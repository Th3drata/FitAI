import SwiftUI

// MARK: - Meal & Macro Color Scheme

struct MealColors {
    static let breakfast = Color.orange          // Sunrise - warm orange
    static let lunch = Color(red: 0.2, green: 0.6, blue: 0.9)  // Midday - sky blue
    static let dinner = Color(red: 0.4, green: 0.3, blue: 0.7) // Evening - purple/indigo
    static let snack = Color(red: 0.3, green: 0.7, blue: 0.5)  // Fresh - green/teal
}

struct MacroColors {
    static let calories = Color(red: 0.95, green: 0.4, blue: 0.4)  // Energy - coral red
    static let protein = Color(red: 0.3, green: 0.6, blue: 0.9)    // Building - blue
    static let carbs = Color(red: 0.95, green: 0.7, blue: 0.2)     // Fuel - golden yellow
    static let fats = Color(red: 0.6, green: 0.4, blue: 0.7)       // Essential - purple
}

struct MealsView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var localization: LocalizationManager
    @StateObject private var openAIService = OpenAIService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selectedDate = Date()
    @State private var isGenerating = false
    @State private var showMealDetail: Meal?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirm = false
    @State private var showPaywall = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    // Usage banner for free users
                    UsageBannerView(type: .meal, showPaywall: $showPaywall)

                    // Date picker
                    dateSelector

                    // Meal plan content
                    if let mealPlan = dataStore.getMealPlan(for: selectedDate) {
                        mealPlanView(mealPlan)
                    } else {
                        emptyState
                    }
                }
                .padding(AppTheme.spacingL)
            }
            .background(AppTheme.backgroundPrimary)
            .navigationTitle(localization["meals_title"])
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if dataStore.getMealPlan(for: selectedDate) != nil {
                        HStack(spacing: AppTheme.spacingM) {
                            Button(action: { showDeleteConfirm = true }) {
                                Image(systemName: "trash")
                                    .foregroundColor(AppTheme.error)
                            }

                            Button(action: attemptRegenerateMealPlan) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .disabled(isGenerating)
                        }
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(localization)
            }
        }
        .sheet(item: $showMealDetail) { meal in
            MealDetailSheet(meal: meal, localization: localization)
        }
        .alert(localization["error"], isPresented: $showError) {
            Button(localization["ok"], role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert(localization["meals_delete"], isPresented: $showDeleteConfirm) {
            Button(localization["cancel"], role: .cancel) {}
            Button(localization["delete"], role: .destructive) {
                deleteMealPlan()
            }
        } message: {
            Text(localization["meals_delete_confirm"])
        }
        .loadingOverlay(
            isLoading: isGenerating,
            title: localization["meals_generating_title"],
            subtitle: localization["meals_generating_subtitle"],
            icon: "fork.knife"
        )
    }

    // MARK: - Delete Action

    private func deleteMealPlan() {
        HapticsManager.shared.notification(.warning)
        dataStore.deleteMealPlan(for: selectedDate)
    }

    // MARK: - Date Selector

    private var dateSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.spacingS) {
                ForEach(-1..<7, id: \.self) { dayOffset in
                    let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date())!
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)

                    Button(action: {
                        HapticsManager.shared.selection()
                        selectedDate = date
                    }) {
                        VStack(spacing: AppTheme.spacingXS) {
                            Text(dayName(for: date))
                                .font(.caption)
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.headline.bold())
                        }
                        .padding(.horizontal, AppTheme.spacingM)
                        .padding(.vertical, AppTheme.spacingS)
                        .background(isSelected ? AppTheme.accent : AppTheme.backgroundSecondary)
                        .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                    }
                }
            }
        }
    }

    // MARK: - Meal Plan View

    private func mealPlanView(_ mealPlan: MealPlan) -> some View {
        VStack(spacing: AppTheme.spacingL) {
            // Water intake tracker
            waterIntakeCard

            // Daily summary
            dailySummary(mealPlan)

            // Meals
            MealCard(
                meal: mealPlan.breakfast,
                mealType: localization["meals_breakfast"],
                icon: "sunrise.fill",
                color: MealColors.breakfast,
                localization: localization,
                onTap: { showMealDetail = mealPlan.breakfast }
            )

            MealCard(
                meal: mealPlan.lunch,
                mealType: localization["meals_lunch"],
                icon: "sun.max.fill",
                color: MealColors.lunch,
                localization: localization,
                onTap: { showMealDetail = mealPlan.lunch }
            )

            MealCard(
                meal: mealPlan.dinner,
                mealType: localization["meals_dinner"],
                icon: "moon.fill",
                color: MealColors.dinner,
                localization: localization,
                onTap: { showMealDetail = mealPlan.dinner }
            )

            // Snacks
            if !mealPlan.snacks.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    Text(localization["meals_snacks"])
                        .font(.headline)

                    ForEach(mealPlan.snacks) { snack in
                        MealCard(
                            meal: snack,
                            mealType: localization["meals_snacks"],
                            icon: "leaf.fill",
                            color: MealColors.snack,
                            localization: localization,
                            onTap: { showMealDetail = snack }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Water Intake Card

    private var waterIntakeCard: some View {
        let intake = dataStore.getWaterIntake(for: selectedDate) ?? WaterIntake(date: selectedDate)

        return VStack(spacing: AppTheme.spacingM) {
            HStack {
                Image(systemName: "drop.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                Text(localization["water_title"])
                    .font(.headline)

                Spacer()

                Text("\(intake.glasses)/\(intake.targetGlasses)")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text(localization["water_glasses"])
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.2))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * intake.progress, height: 12)
                        .animation(.spring(), value: intake.glasses)
                }
            }
            .frame(height: 12)

            // Water glasses visual
            HStack(spacing: AppTheme.spacingXS) {
                ForEach(0..<intake.targetGlasses, id: \.self) { index in
                    Image(systemName: index < intake.glasses ? "drop.fill" : "drop")
                        .font(.caption)
                        .foregroundColor(index < intake.glasses ? .blue : .gray.opacity(0.4))
                }
            }

            // Buttons
            HStack(spacing: AppTheme.spacingL) {
                Button(action: {
                    HapticsManager.shared.impact(.light)
                    dataStore.removeWaterGlass(for: selectedDate)
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundColor(intake.glasses > 0 ? .red.opacity(0.7) : .gray.opacity(0.3))
                }
                .disabled(intake.glasses == 0)

                Text("\(intake.totalMl) ml")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)

                Button(action: {
                    HapticsManager.shared.impact(.medium)
                    dataStore.addWaterGlass(for: selectedDate)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
    }

    // MARK: - Daily Summary

    private func dailySummary(_ mealPlan: MealPlan) -> some View {
        VStack(spacing: AppTheme.spacingM) {
            Text(localization["meals_total"])
                .font(.headline)

            HStack(spacing: AppTheme.spacingL) {
                MacroCircle(
                    value: mealPlan.totalKcal,
                    unit: localization["meals_kcal"],
                    color: MacroColors.calories,
                    isLarge: true
                )

                VStack(spacing: AppTheme.spacingS) {
                    MacroRow(
                        label: localization["meals_protein"],
                        value: mealPlan.totalProtein,
                        color: MacroColors.protein
                    )
                    MacroRow(
                        label: localization["meals_carbs"],
                        value: mealPlan.totalCarbs,
                        color: MacroColors.carbs
                    )
                    MacroRow(
                        label: localization["meals_fats"],
                        value: mealPlan.totalFats,
                        color: MacroColors.fats
                    )
                }
            }
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingL) {
            // Water intake tracker (always visible)
            waterIntakeCard

            Spacer()

            Image(systemName: "fork.knife")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.textSecondary.opacity(0.5))

            VStack(spacing: AppTheme.spacingS) {
                Text(localization["meals_empty"])
                    .font(.title3.bold())

                Text(localization["meals_empty_desc"])
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: attemptGenerateMealPlan) {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(localization["meals_generate"])
                }
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: !isGenerating))
            .disabled(isGenerating)

            Spacer()
        }
    }

    // MARK: - Actions

    private func attemptGenerateMealPlan() {
        // Check if user can generate
        if !subscriptionManager.canGenerateMeal {
            showPaywall = true
            HapticsManager.shared.notification(.warning)
            return
        }

        generateMealPlan()
    }

    private func attemptRegenerateMealPlan() {
        // Check if user can generate
        if !subscriptionManager.canGenerateMeal {
            showPaywall = true
            HapticsManager.shared.notification(.warning)
            return
        }

        regenerateMealPlan()
    }

    private func generateMealPlan() {
        guard let profile = dataStore.profile else { return }
        isGenerating = true
        HapticsManager.shared.impact(.medium)

        Task {
            if let mealPlan = await openAIService.generateMealPlan(profile: profile, localization: localization) {
                var planWithDate = mealPlan
                planWithDate = MealPlan(
                    id: mealPlan.id,
                    date: selectedDate,
                    breakfast: mealPlan.breakfast,
                    lunch: mealPlan.lunch,
                    dinner: mealPlan.dinner,
                    snacks: mealPlan.snacks
                )
                dataStore.addMealPlan(planWithDate)

                // Record usage for free users
                subscriptionManager.recordMealGeneration()

                HapticsManager.shared.notification(.success)
            } else {
                // Fallback to local generator if API fails
                if let error = openAIService.errorMessage {
                    errorMessage = error
                    showError = true
                }
                let plan = MealGenerator.shared.generateMealPlan(for: profile, date: selectedDate)
                dataStore.addMealPlan(plan)
                HapticsManager.shared.notification(.warning)
            }
            isGenerating = false
        }
    }

    private func regenerateMealPlan() {
        generateMealPlan()
    }

    // MARK: - Helpers

    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localization.currentLanguage.rawValue)
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).capitalized
    }
}

