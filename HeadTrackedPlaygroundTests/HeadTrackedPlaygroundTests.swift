import XCTest
@testable import HeadTrackedPlayground

final class HeadTrackedPlaygroundTests: XCTestCase {
    func testScaffoldBuildsTestTarget() {
        XCTAssertTrue(true)
    }

    func testCalibrationProfileRoundTripPreservesValues() throws {
        let profile = CalibrationProfile.default
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(CalibrationProfile.self, from: data)
        XCTAssertEqual(decoded, profile)
    }

    func testCalibrationProfileDecodesLegacyPayloadWithoutMirrorFlag() throws {
        let legacyJSON = """
        {
          "displayWidthMeters" : 0.345,
          "displayHeightMeters" : 0.215,
          "webcamOffsetXMeters" : 0,
          "webcamOffsetYMeters" : 0.012,
          "webcamOffsetZMeters" : 0,
          "neutralFaceCenterX" : 0.5,
          "neutralFaceCenterY" : 0.5,
          "neutralHeadPose" : {
            "x" : 0,
            "y" : 0,
            "z" : 0.6,
            "confidence" : 0,
            "timestamp" : 0
          },
          "baselineInterEyeDistance" : 0.13,
          "lateralSmoothing" : 0.2,
          "depthSmoothing" : 0.15,
          "fallbackHoldDuration" : 0.45,
          "reacquireInterval" : 1
        }
        """

        let decoded = try JSONDecoder().decode(CalibrationProfile.self, from: Data(legacyJSON.utf8))

        XCTAssertFalse(decoded.isWebcamMirrored)
        XCTAssertEqual(decoded.displayWidthMeters, CalibrationProfile.default.displayWidthMeters, accuracy: 0.0001)
    }

    func testPoseEstimatorReturnsNearZeroXYForNeutralFaceCenter() {
        var profile = CalibrationProfile.default
        profile.neutralFaceCenterX = 0.5
        profile.neutralFaceCenterY = 0.5
        profile.webcamOffsetXMeters = 0
        profile.webcamOffsetYMeters = 0
        profile.webcamOffsetZMeters = 0
        profile.neutralHeadPose = HeadPose(x: 0, y: 0, z: 0.6, confidence: 1, timestamp: 0)
        profile.baselineInterEyeDistance = 0.1

        let observation = FaceObservation2D(
            boundingBox: NormalizedRect(x: 0.4, y: 0.35, width: 0.2, height: 0.3),
            leftEye: [NormalizedPoint(x: 0.45, y: 0.55)],
            rightEye: [NormalizedPoint(x: 0.55, y: 0.55)],
            nose: [NormalizedPoint(x: 0.5, y: 0.48)],
            detectionConfidence: 1,
            landmarkConfidence: 1,
            timestamp: 1
        )

        let trackedFaceState = TrackedFaceState(
            observation: observation,
            status: TrackingStatus(mode: .trackingFine, confidence: 1, lastUpdateAge: 0),
            isUsingCoarseFallback: false
        )

        let pose = PoseEstimator().estimatePose(from: trackedFaceState, calibration: profile)

        XCTAssertNotNil(pose)
        XCTAssertEqual(pose?.x ?? 1, 0, accuracy: 0.0001)
        XCTAssertEqual(pose?.y ?? 1, 0, accuracy: 0.0001)
    }

    func testPoseEstimatorMirrorsHorizontalPoseWhenCalibrationRequiresIt() {
        var profile = CalibrationProfile.default
        profile.isWebcamMirrored = true
        profile.neutralFaceCenterX = 0.5
        profile.neutralFaceCenterY = 0.5
        profile.displayWidthMeters = 0.4
        profile.neutralHeadPose = HeadPose(x: 0, y: 0, z: 0.6, confidence: 1, timestamp: 0)
        profile.baselineInterEyeDistance = 0.1

        let observation = FaceObservation2D(
            boundingBox: NormalizedRect(x: 0.65, y: 0.35, width: 0.2, height: 0.3),
            leftEye: [NormalizedPoint(x: 0.7, y: 0.55)],
            rightEye: [NormalizedPoint(x: 0.8, y: 0.55)],
            nose: [],
            detectionConfidence: 1,
            landmarkConfidence: 1,
            timestamp: 1
        )

        let pose = PoseEstimator().estimatePose(
            from: TrackedFaceState(
                observation: observation,
                status: TrackingStatus(mode: .trackingFine, confidence: 1, lastUpdateAge: 0),
                isUsingCoarseFallback: false
            ),
            calibration: profile
        )

        XCTAssertNotNil(pose)
        XCTAssertEqual(pose?.x ?? 1, -0.1, accuracy: 0.0001)
    }

