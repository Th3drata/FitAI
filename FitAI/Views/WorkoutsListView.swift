import SwiftUI

// MARK: - Main Workouts View (Weeks Overview)

struct WorkoutsListView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var localization: LocalizationManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var isGenerating = false
    @State private var generatingWeek: Int?
    @State private var showPaywall = false

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: AppTheme.spacingM) {
                    // Usage banner for free users
                    UsageBannerView(type: .workout, showPaywall: $showPaywall)

                    ForEach(1...12, id: \.self) { week in
                        WeekOverviewCard(
                            week: week,
                            program: dataStore.getWeekProgram(week: week),
                            isCurrentWeek: dataStore.profile?.currentWeek == week,
                            isGenerating: generatingWeek == week,
                            localization: localization,
                            onGenerate: { attemptGenerateProgram(for: week) }
                        )
                    }
                }
                .padding(AppTheme.spacingL)
            }
            .background(AppTheme.backgroundPrimary)
            .navigationTitle(localization["workouts_title"])
            .loadingOverlay(
                isLoading: isGenerating,
                title: localization["workouts_generating_title"],
                subtitle: localization["workouts_generating_subtitle"],
                icon: "figure.strengthtraining.traditional"
            )
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(localization)
            }
        }
    }

    // MARK: - Actions

    private func attemptGenerateProgram(for week: Int) {
        // Check if user can generate
        if !subscriptionManager.canGenerateWorkout {
            showPaywall = true
            HapticsManager.shared.notification(.warning)
            return
        }

        generateProgram(for: week)
    }

    private func generateProgram(for week: Int) {
        guard let profile = dataStore.profile else { return }
        isGenerating = true
        generatingWeek = week
        HapticsManager.shared.impact(.medium)

        Task {
            let program = await WorkoutGenerator.shared.generateWeekProgramWithAI(
                for: profile,
                weekIndex: week,
                sessionLogs: dataStore.appData.sessionLogs,
                existingPrograms: dataStore.appData.weekPrograms
            )

            await MainActor.run {
                dataStore.addWeekProgram(program)

                // Record usage for free users
                subscriptionManager.recordWorkoutGeneration()

                NotificationManager.shared.scheduleAllWorkoutReminders(
                    weekProgram: program,
                    profile: profile,
                    localization: localization
                )

                isGenerating = false
                generatingWeek = nil
                HapticsManager.shared.notification(.success)
            }
        }
    }
}

// MARK: - Week Overview Card

struct WeekOverviewCard: View {
    let week: Int
    let program: WeekProgram?
    let isCurrentWeek: Bool
    let isGenerating: Bool
    let localization: LocalizationManager
    let onGenerate: () -> Void

    private var completedWorkouts: Int {
        program?.workouts.filter { $0.isCompleted }.count ?? 0
    }

    private var totalWorkouts: Int {
        program?.workouts.count ?? 0
    }

    private var progress: Double {
        guard totalWorkouts > 0 else { return 0 }
        return Double(completedWorkouts) / Double(totalWorkouts)
    }

    var body: some View {
        if let program = program {
            // Week with program - navigates to week detail
            NavigationLink(destination: WeekDetailView(week: week, program: program)) {
                weekCardContent
            }
        } else {
            // Empty week - shows generate button
            Button(action: onGenerate) {
                weekCardContent
            }
            .disabled(isGenerating)
        }
    }

    private var weekCardContent: some View {
        VStack(spacing: AppTheme.spacingM) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    HStack(spacing: AppTheme.spacingS) {
                        Text("\(localization["workouts_week"]) \(week)")
                            .font(.title3.bold())
                            .foregroundColor(AppTheme.textPrimary)

                        if isCurrentWeek {
                            Text(localization["workouts_current"])
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, AppTheme.spacingS)
                                .padding(.vertical, 2)
                                .background(AppTheme.accent)
                                .cornerRadius(AppTheme.cornerRadiusSmall)
                        }
                    }

                    if let _ = program {
                        Text("\(completedWorkouts)/\(totalWorkouts) \(localization["workouts_completed"])")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    } else {
                        Text(localization["workouts_not_generated"])
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                if let _ = program {
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.textSecondary)
                } else {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }

