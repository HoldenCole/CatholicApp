"""Generate authoritative ordo.json from DO's headless extraction.
Uses DO's title as the authoritative winner, with the app's temporal key
and season computed from Computus. For 'sanctoral' winners, resolves the
winnerKey from the existing sanctoral index."""
import json, re, unicodedata, datetime, sys
sys.path.insert(0,"scripts")
from gen_ordo_temporal import temporal_key, season_of_date

def norm(s):
    s=unicodedata.normalize("NFD",s); s="".join(c for c in s if unicodedata.category(c)!="Mn").lower()
    s=s.replace("æ","ae").replace("œ","oe"); s=re.sub(r"[^a-z0-9 ]"," ",s); return re.sub(r"\s+"," ",s).strip()

idx=json.load(open("/tmp/ordo_gen/indices.json"))
COMBINED=idx["combined"]; TEMP=idx["temporal"]
EMBER=re.compile(r"quattuor temporum septembr")
# Valid sanctoral keys (from the proper/commune data). When synthesizing a
# sanctoral winnerKey for a feast that wasn't in the name index, prefer the
# variant that actually carries propers (e.g. "10-23r" for St Anthony Mary
# Claret, whose 1960-rubrics office lives under the -r file).
_sp=json.load(open("Introibo/Resources/sanctoral_propers.json"))
_sc=json.load(open("Introibo/Resources/saint_commune.json"))
VALID_SANCT_KEYS=set(_sp)|set(_sc)
def best_sanct_key(mmdd):
    if mmdd in VALID_SANCT_KEYS: return mmdd
    for suf in ("r","o","a"):
        if mmdd+suf in VALID_SANCT_KEYS: return mmdd+suf
    return mmdd
RANK_BY_CLASS={"i. classis":7.0,"ii. classis":5.0,"iii. classis":3.0,"iv. classis":1.0}
# More accurate rank by class
RANK_MAP={
    "i. classis": lambda n,mmdd: 7.0 if ("domini" in n or "nativ" in n or "resurr" in n or "pentecost" in n) else 6.5 if ("assumpt" in n or "epiphan" in n) else 6.0,
    "ii. classis": lambda n,mmdd: 5.0,
    "iii. classis": lambda n,mmdd: 3.0,
    "iv. classis": lambda n,mmdd: 1.0,
}
# Color inference from DO title + class
COLOR_KEYWORDS={
    "martyr":"red","apostol":"red","evangel":"red","passione":"red","crucis":"red",
    "innocen":"red","stephani":"red","laurenti":"red","joannis baptistæ":"red",
    "pentecoste":"red","spiritus":"red",
    "confess":"white","virgin":"white","purific":"white","nativitat":"white",
    "assumpt":"white","concept":"white","corpus":"white","cordis":"white",
    "dedic":"white","angeli":"white","michael":"red","raphael":"white",
    "joseph":"white","annuntiat":"white","transf":"white","epiphan":"white",
    "resurrect":"white","ascension":"white","trinit":"white","omni sancto":"white",
    "defunct":"black","animarum":"black","requiem":"black",
}

def infer_color(name, season, cls_str):
    nn=norm(name)
    for kw,col in COLOR_KEYWORDS.items():
        if kw in nn: return col
    if "dominica" in nn:
        return {"advent":"violet","lent":"violet","pre-lent":"violet","easter":"white","christmas":"white"}.get(season,"green")
    if "feria" in nn or "sabbato" in nn:
        return {"advent":"violet","lent":"violet","pre-lent":"violet","easter":"white","christmas":"white"}.get(season,"green")
    if "ii. classis" in cls_str or "i. classis" in cls_str: return "white"
    return "white"  # saints default

def infer_rank(name, cls_str, season, mmdd):
    nn=norm(name)
    cls=cls_str.strip().rstrip(".")
    if cls in RANK_MAP:
        return RANK_MAP[cls](nn, mmdd)
    # Try to match by known name in COMBINED
    if nn in COMBINED:
        return COMBINED[nn]["rank"]
    return 1.0  # ferial default

_ROMAN={"i":1,"ii":2,"iii":3,"iv":4,"v":5,"vi":6}
def resumed_temporal_key(name, computed):
    """Resumed Epiphany Sundays and the last Pentecost week recur in autumn
    (when there are >24 weeks after Pentecost). DO names them by their proper
    identity; remap to the existing epi/pent24 proper keys so the office reads
    the right formulary instead of falling back to ferial."""
    nn=norm(name)
    m=re.search(r"dominica (i{1,3}|iv|vi?) post epiphaniam", nn)
    if m: return f"epi{_ROMAN[m.group(1)]}-0"
    if "ultima post pentecosten" in nn:
        return "pent24-0"
    if "infra hebdomadam xxiv post octavam pentecostes" in nn and computed and re.search(r"-(\d)$",computed):
        return "pent24-"+re.search(r"-(\d)$",computed).group(1)
    m2=re.search(r"infra hebdomadam (i{1,3}|iv|vi?) post epiphaniam", nn)
    if m2 and computed and re.search(r"-(\d)$",computed):
        return f"epi{_ROMAN[m2.group(1)]}-"+re.search(r"-(\d)$",computed).group(1)
    return None

def parse_title(title):
    title=title.split("\t")[0].strip()
    m=re.search(r"~\s*(.+?)\s*$",title); cls=m.group(1).strip().lower() if m else ""
    return re.sub(r"\s*~\s*.+$","",title).strip(), cls

