# Issues V0.8.1 – V0.8.5 — Master Linux Assistant (MLA)

> 11 Issues, je mit Titel, Meilenstein, Labels und fertigem Body (1:1 kopierbar).
> Labels müssen vorher existieren (siehe `github-setup-linux-master-assistant.sh`): `bug`, `documentation` existieren bereits; neu: `deep-research`, `xdg-launcher`, `packaging`, `roadmap`, `release-process`, `gate:test`, `gate:verify`, `gate:manual`.

---

## Issue 1 — [V0.8.1] Memory aktualisieren: „Master Linux Assistant"

**Meilenstein:** V0.8.1 · **Labels:** `documentation`, `deep-research`, `gate:manual`

### Body

```markdown
## Scope
Task 0 des V0.8.X-Implementierungsplans: Die Projekt-Memory wird komplett neu gefasst, damit der Name **„Master Linux Assistant"** und die seit 2026-09-11 geltende Richtung (persönliches Cockpit für das Referenzsystem Zorin OS 18.1) für alle Sessions greifen.

## Dateien (außerhalb des Repos)
- `~/.claude/projects/-home-bratan--claude/memory/linux-master-assistant-projekt.md` (komplett ersetzen)
- `~/.claude/projects/-home-bratan--claude/memory/MEMORY.md` (nur die Zeile „Master Linux Assistant")

## Kerninhalte der neuen Memory
- Fork `Toqsick/master-linux-assistant` (Upstream `Jean28518/linux-assistant`), lokal `~/10-Projekte/10-active/linux-assistant/`
- Richtung seit dem Grill 2026-09-11: persönliches Cockpit für Zorin OS 18.1; Core = Release-Blocker nur dort; fremde Backends (TokenTelemetry, Hermes, Odysseus) sind nie Core
- `bash install.sh [--purge]` braucht sudo → Basti führt es selbst aus
- Tote dconf-Schlüssel `custom0`–`custom4` alter `<Alt>Q`-Kürzel liegen inert (Stand 2026-07-30)

## Gates
- [ ] Memory-Datei ersetzt (exakter Inhalt aus Plan Task 0, Step 1)
- [ ] `MEMORY.md`-Zeile aktualisiert (Plan Task 0, Step 2)
- [ ] **Manueller Gate:** Sichtung durch Basti (kein Repo-Commit nötig)

_Quelle: Implementierungsplan V0.8.X, Task 0._
```

---

## Issue 2 — [V0.8.1] Branch anlegen & ZCode-Fremd-Diff committen

**Meilenstein:** V0.8.1 · **Labels:** `documentation`, `deep-research`, `gate:manual`, `gate:verify`

### Body

```markdown
## Scope
Task 1: Der uncommittete ZCode-Stand (AGENTS.md, MANIFEST.md, `docs/handoff/roadmap.md`, features.csv — 170+/63−) wird auf einem neuen Hardening-Branch gesichert. Tasks 4/5 bauen darauf auf. Die untracked Datei `docs/handoff/deep-research-verbesserungen.md` bleibt unangetastet (wird in V0.8.5 überschrieben).

## Schritte
- [ ] `git -C ~/10-Projekte/10-active/linux-assistant switch -c hardening/0.8.x-browser-xdg`
- [ ] **Manueller Gate:** Basti sichtet `git diff -- AGENTS.md MANIFEST.md docs/handoff/roadmap.md features.csv` — erst nach seinem OK weiter
- [ ] Commit:
```bash
git add AGENTS.md MANIFEST.md docs/handoff/roadmap.md features.csv
git commit -m "docs: feature tiers and AGENTS.md refresh (ZCode session 2026-09-11)" \
  -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

## Gates
- [ ] Diff-Sichtung durch Basti abgenommen
- [ ] Commit auf `hardening/0.8.x-browser-xdg`, `git status` sauber

