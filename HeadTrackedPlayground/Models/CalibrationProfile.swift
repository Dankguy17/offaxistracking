import Foundation

struct CalibrationProfile: Codable, Equatable, Sendable {
    var isWebcamMirrored: Bool
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
        isWebcamMirrored: false,
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

    private enum CodingKeys: String, CodingKey {
        case isWebcamMirrored
        case displayWidthMeters
        case displayHeightMeters
        case webcamOffsetXMeters
        case webcamOffsetYMeters
        case webcamOffsetZMeters
        case neutralFaceCenterX
        case neutralFaceCenterY
        case neutralHeadPose
        case baselineInterEyeDistance
        case lateralSmoothing
        case depthSmoothing
        case fallbackHoldDuration
        case reacquireInterval
    }

    init(
        isWebcamMirrored: Bool,
        displayWidthMeters: Double,
        displayHeightMeters: Double,
        webcamOffsetXMeters: Double,
        webcamOffsetYMeters: Double,
        webcamOffsetZMeters: Double,
        neutralFaceCenterX: Double,
        neutralFaceCenterY: Double,
        neutralHeadPose: HeadPose,
        baselineInterEyeDistance: Double,
        lateralSmoothing: Double,
        depthSmoothing: Double,
        fallbackHoldDuration: Double,
        reacquireInterval: Double
    ) {
        self.isWebcamMirrored = isWebcamMirrored
        self.displayWidthMeters = displayWidthMeters
        self.displayHeightMeters = displayHeightMeters
        self.webcamOffsetXMeters = webcamOffsetXMeters
        self.webcamOffsetYMeters = webcamOffsetYMeters
        self.webcamOffsetZMeters = webcamOffsetZMeters
        self.neutralFaceCenterX = neutralFaceCenterX
        self.neutralFaceCenterY = neutralFaceCenterY
        self.neutralHeadPose = neutralHeadPose
        self.baselineInterEyeDistance = baselineInterEyeDistance
        self.lateralSmoothing = lateralSmoothing
        self.depthSmoothing = depthSmoothing
        self.fallbackHoldDuration = fallbackHoldDuration
        self.reacquireInterval = reacquireInterval
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isWebcamMirrored: try container.decodeIfPresent(Bool.self, forKey: .isWebcamMirrored) ?? false,
            displayWidthMeters: try container.decode(Double.self, forKey: .displayWidthMeters),
            displayHeightMeters: try container.decode(Double.self, forKey: .displayHeightMeters),
            webcamOffsetXMeters: try container.decode(Double.self, forKey: .webcamOffsetXMeters),
            webcamOffsetYMeters: try container.decode(Double.self, forKey: .webcamOffsetYMeters),
            webcamOffsetZMeters: try container.decode(Double.self, forKey: .webcamOffsetZMeters),
            neutralFaceCenterX: try container.decode(Double.self, forKey: .neutralFaceCenterX),
            neutralFaceCenterY: try container.decode(Double.self, forKey: .neutralFaceCenterY),
            neutralHeadPose: try container.decode(HeadPose.self, forKey: .neutralHeadPose),
            baselineInterEyeDistance: try container.decode(Double.self, forKey: .baselineInterEyeDistance),
            lateralSmoothing: try container.decode(Double.self, forKey: .lateralSmoothing),
            depthSmoothing: try container.decode(Double.self, forKey: .depthSmoothing),
            fallbackHoldDuration: try container.decode(Double.self, forKey: .fallbackHoldDuration),
            reacquireInterval: try container.decode(Double.self, forKey: .reacquireInterval)
        )
    }
}
