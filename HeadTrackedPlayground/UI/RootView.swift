import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Head-Tracked 3D Window Playground")
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text("Prototype shell with persistent calibration state, debug controls, and placeholders for the camera and Metal pipelines.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                CameraPanelPlaceholderView(cameraCaptureService: appModel.cameraCaptureService)
                RendererPanelPlaceholderView()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider()

            InspectorPanel()
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.93, blue: 0.89),
                    Color(red: 0.88, green: 0.86, blue: 0.82)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .task {
            appModel.startServices()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppModel())
}
