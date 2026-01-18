import Foundation

enum SheetDestination: Identifiable {
    case importLibrary
    case wordList
    case settings
    case bookManager
    
    var id: String {
        switch self {
        case .importLibrary: return "importLibrary"
        case .wordList: return "wordList"
        case .settings: return "settings"
        case .bookManager: return "bookManager"
        }
    }
}
