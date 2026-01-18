import SwiftUI
import AppKit

extension View {
    /// Adds a bounce effect if available (macOS 14.0+)
    @ViewBuilder
    func bounceEffect(value: some Equatable) -> some View {
        if #available(macOS 14.0, *) {
            self.symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }
    
    /// Changes the cursor to a pointing hand on hover
    func pointingCursor() -> some View {
        self.onHover { hover in
            if hover {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

extension Character {
    /// Checks if the character is a control character
    var isControl: Bool {
        let scalar = self.unicodeScalars.first!
        return scalar.value < 32 || scalar.value == 127
    }
}
