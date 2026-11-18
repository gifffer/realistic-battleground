"""props_ground: the ground clutter and floor detail of the alleys, built from parts.

Every prop is one function

    name(D, folder, origin, ry, rng, **options) -> number of parts made

  • D       a citykit.Data
  • folder  the folder the parts go in (e.g. "Alleys/Props")
  • origin  the floor point (x, y, z) the prop stands on (y = the floor's top)
  • ry      its turn about Y in degrees (its front faces -Z when ry = 0; "against a wall" props
            have the wall behind them, on +Z)
  • rng     a random.Random: sizes, tilts, wear and colours all come from it (no two alike)

Scale: a Roblox character is about 5 studs tall, 1 stud ~ 0.3 m. Small litter is drawn a touch
larger than life so it reads at a character's scale.

Flags: DECOR for litter and floor marks (no collision, no shadow), DECOR_SHADOW for loose things
that should still shade the ground, SMALL / PROP for things a player bumps into or stands on.

Only built-in Materials and colours (no textures, no meshes). The 2024 Materials "Cardboard" and
"Carpet" are used for cardboard and the carpet roll; set CARDBOARD_MAT / CARPET_MAT to
"SmoothPlastic" / "Fabric" if a build ever lacks them.

NO BOTTLES of any kind (glass or plastic, decoration or litter): there is none in here, keep it so.

CATALOGUE lists every prop with a few option sets for tools/city/preview_props_ground.py.
"""

import functools
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from citykit import (  # noqa: E402
    BALL,
    CYLINDER,
    DECOR,
    DECOR_SHADOW,
    PROP,
    SMALL,
    WEDGE,
    Frame,
    mix,
)

CARDBOARD_MAT = "Cardboard"
CARPET_MAT = "Carpet"

# -- palette (dirty, desaturated; matches alleys.py) -------------------------------------------
PAPER = [(178, 172, 156), (164, 158, 142), (170, 156, 124), (150, 146, 134), (182, 178, 166)]
NEWSPRINT = (156, 152, 140)
INK = (46, 45, 44)
FLYER = [(150, 60, 50), (60, 90, 120), (176, 150, 60), (90, 110, 70), (160, 150, 140)]
CARDBOARD = (132, 106, 72)
CARDBOARD_DARK = (104, 84, 58)
CARDBOARD_WET = (72, 58, 42)
TAPE = (158, 136, 96)
BAG = [(20, 20, 23), (24, 24, 27), (36, 38, 42), (30, 38, 32), (44, 46, 52)]
BAG_INSIDE = (10, 9, 9)
FOOD = [(74, 54, 34), (92, 76, 44), (58, 46, 34), (110, 92, 60)]
FOAM = (192, 188, 176)
LEAF = [(92, 62, 34), (110, 80, 40), (72, 50, 30), (120, 96, 52), (66, 60, 36), (54, 40, 28), (84, 70, 44)]
SOIL = (52, 44, 36)
SOIL_DARK = (36, 31, 27)
DUST = (104, 99, 91)
WOOD = (104, 87, 60)
WOOD_OLD = (82, 70, 54)
WOOD_GREY = (98, 94, 86)
WOOD_DARK = (58, 46, 36)
WOOD_FRESH = (150, 122, 86)
PALLET = [(122, 102, 72), (108, 92, 66), (96, 88, 74), (130, 112, 80)]
BRICK = [(84, 60, 50), (96, 64, 52), (68, 49, 42), (80, 44, 36), (102, 70, 56)]
MORTAR = (118, 112, 102)
CONCRETE = (116, 113, 106)
CONCRETE_OLD = (92, 89, 84)
CONCRETE_FRESH = (146, 142, 134)
CINDER = (112, 110, 104)
ASPHALT = (46, 47, 50)
ASPHALT_NEW = (34, 34, 36)
ASPHALT_WORN = (64, 64, 66)
TAR = (14, 14, 15)
RUST = (89, 47, 30)
RUST_DARK = (59, 29, 19)
RUST_LIGHT = (122, 70, 40)
GALVANISED = (112, 114, 112)
IRON = (46, 44, 42)
RUBBER = (30, 30, 32)
RUBBER_OLD = (48, 47, 46)
OIL = (14, 13, 13)
DAMP = (28, 27, 26)
GRASS = [(62, 76, 40), (52, 64, 34), (84, 86, 48), (104, 98, 58), (70, 82, 44)]
MOSS = [(44, 56, 30), (38, 48, 26), (56, 64, 34)]
WATER = (38, 42, 48)
GUM = [(60, 60, 62), (46, 46, 48), (78, 76, 74), (36, 36, 38)]
PAINT = {"orange": (196, 98, 42), "white": (188, 186, 176), "yellow": (186, 162, 62), "red": (150, 44, 40),
         "blue": (60, 92, 140)}
CHALK = (200, 198, 188)
TARP = [(38, 56, 74), (52, 62, 44), (70, 74, 78), (92, 70, 44)]
CARPET = [(98, 44, 38), (70, 52, 46), (64, 60, 78), (96, 82, 58)]
JUTE = (138, 118, 86)
ROPE = [(132, 116, 84), (60, 82, 104), (110, 58, 40), (82, 84, 70)]
CRATE = [(120, 40, 36), (40, 60, 92), (34, 34, 36), (48, 76, 52)]
CONE = (196, 86, 38)

CATALOGUE = []  # [(function, [options, ...])]


def prop(*variants):
    """Registers a prop for the catalogue and makes it return the number of parts it made."""

    def wrap(fn):
        @functools.wraps(fn)
        def inner(D, folder, origin, ry, rng, **opts):
            n0 = len(D.parts)
            fn(D, folder, origin, ry, rng, **opts)
            return len(D.parts) - n0

        CATALOGUE.append((inner, list(variants) or [{}]))
        return inner

    return wrap


# ------------------------------------------------------------------ building helpers
def _ball(f, name, c, d, color, mat, flags=DECOR, **kw):
    """A sphere (Roblox balls are always round: one diameter)."""
    return f.part(name, c, (d, d, d), color, mat, shape=BALL, flags=flags, **kw)


def _cyl(f, name, c, length, d, color, mat, rot=(0, 0, 0), flags=DECOR, **kw):
    """A cylinder along local X (Roblox cylinders are round: one diameter)."""
    return f.part(name, c, (length, d, d), color, mat, rot=rot, shape=CYLINDER, flags=flags, **kw)


def _disk(f, name, x, z, d, th, color, mat, y=0.0, flags=DECOR, **kw):
    """A flat disk lying on the floor (a cylinder turned upright)."""
    return f.part(name, (x, y + th / 2, z), (th, d, d), color, mat, rot=(0, 0, 90), shape=CYLINDER, flags=flags,
                  **kw)


def _flat(f, name, x, z, w, d, th, color, mat, yaw=0.0, y=0.0, flags=DECOR, **kw):
    """A flat plate lying on the floor."""
    return f.part(name, (x, y + th / 2, z), (w, th, d), color, mat, rot=(0, yaw, 0), flags=flags, **kw)


def _tri(f, name, x, z, w, d, th, color, mat, yaw=0.0, y=0.0, flags=DECOR, **kw):
    """A flat right triangle lying on the floor (a wedge on its side): legs w (along -X) and d (Z)."""
    return f.part(name, (x, y + th / 2, z), (th, w, d), color, mat, rot=(0, yaw, 90), shape=WEDGE, flags=flags,
                  **kw)


def _seg_rot(p0, p1):
    vx, vy, vz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
    length = math.sqrt(vx * vx + vy * vy + vz * vz)
    ry = math.degrees(math.atan2(-vz, vx))
    rz = math.degrees(math.asin(max(-1.0, min(1.0, vy / max(length, 1e-6)))))
    mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)
    return mid, length, ry, rz


def _rod(f, name, p0, p1, d, color, mat, flags=DECOR, extend=0.0, **kw):
    """A round rod from p0 to p1 (local points)."""
    mid, length, ry, rz = _seg_rot(p0, p1)
    return _cyl(f, name, mid, length + extend, d, color, mat, rot=(0, ry, rz), flags=flags, **kw)


def _bar(f, name, p0, p1, w, th, color, mat, flags=DECOR, extend=0.0, roll=0.0, **kw):
    """A flat bar from p0 to p1 (width w across, thickness th up)."""
    mid, length, ry, rz = _seg_rot(p0, p1)
    m = f.m
    g = Frame(f.D, f.folder, f.world(mid), matrix=m)
    return g.part(name, (0, 0, 0), (length + extend, th, w), color, mat, rot=(roll, ry, rz), flags=flags, **kw)


def _tone(color, rng, amount=8, darken=0.0):
    """A colour a little lighter or darker each time, keeping its hue (per-channel noise would turn
    browns pink or green): amount ~ the brightness swing in colour units."""
    mean = max(1.0, sum(color) / 3)
    k = (1 + rng.uniform(-amount, amount) / mean) * (1 - darken)
    return tuple(max(0, min(255, c * k + rng.uniform(-2, 2))) for c in color)


def _pick(rng, seq):
    return seq[rng.randrange(len(seq))]


def _w(f, x, z, y=0.0):
    """A local floor point as a world tuple (to place a sub-prop)."""
    return tuple(float(v) for v in f.world((x, y, z)))


def _yaw(f):
    """The frame's own turn about Y in degrees (for sub-props)."""
    return math.degrees(math.atan2(f.m[0, 2], f.m[2, 2]))


# =============================================================================================
# Paper, cardboard, wrappers, butts
# =============================================================================================
@prop({}, {"size": 0.55}, {"size": 0.38})
def paper_ball(D, folder, origin, ry, rng, size=None, color=None):
    """A crumpled ball of paper. Footprint 0.4-0.8 studs. 2-4 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    s = size or rng.uniform(0.36, 0.56)
    col = color or _tone(_pick(rng, PAPER), rng, 10, darken=rng.uniform(0, 0.3))
    y = s * 0.42
    _ball(f, "PaperBall", (0, y, 0), s, col, "SmoothPlastic")
    # crumple facets: a cube turned askew, its corners poke out of the ball
    f.part("PaperCrease", (0, y, 0), (s * 0.76, s * 0.7, s * 0.74), _tone(col, rng, 8, 0.06), "SmoothPlastic",
           rot=(rng.uniform(20, 70), rng.uniform(0, 90), rng.uniform(20, 70)), flags=DECOR)
    for _ in range(rng.randint(0, 2)):
        a = rng.uniform(0, 2 * math.pi)
        d = s * rng.uniform(0.45, 0.65)
        _ball(f, "PaperBall", (math.cos(a) * s * 0.3, d * 0.4, math.sin(a) * s * 0.3), d, _tone(col, rng, 8),
              "SmoothPlastic")


@prop({"kind": "sheet"}, {"kind": "newspaper"}, {"kind": "newspaper", "wet": True}, {"kind": "flyer"})
def paper_sheet(D, folder, origin, ry, rng, kind="sheet", wet=None):
    """A loose sheet / an open newspaper / a flyer lying flat, its crease lifted, maybe soaked.
    Footprint: sheet 0.7 x 1.0, newspaper (open spread) 1.9 x 1.4, flyer 0.6 x 0.85 studs. 3-8 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    if kind == "newspaper":
        W, L = rng.uniform(0.85, 1.0), rng.uniform(1.2, 1.4)
        col = _tone(NEWSPRINT, rng, 6, darken=rng.uniform(0.05, 0.25))
    elif kind == "flyer":
        W, L = rng.uniform(0.55, 0.65), rng.uniform(0.8, 0.9)
        col = _tone(_pick(rng, FLYER), rng, 10, darken=rng.uniform(0.1, 0.35))
    else:
        W, L = rng.uniform(0.66, 0.74), rng.uniform(0.95, 1.05)
        col = _tone(_pick(rng, PAPER), rng, 8, darken=rng.uniform(0, 0.25))
    wet = (rng.random() < 0.35) if wet is None else wet
    th = 0.05
    if kind == "newspaper":
        # an open spread, trodden on: the left page lies flat (its headline and a print block
        # barely darker than the paper), the right page is crumpled along its middle: its outer
        # half lifted and twisted, a corner dog-eared; a grey shoe print across the fold
        f.part("Paper", (-W / 2, th / 2, 0), (W, th, L), _tone(col, rng, 4), "SmoothPlastic", flags=DECOR,
               rot=(0, rng.uniform(-2, 2), 0))
        f.part("Print", (-W / 2, th + 0.004, -L * 0.36), (W * 0.8, th, 0.1), mix(col, INK, 0.55), "SmoothPlastic",
               flags=DECOR)
        f.part("Print", (-W / 2 + rng.uniform(-0.05, 0.05), th + 0.002, L * 0.1), (W * 0.74, th, L * 0.56),
               mix(col, INK, 0.16), "SmoothPlastic", flags=DECOR)
        g = f.sub((0.02, 0, rng.uniform(-0.06, 0.06)), ry=rng.uniform(2, 8))
        g.part("Paper", (W * 0.25, th / 2 + 0.006, 0), (W / 2, th, L), _tone(col, rng, 4), "SmoothPlastic",
               flags=DECOR)
        h = g.sub((W / 2, th, 0), rz=rng.uniform(8, 22), rx=rng.uniform(-6, 6))
        h.part("Paper", (W * 0.24, -th / 2, 0), (W * 0.48, th, L * rng.uniform(0.92, 0.98)), _tone(col, rng, 6, 0.04),
               "SmoothPlastic", flags=DECOR)
        # a dog-eared corner folded back over the lifted half
        _tri(h, "Paper", W * 0.38, -L / 2 + 0.16, 0.26, 0.26, th, mix(col, DUST, 0.3), "SmoothPlastic", y=0.004,
             yaw=rng.uniform(-8, 8))
        f.part("ShoePrint", (rng.uniform(-0.25, 0.05), th + 0.012, rng.uniform(-0.25, 0.25)), (0.42, 0.05, 0.95),
               (44, 40, 36), "SmoothPlastic", flags=DECOR, transparency=0.55, rot=(0, rng.uniform(-40, 40), 0))
    else:
        _flat(f, "Paper", 0, -L / 4, W, L / 2, th, col, "SmoothPlastic")
        # the other half folded on the crease, lifted a little
        g = f.sub((0, th, 0), rx=-rng.uniform(2, 7), ry=rng.uniform(-4, 4))
        g.part("Paper", (0, -th / 2, L / 4), (W * rng.uniform(0.96, 1.0), th, L / 2), _tone(col, rng, 5),
               "SmoothPlastic", flags=DECOR)
        if kind == "flyer":
            _flat(f, "Print", 0, -L / 4, W * 0.7, L * 0.3, th, mix(col, INK, 0.6), "SmoothPlastic", y=th * 0.6,
                  transparency=0.3)
        else:
            # a curled-up corner
            _tri(f, "Paper", W / 2 - 0.08, -L / 2 + 0.12, 0.22, 0.22, th, _tone(col, rng, 6), "SmoothPlastic",
                 y=th * 0.9, yaw=rng.uniform(-10, 10))
    if wet:
        _disk(f, "WetPaper", rng.uniform(-W, W) * 0.2, -L / 4 + rng.uniform(-0.1, 0.1), min(W, L / 2) * 0.9, th,
              mix(col, CARDBOARD_WET, 0.6), "SmoothPlastic", y=th * 0.9, transparency=0.35)


