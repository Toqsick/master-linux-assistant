"""GTK4/libadwaita-Shell: Monitor liest ausschließlich /proc (nur lesend),
keine Systemaktionen."""
import os
import time
from pathlib import Path

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Adw, Gdk, Gio, GLib, Gtk

from monitor_model import ProcReader, Sampler, VALUE_SPECS, format_drilldown
from monitor_ui import MonitorView

TOKENS_CSS = Path(__file__).resolve().with_name('tokens.css')
TOKENS_DARK_CSS = Path(__file__).resolve().with_name('tokens-dark.css')

# GTK 4.14.5 kennt kein @media in provider-geladenem CSS — Dark-Werte liegen
# in tokens-dark.css und werden über einen Provider mit höherer Priorität
# zugeschaltet/entfernt, wenn Adw.StyleManager das Schema meldet (TOKENS.md §8).
DARK_PROVIDER_PRIORITY = Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1

# Layout-Tokens aus docs/mla-next/TOKENS.md §2 — Größen, für die GTK kein
# CSS-Äquivalent bietet (Gtk.Box-spacing, Paned-Position, Fenstergröße).
DETAILS_MIN_WIDTH = 280
PANE_POSITION = 850
WINDOW_DEFAULT = (1200, 780)
BOX_SPACING = 12  # space3

MODULES = (
    ('dashboard', 'Dashboard', 'Demo-Lagebild, keine Live-Daten'),
    ('monitor', 'Systemmonitor', '60 × 3 s · /proc'),
    ('backup', 'Backup-Cockpit', 'Status unbekannt; Unit-Adapter folgt'),
    ('security', 'Security-Hub', 'Nur lesende Ansicht geplant'),
)

# Tone-Klassen der Shell (tokens.css, TOKENS.md §4) — der Chip trägt genau eine.
CHIP_TONES = ('ok', 'warn', 'crit', 'running', 'unknown', 'stale')

def apply_forced_color_scheme():
    """Test-Affordance (TOKENS.md §7): MLA_FORCE_COLOR_SCHEME=light|dark
    erzwingt das Farbschema nur innerhalb dieser App über Adw.StyleManager —
    keine Systemeinstellung."""
    scheme = os.environ.get('MLA_FORCE_COLOR_SCHEME', '').strip().lower()
    manager = Adw.StyleManager.get_default()
    if scheme == 'light':
        manager.set_color_scheme(Adw.ColorScheme.FORCE_LIGHT)
    elif scheme == 'dark':
        manager.set_color_scheme(Adw.ColorScheme.FORCE_DARK)

