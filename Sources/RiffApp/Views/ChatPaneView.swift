import RiffCore
import SwiftUI

struct ChatPaneView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.transcript) { entry in
                            MessageBubble(entry: entry)
                                .id(entry.id)
                        }
                        if model.isRunning {
                            TypingBubble()
                        }
                    }
                    .padding(18)
                }
                .onChange(of: model.transcript.count) {
                    if let last = model.transcript.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            Divider()
            composer
        }
        .navigationSplitViewColumnWidth(min: 480, ideal: 680)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.selectedConversation?.title ?? "No Conversation")
                    .font(.system(size: 17, weight: .semibold))
                Text(model.selectedConversation?.prompt ?? "Create or select a Riff debate.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if model.isRunning {
                Button {
                    Task {
                        await model.stopSelectedConversation()
                    }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    model.startSelectedConversation()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedConversation == nil)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message agents", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onSubmit {
                    send()
                }
            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 26))
            }
            .buttonStyle(.plain)
            .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.blue)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.selectedConversation == nil)
        }
        .padding(14)
    }

    private func send() {
        let text = draft
        draft = ""
        Task {
            await model.sendUserMessage(text)
        }
    }
}

private struct MessageBubble: View {
    let entry: TranscriptEntry

    private var isUser: Bool {
        entry.speakerID == "user"
    }

    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 80)
            }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if !isUser {
                    Text(entry.speakerName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                }
                Text(entry.error ?? entry.text)
                    .font(.system(size: 14))
                    .foregroundStyle(isUser ? .white : .primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        bubbleColor,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                if let warning = entry.warning {
                    Text(warning)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                }
                if !entry.attachments.isEmpty {
                    Text(entry.attachments.map(\.path).joined(separator: ", "))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                }
            }
            if !isUser {
                Spacer(minLength: 80)
            }
        }
    }

    private var bubbleColor: Color {
        if entry.error != nil {
            return Color.red.opacity(0.22)
        }
        return isUser ? Color.blue : Color(nsColor: .tertiarySystemFill)
    }
}

private struct TypingBubble: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Agents")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                Text("Thinking...")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 18))
            }
            Spacer(minLength: 80)
        }
    }
}