@prop({}, {"wet": True}, {"torn": True, "w": 3.6})
def cardboard_flat(D, folder, origin, ry, rng, w=None, d=None, wet=None, torn=None):
    """A flattened cardboard box on the floor: two faces peaked at the crease, its flaps (one torn,
    one bent up), packing tape, soggy dark patches. Footprint 2.6-3.8 x 2.6-4 studs. 8-10 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    W = w or rng.uniform(2.6, 3.6)
    L = d or rng.uniform(1.8, 2.6)
    fl = L * rng.uniform(0.32, 0.45)
    base = _tone(CARDBOARD, rng, 8, darken=rng.uniform(0, 0.18))
    wet = (rng.random() < 0.5) if wet is None else wet
    torn = (rng.random() < 0.5) if torn is None else torn
    th = 0.06
    a = rng.uniform(1.5, 4.0)
    torn_flap = rng.randrange(4) if torn else -1
    bent_flap = rng.randrange(4)
    k = 0
    for s in (-1, 1):
        g = f.sub((s * W / 2, 0, 0), rz=-s * a)
        col = _tone(base, rng, 5)
        g.part("Cardboard", (-s * W / 4, th / 2, 0), (W / 2 - 0.02, th, L), col, CARDBOARD_MAT, flags=DECOR)
        for e in (-1, 1):
            fc = _tone(base, rng, 6, darken=0.05)
            if k == torn_flap:
                _tri(g, "Cardboard", -s * W / 4, e * (L / 2 + fl / 2), W / 2 - 0.05, fl * 0.95, th, fc, CARDBOARD_MAT,
                     yaw=90 if s * e > 0 else -90)
            elif k == bent_flap:
                h = g.sub((-s * W / 4, th, e * L / 2), rx=e * rng.uniform(-35, -15))
                h.part("Cardboard", (0, -th / 2, e * fl / 2), (W / 2 - 0.06, th, fl), fc, CARDBOARD_MAT, flags=DECOR)
            else:
                g.part("Cardboard", (-s * W / 4, th / 2, e * (L / 2 + fl / 2 + 0.03)), (W / 2 - 0.05, th, fl), fc,
                       CARDBOARD_MAT, flags=DECOR)
            k += 1
    # packing tape over the crease (lifted with it)
    lift = (W / 2) * math.sin(math.radians(a))
    f.part("Tape", (0, lift + th * 0.9, rng.uniform(-0.1, 0.1)), (0.22, 0.05, L * 0.9), TAPE, "SmoothPlastic",
           flags=DECOR, transparency=0.25, rot=(0, rng.uniform(-3, 3), 0))
    if wet:
        # a blotchy soaked patch: a few overlapping blots
        sx, sz = rng.choice((-1, 1)) * W * rng.uniform(0.1, 0.25), rng.uniform(-L, L) * 0.2
        for i in range(3):
            _disk(f, "Soggy", sx + rng.uniform(-0.4, 0.4), sz + rng.uniform(-0.3, 0.3), L * rng.uniform(0.3, 0.55),
                  0.05 + 0.004 * i, CARDBOARD_WET, CARDBOARD_MAT, y=lift * 0.5 + 0.02, transparency=0.35 + 0.1 * i)
    else:
        # a muddy shoe smear
        _flat(f, "Dirt", rng.uniform(-W, W) * 0.2, rng.uniform(-L, L) * 0.2, 0.5, 1.1, 0.05, SOIL, "Ground",
              yaw=rng.uniform(0, 180), y=lift * 0.5 + 0.02, transparency=0.45)


@prop({"state": "open"}, {"state": "closed"}, {"state": "crushed"}, {"state": "open", "wet": True})
def cardboard_box(D, folder, origin, ry, rng, size=None, state=None, wet=None):
    """A battered cardboard box standing on the floor: open (flaps splayed at odd angles, one torn
    off), closed (taped lid), or crushed (a wall caved in, the lid sagging). Water-stained bottom,
    a shipping label, hand holes. Footprint 1.4-2.6 x 1.4-2.2 studs, 1.2-2 tall. 8-14 parts, SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    W, H, Dp = size or (rng.uniform(1.5, 2.5), rng.uniform(1.2, 1.9), rng.uniform(1.3, 2.1))
    state = state or _pick(rng, ["open", "open", "closed", "crushed"])
    wet = (rng.random() < 0.5) if wet is None else wet
    col = _tone(CARDBOARD, rng, 8, darken=rng.uniform(0, 0.2))
    th = 0.07
    M = CARDBOARD_MAT
    f.box("Cardboard", (-W / 2, 0, -Dp / 2), (W / 2, th, Dp / 2), mix(col, CARDBOARD_WET, 0.5), M, flags=SMALL)
    # walls (front -Z, back, left, right)
    if state == "crushed":
        cut = H * rng.uniform(0.4, 0.6)
        f.box("Cardboard", (-W / 2, 0, -Dp / 2), (W / 2, cut, -Dp / 2 + th), _tone(col, rng, 4), M, flags=SMALL)
        g = f.sub((0, cut, -Dp / 2), rx=rng.uniform(14, 26), rz=rng.uniform(-4, 4))
        g.box("Cardboard", (-W / 2 + 0.02, 0, 0), (W / 2 - 0.02, H - cut, th), _tone(col, rng, 6, 0.04), M,
              flags=SMALL)
    else:
        f.box("Cardboard", (-W / 2, 0, -Dp / 2), (W / 2, H, -Dp / 2 + th), _tone(col, rng, 4), M, flags=SMALL)
    f.box("Cardboard", (-W / 2, 0, Dp / 2 - th), (W / 2, H, Dp / 2), _tone(col, rng, 4), M, flags=SMALL)
    f.box("Cardboard", (-W / 2, 0, -Dp / 2 + th), (-W / 2 + th, H, Dp / 2 - th), _tone(col, rng, 4, 0.05), M,
          flags=SMALL)
    f.box("Cardboard", (W / 2 - th, 0, -Dp / 2 + th), (W / 2, H, Dp / 2 - th), _tone(col, rng, 4, 0.05), M,
          flags=SMALL)
    if state == "closed":
        f.box("Cardboard", (-W / 2, H, -Dp / 2), (W / 2, H + th, Dp / 2), _tone(col, rng, 4), M, flags=SMALL)
        f.part("Tape", (rng.uniform(-0.05, 0.05), H + th + 0.02, 0), (0.24, 0.05, Dp + 0.1), TAPE, "SmoothPlastic",
               flags=DECOR, transparency=0.2, rot=(0, rng.uniform(-2, 2), 0))
        # the tape runs down the front, peeling
        f.part("Tape", (0, H - 0.25, -Dp / 2 - 0.03), (0.24, 0.5, 0.05), TAPE, "SmoothPlastic", flags=DECOR,
               transparency=0.2, rot=(rng.uniform(-12, -4), 0, rng.uniform(-6, 6)))
    elif state == "crushed":
        # the lid sags into the box, toward the caved wall
        g = f.sub((0, H, Dp / 2), rx=rng.uniform(14, 24), rz=rng.uniform(-6, 6))
        g.part("Cardboard", (0, th / 2, -Dp / 2), (W - 0.06, th, Dp), _tone(col, rng, 5), M, flags=SMALL)
        g.part("Tape", (0.05, th + 0.02, -Dp / 2), (0.24, 0.05, Dp * 0.9), TAPE, "SmoothPlastic", flags=DECOR,
               transparency=0.25)
    else:
        missing = rng.randrange(4)
        for i, (hinge, rot_axis, centre, size) in enumerate((
                ((0, H, -Dp / 2), "x-", (0, 0, Dp * 0.24), (W - 0.04, th, Dp * 0.48)),
                ((0, H, Dp / 2), "x+", (0, 0, -Dp * 0.24), (W - 0.04, th, Dp * 0.48)),
                ((-W / 2, H, 0), "z+", (W * 0.22, 0, 0), (W * 0.44, th, Dp - 0.04)),
                ((W / 2, H, 0), "z-", (-W * 0.22, 0, 0), (W * 0.44, th, Dp - 0.04)))):
            if i == missing and rng.random() < 0.6:
                continue
            ang = rng.uniform(100, 165) if rng.random() < 0.8 else rng.uniform(25, 50)  # splayed / drooping in
            sgn = -1 if rot_axis[1] == "-" else 1
            if rot_axis[0] == "x":
                g = f.sub(hinge, rx=sgn * ang, rz=rng.uniform(-6, 6))
            else:
                g = f.sub(hinge, rz=sgn * ang, rx=rng.uniform(-6, 6))
            g.part("Flap", centre, size, _tone(col, rng, 7, 0.03), M, flags=DECOR_SHADOW)
    if wet:
        wb = rng.uniform(0.25, 0.55)
        f.box("WetBand", (-W / 2 - 0.02, 0, -Dp / 2 - 0.02), (W / 2 + 0.02, wb, -Dp / 2 + 0.03), CARDBOARD_WET, M,
              flags=DECOR, transparency=0.15)
        f.box("WetBand", (W / 2 - 0.03, 0, -Dp / 2 - 0.02), (W / 2 + 0.02, wb * rng.uniform(0.7, 1.3), Dp / 2 + 0.02),
              CARDBOARD_WET, M, flags=DECOR, transparency=0.15)
    # shipping label, half torn
    if rng.random() < 0.7:
        f.part("Label", (-W / 2 - 0.02, H * rng.uniform(0.45, 0.65), rng.uniform(-0.2, 0.2) * Dp),
               (0.05, 0.42, 0.6), _tone((176, 172, 160), rng, 8, 0.1), "SmoothPlastic", flags=DECOR,
               rot=(rng.uniform(-8, 8), 0, 0))
    # hand holes (dark slots) in the side walls
    if rng.random() < 0.6:
        for s in (-1, 1):
            f.part("HandHole", (s * (W / 2 + 0.005), H * 0.78, 0), (th + 0.03, 0.18, 0.5), TAR, "SmoothPlastic",
                   flags=DECOR)


@prop({"kind": "packet"}, {"kind": "takeaway"}, {"kind": "cup"}, {"kind": "foil"})
def wrapper(D, folder, origin, ry, rng, kind=None):
    """Food litter: a crushed crisp packet, an open foam takeaway box with leftovers, a stamped-flat paper
    coffee cup (lid popped off, sleeve, a spill), or a crumpled foil ball. Footprint 0.4-1.6 studs. 2-5 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["packet", "packet", "takeaway", "cup", "foil"])
    if kind == "packet":
        col = _tone(_pick(rng, FLYER), rng, 12, darken=rng.uniform(0.05, 0.3))
        tw = rng.uniform(8, 25)
        f.part("Wrapper", (-0.02, 0.06, -0.2), (0.6, 0.12, 0.42), col, "Plastic", flags=DECOR,
               rot=(rng.uniform(-6, 6), 0, rng.uniform(-8, 8)), reflectance=0.08)
        f.part("Wrapper", (0.02, 0.07, 0.18), (0.58, 0.13, 0.42), _tone(col, rng, 8), "Plastic", flags=DECOR,
               rot=(rng.uniform(-10, 10), tw, rng.uniform(-10, 10)), reflectance=0.08)
        for e in (-1, 1):  # crimped seals, silver
            f.part("Seal", (0, 0.04, e * 0.42), (0.66, 0.06, 0.1), (150, 150, 146), "Metal", flags=DECOR,
                   rot=(e * rng.uniform(4, 15), tw * (0.5 + e * 0.5), 0))
    elif kind == "takeaway":
        foam = _tone(FOAM, rng, 6, darken=rng.uniform(0.05, 0.3))
        f.box("Takeaway", (-0.45, 0, -0.45), (0.45, 0.28, 0.45), foam, "SmoothPlastic", flags=DECOR)
        _flat(f, "Leftovers", rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 0.62, 0.55, 0.05,
              _pick(rng, FOOD), "Sand", y=0.27, yaw=rng.uniform(0, 30))
        k = rng.random()
        if k < 0.75:  # lid on its hinge: thrown back flat, or half shut over the leftovers
            g = f.sub((0, 0.28, 0.45), rx=rng.uniform(150, 176) if k < 0.5 else rng.uniform(25, 50),
                      rz=rng.uniform(-8, 8))
            g.box("Lid", (-0.45, 0, -0.9), (0.45, 0.16, 0), _tone(foam, rng, 6), "SmoothPlastic", flags=DECOR)
        else:  # torn off, lying upside down beside it
            f.part("Lid", (rng.uniform(-0.3, 0.3), 0.08, -1.0), (0.9, 0.16, 0.9), _tone(foam, rng, 6),
                   "SmoothPlastic", flags=DECOR, rot=(rng.uniform(-6, 6), rng.uniform(0, 90), rng.uniform(-6, 6)))
        _disk(f, "Grease", rng.uniform(-0.3, 0.3), -0.55, 0.5, 0.05, OIL, "SmoothPlastic", transparency=0.55)
    elif kind == "cup":
        # a paper coffee cup stamped flat: a squashed tapered body (wider at the mouth), the
        # cardboard sleeve slid down it, the lid popped off beside it, a dried coffee spill
        col = _tone((176, 170, 158), rng, 8, darken=rng.uniform(0, 0.25))
        g = f.sub((0, 0, 0), ry=rng.uniform(-10, 10))
        g.part("Cup", (0, 0.07, 0), (0.62, 0.13, 0.3), col, "SmoothPlastic", flags=DECOR,
               rot=(rng.uniform(-4, 4), 0, rng.uniform(-3, 3)))
        g.part("Cup", (-0.25, 0.08, 0), (0.16, 0.15, 0.4), _tone(col, rng, 5), "SmoothPlastic", flags=DECOR,
               rot=(rng.uniform(-8, 8), rng.uniform(-6, 6), 0))
        g.part("Sleeve", (0.02, 0.075, 0), (0.24, 0.155, 0.36), _tone(CARDBOARD, rng, 8), CARDBOARD_MAT, flags=DECOR,
               rot=(0, rng.uniform(-5, 5), 0))
        _disk(f, "CupLid", rng.uniform(-0.75, -0.5), rng.uniform(-0.35, 0.35), 0.36, 0.06, (40, 40, 42), "Plastic")
        _disk(f, "Spill", -0.45, rng.uniform(-0.15, 0.15), rng.uniform(0.5, 0.8), 0.05, (44, 32, 22), "SmoothPlastic",
              transparency=0.5)
    else:
        s = rng.uniform(0.28, 0.4)
        _ball(f, "Foil", (0, s * 0.42, 0), s, (150, 150, 148), "Metal", reflectance=0.1)
        f.part("Foil", (0, s * 0.42, 0), (s * 0.78,) * 3, (136, 136, 134), "Metal",
               rot=(rng.uniform(20, 70), rng.uniform(0, 90), rng.uniform(20, 70)), flags=DECOR)


@prop({}, {"count": 7})
def cigarette_butts(D, folder, origin, ry, rng, count=None, radius=0.7):
    """A few cigarette butts where someone stood and smoked, over a grey ash smudge.
    Footprint ~1.4 studs. 3-10 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    n = count or rng.randint(3, 6)
    _disk(f, "Ash", 0, 0, radius * rng.uniform(1.0, 1.4), 0.05, (82, 80, 76), "Sand", transparency=0.6)
    for i in range(n):
        r = radius * math.sqrt(rng.random())
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.07, 0.085)
        length = rng.uniform(0.22, 0.32)
        col = _tone((178, 142, 92) if rng.random() < 0.7 else (186, 182, 170), rng, 10, darken=rng.uniform(0, 0.3))
        _cyl(f, "Butt", (math.cos(a) * r, d / 2, math.sin(a) * r), length, d, col, "SmoothPlastic",
             rot=(0, rng.uniform(0, 180), 0))
        if i == 0:  # one barely smoked: its paper and burnt tip
            yaw = rng.uniform(0, 180)
            _cyl(f, "Butt", (math.cos(a) * r + 0.25, d / 2, math.sin(a) * r), 0.24, d * 0.95, (184, 180, 170),
                 "SmoothPlastic", rot=(0, yaw, 0))


