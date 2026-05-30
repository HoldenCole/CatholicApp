package com.lampstandhq.introibo.data.search

import com.lampstandhq.introibo.data.content.ContentStore

// MARK: - SearchIndex (Phase 1: index core)
//
// Mirror of:
//   Introibo/Data/Search/SearchIndex.swift
//
// Holds the folded, partitioned corpus that the (Phase 2) matcher will run
// over. Built once off the main thread on first access via ContentStore, but
// individual partitions can be hot-swapped with [replacePartition] so a future
// language pack / Bible import can be folded in without a full rebuild.

class SearchIndex private constructor(
    partitions: Map<String, List<SearchDocument>>,
    order: List<String>,
) {
    /** Documents bucketed by source key ("prayers", "missal", "propers", …). */
    var partitions: Map<String, List<SearchDocument>> = partitions
        private set

    /** Stable ordering of partition keys so [documents] is deterministic. */
    private var order: List<String> = order

    /** Flat list of every indexed document (recomputed from [partitions]). */
    var documents: List<SearchDocument> = order.flatMap { partitions[it].orEmpty() }
        private set

    constructor() : this(emptyMap(), emptyList())

    /**
     * Swap one bucket and recompute the flat array. If [key] is new it is
     * appended to the ordering; if [docs] is empty the bucket is removed.
     */
    fun replacePartition(key: String, docs: List<SearchDocument>) {
        val newPartitions = partitions.toMutableMap()
        val newOrder = order.toMutableList()
        if (docs.isEmpty()) {
            newPartitions.remove(key)
            newOrder.remove(key)
        } else {
            if (!newPartitions.containsKey(key)) newOrder.add(key)
            newPartitions[key] = docs
        }
        partitions = newPartitions
        order = newOrder
        documents = newOrder.flatMap { newPartitions[it].orEmpty() }
    }

    companion object {
        /**
         * Runs every registered extractor against the store's content and
         * returns a fully partitioned index. Pure function of its inputs — safe
         * to call off the main thread.
         */
        fun build(store: ContentStore): SearchIndex {
            val partitions = linkedMapOf<String, List<SearchDocument>>()

            // Registration list: adding a content type = adding one line here.
            partitions["prayers"] = SearchExtractors.prayers(store.prayers)
            partitions["missal"] = SearchExtractors.missalSections(store.missal)
            partitions["propers"] = SearchExtractors.propers(store.allPropers)
            partitions["hours"] = SearchExtractors.hours(store.hours)
            partitions["reference"] = SearchExtractors.reference(store.reference)
            partitions["calendar"] = SearchExtractors.calendar(store.reference)
            partitions["saints"] = SearchExtractors.saints(store.saints)

            return SearchIndex(partitions, partitions.keys.toList())
        }
    }
}
