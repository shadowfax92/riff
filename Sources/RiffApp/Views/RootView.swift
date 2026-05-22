import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingNewConversation = false

    var body: some View {
        NavigationSplitView {
            SidebarView(showingNewConversation: $showingNewConversation)
        } content: {
            ChatPaneView()
        } detail: {
            FilePaneView()
        }
        .sheet(isPresented: $showingNewConversation) {
            NewConversationSheet()
                .environmentObject(model)
        }
        .alert("Riff Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
