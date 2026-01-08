import Foundation

@MainActor
class OpenAIService: ObservableObject {
    static let shared = OpenAIService()

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiKey = Config.openAIKey
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    // MARK: - Generate Meal Plan

    func generateMealPlan(profile: UserProfile, localization: LocalizationManager) async -> MealPlan? {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // Calculate daily caloric needs based on fitness goal
        let bmr = calculateBMR(profile: profile)
        let tdee = bmr * 1.55 // Moderate activity
        let targetCalories = Int(tdee + profile.fitnessGoal.caloricAdjustment)

        let proteinTarget = Int(profile.weightKg * profile.fitnessGoal.proteinMultiplier)
        let fatTarget = Int(Double(targetCalories) * 0.25 / 9) // 25% from fats
        let carbTarget = (targetCalories - (proteinTarget * 4) - (fatTarget * 9)) / 4

        let language = profile.language == .french ? "French" : "English"

        // Goal-specific context for AI
        let goalContext: String
        switch profile.fitnessGoal {
        case .weightLoss:
            goalContext = "Focus on LOW-CALORIE, HIGH-PROTEIN meals. Include lots of vegetables, lean proteins, and avoid high-calorie dense foods. Meals should be satisfying but with a caloric deficit."
        case .muscleGain:
            goalContext = "Focus on HIGH-CALORIE, HIGH-PROTEIN meals for muscle building. Include complex carbs, lean proteins, and healthy fats. Meals should support muscle growth with a caloric surplus."
        case .maintenance:
            goalContext = "Focus on BALANCED meals with moderate portions. Include a good mix of proteins, carbs, and healthy fats to maintain current weight and fitness."
        case .recomposition:
            goalContext = "Focus on VERY HIGH-PROTEIN, moderate calorie meals. Prioritize protein at every meal to build muscle while losing fat. Keep carbs moderate and timing around workouts."
        }

        // Dietary regime context
        let dietaryContext = buildDietaryContext(profile: profile)

        // Use current day of week and random seed for variety
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        let randomSeed = Int.random(in: 1...1000)

        let prompt = """
        Generate a UNIQUE and CREATIVE meal plan for one day. The user's goal is: \(profile.fitnessGoal.rawValue.replacingOccurrences(of: "_", with: " ").uppercased())

        \(goalContext)

        \(dietaryContext)

        The user needs approximately:
        - \(targetCalories) calories
        - \(proteinTarget)g protein
        - \(carbTarget)g carbs
        - \(fatTarget)g fats

        IMPORTANT: Use random seed \(randomSeed) and day \(dayOfWeek) to generate completely different meals each time.

        Respond ONLY with valid JSON in this exact format (no markdown, no explanation):
        {
            "breakfast": {
                "name": "Meal name",
                "description": "Brief description",
                "kcal": 600,
                "protein": 35,
                "carbs": 60,
                "fats": 20,
                "ingredients": ["200g ingredient 1", "100g ingredient 2"],
                "instructions": "Step-by-step cooking instructions"
            },
            "lunch": {
                "name": "Meal name",
                "description": "Brief description",
                "kcal": 800,
                "protein": 50,
                "carbs": 80,
                "fats": 25,
                "ingredients": ["ingredient 1", "ingredient 2"],
                "instructions": "Step-by-step cooking instructions"
            },
            "dinner": {
                "name": "Meal name",
                "description": "Brief description",
                "kcal": 700,
                "protein": 45,
                "carbs": 70,
                "fats": 22,
                "ingredients": ["ingredient 1", "ingredient 2"],
                "instructions": "Step-by-step cooking instructions"
            },
            "snacks": [
                {
                    "name": "Snack name",
                    "description": "Brief description",
                    "kcal": 300,
                    "protein": 20,
                    "carbs": 30,
                    "fats": 10,
                    "ingredients": ["ingredient 1", "ingredient 2"],
                    "instructions": "How to prepare (can be simple for snacks)"
                }
            ]
        }

        VARIETY REQUIREMENTS - Be creative and diverse:
        - Vary cuisines: Mediterranean, Asian, Mexican, American, Indian, Middle Eastern, etc.
        - Vary cooking methods: grilled, baked, stir-fried, slow-cooked, steamed, raw
        - Vary protein sources: chicken, beef, pork, fish (salmon, tuna, cod), shrimp, eggs, turkey, tofu, tempeh, greek yogurt, cottage cheese, legumes (lentils, chickpeas, black beans)
        - Vary carb sources: rice (white, brown, basmati), pasta, quinoa, sweet potatoes, regular potatoes, oats, bread, couscous, bulgur, noodles
        - Vary vegetables: broccoli, spinach, peppers, zucchini, asparagus, green beans, carrots, tomatoes, mushrooms, kale, bok choy, edamame
        - Include healthy fats: olive oil, avocado, nuts (almonds, walnuts, cashews), seeds, nut butters, tahini

        INSTRUCTIONS REQUIREMENTS:
        - Include ingredient quantities (grams or common measures)
        - Provide clear, numbered cooking steps
        - Include cooking times and temperatures when applicable
        - Keep instructions concise but complete (3-6 steps typically)

        All text must be in \(language).
        DO NOT repeat common meals like "chicken and rice" or "oatmeal with banana" - be creative!
        """

        do {
            let response = try await sendChatRequest(prompt: prompt)
            return parseMealPlanResponse(response)
        } catch {
            print("OpenAI Error: \(error)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Chat with Assistant

    func chat(message: String, context: String, language: AppLanguage) async -> String? {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        let lang = language == .french ? "French" : "English"
        let systemPrompt = """
        You are FitAI, a helpful fitness and nutrition assistant specialized in muscle building (bulking).
        You provide advice on workouts, nutrition, recovery, and motivation.
        Always respond in \(lang).
        Be concise but helpful. Use emojis sparingly.

        Context about the user:
        \(context)
        """

        do {
            return try await sendChatRequest(prompt: message, systemPrompt: systemPrompt)
        } catch {
            print("OpenAI Chat Error: \(error)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Private Methods

    private func sendChatRequest(prompt: String, systemPrompt: String? = nil) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }

        var messages: [[String: String]] = []

        if let system = systemPrompt {
            messages.append(["role": "system", "content": system])
        }
        messages.append(["role": "user", "content": prompt])

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 2000
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw OpenAIError.apiError(message)
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.parseError
        }

        // Log token usage if available
        if let usage = json["usage"] as? [String: Any],
           let promptTokens = usage["prompt_tokens"] as? Int,
           let completionTokens = usage["completion_tokens"] as? Int,
           let totalTokens = usage["total_tokens"] as? Int {
            print("🤖 OpenAI API - Tokens utilisés: \(totalTokens) (prompt: \(promptTokens), completion: \(completionTokens))")
        }

        return content
    }

    private func parseMealPlanResponse(_ response: String) -> MealPlan? {
        // Clean the response (remove markdown if present)
        var cleanedResponse = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedResponse.data(using: .utf8) else {
            print("Failed to convert response to data")
            return nil
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let json = json else {
                print("Failed to parse JSON")
                return nil
            }

            let breakfast = parseMeal(from: json["breakfast"] as? [String: Any])
            let lunch = parseMeal(from: json["lunch"] as? [String: Any])
            let dinner = parseMeal(from: json["dinner"] as? [String: Any])

            var snacks: [Meal] = []
            if let snacksArray = json["snacks"] as? [[String: Any]] {
                snacks = snacksArray.compactMap { parseMeal(from: $0) }
            }

            guard let b = breakfast, let l = lunch, let d = dinner else {
                print("Missing required meals")
                return nil
            }

            return MealPlan(
                date: Date(),
                breakfast: b,
                lunch: l,
                dinner: d,
                snacks: snacks
            )
        } catch {
            print("JSON parsing error: \(error)")
            return nil
        }
    }

    private func parseMeal(from dict: [String: Any]?) -> Meal? {
        guard let dict = dict,
              let name = dict["name"] as? String,
              let description = dict["description"] as? String,
              let kcal = dict["kcal"] as? Int,
              let protein = dict["protein"] as? Double ?? Double(dict["protein"] as? Int ?? 0) as Double?,
              let carbs = dict["carbs"] as? Double ?? Double(dict["carbs"] as? Int ?? 0) as Double?,
              let fats = dict["fats"] as? Double ?? Double(dict["fats"] as? Int ?? 0) as Double?,
              let ingredients = dict["ingredients"] as? [String] else {
            return nil
        }

        let instructions = dict["instructions"] as? String

        return Meal(
            nameKey: name,
            descriptionKey: description,
            kcal: kcal,
            proteinG: protein,
            carbsG: carbs,
            fatsG: fats,
            ingredients: ingredients,
            instructions: instructions
        )
    }

    private func calculateBMR(profile: UserProfile) -> Double {
        // Mifflin-St Jeor Equation
        if profile.sex == .male {
            return 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * Double(profile.age) + 5
        } else {
            return 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * Double(profile.age) - 161
        }
    }

    private func buildDietaryContext(profile: UserProfile) -> String {
        var context = ""

        // Dietary regime
        if profile.dietaryRegime != .standard {
            let regimeDescriptions: [DietaryRegime: String] = [
                .vegetarian: "VEGETARIAN diet - NO meat or fish, but eggs and dairy are allowed.",
                .vegan: "VEGAN diet - NO animal products whatsoever (no meat, fish, eggs, dairy, honey).",
                .pescatarian: "PESCATARIAN diet - NO meat, but fish and seafood are allowed."
            ]
            if let description = regimeDescriptions[profile.dietaryRegime] {
                context += "DIETARY REGIME: \(description)\n\n"
            }
        }

        // Allergies (CRITICAL)
        if !profile.foodAllergies.isEmpty {
            let allergyNames = profile.foodAllergies.map { allergy -> String in
                switch allergy {
                case .gluten: return "gluten (wheat, barley, rye)"
                case .lactose: return "lactose/dairy products"
                case .nuts: return "tree nuts (almonds, walnuts, cashews, etc.)"
                case .peanuts: return "peanuts"
                case .shellfish: return "shellfish (shrimp, crab, lobster)"
                case .eggs: return "eggs"
                case .soy: return "soy products"
                case .fish: return "fish"
                }
            }
            context += "⚠️ CRITICAL ALLERGIES - NEVER include these ingredients: \(allergyNames.joined(separator: ", ")). This is for health safety!\n\n"
        }

        // Food dislikes
        if !profile.foodDislikes.isEmpty {
            let dislikeNames = profile.foodDislikes.map { dislike -> String in
                switch dislike {
                case .redMeat: return "red meat (beef, lamb, pork)"
                case .pork: return "pork"
                case .chicken: return "chicken/poultry"
                case .fish: return "fish"
                case .seafood: return "seafood"
                case .eggs: return "eggs"
                case .dairy: return "dairy products"
                case .spicy: return "spicy food"
                case .mushrooms: return "mushrooms"
                case .onions: return "onions"
                }
            }
            context += "FOODS TO AVOID (user preference): \(dislikeNames.joined(separator: ", ")). Do not include these in any meal.\n\n"
        }

        return context
    }

    // MARK: - Weekly Recommendations

    func generateWeeklyRecommendations(summary: WeeklySummary, profile: UserProfile?, localization: LocalizationManager) async -> String? {
        guard let profile = profile else { return nil }

        let language = profile.language == .french ? "French" : "English"

        // Build context from summary
        var context = """
        Weekly fitness summary for a user doing \(profile.fitnessGoal.rawValue.replacingOccurrences(of: "_", with: " ")) with \(profile.equipment.rawValue) equipment:

        - Completed \(summary.sessionsCompleted) of \(summary.sessionsPlanned) planned sessions (\(Int(summary.completionRate * 100))% completion)
        - Total training time: \(summary.totalTrainingMinutes) minutes
        - Current streak: \(summary.currentStreak) consecutive days
        """

        if let rating = summary.averageRating {
            context += "\n- Average session rating: \(String(format: "%.1f", rating))/5"
        }

        if let change = summary.weightChange, let start = summary.startWeight, let end = summary.endWeight {
            context += "\n- Weight: \(String(format: "%.1f", start)) kg -> \(String(format: "%.1f", end)) kg (change: \(change >= 0 ? "+" : "")\(String(format: "%.1f", change)) kg)"
        }

        if !summary.bestExercises.isEmpty {
            let exercises = summary.bestExercises.map { "\($0.name): +\(Int($0.improvement))%" }.joined(separator: ", ")
            context += "\n- Best performing exercises: \(exercises)"
        }

        if let calories = summary.averageCalories {
            context += "\n- Average daily calories: \(calories) kcal"
        }

        if let protein = summary.averageProtein {
            context += "\n- Average daily protein: \(Int(protein))g"
        }

        if let water = summary.averageWaterGlasses {
            context += "\n- Average daily water intake: \(String(format: "%.1f", water)) glasses"
        }

        let prompt = """
        Based on the following weekly fitness summary, provide 3-4 concise, personalized recommendations for the next week.
        Be specific, actionable, and motivating. Focus on:
        1. Training improvements based on completion rate and performance
        2. Recovery if needed
        3. Nutrition adjustments if data available
        4. Motivation and streak maintenance

        \(context)

        User goal: \(profile.fitnessGoal.rawValue.replacingOccurrences(of: "_", with: " ").uppercased())

        Respond in \(language) with 3-4 short bullet points (use • as bullet). Keep each recommendation to 1-2 sentences max.
        Be encouraging but realistic. If completion rate is low, suggest ways to improve consistency.
        If weight change doesn't match goal, give gentle nutrition advice.
        """

        do {
            return try await sendChatRequest(prompt: prompt)
        } catch {
            print("AI Recommendations Error: \(error)")
            return nil
        }
    }

    // MARK: - Generate Workout Program

    func generateWeekProgram(profile: UserProfile, weekIndex: Int, sessionLogs: [SessionLog], startDate: Date? = nil) async -> WeekProgram? {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        let language = profile.language == .french ? "French" : "English"
        let equipment = profile.equipment == .dumbbells ? "dumbbells only" : "bodyweight only (no equipment)"

        // Build feedback from past sessions
        let feedbackContext = buildSessionFeedbackContext(sessionLogs: sessionLogs)

        // Goal-specific training context
        let goalContext: String
        switch profile.fitnessGoal {
        case .weightLoss:
            goalContext = "Focus on HIGH-INTENSITY, metabolic training. Include supersets, circuits, shorter rest periods (30-45s), higher reps (12-20), and compound movements to maximize calorie burn while preserving muscle."
        case .muscleGain:
            goalContext = "Focus on HYPERTROPHY training. Use moderate reps (8-12), controlled tempo (3-1-2), adequate rest (60-90s), progressive overload, and target each muscle group with 10-15 sets per week."
        case .maintenance:
            goalContext = "Focus on BALANCED training. Mix of strength and endurance, moderate volume, varied rep ranges (8-15), and full body coverage to maintain current fitness level."
        case .recomposition:
            goalContext = "Focus on STRENGTH with metabolic conditioning. Heavy compound lifts (6-10 reps), moderate rest (60-75s), include some high-intensity finishers. Build muscle while burning fat."
        }

        // Determine split type based on sessions per week
        let splitType: String
        if profile.sessionsPerWeek <= 3 {
            splitType = "Full Body split (each session targets all major muscle groups)"
        } else if profile.sessionsPerWeek <= 4 {
            splitType = "Upper/Lower split or Full Body"
        } else {
            splitType = "Push/Pull/Legs split (Push: chest, shoulders, triceps. Pull: back, biceps. Legs: quads, hamstrings, glutes, calves)"
        }

        let prompt = """
        Generate a personalized \(profile.sessionsPerWeek)-day workout program for week \(weekIndex).

        USER PROFILE:
        - Goal: \(profile.fitnessGoal.rawValue.replacingOccurrences(of: "_", with: " ").uppercased())
        - Equipment: \(equipment)
        - Sessions per week: \(profile.sessionsPerWeek)
        - Week number: \(weekIndex) (adjust difficulty progressively)

        TRAINING APPROACH:
        \(goalContext)

        SPLIT TYPE: \(splitType)

        \(feedbackContext)

        EXERCISE SELECTION RULES:
        - Use ONLY exercises possible with \(equipment)
        - Include compound movements first, then isolation
        - Vary exercises from week to week for muscle confusion
        - Each session should have 5-7 exercises
        - Include core work at least 2x per week

        \(profile.equipment == .dumbbells ? """
        DUMBBELL EXERCISES TO USE:
        Chest: dumbbell bench press, dumbbell flyes, incline press, floor press, squeeze press
        Back: dumbbell rows, single-arm rows, renegade rows, pullovers, reverse flyes
        Shoulders: shoulder press, lateral raises, front raises, arnold press, rear delt flyes
        Biceps: bicep curls, hammer curls, concentration curls, incline curls
        Triceps: tricep extensions, kickbacks, skull crushers, close-grip press
        Legs: goblet squats, lunges, Bulgarian split squats, Romanian deadlifts, calf raises, step-ups, sumo squats
        Glutes: hip thrusts, glute bridges, single-leg deadlifts
        Core: russian twists, weighted crunches, wood chops, farmer walks
        """ : """
        BODYWEIGHT EXERCISES TO USE:
        Chest: push-ups, diamond push-ups, wide push-ups, decline push-ups, archer push-ups
        Back: superman, reverse snow angels, prone Y raises, inverted rows (if bar available)
        Shoulders: pike push-ups, handstand holds, arm circles
        Arms: close-grip push-ups, bench dips, tricep push-ups
        Legs: squats, jump squats, lunges, Bulgarian split squats, pistol squats, wall sits, calf raises
        Glutes: glute bridges, single-leg bridges, donkey kicks, fire hydrants
        Core: planks, side planks, mountain climbers, leg raises, bicycle crunches, dead bugs, hollow holds, V-ups
        Full Body: burpees, jumping jacks, high knees, bear crawls
        """)

        Respond ONLY with valid JSON (no markdown, no explanation):
        {
            "workouts": [
                {
                    "title": "Day 1 - [Focus Area]",
                    "dayIndex": 1,
                    "difficulty": "beginner|intermediate|advanced",
                    "isChallenge": false,
                    "exercises": [
                        {
                            "name": "Exercise Name",
                            "muscleGroups": ["chest", "triceps"],
                            "sets": 4,
                            "reps": 10,
                            "tempo": "3-1-2",
                            "restSeconds": 60,
                            "notes": "Optional form tips"
                        }
                    ]
                }
            ]
        }

        REQUIREMENTS:
        - Generate exactly \(profile.sessionsPerWeek) workouts
        - Last workout of the week should be a "Challenge" session (isChallenge: true) with higher intensity
        - muscleGroups must use: chest, back, shoulders, biceps, triceps, legs, core, glutes, full_body
        - difficulty based on week: weeks 1-2 = beginner, 3-5 = intermediate, 6+ = advanced
        - All text (titles, exercise names, notes) must be in \(language)
        - Tempo format: "eccentric-pause-concentric" in seconds (e.g., "3-1-2")
        """

        do {
            let response = try await sendChatRequest(prompt: prompt, systemPrompt: nil)
            return parseWorkoutProgramResponse(response, weekIndex: weekIndex, profile: profile, startDate: startDate)
        } catch {
            print("OpenAI Workout Generation Error: \(error)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func buildSessionFeedbackContext(sessionLogs: [SessionLog]) -> String {
        guard !sessionLogs.isEmpty else {
            return "No previous session data available. Generate a program suitable for beginners starting their fitness journey."
        }

        // Get last 10 sessions for analysis
        let recentSessions = Array(sessionLogs.suffix(10))

        // Calculate average difficulty feedback
        let difficultyFeedback = recentSessions.compactMap { $0.difficulty }
        var difficultyContext = ""
        if !difficultyFeedback.isEmpty {
            let tooEasyCount = difficultyFeedback.filter { $0 == .tooEasy }.count
            let tooHardCount = difficultyFeedback.filter { $0 == .tooHard }.count
            let justRightCount = difficultyFeedback.filter { $0 == .justRight }.count

            if tooEasyCount > justRightCount && tooEasyCount > tooHardCount {
                difficultyContext = "User feedback: Sessions have been TOO EASY. INCREASE intensity: more sets, higher reps, shorter rest, or more challenging exercise variations."
            } else if tooHardCount > justRightCount && tooHardCount > tooEasyCount {
                difficultyContext = "User feedback: Sessions have been TOO HARD. DECREASE intensity: fewer sets, lower reps, longer rest, or easier exercise variations."
            } else {
                difficultyContext = "User feedback: Difficulty level is appropriate. Maintain similar intensity with slight progression."
            }
        }

        // Calculate average rating
        let ratings = recentSessions.compactMap { $0.rating }
        var ratingContext = ""
        if !ratings.isEmpty {
            let avgRating = Double(ratings.reduce(0, +)) / Double(ratings.count)
            if avgRating < 3.0 {
                ratingContext = "User enjoyment is LOW (avg \(String(format: "%.1f", avgRating))/5). Add more variety, fun exercises, and consider reducing volume."
            } else if avgRating >= 4.0 {
                ratingContext = "User enjoyment is HIGH (avg \(String(format: "%.1f", avgRating))/5). User responds well to current training style."
            }
        }

        // Find exercises with good/bad completion rates
        var exercisePerformance: [String: (completed: Int, total: Int)] = [:]
        for session in recentSessions {
            for record in session.exerciseRecords {
                let name = record.exerciseNameKey
                let completed = record.setsCompleted.filter { $0.isCompleted }.count
                let total = record.setsCompleted.count

                if let existing = exercisePerformance[name] {
                    exercisePerformance[name] = (existing.completed + completed, existing.total + total)
                } else {
                    exercisePerformance[name] = (completed, total)
                }
            }
        }

        let strugglingExercises = exercisePerformance.filter { Double($0.value.completed) / Double(max($0.value.total, 1)) < 0.7 }.map { $0.key }
        var exerciseContext = ""
        if !strugglingExercises.isEmpty {
            exerciseContext = "User struggles with these exercises (low completion): \(strugglingExercises.prefix(3).joined(separator: ", ")). Consider easier alternatives or reduce volume for similar movements."
        }

        return """
        PERFORMANCE FEEDBACK FROM RECENT SESSIONS:
        \(difficultyContext)
        \(ratingContext)
        \(exerciseContext)

        Use this feedback to calibrate the program difficulty and exercise selection.
        """
    }

    private func parseWorkoutProgramResponse(_ response: String, weekIndex: Int, profile: UserProfile, startDate: Date? = nil) -> WeekProgram? {
        let cleanedResponse = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedResponse.data(using: .utf8) else {
            print("Failed to convert workout response to data")
            return nil
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let workoutsArray = json["workouts"] as? [[String: Any]] else {
                print("Failed to parse workouts JSON")
                return nil
            }

            var workouts: [Workout] = []
            let calendar = Calendar.current
            // Use provided startDate or default to today
            let programStartDate = calendar.startOfDay(for: startDate ?? Date())
            
            // Calculate workout days distribution across a full 7-day week
            let daysInWeek = 7
            let sessionsPerWeek = profile.sessionsPerWeek
            let workoutsToSchedule = min(workoutsArray.count, sessionsPerWeek)
            
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
                    let spacing = Double(daysInWeek) / Double(workoutsToSchedule)
                    
                    for i in 0..<workoutsToSchedule {
                        let day = Int(round(Double(i) * spacing))
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

            for (index, workoutDict) in workoutsArray.prefix(workoutsToSchedule).enumerated() {
                guard let title = workoutDict["title"] as? String,
                      let dayIndex = workoutDict["dayIndex"] as? Int,
                      let difficultyStr = workoutDict["difficulty"] as? String,
                      let exercisesArray = workoutDict["exercises"] as? [[String: Any]] else {
                    continue
                }

                let isChallenge = workoutDict["isChallenge"] as? Bool ?? false
                let difficulty = Difficulty(rawValue: difficultyStr) ?? .intermediate

                var exercises: [Exercise] = []
                for exerciseDict in exercisesArray {
                    guard let name = exerciseDict["name"] as? String,
                          let muscleGroupsRaw = exerciseDict["muscleGroups"] as? [String],
                          let sets = exerciseDict["sets"] as? Int,
                          let reps = exerciseDict["reps"] as? Int else {
                        continue
                    }

                    let muscleGroups = muscleGroupsRaw.compactMap { MuscleGroup(rawValue: $0) }
                    let tempo = exerciseDict["tempo"] as? String
                    let restSeconds = exerciseDict["restSeconds"] as? Int ?? 60
                    let notes = exerciseDict["notes"] as? String

                    let exercise = Exercise(
                        nameKey: name,
                        muscleGroups: muscleGroups.isEmpty ? [.fullBody] : muscleGroups,
                        equipment: profile.equipment,
                        sets: sets,
                        reps: reps,
                        tempo: tempo,
                        notesKey: notes,
                        restSeconds: restSeconds
                    )
                    exercises.append(exercise)
                }

                // Calculate duration
                let durationMinutes = calculateDuration(exercises: exercises)

                // Schedule the workout using the calculated distribution
                let scheduledDate: Date?
                if index < workoutDays.count {
                    scheduledDate = calendar.date(byAdding: .day, value: workoutDays[index], to: programStartDate)
                } else {
                    scheduledDate = nil
                }

                let workout = Workout(
                    titleKey: title,
                    weekIndex: weekIndex,
                    dayIndex: dayIndex,
                    exercises: exercises,
                    durationMinutes: durationMinutes,
                    difficulty: difficulty,
                    scheduledDate: scheduledDate,
                    isCompleted: false,
                    isChallenge: isChallenge
                )
                workouts.append(workout)
            }

            guard !workouts.isEmpty else {
                print("No workouts parsed from response")
                return nil
            }

            return WeekProgram(weekIndex: weekIndex, workouts: workouts)

        } catch {
            print("JSON parsing error for workouts: \(error)")
            return nil
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

    // MARK: - Translation

    /// Translate exercise content to the specified language
    func translateExerciseContent(description: String?, instructions: [String], to language: AppLanguage) async -> (description: String?, instructions: [String]) {
        // Skip translation if already in English (API returns English)
        guard language == .french else {
            return (description, instructions)
        }

        // Skip if nothing to translate
        guard description != nil || !instructions.isEmpty else {
            return (description, instructions)
        }

        do {
            let systemPrompt = """
                You are a professional translator specializing in fitness and exercise terminology.
                Translate the following exercise content from English to French.
                Keep the translations natural, accurate, and use proper French fitness terminology.
                Respond ONLY with valid JSON, no markdown or explanation.
                """

            let userPrompt = """
                Translate this exercise content to French:
                {
                    "description": "\(description ?? "")",
                    "instructions": \(instructionsToJSON(instructions))
                }

                Respond with:
                {
                    "description": "translated description in French",
                    "instructions": ["instruction 1 in French", "instruction 2 in French", ...]
                }
                """

            let content = try await sendChatRequest(prompt: userPrompt, systemPrompt: systemPrompt)

            return parseTranslationResponse(content, originalDescription: description, originalInstructions: instructions)
        } catch {
            print("Translation error: \(error)")
            return (description, instructions)
        }
    }

    private func instructionsToJSON(_ instructions: [String]) -> String {
        let escaped = instructions.map { instruction in
            instruction.replacingOccurrences(of: "\"", with: "\\\"")
        }
        return "[" + escaped.map { "\"\($0)\"" }.joined(separator: ", ") + "]"
    }

    private func parseTranslationResponse(_ response: String, originalDescription: String?, originalInstructions: [String]) -> (description: String?, instructions: [String]) {
        let cleanedResponse = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedResponse.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (originalDescription, originalInstructions)
        }

        let translatedDescription = json["description"] as? String
        let translatedInstructions = json["instructions"] as? [String] ?? originalInstructions

        return (
            translatedDescription?.isEmpty == true ? originalDescription : translatedDescription,
            translatedInstructions
        )
    }
}

// MARK: - Errors

enum OpenAIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .apiError(let message):
            return message
        case .parseError:
            return "Failed to parse response"
        }
    }
}
