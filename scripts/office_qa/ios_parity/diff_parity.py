#!/usr/bin/env python3
"""Diff the iOS and Android Office/Mass dumps (see README.md in this directory).

  diff_parity.py --android DIR --ios DIR [--rites 1962,1955,pre1955] [--show N]

Both dumps hold <rite>/<date>.json with every assembled hour's parts and the
day's Mass proper. Any difference is a platform bug: the two apps must render
the same text from the same data.
"""
import argparse, collections, glob, json, os, sys

ap = argparse.ArgumentParser()
ap.add_argument("--android", required=True); ap.add_argument("--ios", required=True)
ap.add_argument("--rites", default="1962,1955,pre1955"); ap.add_argument("--show", type=int, default=4)
a = ap.parse_args()

def norm(v):
    if isinstance(v, float) and v == int(v): return int(v)
    if isinstance(v, dict): return {k: norm(x) for k, x in v.items() if x is not None}
    if isinstance(v, list): return [norm(x) for x in v]
    return v

total = 0; days = 0
cats = collections.Counter(); examples = collections.defaultdict(list)
def flag(cat, where, detail):
    global total
    total += 1; cats[cat] += 1
    if len(examples[cat]) < a.show: examples[cat].append((where, detail))

for rite in a.rites.split(","):
    for f in sorted(glob.glob(os.path.join(a.android, rite, "*.json"))):
        date = os.path.basename(f)[:-5]
        g = os.path.join(a.ios, rite, date + ".json")
        if not os.path.exists(g): flag("missing-ios-day", f"{rite} {date}", ""); continue
        A = norm(json.load(open(f))); I = norm(json.load(open(g))); days += 1
        if A.get("ordo") != I.get("ordo"): flag("ordo", f"{rite} {date}", f"{A.get('ordo')} / {I.get('ordo')}")
        for hour in sorted(set(A["hours"]) | set(I["hours"])):
            ah = A["hours"].get(hour); ih = I["hours"].get(hour)
            where = f"{rite} {date} {hour}"
            if ah is None or ih is None: flag(f"{hour}:missing", where, f"android={ah is not None} ios={ih is not None}"); continue
            if len(ah) != len(ih):
                flag(f"{hour}:part-count", where, f"android {len(ah)} ios {len(ih)}: A={[p.get('vk') or p['type'] for p in ah]} I={[p.get('vk') or p['type'] for p in ih]}")
                continue
            for n, (p, q) in enumerate(zip(ah, ih)):
                for k in sorted(set(p) | set(q)):
                    if p.get(k) != q.get(k):
                        flag(f"{hour}:{p.get('vk') or p['type']}:{k}", f"{where} #{n}", f"A={str(p.get(k))[:160]!r} I={str(q.get(k))[:160]!r}")
        am = A.get("mass"); im = I.get("mass")
        if (am is None) != (im is None): flag("mass:missing", f"{rite} {date}", f"android={am is not None} ios={im is not None}")
        elif am:
            for k in sorted(set(am) | set(im)):
                if am.get(k) != im.get(k): flag(f"mass:{k}", f"{rite} {date}", f"A={str(am.get(k))[:160]!r} I={str(im.get(k))[:160]!r}")

print(f"{days} rite-days compared, {total} differences in {len(cats)} categories")
for cat, n in cats.most_common(60):
    print(f"\n[{n}] {cat}")
    for where, detail in examples[cat]: print(f"    {where}: {detail}")
sys.exit(1 if total else 0)
