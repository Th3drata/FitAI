import Foundation

// MARK: - Extensions

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// MARK: - User Profile

enum Sex: String, Codable, CaseIterable {
    case male = "male"
    case female = "female"
    case other = "other"

    var localizedKey: String {
        switch self {
        case .male: return "sex_male"
        case .female: return "sex_female"
        case .other: return "sex_other"
        }
    }
}

enum Equipment: String, Codable, CaseIterable {
    case dumbbells = "dumbbells"
    case none = "none"

    var localizedKey: String {
        switch self {
        case .dumbbells: return "equipment_dumbbells"
        case .none: return "equipment_none"
        }
    }
}

enum AppLanguage: String, Codable, CaseIterable {
    case french = "fr"
    case english = "en"

    var displayName: String {
        switch self {
        case .french: return "Français"
        case .english: return "English"
        }
    }
}

enum FitnessGoal: String, Codable, CaseIterable {
    case weightLoss = "weight_loss"
    case muscleGain = "muscle_gain"
    case maintenance = "maintenance"
    case recomposition = "recomposition"

    var localizedKey: String {
        return "goal_\(rawValue)"
    }

    var icon: String {
        switch self {
        case .weightLoss: return "flame.fill"
        case .muscleGain: return "figure.strengthtraining.traditional"
        case .maintenance: return "arrow.left.arrow.right"
        case .recomposition: return "arrow.triangle.2.circlepath"
        }
    }

    // Caloric adjustment factor
    var caloricAdjustment: Double {
        switch self {
        case .weightLoss: return -300 // Deficit
        case .muscleGain: return 300 // Surplus
        case .maintenance: return 0
        case .recomposition: return 0 // Slight deficit with high protein
        }
    }

    // Protein multiplier (g per kg of body weight)
    var proteinMultiplier: Double {
        switch self {
        case .weightLoss: return 2.2 // High protein to preserve muscle
        case .muscleGain: return 2.0
        case .maintenance: return 1.8
        case .recomposition: return 2.4 // Very high protein
        }
    }
}

// MARK: - Dietary Preferences

enum DietaryRegime: String, Codable, CaseIterable {
    case standard = "standard"
    case vegetarian = "vegetarian"
    case vegan = "vegan"
    case pescatarian = "pescatarian"

    var localizedKey: String {
        return "diet_\(rawValue)"
    }

    var icon: String {
        switch self {
        case .standard: return "fork.knife"
        case .vegetarian: return "leaf.fill"
        case .vegan: return "leaf.circle.fill"
        case .pescatarian: return "fish.fill"
        }
    }
}

enum FoodAllergy: String, Codable, CaseIterable {
    case gluten = "gluten"
    case lactose = "lactose"
    case nuts = "nuts"
    case peanuts = "peanuts"
    case shellfish = "shellfish"
    case eggs = "eggs"
    case soy = "soy"
    case fish = "fish"

    var localizedKey: String {
        return "allergy_\(rawValue)"
    }

    var icon: String {
        switch self {
        case .gluten: return "wheat"
        case .lactose: return "drop.fill"
        case .nuts: return "leaf.fill"
        case .peanuts: return "leaf.fill"
        case .shellfish: return "fish.fill"
        case .eggs: return "oval.fill"
        case .soy: return "leaf.fill"
        case .fish: return "fish.fill"
        }
    }
}

enum FoodDislike: String, Codable, CaseIterable {
    case redMeat = "red_meat"
    case pork = "pork"
    case chicken = "chicken"
    case fish = "fish"
    case seafood = "seafood"
    case eggs = "eggs"
    case dairy = "dairy"
    case spicy = "spicy"
    case mushrooms = "mushrooms"
    case onions = "onions"

    var localizedKey: String {
        return "dislike_\(rawValue)"
    }
}

