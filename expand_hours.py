#!/usr/bin/env python3
"""
Expand all truncated psalms, hymns, and canticles in the Divine Office hours.json.

This script replaces every truncated text with the complete liturgical text
from the 1962 Breviary (Breviarium Romanum). Latin uses traditional
Ecclesiastical accents. English follows the Douay-Rheims tradition.
"""

import json
import copy
import os

INPUT  = "/home/user/CatholicApp/Introibo/Resources/hours.json"
OUTPUT = INPUT  # overwrite in place

# ──────────────────────────────────────────────────────────────────────
# COMPLETE PSALM TEXTS
# ──────────────────────────────────────────────────────────────────────

PSALM_94 = [
    {"lat": "Veníte, exsultémus Dómino: jubilémus Deo, salutári nostro:",
     "eng": "Come, let us praise the Lord with joy: let us joyfully sing to God our Saviour."},
    {"lat": "Præoccupémus fáciem ejus in confessióne, et in psalmis jubilémus ei.",
     "eng": "Let us come before His presence with thanksgiving, and make a joyful noise to Him with psalms."},
    {"lat": "Quóniam Deus magnus Dóminus, et Rex magnus super omnes deos.",
     "eng": "For the Lord is a great God, and a great King above all gods."},
    {"lat": "Quóniam non repéllet Dóminus plebem suam: quia in manu ejus sunt omnes fines terræ, et altitúdines móntium ipse cónspicit.",
     "eng": "For the Lord will not cast off His people: for in His hand are all the ends of the earth, and the heights of the mountains are His."},
    {"lat": "Quóniam ipsíus est mare, et ipse fecit illud, et áridam fundavérunt manus ejus.",
     "eng": "For the sea is His, and He made it, and His hands formed the dry land."},
    {"lat": "Veníte, adorémus, et procidámus ante Deum: plorémus coram Dómino, qui fecit nos:",
     "eng": "Come, let us adore and fall down: and weep before the Lord that made us:"},
    {"lat": "Quia ipse est Dóminus Deus noster: nos autem pópulus ejus, et oves páscuæ ejus.",
     "eng": "For He is the Lord our God: and we are the people of His pasture, and the sheep of His hand."},
    {"lat": "Hódie si vocem ejus audiéritis, nolíte obduráre corda vestra:",
     "eng": "Today if you shall hear His voice, harden not your hearts:"},
    {"lat": "Sicut in exacerbatióne secúndum diem tentatiónis in desérto: ubi tentavérunt me patres vestri, probavérunt et vidérunt ópera mea.",
     "eng": "As in the provocation, according to the day of temptation in the wilderness: where your fathers tempted Me, they proved Me, and saw My works."},
    {"lat": "Quadragínta annis próximus fui generatióni huic, et dixi: Semper hi errant corde; ipsi vero non cognovérunt vias meas:",
     "eng": "Forty years long was I offended with that generation, and I said: These always err in heart; and they have not known My ways:"},
    {"lat": "Quibus jurávi in ira mea: Si introíbunt in réquiem meam.",
     "eng": "To whom I swore in My wrath: that they shall not enter into My rest."},
]

PSALM_1 = [
    {"lat": "Beátus vir qui non ábiit in consílio impiórum, et in via peccatórum non stetit, et in cáthedra pestiléntiæ non sedit.",
     "eng": "Blessed is the man who hath not walked in the counsel of the ungodly, nor stood in the way of sinners, nor sat in the chair of pestilence."},
    {"lat": "Sed in lege Dómini volúntas ejus, et in lege ejus meditábitur die ac nocte.",
     "eng": "But his will is in the law of the Lord, and on His law he shall meditate day and night."},
    {"lat": "Et erit tamquam lignum quod plantátum est secus decúrsus aquárum, quod fructum suum dabit in témpore suo.",
     "eng": "And he shall be like a tree which is planted near the running waters, which shall bring forth its fruit in due season."},
    {"lat": "Et fólium ejus non défluet; et ómnia quæcúmque fáciet prosperabúntur.",
     "eng": "And his leaf shall not fall off; and all whatsoever he shall do shall prosper."},
    {"lat": "Non sic ímpii, non sic; sed tamquam pulvis quem próicit ventus a fácie terræ.",
     "eng": "Not so the wicked, not so; but like the dust which the wind driveth from the face of the earth."},
    {"lat": "Ideo non resúrgent ímpii in judício, neque peccatóres in concílio justórum.",
     "eng": "Therefore the wicked shall not rise again in judgment, nor sinners in the council of the just."},
    {"lat": "Quóniam novit Dóminus viam justórum; et iter impiórum períbit.",
     "eng": "For the Lord knoweth the way of the just; and the way of the wicked shall perish."},
]

PSALM_2 = [
    {"lat": "Quare fremuérunt gentes, et pópuli meditáti sunt inánia?",
     "eng": "Why have the Gentiles raged, and the people devised vain things?"},
    {"lat": "Astitérunt reges terræ, et príncipes convenérunt in unum advérsus Dóminum et advérsus Christum ejus.",
     "eng": "The kings of the earth stood up, and the princes met together, against the Lord and against His Christ."},
    {"lat": "Dirumpámus víncula eórum, et projiciámus a nobis jugum ipsórum.",
     "eng": "Let us break their bonds asunder, and let us cast away their yoke from us."},
    {"lat": "Qui hábitat in cælis irridébit eos, et Dóminus subsannábit eos.",
     "eng": "He that dwelleth in heaven shall laugh at them, and the Lord shall deride them."},
    {"lat": "Tunc loquétur ad eos in ira sua, et in furóre suo conturbábit eos.",
     "eng": "Then shall He speak to them in His anger, and trouble them in His rage."},
    {"lat": "Ego autem constitútus sum Rex ab eo super Sion, montem sanctum ejus, prǽdicans præcéptum ejus.",
     "eng": "But I am appointed King by Him over Sion, His holy mountain, preaching His commandment."},
    {"lat": "Dóminus dixit ad me: Fílius meus es tu; ego hódie génui te.",
     "eng": "The Lord hath said to Me: Thou art My Son, this day have I begotten Thee."},
    {"lat": "Postula a me, et dabo tibi gentes hereditátem tuam, et possessiónem tuam términos terræ.",
     "eng": "Ask of Me, and I will give Thee the Gentiles for Thy inheritance, and the utmost parts of the earth for Thy possession."},
    {"lat": "Reges eos in virga férrea, et tamquam vas fíguli confrínges eos.",
     "eng": "Thou shalt rule them with a rod of iron, and shalt break them in pieces like a potter's vessel."},
    {"lat": "Et nunc, reges, intellígite; erudímini, qui judicátis terram.",
     "eng": "And now, O ye kings, understand; receive instruction, you that judge the earth."},
    {"lat": "Servíte Dómino in timóre, et exsultáte ei cum tremóre.",
     "eng": "Serve ye the Lord with fear, and rejoice unto Him with trembling."},
    {"lat": "Apprehéndite disciplínam, nequándo irascátur Dóminus, et pereátis de via justa.",
     "eng": "Embrace discipline, lest at any time the Lord be angry, and you perish from the just way."},
    {"lat": "Cum exárserit in brevi ira ejus, beáti omnes qui confídunt in eo.",
     "eng": "When His wrath shall be kindled in a short time, blessed are all they that trust in Him."},
]

# Matins additional psalms (Nocturn I: Ps 1, 2, 3; Nocturn II: Ps 7, 8, 9; Nocturn III: Ps 17-i, 17-ii, 17-iii)
# For Sunday Matins of the ferial psalter per the 1962 rubrics

PSALM_3 = [
    {"lat": "Dómine, quid multiplicáti sunt qui tríbulant me? Multi insúrgunt advérsum me.",
     "eng": "Why, O Lord, are they multiplied that afflict me? Many are they who rise up against me."},
    {"lat": "Multi dicunt ánimæ meæ: Non est salus ipsi in Deo ejus.",
     "eng": "Many say to my soul: There is no salvation for him in his God."},
    {"lat": "Tu autem, Dómine, suscéptor meus es, glória mea, et exáltans caput meum.",
     "eng": "But Thou, O Lord, art my protector, my glory, and the lifter up of my head."},
    {"lat": "Voce mea ad Dóminum clamávi, et exaudívit me de monte sancto suo.",
     "eng": "I have cried to the Lord with my voice, and He hath heard me from His holy hill."},
    {"lat": "Ego dormívi et soporátus sum; et exsurréxi, quia Dóminus suscépit me.",
     "eng": "I have slept and taken my rest; and I have risen up, because the Lord hath protected me."},
    {"lat": "Non timébo míllia pópuli circumdántis me. Exsúrge, Dómine; salvum me fac, Deus meus.",
     "eng": "I will not fear thousands of the people surrounding me. Arise, O Lord; save me, O my God."},
    {"lat": "Quóniam tu percussísti omnes adversántes mihi sine causa; dentes peccatórum contrivísti.",
     "eng": "For Thou hast struck all them who are my adversaries without cause; Thou hast broken the teeth of sinners."},
    {"lat": "Dómini est salus; et super pópulum tuum benedíctio tua.",
     "eng": "Salvation is of the Lord; and Thy blessing is upon Thy people."},
]

PSALM_6 = [
    {"lat": "Dómine, ne in furóre tuo árguas me, neque in ira tua corrípias me.",
     "eng": "O Lord, rebuke me not in Thy indignation, nor chastise me in Thy wrath."},
    {"lat": "Miserére mei, Dómine, quóniam infírmus sum; sana me, Dómine, quóniam conturbáta sunt ossa mea.",
     "eng": "Have mercy on me, O Lord, for I am weak; heal me, O Lord, for my bones are troubled."},
    {"lat": "Et ánima mea turbáta est valde; sed tu, Dómine, úsquequo?",
     "eng": "And my soul is troubled exceedingly; but Thou, O Lord, how long?"},
    {"lat": "Convértere, Dómine, et éripe ánimam meam; salvum me fac propter misericórdiam tuam.",
     "eng": "Turn to me, O Lord, and deliver my soul; O save me for Thy mercy's sake."},
    {"lat": "Quóniam non est in morte qui memor sit tui; in inférno autem quis confitébitur tibi?",
     "eng": "For there is no one in death that is mindful of Thee; and who shall confess to Thee in hell?"},
    {"lat": "Laborávi in gémitu meo; lavábo per síngulas noctes lectum meum; lácrimis meis stratum meum rigábo.",
     "eng": "I have laboured in my groanings; every night I will wash my bed; I will water my couch with my tears."},
    {"lat": "Turbátus est a furóre óculus meus; inveterávi inter omnes inimícos meos.",
     "eng": "My eye is troubled through indignation; I have grown old amongst all my enemies."},
    {"lat": "Discédite a me, omnes qui operámini iniquitátem, quóniam exaudívit Dóminus vocem fletus mei.",
     "eng": "Depart from me, all ye workers of iniquity; for the Lord hath heard the voice of my weeping."},
    {"lat": "Exaudívit Dóminus deprecatiónem meam; Dóminus oratiónem meam suscépit.",
     "eng": "The Lord hath heard my supplication; the Lord hath received my prayer."},
    {"lat": "Erubéscant et conturbéntur veheménter omnes inimíci mei; convertántur et erubéscant valde velóciter.",
     "eng": "Let all my enemies be ashamed and be very much troubled; let them be turned back and be ashamed very speedily."},
]

