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
    private var cancellables = Set<AnyCancellable>()
    private var hasStartedServices = false

    var isUsingCoarseFallback: Bool {
        trackedFaceState.isUsingCoarseFallback
    }

    init(
        calibrationManager: CalibrationManager = CalibrationManager(),
        cameraCaptureService: CameraCaptureService = CameraCaptureService()
    ) {
        self.calibrationManager = calibrationManager
        self.cameraCaptureService = cameraCaptureService
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
    }

    func startServices() {
        guard !hasStartedServices else { return }
        hasStartedServices = true
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
        } catch {
            print("Failed to save calibration profile: \(error.localizedDescription)")
        }
    }
}