            // Progress bar (only if program exists)
            if let _ = program {
                ProgressBar(progress: progress, height: 6)
            }
        }
        .padding(AppTheme.spacingL)
        .background(
            program != nil
                ? (progress >= 1.0 ? AppTheme.success.opacity(0.1) : AppTheme.backgroundSecondary)
                : AppTheme.backgroundSecondary.opacity(0.5)
        )
        .cornerRadius(AppTheme.cornerRadiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(
                    isCurrentWeek ? AppTheme.accent : Color.clear,
                    lineWidth: 2
                )
        )
    }
}

// MARK: - Week Detail View

struct WeekDetailView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var localization: LocalizationManager

    let week: Int
    let program: WeekProgram

    @State private var showDeleteConfirm = false
    @State private var isRegenerating = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.spacingM) {
                // Week summary header
                weekSummaryHeader

                // Workouts list
                ForEach(program.workouts) { workout in
                    NavigationLink(destination: WorkoutDayDetailView(workout: workout)) {
                        WorkoutDayCard(workout: workout, localization: localization)
                    }
                }
            }
            .padding(AppTheme.spacingL)
        }
        .background(AppTheme.backgroundPrimary)
        .navigationTitle("\(localization["workouts_week"]) \(week)")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: AppTheme.spacingM) {
                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(AppTheme.error)
                    }

                    Button(action: regenerateProgram) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRegenerating)
                }
            }
        }
        .alert(localization["workouts_delete"], isPresented: $showDeleteConfirm) {
            Button(localization["cancel"], role: .cancel) {}
            Button(localization["delete"], role: .destructive) {
                deleteWeekProgram()
            }
        } message: {
            Text(localization["workouts_delete_confirm"])
        }
        .loadingOverlay(
            isLoading: isRegenerating,
            title: localization["workouts_generating_title"],
            subtitle: localization["workouts_generating_subtitle"],
            icon: "figure.strengthtraining.traditional"
        )
    }

    private var weekSummaryHeader: some View {
        let completed = program.workouts.filter { $0.isCompleted }.count
        let total = program.workouts.count
        let totalDuration = program.workouts.reduce(0) { $0 + $1.durationMinutes }
        let totalExercises = program.workouts.reduce(0) { $0 + $1.exercises.count }

        return VStack(spacing: AppTheme.spacingM) {
            HStack(spacing: AppTheme.spacingL) {
                StatBadge(
                    icon: "checkmark.circle.fill",
                    value: "\(completed)/\(total)",
                    label: localization["workouts_sessions"],
                    color: AppTheme.success
                )

                StatBadge(
                    icon: "clock.fill",
                    value: "\(totalDuration)",
                    label: localization["home_minutes"],
                    color: AppTheme.accent
                )

                StatBadge(
                    icon: "dumbbell.fill",
                    value: "\(totalExercises)",
                    label: localization["workouts_exercises"],
                    color: AppTheme.warning
                )
            }
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
    }

    private func deleteWeekProgram() {
        HapticsManager.shared.notification(.warning)
        dataStore.deleteWeekProgram(week: week)
    }

    private func regenerateProgram() {
        guard let profile = dataStore.profile else { return }
        isRegenerating = true
        HapticsManager.shared.impact(.medium)

        Task {
            // For regeneration, we exclude the current week from existing programs
            // so it can regenerate from today
            let otherPrograms = dataStore.appData.weekPrograms.filter { $0.weekIndex != week }

            let newProgram = await WorkoutGenerator.shared.generateWeekProgramWithAI(
                for: profile,
                weekIndex: week,
                sessionLogs: dataStore.appData.sessionLogs,
                existingPrograms: otherPrograms
            )

            await MainActor.run {
                dataStore.addWeekProgram(newProgram)

                NotificationManager.shared.scheduleAllWorkoutReminders(
                    weekProgram: newProgram,
                    profile: profile,
                    localization: localization
                )

                isRegenerating = false
                HapticsManager.shared.notification(.success)
            }
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: AppTheme.spacingXS) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.headline.bold())
                .foregroundColor(AppTheme.textPrimary)

            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Workout Day Card

struct WorkoutDayCard: View {
    let workout: Workout
    let localization: LocalizationManager

    var body: some View {
        HStack(spacing: AppTheme.spacingM) {
            // Day circle
            ZStack {
                Circle()
                    .fill(workout.isCompleted ? AppTheme.success : AppTheme.accent.opacity(0.2))
                    .frame(width: 50, height: 50)

                if workout.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                } else {
                    Text("\(workout.dayIndex)")
                        .font(.headline.bold())
                        .foregroundColor(AppTheme.accent)
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                Text(localization[workout.titleKey])
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: AppTheme.spacingM) {
                    Label("\(workout.durationMinutes) min", systemImage: "clock")
                    Label("\(workout.exercises.count) ex", systemImage: "list.bullet")
                }
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)

                if let date = workout.scheduledDate {
                    Text(formatDate(date))
                        .font(.caption)
                        .foregroundColor(AppTheme.accent)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(AppTheme.spacingM)
        .background(
            workout.isCompleted
                ? AppTheme.success.opacity(0.1)
                : AppTheme.backgroundSecondary
        )
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localization.currentLanguage.rawValue)
        formatter.dateFormat = "EEEE d MMM"
        return formatter.string(from: date).capitalized
    }
}

// MARK: - Workout Day Detail View

struct WorkoutDayDetailView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var localization: LocalizationManager

    let workout: Workout

    @State private var showActiveWorkout = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                // Workout info header
                workoutInfoHeader

                // Exercises list
                VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                    Text(localization["workouts_exercises"])
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    ForEach(workout.exercises) { exercise in
                        ExercisePreviewCard(exercise: exercise, localization: localization)
                    }
                }

                // Start workout button
                if !workout.isCompleted {
                    Button(action: {
                        HapticsManager.shared.impact(.medium)
                        showActiveWorkout = true
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text(localization["home_start_workout"])
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, AppTheme.spacingM)
                } else {
                    // Completed badge
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.success)
                        Text(localization["home_completed"])
                            .font(.headline)
                            .foregroundColor(AppTheme.success)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.spacingM)
                    .background(AppTheme.success.opacity(0.1))
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                    .padding(.top, AppTheme.spacingM)
                }
            }
            .padding(AppTheme.spacingL)
        }
        .background(AppTheme.backgroundPrimary)
        .navigationTitle(localization[workout.titleKey])
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $showActiveWorkout) {
            ActiveWorkoutView(workout: workout)
        }
    }

    private var workoutInfoHeader: some View {
        VStack(spacing: AppTheme.spacingM) {
            HStack(spacing: AppTheme.spacingL) {
                VStack(spacing: AppTheme.spacingXS) {
                    Image(systemName: "clock.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.accent)
                    Text("\(workout.durationMinutes) min")
                        .font(.headline)
                    Text(localization["home_duration"])
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: AppTheme.spacingXS) {
                    Image(systemName: "dumbbell.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.warning)
                    Text("\(workout.exercises.count)")
                        .font(.headline)
                    Text(localization["home_exercises"])
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: AppTheme.spacingXS) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.error)
                    Text(localization[workout.difficulty.localizedKey])
                        .font(.headline)
                    Text(localization["workouts_difficulty"])
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            if let date = workout.scheduledDate {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(AppTheme.accent)
                    Text(formatFullDate(date))
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localization.currentLanguage.rawValue)
        formatter.dateStyle = .full
        return formatter.string(from: date).capitalized
    }
}

// MARK: - Exercise Preview Card

struct ExercisePreviewCard: View {
    let exercise: Exercise
    let localization: LocalizationManager
    @EnvironmentObject var dataStore: DataStore

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                Text(localization[exercise.nameKey].trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text("\(exercise.sets) x \(exercise.reps)")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.accent)
            }

            HStack(spacing: AppTheme.spacingM) {
                // Muscle groups
                HStack(spacing: AppTheme.spacingXS) {
                    ForEach(exercise.muscleGroups.prefix(2), id: \.self) { muscle in
                        Text(localization[muscle.localizedKey])
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal, AppTheme.spacingS)
                            .padding(.vertical, 2)
                            .background(AppTheme.backgroundTertiary)
                            .cornerRadius(AppTheme.cornerRadiusSmall)
                    }
                }

                Spacer()

                // Last weight used
                if let lastWeight = dataStore.getLastWeight(for: exercise.nameKey), lastWeight > 0 {
                    Text("\(Int(lastWeight)) kg")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding(AppTheme.spacingM)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}

#Preview {
    WorkoutsListView()
        .environmentObject(DataStore.shared)
        .environmentObject(LocalizationManager.shared)
}