struct UserProfile: Codable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var age: Int = 25
    var weightKg: Double = 70.0
    var heightCm: Double = 175.0
    var sex: Sex = .male
    var fitnessGoal: FitnessGoal = .muscleGain
    var equipment: Equipment = .dumbbells
    var sessionsPerWeek: Int = 4
    var language: AppLanguage = .french
    var hasAcceptedDisclaimer: Bool = false
    var notificationsEnabled: Bool = true
    var reminderMinutesBefore: Int = 30
    var preferredWorkoutHour: Int = 18 // Default 18:00 (6 PM)
    var preferredWorkoutMinute: Int = 0
    var preferredWorkoutDays: Set<Int> = [] // Weekdays: 1=Sunday, 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday, 7=Saturday
    var createdAt: Date = Date()
    var currentWeek: Int = 1

    // Dietary preferences
    var dietaryRegime: DietaryRegime = .standard
    var foodAllergies: [FoodAllergy] = []
    var foodDislikes: [FoodDislike] = []

    // Custom decoder to handle missing fields from old data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 25
        weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg) ?? 70.0
        heightCm = try container.decodeIfPresent(Double.self, forKey: .heightCm) ?? 175.0
        sex = try container.decodeIfPresent(Sex.self, forKey: .sex) ?? .male
        fitnessGoal = try container.decodeIfPresent(FitnessGoal.self, forKey: .fitnessGoal) ?? .muscleGain
        equipment = try container.decodeIfPresent(Equipment.self, forKey: .equipment) ?? .dumbbells
        sessionsPerWeek = try container.decodeIfPresent(Int.self, forKey: .sessionsPerWeek) ?? 4
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .french
        hasAcceptedDisclaimer = try container.decodeIfPresent(Bool.self, forKey: .hasAcceptedDisclaimer) ?? false
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        reminderMinutesBefore = try container.decodeIfPresent(Int.self, forKey: .reminderMinutesBefore) ?? 30
        preferredWorkoutHour = try container.decodeIfPresent(Int.self, forKey: .preferredWorkoutHour) ?? 18
        preferredWorkoutMinute = try container.decodeIfPresent(Int.self, forKey: .preferredWorkoutMinute) ?? 0
        preferredWorkoutDays = try container.decodeIfPresent(Set<Int>.self, forKey: .preferredWorkoutDays) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        currentWeek = try container.decodeIfPresent(Int.self, forKey: .currentWeek) ?? 1
        dietaryRegime = try container.decodeIfPresent(DietaryRegime.self, forKey: .dietaryRegime) ?? .standard
        foodAllergies = try container.decodeIfPresent([FoodAllergy].self, forKey: .foodAllergies) ?? []
        foodDislikes = try container.decodeIfPresent([FoodDislike].self, forKey: .foodDislikes) ?? []
    }

    init() {}
}

// MARK: - Workout & Exercise

enum MuscleGroup: String, Codable, CaseIterable {
    case chest = "chest"
    case back = "back"
    case shoulders = "shoulders"
    case biceps = "biceps"
    case triceps = "triceps"
    case legs = "legs"
    case core = "core"
    case glutes = "glutes"
    case fullBody = "full_body"

    var localizedKey: String {
        return "muscle_\(rawValue)"
    }
}

enum Difficulty: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"

    var localizedKey: String {
        return "difficulty_\(rawValue)"
    }
}

struct Exercise: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var nameKey: String
    var muscleGroups: [MuscleGroup]
    var equipment: Equipment
    var sets: Int
    var reps: Int
    var tempo: String?
    var notesKey: String?
    var restSeconds: Int = 90

    var localizedName: String {
        return nameKey
    }
}

struct Workout: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var titleKey: String
    var weekIndex: Int
    var dayIndex: Int
    var exercises: [Exercise]
    var durationMinutes: Int
    var difficulty: Difficulty
    var scheduledDate: Date?
    var isCompleted: Bool = false
    var isChallenge: Bool = false

    var localizedTitle: String {
        return titleKey
    }

    // Custom decoder to handle missing isChallenge field from old data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        titleKey = try container.decode(String.self, forKey: .titleKey)
        weekIndex = try container.decode(Int.self, forKey: .weekIndex)
        dayIndex = try container.decode(Int.self, forKey: .dayIndex)
        exercises = try container.decode([Exercise].self, forKey: .exercises)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        scheduledDate = try container.decodeIfPresent(Date.self, forKey: .scheduledDate)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        isChallenge = try container.decodeIfPresent(Bool.self, forKey: .isChallenge) ?? false
    }

    init(titleKey: String, weekIndex: Int, dayIndex: Int, exercises: [Exercise], durationMinutes: Int, difficulty: Difficulty, scheduledDate: Date? = nil, isCompleted: Bool = false, isChallenge: Bool = false) {
        self.id = UUID()
        self.titleKey = titleKey
        self.weekIndex = weekIndex
        self.dayIndex = dayIndex
        self.exercises = exercises
        self.durationMinutes = durationMinutes
        self.difficulty = difficulty
        self.scheduledDate = scheduledDate
        self.isCompleted = isCompleted
        self.isChallenge = isChallenge
    }
}