    func testPoseEstimatorDepthDecreasesWhenEyesAppearFurtherApart() {
        var profile = CalibrationProfile.default
        profile.baselineInterEyeDistance = 0.08
        profile.neutralHeadPose = HeadPose(x: 0, y: 0, z: 0.7, confidence: 1, timestamp: 0)

        let farObservation = FaceObservation2D(
            boundingBox: NormalizedRect(x: 0.42, y: 0.32, width: 0.16, height: 0.24),
            leftEye: [NormalizedPoint(x: 0.47, y: 0.53)],
            rightEye: [NormalizedPoint(x: 0.53, y: 0.53)],
            nose: [],
            detectionConfidence: 1,
            landmarkConfidence: 1,
            timestamp: 1
        )

        let nearObservation = FaceObservation2D(
            boundingBox: NormalizedRect(x: 0.37, y: 0.27, width: 0.26, height: 0.38),
            leftEye: [NormalizedPoint(x: 0.44, y: 0.53)],
            rightEye: [NormalizedPoint(x: 0.56, y: 0.53)],
            nose: [],
            detectionConfidence: 1,
            landmarkConfidence: 1,
            timestamp: 1
        )

        let estimator = PoseEstimator()
        let farPose = estimator.estimatePose(
            from: TrackedFaceState(
                observation: farObservation,
                status: TrackingStatus(mode: .trackingFine, confidence: 1, lastUpdateAge: 0),
                isUsingCoarseFallback: false
            ),
            calibration: profile
        )
        let nearPose = estimator.estimatePose(
            from: TrackedFaceState(
                observation: nearObservation,
                status: TrackingStatus(mode: .trackingFine, confidence: 1, lastUpdateAge: 0),
                isUsingCoarseFallback: false
            ),
            calibration: profile
        )

        XCTAssertNotNil(farPose)
        XCTAssertNotNil(nearPose)
        XCTAssertGreaterThan(farPose?.z ?? 0, nearPose?.z ?? 0)
    }

    func testPoseSmootherHoldsPoseDuringShortTrackingLoss() {
        let smoother = PoseSmoother()
        let calibration = CalibrationProfile.default
        let trackedPose = HeadPose(x: 0.1, y: -0.02, z: 0.55, confidence: 1, timestamp: 1)

        let initial = smoother.update(
            rawPose: trackedPose,
            trackingStatus: TrackingStatus(mode: .trackingFine, confidence: 1, lastUpdateAge: 0),
            calibration: calibration,
            now: 1
        )

        let held = smoother.update(
            rawPose: nil,
            trackingStatus: TrackingStatus(mode: .lost, confidence: 0, lastUpdateAge: 0.1),
            calibration: calibration,
            now: 1.2
        )

        XCTAssertEqual(initial.x, held.x, accuracy: 0.0001)
        XCTAssertEqual(initial.z, held.z, accuracy: 0.0001)
    }

    func testProjectionEngineProducesAsymmetricFrustumOffCenter() {
        let engine = ProjectionEngine()
        let calibration = CalibrationProfile.default

        let centered = engine.projectionParameters(
            for: HeadPose(x: 0, y: 0, z: 0.6, confidence: 1, timestamp: 0),
            calibration: calibration,
            drawableSize: CGSize(width: 1280, height: 720)
        )
        let shifted = engine.projectionParameters(
            for: HeadPose(x: 0.08, y: 0, z: 0.6, confidence: 1, timestamp: 0),
            calibration: calibration,
            drawableSize: CGSize(width: 1280, height: 720)
        )

        XCTAssertEqual(centered.projectionMatrix.columns.2.x, 0, accuracy: 0.0001)
        XCTAssertNotEqual(shifted.projectionMatrix.columns.2.x, 0, accuracy: 0.0001)
    }

    func testPaperCalibrationEstimatorDetectsA4AndComputesDistance() {
        let estimator = PaperCalibrationEstimator()
        let observation = estimator.estimateObservation(
            corners: [
                NormalizedPoint(x: 0.39, y: 0.79),
                NormalizedPoint(x: 0.61, y: 0.79),
                NormalizedPoint(x: 0.61, y: 0.24),
                NormalizedPoint(x: 0.39, y: 0.24)
            ],
            frameSize: CGSize(width: 1280, height: 720),
            horizontalFieldOfViewDegrees: 60,
            preferredTarget: .auto,
            rectangleConfidence: 0.95
        )

        XCTAssertEqual(observation?.sheet, .a4)
        XCTAssertEqual(observation?.estimatedDistanceMeters ?? 0, 0.83, accuracy: 0.05)
        XCTAssertGreaterThan(observation?.confidence ?? 0, 0.8)
    }

    func testPaperCalibrationEstimatorCanPreferUSLetter() {
        let estimator = PaperCalibrationEstimator()
        let observation = estimator.estimateObservation(
            corners: [
                NormalizedPoint(x: 0.39, y: 0.75),
                NormalizedPoint(x: 0.61, y: 0.75),
                NormalizedPoint(x: 0.61, y: 0.25),
                NormalizedPoint(x: 0.39, y: 0.25)
            ],
            frameSize: CGSize(width: 1280, height: 720),
            horizontalFieldOfViewDegrees: 60,
            preferredTarget: .usLetter,
            rectangleConfidence: 0.92
        )

        XCTAssertEqual(observation?.sheet, .usLetter)
        XCTAssertEqual(observation?.estimatedDistanceMeters ?? 0, 0.86, accuracy: 0.05)
    }

    func testRenderEnvironmentExposesStableSceneOptions() {
        XCTAssertEqual(RenderEnvironment.allCases.map(\.displayName), ["Workspace Room", "Target Tunnel", "Theater Screen"])
        XCTAssertEqual(RenderEnvironment.workspaceRoom.badgeTitle, "Desk + room anchors")
        XCTAssertEqual(RenderEnvironment.targetTunnel.badgeTitle, "Billboard targets + depth frames")
        XCTAssertEqual(RenderEnvironment.theaterScreen.badgeTitle, "Auditorium depth + big screen")
    }

    func testEnvironmentArtworkDisplayNameStripsPathAndExtension() {
        let artwork = EnvironmentArtwork(imageURL: URL(fileURLWithPath: "/tmp/posters/my-show-poster.png"))

        XCTAssertEqual(artwork.displayName, "my-show-poster")
    }
}
