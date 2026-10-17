"""Layout-Gate der GTK-Shell: rechte Detail-Leiste bleibt im Fenster.

Regression der vorbestehenden „gequetschten“ Detail-Leiste (Triage vor #97,
MONITOR.md §7): `Gtk.Paned` liegt im Inhaltsbereich der
`Adw.NavigationSplitView` (Fenster minus Nav-Sidebar), `PANE_POSITION` gilt
ab dessen linker Kante. Mit dem GTK4-Default `shrink-end-child=TRUE`
ignoriert der Trenner die Mindestbreite der Leiste; GTK alloziert sie zwar
mit ihren 280 px, schiebt sie aber über den rechten Rand hinaus, wo der
Paned sie abschneidet (sichtbar blieben ~60 px).

Braucht GTK 4 + libadwaita und ein Display; ohne beides (CI: reines Python,
.github/workflows/build.yml) wird die Klasse übersprungen.

Läuft mit: python3 -m unittest discover -s prototype/gtk/tests (aus dem
Repo-Root).
"""
import sys
import unittest
from pathlib import Path

GTK_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(GTK_DIR))

try:
    import gi
    gi.require_version('Gtk', '4.0')
    gi.require_version('Gdk', '4.0')
    gi.require_version('Adw', '1')
    from gi.repository import Adw, Gdk, Gtk
    # init_check() meldet beim zweiten Aufruf TRUE, auch wenn kein Display
    # aufging (Init-Flag steht schon) — ohne Display segfaultet dann die
    # Allokation. Maßgeblich ist daher das Default-Display.
    GTK_READY = Gtk.init_check() and Gdk.Display.get_default() is not None
except (ImportError, ValueError):
    GTK_READY = False


def paned_width(window_width):
    """Breite des Paned = Fenster minus Nav-Sidebar (Adw-Defaults der Shell)."""
    nav = Adw.NavigationSplitView()
    sidebar = min(max(window_width * nav.get_sidebar_width_fraction(),
                      nav.get_min_sidebar_width()),
                  nav.get_max_sidebar_width())
    return window_width - round(sidebar)


@unittest.skipUnless(GTK_READY, 'GTK 4/libadwaita oder Display fehlt')
class DetailPaneTests(unittest.TestCase):
    def setUp(self):
        import mla_app
        self.app = mla_app
        self.detail = Gtk.Box()
        self.detail.set_size_request(mla_app.DETAILS_MIN_WIDTH, -1)
        self.pane = mla_app.build_detail_pane(Gtk.Box(), self.detail)

    def assert_detail_inside(self, width):
        self.pane.allocate(width, 700, -1, None)
        found, bounds = self.detail.compute_bounds(self.pane)
        self.assertTrue(found)
        right = bounds.get_x() + bounds.get_width()
        self.assertGreaterEqual(bounds.get_width(), self.app.DETAILS_MIN_WIDTH)
        self.assertLessEqual(
            right, width,
            f'Detail-Leiste ragt bei Paned-Breite {width} px bis {right:.0f} px '
            f'(sichtbar {width - bounds.get_x():.0f} px)')

    def test_default_window_shows_full_detail_pane(self):
        """Fenster 1200 → Paned 920 px (Sonde X11: Trenner 850, sichtbar 69 px)."""
        self.assertEqual(paned_width(self.app.WINDOW_DEFAULT[0]), 920)
        self.assert_detail_inside(paned_width(self.app.WINDOW_DEFAULT[0]))

    def test_resize_keeps_detail_pane_inside(self):
        """Compositor-/Nutzer-Resize skaliert den Trenner proportional
        (Sonde Wayland: 954-px-Fenster, Trenner 661, sichtbar 54 px)."""
        for window in (self.app.WINDOW_DEFAULT[0], 954, 900, 1600):
            with self.subTest(window=window):
                self.assert_detail_inside(paned_width(window))


if __name__ == '__main__':
    unittest.main()
