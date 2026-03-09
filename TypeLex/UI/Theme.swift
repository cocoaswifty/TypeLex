import SwiftUI

struct AppTheme {
    struct Colors {
        static let primary = Color(red: 0.368, green: 0.572, blue: 0.953) // Vibrant blue from Image 4
        static let secondary = Color.purple
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
        static let imageSize = CGSize(width: 520, height: 346)
    }
    
    struct Shadows {
        static let glow = Color.blue.opacity(0.3)
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
