import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue
    @AppStorage(SettingsKey.penance) private var penanceRaw = PenanceDiscipline.discipline1962.rawValue
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue
    @AppStorage(SettingsKey.fontRange) private var fontRangeRaw = FontRange.normal.rawValue
    @AppStorage(SettingsKey.showLeoninePrayers) private var showLeoninePrayers = true
    @AppStorage(SettingsKey.showUpcomingFeasts) private var showUpcomingFeasts = false
    @AppStorage(SettingsKey.vernacularLang) private var vernacularRaw = VernacularLanguage.english.rawValue
    @State private var showResetConfirm = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                riteSection
                leonineSection
                homeSection
                penanceSection
                languageSection
                vernacularSection
                displaySection
                fontSizeSection
                widgetSection
                tutorialSection
                feedbackSection
                resetSection
                licensesSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            // The widget snapshot bakes in the rite and language — rebuild it
            // the moment either changes so the widgets follow immediately.
            .onChange(of: riteRaw) { _, _ in
                DispatchQueue.global(qos: .utility).async { WidgetSnapshotWriter.refresh() }
            }
            .onChange(of: languageRaw) { _, _ in
                DispatchQueue.global(qos: .utility).async { WidgetSnapshotWriter.refresh() }
            }
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

    // MARK: - Leonine Prayers

    private var leonineSection: some View {
        Section {
            Toggle(isOn: $showLeoninePrayers) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Leonine Prayers")
                        .foregroundStyle(Color.primaryText)
                    Text("Prayers after Low Mass (Leo XIII, 1884)")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .tint(Color.sanctuaryRed)
            .listRowBackground(Color.pageBackground)
        } header: {
            Text("Preces Leoninae · Leonine Prayers")
        } footer: {
            Text("The Leonine Prayers were instituted by Leo XIII in 1884 and suppressed by Inter Oecumenici in 1964. Enable for strict 1962 observance; disable for post-1964 practice.")
        }
    }

    // MARK: - Home screen

    private var homeSection: some View {
        Section {
            Toggle(isOn: $showUpcomingFeasts) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Upcoming Feasts on Home")
                        .foregroundStyle(Color.primaryText)
                    Text("The next fortnight's feasts, vigils, and Ember days")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .tint(Color.sanctuaryRed)
            .listRowBackground(Color.pageBackground)
        } header: {
            Text("Hodie · Home Screen")
        } footer: {
            Text("The full list always remains available on the Calendar.")
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

    // MARK: - Vernacular

    private var vernacularSection: some View {
        Section {
            ForEach(VernacularLanguage.allCases) { v in
                HStack {
                    Text(v.displayName)
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    if vernacularRaw == v.rawValue {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.sanctuaryRed)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard vernacularRaw != v.rawValue else { return }
                    vernacularRaw = v.rawValue
                    ContentStore.shared.applyVernacular(v)
                }
                .listRowBackground(Color.pageBackground)
            }
        } header: {
            Text("Sermo Vulgáris · Vernacular")
        } footer: {
            Text("Español covers the prayers, the Marian antiphons, the complete Ordinary of the Mass, and the Office hour introductions; the Mass propers and Office texts fall back to English while translation continues.")
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

    private var currentRange: FontRange {
        FontRange(rawValue: fontRangeRaw) ?? .normal
    }

    private var fontSizeSection: some View {
        Section {
            VStack(spacing: 12) {
                Text("Introibo ad altare Dei")
                    // Slider preview: apply the slider value directly (NOT
                    // .scaledSystem, which would apply it a second time).
                    .font(.system(size: 16 * fontScale, design: .serif))
                    .italic()
                    .foregroundStyle(Color.primaryText)
                    .frame(maxWidth: .infinity)
                HStack {
                    Text("A")
                        .font(.scaledSystem(10, design: .serif))
                        .foregroundStyle(Color.tertiaryText)
                    Slider(
                        value: $fontScale,
                        in: currentRange.min...currentRange.max,
                        step: 0.05
                    )
                    .tint(Color.sanctuaryRed)
                    Text("A")
                        .font(.scaledSystem(24, design: .serif))
                        .foregroundStyle(Color.tertiaryText)
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.pageBackground)

            HStack {
                ForEach(FontRange.allCases) { r in
                    Button {
                        fontRangeRaw = r.rawValue
                        if fontScale < r.min || fontScale > r.max {
                            fontScale = r.defaultVal
                        }
                    } label: {
                        Text(r.label)
                            .font(.captionSm)
                            .foregroundStyle(fontRangeRaw == r.rawValue ? Color.sanctuaryRed : Color.tertiaryText)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(fontRangeRaw == r.rawValue ? Color.sanctuaryRed.opacity(0.08) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(Color.pageBackground)
        } header: {
            Text("Littera · Text Size")
        } footer: {
            Text("Choose a scale range, then adjust the slider. Smaller for compact reading, Bigger for accessibility.")
        }
    }

    // MARK: - Widget

    private var widgetSection: some View {
        Section {
            NavigationLink {
                WidgetSettingsView()
            } label: {
                Label("Home Screen Widget", systemImage: "square.grid.2x2")
                    .foregroundStyle(Color.primaryText)
            }
            .listRowBackground(Color.pageBackground)
        } header: {
            Text("Widget")
        }
    }

    // MARK: - Tutorial

    @State private var showTutorials = false

    private var tutorialSection: some View {
        Section {
            Button { showTutorials = true } label: {
                HStack {
                    Label("Tutorials", systemImage: "questionmark.circle")
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    Text("\(FeatureTutorial.allCases.count)")
                        .font(.captionSm)
                        .foregroundStyle(Color.tertiaryText)
                    Image(systemName: "chevron.right")
                        .font(.scaledSystem(12))
                        .foregroundStyle(Color.tertiaryText)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.pageBackground)
            .sheet(isPresented: $showTutorials) {
                // Close BOTH sheets (tutorials list + Settings) before the
                // tour starts, or the spotlight plays underneath Settings and
                // the user just lands back on this screen.
                TutorialsListView(onStart: { feature in
                    showTutorials = false
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        TutorialManager.shared.startFeatureTutorial(feature)
                    }
                })
            }
        } header: {
            Text("Tutoriales")
        }
    }

    // MARK: - Feedback

    private var feedbackSection: some View {
        Section {
            Link(destination: URL(string: "mailto:contact@lampstandhq.com?subject=Introibo%20Feedback") ?? URL(string: "mailto:")!) {
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

    // MARK: - Licenses

    private var licensesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Divinum Officium")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primaryText)
                Text("Liturgical texts for the Divine Office and Holy Mass are sourced from the Divinum Officium project (divinumofficium.com).")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                Text("Licensed under the MIT License.")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(Color.tertiaryText)
            }
            .listRowBackground(Color.pageBackground)
        } header: {
            Text("Licentia · Licenses")
        } footer: {
            Text("Introibo uses open-source liturgical data to ensure accuracy.")
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
            LabeledContent("Version") {
                Text("1.2")
                    .foregroundStyle(Color.secondaryText)
            }
            .listRowBackground(Color.pageBackground)
            LabeledContent("") {
                Text("Ad altare Dei")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
            }
            .listRowBackground(Color.pageBackground)
            Text("A prayer companion for the traditional Catholic life. Ad free. Works offline.")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .listRowBackground(Color.pageBackground)
        } header: {
            Text("About")
        } footer: {
            Text("Built by Lampstand")
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
    }
}

#Preview { SettingsView() }