PSALM_7 = [
    {"lat": "Dómine Deus meus, in te sperávi; salvum me fac ex ómnibus persequéntibus me, et líbera me.",
     "eng": "O Lord my God, in Thee have I put my trust; save me from all them that persecute me, and deliver me."},
    {"lat": "Nequándo rápiat ut leo ánimam meam, dum non est qui rédimat, neque qui salvum fáciat.",
     "eng": "Lest at any time he seize upon my soul like a lion, while there is no one to redeem me, nor to save."},
    {"lat": "Dómine Deus meus, si feci istud, si est iníquitas in mánibus meis:",
     "eng": "O Lord my God, if I have done this thing, if there be iniquity in my hands:"},
    {"lat": "Si réddidi retribuéntibus mihi mala, décidam mérito ab inimícis meis inánis.",
     "eng": "If I have rendered to them that repaid me evils, let me deservedly fall empty before my enemies."},
    {"lat": "Persequátur inimícus ánimam meam, et comprehéndat, et concúlcet in terra vitam meam, et glóriam meam in púlverem dedúcat.",
     "eng": "Let the enemy pursue my soul, and take it, and tread down my life on the earth, and bring down my glory to the dust."},
    {"lat": "Exsúrge, Dómine, in ira tua, et exaltáre in fínibus inimicórum meórum.",
     "eng": "Arise, O Lord, in Thy anger, and be Thou exalted in the borders of my enemies."},
    {"lat": "Et exsúrge, Dómine Deus meus, in præcépto quod mandásti, et synagóga populórum circúmdabit te.",
     "eng": "And arise, O Lord my God, in the precept which Thou hast commanded, and a congregation of people shall surround Thee."},
    {"lat": "Et propter hanc in altum regrédere. Dóminus júdicat pópulos.",
     "eng": "And for their sakes return Thou on high. The Lord judgeth the people."},
    {"lat": "Júdica me, Dómine, secúndum justítiam meam, et secúndum innocéntiam meam super me.",
     "eng": "Judge me, O Lord, according to my justice, and according to my innocence in me."},
    {"lat": "Consumétur nequítia peccatórum, et díriges justum, scrutans corda et renes, Deus.",
     "eng": "The wickedness of sinners shall be brought to nought; and Thou shalt direct the just, the searcher of hearts and reins, O God."},
    {"lat": "Justum adjutórium meum a Dómino, qui salvos facit rectos corde.",
     "eng": "Just is my help from the Lord, who saveth the upright of heart."},
    {"lat": "Deus judex justus, fortis et pátiens; numquid iráscitur per síngulos dies?",
     "eng": "God is a just judge, strong and patient; is He angry every day?"},
    {"lat": "Nisi convérsi fuéritis, gládium suum vibrábit; arcum suum teténdit et parávit illum.",
     "eng": "Except you will be converted, He will brandish His sword; He hath bent His bow and made it ready."},
    {"lat": "Et in eo parávit vasa mortis; sagíttas suas ardéntibus effécit.",
     "eng": "And in it He hath prepared the instruments of death; He hath made ready His arrows for them that burn."},
    {"lat": "Ecce partúriit injustítiam; concépit dolórem, et péperit iniquitátem.",
     "eng": "Behold he hath been in labour with injustice; he hath conceived sorrow and brought forth iniquity."},
    {"lat": "Lacum apéruit et effódit eum; et íncidit in fóveam quam fecit.",
     "eng": "He hath opened a pit and dug it; and he is fallen into the hole he made."},
    {"lat": "Convertétur dolor ejus in caput ejus, et in vérticem ipsíus iníquitas ejus descéndet.",
     "eng": "His sorrow shall be turned on his own head; and his iniquity shall come down upon his crown."},
    {"lat": "Confitébor Dómino secúndum justítiam ejus, et psallam nómini Dómini altíssimi.",
     "eng": "I will give glory to the Lord according to His justice, and will sing to the name of the Lord the Most High."},
]

PSALM_8 = [
    {"lat": "Dómine, Dóminus noster, quam admirábile est nomen tuum in univérsa terra!",
     "eng": "O Lord our Lord, how admirable is Thy name in the whole earth!"},
    {"lat": "Quóniam eleváta est magnificéntia tua super cælos.",
     "eng": "For Thy magnificence is elevated above the heavens."},
    {"lat": "Ex ore infántium et lacténtium perfecísti laudem propter inimícos tuos, ut déstruas inimícum et ultórem.",
     "eng": "Out of the mouth of infants and of sucklings Thou hast perfected praise, because of Thy enemies, that Thou mayst destroy the enemy and the avenger."},
    {"lat": "Quóniam vidébo cælos tuos, ópera digitórum tuórum, lunam et stellas quæ tu fundásti.",
     "eng": "For I will behold Thy heavens, the works of Thy fingers, the moon and the stars which Thou hast founded."},
    {"lat": "Quid est homo, quod memor es ejus? Aut fílius hóminis, quóniam vísitas eum?",
     "eng": "What is man that Thou art mindful of him? Or the son of man that Thou visitest him?"},
    {"lat": "Minuísti eum paulo minus ab Ángelis; glória et honóre coronásti eum, et constituísti eum super ópera mánuum tuárum.",
     "eng": "Thou hast made him a little less than the Angels; Thou hast crowned him with glory and honour, and hast set him over the works of Thy hands."},
    {"lat": "Omnia subjecísti sub pédibus ejus: oves et boves univérsas, ínsuper et pécora campi.",
     "eng": "Thou hast subjected all things under his feet: all sheep and oxen, moreover the beasts also of the fields."},
    {"lat": "Vólucres cæli et pisces maris, qui perámbulant sémitas maris.",
     "eng": "The birds of the air and the fishes of the sea, that pass through the paths of the sea."},
    {"lat": "Dómine, Dóminus noster, quam admirábile est nomen tuum in univérsa terra!",
     "eng": "O Lord our Lord, how admirable is Thy name in all the earth!"},
]

PSALM_9_I = [
    {"lat": "Confitébor tibi, Dómine, in toto corde meo; narrábo ómnia mirabília tua.",
     "eng": "I will give praise to Thee, O Lord, with my whole heart; I will relate all Thy wonders."},
    {"lat": "Lætábor et exsultábo in te; psallam nómini tuo, Altíssime.",
     "eng": "I will be glad and rejoice in Thee; I will sing to Thy name, O Thou Most High."},
    {"lat": "In converténdo inimícum meum retrórsum; infirmabúntur et períbunt a fácie tua.",
     "eng": "When my enemy shall be turned back; they shall be weakened and perish before Thy face."},
    {"lat": "Quóniam fecísti judícium meum et causam meam; sedísti super thronum, qui júdicas justítiam.",
     "eng": "For Thou hast maintained my judgment and my cause; Thou hast sat on the throne, who judgest justice."},
    {"lat": "Increpásti gentes, et périit ímpius; nomen eórum delésti in ætérnum et in sǽculum sǽculi.",
     "eng": "Thou hast rebuked the Gentiles, and the wicked one hath perished; Thou hast blotted out their name for ever and ever."},
    {"lat": "Inimíci defecérunt frámeæ in finem, et civitátes eórum destruxísti.",
     "eng": "The swords of the enemy have failed unto the end, and their cities Thou hast destroyed."},
    {"lat": "Périit memória eórum cum sónitu; et Dóminus in ætérnum pérmanet.",
     "eng": "Their memory hath perished with a noise; but the Lord remaineth for ever."},
    {"lat": "Parávit in judício thronum suum, et ipse judicábit orbem terræ in æquitáte, judicábit pópulos in justítia.",
     "eng": "He hath prepared His throne in judgment; and He shall judge the world in equity, He shall judge the people in justice."},
    {"lat": "Et factus est Dóminus refúgium páuperi, adjútor in opportunitátibus, in tribulatióne.",
     "eng": "And the Lord is become a refuge for the poor, a helper in due time in tribulation."},
    {"lat": "Et sperent in te qui novérunt nomen tuum, quóniam non dereliquísti quæréntes te, Dómine.",
     "eng": "And let them trust in Thee who know Thy name; for Thou hast not forsaken them that seek Thee, O Lord."},
    {"lat": "Psállite Dómino qui hábitat in Sion; annuntiáte inter gentes stúdia ejus.",
     "eng": "Sing ye to the Lord, who dwelleth in Sion; declare His ways among the Gentiles."},
    {"lat": "Quóniam requírens sánguinem eórum recordátus est; non est oblítus clamórem páuperum.",
     "eng": "For requiring their blood He hath remembered them; He hath not forgotten the cry of the poor."},
    {"lat": "Miserére mei, Dómine; vide humilitátem meam de inimícis meis.",
     "eng": "Have mercy on me, O Lord; see my humiliation which I suffer from my enemies."},
    {"lat": "Qui exáltas me de portis mortis, ut annúntiem omnes laudatiónes tuas in portis fíliæ Sion.",
     "eng": "Thou that liftest me up from the gates of death, that I may declare all Thy praises in the gates of the daughter of Sion."},
    {"lat": "Exsultábo in salutári tuo. Infíxæ sunt gentes in intéritu quem fecérunt.",
     "eng": "I will rejoice in Thy salvation. The Gentiles have stuck fast in the destruction which they have prepared."},
    {"lat": "In láqueo isto quem abscondérunt, comprehénsus est pes eórum.",
     "eng": "Their foot hath been taken in the very snare which they hid."},
    {"lat": "Cognoscétur Dóminus judícia fáciens; in opéribus mánuum suárum comprehénsus est peccátor.",
     "eng": "The Lord shall be known when He executeth judgments; the sinner hath been caught in the works of his own hands."},
    {"lat": "Convertántur peccatóres in inférnum, omnes gentes quæ obliviscúntur Deum.",
     "eng": "The wicked shall be turned into hell, all the nations that forget God."},
    {"lat": "Quóniam non in finem oblívio erit páuperis; patiéntia páuperum non períbit in finem.",
     "eng": "For the poor man shall not be forgotten to the end; the patience of the poor shall not perish for ever."},
    {"lat": "Exsúrge, Dómine, non confortétur homo; judicéntur gentes in conspéctu tuo.",
     "eng": "Arise, O Lord, let not man be strengthened; let the Gentiles be judged in Thy sight."},
    {"lat": "Constítue, Dómine, legislatórem super eos, ut sciant gentes quóniam hómines sunt.",
     "eng": "Appoint, O Lord, a lawgiver over them, that the Gentiles may know themselves to be but men."},
]

# ── Psalm 62 (Lauds) ──
PSALM_62 = [
    {"lat": "Deus, Deus meus, ad te de luce vígilo.",
     "eng": "O God, my God, to Thee do I watch at break of day."},
    {"lat": "Sitívit in te ánima mea, quam multiplíciter tibi caro mea.",
     "eng": "For Thee my soul hath thirsted; for Thee my flesh, O how many ways!"},
    {"lat": "In terra desérta, et ínvia, et inaquósa: sic in sancto appárui tibi, ut vidérem virtútem tuam et glóriam tuam.",
     "eng": "In a desert land, and where there is no way and no water: so in the sanctuary have I come before Thee, to see Thy power and Thy glory."},
    {"lat": "Quóniam mélior est misericórdia tua super vitas: lábia mea laudábunt te.",
     "eng": "For Thy mercy is better than lives: Thee my lips shall praise."},
    {"lat": "Sic benedícam te in vita mea, et in nómine tuo levábo manus meas.",
     "eng": "Thus will I bless Thee all my life long; and in Thy name I will lift up my hands."},
    {"lat": "Sicut ádipe et pinguédine repleátur ánima mea, et lábiis exsultatiónis laudábit os meum.",
     "eng": "Let my soul be filled as with marrow and fatness, and my mouth shall praise Thee with joyful lips."},
    {"lat": "Si memor fui tui super stratum meum, in matutínis meditábor in te:",
     "eng": "If I have remembered Thee upon my bed, I will meditate on Thee in the morning:"},
    {"lat": "Quia fuísti adjútor meus, et in velaménto alárum tuárum exsultábo.",
     "eng": "Because Thou hast been my helper, and I will rejoice under the covert of Thy wings."},
    {"lat": "Adhǽsit ánima mea post te; me suscépit déxtera tua.",
     "eng": "My soul hath clung close to Thee; Thy right hand hath received me."},
    {"lat": "Ipsi vero in vanum quæsiérunt ánimam meam; introíbunt in inferióra terræ:",
     "eng": "But they have sought my soul in vain; they shall go into the lower parts of the earth:"},
    {"lat": "Tradéntur in manus gládii; partes vúlpium erunt.",
     "eng": "They shall be delivered into the hands of the sword; they shall be the portions of foxes."},
    {"lat": "Rex vero lætábitur in Deo; laudabúntur omnes qui jurant in eo, quia obstrúctum est os loquéntium iníqua.",
     "eng": "But the king shall rejoice in God; all they shall be praised that swear by Him, because the mouth is stopped of them that speak wicked things."},
]

