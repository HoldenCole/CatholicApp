import SwiftUI
import SwiftData

struct SettingsSheet: View {
    @EnvironmentObject private var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Missal Rubrics
                    sectionHeader("Missal Rubrics", latin: "Rubricæ Missalis")

                    ForEach(MissalRite.allCases) { rite in
                        Button {
                            appSettings.missalRite = rite
                        } label: {
                            HStack(alignment: .top, spacing: 0) {
                                Rectangle()
                                    .fill(appSettings.missalRite == rite ? Color.sanctuaryRed : Color.clear)
                                    .frame(width: 3)
                                    .padding(.trailing, 16)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rite.displayName)
                                        .font(.custom("Palatino", size: 16).weight(.medium))
                                        .foregroundStyle(appSettings.missalRite == rite ? .ink : .secondary)
                                    Text(rite.latinName)
                                        .font(.custom("Palatino-Italic", size: 12))
                                        .foregroundStyle(.goldLeaf)
                                        .opacity(appSettings.missalRite == rite ? 1 : 0.6)
                                    Text(rite.subtitle)
                                        .font(.custom("Georgia", size: 12))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.goldLeaf.opacity(0.06))
                                    .frame(height: 1)
                            }
                        }
                    }

                    ornamentalDivider

                    // Default Text Mode
                    sectionHeader("Default Text Mode", latin: "Modus Textus")

                    HStack(spacing: 0) {
                        ForEach(TextMode.allCases) { mode in
                            Button {
                                appSettings.defaultTextMode = mode
                            } label: {
                                Text(mode.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(appSettings.defaultTextMode == mode ? .white : .ink)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background {
                                        if appSettings.defaultTextMode == mode {
                                            Rectangle().fill(Color.sanctuaryRed)
                                        }
                                    }
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.goldLeaf.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    ornamentalDivider

                    // Appearance
                    sectionHeader("Appearance", latin: "Aspectus")

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dark Mode")
                                .font(.custom("Palatino", size: 16).weight(.medium))
                                .foregroundStyle(.ink)
                            Text("Warm vellum dark theme")
                                .font(.custom("Georgia", size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $appSettings.darkModeEnabled)
                            .labelsHidden()
                            .tint(.sanctuaryRed)
                    }
                    .padding(.vertical, 12)

                    ornamentalDivider

                    // Progress link
                    sectionHeader("Your Progress", latin: "Progressus Tuus")

                    NavigationLink {
                        ProgressTabView()
                    } label: {
                        HStack {
                            Text("View Prayer Mastery")
                                .font(.custom("Palatino", size: 16).weight(.medium))
                                .foregroundStyle(.ink)
                            Spacer()
                            Text("→")
                                .foregroundStyle(.goldLeaf)
                        }
                        .padding(.vertical, 12)
                    }

                    ornamentalDivider

                    // About
                    sectionHeader("About", latin: "De Applicatione")

                    infoRow("App", value: "Ad Altare Dei")
                    infoRow("Version", value: "1.0")
                    infoRow("Price", value: "Free", valueColor: .comfortMastered)

                    Text("All data stored locally. No analytics, no accounts, no ads. Free forever.")
                        .font(.custom("Georgia-Italic", size: 13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .padding(.top, 16)

                    Text("✿ · ✿")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 12))
                        .foregroundStyle(.goldLeaf.opacity(0.4))
                        .tracking(8)
                        .padding(.vertical, 28)
                }
                .padding(.horizontal, 24)
            }
            .background(Color.parchment)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.sanctuaryRed)
                }
            }
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String, latin: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                .foregroundStyle(.sanctuaryRed)
                .tracking(3)
            Text(latin)
                .font(.custom("Palatino-Italic", size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 12)
    }

    private func infoRow(_ label: String, value: String, valueColor: Color = .secondary) -> some View {
        HStack {
            Text(label)
                .font(.custom("Palatino", size: 15))
                .foregroundStyle(.ink)
            Spacer()
            Text(value)
                .font(.custom("Palatino-Italic", size: 15))
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.goldLeaf.opacity(0.06))
                .frame(height: 1)
        }
    }

    private var ornamentalDivider: some View {
        HStack {
            Spacer()
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.clear)
                .background(
                    LinearGradient(
                        colors: [.clear, .goldLeaf.opacity(0.25), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            Spacer()
        }
        .padding(.vertical, 16)
    }
}
