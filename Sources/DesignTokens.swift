import SwiftUI

/// Shared flag so sidebar panels can skip polling when hidden.
/// When visibility transitions from false→true, triggers immediate refresh on all panels.
@MainActor
final class SidebarVisibility: ObservableObject {
    static let shared = SidebarVisibility()
    @Published var isVisible: Bool = true {
        didSet {
            if isVisible && !oldValue {
                // Sidebar just became visible — refresh all panels immediately
                AnimaState.shared.refresh()
                DockerState.shared.refresh()
                HardwareState.shared.scan()
            }
        }
    }
}

/// RobotFlow Labs shared design tokens.
/// Single source of truth — import these instead of defining per-file constants.
enum RF {
    // Brand colors
    static let accent   = Color(red: 0xFF/255, green: 0x3B/255, blue: 0x00/255)   // #FF3B00
    static let green    = Color(red: 0x00/255, green: 0xFF/255, blue: 0x88/255)   // #00FF88
    static let cyan     = Color(red: 0x00/255, green: 0xDD/255, blue: 0xFF/255)   // #00DDFF
    static let purple   = Color(red: 0x8B/255, green: 0x5C/255, blue: 0xFF/255)   // #8B5CFF
    static let yellow   = Color(red: 0xFF/255, green: 0xB8/255, blue: 0x00/255)   // #FFB800
    static let red      = Color(red: 0xFF/255, green: 0x33/255, blue: 0x33/255)   // #FF3333

    // Backgrounds
    static let voidBlack = Color(red: 0x05/255, green: 0x05/255, blue: 0x05/255)  // #050505
    static let darkGray  = Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255)  // #1A1A1A
    static let elevated  = Color(red: 0x22/255, green: 0x22/255, blue: 0x22/255)  // #222222
    static let sidebarBg = Color(red: 0x08/255, green: 0x08/255, blue: 0x08/255)  // #080808
    static let barBg     = Color(red: 0x0A/255, green: 0x0A/255, blue: 0x0A/255)  // #0A0A0A

    // Borders & dims
    static let border    = Color(red: 0x33/255, green: 0x33/255, blue: 0x33/255)  // #333333
    static let dim       = Color.white.opacity(0.3)
}
