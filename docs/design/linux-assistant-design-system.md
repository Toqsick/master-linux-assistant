# Linux Assistant Design System
## „Mint-Y / Hermes" – Extrahiert aus Toqsick/master-linux-assistant (Flutter, Material 3)

> Quelle: `lib/layouts/mint_y.dart`, `lib/main.dart`, `lib/widgets/*`, `lib/layouts/hermes_tokens.dart` (Fork),
> `linux/my_application.cc`. Alle Werte wurden direkt aus dem Code verifiziert.

---

## 1. Design-Prinzipien

1. **Distro-Adaptive Theming** – Die Akzentfarbe wechselt automatisch je nach erkannter Distribution (`setMainColor()` in `main.dart`).
2. **Material 3, dunkel zuerst** – `useMaterial3: true`, Dark-Theme ist der Standard-Zustand der App.
3. **Eine Akzentfarbe regiert alles** – `MintY.currentColor` steuert Buttons, Checkboxen, Icons, Textselektion, Fortschrittsbalken.
4. **Flache Karten, runde Ecken** – keine Schatten-Hierarchie, Tiefe entsteht über Flächenkontraste (#1F1F1F → #2D2D2D).
5. **Funktionale Statusfarben** – Rot/Orange/Grün werden *nur* für Systemzustände verwendet (Disk >89 %, CPU ≥100 %, Success/Warning).

---

## 2. Farb-Tokens

### 2.1 Kernfarben (Core)

| Token | Hex | Verwendung (verifiziert) |
|---|---|---|
| `--color-primary` | `#6DB443` | `MintY.currentColor` – Mint-Y Green, Hauptakzent |
| `--color-primary-light` | `#92B372` | Helle Green-Variante (auskommentiert im Code) |
| `--color-secondary` | `#2AB9A4` | `MintY.secondaryColor` – Teal, Sekundärakzent |
| `--color-canvas-dark` | `#1F1F1F` | `canvasColor` Dark Theme – App-Hintergrund |
| `--color-surface-dark` | `#2D2D2D` | `cardColor` Dark Theme – Karten/Panels |
| `--color-highlight` | `#FFFFFF` | `highlightColor` Dark Theme |
| `--color-text-on-dark` | `#FFFFFF` | Überschriften/Body auf dunklem Grund |
| `--color-text-on-light` | `#000000` | Überschriften/Body auf hellem Grund |

### 2.2 Akzent-Palette (Mint-Y, `getColorByName()`)

| Name | Hex | Token |
|---|---|---|
| Green | `#6DB443` | `--accent-green` |
| Aqua | `#6CABCD` | `--accent-aqua` |
| Blue | `#5B73C4` | `--accent-blue` |
| Teal | `#2AB9A4` | `--accent-teal` |
| Purple | `#8C6EC9` | `--accent-purple` |
| Pink | `#C76199` | `--accent-pink` |
| Red | `#C15B58` | `--accent-red` |
| Orange | `#DB9D61` | `--accent-orange` |
| Sand | `#C8AC69` | `--accent-sand` |
| Brown | `#AA876A` | `--accent-brown` |
| Grey | `#9D9D9D` | `--accent-grey` |
| Yellow | `#D8C15B` ⚠️ | `--accent-yellow` *(nicht im Code gefunden – Mint-Y-konform ergänzt)* |

### 2.3 Distributions-Themes (`setMainColor()` in `main.dart`)

| Distribution | Primary | Secondary |
|---|---|---|
| Linux Mint (Default) | `#6DB443` | `#2AB9A4` |
| LMDE | `#35A854` | `#238246` |
| Debian | `#D0074E` | `#2AB9A4` |
| openSUSE | `#73BA25` | `#0F5F4B` |
| KDE Neon | `#236896` | `#18A087` |

> Erweiterbar: Ubuntu `#E95420`, Fedora `#51A2DA`, Arch `#1793D1`, Pop!_OS `#48B9C7`, Manjaro `#35BF5C`, Zorin `#15A6CF`.

### 2.4 Semantische / funktionale Farben

| Token | Hex | Verwendung |
|---|---|---|
| `--status-success` | `#4CAF50` (`Colors.green`) | SuccessMessage, Icon `check` 32px |
| `--status-warning` | `#FF9800` (`Colors.orange`) | WarningMessage, Icon `warning` 32px |
| `--status-danger` | `#F44336` (`Colors.red`) | Disk >89 %, CPU ≥100 %, Clean-Icon |
| `--chart-cpu` | `#4699DD` | CPU-Balken (memory_status) |
| `--chart-ram` | `#C177F3` | RAM-Balken (memory_status) |
| `--chart-disk` | `#8D8D8D` | Disk-Balken normal |
| `--chart-track` | `#D3D3D3` | Bar-Hintergrund (single_bar_chart) |
| `--chart-fill` | `#494949` | Bar-Füllung Default |
| `--terminal-fg` | `#FFFFFF` | Konsolen-Output (`SelectableText`, Courier) |

---

## 3. Typografie

System-Font-Stack (Flutter Default = Roboto; auf Linux faktisch GTK-Systemfont). Monospace: `Courier` für Terminal-Output.

| Token | Größe | Gewicht | Variante | Mapping (TextTheme) |
|---|---|---|---|---|
| `--text-heading-1` | 32 | 500 | White / Black | displayLarge, displayMedium |
| `--text-heading-2` | 24 | 400 | White / Black | displaySmall, headlineLarge |
| `--text-heading-3` | 20 | 400 | White / Black | headlineMedium, titleLarge |
| `--text-heading-4` | 16 | 400 | White / Black | headlineSmall, **Button-Label** (`MintYButton`) |
| `--text-body` | 14 | 400 | – | bodyMedium |
| `--text-caption` | 12 | 400 | – | bodySmall, Tooltips |
| `--text-mono` | 14 | 400 | Courier | Terminal-/Log-Ausgabe |

Konvention: Jede Stufe existiert als `headingN` (schwarz, Light) und `headingNWhite` (weiß, Dark).

---

## 4. Geometry & Layout

### 4.1 Fenster
- Default-Fenstergröße: **1280 × 720** (`gtk_window_set_default_size`)
- App-Struktur: zentrierte Content-Column, Bottom-Action-Bar mit `MintYButton` (Zurück/Weiter)

### 4.2 Corner Radius

| Token | Wert | Verwendung (verifiziert) |
|---|---|---|
| `--radius-xs` | 2 | Mini-Progressbars (cleaner_select_disk, minHeight 5) |
| `--radius-sm` | 7 | Fortschrittsbalken (clean_disk, minHeight 15) |
| `--radius-md` | 8 | Info-Chips, Security-Check-Boxen (padding 8) |
| `--radius-lg` | 10 | Action-Entry-Cards / ListTiles (action_entry_card) |
| `--radius-xl` | 20 | Große Panels (flathub_permissions, padding 16) |

### 4.3 Spacing-Scale (aus SizedBox-/Padding-Mustern)

| Token | Wert | Verwendung |
|---|---|---|
| `--space-1` | 8 | Icon↔Text-Abstand, Chip-Padding |
| `--space-2` | 10 | Button-Gruppen, Element-Stacking |
| `--space-3` | 16 | Panel-Padding, Card-Content |
| `--space-4` | 32 | Sektions-Trennung, Hero-Abstände |

### 4.4 Icon-Größen
| Token | Wert | Verwendung |
|---|---|---|
| `--icon-sm` | 20 | Inline-Aktions-Icons (Clean-Icon) |
| `--icon-md` | 32 | Status-Icons (Success/Warning) |
| `--icon-lg` | 48 | Feature-/Entry-Icons (basic_entries) |
| `--icon-xl` | 64 | Settings-Hero-Icons |

Icons sind immer in `MintY.currentColor` eingefärbt; System-Icons laufen über `IconLoader` mit Fallback auf Material-Icons.

---

## 5. Komponenten (aus Code extrahiert)

| Komponente | Datei | Spezifikation |
|---|---|---|
| **MintYButton** | `mint_y.dart` | Primär-Button, `color: currentColor`, Label `heading4White`, Radius 10 |
| **MintYNextButton / BackButton** | `mint_y.dart` | Bottom-Bar-Navigation, lokalisiert |
| **ActionEntryCard** | `action_entry_card.dart` | ListTile, Radius 10, selected = `focusColor`, sonst transparent, Titel + Subtitle |
| **SingleBarChart** | `single_bar_chart.dart` | Vertikaler Balken, Track `#D3D3D3`, Tooltip weiß |
| **MemoryStatus** | `memory_status.dart` | CPU `#4699DD` / RAM `#C177F3`, rot ab Schwellwert |
| **DiskSpace** | `disk_space.dart` | Balken `#8D8D8D`, rot >89 %, Clean-Affordance |
| **SuccessMessage** | `success_message.dart` | `Icons.check` 32px grün + Text, gap 8 |
| **WarningMessage** | `warning_message.dart` | `Icons.warning` 32px orange + optional Fix-Button |
| **SystemIcon** | `system_icon.dart` | IconLoader → Cache, Akzentfarbe, Fallback Material |
| **RunCommandQueue** | `run_command_queue.dart` | Terminal-View: schwarzer Hintergrund, Courier, weiß, selektierbar |
| **GreeterCard** | `greeter/*` | Schwarzes Panel, Radius 20, Padding 16 |

### 5.1 Hermes-Layer (Fork Toqsick, `lib/widgets/hermes/`)
Neues, moderneres Component-Set des Forks – Tokens in `lib/layouts/hermes_tokens.dart` (13 KB):
`HermesCard`, `HermesBadge`, `HermesNavItem`, `HermesStatTile`, `HermesSparkline`, `HermesHaloDot`, `HermesCopyCommand`.
→ Empfehlung: Hermes als **Layer 2** des Design Systems definieren (Glass/Halo-Optik), Mint-Y bleibt **Layer 1** (Basis-Tokens).

---

## 6. Token-Exporte

### 6.1 CSS Custom Properties
```css
:root {
  --color-primary: #6DB443;
  --color-secondary: #2AB9A4;
  --color-canvas: #1F1F1F;
  --color-surface: #2D2D2D;
  --color-text: #FFFFFF;
  --status-success: #4CAF50;
  --status-warning: #FF9800;
  --status-danger: #F44336;
  --radius-sm: 7px;
  --radius-md: 8px;
  --radius-lg: 10px;
  --radius-xl: 20px;
  --space-1: 8px; --space-2: 10px; --space-3: 16px; --space-4: 32px;
  --font-mono: "Courier", monospace;
}
```

### 6.2 Dart (Flutter ThemeExtension-Skelett)
```dart
class MintYTokens {
  static const primary = Color(0xff6db443);
  static const secondary = Color(0xff2ab9a4);
  static const canvasDark = Color(0xff1f1f1f);
  static const surfaceDark = Color(0xff2d2d2d);
  static const chartCpu = Color(0xff4699dd);
  static const chartRam = Color(0xffc177f3);
  static const chartDisk = Color(0xff8d8d8d);
  static const radiusXs = 2.0, radiusSm = 7.0, radiusMd = 8.0;
  static const radiusLg = 10.0, radiusXl = 20.0;
}
```

---

## 7. Do's & Don'ts

- ✅ Akzentfarbe ausschließlich über `currentColor`-Token setzen, niemals hardcoden
- ✅ Statusfarben nur für echte Systemzustände (Schwellwerte: Disk 89 %, CPU 100 %)
- ✅ Pro Theme-Variante White/Black-Textpaar verwenden
- ❌ Keine Schatten-Stacks – Tiefe über Flächenkontrast
- ❌ Keine Zweit-Akzentfarbe innerhalb eines Screens
- ❌ Kein Mischen mehrerer Radius-Stufen in derselben Komponente
