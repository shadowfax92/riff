import AppKit
import SwiftUI
import RiffCore

enum Theme {
    enum Color {
        static let appBackground = dynamic(
            light: SwiftUI.Color(white: 1.0),
            dark: SwiftUI.Color(red: 0.12, green: 0.12, blue: 0.13)
        )
        static let sidebarBackground = dynamic(
            light: SwiftUI.Color(red: 0.96, green: 0.96, blue: 0.97),
            dark: SwiftUI.Color(red: 0.10, green: 0.10, blue: 0.11)
        )
        static let chatBackground = dynamic(
            light: SwiftUI.Color(white: 1.0),
            dark: SwiftUI.Color(red: 0.12, green: 0.12, blue: 0.13)
        )
        static let filesBackground = dynamic(
            light: SwiftUI.Color(red: 0.96, green: 0.96, blue: 0.97),
            dark: SwiftUI.Color(red: 0.10, green: 0.10, blue: 0.11)
        )

        static let userBubble = SwiftUI.Color(red: 0.0, green: 0.48, blue: 1.0)
        static let agentBubble = dynamic(
            light: SwiftUI.Color(red: 0.91, green: 0.91, blue: 0.93),
            dark: SwiftUI.Color(red: 0.23, green: 0.23, blue: 0.24)
        )

        static let sidebarRowSelected = SwiftUI.Color.accentColor.opacity(0.22)
        static let cardBackground = dynamic(
            light: SwiftUI.Color(white: 0.985),
            dark: SwiftUI.Color(red: 0.16, green: 0.16, blue: 0.17)
        )
        static let cardStroke = dynamic(
            light: SwiftUI.Color.black.opacity(0.08),
            dark: SwiftUI.Color.white.opacity(0.06)
        )
        static let separator = dynamic(
            light: SwiftUI.Color.black.opacity(0.10),
            dark: SwiftUI.Color.white.opacity(0.06)
        )
        static let surfaceOverlay = dynamic(
            light: SwiftUI.Color.black.opacity(0.045),
            dark: SwiftUI.Color.white.opacity(0.06)
        )
        static let surfaceStroke = dynamic(
            light: SwiftUI.Color.black.opacity(0.10),
            dark: SwiftUI.Color.white.opacity(0.08)
        )

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

    /// Builds an NSAppearance-aware color so a single token resolves to the
    /// right value when the user flips between light/dark via the toolbar.
    private static func dynamic(light: SwiftUI.Color, dark: SwiftUI.Color) -> SwiftUI.Color {
        SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
            switch appearance.name {
            case .darkAqua,
                 .vibrantDark,
                 .accessibilityHighContrastDarkAqua,
                 .accessibilityHighContrastVibrantDark:
                return NSColor(dark)
            default:
                return NSColor(light)
            }
        })
    }
}

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var next: AppearanceMode {
        switch self {
        case .system: return .light
        case .light: return .dark
        case .dark: return .system
        }
    }
}
