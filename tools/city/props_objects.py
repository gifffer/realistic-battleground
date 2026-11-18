"""props_objects: the furniture and urban objects of the alleys, built from parts: bins and skips,
a shipping container, drums, crates, the black market's dressing, the squat's belongings and the
building-site leftovers.

Every prop is one function

    name(D, folder, origin, ry, rng, **options) -> number of parts made

  • D       a citykit.Data
  • folder  the folder the parts go in (e.g. "Alleys/Props")
  • origin  the floor point (x, y, z) the prop stands on (y = the floor's top; for the table-top
            goods, the table's top)
  • ry      its turn about Y in degrees (its front faces -Z when ry = 0; "against a wall" props
            have the wall behind them, on +Z)
  • rng     a random.Random: sizes, tilts, wear and colours all come from it (no two alike)

Scale: a Roblox character is about 5 studs tall, 1 stud ~ 0.3 m (a door is ~7 studs, a table top
~2.4 studs high, a mattress 3 x 6.2 studs).

How they are made (environment-art rules applied with parts): kitbash every object from its real
sub-parts (a dumpster is a shell, ribs, corner posts, fork pockets, two lids on hinges, casters);
put the wear where use and weather put it, never at random (grime rising from the ground in
two translucent layers = a gradient, rust at the edges, the rims and under the drips, scuffs where
hands and feet touch, stains in the middle of a mattress); sag, dent and tilt everything a little.

Flags: DECOR for small things and surface marks (no collision, no shadow), DECOR_SHADOW for loose
things that still shade, SMALL / PROP for things a player bumps into or stands on (only the main
volume of a prop collides: one or a few parts, the detail never).

Only built-in Materials and colours (no textures, no meshes).

NO BOTTLES of any kind (glass or plastic, decoration or litter): there is none in here, keep it so.
(The gas cylinders and the stove's cartridge are named GasCylinder / GasCartridge.)

CATALOGUE lists every prop with a few option sets for tools/city/preview_props_objects.py.
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
    SOLID,
    WEDGE,
    Frame,
    mix,
    yxz_matrix,
)

CARDBOARD_MAT = "Cardboard"  # the 2024 material; "SmoothPlastic" if a build ever lacks it

# -- palette (dirty, desaturated; matches alleys.py and props_ground.py) -----------------------
DUMPSTER = [(46, 66, 52), (40, 54, 74), (70, 72, 70), (92, 52, 36), (58, 62, 44)]
LID_BLACK = (30, 31, 33)
CONTAINER = [(118, 46, 36), (40, 56, 78), (56, 76, 60), (104, 98, 90), (96, 66, 40), (72, 40, 44)]
DRUM = [(40, 62, 96), (118, 40, 32), (34, 34, 36), (150, 124, 48), (60, 80, 56)]
BIN = [(36, 38, 40), (40, 58, 44), (44, 60, 86), (88, 66, 44), (70, 72, 74)]
RECYCLE = [(40, 92, 60), (44, 78, 130), (170, 140, 50), (120, 120, 118)]
RUST = (89, 47, 30)
RUST_DARK = (59, 29, 19)
RUST_LIGHT = (122, 70, 40)
GALVANISED = (112, 114, 112)
IRON = (46, 44, 42)
STEEL = (128, 130, 132)
RUBBER = (30, 30, 32)
GRIME = (30, 27, 22)
SOOT = (16, 15, 14)
ASH = (88, 86, 82)
OIL = (14, 13, 13)
CARDBOARD = (132, 106, 72)
CARDBOARD_DARK = (104, 84, 58)
CARDBOARD_WET = (72, 58, 42)
TAPE = (158, 136, 96)
DUCT = (120, 122, 122)
WOOD = (104, 87, 60)
WOOD_OLD = (82, 70, 54)
WOOD_GREY = (98, 94, 86)
WOOD_FRESH = (150, 122, 86)
CRATE_WOOD = [(128, 104, 70), (112, 94, 66), (98, 90, 76), (138, 116, 80)]
PLASTIC_CRATE = [(120, 40, 36), (40, 60, 92), (34, 34, 36), (48, 76, 52), (150, 120, 40)]
TARP = [(38, 56, 74), (52, 62, 44), (70, 74, 78), (92, 70, 44), (40, 70, 110)]
FABRIC = [(70, 58, 50), (58, 62, 70), (84, 46, 40), (60, 66, 50), (96, 86, 70), (44, 44, 48)]
MATTRESS = [(176, 168, 150), (160, 160, 156), (150, 140, 118), (140, 150, 160)]
STAIN = [(110, 86, 48), (86, 64, 40), (60, 46, 34), (70, 36, 30)]
FOAM = (196, 176, 110)
UPHOLSTERY = [(96, 54, 40), (70, 80, 60), (110, 92, 66), (66, 60, 74), (120, 70, 50)]
JACKET = [(28, 28, 30), (40, 54, 80), (82, 70, 50), (60, 30, 30), (54, 60, 46), (90, 90, 92)]
SHOEBOX = [(170, 70, 40), (40, 40, 44), (190, 186, 176), (60, 90, 140), (140, 40, 44)]
SCREEN = (14, 16, 18)
CONE = (196, 86, 38)
STRIPE_RED = (150, 44, 40)
STRIPE_WHITE = (186, 184, 176)
CONCRETE = (116, 113, 106)
CONCRETE_OLD = (92, 89, 84)
SOIL = (52, 44, 36)
BAG = [(20, 20, 23), (24, 24, 27), (36, 38, 42), (30, 38, 32)]
INK = (30, 30, 32)
NEON_FIRE = (255, 120, 40)

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


def _vcyl(f, name, x, y0, z, h, d, color, mat, flags=DECOR, **kw):
    """An upright cylinder standing on y0."""
    return _cyl(f, name, (x, y0 + h / 2, z), h, d, color, mat, rot=(0, 0, 90), flags=flags, **kw)


def _disk(f, name, x, z, d, th, color, mat, y=0.0, flags=DECOR, **kw):
    """A flat disk lying on y (a cylinder turned upright)."""
    return f.part(name, (x, y + th / 2, z), (th, d, d), color, mat, rot=(0, 0, 90), shape=CYLINDER, flags=flags, **kw)


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
    """A flat/square bar from p0 to p1 (width w across, thickness th)."""
    mid, length, ry, rz = _seg_rot(p0, p1)
    g = Frame(f.D, f.folder, f.world(mid), matrix=f.m)
    return g.part(name, (0, 0, 0), (length + extend, th, w), color, mat, rot=(roll, ry, rz), flags=flags, **kw)


def _skin(f, name, c, w, h, face, color, mat="SmoothPlastic", th=0.04, spin=0.0, flags=DECOR, **kw):
    """A thin patch lying on a face (rust, grime, a label, a stain): c is the point on the surface,
    face one of "-z", "+z", "-x", "+x", "y"; w x h its size in the face's plane, spun by `spin` deg."""
    s = -1 if face[0] == "-" else 1
    if name == "Stain" and face == "y":  # stains on a top are round: a disk (Roblox cylinders stay round)
        d = (w + h) / 2
        return f.part(
            name, (c[0], c[1] + th / 2, c[2]), (th, d, d), color, mat, rot=(0, 0, 90), shape=CYLINDER, flags=flags, **kw
        )
    if face.endswith("z"):
        return f.part(
            name, (c[0], c[1], c[2] + s * th / 2), (w, h, th), color, mat, rot=(0, 0, spin), flags=flags, **kw
        )
    if face.endswith("x"):
        return f.part(
            name, (c[0] + s * th / 2, c[1], c[2]), (th, h, w), color, mat, rot=(spin, 0, 0), flags=flags, **kw
        )
    return f.part(name, (c[0], c[1] + th / 2, c[2]), (w, th, h), color, mat, rot=(0, spin, 0), flags=flags, **kw)


def _tone(color, rng, amount=8, darken=0.0):
    """A colour a little lighter or darker each time, keeping its hue."""
    mean = max(1.0, sum(color) / 3)
    k = (1 + rng.uniform(-amount, amount) / mean) * (1 - darken)
    return tuple(max(0, min(255, c * k + rng.uniform(-2, 2))) for c in color)


def _pick(rng, seq):
    return seq[rng.randrange(len(seq))]


def _w(f, x, z, y=0.0):
    """A local point as a world tuple (to place a sub-prop)."""
    return tuple(float(v) for v in f.world((x, y, z)))


def _yaw(f):
    """The frame's own turn about Y in degrees (for sub-props)."""
    return math.degrees(math.atan2(f.m[0, 2], f.m[2, 2]))


def _bag(f, name, c, d, rng, color=None, flags=DECOR_SHADOW):
    """A full bin bag as a lump: the bulge, a stretched crease turned askew in it (its edges break
    the round shape), the knotted neck on top. 3 parts."""
    col = color or _tone(_pick(rng, BAG), rng, 3)
    _ball(f, name, c, d, col, "Plastic", flags=flags, reflectance=0.07)
    f.part(
        "BagCrease",
        c,
        (d * 0.74, d * 0.6, d * 0.7),
        _tone(col, rng, 3, 0.08),
        "Plastic",
        rot=(rng.uniform(15, 40), rng.uniform(0, 90), rng.uniform(15, 40)),
        reflectance=0.07,
    )
    f.part(
        "BagKnot",
        (c[0] + rng.uniform(-0.1, 0.1), c[1] + d * 0.48, c[2]),
        (0.3, 0.3, 0.26),
        col,
        "Plastic",
        rot=(rng.uniform(-30, 30), rng.uniform(0, 90), rng.uniform(-30, 30)),
        reflectance=0.07,
    )


def _on_plate(f, name, center, rot, u, v, size, color, mat="Fabric", lift=0.04, spin=0.0, **kw):
    """A patch (tape, a stain) stuck on a tilted plate: the plate's centre and rot, (u, v) the
    patch's offset in the plate's own X / Z, lifted `lift` off its top face."""
    m = yxz_matrix(*rot)
    off = m @ [u, lift, v]
    c = (center[0] + off[0], center[1] + off[1], center[2] + off[2])
    g = Frame(f.D, f.folder, f.world(c), matrix=f.m @ m)
    return g.part(name, (0, 0, 0), size, color, mat, rot=(0, spin, 0), **kw)


def _grime(f, x0, x1, y0, h, z, face, col, rng, w_axis="x"):
    """Grime rising from the ground on a face: a dark band and a paler, higher, more transparent
    one over it (a gradient in two parts)."""
    span = x1 - x0
    c = ((x0 + x1) / 2, 0, z) if w_axis == "x" else (z, 0, (x0 + x1) / 2)
    for k, (hh, tr) in enumerate(((h, 0.4), (h * rng.uniform(1.3, 1.6), 0.75))):
        cc = (c[0], y0 + hh / 2, c[2])
        _skin(
            f,
            "Grime",
            cc,
            span - 0.02,
            hh,
            face,
            mix(col, GRIME, 0.75 if k == 0 else 0.55),
            "SmoothPlastic",
            th=0.03 + 0.01 * k,
            transparency=tr,
        )


def _rust(f, rng, c, face, size=1.0, n=1):
    """n rust patches around a surface point (CorrodedMetal, a dark ring and a paler core)."""
    for _ in range(n):
        w, h = rng.uniform(0.4, 1.2) * size, rng.uniform(0.3, 0.9) * size
        cc = (
            c[0] + rng.uniform(-0.3, 0.3) * size,
            c[1] + rng.uniform(-0.3, 0.3) * size,
            c[2] + rng.uniform(-0.3, 0.3) * size,
        )
        if face.endswith("z"):
            cc = (cc[0], cc[1], c[2])
        elif face.endswith("x"):
            cc = (c[0], cc[1], cc[2])
        else:
            cc = (cc[0], c[1], cc[2])
        _skin(
            f,
            "Rust",
            cc,
            w,
            h,
            face,
            _tone(_pick(rng, [RUST, RUST_DARK, RUST_DARK]), rng, 6, 0.15),
            "CorrodedMetal",
            th=0.035,
            spin=rng.uniform(-20, 20),
        )


def _streak(f, rng, x, ytop, z, face, length=None, color=RUST_DARK):
    """A drip streak running down a face from ytop."""
    ln = length or rng.uniform(0.6, 1.6)
    return _skin(
        f,
        "Streak",
        (x, ytop - ln / 2, z),
        rng.uniform(0.08, 0.18),
        ln,
        face,
        _tone(color, rng, 5),
        "SmoothPlastic",
        th=0.03,
        spin=rng.uniform(-3, 3),
        transparency=0.3,
    )


# =============================================================================================
# Bins, skips, the container, drums
# =============================================================================================
@prop({"lid": "closed"}, {"lid": "open"}, {"lid": "half"}, {"lid": "open", "color": (40, 54, 74), "full": True})
def dumpster(D, folder, origin, ry, rng, lid=None, color=None, full=None):
    """A big steel commercial dumpster (front-load skip): sloped top, the body's shell with three
    stamped ribs on the front, corner posts, a rolled rim, fork pockets on both sides, two black
    plastic lids on hinges (closed / one or both thrown back "open" / one propped up by the rubbish
    "half"), four casters; dented, grime rising from the ground, rust patches at the rim and
    corners, drip streaks, a faded info plate, a sprayed tag. When open, bin bags and cardboard
    bulge over the rim. Its back goes against a wall (+Z).
    Footprint ~6 x 3.6 studs (+0.4 pockets), 3.9-4.6 tall (open lids to ~7.5). 45-65 parts;
    shell and lids PROP, the rest DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    lid = lid or _pick(rng, ["closed", "closed", "open", "half"])
    full = (rng.random() < 0.7) if full is None else full
    col = _tone(color or _pick(rng, DUMPSTER), rng, 6, darken=rng.uniform(0, 0.25))
    dark = _tone(col, rng, 4, 0.3)
    L, W = rng.uniform(5.6, 6.4), rng.uniform(3.4, 3.8)
    y0, t = 0.55, 0.15
    H = rng.uniform(3.2, 3.5)
    H2 = H + rng.uniform(0.35, 0.55)
    mat = "Metal"
    # the shell: floor, four walls, the sloped tops of the side walls
    f.box("Dumpster", (-L / 2, y0, -W / 2), (L / 2, y0 + t, W / 2), dark, mat, flags=PROP)
    f.box("Dumpster", (-L / 2, y0, -W / 2), (L / 2, y0 + H, -W / 2 + t), col, mat, flags=PROP)
    f.box("Dumpster", (-L / 2, y0, W / 2 - t), (L / 2, y0 + H2, W / 2), _tone(col, rng, 3), mat, flags=PROP)
    for s in (-1, 1):
        x0 = s * L / 2 - (t if s > 0 else 0)
        f.box("Dumpster", (x0, y0, -W / 2 + t), (x0 + t, y0 + H, W / 2 - t), _tone(col, rng, 3), mat, flags=PROP)
        f.part(
            "Dumpster",
            (s * (L / 2 - t / 2), y0 + H + (H2 - H) / 2, 0),
            (t, H2 - H, W),
            col,
            mat,
            shape=WEDGE,
            flags=PROP,
        )
    # rolled rim along the front, stamped ribs, corner posts
    f.box("DumpsterRim", (-L / 2 - 0.05, y0 + H - 0.25, -W / 2 - 0.13), (L / 2 + 0.05, y0 + H, -W / 2), dark, mat)
    for x in (-L / 3, 0, L / 3):
        x += rng.uniform(-0.1, 0.1)
        f.box(
            "DumpsterRib", (x - 0.17, y0 + 0.2, -W / 2 - 0.1), (x + 0.17, y0 + H - 0.3, -W / 2), _tone(col, rng, 5), mat
        )
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * (L / 2 + 0.02), sz * (W / 2 + 0.02)
            f.box(
                "DumpsterPost",
                (x - 0.13, y0, z - 0.13),
                (x + 0.13, y0 + (H if sz < 0 else H2) - 0.05, z + 0.13),
                _tone(dark, rng, 4),
                mat,
            )
    # fork pockets on the sides, their dark mouths at the front
    yp = y0 + H * rng.uniform(0.4, 0.48)
    for s in (-1, 1):
        x0, x1 = (L / 2, L / 2 + 0.38) if s > 0 else (-L / 2 - 0.38, -L / 2)
        f.box("ForkPocket", (x0, yp, -W * 0.42), (x1, yp + 0.55, W * 0.42), _tone(dark, rng, 4), mat)
        f.box(
            "ForkPocketMouth",
            (x0 + 0.05, yp + 0.06, -W * 0.42 - 0.02),
            (x1 - 0.05, yp + 0.49, -W * 0.42 + 0.03),
            SOOT,
            "SmoothPlastic",
        )
    # the two lids, hinged at the back; closed they follow the slope
    slope = math.degrees(math.atan2(H2 - H, W))
    LL = math.hypot(W, H2 - H) + 0.22
    lw = L / 2 - 0.1
    states = {
        "closed": ("c", "c"),
        "open": _pick(rng, [("o", "o"), ("o", "c"), ("c", "o")]),
        "half": _pick(rng, [("h", "c"), ("c", "h"), ("h", "o")]),
    }[lid]
    lid_col = _tone(_pick(rng, [LID_BLACK, LID_BLACK, dark]), rng, 4)
    open_sides = []
    for s, st in zip((-1, 1), states):
        ang = {"c": -slope + rng.uniform(-0.6, 0.6), "o": rng.uniform(98, 116), "h": rng.uniform(14, 30)}[st]
        if st != "c":
            open_sides.append((s, st))
        g = f.sub((s * L / 4, y0 + H2 + 0.09, W / 2 - 0.06), rx=ang, rz=rng.uniform(-1.2, 1.2))
        c = _tone(lid_col, rng, 3)
        g.box("DumpsterLid", (-lw / 2, -0.08, -LL), (lw / 2, 0.08, 0), c, "Plastic", flags=PROP)
        for u in (-1, 1):
            g.box(
                "LidRib",
                (u * lw / 4 - 0.14, 0.08, -LL + 0.35),
                (u * lw / 4 + 0.14, 0.2, -0.25),
                _tone(c, rng, 3),
                "Plastic",
            )
        g.box("LidLip", (-lw / 2, -0.28, -LL), (lw / 2, 0.06, -LL + 0.12), _tone(c, rng, 3, 0.1), "Plastic")
        _cyl(f, "Hinge", (s * L / 4, y0 + H2 + 0.06, W / 2 + 0.06), lw * 0.8, 0.2, IRON, "Metal")
    # four casters
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * (L / 2 - 0.5), sz * (W / 2 - 0.5)
            f.box("Caster", (x - 0.16, 0.36, z - 0.16), (x + 0.16, y0, z + 0.16), IRON, "Metal")
            _cyl(f, "CasterWheel", (x, 0.21, z), 0.22, 0.42, RUBBER, "Rubber", rot=(0, rng.uniform(0, 180), 0))
    # wear: grime up the front, rust at the rim and corners, drips, dents, the plate, a tag
    _grime(f, -L / 2, L / 2, y0, rng.uniform(0.5, 0.9), -W / 2 - 0.135, "-z", col, rng)
    _rust(f, rng, (rng.choice((-1, 1)) * L * 0.38, y0 + H - 0.5, -W / 2), "-z", 1.0, rng.randint(1, 2))
    _rust(f, rng, (rng.uniform(-L, L) * 0.3, y0 + rng.uniform(0.6, 1.4), -W / 2), "-z", 0.9, 1)
    _rust(f, rng, (rng.choice((-1, 1)) * (L / 2 + 0.38), yp + 0.3, rng.uniform(-0.6, 0.6)), "-x", 0.8, 1)
    for _ in range(rng.randint(1, 3)):
        _streak(f, rng, rng.uniform(-L / 2 + 0.4, L / 2 - 0.4), y0 + H - 0.25, -W / 2, "-z")
    for _ in range(rng.randint(1, 2)):
        f.part(
            "Dent",
            (rng.uniform(-L / 2 + 0.8, L / 2 - 0.8), y0 + rng.uniform(0.8, H - 0.9), -W / 2 - 0.03),
            (rng.uniform(0.6, 1.1), rng.uniform(0.5, 0.8), 0.06),
            _tone(col, rng, 4, 0.15),
            mat,
            rot=(rng.uniform(-14, 14), rng.uniform(-14, 14), rng.uniform(0, 90)),
        )
    _skin(
        f,
        "InfoPlate",
        (rng.uniform(-0.8, 0.8), y0 + H - 0.75, -W / 2 - 0.1),
        1.1,
        0.55,
        "-z",
        _tone((118, 116, 108), rng, 8, rng.uniform(0.2, 0.4)),
        spin=rng.uniform(-3, 3),
    )
    if rng.random() < 0.6:
        tag = _tone(_pick(rng, [(170, 170, 166), (150, 50, 50), (60, 110, 160), (40, 40, 42)]), rng, 8)
        x, y = rng.uniform(-L / 2 + 1, L / 2 - 1), y0 + rng.uniform(1.0, 1.8)
        for k in range(2):
            _skin(
                f,
                "Tag",
                (x + k * 0.35, y + rng.uniform(-0.15, 0.15), -W / 2 - 0.1),
                rng.uniform(0.6, 1.1),
                0.09,
                "-z",
                tag,
                spin=rng.uniform(-50, 50),
            )
    # what bulges over the rim when a lid is up
    if full and open_sides:
        for s, st in open_sides:
            top = y0 + H + (0.35 if st == "o" else 0.05)
            for _ in range(rng.randint(1, 2)):
                d = rng.uniform(1.3, 1.8)
                _bag(f, "TrashBag", (s * rng.uniform(0.6, L / 2 - 1.0), top - d / 2, rng.uniform(-0.6, 0.6)), d, rng)
            if st == "o" and rng.random() < 0.7:
                f.part(
                    "Cardboard",
                    (s * rng.uniform(0.8, 1.6), top - 0.2, rng.uniform(-0.8, 0.4)),
                    (rng.uniform(1.2, 1.8), rng.uniform(1.2, 1.6), 0.06),
                    _tone(CARDBOARD, rng, 8, 0.1),
                    CARDBOARD_MAT,
                    rot=(rng.uniform(-30, 30), rng.uniform(-40, 40), rng.uniform(-25, 25)),
                    flags=DECOR_SHADOW,
                )


@prop({}, {"kind": "paper", "lid": "open"}, {"kind": "general"})
def recycling_bin(D, folder, origin, ry, rng, kind=None, lid=None):
    """A 1100 L communal bin, galvanised steel with a domed coloured lid (green or blue for
    recycling, yellow, or a plain grey general-waste one): pressed body with a reinforcing band,
    a paper slot or a lid lifted open over a dark mouth, the colour sticker gone pale and peeling,
    side push handles, a foot-pedal bar at the front, four casters, grime and rust at the base.
    Footprint ~4.2 x 3.5 studs, 4.6 tall. 26-30 parts; body and lid PROP."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["paper", "paper", "general"])
    lid = lid or _pick(rng, ["closed", "closed", "open"])
    L, W, y0 = rng.uniform(4.0, 4.4), rng.uniform(3.3, 3.6), 0.5
    H = rng.uniform(3.2, 3.5)
    body = _tone(GALVANISED, rng, 8, darken=rng.uniform(0.1, 0.3))
    lc = _tone(_pick(rng, RECYCLE[:3]) if kind == "paper" else RECYCLE[3], rng, 8, darken=rng.uniform(0.1, 0.35))
    f.box("RecyclingBin", (-L / 2, y0, -W / 2), (L / 2, y0 + H, W / 2), body, "Metal", flags=PROP)
    f.box(
        "BinBand",
        (-L / 2 - 0.06, y0 + H * 0.62, -W / 2 - 0.06),
        (L / 2 + 0.06, y0 + H * 0.62 + 0.25, W / 2 + 0.06),
        _tone(body, rng, 5, 0.1),
        "Metal",
    )
    f.box(
        "BinRim",
        (-L / 2 - 0.1, y0 + H - 0.18, -W / 2 - 0.1),
        (L / 2 + 0.1, y0 + H, W / 2 + 0.1),
        _tone(body, rng, 4, 0.15),
        "Metal",
    )
    # the domed lid: half a cylinder along X above the rim, hinged at the back
    ang = 0.0 if lid == "closed" else rng.uniform(70, 100)
    g = f.sub((0, y0 + H, W / 2), rx=ang)
    hd = 0.75  # the dome: three curved plates on an arc over the mouth
    r = (W * W / 4 + hd * hd) / (2 * hd)
    th = math.asin(min(1.0, (W / 2 + 0.05) / r))
    for i in range(3):
        phi = -th + (2 * i + 1) * th / 3
        g.part(
            "BinLid",
            (0, -r + hd + r * math.cos(phi) - 0.03, -W / 2 + r * math.sin(phi)),
            (L + 0.12, 0.1, 2 * r * math.sin(th / 3) + 0.06),
            _tone(lc, rng, 3),
            "Plastic",
            rot=(math.degrees(phi), 0, 0),
            flags=PROP,
        )
    for e in (-1, 1):
        g.box(
            "BinLidEnd",
            (e * (L / 2 + 0.02) - 0.04, 0.0, -W + 0.3),
            (e * (L / 2 + 0.02) + 0.04, hd * 0.75, -0.3),
            _tone(lc, rng, 3, 0.1),
            "Plastic",
        )
    g.box(
        "BinLidSkirt", (-L / 2 - 0.08, -0.02, -W - 0.08), (L / 2 + 0.08, 0.12, 0.04), _tone(lc, rng, 4, 0.2), "Plastic"
    )
    if lid == "closed" and kind == "paper":
        g.part(
            "PaperSlot",
            (0, hd * 0.55, -W * 0.82),
            (L * 0.55, 0.32, 0.12),
            SOOT,
            "SmoothPlastic",
            rot=(math.degrees(th) * 0.67, 0, 0),
        )
    if lid != "closed":  # the mouth, the rubbish in it
        f.box(
            "BinMouth",
            (-L / 2 + 0.12, y0 + H - 0.05, -W / 2 + 0.12),
            (L / 2 - 0.12, y0 + H + 0.01, W / 2 - 0.12),
            SOOT,
            "SmoothPlastic",
        )
        for _ in range(rng.randint(1, 3)):
            f.part(
                "Cardboard",
                (rng.uniform(-1.2, 1.2), y0 + H + 0.1, rng.uniform(-0.8, 0.8)),
                (rng.uniform(0.9, 1.5), 0.6, rng.uniform(0.9, 1.4)),
                _tone(CARDBOARD, rng, 8, 0.15),
                CARDBOARD_MAT,
                rot=(rng.uniform(-25, 25), rng.uniform(0, 90), rng.uniform(-25, 25)),
            )
    # the sticker (pale, half peeled), push handles, pedal, casters
    sc = mix(lc, (200, 200, 196), rng.uniform(0.3, 0.5))
    _skin(f, "Sticker", (rng.uniform(-0.4, 0.4), y0 + H * 0.4, -W / 2), 1.4, 1.0, "-z", sc, spin=rng.uniform(-2, 2))
    _skin(
        f,
        "StickerPeel",
        (rng.uniform(-0.5, 0.5), y0 + H * 0.4 + 0.4, -W / 2 - 0.04),
        0.5,
        0.3,
        "-z",
        mix(sc, (220, 220, 210), 0.4),
        spin=rng.uniform(20, 50),
    )
    for s in (-1, 1):
        _rod(
            f,
            "PushHandle",
            (s * (L / 2 + 0.25), y0 + H - 0.7, -W * 0.3),
            (s * (L / 2 + 0.25), y0 + H - 0.7, W * 0.3),
            0.14,
            IRON,
            "Metal",
        )
        for u in (-1, 1):
            _rod(
                f,
                "PushHandle",
                (s * L / 2, y0 + H - 0.7, u * W * 0.3),
                (s * (L / 2 + 0.25), y0 + H - 0.7, u * W * 0.3),
                0.12,
                IRON,
                "Metal",
            )
    f.box("Pedal", (-L * 0.3, y0 + 0.15, -W / 2 - 0.45), (L * 0.3, y0 + 0.3, -W / 2), _tone(IRON, rng, 5), "Metal")
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * (L / 2 - 0.45), sz * (W / 2 - 0.45)
            _cyl(f, "CasterWheel", (x, 0.22, z), 0.22, 0.44, RUBBER, "Rubber", rot=(0, rng.uniform(0, 180), 0))
    _grime(f, -L / 2, L / 2, y0, rng.uniform(0.4, 0.8), -W / 2 - 0.01, "-z", body, rng)
    _rust(f, rng, (rng.choice((-1, 1)) * (L / 2 - 0.5), y0 + 0.5, -W / 2), "-z", 0.8, 1)
    _streak(f, rng, rng.uniform(-L / 2 + 0.5, L / 2 - 0.5), y0 + H * 0.62, -W / 2 - 0.06, "-z")


