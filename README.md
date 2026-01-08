# FitAI - Your Personal Fitness Coach

<p align="center">
  <img src="appstore.png" alt="FitAI Logo" width="120" height="120">
</p>

<p align="center">
  <strong>An intelligent iOS fitness app for muscle building with personalized workouts and AI-powered meal plans</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-16.0%2B-blue" alt="iOS 16.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/SwiftUI-4.0-purple" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Firebase-10.0-yellow" alt="Firebase">
  <img src="https://img.shields.io/badge/OpenAI-GPT--4-green" alt="OpenAI">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</p>

---

## Features

### Personalized Workout Programs

- **12-week progressive program** with smart workout generation based on your profile
- **3-level navigation**: Overview of all weeks → Week detail with days → Day detail with exercises
- **Active workout mode** with built-in rest timer, set tracking, and haptic feedback
- **Progressive overload system** - weight suggestions based on your exercise history
- **Session feedback** - rate difficulty and satisfaction after each workout

### AI-Powered Nutrition

- **OpenAI-generated meal plans** with diverse cuisines (Mediterranean, Asian, Mexican, etc.)
- **Detailed cooking instructions** with step-by-step preparation
- **Macro tracking** (proteins, carbs, fats) with daily targets
- **Varied recipes** - different protein sources, cooking methods, and ingredients each time

### Progress Tracking

- **Weight logging** with visual progress charts
- **Session history** with detailed exercise records
- **Statistics dashboard** showing weekly/total progress
- **Weight change tracking** from start to current

### AI Assistant

- **Built-in GPT-powered fitness assistant** for tips and guidance
- **Quick actions** for common tasks
- **Contextual advice** based on your profile

### Cloud Sync & Authentication

- **Firebase Authentication** (Email/Password, Google Sign-In)
- **Firestore cloud sync** - access your data across devices
- **Guest mode** for trying the app without account
- **Delete account** option with full data cleanup

### Customization

- **Light/Dark/System theme** modes
- **7 accent colors** to personalize your experience (Teal, Blue, Purple, Pink, Orange, Green, Red)
- **French & English** language support
- **Workout reminders** with customizable notifications

---

## Screenshots

<p align="center">
  <i>Screenshots coming soon</i>
</p>

---

## Tech Stack

| Technology            | Purpose                             |
| --------------------- | ----------------------------------- |
| **SwiftUI**           | Modern declarative UI framework     |
| **Firebase Auth**     | User authentication (Email, Google) |
| **Cloud Firestore**   | Real-time cloud database            |
| **OpenAI API**        | AI-powered meal plans & assistant   |
| **Google Sign-In**    | OAuth authentication                |
| **UserNotifications** | Workout reminders                   |
| **Charts**            | Progress visualization              |

---

## Architecture

```
FitAI/
├── FitAIApp.swift           # App entry point
├── ContentView.swift        # Root view with navigation
├── Models/
│   └── Models.swift         # Data models (Workout, Exercise, UserProfile, Meal, etc.)
├── Views/
│   ├── HomeView.swift       # Dashboard with today's workout
│   ├── WorkoutsListView.swift   # 3-level workout navigation
│   ├── ActiveWorkoutView.swift  # Active workout with timer & feedback
│   ├── MealsView.swift      # AI meal plans with recipes
│   ├── TrackingView.swift   # Weight & progress tracking
│   ├── AssistantView.swift  # AI fitness assistant
│   ├── SettingsView.swift   # Preferences & account
│   └── OnboardingView.swift # User profile setup
├── Services/
│   ├── DataStore.swift      # Local & cloud data management
│   ├── FirestoreService.swift
│   ├── AuthenticationService.swift
│   ├── OpenAIService.swift  # GPT integration for meals & chat
│   ├── WorkoutGenerator.swift
│   ├── MealGenerator.swift  # Fallback local meal generation
│   └── NotificationManager.swift
└── Utilities/
    ├── Theme.swift          # App theming & styles
    ├── ThemeManager.swift   # Theme/color preferences
    ├── HapticsManager.swift # Haptic feedback
    └── LocalizationManager.swift
```

---

## Getting Started

### Prerequisites

