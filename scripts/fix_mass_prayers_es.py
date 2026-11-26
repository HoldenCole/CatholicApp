#!/usr/bin/env python3
"""The Spanish of the saints' Mass prayers that fix_mass_prayers.py put
right, from the app's own Spanish.

After fix_mass_prayers.py a prayer's Latin may be a different text from the
one its Spanish (spanish-translation/missal_propers_es.json) translates. The
Spanish of each such prayer is rebuilt line by line from the Spanish the
Missal already gives the same Latin elsewhere:

1. the same Latin line in another Mass (a prayer of the Commons, a
   conclusion) -> that Spanish line, the commonest where they vary;
2. the same prayer of the Commons with another saint's name -> that Spanish
   with this saint's name: each Latin "N." line of DO's Commons is a
   pattern, the Spanish of one Mass that uses it becomes the Spanish
   pattern (its saint's Spanish name back to "N."), and the saints' Spanish
   names come from office_names_es.json and from the lines that already
   pair a name in both languages.

A prayer whose every line is found takes the new Spanish; one that is not
loses its Spanish (and shows the English) and is listed, so that a wrong
translation is never left beside a corrected Latin.

Run after fix_mass_prayers.py:
  python3 scripts/fix_mass_prayers_es.py --before <missal_sanctoral.json before the fix> --do <DO checkout> [--dry-run]
  python3 scripts/sync_spanish_assets.py
"""
import difflib
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MISSAL = ROOT / "android/app/src/main/assets/missal_sanctoral.json"
ES = ROOT / "spanish-translation/missal_propers_es.json"
NAMES = ROOT / "spanish-translation/office_names_es.json"
FIELDS = ("oratio", "secreta", "postcommunio", "graduale")
UNNAMED = Counter()

# Saints' names in the corrected prayers that office_names_es.json lacks:
# Latin case form -> the Spanish name.
NAMES_EXTRA = {
    "Joánnis Baptístæ": "Juan Bautista", "Joánnes Chrysóstomus": "Juan Crisóstomo",
    "Joánnis Chrysóstomi": "Juan Crisóstomo", "Petrus Chrysólogus": "Pedro Crisólogo",
    "Petri Chrysólogi": "Pedro Crisólogo", "Andréæ Corsíni": "Andrés Corsino", "Andréa": "Andrés",
    "Antoníno": "Antonino", "Antónius": "Antonio", "Augustíni": "Agustín", "Augustínus": "Agustín",
    "Benedíctus": "Benito", "Bernárdi": "Bernardo", "Bernárdus": "Bernardo", "Blásio": "Blas",
    "Bonaventúræ": "Buenaventura", "Bonifátio": "Bonifacio", "Brunóne": "Bruno", "Cajum": "Cayo",
    "Canúto": "Canuto", "Carólo": "Carlos", "Cletum": "Cleto", "Cypriáno": "Cipriano",
    "Dídaco": "Diego", "Eusébio": "Eusebio", "Fabiáni": "Fabián", "Fabiáno": "Fabián",
    "Felicitátis": "Felicidad", "Felíce": "Félix", "Felícis": "Félix", "Francísci": "Francisco",
    "Francísco": "Francisco", "Francíscus": "Francisco", "Gervásio": "Gervasio",
    "Gregório": "Gregorio", "Guliélmius": "Guillermo", "Ignátio": "Ignacio", "Januário": "Jenaro",
    "Joánne": "Juan", "Justína": "Justina", "Lauréntius": "Lorenzo", "Libório": "Liborio",
    "Marcellínum": "Marcelino", "Maurus": "Mauro", "Nabóris": "Nabor", "Nicoláo": "Nicolás",
    "Norbérto": "Norberto", "Patrício": "Patricio", "Paulíno": "Paulino", "Perpétuæ": "Perpetua",
    "Petro": "Pedro", "Petrus": "Pedro", "Philíppo": "Felipe", "Pio": "Pío", "Plácido": "Plácido",
    "Polycárpo": "Policarpo", "Protásio": "Protasio", "Respício": "Respicio",
    "Romuáldus": "Romualdo", "Sabbas": "Sabas", "Sebastiáni": "Sebastián", "Sebastiáno": "Sebastián",
    "Simeóne": "Simeón", "Sotérem": "Sotero", "Symphorósa": "Sinforosa", "Nympha": "Ninfa",
    "Thomas": "Tomás", "Timothei": "Timoteo", "Timotheo": "Timoteo", "Tito": "Tito",
    "Toríbio": "Toribio", "Tryphóne": "Trifón", "Ubáldo": "Ubaldo", "Urbáni": "Urbano",
    "Úrsula": "Úrsula", "Ursula": "Úrsula", "Ursulæ": "Úrsula", "Vincéntio": "Vicente", "Vitále": "Vital",
    "Sóciis ejus": "sus Compañeros", "Sociórum ejus": "sus Compañeros", "fíliis ejus": "sus hijos",
    "Sociárum": "sus Compañeras", "Sociábus": "sus Compañeras", "Antónii Maríæ": "Antonio María",
    "Matthǽi": "Mateo", "Matthíæ": "Matías", "Jacóbi": "Santiago", "Thomæ": "Tomás",
    "Lauréntio": "Lorenzo", "Sabínæ": "Sabina", "Agrícola": "Agrícola", "Urbáno": "Urbano",
    "Leónem": "León", "Dámasum": "Dámaso", "Silvéstrum": "Silvestre", "Marcum": "Marcos",
    "Emerentiánæ": "Emerenciana", "Emerentiána": "Emerenciana", "Dorótheæ": "Dorotea",
    "Doróthea": "Dorotea", "Christínæ": "Cristina", "Christína": "Cristina", "Bibiánæ": "Bibiana",
    "Bibiána": "Bibiana", "Simeónis": "Simeón", "Ignátii": "Ignacio", "Timothei": "Timoteo",
    "Perpétuæ": "Perpetua", "Felicitátis": "Felicidad", "Hilárion": "Hilarión",
    "Telésphorum": "Telesforo", "Anicétum": "Aniceto", "Urbánum": "Urbano", "Silvérium": "Silverio",
    "Stéphanum": "Esteban", "Zephyrínum": "Ceferino", "Evarístum": "Evaristo", "Martínum": "Martín",
    "Cleméntem": "Clemente", "Melchíadem": "Melquíades", "Hygínum": "Higinio", "Lúcium": "Lucio",
    "Eleuthérium": "Eleuterio", "Joánnem": "Juan", "Felícem": "Félix", "Pium": "Pío", "Linum": "Lino",
    "Pontiánum": "Ponciano",
}