struct WeekProgram: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var weekIndex: Int
    var workouts: [Workout]
    var generatedAt: Date = Date()
}

// MARK: - Session Logging

struct ExerciseRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var exerciseId: UUID
    var exerciseNameKey: String
    var setsCompleted: [SetRecord]
}

struct SetRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var setNumber: Int
    var reps: Int
    var weightKg: Double
    var isCompleted: Bool = false
}

enum SessionDifficulty: String, Codable, CaseIterable {
    case tooEasy = "too_easy"
    case justRight = "just_right"
    case tooHard = "too_hard"

    var localizedKey: String {
        return "difficulty_\(rawValue)"
    }

    var progressionMultiplier: Double {
        switch self {
        case .tooEasy: return 1.1 // Increase weight by 10%
        case .justRight: return 1.025 // Slight increase 2.5%
        case .tooHard: return 0.95 // Decrease by 5%
        }
    }
}

struct SessionLog: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var workoutId: UUID
    var workoutTitleKey: String
    var notes: String = ""
    var exerciseRecords: [ExerciseRecord]
    var durationMinutes: Int?
    var rating: Int? // 1-5 stars
    var difficulty: SessionDifficulty? // User feedback on session difficulty

    // Custom decoder to handle missing difficulty field from old data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decode(Date.self, forKey: .date)
        workoutId = try container.decode(UUID.self, forKey: .workoutId)
        workoutTitleKey = try container.decode(String.self, forKey: .workoutTitleKey)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        exerciseRecords = try container.decodeIfPresent([ExerciseRecord].self, forKey: .exerciseRecords) ?? []
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        rating = try container.decodeIfPresent(Int.self, forKey: .rating)
        difficulty = try container.decodeIfPresent(SessionDifficulty.self, forKey: .difficulty)
    }

    init(date: Date, workoutId: UUID, workoutTitleKey: String, notes: String = "", exerciseRecords: [ExerciseRecord], durationMinutes: Int? = nil, rating: Int? = nil, difficulty: SessionDifficulty? = nil) {
        self.id = UUID()
        self.date = date
        self.workoutId = workoutId
        self.workoutTitleKey = workoutTitleKey
        self.notes = notes
        self.exerciseRecords = exerciseRecords
        self.durationMinutes = durationMinutes
        self.rating = rating
        self.difficulty = difficulty
    }
}

// MARK: - Weight Tracking

struct WeightEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var weightKg: Double
    var notes: String = ""
}

// MARK: - Water Tracking

struct WaterIntake: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var glasses: Int = 0 // Number of glasses (250ml each)
    var targetGlasses: Int = 8 // Default target: 8 glasses = 2L

    var totalMl: Int {
        glasses * 250
    }

    var targetMl: Int {
        targetGlasses * 250
    }

    var progress: Double {
        guard targetGlasses > 0 else { return 0 }
        return min(Double(glasses) / Double(targetGlasses), 1.0)
    }
}

// MARK: - Meal Planning

struct Meal: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var nameKey: String
    var descriptionKey: String
    var kcal: Int
    var proteinG: Double
    var carbsG: Double
    var fatsG: Double
    var ingredients: [String]
    var instructions: String?

    var localizedName: String {
        return nameKey
    }

    // Custom decoder to handle missing instructions field from old data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        nameKey = try container.decode(String.self, forKey: .nameKey)
        descriptionKey = try container.decode(String.self, forKey: .descriptionKey)
        kcal = try container.decode(Int.self, forKey: .kcal)
        proteinG = try container.decode(Double.self, forKey: .proteinG)
        carbsG = try container.decode(Double.self, forKey: .carbsG)
        fatsG = try container.decode(Double.self, forKey: .fatsG)
        ingredients = try container.decode([String].self, forKey: .ingredients)
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions)
    }

    init(nameKey: String, descriptionKey: String, kcal: Int, proteinG: Double, carbsG: Double, fatsG: Double, ingredients: [String], instructions: String? = nil) {
        self.nameKey = nameKey
        self.descriptionKey = descriptionKey
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatsG = fatsG
        self.ingredients = ingredients
        self.instructions = instructions
    }
}