@prop({}, {"width": 5, "depth": 2.4}, {"corner": True})
def leaves_drift(D, folder, origin, ry, rng, width=None, depth=None, corner=False, wet=None):
    """Dead leaves blown against a wall (the wall on +Z): a low wedge of dark soil and grit, the
    leaves thickest against the wall and thinning out; `corner` piles them toward the -X end too.
    Footprint width 2.5-5 x depth 1.4-2.6 studs. 12-28 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    W = width or rng.uniform(2.6, 4.2)
    Dp = depth or rng.uniform(1.4, 2.2)
    h = rng.uniform(0.18, 0.32)
    wet = (rng.random() < 0.4) if wet is None else wet
    f.part("Grit", (0, h / 2, 0), (W, h, Dp), _tone(SOIL_DARK if wet else SOIL, rng, 5), "Ground",
           shape=WEDGE, flags=DECOR)
    f.part("Grit", (-W * 0.25, h * 0.4, Dp * 0.1), (W * 0.45, h * 0.8, Dp * 0.8), _tone(SOIL, rng, 6, 0.1),
           "Ground", shape=WEDGE, flags=DECOR, rot=(0, rng.uniform(-8, 8), 0))
    n = int(rng.uniform(10, 14) * (W * Dp) / 6) + 6
    n = max(10, min(n, 26))
    for _ in range(n):
        u = rng.random() ** 0.6  # depth fraction, biased toward the wall
        z = -Dp / 2 + u * Dp
        x = rng.uniform(-W / 2, W / 2) * 0.95
        if corner:
            x = -W / 2 + (rng.random() ** 1.6) * W
        top = h * (z + Dp / 2) / Dp
        ly = max(0.0, top - rng.uniform(0, 0.05)) + 0.025
        lw = rng.uniform(0.22, 0.42)
        col = _tone(_pick(rng, LEAF), rng, 10, darken=0.3 if wet else rng.uniform(0, 0.15))
        f.part("Leaf", (x, ly, z), (lw, 0.05, lw * rng.uniform(0.5, 0.75)), col, "Fabric", flags=DECOR,
               rot=(rng.uniform(-25, 25), rng.uniform(0, 180), rng.uniform(-25, 25)))


@prop({}, {"length": 8})
def wall_base_grime(D, folder, origin, ry, rng, length=None):
    """The dirty foot of a wall (the wall on +Z, running along X): a strip of silt and grit against
    it, a damp dark band, moss, grit and gravel, a few leaves and a paper scrap caught in it.
    Footprint length 3-10 x 1.2 studs. 7-21 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    L = length or rng.uniform(4, 8)
    _flat(f, "Damp", 0, -0.15, L, 1.2, 0.05, DAMP, "Concrete", transparency=0.55)
    x = -L / 2
    while x < L / 2 - 0.4:
        seg = min(rng.uniform(1.4, 3.0), L / 2 - x)
        h = rng.uniform(0.14, 0.32)
        f.part("Silt", (x + seg / 2, h / 2, 0.2), (seg, h, rng.uniform(0.55, 0.8)),
               _tone(_pick(rng, [SOIL, SOIL_DARK, DUST]), rng, 6), "Ground", shape=WEDGE, flags=DECOR,
               rot=(0, rng.uniform(-2, 2), 0))
        if rng.random() < 0.55:
            _flat(f, "Moss", x + seg * rng.uniform(0.2, 0.8), 0.38, seg * rng.uniform(0.3, 0.6), 0.22, 0.05 + h,
                  _tone(_pick(rng, MOSS), rng, 6), "Grass")
        x += seg
    # grit and gravel washed against the wall, a scrap of paper caught in the silt
    for _ in range(int(L * rng.uniform(0.4, 0.7))):
        s = rng.uniform(0.1, 0.22)
        f.part("Grit", (rng.uniform(-L / 2, L / 2), s * 0.35, rng.uniform(-0.35, 0.3)), (s, s * 0.7, s * 0.8),
               _tone(_pick(rng, [CONCRETE_OLD, DUST, CINDER]), rng, 8, 0.1), "Concrete", flags=DECOR,
               rot=(rng.uniform(-30, 30), rng.uniform(0, 180), rng.uniform(-30, 30)))
    if rng.random() < 0.6:
        f.part("Paper", (rng.uniform(-L, L) * 0.35, 0.12, 0.2), (0.6, 0.05, 0.45),
               _tone(_pick(rng, PAPER), rng, 8, darken=0.35), "SmoothPlastic", flags=DECOR,
               rot=(rng.uniform(-25, -12), rng.uniform(-30, 30), rng.uniform(-8, 8)))
    for _ in range(int(L * rng.uniform(0.5, 0.9))):
        col = _tone(_pick(rng, LEAF), rng, 10, darken=0.2)
        f.part("Leaf", (rng.uniform(-L / 2, L / 2), 0.1, rng.uniform(-0.1, 0.4)), (0.3, 0.05, 0.2), col, "Fabric",
               flags=DECOR, rot=(rng.uniform(-20, 20), rng.uniform(0, 180), rng.uniform(-20, 20)))


@prop({}, {"radius": 2.4, "density": 1.4})
def litter_scatter(D, folder, origin, ry, rng, radius=None, density=1.0):
    """A natural spread of small litter over an area (more at its +Z side, as if against a wall):
    paper balls, sheets, wrappers, butts, a few leaves. Footprint 2-5 studs across. 11-63 parts (a cluster of litter props), DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    R = radius or rng.uniform(1.6, 2.6)
    n = max(4, int(R * R * 2.0 * density))
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi)
        r = R * math.sqrt(rng.random())
        x, z = math.cos(a) * r, abs(math.sin(a)) * r * rng.choice((1, 1, -1))
        o = _w(f, x, z)
        yaw = _yaw(f) + rng.uniform(0, 360)
        k = rng.random()
        if k < 0.32:
            paper_ball(D, folder, o, yaw, rng)
        elif k < 0.5:
            paper_sheet(D, folder, o, yaw, rng, kind=_pick(rng, ["sheet", "sheet", "flyer"]))
        elif k < 0.68:
            wrapper(D, folder, o, yaw, rng, kind=_pick(rng, ["packet", "packet", "foil", "cup"]))
        elif k < 0.78:
            cigarette_butts(D, folder, o, yaw, rng, count=rng.randint(2, 4), radius=0.4)
        else:
            col = _tone(_pick(rng, LEAF), rng, 10)
            f.part("Leaf", (x, 0.03, z), (0.34, 0.05, 0.22), col, "Fabric", flags=DECOR,
                   rot=(rng.uniform(-10, 10), rng.uniform(0, 180), rng.uniform(-10, 10)))


# =============================================================================================
# Trash bags
# =============================================================================================
@prop({}, {"torn": True}, {"size": 1.7, "color": (36, 38, 42)}, {"size": 2.5})
def trash_bag(D, folder, origin, ry, rng, size=None, torn=False, color=None):
    """A full bin bag slumped on the floor: lumpy (several bulges, stretched creases), knotted at
    the top with its two ears; `torn` splits it at the front, rubbish spilling out over a dark leak.
    Footprint 1.7-2.6 studs (torn: + 1.5 in front), 1.6-2.3 tall. 9-12 parts (torn 13-30);
    the main bulge is PROP, the rest shadows only."""
    f = Frame(D, folder, origin, ry=ry)
    s = size or rng.uniform(1.8, 2.5)
    col = color or _tone(_pick(rng, BAG), rng, 3)
    refl = 0.07
    lobes = []
    d0 = s * rng.uniform(0.8, 0.86)
    lobes.append((0.0, d0 * 0.38, 0.0, d0))
    a = rng.uniform(0, 2 * math.pi)
    d1 = s * rng.uniform(0.6, 0.7)
    lobes.append((math.cos(a) * s * 0.24, d1 * 0.38, math.sin(a) * s * 0.24, d1))
    if rng.random() < 0.7:
        a2 = a + rng.uniform(2.0, 4.2)
        d3 = s * rng.uniform(0.46, 0.56)
        lobes.append((math.cos(a2) * s * 0.28, d3 * 0.36, math.sin(a2) * s * 0.28, d3))
    d2 = s * rng.uniform(0.6, 0.68)
    tx, tz = rng.uniform(-0.1, 0.1) * s, rng.uniform(-0.1, 0.1) * s
    ty = d0 * 0.38 + d0 * 0.2
    lobes.append((tx, ty, tz, d2))
    for i, (x, y, z, d) in enumerate(lobes):
        _ball(f, "TrashBag", (x, y, z), d, _tone(col, rng, 2), "Plastic", flags=PROP if i == 0 else DECOR_SHADOW,
              reflectance=refl)
    # stretched creases: blocks turned askew inside the bulges, their edges break the round shape
    for (x, y, z, d) in (lobes[0], lobes[-1]):
        f.part("BagCrease", (x, y, z), (d * 0.74, d * 0.62, d * 0.7), _tone(col, rng, 3, 0.08), "Plastic",
               rot=(rng.uniform(15, 40), rng.uniform(0, 90), rng.uniform(15, 40)), flags=DECOR, reflectance=refl)
    # the gathered top, the knot and its two limp ears
    top = ty + d2 * 0.42
    g = f.sub((tx, top - 0.08, tz), rx=rng.uniform(-30, 30), rz=rng.uniform(-30, 30), ry=rng.uniform(0, 180))
    g.part("BagNeck", (0, 0.08, 0), (0.36, 0.3, 0.34), col, "Plastic", flags=DECOR, reflectance=refl,
           rot=(rng.uniform(-10, 10), 45, rng.uniform(-10, 10)))
    _ball(g, "BagKnot", (0, 0.3, 0), 0.24, _tone(col, rng, 3, 0.05), "Plastic", reflectance=refl)
    for e in (-1, 1):
        g.part("BagEar", (e * 0.16, 0.3, 0.02), (0.26, 0.05, 0.16), col, "Plastic", flags=DECOR,
               rot=(rng.uniform(-20, 20), rng.uniform(-30, 30), e * rng.uniform(-60, -30)), reflectance=refl)
    if torn:
        # the split, low on the front, and what spills out of it
        x0, y0, z0, d = lobes[0]
        _ball(f, "BagTear", (x0 + rng.uniform(-0.15, 0.15), d * 0.28, z0 - d * 0.36), d * 0.42, BAG_INSIDE,
              "SmoothPlastic")
        f.part("BagFlap", (x0 + 0.25, d * 0.22, z0 - d * 0.5), (0.5, 0.05, 0.4), col, "Plastic", flags=DECOR,
               rot=(rng.uniform(-50, -30), rng.uniform(-30, 30), 0), reflectance=refl)
        _disk(f, "Leak", rng.uniform(-0.2, 0.2), -d * 0.75, rng.uniform(1.1, 1.6), 0.05, (24, 20, 16),
              "SmoothPlastic", transparency=0.35, reflectance=0.1)
        for i in range(rng.randint(3, 5)):
            px, pz = rng.uniform(-0.8, 0.8), -d * 0.55 - rng.uniform(0.1, 1.2)
            o = _w(f, px, pz, 0.05)
            k = i % 4
            if k == 0:
                paper_ball(D, folder, o, rng.uniform(0, 360), rng)
            elif k == 1:
                wrapper(D, folder, o, _yaw(f) + rng.uniform(-60, 60), rng, kind=_pick(rng, ["packet", "takeaway"]))
            elif k == 2:
                _ball(f, "Scraps", (px, 0.14, pz), rng.uniform(0.25, 0.4), _tone(_pick(rng, FOOD), rng, 8), "Sand")
            else:
                paper_sheet(D, folder, o, rng.uniform(0, 360), rng, kind="sheet", wet=True)


@prop({}, {"count": 6})
def trash_heap(D, folder, origin, ry, rng, count=None):
    """A heap of bin bags dumped against a wall (on +Z): bags side by side and slumped on each
    other, one torn open, a flattened box under them, loose litter around. Footprint ~5 x 4 studs.
    44-104 parts (count 3-6 bags)."""
    f = Frame(D, folder, origin, ry=ry)
    n = count or rng.randint(3, 5)
    torn_i = rng.randrange(n) if rng.random() < 0.7 else -1
    cardboard_flat(D, folder, _w(f, rng.uniform(-0.6, 0.6), 0.4), _yaw(f) + rng.uniform(-25, 25), rng)
    placed = []
    for i in range(n):
        s = rng.uniform(1.8, 2.4)
        if i < 3 or not placed:
            x = (i - 1) * 1.75 + rng.uniform(-0.3, 0.3)
            z = 0.6 + rng.uniform(-0.3, 0.3)
            y = 0.06 if abs(x) < 1.5 else 0.0  # (on the flattened box)
        else:  # on top of two others, slumped back toward the wall
            j = rng.randrange(len(placed) - 1) if len(placed) > 1 else 0
            x = (placed[j][0] + placed[j + 1][0]) / 2 if j + 1 < len(placed) else placed[j][0]
            z = 0.9
            y = s * 0.45
            s *= 0.9
        placed.append((x, z))
        trash_bag(D, folder, _w(f, x, z, y), _yaw(f) + rng.uniform(-40, 40), rng, size=s,
                  torn=(i == torn_i and i < 3))
    litter_scatter(D, folder, _w(f, 0, -1.4), _yaw(f), rng, radius=2.0, density=0.6)


# =============================================================================================
# Wood: planks, pallets, lumber
# =============================================================================================
def _plank(f, name, x, y, z, length, w, th, col, yaw=0.0, pitch=0.0, roll=0.0, broken=0, flags=DECOR_SHADOW,
           rng=None):
    """A plank along local X centred on (x, y, z). broken = 0 (clean), -1 / +1: that end is snapped
    (splintered tongues of wood and a pale fresh break)."""
    g = f.sub((x, y, z), ry=yaw, rz=pitch, rx=roll)
    body = length if not broken else length * 0.88
    cx = -broken * length * 0.06
    g.part(name, (cx, 0, 0), (body, th, w), col, "Wood", flags=flags)
    if broken:
        end = cx + broken * body / 2
        n = 2 if w < 0.5 else 3
        lane = w / n
        for i in range(n):
            ext = length * rng.uniform(0.03, 0.14)
            zz = -w / 2 + lane * (i + 0.5)
            g.part("Splinter", (end + broken * ext / 2, rng.uniform(-0.01, 0.01), zz),
                   (ext, th * rng.uniform(0.6, 0.95), lane * rng.uniform(0.6, 0.95)),
                   mix(col, WOOD_FRESH, 0.3 + 0.2 * (i % 2)), "Wood", flags=DECOR,
                   rot=(0, broken * rng.uniform(-6, 6), broken * rng.uniform(-4, 4)))


@prop({"kind": "plank"}, {"kind": "scatter"}, {"kind": "splinters"})
def wood_scraps(D, folder, origin, ry, rng, kind=None):
    """Broken wood on the floor: a snapped plank (one end resting on a scrap, a bent nail), a scatter
    of offcuts (one with old green paint), or a little pile of splinters.
    Footprint 1.5-5 studs. 4-20 parts, DECOR_SHADOW / DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["plank", "scatter", "splinters"])
    if kind == "plank":
        L = rng.uniform(3.0, 5.0)
        w, th = rng.uniform(0.5, 0.7), rng.uniform(0.14, 0.2)
        col = _tone(_pick(rng, [WOOD_OLD, WOOD_GREY, WOOD]), rng, 8)
        lift = rng.uniform(0.2, 0.4)
        pitch = math.degrees(math.asin(lift / L))
        f.box("Offcut", (L / 2 - 0.5, 0, -0.35), (L / 2 + 0.1, lift, 0.35), _tone(WOOD_DARK, rng, 8), "Wood",
              flags=DECOR_SHADOW, rot=(0, rng.uniform(-20, 20), 0))
        _plank(f, "Plank", 0, lift / 2 + th / 2, 0, L, w, th, col, pitch=pitch, broken=-1, rng=rng)
        g = f.sub((L * 0.3, lift * 0.8 + th, 0), rz=pitch)
        _rod(g, "Nail", (0, 0, 0), (0.1, 0.35, 0.05), 0.06, RUST, "CorrodedMetal")
    elif kind == "scatter":
        for i in range(rng.randint(3, 5)):
            L = rng.uniform(1.0, 2.6)
            w, th = rng.uniform(0.35, 0.6), rng.uniform(0.12, 0.2)
            col = _tone(_pick(rng, [WOOD_OLD, WOOD_GREY, WOOD, WOOD_DARK]), rng, 8)
            x, z = rng.uniform(-1.4, 1.4), rng.uniform(-1.0, 1.0)
            roll = rng.uniform(-4, 4)
            _plank(f, "Offcut", x, th / 2 + (0.12 if i == 3 else 0), z, L, w, th, col, yaw=rng.uniform(0, 180),
                   roll=roll, pitch=rng.uniform(-3, 3), broken=rng.choice((-1, 0, 1)), rng=rng)
            if i == 0:
                f.part("Paint", (x, th + 0.02, z), (L * 0.6, 0.05, w * 0.9), (64, 86, 70), "SmoothPlastic",
                       flags=DECOR, rot=(roll, 0, 0), transparency=0.25)
    else:
        for _ in range(rng.randint(5, 9)):
            L = rng.uniform(0.4, 1.2)
            col = mix(_tone(_pick(rng, [WOOD_OLD, WOOD, WOOD_GREY]), rng, 10), WOOD_FRESH, rng.uniform(0, 0.4))
            f.part("Splinter", (rng.uniform(-0.8, 0.8), 0.05, rng.uniform(-0.6, 0.6)),
                   (L, rng.uniform(0.06, 0.1), rng.uniform(0.08, 0.16)), col, "Wood", flags=DECOR,
                   rot=(rng.uniform(-8, 8), rng.uniform(0, 180), rng.uniform(-6, 6)))
        _disk(f, "Sawdust", 0, 0, rng.uniform(1.0, 1.5), 0.05, mix(WOOD_FRESH, DUST, 0.5), "Sand", transparency=0.55)


