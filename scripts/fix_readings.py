#!/usr/bin/env python3
"""Correct readings whose translation does not match their Latin.

  python3 scripts/fix_readings.py [--check]

Every Matins lesson and Mass reading was scored against its Latin (a
Latin-vernacular stem dictionary learned from the verse-aligned lessons,
verse by verse where both sides are numbered, and by length). Each reading
that failed was looked at by hand. The verified corrections live in
scripts/reading_fixes.json:

  {"where": "lesson", "hash": ..., "incipit": ..., "lang": ..., "text": ...}
      a text of the Matins lesson table (office_lessons*.json), found by
      the sha1 of its folded Latin, so every copy of that Latin is fixed;
  {"where": "sanctoral_propers" | "temporal_propers" | "commune_office" | "mass",
   "key": "<day>.<field>", "lang": ..., "text": ...}
      one proper (or Mass reading: missal_sanctoral / missal_tempora);
  {"where": "*", "lang": "en", "sub": [old, new]}
      a typo, replaced wherever it stands in the English readings.

lang "lat" corrects the Latin itself (a sentence printed twice, the next
lesson run on). Spanish propers and Mass readings are written to the
spanish-translation staging files (sync_spanish_assets.py copies them);
French Mass readings go to french-translation/missal_fixes_fr.json, which
import_french.py merges, and to the staging file. Everything else is
written to both apps' asset folders. Run it after the importers; a second
run changes nothing. --check only reports what would change.
"""
import hashlib, json, re, sys, unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSET_DIRS = [ROOT / "android/app/src/main/assets", ROOT / "Introibo/Resources"]
ES = ROOT / "spanish-translation"
FR = ROOT / "french-translation"
FIXES = Path(__file__).resolve().parent / "reading_fixes.json"


def fold(t):
    t = unicodedata.normalize("NFD", t)
    t = "".join(c for c in t if unicodedata.category(c) != "Mn").lower()
    return re.sub(r"[^a-z]", "", t.replace("æ", "ae").replace("œ", "oe"))


def lat_hash(t):
    return hashlib.sha1(fold(t).encode()).hexdigest()[:16]


class Doc:
    """A JSON file, written back in the format it was read in."""

    def __init__(self, path):
        self.path = path
        self.raw = path.read_text(encoding="utf-8")
        self.data = json.loads(self.raw)
        for fmt in ({"indent": 2}, {"indent": 1}, {}, {"separators": (",", ":")}):
            s = json.dumps(self.data, ensure_ascii=False, **fmt)
            if s == self.raw or s + "\n" == self.raw:
                self.fmt, self.nl = fmt, s + "\n" == self.raw
                break
        else:
            sys.exit(f"{path}: unknown JSON layout")

    def text(self):
        s = json.dumps(self.data, ensure_ascii=False, **self.fmt)
        return s + "\n" if self.nl else s


def main():
    check = "--check" in sys.argv
    fixes = json.loads(FIXES.read_text(encoding="utf-8"))
    docs = {}

    def doc(path):
        if path not in docs:
            docs[path] = Doc(path)
        return docs[path].data

    changed, missing = [], []

    def put(container, key, value, label):
        if container.get(key) != value:
            container[key] = value
            changed.append(label)

    for d in ASSET_DIRS:
        lessons = doc(d / "office_lessons.json")["texts"]
        vern = {"es": doc(d / "office_lessons_es.json"), "fr": doc(d / "office_lessons_fr.json")}
        index = {}
        for i, t in enumerate(lessons):
            index.setdefault(lat_hash(t["lat"]), []).append(i)
        # a Latin already corrected is found by its new hash
        alias = {f["hash"]: lat_hash(f["text"]) for f in fixes if f["where"] == "lesson" and f["lang"] == "lat"}
        latin_fixes = []
        for f in fixes:
            if f["where"] != "lesson":
                continue
            hits = index.get(f["hash"]) or index.get(alias.get(f["hash"]), [])
            if not hits:
                missing.append(f"lesson {f['incipit'][:40]!r} ({f['lang']})")
                continue
            for i in hits:
                if f["lang"] == "lat":
                    latin_fixes.append((i, f["text"]))
                elif f["lang"] == "en":
                    put(lessons[i], "eng", f["text"], f"{d.name} lesson {i} en")
                else:
                    if vern[f["lang"]][i] != f["text"]:
                        vern[f["lang"]][i] = f["text"]
                        changed.append(f"{d.name} lesson {i} {f['lang']}")
        for i, text in latin_fixes:   # last, so the vernacular fixes still find the old Latin
            put(lessons[i], "lat", text, f"{d.name} lesson {i} lat")

        for f in fixes:
            if f["where"] in ("lesson", "*") or f["lang"] not in ("en", "lat"):
                continue
            day, field = f["key"].split(".", 1)
            if f["where"] == "mass":
                files = ("missal_sanctoral.json", "missal_tempora.json")
            else:
                files = (f["where"] + ".json",)
            for name in files:
                entry = (doc(d / name).get(day) or {}).get(field)
                if isinstance(entry, dict):
                    put(entry, "eng" if f["lang"] == "en" else "lat", f["text"], f"{d.name} {f['key']} {f['lang']}")
                    break
            else:
                missing.append(f"{f['where']} {f['key']} ({f['lang']})")

        for f in fixes:   # typos, in every English reading
            if f["where"] != "*":
                continue
            old, new = f["sub"]
            for t in lessons:
                if old in t.get("eng", ""):
                    t["eng"] = t["eng"].replace(old, new)
                    changed.append(f"{d.name} lesson typo {old[:20]!r}")
            for name in ("sanctoral_propers.json", "temporal_propers.json", "commune_office.json"):
                for day in doc(d / name).values():
                    for v in day.values():
                        if isinstance(v, dict) and old in (v.get("eng") or ""):
                            v["eng"] = v["eng"].replace(old, new)
                            changed.append(f"{d.name} {name} typo {old[:20]!r}")

    # Spanish propers and Mass readings, in the staging files
    for f in fixes:
        if f["lang"] != "es" or f["where"] == "lesson":
            continue
        day, field = f["key"].split(".", 1)
        if f["where"] == "mass":
            put(doc(ES / "missal_readings_es.json").setdefault(day, {}), field, f["text"], f"es {f['key']}")
            continue
        entry = (doc(ES / (f["where"] + "_es.json")).get(day) or {}).get(field)
        if isinstance(entry, dict):
            put(entry, "eng", f["text"], f"es {f['key']}")
        else:
            missing.append(f"es {f['where']} {f['key']}")

    # French Mass readings: the importer's fixes file, and its output
    for f in fixes:
        if f["lang"] != "fr" or f["where"] != "mass":
            continue
        day, field = f["key"].split(".", 1)
        put(doc(FR / "missal_fixes_fr.json").setdefault(day, {}), field, f["text"], f"fr fixes {f['key']}")
        put(doc(FR / "missal_readings_fr.json").setdefault(day, {}), field, f["text"], f"fr {f['key']}")

    for p, dd in docs.items():
        new = dd.text()
        if new != dd.raw and not check:
            p.write_text(new, encoding="utf-8")
    print(f"{len(fixes)} fixes; {len(changed)} values changed" + (" (check only)" if check else ""))
    for m in missing:
        print("  not found:", m)
    if missing:
        sys.exit(1)


if __name__ == "__main__":
    main()
