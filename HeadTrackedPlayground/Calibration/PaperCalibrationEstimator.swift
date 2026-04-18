import CoreGraphics
import Foundation

struct PaperCalibrationEstimator {
    var defaultHorizontalFieldOfViewDegrees: Double = 60
    var maximumAspectError: Double = 0.18
    var minimumDistanceMeters: Double = 0.2
    var maximumDistanceMeters: Double = 2.2

    func estimateObservation(
        corners: [NormalizedPoint],
        frameSize: CGSize,
        horizontalFieldOfViewDegrees: Double?,
        preferredTarget: PaperCalibrationTarget,
        rectangleConfidence: Double
    ) -> PaperCalibrationObservation? {
        guard corners.count == 4, frameSize.width > 0, frameSize.height > 0 else {
            return nil
        }

        let pixelPoints = corners.map { point in
            CGPoint(x: point.x * frameSize.width, y: point.y * frameSize.height)
        }

        let topWidth = distance(pixelPoints[0], pixelPoints[1])
        let rightHeight = distance(pixelPoints[1], pixelPoints[2])
        let bottomWidth = distance(pixelPoints[2], pixelPoints[3])
        let leftHeight = distance(pixelPoints[3], pixelPoints[0])

        let observedWidth = max((topWidth + bottomWidth) * 0.5, 1)
        let observedHeight = max((leftHeight + rightHeight) * 0.5, 1)
        let observedLongSide = max(observedWidth, observedHeight)
        let observedShortSide = min(observedWidth, observedHeight)
        let observedAspectRatio = observedLongSide / max(observedShortSide, 1)

        guard
            let sheet = preferredTarget.candidateSheets.min(
                by: { abs($0.aspectRatio - observedAspectRatio) < abs($1.aspectRatio - observedAspectRatio) }
            )
        else {
            return nil
        }

        let aspectError = abs(sheet.aspectRatio - observedAspectRatio)
        guard aspectError <= maximumAspectError else {
            return nil
        }

        // A known-size rectangle plus approximate webcam FOV is enough to infer a usable
        // monocular distance estimate for neutral-depth calibration in this prototype.
        let focalLengthPixels = focalLength(
            for: frameSize.width,
            horizontalFieldOfViewDegrees: horizontalFieldOfViewDegrees ?? defaultHorizontalFieldOfViewDegrees
        )
        let longSideDistance = (sheet.longSideMeters * focalLengthPixels) / observedLongSide
        let shortSideDistance = (sheet.shortSideMeters * focalLengthPixels) / observedShortSide
        let estimatedDistance = (longSideDistance + shortSideDistance) * 0.5

        guard estimatedDistance.isFinite, minimumDistanceMeters ... maximumDistanceMeters ~= estimatedDistance else {
            return nil
        }

        let xValues = corners.map(\.x)
        let yValues = corners.map(\.y)
        let aspectScore = max(0, 1 - (aspectError / maximumAspectError))
        let confidence = min(1, max(0, rectangleConfidence) * 0.65 + aspectScore * 0.35)

        return PaperCalibrationObservation(
            corners: corners,
            boundingBox: NormalizedRect(
                x: xValues.min() ?? 0,
                y: yValues.min() ?? 0,
                width: (xValues.max() ?? 0) - (xValues.min() ?? 0),
                height: (yValues.max() ?? 0) - (yValues.min() ?? 0)
            ),
            estimatedDistanceMeters: estimatedDistance,
            confidence: confidence,
            sheet: sheet,
            stabilityProgress: 0
        )
    }

    private func focalLength(for frameWidth: Double, horizontalFieldOfViewDegrees: Double) -> Double {
        let clampedFOV = min(max(horizontalFieldOfViewDegrees, 20), 120)
        let radians = clampedFOV * .pi / 180
        return (frameWidth * 0.5) / tan(radians * 0.5)
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> Double {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
