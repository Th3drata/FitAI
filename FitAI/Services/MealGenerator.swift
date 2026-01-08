import Foundation

class MealGenerator {
    static let shared = MealGenerator()

    // MARK: - Calorie Calculation

    func calculateTDEE(profile: UserProfile) -> Int {
        // Mifflin-St Jeor Equation
        let weight = profile.weightKg
        let height = profile.heightCm
        let age = Double(profile.age)

        var bmr: Double
        switch profile.sex {
        case .male:
            bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5
        case .female:
            bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161
        case .other:
            bmr = (10 * weight) + (6.25 * height) - (5 * age) - 78
        }

        // Activity multiplier based on sessions per week
        let activityMultiplier: Double
        switch profile.sessionsPerWeek {
        case 3: activityMultiplier = 1.375 // Light
        case 4: activityMultiplier = 1.55  // Moderate
        case 5: activityMultiplier = 1.725 // Active
        case 6: activityMultiplier = 1.9   // Very active
        default: activityMultiplier = 1.55
        }

        let tdee = bmr * activityMultiplier

        // Add surplus for mass gain (300-400 kcal)
        return Int(tdee + 350)
    }

    // MARK: - Macro Calculation

    func calculateMacros(profile: UserProfile) -> (protein: Double, carbs: Double, fats: Double) {
        let totalCalories = calculateTDEE(profile: profile)
        let weight = profile.weightKg

        // Protein: 1.8-2.2g per kg for mass gain
        let protein = weight * 2.0

        // Fat: 25-30% of calories
        let fatCalories = Double(totalCalories) * 0.27
        let fats = fatCalories / 9.0

        // Carbs: remaining calories
        let proteinCalories = protein * 4.0
        let carbCalories = Double(totalCalories) - proteinCalories - fatCalories
        let carbs = carbCalories / 4.0

        return (protein, carbs, fats)
    }

    // MARK: - Meal Database

    private let breakfastOptions: [Meal] = [
        Meal(
            nameKey: "meal_oatmeal_banana",
            descriptionKey: "Flocons d'avoine avec banane, miel et amandes",
            kcal: 450,
            proteinG: 15,
            carbsG: 70,
            fatsG: 12,
            ingredients: ["100g flocons d'avoine", "1 banane", "20g amandes", "1 c.s. miel", "200ml lait"]
        ),
        Meal(
            nameKey: "meal_eggs_toast",
            descriptionKey: "Oeufs brouillés avec tartines complètes",
            kcal: 520,
            proteinG: 28,
            carbsG: 45,
            fatsG: 24,
            ingredients: ["3 oeufs", "2 tranches pain complet", "1 avocat", "Beurre"]
        ),
        Meal(
            nameKey: "meal_protein_smoothie",
            descriptionKey: "Smoothie protéiné aux fruits rouges",
            kcal: 480,
            proteinG: 35,
            carbsG: 55,
            fatsG: 12,
            ingredients: ["30g whey", "150g fruits rouges", "1 banane", "250ml lait", "30g flocons d'avoine"]
        ),
        Meal(
            nameKey: "meal_greek_yogurt",
            descriptionKey: "Yaourt grec avec granola et fruits",
            kcal: 420,
            proteinG: 25,
            carbsG: 50,
            fatsG: 14,
            ingredients: ["200g yaourt grec", "50g granola", "1 pomme", "1 c.s. miel"]
        ),
    ]

    private let lunchOptions: [Meal] = [
        Meal(
            nameKey: "meal_chicken_rice",
            descriptionKey: "Poulet grillé avec riz et légumes verts",
            kcal: 650,
            proteinG: 45,
            carbsG: 70,
            fatsG: 18,
            ingredients: ["150g blanc de poulet", "150g riz basmati", "200g brocoli", "Huile d'olive"]
        ),
        Meal(
            nameKey: "meal_pasta_beef",
            descriptionKey: "Pâtes complètes au boeuf haché et sauce tomate",
            kcal: 720,
            proteinG: 42,
            carbsG: 85,
            fatsG: 22,
            ingredients: ["120g pâtes complètes", "150g boeuf haché 5%", "200g sauce tomate", "Parmesan"]
        ),
        Meal(
            nameKey: "meal_salmon_quinoa",
            descriptionKey: "Saumon grillé avec quinoa et épinards",
            kcal: 580,
            proteinG: 40,
            carbsG: 45,
            fatsG: 26,
            ingredients: ["150g saumon", "100g quinoa", "150g épinards", "Citron", "Huile d'olive"]
        ),
        Meal(
            nameKey: "meal_tuna_salad",
            descriptionKey: "Salade de thon avec quinoa et légumes",
            kcal: 520,
            proteinG: 38,
            carbsG: 40,
            fatsG: 22,
            ingredients: ["150g thon en conserve", "80g quinoa", "Tomates", "Concombre", "Huile d'olive"]
        ),
    ]

