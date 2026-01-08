import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var localization: LocalizationManager
    @StateObject private var authService = AuthenticationService.shared

    @State private var currentStep: OnboardingStep = .welcome
    @State private var profile = UserProfile()
    @State private var showDisclaimer = false
    @State private var hasCheckedAuth = false

    // Auth fields
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = true

    // Direct input fields
    @State private var showWeightInput = false
    @State private var showHeightInput = false
    @State private var weightInputText = ""
    @State private var heightInputText = ""

    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case auth
        case basicInfo
        case goalsInfo
        case dietaryRegime
        case dietaryAllergies
        case dietaryDislikes
        case fitnessInfo
        case notifications
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator

                // Content
                TabView(selection: $currentStep) {
                    welcomeStep.tag(OnboardingStep.welcome)
                    authStep.tag(OnboardingStep.auth)
                    basicInfoStep.tag(OnboardingStep.basicInfo)
                    goalsInfoStep.tag(OnboardingStep.goalsInfo)
                    dietaryRegimeStep.tag(OnboardingStep.dietaryRegime)
                    dietaryAllergiesStep.tag(OnboardingStep.dietaryAllergies)
                    dietaryDislikesStep.tag(OnboardingStep.dietaryDislikes)
                    fitnessInfoStep.tag(OnboardingStep.fitnessInfo)
                    notificationsStep.tag(OnboardingStep.notifications)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(AppTheme.springAnimation, value: currentStep)
            }
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .sheet(isPresented: $showDisclaimer) {
            disclaimerSheet
        }
        .alert(localization["onboarding_weight"], isPresented: $showWeightInput) {
            TextField("kg", text: $weightInputText)
                .keyboardType(.decimalPad)
            Button(localization["cancel"], role: .cancel) {}
            Button(localization["ok"]) {
                if let weight = Double(weightInputText.replacingOccurrences(of: ",", with: ".")) {
                    profile.weightKg = min(max(weight, 40), 150)
                    HapticsManager.shared.selection()
                }
            }
        } message: {
            Text(localization["onboarding_enter_weight"])
        }
        .alert(localization["onboarding_height"], isPresented: $showHeightInput) {
            TextField("cm", text: $heightInputText)
                .keyboardType(.numberPad)
            Button(localization["cancel"], role: .cancel) {}
            Button(localization["ok"]) {
                if let height = Double(heightInputText) {
                    profile.heightCm = min(max(height, 140), 220)
                    HapticsManager.shared.selection()
                }
            }
        } message: {
            Text(localization["onboarding_enter_height"])
        }
        .onAppear {
            // Si l'utilisateur est déjà authentifié (reconnexion après réinstall),
            // on saute directement à l'étape de création de profil
            if !hasCheckedAuth && authService.isAuthenticated {
                hasCheckedAuth = true
                // Si pas de profil dans le cloud, aller à basicInfo
                if !dataStore.hasProfile {
                    currentStep = .basicInfo
                }
                // Sinon, ContentView affichera MainTabView automatiquement
            }
        }
        .onChange(of: authService.isAuthenticated) { isAuth in
            // Quand l'auth change (connexion réussie), attendre la fin du sync
            if isAuth && currentStep == .auth {
                print("OnboardingView: Auth changed to authenticated, waiting for sync to complete...")
                // Le sync sera déclenché automatiquement par triggerSyncAfterSignIn()
                // On observe isSyncingFromCloud pour savoir quand c'est terminé
            }
        }
        .onChange(of: dataStore.isSyncingFromCloud) { isSyncing in
            // Quand le sync cloud est terminé
            if !isSyncing && authService.isAuthenticated && currentStep == .auth {
                print("OnboardingView: Cloud sync finished, hasProfile = \(dataStore.hasProfile)")
                if !dataStore.hasProfile {
                    // Pas de données cloud, continuer l'onboarding
                    print("OnboardingView: No cloud profile, continuing to basicInfo")
                    goToNext()
                }
                // Sinon ContentView détectera hasProfile et affichera MainTabView
            }
        }
        .onChange(of: dataStore.hasProfile) { hasProfile in
            // Si le profil est chargé du cloud, on n'a plus besoin de l'onboarding
            // ContentView s'en chargera automatiquement
            print("OnboardingView: hasProfile changed to \(hasProfile)")
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: AppTheme.spacingS) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue ? AppTheme.accent : Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .animation(AppTheme.springAnimation, value: currentStep)
            }
        }
        .padding(.horizontal, AppTheme.spacingL)
        .padding(.top, AppTheme.spacingM)
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: AppTheme.spacingXL) {
            Spacer()

            // Icon
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.accent)

            VStack(spacing: AppTheme.spacingM) {
                Text(localization["onboarding_welcome"])
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(localization["onboarding_subtitle"])
                    .font(.title3)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppTheme.spacingL)

            Spacer()

            // Language selector
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                Text(localization["onboarding_language"])
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)

                Picker("", selection: $profile.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: profile.language) { newValue in
                    HapticsManager.shared.selection()
                    localization.setLanguage(newValue)
                }
            }
            .padding(.horizontal, AppTheme.spacingL)

            Button(action: {
                HapticsManager.shared.lightImpact()
                goToNext()
            }) {
                Text(localization["continue"])
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppTheme.spacingL)
            .padding(.bottom, AppTheme.spacingXL)
        }
    }

    // MARK: - Auth Step

    private var authStep: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                Spacer(minLength: AppTheme.spacingXL)

                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.accent)

                VStack(spacing: AppTheme.spacingS) {
                    Text(localization["auth_title"])
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(localization["auth_subtitle"])
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppTheme.spacingL)

                // Sign Up / Sign In Toggle
                Picker("", selection: $isSignUp) {
                    Text(localization["auth_signup"]).tag(true)
                    Text(localization["auth_signin"]).tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.spacingL)
                .onChange(of: isSignUp) { _ in
                    HapticsManager.shared.selection()
                }

                // Email & Password Fields
                VStack(spacing: AppTheme.spacingM) {
                    TextField(localization["auth_email"], text: $email)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField(localization["auth_password"], text: $password)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(isSignUp ? .newPassword : .password)
                }
                .padding(.horizontal, AppTheme.spacingL)

                // Error message
                if let error = authService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppTheme.error)
                        .padding(.horizontal, AppTheme.spacingL)
                }

                // Auth Button
                Button(action: {
                    if isSignUp {
                        authService.signUpWithEmail(email: email, password: password, displayName: nil)
                    } else {
                        authService.signInWithEmail(email: email, password: password)
                    }
                }) {
                    HStack {
                        if authService.isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSignUp ? localization["auth_signup"] : localization["auth_signin"])
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: !authService.isLoading && !email.isEmpty && password.count >= 6))
                .disabled(authService.isLoading || email.isEmpty || password.count < 6)
                .padding(.horizontal, AppTheme.spacingL)

                // Google Sign In Button
                Button(action: {
                    // Always trigger a fresh Google sign-in
                    // The signInWithGoogle will handle sync after successful auth
                    authService.signInWithGoogle()
                }) {
                    HStack(spacing: AppTheme.spacingM) {
                        Image("GoogleLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text(localization["auth_google"])
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacingM)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                .padding(.horizontal, AppTheme.spacingL)

                // Divider
                HStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    Text(localization["auth_or"])
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, AppTheme.spacingL)

                // Skip Button
                Button(action: {
                    HapticsManager.shared.lightImpact()
                    authService.signInAnonymously()
                    goToNext()
                }) {
                    Text(localization["auth_skip"])
                        .font(.subheadline)
                        .foregroundColor(AppTheme.accent)
                }

                Spacer(minLength: AppTheme.spacingL)

                Button(action: {
                    HapticsManager.shared.lightImpact()
                    goToPrevious()
                }) {
                    Text(localization["back"])
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.bottom, AppTheme.spacingXL)
            }
        }
    }

    // MARK: - Basic Info Step

    private var basicInfoStep: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                Text(localization["settings_profile"])
                    .font(.title.bold())
                    .padding(.top, AppTheme.spacingL)

                VStack(spacing: AppTheme.spacingM) {
                    // Name
                    FormField(title: localization["onboarding_name"]) {
                        TextField(localization["onboarding_name"], text: $profile.name)
                            .textFieldStyle(CustomTextFieldStyle())
                            .onChange(of: profile.name) { _ in
                                HapticsManager.shared.selection()
                            }
                    }

                    // Age
                    FormField(title: localization["onboarding_age"]) {
                        TextField("", text: Binding(
                            get: { "\(profile.age)" },
                            set: { newValue in
                                if let age = Int(newValue) {
                                    profile.age = min(max(age, 16), 80)
                                }
                            }
                        ))
                        .textFieldStyle(CustomTextFieldStyle())
                        .keyboardType(.numberPad)
                        .onChange(of: profile.age) { _ in
                            HapticsManager.shared.selection()
                        }
                    }

                    // Weight
                    FormField(title: localization["onboarding_weight"]) {
                        HStack {
                            Slider(value: $profile.weightKg, in: 40...150, step: 0.5)
                                .onChange(of: profile.weightKg) { _ in
                                    HapticsManager.shared.selection()
                                }
                            Button(action: {
                                weightInputText = String(format: "%.1f", profile.weightKg)
                                showWeightInput = true
                            }) {
                                Text(String(format: "%.1f kg", profile.weightKg))
                                    .font(.headline)
                                    .foregroundColor(AppTheme.accent)
                                    .frame(width: 80)
                            }
                        }
                    }

                    // Height
                    FormField(title: localization["onboarding_height"]) {
                        HStack {
                            Slider(value: $profile.heightCm, in: 140...220, step: 1)
                                .onChange(of: profile.heightCm) { _ in
                                    HapticsManager.shared.selection()
                                }
                            Button(action: {
                                heightInputText = String(format: "%.0f", profile.heightCm)
                                showHeightInput = true
                            }) {
                                Text(String(format: "%.0f cm", profile.heightCm))
                                    .font(.headline)
                                    .foregroundColor(AppTheme.accent)
                                    .frame(width: 80)
                            }
                        }
                    }

                    // Sex
                    FormField(title: localization["onboarding_sex"]) {
                        Picker("", selection: $profile.sex) {
                            ForEach(Sex.allCases, id: \.self) { sex in
                                Text(localization[sex.localizedKey]).tag(sex)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: profile.sex) { _ in
                            HapticsManager.shared.selection()
                        }
                    }
                }
                .padding(.horizontal, AppTheme.spacingL)

                navigationButtons
            }
        }
    }

    // MARK: - Goals Info Step

    private var goalsInfoStep: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                Spacer(minLength: AppTheme.spacingXL)

                Image(systemName: "target")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.accent)

                VStack(spacing: AppTheme.spacingS) {
                    Text(localization["onboarding_goal_title"])
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(localization["onboarding_goal_subtitle"])
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppTheme.spacingL)

                VStack(spacing: AppTheme.spacingM) {
                    ForEach(FitnessGoal.allCases, id: \.self) { goal in
                        GoalCard(
                            goal: goal,
                            isSelected: profile.fitnessGoal == goal,
                            localization: localization
                        ) {
                            HapticsManager.shared.mediumImpact()
                            profile.fitnessGoal = goal
                        }
                    }
                }
                .padding(.horizontal, AppTheme.spacingL)

                navigationButtons
            }
        }
    }

    // MARK: - Dietary Regime Step

    private var dietaryRegimeStep: some View {
        VStack(spacing: AppTheme.spacingL) {
            Spacer()

            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.accent)

            VStack(spacing: AppTheme.spacingS) {
                Text(localization["onboarding_regime_title"])
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(localization["onboarding_regime_subtitle"])
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppTheme.spacingL)

            // Dietary regime selection - vertical list
            VStack(spacing: AppTheme.spacingS) {
                ForEach(DietaryRegime.allCases, id: \.self) { regime in
                    DietaryRegimeRow(
                        regime: regime,
                        isSelected: profile.dietaryRegime == regime,
                        localization: localization
                    ) {
                        HapticsManager.shared.mediumImpact()
                        profile.dietaryRegime = regime
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingL)

            Spacer()

            navigationButtons
        }
    }

    // MARK: - Dietary Allergies Step

    private var dietaryAllergiesStep: some View {
        VStack(spacing: AppTheme.spacingL) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            VStack(spacing: AppTheme.spacingS) {
                Text(localization["onboarding_allergies_title"])
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(localization["onboarding_allergies_subtitle"])
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppTheme.spacingL)

            // Allergies grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.spacingS) {
                ForEach(FoodAllergy.allCases, id: \.self) { allergy in
                    AllergyChip(
                        allergy: allergy,
                        isSelected: profile.foodAllergies.contains(allergy),
                        localization: localization
                    ) {
                        HapticsManager.shared.selection()
                        if let index = profile.foodAllergies.firstIndex(of: allergy) {
                            profile.foodAllergies.remove(at: index)
                        } else {
                            profile.foodAllergies.append(allergy)
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingL)

            Spacer()

            navigationButtons
        }
    }

    // MARK: - Dietary Dislikes Step

    private var dietaryDislikesStep: some View {
        VStack(spacing: AppTheme.spacingL) {
            Spacer()

            Image(systemName: "hand.thumbsdown.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            VStack(spacing: AppTheme.spacingS) {
                Text(localization["onboarding_dislikes_title"])
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(localization["onboarding_dislikes_subtitle"])
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppTheme.spacingL)

            // Dislikes grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.spacingS) {
                ForEach(FoodDislike.allCases, id: \.self) { dislike in
                    DislikeChip(
                        dislike: dislike,
                        isSelected: profile.foodDislikes.contains(dislike),
                        localization: localization
                    ) {
                        HapticsManager.shared.selection()
                        if let index = profile.foodDislikes.firstIndex(of: dislike) {
                            profile.foodDislikes.remove(at: index)
                        } else {
                            profile.foodDislikes.append(dislike)
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingL)

            Spacer()

            navigationButtons
        }
    }

    // MARK: - Fitness Info Step

    private var fitnessInfoStep: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                Text(localization["onboarding_equipment"])
                    .font(.title.bold())
                    .padding(.top, AppTheme.spacingL)

                VStack(spacing: AppTheme.spacingM) {
                    // Equipment
                    FormField(title: localization["onboarding_equipment"]) {
                        HStack(spacing: AppTheme.spacingM) {
                            ForEach(Equipment.allCases, id: \.self) { equip in
                                EquipmentCard(
                                    equipment: equip,
                                    isSelected: profile.equipment == equip,
                                    localization: localization
                                ) {
                                    HapticsManager.shared.mediumImpact()
                                    profile.equipment = equip
                                }
                            }
                        }
                    }

                    // Sessions per week
                    FormField(title: localization["onboarding_sessions"]) {
                        VStack(spacing: AppTheme.spacingS) {
                            Slider(value: Binding(
                                get: { Double(profile.sessionsPerWeek) },
                                set: { profile.sessionsPerWeek = Int($0) }
                            ), in: 3...6, step: 1)
                            .onChange(of: profile.sessionsPerWeek) { _ in
                                HapticsManager.shared.selection()
                            }

                            HStack {
                                ForEach(3...6, id: \.self) { num in
                                    Text("\(num)")
                                        .font(profile.sessionsPerWeek == num ? .headline.bold() : .subheadline)
                                        .foregroundColor(profile.sessionsPerWeek == num ? AppTheme.accent : AppTheme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.spacingL)

                navigationButtons
            }
        }
    }

    // MARK: - Notifications Step

    private var preferredWorkoutTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = profile.preferredWorkoutHour
                components.minute = profile.preferredWorkoutMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                profile.preferredWorkoutHour = components.hour ?? 18
                profile.preferredWorkoutMinute = components.minute ?? 0
            }
        )
    }

    private var notificationsStep: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                Spacer(minLength: AppTheme.spacingXL)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.accent)

                VStack(spacing: AppTheme.spacingM) {
                    Text(localization["onboarding_notifications"])
                        .font(.title.bold())

                    Text(localization["onboarding_notifications_desc"])
                        .font(.body)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppTheme.spacingL)

                // Preferred workout time picker
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    Label(localization["settings_workout_time"], systemImage: "clock.fill")
                        .font(.headline)

                    DatePicker(
                        "",
                        selection: preferredWorkoutTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .onChange(of: profile.preferredWorkoutHour) { _ in
                        HapticsManager.shared.selection()
                    }
                }
                .padding(AppTheme.spacingM)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(AppTheme.cornerRadiusMedium)
                .padding(.horizontal, AppTheme.spacingL)

                // Notifications toggle
                Toggle(isOn: $profile.notificationsEnabled) {
                    Label(localization["settings_notifications_enabled"], systemImage: "bell.badge")
                        .font(.headline)
                }
                .onChange(of: profile.notificationsEnabled) { _ in
                    HapticsManager.shared.selection()
                }
                .padding(.horizontal, AppTheme.spacingL)
                .padding(.vertical, AppTheme.spacingM)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(AppTheme.cornerRadiusMedium)
                .padding(.horizontal, AppTheme.spacingL)

                Spacer(minLength: AppTheme.spacingXL)

                Button(action: {
                    HapticsManager.shared.mediumImpact()
                    showDisclaimer = true
                }) {
                    Text(localization["onboarding_create_profile"])
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppTheme.spacingL)

                Button(action: {
                    HapticsManager.shared.lightImpact()
                    goToPrevious()
                }) {
                    Text(localization["back"])
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.bottom, AppTheme.spacingXL)
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: AppTheme.spacingM) {
            if currentStep != .welcome && currentStep != .auth {
                Button(action: {
                    HapticsManager.shared.lightImpact()
                    goToPrevious()
                }) {
                    Text(localization["back"])
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Button(action: {
                HapticsManager.shared.lightImpact()
                goToNext()
            }) {
                Text(localization["next"])
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, AppTheme.spacingL)
        .padding(.bottom, AppTheme.spacingXL)
    }

    // MARK: - Disclaimer Sheet

    private var disclaimerSheet: some View {
        NavigationView {
            VStack(spacing: AppTheme.spacingL) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.accent)
                    .padding(.top, AppTheme.spacingXL)

                Text(localization["onboarding_disclaimer_title"])
                    .font(.title.bold())

                Text(localization["onboarding_disclaimer_text"])
                    .font(.body)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.spacingL)

                Spacer()

                Button(action: {
                    HapticsManager.shared.success()
                    completeOnboarding()
                }) {
                    Text(localization["onboarding_accept_disclaimer"])
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppTheme.spacingL)
                .padding(.bottom, AppTheme.spacingXL)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localization["cancel"]) {
                        HapticsManager.shared.lightImpact()
                        showDisclaimer = false
                    }
                }
            }
        }
    }

    // MARK: - Navigation Logic

    private func goToNext() {
        if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            withAnimation(AppTheme.springAnimation) {
                currentStep = nextStep
            }
        }
    }

    private func goToPrevious() {
        if let prevStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
            withAnimation(AppTheme.springAnimation) {
                currentStep = prevStep
            }
        }
    }

    private func completeOnboarding() {
        profile.hasAcceptedDisclaimer = true
        profile.createdAt = Date()

        // Link auth user info if available
        if let authUser = authService.currentUser {
            if let displayName = authUser.displayName, profile.name.isEmpty {
                profile.name = displayName
            }
        }

        dataStore.saveProfile(profile)

        if profile.notificationsEnabled {
            NotificationManager.shared.requestPermission { granted in
                if granted {
                    // Schedule daily workout reminder at preferred time
                    NotificationManager.shared.scheduleDailyWorkoutReminder(
                        profile: profile,
                        localization: localization
                    )
                    // Schedule Sunday evening reminder for next week's program
                    NotificationManager.shared.scheduleWeeklyProgramReminder(
                        localization: localization
                    )
                }
            }
        }

        showDisclaimer = false
    }
}

