import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showingNewConversation: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Riff")
                    .font(.system(size: 22, weight: .semibold))
                Spacer()
                Button {
                    showingNewConversation = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.borderless)
                .help("New conversation")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            List(model.rows, selection: $model.selectedID) { row in
                ConversationListRow(row: row)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task {
                            await model.select(row)
                        }
                    }
            }
            .listStyle(.sidebar)
        }
        .navigationSplitViewColumnWidth(min: 250, ideal: 280)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct ConversationListRow: View {
    let row: ConversationRow

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(row.conversation.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                statusDot
            }
            Text(row.preview)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 6)
    }

    private var statusDot: some View {
        Circle()
            .fill(row.conversation.status == .running ? Color.green : Color.secondary.opacity(0.55))
            .frame(width: 7, height: 7)
    }
}