# Spanish of the Commons' prayers that no Mass of the app had in Spanish
# before (the corrected Latin brought them in): hand translations, in the
# Missal's own wording for the same formulas. Latin pattern -> Spanish.
HAND = {
    "Sacris altáribus, Dómine, hóstias superpósitas sanctus N. Abbas, quǽsumus, in salútem nobis proveníre depóscat.":
        "Te rogamos, Señor, que tu santo Abad N. alcance que las ofrendas puestas sobre tus sagrados altares nos aprovechen para la salvación.",
    "Sacris altáribus, Dómine, hóstias superpósitas sanctus N., quǽsumus, in salútem nobis proveníre depóscat.":
        "Te rogamos, Señor, que san N. alcance que las ofrendas puestas sobre tus sagrados altares nos aprovechen para la salvación.",
    "Prótegat nos, Dómine, cum tui perceptióne sacraménti beátus N. Abbas, pro nobis intercedéndo: ut et conversatiónis ejus experiámur insígnia, et intercessiónis percipiámus suffrágia.":
        "Protéjanos, Señor, junto con la recepción de tu sacramento, tu santo Abad N., intercediendo por nosotros: para que experimentemos los frutos de su vida y recibamos el auxilio de su intercesión.",
    "Prótegat nos, Dómine, cum tui perceptióne sacraménti beátus N., pro nobis intercedéndo: ut et conversatiónis ejus experiámur insígnia, et intercessiónis percipiámus suffrágia.":
        "Protéjanos, Señor, junto con la recepción de tu sacramento, san N., intercediendo por nosotros: para que experimentemos los frutos de su vida y recibamos el auxilio de su intercesión.",
    "Infirmitátem nostram réspice, omnípotens Deus: et, quia pondus própriæ actiónis gravat, beatórum Mártyrum tuórum N. et N. intercéssio gloriósa nos prótegat.":
        "Mira nuestra flaqueza, oh Dios omnipotente: y, pues nos agobia el peso de nuestras propias obras, protéjanos la gloriosa intercesión de tus santos Mártires N. y N.",
    "Hóstias tibi, Dómine, beatórum Mártyrum tuórum N. et N. dicátas méritis, benígnus assúme: et ad perpétuum nobis tríbue proveníre subsídium.":
        "Recibe benigno, Señor, las ofrendas dedicadas a los méritos de tus santos Mártires N. y N.: y haz que nos aprovechen para perpetuo auxilio.",
    "Hóstias tibi, Dómine, beáti N. Mártyris tui atque Pontíficis dicátas méritis, benígnus assúme: et ad perpétuum nobis tríbue proveníre subsídium.":
        "Recibe benigno, Señor, las ofrendas dedicadas a los méritos de tu santo Mártir y Obispo N.: y haz que nos aprovechen para perpetuo auxilio.",
    "Hóstias tibi, Dómine, beátæ N. Vírginis et Mártyris tuæ dicátas méritis, benígnus assúme: et ad perpétuum nobis tríbue proveníre subsídium.":
        "Recibe benigno, Señor, las ofrendas dedicadas a los méritos de tu santa Virgen y Mártir N.: y haz que nos aprovechen para perpetuo auxilio.",
    "Refécti participatióne múneris sacri, quǽsumus, Dómine, Deus noster: ut, cujus exséquimur cultum, intercedéntibus sanctis Martýribus tuis N. et N., sentiámus efféctum.":
        "Alimentados con la participación del don sagrado, te rogamos, Señor Dios nuestro: que, por la intercesión de tus santos Mártires N. y N., experimentemos el efecto del culto que celebramos.",
    "Refécti participatióne múneris sacri, quǽsumus, Dómine, Deus noster: ut, cujus exséquimur cultum, intercedénte beáto N. Mártyre tuo atque Pontífice, sentiámus efféctum.":
        "Alimentados con la participación del don sagrado, te rogamos, Señor Dios nuestro: que, por la intercesión de tu santo Mártir y Obispo N., experimentemos el efecto del culto que celebramos.",
    "Divíni múneris largitáte satiáti, quǽsumus, Dómine, Deus noster: ut, intercedénte beáta N. Vírgine et Mártyre tua, in ejus semper participatióne vivámus.":
        "Saciados con la largueza del don divino, te rogamos, Señor Dios nuestro: que, por la intercesión de tu santa Virgen y Mártir N., vivamos siempre de su participación.",
    "Apostólici reveréntia cúlminis offeréntes tibi sacra mystéria, Dómine, quǽsumus: ut beáti N. Apóstoli tui suffrágiis, cujus natalícia prævenímus; plebs tua semper et sua vota deprómat, et desideráta percípiat.":
        "Al ofrecerte, Señor, estos sagrados misterios con reverencia a la dignidad apostólica, te rogamos: que, por los sufragios de tu santo Apóstol N., cuya fiesta anticipamos, tu pueblo te presente siempre sus votos y alcance lo que desea.",
    "Apostólici reveréntia cúlminis offeréntes tibi sacra mystéria, Dómine, quǽsumus: ut beáti N. Apóstoli tui et Evangelístæ suffrágiis, cujus natalícia prævenímus; plebs tua semper et sua vota deprómat, et desideráta percípiat.":
        "Al ofrecerte, Señor, estos sagrados misterios con reverencia a la dignidad apostólica, te rogamos: que, por los sufragios de tu santo Apóstol y Evangelista N., cuya fiesta anticipamos, tu pueblo te presente siempre sus votos y alcance lo que desea.",
    "Sancti Apóstoli tui N., quǽsumus. Dómine, supplicatióne placátus: et veniam nobis tríbue, et remédia sempitérna concéde.":
        "Aplacado, Señor, te rogamos, por la súplica de tu santo Apóstol N., concédenos el perdón y los remedios eternos.",
    "Sancti Apóstoli tui et Evangelístæ N., quǽsumus. Dómine, supplicatióne placátus: et veniam nobis tríbue, et remédia sempitérna concéde.":
        "Aplacado, Señor, te rogamos, por la súplica de tu santo Apóstol y Evangelista N., concédenos el perdón y los remedios eternos.",
    "Da, quǽsumus, omnípotens Deus: ut beáti N. Apóstoli tui et Evangelístæ, quam prævenimus, veneránda solémnitas, et devotiónem nobis áugeat et salútem.":
        "Concédenos, oh Dios omnipotente: que la venerable solemnidad de tu santo Apóstol y Evangelista N., que anticipamos, aumente en nosotros la devoción y la salvación.",
    "Gregem tuum, Pastor ætérne, placátus inténde: et, per beátum N. Summum Pontíficem, perpétua protectióne custódi; quem totíus Ecclésiæ præstitísti esse pastórem.":
        "Mira aplacado a tu rebaño, Pastor eterno: y guárdalo con tu continua protección, por intercesión de tu santo Sumo Pontífice N., a quien constituiste pastor de toda la Iglesia.",
    "Gregem tuum, Pastor ætérne, placátus inténde: et, per beátum N. Mártyrem tuum atque Summum Pontíficem, perpétua protectióne custódi; quem totíus Ecclésiæ præstitísti esse pastórem.":
        "Mira aplacado a tu rebaño, Pastor eterno: y guárdalo con tu continua protección, por intercesión de tu santo Mártir y Sumo Pontífice N., a quien constituiste pastor de toda la Iglesia.",
    "Gregem tuum, Pastor ætérne, placátus inténde: et per beátos N. et N. Mártyres tuos atque Summos Pontífices perpétua protectióne custódi; quos totíus Ecclésiæ præstitísti esse pastóres.":
        "Mira aplacado a tu rebaño, Pastor eterno: y guárdalo con tu continua protección, por intercesión de tus santos Mártires y Sumos Pontífices N. y N., a quienes constituiste pastores de toda la Iglesia.",
    "Da nobis, quǽsumus, Dómine Deus noster, sanctárum Mártyrum tuárum N. et N. palmas incessábili devotióne venerári: ut quas digna mente non póssumus celebráre, humílibus saltem frequentémus obséquiis.":
        "Concédenos, Señor Dios nuestro, venerar con incesante devoción las palmas de tus santas Mártires N. y N.: para que, a quienes no podemos celebrar con la dignidad debida, las honremos al menos con humildes obsequios.",
    "Inténde, quǽsumus, Dómine, múnera altáribus tuis pro sanctárum Mártyrum tuárum N. et N. festivitáte propósita: ut, sicut per hæc beáta mystéria illis glóriam contulísti; ita nobis indulgéntiam largiáris.":
        "Mira, Señor, te rogamos, los dones puestos sobre tus altares en la festividad de tus santas Mártires N. y N.: para que, así como por estos sagrados misterios les diste la gloria, así nos concedas a nosotros el perdón.",
    "Sancti N. Confessóris tui atque Doctóris nobis, Dómine, pia non desit orátio: quæ et múnera nostra concíliet; et tuam nobis indulgéntiam semper obtíneat.":
        "No nos falte, Señor, la piadosa oración de tu santo Confesor y Doctor N.: que haga aceptos nuestros dones, y nos alcance siempre tu indulgencia.",
    "Ut nobis, Dómine, tua sacrifícia dent salútem: beátus N. Conféssor tuus et Doctor egrégius, quǽsumus, precátor accédat.":
        "Para que tus sacrificios, Señor, nos den la salvación: interceda por nosotros, te rogamos, el bienaventurado N., tu Confesor y Doctor egregio.",
    "Múnera, quæ tibi, Dómine, lætántes offérimus, súscipe benígnus, et præsta: ut, intercedénte beáto N., Ecclésia tua et fídei integritáte lætétur, et témporum tranquillitáte semper exúltet.":
        "Recibe benigno, Señor, los dones que gozosos te ofrecemos, y concede: que, por la intercesión de san N., tu Iglesia se alegre en la integridad de la fe y se goce siempre en la tranquilidad de los tiempos.",
    "Multíplica, quǽsumus, Dómine, in Ecclésia tua spíritum grátiæ, quem dedísti: ut beáti N. Mártyris tui atque Summi Pontíficis deprecatióne nec pastóri obœdiéntia gregis nec gregi desit cura pastóris.":
        "Multiplica, Señor, te rogamos, en tu Iglesia el espíritu de gracia que le diste: para que, por la súplica de tu santo Mártir y Sumo Pontífice N., ni al pastor le falte la obediencia del rebaño, ni al rebaño el cuidado del pastor.",
    "Ecclésiam tuam, Deus, beáti N. Confessóris tui atque Doctóris sollémnitas votiva lætíficet: ut spirituálibus semper muniátur auxíliis et gáudiis pérfrui mereátur ætérnis.":
        "Alegre a tu Iglesia, oh Dios, la solemnidad votiva de tu santo Confesor y Doctor N.: para que sea siempre fortalecida con auxilios espirituales y merezca gozar de las alegrías eternas.",
    "Divínis, Dómine, munéribus satiáti: quǽsumus; ut, beáti N. Confessóris tui atque Doctóris méritis et intercessióne, salutáris sacrifícii sentiámus efféctum.":
        "Saciados, Señor, con los dones divinos, te rogamos: que, por los méritos e intercesión de tu santo Confesor y Doctor N., experimentemos el efecto del sacrificio saludable.",
    "Oblátis, quǽsumus, Dómine, placáre munéribus: et, intercedéntibus sanctis Martýribus tuis N. et N., a cunctis nos defénde perículis.":
        "Aplácate, Señor, te rogamos, con los dones ofrecidos: y, por la intercesión de tus santos Mártires N. y N., defiéndenos de todos los peligros.",
    "Hæc nos commúnio, Dómine, purget a crímine: et, intercedéntibus sanctis Martýribus tuis N. et N., coeléstis remédii fáciat esse consórtes.":
        "Que esta comunión, Señor, nos limpie de pecado: y, por la intercesión de tus santos Mártires N. y N., nos haga partícipes del remedio celestial.",
    "Præsta, quǽsumus, Dómine: ut, sicut nos sanctórum Martyrum tuórum N. et N. natalítia celebránda non desérunt; ita júgiter suffrágiis comiténtur.":
        "Concédenos, Señor, te rogamos: que, así como nunca nos falta la fiesta de tus santos Mártires N. y N. para celebrarla, así nos acompañen siempre con sus sufragios.",
    "Múnera plebis tuæ, quǽsumus, Dómine, sanctórum Mártyrum tuórum N. et N. fiant grata suffrágiis: et, quorum triúmphis tuo nómini offeruntur, ipsorum digna perficiantur et méritis.":
        "Te suplicamos, Señor, que por la intercesión de tus santos mártires N. y N., te sean agradables las ofrendas de tu pueblo y se hagan dignas de ti por los méritos de aquellos por cuyo triunfo se ofrecen a tu nombre.",
    "Præsta nobis, quǽsumus, Dómine: intercedéntibus sanctis Martýribus tuis N. et N.; ut, quod ore contíngimus, pura mente capiámus.":
        "Concédenos, Señor, te rogamos, por la intercesión de tus santos Mártires N. y N.: que lo que tocamos con los labios, lo recibamos con alma pura.",
    "Præsta nobis, quǽsumus, Dómine: intercedéntibus sanctis Martýribus tuis N., N. et N.; ut, quod ore contíngimus, pura mente capiámus.":
        "Concédenos, Señor, te rogamos, por la intercesión de tus santos Mártires N., N. y N.: que lo que tocamos con los labios, lo recibamos con alma pura.",
    "Præsta nobis, quǽsumus, Dómine, intercedéntibus sanctis Virgínibus et Martýribus tuis N. et N.: ut, quod ore contíngimus, pura mente capiámus.":
        "Concédenos, Señor, te rogamos, por la intercesión de tus santas Vírgenes y Mártires N. y N.: que lo que tocamos con los labios, lo recibamos con alma pura.",
    "Hóstias, Dómine, quas tibi offérimus, propítius súscipe: et, intercedénte beáto N. Mártyre tuo, víncula peccatórum nostrórum absólve.":
        "Recibe propicio, Señor, las ofrendas que te presentamos: y, por la intercesión de tu santo Mártir N., desata los lazos de nuestros pecados.",
    "Deus, qui inter cétera poténtiæ tuæ mirácula étiam in sexu frágili victóriam martýrii contulísti: concéde propítius; ut, qui beátæ N. Mártyris tuæ natalítia cólimus, per ejus ad te exémpla gradiámur.":
        "Oh Dios, que entre las demás maravillas de tu poder concediste también al sexo frágil la victoria del martirio: concédenos propicio que, quienes celebramos el nacimiento al cielo de tu santa Mártir N., caminemos hacia ti por sus ejemplos.",
    "Sancti N. Confessóris tui atque Pontíficis, quǽsumus, Dómine, ánnua sollémnitas pietáti tuæ nos reddat accéptos: ut, per hæc piæ placatiónis offícia, et illum beáta retribútio comitétur, et nobis grátiæ tuæ dona concíliet.":
        "Que la solemnidad anual de tu santo Confesor y Obispo N., te rogamos, Señor, nos haga aceptos a tu piedad: para que, por estos oficios de piadosa propiciación, a él le acompañe la bienaventurada recompensa, y a nosotros nos alcance los dones de tu gracia.",
    "Deus, fidélium remunerátor animárum: præsta; ut, beáti N. Confessóris tui atque Pontíficis, cujus venerándam celebrámus festivitátem, précibus indulgéntiam consequámur.":
        "Oh Dios, remunerador de las almas fieles: concédenos que, por las oraciones de tu santo Confesor y Obispo N., cuya venerable fiesta celebramos, alcancemos el perdón.",
    "Caritátis víctima, quam immolántes offérimus, sit nobis, Dómine, te miseránte, propitiábilis: et, beáti N. précibus et méritis, ad obtinéndum patiéntiæ et caritátis augméntum, éfficax et salutáris.":
        "La víctima de caridad que inmolamos y ofrecemos nos sea propicia, Señor, por tu misericordia: y, por las oraciones y méritos de san N., eficaz y saludable para alcanzar aumento de paciencia y de caridad.",
    "Crescat in nobis, Dómine, tuæ pietátis efféctus salutáris: ut, cælésti pábulo nutríti, ætérnæ vitæ corónam, beáto N. intercedénte, felíciter assequámur.":
        "Crezca en nosotros, Señor, el efecto saludable de tu piedad: para que, alimentados con el manjar celestial, alcancemos felizmente, por la intercesión de san N., la corona de la vida eterna.",
    "(sed feria 7 nisi rubrica 1955 nisi rubrica 196)": "(sed feria 7 nisi rubrica 1955 nisi rubrica 196)",
}

