import SwiftUI

struct PracticeView: View {
    // MARK: - Properties
    
    @Bindable var vm: PracticeViewModel
    @Bindable var router: AppRouter
    @Bindable var settings: AppSettingsStore
    @FocusState private var isFocused: Bool
    
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
                        activeSheet: $router.activeSheet,
                        onShowStats: { router.open(.stats) },
                        onShowShortcuts: { router.presentShortcutHelp() }
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
                    let scale = autoScale * CGFloat(settings.userUIScale)
                    
                    switch vm.screenState {
                    case .ready:
                        PracticeCardView(
                            vm: vm,
                            settings: settings,
                            showLargeImage: $router.showLargeImage,
                            scale: scale
                        )
                    case .emptyLibrary:
                        StatusCardView(
                            icon: "books.vertical.fill",
                            title: AppStrings.noLibraryLoadedTitle,
                            message: "Load the built-in library or import your own vocabulary set to start practicing.",
                            primaryAction: StatusAction(
                                title: "Load @4000 Essential Words",
                                icon: "arrow.down.doc.fill",
                                action: { vm.loadDefaultLibrary() }
                            ),
                            secondaryAction: StatusAction(
                                title: "Import Custom Library",
                                icon: "folder.badge.plus",
                                action: { vm.importCustomLibrary() }
                            ),
                            tertiaryAction: StatusAction(
                                title: "Open Settings",
                                icon: "gearshape.fill",
                                action: { router.open(.settings) }
                            )
                        )
                    case let .failure(title, message):
                        StatusCardView(
                            icon: "exclamationmark.triangle.fill",
                            title: title,
                            message: message,
                            primaryAction: StatusAction(
                                title: "Import Custom Library",
                                icon: "folder.badge.plus",
                                action: { vm.importCustomLibrary() }
                            ),
                            secondaryAction: StatusAction(
                                title: "Load @4000 Essential Words",
                                icon: "arrow.down.doc.fill",
                                action: { vm.loadDefaultLibrary() }
                            ),
                            tertiaryAction: StatusAction(
                                title: "Dismiss",
                                icon: "xmark",
                                action: { vm.clearScreenFailure() }
                            )
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
            .sheet(item: $router.activeSheet, onDismiss: {
                router.dismissSheet()
                vm.refreshQueue()
            }) { destination in
                switch destination {
                case .importLibrary:
                    ImportView(repository: vm.repository)
                case .wordList:
                    WordListView(repository: vm.repository)
                case .settings:
                    SettingsView(repository: vm.repository, settings: settings)
                case .bookManager:
                    BookManagerView(repository: vm.repository)
                case .stats:
                    StatsView(repository: vm.repository)
                }
            }
            .alert(AppStrings.noticeTitle, isPresented: $vm.showAlert) {
                Button("OK") {}
            } message: {
                Text(vm.alertMessage ?? "")
            }
            .overlay {
                imageOverlay
            }
            .overlay {
                onboardingOverlay
            }
            .overlay {
                shortcutHelpOverlay
            }
        }
    }
}

// MARK: - Subviews

private extension PracticeView {
    @ViewBuilder
    var imageOverlay: some View {
        if router.showLargeImage {
            LargeImageOverlay(
                entry: vm.currentEntry,
                repository: vm.repository,
                isPresented: $router.showLargeImage
            )
        }
    }

    @ViewBuilder
    var onboardingOverlay: some View {
        if !settings.hasCompletedOnboarding {
            OnboardingView(
                onLoadDefault: {
                    vm.loadDefaultLibrary { succeeded in
                        if succeeded {
                            settings.hasCompletedOnboarding = true
                        }
                    }
                },
                onImportCustom: {
                    vm.importCustomLibrary { succeeded in
                        if succeeded {
                            settings.hasCompletedOnboarding = true
                        }
                    }
                },
                onOpenSettings: {
                    router.open(.settings)
                },
                onShowShortcuts: {
                    router.presentShortcutHelp()
                },
                onSkip: {
                    settings.hasCompletedOnboarding = true
                }
            )
        }
    }

    @ViewBuilder
    var shortcutHelpOverlay: some View {
        if router.showShortcutHelp {
            KeyboardShortcutHelpView {
                router.dismissShortcutHelp()
            }
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
