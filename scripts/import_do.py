#!/usr/bin/env python3
"""
Bulk import DivinumOfficium corpus into Introibo JSON format.

Usage: python3 scripts/import_do.py [--dry-run] [--mass-only] [--office-only]

Reads DO at /tmp/do_repo, writes to Introibo/Resources/*.json
Respects existing populated entries (merge, never overwrite).
"""

import argparse
import json
import logging
import os
import re
import shutil
import sys
from pathlib import Path
from typing import Optional

# ─── Configuration ────────────────────────────────────────────────────────────

DO_ROOT = Path("/tmp/do_repo/web/www")
DO_MISSA_LATIN = DO_ROOT / "missa" / "Latin"
DO_MISSA_ENGLISH = DO_ROOT / "missa" / "English"
DO_HORAS_LATIN = DO_ROOT / "horas" / "Latin"
DO_HORAS_ENGLISH = DO_ROOT / "horas" / "English"

# Commune files for Mass are in the obsolete directory (moved there in DO restructuring)
DO_MISSA_COMMUNE_LATIN = Path("/tmp/do_repo/obsolete/missa/Latin/Commune")
DO_MISSA_COMMUNE_ENGLISH = Path("/tmp/do_repo/obsolete/missa/English/Commune")

RESOURCES_DIR = Path("/home/user/CatholicApp/Introibo/Resources")
ANDROID_ASSETS = Path("/home/user/CatholicApp/android/app/src/main/assets")

TARGET_FILES = [
    "missal_tempora.json",
    "missal_sanctoral.json",
    "temporal_propers.json",
    "sanctoral_propers.json",
    "communes.json",
    "psalter.json",
]

MAX_REF_DEPTH = 5

# ─── Logging ──────────────────────────────────────────────────────────────────

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
log = logging.getLogger(__name__)

# ─── Statistics ───────────────────────────────────────────────────────────────

stats = {
    "created": 0,
    "updated": 0,
    "skipped": 0,
    "unresolved_refs": [],
}

# ─── Macro Constants ────────���─────────────────────────────────────────────────

MACROS = {
    "$Per Dominum": "Per Dóminum nostrum Jesum Christum, Fílium tuum: qui tecum vivit et regnat in unitáte Spíritus Sancti, Deus, per ómnia sǽcula sæculórum. Amen.",
    "$Per eundem": "Per eúndem Dóminum nostrum Jesum Christum Fílium tuum, qui tecum vivit et regnat in unitáte Spíritus Sancti, Deus, per ómnia sǽcula sæculórum. Amen.",
    "$Qui tecum": "Qui tecum vivit et regnat in unitáte Spíritus Sancti, Deus, per ómnia sǽcula sæculórum. Amen.",
    "$Qui vivis": "Qui vivis et regnas cum Deo Patre, in unitáte Spíritus Sancti, Deus, per ómnia sǽcula sæcul��rum. Amen.",
    "$Pater noster": "Pater noster, qui es in cælis, sanctificétur nomen tuum. Advéniat regnum tuum. Fiat volúntas tua, sicut in cælo et in terra. Panem nostrum quotidiánum da nobis hódie. Et dimítte nobis débita nostra, sicut et nos dimíttimus debitóribus nostris. Et ne nos indúcas in tentatiónem: sed líbera nos a malo. Amen.",
    "&Gloria": "Glória Patri, et Fílio, et Spirítui Sancto. Sicut erat in princípio, et nunc, et semper, et in sǽcula sæculórum. Amen.",
    "&Gloria2": "Glória Patri, et Fílio, et Spirítui Sancto. Sicut erat in princípio, et nunc, et semper, et in sǽcula sæculórum. Amen.",
    "&Dominus_vobiscum": "℣. Dóminus vobíscum. ℟. Et cum spíritu tuo.",
    "&Dominus_vobiscum1": "℣. Dóminus vobíscum. ℟. Et cum spíritu tuo.",
    "$Oremus": "Orémus.",
}

