import SwiftUI
import AppKit

struct WordImageView: View {
    let entry: WordEntry
    let repository: WordRepository
    let isRegenerating: Bool
    let onRegenerate: () -> Void
    @Binding var showLargeImage: Bool
    var scale: CGFloat = 1.0
    
    // Local State
    @State private var currentImage: NSImage?
    @State private var isLoading: Bool = false
    
    // Computed corner radius with minimum value
    private var cornerRadius: CGFloat {
        max(12, 24 * scale)
    }
    
    var body: some View {
        ZStack {
            if let nsImage = currentImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: AppTheme.Layout.imageSize.width * scale, maxHeight: AppTheme.Layout.imageSize.height * scale)
                    // Apply clipShape directly on the image for proper corner clipping
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .transition(.opacity.animation(.easeInOut))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .aspectRatio(AppTheme.Layout.imageSize.width / AppTheme.Layout.imageSize.height, contentMode: .fit)
                    .frame(maxWidth: AppTheme.Layout.imageSize.width * scale, maxHeight: AppTheme.Layout.imageSize.height * scale)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 32 * scale))
                                .foregroundColor(.secondary.opacity(0.3))
                        }
                    }
            }
            
            // Loading Overlay for Regeneration
            if isRegenerating {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.4))
                    .overlay {
                        ProgressView().controlSize(.large).tint(.white)
                    }
                    .transition(.opacity)
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 8 * scale, x: 0, y: 4 * scale)
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
