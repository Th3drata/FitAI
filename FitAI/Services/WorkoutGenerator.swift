import Foundation

class WorkoutGenerator {
    static let shared = WorkoutGenerator()

    // MARK: - User Performance Tracking

    struct PerformanceAnalysis {
        var averageRating: Double          // Average rating from recent sessions (1-5)
        var averageDifficulty: Double      // Average perceived difficulty
        var completionRate: Double         // % of exercises completed
        var consistencyScore: Double       // How consistent the user is
        var recommendedIntensityAdjustment: Double // -0.2 to +0.2 multiplier
        var sessionCount: Int              // Number of sessions analyzed

        static let baseline = PerformanceAnalysis(
            averageRating: 3.5,
            averageDifficulty: 2.0,
            completionRate: 1.0,
            consistencyScore: 1.0,
            recommendedIntensityAdjustment: 0.0,
            sessionCount: 0
        )
    }

    // MARK: - Exercise Database

    private let dumbbellExercises: [MuscleGroup: [Exercise]] = [
        .chest: [
            Exercise(nameKey: "ex_dumbbell_bench_press", muscleGroups: [.chest, .triceps], equipment: .dumbbells, sets: 4, reps: 10, tempo: "3-1-2", restSeconds: 90),
            Exercise(nameKey: "ex_dumbbell_flyes", muscleGroups: [.chest], equipment: .dumbbells, sets: 3, reps: 12, tempo: "3-1-2", restSeconds: 60),
            Exercise(nameKey: "ex_incline_dumbbell_press", muscleGroups: [.chest, .shoulders], equipment: .dumbbells, sets: 4, reps: 10, tempo: "3-1-2", restSeconds: 90),
            Exercise(nameKey: "ex_dumbbell_pullover", muscleGroups: [.chest, .back], equipment: .dumbbells, sets: 3, reps: 12, restSeconds: 60),
        ],
        .back: [
            Exercise(nameKey: "ex_dumbbell_rows", muscleGroups: [.back, .biceps], equipment: .dumbbells, sets: 4, reps: 10, tempo: "2-1-3", restSeconds: 90),
            Exercise(nameKey: "ex_single_arm_row", muscleGroups: [.back], equipment: .dumbbells, sets: 3, reps: 12, restSeconds: 60),
            Exercise(nameKey: "ex_renegade_rows", muscleGroups: [.back, .core], equipment: .dumbbells, sets: 3, reps: 10, restSeconds: 90),
            Exercise(nameKey: "ex_dumbbell_deadlift", muscleGroups: [.back, .legs, .glutes], equipment: .dumbbells, sets: 4, reps: 8, restSeconds: 120),
        ],
        .shoulders: [
            Exercise(nameKey: "ex_dumbbell_shoulder_press", muscleGroups: [.shoulders, .triceps], equipment: .dumbbells, sets: 4, reps: 10, tempo: "2-1-2", restSeconds: 90),
            Exercise(nameKey: "ex_lateral_raises", muscleGroups: [.shoulders], equipment: .dumbbells, sets: 3, reps: 15, restSeconds: 60),
            Exercise(nameKey: "ex_front_raises", muscleGroups: [.shoulders], equipment: .dumbbells, sets: 3, reps: 12, restSeconds: 60),
            Exercise(nameKey: "ex_rear_delt_flyes", muscleGroups: [.shoulders, .back], equipment: .dumbbells, sets: 3, reps: 15, restSeconds: 60),
            Exercise(nameKey: "ex_dumbbell_shrugs", muscleGroups: [.shoulders], equipment: .dumbbells, sets: 3, reps: 15, restSeconds: 60),
            Exercise(nameKey: "ex_arnold_press", muscleGroups: [.shoulders, .triceps], equipment: .dumbbells, sets: 4, reps: 10, tempo: "2-1-2", restSeconds: 90),
        ],
        .biceps: [
            Exercise(nameKey: "ex_bicep_curls", muscleGroups: [.biceps], equipment: .dumbbells, sets: 3, reps: 12, tempo: "3-1-2", restSeconds: 60),
            Exercise(nameKey: "ex_hammer_curls", muscleGroups: [.biceps], equipment: .dumbbells, sets: 3, reps: 12, restSeconds: 60),
            Exercise(nameKey: "ex_concentration_curls", muscleGroups: [.biceps], equipment: .dumbbells, sets: 3, reps: 10, restSeconds: 60),
            Exercise(nameKey: "ex_incline_curls", muscleGroups: [.biceps], equipment: .dumbbells, sets: 3, reps: 10, restSeconds: 60),
        ],
        .triceps: [
            Exercise(nameKey: "ex_tricep_kickbacks", muscleGroups: [.triceps], equipment: .dumbbells, sets: 3, reps: 12, restSeconds: 60),
            Exercise(nameKey: "ex_tricep_extensions", muscleGroups: [.triceps], equipment: .dumbbells, sets: 3, reps: 12, restSeconds: 60),
            Exercise(nameKey: "ex_skull_crushers", muscleGroups: [.triceps], equipment: .dumbbells, sets: 3, reps: 10, restSeconds: 60),
        ],
        .legs: [
            Exercise(nameKey: "ex_goblet_squats", muscleGroups: [.legs, .glutes], equipment: .dumbbells, sets: 4, reps: 12, tempo: "3-1-2", restSeconds: 90),
            Exercise(nameKey: "ex_lunges", muscleGroups: [.legs, .glutes], equipment: .dumbbells, sets: 3, reps: 10, restSeconds: 60),
            Exercise(nameKey: "ex_bulgarian_split_squats", muscleGroups: [.legs, .glutes], equipment: .dumbbells, sets: 3, reps: 10, restSeconds: 90),
            Exercise(nameKey: "ex_dumbbell_rdl", muscleGroups: [.legs, .back, .glutes], equipment: .dumbbells, sets: 4, reps: 10, restSeconds: 90),
            Exercise(nameKey: "ex_calf_raises", muscleGroups: [.legs], equipment: .dumbbells, sets: 4, reps: 15, restSeconds: 45),
            Exercise(nameKey: "ex_step_ups", muscleGroups: [.legs, .glutes], equipment: .dumbbells, sets: 3, reps: 10, restSeconds: 60),
            Exercise(nameKey: "ex_sumo_squats", muscleGroups: [.legs, .glutes], equipment: .dumbbells, sets: 4, reps: 12, restSeconds: 90),
        ],
        .glutes: [
            Exercise(nameKey: "ex_glute_bridges", muscleGroups: [.glutes, .legs], equipment: .dumbbells, sets: 4, reps: 15, restSeconds: 60),
            Exercise(nameKey: "ex_hip_thrusts", muscleGroups: [.glutes], equipment: .dumbbells, sets: 4, reps: 12, restSeconds: 90),
        ],
        .core: [
            Exercise(nameKey: "ex_russian_twists", muscleGroups: [.core], equipment: .dumbbells, sets: 3, reps: 20, restSeconds: 45),
            Exercise(nameKey: "ex_weighted_crunches", muscleGroups: [.core], equipment: .dumbbells, sets: 3, reps: 15, restSeconds: 45),
        ]
    ]

