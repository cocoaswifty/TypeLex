import SwiftUI

struct TypingDisplayView: View {
    // Only depend on the engine state needed for rendering
    let typedPrefix: String
    let remainingSuffix: String
    let isFinished: Bool
    let lastInputWasError: Bool
    var scale: CGFloat = 1.0
    
    // Actions
    let onSpeak: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Text(typedPrefix)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if !isFinished {
                if let firstChar = remainingSuffix.first {
                    Text(String(firstChar))
                        .foregroundColor(lastInputWasError ? .white : AppTheme.Colors.primary)
                        .background(lastInputWasError ? AppTheme.Colors.error : Color.clear)
                        .overlay(
                            Rectangle()
                                .frame(height: 3 * scale)
                                .foregroundColor(AppTheme.Colors.primary)
                                .offset(y: 6 * scale)
                                .shadow(color: AppTheme.Shadows.glow, radius: 4 * scale),
                            alignment: .bottom
                        )
                    
                    Text(String(remainingSuffix.dropFirst()))
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
        }
        .font(.system(size: 80 * scale, weight: .regular, design: .serif))
        .monospaced()
        .padding(.vertical, 4 * scale)
        .onTapGesture(perform: onSpeak)
        .pointingCursor()
    }
}
