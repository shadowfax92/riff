import MarkdownUI
import RiffCore
import SwiftUI

struct ChatPaneView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = ""
    @State private var lastTranscriptCount = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.Color.separator)
            messages
            composerArea
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
        HStack(spacing: 8) {
            if model.isSelectedConversationRunning {
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
                    Label(model.transcript.isEmpty ? "Start" : "Resume", systemImage: "play.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(model.selectedConversation == nil || model.isSelectedConversationSummarizing)
            }

            Button {
                model.summarizeSelectedConversation()
            } label: {
                Label(model.isSelectedConversationSummarizing ? "Summarizing" : "Summarize", systemImage: "text.bubble")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(model.selectedConversation == nil || model.transcript.isEmpty || model.isSelectedConversationSummarizing)
        }
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    Color.clear.frame(height: 1).id("__top__")
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
                    if let active = model.selectedActiveTurn {
                        ThinkingIndicator(state: active)
                            .padding(.top, 6)
                            .id("__thinking__")
                    }
                    Color.clear.frame(height: 1).id("__bottom__")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .onChange(of: model.transcript.count) {
                let newCount = model.transcript.count
                let target = ChatScrollPolicy.target(
                    for: .transcriptAppended(
                        previousCount: lastTranscriptCount,
                        currentCount: newCount,
                        latestSpeakerID: model.transcript.last?.speakerID
                    )
                )
                lastTranscriptCount = newCount
                if target == .top {
                    scrollToTop(proxy, animated: false)
                } else if target == .bottom {
                    scrollToBottom(proxy, animated: true)
                }
            }
            .onChange(of: model.selectedID) {
                guard ChatScrollPolicy.target(for: .selectedConversationChanged) == .bottom else {
                    return
                }
                lastTranscriptCount = 0
                DispatchQueue.main.async {
                    lastTranscriptCount = model.transcript.count
                    scrollToBottom(proxy, animated: false)
                }
            }
            .onAppear {
                lastTranscriptCount = model.transcript.count
            }
        }
    }

    private var composerArea: some View {
        VStack(spacing: 8) {
            steerQueueBar
            composer
        }
    }

    @ViewBuilder
    private var steerQueueBar: some View {
        if let pending = selectedPendingSteer {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22, height: 22)
                    .background(Theme.Color.inputChipBackground)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pending.count) steer \(pending.count == 1 ? "message" : "messages") queued")
                        .font(.system(size: 12, weight: .semibold))
                    Text(pending.latestText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 10)
                Button {
                    model.applyPendingSteer()
                } label: {
                    Label("Steer", systemImage: "arrow.turn.down.right")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .disabled(model.isSelectedApplyingSteer)
                Button {
                    model.clearPendingSteer()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .disabled(model.isSelectedApplyingSteer)
                .help("Clear queued steer messages")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.Color.cardStroke, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }

    private var composer: some View {
        HStack(alignment: .center, spacing: 8) {
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.Color.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.Color.inputStroke, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, selectedPendingSteer == nil ? 12 : 0)
        .padding(.bottom, 12)
    }

    private var selectedPendingSteer: PendingSteer? {
        model.selectedPendingSteer
    }

    private var sendDisabled: Bool {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || model.selectedConversation == nil
    }

    private func send() {
        guard !sendDisabled else { return }
        let text = draft
        draft = ""
        model.sendUserMessage(text)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo("__bottom__", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("__bottom__", anchor: .bottom)
        }
    }

    private func scrollToTop(_ proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo("__top__", anchor: .top)
            }
        } else {
            proxy.scrollTo("__top__", anchor: .top)
        }
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
    private var isSummary: Bool { entry.speakerID == "summary" }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser {
                Spacer(minLength: 60)
            } else {
                avatar
            }
            bubbleColumn
        }
        .padding(.vertical, showHeader ? 6 : 1)
    }

    @ViewBuilder
    private var avatar: some View {
        if showHeader {
            // Prefer the AgentProfile-based init when the speaker matches a
            // configured agent — it pulls through the emoji and consistent
            // color. Falls back to the speaker-id form for legacy entries
            // (e.g., from before emojis existed on AgentProfile).
            if let agent = model.selectedConversation?.agents.first(where: { $0.id == entry.speakerID }) {
                AgentAvatar(agent: agent)
                    .padding(.top, 18)
            } else {
                AgentAvatar(
                    speakerID: entry.speakerID,
                    speakerName: entry.speakerName,
                    runtime: entry.runtime
                )
                .padding(.top, 18)
            }
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
            if let wordCount = wordCountLabel {
                Text(wordCount)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
            }
            ForEach(entry.attachments) { attachment in
                AttachmentCard(attachment: attachment)
                    .onTapGesture { Task { await openAttachment(attachment) } }
            }
        }
        .frame(maxWidth: isUser ? nil : .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var bubble: some View {
        bubbleContent
            .textSelection(.enabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: isUser ? 520 : .infinity, alignment: .leading)
            .background(bubbleColor)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.bubbleCorner, style: .continuous))
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if isUser {
            Text(entry.error ?? entry.text)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .lineSpacing(2)
        } else {
            Markdown(entry.error ?? entry.text)
                .markdownTheme(.bubble(isUser: false))
        }
    }

    private var bubbleColor: Color {
        if entry.error != nil {
            return Color.red.opacity(0.32)
        }
        if isSummary {
            return Theme.Color.summaryBubble
        }
        return isUser ? Theme.Color.userBubble : Theme.Color.agentBubble
    }

    /// User, summary, and error bubbles get no word count; only normal agent turns do.
    private var wordCountLabel: String? {
        guard !isUser, !isSummary, entry.error == nil else { return nil }
        let count = entry.text.split(whereSeparator: \.isWhitespace).count
        guard count > 0 else { return nil }
        return "\(count) words"
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

/// Live "thinking" row shown while a CLI turn is in flight. Renders the
/// active agent's avatar + name, a pulsing dot animation, the elapsed wall
/// time (auto-ticking via TimelineView, no Timer needed), and a chevron
/// that toggles the list of tool/event labels we've collected so far.
/// Collapsed by default so it stays unobtrusive — Codex-style.
private struct ThinkingIndicator: View {
    let state: ActiveTurnState
    @State private var expanded = false
    @State private var dotPhase = 0

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            AgentAvatar(
                speakerID: state.agent.id,
                speakerName: state.agent.name,
                runtime: state.agent.runtime
            )
            .padding(.top, 4)
            VStack(alignment: .leading, spacing: 6) {
                Text(state.agent.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        expanded.toggle()
                    }
                } label: {
                    bubble
                }
                .buttonStyle(.plain)
                if expanded, !state.events.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(state.events.indices, id: \.self) { idx in
                            HStack(spacing: 6) {
                                Image(systemName: "wrench.adjustable")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                Text(state.events[idx])
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 60)
        }
        .task { await animateDots() }
    }

    private var bubble: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<3) { idx in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 5, height: 5)
                        .opacity(dotPhase == idx ? 1.0 : 0.35)
                }
            }
            TimelineView(.periodic(from: state.startedAt, by: 1)) { context in
                Text(label(elapsed: context.date.timeIntervalSince(state.startedAt)))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Theme.Color.agentBubble)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.bubbleCorner, style: .continuous))
    }

    private func label(elapsed seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        if total < 60 {
            return "Thinking · \(total)s"
        }
        let minutes = total / 60
        let secs = total % 60
        return String(format: "Thinking · %dm %02ds", minutes, secs)
    }

    private func animateDots() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 380_000_000)
            dotPhase = (dotPhase + 1) % 3
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
