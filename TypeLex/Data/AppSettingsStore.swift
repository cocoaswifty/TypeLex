import Foundation
import Observation

@Observable
@MainActor
final class AppSettingsStore {
    let userDefaults: UserDefaults

    var userUIScale: Double {
        didSet { userDefaults.set(userUIScale, forKey: Self.userUIScaleKey) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { userDefaults.set(hasCompletedOnboarding, forKey: Self.onboardingKey) }
    }

    var wordPlaybackCount: Int {
        didSet { userDefaults.set(wordPlaybackCount, forKey: PreferenceKeys.wordPlaybackCount) }
    }

    var wordPlaybackDelay: Double {
        didSet { userDefaults.set(wordPlaybackDelay, forKey: PreferenceKeys.wordPlaybackDelay) }
    }

    var autoPlayExampleAudio: Bool {
        didSet { userDefaults.set(autoPlayExampleAudio, forKey: PreferenceKeys.autoPlayExampleAudio) }
    }

    var showTranslations: Bool {
        didSet { userDefaults.set(showTranslations, forKey: PreferenceKeys.showTranslations) }
    }

    var showExampleTranslation: Bool {
        didSet { userDefaults.set(showExampleTranslation, forKey: PreferenceKeys.showExampleTranslation) }
    }

    var defaultPracticeMode: String {
        didSet { userDefaults.set(defaultPracticeMode, forKey: PreferenceKeys.defaultPracticeMode) }
    }

    private static let userUIScaleKey = "userUIScale"
    private static let onboardingKey = "hasCompletedOnboarding"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let storedScale = userDefaults.object(forKey: Self.userUIScaleKey) as? Double
        self.userUIScale = storedScale ?? 1.0
        self.hasCompletedOnboarding = userDefaults.bool(forKey: Self.onboardingKey)
        self.wordPlaybackCount = userDefaults.object(forKey: PreferenceKeys.wordPlaybackCount) as? Int ?? 2
        self.wordPlaybackDelay = userDefaults.object(forKey: PreferenceKeys.wordPlaybackDelay) as? Double ?? 1.3
        self.autoPlayExampleAudio = userDefaults.object(forKey: PreferenceKeys.autoPlayExampleAudio) as? Bool ?? false
        self.showTranslations = userDefaults.object(forKey: PreferenceKeys.showTranslations) as? Bool ?? true
        self.showExampleTranslation = userDefaults.object(forKey: PreferenceKeys.showExampleTranslation) as? Bool ?? true
        self.defaultPracticeMode = userDefaults.string(forKey: PreferenceKeys.defaultPracticeMode) ?? PracticeMode.all.rawValue
    }
}
