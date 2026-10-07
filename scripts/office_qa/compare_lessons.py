#!/usr/bin/env python3
"""Matins lessons and responsories against Divinum Officium, over the year.

For every date of a rite, the first words of each lesson (its body, past the
title and reference lines) and of each responsory in the app's dump
(OfficeJsonDump / SpanishAuditDump: <app>/<rite>/<date>.json) are compared
with DO's rendered Matins (<do>/<rite>/<date>/matutinum.json, from
do_extract.py); the mismatches are counted per slot with examples, so a
wrong choice of lesson or responsory (the 1960 Sunday contraction, a
feast's Scripture responsories, a transferred feast) stands out.

    python3 scripts/office_qa/compare_lessons.py --app /tmp/esdump --do /tmp/doqa --rites 1962,1955,pre1955 --show 6
"""
import argparse, collections, json, os, re, unicodedata
def norm(s):
    s = unicodedata.normalize('NFD', s)
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn').lower()
    s = s.replace('j','i').replace('v','u').replace('æ','ae').replace('œ','oe')
    return re.sub(r'[^a-z ]+',' ', s)
REF = re.compile(r'^(\d+\s)?[A-Z0-9][\w\.]* ?\d+[:,;\d\-\s]*$|^\d+ ?$')
def body_words(lines, n=6):
    # first n words of first substantive line (skip title/ref lines)
    for l in lines:
        t = re.sub(r'^\d+\s+', '', l.strip())
        if not t or REF.match(t) or t.startswith(('℣','℟','*','Incipit','De ','Léctio','Lectio','Homil','Sermo','Ex ','Liber','Epístola','Initium')): continue
        w = norm(t).split()
        if len(w) >= 3: return ' '.join(w[:n])
    return ''
def resp_words(lines, n=5):
    for l in lines:
        if l.startswith('℟. ') and 'Deo grátias' not in l:
            return ' '.join(norm(l[3:]).split()[:n])
    return ''
def do_matins(rite, date):
    try: d = json.load(open(f'{DO}/{rite}/{date}/matutinum.json'))
    except: return None
    les = {}; res = {}
    for s in d['sections']:
        n = s.get('name') or ''
        m = re.match(r'Lectio (\d)$', n)
        if m:
            ls = s.get('lines') or []
            les[int(m.group(1))] = body_words(ls)
            res[int(m.group(1))] = resp_words(ls)
    return les, res
def app_matins(rite, date):
    try: d = json.load(open(f'{APP}/{rite}/{date}.json'))
    except: return None
    parts = d['hours'].get('matutinum') or []
    les = {}; res = {}
    for p in parts:
        vk = p.get('vk') or ''
        m = re.match(r'lectio(\d)$', vk)
        if m and p.get('lat'):
            les[int(m.group(1))] = body_words(p['lat'].split('\n'))
        m = re.match(r'responsory(\d)$', vk)
        if m and p.get('lat'):
            t = p['lat'].split('\n')[0]
            t = re.sub(r'^(R\.|℟\.)\s*', '', t)
            res[int(m.group(1))] = ' '.join(norm(t).split()[:5])
    return les, res, d.get('ordoName','')
ap = argparse.ArgumentParser()
ap.add_argument('--app', required=True); ap.add_argument('--do', required=True)
ap.add_argument('--rites', default='1962,1955,pre1955'); ap.add_argument('--show', type=int, default=6)
args = ap.parse_args()
APP, DO = args.app, args.do
rites = args.rites.split(','); show = args.show
for rite in rites:
    dates = sorted(os.listdir(f'{DO}/{rite}'))
    cnt = collections.Counter(); ex = collections.defaultdict(list); total = 0
    for date in dates:
        do = do_matins(rite, date); ap = app_matins(rite, date)
        if not do or not ap: continue
        total += 1
        dl, dr = do; al, ar, name = ap
        for k in sorted(set(dl) | set(al)):
            a, b = dl.get(k,''), al.get(k,'')
            if a[:25] != b[:25]:
                cnt[('L',k)] += 1; ex[('L',k)].append((date, name[:30], a, b))
        for k in sorted(set(dr) | set(ar)):
            a, b = dr.get(k,''), ar.get(k,'')
            if a[:20] != b[:20]:
                cnt[('R',k)] += 1; ex[('R',k)].append((date, name[:30], a, b))
    print(f'=== {rite}: {total} days')
    for k in sorted(cnt): 
        print(k, cnt[k])
        for e in ex[k][:show]: print('     ', e)
