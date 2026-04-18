import SwiftUI

struct FaceTrackingOverlayView: View {
    let trackedFaceState: TrackedFaceState

    var body: some View {
        GeometryReader { geometry in
            if let observation = trackedFaceState.observation {
                let boundingRect = rect(for: observation.boundingBox, in: geometry.size)

                ZStack {
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
            }
        }
        .allowsHitTesting(false)
    }

    private func rect(for rect: NormalizedRect, in size: CGSize) -> CGRect {
        let width = rect.width * size.width
        let height = rect.height * size.height
        let x = rect.x * size.width
        let y = (1 - rect.y - rect.height) * size.height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func landmarkPath(for points: [NormalizedPoint], in size: CGSize) -> Path {
        var path = Path()

        for (index, point) in points.enumerated() {
            let transformed = CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
            if index == 0 {
                path.move(to: transformed)
            } else {
                path.addLine(to: transformed)
            }
        }

        return path
    }
}
