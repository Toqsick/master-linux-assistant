"""GTK4/libadwaita-Scaffold: Demo-Daten, keine Systemaktionen."""
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Adw, Gdk, Gtk

MODULES = (
    ('dashboard', 'Dashboard', 'Demo-Lagebild, keine Live-Daten'),
    ('monitor', 'Systemmonitor', 'Datenadapter folgt'),
    ('backup', 'Backup-Cockpit', 'Status unbekannt; Unit-Adapter folgt'),
    ('security', 'Security-Hub', 'Nur lesende Ansicht geplant'),
)

class Window(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title='Master Linux Assistant · Prototyp')
        self.set_default_size(1200, 780)
        self.stack = Gtk.Stack(hexpand=True, vexpand=True)
        self.details = Gtk.Label(xalign=0, yalign=0, wrap=True)
        nav = Adw.NavigationSplitView()
        sidebar_view = Adw.ToolbarView()
        sidebar_view.add_top_bar(Adw.HeaderBar())
        sidebar = Gtk.ListBox()
        for ident, title, _ in MODULES:
            row = Gtk.ListBoxRow()
            row.module_id = ident
            label = Gtk.Label(label=title, xalign=0)
            label.set_margin_start(16)
            label.set_margin_top(12)
            label.set_margin_bottom(12)
            row.set_child(label)
            sidebar.append(row)
        sidebar.connect('row-selected', self.select_module)
        sidebar_view.set_content(sidebar)
        nav.set_sidebar(Adw.NavigationPage.new(sidebar_view, 'Navigation'))
        content_view = Adw.ToolbarView()
        self.title = Gtk.Label(label='Dashboard')
        self.title.add_css_class('mla-gold')
        header = Adw.HeaderBar()
        header.set_title_widget(self.title)
        content_view.add_top_bar(header)
        for ident, title, description in MODULES:
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
            box.set_margin_top(24)
            box.set_margin_start(24)
            heading = Gtk.Label(label=title, xalign=0)
            heading.add_css_class('title-1')
            box.append(heading)
            box.append(Gtk.Label(label=description, xalign=0, wrap=True))
            self.stack.add_named(box, ident)
        detail_panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        detail_panel.set_size_request(280, -1)
        detail_panel.set_margin_top(24)
        detail_panel.set_margin_start(16)
        detail_panel.append(Gtk.Label(label='KONTEXT', xalign=0))
        detail_panel.append(self.details)
        pane = Gtk.Paned.new(Gtk.Orientation.HORIZONTAL)
        pane.set_start_child(self.stack)
        pane.set_end_child(detail_panel)
        pane.set_position(850)
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
        window = self.props.active_window
        if window is None:
            css = Gtk.CssProvider()
            css.load_from_data(b'.mla-gold { color: #b8860b; }')
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(), css,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            window = Window(self)
        window.present()

if __name__ == '__main__':
    App().run()