@prop({"state": "closed"}, {"state": "open"}, {"state": "ajar"}, {"state": "tipped"})
def wheelie_bin(D, folder, origin, ry, rng, state=None, color=None):
    """A two-wheeled 240 L wheelie bin, plastic gone chalky: tapered body (two stacked shells), the
    rim, the lid with its front lip (closed, thrown back "open", lifted on an overfull bag "ajar")
    or the whole bin knocked onto its side with its rubbish spilled out ("tipped"); handle bar,
    wheels on an axle, a painted house number, scuffs, a dirty bottom. Its back (wheels, hinge)
    toward +Z. Footprint ~1.9 x 2.4 studs, 3.4 tall (tipped 3.4 x 2.4 + the spill).
    16-21 parts; body PROP."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["closed", "closed", "open", "ajar", "tipped"])
    col = _tone(color or _pick(rng, BIN), rng, 6, darken=rng.uniform(0.05, 0.25))
    W, Dp, H = 1.9, 2.3, 3.2
    if state == "tipped":
        f = f.sub((0, W / 2 + 0.02, 0), rz=90 + rng.uniform(-3, 3))
    f.box(
        "WheelieBin",
        (-W / 2 + 0.12, 0.15, -Dp / 2 + 0.12),
        (W / 2 - 0.12, H * 0.55, Dp / 2 - 0.12),
        col,
        "Plastic",
        flags=PROP,
    )
    f.box(
        "WheelieBin",
        (-W / 2 + 0.03, H * 0.55, -Dp / 2 + 0.03),
        (W / 2 - 0.03, H - 0.15, Dp / 2 - 0.03),
        _tone(col, rng, 3),
        "Plastic",
        flags=PROP,
    )
    f.box("BinRim", (-W / 2, H - 0.18, -Dp / 2 - 0.05), (W / 2, H - 0.02, Dp / 2), _tone(col, rng, 3, 0.1), "Plastic")
    ang = {
        "closed": rng.uniform(-1, 1),
        "open": rng.uniform(100, 118),
        "ajar": rng.uniform(12, 24),
        "tipped": rng.uniform(30, 70),
    }[state]
    g = f.sub((0, H, Dp / 2 + 0.05), rx=ang)
    lc = _tone(col, rng, 4)
    g.box("BinLid", (-W / 2 - 0.04, 0, -Dp - 0.12), (W / 2 + 0.04, 0.12, 0), lc, "Plastic", flags=SMALL)
    g.box(
        "BinLidLip",
        (-W / 2 - 0.04, -0.22, -Dp - 0.14),
        (W / 2 + 0.04, 0.1, -Dp - 0.04),
        _tone(lc, rng, 3, 0.1),
        "Plastic",
    )
    # handle, axle, wheels
    _cyl(f, "BinHandle", (0, H - 0.25, Dp / 2 + 0.2), W * 0.85, 0.16, _tone(col, rng, 3, 0.15), "Plastic")
    _cyl(f, "Axle", (0, 0.36, Dp / 2 - 0.05), W + 0.3, 0.12, IRON, "Metal")
    for s in (-1, 1):
        _cyl(f, "BinWheel", (s * (W / 2 + 0.05), 0.36, Dp / 2 - 0.05), 0.24, 0.72, RUBBER, "Rubber")
        _cyl(f, "BinHub", (s * (W / 2 + 0.18), 0.36, Dp / 2 - 0.05), 0.05, 0.28, _tone(col, rng, 4, 0.2), "Plastic")
    f.box(
        "BinFoot", (-W * 0.35, 0.0, -Dp / 2 + 0.05), (W * 0.35, 0.18, -Dp / 2 + 0.3), _tone(col, rng, 3, 0.2), "Plastic"
    )
    # wear: the number, scuffs, the dirty bottom
    _skin(
        f,
        "BinNumber",
        (rng.uniform(-0.2, 0.2), H * 0.72, -Dp / 2 + 0.03),
        0.7,
        0.45,
        "-z",
        _tone((190, 186, 176), rng, 8, 0.2),
        spin=rng.uniform(-6, 6),
    )
    for _ in range(rng.randint(1, 2)):
        y = rng.uniform(0.8, 2.8)
        _skin(
            f,
            "Scuff",
            (rng.uniform(-0.5, 0.5), y, -Dp / 2 + (0.12 if y < H * 0.55 else 0.03)),
            rng.uniform(0.3, 0.5),
            0.06,
            "-z",
            mix(col, (190, 190, 186), 0.35),
            spin=rng.uniform(-30, 30),
            th=0.02,
        )
    _grime(f, -W / 2 + 0.12, W / 2 - 0.12, 0.15, rng.uniform(0.4, 0.7), -Dp / 2 + 0.1, "-z", col, rng)
    if state == "ajar":
        _bag(f, "TrashBag", (rng.uniform(-0.2, 0.2), H + 0.05, -0.2), 1.5, rng)
    if state == "tipped":  # the spill out of its mouth (the bin's top now faces -X)
        for i in range(rng.randint(2, 4)):
            d = rng.uniform(1.0, 1.6)
            _ball(
                f,
                "TrashBag" if i < 2 else "Rubbish",
                (-W / 2 + d * 0.38 - 0.02, H + d * 0.3 + i * 0.6, rng.uniform(-1.0, 1.0)),
                d,
                _tone(_pick(rng, BAG) if i < 2 else _pick(rng, [CARDBOARD, (90, 80, 60)]), rng, 4),
                "Plastic",
                reflectance=0.05,
                flags=DECOR_SHADOW,
            )


@prop({"doors": "closed"}, {"doors": "ajar"}, {"doors": "closed", "color": (40, 56, 78)})
def shipping_container(D, folder, origin, ry, rng, doors=None, color=None, length=None):
    """A 20 ft shipping container, years past its last voyage: corrugated long walls (raised
    panels), corner posts with their castings, top and bottom rails, the doors at the +X end with
    four lock bars, handles and the seal plate (closed, or one door swung open on a dark inside),
    a dented roof; rust eating the bottom rail and the corners, drips under the roof rail, the
    owner's band of faded white "letters" and its number plate, paint patches over old tags.
    Footprint 20 x 8 studs (doors ajar: +4 on +X), 8.5 tall. 60-73 parts; the core is SOLID
    (stand on it), the rest DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    doors = doors or _pick(rng, ["closed", "closed", "ajar"])
    L = length or 20.0
    W, H = 8.0, 8.5
    col = _tone(color or _pick(rng, CONTAINER), rng, 6, darken=rng.uniform(0.05, 0.3))
    frame = _tone(col, rng, 4, 0.25)
    f.box(
        "Container", (-L / 2 + 0.2, 0.2, -W / 2 + 0.15), (L / 2 - 0.2, H - 0.2, W / 2 - 0.15), col, "Metal", flags=SOLID
    )
    # corner posts, castings, rails
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * (L / 2 - 0.22), sz * (W / 2 - 0.22)
            f.box("ContainerPost", (x - 0.24, 0, z - 0.24), (x + 0.24, H, z + 0.24), frame, "Metal")
            f.box(
                "CornerCasting",
                (x - 0.28, H - 0.4, z - 0.28),
                (x + 0.28, H + 0.02, z + 0.28),
                _tone(RUST_DARK, rng, 5),
                "CorrodedMetal",
            )
    for sz in (-1, 1):
        z = sz * (W / 2 - 0.08)
        f.box("ContainerRail", (-L / 2 + 0.4, H - 0.4, z - 0.12), (L / 2 - 0.4, H, z + 0.12), frame, "Metal")
        f.box(
            "ContainerRail",
            (-L / 2 + 0.4, 0, z - 0.14),
            (L / 2 - 0.4, 0.45, z + 0.14),
            mix(frame, RUST, rng.uniform(0.3, 0.7)),
            "CorrodedMetal",
        )
    # corrugation: raised panels on both long walls
    pitch = 1.75
    n = int((L - 1.2) / pitch)
    x0 = -(n - 1) * pitch / 2
    for sz in (-1, 1):
        for i in range(n):
            x = x0 + i * pitch
            c = _tone(col, rng, 4, 0.0 if sz < 0 else 0.05)
            f.box(
                "Corrugation",
                (x - 0.34, 0.5, sz * (W / 2 - 0.15) - 0.1),
                (x + 0.34, H - 0.45, sz * (W / 2 - 0.15) + 0.1),
                c,
                "Metal",
            )
    # the doors (+X end) and the blank end (-X)
    xd = L / 2 - 0.1
    f.box(
        "ContainerEnd",
        (-L / 2 + 0.05, 0.45, -W / 2 + 0.45),
        (-L / 2 + 0.2, H - 0.4, W / 2 - 0.45),
        _tone(col, rng, 4, 0.05),
        "Metal",
    )
    f.box("DoorHeader", (xd - 0.15, H - 0.65, -W / 2 + 0.4), (xd + 0.1, H - 0.2, W / 2 - 0.4), frame, "Metal")
    f.box(
        "DoorSill", (xd - 0.15, 0.1, -W / 2 + 0.4), (xd + 0.1, 0.5, W / 2 - 0.4), mix(frame, RUST, 0.6), "CorrodedMetal"
    )
    dw = (W - 0.9) / 2
    for k, s in enumerate((-1, 1)):
        hinge_z = s * (W / 2 - 0.45)
        swing = rng.uniform(55, 110) if (doors == "ajar" and k == 1) else 0.0
        g = f.sub((xd, 0, hinge_z), ry=s * swing)
        c = _tone(col, rng, 4)
        z0, z1 = (0.0, dw) if s < 0 else (-dw, 0.0)
        g.box("ContainerDoor", (0, 0.5, z0), (0.12, H - 0.65, z1), c, "Metal", flags=PROP)
        for u in (0.3, 0.7):
            zz = z0 + (z1 - z0) * u
            _vcyl(g, "LockBar", 0.2, 0.35, zz, H - 0.75, 0.12, _tone(GALVANISED, rng, 8, 0.3), "Metal")
            g.box(
                "LockHandle", (0.16, 3.4, zz - 0.06), (0.32, 3.55, zz + (0.9 if s < 0 else -0.9) * 0.5), IRON, "Metal"
            )
        if k == 0:
            _skin(g, "SealPlate", (0.12, 5.0, (z0 + z1) / 2), 1.2, 0.8, "+x", _tone((150, 150, 144), rng, 8, 0.25))
        _rust(g, rng, (0.12, rng.uniform(0.9, 1.6), (z0 + z1) / 2), "+x", 1.0, 1)
    if doors == "ajar":
        f.box(
            "ContainerInside", (xd - 0.25, 0.5, -dw + 0.45), (xd - 0.05, H - 0.65, W / 2 - 0.45), SOOT, "SmoothPlastic"
        )
    # roof dent, rust at the bottom and corners, drips, the owner's band and number
    f.part(
        "RoofDent",
        (rng.uniform(-L / 4, L / 4), H - 0.17, rng.uniform(-1.5, 1.5)),
        (rng.uniform(2, 4), 0.06, 2.5),
        _tone(col, rng, 4, 0.2),
        "Metal",
        rot=(rng.uniform(-4, 4), rng.uniform(0, 90), rng.uniform(-4, 4)),
    )
    face_z = -W / 2 + 0.05 - 0.02
    for _ in range(rng.randint(2, 3)):
        _rust(f, rng, (rng.uniform(-L / 2 + 1, L / 2 - 1), rng.uniform(0.7, 1.5), face_z), "-z", 1.6, 1)
    _rust(f, rng, (rng.choice((-1, 1)) * (L / 2 - 1.2), H - 1.0, face_z), "-z", 1.3, 1)
    for _ in range(rng.randint(2, 3)):
        _streak(f, rng, rng.uniform(-L / 2 + 1, L / 2 - 1), H - 0.45, face_z, "-z", length=rng.uniform(1.5, 3.5))
    band_y = H * rng.uniform(0.62, 0.72)
    letters = rng.randint(4, 6)
    lx = rng.uniform(-L / 2 + 2.5, -1)
    lc = mix(_tone((176, 174, 166), rng, 8), col, rng.uniform(0.35, 0.55))
    for i in range(letters):  # the owner's name: tall narrow letters, faded into the paint, some flaked off
        if rng.random() < 0.2:
            continue
        _skin(
            f,
            "Lettering",
            (lx + i * 0.8, band_y, face_z - 0.12),
            0.5,
            rng.uniform(1.25, 1.4),
            "-z",
            lc,
            th=0.03,
            spin=rng.uniform(-1, 1),
            transparency=0.25,
        )
        if rng.random() < 0.5:  # the letter's bar
            _skin(
                f,
                "Lettering",
                (lx + i * 0.8 + 0.12, band_y + rng.uniform(-0.3, 0.3), face_z - 0.13),
                0.55,
                0.2,
                "-z",
                lc,
                th=0.03,
                transparency=0.25,
            )
    _skin(
        f,
        "ContainerNumber",
        (L / 2 - 3.2, H - 1.2, face_z - 0.02),
        2.6,
        0.45,
        "-z",
        _tone((170, 168, 160), rng, 8, 0.3),
    )
    for _ in range(rng.randint(0, 1)):  # rollered paint over old graffiti
        _skin(
            f,
            "PaintPatch",
            (rng.uniform(-L / 2 + 2, L / 2 - 2), rng.uniform(1.5, 3.5), face_z - 0.03),
            rng.uniform(2, 3.5),
            rng.uniform(1.2, 2.0),
            "-z",
            _tone(col, rng, 6, -0.15),
            th=0.03,
            spin=rng.uniform(-3, 3),
        )
    _grime(f, -L / 2 + 0.4, L / 2 - 0.4, 0.45, rng.uniform(0.5, 1.0), face_z - 0.05, "-z", col, rng)


