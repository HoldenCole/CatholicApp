import SwiftUI

struct DivineOfficeView: View {
    let hours: [OfficeHour] = [
        OfficeHour(name: "Matins", latinName: "Matutinum", time: "During the night", icon: "moon.stars", description: "The longest hour. Psalms, readings, and responsories prayed in the night watches."),
        OfficeHour(name: "Lauds", latinName: "Laudes", time: "Dawn", icon: "sunrise", description: "Morning praise. The Church greets the rising sun as a figure of the Risen Christ."),
        OfficeHour(name: "Prime", latinName: "Prima", time: "~6:00 AM", icon: "sun.horizon", description: "The first hour. Consecration of the day's work to God."),
        OfficeHour(name: "Terce", latinName: "Tertia", time: "~9:00 AM", icon: "sun.min", description: "The third hour. The Holy Ghost descended at Terce on Pentecost."),
        OfficeHour(name: "Sext", latinName: "Sexta", time: "~12:00 PM", icon: "sun.max", description: "The sixth hour. Our Lord was crucified at Sext."),
        OfficeHour(name: "None", latinName: "Nona", time: "~3:00 PM", icon: "sun.haze", description: "The ninth hour. Our Lord died on the Cross at None."),
        OfficeHour(name: "Vespers", latinName: "Vesperae", time: "Evening", icon: "sunset", description: "Evening prayer. The most solemn of the day hours, often chanted publicly."),
        OfficeHour(name: "Compline", latinName: "Completorium", time: "Before sleep", icon: "moon", description: "Night prayer. Commends the soul to God before rest. Ends with a Marian antiphon.")
    ]

    /// Suggests the most appropriate hour based on current time.
    private var suggestedHour: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<5: return "Matins"
        case 5..<7: return "Lauds"
        case 7..<8: return "Prime"
        case 8..<11: return "Terce"
        case 11..<14: return "Sext"
        case 14..<17: return "None"
        case 17..<21: return "Vespers"
        default: return "Compline"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("The Divine Office")
                        .font(.custom("Palatino", size: 28).weight(.bold))
                        .foregroundStyle(.ink)
                    Text("Officium Divinum")
                        .font(.custom("Palatino-Italic", size: 16))
                        .foregroundStyle(.goldLeaf)
                    Text("Select an hour to pray")
                        .font(.custom("Georgia-Italic", size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.bottom, 20)

                // Hours list
                ForEach(hours) { officeHour in
                    let isSuggested = officeHour.name == suggestedHour

                    NavigationLink {
                        // Future: OfficeHourDetailView
                        Text("Coming soon: \(officeHour.latinName)")
                            .font(.custom("Palatino-Italic", size: 16))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.parchment)
                    } label: {
                        HStack(alignment: .top, spacing: 0) {
                            // Accent bar
                            Rectangle()
                                .fill(isSuggested ? Color.sanctuaryRed : Color.goldLeaf.opacity(0.2))
                                .frame(width: 3)
                                .padding(.trailing, 14)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Image(systemName: officeHour.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(isSuggested ? .sanctuaryRed : .goldLeaf)
                                        .frame(width: 20)

                                    Text(officeHour.name)
                                        .font(.custom("Palatino", size: 17).weight(.medium))
                                        .foregroundStyle(.ink)

                                    if isSuggested {
                                        Text("NOW")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.sanctuaryRed)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .stroke(Color.sanctuaryRed.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                }

                                Text(officeHour.latinName)
                                    .font(.custom("Palatino-Italic", size: 13))
                                    .foregroundStyle(.goldLeaf)

                                HStack(spacing: 4) {
                                    Text(officeHour.time)
                                        .font(.custom("Georgia", size: 12))
                                        .foregroundStyle(.secondary)
                                    Text("·")
                                        .foregroundStyle(.goldLeaf.opacity(0.4))
                                    Text(officeHour.description)
                                        .font(.custom("Georgia", size: 12))
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.goldLeaf.opacity(0.08))
                                .frame(height: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color.parchment)
        .navigationTitle("Divine Office")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OfficeHour: Identifiable {
    let id = UUID()
    let name: String
    let latinName: String
    let time: String
    let icon: String
    let description: String
}

#Preview {
    NavigationStack {
        DivineOfficeView()
    }
}
