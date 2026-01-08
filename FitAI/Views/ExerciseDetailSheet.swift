import SwiftUI

struct ExerciseDetailSheet: View {
    let exercise: Exercise
    @EnvironmentObject var localization: LocalizationManager
    @StateObject private var themeManager = ThemeManager.shared

    @State private var media: ExerciseMediaService.ExerciseMedia?
    @State private var isLoading = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    // Header with exercise icon
                    headerSection

                    // Exercise info from API
                    if let media = media {
                        apiInfoSection(media: media)

                        // Description from API
                        if let description = media.description {
                            descriptionSection(description: description)
                        }
                    }

                    // Exercise info
                    infoSection

                    // Instructions from API
                    if let media = media, !media.instructions.isEmpty {
                        instructionsSection(instructions: media.instructions)
                    }

                    // Tips section
                    tipsSection
                }
                .padding(AppTheme.spacingM)
            }
            .background(AppTheme.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(localization[exercise.nameKey])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localization["close"]) {
                        dismiss()
                    }
                }
            }
            .task {
                await loadMedia()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: AppTheme.spacingM) {
            if isLoading {
                // Loading state
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.backgroundSecondary)
                    .frame(height: 150)
                    .overlay(
                        VStack(spacing: AppTheme.spacingS) {
                            ProgressView()
                            Text(localization["loading"])
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    )
            } else {
                // Exercise icon header
                ZStack {
                    Circle()
                        .fill(themeManager.primaryColor.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: iconForExercise)
                        .font(.system(size: 50))
                        .foregroundColor(themeManager.primaryColor)
                }
                .padding(.top, AppTheme.spacingM)

                // Difficulty badge from API
                if let media = media, let difficulty = media.difficulty {
                    HStack(spacing: 6) {
                        Image(systemName: difficultyIcon(for: difficulty))
                            .foregroundColor(difficultyColor(for: difficulty))
                        Text(difficulty)
                            .font(.subheadline.bold())
                            .foregroundColor(difficultyColor(for: difficulty))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(difficultyColor(for: difficulty).opacity(0.15))
                    .cornerRadius(20)
                }
            }
        }
    }

    private var iconForExercise: String {
        // Return appropriate icon based on muscle groups
        if exercise.muscleGroups.contains(.chest) {
            return "figure.strengthtraining.traditional"
        } else if exercise.muscleGroups.contains(.back) {
            return "figure.climbing"
        } else if exercise.muscleGroups.contains(.legs) {
            return "figure.run"
        } else if exercise.muscleGroups.contains(.shoulders) {
            return "figure.arms.open"
        } else if exercise.muscleGroups.contains(.core) {
            return "figure.core.training"
        } else if exercise.muscleGroups.contains(.biceps) || exercise.muscleGroups.contains(.triceps) {
            return "dumbbell.fill"
        } else {
            return "figure.strengthtraining.traditional"
        }
    }

    private func difficultyIcon(for difficulty: String) -> String {
        switch difficulty.lowercased() {
        case "beginner": return "1.circle.fill"
        case "intermediate": return "2.circle.fill"
        case "advanced": return "3.circle.fill"
        default: return "circle.fill"
        }
    }

    private func difficultyColor(for difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "beginner": return .green
        case "intermediate": return .orange
        case "advanced": return .red
        default: return .gray
        }
    }

    // MARK: - API Info Section

    private func apiInfoSection(media: ExerciseMediaService.ExerciseMedia) -> some View {
        VStack(spacing: AppTheme.spacingS) {
            // Target muscle and body part
            HStack(spacing: AppTheme.spacingM) {
                // Target muscle
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .foregroundColor(.red)
                    Text(media.target)
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(20)

                // Body part
                HStack(spacing: 6) {
                    Image(systemName: "figure.stand")
                        .foregroundColor(.blue)
                    Text(media.bodyPart)
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)

                Spacer()
            }

            // Secondary muscles if available
            if !media.secondaryMuscles.isEmpty {
                HStack {
                    Image(systemName: "circle.grid.2x2")
                        .foregroundColor(AppTheme.textSecondary)
                    Text(localization["exercise_secondary_muscles"])
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(media.secondaryMuscles, id: \.self) { muscle in
                                Text(muscle.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.backgroundSecondary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(12)
    }

    // MARK: - Description Section

    private func descriptionSection(description: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(themeManager.primaryColor)
                Text(localization["exercise_description"])
                    .font(.headline)
            }

            Text(description)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(12)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: AppTheme.spacingM) {
            // Sets x Reps
            HStack(spacing: AppTheme.spacingL) {
                InfoBadge(
                    icon: "number.circle.fill",
                    title: localization["workout_sets"],
                    value: "\(exercise.sets)",
                    color: themeManager.primaryColor
                )

                InfoBadge(
                    icon: "repeat.circle.fill",
                    title: localization["workout_reps"],
                    value: "\(exercise.reps)",
                    color: .orange
                )

                InfoBadge(
                    icon: "timer",
                    title: localization["workout_rest"],
                    value: "\(exercise.restSeconds)s",
                    color: .blue
                )
            }

            // Tempo if available
            if let tempo = exercise.tempo {
                HStack {
                    Image(systemName: "metronome.fill")
                        .foregroundColor(.purple)
                    Text(localization["workout_tempo"])
                        .font(.subheadline)
                    Spacer()
                    Text(tempo)
                        .font(.headline)
                        .foregroundColor(.purple)
                }
                .padding()
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(12)
            }

            // Muscle groups from our data
            HStack {
                Image(systemName: "figure.arms.open")
                    .foregroundColor(themeManager.primaryColor)
                Text(localization["exercise_muscles"])
                    .font(.subheadline)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(exercise.muscleGroups, id: \.self) { muscle in
                        Text(localization[muscle.localizedKey])
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeManager.primaryColor.opacity(0.2))
                            .foregroundColor(themeManager.primaryColor)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(12)
        }
    }

    // MARK: - Instructions Section

    private func instructionsSection(instructions: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            HStack {
                Image(systemName: "list.number")
                    .foregroundColor(themeManager.primaryColor)
                Text(localization["exercise_instructions"])
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: AppTheme.spacingS) {
                        Text("\(index + 1).")
                            .font(.subheadline.bold())
                            .foregroundColor(themeManager.primaryColor)
                            .frame(width: 24)

                        Text(instruction)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
            .padding()
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(12)
        }
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text(localization["exercise_tips"])
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                TipRow(icon: "checkmark.circle.fill", text: localization["exercise_tip_form"], color: .green)
                TipRow(icon: "wind", text: localization["exercise_tip_breathing"], color: .blue)
                TipRow(icon: "arrow.up.arrow.down", text: localization["exercise_tip_control"], color: .orange)
            }
            .padding()
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(12)
        }
    }

    // MARK: - Load Media

    private func loadMedia() async {
        isLoading = true
        media = await ExerciseMediaService.shared.fetchMedia(
            for: exercise.nameKey,
            language: localization.currentLanguage
        )
        isLoading = false
    }
}

// MARK: - Supporting Views

struct InfoBadge: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: AppTheme.spacingXS) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .foregroundColor(color)
            }

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.spacingS)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(12)
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: AppTheme.spacingS) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

#Preview {
    ExerciseDetailSheet(
        exercise: Exercise(
            nameKey: "ex_push_ups",
            muscleGroups: [.chest, .triceps],
            equipment: .none,
            sets: 4,
            reps: 15,
            tempo: "2-1-2",
            restSeconds: 60
        )
    )
    .environmentObject(LocalizationManager.shared)
}
