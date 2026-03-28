// MOCKUP: Prayer Detail — Phonetic Mode
// Shows the styled phonetic view with stressed syllables in red
// and syllable dots in gold. This is the core value proposition.

import SwiftUI

struct PrayerDetail_Mockup: View {
    @State private var selectedMode = 0  // 0=Missal, 1=English, 2=Latin, 3=Phonetic

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Header ──
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ave María")
                            .font(.custom("Palatino", size: 28).weight(.semibold))
                            .foregroundStyle(Color(hex: "1C1410"))

                        Text("Hail Mary")
                            .font(.custom("Georgia", size: 22).weight(.medium))
                            .foregroundStyle(.secondary)

                        Text("Rosary")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color(hex: "B8960C"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: "B8960C").opacity(0.1))
                            .clipShape(Capsule())
                    }

                    // ── Mode Toggle ──
                    HStack {
                        Spacer()
                        HStack(spacing: 0) {
                            ForEach(Array(["Missal", "English", "Latin", "Phonetic"].enumerated()), id: \.offset) { index, label in
                                Button {
                                    withAnimation { selectedMode = index }
                                } label: {
                                    Text(label)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(selectedMode == index ? .white : Color(hex: "1C1410"))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background {
                                            if selectedMode == index {
                                                Capsule().fill(Color(hex: "8B1A1A"))
                                            }
                                        }
                                }
                            }
                        }
                        .padding(3)
                        .background(Capsule().fill(Color(hex: "1C1410").opacity(0.06)))
                        Spacer()
                    }

                    // ── Gold Divider ──
                    Rectangle()
                        .fill(Color(hex: "B8960C").opacity(0.3))
                        .frame(height: 1)

                    // ── Prayer Text ──
                    if selectedMode == 3 {
                        phoneticView
                    } else if selectedMode == 0 {
                        missalView
                    } else if selectedMode == 1 {
                        Text("Hail Mary, full of grace, the Lord is with thee. Blessed art thou amongst women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.")
                            .font(.custom("Georgia", size: 18))
                            .foregroundStyle(Color(hex: "1C1410"))
                            .lineSpacing(6)
                    } else {
                        Text("Ave María, grátia plena, Dóminus tecum. Benedícta tu in muliéribus, et benedíctus fructus ventris tui, Iesus. Sancta María, Mater Dei, ora pro nobis peccatóribus, nunc et in hora mortis nostræ. Amen.")
                            .font(.custom("Palatino", size: 18))
                            .foregroundStyle(Color(hex: "1C1410"))
                            .lineSpacing(6)
                    }

                    // ── Practice Button ──
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Practice This Prayer")
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "8B1A1A"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding()
            }
            .background(Color(hex: "F5F0E8"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // ── Phonetic View ──
    private var phoneticView: some View {
        let red = Color(hex: "8B1A1A")
        let gold = Color(hex: "B8960C")
        let ink = Color(hex: "1C1410")

        return VStack(alignment: .leading, spacing: 8) {
            // Line 1
            (Text("A").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("ve").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink)
            + Text(" ").font(.custom("Palatino-Italic", size: 18))
            + Text("Ma").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("RÍ").font(.custom("Palatino-BoldItalic", size: 18)).foregroundColor(red)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("a,").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink)
            + Text(" ").font(.custom("Palatino-Italic", size: 18))
            + Text("GRÁ").font(.custom("Palatino-BoldItalic", size: 18)).foregroundColor(red)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("ti").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("a").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink)
            + Text(" ").font(.custom("Palatino-Italic", size: 18))
            + Text("PLÉ").font(.custom("Palatino-BoldItalic", size: 18)).foregroundColor(red)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("na,").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink))
            .lineSpacing(6)

            // Line 2
            (Text("DÓ").font(.custom("Palatino-BoldItalic", size: 18)).foregroundColor(red)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("mi").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("nus").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink)
            + Text(" ").font(.custom("Palatino-Italic", size: 18))
            + Text("TÉ").font(.custom("Palatino-BoldItalic", size: 18)).foregroundColor(red)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("cum.").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink))
            .lineSpacing(6)

            // Line 3
            (Text("Be").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("ne").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("DÍC").font(.custom("Palatino-BoldItalic", size: 18)).foregroundColor(red)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("ta").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink)
            + Text(" tu in mu").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("li").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("É").font(.custom("Palatino-BoldItalic", size: 18)).foregroundColor(red)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("ri").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink)
            + Text("·").font(.custom("Palatino-Italic", size: 18)).foregroundColor(gold)
            + Text("bus...").font(.custom("Palatino-Italic", size: 18)).foregroundColor(ink))
            .lineSpacing(6)
        }
    }

    // ── Missal View ──
    private var missalView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("LATINA")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "8B1A1A"))
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color(hex: "B8960C").opacity(0.4))
                    .frame(width: 1)

                Text("ENGLISH")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 12)

            Rectangle()
                .fill(Color(hex: "B8960C").opacity(0.3))
                .frame(height: 1)
                .padding(.bottom, 8)

            missalLine(
                "Ave María, grátia plena, Dóminus tecum.",
                "Hail Mary, full of grace, the Lord is with thee."
            )
            missalLine(
                "Benedícta tu in muliéribus, et benedíctus fructus ventris tui, Iesus.",
                "Blessed art thou amongst women, and blessed is the fruit of thy womb, Jesus."
            )
            missalLine(
                "Sancta María, Mater Dei, ora pro nobis peccatóribus, nunc et in hora mortis nostræ. Amen.",
                "Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen."
            )
        }
        .padding()
        .background(Color(hex: "FDFAF4"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private func missalLine(_ latin: String, _ english: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(latin)
                .font(.custom("Palatino", size: 15))
                .foregroundStyle(Color(hex: "1C1410"))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 8)

            Rectangle()
                .fill(Color(hex: "B8960C").opacity(0.2))
                .frame(width: 1)

            Text(english)
                .font(.custom("Georgia", size: 15))
                .foregroundStyle(.secondary)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
        }
        .padding(.vertical, 8)
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

#Preview("Prayer Detail — Phonetic") {
    PrayerDetail_Mockup(selectedMode: 3)
}

#Preview("Prayer Detail — Missal") {
    PrayerDetail_Mockup()
}

extension PrayerDetail_Mockup {
    init(selectedMode: Int) {
        _selectedMode = State(initialValue: selectedMode)
    }
}