    private let bodyweightExercises: [MuscleGroup: [Exercise]] = [
        .chest: [
            Exercise(nameKey: "ex_push_ups", muscleGroups: [.chest, .triceps], equipment: .none, sets: 4, reps: 15, tempo: "2-1-2", restSeconds: 60),
            Exercise(nameKey: "ex_diamond_push_ups", muscleGroups: [.chest, .triceps], equipment: .none, sets: 3, reps: 12, restSeconds: 60),
            Exercise(nameKey: "ex_wide_push_ups", muscleGroups: [.chest], equipment: .none, sets: 3, reps: 15, restSeconds: 60),
            Exercise(nameKey: "ex_decline_push_ups", muscleGroups: [.chest, .shoulders], equipment: .none, sets: 3, reps: 12, restSeconds: 60),
            Exercise(nameKey: "ex_archer_push_ups", muscleGroups: [.chest, .triceps], equipment: .none, sets: 3, reps: 8, restSeconds: 90),
        ],
        .shoulders: [
            Exercise(nameKey: "ex_pike_push_ups", muscleGroups: [.shoulders, .triceps], equipment: .none, sets: 3, reps: 12, restSeconds: 60),
            Exercise(nameKey: "ex_handstand_hold", muscleGroups: [.shoulders, .core], equipment: .none, sets: 3, reps: 30, notesKey: "seconds", restSeconds: 60),
        ],
        .triceps: [
            Exercise(nameKey: "ex_close_grip_push_ups", muscleGroups: [.triceps, .chest], equipment: .none, sets: 3, reps: 12, restSeconds: 60),
            Exercise(nameKey: "ex_bench_dips", muscleGroups: [.triceps], equipment: .none, sets: 3, reps: 15, restSeconds: 60),
        ],
        .legs: [
            Exercise(nameKey: "ex_squats", muscleGroups: [.legs, .glutes], equipment: .none, sets: 4, reps: 20, tempo: "2-1-2", restSeconds: 60),
            Exercise(nameKey: "ex_jump_squats", muscleGroups: [.legs, .glutes], equipment: .none, sets: 3, reps: 15, restSeconds: 60),
            Exercise(nameKey: "ex_lunges", muscleGroups: [.legs, .glutes], equipment: .none, sets: 3, reps: 12, restSeconds: 60),
            Exercise(nameKey: "ex_wall_sit", muscleGroups: [.legs], equipment: .none, sets: 3, reps: 45, notesKey: "seconds", restSeconds: 60),
            Exercise(nameKey: "ex_calf_raises", muscleGroups: [.legs], equipment: .none, sets: 4, reps: 20, restSeconds: 45),
            Exercise(nameKey: "ex_pistol_squats", muscleGroups: [.legs, .glutes], equipment: .none, sets: 3, reps: 5, restSeconds: 90),
            Exercise(nameKey: "ex_jumping_lunges", muscleGroups: [.legs, .glutes], equipment: .none, sets: 3, reps: 12, restSeconds: 60),
        ],
        .glutes: [
            Exercise(nameKey: "ex_glute_bridges", muscleGroups: [.glutes, .legs], equipment: .none, sets: 4, reps: 20, restSeconds: 60),
            Exercise(nameKey: "ex_single_leg_glute_bridge", muscleGroups: [.glutes], equipment: .none, sets: 3, reps: 12, restSeconds: 60),
            Exercise(nameKey: "ex_donkey_kicks", muscleGroups: [.glutes], equipment: .none, sets: 3, reps: 15, restSeconds: 45),
        ],
        .core: [
            Exercise(nameKey: "ex_plank", muscleGroups: [.core], equipment: .none, sets: 3, reps: 60, notesKey: "seconds", restSeconds: 45),
            Exercise(nameKey: "ex_side_plank", muscleGroups: [.core], equipment: .none, sets: 3, reps: 30, notesKey: "seconds", restSeconds: 45),
            Exercise(nameKey: "ex_mountain_climbers", muscleGroups: [.core, .legs], equipment: .none, sets: 3, reps: 30, restSeconds: 45),
            Exercise(nameKey: "ex_leg_raises", muscleGroups: [.core], equipment: .none, sets: 3, reps: 15, restSeconds: 45),
            Exercise(nameKey: "ex_crunches", muscleGroups: [.core], equipment: .none, sets: 3, reps: 20, restSeconds: 45),
            Exercise(nameKey: "ex_bicycle_crunches", muscleGroups: [.core], equipment: .none, sets: 3, reps: 20, restSeconds: 45),
            Exercise(nameKey: "ex_dead_bug", muscleGroups: [.core], equipment: .none, sets: 3, reps: 15, restSeconds: 45),
            Exercise(nameKey: "ex_hollow_hold", muscleGroups: [.core], equipment: .none, sets: 3, reps: 30, notesKey: "seconds", restSeconds: 45),
            Exercise(nameKey: "ex_v_ups", muscleGroups: [.core], equipment: .none, sets: 3, reps: 12, restSeconds: 45),
        ],
        .back: [
            Exercise(nameKey: "ex_superman", muscleGroups: [.back, .glutes], equipment: .none, sets: 3, reps: 15, restSeconds: 45),
            Exercise(nameKey: "ex_reverse_snow_angels", muscleGroups: [.back, .shoulders], equipment: .none, sets: 3, reps: 12, restSeconds: 45),
        ],
        .fullBody: [
            Exercise(nameKey: "ex_burpees", muscleGroups: [.fullBody], equipment: .none, sets: 3, reps: 10, restSeconds: 60),
            Exercise(nameKey: "ex_jumping_jacks", muscleGroups: [.fullBody], equipment: .none, sets: 3, reps: 30, restSeconds: 30),
            Exercise(nameKey: "ex_high_knees", muscleGroups: [.legs, .core], equipment: .none, sets: 3, reps: 30, restSeconds: 30),
            Exercise(nameKey: "ex_star_jumps", muscleGroups: [.fullBody], equipment: .none, sets: 3, reps: 15, restSeconds: 45),
        ]
    ]

