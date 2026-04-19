import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Head-Tracked 3D Window Playground")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.16, green: 0.17, blue: 0.14))

                    Text("Live webcam tracking, calibrated pose estimation, and a Metal off-axis viewport for evaluating head-tracked parallax.")
                        .foregroundStyle(Color(red: 0.32, green: 0.33, blue: 0.31))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                CameraPanelPlaceholderView(cameraCaptureService: appModel.cameraCaptureService)
                RendererPanelPlaceholderView(metalRenderer: appModel.metalRenderer)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider()

            InspectorPanel()
        }
        .foregroundStyle(Color(red: 0.17, green: 0.18, blue: 0.19))
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
