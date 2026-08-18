#!/usr/bin/env python3
"""Build spanish-translation/hours_parts_es.json — the ordinary of the
hours (hours.json parts) in Spanish.

Sources, in precedence order:
  1. spanish-translation/hours_supplements_es.json — hand translations,
     keyed "<slug>:<part index>:<field>" (absolute precedence).
  2. A Latin<->Spanish pair table built from DivinumOfficium's Psalterium
     trees (Common, Special, Psalmi, and the top-level .txt files): the
     SAME file+section in horas/Latin and horas/Espanol pairs line by
     line, giving the received Spanish formulas for versicles, blessings,
     absolutions, the Pater/Ave/Credo/Confiteor, doxologies, antiphons,
     collects, and the ordinary hymns (traditional verse translations).
  3. The Spanish psalter bank (psalter_es.json) for psalm/canticle
     verses, matched by identical Latin line.

Every translated field replaces the English side only; anything
unmatched is reported and keeps its English.

Output: { "<hour slug>": { "<part index>": {"eng": …, "engR": …,
          "v1Eng": …, …, "antiphonEng": …, "verses": [es|null, …] } } }

Run:  python3 scripts/import_spanish_hours.py
      python3 scripts/sync_spanish_assets.py
"""
import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "spanish-translation" / "hours_parts_es.json"
SUPP_PATH = ROOT / "spanish-translation" / "hours_supplements_es.json"
DEFAULT_DO = Path("/tmp/claude-0/-home-user-CatholicApp/"
                  "71906fbb-67e9-553f-b996-d8565178e126/scratchpad/do_repo")


def nfc(s):
    return unicodedata.normalize("NFC", s)


def arg(flag, default=None):
    if flag in sys.argv:
        return sys.argv[sys.argv.index(flag) + 1]
    return default


