import SwiftUI

struct RiffWindowRoot: View {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("riff.appearance") private var appearanceRaw: String = AppearanceMode.system.rawValue

    let initialConversationID: String?
    @State private var didBootstrap = false

    var body: some View {
        RootView()
            .environmentObject(model)
            .task(id: initialConversationID) {
                await bootstrapIfNeeded()
                if let initialConversationID {
                    await model.selectConversation(id: initialConversationID)
                }
            }
            .onChange(of: scenePhase) {
                guard scenePhase == .active else {
                    return
                }
                Task { await model.refreshRowsFromDisk() }
            }
            .frame(minWidth: 1100, minHeight: 700)
            .preferredColorScheme(appearance.colorScheme)
    }

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    private func bootstrapIfNeeded() async {
        guard !didBootstrap else {
            return
        }
        didBootstrap = true
        await model.bootstrap()
    }
}
