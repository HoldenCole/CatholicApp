#!/usr/bin/env python3
"""
Fetches 1962 Missal propers from DivinumOfficium GitHub repo
and converts them to Introibo's propers.json format.
"""
import json, re, sys, time
from urllib.request import urlopen, Request
from urllib.error import URLError

BASE = "https://raw.githubusercontent.com/DivinumOfficium/divinum-officium/master/web/www/missa"

# Map DO filenames to our slugs and metadata
SUNDAYS = [
    # Eastertide
    ("Pasc0-0", "easter-sunday", "Domínica Resurrectiónis", "Easter Sunday", "white", "easter"),
    ("Pasc1-0", "easter-1", "Domínica in Albis", "Low Sunday", "white", "easter"),
    ("Pasc2-0", "easter-2", "Domínica II post Pascha", "Second Sunday after Easter", "white", "easter"),
    ("Pasc3-0", "easter-3", "Domínica III post Pascha", "Third Sunday after Easter", "white", "easter"),
    ("Pasc4-0", "easter-4", "Domínica IV post Pascha", "Fourth Sunday after Easter", "white", "easter"),
    ("Pasc5-0", "easter-5", "Domínica V post Pascha", "Fifth Sunday after Easter (Rogation)", "white", "easter"),
    ("Pasc6-0", "easter-6", "Domínica post Ascensiónem", "Sunday after the Ascension", "white", "easter"),
    ("Pasc7-0", "pentecost-sunday", "Domínica Pentecóstes", "Pentecost Sunday", "red", "easter"),
    # Pre-Lent
    ("Quadp1-0", "septuagesima", "Domínica in Septuagésima", "Septuagesima Sunday", "violet", "perAnnum"),
    ("Quadp2-0", "sexagesima", "Domínica in Sexagésima", "Sexagesima Sunday", "violet", "perAnnum"),
    ("Quadp3-0", "quinquagesima", "Domínica in Quinquagésima", "Quinquagesima Sunday", "violet", "perAnnum"),
    # Lent
    ("Quad1-0", "lent-1", "Domínica I in Quadragésima", "First Sunday of Lent", "violet", "lent"),
    ("Quad2-0", "lent-2", "Domínica II in Quadragésima", "Second Sunday of Lent", "violet", "lent"),
    ("Quad3-0", "lent-3", "Domínica III in Quadragésima", "Third Sunday of Lent", "violet", "lent"),
    ("Quad4-0", "lent-4", "Domínica IV in Quadragésima", "Fourth Sunday of Lent (Laetare)", "rose", "lent"),
    ("Quad5-0", "passion-sunday", "Domínica Passiónis", "Passion Sunday", "violet", "passion"),
    ("Quad6-0", "palm-sunday", "Domínica in Palmis", "Palm Sunday", "violet", "passion"),
    # Post-Pentecost
    ("Pent01-0", "trinity-sunday", "Festum Sanctíssimæ Trinitátis", "Trinity Sunday", "white", "perAnnum"),
    ("Pent02-0", "pentecost-2", "Domínica II post Pentecósten", "Second Sunday after Pentecost", "green", "perAnnum"),
    ("Pent03-0", "pentecost-3", "Domínica III post Pentecósten", "Third Sunday after Pentecost", "green", "perAnnum"),
    ("Pent04-0", "pentecost-4", "Domínica IV post Pentecósten", "Fourth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent05-0", "pentecost-5", "Domínica V post Pentecósten", "Fifth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent06-0", "pentecost-6", "Domínica VI post Pentecósten", "Sixth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent07-0", "pentecost-7", "Domínica VII post Pentecósten", "Seventh Sunday after Pentecost", "green", "perAnnum"),
    ("Pent08-0", "pentecost-8", "Domínica VIII post Pentecósten", "Eighth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent09-0", "pentecost-9", "Domínica IX post Pentecósten", "Ninth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent10-0", "pentecost-10", "Domínica X post Pentecósten", "Tenth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent11-0", "pentecost-11", "Domínica XI post Pentecósten", "Eleventh Sunday after Pentecost", "green", "perAnnum"),
    ("Pent12-0", "pentecost-12", "Domínica XII post Pentecósten", "Twelfth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent13-0", "pentecost-13", "Domínica XIII post Pentecósten", "Thirteenth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent14-0", "pentecost-14", "Domínica XIV post Pentecósten", "Fourteenth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent15-0", "pentecost-15", "Domínica XV post Pentecósten", "Fifteenth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent16-0", "pentecost-16", "Domínica XVI post Pentecósten", "Sixteenth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent17-0", "pentecost-17", "Domínica XVII post Pentecósten", "Seventeenth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent18-0", "pentecost-18", "Domínica XVIII post Pentecósten", "Eighteenth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent19-0", "pentecost-19", "Domínica XIX post Pentecósten", "Nineteenth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent20-0", "pentecost-20", "Domínica XX post Pentecósten", "Twentieth Sunday after Pentecost", "green", "perAnnum"),
    ("Pent21-0", "pentecost-21", "Domínica XXI post Pentecósten", "Twenty-first Sunday after Pentecost", "green", "perAnnum"),
    ("Pent22-0", "pentecost-22", "Domínica XXII post Pentecósten", "Twenty-second Sunday after Pentecost", "green", "perAnnum"),
    ("Pent23-0", "pentecost-23", "Domínica XXIII post Pentecósten", "Twenty-third Sunday after Pentecost", "green", "perAnnum"),
    ("Pent24-0", "pentecost-24", "Domínica XXIV post Pentecósten", "Last Sunday after Pentecost", "green", "perAnnum"),
    # Advent
    ("Adv1-0", "advent-1", "Domínica I Advéntus", "First Sunday of Advent", "violet", "advent"),
    ("Adv2-0", "advent-2", "Domínica II Advéntus", "Second Sunday of Advent", "violet", "advent"),
    ("Adv3-0", "advent-3", "Domínica III Advéntus", "Third Sunday of Advent (Gaudete)", "rose", "advent"),
    ("Adv4-0", "advent-4", "Domínica IV Advéntus", "Fourth Sunday of Advent", "violet", "advent"),
    # Epiphany
    ("Epi1-0", "epiphany-1", "Domínica I post Epiphaníam", "First Sunday after Epiphany", "green", "perAnnum"),
    ("Epi2-0", "epiphany-2", "Domínica II post Epiphaníam", "Second Sunday after Epiphany", "green", "perAnnum"),
    ("Epi3-0", "epiphany-3", "Domínica III post Epiphaníam", "Third Sunday after Epiphany", "green", "perAnnum"),
    ("Epi4-0", "epiphany-4", "Domínica IV post Epiphaníam", "Fourth Sunday after Epiphany", "green", "perAnnum"),
    ("Epi5-0", "epiphany-5", "Domínica V post Epiphaníam", "Fifth Sunday after Epiphany", "green", "perAnnum"),
    ("Epi6-0", "epiphany-6", "Domínica VI post Epiphaníam", "Sixth Sunday after Epiphany", "green", "perAnnum"),
]

