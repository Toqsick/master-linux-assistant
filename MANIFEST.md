Linux Assistant has the goal to assist linux users in their daily use and at administrative tasks. 
It's mission is to unite the major part of the linux community and to profit from synergy effects.
The aim is to support all major and well known linux distributions and desktops.
As long as a certain function or workflow is essential or technically necessary for a distribution, 
it should be payed attention to it and supported/integrated as far as possible and meaningful.
For recommendations of software free software should be preferred to proprietary one, 
as long the free (alternative) is well adapted in the community and has similar functionality.
The installation of Linux Assistant should be very easy. 
As few dependencies as possible should be used.

> **Fork note (removable derivation):** this repository is first a personal
> cockpit for Zorin OS 18.1. The upstream mission above stands unchanged;
> the tiers below are measured on the reference system only.

## Feature tiers

To keep the mission focused, features are grouped into three tiers.
Every feature in `features.csv` carries its tier in the `Category` column.

**Core** — Functions the mission depends on: the daily helper (search,
environment recognition), administrative tasks (package management,
updates, security and health checks, system setup) and the shipped hub
tools (browser launcher, quick notes, file manager, system monitor).
A broken core function is a release blocker on the reference system.
Integrations with foreign backends (TokenTelemetry, Hermes, Odysseus,
weather APIs) are never Core; system components (apt, systemd, Restic,
Docker) may be.

**Quality of Life (QoL)** — Functions that make daily use noticeably more
convenient without adding new mission scope. Rules of thumb:

- No new system dependencies beyond what Core already requires.
- They follow the design system and must degrade gracefully on
  distributions where they are unavailable.
- A missing or broken QoL function is regrettable, but never a release
  blocker.

**Nice to have (n2h)** — Optional extras and integrations. Rules of thumb:

- They are only added if they keep the dependency footprint small and leave
  the security invariants (command queue, polkit policy) untouched.
- They may be invisible on many distributions without hurting the product.
- Removing one is legitimate whenever its maintenance cost exceeds its value.

**Frozen distro matrix:** the distribution and desktop columns of
`features.csv` are frozen at the upstream state — only the reference
system (Zorin OS 18.1, GNOME) is verified by this fork.

Kurzfassung (DE):

- **Core:** Kern der Mission — täglicher Helfer, Admin-Aufgaben und die
  mitgelieferten Hub-Werkzeuge; am Referenzsystem (Zorin OS 18.1) ist ein
  Bruch Release-Blocker. Fremd-Backend-Integrationen sind nie Core,
  Systemkomponenten (apt, systemd, Restic, Docker) dürfen.
- **QoL:** Alltagskomfort ohne neue Missions-Scope — keine neuen
  Abhängigkeiten, folgt dem Design-System, darf auf Distros fehlen.
- **n2h:** Optionale Extras — nur mit kleinem Abhängigkeits-Fußabdruck und
  unangetasteten Security-Invarianten; Entfernung ist legitim.
- **Eingefroren:** Die Distro-/Desktop-Spalten der `features.csv` stehen auf
  Upstream-Stand; verifiziert wird nur das Referenzsystem.