import AVFoundation
import QuartzCore
import SwiftUI

struct CameraSessionPreview: NSViewRepresentable {
    let session: AVCaptureSession
    let isMirrored: Bool

    func makeNSView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        view.applyMirroring(isMirrored)
        return view
    }

    func updateNSView(_ nsView: PreviewContainerView, context: Context) {
        nsView.previewLayer.session = session
        nsView.applyMirroring(isMirrored)
    }
}

final class PreviewContainerView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        previewLayer.frame = bounds
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }

    func applyMirroring(_ isMirrored: Bool) {
        guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else {
            return
        }

        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = isMirrored
    }
}
