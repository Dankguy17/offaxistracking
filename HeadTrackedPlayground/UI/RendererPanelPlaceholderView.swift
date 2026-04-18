import SwiftUI

struct RendererPanelPlaceholderView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Projection Viewport", systemImage: "cube.transparent")
                .font(.headline)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.21, green: 0.15, blue: 0.08),
                                Color(red: 0.07, green: 0.04, blue: 0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Canvas { context, size in
                    let spacing: CGFloat = 28
                    for column in stride(from: 0, through: size.width, by: spacing) {
                        var path = Path()
                        path.move(to: CGPoint(x: column, y: 0))
                        path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                        context.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: 1)
                    }

                    for row in stride(from: size.height * 0.32, through: size.height, by: spacing) {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: row))
                        path.addLine(to: CGPoint(x: size.width, y: row))
                        context.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 1)
                    }

                    let circleRect = CGRect(x: size.width * 0.42, y: size.height * 0.26, width: 56, height: 56)
                    context.fill(Path(ellipseIn: circleRect), with: .color(.white.opacity(0.35)))
                }

                VStack {
                    Spacer()

                    Text(appModel.isProjectionFrozen ? "Projection Frozen for Calibration" : "Metal scene placeholder")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 18)
                }
            }
            .frame(minHeight: 280)

            HStack(spacing: 24) {
                StatBadge(title: "Render FPS", value: appModel.debugMetrics.renderFPS.formatted(.number.precision(.fractionLength(1))))
                StatBadge(title: "Freeze", value: appModel.isProjectionFrozen ? "On" : "Off")
                StatBadge(title: "Pose Z", value: appModel.smoothedPose.z.formatted(.number.precision(.fractionLength(3))))
            }
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct StatBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
    }
}
