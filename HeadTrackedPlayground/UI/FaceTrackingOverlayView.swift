import SwiftUI

struct FaceTrackingOverlayView: View {
    let trackedFaceState: TrackedFaceState
    let paperCalibrationState: PaperCalibrationState
    let isMirrored: Bool

    var body: some View {
        GeometryReader { geometry in
                ZStack {
                    if let observation = trackedFaceState.observation {
                        let boundingRect = rect(for: observation.boundingBox, in: geometry.size)

                        Path { path in
                            path.addRoundedRect(in: boundingRect, cornerSize: CGSize(width: 18, height: 18))
                        }
                        .stroke(trackedFaceState.isUsingCoarseFallback ? Color.orange : Color.green, lineWidth: 3)

                        landmarkPath(for: observation.leftEye, in: geometry.size)
                            .stroke(Color.cyan, lineWidth: 2)
                        landmarkPath(for: observation.rightEye, in: geometry.size)
                            .stroke(Color.cyan, lineWidth: 2)
                        landmarkPath(for: observation.nose, in: geometry.size)
                            .stroke(Color.yellow, lineWidth: 2)
                    }

                    if let paperObservation = paperCalibrationState.observation {
                        paperPath(for: paperObservation.corners, in: geometry.size)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))

                        Text("\(paperObservation.sheet.shortLabel) \(paperObservation.estimatedDistanceMeters.formatted(.number.precision(.fractionLength(2)))) m")
                            .font(.caption2.monospacedDigit())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: Capsule())
                            .position(labelPosition(for: paperObservation.boundingBox, in: geometry.size))
                    }
                }
        }
        .allowsHitTesting(false)
    }

    private func rect(for rect: NormalizedRect, in size: CGSize) -> CGRect {
        let width = rect.width * size.width
        let height = rect.height * size.height
        let normalizedX = isMirrored ? (1 - rect.x - rect.width) : rect.x
        let x = normalizedX * size.width
        let y = (1 - rect.y - rect.height) * size.height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func landmarkPath(for points: [NormalizedPoint], in size: CGSize) -> Path {
        var path = Path()

        for (index, point) in points.enumerated() {
            let normalizedX = isMirrored ? (1 - point.x) : point.x
            let transformed = CGPoint(x: normalizedX * size.width, y: (1 - point.y) * size.height)
            if index == 0 {
                path.move(to: transformed)
            } else {
                path.addLine(to: transformed)
            }
        }

        return path
    }

    private func paperPath(for corners: [NormalizedPoint], in size: CGSize) -> Path {
        var path = Path()
        guard let first = corners.first else { return path }

        path.move(to: point(for: first, in: size))
        for point in corners.dropFirst() {
            path.addLine(to: self.point(for: point, in: size))
        }
        path.closeSubpath()
        return path
    }

    private func point(for point: NormalizedPoint, in size: CGSize) -> CGPoint {
        let normalizedX = isMirrored ? (1 - point.x) : point.x
        return CGPoint(x: normalizedX * size.width, y: (1 - point.y) * size.height)
    }

    private func labelPosition(for rect: NormalizedRect, in size: CGSize) -> CGPoint {
        let overlayRect = self.rect(for: rect, in: size)
        return CGPoint(
            x: min(max(overlayRect.midX, 70), size.width - 70),
            y: max(18, overlayRect.minY - 16)
        )
    }
}