_Quelle: Implementierungsplan V0.8.X, Task 1._
```

---

## Issue 3 — [V0.8.2] TDD: Failing Tests für die XDG-Kette schreiben

**Meilenstein:** V0.8.2 · **Labels:** `bug`, `xdg-launcher`, `gate:test`

### Body

```markdown
## Hintergrund (Live-Bug)
Das Browser-Werkzeug im Hub startet Google Chrome, obwohl Brave Origin Standard ist (`xdg-settings get default-web-browser` → `brave-origin.desktop`). Ursache: `AppLauncher` prüft eine feste Binary-Liste per `which`, von der nur `google-chrome` installiert ist.

## Scope (Task 2, Steps 1–2 — RED)
In `test/app_launcher_test.dart`:
- [ ] `import 'dart:io';` ergänzen
- [ ] Gruppen `AppLauncher.detectBrowser` und `AppLauncher.launchApp` bleiben wörtlich
- [ ] Gruppe `AppLauncher.launchBrowser` (Z. 33–83) ersetzen
- [ ] Hermetischen `fake()`-Helper + zwei neue Gruppen einfügen: `defaultBrowserDesktopId` (4 Tests) und `desktopEntryExistsIn` (2 Tests); `launchBrowser` neu mit 8 Tests (XDG statt Chrome, `xdg-open` mit URL, `preferred_browser` gewinnt, Fallbacks, `failed`)
- [ ] Vollständiger Test-Code: Plan Task 2, Step 1

## Gate (RED)
- [ ] `flutter test test/app_launcher_test.dart` schlägt fehl mit Compile-Fehler `No named parameter with the name 'outputReader'` — erwartet und gewollt

_Quelle: Implementierungsplan V0.8.X, Task 2 (Steps 1–2)._
```

---

## Issue 4 — [V0.8.2] XDG-Stufe in AppLauncher implementieren + Snackbar-Feedback + Doku

**Meilenstein:** V0.8.2 · **Labels:** `bug`, `xdg-launcher`, `gate:test`, `gate:verify`

### Body

```markdown
## Scope (Task 2, Steps 3–8 — GREEN)
Ziel-Reihenfolge: `preferred_browser` → XDG-Standardbrowser (`xdg-settings` + .desktop-Prüfung, dann detached `gtk-launch`; mit URL `xdg-open`) → Binary-Liste `kKnownBrowsers` als letzter Fallback.

## Dateien
- `lib/services/app_launcher.dart` (komplett ersetzen — neuer `BrowserLaunchResult`-Enum, injizierbare Zugriffe `whichRunner`/`processStarter`/`outputReader`/`desktopEntryExists`/`configuredBrowser`; vollständiger Code im Plan Task 2, Step 3)
- `lib/layouts/hub/hub_shell.dart:166-181` (Doc-Kommentar exakt 5 Zeilen + Fallback-Info-Snackbar; `failed`-Zweig ab Z. 182 unverändert)
- Doku: `docs/wiki/Admin-Hub.md:19-27`, `docs/handoff/panels/hub-shell.md:55` (Zeilennummern via grep), `docs/design/feature-spec-admin-hub.md:42`, `docs/design/admin-hub-followups.md:23`

## Hinweise
- Die .desktop-Prüfung bleibt nötig: aus einem detached Start kommt kein Exit-Code zurück — ohne Prüfung meldete der Launcher Erfolg, obwohl sich nichts öffnet
- Wiederverwendet: `CommandHelper.runWithArguments`, `ConfigHandler().getValueUnsafe('preferred_browser', '')`, bestehendes `debugOverride`-Muster

## Gates
- [ ] **Test-Gate:** `flutter test test/app_launcher_test.dart` komplett grün (RED → GREEN)
- [ ] `dart format lib test`, dann alle globalen Gates: `check-versions.sh`, `flutter analyze` (0 Findings), `flutter test`, Python-Unittests
- [ ] Commit „fix(launcher): start the XDG default browser instead of the first listed binary"

