import SwiftUI

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppTheme.spacingL) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(AppTheme.textSecondary.opacity(0.5))

            VStack(spacing: AppTheme.spacingS) {
                Text(title)
                    .font(.title3.bold())

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppTheme.spacingXL)
            }

            Spacer()
        }
        .padding(AppTheme.spacingL)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: AppTheme.spacingM) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

// MARK: - Beautiful Loading Overlay

struct LoadingOverlay: View {
    let title: String
    let subtitle: String
    let icon: String
    var estimatedDuration: TimeInterval = 8.0

    @State private var progress: CGFloat = 0
    @State private var displayedProgress: Int = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var progressTimer: Timer?

    private let cardWidth: CGFloat = 280
    private let cardHeight: CGFloat = 200
    private let cornerRadius: CGFloat = 20
    private let strokeWidth: CGFloat = 4

    var body: some View {
        ZStack {
            // Blur background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Card with border progress
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppTheme.backgroundSecondary)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)

                // Border track (subtle)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.accent.opacity(0.15), lineWidth: strokeWidth)

                // Animated border progress
                BorderProgressView(
                    progress: progress,
                    cornerRadius: cornerRadius,
                    strokeWidth: strokeWidth
                )

                // Content
                VStack(spacing: AppTheme.spacingL) {
                    // Icon with pulse
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .scaleEffect(pulseScale)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .shadow(color: AppTheme.accent.opacity(0.4), radius: 10)

                        Image(systemName: icon)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    // Text
                    VStack(spacing: AppTheme.spacingXS) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)

                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Percentage
                    Text("\(displayedProgress)%")
                        .font(.title2.bold())
                        .foregroundColor(AppTheme.accent)
                        .monospacedDigit()
                }
                .padding(AppTheme.spacingXL)
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            progressTimer?.invalidate()
            progressTimer = nil
        }
    }

    private func startAnimations() {
        // Pulse animation
        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }

        // Progress animation
        startContinuousProgress()
    }

    private func startContinuousProgress() {
        let startTime = Date()
        let updateInterval: TimeInterval = 0.05

        progressTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            let tau = estimatedDuration / 3.0
            let targetProgress = 0.95 * (1 - exp(-elapsed / tau))
            let variation = CGFloat.random(in: 0...0.005)
            let newProgress = min(0.95, CGFloat(targetProgress) + variation)

            if newProgress > progress {
                withAnimation(.linear(duration: 0.05)) {
                    progress = newProgress
                    displayedProgress = Int(progress * 100)
                }
            }
        }
    }
}

// MARK: - Border Progress View

struct BorderProgressView: View {
    let progress: CGFloat
    let cornerRadius: CGFloat
    let strokeWidth: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let perimeter = calculatePerimeter(width: width, height: height, cornerRadius: cornerRadius)
            let progressLength = perimeter * progress

            Path { path in
                // Start from top center and go clockwise
                let startX = width / 2
                let startY: CGFloat = 0

                // Top edge (from center to right)
                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))

                // Top-right corner
                path.addArc(
                    center: CGPoint(x: width - cornerRadius, y: cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(0),
                    clockwise: false
                )

                // Right edge
                path.addLine(to: CGPoint(x: width, y: height - cornerRadius))

                // Bottom-right corner
                path.addArc(
                    center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false
                )

                // Bottom edge
                path.addLine(to: CGPoint(x: cornerRadius, y: height))

                // Bottom-left corner
                path.addArc(
                    center: CGPoint(x: cornerRadius, y: height - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false
                )

                // Left edge
                path.addLine(to: CGPoint(x: 0, y: cornerRadius))

                // Top-left corner
                path.addArc(
                    center: CGPoint(x: cornerRadius, y: cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false
                )

                // Top edge (from left to center)
                path.addLine(to: CGPoint(x: startX, y: 0))
            }
            .trim(from: 0, to: progress)
            .stroke(
                LinearGradient(
                    colors: [AppTheme.accent, AppTheme.accent.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
            )
        }
    }

    private func calculatePerimeter(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> CGFloat {
        let straightEdges = 2 * (width - 2 * cornerRadius) + 2 * (height - 2 * cornerRadius)
        let corners = 2 * .pi * cornerRadius
        return straightEdges + corners
    }
}

// MARK: - Loading Overlay Modifier

struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let title: String
    let subtitle: String
    let icon: String
    let estimatedDuration: TimeInterval

    func body(content: Content) -> some View {
        ZStack {
            content

            if isLoading {
                LoadingOverlay(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    estimatedDuration: estimatedDuration
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoading)
    }
}

extension View {
    func loadingOverlay(
        isLoading: Bool,
        title: String,
        subtitle: String,
        icon: String = "sparkles",
        estimatedDuration: TimeInterval = 8.0
    ) -> some View {
        modifier(LoadingOverlayModifier(
            isLoading: isLoading,
            title: title,
            subtitle: subtitle,
            icon: icon,
            estimatedDuration: estimatedDuration
        ))
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
    }
}

// MARK: - Icon Badge

struct IconBadge: View {
    let icon: String
    let color: Color
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.5))
            .foregroundColor(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.15))
            .clipShape(Circle())
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    var color: Color = AppTheme.accent

    var body: some View {
        HStack(spacing: AppTheme.spacingM) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .foregroundColor(AppTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.headline)
        }
    }
}