    // MARK: - Performance Analysis

    func analyzePerformance(sessionLogs: [SessionLog], recentWeeks: Int = 2) -> PerformanceAnalysis {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .weekOfYear, value: -recentWeeks, to: Date()) ?? Date()

        let recentSessions = sessionLogs.filter { $0.date >= cutoffDate }

        guard !recentSessions.isEmpty else {
            return .baseline
        }

        // Calculate average rating
        let sessionsWithRating = recentSessions.compactMap { $0.rating }
        let averageRating = sessionsWithRating.isEmpty ? 3.5 : Double(sessionsWithRating.reduce(0, +)) / Double(sessionsWithRating.count)

        // Calculate average difficulty perception
        let sessionsWithDifficulty = recentSessions.compactMap { $0.difficulty }
        let difficultyScores = sessionsWithDifficulty.map { difficulty -> Double in
            switch difficulty {
            case .tooEasy: return 1.0
            case .justRight: return 2.0
            case .tooHard: return 3.0
            }
        }
        let averageDifficulty = difficultyScores.isEmpty ? 2.0 : difficultyScores.reduce(0, +) / Double(difficultyScores.count)

        // Calculate completion rate (based on exercise records)
        var totalExercises = 0
        var completedExercises = 0
        for session in recentSessions {
            totalExercises += session.exerciseRecords.count
            // An exercise is considered completed if it has at least one completed set
            completedExercises += session.exerciseRecords.filter { record in
                record.setsCompleted.contains { $0.isCompleted }
            }.count
        }
        let completionRate = totalExercises > 0 ? Double(completedExercises) / Double(totalExercises) : 1.0

