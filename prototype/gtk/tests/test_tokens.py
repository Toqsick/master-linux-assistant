"""Token-Gate für den GTK-Track (Issue #91, A1).

Prüft gegen docs/mla-next/TOKENS.md:
1. Konsistenz: jeder @define-color-Wert in tokens.css/tokens-dark.css ist
   identisch zur Doc-Tabelle bzw. erfüllt die Tone-Formel (fg solid,
   bg 10 %, border 28 % auf bg vorgeblendet).
2. Kontrast: 16 Text-Paare je Schema >= WCAG AA 4,5:1. Schärfe-Nachweis
   (RED-Äquivalent, Muster wie test_fixture_leak_check.py): der Prüfer muss
   eine bekannte schlechte Paarung abweisen und Schwarz/Weiß mit 21:1
   bestehen. focusRing wird NICH als 3:1 behauptet, sondern unter 3:1
   gepinnt (dokumentierte Schwäche, TOKENS.md §5).
3. Hardcode-Gate: keine Hex-/rgb()-Farben in mla_app.py (Regex muss an
   einem Known-Bad-Snippet anschlagen).

Läuft mit: python3 -m unittest discover -s prototype/gtk/tests (aus dem
Repo-Root; auch als CI-Schritt in .github/workflows/build.yml).
"""
import re
import unittest
from pathlib import Path

GTK_DIR = Path(__file__).resolve().parents[1]
TOKENS_CSS = GTK_DIR / 'tokens.css'
TOKENS_DARK_CSS = GTK_DIR / 'tokens-dark.css'
TOKENS_MD = GTK_DIR.parent.parent / 'docs' / 'mla-next' / 'TOKENS.md'
APP_PY = GTK_DIR / 'mla_app.py'

DEFINE_RE = re.compile(r'^\s*@define-color\s+([A-Za-z0-9-]+)\s+([^;]+);')
DOC_ROW_RE = re.compile(
    r'^\|\s*([A-Za-z]+)\s*\|\s*`([a-z0-9-]+)`\s*\|'
    r'\s*(#[0-9A-Fa-f]{6}|rgba\([^)]*\))\s*\|'
    r'\s*(#[0-9A-Fa-f]{6}|rgba\([^)]*\))\s*\|')
RGBA_RE = re.compile(r'rgba\((\d+),(\d+),(\d+),([\d.]+)\)')

TEXT_PAIRS = (
    ('text', 'bg'), ('text', 'surface'), ('text', 'surface-subtle'),
    ('text', 'sidebar'), ('strong', 'bg'), ('muted', 'bg'),
    ('muted', 'surface-subtle'), ('accent-text', 'bg'),
    ('accent-text', 'accent-bg'), ('accent-text', 'accent-bg-strong'),
    ('on-accent', 'accent'), ('error', 'bg'), ('success', 'bg'),
    ('warning', 'bg'), ('info', 'bg'), ('code-text', 'code-bg'),
)
TONE_BASES = {'ok': 'success', 'warn': 'warning', 'crit': 'error',
              'running': 'info'}


def parse_defines(path):
    defines = {}
    depth = 0
    for line in path.read_text(encoding='utf-8').splitlines():
        depth += line.count('{') - line.count('}')
        if depth == 0:
            match = DEFINE_RE.match(line)
            if match:
                defines[match.group(1)] = match.group(2).strip()
    return defines


def parse_doc_colors():
    rows = {}
    for line in TOKENS_MD.read_text(encoding='utf-8').splitlines():
        match = DOC_ROW_RE.match(line)
        if match:
            rows[match.group(2)] = (match.group(3), match.group(4))
    return rows


def parse_color(value):
    value = value.strip()
    if value.startswith('#'):
        return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5)) + (1.0,)
    match = RGBA_RE.match(value)
    if not match:
        raise ValueError('unparsebare Farbe: %r' % value)
    r, g, b, a = match.groups()
    return (int(r), int(g), int(b), float(a))


def blend(fg, alpha, base):
    return tuple(int(f * alpha + b * (1 - alpha) + 0.5)
                 for f, b in zip(fg, base))


def composite(fg, alpha, base):
    return blend(fg, alpha, base)


def _lin(channel):
    c = channel / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(rgb):
    r, g, b = rgb
    return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b)


