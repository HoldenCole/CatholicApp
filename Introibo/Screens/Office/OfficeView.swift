import SwiftUI

// The Divine Office — Officium Divinum. Shows a 24-hour canonical clock
// dial with the 8 hours placed at their traditional times. Current hour
// glows. Tapping an hour opens the full liturgy for that hour.
// Reached from Today's devotions, not a top-level tab.

struct OfficeView: View {
    @State private var store = ContentStore.shared
    @State private var selectedHour: Hour?
    @State private var showNotification = false
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue
    private var rite: MissalRite { MissalRite(rawValue: riteRaw) ?? .rite1962 }
    private var ctx: LiturgicalContext { .current() }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Officium Divínum")
                    .font(.titleL)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text("The Divine Office  ·  \(rite.short)")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .textCase(.uppercase)
                    .tracking(2)
                Text("\u{201C}\(ctx.feriaLatin)  \u{00B7}  \(ctx.latinName)\u{201D}")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.tertiaryText)
                    .padding(.top, 6)
                if rite == .pre1955 {
                    Text("Note: Under pre-1955 rubrics the Holy Week Office follows the older Triduum rites (e.g. Tenebrae on the mornings of the Sacred Triduum). Full pre-1955 Office texts are forthcoming.")
                        .font(.captionSm)
                        .foregroundStyle(Color.sanctuaryRed.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                } else if rite == .rite1955 {
                    Text("Note: Using 1955 Holy Week rubrics. The Office of the Sacred Triduum follows the pre-reform arrangement.")
                        .font(.captionSm)
                        .foregroundStyle(Color.sanctuaryRed.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                }

                ClockDial(
                    hours: store.hours,
                    currentKey: currentHourKey(),
                    onTap: { slug in
                        if let h = store.hourForToday(slug: slug) { selectedHour = h }
                    }
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .padding(.top, 12)

                Text("Tap any hour to enter its prayer.")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.tertiaryText)
                    .padding(.top, 8)
                Text("The current hour glows.")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.tertiaryText)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .navigationTitle("Officium Divinum")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showNotification = true } label: {
                    Image(systemName: NotificationStore.schedule(for: "devotion.office")?.isEnabled == true ? "bell.fill" : "bell")
                        .foregroundStyle(Color.sanctuaryRed)
                }
                .sheet(isPresented: $showNotification) {
                    NotificationScheduleSheet(scheduleId: "devotion.office", title: "Divine Office", subtitle: "Remind me to pray the Office")
                }
            }
        }
        .sheet(item: $selectedHour) { hour in
            HourView(hour: hour)
        }
    }

    /// Matches prototype logic: closest preceding canonical hour; before
    /// Matutinum roll back to the previous day's Completorium.
    private func currentHourKey() -> String {
        let cal = Calendar.liturgical
        let now = Date()
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let nowMin = h * 60 + m
        var best: (slug: String, diff: Int)? = nil
        for hour in store.hours {
            let mins = hour.hour * 60 + hour.minute
            let diff = nowMin - mins
            if diff >= 0 {
                if let b = best, diff >= b.diff { continue }
                best = (hour.slug, diff)
            }
        }
        return best?.slug ?? "completorium"
    }
}

// MARK: - Dial

private struct ClockDial: View {
    let hours: [Hour]
    let currentKey: String
    let onTap: (String) -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let c = CGPoint(x: size / 2, y: size / 2)
            let ringR = size / 2 - 8
            let nodeR = size / 2 * 0.72

            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.goldLeaf.opacity(0.5), lineWidth: 0.5)
                    .frame(width: size, height: size)
                Circle()
                    .stroke(Color.goldLeaf.opacity(0.25), lineWidth: 0.5)
                    .frame(width: size - 12, height: size - 12)
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(Color.sanctuaryRed.opacity(0.2))
                    .frame(width: size - 92, height: size - 92)

                // 24 ticks
                ForEach(0..<24, id: \.self) { i in
                    tick(for: i, ringRadius: ringR, center: c)
                }

                // Center
                VStack(spacing: 2) {
                    Text("Hora hæc")
                        .font(.captionSm)
                        .italic()
                        .foregroundStyle(Color.tertiaryText)
                        .textCase(.uppercase)
                        .tracking(2)
                    Text("✠")
                        .font(.titleL)
                        .foregroundStyle(Color.sanctuaryRed)
                }

                // 8 hour nodes
                ForEach(Array(hours.enumerated()), id: \.element.id) { idx, hour in
                    hourNode(hour, radius: nodeR, center: c, isNow: hour.slug == currentKey, index: idx, total: hours.count)
                }
            }
            .frame(width: size, height: size)
        }
    }

    private func tick(for i: Int, ringRadius: CGFloat, center: CGPoint) -> some View {
        let isMajor = i % 6 == 0
        return Rectangle()
            .fill(isMajor ? Color.sanctuaryRed.opacity(0.55) : Color.goldLeaf.opacity(0.4))
            .frame(width: isMajor ? 1.5 : 1, height: isMajor ? 14 : 8)
            .offset(y: -(ringRadius - (isMajor ? 7 : 4)))
            .rotationEffect(.degrees(Double(i) * 15))
            .position(x: center.x, y: center.y)
    }

    private func hourNode(_ hour: Hour, radius: CGFloat, center: CGPoint, isNow: Bool, index: Int, total: Int) -> some View {
        let angleDeg = (Double(index) / Double(total)) * 360.0 - 90.0
        let angleRad = angleDeg * .pi / 180.0
        let x = center.x + cos(angleRad) * radius
        let y = center.y + sin(angleRad) * radius

        return Button { onTap(hour.slug) } label: {
            VStack(spacing: 1) {
                Text(hour.glyph)
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.sanctuaryRed)
                Text(formatTime(h: hour.hour, m: hour.minute))
                    .font(.system(size: 8, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(Color.tertiaryText)
            }
            .frame(width: 48, height: 48)
            .background(isNow ? Color.goldLeaf.opacity(0.12) : Color.pageBackground)
            .overlay(
                Circle().stroke(
                    isNow ? Color.goldLeaf : Color.goldLeaf.opacity(0.55),
                    lineWidth: isNow ? 1 : 0.5
                )
            )
            .clipShape(Circle())
            .shadow(color: isNow ? Color.goldLeaf.opacity(0.4) : .clear, radius: 12)
        }
        .buttonStyle(.plain)
        .position(x: x, y: y)
    }

    private func formatTime(h: Int, m: Int) -> String {
        let hh = h % 12 == 0 ? 12 : h % 12
        let mm = m < 10 ? "0\(m)" : "\(m)"
        let suffix = h < 12 ? "AM" : "PM"
        return "\(hh):\(mm) \(suffix)"
    }
}
