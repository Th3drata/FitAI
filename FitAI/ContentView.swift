import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var localization: LocalizationManager
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Group {
            if dataStore.isSyncingFromCloud {
                // Show loading while syncing from cloud
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(localization["loading"])
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.backgroundPrimary)
            } else if dataStore.hasProfile {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(AppTheme.springAnimation, value: dataStore.hasProfile)
        .animation(AppTheme.springAnimation, value: dataStore.isSyncingFromCloud)
        // Force re-render when theme changes
        .id(themeManager.accentColor.rawValue)
    }
}

struct MainTabView: View {
    @EnvironmentObject var localization: LocalizationManager
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var selectedTab = 0
    @State private var showTodayWorkout = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(localization["tab_home"], systemImage: "house.fill")
                }
                .tag(0)

            WorkoutsListView()
                .tabItem {
                    Label(localization["tab_workouts"], systemImage: "dumbbell.fill")
                }
                .tag(1)

            MealsView()
                .tabItem {
                    Label(localization["tab_meals"], systemImage: "fork.knife")
                }
                .tag(2)

            AssistantView()
                .tabItem {
                    Label(localization["tab_assistant"], systemImage: "sparkles")
                }
                .tag(3)

            TrackingView()
                .tabItem {
                    Label(localization["tab_tracking"], systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(4)

            SettingsView()
                .tabItem {
                    Label(localization["tab_settings"], systemImage: "gearshape.fill")
                }
                .tag(5)
        }
        .tint(AppTheme.accent)
        .fullScreenCover(isPresented: $showTodayWorkout) {
            if let todayWorkout = dataStore.getTodayWorkout() {
                ActiveWorkoutView(workout: todayWorkout)
                    .environmentObject(dataStore)
                    .environmentObject(localization)
            }
        }
        .onReceive(notificationManager.$shouldNavigateToWorkout) { shouldNavigate in
            if shouldNavigate {
                // Navigate to workouts tab and open today's workout
                selectedTab = 1
                if dataStore.getTodayWorkout() != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showTodayWorkout = true
                    }
                }
                notificationManager.shouldNavigateToWorkout = false
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataStore.shared)
        .environmentObject(LocalizationManager.shared)
        .environmentObject(ThemeManager.shared)
}
