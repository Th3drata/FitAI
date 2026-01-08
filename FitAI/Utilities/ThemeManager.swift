import SwiftUI

// MARK: - Theme Mode

enum ThemeMode: String, CaseIterable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var localizedKey: String {
        return "theme_mode_\(rawValue)"
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Accent Color

enum AccentColorOption: String, CaseIterable, Codable {
    case teal = "teal"
    case coral = "coral"
    case purple = "purple"
    case blue = "blue"
    case green = "green"
    case orange = "orange"
    case pink = "pink"

    var color: Color {
        switch self {
        case .teal: return Color(hex: "00BFA6")
        case .coral: return Color(hex: "FF6B6B")
        case .purple: return Color(hex: "9C27B0")
        case .blue: return Color(hex: "2196F3")
        case .green: return Color(hex: "4CAF50")
        case .orange: return Color(hex: "FF9800")
        case .pink: return Color(hex: "E91E63")
        }
    }

    var localizedKey: String {
        return "accent_color_\(rawValue)"
    }
}

// MARK: - Theme Manager

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private let themeModeKey = "fitai_theme_mode"
    private let accentColorKey = "fitai_accent_color"

    @Published var themeMode: ThemeMode {
        didSet {
            saveThemeMode()
            applyTheme()
        }
    }

    @Published var accentColor: AccentColorOption {
        didSet {
            saveAccentColor()
        }
    }

    init() {
        // Load saved theme mode
        if let savedMode = UserDefaults.standard.string(forKey: themeModeKey),
           let mode = ThemeMode(rawValue: savedMode) {
            self.themeMode = mode
        } else {
            self.themeMode = .system
        }

        // Load saved accent color
        if let savedColor = UserDefaults.standard.string(forKey: accentColorKey),
           let color = AccentColorOption(rawValue: savedColor) {
            self.accentColor = color
        } else {
            self.accentColor = .teal
        }

        applyTheme()
    }

    // MARK: - Persistence

    private func saveThemeMode() {
        UserDefaults.standard.set(themeMode.rawValue, forKey: themeModeKey)
    }

    private func saveAccentColor() {
        UserDefaults.standard.set(accentColor.rawValue, forKey: accentColorKey)
    }

    // MARK: - Apply Theme

    func applyTheme() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        switch themeMode {
        case .system:
            window.overrideUserInterfaceStyle = .unspecified
        case .light:
            window.overrideUserInterfaceStyle = .light
        case .dark:
            window.overrideUserInterfaceStyle = .dark
        }
    }

    // MARK: - Current Color Scheme

    var currentColorScheme: ColorScheme? {
        themeMode.colorScheme
    }

    var colorScheme: ColorScheme? {
        themeMode.colorScheme
    }

    // MARK: - Primary Color

    var primaryColor: Color {
        accentColor.color
    }
    
    nonisolated var currentAccentColor: Color {
        MainActor.assumeIsolated {
            accentColor.color
        }
    }
}

// MARK: - Dynamic AppTheme Extension

extension AppTheme {
    static var dynamicPrimaryTeal: Color {
        ThemeManager.shared.currentAccentColor
    }
}