# ── Psalm 66 (Lauds) ──
PSALM_66 = [
    {"lat": "Deus misereátur nostri, et benedícat nobis; illúminet vultum suum super nos, et misereátur nostri.",
     "eng": "May God have mercy on us, and bless us; may He cause the light of His countenance to shine upon us, and may He have mercy on us."},
    {"lat": "Ut cognoscámus in terra viam tuam, in ómnibus géntibus salutáre tuum.",
     "eng": "That we may know Thy way upon earth, Thy salvation in all nations."},
    {"lat": "Confiteántur tibi pópuli, Deus; confiteántur tibi pópuli omnes.",
     "eng": "Let the peoples praise Thee, O God; let all the peoples praise Thee."},
    {"lat": "Læténtur et exsúltent gentes, quóniam júdicas pópulos in æquitáte, et gentes in terra dírigis.",
     "eng": "Let the nations be glad and rejoice, for Thou judgest the peoples with justice, and directest the nations upon earth."},
    {"lat": "Confiteántur tibi pópuli, Deus, confiteántur tibi pópuli omnes: terra dedit fructum suum.",
     "eng": "Let the peoples praise Thee, O God, let all the peoples praise Thee: the earth hath yielded her fruit."},
    {"lat": "Benedícat nos Deus, Deus noster, benedícat nos Deus; et métuant eum omnes fines terræ.",
     "eng": "May God, our God, bless us, may God bless us; and may all the ends of the earth fear Him."},
]

# ── Psalm 117 (Prime) ──
PSALM_117 = [
    {"lat": "Confitémini Dómino, quóniam bonus, quóniam in sǽculum misericórdia ejus.",
     "eng": "Give praise to the Lord, for He is good, for His mercy endureth for ever."},
    {"lat": "Dicat nunc Israel, quóniam bonus, quóniam in sǽculum misericórdia ejus.",
     "eng": "Let Israel now say that He is good, that His mercy endureth for ever."},
    {"lat": "Dicat nunc domus Aaron, quóniam in sǽculum misericórdia ejus.",
     "eng": "Let the house of Aaron now say, that His mercy endureth for ever."},
    {"lat": "Dicant nunc qui timent Dóminum, quóniam in sǽculum misericórdia ejus.",
     "eng": "Let them that fear the Lord now say, that His mercy endureth for ever."},
    {"lat": "De tribulatióne invocávi Dóminum, et exaudívit me in latitúdine Dóminus.",
     "eng": "In my trouble I called upon the Lord, and the Lord heard me and enlarged me."},
    {"lat": "Dóminus mihi adjútor; non timébo quid fáciat mihi homo.",
     "eng": "The Lord is my helper; I will not fear what man can do unto me."},
    {"lat": "Dóminus mihi adjútor, et ego despíciam inimícos meos.",
     "eng": "The Lord is my helper, and I will look over my enemies."},
    {"lat": "Bonum est confídere in Dómino, quam confídere in hómine.",
     "eng": "It is good to confide in the Lord, rather than to have confidence in man."},
    {"lat": "Bonum est speráre in Dómino, quam speráre in princípibus.",
     "eng": "It is good to trust in the Lord, rather than to trust in princes."},
    {"lat": "Omnes gentes circuiérunt me, et in nómine Dómini quia ultus sum in eos.",
     "eng": "All nations compassed me about, and in the name of the Lord I have been revenged on them."},
    {"lat": "Circumdántes circumdedérunt me, et in nómine Dómini quia ultus sum in eos.",
     "eng": "Surrounding me they compassed me about, and in the name of the Lord I have been revenged on them."},
    {"lat": "Circumdedérunt me sicut apes, et exarsérunt sicut ignis in spinis, et in nómine Dómini quia ultus sum in eos.",
     "eng": "They surrounded me like bees, and they burned like fire among thorns, and in the name of the Lord I was revenged on them."},
    {"lat": "Impúlsus, eversus sum ut cáderem, et Dóminus suscépit me.",
     "eng": "Being pushed I was overturned that I might fall, but the Lord supported me."},
    {"lat": "Fortitúdo mea et laus mea Dóminus, et factus est mihi in salútem.",
     "eng": "The Lord is my strength and my praise, and He is become my salvation."},
    {"lat": "Vox exsultatiónis et salútis in tabernáculis justórum.",
     "eng": "The voice of rejoicing and of salvation is in the tabernacles of the just."},
    {"lat": "Déxtera Dómini fecit virtútem; déxtera Dómini exaltávit me; déxtera Dómini fecit virtútem.",
     "eng": "The right hand of the Lord hath wrought strength; the right hand of the Lord hath exalted me; the right hand of the Lord hath wrought strength."},
    {"lat": "Non móriar sed vivam, et narrábo ópera Dómini.",
     "eng": "I shall not die, but live, and shall declare the works of the Lord."},
    {"lat": "Castigans castigávit me Dóminus, et morti non trádidit me.",
     "eng": "The Lord chastising hath chastised me, but He hath not delivered me over to death."},
    {"lat": "Aperíte mihi portas justítiæ; ingréssus in eas confitébor Dómino.",
     "eng": "Open ye to me the gates of justice; I will go into them, and give praise to the Lord."},
    {"lat": "Hæc porta Dómini; justi intrábunt in eam.",
     "eng": "This is the gate of the Lord; the just shall enter into it."},
    {"lat": "Confitébor tibi quóniam exaudísti me, et factus es mihi in salútem.",
     "eng": "I will give praise to Thee because Thou hast heard me, and art become my salvation."},
    {"lat": "Lápidem quem reprobavérunt ædificántes, hic factus est in caput ánguli.",
     "eng": "The stone which the builders rejected, the same is become the head of the corner."},
    {"lat": "A Dómino factum est istud, et est mirábile in óculis nostris.",
     "eng": "This is the Lord's doing, and it is wonderful in our eyes."},
    {"lat": "Hæc est dies quam fecit Dóminus; exsultémus et lætémur in ea.",
     "eng": "This is the day which the Lord hath made; let us be glad and rejoice therein."},
    {"lat": "O Dómine, salvum me fac; o Dómine, bene prosperáre.",
     "eng": "O Lord, save me; O Lord, give good success."},
    {"lat": "Benedíctus qui venit in nómine Dómini. Benedíximus vobis de domo Dómini.",
     "eng": "Blessed be he that cometh in the name of the Lord. We have blessed you out of the house of the Lord."},
    {"lat": "Deus Dóminus, et illúxit nobis. Constitúite diem sollémnem in condénsis usque ad cornu altáris.",
     "eng": "The Lord is God, and He hath shone upon us. Appoint a solemn day with shady boughs, even to the horn of the altar."},
    {"lat": "Deus meus es tu, et confitébor tibi; Deus meus es tu, et exaltábo te.",
     "eng": "Thou art my God, and I will praise Thee; Thou art my God, and I will exalt Thee."},
    {"lat": "Confitémini Dómino, quóniam bonus, quóniam in sǽculum misericórdia ejus.",
     "eng": "O praise ye the Lord, for He is good, for His mercy endureth for ever."},
]

# ── Psalm 53 (Prime) ──
PSALM_53 = [
    {"lat": "Deus, in nómine tuo salvum me fac: et in virtúte tua júdica me.",
     "eng": "Save me, O God, by Thy name, and judge me in Thy strength."},
    {"lat": "Deus, exáudi oratiónem meam: áuribus pércipe verba oris mei.",
     "eng": "O God, hear my prayer: give ear to the words of my mouth."},
    {"lat": "Quóniam aliéni insurrexérunt advérsum me, et fortes quæsiérunt ánimam meam: et non proposuérunt Deum ante conspéctum suum.",
     "eng": "For strangers have risen up against me, and the mighty have sought after my soul: and they have not set God before their eyes."},
    {"lat": "Ecce enim Deus ádjuvat me: et Dóminus suscéptor est ánimæ meæ.",
     "eng": "For behold God is my helper: and the Lord is the protector of my soul."},
    {"lat": "Avérte mala inimícis meis: et in veritáte tua dispérde illos.",
     "eng": "Turn back the evils upon my enemies: and cut them off in Thy truth."},
    {"lat": "Voluntárie sacrificábo tibi, et confitébor nómini tuo, Dómine: quóniam bonum est.",
     "eng": "I will freely sacrifice to Thee, and will give praise, O God, to Thy name: because it is good."},
    {"lat": "Quóniam ex omni tribulatióne eripuísti me: et super inimícos meos despéxit óculus meus.",
     "eng": "For Thou hast delivered me out of all trouble: and my eye hath looked down upon my enemies."},
]

# ── Psalm 118:1-8 (Terce) – Beáti immaculáti ──
PSALM_118_1_8 = [
    {"lat": "Beáti immaculáti in via, qui ámbulant in lege Dómini.",
     "eng": "Blessed are the undefiled in the way, who walk in the law of the Lord."},
    {"lat": "Beáti qui scrutántur testimónia ejus: in toto corde exquírunt eum.",
     "eng": "Blessed are they that search His testimonies: that seek Him with their whole heart."},
    {"lat": "Non enim qui operántur iniquitátem, in viis ejus ambulavérunt.",
     "eng": "For they that work iniquity, have not walked in His ways."},
    {"lat": "Tu mandásti mandáta tua custodíri nimis.",
     "eng": "Thou hast commanded Thy commandments to be kept most diligently."},
    {"lat": "Útinam dirigántur viæ meæ ad custodiéndas justificatiónes tuas!",
     "eng": "O that my ways may be directed to keep Thy justifications!"},
    {"lat": "Tunc non confúndar, cum perspéxero in ómnibus mandátis tuis.",
     "eng": "Then shall I not be confounded, when I shall look into all Thy commandments."},
    {"lat": "Confitébor tibi in directióne cordis, in eo quod dídici judícia justítiæ tuæ.",
     "eng": "I will praise Thee with uprightness of heart, when I shall have learned the judgments of Thy justice."},
    {"lat": "Justificatiónes tuas custódiam: non me derelínquas usquequáque.",
     "eng": "I will keep Thy justifications: O do not Thou utterly forsake me."},
]

# ── Psalm 118:33-40 (Terce) – Legem pone ──
PSALM_118_33_40 = [
    {"lat": "Legem pone mihi, Dómine, viam justificatiónum tuárum, et exquíram eam semper.",
     "eng": "Set before me for a law the way of Thy justifications, O Lord, and I will always seek after it."},
    {"lat": "Da mihi intelléctum, et scrutábor legem tuam, et custódiam illam in toto corde meo.",
     "eng": "Give me understanding, and I will search Thy law, and I will keep it with my whole heart."},
    {"lat": "Deduc me in sémitam mandatórum tuórum, quia ipsam vólui.",
     "eng": "Lead me into the path of Thy commandments, for this same I have desired."},
    {"lat": "Inclína cor meum in testimónia tua, et non in avarítiam.",
     "eng": "Incline my heart unto Thy testimonies, and not to covetousness."},
    {"lat": "Avérte óculos meos ne vídeant vanitátem: in via tua vivífica me.",
     "eng": "Turn away my eyes that they may not behold vanity: quicken me in Thy way."},
    {"lat": "Státue servo tuo elóquium tuum, in timóre tuo.",
     "eng": "Establish Thy word to Thy servant, in Thy fear."},
    {"lat": "Ámputa oppróbrium meum quod suspicátus sum: quia judícia tua jucúnda.",
     "eng": "Turn away my reproach which I have apprehended: for Thy judgments are delightful."},
    {"lat": "Ecce concupívi mandáta tua: in æquitáte tua vivífica me.",
     "eng": "Behold I have longed after Thy precepts: quicken me in Thy justice."},
]

# ── Psalm 118:41-48 (Terce) – Et véniat ──
PSALM_118_41_48 = [
    {"lat": "Et véniat super me misericórdia tua, Dómine; salutáre tuum secúndum elóquium tuum.",
     "eng": "Let Thy mercy also come upon me, O Lord; Thy salvation according to Thy word."},
    {"lat": "Et respondébo exprobrántibus mihi verbum, quia sperávi in sermónibus tuis.",
     "eng": "So shall I answer them that reproach me in anything, that I have trusted in Thy words."},
    {"lat": "Et ne áuferas de ore meo verbum veritátis usquequáque, quia in judíciis tuis supersperávi.",
     "eng": "And take not Thou the word of truth utterly out of my mouth, for in Thy words I have hoped exceedingly."},
    {"lat": "Et custódiam legem tuam semper, in sǽculum et in sǽculum sǽculi.",
     "eng": "So shall I always keep Thy law, for ever and ever."},
    {"lat": "Et ambulábam in latitúdine, quia mandáta tua exquisívi.",
     "eng": "And I walked at large, because I have sought after Thy commandments."},
    {"lat": "Et loquébar in testimóniis tuis in conspéctu regum, et non confundébar.",
     "eng": "And I spoke of Thy testimonies before kings, and I was not ashamed."},
    {"lat": "Et meditábar in mandátis tuis, quæ diléxi.",
     "eng": "And I meditated on Thy commandments, which I loved."},
    {"lat": "Et levávi manus meas ad mandáta tua quæ diléxi, et exercébar in justificatiónibus tuis.",
     "eng": "And I lifted up my hands to Thy commandments, which I loved, and I was exercised in Thy justifications."},
]

