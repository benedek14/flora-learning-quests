import Foundation

enum Config {
    /// Where the game lives. Change the game by editing ../index.html and running ./publish.sh —
    /// the app downloads the new version on its next launch. No app rebuild needed.
    static let gameURL = URL(string: "https://benedek14.github.io/flora-fraction-quest/")!

    /// After the app has been in the background this long, it checks for a newer game when reopened.
    static let refreshAfter: TimeInterval = 30 * 60
}
