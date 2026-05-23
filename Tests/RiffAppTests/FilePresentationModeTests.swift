import Testing
import CoreGraphics
@testable import RiffApp

@Test func filePresentationModeDefaultsToSidebarForUnknownRawValue() {
    #expect(FilePresentationMode.value(from: "bad") == .sidebar)
}

@Test func filePresentationModeLabelsMatchSettingsCopy() {
    #expect(FilePresentationMode.sidebar.label == "Sidebar")
    #expect(FilePresentationMode.popup.label == "Popup")
}

@Test func popupSizeUsesNinetyPercentOfContainer() {
    let size = FilePresentationMode.popupSize(for: CGSize(width: 1000, height: 800))

    #expect(size.width == 900)
    #expect(size.height == 720)
}
