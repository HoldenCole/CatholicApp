import SwiftUI

struct DailyReadingsView: View {
    @State private var readingsData: ReadingsFileData?

    var body: some View {
        ScrollView {
            if let data = readingsData, let reading = data.readings.first {
                VStack(alignment: .leading, spacing: 0) {
                    // Dark header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Readings")
                            .font(.custom("Palatino", size: 26).weight(.bold))
                            .foregroundStyle(.white)
                        Text("Lectiones Diurnæ")
                            .font(.custom("Palatino-Italic", size: 14))
                            .foregroundStyle(.goldLeaf)
                        HStack(spacing: 8) {
                            Text(reading.occasionEnglish)
                                .font(.custom("Georgia", size: 13))
                                .foregroundStyle(.white.opacity(0.5))
                            if let color = reading.color {
                                Circle()
                                    .fill(liturgicalColor(color))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(LinearGradient(colors: [Color(hex: "1C1410"), Color(hex: "2a2118")], startPoint: .top, endPoint: .bottom))

                    VStack(alignment: .leading, spacing: 0) {
                        ornamentalDivider

                        // Epistle
                        sectionLabel("Epistle", latin: "Epistola")
                        Text(reading.epistle.reference)
                            .font(.custom("Palatino-Italic", size: 13))
                            .foregroundStyle(.goldLeaf)
                            .padding(.bottom, 8)

                        // Side-by-side
                        missalColumns(latin: reading.epistle.latinText, english: reading.epistle.englishText)

                        ornamentalDivider

                        // Gospel
                        sectionLabel("Gospel", latin: "Evangelium")
                        Text(reading.gospel.reference)
                            .font(.custom("Palatino-Italic", size: 13))
                            .foregroundStyle(.goldLeaf)
                            .padding(.bottom, 8)

                        missalColumns(latin: reading.gospel.latinText, english: reading.gospel.englishText)

                        closingOrnament
                    }
                    .padding(.horizontal, 24)
                }
            } else {
                LoadingView()
            }
        }
        .background(Color.parchment)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadData() }
    }

    private func missalColumns(latin: String, english: String) -> some View {
        let latinLines = latin.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let englishLines = english.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let lineCount = max(latinLines.count, englishLines.count)

        return VStack(spacing: 0) {
            ForEach(0..<lineCount, id: \.self) { index in
                HStack(alignment: .top, spacing: 0) {
                    Text(index < latinLines.count ? latinLines[index] : "")
                        .font(.custom("Palatino", size: 15))
                        .foregroundStyle(.ink)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 10)
                    Rectangle().fill(Color.goldLeaf.opacity(0.2)).frame(width: 1)
                    Text(index < englishLines.count ? englishLines[index] : "")
                        .font(.custom("Georgia", size: 15))
                        .foregroundStyle(.secondary)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 10)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func liturgicalColor(_ color: String) -> Color {
        switch color {
        case "violet": return .purple
        case "white": return .white
        case "red": return .sanctuaryRed
        case "green": return .comfortMastered
        case "black": return .ink
        case "rose": return .pink
        default: return .goldLeaf
        }
    }

    private func sectionLabel(_ title: String, latin: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                .foregroundStyle(.sanctuaryRed).tracking(3)
            Text(latin)
                .font(.custom("Palatino-Italic", size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    private var ornamentalDivider: some View {
        HStack { Spacer(); Rectangle().frame(height: 1).foregroundStyle(.clear).background(LinearGradient(colors: [.clear, .goldLeaf.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing)); Spacer() }.padding(.vertical, 12)
    }

    private var closingOrnament: some View {
        Text("✿ · ✿").frame(maxWidth: .infinity).font(.system(size: 12)).foregroundStyle(.goldLeaf.opacity(0.4)).tracking(8).padding(.vertical, 32)
    }

    private func loadData() {
        guard let url = Bundle.main.url(forResource: "daily_readings_sample", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ReadingsFileData.self, from: data) else { return }
        readingsData = decoded
    }
}

// MARK: - Data Models
struct ReadingsFileData: Codable { let readings: [ReadingDayData] }
struct ReadingDayData: Codable {
    let occasion: String; let occasionEnglish: String; let rank: String?
    let color: String?; let epistle: ReadingTextData; let gospel: ReadingTextData
}
struct ReadingTextData: Codable {
    let reference: String; let latinText: String; let englishText: String
}