# ── Psalm 122 (Sext) ──
PSALM_122 = [
    {"lat": "Ad te levávi óculos meos, qui hábitas in cælis.",
     "eng": "To Thee have I lifted up my eyes, who dwellest in heaven."},
    {"lat": "Ecce sicut óculi servórum in mánibus dominórum suórum,",
     "eng": "Behold as the eyes of servants are on the hands of their masters,"},
    {"lat": "Sicut óculi ancíllæ in mánibus dóminæ suæ: ita óculi nostri ad Dóminum Deum nostrum, donec misereátur nostri.",
     "eng": "As the eyes of the handmaid are on the hands of her mistress: so are our eyes unto the Lord our God, until He have mercy on us."},
    {"lat": "Miserére nostri, Dómine, miserére nostri: quia multum repléti sumus despectióne.",
     "eng": "Have mercy on us, O Lord, have mercy on us: for we are greatly filled with contempt."},
    {"lat": "Quia multum repléta est ánima nostra; oppróbrium abundántibus, et despéctio supérbis.",
     "eng": "For our soul is greatly filled: we are a reproach to the rich, and contempt to the proud."},
]

# ── Psalm 123 (Sext) ──
PSALM_123 = [
    {"lat": "Nisi quia Dóminus erat in nobis, dicat nunc Israel:",
     "eng": "Unless the Lord had been in us, let Israel now say:"},
    {"lat": "Nisi quia Dóminus erat in nobis, cum exsúrgerent hómines in nos:",
     "eng": "Unless the Lord had been in us, when men rose up against us:"},
    {"lat": "Forte vivos deglutíssent nos:",
     "eng": "Perhaps they had swallowed us up alive:"},
    {"lat": "Cum irascerétur furor eórum in nos, fórsitan aqua absorbuísset nos.",
     "eng": "When their fury was enkindled against us, perhaps the water had swallowed us up."},
    {"lat": "Torréntem pertransívit ánima nostra: fórsitan pertransísset ánima nostra aquam intolerábilem.",
     "eng": "Our soul hath passed through a torrent: perhaps our soul had passed through a water insupportable."},
    {"lat": "Benedíctus Dóminus, qui non dedit nos in captiónem déntibus eórum.",
     "eng": "Blessed be the Lord, who hath not given us to be a prey to their teeth."},
    {"lat": "Anima nostra sicut passer erépta est de láqueo venántium:",
     "eng": "Our soul hath been delivered as a sparrow out of the snare of the fowlers:"},
    {"lat": "Láqueus contrítus est, et nos liberáti sumus.",
     "eng": "The snare is broken, and we are delivered."},
    {"lat": "Adjutórium nostrum in nómine Dómini, qui fecit cælum et terram.",
     "eng": "Our help is in the name of the Lord, who made heaven and earth."},
]

# ── Psalm 124 (Sext) ──
PSALM_124 = [
    {"lat": "Qui confídunt in Dómino, sicut mons Sion: non commovébitur in ætérnum, qui hábitat in Jerúsalem.",
     "eng": "They that trust in the Lord shall be as Mount Sion: he shall not be moved for ever that dwelleth in Jerusalem."},
    {"lat": "Montes in circúitu ejus: et Dóminus in circúitu pópuli sui, ex hoc nunc et usque in sǽculum.",
     "eng": "Mountains are round about it: so the Lord is round about His people, from henceforth now and for ever."},
    {"lat": "Quia non relínquet Dóminus virgam peccatórum super sortem justórum: ut non exténdant justi ad iniquitátem manus suas.",
     "eng": "For the Lord will not leave the rod of sinners upon the lot of the just: that the just may not stretch forth their hands to iniquity."},
    {"lat": "Benefac, Dómine, bonis, et rectis corde.",
     "eng": "Do good, O Lord, to those that are good, and to the upright of heart."},
    {"lat": "Declinátes autem in obligatiónes addúcet Dóminus cum operántibus iniquitátem: pax super Israel.",
     "eng": "But such as turn aside into bonds, the Lord shall lead out with the workers of iniquity: peace upon Israel."},
]

# ── Psalm 125 (None) ──
PSALM_125 = [
    {"lat": "In converténdo Dóminus captivitátem Sion, facti sumus sicut consoláti.",
     "eng": "When the Lord brought back the captivity of Sion, we became like men comforted."},
    {"lat": "Tunc replétum est gáudio os nostrum, et lingua nostra exsultatióne.",
     "eng": "Then was our mouth filled with gladness, and our tongue with joy."},
    {"lat": "Tunc dicent inter gentes: Magnificávit Dóminus fácere cum eis.",
     "eng": "Then shall they say among the Gentiles: The Lord hath done great things for them."},
    {"lat": "Magnificávit Dóminus fácere nobíscum: facti sumus lætántes.",
     "eng": "The Lord hath done great things for us: we are become joyful."},
    {"lat": "Convérte, Dómine, captivitátem nostram, sicut torrens in Austro.",
     "eng": "Turn again our captivity, O Lord, as a stream in the south."},
    {"lat": "Qui séminant in lácrimis, in exsultatióne metent.",
     "eng": "They that sow in tears shall reap in joy."},
    {"lat": "Eúntes ibant et flebant, mitténtes sémina sua.",
     "eng": "Going they went and wept, casting their seeds."},
    {"lat": "Veniéntes autem vénient cum exsultatióne, portántes manípulos suos.",
     "eng": "But coming they shall come with joyfulness, carrying their sheaves."},
]

# ── Psalm 126 (None) ──
PSALM_126 = [
    {"lat": "Nisi Dóminus ædificáverit domum, in vanum laboravérunt qui ǽdificant eam.",
     "eng": "Unless the Lord build the house, they labour in vain that build it."},
    {"lat": "Nisi Dóminus custodíerit civitátem, frustra vígilat qui custódit eam.",
     "eng": "Unless the Lord keep the city, he watcheth in vain that keepeth it."},
    {"lat": "Vanum est vobis ante lucem súrgere: súrgite postquam sedéritis, qui manducátis panem dolóris.",
     "eng": "It is vain for you to rise before light: rise ye after you have sitten, you that eat the bread of sorrow."},
    {"lat": "Cum déderit diléctis suis somnum: ecce heréditas Dómini, fílii; merces, fructus ventris.",
     "eng": "When He shall give sleep to His beloved: behold the inheritance of the Lord are children; the reward, the fruit of the womb."},
    {"lat": "Sicut sagíttæ in manu poténtis, ita fílii excussórum.",
     "eng": "As arrows in the hand of the mighty, so the children of them that have been shaken."},
    {"lat": "Beátus vir qui implévit desidérium suum ex ipsis: non confundétur cum loquétur inimícis suis in porta.",
     "eng": "Blessed is the man that hath filled the desire with them: he shall not be confounded when he shall speak to his enemies in the gate."},
]

# ── Psalm 127 (None) ──
PSALM_127 = [
    {"lat": "Beáti omnes qui timent Dóminum, qui ámbulant in viis ejus.",
     "eng": "Blessed are all they that fear the Lord, that walk in His ways."},
    {"lat": "Labóres mánuum tuárum quia manducábis: beátus es, et bene tibi erit.",
     "eng": "For thou shalt eat the labours of thy hands: blessed art thou, and it shall be well with thee."},
    {"lat": "Uxor tua sicut vitis abúndans in latéribus domus tuæ.",
     "eng": "Thy wife as a fruitful vine on the sides of thy house."},
    {"lat": "Fílii tui sicut novéllæ olivárum in circúitu mensæ tuæ.",
     "eng": "Thy children as olive plants round about thy table."},
    {"lat": "Ecce sic benedicétur homo qui timet Dóminum.",
     "eng": "Behold, thus shall the man be blessed that feareth the Lord."},
    {"lat": "Benedícat tibi Dóminus ex Sion: et vídeas bona Jerúsalem ómnibus diébus vitæ tuæ.",
     "eng": "May the Lord bless thee out of Sion: and mayst thou see the good things of Jerusalem all the days of thy life."},
    {"lat": "Et vídeas fílios filiórum tuórum: pacem super Israel.",
     "eng": "And mayst thou see thy children's children: peace upon Israel."},
]

# ── Psalm 109 (Vespers) ──
PSALM_109 = [
    {"lat": "Dixit Dóminus Dómino meo: Sede a dextris meis:",
     "eng": "The Lord said to my Lord: Sit Thou at My right hand:"},
    {"lat": "Donec ponam inimícos tuos, scabéllum pedum tuórum.",
     "eng": "Until I make Thy enemies Thy footstool."},
    {"lat": "Virgam virtútis tuæ emíttet Dóminus ex Sion: domináre in médio inimicórum tuórum.",
     "eng": "The Lord will send forth the sceptre of Thy power out of Sion: rule Thou in the midst of Thy enemies."},
    {"lat": "Tecum princípium in die virtútis tuæ in splendóribus sanctórum: ex útero ante lucíferum génui te.",
     "eng": "With Thee is the principality in the day of Thy strength, in the brightness of the saints: from the womb before the day star I begot Thee."},
    {"lat": "Jurávit Dóminus, et non pœnitébit eum: Tu es sacérdos in ætérnum secúndum órdinem Melchísedech.",
     "eng": "The Lord hath sworn, and He will not repent: Thou art a priest for ever according to the order of Melchisedech."},
    {"lat": "Dóminus a dextris tuis, confrégit in die iræ suæ reges.",
     "eng": "The Lord at Thy right hand hath broken kings in the day of His wrath."},
    {"lat": "Judicábit in natiónibus, implébit ruínas: conquassábit cápita in terra multórum.",
     "eng": "He shall judge among nations, He shall fill ruins: He shall crush the heads in the land of many."},
    {"lat": "De torrénte in via bibet: proptérea exaltábit caput.",
     "eng": "He shall drink of the torrent in the way: therefore shall He lift up the head."},
]

# ── Psalm 110 (Vespers) ──
PSALM_110 = [
    {"lat": "Confitébor tibi, Dómine, in toto corde meo, in consílio justórum et congregatióne.",
     "eng": "I will praise Thee, O Lord, with my whole heart, in the council of the just and in the congregation."},
    {"lat": "Magna ópera Dómini, exquisíta in omnes voluntátes ejus.",
     "eng": "Great are the works of the Lord, sought out according to all His wills."},
    {"lat": "Conféssio et magnificéntia opus ejus, et justítia ejus manet in sǽculum sǽculi.",
     "eng": "His work is praise and magnificence, and His justice continueth for ever and ever."},
    {"lat": "Memóriam fecit mirabílium suórum, miséricors et miserátor Dóminus: escam dedit timéntibus se.",
     "eng": "He hath made a remembrance of His wonderful works, being a merciful and gracious Lord: He hath given food to them that fear Him."},
    {"lat": "Memor erit in sǽculum testaménti sui: virtútem óperum suórum annuntiábit pópulo suo:",
     "eng": "He will be mindful for ever of His covenant: He will shew forth to His people the power of His works."},
    {"lat": "Ut det illis hereditátem géntium: ópera mánuum ejus véritas et judícium.",
     "eng": "That He may give them the inheritance of the Gentiles: the works of His hands are truth and judgment."},
    {"lat": "Fidélia ómnia mandáta ejus, confirmáta in sǽculum sǽculi, facta in veritáte et æquitáte.",
     "eng": "All His commandments are faithful, confirmed for ever and ever, made in truth and equity."},
    {"lat": "Redemptiónem misit pópulo suo: mandávit in ætérnum testaméntum suum.",
     "eng": "He hath sent redemption to His people: He hath commanded His covenant for ever."},
    {"lat": "Sanctum et terríbile nomen ejus: inítium sapiéntiæ timor Dómini.",
     "eng": "Holy and terrible is His name: the fear of the Lord is the beginning of wisdom."},
    {"lat": "Intelléctus bonus ómnibus faciéntibus eum: laudátio ejus manet in sǽculum sǽculi.",
     "eng": "A good understanding to all that do it: His praise continueth for ever and ever."},
]