// MARK: - Supporting Views

struct FormField<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            content()
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(AppTheme.spacingM)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(AppTheme.cornerRadiusSmall)
    }
}

struct EquipmentCard: View {
    let equipment: Equipment
    let isSelected: Bool
    let localization: LocalizationManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.spacingS) {
                Image(systemName: equipment == .dumbbells ? "dumbbell.fill" : "figure.walk")
                    .font(.system(size: 30))

                Text(localization[equipment.localizedKey])
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.spacingL)
            .background(isSelected ? AppTheme.accent.opacity(0.2) : AppTheme.backgroundSecondary)
            .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textPrimary)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct GoalCard: View {
    let goal: FitnessGoal
    let isSelected: Bool
    let localization: LocalizationManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingM) {
                Image(systemName: goal.icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    Text(localization[goal.localizedKey])
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    Text(localization["\(goal.localizedKey)_desc"])
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.accent)
                }
            }
            .padding(AppTheme.spacingM)
            .background(isSelected ? AppTheme.accent.opacity(0.1) : AppTheme.backgroundSecondary)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct DietaryRegimeRow: View {
    let regime: DietaryRegime
    let isSelected: Bool
    let localization: LocalizationManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingM) {
                Image(systemName: regime.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                    .frame(width: 32)

                Text(localization[regime.localizedKey])
                    .font(.body)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.accent)
                }
            }
            .padding(AppTheme.spacingM)
            .background(isSelected ? AppTheme.accent.opacity(0.15) : AppTheme.backgroundSecondary)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct AllergyChip: View {
    let allergy: FoodAllergy
    let isSelected: Bool
    let localization: LocalizationManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingXS) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .red : AppTheme.textSecondary)

                Text(localization[allergy.localizedKey])
                    .font(.subheadline)
                    .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.vertical, AppTheme.spacingS)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.red.opacity(0.15) : AppTheme.backgroundSecondary)
            .cornerRadius(AppTheme.cornerRadiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .stroke(isSelected ? Color.red : Color.clear, lineWidth: 1)
            )
        }
    }
}

struct DislikeChip: View {
    let dislike: FoodDislike
    let isSelected: Bool
    let localization: LocalizationManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingXS) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .orange : AppTheme.textSecondary)

                Text(localization[dislike.localizedKey])
                    .font(.subheadline)
                    .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.vertical, AppTheme.spacingS)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.orange.opacity(0.15) : AppTheme.backgroundSecondary)
            .cornerRadius(AppTheme.cornerRadiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 1)
            )
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(DataStore.shared)
        .environmentObject(LocalizationManager.shared)
}
