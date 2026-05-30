import Foundation

// MARK: - SearchIndex (Phase 1: index core)
//
// Mirror of:
//   android/app/src/main/java/com/lampstandhq/introibo/data/search/SearchIndex.kt
//
// Holds the folded, partitioned corpus that the (Phase 2) matcher will run
// over. Built once off the main thread on first access via ContentStore, but
// individual partitions can be hot-swapped with `replacePartition` so a future
// language pack / Bible import can be folded in without a full rebuild.

struct SearchIndex {

    /// Flat list of every indexed document (recomputed from `partitions`).
    private(set) var documents: [SearchDocument]

    /// Documents bucketed by source key ("prayers", "missal", "propers",
    /// "hours", "reference", "calendar", "saints", …). A future Bible import
    /// would just add a "bible" partition.
    private(set) var partitions: [String: [SearchDocument]]

    /// Stable ordering of partition keys so the flat `documents` array is
    /// deterministic across rebuilds (helps tests + snapshotting).
    private var order: [String]

    init() {
        documents = []
        partitions = [:]
        order = []
    }

    private init(partitions: [String: [SearchDocument]], order: [String]) {
        self.partitions = partitions
        self.order = order
        self.documents = order.flatMap { partitions[$0] ?? [] }
    }

    /// Swap one bucket and recompute the flat array. If `key` is new it is
    /// appended to the ordering; if `docs` is empty the bucket is removed.
    mutating func replacePartition(_ key: String, _ docs: [SearchDocument]) {
        if docs.isEmpty {
            partitions[key] = nil
            order.removeAll { $0 == key }
        } else {
            if partitions[key] == nil { order.append(key) }
            partitions[key] = docs
        }
        documents = order.flatMap { partitions[$0] ?? [] }
    }

    // MARK: - Build

    /// Runs every registered extractor against the store's content and returns
    /// a fully partitioned index. Pure function of its inputs — safe to call
    /// off the main thread.
    static func build(from store: ContentStore) -> SearchIndex {
        var partitions: [String: [SearchDocument]] = [:]
        var order: [String] = []

        func add(_ key: String, _ docs: [SearchDocument]) {
            order.append(key)
            partitions[key] = docs
        }

        // Registration list: adding a content type = adding one line here.
        add("prayers",   SearchExtractors.prayers(store.prayers))
        add("missal",    SearchExtractors.missalSections(store.missal))
        add("propers",   SearchExtractors.propers(store.allPropers))
        add("hours",     SearchExtractors.hours(store.hours))
        add("reference", SearchExtractors.reference(store.reference))
        add("calendar",  SearchExtractors.calendar(store.reference))
        add("saints",    SearchExtractors.saints(store.saints))

        return SearchIndex(partitions: partitions, order: order)
    }
}
