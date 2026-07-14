import SwiftUI

// MARK: - DeepLinkRouter (Phase 3: deep-link navigation)
//
// Resolves a `DeepLinkTarget` (carried by every SearchDocument, and — in the
// future — by a contextual link or a Home-Screen widget) into concrete in-app
// navigation: pick the right tab, then present the matching detail view scrolled
// to the matched element (`initialAnchor` = target.position).
//
// Single entry point: `DeepLinkRouter.shared.open(target)`. ContentView observes
// the router and drives one root-level sheet from `resolved`; the destination
// detail view reads `initialAnchor` and scrolls to the keyed element on appear.
//
// Cold-launch / URL entry (a future widget) can call the SAME `open(target)`
// once the UI is on screen — the router is intentionally surface-agnostic.

// MARK: - Resolved deep link

/// A `DeepLinkTarget` resolved against ContentStore into a concrete model plus
/// its scroll anchor. Identifiable so it can drive a `.sheet(item:)`.
enum DeepLinkResolved: Identifiable {
    case prayer(Prayer, anchor: String?)
    case proper(MassProper, anchor: String?)
    case missalSection(MassProper, anchor: String?) // Ordinary sections re-use the proper sheet only when a proper carries them; plain sections fall back to the Missal tab (see resolve()).
    case hour(Hour, anchor: String?)
    case reference(ReferenceEntry, anchor: String?)
    case saint(Saint, anchor: String?)

    /// Stable identity so SwiftUI re-presents the sheet when the target changes.
    var id: String {
        switch self {
        case .prayer(let p, let a):         return "prayer:\(p.slug)#\(a ?? "")"
        case .proper(let mp, let a):        return "proper:\(mp.slug)#\(a ?? "")"
        case .missalSection(let mp, let a): return "missal:\(mp.slug)#\(a ?? "")"
        case .hour(let h, let a):           return "office:\(h.slug)#\(a ?? "")"
        case .reference(let e, let a):      return "reference:\(e.slug)#\(a ?? "")"
        case .saint(let s, let a):          return "saint:\(s.slug)#\(a ?? "")"
        }
    }
}

// MARK: - Router

@Observable
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    /// The tab index ContentView should switch to before presenting. Mirrors the
    /// tags in ContentView's TabView (0 Hodie · 1 Missa · 2 Oratio · 3 Schola ·
    /// 4 Liber). nil = leave the current tab as-is.
    var requestedTab: Int?

    /// The resolved detail to present at the app root. Cleared after consumption.
    var resolved: DeepLinkResolved?

    private init() {}

    /// The one public entry point. Resolves `target` against the shared
    /// ContentStore and stages the navigation. Safe to call from any surface;
    /// no-op if the target cannot be resolved.
    func open(_ target: DeepLinkTarget) {
        guard let resolved = Self.resolve(target, store: .shared) else { return }
        requestedTab = Self.tab(for: target.type)
        self.resolved = resolved
    }

    /// URL entry point — inline contextual links (`introibo://link?t=…`) and
    /// widget taps (`introibo://widget?m=office|prayer`). Attached at the App
    /// root so cold launches during the splash still stage the navigation;
    /// ContentView presents it when it mounts. Widget targets are resolved
    /// against the clock AT TAP TIME (never a stale render payload), via the
    /// same OfficeSchedule / slot logic the widget itself renders from.
    func open(url: URL) {
        guard url.scheme == ContextualLink.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return }

        switch url.host {
        case ContextualLink.host: // "link"
            guard let raw = components.queryItems?.first(where: { $0.name == "t" })?.value,
                  let target = LinkTarget.parse(raw)
            else { return }
            open(target)

        case "widget":
            let mode = components.queryItems?.first(where: { $0.name == "m" })?.value
            switch WidgetMode(rawValue: mode ?? "") ?? .office {
            case .office:
                let slug = OfficeSchedule.currentHourSlug(in: ContentStore.shared.hours)
                open(DeepLinkTarget(type: .office, id: slug, position: nil))
            case .prayer:
                let slot = WidgetConfigStore.currentSlot()
                let slug = WidgetConfigStore.slotPrayer(slot)
                open(DeepLinkTarget(type: .prayer, id: slug, position: nil))
            }

        default:
            return
        }
    }

    /// Clears the staged navigation once the destination sheet has been
    /// presented (called by ContentView on dismissal).
    func consume() {
        resolved = nil
        requestedTab = nil
    }

    // MARK: Resolution

    /// Maps a content type to the tab whose surface owns it.
    private static func tab(for type: ContentType) -> Int {
        switch type {
        case .prayer:                       return 2 // Oratio
        case .missal:                       return 1 // Missa
        case .office:                       return 1 // Office is reached from Missa/Today; keep Missa context.
        case .reference, .calendar, .saint: return 4 // Liber
        }
    }

    /// Resolves a target into a concrete model + anchor, or nil if the content
    /// is missing.
    static func resolve(_ target: DeepLinkTarget, store: ContentStore) -> DeepLinkResolved? {
        switch target.type {
        case .prayer:
            guard let p = store.prayer(slug: target.id) else { return nil }
            return .prayer(p, anchor: target.position)

        case .missal:
            // Proper element/feast docs and Ordinary-section docs both carry
            // ContentType.missal. Try the proper corpus first (its slugs are the
            // formulary slugs); the anchor is the element name or "feast".
            if let mp = store.anyProper(slug: target.id) {
                return .proper(mp, anchor: target.position)
            }
            // An Ordinary section (e.g. "kyrie") has no standalone detail sheet;
            // we can still land the user on the Missa tab. Nothing to present.
            return nil

        case .office:
            guard let h = store.hour(slug: target.id) else { return nil }
            return .hour(h, anchor: target.position)

        case .reference, .calendar:
            guard let e = store.referenceEntry(slug: target.id) else { return nil }
            return .reference(e, anchor: target.position)

        case .saint:
            guard let s = store.saint(slug: target.id) else { return nil }
            return .saint(s, anchor: target.position)
        }
    }
}