- **Xcode 15+**
- **iOS 17.0+**
- **Swift Package Manager**
- **Firebase account**
- **OpenAI API key** (required for AI features)
- **Apple Developer account** (for testing on physical device)

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/Th3drata/FitAI.git
   cd FitAI
   ```

2. **Configure API Keys**

   The project uses two external services that require API keys:

   #### OpenAI (Required)

   - **Purpose:** Personalized workout and meal generation
   - **Get your key:** https://platform.openai.com/api-keys
   - **Cost:** Pay-per-use

   #### RapidAPI - ExerciseDB (Optional)

   - **Purpose:** Exercise database with images/videos
   - **Get your key:** https://rapidapi.com/justin-WFnsXH_t6/api/exercisedb
   - **Cost:** Free tier available

   **Install API Keys:**

   1. Copy the template file:

      ```bash
      cp FitAI/Config.example.swift FitAI/Config.swift
      ```

   2. Edit `FitAI/Config.swift` with your keys:

      ```swift
      struct Config {
          static let openAIKey = "your-openai-key-here"
          static let rapidAPIKey = "your-rapidapi-key-here"
      }
      ```

   3. ⚠️ **Important:** `Config.swift` is git-ignored and will never be committed

3. **Configure Firebase**

   Create a Firebase project:

   - Go to https://console.firebase.google.com
   - Create a new project
   - Enable **Authentication** (Email/Password and Google Sign-In)
   - Enable **Cloud Firestore**

   Download configuration file:

   - In Firebase project settings, download `GoogleService-Info.plist`
   - Place it in the `FitAI/` folder
   - ⚠️ This file is also excluded from Git

   **Firestore Security Rules:**

   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```

4. **Configure Google Sign-In**

   - In Firebase Console > Authentication > Sign-in method
   - Enable "Google"
   - Copy the OAuth Client ID
   - Add to Xcode > FitAI Target > Info > URL Types

   Add to your `Info.plist`:

   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleTypeRole</key>
       <string>Editor</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```

5. **Build and Run**

   ```bash
   open FitAI.xcodeproj
   ```

   Select your target device/simulator and press `Cmd + R`

   Or via command line:

   ```bash
   xcodebuild -project FitAI.xcodeproj -scheme FitAI -configuration Debug
   ```

### Project Structure - Secret Files

```
FitAI/
├── Config.swift              # ❌ Git-ignored (contains your API keys)
├── Config.example.swift      # ✅ Committed (template without keys)
└── GoogleService-Info.plist  # ❌ Git-ignored (Firebase config)
```

---

## Data Models

### UserProfile

```swift
struct UserProfile {
    var name: String
    var age: Int
    var weightKg: Double
    var heightCm: Double
    var sex: Sex
    var equipment: Equipment      // .dumbbells or .none
    var sessionsPerWeek: Int      // 3-6
    var language: AppLanguage
    var currentWeek: Int          // 1-12
}
```

### Workout & Exercise

```swift
struct Workout {
    var titleKey: String
    var weekIndex: Int
    var dayIndex: Int
    var exercises: [Exercise]
    var durationMinutes: Int
    var difficulty: Difficulty
    var scheduledDate: Date?
}

struct Exercise {
    var nameKey: String
    var muscleGroups: [MuscleGroup]
    var equipment: Equipment
    var sets: Int
    var reps: Int
    var restSeconds: Int
    var tempo: String?
}
```

### Meal

```swift
struct Meal {
    var nameKey: String
    var descriptionKey: String
    var kcal: Int
    var proteinG: Double
    var carbsG: Double
    var fatsG: Double
    var ingredients: [String]
    var instructions: String?     // Step-by-step cooking instructions
}
```

---

## Localization

The app supports:

- **French** (default)
- **English**

Add new languages by extending `LocalizationManager.swift`:

```swift
private let spanishStrings: [String: String] = [
    "app_name": "FitAI",
    // ... add translations
]
```

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- Built with SwiftUI and Firebase
- AI powered by OpenAI GPT
- Icons from SF Symbols
- Inspired by modern fitness tracking apps

---

## Contact

**Oscar** - [@Th3drata](https://github.com/Th3drata)

Project Link: [https://github.com/Th3drata/FitAI](https://github.com/Th3drata/FitAI)

---

<p align="center">
  Made with ❤️ for fitness enthusiasts
</p>
