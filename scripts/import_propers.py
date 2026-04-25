#!/usr/bin/env python3
"""
Fetches ALL 1962 Missal propers from DivinumOfficium GitHub repo
(Temporale: Sundays + weekdays) and converts to Introibo's propers.json.
"""
import json, re, sys, time
from urllib.request import urlopen, Request
from urllib.error import URLError

BASE = "https://raw.githubusercontent.com/DivinumOfficium/divinum-officium/master/web/www/missa"

def fetch(url):
    for attempt in range(3):
        try:
            req = Request(url, headers={"User-Agent": "Introibo/1.0"})
            return urlopen(req, timeout=15).read().decode("utf-8", errors="replace")
        except Exception as e:
            if attempt < 2:
                time.sleep(1)
            else:
                return None

def parse_sections(text):
    sections = {}
    current = None
    lines = []
    for line in text.split("\n"):
        line = line.rstrip()
        if line.startswith("[") and line.endswith("]"):
            if current:
                sections[current] = "\n".join(lines).strip()
            current = line[1:-1]
            lines = []
        else:
            lines.append(line)
    if current:
        sections[current] = "\n".join(lines).strip()
    return sections

def fetch_with_redirects(lang, path):
    url = f"{BASE}/{lang}/{path}.txt"
    text = fetch(url)
    if not text:
        return None
    first_line = text.strip().split("\n")[0].strip()
    if first_line.startswith("@"):
        redirect = first_line[1:].strip()
        if ":" in redirect:
            redirect = redirect.split(":")[0]
        if not redirect.endswith(".txt"):
            redirect_url = f"{BASE}/{lang}/{redirect}.txt"
        else:
            redirect_url = f"{BASE}/{lang}/{redirect}"
        redirected = fetch(redirect_url)
        if redirected:
            base_sections = parse_sections(redirected)
            override_sections = parse_sections(text)
            base_sections.update({k: v for k, v in override_sections.items() if v.strip()})
            lines = []
            for k, v in base_sections.items():
                lines.append(f"[{k}]")
                lines.append(v)
                lines.append("")
            return "\n".join(lines)
    return text

def resolve_at_ref(text, lang):
    if not text:
        return text
    resolved_lines = []
    for line in text.split("\n"):
        stripped = line.strip()
        if stripped.startswith("@") and "/" in stripped:
            ref_path = stripped[1:]
            if ":" in ref_path:
                ref_path = ref_path.split(":")[0]
            fetched = fetch(f"{BASE}/{lang}/{ref_path}.txt")
            if fetched:
                resolved_lines.append(fetched)
            continue
        resolved_lines.append(line)
    return "\n".join(resolved_lines)

def clean_text(text):
    if not text:
        return ""
    lines = []
    for line in text.split("\n"):
        line = line.strip()
        if not line: continue
        if line.startswith("@"): continue
        if line.startswith("!"): continue
        if line.startswith("$"): continue
        if line.startswith("&"): continue
        if line.startswith("//"): continue
        if line.startswith("_"): line = line.strip("_")
        if line.startswith("v. "): line = line[3:]
        elif line.startswith("v."): line = line[2:].lstrip()
        if line.startswith("r. "): line = line[3:]
        elif line.startswith("r."): line = line[2:].lstrip()
        # Remove ++ cross markers
        line = line.replace("++", "").replace("+ ", "").strip()
        if line.startswith("Continuation  of"):
            continue
        if line.startswith("Continuation of"):
            continue
        if line.startswith("Sequéntia") or line.startswith("Léctio") or line.startswith("Lesson from"):
            continue
        lines.append(line)
    return " ".join(lines).strip()

def extract_ref(text):
    if not text:
        return ""
    for line in text.split("\n"):
        line = line.strip()
        if line.startswith("!") and not line.startswith("!!"):
            ref = line[1:].strip()
            if ref and any(c.isdigit() for c in ref):
                return ref
    return ""

def get_section(sections, *keys):
    for k in keys:
        if k in sections:
            return sections[k]
    return ""

DOW_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
DOW_LATIN = ["Domínica", "Feria II", "Feria III", "Feria IV", "Feria V", "Feria VI", "Sábbato"]

