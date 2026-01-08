import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FirestoreService: ObservableObject {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()

    @Published var isSyncing = false
    @Published var lastSyncError: String?

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    private var isAnonymous: Bool {
        Auth.auth().currentUser?.isAnonymous ?? true
    }

    // MARK: - User Document Reference

    private func userDocument() -> DocumentReference? {
        guard let userId = userId else { return nil }
        return db.collection("users").document(userId)
    }

    // MARK: - Save All Data

    func saveAppData(_ appData: AppData) async {
        // Don't sync for anonymous users
        guard !isAnonymous, let userDoc = userDocument() else { return }

        isSyncing = true
        lastSyncError = nil

        do {
            let encoder = Firestore.Encoder()
            let data = try encoder.encode(appData)
            try await userDoc.setData(data, merge: true)
            print("Data synced to Firestore")
        } catch {
            lastSyncError = error.localizedDescription
            print("Firestore save error: \(error)")
        }

        isSyncing = false
    }

    // MARK: - Load All Data

    func loadAppData() async -> AppData? {
        // Don't load for anonymous users
        guard !isAnonymous else {
            print("FirestoreService: Skipping load - anonymous user")
            return nil
        }

        guard let userDoc = userDocument() else {
            print("FirestoreService: Skipping load - no user document")
            return nil
        }

        isSyncing = true
        lastSyncError = nil
        print("FirestoreService: Loading data for user \(userId ?? "unknown")...")

        do {
            let snapshot = try await userDoc.getDocument()

            guard snapshot.exists else {
                print("FirestoreService: No document exists for this user")
                isSyncing = false
                return nil
            }

            guard let data = snapshot.data() else {
                print("FirestoreService: Document exists but no data")
                isSyncing = false
                return nil
            }

            let decoder = Firestore.Decoder()
            let appData = try decoder.decode(AppData.self, from: data)
            print("FirestoreService: Data loaded successfully! Profile: \(appData.profile?.name ?? "nil")")
            isSyncing = false
            return appData
        } catch {
            lastSyncError = error.localizedDescription
            print("FirestoreService: Load error: \(error)")
            isSyncing = false
            return nil
        }
    }

    // MARK: - Check if User Has Cloud Data

    func hasCloudData() async -> Bool {
        guard !isAnonymous, let userDoc = userDocument() else { return false }

        do {
            let snapshot = try await userDoc.getDocument()
            return snapshot.exists
        } catch {
            return false
        }
    }

    // MARK: - Delete User Data

    func deleteUserData() async {
        guard let userDoc = userDocument() else { return }

        do {
            try await userDoc.delete()
            print("User data deleted from Firestore")
        } catch {
            print("Firestore delete error: \(error)")
        }
    }

    // MARK: - Save Profile Only (for quick updates)

    func saveProfile(_ profile: UserProfile) async {
        guard !isAnonymous, let userDoc = userDocument() else { return }

        do {
            let encoder = Firestore.Encoder()
            let profileData = try encoder.encode(profile)
            try await userDoc.setData(["profile": profileData], merge: true)
        } catch {
            print("Firestore profile save error: \(error)")
        }
    }

    // MARK: - Usage Quotas

    func saveUsageData(_ usageData: UsageData) async {
        guard !isAnonymous, let userDoc = userDocument() else { return }

        do {
            let encoder = Firestore.Encoder()
            let data = try encoder.encode(usageData)
            try await userDoc.setData(["usageData": data], merge: true)
            print("Usage data synced to Firestore")
        } catch {
            print("Firestore usage save error: \(error)")
        }
    }

    func loadUsageData() async -> UsageData? {
        guard !isAnonymous, let userDoc = userDocument() else {
            print("FirestoreService: Cannot load usage - anonymous or no user")
            return nil
        }

        do {
            let snapshot = try await userDoc.getDocument()
            guard let data = snapshot.data() else {
                print("FirestoreService: No document data for usage")
                return nil
            }

            // Try to get usageData field
            guard let usageDict = data["usageData"] as? [String: Any] else {
                print("FirestoreService: No usageData field found in document")
                return nil
            }

            let decoder = Firestore.Decoder()
            var usageData = try decoder.decode(UsageData.self, from: usageDict)
            usageData.resetIfNewMonth()
            print("FirestoreService: Usage loaded - workouts=\(usageData.workoutGenerationsThisMonth), meals=\(usageData.mealGenerationsThisMonth)")
            return usageData
        } catch {
            print("FirestoreService: Usage load error: \(error)")
            return nil
        }
    }
}
