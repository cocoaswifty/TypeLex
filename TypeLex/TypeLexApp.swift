import SwiftUI

@main
struct TypeLexApp: App {
    @State private var vm = PracticeViewModel()
    
    var body: some Scene {
        WindowGroup {
            PracticeView(vm: vm)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .typeLexOpenSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("Practice") {
                Button("Import Library") {
                    NotificationCenter.default.post(name: .typeLexOpenImportLibrary, object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Word List") {
                    NotificationCenter.default.post(name: .typeLexOpenWordList, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("Switch Books") {
                    NotificationCenter.default.post(name: .typeLexOpenBookManager, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)

                Divider()

                Button("Learning Stats") {
                    NotificationCenter.default.post(name: .typeLexOpenStats, object: nil)
                }
                .keyboardShortcut("9", modifiers: .command)

                Button("Keyboard Shortcuts") {
                    NotificationCenter.default.post(name: .typeLexShowShortcutHelp, object: nil)
                }
                .keyboardShortcut("/", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let typeLexOpenImportLibrary = Notification.Name("TypeLex.OpenImportLibrary")
    static let typeLexOpenWordList = Notification.Name("TypeLex.OpenWordList")
    static let typeLexOpenSettings = Notification.Name("TypeLex.OpenSettings")
    static let typeLexOpenBookManager = Notification.Name("TypeLex.OpenBookManager")
    static let typeLexOpenStats = Notification.Name("TypeLex.OpenStats")
    static let typeLexShowShortcutHelp = Notification.Name("TypeLex.ShowShortcutHelp")
}
