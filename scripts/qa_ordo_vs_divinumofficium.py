#!/usr/bin/env python3
"""QA the DISPLAYED feast name (ordo.name) against DO's authoritative 1962
fixed sanctoral calendar, for sanctoral-winning dates in 2026/2027.

Only flags dates where the sanctoral feast WINS in our ordo but the displayed
name disagrees with DO's authoritative feast for that fixed date — i.e. a real
"wrong feast shown" bug, not a precedence/commemoration difference.
"""
import json, re, unicodedata
from pathlib import Path

KAL = Path("/tmp/do_repo/web/www/Tabulae/Kalendaria")
CHAIN = ["1570", "1888", "1906", "1939", "1954", "1955", "1960"]

def parse_file(name):
    out = {}
    for raw in (KAL / f"{name}.txt").read_text(encoding="latin-1").splitlines():
        line = raw.strip()
        if not line or line.startswith("*") or line.startswith("#"):
            continue
        m = re.match(r"^(\d{2}-\d{2})=(.*)$", line)
        if not m:
            continue
        date, rest = m.group(1), m.group(2)
        if rest.startswith("XXXXX"):
            out[date] = None
            continue
        parts = rest.split("=")
        if len(parts) >= 3:
            out[date] = parts[1].strip()
    return out

def build_authoritative():
    cal = {}
    for f in CHAIN:
        for date, name_ in parse_file(f).items():
            if name_ is None:
                cal.pop(date, None)
            elif name_:
                cal[date] = name_
    return cal

def norm(s):
    if not s:
        return ""
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = s.lower()
    s = re.sub(r"æ", "ae", s); s = re.sub(r"œ", "oe", s)
    s = re.sub(r"[^a-z ]", " ", s)
    for a, b in [("ss ","s "),("ep ","episcopi "),("conf ","confessoris "),
                 ("mart ","martyris "),("virg ","virginis "),("doct ","doctoris "),
                 ("pp ","papae "),("bmv","beatae mariae virginis")]:
        s = s.replace(a, b)
    return re.sub(r"\s+", " ", s).strip()

def first_saint(s):
    """Leading saint tokens up to the first role word — robust to spelling."""
    toks = norm(s).split()
    roles = {"papae","episcopi","confessoris","martyris","martyrum","virginis",
             "viduae","abbatis","apostoli","evangelistae","doctoris","reginae",
             "presbyteri","diaconi","et","ac","sociorum","soc"}
    out = []
    for t in toks:
        if t in roles:
            break
        out.append(t)
    return set(out)

def overlap(a, b):
    sa, sb = first_saint(a), first_saint(b)
    if not sa or not sb:
        ta, tb = set(norm(a).split()), set(norm(b).split())
        return len(ta & tb)/max(len(ta),len(tb),1)
    return len(sa & sb)/max(len(sa),len(sb))

def main():
    auth = build_authoritative()
    ordo = json.loads(Path("/home/user/CatholicApp/Introibo/Resources/ordo.json").read_text())

    bugs = []
    seen = set()
    for k in sorted(ordo):
        if not (k.startswith("2026-") or k.startswith("2027-")):
            continue
        e = ordo[k]
        if e.get("winner") != "sanctoral":
            continue
        mmdd = k[5:]
        if mmdd not in auth:
            continue
        do_name = auth[mmdd]
        our_name = e.get("name", "")
        sim = overlap(do_name, our_name)
        if sim < 0.5 and mmdd not in seen:
            seen.add(mmdd)
            bugs.append((mmdd, do_name, our_name, round(sim, 2)))

    print(f"Sanctoral-winning dates where displayed feast disagrees with DO 1962:")
    print(f"({len(bugs)} distinct dates)\n")
    for mmdd, do_n, our_n, sim in sorted(bugs):
        print(f"  {mmdd}  (saint-overlap {sim})")
        print(f"     DO 1962 : {do_n}")
        print(f"     ours    : {our_n}\n")

if __name__ == "__main__":
    main()
