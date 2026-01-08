import Foundation
import SwiftUI
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

@MainActor
class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()

    @Published var isAuthenticated = false
    @Published var currentUser: AuthUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userDefaultsKey = "fitai_auth_user"
    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        setupAuthStateListener()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - User Model

    struct AuthUser: Codable {
        var id: String
        var email: String?
        var displayName: String?
        var photoURL: String?
        var provider: AuthProvider
        var createdAt: Date
    }

    enum AuthProvider: String, Codable {
        case email
        case google
        case apple
        case anonymous
    }

    // MARK: - Auth State Listener

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    // Verify the user account still exists on Firebase
                    await self?.verifyUserAccount(user)
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }

    // MARK: - Verify User Account

    /// Verifies that the user account still exists on Firebase servers
    /// This handles cases where the account was deleted from Firebase console
    private func verifyUserAccount(_ user: User) async {
        do {
            // Force a token refresh to verify the account still exists
            try await user.reload()
            // Account is valid, update the current user
            updateCurrentUser(from: user)
        } catch {
            let nsError = error as NSError
            print("AuthService: User verification failed - \(error.localizedDescription)")

            // Check if the error indicates the user was deleted or disabled
            if nsError.code == AuthErrorCode.userNotFound.rawValue ||
               nsError.code == AuthErrorCode.userDisabled.rawValue ||
               nsError.code == AuthErrorCode.userTokenExpired.rawValue ||
               nsError.code == AuthErrorCode.invalidUserToken.rawValue {

                print("AuthService: User account no longer valid, signing out...")

                // Sign out and clear local data
                do {
                    try Auth.auth().signOut()
                } catch {
                    print("AuthService: Sign out error - \(error.localizedDescription)")
                }

                GIDSignIn.sharedInstance.signOut()
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
                currentUser = nil
                isAuthenticated = false

                // Reset local data since the account no longer exists
                DataStore.shared.reset()

                HapticsManager.shared.notification(.warning)
            } else {
                // Other errors (network, etc.) - keep the user logged in
                // but don't update (to avoid issues)
                print("AuthService: Non-critical error, keeping user state")
                updateCurrentUser(from: user)
            }
        }
    }

    private func updateCurrentUser(from firebaseUser: User) {
        let provider: AuthProvider
        if firebaseUser.isAnonymous {
            provider = .anonymous
        } else if firebaseUser.providerData.contains(where: { $0.providerID == "google.com" }) {
            provider = .google
        } else {
            provider = .email
        }

        let user = AuthUser(
            id: firebaseUser.uid,
            email: firebaseUser.email,
            displayName: firebaseUser.displayName,
            photoURL: firebaseUser.photoURL?.absoluteString,
            provider: provider,
            createdAt: firebaseUser.metadata.creationDate ?? Date()
        )

        currentUser = user
        isAuthenticated = true
        saveUserLocally(user)
    }

    private func saveUserLocally(_ user: AuthUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    // MARK: - Email/Password Sign In

    func signInWithEmail(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        HapticsManager.shared.impact(.light)

        Task {
            do {
                let result = try await Auth.auth().signIn(withEmail: email, password: password)
                updateCurrentUser(from: result.user)

                // Trigger cloud sync after successful sign-in
                await DataStore.shared.triggerSyncAfterSignIn()

                isLoading = false
                HapticsManager.shared.notification(.success)
            } catch {
                errorMessage = mapFirebaseError(error)
                isLoading = false
                HapticsManager.shared.notification(.error)
            }
        }
    }

    func signUpWithEmail(email: String, password: String, displayName: String?) {
        isLoading = true
        errorMessage = nil
        HapticsManager.shared.impact(.light)

        Task {
            do {
                let result = try await Auth.auth().createUser(withEmail: email, password: password)

                // Update display name if provided
                if let displayName = displayName {
                    let changeRequest = result.user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    try await changeRequest.commitChanges()
                }

                updateCurrentUser(from: result.user)
                isLoading = false
                HapticsManager.shared.notification(.success)
            } catch {
                errorMessage = mapFirebaseError(error)
                isLoading = false
                HapticsManager.shared.notification(.error)
            }
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        HapticsManager.shared.impact(.light)

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Configuration Firebase manquante"
            isLoading = false
            print("Google Sign-In Error: No clientID found")
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Find the root view controller more reliably
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            errorMessage = "Impossible d'afficher la connexion Google"
            isLoading = false
            print("Google Sign-In Error: No rootViewController found")
            return
        }

        // Get the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        print("Google Sign-In: Starting with controller \(type(of: topController))")

        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: topController)

                guard let idToken = result.user.idToken?.tokenString else {
                    errorMessage = "Token Google invalide"
                    isLoading = false
                    return
                }

                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )

                let authResult = try await Auth.auth().signIn(with: credential)
                print("Google Sign-In: Success! User: \(authResult.user.uid)")
                updateCurrentUser(from: authResult.user)

                // Trigger cloud sync after successful sign-in
                print("Google Sign-In: Triggering cloud sync...")
                await DataStore.shared.triggerSyncAfterSignIn()
                print("Google Sign-In: Cloud sync completed")

                isLoading = false
                HapticsManager.shared.notification(.success)
            } catch {
                print("Google Sign-In Error: \(error.localizedDescription)")
                errorMessage = mapFirebaseError(error)
                isLoading = false
                HapticsManager.shared.notification(.error)
            }
        }
    }

    // MARK: - Anonymous Sign In (Skip)

    func signInAnonymously() {
        isLoading = true
        HapticsManager.shared.impact(.light)

        Task {
            do {
                let result = try await Auth.auth().signInAnonymously()
                updateCurrentUser(from: result.user)
                isLoading = false
                HapticsManager.shared.notification(.success)
            } catch {
                // Fallback to local anonymous user if Firebase fails
                let user = AuthUser(
                    id: UUID().uuidString,
                    email: nil,
                    displayName: nil,
                    photoURL: nil,
                    provider: .anonymous,
                    createdAt: Date()
                )
                currentUser = user
                isAuthenticated = true
                saveUserLocally(user)
                isLoading = false
                HapticsManager.shared.notification(.success)
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        HapticsManager.shared.impact(.medium)

        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            currentUser = nil
            isAuthenticated = false
        } catch {
            errorMessage = "Erreur lors de la déconnexion"
        }
    }

    // MARK: - Delete Account

    // Flag to prevent auto-sync during account deletion
    private(set) var isDeletingAccount = false

    func deleteAccount() async {
        HapticsManager.shared.impact(.medium)
        isDeletingAccount = true

        print("DeleteAccount: Starting cleanup...")

        // Sign out from Firebase
        do {
            try Auth.auth().signOut()
            print("DeleteAccount: Firebase signed out")
        } catch {
            print("DeleteAccount: Firebase sign out error: \(error.localizedDescription)")
        }

        // Disconnect from Google (revokes access completely)
        GIDSignIn.sharedInstance.signOut()
        print("DeleteAccount: Google signed out")

        // Clear local auth data
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        currentUser = nil
        isAuthenticated = false

        // Reset DataStore
        DataStore.shared.reset()

        isDeletingAccount = false
        HapticsManager.shared.notification(.success)
        print("DeleteAccount: Cleanup complete - returning to onboarding")
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await Auth.auth().sendPasswordReset(withEmail: email)
                isLoading = false
                HapticsManager.shared.notification(.success)
            } catch {
                errorMessage = mapFirebaseError(error)
                isLoading = false
                HapticsManager.shared.notification(.error)
            }
        }
    }

    // MARK: - Error Mapping

    private func mapFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError

        switch nsError.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "Cette adresse email est déjà utilisée"
        case AuthErrorCode.invalidEmail.rawValue:
            return "Adresse email invalide"
        case AuthErrorCode.weakPassword.rawValue:
            return "Le mot de passe doit contenir au moins 6 caractères"
        case AuthErrorCode.wrongPassword.rawValue:
            return "Mot de passe incorrect"
        case AuthErrorCode.userNotFound.rawValue:
            return "Aucun compte trouvé avec cet email"
        case AuthErrorCode.networkError.rawValue:
            return "Erreur réseau. Vérifiez votre connexion"
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Trop de tentatives. Réessayez plus tard"
        case AuthErrorCode.userDisabled.rawValue:
            return "Ce compte a été désactivé"
        case AuthErrorCode.requiresRecentLogin.rawValue:
            return "Veuillez vous reconnecter pour effectuer cette action"
        default:
            return error.localizedDescription
        }
    }
}

// MARK: - Haptics Manager

class HapticsManager {
    static let shared = HapticsManager()

    private init() {}

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    // Convenience methods
    func lightImpact() {
        impact(.light)
    }

    func mediumImpact() {
        impact(.medium)
    }

    func heavyImpact() {
        impact(.heavy)
    }

    func success() {
        notification(.success)
    }

    func warning() {
        notification(.warning)
    }

    func error() {
        notification(.error)
    }
}
