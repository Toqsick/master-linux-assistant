# MLA-Next Tokens — GTK4/libadwaita (Issue #91, A1)

> Stand: 2026-09-30 · Branch `feature/mla-91-tokens` · Plan:
> `docs/superpowers/plans/2026-09-30-mla-91-tokens.md`
>
> **Quelle der Wahrheit für Farbwerte:** `lib/layouts/hermes_tokens.dart`
> (light `:98-132`, dark `:135-162`). Diese Datei portiert sie 1:1 in den
> GTK-Track; Abweichungen sind nur dokumentiert, nie zurückgeportet.
> Umsetzung: `prototype/gtk/tokens.css`, geprüft durch
> `prototype/gtk/tests/test_tokens.py` (Konsistenz, Kontrast, Hardcode-Gate).

## 1. Farb-Tokens (26, hell und dunkel)

Schreibweise: opake Farben als `#RRGGBB`, transparente als `rgba(r,g,b,a)`
(die Alpha-Stufen entsprechen `Color(0xAARRGGBB)` aus HermesTokens:
`0x0D`→0.051, `0x08`→0.031, `0x0A`→0.039, `0x0F`→0.059, `0x59`→0.349).

| Token | CSS-Name | Light | Dark | Verwendung |
|---|---|---|---|---|
| bg | `bg` | #FEFCF7 | #0D0D1A | Fensterhintergrund |
| sidebar | `sidebar` | #FAF7F0 | #141425 | Navigationsseitenleiste |
| surface | `surface` | #F3EEE3 | #1A1A2E | Karten, angehobene Flächen |
| surfaceSubtle | `surface-subtle` | #F7F4EC | #16162A | sekundäre Flächen, Badges (Neutral) |
| surfaceSubtleHover | `surface-subtle-hover` | #EFEADF | #1F1F35 | Hover-Zustand dazu |
| border | `border` | #E0D8C8 | #2A2A45 | Hairline-Border (1px) |
| borderMuted | `border-muted` | #D0C6B2 | #3A3A58 | stärkere Trennlinien |
| borderSubtle | `border-subtle` | #EAE4D8 | #20203A | zarte Trennlinien |
| text | `text` | #1A1610 | #FFF8DC | Fließtext |
| strong | `strong` | #0F0D08 | #FFFFFF | betonte Werte, Titel |
| muted | `muted` | #5C5344 | #C0C0C0 | Metadaten, Sekundärtext |
| accent | `accent` | #B8860B | #FFD700 | Golden — Akzentflächen, aktive Markierung |
| accentHover | `accent-hover` | #996F08 | #FFBF00 | Akzent-Hover |
| accentText | `accent-text` | #7F5C08 | #FFD700 | Akzentfarbe als Text (light 2 Stufen dunkler für AA) |
| accentBg | `accent-bg` | #F8F2E4 | #201D18 | Akzent-Fläche 8 % (vorgeblendet) |
| accentBgStrong | `accent-bg-strong` | #F1E7CE | #322D1D | Akzent-Fläche 15 % (vorgeblendet) |
| onAccent | `on-accent` | #1A1610 | #0D0D1A | Text/Icons auf Akzent (bewusst dunkle Tinte, nicht Weiß) |
| error | `error` | #C62828 | #EF5350 | Fehler, crit/failed |
| success | `success` | #2E7D32 | #4CAF50 | Erfolg, ok |
| warning | `warning` | #B45309 | #FFA726 | Warnung, warn |
| info | `info` | #05748F | #4DD0E1 | Information, running |
| hoverBg | `hover-bg` | rgba(0,0,0,0.051) | rgba(255,255,255,0.059) | generische Hover-Überlagerung |
| inputBg | `input-bg` | rgba(0,0,0,0.031) | rgba(255,255,255,0.039) | Eingabefelder |
| focusRing | `focus-ring` | rgba(184,134,11,0.349) | rgba(255,215,0,0.349) | sichtbarer Fokusring (35 % Akzent) |
| codeBg | `code-bg` | #F5F0E5 | #1A1A2E | Code-Blöcke |
| codeText | `code-text` | #8B4513 | #F0C27F | Code-Inhalt |

**Dark-Regeln (wie Hermes):** Semantische Farben (error/success/warning/info)
**hellen im Dunkelmodus auf** statt fix zu bleiben; der Akzent wechselt von
Golden `#B8860B` (light) zu `#FFD700` (dark); `onAccent` bleibt in beiden
Schemata dunkle Tinte. Elevation entsteht aus 1px-Border, nicht aus Schatten.

## 2. Struktur-Tokens

| Token | Wert | Verwendung |
|---|---|---|
| space1 | 4 | Innenabstände kompakt |
| space2 | 8 | Innenabstände Standard |
| space3 | 12 | Abstände Gruppen ↔ Elemente |
| space4 | 16 | Außenabstände Standard |
| space5 | 24 | **GTK-Zusatz** (kein Hermes-Pendant): Flächen-Rahmenabstand großer Fenster |
| radiusSm / radiusMd / radiusLg / radiusPill | 4 / 8 / 12 / 999 | Ecken; Pill für Badges |
| borderWidth | 1 | Hairline überall, keine Schatten |
| spineWidth | 2 | Akzent-Rücken aktiver Nav-Items |
| opacityFaint / opacityMuted / opacityStrong | 0.42 / 0.56 / 0.75 | Entwertung von Metadaten über Opacity, nie über andere Farbe |
| fontMono | `monospace` | generischer Alias (kein gebundelter Font) |
| layoutSidebarMin | 280 | Mindestbreite rechte Detail-Leiste |
| layoutPanePos | 850 | Startposition des Trenners (Gtk.Paned) |
| layoutWindow | 1200 × 780 | Fenster-Defaultgröße |

