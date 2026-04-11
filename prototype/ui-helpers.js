// ===== Shared UI helpers for Ad Altare Dei prototypes =====
// - escapeHtml(s): HTML-safe string escape (< > & " ')
// - toRoman(n): integer to Roman numerals (1..30, then decimal fallback)
// - global ESC key handler that closes any .overlay.show
// Load via <script src="ui-helpers.js"></script> in <head>.
// Each page's local overlay show/hide functions are unaffected.

(function(global){
  var ENTS = {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'};
  function escapeHtml(s){
    return String(s==null?'':s).replace(/[&<>"']/g, function(c){ return ENTS[c]; });
  }

  var ROMAN = ['','I','II','III','IV','V','VI','VII','VIII','IX','X',
               'XI','XII','XIII','XIV','XV','XVI','XVII','XVIII','XIX','XX',
               'XXI','XXII','XXIII','XXIV','XXV','XXVI','XXVII','XXVIII','XXIX','XXX'];
  function toRoman(n){
    return n < ROMAN.length ? ROMAN[n] : String(n);
  }

  // Global ESC key: close any visible .overlay.show on any page.
  // Each page's local hide function still works; this is an additional
  // affordance for keyboard users.
  if (typeof document !== 'undefined') {
    document.addEventListener('keydown', function(e){
      if (e.key === 'Escape' || e.key === 'Esc') {
        var open = document.querySelectorAll('.overlay.show');
        open.forEach(function(o){ o.classList.remove('show'); });
      }
    });
  }

  global.escapeHtml = escapeHtml;
  global.toRoman = toRoman;
})(typeof window !== 'undefined' ? window : this);
