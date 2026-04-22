import SwiftUI

// Stations of the Cross — Via Crucis.
// Two-screen flow on one view:
//   • Start: list of all 14 stations, with a "Begin the Way" button.
//   • Pray:  one station at a time with back/next navigation.
// Mirrors prototype/stations.html.

struct StationsView: View {
    @State private var store = ContentStore.shared
    @State private var activeIndex: Int? = nil

    var body: some View {
        Group {
            if let idx = activeIndex {
                PrayStationView(
                    stations: store.stations,
                    index: idx,
                    onBack:  { activeIndex = max(idx - 1, 0) },
                    onNext:  { activeIndex = idx + 1 < store.stations.count ? idx + 1 : nil },
                    onClose: { activeIndex = nil }
                )
                .transition(.opacity)
            } else {
                startList
            }
        }
        .navigationTitle("Via Crucis")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Start list

    private var startList: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Stations of the Cross")
                    .font(.titleL)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                    .padding(.top, 8)
                Text("XIV statiónes Viæ Crucis")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .textCase(.uppercase)
                    .tracking(2)

                ForEach(Array(store.stations.enumerated()), id: \.offset) { idx, s in
                    Button { activeIndex = idx } label: {
                        stationRow(s)
                    }
                    .buttonStyle(.plain)
                }

                Button { activeIndex = 0 } label: {
                    Text("Incipiámus  ✠  Begin the Way")
                        .smallLabel(color: Color.sanctuaryRed, tracking: 3)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .overlay(Rectangle().stroke(Color.sanctuaryRed.opacity(0.6), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .background(Color.pageBackground.ignoresSafeArea())
    }

    private func stationRow(_ s: Station) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(s.station)
                .font(.titleL)
                .italic()
                .foregroundStyle(Color.sanctuaryRed)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.title)
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text(s.latin)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Praying a single station

private struct PrayStationView: View {
    let stations: [Station]
    let index: Int
    let onBack:  () -> Void
    let onNext:  () -> Void
    let onClose: () -> Void

    private var station: Station { stations[index] }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .center, spacing: 18) {
                    Text("Státio \(station.station)  ·  \(index + 1) of 14")
                        .smallLabel(color: Color.goldLeaf)
                        .padding(.top, 12)
                    Text(station.station)
                        .font(.system(size: 96, weight: .semibold, design: .serif))
                        .italic()
                        .foregroundStyle(numeralColor)
                        .shadow(color: numeralColor.opacity(0.25), radius: 24)
                    Text(station.title)
                        .font(.titleL)
                        .italic()
                        .foregroundStyle(Color.ivory)
                        .multilineTextAlignment(.center)
                    Text(station.latin)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(Color.muted)
                        .textCase(.uppercase)
                        .tracking(2.5)
                        .multilineTextAlignment(.center)

                    Divider().background(Color.goldLeaf.opacity(0.3))
                        .padding(.vertical, 8)

                    versicle

                    Text(station.med)
                        .font(.body)
                        .foregroundStyle(Color.ivory)
                        .lineSpacing(4)
                        .padding(.top, 10)

                    Divider().background(Color.goldLeaf.opacity(0.3))
                        .padding(.vertical, 8)

                    stabatBlock
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 120)   // room for the nav bar
            }

            navBar
        }
        .background(
            LinearGradient(colors: [Color.walnut, Color.walnutHi], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("‹ Via") { onClose() }
                    .foregroundStyle(Color.goldLeaf)
            }
        }
    }

    private var versicle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("℣. Adorámus te, Christe, et benedícimus tibi.")
                .font(.bodyIt)
                .foregroundStyle(Color.ivory)
            Text("℟. Quia per sanctam Crucem tuam redemísti mundum.")
                .font(.bodyIt)
                .foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stabatBlock: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Orátio  ·  Stabat Mater")
                .smallLabel(color: Color.goldLeaf)
            Text(htmlToMultiline(station.stabat_lat))
                .font(.bodyIt)
                .foregroundStyle(Color.ivory)
                .multilineTextAlignment(.center)
            Text(htmlToMultiline(station.stabat_eng))
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
    }

    private var navBar: some View {
        HStack(spacing: 18) {
            Button {
                onBack()
            } label: {
                Text("‹")
                    .font(.system(size: 22, design: .serif))
                    .foregroundStyle(Color.goldLeaf)
                    .frame(width: 52, height: 52)
                    .overlay(Rectangle().stroke(Color.goldLeaf.opacity(0.55), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(index == 0)
            .opacity(index == 0 ? 0.4 : 1)

            Button {
                onNext()
            } label: {
                Text(index + 1 < 14 ? "Sequens  ✠  Next Station" : "Finis  ✠  Finish")
                    .smallLabel(color: Color.ivory, tracking: 3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Color.goldLeaf.opacity(0.12))
                    .overlay(Rectangle().stroke(Color.goldLeaf, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 36)
        .background(
            LinearGradient(colors: [Color.walnut.opacity(0), Color.walnut], startPoint: .top, endPoint: .bottom)
        )
    }

    private var numeralColor: Color {
        switch station.mood {
        case "mood-death": return Color.sanctuaryRed
        case "mood-mother": return Color.goldLeaf
        case "mood-tomb": return Color.gray
        default: return Color.sanctuaryRed.opacity(0.5)
        }
    }

    private func htmlToMultiline(_ s: String) -> String {
        s.replacingOccurrences(of: "<br>", with: "\n")
         .replacingOccurrences(of: "<br/>", with: "\n")
         .replacingOccurrences(of: "<br />", with: "\n")
         .strippingEm
    }
}
