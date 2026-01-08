import Foundation

@MainActor
class AIAssistant: ObservableObject {
    static let shared = AIAssistant()

    @Published var isProcessing = false

    // Keywords for intent detection
    private let programKeywords = ["programme", "program", "entraînement", "workout", "training", "séance", "session", "semaine", "week", "générer", "generate", "créer", "create"]
    private let menuKeywords = ["menu", "repas", "meal", "manger", "eat", "nutrition", "calories", "protéines", "protein", "macros"]
    private let reminderKeywords = ["rappel", "reminder", "notification", "alert", "rappeler", "remind"]
    private let exerciseKeywords = ["exercice", "exercise", "mouvement", "mouvement", "technique", "form", "comment", "how"]
    private let macroKeywords = ["macro", "protéine", "protein", "glucide", "carb", "lipide", "fat", "calorie"]
    private let progressKeywords = ["progrès", "progress", "évolution", "evolution", "résultat", "result", "poids", "weight"]
    private let tipKeywords = ["conseil", "tip", "astuce", "advice", "recommandation", "recommendation"]

    // MARK: - Process Message

    func processMessage(_ message: String, profile: UserProfile?, localization: LocalizationManager) -> String {
        let lowercased = message.lowercased()

        // Detect intent and respond
        if containsKeywords(lowercased, keywords: programKeywords) {
            return handleProgramIntent(message, profile: profile, localization: localization)
        }

        if containsKeywords(lowercased, keywords: menuKeywords) {
            return handleMenuIntent(message, profile: profile, localization: localization)
        }

        if containsKeywords(lowercased, keywords: reminderKeywords) {
            return handleReminderIntent(localization: localization)
        }

        if containsKeywords(lowercased, keywords: exerciseKeywords) {
            return handleExerciseIntent(message, localization: localization)
        }

        if containsKeywords(lowercased, keywords: macroKeywords) {
            return handleMacroIntent(profile: profile, localization: localization)
        }

        if containsKeywords(lowercased, keywords: progressKeywords) {
            return handleProgressIntent(localization: localization)
        }

        if containsKeywords(lowercased, keywords: tipKeywords) {
            return getDailyTip(localization: localization)
        }

        // Default response
        return getDefaultResponse(localization: localization)
    }

    // MARK: - Intent Handlers

    private func handleProgramIntent(_ message: String, profile: UserProfile?, localization: LocalizationManager) -> String {
        guard let profile = profile else {
            return localization.currentLanguage == .french
                ? "Vous devez d'abord créer votre profil pour générer un programme personnalisé."
                : "You need to create your profile first to generate a personalized program."
        }

        let sessions = profile.sessionsPerWeek
        let equipment = profile.equipment == .dumbbells
            ? localization["equipment_dumbbells"]
            : localization["equipment_none"]

        if localization.currentLanguage == .french {
            return """
            Je peux générer un programme de prise de masse adapté à votre profil :

            - \(sessions) séances par semaine
            - Équipement : \(equipment)
            - Split : \(sessions <= 4 ? "Full Body" : "Push/Pull/Legs")

            Le programme inclut une progression automatique : +5% de charge ou +1 rep toutes les 2 semaines.

            Allez dans l'onglet "Entraînements" et appuyez sur "Générer la semaine" pour créer votre programme !
            """
        } else {
            return """
            I can generate a mass-building program adapted to your profile:

            - \(sessions) sessions per week
            - Equipment: \(equipment)
            - Split: \(sessions <= 4 ? "Full Body" : "Push/Pull/Legs")

            The program includes automatic progression: +5% weight or +1 rep every 2 weeks.

            Go to the "Workouts" tab and tap "Generate week" to create your program!
            """
        }
    }

    private func handleMenuIntent(_ message: String, profile: UserProfile?, localization: LocalizationManager) -> String {
        guard let profile = profile else {
            return localization.currentLanguage == .french
                ? "Créez d'abord votre profil pour obtenir un plan repas personnalisé."
                : "Create your profile first to get a personalized meal plan."
        }

        let tdee = MealGenerator.shared.calculateTDEE(profile: profile)
        let (protein, carbs, fats) = MealGenerator.shared.calculateMacros(profile: profile)

        if localization.currentLanguage == .french {
            return """
            Voici vos besoins caloriques pour la prise de masse :

            🔥 Calories quotidiennes : \(tdee) kcal
            🥩 Protéines : \(Int(protein))g
            🍚 Glucides : \(Int(carbs))g
            🥑 Lipides : \(Int(fats))g

            Ces calculs incluent un surplus de 350 kcal pour favoriser la prise de muscle.

            Allez dans l'onglet "Repas" pour générer votre menu du jour !
            """
        } else {
            return """
            Here are your calorie needs for mass building:

            🔥 Daily calories: \(tdee) kcal
            🥩 Protein: \(Int(protein))g
            🍚 Carbs: \(Int(carbs))g
            🥑 Fats: \(Int(fats))g

            These calculations include a 350 kcal surplus to promote muscle growth.

            Go to the "Meals" tab to generate your daily menu!
            """
        }
    }

