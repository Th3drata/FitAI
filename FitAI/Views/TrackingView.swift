import SwiftUI
import Charts

struct TrackingView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var localization: LocalizationManager

    @State private var selectedTab = 0
    @State private var showAddWeight = false
    @State private var newWeight: Double = 70.0
    @State private var weightNotes = ""
    @State private var showWeightInput = false
    @State private var weightInputText = ""
    @State private var selectedWeightEntry: WeightEntry?
    @State private var showEditWeight = false
    @State private var editingWeight: Double = 70.0
    @State private var editingNotes = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    // Tab selector with custom style
                    tabSelector

                    // Content
                    if selectedTab == 0 {
                        weightTrackingContent
                    } else {
                        sessionsContent
                    }
                }
                .padding(AppTheme.spacingL)
            }
            .background(AppTheme.backgroundPrimary)
            .navigationTitle(localization["tracking_title"])
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == 0 {
                        Button(action: { showAddWeight = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddWeight) {
                addWeightSheet
            }
            .sheet(isPresented: $showEditWeight) {
                editWeightSheet
            }
            .onAppear {
                if let weight = dataStore.getLatestWeight() {
                    newWeight = weight
                }
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(0..<2, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = index
                        HapticsManager.shared.selection()
                    }
                }) {
                    VStack(spacing: AppTheme.spacingS) {
                        Image(systemName: index == 0 ? "scalemass.fill" : "figure.run")
                            .font(.title2)
                        Text(index == 0 ? localization["tracking_weight"] : localization["tracking_sessions"])
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacingM)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                            .fill(selectedTab == index ? AppTheme.accent : Color.clear)
                    )
                    .foregroundColor(selectedTab == index ? .white : AppTheme.textSecondary)
                }
            }
        }
        .padding(4)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
    }

    // MARK: - Weight Tracking Content

    private var weightTrackingContent: some View {
        VStack(spacing: AppTheme.spacingL) {
            // Summary cards
            weightSummaryCards

            // Chart
            if !dataStore.getWeightEntries().isEmpty {
                weightChart
            } else {
                emptyWeightState
            }

            // History
            if !dataStore.getWeightEntries().isEmpty {
                weightHistory
            }
        }
    }

    // MARK: - Weight Summary Cards

    private var weightSummaryCards: some View {
        HStack(spacing: AppTheme.spacingM) {
            // Current weight card
            VStack(spacing: AppTheme.spacingS) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: "scalemass.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.accent)
                }

                Text(localization["tracking_current_weight"])
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)

                if let weight = dataStore.getLatestWeight() {
                    Text(String(format: "%.1f", weight))
                        .font(.title.bold())
                    Text(localization["tracking_kg"])
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                } else {
                    Text("-")
                        .font(.title.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.spacingL)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(AppTheme.cornerRadiusLarge)

            // Progress card
            VStack(spacing: AppTheme.spacingS) {
                ZStack {
                    Circle()
                        .fill((dataStore.getWeightProgress()?.change ?? 0) >= 0 ? AppTheme.success.opacity(0.15) : AppTheme.warning.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: (dataStore.getWeightProgress()?.change ?? 0) >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.title2)
                        .foregroundColor((dataStore.getWeightProgress()?.change ?? 0) >= 0 ? AppTheme.success : AppTheme.warning)
                }

                Text(localization["tracking_progress"])
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)

                if let progress = dataStore.getWeightProgress() {
                    Text(String(format: "%@%.1f", progress.change >= 0 ? "+" : "", progress.change))
                        .font(.title.bold())
                        .foregroundColor(progress.change >= 0 ? AppTheme.success : AppTheme.warning)
                    Text(localization["tracking_kg"])
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                } else {
                    Text("-")
                        .font(.title.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.spacingL)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(AppTheme.cornerRadiusLarge)
        }
    }

    // MARK: - Weight Chart

    private var weightChart: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(AppTheme.accent)
                Text(localization["tracking_progress"])
                    .font(.headline)
            }

            let entries = dataStore.getWeightEntries()

            Chart(entries) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weightKg)
                )
                .foregroundStyle(AppTheme.accent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3))

                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weightKg)
                )
                .foregroundStyle(selectedWeightEntry?.id == entry.id ? .white : AppTheme.accent)
                .symbolSize(selectedWeightEntry?.id == entry.id ? 120 : 60)

                AreaMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weightKg)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.accent.opacity(0.3), AppTheme.accent.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Show rule line for selected entry
                if let selected = selectedWeightEntry, selected.id == entry.id {
                    RuleMark(x: .value("Date", entry.date))
                        .foregroundStyle(AppTheme.accent.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                }
            }
            .chartYScale(domain: weightChartDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month())
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x
                                    if let date: Date = proxy.value(atX: x) {
                                        // Find closest entry
                                        let closest = entries.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                        })
                                        if selectedWeightEntry?.id != closest?.id {
                                            selectedWeightEntry = closest
                                            HapticsManager.shared.selection()
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    // Keep selection visible for a moment then clear
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation {
                                            selectedWeightEntry = nil
                                        }
                                    }
                                }
                        )
                }
            }
            .frame(height: 220)

            // Show selected entry details
            if let entry = selectedWeightEntry {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%.1f kg", entry.weightKg))
                            .font(.headline)
                            .foregroundColor(AppTheme.accent)
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.top, AppTheme.spacingS)
                .transition(.opacity)
            }
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
    }

    private var weightChartDomain: ClosedRange<Double> {
        let entries = dataStore.getWeightEntries()
        let weights = entries.map { $0.weightKg }
        let minWeight = (weights.min() ?? 60) - 2
        let maxWeight = (weights.max() ?? 80) + 2
        return minWeight...maxWeight
    }

    // MARK: - Weight History

    private var weightHistory: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(AppTheme.accent)
                Text(localization["tracking_history"])
                    .font(.headline)
                Spacer()
                Button(action: exportData) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text(localization["tracking_export"])
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.vertical, AppTheme.spacingS)
                    .background(AppTheme.accent.opacity(0.1))
                    .cornerRadius(AppTheme.cornerRadiusSmall)
                }
            }

            ForEach(dataStore.getWeightEntries().suffix(10).reversed()) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(entry.date))
                            .font(.subheadline.weight(.medium))
                        if !entry.notes.isEmpty {
                            Text(entry.notes)
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    Spacer()
                    Text(String(format: "%.1f kg", entry.weightKg))
                        .font(.headline)
                        .foregroundColor(AppTheme.accent)
                        .padding(.horizontal, AppTheme.spacingM)
                        .padding(.vertical, AppTheme.spacingS)
                        .background(AppTheme.accent.opacity(0.1))
                        .cornerRadius(AppTheme.cornerRadiusSmall)
                }
                .padding(.vertical, AppTheme.spacingS)
                .contextMenu {
                    Button {
                        editingWeight = entry.weightKg
                        editingNotes = entry.notes
                        selectedWeightEntry = entry
                        showEditWeight = true
                    } label: {
                        Label(localization["edit"], systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        deleteWeightEntry(entry)
                    } label: {
                        Label(localization["delete"], systemImage: "trash")
                    }
                }

                if entry.id != dataStore.getWeightEntries().suffix(10).reversed().last?.id {
                    Divider()
                }
            }
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
    }

    // MARK: - Empty Weight State

    private var emptyWeightState: some View {
        VStack(spacing: AppTheme.spacingL) {
            Spacer(minLength: AppTheme.spacingXL)

            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "scalemass")
                    .font(.system(size: 50))
                    .foregroundColor(AppTheme.accent)
            }

            VStack(spacing: AppTheme.spacingS) {
                Text(localization["tracking_no_data"])
                    .font(.title3.bold())

                Text(localization["tracking_no_data_desc"])
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showAddWeight = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(localization["tracking_add_weight"])
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            Spacer(minLength: AppTheme.spacingXL)
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
    }

    // MARK: - Sessions Content

    private var sessionsContent: some View {
        VStack(spacing: AppTheme.spacingL) {
            // Stats cards
            HStack(spacing: AppTheme.spacingM) {
                StatCardEnhanced(
                    title: localization["home_total_workouts"],
                    value: "\(dataStore.getTotalWorkoutsCompleted())",
                    icon: "checkmark.seal.fill",
                    color: AppTheme.accent
                )
                StatCardEnhanced(
                    title: localization["home_this_week"],
                    value: "\(dataStore.getWeeklyWorkoutsCompleted())",
                    icon: "flame.fill",
                    color: AppTheme.warning
                )
            }

            // Session history
            if !dataStore.getSessionLogs().isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                            .foregroundColor(AppTheme.accent)
                        Text(localization["tracking_history"])
                            .font(.headline)
                    }

                    ForEach(dataStore.getSessionLogs(limit: 20)) { log in
                        SessionLogCardEnhanced(log: log, localization: localization)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteSessionLog(log)
                                } label: {
                                    Label(localization["delete"], systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(AppTheme.spacingL)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(AppTheme.cornerRadiusLarge)
            } else {
                emptySessionsState
            }
        }
    }

    private var emptySessionsState: some View {
        VStack(spacing: AppTheme.spacingL) {
            Spacer(minLength: AppTheme.spacingXL)

            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "figure.run")
                    .font(.system(size: 50))
                    .foregroundColor(AppTheme.accent)
            }

            VStack(spacing: AppTheme.spacingS) {
                Text(localization["tracking_no_data"])
                    .font(.title3.bold())

                Text(localization["tracking_no_sessions_desc"])
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: AppTheme.spacingXL)
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
    }

    // MARK: - Add Weight Sheet

    private var addWeightSheet: some View {
        NavigationView {
            VStack(spacing: AppTheme.spacingL) {
                Spacer()

                // Weight display - tap to enter manually
                VStack(spacing: AppTheme.spacingS) {
                    Button(action: {
                        weightInputText = String(format: "%.1f", newWeight)
                        showWeightInput = true
                    }) {
                        Text(String(format: "%.1f", newWeight))
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.accent)
                    }
                    Text(localization["tracking_kg"])
                        .font(.title3)
                        .foregroundColor(AppTheme.textSecondary)
                    Text(localization["tracking_tap_to_edit"])
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                }

                // Slider
                VStack(spacing: AppTheme.spacingS) {
                    Slider(value: $newWeight, in: 40...150, step: 0.1)
                        .tint(AppTheme.accent)
                        .padding(.horizontal)

                    HStack {
                        Text("40 kg")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text("150 kg")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.horizontal)
                }
                .padding(AppTheme.spacingL)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(AppTheme.cornerRadiusLarge)
                .padding(.horizontal)

                // Notes
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    Text(localization["workout_notes"])
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                    TextField(localization["workout_add_notes"], text: $weightNotes)
                        .padding()
                        .background(AppTheme.backgroundSecondary)
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                }
                .padding(.horizontal)

                Spacer()

                // Save button
                Button(action: saveWeight) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(localization["save"])
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(AppTheme.backgroundPrimary)
            .navigationTitle(localization["tracking_add_weight"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localization["cancel"]) {
                        showAddWeight = false
                    }
                }
            }
            .alert(localization["tracking_weight"], isPresented: $showWeightInput) {
                TextField("kg", text: $weightInputText)
                    .keyboardType(.decimalPad)
                Button(localization["cancel"], role: .cancel) {}
                Button(localization["ok"]) {
                    if let weight = Double(weightInputText.replacingOccurrences(of: ",", with: ".")) {
                        newWeight = min(max(weight, 40), 150)
                    }
                }
            } message: {
                Text(localization["onboarding_enter_weight"])
            }
        }
    }

    // MARK: - Edit Weight Sheet

    private var editWeightSheet: some View {
        NavigationView {
            VStack(spacing: AppTheme.spacingL) {
                Spacer()

                // Weight display
                VStack(spacing: AppTheme.spacingS) {
                    Text(String(format: "%.1f", editingWeight))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.accent)
                    Text(localization["tracking_kg"])
                        .font(.title3)
                        .foregroundColor(AppTheme.textSecondary)
                }

                // Slider
                VStack(spacing: AppTheme.spacingS) {
                    Slider(value: $editingWeight, in: 40...150, step: 0.1)
                        .tint(AppTheme.accent)
                        .padding(.horizontal)

                    HStack {
                        Text("40 kg")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text("150 kg")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.horizontal)
                }
                .padding(AppTheme.spacingL)
                .background(AppTheme.backgroundSecondary)
                .cornerRadius(AppTheme.cornerRadiusLarge)
                .padding(.horizontal)

                // Notes
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    Text(localization["workout_notes"])
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                    TextField(localization["workout_add_notes"], text: $editingNotes)
                        .padding()
                        .background(AppTheme.backgroundSecondary)
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                }
                .padding(.horizontal)

                Spacer()

                // Save button
                Button(action: saveEditedWeight) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(localization["save"])
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(AppTheme.backgroundPrimary)
            .navigationTitle(localization["edit"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localization["cancel"]) {
                        showEditWeight = false
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveWeight() {
        let entry = WeightEntry(
            date: Date(),
            weightKg: newWeight,
            notes: weightNotes
        )
        dataStore.addWeightEntry(entry)
        weightNotes = ""
        showAddWeight = false
        HapticsManager.shared.notification(.success)
    }

    private func exportData() {
        HapticsManager.shared.impact(.light)
        let csv = dataStore.exportWeightDataToCSV()
        let activityVC = UIActivityViewController(
            activityItems: [csv],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func deleteWeightEntry(_ entry: WeightEntry) {
        dataStore.deleteWeightEntry(entry)
        HapticsManager.shared.notification(.success)
    }

    private func saveEditedWeight() {
        guard let entry = selectedWeightEntry else { return }
        let updatedEntry = WeightEntry(
            id: entry.id,
            date: entry.date,
            weightKg: editingWeight,
            notes: editingNotes
        )
        dataStore.updateWeightEntry(updatedEntry)
        showEditWeight = false
        selectedWeightEntry = nil
        HapticsManager.shared.notification(.success)
    }

    private func deleteSessionLog(_ log: SessionLog) {
        dataStore.deleteSessionLog(log)
        HapticsManager.shared.notification(.success)
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localization.currentLanguage.rawValue)
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Enhanced Stat Card

struct StatCardEnhanced: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: AppTheme.spacingM) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }

            Text(value)
                .font(.title.bold())

            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingL)
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(AppTheme.cornerRadiusLarge)
    }
}