@prop({"state": "upright"}, {"state": "tipped"}, {"state": "fire"}, {"state": "upright", "color": (118, 40, 32)})
def oil_drum(D, folder, origin, ry, rng, state=None, color=None, light=True):
    """A 200 L steel drum, dented and rusting: body, two rolling hoops, top and bottom chimes, a
    lid with its bung (or a cut-open top); rust bands and patches, a faded hazard label, a dent.
    `tipped`: on its side over an oil stain. `fire`: a burn barrel, top cut away jagged, holes
    punched round the bottom glowing orange, soot up the side, ash on the ground; tagged like
    alleys.py's: the body CityFire, a Neon disk inside "Embers" CityFireEmbers with its light and
    fire (set light=False to leave the light out).
    Footprint 1.9 studs round (tipped 2.8 x 1.9), 2.8 tall. 11-17 parts; body PROP."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["upright", "upright", "tipped", "fire"])
    d, H = 1.85, 2.8
    col = _tone(color or _pick(rng, DRUM), rng, 6, darken=rng.uniform(0.1, 0.35))
    if state == "fire":
        col = mix(col, RUST_DARK, rng.uniform(0.5, 0.8))
    if state == "tipped":
        _disk(
            f,
            "OilStain",
            rng.uniform(-0.4, 0.4),
            rng.uniform(-1.2, -0.6),
            rng.uniform(1.8, 2.6),
            0.04,
            OIL,
            "SmoothPlastic",
            transparency=0.2,
            reflectance=0.15,
        )
        f = f.sub((0, d / 2, 0), rz=90, rx=rng.uniform(-3, 3))
        f = f.sub((0, -H / 2, 0))
    extra = {"t": ["CityFire"]} if state == "fire" else None
    _vcyl(
        f,
        "BurnBarrel" if state == "fire" else "Drum",
        0,
        0.05,
        0,
        H - 0.1,
        d,
        col,
        "CorrodedMetal" if state == "fire" else "Metal",
        flags=PROP,
        extra=extra,
    )
    for y in (H / 3, 2 * H / 3):
        _vcyl(f, "DrumHoop", 0, y - 0.07, 0, 0.14, d + 0.08, _tone(col, rng, 4, 0.12), "Metal")
    _vcyl(f, "DrumChime", 0, 0, 0, 0.12, d + 0.05, _tone(col, rng, 4, 0.2), "Metal")
    if state != "fire":
        _vcyl(f, "DrumChime", 0, H - 0.12, 0, 0.14, d + 0.05, _tone(col, rng, 4, 0.2), "Metal")
        _vcyl(f, "DrumLid", 0, H - 0.08, 0, 0.06, d - 0.08, _tone(col, rng, 6, 0.1), "Metal")
        _vcyl(f, "Bung", d * 0.28, H - 0.04, 0.1, 0.08, 0.28, _tone(GALVANISED, rng, 8, 0.3), "Metal")
        _skin(
            f,
            "HazardLabel",
            (0, H * 0.5, -d / 2 + 0.07),
            0.5,
            0.5,
            "-z",
            _tone(_pick(rng, [(176, 140, 50), (170, 160, 150), (150, 70, 50)]), rng, 8, 0.3),
            spin=45 + rng.uniform(-4, 4),
        )
        f.part(
            "Dent",
            (rng.uniform(-0.2, 0.2), rng.uniform(0.5, H - 0.6), -d / 2 + 0.12),
            (0.5, 0.45, 0.12),
            _tone(col, rng, 4, 0.2),
            "Metal",
            rot=(rng.uniform(-15, 15), rng.uniform(-20, 20), rng.uniform(0, 90)),
        )
        for _ in range(rng.randint(1, 3)):  # rust in bands where the hoops hold water, and at the bottom
            y = _pick(rng, [0.15, H / 3, 2 * H / 3, rng.uniform(0.4, H - 0.4)])
            _vcyl(
                f,
                "Rust",
                0,
                y - 0.1,
                0,
                rng.uniform(0.15, 0.4),
                d + 0.03,
                _tone(RUST, rng, 8),
                "CorrodedMetal",
                transparency=0.15,
            )
        g = f.sub((0, 0, 0), ry=rng.uniform(-60, 60))
        _skin(
            g,
            "Rust",
            (0, H * rng.uniform(0.2, 0.7), -d / 2 + 0.1),
            rng.uniform(0.35, 0.5),
            rng.uniform(0.4, 0.8),
            "-z",
            _tone(_pick(rng, [RUST, RUST_DARK]), rng, 6),
            "CorrodedMetal",
            th=0.03,
        )
    else:
        # the jagged cut top, the punched holes glowing, soot, ash, embers
        for i in range(5):
            a = i * 72 + rng.uniform(-15, 15)
            g = f.sub((0, H - 0.05, 0), ry=a)
            g.part(
                "CutEdge",
                (0, rng.uniform(-0.04, 0.12), -d / 2 + 0.05),
                (rng.uniform(0.5, 0.9), 0.2, 0.06),
                _tone(RUST_DARK, rng, 5),
                "CorrodedMetal",
                rot=(rng.uniform(-25, 10), 0, rng.uniform(-15, 15)),
            )
        for i in range(rng.randint(3, 5)):
            a = rng.uniform(0, 360)
            g = f.sub((0, rng.uniform(0.35, 0.8), 0), ry=a)
            glow = i < 2
            g.part(
                "BarrelHole",
                (0, 0, -d / 2 + 0.02),
                (0.22, 0.2, 0.08),
                NEON_FIRE if glow else SOOT,
                "Neon" if glow else "SmoothPlastic",
            )
        _vcyl(f, "Soot", 0, H - 0.75, 0, 0.7, d + 0.03, SOOT, "SmoothPlastic", transparency=0.25)
        _disk(
            f,
            "Ash",
            rng.uniform(-0.3, 0.3),
            rng.uniform(-0.3, 0.3),
            d + rng.uniform(1.0, 1.8),
            0.04,
            ASH,
            "Slate",
            transparency=0.3,
        )
        ex = {"t": ["CityFireEmbers"], "fx": "fire"}
        if light:
            ex["l"] = {
                "type": "Point",
                "color": [255, 130, 50],
                "range": 18,
                "brightness": 1.6,
                "name": "Light",
                "shadows": False,
            }
        _cyl(f, "Embers", (0, H - 0.35, 0), 0.15, d - 0.2, NEON_FIRE, "Neon", rot=(0, 0, 90), extra=ex)


# =============================================================================================
# Crates
# =============================================================================================
def _wood_crate(f, rng, w, h, d, col, lid="on", broken=False, flags=PROP):
    """One slatted crate in frame f, standing on y=0: a dark core (the gaps between boards read as
    shadow), two boards a side on all four sides, corner battens, three lid boards (or the lid
    gone / one board askew), a stencil on the front, maybe a split board."""
    t = 0.1
    core_top = h - 0.05 if lid == "on" else h * 0.5  # an open crate shows its depth
    f.box(
        "CrateCore", (-w / 2 + t, 0.02, -d / 2 + t), (w / 2 - t, core_top, d / 2 - t), (26, 22, 18), "Wood", flags=flags
    )
    gap = 0.08
    bh = (h - gap * 2) / 2
    split = rng.randrange(8) if broken else -1
    k = 0
    for i in range(2):
        y0 = gap / 2 + i * (bh + gap)
        for s in (-1, 1):  # front/back boards (along X) and side boards (along Z)
            c = _tone(col, rng, 8)
            if k == split:
                f.part(
                    "CrateBoard",
                    (s * 0.0 + rng.uniform(-0.2, 0.2), y0 + bh / 2, s * (d / 2 - t / 2)),
                    (w * 0.55, bh, t),
                    c,
                    "WoodPlanks",
                    rot=(0, 0, rng.uniform(-14, 14)),
                )
            else:
                f.box(
                    "CrateBoard",
                    (-w / 2 + 0.02, y0, s * (d / 2 - t / 2) - t / 2),
                    (w / 2 - 0.02, y0 + bh, s * (d / 2 - t / 2) + t / 2),
                    c,
                    "WoodPlanks",
                )
            k += 1
            c = _tone(col, rng, 8)
            f.box(
                "CrateBoard",
                (s * (w / 2 - t / 2) - t / 2, y0, -d / 2 + 0.02),
                (s * (w / 2 - t / 2) + t / 2, y0 + bh, d / 2 - 0.02),
                c,
                "WoodPlanks",
            )
            k += 1
    for sx in (-1, 1):
        for sz in (-1, 1):
            if sz > 0 and rng.random() < 0.5:
                continue  # the back battens are often hidden
            x, z = sx * (w / 2 + 0.01), sz * (d / 2 + 0.01)
            f.box("CrateBatten", (x - 0.09, 0, z - 0.09), (x + 0.09, h, z + 0.09), _tone(col, rng, 6, 0.12), "Wood")
    if lid != "off":
        nb = 3
        bw = (w - 0.1) / nb
        askew = rng.randrange(nb) if lid == "loose" else -1
        for i in range(nb):
            x = -w / 2 + 0.05 + bw * (i + 0.5)
            if i == askew:
                f.part(
                    "CrateLid",
                    (x + rng.uniform(0.2, 0.5), h + 0.12, rng.uniform(-0.3, 0.3)),
                    (bw - 0.06, 0.1, d + 0.1),
                    _tone(col, rng, 8, 0.05),
                    "WoodPlanks",
                    rot=(rng.uniform(-6, 6), rng.uniform(-25, 25), rng.uniform(4, 12)),
                )
            else:
                f.box(
                    "CrateLid",
                    (x - bw / 2 + 0.03, h - 0.05, -d / 2),
                    (x + bw / 2 - 0.03, h + 0.05, d / 2),
                    _tone(col, rng, 8, 0.05),
                    "WoodPlanks",
                )
    if rng.random() < 0.7:  # a stencilled mark: a couple of strokes in faded black paint
        sx, sy = rng.uniform(-0.2, 0.2) * w, h * rng.uniform(0.6, 0.75)
        for k in range(2):
            _skin(
                f,
                "Stencil",
                (sx + k * w * 0.16, sy, -d / 2),
                w * rng.uniform(0.1, 0.22),
                h * 0.12,
                "-z",
                mix(col, (30, 26, 22), 0.75),
                th=0.02,
                spin=rng.uniform(-2, 2),
            )


@prop({"count": 1}, {"count": 2}, {"count": 3}, {"count": 3, "wet": True})
def wooden_crates(D, folder, origin, ry, rng, count=None, wet=None):
    """Wooden shipping crates made of boards: one, two side by side, or three (two on the ground,
    one on top turned askew); lids on, loose (a board knocked sideways) or gone, a split board,
    stencils, the wood greyed by weather (`wet`: dark and damp at the bottom).
    Footprint ~2.4 x 2.2 studs each (3: ~5 x 2.6), 2-2.5 tall a crate (stacked 4.5). 11-56 parts;
    each crate's core PROP (climbable)."""
    f = Frame(D, folder, origin, ry=ry)
    count = count or rng.randint(1, 3)
    wet = (rng.random() < 0.3) if wet is None else wet
    base = _tone(_pick(rng, CRATE_WOOD), rng, 6, darken=rng.uniform(0.1, 0.3))
    if wet:
        base = mix(base, (50, 44, 36), 0.4)
    spots = [(0, 0, 0)] if count == 1 else [(-1.3, 0, 0), (1.3, 0, rng.uniform(-0.3, 0.3))]
    sizes = []
    for i in range(min(count, 2)):
        w, h, d = rng.uniform(2.2, 2.6), rng.uniform(1.9, 2.4), rng.uniform(2.0, 2.3)
        sizes.append(h)
        x, _, z = spots[i]
        g = f.sub((x, 0, z), ry=rng.uniform(-8, 8))
        _wood_crate(
            g,
            rng,
            w,
            h,
            d,
            _tone(base, rng, 6),
            lid=_pick(rng, ["on", "on", "loose", "off"]),
            broken=rng.random() < 0.3,
        )
    if count >= 3:
        g = f.sub(
            (rng.uniform(-0.6, 0.6), min(sizes) + 0.1, rng.uniform(-0.2, 0.2)),
            ry=rng.uniform(-25, 25),
            rz=rng.uniform(-2, 2),
        )
        _wood_crate(
            g,
            rng,
            rng.uniform(2.0, 2.4),
            rng.uniform(1.8, 2.1),
            rng.uniform(1.9, 2.2),
            _tone(base, rng, 6),
            lid=_pick(rng, ["on", "loose"]),
        )
    if wet:
        _grime(f, -2.6 if count > 1 else -1.3, 2.6 if count > 1 else 1.3, 0.0, 0.5, -1.25, "-z", base, rng)


def _plastic_crate(f, rng, col, w, d, h):
    """A stackable plastic produce crate: base, four walls, the hand holes in the short ends."""
    t = 0.08
    f.box("PlasticCrate", (-w / 2, 0, -d / 2), (w / 2, 0.08, d / 2), _tone(col, rng, 4, 0.1), "Plastic", flags=SMALL)
    for s in (-1, 1):
        f.box(
            "PlasticCrate",
            (-w / 2, 0, s * d / 2 - t / 2),
            (w / 2, h, s * d / 2 + t / 2),
            _tone(col, rng, 4),
            "Plastic",
            flags=SMALL,
        )
        f.box(
            "PlasticCrate",
            (s * w / 2 - t / 2, 0, -d / 2),
            (s * w / 2 + t / 2, h, d / 2),
            _tone(col, rng, 4),
            "Plastic",
            flags=SMALL,
        )
        f.box("HandHole", (s * w / 2 - 0.06, h - 0.32, -0.3), (s * w / 2 + 0.06, h - 0.14, 0.3), SOOT, "SmoothPlastic")
    f.box(
        "CrateVent",
        (-w * 0.35, h * 0.3, -d / 2 - 0.05),
        (w * 0.35, h * 0.5, -d / 2 + 0.01),
        SOOT,
        "SmoothPlastic",
        transparency=0.2,
    )


@prop({"count": 2}, {"count": 4}, {"count": 6})
def plastic_crates(D, folder, origin, ry, rng, count=None, color=None):
    """Stackable plastic produce crates, sun-faded and scuffed: a leaning stack (each crate turned a
    little on the one below, the colours mismatched), one dropped on its side next to it.
    Footprint 2.2 x 1.5 studs (+ the dropped one ~2.4 to the side), 0.9 a crate. 16-48 parts;
    crate walls SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    count = count or rng.randint(2, 6)
    base = color or _pick(rng, PLASTIC_CRATE)
    w, d, h = 2.2, 1.5, 0.85
    stack = count - (1 if count >= 3 and rng.random() < 0.7 else 0)
    y = 0.0
    lean = rng.uniform(-1.5, 1.5)
    for i in range(stack):
        col = _tone(base if rng.random() < 0.75 else _pick(rng, PLASTIC_CRATE), rng, 8, darken=rng.uniform(0.05, 0.3))
        g = f.sub(
            (rng.uniform(-0.08, 0.08) + i * lean * 0.03, y, rng.uniform(-0.08, 0.08)),
            ry=rng.uniform(-6, 6),
            rz=lean * 0.4,
        )
        _plastic_crate(g, rng, col, w, d, h)
        y += h - 0.12
    if stack < count:
        g = f.sub(
            (rng.choice((-1, 1)) * rng.uniform(2.3, 2.6), d / 2, rng.uniform(-0.6, 0.4)), ry=rng.uniform(-40, 40), rx=90
        )
        _plastic_crate(g, rng, _tone(base, rng, 8, 0.2), w, d, h)


# =============================================================================================
# The black market: tables, the canopy, the goods (NOTHING bottle-like)
# =============================================================================================
@prop({}, {"cloth": True}, {"kind": "wood"}, {"kind": "wood", "cloth": True})
def folding_table(D, folder, origin, ry, rng, kind=None, cloth=None, w=None):
    """A folding trestle table: a scuffed plastic top on a steel frame (two pairs of tube legs with
    their foot bars, the under-frame, a folding brace) or an old door / board laid on two
    sawhorse trestles (`kind="wood"`); `cloth`: a stained sheet thrown over it hanging down the
    front. The goods go on its top (top_y = 2.45). Footprint 5-6.4 x 2.6 studs, 2.45 tall.
    12-17 parts; the top PROP."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["plastic", "plastic", "wood"])
    cloth = (rng.random() < 0.4) if cloth is None else cloth
    W = w or rng.uniform(5.0, 6.4)
    Dp, H = rng.uniform(2.4, 2.8), 2.45
    sag = rng.uniform(0.5, 1.5)
    if kind == "plastic":
        top = _tone((150, 148, 140), rng, 10, darken=rng.uniform(0.1, 0.35))
        g = f.sub((0, H, 0), rz=rng.uniform(-0.8, 0.8))
        for s in (-1, 1):  # the top folds in the middle: two halves, sagging a touch
            g.box(
                "TableTop",
                (0 if s > 0 else -W / 2, -0.14, -Dp / 2),
                (W / 2 if s > 0 else 0, 0, Dp / 2),
                _tone(top, rng, 4),
                "Plastic",
                flags=PROP,
                rot=(0, 0, -s * sag),
            )
        g.box("TableFrame", (-W / 2 + 0.2, -0.3, -Dp / 2 + 0.12), (W / 2 - 0.2, -0.16, -Dp / 2 + 0.22), IRON, "Metal")
        g.box("TableFrame", (-W / 2 + 0.2, -0.3, Dp / 2 - 0.22), (W / 2 - 0.2, -0.16, Dp / 2 - 0.12), IRON, "Metal")
        legc = _tone(GALVANISED, rng, 8, darken=rng.uniform(0.2, 0.4))
        for s in (-1, 1):
            x = s * (W / 2 - 0.5)
            for u in (-1, 1):
                _rod(
                    f,
                    "TableLeg",
                    (x + s * 0.15, 0, u * (Dp / 2 - 0.25)),
                    (x, H - 0.25, u * (Dp / 2 - 0.25)),
                    0.12,
                    legc,
                    "Metal",
                )
            _rod(
                f,
                "TableFoot",
                (x + s * 0.15, 0.08, -(Dp / 2 - 0.25)),
                (x + s * 0.15, 0.08, Dp / 2 - 0.25),
                0.12,
                legc,
                "Metal",
            )
            _rod(f, "TableBrace", (x, H * 0.6, 0), (x * 0.3, H - 0.3, 0), 0.08, legc, "Metal")
        for _ in range(2):  # scuffs and a burn on the top
            _skin(
                f,
                "Stain",
                (rng.uniform(-W / 3, W / 3), H, rng.uniform(-Dp / 4, Dp / 4)),
                rng.uniform(0.5, 1.2),
                rng.uniform(0.3, 0.7),
                "y",
                _tone(_pick(rng, STAIN), rng, 6),
                th=0.02,
                transparency=0.4,
                spin=rng.uniform(0, 180),
            )
    else:
        top = _tone(_pick(rng, [WOOD_OLD, WOOD_GREY, (110, 84, 60)]), rng, 6, darken=rng.uniform(0, 0.25))
        f.box(
            "TableTop",
            (-W / 2, H - 0.16, -Dp / 2),
            (W / 2, H, Dp / 2),
            top,
            "Wood",
            flags=PROP,
            rot=(0, rng.uniform(-2, 2), rng.uniform(-0.6, 0.6)),
        )
        _skin(
            f,
            "DoorPanel",
            (rng.uniform(-0.4, 0.4), H, 0),
            W * 0.38,
            Dp * 0.6,
            "y",
            _tone(top, rng, 4, 0.12),
            "Wood",
            th=0.04,
        )
        legc = _tone(WOOD, rng, 6, darken=rng.uniform(0.1, 0.3))
        for s in (-1, 1):  # the sawhorses
            x = s * (W / 2 - 0.9)
            f.box("Trestle", (x - 0.12, H - 0.42, -Dp / 2 + 0.1), (x + 0.12, H - 0.16, Dp / 2 - 0.1), legc, "Wood")
            for u in (-1, 1):
                for v in (-1, 1):
                    _bar(
                        f,
                        "TrestleLeg",
                        (x + v * 0.45, 0, u * (Dp / 2 - 0.05)),
                        (x, H - 0.3, u * (Dp / 2 - 0.3)),
                        0.16,
                        0.14,
                        _tone(legc, rng, 5),
                        "Wood",
                    )
    if cloth:
        cc = _tone(_pick(rng, FABRIC + [(120, 110, 96)]), rng, 6, darken=rng.uniform(0, 0.2))
        f.box("TableCloth", (-W / 2 - 0.05, H, -Dp / 2 - 0.05), (W / 2 + 0.05, H + 0.04, Dp / 2 + 0.05), cc, "Fabric")
        hang = rng.uniform(1.2, 2.0)
        f.part(
            "TableCloth",
            (rng.uniform(-0.2, 0.2), H - hang / 2, -Dp / 2 - 0.08),
            (W * rng.uniform(0.85, 1.0), hang, 0.04),
            _tone(cc, rng, 4),
            "Fabric",
            rot=(rng.uniform(-6, -2), 0, rng.uniform(-2, 2)),
        )
        _skin(
            f,
            "Stain",
            (rng.uniform(-W / 3, W / 3), H + 0.04, rng.uniform(-0.6, 0.6)),
            rng.uniform(0.6, 1.1),
            0.7,
            "y",
            _tone(_pick(rng, STAIN), rng, 6),
            th=0.02,
            transparency=0.4,
            spin=rng.uniform(0, 180),
        )


@prop({}, {"w": 10, "d": 7}, {"light": False, "torn": True})
def market_canopy(D, folder, origin, ry, rng, w=None, d=None, light=True, torn=None, color=None):
    """A makeshift stall canopy: a tarp stretched over four mismatched poles (scaffold tube, a
    length of timber, conduit) footed in cinder blocks and a bucket of concrete, higher at the
    front, sagging in the middle where rain pools (a dark, wet patch), its front edge hanging in
    ragged flaps, guy ropes to pegs at the front corners, patches of tape, maybe a torn hole; a
    bare bulb hanging under it on its flex (`light`: a weak warm PointLight).
    Footprint w x d (default ~8 x 6) studs + 1.5 for the ropes, 6.5-7.8 tall. 24-29 parts;
    poles SMALL, the tarp DECOR_SHADOW (too high to touch)."""
    f = Frame(D, folder, origin, ry=ry)
    W = w or rng.uniform(7.5, 9)
    Dp = d or rng.uniform(5.5, 6.5)
    torn = (rng.random() < 0.4) if torn is None else torn
    hf, hb = rng.uniform(7.2, 7.8), rng.uniform(6.4, 6.9)
    tc = _tone(color or _pick(rng, TARP), rng, 6, darken=rng.uniform(0.1, 0.35))
    corners = {}
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * W / 2 + rng.uniform(-0.15, 0.15), sz * Dp / 2 + rng.uniform(-0.15, 0.15)
            h = (hf if sz < 0 else hb) + rng.uniform(-0.15, 0.15)
            corners[(sx, sz)] = (x, h, z)
            kind = rng.randrange(3)
            lean = (x + rng.uniform(-0.25, 0.25), 0, z + rng.uniform(-0.25, 0.25))
            if kind == 0:
                _rod(f, "CanopyPole", lean, (x, h, z), 0.2, _tone(GALVANISED, rng, 8, 0.3), "Metal", flags=SMALL)
            elif kind == 1:
                _bar(f, "CanopyPole", lean, (x, h, z), 0.28, 0.28, _tone(WOOD_OLD, rng, 6), "Wood", flags=SMALL)
            else:
                _rod(
                    f, "CanopyPole", lean, (x, h, z), 0.14, _tone((150, 150, 146), rng, 8, 0.3), "Plastic", flags=SMALL
                )
            if rng.random() < 0.6:
                f.box(
                    "PoleFoot",
                    (lean[0] - 0.5, 0, lean[2] - 0.35),
                    (lean[0] + 0.5, 0.65, lean[2] + 0.35),
                    _tone(CONCRETE, rng, 8, 0.1),
                    "Concrete",
                    flags=SMALL,
                    rot=(0, rng.uniform(-30, 30), 0),
                )
            else:
                _vcyl(
                    f,
                    "PoleFoot",
                    lean[0],
                    0,
                    lean[2],
                    0.9,
                    0.8,
                    _tone(_pick(rng, [(60, 60, 62), (130, 90, 40)]), rng, 6),
                    "Plastic",
                    flags=SMALL,
                )
    # the tarp: four strips across the width, following a sag curve, sloping back
    n = 4
    sag = rng.uniform(0.6, 1.0)
    xs = [-W / 2 - 0.2 + (W + 0.4) * i / n for i in range(n + 1)]
    hs = [-sag * (1 - (2 * i / n - 1) ** 2) for i in range(n + 1)]
    pitch = math.degrees(math.atan2(hf - hb, Dp))
    ymid = (hf + hb) / 2 + 0.12
    for i in range(n):
        x0, x1, h0, h1 = xs[i], xs[i + 1], hs[i], hs[i + 1]
        roll = math.degrees(math.atan2(h1 - h0, x1 - x0))
        f.part(
            "Tarp",
            ((x0 + x1) / 2, ymid + (h0 + h1) / 2, 0),
            (math.hypot(x1 - x0, h1 - h0) + 0.05, 0.06, Dp + 0.6),
            _tone(tc, rng, 4),
            "Plastic",
            rot=(pitch, 0, roll),
            flags=DECOR_SHADOW,
        )
    Wt = W + 0.4

    def tarp_y(x, z):  # the tarp's top surface height at (x, z)
        return ymid + 0.04 - sag * max(0.0, 1 - (2 * x / Wt) ** 2) - z * math.tan(math.radians(pitch))

    px, pz = rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6)
    f.part(
        "TarpPool",
        (px, tarp_y(px, pz), pz),
        (rng.uniform(1.4, 2.2), 0.04, rng.uniform(1.2, 2.0)),
        mix(tc, (10, 12, 14), 0.6),
        "SmoothPlastic",
        rot=(pitch, rng.uniform(-20, 20), 0),
        reflectance=0.15,
    )
    # the ragged front valance
    xf = -W / 2
    while xf < W / 2 - 0.3:
        fw = rng.uniform(1.0, 2.2)
        hang = rng.uniform(0.3, 1.1)
        xc = min(xf + fw / 2, W / 2 - fw / 2)
        hc = -sag * (1 - (2 * (xc + W / 2) / W - 1) ** 2)
        f.part(
            "TarpFlap",
            (xc, hf + 0.1 + hc - hang / 2, -Dp / 2 - 0.32),
            (fw, hang, 0.05),
            _tone(tc, rng, 5),
            "Plastic",
            rot=(rng.uniform(-8, 8), 0, rng.uniform(-6, 6)),
            flags=DECOR,
        )
        xf += fw + rng.uniform(0.1, 0.4)
    for _ in range(rng.randint(1, 2)):
        x, z = rng.uniform(-W / 3, W / 3), rng.uniform(-Dp / 3, Dp / 3)
        f.part(
            "TarpTape",
            (x, tarp_y(x, z), z),
            (rng.uniform(0.6, 1.2), 0.03, 0.22),
            _tone(DUCT, rng, 8),
            "Fabric",
            rot=(pitch, rng.uniform(0, 180), 0),
        )
    if torn:
        x, z = rng.choice((-1, 1)) * W * 0.3, rng.uniform(-1, 1)
        f.part(
            "TarpHole",
            (x, tarp_y(x, z) - 0.04, z),
            (rng.uniform(0.6, 1.0), 0.1, rng.uniform(0.4, 0.8)),
            (10, 10, 12),
            "SmoothPlastic",
            rot=(pitch, rng.uniform(0, 90), 0),
        )
    # guy ropes to pegs at the front corners
    for sx in (-1, 1):
        x, h, z = corners[(sx, -1)]
        peg = (x + sx * rng.uniform(0.6, 1.2), 0.15, z - rng.uniform(1.0, 1.6))
        _rod(f, "GuyRope", (x, h - 0.1, z), peg, 0.06, _tone((120, 110, 90), rng, 8), "Fabric")
        _vcyl(f, "Peg", peg[0], 0, peg[2], 0.3, 0.12, IRON, "Metal")
    # the bulb on its flex
    bx, bz = rng.uniform(-1, 1), rng.uniform(-0.8, 0.8)
    drop = rng.uniform(1.0, 1.6)
    ytop = tarp_y(bx, bz) - 0.08
    _rod(f, "Flex", (bx, ytop, bz), (bx, ytop - drop, bz), 0.05, (20, 20, 20), "Rubber")
    ex = (
        {
            "l": {
                "type": "Point",
                "color": [255, 186, 120],
                "range": 14,
                "brightness": 0.9,
                "name": "Light",
                "shadows": True,
            }
        }
        if light
        else None
    )
    _ball(f, "Bulb", (bx, ytop - drop - 0.15, bz), 0.32, (255, 214, 160), "Neon", extra=ex)


