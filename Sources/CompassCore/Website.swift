import Foundation

/// Compasslet's website, for the app's links to its pages.
public enum Website {
  private static let address = "https://compasslet.lunchbox-labs.dev"

  /// The page with the shortcuts that start and end the Live Activity with CarPlay, published
  /// from `website/docs/shortcuts.md`.
  public static var shortcutsURL: URL? { URL(string: "\(address)/shortcuts/") }
}
