# Linux Assistant – Wiki

Willkommen im Wiki des **Linux Assistant** (Fork mit Admin-Hub). Diese Seiten
leben versioniert im Repo unter `docs/wiki/` – gleiches Markdown, gleiche
Namenskonvention wie ein GitHub-Wiki, sodass sie bei Bedarf 1:1 in das
Repo-Wiki übernommen werden können.

**Was ist das?** Ein täglicher Linux-Helfer: mächtige integrierte Suche,
Routine-Checks, administrative Aufgaben – gebaut mit Flutter (Dart) plus
Python-Helferskripten. Seit v0.7.2 zusätzlich ein **Admin-Hub** mit
eingebetteten Werkzeugen in der Sidebar.

## Seiten

| Seite | Inhalt |
|---|---|
| [[Getting-Started]] | Bauen, Installieren, Starten, Hotkey, Deinstallieren |
| [[Architecture]] | Schichten, Hub-Shell, Screen-Tool-Pattern, Services, Stats-Polling |
| [[Admin-Hub]] | Die vier Werkzeuge (Browser, Quick Notes, Dateimanager, Systemmonitor) |
| [[Design-System]] | Mint-Y/Hermes-Tokens, Widget-Katalog, Regeln |
| [[Testing]] | Suite-Überblick, Test-Patterns, Golden-Status |
| [[Release-Process]] | Versionierung, Packaging (deb), CI |
| [[Contributing]] | PR-Workflow, Code-Konventionen, Commit-Stil |
| [[Roadmap]] | v0.8.0-Stand, Kandidaten, parallele Tracks |

## Kern-Dokumente (docs/design/)

- `feature-spec-admin-hub.md` – Spezifikation des Admin-Hub (E1–E4)
- `milestone-v0.7.2.md` – Release-Gate, DoD, Changelog-Vorlage
- `admin-hub-followups.md` – Nacharbeiten-Checkliste (Verifikation, l10n, Goldens)
- `linux-assistant-design-system.md` – Design-System-Referenz
- `design-audit-*.md` – Inventar, Inkonsistenzen, Komponenten-Katalog
- `screenshot-baseline.md` – Golden-Test-Setup

## Schnellzugriff

```bash
# Entwickeln
git clone https://github.com/Toqsick/master-linux-assistant.git
cd linux-assistant && flutter pub get
flutter run -d linux

# Testen
flutter test

# Paket bauen
bash ./build-deb.sh
```