def _box_tray(f, rng, w, d, h, col, name="Tray"):
    """An open cardboard tray: base and four low walls (one flap folded out)."""
    t = 0.06
    f.box(name, (-w / 2, 0, -d / 2), (w / 2, 0.05, d / 2), _tone(col, rng, 6, 0.1), CARDBOARD_MAT)
    for s in (-1, 1):
        f.box(name, (-w / 2, 0, s * d / 2 - t / 2), (w / 2, h, s * d / 2 + t / 2), _tone(col, rng, 6), CARDBOARD_MAT)
        f.box(name, (s * w / 2 - t / 2, 0, -d / 2), (s * w / 2 + t / 2, h, d / 2), _tone(col, rng, 6), CARDBOARD_MAT)
    f.part(
        name + "Flap",
        (0, h + 0.02, -d / 2 - 0.18),
        (w * 0.9, 0.04, 0.4),
        _tone(col, rng, 6, 0.05),
        CARDBOARD_MAT,
        rot=(rng.uniform(-30, -10), 0, rng.uniform(-3, 3)),
    )


@prop({}, {"count": 8})
def phone_tray(D, folder, origin, ry, rng, count=None):
    """A cardboard tray of second-hand (stolen) phones laid out on a table: slabs of dark glass and
    grey/black/gold backs, some face up with a cracked screen (a pale line across), one in a
    bright case, a tangle of charger cable. Footprint 1.8 x 1.3 studs, 0.35 tall. 12-17 parts,
    DECOR. Origin = the table top."""
    f = Frame(D, folder, origin, ry=ry)
    count = count or rng.randint(5, 7)
    w, d = 1.8, 1.3
    _box_tray(f, rng, w, d, 0.28, _tone(CARDBOARD, rng, 8, 0.1))
    for i in range(count):
        cx, cz = -w / 2 + 0.25 + (i % 4) * 0.42, -d / 4 + (i // 4) * 0.55
        g = f.sub(
            (cx + rng.uniform(-0.04, 0.04), 0.08 + rng.uniform(0, 0.04), cz),
            ry=rng.uniform(-15, 15),
            rz=rng.uniform(-6, 6),
        )
        up = rng.random() < 0.6
        back = _pick(rng, [(30, 30, 32), (120, 122, 124), (150, 130, 96), (40, 60, 90), (150, 50, 50)])
        g.box(
            "Phone",
            (-0.15, 0, -0.3),
            (0.15, 0.05, 0.3),
            SCREEN if up else back,
            "Glass" if up else "SmoothPlastic",
            reflectance=0.2 if up else 0.05,
        )
        if up and rng.random() < 0.5 and i < 2:
            g.part(
                "Crack",
                (0, 0.055, 0),
                (0.02, 0.01, 0.5),
                (150, 156, 160),
                "SmoothPlastic",
                rot=(0, rng.uniform(-40, 40), 0),
            )
    _rod(
        f,
        "Cable",
        (-w / 2 + 0.1, 0.12, d / 2 - 0.2),
        (w / 2 - 0.3, 0.15, d / 2 - 0.25),
        0.03,
        (34, 34, 36),
        "SmoothPlastic",
    )


@prop({}, {"open": False})
def watch_case(D, folder, origin, ry, rng, open=True, count=None):
    """A battered aluminium attache case of watches: the shell with its edge trims and catches, the
    lid thrown back, worn red felt lining, two rows of watches (a steel or gold case with a dial and
    a strap), one strap hanging over the edge. Footprint 2 x 1.4 studs (lid open: + 1.4 behind),
    0.4 tall (open 1.6). 6-20 parts, DECOR. Origin = the table top."""
    f = Frame(D, folder, origin, ry=ry)
    count = count or rng.randint(4, 6)
    w, d, h = 2.0, 1.4, 0.36
    shell = _tone((140, 140, 136), rng, 10, darken=rng.uniform(0.15, 0.35))
    f.box("WatchCase", (-w / 2, 0, -d / 2), (w / 2, h, d / 2), shell, "Metal")
    f.box(
        "CaseTrim",
        (-w / 2 - 0.03, h - 0.06, -d / 2 - 0.03),
        (w / 2 + 0.03, h, d / 2 + 0.03),
        _tone(shell, rng, 4, 0.2),
        "Metal",
    )
    for s in (-1, 1):
        f.box(
            "CaseCatch", (s * w / 3 - 0.1, h - 0.18, -d / 2 - 0.06), (s * w / 3 + 0.1, h - 0.02, -d / 2), IRON, "Metal"
        )
    if not open:
        f.box("CaseLid", (-w / 2, h, -d / 2), (w / 2, h + 0.1, d / 2), shell, "Metal")
        _skin(
            f,
            "Scuff",
            (rng.uniform(-0.4, 0.4), h + 0.1, 0),
            0.6,
            0.08,
            "y",
            mix(shell, (200, 200, 196), 0.4),
            th=0.02,
            spin=rng.uniform(0, 180),
        )
        return
    felt = _tone((96, 30, 34), rng, 8, darken=rng.uniform(0.1, 0.3))
    f.box("CaseFelt", (-w / 2 + 0.06, h - 0.1, -d / 2 + 0.06), (w / 2 - 0.06, h - 0.04, d / 2 - 0.06), felt, "Fabric")
    g = f.sub((0, h, d / 2), rx=rng.uniform(95, 110))
    g.box("CaseLid", (-w / 2, 0, -d), (w / 2, 0.1, 0), shell, "Metal")
    g.box("CaseFelt", (-w / 2 + 0.06, -0.03, -d + 0.06), (w / 2 - 0.06, 0.0, -0.06), _tone(felt, rng, 4, 0.1), "Fabric")
    for i in range(count):
        x, z = -w / 2 + 0.3 + (i % 3) * 0.7, -0.3 + (i // 3) * 0.6
        gold = rng.random() < 0.35
        cc = (170, 140, 70) if gold else _tone(STEEL, rng, 10)
        _disk(f, "WatchFace", x, z, 0.3, 0.07, cc, "Metal", y=h - 0.04, reflectance=0.2)
        f.box(
            "WatchStrap",
            (x - 0.06, h - 0.05, z - 0.27),
            (x + 0.06, h - 0.02, z + 0.27),
            _pick(rng, [(30, 26, 22), (70, 46, 30), cc]),
            "Leather",
        )
    _bar(
        f,
        "WatchStrap",
        (-w / 2 + 0.3, h, -d / 2 + 0.1),
        (-w / 2 + 0.35, h - 0.35, -d / 2 - 0.05),
        0.12,
        0.03,
        (40, 30, 24),
        "Leather",
    )


@prop({}, {"count": 6}, {"count": 3, "open": True})
def shoe_boxes(D, folder, origin, ry, rng, count=None, open=None):
    """Sneaker boxes, the knock-off kind: a stack and a couple beside it, each box with its lid in
    another colour and a white label at the end, corners crushed; one open with a sneaker in it
    (sole, upper, toe cap, a lighter swoosh-less side panel). Footprint ~2.4 x 1.2 studs, up to
    2.2 tall. 6-23 parts; DECOR_SHADOW (the floor stack's bottom box SMALL)."""
    f = Frame(D, folder, origin, ry=ry)
    count = count or rng.randint(3, 6)
    open = (rng.random() < 0.6) if open is None else open
    bw, bh, bd = 1.1, 0.45, 0.7
    stack = max(1, count - rng.randint(1, 2)) if count > 2 else count
    y = 0.0
    for i in range(count):
        if i < stack:
            x, z, yy = -0.6 + rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05), y
            y += bh
            yaw = rng.uniform(-8, 8)
        else:
            x, z, yy = 0.75 + (i - stack) * 0.05, -0.05 + (i - stack) * 0.05, (i - stack) * bh
            yaw = rng.uniform(-15, 15) + 90 * ((i - stack) % 2)
        g = f.sub((x, yy, z), ry=yaw)
        col = mix(_tone(_pick(rng, SHOEBOX), rng, 8, darken=rng.uniform(0.25, 0.45)), CARDBOARD_DARK, 0.2)
        is_open = open and i == count - 1
        g.box(
            "ShoeBox",
            (-bw / 2, 0, -bd / 2),
            (bw / 2, bh - 0.08, bd / 2),
            col,
            CARDBOARD_MAT,
            flags=SMALL if (i == 0) else DECOR_SHADOW,
        )
        lc = mix(_tone(_pick(rng, SHOEBOX), rng, 8, darken=0.3), CARDBOARD_DARK, 0.15)
        if is_open:
            g.part(
                "ShoeBoxLid",
                (0, bh / 2, bd / 2 + 0.12),
                (bw + 0.04, 0.06, bd + 0.04),
                lc,
                CARDBOARD_MAT,
                rot=(rng.uniform(70, 85), 0, 0),
            )
            g.box(
                "ShoeBoxInside",
                (-bw / 2 + 0.04, bh - 0.12, -bd / 2 + 0.04),
                (bw / 2 - 0.04, bh - 0.08, bd / 2 - 0.04),
                (190, 188, 180),
                "Fabric",
            )
            sc = _pick(rng, [(200, 198, 192), (40, 40, 44), (150, 40, 40)])
            g.box("Sole", (-0.42, bh - 0.12, -0.2), (0.42, bh - 0.02, 0.06), (220, 218, 210), "Rubber")
            g.box("Sneaker", (-0.38, bh - 0.02, -0.18), (0.2, bh + 0.2, 0.04), sc, "Leather")
            g.part("SneakerToe", (0.27, bh + 0.04, -0.07), (0.3, 0.14, 0.22), sc, "Leather", rot=(0, 0, -15))
            g.box(
                "SneakerPanel",
                (-0.3, bh + 0.04, -0.19),
                (0.1, bh + 0.14, -0.18),
                mix(sc, (120, 120, 120), 0.5),
                "Leather",
            )
        else:
            g.box(
                "ShoeBoxLid",
                (-bw / 2 - 0.02, bh - 0.1, -bd / 2 - 0.02),
                (bw / 2 + 0.02, bh, bd / 2 + 0.02),
                lc,
                CARDBOARD_MAT,
            )
        if rng.random() < 0.6:
            _skin(g, "Label", (bw / 2, bh * 0.45, 0), 0.4, 0.2, "+x", (200, 198, 190), th=0.02)


@prop({}, {"count": 3})
def car_stereos(D, folder, origin, ry, rng, count=None):
    """Car stereos ripped out of dashboards: double-DIN units (a black chassis, the face plate with
    a dead display and a knob), their cut wiring looms trailing in coloured wires, one face down.
    Footprint ~1.8 x 1.2 studs, 0.4-0.9 tall. 10-16 parts, DECOR. Origin = the table top."""
    f = Frame(D, folder, origin, ry=ry)
    count = count or rng.randint(2, 3)
    for i in range(count):
        g = f.sub((-0.6 + i * 0.6 + rng.uniform(-0.1, 0.1), 0, rng.uniform(-0.2, 0.2)), ry=rng.uniform(-25, 25))
        if i == 2:
            g = g.sub((0, 0.2, 0), rx=-90)
        g.box("CarStereo", (-0.28, 0, -0.35), (0.28, 0.4, 0.3), _tone((36, 36, 38), rng, 4), "Metal")
        g.box("StereoFace", (-0.3, -0.02, -0.4), (0.3, 0.42, -0.35), _tone((24, 24, 26), rng, 3), "SmoothPlastic")
        g.box("StereoDisplay", (-0.2, 0.22, -0.42), (0.16, 0.34, -0.39), (40, 56, 60), "Glass", reflectance=0.15)
        _cyl(g, "StereoKnob", (0.2, 0.12, -0.44), 0.08, 0.12, (90, 90, 92), "Metal", rot=(0, 90, 0))
        if i < 2:
            for k in range(rng.randint(0, 1) + 1):
                _rod(
                    g,
                    "Wire",
                    (0.1 - k * 0.15, 0.15, 0.3),
                    (0.2 - k * 0.3 + rng.uniform(-0.2, 0.2), 0.03, 0.7 + rng.uniform(0, 0.3)),
                    0.04,
                    _pick(rng, [(150, 40, 30), (180, 160, 40), (30, 30, 30), (40, 80, 150)]),
                    "Plastic",
                )


@prop({}, {"color": (120, 120, 124)})
def radio(D, folder, origin, ry, rng, color=None):
    """An 80s boombox: the body with its rounded top edge, two speaker grilles (a dark cone in a
    silver ring), the cassette door between them, the tuning strip, a carry handle on two posts,
    a telescopic aerial pulled half out and bent; scuffed, the handle taped. Footprint 2 x 0.7
    studs, 1.1 tall (aerial to 2). 14-14 parts, DECOR. Origin = the table top / floor."""
    f = Frame(D, folder, origin, ry=ry)
    col = _tone(
        color or _pick(rng, [(40, 40, 42), (120, 120, 124), (70, 70, 74)]), rng, 6, darken=rng.uniform(0.05, 0.25)
    )
    w, h, d = 2.0, 1.0, 0.65
    f.box("Boombox", (-w / 2, 0, -d / 2), (w / 2, h - 0.12, d / 2), col, "SmoothPlastic", flags=DECOR_SHADOW)
    _cyl(f, "Boombox", (0, h - 0.14, 0), w - 0.02, 0.26, col, "SmoothPlastic", rot=(0, 0, 0))
    for s in (-1, 1):
        _cyl(f, "SpeakerRing", (s * 0.62, 0.45, -d / 2 - 0.02), 0.05, 0.66, (150, 150, 148), "Metal", rot=(0, 90, 0))
        _cyl(f, "SpeakerGrille", (s * 0.62, 0.45, -d / 2 - 0.04), 0.04, 0.56, (24, 24, 26), "Fabric", rot=(0, 90, 0))
        f.box("HandlePost", (s * 0.55 - 0.05, h, -0.05), (s * 0.55 + 0.05, h + 0.25, 0.05), IRON, "Metal")
    f.box(
        "CassetteDoor",
        (-0.24, 0.22, -d / 2 - 0.03),
        (0.24, 0.6, -d / 2),
        _tone((30, 30, 32), rng, 3),
        "Glass",
        reflectance=0.1,
    )
    f.box("TunerStrip", (-0.8, h - 0.32, -d / 2 - 0.03), (0.8, h - 0.22, -d / 2), (150, 140, 110), "SmoothPlastic")
    f.box("BoomboxHandle", (-0.62, h + 0.22, -0.07), (0.62, h + 0.34, 0.07), IRON, "Metal")
    f.box("HandleTape", (-0.15, h + 0.2, -0.09), (0.15, h + 0.36, 0.09), _tone(DUCT, rng, 6), "Fabric")
    _rod(
        f,
        "Aerial",
        (w / 2 - 0.15, h, 0.2),
        (w / 2 + 0.1 + rng.uniform(0, 0.3), h + rng.uniform(0.7, 1.0), 0.35),
        0.03,
        (180, 180, 178),
        "Metal",
    )
    _skin(
        f,
        "Scuff",
        (rng.uniform(-0.6, 0.6), 0.1, -d / 2),
        0.5,
        0.06,
        "-z",
        mix(col, (200, 200, 200), 0.4),
        th=0.02,
        spin=rng.uniform(-20, 20),
    )


@prop(
    {"kind": "crt"},
    {"kind": "crt", "state": "broken"},
    {"kind": "crt", "state": "ground"},
    {"kind": "flat"},
    {"kind": "flat", "state": "ground"},
)
def tv(D, folder, origin, ry, rng, kind=None, state=None):
    """A television: an old CRT set (the deep tapered back, the bezel, the bulging dark screen, a
    speaker grille, knobs, a rabbit-ear aerial) or a flat screen on its foot.
    `broken`: the screen caved in (a black hole ringed by a pale crazed edge, glass shards below),
    the casing cracked. `ground`: dumped on the floor: the CRT on its back / side with its screen
    smashed and the shards around, the flat screen leaning against the wall (+Z) with a spider-web
    crack and a bent corner. Footprint CRT 2.2 x 2.2 studs, 1.9 tall; flat 3.6 x 0.6, 2.3 tall
    (on the ground ~2.6 x 1.2). 4-15 parts; the body SMALL on the ground, else DECOR_SHADOW."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["crt", "crt", "flat"])
    state = state or _pick(rng, ["ok", "broken", "ground"])
    body_flags = SMALL if state == "ground" else DECOR_SHADOW
    if kind == "crt":
        col = _tone(_pick(rng, [(46, 44, 42), (110, 104, 92), (70, 60, 50)]), rng, 6, darken=rng.uniform(0, 0.2))
        W, H, Dp = 2.2, 1.85, 2.0
        if state == "ground":
            _disk(f, "Shards", 0, -0.8, 2.0, 0.03, (120, 130, 136), "Glass", transparency=0.6, reflectance=0.2)
            if rng.random() < 0.6:  # on its back, the smashed screen to the sky
                f = f.sub((0, Dp / 2 + 0.02, 0), rx=90 + rng.uniform(-5, 5), rz=rng.uniform(-6, 6))
            else:  # on its side
                f = f.sub((0, W / 2 + 0.02, 0), rz=90 + rng.uniform(-5, 5), ry=rng.uniform(-10, 10))
        f.box("TV", (-W / 2, 0, -Dp / 2), (W / 2, H, -Dp / 2 + 0.7), col, "SmoothPlastic", flags=body_flags)
        f.box(
            "TVBack",
            (-W * 0.36, 0.15, -Dp / 2 + 0.7),
            (W * 0.36, H * 0.82, Dp / 2),
            _tone(col, rng, 4, 0.1),
            "SmoothPlastic",
            flags=body_flags,
        )
        f.box(
            "TVBezel",
            (-W / 2 + 0.12, 0.35, -Dp / 2 - 0.04),
            (W * 0.24, H - 0.14, -Dp / 2 + 0.02),
            _tone(col, rng, 3, 0.25),
            "SmoothPlastic",
        )
        sw = W * 0.74 - 0.12
        scx = (-W / 2 + 0.12 + W * 0.24) / 2
        smashed = state in ("broken", "ground")
        f.part(
            "TVScreen",
            (scx, (0.35 + H - 0.14) / 2, -Dp / 2 - 0.06),
            (sw - 0.16, H - 0.65, 0.08),
            (8, 8, 9) if smashed else (26, 32, 34),
            "Glass",
            reflectance=0.0 if smashed else 0.2,
        )
        if smashed:
            for k in range(3):  # the crazed glass left round the rim of the hole
                ex = rng.choice((-1, 1)) * (sw / 2 - 0.25)
                f.part(
                    "ScreenShard",
                    (
                        scx + (ex if k != 1 else rng.uniform(-0.4, 0.4)),
                        0.55 + (k * 0.45 if k != 1 else H - 0.75),
                        -Dp / 2 - 0.09,
                    ),
                    (rng.uniform(0.2, 0.4), rng.uniform(0.15, 0.3), 0.03),
                    (70, 78, 84),
                    "Glass",
                    rot=(0, 0, rng.uniform(0, 180)),
                    transparency=0.35,
                    reflectance=0.25,
                )
        f.box("TVGrille", (W * 0.28, 0.35, -Dp / 2 - 0.03), (W / 2 - 0.1, H * 0.45, -Dp / 2), (20, 20, 20), "Fabric")
        for k in range(2):
            _cyl(
                f,
                "TVKnob",
                (W * 0.37, H * 0.62 + k * 0.32, -Dp / 2 - 0.06),
                0.1,
                0.18,
                (30, 30, 30),
                "SmoothPlastic",
                rot=(0, 90, 0),
            )
        if state == "broken":
            f.part(
                "CaseCrack",
                (W / 2 + 0.01, H * 0.5, -Dp / 4),
                (0.03, 0.8, 0.04),
                (10, 10, 10),
                "SmoothPlastic",
                rot=(rng.uniform(-30, 30), 0, 0),
            )
        if state != "ground":
            for s in (-1, 1):
                _rod(
                    f,
                    "Aerial",
                    (0, H, 0),
                    (s * rng.uniform(0.5, 0.8), H + rng.uniform(0.9, 1.3), 0.2),
                    0.03,
                    (170, 170, 168),
                    "Metal",
                )
            if state == "broken":
                for _ in range(2):
                    _skin(
                        f,
                        "GlassShard",
                        (rng.uniform(-0.8, 0.8), 0, -Dp / 2 - rng.uniform(0.2, 0.5)),
                        rng.uniform(0.15, 0.3),
                        rng.uniform(0.1, 0.2),
                        "y",
                        (130, 140, 146),
                        "Glass",
                        th=0.02,
                        spin=rng.uniform(0, 180),
                        transparency=0.3,
                    )
    else:
        W, H = 3.6, 2.1
        col = _tone((26, 26, 28), rng, 3)
        if state == "ground":
            g = f.sub((0, 0, 0.3), rx=-rng.uniform(12, 20), rz=rng.uniform(-3, 3))
            y0 = 0.0
        else:
            g = f
            y0 = 0.25
            g.box("TVFoot", (-0.6, 0, -0.3), (0.6, 0.06, 0.3), col, "SmoothPlastic")
            g.box("TVNeck", (-0.12, 0.06, -0.05), (0.12, 0.35, 0.05), col, "SmoothPlastic")
        g.box("TV", (-W / 2, y0, -0.08), (W / 2, y0 + H, 0.08), col, "SmoothPlastic", flags=body_flags)
        g.box(
            "TVScreen",
            (-W / 2 + 0.07, y0 + 0.08, -0.1),
            (W / 2 - 0.07, y0 + H - 0.07, -0.08),
            SCREEN,
            "Glass",
            reflectance=0.25,
        )
        if state != "ok":
            cx, cy = rng.uniform(-0.8, 0.8), y0 + rng.uniform(0.6, 1.4)
            _skin(g, "ScreenImpact", (cx, cy, -0.1), 0.25, 0.25, "-z", (170, 176, 180), spin=45, th=0.02)
            for k in range(rng.randint(4, 5)):  # the spider web
                a = k * 72 + rng.uniform(-20, 20)
                ln = rng.uniform(0.5, 1.1)
                _skin(
                    g,
                    "ScreenCrack",
                    (cx + math.cos(math.radians(a)) * ln / 2, cy + math.sin(math.radians(a)) * ln / 2, -0.1),
                    ln,
                    0.025,
                    "-z",
                    (150, 156, 160),
                    spin=a,
                    th=0.015,
                )
            if state == "ground":
                g.part(
                    "BentCorner",
                    (W / 2 - 0.2, y0 + H - 0.2, 0),
                    (0.45, 0.45, 0.17),
                    col,
                    "SmoothPlastic",
                    rot=(rng.uniform(10, 20), 0, 12),
                )


@prop({}, {"count": 6}, {"count": 3, "fallen": 1})
def clothes_rack(D, folder, origin, ry, rng, count=None, fallen=None):
    """A chrome garment rail on castors (tarnished, one upright bent) hung with jackets on wire
    hangers: leather, denim, a puffer, a parka; each jacket a body with a collar and two limp
    sleeves, pushed along the rail at odd angles; one jacket fallen in a heap under it.
    Footprint 5 x 2 studs, 5.2 tall. 25-42 parts; the uprights SMALL, the jackets DECOR_SHADOW."""
    f = Frame(D, folder, origin, ry=ry)
    count = count or rng.randint(3, 6)
    fallen = (1 if rng.random() < 0.4 else 0) if fallen is None else fallen
    W, H = 4.8, 5.2
    mc = _tone((150, 150, 148), rng, 8, darken=rng.uniform(0.15, 0.35))
    bend = rng.uniform(-4, 4)
    for s in (-1, 1):
        x = s * W / 2
        _rod(f, "RackUpright", (x, 0.35, 0), (x + (bend * 0.03 if s > 0 else 0), H, 0), 0.14, mc, "Metal", flags=SMALL)
        _rod(f, "RackFoot", (x, 0.3, -0.9), (x, 0.3, 0.9), 0.14, mc, "Metal")
        for u in (-1, 1):
            _ball(f, "Castor", (x, 0.14, u * 0.85), 0.28, RUBBER, "Rubber")
    _rod(f, "RackRail", (-W / 2, H, 0), (W / 2 + bend * 0.03, H, 0), 0.12, mc, "Metal", extend=0.1)
    _rod(f, "RackBase", (-W / 2, 0.45, 0), (W / 2, 0.45, 0), 0.12, mc, "Metal")
    xs = sorted(rng.uniform(-W / 2 + 0.6, W / 2 - 0.6) for _ in range(count))
    for i, x in enumerate(xs):
        jc = _tone(_pick(rng, JACKET), rng, 6, darken=rng.uniform(0, 0.25))
        mat = _pick(rng, ["Leather", "Fabric", "Fabric", "Plastic"])
        g = f.sub((x, H, 0), ry=rng.uniform(-25, 25) + 90 * (0 if rng.random() < 0.8 else 1), rz=rng.uniform(-4, 4))
        _rod(g, "Hanger", (-0.7, -0.35, 0), (0.7, -0.35, 0), 0.04, (120, 120, 120), "Metal")
        jl = rng.uniform(2.2, 2.9)
        puff = mat == "Plastic"
        g.box(
            "Jacket",
            (-0.75, -0.35 - jl, -0.22 - 0.1 * puff),
            (0.75, -0.3, 0.22 + 0.1 * puff),
            jc,
            mat,
            flags=DECOR_SHADOW,
        )
        g.box("JacketCollar", (-0.4, -0.45, -0.28), (0.4, -0.2, 0.26), _tone(jc, rng, 4, 0.15), mat)
        for s in (-1, 1):
            g.part(
                "Sleeve",
                (s * 0.85, -0.4 - jl * 0.42, 0),
                (0.34, jl * 0.8, 0.34),
                _tone(jc, rng, 4, 0.05),
                mat,
                rot=(rng.uniform(-6, 6), 0, s * rng.uniform(4, 10)),
            )
    for _ in range(fallen):
        jc = _tone(_pick(rng, JACKET), rng, 6, darken=0.2)
        x = rng.uniform(-1.5, 1.5)
        f.part(
            "Jacket",
            (x, 0.25, rng.uniform(-0.6, 0.3)),
            (1.6, 0.4, 1.3),
            jc,
            "Fabric",
            rot=(rng.uniform(-8, 8), rng.uniform(0, 180), rng.uniform(-8, 8)),
            flags=DECOR_SHADOW,
        )
        f.part(
            "Sleeve",
            (x + 0.7, 0.15, rng.uniform(-0.8, -0.4)),
            (1.4, 0.3, 0.35),
            jc,
            "Fabric",
            rot=(0, rng.uniform(0, 180), 0),
        )


@prop({}, {"open": False})
def cash_box(D, folder, origin, ry, rng, open=True):
    """A dented steel cash box: the body, the lid (thrown back, or shut), the carry handle, the
    coin tray's dividers, a fat wad of grubby notes held by a rubber band, a few coins, the key in
    the lock. Footprint 1.2 x 0.9 studs, 0.45 tall (lid open 1.2). 4-8 parts, DECOR.
    Origin = the table top."""
    f = Frame(D, folder, origin, ry=ry)
    col = _tone(_pick(rng, [(60, 64, 70), (90, 40, 36), (50, 66, 54)]), rng, 6, darken=rng.uniform(0.05, 0.25))
    w, d, h = 1.2, 0.9, 0.4
    f.box("CashBox", (-w / 2, 0, -d / 2), (w / 2, h, d / 2), col, "Metal")
    f.box(
        "CashBoxHandle",
        (-0.25, h + (0 if open else 0.08), d / 2 - 0.08 if open else -0.04),
        (0.25, h + 0.06 + (0 if open else 0.08), d / 2 if open else 0.04),
        IRON,
        "Metal",
    )
    if open:
        g = f.sub((0, h, d / 2), rx=rng.uniform(95, 110))
        g.box("CashBoxLid", (-w / 2, 0, -d), (w / 2, 0.07, 0), _tone(col, rng, 4), "Metal")
        for k in range(2):
            f.box(
                "CoinTray",
                (-w / 2 + 0.05 + k * 0.3, h - 0.1, -d / 2 + 0.05),
                (-w / 2 + 0.08 + k * 0.3, h - 0.02, -d / 2 + 0.35),
                IRON,
                "Metal",
            )
        f.part(
            "Notes",
            (0.2, h + 0.04, 0.08),
            (0.65, 0.16, 0.36),
            _tone((120, 128, 108), rng, 8),
            "Fabric",
            rot=(0, rng.uniform(-10, 10), rng.uniform(-3, 3)),
        )
        f.part(
            "RubberBand",
            (0.2, h + 0.05, 0.08),
            (0.06, 0.2, 0.4),
            (150, 60, 40),
            "Rubber",
            rot=(0, rng.uniform(-10, 10), 0),
        )
        _disk(f, "Coins", -0.35, -0.2, 0.18, 0.06, (150, 130, 80), "Metal", y=h - 0.06)
    else:
        f.box(
            "CashBoxLid",
            (-w / 2 - 0.02, h, -d / 2 - 0.02),
            (w / 2 + 0.02, h + 0.07, d / 2 + 0.02),
            _tone(col, rng, 4),
            "Metal",
        )
        f.box("CashKey", (0.0, h - 0.18, -d / 2 - 0.08), (0.05, h - 0.06, -d / 2), (170, 150, 90), "Metal")


@prop({}, {"goods": "electronics"}, {"goods": "clothes"})
def market_stall(D, folder, origin, ry, rng, goods=None, light=True):
    """A whole black-market stall, composed: the canopy over a folding table laid with goods
    (phones, watches, car stereos, a radio, a TV, a cash box) or clothes (sneaker boxes, the
    jacket rail beside it), crates of stock stacked behind, a cardboard box of more. For quick
    dressing; place the pieces by hand for anything bespoke.
    Footprint ~9 x 7 studs, 7.8 tall. 117-175 parts (the sum of its pieces)."""
    f = Frame(D, folder, origin, ry=ry)
    goods = goods or _pick(rng, ["electronics", "electronics", "clothes"])
    yaw = _yaw(f)
    market_canopy(D, folder, _w(f, 0, 0.5), yaw, rng, w=rng.uniform(8.5, 9.5), d=rng.uniform(6, 7), light=light)
    tw = rng.uniform(5.5, 6.2)
    folding_table(D, folder, _w(f, rng.uniform(-0.4, 0.4), -1.0), yaw + rng.uniform(-3, 3), rng, w=tw)
    top = 2.45
    if goods == "electronics":
        items = [phone_tray, watch_case, car_stereos, cash_box]
        rng.shuffle(items)
        xs = [-tw / 2 + 0.9, -tw / 6 + 0.1, tw / 6, tw / 2 - 0.9]
        for fn, x in zip(items, xs):
            fn(D, folder, _w(f, x, -1.2, top), yaw + rng.uniform(-12, 12), rng)
        if rng.random() < 0.6:
            tv(
                D,
                folder,
                _w(f, rng.uniform(1.5, 2.5), 2.0),
                yaw + 180 + rng.uniform(-20, 20),
                rng,
                kind="crt",
                state="ok",
            )
        else:
            radio(D, folder, _w(f, rng.uniform(-2.5, -1.5), 1.6), yaw + rng.uniform(-30, 30), rng)
    else:
        shoe_boxes(
            D, folder, _w(f, rng.uniform(-1.5, 0), -1.1, top), yaw + rng.uniform(-10, 10), rng, count=rng.randint(3, 4)
        )
        cash_box(D, folder, _w(f, tw / 2 - 0.8, -1.2, top), yaw + rng.uniform(-15, 15), rng)
        clothes_rack(
            D, folder, _w(f, rng.uniform(-0.5, 0.5), 1.8), yaw + rng.uniform(-6, 6), rng, count=rng.randint(4, 5)
        )
    wooden_crates(D, folder, _w(f, -3.0, 2.2), yaw + rng.uniform(-10, 10), rng, count=rng.randint(1, 2))
    plastic_crates(D, folder, _w(f, 3.1, 2.4), yaw + rng.uniform(-20, 20), rng, count=rng.randint(2, 3))


# =============================================================================================
# The squat
# =============================================================================================
@prop({"state": "flat"}, {"state": "flat", "torn": True}, {"state": "folded"}, {"state": "leaning"})
def mattress(D, folder, origin, ry, rng, state=None, torn=None, size=None):
    """An old single mattress dragged in from the street: sagging (three segments, the middle one
    lower), the piped seam round its top edges, lumps where the springs have gone, tide-mark stains
    (urine yellow, rust brown, a dark old one), maybe a torn corner with the yellow foam showing.
    `flat` on the floor (on flattened cardboard), `folded` in two (the bend a fat roll), or
    `leaning` stood against the wall (+Z), buckling at the middle.
    Footprint 3 x 6.2 studs (folded 3 x 3.4, leaning 3 x 1.6), 0.6 thick. 9-19 parts; the body
    PROP (flat/folded), SMALL leaning."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["flat", "flat", "folded", "leaning"])
    torn = (rng.random() < 0.5) if torn is None else torn
    W, L, T = 3.0, size or 6.2, 0.6
    col = mix(_tone(_pick(rng, MATTRESS), rng, 8, darken=rng.uniform(0.25, 0.5)), (90, 80, 60), rng.uniform(0.1, 0.3))
    if state == "flat" and rng.random() < 0.6:
        f.part(
            "Cardboard",
            (rng.uniform(-0.3, 0.3), 0.03, rng.uniform(-0.3, 0.3)),
            (W + 0.8, 0.05, L * 0.7),
            _tone(CARDBOARD_WET, rng, 8),
            CARDBOARD_MAT,
            rot=(0, rng.uniform(-8, 8), 0),
        )
    segs = []  # (frame at the segment's centre bottom, its length) along local Z
    if state == "flat":
        sag = rng.uniform(0.08, 0.16)
        a = math.degrees(math.atan2(sag, L / 3)) * 0.5
        segs = [
            (f.sub((0, 0.05, -L / 3), rx=a), L / 3 + 0.03),
            (f.sub((0, 0.05 - sag * 0.5, 0)), L / 3 + 0.03),
            (f.sub((0, 0.05, L / 3), rx=-a), L / 3 + 0.03),
        ]
    elif state == "folded":
        Lh = L / 2
        segs = [
            (f.sub((0, 0, 0)), Lh),
            (f.sub((rng.uniform(-0.15, 0.15), T + 0.02, -0.1), ry=rng.uniform(-6, 6), rx=rng.uniform(1, 3)), Lh - 0.1),
        ]
        _cyl(f, "MattressFold", (0, T, Lh / 2 - 0.05), W, T * 2, _tone(col, rng, 4), "Fabric", flags=DECOR_SHADOW)
    else:
        lean = rng.uniform(10, 18)
        g = f.sub((0, 0, -0.2 - T), rx=90 + lean)  # stood on its end, its top against the wall
        segs = [
            (g.sub((0, 0, -L / 4)), L / 2),
            (g.sub((0, 0, -L / 2), rx=-rng.uniform(4, 9)).sub((0, 0, -L / 4)), L / 2),
        ]
    body_flag = SMALL if state == "leaning" else PROP
    for k, (s2, ln) in enumerate(segs):
        s2.box("Mattress", (-W / 2, 0, -ln / 2), (W / 2, T, ln / 2), _tone(col, rng, 3), "Fabric", flags=body_flag)
        s2.box(
            "MattressSeam",
            (-W / 2 - 0.04, T - 0.06, -ln / 2),
            (-W / 2 + 0.04, T + 0.02, ln / 2),
            _tone(col, rng, 3, 0.2),
            "Fabric",
        )
        s2.box(
            "MattressSeam",
            (W / 2 - 0.04, T - 0.06, -ln / 2),
            (W / 2 + 0.04, T + 0.02, ln / 2),
            _tone(col, rng, 3, 0.2),
            "Fabric",
        )
        if k == 0:  # a lump where a spring has gone: a low swelling, turned askew in the top
            s2.part(
                "Lump",
                (rng.uniform(-0.6, 0.6), T - 0.02, rng.uniform(-0.5, 0.5)),
                (rng.uniform(0.9, 1.3), 0.12, rng.uniform(0.8, 1.1)),
                _tone(col, rng, 3, -0.04),
                "Fabric",
                rot=(rng.uniform(-6, 6), rng.uniform(0, 90), rng.uniform(-6, 6)),
            )
        for _ in range(rng.randint(1, 2)):  # stains, darker rings round paler cores
            sc = mix(_tone(_pick(rng, STAIN), rng, 6), col, 0.35)
            x, z = rng.uniform(-0.8, 0.8), rng.uniform(-ln / 3, ln / 3)
            sz = rng.uniform(0.6, 1.4)
            _skin(
                s2,
                "Stain",
                (x, T, z),
                sz,
                sz * rng.uniform(0.6, 1.0),
                "y",
                sc,
                "Fabric",
                th=0.02,
                spin=rng.uniform(0, 180),
                transparency=0.35,
            )
    if torn:
        s2, ln = segs[-1]
        s2.part(
            "Foam",
            (W / 2 - 0.35, T * 0.55, ln / 2 - 0.4),
            (0.7, T * 0.7, 0.8),
            _tone(FOAM, rng, 10, 0.15),
            "Sand",
            rot=(0, rng.uniform(-20, 20), 0),
        )
        s2.part(
            "TornFlap",
            (W / 2 - 0.1, T + 0.1, ln / 2 - 0.3),
            (0.7, 0.04, 0.6),
            _tone(col, rng, 3),
            "Fabric",
            rot=(rng.uniform(-30, 30), 0, rng.uniform(20, 40)),
        )


@prop({"state": "laid"}, {"state": "bunched"}, {"state": "rolled"})
def sleeping_bag(D, folder, origin, ry, rng, state=None, color=None):
    """A grimy synthetic sleeping bag: `laid` out flat and slept in (the quilted body with its
    darker baffle lines, the hood end bunched, the top half unzipped and turned back showing the
    paler lining), `bunched` up in a heap, or `rolled` and strapped. Footprint 2.5 x 6.5 studs
    (bunched 2.4 x 2.2, rolled 2.4 x 1), 0.3-1 tall. 4-9 parts; DECOR_SHADOW."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["laid", "laid", "bunched", "rolled"])
    col = _tone(
        color or _pick(rng, [(40, 60, 92), (110, 50, 40), (60, 72, 50), (60, 60, 64), (140, 100, 50)]),
        rng,
        6,
        darken=rng.uniform(0.15, 0.4),
    )
    lining = mix(col, (150, 140, 120), 0.5)
    if state == "laid":
        W, L = rng.uniform(2.3, 2.6), rng.uniform(6.0, 6.6)
        f.box("SleepingBag", (-W / 2, 0, -L / 2 + 0.6), (W / 2, 0.35, L / 2), col, "Fabric", flags=DECOR_SHADOW)
        _cyl(f, "BagHood", (0, 0.32, -L / 2 + 0.6), W, 0.7, _tone(col, rng, 4), "Fabric", flags=DECOR_SHADOW)
        for k in range(rng.randint(3, 4)):
            z = -L / 2 + 1.6 + k * 1.2
            f.box(
                "Baffle",
                (-W / 2 - 0.01, 0.3, z - 0.04),
                (W / 2 + 0.01, 0.37, z + 0.04),
                _tone(col, rng, 3, 0.25),
                "Fabric",
            )
        # the top half unzipped and turned back
        g = f.sub((W / 2 - 0.05, 0.36, -L / 2 + 1.2), ry=rng.uniform(-6, 6))
        g.part("BagFlap", (0.55, 0.02, 1.1), (1.2, 0.06, 2.2), lining, "Fabric", rot=(0, 0, rng.uniform(-6, -2)))
        _cyl(g, "BagFlapRoll", (0.0, 0.08, 1.1), 2.2, 0.22, _tone(col, rng, 4), "Fabric", rot=(0, 90, 0))
        _skin(
            f,
            "Stain",
            (rng.uniform(-0.6, 0.6), 0.35, rng.uniform(0, L / 3)),
            0.9,
            0.7,
            "y",
            _tone(_pick(rng, STAIN), rng, 6),
            "Fabric",
            th=0.02,
            spin=rng.uniform(0, 180),
            transparency=0.4,
        )
    elif state == "bunched":
        for i in range(rng.randint(3, 4)):
            f.part(
                "SleepingBag",
                (rng.uniform(-0.6, 0.6), 0.25 + i * 0.12, rng.uniform(-0.6, 0.6)),
                (rng.uniform(1.4, 2.2), rng.uniform(0.4, 0.7), rng.uniform(1.0, 1.6)),
                _tone(col if i % 2 == 0 else lining, rng, 4),
                "Fabric",
                rot=(rng.uniform(-15, 15), rng.uniform(0, 180), rng.uniform(-15, 15)),
                flags=DECOR_SHADOW,
            )
        _ball(
            f,
            "SleepingBag",
            (rng.uniform(-0.3, 0.3), 0.45, rng.uniform(-0.3, 0.3)),
            1.2,
            _tone(col, rng, 4),
            "Fabric",
            flags=DECOR_SHADOW,
        )
    else:
        _cyl(f, "SleepingBag", (0, 0.5, 0), 2.2, 1.0, col, "Fabric", flags=DECOR_SHADOW)
        for s in (-1, 1):
            _cyl(f, "Strap", (s * 0.6, 0.5, 0), 0.12, 1.04, (24, 24, 24), "Fabric")
        _cyl(f, "BagEnd", (1.11, 0.5, 0), 0.04, 0.5, mix(col, (20, 20, 20), 0.5), "Fabric")


@prop({"kind": "folded"}, {"kind": "crumpled"}, {"kind": "draped"})
def blankets(D, folder, origin, ry, rng, kind=None):
    """Old blankets and duvets: a `folded` stack (2-4 slabs offset, each with its rounded fold),
    `crumpled` in a heap kicked off a bed, or `draped` half over something low with a corner
    trailing on the floor. Wool and fleece colours gone dull, a check stripe, a stain.
    Footprint 2-3.6 studs, 0.3-1.1 tall. 4-9 parts; DECOR_SHADOW."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["folded", "crumpled", "draped"])
    cols = [_tone(_pick(rng, FABRIC), rng, 8, darken=rng.uniform(0.05, 0.3)) for _ in range(4)]
    if kind == "folded":
        y = 0.0
        for i in range(rng.randint(2, 4)):
            th = rng.uniform(0.2, 0.32)
            g = f.sub((rng.uniform(-0.15, 0.15), y, rng.uniform(-0.15, 0.15)), ry=rng.uniform(-10, 10))
            g.box("Blanket", (-1.0, 0, -0.75), (1.0, th, 0.75), cols[i], "Fabric", flags=DECOR_SHADOW)
            _cyl(g, "BlanketFold", (0, th / 2, -0.75), 2.0, th, cols[i], "Fabric")
            y += th
        _skin(
            f,
            "Stripe",
            (0, y, rng.uniform(-0.3, 0.3)),
            1.9,
            0.12,
            "y",
            mix(cols[0], (180, 170, 150), 0.4),
            "Fabric",
            th=0.02,
        )
    elif kind == "crumpled":
        for i in range(rng.randint(3, 5)):
            f.part(
                "Blanket",
                (rng.uniform(-0.7, 0.7), 0.12 + i * 0.08, rng.uniform(-0.7, 0.7)),
                (rng.uniform(1.2, 2.2), rng.uniform(0.15, 0.45), rng.uniform(1.0, 1.8)),
                _tone(cols[i % 2], rng, 6),
                "Fabric",
                rot=(rng.uniform(-20, 20), rng.uniform(0, 180), rng.uniform(-20, 20)),
                flags=DECOR_SHADOW,
            )
        f.part(
            "Blanket",
            (0, 0.03, 0),
            (3.2, 0.05, 2.6),
            _tone(cols[0], rng, 6, 0.1),
            "Fabric",
            rot=(0, rng.uniform(0, 90), 0),
        )
    else:
        h = rng.uniform(0.7, 1.0)
        f.box("Blanket", (-1.3, h - 0.06, -0.8), (1.3, h, 0.8), cols[0], "Fabric", flags=DECOR_SHADOW)
        f.part(
            "Blanket",
            (0, h / 2, -0.85),
            (2.6, h, 0.06),
            _tone(cols[0], rng, 4),
            "Fabric",
            rot=(rng.uniform(-10, -4), 0, 0),
        )
        f.part(
            "Blanket",
            (rng.uniform(-0.5, 0.5), 0.03, -1.6),
            (2.0, 0.05, 1.4),
            _tone(cols[0], rng, 4, 0.05),
            "Fabric",
            rot=(0, rng.uniform(-20, 20), 0),
        )
        _skin(
            f,
            "Stain",
            (rng.uniform(-0.6, 0.6), h, 0),
            0.8,
            0.6,
            "y",
            _tone(_pick(rng, STAIN), rng, 6),
            "Fabric",
            th=0.02,
            spin=rng.uniform(0, 180),
            transparency=0.4,
        )


@prop({"kind": "ridge"}, {"kind": "ridge", "open": True}, {"kind": "dome"})
def tent(D, folder, origin, ry, rng, kind=None, open=None, color=None):
    """A cheap pop-up tent pitched on concrete: `ridge` (two sloped flysheet panels sagging off a
    bowed ridge pole, triangular ends, the door flap rolled up on a dark inside when `open`, guy
    lines to bricks since pegs won't go into concrete) or `dome` (four panels round a low crown,
    the poles showing as ribs). Duct-tape patches, a mud tide-line along the bottom, a tarp ground
    sheet sticking out. Footprint 4.5-5 x 6.5-7 studs (+1 for the guys), 3.6-4.2 tall.
    16-25 parts; the panels PROP."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["ridge", "ridge", "dome"])
    open = (rng.random() < 0.5) if open is None else open
    col = _tone(color or _pick(rng, TARP + [(110, 90, 50)]), rng, 6, darken=rng.uniform(0.1, 0.35))
    W, L, H = rng.uniform(4.4, 5.0), rng.uniform(6.4, 7.0), rng.uniform(3.6, 4.2)
    f.part(
        "GroundSheet",
        (rng.uniform(-0.2, 0.2), 0.03, -0.3),
        (W + 0.6, 0.05, L + 0.8),
        _tone(_pick(rng, TARP), rng, 6, 0.25),
        "Plastic",
        rot=(0, rng.uniform(-4, 4), 0),
    )
    if kind == "ridge":
        sag = rng.uniform(0.2, 0.4)
        slope = math.degrees(math.atan2(H, W / 2))
        side = math.hypot(W / 2, H)
        for s in (-1, 1):  # each roof panel in two halves along the ridge, dipping toward the middle
            for u in (-1, 1):
                dip = math.degrees(math.atan2(sag, L / 2)) * u
                pc, pr = (s * W / 4, H / 2 - sag / 2, u * L / 4), (dip, 0, -s * slope)
                f.part("TentPanel", pc, (side, 0.06, L / 2 + 0.05), _tone(col, rng, 3), "Fabric", rot=pr, flags=PROP)
                if rng.random() < 0.35:  # a duct-taped tear
                    _on_plate(
                        f,
                        "DuctTape",
                        pc,
                        pr,
                        rng.uniform(-0.6, 0.6),
                        rng.uniform(-1, 1),
                        (0.8, 0.03, 0.22),
                        _tone(DUCT, rng, 8),
                        spin=rng.uniform(-40, 40),
                    )
        _rod(f, "RidgePole", (0, H + 0.05, -L / 2), (0, H - sag + 0.05, 0), 0.08, IRON, "Metal")
        _rod(f, "RidgePole", (0, H - sag + 0.05, 0), (0, H + 0.05, L / 2), 0.08, IRON, "Metal")
        # the ends: back closed, front door flaps
        for e in (-1, 1):
            z = e * L / 2
            for s in (-1, 1):
                if e < 0 and open and s > 0:
                    continue
                f.part(
                    "TentEnd",
                    (s * W / 4, H / 2, z),
                    (0.05, H, W / 2),
                    _tone(col, rng, 4, 0.05),
                    "Fabric",
                    rot=(0, -s * 90, 0),
                    shape=WEDGE,
                )
        if open:
            f.part(
                "TentInside",
                (W / 4, H / 3, -L / 2 + 0.15),
                (0.05, H * 0.66, W / 2 - 0.3),
                SOOT,
                "Fabric",
                rot=(0, -90, 0),
                shape=WEDGE,
            )
            _rod(
                f,
                "DoorRoll",
                (0.15, H - 0.3, -L / 2 - 0.08),
                (W / 2 - 0.4, 0.5, -L / 2 - 0.08),
                0.22,
                _tone(col, rng, 4, 0.1),
                "Fabric",
            )
        guys = [(-1, -1), (1, -1), (-1, 1), (1, 1)][: rng.randint(2, 4)]
        for sx, sz in guys:
            top = (sx * 0.1, H - 0.1, sz * L / 2)
            foot = (sx * (W / 2 + rng.uniform(0.6, 1.0)), 0.25, sz * (L / 2 + rng.uniform(0.6, 1.0)))
            _rod(f, "GuyLine", top, foot, 0.04, (140, 130, 110), "Fabric")
            f.box(
                "Brick",
                (foot[0] - 0.4, 0, foot[2] - 0.2),
                (foot[0] + 0.4, 0.4, foot[2] + 0.2),
                _tone((96, 64, 52), rng, 8),
                "Brick",
                rot=(0, rng.uniform(0, 180), 0),
            )
    else:  # a dome: a ring of eight steep panels and eight flatter ones closing the crown
        R = W / 2 + 0.6
        r1, h1 = R * 0.62, H * 0.6
        lo = math.degrees(math.atan2(h1, R - r1))
        hi = math.degrees(math.atan2(H - h1, r1))
        door = rng.randrange(8)
        for k in range(8):
            g = f.sub((0, 0, 0), ry=k * 45 + rng.uniform(-2, 2))
            c = _tone(col, rng, 3)
            if not (open and k == door):
                g.part(
                    "TentPanel",
                    (0, h1 / 2, -(R + r1) / 2),
                    (R * 0.86, 0.06, math.hypot(R - r1, h1) + 0.06),
                    c,
                    "Fabric",
                    rot=(-lo, 0, 0),
                    flags=PROP,
                )
            else:
                g.part(
                    "TentInside",
                    (0, h1 / 2 - 0.1, -(R + r1) / 2 + 0.25),
                    (R * 0.6, 0.06, h1 * 0.95),
                    SOOT,
                    "Fabric",
                    rot=(-lo, 0, 0),
                )
                _cyl(g, "DoorRoll", (0, h1 + 0.1, -r1 - 0.1), R * 0.6, 0.22, _tone(col, rng, 4, 0.1), "Fabric")
            g.part(
                "TentPanel",
                (0, h1 + (H - h1) / 2 - 0.05, -r1 / 2),
                (r1 * 0.86, 0.06, math.hypot(r1, H - h1) + 0.06),
                _tone(c, rng, 2),
                "Fabric",
                rot=(-hi, 0, 0),
            )
        _vcyl(f, "TentCrown", 0, H - 0.12, 0, 0.12, 0.8, _tone(col, rng, 3, 0.15), "Fabric")
    _skin(
        f,
        "Mud",
        (0, 0.06, -L / 2 - 0.25 if kind == "ridge" else -W / 2),
        W * 0.9,
        0.5,
        "y",
        SOIL,
        "Ground",
        th=0.03,
        transparency=0.35,
    )


@prop({}, {"closed_side": True})
def lean_to(D, folder, origin, ry, rng, closed_side=None, w=None):
    """A tarp lean-to against a wall (+Z): the tarp tied to a pipe on the wall up high, sloping down
    to the ground at the front held by a timber pole and a rope, its lower edge weighed down with
    bricks, sagging in two strips, a duct-taped tear; maybe one side closed with a
    sheet of cardboard and a pallet. Footprint w (default 5.5-6.5) x 4.5 studs, 4.6 tall.
    10-16 parts; the tarp DECOR_SHADOW, the pole and pallet SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    closed_side = (rng.random() < 0.6) if closed_side is None else closed_side
    W = w or rng.uniform(5.5, 6.5)
    Dp, Ht, Hf = rng.uniform(4.2, 4.8), rng.uniform(4.4, 4.8), rng.uniform(1.6, 2.2)
    col = _tone(_pick(rng, TARP), rng, 6, darken=rng.uniform(0.1, 0.35))
    _rod(
        f,
        "WallPipe",
        (-W / 2 - 0.3, Ht + 0.1, Dp / 2 - 0.1),
        (W / 2 + 0.3, Ht + 0.1, Dp / 2 - 0.1),
        0.18,
        _tone(RUST, rng, 6),
        "CorrodedMetal",
    )
    sag = rng.uniform(0.2, 0.4)
    for s in (-1, 1):  # two strips each sagging toward the middle
        p0 = (s * W / 4, Ht, Dp / 2 - 0.1)
        p1 = (s * W / 4, Hf, -Dp / 2 + 0.6)
        mid, length, _, _ = _seg_rot(p0, p1)
        pitch = math.degrees(math.atan2(Ht - Hf, Dp - 0.7))
        pc, pr = (mid[0], mid[1] - sag * 0.5, mid[2]), (-pitch, 0, s * rng.uniform(2, 5))
        f.part("Tarp", pc, (W / 2 + 0.05, 0.06, length), _tone(col, rng, 4), "Plastic", rot=pr, flags=DECOR_SHADOW)
        if s < 0 or rng.random() < 0.4:
            _on_plate(
                f,
                "DuctTape",
                pc,
                pr,
                rng.uniform(-0.8, 0.8),
                rng.uniform(-1, 1),
                (0.8, 0.03, 0.25),
                _tone(DUCT, rng, 8),
                spin=rng.uniform(0, 180),
            )
    # the front skirt to the ground, the pole and the rope
    sk = rng.uniform(18, 28)
    f.part(
        "Tarp",
        (0, Hf / 2, -Dp / 2 + 0.6 - Hf / 2 * math.sin(math.radians(sk))),
        (W, Hf / math.cos(math.radians(sk)) + 0.1, 0.06),
        _tone(col, rng, 4, 0.05),
        "Plastic",
        rot=(sk, 0, rng.uniform(-2, 2)),
        flags=DECOR_SHADOW,
    )
    px = rng.uniform(-W / 4, W / 4)
    _bar(
        f,
        "TarpPole",
        (px, 0, -Dp / 2 + 0.6),
        (px, Hf + 0.15, -Dp / 2 + 0.6),
        0.22,
        0.22,
        _tone(WOOD_OLD, rng, 6),
        "Wood",
        flags=SMALL,
    )
    _rod(
        f,
        "Rope",
        (px, Hf + 0.1, -Dp / 2 + 0.6),
        (px + rng.uniform(-1, 1), 0.2, -Dp / 2 - 0.9),
        0.05,
        (130, 116, 84),
        "Fabric",
    )
    for i in range(rng.randint(3, 5)):  # bricks holding the skirt down
        x = -W / 2 + 0.5 + i * (W - 1) / 4 + rng.uniform(-0.2, 0.2)
        f.box(
            "Brick",
            (x - 0.4, 0, -Dp / 2 - 0.6),
            (x + 0.4, 0.4, -Dp / 2 - 0.2),
            _tone((96, 64, 52), rng, 8),
            "Brick",
            rot=(0, rng.uniform(-25, 25), rng.uniform(-6, 6)),
        )
    if closed_side:
        s = rng.choice((-1, 1))
        zc, dz = 0.3, Dp - 0.8  # the side closed under the slope: a box side and a triangle over it
        cc = _tone(CARDBOARD_WET, rng, 8)
        f.part("Cardboard", (s * W / 2, Hf / 2, zc), (0.06, Hf, dz), cc, CARDBOARD_MAT, rot=(0, 0, s * 2))
        f.part(
            "Cardboard",
            (s * W / 2, Hf + (Ht - Hf) / 2 - 0.15, zc),
            (0.06, Ht - Hf - 0.2, dz),
            _tone(cc, rng, 5),
            CARDBOARD_MAT,
            shape=WEDGE,
            rot=(0, 0, s * 2),
        )
        f.part(
            "Pallet",
            (s * (W / 2 + 0.35), 1.1, 0.4),
            (0.4, 2.2, 3.4),
            _tone(WOOD_GREY, rng, 8),
            "WoodPlanks",
            rot=(0, 0, s * rng.uniform(6, 12)),
            flags=SMALL,
        )


@prop({}, {"blanket": True})
def cardboard_shelter(D, folder, origin, ry, rng, blanket=None):
    """A sleeping place built of cardboard against a wall (+Z): two or three flattened boxes as a
    floor, two box sides propped as low walls, a big sheet bent over as a roof, a whole box at the
    head end for the head and the wind, held with brown tape; the cardboard dark and soft where it
    is wet at the bottom, a blanket poking out (`blanket`). Footprint 3.4 x 6.5 studs, 2.2 tall.
    12-15 parts; the walls SMALL, the rest DECOR_SHADOW."""
    f = Frame(D, folder, origin, ry=ry)
    blanket = (rng.random() < 0.6) if blanket is None else blanket
    W, L, H = 3.4, 6.4, rng.uniform(1.8, 2.3)
    for i in range(rng.randint(2, 3)):
        f.part(
            "Cardboard",
            (rng.uniform(-0.2, 0.2), 0.03 + i * 0.01, -L / 2 + 1.1 + i * 2.1),
            (W + rng.uniform(0, 0.4), 0.05, 2.4),
            _tone(CARDBOARD_WET if i % 2 else CARDBOARD_DARK, rng, 8),
            CARDBOARD_MAT,
            rot=(0, rng.uniform(-6, 6), 0),
        )
    for s in (-1, 1):
        f.part(
            "CardboardWall",
            (s * W / 2, H / 2 - 0.1, 0),
            (0.06, H, L * rng.uniform(0.75, 0.9)),
            _tone(CARDBOARD, rng, 8, 0.1),
            CARDBOARD_MAT,
            rot=(0, rng.uniform(-3, 3), s * rng.uniform(4, 10)),
            flags=SMALL,
        )
        _skin(
            f,
            "WetEdge",
            (s * (W / 2 + 0.05), 0.25, 0),
            L * 0.7,
            0.45,
            "+x" if s > 0 else "-x",
            CARDBOARD_WET,
            CARDBOARD_MAT,
            th=0.03,
        )
    # the roof: one big sheet bent over the two walls
    for s in (-1, 1):
        f.part(
            "CardboardRoof",
            (s * W / 4, H + 0.05 - 0.15, rng.uniform(-0.3, 0.3)),
            (W / 2 + 0.25, 0.06, L * 0.62),
            _tone(CARDBOARD, rng, 8),
            CARDBOARD_MAT,
            rot=(rng.uniform(-3, 3), 0, -s * rng.uniform(8, 14)),
            flags=DECOR_SHADOW,
        )
    f.part(
        "CardboardBox",
        (0, 0.9, L / 2 - 0.6),
        (W * 0.85, 1.8, 1.2),
        _tone(CARDBOARD, rng, 8, 0.05),
        CARDBOARD_MAT,
        rot=(0, rng.uniform(-4, 4), rng.uniform(-3, 3)),
        flags=SMALL,
    )
    f.part(
        "BoxFlap",
        (0, 1.85, L / 2 - 1.25),
        (W * 0.8, 0.05, 0.6),
        _tone(CARDBOARD, rng, 8),
        CARDBOARD_MAT,
        rot=(rng.uniform(-40, -20), 0, 0),
    )
    for _ in range(rng.randint(2, 3)):
        _skin(
            f,
            "Tape",
            (rng.uniform(-W / 3, W / 3), H - 0.05, rng.uniform(-L / 4, L / 4)),
            0.18,
            0.9,
            "y",
            _tone(TAPE, rng, 8),
            th=0.12,
            spin=rng.uniform(-20, 20),
        )
    if blanket:
        f.part(
            "Blanket",
            (rng.uniform(-0.4, 0.4), 0.2, -L / 2 + 0.2),
            (W * 0.7, 0.3, 1.6),
            _tone(_pick(rng, FABRIC), rng, 8, 0.15),
            "Fabric",
            rot=(rng.uniform(-8, 8), rng.uniform(-20, 20), 0),
            flags=DECOR_SHADOW,
        )


@prop({}, {"broken": True})
def camp_stool(D, folder, origin, ry, rng, broken=None):
    """A folding camp stool: two pairs of crossed steel legs (pivot bolts), the canvas seat sagging
    between the top bars, frayed; `broken`: one leg bent, the stool lopsided. Footprint 1.5 x 1.3
    studs, 1.5 tall. 8-8 parts; the seat SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    broken = (rng.random() < 0.25) if broken is None else broken
    if broken:
        f = f.sub((0, 0, 0), rz=rng.uniform(5, 9))
    w, d, h = 1.4, 1.2, 1.45
    mc = _tone((60, 66, 60), rng, 8, darken=rng.uniform(0, 0.3))
    for s in (-1, 1):
        x = s * w / 2
        _rod(f, "StoolLeg", (x, 0, -d / 2), (x, h, d / 2), 0.09, mc, "Metal")
        _rod(
            f,
            "StoolLeg",
            (x, 0, d / 2),
            (x, h, -d / 2) if not (broken and s > 0) else (x, h * 0.6, -d / 4),
            0.09,
            mc,
            "Metal",
        )
    for u in (-1, 1):
        _rod(f, "StoolBar", (-w / 2, h, u * d / 2), (w / 2, h, u * d / 2), 0.08, mc, "Metal")
    f.box(
        "StoolSeat",
        (-w / 2 + 0.05, h - 0.12, -d / 2),
        (w / 2 - 0.05, h - 0.06, d / 2),
        _tone(_pick(rng, FABRIC), rng, 8, 0.1),
        "Fabric",
        flags=SMALL,
    )
    _ball(f, "Pivot", (w / 2 + 0.03, h / 2, 0), 0.12, IRON, "Metal")


@prop({"state": "worn"}, {"state": "wrecked"}, {"state": "worn", "blanket": True})
def armchair(D, folder, origin, ry, rng, state=None, blanket=None, color=None):
    """A battered old armchair dragged out to the street: the base on short stubby legs (one
    missing, a brick under that corner), a sagging seat cushion squashed off-centre, the back
    leaning a little, two rolled arms; the upholstery torn on an arm with yellow foam bursting,
    the seat stained and the fabric black with grime where heads and hands go. `wrecked`: the
    cushion gone (springs and webbing showing), the back snapped further back, more foam.
    `blanket`: a blanket over the back. Footprint 3.2 x 3 studs, 3.4 tall. 16-20 parts;
    base and back PROP (sit on it)."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["worn", "worn", "wrecked"])
    blanket = (rng.random() < 0.35) if blanket is None else blanket
    col = _tone(color or _pick(rng, UPHOLSTERY), rng, 8, darken=rng.uniform(0.15, 0.4))
    W, Dp, y0 = 3.2, 3.0, 0.35
    miss = rng.randrange(4)
    for k, (sx, sz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        x, z = sx * (W / 2 - 0.3), sz * (Dp / 2 - 0.3)
        if k == miss:
            f.box(
                "Brick",
                (x - 0.25, 0, z - 0.4),
                (x + 0.25, y0, z + 0.4),
                _tone((96, 64, 52), rng, 8),
                "Brick",
                rot=(0, rng.uniform(-20, 20), 0),
            )
        else:
            _vcyl(f, "ChairLeg", x, 0, z, y0, 0.22, _tone(WOOD, rng, 6, 0.3), "Wood")
    tilt = rng.uniform(-1.5, 1.5)
    g = f.sub((0, y0, 0), rz=tilt)
    g.box("Armchair", (-W / 2, 0, -Dp / 2), (W / 2, 1.0, Dp / 2), col, "Fabric", flags=PROP)
    for s in (-1, 1):
        x = s * (W / 2 - 0.3)
        g.box(
            "ChairArm", (x - 0.3, 1.0, -Dp / 2), (x + 0.3, 1.9, Dp / 2 - 0.2), _tone(col, rng, 4), "Fabric", flags=PROP
        )
        _cyl(g, "ChairArmRoll", (x + s * 0.05, 1.9, -0.1), Dp - 0.2, 0.7, _tone(col, rng, 4), "Fabric", rot=(0, 90, 0))
    back = rng.uniform(8, 14) + (rng.uniform(12, 22) if state == "wrecked" else 0)
    b = g.sub((0, 0.9, Dp / 2 - 0.35), rx=-back)
    b.box("ChairBack", (-W / 2 + 0.55, 0, -0.3), (W / 2 - 0.55, 2.3, 0.3), _tone(col, rng, 4), "Fabric", flags=PROP)
    _cyl(b, "ChairBackRoll", (0, 2.3, 0), W - 1.1, 0.6, _tone(col, rng, 4), "Fabric")
    _skin(b, "Grime", (0, 1.8, -0.3), W * 0.45, 0.8, "-z", mix(col, GRIME, 0.7), "Fabric", th=0.03, transparency=0.3)
    if state == "worn":
        g.part(
            "Cushion",
            (rng.uniform(-0.2, 0.2), 1.15, -0.25 + rng.uniform(-0.2, 0.1)),
            (W - 1.3, 0.36, Dp - 0.9),
            _tone(col, rng, 4, -0.05),
            "Fabric",
            rot=(rng.uniform(-3, 3), rng.uniform(-6, 6), rng.uniform(-3, 3)),
        )
        _skin(
            g,
            "Stain",
            (rng.uniform(-0.4, 0.4), 1.33, -0.3),
            0.9,
            0.7,
            "y",
            _tone(_pick(rng, STAIN), rng, 6),
            "Fabric",
            th=0.02,
            spin=rng.uniform(0, 180),
            transparency=0.35,
        )
    else:
        g.box("Webbing", (-W / 2 + 0.6, 0.95, -Dp / 2 + 0.15), (W / 2 - 0.6, 1.0, Dp / 2 - 0.5), (30, 26, 22), "Fabric")
        for i in range(3):
            _rod(
                g,
                "Spring",
                (-0.7 + i * 0.7, 1.0, -0.6),
                (-0.7 + i * 0.7 + 0.05, 1.45, -0.55),
                0.12,
                _tone(RUST, rng, 8),
                "CorrodedMetal",
            )
        f.part(
            "Cushion",
            (rng.uniform(-2.6, 2.6), 0.18, -Dp / 2 - 1.0),
            (W - 1.3, 0.36, Dp - 0.9),
            _tone(col, rng, 4, 0.1),
            "Fabric",
            rot=(0, rng.uniform(0, 180), rng.uniform(-8, 8)),
            flags=DECOR_SHADOW,
        )
    s = rng.choice((-1, 1))  # torn arm, foam bursting
    g.part(
        "Foam",
        (s * (W / 2 - 0.3), 1.95, -Dp / 2 + rng.uniform(0.4, 0.9)),
        (0.5, 0.35, 0.6),
        _tone(FOAM, rng, 10, 0.1),
        "Sand",
        rot=(rng.uniform(-20, 20), rng.uniform(0, 90), 0),
    )
    _skin(g, "Grime", (0, 0.5, -Dp / 2), W - 0.1, 1.0, "-z", mix(col, GRIME, 0.6), "Fabric", th=0.03, transparency=0.45)
    if blanket:
        b.part(
            "Blanket",
            (rng.uniform(-0.3, 0.3), 2.0, -0.05),
            (W - 0.6, 0.12, 1.6),
            _tone(_pick(rng, FABRIC), rng, 8, 0.1),
            "Fabric",
            rot=(rng.uniform(-80, -60), rng.uniform(-6, 6), 0),
        )


@prop({"lit": True}, {"lit": False}, {"lit": False, "pot": False})
def camp_stove(D, folder, origin, ry, rng, lit=None, pot=True, light=True):
    """A one-ring camping stove on the ground: the squat gas cartridge (dented, label faded) under
    the burner head, three pot supports, a blackened dented saucepan with its handle sticking out
    and a lid half on (or a pot of brown stew), a small blue flame (`lit`, Neon, with a faint light
    if `light`), a scorch mark, a spoon. Footprint 1.6 x 1.4 studs, 1.6 tall. 8-13 parts, DECOR
    (the cartridge SMALL)."""
    f = Frame(D, folder, origin, ry=ry)
    lit = (rng.random() < 0.6) if lit is None else lit
    _disk(f, "Scorch", rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 1.6, 0.03, SOOT, "Slate", transparency=0.35)
    cc = _tone(_pick(rng, [(40, 70, 130), (170, 60, 40), (150, 140, 60)]), rng, 8, darken=rng.uniform(0.15, 0.4))
    _vcyl(f, "GasCartridge", 0, 0, 0, 0.55, 0.85, cc, "Metal", flags=SMALL)
    _vcyl(f, "CartridgeTop", 0, 0.55, 0, 0.12, 0.6, _tone(STEEL, rng, 8, 0.2), "Metal")
    _vcyl(f, "Burner", 0, 0.67, 0, 0.18, 0.4, _tone(IRON, rng, 5), "Metal")
    for k in range(3):
        g = f.sub((0, 0.85, 0), ry=k * 120)
        g.box("PotSupport", (-0.04, 0, -0.45), (0.04, 0.12, -0.15), IRON, "Metal")
    if lit:
        ex = (
            {
                "l": {
                    "type": "Point",
                    "color": [120, 150, 255],
                    "range": 5,
                    "brightness": 0.6,
                    "name": "Light",
                    "shadows": False,
                }
            }
            if light
            else None
        )
        _vcyl(f, "Flame", 0, 0.85, 0, 0.1, 0.42, (90, 130, 255), "Neon", transparency=0.3, extra=ex)
    if pot:
        pc = _tone((70, 66, 62), rng, 6, darken=rng.uniform(0.1, 0.3))
        g = f.sub((0, 0.97, 0), rz=rng.uniform(-3, 3))
        _vcyl(g, "Saucepan", 0, 0, 0, 0.5, 1.0, pc, "Metal")
        _vcyl(g, "SaucepanSoot", 0, 0, 0, 0.18, 1.02, SOOT, "Metal")
        g.box("PanHandle", (0.5, 0.38, -0.05), (1.3, 0.46, 0.05), _tone(IRON, rng, 4), "Metal", rot=(0, 0, 8))
        if rng.random() < 0.5:
            g.part(
                "PanLid",
                (0.18, 0.55, 0),
                (0.06, 0.95, 0.95),
                _tone(pc, rng, 4),
                "Metal",
                shape=CYLINDER,
                rot=(0, 0, 90 - rng.uniform(8, 14)),
            )
        else:
            _vcyl(g, "Stew", 0, 0.38, 0, 0.06, 0.9, _tone((84, 58, 34), rng, 6), "Sand")
    f.part(
        "Spoon",
        (rng.uniform(0.6, 0.9), 0.03, rng.uniform(-0.6, -0.3)),
        (0.7, 0.04, 0.1),
        _tone(STEEL, rng, 8, 0.1),
        "Metal",
        rot=(0, rng.uniform(0, 180), 0),
    )


@prop({"full": True}, {"full": False}, {"state": "tipped"})
def shopping_cart(D, folder, origin, ry, rng, full=None, state=None):
    """A stolen supermarket trolley, the squat's wardrobe on wheels: galvanised wire basket (thin
    rods: rims, corner posts, wires on every side and a translucent mesh skin so it reads as wire
    mesh), the tapered nose, the chassis rails and legs, four castors (one twisted), the handle
    with its faded red grip; rust at the welds; `full` of belongings bulging over the rim (bin
    bags, a rolled blanket, cardboard, a sleeping bag, a carrier bag) or `tipped` onto its side
    with its load spilled. Front (nose) toward -Z. Footprint 2 x 3.6 studs (tipped 3.6 x 3.6 + the
    spill), 3.6 tall. 49-65 parts; the basket's rims SMALL, wires DECOR."""
    f0 = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["upright", "upright", "tipped"])
    full = (rng.random() < 0.7) if full is None else full
    f = f0.sub((0, 1.02, 0), rz=90 + rng.uniform(-3, 3)) if state == "tipped" else f0
    mc = _tone(GALVANISED, rng, 8, darken=rng.uniform(0.05, 0.25))
    yb, yt = 1.45, 3.15
    bk = {"bl": (-1.0, yb, 1.4), "br": (1.0, yb, 1.4), "fl": (-0.75, yb + 0.15, -1.6), "fr": (0.75, yb + 0.15, -1.6)}
    tp = {"bl": (-1.05, yt, 1.55), "br": (1.05, yt, 1.55), "fl": (-0.85, yt, -1.75), "fr": (0.85, yt, -1.75)}
    loop = ["bl", "br", "fr", "fl"]
    for i in range(4):
        a, b = loop[i], loop[(i + 1) % 4]
        _rod(f, "CartRim", tp[a], tp[b], 0.1, mc, "Metal", flags=SMALL)
        _rod(f, "CartWire", bk[a], bk[b], 0.07, mc, "Metal")
        _rod(f, "CartWire", bk[a], tp[a], 0.07, mc, "Metal")

    def lerp(p, q, t):
        return tuple(p[k] + (q[k] - p[k]) * t for k in range(3))

    for a, b, n in (("bl", "fl", 3), ("br", "fr", 3), ("fl", "fr", 1), ("bl", "br", 2)):  # wires on each side
        for k in range(1, n + 1):
            t = k / (n + 1)
            _rod(f, "CartWire", lerp(bk[a], bk[b], t), lerp(tp[a], tp[b], t), 0.05, mc, "Metal")
        # the mesh skin, mid-height rail
        lo, hi = lerp(bk[a], tp[a], 0.5), lerp(bk[b], tp[b], 0.5)
        mid, length, ry2, _ = _seg_rot(lo, hi)
        g = Frame(f.D, f.folder, f.world(mid), matrix=f.m)
        g.part("CartMesh", (0, 0, 0), (length, yt - yb, 0.04), mc, "Metal", rot=(0, ry2, 0), transparency=0.78)
    for x in (-0.5, 0.0, 0.5):  # the floor wires
        _rod(f, "CartWire", (x, yb + 0.02, 1.4), (x * 0.8, yb + 0.17, -1.6), 0.05, mc, "Metal")
    # chassis, legs, castors
    for s in (-1, 1):
        _rod(f, "CartRail", (s * 0.8, 0.45, 1.5), (s * 0.6, 0.45, -1.6), 0.1, mc, "Metal")
        _rod(f, "CartLeg", (s * 1.0, yb, 1.4), (s * 0.8, 0.45, 1.5), 0.1, mc, "Metal")
        _rod(f, "CartLeg", (s * 0.75, yb + 0.15, -1.6), (s * 0.6, 0.45, -1.6), 0.09, mc, "Metal")
    _rod(f, "CartRail", (-0.6, 0.45, -1.6), (0.6, 0.45, -1.6), 0.1, mc, "Metal")
    twisted = rng.randrange(4)
    for k, (x, z) in enumerate(((-0.8, 1.5), (0.8, 1.5), (-0.6, -1.6), (0.6, -1.6))):
        f.box("CastorFork", (x - 0.08, 0.3, z - 0.1), (x + 0.08, 0.45, z + 0.1), IRON, "Metal")
        _cyl(
            f,
            "CartWheel",
            (x, 0.18, z + (0.08 if k != twisted else 0)),
            0.14,
            0.36,
            RUBBER,
            "Rubber",
            rot=(0, 90 if k == twisted else rng.uniform(-10, 10), 0),
        )
    # the handle
    for s in (-1, 1):
        _rod(f, "CartHandleArm", tp["bl" if s < 0 else "br"], (s * 1.05, yt + 0.3, 1.95), 0.08, mc, "Metal")
    _rod(f, "CartHandle", (-1.1, yt + 0.3, 1.95), (1.1, yt + 0.3, 1.95), 0.1, mc, "Metal")
    _rod(
        f,
        "CartGrip",
        (-0.75, yt + 0.3, 1.95),
        (0.75, yt + 0.3, 1.95),
        0.17,
        _tone((150, 44, 40), rng, 8, darken=rng.uniform(0.2, 0.45)),
        "Plastic",
    )
    _ball(f, "Rust", (rng.choice((-1, 1)) * 1.0, yb + 0.02, 1.4), 0.18, _tone(RUST, rng, 6), "CorrodedMetal")
    _ball(f, "Rust", (rng.choice((-1, 1)) * 0.6, 0.45, -1.6), 0.16, _tone(RUST, rng, 6), "CorrodedMetal")
    # the load
    if full or state == "tipped":
        items = rng.randint(4, 6)
        for i in range(items):
            k = i % 5
            x, z = rng.uniform(-0.45, 0.45), -1.1 + i * 0.5
            y = yb + 0.6 + (i % 2) * 0.5 + rng.uniform(0, 0.4)
            if k in (0, 3):
                d = rng.uniform(1.0, 1.4)
                _bag(f, "TrashBag", (x, y + 0.3, z), d, rng)
            elif k == 1:
                _cyl(
                    f,
                    "Blanket",
                    (0, y + 0.4, z),
                    1.7,
                    0.7,
                    _tone(_pick(rng, FABRIC), rng, 6, 0.1),
                    "Fabric",
                    rot=(0, rng.uniform(-15, 15), rng.uniform(-10, 10)),
                    flags=DECOR_SHADOW,
                )
            elif k == 2:
                f.part(
                    "Cardboard",
                    (x * 0.5, yt + 0.3, z),
                    (1.4, 1.2, 0.06),
                    _tone(CARDBOARD, rng, 8, 0.1),
                    CARDBOARD_MAT,
                    rot=(rng.uniform(-20, 20), rng.uniform(-30, 30), rng.uniform(-15, 15)),
                )
            else:
                f.part(
                    "CarrierBag",
                    (x, y + 0.2, z),
                    (0.8, 0.9, 0.6),
                    _tone((180, 176, 166), rng, 10, 0.2),
                    "Plastic",
                    rot=(rng.uniform(-15, 15), rng.uniform(0, 90), rng.uniform(-15, 15)),
                    transparency=0.1,
                )
        if state == "tipped":  # what fell out of the open top (now facing -X of the floor frame)
            for i in range(rng.randint(2, 3)):
                d = rng.uniform(1.0, 1.5)
                _ball(
                    f0,
                    "TrashBag",
                    (-3.6 - i * 0.7 - rng.uniform(0, 0.4), d * 0.38, rng.uniform(-1.2, 1.2)),
                    d,
                    _tone(_pick(rng, BAG), rng, 3),
                    "Plastic",
                    reflectance=0.07,
                    flags=DECOR_SHADOW,
                )
            f0.part(
                "Blanket",
                (-4.0, 0.08, rng.uniform(-0.6, 0.6)),
                (2.0, 0.15, 1.6),
                _tone(_pick(rng, FABRIC), rng, 6, 0.1),
                "Fabric",
                rot=(0, rng.uniform(0, 180), 0),
            )


@prop({"state": "standing"}, {"state": "lying"}, {"state": "standing", "mat": False})
def backpack(D, folder, origin, ry, rng, state=None, mat=None, color=None):
    """A worn-out rucksack: the main bag with its rounded top, a front pocket with its zip line,
    two side pockets, the shoulder straps and the grab loop on the back, a sleeping mat rolled and
    strapped on top (`mat`), a frayed patch; `standing` slumped forward, or `lying` on its back.
    Footprint 1.4 x 0.9 studs (lying 1.4 x 2), 2-2.4 tall. 9-10 parts; the bag SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["standing", "standing", "lying"])
    mat = (rng.random() < 0.5) if mat is None else mat
    col = _tone(
        color or _pick(rng, [(40, 50, 40), (50, 54, 70), (90, 40, 36), (30, 30, 32), (96, 86, 64)]),
        rng,
        6,
        darken=rng.uniform(0.1, 0.35),
    )
    W, Dp, H = 1.3, 0.7, 1.6
    if state == "lying":
        f = f.sub((0, Dp / 2 + 0.05, 0.2), rx=90 + rng.uniform(-5, 5), rz=rng.uniform(-10, 10))
        f = f.sub((0, 0, -Dp / 2))
    else:
        f = f.sub((0, 0, 0), rx=rng.uniform(4, 10))
    f.box("Backpack", (-W / 2, 0, -Dp / 2), (W / 2, H, Dp / 2), col, "Fabric", flags=SMALL)
    _cyl(f, "BackpackTop", (0, H, 0), W - 0.02, Dp, _tone(col, rng, 4), "Fabric")
    f.box(
        "FrontPocket",
        (-W * 0.38, 0.15, -Dp / 2 - 0.25),
        (W * 0.38, H * 0.5, -Dp / 2 + 0.02),
        _tone(col, rng, 4, 0.1),
        "Fabric",
    )
    f.box(
        "Zip",
        (-W * 0.36, H * 0.5 - 0.06, -Dp / 2 - 0.27),
        (W * 0.36, H * 0.5 - 0.02, -Dp / 2 - 0.2),
        (40, 40, 40),
        "Metal",
    )
    for s in (-1, 1):
        f.box(
            "SidePocket",
            (s * W / 2 - 0.12, 0.1, -0.25),
            (s * W / 2 + 0.12, H * 0.45, 0.2),
            _tone(col, rng, 4, 0.1),
            "Fabric",
        )
        _bar(
            f,
            "Strap",
            (s * 0.35, H, Dp / 2 + 0.05),
            (s * 0.4, 0.25, Dp / 2 + 0.15),
            0.25,
            0.08,
            _tone((30, 30, 30), rng, 4),
            "Fabric",
        )
    if mat:
        _cyl(
            f,
            "SleepingMat",
            (0, H + 0.45, 0),
            W + 0.6,
            0.6,
            _tone(_pick(rng, [(60, 90, 60), (40, 60, 100), (120, 70, 40)]), rng, 6, 0.2),
            "Plastic",
        )
    _skin(
        f,
        "Patch",
        (rng.uniform(-0.3, 0.3), rng.uniform(0.8, 1.2), -Dp / 2),
        0.35,
        0.3,
        "-z",
        _tone(_pick(rng, FABRIC), rng, 8),
        "Fabric",
        th=0.03,
        spin=rng.uniform(-20, 20),
    )


@prop({}, {"cup": True}, {"lines": 4})
def cardboard_sign(D, folder, origin, ry, rng, lines=None, cup=None):
    """A begging sign: a torn piece of box leaning against the wall (+Z) or a crate, with
    hand-written lines in black marker (short strokes of uneven length, words), a corner torn off,
    a wet stain; maybe a paper cup with a few coins in front of it (`cup`). Footprint 2.2 x 0.8
    studs, 1.4 tall. 7-17 parts, DECOR_SHADOW."""
    f = Frame(D, folder, origin, ry=ry)
    lines = lines or rng.randint(2, 4)
    cup = (rng.random() < 0.5) if cup is None else cup
    w, h = rng.uniform(1.9, 2.4), rng.uniform(1.3, 1.6)
    g = f.sub((0, 0, 0.3), rx=rng.uniform(10, 18), rz=rng.uniform(-3, 3))
    col = _tone(CARDBOARD, rng, 10, darken=rng.uniform(0, 0.2))
    g.box("Sign", (-w / 2, 0, -0.03), (w / 2, h, 0.03), col, CARDBOARD_MAT, flags=DECOR_SHADOW)
    s = rng.choice((-1, 1))
    g.part(
        "SignTear",
        (s * (w / 2 - 0.2), h - 0.2, -0.035),
        (0.04, 0.42, 0.42),
        _tone(col, rng, 6, 0.3),
        CARDBOARD_MAT,
        rot=(0, 90 * s, 0),
        shape=WEDGE,
    )
    for i in range(lines):
        y = h - 0.35 - i * (h - 0.5) / max(1, lines - 1) * 0.9
        x = -w / 2 + 0.2 + rng.uniform(0, 0.1)
        for _ in range(rng.randint(2, 3)):
            ln = rng.uniform(0.25, 0.6)
            if x + ln > w / 2 - 0.15:
                break
            _skin(
                g,
                "SignText",
                (x + ln / 2, y + rng.uniform(-0.03, 0.03), -0.03),
                ln,
                rng.uniform(0.09, 0.13),
                "-z",
                INK,
                th=0.01,
                spin=rng.uniform(-4, 4),
            )
            x += ln + rng.uniform(0.1, 0.18)
    _skin(
        g,
        "Stain",
        (rng.uniform(-0.5, 0.5), 0.3, -0.03),
        rng.uniform(0.5, 0.9),
        0.4,
        "-z",
        CARDBOARD_WET,
        CARDBOARD_MAT,
        th=0.01,
        transparency=0.3,
    )
    if cup:
        _vcyl(
            f,
            "PaperCup",
            rng.uniform(-0.4, 0.4),
            0,
            -0.45,
            0.5,
            0.36,
            _tone((200, 196, 186), rng, 10, 0.15),
            "SmoothPlastic",
        )
        _disk(f, "Coins", rng.uniform(-0.8, 0.8), -0.75, 0.16, 0.04, (150, 130, 80), "Metal")


# =============================================================================================
# Building-site leftovers
# =============================================================================================
@prop({"state": "standing"}, {"state": "fallen"}, {"state": "standing", "sandbag": True})
def traffic_cone(D, folder, origin, ry, rng, state=None, sandbag=None):
    """A tall road cone (the 1 m kind): the square rubber base with its stepped rim, a tapering
    orange body in five sections, two dirty white reflective collars, black grime rising from the
    bottom and a cracked, split tip; a sandbag slumped over the base (`sandbag`); standing or
    knocked over. Footprint 1.4 x 1.4 studs (fallen 1.4 x 3.6), 3.3 tall. 10-11 parts; SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["standing", "standing", "fallen"])
    sandbag = (rng.random() < 0.3) if sandbag is None else sandbag
    if state == "fallen":
        f = f.sub((0, 0.68, 0), rz=-76 + rng.uniform(-3, 3), rx=rng.uniform(-6, 6))
        f = f.sub((0, -0.7, 0))
    col = _tone(CONE, rng, 8, darken=rng.uniform(0.05, 0.3))
    f.box("ConeBase", (-0.7, 0, -0.7), (0.7, 0.12, 0.7), _tone(RUBBER, rng, 4), "Rubber", flags=SMALL)
    f.box("ConeBase", (-0.55, 0.12, -0.55), (0.55, 0.22, 0.55), _tone(RUBBER, rng, 4), "Rubber")
    ds = [0.95, 0.8, 0.64, 0.48, 0.33]
    for i, d in enumerate(ds):
        c = mix(col, (30, 26, 22), 0.5 * max(0.0, 1 - i / 2.5) * rng.uniform(0.6, 1.0))
        _vcyl(f, "Cone", 0, 0.22 + i * 0.58, 0, 0.6, d, c, "Plastic", flags=SMALL if i == 0 else DECOR_SHADOW)
    for y, d in ((1.7, 0.66), (2.4, 0.5)):
        _vcyl(
            f,
            "ConeCollar",
            0,
            y,
            0,
            0.3,
            d,
            _tone((180, 180, 172), rng, 8, darken=rng.uniform(0.2, 0.45)),
            "SmoothPlastic",
        )
    f.part("ConeTipCrack", (0.08, 3.12, 0), (0.05, 0.25, 0.3), SOOT, "SmoothPlastic", rot=(0, rng.uniform(0, 180), 0))
    if sandbag and state == "standing":
        f.part(
            "Sandbag",
            (rng.uniform(-0.2, 0.2), 0.35, -0.2),
            (1.3, 0.35, 0.8),
            _tone((120, 110, 86), rng, 8, 0.15),
            "Fabric",
            rot=(rng.uniform(-6, 6), rng.uniform(0, 180), rng.uniform(-6, 6)),
        )


