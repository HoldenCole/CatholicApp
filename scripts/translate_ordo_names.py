#!/usr/bin/env python3
"""Generate English translations for the Latin ordo day names.

Reads Introibo/Resources/ordo.json, translates every DISTINCT `name` value to
English, and writes ordo_names_en.json (iOS Resources + Android assets) as a
flat { latin_name: english_name } map. Names the translator cannot confidently
handle are OMITTED (the UI falls back to the Latin), so we never display a
garbled translation.

Run:  python3 scripts/translate_ordo_names.py [--show-missed] [--show-sample]
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ORDO = ROOT / "Introibo" / "Resources" / "ordo.json"
OUT_IOS = ROOT / "Introibo" / "Resources" / "ordo_names_en.json"
OUT_ANDROID = ROOT / "android" / "app" / "src" / "main" / "assets" / "ordo_names_en.json"

# ---------------------------------------------------------------------------
# Ordinals
# ---------------------------------------------------------------------------

ORD = {}
for i, w in enumerate(
    ["1st","2nd","3rd","4th","5th","6th","7th","8th","9th","10th","11th","12th",
     "13th","14th","15th","16th","17th","18th","19th","20th","21st","22nd","23rd",
     "24th","25th","26th","27th"], start=1):
    ORD[str(i)] = w
for rom, n in {
    "I":1,"II":2,"III":3,"IV":4,"V":5,"VI":6,"VII":7,"VIII":8,"IX":9,"X":10,
    "XI":11,"XII":12,"XIII":13,"XIV":14,"XV":15,"XVI":16,"XVII":17,"XVIII":18,
    "XIX":19,"XX":20,"XXI":21,"XXII":22,"XXIII":23,"XXIV":24,"XXV":25,"XXVI":26,
    "XXVII":27}.items():
    ORD[rom] = ORD[str(n)]

CARDINAL = {  # for "Die <X> Januarii"
    "Sexta":6, "Septima":7, "Octava":8, "Nona":9, "Decima":10,
    "Undecima":11, "Duodecima":12,
}

# feria word/numeral -> English weekday
FERIA = {
    "prima":"Sunday","secunda":"Monday","tertia":"Tuesday","quarta":"Wednesday",
    "quinta":"Thursday","sexta":"Friday","septima":"Saturday",
    "i":"Sunday","ii":"Monday","iii":"Tuesday","iv":"Wednesday","v":"Thursday",
    "vi":"Friday","vii":"Saturday",
}

# ---------------------------------------------------------------------------
# Whole-name overrides (feasts, mysteries, vigils, multi-saint, irregular)
# ---------------------------------------------------------------------------

OVERRIDES = {
    # Temporal solemnities / special days
    "In Nativitate Domini": "The Nativity of Our Lord",
    "In Epiphania Domini": "The Epiphany",
    "In Ascensione Domini": "The Ascension",
    "Dominica Resurrectionis": "Easter Sunday",
    "Dominica Pentecostes": "Pentecost Sunday",
    "Dominica in Palmis": "Palm Sunday",
    "Dominica Sanctissimæ Trinitatis": "Trinity Sunday",
    "Dominica Infra Octavam Nativitatis": "Sunday within the Octave of the Nativity",
    "Dominica infra Octavam Nativitatis": "Sunday within the Octave of the Nativity",
    "Dominica in Albis in Octava Paschæ": "Low Sunday",
    "Dominica in Albis": "Low Sunday",
    "Dominica post Ascensionem": "Sunday after the Ascension",
    "Dominica in Septuagesima": "Septuagesima Sunday",
    "Dominica in Sexagesima": "Sexagesima Sunday",
    "Dominica in Quinquagesima": "Quinquagesima Sunday",
    "Sabbato Sancto": "Holy Saturday",
    "Feria IV Cinerum": "Ash Wednesday",
    "Feria Quarta Cinerum": "Ash Wednesday",
    "Feria Quinta in Cena Domini": "Maundy Thursday",
    "Sabbato in Albis": "Saturday within the Octave of Easter",
    "Sabbato in Vigilia Pentecostes": "The Vigil of Pentecost",
    "Die Octavæ Nativitatis Domini": "The Octave Day of the Nativity",
    "Die Sexta infra Octavam Nativitatis": "Sixth Day within the Octave of the Nativity",
    "Commemoratio Baptismatis Domini Nostri Jesu Christi": "The Commemoration of the Baptism of Our Lord",

    # Feasts of Our Lord
    "In Transfiguratione Domini Nostri Jesu Christi": "The Transfiguration",
    "In Exaltatione Sanctæ Crucis": "The Exaltation of the Holy Cross",
    "In Festo Domini Nostri Jesu Christi Regis": "Christ the King",
    "Festum Sanctissimi Corporis Christi": "Corpus Christi",
    "Sacratissimi Cordis Domini Nostri Jesu Christi": "The Most Sacred Heart of Jesus",
    "Pretiosissimi Sanguinis Domini Nostri Jesu Christi": "The Most Precious Blood",
    "Sanctæ Familiæ Jesu Mariæ Joseph": "The Holy Family",
    "In Festo Sanctæ Familiæ Jesu Mariæ Joseph": "The Holy Family",

    # Feasts of Our Lady
    "In Annuntiatione Beatæ Mariæ Virginis": "The Annunciation",
    "In Annuntiatione Beatissimæ Mariæ Virginis": "The Annunciation",
    "In Assumptione Beatæ Mariæ Virginis": "The Assumption",
    "In Conceptione Immaculata BMV": "The Immaculate Conception",
    "In Conceptione Immaculata Beatæ Mariæ Virginis": "The Immaculate Conception",
    "In Nativitate Beatæ Mariæ Virginis": "The Nativity of the Blessed Virgin Mary",
    "In Purificatione Beatæ Mariæ Virginis": "The Purification (Candlemas)",
    "In Præsentatione Beatæ Mariæ Virginis": "The Presentation of the Blessed Virgin Mary",
    "In Visitatione Beatæ Mariæ Virginis": "The Visitation",
    "In Apparitione Beatæ Mariæ Virginis Immaculatæ": "Our Lady of Lourdes",
    "Maternitatis Beatæ Mariæ Virginis": "The Maternity of the Blessed Virgin Mary",
    "Immaculati Cordis Beatæ Mariæ Virginis": "The Immaculate Heart of Mary",
    "Septem Dolorum Beatæ Mariæ Virginis": "The Seven Sorrows of the Blessed Virgin Mary",
    "Beatæ Mariæ Virginis Reginæ": "The Queenship of the Blessed Virgin Mary",
    "Beatæ Mariæ Virginis a Rosario": "Our Lady of the Rosary",
    "Beatæ Mariæ Virginis de Mercede": "Our Lady of Ransom",
    "Beatæ Mariæ Virginis de Monte Carmelo": "Our Lady of Mount Carmel",
    "Sanctæ Mariæ Virginis ad Nives": "Our Lady of the Snows",
    "S. Nominis Beatæ Mariæ Virginis": "The Most Holy Name of Mary",

    # Apostles / John the Baptist / dedications / chairs
    "In Nativitate S. Joannis Baptistæ": "The Nativity of St. John the Baptist",
    "In Decollatione S. Joannis Baptistæ": "The Beheading of St. John the Baptist",
    "In Conversione S. Pauli Apostoli": "The Conversion of St. Paul",
    "In Commemoratione S. Pauli Apostoli": "The Commemoration of St. Paul",
    "In Commemoratione Omnium Fidelium Defunctorum": "All Souls",
    "Omnium Sanctorum": "All Saints",
    "In Dedicatione S. Michaëlis Archangelis": "The Dedication of St. Michael (Michaelmas)",
    "In Dedicatione Archibasilicæ Ss. Salvatoris": "The Dedication of the Archbasilica of the Holy Saviour",
    "In Dedicatione Basilicarum Ss. Apostolorum Petri et Pauli": "The Dedication of the Basilicas of Sts. Peter & Paul",
    "In Cathedra S. Petri Apostoli Antiochiæ": "The Chair of St. Peter at Antioch",
    "Cathedræ S. Petri Romæ": "The Chair of St. Peter at Rome",
    "Impressionis Stigmatum S. Francisci": "The Stigmata of St. Francis",
    "S. Petri ad Vincula": "St. Peter in Chains",
    "S. Joannis Apostoli ante Portam Latinam": "St. John before the Latin Gate",
    "S. Annæ Matris B.M.V.": "St. Anne, Mother of the Blessed Virgin Mary",
    "S. Joachim Confessoris, Patris B. M. V.": "St. Joachim, Father of the Blessed Virgin Mary",
    "S. Joseph Sponsi B.M.V. Confessoris": "St. Joseph, Spouse of the Blessed Virgin Mary",
    "S. Josephi Opificis Sponsi BMV Confessoris": "St. Joseph the Worker",

    # Vigils
    "In Vigilia Nativitatis Domini": "Christmas Eve",
    "In Vigilia Epiphaniæ": "The Vigil of the Epiphany",
    "In Vigilia Ascensionis": "The Vigil of the Ascension",
    "In Vigilia Assumptionis B.M.V.": "The Vigil of the Assumption",
    "In Vigilia Omnium Sanctorum": "The Vigil of All Saints",
    "In Vigilia S. Joannis Baptistæ": "The Vigil of St. John the Baptist",
    "In Vigilia Ss. Petri et Pauli Apostolorum": "The Vigil of Sts. Peter & Paul",

    # Angels / innocents
    "Ss. Angelorum Custodum": "The Holy Guardian Angels",
    "Ss. Innocentium": "The Holy Innocents",

    # Multi-saint feasts
    "SS. Apostolorum Petri et Pauli": "Sts. Peter & Paul, Apostles",
    "Ss. Simonis et Judæ Apostolorum": "Sts. Simon & Jude, Apostles",
    "Ss. Philippi et Jacobi Apostolorum (transl.)": "Sts. Philip & James, Apostles",
    "Ss. Cyrilli et Methodii Pont. et Conf.": "Sts. Cyril & Methodius",
    "Ss. Cosmæ et Damiani Martyrum": "Sts. Cosmas & Damian, Martyrs",
    "Ss. Chrysanthi et Dariæ Martyrum": "Sts. Chrysanthus & Daria, Martyrs",
    "Ss. Cornelii Papæ et Cypriani Episcopi, Martyrum": "Sts. Cornelius & Cyprian, Martyrs",
    "Ss. Cypriani et Justinæ Virginis, Martyrum": "Sts. Cyprian & Justina, Martyrs",
    "Ss. Cyriaci, Largi et Smaragdi Martyrum": "Sts. Cyriacus, Largus & Smaragdus, Martyrs",
    "Ss. Eustachii et Sociorum Martyrum": "Sts. Eustace & Companions, Martyrs",
    "Ss. Fabiani et Sebastiani Martyrum": "Sts. Fabian & Sebastian, Martyrs",
    "Ss. Hippolyti et Cassiani Martyrum": "Sts. Hippolytus & Cassian, Martyrs",
    "Ss. Joannis et Pauli Martyrum": "Sts. John & Paul, Martyrs",
    "Ss. Marcellini, Petri, atque Erasmi, Episcopi, Martyrum": "Sts. Marcellinus, Peter & Erasmus, Martyrs",
    "Ss. Marii, Marthæ, Audifacis, et Abachum Martyrum": "Sts. Marius, Martha, Audifax & Abachum, Martyrs",
    "Ss. Nazarii et Celsi Martyrum, Victoris I Papæ et Martyris ac Innocentii I Papæ et Confessoris": "Sts. Nazarius & Celsus, Martyrs",
    "Ss. Nerei, Achillei et Domitillæ Virg. atque Pancratii Martyrum": "Sts. Nereus, Achilleus, Domitilla & Pancras, Martyrs",
    "Ss. Placidi et Sociorum Martyrum": "Sts. Placid & Companions, Martyrs",
    "Ss. Primi et Feliciani Martyrum": "Sts. Primus & Felician, Martyrs",
    "Ss. Proti et Hyacinthi Martyrum": "Sts. Protus & Hyacinth, Martyrs",
    "Ss. Tiburtii et Susannæ Virginis, Martyrum": "Sts. Tiburtius & Susanna, Martyrs",
    "Ss. Vincentii et Anastasii Martyrum": "Sts. Vincent & Anastasius, Martyrs",
    "Ss. Viti, Modesti atque Crescentiæ Martyrum": "Sts. Vitus, Modestus & Crescentia, Martyrs",
    "Ss. Septem Fratrum Martyrum, ac Rufinæ et Secundæ Virginum et Martyrum": "The Seven Holy Brothers, Martyrs",
    "Ss. Septem Fundatorum Ordinis Servorum B. M. V.": "The Seven Holy Founders of the Servites",
    "SS. Cleti et Marcellini Summorum Pontificum et Martyrum": "Sts. Cletus & Marcellinus, Popes & Martyrs",
    "SS. Soteris et Caii Summorum Pontificum et Martyrum": "Sts. Soter & Caius, Popes & Martyrs",
    "SS. Faustini et Jovitæ": "Sts. Faustinus & Jovita",

    # Irregular single-saint
    "S. Basilii Magni, Episcopis Confessoris et Ecclesiæ Doctoris": "St. Basil the Great, Bishop, Confessor & Doctor of the Church",
    "S. Cyrilli Episc. Alexandrini Confessoris et Ecclesiæ Doctoris": "St. Cyril of Alexandria, Confessor & Doctor of the Church",
    "S. Elisabeth Reg. Portugaliæ Viduæ": "St. Elizabeth of Portugal, Widow",
    "S. Januarii Episcopi et Sociorum Martyrum": "St. Januarius & Companions, Martyrs",
    "S. Ludovici Regis Franciæ Confessoris": "St. Louis, King of France, Confessor",
    "S. Stephani Protomartyris": "St. Stephen, Protomartyr",
    "S. Stephani Hungariæ Regis Confessoris": "St. Stephen of Hungary, King & Confessor",
    "S. Rosæ a Sancta Maria Limanæ Virginis": "St. Rose of Lima, Virgin",
    "S. Hieronymi Presbyteris Confessoris et Ecclesiæ Doctoris": "St. Jerome, Priest, Confessor & Doctor of the Church",
    "Feria infra Hebdomadam Adventus": "Weekday of Advent",

    # Missal-specific variant spellings and titles
    "Dominica infra Octavam Epiphaniæ": "Sunday within the Octave of the Epiphany",
    "Sanctissimi Nominis Jesu": "The Most Holy Name of Jesus",
    "Patrocinii St. Joseph Confessoris Sponsi B.M.V. confessoris": "The Patronage of St. Joseph",
    "Diei II infra Octavam Nativitatis": "2nd Day within the Octave of the Nativity",
    "Diei III infra Octavam Nativitatis": "3rd Day within the Octave of the Nativity",
    "Diei IV infra Octavam Nativitatis": "4th Day within the Octave of the Nativity",
    "Die V infra Octavam Nativitatis": "5th Day within the Octave of the Nativity",
    "Die VI infra Octavam Nativitatis": "6th Day within the Octave of the Nativity",
    "Die VII infra Octavam Nativitatis": "7th Day within the Octave of the Nativity",
    "Die Quinta infra Octavam Nativitatis": "5th Day within the Octave of the Nativity",
    "Die Septima infra Octavam Nativitatis": "7th Day within the Octave of the Nativity",
}

# ---------------------------------------------------------------------------
# Saint name (genitive) -> English nominative
# ---------------------------------------------------------------------------

SAINTS = {
    "Abdon et Sennen":"Abdon & Sennen","Agathæ":"Agatha","Agnetis":"Agnes",
    "Alberti Magni":"Albert the Great","Alexii":"Alexius",
    "Alfonsi Mariæ de Ligorio":"Alphonsus Liguori","Aloisii Gonzagæ":"Aloysius Gonzaga",
    "Ambrosii":"Ambrose","Andreæ Avellini":"Andrew Avellino","Andreæ Corsini":"Andrew Corsini",
    "Andreæ":"Andrew","Angelæ Mericiæ":"Angela Merici","Aniceti":"Anicetus",
    "Anselmi":"Anselm","Antonii Mariæ Zaccaria":"Anthony Mary Zaccaria",
    "Antonii de Padua":"Anthony of Padua","Antonii":"Anthony","Antonini":"Antoninus",
    "Apollinaris":"Apollinaris","Athanasii":"Athanasius","Augustini":"Augustine",
    "Barnabæ":"Barnabas","Bartholomæi":"Bartholomew","Basilii Magni":"Basil the Great",
    "Bedæ Venerabilis":"the Venerable Bede","Bernardini Senensis":"Bernardine of Siena",
    "Bernardi":"Bernard","Bibianæ":"Bibiana","Birgittæ":"Bridget","Blasii":"Blaise",
    "Bonaventuræ":"Bonaventure","Bonifatii":"Boniface","Brunonis":"Bruno",
    "Cajetani":"Cajetan","Callisti":"Callistus","Camilli de Lellis":"Camillus de Lellis",
    "Caroli":"Charles","Casimiri":"Casimir","Catharinæ Senensis":"Catherine of Siena",
    "Catharinæ":"Catherine","Claræ":"Clare","Clementis":"Clement","Cyrilli":"Cyril",
    "Cæciliæ":"Cecilia","Damasi":"Damasus","Didaci":"Didacus","Dominici":"Dominic",
    "Eduardi":"Edward","Elisabeth":"Elizabeth","Ephræm Syri":"Ephrem the Syrian",
    "Eusebii":"Eusebius","Evaristi":"Evaristus","Felicis I":"Felix I",
    "Felicis de Valois":"Felix of Valois","Fidelis de Sigmaringa":"Fidelis of Sigmaringen",
    "Francisci Borgiæ":"Francis Borgia","Francisci Caracciolo":"Francis Caracciolo",
    "Francisci Salesii":"Francis de Sales","Francisci Xaverii":"Francis Xavier",
    "Francisci":"Francis","Gabrielis a Virgine Perdolente":"Gabriel of the Sorrowful Virgin",
    "Georgii":"George","Gertrudis":"Gertrude","Gorgonii":"Gorgonius",
    "Gregorii Nazianzeni":"Gregory Nazianzen","Gregorii Thaumaturgi":"Gregory Thaumaturgus",
    "Gregorii VII":"Gregory VII","Gulielmi":"William","Hedwigis":"Hedwig",
    "Henrici":"Henry","Hermenegildi":"Hermenegild","Hieronymi Æmiliani":"Jerome Emiliani",
    "Hieronymi":"Jerome","Hilarii":"Hilary","Hilarionis":"Hilarion","Hyacinthi":"Hyacinth",
    "Ignatii":"Ignatius","Irenæi":"Irenaeus","Jacobi":"James","Joachim":"Joachim",
    "Joannis Baptistæ de Rossi":"John Baptist de Rossi","Joannis Baptistæ de la Salle":"John Baptist de la Salle",
    "Joannis Bosco":"John Bosco","Joannis Cantii":"John Cantius","Joannis Chrysostomi":"John Chrysostom",
    "Joannis Damasceni":"John Damascene","Joannis Eudes":"John Eudes","Joannis Gualberti":"John Gualbert",
    "Joannis Leonardi":"John Leonardi","Joannis Mariæ Vianney":"John Mary Vianney",
    "Joannis a Cruce":"John of the Cross","Joannis a S. Facundo":"John of St. Facundo",
    "Joannis de Matha":"John of Matha","Joannis":"John",
    "Joannæ Franciscæ Frémiot de Chantal":"Jane Frances de Chantal","Josaphat":"Josaphat",
    "Josephi Calasanctii":"Joseph Calasanctius","Josephi de Cupertino":"Joseph of Cupertino",
    "Josephi":"Joseph","Joseph":"Joseph","Julianæ de Falconeriis":"Juliana Falconieri",
    "Justini":"Justin","Laurentii Justiniani":"Lawrence Justinian","Laurentii":"Lawrence",
    "Leonis I":"Leo I","Leonis":"Leo","Lini":"Linus","Luciæ":"Lucy","Lucæ":"Luke",
    "Ludovici":"Louis","Marcelli":"Marcellus","Marci":"Mark",
    "Margaritæ Mariæ Alacoque":"Margaret Mary Alacoque","Margaritæ":"Margaret",
    "Mariæ Magdalenæ de Pazzis":"Mary Magdalen de' Pazzi","Mariæ Magdalenæ":"Mary Magdalen",
    "Marthæ":"Martha","Martini":"Martin","Martinæ":"Martina","Matthiæ":"Matthias",
    "Matthæi":"Matthew","Monicæ":"Monica","Nicolai de Tolentino":"Nicholas of Tolentino",
    "Nicolai":"Nicholas","Norberti":"Norbert","Pantaleonis":"Pantaleon",
    "Paschalis Baylon":"Paschal Baylon","Pauli Primi Eremitæ":"Paul the First Hermit",
    "Pauli a Cruce":"Paul of the Cross","Paulini":"Paulinus","Petri Canisii":"Peter Canisius",
    "Petri Celestini":"Peter Celestine","Petri Nolasci":"Peter Nolasco",
    "Petri de Alcantara":"Peter of Alcantara","Petri":"Peter","Philippi Benitii":"Philip Benizi",
    "Philippi Neri":"Philip Neri","Pii I":"Pius I","Pii V":"Pius V","Pii X":"Pius X",
    "Polycarpi":"Polycarp","Praxedis":"Praxedes","Raphaëlis":"Raphael",
    "Raymundi Nonnati":"Raymond Nonnatus","Raymundi de Peñafort":"Raymond of Peñafort",
    "Remigii":"Remigius","Roberti Bellarmino":"Robert Bellarmine","Romualdi":"Romuald",
    "Scholasticæ":"Scholastica","Silverii":"Silverius","Silvestri":"Sylvester",
    "Simeonis":"Simeon","Stanislai":"Stanislaus","Teresiæ":"Teresa",
    "Theresiæ a Jesu Infante":"Thérèse of the Child Jesus","Thomæ Cantuariensis":"Thomas of Canterbury",
    "Thomæ de Villanova":"Thomas of Villanova","Thomæ":"Thomas","Timothei":"Timothy",
    "Titi":"Titus","Ubaldi":"Ubald","Valentini":"Valentine","Venantii":"Venantius",
    "Vincentii a Paulo":"Vincent de Paul","Wenceslai":"Wenceslaus","Zephyrini":"Zephyrinus",
    "Ægidii":"Giles",
}

TITLE_PHRASES = [
    ("Episcopi Confessoris et Ecclesiæ Doctoris","Bishop, Confessor & Doctor of the Church"),
    ("Episcopi et Confessoris et Ecclesiæ Doctoris","Bishop, Confessor & Doctor of the Church"),
    ("Episcopi Confessoris Ecclesiæ Doctoris","Bishop, Confessor & Doctor of the Church"),
    ("Papæ Confessoris et Ecclesiæ Doctoris","Pope, Confessor & Doctor of the Church"),
    ("Confessoris et Ecclesiæ Doctoris","Confessor & Doctor of the Church"),
    ("Abbatis et Ecclesiæ Doctoris","Abbot & Doctor of the Church"),
    ("Apostoli et Evangelistæ","Apostle & Evangelist"),
    ("Episcopi et Martyris","Bishop & Martyr"),
    ("Episcopi et Confessoris","Bishop & Confessor"),
    ("Episcopi Confessoris","Bishop & Confessor"),
    ("Papæ et Martyris","Pope & Martyr"),
    ("Papæ et Confessoris","Pope & Confessor"),
    ("Papæ Confessoris","Pope & Confessor"),
    ("Presbyteri et Martyris","Priest & Martyr"),
    ("Regis Confessoris","King & Confessor"),
    ("Reginæ Viduæ","Queen & Widow"),
    ("Imperatoris Confessoris","Emperor & Confessor"),
    ("Ducis et Martyris","Duke & Martyr"),
    ("Virginis et Martyris","Virgin & Martyr"),
    ("Eremitæ et Confessoris","Hermit & Confessor"),
    ("Episcopi","Bishop"),("Confessoris","Confessor"),("Martyris","Martyr"),
    ("Martyrum","Martyrs"),("Virginis","Virgin"),("Virginum","Virgins"),
    ("Papæ","Pope"),("Abbatis","Abbot"),("Apostoli","Apostle"),
    ("Apostolorum","Apostles"),("Evangelistæ","Evangelist"),("Reginæ","Queen"),
    ("Viduæ","Widow"),("Regis","King"),("Presbyteri","Priest"),("Diaconi","Deacon"),
    ("Protomartyris","Protomartyr"),("Pœnitentis","Penitent"),("Archangeli","Archangel"),
]

EMBER_SEASON = {
    "in Adventu":"of Advent","Quadragesimæ":"of Lent",
    "Pentecostes":"of Pentecost","Septembris":"of September",
}

# ---------------------------------------------------------------------------
# Temporal
# ---------------------------------------------------------------------------

def feria_weekday(tok):
    return FERIA.get(tok.lower())

WEEK_TAIL = {
    "Adventus": "of Advent",
    "in Quadragesima": "of Lent",
    "Quadragesimæ": "of Lent",
    "post Octavam Pentecostes": "after Pentecost",
    "post Pentecosten": "after Pentecost",
    "post Epiphaniam": "after Epiphany",
    "post Epiiphaniam": "after Epiphany",
    "post Octavam Epiphaniæ": "after Epiphany",
    "Post Pascha": "after Easter",
    "post Pascha": "after Easter",
    "post Octavam Paschæ": "after Easter",
    "post Octavam Paschae": "after Easter",
    "I post Octavam Paschae": "after Easter",
}

def suffix_for(rest):
    """Translate the part after the weekday into an English suffix phrase."""
    rest = rest.strip()

    # "infra Hebdomadam <ord> <season>" -> "of the Nth Week <season>"
    m = re.match(r"^infra Hebdomadam (\d+|[IVXL]+) (.+)$", rest)
    if m and m.group(1) in ORD:
        tail = WEEK_TAIL.get(m.group(2).strip())
        return f"of the {ORD[m.group(1)]} Week {tail}" if tail else None

    # "Hebdomadæ <num> post Pentecosten" (alternate word order)
    m = re.match(r"^Hebdomadæ (\d+|[IVXL]+) post Pentecosten$", rest)
    if m and m.group(1) in ORD:
        return f"of the {ORD[m.group(1)]} Week after Pentecost"

    fixed = {
        "infra Hebdomadam Pentecostes": "within the Octave of Pentecost",
        "infra Octavam Pentecostes": "within the Octave of Pentecost",
        "infra Hebdomadam Quinquagesimæ": "of Quinquagesima Week",
        "infra Hebdomadam Septuagesimæ": "of Septuagesima Week",
        "infra Hebdomadam Sexagesimæ": "of Sexagesima Week",
        "infra Hebdomadam Passionis": "of Passion Week",
        "infra Hebdomadam Adventus": "of Advent",
        "infra Hebdomadam post Ascensionem": "after the Ascension",
        "infra Tempus Nativitatis": "within Christmastide",
        "Hebdomadæ Sanctæ": "of Holy Week",
        "in Rogationibus": "of the Rogation Days",
        "post Ascensionem": "after the Ascension",
        "post Cineres": "after Ash Wednesday",
        "in Albis": "within the Octave of Easter",
    }
    return fixed.get(rest)

def translate_temporal(n):
    # "De Dominica" prefix (missal variant) → strip and treat as Dominica
    if n.startswith("De Dominica"):
        result = translate_temporal("Dominica" + n[len("De Dominica"):])
        if result:
            return result

    # Good Friday
    if n.startswith("Feria") and ("in Passione" in n or "in Parasceve" in n):
        return "Good Friday"

    # "Die <Cardinal> Januarii"
    m = re.match(r"^Die (\w+) Januarii$", n)
    if m and m.group(1) in CARDINAL:
        return f"January {CARDINAL[m.group(1)]}"

    # "Die <Roman> infra octavam Paschæ"
    m = re.match(r"^Die (II|III|IV|V|VI) infra octavam Paschæ$", n)
    if m:
        return f"{ORD[m.group(1)]} Day within the Octave of Easter"

    # Sundays: "Dominica <ord> [et Ultima] <season>"
    m = re.match(r"^Dominica (\d+|[IVXL]+)(?: et Ultima)? (.+)$", n)
    if m and m.group(1) in ORD:
        suf = suffix_for(m.group(2))
        if suf is None:
            # season phrase directly (e.g. "post Pentecosten")
            suf = season_tail(m.group(2))
        if suf:
            ultima = " (Last)" if "et Ultima" in n else ""
            return f"{ORD[m.group(1)]} Sunday {suf}{ultima}"
        return None

    # Ember days: "<Feria N | Sabbato> Quattuor Temporum <season>"
    m = re.match(r"^(?:Feria )?(?:(\w+) )?Quattuor Temporum (.+)$", n)
    if m and "Quattuor Temporum" in n:
        seas = EMBER_SEASON.get(m.group(2).strip())
        if seas:
            tok = m.group(1)
            if n.startswith("Sabbato") or (tok and tok.lower() == "sabbato"):
                return f"Ember Saturday {seas}"
            wd = feria_weekday(tok) if tok else None
            if wd == "Wednesday": return f"Ember Wednesday {seas}"
            if wd == "Friday": return f"Ember Friday {seas}"
            if wd == "Saturday": return f"Ember Saturday {seas}"
        return None

    # Ferias / Saturdays with a translatable suffix
    m = re.match(r"^Feria (\w+) (.+)$", n)
    if m:
        wd = feria_weekday(m.group(1))
        if wd:
            suf = suffix_for(m.group(2))
            if suf: return f"{wd} {suf}"
        return None
    # "Feria infra Hebdomadam Adventus" (no ordinal)
    if n == "Feria infra Hebdomadam Adventus":
        return None  # ambiguous weekday; skip
    m = re.match(r"^Sabbato (.+)$", n)
    if m:
        suf = suffix_for(m.group(1))
        if suf: return f"Saturday {suf}"
        return None

    return None

def season_tail(s):
    s = s.strip()
    tails = {
        "Adventus":"of Advent","in Quadragesima":"of Lent","Quadragesimæ":"of Lent",
        "Passionis":"of Passiontide","post Pentecosten":"after Pentecost",
        "Post Pentecosten":"after Pentecost","post Epiphaniam":"after Epiphany",
        "Post Epiphaniam":"after Epiphany","post Pascha":"after Easter",
        "Post Pascha":"after Easter","Post Octavam Paschæ":"after the Octave of Easter",
        "post Octavam Paschæ":"after the Octave of Easter",
    }
    return tails.get(s)

# ---------------------------------------------------------------------------
# Sanctoral
# ---------------------------------------------------------------------------

def translate_titles(rest):
    rest = rest.strip().strip(",").strip()
    rest = re.sub(r"^et ", "", rest)
    if not rest:
        return ""
    for lat, eng in TITLE_PHRASES:
        if rest == lat:
            return eng
    return None

def translate_saint(n):
    if n.startswith(("SS. ","Ss. ")):
        prefix, body = "Sts.", n[4:]
    elif n.startswith("S. "):
        prefix, body = "St.", n[3:]
    else:
        return None
    best = None
    for lat, eng in SAINTS.items():
        if body == lat or body.startswith(lat + " "):
            if best is None or len(lat) > len(best[0]):
                best = (lat, eng)
    if best is None:
        return None
    lat, eng = best
    rest = body[len(lat):].strip()
    if not rest:
        return f"{prefix} {eng}"
    titles = translate_titles(rest)
    if titles is None:
        return None
    return f"{prefix} {eng}, {titles}"

# ---------------------------------------------------------------------------

def translate(name):
    if name in OVERRIDES:
        return OVERRIDES[name]
    t = translate_temporal(name)
    if t:
        return t
    if name.startswith(("S.","SS.","Ss.")):
        return translate_saint(name)
    return None


def main():
    ordo = json.loads(ORDO.read_text())
    # Collect names from both the ordo AND the missal propers so the english
    # map covers feast titles wherever they appear.
    names = set(v["name"] for v in ordo.values())
    for mf in ["missal_tempora.json", "missal_sanctoral.json"]:
        p = ROOT / "Introibo" / "Resources" / mf
        if p.exists():
            for v in json.loads(p.read_text()).values():
                off = v.get("officium", "")
                if off:
                    names.add(off)
    names = sorted(names)
    out, missed = {}, []
    for n in names:
        eng = translate(n)
        if eng:
            out[n] = eng
        else:
            missed.append(n)
    OUT_IOS.write_text(json.dumps(out, ensure_ascii=False, indent=0, sort_keys=True))
    OUT_ANDROID.write_text(json.dumps(out, ensure_ascii=False, indent=0, sort_keys=True))
    print(f"translated {len(out)}/{len(names)} ({100*len(out)//len(names)}%); missed {len(missed)}")
    if "--show-missed" in sys.argv:
        for m in missed: print("  MISS:", m)
    if "--show-sample" in sys.argv:
        import random
        for n in random.sample(list(out.keys()), min(50, len(out))):
            print(f"  {n}  ->  {out[n]}")


if __name__ == "__main__":
    main()
