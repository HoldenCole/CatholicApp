import SwiftUI

/// Choose which saint(s) to follow.
struct SaintSelectorView: View {
    @State private var saints: [SaintProfile] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Dark header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Practices of the Saints")
                        .font(.custom("Palatino", size: 24).weight(.bold))
                        .foregroundStyle(.white)
                    Text("Praxes Sanctorum")
                        .font(.custom("Palatino-Italic", size: 14))
                        .foregroundStyle(.goldLeaf)
                    Text("Choose a saint to follow their rule of life.")
                        .font(.custom("Georgia-Italic", size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "1C1410"), Color(hex: "2a2118")],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(saints) { saint in
                        NavigationLink {
                            SaintProfileView(saint: saint)
                        } label: {
                            HStack(alignment: .top, spacing: 0) {
                                Rectangle()
                                    .fill(Color.sanctuaryRed)
                                    .frame(width: 3)
                                    .padding(.trailing, 16)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(saint.name)
                                        .font(.custom("Palatino", size: 18).weight(.semibold))
                                        .foregroundStyle(.ink)

                                    Text(saint.title)
                                        .font(.custom("Palatino-Italic", size: 13))
                                        .foregroundStyle(.goldLeaf)

                                    Text(saint.charism)
                                        .font(.custom("Georgia", size: 13))
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(3)
                                        .padding(.top, 2)

                                    HStack(spacing: 12) {
                                        Text(saint.feastDay)
                                            .font(.custom("Georgia", size: 11))
                                            .foregroundStyle(.secondary)
                                        Text("·")
                                            .foregroundStyle(.goldLeaf.opacity(0.4))
                                        Text(saint.era)
                                            .font(.custom("Georgia", size: 11))
                                            .foregroundStyle(.secondary)
                                        Text("·")
                                            .foregroundStyle(.goldLeaf.opacity(0.4))
                                        Text("\(saint.dailyPractices.count) daily practices")
                                            .font(.custom("Georgia", size: 11))
                                            .foregroundStyle(.sanctuaryRed)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(.vertical, 18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, .goldLeaf.opacity(0.15), .clear],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Text("✿ · ✿")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 12))
                        .foregroundStyle(.goldLeaf.opacity(0.4))
                        .tracking(8)
                        .padding(.vertical, 28)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color.parchment)
        .navigationTitle("Saints")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadSaints() }
    }

    private func loadSaints() {
        let files = ["saint_padre_pio", "saint_therese", "saint_thomas_aquinas", "saint_benedict", "saint_teresa_avila", "saint_escriva", "saint_francis_de_sales"]
        saints = files.compactMap { file in
            guard let url = Bundle.main.url(forResource: file, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(SaintProfile.self, from: data) else { return nil }
            return decoded
        }
    }
}