_Quelle: Implementierungsplan V0.8.X, Task 2 (Steps 3–8)._
```

---

## Issue 5 — [V0.8.3] deb-Depends: xdg-utils, libgtk-3-bin, libglib2.0-bin

**Meilenstein:** V0.8.3 · **Labels:** `packaging`, `xdg-launcher`, `gate:verify`

### Body

```markdown
## Scope (Task 3, Step 1)
Der Launcher ruft künftig `xdg-settings`, `gtk-launch` und `xdg-open` (unter GNOME via `gio`) auf — das .deb muss die Werkzeuge deklarieren. Paket-Beleg per `dpkg -S` auf Zorin 18.1:

| Datei | Paket |
|---|---|
| `/usr/bin/xdg-settings` | `xdg-utils` |
| `/usr/bin/gtk-launch` | `libgtk-3-bin` |
| `/usr/bin/gio` | `libglib2.0-bin` |

## Änderung
`deb/DEBIAN/control:2` wird zu:
`Depends: libgtk-3-0, libkeybinder-3.0-0, python3, python3-gi, gir1.2-gtk-3.0, python3-apt, mesa-utils, pkexec | policykit-1, xdg-utils, libgtk-3-bin, libglib2.0-bin`

(`libkeybinder-3.0-0` bleibt bis zum Hotkey-Umbau nach V0.8.X.)

## Gates
- [ ] `bash tool/check-versions.sh` → OK
- [ ] **Verify-Gate:** `bash build-deb.sh && dpkg-deb -f linux-assistant.deb Depends` endet auf `xdg-utils, libgtk-3-bin, libglib2.0-bin`

_Quelle: Implementierungsplan V0.8.X, Task 3 (Step 1 + 4)._
```

---

## Issue 6 — [V0.8.3] README & Getting-Started an control angleichen

**Meilenstein:** V0.8.3 · **Labels:** `documentation`, `packaging`, `gate:verify`

### Body

```markdown
## Scope (Task 3, Steps 2–3)
Die Abhängigkeitslisten folgen wieder `deb/DEBIAN/control`:

README.md:
- [ ] Z. 55–56: Laufzeitpaket-Liste endet auf `…, mesa-utils, pkexec | policykit-1, xdg-utils, libgtk-3-bin, libglib2.0-bin`
- [ ] Z. 64–65: apt-install-Block um `xdg-utils libgtk-3-bin libglib2.0-bin` ergänzen (exakter Block im Plan)

docs/wiki/Getting-Started.md:
- [ ] Z. 8 wird `sudo apt install libkeybinder-3.0-0 libkeybinder-3.0-dev` — `wmctrl` fällt weg (seit 0.8.0 durch den Single-Instance-Socket ersetzt); `libkeybinder-3.0-0-dev` war ein falscher Paketname
- [ ] Z. 11–14: Hinweis, dass das .deb die Laufzeit-Bibliotheken deklariert und `apt` sie automatisch zieht

## Verify-Gates
- [ ] `grep -rn "wmctrl\|libkeybinder-3.0-0-dev" README.md docs/wiki` → kein Treffer
- [ ] `bash tool/check-versions.sh` → OK
- [ ] Commit „build(deb): depend on xdg-utils, libgtk-3-bin and libglib2.0-bin" (gemeinsam mit Issue 5)

_Quelle: Implementierungsplan V0.8.X, Task 3 (Steps 2–5)._
```

---

## Issue 7 — [V0.8.4] MANIFEST, features.csv & AGENTS.md: Cockpit-Scope festschreiben

**Meilenstein:** V0.8.4 · **Labels:** `documentation`, `deep-research`, `gate:verify`, `roadmap`

### Body

```markdown
## Scope (Task 4)
Die Grill-Entscheidungen (DR 2026-09-11) werden verbindlich:

