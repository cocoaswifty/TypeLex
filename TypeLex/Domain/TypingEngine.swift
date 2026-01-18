import Foundation

/// TypingEngine 負責管理單字打字的狀態機
/// 它不依賴 UI，純粹處理輸入邏輯
struct TypingEngine {
    
    // MARK: - State
    
    /// 當前目標單字
    let targetWord: String
    
    /// 當前游標位置 (0-based index)
    /// 指向「下一個等待輸入」的字元
    private(set) var cursorIndex: Int = 0
    
    /// 該單字累積錯誤次數
    private(set) var errorCount: Int = 0
    
    /// 開始時間 (用於未來計算 WPM，目前先保留)
    private(set) var startedAt: Date?
    
    /// 標記是否剛發生錯誤（用於 UI 短暫震動或閃爍）
    private(set) var lastInputWasError: Bool = false
    
    // MARK: - Initialization
    
    init(targetWord: String) {
        self.targetWord = targetWord
    }
    
    // MARK: - Computed Properties
    
    /// 檢查是否已完成該單字
    var isFinished: Bool {
        return cursorIndex >= targetWord.count
    }
    
    /// 取得目前已輸入正確的部分
    var typedPrefix: String {
        return String(targetWord.prefix(cursorIndex))
    }
    
    /// 取得剩餘未輸入的部分
    var remainingSuffix: String {
        guard cursorIndex < targetWord.count else { return "" }
        let startIndex = targetWord.index(targetWord.startIndex, offsetBy: cursorIndex)
        return String(targetWord[startIndex...])
    }
    
    // MARK: - Actions
    
    /// 處理使用者輸入字元
    /// - Parameter char: 使用者輸入的字元
    /// - Returns: 輸入是否正確
    mutating func input(char: Character) -> Bool {
        // 如果已經結束，不處理
        if isFinished { return false }
        
        // 開始計時
        if cursorIndex == 0 && startedAt == nil {
            startedAt = Date()
        }
        
        // 重置錯誤旗標
        lastInputWasError = false
        
        // 取得當前目標字元
        let targetCharIndex = targetWord.index(targetWord.startIndex, offsetBy: cursorIndex)
        let targetChar = targetWord[targetCharIndex]
        
        // 比對 (這裡假設大小寫敏感，若需不敏感可調整)
        if char == targetChar {
            cursorIndex += 1
            return true
        } else {
            errorCount += 1
            lastInputWasError = true
            return false
        }
    }
    
    /// 重置引擎以練習新單字
    mutating func reset(newWord: String) {
        self = TypingEngine(targetWord: newWord)
    }
}