def _pallet_in(f, rng, L, Wd, state):
    """A pallet in frame f: its deck along X (length L), depth Wd along Z, standing on y = 0."""
    base = _pick(rng, PALLET)
    tone = _tone(base, rng, 10, darken=rng.uniform(0, 0.25))
    bh, sh, th = 0.12, 0.3, 0.12  # bottom boards, stringers, deck boards
    for e in (-1, 0, 1):  # bottom boards (across X, under the stringers)
        f.box("PalletBoard", (-L / 2, 0, e * (Wd / 2 - 0.3) - 0.3), (L / 2, bh, e * (Wd / 2 - 0.3) + 0.3),
              _tone(tone, rng, 8, 0.1), "Wood", flags=SMALL)
    broken_stringer = rng.randrange(3) if state == "broken" else -1
    for i, e in enumerate((-1, 0, 1)):  # stringers / blocks rows
        z = e * (Wd / 2 - 0.3)
        col = _tone(tone, rng, 8, 0.15)
        if i == broken_stringer:
            f.box("PalletBlock", (-L / 2, bh, z - 0.28), (-L * 0.1, bh + sh, z + 0.28), col, "Wood", flags=SMALL)
            f.part("PalletBlock", (L * 0.28, bh + sh / 2 - 0.04, z), (L * 0.42, sh, 0.56), col, "Wood", flags=SMALL,
                   rot=(rng.uniform(-6, 6), rng.uniform(-6, 6), rng.uniform(-5, -2)))
        else:
            f.box("PalletBlock", (-L / 2, bh, z - 0.28), (L / 2, bh + sh, z + 0.28), col, "Wood", flags=SMALL)
    n = 7
    pitch = (L - 0.2) / (n - 1)
    missing = set()
    if state == "broken":
        missing = set(rng.sample(range(1, n - 1), rng.randint(1, 2)))
    elif rng.random() < 0.3:
        missing = {rng.randrange(1, n - 1)}
    snapped = rng.choice([i for i in range(n) if i not in missing]) if state == "broken" else -1
    y = bh + sh + th / 2
    for i in range(n):
        if i in missing:
            continue
        x = -L / 2 + 0.1 + i * pitch
        bw = 0.5 if i % 3 == 0 else 0.42
        col = _tone(tone, rng, 12, darken=rng.uniform(0, 0.2))
        if rng.random() < 0.2:
            col = mix(col, WOOD_GREY, 0.5)
        if i == snapped:
            # snapped in two, one half kicked up
            f.part("PalletBoard", (x, y, -Wd / 4 - 0.05), (bw, th, Wd / 2 - 0.1), col, "Wood", flags=SMALL,
                   rot=(rng.uniform(-3, 3), rng.uniform(-3, 3), 0))
            g = f.sub((x, y + 0.02, 0.05), rx=-rng.uniform(15, 35), ry=rng.uniform(-10, 10))
            g.part("PalletBoard", (0, 0, Wd / 4), (bw, th, Wd / 2 - 0.15), mix(col, WOOD_FRESH, 0.15), "Wood",
                   flags=DECOR_SHADOW)
        else:
            f.part("PalletBoard", (x + rng.uniform(-0.04, 0.04), y + rng.uniform(-0.01, 0.015), 0),
                   (bw, th, Wd + rng.uniform(-0.05, 0.05)), col, "Wood", flags=SMALL,
                   rot=(0, rng.uniform(-1.5, 1.5), 0))
    # a dark stain soaked into the deck
    if rng.random() < 0.6:
        f.part("Stain", (rng.uniform(-L, L) * 0.25, y + th / 2 + 0.01, rng.uniform(-Wd, Wd) * 0.2),
               (rng.uniform(0.8, 1.6), 0.05, rng.uniform(0.6, 1.2)), (34, 28, 22), "Wood", flags=DECOR,
               transparency=0.45, rot=(0, rng.uniform(0, 90), 0))
    # the stamp on a block end
    f.part("Stamp", (-L / 2 - 0.01, bh + sh / 2, 0), (0.05, 0.22, 0.4), (40, 36, 30), "SmoothPlastic", flags=DECOR,
           transparency=0.3)
    return bh + sh + th


@prop({"state": "whole"}, {"state": "broken"}, {"state": "leaning"})
def pallet(D, folder, origin, ry, rng, state=None):
    """A wooden pallet: whole but weathered (mismatched boards, a missing one, a soaked stain, the
    stamp), broken (missing boards, one snapped and kicked up, a cracked stringer), or leaning
    against a wall (on +Z). Footprint 4.2 x 3.0 studs, 0.55 tall (leaning: 4.2 x 1, 3 tall).
    13-17 parts; boards SMALL (you stand on it)."""
    state = state or _pick(rng, ["whole", "whole", "broken", "leaning"])
    L, Wd = rng.uniform(4.0, 4.4), rng.uniform(2.9, 3.2)
    if state == "leaning":
        lean = rng.uniform(12, 22)
        # stood on its long edge, its deck facing out (-Z), the top resting back on the wall
        f = Frame(D, folder, origin, ry=ry)
        g = f.sub((0, 0, 0), rx=-(90 - lean))
        g = g.sub((0, 0, Wd / 2))
        _pallet_in(g, rng, L, Wd, "whole")
    else:
        f = Frame(D, folder, origin, ry=ry, rx=rng.uniform(-1, 1), rz=rng.uniform(-1, 1))
        _pallet_in(f, rng, L, Wd, state)


@prop({}, {"count": 4})
def pallet_stack(D, folder, origin, ry, rng, count=None):
    """A stack of 2-4 pallets, each a little off the one below, the top one maybe broken.
    Footprint 4.6 x 3.4 studs, 0.55 per pallet. 27-61 parts, SMALL (climbable)."""
    f = Frame(D, folder, origin, ry=ry)
    n = count or rng.randint(2, 3)
    y = 0.0
    for i in range(n):
        g = f.sub((rng.uniform(-0.2, 0.2), y, rng.uniform(-0.15, 0.15)), ry=rng.uniform(-6, 6))
        y += _pallet_in(g, rng, rng.uniform(4.0, 4.3), rng.uniform(2.9, 3.1),
                        "broken" if (i == n - 1 and rng.random() < 0.5) else "whole")