// MARK: - Enhanced Session Log Card

struct SessionLogCardEnhanced: View {
    let log: SessionLog
    let localization: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization[log.workoutTitleKey])
                        .font(.headline)
                    Text(formatDate(log.date))
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                if let rating = log.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(AppTheme.warning)
                        }
                    }
                    .padding(.horizontal, AppTheme.spacingS)
                    .padding(.vertical, 4)
                    .background(AppTheme.warning.opacity(0.1))
                    .cornerRadius(AppTheme.cornerRadiusSmall)
                }
            }

            HStack(spacing: AppTheme.spacingM) {
                if let duration = log.durationMinutes {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text("\(duration) min")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, AppTheme.spacingS)
                    .padding(.vertical, 4)
                    .background(AppTheme.accent.opacity(0.1))
                    .cornerRadius(AppTheme.cornerRadiusSmall)
                }

                HStack(spacing: 4) {
                    Image(systemName: "dumbbell.fill")
                        .font(.caption)
                    Text("\(log.exerciseRecords.count) \(localization["home_exercises"])")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, AppTheme.spacingS)
                .padding(.vertical, 4)
                .background(AppTheme.backgroundPrimary)
                .cornerRadius(AppTheme.cornerRadiusSmall)

                if let difficulty = log.difficulty {
                    HStack(spacing: 4) {
                        Image(systemName: difficulty == .tooEasy ? "hand.thumbsup.fill" : difficulty == .tooHard ? "hand.thumbsdown.fill" : "checkmark.circle.fill")
                            .font(.caption)
                    }
                    .foregroundColor(difficulty == .justRight ? AppTheme.success : AppTheme.textSecondary)
                    .padding(.horizontal, AppTheme.spacingS)
                    .padding(.vertical, 4)
                    .background((difficulty == .justRight ? AppTheme.success : AppTheme.textSecondary).opacity(0.1))
                    .cornerRadius(AppTheme.cornerRadiusSmall)
                }
            }

            if !log.notes.isEmpty {
                Text(log.notes)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(AppTheme.spacingS)
                    .background(AppTheme.backgroundPrimary)
                    .cornerRadius(AppTheme.cornerRadiusSmall)
            }
        }
        .padding(AppTheme.spacingM)
        .background(AppTheme.backgroundPrimary)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localization.currentLanguage.rawValue)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    TrackingView()
        .environmentObject(DataStore.shared)
        .environmentObject(LocalizationManager.shared)
}
