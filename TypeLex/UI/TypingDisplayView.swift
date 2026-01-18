import SwiftUI

struct TypingDisplayView: View {
    // Only depend on the engine state needed for rendering
    let typedPrefix: String
    let remainingSuffix: String
    let isFinished: Bool
    let lastInputWasError: Bool
    
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
                                .frame(height: 3)
                                .foregroundColor(AppTheme.Colors.primary)
                                .offset(y: 6)
                                .shadow(color: AppTheme.Shadows.glow, radius: 4),
                            alignment: .bottom
                        )
                    
                    Text(String(remainingSuffix.dropFirst()))
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
        }
        .font(.system(size: 80, weight: .regular, design: .serif))
        .monospaced()
        .padding(.vertical, 4)
        .onTapGesture(perform: onSpeak)
        .pointingCursor()
    }
}
