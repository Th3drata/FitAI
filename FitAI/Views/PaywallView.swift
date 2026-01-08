import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localization: LocalizationManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.spacingXL) {
                    // Header
                    headerSection

                    // Features
                    featuresSection

                    // Products
                    productsSection

                    // Legal
                    legalSection
                }
                .padding(AppTheme.spacingL)
            }
            .background(AppTheme.backgroundPrimary)
            .navigationTitle(localization["premium_title"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .alert(localization["error"], isPresented: $showError) {
                Button(localization["ok"], role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isPurchasing {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AppTheme.spacingM) {
            // Premium icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            Text(localization["premium_unlock"])
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(localization["premium_subtitle"])
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.spacingL)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: AppTheme.spacingM) {
            FeatureRow(
                icon: "sparkles",
                title: localization["premium_feature_ai"],
                subtitle: localization["premium_feature_ai_desc"],
                color: AppTheme.accent
            )

            FeatureRow(
                icon: "fork.knife",
                title: localization["premium_feature_meals"],
                subtitle: localization["premium_feature_meals_desc"],
                color: .orange
            )

            FeatureRow(
                icon: "figure.strengthtraining.traditional",
                title: localization["premium_feature_workouts"],
                subtitle: localization["premium_feature_workouts_desc"],
                color: .green
            )

            FeatureRow(
                icon: "chart.bar.doc.horizontal",
                title: localization["premium_feature_summary"],
                subtitle: localization["premium_feature_summary_desc"],
                color: .purple
            )

            FeatureRow(
                icon: "arrow.clockwise",
                title: localization["premium_feature_regenerate"],
                subtitle: localization["premium_feature_regenerate_desc"],
                color: .blue
            )
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
    }

    // MARK: - Products

    private var productsSection: some View {
        VStack(spacing: AppTheme.spacingM) {
            if subscriptionManager.products.isEmpty {
                if subscriptionManager.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    Text(localization["premium_loading_error"])
                        .foregroundColor(AppTheme.textSecondary)
                        .padding()

                    Button(action: {
                        Task { await subscriptionManager.loadProducts() }
                    }) {
                        Text(localization["premium_retry"])
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            } else {
                ForEach(subscriptionManager.products, id: \.id) { product in
                    ProductCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        savingsPercentage: product.id == SubscriptionManager.premiumYearlyProductId
                            ? subscriptionManager.yearlySavingsPercentage
                            : nil,
                        localization: localization
                    ) {
                        selectedProduct = product
                        HapticsManager.shared.selection()
                    }
                }

                // Purchase button
                Button(action: purchase) {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(localization["premium_subscribe"])
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedProduct == nil || isPurchasing)
                .padding(.top, AppTheme.spacingS)

                // Restore purchases
                Button(action: {
                    Task {
                        isPurchasing = true
                        await subscriptionManager.restorePurchases()
                        isPurchasing = false

                        if subscriptionManager.isPremium {
                            dismiss()
                        }
                    }
                }) {
                    Text(localization["premium_restore"])
                        .font(.subheadline)
                        .foregroundColor(AppTheme.accent)
                }
                .padding(.top, AppTheme.spacingS)
            }
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: AppTheme.spacingS) {
            Text(localization["premium_legal"])
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: AppTheme.spacingM) {
                Button(action: {
                    // Open Terms of Use
                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text(localization["premium_terms"])
                        .font(.caption)
                        .foregroundColor(AppTheme.accent)
                }

                Button(action: {
                    // Open Privacy Policy
                    // TODO: Replace with your privacy policy URL
                }) {
                    Text(localization["premium_privacy"])
                        .font(.caption)
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .padding(.top, AppTheme.spacingM)
    }

    // MARK: - Actions

    private func purchase() {
        guard let product = selectedProduct else { return }

        isPurchasing = true
        HapticsManager.shared.impact(.medium)

        Task {
            do {
                let success = try await subscriptionManager.purchase(product)
                isPurchasing = false

                if success {
                    HapticsManager.shared.notification(.success)
                    dismiss()
                }
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
                showError = true
                HapticsManager.shared.notification(.error)
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: AppTheme.spacingM) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppTheme.success)
        }
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let savingsPercentage: Int?
    let localization: LocalizationManager
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    HStack {
                        Text(productTitle)
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)

                        if let savings = savingsPercentage, savings > 0 {
                            Text("-\(savings)%")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, AppTheme.spacingS)
                                .padding(.vertical, 2)
                                .background(AppTheme.success)
                                .cornerRadius(AppTheme.cornerRadiusSmall)
                        }
                    }

                    Text(productSubtitle)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3.bold())
                        .foregroundColor(AppTheme.accent)

                    Text(pricePerMonth)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(AppTheme.spacingM)
            .background(isSelected ? AppTheme.accent.opacity(0.1) : AppTheme.backgroundSecondary)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 2)
            )
        }
    }

    private var productTitle: String {
        if product.id == SubscriptionManager.premiumMonthlyProductId {
            return localization["premium_monthly"]
        } else {
            return localization["premium_yearly"]
        }
    }

    private var productSubtitle: String {
        if product.id == SubscriptionManager.premiumMonthlyProductId {
            return localization["premium_monthly_desc"]
        } else {
            return localization["premium_yearly_desc"]
        }
    }

    private var pricePerMonth: String {
        if product.id == SubscriptionManager.premiumYearlyProductId {
            let monthlyPrice = product.price / 12
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = product.priceFormatStyle.locale
            let formatted = formatter.string(from: monthlyPrice as NSNumber) ?? ""
            return "\(formatted)/\(localization["premium_month"])"
        }
        return "/\(localization["premium_month"])"
    }
}

// MARK: - Usage Banner (for free users)

struct UsageBannerView: View {
    @EnvironmentObject var localization: LocalizationManager
    @ObservedObject var subscriptionManager = SubscriptionManager.shared

    let type: UsageType
    @Binding var showPaywall: Bool

    enum UsageType {
        case workout
        case meal
    }

    var remaining: Int {
        switch type {
        case .workout:
            return subscriptionManager.remainingWorkoutGenerations
        case .meal:
            return subscriptionManager.remainingMealGenerations
        }
    }

    var total: Int {
        switch type {
        case .workout:
            return UsageLimits.freeWorkoutGenerationsPerMonth
        case .meal:
            return UsageLimits.freeMealGenerationsPerMonth
        }
    }

    var canGenerate: Bool {
        switch type {
        case .workout:
            return subscriptionManager.canGenerateWorkout
        case .meal:
            return subscriptionManager.canGenerateMeal
        }
    }

    var body: some View {
        if !subscriptionManager.isPremium {
            VStack(spacing: AppTheme.spacingS) {
                HStack {
                    Image(systemName: canGenerate ? "sparkles" : "lock.fill")
                        .foregroundColor(canGenerate ? AppTheme.accent : AppTheme.warning)

                    if canGenerate {
                        Text("\(remaining)/\(total) \(localization["premium_remaining"])")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    } else {
                        Text(localization["premium_limit_reached"])
                            .font(.caption)
                            .foregroundColor(AppTheme.warning)
                    }

                    Spacer()

                    Button(action: {
                        showPaywall = true
                        HapticsManager.shared.impact(.light)
                    }) {
                        Text(localization["premium_upgrade"])
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, AppTheme.spacingM)
                            .padding(.vertical, AppTheme.spacingXS)
                            .background(AppTheme.accent)
                            .cornerRadius(AppTheme.cornerRadiusSmall)
                    }
                }
            }
            .padding(AppTheme.spacingM)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(AppTheme.cornerRadiusMedium)
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(LocalizationManager.shared)
}
