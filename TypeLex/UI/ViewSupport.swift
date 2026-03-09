import AppKit
import SwiftUI

struct SectionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct StorageLocationSummaryView: View {
    let path: String
    let changeTitle: String
    let buttonKind: StorageLocationButtonKind
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Data stored at:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                changeButton
            }

            Text(path)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.blue)
                .textSelection(.enabled)
                .accessibilityLabel("Storage path")
                .contextMenu {
                    Button("Copy Path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path, forType: .string)
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var changeButton: some View {
        switch buttonKind {
        case .link:
            Button(changeTitle, action: onChange)
                .font(.caption)
                .buttonStyle(LinkButtonStyle())
                .pointingCursor()
        case .bordered:
            Button(changeTitle, action: onChange)
                .font(.caption)
                .buttonStyle(BorderedButtonStyle())
                .pointingCursor()
        }
    }
}

enum StorageLocationButtonKind {
    case link
    case bordered
}

@MainActor
func presentInlineFeedback(_ feedback: Binding<InlineFeedback?>, title: String, message: String, style: InlineFeedbackStyle) {
    withAnimation {
        feedback.wrappedValue = InlineFeedback(title: title, message: message, style: style)
    }
}

@MainActor
func presentTransientInlineFeedback(
    _ feedback: Binding<InlineFeedback?>,
    title: String,
    message: String,
    style: InlineFeedbackStyle,
    durationNanoseconds: UInt64 = 2_000_000_000
) {
    presentInlineFeedback(feedback, title: title, message: message, style: style)

    Task { @MainActor in
        try? await Task.sleep(nanoseconds: durationNanoseconds)
        withAnimation {
            if feedback.wrappedValue?.title == title {
                feedback.wrappedValue = nil
            }
        }
    }
}
