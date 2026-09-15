# Die Release-Pläne V0.8.1 – V0.8.5 (+ V0.8.2.5 Security-Pass) — Linux Master Assistant

> Zerlegung des V0.8.X-Implementierungsplans (Deep-Research-Auswertung 2026-09-11) in fünf eigenständige Releases — seit 2026-09-15 ergänzt um den Security-Pass V0.8.2.5 (RepoLens-Audit-Triage, Ausarbeitung in `security-fixplan-42-50.md`).
> Jedes Release erbt die globalen Randbedingungen: Referenzsystem Zorin OS 18.1, Branch `hardening/0.8.x-browser-xdg`, Security-Invarianten unangetastet (Command-Queue, zwei polkit-Actions), jedes Commit mit `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. Ohne Bastis ausdrückliches OK: kein Push, kein PR, kein Versions-Bump, kein Release.

## Globale CI-Gates (gelten für jedes Release)

- [ ] `bash tool/check-versions.sh`
- [ ] `dart format --output=none --set-exit-if-changed lib test`
- [ ] `flutter analyze` → 0 Findings
- [ ] `flutter test` → grün
- [ ] `(cd additional/python && python3 -m unittest discover -s tests -t .)`

---

## Release V0.8.1 — „Setup & Sicherung"

**Ziel:** Die Arbeitsgrundlage steht: Memory trägt Namen und Richtung, der Fremd-Diff ist auf einem eigenen Branch gesichert.

### Inhalt
1. **Memory aktualisieren (Task 0):** `linux-master-assistant-projekt.md` komplett neu fassen (Fork-Identität, Cockpit-Richtung seit 2026-09-11, sudo-Regel für `install.sh`, dconf-Hinweis), `MEMORY.md`-Zeile anpassen.
2. **Branch + Fremd-Diff (Task 1):** `git switch -c hardening/0.8.x-browser-xdg` von `main`; ZCode-Diff (AGENTS.md, MANIFEST.md, roadmap.md, features.csv — 170+/63−) unverändert committen. Die untracked `deep-research-verbesserungen.md` bleibt liegen (wird in V0.8.5 ersetzt).

### Gates
- **Manuell (Pflicht):** Basti sichtet `git diff -- AGENTS.md MANIFEST.md docs/handoff/roadmap.md features.csv` vor dem Commit.
- **Verify:** `git status` sauber; Commit-Message mit Co-Authored-By.
- **Test:** Docs-only → `check-versions.sh` + `dart format` genügen.

### Abhängigkeiten
Blockiert nichts Externes; V0.8.2–V0.8.5 setzen diesen Branch voraus.

---

## Release V0.8.2 — „XDG-Browser-Fix"

**Ziel:** Das Browser-Werkzeug im Hub respektiert `preferred_browser` und den XDG-Standardbrowser. Der Live-Bug (Chrome statt Brave Origin) ist behoben.

### Inhalt (Task 2, strikt TDD)
1. **RED — Tests schreiben:** `test/app_launcher_test.dart`: Gruppe `launchBrowser` ersetzen, hermetischer `fake()`-Helper, zwei neue Gruppen (`defaultBrowserDesktopId`, `desktopEntryExistsIn`), 8 neue Launch-Tests. Erwarteter Compile-Fehler: `No named parameter with the name 'outputReader'`.
2. **GREEN — Implementieren:** `lib/services/app_launcher.dart` komplett ersetzen: `BrowserLaunchResult`-Enum (launchedPreferred / launchedFallback / failed), injizierbare Zugriffe nach `debugOverride`-Muster, XDG-Stufe via `CommandHelper.runWithArguments` (`xdg-settings`), .desktop-Existenzprüfung über XDG_DATA_HOME/XDG_DATA_DIRS, detached `gtk-launch` bzw. `xdg-open`, Binary-Liste nur als letzter Fallback.
3. **Hub-Feedback:** `hub_shell.dart:166-181` — Doc-Kommentar (exakt 5 Zeilen wegen Zeilenbelegen in panels/hub-shell.md), Info-Snackbar beim Listen-Fallback, Fehler-Snackbar bei `failed` bleibt.
4. **Doku:** Admin-Hub.md, panels/hub-shell.md:55 (Zeilen via grep), feature-spec-admin-hub.md („Überholt (DR)"-Banner), admin-hub-followups.md:23.

### Gates
- **Test (Pflicht):** Reihenfolge RED → GREEN wird eingehalten; `flutter test` komplett grün, `flutter analyze` 0 Findings, `dart format` sauber.
- **Verify (manuell, ohne Installation):** `xdg-settings get default-web-browser` → `brave-origin.desktop`; `gtk-launch brave-origin.desktop` öffnet Brave Origin; `flutter run -d linux` → Hub → Werkzeuge → Browser öffnet Brave Origin **ohne Snackbar**.
- Commit: „fix(launcher): start the XDG default browser instead of the first listed binary".

### Warum die .desktop-Prüfung nötig ist
Detached Starts liefern keinen Exit-Code — ohne Prüfung würde eine veraltete Desktop-ID als Erfolg gemeldet, obwohl sich nichts öffnet. Ein nicht-detached `gtk-launch` hingegen würde an der geerbten Pipe hängen.

**Fix-Plan-Bezug:** In diesem Release einweben: **WP-B1** (#47, Boundary-Validation für `preferred_browser` — Teil des app_launcher-Neubaus) und **WP-B2** (#45, Icon-Loader `runInShell: false` + Quote-Shim-Entfernung als gekoppeltes Paar, nur nach RV-1). Details: `security-fixplan-42-50.md`.

---

## Release V0.8.2.5 — „Security-Pass"

**Ziel:** Die beiden echten Security-Findings sind geschlossen und die Hygiene-Familie (Shell-Quoting/Boundary) ist konsistent gezogen, bevor V0.8.3 das Paket einfriert. Grundlage: RepoLens-Audit-Triage (`~/20-Workspace/RepoLens/logs/20260912T004309Z-c22e3a62/final/TRIAGE-2026-09-15.md`), Ausarbeitung: `security-fixplan-42-50.md`.

### Inhalt
1. **RV-1 (falls noch nicht erledigt):** Re-Verify von #45/#50/#42 über die gebaute App — entscheidet die finale Severity, vor WP-B2.
2. **WP-S1 (top priority, #49):** Bestätigungs-Dialog vor `openfile:`-Exec (`action_handler.dart:147-160`, Muster `_confirmDeletion`), TDD.
3. **WP-S2 (#44):** Root-Queue-Env härten (LD_*/BASH_ENV/ENV/IFS-Strip, argv[0]-Kanonisierung + Guard, env-Transparenz in `displayCommand`), TDD in `additional/python/tests/`.
4. **WP-S3 (#42+#50+#46):** Hygiene-Bundle — `runInShell: false` an den Disk-Analyzer-Launches + Default-Flip in der Command-Layer + Kommentar-Fix :1496; Depth-Klemme für `folder_recursion_depth`.

### Gates
- Globale CI-Gates; je Paket eigene Gates (TDD-Reihenfolge RED→GREEN, manuelle Proben) — Details im Fix-Plan.
- Reihenfolge WP-S3 nach WP-B2 (beide fassen runInShell-Stellen an).

---

## Release V0.8.3 — „Packaging: Depends & Abhängigkeitslisten"

**Ziel:** Das .deb deklariert die Laufzeitwerkzeuge des neuen Launchers; README und Getting-Started stimmen wieder mit `control` überein.

### Inhalt (Task 3)
1. **`deb/DEBIAN/control:2`:** `Depends: libgtk-3-0, libkeybinder-3.0-0, python3, python3-gi, gir1.2-gtk-3.0, python3-apt, mesa-utils, pkexec | policykit-1, xdg-utils, libgtk-3-bin, libglib2.0-bin` (Paketbeleg per `dpkg -S` auf Zorin 18.1; `libkeybinder-3.0-0` bleibt bis zum Hotkey-Umbau nach V0.8.X).
2. **README.md:** Laufzeitliste (Z. 55–56) und apt-Block (Z. 64–65) um die drei Pakete ergänzen.
3. **Getting-Started.md:** Z. 8 → `sudo apt install libkeybinder-3.0-0 libkeybinder-3.0-dev` (`wmctrl` raus — seit 0.8.0 durch den Single-Instance-Socket ersetzt; `libkeybinder-3.0-0-dev` war ein falscher Paketname); Z. 11–14 Hinweis auf deklarierte Laufzeitpakete.

### Gates
- **Test:** `bash tool/check-versions.sh` → OK.
- **Verify (Pflicht):** `bash build-deb.sh && dpkg-deb -f linux-assistant.deb Depends` endet auf `xdg-utils, libgtk-3-bin, libglib2.0-bin`; `grep -rn "wmctrl\|libkeybinder-3.0-0-dev" README.md docs/wiki` → kein Treffer.
- Commit: „build(deb): depend on xdg-utils, libgtk-3-bin and libglib2.0-bin".

**Fix-Plan-Bezug:** In diesem Release einweben: **WP-P1** (#43, `jfiles.copy_file` → `shutil.copy2`) und **WP-P2** (#48, `jessentials` wget/unzip auf argv-Listen), beide mit Unittests + Upstream-Hinweis (Jean28518/jtools-unix-python — Basti-Task). Details: `security-fixplan-42-50.md`.

---

## Release V0.8.4 — „Cockpit-Scope & Roadmap"

**Ziel:** Die Grill-Entscheidungen sind verbindlich dokumentiert: persönliches Cockpit, Core-Definition, eingefrorene Feature-Matrix, neue Roadmap-Struktur.

### Inhalt
1. **MANIFEST.md (Task 4):** Fork-Hinweis (streichbare Ableitung), neuer Core-Absatz (Hub-Werkzeuge Core; fremde Backends nie Core; apt/systemd/Restic/Docker dürfen Core), Einfrier-Hinweis zur CSV, Kurzfassung (DE) angeglichen.
2. **features.csv (Task 4):** Vier neue Hub-Zeilen (browser launcher, quick notes, file manager, system monitor; je 21 Felder, `yes` nur Zorin OS + GNOME); fork-eigene Zeilen 39–41 ehrlich mit `?` (streichbare Ableitung); AGENTS.md:9–10 Lese-Hinweis.
3. **roadmap.md (Task 5):** DR-Kopfzeile, V0.8.0-Überschrift mit Tag, V0.8.X-Punkte 9+10, neuer Abschnitt „Nach V0.8.X" (Hotkey-gsettings, Browser-Status, Agenten-Tile, Gate-Automatisierung mit Spike), V0.9-Tabelle (Agenten-Tile ersetzt Tokentelemetrie; Gateway Manager + Kanban Watcher gestrichen mit Begründung), Tier-Absatz (24/17/4), Geparkt-Tabelle (7 Themen), verbindliche Nie-Liste + Upstream-Punkte.

### Gates
- **Verify (Pflicht):** CSV-Check `python3 -c …` → `{21} [24, 17, 4]`.
- **Test:** Docs/CSV-only → `check-versions.sh` + `dart format`.
- Commits: „docs: personal-cockpit scope …" und „docs(roadmap): fold in the deep-research review".

---

## Release V0.8.5 — „Release-Gates, Prompt & E2E-Verifikation"

**Ziel:** Der Release-Prozess ist messbar (manuelle Gates pro Session), künftige Recherche läuft über ein sauberes Prompt-Skelett, und die ganze Reihe wird Ende-zu-Ende verifiziert.

### Inhalt
1. **Release-Gates (Task 6):** Release-Process.md — Gate-Tabelle Wayland (`zorin-wayland`) / X11 (`zorin-xorg`): App-Start in Hub, Hotkey (`getHotkeyModifier()`) mit Fokus im Suchfeld, Monitorwechsel, Clipboard (`HermesCopyCommand`), Browser-Werkzeug ohne Snackbar, alle Hub-Werkzeuge, kein Journal-Lärm. Faktenpflege: `version` als Source of Truth, deb einziger Weg, RPM/Arch/Flatpak geparkt, CI-Reihenfolge.
2. **Prompt-Skelett (Task 7):** `docs/handoff/deep-research-verbesserungen.md` komplett neu — harte Regeln („Aussage ohne Link wird verworfen", Nachbarprojekte öffentlich lesen), verifizierter Kontextblock (Stand 2026-09-11) mit Plattform-Fakten und Nie-Liste, genau ein Themen-Slot, Ausgabeformat mit Optionen-Tabelle.
3. **E2E-Verifikation (Verifikations-Abschnitt des Plans):** alle CI-Gates lokal, Paket-Check, echte Kette auf Bastis Rechner, Doku-Checks, dann Basti: `bash install.sh` + Gate-Tabelle in beiden Sessions.

### Gates
- **Verify (Pflicht):** Leak-Check `grep -nE '([0-9]{1,3}\.){3}[0-9]{1,3}|localhost|:[0-9]{4,5}\b|~/|/home/' docs/handoff/deep-research-verbesserungen.md` → kein Treffer.
- **Test (Pflicht):** alle 5 CI-Gates grün (Vollausführung, nicht nur Doku-Gates).
- **Manuell (Pflicht):** Gate-Tabelle in beiden Sessions abgehakt; **erst danach** Push von `hardening/0.8.x-browser-xdg`, Actions-Lauf grün.
- Commits: „docs(release): manual release gates …", „docs(handoff): deep-research prompt skeleton …".

---

## Reihenfolge & Basti-Aufgaben

```text
V0.8.1 (Basis) → V0.8.2 (Code) → V0.8.2.5 (Security-Pass) → V0.8.3 (Paket) → V0.8.4 (Scope) → V0.8.5 (Abschluss)
```

**Bleibt bei Basti (nicht Teil der Releases):** TT-Budgets anlegen, Kommentar in Upstream-#253 (Hypothese mit Link `eb1dfb5`), privater Maintainer-Kontakt, `bash install.sh` (sudo), Gate-Abhaken. `~/.hermes/` wird nicht angefasst; `.zcode/` bleibt untracked.
