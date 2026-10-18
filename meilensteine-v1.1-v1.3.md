# Meilensteine V1.1 – V1.3 — Master Linux Assistant (MLA)

> Repo: `Toqsick/master-linux-assistant`
> Quelle: Ausbauplan V1.1–V1.3 (Planungssession 2026-10-18, `ausbauplan-v1.1-v1.3.md`)
> Anlegen: fortlaufend ab Nummer 19 (1–11 = V0.8.1–V1.0, 12–18 = MLA-Next 0.0.1–0.4.x), per Skript (siehe Ausbauplan, „Überführung"). Issue-Bodies stehen in `issues-v1.1-v1.3.md`.
> Ziel-Shell: GTK4/libadwaita (`prototype/gtk/`) + Dart-Kern `packages/la_core`. Prämisse: der Flutter-vs-GTK-Entscheid (MLA-Next 0.4.x, #106) fällt für GTK; Rückfallregel im Ausbauplan.

---

## Meilenstein 19 — V1.1 „Cockpit-QoL & UX“

**Beschreibung:**

Komfort auf der GTK-Shell ohne neue System-Nähte (12 Teilpläne): FU4 generischer Probe-Vertrag (`la_probe --json` als Zwischenstufe, `probe.*` über IPC), DS7 l10n-Grundgerüst (gettext, ARB-Keys), UX1 Navigation/Fensterzustand/Kürzel, UX2 Kontext-Inspektor, UX3 Leer-/Lade-/Stale-/Fehlerzustände, UX4 Einstellungen als Seite, DS5 Komponenten-Katalog + Galerie + xvfb-CI-Gate, LB4 Ampel-Feinschliff (Bekannt/Snooze/Ruhezeiten/Verlauf), LB5 Tages-Check „Heute", ST4 Grafik-Stabilitäts-Wache (NVIDIA/Wayland), GA1 Gaming-Vorflug, SP3 Speicher-Feinschliff (Mounts, Timeshift-Soll, SMART ohne Root). Ziel-Shell GTK4/libadwaita + `la_core`; Prämisse: der Flutter-vs-GTK-Entscheid (#106) fällt für GTK.

**Erfolgskriterium:** Eine neue Probe im Kern erscheint ohne GTK-Codeänderung; ein Neustart stellt Fenster und Modul wieder her; Fixture-Freeze-Boots werden als solche erkannt; eine Timeshift-Zeitplan-Regression wird gelb; jede Fläche hat einen Leer-/Lade-/Stale-/Fehlerzustand; GTK-Widget-Tests laufen in CI unter xvfb.

---

## Meilenstein 20 — V1.2 „Zorin/GNOME-Integration & Werkzeuge“

**Beschreibung:**

GNOME-Nähte und Werkzeuge (11 Teilpläne): GN4 App-ID, Desktop-Actions, AppStream, Autostart (Schritt 0), GN1 GNOME-Shell-Suchanbieter, GN2 Hotkey-Robustheit (gsettings; GNOME 46 hat kein GlobalShortcuts-Portal), GN3 Benachrichtigungen mit Aktionen und Deep-Links, DS6 Tastatur/Accessibility/Darstellung folgt GNOME, WZ3 Werkstatt-Übergaben (Terminal, Dateien, Obsidian, Dashboard-Links), TE4 Palette-Aktionen + Schnellaktionen-Kacheln, DI4 Stack-Operationen + Container-Hygiene, DI5 Tunnel-Status + Gateway-Audit, ST5 Grafik-Setup-Check/Radar/GNOME-Erweiterungen, GA2 Steam-Bibliotheken + Platzfresser.

**Erfolgskriterium:** Die Super-Taste findet MLA-Module; „Öffnen" einer Benachrichtigung landet im Zielmodul, auch bei gestoppter App; das Dock zeigt die Desktop-Actions; Orca liest Ampeln vor; Compose-Stacks mit Hygiene-Vorschau; zwei Steam-Bibliotheken werden erkannt; jede Übergabe läuft ohne Shell-String (argv-Asserts).

---

## Meilenstein 21 — V1.3 „Nice-to-haves & Parkliste“

**Beschreibung:**

Extras mit kleinem Fußabdruck (9 Teilpläne): UX5 Dashboard anpassbar + Fokus-Modus, UX6 Wetter-Kachel (Open-Meteo), LB6 ntfy-Ziel im Wächter, DI6 Odysseus „Ungelesen: N" (die drei Parkliste-Mini-Varianten mit Bastis Go), ST6 Wochenbericht, DI7 Lab-Status (Container-Labs, VMs), DI8 Tailscale-Status, UX7 Erster Start & Onboarding, Abschluss (Parkliste #88, `features.csv`, Wiki, Doku-Altlasten).

**Erfolgskriterium:** Deaktivierte Kacheln erzeugen keinen Netzverkehr; Tokens liegen nur im Secret Service (Grep-Gate); der Wochenbericht enthält keine Hostnamen oder IPs; `features.csv`, Wiki und Parkliste sind auf Stand.
