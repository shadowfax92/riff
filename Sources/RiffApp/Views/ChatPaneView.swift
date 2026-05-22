import RiffCore
import SwiftUI

struct ChatPaneView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.Color.separator)
            messages
            composer
        }
        .background(Theme.Color.chatBackground)
        .navigationSplitViewColumnWidth(min: 520, ideal: 720)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if let conversation = model.selectedConversation {
                    HStack(spacing: 6) {
                        Text("To:")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        ForEach(conversation.agents) { agent in
                            ParticipantChip(agent: agent)
                        }
                    }
                    Text(conversation.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("No Conversation")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Create or select a Riff debate.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            actionButton
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var actionButton: some View {
        if model.isRunning {
            Button {
                Task { await model.stopSelectedConversation() }
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else {
            Button {
                model.startSelectedConversation()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(model.selectedConversation == nil)
        }
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    let groups = MessageGrouping.group(entries: model.transcript)
                    ForEach(groups) { group in
                        switch group {
                        case .dateDivider(let id, let date):
                            DateDivider(date: date).id(id)
                        case .message(let entry, let showHeader):
                            MessageRow(entry: entry, showHeader: showHeader)
                                .id(entry.id)
                        }
                    }
                    if model.isRunning {
                        TypingIndicator()
                            .padding(.top, 6)
                    }
                    Color.clear.frame(height: 1).id("__bottom__")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .onChange(of: model.transcript.count) {
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo("__bottom__", anchor: .bottom)
                }
            }
            .onChange(of: model.selectedID) {
                proxy.scrollTo("__bottom__", anchor: .bottom)
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                // Reserved for attachment picker.
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Theme.Color.surfaceOverlay)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(true)
            .padding(.bottom, 2)

            TextField("Message agents", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .font(.system(size: 14))
                .onSubmit { send() }

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(sendDisabled ? Color.secondary.opacity(0.5) : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(sendDisabled)
            .padding(.bottom, 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.Color.surfaceOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.Color.surfaceStroke, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var sendDisabled: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || model.selectedConversation == nil
    }

    private func send() {
        guard !sendDisabled else { return }
        let text = draft
        draft = ""
        Task { await model.sendUserMessage(text) }
    }
}

private struct ParticipantChip: View {
    let agent: AgentProfile

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Theme.color(for: agent))
                .frame(width: 6, height: 6)
            Text(agent.name)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Theme.Color.surfaceOverlay)
        .clipShape(Capsule())
    }
}

private struct DateDivider: View {
    let date: Date

    var body: some View {
        Text(formatted)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
    }

    private var formatted: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today \(timeString)"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday \(timeString)"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct MessageRow: View {
    @EnvironmentObject private var model: AppModel
    let entry: TranscriptEntry
    let showHeader: Bool

    private var isUser: Bool { entry.speakerID == "user" }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser {
                Spacer(minLength: 60)
                bubbleColumn
            } else {
                avatar
                bubbleColumn
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, showHeader ? 6 : 1)
    }

    @ViewBuilder
    private var avatar: some View {
        if showHeader {
            AgentAvatar(
                speakerID: entry.speakerID,
                speakerName: entry.speakerName,
                runtime: entry.runtime
            )
            .padding(.top, 18)
        } else {
            Color.clear.frame(width: Theme.Metric.avatarSize)
        }
    }

    private var bubbleColumn: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            if showHeader, !isUser {
                Text(entry.speakerName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }
            bubble
            if let warning = entry.warning {
                Text(warning)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
            }
            ForEach(entry.attachments) { attachment in
                AttachmentCard(attachment: attachment)
                    .onTapGesture { Task { await openAttachment(attachment) } }
            }
        }
    }

    private var bubble: some View {
        Text(entry.error ?? entry.text)
            .font(.system(size: 14))
            .foregroundStyle(isUser ? .white : .primary)
            .textSelection(.enabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(bubbleColor)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.bubbleCorner, style: .continuous))
            .frame(maxWidth: 520, alignment: isUser ? .trailing : .leading)
    }

    private var bubbleColor: Color {
        if entry.error != nil {
            return Color.red.opacity(0.32)
        }
        return isUser ? Theme.Color.userBubble : Theme.Color.agentBubble
    }

    /// Tapping an inline attachment selects that file in the artifacts pane
    /// instead of opening it via NSWorkspace — keeps the user in the app.
    private func openAttachment(_ attachment: TranscriptAttachment) async {
        let filename = (attachment.path as NSString).lastPathComponent
        if let match = model.files.first(where: { $0.relativePath == attachment.path || $0.name == filename }) {
            await model.selectFile(match)
        }
    }
}

private struct AttachmentCard: View {
    let attachment: TranscriptAttachment

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Theme.Color.surfaceOverlay)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(filename)
                    .font(.system(size: 12, weight: .medium))
                Text("Document · MD")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            Text("Open")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.Color.surfaceOverlay)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.Color.cardStroke, lineWidth: 1)
        )
        .frame(maxWidth: 320)
    }

    private var filename: String {
        (attachment.path as NSString).lastPathComponent
    }
}

private struct TypingIndicator: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.3))
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: Theme.Metric.avatarSize, height: Theme.Metric.avatarSize)
            HStack(spacing: 4) {
                ForEach(0..<3) { idx in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(phase == idx ? 1 : 0.35)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.Color.agentBubble)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.bubbleCorner, style: .continuous))
            Spacer()
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 380_000_000)
                phase = (phase + 1) % 3
            }
        }
    }
}

/// Groups transcript entries into renderable rows: date dividers between
/// messages > 10 minutes apart, message rows with header (avatar+name) only
/// when the speaker changes or after a gap.
enum MessageGroup: Identifiable {
    case dateDivider(id: String, date: Date)
    case message(TranscriptEntry, showHeader: Bool)

    var id: String {
        switch self {
        case .dateDivider(let id, _): return "divider-\(id)"
        case .message(let entry, _): return entry.id
        }
    }
}

enum MessageGrouping {
    static func group(entries: [TranscriptEntry]) -> [MessageGroup] {
        var result: [MessageGroup] = []
        var lastEntry: TranscriptEntry?
        for entry in entries {
            let needsDivider: Bool
            if let last = lastEntry {
                needsDivider = entry.startedAt.timeIntervalSince(last.startedAt) > 600
            } else {
                needsDivider = true
            }
            if needsDivider {
                result.append(.dateDivider(id: entry.id, date: entry.startedAt))
            }
            let showHeader: Bool
            if let last = lastEntry, !needsDivider {
                showHeader = last.speakerID != entry.speakerID
            } else {
                showHeader = true
            }
            result.append(.message(entry, showHeader: showHeader))
            lastEntry = entry
        }
        return result
    }
}
