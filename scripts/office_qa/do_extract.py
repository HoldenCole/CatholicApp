#!/usr/bin/env python3
"""Run Divinum Officium locally and extract the Latin column of an hour as
a list of sections, for differential QA of the app's Office assembler.

Usage:
  do_extract.py --do /path/to/divinum-officium --out DIR \
      --start 2025-11-30 --end 2026-11-28 --versions 1962,1955,pre1955 \
      [--hours matutinum,laudes,...] [--jobs 4]

Output: DIR/<rite>/<date>/<hour>.json — {"sections": [{"name": ..,
"lines": [..]}]} where every line is the visible Latin text of one <br/>
line, with the DO markup reduced to tags: "Ant. …", "Psalmus 117",
"117:1 …", "℣. …", "℟. …", "[Lectio 1]" etc.
"""
import argparse, datetime, html, json, os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

VERSIONS = {
    "1962": "Rubrics 1960 - 1960",
    "1955": "Reduced - 1955",
    "pre1955": "Divino Afflatu - 1954",
}
HOURS = ["matutinum", "laudes", "prima", "tertia", "sexta", "nona", "vesperae", "completorium"]
DO_HOUR = {"matutinum": "Matutinum", "laudes": "Laudes", "prima": "Prima", "tertia": "Tertia",
           "sexta": "Sexta", "nona": "Nona", "vesperae": "Vesperae", "completorium": "Completorium"}

SECTION_RE = re.compile(r"<FONT SIZE='\+1' COLOR=\"red\"><B><I>([^<]*)</I></B></FONT>\s*(?:<FONT SIZE='-1' >\{([^}]*)\}</FONT>)?")


def run_do(do_root, date, hour, version):
    q = ("date=%d-%d-%d&command=pray%s&version=%s&lang2=English&expand=all&votive=Hodie"
         % (date.month, date.day, date.year, DO_HOUR[hour], version.replace(" ", "%20")))
    env = dict(os.environ, QUERY_STRING=q, REQUEST_METHOD="GET")
    p = subprocess.run(["perl", "officium.pl"], cwd=os.path.join(do_root, "web/cgi-bin/horas"),
                       env=env, capture_output=True, text=True, timeout=120)
    return p.stdout


def clean_line(s):
    s = re.sub(r"<span[^>]*>✠</span>", "✠", s)
    s = re.sub(r"<FONT SIZE='\+[12]' COLOR=\"red\"><B><I>(\w)</I></B></FONT>", r"\1", s)  # drop cap
    s = re.sub(r"<FONT COLOR=\"red\"><I>([^<]*)</I></FONT>", r"\1", s)                     # Ant. / ℣. / Psalmus N
    s = re.sub(r"<FONT SIZE='1' COLOR=\"red\">([^<]*)</FONT>", r"\1", s)                    # verse numbers
    s = re.sub(r"<FONT SIZE='-1' >([^<]*)</FONT>", r"\1", s)                                 # {rubric} / [1]
    s = re.sub(r"<[^>]+>", "", s)
    s = html.unescape(s)
    return re.sub(r"\s+", " ", s).strip()


def parse(html_text, hour):
    # DO anchors Vespers as "Vespera" even though the command is prayVesperae.
    cap = "Vespera" if hour == "vesperae" else DO_HOUR[hour]
    i = html_text.find("<H2 ID='%stop'>" % cap)
    j = html_text.find("</TABLE>", i)
    if i < 0 or j < 0:
        return None
    body = html_text[i:j]
    sections = []
    # Latin column cells only: <TD VALIGN='TOP' WIDTH='50%' ID='PrimaN'>
    for cell in re.findall(r"<TD VALIGN='TOP' WIDTH='50%%' ID='%s\d+'>(.*?)</TD>" % cap, body, re.S):
        cell = re.sub(r"<DIV ALIGN='right'>.*?</DIV>", "", cell, flags=re.S)
        m = SECTION_RE.search(cell)
        name = m.group(1).strip() if m else ""
        rubric = (m.group(2) or "").strip() if m else ""
        rest = cell[m.end():] if m else cell
        lines = [clean_line(l) for l in re.split(r"<br\s*/?>", rest)]
        lines = [l for l in lines if l]
        sections.append({"name": name, "rubric": rubric, "lines": lines})
    return sections


def one(args, rite, date, hour):
    out = os.path.join(args.out, rite, date.isoformat(), hour + ".json")
    if os.path.exists(out) and not args.force:
        return
    os.makedirs(os.path.dirname(out), exist_ok=True)
    text = run_do(args.do, date, hour, VERSIONS[rite])
    sections = parse(text, hour)
    if sections is None:
        sys.stderr.write("no body: %s %s %s\n" % (rite, date, hour))
        sections = []
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"rite": rite, "date": date.isoformat(), "hour": hour, "sections": sections},
                  f, ensure_ascii=False, indent=1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--do", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--start", required=True)
    ap.add_argument("--end", required=True)
    ap.add_argument("--versions", default="1962,1955,pre1955")
    ap.add_argument("--hours", default=",".join(HOURS))
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    start = datetime.date.fromisoformat(args.start)
    end = datetime.date.fromisoformat(args.end)
    jobs = []
    d = start
    while d <= end:
        for rite in args.versions.split(","):
            for hour in args.hours.split(","):
                jobs.append((rite, d, hour))
        d += datetime.timedelta(days=1)
    with ThreadPoolExecutor(max_workers=args.jobs) as ex:
        list(ex.map(lambda j: one(args, *j), jobs))
    print("done", len(jobs))


if __name__ == "__main__":
    main()
