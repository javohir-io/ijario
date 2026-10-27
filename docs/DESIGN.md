# Ijario design system

Source of truth for how Ijario looks and moves. Everything here is implemented
in `ijario-app/lib/theme/` and `ijario-app/lib/widgets/`.

## 1. Direction

**Quiet luxury for an everyday need.** Renting a flat is stressful and money-heavy;
the app should feel calm, warm and trustworthy, like a well-kept apartment, not a
classifieds board. The reference photo (arched window, herringbone oak, oxblood sofa)
set the tone: generous curves, deep red, warm wood, grey plaster.

Three decisions carry the whole look:

1. **Oxblood field + raw-oak light.** The only saturated surface is the aurora
   (hero, splash, welcome, auth). Everything else is quiet neutrals.
2. **Serif italic headlines, sans for everything functional.** Cormorant Garamond
   Italic is the face on the palette card; Manrope does the work (it covers
   Latin-Extended and Cyrillic, so Uzbek and Russian listings both render).
3. **One signature shape: the arch.** The logo, the empty states and the photo
   placeholders all use the arched doorway from the reference window.

## 2. Colour

Measured from the palette card (pixel samples matched the printed hex values).

| Token | Hex | Role |
|---|---|---|
| Oxblood | `#5E1E2B` | Brand: primary button (light), selected states, aurora |
| Raw Oak | `#D2BCA8` | Warm accent: primary button (dark), highlights, nav selection |
| Plaster | `#DADCDD` | Light neutral: fills, text on dark |
| Concrete | `#9C9D9B` | Mid neutral: borders, icons, muted text on dark |
| Obsidian | `#202020` | Ink in light mode, ground in dark mode |

Derived tints (each is one palette colour lightened/darkened, named in `tokens.dart`):
`oxbloodDeep`, `oxbloodGlow`, `plasterTint` (app background), `paper` (cards),
`inkMuted`, `obsidianRaised`, `obsidianHigh`.

**Contrast:** Concrete on Plaster is only ~2.3:1, so it is never used for essential
text in light mode. Secondary text uses `inkMuted` (Concrete darkened, ≥4.5:1).
**Semantic colours** (green for "cheap / confirmed", red for "expensive / error") are the
only non-palette hues, used only where meaning needs them.

## 3. Type

| Style | Font | Size |
|---|---|---|
| hero / display / headline / subhead | Cormorant Garamond Italic 600/500 | 52 / 38 / 28 / 22 |
| price | Manrope 800 | 22 (32 on detail) |
| title / body / small / label / button | Manrope 700 / 500 / 500 / 700 / 700 | 17 / 15 / 13 / 12.5 / 16 |

Sentence case everywhere. Fonts are bundled (instanced from the Google Fonts variable
files, subset to Latin + Cyrillic), so the app never waits on a font download.

## 4. Shape and space

Different things get different radii: thumbs 14 · fields 20 · cards 28 · sheets 36 ·
buttons and chips full pill. Page margin 20. Touch targets are at least 44 px
(buttons 56). Wide screens (web) keep content to a readable column.

## 5. Motion — "Premium" archetype

Rules from the motion-design skill, as implemented in `BMotion`:

- **One signature curve**, `cubic-bezier(0.4, 0, 0.2, 1)`, for ~80% of animation.
- Durations: press 120 ms · state 250 ms · enter/page 500 ms · logo reveal 800 ms.
- **Stagger 70 ms**, capped at 6 items (never more than ~420 ms of waiting).
- **No overshoot**, except one earned moment: the saved-heart pop (1.0 → 1.15 → 1.0).
- Entrances are longer than exits.
- **Ambient motion exists once:** the aurora drift (28 s seamless loop) and the logo's
  light sweep (every 9 s).
- **Reduce motion** is honoured everywhere: ambient loops stop, reveals just appear.
- Tabs that aren't visible stop their animations (`TickerMode`).

## 6. Depth and glass

The look is *layered*: a glowing ground, translucent raised surfaces, and real glass only
where something floats over moving content.

| Layer | What | Where (code) |
|---|---|---|
| Ground | Fixed, soft oxblood + raw-oak glows behind every tab; content scrolls over it | `AppBackdrop` |
| Raised surfaces | Translucent gradient fill (light from the top-left), a 1 px rim, a two-layer shadow tinted with the brand colour in light mode | `BDeco.card` (tokens) |
| Lit controls | Primary button, selected chips and chat bubbles are gradients lit from above, with a coloured shadow | `BDeco.primary`, `BDeco.selected` |
| Perspective | Listing cards tilt toward the cursor/finger in real 3-D perspective (max ~4°) with a glare that follows the light | `Tilt3D` |
| Real glass | Backdrop blur + rim light, only on the nav bar, buttons over photos and the booking bar | `Glass` |

Why the cards are *not* blurred: behind them the background is a smooth gradient, so a blur
would look identical but cost a lot of frame time across a long list. Blur is kept where
there is detail to blur (photos, scrolling content under the nav).

Tuning knobs, all in one place: shadow and glow strengths in `BPalette` (`tokens.dart`),
tilt angle in `Tilt3D.maxAngle`.

## 6b. Glass — used sparingly

Glass appears only on controls that float over moving or photographic content: the
bottom navigation, buttons over photos, the booking bar. Never on ordinary cards.
Implementation (`widgets/glass.dart`): backdrop blur + a faint tint gradient + a 1 px
"rim light" stroke that is bright top-left / bottom-right and dark between.

## 7. What was learned from each reference repo

The brief pointed at nine repositories. Most are JavaScript/WebGL libraries, which
cannot be imported into a Flutter app, so what was taken is their *technique and
discipline*, re-implemented natively:

| Repo | Taken | Where |
|---|---|---|
| **genjutsu** | Design-system-before-screens; the "AI tells" list (no rainbow gradients, no gratuitous glassmorphism, no invented data); mobile rules (thumb-zone CTAs, safe areas, 44 px targets, 60 fps) | whole app; empty states, honest price insight |
| **motion-design-skill** | Archetype tables (timing, easing, stagger, overshoot budget), ambient-motion rules | `BMotion`, `Reveal`, `Pressable`, `SaveButton` |
| **design-dna** | Measure colours from the image instead of eyeballing | palette tokens |
| **liquid-glass-js** | Edge "rim light" + blur as what makes glass read as glass | `Glass` |
| **shadergradient** | Slow flowing gradient planes as a brand backdrop | `AuroraBackground` (plain radial gradients, so no shader compilation) |
| **liquid-logo** | Metallic, light-sweeping logo mark | `IjarioMark`, app icon |
| **gsap-skills** | Choreography: staggers, timelines, scroll-linked parallax | `Reveal`, the detail-page gallery parallax |
| **threejs-skills / react-three-fiber** | Reviewed. **Not used in the app**: a 3-D scene would add weight to a list-and-form app without helping anyone rent a flat. They would suit a marketing site. | – |

## 8. Voice

Short, plain Uzbek, active verbs, same words as the button that caused the thing
("Saqlandi", "So'rov yuborildi"). No exclamation marks, no filler. Apostrophes are
the plain ASCII `'` (`O'rtacha`, `E'lon`), which every font renders.
