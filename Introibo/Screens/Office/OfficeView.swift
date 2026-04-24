import SwiftUI

// The Divine Office — Officium Divinum. Shows a 24-hour canonical clock
// dial with the 8 hours placed at their traditional times. Current hour
// glows. Tapping an hour opens the full liturgy for that hour.
// Reached from Today's devotions, not a top-level tab.

struct OfficeView: View {
    @State private var store = ContentStore.shared
    @State private var selectedHour: Hour?
    private let ctx = LiturgicalContext.current()

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Officium Divínum")
                    .font(.titleL)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text("The Divine Office  ·  1962 Roman Breviary")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .textCase(.uppercase)
                    .tracking(2)
                Text("“\(ctx.feriaLatin)  ·  \(ctx.latinName)”")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.tertiaryText)
                    .padding(.top, 6)

                ClockDial(
                    hours: store.hours,
                    currentKey: currentHourKey(),
                    onTap: { slug in
                        if let h = store.hour(slug: slug) { selectedHour = h }
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
            let nodeR: CGFloat = 110

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
                ForEach(hours) { hour in
                    hourNode(hour, radius: nodeR, center: c, isNow: hour.slug == currentKey)
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

    private func hourNode(_ hour: Hour, radius: CGFloat, center: CGPoint, isNow: Bool) -> some View {
        // Convert hour:minute to angle (0 = top, clockwise).
        let totalMin = Double(hour.hour * 60 + hour.minute)
        let angleDeg = (totalMin / (24.0 * 60.0)) * 360.0 - 90.0
        let angleRad = angleDeg * .pi / 180.0
        let x = center.x + cos(angleRad) * radius
        let y = center.y + sin(angleRad) * radius

        return Button { onTap(hour.slug) } label: {
            VStack(spacing: 1) {
                Text(hour.glyph)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(Color.sanctuaryRed)
                Text(formatTime(h: hour.hour, m: hour.minute))
                    .font(.system(size: 8, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(Color.tertiaryText)
            }
            .frame(width: 48, height: 48)
            .background(isNow ? Color.goldLeaf.opacity(0.12) : Color.parchment)
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
