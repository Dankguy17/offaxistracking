import SwiftUI

struct CameraPanelPlaceholderView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var cameraCaptureService: CameraCaptureService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Camera Preview", systemImage: "camera.viewfinder")
                .font(.headline)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.85))

                if cameraCaptureService.authorizationStatus == .authorized {
                    CameraSessionPreview(session: cameraCaptureService.session)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            FaceTrackingOverlayView(trackedFaceState: appModel.trackedFaceState)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                        .overlay(alignment: .topLeading) {
                            CameraStatusBanner(
                                title: cameraCaptureService.isRunning ? "Live Camera" : "Starting Camera",
                                subtitle: appModel.isUsingCoarseFallback ? "Coarse fallback tracking active" : "Vision tracking overlay active"
                            )
                            .padding(14)
                        }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.badge.ellipsis")
                            .font(.system(size: 54))
                            .foregroundStyle(Color.white.opacity(0.85))

                        Text(cameraStateTitle)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(cameraStateSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                    }
                    .padding(24)
                }
            }
            .frame(minHeight: 280)

            HStack(spacing: 24) {
                StatBadge(title: "Tracking", value: appModel.trackingStatus.mode.rawValue)
                StatBadge(title: "Confidence", value: appModel.trackingStatus.confidence.formatted(.number.precision(.fractionLength(2))))
                StatBadge(title: "Camera FPS", value: cameraCaptureService.averageFPS.formatted(.number.precision(.fractionLength(1))))
            }
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var cameraStateTitle: String {
        switch cameraCaptureService.authorizationStatus {
        case .authorized:
            return cameraCaptureService.isRunning ? "Live camera running" : "Starting camera session"
        case .notDetermined:
            return "Requesting camera permission"
        case .denied:
            return "Camera permission denied"
        case .restricted:
            return "Camera access restricted"
        @unknown default:
            return "Camera status unavailable"
        }
    }

    private var cameraStateSubtitle: String {
        if let errorMessage = cameraCaptureService.errorMessage {
            return errorMessage
        }
        return "The live webcam preview will appear here once camera access is available."
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

private struct CameraStatusBanner: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
