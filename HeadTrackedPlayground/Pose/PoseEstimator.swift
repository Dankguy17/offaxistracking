import Foundation

struct PoseEstimator {
    func estimatePose(from trackedFaceState: TrackedFaceState, calibration: CalibrationProfile) -> HeadPose? {
        guard let observation = trackedFaceState.observation else {
            return nil
        }

        let centerX = observation.boundingBox.x + (observation.boundingBox.width * 0.5)
        let centerY = observation.boundingBox.y + (observation.boundingBox.height * 0.5)

        let depthSignal = depthSignal(for: observation, useCoarseFallback: trackedFaceState.isUsingCoarseFallback)
        let baselineSignal = max(calibration.baselineInterEyeDistance, 0.001)

        let x = calibration.neutralHeadPose.x + ((centerX - calibration.neutralFaceCenterX) * calibration.displayWidthMeters) + calibration.webcamOffsetXMeters
        let y = calibration.neutralHeadPose.y + ((centerY - calibration.neutralFaceCenterY) * calibration.displayHeightMeters) + calibration.webcamOffsetYMeters
        let z = (calibration.neutralHeadPose.z * (baselineSignal / max(depthSignal, 0.001))) + calibration.webcamOffsetZMeters

        return HeadPose(
            x: x,
            y: y,
            z: z,
            confidence: trackedFaceState.status.confidence,
            timestamp: observation.timestamp
        )
    }

    func depthSignal(for observation: FaceObservation2D, useCoarseFallback: Bool) -> Double {
        if useCoarseFallback {
            return max(observation.boundingBox.width, observation.boundingBox.height)
        }

        let leftEyeCenter = centroid(of: observation.leftEye)
        let rightEyeCenter = centroid(of: observation.rightEye)

        guard let leftEyeCenter, let rightEyeCenter else {
            return max(observation.boundingBox.width, observation.boundingBox.height)
        }

        return hypot(leftEyeCenter.x - rightEyeCenter.x, leftEyeCenter.y - rightEyeCenter.y)
    }

    func faceCenter(for observation: FaceObservation2D) -> (x: Double, y: Double) {
        (
            observation.boundingBox.x + (observation.boundingBox.width * 0.5),
            observation.boundingBox.y + (observation.boundingBox.height * 0.5)
        )
    }

    private func centroid(of points: [NormalizedPoint]) -> NormalizedPoint? {
        guard !points.isEmpty else { return nil }

        let summed = points.reduce((x: 0.0, y: 0.0)) { partial, point in
            (partial.x + point.x, partial.y + point.y)
        }

        return NormalizedPoint(
            x: summed.x / Double(points.count),
            y: summed.y / Double(points.count)
        )
    }
}
