import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var calibrationProfile: CalibrationProfile
    @Published var trackingStatus: TrackingStatus
    @Published var trackedFaceState: TrackedFaceState
    @Published var rawPose: HeadPose
    @Published var smoothedPose: HeadPose
    @Published var debugMetrics: DebugMetrics
    @Published var isProjectionFrozen: Bool

    private let calibrationManager: CalibrationManager
    let cameraCaptureService: CameraCaptureService
    let faceTrackingService: FaceTrackingService
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
            }
            .store(in: &cancellables)

        faceTrackingService.$averageLatencyMS
            .receive(on: RunLoop.main)
            .sink { [weak self] latencyMS in
                self?.debugMetrics.visionLatencyMS = latencyMS
            }
            .store(in: &cancellables)

        cameraCaptureService.onFrame = { [weak faceTrackingService] frame in
            faceTrackingService?.enqueue(frame)
        }
    }

    func startServices() {
        guard !hasStartedServices else { return }
        hasStartedServices = true
        faceTrackingService.reacquireInterval = calibrationProfile.reacquireInterval
        cameraCaptureService.start()
    }

    func captureNeutralPose() {
        calibrationProfile.neutralHeadPose = smoothedPose
        persistCalibration()
    }

    func resetCalibration() {
        calibrationProfile = .default
        rawPose = calibrationProfile.neutralHeadPose
        smoothedPose = calibrationProfile.neutralHeadPose
        persistCalibration()
    }

    func persistCalibration() {
        do {
            try calibrationManager.saveProfile(calibrationProfile)
            faceTrackingService.reacquireInterval = calibrationProfile.reacquireInterval
        } catch {
            print("Failed to save calibration profile: \(error.localizedDescription)")
        }
    }
}