# Whole fields: St Praxedes's Gradual (the Missal's Spanish of Ps 44).
FIELD_HAND = {
    ("07-21", "graduale"): "Amaste la justicia y aborreciste la iniquidad.\n"
                           "V. Por eso te ungió Dios, tu Dios, con óleo de alegría. Aleluya, aleluya.\n"
                           "V. Con tu gallardía y tu hermosura avanza, marcha prósperamente y reina. Aleluya.",
}


def nfc(s):
    return unicodedata.normalize("NFC", s or "")


def fold(t):
    t = unicodedata.normalize("NFD", nfc(t))
    t = "".join(c for c in t if unicodedata.category(c) != "Mn").lower()
    t = t.replace("æ", "ae").replace("œ", "ae").replace("oe", "ae").replace("j", "i").replace("v", "u")
    t = re.sub(r"ci(?=[aeiou])", "ti", t)
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9 ]+", " ", t)).strip()


def lines(t):
    return [l for l in nfc(t).split("\n") if l.strip()]


def commune_templates(do):
    """Folded Latin lines of DO's Commons that carry "N." -> regex."""
    out = {}
    for p in sorted((Path(do) / "web/www/horas/Latin/Commune").glob("*.txt")):
        for l in p.read_text(encoding="utf-8", errors="replace").split("\n"):
            l = re.sub(r"^v\.\s*", "", l.strip())
            if not re.search(r"\bN\.", l) or len(l) < 30:
                continue
            k = fold(l)
            words = k.split(" ")
            out[k] = re.compile("^" + " ".join(r"(.+?)" if w == "n" else re.escape(w) for w in words) + "$")
    return out


