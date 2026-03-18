import AppKit
import Foundation

/// Simple singleton holding terminal appearance and shell settings.
/// Replaces GhosttyManager's config-reading responsibility.
@MainActor
final class TerminalSettings {
    static let shared = TerminalSettings()

    /// Terminal background color (default: near-black matching ROBOTERM design tokens).
    var backgroundColor: NSColor = NSColor(red: 0x05/255, green: 0x05/255, blue: 0x05/255, alpha: 1.0)

    /// Terminal foreground / text color.
    var foregroundColor: NSColor = .white

    /// Font family used in the terminal.
    var fontName: String = "Menlo"

    /// Font point size.
    var fontSize: CGFloat = 13

    /// Background opacity (1.0 = fully opaque).
    var backgroundOpacity: Double = 1.0

    /// Shell executable to launch. Defaults to $SHELL, falling back to /bin/zsh.
    var shell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

    private init() {
        load()
    }

    /// Load settings from UserDefaults (or leave defaults if not set).
    func load() {
        let defaults = UserDefaults.standard

        if let hex = defaults.string(forKey: "terminalBackgroundColor"),
           let color = NSColor(hex: hex) {
            backgroundColor = color
        }

        if let hex = defaults.string(forKey: "terminalForegroundColor"),
           let color = NSColor(hex: hex) {
            foregroundColor = color
        }

        if let name = defaults.string(forKey: "terminalFontName"), !name.isEmpty {
            fontName = name
        }

        let size = defaults.double(forKey: "terminalFontSize")
        if size > 0 {
            fontSize = CGFloat(size)
        }

        let opacity = defaults.double(forKey: "terminalBackgroundOpacity")
        if opacity > 0 {
            backgroundOpacity = opacity
        }

        if let sh = defaults.string(forKey: "terminalShell"), !sh.isEmpty {
            shell = sh
        }
    }

    /// Persist current settings to UserDefaults.
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(backgroundColor.hexString, forKey: "terminalBackgroundColor")
        defaults.set(foregroundColor.hexString, forKey: "terminalForegroundColor")
        defaults.set(fontName, forKey: "terminalFontName")
        defaults.set(fontSize, forKey: "terminalFontSize")
        defaults.set(backgroundOpacity, forKey: "terminalBackgroundOpacity")
        defaults.set(shell, forKey: "terminalShell")
    }
}

// MARK: - NSColor hex helpers

private extension NSColor {
    convenience init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8)  & 0xFF) / 255
        let b = CGFloat( value        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }

    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "#050505" }
        let r = Int(c.redComponent   * 255)
        let g = Int(c.greenComponent * 255)
        let b = Int(c.blueComponent  * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