# ── Psalm 111 (Vespers) ──
PSALM_111 = [
    {"lat": "Beátus vir qui timet Dóminum: in mandátis ejus volet nimis.",
     "eng": "Blessed is the man that feareth the Lord: he shall delight exceedingly in His commandments."},
    {"lat": "Potens in terra erit semen ejus: generátio rectórum benedicétur.",
     "eng": "His seed shall be mighty upon earth: the generation of the righteous shall be blessed."},
    {"lat": "Glória et divítiæ in domo ejus, et justítia ejus manet in sǽculum sǽculi.",
     "eng": "Glory and wealth shall be in his house, and his justice remaineth for ever and ever."},
    {"lat": "Exórtum est in ténebris lumen rectis: miséricors, et miserátor, et justus.",
     "eng": "To the righteous a light is risen up in darkness: he is merciful, and compassionate, and just."},
    {"lat": "Jucúndus homo qui miserétur et cómmodat, dispónet sermónes suos in judício: quia in ætérnum non commovébitur.",
     "eng": "Acceptable is the man that showeth mercy and lendeth; he shall order his words with judgment, because he shall not be moved for ever."},
    {"lat": "In memória ætérna erit justus: ab auditióne mala non timébit.",
     "eng": "The just shall be in everlasting remembrance: he shall not fear the evil hearing."},
    {"lat": "Parátum cor ejus speráre in Dómino, confirmátum est cor ejus: non commovébitur donec despíciat inimícos suos.",
     "eng": "His heart is ready to hope in the Lord; his heart is strengthened: he shall not be moved until he look over his enemies."},
    {"lat": "Dispérsit, dedit paupéribus: justítia ejus manet in sǽculum sǽculi; cornu ejus exaltábitur in glória.",
     "eng": "He hath distributed, he hath given to the poor: his justice remaineth for ever and ever; his horn shall be exalted in glory."},
    {"lat": "Peccátor vidébit et irascétur; déntibus suis fremet et tabéscet: desidérium peccatórum períbit.",
     "eng": "The wicked shall see and shall be angry; he shall gnash with his teeth and pine away: the desire of the wicked shall perish."},
]

# ── Psalm 112 (Vespers) ──
PSALM_112 = [
    {"lat": "Laudáte, púeri, Dóminum: laudáte nomen Dómini.",
     "eng": "Praise the Lord, ye children: praise ye the name of the Lord."},
    {"lat": "Sit nomen Dómini benedíctum, ex hoc nunc et usque in sǽculum.",
     "eng": "Blessed be the name of the Lord, from henceforth now and for ever."},
    {"lat": "A solis ortu usque ad occásum, laudábile nomen Dómini.",
     "eng": "From the rising of the sun unto the going down of the same, the name of the Lord is worthy of praise."},
    {"lat": "Excélsus super omnes gentes Dóminus, et super cælos glória ejus.",
     "eng": "The Lord is high above all nations, and His glory above the heavens."},
    {"lat": "Quis sicut Dóminus Deus noster, qui in altis hábitat, et humília réspicit in cælo et in terra?",
     "eng": "Who is as the Lord our God, who dwelleth on high, and looketh down on the low things in heaven and in earth?"},
    {"lat": "Súscitans a terra ínopem, et de stércore érigens páuperem:",
     "eng": "Raising up the needy from the earth, and lifting up the poor out of the dunghill:"},
    {"lat": "Ut cóllocet eum cum princípibus, cum princípibus pópuli sui.",
     "eng": "That He may place him with princes, with the princes of His people."},
    {"lat": "Qui habitáre facit stérilem in domo, matrem filiórum lætántem.",
     "eng": "Who maketh a barren woman to dwell in a house, the joyful mother of children."},
]

# ── Psalm 30:1-6 (Compline) ──
PSALM_30 = [
    {"lat": "In te, Dómine, sperávi, non confúndar in ætérnum: in justítia tua líbera me.",
     "eng": "In Thee, O Lord, have I hoped, let me never be confounded: deliver me in Thy justice."},
    {"lat": "Inclína ad me aurem tuam, accélera ut éruas me.",
     "eng": "Bow down Thy ear to me: make haste to deliver me."},
    {"lat": "Esto mihi in Deum protectórem, et in domum refúgii, ut salvum me fácias.",
     "eng": "Be Thou unto me a God, a protector, and a house of refuge, to save me."},
    {"lat": "Quóniam fortitúdo mea et refúgium meum es tu: et propter nomen tuum dedúces me et enútries me.",
     "eng": "For Thou art my strength and my refuge: and for Thy name's sake Thou wilt lead me and nourish me."},
    {"lat": "Edúces me de láqueo hoc quem abscondérunt mihi, quóniam tu es protéctor meus.",
     "eng": "Thou wilt bring me out of this snare which they have hidden for me: for Thou art my protector."},
    {"lat": "In manus tuas comméndo spíritum meum: redemísti me, Dómine, Deus veritátis.",
     "eng": "Into Thy hands I commend my spirit: Thou hast redeemed me, O Lord, the God of truth."},
]

# ── Psalm 4 (Compline) ──
PSALM_4 = [
    {"lat": "Cum invocárem, exaudívit me Deus justítiæ meæ: in tribulatióne dilatásti mihi.",
     "eng": "When I called upon Him, the God of my justice heard me: when I was in distress, Thou hast enlarged me."},
    {"lat": "Miserére mei, et exáudi oratiónem meam.",
     "eng": "Have mercy on me, and hear my prayer."},
    {"lat": "Fílii hóminum, úsquequo gravi corde? Ut quid dilígitis vanitátem, et quǽritis mendácium?",
     "eng": "O ye sons of men, how long will you be dull of heart? Why do you love vanity and seek after lying?"},
    {"lat": "Et scitóte quóniam mirificávit Dóminus sanctum suum: Dóminus exáudiet me cum clamávero ad eum.",
     "eng": "Know ye also that the Lord hath made His holy one wonderful: the Lord will hear me when I shall cry unto Him."},
    {"lat": "Irascímini, et nolíte peccáre: quæ dícitis in córdibus vestris, in cubílibus vestris compungímini.",
     "eng": "Be angry and sin not: the things you say in your hearts, be sorry for them upon your beds."},
    {"lat": "Sacrificáte sacrifícium justítiæ, et speráte in Dómino. Multi dicunt: Quis osténdit nobis bona?",
     "eng": "Offer up the sacrifice of justice, and trust in the Lord. Many say: Who showeth us good things?"},
    {"lat": "Signátum est super nos lumen vultus tui, Dómine: dedísti lætítiam in corde meo.",
     "eng": "The light of Thy countenance, O Lord, is signed upon us: Thou hast given gladness in my heart."},
    {"lat": "A fructu fruménti, vini et ólei sui, multiplicáti sunt.",
     "eng": "By the fruit of their corn, their wine, and oil, they are multiplied."},
    {"lat": "In pace in idípsum dórmiam et requiéscam:",
     "eng": "In peace in the selfsame I will sleep and I will rest:"},
    {"lat": "Quóniam tu, Dómine, singuláriter in spe constituísti me.",
     "eng": "For Thou, O Lord, singularly hast settled me in hope."},
]

# ── Psalm 90 (Compline) ──
PSALM_90 = [
    {"lat": "Qui hábitat in adjutório Altíssimi, in protectióne Dei cæli commorábitur.",
     "eng": "He that dwelleth in the aid of the Most High shall abide under the protection of the God of heaven."},
    {"lat": "Dicet Dómino: Suscéptor meus es tu et refúgium meum: Deus meus, sperábo in eum.",
     "eng": "He shall say to the Lord: Thou art my protector and my refuge: my God, in Him will I trust."},
    {"lat": "Quóniam ipse liberávit me de láqueo venántium, et a verbo áspero.",
     "eng": "For He hath delivered me from the snare of the hunters, and from the sharp word."},
    {"lat": "Scápulis suis obumbrábit tibi, et sub pennis ejus sperábis.",
     "eng": "He will overshadow thee with His shoulders, and under His wings thou shalt trust."},
    {"lat": "Scuto circúmdabit te véritas ejus: non timébis a timóre noctúrno,",
     "eng": "His truth shall compass thee with a shield: thou shalt not be afraid of the terror of the night,"},
    {"lat": "A sagítta volánte in die, a negótio perambulánte in ténebris, ab incúrsu et dæmónio meridiáno.",
     "eng": "Of the arrow that flieth in the day, of the business that walketh about in the dark, of invasion, or of the noonday devil."},
    {"lat": "Cadent a látere tuo mille, et decem míllia a dextris tuis: ad te autem non appropinquábit.",
     "eng": "A thousand shall fall at thy side, and ten thousand at thy right hand: but it shall not come nigh thee."},
    {"lat": "Verúmtamen óculis tuis considerábis, et retributiónem peccatórum vidébis.",
     "eng": "But thou shalt consider with thy eyes, and shalt see the reward of the wicked."},
    {"lat": "Quóniam tu es, Dómine, spes mea: Altíssimum posuísti refúgium tuum.",
     "eng": "Because Thou, O Lord, art my hope: Thou hast made the Most High thy refuge."},
    {"lat": "Non accédet ad te malum, et flagéllum non appropinquábit tabernáculo tuo.",
     "eng": "There shall no evil come to thee, nor shall the scourge come near thy dwelling."},
    {"lat": "Quóniam Ángelis suis mandávit de te, ut custódiant te in ómnibus viis tuis.",
     "eng": "For He hath given His Angels charge over thee, to keep thee in all thy ways."},
    {"lat": "In mánibus portábunt te, ne forte offéndas ad lápidem pedem tuum.",
     "eng": "In their hands they shall bear thee up, lest thou dash thy foot against a stone."},
    {"lat": "Super áspidem et basilíscum ambulábis, et conculcábis leónem et dracónem.",
     "eng": "Thou shalt walk upon the asp and the basilisk: and thou shalt trample under foot the lion and the dragon."},
    {"lat": "Quóniam in me sperávit, liberábo eum: prótegam eum, quóniam cognóvit nomen meum.",
     "eng": "Because he hoped in Me I will deliver him: I will protect him because he hath known My name."},
    {"lat": "Clamábit ad me, et ego exáudiam eum: cum ipso sum in tribulatióne: erípiam eum et glorificábo eum.",
     "eng": "He shall cry to Me, and I will hear him: I am with him in tribulation: I will deliver him and I will glorify him."},
    {"lat": "Longitúdine diérum replébo eum, et osténdam illi salutáre meum.",
     "eng": "I will fill him with length of days, and I will show him My salvation."},
]

# ── Psalm 133 (Compline) ──
PSALM_133 = [
    {"lat": "Ecce nunc benedícite Dóminum, omnes servi Dómini:",
     "eng": "Behold, now bless ye the Lord, all ye servants of the Lord:"},
    {"lat": "Qui statis in domo Dómini, in átriis domus Dei nostri.",
     "eng": "Who stand in the house of the Lord, in the courts of the house of our God."},
    {"lat": "In nóctibus extóllite manus vestras in sancta, et benedícite Dóminum.",
     "eng": "In the nights lift up your hands to the holy places, and bless ye the Lord."},
    {"lat": "Benedícat te Dóminus ex Sion, qui fecit cælum et terram.",
     "eng": "May the Lord out of Sion bless thee, He that made heaven and earth."},
]

# ──────────────────────────────────────────────────────────────────────
# COMPLETE CANTICLE TEXTS
# ──────────────────────────────────────────────────────────────────────

