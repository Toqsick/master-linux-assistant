# v0.8.0 — Installations-Verifikation (2026-09-11)

Nachweis, dass das auf dem System installierte Paket dem Branch `hardening/0.8.0`
entspricht und die Kern-Fixes der Version live wirken. Grundlage für Tag/Release.

## Paket & Dateien

- `dpkg -s linux-assistant` → `Status: install ok installed`, `Version: 0.8.0`, `Architecture: amd64`
- Installation via `bash install.sh --purge --yes` (sudo durch Basti, 2026-09-11 ~09:5x)
- md5-Vergleich Branch `additional/python/` vs. `/usr/lib/linux-assistant/additional/python/`:
  `jessentials.py`, `check_security.py`, `read_security_report.py`,
  `check_home_folder_rights.py`, `check_security_fedora.py` — **alle identisch**
- Fix-Marker auf dem System: `systemd_unit_is_active` in installierter `jessentials.py`;
  Erfolgsmarker in allen 4 installierten `check_security*.py`

## App-Start & Smoke-Test (Hub, GDK_BACKEND=x11, DISPLAY=:1)

- Prozess: `/usr/lib/linux-assistant/linux-assistant`, Log zeigt Aufrufe als
  Argument-Listen (`python3 [/usr/lib/linux-assistant/.../get_environment.py]`) — shell-frei
- Stale-Socket-Fix live: `Removing a stale single-instance socket at /run/user/1000/linux-assistant.sock`
  nach jedem Neustart einer gekillten Instanz
- Hub erreicht, Fenstertitel `Linux Assistant`, OCR zeigt `v0.8.0`
- Sektionen angefahren und mit Inhalt belegt (Screenshots `../screenshots/v0.8.0/`):
  Dashboard, Suche, Speicher, Linux-Gesundheit, Dateimanager (Home-Listing),
  Systemmonitor (**Live-1s, CPU 16 Cores, RAM 10.06/15.36, GPU** — Thermal-/GPU-Fixe live),
  Einstellungen → Erscheinungsbild

## Security-Check (der v0.8.0-Kernfix)

Öffnen der Sicherheitsüberprüfung um 10:13:22, pkexec-Prompt von Basti bedient.
Ergebnis: **volle Befundliste statt „Du benötigst Root-Rechte"** — u. a.
„29 Pakete sollten aktualisiert werden" und „Es wurden zusätzliche Paketquellen
gefunden …" (deb822-`.sources`-Parsing lebt, kein IndexError-Crash mehr).

Journal-Evidence (`journalctl`, User in `adm`):

```
Sep 11 10:13:26 polkitd[1290]: Operator of unix-session:3 successfully authenticated as
  unix-user:<user> to gain ONE-SHOT authorization for action
  org.linux-assistant.read-security-report for unix-process:43860:154605
  [/usr/lib/linux-assistant/linux-assistant] (owned by unix-user:<user>)
Sep 11 10:13:26 pkexec[44569]: pam_unix(polkit-1:session): session opened for user
  root(uid=0) by <user>(uid=1000)
Sep 11 10:13:26 pkexec[44569]: <user>: Executing command [USER=root] [TTY=unknown]
  [CWD=/tmp] [COMMAND=/usr/lib/linux-assistant/additional/python/read_security_report.py
  --family=debian --home=/home/<user>]
```

Das bestätigt drei Fix-Ebenen auf einmal: die dedizierte One-Shot-Polkit-Action
(kein `run_script.py`-Freibrief mehr), den family-basierten Dispatch ohne
Dateinamen über die Privilegiengrenze, und den erfolgreichen Root-Lauf selbst.

## Theme-Fix (E.2) live

- Erscheinungsbild zeigt „Farbschema" mit SegmentedButton System/Hell/Dunkel
- Live-Umschaltung Dunkel→Hell in der UI ohne Neustart; `config.json` danach:
  `"theme_mode":"light"` — Persistenz bewiesen
- Vorher/Nachher: `08_appearance_dark_dark.png` → `09_appearance_light_after-switch.png`

## Hinweise / Abweichungen

- First-Run-Wizard („Dein. Linux. Assistent." → After-Installation-Flow) wurde per
  Config (`runFirstStartUp`, `runIntroduction` = false) übersprungen, um keine
  Software-Installationen anzustoßen; Wizard selbst wurde nicht verifiziert (out of scope)
- Security-Erfolg nur im Light-Theme festgehalten (eine pkexec-Runde reicht als Evidence)
- Close-Button des Erscheinungsbild-Screens wurde per Mausklick nicht sicher getroffen
  (Blind-Klick über OCR-Koordinaten); Fix ist durch settings_start.dart:80–86
  („close means pop") und grüne Widget-Tests gedeckt
