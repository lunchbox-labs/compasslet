import CompassCore
import Foundation
import Testing

@Test func theShortcutsLinkOpensTheWebsitesShortcutsPage() throws {
  let repository = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  // The site publishes each docs page under its file name at the site's own address.
  let config = try String(
    contentsOf: repository.appendingPathComponent("website/zensical.toml"), encoding: .utf8)
  let siteLine = try #require(
    config.split(whereSeparator: \.isNewline).first { $0.hasPrefix("site_url = ") })
  let siteURL = try #require(siteLine.split(separator: "\"").dropFirst().first)
  #expect(Website.shortcutsURL?.absoluteString == "\(siteURL)shortcuts/")
  let page = repository.appendingPathComponent("website/docs/shortcuts.md")
  #expect(FileManager.default.fileExists(atPath: page.path))
}
