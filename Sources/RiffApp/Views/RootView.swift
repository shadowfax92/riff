import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingNewConversation = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("riff.showFilesPane") private var showFilesPane = true

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(showingNewConversation: $showingNewConversation)
        } content: {
            ChatPaneView()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showFilesPane.toggle()
                            }
                        } label: {
                            Image(systemName: showFilesPane ? "sidebar.right" : "sidebar.right")
                                .foregroundStyle(showFilesPane ? Color.accentColor : .secondary)
                        }
                        .help(showFilesPane ? "Hide Artifacts" : "Show Artifacts")
                    }
                }
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
}
