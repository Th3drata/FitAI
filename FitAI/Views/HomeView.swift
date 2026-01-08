import SwiftUI

struct HomeView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var localization: LocalizationManager

    private let workoutGenerator = WorkoutGenerator.shared

    @State private var activeWorkout: Workout?
    @State private var animateCards = false
    @State private var showWeeklySummary = false
    @State private var weeklySummary: WeeklySummary?
    @State private var isGeneratingNextWeek = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    // Weekly Summary Banner (Sunday evening)
                    if dataStore.shouldShowWeeklySummary() {
                        weeklySummaryBanner
                            .padding(.horizontal, AppTheme.spacingL)
                    }

                    // Welcome Header
                    welcomeHeader
                        .padding(.horizontal, AppTheme.spacingL)

                    // Today's Workout Card
                    todayWorkoutCard
                        .padding(.horizontal, AppTheme.spacingL)

                    // Quick Stats
                    statsSection
                        .padding(.horizontal, AppTheme.spacingL)

                    // Quick Actions
                    quickActionsSection
                        .padding(.horizontal, AppTheme.spacingL)
                }
                .padding(.vertical, AppTheme.spacingM)
            }
            .background(AppTheme.backgroundPrimary)
            .navigationTitle(localization["tab_home"])
            .onAppear {
                // Check if we need to advance to the next week
                dataStore.updateCurrentWeekIfNeeded()
                
                withAnimation(AppTheme.springAnimation.delay(0.1)) {
                    animateCards = true
                }
                // Check if we should show weekly summary
                if dataStore.shouldShowWeeklySummary() {
                    weeklySummary = dataStore.getWeeklySummary()
                }
            }
        }
        .fullScreenCover(item: $activeWorkout) { workout in
            ActiveWorkoutView(workout: workout)
                .environmentObject(dataStore)
                .environmentObject(localization)
        }
        .sheet(isPresented: $showWeeklySummary) {
            if let summary = weeklySummary {
                WeeklySummaryView(
                    summary: summary,
                    onGenerateNextWeek: {
                        generateNextWeek()
                        showWeeklySummary = false
                    },
                    onDismiss: {
                        showWeeklySummary = false
                    }
                )
                .environmentObject(dataStore)
                .environmentObject(localization)
            }
        }
        .loadingOverlay(
            isLoading: isGeneratingNextWeek,
            title: localization["workouts_generating_title"],
            subtitle: localization["workouts_generating_subtitle"],
            icon: "figure.strengthtraining.traditional"
        )
    }

    // MARK: - Weekly Summary Banner

    private var weeklySummaryBanner: some View {
        Button(action: {
            weeklySummary = dataStore.getWeeklySummary()
            showWeeklySummary = true
            HapticsManager.shared.impact(.medium)
        }) {
            HStack(spacing: AppTheme.spacingM) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accent.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(localization["summary_banner_title"])
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    Text(localization["summary_banner_subtitle"])
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(AppTheme.spacingM)
            .background(
                LinearGradient(
                    colors: [AppTheme.accent.opacity(0.15), AppTheme.accent.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppTheme.cornerRadiusLarge)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .opacity(animateCards ? 1 : 0)
        .offset(y: animateCards ? 0 : -20)
    }

    private func generateNextWeek() {
        guard let profile = dataStore.profile else { return }

        isGeneratingNextWeek = true
        HapticsManager.shared.impact(.medium)

        Task {
            // Increment week
            var updatedProfile = profile
            updatedProfile.currentWeek += 1

            // Generate new week program with AI
            let sessionLogs = dataStore.getSessionLogs(limit: 20)
            let newProgram = await workoutGenerator.generateNextWeekWithAI(
                for: updatedProfile,
                sessionLogs: sessionLogs,
                existingPrograms: dataStore.appData.weekPrograms
            )

            await MainActor.run {
                dataStore.saveProfile(updatedProfile)
                dataStore.addWeekProgram(newProgram)

                // Schedule notifications
                NotificationManager.shared.scheduleAllWorkoutReminders(
                    weekProgram: newProgram,
                    profile: updatedProfile,
                    localization: localization
                )

                isGeneratingNextWeek = false
                HapticsManager.shared.notification(.success)
            }
        }
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                if let profile = dataStore.profile, !profile.name.isEmpty {
                    Text("👋 \(profile.name)")
                        .font(.title2.bold())
                } else {
                    Text("👋")
                        .font(.title2)
                }

                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }
            Spacer()

            // Week indicator
            if let profile = dataStore.profile {
                VStack {
                    Text(localization["home_week"])
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("\(profile.currentWeek)")
                        .font(.title.bold())
                        .foregroundColor(AppTheme.accent)
                }
                .padding(AppTheme.spacingM)
                .background(AppTheme.accent.opacity(0.1))
                .cornerRadius(AppTheme.cornerRadiusMedium)
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localization.currentLanguage.rawValue)
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: Date()).capitalized
    }

    // MARK: - Today's Workout Card

    private var todayWorkoutCard: some View {
        VStack(spacing: 0) {
            if let workout = dataStore.getTodayWorkout(), !workout.isCompleted {
                // Workout available and not completed
                VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                    HStack {
                        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                            Text(localization["home_today_workout"])
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)

                            Text(localization[workout.titleKey])
                                .font(.title2.bold())

                            HStack(spacing: AppTheme.spacingM) {
                                Label("\(workout.durationMinutes) \(localization["home_minutes"])", systemImage: "clock")
                                Label("\(workout.exercises.count) \(localization["home_exercises"])", systemImage: "figure.strengthtraining.traditional")
                            }
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                        }

                        Spacer()

                        // Difficulty badge
                        Text(localization[workout.difficulty.localizedKey])
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, AppTheme.spacingS)
                            .padding(.vertical, AppTheme.spacingXS)
                            .background(difficultyColor(workout.difficulty))
                            .cornerRadius(AppTheme.cornerRadiusSmall)
                    }

                    // Exercise preview
                    VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                        ForEach(workout.exercises.prefix(3)) { exercise in
                            HStack {
                                Circle()
                                    .fill(AppTheme.accent)
                                    .frame(width: 6, height: 6)
                                Text(localization[exercise.nameKey].trimmingCharacters(in: .whitespacesAndNewlines))
                                    .font(.subheadline)
                                Spacer()
                                Text("\(exercise.sets)×\(exercise.reps)")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        if workout.exercises.count > 3 {
                            Text("+\(workout.exercises.count - 3) \(localization["home_exercises"])")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, AppTheme.spacingS)

                    // Action buttons
                    HStack(spacing: AppTheme.spacingM) {
                        Button(action: {
                            print("HomeView: Start workout button tapped")
                            HapticsManager.shared.impact(.medium)
                            activeWorkout = workout
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(localization["home_start_workout"])
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        NavigationLink(destination: WorkoutDayDetailView(workout: workout)) {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(width: 60)
                    }
                }
                .padding(AppTheme.spacingL)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(AppTheme.cornerRadiusLarge)
                .shadow(color: AppTheme.cardShadow, radius: AppTheme.cardShadowRadius, x: 0, y: 4)

            } else if dataStore.isTodayWorkoutCompleted() {
                // Workout completed for today
                VStack(spacing: AppTheme.spacingM) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)

                    Text(localization["home_workout_done"])
                        .font(.title3.bold())

                    Text(localization["home_workout_done_subtitle"])
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)

                    NavigationLink(destination: WorkoutsListView()) {
                        Text(localization["home_view_program"])
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.accent)
                    }
                }
                .padding(AppTheme.spacingXL)
                .frame(maxWidth: .infinity)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(AppTheme.cornerRadiusLarge)
            } else {
                // Rest day or no program
                VStack(spacing: AppTheme.spacingM) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 50))
                        .foregroundColor(AppTheme.accent.opacity(0.5))

                    Text(localization["home_rest_day"])
                        .font(.title3.bold())

                    Text(localization["home_no_workout"])
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)

                    NavigationLink(destination: WorkoutsListView()) {
                        Text(localization["home_view_program"])
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.accent)
                    }
                }
                .padding(AppTheme.spacingXL)
                .frame(maxWidth: .infinity)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(AppTheme.cornerRadiusLarge)
            }
        }
        .opacity(animateCards ? 1 : 0)
        .offset(y: animateCards ? 0 : 20)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            Text(localization["home_stats_title"])
                .font(.headline)

            HStack(spacing: AppTheme.spacingM) {
                StatCard(
                    title: localization["home_total_workouts"],
                    value: "\(dataStore.getTotalWorkoutsCompleted())",
                    icon: "checkmark.circle.fill",
                    color: AppTheme.accent
                )

                StatCard(
                    title: localization["home_this_week"],
                    value: "\(dataStore.getWeeklyWorkoutsCompleted())",
                    icon: "flame.fill",
                    color: AppTheme.accent
                )

                if let progress = dataStore.getWeightProgress() {
                    StatCard(
                        title: localization["home_weight_change"],
                        value: String(format: "%+.1f", progress.change),
                        icon: progress.change >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                        color: progress.change >= 0 ? AppTheme.success : AppTheme.warning
                    )
                } else {
                    StatCard(
                        title: localization["home_weight_change"],
                        value: "-",
                        icon: "scalemass.fill",
                        color: AppTheme.textSecondary
                    )
                }
            }
        }
        .opacity(animateCards ? 1 : 0)
        .offset(y: animateCards ? 0 : 20)
        .animation(AppTheme.springAnimation.delay(0.2), value: animateCards)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            Text(localization["assistant_quick_actions"])
                .font(.headline)

            HStack(spacing: AppTheme.spacingM) {
                NavigationLink(destination: WorkoutsListView()) {
                    QuickActionButton(
                        icon: "calendar",
                        title: localization["home_view_program"],
                        color: AppTheme.accent
                    )
                }

                NavigationLink(destination: MealsView()) {
                    QuickActionButton(
                        icon: "fork.knife",
                        title: localization["home_view_meals"],
                        color: AppTheme.accent
                    )
                }
            }
        }
        .opacity(animateCards ? 1 : 0)
        .offset(y: animateCards ? 0 : 20)
        .animation(AppTheme.springAnimation.delay(0.3), value: animateCards)
    }

    // MARK: - Helpers

    private func difficultyColor(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .beginner: return AppTheme.success
        case .intermediate: return AppTheme.warning
        case .advanced: return AppTheme.accent
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: AppTheme.spacingS) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3.bold())

            Text(title)
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingM)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: AppTheme.spacingS) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(AppTheme.spacingM)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}

#Preview {
    HomeView()
        .environmentObject(DataStore.shared)
        .environmentObject(LocalizationManager.shared)
}
