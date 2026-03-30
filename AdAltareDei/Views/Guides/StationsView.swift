import SwiftUI

struct StationsView: View {
    @State private var stationsData: StationsData?
    @State private var currentStation = 0  // 0 = opening, 1-14 = stations, 15 = closing
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if let data = stationsData {
                if currentStation == 0 {
                    openingView(data)
                } else if currentStation <= data.stations.count {
                    stationView(data.stations[currentStation - 1])
                } else {
                    closingView(data)
                }
            } else {
                LoadingView()
            }
        }
        .background(Color(hex: "1a1410"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadData() }
    }

    // MARK: - Opening

    private func openingView(_ data: StationsData) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    Text("✟")
                        .font(.system(size: 48))
                        .foregroundStyle(.goldLeaf.opacity(0.6))

                    Text(data.title)
                        .font(.custom("Palatino", size: 26).weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(data.latinTitle)
                        .font(.custom("Palatino-Italic", size: 16))
                        .foregroundStyle(.goldLeaf)

                    Text(data.openingPrayer)
                        .font(.custom("Georgia-Italic", size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Spacer()
                }
                .padding()
            }

            navigationBar(total: (stationsData?.stations.count ?? 14) + 2)
        }
    }

    // MARK: - Station

    private func stationView(_ station: StationData) -> some View {
        VStack(spacing: 0) {
            // Progress
            progressBar(total: (stationsData?.stations.count ?? 14) + 2)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Station number and title
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Text("Station \(station.number)")
                                .font(.custom("Palatino-Italic", size: 12))
                                .foregroundStyle(.goldLeaf)
                                .tracking(2)
                                .textCase(.uppercase)

                            Text(station.title)
                                .font(.custom("Palatino", size: 22).weight(.semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)

                            Text(station.latinTitle)
                                .font(.custom("Palatino-Italic", size: 14))
                                .foregroundStyle(.goldLeaf.opacity(0.7))
                        }
                        Spacer()
                    }
                    .padding(.top, 16)

                    // Versicle
                    Text(station.versicleEnglish)
                        .font(.custom("Georgia-Italic", size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                    // Gold divider
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .goldLeaf.opacity(0.2), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)

                    // Meditation
                    Text(station.meditation)
                        .font(.custom("Georgia", size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(6)

                    // Gold divider
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .goldLeaf.opacity(0.2), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)

                    // Prayer
                    Text(station.prayer)
                        .font(.custom("Georgia-Italic", size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineSpacing(5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            navigationBar(total: (stationsData?.stations.count ?? 14) + 2)
        }
    }

    // MARK: - Closing

    private func closingView(_ data: StationsData) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.goldLeaf)

                    Text("Deo Grátias")
                        .font(.custom("Palatino", size: 28).weight(.bold))
                        .foregroundStyle(.white)

                    Text(data.closingPrayer)
                        .font(.custom("Georgia-Italic", size: 15))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Spacer()
                }
                .padding()
            }

            Button {
                dismiss()
            } label: {
                Text("Return")
                    .font(.custom("Palatino", size: 16).weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.sanctuaryRed)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Navigation

    private func progressBar(total: Int) -> some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.goldLeaf.opacity(0.1)).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2).fill(Color.sanctuaryRed).frame(width: geo.size.width * CGFloat(currentStation) / CGFloat(total), height: 3)
                }
            }
            .frame(height: 3)

            HStack {
                if currentStation > 0 && currentStation <= (stationsData?.stations.count ?? 14) {
                    Text("Station \(currentStation) of \(stationsData?.stations.count ?? 14)")
                        .font(.custom("Palatino-Italic", size: 11))
                        .foregroundStyle(.goldLeaf)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private func navigationBar(total: Int) -> some View {
        HStack(spacing: 16) {
            if currentStation > 0 {
                Button {
                    withAnimation { currentStation -= 1 }
                } label: {
                    Circle()
                        .stroke(Color.goldLeaf.opacity(0.2), lineWidth: 1)
                        .frame(width: 50, height: 50)
                        .overlay { Text("‹").font(.system(size: 20)).foregroundStyle(.white) }
                }
            }

            Button {
                withAnimation { currentStation += 1 }
            } label: {
                Text(currentStation == 0 ? "Begin" : "Next →")
                    .font(.custom("Palatino", size: 16).weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.sanctuaryRed)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .padding(.top, 12)
    }

    private func loadData() {
        guard let url = Bundle.main.url(forResource: "stations_of_the_cross", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(StationsData.self, from: data) else { return }
        stationsData = decoded
    }
}

// MARK: - Data Models
struct StationsData: Codable {
    let title: String; let latinTitle: String; let introduction: String
    let openingPrayer: String; let stations: [StationData]
    let closingPrayer: String
}
struct StationData: Codable {
    let number: Int; let title: String; let latinTitle: String
    let versicle: String; let versicleEnglish: String
    let meditation: String; let prayer: String
}
