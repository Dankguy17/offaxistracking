import Foundation

final class PoseSmoother {
    private var lastPose: HeadPose?
    private var lastTrackedTimestamp: TimeInterval?

    func update(rawPose: HeadPose?, trackingStatus: TrackingStatus, calibration: CalibrationProfile, now: TimeInterval) -> HeadPose {
        if let rawPose, trackingStatus.mode == .trackingFine || trackingStatus.mode == .trackingCoarse {
            let smoothedPose: HeadPose

            if let lastPose {
                let confidence = max(trackingStatus.confidence, 0.15)
                let lateralAlpha = min(max(calibration.lateralSmoothing * confidence, 0.01), 1)
                let depthAlpha = min(max(calibration.depthSmoothing * confidence, 0.01), 1)

                smoothedPose = HeadPose(
                    x: interpolate(from: lastPose.x, to: rawPose.x, alpha: lateralAlpha),
                    y: interpolate(from: lastPose.y, to: rawPose.y, alpha: lateralAlpha),
                    z: interpolate(from: lastPose.z, to: rawPose.z, alpha: depthAlpha),
                    confidence: rawPose.confidence,
                    timestamp: rawPose.timestamp
                )
            } else {
                smoothedPose = rawPose
            }

            lastPose = smoothedPose
            lastTrackedTimestamp = now
            return smoothedPose
        }

        guard let lastPose else {
            return calibration.neutralHeadPose
        }

        let lastTrackedAge = lastTrackedTimestamp.map { now - $0 } ?? .infinity
        if lastTrackedAge <= calibration.fallbackHoldDuration {
            return HeadPose(
                x: lastPose.x,
                y: lastPose.y,
                z: lastPose.z,
                confidence: 0,
                timestamp: now
            )
        }

        let decayedPose = HeadPose(
            x: interpolate(from: lastPose.x, to: calibration.neutralHeadPose.x, alpha: 0.08),
            y: interpolate(from: lastPose.y, to: calibration.neutralHeadPose.y, alpha: 0.08),
            z: interpolate(from: lastPose.z, to: calibration.neutralHeadPose.z, alpha: 0.08),
            confidence: 0,
            timestamp: now
        )

        self.lastPose = decayedPose
        return decayedPose
    }

    func reset(to pose: HeadPose? = nil) {
        lastPose = pose
        lastTrackedTimestamp = nil
    }

    private func interpolate(from start: Double, to end: Double, alpha: Double) -> Double {
        start + ((end - start) * alpha)
    }
}