def contrast_ratio(fg, bg, fg_alpha=1.0):
    if fg_alpha < 1.0:
        fg = composite(fg, fg_alpha, bg)
    lighter, darker = sorted((luminance(fg), luminance(bg)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def schemes():
    return {'light': parse_defines(TOKENS_CSS),
            'dark': parse_defines(TOKENS_DARK_CSS)}


class ConsistencyTests(unittest.TestCase):
    def test_every_doc_color_matches_css(self):
        doc = parse_doc_colors()
        css = schemes()
        self.assertEqual(len(doc), 26)
        for css_name, (light, dark) in doc.items():
            with self.subTest(token=css_name):
                self.assertEqual(css['light'].get(css_name), light)
                self.assertEqual(css['dark'].get(css_name), dark)

    def test_css_defines_cover_exactly_the_doc_tokens(self):
        doc_names = set(parse_doc_colors())
        tone_names = {'tone-%s-%s' % (state, part)
                      for state in list(TONE_BASES) + ['unknown', 'stale']
                      for part in ('fg', 'bg', 'border')}
        for scheme, defines in schemes().items():
            with self.subTest(scheme=scheme):
                self.assertEqual(set(defines), doc_names | tone_names)

    def test_tone_formula(self):
        for scheme, defines in schemes().items():
            bg = parse_color(defines['bg'])[:3]
            for state, base_name in TONE_BASES.items():
                base = parse_color(defines[base_name])[:3]
                expected = {
                    'fg': defines[base_name],
                    'bg': '#%02X%02X%02X' % blend(base, 0.10, bg),
                    'border': '#%02X%02X%02X' % blend(base, 0.28, bg),
                }
                for part, want in expected.items():
                    with self.subTest(scheme=scheme, tone=state, part=part):
                        self.assertEqual(
                            defines['tone-%s-%s' % (state, part)], want)
            for state in ('unknown', 'stale'):
                expected = {'fg': defines['muted'],
                            'bg': defines['surface-subtle'],
                            'border': defines['border']}
                for part, want in expected.items():
                    with self.subTest(scheme=scheme, tone=state, part=part):
                        self.assertEqual(
                            defines['tone-%s-%s' % (state, part)], want)

    def test_stale_differs_structurally_from_ok(self):
        css = TOKENS_CSS.read_text(encoding='utf-8')

        def block(selector):
            match = re.search(r'%s\s*\{(.*?)\}' % re.escape(selector), css,
                              re.DOTALL)
            self.assertIsNotNone(match, 'Selektor fehlt: %s' % selector)
            return match.group(1)

        self.assertIn('border-style: dashed', block('.mla-tone-stale'))
        self.assertIn('border-style: solid', block('.mla-tone-ok'))
        self.assertNotEqual(
            parse_defines(TOKENS_CSS)['tone-stale-fg'],
            parse_defines(TOKENS_CSS)['tone-ok-fg'],
            'stale und ok muessen sich mindestens in der Vordergrundfarbe '
            'unterscheiden')


class ContrastTests(unittest.TestCase):
    def test_text_pairs_meet_aa(self):
        for scheme, defines in schemes().items():
            for fg_name, bg_name in TEXT_PAIRS:
                fg = parse_color(defines[fg_name])
                bg = parse_color(defines[bg_name])
                ratio = contrast_ratio(fg[:3], bg[:3], fg[3])
                with self.subTest(scheme=scheme, pair='%s/%s' % (fg_name, bg_name)):
                    self.assertGreaterEqual(ratio, 4.5)

    def test_checker_rejects_known_bad_pair(self):
        # RED-Beleg: der Pruefer muss anschlagen — Weiß auf Cream (light-bg)
        # liegt bei ~1.06:1, weit unter AA.
        light_bg = parse_color(parse_defines(TOKENS_CSS)['bg'])[:3]
        white = (255, 255, 255)
        self.assertLess(contrast_ratio(white, light_bg), 4.5)

    def test_checker_passes_black_on_white(self):
        # Sanity: Schwarz/Weiß muss exakt 21:1 ergeben (WCAG-Ankerpunkt).
        ratio = contrast_ratio((0, 0, 0), (255, 255, 255))
        self.assertAlmostEqual(ratio, 21.0, delta=0.01)

    def test_focusring_documented_below_3_to_1(self):
        # Pinnt die dokumentierte Schwäche fest (TOKENS.md §5): Gold 35 % auf
        # bg liegt in beiden Schemata UNTER 3:1 — die Doku behauptet nichts
        # anderes. Wenn dieser Test anschlägt, wurden die Ring-Werte geändert
        # und TOKENS.md §5 muss neu bewertet werden.
        for scheme, defines in schemes().items():
            ring = parse_color(defines['focus-ring'])
            bg = parse_color(defines['bg'])[:3]
            ratio = contrast_ratio(ring[:3], bg, ring[3])
            with self.subTest(scheme=scheme):
                self.assertLess(ratio, 3.0)


class HardcodeTests(unittest.TestCase):
    HEX_RE = re.compile(r'#[0-9a-fA-F]{3,8}\b')
    RGB_RE = re.compile(r'\brgba?\(')

    def test_no_color_literals_in_app(self):
        source = APP_PY.read_text(encoding='utf-8')
        for pattern in (self.HEX_RE, self.RGB_RE):
            with self.subTest(pattern=pattern.pattern):
                self.assertEqual(pattern.findall(source), [])

    def test_gate_regex_flags_known_bad_snippet(self):
        # RED-Beleg: das Regex-Gate ist nicht leer — es muss #B8860B in einem
        # Known-Bad-Snippet finden (der vormals reale Verstoß, mla_app.py:84).
        self.assertEqual(self.HEX_RE.findall('color: #B8860B;'), ['#B8860B'])
        self.assertEqual(self.RGB_RE.findall('color: rgba(0,0,0,0.05);'),
                         ['rgba('])


if __name__ == '__main__':
    unittest.main()
