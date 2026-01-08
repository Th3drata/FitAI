import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var localization: LocalizationManager

    let workout: Workout

    @State private var currentExerciseIndex = 0
    @State private var currentSetIndex = 0
    @State private var exerciseRecords: [ExerciseRecord] = []
    @State private var isResting = false
    @State private var restTimeRemaining = 0
    @State private var timer: Timer?
    @State private var startTime = Date()
    @State private var showFinishSheet = false
    @State private var notes = ""
    @State private var rating = 0
    @State private var currentWeight: Double = 0
    @State private var currentReps: Int = 0
    @State private var sessionDifficulty: SessionDifficulty = .justRight
    @State private var isInitialized = false
    @State private var showExerciseDetail = false

    var body: some View {
        NavigationView {
            mainContent
                .navigationTitle(localization["active_workout_title"])
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(localization["cancel"]) {
                            stopTimer()
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(localization["active_workout_finish"]) {
                            showFinishSheet = true
                        }
                    }
                }
        }
        .onAppear {
            initializeWorkout()
        }
        .onDisappear {
            stopTimer()
        }
        .sheet(isPresented: $showFinishSheet) {
            finishWorkoutSheet
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()

            if workout.exercises.isEmpty {
                emptyWorkoutView
            } else if !isInitialized {
                loadingView
            } else if isResting {
                restTimerView
            } else if currentExerciseIndex < workout.exercises.count {
                exerciseContentView
            } else {
                workoutCompleteView
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: AppTheme.spacingL) {
            ProgressView()
                .scaleEffect(1.5)
            Text(localization["loading"])
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    // MARK: - Empty Workout View

    private var emptyWorkoutView: some View {
        VStack(spacing: AppTheme.spacingL) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.warning)
            Text("Aucun exercice dans cette séance")
                .font(.headline)
            Button(action: { dismiss() }) {
                Text(localization["close"])
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppTheme.spacingXL)
        }
    }

    // MARK: - Exercise Content View

    private var exerciseContentView: some View {
        let exercise = workout.exercises[currentExerciseIndex]

        return ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                // Progress indicator
                ProgressView(value: Double(currentExerciseIndex), total: Double(workout.exercises.count))
                    .tint(AppTheme.accent)
                    .padding(.horizontal, AppTheme.spacingL)
                    .padding(.top, AppTheme.spacingM)

                // Exercise info card
                VStack(spacing: AppTheme.spacingM) {
                    Text(localization[exercise.nameKey].trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    HStack(spacing: AppTheme.spacingXL) {
                        VStack {
                            Text(localization["active_workout_set"])
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            Text("\(currentSetIndex + 1)/\(exercise.sets)")
                                .font(.title2.bold())
                        }

                        VStack {
                            Text(localization["workout_reps"])
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            Text("\(exercise.reps)")
                                .font(.title2.bold())
                                .foregroundColor(AppTheme.accent)
                        }
                    }

                    // Muscle groups
                    HStack {
                        ForEach(exercise.muscleGroups, id: \.self) { group in
                            Text(localization[group.localizedKey])
                                .font(.caption)
                                .padding(.horizontal, AppTheme.spacingS)
                                .padding(.vertical, 4)
                                .background(AppTheme.accent.opacity(0.1))
                                .cornerRadius(AppTheme.cornerRadiusSmall)
                        }
                    }

                    if let tempo = exercise.tempo {
                        Text("\(localization["workout_tempo"]): \(tempo)")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
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
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.accent)
                        .padding(.horizontal, AppTheme.spacingM)
                        .padding(.vertical, AppTheme.spacingS)
                        .background(AppTheme.accent.opacity(0.1))
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                    }
                    .sheet(isPresented: $showExerciseDetail) {
                        ExerciseDetailSheet(exercise: exercise)
                            .environmentObject(localization)
                    }
                }
                .padding(AppTheme.spacingL)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(AppTheme.cornerRadiusMedium)
                .padding(.horizontal, AppTheme.spacingL)

                // Weight suggestion hint
                if exercise.equipment == .dumbbells {
                    weightSuggestionHint(for: exercise)
                }

                // Weight input
                weightInputSection

                // Reps input
                repsInputSection

                Spacer(minLength: AppTheme.spacingL)

                // Complete set button
                Button(action: completeSet) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("\(localization["workout_complete"]) \(localization["active_workout_set"]) \(currentSetIndex + 1)")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppTheme.spacingL)
                .padding(.bottom, AppTheme.spacingXL)
            }
        }
    }

    // MARK: - Weight Suggestion Hint

    @ViewBuilder
    private func weightSuggestionHint(for exercise: Exercise) -> some View {
        if let lastWeight = dataStore.getLastWeight(for: exercise.nameKey) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppTheme.warning)
                Text("\(localization["workout_last_weight"]): \(String(format: "%.1f", lastWeight)) kg")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                if let suggested = dataStore.getSuggestedWeight(for: exercise.nameKey), suggested != lastWeight {
                    Text("→ \(String(format: "%.1f", suggested)) kg")
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.accent)
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.vertical, AppTheme.spacingS)
            .background(AppTheme.warning.opacity(0.1))
            .cornerRadius(AppTheme.cornerRadiusSmall)
            .padding(.horizontal, AppTheme.spacingL)
        }
    }

    // MARK: - Weight Input Section

    private var weightInputSection: some View {
        HStack {
            Text(localization["workout_weight_used"])
                .font(.subheadline)
            Spacer()
            HStack(spacing: AppTheme.spacingM) {
                Button(action: {
                    if currentWeight > 0 {
                        currentWeight -= 0.5
                        HapticsManager.shared.selection()
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.accent)
                }

                Text(String(format: "%.1f kg", currentWeight))
                    .font(.headline.monospacedDigit())
                    .frame(width: 80)

                Button(action: {
                    currentWeight += 0.5
                    HapticsManager.shared.selection()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .padding(AppTheme.spacingM)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusMedium)
        .padding(.horizontal, AppTheme.spacingL)
    }

    // MARK: - Reps Input Section

    private var repsInputSection: some View {
        HStack {
            Text(localization["workout_reps_done"])
                .font(.subheadline)
            Spacer()
            HStack(spacing: AppTheme.spacingM) {
                Button(action: {
                    if currentReps > 0 {
                        currentReps -= 1
                        HapticsManager.shared.selection()
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.accent)
                }

                Text("\(currentReps)")
                    .font(.headline.monospacedDigit())
                    .frame(width: 60)

                Button(action: {
                    currentReps += 1
                    HapticsManager.shared.selection()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .padding(AppTheme.spacingM)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusMedium)
        .padding(.horizontal, AppTheme.spacingL)
    }

    // MARK: - Rest Timer View

    private var restTimerView: some View {
        VStack(spacing: AppTheme.spacingXL) {
            Spacer()

            Text(localization["active_workout_rest_timer"])
                .font(.title2)
                .foregroundColor(AppTheme.textSecondary)

            Text("\(restTimeRemaining)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.accent)

            Text(localization["workout_seconds"])
                .font(.title3)
                .foregroundColor(AppTheme.textSecondary)

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: CGFloat(restTimeRemaining) / CGFloat(workout.exercises[safe: currentExerciseIndex]?.restSeconds ?? 90))
                    .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: restTimeRemaining)
            }

            Spacer()

            Button(action: skipRest) {
                HStack {
                    Image(systemName: "forward.fill")
                    Text(localization["active_workout_skip_rest"])
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.horizontal, AppTheme.spacingXL)
            .padding(.bottom, AppTheme.spacingXL)
        }
    }

    // MARK: - Workout Complete View

    private var workoutCompleteView: some View {
        VStack(spacing: AppTheme.spacingXL) {
            Spacer()

            Image(systemName: "trophy.fill")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.warning)

            Text(localization["workout_session_saved"])
                .font(.title.bold())

            Text("\(localization["home_exercises"]): \(workout.exercises.count)")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)

            Spacer()

            Button(action: { showFinishSheet = true }) {
                Text(localization["active_workout_finish"])
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppTheme.spacingL)
            .padding(.bottom, AppTheme.spacingXL)
        }
    }

    // MARK: - Finish Workout Sheet

    private var finishWorkoutSheet: some View {
        NavigationView {
            Form {
                // Difficulty feedback
                Section(header: Text(localization["workout_difficulty_question"])) {
                    VStack(spacing: AppTheme.spacingM) {
                        Text(localization["workout_difficulty_desc"])
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: AppTheme.spacingM) {
                            ForEach(SessionDifficulty.allCases, id: \.self) { difficulty in
                                DifficultyOptionView(
                                    difficulty: difficulty,
                                    isSelected: sessionDifficulty == difficulty,
                                    localization: localization
                                )
                                .onTapGesture {
                                    HapticsManager.shared.selection()
                                    sessionDifficulty = difficulty
                                }
                            }
                        }
                    }
                    .padding(.vertical, AppTheme.spacingS)
                }

                Section(header: Text(localization["workout_rate"])) {
                    HStack {
                        Spacer()
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.title)
                                .foregroundColor(AppTheme.warning)
                                .onTapGesture {
                                    HapticsManager.shared.selection()
                                    // Si on clique sur l'étoile déjà sélectionnée, on descend d'un niveau
                                    if star == rating {
                                        rating = star - 1
                                    } else {
                                        rating = star
                                    }
                                }
                        }
                        Spacer()
                    }
                    .padding(.vertical, AppTheme.spacingS)
                }

                Section(header: Text(localization["workout_notes"])) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(localization["workout_log_session"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localization["cancel"]) {
                        showFinishSheet = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localization["save"]) {
                        saveSession()
                    }
                    .bold()
                }
            }
        }
    }

    // MARK: - Logic

    private func initializeWorkout() {
        print("ActiveWorkoutView: Initializing workout with \(workout.exercises.count) exercises")

        // Initialize exercise records
        exerciseRecords = workout.exercises.map { exercise in
            ExerciseRecord(
                exerciseId: exercise.id,
                exerciseNameKey: exercise.nameKey,
                setsCompleted: []
            )
        }

        // Initialize first exercise values
        if let firstExercise = workout.exercises.first {
            currentReps = firstExercise.reps
            currentWeight = dataStore.getDefaultWeight(for: firstExercise.nameKey, equipment: firstExercise.equipment)
        }

        startTime = Date()
        isInitialized = true
    }

    private func completeSet() {
        guard currentExerciseIndex < workout.exercises.count else { return }
        let exercise = workout.exercises[currentExerciseIndex]

        HapticsManager.shared.impact(.medium)

        // Record the set
        let setRecord = SetRecord(
            setNumber: currentSetIndex + 1,
            reps: currentReps,
            weightKg: currentWeight,
            isCompleted: true
        )

        exerciseRecords[currentExerciseIndex].setsCompleted.append(setRecord)

        // Move to next set or exercise
        if currentSetIndex + 1 < exercise.sets {
            currentSetIndex += 1
            startRestTimer(seconds: exercise.restSeconds)
        } else {
            // Move to next exercise
            currentSetIndex = 0
            if currentExerciseIndex + 1 < workout.exercises.count {
                currentExerciseIndex += 1
                // Set values for next exercise
                let nextExercise = workout.exercises[currentExerciseIndex]
                currentReps = nextExercise.reps
                currentWeight = dataStore.getDefaultWeight(for: nextExercise.nameKey, equipment: nextExercise.equipment)
                startRestTimer(seconds: exercise.restSeconds)
            } else {
                // Workout complete
                currentExerciseIndex = workout.exercises.count
                HapticsManager.shared.notification(.success)
            }
        }
    }

    private func startRestTimer(seconds: Int) {
        isResting = true
        restTimeRemaining = seconds

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if restTimeRemaining > 0 {
                restTimeRemaining -= 1
            } else {
                stopTimer()
                isResting = false
            }
        }
    }

    private func skipRest() {
        HapticsManager.shared.impact(.light)
        stopTimer()
        isResting = false
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func saveSession() {
        let duration = Int(Date().timeIntervalSince(startTime) / 60)

        let log = SessionLog(
            date: Date(),
            workoutId: workout.id,
            workoutTitleKey: workout.titleKey,
            notes: notes,
            exerciseRecords: exerciseRecords,
            durationMinutes: duration,
            rating: rating > 0 ? rating : nil,
            difficulty: sessionDifficulty
        )

        dataStore.addSessionLog(log)
        HapticsManager.shared.notification(.success)
        showFinishSheet = false
        dismiss()
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Difficulty Option View Component

struct DifficultyOptionView: View {
    let difficulty: SessionDifficulty
    let isSelected: Bool
    let localization: LocalizationManager

    var icon: String {
        switch difficulty {
        case .tooEasy: return "arrow.up.circle.fill"
        case .justRight: return "checkmark.circle.fill"
        case .tooHard: return "arrow.down.circle.fill"
        }
    }

    var color: Color {
        switch difficulty {
        case .tooEasy: return AppTheme.success
        case .justRight: return AppTheme.accent
        case .tooHard: return AppTheme.error
        }
    }

    var body: some View {
        VStack(spacing: AppTheme.spacingXS) {
            Image(systemName: icon)
                .font(.title2)
            Text(localization[difficulty.localizedKey])
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.spacingM)
        .background(isSelected ? color.opacity(0.2) : AppTheme.backgroundSecondary)
        .foregroundColor(isSelected ? color : AppTheme.textSecondary)
        .cornerRadius(AppTheme.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(isSelected ? color : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
    }
}

#Preview {
    ActiveWorkoutView(
        workout: Workout(
            titleKey: "workout_full_body",
            weekIndex: 1,
            dayIndex: 1,
            exercises: [
                Exercise(nameKey: "ex_push_ups", muscleGroups: [.chest], equipment: .none, sets: 3, reps: 15, restSeconds: 60),
                Exercise(nameKey: "ex_squats", muscleGroups: [.legs], equipment: .none, sets: 4, reps: 20, restSeconds: 90),
            ],
            durationMinutes: 45,
            difficulty: .beginner
        )
    )
    .environmentObject(DataStore.shared)
    .environmentObject(LocalizationManager.shared)
}
