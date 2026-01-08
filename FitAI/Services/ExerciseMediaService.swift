import Foundation

/// Service to fetch exercise media (images, videos) from ExerciseDB API via RapidAPI
/// API Documentation: https://rapidapi.com/justin-WFnsXH_t6/api/exercisedb
class ExerciseMediaService {
    static let shared = ExerciseMediaService()

    private let baseURL = "https://exercisedb.p.rapidapi.com"
    private let apiKey = Config.rapidAPIKey
    private let apiHost = "exercisedb.p.rapidapi.com"
    private var cache: [String: ExerciseMedia] = [:]

    // MARK: - Models

    struct ExerciseMedia {
        let name: String
        let bodyPart: String
        let target: String
        let equipment: String
        let instructions: [String]
        let secondaryMuscles: [String]
        let description: String?
        let difficulty: String?
        let category: String?
    }

    // MARK: - API Response Model

    private struct ExerciseDBResponse: Codable {
        let id: String
        let name: String
        let bodyPart: String
        let target: String
        let equipment: String
        let instructions: [String]?
        let secondaryMuscles: [String]?
        let description: String?
        let difficulty: String?
        let category: String?
    }

    // MARK: - Exercise Name Mapping

    /// Maps our exercise keys to ExerciseDB search terms
    private let exerciseSearchTerms: [String: String] = [
        // Chest - Dumbbells
        "ex_dumbbell_bench_press": "dumbbell bench press",
        "ex_dumbbell_flyes": "dumbbell fly",
        "ex_incline_dumbbell_press": "dumbbell incline bench press",
        "ex_dumbbell_pullover": "dumbbell pullover",

        // Chest - Bodyweight
        "ex_push_ups": "push-up",
        "ex_diamond_push_ups": "diamond push-up",
        "ex_wide_push_ups": "wide hand push-up",
        "ex_decline_push_ups": "decline push-up",
        "ex_archer_push_ups": "archer push up",

        // Back - Dumbbells
        "ex_dumbbell_rows": "dumbbell bent over row",
        "ex_single_arm_row": "dumbbell one arm row",
        "ex_renegade_rows": "dumbbell renegade row",
        "ex_dumbbell_deadlift": "dumbbell deadlift",

        // Back - Bodyweight
        "ex_superman": "superman",
        "ex_reverse_snow_angels": "reverse fly",

        // Shoulders - Dumbbells
        "ex_dumbbell_shoulder_press": "dumbbell shoulder press",
        "ex_lateral_raises": "dumbbell lateral raise",
        "ex_front_raises": "dumbbell front raise",
        "ex_rear_delt_flyes": "dumbbell rear lateral raise",
        "ex_dumbbell_shrugs": "dumbbell shrug",
        "ex_arnold_press": "dumbbell arnold press",

        // Shoulders - Bodyweight
        "ex_pike_push_ups": "pike push-up",
        "ex_handstand_hold": "handstand",

        // Biceps
        "ex_bicep_curls": "dumbbell bicep curl",
        "ex_hammer_curls": "dumbbell hammer curl",
        "ex_concentration_curls": "dumbbell concentration curl",
        "ex_incline_curls": "dumbbell incline curl",

        // Triceps - Dumbbells
        "ex_tricep_kickbacks": "dumbbell kickback",
        "ex_tricep_extensions": "dumbbell triceps extension",
        "ex_skull_crushers": "dumbbell lying triceps extension",

        // Triceps - Bodyweight
        "ex_close_grip_push_ups": "close-grip push-up",
        "ex_bench_dips": "bench dip",

        // Legs - Dumbbells
        "ex_goblet_squats": "dumbbell goblet squat",
        "ex_lunges": "dumbbell lunge",
        "ex_bulgarian_split_squats": "dumbbell single leg split squat",
        "ex_dumbbell_rdl": "dumbbell romanian deadlift",
        "ex_calf_raises": "dumbbell calf raise",
        "ex_step_ups": "dumbbell step-up",
        "ex_sumo_squats": "dumbbell sumo squat",

        // Legs - Bodyweight
        "ex_squats": "bodyweight squat",
        "ex_jump_squats": "jump squat",
        "ex_wall_sit": "wall sit",
        "ex_pistol_squats": "pistol squat",
        "ex_jumping_lunges": "split jump",

        // Glutes
        "ex_glute_bridges": "glute bridge",
        "ex_hip_thrusts": "barbell hip thrust",
        "ex_single_leg_glute_bridge": "single leg bridge",
        "ex_donkey_kicks": "donkey calf raise",

        // Core - Dumbbells
        "ex_russian_twists": "russian twist",
        "ex_weighted_crunches": "weighted crunch",

        // Core - Bodyweight
        "ex_plank": "plank",
        "ex_side_plank": "side plank",
        "ex_mountain_climbers": "mountain climber",
        "ex_leg_raises": "lying leg raise",
        "ex_crunches": "crunch",
        "ex_bicycle_crunches": "bicycle crunch",
        "ex_dead_bug": "dead bug",
        "ex_hollow_hold": "hollow hold",
        "ex_v_ups": "v-up",

        // Full Body
        "ex_burpees": "burpee",
        "ex_jumping_jacks": "jumping jack",
        "ex_high_knees": "high knee skips",
        "ex_star_jumps": "star jump",
        "ex_dumbbell_complex": "dumbbell clean"
    ]

