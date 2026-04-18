import SwiftUI

struct CameraPanelPlaceholderView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Camera Preview", systemImage: "camera.viewfinder")
                .font(.headline)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.12, blue: 0.18),
                                Color(red: 0.03, green: 0.05, blue: 0.09)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 10) {
                    Image(systemName: "person.crop.square.badge.video")
                        .font(.system(size: 54))
                        .foregroundStyle(Color.white.opacity(0.85))

                    Text(appModel.trackingStatus.mode == .searching ? "Camera pipeline not started yet" : "Tracking preview active")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("The live webcam feed and landmark overlay will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(24)
            }
            .frame(minHeight: 280)

            HStack(spacing: 24) {
                StatBadge(title: "Tracking", value: appModel.trackingStatus.mode.rawValue)
                StatBadge(title: "Confidence", value: appModel.trackingStatus.confidence.formatted(.number.precision(.fractionLength(2))))
                StatBadge(title: "Camera FPS", value: appModel.debugMetrics.cameraFPS.formatted(.number.precision(.fractionLength(1))))
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
