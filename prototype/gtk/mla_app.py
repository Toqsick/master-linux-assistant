"""GTK4/libadwaita-Scaffold: Demo-Daten, keine Systemaktionen."""
import os
from pathlib import Path

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Adw, Gdk, Gio, Gtk

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
    ('monitor', 'Systemmonitor', 'Datenadapter folgt'),
    ('backup', 'Backup-Cockpit', 'Status unbekannt; Unit-Adapter folgt'),
    ('security', 'Security-Hub', 'Nur lesende Ansicht geplant'),
)

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

    def select_module(self, _sidebar, row):
        if row is None:
            return
        ident = row.module_id
        self.stack.set_visible_child_name(ident)
        self.title.set_text(next(title for key, title, _ in MODULES if key == ident))
        self.details.set_text('Keine Live-Daten oder Admin-Aktionen. ' +
                              ('Ein Backup-Erfolg ist nicht belegt.' if ident == 'backup'
                               else 'Details und Datenquelle folgen.'))

class App(Adw.Application):
    def __init__(self):
        super().__init__(application_id='dev.toqsick.MlaPrototype')

    def do_activate(self):
        apply_forced_color_scheme()
        window = self.props.active_window
        if window is None:
            self._setup_css()
            Adw.StyleManager.get_default().connect(
                'notify::dark', self._on_scheme_changed)
            window = Window(self)
        window.present()

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
