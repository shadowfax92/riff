import SwiftUI

@main
struct RiffApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Riff") {
            RootView()
                .environmentObject(model)
                .task { await model.bootstrap() }
                .frame(minWidth: 1100, minHeight: 700)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Riff") {
                    NotificationCenter.default.post(name: .riffNewConversation, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let riffNewConversation = Notification.Name("riff.newConversation")
}
