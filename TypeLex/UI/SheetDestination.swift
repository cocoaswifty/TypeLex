import Foundation

enum SheetDestination: Identifiable {
    case importLibrary
    case wordList
    case settings
    case bookManager
    case stats
    
    var id: String {
        switch self {
        case .importLibrary: return "importLibrary"
        case .wordList: return "wordList"
        case .settings: return "settings"
        case .bookManager: return "bookManager"
        case .stats: return "stats"
        }
    }
}
