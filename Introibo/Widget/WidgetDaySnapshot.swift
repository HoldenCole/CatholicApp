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
    // Sanctorale fields — optional so snapshot windows written by older app
    // versions still decode. "Progress" below is the CHURCH'S calendar (how
    // far the season has run), never the user's behaviour (wellbeing CUT LINE).
    let rank: Double?          // ordo rank of the day's celebration
    let sanctoral: Bool?       // the sanctoral cycle won the day
    let notable: Bool?         // upcoming-feasts criteria (rank ≥ III | vigil | Ember)
    let seasonDay: Int?        // 1-based day within the current season run
    let seasonLength: Int?     // total days in the current season run
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

/// Who appears in the Sanctorale widget's upcoming list (user choice, set in
/// the in-app widget settings).
enum WidgetSaintsFilter: String, CaseIterable {
    case saints, all

    var label: String {
        switch self {
        case .saints: return "Saints only"
        case .all: return "All notable days"
        }
    }

    var detail: String {
        switch self {
        case .saints: return "Feasts of the sanctoral cycle"
        case .all: return "Adds vigils and Ember days"
        }
    }
}

enum WidgetSnapshotStore {

    static let daysKey = "widget.days"
    static let langKey = "widget.lang"        // "latin" | "english"
    static let readingKey = "widget.reading"  // WidgetReadingText rawValue
    static let saintsKey = "widget.saints"    // WidgetSaintsFilter rawValue

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

    static var saintsFilter: WidgetSaintsFilter {
        get {
            WidgetSaintsFilter(
                rawValue: WidgetConfigStore.defaults.string(forKey: saintsKey) ?? ""
            ) ?? .saints
        }
        set {
            WidgetConfigStore.defaults.set(newValue.rawValue, forKey: saintsKey)
        }
    }

    /// The notable days after `snapshot`'s date still inside the window,
    /// filtered per the user's saints choice, soonest first.
    static func upcoming(after snapshot: WidgetDaySnapshot, limit: Int) -> [WidgetDaySnapshot] {
        let filter = saintsFilter
        return load()
            .filter {
                $0.date > snapshot.date
                    && ($0.notable ?? false)
                    && (filter == .all || ($0.sanctoral ?? false))
            }
            .sorted { $0.date < $1.date }   // "yyyy-MM-dd" sorts lexically
            .prefix(limit)
            .map { $0 }
    }
}
