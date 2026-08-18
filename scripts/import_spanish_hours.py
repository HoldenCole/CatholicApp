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
COMMUNE_OUT = ROOT / "spanish-translation" / "commune_office_es.json"
TEMPORAL_OUT = ROOT / "spanish-translation" / "temporal_propers_es.json"
HYMNS_OUT = ROOT / "spanish-translation" / "hymns_seasonal_es.json"
SANCTORAL_OUT = ROOT / "spanish-translation" / "sanctoral_propers_es.json"
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


# -- Hand translations for temporal_propers fields the current DO
# Espanol tree no longer carries (the Latin recension moved on since the
# app's import). Traditional register; Torres Amat wording where the
# Latin follows the Vulgate; deuterocanonical texts tier-2 from the
# Vulgate; received texts (Pater noster, Gloria Patri) untouched.
# Matched by fold(full Latin field) — accents/punctuation-insensitive.
_PATER_LA = ("Pater noster, qui es in cælis, sanctificétur nomen tuum. "
             "Advéniat regnum tuum. Fiat volúntas tua, sicut in cælo et in "
             "terra. Panem nostrum quotidiánum da nobis hódie. Et dimítte "
             "nobis débita nostra, sicut et nos dimíttimus debitóribus "
             "nostris. Et ne nos indúcas in tentatiónem: sed líbera nos a "
             "malo. Amen.")
_PATER_ES = ("Padre nuestro, que estás en los cielos, santificado sea tu "
             "nombre, venga a nosotros tu reino, hágase tu voluntad así en "
             "la tierra como en el cielo. El pan nuestro de cada día "
             "dánosle hoy; perdónanos nuestras deudas, así como nosotros "
             "perdonamos a nuestros deudores, y no nos dejes caer en la "
             "tentación, mas líbranos del mal. Amén.")
_GLORIA_LA = ("Glória Patri, et Fílio, et Spirítui Sancto. Sicut erat in "
              "princípio, et nunc, et semper, et in sǽcula sæculórum. Amen.")
_GLORIA_ES = ("Gloria al Padre, y al Hijo, y al Espíritu Santo. Como era "
              "en el principio, ahora y siempre, por los siglos de los "
              "siglos. Amén.")
_RESPICE_LA = ("Réspice, quǽsumus, Dómine, super hanc famíliam tuam, pro "
               "qua Dóminus noster Jesus Christus non dubitávit mánibus "
               "tradi nocéntium, et crucis subíre torméntum: Qui tecum "
               "vivit et regnat in unitáte Spíritus Sancti, Deus, per "
               "ómnia sǽcula sæculórum. Amen.")
_RESPICE_ES = ("Mira, te rogamos, Señor, a esta tu familia, por la cual "
               "nuestro Señor Jesucristo no dudó entregarse a las manos "
               "de los verdugos y padecer el tormento de la cruz: El cual "
               "vive y reina contigo en la unidad del Espíritu Santo, "
               "Dios, por todos los siglos de los siglos. Amén.")
_CONCEDE_LA = ("Concéde, quǽsumus, omnípotens Deus: ut, qui Fílii tui "
               "resurrectiónem devóta exspectatióne prævenímus; ejúsdem "
               "resurrectiónis glóriam consequámur.")
_CONCEDE_ES = ("Concédenos, te rogamos, Dios todopoderoso: que los que "
               "anticipamos con devota expectación la resurrección de tu "
               "Hijo, consigamos la gloria de la misma resurrección.")
