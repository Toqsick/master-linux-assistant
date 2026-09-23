# Meilensteine V0.8.1 – V0.8.5 — Master Linux Assistant (MLA)

> Repo: `Toqsick/linux-assistant` (wird: `Toqsick/linux-master-assistant`)
> Quelle: Implementierungsplan V0.8.X (Deep-Research-Auswertung 2026-09-11)
> Anlegen via Web-UI (Issues → Milestones → New milestone) oder mit dem Skript `github-setup-linux-master-assistant.sh`.

---

## Meilenstein 1 — V0.8.1 „Setup & Sicherung“

**Beschreibung:**

Task 0+1 des V0.8.X-Plans: Memory neu fassen („Master Linux Assistant", Cockpit-Richtung für Zorin OS 18.1), Branch `hardening/0.8.x-browser-xdg` von `main` anlegen, ZCode-Fremd-Diff (AGENTS.md, MANIFEST.md, roadmap.md, features.csv — 170+/63−) unverändert committen.

**Erfolgskriterium:** Branch existiert, Fremd-Diff ist committet, Memory greift — die Basis für alle folgenden Releases steht.

---

## Meilenstein 2 — V0.8.2 „XDG-Browser-Fix“

**Beschreibung:**

Task 2: Der `AppLauncher` folgt `preferred_browser` → XDG-Standardbrowser (`xdg-settings get default-web-browser` + .desktop-Existenzprüfung, dann detached `gtk-launch`; mit URL `xdg-open`) → Binary-Liste nur als letzter Fallback. TDD (RED→GREEN), Snackbar-Feedback in `hub_shell.dart`, Doku-Abgleich. Behebt den Live-Bug: Der Hub startete Google Chrome statt des Standardbrowsers Brave Origin.

**Erfolgskriterium:** `flutter test` + `flutter analyze` grün; auf Bastis Rechner öffnet das Browser-Werkzeug Brave Origin ohne Snackbar.

---

## Meilenstein 3 — V0.8.3 „Packaging: Depends & Abhängigkeitslisten“

**Beschreibung:**

Task 3: `deb/DEBIAN/control` deklariert die neuen Laufzeitpakete `xdg-utils`, `libgtk-3-bin`, `libglib2.0-bin` (belegt per `dpkg -S` auf Zorin 18.1); README und Getting-Started werden synchronisiert; `wmctrl` (seit 0.8.0 obsolet) und der Falschname `libkeybinder-3.0-0-dev` verschwinden.

**Erfolgskriterium:** `build-deb.sh` baut, `dpkg-deb -f linux-assistant.deb Depends` endet auf die drei Pakete.

---

## Meilenstein 4 — V0.8.4 „Cockpit-Scope & Roadmap“

**Beschreibung:**

Task 4+5: MANIFEST und AGENTS.md schreiben den persönlichen Cockpit-Scope fest (Referenzsystem Zorin OS 18.1; Core = Missionskern + mitgelieferte Hub-Werkzeuge; Integrationen fremder Backends sind nie Core). features.csv: vier Hub-Tool-Zeilen, Distro-/Desktop-Matrix eingefroren als unverifizierter Upstream-Stand. Roadmap: V0.8.X abgerundet, „Nach V0.8.X", V0.9-Tiers angepasst, Geparkt-Tabelle (Wiedervorlage nur mit Beleg), verbindliche Nie-Liste.

**Erfolgskriterium:** CSV-Check ergibt `{21} [24, 17, 4]` (21 Felder, 24 Core / 17 QoL / 4 N2H); alle Grill-Entscheidungen (DR) sind in MANIFEST, CSV und Roadmap greifbar.

---

## Meilenstein 5 — V0.8.5 „Release-Gates, Prompt & E2E-Verifikation“

**Beschreibung:**

Task 6+7 plus Ende-zu-Ende-Verifikation: Manuelle Release-Gates für Wayland (`zorin-wayland`) und X11 (`zorin-xorg`) in Release-Process.md inkl. Faktenpflege (deb einziger gepflegter Weg, rpm/arch/Flatpak geparkt); Prompt-Skelett `docs/handoff/deep-research-verbesserungen.md` committen (ersetzt die untracked Fassung mit falschen Blackbox-Annahmen). Danach die komplette Verifikationskette.

**Erfolgskriterium:** Alle CI-Gates lokal grün, Leak-Check des Prompts ohne Treffer, echte Kette auf Bastis Rechner bestätigt, Gate-Tabelle in beiden Sessions abgehakt — erst dann Push/PR/Release auf Bastis ausdrückliches OK.
