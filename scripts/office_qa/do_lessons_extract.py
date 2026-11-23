#!/usr/bin/env python3
"""Render Divinum Officium's Matins and extract every lesson with its
responsory, Latin beside one vernacular column, for build_office_lessons.py.

  do_lessons_extract.py --do /path/to/divinum-officium --out DIR \
      --start 2024-01-01 --end 2030-12-31 [--versions 1962,1955,pre1955] \
      [--langs English,Espanol] [--jobs 4]

Output: DIR/<lang>/<rite>/<date>.json — {"lessons": [{"n": 1, "lat": [..],
"ver": [..]}]}: the lines of the "Lectio N" section in each column, blank
lines kept as "" (they separate the lesson, its responsory and the Te Deum),
reference lines (red italics alone on a line: "1 Mac 5:55-58") prefixed "!".

DO prints the 1960 books' Latin with i for j ("eius", "Iesus": spell_var in
horascommon.pl). The apps keep the j of DO's own files in every book, so the
checkout's spell_var is patched once (idempotently) to leave the j alone
when DO_KEEP_J is set, and every render here sets it.
"""
import argparse, datetime, html, json, os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

VERSIONS = {"1962": "Rubrics 1960 - 1960", "1955": "Reduced - 1955", "pre1955": "Divino Afflatu - 1954"}
ROW = re.compile(r"<TD VALIGN='TOP' WIDTH='50%' ID='Matutinum\d+'>(.*?)</TD>\s*<TD VALIGN='TOP' WIDTH='50%'>(.*?)</TD>", re.S)
HEAD = re.compile(r"<FONT SIZE='\+1' COLOR=\"red\"><B><I>([^<]*)</I></B></FONT>")
REFLINE = re.compile(r"^\s*<FONT COLOR=\"red\"><I>([^<]*)</I></FONT>\s*$")


def patch_spelling(do_root):
    path = os.path.join(do_root, "web/cgi-bin/horas/horascommon.pl")
    src = open(path).read()
    if "DO_KEEP_J" in src: return
    old = "      tr/Jj/Ii/;\n"
    if src.count(old) != 1: sys.exit("spell_var has changed: cannot patch " + path)
    open(path, "w").write(src.replace(old, "      tr/Jj/Ii/ unless $ENV{DO_KEEP_J};\n"))


def run_do(do_root, date, version, lang):
    q = ("date=%d-%d-%d&command=prayMatutinum&version=%s&lang2=%s&expand=all&votive=Hodie"
         % (date.month, date.day, date.year, version.replace(" ", "%20"), lang))
    env = dict(os.environ, QUERY_STRING=q, REQUEST_METHOD="GET", DO_KEEP_J="1")
    p = subprocess.run(["perl", "officium.pl"], cwd=os.path.join(do_root, "web/cgi-bin/horas"),
                       env=env, capture_output=True, text=True, timeout=180)
    return p.stdout


def clean(s):
    m = REFLINE.match(s)
    if m and not re.match(r"^(℣|℟|V|R|Ant|Benedictio|Absolutio)\.?$", m.group(1).strip()):
        return "!" + html.unescape(m.group(1)).strip()
    s = re.sub(r"<span[^>]*>✠</span>", "✠", s)
    s = re.sub(r"<[^>]+>", "", s)
    return re.sub(r"\s+", " ", html.unescape(s)).strip()


def section(cell):
    """(name, lines after the heading) of the +1 red heading in a cell, or None."""
    m = HEAD.search(cell)
    if not m:
        return None
    lines = [clean(x) for x in re.split(r"<br\s*/?>", cell[m.end():], flags=re.I)]
    while lines and lines[0] == "": lines.pop(0)
    while lines and lines[-1] == "": lines.pop()
    return m.group(1).strip(), lines


def extract(page):
    out = []
    for lat, ver in ROW.findall(page):
        a = section(lat)
        if not a: continue
        m = re.match(r"Lectio (\d+)$", a[0])
        if not m: continue
        b = section(ver)
        out.append({"n": int(m.group(1)), "lat": a[1], "ver": b[1] if b else []})
    return out


def one(args):
    do_root, out, rite, lang, date, force = args
    path = os.path.join(out, lang, rite, date.isoformat() + ".json")
    if os.path.exists(path) and not force: return 0
    page = run_do(do_root, date, VERSIONS[rite], lang)
    lessons = extract(page)
    if not lessons:
        sys.stderr.write("no lessons: %s %s %s\n" % (lang, rite, date)); return 0
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump({"lessons": lessons}, open(path, "w"), ensure_ascii=False)
    return 1


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--do", required=True); ap.add_argument("--out", required=True)
    ap.add_argument("--start", required=True); ap.add_argument("--end", required=True)
    ap.add_argument("--versions", default="1962,1955,pre1955"); ap.add_argument("--langs", default="English,Espanol")
    ap.add_argument("--jobs", type=int, default=4); ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    patch_spelling(a.do)
    d = datetime.date.fromisoformat(a.start); end = datetime.date.fromisoformat(a.end)
    jobs = []
    while d <= end:
        for lang in a.langs.split(","):
            for rite in a.versions.split(","):
                jobs.append((a.do, a.out, rite, lang, d, a.force))
        d += datetime.timedelta(days=1)
    with ThreadPoolExecutor(a.jobs) as ex:
        n = sum(ex.map(one, jobs))
    print("done", n)