TEMPORAL_FIX_PAIRS = [
    # The August Wisdom-book Matins responsories (Eccli 24; Sap 9; Sap
    # 17-19) — the old recension the app carries.
    ("R. Gyrum cæli circuívi sola, et in flúctibus maris ambulávi, in "
     "omni gente et in omni pópulo primátum ténui:\n"
     "* Superbórum et sublímium colla própria virtúte calcávi.\n"
     "V. Ego in altíssimis hábito, et thronus meus in colúmna nubis.\n"
     "R. Superbórum et sublímium colla própria virtúte calcávi.",
     "R. Yo sola recorrí todo el giro del cielo, y me paseé por las olas "
     "del mar, y en toda gente y en todo pueblo tuve el primado:\n"
     "* Con mi propio poder hollé las cervices de los soberbios y de los "
     "altivos.\n"
     "V. Yo habito en las alturas, y mi trono está sobre una columna de "
     "nube.\n"
     "R. Con mi propio poder hollé las cervices de los soberbios y de "
     "los altivos."),
    ("R. Da mihi, Dómine, sédium tuárum assistrícem sapiéntiam, et noli "
     "me reprobáre a púeris tuis:\n"
     "* Quóniam servus tuus sum ego, et fílius ancíllæ tuæ.\n"
     "V. Mitte illam de sede magnitúdinis tuæ, ut mecum sit et mecum "
     "labóret.\n"
     "R. Quóniam servus tuus sum ego, et fílius ancíllæ tuæ.",
     "R. Dame, Señor, aquella sabiduría que asiste a tu trono, y no "
     "quieras excluirme del número de tus siervos:\n"
     "* Porque yo soy siervo tuyo, e hijo de tu esclava.\n"
     "V. Envíala desde el trono de tu grandeza, para que conmigo esté y "
     "conmigo trabaje.\n"
     "R. Porque yo soy siervo tuyo, e hijo de tu esclava."),
    ("R. Magna enim sunt judícia tua, Dómine, et inenarrabília verba "
     "tua:\n"
     "* Magnificásti pópulum tuum et honorásti.\n"
     "V. Transtulísti illos per Mare Rubrum et transvexísti eos per "
     "aquam nímiam.\n"
     "R. Magnificásti pópulum tuum et honorásti.",
     "R. Grandes son, Señor, tus juicios, e inefables tus palabras:\n"
     "* Engrandeciste a tu pueblo y lo llenaste de honra.\n"
     "V. Los hiciste pasar por el Mar Rojo, y los condujiste a través de "
     "las muchas aguas.\n"
     "R. Engrandeciste a tu pueblo y lo llenaste de honra."),
    # August–November Magnificat/Benedictus antiphons (old recension).
    ("Sapiéntia * clámitat in platéis: Si quis díligit sapiéntiam, ad me "
     "declínet, et eam invéniet: et, cum invénerit, beátus erit si "
     "tenúerit eam.",
     "La sabiduría * clama en las plazas: Si alguno ama la sabiduría, "
     "venga a mí y la hallará; y cuando la hubiere hallado, dichoso será "
     "si la retiene."),
    ("In ómnibus his * non peccávit Job lábiis suis neque stultum "
     "áliquid contra Deum locútus est.",
     "En todas estas cosas * no pecó Job con sus labios, ni profirió "
     "necedad alguna contra Dios."),
    ("Múlier, * quæ erat in civitáte peccátrix, stans retro secus pedes "
     "Dómini, lácrimis cœpit rigáre pedes ejus et capíllis cápitis sui "
     "tergébat, et deosculabátur pedes ejus et unguénto ungébat.",
     "Una mujer, * que era pecadora en la ciudad, puesta detrás a los "
     "pies del Señor, comenzó a regar con lágrimas sus pies, y los "
     "enjugaba con los cabellos de su cabeza, y besaba sus pies, y los "
     "ungía con perfume."),
    ("Illúmina, Dómine, * sedéntes in ténebris et umbra mortis, et "
     "dírige pedes nostros in viam pacis.",
     "Alumbra, Señor, * a los que yacen en las tinieblas y en la sombra "
     "de la muerte, y endereza nuestros pasos por el camino de la paz."),
    ("Adapériat Dóminus * cor vestrum in lege sua et in præcéptis suis "
     "et fáciat pacem Dóminus Deus noster.",
     "Abra el Señor * vuestro corazón a su ley y a sus preceptos, y haga "
     "la paz el Señor Dios nuestro."),
    ("Refúlsit sol * in clípeos áureos, et resplenduérunt montes ab eis: "
     "et fortitúdo géntium dissipáta est.",
     "Resplandeció el sol * sobre los escudos de oro, y brillaron con su "
     "luz los montes; y quedó deshecha la fuerza de las naciones."),
    ("Lugébat autem Judam * Israël planctu magno et dicébat: Quómodo "
     "cecidísti, potens in prǽlio, qui salvum faciébas pópulum Dómini?",
     "Lloraba Israel * a Judas con grande llanto, y decía: ¿Cómo caíste, "
     "valiente en la batalla, tú que salvabas al pueblo del Señor?"),
    # Advent, Christmastide, Epiphany antiphons.
    ("Antequam convenírent, * invénta est María habens in útero de "
     "Spíritu Sancto, allelúja.",
     "Antes de que morasen juntos, * se halló que María había concebido "
     "en su seno por obra del Espíritu Santo, aleluya."),
    ("Ecce véniet Rex * Dóminus terræ, et ipse áuferet jugum "
     "captivitátis nostræ.",
     "He aquí que vendrá el Rey, * Señor de la tierra, y él quitará el "
     "yugo de nuestro cautiverio."),
    ("Quómodo fiet istud, * Angele Dei, quóniam virum non cognósco? "
     "Audi, María Virgo: Spíritus Sanctus supervéniet in te, et virtus "
     "Altíssimi obumbrábit tibi.",
     "¿Cómo se hará esto, * Ángel de Dios, pues no conozco varón? "
     "Escucha, Virgen María: El Espíritu Santo vendrá sobre ti, y la "
     "virtud del Altísimo te cubrirá con su sombra."),
    ("Dicit Dóminus: * Pœniténtiam ágite: appropinquávit enim regnum "
     "cælórum, allelúja.",
     "Dice el Señor: * Haced penitencia, porque se ha acercado el reino "
     "de los cielos, aleluya."),
    ("Ponam in Sion * salútem, et in Jerúsalem glóriam meam, allelúja.",
     "Pondré en Sión * la salvación, y en Jerusalén mi gloria, aleluya."),
    ("Consolámini, consolámini, * pópule meus, dicit Dóminus Deus "
     "vester.",
     "Consolaos, consolaos, * pueblo mío, dice el Señor Dios vuestro."),
    ("Suscépit Deus * Israël, púerum suum: sicut locútus est ad "
     "Abraham, et semen ejus usque in sǽculum.",
     "Acogió Dios * a Israel, su siervo, como lo había prometido a "
     "Abrahán y a su descendencia por los siglos."),
    ("Dedit se, * ut liberáret pópulum, et acquíreret sibi nomen "
     "ætérnum, allelúja.",
     "Se entregó a sí mismo * para librar a su pueblo, y adquirir un "
     "nombre eterno, aleluya."),
    ("Vocábis * nomen ejus Jesum; ipse enim salvum fáciet pópulum suum "
     "a peccátis eórum, allelúja.",
     "Le pondrás por nombre * Jesús; pues él salvará a su pueblo de sus "
     "pecados, aleluya."),
    ("Oleum effúsum * nomen tuum, ídeo adolescéntulæ dilexérunt te.\n"
     "Scitóte, * quia Dóminus ipse est Deus, cujus nomen in ætérnum.\n"
     "Sitívit * ánima mea ad nomen sanctum tuum, Dómine.\n"
     "Benedíctum * nomen glóriæ tuæ sanctum, et laudábile, et "
     "superexaltátum in sǽcula.\n"
     "Júvenes et vírgines, * senes cum junióribus laudáte nomen Dómini, "
     "quia exaltátum est nomen ejus solíus.",
     "Óleo derramado * es tu nombre, por eso te amaron las doncellas.\n"
     "Sabed * que el Señor es Dios, cuyo nombre es eterno.\n"
     "Sedienta está * mi alma de tu santo nombre, Señor.\n"
     "Bendito sea * el santo nombre de tu gloria, digno de alabanza y "
     "ensalzado por los siglos.\n"
     "Los jóvenes y las vírgenes, * los ancianos y los niños alaben el "
     "nombre del Señor, porque sólo su nombre es ensalzado."),
    ("V. Notum fecit Dóminus, allelúja.\nR. Salutáre suum, allelúja.",
     "V. El Señor ha dado a conocer, aleluya.\n"
     "R. Su salvación, aleluya."),
    # Holy Saturday Paschal Vespers (mirrors the field's own structure).
    ("#Sabbato Sancto special Paschal Vespera\n" + _PATER_LA + "\n"
     "$Ave Maria\n"
     "Ant. Allelúja, Allelúja, Allelúja.",
     "#Sabbato Sancto special Paschal Vespera\n" + _PATER_ES + "\n"
     "$Ave Maria\n"
     "Ant. Aleluya, aleluya, aleluya.\n"
     "Ant. Aleluya, aleluya, aleluya.\n"
     "Ant. Y pasado el sábado, al amanecer del primer día de la semana, "
     "vino María Magdalena con la otra María a ver el sepulcro, "
     "aleluya.\n"
     "Ant. Y pasado el sábado, al amanecer del primer día de la semana, "
     "vino María Magdalena con la otra María a ver el sepulcro, "
     "aleluya.\n"
     "\n"
     "℣. El Señor sea con vosotros. ℟. Y con tu espíritu.\n"
     "Derrama, Señor, te suplicamos, el Espíritu de tu amor en nuestros "
     "corazones, y haz por tu misericordia que sean de un mismo sentir "
     "aquellos a quienes diste a comer de tu Pascua mística.\n"
     "Por nuestro Señor Jesucristo, tu Hijo, que vive y reina contigo "
     "en la unidad del Espíritu Santo, Dios, por todos los siglos de "
     "los siglos. Amén.\n"
     "℣. El Señor sea con vosotros. ℟. Y con tu espíritu.\n"
     "\n"
     "V. Bendigamos al Señor, aleluya, aleluya.\n"
     "R. Demos gracias a Dios, aleluya, aleluya.\n"
     "$Fidelium animae\n" + _PATER_ES),
    ("Vidéte manus meas * et pedes meos, quia ego ipse sum, allelúja, "
     "allelúja.",
     "Ved mis manos * y mis pies, que yo mismo soy, aleluya, aleluya."),
    # Rogation / octave commemorations — collects the Missal already
    # carries in Spanish, with their conclusions.
    ("Deus, qui errántibus, ut in viam possint redíre justítiæ, "
     "veritátis tuæ lumen osténdis: da cunctis, qui christiána "
     "professióne censéntur, et illa respúere, quæ huic inimíca sunt "
     "nómini; et ea, quæ sunt apta, sectári.\n"
     "Per Dóminum nostrum Jesum Christum, Fílium tuum: qui tecum vivit "
     "et regnat in unitáte Spíritus Sancti, Deus, per ómnia sǽcula "
     "sæculórum. Amen.",
     "Oh Dios, que muestras la luz de tu verdad a los que yerran, para "
     "que puedan volver al camino de la justicia: concede a todos los "
     "que profesan el nombre cristiano rechazar lo que es contrario a "
     "este nombre, y seguir lo que le es conforme.\n"
     "Por nuestro Señor Jesucristo, tu Hijo, que vive y reina contigo "
     "en la unidad del Espíritu Santo, Dios, por todos los siglos de "
     "los siglos. Amén."),
    ("Ant. Ascéndo ad Patrem meum, * et Patrem vestrum: Deum meum, et "
     "Deum vestrum, allelúja.\n"
     "V. Dóminus in cælo, allelúja.\n"
     "R. Parávit sedem suam, allelúja.",
     "Ant. Subo a mi Padre, * y vuestro Padre: a mi Dios, y vuestro "
     "Dios, aleluya.\n"
     "V. El Señor está en el cielo, aleluya.\n"
     "R. Ha preparado su trono, aleluya."),
    ("Ant. O Rex glóriæ, * Dómine virtútum, qui triumphátor hódie super "
     "omnes cælos ascendísti, ne derelínquas nos órphanos; sed mitte "
     "promíssum Patris in nos, Spíritum veritátis, allelúja.\n"
     "V. Ascéndit Deus in jubilatióne, allelúja.\n"
     "R. Et Dóminus in voce tubæ, allelúja.",
     "Ant. Oh Rey de la gloria, * Señor de los ejércitos, que "
     "triunfador subiste hoy sobre todos los cielos, no nos dejes "
     "huérfanos; antes envíanos al Espíritu de verdad, prometido del "
     "Padre, aleluya.\n"
     "V. Subió Dios entre voces de júbilo, aleluya.\n"
     "R. Y el Señor al son de la trompeta, aleluya."),
    # Vigil of Pentecost little chapters (1 Pet 4).
    ("Si quis lóquitur, quasi sermónes Dei: si quis minístrat, tamquam "
     "ex virtúte, quam adminístrat Deus: ut in ómnibus honorificétur "
     "Deus per Jesum Christum, Dóminum nostrum.\n"
     "$Deo gratias",
     "Si alguno habla, sean sus palabras como palabras de Dios: si "
     "alguno ejerce un ministerio, hágalo como en virtud del poder que "
     "Dios le comunica: para que en todo sea Dios honrado por "
     "Jesucristo, nuestro Señor.\n"
     "Demos gracias a Dios."),
    ("Hospitáles ínvicem sine murmuratióne. Unusquísque, sicut accépit "
     "grátiam, in altérutrum illam administrántes, sicut boni "
     "dispensatóres multifórmis grátiæ Dei.\n"
     "$Deo gratias",
     "Ejercitad la hospitalidad unos con otros sin murmuración. Cada "
     "uno, según la gracia que ha recibido, comuníquela a los demás, "
     "como buenos dispensadores de las diversas gracias de Dios.\n"
     "Demos gracias a Dios."),
    # Trinity Sunday eighth responsory.
    ("R. Duo Séraphim clamábant alter ad álterum:\n"
     "* Sanctus, sanctus, sanctus Dóminus Deus Sábaoth: * Plena est "
     "omnis terra glória ejus.\n"
     "V. Tres sunt qui testimónium dant in cælo: Pater, Verbum, et "
     "Spíritus Sanctus: et hi tres unum sunt.\n"
     "R. Sanctus, sanctus, sanctus Dóminus Deus Sábaoth.\n"
     + _GLORIA_LA + "\n"
     "R. Plena est omnis terra glória ejus.",
     "R. Dos serafines se clamaban el uno al otro:\n"
     "* Santo, santo, santo el Señor Dios de los ejércitos: * Llena "
     "está toda la tierra de su gloria.\n"
     "V. Tres son los que dan testimonio en el cielo: el Padre, el "
     "Verbo y el Espíritu Santo: y estos tres son una misma cosa.\n"
     "R. Santo, santo, santo el Señor Dios de los ejércitos.\n"
     + _GLORIA_ES + "\n"
     "R. Llena está toda la tierra de su gloria."),
    # Corpus Christi commemoration (the Missal's Spanish collect).
    ("Deus, qui nobis sub Sacraménto mirábili passiónis tuæ memóriam "
     "reliquísti: tríbue, quǽsumus, ita nos Córporis, et Sánguinis tui "
     "sacra mystéria venerári; ut redemptiónis tuæ fructum in nobis "
     "júgiter sentiámus:\n"
     "Qui vivis et regnas cum Deo Patre, in unitáte Spíritus Sancti, "
     "Deus, per ómnia sǽcula sæculórum. Amen.",
     "¡Oh Dios!, que bajo un sacramento admirable nos dejaste el "
     "memorial de tu pasión; te pedimos, Señor, nos concedas venerar de "
     "tal manera los sagrados misterios de tu cuerpo y sangre, que "
     "sintamos constantemente en nosotros el fruto de tu redención:\n"
     "Tú que vives y reinas con Dios Padre en la unidad del Espíritu "
     "Santo, Dios, por todos los siglos de los siglos. Amén."),
    # Sacred Heart hymn doxology (M variant).
    ("Glória tibi, Dómine,\nQui Corde fundis grátiam,\nCum Patre, et "
     "Sancto Spíritu,\nIn sempitérna sǽcula.\nAmen.",
     "Gloria a ti, Señor,\nque del Corazón derramas la gracia,\ncon el "
     "Padre y el Espíritu Santo,\npor los siglos sempiternos.\nAmén."),
    # Sacred Heart collect (pre-1955 recension).
    ("Concéde quǽsumus omnípotens Deus: ut, qui in sanctíssimo dilécti "
     "Fílii tui Corde gloriántes, præcípua in nos caritátis ejus "
     "benefícia recólimus; eórum páriter et actu delectémur et fructu.\n"
     "Per Dóminum nostrum Jesum Christum, Fílium tuum: qui tecum vivit "
     "et regnat in unitáte Spíritus Sancti, Deus, per ómnia sǽcula "
     "sæculórum. Amen.",
     "Concédenos, te rogamos, Dios todopoderoso: que, gloriándonos en "
     "el santísimo Corazón de tu amado Hijo, y recordando los "
     "principales beneficios de su caridad para con nosotros, nos "
     "gocemos igualmente en ellos y en su fruto.\n"
     "Por nuestro Señor Jesucristo, tu Hijo, que vive y reina contigo "
     "en la unidad del Espíritu Santo, Dios, por todos los siglos de "
     "los siglos. Amén."),
    # Time after Pentecost antiphons (old recension).
    ("Cognovérunt omnes * a Dan usque Bersabée, quod fidélis Sámuel "
     "prophéta esset Dómini.",
     "Conocieron todos, * desde Dan hasta Bersabee, que Samuel era fiel "
     "profeta del Señor."),
    ("R. Recordáre, Dómine, testaménti tui, et dic Angelo percutiénti: "
     "Cesset jam manus tua,\n"
     "* Ut non desolétur terra, et ne perdas omnem ánimam vivam.\n"
     "V. Ego sum qui peccávi, ego qui iníque egi: isti qui oves sunt, "
     "quid fecérunt? Avertátur, óbsecro, furor tuus, Dómine, a pópulo "
     "tuo.",
     "R. Acuérdate, Señor, de tu alianza, y di al Ángel exterminador: "
     "Detén ya tu mano,\n"
     "* Para que no quede desolada la tierra, y no pierdas a toda alma "
     "viviente.\n"
     "V. Yo soy el que pequé, yo el que obré inicuamente: éstos, que "
     "son las ovejas, ¿qué han hecho? Apártese, te ruego, Señor, tu "
     "furor de tu pueblo."),
    ("Audístis * quia dictum est antíquis: Non occídes; qui autem "
     "occíderit, reus erit judício.",
     "Oísteis * que fue dicho a los antiguos: No matarás; y quien "
     "matare, quedará sujeto a juicio."),
    ("Dum tólleret Dóminus * Elíam per túrbinem in cælum, Eliséus "
     "clamábat: Pater mi, currus Israël et auríga ejus.",
     "Cuando el Señor arrebataba * a Elías al cielo en un torbellino, "
     "clamaba Eliseo: ¡Padre mío, carro de Israel y su conductor!"),
    ("Fecit Joas * rectum coram Dómino cunctis diébus, quibus dócuit "
     "eum Jójada sacérdos.",
     "Hizo Joás * lo recto delante del Señor todos los días en que le "
     "dirigió el sacerdote Joyadá."),
    ("Descéndit * hic justificátus in domum suam ab illo; quia omnis "
     "qui se exáltat, humiliábitur, et, qui se humíliat, exaltábitur.",
     "Descendió éste * justificado a su casa, y no aquél; porque todo "
     "el que se ensalza, será humillado; y el que se humilla, será "
     "ensalzado."),
    ("Obsécro, Dómine: * meménto, quæso, quómodo ambuláverim coram te "
     "in veritáte et in corde perfécto et quod plácitum est coram te, "
     "fécerim.",
     "Te ruego, Señor: * acuérdate, te suplico, de que he andado "
     "delante de ti con verdad y con corazón perfecto, y que he hecho "
     "lo que es agradable a tus ojos."),
    ("Cum transísset Dóminus * fines Tyri, surdos fecit audíre et "
     "mutos loqui.",
     "Cuando salió el Señor * de los confines de Tiro, hizo oír a los "
     "sordos y hablar a los mudos."),
    ("Cum intráret Jesus * in domum cujúsdam príncipis pharisæórum "
     "sábbato manducáre panem, ecce homo quidam hydrópicus erat ante "
     "illum: ipse vero apprehénsum sanávit eum, ac dimísit.",
     "Al entrar Jesús * un sábado en casa de uno de los principales "
     "fariseos para comer pan, he aquí que un hombre hidrópico estaba "
     "delante de él: y Jesús, tomándole, le sanó y le despidió."),
    ("Intrávit autem rex * ut vidéret discumbéntes, et vidit ibi "
     "hóminem non vestítum veste nuptiáli et ait illi: Amíce, quómodo "
     "huc intrásti non habens vestem nuptiálem?",
     "Entró el rey * para ver a los convidados, y vio allí a un hombre "
     "que no estaba vestido con traje de boda, y le dijo: Amigo, ¿cómo "
     "has entrado aquí sin vestido nupcial?"),
    ("Serve nequam, * omne débitum dimísi tibi, quóniam rogásti me: "
     "nonne ergo opórtuit et te miseréri consérvi tui, sicut et ego "
     "tui misértus sum, allelúja.",
     "Siervo malvado, * toda la deuda te perdoné, porque me lo "
     "rogaste: ¿no debías tú también compadecerte de tu consiervo, "
     "como yo me compadecí de ti?, aleluya."),
    # Lent and Passiontide.
    ("Tunc invocábis, * et Dóminus exáudiet: clamábis, et dicet: Ecce "
     "adsum.",
     "Entonces invocarás, * y el Señor te oirá: clamarás, y te dirá: "
     "Aquí estoy."),
    ("Tunc assúmpsit * eum diábolus in sanctam civitátem, et státuit "
     "eum supra pinnáculum templi, et dixit ei: Si Fílius Dei es, "
     "mitte te deórsum.",
     "Entonces le llevó * el diablo a la ciudad santa, y le puso sobre "
     "el pináculo del templo, y le dijo: Si eres Hijo de Dios, échate "
     "de aquí abajo."),
    ("Fac benígne * in bona voluntáte tua, ut ædificéntur, Dómine, "
     "muri Jerúsalem.\n"
     "Dóminus * mihi adjútor est, non timébo quid fáciat mihi homo.\n"
     "Adhǽsit ánima mea * post te, Deus meus.",
     "Sé benigno * por tu buena voluntad, Señor, para que se "
     "edifiquen los muros de Jerusalén.\n"
     "El Señor * es mi sostén, no temeré nada de cuanto pueda hacerme "
     "el hombre.\n"
     "Mi alma está unida * a ti, Dios mío."),
    ("R. Extrahéntes Joseph de lacu, vendidérunt Ismaëlítæ vigínti "
     "argénteis:\n"
     "* Reversúsque Ruben ad púteum, cum non invenísset eum, scidit "
     "vestiménta sua cum fletu, et dixit: * Puer non compáret, et ego "
     "quo ibo?\n"
     "V. At illi, intíncta túnica Joseph in sánguine hædi, misérunt "
     "qui ferret eam ad patrem, et díceret: Vide, si túnica fílii tui "
     "sit, an non.\n"
     "R. Reversúsque Ruben ad púteum, cum non invenísset eum, scidit "
     "vestiménta sua cum fletu, et dixit.\n"
     + _GLORIA_LA + "\n"
     "R. Puer non compáret, et ego quo ibo?",
     "R. Sacando a José de la cisterna, lo vendieron a los ismaelitas "
     "por veinte monedas de plata:\n"
     "* Y volviendo Rubén al pozo, y no hallándole, rasgó sus "
     "vestiduras llorando, y dijo: * El niño no aparece, y yo ¿adónde "
     "iré?\n"
     "V. Ellos, empapando la túnica de José en la sangre de un "
     "cabrito, la enviaron a su padre con quien le dijese: Mira si es "
     "la túnica de tu hijo, o no.\n"
     "R. Y volviendo Rubén al pozo, y no hallándole, rasgó sus "
     "vestiduras llorando, y dijo.\n"
     + _GLORIA_ES + "\n"
     "R. El niño no aparece, y yo ¿adónde iré?"),
    ("Súbiit ergo, * in montem Jesus, et ibi sedébat cum discípulis "
     "suis.",
     "Subió, pues, * Jesús a un monte, y allí se sentó con sus "
     "discípulos."),
    ("Tunc acceptábis * sacrifícium justítiæ, si avérteris fáciem "
     "tuam a peccátis meis.\n"
     "Bonum est * speráre in Dómino, quam speráre in princípibus.\n"
     "Me suscépit * déxtera tua, Dómine.",
     "Entonces aceptarás * el sacrificio de justicia, si apartas tu "
     "rostro de mis pecados.\n"
     "Mejor es * poner la esperanza en el Señor, que ponerla en los "
     "príncipes.\n"
     "Me sostuvo * tu diestra, Señor."),
    ("Magíster dicit: * Tempus meum prope est, apud te fácio Pascha "
     "cum discípulis meis.",
     "El Maestro dice: * Mi tiempo está cerca, en tu casa celebro la "
     "Pascua con mis discípulos."),
    ("Ant. Desidério desiderávi * hoc Pascha manducáre vobíscum, "
     "ántequam pátiar.",
     "Ant. Con ansia he deseado * comer esta Pascua con vosotros, "
     "antes de padecer."),
    ("Pater juste, * mundus te non cognóvit: ego autem novi te, quia "
     "tu me misísti.",
     "Padre justo, * el mundo no te ha conocido: mas yo te he "
     "conocido, porque tú me enviaste."),
    ("Scriptum est enim: * Percútiam pastórem, et dispergéntur oves "
     "gregis: postquam autem resurréxero, præcédam vos in Galilǽam: "
     "ibi me vidébitis, dicit Dóminus.",
     "Porque escrito está: * Heriré al pastor, y se dispersarán las "
     "ovejas del rebaño: mas después que yo resucite, iré delante de "
     "vosotros a Galilea: allí me veréis, dice el Señor."),
    ("Ante diem festum * Paschæ, sciens Jesus quia venit hora ejus, "
     "cum dilexísset suos, in finem diléxit eos.",
     "Antes del día solemne * de la Pascua, sabiendo Jesús que era "
     "llegada su hora, como hubiese amado a los suyos, los amó hasta "
     "el fin."),
    # The Triduum orations (Christus factus est + Pater + collect).
    ("Christus factus est pro nobis obédiens usque ad mortem.\n\n"
     + _PATER_LA + "\n\n" + _RESPICE_LA,
     "Cristo se hizo por nosotros obediente hasta la muerte.\n\n"
     + _PATER_ES + "\n\n" + _RESPICE_ES),
    ("$Confiteor\n$Misereatur\n$Indulgentiam",
     "$Confiteor\n$Misereatur\n$Indulgentiam"),
    ("Christus factus est pro nobis obédiens usque ad mortem, mortem "
     "autem crucis.\n\n" + _PATER_LA + "\n\n" + _RESPICE_LA,
     "Cristo se hizo por nosotros obediente hasta la muerte, y muerte "
     "de cruz.\n\n" + _PATER_ES + "\n\n" + _RESPICE_ES),
    ("Deus ádjuvat me, * et Dóminus suscéptor est ánimæ meæ.",
     "Dios me socorre, * y el Señor toma por su cuenta la defensa de "
     "mi vida."),
    ("Dómine, * abstraxísti ab ínferis ánimam meam.",
     "Señor, * sacaste mi alma del infierno."),
    ("Christus factus est pro nobis obédiens usque ad mortem, mortem "
     "autem crucis. Propter quod et Deus exaltávit illum: et dedit "
     "illi nomen, quod est super omne nomen.\n\n" + _PATER_LA + "\n\n"
     + _CONCEDE_LA + " Per eúndem Dóminum nostrum Jesum Christum "
     "Fílium tuum, qui tecum vivit et regnat in unitáte Spíritus "
     "Sancti, Deus, per ómnia sǽcula sæculórum. Amen.",
     "Cristo se hizo por nosotros obediente hasta la muerte, y muerte "
     "de cruz. Por lo cual Dios le ensalzó, y le dio un nombre que es "
     "sobre todo nombre.\n\n" + _PATER_ES + "\n\n"
     + _CONCEDE_ES + " Por el mismo Señor nuestro Jesucristo, tu "
     "Hijo, que vive y reina contigo en la unidad del Espíritu Santo, "
     "Dios, por todos los siglos de los siglos. Amén."),
    ("Christus factus est pro nobis obédiens usque ad mortem, mortem "
     "autem crucis: propter quod et Deus exaltávit illum, et dedit "
     "illi nomen, quod est super omne nomen.\n" + _PATER_LA + "\n"
     + _CONCEDE_LA + "\n$Per eumdem",
     "Cristo se hizo por nosotros obediente hasta la muerte, y muerte "
     "de cruz: por lo cual Dios le ensalzó, y le dio un nombre que es "
     "sobre todo nombre.\n" + _PATER_ES + "\n" + _CONCEDE_ES + "\n"
     "Por el mismo Señor Nuestro Jesucristo, tu Hijo, que vive y "
     "reina en la unidad del Espíritu Santo, Dios, por todos los "
     "siglos de los siglos. Amén."),
]


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

    def compose_brief_responsory(lat):
        """'R.br. A * B.\\nR. A * B.\\nV. C.\\nR. B.\\n<Gloria>\\nR. A * B.'
        — translate the A, B, and C segments independently and rebuild
        the same line pattern."""
        first = lat.split("\n", 1)[0]
        m = re.match(r"^R\.br\.\s*(.+?)\s*\*\s*(.+?)\.?\s*$", first)
        if not m:
            return None
        a_lat, b_lat = m.group(1), m.group(2)
        v_lat = None
        for l in lat.split("\n"):
            if l.strip().startswith("V."):
                v_lat = clean_line(l)
                break
        a = find_line(a_lat)
        b = find_line(b_lat)
        if a is None or b is None:
            whole = find_line(a_lat + " " + b_lat)
            if whole is None:
                return None
            # place the mediant at the same ratio as the Latin
            ratio = len(a_lat) / max(1, len(a_lat) + len(b_lat))
            pos = int(len(whole) * ratio)
            sp = [mm.start() for mm in re.finditer(r"\s", whole)]
            if not sp:
                return None
            cut = min(sp, key=lambda c: abs(c - pos))
            a, b = whole[:cut].strip(), whole[cut:].strip()
        v = find_line(v_lat) if v_lat else None
        if v is None:
            return None
        a = a.rstrip(".")
        b = b.rstrip(".")
        return (f"R.br. {a} * {b}.\n"
                f"R. {a} * {b}.\n"
                f"V. {v if v.endswith('.') else v + '.'}\n"
                f"R. {cap_first(b)}.\n"
                f"{GLORIA_ES}\n"
                f"R. {a} * {b}.")

    def cap_first(s):
        for i, ch in enumerate(s):
            if ch.isalpha():
                return s[:i] + ch.upper() + s[i + 1:]
        return s

    # ---- the Office commons (commune_office.json) share the Hour.Part
    # shape — translate them with the same tables into
    # commune_office_es.json (supplement keys "commune:<C>:<field>:<f>")
    commune = json.load(open(ROOT / "Introibo/Resources/"
                             "commune_office.json"))
    cout = {}
    cmisses = []
    cn = 0
    for ckey in sorted(commune):
        for fkey, p in sorted(commune[ckey].items()):
            if not isinstance(p, dict):
                continue
            entry = {}
            for lat_f, eng_f in SINGLE:
                if not p.get(eng_f):
                    continue
                skey = f"commune:{ckey}:{fkey}:{eng_f}"
                if skey in supp:
                    entry[eng_f] = supp[skey]
                    cn += 1
                    continue
                lat = p.get(lat_f) or ""
                if p.get("type") == "hymn" and eng_f == "eng":
                    first = lat.split("\n", 1)[0]
                    t = hymn_map.get(fold(clean_line(first)))
                elif lat.startswith("R.br.") and eng_f == "eng":
                    t = compose_brief_responsory(lat)
                elif lat.strip() in ("$Deo gratias", "$Deo gratias."):
                    t = "Demos gracias a Dios."
                elif "\n" in lat or len(lat) > 140:
                    t = find_block(lat)
                else:
                    t = find_line(lat)
                    if t is None:
                        t = find_block(lat)
                if t:
                    m = re.match(r"^([℣℟VR]\.\s*)", p[eng_f])
                    if m and not re.match(r"^[℣℟VR]\.", t):
                        t = m.group(1) + t
                    entry[eng_f] = nfc(t)
                    cn += 1
                else:
                    cmisses.append((ckey, fkey, (lat or "?")[:60]))
            if p.get("verses"):
                vkey = f"commune:{ckey}:{fkey}:verses"
                if vkey in supp and len(supp[vkey]) == len(p["verses"]):
                    entry["verses"] = supp[vkey]
                    cn += len(supp[vkey])
                else:
                    vs = []
                    hit_any = False
                    for vi, vv in enumerate(p["verses"]):
                        el = supp.get(f"commune:{ckey}:{fkey}:verses:{vi}")
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
                        cn += sum(1 for x in vs if x)
                    else:
                        cmisses.append((ckey, fkey + "/verses",
                                        p["verses"][0]["lat"][:60]))
            if entry:
                cout.setdefault(ckey, {})[fkey] = entry
    COMMUNE_OUT.write_text(json.dumps(cout, ensure_ascii=False, indent=1,
                                      sort_keys=True) + "\n",
                           encoding="utf-8")
    print(f"commune: wrote {sum(len(v) for v in cout.values())} parts "
          f"({cn} fields)")
    if cmisses:
        print(f"COMMUNE MISSES {len(cmisses)}:")
        for m in cmisses:
            print("   ", m)

    # ---- the temporal propers (temporal_propers.json): app keys map
    # 1:1 to Tempora filenames and app field keys are the section names
    # lowercased/underscored, so pair each day's file section-for-section
    # (the most precise source); the global pair tables and the psalm
    # bank cover the assembled matutinum/vesperae parts. The Matins
    # lessons (lectio*) are a separate tranche with their own
    # per-pericope provenance audit — skipped here.
    temporal = json.load(open(ROOT / "Introibo/Resources/"
                              "temporal_propers.json"))
    # The sanctoral Office propers share the shape and the machinery —
    # their keys map to the Sancti files the same way.
    sanctoral = json.load(open(ROOT / "Introibo/Resources/"
                               "sanctoral_propers.json"))
    combined = {}
    combined.update(temporal)
    combined.update(sanctoral)
    es_temp_files = {}
    lat_temp_files = {}
    for sub in ("Tempora", "Sancti"):
        for p in (es_horas / sub).glob("*.txt"):
            es_temp_files.setdefault(p.name[:-4].lower(), p)
        for p in (lat_horas / sub).glob("*.txt"):
            lat_temp_files.setdefault(p.name[:-4].lower(), p)

    def key_file(files, key):
        """Exact filename first; app rite-variant suffixes ('01-05cc',
        '01-06n') fall back to the base MM-DD file."""
        p = files.get(key)
        if p is None:
            base = re.sub(r"(?<=\d)[a-z]+$", "", key)
            if base != key:
                p = files.get(base)
        return p

    _secs_cache = {}

    def file_secs(path):
        k = str(path)
        if k not in _secs_cache:
            _secs_cache[k] = {n.lower().replace(" ", "_"): raw
                              for n, raw in parse_sections(path).items()}
        return _secs_cache[k]

    REF_LINE = re.compile(r"^@([^:]+?)(?::(.+))?$")

    def _deref(raw):
        """Section body, or None if it is itself an @-reference."""
        if not raw:
            return None
        c = [l for l in raw if l.strip() and l.strip() != "_"]
        if not c or c[0].strip().startswith("@"):
            return None
        return raw

    def resolve_pair(es_path, lat_path, sec, depth=0):
        """(Espanol raw lines, Latin raw lines) for the section, following
        @File:Section references through both trees in lock-step (the
        Latin file guides the reference when the Espanol omits it)."""
        if depth > 3:
            return None, None
        for path in (es_path, lat_path):
            if path is None or not path.exists():
                continue
            raw = file_secs(path).get(sec)
            if raw is None:
                continue
            content = [l for l in raw if l.strip() and l.strip() != "_"]
            m = REF_LINE.match(content[0].strip()) if content else None
            if m:
                relpath = m.group(1).strip()
                rsec = (m.group(2) or sec).split(":")[0].strip()
                ep2 = es_horas / (relpath + ".txt")
                lp2 = lat_horas / (relpath + ".txt")
                return resolve_pair(ep2 if ep2.exists() else None,
                                    lp2 if lp2.exists() else None,
                                    rsec.lower().replace(" ", "_"),
                                    depth + 1)
            break
        es_raw = (file_secs(es_path).get(sec)
                  if es_path is not None and es_path.exists() else None)
        lat_raw = (file_secs(lat_path).get(sec)
                   if lat_path is not None and lat_path.exists() else None)
        return _deref(es_raw), _deref(lat_raw)

    def concl_es(macro):
        """$-macro conclusion -> the received Spanish formula from the
        Espanol Prayers.txt sections (Per Dominum, Qui vivis, …)."""
        raw = espanol_named.get(("Psalterium/Common/Prayers.txt", macro))
        if raw is None:
            return None
        t = " ".join(content_lines(raw))
        return re.sub(r"\s+", " ", t).strip() or None

    def render_es_section(raw_lines):
        """Espanol section -> app-style text: cleaned lines with their
        V./R. markers kept, &Gloria expanded to the received Gloria,
        $conclusions expanded from Prayers.txt. None on unknown macros."""
        out = []
        for raw in raw_lines:
            s = raw.strip()
            if not s or s == "_":
                continue
            if s.startswith(("!", "@", "#")):
                continue
            if s.startswith("&"):
                if s[1:].split()[0] in ("Gloria", "GloriaL"):
                    out.append(GLORIA_ES)
                    continue
                return None
            if s.startswith("$"):
                c = concl_es(s[1:].strip().rstrip("."))
                if c is None:
                    return None
                out.append(c)
                continue
            m = re.match(r"^([VvRr]\.|℣\.|℟\.)", s)
            pre = (m.group(1)[0].upper() + ". ") if m else ""
            if pre.startswith(("℣", "℟")):
                pre = ("V. " if m.group(1)[0] == "℣" else "R. ")
            c = clean_line(s)
            if c:
                out.append(pre + c)
        text = "\n".join(out).strip()
        return text or None

    # Old-recension Matins responsories and antiphons the current DO
    # Espanol tree no longer carries — hand translations in the
    # traditional register (Torres Amat wording where the Latin follows
    # the Vulgate; the deuterocanonical texts tier-2 from the Vulgate).
    # Keyed by fold(full Latin field).
    TEMPORAL_FIXES = {}
    for lt, es_ in TEMPORAL_FIX_PAIRS:
        TEMPORAL_FIXES[fold(lt)] = es_

    # ---- the Matins lessons (--lessons): scripture pericopes are
    # COMPOSED from the Torres Amat module (the DO Espanol Tempora
    # lessons are largely a modern, non-TA scripture translation — the
    # per-pericope audit rejected them); patristic/homily lessons keep
    # the DO Espanol traditional-register translation (tier 2, like the
    # orations). Deuterocanonical pericopes need their own tier-2
    # compositions (lessons_deutero_office_es.json, keyed
    # "<key>:<field>") — until supplied they stay English.
    LESSONS = "--lessons" in sys.argv
    ta_text = None
    isr = None
    lessons_deutero = {}
    if LESSONS:
        import import_spanish_readings as isr_mod
        isr = isr_mod
        # DO's Tempora files abbreviate books differently than the missal
        isr.BOOKS.update({
            "Ezek": "Ezekiel", "Eccl": "Ecclesiastes", "Apo": "Revelation",
            "Titus": "Titus", "Jonas": "Jonah", "Mic": "Micah",
            "Phlm": "Philemon", "Judas": "Jude",
            "2 Joannes": "2 John", "1 Jn": "1 John", "2 Jn": "2 John",
            "3 Jn": "3 John",
            "1 Mac": isr_mod.DEUTERO, "2 Mac": isr_mod.DEUTERO,
            "Jdt": isr_mod.DEUTERO, "Bar": isr_mod.DEUTERO,
        })
        bible_path = arg("--bible", str(DEFAULT_DO.parent /
                                        "torres_amat.bin"))
        kjv_path = arg("--kjv", str(DEFAULT_DO.parent / "kjv.json"))
        verse_lines = open(bible_path, encoding="utf-8-sig",
                           newline="").read().splitlines()
        kjv_books = json.load(open(kjv_path, encoding="utf-8"))["books"]
        ta_index = {}
        line_no = 0
        for b in kjv_books:
            by_cv = {}
            for ch in b["chapters"]:
                for v in ch["verses"]:
                    by_cv[(int(ch["chapter"]), int(v["verse"]))] = line_no
                    line_no += 1
            ta_index[b["name"]] = by_cv

        def ta_line_text(ln):
            if not (0 <= ln < len(verse_lines)):
                return None
            t = re.sub(r"<[^>]*>", " ", verse_lines[ln])
            t = re.sub(r"\s+([,.;:!?])", r"\1",
                       re.sub(r"\s+", " ", t)).strip()
            return t or None

        def ta_text(name, ch, v, line_shift=0):
            shift = isr.VULGATE_SHIFTS.get((name, ch), 0)
            ln = ta_index.get(name, {}).get((ch, v + shift))
            if ln is None:
                return None
            return ta_line_text(ln + line_shift)

        def cognate_stems(s):
            out = set()
            for w in fold(s).split():
                w = w.replace("ue", "o").replace("ie", "e")
                if len(w) >= 5:
                    out.add(w[:4])
            return out

        def cog_score(lat_s, es_s):
            a = cognate_stems(lat_s)
            if not a:
                return 0.5
            return len(a & cognate_stems(es_s)) / len(a)

        def pair_score(lat_s, es_s):
            """Cognate fit + length similarity (TA runs ~1.15x the
            Latin) — TA's free renderings can be cognate-poor."""
            r = len(es_s) / (1.15 * max(1, len(lat_s)))
            return cog_score(lat_s, es_s) + \
                0.5 * (min(r, 1 / r) if r > 0 else 0.0)

        lesson_shift_stats = {}

        dpath = ROOT / "spanish-translation" / \
            "lessons_deutero_office_es.json"
        if dpath.exists():
            lessons_deutero = json.load(open(dpath, encoding="utf-8"))

    # Sections whose source carries no parsable "!" reference.
    LESSON_REFS = {
        ("pasc2-2t", "lectio3"): "Act 18:5-6",
        ("pasc6-6", "lectio1"): "Judas 1:1-4",
        ("pasc6-6", "lectio2"): "Judas 1:5-8",
        ("pasc6-6", "lectio3"): "Judas 1:9-13",
        # Sancti sections whose "!" ref belongs to a different variant.
        ("01-00", "lectio1"): "Act 3:1-8",
        ("01-00", "lectio2"): "Act 3:9-16",
        ("01-00", "lectio3"): "Act 4:5-12",
        ("03-25", "lectio1"): "Isa 7:10-15",
        ("09-08", "lectio1"): "Cant 1:1-4",
        ("09-08", "lectio2"): "Cant 1:5-9",
        ("09-08", "lectio3"): "Cant 1:10-16",
        ("12-24s", "lectio1"): "Isa 35:1-7",
        ("12-24s", "lectio2"): "Isa 35:7-10",
        ("12-24s", "lectio3"): "Isa 41:1-4",
        ("12-24so", "lectio1"): "Isa 35:1-7",
        ("12-24so", "lectio2"): "Isa 35:7-10",
        ("12-24so", "lectio3"): "Isa 41:1-4",
        ("epi1-0b", "lectio1"): "1 Cor 1:1-3",
        ("epi1-0b", "lectio2"): "1 Cor 1:4-9",
        ("epi1-0b", "lectio3"): "1 Cor 1:10-13",
        ("nat01o", "lectio3"): "Rom 4:9-12",
        ("nat04o", "lectio1"): "Rom 5:1-5",
        ("nat04o", "lectio2"): "Rom 5:6-9",
        ("nat05o", "lectio2"): "Rom 7:4-6",
        ("10-24", "lectio3"): "Tob 12:14-22",
    }
    # Office lesson headings the missal intro translator doesn't know.
    HEAD_FIXES = {}
    for _la, _es in [
        ("Incipit Epístola cathólica beáti Judæ Apóstoli",
         "Empieza la Epístola católica del Apóstol San Judas"),
    ]:
        HEAD_FIXES[fold(_la)] = _es

    # The Office collect of a feast is the Mass collect — the missal's
    # Spanish already carries the common saints' orations. Bank them by
    # the folded body (conclusion stripped).
    CONCL_CUT = re.compile(
        r"\s*(?:Per (?:Dóminum|eúndem|Dominum)|Qui vivis|Qui tecum"
        r"|\$).*$", re.S)

    def oration_key(lat):
        k = fold(CONCL_CUT.sub("", clean_line(lat.replace("\n", " "))))
        # ae/oe spellings vary between the trees (caelestis/coelestis)
        return k.replace("ae", "e").replace("oe", "e")

    oration_bank = {}
    missal_es = json.load(open(ROOT / "spanish-translation/"
                               "missal_propers_es.json"))
    for srcname in ("missal_tempora.json", "missal_sanctoral.json"):
        msrc = json.load(open(ROOT / "Introibo/Resources" / srcname))
        for slug, entry in msrc.items():
            eslug = missal_es.get(slug) or {}
            for f in ("oratio", "secreta", "postcommunio", "oratio_2",
                      "oratio_3"):
                v = entry.get(f)
                es_v = eslug.get(f)
                if isinstance(v, dict) and v.get("lat") and \
                        isinstance(es_v, str) and es_v.strip():
                    k = oration_key(v["lat"])
                    if len(k) > 25:
                        oration_bank.setdefault(k, es_v.strip())

    tout = {}
    tmisses = []
    tn = 0
    pending_lessons = []   # scripture pericopes awaiting shift consensus
    ch_agg = {}            # (book, chapter) -> {shift: summed score}
    sout = {}
    for tkey in sorted(combined):
        tout_dst = sout if tkey in sanctoral else tout
        es_p = key_file(es_temp_files, tkey)
        lat_p = key_file(lat_temp_files, tkey)
        for fkey, p in sorted(combined[tkey].items()):
            if not isinstance(p, dict):
                continue
            if fkey.startswith("lectio"):
                if not LESSONS or not p.get("eng"):
                    continue
                lat = p.get("lat") or ""
                skey = f"temporal:{tkey}:{fkey}:eng"
                if skey in supp:
                    tout_dst.setdefault(tkey, {})[fkey] = {"eng": supp[skey]}
                    tn += 1
                    continue
                raw_es, raw_lat = resolve_pair(es_p, lat_p, fkey)
                if raw_es is None and raw_lat is None:
                    base = re.sub(r"_(19\d\d|cist|op)$", "", fkey)
                    if base != fkey:
                        raw_es, raw_lat = resolve_pair(es_p, lat_p, base)
                lat_lines = lat.split("\n")
                num_idx = [i for i, l in enumerate(lat_lines)
                           if re.match(r"^\d+ ", l.strip())]
                is_reading = bool(num_idx) and all(
                    re.match(r"^\d+ ", l.strip())
                    for l in lat_lines[num_idx[0]:] if l.strip())
                t = None
                if is_reading:
                    ref = LESSON_REFS.get((tkey, fkey))
                    parsed = isr.parse_ref(ref) if ref else None
                    if parsed is None:
                        for l in (raw_lat or []) + (raw_es or []):
                            if l.strip().startswith("!"):
                                cand = l.strip()[1:].strip()
                                parsed = isr.parse_ref(cand)
                                if parsed:
                                    ref = cand
                                    break
                                if ref is None:
                                    ref = cand
                    seq = None
                    deutero = False
                    if parsed:
                        seq = []
                        for book, ch, v in parsed:
                            name = isr.BOOKS.get(book)
                            if name is None:
                                seq = None
                                break
                            if name == isr.DEUTERO or \
                               (name == "Esther" and ch > 10) or \
                               (name == "Ecclesiastes" and ch > 12) or \
                               (name == "Daniel" and (ch > 12 or
                                    (ch == 3 and (v is None or v > 23)))):
                                deutero = True
                                break
                            seq.append((name, ch, v))
                    if deutero:
                        dt = lessons_deutero.get(f"{tkey}:{fkey}")
                        if dt:
                            tout_dst.setdefault(tkey, {})[fkey] = {"eng": dt}
                            tn += 1
                        else:
                            tmisses.append((tkey, fkey,
                                            "DEUTERO " + (ref or "?")))
                        continue
                    if seq:
                        out_lines = []
                        ok = True
                        head_lines = [h for h in lat_lines[:num_idx[0]]
                                      if h.strip()]
                        es_heads = []
                        if raw_es:
                            for l in raw_es:
                                s = l.strip()
                                if not s or s.startswith(("!", "@", "#")):
                                    continue
                                if re.match(r"^\d+ ", s):
                                    break
                                es_heads.append(clean_line(l))
                        if es_heads and len(es_heads) == len(head_lines):
                            out_lines.extend(es_heads)
                        else:
                            for h in head_lines:
                                if h.strip().startswith("!"):
                                    out_lines.append(h.strip())
                                    continue
                                hc = clean_line(h)
                                ht = (HEAD_FIXES.get(fold(hc))
                                      or isr.translate_intro(hc)
                                      or find_line(hc))
                                if ht is None:
                                    ok = False
                                    break
                                out_lines.append(ht)
                        if ok:
                            vnum_lines = [l.strip()
                                          for l in lat_lines[num_idx[0]:]
                                          if l.strip()]
                            pairs = []  # (printed num, latin text, n/c/v)
                            if len(vnum_lines) == len(seq):
                                # positional zip — robust to source typos
                                # in the printed verse numbers
                                for (name, ch, v), s in zip(seq,
                                                            vnum_lines):
                                    pairs.append(
                                        (v, re.sub(r"^\d+ ", "", s),
                                         name, ch, v))
                            else:
                                si = 0
                                for s in vnum_lines:
                                    n_ = int(re.match(r"^(\d+) ",
                                                      s).group(1))
                                    while si < len(seq) and \
                                            seq[si][2] != n_:
                                        si += 1
                                    if si >= len(seq):
                                        ok = False
                                        break
                                    name, ch, v = seq[si]
                                    si += 1
                                    pairs.append(
                                        (n_, re.sub(r"^\d+ ", "", s),
                                         name, ch, v))
                            # The module's versification drifts in spots
                            # (its Isaiah drops the 1:1 title verse,
                            # shifting chapters 1-44 down a line). Score
                            # every line-shift per pericope, aggregate
                            # per chapter, and decide in a post-pass —
                            # a chapter's shift is consistent even when
                            # a single short pericope is ambiguous.
                            if ok and pairs:
                                for shf in (0, -1, 1, -2, 2, -3, 3, -4, 4):
                                    tot = 0.0
                                    good = True
                                    for num, lt, name, ch, v in pairs:
                                        t_ = ta_text(name, ch, v, shf)
                                        if t_ is None:
                                            good = False
                                            break
                                        tot += pair_score(lt, t_)
                                    if not good:
                                        continue
                                    sc = tot / len(pairs)
                                    for _n, _lt, name, ch, _v in pairs:
                                        d = ch_agg.setdefault((name, ch),
                                                              {})
                                        d[shf] = d.get(shf, 0.0) + sc
                                pending_lessons.append(
                                    (tkey, fkey, ref, out_lines, pairs))
                                continue
                        if ok and out_lines:
                            t = "\n".join(out_lines)
                    if t is None:
                        tmisses.append((tkey, fkey, "SCRIPT " +
                                        (ref or lat_lines[0][:50])))
                        continue
                else:
                    # patristic/homily lesson: the DO Espanol
                    # traditional-register translation (tier 2)
                    if raw_es:
                        t = render_es_section(raw_es)
                        if t is not None and len(t.split("\n")) != \
                                len(lat_lines):
                            t = None
                    if t is None:
                        t = find_block(lat)
                    if t is None:
                        tmisses.append((tkey, fkey, "PATRISTIC " +
                                        lat_lines[0][:50]))
                        continue
                tout_dst.setdefault(tkey, {})[fkey] = {"eng": nfc(t)}
                tn += 1
                continue
            entry = {}
            for lat_f, eng_f in SINGLE:
                if not p.get(eng_f):
                    continue
                skey = f"temporal:{tkey}:{fkey}:{eng_f}"
                if skey in supp:
                    entry[eng_f] = supp[skey]
                    tn += 1
                    continue
                lat = p.get(lat_f) or ""
                t = None
                if eng_f == "eng":
                    raw_es, raw_lat = resolve_pair(es_p, lat_p, fkey)
                    if raw_es is None and raw_lat is None:
                        # conditioned variants keep a rubric suffix on the
                        # field key ("responsory3_1960") — retry the base
                        base = re.sub(r"_(19\d\d|cist|op)$", "", fkey)
                        if base != fkey:
                            raw_es, raw_lat = resolve_pair(es_p, lat_p, base)
                    # the resolved LATIN must be the very text the app
                    # carries (first line identity) — a mismatch means we
                    # found a different variant of the section
                    if raw_es is not None and raw_lat is not None:
                        lc = content_lines(raw_lat)
                        a = fold(lc[0]) if lc else ""
                        b = fold(clean_line(lat.split("\n", 1)[0]))
                        # prefix match either way: DO has re-split some
                        # lines since the app's import, but a different
                        # VARIANT of the section starts with different text
                        if not a or not (a == b or a.startswith(b)
                                         or b.startswith(a)):
                            raw_es = None
                else:
                    raw_es = None
                if p.get("type") == "hymn" and eng_f == "eng":
                    first = lat.split("\n", 1)[0]
                    t = hymn_map.get(fold(clean_line(first)))
                    if t is None and raw_es:
                        txt = "\n".join(
                            "" if l.strip() == "_" else clean_line(l)
                            for l in raw_es
                            if not l.strip().startswith("!"))
                        txt = re.sub(r"\n{3,}", "\n\n", txt).strip()
                        t = txt or None
                elif eng_f == "eng" and raw_es:
                    t = render_es_section(raw_es)
                    # the app's lat mirrors the Latin file's lines — a
                    # count mismatch means the Espanol file diverges
                    ref_txt = lat if lat else p[eng_f]
                    if t is not None and \
                            len(t.split("\n")) != len(ref_txt.split("\n")):
                        t = None
                if t is None and lat.startswith("R.br.") and eng_f == "eng":
                    t = compose_brief_responsory(lat)
                if t is None and eng_f == "eng" and "\n" in lat:
                    # line-by-line composition: DO has reshuffled some
                    # Matins responsories since the app's import, but the
                    # individual lines survive in the pair table
                    comp = []
                    ok = True
                    for ln in lat.split("\n"):
                        pre_m = re.match(r"^((?:Ant\.|[VR]\.|℣\.|℟\.)\s*)",
                                         ln.strip())
                        pre = pre_m.group(1).strip() + " " if pre_m else ""
                        c = clean_line(ln)
                        if not c:
                            ok = False
                            break
                        if fold(c).startswith("gloria patri et filio"):
                            comp.append(GLORIA_ES)
                            continue
                        cl = find_line(c)
                        if cl is None and "*" in ln:
                            segs = [clean_line(x)
                                    for x in ln.split("*")]
                            es_segs = [find_line(x) for x in segs if x]
                            if all(es_segs) and es_segs:
                                cl = " * ".join(
                                    x.rstrip() for x in es_segs)
                        if cl is None:
                            ok = False
                            break
                        if pre and not re.match(r"^(?:Ant\.|[VR]\.|℣\.|℟\.)",
                                                cl):
                            cl = pre + cl
                        comp.append(cl)
                    if ok and comp:
                        t = "\n".join(comp)
                if t is None and lat.strip() in ("$Deo gratias",
                                                 "$Deo gratias."):
                    t = "Demos gracias a Dios."
                if t is None:
                    if "\n" in lat or len(lat) > 140:
                        t = find_block(lat)
                    else:
                        t = find_line(lat)
                        if t is None:
                            t = find_block(lat)
                        if t is None:
                            # many antiphons are psalm-verse fragments
                            t = bank.get(bank_key(clean_line(lat)))
                if t is None:
                    t = TEMPORAL_FIXES.get(fold(lat))
                if t is None:
                    t = oration_bank.get(oration_key(lat))
                if t:
                    m = re.match(r"^([℣℟VR]\.\s*)", p[eng_f])
                    if m and not re.match(r"^[℣℟VR]\.", t):
                        t = m.group(1) + t
                    entry[eng_f] = nfc(t)
                    tn += 1
                elif lat.lstrip().startswith(("@", "#", "(deinde")):
                    # unresolved-reference artifacts in the source data —
                    # the English side carries the same raw text
                    pass
                else:
                    tmisses.append((tkey, fkey, (lat or "?")[:60]))
            if p.get("verses"):
                vkey = f"temporal:{tkey}:{fkey}:verses"
                if vkey in supp and len(supp[vkey]) == len(p["verses"]):
                    entry["verses"] = supp[vkey]
                    tn += len([x for x in supp[vkey] if x])
                else:
                    vs = []
                    hit_any = False
                    for vi, vv in enumerate(p["verses"]):
                        el = supp.get(f"temporal:{tkey}:{fkey}:verses:{vi}")
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
                        tn += sum(1 for x in vs if x)
                    else:
                        tmisses.append((tkey, fkey + "/verses",
                                        p["verses"][0]["lat"][:60]))
            if entry:
                tout_dst.setdefault(tkey, {})[fkey] = entry
    # Post-pass: compose the deferred scripture pericopes with the
    # chapter-consensus line-shift (0 preferred when within noise).
    ch_choice = {}
    for key, d in ch_agg.items():
        top = max(d, key=d.get)
        if 0 in d and d[0] >= 0.9 * d[top]:
            top = 0
        ch_choice[key] = top
    if LESSONS:
        # Export the consensus for the missal readings importer — its
        # pericopes are too sparse to infer the drift on their own.
        shifts_path = ROOT / "spanish-translation" / \
            "ta_chapter_shifts.json"
        json.dump({f"{b} {c}": s
                   for (b, c), s in sorted(ch_choice.items())},
                  open(shifts_path, "w", encoding="utf-8"),
                  ensure_ascii=False, indent=0, sort_keys=True)
        print(f"chapter shifts exported: "
              f"{sum(1 for s in ch_choice.values() if s)} nonzero "
              f"of {len(ch_choice)}")
    for tkey, fkey, ref, out_lines, pairs in pending_lessons:
        lines = list(out_lines)
        tot = 0.0
        okk = True
        last_ln = None
        for num, lt, name, ch, v in pairs:
            shf = ch_choice.get((name, ch), 0)
            t_ = ta_text(name, ch, v, shf)
            if t_ is None:
                okk = False
                break
            tot += pair_score(lt, t_)
            lines.append(f"{num} {t_}")
            base = ta_index.get(name, {}).get(
                (ch, v + isr.VULGATE_SHIFTS.get((name, ch), 0)))
            last_ln = None if base is None else base + shf
            last_lt = lt
            lesson_shift_stats[shf] = lesson_shift_stats.get(shf, 0) + 1
        # The Vulgate sometimes merges what the module splits (KJV
        # division): when the final verse's Spanish runs well short of
        # its Latin and the next module line is a lowercase
        # continuation, pull it in.
        if okk and last_ln is not None and lines:
            appended = 0
            while appended < 2:
                nxt = ta_line_text(last_ln + 1)
                if not nxt or not nxt[0].islower():
                    break
                if len(lines[-1].split(" ", 1)[1]) >= \
                        0.75 * len(last_lt):
                    break
                lines[-1] = lines[-1] + " " + nxt
                last_ln += 1
                appended += 1
        dst = sout if tkey in sanctoral else tout
        if okk and pairs and tot / len(pairs) >= 0.30:
            dst.setdefault(tkey, {})[fkey] = {"eng": nfc("\n".join(lines))}
            tn += 1
            continue
        # Constant-shift alignment failed — the module merges/splits the
        # occasional verse mid-chapter. Local DP: pick one module line
        # per verse from a small window, strictly increasing, maximizing
        # the cognate fit.
        opts_per = []
        for num, lt, name, ch, v in pairs:
            b = ta_index.get(name, {}).get((ch, v))
            opts = []
            if b is not None:
                for dd in range(-5, 6):
                    t_ = ta_line_text(b + dd)
                    if t_:
                        opts.append((b + dd, t_, pair_score(lt, t_)))
            if not opts:
                opts_per = None
                break
            opts_per.append(opts)
        best_lines = None
        if opts_per:
            dp = [(o[2], None, oi) for oi, o in enumerate(opts_per[0])]
            tables = [dp]
            for pi in range(1, len(opts_per)):
                cur = []
                for oi, (ln, t_, sc) in enumerate(opts_per[pi]):
                    best_prev = None
                    for pj, (psc, _pb, poi) in enumerate(tables[-1]):
                        if opts_per[pi - 1][poi][0] < ln and \
                                (best_prev is None or
                                 psc > tables[-1][best_prev][0]):
                            best_prev = pj
                    if best_prev is None:
                        cur.append((-1e9, None, oi))
                    else:
                        cur.append((tables[-1][best_prev][0] + sc,
                                    best_prev, oi))
                tables.append(cur)
            end = max(range(len(tables[-1])),
                      key=lambda i: tables[-1][i][0])
            total = tables[-1][end][0]
            if total / len(pairs) >= 0.35:
                sel = []
                i = end
                for pi in range(len(tables) - 1, -1, -1):
                    sc_, prev, oi = tables[pi][i]
                    sel.append(oi)
                    i = prev if prev is not None else 0
                sel.reverse()
                best_lines = [opts_per[pi][oi][1]
                              for pi, oi in enumerate(sel)]
        if best_lines:
            lines = list(out_lines)
            for (num, lt, name, ch, v), t_ in zip(pairs, best_lines):
                lines.append(f"{num} {t_}")
            dst.setdefault(tkey, {})[fkey] = {"eng": nfc("\n".join(lines))}
            lesson_shift_stats["dp"] = lesson_shift_stats.get("dp", 0) + 1
            tn += 1
        else:
            tmisses.append((tkey, fkey, "SCRIPT " + (ref or "?") +
                            f" score={tot / max(1, len(pairs)):.2f}"))

    TEMPORAL_OUT.write_text(json.dumps(tout, ensure_ascii=False, indent=1,
                                       sort_keys=True) + "\n",
                            encoding="utf-8")
    SANCTORAL_OUT.write_text(json.dumps(sout, ensure_ascii=False,
                                        indent=1, sort_keys=True) + "\n",
                             encoding="utf-8")
    sn = sum(1 for v in sout.values() for o in v.values()
             for f, x in o.items()
             if f != "verses"
             for _ in ([1] if isinstance(x, str) else []))
    sv = sum(1 for v in sout.values() for o in v.values()
             for l in (o.get("verses") or []) if l)
    print(f"sanctoral: wrote {sum(len(v) for v in sout.values())} parts "
          f"({sn + sv} fields)")
    # ---- the seasonal hymns (hymns_seasonal.json): traditional verse
    # translations from the hymn table; the app's <br>-within-stanza /
    # blank-line-between-stanza structure is mirrored.
    hymns = json.load(open(ROOT / "Introibo/Resources/"
                           "hymns_seasonal.json"))
    # The app carries the pre-Urban-VIII texts for a few seasonal hymns
    # ("Vox clara" where DO's default is "En clara vox") — the Espanol
    # verse translations cover the hymn either way; reach them by the
    # season-named section when the incipit key misses.
    SEASON_HYMN_SECTIONS = {
        ("advent", "hymnus_laudes"): "Hymnus Adv Laudes",
        ("advent", "hymnus_vespera"): "Hymnus Adv Vespera",
        ("lent", "hymnus_laudes"): "Hymnus Quad Laudes",
        ("passion", "hymnus_laudes"): "Hymnus Quad5 Laudes",
        ("easter", "hymnus_laudes"): "Hymnus Pasch Laudes",
    }

    def named_hymn_text(name):
        raw = espanol_named.get(
            ("Psalterium/Special/Major Special.txt", name))
        if not raw:
            return None
        txt = "\n".join(
            "" if l.strip() == "_" else clean_line(l)
            for l in raw if not l.strip().startswith("!"))
        return re.sub(r"\n{3,}", "\n\n", txt).strip() or None

    hymn_out = {}
    hymn_misses = []
    hymn_n = 0
    for season in sorted(hymns):
        for fkey, p in sorted(hymns[season].items()):
            if not isinstance(p, dict):
                continue
            entry = {}
            if p.get("eng"):
                skey = f"hymns:{season}:{fkey}:eng"
                lat = p.get("lat") or ""
                first = clean_line(lat.split("<br>")[0].split("\n")[0])
                t = supp.get(skey)
                if t is None and p.get("type") == "hymn":
                    t = hymn_map.get(fold(first))
                    if t is None:
                        name = SEASON_HYMN_SECTIONS.get((season, fkey))
                        if name:
                            t = named_hymn_text(name)
                    if t is not None:
                        stanzas = [s.strip() for s in t.split("\n\n")
                                   if s.strip()]
                        t = "\n\n".join(
                            "<br>".join(l for l in s.split("\n") if l)
                            for s in stanzas)
                if t is None:
                    flat = clean_line(lat.replace("<br>", " "))
                    t = find_line(flat) or find_block(flat)
                if t:
                    entry["eng"] = nfc(t)
                    hymn_n += 1
                else:
                    hymn_misses.append((season, fkey, first[:60]))
            if p.get("antiphonEng") and p.get("antiphonLat"):
                ta = supp.get(f"hymns:{season}:{fkey}:antiphonEng") \
                    or find_line(clean_line(p["antiphonLat"]))
                if ta:
                    entry["antiphonEng"] = nfc(ta)
                    hymn_n += 1
                else:
                    hymn_misses.append((season, fkey + "/antiphon",
                                        p["antiphonLat"][:60]))
            if entry:
                hymn_out.setdefault(season, {})[fkey] = entry
    HYMNS_OUT.write_text(json.dumps(hymn_out, ensure_ascii=False,
                                    indent=1, sort_keys=True) + "\n",
                         encoding="utf-8")
    print(f"hymns: wrote {hymn_n} fields")
    if hymn_misses:
        print(f"HYMN MISSES {len(hymn_misses)}:")
        for m in hymn_misses:
            print("   ", m)

    print(f"temporal: wrote {sum(len(v) for v in tout.values())} parts "
          f"({tn} fields)")
    if LESSONS and lesson_shift_stats:
        print(f"lesson line-shifts chosen: {lesson_shift_stats}")
    if tmisses:
        print(f"TEMPORAL MISSES {len(tmisses)}:")
        for m in tmisses[:80]:
            print("   ", m)
        if len(tmisses) > 80:
            print(f"    … and {len(tmisses) - 80} more")
        mpath = arg("--miss-out")
        if mpath:
            json.dump(tmisses, open(mpath, "w"), ensure_ascii=False,
                      indent=0)


if __name__ == "__main__":
    main()
