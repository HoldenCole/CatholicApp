# Ad Altare Dei — UI Design Reference

## Design Philosophy

**Goal:** Refined liturgical. The app should feel like a beautifully typeset hand missal — not a Silicon Valley meditation app. Every screen should evoke the craftsmanship of illuminated manuscripts while remaining fully modern and usable on iOS.

**NOT this:** Hallow's gradient-heavy, rounded, "glowy" aesthetic. While polished, Hallow leans toward a contemporary wellness-app feel with soft illustrations, ambient backgrounds, and a meditation-app vibe. That's not us.

**YES this:** Think Santifica's restraint. Clean type hierarchy, generous whitespace, structured layouts. The sacred art and typography do the heavy lifting — not gradients and blur effects.

---

## Reference Apps

### Santifica (What We Like)
- **Clean, structured layouts** — content-first, no visual clutter
- **Strong typography** — serif fonts for sacred text, sans-serif for UI
- **Muted, liturgical palette** — deep reds, golds, cream/parchment backgrounds
- **Iconography** — minimal, purposeful, not illustrative
- **Card-based layout** — clear content hierarchy with subtle shadows
- **Liturgical calendar integration** — today's feast, readings, saint of the day
- **Traditional Catholic identity** — no modernist compromises on content

### Hallow (What to Avoid)
- ❌ Gradient backgrounds and ambient blur effects
- ❌ Rounded "pill" buttons everywhere (feels wellness-app, not Catholic)
- ❌ Illustrative/cartoony saint artwork
- ❌ Dark moody backgrounds as default (we use parchment)
- ❌ Audio-player-centric layout (Spotify for prayer feel)
- ❌ Gamification elements (streaks are OK, but no badges/achievements)

### What Hallow Does Well (Worth Borrowing)
- ✅ Smooth animations and transitions
- ✅ Daily personalized content on the home screen
- ✅ Clean onboarding flow
- ✅ Professional audio integration

---

## Our Visual Language

### Color Palette
| Name | Hex | Usage |
|------|-----|-------|
| Parchment | `#F5F0E8` | Primary background — like aged vellum |
| Ink | `#1C1410` | Primary text — deep brown-black |
| Sanctuary Red | `#8B1A1A` | Accent, CTAs, rubrics, stressed syllables |
| Gold Leaf | `#B8960C` | Secondary accent, dividers, icons |
| Warm White | `#FDFAF4` | Card surfaces |
| Vellum Dark | `#2A2118` | Dark mode background |
| Cream | `#EDE8DC` | Dark mode text |

**Rules:**
- Backgrounds are always warm (parchment/cream), never pure white or gray
- Red is used sparingly — rubrics, active states, primary actions
- Gold is for ornamentation — dividers, secondary icons, syllable dots
- No gradients. Flat colors with subtle shadows for depth

### Typography
| Role | Font | Why |
|------|------|-----|
| Latin / Display | Palatino | Classical, ships with iOS, evokes printed missals |
| English / Body | Georgia | Readable, traditional serif, pairs with Palatino |
| Phonetic | Palatino Italic | Distinguishes from plain Latin |
| UI Labels | SF Rounded | Friendly native iOS feel for buttons/tabs |

**Rules:**
- Latin text is always in Palatino — it's the language of the Church, it deserves the best type
- English body text in Georgia for readability
- UI chrome (tabs, buttons, captions) in SF Rounded for native iOS feel
- Never use system default San Francisco for prayer text

### Layout Principles
1. **Generous margins** — 16-20pt padding on all sides
2. **Card-based content** — warm white cards on parchment background
3. **Subtle shadows** — `shadow(color: .black.opacity(0.04), radius: 8, y: 2)` — barely there
4. **16pt corner radius** on cards — softer than sharp, not as bubbly as 24pt
5. **Gold leaf dividers** — thin 1pt lines at 30% opacity between sections
6. **Section headers** — small caps, tracked out, secondary color

### Iconography
- **SF Symbols only** — no custom illustrations in v1
- **Thin/medium weight** — not heavy/filled (except active tab)
- **Liturgical symbols** where possible: `cross.fill`, `book.closed`, `sun.horizon`

### Dark Mode
- Vellum Dark (`#2A2118`) background — warm brown, not pure black
- Cream (`#EDE8DC`) text — not pure white
- Sanctuary Red and Gold Leaf stay the same
- Cards become slightly lighter than background (`#352C22`)

---

## Screen-by-Screen Notes

### Today Tab
- Latin feria name at top in gold, small caps, tracked
- English day name large below
- Mystery cards with number circles (Sanctuary Red)
- Clean list, no hero images or gradients

### Missal Tab
- Grouped by Mass part with Latin section headers
- Each section card shows Latin title primary, English subtitle
- Detail view: true side-by-side columns like a printed missal
- Rubrics in red italic (traditional liturgical convention)

### Prayers Tab
- Grouped by category (Rosary, Mass, Devotional)
- Each prayer card: Latin name primary, English secondary
- Small "L" and "P" badges indicating Latin/Phonetic availability
- Search bar at top

### Prayer Detail
- Missal mode default: Latin left, English right, gold divider
- Toggle bar: Missal | English | Latin | Phonetic
- Phonetic view: stressed syllables in red, dots in gold
- Practice button at bottom: full-width red

### Learn Tab
- Course cards with estimated time
- Locked courses show gold lock icon
- AI tutor badge at top
- Premium paywall: elegant, not aggressive

### Progress Tab
- Mastery ring with gradient stroke (red → gold)
- Streak flame icon
- Per-prayer comfort level with expandable picker

---

## Mockup Checklist

- [ ] Today tab — mystery cards, feria header
- [ ] Missal tab — section list grouped by Mass part
- [ ] Missal detail — side-by-side Latin/English
- [ ] Prayer list — categorized with badges
- [ ] Prayer detail — missal mode with toggle
- [ ] Prayer detail — phonetic mode with colored syllables
- [ ] Learn tab — course list with premium locks
- [ ] Paywall — premium subscription screen
- [ ] Progress tab — mastery ring + prayer list
- [ ] Onboarding — 3-page flow
- [ ] Dark mode — all key screens
- [ ] Settings sheet

---

## Inspiration Sources

- Traditional hand missals (Baronius Press, Angelus Press)
- Illuminated manuscript lettering (Book of Kells aesthetic, not literal)
- Sanctifica app — clean liturgical structure
- Universalis app — strong typography, content-first
- 1962 Missale Romanum typography
