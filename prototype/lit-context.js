// ===== Shared Liturgical Context for Introibo prototypes =====
// Provides getLiturgicalContext(date) and a few helpers used across pages.
// All prototypes that care about feria / season / colour / mystery / Marian
// antiphon / Lenten state should <script src="lit-context.js"></script> this.

(function(global){
  // ---- Computus: Anonymous Gregorian algorithm for Easter Sunday ----
  function easterFor(year){
    var a=year%19, b=Math.floor(year/100), c=year%100;
    var d=Math.floor(b/4), e=b%4;
    var f=Math.floor((b+8)/25);
    var g=Math.floor((b-f+1)/3);
    var h=(19*a+b-d-g+15)%30;
    var i=Math.floor(c/4), k=c%4;
    var l=(32+2*e+2*i-h-k)%7;
    var m=Math.floor((a+11*h+22*l)/451);
    var month=Math.floor((h+l-7*m+114)/31);
    var day=((h+l-7*m+114)%31)+1;
    return new Date(year,month-1,day);
  }
  function dateAdd(d,n){var x=new Date(d);x.setDate(x.getDate()+n);return x}
  function sameOrAfter(a,b){return a.getTime()>=b.getTime()}
  function sameOrBefore(a,b){return a.getTime()<=b.getTime()}

  // ---- Day-of-week labels ----
  var FERIA_LAT=['Domínica','Feria Secúnda','Feria Tértia','Feria Quarta','Feria Quinta','Feria Sexta','Sábbato'];
  var FERIA_ENG=['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];

  // ---- Traditional Rosary mystery schedule (1962, no Luminous) ----
  // Sun: Glorious  Mon: Joyful  Tue: Sorrowful  Wed: Glorious
  // Thu: Joyful    Fri: Sorrowful  Sat: Glorious
  var MYSTERY_BY_DOW=['glorious','joyful','sorrowful','glorious','joyful','sorrowful','glorious'];
  var MYSTERY_LAT={glorious:'Mystéria Gloriósa',sorrowful:'Mystéria Dolorósa',joyful:'Mystéria Gaudiósa'};
  var MYSTERY_ENG={glorious:'Glorious Mysteries',sorrowful:'Sorrowful Mysteries',joyful:'Joyful Mysteries'};

  // ---- Liturgical colour palette (hex) ----
  var COLOUR_HEX={violet:'#6A359A',rose:'#a04860',white:'#7a5a0e',red:'#8B1A1A',green:'#3a5d28'};

  function getLiturgicalContext(now){
    now=now||new Date();
    var year=now.getFullYear();
    var easter=easterFor(year);
    var ashWed=dateAdd(easter,-46);
    var passionStart=dateAdd(easter,-14);   // Passion Sunday
    var holyWed=dateAdd(easter,-4);
    var pentecost=dateAdd(easter,49);
    var trinity=dateAdd(easter,56);
    var christmas=new Date(year,11,25);
    var candlemas=new Date(year,1,2);
    var advent1=new Date(year,11,25);
    while(advent1.getDay()!==0)advent1=dateAdd(advent1,-1);
    advent1=dateAdd(advent1,-21);

    // ---- Season detection ----
    var season,colour,latName,engName;
    if(sameOrAfter(now,advent1) && sameOrBefore(now,dateAdd(christmas,-1))){
      season='advent';colour='violet';latName='Tempus Advéntus';engName='Advent';
    } else if(sameOrAfter(now,christmas) || sameOrBefore(now,dateAdd(candlemas,-1))){
      season='christmas';colour='white';latName='Tempus Nativitátis';engName='Christmastide';
    } else if(sameOrAfter(now,ashWed) && sameOrBefore(now,dateAdd(easter,-1))){
      if(sameOrAfter(now,passionStart)){
        season='passion';colour='violet';latName='Tempus Passiónis';engName='Passiontide';
      } else {
        season='lent';colour='violet';latName='Quadragésima';engName='Lent';
      }
    } else if(now.getTime()===pentecost.getTime()){
      season='pentecost';colour='red';latName='Pentecóste';engName='Pentecost';
    } else if(sameOrAfter(now,easter) && sameOrBefore(now,dateAdd(trinity,-1))){
      // Eastertide includes the Octave of Pentecost — runs through Sat before Trinity
      season='easter';colour='white';latName='Tempus Paschále';engName='Eastertide';
    } else if(sameOrAfter(now,trinity)){
      season='per_annum';colour='green';latName='Tempus post Pentecósten';engName='Time after Pentecost';
    } else {
      season='per_annum';colour='green';latName='Tempus post Epiphaníam';engName='Time after Epiphany';
    }

    var dow=now.getDay();
    var isLent=(season==='lent'||season==='passion');
    var isFriday=(dow===5);
    var isSunday=(dow===0);

    // ---- Marian antiphon for Compline ----
    var marian;
    if(sameOrAfter(now,advent1) || sameOrBefore(now,dateAdd(candlemas,-1))){
      marian='alma';
    } else if(sameOrAfter(now,candlemas) && sameOrBefore(now,holyWed)){
      marian='ave';
    } else if(sameOrAfter(now,easter) && sameOrBefore(now,dateAdd(trinity,-1))){
      marian='regina';
    } else {
      marian='salve';
    }

    // ---- Today's Rosary mystery (with seasonal overrides) ----
    // Traditional override: Sunday in Advent = Joyful, Sunday in Lent = Sorrowful
    var mysteryKey=MYSTERY_BY_DOW[dow];
    if(isSunday && season==='advent')mysteryKey='joyful';
    if(isSunday && (season==='lent'||season==='passion'))mysteryKey='sorrowful';

    // ---- Day's penance (1962 norms) ----
    // Friday: abstinence from flesh-meat (perpetual)
    // Lenten weekdays: fast (one full meal + two collations) + Friday abstinence
    // Holy Saturday morning: fast continues until midday
    var penance;
    if(isLent && isFriday){
      penance={
        title:'Lenten Friday',
        latin:'Feria Sexta in Quadragésima',
        desc:'Abstinence from flesh-meat. Those of fasting age observe the Lenten fast: one full meal and two small collations.',
        rubric:'℟. Quadragésima · Feria Sexta',
        strict:true
      };
    } else if(isLent){
      penance={
        title:'Lenten Fast',
        latin:'Ieiúnium Quadragesimále',
        desc:'Those of fasting age (21–59) observe the Lenten fast: one full meal and two small collations. Wednesdays in Lent are also days of abstinence.',
        rubric:'℟. ' + FERIA_LAT[dow] + ' in Quadragésima',
        strict:true
      };
    } else if(isFriday){
      penance={
        title:'Friday Abstinence',
        latin:'Feria Sexta',
        desc:'Abstain from the flesh of warm-blooded animals, in memory of the Passion of Our Lord.',
        rubric:'℟. Feria Sexta',
        strict:false
      };
    } else if(season==='advent' && (dow===3||dow===5||dow===6)){
      // Ember Days fall on Wed/Fri/Sat of Advent's third week, but for the
      // prototype we just flag Wed/Fri/Sat in Advent as a gentle reminder.
      penance={
        title:'Advent Penance',
        latin:'Tempus Advéntus',
        desc:'A penitential season. Offer voluntary fasts and almsgiving as you prepare for the coming of the Lord.',
        rubric:'℟. ' + FERIA_LAT[dow] + ' in Advéntu',
        strict:false
      };
    } else if(isSunday){
      penance={
        title:'Day of the Lord',
        latin:'Dies Domínica',
        desc:'No obligation of fasting or abstinence. Rest in the Lord and attend Holy Mass.',
        rubric:'℟. Domínica',
        strict:false
      };
    } else {
      penance={
        title:'No obligatory penance',
        latin:'Nulla pænitentia obligatória',
        desc:'A free day. Voluntary mortifications are always meritorious — choose a small sacrifice as your daily offering.',
        rubric:'℟. ' + FERIA_LAT[dow],
        strict:false
      };
    }

    // ---- Plenary indulgence flags ----
    var indulgences={};
    if(isFriday && isLent){
      indulgences.crucifix=true;  // Prayer Before a Crucifix grants plenary indulgence on Lenten Fridays
    }

    return {
      season:season,
      colour:colour,
      colourHex:COLOUR_HEX[colour]||'#8B1A1A',
      latName:latName,
      engName:engName,
      feriaLat:FERIA_LAT[dow],
      feriaEng:FERIA_ENG[dow],
      dow:dow,
      isSunday:isSunday,
      isFriday:isFriday,
      isLent:isLent,
      marian:marian,
      mystery:mysteryKey,
      mysteryLat:MYSTERY_LAT[mysteryKey],
      mysteryEng:MYSTERY_ENG[mysteryKey],
      penance:penance,
      indulgences:indulgences,
      // Computed dates (useful elsewhere)
      easter:easter,
      ashWed:ashWed,
      pentecost:pentecost,
      trinity:trinity,
      advent1:advent1
    };
  }

  // Format a JS Date as "the twenty-eighth of March"
  function formatLongDate(d){
    var months=['January','February','March','April','May','June','July','August','September','October','November','December'];
    var ord=['','first','second','third','fourth','fifth','sixth','seventh','eighth','ninth','tenth','eleventh','twelfth','thirteenth','fourteenth','fifteenth','sixteenth','seventeenth','eighteenth','nineteenth','twentieth','twenty-first','twenty-second','twenty-third','twenty-fourth','twenty-fifth','twenty-sixth','twenty-seventh','twenty-eighth','twenty-ninth','thirtieth','thirty-first'];
    return 'the '+ord[d.getDate()]+' of '+months[d.getMonth()];
  }

  global.LitContext={
    get:getLiturgicalContext,
    easterFor:easterFor,
    formatLongDate:formatLongDate,
    COLOUR_HEX:COLOUR_HEX
  };
})(typeof window!=='undefined'?window:this);
