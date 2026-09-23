# Design-System

Referenz: `docs/design/linux-assistant-design-system.md` · Audit:
`docs/design/design-audit-*.md`

## Zwei Ebenen

### Mint-Y (Upstream-Basis)

`lib/layouts/mint_y.dart` + `lib/layouts/mint_y_tokens.dart`: Das klassische
Komponenten-Set der App (MintYPage, MintYButton, MintYTable, …) plus Token-
Definitionen. Distro-Akzente über `MintYAccent` (mint, debian, opensuse,
kde_neon, lmde, zorin, …), gesetzt in `main.dart` anhand der erkannten
Distribution.

### Hermes (Fork-Layer)

`lib/layouts/hermes_tokens.dart` + `lib/widgets/hermes/`: Die visuelle
Sprache des Hubs. Kernideen:

- **Elevation ohne Schatten:** 1-px-Border + Tint statt Drop-Shadow
- **Tint-Triade:** ~8-10 % Hintergrund, ~28 % Border, Vollton als Text
  (implementiert in `hermesToneColors`)
- **Akzent-Spine:** 2-px-Balken links markiert Auswahl/aktive Karte
- **Opacity als Hierarchie-Hebel** für Metadaten (kein zweiter Farbton)

## Token-Überblick

| Kategorie | Beispiele |
|---|---|
| Flächen | `t.bg`, `t.surface`, `t.sidebar`, `t.surfaceSubtleHover` |
| Text | `t.strong`, `t.text`, `t.muted`, `t.onAccent` |
| Akzent | `t.accent`, `t.accentHover`, `t.accentBg`, `t.accentText` |
| Semantik | `t.success`, `t.warning`, `t.error`, `t.info` |
| Borders | `t.border`, `t.borderSubtle` |
| Code | `t.codeBg`, `t.codeText`, `HermesTokens.fontMono` |
| Abstände | `HermesTokens.space1…space4`, `radiusSm/Md/Pill`, `spineWidth` |

Zugriff im Code: `final t = HermesTokens.of(context);`

## Widget-Katalog (Hermes)

| Widget | Zweck |
|---|---|
| `HermesCard` | Basis-Fläche (optional `spineColor`, `onTap`) |
| `HermesSectionHeader` | Uppercase-Label + Trennlinie über Kartengruppen |
| `HermesStatTile` | Label + großer Wert + Badge + Visual + Footer |
| `HermesMetaRow` | Kompakte `label — value`-Zeile (tabular figures) |
| `HermesSparkline` | CustomPainter-Linienchart (≤ 60 Punkte, kein fl_chart) |
| `HermesBadge` | Pill mit Tint + optionalem Icon, `dense`-Variante |
| `HermesHaloDot` | 7-px-Statuspunkt mit Halo |
| `HermesNavItem` | Sidebar-Zeile (Hover, selected, collapsed-Rail) |
| `HermesCopyCommand` | Mono-Kommandozeile mit Copy-Button (zeigt, führt nie aus) |

## Regeln (aus dem Design-Audit)

1. **Keine hartcodierten Farben in neuen Screens** – immer Tokens. Bekannte
   Alt-Verstöße sind in `design-audit-inconsistencies.md` priorisiert
   (z. B. `Colors.grey` Info-Box, `Colors.black54` in power_mode).
2. **Destructive = Confirm-Dialog** mit konkretem Objekt (Name/Pfad), rote
   Aktion (`statusDanger`/`t.error`).
3. **Neue Screens bekommen Goldens** – Setup-Stand siehe [[Testing]].
4. Sidebar-Labels: klein, muted, uppercase, letter-spaced (Muster:
   „EINGEBUNDENE DATENTRÄGER“).

## Laufende Migration

PR B (#10) migriert Dashboard-Widgets auf die `MintYColors`-ThemeExtension.
Sonderfall aus dem Audit: der Dark-Mode-Mutations-Hack in
`single_bar_chart.dart` wurde **ersetzt** — die Farben werden pro `build()`
aufgelöst; die hartcodierten `Color.fromARGB`-Dark-Fallbacks stehen noch
zur Token-Migration an.
