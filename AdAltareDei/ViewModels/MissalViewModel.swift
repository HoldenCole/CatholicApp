import Foundation

@MainActor
class MissalViewModel: ObservableObject {
    @Published var sections: [MissalSection] = []
    @Published var selectedPart: MassPart?

    var groupedSections: [(MassPart, [MissalSection])] {
        let grouped = Dictionary(grouping: sections) { $0.part }
        return MassPart.allCases.compactMap { part in
            guard let items = grouped[part], !items.isEmpty else { return nil }
            return (part, items.sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    func loadSections() {
        guard let url = Bundle.main.url(forResource: "mass_ordinary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([MissalSection].self, from: data) else {
            return
        }
        sections = decoded.sorted { $0.sortOrder < $1.sortOrder }
    }
}
