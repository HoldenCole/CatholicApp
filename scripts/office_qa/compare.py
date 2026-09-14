#!/usr/bin/env python3
"""Differential QA: the app's assembled hours (OfficeJsonDump) against
Divinum Officium (do_extract.py), day by day, hour by hour, rite by rite.

  compare.py --app DIR --do DIR [--rites 1962,1955,pre1955] [--hours ...]
             [--start ..] [--end ..] [--report FILE] [--max-examples 8]

Checks (each a category in the report):
  psalms      the ordered list of psalms/canticles (number + range) and
              each one's verse count
  antiphons   the ordered antiphon texts (first 5 words)
  hymn        the hymn's first line
  capitulum   the chapter's first words
  versicle    the ℣. lines (first 5 words each), in order
  responsory  the short responsory's first words
  collect     the collect(s), first 6 words, in order
  lessons     Matins: number of lessons; Te Deum presence
  marian      Compline: the final antiphon of the BVM
  preces      whether the preces are said
  structure   section presence: Incipit, Hymnus, Capitulum, Oratio, ...
"""
import argparse, datetime, json, os, re, sys, unicodedata
from collections import Counter, defaultdict

HOURS = ["matutinum", "laudes", "prima", "tertia", "sexta", "nona", "vesperae", "completorium"]