    private func handleReminderIntent(localization: LocalizationManager) -> String {
        if localization.currentLanguage == .french {
            return """
            Les rappels vous aident à ne jamais manquer une séance !

            ⏰ Configuration :
            1. Allez dans Paramètres
            2. Activez les notifications
            3. Choisissez le délai de rappel (15, 30 ou 60 min avant)

            Vous recevrez une notification avant chaque séance planifiée.
            """
        } else {
            return """
            Reminders help you never miss a workout!

            ⏰ Setup:
            1. Go to Settings
            2. Enable notifications
            3. Choose reminder time (15, 30 or 60 min before)

            You'll receive a notification before each scheduled session.
            """
        }
    }

    private func handleExerciseIntent(_ message: String, localization: LocalizationManager) -> String {
        // Try to identify specific exercise
        let exerciseResponses: [String: (fr: String, en: String)] = [
            "squat": (
                fr: "🦵 Squats :\n\n1. Pieds écartés largeur d'épaules\n2. Descendez en poussant les hanches vers l'arrière\n3. Gardez le dos droit et les genoux alignés\n4. Descendez jusqu'à ce que les cuisses soient parallèles\n5. Poussez sur les talons pour remonter",
                en: "🦵 Squats:\n\n1. Feet shoulder-width apart\n2. Lower by pushing hips back\n3. Keep back straight and knees aligned\n4. Go down until thighs are parallel\n5. Push through heels to stand up"
            ),
            "pompe": (
                fr: "💪 Pompes :\n\n1. Mains écartées un peu plus que les épaules\n2. Corps aligné de la tête aux pieds\n3. Descendez jusqu'à ce que la poitrine frôle le sol\n4. Poussez pour remonter en gardant le corps gainé\n5. Respirez : inspirez en descendant, expirez en montant",
                en: "💪 Push-ups:\n\n1. Hands slightly wider than shoulders\n2. Body aligned from head to feet\n3. Lower until chest nearly touches floor\n4. Push up while keeping core tight\n5. Breathe: inhale going down, exhale going up"
            ),
            "push": (
                fr: "💪 Pompes :\n\n1. Mains écartées un peu plus que les épaules\n2. Corps aligné de la tête aux pieds\n3. Descendez jusqu'à ce que la poitrine frôle le sol\n4. Poussez pour remonter en gardant le corps gainé\n5. Respirez : inspirez en descendant, expirez en montant",
                en: "💪 Push-ups:\n\n1. Hands slightly wider than shoulders\n2. Body aligned from head to feet\n3. Lower until chest nearly touches floor\n4. Push up while keeping core tight\n5. Breathe: inhale going down, exhale going up"
            ),
        ]

        let lowercased = message.lowercased()
        for (keyword, response) in exerciseResponses {
            if lowercased.contains(keyword) {
                return localization.currentLanguage == .french ? response.fr : response.en
            }
        }

        // Generic exercise tips
        if localization.currentLanguage == .french {
            return """
            📚 Conseils techniques généraux :

            1. Échauffez-vous toujours avant l'entraînement
            2. Contrôlez le mouvement (tempo 2-1-2)
            3. Ne sacrifiez jamais la forme pour la charge
            4. Respirez : expirez sur l'effort
            5. Hydratez-vous entre les séries

            Demandez-moi des conseils sur un exercice spécifique !
            """
        } else {
            return """
            📚 General technique tips:

            1. Always warm up before training
            2. Control the movement (2-1-2 tempo)
            3. Never sacrifice form for weight
            4. Breathe: exhale on effort
            5. Stay hydrated between sets

            Ask me about a specific exercise for detailed tips!
            """
        }
    }