def fetch(url):
    try:
        req = Request(url, headers={"User-Agent": "Introibo/1.0"})
        return urlopen(req, timeout=15).read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  WARN: {e}", file=sys.stderr)
        return None

def fetch_with_redirects(lang, do_file):
    url = f"{BASE}/{lang}/Tempora/{do_file}.txt"
    text = fetch(url)
    if not text:
        return None
    # Follow @Tempora/ redirects
    first_line = text.strip().split("\n")[0].strip()
    if first_line.startswith("@Tempora/"):
        redirect = first_line.replace("@Tempora/", "").strip()
        if not redirect.endswith(".txt"):
            redirect += ".txt"
        redirect_url = f"{BASE}/{lang}/Tempora/{redirect}"
        redirected = fetch(redirect_url)
        if redirected:
            # Merge: redirected file is the base, original file overrides
            base_sections = parse_sections(redirected)
            override_sections = parse_sections(text)
            base_sections.update({k: v for k, v in override_sections.items() if v.strip()})
            # Reconstruct as text
            lines = []
            for k, v in base_sections.items():
                lines.append(f"[{k}]")
                lines.append(v)
                lines.append("")
            return "\n".join(lines)
    return text

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

def resolve_at_ref(text, lang):
    """If text contains @Path/File lines, fetch and inline them."""
    if not text:
        return text
    resolved_lines = []
    for line in text.split("\n"):
        stripped = line.strip()
        if stripped.startswith("@") and "/" in stripped:
            ref_path = stripped[1:]
            if ":" in ref_path:
                ref_path = ref_path.split(":")[0]
            ref_url = f"{BASE}/{lang}/{ref_path}.txt"
            fetched = fetch(ref_url)
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
        if not line:
            continue
        if line.startswith("@"):
            continue
        if line.startswith("!"):
            continue
        if line.startswith("$"):
            continue
        if line.startswith("&"):
            continue
        if line.startswith("_"):
            line = line.strip("_")
        if line.startswith("v. "):
            line = line[3:]
        elif line.startswith("v."):
            line = line[2:].lstrip()
        if line.startswith("r. "):
            line = line[3:]
        elif line.startswith("r."):
            line = line[2:].lstrip()
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

