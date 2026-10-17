# MLA GTK4-Prototyp

Isolierter, unprivilegierter UI-Spike auf `feature/mla-gtk-scaffold`. `mla_app.py` zeigt Demo-Daten; nur der Monitor-Screen (#96) liest echte Werte, ausschließlich lesend aus fünf festen `/proc`-Dateien (Spec `docs/mla-next/MONITOR.md`). Kein IPC, keine echten Backup-/Security-Checks, keine Admin-Aktionen und keine Paketintegration. Der bestehende Flutter-Hub bleibt unverändert.

## Lokaler Start auf Zorin

Prüfe zuerst GTK4/libadwaita/PyGObject auf dem Zielsystem. Ubuntu-basierte Paketnamen sind typischerweise `python3-gi`, `gir1.2-gtk-4.0`, `gir1.2-adw-1`; nichts davon wird durch diesen Branch installiert. Danach im Repo:

```sh
python3 -m py_compile prototype/gtk/mla_app.py
python3 prototype/gtk/mla_app.py
```

**Nicht mit sudo starten.** `py_compile` prüft nur Syntax. Die GUI braucht eine laufende Desktop-Session; Wayland, X11, Skalierung und Theme wurden von diesem Commit nicht verifiziert.

## Geplanter Aufbau

`mla_app.py` ist die minimale Shell mit NavigationSplitView, HeaderBar, drei Fixture-Screens, dem lesenden Monitor-Screen (#96: `monitor_model.py`, `monitor_ui.py`, Tests unter `tests/`) und rechter Kontextfläche. IPC und weitere Module folgen in getrennten, überprüften Arbeitspaketen. `docs/mla-next/AGENT_PLAN.md` gibt Reihenfolge und Sicherheitsgrenzen vor; `docs/mla-next/IPC_CONTRACT.md` ist ein Wire-Entwurf; `docs/mla-next/VERIFY.md` beschreibt Gates.

Der frühere rsync-Democode aus der Unterhaltung gehört **nicht** zum produktiven Backup-Cockpit aus Issue #63 und wird hier nicht eingecheckt.
