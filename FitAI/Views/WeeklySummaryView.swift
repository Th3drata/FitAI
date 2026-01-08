import SwiftUI

struct WeeklySummaryView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var localization: LocalizationManager

    @State var summary: WeeklySummary
    let onGenerateNextWeek: () -> Void
    let onDismiss: () -> Void

    @State private var isLoadingRecommendations = false
    @State private var animateIn = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                // Header
                headerSection

                // Stats Grid
                statsGrid

                // Weight Progress
                if summary.weightChange != nil {
                    weightProgressSection
                }

                // Best Exercises
                if !summary.bestExercises.isEmpty {
                    bestExercisesSection
                }

                // Nutrition & Hydration
                if summary.averageCalories != nil || summary.averageWaterGlasses != nil {
                    nutritionSection
                }

                // AI Recommendations
                recommendationsSection

                // Action Button
                actionButton
            }
            .padding(AppTheme.spacingL)
        }
        .background(AppTheme.backgroundPrimary)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateIn = true
            }
            // Only load if not already cached
            if !summary.hasAIRecommendations {
                loadAIRecommendations()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AppTheme.spacingM) {
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

                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 35))
                    .foregroundColor(.white)
            }
            .scaleEffect(animateIn ? 1 : 0.5)
            .opacity(animateIn ? 1 : 0)

            Text(localization["summary_title"])
                .font(.title.bold())

            Text("\(localization["home_week"]) \(summary.weekNumber)")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)

            // Completion badge
            HStack(spacing: AppTheme.spacingS) {
                Image(systemName: completionIcon)
                    .foregroundColor(completionColor)
                Text(String(format: "%.0f%%", summary.completionRate * 100))
                    .font(.headline)
                    .foregroundColor(completionColor)
                Text(localization["summary_completed"])
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.vertical, AppTheme.spacingS)
            .background(completionColor.opacity(0.1))
            .cornerRadius(AppTheme.cornerRadiusMedium)
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : -20)
    }

    private var completionIcon: String {
        if summary.completionRate >= 1.0 {
            return "star.fill"
        } else if summary.completionRate >= 0.75 {
            return "checkmark.circle.fill"
        } else if summary.completionRate >= 0.5 {
            return "circle.lefthalf.filled"
        } else {
            return "circle"
        }
    }

    private var completionColor: Color {
        if summary.completionRate >= 1.0 {
            return .yellow
        } else if summary.completionRate >= 0.75 {
            return AppTheme.success
        } else if summary.completionRate >= 0.5 {
            return AppTheme.warning
        } else {
            return AppTheme.textSecondary
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.spacingM) {
            // Sessions
            SummaryStatCard(
                icon: "figure.strengthtraining.traditional",
                title: localization["summary_sessions"],
                value: "\(summary.sessionsCompleted)/\(summary.sessionsPlanned)",
                color: AppTheme.accent
            )

            // Training Time
            SummaryStatCard(
                icon: "clock.fill",
                title: localization["summary_training_time"],
                value: formatDuration(summary.totalTrainingMinutes),
                color: .blue
            )

            // Streak
            SummaryStatCard(
                icon: "flame.fill",
                title: localization["summary_streak"],
                value: "\(summary.currentStreak) \(localization["summary_days"])",
                color: .orange
            )

            // Average Rating
            if let rating = summary.averageRating {
                SummaryStatCard(
                    icon: "star.fill",
                    title: localization["summary_avg_rating"],
                    value: String(format: "%.1f/5", rating),
                    color: .yellow
                )
            } else {
                SummaryStatCard(
                    icon: "star.fill",
                    title: localization["summary_avg_rating"],
                    value: "-",
                    color: .yellow
                )
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(.spring(response: 0.6).delay(0.1), value: animateIn)
    }

    // MARK: - Weight Progress

    private var weightProgressSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            HStack {
                Image(systemName: "scalemass.fill")
                    .foregroundColor(AppTheme.accent)
                Text(localization["summary_weight_progress"])
                    .font(.headline)
            }

            HStack(spacing: AppTheme.spacingL) {
                if let start = summary.startWeight {
                    VStack {
                        Text(localization["summary_start"])
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                        Text(String(format: "%.1f kg", start))
                            .font(.title3.bold())
                    }
                }

                if summary.weightChange != nil {
                    Image(systemName: "arrow.right")
                        .foregroundColor(AppTheme.textSecondary)
                }

                if let end = summary.endWeight {
                    VStack {
                        Text(localization["summary_end"])
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                        Text(String(format: "%.1f kg", end))
                            .font(.title3.bold())
                    }
                }

                Spacer()

                if let change = summary.weightChange {
                    VStack {
                        Image(systemName: change >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundColor(weightChangeColor(change))
                        Text(String(format: "%+.1f kg", change))
                            .font(.headline)
                            .foregroundColor(weightChangeColor(change))
                    }
                }
            }
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(.spring(response: 0.6).delay(0.2), value: animateIn)
    }

    private func weightChangeColor(_ change: Double) -> Color {
        // Color depends on goal - for muscle gain, positive is good
        if let goal = dataStore.profile?.fitnessGoal {
            switch goal {
            case .muscleGain:
                return change >= 0 ? AppTheme.success : AppTheme.warning
            case .weightLoss:
                return change <= 0 ? AppTheme.success : AppTheme.warning
            default:
                return abs(change) < 0.5 ? AppTheme.success : AppTheme.warning
            }
        }
        return AppTheme.accent
    }

    // MARK: - Best Exercises

    private var bestExercisesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                Text(localization["summary_best_exercises"])
                    .font(.headline)
            }

            ForEach(Array(summary.bestExercises.enumerated()), id: \.element.id) { index, exercise in
                HStack {
                    Text("\(index + 1).")
                        .font(.headline)
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 25)

                    Text(localization[exercise.name])
                        .font(.subheadline)

                    Spacer()

                    Text("+\(Int(exercise.improvement))%")
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.success)
                        .padding(.horizontal, AppTheme.spacingS)
                        .padding(.vertical, 4)
                        .background(AppTheme.success.opacity(0.1))
                        .cornerRadius(AppTheme.cornerRadiusSmall)
                }
            }
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(.spring(response: 0.6).delay(0.3), value: animateIn)
    }

    // MARK: - Nutrition Section

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(AppTheme.accent)
                Text(localization["summary_nutrition"])
                    .font(.headline)
            }

            HStack(spacing: AppTheme.spacingM) {
                if let calories = summary.averageCalories {
                    NutritionMiniCard(
                        title: localization["meals_kcal"],
                        value: "\(calories)",
                        color: .orange
                    )
                }

                if let protein = summary.averageProtein {
                    NutritionMiniCard(
                        title: localization["meals_protein"],
                        value: "\(Int(protein))g",
                        color: .red
                    )
                }

                if let water = summary.averageWaterGlasses {
                    NutritionMiniCard(
                        title: localization["water_title"],
                        value: String(format: "%.1f", water),
                        icon: "drop.fill",
                        color: .blue
                    )
                }
            }

            if let carbs = summary.averageCarbs, let fats = summary.averageFats {
                HStack(spacing: AppTheme.spacingM) {
                    NutritionMiniCard(
                        title: localization["meals_carbs"],
                        value: "\(Int(carbs))g",
                        color: .green
                    )

                    NutritionMiniCard(
                        title: localization["meals_fats"],
                        value: "\(Int(fats))g",
                        color: .purple
                    )
                }
            }
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(.spring(response: 0.6).delay(0.35), value: animateIn)
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text(localization["summary_recommendations"])
                    .font(.headline)
            }

            if isLoadingRecommendations {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text(localization["loading"])
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.spacingL)
            } else if let recommendations = summary.aiRecommendations, !recommendations.isEmpty {
                Text(recommendations)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineSpacing(4)
            } else {
                Text(localization["summary_no_recommendations"])
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(.spring(response: 0.6).delay(0.4), value: animateIn)
    }

    // MARK: - Action Button

    private var actionButton: some View {
        VStack(spacing: AppTheme.spacingM) {
            Button(action: {
                HapticsManager.shared.impact(.medium)
                onGenerateNextWeek()
            }) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                    Text(localization["summary_generate_next_week"])
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            Button(action: {
                onDismiss()
            }) {
                Text(localization["close"])
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(.spring(response: 0.6).delay(0.5), value: animateIn)
    }

    // MARK: - Helpers

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes) min"
    }

    private func loadAIRecommendations() {
        isLoadingRecommendations = true

        Task {
            let recommendations = await OpenAIService.shared.generateWeeklyRecommendations(
                summary: summary,
                profile: dataStore.profile,
                localization: localization
            )
            await MainActor.run {
                // Update summary with AI recommendations
                var updatedSummary = summary
                updatedSummary.aiRecommendations = recommendations
                updatedSummary.generatedAt = Date()

                // Save to cache
                dataStore.saveWeeklySummary(updatedSummary)

                // Update local state
                self.summary = updatedSummary
                self.isLoadingRecommendations = false
            }
        }
    }
}