    // MARK: - Fetch Methods

    /// Fetch exercise media by exercise key with translation support
    func fetchMedia(for exerciseKey: String, language: AppLanguage = .english) async -> ExerciseMedia? {
        // Create cache key including language
        let cacheKey = "\(exerciseKey)_\(language.rawValue)"

        // Check cache first
        if let cached = cache[cacheKey] {
            return cached
        }

        // Get search term
        guard let searchTerm = exerciseSearchTerms[exerciseKey] else {
            print("No search term found for: \(exerciseKey)")
            return nil
        }

        // Search ExerciseDB API
        guard var media = await searchExercise(term: searchTerm) else {
            return nil
        }

        // Translate if needed
        if language == .french {
            let translated = await OpenAIService.shared.translateExerciseContent(
                description: media.description,
                instructions: media.instructions,
                to: language
            )
            media = ExerciseMedia(
                name: media.name,
                bodyPart: media.bodyPart,
                target: media.target,
                equipment: media.equipment,
                instructions: translated.instructions,
                secondaryMuscles: media.secondaryMuscles,
                description: translated.description,
                difficulty: media.difficulty,
                category: media.category
            )
        }

        // Cache result
        cache[cacheKey] = media
        return media
    }

    /// Search for exercise on ExerciseDB
    private func searchExercise(term: String) async -> ExerciseMedia? {
        let encodedTerm = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
        let urlString = "\(baseURL)/exercises/name/\(encodedTerm)?limit=1"

        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.addValue(apiHost, forHTTPHeaderField: "x-rapidapi-host")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    print("API Error: HTTP \(httpResponse.statusCode)")
                    return nil
                }
            }

            // Debug: Print raw JSON
            if let jsonString = String(data: data, encoding: .utf8) {
                print("API Response for '\(term)': \(jsonString.prefix(500))...")
            }

            // Use flexible decoder with snake_case support
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let exercises = try decoder.decode([ExerciseDBResponse].self, from: data)

            // Find best match
            guard let exercise = exercises.first else {
                print("No exercise found for: \(term)")
                return nil
            }

            return ExerciseMedia(
                name: exercise.name.capitalized,
                bodyPart: exercise.bodyPart.capitalized,
                target: exercise.target.capitalized,
                equipment: exercise.equipment.capitalized,
                instructions: exercise.instructions ?? [],
                secondaryMuscles: exercise.secondaryMuscles ?? [],
                description: exercise.description,
                difficulty: exercise.difficulty?.capitalized,
                category: exercise.category?.capitalized
            )
        } catch {
            print("Error fetching exercise media: \(error)")
            return nil
        }
    }

    /// Clear cache
    func clearCache() {
        cache.removeAll()
    }
}
