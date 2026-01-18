import SwiftUI
import AppKit

struct WordImageView: View {
    let entry: WordEntry
    let repository: WordRepository
    let isRegenerating: Bool
    let onRegenerate: () -> Void
    @Binding var showLargeImage: Bool
    
    // Local State
    @State private var currentImage: NSImage?
    @State private var isLoading: Bool = false
    
    var body: some View {
        ZStack {
            if let nsImage = currentImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: AppTheme.Layout.imageSize.width, height: AppTheme.Layout.imageSize.height)
                    .clipped()
                    .transition(.opacity.animation(.easeInOut))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: AppTheme.Layout.imageSize.width, height: AppTheme.Layout.imageSize.height)
                    .overlay {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.secondary.opacity(0.3))
                        }
                    }
            }
            
            // Loading Overlay for Regeneration
            if isRegenerating {
                ZStack {
                    Color.black.opacity(0.4)
                    ProgressView().controlSize(.large).tint(.white)
                }
                .transition(.opacity)
            }
        }
        .frame(width: AppTheme.Layout.imageSize.width, height: AppTheme.Layout.imageSize.height)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .contextMenu {
            Button(action: onRegenerate) {
                Label("Regenerate Image", systemImage: "arrow.clockwise")
            }
        }
        .onTapGesture { withAnimation(.spring()) { showLargeImage = true } }
        .pointingCursor()
        .task(id: entry.id) {
            await loadImage()
        }
        .task(id: entry.localImagePath) {
            // Also reload if the path changes (e.g. after regeneration)
            await loadImage()
        }
    }
    
    private func loadImage() async {
        isLoading = true
        defer { isLoading = false }
        
        // Fast path: Check memory or simple file check first
        if let localPath = entry.localImagePath {
            let fileURL = repository.resolveFileURL(for: localPath)
            if let image = NSImage(contentsOf: fileURL) {
                self.currentImage = image
                return
            }
        } else if let imageName = entry.imageName, let image = NSImage(named: imageName) {
            self.currentImage = image
            return
        }
        
        self.currentImage = nil
    }
}