def slug_from_filename(filename):
    """Convert DO filename to our slug format."""
    name = filename.replace(".txt", "")

    # Pasc = Easter season
    m = re.match(r'Pasc(\d+)-(\d+)', name)
    if m:
        week, dow = int(m.group(1)), int(m.group(2))
        if week == 0 and dow == 0: return "easter-sunday"
        if dow == 0: return f"easter-{week}"
        return f"easter-{week}-{dow}"

    # Quad = Lent, Quadp = Pre-Lent
    m = re.match(r'Quadp(\d+)-(\d+)', name)
    if m:
        week, dow = int(m.group(1)), int(m.group(2))
        names = {1: "septuagesima", 2: "sexagesima", 3: "quinquagesima"}
        if dow == 0: return names.get(week, f"prelent-{week}")
        return f"{names.get(week, f'prelent-{week}')}-{dow}"

    m = re.match(r'Quad(\d+)-(\d+)', name)
    if m:
        week, dow = int(m.group(1)), int(m.group(2))
        if week == 6 and dow == 0: return "palm-sunday"
        if week == 5 and dow == 0: return "passion-sunday"
        if dow == 0: return f"lent-{week}"
        if week == 6: return f"holy-week-{dow}"
        return f"lent-{week}-{dow}"

    # Pent = Post-Pentecost
    m = re.match(r'Pent(\d+)-(\d+)', name)
    if m:
        week, dow = int(m.group(1)), int(m.group(2))
        if week == 1 and dow == 0: return "trinity-sunday"
        if dow == 0: return f"pentecost-{week}"
        return f"pentecost-{week}-{dow}"

    # Adv = Advent
    m = re.match(r'Adv(\d+)-(\d+)', name)
    if m:
        week, dow = int(m.group(1)), int(m.group(2))
        if dow == 0: return f"advent-{week}"
        return f"advent-{week}-{dow}"

    # Epi = Epiphany
    m = re.match(r'Epi(\d+)-(\d+)', name)
    if m:
        week, dow = int(m.group(1)), int(m.group(2))
        if dow == 0: return f"epiphany-{week}"
        return f"epiphany-{week}-{dow}"

    # Numbered (Ember days etc)
    m = re.match(r'(\d+)-(\d+)', name)
    if m:
        return f"ember-{m.group(1)}-{m.group(2)}"

    return name.lower()

