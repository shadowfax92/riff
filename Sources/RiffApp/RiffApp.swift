import SwiftUI

@main
struct RiffApp: App {
    var body: some Scene {
        WindowGroup("Riff") {
            RiffWindowRoot(initialConversationID: nil)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1280, height: 800)

        WindowGroup("Riff Chat", for: ConversationWindowRoute.self) { route in
            RiffWindowRoot(initialConversationID: route.wrappedValue?.conversationID)
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
    static let riffOpenSettings = Notification.Name("riff.openSettings")
}