@prop({"kind": "fence"}, {"kind": "aframe"}, {"kind": "jersey"}, {"kind": "fence", "banner": True})
def construction_barrier(D, folder, origin, ry, rng, kind=None, banner=None):
    """Site barriers left behind: `fence` (a steel mesh fence panel: tube frame, the mesh as wires
    and a translucent skin, two concrete feet, a clamp, maybe a torn printed banner cable-tied on),
    `aframe` (a red-and-white striped board on two folding A-legs, a dead warning lamp, the paint
    chipped) or `jersey` (a concrete crash barrier: sloped sides, chipped edges, lifting holes,
    tyre marks and a faded stripe). Footprint fence 7 x 1.8, aframe 4.6 x 2, jersey 6 x 2 studs;
    6.2 / 3.4 / 2.6 tall. 12-18 parts; the main panel or block SOLID / PROP."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["fence", "aframe", "jersey"])
    if kind == "fence":
        banner = (rng.random() < 0.4) if banner is None else banner
        W, H = 7.0, 6.0
        mc = _tone(GALVANISED, rng, 8, darken=rng.uniform(0.1, 0.35))
        for s in (-1, 1):
            f.box(
                "FenceFoot",
                (s * W / 2 - 0.9, 0, -0.35),
                (s * W / 2 + 0.9, 0.5, 0.35),
                _tone(CONCRETE, rng, 8, 0.1),
                "Concrete",
                flags=SMALL,
                rot=(0, rng.uniform(-6, 6), 0),
            )
        g = f.sub((0, 0.3, 0), rx=rng.uniform(-4, 4))
        for s in (-1, 1):
            _rod(g, "FenceFrame", (s * W / 2, 0, 0), (s * W / 2, H, 0), 0.16, mc, "Metal")
        for y in (0.1, H):
            _rod(g, "FenceFrame", (-W / 2, y, 0), (W / 2, y, 0), 0.16, mc, "Metal")
        g.box("FenceMesh", (-W / 2, 0.1, -0.02), (W / 2, H, 0.02), mc, "Metal", transparency=0.8, flags=SOLID)
        for k in range(1, 5):
            x = -W / 2 + k * W / 5
            _rod(g, "FenceWire", (x, 0.1, 0), (x, H, 0), 0.05, mc, "Metal")
        for y in (H / 3, 2 * H / 3):
            _rod(g, "FenceWire", (-W / 2, y, 0), (W / 2, y, 0), 0.05, mc, "Metal")
        g.box("FenceClamp", (W / 2 - 0.15, H * 0.5, -0.12), (W / 2 + 0.15, H * 0.5 + 0.35, 0.12), IRON, "Metal")
        _rust(g, rng, (-W / 2 + 0.3, 0.6, -0.08), "-z", 0.6, 1)
        if banner:
            bc = _tone(_pick(rng, [(40, 70, 120), (170, 160, 150), (60, 90, 60)]), rng, 8, 0.25)
            g.part(
                "Banner",
                (rng.uniform(-0.6, 0.6), H * 0.62, -0.06),
                (W * 0.7, 1.8, 0.03),
                bc,
                "Plastic",
                rot=(0, 0, rng.uniform(-3, 3)),
            )
            g.part(
                "Banner",
                (W * 0.25, H * 0.42, -0.07),
                (W * 0.25, 1.0, 0.03),
                bc,
                "Plastic",
                rot=(rng.uniform(-10, 10), 0, rng.uniform(15, 35)),
            )
            _skin(g, "BannerPrint", (-0.3, H * 0.64, -0.08), W * 0.4, 0.5, "-z", (200, 198, 190), th=0.01)
    elif kind == "aframe":
        W, H = 4.6, 3.2
        lc = _tone(STRIPE_WHITE, rng, 8, darken=rng.uniform(0.15, 0.35))
        rc = _tone(STRIPE_RED, rng, 8, darken=rng.uniform(0.1, 0.3))
        f.box(
            "BarrierBoard",
            (-W / 2, H - 0.75, -0.06),
            (W / 2, H - 0.05, 0.06),
            lc,
            "Wood",
            flags=PROP,
            rot=(0, 0, rng.uniform(-2, 2)),
        )
        for k in range(4):  # the diagonal red stripes
            x = -W / 2 + 0.55 + k * (W - 1.1) / 3
            _skin(f, "Stripe", (x, H - 0.4, -0.06), 0.35, 0.8, "-z", rc, th=0.02, spin=35)
        for s in (-1, 1):
            x = s * (W / 2 - 0.5)
            for u in (-1, 1):
                _bar(
                    f,
                    "BarrierLeg",
                    (x, H - 0.2, 0),
                    (x + s * 0.05, 0, u * 0.9),
                    0.18,
                    0.12,
                    _tone((150, 140, 60), rng, 8, 0.3),
                    "Metal",
                )
            _rod(f, "BarrierLegBar", (x, 0.6, -0.68), (x, 0.6, 0.68), 0.07, IRON, "Metal")
        _vcyl(
            f,
            "WarningLamp",
            W / 2 - 0.4,
            H - 0.05,
            0,
            0.35,
            0.36,
            _tone((150, 100, 40), rng, 6, 0.3),
            "Glass",
            transparency=0.2,
        )
        _skin(
            f,
            "Chip",
            (rng.uniform(-1.5, 1.5), H - 0.35, -0.08),
            0.3,
            0.15,
            "-z",
            WOOD_OLD,
            "Wood",
            th=0.01,
            spin=rng.uniform(0, 90),
        )
    else:
        L = rng.uniform(5.6, 6.2)
        cc = _tone(_pick(rng, [CONCRETE, CONCRETE_OLD, (130, 126, 118)]), rng, 6, darken=rng.uniform(0, 0.2))
        f.box("JerseyBarrier", (-L / 2, 0, -1.0), (L / 2, 0.8, 1.0), cc, "Concrete", flags=SOLID)
        f.part(
            "JerseyBarrier", (0, 1.55, -0.62), (L, 1.5, 0.75), _tone(cc, rng, 3), "Concrete", shape=WEDGE, flags=SOLID
        )
        f.part(
            "JerseyBarrier",
            (0, 1.55, 0.62),
            (L, 1.5, 0.75),
            _tone(cc, rng, 3),
            "Concrete",
            shape=WEDGE,
            rot=(0, 180, 0),
            flags=SOLID,
        )
        f.box("JerseyBarrier", (-L / 2, 0.8, -0.25), (L / 2, 2.6, 0.25), _tone(cc, rng, 3), "Concrete", flags=SOLID)
        for s in (-1, 1):  # the lifting slots at the base
            f.box("LiftSlot", (s * L / 4 - 0.4, 0.0, -1.02), (s * L / 4 + 0.4, 0.35, 1.02), SOOT, "SmoothPlastic")
        for _ in range(rng.randint(2, 3)):  # chipped edges: darker, rougher chunks along the top and corners
            sx = rng.choice((-1, 1))
            f.part(
                "Chip",
                (sx * (L / 2 - rng.uniform(0, 0.15)), rng.uniform(0.6, 2.4), rng.uniform(-0.6, 0.6)),
                (0.3, 0.35, 0.4),
                _tone(cc, rng, 6, 0.2),
                "Slate",
                rot=(rng.uniform(0, 45), rng.uniform(0, 45), 0),
            )
        _skin(f, "Stripe", (0, 2.2, -0.25), L - 0.3, 0.25, "-z", _tone((170, 150, 60), rng, 8, 0.35), th=0.02)
        _grime(f, -L / 2, L / 2, 0.0, rng.uniform(0.5, 0.8), -1.0, "-z", cc, rng)
        _skin(
            f,
            "TyreMark",
            (rng.uniform(-1, 1), 0.5, -1.02),
            rng.uniform(1.5, 2.5),
            0.25,
            "-z",
            (24, 24, 24),
            th=0.02,
            spin=rng.uniform(-8, 8),
            transparency=0.3,
        )


@prop({"bays": 1, "levels": 1}, {"bays": 1, "levels": 2}, {"bays": 2, "levels": 1, "netting": True})
def scaffolding(D, folder, origin, ry, rng, bays=None, levels=None, netting=None):
    """A section of tube-and-fitting scaffold against a wall (+Z): standards on base plates and
    sole boards, ledgers and transoms at every lift, a diagonal brace across the front, scaffold
    boards (grey, paint-spattered, one missing, one split), a toe board and a guard rail on top,
    couplers at the joints, rust on the old tubes; `netting`: a torn debris net hanging off the
    front. Each bay 7 x 3.4 studs, a lift 6.5 tall. 23-39 parts over its
    variants (+2 with the netting); boards SOLID (walkable), standards SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    bays = bays or rng.randint(1, 2)
    levels = levels or (1 if bays == 2 else rng.randint(1, 2))
    netting = (rng.random() < 0.35) if netting is None else netting
    BW, BD, LH = 7.0, 3.4, 6.5
    W = bays * BW
    tc = _tone(GALVANISED, rng, 8, darken=rng.uniform(0.15, 0.35))
    top = levels * LH
    xs = [-W / 2 + i * BW for i in range(bays + 1)]
    zs = (-BD / 2, BD / 2)
    for s, z in enumerate(zs):
        f.box("SoleBoard", (-W / 2 - 0.4, 0, z - 0.35), (W / 2 + 0.4, 0.12, z + 0.35), _tone(WOOD_OLD, rng, 6), "Wood")
    for x in xs:
        for z in zs:
            c = _tone(tc, rng, 4) if rng.random() < 0.7 else _tone(mix(tc, RUST, 0.5), rng, 6)
            _rod(f, "Standard", (x, 0.12, z), (x, top + (3.2 if z < 0 else 0.6), z), 0.2, c, "Metal", flags=SMALL)
            f.box("BasePlate", (x - 0.25, 0.12, z - 0.25), (x + 0.25, 0.2, z + 0.25), IRON, "Metal")
    for lv in range(1, levels + 1):
        y = lv * LH
        for z in zs:
            _rod(f, "Ledger", (-W / 2 - 0.3, y - 0.15, z), (W / 2 + 0.3, y - 0.15, z), 0.18, tc, "Metal")
        for x in xs:
            _rod(f, "Transom", (x, y, -BD / 2 - 0.3), (x, y, BD / 2 + 0.3), 0.18, tc, "Metal")
            _ball(f, "Coupler", (x, y - 0.15, -BD / 2), 0.3, IRON, "Metal")
        for b in range(bays):  # the boards, laid on the transoms
            x0 = xs[b]
            nb = 4
            missing = rng.randrange(nb) if rng.random() < 0.4 else -1
            for k in range(nb):
                if k == missing:
                    continue
                z = -BD / 2 + 0.45 + k * (BD - 0.9) / (nb - 1)
                bc = _tone(_pick(rng, [WOOD_GREY, WOOD_OLD, (120, 110, 90)]), rng, 8)
                f.part(
                    "ScaffoldBoard",
                    (x0 + BW / 2 + rng.uniform(-0.2, 0.2), y + 0.17, z + rng.uniform(-0.04, 0.04)),
                    (BW + 0.6 + rng.uniform(-0.2, 0.3), 0.15, 0.72),
                    bc,
                    "WoodPlanks",
                    flags=SOLID,
                    rot=(0, rng.uniform(-1, 1), rng.uniform(-0.6, 0.6)),
                )
            if rng.random() < 0.6:
                _skin(
                    f,
                    "PaintSpatter",
                    (x0 + rng.uniform(1, BW - 1), y + 0.25, rng.uniform(-1, 1)),
                    0.6,
                    0.4,
                    "y",
                    _tone((190, 188, 180), rng, 8, 0.1),
                    th=0.01,
                    spin=rng.uniform(0, 180),
                )
    f.box(
        "ToeBoard",
        (-W / 2, top + 0.25, -BD / 2 - 0.45),
        (W / 2, top + 0.85, -BD / 2 - 0.35),
        _tone(WOOD_OLD, rng, 6),
        "WoodPlanks",
    )
    for y in (top + 1.6, top + 3.0):
        _rod(f, "GuardRail", (-W / 2 - 0.2, y, -BD / 2 - 0.2), (W / 2 + 0.2, y, -BD / 2 - 0.2), 0.16, tc, "Metal")
    for b in range(bays):
        _rod(f, "Brace", (xs[b], 0.4, -BD / 2 - 0.2), (xs[b + 1], top - 0.3, -BD / 2 - 0.2), 0.16, tc, "Metal")
    if netting:
        nc = _tone(_pick(rng, [(40, 80, 50), (40, 70, 110), (60, 60, 60)]), rng, 8, 0.2)
        f.part(
            "DebrisNet",
            (0, top * 0.6, -BD / 2 - 0.35),
            (W - 0.6, top * 0.75, 0.04),
            nc,
            "Fabric",
            transparency=0.45,
            rot=(rng.uniform(-3, 0), 0, rng.uniform(-1, 1)),
        )
        f.part(
            "DebrisNet",
            (rng.uniform(-W / 4, W / 4), top * 0.18, -BD / 2 - 0.8),
            (W * 0.35, 2.0, 0.04),
            nc,
            "Fabric",
            transparency=0.4,
            rot=(rng.uniform(-35, -20), rng.uniform(-10, 10), rng.uniform(-8, 8)),
        )


