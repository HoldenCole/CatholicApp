import SwiftUI

// Settings sheet — mirrors the settings overlay from prototype/today.html.
// Sections: Rite, Penance Discipline, Display (dark mode), Reset, About.

struct SettingsView: View {
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue
    @AppStorage(SettingsKey.penance) private var penanceRaw = PenanceDiscipline.discipline1962.rawValue
    @AppStorage(SettingsKey.darkMode) private var darkMode = false
    @State private var showResetConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                riteSection
                penanceSection
                displaySection
                resetSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.sanctuaryRed)
                }
            }
        }
    }

    // MARK: - Rite

    private var riteSection: some View {
        Section {
            Picker("Missal Rite", selection: $riteRaw) {
                ForEach(MissalRite.allCases) { r in
                    Text(r.label).tag(r.rawValue)
                }
            }
            .pickerStyle(.inline)
        } header: {
            Text("Ritus")
        } footer: {
            Text("Controls the rubrics displayed in the Missal. Most traditional parishes use the 1962 Missal.")
        }
    }

    // MARK: - Penance

    private var penanceSection: some View {
        Section {
            Picker("Penance Discipline", selection: $penanceRaw) {
                ForEach(PenanceDiscipline.allCases) { d in
                    Text(d.label).tag(d.rawValue)
                }
            }
            .pickerStyle(.inline)
        } header: {
            Text("Pæniténtia")
        } footer: {
            Text("Determines which fasting and abstinence obligations appear on the Today screen.")
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        Section {
            Toggle("Dark Mode", isOn: $darkMode)
        } header: {
            Text("Display")
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Reset All Progress", systemImage: "arrow.counterclockwise")
            }
            .confirmationDialog("Clear all local progress?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) {
                    UserProgress.resetAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear your followed saint, streaks, rosary history, and mastered lessons. Settings are preserved.")
            }
        } footer: {
            Text("Clears all local progress. Settings (rite, penance, dark mode) are not affected.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("App") {
                Text("Introibo")
                    .italic()
            }
            LabeledContent("") {
                Text("Ad altáre Dei — To the Altar of God")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            Text("A free prayer companion for traditional Catholics. No accounts, no tracking, no ads. All data is stored locally on your device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("About")
        }
    }
}

#Preview { SettingsView() }
