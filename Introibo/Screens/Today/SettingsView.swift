import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue
    @AppStorage(SettingsKey.penance) private var penanceRaw = PenanceDiscipline.discipline1962.rawValue
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue
    @State private var showResetConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                riteSection
                penanceSection
                languageSection
                displaySection
                fontSizeSection
                feedbackSection
                resetSection
                aboutSection
            }
            .listStyle(.insetGrouped)
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
                .listRowBackground(Color.pageBackground)
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
                .listRowBackground(Color.pageBackground)
            }
        } header: {
            Text("Paenitentia · Penance Discipline")
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
                .listRowBackground(Color.pageBackground)
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
                .listRowBackground(Color.pageBackground)
            }
        } header: {
            Text("Apparitus · Appearance")
        } footer: {
            Text("Parchment: warm vellum background. Clean White: modern white with walnut tab bar. Dark: deep walnut for low light.")
        }
    }

    // MARK: - Font Size

    private var fontSizeSection: some View {
        Section {
            VStack(spacing: 12) {
                Text("Introibo ad altare Dei")
                    .font(.system(size: 16 * fontScale, design: .serif))
                    .italic()
                    .foregroundStyle(Color.primaryText)
                    .frame(maxWidth: .infinity)
                HStack {
                    Text("A")
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(Color.tertiaryText)
                    Slider(
                        value: $fontScale,
                        in: FontSizeScale.min...FontSizeScale.max,
                        step: 0.05
                    )
                    .tint(Color.sanctuaryRed)
                    Text("A")
                        .font(.system(size: 22, design: .serif))
                        .foregroundStyle(Color.tertiaryText)
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.pageBackground)
        } header: {
            Text("Littera · Text Size")
        } footer: {
            Text("Adjusts the size of prayer text, the Missal, and the Divine Office.")
        }
    }

    // MARK: - Feedback

    private var feedbackSection: some View {
        Section {
            Link(destination: URL(string: "mailto:feedback@introibo.app?subject=Introibo%20Feedback")!) {
                HStack {
                    Label("Send Feedback", systemImage: "envelope")
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.captionSm)
                        .foregroundStyle(Color.tertiaryText)
                }
            }
            .listRowBackground(Color.pageBackground)
        } header: {
            Text("Opinor · Feedback")
        } footer: {
            Text("Report issues, suggest features, or share your experience.")
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
            .listRowBackground(Color.pageBackground)
            .confirmationDialog("Clear all local progress?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) {
                    UserProgress.resetAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear your followed saint, streaks, rosary history, and mastered lessons. Settings are preserved.")
            }
        } footer: {
            Text("Clears all local progress. Settings (rite, penance, theme) are not affected.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("App") {
                Text("Introibo")
                    .italic()
            }
            .listRowBackground(Color.pageBackground)
            LabeledContent("") {
                Text("Ad altare Dei")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
            }
            .listRowBackground(Color.pageBackground)
            Text("A prayer companion for traditional Catholics. Ad free. Works offline.")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .listRowBackground(Color.pageBackground)
        } header: {
            Text("About")
        }
    }
}

#Preview { SettingsView() }
