package com.lampstandhq.introibo.data.links

import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.data.model.MassProper
import com.lampstandhq.introibo.data.model.MissalSection
import com.lampstandhq.introibo.data.model.Prayer
import com.lampstandhq.introibo.data.model.ReferenceEntry
import com.lampstandhq.introibo.data.model.Saint
import com.lampstandhq.introibo.data.search.ContentType
import com.lampstandhq.introibo.data.search.DeepLinkTarget

// MARK: - LinkScanners (Phase 3: contextual-links reverse index)
//
// Mirror of:
//   Introibo/Data/Links/LinkScanners.swift
//
// One scanner per content type. Each computes an entry's OWN DeepLinkTarget +
// display label (the LinkSource shown under "Referenced By"), then finds every
// OUTBOUND link from that entry and records the inverse edge into the
// LinkGraph.Builder.
//
// Outbound links come from two places, exactly mirroring what a detail screen +
// RelatedLinksSection render:
//   1. Inline `<link>` markup in the same text fields BilingualLine renders —
//      collected by running [LinkMarkup.runs] over each field and keeping every
//      [TextRun.Link] target.
//   2. The entry's optional `related: List<RelatedLink>` array — each `target`
//      string parsed via [LinkTarget.parse].
//
// Scanners are registered in LinkGraph.build so adding a content type is one
// scanner + one registration line (mirrors SearchExtractors / SearchIndex.build).

object LinkScanners {

    // ---- Inline-link target collection ----

    /**
     * Every [TextRun.Link] target found across the given nullable text fields.
     * Fields with no `<link>` markup contribute nothing.
     */
    private fun inlineTargets(fields: List<String?>): List<DeepLinkTarget> {
        val out = mutableListOf<DeepLinkTarget>()
        for (field in fields) {
            if (field.isNullOrEmpty()) continue
            for (run in LinkMarkup.runs(field)) {
                if (run is TextRun.Link) out.add(run.target)
            }
        }
        return out
    }

    /** Parsed targets from an entry's `related[]` array (null/malformed dropped). */
    private fun relatedTargets(related: List<RelatedLink>?): List<DeepLinkTarget> =
        (related ?: emptyList()).mapNotNull { LinkTarget.parse(it.target) }

    /** Records one source's outbound edges (inline + related) into the builder. */
    private fun record(
        source: LinkSource,
        inlineFields: List<String?>,
        related: List<RelatedLink>?,
        builder: LinkGraph.Builder,
    ) {
        for (target in inlineTargets(inlineFields)) builder.record(source, target)
        for (target in relatedTargets(related)) builder.record(source, target)
    }

    // ---- Prayer ----

    fun prayers(items: List<Prayer>, builder: LinkGraph.Builder) {
        for (p in items) {
            val source = LinkSource(
                target = DeepLinkTarget(ContentType.PRAYER, p.slug, null),
                label = p.title,
            )
            val fields = mutableListOf<String?>(p.note)
            for (line in p.lines) { fields.add(line.lat); fields.add(line.eng) }
            record(source, fields, p.related, builder)
        }
    }

    // ---- MissalSection (Ordinary) ----

    fun missalSections(items: List<MissalSection>, builder: LinkGraph.Builder) {
        for (s in items) {
            val source = LinkSource(
                target = DeepLinkTarget(ContentType.MISSAL, s.slug, null),
                label = s.title,
            )
            val fields = mutableListOf<String?>()
            for (line in s.body) { fields.add(line.lat); fields.add(line.eng) }
            record(source, fields, null, builder)
        }
    }

    // ---- MassProper ----

    fun propers(items: List<MassProper>, builder: LinkGraph.Builder) {
        for (mp in items) {
            val source = LinkSource(
                target = DeepLinkTarget(ContentType.MISSAL, mp.slug, null),
                label = mp.title,
            )
            val fields = mutableListOf<String?>(
                mp.introit.lat, mp.introit.eng,
                mp.collect.lat, mp.collect.eng,
                mp.epistle.lat, mp.epistle.eng,
                mp.gradual?.lat, mp.gradual?.eng,
                mp.alleluia?.lat, mp.alleluia?.eng,
                mp.tract?.lat, mp.tract?.eng,
                mp.sequence?.lat, mp.sequence?.eng,
                mp.gospel.lat, mp.gospel.eng,
                mp.offertory.lat, mp.offertory.eng,
                mp.secret.lat, mp.secret.eng,
                mp.communion.lat, mp.communion.eng,
                mp.postcommunion.lat, mp.postcommunion.eng,
            )
            record(source, fields, mp.related, builder)
        }
    }

    // ---- Hour ----

    fun hours(items: List<Hour>, builder: LinkGraph.Builder) {
        for (hour in items) {
            val source = LinkSource(
                target = DeepLinkTarget(ContentType.OFFICE, hour.slug, null),
                label = hour.eng,
            )
            val fields = mutableListOf<String?>()
            for (part in hour.parts) {
                fields.add(part.lat);  fields.add(part.eng)
                fields.add(part.latR); fields.add(part.engR)
                fields.add(part.v1Lat); fields.add(part.v1Eng)
                fields.add(part.r1Lat); fields.add(part.r1Eng)
                fields.add(part.v2Lat); fields.add(part.v2Eng)
                fields.add(part.engBody)
                fields.add(part.antiphonLat); fields.add(part.antiphonEng)
                part.verses?.forEach { v -> fields.add(v.lat); fields.add(v.eng) }
            }
            record(source, fields, hour.related, builder)
        }
    }

    // ---- ReferenceEntry (reference + calendar) ----

    fun reference(items: List<ReferenceEntry>, builder: LinkGraph.Builder) {
        for (e in items) {
            // Calendar entries (cat == "Calendarium") deep-link as CALENDAR; all
            // others as REFERENCE — matching the search extractor split.
            val type = if (e.cat == "Calendarium") ContentType.CALENDAR else ContentType.REFERENCE
            val source = LinkSource(
                target = DeepLinkTarget(type, e.slug, null),
                label = e.title,
            )
            val fields = mutableListOf<String?>(e.summary, e.history, e.practice, e.notes)
            e.scripture?.let { fields.add(it.lat); fields.add(it.eng) }
            record(source, fields, e.related, builder)
        }
    }

    // ---- Saint ----

    fun saints(items: List<Saint>, builder: LinkGraph.Builder) {
        for (s in items) {
            val source = LinkSource(
                target = DeepLinkTarget(ContentType.SAINT, s.slug, null),
                label = s.name,
            )
            val fields = mutableListOf<String?>(s.quote)
            for (section in s.sections) { fields.add(section.lat); fields.add(section.eng) }
            (s.prayers ?: emptyList()).forEach { pr ->
                fields.add(pr.latin); fields.add(pr.eng); fields.add(pr.note)
            }
            record(source, fields, s.related, builder)
        }
    }
}
