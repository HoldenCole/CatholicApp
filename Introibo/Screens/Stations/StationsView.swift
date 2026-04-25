import SwiftUI

struct StationsView: View {
    @State private var store = ContentStore.shared
    @State private var activeIndex: Int? = nil
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue

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

    private var startList: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Text("✠")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.sanctuaryRed.opacity(0.6))
                        .padding(.top, 24)
                    Text("Via Crucis")
                        .font(.pageTitle)
                        .foregroundStyle(Color.ivory)
                    Text("The Way of the Cross")
                        .font(.caption)
                        .italic()
                        .foregroundStyle(Color.muted)
                        .textCase(.uppercase)
                        .tracking(2.5)
                    Text("XIV Statiónes")
                        .font(.captionSm)
                        .italic()
                        .foregroundStyle(Color.muted)
                        .padding(.top, 2)
                    Rectangle()
                        .fill(Color.sanctuaryRed.opacity(0.4))
                        .frame(width: 60, height: 1)
                        .padding(.top, 14)
                        .padding(.bottom, 18)
                }
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [Color.walnut, Color.walnutHi], startPoint: .top, endPoint: .bottom)
                )

                // Winding path
                VStack(spacing: 0) {
                    ForEach(Array(store.stations.enumerated()), id: \.offset) { idx, s in
                        Button { activeIndex = idx } label: {
                            windingStop(s, index: idx)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 28)
                .padding(.horizontal, 20)

                Button { activeIndex = 0 } label: {
                    VStack(spacing: 8) {
                        Text("✠")
                            .font(.titleL)
                            .foregroundStyle(Color.sanctuaryRed)
                        Text("Incipiámus")
                            .font(.titleL)
                            .italic()
                            .foregroundStyle(Color.sanctuaryRed)
                        Text("Begin the Way of the Cross")
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.secondaryText)
                            .textCase(.uppercase)
                            .tracking(2)
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .overlay(Rectangle().stroke(Color.sanctuaryRed.opacity(0.5), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .background(Color.pageBackground.ignoresSafeArea())
    }

    private func windingStop(_ s: Station, index: Int) -> some View {
        let isLeft = index % 2 == 0
        let moodColor = stationColor(s)

        return HStack(spacing: 0) {
            if !isLeft { Spacer(minLength: 0) }

            HStack(spacing: 14) {
                if isLeft {
                    stationMarker(s, index: index, color: moodColor)
                    stationInfo(s, alignment: .leading)
                } else {
                    stationInfo(s, alignment: .trailing)
                    stationMarker(s, index: index, color: moodColor)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: 320, alignment: isLeft ? .leading : .trailing)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(moodColor.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(moodColor.opacity(0.2), lineWidth: 0.5)
            )

            if isLeft { Spacer(minLength: 0) }
        }
        .overlay(
            pathConnector(index: index)
        )
        .padding(.bottom, 4)
    }

    private func stationMarker(_ s: Station, index: Int, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 48, height: 48)
            Circle()
                .stroke(color.opacity(0.6), lineWidth: 1.5)
                .frame(width: 48, height: 48)
            Text(s.station)
                .font(.system(size: 16, weight: .bold, design: .serif))
                .italic()
                .foregroundStyle(color)
        }
    }

    private func stationInfo(_ s: Station, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(s.title)
                .font(.titleM)
                .italic()
                .foregroundStyle(Color.primaryText)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            Text(s.latin)
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        }
    }

    @ViewBuilder
    private func pathConnector(index: Int) -> some View {
        if index < store.stations.count - 1 {
            let isLeft = index % 2 == 0
            GeometryReader { geo in
                Path { path in
                    let startX = isLeft ? geo.size.width * 0.3 : geo.size.width * 0.7
                    let endX = isLeft ? geo.size.width * 0.7 : geo.size.width * 0.3
                    path.move(to: CGPoint(x: startX, y: geo.size.height))
                    path.addQuadCurve(
                        to: CGPoint(x: endX, y: geo.size.height + 8),
                        control: CGPoint(x: geo.size.width * 0.5, y: geo.size.height + 14)
                    )
                }
                .stroke(
                    Color.sanctuaryRed.opacity(0.2),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
            }
            .allowsHitTesting(false)
        }
    }

    private func stationColor(_ s: Station) -> Color {
        switch s.mood {
        case "mood-death":  return Color.sanctuaryRed
        case "mood-mother": return Color.goldLeaf
        case "mood-tomb":   return Color.gray
        default:            return Color.sanctuaryRed.opacity(0.7)
        }
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
                .padding(.bottom, 120)
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
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("℣. Adorámus te, Christe, et benedícimus tibi.")
                    .font(.bodyIt)
                    .foregroundStyle(Color.ivory)
                Text("We adore Thee, O Christ, and we bless Thee.")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.muted)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("℟. Quia per sanctam Crucem tuam redemísti mundum.")
                    .font(.bodyIt)
                    .foregroundStyle(Color.ivory)
                Text("Because by Thy holy Cross Thou hast redeemed the world.")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.muted)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Pater Noster  ·  Ave María  ·  Glória Patri")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.goldLeaf)
                    .padding(.top, 4)
            }
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