def norm(s):
    s = s or ""
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = s.lower().replace("æ", "ae").replace("œ", "oe").replace("j", "i").replace("v", "u")
    s = re.sub(r"[^a-z0-9 ]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def words(s, n):
    return " ".join(norm(s).split()[:n])


def strip_num(l):
    l = re.sub(r"^\d+:\d+[ab]?\s+", "", l)
    l = re.sub(r"^\(\w+\)\s+", "", l)          # (Aleph) / (fit reverentia)
    return re.sub(r"^\(fit reverentia\)\s+", "", l)


GLORIA = ("gloria patri", "sicut erat")

# Versicles that belong to the fixed frame of every hour (not what we are
# checking); matched on their normalised first words.
FIXED_VERSICLES = ("deus in adiutorium", "gloria patri", "domine exaudi", "benedicamus domino",
                   "fidelium animae", "domine labia", "iube domine", "iube domne", "tu autem",
                   "adiutorium nostrum", "pretiosa in conspectu", "respice in seruos",
                   "et ne nos inducas", "sed libera nos", "dominus uobiscum", "exsurge christe",
                   "diuinum auxilium", "domine miserere", "conuerte nos", "dignare domine",
                   "kyrie eleison", "christe eleison", "pater noster", "ostende nobis",
                   "sancta maria", "exaudi domine", "in manus tuas")


def proper_versicle(t):
    n = norm(t)
    return not any(n.startswith(f) for f in FIXED_VERSICLES)


def is_gloria(l):
    n = norm(l)
    return n.startswith(GLORIA[0]) or n.startswith(GLORIA[1])


# ---------------- DO side ----------------

def do_psalms(sections):
    """[(label, verse_count, first_line)] from DO sections."""
    out = []
    for sec in sections:
        lines = sec["lines"]
        i = 0
        while i < len(lines):
            l = lines[i]
            m = re.match(r"^(Psalmus \d+(?:\(\d+-\d+\))?)\s*\[\d+\]", l) or re.match(r"^(Canticum [A-Za-zæÆ. ]+?)\s*(?:\[\d+\])?$", l)
            if m:
                label = m.group(1).strip()
                # verses follow until the next Ant./Psalmus/section end
                j = i + 1
                verses = []
                first = None
                while j < len(lines) and not re.match(r"^(Ant\.|Psalmus \d|Canticum |℣\.|Capitulum|Hymnus)", lines[j]):
                    lj = lines[j]
                    if re.match(r"^\d+:\d+", lj) or (first is None and not re.match(r"^[A-Z][a-z]+\.? \d", lj)):
                        if re.match(r"^\d+:\d+", lj):
                            verses.append(strip_num(lj))
                    j += 1
                if not verses:
                    verses = [x for x in lines[i + 1:j] if not is_gloria(x)]
                verses = [v for v in verses if not is_gloria(v)]
                out.append((label, len(verses), verses[0] if verses else ""))
                i = j
                continue
            i += 1
    return out


def merge_laudate(ps):
    """DO lists Ps 148, 149, 150 separately; the app keeps them as one part."""
    out = []
    i = 0
    while i < len(ps):
        if (i + 2 < len(ps) and ps[i][0] == "Psalmus 148" and ps[i + 1][0] == "Psalmus 149"
                and ps[i + 2][0] == "Psalmus 150"):
            out.append(("Psalmus 148-150", ps[i][1] + ps[i + 1][1] + ps[i + 2][1], ps[i][2]))
            i += 3
        else:
            out.append(ps[i]); i += 1
    return out


def do_antiphons(sections):
    out = []
    for sec in sections:
        for l in sec["lines"]:
            if l.startswith("Ant. "):
                t = words(l[5:], 5)
                if not out or out[-1] != t:
                    out.append(t)
    return out


def do_lines(sections, pred):
    return [l for sec in sections for l in sec["lines"] if pred(l)]


def do_section(sections, name_re):
    for sec in sections:
        if re.search(name_re, sec["name"]):
            return sec
    return None


def is_rubric(l):
    n = norm(l)
    return ("stropha" in n or n.endswith("dicitur") or n.startswith("{") or l.startswith("{"))


def do_hymn(sections):
    # "Hymnus" section, or the line after a "Hymnus" marker inside a
    # "Capitulum Hymnus Versus" section.
    sec = do_section(sections, r"^Hymnus")
    if sec and sec["lines"]:
        for l in sec["lines"]:
            if not is_rubric(l):
                return words(l, 5)
    for sec in sections:
        lines = sec["lines"]
        for i, l in enumerate(lines):
            if l == "Hymnus":
                for l2 in lines[i + 1:]:
                    if not is_rubric(l2):
                        return words(l2, 5)
    return None


def do_capitulum(sections):
    for sec in sections:
        if "Capitulum" in sec["name"]:
            lines = sec["lines"]
            for i, l in enumerate(lines):
                # scripture ref line then the text
                if re.match(r"^(?:[1-4] )?[A-Z][a-z]+\.? \d", l) and i + 1 < len(lines):
                    return words(lines[i + 1], 6)
            if lines:
                return words(lines[0], 6)
    return None


def do_versicles(sections, hour):
    """The hour's proper versicle(s): after the hymn (Lauds/Vespers), after
    the short responsory (little hours), the nocturn versicles (Matins)."""
    out = []
    if hour in ("laudes", "vesperae"):
        sec = do_section(sections, r"Capitulum Hymnus Versus|Versus")
        if sec:
            vs = [l for l in sec["lines"] if l.startswith("℣. ") and proper_versicle(l[3:])]
            if vs: out.append(words(vs[-1][3:], 5))
    elif hour in ("tertia", "sexta", "nona"):
        sec = do_section(sections, r"Capitulum Responsorium Versus")
        if sec:
            vs = [l for l in sec["lines"] if l.startswith("℣. ") and proper_versicle(l[3:])]
            if vs: out.append(words(vs[-1][3:], 5))
    elif hour == "matutinum":
        for sec in sections:
            if re.match(r"^Lectio", sec["name"]) or sec["name"] in ("Incipit", "Invitatorium", "Oratio", "Conclusio"):
                continue
            lines = sec["lines"]
            # a nocturn versicle is a bare ℣/℟ pair section (2 lines)
            if len(lines) == 2 and lines[0].startswith("℣. ") and lines[1].startswith("℟. ") and proper_versicle(lines[0][3:]):
                out.append(words(lines[0][3:], 5))
    return out


def do_responsory(sections):
    r = do_lines(sections, lambda l: l.startswith("℟.br. "))
    return words(r[0][6:], 6) if r else None


def do_collects(sections):
    out = []
    for sec in sections:
        lines = sec["lines"]
        for i, l in enumerate(lines):
            if l.startswith("Orémus") and i + 1 < len(lines):
                out.append(words(lines[i + 1], 6))
    return out


def do_lessons(sections):
    n = sum(1 for sec in sections if re.match(r"^Lectio \d", sec["name"]))
    tedeum = bool(do_lines(sections, lambda l: norm(l).startswith("te deum laudamus")))
    return n, tedeum


def do_marian(sections):
    sec = do_section(sections, r"Antiphona finalis")
    return words(sec["lines"][0], 4) if sec and sec["lines"] else None


def do_preces(sections):
    return bool(do_lines(sections, lambda l: norm(l).startswith("kyrie eleison")))


# ---------------- app side ----------------

def app_psalms(parts):
    out = []
    for p in parts:
        if p.get("type") not in ("psalm", "canticle"):
            continue
        label = p.get("label") or ""
        if label.startswith("Psalm 94") or (p.get("vk") or "") == "matutinum.canticle":
            continue  # invitatory psalm / Te Deum are checked elsewhere
        verses = [strip_num(v) for v in (p.get("verses") or []) if not is_gloria(v)]
        m = re.search(r"Psalm(?:us|i)?\s+(\d+)(?:\s*[:(]\s*(\d+)\s*-\s*(\d+))?", label)
        if m and "Psalmi 148" in label:
            out.append(("Psalmus 148-150", len(verses), verses[0] if verses else ""))
        elif m:
            lab = "Psalmus %s" % m.group(1) + ("(%s-%s)" % (m.group(2), m.group(3)) if m.group(2) else "")
            out.append((lab, len(verses), verses[0] if verses else ""))
        else:
            out.append(("Canticum " + label, len(verses), verses[0] if verses else ""))
    return out


def app_antiphons(parts):
    out = []
    for p in parts:
        a = p.get("ant") if p.get("type") in ("psalm", "canticle") else (p.get("lat") if p.get("type") == "antiphon" else None)
        if a:
            t = words(a, 5)
            if not out or out[-1] != t:
                out.append(t)
    return out


def first_line(s):
    s = re.split(r"<br\s*/?>|\n", s or "")[0]
    return s


def app_hymn(parts):
    for p in parts:
        if p.get("type") == "hymn" and p.get("lat"):
            return words(first_line(p["lat"]), 5)
    return None


def app_capitulum(parts):
    for p in parts:
        if p.get("type") in ("capitulum", "reading") and p.get("lat") and p.get("type") == "capitulum":
            return words(first_line(p["lat"]), 6)
    for p in parts:
        if p.get("type") == "reading" and (p.get("vk") or "").startswith("lectio") and p.get("lat"):
            return words(first_line(p["lat"]), 6)
    return None


def app_versicles(parts, hour):
    out = []
    for p in parts:
        if p.get("type") != "vr":
            continue
        vk = p.get("vk") or ""
        if hour in ("laudes", "vesperae") and not vk.startswith("versum_"):
            continue
        if hour in ("tertia", "sexta", "nona") and vk != "versum_" + hour:
            continue
        if hour == "matutinum" and not vk.startswith("nocturn_"):
            continue
        if hour in ("prima", "completorium"):
            continue
        for k in ("v1", "lat"):
            v = p.get(k)
            if not v:
                continue
            line = re.split(r"<br\s*/?>|\n", v)[0].strip()
            line = re.sub(r"^(℣\.|V\.)\s*", "", line)
            if proper_versicle(line):
                out.append(words(line, 5))
            break
    return out


def app_responsory(parts):
    for p in parts:
        if p.get("type") == "responsory" and (p.get("lat") or p.get("v1") or p.get("r1")):
            t = re.sub(r"^(℟|R)\.?\s*br\.?\s*", "", first_line(p.get("lat") or p.get("r1") or p.get("v1")).strip())
            return words(t, 6)
    return None


def app_collects(parts):
    return [words(first_line(p["lat"]), 6) for p in parts
            if p.get("type") == "collect" and p.get("lat") and (p.get("vk") or "") != "prima2.sanctamaria"]


def app_lessons(parts):
    n = sum(1 for p in parts if p.get("type") == "reading" and re.match(r"lectio\d", p.get("vk") or ""))
    tedeum = any((p.get("vk") or "") == "matutinum.canticle" or "Te Deum" in (p.get("label") or "") for p in parts)
    return n, tedeum


def app_marian(parts):
    for p in parts:
        if (p.get("vk") or "").startswith("completorium.marian") or p.get("type") == "marian":
            if p.get("lat"):
                return words(first_line(p["lat"]), 4)
    return None


def app_preces(parts):
    return any(norm(first_line(p.get("lat") or "")).startswith("kyrie eleison") or p.get("type") == "preces"
               or (p.get("vk") or "").startswith("preces") for p in parts)


# ---------------- comparison ----------------

def compare_hour(rite, date, hour, app_parts, do_sections, flags):
    def flag(cat, detail):
        flags[cat].append((rite, date, hour, detail))

    # psalms
    ap = app_psalms(app_parts)
    dp = merge_laudate(do_psalms(do_sections))
    apl = [x[0] for x in ap]
    dpl = [x[0] for x in dp]
    # canticles: compare by first line instead of label
    def key(x):
        m = re.match(r"Psalmus (\d+)", x[0])
        return ("Ps%s:" % m.group(1) if m else "Cant:") + words(x[2], 3)
    if [key(x) for x in ap] != [key(x) for x in dp]:
        flag("psalms", "app %s | DO %s" % ([key(x) for x in ap], [key(x) for x in dp]))
    else:
        for a, d in zip(ap, dp):
            if a[0].startswith("Psalmus 148"):
                continue
            if abs(a[1] - d[1]) > 1:
                flag("psalm-verses", "%s app %d vs DO %d" % (a[0], a[1], d[1]))
    aa, da = app_antiphons(app_parts), do_antiphons(do_sections)
    if aa != da:
        flag("antiphons", "app %s | DO %s" % (aa, da))
    ah, dh = app_hymn(app_parts), do_hymn(do_sections)
    if (ah or dh) and ah != dh:
        flag("hymn", "app %r | DO %r" % (ah, dh))
    ac, dc = app_capitulum(app_parts), do_capitulum(do_sections)
    if hour != "matutinum" and (ac or dc) and ac != dc:
        flag("capitulum", "app %r | DO %r" % (ac, dc))
    av, dv = app_versicles(app_parts, hour), do_versicles(do_sections, hour)
    if hour not in ("prima", "completorium") and av != dv:
        flag("versicle", "app %s | DO %s" % (av, dv))
    ar, dr = app_responsory(app_parts), do_responsory(do_sections)
    if hour != "matutinum" and (ar or dr) and ar != dr:
        flag("responsory", "app %r | DO %r" % (ar, dr))
    aco, dco = app_collects(app_parts), do_collects(do_sections)
    if aco != dco:
        flag("collect", "app %s | DO %s" % (aco, dco))
    if hour == "matutinum":
        al, dl = app_lessons(app_parts), do_lessons(do_sections)
        if al != dl:
            flag("lessons", "app lessons=%d tedeum=%s | DO lessons=%d tedeum=%s" % (al[0], al[1], dl[0], dl[1]))
    if hour == "completorium":
        am, dm = app_marian(app_parts), do_marian(do_sections)
        if (am or dm) and am != dm:
            flag("marian", "app %r | DO %r" % (am, dm))
    if hour in ("laudes", "vesperae", "prima", "completorium"):
        if app_preces(app_parts) != do_preces(do_sections):
            flag("preces", "app %s | DO %s" % (app_preces(app_parts), do_preces(do_sections)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--app", required=True)
    ap.add_argument("--do", required=True)
    ap.add_argument("--rites", default="1962,1955,pre1955")
    ap.add_argument("--hours", default=",".join(HOURS))
    ap.add_argument("--start")
    ap.add_argument("--end")
    ap.add_argument("--report")
    ap.add_argument("--max-examples", type=int, default=8)
    ap.add_argument("--category")
    args = ap.parse_args()
    flags = defaultdict(list)
    n_hours = 0
    for rite in args.rites.split(","):
        adir = os.path.join(args.app, rite)
        if not os.path.isdir(adir):
            print("missing app dir", adir); continue
        for fn in sorted(os.listdir(adir)):
            date = fn[:-5]
            if args.start and date < args.start: continue
            if args.end and date > args.end: continue
            appdoc = json.load(open(os.path.join(adir, fn)))
            for hour in args.hours.split(","):
                dof = os.path.join(args.do, rite, date, hour + ".json")
                if not os.path.exists(dof):
                    flags["missing-do"].append((rite, date, hour, "")); continue
                dodoc = json.load(open(dof))
                parts = appdoc["hours"].get(hour)
                if parts is None:
                    flags["missing-app"].append((rite, date, hour, "")); continue
                n_hours += 1
                compare_hour(rite, date, hour, parts, dodoc["sections"], flags)
    out = []
    out.append("hours compared: %d" % n_hours)
    cats = sorted(flags.items(), key=lambda kv: -len(kv[1]))
    for cat, items in cats:
        if args.category and cat != args.category: continue
        out.append("\n== %s: %d" % (cat, len(items)))
        by_hour = Counter(h for _, _, h, _ in items)
        by_rite = Counter(r for r, _, _, _ in items)
        out.append("   by hour: %s" % dict(by_hour))
        out.append("   by rite: %s" % dict(by_rite))
        shown = 0
        seen = set()
        for r, d, h, det in items:
            k = det[:120]
            if k in seen: continue
            seen.add(k)
            out.append("   %s %s %s: %s" % (r, d, h, det[:400]))
            shown += 1
            if shown >= args.max_examples: break
    text = "\n".join(out)
    print(text)
    if args.report:
        with open(args.report, "w") as f:
            f.write(text + "\n")
            f.write("\n\n== ALL FLAGS ==\n")
            for cat, items in cats:
                for r, d, h, det in items:
                    f.write("%s\t%s\t%s\t%s\t%s\n" % (cat, r, d, h, det))


if __name__ == "__main__":
    main()