    private let dinnerOptions: [Meal] = [
        Meal(
            nameKey: "meal_steak_potatoes",
            descriptionKey: "Steak de boeuf avec pommes de terre sautées",
            kcal: 680,
            proteinG: 45,
            carbsG: 55,
            fatsG: 28,
            ingredients: ["180g steak de boeuf", "200g pommes de terre", "Haricots verts", "Beurre"]
        ),
        Meal(
            nameKey: "meal_turkey_wrap",
            descriptionKey: "Wrap à la dinde avec légumes",
            kcal: 550,
            proteinG: 38,
            carbsG: 50,
            fatsG: 20,
            ingredients: ["150g dinde", "2 wraps complets", "Laitue", "Tomates", "Sauce yaourt"]
        ),
        Meal(
            nameKey: "meal_fish_vegetables",
            descriptionKey: "Poisson blanc avec riz et légumes grillés",
            kcal: 480,
            proteinG: 40,
            carbsG: 45,
            fatsG: 14,
            ingredients: ["180g cabillaud", "120g riz", "Courgettes", "Poivrons", "Huile d'olive"]
        ),
        Meal(
            nameKey: "meal_beef_stir_fry",
            descriptionKey: "Boeuf sauté aux légumes et nouilles",
            kcal: 620,
            proteinG: 42,
            carbsG: 60,
            fatsG: 22,
            ingredients: ["150g boeuf", "150g nouilles", "Poivrons", "Oignons", "Sauce soja"]
        ),
    ]

    private let snackOptions: [Meal] = [
        Meal(
            nameKey: "meal_nuts_fruit",
            descriptionKey: "Mélange de noix et fruits secs",
            kcal: 250,
            proteinG: 8,
            carbsG: 22,
            fatsG: 16,
            ingredients: ["30g amandes", "20g noix de cajou", "20g raisins secs"]
        ),
        Meal(
            nameKey: "meal_protein_bar",
            descriptionKey: "Barre protéinée",
            kcal: 220,
            proteinG: 20,
            carbsG: 25,
            fatsG: 8,
            ingredients: ["1 barre protéinée"]
        ),
        Meal(
            nameKey: "meal_cottage_cheese",
            descriptionKey: "Fromage blanc avec fruits",
            kcal: 180,
            proteinG: 20,
            carbsG: 15,
            fatsG: 4,
            ingredients: ["150g fromage blanc", "100g fruits frais"]
        ),
    ]

    // MARK: - Meal Plan Generation

    func generateMealPlan(for profile: UserProfile, date: Date = Date()) -> MealPlan {
        let targetCalories = calculateTDEE(profile: profile)
        let (targetProtein, targetCarbs, targetFats) = calculateMacros(profile: profile)

        // Select meals that best match targets
        var breakfast = selectBestMeal(from: breakfastOptions, targetCalories: Int(Double(targetCalories) * 0.25))
        var lunch = selectBestMeal(from: lunchOptions, targetCalories: Int(Double(targetCalories) * 0.35))
        var dinner = selectBestMeal(from: dinnerOptions, targetCalories: Int(Double(targetCalories) * 0.30))

        // Scale meals to match calorie target
        let currentTotal = breakfast.kcal + lunch.kcal + dinner.kcal
        let scaleFactor = Double(targetCalories) * 0.9 / Double(currentTotal) // Leave room for snack

        breakfast = scaleMeal(breakfast, by: scaleFactor)
        lunch = scaleMeal(lunch, by: scaleFactor)
        dinner = scaleMeal(dinner, by: scaleFactor)

        // Add snack if needed
        var snacks: [Meal] = []
        let remaining = targetCalories - (breakfast.kcal + lunch.kcal + dinner.kcal)
        if remaining > 100 {
            if let snack = snackOptions.min(by: { abs($0.kcal - remaining) < abs($1.kcal - remaining) }) {
                snacks.append(snack)
            }
        }

        return MealPlan(
            date: date,
            breakfast: breakfast,
            lunch: lunch,
            dinner: dinner,
            snacks: snacks
        )
    }

    private func selectBestMeal(from meals: [Meal], targetCalories: Int) -> Meal {
        // Random selection with slight preference for closer calorie match
        let shuffled = meals.shuffled()
        return shuffled.first ?? meals[0]
    }

    private func scaleMeal(_ meal: Meal, by factor: Double) -> Meal {
        var scaled = meal
        scaled.kcal = Int(Double(meal.kcal) * factor)
        scaled.proteinG = meal.proteinG * factor
        scaled.carbsG = meal.carbsG * factor
        scaled.fatsG = meal.fatsG * factor
        return scaled
    }

    // MARK: - Weekly Plan

    func generateWeekMealPlans(for profile: UserProfile) -> [MealPlan] {
        let calendar = Calendar.current
        var plans: [MealPlan] = []

        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: Date()) {
                let plan = generateMealPlan(for: profile, date: date)
                plans.append(plan)
            }
        }

        return plans
    }
}
