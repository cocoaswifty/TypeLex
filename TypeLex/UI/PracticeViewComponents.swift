import SwiftUI

// MARK: - Toolbar

struct TopToolbarView: View {
    let currentBookName: String
    @Binding var activeSheet: SheetDestination?
    
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(IconicButtonStyle())
            .help("Switch Word Book")
            
            // 右側設定
            HStack(spacing: 24) {
                Spacer()
                Divider().frame(height: 20)
                ToolbarIconButton(icon: "gearshape.fill", title: "Settings") { activeSheet = .settings }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
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
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
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

// MARK: - Welcome

struct WelcomeView: View {
    let onLoadDefault: () -> Void
    let onImportCustom: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 80))
                .foregroundStyle(AppTheme.Colors.primaryGradient)
                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 20, x: 0, y: 10)
            
            VStack(spacing: 12) {
                Text("Welcome to TypeLex")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Start your typing journey by loading a vocabulary library.")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 20) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { onLoadDefault() }
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Load @4000 Essential Words")
                                .font(.headline)
                            Text("Select the library folder to import")
                                .font(.caption)
                                .opacity(0.8)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .frame(minWidth: 320)
                    .background(AppTheme.Colors.primaryGradient)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(PlainButtonStyle())
                .pointingCursor()

                HStack {
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                    Text("OR").font(.caption).foregroundColor(.secondary)
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                }
                .frame(width: 200)
                
                Button(action: onImportCustom) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Import Custom Library Folder")
                    }
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())
                .pointingCursor()
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .transition(.opacity)
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
    }
}