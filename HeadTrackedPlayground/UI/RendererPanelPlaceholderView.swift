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

                if appModel.selectedEnvironment == .windowLandscape {
                    WindowFrameOverlay()
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .allowsHitTesting(false)
                }

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
                StatBadge(title: "Screen Art", value: appModel.environmentArtwork?.displayName ?? "None")
                StatBadge(title: "Render FPS", value: appModel.debugMetrics.renderFPS.formatted(.number.precision(.fractionLength(1))))
                StatBadge(title: "Freeze", value: appModel.isProjectionFrozen ? "On" : "Off")
                StatBadge(title: "Pose Z", value: appModel.smoothedPose.z.formatted(.number.precision(.fractionLength(3))))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct SceneBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(Color(red: 0.16, green: 0.19, blue: 0.14))
            .background(
                Capsule()
                    .fill(Color(red: 0.16, green: 0.39, blue: 0.24).opacity(0.88))
            )
            .foregroundStyle(.white)
    }
}

private struct StatBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Color.primary)
        }
    }
}

private struct WindowFrameOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let sideRail = max(24, width * 0.055)
            let topRail = max(24, height * 0.09)
            let sill = max(28, height * 0.12)
            let mullion = max(12, width * 0.018)
            let crossbar = max(12, height * 0.022)
            let glow = Color(red: 0.96, green: 0.86, blue: 0.67).opacity(0.72)
            let wood = Color(red: 0.45, green: 0.28, blue: 0.14)
            let shadow = Color.black.opacity(0.20)

            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [shadow.opacity(0.3), .clear, shadow.opacity(0.18)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .mask(
                        WindowMask(
                            sideRail: sideRail,
                            topRail: topRail,
                            sill: sill,
                            mullion: mullion,
                            crossbar: crossbar
                        )
                        .fill(style: FillStyle(eoFill: true))
                    )

                WindowMask(
                    sideRail: sideRail,
                    topRail: topRail,
                    sill: sill,
                    mullion: mullion,
                    crossbar: crossbar
                )
                .fill(wood)

                WindowMask(
                    sideRail: sideRail + 8,
                    topRail: topRail + 8,
                    sill: sill + 8,
                    mullion: mullion + 4,
                    crossbar: crossbar + 4
                )
                .stroke(glow, lineWidth: 3)
                .blur(radius: 1.4)
            }
        }
    }
}

private struct WindowMask: Shape {
    let sideRail: CGFloat
    let topRail: CGFloat
    let sill: CGFloat
    let mullion: CGFloat
    let crossbar: CGFloat

    func path(in rect: CGRect) -> Path {
        let outer = RoundedRectangle(cornerRadius: 24, style: .continuous).path(in: rect)
        let opening = CGRect(
            x: sideRail,
            y: topRail,
            width: rect.width - (sideRail * 2),
            height: rect.height - topRail - sill
        )
        let leftPane = CGRect(
            x: opening.minX,
            y: opening.minY,
            width: (opening.width - mullion) * 0.5,
            height: opening.height
        )
        let rightPane = CGRect(
            x: leftPane.maxX + mullion,
            y: opening.minY,
            width: leftPane.width,
            height: opening.height
        )
        let leftUpper = CGRect(
            x: leftPane.minX,
            y: leftPane.minY,
            width: leftPane.width,
            height: (leftPane.height - crossbar) * 0.5
        )
        let leftLower = CGRect(
            x: leftPane.minX,
            y: leftUpper.maxY + crossbar,
            width: leftPane.width,
            height: leftUpper.height
        )
        let rightUpper = CGRect(
            x: rightPane.minX,
            y: rightPane.minY,
            width: rightPane.width,
            height: (rightPane.height - crossbar) * 0.5
        )
        let rightLower = CGRect(
            x: rightPane.minX,
            y: rightUpper.maxY + crossbar,
            width: rightPane.width,
            height: rightUpper.height
        )

        var path = Path()
        path.addPath(outer)
        path.addRoundedRect(in: leftUpper, cornerSize: CGSize(width: 10, height: 10))
        path.addRoundedRect(in: leftLower, cornerSize: CGSize(width: 10, height: 10))
        path.addRoundedRect(in: rightUpper, cornerSize: CGSize(width: 10, height: 10))
        path.addRoundedRect(in: rightLower, cornerSize: CGSize(width: 10, height: 10))
        return path
    }
}
