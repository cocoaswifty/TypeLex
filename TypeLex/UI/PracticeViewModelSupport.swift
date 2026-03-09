import Foundation

enum PracticeMode: String, CaseIterable {
    case all = "All Words"
    case favorites = "Favorites Only"
    case mistakes = "Mistakes Only"
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .favorites: return "star.fill"
        case .mistakes: return "exclamationmark.triangle.fill"
        }
    }
}

enum PracticeScreenState: Equatable {
    case ready
    case emptyLibrary
    case failure(title: String, message: String)
}

enum PracticeWordSelector {
    static func nextWord(
        from pool: [WordEntry],
        recentHistory: [WordEntry],
        currentEntry: WordEntry,
        recentWordLimit: Int,
        now: Date = Date()
    ) -> WordEntry? {
        let recentIDs = Set(recentHistory.suffix(recentWordLimit).map(\.id)).union([currentEntry.id])
        return selectNextWord(from: pool, excludingIDs: recentIDs, now: now)
            ?? selectNextWord(from: pool, now: now)
            ?? currentEntry
    }

    static func selectNextWord(
        from pool: [WordEntry],
        excludingIDs: Set<String> = [],
        now: Date = Date()
    ) -> WordEntry? {
        guard !pool.isEmpty else { return nil }

        let filteredPool = pool.filter { !excludingIDs.contains($0.id) }
        let candidates = filteredPool.isEmpty ? pool : filteredPool

        let reviewedDueWords = candidates
            .filter { isDue($0, now: now) && $0.nextReviewAt != nil }
            .sorted { ($0.nextReviewAt ?? .distantFuture) < ($1.nextReviewAt ?? .distantFuture) }

        if let overdue = reviewedDueWords.first {
            return overdue
        }

        let newWords = candidates.filter { $0.nextReviewAt == nil }
        if let unseen = newWords.randomElement() {
            return unseen
        }

        let upcomingWords = candidates
            .filter { $0.nextReviewAt != nil }
            .sorted { ($0.nextReviewAt ?? .distantFuture) < ($1.nextReviewAt ?? .distantFuture) }

        return upcomingWords.first ?? candidates.randomElement()
    }

    static func words(for mode: PracticeMode, from words: [WordEntry]) -> [WordEntry] {
        switch mode {
        case .all:
            return words
        case .favorites:
            return words.filter(\.isFavorite)
        case .mistakes:
            return words.filter { ($0.mistakeCount ?? 0) > 0 }
        }
    }

    static func isWordValid(_ word: WordEntry, for mode: PracticeMode) -> Bool {
        switch mode {
        case .all: return true
        case .favorites: return word.isFavorite
        case .mistakes: return (word.mistakeCount ?? 0) > 0
        }
    }

    private static func isDue(_ word: WordEntry, now: Date) -> Bool {
        guard let nextReviewAt = word.nextReviewAt else { return true }
        return nextReviewAt <= now
    }
}