MANIFEST.md:
- [ ] (a) Fork-Hinweis nach Z. 9: persönliches Cockpit für Zorin OS 18.1; Upstream-Mission oben bleibt, Tiers werden nur am Referenzsystem gemessen *(Ableitung, streichbar)*
- [ ] (b) Core-Absatz Z. 16–19 ersetzen: Core = täglicher Helfer, Admin-Aufgaben, mitgelieferte Hub-Werkzeuge; Bruch = Release-Blocker auf dem Referenzsystem; Integrationen fremder Backends (TokenTelemetry, Hermes, Odysseus, Wetter-APIs) sind nie Core — Systemkomponenten wie apt, systemd, Restic, Docker dürfen Core sein
- [ ] (c) Hinweis nach dem n2h-Block: Distro-/Desktop-Spalten der features.csv eingefroren (Upstream-Stand, unverifiziert)
- [ ] (d) Kurzfassung (DE) angleichen

features.csv:
- [ ] Vier neue Hub-Zeilen (21 Felder): browser launcher, quick notes, file manager, system monitor — `yes` nur für Zorin OS + GNOME, sonst `?`
- [ ] Fork-eigene Zeilen 39–41 auf dieselbe ehrliche Belegung *(Ableitung, streichbar)*; Zeile 42 bleibt

AGENTS.md:9–10:
- [ ] Hinweis: MANIFEST (Referenzsystem Zorin OS 18.1) + features.csv (eingefrorene Distro-Spalten) lesen vor Änderungen an Distro-Verhalten

## Verify-Gate
- [ ] `python3 -c "import csv; r=list(csv.reader(open('features.csv'))); print({len(x) for x in r}, [sum(x[1]==c for x in r[1:]) for c in ('Core','QoL','N2H')])"` → `{21} [24, 17, 4]`
- [ ] Commit „docs: personal-cockpit scope, Core covers the hub tools, distro matrix frozen"

_Quelle: Implementierungsplan V0.8.X, Task 4._
```

---

## Issue 8 — [V0.8.4] Roadmap: DR-Abschnitte, Geparkt-Tabelle & Nie-Liste

**Meilenstein:** V0.8.4 · **Labels:** `documentation`, `deep-research`, `roadmap`

### Body

```markdown
## Scope (Task 5)
`docs/handoff/roadmap.md` — Stellen werden über Ankertext gefunden, nicht über Zeilennummern:

- [ ] Kopf: DR-Hinweis-Zeile (Bericht bleibt bewusst außerhalb des Repos); V0.8.0-Überschrift auf „✅ Tag v0.8.0, 2026-09-11" *(Faktenpflege, streichbar)*
- [ ] V0.8.X: Punkt 3 → ✅ im Code erledigt (`lib/services/updater.dart:21`); Punkt 4 → „Ohne Panel-/Dock-Teil"; neue Punkte 9 (Browser-Launcher XDG ✅) und 10 (Release-Gates ✅)
- [ ] Neuer Abschnitt „Nach V0.8.X — aus der Deep-Research-Auswertung (DR)": 1) Hotkey über gsettings in beiden Sessions (`hotkey_manager` + `libkeybinder-3.0-0` raus), 2) Browser-Status (Core, read-only), 3) Agenten-Tile → V0.9 P2, 4) Gate-Automatisierung (Spike headless gnome-shell; nur Wayland; Monitorwechsel + alle X11-Gates manuell; kein Self-hosted-Runner)
- [ ] V0.9-Tabelle: Zeile „Tokentelemetrie" → „Agenten-Tile (n2h, DR)"; Zeilen „Hermes Gateway Manager" und „Kanban Watcher" löschen; Streichungs-Notiz unter die Tabelle
- [ ] Tier-Absatz ersetzen (24 Core / 17 QoL / 4 N2H; V0.9-Einordnung)
- [ ] Neuer Abschnitt „Geparkt — Wiedervorlage nur mit Beleg (DR)": Tabelle 4.1, 4.4, 4.6, 4.8, 4.9, 4.10, 4.11
- [ ] „Nicht-Ziele": verbindliche Nie-Liste + Upstream-Punkte (Kommentar #253 mit Link `eb1dfb5`, privater Maintainer-Hinweis — beides Basti)

## Gate
- [ ] Commit „docs(roadmap): fold in the deep-research review"

