import SwiftUI

@main
struct HeadTrackedPlaygroundApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .frame(minWidth: 1200, minHeight: 720)
        }
        .windowResizability(.contentSize)
    }
}
