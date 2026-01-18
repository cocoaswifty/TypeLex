import SwiftUI

struct AppTheme {
    struct Colors {
        static let accent = Color("AccentColor")
        static let primary = Color(red: 0.368, green: 0.572, blue: 0.953) // Vibrant blue from Image 4
        static let secondary = Color.purple
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color(red: 0.925, green: 0.368, blue: 0.368) // Soft red to match primary
        
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        
        static let primaryGradient = LinearGradient(
            gradient: Gradient(colors: [primary, secondary]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Dynamic Background
        static let backgroundGradient = LinearGradient(
            gradient: Gradient(colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .windowBackgroundColor).opacity(0.8),
                Color.blue.opacity(0.05)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    struct Layout {
        static let cardCornerRadius: CGFloat = 24
        static let buttonCornerRadius: CGFloat = 12
        static let standardPadding: CGFloat = 20
        static let imageSize = CGSize(width: 520, height: 346)
    }
    
    struct Shadows {
        static let card = Color.black.opacity(0.15)
        static let cardRadius: CGFloat = 12
        static let cardY: CGFloat = 6
        
        static let glow = Color.blue.opacity(0.3)
    }
}

// MARK: - View Modifiers

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.Layout.cardCornerRadius
    var padding: CGFloat = AppTheme.Layout.standardPadding
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: AppTheme.Shadows.card, radius: AppTheme.Shadows.cardRadius, x: 0, y: AppTheme.Shadows.cardY)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppTheme.Colors.primary.opacity(configuration.isPressed ? 0.8 : 1.0))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.buttonCornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct IconicButtonStyle: ButtonStyle {
    var backgroundColor: Color = .clear
    var foregroundColor: Color = .primary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foregroundColor.opacity(configuration.isPressed ? 0.7 : 1.0))
            .background(backgroundColor.opacity(configuration.isPressed ? 0.5 : 1.0))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension View {
    func glassCardStyle(cornerRadius: CGFloat = 24, padding: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
