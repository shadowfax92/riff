import RiffCore
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showingNewConversation: Bool
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            if filteredRows.isEmpty {
                emptyState
            } else {
                conversationList
            }
        }
        .background(Theme.Color.sidebarBackground)
        .navigationSplitViewColumnWidth(min: 240, ideal: Theme.Metric.sidebarWidth, max: 360)
    }

    private var header: some View {
        HStack {
            Spacer()
            Button {
                showingNewConversation = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("New Riff")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.Color.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.Color.inputStroke, lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(search.isEmpty ? "No Riffs Yet" : "No Matches")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            if search.isEmpty {
                Button("New Riff") {
                    showingNewConversation = true
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredRows) { row in
                    ConversationListRow(row: row, isSelected: row.id == model.selectedID)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task { await model.select(row) }
                        }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
    }

    private var filteredRows: [ConversationRow] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return model.rows }
        return model.rows.filter { row in
            row.conversation.title.lowercased().contains(query)
                || row.preview.lowercased().contains(query)
        }
    }
}

private struct ConversationListRow: View {
    let row: ConversationRow
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AgentAvatarStack(agents: row.conversation.agents, size: Theme.Metric.sidebarAvatarSize)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.conversation.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(timestamp)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(row.preview.isEmpty ? row.conversation.prompt : row.preview)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if row.conversation.status == .running {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Running")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Theme.Color.sidebarRowSelected : Color.clear)
        )
    }

    private var timestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: row.conversation.createdAt, relativeTo: Date())
    }
}
