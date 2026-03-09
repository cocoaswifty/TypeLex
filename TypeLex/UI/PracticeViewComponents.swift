import SwiftUI

// MARK: - Toolbar

struct TopToolbarView: View {
    let currentBookName: String
    @Binding var activeSheet: SheetDestination?
    let onShowStats: () -> Void
    let onShowShortcuts: () -> Void
    
    var body: some View {
        ZStack {
            // 左側功能
            HStack(spacing: 24) {
                ToolbarIconButton(icon: "plus", title: "Import") { activeSheet = .importLibrary }
                ToolbarIconButton(icon: "list.bullet", title: "List") { activeSheet = .wordList }
                Spacer()
            }
            
            // Book Switcher (置中)
            Button(action: { activeSheet = .bookManager }) {
                HStack(spacing: 8) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 16))
                    Text(currentBookName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
                .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(IconicButtonStyle())
            .help("Switch Word Book")
            .accessibilityLabel(AppStrings.switchWordBook)
            
            // 右側設定
            HStack(spacing: 24) {
                Spacer()
                ToolbarIconButton(icon: "chart.bar.xaxis", title: "Stats", action: onShowStats)
                ToolbarIconButton(icon: "questionmark.circle", title: "Shortcuts", action: onShowShortcuts)
                ToolbarIconButton(icon: "gearshape.fill", title: "Settings") { activeSheet = .settings }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 24)
        .frame(height: 44, alignment: .center)
    }
}

// MARK: - Status Bar

struct BottomStatusBarView: View {
    let practiceMode: PracticeMode
    let isFavorite: Bool
    let onCycleMode: () -> Void
    let onToggleFavorite: () -> Void
    @Binding var localPracticeMode: PracticeMode // 用于 ContextMenu 更新
    
    var body: some View {
        HStack {
            // 左下角：練習模式切換
            Button(action: onCycleMode) {
                HStack(spacing: 6) {
                    Image(systemName: practiceMode.icon)
                        .font(.system(size: 14))
                    Text(practiceMode.rawValue)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Change practice mode")
            .contextMenu {
                Button("Practice All Words") { localPracticeMode = .all }
                Button("Practice Favorites Only") { localPracticeMode = .favorites }
                Button("Practice Mistakes Only") { localPracticeMode = .mistakes }
            }
            
            Spacer()
            
            // 右下角：我的最愛
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { onToggleFavorite() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundColor(isFavorite ? .yellow : .secondary)
                    Text(isFavorite ? "Saved" : "Favorite")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isFavorite ? .primary : .secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(isFavorite ? "Remove favorite" : "Mark current word as favorite")
        }
        .padding(.horizontal, 40)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
}

// MARK: - Overlays

struct LargeImageOverlay: View {
    let entry: WordEntry
    let repository: WordRepository
    @Binding var isPresented: Bool
    
    @State private var overlayImage: NSImage?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).edgesIgnoringSafeArea(.all)
            
            VStack {
                if let nsImage = overlayImage {
                     Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .shadow(radius: 20)
                        .padding(40)
                } else {
                    ProgressView().tint(.white)
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .onTapGesture {
            withAnimation(.spring()) { isPresented = false }
        }
        .accessibilityAddTraits(.isModal)
        .task(id: entry.id) {
            if let localPath = entry.localImagePath {
                let fileURL = repository.resolveFileURL(for: localPath)
                overlayImage = NSImage(contentsOf: fileURL)
            } else if let imageName = entry.imageName {
                overlayImage = NSImage(named: imageName)
            }
        }
    }
}

// MARK: - Private Helpers

struct ToolbarIconButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.caption2)
            }
            .frame(width: 50, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(IconicButtonStyle(foregroundColor: .secondary))
        .accessibilityLabel(title)
    }
}
