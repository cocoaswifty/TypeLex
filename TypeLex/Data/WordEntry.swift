import Foundation

struct WordEntry: Codable, Identifiable {
    var id: String { word }
    let word: String
    var phonetic: String?
    var translation: String? // Short word translation
    var meaning: String
    var meaningTranslation: String? // Translation of the meaning
    var example: String?
    var exampleTranslation: String?
    var imageName: String? // For bundled assets
    var localImagePath: String? // For runtime imported images (relative path in Documents)
    var soundPath: String? // For word sound
    var soundMeaningPath: String? // For meaning sound
    var soundExamplePath: String? // For example sound
    var isFavorite: Bool = false // User favorite status
    var mistakeCount: Int? = 0 // Historical mistake count (Optional for backward compatibility)
}

// 用於預覽與測試的假資料
extension WordEntry {
    static let mock = WordEntry(
        word: "abandon",
        phonetic: "/ə'bændən/",
        translation: "拋棄",
        meaning: "v. 拋棄，放棄",
        meaningTranslation: "拋棄某物或某人",
        example: "The crew had to abandon the sinking ship.",
        exampleTranslation: "船員們不得不棄船。",
        imageName: nil,
        localImagePath: nil,
        soundPath: nil,
        soundMeaningPath: nil,
        soundExamplePath: nil,
        isFavorite: false,
        mistakeCount: 0
    )
}
