import SwiftUI

@main
struct TypeLexApp: App {
    @State private var vm = PracticeViewModel()
    
    var body: some Scene {
        WindowGroup {
            PracticeView(vm: vm)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // 移除不必要的選單，保持極簡
            SidebarCommands() // 移除側邊欄選單
        }
    }
}
