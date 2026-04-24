import SwiftUI

// Settings sheet — mirrors the settings overlay from prototype/today.html.
// Sections: Rite, Penance Discipline, Display (dark mode), Reset, About.

struct SettingsView: View {
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue
    @AppStorage(SettingsKey.penance) private var penanceRaw = PenanceDiscipline.discipline1962.rawValue
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @State private var showResetConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                riteSection
                penanceSection
                languageSection
                displaySection
                resetSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.pageBackground.ignoresSafeArea())
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
            ForEach(MissalRite.allCases) { r in
                HStack {
                    Text(r.label)
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    if riteRaw == r.rawValue {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.sanctuaryRed)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { riteRaw = r.rawValue }
            }
        } header: {
            Text("Ritus · Missal Rite")
        } footer: {
            Text("Controls the rubrics displayed in the Missal. Most traditional parishes use the 1962 Missal.")
        }
    }

    // MARK: - Penance

    private var penanceSection: some View {
        Section {
            ForEach(PenanceDiscipline.allCases) { d in
                HStack {
                    Text(d.label)
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    if penanceRaw == d.rawValue {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.sanctuaryRed)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { penanceRaw = d.rawValue }
            }
        } header: {
            Text("Pæniténtia · Penance Discipline")
        } footer: {
            Text("Determines which fasting and abstinence obligations appear on the Today screen.")
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        Section {
            ForEach(LanguageMode.allCases) { l in
                HStack {
                    Text(l.label)
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    if languageRaw == l.rawValue {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.sanctuaryRed)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { languageRaw = l.rawValue }
            }
        } header: {
            Text("Lingua · Language")
        } footer: {
            Text("Choose which text to display in prayers, the Missal, and the Divine Office.")
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        Section {
            ForEach(AppTheme.allCases) { t in
                HStack {
                    Text(t.label)
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    if themeRaw == t.rawValue {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.sanctuaryRed)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { themeRaw = t.rawValue }
            }
        } header: {
            Text("Appáritus · Appearance")
        } footer: {
            Text("Parchment: warm vellum background. Clean White: modern white with walnut tab bar. Dark: deep walnut for low light.")
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