@prop({}, {"count": 9})
def plank_stack(D, folder, origin, ry, rng, count=None):
    """Old lumber stacked on two bearers: weathered planks of uneven lengths, the top ones knocked
    askew, one snapped. Footprint 6-7 x 2.6 studs, 0.6-0.9 tall. 9-16 parts, SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    n = count or rng.randint(6, 9)
    for e in (-1, 1):
        f.box("Bearer", (e * 1.8 - 0.25, 0, -1.4), (e * 1.8 + 0.25, 0.3, 1.4), _tone(WOOD_DARK, rng, 8), "Wood",
              flags=SMALL, rot=(0, rng.uniform(-4, 4), 0))
    per_row = 4
    for i in range(n):
        row, k = divmod(i, per_row)
        th = 0.18
        y = 0.3 + row * th + th / 2
        z = -1.05 + k * 0.7 + rng.uniform(-0.05, 0.05)
        L = rng.uniform(5.2, 7.0)
        yaw = rng.uniform(-2, 2) if row == 0 else rng.uniform(-14, 14)
        col = _tone(_pick(rng, [WOOD_OLD, WOOD_GREY, WOOD]), rng, 8, darken=rng.uniform(0, 0.2))
        _plank(f, "Plank", rng.uniform(-0.4, 0.4), y, z, L, 0.62, th, col, yaw=yaw,
               broken=(rng.choice((-1, 1)) if i == n - 1 else 0), flags=SMALL, rng=rng)


# =============================================================================================
# Masonry and concrete: cinder blocks, bricks, chunks, rubble, rebar
# =============================================================================================
def _cinder_in(f, rng, col, half=False):
    """A hollow cinder block in frame f (1.3 x 0.65 x 0.65, two cores), on y = 0."""
    L = 0.7 if half else 1.3
    H, Wd, t = 0.65, 0.65, 0.13
    # the two face shells
    f.box("CinderBlock", (-L / 2, 0, -Wd / 2), (L / 2, H, -Wd / 2 + t), _tone(col, rng, 5), "Concrete", flags=SMALL)
    f.box("CinderBlock", (-L / 2, 0, Wd / 2 - t), (L / 2, H, Wd / 2), _tone(col, rng, 5), "Concrete", flags=SMALL)
    # the webs (ends and middle)
    xs = (-L / 2 + t / 2, L / 2 - t / 2) if half else (-L / 2 + t / 2, 0, L / 2 - t / 2)
    for x in xs:
        f.box("CinderBlock", (x - t / 2, 0, -Wd / 2 + t), (x + t / 2, H * (0.97 if x == 0 else 1), Wd / 2 - t),
              _tone(col, rng, 5, 0.04), "Concrete", flags=SMALL)
    if half:  # the broken end is rough and pale
        f.part("BrokenFace", (L / 2 + 0.02, H * 0.45, 0), (0.06, H * 0.8, Wd * 0.85), mix(col, CONCRETE_FRESH, 0.5),
               "Concrete", flags=DECOR, rot=(rng.uniform(-10, 10), rng.uniform(-12, 12), rng.uniform(-8, 8)))


@prop({"state": "flat"}, {"state": "side"}, {"state": "broken"}, {"state": "stack"})
def cinder_block(D, folder, origin, ry, rng, state=None):
    """A hollow concrete (cinder) block: lying flat (cores up), on its side (cores showing), broken
    in half with a pale break and a chip, or a small stack of 3-5 (one knocked off, one broken).
    Footprint 1.3 x 0.65 studs (stack ~2.8 x 1.5). 5-7 parts (stack 15-35), SMALL."""
    state = state or _pick(rng, ["flat", "side", "broken"])
    f = Frame(D, folder, origin, ry=ry)
    col = _tone(_pick(rng, [CINDER, CONCRETE, CONCRETE_OLD]), rng, 6, darken=rng.uniform(0, 0.15))
    if state == "flat":
        _cinder_in(f.sub((0, 0, 0), rx=rng.uniform(-2, 2), rz=rng.uniform(-2, 2)), rng, col)
        f.part("Grime", (0, 0.07, -0.335), (1.32, 0.14, 0.05), mix(col, SOIL_DARK, 0.6), "Concrete", flags=DECOR,
               transparency=0.3)
    elif state == "side":
        _cinder_in(f.sub((0, 0.325, 0), rx=90).sub((0, -0.325, 0)), rng, col)
    elif state == "broken":
        _cinder_in(f.sub((0, 0, 0), ry=rng.uniform(-10, 10), rz=rng.uniform(-3, 3)), rng, col, half=True)
        f.part("Chip", (rng.uniform(0.7, 1.0), 0.12, rng.uniform(-0.4, 0.4)), (0.3, 0.2, 0.26),
               mix(col, CONCRETE_FRESH, 0.3), "Concrete", flags=DECOR,
               rot=(rng.uniform(-30, 30), rng.uniform(0, 90), rng.uniform(-30, 30)))
    else:
        y = 0.0
        rows = rng.randint(2, 3)
        for r in range(rows):
            m = 2 if r < rows - 1 else rng.randint(1, 2)
            for k in range(m):
                x = (k - (m - 1) / 2) * 1.34 + (0.33 if r % 2 else 0) + rng.uniform(-0.05, 0.05)
                g = f.sub((x, y, rng.uniform(-0.04, 0.04)), ry=rng.uniform(-4, 4))
                _cinder_in(g, rng, _tone(col, rng, 6))
            y += 0.66
        g = f.sub((rng.uniform(-0.6, 0.6), 0, -1.2), ry=rng.uniform(20, 70))
        _cinder_in(g.sub((0, 0.325, 0), rx=90).sub((0, -0.325, 0)), rng, _tone(col, rng, 6))


def _brick(f, rng, x, y, z, half=False, rot=(0, 0, 0), col=None):
    col = col or _tone(_pick(rng, BRICK), rng, 8, darken=rng.uniform(0, 0.15))
    L = 0.36 if half else 0.75
    f.part("Brick", (x, y, z), (L, 0.24, 0.36), col, "Brick", flags=DECOR_SHADOW, rot=rot)


@prop({}, {"count": 6})
def loose_bricks(D, folder, origin, ry, rng, count=None):
    """A few loose bricks: whole and half bricks, some propped on others at an angle, old mortar
    crusted on one, red dust around. Footprint ~2 studs. 4-10 parts, DECOR_SHADOW."""
    f = Frame(D, folder, origin, ry=ry)
    n = count or rng.randint(3, 6)
    pos = []
    for i in range(n):
        if i > 0 and rng.random() < 0.35:
            px, pz = pos[rng.randrange(len(pos))]
            x, z = px + rng.uniform(-0.3, 0.3), pz + rng.uniform(-0.2, 0.2)
            y = 0.24 + rng.uniform(0.05, 0.12)
            rot = (rng.uniform(-20, 20), rng.uniform(0, 180), rng.uniform(-25, 25))
        else:
            x, z = rng.uniform(-1.0, 1.0), rng.uniform(-0.8, 0.8)
            y = 0.12
            rot = (rng.uniform(-3, 3), rng.uniform(0, 180), rng.uniform(-3, 3))
            if rng.random() < 0.25:  # on its edge
                y = 0.18
                rot = (90 + rng.uniform(-4, 4), rot[1], 0)
        pos.append((x, z))
        _brick(f, rng, x, y, z, half=rng.random() < 0.35, rot=rot)
        if i == 0:
            f.part("Mortar", (x, y + 0.13, z), (0.6, 0.05, 0.3), _tone(MORTAR, rng, 6), "Concrete", flags=DECOR,
                   rot=rot)
    _disk(f, "BrickDust", 0, 0, rng.uniform(1.4, 2.0), 0.05, mix(BRICK[0], DUST, 0.5), "Sand", transparency=0.6)


def _chunk(f, rng, x, y, z, s, col, flags=DECOR_SHADOW, rebar=False):
    """An irregular broken lump of concrete: two blocks and a wedge interpenetrating at angles."""
    rot = (rng.uniform(-25, 25), rng.uniform(0, 180), rng.uniform(-25, 25))
    g = f.sub((x, y, z), rx=rot[0], ry=rot[1], rz=rot[2])
    g.part("Chunk", (0, 0, 0), (s, s * rng.uniform(0.45, 0.65), s * rng.uniform(0.6, 0.85)), col, "Concrete",
           flags=flags)
    g.part("Chunk", (s * 0.18, s * 0.08, s * 0.1), (s * 0.7, s * 0.5, s * 0.6), _tone(col, rng, 6, 0.05),
           "Concrete", flags=DECOR, rot=(rng.uniform(15, 40), rng.uniform(20, 50), rng.uniform(-30, 30)))
    g.part("BreakFace", (-s * 0.25, s * 0.15, 0), (s * 0.5, s * 0.35, s * 0.55), mix(col, CONCRETE_FRESH, 0.45),
           "Concrete", shape=WEDGE, flags=DECOR, rot=(0, rng.uniform(-30, 30) + 90, 0))
    if rebar:
        _rod(g, "Rebar", (s * 0.1, 0, 0), (s * 0.5 + rng.uniform(0.3, 0.8), s * rng.uniform(0.1, 0.5), 0.05),
             0.1, RUST, "CorrodedMetal")


@prop({}, {"size": 2.0, "rebar": True})
def concrete_chunk(D, folder, origin, ry, rng, size=None, rebar=None):
    """A broken chunk of concrete slab: irregular faces, a pale fresh break, maybe a rusty rebar
    stub sticking out. Footprint 0.6-2.2 studs. 3-5 parts, DECOR_SHADOW (SMALL from size 1.4)."""
    f = Frame(D, folder, origin, ry=ry)
    s = size or rng.uniform(0.6, 1.8)
    rebar = (s > 1.0 and rng.random() < 0.5) if rebar is None else rebar
    col = _tone(_pick(rng, [CONCRETE, CONCRETE_OLD]), rng, 6, darken=rng.uniform(0, 0.15))
    _chunk(f, rng, 0, s * 0.22, 0, s, col, flags=SMALL if s >= 1.4 else DECOR_SHADOW, rebar=rebar)


@prop({}, {"radius": 3.4})
def rubble_pile(D, folder, origin, ry, rng, radius=None):
    """A pile of demolition rubble: a gritty mound (irregular slopes of dust and broken stuff),
    concrete lumps, bricks, a bent rebar or two sticking out, a broken plank, dust spread around.
    Footprint 2 x radius (4.4-7 studs), 0.8-1.6 tall. 39-53 parts; the mound is PROP (climbable)."""
    f = Frame(D, folder, origin, ry=ry)
    R = radius or rng.uniform(2.2, 3.4)
    h = R * rng.uniform(0.32, 0.45)
    k = 6
    heights = []
    for i in range(k):
        yaw = i * 360 / k + rng.uniform(-12, 12)
        hi = h * rng.uniform(0.8, 1.1)
        ri = R * rng.uniform(0.85, 1.1)
        heights.append(hi)
        g = f.sub((0, 0, 0), ry=yaw)
        g.part("Rubble", (0, hi / 2, -ri / 2), (ri * 1.2, hi, ri),
               _tone(_pick(rng, [DUST, mix(DUST, SOIL, 0.4), CONCRETE_OLD]), rng, 6),
               _pick(rng, ["Pebble", "Ground", "Pebble"]), shape=WEDGE, flags=PROP)
    hmax = max(heights)

    def surf(r):
        return max(0.0, hmax * (1 - r / R))

    # spread dust around the foot
    for i in range(2):
        _disk(f, "Dust", rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), R * (2.3 + i * 0.4), 0.05 + 0.005 * i,
              mix(DUST, CONCRETE_FRESH, 0.2), "Sand", transparency=0.45 + 0.15 * i)
    # concrete lumps (half sunk in the slope)
    for _ in range(rng.randint(7, 10)):
        r = R * rng.uniform(0.05, 1.1)
        a = rng.uniform(0, 2 * math.pi)
        s = rng.uniform(0.35, 1.0) * (1.2 if r < R * 0.5 else 0.9)
        _chunk(f, rng, math.cos(a) * r, surf(r) + s * 0.1, math.sin(a) * r, s,
               _tone(_pick(rng, [CONCRETE, CONCRETE_OLD]), rng, 8), rebar=False)
    # bricks
    for _ in range(rng.randint(4, 7)):
        r = R * rng.uniform(0.1, 1.15)
        a = rng.uniform(0, 2 * math.pi)
        _brick(f, rng, math.cos(a) * r, surf(r) + 0.1, math.sin(a) * r, half=rng.random() < 0.4,
               rot=(rng.uniform(-35, 35), rng.uniform(0, 180), rng.uniform(-35, 35)))
    # rebar sticking out of the top, bent
    for _ in range(rng.randint(1, 2)):
        a = rng.uniform(0, 2 * math.pi)
        r = R * rng.uniform(0.1, 0.35)
        p0 = (math.cos(a) * r, surf(r) - 0.2, math.sin(a) * r)
        p1 = (p0[0] + rng.uniform(-0.4, 0.4), p0[1] + rng.uniform(1.0, 1.8), p0[2] + rng.uniform(-0.4, 0.4))
        p2 = (p1[0] + rng.uniform(-1.0, 1.0), p1[1] + rng.uniform(-0.4, 0.3), p1[2] + rng.uniform(-1.0, 1.0))
        _rod(f, "Rebar", p0, p1, 0.11, _tone(RUST, rng, 8), "CorrodedMetal", extend=0.05)
        _rod(f, "Rebar", p1, p2, 0.11, _tone(RUST, rng, 8), "CorrodedMetal", extend=0.05)
    # a broken plank slid down the side
    a = rng.uniform(0, 2 * math.pi)
    r = R * 0.55
    _plank(f, "Plank", math.cos(a) * r, surf(r) + 0.12, math.sin(a) * r, rng.uniform(2.0, 3.2), 0.55, 0.15,
           _tone(WOOD_OLD, rng, 8), yaw=math.degrees(-a) + rng.uniform(-20, 20), pitch=-rng.uniform(10, 25),
           broken=1, rng=rng)


@prop({}, {"bends": 2})
def rebar(D, folder, origin, ry, rng, bends=None, length=None):
    """A loose bent length of rusty rebar lying on the floor (kinks at random angles, one end
    lifted where it crosses itself). Footprint 2.5-5 studs. 2-4 parts, DECOR_SHADOW."""
    f = Frame(D, folder, origin, ry=ry)
    n = (bends if bends is not None else rng.randint(1, 3)) + 1
    L = length or rng.uniform(3, 5)
    seg = L / n
    p = (-L / 2 * 0.8, 0.06, 0.0)
    a = 0.0
    col = _tone(RUST, rng, 8)
    for i in range(n):
        a += math.radians(rng.uniform(-45, 45)) if i else 0
        q = (p[0] + math.cos(a) * seg, 0.06 + (rng.uniform(0.05, 0.25) if i == n - 1 else 0),
             p[2] + math.sin(a) * seg)
        _rod(f, "Rebar", p, q, 0.1, _tone(col, rng, 6), "CorrodedMetal", flags=DECOR_SHADOW, extend=0.06)
        p = q


# =============================================================================================
# Worn urban objects and construction leftovers
# =============================================================================================
def _ring(f, rng, R_out, t, W, col, n=16, flags=DECOR_SHADOW, wear=0.25):
    """A tyre ring around the frame's Y axis, centred on its origin."""
    rm = R_out - t / 2
    chord = 2 * R_out * math.tan(math.pi / n) + 0.02
    for i in range(n):
        th = 2 * math.pi * i / n
        c = _tone(col, rng, 3)
        if rng.random() < wear:
            c = mix(c, RUBBER_OLD, rng.uniform(0.3, 0.7))
        f.part("Tyre", (math.cos(th) * rm, 0, math.sin(th) * rm), (t, W, chord), c, "Rubber",
               rot=(0, -math.degrees(th), 0), flags=flags if i % 4 == 0 else DECOR_SHADOW)


