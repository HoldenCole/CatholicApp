import Foundation

// MARK: - WidgetDaySnapshot
//
// The daily liturgical payload the widget extension renders — the feast and
// a quote from the day's Mass propers. The extension CANNOT load the missal
// corpus (a widget process has a hard memory ceiling far below the ~20 MB of
// bundled JSON), so the app precomputes a rolling window of these snapshots
// into the shared App Group whenever it runs (see WidgetSnapshotWriter, app
// target only). The window is ~30 days, so the widgets stay correct for a
// month even if the app is never opened.
//
// This FILE is compiled into BOTH the app target and the IntroiboWidgets
// extension target (see project.yml).
//
// Android mirror: none needed — the Android widget shares the app process
// and reads ContentStore directly.

struct WidgetDaySnapshot: Codable {
    let date: String          // "yyyy-MM-dd" (local)
    let name: String          // Latin feast/feria title
    let english: String?      // English title if bundled
    let color: String         // ordo colour key ("white", "red", ...)
    let season: String        // English season name
    let introitLat: String
    let introitEng: String
    let introitRef: String?
    let collectLat: String
    let collectEng: String
    let epistleLat: String
    let epistleEng: String
    let epistleRef: String?
    let gospelLat: String
    let gospelEng: String
    let gospelRef: String?
}

/// Which propers text the Daily Reading widget quotes (user choice, set in
/// the in-app widget settings). Extensible set.
enum WidgetReadingText: String, CaseIterable {
    case introit, collect, epistle, gospel

    var label: String {
        switch self {
        case .introit: return "Introit"
        case .collect: return "Collect"
        case .epistle: return "Epistle"
        case .gospel: return "Gospel"
        }
    }
}

enum WidgetSnapshotStore {

    static let daysKey = "widget.days"
    static let langKey = "widget.lang"        // "latin" | "english"
    static let readingKey = "widget.reading"  // WidgetReadingText rawValue

    static func load() -> [WidgetDaySnapshot] {
        guard let data = WidgetConfigStore.defaults.data(forKey: daysKey),
              let list = try? JSONDecoder().decode([WidgetDaySnapshot].self, from: data)
        else { return [] }
        return list
    }

    static func save(_ list: [WidgetDaySnapshot]) {
        if let data = try? JSONEncoder().encode(list) {
            WidgetConfigStore.defaults.set(data, forKey: daysKey)
        }
    }

    /// The snapshot for `date` (local calendar day), if the window covers it.
    static func snapshot(for date: Date = Date()) -> WidgetDaySnapshot? {
        let key = dateKey(date)
        return load().first { $0.date == key }
    }

    static func dateKey(_ date: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Whether the widgets should render Latin (true) or English (false),
    /// mirrored from the app's language setting at snapshot time.
    static var prefersLatin: Bool {
        WidgetConfigStore.defaults.string(forKey: langKey) == "latin"
    }

    static var readingText: WidgetReadingText {
        get {
            WidgetReadingText(
                rawValue: WidgetConfigStore.defaults.string(forKey: readingKey) ?? ""
            ) ?? .introit
        }
        set {
            WidgetConfigStore.defaults.set(newValue.rawValue, forKey: readingKey)
        }
    }
}
