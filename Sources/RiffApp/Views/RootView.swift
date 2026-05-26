import RiffCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingNewConversation = false
    @State private var showingSettings = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("riff.showFilesPane") private var showFilesPane = true
    @AppStorage("riff.appearance") private var appearanceRaw: String = AppearanceMode.system.rawValue
    @AppStorage("riff.filePresentationMode") private var filePresentationModeRaw = FilePresentationMode.sidebar.rawValue

    var body: some View {
        GeometryReader { geometry in
            rootContent(containerSize: geometry.size)
        }
    }

    private func rootContent(containerSize: CGSize) -> some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(showingNewConversation: $showingNewConversation)
        } content: {
            ChatPaneView()
        } detail: {
            if showFilesPane {
                FilePaneView(
                    presentationMode: filePresentationMode,
                    openFile: openFile,
                    popOut: popOutSelectedFile
                )
            } else {
                Color.clear
                    .navigationSplitViewColumnWidth(0)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar { appToolbar }
        .sheet(isPresented: $showingNewConversation) {
            NewConversationSheet {
                showingNewConversation = false
                DispatchQueue.main.async {
                    showingSettings = true
                }
            }
                .environmentObject(model)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
                .environmentObject(model)
        }
        .sheet(isPresented: popupFileBinding) {
            if let file = model.selectedFile {
                MarkdownFileReaderView(
                    file: file,
                    markdown: model.selectedMarkdown,
                    mode: .popup,
                    onDock: dockPopupFile,
                    onClose: { model.selectedFile = nil }
                )
                .frame(width: popupSize(for: containerSize).width, height: popupSize(for: containerSize).height)
                .presentationSizing(.fitted)
                .environmentObject(model)
            }
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
        .onReceive(NotificationCenter.default.publisher(for: .riffOpenSettings)) { _ in
            showingSettings = true
        }
    }

    @ToolbarContentBuilder
    private var appToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .help("Settings")
        }
        ToolbarItem(placement: .navigation) {
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

    private var filePresentationMode: FilePresentationMode {
        FilePresentationMode.value(from: filePresentationModeRaw)
    }

    private var popupFileBinding: Binding<Bool> {
        Binding {
            filePresentationMode == .popup && model.selectedFile != nil
        } set: { isPresented in
            if !isPresented, filePresentationMode == .popup {
                model.selectedFile = nil
            }
        }
    }

    private func popupSize(for containerSize: CGSize) -> CGSize {
        FilePresentationMode.popupSize(for: containerSize)
    }

    private func cycleAppearance() {
        appearanceRaw = appearance.next.rawValue
    }

    private func openFile(_ file: ConversationFile) {
        if filePresentationMode == .sidebar {
            withAnimation(.easeInOut(duration: 0.18)) {
                showFilesPane = true
            }
        }
        Task { await model.selectFile(file) }
    }

    private func popOutSelectedFile() {
        filePresentationModeRaw = FilePresentationMode.popup.rawValue
        withAnimation(.easeInOut(duration: 0.18)) {
            showFilesPane = false
        }
    }

    private func dockPopupFile() {
        filePresentationModeRaw = FilePresentationMode.sidebar.rawValue
        withAnimation(.easeInOut(duration: 0.18)) {
            showFilesPane = true
        }
    }
}
