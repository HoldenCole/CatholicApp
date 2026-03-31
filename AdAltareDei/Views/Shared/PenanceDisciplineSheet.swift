import SwiftUI

struct PenanceDisciplineSheet: View {
    @EnvironmentObject private var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Choose Your Penance Discipline")
                        .font(.custom("Palatino", size: 22).weight(.bold))
                        .foregroundStyle(.ink)

                    Text("Select which fasting and abstinence practices you follow")
                        .font(.custom("Palatino-Italic", size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                        .padding(.bottom, 20)

                    ForEach(PenanceDiscipline.allCases) { discipline in
                        Button {
                            appSettings.penanceDiscipline = discipline
                        } label: {
                            HStack(alignment: .top, spacing: 0) {
                                Rectangle()
                                    .fill(appSettings.penanceDiscipline == discipline ? Color.sanctuaryRed : Color.clear)
                                    .frame(width: 3)
                                    .padding(.trailing, 16)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(discipline.displayName)
                                        .font(.custom("Palatino", size: 17).weight(.medium))
                                        .foregroundStyle(appSettings.penanceDiscipline == discipline ? .ink : .secondary)

                                    Text(discipline.latinName)
                                        .font(.custom("Palatino-Italic", size: 12))
                                        .foregroundStyle(.goldLeaf)
                                        .opacity(appSettings.penanceDiscipline == discipline ? 1 : 0.6)

                                    Text(discipline.subtitle)
                                        .font(.custom("Georgia", size: 13))
                                        .foregroundStyle(.secondary)
                                        .lineSpacing(4)
                                        .padding(.top, 2)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.goldLeaf.opacity(0.06))
                                    .frame(height: 1)
                            }
                        }
                    }

                    // Note
                    HStack {
                        Spacer()
                        Rectangle().frame(height: 1).foregroundStyle(.clear)
                            .background(LinearGradient(colors: [.clear, .goldLeaf.opacity(0.2), .clear], startPoint: .leading, endPoint: .trailing))
                        Spacer()
                    }
                    .padding(.vertical, 16)

                    Text("If you are following a saint's practices, their specific penances will also appear on your daily screen in addition to the discipline selected here.")
                        .font(.custom("Georgia-Italic", size: 13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)

                    Text("You can change this anytime in Settings.")
                        .font(.custom("Georgia-Italic", size: 13))
                        .foregroundStyle(.goldLeaf)
                        .padding(.top, 8)
                }
                .padding(24)
            }
            .background(Color.parchment)
            .navigationTitle("Penance Discipline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.sanctuaryRed)
                }
            }
        }
    }
}