def title_from_filename(filename, lang="latin"):
    name = filename.replace(".txt", "")

    m = re.match(r'Pasc(\d+)-(\d+)', name)
    if m:
        week, dow = int(m.group(1)), int(m.group(2))
        if week == 0 and dow == 0:
            return ("Domínica Resurrectiónis", "Easter Sunday")
        if dow == 0:
            return (f"Domínica {['','I','II','III','IV','V','VI','VII'][week]} post Pascha",
                    f"{'Low Sunday' if week==1 else ['','1st','2nd','3rd','4th','5th','6th','7th'][week]+' Sunday after Easter'}")
        return (f"{DOW_LATIN[dow]} post Dom. {['','I','II','III','IV','V','VI','VII'][week]} post Pascha",
                f"{DOW_NAMES[dow]} after {['','1st','2nd','3rd','4th','5th','6th','7th'][week]} Sunday after Easter")

    m = re.match(r'Quadp(\d+)-(\d+)', name)
    if m:
        week, dow = int(m.group(1)), int(m.group(2))
        names_lat = {1: "Septuagésima", 2: "Sexagésima", 3: "Quinquagésima"}
        names_eng = {1: "Septuagesima", 2: "Sexagesima", 3: "Quinquagesima"}
        if dow == 0:
            return (f"Domínica in {names_lat[week]}", f"{names_eng[week]} Sunday")
        return (f"{DOW_LATIN[dow]} post {names_lat[week]}", f"{DOW_NAMES[dow]} after {names_eng[week]}")

    m = re.match(r'Quad(\d+)-(\d+)', name)
    if m:
        week, dow = int(m.group(1)), int(m.group(2))
        week_roman = ['','I','II','III','IV','V','VI'][week]
        if week == 6 and dow == 0: return ("Domínica in Palmis", "Palm Sunday")
        if week == 5 and dow == 0: return ("Domínica Passiónis", "Passion Sunday")
        if dow == 0: return (f"Domínica {week_roman} in Quadragésima", f"{'Laetare' if week==4 else ''} {'Sunday' if week!=4 else 'Sunday'} of Lent {week_roman}".strip())
        if week == 6:
            hw_eng = {1:"Monday of Holy Week",2:"Tuesday of Holy Week",3:"Spy Wednesday",4:"Holy Thursday",5:"Good Friday",6:"Holy Saturday"}
            hw_lat = {1:"Feria II Hebdomadæ Sanctæ",2:"Feria III Hebdomadæ Sanctæ",3:"Feria IV Hebdomadæ Sanctæ",4:"Feria V in Cena Dómini",5:"Feria VI in Passióne Dómini",6:"Sábbato Sancto"}
            return (hw_lat.get(dow, f"Hebdomada Sancta {dow}"), hw_eng.get(dow, f"Holy Week Day {dow}"))
        return (f"{DOW_LATIN[dow]} post Dom. {week_roman} Quadragésimæ", f"{DOW_NAMES[dow]} of Lent Week {week}")

    m = re.match(r'Pent(\d+)-(\d+)', name)
    if m:
        week, dow = int(m.group(1)), int(m.group(2))
        if week == 1 and dow == 0: return ("Festum Sanctíssimæ Trinitátis", "Trinity Sunday")
        if dow == 0:
            return (f"Domínica {week} post Pentecósten", f"{'Last' if week==24 else ''} {week}{'st' if week==1 else 'nd' if week==2 else 'rd' if week==3 else 'th'} Sunday after Pentecost".strip())
        return (f"{DOW_LATIN[dow]} post Dom. {week} post Pent.", f"{DOW_NAMES[dow]} after {week}{'th' if week>3 else ['st','nd','rd'][week-1]} Sunday after Pentecost")

    m = re.match(r'Adv(\d+)-(\d+)', name)
    if m:
        week, dow = int(m.group(1)), int(m.group(2))
        week_roman = ['','I','II','III','IV'][week]
        if dow == 0:
            return (f"Domínica {week_roman} Advéntus", f"{'Gaudete' if week==3 else ''} {week_roman} Sunday of Advent".strip())
        return (f"{DOW_LATIN[dow]} Hebd. {week_roman} Advéntus", f"{DOW_NAMES[dow]} of Advent Week {week}")

    m = re.match(r'Epi(\d+)-(\d+)', name)
    if m:
        week, dow = int(m.group(1)), int(m.group(2))
        if dow == 0:
            return (f"Domínica {week} post Epiphaníam", f"{week}{'st' if week==1 else 'nd' if week==2 else 'rd' if week==3 else 'th'} Sunday after Epiphany")
        return (f"{DOW_LATIN[dow]} post Dom. {week} post Epiph.", f"{DOW_NAMES[dow]} after {week}{'th' if week>3 else ['st','nd','rd'][week-1]} Sunday after Epiphany")

    return (name, name)

def color_from_filename(filename):
    name = filename.replace(".txt","")
    if "Pasc" in name: return "white"
    if "Quad" in name and "Quadp" not in name: return "violet"
    if name == "Quad4-0": return "rose"
    if "Adv" in name: return "violet"
    if name == "Adv3-0": return "rose"
    if "Pent" in name:
        m = re.match(r'Pent01-0', name)
        if m: return "white"
        return "green"
    return "green"

def season_from_filename(filename):
    name = filename.replace(".txt","")
    if "Pasc" in name: return "easter"
    if "Quadp" in name: return "perAnnum"
    if "Quad" in name:
        m = re.match(r'Quad(\d+)', name)
        if m and int(m.group(1)) >= 5: return "passion"
        return "lent"
    if "Pent" in name: return "perAnnum"
    if "Adv" in name: return "advent"
    if "Epi" in name: return "perAnnum"
    return "perAnnum"