_Quelle: Implementierungsplan V0.8.X, Task 5._
```

---

## Issue 9 — [V0.8.5] Release-Process: manuelle Gates für Wayland & X11

**Meilenstein:** V0.8.5 · **Labels:** `documentation`, `release-process`, `gate:manual`

### Body

```markdown
## Scope (Task 6)
`docs/wiki/Release-Process.md`:

- [ ] Abschnitt „Smoke-Test nach Installation" bis Dateiende ersetzen durch „Release-Gates nach Installation (Definition of Done)": Gate-Tabelle mit [ ]-Spalten für Wayland (`zorin-wayland`) und X11 (`zorin-xorg`) — App startet in den Hub, Hotkey (Alt+Q, Quelle `getHotkeyModifier()`) mit Fokus im Suchfeld, Monitorwechsel, Clipboard (`HermesCopyCommand`), Browser-Werkzeug startet Standardbrowser ohne Snackbar, alle Hub-Werkzeuge funktional, kein Polling-Lärm im Journal
- [ ] Hinweis auf geplante Automatisierung: nur Hotkey + Clipboard unter Wayland auf dem Runner; Rest manuell
- [ ] Faktenpflege (streichbar): Z. 3 (Gates-Verweis), Z. 7–10 (`version` = einzige Source of Truth; `build-deb.sh` stempelt Version/Installed-Size), rpm-Zeile raus (Skript existiert nicht mehr), deb = einziger gepflegter Weg, RPM/Arch/Flatpak geparkt in `packaging/unmaintained/`, Z. 49 (CI-Reihenfolge)

## Gates
- [ ] **Manueller Gate:** Tabelle ist in beiden Sessions abhakbar (Referenzsystem Zorin OS 18.1)
- [ ] Commit „docs(release): manual release gates for Wayland and X11"

_Quelle: Implementierungsplan V0.8.X, Task 6._
```

---

## Issue 10 — [V0.8.5] Prompt-Skelett für geparkte Themen committen

**Meilenstein:** V0.8.5 · **Labels:** `documentation`, `deep-research`, `gate:verify`

### Body

```markdown
## Scope (Task 7)
`docs/handoff/deep-research-verbesserungen.md` komplett ersetzen — die untracked Fassung stellte Hermes, Odysseus und token-calc falsch als private Blackboxes dar und war nie committet.

Das Skelett (voller Text im Plan Task 7, Step 1):
- Verwendung: nur bei neuem Beleg für ein Thema aus „Geparkt"; genau **einen** Themen-Slot ausfüllen
- Harte Regeln: „Aussage ohne Link wird verworfen", Nachbarprojekte sind öffentlich (Upstream-Doku lesen, keine Blackbox), Nie-Liste und Sicherheitsinvarianten bindend, Stand 2025/26
- Verifizierter Kontextblock (Stand 2026-09-11): Produkt/Arbeitsflächen-Regel/Tiers/Core-Werkzeuge/Sicherheitsinvarianten/Plattform Zorin 18.1 (kein GlobalShortcuts-Portal)/öffentliche Schnittstellen von Hermes, TokenTelemetry, Odysseus + verbindliche Nie-Liste
- Ausgabeformat: Deutsch, Quellen, Optionen-Tabelle mit Aufwand S/M/L/XL, Empfehlung, Tier-Vorschlag, offene Fragen — nur das Slot-Thema

## Verify-Gates
- [ ] **Leak-Check:** `grep -nE '([0-9]{1,3}\.){3}[0-9]{1,3}|localhost|:[0-9]{4,5}\b|~/|/home/' docs/handoff/deep-research-verbesserungen.md` → kein Treffer (keine Hosts, IPs, Ports, Tunnel, lokalen Pfade)
- [ ] Commit „docs(handoff): deep-research prompt skeleton for parked topics"

