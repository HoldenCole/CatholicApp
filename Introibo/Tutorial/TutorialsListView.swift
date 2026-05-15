import SwiftUI

struct TutorialsListView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(FeatureTutorial.allCases) { feature in
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                TutorialManager.shared.startFeatureTutorial(feature)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: feature.systemImage)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.sanctuaryRed)
                                    .frame(width: 24, alignment: .center)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feature.label)
                                        .font(.body)
                                        .foregroundStyle(Color.primaryText)
                                    Text(feature.latinLabel)
                                        .font(.captionSm)
                                        .italic()
                                        .foregroundStyle(Color.tertiaryText)
                                }
                                Spacer()
                                Image(systemName: "play.circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.sanctuaryRed)
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.pageBackground)
                    }
                } footer: {
                    Text("Tutorials can be re-run anytime. Each one navigates to the relevant section and walks you through it.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("Tutorials")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.sanctuaryRed)
                }
            }
        }
    }
}
