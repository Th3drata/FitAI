import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var localization: LocalizationManager
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var showResetAlert = false
    @State private var showDisclaimer = false
    @State private var showEditProfile = false
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var isDeleting = false
    @State private var showPaywall = false


    var body: some View {
        NavigationView {
            Form {
                // Subscription section
                subscriptionSection

                // Account section
                accountSection

                // Profile section
                profileSection

                // Appearance section
                appearanceSection

                // Notifications section
                notificationsSection

                // Dietary preferences section
                dietarySection

                // Language section
                languageSection

                // About section
                aboutSection

                // Danger zone
                dangerZone

                #if DEBUG
                // Debug section (only in debug builds)
                debugSection
                #endif
            }
            .navigationTitle(localization["settings_title"])
            .alert(localization["settings_reset"], isPresented: $showResetAlert) {
                Button(localization["cancel"], role: .cancel) {}
                Button(localization["delete"], role: .destructive) {
                    resetApp()
                }
            } message: {
                Text(localization["settings_reset_confirm"])
            }
            .sheet(isPresented: $showDisclaimer) {
                disclaimerSheet
            }
            .sheet(isPresented: $showEditProfile) {
                editProfileSheet
            }
            .alert(localization["auth_sign_out"], isPresented: $showSignOutAlert) {
                Button(localization["cancel"], role: .cancel) {}
                Button(localization["auth_sign_out"], role: .destructive) {
                    signOut()
                }
            } message: {
                Text(localization["auth_sign_out_confirm"])
            }
            .alert(localization["auth_delete_account"], isPresented: $showDeleteAccountAlert) {
                Button(localization["cancel"], role: .cancel) {}
                Button(localization["delete"], role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text(localization["auth_delete_confirm"])
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(localization)
            }
        }
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        Section(header: Text(localization["settings_subscription"])) {
            if subscriptionManager.isPremium {
                // Premium user
                HStack {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [themeManager.primaryColor, themeManager.primaryColor.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: "crown.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization["premium_title"])
                            .font(.headline)
                        Text(localization["settings_premium_active"])
                            .font(.caption)
                            .foregroundColor(AppTheme.success)
                    }

                    Spacer()

                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(AppTheme.success)
                }

                Button(action: {
                    // Open subscription management in App Store
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Label(localization["settings_manage_subscription"], systemImage: "gear")
                }
                .foregroundColor(themeManager.primaryColor)
            } else {
                // Free user
                HStack {
                    ZStack {
                        Circle()
                            .fill(AppTheme.backgroundSecondary)
                            .frame(width: 44, height: 44)

                        Image(systemName: "person.fill")
                            .font(.title3)
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization["settings_free_plan"])
                            .font(.headline)
                        Text(localization["settings_free_limits"])
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()
                }

                // Usage stats
                VStack(spacing: AppTheme.spacingS) {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundColor(themeManager.primaryColor)
                            .frame(width: 24)
                        Text(localization["settings_workouts_remaining"])
                        Spacer()
                        Text("\(subscriptionManager.remainingWorkoutGenerations)/\(UsageLimits.freeWorkoutGenerationsPerMonth)")
                            .foregroundColor(subscriptionManager.canGenerateWorkout ? AppTheme.textSecondary : AppTheme.warning)
                            .bold()
                    }
                    .font(.subheadline)

                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Text(localization["settings_meals_remaining"])
                        Spacer()
                        Text("\(subscriptionManager.remainingMealGenerations)/\(UsageLimits.freeMealGenerationsPerMonth)")
                            .foregroundColor(subscriptionManager.canGenerateMeal ? AppTheme.textSecondary : AppTheme.warning)
                            .bold()
                    }
                    .font(.subheadline)
                }
                .padding(.vertical, AppTheme.spacingXS)

                // Upgrade button
                Button(action: {
                    HapticsManager.shared.impact(.medium)
                    showPaywall = true
                }) {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text(localization["premium_upgrade"])
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacingS)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.primaryColor)
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section(header: Text(localization["settings_account"])) {
            if authService.isAuthenticated {
                if let user = authService.currentUser {
                    let isAnonymous = user.provider == .anonymous
                    HStack {
                        Image(systemName: isAnonymous ? "person.crop.circle.badge.questionmark" : "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundColor(themeManager.primaryColor)

                        VStack(alignment: .leading, spacing: 2) {
                            if isAnonymous {
                                Text(localization["auth_anonymous"])
                                    .font(.headline)
                            } else {
                                Text(user.email ?? "")
                                    .font(.headline)
                                Text(localization["auth_logged_in_as"])
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }

                        Spacer()
                    }
                }

                Button(action: {
                    HapticsManager.shared.impact(.medium)
                    showSignOutAlert = true
                }) {
                    Label(localization["auth_sign_out"], systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(AppTheme.warning)
                }

                // Delete account button (only for non-anonymous users)
                if authService.currentUser?.provider != .anonymous {
                    Button(action: {
                        HapticsManager.shared.impact(.heavy)
                        showDeleteAccountAlert = true
                    }) {
                        if isDeleting {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(localization["loading"])
                            }
                        } else {
                            Label(localization["auth_delete_account"], systemImage: "trash.circle.fill")
                        }
                    }
                    .foregroundColor(AppTheme.error)
                    .disabled(isDeleting)
                }
            } else {
                Text(localization["auth_not_logged_in"])
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section(header: Text(localization["settings_profile"])) {
            if let profile = dataStore.profile {
                HStack {
                    VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                        Text(profile.name.isEmpty ? "FitAI User" : profile.name)
                            .font(.headline)

                        HStack(spacing: AppTheme.spacingM) {
                            Text("\(profile.age) ans")
                            Text("•")
                            Text(String(format: "%.1f kg", profile.weightKg))
                            Text("•")
                            Text(String(format: "%.0f cm", profile.heightCm))
                        }
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    Button(action: { showEditProfile = true }) {
                        Text(localization["edit"])
                            .font(.subheadline)
                            .foregroundColor(themeManager.primaryColor)
                    }
                }

                HStack {
                    Image(systemName: profile.equipment == .dumbbells ? "dumbbell.fill" : "figure.walk")
                    Text(localization[profile.equipment.localizedKey])
                    Spacer()
                    Text("\(profile.sessionsPerWeek) \(localization["onboarding_sessions"])")
                        .foregroundColor(AppTheme.textSecondary)
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section(header: Text(localization["settings_appearance"])) {
            // Theme mode picker
            HStack {
                Label(localization["settings_theme"], systemImage: "circle.lefthalf.filled")
                Spacer()
                Picker("", selection: $themeManager.themeMode) {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: mode.icon)
                            Text(localization[mode.localizedKey])
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }

            // Accent color picker
            VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                Label(localization["settings_accent_color"], systemImage: "paintpalette")

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: AppTheme.spacingM) {
                    ForEach(AccentColorOption.allCases, id: \.self) { colorOption in
                        Button(action: {
                            HapticsManager.shared.selection()
                            themeManager.accentColor = colorOption
                        }) {
                            VStack(spacing: AppTheme.spacingXS) {
                                Circle()
                                    .fill(colorOption.color)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(themeManager.accentColor == colorOption ? Color.primary : Color.clear, lineWidth: 3)
                                    )
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                            .opacity(themeManager.accentColor == colorOption ? 1 : 0)
                                    )

                                Text(localization[colorOption.localizedKey])
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, AppTheme.spacingS)
            }
        }
    }

    // MARK: - Notifications Section

    private var preferredWorkoutTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = dataStore.profile?.preferredWorkoutHour ?? 18
                components.minute = dataStore.profile?.preferredWorkoutMinute ?? 0
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                if var profile = dataStore.profile {
                    profile.preferredWorkoutHour = components.hour ?? 18
                    profile.preferredWorkoutMinute = components.minute ?? 0
                    dataStore.saveProfile(profile)
                    // Reschedule notification with new time
                    if profile.notificationsEnabled {
                        NotificationManager.shared.scheduleDailyWorkoutReminder(
                            profile: profile,
                            localization: localization
                        )
                    }
                }
            }
        )
    }

    private var notificationsSection: some View {
        Section(header: Text(localization["settings_notifications"])) {
            // Preferred workout time
            DatePicker(
                selection: preferredWorkoutTime,
                displayedComponents: .hourAndMinute
            ) {
                Label(localization["settings_workout_time"], systemImage: "clock.fill")
            }
            .onChange(of: dataStore.profile?.preferredWorkoutHour) { _ in
                HapticsManager.shared.selection()
            }

            // Notifications toggle
            Toggle(isOn: Binding(
                get: { dataStore.profile?.notificationsEnabled ?? false },
                set: { newValue in
                    if var profile = dataStore.profile {
                        profile.notificationsEnabled = newValue
                        dataStore.saveProfile(profile)

                        if newValue {
                            NotificationManager.shared.requestPermission { granted in
                                if granted {
                                    // Schedule notification at preferred time
                                    NotificationManager.shared.scheduleDailyWorkoutReminder(
                                        profile: profile,
                                        localization: localization
                                    )
                                    // Schedule Sunday evening reminder
                                    NotificationManager.shared.scheduleWeeklyProgramReminder(
                                        localization: localization
                                    )
                                } else {
                                    // Reset toggle if permission denied
                                    if var p = dataStore.profile {
                                        p.notificationsEnabled = false
                                        dataStore.saveProfile(p)
                                    }
                                }
                            }
                        } else {
                            NotificationManager.shared.cancelDailyWorkoutReminder()
                            NotificationManager.shared.cancelWeeklyProgramReminder()
                        }
                    }
                }
            )) {
                Label(localization["settings_notifications_enabled"], systemImage: "bell.badge")
            }
            .tint(themeManager.primaryColor)
        }
    }

    // MARK: - Dietary Section

    private var dietarySection: some View {
        Section(header: Text(localization["settings_dietary"])) {
            // Dietary regime picker
            Picker(selection: Binding(
                get: { dataStore.profile?.dietaryRegime ?? .standard },
                set: { newValue in
                    if var profile = dataStore.profile {
                        profile.dietaryRegime = newValue
                        dataStore.saveProfile(profile)
                        HapticsManager.shared.selection()
                    }
                }
            )) {
                ForEach(DietaryRegime.allCases, id: \.self) { regime in
                    HStack {
                        Image(systemName: regime.icon)
                        Text(localization[regime.localizedKey])
                    }
                    .tag(regime)
                }
            } label: {
                Label(localization["settings_dietary_regime"], systemImage: "fork.knife")
            }

            // Allergies
            NavigationLink {
                allergiesSelectionView
            } label: {
                HStack {
                    Label(localization["settings_allergies"], systemImage: "exclamationmark.triangle.fill")
                    Spacer()
                    if let allergies = dataStore.profile?.foodAllergies, !allergies.isEmpty {
                        Text("\(allergies.count)")
                            .foregroundColor(AppTheme.textSecondary)
                    } else {
                        Text(localization["settings_no_allergies"])
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }

            // Food dislikes
            NavigationLink {
                dislikesSelectionView
            } label: {
                HStack {
                    Label(localization["settings_dislikes"], systemImage: "hand.thumbsdown.fill")
                    Spacer()
                    if let dislikes = dataStore.profile?.foodDislikes, !dislikes.isEmpty {
                        Text("\(dislikes.count)")
                            .foregroundColor(AppTheme.textSecondary)
                    } else {
                        Text(localization["settings_no_dislikes"])
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var allergiesSelectionView: some View {
        List {
            ForEach(FoodAllergy.allCases, id: \.self) { allergy in
                Button {
                    toggleAllergy(allergy)
                } label: {
                    HStack {
                        Image(systemName: allergy.icon)
                            .foregroundColor(.red)
                            .frame(width: 24)
                        Text(localization[allergy.localizedKey])
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        if dataStore.profile?.foodAllergies.contains(allergy) == true {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(themeManager.primaryColor)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(localization["settings_allergies"])
    }

    private var dislikesSelectionView: some View {
        List {
            ForEach(FoodDislike.allCases, id: \.self) { dislike in
                Button {
                    toggleDislike(dislike)
                } label: {
                    HStack {
                        Text(localization[dislike.localizedKey])
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        if dataStore.profile?.foodDislikes.contains(dislike) == true {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(themeManager.primaryColor)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(localization["settings_dislikes"])
    }

    private func toggleAllergy(_ allergy: FoodAllergy) {
        guard var profile = dataStore.profile else { return }
        if let index = profile.foodAllergies.firstIndex(of: allergy) {
            profile.foodAllergies.remove(at: index)
        } else {
            profile.foodAllergies.append(allergy)
        }
        dataStore.saveProfile(profile)
        HapticsManager.shared.selection()
    }

    private func toggleDislike(_ dislike: FoodDislike) {
        guard var profile = dataStore.profile else { return }
        if let index = profile.foodDislikes.firstIndex(of: dislike) {
            profile.foodDislikes.remove(at: index)
        } else {
            profile.foodDislikes.append(dislike)
        }
        dataStore.saveProfile(profile)
        HapticsManager.shared.selection()
    }

    // MARK: - Language Section

    private var languageSection: some View {
        Section(header: Text(localization["settings_language"])) {
            Picker(selection: Binding(
                get: { dataStore.profile?.language ?? .french },
                set: { newValue in
                    localization.setLanguage(newValue)
                    if var profile = dataStore.profile {
                        profile.language = newValue
                        dataStore.saveProfile(profile)
                    }
                }
            )) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    HStack {
                        Text(lang == .french ? "🇫🇷" : "🇬🇧")
                        Text(lang.displayName)
                    }
                    .tag(lang)
                }
            } label: {
                Label(localization["settings_language"], systemImage: "globe")
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section(header: Text(localization["settings_about"])) {
            Button(action: { showDisclaimer = true }) {
                Label(localization["settings_disclaimer"], systemImage: "heart.text.square")
            }
            .foregroundColor(AppTheme.textPrimary)

            HStack {
                Label(localization["settings_version"], systemImage: "info.circle")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(AppTheme.textSecondary)
            }

            Button(action: exportAllData) {
                Label(localization["settings_export_data"], systemImage: "square.and.arrow.up")
            }
            .foregroundColor(AppTheme.textPrimary)
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        Section(header: Text(localization["settings_danger_zone"])) {
            Button(action: { showResetAlert = true }) {
                Label(localization["settings_reset"], systemImage: "trash")
                    .foregroundColor(AppTheme.error)
            }
        }
    }

    // MARK: - Debug Section

    #if DEBUG
    private var debugSection: some View {
        Section(header: Text("🛠 DEBUG")) {
            // Reset quotas
            Button(action: {
                HapticsManager.shared.notification(.success)
                subscriptionManager.resetQuotas()
            }) {
                HStack {
                    Label("Reset Quotas", systemImage: "arrow.counterclockwise")
                    Spacer()
                    Text("\(subscriptionManager.usageData.workoutGenerationsThisMonth)/\(UsageLimits.freeWorkoutGenerationsPerMonth) W • \(subscriptionManager.usageData.mealGenerationsThisMonth)/\(UsageLimits.freeMealGenerationsPerMonth) M")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .foregroundColor(.orange)

            // List pending notifications
            Button(action: {
                NotificationManager.shared.listPendingNotifications()
            }) {
                Label("Log Pending Notifications", systemImage: "bell.badge")
            }
            .foregroundColor(.blue)

            // Log quotas
            Button(action: {
                subscriptionManager.logCurrentQuotas()
            }) {
                Label("Log Quotas", systemImage: "chart.bar")
            }
            .foregroundColor(.green)
            
            // Add premium
            Button(action: {
                HapticsManager.shared.notification(.success)
                subscriptionManager.subscriptionStatus = .premium
                print("✅ Premium added - Status: \(subscriptionManager.subscriptionStatus.rawValue)")
            }) {
                Label("Add Premium", systemImage: "crown.fill")
            }
            .foregroundColor(.purple)
            
            // Remove premium
            Button(action: {
                HapticsManager.shared.notification(.warning)
                subscriptionManager.subscriptionStatus = .free
                print("❌ Premium removed - Status: \(subscriptionManager.subscriptionStatus.rawValue)")
            }) {
                Label("Remove Premium", systemImage: "crown")
            }
            .foregroundColor(.red)
        }
    }
    #endif

    // MARK: - Disclaimer Sheet

    private var disclaimerSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.accent)
                        .frame(maxWidth: .infinity)

                    Text(localization["onboarding_disclaimer_title"])
                        .font(.title.bold())

                    Text(localization["onboarding_disclaimer_text"])
                        .font(.body)
                        .foregroundColor(AppTheme.textSecondary)

                    Spacer()
                }
                .padding(AppTheme.spacingL)
            }
            .navigationTitle(localization["settings_disclaimer"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localization["close"]) {
                        showDisclaimer = false
                    }
                }
            }
        }
    }

    // MARK: - Edit Profile Sheet

    private var editProfileSheet: some View {
        NavigationView {
            Form {
                if var profile = dataStore.profile {
                    Section(header: Text(localization["settings_profile"])) {
                        TextField(localization["onboarding_name"], text: Binding(
                            get: { profile.name },
                            set: { profile.name = $0 }
                        ))

                        Stepper(value: Binding(
                            get: { profile.age },
                            set: { profile.age = $0 }
                        ), in: 16...80) {
                            HStack {
                                Text(localization["onboarding_age"])
                                Spacer()
                                Text("\(profile.age)")
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }

                        HStack {
                            Text(localization["onboarding_weight"])
                            Spacer()
                            Text(String(format: "%.1f kg", profile.weightKg))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Slider(value: Binding(
                            get: { profile.weightKg },
                            set: { profile.weightKg = $0 }
                        ), in: 40...150, step: 0.5)
                        .tint(themeManager.primaryColor)

                        HStack {
                            Text(localization["onboarding_height"])
                            Spacer()
                            Text(String(format: "%.0f cm", profile.heightCm))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Slider(value: Binding(
                            get: { profile.heightCm },
                            set: { profile.heightCm = $0 }
                        ), in: 140...220, step: 1)
                        .tint(themeManager.primaryColor)
                    }

                    Section(header: Text(localization["onboarding_equipment"])) {
                        Picker(localization["onboarding_equipment"], selection: Binding(
                            get: { profile.equipment },
                            set: { profile.equipment = $0 }
                        )) {
                            ForEach(Equipment.allCases, id: \.self) { equip in
                                Text(localization[equip.localizedKey]).tag(equip)
                            }
                        }
                        .pickerStyle(.segmented)

                        Stepper(value: Binding(
                            get: { profile.sessionsPerWeek },
                            set: { profile.sessionsPerWeek = $0 }
                        ), in: 3...6) {
                            HStack {
                                Text(localization["onboarding_sessions"])
                                Spacer()
                                Text("\(profile.sessionsPerWeek)")
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        
                        // Preferred workout days (optional)
                        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                            HStack {
                                Text(localization["settings_preferred_days"])
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("(\(localization["settings_optional"]))")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            if !profile.preferredWorkoutDays.isEmpty {
                                Text(localization["settings_preferred_days_desc"])
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: AppTheme.spacingS) {
                                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { weekday in
                                    let isSelected = profile.preferredWorkoutDays.contains(weekday)
                                    Button(action: {
                                        HapticsManager.shared.selection()
                                        if isSelected {
                                            profile.preferredWorkoutDays.remove(weekday)
                                        } else {
                                            profile.preferredWorkoutDays.insert(weekday)
                                        }
                                    }) {
                                        VStack(spacing: 2) {
                                            Text(weekdayShortName(weekday))
                                                .font(.caption2.bold())
                                                .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
                                        }
                                        .frame(height: 32)
                                        .frame(maxWidth: .infinity)
                                        .background(isSelected ? themeManager.primaryColor : AppTheme.backgroundSecondary)
                                        .cornerRadius(AppTheme.cornerRadiusSmall)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, AppTheme.spacingXS)
                    }
                }
            }
            .navigationTitle(localization["settings_profile"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localization["cancel"]) {
                        showEditProfile = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localization["save"]) {
                        if let profile = dataStore.profile {
                            dataStore.saveProfile(profile)
                        }
                        showEditProfile = false
                    }
                    .bold()
                }
            }
        }
    }

    // MARK: - Helpers
    
    private func weekdayShortName(_ weekday: Int) -> String {
        // 1=Sunday, 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday, 7=Saturday
        let weekdayKeys = [
            1: "day_sun",
            2: "day_mon",
            3: "day_tue",
            4: "day_wed",
            5: "day_thu",
            6: "day_fri",
            7: "day_sat"
        ]
        return localization[weekdayKeys[weekday] ?? ""]
    }

    // MARK: - Actions

    private func resetApp() {
        HapticsManager.shared.notification(.warning)
        NotificationManager.shared.clearAllNotifications()
        dataStore.reset()
    }

    private func signOut() {
        HapticsManager.shared.notification(.warning)
        authService.signOut()
        dataStore.reset()
    }

    private func deleteAccount() {
        isDeleting = true
        HapticsManager.shared.notification(.warning)

        Task {
            // Delete cloud data first
            await FirestoreService.shared.deleteUserData()

            // Delete the account
            await authService.deleteAccount()

            // Clear local notifications
            NotificationManager.shared.clearAllNotifications()

            // Reset local data and return to onboarding
            dataStore.reset()

            isDeleting = false
        }
    }

    private func exportAllData() {
        HapticsManager.shared.impact(.light)
        var exportText = "=== FitAI Export ===\n\n"

        // Profile
        if let profile = dataStore.profile {
            exportText += "== Profile ==\n"
            exportText += "Name: \(profile.name)\n"
            exportText += "Age: \(profile.age)\n"
            exportText += "Weight: \(profile.weightKg) kg\n"
            exportText += "Height: \(profile.heightCm) cm\n"
            exportText += "Equipment: \(profile.equipment.rawValue)\n"
            exportText += "Sessions/week: \(profile.sessionsPerWeek)\n\n"
        }

        // Weight entries
        exportText += "== Weight History ==\n"
        exportText += dataStore.exportWeightDataToCSV()
        exportText += "\n"

        // Session logs
        exportText += "== Session Logs ==\n"
        exportText += dataStore.exportSessionLogsToCSV()

        let activityVC = UIActivityViewController(
            activityItems: [exportText],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(DataStore.shared)
        .environmentObject(LocalizationManager.shared)
}