# English equivalents of macros
MACROS_ENG = {
    "$Per Dominum": "Through our Lord Jesus Christ, Thy Son, Who liveth and reigneth with Thee in the unity of the Holy Ghost, God, world without end. Amen.",
    "$Per eundem": "Through the same our Lord Jesus Christ, Thy Son, Who liveth and reigneth with Thee in the unity of the Holy Ghost, God, world without end. Amen.",
    "$Qui tecum": "Who liveth and reigneth with Thee in the unity of the Holy Ghost, God, world without end. Amen.",
    "$Qui vivis": "Who livest and reignest with God the Father, in the unity of the Holy Ghost, God, world without end. Amen.",
    "$Pater noster": "Our Father, Who art in heaven, hallowed be Thy name. Thy kingdom come. Thy will be done on earth as it is in heaven. Give us this day our daily bread. And forgive us our trespasses, as we forgive those who trespass against us. And lead us not into temptation: but deliver us from evil. Amen.",
    "&Gloria": "Glory be to the Father, and to the Son, and to the Holy Ghost. As it was in the beginning, is now, and ever shall be, world without end. Amen.",
    "&Gloria2": "Glory be to the Father, and to the Son, and to the Holy Ghost. As it was in the beginning, is now, and ever shall be, world without end. Amen.",
    "&Dominus_vobiscum": "℣. The Lord be with you. ℟. And with thy spirit.",
    "&Dominus_vobiscum1": "℣. The Lord be with you. ℟. And with thy spirit.",
    "$Oremus": "Let us pray.",
}

# Mass section name mapping: DO section -> our JSON field
MASS_SECTION_MAP = {
    "Introitus": "introitus",
    "Oratio": "oratio",
    "Lectio": "lectio",
    "Graduale": "graduale",
    "Evangelium": "evangelium",
    "Offertorium": "offertorium",
    "Secreta": "secreta",
    "Communio": "communio",
    "Postcommunio": "postcommunio",
}

# ─── File Parsing ─────────────────────────────────────────────────────────────


def parse_do_file(path: Path) -> dict:
    """Splits a DO file into sections. Returns dict[section_name] -> list of lines."""
    sections = {}
    current_section = None

    if not path.exists():
        return sections

    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except Exception as e:
        log.warning(f"Cannot read {path}: {e}")
        return sections

    for line in text.split("\n"):
        # Section header
        m = re.match(r"^\[(.+?)\]\s*$", line)
        if m:
            current_section = m.group(1)
            if current_section not in sections:
                sections[current_section] = []
            continue

        if current_section is not None:
            sections[current_section].append(line)

    # Strip trailing empty lines from each section
    for key in sections:
        while sections[key] and sections[key][-1].strip() == "":
            sections[key].pop()

    return sections


def resolve_reference(ref_string: str, base_dir: Path, lang_root: Path,
                      depth: int = 0, _visited: set = None) -> Optional[str]:
    """
    Follows @Path:Section chains recursively.
    ref_string like '@Commune/C5:Introitus' or '@Sancti/02-22:Oratio Petri'
    base_dir is the directory of the current file.
    lang_root is the language root (e.g., /tmp/do_repo/web/www/missa/Latin)
    """
    if _visited is None:
        _visited = set()

    if depth > MAX_REF_DEPTH:
        log.warning(f"Max reference depth exceeded: {ref_string}")
        return None

    # Circular reference guard
    ref_key = f"{base_dir}:{ref_string}"
    if ref_key in _visited:
        log.debug(f"Circular reference detected: {ref_string}")
        return None
    _visited.add(ref_key)

    ref_string = ref_string.strip()
    if not ref_string.startswith("@"):
        return ref_string

    ref_string = ref_string[1:]  # Remove @

    # Parse path and section
    if ":" in ref_string:
        path_part, section_name = ref_string.split(":", 1)
    else:
        path_part = ref_string
        section_name = None

    # Resolve the file path
    if path_part == "" or path_part.startswith(":"):
        # Self-reference (@:Section)
        target_path = base_dir
        if path_part.startswith(":"):
            section_name = path_part[1:]
            target_path = base_dir
    else:
        # Try multiple resolution strategies for Commune references
        target_path = None
        candidates = []

        # Strategy 1: relative to lang_root
        candidates.append(lang_root / (path_part + ".txt"))

        # Strategy 2: For Commune references in missa, try the obsolete directory
        if "Commune" in path_part:
            if "missa" in str(lang_root):
                commune_base = DO_MISSA_COMMUNE_LATIN if "Latin" in str(lang_root) else DO_MISSA_COMMUNE_ENGLISH
                # path_part like "Commune/C5" -> just take the filename part
                commune_file = path_part.split("/")[-1]
                candidates.append(commune_base / (commune_file + ".txt"))
            # Also try horas Commune
            if "Latin" in str(lang_root):
                candidates.append(DO_HORAS_LATIN / (path_part + ".txt"))
            else:
                candidates.append(DO_HORAS_ENGLISH / (path_part + ".txt"))

        # Strategy 3: relative to base_dir parent
        candidates.append(base_dir.parent / (path_part + ".txt"))

        for candidate in candidates:
            if candidate.exists():
                target_path = candidate
                break

        if target_path is None:
            log.debug(f"Cannot resolve reference path: {ref_string} (tried {candidates})")
            stats["unresolved_refs"].append(ref_string)
            return None

    # Parse the target file
    if target_path.is_file():
        sections = parse_do_file(target_path)
    else:
        # Self-reference: we need the file we're already in
        # This case is handled by the caller passing the current sections
        return None

    if section_name and section_name in sections:
        lines = sections[section_name]
        # Check if content starts with another @reference
        content = "\n".join(lines).strip()
        if content.startswith("@"):
            # Recursive reference
            first_line = content.split("\n")[0].strip()
            if first_line.startswith("@"):
                resolved = resolve_reference(
                    first_line, target_path if target_path.is_file() else base_dir,
                    lang_root, depth + 1, _visited
                )
                if resolved:
                    remaining = "\n".join(content.split("\n")[1:]).strip()
                    if remaining:
                        return resolved + "\n" + remaining
                    return resolved
        return content
    elif section_name is None:
        # Return entire file content (all sections joined)
        all_content = []
        for sec_lines in sections.values():
            all_content.extend(sec_lines)
        return "\n".join(all_content).strip()

    log.debug(f"Section '{section_name}' not found in {target_path}")
    stats["unresolved_refs"].append(ref_string)
    return None


