import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingNewConversation = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("riff.showFilesPane") private var showFilesPane = true
    @AppStorage("riff.appearance") private var appearanceRaw: String = AppearanceMode.system.rawValue

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(showingNewConversation: $showingNewConversation)
        } content: {
            ChatPaneView()
                .toolbar { chatToolbar }
        } detail: {
            if showFilesPane {
                FilePaneView()
            } else {
                Color.clear
                    .navigationSplitViewColumnWidth(0)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingNewConversation) {
            NewConversationSheet()
                .environmentObject(model)
        }
        .alert("Riff Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .riffNewConversation)) { _ in
            showingNewConversation = true
        }
    }

    @ToolbarContentBuilder
    private var chatToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                cycleAppearance()
            } label: {
                Image(systemName: appearance.iconName)
                    .foregroundStyle(.secondary)
            }
            .help("Appearance: \(appearance.label)")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showFilesPane.toggle()
                }
            } label: {
                Image(systemName: "sidebar.right")
                    .foregroundStyle(showFilesPane ? Color.accentColor : .secondary)
            }
            .help(showFilesPane ? "Hide Artifacts" : "Show Artifacts")
        }
    }

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    private func cycleAppearance() {
        appearanceRaw = appearance.next.rawValue
    }
}
