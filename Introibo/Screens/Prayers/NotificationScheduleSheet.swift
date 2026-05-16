import SwiftUI
import UserNotifications

struct NotificationScheduleSheet: View {
    let scheduleId: String
    let title: String
    let subtitle: String

    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue

    @State private var isEnabled = false
    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    @State private var selectedTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    if authStatus == .denied {
                        deniedSection
                    } else {
                        toggleSection
                        if isEnabled {
                            daysSection
                            timeSection
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { save(); dismiss() }
                        .foregroundStyle(Color.sanctuaryRed)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.sanctuaryRed)
                }
            }
            .onAppear { loadExisting(); checkPermission() }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.titleL)
                .italic()
                .foregroundStyle(Color.primaryText)
            Text(subtitle)
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var toggleSection: some View {
        HStack {
            Label("Remind Me", systemImage: isEnabled ? "bell.fill" : "bell")
                .font(.titleM)
                .foregroundStyle(Color.primaryText)
            Spacer()
            Toggle("", isOn: $isEnabled)
                .tint(Color.sanctuaryRed)
                .labelsHidden()
        }
        .padding(16)
        .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
    }

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Days")
                .smallLabel(color: Color.sanctuaryRed)

            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { day in
                    let isSelected = selectedDays.contains(day)
                    Button {
                        if isSelected && selectedDays.count > 1 { selectedDays.remove(day) }
                        else if !isSelected { selectedDays.insert(day) }
                    } label: {
                        Text(dayNames[day - 1])
                            .font(.captionSm)
                            .foregroundStyle(isSelected ? Color.ivory : Color.primaryText)
                            .frame(width: 44, height: 44)
                            .background(isSelected ? Color.sanctuaryRed : Color.clear)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(isSelected ? Color.sanctuaryRed : Color.frameLine, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time")
                .smallLabel(color: Color.sanctuaryRed)
            DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
    }

    private var deniedSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.titleL)
                .foregroundStyle(Color.sanctuaryRed)
            Text("Notifications Disabled")
                .font(.titleM)
                .italic()
                .foregroundStyle(Color.primaryText)
            Text("Open Settings to allow Introibo to send prayer reminders.")
                .font(.captionSm)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.sanctuaryRed)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .overlay(Rectangle().stroke(Color.sanctuaryRed.opacity(0.5), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    private func loadExisting() {
        if let existing = NotificationStore.schedule(for: scheduleId) {
            isEnabled = existing.isEnabled
            selectedDays = existing.days
            let comps = DateComponents(hour: existing.hour, minute: existing.minute)
            selectedTime = Calendar.current.date(from: comps) ?? selectedTime
        }
    }

    private func checkPermission() {
        PrayerNotificationManager.checkStatus { status in
            authStatus = status
            if status == .notDetermined {
                PrayerNotificationManager.requestPermission { granted in
                    authStatus = granted ? .authorized : .denied
                }
            }
        }
    }

    private func save() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let schedule = NotificationSchedule(
            id: scheduleId,
            days: isEnabled ? selectedDays : [],
            hour: comps.hour ?? 8,
            minute: comps.minute ?? 0,
            isEnabled: isEnabled
        )
        NotificationStore.upsert(schedule)
        PrayerNotificationManager.scheduleAll()
    }
}