def resolve_section_content(lines: list, file_path: Path, lang_root: Path,
                            all_sections: dict, _depth: int = 0,
                            current_section_name: str = None) -> str:
    """
    Resolve a section's content, handling @-references and inline references.
    current_section_name is used when a bare @Path reference (no :Section) is encountered,
    so we know to pull the same-named section from the target file.
    """
    if _depth > MAX_REF_DEPTH:
        return "\n".join(lines).strip()

    result_lines = []

    for line in lines:
        stripped = line.strip()

        # Skip rubrical conditionals for non-1960 rites
        if stripped.startswith("(") and "rubrica" in stripped.lower():
            # We'll handle these in apply_rubric_filter
            result_lines.append(line)
            continue

        # Handle @-references (a line that starts with @)
        if stripped.startswith("@"):
            # Could be @Path:Section or @:LocalSection
            if stripped.startswith("@:"):
                # Self-reference to another section in same file
                local_section = stripped[2:]
                if local_section in all_sections:
                    # Recursively resolve with depth guard
                    resolved = resolve_section_content(
                        all_sections[local_section], file_path, lang_root,
                        all_sections, _depth + 1, local_section
                    )
                    if resolved:
                        result_lines.append(resolved)
                    else:
                        result_lines.append("\n".join(all_sections[local_section]).strip())
                else:
                    stats["unresolved_refs"].append(stripped)
            else:
                # If no section specified and we know our current section, append it
                ref_str = stripped
                if ":" not in stripped[1:] and current_section_name:
                    ref_str = stripped + ":" + current_section_name

                resolved = resolve_reference(ref_str, file_path, lang_root)
                if resolved:
                    result_lines.append(resolved)
                else:
                    # Try without the appended section name as fallback
                    if ref_str != stripped:
                        resolved = resolve_reference(stripped, file_path, lang_root)
                        if resolved:
                            result_lines.append(resolved)
        else:
            result_lines.append(line)

    return "\n".join(result_lines).strip()


def expand_macros(text: str, english: bool = False) -> str:
    """Expands $Per/$Qui/&Gloria etc. macros in text."""
    if not text:
        return text

    macro_dict = MACROS_ENG if english else MACROS

    lines = text.split("\n")
    result = []

    for line in lines:
        stripped = line.strip()
        # Check if the entire line is a macro
        if stripped in macro_dict:
            result.append(macro_dict[stripped])
        else:
            # Check for inline macros (less common)
            for macro, expansion in macro_dict.items():
                if macro in stripped:
                    stripped = stripped.replace(macro, expansion)
            result.append(stripped if stripped != line.strip() else line)

    return "\n".join(result)


