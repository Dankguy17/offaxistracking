import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Label("Camera", systemImage: "camera")
                Label("Tracking", systemImage: "faceid")
                Label("Rendering", systemImage: "cube.transparent")
            }
            .navigationSplitViewColumnWidth(240)
        } detail: {
            VStack(spacing: 16) {
                Image(systemName: "view.3d")
                    .font(.system(size: 72))
                    .foregroundStyle(.secondary)

                Text("Head-Tracked 3D Window Playground")
                    .font(.largeTitle)

                Text("Scaffold is ready. Camera, tracking, pose estimation, and Metal rendering will be added next.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

#Preview {
    RootView()
}