TE_DEUM = [
    {"lat": "Te Deum laudámus: te Dóminum confitémur.",
     "eng": "We praise Thee, O God: we acknowledge Thee to be the Lord."},
    {"lat": "Te ætérnum Patrem omnis terra venerátur.",
     "eng": "All the earth doth worship Thee, the Father everlasting."},
    {"lat": "Tibi omnes Ángeli, tibi Cæli et univérsæ Potestátes:",
     "eng": "To Thee all Angels cry aloud, the Heavens and all the Powers therein."},
    {"lat": "Tibi Chérubim et Séraphim incessábili voce proclámant:",
     "eng": "To Thee Cherubim and Seraphim continually do cry:"},
    {"lat": "Sanctus, Sanctus, Sanctus, Dóminus Deus Sábaoth.",
     "eng": "Holy, Holy, Holy, Lord God of Hosts."},
    {"lat": "Pleni sunt cæli et terra majestátis glóriæ tuæ.",
     "eng": "Heaven and earth are full of the majesty of Thy glory."},
    {"lat": "Te gloriósus Apostolórum chorus,",
     "eng": "The glorious company of the Apostles praise Thee,"},
    {"lat": "Te Prophetárum laudábilis númerus,",
     "eng": "The goodly fellowship of the Prophets praise Thee,"},
    {"lat": "Te Mártyrum candidátus laudat exércitus.",
     "eng": "The noble army of Martyrs praise Thee."},
    {"lat": "Te per orbem terrárum sancta confitétur Ecclésia,",
     "eng": "The holy Church throughout all the world doth acknowledge Thee,"},
    {"lat": "Patrem imménsæ majestátis;",
     "eng": "The Father of an infinite majesty;"},
    {"lat": "Venerándum tuum verum et únicum Fílium;",
     "eng": "Thine honourable, true and only Son;"},
    {"lat": "Sanctum quoque Paráclitum Spíritum.",
     "eng": "Also the Holy Ghost, the Comforter."},
    {"lat": "Tu Rex glóriæ, Christe.",
     "eng": "Thou art the King of Glory, O Christ."},
    {"lat": "Tu Patris sempitérnus es Fílius.",
     "eng": "Thou art the everlasting Son of the Father."},
    {"lat": "Tu, ad liberándum susceptúrus hóminem, non horruísti Vírginis úterum.",
     "eng": "When Thou tookest upon Thee to deliver man, Thou didst not abhor the Virgin's womb."},
    {"lat": "Tu, devícto mortis acúleo, aperuísti credéntibus regna cælórum.",
     "eng": "When Thou hadst overcome the sharpness of death, Thou didst open the kingdom of heaven to all believers."},
    {"lat": "Tu ad déxteram Dei sedes, in glória Patris.",
     "eng": "Thou sittest at the right hand of God, in the glory of the Father."},
    {"lat": "Judex créderis esse ventúrus.",
     "eng": "We believe that Thou shalt come to be our Judge."},
    {"lat": "Te ergo quǽsumus, tuis fámulis súbveni, quos pretióso sánguine redemísti.",
     "eng": "We therefore pray Thee, help Thy servants, whom Thou hast redeemed with Thy precious Blood."},
    {"lat": "Ætérna fac cum Sanctis tuis in glória numerári.",
     "eng": "Make them to be numbered with Thy Saints in glory everlasting."},
    {"lat": "Salvum fac pópulum tuum, Dómine, et bénedic hereditáti tuæ.",
     "eng": "O Lord, save Thy people, and bless Thine inheritance."},
    {"lat": "Et rege eos, et extólle illos usque in ætérnum.",
     "eng": "Govern them, and lift them up for ever."},
    {"lat": "Per síngulos dies benedícimus te.",
     "eng": "Day by day we magnify Thee."},
    {"lat": "Et laudámus nomen tuum in sǽculum, et in sǽculum sǽculi.",
     "eng": "And we worship Thy name ever, world without end."},
    {"lat": "Dignáre, Dómine, die isto sine peccáto nos custodíre.",
     "eng": "Vouchsafe, O Lord, to keep us this day without sin."},
    {"lat": "Miserére nostri, Dómine, miserére nostri.",
     "eng": "O Lord, have mercy upon us, have mercy upon us."},
    {"lat": "Fiat misericórdia tua, Dómine, super nos, quemádmodum sperávimus in te.",
     "eng": "O Lord, let Thy mercy lighten upon us, as our trust is in Thee."},
    {"lat": "In te, Dómine, sperávi: non confúndar in ætérnum.",
     "eng": "O Lord, in Thee have I trusted: let me never be confounded."},
]

BENEDICTUS = [
    {"lat": "Benedíctus Dóminus Deus Israël, quia visitávit et fecit redemptiónem plebis suæ:",
     "eng": "Blessed be the Lord God of Israel, because He hath visited and wrought the redemption of His people:"},
    {"lat": "Et eréxit cornu salútis nobis, in domo David púeri sui.",
     "eng": "And hath raised up an horn of salvation to us, in the house of David His servant."},
    {"lat": "Sicut locútus est per os sanctórum, qui a sǽculo sunt, prophetárum ejus:",
     "eng": "As He spoke by the mouth of His holy prophets, who are from the beginning:"},
    {"lat": "Salútem ex inimícis nostris, et de manu ómnium qui odérunt nos:",
     "eng": "Salvation from our enemies, and from the hand of all that hate us:"},
    {"lat": "Ad faciéndam misericórdiam cum pátribus nostris, et memorári testaménti sui sancti.",
     "eng": "To perform mercy to our fathers, and to remember His holy testament."},
    {"lat": "Jusjurándum quod jurávit ad Abraham patrem nostrum, datúrum se nobis:",
     "eng": "The oath which He swore to Abraham our father, that He would grant to us:"},
    {"lat": "Ut sine timóre, de manu inimicórum nostrórum liberáti, serviámus illi,",
     "eng": "That being delivered from the hand of our enemies, we may serve Him without fear,"},
    {"lat": "In sanctitáte et justítia coram ipso, ómnibus diébus nostris.",
     "eng": "In holiness and justice before Him, all our days."},
    {"lat": "Et tu, puer, Prophéta Altíssimi vocáberis: præíbis enim ante fáciem Dómini, paráre vias ejus:",
     "eng": "And thou, child, shalt be called the prophet of the Highest: for thou shalt go before the face of the Lord to prepare His ways:"},
    {"lat": "Ad dandam sciéntiam salútis plebi ejus, in remissiónem peccatórum eórum:",
     "eng": "To give knowledge of salvation to His people, unto the remission of their sins:"},
    {"lat": "Per víscera misericórdiæ Dei nostri, in quibus visitávit nos Óriens ex alto:",
     "eng": "Through the bowels of the mercy of our God, in which the Orient from on high hath visited us:"},
    {"lat": "Illumináre his qui in ténebris et in umbra mortis sedent, ad dirigéndos pedes nostros in viam pacis.",
     "eng": "To enlighten them that sit in darkness and in the shadow of death: to direct our feet into the way of peace."},
]

MAGNIFICAT = [
    {"lat": "Magníficat ánima mea Dóminum:",
     "eng": "My soul doth magnify the Lord:"},
    {"lat": "Et exsultávit spíritus meus in Deo salutári meo.",
     "eng": "And my spirit hath rejoiced in God my Saviour."},
    {"lat": "Quia respéxit humilitátem ancíllæ suæ: ecce enim ex hoc beátam me dicent omnes generatiónes.",
     "eng": "Because He hath regarded the humility of His handmaid: for behold from henceforth all generations shall call me blessed."},
    {"lat": "Quia fecit mihi magna qui potens est: et sanctum nomen ejus.",
     "eng": "Because He that is mighty hath done great things to me: and holy is His name."},
    {"lat": "Et misericórdia ejus a progénie in progénies timéntibus eum.",
     "eng": "And His mercy is from generation unto generations, to them that fear Him."},
    {"lat": "Fecit poténtiam in bráchio suo: dispérsit supérbos mente cordis sui.",
     "eng": "He hath shewed might in His arm: He hath scattered the proud in the conceit of their heart."},
    {"lat": "Depósuit poténtes de sede, et exaltávit húmiles.",
     "eng": "He hath put down the mighty from their seat, and hath exalted the humble."},
    {"lat": "Esuriéntes implévit bonis, et dívites dimísit inánes.",
     "eng": "He hath filled the hungry with good things, and the rich He hath sent empty away."},
    {"lat": "Suscépit Israël púerum suum, recordátus misericórdiæ suæ.",
     "eng": "He hath received Israel His servant, being mindful of His mercy."},
    {"lat": "Sicut locútus est ad patres nostros, Abraham et sémini ejus in sǽcula.",
     "eng": "As He spoke to our fathers, to Abraham and to his seed for ever."},
]

NUNC_DIMITTIS = [
    {"lat": "Nunc dimíttis servum tuum, Dómine, secúndum verbum tuum in pace:",
     "eng": "Now Thou dost dismiss Thy servant, O Lord, according to Thy word in peace:"},
    {"lat": "Quia vidérunt óculi mei salutáre tuum,",
     "eng": "Because my eyes have seen Thy salvation,"},
    {"lat": "Quod parásti ante fáciem ómnium populórum:",
     "eng": "Which Thou hast prepared before the face of all peoples:"},
    {"lat": "Lumen ad revelatiónem géntium, et glóriam plebis tuæ Israël.",
     "eng": "A light to the revelation of the Gentiles, and the glory of Thy people Israel."},
]

# ── Canticum Trium Puerorum (Dan 3:57-88, 56) ──
CANTICUM_TRIUM_PUERORUM = [
    {"lat": "Benedícite, ómnia ópera Dómini, Dómino: laudáte et superexaltáte eum in sǽcula.",
     "eng": "All ye works of the Lord, bless the Lord: praise and exalt Him above all for ever."},
    {"lat": "Benedícite, Ángeli Dómini, Dómino: benedícite, cæli, Dómino.",
     "eng": "O ye Angels of the Lord, bless the Lord: O ye heavens, bless the Lord."},
    {"lat": "Benedícite, aquæ omnes quæ super cælos sunt, Dómino: benedícite, omnes virtútes Dómini, Dómino.",
     "eng": "O all ye waters that are above the heavens, bless the Lord: O all ye powers of the Lord, bless the Lord."},
    {"lat": "Benedícite, sol et luna, Dómino: benedícite, stellæ cæli, Dómino.",
     "eng": "O ye sun and moon, bless the Lord: O ye stars of heaven, bless the Lord."},
    {"lat": "Benedícite, omnis imber et ros, Dómino: benedícite, omnes spíritus Dei, Dómino.",
     "eng": "O every shower and dew, bless the Lord: O all ye spirits of God, bless the Lord."},
    {"lat": "Benedícite, ignis et æstus, Dómino: benedícite, frigus et æstus, Dómino.",
     "eng": "O ye fire and heat, bless the Lord: O ye cold and heat, bless the Lord."},
    {"lat": "Benedícite, rores et pruína, Dómino: benedícite, gelu et frigus, Dómino.",
     "eng": "O ye dews and hoar frosts, bless the Lord: O ye frost and cold, bless the Lord."},
    {"lat": "Benedícite, glácies et nives, Dómino: benedícite, noctes et dies, Dómino.",
     "eng": "O ye ice and snow, bless the Lord: O ye nights and days, bless the Lord."},
    {"lat": "Benedícite, lux et ténebræ, Dómino: benedícite, fúlgura et nubes, Dómino.",
     "eng": "O ye light and darkness, bless the Lord: O ye lightnings and clouds, bless the Lord."},
    {"lat": "Benedícat terra Dóminum: laudet et superexáltet eum in sǽcula.",
     "eng": "O let the earth bless the Lord: let it praise and exalt Him above all for ever."},
    {"lat": "Benedícite, montes et colles, Dómino: benedícite, univérsa germinántia in terra, Dómino.",
     "eng": "O ye mountains and hills, bless the Lord: O all ye things that spring up in the earth, bless the Lord."},
    {"lat": "Benedícite, fontes, Dómino: benedícite, mária et flúmina, Dómino.",
     "eng": "O ye fountains, bless the Lord: O ye seas and rivers, bless the Lord."},
    {"lat": "Benedícite, cete et ómnia quæ movéntur in aquis, Dómino: benedícite, omnes vólucres cæli, Dómino.",
     "eng": "O ye whales and all that move in the waters, bless the Lord: O all ye fowls of the air, bless the Lord."},
    {"lat": "Benedícite, omnes béstiæ et pécora, Dómino: benedícite, fílii hóminum, Dómino.",
     "eng": "O all ye beasts and cattle, bless the Lord: O ye sons of men, bless the Lord."},
    {"lat": "Benedícat Israël Dóminum: laudet et superexáltet eum in sǽcula.",
     "eng": "O let Israel bless the Lord: let them praise and exalt Him above all for ever."},
    {"lat": "Benedícite, sacerdótes Dómini, Dómino: benedícite, servi Dómini, Dómino.",
     "eng": "O ye priests of the Lord, bless the Lord: O ye servants of the Lord, bless the Lord."},
    {"lat": "Benedícite, spíritus et ánimæ justórum, Dómino: benedícite, sancti et húmiles corde, Dómino.",
     "eng": "O ye spirits and souls of the just, bless the Lord: O ye holy and humble of heart, bless the Lord."},
    {"lat": "Benedícite, Ananía, Azaría, Mísaël, Dómino: laudáte et superexaltáte eum in sǽcula.",
     "eng": "O Ananias, Azarias, and Misael, bless ye the Lord: praise and exalt Him above all for ever."},
    {"lat": "Benedícámus Patrem et Fílium cum Sancto Spíritu: laudémus et superexaltémus eum in sǽcula.",
     "eng": "Let us bless the Father and the Son, with the Holy Ghost: let us praise and exalt Him above all for ever."},
    {"lat": "Benedíctus es, Dómine, in firmaménto cæli: et laudábilis, et gloriósus, et superexaltátus in sǽcula.",
     "eng": "Blessed art Thou, O Lord, in the firmament of heaven: and worthy of praise, and glorious, and highly exalted for ever."},
]

