// MOCKUP: Missal Side-by-Side View
// This file is a visual reference — not compiled into the app.
// The key differentiator: side-by-side Latin/English like a printed missal.

import SwiftUI

struct MissalView_Mockup: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Header ──
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sanctus")
                            .font(.custom("Palatino", size: 28).weight(.semibold))
                            .foregroundStyle(Color(hex: "1C1410"))

                        Text("Holy, Holy, Holy")
                            .font(.custom("Georgia", size: 22).weight(.medium))
                            .foregroundStyle(.secondary)

                        Text("Missa Fidelium")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color(hex: "8B1A1A"))
                    }

                    // ── Rubric ──
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "hand.point.right")
                            .foregroundStyle(Color(hex: "8B1A1A"))
                            .font(.system(size: 14))

                        Text("At the conclusion of the Preface, all kneel as the bells ring. The Sanctus begins the Canon of the Mass.")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundStyle(Color(hex: "8B1A1A").opacity(0.8))
                            .lineSpacing(4)
                    }
                    .padding()
                    .background(Color(hex: "8B1A1A").opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // ── Side-by-Side Missal ──
                    VStack(spacing: 0) {
                        // Column headers
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
                            .padding(.bottom, 12)

                        // Line-by-line
                        missalLine(
                            latin: "Sanctus, Sanctus, Sanctus, Dóminus Deus Sábaoth.",
                            english: "Holy, Holy, Holy, Lord God of Hosts."
                        )
                        thinDivider

                        missalLine(
                            latin: "Pleni sunt cæli et terra glória tua.",
                            english: "Heaven and earth are full of Thy glory."
                        )
                        thinDivider

                        missalLine(
                            latin: "Hosánna in excélsis.",
                            english: "Hosanna in the highest."
                        )
                        thinDivider

                        missalLine(
                            latin: "✠ Benedíctus qui venit in nómine Dómini.",
                            english: "✠ Blessed is He Who cometh in the name of the Lord."
                        )
                        thinDivider

                        missalLine(
                            latin: "Hosánna in excélsis.",
                            english: "Hosanna in the highest."
                        )
                    }
                    .padding()
                    .background(Color(hex: "FDFAF4"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                }
                .padding()
            }
            .background(Color(hex: "F5F0E8"))
            .navigationTitle("Missal")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func missalLine(latin: String, english: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(latin)
                .font(.custom("Palatino", size: 16))
                .foregroundStyle(Color(hex: "1C1410"))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 10)

            Rectangle()
                .fill(Color(hex: "B8960C").opacity(0.25))
                .frame(width: 1)

            Text(english)
                .font(.custom("Georgia", size: 16))
                .foregroundStyle(.secondary)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)
        }
        .padding(.vertical, 8)
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(Color(hex: "B8960C").opacity(0.08))
            .frame(height: 1)
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

#Preview("Missal Detail — Sanctus") {
    MissalView_Mockup()
}
