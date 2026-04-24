import SwiftUI

struct OptionalPenanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = OptionalPenances.selectedIDs()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose voluntary penances to observe today. These are not obligatory but are meritorious offerings to God.")
                        .font(.bodySm)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                        .lineSpacing(3)
                        .padding(.bottom, 4)

                    ForEach(OptionalPenances.all) { penance in
                        Button {
                            let isSelected = selected.contains(penance.id)
                            OptionalPenances.setSelected(penance.id, selected: !isSelected)
                            if isSelected { selected.remove(penance.id) }
                            else { selected.insert(penance.id) }
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: selected.contains(penance.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(selected.contains(penance.id) ? Color.sanctuaryRed : Color.tertiaryText)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(penance.title)
                                        .font(.titleM)
                                        .italic()
                                        .foregroundStyle(Color.primaryText)
                                    Text(penance.latin)
                                        .font(.captionSm)
                                        .italic()
                                        .foregroundStyle(Color.goldLeaf)
                                    Text(penance.desc)
                                        .font(.captionSm)
                                        .foregroundStyle(Color.secondaryText)
                                        .lineSpacing(2)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if penance.id != OptionalPenances.all.last?.id {
                            Divider().background(Color.frameLine.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("Voluntary Penances")
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
