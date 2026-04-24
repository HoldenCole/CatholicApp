import Foundation

// A rotating daily psalm verse. Picks from a curated set of 30
// psalm verses, cycling by day-of-year so the same verse appears
// on the same date each year.

struct PsalmVerse {
    let ref: String
    let latin: String
    let english: String
}

enum DailyPsalm {
    static func verse(for date: Date = Date()) -> PsalmVerse {
        let day = Calendar.liturgical.ordinality(of: .day, in: .year, for: date) ?? 1
        let idx = (day - 1) % verses.count
        return verses[idx]
    }

    private static let verses: [PsalmVerse] = [
        PsalmVerse(ref: "Ps 26:4", latin: "Unam pétii a Dómino, hanc requíram: ut inhábitem in domo Dómini ómnibus diébus vitæ meæ.", english: "One thing I have asked of the Lord, this will I seek after: that I may dwell in the house of the Lord all the days of my life."),
        PsalmVerse(ref: "Ps 41:2", latin: "Quemádmodum desíderat cervus ad fontes aquárum, ita desíderat ánima mea ad te, Deus.", english: "As the hart panteth after the fountains of water, so my soul panteth after Thee, O God."),
        PsalmVerse(ref: "Ps 50:12", latin: "Cor mundum crea in me, Deus, et spíritum rectum ínnova in viscéribus meis.", english: "Create a clean heart in me, O God, and renew a right spirit within my bowels."),
        PsalmVerse(ref: "Ps 22:1", latin: "Dóminus regit me, et nihil mihi déerit; in loco páscuæ ibi me collocávit.", english: "The Lord ruleth me, and I shall want nothing; He hath set me in a place of pasture."),
        PsalmVerse(ref: "Ps 33:9", latin: "Gustáte et vidéte quóniam suávis est Dóminus; beátus vir qui sperat in eo.", english: "O taste and see that the Lord is sweet; blessed is the man that hopeth in Him."),
        PsalmVerse(ref: "Ps 118:105", latin: "Lucérna pédibus meis verbum tuum, et lumen sémitis meis.", english: "Thy word is a lamp to my feet, and a light to my paths."),
        PsalmVerse(ref: "Ps 45:11", latin: "Vacáte et vidéte quóniam ego sum Deus; exaltábor in géntibus, et exaltábor in terra.", english: "Be still and see that I am God; I will be exalted among the nations, and I will be exalted in the earth."),
        PsalmVerse(ref: "Ps 129:1-2", latin: "De profúndis clamávi ad te, Dómine; Dómine, exáudi vocem meam.", english: "Out of the depths I have cried to Thee, O Lord; Lord, hear my voice."),
        PsalmVerse(ref: "Ps 83:2-3", latin: "Quam dilécta tabernácula tua, Dómine virtútum! Concupíscit et déficit ánima mea in átria Dómini.", english: "How lovely are Thy tabernacles, O Lord of hosts! My soul longeth and fainteth for the courts of the Lord."),
        PsalmVerse(ref: "Ps 102:1", latin: "Bénedic, ánima mea, Dómino, et ómnia quæ intra me sunt nómini sancto ejus.", english: "Bless the Lord, O my soul, and let all that is within me bless His holy name."),
        PsalmVerse(ref: "Ps 18:2", latin: "Cæli enárrant glóriam Dei, et ópera mánuum ejus annúntiat firmaméntum.", english: "The heavens show forth the glory of God, and the firmament declareth the work of His hands."),
        PsalmVerse(ref: "Ps 26:1", latin: "Dóminus illuminátio mea et salus mea, quem timébo?", english: "The Lord is my light and my salvation; whom shall I fear?"),
        PsalmVerse(ref: "Ps 50:3", latin: "Miserére mei, Deus, secúndum magnam misericórdiam tuam.", english: "Have mercy on me, O God, according to Thy great mercy."),
        PsalmVerse(ref: "Ps 62:2", latin: "Deus, Deus meus, ad te de luce vígilo. Sitívit in te ánima mea.", english: "O God, my God, to Thee do I watch at break of day. For Thee my soul hath thirsted."),
        PsalmVerse(ref: "Ps 83:11", latin: "Elegi abjéctus esse in domo Dei mei magis quam habitáre in tabernáculis peccatórum.", english: "I have chosen to be an abject in the house of my God, rather than to dwell in the tabernacles of sinners."),
        PsalmVerse(ref: "Ps 115:12", latin: "Quid retríbuam Dómino pro ómnibus quæ retríbuit mihi?", english: "What shall I render to the Lord for all the things that He hath rendered unto me?"),
        PsalmVerse(ref: "Ps 8:2", latin: "Dómine, Dóminus noster, quam admirábile est nomen tuum in univérsa terra!", english: "O Lord, our Lord, how admirable is Thy name in the whole earth!"),
        PsalmVerse(ref: "Ps 138:14", latin: "Confitébor tibi quia terribíliter magnificátus es; mirabília ópera tua.", english: "I will praise Thee, for Thou art fearfully magnified; wonderful are Thy works."),
        PsalmVerse(ref: "Ps 36:5", latin: "Revéla Dómino viam tuam et spera in eo, et ipse fáciet.", english: "Commit thy way to the Lord, and trust in Him, and He will do it."),
        PsalmVerse(ref: "Ps 89:1", latin: "Dómine, refúgium factus es nobis a generatióne in generatiónem.", english: "Lord, Thou hast been our refuge from generation to generation."),
        PsalmVerse(ref: "Ps 120:1-2", latin: "Levávi óculos meos in montes, unde véniet auxílium mihi. Auxílium meum a Dómino, qui fecit cælum et terram.", english: "I have lifted up my eyes to the mountains, from whence help shall come to me. My help is from the Lord, who made heaven and earth."),
        PsalmVerse(ref: "Ps 4:9", latin: "In pace in idípsum dórmiam et requiéscam.", english: "In peace in the selfsame I will sleep, and I will rest."),
        PsalmVerse(ref: "Ps 142:10", latin: "Doce me fácere voluntátem tuam, quia Deus meus es tu.", english: "Teach me to do Thy will, for Thou art my God."),
        PsalmVerse(ref: "Ps 70:8", latin: "Repleátur os meum laude, ut cantem glóriam tuam, tota die magnitúdinem tuam.", english: "Let my mouth be filled with praise, that I may sing Thy glory, Thy greatness all the day long."),
        PsalmVerse(ref: "Ps 15:11", latin: "Notas mihi fecísti vias vitæ; adimplébis me lætítia cum vultu tuo.", english: "Thou hast made known to me the ways of life; Thou shalt fill me with joy with Thy countenance."),
        PsalmVerse(ref: "Ps 85:11", latin: "Deduc me, Dómine, in via tua, et ingrédiar in veritáte tua.", english: "Conduct me, O Lord, in Thy way, and I will walk in Thy truth."),
        PsalmVerse(ref: "Ps 144:18", latin: "Prope est Dóminus ómnibus invocántibus eum, ómnibus invocántibus eum in veritáte.", english: "The Lord is nigh unto all them that call upon Him, to all that call upon Him in truth."),
        PsalmVerse(ref: "Ps 29:12", latin: "Convertísti planctum meum in gáudium mihi; conscidísti saccum meum, et circumdedísti me lætítia.", english: "Thou hast turned for me my mourning into joy; Thou hast cut my sackcloth, and hast compassed me with gladness."),
        PsalmVerse(ref: "Ps 76:14-15", latin: "Deus, in sancto via tua; quis Deus magnus sicut Deus noster? Tu es Deus qui facis mirabília.", english: "Thy way, O God, is in the holy place; who is the great God like our God? Thou art the God that dost wonders."),
        PsalmVerse(ref: "Ps 116:1-2", latin: "Laudáte Dóminum, omnes gentes; laudáte eum, omnes pópuli. Quóniam confirmáta est super nos misericórdia ejus.", english: "O praise the Lord, all ye nations; praise Him, all ye people. For His mercy is confirmed upon us."),
    ]
}