// MARK: - Meal Card

struct MealCard: View {
    let meal: Meal
    let mealType: String
    let icon: String
    let color: Color
    let localization: LocalizationManager
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticsManager.shared.impact(.light)
            onTap()
        }) {
            HStack(spacing: AppTheme.spacingM) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    Text(mealType)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)

                    Text(meal.nameKey.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: AppTheme.spacingM) {
                        Text("\(meal.kcal) \(localization["meals_kcal"])")
                            .font(.caption)
                            .foregroundColor(color)

                        Text("P: \(Int(meal.proteinG))g")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(AppTheme.spacingM)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(AppTheme.cornerRadiusMedium)
        }
    }
}

// MARK: - Macro Components

struct MacroCircle: View {
    let value: Int
    let unit: String
    let color: Color
    var isLarge: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(isLarge ? .title3.bold() : .headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unit)
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(width: isLarge ? 90 : 60, height: isLarge ? 90 : 60)
        .background(color.opacity(0.1))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(color, lineWidth: 2)
        )
    }
}

struct MacroRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text("\(Int(value))g")
                .font(.caption.bold())
        }
    }
}

// MARK: - Meal Detail Sheet

struct MealDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    let meal: Meal
    let localization: LocalizationManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                    // Macros summary
                    HStack(spacing: AppTheme.spacingL) {
                        MacroDetail(label: localization["meals_kcal"], value: "\(meal.kcal)", color: MacroColors.calories)
                        MacroDetail(label: localization["meals_protein"], value: "\(Int(meal.proteinG))g", color: MacroColors.protein)
                        MacroDetail(label: localization["meals_carbs"], value: "\(Int(meal.carbsG))g", color: MacroColors.carbs)
                        MacroDetail(label: localization["meals_fats"], value: "\(Int(meal.fatsG))g", color: MacroColors.fats)
                    }
                    .padding(AppTheme.spacingL)
                    .background(AppTheme.backgroundSecondary)
                    .cornerRadius(AppTheme.cornerRadiusMedium)

                    // Description
                    if !meal.descriptionKey.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                            Text("Description")
                                .font(.headline)
                            Text(meal.descriptionKey)
                                .font(.body)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }

                    // Ingredients
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text(localization["meals_ingredients"])
                            .font(.headline)

                        ForEach(meal.ingredients, id: \.self) { ingredient in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.success)
                                    .font(.caption)
                                Text(ingredient)
                                    .font(.body)
                            }
                        }
                    }

                    // Cooking Instructions
                    if let instructions = meal.instructions, !instructions.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                            Text(localization["meals_instructions"])
                                .font(.headline)

                            Text(instructions)
                                .font(.body)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                .padding(AppTheme.spacingL)
            }
            .navigationTitle(meal.nameKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localization["close"]) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MacroDetail: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: AppTheme.spacingXS) {
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MealsView()
        .environmentObject(DataStore.shared)
        .environmentObject(LocalizationManager.shared)
}