@prop({"state": "flat"}, {"state": "leaning"}, {"state": "stack"})
def tyre(D, folder, origin, ry, rng, state=None):
    """An old car tyre: lying flat (stagnant water and dirt in it), leaning against a wall (on +Z),
    or a stack of 2-3 slightly off each other. Built as a ring of 16 rubber segments, sun-greyed in
    patches. Footprint 2.3 studs (stack ~2.6). 16-18 parts (stack 33-49); some segments SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["flat", "leaning", "stack"])
    R, t, W = rng.uniform(1.05, 1.2), 0.46, rng.uniform(0.62, 0.75)
    col = _tone(RUBBER, rng, 4)
    if state == "flat":
        g = f.sub((0, W / 2, 0), rx=rng.uniform(-3, 3), rz=rng.uniform(-3, 3))
        _ring(g, rng, R, t, W, col, flags=SMALL)
        _disk(f, "TyreWater", 0, 0, (R - t) * 2 + 0.2, 0.08, (30, 30, 28), "SmoothPlastic", y=0.05,
              transparency=0.2, reflectance=0.25)
        _disk(f, "TyreDirt", 0.15, -0.1, (R - t) * 1.4, 0.1, SOIL_DARK, "Ground", y=0.04)
    elif state == "leaning":
        lean = rng.uniform(12, 22)
        lr = math.radians(lean)
        g = f.sub((0, R * math.cos(lr) + W / 2 * math.sin(lr), R * math.sin(lr)), rx=90 + lean)
        _ring(g, rng, R, t, W, col, flags=SMALL)
    else:
        n = rng.randint(2, 3)
        for i in range(n):
            g = f.sub((rng.uniform(-0.25, 0.25), W / 2 + i * W * 0.98, rng.uniform(-0.25, 0.25)),
                      rx=rng.uniform(-3, 3), rz=rng.uniform(-3, 3))
            _ring(g, rng, R * rng.uniform(0.95, 1.05), t, W, _tone(col, rng, 4), flags=SMALL)
        _disk(f, "TyreDirt", 0, 0, (R - t) * 2, 0.06, SOIL_DARK, "Ground", y=0.0)


@prop({}, {"unrolled": True})
def carpet_roll(D, folder, origin, ry, rng, length=None, unrolled=None):
    """An old rolled-up carpet dumped on the floor: kinked in the middle, tied with two cords, its
    jute backing and core showing at the ends, maybe a flap unrolled showing its faded pattern and
    a stain. Footprint 5-7 x 1.1 studs (+1.2-2 with the flap). 8-12 parts; the roll is PROP."""
    f = Frame(D, folder, origin, ry=ry)
    L = length or rng.uniform(5, 7)
    d = rng.uniform(0.95, 1.2)
    col = _tone(_pick(rng, CARPET), rng, 8, darken=rng.uniform(0.05, 0.3))
    unrolled = (rng.random() < 0.6) if unrolled is None else unrolled
    kink = rng.uniform(3, 7)
    for s in (-1, 1):
        g = f.sub((0, d / 2, 0), ry=-s * kink)
        _cyl(g, "Carpet", (s * L / 4, 0, 0), L / 2 + 0.1, d * (1 if s < 0 else rng.uniform(0.94, 0.98)),
             _tone(col, rng, 5), CARPET_MAT, flags=PROP)
        # the end: backing and the core
        _cyl(g, "CarpetEnd", (s * (L / 2 + 0.03), 0, 0), 0.06, d * 0.94, _tone(JUTE, rng, 8, 0.15), "Fabric")
        _cyl(g, "CarpetCore", (s * (L / 2 + 0.05), 0, 0), 0.06, d * rng.uniform(0.2, 0.3), (24, 22, 20), "Fabric")
        _cyl(g, "Cord", (s * L * 0.3, 0, 0), 0.12, d + 0.04, _tone(_pick(rng, ROPE), rng, 8, 0.2), "Fabric")
    if unrolled:
        fl = rng.uniform(1.2, 2.0)
        g = f.sub((rng.uniform(-0.3, 0.3), 0, -d * 0.35), ry=rng.uniform(-4, 4))
        g.part("CarpetFlap", (0, 0.03, -fl / 2), (L * rng.uniform(0.7, 0.85), 0.06, fl), mix(col, (0, 0, 0), 0.1),
               CARPET_MAT, flags=DECOR)
        g.part("CarpetBorder", (0, 0.05, -fl + 0.2), (L * 0.7, 0.05, 0.16), mix(col, JUTE, 0.5), CARPET_MAT,
               flags=DECOR)
        _disk(g, "Stain", rng.uniform(-L, L) * 0.2, -fl * 0.5, rng.uniform(0.6, 1.0), 0.05, (30, 22, 18), "Fabric",
              y=0.04, transparency=0.4)


@prop({"kind": "corrugated"}, {"kind": "plate"})
def scrap_sheet(D, folder, origin, ry, rng, kind=None):
    """Scrap metal sheet: a corrugated roofing sheet (real zigzag ribs, galvanised turning to rust
    across it, one end propped on a lump of debris) or a bent steel plate with bolt holes and
    rust. Footprint 2.6-3.2 x 4-6 studs. 4-16 parts; DECOR_SHADOW, ribs SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["corrugated", "corrugated", "plate"])
    if kind == "corrugated":
        n = rng.randint(9, 12)
        pitch = 0.28
        W = n * pitch
        L = rng.uniform(4, 6)
        tilt = 26
        amp = pitch * math.tan(math.radians(tilt))
        lift = rng.uniform(0.25, 0.6)
        f.part("Debris", (0, lift / 2, L / 2 - 0.5), (1.2, lift, 0.8), _tone(CONCRETE_OLD, rng, 6), "Concrete",
               flags=DECOR_SHADOW, rot=(rng.uniform(-8, 8), rng.uniform(-30, 30), 0))
        g = f.sub((0, amp / 2 + 0.03, -L / 2), rx=-math.degrees(math.asin(lift / L)), rz=rng.uniform(-3, 3))
        g = g.sub((0, 0, L / 2))
        rust_side = rng.choice((-1, 1))
        short = rng.randrange(n)
        for i in range(n):
            x = -W / 2 + pitch * (i + 0.5)
            t = (i / (n - 1)) if rust_side > 0 else 1 - i / (n - 1)
            c = mix(_tone(GALVANISED, rng, 6), _tone(RUST, rng, 8), min(1.0, t * rng.uniform(0.7, 1.4)))
            ln = L if i != short else L * rng.uniform(0.6, 0.8)
            g.part("Corrugated", (x, 0, (L - ln) / 2), (pitch / math.cos(math.radians(tilt)) + 0.01, 0.05, ln), c,
                   "CorrodedMetal" if t > 0.4 else "Metal", flags=SMALL if i % 3 == 0 else DECOR_SHADOW,
                   rot=(0, 0, tilt if i % 2 else -tilt))
    else:
        W, L = rng.uniform(2.4, 3.2), rng.uniform(3.2, 4.4)
        col = _tone(_pick(rng, [RUST, IRON, RUST_DARK]), rng, 8)
        bend = rng.uniform(8, 20)
        f.part("Plate", (0, 0.04, -L / 4), (W, 0.08, L / 2), col, "CorrodedMetal", flags=DECOR_SHADOW,
               rot=(rng.uniform(-1, 1), 0, 0))
        g = f.sub((0, 0.06, 0), rx=-bend)
        g.part("Plate", (0, 0, L / 4), (W, 0.08, L / 2), _tone(col, rng, 6), "CorrodedMetal", flags=DECOR_SHADOW)
        for i in range(rng.randint(2, 3)):
            _disk(f, "BoltHole", -W / 2 + 0.3 + i * (W - 0.6) / 2, -L / 2 + 0.3, 0.14, 0.05, TAR, "SmoothPlastic",
                  y=0.06)
        _disk(f, "Rust", rng.uniform(-0.5, 0.5), rng.uniform(-1, 0), rng.uniform(1.6, 2.4), 0.05, RUST_DARK,
              "CorrodedMetal", transparency=0.55)


@prop({}, {"color": (52, 62, 44)})
def tarp_scrap(D, folder, origin, ry, rng, size=None, color=None):
    """A dirty crumpled tarp on the floor: an irregular sheet with folds raised in ridges, grommets
    along an edge, muddy patches. Footprint 2.5-4 studs. 6-14 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    S = size or rng.uniform(2.6, 3.8)
    col = color or _tone(_pick(rng, TARP), rng, 6)
    col = _tone(col, rng, 4, darken=rng.uniform(0.05, 0.3))
    _flat(f, "Tarp", 0, 0, S, S * 0.75, 0.05, col, "Plastic", yaw=rng.uniform(-10, 10))
    _flat(f, "Tarp", S * 0.25, S * 0.2, S * 0.6, S * 0.55, 0.06, _tone(col, rng, 5), "Plastic",
          yaw=rng.uniform(20, 50))
    for _ in range(rng.randint(2, 3)):  # folds: two strips leaning on each other
        x, z = rng.uniform(-S, S) * 0.25, rng.uniform(-S, S) * 0.2
        yaw = rng.uniform(0, 180)
        ln = rng.uniform(1.0, S * 0.8)
        hgt = rng.uniform(0.1, 0.22)
        wd = rng.uniform(0.3, 0.5)
        g = f.sub((x, 0, z), ry=yaw)
        ang = math.degrees(math.atan2(hgt, wd / 2))
        for e in (-1, 1):
            g.part("TarpFold", (0, hgt / 2, e * wd / 4), (ln, 0.05, math.hypot(wd / 2, hgt)), _tone(col, rng, 6),
                   "Plastic", flags=DECOR, rot=(e * ang, 0, 0))
    for i in range(rng.randint(2, 3)):
        _disk(f, "Grommet", -S / 2 + 0.25 + i * 0.9, -S * 0.375 + 0.15, 0.16, 0.06, (120, 120, 116), "Metal", y=0.03)
    _disk(f, "Mud", rng.uniform(-S, S) * 0.2, rng.uniform(-S, S) * 0.15, rng.uniform(0.8, 1.4), 0.05, SOIL, "Ground",
          y=0.05, transparency=0.4)


@prop({}, {"loops": 3})
def rope_coil(D, folder, origin, ry, rng, loops=None):
    """A coil of old rope dropped on the floor: 2-3 sagging loops, one end trailing off with a
    frayed tip. Footprint ~1.6 x 2.5 studs. 13-31 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    col = _tone(_pick(rng, ROPE), rng, 8, darken=rng.uniform(0.05, 0.3))
    d = rng.uniform(0.12, 0.15)
    n = 9
    for k in range(loops or rng.randint(2, 2)):
        r = rng.uniform(0.55, 0.72)
        cx, cz = rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12)
        ph = rng.uniform(0, 2 * math.pi)
        pts = []
        for i in range(n + 1):
            a = ph + 2 * math.pi * i / n
            rr = r * rng.uniform(0.92, 1.06)
            pts.append((cx + math.cos(a) * rr, d / 2 + k * d * 0.7 + rng.uniform(0, 0.03), cz + math.sin(a) * rr * 0.9))
        pts[-1] = pts[0]
        for i in range(n):
            _rod(f, "Rope", pts[i], pts[i + 1], d, _tone(col, rng, 4), "Fabric", extend=d * 0.6)
    p = (0.7, d / 2, 0.0)
    a = rng.uniform(-0.5, 0.5)
    for _ in range(3):
        a += rng.uniform(-0.7, 0.7)
        q = (p[0] + math.cos(a) * 0.5, d / 2, p[2] + math.sin(a) * 0.5)
        _rod(f, "Rope", p, q, d, _tone(col, rng, 4), "Fabric", extend=d * 0.6)
        p = q
    _ball(f, "Fray", p, d * 1.6, mix(col, (200, 190, 160), 0.3), "Fabric")


@prop({}, {"torn": True})
def cement_bag(D, folder, origin, ry, rng, torn=None):
    """A paper sack of cement, set hard and lumpy: rounded pillow shape, crimped ends, a faded red
    print band; torn, it spills grey powder and hardened lumps. Footprint 1.9 x 1.2 studs, 0.5 tall
    (torn: + 1.2). 6-12 parts; the body is PROP."""
    f = Frame(D, folder, origin, ry=ry, rz=rng.uniform(-2, 2))
    torn = (rng.random() < 0.5) if torn is None else torn
    L, Wd, h = rng.uniform(1.8, 2.0), rng.uniform(1.1, 1.25), rng.uniform(0.42, 0.52)
    col = _tone((150, 136, 108), rng, 8, darken=rng.uniform(0.05, 0.3))
    f.part("CementBag", (0, h / 2, 0), (L * 0.92, h * 0.96, Wd - h), col, "Fabric", flags=PROP)
    for e in (-1, 1):
        _cyl(f, "CementBag", (0, h / 2, e * (Wd / 2 - h / 2)), L * 0.9, h, _tone(col, rng, 4), "Fabric")
        f.part("BagSeam", (e * L * 0.47, h * 0.35, 0), (0.12, h * 0.6, Wd * 0.95), _tone(col, rng, 6, 0.08),
               "Fabric", flags=DECOR, rot=(0, 0, e * rng.uniform(4, 12)))
    f.part("Print", (L * 0.15, h + 0.01, 0), (L * 0.22, 0.05, Wd - h), (122, 56, 44), "Fabric", flags=DECOR,
           transparency=0.3)
    if torn:
        f.part("Tear", (-L * 0.32, h * 0.65, -Wd * 0.3), (0.5, 0.2, 0.35), (60, 56, 50), "Fabric", flags=DECOR,
               rot=(rng.uniform(-20, 20), rng.uniform(0, 60), rng.uniform(-20, 20)))
        powder = _tone((166, 162, 152), rng, 6)
        _disk(f, "Powder", -L * 0.35, -Wd * 0.8, rng.uniform(1.2, 1.8), 0.06, powder, "Sand")
        _disk(f, "Powder", -L * 0.5, -Wd * 1.1, rng.uniform(0.8, 1.2), 0.08, _tone(powder, rng, 4), "Sand",
              transparency=0.3)
        for _ in range(2):
            f.part("Lump", (rng.uniform(-1.2, 0.2), 0.1, -Wd * rng.uniform(0.7, 1.3)), (0.3, 0.2, 0.25),
                   _tone(powder, rng, 6, 0.1), "Concrete", flags=DECOR,
                   rot=(rng.uniform(-20, 20), rng.uniform(0, 90), rng.uniform(-20, 20)))


@prop({"kind": "pvc"}, {"kind": "steel"})
def pipe_piece(D, folder, origin, ry, rng, kind=None, length=None):
    """An offcut of pipe lying on the floor: orange sewer PVC (dirty, a dark bore) or rusty steel
    with a threaded collar. Footprint 2-4 x 0.3-0.5 studs. 3-4 parts, DECOR_SHADOW."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["pvc", "steel"])
    L = length or rng.uniform(2.0, 4.0)
    if kind == "pvc":
        d = rng.uniform(0.42, 0.5)
        col = _tone((150, 84, 48), rng, 8, darken=rng.uniform(0, 0.25))
        _cyl(f, "Pipe", (0, d / 2, 0), L, d, col, "Plastic", rot=(0, 0, rng.uniform(-1, 1)), flags=DECOR_SHADOW)
        _cyl(f, "PipeDirt", (-L * 0.2, d / 2 - 0.005, 0), L * 0.45, d + 0.01, mix(col, SOIL, 0.5), "Plastic",
             transparency=0.4)
    else:
        d = rng.uniform(0.28, 0.34)
        col = _tone(RUST, rng, 8)
        _cyl(f, "Pipe", (0, d / 2, 0), L, d, col, "CorrodedMetal", flags=DECOR_SHADOW)
        _cyl(f, "Collar", (L / 2 - 0.15, d / 2 + 0.01, 0), 0.3, d + 0.1, _tone(RUST_DARK, rng, 6), "CorrodedMetal")
    for e in (-1, 1):
        if kind == "steel" and e > 0:
            continue
        _cyl(f, "Bore", (e * (L / 2 + 0.005), d / 2, 0), 0.05, d * 0.78, TAR, "SmoothPlastic")


@prop({"state": "standing"}, {"state": "fallen"})
def traffic_cone(D, folder, origin, ry, rng, state=None):
    """A battered traffic cone: square rubber base, a stepped orange cone faded and black with grime
    toward the bottom, two dirty reflective bands; standing or knocked over. Footprint 1 x 1 studs
    (fallen 1 x 2.4), 2.3 tall. 8 parts, SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["standing", "fallen"])
    if state == "fallen":
        f = f.sub((0, 0.48, 0), rz=-74, rx=rng.uniform(-5, 5))
        f = f.sub((0, -0.45, 0))
    col = _tone(CONE, rng, 8, darken=rng.uniform(0.05, 0.3))
    f.box("ConeBase", (-0.48, 0, -0.48), (0.48, 0.14, 0.48), _tone(RUBBER, rng, 4), "Rubber", flags=SMALL)
    ds = [0.74, 0.62, 0.5, 0.38, 0.27]
    for i, d in enumerate(ds):
        c = mix(col, (30, 26, 22), 0.45 * (1 - i / 4) * rng.uniform(0.6, 1.0))
        _cyl(f, "Cone", (0, 0.14 + 0.2 + i * 0.4, 0), 0.42, d, c, "Plastic", rot=(0, 0, 90),
             flags=SMALL if i == 0 else DECOR_SHADOW)
    for y, d in ((1.32, 0.55), (0.9, 0.67)):
        _cyl(f, "ConeBand", (0, y, 0), 0.14, d, _tone((176, 176, 168), rng, 8, darken=rng.uniform(0.15, 0.4)),
             "SmoothPlastic", rot=(0, 0, 90))


