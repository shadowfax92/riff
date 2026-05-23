import Testing
@testable import RiffApp

@Test func filePresentationModeDefaultsToSidebarForUnknownRawValue() {
    #expect(FilePresentationMode.value(from: "bad") == .sidebar)
}

@Test func filePresentationModeLabelsMatchSettingsCopy() {
    #expect(FilePresentationMode.sidebar.label == "Sidebar")
    #expect(FilePresentationMode.popup.label == "Popup")
}
