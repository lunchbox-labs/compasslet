import CompassCore
import Foundation
import Testing

@Test func theShortcutsLinkOpensTheWebsitesShortcutsPage() throws {
  #expect(
    Website.shortcutsURL?.absoluteString == "https://compasslet.lunchbox-labs.dev/shortcuts/")
  // The site publishes each docs page at its file name, so the link breaks if the page moves.
  let page = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("website/docs/shortcuts.md")
  #expect(FileManager.default.fileExists(atPath: page.path))
}
