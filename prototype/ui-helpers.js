// ===== Shared UI helpers for Ad Altare Dei prototypes =====
// Load via <script src="ui-helpers.js"></script> in <head>.
//
// Provides:
//   escapeHtml(s)          — HTML-safe string escape
//   toRoman(n)             — integer to Roman numeral (1..30)
//   Overlay.open(el|id)    — show an overlay by element or ID
//   Overlay.close()        — close all visible overlays
//   Storage.get(key, fb)   — localStorage.getItem with fallback
//   Storage.getJSON(key,fb)— parse JSON from localStorage
//   Storage.set(key, val)  — localStorage.setItem (safe)
//   Storage.remove(key)    — localStorage.removeItem (safe)
//   Global ESC key handler — closes any .overlay.show

(function(global){
  // ---- escapeHtml ----
  var ENTS = {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'};
  function escapeHtml(s){
    return String(s==null?'':s).replace(/[&<>"']/g, function(c){ return ENTS[c]; });
  }

  // ---- toRoman ----
  var ROMAN = ['','I','II','III','IV','V','VI','VII','VIII','IX','X',
               'XI','XII','XIII','XIV','XV','XVI','XVII','XVIII','XIX','XX',
               'XXI','XXII','XXIII','XXIV','XXV','XXVI','XXVII','XXVIII','XXIX','XXX'];
  function toRoman(n){
    return n < ROMAN.length ? ROMAN[n] : String(n);
  }

  // ---- Overlay ----
  // Shared open/close for the .overlay.show pattern used on every page.
  // Pages can still define local show*/hide* wrappers that call these.
  var Overlay = {
    open: function(elOrId){
      var el = typeof elOrId === 'string' ? document.getElementById(elOrId) : elOrId;
      if(el){ el.classList.add('show'); window.scrollTo(0,0); }
    },
    close: function(){
      var open = document.querySelectorAll('.overlay.show, .settings-overlay.show');
      open.forEach(function(o){ o.classList.remove('show'); });
    }
  };

  // ---- Storage ----
  // Thin wrapper around localStorage with try-catch, namespaced under aad.*
  var Storage = {
    get: function(key, fallback){
      try{ var v = localStorage.getItem(key); return v == null ? fallback : v; }
      catch(e){ return fallback; }
    },
    getJSON: function(key, fallback){
      try{ return JSON.parse(localStorage.getItem(key) || 'null') || fallback; }
      catch(e){ return fallback; }
    },
    set: function(key, val){
      try{ localStorage.setItem(key, typeof val === 'object' ? JSON.stringify(val) : val); }
      catch(e){}
    },
    remove: function(key){
      try{ localStorage.removeItem(key); }
      catch(e){}
    }
  };

  // ---- Dark mode auto-apply ----
  // Reads aad.settings.darkMode from localStorage and applies
  // body.dark class immediately (before first paint if possible).
  function applyDarkMode(){
    if (typeof document === 'undefined') return;
    var dark = Storage.get('aad.settings.darkMode','false') === 'true';
    if (dark) document.body.classList.add('dark');
    else document.body.classList.remove('dark');
  }
  function toggleDarkMode(){
    var cur = Storage.get('aad.settings.darkMode','false') === 'true';
    Storage.set('aad.settings.darkMode', cur ? 'false' : 'true');
    applyDarkMode();
  }

  // ---- Global ESC key handler ----
  if (typeof document !== 'undefined') {
    document.addEventListener('keydown', function(e){
      if (e.key === 'Escape' || e.key === 'Esc') {
        Overlay.close();
      }
    });
    // Apply dark mode on load
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', applyDarkMode);
    } else {
      applyDarkMode();
    }
  }

  // Export
  global.escapeHtml = escapeHtml;
  global.toRoman = toRoman;
  global.Overlay = Overlay;
  global.Storage = Storage;
  global.applyDarkMode = applyDarkMode;
  global.toggleDarkMode = toggleDarkMode;
})(typeof window !== 'undefined' ? window : this);