def fold(s):
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.lower().replace("æ", "ae").replace("œ", "oe")
    s = re.sub(r"[^a-z0-9ñ ]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


MARKER = re.compile(r"^(?:[VvRr]\.|℣\.|℟\.)\s*")
RUBRIC = re.compile(r"/:[^:]*:/")


def clean_line(l):
    """Strip DO markers, rubrics, tags, metadata, and macros from a line."""
    l = RUBRIC.sub(" ", l)
    l = re.sub(r"\{:[^}]*:\}", " ", l)        # {:H-...:} anchor tags
    l = re.sub(r";;.*$", "", l)               # trailing ";;N" metadata
    l = MARKER.sub("", l.strip())
    l = re.sub(r"^\d+\s+", "", l)             # leading verse numbers
    l = l.replace("+++", "").replace("++", "").replace("+", "")
    l = re.sub(r"[$&]\S+.*$", "", l)          # macro invocations
    return re.sub(r"\s+", " ", l).strip()


def parse_sections(path):
    """DO file -> {section: [raw lines]}."""
    out = {}
    cur = None
    for raw in open(path, encoding="utf-8").read().splitlines():
        m = re.match(r"^\[([^\]]+)\]", raw)
        if m:
            cur = m.group(1)
            out[cur] = []
        elif cur is not None:
            out[cur].append(raw.rstrip())
    return out


def content_lines(lines):
    """Cleaned nonempty content lines of a section (rubrics/macros gone)."""
    out = []
    for l in lines:
        s = l.strip()
        if s in ("_", "") or s.startswith(("!", "@", "#")):
            continue
        c = clean_line(l)
        if c:
            out.append(c)
    return out


def main():
    do_root = Path(arg("--do", str(DEFAULT_DO)))
    lat_horas = do_root / "web/www/horas/Latin"
    es_horas = do_root / "web/www/horas/Espanol"

    # ---- build the pair tables (all trees: Psalterium, Tempora,
    # Commune, Sancti — the ordinary's Sunday Matins content lives in
    # the Tempora files) ----
    line_map = {}    # fold(latin content line) -> spanish content line
    block_map = {}   # fold(whole latin section) -> spanish section lines
    hymn_map = {}    # fold(latin hymn first line) -> spanish stanzas text
    espanol_named = {}   # (relpath, section) -> raw Espanol lines
    pair_files = 0
    for sub in ("Psalterium", "Tempora", "Commune", "Sancti",
                "TemporaM", "CommuneM", "SanctiM"):
        lat_root = lat_horas / sub
        es_root = es_horas / sub
        if not lat_root.exists():
            continue
        for lp in sorted(lat_root.rglob("*.txt")):
            rel = lp.relative_to(lat_root)
            ep = es_root / rel
            if not ep.exists():
                continue
            pair_files += 1
            lsec = parse_sections(lp)
            esec = parse_sections(ep)
            for name, raw in esec.items():
                espanol_named[(f"{sub}/{rel}", name)] = raw
            for name in lsec:
                if name not in esec:
                    continue
                ll = content_lines(lsec[name])
                el = content_lines(esec[name])
                if ll and el:
                    block_map.setdefault(
                        re.sub(r"\d+", " ", fold(" ".join(ll))).strip(), el)
                if len(ll) == len(el):
                    for a, b in zip(ll, el):
                        line_map.setdefault(fold(a), b)
                        # responsory/antiphon lines pack body and response
                        # around " * " — index the segments too, so the
                        # app's split v1/r1 fields can find their halves
                        sa = [x.strip() for x in a.split("*")]
                        sb = [x.strip() for x in b.split("*")]
                        if len(sa) == len(sb) and len(sa) > 1:
                            for xa, xb in zip(sa, sb):
                                if xa and xb:
                                    line_map.setdefault(fold(xa), xb)
                if name.startswith("Hymnus") and ll and el:
                    es_text = "\n".join(
                        "" if l.strip() == "_" else clean_line(l)
                        for l in esec[name]
                        if not l.strip().startswith("!"))
                    es_text = re.sub(r"\n{3,}", "\n\n", es_text).strip()
                    hymn_map.setdefault(fold(ll[0]), es_text)

    # Received prayers the Latin tree hides behind macros ($Pater noster):
    # pulled from the Espanol tree by SECTION NAME, matched to hours parts
    # by the fold-prefix of their Latin.
    SPECIAL = [
        ("pater noster qui es in caelis",
         "Psalterium/Common/Prayers.txt", "Pater noster"),
        ("ave maria gratia plena",
         "Psalterium/Common/Prayers.txt", "Ave Maria"),
        ("credo in deum patrem",
         "Psalterium/Common/Prayers.txt", "Credo"),
        ("confiteor deo omnipotenti",
         "Psalterium/Common/Prayers.txt", "Confiteor_"),
    ]
    special_blocks = []
    for prefix, relpath, name in SPECIAL:
        raw = espanol_named.get((relpath, name))
        if raw:
            text = " ".join(content_lines(raw))
            special_blocks.append((prefix, re.sub(r"\s+", " ", text).strip()))

    supp = (json.load(open(SUPP_PATH, encoding="utf-8"))
            if SUPP_PATH.exists() else {})

    # ---- psalm bank for verses ----
    psalter = json.load(open(ROOT / "Introibo/Resources/psalter.json"))
    psalter_es = json.load(open(ROOT /
                                "spanish-translation/psalter_es.json"))
    REF = re.compile(r"^\d+:\d+[a-d]?\s+")

    def bank_key(l):
        return fold(re.sub(r"\([^)]*\)", " ", REF.sub("", l)))

    bank = {}
    for n, v in psalter.items():
        if n not in psalter_es:
            continue
        lat_pieces = []
        es_pieces = []
        aligned = True
        for ll, el in zip(v["lat"], psalter_es[n]["lines"]):
            # bank values keep their ref prefix stripped so they slot
            # into un-prefixed verse lines
            bank[bank_key(ll)] = REF.sub("", el)
            lp = [x.strip() for x in
                  re.split(r"[†*]", REF.sub("", ll)) if x.strip()]
            ep = [x.strip() for x in
                  re.split(r"[†*]", REF.sub("", el)) if x.strip()]
            if len(lp) != len(ep):
                aligned = False
            lat_pieces.extend(lp)
            es_pieces.extend(ep)
        # the hours split psalm verses at different boundaries than the
        # psalter lines — index every 1-3 piece window so re-grouped
        # verses still find their Spanish
        if aligned and len(lat_pieces) == len(es_pieces):
            for w in (1, 2, 3):
                for i in range(len(lat_pieces) - w + 1):
                    k = fold(" ".join(lat_pieces[i:i + w]))
                    bank.setdefault(k, ", ".join(es_pieces[i:i + w]))

    GLORIA_ES = ("Gloria al Padre, y al Hijo, y al Espíritu Santo. "
                 "Como era en el principio, ahora y siempre, "
                 "por los siglos de los siglos. Amén.")

    # Verse lines the bank cannot match: the invitatory psalm regrouped
    # at different boundaries, the Requiem verses, the doxology's second
    # half, and a few source-data spelling variants (resúrgunt,
    # "ambula vérunt", bráchio). Keyed by fold(latin).
    VERSE_FIXES = {}
    for lt, es_ in [
        ("Intráte in conspéctu ejus in exsultatióne.",
         "Entrad llenos de alegría * en su presencia."),
        ("Laudáte eum in cýmbalis benesonántibus: laudáte eum in cýmbalis "
         "jubilatiónis.",
         "Alabadle con címbalos sonoros: * alabadle con címbalos de júbilo."),
        ("Omnis spíritus laudet Dóminum.",
         "Todo espíritu * alabe al Señor."),
        ("Quia in manu ejus sunt omnes fines terræ, et altitúdines móntium "
         "ipse cónspicit.",
         "Porque en su mano tiene toda la extensión de la tierra, * y suyos "
         "son los más encumbrados montes."),
        ("Quóniam ipsíus est mare, et ipse fecit illud, et áridam "
         "fundavérunt manus ejus.",
         "Suyo es el mar, y obra es de sus manos; * y hechura de sus manos "
         "es la tierra."),
        ("Veníte, adorémus, et procidámus ante Deum: plorémus coram "
         "Dómino, qui fecit nos.",
         "Venid, adoremos y postrémonos ante Dios: * lloremos en presencia "
         "del Señor que nos ha creado."),
        ("Quia ipse est Dóminus Deus noster; nos autem pópulus ejus, et "
         "oves páscuæ ejus.",
         "Porque él es el Señor Dios nuestro; * y nosotros su pueblo, y "
         "ovejas que él apacienta."),
        ("Sicut in exacerbatióne secúndum diem tentatiónis in desérto, ubi "
         "tentavérunt me patres vestri, probavérunt et vidérunt ópera mea.",
         "Como sucedió cuando provocaron mi ira, el día de la tentación en "
         "el desierto, * donde vuestros padres me tentaron, me probaron, y "
         "vieron mis obras."),
        ("Quadragínta annis próximus fui generatióni huic, et dixi: Semper "
         "hi errant corde; ipsi vero non cognovérunt vias meas.",
         "Por espacio de cuarenta años estuve cercano a esta generación, y "
         "dije: Siempre anda descarriado su corazón; * ellos no conocieron "
         "mis caminos."),
        ("Quibus jurávi in ira mea: Si introíbunt in réquiem meam.",
         "Por lo que juré airado: * que no entrarían en mi reposo."),
        ("Ídeo non resúrgunt ímpii in judício, neque peccatóres in "
         "concílio justórum.",
         "Por tanto, no prevalecerán los impíos en el juicio; * ni los "
         "pecadores estarán en la asamblea de los justos."),
        ("Dirumpámus víncula eórum, et projiciámus a nobis jugum ipsórum.",
         "Rompamos, dijeron, sus ataduras, * y sacudamos lejos de nosotros "
         "su yugo."),
        ("Et nunc, reges, intellígite; erudímini, qui judicátis terram.",
         "Ahora pues, ¡oh reyes!, entendedlo: * sed instruidos vosotros "
         "los que juzgáis la tierra."),
        ("Réquiem ætérnam * dona eis, Dómine.",
         "Dales, Señor, * el descanso eterno."),
        ("Et lux perpétua * lúceat eis.",
         "Y brille para ellos * una luz perpetua."),
        ("Fecit poténtiam in bráchio suo: dispérsit supérbos mente cordis "
         "sui.",
         "Desplegó el poder de su brazo: * dispersó a los soberbios de "
         "corazón."),
        ("Hæc porta Dómini; justi intrábunt in eam.",
         "Esta es la puerta del Señor; * por ella entrarán los justos."),
        ("Benedíctus qui venit in nómine Dómini. Benedíximus vobis de domo "
         "Dómini.",
         "Bendito el que viene en el nombre del Señor. * Desde la casa del "
         "Señor os bendecimos."),
        ("Deus Dóminus, et illúxit nobis. Constitúite diem sollémnem in "
         "condénsis usque ad cornu altáris.",
         "El Señor es Dios, y él nos ha alumbrado. * Celebrad el día "
         "solemne con espesas ramas, hasta el ángulo del altar."),
        ("Non enim qui operántur iniquitátem, * in viis ejus ambula vérunt.",
         "Porque los que cometen la maldad, * no andan por los caminos del "
         "Señor."),
        ("Tu mandásti * mandáta tua custódi nimis.",
         "Tú ordenaste que * se guarden exactamente tus mandamientos."),
        ("Montes exsulta vérunt ut aríetes: * et colles sicut agni óvium.",
         "Los montes brincaron de gozo como carneros, * y los collados "
         "como corderitos."),
        ("Sicut erat in princípio, et nunc, et semper, * et in sæcula "
         "sæculórum. Amen.",
         "Como era en el principio, ahora y siempre, * por los siglos de "
         "los siglos. Amén."),
        ("Sicut erat in princípio, et nunc, et semper, et in sǽcula "
         "sæculórum. Amen.",
         "Como era en el principio, ahora y siempre, por los siglos de los "
         "siglos. Amén."),
    ]:
        VERSE_FIXES[fold(lt)] = es_

    def find_line(lat):
        c = fold(clean_line(lat))
        if not c:
            return None
        return line_map.get(c) or bank.get(bank_key(lat))

    def find_block(lat):
        c = fold(re.sub(r"\s+", " ",
                        " ".join(clean_line(x) for x in lat.split("\n"))))
        for prefix, text in special_blocks:
            if c.startswith(prefix):
                return text
        hit = block_map.get(re.sub(r"\d+", " ", c).strip())
        if hit:
            return " ".join(hit)
        # try line-by-line
        parts = []
        for piece in lat.split("\n"):
            if not piece.strip():
                parts.append("")
                continue
            t = find_line(piece)
            if t is None:
                return None
            parts.append(t)
        return "\n".join(parts) if parts else None

    hours = json.load(open(ROOT / "Introibo/Resources/hours.json"))
    out = {}
    misses = []
    n_fields = 0

    SINGLE = [("lat", "eng"), ("latR", "engR"),
              ("v1Lat", "v1Eng"), ("r1Lat", "r1Eng"),
              ("v2Lat", "v2Eng"), ("r2Lat", "r2Eng"),
              ("antiphonLat", "antiphonEng")]

    for hr in hours:
        slug = hr["slug"]
        for idx, p in enumerate(hr["parts"]):
            entry = {}
            key3 = f"{slug}:{idx}"
            for lat_f, eng_f in SINGLE:
                if not p.get(eng_f):
                    continue
                skey = f"{key3}:{eng_f}"
                if skey in supp:
                    entry[eng_f] = supp[skey]
                    n_fields += 1
                    continue
                lat = p.get(lat_f) or ""
                if p["type"] == "hymn" and eng_f == "eng":
                    first = lat.split("\n", 1)[0]
                    t = hymn_map.get(fold(clean_line(first)))
                elif "\n" in lat or len(lat) > 140:
                    t = find_block(lat)
                else:
                    t = find_line(lat)
                    if t is None:
                        t = find_block(lat)
                if t:
                    # preserve the English side's ℣/℟ marker prefix
                    m = re.match(r"^([℣℟VR]\.\s*)", p[eng_f])
                    if m and not re.match(r"^[℣℟VR]\.", t):
                        t = m.group(1) + t
                    entry[eng_f] = nfc(t)
                    n_fields += 1
                else:
                    misses.append((slug, idx, p["type"],
                                   (lat or "?")[:60]))
            if p.get("verses"):
                vkey = f"{key3}:verses"
                if vkey in supp and len(supp[vkey]) == len(p["verses"]):
                    entry["verses"] = supp[vkey]
                    n_fields += len(supp[vkey])
                else:
                    vs = []
                    hit_any = False
                    for vi, vv in enumerate(p["verses"]):
                        el = supp.get(f"{key3}:verses:{vi}")
                        if el is None:
                            el = bank.get(bank_key(vv["lat"]))
                        if el is None:
                            el = VERSE_FIXES.get(fold(vv["lat"]))
                        if el is None and fold(vv["lat"]).startswith(
                                "gloria patri et filio"):
                            el = GLORIA_ES
                        if el is not None:
                            hit_any = True
                        vs.append(el)
                    if hit_any:
                        entry["verses"] = vs
                        n_fields += sum(1 for x in vs if x)
                    else:
                        misses.append((slug, idx, p["type"] + "/verses",
                                       p["verses"][0]["lat"][:60]))
            if entry:
                out.setdefault(slug, {})[str(idx)] = entry

    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1,
                              sort_keys=True) + "\n", encoding="utf-8")
    print(f"paired files: {pair_files}; line table: {len(line_map)}; "
          f"blocks: {len(block_map)}; hymns: {len(hymn_map)}")
    print(f"wrote {sum(len(v) for v in out.values())} parts "
          f"({n_fields} fields)")
    if misses:
        print(f"MISSES {len(misses)}:")
        for m in misses:
            print("   ", m)


if __name__ == "__main__":
    main()
