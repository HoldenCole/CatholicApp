#!/usr/bin/env python3
"""Offline contextual-link validator (Introibo Phase 4).

Runs in CI/locally WITHOUT a Swift or Kotlin toolchain. Mirrors the in-app
validation done by DeepLinkRouter.resolve + AnchorValidation.anchorExists and
the LinkGraph debug assertion: it parses every outbound link in the content
corpus (inline `<link target="...">` markup AND every `related[].target`),
confirms the target id resolves to real content, and confirms the position
anchor exists.

Two link sources, exactly mirroring the iOS/Android LinkScanners:
  1. Inline `<link target="type:id#pos">text</link>` markup inside any text
     field a detail view renders.
  2. The optional `related: [{label, target}]` array on an entry.

Target grammar (mirror of LinkTarget.parse): "type:id" or "type:id#position"
  - split on FIRST ':' -> type / rest
  - split rest on FIRST '#' -> id / position
  - type must be a known ContentType
  - empty type or empty id => malformed

Anchor rules (mirror of AnchorValidation.anchorExists):
  - missal  : position in {12 proper element names} or "feast", or nil
  - office  : position == "part:N" with 0 <= N < hour.parts.count, or nil
  - reference / prayer / saint / calendar : position must be nil (whole-doc)

Exit status: 0 when every link is valid; non-zero on any dangling link or any
malformed target (CI gate).
"""

import json
import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES_DIR = os.path.join(REPO_ROOT, "Introibo", "Resources")

# The 12 Mass-proper element anchor names + the title-only "feast" anchor.
# Mirrors AnchorValidation.missalProperAnchors / SearchExtractors.properElements.
MISSAL_PROPER_ANCHORS = {
    "introit", "collect", "epistle", "gradual", "alleluia", "tract",
    "sequence", "gospel", "offertory", "secret", "communion", "postcommunion",
    "feast",
}

KNOWN_TYPES = {"prayer", "missal", "office", "reference", "saint", "calendar"}


def load(name):
    with open(os.path.join(RES_DIR, name), encoding="utf-8") as fh:
        return json.load(fh)


# ---------------------------------------------------------------------------
# Target parsing (mirror of LinkTarget.parse)
# ---------------------------------------------------------------------------

def parse_target(raw):
    """Return (type, id, position|None) or None if malformed."""
    if ":" not in raw:
        return None
    type_str, rest = raw.split(":", 1)
    if not type_str or type_str not in KNOWN_TYPES:
        return None
    if not rest:
        return None
    if "#" in rest:
        cid, pos = rest.split("#", 1)
        if not cid:
            return None
        return (type_str, cid, pos if pos else None)
    return (type_str, rest, None)


# ---------------------------------------------------------------------------
# Inline <link> extraction (mirror of LinkMarkup.runs — string scan, no regex)
# ---------------------------------------------------------------------------

def extract_inline_targets(text):
    """Every target string inside <link target="...">...</link> in `text`."""
    out = []
    if not text or "<link " not in text:
        return out
    cursor = 0
    while True:
        open_start = text.find("<link ", cursor)
        if open_start == -1:
            break
        attr_start = text.find('target="', open_start)
        if attr_start == -1:
            break
        attr_start += len('target="')
        attr_end = text.find('"', attr_start)
        if attr_end == -1:
            break
        out.append(text[attr_start:attr_end])
        close = text.find("</link>", attr_end)
        if close == -1:
            break
        cursor = close + len("</link>")
    return out


# ---------------------------------------------------------------------------
# Build the resolution sets from real content
# ---------------------------------------------------------------------------

def build_corpus():
    corpus = {}

    prayers = load("prayers.json")
    corpus["prayer"] = {p["slug"] for p in prayers}

    reference = load("reference.json")
    corpus["reference"] = {e["slug"] for e in reference if e.get("cat") != "Calendarium"}
    corpus["calendar"] = {e["slug"] for e in reference if e.get("cat") == "Calendarium"}

    saints = load("saints.json")
    corpus["saint"] = {s["slug"] for s in saints}

    hours = load("hours.json")
    # office anchors need parts.count; hours.json items are hour stubs whose
    # parts are assembled at runtime. The validator can still confirm the slug
    # exists; for a "part:N" anchor it accepts any non-negative N (parts.count
    # is runtime-assembled and not present statically). The in-app assertion
    # enforces the upper bound at build time.
    corpus["office"] = {h["slug"] for h in hours}

    # missal id resolves against: Ordinary sections (missal.json) OR a proper
    # formulary key (missal_tempora / missal_sanctoral) OR a legacy propers.json
    # slug. Mirrors ContentStore.anyProper / buildAllPropers.
    missal_sections = {s["slug"] for s in load("missal.json")}
    tempora = set(load("missal_tempora.json").keys())
    sanctoral = set(load("missal_sanctoral.json").keys())
    propers_raw = load("propers.json")
    if isinstance(propers_raw, list):
        propers = {p["slug"] for p in propers_raw if isinstance(p, dict) and "slug" in p}
    elif isinstance(propers_raw, dict):
        propers = set(propers_raw.keys())
    else:
        propers = set()
    corpus["missal"] = missal_sections | tempora | sanctoral | propers

    return corpus


