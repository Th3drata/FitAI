import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var shouldNavigateToWorkout = false

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let action = userInfo["action"] as? String, action == "openWorkout" {
            DispatchQueue.main.async {
                self.shouldNavigateToWorkout = true
            }
        }

        completionHandler()
    }

    // Show notification even when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - Authorization

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                completion(granted)
            }
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Workout Reminders

    func scheduleWorkoutReminder(workout: Workout, minutesBefore: Int, localization: LocalizationManager) {
        guard let scheduledDate = workout.scheduledDate else { return }

        let title = localization["app_name"]
        let body = "\(localization["home_today_workout"]): \(localization[workout.titleKey])"

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1

        // Calculate trigger time
        let reminderDate = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: scheduledDate)!
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "workout-\(workout.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    func scheduleAllWorkoutReminders(weekProgram: WeekProgram, profile: UserProfile, localization: LocalizationManager) {
        guard profile.notificationsEnabled else { return }

        // Clear existing workout notifications
        cancelAllWorkoutReminders()

        // Schedule new ones
        for workout in weekProgram.workouts {
            scheduleWorkoutReminder(
                workout: workout,
                minutesBefore: profile.reminderMinutesBefore,
                localization: localization
            )
        }
    }

    func cancelAllWorkoutReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let workoutIds = requests
                .filter { $0.identifier.hasPrefix("workout-") }
                .map { $0.identifier }

            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: workoutIds)
        }
    }

    func cancelWorkoutReminder(workoutId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["workout-\(workoutId.uuidString)"]
        )
    }

    // MARK: - Daily Workout Reminder at Preferred Time

    func scheduleDailyWorkoutReminder(profile: UserProfile, localization: LocalizationManager) {
        guard profile.notificationsEnabled else {
            cancelDailyWorkoutReminder()
            return
        }

        let title = localization["app_name"]
        let body = localization["notification_workout_time"]

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1

        // Add deep link info to open workout page
        content.userInfo = ["action": "openWorkout"]

        var dateComponents = DateComponents()
        dateComponents.hour = profile.preferredWorkoutHour
        dateComponents.minute = profile.preferredWorkoutMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily-workout-reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule daily workout reminder: \(error)")
            } else {
                print("Daily workout reminder scheduled at \(profile.preferredWorkoutHour):\(String(format: "%02d", profile.preferredWorkoutMinute))")
            }
        }
    }

    func cancelDailyWorkoutReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-workout-reminder"])
    }

    // MARK: - Daily Reminders (Legacy)

    func scheduleDailyReminder(hour: Int, minute: Int, localization: LocalizationManager) {
        let title = localization["app_name"]
        let body = localization["assistant_tips"]

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily-reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule daily reminder: \(error)")
            }
        }
    }

    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])
    }

    // MARK: - Weekly Summary & Program Reminder

    func scheduleWeeklyProgramReminder(localization: LocalizationManager) {
        let title = localization["app_name"]
        let body = localization["notification_weekly_summary"]

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        content.userInfo = ["action": "showWeeklySummary"]

        // Schedule for Sunday at 18:00 (6 PM) - matches shouldShowWeeklySummary()
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 18
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "weekly-program-reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule weekly program reminder: \(error)")
            } else {
                print("Weekly summary reminder scheduled for Sunday 18:00")
            }
        }
    }

    func cancelWeeklyProgramReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weekly-program-reminder"])
    }

    // MARK: - Weight Tracking Reminder

    func scheduleWeeklyWeightReminder(dayOfWeek: Int, hour: Int, localization: LocalizationManager) {
        let title = localization["app_name"]
        let body = localization["tracking_add_weight"]

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = dayOfWeek // 1 = Sunday, 2 = Monday, etc.
        dateComponents.hour = hour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "weight-reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule weight reminder: \(error)")
            }
        }
    }

    // MARK: - Clear All

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    // MARK: - Debug

    func listPendingNotifications() {
        // Longer delay to let async add() complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("📱 NOTIFICATIONS PLANIFIÉES: \(requests.count)")
                for request in requests {
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                        let components = trigger.dateComponents
                        let hour = components.hour ?? 0
                        let minute = components.minute ?? 0
                        let time = "\(hour):\(String(format: "%02d", minute))"
                        if let weekday = components.weekday {
                            let dayName = ["", "Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam"][weekday]
                            print("   \(request.identifier): \(dayName) à \(time)")
                        } else {
                            print("   \(request.identifier): tous les jours à \(time)")
                        }
                    }
                }
                if requests.isEmpty {
                    print("   ⚠️ Aucune notification planifiée!")
                }
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            }
        }
    }
}
