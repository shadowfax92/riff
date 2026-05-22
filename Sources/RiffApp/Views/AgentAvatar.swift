import RiffCore
import SwiftUI

/// Circular avatar with one or two letters, tinted by Theme.color(for:).
/// Used in both the sidebar row and inline next to chat bubbles.
struct AgentAvatar: View {
    let initials: String
    let color: Color
    var size: CGFloat = Theme.Metric.avatarSize

    var body: some View {
        Circle()
            .fill(color)
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
    }
}

extension AgentAvatar {
    init(agent: AgentProfile, size: CGFloat = Theme.Metric.avatarSize) {
        self.init(
            initials: AgentAvatar.initials(from: agent.name),
            color: Theme.color(for: agent),
            size: size
        )
    }

    init(speakerID: String, speakerName: String, runtime: RuntimeID?, size: CGFloat = Theme.Metric.avatarSize) {
        self.init(
            initials: AgentAvatar.initials(from: speakerName),
            color: Theme.color(forSpeakerID: speakerID, runtime: runtime),
            size: size
        )
    }

    static func initials(from name: String) -> String {
        let parts = name
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .prefix(2)
        let letters = parts.compactMap { $0.first }
        if letters.isEmpty { return "?" }
        return letters.map { String($0).uppercased() }.joined()
    }
}

/// Stack of up to three avatars (used in sidebar to represent multi-agent
/// conversations the way iMessage stacks group-chat thumbnails).
struct AgentAvatarStack: View {
    let agents: [AgentProfile]
    var size: CGFloat = Theme.Metric.sidebarAvatarSize

    var body: some View {
        ZStack {
            switch agents.prefix(3).count {
            case 0:
                Circle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: size, height: size)
            case 1:
                AgentAvatar(agent: agents[0], size: size)
            case 2:
                AgentAvatar(agent: agents[0], size: size * 0.72)
                    .offset(x: -size * 0.18, y: -size * 0.12)
                AgentAvatar(agent: agents[1], size: size * 0.72)
                    .offset(x: size * 0.18, y: size * 0.12)
            default:
                AgentAvatar(agent: agents[0], size: size * 0.6)
                    .offset(x: -size * 0.22, y: -size * 0.18)
                AgentAvatar(agent: agents[1], size: size * 0.6)
                    .offset(x: size * 0.22, y: -size * 0.18)
                AgentAvatar(agent: agents[2], size: size * 0.6)
                    .offset(x: 0, y: size * 0.22)
            }
        }
        .frame(width: size, height: size)
    }
}
