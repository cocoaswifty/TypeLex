import SwiftUI

struct StatusAction {
    let title: String
    let icon: String
    let action: () -> Void
}

struct StatusCardView: View {
    let icon: String
    let title: String
    let message: String
    let primaryAction: StatusAction
    let secondaryAction: StatusAction?
    let tertiaryAction: StatusAction?

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(AppTheme.Colors.primaryGradient)
                .shadow(color: AppTheme.Colors.primary.opacity(0.25), radius: 18, x: 0, y: 10)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }

            VStack(spacing: 14) {
                StateActionButton(action: primaryAction, emphasized: true)

                if let secondaryAction {
                    StateActionButton(action: secondaryAction, emphasized: false)
                }

                if let tertiaryAction {
                    Button(action: tertiaryAction.action) {
                        Label(tertiaryAction.title, systemImage: tertiaryAction.icon)
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.secondary)
                    .pointingCursor()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct OnboardingView: View {
    let onLoadDefault: () -> Void
    let onImportCustom: () -> Void
    let onOpenSettings: () -> Void
    let onShowShortcuts: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(AppTheme.Colors.primaryGradient)

                    Text(AppStrings.onboardingTitle)
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    Text("Start with the built-in library, import your own, or skip API setup for now.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 500)
                }

                VStack(spacing: 14) {
                    StateActionButton(
                        action: StatusAction(
                            title: "Load @4000 Essential Words",
                            icon: "arrow.down.doc.fill",
                            action: onLoadDefault
                        ),
                        emphasized: true
                    )

                    StateActionButton(
                        action: StatusAction(
                            title: "Import Custom Library",
                            icon: "folder.badge.plus",
                            action: onImportCustom
                        ),
                        emphasized: false
                    )

                    StateActionButton(
                        action: StatusAction(
                            title: "Open Settings",
                            icon: "gearshape.fill",
                            action: onOpenSettings
                        ),
                        emphasized: false
                    )
                }

                Button("Skip For Now", action: onSkip)
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.secondary)
                    .pointingCursor()

                Button("View Shortcuts", action: onShowShortcuts)
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.secondary)
                    .pointingCursor()
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 32)
            .frame(width: 620)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 28, x: 0, y: 18)
        }
    }
}

struct KeyboardShortcutHelpView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppStrings.keyboardShortcutsTitle)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Core controls for practice and library management.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Close keyboard shortcuts")
                    .pointingCursor()
                }

                VStack(spacing: 12) {
                    ShortcutRow(keys: "←", description: "Previous word")
                    ShortcutRow(keys: "→", description: "Skip current word")
                    ShortcutRow(keys: "Type letters", description: "Practice the current word")
                    ShortcutRow(keys: "⌘I", description: "Open import")
                    ShortcutRow(keys: "⌘L", description: "Open word list")
                    ShortcutRow(keys: "⌘,", description: "Open settings")
                    ShortcutRow(keys: "⌘/", description: "Show this shortcut guide")
                }
            }
            .padding(28)
            .frame(width: 520)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 28, x: 0, y: 18)
        }
    }
}

struct InlineFeedback: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let style: InlineFeedbackStyle

    var icon: String {
        switch style {
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch style {
        case .success: return .green
        case .failure: return .orange
        case .info: return .blue
        }
    }
}

enum InlineFeedbackStyle {
    case success
    case failure
    case info
}

struct InlineFeedbackView: View {
    let feedback: InlineFeedback
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: feedback.icon)
                .foregroundColor(feedback.color)
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text(feedback.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(feedback.message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Dismiss message")
            .pointingCursor()
        }
        .padding(12)
        .background(feedback.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(feedback.color.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct ShortcutRow: View {
    let keys: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Text(keys)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(description)
                .font(.body)

            Spacer()
        }
    }
}

private struct StateActionButton: View {
    let action: StatusAction
    let emphasized: Bool

    var body: some View {
        Button(action: action.action) {
            HStack(spacing: 14) {
                Image(systemName: action.icon)
                    .font(.title3)

                Text(action.title)
                    .font(.headline)
            }
            .frame(minWidth: 320)
            .padding(.vertical, 14)
            .padding(.horizontal, 22)
            .background(background)
            .foregroundColor(foregroundColor)
            .overlay(outline)
            .cornerRadius(16)
            .shadow(color: shadowColor, radius: emphasized ? 10 : 0, x: 0, y: emphasized ? 5 : 0)
        }
        .buttonStyle(PlainButtonStyle())
        .pointingCursor()
    }

    private var background: some ShapeStyle {
        emphasized ? AnyShapeStyle(AppTheme.Colors.primaryGradient) : AnyShapeStyle(.ultraThinMaterial)
    }

    private var foregroundColor: Color {
        emphasized ? .white : .primary
    }

    @ViewBuilder
    private var outline: some View {
        if emphasized {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        }
    }

    private var shadowColor: Color {
        emphasized ? AppTheme.Colors.primary.opacity(0.24) : .clear
    }
}
