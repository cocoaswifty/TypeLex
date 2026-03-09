import SwiftUI

struct WordListFilter {
    var searchText: String = ""
    var sortOption: WordListSortOption = .alphabetical

    func visibleWords(from words: [WordEntry]) -> [WordEntry] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredWords: [WordEntry]

        if trimmedQuery.isEmpty {
            filteredWords = words
        } else {
            filteredWords = words.filter { entry in
                entry.word.localizedCaseInsensitiveContains(trimmedQuery)
                    || (entry.translation?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
                    || entry.meaning.localizedCaseInsensitiveContains(trimmedQuery)
                    || (entry.example?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
            }
        }

        return sortOption.sorted(using: filteredWords)
    }
}

enum WordListSortOption: String, CaseIterable, Identifiable {
    case alphabetical
    case recentReview
    case mistakes
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alphabetical: return "Alphabetical"
        case .recentReview: return "Recently Reviewed"
        case .mistakes: return "Mistakes"
        case .favorites: return "Favorites First"
        }
    }

    var icon: String {
        switch self {
        case .alphabetical: return "textformat"
        case .recentReview: return "clock.arrow.circlepath"
        case .mistakes: return "exclamationmark.triangle"
        case .favorites: return "star"
        }
    }

    func sorted(using words: [WordEntry]) -> [WordEntry] {
        words.sorted { lhs, rhs in
            switch self {
            case .alphabetical:
                return lhs.word.localizedCaseInsensitiveCompare(rhs.word) == .orderedAscending
            case .recentReview:
                return (lhs.lastReviewedAt ?? .distantPast) > (rhs.lastReviewedAt ?? .distantPast)
            case .mistakes:
                let leftMistakes = lhs.mistakeCount ?? 0
                let rightMistakes = rhs.mistakeCount ?? 0
                if leftMistakes == rightMistakes {
                    return lhs.word.localizedCaseInsensitiveCompare(rhs.word) == .orderedAscending
                }
                return leftMistakes > rightMistakes
            case .favorites:
                if lhs.isFavorite == rhs.isFavorite {
                    return lhs.word.localizedCaseInsensitiveCompare(rhs.word) == .orderedAscending
                }
                return lhs.isFavorite && !rhs.isFavorite
            }
        }
    }
}