def is_sanctoral_winner(name, nn, tk, mmdd, season):
    """DO declared this as the winner; is it a sanctoral or temporal office?"""
    if nn in COMBINED:
        return COMBINED[nn]["winner"]=="sanctoral"
    # Heuristics: if name matches a temporal key's name template, it's temporal
    if tk and TEMP.get(tk) and norm(TEMP[tk]["name"])==nn:
        return False
    # Generic temporal markers
    temporal_markers=("feria","dominica","sabbato","die ","diei ","in vigilia",
                      "sanctae mariae sabbato","octava ","infra octavam","infra hebdomadam","infra tempus")
    if any(nn.startswith(x) or x in nn for x in temporal_markers):
        return False
    return True  # named feast → sanctoral

def assemble(date_str, title, commem):
    d=datetime.date.fromisoformat(date_str)
    tk=temporal_key(d); season=season_of_date(d); mmdd=date_str[5:]
    name,cls=parse_title(title); nn=norm(name)
    has_commem=bool(commem.strip())
    if not nn:
        return {"temporal":tk,"sanctoral":mmdd,"winner":"temporal","winnerKey":tk or "",
                "rank":1.0,"name":"Feria","color":"green","season":season,"commemoration":None}
    # Ember remap
    tkk=tk
    if EMBER.search(nn) and tk and re.search(r"-(\d)$",tk):
        tkk="093-"+re.search(r"-(\d)$",tk).group(1)
    # Saturday Office of the BVM ("Sanctæ Mariæ Sabbato"): a IV-class office on
    # free Saturdays. It uses the Saturday Lauds psalmody (already the festal
    # Lauds-I scheme) with the proper BVM Benedictus antiphon, hymn and collect,
    # which live in the dedicated bvm-sab / bvm-sabN commune (the latter for the
    # Christmas season). Route it to that commune as a low-rank sanctoral office.
    if "mariae sabbato" in nn or "mari ae sabbato" in nn or nn.startswith("sanctae mariae sabbato"):
        wkb = {"christmas":"bvm-sabN","easter":"bvm-sabP"}.get(season,"bvm-sab")
        return {"temporal":tk,"sanctoral":mmdd,"winner":"sanctoral","winnerKey":wkb,
                "rank":1.0,"name":name,"color":"white","season":season,"commemoration":tk}
    sanct=is_sanctoral_winner(name,nn,tkk or tk,mmdd,season)
    rank=infer_rank(name,cls,season,mmdd)
    color=infer_color(name,season,cls)
    # Resolve the index entry, allowing for DO dropping an "In Festo "/"Festum "
    # prefix that the source data carries (e.g. Christ the King).
    cnn = nn if nn in COMBINED else next(
        (a for a in ("in festo "+nn, "festum "+nn, "in "+nn) if a in COMBINED), None)
    centry = COMBINED.get(cnn) if cnn else None
    if centry:
        wk=centry["winnerKey"]; color=centry["color"]; rank=centry["rank"]
        sanct=(centry["winner"]=="sanctoral")
    elif sanct:
        wk=best_sanct_key(mmdd)
    else:
        wk=tkk or tk or ""
    if sanct:
        return {"temporal":tk,"sanctoral":mmdd,"winner":"sanctoral","winnerKey":wk,
                "rank":rank,"name":name,"color":color,"season":season,"commemoration":tk}
    else:
        # For temporal feasts found in the index, the index key is the
        # authoritative temporal key (e.g. "Dominica II post Epiphaniam" ->
        # epi2-0); use it for BOTH temporal and winnerKey so the office reads
        # the right proper. Otherwise fall back to the computed key.
        temporal_key_val = wk if centry else (tkk or tk)
        # Resumed Epiphany Sundays / last Pentecost week recurring in autumn.
        resumed = resumed_temporal_key(name, temporal_key_val)
        if resumed: temporal_key_val = resumed
        # Christmas-octave days: the app keys the octave offices by calendar day
        # (nat26..nat31 for Dec 26-31) and the Sunday within the octave as
        # nat1-0, not by the sequential day-from-Christmas count. Remap so the
        # office reads the right octave-day formulary (e.g. Dec 31 -> nat31).
        if "dominica infra octavam nativitatis" in nn:
            temporal_key_val = "nat1-0"
        elif d.month==12 and 26<=d.day<=31:
            temporal_key_val = f"nat{d.day}"
        entry={"temporal":temporal_key_val,"sanctoral":mmdd,"winner":"temporal","winnerKey":temporal_key_val,
               "rank":rank,"name":name,"color":color,"season":season}
        entry["commemoration"]=mmdd if has_commem else None
        return entry

def load_rows():
    rows={}
    for line in open("/tmp/ordo_gen/do_winners.tsv"):
        p=line.rstrip("\n").split("\t",2)
        if len(p)>=2: rows[p[0]]=(p[1],p[2] if len(p)>2 else "")
    return rows

if __name__=="__main__":
    rows=load_rows()
    ordo={}
    for date in sorted(rows):
        ordo[date]=assemble(date,*rows[date])
    print(f"generated {len(ordo)} entries")
    # Quick winner distribution
    from collections import Counter
    w=Counter(e["winner"] for e in ordo.values())
    print(f"winners: {dict(w)}")
    # Validate field completeness
    bad=sum(1 for e in ordo.values() if not e.get("winnerKey") or not e.get("name"))
    print(f"entries missing winnerKey/name: {bad}")

def write_ordo(dest_ios, dest_android):
    """Generate ordo.json from DO's TSV extraction."""
    rows=load_rows()
    ordo={}
    for date in sorted(rows):
        ordo[date]=assemble(date,*rows[date])
    json.dump(ordo, open(dest_ios,"w"), ensure_ascii=False, indent=2)
    json.dump(ordo, open(dest_android,"w"), ensure_ascii=False, indent=2)
    print(f"wrote {len(ordo)} entries to {dest_ios} + {dest_android}")
    from collections import Counter
    print(f"winners: {dict(Counter(e['winner'] for e in ordo.values()))}")
    return ordo
