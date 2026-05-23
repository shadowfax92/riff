import CoreGraphics

enum FilePresentationMode: String, CaseIterable, Identifiable {
    case sidebar
    case popup

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sidebar: return "Sidebar"
        case .popup: return "Popup"
        }
    }

    static func value(from rawValue: String) -> FilePresentationMode {
        FilePresentationMode(rawValue: rawValue) ?? .sidebar
    }

    static func popupSize(for containerSize: CGSize) -> CGSize {
        CGSize(width: containerSize.width * 0.9, height: containerSize.height * 0.9)
    }
}
