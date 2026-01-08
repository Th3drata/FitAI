import Foundation
import StoreKit

// MARK: - Subscription Status

enum SubscriptionStatus: String, Codable {
    case free = "free"
    case premium = "premium"
    case expired = "expired"
}

// MARK: - Usage Limits

struct UsageLimits {
    static let freeWorkoutGenerationsPerMonth = 2
    static let freeMealGenerationsPerMonth = 3

    static func canGenerateWorkout(currentCount: Int, isPremium: Bool) -> Bool {
        isPremium || currentCount < freeWorkoutGenerationsPerMonth
    }

    static func canGenerateMeal(currentCount: Int, isPremium: Bool) -> Bool {
        isPremium || currentCount < freeMealGenerationsPerMonth
    }

    static func remainingWorkouts(currentCount: Int, isPremium: Bool) -> Int {
        isPremium ? .max : max(0, freeWorkoutGenerationsPerMonth - currentCount)
    }

    static func remainingMeals(currentCount: Int, isPremium: Bool) -> Int {
        isPremium ? .max : max(0, freeMealGenerationsPerMonth - currentCount)
    }
}

// MARK: - Usage Tracking

struct UsageData: Codable {
    var workoutGenerationsThisMonth: Int = 0
    var mealGenerationsThisMonth: Int = 0
    var lastResetDate: Date = Date()

    mutating func resetIfNewMonth() {
        let calendar = Calendar.current
        let now = Date()

        if !calendar.isDate(lastResetDate, equalTo: now, toGranularity: .month) {
            workoutGenerationsThisMonth = 0
            mealGenerationsThisMonth = 0
            lastResetDate = now
        }
    }
}

