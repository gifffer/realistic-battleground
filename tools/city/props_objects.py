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

Only built-in Materials and colours (no textures, no meshes). These parts are the fallback until
the mesh kit (tools/city/kit/) is imported, and stay the real thing for the boxy objects.

No z-fighting (Roblox can't sort two faces in one plane: they flicker and swap as the camera
moves), so every prop follows these rules (checked with the scratchpad z-fight detector):
  • shells are BUTT-jointed: front and back walls full length, the ends fitted between them, a
    floor fitted inside the walls; no two pieces cross or share a face;
  • a detail stands 6-7 cm proud of its host (catches, bands, ribs) or is a surface mark;
  • surface marks (rust, grime, labels, stains: _skin) take depth slots per face plane, so two
    overlapping marks never share a depth (SKIN_STEP apart, an air gap between);
  • coaxial cylinders never share a cap (a drum's body ends 7 cm inside its chimes);
  • loose things lying on something are tilted 2.5+ degrees or lifted, never left in its plane;
    surfaces that carry goods are dead flat, and the goods stand 1 cm above them;
  • translucency only where nothing translucent overlaps (grime is opaque, mixed into the
    host's colour).

NO BOTTLES of any kind (glass or plastic, decoration or litter): there is none in here, keep it so.
(No gas cylinders either: the camp stove's squat cartridge is named GasCartridge.)

CATALOGUE lists every prop with a few option sets for tools/city/preview_props_objects.py.
"""

import functools
import math
import os
import random
import sys

import numpy as np

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
import zlayers  # noqa: E402
import meshprop as MESHPROP  # noqa: E402
from meshprop import frame_meshprop, lib_meshprop, variation, weathered  # noqa: E402

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
    """A flat disk lying on y (a cylinder turned upright). Its bottom stays on y even when the
    citykit size floor thickens it (flush). A thin DECOR disk on a level frame is a floor decal
    and goes through zlayers.floor_layer, like props_ground._disk: its own height over other
    decals, opaque blend where possible, None where 3 decals already overlap."""
    decal = (th <= zlayers.FLOOR_DECAL_MAX_TH and flags == DECOR and abs(f.m[1, 1]) > 0.9995
             and not kw.get("extra") and not kw.get("parent"))
    if not decal:
        return f.part(name, (x, y + th / 2, z), (th, d, d), color, mat, rot=(0, 0, 90), shape=CYLINDER, flags=flags,
                      flush=(0, 1), **kw)
    tr0 = kw.pop("transparency", 0.0)

    def make(yc, t, col, tr, m):
        return f.part(name, (x, yc, z), (t, d, d), col, m, rot=(0, 0, 90), shape=CYLINDER, flags=flags,
                      transparency=tr, flush=(0, 1), **kw)

    return zlayers.floor_layer(f, name, x, y, z, d * 0.85, d * 0.85, th, 0.0, make, color, tr0, mat)


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


# -- surface marks (rust, grime, labels, scuffs, stains) on a prop's faces ------------------------
# Every mark is a thin slab lying on a face. Two marks that overlap on the same face must not
# share a depth, or Roblox can't tell which is in front (z-fighting: stripes that swap as the
# camera moves), and two translucent ones must not intersect (their draw order flips). So each
# face plane of the world keeps a list of the marks on it, and a new mark goes one SLOT in front
# of every mark it overlaps there: slot k spans k * SKIN_STEP .. + SKIN_TH out of the face, so the
# front faces are SKIN_STEP apart and there is an air gap between slots. A mark that would need
# more than SKIN_MAX slots is dropped (None): nobody sees a fourth layer of grime.
SKIN_TH = 0.035  # a mark's thickness (studs)
SKIN_STEP = 0.062  # slot spacing: front faces 0.062 apart, a 0.027 air gap between slots
SKIN_MAX = 3  # slots per spot on a face


def _skin_slot(f, c, corners, n_local):
    """Finds the slot for a mark whose outline (local points `corners`) lies on the face through
    local point c with local normal n_local; registers it. Returns the slot or None (full)."""
    n = f.m @ np.array(n_local, float)
    off = float(n @ f.world(c))
    u = np.cross(n, (0.0, 1.0, 0.0) if abs(n[1]) < 0.9 else (1.0, 0.0, 0.0))
    u /= np.linalg.norm(u)
    v = np.cross(n, u)
    pts = np.array([f.world(p) for p in corners])
    pu, pv = pts @ u, pts @ v
    rect = (pu.min(), pu.max(), pv.min(), pv.max())
    planes = f.D.__dict__.setdefault("_po_skins", [])
    marks = None
    for pn, poff, lst in planes:
        if pn @ n > 0.9995 and abs(poff - off) < 0.06:  # (a mark asked a little off the face counts too)
            marks = lst
            break
    if marks is None:
        marks = []
        planes.append((n, off, marks))
    # (rect in the plane's own u/v: recompute against the stored plane's basis is not needed,
    # u/v depend on n only and n matches to 0.03 deg)
    slot = 0
    for r, k in marks:
        if r[0] < rect[1] - 0.01 and rect[0] < r[1] - 0.01 and r[2] < rect[3] - 0.01 and rect[2] < r[3] - 0.01:
            slot = max(slot, k + 1)
    if slot >= SKIN_MAX:
        return None
    marks.append((rect, slot))
    return slot


def _skin(f, name, c, w, h, face, color, mat="SmoothPlastic", th=None, spin=0.0, flags=DECOR, disk=False, **kw):
    """A thin mark lying on a face (rust, grime, a label, a stain): c is the point on the surface,
    face one of "-z", "+z", "-x", "+x", "y"; w x h its size in the face's plane, spun by `spin`
    deg. Its depth comes from the face's slots (_skin_slot): never coplanar with another mark.
    `th` is accepted for old calls but every mark is SKIN_TH thick. A "Stain" (or `disk`) on a
    top is round. Returns the row or None."""
    disk = disk or name == "Stain"
    s = -1 if face[0] == "-" else 1
    a = math.radians(spin)
    ca, sa = math.cos(a), math.sin(a)
    # the outline in the face's own 2D axes (p along w, q along h), spun
    if disk and face == "y":
        w = h = (w + h) / 2
    pq = [(ca * x - sa * y, sa * x + ca * y) for x, y in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2))]
    if face.endswith("z"):
        corners = [(c[0] + p, c[1] + q, c[2]) for p, q in pq]
        n_local = (0, 0, s)
    elif face.endswith("x"):
        corners = [(c[0], c[1] + q, c[2] + p) for p, q in pq]
        n_local = (s, 0, 0)
    else:
        corners = [(c[0] + p, c[1], c[2] + q) for p, q in pq]
        n_local = (0, 1, 0)
    slot = _skin_slot(f, c, corners, n_local)
    if slot is None:
        return None
    lift = slot * SKIN_STEP + SKIN_TH / 2  # the slab's centre out of the face
    t = SKIN_TH
    if disk and face == "y":  # stains on a top are round: a disk (Roblox cylinders stay round)
        return f.part(name, (c[0], c[1] + lift, c[2]), (t, w, w), color, mat, rot=(0, 0, 90), shape=CYLINDER,
                      flags=flags, **kw)
    if face.endswith("z"):
        return f.part(name, (c[0], c[1], c[2] + s * lift), (w, h, t), color, mat, rot=(0, 0, spin), flags=flags, **kw)
    if face.endswith("x"):
        return f.part(name, (c[0] + s * lift, c[1], c[2]), (t, h, w), color, mat, rot=(spin, 0, 0), flags=flags, **kw)
    return f.part(name, (c[0], c[1] + lift, c[2]), (w, t, h), color, mat, rot=(0, spin, 0), flags=flags, **kw)


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
    """Grime rising from the ground on a face: a pale high band and a darker low band in front of
    it (a gradient in two steps). Both opaque, the face's own colour mixed with GRIME, so nothing
    needs depth sorting; their depths come from the face's mark slots."""
    span = x1 - x0
    c = ((x0 + x1) / 2, 0, z) if w_axis == "x" else (z, 0, (x0 + x1) / 2)
    for hh, k in ((h * rng.uniform(1.3, 1.6), 0.2), (h, 0.42)):
        _skin(f, "Grime", (c[0], y0 + hh / 2, c[2]), span - 0.02, hh, face, mix(col, GRIME, k), "SmoothPlastic")


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
def dumpster(D, folder, origin, ry, rng, lid=None, color=None, full=None, against_wall=False, lids=None):
    """A big steel commercial dumpster (front-load skip): sloped top, the body's shell with three
    stamped ribs on the front, corner posts, a rolled rim, fork pockets on both sides, two black
    plastic lids on hinges (closed / one or both thrown back "open" / one propped up by the rubbish
    "half"), four casters; dented, grime rising from the ground, rust patches at the rim and
    corners, drip streaks, a faded info plate, a sprayed tag. When open, bin bags and cardboard
    bulge over the rim. Its back goes against a wall (+Z).
    Footprint ~6 x 3.6 studs (+0.4 pockets), 3.9-4.6 tall (open lids to ~7.5). 45-65 parts;
    shell and lids PROP, the rest DECOR. `lids`: force each lid's state ("c" closed, "o" open,
    "h" half; the -X lid first), e.g. to match the kit's lid markers placed over it."""
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
    # the shell, butt-jointed (no two plates overlap): the front and back walls full length, the
    # ends fitted between them with their sloped tops (wedges) butting the taller back wall, the
    # floor fitted inside the four walls
    f.box("Dumpster", (-L / 2, y0, -W / 2), (L / 2, y0 + H, -W / 2 + t), col, mat, flags=PROP)
    f.box("Dumpster", (-L / 2, y0, W / 2 - t), (L / 2, y0 + H2, W / 2), _tone(col, rng, 3), mat, flags=PROP)
    f.box("Dumpster", (-L / 2 + t, y0, -W / 2 + t), (L / 2 - t, y0 + t, W / 2 - t), dark, mat, flags=PROP)
    for s in (-1, 1):
        x0 = s * L / 2 - (t if s > 0 else 0)
        f.box("Dumpster", (x0, y0, -W / 2 + t), (x0 + t, y0 + H, W / 2 - t), _tone(col, rng, 3), mat, flags=PROP)
        f.part("Dumpster", (s * (L / 2 - t / 2), y0 + H + (H2 - H) / 2, -t / 2), (t, H2 - H, W - t), col, mat,
               shape=WEDGE, flags=PROP)
    # corner posts wrapping the front corners (their inner quarter hidden in the walls, their tops
    # 6 cm under the wall tops, their feet 6 cm below the shell), the back ones on the ends only, the rolled rim between the front
    # posts, stiffener channels 20 cm proud on the front
    pc = 0.1  # how far a post reaches into the walls
    for sx in (-1, 1):
        for sz in (-1, 1):
            x0 = sx * L / 2 - (pc if sx > 0 else 0.18)
            # (the back posts stop 7 cm inside the back face: the back goes flat against a wall)
            z0 = -W / 2 - 0.18 if sz < 0 else W / 2 - 0.35
            top = y0 + (H if sz < 0 else H2) - 0.065
            f.box("DumpsterPost", (x0, y0 - 0.065, z0), (x0 + 0.28, top, z0 + 0.28), _tone(dark, rng, 4), mat)
    f.box("DumpsterRim", (-L / 2 + pc, y0 + H - 0.25, -W / 2 - 0.18), (L / 2 - pc, y0 + H, -W / 2), dark, mat)
    ribs = []
    for x in (-L / 3, 0, L / 3):
        x += rng.uniform(-0.1, 0.1)
        ribs.append(x)
        f.box("DumpsterRib", (x - 0.17, y0 + 0.2, -W / 2 - 0.2), (x + 0.17, y0 + H - 0.3, -W / 2), _tone(col, rng, 5),
              mat)
    # fork pockets on the sides: open steel channels (top, bottom, outer plate) welded to the ends
    yp = y0 + H * rng.uniform(0.4, 0.48)
    for s in (-1, 1):
        x0, x1 = (L / 2, L / 2 + 0.38) if s > 0 else (-L / 2 - 0.38, -L / 2)
        pcol = _tone(dark, rng, 4)
        f.box("ForkPocket", (x0, yp + 0.47, -W * 0.42), (x1, yp + 0.55, W * 0.42), pcol, mat)
        f.box("ForkPocket", (x0, yp, -W * 0.42), (x1, yp + 0.08, W * 0.42), pcol, mat)
        xo = x1 - 0.08 if s > 0 else x0
        f.box("ForkPocket", (xo, yp + 0.08, -W * 0.42), (xo + 0.08, yp + 0.47, W * 0.42), pcol, mat)
    # the two lids, hinged at the back; closed they follow the slope
    slope = math.degrees(math.atan2(H2 - H, W))
    LL = math.hypot(W, H2 - H) + 0.22
    lw = L / 2 - 0.1
    states = {
        "closed": ("c", "c"),
        "open": _pick(rng, [("o", "o"), ("o", "c"), ("c", "o")]),
        "half": _pick(rng, [("h", "c"), ("c", "h"), ("h", "o")]),
    }[lid]
    states = tuple(lids) if lids else states
    lid_col = _tone(_pick(rng, [LID_BLACK, LID_BLACK, dark]), rng, 4)
    open_sides = []
    for s, st in zip((-1, 1), states):
        # against a wall the thrown-back lid rests on the bricks instead of going through them
        o_ang = rng.uniform(91, 95) if against_wall else rng.uniform(98, 116)
        ang = {"c": -slope + rng.uniform(-0.6, 0.6), "o": o_ang, "h": rng.uniform(14, 30)}[st]
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
        g.box("LidLip", (-lw / 2, -0.28, -LL), (lw / 2, -0.08, -LL + 0.12), _tone(c, rng, 3, 0.1), "Plastic")
        _cyl(f, "Hinge", (s * L / 4, y0 + H2 + 0.06, W / 2 + 0.06), lw * 0.8, 0.2, IRON, "Metal")
    # four casters
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * (L / 2 - 0.5), sz * (W / 2 - 0.5)
            f.box("Caster", (x - 0.16, 0.36, z - 0.16), (x + 0.16, y0, z + 0.16), IRON, "Metal")
            _cyl(f, "CasterWheel", (x, 0.21, z), 0.18, 0.42, RUBBER, "Rubber", rot=(0, rng.uniform(0, 180), 0))
    # wear on the front wall's face (its marks take depth slots, the ribs stand 20 cm proud):
    # grime up from the ground between the posts, rust at the rim and corners, drips, dents, the
    # faded info plate between two ribs, a sprayed tag
    _grime(f, -L / 2 + pc + 0.02, L / 2 - pc - 0.02, y0, rng.uniform(0.5, 0.9), -W / 2, "-z", col, rng)
    _rust(f, rng, (rng.choice((-1, 1)) * L * 0.36, y0 + H - 0.5, -W / 2), "-z", 0.9, rng.randint(1, 2))
    _rust(f, rng, (rng.uniform(-L, L) * 0.3, y0 + rng.uniform(0.6, 1.4), -W / 2), "-z", 0.9, 1)
    sx = rng.choice((-1, 1))  # (on the outer plate of a fork pocket)
    _rust(f, rng, (sx * (L / 2 + 0.38), yp + 0.275, rng.uniform(-0.6, 0.6)), "-x" if sx < 0 else "+x", 0.4, 1)
    for _ in range(rng.randint(1, 3)):
        _streak(f, rng, rng.uniform(-L / 2 + 0.4, L / 2 - 0.4), y0 + H - 0.25, -W / 2, "-z")
    for _ in range(rng.randint(1, 2)):
        f.part(
            "Dent",
            (rng.uniform(-L / 2 + 0.8, L / 2 - 0.8), y0 + rng.uniform(0.8, H - 0.9), -W / 2 - 0.03),
            (rng.uniform(0.6, 1.1), rng.uniform(0.5, 0.8), 0.06),
            _tone(col, rng, 4, 0.15),
            mat,
            rot=(rng.uniform(5, 14) * rng.choice((-1, 1)), rng.uniform(5, 14) * rng.choice((-1, 1)), rng.uniform(0, 90)),
        )
    k = rng.randrange(2)
    _skin(f, "InfoPlate", ((ribs[k] + ribs[k + 1]) / 2 + rng.uniform(-0.15, 0.15), y0 + H - 0.75, -W / 2), 1.0, 0.55,
          "-z", _tone((118, 116, 108), rng, 8, rng.uniform(0.2, 0.4)), "Metal", spin=rng.uniform(-3, 3))
    if rng.random() < 0.6:
        tag = _tone(_pick(rng, [(170, 170, 166), (150, 50, 50), (60, 110, 160), (40, 40, 42)]), rng, 8)
        x, y = rng.uniform(-L / 2 + 1, L / 2 - 1), y0 + rng.uniform(1.0, 1.8)
        for k in range(2):
            _skin(f, "Tag", (x + k * 0.35, y + rng.uniform(-0.15, 0.15), -W / 2), rng.uniform(0.6, 1.1), 0.09, "-z", tag,
                  spin=rng.uniform(-50, 50))
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
    f.box("BinBand", (-L / 2 - 0.07, y0 + H * 0.62, -W / 2 - 0.07), (L / 2 + 0.07, y0 + H * 0.62 + 0.25, W / 2 + 0.07),
          _tone(body, rng, 5, 0.1), "Metal")  # (7 cm proud: never near-coplanar with the body)
    # the rim: a collar round the top, butt-jointed, standing 7 cm above the body's top
    rim, rc = 0.1, _tone(body, rng, 4, 0.15)
    yr0, yr1 = y0 + H - 0.18, y0 + H + 0.07
    for s in (-1, 1):
        z0 = -W / 2 - rim if s < 0 else W / 2
        f.box("BinRim", (-L / 2 - rim, yr0, z0), (L / 2 + rim, yr1, z0 + rim), rc, "Metal")
        x0 = -L / 2 - rim if s < 0 else L / 2
        f.box("BinRim", (x0, yr0, -W / 2), (x0 + rim, yr1, W / 2), rc, "Metal")
    # the domed lid, hinged at the back on the rim: a flat skirt, three curved plates on an arc
    # over it, the two gable ends butting the plates' ends
    ang = 0.0 if lid == "closed" else rng.uniform(55, 65)  # (propped: never swung back past the hinge)
    Wl = W + 2 * rim
    g = f.sub((0, yr1, W / 2 + rim), rx=ang)
    g.box("BinLidSkirt", (-L / 2 - rim, 0, -Wl), (L / 2 + rim, 0.12, 0), _tone(lc, rng, 4, 0.2), "Plastic", flags=PROP)
    hd = 0.7
    r = (Wl * Wl / 4 + hd * hd) / (2 * hd)
    th = math.asin(min(1.0, (Wl / 2 - 0.05) / r))
    plates = []
    for i in range(3):
        phi = -th + (2 * i + 1) * th / 3
        p = g.sub((0, 0.12 - r + hd + r * math.cos(phi) - 0.05, -Wl / 2 + r * math.sin(phi)), rx=math.degrees(phi))
        p.part("BinLid", (0, 0, 0), (L, 0.1, 2 * r * math.sin(th / 3) + 0.06), _tone(lc, rng, 2), "Plastic", flags=PROP)
        plates.append(p)
    for e in (-1, 1):
        x0 = e * L / 2 - (0 if e > 0 else 0.06)
        g.box("BinLidEnd", (x0, 0.12, -Wl + 0.35), (x0 + 0.06, 0.12 + hd * 0.7, -0.35), _tone(lc, rng, 3, 0.1), "Plastic")
    if lid == "closed" and kind == "paper":  # the paper slot in the front plate
        _skin(plates[0], "PaperSlot", (0, 0.05, 0.05), L * 0.55, 0.14, "y", SOOT)
    if lid != "closed":  # the dark mouth level with the rim, the rubbish in it
        f.box("BinMouth", (-L / 2, y0 + H, -W / 2), (L / 2, y0 + H + 0.065, W / 2), SOOT, "SmoothPlastic")
        for _ in range(rng.randint(1, 3)):
            f.part("Cardboard", (rng.uniform(-1.2, 1.2), y0 + H + 0.2, rng.uniform(-0.8, 0.8)),
                   (rng.uniform(0.9, 1.5), 0.6, rng.uniform(0.9, 1.4)), _tone(CARDBOARD, rng, 8, 0.15), CARDBOARD_MAT,
                   rot=(rng.uniform(-25, 25), rng.uniform(0, 90), rng.uniform(-25, 25)))
    # the sticker (pale, half peeled), push handles, pedal, casters
    sc = mix(lc, (200, 200, 196), rng.uniform(0.3, 0.5))
    _skin(f, "Sticker", (rng.uniform(-0.4, 0.4), y0 + H * 0.4, -W / 2), 1.4, 1.0, "-z", sc, spin=rng.uniform(-2, 2))
    _skin(
        f,
        "StickerPeel",
        (rng.uniform(-0.5, 0.5), y0 + H * 0.4 + 0.4, -W / 2),
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
    _grime(f, -L / 2, L / 2, y0, rng.uniform(0.4, 0.8), -W / 2, "-z", body, rng)
    _rust(f, rng, (rng.choice((-1, 1)) * (L / 2 - 0.5), y0 + 0.5, -W / 2), "-z", 0.8, 1)
    _streak(f, rng, rng.uniform(-L / 2 + 0.5, L / 2 - 0.5), y0 + H * 0.62, -W / 2, "-z")


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
    if state == "tipped":  # on its side, resting on a wheel hub at the bottom and the rim at the top
        dl = math.atan2(0.205, H - 0.36)
        f = f.sub((0, (W / 2 + 0.205) * math.cos(dl) + 0.36 * math.sin(dl) + 0.01, 0), rz=90 + math.degrees(dl))
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
    g.box("BinLid", (-W / 2 - 0.04, 0, -Dp - 0.2), (W / 2 + 0.04, 0.12, 0), lc, "Plastic", flags=SMALL)
    g.box(
        "BinLidLip",
        (-W / 2 - 0.04, -0.22, -Dp - 0.2),
        (W / 2 + 0.04, 0.0, -Dp - 0.1),
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
    _grime(f, -W / 2 + 0.12, W / 2 - 0.12, 0.18, rng.uniform(0.4, 0.7), -Dp / 2 + 0.12, "-z", col, rng)
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
    """A 20 ft shipping container (ISO 668: 20.2 x 8.1 x 8.6 studs), years past its last voyage:
      • the frame: eight corner castings (0.6 x 0.5 x 0.4, rusty, the oval holes), corner posts
        between them, top and bottom side rails and the end header / sill, all BUTTED: each
        member stops where the next begins, so their outer faces meet edge to edge;
      • the long walls: the core's face is the valley, with trapezoid-pitch corrugation crests
        0.13 proud every 0.92 (real: 0.9 st pitch, 0.12-0.15 deep); the blank end corrugated
        horizontally the same way; the roof sits 0.1 below the rails;
      • the doors (+X end): two leaves with four pressed bands, two lock bars each, handles, the
        CSC plate and the box number; closed, or the right leaf swung open on the dark inside;
      • wear in the paint's depth slots, on the crests (never floating over a valley): the owner's
        faded letters one per crest, rust and roller-painted patches over old tags, drips from
        the roof rail, rust along the bottom rail, a puddle in the dented roof.
    Footprint L (20) x 8 studs (doors ajar: +4 on +X), 8.5 tall. 95-115 parts; the core is SOLID
    (stand on it), the rest DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    doors = doors or _pick(rng, ["closed", "closed", "ajar"])
    L = length or 20.0
    W, H = 8.0, 8.5
    col = _tone(color or _pick(rng, CONTAINER), rng, 6, darken=rng.uniform(0.05, 0.3))
    frame = _tone(col, rng, 4, 0.25)
    cast = _tone(RUST_DARK, rng, 5)
    cx, cz, ch = 0.6, 0.5, 0.4  # casting size (along X, Z, Y)
    pw = 0.45  # corner post section
    vz = W / 2 - 0.15  # the long walls' valley face
    f.box("Container", (-L / 2 + 0.15, 0.2, -vz), (L / 2 - 0.36, H - 0.1, vz), col, "Metal", flags=SOLID)
    for sx in (-1, 1):
        for sz in (-1, 1):
            x0 = sx * L / 2 - (cx if sx > 0 else 0)
            z0 = sz * W / 2 - (cz if sz > 0 else 0)
            for y0 in (0.0, H - ch):
                f.box("CornerCasting", (x0, y0, z0), (x0 + cx, y0 + ch, z0 + cz), _tone(cast, rng, 4), "CorrodedMetal")
            xp = sx * L / 2 - (pw if sx > 0 else 0)
            zp = sz * W / 2 - (pw if sz > 0 else 0)
            f.box("ContainerPost", (xp, ch, zp), (xp + pw, H - ch, zp + pw), frame, "Metal")
            # the casting's oval holes, on its side and end
            _skin(f, "CastingHole", (sx * (L / 2 - cx / 2), H - ch / 2, sz * W / 2), 0.26, 0.14, "-z" if sz < 0 else "+z",
                  SOOT)
            _skin(f, "CastingHole", (sx * L / 2, H - ch / 2, sz * (W / 2 - cz / 2)), 0.22, 0.14, "-x" if sx < 0 else "+x",
                  SOOT)
    for sz in (-1, 1):  # the side rails between the castings, flush with them
        z0 = sz * W / 2 - (0.3 if sz > 0 else 0)
        f.box("ContainerRail", (-L / 2 + cx, H - 0.4, z0), (L / 2 - cx, H - 0.03, z0 + 0.3), frame, "Metal")
        f.box("ContainerRail", (-L / 2 + cx, 0.05, z0), (L / 2 - cx, 0.45, z0 + 0.3), mix(frame, RUST, rng.uniform(0.3, 0.7)),
              "CorrodedMetal")
    # corrugation crests on both long walls, between the posts and the rails
    pitch, crest = 0.92, 0.42
    n = int((L - 2 * pw - 0.3) / pitch)
    xs = [-(n - 1) * pitch / 2 + i * pitch for i in range(n)]
    for sz in (-1, 1):
        z0 = sz * vz if sz > 0 else -W / 2 + 0.02
        for x in xs:
            f.box("Corrugation", (x - crest / 2, 0.45, z0), (x + crest / 2, H - 0.4, z0 + 0.13),
                  _tone(col, rng, 3, 0.0 if sz < 0 else 0.05), "Metal")
    # the blank end (-X): end rails, horizontal crests on the core's end face
    for y0, y1 in ((0.05, 0.45), (H - 0.45, H - 0.03)):
        f.box("ContainerRail", (-L / 2 + 0.02, y0, -W / 2 + cz), (-L / 2 + 0.32, y1, W / 2 - cz), frame, "Metal")
    ny = int((H - 1.0) / pitch)
    for i in range(ny):
        y = 0.5 + pitch / 2 + i * (H - 1.0 - pitch) / max(1, ny - 1)
        f.box("Corrugation", (-L / 2 + 0.02, y - crest / 2, -W / 2 + pw), (-L / 2 + 0.15, y + crest / 2, W / 2 - pw),
              _tone(col, rng, 3, 0.05), "Metal")
    # the door end (+X): header and sill between the castings, the two leaves between the posts
    xd = L / 2 - 0.2
    f.box("DoorHeader", (L / 2 - 0.35, H - 0.6, -W / 2 + cz), (L / 2 - 0.02, H - 0.05, W / 2 - cz), frame, "Metal")
    f.box("DoorSill", (L / 2 - 0.35, 0.05, -W / 2 + cz), (L / 2 - 0.02, 0.5, W / 2 - cz), mix(frame, RUST, 0.6),
          "CorrodedMetal")
    if doors == "ajar":  # the dark inside, 7 cm in front of the core's end
        f.box("ContainerInside", (L / 2 - 0.36, 0.5, -W / 2 + pw), (L / 2 - 0.29, H - 0.6, W / 2 - pw), SOOT,
              "SmoothPlastic")
    dw = W / 2 - pw
    dh0, dh1 = 0.5, H - 0.6
    bands = [dh0 + (dh1 - dh0) * u for u in (0.12, 0.42, 0.62, 0.88)]
    for k, s in enumerate((-1, 1)):
        hinge_z = s * (W / 2 - pw)
        swing = rng.uniform(55, 110) if (doors == "ajar" and k == 1) else 0.0
        g = f.sub((xd, 0, hinge_z), ry=-s * swing)  # (both leaves swing outwards)
        c = _tone(col, rng, 4)
        z0, z1 = (0.0, dw) if s < 0 else (-dw, 0.0)
        g.box("ContainerDoor", (0, dh0, z0), (0.12, dh1, z1), c, "Metal", flags=PROP)
        for y in bands:  # the pressed bands, 7 cm proud
            g.box("DoorBand", (0.12, y - 0.18, z0 + 0.08), (0.19, y + 0.18, z1 - 0.08), _tone(c, rng, 3, 0.04), "Metal")
        for u in (0.3, 0.7):
            zz = z0 + (z1 - z0) * u
            _vcyl(g, "LockBar", 0.26, dh0 + 0.15, zz, dh1 - dh0 - 0.3, 0.11, _tone(GALVANISED, rng, 8, 0.3), "Metal")
            for y in (dh0 + 0.08, dh1 - 0.2):  # cam keepers
                g.box("CamKeeper", (0.12, y, zz - 0.1), (0.38, y + 0.12, zz + 0.1), IRON, "Metal")
            g.box("LockHandle", (0.3, 3.0, zz - 0.05), (0.38, 3.12, zz + (0.9 if s < 0 else -0.9) * 0.5), IRON, "Metal")
        if k == 0:
            _skin(g, "SealPlate", (0.12, 4.35, z0 + (z1 - z0) * 0.5), 0.9, 0.6, "+x", _tone((150, 150, 144), rng, 8, 0.25),
                  "Metal")
        else:
            _skin(g, "ContainerNumber", (0.12, 6.0, z0 + (z1 - z0) * 0.5), 2.4, 0.4, "+x",
                  _tone((176, 174, 166), rng, 8, 0.3))
        _rust(g, rng, (0.12, rng.uniform(0.85, 1.0), (z0 + z1) / 2), "+x", 0.35, 1)
    # wear, on the crests of the -Z wall (the side the alleys show), in their depth slots
    face = -W / 2 + 0.02
    lc = mix(_tone((176, 174, 166), rng, 8), col, rng.uniform(0.35, 0.55))
    band_y = H * rng.uniform(0.6, 0.7)
    k0 = rng.randrange(1, max(2, n // 3))
    for i in range(rng.randint(4, 6)):  # the owner's name: one faded letter per crest, some flaked off
        if k0 + i >= n or rng.random() < 0.2:
            continue
        _skin(f, "Lettering", (xs[k0 + i], band_y, face), crest - 0.06, rng.uniform(1.2, 1.35), "-z", lc)
    for _ in range(rng.randint(2, 4)):  # rust on the crests low down, just above the bottom rail
        x = _pick(rng, xs)
        rh = rng.uniform(0.3, 0.8)
        _skin(f, "Rust", (x, 0.5 + rh / 2 + rng.uniform(0, 0.5), face), crest - 0.04, rh, "-z",
              _tone(_pick(rng, [RUST, RUST_DARK]), rng, 6, 0.15), "CorrodedMetal")
    for _ in range(rng.randint(2, 3)):
        x = _pick(rng, xs)
        _streak(f, rng, x + rng.uniform(-0.1, 0.1), H - 0.45, face, "-z", length=rng.uniform(1.5, 3.5))
    if rng.random() < 0.6:  # rollered paint over old graffiti, across a few crests
        k = rng.randrange(0, max(1, n - 4))
        y, h = rng.uniform(2.0, 3.5), rng.uniform(1.2, 2.0)
        pc = _tone(col, rng, 6, -0.15)
        for i in range(rng.randint(3, 4)):
            _skin(f, "PaintPatch", (xs[k + i], y + rng.uniform(-0.05, 0.05), face), crest - 0.02, h, "-z", pc)
    # the bottom rail's own rust bloom, a puddle where the roof is dented
    _skin(f, "Rust", (rng.uniform(-L / 4, L / 4), 0.25, -W / 2), rng.uniform(3, 6), 0.3, "-z", _tone(RUST, rng, 6, 0.1),
          "CorrodedMetal")
    _skin(f, "RoofPool", (rng.uniform(-L / 4, L / 4), H - 0.1, rng.uniform(-1.5, 1.5)), rng.uniform(1.8, 3.0),
          rng.uniform(1.4, 2.2), "y", mix(col, (12, 14, 16), 0.6), reflectance=0.15, disk=True)


@prop({"state": "upright"}, {"state": "tipped"}, {"state": "fire"}, {"state": "upright", "color": (118, 40, 32)})
def oil_drum(D, folder, origin, ry, rng, state=None, color=None, light=True):
    """A 200 L steel drum (58 x 88 cm), dented and rusting, built like a lathe profile of coaxial
    cylinders that never share a cap: the body, two rolling hoops 4 cm proud, the rolled chimes
    top and bottom (the body's ends hidden inside them), the 2" and 3/4" bungs 7 cm up on the
    head; the bottom chime and one hoop rusted through the paint, rust patches and a dent's
    shadow on the shell, a half-torn hazard diamond (marks on planes tangent to the shell).
    `tipped`: on its side over an oil stain. `fire`: a burn barrel: the drum burnt black above,
    filled with embers to 0.55 under the top, the cut-away top a ring of jagged, bent plates
    round them, holes punched round the bottom glowing orange, ash in heaps round its foot;
    tagged like alleys.py's: the body CityFire, a Neon disk "Embers" CityFireEmbers with its
    light and fire (set light=False to leave the light out).
    Footprint 1.9 studs round (tipped 2.8 x 1.9), 2.8 tall. 10-22 parts; body PROP."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["upright", "upright", "tipped", "fire"])
    d, H = 1.85, 2.8
    col = _tone(color or _pick(rng, DRUM), rng, 6, darken=rng.uniform(0.1, 0.35))
    if state == "fire":
        col = mix(col, RUST_DARK, rng.uniform(0.5, 0.8))
    if state == "tipped":
        _disk(f, "OilStain", rng.uniform(-0.4, 0.4), rng.uniform(-1.2, -0.6), rng.uniform(1.8, 2.6), 0.04, OIL,
              "SmoothPlastic", reflectance=0.15)
        f = f.sub((0, d / 2 + 0.04, 0), rz=90, rx=rng.uniform(-3, 3))  # (resting on its hoops)
        f = f.sub((0, -H / 2, 0))
    rusty = mix(col, RUST, rng.uniform(0.4, 0.8))
    top = H - 0.55 if state == "fire" else H - 0.07  # (the body's caps 7 cm inside the chimes)
    if state == "fire":  # rust-brown below, burnt black above (butted, one diameter)
        _vcyl(f, "BurnBarrel", 0, 0.07, 0, H - 1.25 - 0.07, d, col, "CorrodedMetal", flags=PROP,
              extra={"t": ["CityFire"]})
        _vcyl(f, "BurnBarrel", 0, H - 1.25, 0, top - (H - 1.25), d, mix(SOOT, col, 0.25), "CorrodedMetal", flags=PROP)
    else:
        _vcyl(f, "Drum", 0, 0.07, 0, top - 0.07, d, col, "Metal", flags=PROP)
    for k, y in enumerate((H / 3, 2 * H / 3)):
        hc = rusty if (k == 0 and rng.random() < 0.6) else _tone(col, rng, 4, 0.12)
        _vcyl(f, "DrumHoop", 0, y - 0.06, 0, 0.12, d + 0.08, hc, "Metal")
    _vcyl(f, "DrumChime", 0, 0, 0, 0.1, d + 0.06, mix(rusty, RUST_DARK, 0.3), "CorrodedMetal")
    if state != "fire":
        _vcyl(f, "DrumChime", 0, H - 0.1, 0, 0.1, d + 0.06, _tone(col, rng, 4, 0.2), "Metal")
        _vcyl(f, "Bung", d * 0.3, H, 0.1, 0.07, 0.26, _tone(GALVANISED, rng, 8, 0.3), "Metal")
        _vcyl(f, "Bung", -d * 0.32, H, -0.05, 0.07, 0.14, _tone(GALVANISED, rng, 8, 0.3), "Metal")
        # marks on planes tangent to the shell, small enough to hug it
        g = f.sub((0, 0, 0), ry=rng.uniform(-30, 30))
        _skin(g, "HazardLabel", (0, H * 0.5, -d / 2), 0.36, 0.36, "-z",
              _tone(_pick(rng, [(176, 140, 50), (170, 160, 150), (150, 70, 50)]), rng, 8, 0.3), spin=45)
        for _ in range(rng.randint(1, 2)):
            g = f.sub((0, 0, 0), ry=rng.uniform(-180, 180))
            y = _pick(rng, [rng.uniform(0.2, 0.7), rng.uniform(1.05, 1.7), rng.uniform(2.0, 2.5)])
            _skin(g, "Rust", (0, y, -d / 2), rng.uniform(0.25, 0.4), rng.uniform(0.25, 0.5), "-z",
                  _tone(_pick(rng, [RUST, RUST_DARK]), rng, 6), "CorrodedMetal", spin=rng.uniform(-20, 20))
        g = f.sub((0, 0, 0), ry=rng.uniform(-180, 180))
        _skin(g, "Dent", (0, rng.uniform(0.3, 0.75) * H, -d / 2), 0.4, 0.3, "-z", _tone(col, rng, 4, 0.3), "Metal",
              spin=rng.uniform(0, 90))
        return
    # the burn barrel: embers to 0.55 under the top, the jagged ring of the cut-away top
    for i in range(8):
        a = i * 45 + rng.uniform(-4, 4)
        g = f.sub((0, top, 0), ry=a)
        hh = rng.uniform(0.3, 0.55)
        g.part("CutEdge", (0, hh / 2 - 0.02, -d / 2 + 0.04), (0.72, hh, 0.06), _tone(mix(SOOT, RUST_DARK, 0.4), rng, 5),
               "CorrodedMetal", rot=(rng.uniform(-14, -4), 0, rng.uniform(-10, 10)))
    for i in range(rng.randint(3, 5)):
        g = f.sub((0, rng.uniform(0.35, 0.8), 0), ry=rng.uniform(0, 360))
        glow = i < 2
        g.part("BarrelHole", (0, 0, -d / 2 + 0.02), (0.22, 0.2, 0.08), NEON_FIRE if glow else SOOT,
               "Neon" if glow else "SmoothPlastic")
    for _ in range(rng.randint(2, 3)):  # ash in heaps round its foot
        a = math.radians(rng.uniform(0, 360))
        r = d / 2 + rng.uniform(0.35, 0.6)
        _disk(f, "Ash", math.cos(a) * r, math.sin(a) * r, rng.uniform(0.5, 0.9), 0.04, ASH, "Slate")
    ex = {"t": ["CityFireEmbers"]}
    if light:
        ex["l"] = {"type": "Point", "color": [255, 130, 50], "range": 18, "brightness": 1.6, "name": "Light",
                   "shadows": False}
    _vcyl(f, "Embers", 0, top, 0, 0.07, d - 0.2, NEON_FIRE, "Neon", extra=ex)
    # the flames come from an unrotated invisible part, so they rise
    f.box("FireFx", (-0.4, top + 0.1, -0.4), (0.4, top + 0.2, 0.4), NEON_FIRE, "SmoothPlastic", flags=DECOR,
          transparency=1, extra={"fx": "fire"})



# =============================================================================================
# Crates
# =============================================================================================
def _wood_crate(f, rng, w, h, d, col, lid="on", broken=False, flags=PROP):
    """One slatted shipping crate in frame f, standing on y=0 (real: pine boards with 1-2 cm gaps,
    cleats at the corners, a diagonal brace on the ends, nailed lid boards, a stencil):
      • a dark core inside the boards (the gaps between them read as shadow; it's what collides);
      • three boards a side with gaps, BUTT-jointed: the front and back boards run the full width,
        the end boards fit between them, so no two boards share a face;
      • corner cleats on the front and back faces, a diagonal brace 7 cm proud on each end;
      • three lid boards lying ON the walls (or one knocked askew, or the lid gone: the core is
        then half height and the inside shows);
      • a stencil in faded paint on the front, maybe a split board hanging loose."""
    t = 0.08
    core_top = h - 0.05 if lid == "on" else h * 0.5  # an open crate shows its depth
    f.box("CrateCore", (-w / 2 + t, 0.02, -d / 2 + t), (w / 2 - t, core_top, d / 2 - t), (26, 22, 18), "Wood",
          flags=flags)
    n, gap = 3, 0.07
    bh = (h - gap * (n - 1) - 0.02) / n
    split = rng.randrange(2 * n) if broken else -1
    for i in range(n):
        y0 = 0.02 + i * (bh + gap)
        for s in (-1, 1):
            z0 = -d / 2 if s < 0 else d / 2 - t
            if i * 2 + (s > 0) == split:  # a split board: half of it hanging off one nail
                g = f.sub((-w / 4, y0 + bh, z0 + t / 2), ry=rng.choice((-1, 1)) * rng.uniform(4, 8), rz=rng.uniform(8, 20))
                g.box("CrateBoard", (0, -bh, -t / 2), (w * 0.5, 0, t / 2), _tone(col, rng, 8, 0.1), "WoodPlanks")
            else:
                f.box("CrateBoard", (-w / 2, y0, z0), (w / 2, y0 + bh, z0 + t), _tone(col, rng, 8), "WoodPlanks")
            x0 = -w / 2 if s < 0 else w / 2 - t
            f.box("CrateBoard", (x0, y0, -d / 2 + t), (x0 + t, y0 + bh, d / 2 - t), _tone(col, rng, 8), "WoodPlanks")
    cc = _tone(col, rng, 6, 0.12)
    for sz in (-1, 1):  # corner cleats, outside the front and back boards
        if sz > 0 and rng.random() < 0.5:
            continue
        z0 = -d / 2 - 0.08 if sz < 0 else d / 2
        for sx in (-1, 1):
            x0 = -w / 2 if sx < 0 else w / 2 - 0.16
            f.box("CrateBatten", (x0, 0, z0), (x0 + 0.16, h, z0 + 0.08), _tone(cc, rng, 4), "Wood")
    for sx in (-1, 1):  # the diagonal brace on each end (7 cm proud: never near-coplanar)
        x = sx * (w / 2 + 0.035)
        a, b = (x, 0.12, -d / 2 + 0.2), (x, h - 0.12, d / 2 - 0.2)
        if sx > 0:
            a, b = (x, 0.12, d / 2 - 0.2), (x, h - 0.12, -d / 2 + 0.2)
        g = Frame(f.D, f.folder, f.world(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)),
                  matrix=f.m @ yxz_matrix(math.degrees(math.atan2(b[1] - a[1], -(b[2] - a[2]))), 0, 0))
        ln = math.hypot(b[1] - a[1], b[2] - a[2]) - 0.1
        g.box("CrateBrace", (-0.035, -0.08, -ln / 2), (0.035, 0.08, ln / 2), _tone(cc, rng, 4), "Wood")
    if lid != "off":
        nb = 3
        bw = (w - 0.08) / nb
        askew = rng.randrange(nb) if lid == "loose" else -1
        for i in range(nb):
            x = -w / 2 + 0.04 + bw * (i + 0.5)
            if i == askew:
                f.part("CrateLid", (x + rng.uniform(0.2, 0.5), h + 0.14, rng.uniform(-0.3, 0.3)), (bw - 0.06, 0.08, d + 0.1),
                       _tone(col, rng, 8, 0.05), "WoodPlanks",
                       rot=(rng.uniform(-6, 6), rng.uniform(-25, 25), rng.uniform(4, 12)))
            else:
                f.box("CrateLid", (x - bw / 2 + 0.03, h, -d / 2), (x + bw / 2 - 0.03, h + 0.08, d / 2),
                      _tone(col, rng, 8, 0.05), "WoodPlanks")
    if rng.random() < 0.7:  # a stencilled mark: a couple of strokes in faded black paint
        sx, sy = rng.uniform(-0.15, 0.15) * w, h * rng.uniform(0.45, 0.6)
        for k in range(2):
            _skin(f, "Stencil", (sx + k * w * 0.16, sy, -d / 2), w * rng.uniform(0.1, 0.18), h * 0.1, "-z",
                  mix(col, (30, 26, 22), 0.75), spin=rng.uniform(-2, 2))


@prop({"count": 1}, {"count": 2}, {"count": 3}, {"count": 3, "wet": True})
def wooden_crates(D, folder, origin, ry, rng, count=None, wet=None):
    """Wooden shipping crates made of boards: one, two side by side, or three (two on the ground,
    one on top turned askew, resting on the taller one's lid); lids on, loose (a board knocked
    sideways) or gone, a split board, stencils, the wood greyed by weather (`wet`: dark and damp
    at the bottom). Footprint ~2.4 x 2.2 studs each (3: ~5 x 2.6), 2-2.5 tall a crate (stacked
    4.5). 25-90 parts; each crate's core PROP (climbable)."""
    f = Frame(D, folder, origin, ry=ry)
    count = count or rng.randint(1, 3)
    wet = (rng.random() < 0.3) if wet is None else wet
    base = _tone(_pick(rng, CRATE_WOOD), rng, 6, darken=rng.uniform(0.1, 0.3))
    if wet:
        base = mix(base, (50, 44, 36), 0.4)
    spots = [(0, 0, 0)] if count == 1 else [(-1.35, 0, 0), (1.35, 0, rng.uniform(-0.3, 0.3))]
    tops = []
    for i in range(min(count, 2)):
        w, h, d = rng.uniform(2.2, 2.5), rng.uniform(1.9, 2.4), rng.uniform(2.0, 2.3)
        x, _, z = spots[i]
        g = f.sub((x, 0, z), ry=rng.uniform(-6, 6))
        lid = "on" if count >= 3 else _pick(rng, ["on", "on", "loose", "off"])
        _wood_crate(g, rng, w, h, d, _tone(base, rng, 6), lid=lid, broken=rng.random() < 0.3)
        tops.append((h + 0.08, x))
        if wet:
            _grime(g, -w / 2 + 0.17, w / 2 - 0.17, 0.0, 0.5, -d / 2, "-z", base, rng)  # (between the cleats)
    if count >= 3:  # on the taller one's lid, turned
        top, x = max(tops)
        g = f.sub((x * 0.6, top, rng.uniform(-0.2, 0.2)), ry=rng.uniform(-25, 25))
        _wood_crate(g, rng, rng.uniform(2.0, 2.3), rng.uniform(1.8, 2.1), rng.uniform(1.9, 2.1), _tone(base, rng, 6),
                    lid=_pick(rng, ["on", "loose"]))


def _plastic_crate(f, rng, col, w, d, h):
    """A stackable plastic produce crate (a Euro 600 x 400): the long walls a solid lower panel,
    a row of open slots (ribs between the panel and the thick rim) you can see through; the short
    ends solid with a real cut-through hand hole under the top edge; the floor between the walls.
    Every piece butts its neighbours (no crossing walls, no plate on a wall). 22 parts; the
    lower panels SMALL."""
    t = 0.07
    yl, yr = h * 0.42, h - 0.2  # the slot band
    fade = mix(col, (200, 200, 196), 0.12)  # the rim, sun-faded
    for s in (-1, 1):
        z0 = -d / 2 if s < 0 else d / 2 - t
        f.box("PlasticCrate", (-w / 2, 0, z0), (w / 2, yl, z0 + t), _tone(col, rng, 3), "Plastic", flags=SMALL)
        f.box("CrateRim", (-w / 2, yr, z0), (w / 2, h, z0 + t), _tone(fade, rng, 3), "Plastic")
        for k in range(5):  # the two corner ribs and three between: four slots
            x = -w / 2 + t / 2 + (w - t) * k / 4
            f.box("CrateRib", (x - t / 2, yl, z0), (x + t / 2, yr, z0 + t), _tone(col, rng, 3), "Plastic")
        x0 = -w / 2 if s < 0 else w / 2 - t  # the short end: panel, the hand hole under the top strip
        f.box("PlasticCrate", (x0, 0, -d / 2 + t), (x0 + t, yr, d / 2 - t), _tone(col, rng, 3), "Plastic", flags=SMALL)
        for u in (-1, 1):
            z1 = -d / 2 + t if u < 0 else 0.3
            z2 = -0.3 if u < 0 else d / 2 - t
            f.box("CrateRim", (x0, yr, z1), (x0 + t, h - 0.07, z2), _tone(fade, rng, 3), "Plastic")
        f.box("CrateRim", (x0, h - 0.07, -d / 2 + t), (x0 + t, h, d / 2 - t), _tone(fade, rng, 3), "Plastic")
    f.box("CrateFloor", (-w / 2 + t, 0, -d / 2 + t), (w / 2 - t, 0.07, d / 2 - t), _tone(col, rng, 3, 0.15), "Plastic")


@prop({"count": 2}, {"count": 4}, {"count": 6})
def plastic_crates(D, folder, origin, ry, rng, count=None, color=None):
    """Stackable plastic produce crates, sun-faded and scuffed: a stack (each crate resting on the
    rim of the one below, turned a little, the colours mismatched), one dropped on its side next
    to it in front (-Z), marker scrawl on a front.
    Footprint 2 x 1.33 studs (+ the dropped one ~2.2 in front), 0.9 a crate. 22-140 parts;
    the crates' lower panels SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    count = count or rng.randint(2, 6)
    base = color or _pick(rng, PLASTIC_CRATE)
    w, d, h = 2.0, 1.33, 0.9
    stack = count - (1 if count >= 3 and rng.random() < 0.7 else 0)
    y = 0.0
    for i in range(stack):
        col = _tone(base if rng.random() < 0.75 else _pick(rng, PLASTIC_CRATE), rng, 8, darken=rng.uniform(0.05, 0.3))
        g = f.sub((rng.uniform(-0.06, 0.06), y, rng.uniform(-0.06, 0.06)), ry=rng.uniform(-6, 6))

        def crate(g=g, col=col):
            _plastic_crate(g, rng, col, w, d, h)
            if rng.random() < 0.35:
                _skin(g, "Marker", (rng.uniform(-0.4, 0.4), h * 0.22, -d / 2), rng.uniform(0.4, 0.8), 0.12, "-z",
                      (24, 24, 26), spin=rng.uniform(-8, 8))

        frame_meshprop(D, folder, "PlasticCrate", g.sub((0, 0.004 * i, 0)), crate, lib=True, tint=col)
        y += h
    if stack < count:
        # (in front of the stack, -Z: the side away from the wall the stack stands against)
        # (on its side its height runs back toward the stack: its bottom is h + 0.55..0.85 in front)
        g = f.sub((rng.uniform(-0.3, 0.3), d / 2, -d / 2 - h - rng.uniform(0.55, 0.85)), ry=rng.uniform(-20, 20),
                  rx=90)
        col = _tone(base, rng, 8, 0.2)
        frame_meshprop(D, folder, "PlasticCrate", g, lambda: _plastic_crate(g, rng, col, w, d, h), lib=True, tint=col)


# =============================================================================================
# The black market: tables, the canopy, the goods (NOTHING bottle-like)
# =============================================================================================
def _table(D, folder, origin, ry, rng, kind=None, cloth=None, w=None, d=None, clear=()):
    """Builds a folding table (see folding_table) and returns the height of its real top surface
    above origin (the cloth's top when there is one): goods go on it + 0.01. `clear`: local
    rectangles (x0, x1, z0, z1) where goods will stand, kept free of stains and marks."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["plastic", "plastic", "wood"])
    cloth = (rng.random() < 0.4) if cloth is None else cloth
    W = w or rng.uniform(5.0, 6.4)
    Dp = d or rng.uniform(2.4, 2.8)
    H = 2.45  # (74 cm)

    def spot(r):
        """A random point on the top at least r from the edges and from the goods (or None)."""
        for _ in range(12):
            x, z = rng.uniform(-W / 2 + r + 0.1, W / 2 - r - 0.1), rng.uniform(-Dp / 2 + r + 0.1, Dp / 2 - r - 0.1)
            if all(not (x0 - r < x < x1 + r and z0 - r < z < z1 + r) for x0, x1, z0, z1 in clear):
                return x, z
        return None

    marks = []  # (name, size, colour, material) laid on the top
    if kind == "plastic":
        # A 6 ft blow-moulded table: the top 4.5 cm thick in two halves butted at the middle hinge,
        # dead flat (goods stand on it), with a moulded skirt under its edge; two folding steel leg
        # frames with plastic foot caps, a cross tube and a brace with its lock ring.
        top = _tone((150, 148, 140), rng, 10, darken=rng.uniform(0.1, 0.35))
        th, sk = 0.15, 0.08
        for s in (-1, 1):
            f.box("TableTop", (min(0, s * W / 2), H - th, -Dp / 2), (max(0, s * W / 2), H, Dp / 2), _tone(top, rng, 3),
                  "Plastic", flags=PROP)
        skirt = mix(top, (0, 0, 0), 0.08)
        f.box("TableSkirt", (-W / 2, H - th - 0.14, -Dp / 2), (W / 2, H - th, -Dp / 2 + sk), skirt, "Plastic")
        f.box("TableSkirt", (-W / 2, H - th - 0.14, Dp / 2 - sk), (W / 2, H - th, Dp / 2), skirt, "Plastic")
        for s in (-1, 1):
            x0 = s * W / 2 - (sk if s > 0 else 0)
            f.box("TableSkirt", (x0, H - th - 0.14, -Dp / 2 + sk), (x0 + sk, H - th, Dp / 2 - sk), skirt, "Plastic")
        legc = _tone(GALVANISED, rng, 8, darken=rng.uniform(0.2, 0.45))
        for u in (-1, 1):  # the two steel rails under the top
            z = u * (Dp / 2 - 0.4)
            f.box("TableFrame", (-W / 2 + 0.3, H - th - 0.09, z - 0.05), (W / 2 - 0.3, H - th, z + 0.05), IRON, "Metal")
        f.box("TableFrame", (-W / 2 + 0.3, H - th - 0.08, -0.04), (W / 2 - 0.3, H - th, 0.04), IRON, "Metal")
        cap = _tone((40, 40, 42), rng, 4)
        for s in (-1, 1):
            x = s * (W / 2 - 0.55)
            for u in (-1, 1):
                z = u * (Dp / 2 - 0.4)
                _vcyl(f, "TableLeg", x, 0.06, z, H - th - 0.09 - 0.06, 0.09, legc, "Metal")
                _vcyl(f, "FootCap", x, 0.0, z, 0.12, 0.14, cap, "Plastic")
            _rod(f, "TableLeg", (x, H - 0.75, -(Dp / 2 - 0.4)), (x, H - 0.75, Dp / 2 - 0.4), 0.08, legc, "Metal")
            b0, b1 = (x, H - 0.75, 0), (x * 0.5, H - th - 0.04, 0)
            _rod(f, "TableBrace", b0, b1, 0.07, legc, "Metal")
            r0 = tuple(b0[i] + (b1[i] - b0[i]) * 0.62 for i in range(3))
            r1 = tuple(b0[i] + (b1[i] - b0[i]) * 0.76 for i in range(3))
            _rod(f, "LockRing", r0, r1, 0.13, _tone(legc, rng, 4, 0.1), "Metal")
        # hands rub the front edge; pen marks, a cigarette burn, a grimy patch on the top
        _skin(f, "Scuff", (rng.uniform(-0.6, 0.6), H - th - 0.07, -Dp / 2), W * rng.uniform(0.4, 0.7), 0.1, "-z",
              mix(skirt, GRIME, 0.35))
        if not cloth:
            marks = [("Stain", rng.uniform(0.5, 0.9), mix(top, GRIME, 0.3), "SmoothPlastic"),
                     ("Burn", 0.12, (40, 30, 24), "SmoothPlastic"),
                     ("PenMark", 0.5, _pick(rng, [(40, 50, 90), (30, 30, 34), (120, 40, 40)]), "SmoothPlastic")]
    else:
        # An old flush door laid on two sawhorses: painted once, chipped to the wood, its knob bore
        # and latch plate on one long edge, the hinge leaves on the other.
        th = 0.14
        paint = _pick(rng, [(150, 146, 132), (70, 90, 72), (110, 84, 60), (120, 112, 96)])
        top = _tone(paint, rng, 6, darken=rng.uniform(0.1, 0.3))
        f.box("TableTop", (-W / 2, H - th, -Dp / 2), (W / 2, H, Dp / 2), top, "Wood", flags=PROP)
        brass = _tone((150, 124, 70), rng, 8, 0.3)
        kx = rng.uniform(-0.1, 0.1) * W
        for k, x in enumerate((-W * 0.4, 0.0, W * 0.4)):
            _skin(f, "Hinge", (x + rng.uniform(-0.05, 0.05), H - th / 2, -Dp / 2), 0.32, 0.1, "-z", brass, "Metal")
        _skin(f, "LatchPlate", (kx, H - th / 2, Dp / 2), 0.36, 0.08, "+z", brass, "Metal")
        legc = _tone(WOOD, rng, 6, darken=rng.uniform(0.1, 0.3))
        for s in (-1, 1):  # the sawhorses: a beam under the door, four splayed legs
            x = s * (W / 2 - 0.9)
            f.box("Trestle", (x - 0.12, H - th - 0.26, -Dp / 2 + 0.1), (x + 0.12, H - th, Dp / 2 - 0.1), legc, "Wood")
            for u in (-1, 1):
                for v in (-1, 1):
                    _bar(f, "TrestleLeg", (x + v * 0.45, 0.06, u * (Dp / 2 - 0.08)),
                         (x + v * 0.06, H - th - 0.2, u * (Dp / 2 - 0.3)), 0.16, 0.14, _tone(legc, rng, 5), "Wood")
        if not cloth:
            marks = [("KnobHole", 0.2, (20, 18, 16), "SmoothPlastic", (kx, Dp / 2 - 0.22)),
                     ("Chip", rng.uniform(0.3, 0.6), _tone(WOOD_FRESH, rng, 8, 0.2), "Wood"),
                     ("Chip", rng.uniform(0.2, 0.4), _tone(WOOD_FRESH, rng, 8, 0.25), "Wood"),
                     ("Stain", rng.uniform(0.5, 0.8), mix(top, GRIME, 0.35), "SmoothPlastic")]
    surface = H
    if cloth:  # a sheet over the top (one flush surface), its front edge hanging down
        cc = _tone(_pick(rng, FABRIC + [(120, 110, 96)]), rng, 6, darken=rng.uniform(0, 0.2))
        f.box("TableCloth", (-W / 2 - 0.06, H, -Dp / 2 - 0.06), (W / 2 + 0.06, H + 0.04, Dp / 2 + 0.06), cc, "Fabric")
        surface = H + 0.04
        hang = rng.uniform(1.2, 2.0)
        g = f.sub((rng.uniform(-0.2, 0.2), surface - 0.02, -Dp / 2 - 0.06), rx=rng.uniform(3, 7), rz=rng.uniform(-2, 2))
        dw = W * rng.uniform(0.85, 1.0)
        g.box("TableCloth", (-dw / 2, -hang, -0.04), (dw / 2, 0, 0), _tone(cc, rng, 4, 0.06), "Fabric")
        marks = [("Stain", rng.uniform(0.6, 1.0), mix(cc, (60, 46, 34), 0.45), "Fabric"),
                 ("Stain", rng.uniform(0.3, 0.5), mix(cc, (60, 46, 34), 0.3), "Fabric")]
    for m in marks:
        name, size, col, mat = m[:4]
        p = m[4] if len(m) > 4 else spot(size / 2 + 0.05)
        if p is None:
            continue
        if name == "PenMark":
            _skin(f, name, (p[0], surface, p[1]), size, 0.04, "y", col, mat, spin=rng.uniform(0, 180))
        else:
            _skin(f, name, (p[0], surface, p[1]), size, size, "y", col, mat, disk=True)
    return surface


@prop({}, {"cloth": True}, {"kind": "wood"}, {"kind": "wood", "cloth": True})
def folding_table(D, folder, origin, ry, rng, kind=None, cloth=None, w=None, d=None, clear=()):
    """A folding trestle table: a 6 ft blow-moulded plastic top (two halves butted at the hinge, a
    moulded skirt under the edge) on two folding steel leg frames with foot caps, the cross tube
    and the brace with its lock ring; or an old flush door (knob bore, latch plate, hinge leaves,
    paint chipped to the wood) on two sawhorses (`kind="wood"`); `cloth`: a sheet over the top,
    its front edge hanging down. The top is dead flat: goods stand on it (market_stall puts them
    at its real surface + 0.01: 2.45, or 2.49 with the cloth). `clear`: rectangles kept free of
    marks (where the goods go). Footprint w (5-6.4) x d (2.4-2.8) studs, 2.45 tall.
    20-27 parts (plastic), 14-17 (door); the top PROP."""
    _table(D, folder, origin, ry, rng, kind=kind, cloth=cloth, w=w, d=d, clear=clear)


@prop({}, {"w": 10, "d": 7}, {"light": False, "torn": True})
def market_canopy(D, folder, origin, ry, rng, w=None, d=None, light=True, torn=None, color=None, pin=False):
    """A makeshift stall canopy: one woven tarp stretched over four mismatched poles (scaffold
    tube, a length of timber, conduit) footed in cinder blocks and a bucket of concrete, higher at
    the front, sagging in the middle where rain pools (a dark wet patch), its front edge hanging
    in ragged flaps, guy ropes to pegs at the front corners, patches of tape, maybe a torn hole; a
    bare bulb hanging under it on its flex (`light`: a weak warm PointLight).
    The sheet is five strips of one colour following the sag (each tilted differently, so no two
    faces are coplanar); the pool, the tape and the hole lie on their strip, in its frame.
    Footprint w x d (default ~8 x 6) studs + 1.5 for the ropes, 6.5-7.8 tall. 27-34 parts;
    poles SMALL, the tarp DECOR_SHADOW (too high to touch).
    `pin`: the poles exactly at the corners and plumb (the same rng draws, unused), so they match
    the kit's MarketTarp when they are its collision proxies."""
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
            if pin:
                x, z = sx * W / 2, sz * Dp / 2
            corners[(sx, sz)] = (x, h, z)
            kind = rng.randrange(3)
            lean = (x + rng.uniform(-0.25, 0.25), 0.15, z + rng.uniform(-0.25, 0.25))  # (its foot inside the block)
            if pin:
                lean = (x, 0.15, z)
            if kind == 0:
                _rod(f, "CanopyPole", lean, (x, h, z), 0.2, _tone(GALVANISED, rng, 8, 0.3), "Metal", flags=SMALL)
            elif kind == 1:
                _bar(f, "CanopyPole", lean, (x, h, z), 0.28, 0.28, _tone(WOOD_OLD, rng, 6), "Wood", flags=SMALL)
            else:
                _rod(f, "CanopyPole", lean, (x, h, z), 0.14, _tone((150, 150, 146), rng, 8, 0.3), "Plastic",
                     flags=SMALL)
            if rng.random() < 0.6:
                f.box("PoleFoot", (lean[0] - 0.5, 0, lean[2] - 0.35), (lean[0] + 0.5, 0.65, lean[2] + 0.35),
                      _tone(CONCRETE, rng, 8, 0.1), "Concrete", flags=SMALL, rot=(0, rng.uniform(-30, 30), 0))
            else:
                _vcyl(f, "PoleFoot", lean[0], 0, lean[2], 0.9, 0.8,
                      _tone(_pick(rng, [(60, 60, 62), (130, 90, 40)]), rng, 6), "Plastic", flags=SMALL)
    # the tarp: five strips across the width following the sag curve, sloping back
    n = 5
    sag = rng.uniform(0.6, 1.0)
    Wt = W + 0.4
    xs = [-Wt / 2 + Wt * i / n for i in range(n + 1)]
    hs = [-sag * (1 - (2 * i / n - 1) ** 2) for i in range(n + 1)]
    pitch = math.degrees(math.atan2(hf - hb, Dp))
    ymid = (hf + hb) / 2 + 0.12
    Dt = Dp + 0.6
    strips = []
    for i in range(n):
        x0, x1, h0, h1 = xs[i], xs[i + 1], hs[i], hs[i + 1]
        roll = math.degrees(math.atan2(h1 - h0, x1 - x0))
        ln = math.hypot(x1 - x0, h1 - h0)
        g = f.sub(((x0 + x1) / 2, ymid + (h0 + h1) / 2, 0), rx=pitch, rz=roll)
        g.part("Tarp", (0, 0, 0), (ln + 0.05, 0.06, Dt), tc, "Fabric", flags=DECOR_SHADOW)
        strips.append((g, ln, (x0 + x1) / 2))
    mid, mln, _ = strips[n // 2]  # the flat middle strip, where the rain pools
    _skin(mid, "TarpPool", (rng.uniform(-0.2, 0.2), 0.03, rng.uniform(-0.6, 0.6)), mln * rng.uniform(0.6, 0.8),
          rng.uniform(1.2, 2.0), "y", mix(tc, (10, 12, 14), 0.6), reflectance=0.15, spin=rng.uniform(-6, 6))
    for _ in range(rng.randint(1, 2)):
        g, ln, _ = _pick(rng, strips)
        _skin(g, "TarpTape", (rng.uniform(-ln / 4, ln / 4), 0.03, rng.uniform(-Dp / 3, Dp / 3)), rng.uniform(0.6, 1.0),
              0.22, "y", _tone(DUCT, rng, 8), "Fabric", spin=rng.uniform(0, 180))
    if torn:  # a dark tear, seen from above and from below
        g, ln, _ = strips[_pick(rng, [0, 1, n - 2, n - 1])]
        x, z = rng.uniform(-ln / 4, ln / 4), rng.uniform(-1, 1)
        tw, td = rng.uniform(0.5, 0.8), rng.uniform(0.3, 0.6)
        _skin(g, "TarpHole", (x, 0.03, z), tw, td, "y", (12, 12, 14))
        under = g.sub((0, -0.03, 0), rz=180)
        _skin(under, "TarpHole", (-x, 0, z), tw, td, "y", (12, 12, 14))
    # the ragged front valance: flaps hanging from the strips' front edges
    for g, ln, xc0 in strips:
        if rng.random() < 0.15:
            continue
        fw = ln * rng.uniform(0.85, 0.98)
        hang = rng.uniform(0.25, 0.8)
        hp = g.world((rng.uniform(-(ln - fw) / 2, (ln - fw) / 2), -0.03, -Dt / 2 + 0.05))
        # (hanging nearly plumb: never parallel to the pitched strip above it)
        hinge = Frame(D, folder, hp, matrix=f.m @ yxz_matrix(-rng.uniform(2, 8), 0, rng.uniform(-5, 5)))
        hinge.box("TarpFlap", (-fw / 2, -hang, -0.04), (fw / 2, 0, 0), _tone(tc, rng, 2, 0.04), "Fabric")
    # guy ropes to pegs at the front corners
    for sx in (-1, 1):
        x, h, z = corners[(sx, -1)]
        peg = (x + sx * rng.uniform(0.6, 1.2), 0.15, z - rng.uniform(1.0, 1.6))
        _rod(f, "GuyRope", (x, h - 0.1, z), peg, 0.06, _tone((120, 110, 90), rng, 8), "Fabric")
        _vcyl(f, "Peg", peg[0], 0, peg[2], 0.3, 0.12, IRON, "Metal")
    # the bulb on its flex, hanging from the middle strip
    bx, bz = rng.uniform(-0.4, 0.4), rng.uniform(-0.8, 0.8)
    top = mid.world((bx, -0.03, bz))
    drop = rng.uniform(1.0, 1.6)
    fl = Frame(D, folder, top)
    _rod(fl, "Flex", (0, 0, 0), (0, -drop, 0), 0.05, (20, 20, 20), "Rubber")
    ex = (
        {"l": {"type": "Point", "color": [255, 186, 120], "range": 14, "brightness": 0.9, "name": "Light",
               "shadows": True}}
        if light
        else None
    )
    _ball(fl, "Bulb", (0, -drop - 0.15, 0), 0.32, (255, 214, 160), "Neon", extra=ex)


def _open_box(f, rng, w, d, h, col, mat, name, t=0.04, b=0.04, flags=DECOR, tone=6):
    """An open box with butt joints: four walls standing on the ground up to h (the front and back
    full width, the two ends fitted between them) and the floor (b thick) fitted inside them. No
    two pieces overlap, so no faces are shared, and every bottom face lies in one plane."""
    for s in (-1, 1):
        z0 = -d / 2 if s < 0 else d / 2 - t
        f.box(name, (-w / 2, 0, z0), (w / 2, h, z0 + t), _tone(col, rng, tone), mat, flags=flags)
        x0 = -w / 2 if s < 0 else w / 2 - t
        f.box(name, (x0, 0, -d / 2 + t), (x0 + t, h, d / 2 - t), _tone(col, rng, tone), mat, flags=flags)
    f.box(name, (-w / 2 + t, 0, -d / 2 + t), (w / 2 - t, b, d / 2 - t), _tone(col, rng, tone, 0.1), mat, flags=flags)


# footprints of the table goods about their origin (w along X, d along Z, studs, lids and
# trailing wires included), for market_stall's layout
GOODS_FOOT = {
    "phone_tray": (1.62, 1.37),
    "watch_case": (1.62, 1.52),
    "cash_box": (1.06, 1.15),  # (the kit's open lid and key tag reach z -0.52..0.60)
    "shoe_boxes": (2.5, 1.5),
}


def _stereo_foot(count):
    return (0.8 * count, 1.0)


@prop({}, {"count": 8})
def phone_tray(D, folder, origin, ry, rng, count=None):
    """A cardboard tray of second-hand (stolen) phones laid out on a table: the tray (base and
    four butted walls, two flaps folded down outside, torn), the phones in two rows (0.26 x 0.52
    x 0.045, the glass and the frame as two same-size layers, no plate on a plate), face up with
    black glass (one cracked pale) or face down showing grey / black / gold / a bright case.
    Footprint 1.62 x 1.37 studs, 0.2 tall. 10-15 parts, DECOR. Origin = the table top."""
    f = Frame(D, folder, origin, ry=ry)
    count = min(8, count or rng.randint(5, 7))
    w, d, h, t, b = 1.5, 1.25, 0.2, 0.04, 0.05
    col = _tone(CARDBOARD, rng, 8, 0.1)
    _open_box(f, rng, w, d, h, col, CARDBOARD_MAT, "Tray", t=t, b=b)  # (b 0.05: a phone 0.012 over it ends >= 0.06 up)
    for side in ("front", _pick(rng, ["left", "right"])):  # flaps folded down outside the walls
        if side == "front":
            g = f.sub((rng.uniform(-0.1, 0.1), h, -d / 2), rx=rng.uniform(12, 30))
            fw = w * rng.uniform(0.7, 0.9)
            g.box("TrayFlap", (-fw / 2, -h * rng.uniform(0.7, 0.95), -0.03), (fw / 2, 0, 0), _tone(col, rng, 6, 0.05),
                  CARDBOARD_MAT)
        else:
            s = 1 if side == "right" else -1
            g = f.sub((s * w / 2, h, rng.uniform(-0.1, 0.1)), rz=-s * rng.uniform(12, 30))
            fd = d * rng.uniform(0.6, 0.85)
            g.box("TrayFlap", (0, -h * rng.uniform(0.7, 0.95), -fd / 2) if s > 0 else (-0.03, -h * 0.8, -fd / 2),
                  (0.03, 0, fd / 2) if s > 0 else (0, 0, fd / 2), _tone(col, rng, 6, 0.05), CARDBOARD_MAT)
    slots = [(i, j) for j in range(2) for i in range(4)]
    rng.shuffle(slots)
    pw, pd = 0.26, 0.52
    iw, idp = w - 2 * t, d - 2 * t
    cracked = rng.random() < 0.6
    for i, j in slots[:count]:
        cx = -iw / 2 + iw * (i + 0.5) / 4 + rng.uniform(-0.02, 0.02)
        cz = -idp / 2 + idp * (j + 0.5) / 2 + rng.uniform(-0.02, 0.02)
        g = f.sub((cx, b + 0.012, cz), ry=rng.uniform(-5, 5))
        up = rng.random() < 0.6
        back = _pick(rng, [(30, 30, 32), (120, 122, 124), (150, 130, 96), (40, 60, 90), (150, 50, 50), (60, 140, 120)])
        if up:  # the black glass face (one cracked pale)
            glass = (110, 116, 120) if cracked else SCREEN
            cracked = False
            g.box("Phone", (-pw / 2, 0, -pd / 2), (pw / 2, 0.05, pd / 2), glass, "Glass", reflectance=0.2)
        else:
            g.box("Phone", (-pw / 2, 0, -pd / 2), (pw / 2, 0.05, pd / 2), _tone(back, rng, 4), "SmoothPlastic",
                  reflectance=0.05)


@prop({}, {"open": False})
def watch_case(D, folder, origin, ry, rng, open=True, count=None):
    """A battered aluminium attache case of watches (45 x 33 cm): a hollow shell (a panel base,
    four butted aluminium walls), chrome ball corner caps, two catches and a handle on the front;
    open: the lid thrown back with its felt lining, the felt floor, two foam rolls with watches
    strapped round them (the strap over the roll, the steel or gold case, the dial), one strap
    hanging over the front edge. Footprint 1.62 x 1.52 studs, 0.38 tall (open: the lid stands
    1.1 up). 22-40 parts, DECOR. Origin = the table top."""
    f = Frame(D, folder, origin, ry=ry)
    count = min(8, count or rng.randint(5, 7))
    w, d, hb, t = 1.5, 1.1, 0.28, 0.065  # (t: the aluminium frame; >= 6 cm keeps butted ends clear)
    shell = _tone((176, 176, 172), rng, 10, darken=rng.uniform(0.05, 0.25))
    for s in (-1, 1):  # four butted walls on the ground; the floor fits inside them
        z0 = -d / 2 if s < 0 else d / 2 - t
        f.box("WatchCase", (-w / 2, 0, z0), (w / 2, hb, z0 + t), _tone(shell, rng, 4), "Metal")
        x0 = -w / 2 if s < 0 else w / 2 - t
        f.box("WatchCase", (x0, 0, -d / 2 + t), (x0 + t, hb, d / 2 - t), _tone(shell, rng, 4), "Metal")
    chrome = _tone((170, 170, 168), rng, 6, 0.1)
    for sx in (-1, 1):
        for sz in (-1, 1):
            for y in (0.06, hb - 0.04):
                _ball(f, "CaseCorner", (sx * (w / 2 - 0.015), y, sz * (d / 2 - 0.015)), 0.085, chrome, "Metal")
    for s in (-1, 1):  # catches (6.5 cm proud) and the handle on its posts
        f.box("CaseCatch", (s * w / 3 - 0.08, hb - 0.15, -d / 2 - 0.065), (s * w / 3 + 0.08, hb - 0.02, -d / 2), IRON,
              "Metal")
        f.box("HandlePost", (s * 0.2 - 0.03, hb * 0.45, -d / 2 - 0.12), (s * 0.2 + 0.03, hb * 0.45 + 0.08, -d / 2),
              (24, 24, 26), "Plastic")
    _cyl(f, "CaseHandle", (0, hb * 0.45 + 0.04, -d / 2 - 0.15), 0.52, 0.07, (24, 24, 26), "Plastic")
    if not open:
        f.box("CaseLid", (-w / 2, hb, -d / 2), (w / 2, hb + 0.1, d / 2), _tone(shell, rng, 4), "Metal")
        for sx in (-1, 1):
            for sz in (-1, 1):
                _ball(f, "CaseCorner", (sx * (w / 2 - 0.015), hb + 0.06, sz * (d / 2 - 0.015)), 0.085, chrome, "Metal")
        _skin(f, "Scuff", (rng.uniform(-0.4, 0.4), hb + 0.1, rng.uniform(-0.2, 0.2)), 0.3, 0.2, "y",
              mix(shell, (60, 60, 58), 0.2), spin=rng.uniform(0, 180))
        return
    felt = _tone((96, 30, 34), rng, 8, darken=rng.uniform(0.1, 0.3))
    iw, idp = w - 2 * t, d - 2 * t
    f.box("CaseFelt", (-iw / 2, 0, -idp / 2), (iw / 2, 0.08, idp / 2), felt, "Fabric")  # the floor, lined
    g = f.sub((0, hb, d / 2), rx=rng.uniform(96, 108))
    g.box("CaseLid", (-w / 2, 0, -d), (w / 2, 0.1, 0), _tone(shell, rng, 4), "Metal")
    g.box("CaseFelt", (-iw / 2, -0.03, -d + t), (iw / 2, 0.0, -t), _tone(felt, rng, 4, 0.1), "Fabric")
    for sx in (-1, 1):
        for z in (-0.035, -d + 0.035):
            _ball(g, "CaseCorner", (sx * (w / 2 - 0.015), 0.05, z), 0.085, chrome, "Metal")
    # two foam rolls lying on the felt, end to end between the walls; the watches strapped on them
    r = 0.09
    slots = [(i, j) for j in range(2) for i in range(4)]
    rng.shuffle(slots)
    used = sorted(slots[:count])
    rows = sorted({j for _, j in used})
    for j in rows:
        z = -0.2 + j * 0.42
        _cyl(f, "WatchRoll", (0, 0.08 + r, z), iw, 2 * r, _tone(felt, rng, 4, 0.2), "Fabric")
    for i, j in used:
        x, z = -iw / 2 + iw * (i + 0.5) / 4, -0.2 + j * 0.42
        gold = rng.random() < 0.3
        cc = (170, 140, 70) if gold else _tone(STEEL, rng, 10)
        strap = _pick(rng, [(30, 26, 22), (70, 46, 30), cc])
        y = 0.08 + r  # the roll's axis
        f.box("WatchStrap", (x - 0.05, y, z - r - 0.03), (x + 0.05, y + r + 0.02, z + r + 0.03), strap,
              "Metal" if strap == cc else "Leather")
        _vcyl(f, "WatchFace", x, y + r + 0.02, z, 0.04, 0.19, cc, "Metal", reflectance=0.2)
        _vcyl(f, "WatchDial", x, y + r + 0.06, z, 0.025, 0.15, _pick(rng, [(20, 20, 24), (210, 206, 196), (30, 46, 80)]),
              "Glass", reflectance=0.15)
    x = _pick(rng, [-0.45, 0.45]) + rng.uniform(-0.05, 0.05)  # a strap hanging over the front wall
    _bar(f, "WatchStrap", (x, 0.1, -d / 2 + 0.2), (x + 0.02, hb + 0.03, -d / 2 + 0.02), 0.1, 0.03, (40, 30, 24),
         "Leather")
    _bar(f, "WatchStrap", (x + 0.02, hb + 0.03, -d / 2 - 0.04), (x + 0.06, hb - 0.26, -d / 2 - 0.09), 0.1, 0.03,
         (40, 30, 24), "Leather")
    _skin(g, "Scuff", (rng.uniform(-0.4, 0.4), 0.1, -d / 2), 0.3, 0.2, "y", mix(shell, (60, 60, 58), 0.2),
          spin=rng.uniform(0, 180))


@prop({}, {"count": 6}, {"count": 3, "open": True})
def shoe_boxes(D, folder, origin, ry, rng, count=None, open=None):
    """Sneaker boxes, the knock-off kind (33 x 20 x 12 cm): a stack and a couple beside it, each a
    body with a deeper lid in another colour sitting on it (overhanging 1 cm all round) and a
    white label at the end; one open (`open`): a hollow box (base, butted walls) with crumpled
    tissue paper in it below the rim, its lid leaning against its back. Footprint ~2.5 x 1.5
    studs, up to 2.2 tall. 4-16 parts; DECOR_SHADOW (the floor stack's bottom box SMALL)."""
    f = Frame(D, folder, origin, ry=ry)
    count = count or rng.randint(3, 6)
    open = (rng.random() < 0.6) if open is None else open
    bw, bh, bd, lh, ov = 1.1, 0.42, 0.67, 0.13, 0.03
    stack = max(1, count - rng.randint(1, 2)) if count > 2 else count
    y = 0.0
    for i in range(count):
        if i < stack:
            x, z, yy = -0.6 + rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05), y
            y += bh
            yaw = rng.uniform(-8, 8)
        else:
            k = i - stack
            x, z, yy = 0.75 + k * 0.05, -0.05 + k * 0.05, k * bh
            yaw = rng.uniform(-8, 8) + 90 * (k % 2)
        g = f.sub((x, yy, z), ry=yaw)
        col = mix(_tone(_pick(rng, SHOEBOX), rng, 8, darken=rng.uniform(0.25, 0.45)), CARDBOARD_DARK, 0.2)
        lc = mix(_tone(_pick(rng, SHOEBOX), rng, 8, darken=0.3), CARDBOARD_DARK, 0.15)
        is_open = open and i == count - 1 and (i >= stack or i == stack - 1)
        fl = SMALL if i == 0 else DECOR_SHADOW
        if is_open:
            _open_box(g, rng, bw, bd, bh - 0.02, col, CARDBOARD_MAT, "ShoeBox", t=0.03, b=0.03, flags=fl, tone=3)
            for k in range(rng.randint(2, 3)):  # crumpled tissue, below the rim
                g.part("Tissue", (rng.uniform(-0.25, 0.25), 0.12 + k * 0.05, rng.uniform(-0.1, 0.1)),
                       (bw * rng.uniform(0.45, 0.65), 0.03, bd * rng.uniform(0.5, 0.7)),
                       _tone((205, 202, 194), rng, 6), "Fabric", rot=(rng.uniform(-12, 12), rng.uniform(-20, 20),
                                                                       rng.uniform(-12, 12)))
            a = rng.uniform(12, 20)  # its lid stood on edge, leaning back, behind it
            lid = g.sub((0, lh * math.sin(math.radians(a)) + 0.01, bd / 2 + 0.04), rx=a)
            lid.box("ShoeBoxLid", (-bw / 2 - ov, 0, 0), (bw / 2 + ov, bd + 2 * ov, lh), lc, CARDBOARD_MAT)
        else:
            g.box("ShoeBox", (-bw / 2, 0, -bd / 2), (bw / 2, bh - lh, bd / 2), col, CARDBOARD_MAT, flags=fl)
            g.box("ShoeBoxLid", (-bw / 2 - ov, bh - lh, -bd / 2 - ov), (bw / 2 + ov, bh, bd / 2 + ov), lc,
                  CARDBOARD_MAT, flags=fl)
            if rng.random() < 0.6:
                _skin(g, "Label", (bw / 2, (bh - lh) * 0.5, 0), 0.4, 0.16, "+x", (200, 198, 190))


@prop({}, {"count": 3})
def car_stereos(D, folder, origin, ry, rng, count=None):
    """Car stereos ripped out of dashboards: single or double DIN units side by side (the metal
    chassis, the face plate a little bigger in front of it, a glass display 4 cm proud, the volume knob, a row of buttons), the cut loom behind: the ISO plug and coloured
    wires trailing on the table. Footprint 0.8 per unit x 1.0 studs, 0.2-0.4 tall. 8-10 parts a
    unit, DECOR. Origin = the table top."""
    f = Frame(D, folder, origin, ry=ry)
    count = count or rng.randint(2, 3)
    for i in range(count):
        g = f.sub(((i - (count - 1) / 2) * 0.8, 0, -0.1 + rng.uniform(-0.03, 0.03)), ry=rng.uniform(-6, 6))
        dd = rng.random() < 0.6  # double DIN
        ch, ph = (0.34, 0.36) if dd else (0.17, 0.19)
        g.box("CarStereo", (-0.3, 0, -0.22), (0.3, ch, 0.28), _tone((60, 60, 62), rng, 6), "Metal")
        g.box("StereoFace", (-0.32, 0, -0.28), (0.32, ph, -0.22), _tone((22, 22, 24), rng, 3), "SmoothPlastic")
        dy = ph - (0.13 if dd else 0.11)
        g.box("StereoDisplay", (-0.22, dy, -0.32), (0.12, dy + (0.07 if dd else 0.05), -0.28), _pick(rng, [(40, 56, 60), (20, 30, 50)]),
              "Glass", reflectance=0.15)
        _cyl(g, "StereoKnob", (0.22, ph * 0.45, -0.32), 0.1, 0.12, (80, 80, 82), "Metal", rot=(0, 90, 0))
        g.box("StereoButtons", (-0.22, 0.03, -0.32), (0.1, 0.06, -0.28), (60, 60, 64), "SmoothPlastic")
        g.box("ISOPlug", (-0.12, 0.04, 0.28), (0.1, 0.12, 0.36), (30, 30, 30), "Plastic")
        for k in range(rng.randint(1, 3)):
            _rod(g, "Wire", (-0.08 + k * 0.07, 0.08, 0.36),
                 (-0.1 + k * 0.1 + rng.uniform(-0.1, 0.1), 0.025, 0.62 + rng.uniform(0, 0.1)), 0.04,
                 _pick(rng, [(150, 40, 30), (180, 160, 40), (30, 30, 30), (40, 80, 150)]), "Plastic")


@prop({}, {"color": (120, 120, 124)})
def radio(D, folder, origin, ry, rng, color=None):
    """An 80s boombox: the body (a chamfered top front edge), two speakers (a chrome ring, the
    dark cone 4 cm in front of it, the dust cap), the cassette door and the tuning strip between
    them, a carry handle on two posts with tape wound round it, a telescopic aerial pulled half
    out and bent; scuffed low on the front. Footprint 2 x 0.65 studs, 1.2 tall (aerial to 2).
    19 parts, DECOR. Origin = the table top / floor."""
    f = Frame(D, folder, origin, ry=ry)
    col = _tone(
        color or _pick(rng, [(40, 40, 42), (120, 120, 124), (70, 70, 74)]), rng, 6, darken=rng.uniform(0.05, 0.25)
    )
    w, h, d, hl = 2.0, 0.92, 0.65, 0.72
    f.box("Boombox", (-w / 2, 0, -d / 2), (w / 2, hl, d / 2), col, "SmoothPlastic", flags=DECOR_SHADOW)
    f.box("Boombox", (-w / 2, hl, -d / 2 + 0.14), (w / 2, h, d / 2), col, "SmoothPlastic")
    f.part("Boombox", (0, (hl + h) / 2, -d / 2 + 0.07), (w, h - hl, 0.14), col, "SmoothPlastic", shape=WEDGE)
    for s in (-1, 1):
        _cyl(f, "SpeakerRing", (s * 0.62, 0.4, -d / 2), 0.08, 0.62, (150, 150, 148), "Metal", rot=(0, 90, 0))
        _cyl(f, "SpeakerCone", (s * 0.62, 0.4, -d / 2 - 0.04), 0.08, 0.5, (24, 24, 26), "Fabric", rot=(0, 90, 0))
        _cyl(f, "SpeakerCap", (s * 0.62, 0.4, -d / 2 - 0.08), 0.08, 0.16, (60, 60, 62), "SmoothPlastic", rot=(0, 90, 0))
        f.box("HandlePost", (s * 0.55 - 0.05, h, -0.05), (s * 0.55 + 0.05, h + 0.2, 0.05), IRON, "Metal")
    f.box("CassetteDoor", (-0.24, 0.16, -d / 2 - 0.04), (0.24, 0.52, -d / 2), _tone((30, 30, 32), rng, 3), "Glass",
          reflectance=0.1)
    f.box("TunerStrip", (-0.26, 0.57, -d / 2 - 0.04), (0.26, 0.66, -d / 2), (150, 140, 110), "SmoothPlastic")
    _cyl(f, "BoomboxHandle", (0, h + 0.24, 0), 1.24, 0.1, IRON, "Metal")
    _cyl(f, "HandleTape", (rng.uniform(-0.1, 0.1), h + 0.24, 0), 0.3, 0.15, _tone(DUCT, rng, 6), "Fabric")
    _rod(f, "Aerial", (w / 2 - 0.15, h, 0.2), (w / 2 + 0.1 + rng.uniform(0, 0.3), h + rng.uniform(0.7, 1.0), 0.35),
         0.03, (180, 180, 178), "Metal")
    _skin(f, "Scuff", (rng.uniform(-0.5, 0.5), 0.05, -d / 2), 0.5, 0.06, "-z", mix(col, (200, 200, 200), 0.4),
          spin=rng.uniform(-6, 6))


@prop(
    {"kind": "crt"},
    {"kind": "crt", "state": "broken"},
    {"kind": "crt", "state": "ground"},
    {"kind": "flat"},
    {"kind": "flat", "state": "ground"},
)
def tv(D, folder, origin, ry, rng, kind=None, state=None):
    """A television: an old 20" CRT set (the front shell, the deep back hump stepped in and raised
    off the ground, the bulging glass screen 4 cm proud of the bezel, a speaker grille, two knobs
    8 cm proud, a rabbit-ear aerial) or a flat screen on its foot.
    `broken`: the screen caved in (black, the crazed rim tilted round the hole, glass on the
    floor), the casing cracked. `ground`: dumped on the floor: the CRT on its back / side with
    its screen smashed and the shards around, the flat screen leaning against the wall (+Z) with
    a spider-web crack and a bent corner. Footprint CRT 2 x 1.6 studs, 1.55 tall; flat 3.6 x 0.6,
    2.3 tall (on the ground ~2.6 x 1.2). 4-15 parts; the body SMALL on the ground, else
    DECOR_SHADOW."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["crt", "crt", "flat"])
    state = state or _pick(rng, ["ok", "broken", "ground"])
    body_flags = SMALL if state == "ground" else DECOR_SHADOW
    if kind == "crt":
        col = _tone(_pick(rng, [(46, 44, 42), (110, 104, 92), (70, 60, 50)]), rng, 6, darken=rng.uniform(0, 0.2))
        W, H, Dp, fd = 2.0, 1.55, 1.6, 0.55
        if state == "ground":
            _disk(f, "Shards", 0, -1.6, 1.4, 0.03, (120, 130, 136), "Glass", reflectance=0.2)  # (in front, clear of it)
            if rng.random() < 0.6:  # on its back, the smashed screen to the sky
                f = f.sub((0, Dp / 2 + 0.02, 0), rx=90 + rng.uniform(-5, 5), rz=rng.uniform(-6, 6))
            else:  # on its side
                f = f.sub((0, W / 2 + 0.02, 0), rz=90 + rng.uniform(-5, 5), ry=rng.uniform(-10, 10))
        f.box("TV", (-W / 2, 0, -Dp / 2), (W / 2, H, -Dp / 2 + fd), col, "SmoothPlastic", flags=body_flags)
        f.box("TVBack", (-W * 0.36, 0.12, -Dp / 2 + fd), (W * 0.36, H * 0.82, Dp / 2), _tone(col, rng, 4, 0.1),
              "SmoothPlastic", flags=body_flags)
        sx0, sx1, sy0, sy1 = -W / 2 + 0.16, W * 0.22, 0.22, H - 0.16
        scx, scy = (sx0 + sx1) / 2, (sy0 + sy1) / 2
        smashed = state in ("broken", "ground")
        f.box("TVScreen", (sx0, sy0, -Dp / 2 - 0.04), (sx1, sy1, -Dp / 2), (8, 8, 9) if smashed else (26, 32, 34),
              "Glass", reflectance=0.0 if smashed else 0.2)
        if not smashed:  # the bulge of the tube's face
            f.box("TVScreen", (sx0 + 0.12, sy0 + 0.1, -Dp / 2 - 0.08), (sx1 - 0.12, sy1 - 0.1, -Dp / 2 - 0.04),
                  (30, 36, 38), "Glass", reflectance=0.25)
        else:
            for k in range(3):  # the crazed glass left round the rim of the hole, each piece tilted
                ex = rng.choice((-1, 1)) * ((sx1 - sx0) / 2 - 0.22)
                f.part("ScreenShard", (scx + (ex if k != 1 else rng.uniform(-0.3, 0.3)),
                                       scy + (k - 1) * 0.4 if k != 1 else sy1 - 0.2, -Dp / 2 - 0.07),
                       (rng.uniform(0.2, 0.35), rng.uniform(0.15, 0.25), 0.03), (90, 98, 104), "Glass",
                       rot=(rng.uniform(8, 18) * rng.choice((-1, 1)), rng.uniform(8, 18), rng.uniform(0, 180)),
                       reflectance=0.25)
        f.box("TVGrille", (W * 0.28, 0.22, -Dp / 2 - 0.04), (W / 2 - 0.12, H * 0.45, -Dp / 2), (20, 20, 20), "Fabric")
        for k in range(2):
            _cyl(f, "TVKnob", (W * 0.37, H * 0.6 + k * 0.3, -Dp / 2 - 0.04), 0.08, 0.16, (30, 30, 30), "SmoothPlastic",
                 rot=(0, 90, 0))
        if state == "broken":
            _skin(f, "CaseCrack", (W / 2, H * 0.5, -Dp / 2 + fd / 2), 0.03, 0.8, "+x", (10, 10, 10),
                  spin=rng.uniform(-30, 30))
        if state != "ground":
            for s in (-1, 1):
                _rod(f, "Aerial", (s * 0.05, H * 0.82, 0.2), (s * rng.uniform(0.5, 0.8), H + rng.uniform(0.9, 1.3), 0.3),
                     0.03, (170, 170, 168), "Metal")
            if state == "broken":
                for _ in range(2):
                    _disk(f, "GlassShard", rng.uniform(-0.8, 0.8), -Dp / 2 - rng.uniform(0.25, 0.5),
                          rng.uniform(0.15, 0.3), 0.02, (130, 140, 146), "Glass", reflectance=0.2)
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
            g.box("TVNeck", (-0.12, 0.06, -0.05), (0.12, y0, 0.05), col, "SmoothPlastic")
        g.box("TV", (-W / 2, y0, -0.06), (W / 2, y0 + H, 0.08), col, "SmoothPlastic", flags=body_flags)
        g.box("TVScreen", (-W / 2 + 0.07, y0 + 0.08, -0.1), (W / 2 - 0.07, y0 + H - 0.07, -0.06), SCREEN, "Glass",
              reflectance=0.25)
        if state != "ok":
            cx, cy = rng.uniform(-0.8, 0.8), y0 + rng.uniform(0.6, 1.4)
            _skin(g, "ScreenImpact", (cx, cy, -0.1), 0.25, 0.25, "-z", (170, 176, 180), spin=45)
            for k in range(rng.randint(4, 5)):  # the spider web (thin lines: separate slots where they cross)
                a = k * 72 + rng.uniform(-20, 20)
                ln = rng.uniform(0.5, 1.1)
                _skin(g, "ScreenCrack", (cx + math.cos(math.radians(a)) * (ln / 2 + 0.14),
                                         cy + math.sin(math.radians(a)) * (ln / 2 + 0.14), -0.1),
                      ln, 0.025, "-z", (150, 156, 160), spin=a)
            if state == "ground":
                g.part("BentCorner", (W / 2 - 0.2, y0 + H - 0.2, 0.01), (0.45, 0.45, 0.17), col, "SmoothPlastic",
                       rot=(rng.uniform(10, 20), 0, 12))


@prop({}, {"count": 6}, {"count": 3, "fallen": 1})
def clothes_rack(D, folder, origin, ry, rng, count=None, fallen=None):
    """A chrome garment rail on castors (tarnished, one upright bent) hung with jackets on wire
    hangers: leather, denim, a puffer, a parka; each hangs across the rail as on a real rack, the
    hook over the rail and the hanger's shoulders showing above the jacket: a body with sloping
    shoulders, a collar standing 7 cm proud, two limp sleeves; one jacket fallen in a heap under
    it. The jackets are spaced by their thickness (none inside another) and their collars at
    different heights. Footprint 5 x 2 studs, 5.2 tall. 30-48 parts; the uprights SMALL, the
    jackets DECOR_SHADOW."""
    f = Frame(D, folder, origin, ry=ry)
    count = count or rng.randint(3, 6)
    fallen = (1 if rng.random() < 0.4 else 0) if fallen is None else fallen
    W, H = 4.8, 5.2
    mc = _tone((150, 150, 148), rng, 8, darken=rng.uniform(0.15, 0.35))
    bend = rng.uniform(-4, 4)

    def rack():
        for s in (-1, 1):
            x = s * W / 2
            _rod(f, "RackUpright", (x, 0.35, 0), (x + (bend * 0.03 if s > 0 else 0), H, 0), 0.14, mc, "Metal",
                 flags=SMALL)
            _rod(f, "RackFoot", (x, 0.3, -0.9), (x, 0.3, 0.9), 0.14, mc, "Metal")
            for u in (-1, 1):
                _ball(f, "Castor", (x, 0.14, u * 0.85), 0.28, RUBBER, "Rubber")
        _rod(f, "RackRail", (-W / 2, H, 0), (W / 2 + bend * 0.03, H, 0), 0.12, mc, "Metal", extend=0.1)
        _rod(f, "RackBase", (-W / 2, 0.45, 0), (W / 2, 0.45, 0), 0.12, mc, "Metal")

    lib_meshprop(D, folder, "ClothesRack", origin, ry, rack)
    kit = MESHPROP.LIBS  # (the kit swaps the jackets: they are spaced for its pieces)
    vr = variation("clothes_rack", *(round(float(v), 2) for v in origin))
    kinds = [(_pick(rng, ["Leather", "Fabric", "Fabric", "Plastic"])) for _ in range(count)]
    # (along the rail: a puffer is fat; the kit's jackets are 0.56 / 0.70 deep, + their few degrees of yaw)
    thick = [(0.66 if m == "Leather" else 0.8) if kit else (0.64 if m == "Plastic" else 0.44) for m in kinds]
    room = W - 1.2 - sum(thick)
    while room < 0.1 * count and len(kinds) > 1:  # (never more jackets than fit)
        kinds.pop()
        thick.pop()
        room = W - 1.2 - sum(thick)
    x = -W / 2 + 0.6
    lift = [0.0, 0.05, 0.1]
    rng.shuffle(lift)
    last = None
    for i, (mat, tk) in enumerate(zip(kinds, thick)):
        x += rng.uniform(0.06, room / len(kinds)) + tk / 2
        jc = _tone(_pick(rng, JACKET), rng, 6, darken=rng.uniform(0, 0.25))
        u, v = rng.uniform(-6, 6), rng.uniform(-3, 3)
        if kit:
            u *= 0.4  # (the kit jackets are 1.95 wide: a big yaw would swing them into their neighbours)
        g = f.sub((x, H, 0), ry=90 + u, rz=v)
        x += tk / 2
        jl = rng.uniform(2.2, 2.9)
        top = -0.48 - lift[i % 3]
        if mat == "Leather":
            piece = "Jacket1" if vr.random() < 0.5 else "Jacket1Brown"
            tint = None
        else:
            piece, tint = "Jacket2", weathered(jc, vr, 6, 0.1)
        if piece == last and piece != "Jacket2":
            piece = "Jacket1Brown" if piece == "Jacket1" else "Jacket1"  # (never two identical side by side)
        last = piece
        frame_meshprop(D, folder, piece, g, lib=True, tint=tint,
                       fallback=lambda g=g, jc=jc, mat=mat, tk=tk, jl=jl, top=top: _rack_jacket(g, rng, jc, mat, tk,
                                                                                                    jl, top))
    for _ in range(0 if kit else fallen):  # (the heap of a fallen jacket: no kit piece, left out with the kit)
        jc = _tone(_pick(rng, JACKET), rng, 6, darken=0.2)
        x = rng.uniform(-1.5, 1.5)
        f.part("Jacket", (x, 0.2, rng.uniform(-0.6, 0.3)), (1.6, 0.4, 1.3), jc, "Fabric",
               rot=(rng.uniform(-8, 8), rng.uniform(0, 180), rng.uniform(-8, 8)), flags=DECOR_SHADOW)
        f.part("Sleeve", (x + 0.7, 0.15, rng.uniform(-0.8, -0.4)), (1.4, 0.3, 0.35), jc, "Fabric",
               rot=(rng.uniform(-6, 6), rng.uniform(0, 180), rng.uniform(4, 9)))


def _rack_jacket(g, rng, jc, mat, tk, jl, top):
    """One jacket on its wire hanger, hung across the rail at g (g's origin on the rail, its Z
    along the rail): the hook, the hanger's arms, a body with sloping shoulders, a collar standing
    7 cm proud, two limp sleeves (the primitive fallback of the kit's Jacket pieces)."""
    hc = (120, 120, 120)
    _rod(g, "Hanger", (0, 0.07, -0.05), (0, -0.14, 0), 0.03, hc, "Metal")
    for s in (-1, 1):
        _rod(g, "Hanger", (0, -0.14, 0), (s * 0.7, -0.33, 0), 0.035, hc, "Metal")
    hz = tk / 2
    g.box("Jacket", (-0.75, top - jl, -hz), (0.75, top, hz), jc, mat, flags=DECOR_SHADOW)
    for s in (-1, 1):  # the shoulders under the hanger's arms, sloping
        g.part("Jacket", (s * 0.4, top + 0.02, 0), (0.75, 0.16, tk - 0.13), _tone(jc, rng, 3), mat,
               rot=(0, 0, s * -15))
    g.box("JacketCollar", (-0.28, top - 0.04, -hz - 0.07), (0.28, top + 0.2, hz + 0.07), _tone(jc, rng, 4, 0.15),
          mat)
    for s in (-1, 1):
        g.part("Sleeve", (s * 0.86, top - 0.1 - jl * 0.42, 0), (0.3, jl * 0.8, tk * 0.7), _tone(jc, rng, 4, 0.05),
               mat, rot=(rng.uniform(-6, 6), 0, s * rng.uniform(4, 10)))


@prop({}, {"open": False})
def cash_box(D, folder, origin, ry, rng, open=True):
    """A dented steel cash box (30 x 24 x 9 cm): a hollow body (base and four butted walls), the
    cylinder lock 4 cm proud on the front with the key in it, the lid hinged at the back with its
    folding handle; open: the plastic coin tray sitting inside 2 cm below the rim, its dividers
    (five coin cups at the front, three note slots behind), piles of coins in the cups, two wads of
    grubby notes lying askew across the back slots. Footprint 1.06 x 1.1 studs, 0.3 tall (lid
    open 1.0). 10-23 parts, DECOR. Origin = the table top."""
    f = Frame(D, folder, origin, ry=ry)
    col = _tone(_pick(rng, [(60, 64, 70), (90, 40, 36), (50, 66, 54), (40, 40, 44)]), rng, 6,
                darken=rng.uniform(0.05, 0.25))
    w, d, hb, t = 1.0, 0.78, 0.22, 0.035
    _open_box(f, rng, w, d, hb, col, "Metal", "CashBox", t=t, b=0.03, tone=3)
    _cyl(f, "CashLock", (0.0, hb * 0.55, -d / 2), 0.08, 0.1, (150, 150, 146), "Metal", rot=(0, 90, 0))
    f.box("CashKey", (-0.015, hb * 0.55 - 0.05, -d / 2 - 0.1), (0.015, hb * 0.55 + 0.05, -d / 2 - 0.04),
          (170, 150, 90), "Metal")
    lc = _tone(col, rng, 4)
    ang = rng.uniform(96, 108) if open else 0.0
    g = f.sub((0, hb, d / 2), rx=ang)
    g.box("CashBoxLid", (-w / 2, 0, -d), (w / 2, 0.07, 0), lc, "Metal")
    g.box("CashBoxHandle", (-0.2, 0.07, -d / 2 - 0.04), (0.2, 0.11, -d / 2 + 0.04), IRON, "Metal")
    if not open:
        return
    # the removable tray: 2.5 cm clear of the walls all round, its floor 6.5 cm thick (so no
    # bottom face lies within 6 cm of another), shallow cups 4.5 cm deep
    iw, idp = w - 2 * t - 0.05, d - 2 * t - 0.05
    ty = hb - 0.13  # the tray's floor
    tf = 0.065
    tray = _tone((40, 40, 44), rng, 4)
    f.box("CoinTray", (-iw / 2, ty, -idp / 2), (iw / 2, ty + tf, idp / 2), tray, "Plastic")
    zl = -0.05
    f.box("CoinTray", (-iw / 2, ty + tf, zl - 0.01), (iw / 2, hb - 0.02, zl + 0.01), tray, "Plastic")
    for k in range(1, 5):  # five coin cups at the front
        x = -iw / 2 + iw * k / 5
        f.box("CoinTray", (x - 0.01, ty + tf, -idp / 2), (x + 0.01, hb - 0.02, zl - 0.01), tray, "Plastic")
    for k in (1, 2):  # three note slots behind
        x = -iw / 2 + iw * k / 3
        f.box("CoinTray", (x - 0.01, ty + tf, zl + 0.01), (x + 0.01, hb - 0.02, idp / 2), tray, "Plastic")
    cup = iw / 5
    for k in range(5):
        if rng.random() < 0.25:
            continue
        x = -iw / 2 + cup * (k + 0.5) + rng.uniform(-0.02, 0.02)
        z = (-idp / 2 + zl) / 2 + rng.uniform(-0.03, 0.03)
        _vcyl(f, "Coins", x, ty + tf, z, rng.uniform(0.02, 0.04), 0.09,
              _pick(rng, [(150, 130, 80), (160, 160, 156), (140, 90, 60)]), "Metal", reflectance=0.15)
    for k in range(rng.randint(1, 2)):  # wads of notes lying askew on the slot dividers
        nc = _tone(_pick(rng, [(120, 128, 108), (150, 120, 110), (110, 120, 140)]), rng, 8, 0.1)
        y = hb - 0.02 + 0.035 + k * 0.05
        f.part("Notes", (rng.uniform(-0.08, 0.08), y, (zl + idp / 2) / 2 + rng.uniform(-0.03, 0.03)), (0.5, 0.05, 0.23),
               nc, "Fabric", rot=(rng.uniform(2.5, 4) * rng.choice((-1, 1)), rng.uniform(-12, 12) + k * 20,
                                  rng.uniform(2.5, 4) * rng.choice((-1, 1))))


def _lay_goods(rng, items, W, Dp, margin=0.2, gap=0.15, yaw_max=6.0):
    """Lays the goods out in a row along the table, left to right by footprint: items is
    [(fn, opts, w, d)] in priority order; an item that doesn't fit beside the ones already taken
    is dropped. Each gets a small yaw; its rotated footprint (the bounding box of the turned
    rectangle) is what's laid out, so two items' turned footprints never overlap (an OBB
    clearance >= gap), and the spare length is shared out as random extra gaps. Returns
    [(fn, opts, x, z, yaw, rect)] in table coordinates (rect = x0, x1, z0, z1)."""
    taken, used = [], 0.0
    for fn, opts, w, d in items:
        yaw = rng.uniform(-yaw_max, yaw_max)
        a = math.radians(yaw)
        ew = abs(w * math.cos(a)) + abs(d * math.sin(a))
        ed = abs(w * math.sin(a)) + abs(d * math.cos(a))
        need = ew + (gap if taken else 0.0)
        if used + need > W - 2 * margin or ed > Dp - 2 * margin:
            continue
        taken.append((fn, opts, ew, ed, yaw))
        used += need
    rng.shuffle(taken)
    spare = W - 2 * margin - used
    cuts = sorted(rng.uniform(0, spare) for _ in taken)
    out, x, prev = [], -W / 2 + margin, 0.0
    for k, (fn, opts, ew, ed, yaw) in enumerate(taken):
        x += (gap if k else 0.0) + cuts[k] - prev
        prev = cuts[k]
        cx = x + ew / 2
        x += ew
        z0 = -Dp / 2 + margin
        cz = z0 + ed / 2 + rng.uniform(0, max(0.0, min(0.4, Dp - 2 * margin - ed)))
        out.append((fn, opts, cx, cz, yaw, (cx - ew / 2, cx + ew / 2, cz - ed / 2, cz + ed / 2)))
    for i in range(len(out)):  # the clearance check (axis-aligned turned footprints)
        for j in range(i + 1, len(out)):
            a, b = out[i][5], out[j][5]
            assert a[1] + gap - 1e-6 <= b[0] or b[1] + gap - 1e-6 <= a[0], (a, b)
    return out


@prop({}, {"goods": "electronics"}, {"goods": "clothes"})
def market_stall(D, folder, origin, ry, rng, goods=None, light=True, compact=False):
    """A whole black-market stall, composed: the canopy over a folding table laid with goods
    (phones, watches, car stereos, a cash box; a TV or a radio behind) or clothes (sneaker
    boxes and the cash box on the table, the jacket rail behind), crates of stock stacked behind.
    The goods are laid out by footprint (_lay_goods: as many as fit, never inside each other,
    turned a few degrees) in the table's own frame, standing on its real top surface + 0.01 (the
    table's top is flat). Footprint ~9 x 7 studs, 7.8 tall (`compact`: ~7 x 5.5, no stock crates
    behind, for tight yards). 110-190 parts (the sum of its pieces)."""
    f = Frame(D, folder, origin, ry=ry)
    goods = goods or _pick(rng, ["electronics", "electronics", "clothes"])
    yaw = _yaw(f)
    cw, cd = (6.8, 5.4) if compact else (rng.uniform(8.5, 9.5), rng.uniform(6, 7))
    vr = variation("market_stall", *(round(float(v), 2) for v in origin))
    if compact:  # (the kit's MarketTarp is this size: 6.8 x 5.4 between the poles)
        tarp = weathered(_pick(vr, TARP), vr, 6, 0.15)
        lib_meshprop(D, folder, "MarketTarp", _w(f, 0, 0.5), yaw, tint=tarp,
                     fallback=lambda: market_canopy(D, folder, _w(f, 0, 0.5), yaw, rng, w=cw, d=cd, light=light,
                                                    color=tarp, pin=True))
    else:
        market_canopy(D, folder, _w(f, 0, 0.5), yaw, rng, w=cw, d=cd, light=light)
    tw = 4.8 if compact else rng.uniform(5.5, 6.2)
    td = rng.uniform(2.4, 2.7)
    tyaw = yaw + rng.uniform(-3, 3)
    tpos = _w(f, rng.uniform(-0.3, 0.3), -1.0)
    tf = Frame(D, folder, tpos, ry=tyaw)
    if goods == "electronics":
        n = rng.randint(2, 3)
        items = [(cash_box, {}) + GOODS_FOOT["cash_box"]]
        rest = [(phone_tray, {}) + GOODS_FOOT["phone_tray"], (watch_case, {}) + GOODS_FOOT["watch_case"]]
        rest += [(car_stereos, {"count": k}) + _stereo_foot(k) for k in range(n, 0, -1)]
        rng.shuffle(rest)
        items += rest
    else:
        items = [(cash_box, {}) + GOODS_FOOT["cash_box"],
                 (shoe_boxes, {"count": rng.randint(3, 4)}) + GOODS_FOOT["shoe_boxes"]]
    placed = []
    seen = set()
    for it in items:  # (only one car_stereos entry: the biggest count that fits)
        if it[0] in seen:
            continue
        lay = _lay_goods(random.Random(0), [(fn, o, w, d) for fn, o, w, d in placed] + [it], tw, td)
        if len(lay) == len(placed) + 1:
            placed.append(it)
            seen.add(it[0])
    lay = _lay_goods(rng, placed, tw, td)
    top = _table(D, folder, tpos, tyaw, rng, w=tw, d=td, clear=[r[5] for r in lay])
    kit = {"phone_tray": "PhoneTray", "watch_case": "WatchCase", "cash_box": "CashBox"}
    for fn, opts, x, z, gyaw, _ in lay:
        at = tuple(float(v) for v in tf.world((x, top + 0.01, z)))

        def goods_fn(fn=fn, at=at, gyaw=gyaw, opts=opts):
            fn(D, folder, at, tyaw + gyaw, rng, **opts)

        piece = kit.get(fn.__name__)
        if piece and opts.get("open", True):  # (the kit has them open; the goods stand 0.012 above it)
            tint = None
            if piece == "CashBox":
                tint = weathered(_pick(vr, [(62, 66, 74), (120, 36, 32), (40, 60, 110)]), vr, 6)
            lib_meshprop(D, folder, piece, tuple(float(v) for v in tf.world((x, top, z))), tyaw + gyaw, goods_fn,
                         tint=tint)
        else:
            goods_fn()
    if goods == "electronics":
        if rng.random() < 0.6:
            at, a = _w(f, rng.uniform(-0.4, 0.4), 1.75), yaw + 180 + rng.uniform(-10, 10)
            lib_meshprop(D, folder, "CrtTv", at, a, lambda: tv(D, folder, at, a, rng, kind="crt", state="ok"),
                         tint=weathered(_pick(vr, [(58, 56, 54), (112, 106, 94), (72, 62, 52)]), vr, 5))
        else:
            at, a = _w(f, rng.uniform(-0.5, 0.5), 1.5), yaw + rng.uniform(-15, 15)
            lib_meshprop(D, folder, "Radio", at, a, lambda: radio(D, folder, at, a, rng),
                         tint=weathered(_pick(vr, [(46, 46, 48), (150, 150, 154), (70, 70, 74)]), vr, 5))
    else:
        clothes_rack(D, folder, _w(f, rng.uniform(-0.3, 0.3), 1.9), yaw + rng.uniform(-6, 6), rng,
                     count=rng.randint(4, 5))
    if compact:
        return
    # the stock, behind the table, clear of the TV / radio / rail and of the back poles' feet
    if goods == "electronics":
        wooden_crates(D, folder, _w(f, -3.3, 1.9), yaw + rng.uniform(-6, 6), rng, count=1)
    plastic_crates(D, folder, _w(f, 3.6, 1.6), yaw + 90 + rng.uniform(-6, 6), rng, count=2)


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
    y0 = 0.0
    if state == "flat" and rng.random() < 0.6:  # on flattened cardboard
        f.part("Cardboard", (rng.uniform(-0.3, 0.3), 0.03, rng.uniform(-0.3, 0.3)), (W + 0.8, 0.06, L * 0.7),
               _tone(CARDBOARD_WET, rng, 8), CARDBOARD_MAT, rot=(0, rng.uniform(-8, 8), 0))
        y0 = 0.06
    segs = []  # (frame at the segment's centre bottom, its length) along local Z
    if state == "flat":  # (on the floor a mattress lies flat: one piece)
        segs = [(f.sub((0, y0, 0), ry=rng.uniform(-2, 2)), L)]
    elif state == "folded":
        Lh = L / 2
        segs = [
            (f.sub((0, 0, 0)), Lh),
            (f.sub((rng.uniform(-0.15, 0.15), T + 0.02, -0.1), ry=rng.choice((-1, 1)) * rng.uniform(3, 6),
                   rx=rng.uniform(2, 4)), Lh - 0.1),
        ]
        # the bend: a fat roll, its ends 6 cm inside the sides
        _cyl(f, "MattressFold", (0, T, Lh / 2 - 0.05), W - 0.12, T * 2, _tone(col, rng, 4), "Fabric", flags=DECOR_SHADOW)
    else:
        lean = rng.uniform(10, 18)
        g = f.sub((0, 0, -0.2 - T), rx=90 + lean)  # stood on its end, its top against the wall
        segs = [
            (g.sub((0, 0, -L / 4)), L / 2),
            (g.sub((0, 0, -L / 2), rx=-rng.uniform(4, 9), ry=rng.choice((-1, 1)) * rng.uniform(2.5, 4)).sub(
                (0, 0, -L / 4)), L / 2),
        ]
    body_flag = SMALL if state == "leaning" else PROP
    for k, (s2, ln) in enumerate(segs):
        s2.box("Mattress", (-W / 2, 0, -ln / 2), (W / 2, T, ln / 2), _tone(col, rng, 3), "Fabric", flags=body_flag)
        for sx in (-1, 1):  # the piped seam along the top edges (round; its ends 7 cm past the body's)
            _cyl(s2, "MattressSeam", (sx * W / 2, T - 0.02, 0), ln + 0.14, 0.12, _tone(col, rng, 3, 0.2), "Fabric",
                 rot=(0, 90, 0))
        if k == 0:  # a lump where a spring has gone: a low swelling, turned askew in the top
            s2.part(
                "Lump",
                (rng.uniform(-0.6, 0.6), T - 0.02, rng.uniform(-0.5, 0.5)),
                (rng.uniform(0.9, 1.3), 0.12, rng.uniform(0.8, 1.1)),
                _tone(col, rng, 3, -0.04),
                "Fabric",
                rot=(rng.choice((-1, 1)) * rng.uniform(3, 7), rng.uniform(0, 90), rng.choice((-1, 1)) * rng.uniform(3, 7)),
            )
        for _ in range(rng.randint(1, 2) if k == len(segs) - 1 else 0):  # tide marks, on the top piece
            sc = mix(_tone(_pick(rng, STAIN), rng, 6), col, 0.55)
            x, z = rng.uniform(-0.8, 0.8), rng.choice((-1, 1)) * rng.uniform(0.95, max(1.0, ln / 3))  # (off the lump)
            sz = rng.uniform(0.6, 1.2)
            _skin(s2, "Stain", (x, T, z), sz, sz * rng.uniform(0.6, 1.0), "y", sc, "Fabric", spin=rng.uniform(0, 180))
    if torn:  # a torn corner, the yellow foam bulging out of it
        s2, ln = segs[-1]
        _ball(s2, "Foam", (W / 2 - 0.35, T - 0.05, ln / 2 - 0.4), 0.6, _tone(FOAM, rng, 10, 0.15), "Sand")
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
        _cyl(f, "BagHood", (0, 0.32, -L / 2 + 0.6), W + 0.14, 0.7, _tone(col, rng, 4), "Fabric", flags=DECOR_SHADOW)
        for k in range(rng.randint(3, 4)):  # the quilting lines (marks on the top)
            z = -L / 2 + 1.6 + k * 1.2
            _skin(f, "Baffle", (0, 0.35, z), W - 0.06, 0.08, "y", _tone(col, rng, 3, 0.25), "Fabric")
        # the top half unzipped and turned back
        g = f.sub((W / 2 - 0.05, 0.36, -L / 2 + 1.2), ry=rng.uniform(-6, 6))
        g.part("BagFlap", (0.55, 0.02, 1.1), (1.2, 0.06, 2.2), lining, "Fabric", rot=(0, 0, rng.uniform(-6, -2)))
        _cyl(g, "BagFlapRoll", (0.0, 0.08, 1.1), 2.2, 0.22, _tone(col, rng, 4), "Fabric", rot=(0, 90, 0))
        _skin(f, "Stain", (rng.uniform(-0.6, 0.6), 0.35, rng.uniform(0, L / 3)), 0.9, 0.7, "y",
              mix(_tone(_pick(rng, STAIN), rng, 6), col, 0.5), "Fabric", spin=rng.uniform(0, 180))
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
        _cyl(f, "BagEnd", (1.14, 0.5, 0), 0.08, 0.5, mix(col, (20, 20, 20), 0.5), "Fabric")


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
            _cyl(g, "BlanketFold", (0, th / 2, -0.75), 2.0 - 0.14, th, cols[i], "Fabric")
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
        # the bottom one spread on the ground, one edge rucked up (tilted 2.5 deg: never in the plane
        # of a sheet of cardboard or another blanket lying flat beside it)
        f.part("Blanket", (0, 0.025 + 1.3 * math.sin(math.radians(2.5)), 0), (3.2, 0.05, 2.6), _tone(cols[0], rng, 6, 0.1),
               "Fabric", rot=(0, rng.uniform(0, 90), 2.5))
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
        (rng.uniform(-0.2, 0.2), 0.025, -0.3),
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
                f.part(  # (standing on the groundsheet, not through it)
                    "TentEnd",
                    (s * W / 4, 0.05 + (H - 0.05) / 2, z),
                    (0.05, H - 0.05, W / 2),
                    _tone(col, rng, 4, 0.05),
                    "Fabric",
                    rot=(0, -s * 90, 0),
                    shape=WEDGE,
                )
        if open:
            f.part(
                "TentInside",
                (W / 4, 0.05 + H * 0.33, -L / 2 + 0.15),
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
                # (rocked on the uneven ground: never in the groundsheet's plane)
                rot=(0, rng.uniform(0, 180), rng.choice((-1, 1)) * rng.uniform(3, 6)),
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
        zc, dz = 0.2, Dp - 1.0  # the side closed under the slope: a box side and a triangle over it (its back
        # end 0.3 short of the wall, clear of the wall's own stains)
        cc = _tone(CARDBOARD_WET, rng, 8)
        f.part("Cardboard", (s * W / 2, Hf / 2, zc), (0.06, Hf, dz), cc, CARDBOARD_MAT, rot=(0, 0, s * 3))
        f.part(
            "Cardboard",
            (s * W / 2, Hf + (Ht - Hf) / 2 - 0.15, zc),
            (0.06, Ht - Hf - 0.2, dz),
            _tone(cc, rng, 5),
            CARDBOARD_MAT,
            shape=WEDGE,
            rot=(0, 0, s * 3),
        )
        f.part(
            "Pallet",
            (s * (W / 2 + 0.5), 1.1, 0.4),
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
            "Cardboard",  # (each sheet overlapping the last lies on it: 6 cm up a sheet)
            (rng.uniform(-0.2, 0.2), 0.03 + i * 0.06, -L / 2 + 1.1 + i * 2.1),
            (W + rng.uniform(0, 0.4), 0.06, 2.4),
            _tone(CARDBOARD_WET if i % 2 else CARDBOARD_DARK, rng, 8),
            CARDBOARD_MAT,
            rot=(0, rng.uniform(-6, 6), 0),
        )
    for s in (-1, 1):  # the propped walls, the wet dark band at their foot (in the wall's frame)
        g = f.sub((s * W / 2, H / 2 - 0.1, 0), ry=rng.uniform(-3, 3), rz=s * rng.uniform(4, 10))
        lw = L * rng.uniform(0.75, 0.9)
        g.box("CardboardWall", (-0.03, -H / 2, -lw / 2), (0.03, H / 2, lw / 2), _tone(CARDBOARD, rng, 8, 0.1), CARDBOARD_MAT,
              flags=SMALL)
        _skin(g, "WetEdge", (s * 0.03, -H / 2 + 0.3, 0), lw * 0.8, 0.45, "+x" if s > 0 else "-x", CARDBOARD_WET,
              CARDBOARD_MAT)
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
        # the rolled arm, its scroll 7 cm proud of the arm's front and back
        _cyl(g, "ChairArmRoll", (x + s * 0.05, 1.9, -0.1), Dp - 0.2 + 0.14, 0.7, _tone(col, rng, 4), "Fabric",
             rot=(0, 90, 0))
    back = rng.uniform(8, 14) + (rng.uniform(12, 22) if state == "wrecked" else 0)
    b = g.sub((0, 0.9, Dp / 2 - 0.35), rx=-back)
    b.box("ChairBack", (-W / 2 + 0.55, 0, -0.3), (W / 2 - 0.55, 2.3, 0.3), _tone(col, rng, 4), "Fabric", flags=PROP)
    _cyl(b, "ChairBackRoll", (0, 2.3, 0), W - 1.1 + 0.14, 0.6, _tone(col, rng, 4), "Fabric")
    _skin(b, "Grime", (0, 1.8, -0.3), W * 0.45, 0.8, "-z", mix(col, GRIME, 0.45), "Fabric")  # (where heads rest)
    if state == "worn":
        cf = g.sub((rng.uniform(-0.15, 0.15), 1.15, -0.25 + rng.uniform(-0.2, 0.1)),
                   rx=rng.choice((-1, 1)) * rng.uniform(2, 3.5), ry=rng.uniform(-6, 6), rz=rng.choice((-1, 1)) * rng.uniform(2, 3))
        cf.box("Cushion", (-(W - 1.3) / 2, -0.18, -(Dp - 0.9) / 2), ((W - 1.3) / 2, 0.18, (Dp - 0.9) / 2),
               _tone(col, rng, 4, -0.05), "Fabric")
        _skin(cf, "Stain", (rng.uniform(-0.4, 0.4), 0.18, rng.uniform(-0.3, 0.1)), 0.9, 0.7, "y",
              mix(_tone(_pick(rng, STAIN), rng, 6), col, 0.45), "Fabric", spin=rng.uniform(0, 180))
    else:
        g.box("Webbing", (-W / 2 + 0.6, 1.0, -Dp / 2 + 0.15), (W / 2 - 0.6, 1.07, Dp / 2 - 0.5), (30, 26, 22), "Fabric")
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
    s = rng.choice((-1, 1))  # torn arm, foam bursting out of the roll
    _ball(g, "Foam", (s * (W / 2 - 0.25), 2.18, -Dp / 2 + rng.uniform(0.4, 0.9)), 0.5, _tone(FOAM, rng, 10, 0.1), "Sand")
    _skin(g, "Grime", (0, 0.5, -Dp / 2), W - 0.1, 1.0, "-z", mix(col, GRIME, 0.35), "Fabric")
    if blanket:  # thrown over the back: a fold on the roll, the rest hanging down its front
        bc = _tone(_pick(rng, FABRIC), rng, 8, 0.1)
        bx = rng.uniform(-0.25, 0.25)
        b.part("Blanket", (bx, 2.3 + 0.36, 0.05), (W - 0.7, 0.12, 0.9), bc, "Fabric",
               rot=(rng.choice((-1, 1)) * rng.uniform(3, 6), rng.uniform(-4, 4), rng.choice((-1, 1)) * rng.uniform(2, 4)))
        hang = b.sub((bx, 2.5, -0.38), rx=rng.uniform(4, 9), rz=rng.uniform(-3, 3))
        hang.box("Blanket", (-(W - 0.8) / 2, -1.3, -0.12), ((W - 0.8) / 2, 0, 0), _tone(bc, rng, 3), "Fabric")


@prop({"lit": True}, {"lit": False}, {"lit": False, "pot": False})
def camp_stove(D, folder, origin, ry, rng, lit=None, pot=True, light=True):
    """A one-ring camping stove on the ground: the squat gas cartridge (dented, label faded) under
    the burner head, three pot supports, a blackened dented saucepan with its handle sticking out
    and a lid half on (or a pot of brown stew), a small blue flame (`lit`, Neon, with a faint light
    if `light`), a scorch mark, a spoon. Footprint 1.6 x 1.4 studs, 1.6 tall. 8-13 parts, DECOR
    (the cartridge SMALL)."""
    f = Frame(D, folder, origin, ry=ry)
    lit = (rng.random() < 0.6) if lit is None else lit
    # the scorch: an opaque sooty disk the stove stands on (not a floor decal: the cartridge's
    # foot must not share its plane)
    f.part("Scorch", (rng.uniform(-0.1, 0.1), 0.015, rng.uniform(-0.1, 0.1)), (0.03, 1.6, 1.6), (40, 38, 36), "Slate",
           rot=(0, 0, 90), shape=CYLINDER, flags=DECOR)
    y0 = 0.03
    cc = _tone(_pick(rng, [(40, 70, 130), (170, 60, 40), (150, 140, 60)]), rng, 8, darken=rng.uniform(0.15, 0.4))
    _vcyl(f, "GasCartridge", 0, y0, 0, 0.55, 0.85, cc, "Metal", flags=SMALL)
    _vcyl(f, "CartridgeTop", 0, y0 + 0.55, 0, 0.12, 0.6, _tone(STEEL, rng, 8, 0.2), "Metal")
    _vcyl(f, "Burner", 0, y0 + 0.67, 0, 0.18, 0.4, _tone(IRON, rng, 5), "Metal")
    f = f.sub((0, y0, 0))
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
        _vcyl(g, "SaucepanSoot", 0, 0, 0, 0.18, 1.0, SOOT, "Metal")  # the burnt bottom, butted under the pan
        _vcyl(g, "Saucepan", 0, 0.18, 0, 0.27, 1.0, pc, "Metal")
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
            _vcyl(g, "Stew", 0, 0.45, 0, 0.065, 0.86, _tone((84, 58, 34), rng, 6), "Sand")  # (full to the brim)
    f.part(
        "Spoon",
        (rng.uniform(0.6, 0.9), 0.02, rng.uniform(-0.6, -0.3)),
        (0.7, 0.04, 0.1),
        _tone(STEEL, rng, 8, 0.1),
        "Metal",
        rot=(rng.uniform(2.5, 4), rng.uniform(0, 180), rng.uniform(2.5, 4)),
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
        # (6 cm short of each corner, so no two translucent skins ever intersect)
        g.part("CartMesh", (0, 0, 0), (length - 0.12, yt - yb - 0.1, 0.04), mc, "Metal", rot=(0, ry2, 0), transparency=0.78)
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
    _cyl(f, "BackpackTop", (0, H, 0), W - 0.14, Dp, _tone(col, rng, 4), "Fabric")  # (the rounded top, 7 cm in)
    f.box(
        "FrontPocket",
        (-W * 0.38, 0.15, -Dp / 2 - 0.25),
        (W * 0.38, H * 0.5, -Dp / 2 + 0.02),
        _tone(col, rng, 4, 0.1),
        "Fabric",
    )
    _skin(f, "Zip", (0, H * 0.5 - 0.08, -Dp / 2 - 0.25), W * 0.7, 0.04, "-z", (40, 40, 40), "Metal")
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
        (rng.uniform(-0.3, 0.3), rng.uniform(1.05, 1.3), -Dp / 2),
        0.35,
        0.3,
        "-z",
        _tone(_pick(rng, FABRIC), rng, 8),
        "Fabric",
        th=0.03,
        spin=rng.uniform(-20, 20),
    )


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
    for y, d in ((0.22 + 2 * 0.58 + 0.15, 0.66), (0.22 + 3 * 0.58 + 0.15, 0.5)):  # (mid-section: caps clear)
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
        if banner:  # a printed banner cable-tied on, its torn corner hanging 7 cm in front
            bc = _tone(_pick(rng, [(40, 70, 120), (170, 160, 150), (60, 90, 60)]), rng, 8, 0.25)
            bf = g.sub((rng.uniform(-0.6, 0.6), H * 0.62, -0.075), rz=rng.uniform(-3, 3))
            bf.box("Banner", (-W * 0.35, -0.9, -0.015), (W * 0.35, 0.9, 0.015), bc, "Plastic")
            _skin(bf, "BannerPrint", (-0.3, 0.1, -0.015), W * 0.4, 0.5, "-z", (200, 198, 190))
            g.part("Banner", (W * 0.25, H * 0.42, -0.15), (W * 0.25, 1.0, 0.03), bc, "Plastic",
                   rot=(rng.choice((-1, 1)) * rng.uniform(4, 10), 0, rng.uniform(15, 35)))
    elif kind == "aframe":
        W, H = 4.6, 3.2
        lc = _tone(STRIPE_WHITE, rng, 8, darken=rng.uniform(0.15, 0.35))
        rc = _tone(STRIPE_RED, rng, 8, darken=rng.uniform(0.1, 0.3))
        # the board: red and white blocks butted end to end (the UK chapter-8 pattern; no stickers
        # on a board), its chipped paint showing the wood
        bf = f.sub((0, H - 0.4, 0), rz=rng.uniform(-2, 2))
        nb = 7
        for k in range(nb):
            x0 = -W / 2 + W * k / nb
            bf.box("BarrierBoard", (x0, -0.35, -0.06), (x0 + W / nb, 0.35, 0.06), _tone(rc if k % 2 else lc, rng, 4), "Wood",
                   flags=PROP)
        for _ in range(rng.randint(1, 2)):
            _skin(bf, "Chip", (rng.uniform(-1.8, 1.8), rng.uniform(-0.2, 0.2), -0.06), 0.25, 0.12, "-z", WOOD_OLD, "Wood",
                  spin=rng.uniform(0, 90))
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
        for s in (-1, 1):  # the lifting slots at the base (dark, on both faces)
            for u in (-1, 1):
                _skin(f, "LiftSlot", (s * L / 4, 0.2, u * 1.0), 0.8, 0.3, "-z" if u < 0 else "+z", SOOT)
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
        _skin(f, "TyreMark", (rng.uniform(-1, 1), 0.55, -1.0), rng.uniform(1.5, 2.5), 0.25, "-z", mix((24, 24, 24), cc, 0.3),
              spin=rng.uniform(-8, 8))


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
        for b in range(bays):  # the boards, laid on the transoms (an odd bay's lapped over its neighbours')
            x0 = xs[b]
            nb = 4
            missing = rng.randrange(nb) if rng.random() < 0.4 else -1
            boards = []
            for k in range(nb):
                if k == missing:
                    continue
                z = -BD / 2 + 0.45 + k * (BD - 0.9) / (nb - 1)
                bc = _tone(_pick(rng, [WOOD_GREY, WOOD_OLD, (120, 110, 90)]), rng, 8)
                bf = f.sub((x0 + BW / 2 + rng.uniform(-0.15, 0.15), y + 0.17 + 0.15 * (b % 2), z + rng.uniform(-0.02, 0.02)),
                           ry=rng.uniform(-0.4, 0.4))
                bf.box("ScaffoldBoard", (-(BW + 0.5) / 2, -0.075, -0.36), ((BW + 0.5) / 2, 0.075, 0.36), bc, "WoodPlanks",
                       flags=SOLID)
                boards.append(bf)
            if boards and rng.random() < 0.6:
                _skin(_pick(rng, boards), "PaintSpatter", (rng.uniform(-2, 2), 0.075, rng.uniform(-0.15, 0.15)), 0.6, 0.4,
                      "y", _tone((190, 188, 180), rng, 8, 0.1), spin=rng.uniform(0, 180), disk=True)
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
            rot=(rng.uniform(-35, -20), rng.uniform(-10, 10), rng.uniform(-8, 8)),  # (bunched: opaque)
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
    _vcyl(f, "ChairHub", 0, 0.24, 0, 0.32, 0.44, pc, "Plastic")
    for k in range(5):  # five legs sloping down from the hub (each its own tilt: no shared planes)
        g = f.sub((0, 0.45, 0), ry=k * 72 + rng.uniform(-3, 3), rx=-4)
        g.box("ChairLeg", (-0.1, -0.08, -1.15), (0.1, 0.08, -0.15), pc, "Plastic")
        if k != miss:
            _ball(f.sub((0, 0, 0), ry=k * 72), "ChairCastor", (0, 0.16, -1.1), 0.32, pc, "Plastic")
    _vcyl(f, "GasLift", 0, 0.45, 0, 1.2, 0.26, _tone(STEEL, rng, 8, 0.3), "Metal")
    lean = rng.uniform(5, 9) if state == "broken" else 0
    g = f.sub((0, 1.6, 0), rz=lean)
    g.box("ChairMech", (-0.5, 0, -0.5), (0.5, 0.25, 0.5), IRON, "Metal")
    g.box("ChairSeat", (-1.0, 0.25, -1.0), (1.0, 0.65, 0.95), col, "Fabric", flags=SMALL)
    _ball(g, "SeatFoam", (rng.uniform(-0.4, 0.4), 0.62, rng.uniform(-0.5, 0.2)), 0.42, _tone(FOAM, rng, 10, 0.15),
          "Sand")  # foam bulging through a split
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
