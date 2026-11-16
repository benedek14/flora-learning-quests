import Foundation

enum Config {
    /// Where the quests live (GitHub Pages). To change or add quests, edit the files in the project folder
    /// and run ./publish.sh — the app downloads the new versions on its next launch. No app rebuild needed.
    static let siteURL = URL(string: "https://benedek14.github.io/flora-learning-quests/")!

    /// After the app has been in the background this long, it checks for newer quests when reopened.
    static let refreshAfter: TimeInterval = 30 * 60
}