def main():
    before = json.load(open(sys.argv[sys.argv.index("--before") + 1], encoding="utf-8"))
    do = sys.argv[sys.argv.index("--do") + 1]
    missal = json.load(open(MISSAL, encoding="utf-8"))
    es_text = ES.read_text(encoding="utf-8")
    es = json.loads(es_text)
    templates = commune_templates(do)
    by_first = defaultdict(list)
    for k, rx in templates.items():
        by_first[" ".join(k.split(" ")[:2])].append((k, rx))

    def match(lat):
        f = fold(lat)
        for k, rx in by_first.get(" ".join(f.split(" ")[:2]), []):
            m = rx.match(f)
            if m:
                return k, m.groups()
        return None, None

    changed = [(k, f) for k in missal for f in FIELDS
               if isinstance(missal[k].get(f), dict)
               and missal[k][f].get("lat") != (before.get(k, {}).get(f) or {}).get("lat")]
    changed_set = set(changed)

    # Line pairs from the prayers left as they were (Latin and Spanish agree).
    pairs = defaultdict(Counter)
    for k, e in missal.items():
        for f in FIELDS:
            v, s = e.get(f), es.get(k, {}).get(f)
            if not isinstance(v, dict) or not s or (k, f) in changed_set:
                continue
            ll, sl = lines(v["lat"]), lines(s)
            if len(ll) == len(sl):
                for a, b in zip(ll, sl):
                    pairs[fold(a)][b] += 1

    names = {fold(k): v for k, v in json.load(open(NAMES, encoding="utf-8")).items()}
    names.update({fold(k): v for k, v in NAMES_EXTRA.items()})
    # the Commons' own "N." pairs with the Spanish "N.": their lines serve
    # as patterns for every saint's Mass that uses them
    names["n"] = "N."
    # Spanish patterns of the Commons' lines, and more names, learned in turns
    es_tpl = defaultdict(Counter)
    for _ in range(3):
        for lat_f, c in pairs.items():
            k, groups = match(lat_f)
            if not k:
                continue
            for sp, n in c.items():
                got = [names.get(fold(g)) for g in groups]
                if None not in got and all(g in sp for g in got):
                    t = sp
                    for g in got:
                        t = t.replace(g, "N.", 1)
                    es_tpl[k][t] += n
                elif es_tpl.get(k) and len(groups) == 1:
                    # a known pattern names the saint in Spanish
                    t = es_tpl[k].most_common(1)[0][0]
                    rx = re.compile("^" + re.escape(t).replace(r"N\.", "(.+?)") + "$")
                    m = rx.match(sp)
                    if m:
                        names.setdefault(fold(groups[0]), m.group(1))

    # 3. the same line with another saint's name, wherever the Missal has
    # one: the line's skeleton (every known name form -> "N") and that
    # Mass's Spanish with its saint's Spanish name swapped for this one's.
    name_rx = re.compile(r"\b(" + "|".join(sorted((re.escape(k) for k in names), key=len, reverse=True)) + r")\b")

    def skeleton(f):
        found = []
        sk = name_rx.sub(lambda m: (found.append(m.group(1)), "N")[1], f)
        return sk, found

    siblings = defaultdict(list)
    for lat_f, c in pairs.items():
        sk, found = skeleton(lat_f)
        if found:
            for sp, _ in c.most_common():
                if "(" not in sp or "(" in lat_f:
                    siblings[sk].append((found, sp))
                    break
    UNNAMED.clear()

    hand = []
    for lat_t, es_t in HAND.items():
        words = fold(lat_t).split(" ")
        hand.append((re.compile("^" + " ".join(r"(.+?)" if w == "n" else re.escape(w) for w in words) + "$"), es_t))

    def by_hand(lat):
        f = fold(lat)
        for rx, es_t in hand:
            m = rx.match(f)
            if not m:
                continue
            got = [names.get(g) for g in m.groups()]
            if None in got:
                UNNAMED.update(g for g, x in zip(m.groups(), got) if x is None)
                continue
            t = es_t
            for g in got:
                t = t.replace("N.", "\0", 1)
            for g in got:
                t = t.replace("\0", g, 1)
            return t
        return None

    def ok(o, l):
        """No placeholder or bracketed variant that the Latin line lacks."""
        return (("(" in o) <= ("(" in l)) and (bool(re.search(r"\bN\.", o)) <= bool(re.search(r"\bN\.", l)))

    def spanish(lat, own=None):
        for o in candidates(lat, own):
            if o and ok(o, lat):
                return o
        return None

    def candidates(lat, own=None):
        # the field's own Spanish line, where only a spelling or the case
        # of the name changed in the Latin
        if own:
            sk = skeleton(fold(lat))[0]
            for ol, osp in own:
                osk = skeleton(fold(ol))[0]
                if osk == sk or difflib.SequenceMatcher(None, osk, sk).ratio() > 0.98:
                    yield osp
        for sp, _ in (pairs.get(fold(lat)) or Counter()).most_common():
            yield sp
        yield by_hand(lat)
        sk, found = skeleton(fold(lat))
        for other, sp in siblings.get(sk, []):
            if len(other) != len(found):
                continue
            t = sp
            fits = True
            for o_, n_ in zip(other, found):
                if names[o_] not in t:
                    fits = False
                    break
                t = t.replace(names[o_], "\0", 1)
            if fits:
                for n_ in found:
                    t = t.replace("\0", names[n_], 1)
                yield t
        k, groups = match(lat)
        if k and es_tpl.get(k):
            got = [names.get(fold(g)) for g in groups]
            if None in got:
                UNNAMED.update(g for g, x in zip(groups, got) if x is None)
                return
            t = es_tpl[k].most_common(1)[0][0]
            for g in got:
                t = t.replace("N.", g, 1)
            yield t

    done, dropped = [], []
    for k, f in changed:
        if (k, f) in FIELD_HAND:
            es.setdefault(k, {})[f] = FIELD_HAND[(k, f)]
            done.append((k, f))
            continue
        own = []
        ob, os_ = (before.get(k, {}).get(f) or {}).get("lat", ""), es.get(k, {}).get(f, "")
        if len(lines(ob)) == len(lines(os_)):
            own = list(zip(lines(ob), lines(os_)))
        lat_lines = lines(missal[k][f]["lat"])
        out = [spanish(l, own) for l in lat_lines]

        if None in out:
            if f in es.get(k, {}):
                del es[k][f]
            miss = next(l for l, o in zip(lines(missal[k][f]["lat"]), out) if o is None)
            dropped.append((k, f, miss[:100]))
        else:
            es.setdefault(k, {})[f] = "\n".join(out)
            done.append((k, f))
    # an older Spanish line that kept the Commons' "N."
    for (k, f), (old, new) in {("08-09cc", "postcommunio"): ("tu santo mártir N.,", "tu santo mártir Román,")}.items():
        if isinstance(es.get(k, {}).get(f), str):
            es[k][f] = es[k][f].replace(old, new)
    print(f"spanish: {len(done)} prayers rebuilt, {len(dropped)} left to the English")
    for x in dropped:
        print("  english", *x, sep=" | ")
    for n, c in UNNAMED.most_common():
        print("  unnamed", n, c, sep=" | ")
    # The Office's popes' collects lost their stray second prayer in
    # fix_mass_prayers.py; their Spanish loses it too.
    office = json.load(open(ROOT / "android/app/src/main/assets/sanctoral_propers.json", encoding="utf-8"))
    oes_path = ROOT / "spanish-translation/sanctoral_propers_es.json"
    oes_text = oes_path.read_text(encoding="utf-8")
    oes = json.loads(oes_text)
    trimmed = 0
    for k, e in oes.items():
        v, lat = e.get("oratio"), (office.get(k, {}).get("oratio") or {}).get("lat", "")
        if isinstance(v, dict) and lat.startswith("Gregem tuum") and "\n" not in lat \
                and v.get("eng", "").startswith("Mira aplacado a tu rebaño") and "\n" in v["eng"]:
            v["eng"] = v["eng"].split("\n")[0]
            trimmed += 1
    print(f"spanish office: {trimmed} popes' collects trimmed")
    if "--dry-run" in sys.argv:
        return
    oindent = 2 if oes_text.startswith('{\n  "') else 1
    oes_path.write_text(json.dumps(oes, ensure_ascii=False, indent=oindent) + ("\n" if oes_text.endswith("\n") else ""), encoding="utf-8")
    indent = 2 if es_text.startswith('{\n  "') else 1
    ES.write_text(json.dumps(es, ensure_ascii=False, indent=indent) + ("\n" if es_text.endswith("\n") else ""), encoding="utf-8")


if __name__ == "__main__":
    main()