def build_proper(do_path, slug, title_lat, title_eng, color, season):
    lat_text = fetch_with_redirects("Latin", do_path)
    eng_text = fetch_with_redirects("English", do_path)
    if not lat_text or not eng_text:
        return None

    lat = parse_sections(lat_text)
    eng = parse_sections(eng_text)

    for key in list(lat.keys()):
        lat[key] = resolve_at_ref(lat[key], "Latin")
    for key in list(eng.keys()):
        eng[key] = resolve_at_ref(eng[key], "English")

    def txt(section_name):
        return (clean_text(get_section(lat, section_name)),
                clean_text(get_section(eng, section_name)))

    introit = txt("Introitus")
    collect = txt("Oratio")
    epistle = txt("Lectio")
    gradual = txt("Graduale")
    gospel = txt("Evangelium")
    offertory = txt("Offertorium")
    secret = txt("Secreta")
    communion = txt("Communio")
    postcomm = txt("Postcommunio")
    tract = txt("Tractus")

    ep_ref = extract_ref(get_section(lat, "Lectio"))
    go_ref = extract_ref(get_section(lat, "Evangelium"))

    # Skip if essential parts are empty
    if not introit[0] and not collect[0] and not epistle[0]:
        return None

    proper = {
        "slug": slug,
        "title": title_lat,
        "english": title_eng,
        "rank": 1 if "-0" in do_path or "sunday" in slug else 3,
        "color": color,
        "season": season,
        "introit": {"lat": introit[0], "eng": introit[1]},
        "collect": {"lat": collect[0], "eng": collect[1]},
        "epistle": {"ref": ep_ref, "lat": epistle[0], "eng": epistle[1]},
        "gradual": {"lat": gradual[0], "eng": gradual[1]} if gradual[0] else None,
        "alleluia": None,
        "tract": {"lat": tract[0], "eng": tract[1]} if tract[0] else None,
        "sequence": None,
        "gospel": {"ref": go_ref, "lat": gospel[0], "eng": gospel[1]},
        "offertory": {"lat": offertory[0], "eng": offertory[1]},
        "secret": {"lat": secret[0], "eng": secret[1]},
        "communion": {"lat": communion[0], "eng": communion[1]},
        "postcommunion": {"lat": postcomm[0], "eng": postcomm[1]},
        "preface": None
    }
    return proper

def main():
    # Get all Tempora files from the repo
    print("Fetching file list...")
    tree_url = "https://api.github.com/repos/DivinumOfficium/divinum-officium/git/trees/master?recursive=1"
    tree_text = fetch(tree_url)
    if not tree_text:
        print("Failed to fetch repo tree")
        sys.exit(1)

    tree = json.loads(tree_text)
    tempora_files = sorted(set([
        t['path'].split('/')[-1].replace('.txt','')
        for t in tree.get('tree', [])
        if 'missa/Latin/Tempora/' in t['path']
        and t['path'].endswith('.txt')
        and 'r.txt' not in t['path']  # skip redirect-only files
        and 'o.txt' not in t['path']  # skip old-rite variants
    ]))

    print(f"Found {len(tempora_files)} Tempora files")

    propers = []
    failed = []

    for i, filename in enumerate(tempora_files):
        slug = slug_from_filename(filename + ".txt")
        title_lat, title_eng = title_from_filename(filename + ".txt")
        color = color_from_filename(filename + ".txt")
        season = season_from_filename(filename + ".txt")
        do_path = f"Tempora/{filename}"

        print(f"[{i+1}/{len(tempora_files)}] {slug}...", end=" ", flush=True)
        proper = build_proper(do_path, slug, title_lat, title_eng, color, season)
        if proper:
            propers.append(proper)
            print("OK")
        else:
            failed.append(slug)
            print("SKIP")
        time.sleep(0.15)

    out_path = "Introibo/Resources/propers.json"
    with open(out_path, "w") as f:
        json.dump(propers, f, indent=2, ensure_ascii=False)

    print(f"\nDone: {len(propers)} propers written ({len(failed)} skipped)")
    if failed:
        print(f"Skipped: {failed[:20]}{'...' if len(failed)>20 else ''}")

if __name__ == "__main__":
    main()