struct MealPlan: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var breakfast: Meal
    var lunch: Meal
    var dinner: Meal
    var snacks: [Meal] = []

    var totalKcal: Int {
        breakfast.kcal + lunch.kcal + dinner.kcal + snacks.reduce(0) { $0 + $1.kcal }
    }

    var totalProtein: Double {
        breakfast.proteinG + lunch.proteinG + dinner.proteinG + snacks.reduce(0) { $0 + $1.proteinG }
    }

    var totalCarbs: Double {
        breakfast.carbsG + lunch.carbsG + dinner.carbsG + snacks.reduce(0) { $0 + $1.carbsG }
    }

    var totalFats: Double {
        breakfast.fatsG + lunch.fatsG + dinner.fatsG + snacks.reduce(0) { $0 + $1.fatsG }
    }
}

// MARK: - Chat / Assistant

struct ChatMessage: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var content: String
    var isFromUser: Bool
    var timestamp: Date = Date()
}

// MARK: - Exercise Weight History

struct ExerciseWeightHistory: Codable, Equatable {
    var exerciseNameKey: String
    var lastWeightKg: Double
    var suggestedWeightKg: Double
    var lastUpdated: Date = Date()
}

// MARK: - Weekly Summary

struct ExerciseImprovement: Codable, Identifiable {
    var id: String { name }
    var name: String
    var improvement: Double
}

struct WeeklySummary: Codable, Identifiable {
    var id: String { "week_\(weekNumber)" }
    var weekNumber: Int
    var sessionsCompleted: Int
    var sessionsPlanned: Int
    var totalTrainingMinutes: Int
    var weightChange: Double?
    var startWeight: Double?
    var endWeight: Double?
    var averageRating: Double?
    var bestExercises: [ExerciseImprovement]
    var averageCalories: Int?
    var averageProtein: Double?
    var averageCarbs: Double?
    var averageFats: Double?
    var averageWaterGlasses: Double?
    var currentStreak: Int
    var aiRecommendations: String?
    var generatedAt: Date?

    var completionRate: Double {
        guard sessionsPlanned > 0 else { return 0 }
        return Double(sessionsCompleted) / Double(sessionsPlanned)
    }

    var hasAIRecommendations: Bool {
        aiRecommendations != nil && !aiRecommendations!.isEmpty
    }
}

// MARK: - App State

struct AppData: Codable {
    var profile: UserProfile?
    var weekPrograms: [WeekProgram] = []
    var sessionLogs: [SessionLog] = []
    var weightEntries: [WeightEntry] = []
    var mealPlans: [MealPlan] = []
    var waterIntakes: [WaterIntake] = []
    var chatHistory: [ChatMessage] = []
    var exerciseWeightHistory: [ExerciseWeightHistory] = []
    var weeklySummaries: [WeeklySummary] = []
    var lastSyncDate: Date?

    // Custom decoder to handle missing fields from old data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decodeIfPresent(UserProfile.self, forKey: .profile)
        weekPrograms = try container.decodeIfPresent([WeekProgram].self, forKey: .weekPrograms) ?? []
        sessionLogs = try container.decodeIfPresent([SessionLog].self, forKey: .sessionLogs) ?? []
        weightEntries = try container.decodeIfPresent([WeightEntry].self, forKey: .weightEntries) ?? []
        mealPlans = try container.decodeIfPresent([MealPlan].self, forKey: .mealPlans) ?? []
        waterIntakes = try container.decodeIfPresent([WaterIntake].self, forKey: .waterIntakes) ?? []
        chatHistory = try container.decodeIfPresent([ChatMessage].self, forKey: .chatHistory) ?? []
        exerciseWeightHistory = try container.decodeIfPresent([ExerciseWeightHistory].self, forKey: .exerciseWeightHistory) ?? []
        weeklySummaries = try container.decodeIfPresent([WeeklySummary].self, forKey: .weeklySummaries) ?? []
        lastSyncDate = try container.decodeIfPresent(Date.self, forKey: .lastSyncDate)
    }

    init() {
        // Default initializer
    }
}
