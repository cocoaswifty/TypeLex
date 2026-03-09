import Observation

@Observable
@MainActor
final class AppRouter {
    var activeSheet: SheetDestination?
    var showShortcutHelp = false
    var showLargeImage = false

    func open(_ destination: SheetDestination) {
        activeSheet = destination
    }

    func dismissSheet() {
        activeSheet = nil
    }

    func presentShortcutHelp() {
        showShortcutHelp = true
    }

    func dismissShortcutHelp() {
        showShortcutHelp = false
    }

    func presentLargeImage() {
        showLargeImage = true
    }

    func dismissLargeImage() {
        showLargeImage = false
    }
}
