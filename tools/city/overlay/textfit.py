"""textfit: how big Roblox TextScaled draws a sign's text, and the PixelsPerStud that makes it sharp.

TextScaled picks the biggest text size (in pixels, at most 100) whose lines fit the label; the
label is the SurfaceGui's face (face size x PixelsPerStud pixels) minus its UIPadding. So the
biggest text a sign can show is 100 / PixelsPerStud studs, and a small sign at the default 25 px
per stud is drawn with a handful of pixels (a blur). fit_pps() measures the text with the real
fonts (tools/city/fonts, Google Fonts; Libre Bodoni stands in for Bodoni, Arimo for Arial) and
returns the PixelsPerStud at which the text fills its box exactly at the 100 px cap: the sharpest
it can be, at the size the box asks for. Used by the CityOverlay sign edits and by the alleys'
generator (tools/city/props_walls.py). Needs PIL; without it, a rough 0.62 em per character.
"""

import math
import os

FONT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "fonts")
FONTS = {"Oswald": "Oswald.ttf", "Arimo": "Arimo.ttf", "Arial": "Arimo.ttf", "Gotham": "Arimo.ttf",
         "GothamBold": "Arimo.ttf", "SourceSans": "Arimo.ttf", "PermanentMarker": "PermanentMarker-Regular.ttf",
         "Kalam": "Kalam-Regular.ttf", "SpecialElite": "SpecialElite-Regular.ttf",
         "Fondamento": "Fondamento-Regular.ttf", "Bodoni": "LibreBodoni.ttf"}
_REF = 200  # measuring size (px)
_cache = {}


def _font(name):
    if name not in _cache:
        try:
            from PIL import ImageFont

            _cache[name] = ImageFont.truetype(os.path.join(FONT_DIR, FONTS.get(name, "Arimo.ttf")), _REF)
        except (ImportError, OSError):
            _cache[name] = None
    return _cache[name]


def strip_rich(text):
    import re

    return re.sub(r"<[^>]+>", "", text)


def line_em(line, font="Oswald"):
    """Width of one line in em (1 em = the text size = TextScaled's line height)."""
    f = _font(font)
    if f is None:
        return 0.62 * len(line)
    return f.getlength(line) / _REF


def text_studs(text, font, w, h, pad=0.0):
    """The text size (studs) TextScaled reaches with no 100 px cap: explicit lines only (the
    signs' texts carry their own \\n, so nothing wraps)."""
    px, py = (pad, pad) if isinstance(pad, (int, float)) else (pad[0], pad[1])
    iw, ih = w * (1 - 2 * px), h * (1 - 2 * py)
    lines = strip_rich(text).split("\n")
    widest = max(line_em(ln, font) for ln in lines) or 1e-6
    return max(1e-3, min(ih / len(lines), iw / widest))


def fit_pps(text, font, w, h, pad=0.0, lo=10, hi=200, scale=1.0):
    """PixelsPerStud so that the 100 px cap is the size the box allows (rounded up: the cap binds,
    so TextScaled draws the lines as given, at 100 px, and never wraps them into a bigger size).
    scale < 1 makes the text that much smaller than the box allows."""
    s = text_studs(text, font, w, h, pad) * scale
    return int(max(lo, min(hi, math.ceil(100 / s))))


def two_lines(text, limit=10, seps=(" · ", " - ", ". ")):
    """A text longer than `limit` characters on two lines: split at a separator (dropped, except
    a full stop), else at the space nearest the middle. Shorter texts stay on one line."""
    if "\n" in text or len(text) <= limit:
        return text
    for sep in seps:
        if sep in text:
            a, b = text.split(sep, 1)
            return (a + sep.strip() if sep == ". " else a) + "\n" + b
    spaces = [i for i, c in enumerate(text) if c == " "]
    if not spaces:
        return text
    i = min(spaces, key=lambda k: abs(k - len(text) / 2))
    return text[:i] + "\n" + text[i + 1:]