def apply_rubric_filter(text: str, rite: str = "1960") -> str:
    """
    Filter text based on rubrical conditionals.
    Keep content for the 1960 rite (default).
    Remove content marked for other rites only.
    """
    if not text:
        return text

    lines = text.split("\n")
    result = []
    skip_until_next = False
    in_1960_block = False

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Check for rubrica markers
        rubrica_match = re.match(r"^\((?:sed\s+)?rubrica\s+(\w+)(?:\s+.*)?\)", stripped, re.IGNORECASE)
        if rubrica_match:
            rubric_code = rubrica_match.group(1).lower()

            if rubric_code in ("1960", "196", "innovata"):
                # This is for 1960/1962 - include following content
                skip_until_next = False
                in_1960_block = True
            elif rubric_code in ("1955",):
                # 1955 form - skip for 1960 import
                skip_until_next = True
                in_1960_block = False
            elif rubric_code in ("1570", "tridentina", "divino"):
                # Pre-1955 form - skip for 1960 import
                skip_until_next = True
                in_1960_block = False
            else:
                # Unknown rubric, skip
                skip_until_next = True
                in_1960_block = False

            i += 1
            continue

        # Check for "(deinde dicuntur semper)" - always include what follows
        if "deinde dicuntur semper" in stripped.lower():
            skip_until_next = False
            i += 1
            continue

        # Check for conditional end markers
        if stripped.startswith("(") and stripped.endswith(")") and "omittuntur" in stripped.lower():
            # "(sed rubrica 196 omittuntur)" means omit in 1960
            if "196" in stripped:
                skip_until_next = True
            i += 1
            continue

        if not skip_until_next:
            result.append(line)

        i += 1

    return "\n".join(result)


def strip_markup(text: str) -> str:
    """Removes DO-specific markers while preserving liturgical symbols."""
    if not text:
        return text

    lines = text.split("\n")
    result = []

    for line in lines:
        # Remove v. / V. prefixes at start of line (verse markers)
        line = re.sub(r"^v\.\s*", "", line)

        # Remove {:H-NAME:} hymn markers
        line = re.sub(r"\{:.*?:\}", "", line)

        # Remove &t-rubric; tokens
        line = re.sub(r"&t-[a-zA-Z]+;", "", line)

        # Remove r. response markers (but keep the liturgical symbols)
        line = re.sub(r"^r\.\s*", "", line)

        # Remove _ separator lines
        if line.strip() == "_":
            continue

        # Remove lines that are purely formatting directives
        if line.strip().startswith("&") and line.strip() not in MACROS:
            # Unknown macro/directive - skip if it looks like a directive
            if re.match(r"^&[a-zA-Z_]+\d*$", line.strip()):
                continue

        # Clean up multiple spaces
        line = re.sub(r"  +", " ", line)

        result.append(line)

    return "\n".join(result).strip()


def extract_reference(lines: list) -> Optional[str]:
    """Extract scripture reference from lines starting with !"""
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("!"):
            ref = stripped[1:].strip()
            # Only take it if it looks like a scripture reference
            if re.match(r"^[A-Z0-9]", ref) and not ref.startswith("Tractus"):
                # Clean up the reference (remove trailing period)
                ref = ref.rstrip(".")
                return ref
    return None


def extract_rank(sections: dict) -> Optional[int]:
    """Extract numeric rank from [Rank] section."""
    if "Rank" not in sections:
        return None

    rank_text = "\n".join(sections["Rank"]).strip()
    # Format: ";;Semiduplex;;6.9" or "Name;;Class;;Rank;;..."
    parts = rank_text.split(";;")
    for part in parts:
        part = part.strip()
        try:
            val = float(part)
            if 1 <= val <= 7:
                return int(val)
        except ValueError:
            continue
    return None


def parse_rule_section(sections: dict) -> dict:
    """Parse [Rule] section for Gloria, Credo, Preface."""
    rule = {}
    if "Rule" not in sections:
        return rule

    rule_text = "\n".join(sections["Rule"]).strip()

    # Gloria
    if re.search(r"\bno\s+Gloria\b", rule_text, re.IGNORECASE):
        rule["gloria"] = False
    elif re.search(r"\bGloria\b", rule_text):
        rule["gloria"] = True

    # Credo
    if re.search(r"\bno\s+Credo\b", rule_text, re.IGNORECASE):
        rule["credo"] = False
    elif re.search(r"\bCredo\b", rule_text):
        rule["credo"] = True

    # Preface
    pref_match = re.search(r"Prefatio=(\w+)", rule_text)
    if not pref_match:
        pref_match = re.search(r"Pref(?:atio|ace)=(\w+)", rule_text, re.IGNORECASE)
    if pref_match:
        rule["preface"] = pref_match.group(1)

    return rule


def process_section_text(lines: list, file_path: Path, lang_root: Path,
                         all_sections: dict, english: bool = False,
                         section_name: str = None) -> str:
    """Full processing pipeline for a section's content."""
    # 1. Resolve references
    content = resolve_section_content(lines, file_path, lang_root, all_sections,
                                      current_section_name=section_name)

    # 2. Apply rubric filter
    content = apply_rubric_filter(content)

    # 3. Expand macros
    content = expand_macros(content, english=english)

    # 4. Strip markup
    content = strip_markup(content)

    # 5. Clean up
    # Remove lines that are purely reference markers (!) unless they're the only content
    content_lines = content.split("\n")
    text_lines = [l for l in content_lines if not l.strip().startswith("!")]
    if text_lines:
        content = "\n".join(text_lines).strip()
    else:
        content = "\n".join(content_lines).strip()

    return content


