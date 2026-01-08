import Foundation
import SwiftUI
import FirebaseAuth

@MainActor
class DataStore: ObservableObject {
    static let shared = DataStore()

    private let userDefaultsKey = "fitai_app_data"
    private let firestoreService = FirestoreService.shared
    private var authStateListener: AuthStateDidChangeListenerHandle?

    @Published var appData: AppData {
        didSet {
            save()
            // Sync to cloud in background (but not during account deletion)
            if !AuthenticationService.shared.isDeletingAccount {
                Task {
                    await firestoreService.saveAppData(appData)
                }
            }
        }
    }

    @Published var isLoading: Bool = false
    @Published var isSyncingFromCloud: Bool = false

    init() {
        self.appData = AppData()
        load()
        setupAuthStateListener()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Auth State Listener

    private var lastSyncedUserId: String?
    private var hasCompletedInitialLoad = false

    // Flag to indicate sync was triggered by explicit user action (not app startup)
    var pendingUserInitiatedSync = false

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }

                // Don't process auth changes during account deletion
                if AuthenticationService.shared.isDeletingAccount {
                    print("DataStore: Ignoring auth change during account deletion")
                    return
                }

                if let user = user, !user.isAnonymous {
                    // Only sync if:
                    // 1. This is a different user than last time, AND
                    // 2. Either we already have a profile (returning user) OR user explicitly triggered sign-in
                    let shouldSync = self.lastSyncedUserId != user.uid &&
                                     (self.hasProfile || self.pendingUserInitiatedSync)

                    if shouldSync {
                        self.lastSyncedUserId = user.uid
                        print("DataStore: User authenticated, syncing from cloud...")
                        await self.syncFromCloud()
                        self.pendingUserInitiatedSync = false
                    } else if self.lastSyncedUserId != user.uid {
                        // User already logged in at app start but no local profile
                        // Don't sync yet - wait for explicit sign-in action
                        print("DataStore: User detected at startup, waiting for explicit sign-in action")
                        self.lastSyncedUserId = user.uid
                    } else {
                        print("DataStore: Same user, skipping sync")
                    }
                } else {
                    // User logged out or is anonymous
                    self.lastSyncedUserId = nil
                    self.pendingUserInitiatedSync = false
                }
            }
        }
    }

    // Call this when user explicitly initiates sign-in
    func triggerSyncAfterSignIn() async {
        print("DataStore: User-initiated sync triggered")
        pendingUserInitiatedSync = true
        await syncFromCloud()
        pendingUserInitiatedSync = false
    }

    // MARK: - Cloud Sync

    func syncFromCloud() async {
        isSyncingFromCloud = true
        print("DataStore: Starting cloud sync...")

        if let cloudData = await firestoreService.loadAppData() {
            // Cloud data exists - use it
            print("DataStore: Cloud data found! Profile exists: \(cloudData.profile != nil)")
            self.appData = cloudData
            saveLocally() // Save to local without triggering cloud sync again
        } else {
            print("DataStore: No cloud data found")
        }

        isSyncingFromCloud = false
    }

    // Save locally without triggering cloud sync (to avoid infinite loop)
    private func saveLocally() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(appData)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save app data locally: \(error)")
        }
    }

    func syncToCloud() async {
        // Don't sync during account deletion
        if AuthenticationService.shared.isDeletingAccount {
            print("DataStore: Skipping cloud sync during account deletion")
            return
        }
        await firestoreService.saveAppData(appData)
    }

    // MARK: - Persistence

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(appData)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save app data: \(error)")
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            appData = try decoder.decode(AppData.self, from: data)
        } catch {
            print("Failed to load app data: \(error)")
        }
    }

    func reset() {
        print("DataStore: Resetting all data...")
        appData = AppData()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)

        // Reset sync tracking so next sign-in will sync fresh
        lastSyncedUserId = nil
        hasCompletedInitialLoad = false
        pendingUserInitiatedSync = false

        print("DataStore: Reset complete")
    }

    // MARK: - Profile

    var hasProfile: Bool {
        appData.profile != nil && appData.profile?.hasAcceptedDisclaimer == true
    }

    var profile: UserProfile? {
        get { appData.profile }
        set { appData.profile = newValue }
    }

    func saveProfile(_ profile: UserProfile) {
        appData.profile = profile
    }
    
    // MARK: - Week Management
    
    /// Check if the current week should advance to the next week
    /// This is called automatically when the app opens
    func updateCurrentWeekIfNeeded() {
        guard var profile = appData.profile else { return }
        guard let currentProgram = getWeekProgram(week: profile.currentWeek) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Find the last scheduled date in the current week
        guard let lastScheduledDate = currentProgram.workouts.compactMap({ $0.scheduledDate }).max() else {
            return
        }
        
        // Check if we're past the last scheduled workout of the current week
        // We advance to next week if:
        // 1. All workouts are completed, OR
        // 2. We're more than 1 day past the last scheduled workout
        let allCompleted = currentProgram.workouts.allSatisfy { $0.isCompleted }
        let daysSinceLastWorkout = calendar.dateComponents([.day], from: lastScheduledDate, to: now).day ?? 0
        
        if allCompleted || daysSinceLastWorkout > 1 {
            print("📅 DataStore: Advancing from week \(profile.currentWeek) to week \(profile.currentWeek + 1)")
            profile.currentWeek += 1
            appData.profile = profile
        }
    }

    // MARK: - Programs

    func addWeekProgram(_ program: WeekProgram) {
        if let index = appData.weekPrograms.firstIndex(where: { $0.weekIndex == program.weekIndex }) {
            appData.weekPrograms[index] = program
        } else {
            appData.weekPrograms.append(program)
        }
    }

    func getWeekProgram(week: Int) -> WeekProgram? {
        appData.weekPrograms.first { $0.weekIndex == week }
    }

    func deleteWeekProgram(week: Int) {
        appData.weekPrograms.removeAll { $0.weekIndex == week }
    }

    func getCurrentWeekProgram() -> WeekProgram? {
        guard let profile = appData.profile else { return nil }
        return getWeekProgram(week: profile.currentWeek)
    }

    func getTodayWorkout() -> Workout? {
        guard let program = getCurrentWeekProgram() else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find workout scheduled for today only (no fallback to next workout)
        return program.workouts.first(where: {
            guard let scheduled = $0.scheduledDate else { return false }
            return calendar.isDate(scheduled, inSameDayAs: today)
        })
    }

    func isTodayWorkoutCompleted() -> Bool {
        guard let todayWorkout = getTodayWorkout() else { return false }
        return todayWorkout.isCompleted
    }

    func markWorkoutCompleted(_ workoutId: UUID) {
        for (programIndex, program) in appData.weekPrograms.enumerated() {
            if let workoutIndex = program.workouts.firstIndex(where: { $0.id == workoutId }) {
                appData.weekPrograms[programIndex].workouts[workoutIndex].isCompleted = true
            }
        }
    }

    // MARK: - Session Logs

    func addSessionLog(_ log: SessionLog) {
        appData.sessionLogs.append(log)
        markWorkoutCompleted(log.workoutId)

        // Update exercise weight history based on session feedback
        updateExerciseWeightHistory(from: log)
    }

    private func updateExerciseWeightHistory(from log: SessionLog) {
        let multiplier = log.difficulty?.progressionMultiplier ?? 1.025

        for record in log.exerciseRecords {
            // Get the max weight used in this exercise
            guard let maxWeight = record.setsCompleted.map({ $0.weightKg }).max(), maxWeight > 0 else {
                continue
            }

            // Calculate suggested weight for next time
            let suggestedWeight = (maxWeight * multiplier).rounded(toPlaces: 1)

            if let existingIndex = appData.exerciseWeightHistory.firstIndex(where: { $0.exerciseNameKey == record.exerciseNameKey }) {
                appData.exerciseWeightHistory[existingIndex].lastWeightKg = maxWeight
                appData.exerciseWeightHistory[existingIndex].suggestedWeightKg = suggestedWeight
                appData.exerciseWeightHistory[existingIndex].lastUpdated = Date()
            } else {
                let history = ExerciseWeightHistory(
                    exerciseNameKey: record.exerciseNameKey,
                    lastWeightKg: maxWeight,
                    suggestedWeightKg: suggestedWeight
                )
                appData.exerciseWeightHistory.append(history)
            }
        }
    }

    // MARK: - Exercise Weight History

    func getSuggestedWeight(for exerciseNameKey: String) -> Double? {
        appData.exerciseWeightHistory.first(where: { $0.exerciseNameKey == exerciseNameKey })?.suggestedWeightKg
    }

    func getLastWeight(for exerciseNameKey: String) -> Double? {
        appData.exerciseWeightHistory.first(where: { $0.exerciseNameKey == exerciseNameKey })?.lastWeightKg
    }

    func getDefaultWeight(for exerciseNameKey: String, equipment: Equipment) -> Double {
        // If user has history, use suggested weight
        if let suggested = getSuggestedWeight(for: exerciseNameKey) {
            return suggested
        }

        // Otherwise, suggest default starting weights based on exercise type
        if equipment == .none {
            return 0 // Bodyweight exercises
        }

        // Default starting weights for common dumbbell exercises (per dumbbell)
        let defaultWeights: [String: Double] = [
            // Chest
            "ex_dumbbell_bench_press": 10.0,
            "ex_dumbbell_flyes": 6.0,
            "ex_incline_dumbbell_press": 8.0,
            "ex_dumbbell_pullover": 8.0,
            // Back
            "ex_dumbbell_rows": 10.0,
            "ex_single_arm_row": 10.0,
            "ex_renegade_rows": 6.0,
            "ex_dumbbell_deadlift": 12.0,
            // Shoulders
            "ex_dumbbell_shoulder_press": 8.0,
            "ex_lateral_raises": 4.0,
            "ex_front_raises": 4.0,
            "ex_rear_delt_flyes": 4.0,
            "ex_dumbbell_shrugs": 10.0,
            // Arms
            "ex_bicep_curls": 6.0,
            "ex_hammer_curls": 6.0,
            "ex_concentration_curls": 6.0,
            "ex_tricep_kickbacks": 4.0,
            "ex_tricep_extensions": 6.0,
            // Legs
            "ex_goblet_squats": 12.0,
            "ex_lunges": 8.0,
            "ex_bulgarian_split_squats": 8.0,
            "ex_dumbbell_rdl": 10.0,
            "ex_calf_raises": 10.0,
            "ex_step_ups": 8.0,
            // Glutes
            "ex_glute_bridges": 10.0,
            "ex_hip_thrusts": 12.0,
            // Core
            "ex_russian_twists": 4.0,
        ]

        return defaultWeights[exerciseNameKey] ?? 5.0
    }

    func getSessionLogs(limit: Int? = nil) -> [SessionLog] {
        let sorted = appData.sessionLogs.sorted { $0.date > $1.date }
        if let limit = limit {
            return Array(sorted.prefix(limit))
        }
        return sorted
    }

    func getSessionLog(for workoutId: UUID) -> SessionLog? {
        appData.sessionLogs.first { $0.workoutId == workoutId }
    }

    func deleteSessionLog(_ log: SessionLog) {
        appData.sessionLogs.removeAll { $0.id == log.id }
        // Also unmark the workout as completed
        for (programIndex, program) in appData.weekPrograms.enumerated() {
            if let workoutIndex = program.workouts.firstIndex(where: { $0.id == log.workoutId }) {
                appData.weekPrograms[programIndex].workouts[workoutIndex].isCompleted = false
            }
        }
    }

    // MARK: - Weight Entries

    func addWeightEntry(_ entry: WeightEntry) {
        appData.weightEntries.append(entry)
        // Also update profile weight
        if var profile = appData.profile {
            profile.weightKg = entry.weightKg
            appData.profile = profile
        }
    }

    func getWeightEntries() -> [WeightEntry] {
        appData.weightEntries.sorted { $0.date < $1.date }
    }

    func getLatestWeight() -> Double? {
        appData.weightEntries.max(by: { $0.date < $1.date })?.weightKg ?? appData.profile?.weightKg
    }

    func deleteWeightEntry(_ entry: WeightEntry) {
        appData.weightEntries.removeAll { $0.id == entry.id }
    }

    func updateWeightEntry(_ entry: WeightEntry) {
        if let index = appData.weightEntries.firstIndex(where: { $0.id == entry.id }) {
            appData.weightEntries[index] = entry
            // Also update profile weight if this is the latest entry
            if appData.weightEntries.max(by: { $0.date < $1.date })?.id == entry.id,
               var profile = appData.profile {
                profile.weightKg = entry.weightKg
                appData.profile = profile
            }
        }
    }

    // MARK: - Meal Plans

    func addMealPlan(_ plan: MealPlan) {
        if let index = appData.mealPlans.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: plan.date)
        }) {
            appData.mealPlans[index] = plan
        } else {
            appData.mealPlans.append(plan)
        }
    }

    func getTodayMealPlan() -> MealPlan? {
        let today = Calendar.current.startOfDay(for: Date())
        return appData.mealPlans.first {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }
    }

    func getMealPlan(for date: Date) -> MealPlan? {
        appData.mealPlans.first {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    func deleteMealPlan(for date: Date) {
        appData.mealPlans.removeAll {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    // MARK: - Water Intake

    func getWaterIntake(for date: Date) -> WaterIntake? {
        appData.waterIntakes.first {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    func addWaterGlass(for date: Date) {
        if let index = appData.waterIntakes.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }) {
            appData.waterIntakes[index].glasses += 1
        } else {
            var intake = WaterIntake(date: date)
            intake.glasses = 1
            appData.waterIntakes.append(intake)
        }
    }

    func removeWaterGlass(for date: Date) {
        if let index = appData.waterIntakes.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }) {
            if appData.waterIntakes[index].glasses > 0 {
                appData.waterIntakes[index].glasses -= 1
            }
        }
    }

    func setWaterTarget(glasses: Int, for date: Date) {
        if let index = appData.waterIntakes.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }) {
            appData.waterIntakes[index].targetGlasses = glasses
        } else {
            var intake = WaterIntake(date: date)
            intake.targetGlasses = glasses
            appData.waterIntakes.append(intake)
        }
    }

    // MARK: - Chat History

    func addChatMessage(_ message: ChatMessage) {
        appData.chatHistory.append(message)
    }

    func getChatHistory() -> [ChatMessage] {
        appData.chatHistory.sorted { $0.timestamp < $1.timestamp }
    }

    func clearChatHistory() {
        appData.chatHistory.removeAll()
    }

    // MARK: - CSV Export

    func exportWeightDataToCSV() -> String {
        var csv = "Date,Weight (kg),Notes\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for entry in getWeightEntries() {
            let date = dateFormatter.string(from: entry.date)
            let notes = entry.notes.replacingOccurrences(of: ",", with: ";")
            csv += "\(date),\(entry.weightKg),\(notes)\n"
        }
        return csv
    }

    func exportSessionLogsToCSV() -> String {
        var csv = "Date,Workout,Duration (min),Rating,Notes\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        for log in getSessionLogs() {
            let date = dateFormatter.string(from: log.date)
            let duration = log.durationMinutes ?? 0
            let rating = log.rating ?? 0
            let notes = log.notes.replacingOccurrences(of: ",", with: ";")
            csv += "\(date),\(log.workoutTitleKey),\(duration),\(rating),\(notes)\n"
        }
        return csv
    }

    // MARK: - Statistics

    func getTotalWorkoutsCompleted() -> Int {
        appData.sessionLogs.count
    }

    func getWeeklyWorkoutsCompleted() -> Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        return appData.sessionLogs.filter { $0.date >= weekAgo }.count
    }

    func getWeightProgress() -> (start: Double, current: Double, change: Double)? {
        let entries = getWeightEntries()
        guard let first = entries.first, let last = entries.last else { return nil }
        let change = last.weightKg - first.weightKg
        return (first.weightKg, last.weightKg, change)
    }

    // MARK: - Weekly Summary

    func getWeeklySummary(for weekNumber: Int? = nil) -> WeeklySummary {
        let calendar = Calendar.current
        let today = Date()

        // Get start of current week (Monday)
        let weekStart: Date
        let weekEnd: Date

        if let weekNum = weekNumber, let program = getWeekProgram(week: weekNum),
           let firstWorkout = program.workouts.first?.scheduledDate {
            // Use the week of the program
            weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: firstWorkout))!
            weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        } else {
            // Use current week
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
            components.weekday = 2 // Monday
            weekStart = calendar.date(from: components) ?? today
            weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        }

        let currentWeekNum = weekNumber ?? (appData.profile?.currentWeek ?? 1)

        // Sessions completed vs planned
        let program = getWeekProgram(week: currentWeekNum)
        let sessionsPlanned = program?.workouts.count ?? 0
        let sessionsCompleted = program?.workouts.filter { $0.isCompleted }.count ?? 0

        // Get session logs for this week
        let weekLogs = appData.sessionLogs.filter { log in
            log.date >= weekStart && log.date < weekEnd
        }

        // Total training time
        let totalMinutes = weekLogs.compactMap { $0.durationMinutes }.reduce(0, +)

        // Average rating
        let ratings = weekLogs.compactMap { $0.rating }
        let avgRating = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)

        // Weight change this week
        let weekWeights = appData.weightEntries.filter { entry in
            entry.date >= weekStart && entry.date < weekEnd
        }.sorted { $0.date < $1.date }

        let startWeight = weekWeights.first?.weightKg
        let endWeight = weekWeights.last?.weightKg
        let weightChange: Double? = (startWeight != nil && endWeight != nil) ? endWeight! - startWeight! : nil

        // Best exercises (most improved weights)
        let bestExercises = calculateBestExercises(from: weekLogs)

        // Nutrition averages
        let weekMeals = appData.mealPlans.filter { meal in
            meal.date >= weekStart && meal.date < weekEnd
        }

        let avgCalories: Int? = weekMeals.isEmpty ? nil : weekMeals.map { $0.totalKcal }.reduce(0, +) / weekMeals.count
        let avgProtein: Double? = weekMeals.isEmpty ? nil : weekMeals.map { $0.totalProtein }.reduce(0, +) / Double(weekMeals.count)
        let avgCarbs: Double? = weekMeals.isEmpty ? nil : weekMeals.map { $0.totalCarbs }.reduce(0, +) / Double(weekMeals.count)
        let avgFats: Double? = weekMeals.isEmpty ? nil : weekMeals.map { $0.totalFats }.reduce(0, +) / Double(weekMeals.count)

        // Water intake average
        let weekWater = appData.waterIntakes.filter { intake in
            intake.date >= weekStart && intake.date < weekEnd
        }
        let avgWater: Double? = weekWater.isEmpty ? nil : Double(weekWater.map { $0.glasses }.reduce(0, +)) / Double(weekWater.count)

        // Calculate streak
        let streak = calculateCurrentStreak()

        return WeeklySummary(
            weekNumber: currentWeekNum,
            sessionsCompleted: sessionsCompleted,
            sessionsPlanned: sessionsPlanned,
            totalTrainingMinutes: totalMinutes,
            weightChange: weightChange,
            startWeight: startWeight,
            endWeight: endWeight,
            averageRating: avgRating,
            bestExercises: bestExercises,
            averageCalories: avgCalories,
            averageProtein: avgProtein,
            averageCarbs: avgCarbs,
            averageFats: avgFats,
            averageWaterGlasses: avgWater,
            currentStreak: streak,
            aiRecommendations: nil
        )
    }

    private func calculateBestExercises(from logs: [SessionLog]) -> [ExerciseImprovement] {
        var exerciseWeights: [String: [Double]] = [:]

        for log in logs {
            for record in log.exerciseRecords {
                let maxWeight = record.setsCompleted.map { $0.weightKg }.max() ?? 0
                if maxWeight > 0 {
                    if exerciseWeights[record.exerciseNameKey] == nil {
                        exerciseWeights[record.exerciseNameKey] = []
                    }
                    exerciseWeights[record.exerciseNameKey]?.append(maxWeight)
                }
            }
        }

        // Calculate improvement for exercises with multiple entries
        var improvements: [ExerciseImprovement] = []
        for (name, weights) in exerciseWeights {
            if weights.count >= 2, let first = weights.first, let last = weights.last, first > 0 {
                let improvement = ((last - first) / first) * 100
                if improvement > 0 {
                    improvements.append(ExerciseImprovement(name: name, improvement: improvement))
                }
            }
        }

        return improvements.sorted { $0.improvement > $1.improvement }.prefix(3).map { $0 }
    }

    private func calculateCurrentStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())

        // Get all workout dates
        let workoutDates = Set(appData.sessionLogs.map { calendar.startOfDay(for: $0.date) })

        // Count backwards from today/yesterday
        if !workoutDates.contains(currentDate) {
            // Check if yesterday had a workout
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate),
               workoutDates.contains(yesterday) {
                currentDate = yesterday
            } else {
                return 0
            }
        }

        while workoutDates.contains(currentDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = previousDay
        }

        return streak
    }

    func shouldShowWeeklySummary() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)

        // Show on Sunday (weekday = 1) from 18:00 onwards
        return weekday == 1 && hour >= 18
    }

    // MARK: - Weekly Summary Storage

    /// Get cached summary for a week, or nil if not generated yet
    func getCachedWeeklySummary(for weekNumber: Int) -> WeeklySummary? {
        return appData.weeklySummaries.first { $0.weekNumber == weekNumber }
    }

    /// Save a weekly summary (with AI recommendations)
    func saveWeeklySummary(_ summary: WeeklySummary) {
        // Remove old summary for this week if exists
        appData.weeklySummaries.removeAll { $0.weekNumber == summary.weekNumber }
        appData.weeklySummaries.append(summary)
        save()
        Task {
            await syncToCloud()
        }
    }

    /// Get or create summary for current week
    func getOrCreateWeeklySummary() -> WeeklySummary {
        let currentWeekNum = appData.profile?.currentWeek ?? 1

        // Check if we have a cached summary with AI recommendations
        if let cached = getCachedWeeklySummary(for: currentWeekNum),
           cached.hasAIRecommendations {
            return cached
        }

        // Generate fresh stats (without AI recommendations yet)
        return getWeeklySummary(for: currentWeekNum)
    }
}
