import SwiftUI

@main
struct RiffApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("riff.appearance") private var appearanceRaw: String = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup("Riff") {
            RootView()
                .environmentObject(model)
                .task { await model.bootstrap() }
                .onChange(of: scenePhase) {
                    guard scenePhase == .active else {
                        return
                    }
                    Task { await model.refreshRowsFromDisk() }
                }
                .frame(minWidth: 1100, minHeight: 700)
                .preferredColorScheme(appearance.colorScheme)
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

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }
}

extension Notification.Name {
    static let riffNewConversation = Notification.Name("riff.newConversation")
    static let riffOpenSettings = Notification.Name("riff.openSettings")
}