        // Calculate consistency (sessions per week average)
        let weeksAnalyzed = max(1, recentWeeks)
        let sessionsPerWeek = Double(recentSessions.count) / Double(weeksAnalyzed)
        let consistencyScore = min(sessionsPerWeek / 4.0, 1.0) // Normalize to 4 sessions/week = 100%

        // Calculate recommended intensity adjustment
        var intensityAdjustment = 0.0

        // Based on difficulty feedback
        if averageDifficulty < 1.5 {
            // Sessions are too easy - increase intensity
            intensityAdjustment += 0.15
        } else if averageDifficulty > 2.5 {
            // Sessions are too hard - decrease intensity
            intensityAdjustment -= 0.15
        }

        // Based on ratings
        if averageRating >= 4.5 {
            // User is loving it - slight increase to keep challenging
            intensityAdjustment += 0.05
        } else if averageRating < 2.5 {
            // User is not enjoying - might be too hard or boring
            intensityAdjustment -= 0.1
        }

        // Based on completion rate
        if completionRate < 0.7 {
            // User not completing exercises - too hard
            intensityAdjustment -= 0.1
        } else if completionRate >= 0.95 {
            // Perfect completion - can push harder
            intensityAdjustment += 0.05
        }

        // Clamp adjustment between -0.2 and +0.2
        intensityAdjustment = max(-0.2, min(0.2, intensityAdjustment))