    private func handleMacroIntent(profile: UserProfile?, localization: LocalizationManager) -> String {
        if localization.currentLanguage == .french {
            return """
            📊 Les macronutriments expliqués :

            🥩 PROTÉINES (1.8-2.2g/kg)
            Essentielles pour la construction musculaire. Sources : viande, poisson, œufs, légumineuses.

            🍚 GLUCIDES (50-60% des calories)
            Énergie pour l'entraînement. Sources : riz, pâtes, patates, fruits.

            🥑 LIPIDES (25-30% des calories)
            Hormones et santé. Sources : huile d'olive, avocat, noix, poisson gras.

            Pour la prise de masse, visez un surplus de 300-400 kcal/jour.
            """
        } else {
            return """
            📊 Macronutrients explained:

            🥩 PROTEIN (1.8-2.2g/kg)
            Essential for muscle building. Sources: meat, fish, eggs, legumes.

            🍚 CARBS (50-60% of calories)
            Energy for training. Sources: rice, pasta, potatoes, fruits.

            🥑 FATS (25-30% of calories)
            Hormones and health. Sources: olive oil, avocado, nuts, fatty fish.

            For mass building, aim for a 300-400 kcal/day surplus.
            """
        }
    }

    private func handleProgressIntent(localization: LocalizationManager) -> String {
        if localization.currentLanguage == .french {
            return """
            📈 Suivi de progression :

            Pour suivre vos progrès efficacement :

            1. Pesez-vous chaque semaine (même jour, même heure)
            2. Enregistrez chaque séance avec les poids utilisés
            3. Visez 0.25-0.5 kg de prise par semaine
            4. Prenez des photos mensuelles

            Consultez l'onglet "Suivi" pour voir vos graphiques !
            """
        } else {
            return """
            📈 Progress tracking:

            To track your progress effectively:

            1. Weigh yourself weekly (same day, same time)
            2. Log each session with weights used
            3. Aim for 0.25-0.5 kg gain per week
            4. Take monthly progress photos

            Check the "Tracking" tab to see your charts!
            """
        }
    }

    private func getDailyTip(localization: LocalizationManager) -> String {
        let frenchTips = [
            "💡 Dormez au moins 7-8h par nuit. C'est pendant le sommeil que vos muscles récupèrent et grandissent !",
            "💡 Mangez des protéines à chaque repas pour maintenir la synthèse protéique tout au long de la journée.",
            "💡 N'oubliez pas de vous hydrater : 2-3L d'eau par jour minimum, plus si vous transpirez beaucoup.",
            "💡 La progression est plus importante que la perfection. Ajoutez du poids ou des reps régulièrement.",
            "💡 Les jours de repos sont aussi importants que les jours d'entraînement. Laissez vos muscles récupérer !",
            "💡 Échauffez-vous toujours avant de soulever lourd. 5-10 min de cardio léger + séries légères.",
        ]

        let englishTips = [
            "💡 Sleep at least 7-8h per night. Your muscles recover and grow during sleep!",
            "💡 Eat protein at every meal to maintain protein synthesis throughout the day.",
            "💡 Stay hydrated: 2-3L of water per day minimum, more if you sweat a lot.",
            "💡 Progress is more important than perfection. Add weight or reps regularly.",
            "💡 Rest days are as important as training days. Let your muscles recover!",
            "💡 Always warm up before lifting heavy. 5-10 min light cardio + warm-up sets.",
        ]

        let tips = localization.currentLanguage == .french ? frenchTips : englishTips
        return tips.randomElement() ?? tips[0]
    }

    private func getDefaultResponse(localization: LocalizationManager) -> String {
        if localization.currentLanguage == .french {
            return """
            Je suis votre assistant fitness ! Je peux vous aider avec :

            🏋️ Programmes d'entraînement
            🍽️ Plans repas et nutrition
            ⏰ Rappels et notifications
            📚 Technique des exercices
            📊 Suivi de progression
            💡 Conseils du jour

            Que voulez-vous savoir ?
            """
        } else {
            return """
            I'm your fitness assistant! I can help you with:

            🏋️ Workout programs
            🍽️ Meal plans and nutrition
            ⏰ Reminders and notifications
            📚 Exercise technique
            📊 Progress tracking
            💡 Daily tips

            What would you like to know?
            """
        }
    }

    // MARK: - Helpers

    private func containsKeywords(_ text: String, keywords: [String]) -> Bool {
        for keyword in keywords {
            if text.contains(keyword) {
                return true
            }
        }
        return false
    }
}
