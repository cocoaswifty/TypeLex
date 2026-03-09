import Foundation

struct ReviewEvent: Codable, Identifiable {
    let id: UUID
    let wordID: String
    let word: String
    let reviewedAt: Date
    let errorCount: Int
    let wasSuccessful: Bool
    let resultingReviewStage: Int
    let wasNewWord: Bool
    let wasOverdue: Bool

    init(
        id: UUID = UUID(),
        wordID: String,
        word: String,
        reviewedAt: Date,
        errorCount: Int,
        wasSuccessful: Bool,
        resultingReviewStage: Int,
        wasNewWord: Bool,
        wasOverdue: Bool
    ) {
        self.id = id
        self.wordID = wordID
        self.word = word
        self.reviewedAt = reviewedAt
        self.errorCount = errorCount
        self.wasSuccessful = wasSuccessful
        self.resultingReviewStage = resultingReviewStage
        self.wasNewWord = wasNewWord
        self.wasOverdue = wasOverdue
    }
}

struct ReviewStatsSummary {
    let completedToday: Int
    let accuracyToday: Double
    let newWordsToday: Int
    let reviewWordsToday: Int
    let dueToday: Int
    let overdue: Int
    let streakDays: Int
}

struct ReviewDailyProgress: Identifiable {
    let date: Date
    let completedCount: Int
    let successfulCount: Int
    let newWordCount: Int

    var id: Date { date }

    var accuracy: Double {
        guard completedCount > 0 else { return 0 }
        return Double(successfulCount) / Double(completedCount)
    }
}

struct ReviewCalendarDay: Identifiable {
    let date: Date
    let dueCount: Int
    let completedCount: Int
    let isCurrentMonth: Bool
    let isToday: Bool

    var id: Date { date }
}
