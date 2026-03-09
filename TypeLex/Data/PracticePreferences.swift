import Foundation

enum PreferenceKeys {
    static let wordPlaybackCount = "wordPlaybackCount"
    static let wordPlaybackDelay = "wordPlaybackDelay"
    static let autoPlayExampleAudio = "autoPlayExampleAudio"
    static let showTranslations = "showTranslations"
    static let showExampleTranslation = "showExampleTranslation"
    static let defaultPracticeMode = "defaultPracticeMode"
}

struct PracticePreferences {
    let wordPlaybackCount: Int
    let wordPlaybackDelay: Double
    let autoPlayExampleAudio: Bool
    let showTranslations: Bool
    let showExampleTranslation: Bool
    let defaultPracticeMode: String

    static func load(using defaults: UserDefaults = .standard) -> PracticePreferences {
        PracticePreferences(
            wordPlaybackCount: max(1, defaults.object(forKey: PreferenceKeys.wordPlaybackCount) as? Int ?? 2),
            wordPlaybackDelay: max(0.3, defaults.object(forKey: PreferenceKeys.wordPlaybackDelay) as? Double ?? 1.3),
            autoPlayExampleAudio: defaults.object(forKey: PreferenceKeys.autoPlayExampleAudio) as? Bool ?? false,
            showTranslations: defaults.object(forKey: PreferenceKeys.showTranslations) as? Bool ?? true,
            showExampleTranslation: defaults.object(forKey: PreferenceKeys.showExampleTranslation) as? Bool ?? true,
            defaultPracticeMode: defaults.string(forKey: PreferenceKeys.defaultPracticeMode) ?? "All Words"
        )
    }
}
