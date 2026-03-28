// MOCKUP: Today Tab
// This file is a visual reference — not compiled into the app.
// Copy to Xcode Previews to see the rendered design.

import SwiftUI

struct TodayTab_Mockup: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Feria Header ──
                    VStack(alignment: .leading, spacing: 6) {
                        Text("FERIA SEXTA")
                            .font(.custom("Palatino", size: 14))
                            .foregroundStyle(Color(hex: "B8960C"))
                            .tracking(1.5)

                        Text("Friday")
                            .font(.custom("Georgia", size: 28).weight(.semibold))
                            .foregroundStyle(Color(hex: "1C1410"))

                        Text("March 28, 2026")
                            .font(.custom("Georgia", size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // ── Section Header ──
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MYSTERIA DOLOROSA")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(1.2)
                        Text("Sorrowful Mysteries")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }

                    // ── Mystery Cards ──
                    ForEach(1...5, id: \.self) { num in
                        mysteryCard(
                            number: num,
                            latin: ["Agonia in Horto", "Flagellatio", "Coronatio Spinis", "Bajulatio Crucis", "Crucifixio"][num - 1],
                            english: ["The Agony in the Garden", "The Scourging at the Pillar", "The Crowning with Thorns", "The Carrying of the Cross", "The Crucifixion"][num - 1],
                            ref: ["Lk 22:39–46", "Mk 15:6–15", "Mk 15:16–20", "Lk 23:26–32", "Lk 23:33–46"][num - 1]
                        )
                    }

                    // ── Quick Section ──
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ROSARY PRAYERS")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(1.2)

                        Text("Open the Prayers tab to browse all prayers with Latin text, phonetic guides, and reference recordings.")
                            .font(.custom("Georgia", size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .background(Color(hex: "F5F0E8"))
            .navigationTitle("Today")
        }
    }

    private func mysteryCard(number: Int, latin: String, english: String, ref: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "8B1A1A").opacity(0.1))
                    .frame(width: 40, height: 40)
                Text("\(number)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "8B1A1A"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(latin)
                    .font(.custom("Palatino", size: 18))
                    .foregroundStyle(Color(hex: "1C1410"))
                Text(english)
                    .font(.custom("Georgia", size: 14))
                    .foregroundStyle(.secondary)
                Text(ref)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color(hex: "B8960C"))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(hex: "FDFAF4"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

// Hex helper for mockup files (standalone)
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

#Preview("Today Tab — Light") {
    TodayTab_Mockup()
}

#Preview("Today Tab — Dark") {
    TodayTab_Mockup()
        .preferredColorScheme(.dark)
}
