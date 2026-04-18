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

    var isUsingCoarseFallback: Bool {
        trackedFaceState.isUsingCoarseFallback
    }

    init(calibrationManager: CalibrationManager = CalibrationManager()) {
        self.calibrationManager = calibrationManager
        let profile = calibrationManager.loadProfile()
        calibrationProfile = profile
        trackingStatus = .searching
        trackedFaceState = .empty
        rawPose = profile.neutralHeadPose
        smoothedPose = profile.neutralHeadPose
        debugMetrics = .zero
        isProjectionFrozen = false
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