@prop({"state": "upright"}, {"state": "upside"}, {"state": "broken"})
def milk_crate(D, folder, origin, ry, rng, state=None):
    """A plastic milk crate, faded and scuffed: open-sided frame (posts, rims, rails), upright,
    upside down (a seat), or broken (rails and slats gone, a rim cracked off). Footprint 1.2 x 1.2
    studs, 1 tall. 14-22 parts; frame SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["upright", "upside", "broken"])
    col = _tone(_pick(rng, CRATE), rng, 8, darken=rng.uniform(0.1, 0.35))
    S, H, b = 1.2, 1.0, 0.1
    if state == "upside":
        f = f.sub((0, H, 0), rx=180)
    for sx in (-1, 1):  # corner posts
        for sz in (-1, 1):
            f.box("Crate", (sx * S / 2 - (b if sx > 0 else 0), 0, sz * S / 2 - (b if sz > 0 else 0)),
                  (sx * S / 2 + (0 if sx > 0 else b), H, sz * S / 2 + (0 if sz > 0 else b)), col, "Plastic",
                  flags=SMALL)
    f.box("CrateFloor", (-S / 2 + b, 0.02, -S / 2 + b), (S / 2 - b, 0.1, S / 2 - b), _tone(col, rng, 5, 0.15),
          "Plastic", flags=SMALL)
    broken = set(rng.sample(range(8), 3)) if state == "broken" else set()
    k = 0
    for y, hh in ((H - 0.12, 0.12), (H * 0.5, 0.08)):  # top rim and a middle rail on each side
        for side in range(4):
            if k in broken:
                k += 1
                continue
            c = _tone(col, rng, 4)
            if side < 2:
                z = (-1 if side == 0 else 1) * (S / 2 - b / 2)
                f.box("Crate", (-S / 2 + b, y, z - b / 2), (S / 2 - b, y + hh, z + b / 2), c, "Plastic", flags=SMALL)
            else:
                x = (-1 if side == 2 else 1) * (S / 2 - b / 2)
                f.box("Crate", (x - b / 2, y, -S / 2 + b), (x + b / 2, y + hh, S / 2 - b), c, "Plastic", flags=SMALL)
            k += 1
    # the lattice of the walls: two vertical slats a side (with the rails they make the grid of
    # holes a crate reads by); a broken crate has lost some
    for side in range(4):
        for u in (-1, 1):
            if state == "broken" and rng.random() < 0.3:
                continue
            c = _tone(col, rng, 4, 0.03)
            p = u * S / 6
            if side < 2:
                z = (-1 if side == 0 else 1) * (S / 2 - b * 0.4)
                f.box("Crate", (p - 0.05, 0.1, z - 0.04), (p + 0.05, H - 0.12, z + 0.04), c, "Plastic", flags=DECOR)
            else:
                x = (-1 if side == 2 else 1) * (S / 2 - b * 0.4)
                f.box("Crate", (x - 0.04, 0.1, p - 0.05), (x + 0.04, H - 0.12, p + 0.05), c, "Plastic", flags=DECOR)
    if state == "broken":
        f.part("CrateBit", (rng.uniform(0.9, 1.4), 0.06, rng.uniform(-0.6, 0.6)), (S * 0.7, 0.12, b), col,
               "Plastic", flags=DECOR, rot=(0, rng.uniform(0, 180), rng.uniform(-5, 5)))
    # scuffs: grey-white scratches on the rim
    f.part("Scuff", (S / 2 + 0.01, H - 0.06, rng.uniform(-0.3, 0.3)), (0.05, 0.1, 0.5), mix(col, (180, 180, 176), 0.5),
           "SmoothPlastic", flags=DECOR)


@prop({"state": "standing"}, {"state": "tipped"})
def bucket(D, folder, origin, ry, rng, state=None):
    """An old paint bucket: tapered, rolled rim, wire handle, crusted paint inside and dried drips down
    its side; standing or tipped over with a dried, trodden spill. Footprint 1 studs (tipped 1 x 2),
    1.1 tall. 8-11 parts, SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["standing", "tipped"])
    paint = _tone(_pick(rng, [PAINT["white"], (150, 150, 140), PAINT["blue"], (120, 110, 90)]), rng, 8, 0.1)
    if state == "tipped":
        # a dried spill, dirtied and trodden: two overlapping blots and a smear
        dried = mix(paint, DUST, rng.uniform(0.3, 0.5))
        _disk(f, "Spill", -0.15, -1.0, rng.uniform(1.0, 1.3), 0.05, dried, "SmoothPlastic", transparency=0.15)
        _disk(f, "Spill", rng.uniform(-0.6, 0.2), -1.5, rng.uniform(0.5, 0.8), 0.055, _tone(dried, rng, 6, 0.08),
              "SmoothPlastic", transparency=0.25)
        _flat(f, "Spill", rng.uniform(0.2, 0.5), -1.7, 0.3, 0.9, 0.05, mix(dried, SOIL_DARK, 0.4), "SmoothPlastic",
              yaw=rng.uniform(-40, 40), transparency=0.35)
        f = f.sub((0, 0.46, 0), rx=-90 + rng.uniform(-4, 4)).sub((0, -0.5, 0))
    col = _tone(_pick(rng, [(176, 172, 160), (60, 62, 66), (140, 40, 34)]), rng, 8, darken=rng.uniform(0.1, 0.3))
    _cyl(f, "Bucket", (0, 0.25, 0), 0.5, 0.84, col, "Plastic", rot=(0, 0, 90), flags=SMALL)
    _cyl(f, "Bucket", (0, 0.72, 0), 0.46, 0.92, _tone(col, rng, 4), "Plastic", rot=(0, 0, 90), flags=SMALL)
    _cyl(f, "Rim", (0, 0.97, 0), 0.06, 0.98, _tone(col, rng, 4, 0.1), "Plastic", rot=(0, 0, 90))
    _cyl(f, "Crust", (0, 0.975, 0), 0.06, 0.82, mix(paint, (40, 40, 40), 0.3), "SmoothPlastic", rot=(0, 0, 90))
    for e in (-1, 1):
        _rod(f, "Handle", (e * 0.47, 0.9, 0), (e * 0.3, 1.2, -0.1), 0.04, IRON, "Metal")
    _rod(f, "Handle", (-0.3, 1.2, -0.1), (0.3, 1.2, -0.1), 0.04, IRON, "Metal")
    f.part("Drip", (0.1, 0.75, -0.465), (0.14, 0.45, 0.05), paint, "SmoothPlastic", flags=DECOR,
           rot=(4, 0, rng.uniform(-3, 3)))


# =============================================================================================
# Floor wear: stains, cracks, potholes, patches, covers, grates, weeds, puddles, marks
# =============================================================================================
@prop({}, {"size": 1.6})
def oil_stain(D, folder, origin, ry, rng, size=None):
    """A black oil stain soaked into the ground, glossy at its heart, with a few drips beside it.
    Footprint 1.5-4 studs. 3-7 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    s = size or rng.uniform(1.0, 1.6)
    for i in range(rng.randint(2, 3)):
        _disk(f, "OilStain", rng.uniform(-0.4, 0.4) * s, rng.uniform(-0.3, 0.3) * s, s * rng.uniform(1.0, 1.8),
              0.05 + 0.004 * i, _tone(OIL, rng, 3), "SmoothPlastic", transparency=0.45 + 0.12 * i,
              reflectance=0.12)
    _disk(f, "OilStain", rng.uniform(-0.15, 0.15) * s, 0, s * 0.6, 0.064, OIL, "SmoothPlastic", transparency=0.3,
          reflectance=0.25)
    for _ in range(rng.randint(0, 3)):
        a = rng.uniform(0, 2 * math.pi)
        r = s * rng.uniform(1.0, 1.5)
        _disk(f, "OilDrip", math.cos(a) * r, math.sin(a) * r, rng.uniform(0.12, 0.3), 0.05, OIL, "SmoothPlastic",
              transparency=0.25, reflectance=0.12)


@prop({}, {"size": 3.0, "run": True})
def damp_stain(D, folder, origin, ry, rng, size=None, run=None):
    """A damp patch: dark wet ground in soft overlapping blotches, sometimes running off in a long
    wet streak (toward -Z, to a drain). Footprint 2-6 studs. 3-7 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    s = size or rng.uniform(1.8, 3.0)
    run = (rng.random() < 0.5) if run is None else run
    for i in range(rng.randint(2, 4)):
        _disk(f, "Damp", rng.uniform(-0.35, 0.35) * s, rng.uniform(-0.25, 0.25) * s, s * rng.uniform(0.6, 1.1),
              0.05 + 0.004 * i, _tone(DAMP, rng, 4), "Concrete", transparency=0.45 + 0.08 * i)
    if run:
        ln = s * rng.uniform(1.2, 2.0)
        g = f.sub((0, 0, -ln / 2), ry=rng.uniform(-12, 12))
        g.part("Damp", (0, 0.03, 0), (s * 0.25, 0.06, ln), DAMP, "Concrete", flags=DECOR, transparency=0.5)
        g.part("Damp", (rng.uniform(-0.1, 0.1), 0.035, -ln * 0.1), (s * 0.12, 0.07, ln * 0.8), DAMP, "Concrete",
               flags=DECOR, transparency=0.4, rot=(0, rng.uniform(-6, 6), 0))


@prop({}, {"length": 7})
def crack(D, folder, origin, ry, rng, length=None, branches=None):
    """A crack in the ground: a jagged dark line wandering along -Z..+Z, thinning out, with 1-2
    side branches and a soft dark edge. Footprint length 3-8 studs. 5-14 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    L = length or rng.uniform(3, 6)
    n = max(3, int(L / 0.8))
    pts = [(0.0, -L / 2)]
    for i in range(n):
        x, z = pts[-1]
        pts.append((x + rng.uniform(-0.35, 0.35), z + L / n * rng.uniform(0.8, 1.2)))

    def line(points, w0, w1):
        m = len(points) - 1
        for i in range(m):
            (x0, z0), (x1, z1) = points[i], points[i + 1]
            w = w0 + (w1 - w0) * i / max(1, m - 1)
            _bar(f, "Crack", (x0, 0.026, z0), (x1, 0.026, z1), w, 0.05, TAR, "SmoothPlastic", extend=w * 0.8)

    line(pts, rng.uniform(0.1, 0.14), 0.05)
    _bar(f, "CrackEdge", (pts[0][0], 0.024, pts[0][1]), (pts[-1][0], 0.024, pts[-1][1]), 0.35, 0.05, DAMP,
         "SmoothPlastic", transparency=0.75)
    for _ in range(branches if branches is not None else rng.randint(1, 2)):
        j = rng.randrange(1, len(pts) - 1)
        x, z = pts[j]
        side = rng.choice((-1, 1))
        bp = [(x, z)]
        for _k in range(rng.randint(1, 3)):
            x, z = x + side * rng.uniform(0.4, 0.8), z + rng.uniform(-0.2, 0.5)
            bp.append((x, z))
        line(bp, 0.07, 0.05)


@prop({}, {"radius": 1.8})
def pothole(D, folder, origin, ry, rng, radius=None):
    """A pothole: a ragged rim of broken asphalt lumps raised around a dark muddy hollow holding
    dirty water, loose gravel kicked out of it. Footprint 2-4 studs. 11-18 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    R = radius or rng.uniform(1.0, 1.7)
    _disk(f, "PotholeEdge", 0, 0, R * 2.5, 0.05, DAMP, "Asphalt", transparency=0.6)
    _disk(f, "PotholeMud", 0, 0, R * 2.0, 0.07, _tone(SOIL_DARK, rng, 4), "Ground")
    _disk(f, "PotholeWater", rng.uniform(-0.1, 0.1) * R, rng.uniform(-0.1, 0.1) * R, R * rng.uniform(1.3, 1.7), 0.09,
          WATER, "SmoothPlastic", transparency=0.25, reflectance=0.3)
    k = rng.randint(6, 9)
    for i in range(k):
        a = 2 * math.pi * i / k + rng.uniform(-0.2, 0.2)
        r = R * rng.uniform(0.95, 1.1)
        w = 2 * math.pi * R / k * rng.uniform(0.8, 1.2)
        f.part("PotholeRim", (math.cos(a) * r, 0.05, math.sin(a) * r), (rng.uniform(0.35, 0.55), 0.14, w),
               _tone(ASPHALT_WORN, rng, 6), "Asphalt", flags=DECOR,
               rot=(0, -math.degrees(a), rng.uniform(8, 22)))
    for _ in range(rng.randint(2, 4)):
        a = rng.uniform(0, 2 * math.pi)
        r = R * rng.uniform(1.2, 1.8)
        f.part("Gravel", (math.cos(a) * r, 0.05, math.sin(a) * r), (0.2, 0.12, 0.16), _tone(ASPHALT_WORN, rng, 10),
               "Asphalt", flags=DECOR, rot=(rng.uniform(-20, 20), rng.uniform(0, 90), rng.uniform(-20, 20)))


