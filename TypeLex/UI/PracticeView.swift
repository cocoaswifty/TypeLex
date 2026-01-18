import SwiftUI
import AppKit

struct PracticeView: View {
    // MARK: - Properties
    
    @Bindable var vm: PracticeViewModel
    @FocusState private var isFocused: Bool
    
    @State private var activeSheet: SheetDestination?
    @State private var showLargeImage = false
    
    // User UI scale preference (synced with SettingsView)
    @AppStorage("userUIScale") private var userUIScale: Double = 1.0
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                AppTheme.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. 頂部工具列
                    TopToolbarView(
                        currentBookName: vm.repository.currentBookName,
                        activeSheet: $activeSheet
                    )
                    
                    Divider().frame(height: 16)
                    Spacer()
                    
                    // 2. 核心內容區 (Dynamic Scaling)
                    // Combine auto-calculated scale with user preference
                    let baseSize: CGFloat = 900.0
                    let heightScale = geometry.size.height / baseSize
                    let widthScale = geometry.size.width / 1200.0
                    let rawScale = min(heightScale, widthScale)
                    let autoScale = min(1.0, max(0.55, rawScale))
                    // Apply user preference: userUIScale of 1.0 = 100%, 0.7 = 70%, 1.3 = 130%
                    let scale = autoScale * CGFloat(userUIScale)
                    
                    if vm.isEmptyState {
                        WelcomeView(
                            onLoadDefault: { vm.loadDefaultLibrary() },
                            onImportCustom: { vm.importCustomLibrary() }
                        )
                    } else {
                        PracticeCardView(
                            vm: vm,
                            showLargeImage: $showLargeImage,
                            scale: scale
                        )
                    }
                    
                    Spacer()
                    Divider().frame(height: 16)
                    
                    // 3. 底部狀態列
                    BottomStatusBarView(
                        practiceMode: vm.practiceMode,
                        isFavorite: vm.currentEntry.isFavorite,
                        onCycleMode: { vm.cyclePracticeMode() },
                        onToggleFavorite: { vm.toggleFavorite() },
                        localPracticeMode: $vm.practiceMode
                    )
                }
            }
            .frame(minWidth: 900, minHeight: 600)
            .focusable()
            .focused($isFocused)
            .onAppear {
                isFocused = true
            }
            .onKeyPress { press in
                handleKeyPress(press)
            }
            .onTapGesture { isFocused = true }
            .sheet(item: $activeSheet, onDismiss: { vm.refreshQueue() }) { destination in
                switch destination {
                case .importLibrary:
                    ImportView(repository: vm.repository)
                case .wordList:
                    WordListView(repository: vm.repository)
                case .settings:
                    SettingsView(repository: vm.repository)
                case .bookManager:
                    BookManagerView(repository: vm.repository)
                }
            }
            .alert("Notice", isPresented: $vm.showAlert) {
                Button("OK") {}
            } message: {
                Text(vm.alertMessage ?? "")
            }
            .overlay {
                imageOverlay
            }
        }
    }
}

// MARK: - Subviews

private extension PracticeView {
    @ViewBuilder
    var imageOverlay: some View {
        if showLargeImage {
            LargeImageOverlay(
                entry: vm.currentEntry,
                repository: vm.repository,
                isPresented: $showLargeImage
            )
        }
    }
}

// MARK: - Handlers

private extension PracticeView {
    func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        guard press.phase == .down else { return .ignored }
        
        // Handle Navigation Keys
        if press.key == .leftArrow {
            vm.goToPreviousWord()
            return .handled
        }
        if press.key == .rightArrow {
            vm.skipWord()
            return .handled
        }
        
        // Handle Typing Input
        if let char = press.characters.first, press.characters.count == 1, !char.isControl {
            vm.handleInput(char)
            return .handled
        }
        return .ignored
    }
}