def process_mass_file(lat_path: Path, eng_path: Optional[Path]) -> Optional[dict]:
    """Process a single Mass file pair (Latin + English) into our JSON format."""
    lat_sections = parse_do_file(lat_path)
    eng_sections = parse_do_file(eng_path) if eng_path and eng_path.exists() else {}

    if not lat_sections:
        return None

    entry = {}

    # Officium (title)
    if "Officium" in lat_sections:
        officium_text = "\n".join(lat_sections["Officium"]).strip()
        if officium_text:
            entry["officium"] = officium_text
    elif "Rank" in lat_sections:
        # Fallback: extract name from Rank line (format: "Name;;Class;;rank;;")
        rank_text = "\n".join(lat_sections["Rank"]).strip()
        rank_parts = rank_text.split(";;")
        if rank_parts and rank_parts[0].strip():
            entry["officium"] = rank_parts[0].strip()

    # Rank
    rank = extract_rank(lat_sections)
    if rank is not None:
        entry["rank"] = rank

    # Rule (Gloria, Credo, Preface)
    rule = parse_rule_section(lat_sections)
    if rule:
        entry["rule"] = rule

    # Process each Mass section
    for do_section, json_field in MASS_SECTION_MAP.items():
        if do_section not in lat_sections:
            continue

        lat_lines = lat_sections[do_section]

        # Extract scripture reference
        ref = extract_reference(lat_lines)

        # Process Latin text
        lat_text = process_section_text(
            lat_lines, lat_path, DO_MISSA_LATIN, lat_sections, english=False,
            section_name=do_section
        )

        # Process English text
        eng_text = ""
        if do_section in eng_sections:
            eng_text = process_section_text(
                eng_sections[do_section], eng_path, DO_MISSA_ENGLISH, eng_sections,
                english=True, section_name=do_section
            )

        if lat_text or eng_text:
            field_data = {}
            if lat_text:
                field_data["lat"] = lat_text
            field_data["eng"] = eng_text if eng_text else ""
            if ref:
                field_data["ref"] = ref
            entry[json_field] = field_data

    return entry if entry else None


def slug_from_filename(filename: str) -> str:
    """Convert DO filename to our JSON slug format."""
    # Remove .txt extension
    slug = filename.replace(".txt", "")
    # Lowercase
    slug = slug.lower()
    return slug


def is_variant_file(filename: str) -> bool:
    """Check if a file is a variant (old rite, etc.) that we should skip for main import."""
    base = filename.replace(".txt", "")
    # Files ending in 'o' are old-rite variants (pre-1955)
    # Files ending in 'n' are newer variants
    # Files ending in 'r' are reformed variants
    # Files with 'm1', 'm2', 'm3' are multiple masses (Christmas etc.)
    # Files with 't' suffix are vigils

    # We import 'o' files as separate entries only if substantially different
    # For now, skip variant files in main import
    if re.match(r".*[A-Za-z]\d+-\d+o$", base):
        return True  # old-rite office variant

    return False


def import_mass_tempora(dry_run: bool = False) -> dict:
    """Walk missa/Latin/Tempora/ and import each file."""
    tempora_dir = DO_MISSA_LATIN / "Tempora"
    entries = {}

    if not tempora_dir.exists():
        log.error(f"Tempora directory not found: {tempora_dir}")
        return entries

    for filename in sorted(os.listdir(tempora_dir)):
        if not filename.endswith(".txt"):
            continue

        slug = slug_from_filename(filename)

        # Skip old-rite variant files (ending in 'o')
        if slug.endswith("o") and re.match(r".*\d+-\d+o$", slug):
            continue

        lat_path = tempora_dir / filename

        # Find English equivalent
        eng_filename = filename  # Same name structure
        eng_path = DO_MISSA_ENGLISH / "Tempora" / eng_filename

        entry = process_mass_file(lat_path, eng_path)
        if entry:
            entries[slug] = entry

    if not dry_run:
        log.info(f"Mass Tempora: processed {len(entries)} entries")

    return entries