def anchor_ok(type_str, position):
    """Mirror of AnchorValidation.anchorExists (id assumed to resolve)."""
    if position is None:
        return True
    if type_str == "missal":
        return position in MISSAL_PROPER_ANCHORS
    if type_str == "office":
        if not position.startswith("part:"):
            return False
        try:
            n = int(position[len("part:"):])
        except ValueError:
            return False
        return n >= 0
    # reference / calendar / prayer / saint => whole-document, no position
    return False


# ---------------------------------------------------------------------------
# Collect every outbound link with provenance (file + field)
# ---------------------------------------------------------------------------

def collect_links():
    """Yield (file, field, raw_target) for every outbound link in the corpus."""
    links = []

    def scan_text(file, field, text):
        for raw in extract_inline_targets(text):
            links.append((file, field + " (inline)", raw))

    def scan_related(file, slug, related):
        if not related:
            return
        for i, rl in enumerate(related):
            t = rl.get("target") if isinstance(rl, dict) else None
            if t is not None:
                links.append((file, "{}#related[{}]".format(slug, i), t))

    # prayers.json
    for p in load("prayers.json"):
        slug = p.get("slug", "?")
        scan_text("prayers.json", "{}.note".format(slug), p.get("note", ""))
        for j, line in enumerate(p.get("lines", [])):
            scan_text("prayers.json", "{}.lines[{}].lat".format(slug, j), line.get("lat", ""))
            scan_text("prayers.json", "{}.lines[{}].eng".format(slug, j), line.get("eng", ""))
        scan_related("prayers.json", slug, p.get("related"))

    # reference.json
    for e in load("reference.json"):
        slug = e.get("slug", "?")
        for f in ("summary", "history", "practice", "notes"):
            scan_text("reference.json", "{}.{}".format(slug, f), e.get(f, ""))
        sc = e.get("scripture")
        if isinstance(sc, dict):
            scan_text("reference.json", "{}.scripture.lat".format(slug), sc.get("lat", ""))
            scan_text("reference.json", "{}.scripture.eng".format(slug), sc.get("eng", ""))
        scan_related("reference.json", slug, e.get("related"))

    # missal.json (Ordinary sections)
    for s in load("missal.json"):
        slug = s.get("slug", "?")
        for j, line in enumerate(s.get("body", [])):
            scan_text("missal.json", "{}.body[{}].lat".format(slug, j), line.get("lat", ""))
            scan_text("missal.json", "{}.body[{}].eng".format(slug, j), line.get("eng", ""))
        scan_related("missal.json", slug, s.get("related"))

    # saints.json
    for s in load("saints.json"):
        slug = s.get("slug", "?")
        scan_text("saints.json", "{}.quote".format(slug), s.get("quote", ""))
        for j, sec in enumerate(s.get("sections", [])):
            scan_text("saints.json", "{}.sections[{}].lat".format(slug, j), sec.get("lat", ""))
            scan_text("saints.json", "{}.sections[{}].eng".format(slug, j), sec.get("eng", ""))
        scan_related("saints.json", slug, s.get("related"))

    return links


def main():
    corpus = build_corpus()
    links = collect_links()

    dangling = []
    valid = 0
    for file, field, raw in links:
        parsed = parse_target(raw)
        if parsed is None:
            dangling.append((file, field, raw, "malformed target"))
            continue
        type_str, cid, position = parsed
        if cid not in corpus.get(type_str, set()):
            dangling.append((file, field, raw, "id not found in {} content".format(type_str)))
            continue
        if not anchor_ok(type_str, position):
            dangling.append((file, field, raw, "invalid anchor '{}'".format(position)))
            continue
        valid += 1

    print("Introibo contextual-link validation")
    print("-----------------------------------")
    print("{} links found, {} valid, {} dangling".format(len(links), valid, len(dangling)))

    if dangling:
        print()
        print("DANGLING LINKS:")
        for file, field, raw, reason in dangling:
            print("  {}  [{}]  -> {}   ({})".format(file, field, raw, reason))
        return 1

    print("All links resolve to real content with valid anchors.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
