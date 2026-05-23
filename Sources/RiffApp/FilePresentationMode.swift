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
}