// MARK: - Subscription Manager

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // Product IDs - Configure these in App Store Connect
    static let premiumMonthlyProductId = "com.fitai.premium.monthly"
    static let premiumYearlyProductId = "com.fitai.premium.yearly"

    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var usageData: UsageData = UsageData() {
        didSet {
            saveUsageData()
        }
    }

    private let usageDataKey = "fitai_usage_data"
    private var updateListenerTask: Task<Void, Error>?

    var isPremium: Bool {
        subscriptionStatus == .premium
    }

    var canGenerateWorkout: Bool {
        UsageLimits.canGenerateWorkout(currentCount: usageData.workoutGenerationsThisMonth, isPremium: isPremium)
    }

    var canGenerateMeal: Bool {
        UsageLimits.canGenerateMeal(currentCount: usageData.mealGenerationsThisMonth, isPremium: isPremium)
    }

    var remainingWorkoutGenerations: Int {
        UsageLimits.remainingWorkouts(currentCount: usageData.workoutGenerationsThisMonth, isPremium: isPremium)
    }

    var remainingMealGenerations: Int {
        UsageLimits.remainingMeals(currentCount: usageData.mealGenerationsThisMonth, isPremium: isPremium)
    }

    init() {
        // Start listening for transactions
        updateListenerTask = listenForTransactions()

        // Load products, check subscription, and sync usage data
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
            await loadUsageDataFromCloud()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Usage Tracking

    func recordWorkoutGeneration() {
        usageData.resetIfNewMonth()
        usageData.workoutGenerationsThisMonth += 1
        print("📊 Workout généré! Nouveau quota: \(usageData.workoutGenerationsThisMonth)/\(UsageLimits.freeWorkoutGenerationsPerMonth)")
        // Sync to cloud
        Task {
            await syncUsageToCloud()
        }
    }

    func recordMealGeneration() {
        usageData.resetIfNewMonth()
        usageData.mealGenerationsThisMonth += 1
        print("📊 Meal généré! Nouveau quota: \(usageData.mealGenerationsThisMonth)/\(UsageLimits.freeMealGenerationsPerMonth)")
        // Sync to cloud
        Task {
            await syncUsageToCloud()
        }
    }

    // MARK: - Debug

    #if DEBUG
    func resetQuotas() {
        usageData.workoutGenerationsThisMonth = 0
        usageData.mealGenerationsThisMonth = 0
        usageData.lastResetDate = Date()
        print("🔄 QUOTAS RESET!")
        logCurrentQuotas()
        // Sync reset to cloud
        Task {
            await syncUsageToCloud()
        }
    }
    #endif

    /// Load from Firebase first, fallback to local
    func loadUsageDataFromCloud() async {
        // Try to load from Firebase first
        if let cloudData = await FirestoreService.shared.loadUsageData() {
            self.usageData = cloudData
            saveUsageDataLocally() // Keep local in sync
            print("SubscriptionManager: Loaded usage from cloud")
        } else {
            // Fallback to local
            loadUsageDataLocally()
            print("SubscriptionManager: Loaded usage from local storage")
        }
        // Always log current quotas
        logCurrentQuotas()
    }

    /// Log current quota status to console
    func logCurrentQuotas() {
        let workoutsUsed = usageData.workoutGenerationsThisMonth
        let mealsUsed = usageData.mealGenerationsThisMonth
        let workoutsMax = UsageLimits.freeWorkoutGenerationsPerMonth
        let mealsMax = UsageLimits.freeMealGenerationsPerMonth

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print(" QUOTAS DU MOIS")
        print("   Workouts: \(workoutsUsed)/\(workoutsMax) utilisés (\(remainingWorkoutGenerations) restants)")
        print("   Meals:    \(mealsUsed)/\(mealsMax) utilisés (\(remainingMealGenerations) restants)")
        print("   Premium:  \(isPremium ? "✅ Oui" : "❌ Non")")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    private func syncUsageToCloud() async {
        await FirestoreService.shared.saveUsageData(usageData)
    }

    private func loadUsageDataLocally() {
        guard let data = UserDefaults.standard.data(forKey: usageDataKey) else { return }

        do {
            var loaded = try JSONDecoder().decode(UsageData.self, from: data)
            loaded.resetIfNewMonth()
            usageData = loaded
        } catch {
            print("Failed to load usage data locally: \(error)")
        }
    }

    private func saveUsageData() {
        saveUsageDataLocally()
        // Also sync to cloud
        Task {
            await syncUsageToCloud()
        }
    }

    private func saveUsageDataLocally() {
        do {
            let data = try JSONEncoder().encode(usageData)
            UserDefaults.standard.set(data, forKey: usageDataKey)
        } catch {
            print("Failed to save usage data locally: \(error)")
        }
    }

    // MARK: - StoreKit 2

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIds = [
                Self.premiumMonthlyProductId,
                Self.premiumYearlyProductId
            ]

            products = try await Product.products(for: productIds)
            products.sort { $0.price < $1.price }
            print("Loaded \(products.count) products")
        } catch {
            print("Failed to load products: \(error)")
            errorMessage = "Failed to load subscription options"
        }
    }

    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            return true

        case .userCancelled:
            return false

        case .pending:
            // Transaction is pending (e.g., parental approval)
            return false

        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            print("Failed to restore purchases: \(error)")
            errorMessage = "Failed to restore purchases"
        }
    }

    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if transaction.productID == Self.premiumMonthlyProductId ||
                   transaction.productID == Self.premiumYearlyProductId {

                    // Check if subscription is still valid
                    if let expirationDate = transaction.expirationDate,
                       expirationDate > Date() {
                        hasActiveSubscription = true
                        purchasedProductIDs.insert(transaction.productID)
                    }
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }

        subscriptionStatus = hasActiveSubscription ? .premium : .free
        print("Subscription status: \(subscriptionStatus.rawValue)")
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let item):
            return item
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }

    // MARK: - Helpers

    func formattedPrice(for product: Product) -> String {
        product.displayPrice
    }

    func subscriptionPeriod(for product: Product) -> String? {
        guard let subscription = product.subscription else { return nil }

        switch subscription.subscriptionPeriod.unit {
        case .day:
            return subscription.subscriptionPeriod.value == 7 ? "week" : "day"
        case .week:
            return "week"
        case .month:
            return subscription.subscriptionPeriod.value == 1 ? "month" : "\(subscription.subscriptionPeriod.value) months"
        case .year:
            return "year"
        @unknown default:
            return nil
        }
    }

    var monthlyProduct: Product? {
        products.first { $0.id == Self.premiumMonthlyProductId }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.premiumYearlyProductId }
    }

    var yearlySavingsPercentage: Int? {
        guard let monthly = monthlyProduct,
              let yearly = yearlyProduct else { return nil }

        let monthlyAnnual = monthly.price * 12
        let savings = (1 - (yearly.price / monthlyAnnual)) * 100
        return NSDecimalNumber(decimal: savings).intValue
    }
}

// MARK: - Store Errors

enum StoreError: Error {
    case failedVerification
    case purchaseFailed
    case productNotFound
}
