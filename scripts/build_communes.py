#!/usr/bin/env python3
"""
Fills gaps in propers.json using Commune templates from the 1962 Missal.
Each Commune provides default Introit, Epistle, Gradual, Gospel, Offertory,
Secret, Communion, Postcommunion for saints of that type.
"""
import json

COMMUNES = {
    "C1": {  # Apostles
        "introit": {"lat": "Mihi autem nimis honorati sunt amici tui, Deus: nimis confortatus est principatus eorum.", "eng": "To me, Thy friends, O God, are made exceedingly honourable: their principality is exceedingly strengthened."},
        "epistle": {"ref": "Eph. 2:19-22", "lat": "Fratres: Jam non estis hospites et advenae: sed estis cives sanctorum et domestici Dei: superaedificati super fundamentum Apostolorum et Prophetarum, ipso summo angulari lapide Christo Jesu.", "eng": "Brethren: You are no more strangers and foreigners: but you are fellow citizens with the saints and the domestics of God: built upon the foundation of the apostles and prophets, Jesus Christ Himself being the chief corner stone."},
        "gospel": {"ref": "Joann. 15:12-16", "lat": "In illo tempore: Dixit Jesus discipulis suis: Hoc est praeceptum meum, ut diligatis invicem, sicut dilexi vos.", "eng": "At that time: Jesus said to His disciples: This is My commandment, that you love one another, as I have loved you."},
        "offertory": {"lat": "In omnem terram exivit sonus eorum: et in fines orbis terrae verba eorum.", "eng": "Their sound hath gone forth into all the earth: and their words unto the ends of the world."},
        "communion": {"lat": "Vos qui secuti estis me, sedebitis super sedes, judicantes duodecim tribus Israel, dicit Dominus.", "eng": "You who have followed Me shall sit upon seats, judging the twelve tribes of Israel, saith the Lord."},
    },
    "C2": {  # Several Martyrs
        "introit": {"lat": "Intret in conspectu tuo, Domine, gemitus compeditorum: redde vicinis nostris septuplum in sinu eorum: vindica sanguinem Sanctorum tuorum, qui effusus est.", "eng": "Let the sighing of the prisoners come in before Thee, O Lord: render to our neighbours sevenfold in their bosom: avenge the blood of Thy Saints, which hath been shed."},
        "epistle": {"ref": "Sap. 3:1-8", "lat": "Justorum animae in manu Dei sunt, et non tanget illos tormentum mortis. Visi sunt oculis insipientium mori: et aestimata est afflictio exitus illorum.", "eng": "The souls of the just are in the hand of God, and the torment of death shall not touch them. In the sight of the unwise they seemed to die: and their departure was taken for misery."},
        "gospel": {"ref": "Luc. 21:9-19", "lat": "In illo tempore: Dixit Jesus discipulis suis: Cum audieritis proelia et seditiones, nolite terreri: oportet primum haec fieri, sed nondum statim finis.", "eng": "At that time: Jesus said to His disciples: When you shall hear of wars and seditions, be not terrified: these things must first come to pass, but the end is not yet presently."},
        "offertory": {"lat": "Laetamini in Domino, et exsultate, justi: et gloriamini, omnes recti corde.", "eng": "Be glad in the Lord, and rejoice, ye just: and glory, all ye right of heart."},
        "communion": {"lat": "Quod dico vobis in tenebris, dicite in lumine, dicit Dominus: et quod in aure auditis, praedicate super tecta.", "eng": "That which I tell you in the dark, speak ye in the light, saith the Lord: and that which you hear in the ear, preach ye upon the housetops."},
    },
    "C3": {  # One Martyr
        "introit": {"lat": "In virtute tua, Domine, laetabitur justus: et super salutare tuum exsultabit vehementer: desiderium animae ejus tribuisti ei.", "eng": "In Thy strength, O Lord, the just man shall joy: and in Thy salvation he shall rejoice exceedingly: Thou hast given him his heart's desire."},
        "epistle": {"ref": "2 Tim. 2:8-10; 3:10-12", "lat": "Carissime: Memor esto Dominum Jesum Christum resurrexisse a mortuis ex semine David, secundum Evangelium meum, in quo laboro usque ad vincula, quasi male operans.", "eng": "Dearly beloved: Be mindful that the Lord Jesus Christ is risen again from the dead, of the seed of David, according to my Gospel, wherein I labour even unto bands, as an evildoer."},
        "gospel": {"ref": "Matt. 10:34-42", "lat": "In illo tempore: Dixit Jesus discipulis suis: Nolite arbitrari quia pacem venerim mittere in terram: non veni pacem mittere, sed gladium.", "eng": "At that time: Jesus said to His disciples: Do not think that I came to send peace upon earth: I came not to send peace, but the sword."},
        "offertory": {"lat": "Gloria et honore coronasti eum: et constituisti eum super opera manuum tuarum, Domine.", "eng": "Thou hast crowned him with glory and honour: and hast set him over the works of Thy hands, O Lord."},
        "communion": {"lat": "Qui vult venire post me, abneget semetipsum, et tollat crucem suam, et sequatur me.", "eng": "If any man will come after Me, let him deny himself, and take up his cross, and follow Me."},
    },
    "C4": {  # Confessor Bishop
        "introit": {"lat": "Statuit ei Dominus testamentum pacis, et principem fecit eum: ut sit illi sacerdotii dignitas in aeternum.", "eng": "The Lord made to him a covenant of peace, and made him a prince: that the dignity of priesthood should be to him for ever."},
        "epistle": {"ref": "Eccli. 44:16-27; 45:3-20", "lat": "Ecce sacerdos magnus, qui in diebus suis placuit Deo, et inventus est justus.", "eng": "Behold, a great priest, who in his days pleased God, and was found just."},
        "gospel": {"ref": "Matt. 25:14-23", "lat": "In illo tempore: Dixit Jesus discipulis suis parabolam hanc: Homo peregre proficiscens, vocavit servos suos, et tradidit illis bona sua.", "eng": "At that time: Jesus spoke to His disciples this parable: A man going into a far country, called his servants and delivered to them his goods."},
        "offertory": {"lat": "Inveni David servum meum, oleo sancto meo unxi eum: manus enim mea auxiliabitur ei, et brachium meum confortabit eum.", "eng": "I have found David My servant: with My holy oil I have anointed him: for My hand shall help him, and My arm shall strengthen him."},
        "communion": {"lat": "Fidelis servus et prudens, quem constituit dominus super familiam suam: ut det illis in tempore tritici mensuram.", "eng": "The faithful and wise servant, whom his lord setteth over his family: to give them their measure of wheat in due season."},
    },
    "C5": {  # Confessor non-Bishop
        "introit": {"lat": "Os justi meditabitur sapientiam, et lingua ejus loquetur judicium: lex Dei ejus in corde ipsius.", "eng": "The mouth of the just shall meditate wisdom, and his tongue shall speak judgment: the law of his God is in his heart."},
        "epistle": {"ref": "Eccli. 31:8-11", "lat": "Beatus vir, qui inventus est sine macula, et qui post aurum non abiit, nec speravit in pecunia et thesauris.", "eng": "Blessed is the man that is found without blemish: and that hath not gone after gold, nor put his trust in money nor in treasures."},
        "gospel": {"ref": "Luc. 12:35-40", "lat": "In illo tempore: Dixit Jesus discipulis suis: Sint lumbi vestri praecincti, et lucernae ardentes in manibus vestris.", "eng": "At that time: Jesus said to His disciples: Let your loins be girt, and lamps burning in your hands."},
        "offertory": {"lat": "Veritas mea et misericordia mea cum ipso: et in nomine meo exaltabitur cornu ejus.", "eng": "My truth and My mercy shall be with him: and in My Name shall his horn be exalted."},
        "communion": {"lat": "Beatus servus, quem, cum venerit dominus, invenerit vigilantem: amen dico vobis, super omnia bona sua constituet eum.", "eng": "Blessed is that servant, whom when his lord shall come he shall find watching: amen I say to you, he shall place him over all his goods."},
    },
    "C6": {  # Abbot - uses C5
    },
    "C7": {  # Virgin
        "introit": {"lat": "Dilexisti justitiam, et odisti iniquitatem: propterea unxit te Deus, Deus tuus, oleo laetitiae prae consortibus tuis.", "eng": "Thou hast loved justice, and hated iniquity: therefore God, Thy God, hath anointed Thee with the oil of gladness above Thy fellows."},
        "epistle": {"ref": "2 Cor. 10:17-18; 11:1-2", "lat": "Fratres: Qui gloriatur, in Domino glorietur. Non enim qui seipsum commendat, ille probatus est: sed quem Deus commendat.", "eng": "Brethren: He that glorieth, let him glory in the Lord. For not he who commendeth himself is approved: but he whom God commendeth."},
        "gospel": {"ref": "Matt. 25:1-13", "lat": "In illo tempore: Dixit Jesus discipulis suis parabolam hanc: Simile erit regnum caelorum decem virginibus: quae accipientes lampades suas exierunt obviam sponso et sponsae.", "eng": "At that time: Jesus spoke to His disciples this parable: The kingdom of heaven shall be like to ten virgins: who taking their lamps went out to meet the bridegroom and the bride."},
        "offertory": {"lat": "Afferentur Regi virgines post eam: proximae ejus afferentur tibi in laetitia.", "eng": "After her shall virgins be brought to the King: her neighbours shall be brought to Thee with gladness."},
        "communion": {"lat": "Quinque prudentes virgines acceperunt oleum in vasis suis cum lampadibus: media autem nocte clamor factus est: Ecce sponsus venit: exite obviam Christo Domino.", "eng": "The five wise virgins took oil in their vessels with the lamps: and at midnight there was a cry made: Behold the bridegroom cometh, go ye forth to meet Christ the Lord."},
    },
    "C11": {  # BVM
        "introit": {"lat": "Salve, sancta Parens, enixa puerpera Regem: qui caelum terramque regit in saecula saeculorum.", "eng": "Hail, holy Mother, who didst bring forth the King Who ruleth heaven and earth for ever and ever."},
        "epistle": {"ref": "Eccli. 24:14-16", "lat": "Ab initio et ante saecula creata sum, et usque ad futurum saeculum non desinam, et in habitatione sancta coram ipso ministravi.", "eng": "From the beginning, and before the world, was I created, and unto the world to come I shall not cease to be, and in the holy dwelling place I have ministered before Him."},
        "gospel": {"ref": "Luc. 11:27-28", "lat": "In illo tempore: Loquente Jesu ad turbas, extollens vocem quaedam mulier de turba, dixit illi: Beatus venter, qui te portavit, et ubera, quae suxisti.", "eng": "At that time: As Jesus was speaking to the multitudes, a certain woman from the crowd, lifting up her voice, said to Him: Blessed is the womb that bore Thee, and the paps that gave Thee suck."},
        "offertory": {"lat": "Beata es, Virgo Maria, quae omnium portasti Creatorem: genuisti qui te fecit, et in aeternum permanes Virgo.", "eng": "Blessed art thou, O Virgin Mary, who didst bear the Creator of all things: thou didst bring forth Him Who made thee, and thou remainest a Virgin for ever."},
        "communion": {"lat": "Beata viscera Mariae Virginis, quae portaverunt aeterni Patris Filium.", "eng": "Blessed is the womb of the Virgin Mary, which bore the Son of the eternal Father."},
    },
}

# Aliases
COMMUNES["C1a"] = COMMUNES["C1"]
COMMUNES["C1v"] = COMMUNES["C1"]
COMMUNES["C2a"] = COMMUNES["C2"]
COMMUNES["C2b"] = COMMUNES["C2"]
COMMUNES["C3a"] = COMMUNES["C3"]
COMMUNES["C4a"] = COMMUNES["C4"]
COMMUNES["C4b"] = COMMUNES["C4"]
COMMUNES["C5a"] = COMMUNES["C5"]
COMMUNES["C5b"] = COMMUNES["C5"]
COMMUNES["C5c"] = COMMUNES["C5"]
COMMUNES["C6a"] = COMMUNES["C5"]  # Abbots use Confessor texts
COMMUNES["C7a"] = COMMUNES["C7"]
COMMUNES["C8"] = COMMUNES["C7"]   # Holy Women use similar texts
COMMUNES["C8a"] = COMMUNES["C7"]
COMMUNES["C11a"] = COMMUNES["C11"]

with open('Introibo/Resources/communes.json', 'w') as f:
    json.dump(COMMUNES, f, indent=2, ensure_ascii=False)
print(f"Wrote {len(COMMUNES)} commune templates")
