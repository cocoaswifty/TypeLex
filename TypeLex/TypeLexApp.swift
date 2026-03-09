import SwiftUI

@main
struct TypeLexApp: App {
    @State private var router: AppRouter
    @State private var settings: AppSettingsStore
    @State private var vm: PracticeViewModel

    init() {
        let settings = AppSettingsStore()
        let panelService = AppPanelService()
        _router = State(initialValue: AppRouter())
        _settings = State(initialValue: settings)
        _vm = State(
            initialValue: PracticeViewModel(
                userDefaults: settings.userDefaults,
                libraryPicker: panelService,
                contentGenerator: GeminiService(),
                speechService: SpeechService.shared,
                telemetry: AppTelemetry.shared
            )
        )
    }
    
    var body: some Scene {
        WindowGroup {
            PracticeView(vm: vm, router: router, settings: settings)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .appSettings) {
                Button("\(AppStrings.settingsTitle)...") {
                    router.open(.settings)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("Practice") {
                Button(AppStrings.importLibrary) {
                    router.open(.importLibrary)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button(AppStrings.wordList) {
                    router.open(.wordList)
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("Switch Books") {
                    router.open(.bookManager)
                }
                .keyboardShortcut("b", modifiers: .command)

                Divider()

                Button(AppStrings.learningStats) {
                    router.open(.stats)
                }
                .keyboardShortcut("9", modifiers: .command)

                Button(AppStrings.keyboardShortcutsTitle) {
                    router.presentShortcutHelp()
                }
                .keyboardShortcut("/", modifiers: .command)
            }
        }
    }
}