class Window(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title='Master Linux Assistant · Prototyp')
        self.set_default_size(*WINDOW_DEFAULT)
        # Sampler lebt in der Shell: /proc-Reader + monotone/Wanduhr-Quelle;
        # den einzigen Zeitgeber besitzt das Fenster (Single-Source, D6).
        self.sampler = Sampler(
            read=ProcReader().read,
            clock=lambda: (time.monotonic(), time.time()))
        self._tick_source_id = None
        self.stack = Gtk.Stack(hexpand=True, vexpand=True)
        self.details = Gtk.Label(xalign=0, yalign=0, wrap=True)
        self.details.add_css_class('mla-detail-text')
        self.status_chip = Gtk.Label(label='unbekannt', xalign=0)
        self.status_chip.add_css_class('mla-chip')
        self.status_chip.add_css_class('mla-tone-unknown')
        nav = Adw.NavigationSplitView()
        sidebar_view = Adw.ToolbarView()
        sidebar_view.add_top_bar(Adw.HeaderBar())
        sidebar = Gtk.ListBox()
        sidebar.add_css_class('mla-nav')
        for ident, title, _ in MODULES:
            row = Gtk.ListBoxRow()
            row.module_id = ident
            label = Gtk.Label(label=title, xalign=0)
            label.add_css_class('mla-nav-label')
            row.set_child(label)
            sidebar.append(row)
        sidebar.connect('row-selected', self.select_module)
        sidebar_view.set_content(sidebar)
        nav.set_sidebar(Adw.NavigationPage.new(sidebar_view, 'Navigation'))
        content_view = Adw.ToolbarView()
        self.title = Gtk.Label(label='Dashboard')
        self.title.add_css_class('mla-accent-text')
        header = Adw.HeaderBar()
        header.set_title_widget(self.title)
        content_view.add_top_bar(header)
        for ident, title, description in MODULES:
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=BOX_SPACING)
            box.add_css_class('mla-screen')
            heading = Gtk.Label(label=title, xalign=0)
            heading.add_css_class('title-1')
            box.append(heading)
            description_label = Gtk.Label(label=description, xalign=0, wrap=True)
            description_label.add_css_class('mla-desc')
            box.append(description_label)
            if ident == 'monitor':
                self.monitor_view = MonitorView(self.sampler,
                                                self._show_drilldown)
                box.append(self.monitor_view)
            self.stack.add_named(box, ident)
        detail_panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=BOX_SPACING)
        detail_panel.set_size_request(DETAILS_MIN_WIDTH, -1)
        detail_panel.add_css_class('mla-details')
        detail_heading = Gtk.Label(label='KONTEXT', xalign=0)
        detail_heading.add_css_class('mla-detail-heading')
        detail_panel.append(detail_heading)
        detail_panel.append(self.status_chip)
        detail_panel.append(self.details)
        pane = Gtk.Paned.new(Gtk.Orientation.HORIZONTAL)
        pane.set_start_child(self.stack)
        pane.set_end_child(detail_panel)
        pane.set_position(PANE_POSITION)
        content_view.set_content(pane)
        nav.set_content(Adw.NavigationPage.new(content_view, 'Arbeitsbereich'))
        self.set_content(nav)
        sidebar.select_row(sidebar.get_row_at_index(0))
        # Initiales Refresh, Erstbefüllung per direktem _tick (toleriert den
        # Aufruf außerhalb des Timeouts) und der einzige Mess-Zeitgeber;
        # der Doppelstart-Guard armt nur, solange keine Source-ID steht.
        self.monitor_view.refresh()
        self._tick()
        if self._tick_source_id is None:
            self._tick_source_id = GLib.timeout_add_seconds(
                int(self.sampler.interval), self._tick)

    def _tick(self):
        """Ein Messlauf plus Refresh; für den GLib-Zeitgeber SOURCE_CONTINUE."""
        self.sampler.tick()
        self.monitor_view.refresh()
        return GLib.SOURCE_CONTINUE

    def stop_ticking(self):
        """Zeitgeber abbestellen (idempotent); App.do_shutdown ruft dies."""
        if self._tick_source_id is not None:
            GLib.source_remove(self._tick_source_id)
            self._tick_source_id = None

    def _show_drilldown(self, value_id):
        """Drill-down eines Werts in die rechte Detail-Leiste schreiben."""
        spec = next(spec for spec in VALUE_SPECS if spec.id == value_id)
        self.details.set_text(format_drilldown(
            spec, self.sampler.samples(value_id),
            self.sampler.stale_count(value_id)))
        self.details.add_css_class('mla-drilldown')

    def _set_chip(self, text, tone):
        """Status-Chip umschalten (Tone-Klassen wie im Aufbau, TOKENS.md §4)."""
        self.status_chip.set_text(text)
        for name in CHIP_TONES:
            self.status_chip.remove_css_class('mla-tone-' + name)
        self.status_chip.add_css_class('mla-tone-' + tone)

    def select_module(self, _sidebar, row):
        if row is None:
            return
        ident = row.module_id
        self.stack.set_visible_child_name(ident)
        self.title.set_text(next(title for key, title, _ in MODULES if key == ident))
        self.details.remove_css_class('mla-drilldown')
        if ident == 'monitor':
            self.details.set_text('Klick auf ein Diagramm zeigt Quelle, Formel, '
                                  'Toleranz und die letzten Proben.')
            self._set_chip('messend', 'running')
        else:
            self.details.set_text('Keine Live-Daten oder Admin-Aktionen. ' +
                                  ('Ein Backup-Erfolg ist nicht belegt.'
                                   if ident == 'backup'
                                   else 'Details und Datenquelle folgen.'))
            self._set_chip('unbekannt', 'unknown')

class App(Adw.Application):
    def __init__(self):
        super().__init__(application_id='dev.toqsick.MlaPrototype')
        self._window = None

    def do_activate(self):
        apply_forced_color_scheme()
        window = self.props.active_window
        if window is None:
            self._setup_css()
            Adw.StyleManager.get_default().connect(
                'notify::dark', self._on_scheme_changed)
            window = Window(self)
            self._window = window
        window.present()

    def do_shutdown(self):
        # Mess-Zeitgeber des Fensters sauber abbestellen (nur wenn gesetzt).
        if self._window is not None:
            self._window.stop_ticking()
        Adw.Application.do_shutdown(self)

    def _setup_css(self):
        display = Gdk.Display.get_default()
        css = Gtk.CssProvider()
        css.load_from_file(Gio.File.new_for_path(str(TOKENS_CSS)))
        Gtk.StyleContext.add_provider_for_display(
            display, css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self._dark_css = Gtk.CssProvider()
        self._dark_css.load_from_file(Gio.File.new_for_path(str(TOKENS_DARK_CSS)))
        self._apply_dark_provider(Adw.StyleManager.get_default().get_dark())

    def _apply_dark_provider(self, dark):
        display = Gdk.Display.get_default()
        if dark:
            Gtk.StyleContext.add_provider_for_display(
                display, self._dark_css, DARK_PROVIDER_PRIORITY)
        else:
            Gtk.StyleContext.remove_provider_for_display(display, self._dark_css)

    def _on_scheme_changed(self, manager, _pspec):
        self._apply_dark_provider(manager.get_dark())

if __name__ == '__main__':
    App().run()