_Quelle: Implementierungsplan V0.8.X, Task 7._
```

---

## Issue 11 — [V0.8.5] End-to-End-Verifikation & Freigabe (Push erst nach OK)

**Meilenstein:** V0.8.5 · **Labels:** `release-process`, `gate:verify`, `gate:manual`

### Body

```markdown
## Scope
Abschluss der V0.8.X-Reihe: komplette Ende-zu-Ende-Verifikation vor Push/PR/Release. **Push, PR, Versions-Bump und Release nur mit Bastis ausdrücklichem OK.**

## Checkliste
- [ ] CI-Gates lokal grün: `tool/check-versions.sh`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze` (0 Findings), `flutter test`, Python-Unittests (`additional/python`)
- [ ] Paket: `bash build-deb.sh && dpkg-deb -f linux-assistant.deb Depends` enthält `xdg-utils, libgtk-3-bin, libglib2.0-bin`
- [ ] Echte Kette ohne Installation: `xdg-settings get default-web-browser` → `brave-origin.desktop`; `gtk-launch brave-origin.desktop` öffnet Brave Origin; `flutter run -d linux` → Hub → Werkzeuge → Browser: Brave Origin öffnet ohne Snackbar (vorher: Chrome)
- [ ] Doku: CSV-Check `{21} [24, 17, 4]`, Leak-Check (Issue 10), wmctrl-Grep (Issue 6) — alle ohne Fund
- [ ] **Basti (sudo):** `bash install.sh`, dann Gate-Tabelle aus Release-Process.md in beiden Sessions (Wayland + X11) abhaken
- [ ] Erst nach OK: `hardening/0.8.x-browser-xdg` pushen, Actions-Lauf muss grün sein

## Offene Fakten (werden geprüft, nicht entschieden)
- Headless gnome-shell auf dem GitHub-Runner → Spike nach V0.8.X
- Upstream-#253: nur Symptom-Gleichheit mit deb822; Kommentar als Hypothese mit Link `eb1dfb5` (Basti)
- Ersetzt der gsettings-Shortcut unter X11 den Grab vollständig? → das X11-Gate prüft es

_Quelle: Implementierungsplan V0.8.X, Abschnitt „Verifikation (Ende-zu-Ende)"._
```

---

## Zusammenfassung

| # | Titel | Meilenstein | Labels |
|---|---|---|---|
| 1 | [V0.8.1] Memory aktualisieren: „Master Linux Assistant" | V0.8.1 | documentation, deep-research, gate:manual |
| 2 | [V0.8.1] Branch anlegen & ZCode-Fremd-Diff committen | V0.8.1 | documentation, deep-research, gate:manual, gate:verify |
| 3 | [V0.8.2] TDD: Failing Tests für die XDG-Kette schreiben | V0.8.2 | bug, xdg-launcher, gate:test |
| 4 | [V0.8.2] XDG-Stufe in AppLauncher implementieren + Snackbar-Feedback + Doku | V0.8.2 | bug, xdg-launcher, gate:test, gate:verify |
| 5 | [V0.8.3] deb-Depends: xdg-utils, libgtk-3-bin, libglib2.0-bin | V0.8.3 | packaging, xdg-launcher, gate:verify |
| 6 | [V0.8.3] README & Getting-Started an control angleichen | V0.8.3 | documentation, packaging, gate:verify |
| 7 | [V0.8.4] MANIFEST, features.csv & AGENTS.md: Cockpit-Scope festschreiben | V0.8.4 | documentation, deep-research, gate:verify, roadmap |
| 8 | [V0.8.4] Roadmap: DR-Abschnitte, Geparkt-Tabelle & Nie-Liste | V0.8.4 | documentation, deep-research, roadmap |
| 9 | [V0.8.5] Release-Process: manuelle Gates für Wayland & X11 | V0.8.5 | documentation, release-process, gate:manual |
| 10 | [V0.8.5] Prompt-Skelett für geparkte Themen committen | V0.8.5 | documentation, deep-research, gate:verify |
| 11 | [V0.8.5] End-to-End-Verifikation & Freigabe (Push erst nach OK) | V0.8.5 | release-process, gate:verify, gate:manual |