// MARK: - Animated Checkmark

struct AnimatedCheckmark: View {
    @State private var animate = false

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 60))
            .foregroundColor(AppTheme.success)
            .scaleEffect(animate ? 1 : 0)
            .onAppear {
                withAnimation(AppTheme.springAnimation) {
                    animate = true
                }
            }
    }
}

// MARK: - Pulse Animation

struct PulseAnimation: ViewModifier {
    @State private var animate = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(animate ? 1.1 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: animate
            )
            .onAppear {
                animate = true
            }
    }
}

extension View {
    func pulse() -> some View {
        modifier(PulseAnimation())
    }
}

// MARK: - Haptic Feedback

enum HapticType {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
}

func triggerHaptic(_ type: HapticType) {
    switch type {
    case .light:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    case .medium:
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    case .heavy:
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    case .success:
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    case .warning:
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    case .error:
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Confetti Effect (Simple)

struct ConfettiPiece: View {
    let color: Color
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .offset(
                x: animate ? CGFloat.random(in: -100...100) : 0,
                y: animate ? CGFloat.random(in: -200...200) : 0
            )
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    animate = true
                }
            }
    }
}

struct ConfettiView: View {
    let colors: [Color] = [
        AppTheme.accent,
        AppTheme.accent,
        AppTheme.success,
        AppTheme.warning
    ]

    var body: some View {
        ZStack {
            ForEach(0..<30, id: \.self) { _ in
                ConfettiPiece(color: colors.randomElement() ?? .blue)
            }
        }
    }
}

// MARK: - Circular Progress

struct CircularProgress: View {
    let progress: Double
    let lineWidth: CGFloat
    var color: Color = AppTheme.accent

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(AppTheme.springAnimation, value: progress)
        }
    }
}

// MARK: - Tag View

struct TagView: View {
    let text: String
    var color: Color = AppTheme.accent

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(color)
            .padding(.horizontal, AppTheme.spacingS)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(AppTheme.cornerRadiusSmall)
    }
}

// MARK: - Numeric Stepper

struct NumericStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack(spacing: AppTheme.spacingM) {
            Button(action: { if value > range.lowerBound { value -= step } }) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundColor(value > range.lowerBound ? AppTheme.accent : AppTheme.textSecondary)
            }
            .disabled(value <= range.lowerBound)

            Text("\(value)")
                .font(.title3.bold())
                .frame(minWidth: 40)

            Button(action: { if value < range.upperBound { value += step } }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(value < range.upperBound ? AppTheme.accent : AppTheme.textSecondary)
            }
            .disabled(value >= range.upperBound)
        }
    }
}

// MARK: - Previews

#Preview("Empty State") {
    EmptyStateView(
        icon: "dumbbell.fill",
        title: "No Workouts",
        description: "Generate your first workout program",
        actionTitle: "Generate"
    ) {
        print("Action tapped")
    }
}

#Preview("Loading") {
    LoadingView(message: "Generating...")
}

#Preview("Progress") {
    VStack(spacing: 20) {
        CircularProgress(progress: 0.7, lineWidth: 10)
            .frame(width: 100, height: 100)

        ProgressBar(progress: 0.7)
            .frame(height: 10)
            .padding()
    }
}