@prop({"state": "leaning"}, {"state": "lying"}, {"state": "leaning", "kind": "wood"})
def ladder(D, folder, origin, ry, rng, state=None, kind=None, length=None):
    """A ladder: aluminium (box-section stiles, round rungs, rubber feet, dented and grey-black
    with handling) or old wooden (stiles, flat rungs, paint drips), a rung missing or one snapped;
    `leaning` against the wall (+Z) at a working angle, or `lying` flat on the ground.
    Footprint 1.6 x 9-11 studs (leaning: 1.6 x ~3), 9-11 long. 13-16 parts; stiles SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["leaning", "lying"])
    kind = kind or _pick(rng, ["alu", "alu", "wood"])
    L = length or rng.uniform(9, 11)
    W = 1.5
    if state == "leaning":
        ang = rng.uniform(14, 20)
        g = f.sub((0, 0, -L * math.sin(math.radians(ang)) / 2), rx=ang)
    else:
        g = f.sub((0, 0.14, L / 2), rx=-90, rz=rng.uniform(-2, 2))
    col = _tone((150, 152, 150) if kind == "alu" else WOOD, rng, 8, darken=rng.uniform(0.1, 0.35))
    mat = "Metal" if kind == "alu" else "Wood"
    for s in (-1, 1):
        g.box(
            "LadderStile", (s * W / 2 - 0.1, 0, -0.14), (s * W / 2 + 0.1, L, 0.14), _tone(col, rng, 4), mat, flags=SMALL
        )
        g.box("LadderFoot", (s * W / 2 - 0.13, 0, -0.17), (s * W / 2 + 0.13, 0.3, 0.17), RUBBER, "Rubber")
    n = int(L / 1.0)
    gone = rng.randrange(1, n - 1)
    for i in range(1, n):
        y = i * L / n
        if i == gone:
            if kind == "wood" and rng.random() < 0.5:
                g.part(
                    "LadderRung",
                    (-W / 4, y - 0.1, 0),
                    (W / 2, 0.14, 0.24),
                    _tone(col, rng, 6),
                    mat,
                    rot=(0, 0, rng.uniform(-30, -15)),
                )
            continue
        if kind == "alu":
            _cyl(g, "LadderRung", (0, y, 0), W, 0.16, _tone(col, rng, 4), mat)
        else:
            g.box("LadderRung", (-W / 2, y - 0.07, -0.12), (W / 2, y + 0.07, 0.12), _tone(col, rng, 6), mat)
    for s in (-1, 1):  # handling grime: the stiles black where hands hold them
        _skin(g, "Grime", (s * W / 2, L * 0.45, -0.14), 0.22, L * 0.35, "-z", mix(col, GRIME, 0.6), th=0.02)
    if kind == "wood":
        _skin(
            g,
            "PaintDrip",
            (rng.choice((-1, 1)) * W / 2, L * rng.uniform(0.3, 0.7), -0.15),
            0.18,
            0.7,
            "-z",
            _tone((190, 186, 176), rng, 8, 0.1),
            th=0.02,
            spin=rng.uniform(-5, 5),
        )


@prop({"count": 1}, {"count": 3}, {"count": 4, "chain": True})
def gas_canisters(D, folder, origin, ry, rng, count=None, chain=None):
    """Industrial gas cylinders (propane, oxygen, acetylene) standing against the wall (+Z): each a
    tall steel body with a rounded shoulder, the valve under its guard ring, a foot ring, a coloured
    shoulder band over faded paint, scrapes down to the metal, rust at the foot; chained to the wall
    (`chain`) or one fallen on its side. NAMED GasCylinder (never anything bottle-like).
    Footprint ~1 x 1 stud each, 3 in a row ~3.2 x 1.2; 4 tall. 7-30 parts; bodies PROP."""
    f = Frame(D, folder, origin, ry=ry)
    count = count or rng.randint(1, 4)
    chain = (count > 1 and rng.random() < 0.5) if chain is None else chain
    base = _tone(
        _pick(rng, [(60, 70, 64), (120, 40, 34), (40, 46, 56), (150, 130, 60), (90, 90, 92)]),
        rng,
        6,
        darken=rng.uniform(0.15, 0.35),
    )
    fallen = count >= 3 and not chain and rng.random() < 0.6
    for i in range(count):
        d, h = rng.uniform(0.9, 1.05), rng.uniform(3.2, 3.6)
        if fallen and i == count - 1:
            g = f.sub((rng.uniform(-0.5, 0.5), d / 2, -1.6), rz=90, ry=rng.uniform(-20, 20))
            g = g.sub((0, -h / 2, 0))
        else:
            g = f.sub(
                (-(count - 1) * 0.55 + i * 1.1 + rng.uniform(-0.05, 0.05), 0, rng.uniform(-0.1, 0.1)),
                rx=rng.uniform(-1.5, 1.5),
                rz=rng.uniform(-1.5, 1.5),
            )
        c = _tone(base, rng, 6)
        _vcyl(g, "GasCylinder", 0, 0.15, 0, h - 0.15, d, c, "Metal", flags=PROP)
        _ball(g, "GasCylinder", (0, h, 0), d, c, "Metal")
        _vcyl(g, "CylinderFoot", 0, 0, 0, 0.2, d + 0.06, _tone(mix(c, RUST, 0.6), rng, 6), "CorrodedMetal")
        _vcyl(
            g,
            "ShoulderBand",
            0,
            h - 0.5,
            0,
            0.35,
            d + 0.02,
            _tone(_pick(rng, [(170, 160, 150), (60, 80, 140), (150, 120, 50), (40, 40, 40)]), rng, 8, 0.2),
            "Metal",
        )
        _vcyl(g, "Valve", 0, h + d * 0.35, 0, 0.35, 0.22, _tone((150, 130, 80), rng, 8, 0.3), "Metal")
        _vcyl(g, "ValveGuard", 0, h + d * 0.4, 0, 0.3, 0.62, _tone(IRON, rng, 6), "Metal")
        _skin(
            g,
            "Scrape",
            (rng.uniform(-0.15, 0.15), rng.uniform(1.0, 2.4), -d / 2 + 0.03),
            0.14,
            rng.uniform(0.5, 1.0),
            "-z",
            _tone(STEEL, rng, 8, 0.2),
            th=0.02,
            spin=rng.uniform(-10, 10),
        )
    if chain:
        _rod(
            f,
            "Chain",
            (-(count - 1) * 0.55 - 0.7, 2.6, 0.55),
            ((count - 1) * 0.55 + 0.7, 2.6, 0.55),
            0.08,
            _tone(IRON, rng, 6),
            "Metal",
        )
        _rod(
            f,
            "Chain",
            (-(count - 1) * 0.55, 2.62, -0.55),
            ((count - 1) * 0.55, 2.62, -0.55),
            0.08,
            _tone(IRON, rng, 6),
            "Metal",
        )


@prop({"kind": "draped"}, {"kind": "pile"}, {"kind": "hanging"}, {"kind": "draped", "color": (60, 90, 140)})
def plastic_sheeting(D, folder, origin, ry, rng, kind=None, color=None):
    """Builders' polythene, dirty and half see-through: `draped` over a low heap of something (the
    sheet's top, its sloped sides, a skirt with a torn corner and a brick on it), `pile` (crumpled
    in a heap: tilted folds and bulges) or `hanging` down the wall (+Z) from a batten, in strips of
    different lengths, one torn and lifted. Footprint 3-4.5 x 2.5-3.5 studs (hanging 4 x 0.6, 6
    tall). 5-8 parts; DECOR_SHADOW (the draped heap SMALL)."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["draped", "pile", "hanging"])
    col = _tone(
        color or _pick(rng, [(190, 192, 188), (170, 176, 172), (120, 140, 160)]), rng, 8, darken=rng.uniform(0.05, 0.25)
    )
    tr = rng.uniform(0.3, 0.45)
    kw = {"transparency": tr, "reflectance": 0.1}
    if kind == "draped":
        W, Dp, H = rng.uniform(3.2, 4.2), rng.uniform(2.4, 3.2), rng.uniform(1.2, 1.8)
        f.box(
            "SheetedHeap",
            (-W / 2 + 0.4, 0, -Dp / 2 + 0.4),
            (W / 2 - 0.4, H - 0.1, Dp / 2 - 0.4),
            (40, 36, 30),
            "Wood",
            flags=SMALL,
        )
        f.part(
            "PlasticSheet",
            (0, H, 0),
            (W - 0.6, 0.05, Dp - 0.6),
            col,
            "Plastic",
            flags=DECOR_SHADOW,
            rot=(rng.uniform(-3, 3), rng.uniform(-5, 5), 0),
            **kw,
        )
        for s in (-1, 1):
            a = math.degrees(math.atan2(H, 0.6))
            f.part(
                "PlasticSheet",
                (s * (W / 2 - 0.15), H / 2, 0),
                (math.hypot(0.6, H), 0.05, Dp - 0.4),
                _tone(col, rng, 4),
                "Plastic",
                rot=(0, 0, -s * a),
                flags=DECOR_SHADOW,
                **kw,
            )
            f.part(
                "PlasticSheet",
                (0, H / 2, s * (Dp / 2 - 0.15)),
                (W - 0.4, 0.05, math.hypot(0.6, H)),
                _tone(col, rng, 4),
                "Plastic",
                rot=(s * a, 0, 0),
                flags=DECOR_SHADOW,
                **kw,
            )
        f.part(
            "PlasticSheet",
            (W / 2 + 0.4, 0.03, -Dp / 2 - 0.2),
            (1.2, 0.04, 0.9),
            col,
            "Plastic",
            rot=(0, rng.uniform(0, 60), 0),
            **kw,
        )
        f.box(
            "Brick",
            (-W / 2 - 0.2, 0, -0.2),
            (-W / 2 + 0.6, 0.4, 0.2),
            _tone((96, 64, 52), rng, 8),
            "Brick",
            rot=(0, rng.uniform(-30, 30), 0),
        )
    elif kind == "pile":
        for i in range(rng.randint(4, 6)):
            f.part(
                "PlasticSheet",
                (rng.uniform(-0.7, 0.7), 0.15 + i * 0.1, rng.uniform(-0.6, 0.6)),
                (rng.uniform(1.4, 2.6), 0.05, rng.uniform(1.0, 2.0)),
                _tone(col, rng, 5),
                "Plastic",
                rot=(rng.uniform(-35, 35), rng.uniform(0, 180), rng.uniform(-35, 35)),
                flags=DECOR_SHADOW,
                **kw,
            )
        _ball(f, "PlasticSheet", (0, 0.3, 0), 1.0, col, "Plastic", **kw)
    else:
        H = rng.uniform(5.5, 6.5)
        f.box("Batten", (-2.2, H - 0.2, 0.2), (2.2, H + 0.1, 0.4), _tone(WOOD_OLD, rng, 6), "Wood")
        x = -2.0
        while x < 2.0:
            w = rng.uniform(0.9, 1.6)
            hang = rng.uniform(H * 0.45, H - 0.1)
            xc = min(x + w / 2, 2.0 - w / 2)
            f.part(
                "PlasticSheet",
                (xc, H - hang / 2, 0.12),
                (w, hang, 0.04),
                _tone(col, rng, 5),
                "Plastic",
                rot=(rng.uniform(-6, -1), 0, rng.uniform(-3, 3)),
                flags=DECOR_SHADOW,
                **kw,
            )
            x += w - 0.1
        f.part(
            "PlasticFlap",
            (rng.uniform(-1, 1), H * 0.35, -0.2),
            (1.0, 1.2, 0.04),
            col,
            "Plastic",
            rot=(rng.uniform(-50, -30), rng.uniform(-20, 20), rng.uniform(-10, 10)),
            **kw,
        )


