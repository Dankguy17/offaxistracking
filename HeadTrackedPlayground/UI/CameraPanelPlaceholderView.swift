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
                    CameraSessionPreview(
                        session: cameraCaptureService.session,
                        isMirrored: appModel.calibrationProfile.isWebcamMirrored
                    )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            FaceTrackingOverlayView(
                                trackedFaceState: appModel.trackedFaceState,
                                paperCalibrationState: appModel.paperCalibrationState,
                                isMirrored: appModel.calibrationProfile.isWebcamMirrored
                            )
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                        .overlay(alignment: .topLeading) {
                            CameraStatusBanner(
                                title: cameraCaptureService.isRunning ? "Live Camera" : "Starting Camera",
                                subtitle: bannerSubtitle
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
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var bannerSubtitle: String {
        if appModel.paperCalibrationState.phase != .idle {
            return appModel.paperCalibrationState.instructionText
        }

        return appModel.isUsingCoarseFallback ? "Coarse fallback tracking active" : "Vision tracking overlay active"
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
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Color.primary)
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
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.82))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.32))
        )
    }
}