## 3. Typografie (Adw-Klassen als Typo-Tokens)

GTK nutzt die libadwaita-Stilklassen; Pixel-Parität zur Flutter-App ist kein
Ziel, **Rangstufen-Parität** schon. Adw-Größen sind Punkt-basiert und folgen
der System-Skalierung (100/125/150 %).

| Rang | GTK (Adw-Klasse) | Flutter (MintY/Hermes) |
|---|---|---|
| 1 | `title-1` | heading1, 32 px w500 |
| 2 | `title-2` | heading2, 24 px |
| 3 | `title-3` | heading3, 20 px |
| 4 | `title-4` | heading4, 17 px |
| Fließtext | `body` | paragraph, 15 px |
| Betont/Support | `heading` / `caption` | 12–13 px Support |
| Metadaten | `caption` (klein) + `opacityMuted` | 11 px uppercase w600 (Hermes-Stat-Tile-Stil) |
| Code/Werte | `fontMono` | `HermesTokens.fontMono` |

## 4. Status-/Ampel-Tokens (Tone-Mapping, keine neuen Farben)

Zustandsvokabular aus IPC_CONTRACT (`ok|warn|crit|unknown`) und ProbeState
(`unknown|running|ok|stale|failed`). Tone-Formel wie Hermes-Badges
(`hermes_badge.dart:25-52`): **fg = Basisfarbe solid, bg = Basisfarbe 10 %
auf `bg` vorgeblendet, border = Basisfarbe 28 % auf `bg` vorgeblendet.**

| Zustand | Basisfarbe | Struktur |
|---|---|---|
| ok | success | solide Border |
| warn | warning | solide Border |
| crit / failed | error | solide Border |
| running | info | solide Border |
| unknown | muted (Neutral-Tone: fg `muted`, bg `surfaceSubtle`, border `border`) | solide Border |
| **stale** | wie unknown | **gestrichelte Border** — Struktur- statt Farbunterschied |

**stale ≠ ok ist Strukturregel:** `stale` darf niemals wie `ok` aussehen —
der Unterschied ist formgebunden (gestrichelt) und damit farbenblindsicher
(«stale ist UI-/Transportstatus, nicht stillschweigend ok»,
IPC_CONTRACT.md:16).

## 5. Kontrast-Ziele (vom Task-Spec gesetzt, ISSUES.md #91 Abnahme 2)

- **Text-Paare: WCAG AA ≥ 4,5:1** — Paarliste analog
  `test/hermes_tokens_test.dart:11-28`, je Schema (light/dark) 16 Paare:
  text/bg, text/surface, text/surfaceSubtle, text/sidebar, strong/bg,
  muted/bg, muted/surfaceSubtle, accentText/bg, accentText/accentBg,
  accentText/accentBgStrong, onAccent/accent, error/bg, success/bg,
  warning/bg, info/bg, codeText/codeBg.
- **Non-Text: ≥ 3:1** — focusRing auf bg (Alpha 35 % auf bg vorgeblendet).
- Geprüft maschinell in `prototype/gtk/tests/test_tokens.py` (WCAG-2.2-
  Luminanz/Formel wie `hermes_tokens.dart:204-224`); Alpha-Farben werden vor
  der Prüfung auf bg kompositiert.

## 6. Fokus-Regeln

- Jeder fokussierbare Bereich (Sidebar-Rows, Buttons, Eingaben, Details)
  zeigt einen **sichtbaren Fokusring**: `:focus-visible`-Outline in
  `focus-ring` (35 % Akzent), 2 px, Abstand 2 px.
- Vollständige Tab-/Pfeiltasten-Reihenfolge; der Durchgang am lebenden System
  ist Teil der manuellen Gate-0-Checks (BASELINE §3 Punkt 6, Basti).

## 7. Screenshot-Regeln

- Screenshots nur als `/tmp`-Artefakte, **nie ins Repo**; ohne Secrets
  (Fixtures/Demo-Daten only).
- Hell/Dunkel erzwingbar über `MLA_FORCE_COLOR_SCHEME=light|dark`
  (Test-Affordance, wirkt nur innerhalb der App über
  `Adw.StyleManager.set_color_scheme`; keine Systemeinstellung).
- X11 maschinell (xdotool+import, Rezept BASELINE §2); **Wayland-Screenshot
  bleibt manuell** (gnome-screenshot fehlt, D-Bus verweigert; BASELINE §6.2).

## 8. Anwendung in der Shell

CSS-Klassen mit Präfix `mla-`: `.mla-space-3` (Abstände), `.mla-screen`
(Seitenrahmen), `.mla-details` (rechte Leiste), `.mla-tone-ok` …
`.mla-tone-stale` (Status), `.mla-focus`-Outline global über
`:focus-visible`. Keine Hex-Farben außerhalb `tokens.css` — durchgesetzt per
Regex-Gate in `test_tokens.py` (heute einziger Verstoß: `#b8860b` in
`mla_app.py:84`, durch dieses Paket beseitigt).