def get_preface(season, slug):
    if "easter" in slug or "pasc" in slug.lower():
        return "easter"
    if "pentecost" in slug:
        return "holy-ghost"
    if "trinity" in slug:
        return "trinity"
    if "advent" in slug:
        return None
    if "lent" in slug or "passion" in slug or "palm" in slug:
        return None
    if "septuagesima" in slug or "sexagesima" in slug or "quinquagesima" in slug:
        return None
    return None

def build_proper(do_file, slug, title, english, color, season):
    lat_text = fetch_with_redirects("Latin", do_file)
    eng_text = fetch_with_redirects("English", do_file)

    if not lat_text or not eng_text:
        return None

    lat = parse_sections(lat_text)
    eng = parse_sections(eng_text)

    # Resolve any @ references in each section
    for key in list(lat.keys()):
        lat[key] = resolve_at_ref(lat[key], "Latin")
    for key in list(eng.keys()):
        eng[key] = resolve_at_ref(eng[key], "English")

    introit_lat = clean_text(get_section(lat, "Introitus"))
    introit_eng = clean_text(get_section(eng, "Introitus"))

    collect_lat = clean_text(get_section(lat, "Oratio"))
    collect_eng = clean_text(get_section(eng, "Oratio"))

    epistle_lat = clean_text(get_section(lat, "Lectio"))
    epistle_eng = clean_text(get_section(eng, "Lectio"))
    epistle_ref = extract_ref(get_section(lat, "Lectio"))

    gradual_lat = clean_text(get_section(lat, "Graduale"))
    gradual_eng = clean_text(get_section(eng, "Graduale"))

    gospel_lat = clean_text(get_section(lat, "Evangelium"))
    gospel_eng = clean_text(get_section(eng, "Evangelium"))
    gospel_ref = extract_ref(get_section(lat, "Evangelium"))

    offertory_lat = clean_text(get_section(lat, "Offertorium"))
    offertory_eng = clean_text(get_section(eng, "Offertorium"))

    secret_lat = clean_text(get_section(lat, "Secreta"))
    secret_eng = clean_text(get_section(eng, "Secreta"))

    communion_lat = clean_text(get_section(lat, "Communio"))
    communion_eng = clean_text(get_section(eng, "Communio"))

    postcomm_lat = clean_text(get_section(lat, "Postcommunio"))
    postcomm_eng = clean_text(get_section(eng, "Postcommunio"))

    # Check for Tractus (Lent) vs Alleluia (Easter)
    tractus_lat = clean_text(get_section(lat, "Tractus"))
    tractus_eng = clean_text(get_section(eng, "Tractus"))

    proper = {
        "slug": slug,
        "title": title,
        "english": english,
        "rank": 1,
        "color": color,
        "season": season,
        "introit": {"lat": introit_lat, "eng": introit_eng},
        "collect": {"lat": collect_lat, "eng": collect_eng},
        "epistle": {"ref": epistle_ref, "lat": epistle_lat, "eng": epistle_eng},
        "gradual": {"lat": gradual_lat, "eng": gradual_eng} if gradual_lat else None,
        "alleluia": None,
        "tract": {"lat": tractus_lat, "eng": tractus_eng} if tractus_lat else None,
        "sequence": None,
        "gospel": {"ref": gospel_ref, "lat": gospel_lat, "eng": gospel_eng},
        "offertory": {"lat": offertory_lat, "eng": offertory_eng},
        "secret": {"lat": secret_lat, "eng": secret_eng},
        "communion": {"lat": communion_lat, "eng": communion_eng},
        "postcommunion": {"lat": postcomm_lat, "eng": postcomm_eng},
        "preface": get_preface(season, slug)
    }

    return proper

def main():
    propers = []
    total = len(SUNDAYS)

    for i, (do_file, slug, title, english, color, season) in enumerate(SUNDAYS):
        print(f"[{i+1}/{total}] {slug}...", end=" ", flush=True)
        proper = build_proper(do_file, slug, title, english, color, season)
        if proper:
            propers.append(proper)
            print("OK")
        else:
            print("FAILED")
        time.sleep(0.3)  # rate limit

    out_path = "Introibo/Resources/propers.json"
    with open(out_path, "w") as f:
        json.dump(propers, f, indent=2, ensure_ascii=False)

    print(f"\nDone: {len(propers)} propers written to {out_path}")

if __name__ == "__main__":
    main()
