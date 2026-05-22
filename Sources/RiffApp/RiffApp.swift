import SwiftUI

@main
struct RiffApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .task {
                    await model.bootstrap()
                }
                .frame(minWidth: 1120, minHeight: 720)
        }
    }
}
