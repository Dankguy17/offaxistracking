import Foundation

struct CalibrationProfile: Codable, Equatable, Sendable {
    var displayWidthMeters: Double
    var displayHeightMeters: Double
    var webcamOffsetXMeters: Double
    var webcamOffsetYMeters: Double
    var webcamOffsetZMeters: Double
    var neutralFaceCenterX: Double
    var neutralFaceCenterY: Double
    var neutralHeadPose: HeadPose
    var baselineInterEyeDistance: Double
    var lateralSmoothing: Double
    var depthSmoothing: Double
    var fallbackHoldDuration: Double
    var reacquireInterval: Double

    static let `default` = CalibrationProfile(
        displayWidthMeters: 0.345,
        displayHeightMeters: 0.215,
        webcamOffsetXMeters: 0,
        webcamOffsetYMeters: 0.012,
        webcamOffsetZMeters: 0,
        neutralFaceCenterX: 0.5,
        neutralFaceCenterY: 0.5,
        neutralHeadPose: .neutral,
        baselineInterEyeDistance: 0.13,
        lateralSmoothing: 0.2,
        depthSmoothing: 0.15,
        fallbackHoldDuration: 0.45,
        reacquireInterval: 1.0
    )
}