def import_mass_sanctoral(dry_run: bool = False) -> dict:
    """Walk missa/Latin/Sancti/ and import each file."""
    sancti_dir = DO_MISSA_LATIN / "Sancti"
    entries = {}

    if not sancti_dir.exists():
        log.error(f"Sancti directory not found: {sancti_dir}")
        return entries

    for filename in sorted(os.listdir(sancti_dir)):
        if not filename.endswith(".txt"):
            continue

        slug = slug_from_filename(filename)

        lat_path = sancti_dir / filename

        # Find English equivalent
        eng_path = DO_MISSA_ENGLISH / "Sancti" / filename

        entry = process_mass_file(lat_path, eng_path)
        if entry:
            entries[slug] = entry

    if not dry_run:
        log.info(f"Mass Sanctoral: processed {len(entries)} entries")

    return entries


def import_office_tempora(dry_run: bool = False) -> dict:
    """Walk horas/Latin/Tempora/ and import each file."""
    tempora_dir = DO_HORAS_LATIN / "Tempora"
    entries = {}

    if not tempora_dir.exists():
        log.error(f"Office Tempora directory not found: {tempora_dir}")
        return entries

    for filename in sorted(os.listdir(tempora_dir)):
        if not filename.endswith(".txt"):
            continue

        slug = slug_from_filename(filename)

        lat_path = tempora_dir / filename
        eng_path = DO_HORAS_ENGLISH / "Tempora" / filename

        lat_sections = parse_do_file(lat_path)
        eng_sections = parse_do_file(eng_path) if eng_path.exists() else {}

        if not lat_sections:
            continue

        entry = {}

        # Officium (title)
        if "Officium" in lat_sections:
            entry["officium"] = "\n".join(lat_sections["Officium"]).strip()

        # Rank
        rank = extract_rank(lat_sections)
        if rank is not None:
            entry["rank"] = rank

        skip_sections = {"Officium", "Rank", "Rule", "Name"}
        for sec_name in lat_sections:
            if sec_name in skip_sections:
                continue
            if True:
                lat_text = process_section_text(
                    lat_sections[sec_name], lat_path, DO_HORAS_LATIN, lat_sections,
                    english=False, section_name=sec_name
                )
                eng_text = ""
                if sec_name in eng_sections:
                    eng_text = process_section_text(
                        eng_sections[sec_name], eng_path, DO_HORAS_ENGLISH, eng_sections,
                        english=True, section_name=sec_name
                    )

                field_key = sec_name.lower().replace(" ", "_")
                if lat_text:
                    entry[field_key] = {"lat": lat_text}
                    if eng_text:
                        entry[field_key]["eng"] = eng_text

        if entry:
            entries[slug] = entry

    if not dry_run:
        log.info(f"Office Tempora: processed {len(entries)} entries")

    return entries


def import_office_sanctoral(dry_run: bool = False) -> dict:
    """Walk horas/Latin/Sancti/ and import each file."""
    sancti_dir = DO_HORAS_LATIN / "Sancti"
    entries = {}

    if not sancti_dir.exists():
        log.error(f"Office Sancti directory not found: {sancti_dir}")
        return entries

    for filename in sorted(os.listdir(sancti_dir)):
        if not filename.endswith(".txt"):
            continue

        slug = slug_from_filename(filename)

        lat_path = sancti_dir / filename
        eng_path = DO_HORAS_ENGLISH / "Sancti" / filename

        lat_sections = parse_do_file(lat_path)
        eng_sections = parse_do_file(eng_path) if eng_path.exists() else {}

        if not lat_sections:
            continue

        entry = {}

        if "Officium" in lat_sections:
            entry["officium"] = "\n".join(lat_sections["Officium"]).strip()

        rank = extract_rank(lat_sections)
        if rank is not None:
            entry["rank"] = rank

        skip_sections = {"Officium", "Rank", "Rule", "Name"}
        for sec_name in lat_sections:
            if sec_name in skip_sections:
                continue
            if True:
                lat_text = process_section_text(
                    lat_sections[sec_name], lat_path, DO_HORAS_LATIN, lat_sections,
                    english=False, section_name=sec_name
                )
                eng_text = ""
                if sec_name in eng_sections:
                    eng_text = process_section_text(
                        eng_sections[sec_name], eng_path, DO_HORAS_ENGLISH, eng_sections,
                        english=True, section_name=sec_name
                    )

                field_key = sec_name.lower().replace(" ", "_")
                if lat_text:
                    entry[field_key] = {"lat": lat_text}
                    if eng_text:
                        entry[field_key]["eng"] = eng_text

        if entry:
            entries[slug] = entry

    if not dry_run:
        log.info(f"Office Sanctoral: processed {len(entries)} entries")

    return entries