        return PerformanceAnalysis(
            averageRating: averageRating,
            averageDifficulty: averageDifficulty,
            completionRate: completionRate,
            consistencyScore: consistencyScore,
            recommendedIntensityAdjustment: intensityAdjustment,
            sessionCount: recentSessions.count
        )
    }

    // MARK: - Program Generation

    func generateWeekProgram(profile: UserProfile, weekIndex: Int, sessionLogs: [SessionLog] = [], startDate: Date? = nil) -> WeekProgram {
        let sessions = profile.sessionsPerWeek
        let equipment = profile.equipment

        // Analyze past performance
        let performance = analyzePerformance(sessionLogs: sessionLogs)

        // Determine split type based on sessions per week
        var workouts: [Workout]
        if sessions <= 4 {
            workouts = generateFullBodySplit(sessions: sessions, equipment: equipment, weekIndex: weekIndex, performance: performance)
        } else {
            workouts = generatePushPullLegsSplit(sessions: sessions, equipment: equipment, weekIndex: weekIndex, performance: performance)
        }

        // Adjust workouts based on fitness goal
        workouts = adjustForGoal(workouts: workouts, goal: profile.fitnessGoal)

        // Apply adaptive intensity based on past performance
        workouts = applyAdaptiveIntensity(workouts: workouts, performance: performance)

        // Mark last session of the week as challenge
        if !workouts.isEmpty {
            workouts[workouts.count - 1] = makeChallengeWorkout(workouts[workouts.count - 1])
        }

        // Schedule workouts from the provided start date or today
        var scheduledWorkouts = scheduleWorkouts(workouts, sessionsPerWeek: sessions, startDate: startDate)

        // Apply progression
        scheduledWorkouts = applyProgression(workouts: scheduledWorkouts, weekIndex: weekIndex)

        return WeekProgram(weekIndex: weekIndex, workouts: scheduledWorkouts)
    }

    // MARK: - Adaptive Intensity

    private func applyAdaptiveIntensity(workouts: [Workout], performance: PerformanceAnalysis) -> [Workout] {
        let adjustment = performance.recommendedIntensityAdjustment

        // No adjustment needed if user has no history
        guard performance.sessionCount > 0 else { return workouts }

        return workouts.map { workout in
            var adjusted = workout
            adjusted.exercises = workout.exercises.map { exercise in
                var ex = exercise

                if adjustment > 0 {
                    // Increase intensity: more reps or sets
                    if adjustment > 0.1 {
                        ex.sets = min(exercise.sets + 1, 6)
                    }
                    ex.reps = min(exercise.reps + Int(Double(exercise.reps) * adjustment), exercise.reps + 5)
                    ex.restSeconds = max(exercise.restSeconds - 10, 30)
                } else if adjustment < 0 {
                    // Decrease intensity: fewer reps, more rest
                    ex.reps = max(exercise.reps + Int(Double(exercise.reps) * adjustment), exercise.reps - 3)
                    ex.restSeconds = min(exercise.restSeconds + 15, 120)
                }

                return ex
            }
            return adjusted
        }
    }

    // MARK: - Challenge Workout

    private func makeChallengeWorkout(_ workout: Workout) -> Workout {
        var challenge = workout
        challenge.titleKey = "workout_challenge"
        challenge.isChallenge = true
        challenge.difficulty = .advanced

        // Increase intensity for challenge
        challenge.exercises = workout.exercises.map { exercise in
            var ex = exercise
            ex.sets = min(exercise.sets + 1, 5)
            ex.reps = exercise.reps + 3
            ex.restSeconds = max(exercise.restSeconds - 15, 30)
            return ex
        }

        // Add an extra finisher exercise
        let finisher = createFinisherExercise(equipment: workout.exercises.first?.equipment ?? .none)
        challenge.exercises.append(finisher)

        // Recalculate duration
        challenge.durationMinutes = calculateDuration(exercises: challenge.exercises)

        return challenge
    }

    private func createFinisherExercise(equipment: Equipment) -> Exercise {
        if equipment == .dumbbells {
            return Exercise(
                nameKey: "ex_dumbbell_complex",
                muscleGroups: [.fullBody],
                equipment: .dumbbells,
                sets: 3,
                reps: 10,
                notesKey: "ex_complex_note",
                restSeconds: 60
            )
        } else {
            return Exercise(
                nameKey: "ex_burpees",
                muscleGroups: [.fullBody],
                equipment: .none,
                sets: 4,
                reps: 12,
                restSeconds: 45
            )
        }
    }

    // MARK: - Goal Adjustments

    private func adjustForGoal(workouts: [Workout], goal: FitnessGoal) -> [Workout] {
        return workouts.map { workout in
            var adjustedWorkout = workout
            adjustedWorkout.exercises = workout.exercises.map { exercise in
                var adjustedExercise = exercise

                switch goal {
                case .weightLoss:
                    // Higher reps, shorter rest for metabolic effect
                    adjustedExercise.reps = min(exercise.reps + 5, 20)
                    adjustedExercise.restSeconds = max(exercise.restSeconds - 15, 30)
                case .muscleGain:
                    // Moderate reps, standard rest for hypertrophy
                    // Keep defaults
                    break
                case .maintenance:
                    // Balanced approach
                    break
                case .recomposition:
                    // Slightly higher reps, moderate rest
                    adjustedExercise.reps = min(exercise.reps + 2, 15)
                    adjustedExercise.restSeconds = max(exercise.restSeconds - 10, 45)
                }

                return adjustedExercise
            }
            return adjustedWorkout
        }
    }

    // MARK: - Full Body Split (3-4 sessions)

    private func generateFullBodySplit(sessions: Int, equipment: Equipment, weekIndex: Int, performance: PerformanceAnalysis) -> [Workout] {
        var workouts: [Workout] = []
        let exerciseDB = equipment == .dumbbells ? dumbbellExercises : bodyweightExercises

        for day in 0..<sessions {
            var exercises: [Exercise] = []

            // Vary exercise selection based on day to avoid repetition
            let variation = (weekIndex + day) % 3

            // Compound movements first
            if let chestExercises = exerciseDB[.chest]?.shuffled() {
                let index = min(variation, chestExercises.count - 1)
                exercises.append(chestExercises[index])
            }
            if let backExercises = exerciseDB[.back]?.shuffled() {
                let index = min(variation, backExercises.count - 1)
                exercises.append(backExercises[index])
            }
            if let shoulderExercises = exerciseDB[.shoulders]?.shuffled() {
                exercises.append(contentsOf: Array(shoulderExercises.prefix(1)))
            }
            if let legExercises = exerciseDB[.legs]?.shuffled() {
                exercises.append(contentsOf: Array(legExercises.prefix(2)))
            }

            // Accessory work - alternate focus each day
            if day % 2 == 0 {
                if let bicepsExercises = exerciseDB[.biceps]?.shuffled() {
                    exercises.append(contentsOf: Array(bicepsExercises.prefix(1)))
                }
            } else {
                if let tricepsExercises = exerciseDB[.triceps]?.shuffled() {
                    exercises.append(contentsOf: Array(tricepsExercises.prefix(1)))
                }
            }

            // Core at the end
            if let coreExercises = exerciseDB[.core]?.shuffled() {
                exercises.append(contentsOf: Array(coreExercises.prefix(2)))
            }

            // Determine base difficulty from performance
            let baseDifficulty = getDifficultyFromPerformance(weekIndex: weekIndex, performance: performance)

            let workout = Workout(
                titleKey: "workout_full_body",
                weekIndex: weekIndex,
                dayIndex: day + 1,
                exercises: exercises,
                durationMinutes: calculateDuration(exercises: exercises),
                difficulty: baseDifficulty
            )
            workouts.append(workout)
        }

        return workouts
    }

    // MARK: - Push/Pull/Legs Split (5-6 sessions)

    private func generatePushPullLegsSplit(sessions: Int, equipment: Equipment, weekIndex: Int, performance: PerformanceAnalysis) -> [Workout] {
        var workouts: [Workout] = []
        let exerciseDB = equipment == .dumbbells ? dumbbellExercises : bodyweightExercises

        let splitPattern: [(String, [MuscleGroup])] = [
            ("workout_push", [.chest, .shoulders, .triceps]),
            ("workout_pull", [.back, .biceps]),
            ("workout_legs", [.legs, .glutes]),
            ("workout_push", [.chest, .shoulders, .triceps]),
            ("workout_pull", [.back, .biceps]),
            ("workout_legs", [.legs, .glutes])
        ]

        for day in 0..<sessions {
            let (titleKey, muscleGroups) = splitPattern[day]
            var exercises: [Exercise] = []

            // Vary exercise selection based on week and day
            let variation = (weekIndex + day) % 2

            for group in muscleGroups {
                if let groupExercises = exerciseDB[group]?.shuffled() {
                    let count = group == muscleGroups.first ? 2 : 1
                    let startIndex = variation * count
                    let availableExercises = Array(groupExercises.dropFirst(startIndex % max(1, groupExercises.count - count)))
                    exercises.append(contentsOf: Array(availableExercises.prefix(count)))
                }
            }

            // Add core on leg days
            if muscleGroups.contains(.legs), let coreExercises = exerciseDB[.core]?.shuffled() {
                exercises.append(contentsOf: Array(coreExercises.prefix(2)))
            }

            let baseDifficulty = getDifficultyFromPerformance(weekIndex: weekIndex, performance: performance)

            let workout = Workout(
                titleKey: titleKey,
                weekIndex: weekIndex,
                dayIndex: day + 1,
                exercises: exercises,
                durationMinutes: calculateDuration(exercises: exercises),
                difficulty: baseDifficulty
            )
            workouts.append(workout)
        }

        return workouts
    }

    // MARK: - Helpers

    private func getDifficultyFromPerformance(weekIndex: Int, performance: PerformanceAnalysis) -> Difficulty {
        // Base difficulty on week
        var baseDifficulty: Difficulty
        switch weekIndex {
        case 1...2: baseDifficulty = .beginner
        case 3...5: baseDifficulty = .intermediate
        default: baseDifficulty = .advanced
        }

        // Adjust based on performance if we have data
        if performance.sessionCount >= 3 {
            if performance.averageDifficulty < 1.5 && performance.completionRate > 0.9 {
                // Sessions too easy and completing everything - bump up
                switch baseDifficulty {
                case .beginner: baseDifficulty = .intermediate
                case .intermediate: baseDifficulty = .advanced
                case .advanced: break
                }
            } else if performance.averageDifficulty > 2.5 || performance.completionRate < 0.6 {
                // Sessions too hard or not completing - bump down
                switch baseDifficulty {
                case .beginner: break
                case .intermediate: baseDifficulty = .beginner
                case .advanced: baseDifficulty = .intermediate
                }
            }
        }

        return baseDifficulty
    }

    private func scheduleWorkouts(_ workouts: [Workout], sessionsPerWeek: Int, startDate: Date? = nil) -> [Workout] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: startDate ?? Date())

        // Schedule workouts over a full 7-day week, respecting user's sessionsPerWeek preference
        let daysInWeek = 7
        let workoutsToSchedule = min(workouts.count, sessionsPerWeek)
        
        var workoutDays: [Int] = []
        
        if workoutsToSchedule > 0 {
            if workoutsToSchedule == 1 {
                // Single workout: schedule on day 0 (start date)
                workoutDays = [0]
            } else if workoutsToSchedule == daysInWeek {
                // Workout every day of the week
                workoutDays = Array(0..<daysInWeek)
            } else {
                // Distribute workouts evenly across the 7-day week
                // Calculate spacing between workouts
                let spacing = Double(daysInWeek) / Double(workoutsToSchedule)
                
                for i in 0..<workoutsToSchedule {
                    let day = Int(round(Double(i) * spacing))
                    // Ensure we don't exceed 6 days (0-6 for a 7-day week)
                    workoutDays.append(min(day, daysInWeek - 1))
                }
                
                // Remove duplicates and sort
                workoutDays = Array(Set(workoutDays)).sorted()
                
                // If we lost some days due to rounding, add them back
                while workoutDays.count < workoutsToSchedule && workoutDays.count < daysInWeek {
                    // Find the largest gap and add a day there
                    var largestGap = 0
                    var gapIndex = 0
                    
                    for i in 0..<(workoutDays.count - 1) {
                        let gap = workoutDays[i + 1] - workoutDays[i]
                        if gap > largestGap {
                            largestGap = gap
                            gapIndex = i
                        }
                    }
                    
                    // Add a day in the middle of the largest gap
                    let newDay = workoutDays[gapIndex] + largestGap / 2
                    if newDay < daysInWeek && !workoutDays.contains(newDay) {
                        workoutDays.append(newDay)
                        workoutDays.sort()
                    } else {
                        break
                    }
                }
            }
        }

        var scheduledWorkouts: [Workout] = []
        for (index, workout) in workouts.prefix(workoutsToSchedule).enumerated() {
            var scheduled = workout
            if index < workoutDays.count {
                scheduled.scheduledDate = calendar.date(byAdding: .day, value: workoutDays[index], to: today)
            }
            scheduledWorkouts.append(scheduled)
        }

        return scheduledWorkouts
    }

    private func applyProgression(workouts: [Workout], weekIndex: Int) -> [Workout] {
        // Apply simple progression: every 2 weeks, increase reps or sets
        guard weekIndex > 1 else { return workouts }

        return workouts.map { workout in
            var modified = workout
            modified.exercises = workout.exercises.map { exercise in
                var modifiedEx = exercise
                if weekIndex % 2 == 0 {
                    // Add reps every 2 weeks
                    modifiedEx.reps = min(exercise.reps + 1, exercise.reps + 3)
                }
                return modifiedEx
            }
            return modified
        }
    }

    private func calculateDuration(exercises: [Exercise]) -> Int {
        var totalSeconds = 0
        for exercise in exercises {
            let setDuration = 45 // Average time per set in seconds
            let restTime = exercise.restSeconds
            totalSeconds += exercise.sets * (setDuration + restTime)
        }
        // Add 5 minutes for warmup
        return (totalSeconds / 60) + 5
    }

    private func getDifficulty(weekIndex: Int) -> Difficulty {
        switch weekIndex {
        case 1...2: return .beginner
        case 3...5: return .intermediate
        default: return .advanced
        }
    }

    // MARK: - Quick Generation (Local Fallback)

    func generateNextWeek(for profile: UserProfile, sessionLogs: [SessionLog] = []) -> WeekProgram {
        let nextWeek = profile.currentWeek
        return generateWeekProgram(profile: profile, weekIndex: nextWeek, sessionLogs: sessionLogs)
    }

    func regenerateCurrentWeek(for profile: UserProfile, sessionLogs: [SessionLog] = []) -> WeekProgram {
        return generateWeekProgram(profile: profile, weekIndex: profile.currentWeek, sessionLogs: sessionLogs)
    }

    // MARK: - AI Generation

    /// Generate workout program using AI (async)
    /// Falls back to local generation if AI fails
    /// - Parameters:
    ///   - startDate: Optional start date. If nil, calculates based on existing programs
    ///   - existingPrograms: Existing week programs to check for scheduling conflicts
    func generateWeekProgramWithAI(for profile: UserProfile, weekIndex: Int, sessionLogs: [SessionLog] = [], startDate: Date? = nil, existingPrograms: [WeekProgram] = []) async -> WeekProgram {
        // Calculate the appropriate start date
        let calculatedStartDate = calculateStartDate(startDate: startDate, existingPrograms: existingPrograms)

        // Try AI generation first
        if let aiProgram = await OpenAIService.shared.generateWeekProgram(
            profile: profile,
            weekIndex: weekIndex,
            sessionLogs: sessionLogs,
            startDate: calculatedStartDate
        ) {
            print("✅ AI workout generation successful, starting from \(calculatedStartDate)")
            return aiProgram
        }

        // Fallback to local generation
        print("⚠️ AI generation failed, falling back to local generation")
        return generateWeekProgram(profile: profile, weekIndex: weekIndex, sessionLogs: sessionLogs, startDate: calculatedStartDate)
    }

    func generateNextWeekWithAI(for profile: UserProfile, sessionLogs: [SessionLog] = [], existingPrograms: [WeekProgram] = []) async -> WeekProgram {
        let nextWeek = profile.currentWeek
        return await generateWeekProgramWithAI(for: profile, weekIndex: nextWeek, sessionLogs: sessionLogs, existingPrograms: existingPrograms)
    }

    func regenerateCurrentWeekWithAI(for profile: UserProfile, sessionLogs: [SessionLog] = [], existingPrograms: [WeekProgram] = []) async -> WeekProgram {
        return await generateWeekProgramWithAI(for: profile, weekIndex: profile.currentWeek, sessionLogs: sessionLogs, existingPrograms: existingPrograms)
    }

    // MARK: - Start Date Calculation

    /// Calculates the appropriate start date for a new week program
    /// If there are existing programs, starts the day after the last scheduled workout
    /// Otherwise, starts from today
    private func calculateStartDate(startDate: Date?, existingPrograms: [WeekProgram]) -> Date {
        // If a specific start date is provided, use it
        if let startDate = startDate {
            return startDate
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find the latest scheduled date across all existing programs
        var latestDate: Date? = nil

        for program in existingPrograms {
            for workout in program.workouts {
                if let scheduledDate = workout.scheduledDate {
                    if latestDate == nil || scheduledDate > latestDate! {
                        latestDate = scheduledDate
                    }
                }
            }
        }

        // If we have a latest date and it's today or in the future, start from the day after
        if let latest = latestDate {
            let latestDay = calendar.startOfDay(for: latest)
            if latestDay >= today {
                // Start from the day after the latest scheduled workout
                return calendar.date(byAdding: .day, value: 1, to: latestDay) ?? today
            }
        }

        // Default to today
        return today
    }
}
