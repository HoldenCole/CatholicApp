"""Assemble authoritative ordo entries from DO winners + combined name index +
computed temporal keys/seasons."""
import json, re, unicodedata, datetime, sys
sys.path.insert(0,"scripts")
from gen_ordo_temporal import temporal_key, season_of_date

def norm(s):
    s=unicodedata.normalize("NFD",s); s="".join(c for c in s if unicodedata.category(c)!="Mn").lower()
    s=s.replace("æ","ae").replace("œ","oe"); s=re.sub(r"[^a-z0-9 ]"," ",s); return re.sub(r"\s+"," ",s).strip()

idx=json.load(open("/tmp/ordo_gen/indices.json"))
COMBINED=idx["combined"]; COLLISIONS=set(idx["collisions"]); TEMP=idx["temporal"]
EMBER=re.compile(r"quattuor temporum septembr")
TEMPORAL_MARKERS=("feria","dominica","sabbato","die ","diei ","in vigilia",
                  "sanctae mariae sabbato","octava ","infra octavam","infra hebdomadam","infra tempus")
RANK_BY_CLASS={"i. classis":6.0,"ii. classis":5.0,"iii. classis":3.0,"iv. classis":1.0}

def parse_title(title):
    title=title.split("\t")[0].strip()
    m=re.search(r"~\s*(.+?)\s*$",title); cls=m.group(1).lower() if m else ""
    return re.sub(r"\s*~\s*.+$","",title).strip(), cls

def looks_temporal(nn): return any(nn.startswith(x) or x in nn for x in TEMPORAL_MARKERS)

def temporal_entry(tk, season, mmdd, name, cls):
    tkk=tk
    if EMBER.search(norm(name)) and re.search(r"-(\d)$",tk): tkk="093-"+re.search(r"-(\d)$",tk).group(1)
    t=TEMP.get(tkk) or TEMP.get(tk)
    if t:
        return {"temporal":tkk,"sanctoral":mmdd,"winner":"temporal","winnerKey":tkk,
                "rank":t["rank"],"name":t["name"],"color":t["color"],"season":season}
    col={"advent":"violet","lent":"violet","pre-lent":"violet","easter":"white","christmas":"white"}.get(season,"green")
    return {"temporal":tkk,"sanctoral":mmdd,"winner":"temporal","winnerKey":tkk,
            "rank":RANK_BY_CLASS.get(cls,1.0),"name":name,"color":col,"season":season}

def assemble(date_str, title, commem):
    d=datetime.date.fromisoformat(date_str)
    tk=temporal_key(d); season=season_of_date(d); mmdd=date_str[5:]
    name,cls=parse_title(title); nn=norm(name); has_commem=bool(commem.strip())

    sanct_on_date=any(re.match(r"\d\d-\d\d",v["winnerKey"]) and v["winnerKey"][:5]==mmdd
                      for v in COMBINED.values() if v["winner"]=="sanctoral")

    # Septem Dolorum: sanctoral only on its fixed date 09-15
    if nn=="septem dolorum beatae mariae virginis" and mmdd!="09-15":
        e=temporal_entry(tk,season,mmdd,name,cls); e["commemoration"]=mmdd if (has_commem and sanct_on_date) else None
        return e
    if nn in COLLISIONS:           # generic Christmas/Advent ferias -> computed key
        e=temporal_entry(tk,season,mmdd,name,cls); e["commemoration"]=mmdd if (has_commem and sanct_on_date) else None
        return e
    if nn in COMBINED:
        c=COMBINED[nn]
        if c["winner"]=="sanctoral":
            return {"temporal":tk,"sanctoral":mmdd,"winner":"sanctoral","winnerKey":c["winnerKey"],
                    "rank":c["rank"],"name":c["name"],"color":c["color"],"season":season,"commemoration":tk}
        else:  # temporal-keyed feast (Holy Family, Ascension, Corpus Christi...) — stable key
            return {"temporal":c["winnerKey"],"sanctoral":mmdd,"winner":"temporal","winnerKey":c["winnerKey"],
                    "rank":c["rank"],"name":c["name"],"color":c["color"],"season":season,
                    "commemoration":(mmdd if (has_commem and sanct_on_date) else None)}
    if not nn or looks_temporal(nn):
        e=temporal_entry(tk,season,mmdd,name,cls); e["commemoration"]=mmdd if (has_commem and sanct_on_date) else None
        return e
    # Sanctoral feast impeded in all index years -> synthesize
    return {"temporal":tk,"sanctoral":mmdd,"winner":"sanctoral","winnerKey":mmdd,
            "rank":RANK_BY_CLASS.get(cls,3.0),"name":name,"color":"white","season":season,"commemoration":tk}

def load_rows():
    rows={}
    for line in open("/tmp/ordo_gen/do_winners.tsv"):
        p=line.rstrip("\n").split("\t",2)
        if len(p)>=2: rows[p[0]]=(p[1],p[2] if len(p)>2 else "")
    return rows

if __name__=="__main__":
    rows=load_rows(); existing=json.load(open("Introibo/Resources/ordo.json"))
    wbad=0; drop=[]; add=[]
    for date in sorted(rows):
        if date not in existing: continue
        got=assemble(date,*rows[date]); exp=existing[date]
        if got["winner"]!=exp["winner"]:
            wbad+=1
            if got["winner"]=="temporal" and exp["winner"]=="sanctoral": drop.append((date,exp["name"][:30]))
            else: add.append((date,got["name"][:30]))
    print(f"winner-type diffs vs existing: {wbad}")
    print(f"  existing=sanctoral -> me=temporal (DO demotes feast): {len(drop)}")
    for x in drop[:8]: print("     ",x)
    print(f"  existing=temporal -> me=sanctoral (DO promotes feast): {len(add)}")
    for x in add[:8]: print("     ",x)