@prop({}, {"w": 5, "d": 3})
def asphalt_patch(D, folder, origin, ry, rng, w=None, d=None):
    """A patched repair: a slightly raised rectangle of newer, blacker asphalt, glossy tar seams
    around it, a crack already running across, crumbs at a chewed corner.
    Footprint 2.5-6 x 2-4 studs. 7-11 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    W = w or rng.uniform(2.5, 5.0)
    L = d or rng.uniform(2.0, 3.5)
    _flat(f, "Patch", 0, 0, W, L, 0.07, _tone(ASPHALT_NEW, rng, 3), "Asphalt", yaw=rng.uniform(-2, 2))
    for (x, z, sw, sd) in ((0, -L / 2, W + 0.1, 0.14), (0, L / 2, W + 0.1, 0.14), (-W / 2, 0, 0.14, L + 0.1),
                           (W / 2, 0, 0.14, L + 0.1)):
        _flat(f, "Seam", x + rng.uniform(-0.03, 0.03), z + rng.uniform(-0.03, 0.03), sw, sd, 0.08, TAR, "SmoothPlastic",
              reflectance=0.15, yaw=rng.uniform(-1, 1))
    p0 = (-W / 2 + 0.2, 0.06, rng.uniform(-L, L) * 0.3)
    mid = (rng.uniform(-0.3, 0.3), 0.06, rng.uniform(-L, L) * 0.2)
    p1 = (W / 2 - 0.2, 0.06, rng.uniform(-L, L) * 0.3)
    _bar(f, "Crack", p0, mid, 0.08, 0.05, TAR, "SmoothPlastic", extend=0.05)
    _bar(f, "Crack", mid, p1, 0.06, 0.05, TAR, "SmoothPlastic", extend=0.05)
    for _ in range(rng.randint(1, 3)):
        f.part("Gravel", (W / 2 + rng.uniform(0, 0.4), 0.05, L / 2 + rng.uniform(-0.6, 0.2)), (0.18, 0.1, 0.14),
               _tone(ASPHALT_WORN, rng, 8), "Asphalt", flags=DECOR, rot=(0, rng.uniform(0, 90), 0))


@prop({}, {"square": True})
def manhole(D, folder, origin, ry, rng, diameter=None, square=None):
    """A cast-iron manhole cover set in its frame: a worn concrete collar (square or round), the
    dark gap around the lid, raised cross-hatch bars, two pick holes, rust bleeding into the ground.
    Footprint 2.4-3.4 studs. 14-17 parts, DECOR (flush with the floor)."""
    f = Frame(D, folder, origin, ry=ry)
    dm = diameter or rng.uniform(2.1, 2.4)
    square = (rng.random() < 0.5) if square is None else square
    _disk(f, "RustBleed", rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), dm * 1.5, 0.05, RUST_DARK, "Concrete",
          transparency=0.6)
    if square:
        c = _tone(CONCRETE_OLD, rng, 6, darken=0.1)
        S = dm + 0.7
        for (x, z, sw, sd) in ((0, -S / 2 + 0.2, S, 0.4), (0, S / 2 - 0.2, S, 0.4), (-S / 2 + 0.2, 0, 0.4, S - 0.8),
                               (S / 2 - 0.2, 0, 0.4, S - 0.8)):
            _flat(f, "ManholeFrame", x, z, sw, sd, 0.07, _tone(c, rng, 5), "Concrete")
    else:
        _disk(f, "ManholeFrame", 0, 0, dm + 0.6, 0.06, _tone(CONCRETE_OLD, rng, 6), "Concrete")
    _disk(f, "ManholeGap", 0, 0, dm + 0.12, 0.075, TAR, "SmoothPlastic")
    lid = _tone(IRON, rng, 4)
    _disk(f, "ManholeCover", 0, 0, dm, 0.085, lid, "DiamondPlate", reflectance=0.05)
    _disk(f, "ManholeRing", 0, 0, dm * 0.62, 0.1, mix(lid, RUST, 0.25), "Metal")
    for i in range(3):
        for rot in (45, -45):
            off = (i - 1) * dm * 0.22
            half = math.sqrt(max(0.01, (dm * 0.46) ** 2 - off ** 2))
            g = f.sub((0, 0, 0), ry=rot)
            _bar(g, "ManholeBar", (-half, 0.1, off), (half, 0.1, off), 0.08, 0.05, mix(lid, (80, 78, 74), 0.4),
                 "Metal")
    for e in (-1, 1):
        _disk(f, "PickHole", e * dm * 0.36, 0, 0.14, 0.11, TAR, "SmoothPlastic")


@prop({"kind": "gully"}, {"kind": "channel"})
def drain_grate(D, folder, origin, ry, rng, kind=None):
    """A drain: a gully grate (square iron frame, bars over a black void, wet and rusty around) or a
    long channel drain along X; leaves and a scrap of paper caught on the bars, a damp halo.
    Footprint gully 1.8 x 1.4, channel 5-7 x 0.9 studs. 11-20 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["gully", "channel"])
    if kind == "gully":
        W, L, nb = 1.8, 1.4, 7
    else:
        W, L, nb = rng.uniform(5, 7), 0.9, 0
    _flat(f, "DrainDamp", 0, 0, W + 1.2, L + 1.2, 0.05, DAMP, "Concrete", transparency=0.55)
    _flat(f, "DrainVoid", 0, 0, W - 0.1, L - 0.1, 0.06, (6, 6, 6), "SmoothPlastic")
    iron = _tone(IRON, rng, 5)
    fr = 0.12
    for (x, z, sw, sd) in ((0, -L / 2, W, fr), (0, L / 2, W, fr), (-W / 2, 0, fr, L), (W / 2, 0, fr, L)):
        _flat(f, "DrainFrame", x, z, sw, sd, 0.1, mix(iron, RUST, rng.uniform(0.1, 0.5)), "CorrodedMetal")
    if kind == "gully":
        for i in range(nb):
            x = -W / 2 + fr + (W - 2 * fr) * (i + 0.5) / nb
            _flat(f, "DrainBar", x, 0, 0.09, L - fr, 0.1, mix(iron, RUST, rng.uniform(0, 0.4)), "CorrodedMetal")
    else:
        n = int(W / 0.5)
        for i in range(n):
            x = -W / 2 + fr + (W - 2 * fr) * (i + 0.5) / n
            _flat(f, "DrainBar", x, 0, 0.12, L - fr, 0.1, mix(iron, RUST, rng.uniform(0, 0.4)), "CorrodedMetal",
                  yaw=0)
        n = 0
    for _ in range(rng.randint(2, 4)):
        f.part("Leaf", (rng.uniform(-W, W) * 0.4, 0.12, rng.uniform(-L, L) * 0.4), (0.32, 0.05, 0.2),
               _tone(_pick(rng, LEAF), rng, 10, 0.25), "Fabric", flags=DECOR,
               rot=(rng.uniform(-15, 15), rng.uniform(0, 180), rng.uniform(-15, 15)))
    if rng.random() < 0.6:
        f.part("Paper", (rng.uniform(-W, W) * 0.3, 0.13, rng.uniform(-L, L) * 0.2), (0.6, 0.05, 0.45),
               mix(_pick(rng, PAPER), CARDBOARD_WET, 0.5), "SmoothPlastic", flags=DECOR,
               rot=(rng.uniform(-8, 8), rng.uniform(0, 180), rng.uniform(-8, 8)))


@prop({"kind": "tuft"}, {"kind": "line", "length": 6}, {"kind": "crack", "length": 4})
def weeds(D, folder, origin, ry, rng, kind=None, length=None):
    """Weeds: a tuft of grass blades leaning out of a crack, a line of tufts and moss along a wall
    base (wall on +Z, along X), or tufts following a crack (along Z). Grass material, dry
    yellowed tips mixed with green. Footprint tuft 0.8, line/crack length 3-8 studs.
    tuft 4-10, line 10-30, crack 8-26 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["tuft", "tuft", "line"])

    def tuft(x, z, n, hmax):
        _disk(f, "Moss", x, z, rng.uniform(0.35, 0.6), 0.05, _tone(_pick(rng, MOSS), rng, 6), "Grass")
        for _ in range(n):
            a = rng.uniform(0, 360)
            h = hmax * rng.uniform(0.45, 1.0)
            lean = rng.uniform(8, 38)
            g = f.sub((x + rng.uniform(-0.1, 0.1), 0, z + rng.uniform(-0.1, 0.1)), ry=a, rz=lean)
            col = _tone(_pick(rng, GRASS), rng, 8, darken=rng.uniform(0, 0.2))
            g.part("Weed", (0, h / 2, 0), (0.05, h, rng.uniform(0.1, 0.22)), col, "Grass", flags=DECOR)

    if kind == "tuft":
        tuft(0, 0, rng.randint(3, 8), rng.uniform(0.5, 1.1))
    elif kind == "line":
        L = length or rng.uniform(3, 7)
        _flat(f, "Moss", 0, 0.25, L, 0.3, 0.05, _tone(_pick(rng, MOSS), rng, 6), "Grass")
        x = -L / 2 + rng.uniform(0, 0.5)
        while x < L / 2:
            tuft(x, rng.uniform(0.1, 0.35), rng.randint(2, 4), rng.uniform(0.4, 0.9))
            x += rng.uniform(1.0, 2.2)
    else:
        L = length or rng.uniform(3, 6)
        z = -L / 2
        while z < L / 2:
            tuft(rng.uniform(-0.15, 0.15), z, rng.randint(2, 4), rng.uniform(0.3, 0.7))
            z += rng.uniform(0.8, 1.6)


@prop({}, {"size": 2.4})
def moss_patch(D, folder, origin, ry, rng, size=None):
    """A patch of dark moss on damp ground (shade, near a drip or a wall): soft overlapping blotches.
    Footprint 1-3 studs. 3-6 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    s = size or rng.uniform(1.0, 2.0)
    for i in range(rng.randint(3, 6)):
        _disk(f, "Moss", rng.uniform(-0.35, 0.35) * s, rng.uniform(-0.3, 0.3) * s, s * rng.uniform(0.35, 0.7),
              0.05 + 0.006 * i, _tone(_pick(rng, MOSS), rng, 6, darken=rng.uniform(0, 0.25)), "Grass")


@prop({}, {"radius": 2.0})
def puddle(D, folder, origin, ry, rng, radius=None, debris=None):
    """A standing puddle: a dark damp rim soaking out from it, the water itself irregular (several
    overlapping pools, glossy), maybe a leaf or a soaked scrap floating. Footprint 1.5-5 studs.
    4-9 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    R = radius or rng.uniform(0.9, 1.6)
    for i in range(2):
        _disk(f, "PuddleRim", rng.uniform(-0.2, 0.2) * R, rng.uniform(-0.2, 0.2) * R, R * rng.uniform(2.3, 2.7),
              0.05 + 0.004 * i, DAMP, "Concrete", transparency=0.5 + 0.1 * i)
    for i in range(rng.randint(2, 4)):
        _disk(f, "PuddleWater", rng.uniform(-0.45, 0.45) * R, rng.uniform(-0.35, 0.35) * R, R * rng.uniform(1.0, 1.6),
              0.06 + 0.004 * i, _tone(WATER, rng, 4), "SmoothPlastic", transparency=0.2, reflectance=0.35)
    debris = (rng.random() < 0.5) if debris is None else debris
    if debris:
        f.part("Leaf", (rng.uniform(-0.4, 0.4) * R, 0.08, rng.uniform(-0.3, 0.3) * R), (0.32, 0.05, 0.2),
               _tone(_pick(rng, LEAF), rng, 10, 0.3), "Fabric", flags=DECOR, rot=(0, rng.uniform(0, 180), 0))


@prop({}, {"count": 8, "radius": 1.6})
def gum_spots(D, folder, origin, ry, rng, count=None, radius=1.0):
    """Old flattened chewing gum, grey-black blotches trodden into the ground (doorways, where
    people wait). Footprint ~2 studs. 2-8 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    for _ in range(count or rng.randint(2, 5)):
        r = radius * math.sqrt(rng.random())
        a = rng.uniform(0, 2 * math.pi)
        _disk(f, "Gum", math.cos(a) * r, math.sin(a) * r, rng.uniform(0.12, 0.24), 0.05,
              _tone(_pick(rng, GUM), rng, 4), "SmoothPlastic")


@prop({"kind": "survey"}, {"kind": "chalk"}, {"kind": "spray"})
def paint_marks(D, folder, origin, ry, rng, kind=None, color=None):
    """Marks on the ground: faded utility survey paint (an arrow and dashes along -Z), chalk tally
    marks (someone counting), or a sprayed X with a ring. Half worn away. Footprint 1.5-4 studs.
    3-10 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["survey", "chalk", "spray"])
    t = 0.05
    if kind == "survey":
        col = color or PAINT[_pick(rng, ["orange", "yellow", "white", "blue"])]
        tr = rng.uniform(0.3, 0.5)
        _flat(f, "Paint", 0, 0.4, 0.16, 1.6, t, col, "SmoothPlastic", transparency=tr)
        for e in (-1, 1):
            g = f.sub((0, 0, -0.4), ry=e * 35)
            g.part("Paint", (0, t / 2, 0.3), (0.15, t, 0.6), col, "SmoothPlastic", flags=DECOR, transparency=tr)
        for i in range(rng.randint(1, 3)):
            _flat(f, "Paint", 0, 1.6 + i * 0.7, 0.15, 0.4, t, col, "SmoothPlastic", transparency=tr + 0.15)
    elif kind == "chalk":
        col = color or CHALK
        n = rng.randint(4, 5)
        for i in range(n):
            if i < 4:
                f.part("Chalk", (-0.3 + i * 0.2, t / 2, 0), (0.07, t, 0.75), col, "SmoothPlastic", flags=DECOR,
                       transparency=0.45, rot=(0, rng.uniform(-5, 5), 0))
            else:
                f.part("Chalk", (0, t / 2 + 0.005, 0), (0.07, t, 1.0), col, "SmoothPlastic", flags=DECOR,
                       transparency=0.45, rot=(0, -55 + rng.uniform(-5, 5), 0))
        if rng.random() < 0.6:
            f.part("Chalk", (0.9, t / 2, rng.uniform(-0.2, 0.2)), (0.07, t, 0.75), col, "SmoothPlastic",
                   flags=DECOR, transparency=0.5)
    else:
        col = color or PAINT[_pick(rng, ["red", "white", "orange"])]
        for e in (-1, 1):
            f.part("Paint", (0, t / 2 + (0.003 if e > 0 else 0), 0), (0.2, t, 1.6), col, "SmoothPlastic",
                   flags=DECOR, transparency=0.35, rot=(0, e * 45 + rng.uniform(-6, 6), 0))
        k = 8
        for i in range(k):
            if rng.random() < 0.25:
                continue  # sprayed in one go, gaps where it ran dry
            a = 2 * math.pi * i / k
            f.part("Paint", (math.cos(a) * 1.0, t / 2, math.sin(a) * 1.0), (0.13, t, 0.8), col, "SmoothPlastic",
                   flags=DECOR, transparency=0.45, rot=(0, -math.degrees(a), 0))
