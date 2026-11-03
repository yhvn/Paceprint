import SwiftUI
import UIKit

/// Things said aloud as they happen during a Run, only while VoiceOver is on.
enum VoiceOverAnnouncement {
    static func post(_ text: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        AccessibilityNotification.Announcement(text).post()
    }
}