# ──────────────────────────────────────────────────────────────────────
# COMPLETE HYMN TEXTS  (stanzas separated by \n\n in lat/eng fields)
# ──────────────────────────────────────────────────────────────────────

# Matins Hymn
HYMN_AETERNE_RERUM = {
    "lat": (
        "Ætérne rerum Cónditor,<br>noctem diémque qui regis,<br>et témporum das témpora,<br>ut álleves fastídium.\n\n"
        "Præco diéi jam sonat,<br>noctis profúndæ pérvigil,<br>noctúrna lux viántibus,<br>a nocte noctem ségregans.\n\n"
        "Hoc excitátus Lúcifer<br>solvit polum calígine;<br>hoc omnis errónum cohors<br>viam nocéndi déserit.\n\n"
        "Hoc nauta vires cólligit,<br>pontíque mitéscunt freta;<br>hoc ipse petra Ecclésiæ<br>canénte, culpam díluit.\n\n"
        "Surgámus ergo strénue:<br>gallus jacéntes éxcitat,<br>et somnoléntis íncrepat;<br>gallus negántes árguit.\n\n"
        "Gallo canénte, spes redit,<br>ægris salus refúnditur,<br>mucro latrónis cónditur,<br>lapsis fides revértitur.\n\n"
        "Jesu, labántes réspice,<br>et nos vidéndo córrige;<br>si réspicis, lapsus cadunt,<br>fletúque culpa sólvitur.\n\n"
        "Tu lux refúlge sénsibus,<br>mentísque somnum díscute;<br>te nostra vox primum sonet,<br>et ore psallamus tibi.\n\n"
        "Deo Patri sit glória,<br>ejúsque soli Fílio,<br>cum Spíritu Paráclito,<br>nunc et per omne sǽculum. Amen."
    ),
    "eng": (
        "Eternal Maker of all things,<br>Who governest both night and day,<br>and grantest us the changing hours<br>to ease the labours of our way.\n\n"
        "Now sounds the herald of the dawn,<br>who watches through the night profound,<br>a light to travellers in the dark,<br>dividing night from night around.\n\n"
        "At this the morning star awakes,<br>and frees the sky from cloudy pall;<br>at this the band of wanderers leaves<br>the road of harm where shadows fall.\n\n"
        "At this the sailor gathers strength,<br>and calmer grow the waves of sea;<br>at this the Rock upon whom rests<br>the Church, from sin doth wash Him free.\n\n"
        "Then let us rise with earnest haste:<br>the cock awakes the sluggish men,<br>upbraids the drowsy with his cry,<br>convicts the faithless once again.\n\n"
        "The cock crows, and hope returns,<br>health is poured back on the sick,<br>the robber sheathes his murderous blade,<br>faith is restored to those who slipped.\n\n"
        "O Jesus, look on us who fall,<br>and by Thy gaze correct our ways;<br>if Thou dost look, our faults give way,<br>and guilt dissolves in tears of praise.\n\n"
        "O Light, shine on our darkened sense,<br>and drive away the sleep of mind;<br>let our first utterance be of Thee,<br>and hymns of praise to Thee be signed.\n\n"
        "To God the Father glory be,<br>and to His only Son on high,<br>together with the Paraclete,<br>both now and through eternity. Amen."
    ),
}

# Lauds Hymn
HYMN_SPLENDOR = {
    "lat": (
        "Splendor patérnæ glóriæ,<br>de luce lucem próferens,<br>lux lucis et fons lúminis,<br>diem dies illúminans.\n\n"
        "Verúsque sol, illábere,<br>micans nitóre pérpeti,<br>jubárque Sancti Spíritus<br>infúnde nostris sénsibus.\n\n"
        "Votis vocémus et Patrem,<br>Patrem perénnis glóriæ,<br>Patrem poténtis grátiæ,<br>culpam reléget lúbricam.\n\n"
        "Infórmet actus strénuos,<br>dentem retúndat ínvidi,<br>casus secúndet ásperos,<br>donet geréndi grátiam.\n\n"
        "Mentem gubérnet et regat<br>casto, fidéli córpore;<br>fides calóre férveat,<br>fraudis venéna nésciat.\n\n"
        "Christúsque nobis sit cibus,<br>potúsque noster sit fides;<br>læti bibámus sóbriam<br>ebrietátem Spíritus.\n\n"
        "Lætus dies hic tránseat;<br>pudor sit ut dilúculum,<br>fides velut merídies,<br>crepúsculum mens nésciat.\n\n"
        "Auróra cursus próvehit:<br>Auróra totus pródeat,<br>in Patre totus Fílius,<br>et totus in Verbo Pater.\n\n"
        "Deo Patri sit glória,<br>ejúsque soli Fílio,<br>cum Spíritu Paráclito,<br>nunc et per omne sǽculum. Amen."
    ),
    "eng": (
        "O splendour of God's glory bright,<br>O Thou that bringest light from light,<br>O Light of light, light's living spring,<br>O Day, all days illumining.\n\n"
        "O Thou true Sun, on us Thy glance<br>let fall in royal radiance;<br>the Spirit's sanctifying beam<br>upon our earthly senses stream.\n\n"
        "The Father, too, our prayers implore,<br>Father of glory evermore,<br>the Father of all grace and might,<br>to banish sin from our delight.\n\n"
        "May He our actions deign to bless,<br>and loose the wiles of wickedness;<br>from stumbling may He keep our feet,<br>and give us grace all ill to meet.\n\n"
        "May He our minds direct and rule,<br>with bodies chaste and faithful still;<br>may faith in fervour burn the heart,<br>and know not poison's treacherous art.\n\n"
        "And Christ to us for food shall be,<br>from Him our drink of faith have we;<br>the Spirit's wine that maketh whole,<br>and mocking not, exalts the soul.\n\n"
        "Rejoicing may this day go hence;<br>like to the dawn our innocence,<br>like noonday glow our faith remain,<br>nor know the twilight of the brain.\n\n"
        "Dawn speeds her course along the way:<br>O Dawn in fullness, come and stay,<br>all in the Father is the Son,<br>and all the Father in the Word.\n\n"
        "To God the Father glory be,<br>and to His only Son on high,<br>together with the Paraclete,<br>both now and through eternity. Amen."
    ),
}

# Prime Hymn
HYMN_IAM_LUCIS = {
    "lat": (
        "Jam lucis orto sídere,<br>Deum precémur súpplices,<br>ut in diúrnis áctibus<br>nos servet a nocéntibus.\n\n"
        "Linguam refrénans témperet,<br>ne litis horror ínsonet;<br>visum fovéndo cóntegat,<br>ne vanitátes háuriat.\n\n"
        "Sint pura cordis íntima,<br>absístat et vecórdia;<br>carnis terat supérbiam<br>potus cibíque párcitas.\n\n"
        "Ut cum dies abscésserit,<br>noctémque sors redúxerit,<br>mundi per abstinéntiam<br>ipsi canámus glóriam.\n\n"
        "Deo Patri sit glória,<br>ejúsque soli Fílio,<br>cum Spíritu Paráclito,<br>nunc et per omne sǽculum. Amen."
    ),
    "eng": (
        "Now in the sun's new dawning ray,<br>lowly of heart we Thee implore:<br>that in our every deed this day<br>Thou keep us free from evil's power.\n\n"
        "May He our tongues in order hold,<br>that discord's horror sound not here;<br>and guard our eyes from sights untold,<br>that vanities may not appear.\n\n"
        "O may the inmost heart be pure,<br>and folly's grasp be far removed;<br>let abstinence in food endure,<br>that pride of flesh be reproved.\n\n"
        "So when the daylight fades away,<br>and night in turn again draws near,<br>through abstinence from worldly sway<br>we sing His glory without fear.\n\n"
        "To God the Father glory be,<br>and to His only Son on high,<br>together with the Paraclete,<br>both now and through eternity. Amen."
    ),
}

# Terce Hymn
HYMN_NUNC_SANCTE = {
    "lat": (
        "Nunc, Sancte, nobis Spíritus,<br>unum Patri cum Fílio,<br>dignáre promptus íngeri<br>nostro refúsus péctori.\n\n"
        "Os, lingua, mens, sensus, vigor,<br>confessiónem pérsonent;<br>flamméscat igne cáritas,<br>accéndat ardor próximos.\n\n"
        "Præsta, Pater piíssime,<br>Patríque compar Únice,<br>cum Spíritu Paráclito<br>regnans per omne sǽculum. Amen."
    ),
    "eng": (
        "Come, Holy Ghost, who ever One<br>reignest with Father and with Son,<br>it is the hour, our souls possess<br>with Thy full flood of holiness.\n\n"
        "Let mouth and tongue, mind, strength, and will,<br>sound forth our witness to Thy name;<br>and charity's devouring flame<br>set all our being in a glow.\n\n"
        "O Father, that we ask be done,<br>through Jesus Christ, Thine only Son,<br>who, with the Holy Ghost and Thee,<br>shall live and reign eternally. Amen."
    ),
}

# Sext Hymn
HYMN_RECTOR_POTENS = {
    "lat": (
        "Rector potens, verax Deus,<br>qui témperas rerum vices,<br>splendóre mane illúminas,<br>et ígnibus merídiem.\n\n"
        "Exstíngue flammas lítium,<br>aufer calórem nóxium,<br>confer salútem córporum,<br>verámque pacem córdium.\n\n"
        "Præsta, Pater piíssime,<br>Patríque compar Únice,<br>cum Spíritu Paráclito<br>regnans per omne sǽculum. Amen."
    ),
    "eng": (
        "O God of truth, O Lord of might,<br>who orderest time and change aright,<br>who sendest the early morning ray,<br>and lightest with splendour all the day.\n\n"
        "Extinguish Thou each sinful fire,<br>and banish every ill desire;<br>and while Thou keepest the body whole,<br>shed forth Thy peace upon the soul.\n\n"
        "O Father, that we ask be done,<br>through Jesus Christ, Thine only Son,<br>who, with the Holy Ghost and Thee,<br>shall live and reign eternally. Amen."
    ),
}

# None Hymn
HYMN_RERUM_DEUS = {
    "lat": (
        "Rerum Deus tenax vigor,<br>immótus in te pérmanens,<br>lucis diúrnæ témpora<br>succéssibus detérminans.\n\n"
        "Largíre clarum véspere,<br>quo vita nusquam décidat,<br>sed prǽmium mortis sacræ<br>perénnis instet glória.\n\n"
        "Præsta, Pater piíssime,<br>Patríque compar Únice,<br>cum Spíritu Paráclito<br>regnans per omne sǽculum. Amen."
    ),
    "eng": (
        "O strength and stay upholding all creation,<br>who ever dost Thyself unmoved abide,<br>yet day by day the light in due gradation<br>from hour to hour through all its changes guide.\n\n"
        "Grant to life's day a calm unclouded ending,<br>an eve untouched by shadows of decay,<br>the brightness of a holy deathbed blending<br>with dawning glories of th'eternal day.\n\n"
        "O Father, that we ask be done,<br>through Jesus Christ, Thine only Son,<br>who, with the Holy Ghost and Thee,<br>shall live and reign eternally. Amen."
    ),
}