@prop({"state": "upright"}, {"state": "broken"}, {"state": "tipped"})
def office_chair(D, folder, origin, ry, rng, state=None, color=None):
    """A dumped office swivel chair: five-star base (legs and castors), the gas lift column and the
    tilt mechanism, a padded seat split with its foam out, the backrest on its curved support,
    two armrests (one pad gone); faded black/grey/blue fabric stained. `broken`: the back snapped
    and flopped backwards, a castor missing, sagging to one side. `tipped`: lying on its side.
    Footprint 2.4 x 2.4 studs (tipped 4 x 2.4), 4 tall. 20-21 parts; seat and back SMALL."""
    f0 = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["upright", "upright", "broken", "tipped"])
    f = f0.sub((0, 1.2, 0), rz=90 + rng.uniform(-6, 6), ry=rng.uniform(-20, 20)) if state == "tipped" else f0
    col = _tone(
        color or _pick(rng, [(40, 40, 44), (70, 72, 76), (40, 50, 76), (70, 40, 38)]),
        rng,
        6,
        darken=rng.uniform(0.1, 0.3),
    )
    pc = _tone((30, 30, 32), rng, 3)
    miss = rng.randrange(5) if state == "broken" else -1
    for k in range(5):
        g = f.sub((0, 0, 0), ry=k * 72 + rng.uniform(-3, 3))
        g.box("ChairLeg", (-0.1, 0.32, -1.15), (0.1, 0.48, 0), pc, "Plastic")
        if k != miss:
            _ball(g, "ChairCastor", (0, 0.16, -1.1), 0.32, pc, "Plastic")
    _vcyl(f, "GasLift", 0, 0.45, 0, 1.2, 0.26, _tone(STEEL, rng, 8, 0.3), "Metal")
    lean = rng.uniform(5, 9) if state == "broken" else 0
    g = f.sub((0, 1.6, 0), rz=lean)
    g.box("ChairMech", (-0.5, 0, -0.5), (0.5, 0.25, 0.5), IRON, "Metal")
    g.box("ChairSeat", (-1.0, 0.25, -1.0), (1.0, 0.65, 0.95), col, "Fabric", flags=SMALL)
    g.part(
        "SeatFoam",
        (rng.uniform(-0.4, 0.4), 0.62, rng.uniform(-0.5, 0.2)),
        (0.55, 0.1, 0.4),
        _tone(FOAM, rng, 10, 0.15),
        "Sand",
        rot=(0, rng.uniform(0, 180), 0),
    )
    _skin(
        g,
        "Stain",
        (rng.uniform(-0.4, 0.4), 0.65, rng.uniform(-0.4, 0.4)),
        0.8,
        0.6,
        "y",
        _tone(_pick(rng, STAIN), rng, 6),
        "Fabric",
        th=0.02,
        spin=rng.uniform(0, 180),
        transparency=0.4,
    )
    g.box("BackSupport", (-0.18, 0.1, 0.85), (0.18, 1.0, 1.1), pc, "Plastic")
    back = rng.uniform(4, 10) + (rng.uniform(45, 65) if state == "broken" else 0)
    b = g.sub((0, 0.9, 1.0), rx=-back)
    b.box("ChairBack", (-0.95, 0, -0.15), (0.95, 2.1, 0.2), _tone(col, rng, 4), "Fabric", flags=SMALL)
    b.box("ChairBackShell", (-0.9, 0.1, 0.2), (0.9, 2.0, 0.3), pc, "Plastic")
    padless = rng.randrange(2)
    for i, s in enumerate((-1, 1)):
        g.box("ArmPost", (s * 1.0 - 0.08, 0.3, -0.1), (s * 1.0 + 0.08, 1.3, 0.1), pc, "Plastic")
        if i != padless:
            g.box("ArmPad", (s * 1.0 - 0.14, 1.3, -0.55), (s * 1.0 + 0.14, 1.42, 0.35), pc, "Rubber")
