"""Phase 1: temporal key + season computation, validated against existing ordo."""
import json, datetime

def easter(year):
    # Anonymous Gregorian algorithm (Meeus/Jones/Butcher)
    a=year%19; b=year//100; c=year%100; d=b//4; e=b%4; f=(b+8)//25
    g=(b-f+1)//3; h=(19*a+b-d-g+15)%30; i=c//4; k=c%4
    l=(32+2*e+2*i-h-k)%7; m=(a+11*h+22*l)//451
    month=(h+l-7*m+114)//31; day=((h+l-7*m+114)%31)+1
    return datetime.date(year, month, day)

def first_advent(year):
    christmas = datetime.date(year,12,25)
    # 4th Sunday before Christmas. Sunday before Christmas:
    dow = christmas.weekday()  # Mon=0..Sun=6
    days_to_prev_sunday = (dow + 1) % 7  # back to Sunday
    sun_before = christmas - datetime.timedelta(days=days_to_prev_sunday)
    return sun_before - datetime.timedelta(weeks=3)

def next_sunday(d):
    while d.weekday() != 6:  # Sunday
        d += datetime.timedelta(days=1)
    return d

def temporal_key(date):
    y=date.year
    e=easter(y); ash=e-datetime.timedelta(days=46)
    pentecost=e+datetime.timedelta(days=49); trinity=e+datetime.timedelta(days=56)
    fadv=first_advent(y); christmas=datetime.date(y,12,25)
    septuagesima=ash-datetime.timedelta(days=17)
    first_sun_lent=ash+datetime.timedelta(days=4)
    # Easter season: e .. pentecost+7
    if e <= date < pentecost+datetime.timedelta(days=7):
        days=(date-e).days; return f"pasc{days//7}-{days%7}"
    if first_sun_lent <= date < e:
        days=(date-first_sun_lent).days; return f"quad{days//7+1}-{days%7}"
    if septuagesima <= date < first_sun_lent:
        days=(date-septuagesima).days; return f"quadp{days//7+1}-{days%7}"
    if fadv <= date < christmas:
        days=(date-fadv).days; return f"adv{days//7+1}-{days%7}"
    if trinity <= date < fadv:
        days=(date-trinity).days; return f"pent{days//7+1:02d}-{days%7}"
    epiphany=datetime.date(y,1,6); epi1=next_sunday(epiphany)
    if epi1 <= date < septuagesima:
        days=(date-epi1).days; return f"epi{days//7+1}-{days%7}"
    # Christmas to Epiphany
    if date >= christmas:
        days=(date-christmas).days; return f"nat{days:02d}"
    if date < epi1:
        # Jan 1 - Epiphany week: still nat days from PREVIOUS christmas
        prev_christmas=datetime.date(y-1,12,25)
        days=(date-prev_christmas).days; return f"nat{days:02d}"
    return None

SEASON={"adv":"advent","nat":"christmas","epi":"ordinary","quadp":"pre-lent",
        "quad":"lent","pasc":"easter","pent":"ordinary"}
def season_of(tk):
    if tk is None: return None
    for pre,s in sorted(SEASON.items(), key=lambda x:-len(x[0])):
        if tk.startswith(pre): return s
    return None

if __name__=="__main__":
    ordo=json.load(open("Introibo/Resources/ordo.json"))
    tk_ok=tk_bad=se_ok=se_bad=0; ex=[]
    for date,e in sorted(ordo.items()):
        d=datetime.date.fromisoformat(date)
        tk=temporal_key(d); se=season_of(tk)
        # The ordo `temporal` field is the temporal key (for both winners).
        exp_tk=e.get("temporal")
        if tk==exp_tk: tk_ok+=1
        else:
            tk_bad+=1
            if len(ex)<12: ex.append((date, "TK", tk, exp_tk))
        if se==e["season"]: se_ok+=1
        else:
            se_bad+=1
            if len(ex)<24: ex.append((date,"SE",se,e["season"]))
    print(f"temporal key: {tk_ok} ok, {tk_bad} bad")
    print(f"season: {se_ok} ok, {se_bad} bad")
    for x in ex: print("  ",x)

def season_of_date(date):
    """Ordo season vocabulary, computed from the date (Ash Wednesday is the
    pre-lent/lent boundary; Passiontide folds into 'lent')."""
    y=date.year
    e=easter(y); ash=e-datetime.timedelta(days=46)
    pentecost=e+datetime.timedelta(days=49); trinity=e+datetime.timedelta(days=56)
    fadv=first_advent(y); christmas=datetime.date(y,12,25)
    septuagesima=ash-datetime.timedelta(days=17)
    epiphany=datetime.date(y,1,6); epi1=next_sunday(epiphany)
    if fadv <= date < christmas: return "advent"
    if date >= christmas or date < epi1 or date == epiphany: return "christmas"
    if epi1 <= date < septuagesima: return "ordinary"
    if septuagesima <= date < ash: return "pre-lent"
    if ash <= date < e: return "lent"
    if e <= date < pentecost+datetime.timedelta(days=7): return "easter"
    return "ordinary"
