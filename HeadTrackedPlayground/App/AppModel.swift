import Combine
import Foundation
import AppKit
import UniformTypeIdentifiers

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
    @Published var environmentArtwork: EnvironmentArtwork?
    @Published var paperCalibrationTarget: PaperCalibrationTarget
    @Published var paperCalibrationState: PaperCalibrationState

    private let calibrationManager: CalibrationManager
    let cameraCaptureService: CameraCaptureService
    let faceTrackingService: FaceTrackingService
    let paperCalibrationService: PaperCalibrationService
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
        faceTrackingService: FaceTrackingService = FaceTrackingService(),
        paperCalibrationService: PaperCalibrationService = PaperCalibrationService()
    ) {
        self.calibrationManager = calibrationManager
        self.cameraCaptureService = cameraCaptureService
        self.faceTrackingService = faceTrackingService
        self.paperCalibrationService = paperCalibrationService
        let profile = calibrationManager.loadProfile()
        calibrationProfile = profile
        trackingStatus = .searching
        trackedFaceState = .empty
        rawPose = profile.neutralHeadPose
        smoothedPose = profile.neutralHeadPose
        debugMetrics = .zero
        isProjectionFrozen = false
        selectedEnvironment = .workspaceRoom
        environmentArtwork = nil
        paperCalibrationTarget = .auto
        paperCalibrationState = .idle

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

        paperCalibrationService.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.paperCalibrationState = state
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

        $environmentArtwork
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateRendererState()
            }
            .store(in: &cancellables)

        paperCalibrationService.onCompleted = { [weak self] result in
            self?.applyPaperCalibration(result)
        }

        cameraCaptureService.onFrame = { [weak faceTrackingService, weak paperCalibrationService] frame in
            faceTrackingService?.enqueue(frame)
            paperCalibrationService?.enqueue(frame)
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
            let faceCenter = poseEstimator.faceCenter(for: observation, calibration: calibrationProfile)
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

    func startPaperCalibration() {
        paperCalibrationService.start(preferredTarget: paperCalibrationTarget)
    }

    func cancelPaperCalibration() {
        paperCalibrationService.cancel()
    }

    func resetCalibration() {
        calibrationProfile = .default
        rawPose = calibrationProfile.neutralHeadPose
        smoothedPose = calibrationProfile.neutralHeadPose
        poseSmoother.reset(to: smoothedPose)
        persistCalibration()
    }

    func chooseEnvironmentArtwork() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.prompt = "Add Image"
        panel.message = "Choose an image to map onto the in-scene theater screen."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        environmentArtwork = EnvironmentArtwork(imageURL: url)
    }

    func clearEnvironmentArtwork() {
        environmentArtwork = nil
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
            artwork: environmentArtwork,
            isFrozen: isProjectionFrozen
        )
    }

    private func applyPaperCalibration(_ result: PaperCalibrationResult) {
        if let observation = trackedFaceState.observation {
            let faceCenter = poseEstimator.faceCenter(for: observation, calibration: calibrationProfile)
            calibrationProfile.neutralFaceCenterX = faceCenter.x
            calibrationProfile.neutralFaceCenterY = faceCenter.y
            calibrationProfile.baselineInterEyeDistance = poseEstimator.depthSignal(
                for: observation,
                useCoarseFallback: trackedFaceState.isUsingCoarseFallback
            )
        }

        var calibratedNeutralPose = smoothedPose
        calibratedNeutralPose.z = max(result.distanceMeters - calibrationProfile.webcamOffsetZMeters, 0.05)
        calibratedNeutralPose.confidence = max(calibratedNeutralPose.confidence, result.confidence)
        calibratedNeutralPose.timestamp = trackedFaceState.observation?.timestamp ?? calibratedNeutralPose.timestamp
        calibrationProfile.neutralHeadPose = calibratedNeutralPose
        rawPose = calibratedNeutralPose
        smoothedPose = calibratedNeutralPose
        poseSmoother.reset(to: calibratedNeutralPose)
        persistCalibration()
    }
}
