import MetalKit
import SwiftUI

struct MetalViewport: NSViewRepresentable {
    let renderer: MetalRenderer

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        renderer.configure(view: view)
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        renderer.configure(view: nsView)
    }
}