# Vespers Hymn
HYMN_LUCIS_CREATOR = {
    "lat": (
        "Lucis Creátor óptime,<br>lucem diérum próferens,<br>primórdiis lucis novæ,<br>mundi parans oríginem.\n\n"
        "Qui mane junctum vésperi<br>diem vocári prǽcipis:<br>illǽbitur tetrum chaos,<br>audi preces cum flétibus.\n\n"
        "Ne mens graváta crímine<br>vitæ sit exsul múnere,<br>dum nil perénne cógitat,<br>sesé que culpis ílligat.\n\n"
        "Cæléstem pulsent jánuam,<br>vitále tollant prǽmium;<br>vitémus omne nóxium,<br>purgémus omne péssimum.\n\n"
        "Præsta, Pater piíssime,<br>Patríque compar Únice,<br>cum Spíritu Paráclito<br>regnans per omne sǽculum. Amen."
    ),
    "eng": (
        "O blest Creator of the light,<br>who mak'st the day with radiance bright,<br>and o'er the forming world didst call<br>the light from chaos first of all.\n\n"
        "Whose wisdom joined in meet array<br>the morn and eve, and named them day:<br>night comes with all its darkling fears,<br>regard Thy people's prayers and tears.\n\n"
        "Lest, sunk in sin, and whelmed with strife,<br>they lose the gift of endless life;<br>while thinking but the thoughts of time,<br>they weave new chains of woe and crime.\n\n"
        "But grant them grace that they may strain<br>the heavenly gate and prize to gain;<br>each harmful lure aside to cast,<br>and purge away each error past.\n\n"
        "O Father, that we ask be done,<br>through Jesus Christ, Thine only Son,<br>who, with the Holy Ghost and Thee,<br>shall live and reign eternally. Amen."
    ),
}

# Compline Hymn
HYMN_TE_LUCIS = {
    "lat": (
        "Te lucis ante términum,<br>rerum Creátor, póscimus,<br>ut pro tua cleméntia<br>sis præsul et custódia.\n\n"
        "Procul recédant sómnia,<br>et nóctium phantásmata;<br>hostémque nostrum cómprime,<br>ne polluántur córpora.\n\n"
        "Præsta, Pater piíssime,<br>Patríque compar Únice,<br>cum Spíritu Paráclito<br>regnans per omne sǽculum. Amen."
    ),
    "eng": (
        "To Thee before the close of day,<br>Creator of the world, we pray:<br>that with Thy wonted favour Thou<br>wouldst be our guard and keeper now.\n\n"
        "From all ill dreams defend our sight,<br>from fears and terrors of the night;<br>withhold from us our ghostly foe,<br>that spot of sin we may not know.\n\n"
        "O Father, that we ask be done,<br>through Jesus Christ, Thine only Son,<br>who, with the Holy Ghost and Thee,<br>shall live and reign eternally. Amen."
    ),
}

# ── Compline Marian Antiphon – Salve Regína (full text) ──
SALVE_REGINA = {
    "type": "marian",
    "label": "Marian Antiphon; Salve Regína",
    "lat": "Salve, Regína, Mater misericórdiæ, vita, dulcédo et spes nostra, salve. Ad te clamámus, éxsules fílii Hevæ. Ad te suspirámus, geméntes et flentes in hac lacrimárum valle. Eja ergo, advocáta nostra, illos tuos misericórdes óculos ad nos convérte. Et Jesum, benedíctum fructum ventris tui, nobis post hoc exsílium osténde. O clemens, o pia, o dulcis Virgo María.",
    "eng": "Hail, holy Queen, Mother of mercy, our life, our sweetness, and our hope. To thee do we cry, poor banished children of Eve. To thee do we send up our sighs, mourning and weeping in this valley of tears. Turn then, most gracious Advocate, thine eyes of mercy toward us. And after this our exile, show unto us the blessed fruit of thy womb, Jesus. O clement, O loving, O sweet Virgin Mary.",
}

# ──────────────────────────────────────────────────────────────────────
# MAPPING: how to find and replace each element
# ──────────────────────────────────────────────────────────────────────

def find_part(parts, **criteria):
    """Return (index, part) for the first part matching all criteria."""
    for i, p in enumerate(parts):
        if all(p.get(k) == v for k, v in criteria.items()):
            return i, p
    return None, None

def find_part_label_contains(parts, type_val, substr):
    """Return (index, part) for first part of given type whose label contains substr."""
    for i, p in enumerate(parts):
        if p.get("type") == type_val and substr in p.get("label", ""):
            return i, p
    return None, None

def replace_psalm_verses(parts, label_substr, new_verses):
    """Replace verses in the first psalm/canticle whose label contains label_substr."""
    for p in parts:
        if p.get("type") in ("psalm", "canticle") and label_substr in p.get("label", ""):
            p["verses"] = new_verses
            return True
    return False

def replace_hymn(parts, title, new_lat, new_eng):
    """Replace lat/eng in the first hymn matching the given title."""
    for p in parts:
        if p.get("type") == "hymn" and p.get("title", "").startswith(title[:10]):
            p["lat"] = new_lat
            p["eng"] = new_eng
            return True
    return False

# ──────────────────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────────────────

def main():
    with open(INPUT, "r", encoding="utf-8") as f:
        hours = json.load(f)

    hour_map = {h["slug"]: h for h in hours}

    # ────── MATUTINUM ──────
    mat = hour_map["matutinum"]
    parts = mat["parts"]

    # Hymn
    replace_hymn(parts, "Æterne", HYMN_AETERNE_RERUM["lat"], HYMN_AETERNE_RERUM["eng"])

    # Psalm 94 (Invitatorium)
    replace_psalm_verses(parts, "Psalm 94", PSALM_94)

    # Psalm 1
    replace_psalm_verses(parts, "Psalmus 1", PSALM_1)

    # Psalm 2
    replace_psalm_verses(parts, "Psalmus 2", PSALM_2)

    # Add missing Matins psalms (Nocturns)
    # Find the position of Psalm 2 to insert after it
    ps2_idx = None
    for i, p in enumerate(parts):
        if p.get("label") == "Psalmus 2":
            ps2_idx = i
            break

    # Nocturn I additional psalm: Psalm 3
    new_psalms_nocturn_1 = [
        {
            "type": "psalm",
            "label": "Psalmus 3",
            "ref": "Ps 3",
            "verses": PSALM_3,
        },
    ]

    # Nocturn II: Psalms 6, 7, 8
    new_psalms_nocturn_2 = [
        {
            "type": "psalm",
            "label": "Psalmus 6",
            "ref": "Ps 6",
            "verses": PSALM_6,
        },
        {
            "type": "psalm",
            "label": "Psalmus 7",
            "ref": "Ps 7",
            "verses": PSALM_7,
        },
        {
            "type": "psalm",
            "label": "Psalmus 8",
            "ref": "Ps 8",
            "verses": PSALM_8,
        },
    ]

    # Nocturn III: Psalm 9 (split into parts in the breviary but we use Ps 9:1-21)
    new_psalms_nocturn_3 = [
        {
            "type": "psalm",
            "label": "Psalmus 9",
            "ref": "Ps 9",
            "verses": PSALM_9_I,
        },
    ]

    if ps2_idx is not None:
        insert_pos = ps2_idx + 1
        for psm in reversed(new_psalms_nocturn_1 + new_psalms_nocturn_2 + new_psalms_nocturn_3):
            parts.insert(insert_pos, psm)

    # Te Deum
    replace_psalm_verses(parts, "Te Deum", TE_DEUM)

    # ────── LAUDES ──────
    lau = hour_map["laudes"]
    parts = lau["parts"]

    replace_hymn(parts, "Splendor", HYMN_SPLENDOR["lat"], HYMN_SPLENDOR["eng"])
    replace_psalm_verses(parts, "Psalm 62", PSALM_62)
    replace_psalm_verses(parts, "Psalmus 66", PSALM_66)
    replace_psalm_verses(parts, "Canticum Trium", CANTICUM_TRIUM_PUERORUM)
    replace_psalm_verses(parts, "Benedictus", BENEDICTUS)

    # ────── PRIMA ──────
    pri = hour_map["prima"]
    parts = pri["parts"]

    replace_hymn(parts, "Iam lucis", HYMN_IAM_LUCIS["lat"], HYMN_IAM_LUCIS["eng"])
    replace_psalm_verses(parts, "Psalmus 117", PSALM_117)
    replace_psalm_verses(parts, "Psalm 53", PSALM_53)

    # ────── TERTIA ──────
    ter = hour_map["tertia"]
    parts = ter["parts"]

    replace_hymn(parts, "Nunc, Sancte", HYMN_NUNC_SANCTE["lat"], HYMN_NUNC_SANCTE["eng"])
    replace_psalm_verses(parts, "Beáti immaculáti", PSALM_118_1_8)
    replace_psalm_verses(parts, "118:33-40", PSALM_118_33_40)
    replace_psalm_verses(parts, "118:41-48", PSALM_118_41_48)

    # ────── SEXTA ──────
    sex = hour_map["sexta"]
    parts = sex["parts"]

    replace_hymn(parts, "Rector pot", HYMN_RECTOR_POTENS["lat"], HYMN_RECTOR_POTENS["eng"])
    replace_psalm_verses(parts, "Psalm 122", PSALM_122)
    replace_psalm_verses(parts, "Psalmus 123", PSALM_123)
    replace_psalm_verses(parts, "Psalmus 124", PSALM_124)

    # ────── NONA ──────
    non = hour_map["nona"]
    parts = non["parts"]

    replace_hymn(parts, "Rerum Deus", HYMN_RERUM_DEUS["lat"], HYMN_RERUM_DEUS["eng"])
    replace_psalm_verses(parts, "Psalm 125", PSALM_125)
    replace_psalm_verses(parts, "Psalmus 126", PSALM_126)
    replace_psalm_verses(parts, "Psalmus 127", PSALM_127)

    # ────── VESPERAE ──────
    ves = hour_map["vesperae"]
    parts = ves["parts"]

    replace_hymn(parts, "Lucis Cre", HYMN_LUCIS_CREATOR["lat"], HYMN_LUCIS_CREATOR["eng"])
    replace_psalm_verses(parts, "Psalm 109", PSALM_109)
    replace_psalm_verses(parts, "Psalmus 110", PSALM_110)
    replace_psalm_verses(parts, "Psalmus 111", PSALM_111)
    replace_psalm_verses(parts, "Psalmus 112", PSALM_112)
    replace_psalm_verses(parts, "Magnificat", MAGNIFICAT)

    # ────── COMPLETORIUM ──────
    com = hour_map["completorium"]
    parts = com["parts"]

    replace_hymn(parts, "Te lucis", HYMN_TE_LUCIS["lat"], HYMN_TE_LUCIS["eng"])
    replace_psalm_verses(parts, "Psalm 30", PSALM_30)
    replace_psalm_verses(parts, "Psalmus 4", PSALM_4)
    replace_psalm_verses(parts, "Psalmus 90", PSALM_90)
    replace_psalm_verses(parts, "Psalmus 133", PSALM_133)
    replace_psalm_verses(parts, "Nunc Dimittis", NUNC_DIMITTIS)

    # Fix Compline Marian Antiphon: change type from "closing" to "marian" and expand text
    for i, p in enumerate(parts):
        if p.get("type") == "closing" and "Salve" in p.get("lat", ""):
            parts[i] = SALVE_REGINA
            break

    # ────── WRITE OUTPUT ──────
    with open(OUTPUT, "w", encoding="utf-8") as f:
        json.dump(hours, f, indent=2, ensure_ascii=False)

    # ── Verification ──
    with open(OUTPUT, "r", encoding="utf-8") as f:
        result = json.load(f)

    print("=== Verification ===")
    for h in result:
        slug = h["slug"]
        psalm_count = sum(1 for p in h["parts"] if p["type"] == "psalm")
        canticle_count = sum(1 for p in h["parts"] if p["type"] == "canticle")
        hymn_count = sum(1 for p in h["parts"] if p["type"] == "hymn")

        for p in h["parts"]:
            if p["type"] == "psalm":
                label = p.get("label", "?")
                vcount = len(p.get("verses", []))
                print(f"  {slug}: {label} → {vcount} verses")
            elif p["type"] == "canticle":
                label = p.get("label", "?")
                vcount = len(p.get("verses", []))
                print(f"  {slug}: {label} → {vcount} verses")
            elif p["type"] == "hymn":
                title = p.get("title", "?")
                stanzas = p.get("lat", "").count("\n\n") + 1
                print(f"  {slug}: Hymn '{title}' → {stanzas} stanzas")
            elif p["type"] == "marian":
                print(f"  {slug}: Marian Antiphon (type=marian) ✓")

        print(f"  [{slug}] psalms={psalm_count}, canticles={canticle_count}, hymns={hymn_count}")
        print()

    print("Done. hours.json has been updated.")


if __name__ == "__main__":
    main()