// MARK: - Supporting Views

struct SummaryStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: AppTheme.spacingS) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3.bold())

            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingM)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}

struct NutritionMiniCard: View {
    let title: String
    let value: String
    var icon: String? = nil
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
            }
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingS)
        .background(color.opacity(0.1))
        .cornerRadius(AppTheme.cornerRadiusSmall)
    }
}

#Preview {
    WeeklySummaryView(
        summary: WeeklySummary(
            weekNumber: 1,
            sessionsCompleted: 3,
            sessionsPlanned: 4,
            totalTrainingMinutes: 180,
            weightChange: 0.5,
            startWeight: 70.0,
            endWeight: 70.5,
            averageRating: 4.2,
            bestExercises: [
                ExerciseImprovement(name: "ex_bicep_curls", improvement: 15.0),
                ExerciseImprovement(name: "ex_squats", improvement: 10.0)
            ],
            averageCalories: 2500,
            averageProtein: 150,
            averageCarbs: 280,
            averageFats: 80,
            averageWaterGlasses: 7.5,
            currentStreak: 3,
            aiRecommendations: nil,
            generatedAt: nil
        ),
        onGenerateNextWeek: {},
        onDismiss: {}
    )
    .environmentObject(DataStore.shared)
    .environmentObject(LocalizationManager.shared)
}
