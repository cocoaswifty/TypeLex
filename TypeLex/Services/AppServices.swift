import Foundation
import OSLog

struct GeneratedWordInfo {
    let phonetic: String
    let translation: String?
    let meaning: String
    let meaningTranslation: String?
    let example: String
    let exampleTranslation: String
}

protocol SpeechPlaying: AnyObject {
    func stop()
    func speak(_ text: String, language: String)
    func playAudio(at url: URL)
}

extension SpeechPlaying {
    func speak(_ text: String) {
        speak(text, language: "en-US")
    }
}

protocol ImageGenerating {
    func generateImage(context: String) async throws -> Data?
}

protocol WordContentGenerating {
    func fetchWordInfo(word: String) async throws -> GeneratedWordInfo
    func regenerateWordInfo(word: String) async throws -> GeneratedWordInfo
    func regenerateImage(for entry: WordEntry) async throws -> Data?
}

protocol TelemetryTracking {
    func track(_ event: TelemetryEvent)
}

protocol CrashReporting {
    func record(_ error: Error, context: String)
}

enum TelemetryEvent {
    case practiceCompleted(word: String, errorCount: Int)
    case libraryImportStarted(totalWords: Int)
    case libraryImportCompleted(totalWords: Int)
    case libraryImportFailed(word: String, reason: String)
    case storageLocationChanged
    case settingsKeyUpdated(service: String, cleared: Bool)

    var name: String {
        switch self {
        case .practiceCompleted:
            return "practice_completed"
        case .libraryImportStarted:
            return "library_import_started"
        case .libraryImportCompleted:
            return "library_import_completed"
        case .libraryImportFailed:
            return "library_import_failed"
        case .storageLocationChanged:
            return "storage_location_changed"
        case .settingsKeyUpdated:
            return "settings_key_updated"
        }
    }

    var metadata: [String: String] {
        switch self {
        case let .practiceCompleted(word, errorCount):
            return ["word": word, "error_count": String(errorCount)]
        case let .libraryImportStarted(totalWords), let .libraryImportCompleted(totalWords):
            return ["total_words": String(totalWords)]
        case let .libraryImportFailed(word, reason):
            return ["word": word, "reason": reason]
        case .storageLocationChanged:
            return [:]
        case let .settingsKeyUpdated(service, cleared):
            return ["service": service, "cleared": String(cleared)]
        }
    }
}

final class AppTelemetry: TelemetryTracking {
    static let shared = AppTelemetry()

    private init() {}

    func track(_ event: TelemetryEvent) {
        let payload = event.metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        if payload.isEmpty {
            AppLogger.telemetry.info("\(event.name, privacy: .public)")
        } else {
            AppLogger.telemetry.info("\(event.name, privacy: .public) \(payload, privacy: .public)")
        }
    }
}

final class AppCrashReporter: CrashReporting {
    static let shared = AppCrashReporter()

    private init() {}

    func record(_ error: Error, context: String) {
        AppLogger.app.fault("context=\(context, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
    }
}
