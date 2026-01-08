import SwiftUI

struct WorkoutDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var localization: LocalizationManager

    let workout: Workout

    @State private var showActiveWorkout = false
    @State private var showLogSheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    // Header
                    workoutHeader

                    // Exercises list
                    exercisesList

                    // Action buttons
                    actionButtons
                }
                .padding(AppTheme.spacingL)
            }
            .background(AppTheme.backgroundPrimary)
            .navigationTitle(localization[workout.titleKey])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localization["close"]) {
                        dismiss()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showActiveWorkout) {
            ActiveWorkoutView(workout: workout)
                .environmentObject(dataStore)
                .environmentObject(localization)
        }
    }

    // MARK: - Header

    private var workoutHeader: some View {
        VStack(spacing: AppTheme.spacingM) {
            HStack(spacing: AppTheme.spacingL) {
                // Duration
                VStack {
                    Image(systemName: "clock")
                        .font(.title2)
                        .foregroundColor(AppTheme.accent)
                    Text("\(workout.durationMinutes)")
                        .font(.title3.bold())
                    Text(localization["home_minutes"])
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                // Exercises count
                VStack {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                        .foregroundColor(AppTheme.accent)
                    Text("\(workout.exercises.count)")
                        .font(.title3.bold())
                    Text(localization["home_exercises"])
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                // Difficulty
                VStack {
                    Image(systemName: "flame")
                        .font(.title2)
                        .foregroundColor(difficultyColor)
                    Text(localization[workout.difficulty.localizedKey])
                        .font(.caption.bold())
                        .foregroundColor(difficultyColor)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(AppTheme.spacingL)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(AppTheme.cornerRadiusMedium)

            // Scheduled date
            if let date = workout.scheduledDate {
                HStack {
                    Image(systemName: "calendar")
                    Text(formatDate(date))
                }
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            }

            // Completion status
            if workout.isCompleted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.success)
                    Text(localization["home_completed"])
                        .foregroundColor(AppTheme.success)
                }
                .font(.subheadline.bold())
            }
        }
    }

    // MARK: - Exercises List

    private var exercisesList: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            Text(localization["home_exercises"])
                .font(.headline)

            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                ExerciseDetailCard(
                    exercise: exercise,
                    index: index + 1,
                    localization: localization
                )
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: AppTheme.spacingM) {
            if !workout.isCompleted {
                Button(action: {
                    print("WorkoutDetailView: Start workout button tapped")
                    HapticsManager.shared.impact(.medium)
                    showActiveWorkout = true
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text(localization["home_start_workout"])
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if let log = dataStore.getSessionLog(for: workout.id) {
                // Show log summary
                LogSummaryCard(log: log, localization: localization)
            }
        }
    }

    // MARK: - Helpers

    private var difficultyColor: Color {
        switch workout.difficulty {
        case .beginner: return AppTheme.success
        case .intermediate: return AppTheme.warning
        case .advanced: return AppTheme.accent
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localization.currentLanguage.rawValue)
        formatter.dateStyle = .full
        return formatter.string(from: date).capitalized
    }
}

// MARK: - Exercise Detail Card

struct ExerciseDetailCard: View {
    let exercise: Exercise
    let index: Int
    let localization: LocalizationManager
    @EnvironmentObject var dataStore: DataStore
    @State private var showExerciseDetail = false

    var suggestedWeight: Double {
        dataStore.getDefaultWeight(for: exercise.nameKey, equipment: exercise.equipment)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                // Index badge
                Text("\(index)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(AppTheme.accent)
                    .clipShape(Circle())

                Text(localization[exercise.nameKey].trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.headline)

                Spacer()

                // Sets x Reps
                Text("\(exercise.sets) × \(exercise.reps)")
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.accent)
            }

            HStack(spacing: AppTheme.spacingL) {
                // Muscle groups
                HStack(spacing: AppTheme.spacingXS) {
                    ForEach(exercise.muscleGroups.prefix(2), id: \.self) { group in
                        Text(localization[group.localizedKey])
                            .font(.caption)
                            .padding(.horizontal, AppTheme.spacingS)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.1))
                            .cornerRadius(AppTheme.cornerRadiusSmall)
                    }
                }

                Spacer()

                // Rest time
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text("\(exercise.restSeconds) \(localization["workout_seconds"])")
                }
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
            }

            // Weight suggestion for dumbbell exercises
            if exercise.equipment == .dumbbells && suggestedWeight > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "scalemass.fill")
                        .foregroundColor(AppTheme.warning)
                    Text(String(format: "%.1f kg", suggestedWeight))
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.warning)
                    if dataStore.getLastWeight(for: exercise.nameKey) != nil {
                        Text("(\(localization["workout_last_weight"]))")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }

            // Tempo if available
            if let tempo = exercise.tempo {
                HStack {
                    Text(localization["workout_tempo"])
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text(tempo)
                        .font(.caption.bold())
                }
            }

            // How to button
            Button(action: {
                HapticsManager.shared.impact(.light)
                showExerciseDetail = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "play.circle.fill")
                    Text(localization["exercise_how_to"])
                }
                .font(.caption.bold())
                .foregroundColor(AppTheme.accent)
            }
        }
        .padding(AppTheme.spacingM)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusMedium)
        .sheet(isPresented: $showExerciseDetail) {
            ExerciseDetailSheet(exercise: exercise)
                .environmentObject(localization)
        }
    }
}

// MARK: - Log Summary Card

struct LogSummaryCard: View {
    let log: SessionLog
    let localization: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(AppTheme.success)
                Text(localization["home_completed"])
                    .font(.headline)
                Spacer()
                if let rating = log.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundColor(AppTheme.warning)
                                .font(.caption)
                        }
                    }
                }
            }

            if let duration = log.durationMinutes {
                HStack {
                    Image(systemName: "clock")
                    Text("\(duration) \(localization["home_minutes"])")
                }
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            }

            if !log.notes.isEmpty {
                Text(log.notes)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            Text(formatDate(log.date))
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(AppTheme.spacingM)
        .background(AppTheme.success.opacity(0.1))
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localization.currentLanguage.rawValue)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    WorkoutDetailView(
        workout: Workout(
            titleKey: "workout_full_body",
            weekIndex: 1,
            dayIndex: 1,
            exercises: [
                Exercise(nameKey: "ex_push_ups", muscleGroups: [.chest], equipment: .none, sets: 3, reps: 15),
                Exercise(nameKey: "ex_squats", muscleGroups: [.legs], equipment: .none, sets: 4, reps: 20),
            ],
            durationMinutes: 45,
            difficulty: .beginner
        )
    )
    .environmentObject(DataStore.shared)
    .environmentObject(LocalizationManager.shared)
}