def import_psalter() -> dict:
    """Import all 150 psalms + canticles from DO Psalterium, verse-by-verse."""
    psalmorum_lat = DO_HORAS_LATIN / "Psalterium" / "Psalmorum"
    psalmorum_eng = DO_HORAS_ENGLISH / "Psalterium" / "Psalmorum"
    psalter = {}

    if not psalmorum_lat.exists():
        log.error(f"Psalterium not found: {psalmorum_lat}")
        return psalter

    for fn in sorted(os.listdir(psalmorum_lat)):
        if not fn.endswith(".txt"):
            continue
        m = re.match(r'Psalm(\d+)\.txt', fn)
        if not m:
            # Canticles or special files
            key = fn.replace('.txt', '').lower()
        else:
            key = f"psalm{m.group(1)}"

        lat_path = psalmorum_lat / fn
        eng_path = psalmorum_eng / fn

        try:
            with open(lat_path, encoding='utf-8', errors='replace') as f:
                lat_lines = [l.rstrip() for l in f if l.strip() and not l.startswith('#') and not l.startswith('[')]
        except Exception:
            continue

        eng_lines = []
        if eng_path.exists():
            try:
                with open(eng_path, encoding='utf-8', errors='replace') as f:
                    eng_lines = [l.rstrip() for l in f if l.strip() and not l.startswith('#') and not l.startswith('[')]
            except Exception:
                pass

        # Clean verse lines
        lat_verses = [strip_markup(l) for l in lat_lines if l.strip()]
        eng_verses = [strip_markup(l) for l in eng_lines if l.strip()]

        if lat_verses:
            entry = {"lat": lat_verses}
            if eng_verses:
                entry["eng"] = eng_verses
            psalter[key] = entry

    log.info(f"Psalter: imported {len(psalter)} psalms/canticles")
    return psalter


def is_field_populated(value) -> bool:
    """Check if a field value is populated (non-null, non-empty)."""
    if value is None:
        return False
    if value == "":
        return False
    if value == {}:
        return False
    if value == []:
        return False
    if isinstance(value, dict):
        # A dict field is populated if it has at least one non-empty value
        return any(is_field_populated(v) for v in value.values())
    return True


def merge_field(existing_value, new_value):
    """
    Merge a new value into an existing value, respecting the dedup rule:
    - Only fill fields that are currently null, empty, or missing.
    - Never overwrite populated fields.
    """
    if not is_field_populated(existing_value):
        return new_value

    if isinstance(existing_value, dict) and isinstance(new_value, dict):
        merged = dict(existing_value)
        for key, val in new_value.items():
            if key not in merged or not is_field_populated(merged[key]):
                if is_field_populated(val):
                    merged[key] = val
        return merged

    # Existing is populated and not a dict - keep it
    return existing_value


def merge_into_json(target_path: Path, new_entries: dict, dry_run: bool = False) -> tuple:
    """
    Load existing JSON, merge new entries (field-level, not entry-level), write back.
    Returns (created_count, updated_count, skipped_count).
    """
    created = 0
    updated = 0
    skipped = 0

    # Load existing data
    existing_data = {}
    if target_path.exists():
        try:
            with open(target_path, "r", encoding="utf-8") as f:
                existing_data = json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            log.warning(f"Error reading {target_path}: {e}")
            existing_data = {}

    for slug, new_entry in new_entries.items():
        if slug not in existing_data:
            # New entry - create it
            existing_data[slug] = new_entry
            created += 1
        else:
            # Existing entry - merge at field level
            existing_entry = existing_data[slug]
            any_update = False

            for field, new_value in new_entry.items():
                if field not in existing_entry:
                    # Field doesn't exist - add it
                    if is_field_populated(new_value):
                        existing_entry[field] = new_value
                        any_update = True
                elif not is_field_populated(existing_entry[field]):
                    # Field exists but is empty/null - fill it
                    if is_field_populated(new_value):
                        existing_entry[field] = new_value
                        any_update = True
                elif isinstance(existing_entry[field], dict) and isinstance(new_value, dict):
                    # Both are dicts - merge at sub-field level
                    merged = merge_field(existing_entry[field], new_value)
                    if merged != existing_entry[field]:
                        existing_entry[field] = merged
                        any_update = True

            if any_update:
                existing_data[slug] = existing_entry
                updated += 1
            else:
                skipped += 1

    if not dry_run:
        # Write back
        with open(target_path, "w", encoding="utf-8") as f:
            json.dump(existing_data, f, ensure_ascii=False, indent=2)
            f.write("\n")

    return created, updated, skipped


