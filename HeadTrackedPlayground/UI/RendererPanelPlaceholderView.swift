import SwiftUI

struct RendererPanelPlaceholderView: View {
    @EnvironmentObject private var appModel: AppModel
    let metalRenderer: MetalRenderer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Projection Environments", systemImage: "cube.transparent")
                .font(.headline)

            ZStack {
                MetalViewport(renderer: metalRenderer)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                VStack {
                    Spacer()

                    HStack {
                        SceneBadge(title: appModel.isProjectionFrozen ? "Projection Frozen" : "Live Off-Axis Projection")
                        Spacer()
                        SceneBadge(title: appModel.selectedEnvironment.displayName)
                        SceneBadge(title: appModel.selectedEnvironment.badgeTitle)
                        SceneBadge(title: "Viewer z \(appModel.smoothedPose.z.formatted(.number.precision(.fractionLength(2)))) m")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .frame(minHeight: 280)

            HStack(spacing: 24) {
                StatBadge(title: "Environment", value: appModel.selectedEnvironment.shortLabel)
                StatBadge(title: "Render FPS", value: appModel.debugMetrics.renderFPS.formatted(.number.precision(.fractionLength(1))))
                StatBadge(title: "Freeze", value: appModel.isProjectionFrozen ? "On" : "Off")
                StatBadge(title: "Pose Z", value: appModel.smoothedPose.z.formatted(.number.precision(.fractionLength(3))))
            }
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct SceneBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
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
