import SwiftUI
import RiffCore

enum Theme {
    enum Color {
        static let appBackground = SwiftUI.Color(nsColor: .windowBackgroundColor)
        static let sidebarBackground = SwiftUI.Color(red: 0.10, green: 0.10, blue: 0.11)
        static let chatBackground = SwiftUI.Color(red: 0.12, green: 0.12, blue: 0.13)
        static let filesBackground = SwiftUI.Color(red: 0.10, green: 0.10, blue: 0.11)

        static let userBubble = SwiftUI.Color(red: 0.0, green: 0.48, blue: 1.0)
        static let agentBubble = SwiftUI.Color(red: 0.23, green: 0.23, blue: 0.24)

        static let sidebarRowSelected = SwiftUI.Color.accentColor.opacity(0.22)
        static let cardBackground = SwiftUI.Color(red: 0.16, green: 0.16, blue: 0.17)
        static let cardStroke = SwiftUI.Color.white.opacity(0.06)
        static let separator = SwiftUI.Color.white.opacity(0.06)

        static let secondary = SwiftUI.Color.secondary
        static let placeholder = SwiftUI.Color.secondary.opacity(0.7)
    }

    enum Metric {
        static let bubbleCorner: CGFloat = 18
        static let bubbleMaxWidthFraction: CGFloat = 0.66
        static let avatarSize: CGFloat = 28
        static let sidebarAvatarSize: CGFloat = 38
        static let sidebarWidth: CGFloat = 280
        static let filesWidth: CGFloat = 360
    }

    /// Stable color for an agent based on runtime + id so the same agent
    /// always paints the same color across sidebar, avatars, and bubbles.
    static func color(for agent: AgentProfile) -> SwiftUI.Color {
        if let preset = runtimePreset[agent.runtime] {
            return preset
        }
        return paletteColor(for: agent.id)
    }

    static func color(forSpeakerID id: String, runtime: RuntimeID?) -> SwiftUI.Color {
        if id == "user" {
            return Theme.Color.userBubble
        }
        if let runtime, let preset = runtimePreset[runtime] {
            return preset
        }
        return paletteColor(for: id)
    }

    private static let runtimePreset: [RuntimeID: SwiftUI.Color] = [
        .claude: SwiftUI.Color(red: 0.85, green: 0.46, blue: 0.34),
        .codex: SwiftUI.Color(red: 0.40, green: 0.69, blue: 0.55),
    ]

    private static let palette: [SwiftUI.Color] = [
        SwiftUI.Color(red: 0.85, green: 0.46, blue: 0.34),
        SwiftUI.Color(red: 0.40, green: 0.69, blue: 0.55),
        SwiftUI.Color(red: 0.43, green: 0.55, blue: 0.92),
        SwiftUI.Color(red: 0.78, green: 0.50, blue: 0.85),
        SwiftUI.Color(red: 0.93, green: 0.74, blue: 0.35),
        SwiftUI.Color(red: 0.43, green: 0.78, blue: 0.91),
    ]

    private static func paletteColor(for key: String) -> SwiftUI.Color {
        let hash = key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[abs(hash) % palette.count]
    }
}
