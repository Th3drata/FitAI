import SwiftUI

struct AssistantView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var localization: LocalizationManager
    @StateObject private var openAIService = OpenAIService.shared

    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isProcessing = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat messages
                chatMessagesView

                // Quick actions (when no messages)
                if dataStore.getChatHistory().isEmpty {
                    quickActionsView
                }

                // Input field
                inputField
            }
            .background(AppTheme.backgroundPrimary)
            .navigationTitle(localization["assistant_title"])
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !dataStore.getChatHistory().isEmpty {
                        Button(action: clearChat) {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .onAppear {
                if dataStore.getChatHistory().isEmpty {
                    addWelcomeMessage()
                }
            }
        }
    }

    // MARK: - Chat Messages View

    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppTheme.spacingM) {
                    ForEach(dataStore.getChatHistory()) { message in
                        ChatBubble(message: message, localization: localization)
                            .id(message.id)
                    }
                }
                .padding(AppTheme.spacingM)
            }
            .onAppear {
                scrollProxy = proxy
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsView: some View {
        VStack(spacing: AppTheme.spacingM) {
            Text(localization["assistant_quick_actions"])
                .font(.headline)
                .foregroundColor(AppTheme.textSecondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppTheme.spacingM) {
                QuickActionCard(
                    icon: "calendar.badge.plus",
                    title: localization["assistant_generate_week"],
                    color: AppTheme.accent
                ) {
                    sendQuickAction(localization.currentLanguage == .french
                        ? "Génère-moi un programme d'entraînement"
                        : "Generate a workout program for me")
                }

                QuickActionCard(
                    icon: "bell.badge",
                    title: localization["assistant_enable_reminders"],
                    color: AppTheme.warning
                ) {
                    sendQuickAction(localization.currentLanguage == .french
                        ? "Comment activer les rappels ?"
                        : "How to enable reminders?")
                }

                QuickActionCard(
                    icon: "chart.pie",
                    title: localization["assistant_explain_macros"],
                    color: AppTheme.accent
                ) {
                    sendQuickAction(localization.currentLanguage == .french
                        ? "Explique-moi les macros"
                        : "Explain macros to me")
                }

                QuickActionCard(
                    icon: "lightbulb",
                    title: localization["assistant_tips"],
                    color: AppTheme.success
                ) {
                    sendQuickAction(localization.currentLanguage == .french
                        ? "Donne-moi un conseil"
                        : "Give me a tip")
                }
            }
            .padding(.horizontal, AppTheme.spacingL)
        }
        .padding(.vertical, AppTheme.spacingL)
    }

    // MARK: - Input Field

    private var inputField: some View {
        HStack(spacing: AppTheme.spacingS) {
            TextField(localization["assistant_placeholder"], text: $messageText)
                .textFieldStyle(CustomTextFieldStyle())
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }

            Button(action: sendMessage) {
                if isProcessing {
                    ProgressView()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundColor(messageText.isEmpty ? AppTheme.textSecondary : AppTheme.accent)
                }
            }
            .disabled(messageText.isEmpty || isProcessing)
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.vertical, AppTheme.spacingS)
        .background(AppTheme.backgroundSecondary)
    }

    // MARK: - Actions

    private func addWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            content: localization["assistant_welcome"],
            isFromUser: false
        )
        dataStore.addChatMessage(welcomeMessage)
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        let userMessage = ChatMessage(
            content: messageText,
            isFromUser: true
        )
        dataStore.addChatMessage(userMessage)

        let text = messageText
        messageText = ""
        isInputFocused = false
        isProcessing = true

        // Build context for AI
        let context = buildContext()

        // Process with OpenAI
        Task {
            let response = await openAIService.chat(
                message: text,
                context: context,
                language: dataStore.profile?.language ?? .french
            )

            let aiMessage = ChatMessage(
                content: response ?? (localization.currentLanguage == .french
                    ? "Désolé, je n'ai pas pu traiter votre message. Veuillez réessayer."
                    : "Sorry, I couldn't process your message. Please try again."),
                isFromUser: false
            )
            dataStore.addChatMessage(aiMessage)
            isProcessing = false

            // Scroll to bottom
            if let lastMessage = dataStore.getChatHistory().last {
                withAnimation {
                    scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }

    private func buildContext() -> String {
        var context = ""

        if let profile = dataStore.profile {
            context += "User profile:\n"
            context += "- Name: \(profile.name.isEmpty ? "Unknown" : profile.name)\n"
            context += "- Age: \(profile.age) years old\n"
            context += "- Weight: \(profile.weightKg) kg\n"
            context += "- Height: \(profile.heightCm) cm\n"
            context += "- Equipment: \(profile.equipment == .dumbbells ? "Dumbbells" : "No equipment")\n"
            context += "- Sessions per week: \(profile.sessionsPerWeek)\n"
        }

        let totalWorkouts = dataStore.getSessionLogs().count
        context += "- Total completed workouts: \(totalWorkouts)\n"

        if let lastWeight = dataStore.getWeightEntries().last {
            context += "- Latest recorded weight: \(lastWeight.weightKg) kg\n"
        }

        return context
    }

    private func sendQuickAction(_ text: String) {
        messageText = text
        sendMessage()
    }

    private func clearChat() {
        dataStore.clearChatHistory()
        addWelcomeMessage()
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    let localization: LocalizationManager

    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: AppTheme.spacingXS) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(message.isFromUser ? .white : AppTheme.textPrimary)
                    .padding(AppTheme.spacingM)
                    .background(
                        message.isFromUser
                            ? AppTheme.accent
                            : AppTheme.backgroundSecondary
                    )
                    .cornerRadius(AppTheme.cornerRadiusMedium)

                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.isFromUser ? .trailing : .leading)

            if !message.isFromUser {
                Spacer()
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.spacingS) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.spacingM)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(AppTheme.cornerRadiusMedium)
        }
    }
}

#Preview {
    AssistantView()
        .environmentObject(DataStore.shared)
        .environmentObject(LocalizationManager.shared)
}
