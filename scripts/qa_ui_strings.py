#!/usr/bin/env python3
"""Advisory scan for user-visible English UI literals that bypass the
vernacular layer (ContentStore.uiString / WidgetConfigStore.chrome).

Run from the repo root:  python3 scripts/qa_ui_strings.py

Heuristic: quoted literals passed to Text/Button/Label/... (Swift) or
text=/title=/contentDescription=/Text( (Kotlin) that contain common
English function words. Latin labels, glyphs and interpolation-only
strings do not trip it. Triage by hand; add real ones to
spanish-translation/ui_strings_es.json and route the site through
uiString. Exit status is always 0 — this is a report.
"""
import glob, re, collections

EN = set('the and of to for a an in on at your you this that with from by is are be as or not '
         'all any day today morning evening night prayer prayers hour hours office mass feast saint '
         'saints holy read tap open show hide settings reminder remind about done cancel save edit '
         'delete add remove begin start next back close search results found empty loading error '
         'skip continue share text pdf take tour would like quick what new rule choose again reset '
         'clear progress'.split())
SINGLE = {'done', 'cancel', 'save', 'skip', 'back', 'next', 'edit', 'close', 'begin', 'continue',
          'share', 'ok', 'yes', 'no', 'remove', 'add', 'delete', 'settings', 'search', 'reminder',
          'remind', 'open', 'change', 'retry', 'finish', 'more', 'less', 'all', 'today', 'tomorrow',
          'morning', 'midday', 'evening', 'night', 'week', 'month', 'year'}
# Latin labels, glyphs, slugs and interpolation-only strings.
IGNORE = {'Orémus', 'Orátio', 'Orátio Fátimæ', 'offertory_prayers', 'Divine Office',
          '\\u{203A}', 'Pater Noster  ·  Ave María  ·  Glória Patri', 'Orátio  ·  Stabat Mater',
          'Ave María (${virtues[i - 1]})'}

def english(s):
    w = re.findall(r"[A-Za-z']+", re.sub(r"\\\(.*?\)|\$\{[^}]*\}|\$[A-Za-z_]+", " ", s).lower())
    if not w:
        return False
    if len(w) == 1:
        return w[0] in SINGLE
    return any(x in EN for x in w)

SW = re.compile(r'(?:Text|Label|Button|TextField|SecureField|navigationTitle|confirmationDialog|alert|'
                r'accessibilityLabel|Section|Toggle|Picker|Link|ContentUnavailableView|ShareLink|Menu)'
                r'\(\s*"((?:[^"\\]|\\.)*)"')
KT = re.compile(r'(?:text|title|subtitle|label|contentDescription|placeholder|message|hint)\s*=\s*'
                r'"((?:[^"\\]|\\.)*)"|Text\(\s*"((?:[^"\\]|\\.)*)"')

def main():
    hits = collections.defaultdict(list)
    for f in sorted(glob.glob('Introibo/**/*.swift', recursive=True) + glob.glob('IntroiboWidgets/*.swift')):
        s = open(f, encoding='utf-8').read()
        for m in SW.finditer(s):
            t = m.group(1)
            if 'uiString' in s[max(0, m.start() - 60):m.start()] or t in IGNORE:
                continue
            if english(t):
                hits[f].append((s[:m.start()].count('\n') + 1, t))
    for f in sorted(glob.glob('android/app/src/main/java/**/*.kt', recursive=True)):
        s = open(f, encoding='utf-8').read()
        for m in KT.finditer(s):
            t = m.group(1) if m.group(1) is not None else m.group(2)
            if t is None or t in IGNORE:
                continue
            if 'uiString' in s[max(0, m.start() - 80):m.end() + 60]:
                continue
            if english(t):
                hits[f].append((s[:m.start()].count('\n') + 1, t))
    n = sum(len(v) for v in hits.values())
    print(f"untranslated UI literals (advisory): {n}")
    for f, v in sorted(hits.items()):
        for line, t in v:
            print(f"  {f}:{line}: {t[:90]}")

if __name__ == '__main__':
    main()
