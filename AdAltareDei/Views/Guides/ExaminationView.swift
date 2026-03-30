import SwiftUI

struct ExaminationView: View {
    @State private var examData: ExaminationData?
    @State private var expandedCommandment: Int?

    var body: some View {
        ScrollView {
            if let exam = examData {
                VStack(alignment: .leading, spacing: 0) {
                    // Dark header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exam.title)
                            .font(.custom("Palatino", size: 26).weight(.bold))
                            .foregroundStyle(.white)
                        Text(exam.latinTitle)
                            .font(.custom("Palatino-Italic", size: 14))
                            .foregroundStyle(.goldLeaf)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(LinearGradient(colors: [Color(hex: "1C1410"), Color(hex: "2a2118")], startPoint: .top, endPoint: .bottom))

                    VStack(alignment: .leading, spacing: 0) {
                        ornamentalDivider

                        // Introduction
                        Text(exam.introduction)
                            .font(.custom("Georgia-Italic", size: 15))
                            .foregroundStyle(.secondary)
                            .lineSpacing(5)
                            .padding(.vertical, 12)

                        // Preparatory Prayer
                        ornamentalDivider
                        sectionLabel("Preparatory Prayer", latin: "Oratio Præparatoria")
                        HStack(alignment: .top, spacing: 0) {
                            Rectangle().fill(Color.sanctuaryRed).frame(width: 3).padding(.trailing, 16)
                            Text(exam.preparatoryPrayer)
                                .font(.custom("Georgia-Italic", size: 15))
                                .foregroundStyle(.ink)
                                .lineSpacing(5)
                        }
                        .padding(.vertical, 8)

                        ornamentalDivider

                        // Commandments
                        sectionLabel("The Ten Commandments", latin: "Decem Præcepta")

                        ForEach(exam.commandments, id: \.number) { cmd in
                            commandmentRow(cmd)
                        }

                        // Precepts
                        ornamentalDivider
                        sectionLabel(exam.precepts.title, latin: "Præcepta Ecclesiæ")
                        ForEach(Array(exam.precepts.items.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 10) {
                                Text("·").foregroundStyle(.goldLeaf)
                                Text(item)
                                    .font(.custom("Georgia", size: 15))
                                    .foregroundStyle(.ink)
                                    .lineSpacing(4)
                            }
                            .padding(.vertical, 4)
                        }

                        // Closing Prayer
                        ornamentalDivider
                        sectionLabel("Act of Contrition", latin: "Actus Contritionis")
                        HStack(alignment: .top, spacing: 0) {
                            Rectangle().fill(Color.sanctuaryRed).frame(width: 3).padding(.trailing, 16)
                            Text(exam.closingPrayer)
                                .font(.custom("Georgia-Italic", size: 15))
                                .foregroundStyle(.ink)
                                .lineSpacing(5)
                        }
                        .padding(.vertical, 8)

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

    private func commandmentRow(_ cmd: CommandmentData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    expandedCommandment = expandedCommandment == cmd.number ? nil : cmd.number
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(cmd.number)")
                        .font(.custom("Palatino", size: 22).weight(.light))
                        .foregroundStyle(.sanctuaryRed.opacity(0.4))
                        .frame(width: 24, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cmd.commandment)
                            .font(.custom("Palatino", size: 15).weight(.medium))
                            .foregroundStyle(.ink)
                            .multilineTextAlignment(.leading)
                        Text(cmd.latinText)
                            .font(.custom("Palatino-Italic", size: 12))
                            .foregroundStyle(.goldLeaf)
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
            }

            if expandedCommandment == cmd.number {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(cmd.sins.enumerated()), id: \.offset) { _, sin in
                        HStack(alignment: .top, spacing: 10) {
                            Text("·").foregroundStyle(.sanctuaryRed)
                            Text(sin)
                                .font(.custom("Georgia", size: 14))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                        }
                    }
                }
                .padding(.leading, 36)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Rectangle().fill(Color.goldLeaf.opacity(0.08)).frame(height: 1)
        }
    }

    // MARK: - Components

    private func sectionLabel(_ title: String, latin: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                .foregroundStyle(.sanctuaryRed)
                .tracking(3)
            Text(latin)
                .font(.custom("Palatino-Italic", size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 12)
    }

    private var ornamentalDivider: some View {
        HStack { Spacer(); Rectangle().frame(height: 1).foregroundStyle(.clear).background(LinearGradient(colors: [.clear, .goldLeaf.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing)); Spacer() }.padding(.vertical, 12)
    }

    private var closingOrnament: some View {
        Text("✿ · ✿").frame(maxWidth: .infinity).font(.system(size: 12)).foregroundStyle(.goldLeaf.opacity(0.4)).tracking(8).padding(.vertical, 32)
    }

    private func loadData() {
        guard let url = Bundle.main.url(forResource: "examination_of_conscience", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ExaminationData.self, from: data) else { return }
        examData = decoded
    }
}

// MARK: - Data Models
struct ExaminationData: Codable {
    let title: String; let latinTitle: String; let introduction: String
    let preparatoryPrayer: String; let commandments: [CommandmentData]
    let precepts: PreceptsData; let closingPrayer: String
}
struct CommandmentData: Codable {
    let number: Int; let commandment: String; let latinText: String; let sins: [String]
}
struct PreceptsData: Codable { let title: String; let items: [String] }
