import MarkdownUI
import SwiftUI

extension MarkdownUI.Theme {
    /// Tight markdown theme for chat bubbles. Tones down heading sizes so
    /// `# Heading` text in an agent's output doesn't dominate the bubble,
    /// and switches base/link colors based on whether the bubble is the
    /// blue user bubble (white text) or the gray agent bubble (primary).
    static func bubble(isUser: Bool) -> MarkdownUI.Theme {
        let bodyColor: SwiftUI.Color = isUser ? .white : .primary
        let linkColor: SwiftUI.Color = isUser ? .white : .accentColor
        let codeBg: SwiftUI.Color = isUser ? .white.opacity(0.18) : .gray.opacity(0.22)
        let quoteRail: SwiftUI.Color = isUser ? .white.opacity(0.4) : .secondary.opacity(0.5)
        let codeBlockBg: SwiftUI.Color = isUser ? .white.opacity(0.12) : .black.opacity(0.18)

        return MarkdownUI.Theme()
            .text {
                FontSize(14)
                ForegroundColor(bodyColor)
            }
            .strong { FontWeight(.semibold) }
            .emphasis { FontStyle(.italic) }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.88))
                BackgroundColor(codeBg)
            }
            .link {
                ForegroundColor(linkColor)
                UnderlineStyle(.single)
            }
            .paragraph { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.18))
                    .markdownMargin(top: 0, bottom: 10)
            }
            .heading1 { configuration in
                configuration.label
                    .markdownMargin(top: 6, bottom: 4)
                    .markdownTextStyle {
                        FontSize(.em(1.2))
                        FontWeight(.semibold)
                    }
            }
            .heading2 { configuration in
                configuration.label
                    .markdownMargin(top: 6, bottom: 4)
                    .markdownTextStyle {
                        FontSize(.em(1.12))
                        FontWeight(.semibold)
                    }
            }
            .heading3 { configuration in
                configuration.label
                    .markdownMargin(top: 4, bottom: 2)
                    .markdownTextStyle {
                        FontSize(.em(1.05))
                        FontWeight(.semibold)
                    }
            }
            .listItem { configuration in
                configuration.label
                    .markdownMargin(top: .em(0.15))
            }
            .blockquote { configuration in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(quoteRail)
                        .frame(width: 3)
                    configuration.label
                        .padding(.leading, 10)
                        .markdownTextStyle {
                            FontStyle(.italic)
                        }
                }
            }
            .codeBlock { configuration in
                configuration.label
                    .padding(10)
                    .background(codeBlockBg)
                    .cornerRadius(6)
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.88))
                    }
            }
    }
}
