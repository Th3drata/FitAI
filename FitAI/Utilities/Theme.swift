import SwiftUI

// MARK: - Color Theme

struct AppTheme {
    // Primary colors (static defaults - use ThemeManager for dynamic)
    static let primaryTeal = Color(hex: "00BFA6")
    static let primaryCoral = Color(hex: "FF6B6B")

    // Dynamic accent color from ThemeManager
    @MainActor static var accent: Color {
        ThemeManager.shared.primaryColor
    }

    // Background colors
    static let backgroundPrimary = Color(UIColor.systemBackground)
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
    static let backgroundTertiary = Color(UIColor.tertiarySystemBackground)

    // Text colors
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)

    // Accent colors
    static let success = Color(hex: "4CAF50")
    static let warning = Color(hex: "FF9800")
    static let error = Color(hex: "F44336")

    // Gradient
    static let primaryGradient = LinearGradient(
        colors: [primaryTeal, primaryTeal.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let coralGradient = LinearGradient(
        colors: [primaryCoral, primaryCoral.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Card shadows
    static let cardShadow = Color.black.opacity(0.1)
    static let cardShadowRadius: CGFloat = 8

    // Corner radii
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 24

    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // Animation
    static let animationDuration: Double = 0.3
    static let springAnimation = Animation.spring(response: 0.4, dampingFraction: 0.8)
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: 4)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @ObservedObject private var themeManager = ThemeManager.shared
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.spacingM)
            .background(
                isEnabled ? themeManager.primaryColor : Color.gray
            )
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AppTheme.springAnimation, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @ObservedObject private var themeManager = ThemeManager.shared

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(themeManager.primaryColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.spacingM)
            .background(themeManager.primaryColor.opacity(0.1))
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(themeManager.primaryColor, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AppTheme.springAnimation, value: configuration.isPressed)
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.vertical, AppTheme.spacingS)
            .background(AppTheme.primaryCoral)
            .cornerRadius(AppTheme.cornerRadiusSmall)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AppTheme.springAnimation, value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func fadeInAnimation(delay: Double = 0) -> some View {
        self.opacity(1)
            .animation(.easeIn(duration: AppTheme.animationDuration).delay(delay), value: true)
    }

    func slideInAnimation(from edge: Edge = .bottom, delay: Double = 0) -> some View {
        self.transition(.move(edge: edge).combined(with: .opacity))
            .animation(AppTheme.springAnimation.delay(delay), value: true)
    }
}

// MARK: - Custom Progress Bar

struct ProgressBar: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let progress: Double
    var useAccentColor: Bool = true
    var customColor: Color?
    var height: CGFloat = 8

    var barColor: Color {
        if let custom = customColor {
            return custom
        }
        return useAccentColor ? themeManager.primaryColor : AppTheme.primaryTeal
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(barColor)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1), height: height)
                    .animation(AppTheme.springAnimation, value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Theme Observer Modifier

struct ThemeObserver: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            // Force re-render when accent color changes
            .id(themeManager.accentColor.rawValue)
    }
}

extension View {
    func observeTheme() -> some View {
        modifier(ThemeObserver())
    }
}

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.5),
                            Color.white.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}
