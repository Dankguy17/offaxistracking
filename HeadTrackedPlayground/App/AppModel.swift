import Combine
import Foundation

enum RenderEnvironment: String, CaseIterable, Identifiable {
    case workspaceRoom
    case targetTunnel

    var id: Self { self }

    var displayName: String {
        switch self {
        case .workspaceRoom:
            "Workspace Room"
        case .targetTunnel:
            "Target Tunnel"
        }
    }

    var shortLabel: String {
        switch self {
        case .workspaceRoom:
            "Workspace"
        case .targetTunnel:
            "Tunnel"
        }
    }

    var badgeTitle: String {
        switch self {
        case .workspaceRoom:
            "Desk + room anchors"
        case .targetTunnel:
            "Billboard targets + depth frames"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var calibrationProfile: CalibrationProfile
    @Published var trackingStatus: TrackingStatus
    @Published var trackedFaceState: TrackedFaceState
    @Published var rawPose: HeadPose
    @Published var smoothedPose: HeadPose
    @Published var debugMetrics: DebugMetrics
    @Published var isProjectionFrozen: Bool
    @Published var selectedEnvironment: RenderEnvironment

    private let calibrationManager: CalibrationManager
    let cameraCaptureService: CameraCaptureService
    let faceTrackingService: FaceTrackingService
    let metalRenderer = MetalRenderer()
    private let poseEstimator = PoseEstimator()
    private let poseSmoother = PoseSmoother()
    private var cancellables = Set<AnyCancellable>()
    private var hasStartedServices = false

    var isUsingCoarseFallback: Bool {
        trackedFaceState.isUsingCoarseFallback
    }

    init(
        calibrationManager: CalibrationManager = CalibrationManager(),
        cameraCaptureService: CameraCaptureService = CameraCaptureService(),
        faceTrackingService: FaceTrackingService = FaceTrackingService()
    ) {
        self.calibrationManager = calibrationManager
        self.cameraCaptureService = cameraCaptureService
        self.faceTrackingService = faceTrackingService
        let profile = calibrationManager.loadProfile()
        calibrationProfile = profile
        trackingStatus = .searching
        trackedFaceState = .empty
        rawPose = profile.neutralHeadPose
        smoothedPose = profile.neutralHeadPose
        debugMetrics = .zero
        isProjectionFrozen = false
        selectedEnvironment = .workspaceRoom

        cameraCaptureService.$averageFPS
            .receive(on: RunLoop.main)
            .sink { [weak self] fps in
                self?.debugMetrics.cameraFPS = fps
            }
            .store(in: &cancellables)

        faceTrackingService.$trackedFaceState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                trackedFaceState = state
                trackingStatus = state.status
                recomputePose(using: state)
            }
            .store(in: &cancellables)

        faceTrackingService.$averageLatencyMS
            .receive(on: RunLoop.main)
            .sink { [weak self] latencyMS in
                self?.debugMetrics.visionLatencyMS = latencyMS
            }
            .store(in: &cancellables)

        $isProjectionFrozen
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateRendererState()
            }
            .store(in: &cancellables)

        $selectedEnvironment
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateRendererState()
            }
            .store(in: &cancellables)

        cameraCaptureService.onFrame = { [weak faceTrackingService] frame in
            faceTrackingService?.enqueue(frame)
        }

        metalRenderer.onRenderFPSUpdate = { [weak self] fps in
            DispatchQueue.main.async {
                self?.debugMetrics.renderFPS = fps
            }
        }
    }

    func startServices() {
        guard !hasStartedServices else { return }
        hasStartedServices = true
        faceTrackingService.reacquireInterval = calibrationProfile.reacquireInterval
        cameraCaptureService.start()
        updateRendererState()
    }

    func captureNeutralPose() {
        if let observation = trackedFaceState.observation {
            let faceCenter = poseEstimator.faceCenter(for: observation)
            calibrationProfile.neutralFaceCenterX = faceCenter.x
            calibrationProfile.neutralFaceCenterY = faceCenter.y
            calibrationProfile.baselineInterEyeDistance = poseEstimator.depthSignal(
                for: observation,
                useCoarseFallback: trackedFaceState.isUsingCoarseFallback
            )
        }
        calibrationProfile.neutralHeadPose = smoothedPose
        poseSmoother.reset(to: smoothedPose)
        persistCalibration()
    }

    func resetCalibration() {
        calibrationProfile = .default
        rawPose = calibrationProfile.neutralHeadPose
        smoothedPose = calibrationProfile.neutralHeadPose
        poseSmoother.reset(to: smoothedPose)
        persistCalibration()
    }

    func persistCalibration() {
        do {
            try calibrationManager.saveProfile(calibrationProfile)
            faceTrackingService.reacquireInterval = calibrationProfile.reacquireInterval
            recomputePose(using: trackedFaceState)
        } catch {
            print("Failed to save calibration profile: \(error.localizedDescription)")
        }
    }

    private func recomputePose(using trackedFaceState: TrackedFaceState) {
        let now = trackedFaceState.observation?.timestamp ?? Date().timeIntervalSinceReferenceDate
        let estimatedPose = poseEstimator.estimatePose(from: trackedFaceState, calibration: calibrationProfile)

        if let estimatedPose {
            rawPose = estimatedPose
        }

        smoothedPose = poseSmoother.update(
            rawPose: estimatedPose,
            trackingStatus: trackedFaceState.status,
            calibration: calibrationProfile,
            now: now
        )
        updateRendererState()
    }

    private func updateRendererState() {
        metalRenderer.update(
            pose: smoothedPose,
            calibration: calibrationProfile,
            environment: selectedEnvironment,
            isFrozen: isProjectionFrozen
        )
    }
}
