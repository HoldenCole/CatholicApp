import SwiftUI
import WidgetKit

// MARK: - WidgetSettingsView
//
// The home-screen widget's small configuration surface: mode, and (for the
// chosen-prayer mode) one prayer per time slot. Deliberately minimal — more
// slots / per-day rules / multiple prayers belong to the future Rule-
// integration mode, not here. No tracking options exist or may be added
// (wellbeing CUT LINE).
//
// Picking a prayer also denormalizes its display titles into the shared
// defaults so the widget extension can render them without carrying the full
// prayer corpus.
//
// Android mirror: ui/widget/WidgetSettingsScreen.kt

struct WidgetSettingsView: View {
    @State private var mode = WidgetConfigStore.mode
    @State private var readingChoice = WidgetSnapshotStore.readingText
    @State private var saintsChoice = WidgetSnapshotStore.saintsFilter
    /// Bumped after a slot pick so the rows re-read the store.
    @State private var revision = 0

    private let store = ContentStore.shared

    var body: some View {
        List {
            Section {
                Text("The widget offers the right prayer for this part of the day. It is an invitation, never a scorekeeper.")
                    .font(.bodyIt)
                    .foregroundStyle(Color.secondaryText)
                    .listRowBackground(Color.pageBackground)
            }

            Section {
                modeRow(
                    .office,
                    title: "Divine Office",
                    subtitle: "The canonical hour for the current time"
                )
                modeRow(
                    .prayer,
                    title: "Chosen prayers",
                    subtitle: "Your own prayer for morning, midday, and evening"
                )
            } header: {
                Text("Modus · Mode")
            }

            if mode == .prayer {
                Section {
                    ForEach(WidgetSlot.allCases, id: \.rawValue) { slot in
                        slotRow(slot)
                    }
                } header: {
                    Text("Orationes · Slot Prayers")
                }
                .id(revision)
            }

            Section {
                ForEach(WidgetReadingText.allCases, id: \.rawValue) { choice in
                    Button {
                        readingChoice = choice
                        WidgetSnapshotStore.readingText = choice
                        WidgetCenter.shared.reloadAllTimelines()
                    } label: {
                        HStack {
                            Text(choice.label)
                                .font(.body)
                                .foregroundStyle(Color.primaryText)
                            Spacer()
                            if readingChoice == choice {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.sanctuaryRed)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.pageBackground)
                }
            } header: {
                Text("Lectio · Reading Widget")
            } footer: {
                Text("The text the Daily Reading widget quotes from each day's Mass propers. The small Today's Feast widget needs no configuration — it always shows the liturgical day.")
            }

            Section {
                ForEach(WidgetSaintsFilter.allCases, id: \.rawValue) { choice in
                    Button {
                        saintsChoice = choice
                        WidgetSnapshotStore.saintsFilter = choice
                        WidgetCenter.shared.reloadAllTimelines()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(choice.label)
                                    .font(.body)
                                    .foregroundStyle(Color.primaryText)
                                Text(choice.detail)
                                    .font(.captionSm)
                                    .foregroundStyle(Color.tertiaryText)
                            }
                            Spacer()
                            if saintsChoice == choice {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.sanctuaryRed)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.pageBackground)
                }
            } header: {
                Text("Sancti · Saints Widget")
            } footer: {
                Text("Who appears in the Sanctorale widget's upcoming list. It always shows the Church's calendar — never a score.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pageBackground)
        .navigationTitle("Home Screen Widget")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func modeRow(_ value: WidgetMode, title: String, subtitle: String) -> some View {
        Button {
            mode = value
            WidgetConfigStore.mode = value
        } label: {
            HStack {
                Image(systemName: mode == value ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(mode == value ? Color.sanctuaryRed : Color.tertiaryText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(Color.primaryText)
                    Text(subtitle)
                        .font(.captionSm)
                        .foregroundStyle(Color.tertiaryText)
                }
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.pageBackground)
    }

    private func slotRow(_ slot: WidgetSlot) -> some View {
        let slug = WidgetConfigStore.slotPrayer(slot)
        let prayer = store.prayer(slug: slug)
        return NavigationLink {
            WidgetPrayerPicker(slot: slot) { revision += 1 }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.label)
                    .font(.captionSm)
                    .foregroundStyle(Color.tertiaryText)
                Text(prayer?.title ?? slug)
                    .font(.body)
                    .foregroundStyle(Color.primaryText)
            }
        }
        .listRowBackground(Color.pageBackground)
    }
}

/// Assign one prayer to one slot, from the existing prayer corpus grouped by
/// category (reuses the corpus, not a new picker paradigm).
private struct WidgetPrayerPicker: View {
    let slot: WidgetSlot
    var onPicked: () -> Void

    @Environment(\.dismiss) private var dismiss
    private let store = ContentStore.shared

    private var grouped: [(category: String, prayers: [Prayer])] {
        Dictionary(grouping: store.prayers, by: { $0.category })
            .map { (category: $0.key, prayers: $0.value) }
            .sorted { $0.category < $1.category }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.category) { group in
                Section {
                    ForEach(group.prayers) { prayer in
                        Button {
                            // Denormalize the display titles FIRST — the slot
                            // setter triggers a timeline reload, and the
                            // extension must not race an unwritten title.
                            WidgetConfigStore.defaults.set(
                                prayer.title, forKey: "widget.title.\(prayer.slug)")
                            WidgetConfigStore.defaults.set(
                                prayer.eng, forKey: "widget.eng.\(prayer.slug)")
                            WidgetConfigStore.setSlotPrayer(slot, slug: prayer.slug)
                            onPicked()
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(prayer.title)
                                        .font(.body)
                                        .foregroundStyle(Color.primaryText)
                                    Text(prayer.eng)
                                        .font(.captionSm)
                                        .foregroundStyle(Color.tertiaryText)
                                }
                                Spacer()
                                if prayer.slug == WidgetConfigStore.slotPrayer(slot) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.sanctuaryRed)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.pageBackground)
                    }
                } header: {
                    Text(group.category)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pageBackground)
        .navigationTitle("\(slot.label) prayer")
        .navigationBarTitleDisplayMode(.inline)
    }
}
