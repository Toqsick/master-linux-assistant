"""GTK-Ansicht des Systemmonitors: Diagramme, Captions, Drill-down (#96).

Je `VALUE_SPECS`-Eintrag eine Zeile aus Caption-Label und
`Gtk.DrawingArea`; Cairo zeichnet Grundlinie und Datenpolyline, die Farben
kommen ausschließlich über `StyleContext.lookup_color()` aus den
bestehenden Tokens (TOKENS.md §1/§8) — kein Hex/rgba im Quelltext. Den
einzigen Zeitgeber besitzt die Shell (`mla_app.py`); `refresh()` zieht nur
Captions und Zeichenflächen nach (D6, Single-Source-Timer).
"""
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gdk, Gtk

from monitor_model import VALUE_SPECS, format_caption

CHART_MIN_HEIGHT = 72      # Diagrammhöhe in px (D6)
ROW_SPACING = 12           # space3 (TOKENS.md §2)
LABEL_SPACING = 4          # space1 (TOKENS.md §2)
BASELINE_TOKEN = 'border-subtle'
LINE_TOKEN = 'accent'
Y_MAX_PERCENT = 100.0      # feste Y-Skala 0…100 % (D6)


class MonitorView(Gtk.Box):
    """Monitor-Screen: je Wert Caption + Diagramm; Klick → Drill-down.

    `on_drill(value_id)` wird bei Klick auf eine Zeile aufgerufen; den
    Refresh-Zyklus stößt die Shell an (`refresh()`), diese Ansicht kennt
    keinen eigenen Timer.
    """

    def __init__(self, sampler, on_drill):
        super().__init__(orientation=Gtk.Orientation.VERTICAL,
                         spacing=ROW_SPACING)
        self._sampler = sampler
        self._on_drill = on_drill
        self._captions = {}
        self._areas = []
        self.set_vexpand(True)
        for spec in VALUE_SPECS:
            row = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                          spacing=LABEL_SPACING)
            caption = Gtk.Label(xalign=0, wrap=True)
            caption.add_css_class('mla-desc')
            area = Gtk.DrawingArea()
            area.set_size_request(-1, CHART_MIN_HEIGHT)
            area.set_hexpand(True)
            area.set_vexpand(True)
            area.set_draw_func(self._draw_chart, spec)
            row.append(caption)
            row.append(area)
            gesture = Gtk.GestureClick()
            gesture.set_button(Gdk.BUTTON_PRIMARY)  # nur Primärklick; Touch/Tap zählt als primär
            gesture.connect('released', self._on_row_clicked, spec.id)
            row.add_controller(gesture)
            self.append(row)
            self._captions[spec.id] = caption
            self._areas.append(area)
        self.refresh()

    def _on_row_clicked(self, _gesture, _n_press, _x, _y, value_id):
        """Klick (losgelassen) auf eine Zeile: Drill-down für ihren Wert."""
        self._on_drill(value_id)

    def _color(self, widget, token):
        """Token-Farbe aus dem Style-Context; Fallback: aktuelle Textfarbe."""
        found, color = widget.get_style_context().lookup_color(token)
        if not found:
            color = widget.get_color()
        return (color.red, color.green, color.blue, color.alpha)

    def _draw_chart(self, area, context, width, height, spec):
        """Ein Diagramm zeichnen: Grundlinie + Polyline über die Slots.

        X: Slot `i` liegt bei `(i + 0,5) × Breite/Kapazität` (älteste
        links, Raster wie `build_series`). Y: 0 % auf der Grundlinie,
        100 % am oberen Rand. `None`-Slots brechen die Linie — nie durch
        0 ziehen; eine leere Serie zeigt nur die Grundlinie.
        """
        if width <= 0 or height <= 0:
            return
        ground_y = height - 1.0
        context.set_line_width(1.0)
        context.set_source_rgba(*self._color(area, BASELINE_TOKEN))
        context.move_to(0.0, ground_y)
        context.line_to(width, ground_y)
        context.stroke()

        series = self._sampler.series(spec.id)
        if not any(value is not None for value in series):
            return
        context.set_source_rgba(*self._color(area, LINE_TOKEN))
        step = width / self._sampler.capacity
        drawing = False
        for index, value in enumerate(series):
            if value is None:
                drawing = False  # Linie bricht an Lücken (D4)
                continue
            x = (index + 0.5) * step
            ratio = min(max(value, 0.0), Y_MAX_PERCENT) / Y_MAX_PERCENT
            y = ground_y - ratio * ground_y
            if drawing:
                context.line_to(x, y)
            else:
                context.move_to(x, y)
                drawing = True
        context.stroke()

    def refresh(self):
        """Captions auf den letzten Tick ziehen und alles neu zeichnen."""
        for spec in VALUE_SPECS:
            latest = self._sampler.latest(spec.id)
            newest_wall = latest.wall if latest is not None else None
            self._captions[spec.id].set_text(format_caption(
                spec, newest_wall, self._sampler.stale_count(spec.id)))
        for area in self._areas:
            area.queue_draw()
