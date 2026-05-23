import SwiftUI

/// Multi-line text input where Enter inserts a newline.
///
/// SwiftUI's `TextField(..., axis: .vertical)` on macOS reserves Enter for
/// submit-style behavior, forcing users to press Option+Enter for a new
/// line. `TextEditor` has the natural Mac behavior we want (Enter = new
/// line) but ships with no placeholder support, so this wraps it with a
/// faded placeholder overlay that disappears once the user starts typing.
struct MultilineTextField: View {
    let placeholder: String
    @Binding var text: String
    var font: Font = .system(size: 14)
    var minHeight: CGFloat = 64
    var maxHeight: CGFloat = 200

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(font)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight, maxHeight: maxHeight)
        }
    }
}