def sync_to_android():
    """Copy each iOS resource to its Android mirror."""
    if not ANDROID_ASSETS.exists():
        log.warning(f"Android assets directory not found: {ANDROID_ASSETS}")
        return

    for f in TARGET_FILES:
        src = RESOURCES_DIR / f
        dst = ANDROID_ASSETS / f
        if src.exists():
            shutil.copy2(str(src), str(dst))
            log.info(f"Synced {f} to Android assets")


def main():
    parser = argparse.ArgumentParser(description="Import DivinumOfficium corpus into Introibo JSON")
    parser.add_argument("--dry-run", action="store_true", help="Show what would change without writing")
    parser.add_argument("--mass-only", action="store_true", help="Only import Mass data")
    parser.add_argument("--office-only", action="store_true", help="Only import Office data")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose logging")
    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Validate DO corpus exists
    if not DO_ROOT.exists():
        log.error(f"DivinumOfficium corpus not found at {DO_ROOT}")
        sys.exit(1)

    total_created = 0
    total_updated = 0
    total_skipped = 0

    do_mass = not args.office_only
    do_office = not args.mass_only

    # ─── Mass Import ──────────────────────────────────────────────────────────
    if do_mass:
        print("=" * 60)
        print("IMPORTING MASS DATA")
        print("=" * 60)

        # Mass Tempora
        print("\n--- Mass Tempora ---")
        tempora_entries = import_mass_tempora(dry_run=args.dry_run)
        target = RESOURCES_DIR / "missal_tempora.json"
        c, u, s = merge_into_json(target, tempora_entries, dry_run=args.dry_run)
        total_created += c
        total_updated += u
        total_skipped += s
        print(f"  Created: {c}, Updated: {u}, Skipped: {s}")

        # Mass Sanctoral
        print("\n--- Mass Sanctoral ---")
        sanctoral_entries = import_mass_sanctoral(dry_run=args.dry_run)
        target = RESOURCES_DIR / "missal_sanctoral.json"
        c, u, s = merge_into_json(target, sanctoral_entries, dry_run=args.dry_run)
        total_created += c
        total_updated += u
        total_skipped += s
        print(f"  Created: {c}, Updated: {u}, Skipped: {s}")

    # ─── Office Import ────────────────────────────────────────────────────────
    if do_office:
        print("\n" + "=" * 60)
        print("IMPORTING OFFICE DATA")
        print("=" * 60)

        # Office Tempora
        print("\n--- Office Tempora ---")
        office_temp_entries = import_office_tempora(dry_run=args.dry_run)
        target = RESOURCES_DIR / "temporal_propers.json"
        c, u, s = merge_into_json(target, office_temp_entries, dry_run=args.dry_run)
        total_created += c
        total_updated += u
        total_skipped += s
        print(f"  Created: {c}, Updated: {u}, Skipped: {s}")

        # Office Sanctoral
        print("\n--- Office Sanctoral ---")
        office_sanct_entries = import_office_sanctoral(dry_run=args.dry_run)
        target = RESOURCES_DIR / "sanctoral_propers.json"
        c, u, s = merge_into_json(target, office_sanct_entries, dry_run=args.dry_run)
        total_created += c
        total_updated += u
        total_skipped += s
        print(f"  Created: {c}, Updated: {u}, Skipped: {s}")

    # ─── Psalter Import ────────────────────────────────────────────────────────
    if do_office:
        print("\n--- Psalter ---")
        psalter_data = import_psalter()
        psalter_path = RESOURCES_DIR / "psalter.json"
        with open(psalter_path, 'w', encoding='utf-8') as f:
            json.dump(psalter_data, f, ensure_ascii=False, indent=2)
        print(f"  Psalter: {len(psalter_data)} psalms/canticles written")

    # ─── Summary ─────────────────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("IMPORT SUMMARY")
    print("=" * 60)
    print(f"  Entries created (new):           {total_created}")
    print(f"  Entries updated (fields filled):  {total_updated}")
    print(f"  Entries skipped (already full):   {total_skipped}")

    # Deduplicate unresolved refs
    unresolved = list(set(stats["unresolved_refs"]))
    if unresolved:
        print(f"\n  Unresolved references: {len(unresolved)}")
        if len(unresolved) <= 20:
            for ref in sorted(unresolved):
                print(f"    - {ref}")
        else:
            for ref in sorted(unresolved)[:20]:
                print(f"    - {ref}")
            print(f"    ... and {len(unresolved) - 20} more")

    if args.dry_run:
        print("\n  [DRY RUN - no files were modified]")
    else:
        # Sync to Android
        print("\n--- Syncing to Android assets ---")
        sync_to_android()
        print("\nDone!")


if __name__ == "__main__":
    main()
