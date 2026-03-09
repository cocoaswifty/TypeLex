import Foundation
import OSLog

enum WordRepositoryError: LocalizedError {
    case wordPersistenceFailed(underlying: Error)
    case reviewEventPersistenceFailed(underlying: Error)
    case rollbackFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .wordPersistenceFailed(let underlying):
            return "Failed to persist words: \(underlying.localizedDescription)"
        case .reviewEventPersistenceFailed(let underlying):
            return "Failed to persist review events: \(underlying.localizedDescription)"
        case .rollbackFailed(let underlying):
            return "Failed to restore previous repository state: \(underlying.localizedDescription)"
        }
    }
}

extension WordRepository {
    func applyWordsMutation(_ mutation: () -> Void) {
        let previousWords = words
        mutation()

        do {
            try storageSupport.saveWords(words, toBookNamed: currentBookName)
        } catch {
            words = previousWords

            do {
                try storageSupport.saveWords(previousWords, toBookNamed: currentBookName)
            } catch {
                AppLogger.repository.error("\(WordRepositoryError.rollbackFailed(underlying: error).localizedDescription)")
            }

            AppLogger.repository.error("\(WordRepositoryError.wordPersistenceFailed(underlying: error).localizedDescription)")
        }
    }

    func applyRepositoryStateMutation(_ mutation: () -> Void) {
        let previousWords = words
        let previousReviewEvents = reviewEvents
        mutation()

        do {
            try storageSupport.saveWords(words, toBookNamed: currentBookName)
        } catch {
            words = previousWords
            reviewEvents = previousReviewEvents

            do {
                try storageSupport.saveWords(previousWords, toBookNamed: currentBookName)
                try storageSupport.saveReviewEvents(previousReviewEvents, toBookNamed: currentBookName)
            } catch {
                AppLogger.repository.error("\(WordRepositoryError.rollbackFailed(underlying: error).localizedDescription)")
            }

            AppLogger.repository.error("\(WordRepositoryError.wordPersistenceFailed(underlying: error).localizedDescription)")
            return
        }

        do {
            try storageSupport.saveReviewEvents(reviewEvents, toBookNamed: currentBookName)
        } catch {
            words = previousWords
            reviewEvents = previousReviewEvents

            do {
                try storageSupport.saveWords(previousWords, toBookNamed: currentBookName)
                try storageSupport.saveReviewEvents(previousReviewEvents, toBookNamed: currentBookName)
            } catch {
                AppLogger.repository.error("\(WordRepositoryError.rollbackFailed(underlying: error).localizedDescription)")
            }

            AppLogger.repository.error("\(WordRepositoryError.reviewEventPersistenceFailed(underlying: error).localizedDescription)")
        }
    }
}
