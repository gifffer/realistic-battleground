"""props_walls: the wall and facade detailing of the alleys (code-made, parts only).

Every builder has the same signature:

    build(D, folder, origin, ry, rng, **options) -> number of parts made

    D        a citykit.Data
    folder   the folder path of the parts (e.g. "Alleys/Walls/Detail")
    origin   (x, y, z): for WALL props, the point ON THE WALL FACE at floor level;
             for free-standing ones (fence, background facade, building top...) the floor
             point given in each docstring.
    ry       turn about Y (degrees). For wall props: the local -Z points OUT of the wall
             (ry = 0: a wall whose face looks north, -Z).
    rng      a random.Random: sizes, tilts, wear and colours vary with it.

Local frame (citykit.Frame): +X along the wall (seen from the alley, facing the wall, +X is
on your LEFT), +Y up, -Z out of the wall. Overlays (grime, stains, posters...) are thin DECOR parts
in front of the face, in depth slots shared by every prop on that wall (zlayers: no two layers on
one plane, opaque blended colours where possible, at most 5 layers in one place).

Scale: a character is ~5 studs tall; a floor ~10 studs; a door ~4 x 7.5; 1 stud ~ 0.3 m.
Only built-in materials and colours, no textures / meshes. NO BOTTLES anywhere.

Art direction (from environment-art breakdowns and DevForum building advice): never a clean
box; wear follows logic (water runs down from sills, joints and brackets; soot rises from
vents and lamps; dirt and damp climb from the ground; hands grime door handles); frames and
sills stand proud of the wall so it isn't flat; slight irregular tilts; layered, torn,
overlapping surfaces tell that the place has been used for years.
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from citykit import (  # noqa: E402
    BALL,
    BLOCK,
    CYLINDER,
    DECOR,
    DECOR_SHADOW,
    PROP,
    SMALL,
    SOLID,
    WEDGE,
    Frame,
    jitter,
    mix,
    yxz_angles,
)
import zlayers  # noqa: E402

# ------------------------------------------------------------------ palette (dirty, desaturated)
BRICK = [(84, 60, 50), (96, 64, 52), (68, 49, 42), (80, 44, 36)]
BRICK_PALE = (112, 82, 66)
MORTAR = (112, 106, 96)
SOOT = (34, 31, 29)
DAMP = (40, 36, 32)
WET_DARK = (26, 24, 22)
MOSS = (46, 54, 34)
PLASTER = [(104, 98, 86), (94, 90, 80), (108, 100, 86), (88, 86, 80)]
CONCRETE = (96, 92, 86)
CONCRETE_DARK = (70, 68, 64)
STONE = (126, 120, 108)
EFFLO = (178, 174, 162)
RUST = (89, 47, 30)
RUST_DARK = (59, 29, 19)
RUST_STAIN = (72, 38, 22)
METAL = (58, 62, 64)
METAL_DARK = (40, 40, 40)
GALV = (104, 106, 104)
STEEL_PAINT = [(52, 60, 56), (66, 58, 50), (70, 34, 30), (46, 50, 58), (84, 80, 70)]
WOOD = (104, 87, 60)
WOOD_OLD = (78, 66, 50)
WOOD_DARK = (58, 46, 36)
FRAME_PAINT = [(150, 144, 128), (60, 66, 56), (88, 46, 38), (44, 40, 38)]
VOID = (12, 12, 13)
GLASS_DIRTY = [(64, 70, 66), (58, 60, 56), (72, 74, 66)]
PAPER = [(150, 142, 120), (134, 122, 100), (118, 108, 90), (140, 128, 104), (108, 102, 88)]
POSTER_INK = [(118, 44, 38), (40, 54, 70), (150, 120, 60), (60, 70, 52), (30, 28, 28)]
CABLE = (22, 22, 24)
PLASTIC_GREY = (120, 118, 108)
BEIGE = (150, 142, 120)
WARM = (255, 176, 110)
WARM_DIM = (168, 112, 64)
COLD_DIM = (96, 120, 140)
TV_DIM = (84, 104, 150)
WHITE = (180, 180, 170)


# ------------------------------------------------------------------ geometry helpers
def _unit(v):
    v = np.asarray(v, dtype=float)
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


def _beam_matrix(d, side=None):
    """Columns X, Y, Z: Y along d, Z as close to `side` as possible."""
    y = _unit(d)
    s = np.array(side if side is not None else (0, 0, 1), dtype=float)
    z = s - y * np.dot(s, y)
    if np.linalg.norm(z) < 1e-4:
        s = np.array((1, 0, 0), dtype=float)
        z = s - y * np.dot(s, y)
    z = _unit(z)
    x = np.cross(y, z)
    return np.column_stack([x, y, z])


def _rod_matrix(d):
    """Columns X (along d: a cylinder's axis), Y, Z."""
    x = _unit(d)
    ref = np.array((0, 1, 0) if abs(x[1]) < 0.9 else (1, 0, 0), dtype=float)
    y = _unit(ref - x * np.dot(ref, x))
    z = np.cross(x, y)
    return np.column_stack([x, y, z])


def beam(f, name, p0, p1, w, t, color, material, side=None, **kw):
    """A block from local point p0 to p1 (its Y), w wide (its X), t thick (its Z ~ `side`,
    default the wall normal: so in the wall plane w is the visible width)."""
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    m = f.m @ _beam_matrix(p1 - p0, side)
    folder = kw.pop("folder", None) or f.folder
    return f.D.part(folder, name, tuple(f.world((p0 + p1) / 2)), (w, float(np.linalg.norm(p1 - p0)), t),
                    color, material, rot=yxz_angles(m), **kw)


def rod(f, name, p0, p1, d, color, material, shape=CYLINDER, **kw):
    """A cylinder (diameter d) from local p0 to p1."""
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    m = f.m @ _rod_matrix(p1 - p0)
    folder = kw.pop("folder", None) or f.folder
    return f.D.part(folder, name, tuple(f.world((p0 + p1) / 2)), (float(np.linalg.norm(p1 - p0)), d, d),
                    color, material, rot=yxz_angles(m), shape=shape, **kw)


def _ov(k=0):
    """Local z centre of a 0.05-thick part meant to sit in front of overlay layer k: half a slot
    in front of slot k (zlayers.WALL_* depths), so it never shares a plane with an overlay.
    Used for invisible text carriers (their SurfaceGui draws on the front face) and crack lines."""
    return zlayers.wall_text_depth(k)


def overlay(f, name, x0, x1, y0, y1, color, k=0, tr=0.5, material="Concrete", rz=0.0, **kw):
    """A thin stain / paint / paper layer flat on the wall face. Matte by default (Concrete):
    a glossy translucent layer reads as a grey film, a matte one as a stain soaked in.

    The depth comes from zlayers.wall_layer: the next free slot of this wall plane, one slot in
    front of every overlay it overlaps (from any prop), each slot WALL_TH thick with an air gap,
    so no two layers share a plane or intersect. k is the order hint inside the prop (higher =
    in front). A translucent layer lying wholly over one opaque surface is made OPAQUE with the
    blended colour (nothing left to depth-sort). Returns the part index, or None when that place
    already has zlayers.WALL_MAX layers (the layer is dropped, never squeezed in)."""
    flags = kw.pop("flags", DECOR)
    return zlayers.wall_layer(f, name, (x0 + x1) / 2, (y0 + y1) / 2, abs(x1 - x0), abs(y1 - y0), rz, color, k, tr,
                              material, flags, **kw)


def streak(f, rng, name, x, y_top, length, width, color, k=1, tr=0.55, taper=3):
    """A run-off stain hanging down from (x, y_top): up to 2 overlapping layers (darkest and
    narrowest at the source), slightly wavy. More layers bought nothing once they are opaque
    blends, and each one takes a wall slot. Returns the number of parts made."""
    taper = max(1, min(taper, 2))
    n = 0
    for i in range(taper):
        t = i / max(1, taper - 1)
        w = width * (1 - 0.55 * t) * rng.uniform(0.85, 1.1)
        ln = length * (1 - 0.45 * t) * rng.uniform(0.85, 1.05)
        xo = x + rng.uniform(-0.06, 0.06) * width
        if overlay(f, name, xo - w / 2, xo + w / 2, y_top - ln, y_top, jitter(color, rng, 5, 0.1 * i), k=k + i,
                   tr=min(0.9, tr + 0.12 * (taper - 1 - i)), rz=rng.uniform(-1.2, 1.2)) is not None:
            n += 1
    return n


def soft(f, rng, name, x0, x1, y0, y1, color, opacity=0.5, layers=3, k=0, anchor="center", material="Concrete",
         ragged=0.25):
    """A soft-edged stain: up to 2 nested layers shrinking toward the centre (or toward the
    bottom / top edge for anchor = "bottom" / "top"), so the colour builds up toward the core
    instead of ending on one hard edge. opacity = at the core. Each layer takes a wall slot,
    and the layers are made opaque blends where they lie on one surface. So the gradient is 2
    steps, not 3. Returns the number of parts made."""
    layers = max(1, min(layers, 2))
    a = 1 - (1 - opacity) ** (1 / layers)
    w, h = x1 - x0, y1 - y0
    n = 0
    for i in range(layers):
        s = 1 - 0.6 * i / max(1, layers - 1) if layers > 1 else 1.0
        sw = w * (1 - (1 - s) * 0.6) * rng.uniform(1 - ragged * 0.3, 1.0)
        sh = h * s * rng.uniform(1 - ragged * 0.4, 1.0)
        cx = (x0 + x1) / 2 + rng.uniform(-ragged, ragged) * (w - sw) * 0.5
        if anchor == "bottom":
            cy = y0 + sh / 2
        elif anchor == "top":
            cy = y1 - sh / 2
        else:
            cy = (y0 + y1) / 2 + rng.uniform(-ragged, ragged) * (h - sh) * 0.5
        if overlay(f, name, cx - sw / 2, cx + sw / 2, cy - sh / 2, cy + sh / 2, jitter(color, rng, 3), k=k + i,
                   tr=1 - a, material=material, rz=rng.uniform(-0.8, 0.8)) is not None:
            n += 1
    return n


def frame_at(D, folder, origin, ry):
    """The prop's frame. Also starts a new zlayers instance: this prop's overlays go in front of
    those of every prop placed before it on the same wall."""
    zlayers.new_instance(D)
    return Frame(D, folder, origin=origin, ry=ry)


def light_extra(tags, light, attrs=None):
    ex = {"t": tags, "l": light}
    if attrs:
        ex["a"] = attrs
    return ex


def sign_extra(text, color, font="PermanentMarker", lit=False, face="Front"):
    return {"g": {"text": text, "font": font, "color": [int(c) for c in color], "face": face, "lit": lit,
                  "bg": None, "bg_tr": 1.0, "rot": 0, "align": "Center"}}


# =================================================================================================
# 1. Surfaces: grime, plaster, cracks, stains, posters, signs, graffiti
# =================================================================================================


def wall_grime(D, folder, origin, ry, rng, width=12.0, height=5.0, soot=True, moss=True):
    """Damp and soot gradient at the foot of a wall: rising damp built up in overlapping
    translucent bands (each a few pieces of different heights, so the top edge is ragged
    and the colour deepens toward the ground), a wet splash band, moss in the corner of the
    floor, and an optional soot haze higher up. Footprint: width x height (flat on the face).
    Parts: 12-28."""
    f = frame_at(D, folder, origin, ry)
    n = 0
    bands = 4
    # continuous bands (a smooth vertical gradient, darkest at the ground)...
    for b in range(bands):
        t = b / (bands - 1)
        h = height * (0.85 - 0.62 * t) * rng.uniform(0.9, 1.1)
        col = jitter(mix(DAMP, WET_DARK, t), rng, 3)
        if b == 0:  # the tide mark: uneven runs, never one straight line
            segs = max(3, min(7, int(width / 3)))
            edges = sorted(rng.uniform(-width / 2, width / 2) for _ in range(segs - 1))
            edges = [-width / 2] + edges + [width / 2]
            for a, c in zip(edges, edges[1:]):
                if c - a < 0.3:
                    continue
                overlay(f, "Damp", a - 0.15, c + 0.15, 0, h * rng.uniform(0.75, 1.15), col, k=b, tr=0.8,
                        rz=rng.uniform(-1.2, 1.2))
                n += 1
            continue
        x0 = -width / 2 + rng.uniform(0, 0.4)
        x1 = width / 2 - rng.uniform(0, 0.4)
        overlay(f, "Damp", x0, x1, 0, h, col, k=b, tr=0.8, rz=rng.uniform(-0.3, 0.3))
        n += 1
    # ...and faint tongues climbing higher where the wall wicks more water (ragged tide mark)
    for _ in range(max(2, min(5, int(width / 4)))):
        x = rng.uniform(-width / 2 + 1, width / 2 - 1)
        w = rng.uniform(1.2, 3.5)
        overlay(f, "Damp", max(-width / 2, x - w / 2), min(width / 2, x + w / 2), 0, height * rng.uniform(0.95, 1.25),
                jitter(DAMP, rng, 3), k=bands, tr=0.86, rz=rng.uniform(-0.6, 0.6))
        n += 1
    overlay(f, "Splash", -width / 2, width / 2, 0, rng.uniform(0.35, 0.6), WET_DARK, k=bands + 1, tr=0.6)
    n += 1
    if moss:
        for _ in range(rng.randint(1, 3)):
            x = rng.uniform(-width / 2 + 0.6, width / 2 - 0.6)
            w = rng.uniform(0.6, 1.8)
            n += soft(f, rng, "Moss", x - w / 2, x + w / 2, 0, rng.uniform(0.3, 0.8), jitter(MOSS, rng, 6), opacity=0.55,
                      layers=2, k=bands + 2, anchor="bottom", material="Grass")
    if soot:
        x = rng.uniform(-width / 4, width / 4)
        w = rng.uniform(width * 0.35, width * 0.6)
        y0 = height * rng.uniform(0.7, 1.0)
        n += soft(f, rng, "Soot", x - w / 2, x + w / 2, y0, y0 + rng.uniform(2, 4), SOOT, opacity=0.3, layers=3, k=0)
    return n


def plaster_patch(D, folder, origin, ry, rng, width=6.0, height=5.0, y=2.0, color=None, brick=None):
    """A patch of old render on a brick wall, chipped away at its edges and in one hole so
    the brick shows through: irregular rows of render (each row a few runs with jagged ends),
    loose bricks standing proud in the hole, a darker dirt band at its foot.
    Footprint: width x height at height y. Parts: 10-26."""
    f = frame_at(D, folder, origin, ry)
    base = color or rng.choice(PLASTER)
    brick = brick or rng.choice(BRICK)
    n = 0
    rows = max(4, int(height / 0.65))
    hs = [rng.uniform(0.6, 1.4) for _ in range(rows)]
    hs = [h * height / sum(hs) for h in hs]
    starts = [y + sum(hs[:i]) for i in range(rows)]
    hole_c = (rng.uniform(-width * 0.25, width * 0.25), y + rng.uniform(0.3, 0.7) * height)
    hole_r = rng.uniform(0.18, 0.3) * min(width, height)
    thick = rng.uniform(0.08, 0.1)
    for r in range(rows):
        y0 = starts[r] + rng.uniform(-0.04, 0.04)
        y1 = y0 + hs[r] + 0.08
        # each row is shorter at the patch's top/bottom (the patch is roughly oval)
        t = abs((r + 0.5) / rows - 0.5) * 2
        half = width / 2 * (1 - 0.35 * t * t) * rng.uniform(0.85, 1.0)
        x0, x1 = -half + rng.uniform(-0.25, 0.25), half + rng.uniform(-0.25, 0.25)
        ym = (y0 + y1) / 2
        dy = abs(ym - hole_c[1])
        if dy < hole_r:  # the row is cut by the hole: two runs
            hw = math.sqrt(hole_r * hole_r - dy * dy) * rng.uniform(0.8, 1.2)
            runs = [(x0, hole_c[0] - hw), (hole_c[0] + hw, x1)]
        else:
            runs = [(x0, x1)]
        for a, b in runs:
            if b - a < 0.3:
                continue
            # one even skin (same colour / thickness, overlapping runs: no seams), only its
            # outline is jagged; the chipped edge shows as the runs' uneven ends
            tk = thick + 0.008 * (r % 2)  # overlapping rows never coplanar (no z-fighting)
            f.part("Render", ((a + b) / 2, (y0 + y1) / 2, -tk / 2), (b - a, y1 - y0 + 0.1, tk),
                   jitter(base, rng, 1.5), "Plaster", rot=(0, 0, rng.uniform(-0.4, 0.4)), flags=DECOR)
            n += 1
    # loose / exposed bricks in the hole (proud, darker, chipped)
    for _ in range(rng.randint(2, 4)):
        bx = hole_c[0] + rng.uniform(-hole_r * 0.6, hole_r * 0.6)
        by = hole_c[1] + rng.uniform(-hole_r * 0.6, hole_r * 0.6)
        f.part("Brick", (bx, by, -0.05), (rng.uniform(0.75, 0.95), 0.36, 0.1), jitter(brick, rng, 10, 0.1), "Brick",
               rot=(0, 0, rng.uniform(-3, 3)), flags=DECOR)
        n += 1
    # dirt on the render (darker toward its foot) and a run-off streak
    n += soft(f, rng, "Dirt", -width * 0.45, width * 0.45, y, y + height * 0.45, DAMP, opacity=0.35, layers=2, k=4,
              anchor="bottom")
    n += streak(f, rng, "Streak", rng.uniform(-width / 3, width / 3), y + height, height * 0.7, 0.5, DAMP, k=5,
                tr=0.72, taper=2)
    return n


def crack(D, folder, origin, ry, rng, length=5.0, y=3.0, x=0.0, branch=True):
    """A crack wandering down the wall from (x, y + length): a jagged polyline of thin dark
    slivers, wider at its origin, with a side branch. Footprint: ~length tall. Parts: 3-9."""
    f = frame_at(D, folder, origin, ry)
    n = 0

    def walk(px, py, total, width, k):
        nonlocal n
        made = 0
        while total > 0 and made < 6:
            step = min(total, rng.uniform(0.5, 1.2))
            ang = math.radians(rng.uniform(-40, 40))
            qx, qy = px + math.sin(ang) * step, py - math.cos(ang) * step
            beam(f, "Crack", (px, py, _ov(k)), (qx, qy, _ov(k)), width, 0.05, jitter(WET_DARK, rng, 4), "Slate",
                 flags=DECOR)
            n += 1
            made += 1
            px, py, total, width = qx, qy, total - step, max(0.05, width * 0.8)
        return px, py

    top = y + length
    walk(x, top, length * 0.65, rng.uniform(0.1, 0.16), 0)
    if branch:
        walk(x + rng.uniform(-0.3, 0.3), top - length * rng.uniform(0.2, 0.4), length * 0.35, 0.07, 1)
    return n


def rust_streak(D, folder, origin, ry, rng, x=0.0, y=8.0, length=4.0, width=0.6, bolt=True):
    """Rust run-off under a fixing (bolt / old bracket stub) at (x, y): tapered orange-brown
    layers, darkest at the source. Footprint: width x length. Parts: 3-5."""
    f = frame_at(D, folder, origin, ry)
    n = 0
    if bolt:
        f.part("Stub", (x, y, -0.08), (0.22, 0.22, 0.16), jitter(RUST_DARK, rng, 5), "CorrodedMetal", flags=DECOR)
        n += 1
    n += streak(f, rng, "RustStreak", x, y, length, width, jitter(RUST_STAIN, rng, 8), k=0, tr=0.62,
                taper=rng.randint(2, 3))
    return n


def efflorescence(D, folder, origin, ry, rng, width=4.0, y=0.4, height=1.6):
    """White salt bloom on brick (where water evaporates: above the damp line, under sills):
    a few chalky translucent blotches with a crisper tide line. Footprint: width x height.
    Parts: 3-6."""
    f = frame_at(D, folder, origin, ry)
    n = 0
    for _ in range(rng.randint(2, 4)):
        cx = rng.uniform(-width / 2 + 0.5, width / 2 - 0.5)
        w = rng.uniform(0.8, width * 0.6)
        h = rng.uniform(0.4, height)
        overlay(f, "Salt", cx - w / 2, cx + w / 2, y, y + h, jitter(EFFLO, rng, 6), k=rng.randint(0, 2),
                tr=rng.uniform(0.62, 0.78), rz=rng.uniform(-3, 3))
        n += 1
    overlay(f, "TideLine", -width / 2, width / 2, y + height * 0.8, y + height * 0.8 + 0.12, EFFLO, k=3, tr=0.55,
            rz=rng.uniform(-1.5, 1.5))
    return n + 1


POSTER_TEXTS = ["MISSING", "LIVE · THE ROT", "CASH FOR GOLD", "ROOMS · NO ID", "LOST DOG", "FIGHT NIGHT",
                "WE BUY ANYTHING", "REWARD", "CLUB HOLLOW", "VOTE NO", "EVICTION NOTICE"]


def torn_posters(D, folder, origin, ry, rng, width=3.6, height=4.2, y=3.5, text=None, layers=None):
    """Fly-posting built up over years: several paper layers (older ones larger and paler),
    torn so the lower layers and the wall show, a hanging peeled flap, glue stains and
    tape. The top poster carries a faded headline. Footprint: width x height. Parts: 9-18."""
    f = frame_at(D, folder, origin, ry)
    n = 0
    layers = layers or rng.randint(2, 4)
    for i in range(layers):
        w = width * rng.uniform(0.55, 0.85) * (1.15 - 0.1 * i)
        h = height * rng.uniform(0.55, 0.85) * (1.15 - 0.1 * i)
        cx = rng.uniform(-width / 2 + w / 2, width / 2 - w / 2) if width > w else 0.0
        y0 = y + rng.uniform(0, max(0.01, height - h))
        paper = jitter(rng.choice(PAPER), rng, 8, 0.05 * (layers - i))
        rz = rng.uniform(-2.5, 2.5)
        # the sheet: top part intact, the bottom torn into a ragged remnant
        cut = rng.uniform(0.35, 0.65)
        overlay(f, "Poster", cx - w / 2, cx + w / 2, y0 + h * cut, y0 + h, paper, k=i, tr=0.0, rz=rz)
        rw = w * rng.uniform(0.4, 0.8)
        rx = cx + rng.uniform(-(w - rw) / 2, (w - rw) / 2)
        overlay(f, "Poster", rx - rw / 2, rx + rw / 2, y0 + h * cut * rng.uniform(0.2, 0.6), y0 + h * cut + 0.02,
                paper, k=i, tr=0.0, rz=rz + rng.uniform(-3, 3))
        n += 2
        if i == layers - 1 or rng.random() < 0.4:  # a printed band (photo / headline block)
            ink = jitter(rng.choice(POSTER_INK), rng, 8, 0.15)
            overlay(f, "Print", cx - w * 0.38, cx + w * 0.38, y0 + h * 0.62, y0 + h * 0.9, ink, k=i + 1,
                    tr=rng.uniform(0.25, 0.45), rz=rz)
            n += 1
        if i == layers - 1:
            label = text or rng.choice(POSTER_TEXTS)
            f.part("PosterText", (cx, y0 + h * 0.76, _ov(i + 2)), (w * 0.82, h * 0.22, 0.05), (0, 0, 0),
                   "SmoothPlastic", rot=(0, 0, rz), transparency=1, flags=DECOR,
                   extra=sign_extra(label, jitter((40, 34, 30), rng, 6), font=rng.choice(["Oswald", "Bodoni", "Arial"])))
            n += 1
            # the peeled flap: a corner hanging off the wall
            fx = cx + (w / 2 - 0.35) * rng.choice((-1, 1))
            f.part("Flap", (fx, y0 + h * cut - 0.35, -0.16), (0.7, 0.7, 0.05), paper, "SmoothPlastic",
                   rot=(rng.uniform(18, 32), 0, rng.uniform(-25, 25)), flags=DECOR)
            n += 1
    # glue tide marks and tape
    n += soft(f, rng, "Glue", -width / 2, width / 2, y - 0.3, y + height, (104, 98, 80), opacity=0.25, layers=2, k=0)
    for _ in range(rng.randint(1, 2)):
        tx = rng.uniform(-width / 2, width / 2)
        overlay(f, "Tape", tx - 0.25, tx + 0.25, y + height * rng.uniform(0.6, 0.95), y + height * rng.uniform(0.6, 0.95) + 0.12,
                (170, 160, 120), k=layers + 2, tr=0.35, rz=rng.uniform(-30, 30))
        n += 1
    return n


def painted_sign(D, folder, origin, ry, rng, width=9.0, height=2.4, y=11.0, text="HARLAN & SONS · TANNERY",
                 color=None, ground=None):
    """A faded 'ghost sign' painted on brick decades ago: weathered ground colour, a border,
    the lettering half gone, bare patches where the paint flaked off, a soot wash.
    Footprint: width x height at y. Parts: 9-16."""
    f = frame_at(D, folder, origin, ry)
    ground = ground or jitter(rng.choice([(108, 92, 64), (70, 76, 70), (96, 54, 44), (120, 116, 104)]), rng, 6)
    ink = color or jitter(rng.choice([(176, 166, 140), (150, 140, 112), (30, 30, 28)]), rng, 6)
    overlay(f, "SignGround", -width / 2, width / 2, y, y + height, ground, k=0, tr=0.55)
    for yy in (y + 0.12, y + height - 0.12):
        overlay(f, "SignBorder", -width / 2 + 0.12, width / 2 - 0.12, yy - 0.05, yy + 0.05, ink, k=1, tr=0.5)
    f.part("SignText", (0, y + height / 2, _ov(2)), (width * 0.92, height * 0.62, 0.05), (0, 0, 0), "SmoothPlastic",
           transparency=1, flags=DECOR, extra=sign_extra(text, mix(ink, ground, 0.35), font="Oswald"))
    n = 4
    for _ in range(rng.randint(2, 3)):  # flaked patches: bare (darker, sooty) brick
        px = rng.uniform(-width / 2 + 0.8, width / 2 - 0.8)
        pw = rng.uniform(0.7, 1.8)
        py = rng.uniform(y, y + height * 0.7)
        overlay(f, "Flaked", px - pw / 2, px + pw / 2, py, py + rng.uniform(0.4, 0.9), jitter(BRICK[2], rng, 6), k=3,
                tr=0.15, rz=rng.uniform(-6, 6), material="Brick")
        n += 1
    n += soft(f, rng, "SootWash", -width / 2 - 0.5, width / 2 + 0.5, y - 0.8, y + height + 0.6, SOOT, opacity=0.3,
              layers=2, k=4)
    for _ in range(rng.randint(1, 3)):  # rain has washed streaks through the paint
        n += streak(f, rng, "RunOff", rng.uniform(-width / 2, width / 2), y + height + 0.3, height + rng.uniform(0.5, 2),
                    rng.uniform(0.3, 0.6), SOOT, k=6, tr=0.74, taper=2)
    return n


GRAFFITI_TAGS = ["NO COPS", "R0T", "SKUL", "MARROW", "DEAD END", "KRASH", "SLEEP LIGHT", "VIC OWES", "HOLLOW",
                 "ASK FOR VIC", "N.O.D.", "RATKING"]


def graffiti_tag(D, folder, origin, ry, rng, width=5.0, height=1.8, y=4.0, x=0.0, text=None, color=None,
                 buffed=None, drips=True):
    """A spray-painted tag: the text (a "g" sign on an invisible part, face Front), paint
    drips running under it, and often an older tag 'buffed' out under a mismatched grey
    patch. Footprint: width x height. Parts: 1-6."""
    f = frame_at(D, folder, origin, ry)
    color = color or jitter(rng.choice([(180, 176, 160), (170, 60, 50), (60, 90, 120), (190, 180, 120),
                                         (30, 30, 30), (120, 150, 90)]), rng, 10)
    n = 0
    if buffed if buffed is not None else rng.random() < 0.4:
        overlay(f, "Buff", x - width * 0.6, x + width * 0.55, y - height * 0.15, y + height * 1.1,
                jitter((92, 88, 80), rng, 6), k=0, tr=0.1, rz=rng.uniform(-1, 1), material="Concrete")
        n += 1
    rz = rng.uniform(-6, 6)
    f.part("Graffiti", (x, y + height / 2, _ov(1)), (width, height, 0.05), (0, 0, 0), "SmoothPlastic",
           rot=(0, 0, rz), transparency=1, flags=DECOR,
           extra=sign_extra(text or rng.choice(GRAFFITI_TAGS), color, font=rng.choice(["PermanentMarker", "Kalam"])))
    n += 1
    if drips:
        for _ in range(rng.randint(1, 4)):
            dx = x + rng.uniform(-width * 0.4, width * 0.4)
            ln = rng.uniform(0.3, 1.2)
            overlay(f, "Drip", dx - 0.035, dx + 0.035, y + height * 0.25 - ln, y + height * 0.3, color, k=2, tr=0.15)
            n += 1
    return n


# =================================================================================================
# 2. Openings: windows, doors, shutters
# =================================================================================================


def window(D, folder, origin, ry, rng, width=3.4, height=5.0, y=4.0, variant="dirty", frame_color=None, x=0.0,
           kind="warm"):
    """A sash window unit set into the wall: dark room behind (void), stone surround standing
    proud, concrete lintel (settled, cracked), sloped stone sill with dirt streaks running
    off its ends, painted timber frame with a meeting rail, dirty glass.
    Variants: "dirty" (grimy panes, sagging blind), "lit" (warm room light, half-drawn
    curtain, tag CityWindowLit + a weak light), "boarded" (plywood + nailed planks),
    "barred" (rusted security bars on lugs), "broken" (panes smashed, shards in the frame
    and on the sill). Footprint: (width + 1) x (height + 1.2), 0.6 deep. Parts: 18-34 (boarded ~18, barred ~33)."""
    f = frame_at(D, folder, origin, ry)
    f = f.sub((x, 0, 0))
    w, h = width, height
    n = 0
    fc = frame_color or jitter(rng.choice(FRAME_PAINT), rng, 6)
    surround = jitter(rng.choice([STONE, BRICK_PALE, CONCRETE]), rng, 6)
    lit = variant == "lit"
    # the room behind
    if lit:
        f.box("Room", (-w / 2, y, -0.07), (w / 2, y + h, -0.02), (30, 32, 34), "Glass", flags=DECOR,
              extra={"t": ["CityWindowLit"], "a": {"Kind": kind, "Day": True},
                     "l": {"type": "Point", "color": list(WARM), "range": 12, "brightness": 0.45, "name": "Light",
                           "shadows": False}})
    else:
        f.box("Void", (-w / 2, y, -0.07), (w / 2, y + h, -0.02), VOID, "SmoothPlastic", flags=DECOR)
    n += 1
    # surround, lintel, sill
    for s in (-1, 1):
        f.box("Jamb", (s * w / 2, y - 0.05, -0.26), (s * (w / 2 + 0.38), y + h, 0.0), jitter(surround, rng, 4), "Concrete",
              flags=DECOR)
        n += 1
    f.part("Lintel", (rng.uniform(-0.05, 0.05), y + h + 0.32, -0.15), (w + 1.0 + rng.uniform(0, 0.2), 0.64, 0.32),
           jitter(CONCRETE, rng, 6), "Concrete", rot=(0, 0, rng.uniform(-0.8, 0.8)), flags=DECOR)
    f.part("Sill", (0, y - 0.18, -0.26), (w + 0.9, 0.34, 0.6), jitter(STONE, rng, 6, 0.08), "Slate",
           rot=(-4, 0, rng.uniform(-1.2, 1.2)), flags=DECOR_SHADOW)
    n += 2
    # crack through the lintel, dirt run-off from the sill ends and soot above the lintel
    beam(f, "Crack", (rng.uniform(-w / 4, w / 4), y + h + 0.62, -0.32), (rng.uniform(-w / 4, w / 4), y + h + 0.02, -0.32),
         0.06, 0.03, WET_DARK, "Slate", flags=DECOR)
    n += 1
    for s in (-1, 1):
        n += streak(f, rng, "SillStain", s * (w / 2 + rng.uniform(0.1, 0.3)), y - 0.3, rng.uniform(1.4, 3.2),
                    rng.uniform(0.25, 0.4), DAMP, k=0, tr=0.68, taper=2)
    overlay(f, "Soot", -w / 2 - 0.4, w / 2 + 0.4, y + h + 0.64, y + h + rng.uniform(1.2, 2.2), SOOT, k=0, tr=0.8)
    n += 1
    if variant == "boarded":
        f.box("Plywood", (-w / 2 - 0.1, y - 0.05, -0.36), (w / 2 + 0.1, y + h + 0.05, -0.28),
              jitter((112, 96, 70), rng, 8, 0.1), "WoodPlanks", flags=DECOR)
        n += 1
        for i in range(rng.randint(2, 4)):
            py = y + h * (0.15 + 0.7 * i / 3) + rng.uniform(-0.2, 0.2)
            f.part("Plank", (rng.uniform(-0.1, 0.1), py, -0.44), (w + rng.uniform(0.6, 1.2), rng.uniform(0.45, 0.7), 0.14),
                   jitter(rng.choice([WOOD_OLD, WOOD, WOOD_DARK]), rng, 8), "Wood", rot=(0, 0, rng.uniform(-14, 14)),
                   flags=DECOR)
            n += 1
        overlay(f, "Water", -w / 2, w / 2, y, y + h * 0.4, WET_DARK, k=0, tr=0.7)
        f.part("Spray", (0, y + h * 0.55, -0.53), (w * 0.9, h * 0.3, 0.05), (0, 0, 0), "SmoothPlastic", transparency=1,
               flags=DECOR, extra=sign_extra(rng.choice(["KEEP OUT", "X", "CONDEMNED", "NO ENTRY"]),
                                              jitter((170, 60, 50), rng, 10)))
        return n + 2
    # timber frame and sashes
    fw = 0.2
    for s in (-1, 1):
        f.box("Frame", (s * w / 2, y, -0.22), (s * (w / 2 - fw), y + h, -0.05), fc, "Wood", flags=DECOR)
    f.box("Frame", (-w / 2, y + h - fw, -0.22), (w / 2, y + h, -0.05), fc, "Wood", flags=DECOR)
    f.box("Frame", (-w / 2, y, -0.22), (w / 2, y + fw, -0.05), jitter(fc, rng, 4, 0.15), "Wood", flags=DECOR)
    mid = y + h * rng.uniform(0.48, 0.55)
    f.box("MeetingRail", (-w / 2 + fw, mid - 0.09, -0.24), (w / 2 - fw, mid + 0.09, -0.08), fc, "Wood", flags=DECOR)
    n += 5
    # peeled paint on the bottom rail (the timber shows)
    overlay(f, "Peel", -w / 4, w / 4, y + 0.02, y + fw - 0.02, WOOD_DARK, k=0, tr=0.1)
    f.part("Peel", (rng.uniform(-w / 3, w / 3), y + 0.1, -0.235), (rng.uniform(0.3, 0.8), 0.14, 0.03), WOOD_DARK,
           "Wood", flags=DECOR)
    n += 1
    panes = [(y + fw, mid - 0.09), (mid + 0.09, y + h - fw)]
    gc = jitter(rng.choice(GLASS_DIRTY), rng, 4)
    if variant == "broken":
        missing = rng.randrange(2)
        for i, (a, b) in enumerate(panes):
            if i != missing and rng.random() < 0.7:
                f.box("Glass", (-w / 2 + fw, a, -0.15), (w / 2 - fw, b, -0.13), gc, "Glass", transparency=0.25,
                      flags=DECOR)
                beam(f, "GlassCrack", (rng.uniform(-w / 3, 0), b - 0.1, -0.17), (rng.uniform(0, w / 3), a + 0.1, -0.17),
                     0.05, 0.02, (150, 156, 150), "SmoothPlastic", flags=DECOR, transparency=0.3)
                n += 2
                continue
            # jagged shards left in the corners (wedges in the wall plane)
            pw, ph = w - 2 * fw, b - a
            for corner in rng.sample([(0, -1, -1), (90, -1, 1), (180, 1, 1), (270, 1, -1)], rng.randint(1, 3)):
                ang, sx, sy = corner
                sw = rng.uniform(0.3, 0.6) * min(pw, ph)
                cx = sx * (pw / 2 - sw / 2)
                cy = (a + b) / 2 + sy * (ph / 2 - sw / 2)
                f.part("Shard", (cx, cy, -0.14), (0.04, sw, sw * rng.uniform(0.7, 1.3)), gc, "Glass",
                       rot=(ang, 90, 0), shape=WEDGE, transparency=0.25, flags=DECOR)
                n += 1
        for _ in range(rng.randint(1, 3)):
            f.part("Shard", (rng.uniform(-w / 2, w / 2), y + 0.01, -0.35), (rng.uniform(0.15, 0.4), 0.04, rng.uniform(0.1, 0.3)),
                   gc, "Glass", rot=(0, rng.uniform(0, 180), 0), transparency=0.2, flags=DECOR)
            n += 1
        return n
    for (a, b) in panes:
        f.box("Glass", (-w / 2 + fw, a, -0.15), (w / 2 - fw, b, -0.13), jitter(gc, rng, 3), "Glass",
              transparency=0.45 if lit else 0.3, flags=DECOR)
        n += 1
    # grime crusted in the bottom of each pane
    f.box("Grime", (-w / 2 + fw, y + fw, -0.165), (w / 2 - fw, y + fw + rng.uniform(0.35, 0.7), -0.155),
          (52, 48, 40), "SmoothPlastic", transparency=0.45, flags=DECOR)
    n += 1
    if lit:  # a half-drawn curtain (inside: between the room light and the glass)
        cw = w * rng.uniform(0.35, 0.6)
        side = rng.choice((-1, 1))
        f.box("Curtain", (side * (w / 2 - fw) - side * cw, y + fw, -0.11), (side * (w / 2 - fw), y + h - fw, -0.09),
              jitter(rng.choice([(110, 52, 44), (60, 70, 60), (120, 108, 84)]), rng, 8), "Fabric", flags=DECOR,
              transparency=0.15)
        n += 1
    elif variant == "dirty":  # a sagging, broken venetian blind / a sheet
        if rng.random() < 0.5:
            for i in range(rng.randint(3, 5)):
                yy = y + h - fw - 0.25 - i * 0.28
                f.part("Blind", (0, yy, -0.1), (w - 2 * fw - 0.05, 0.06, 0.04), (150, 146, 128), "SmoothPlastic",
                       rot=(0, 0, rng.uniform(-4, 4) * (i + 1) * 0.5), flags=DECOR)
                n += 1
        else:
            f.box("Sheet", (-w / 2 + fw, mid - h * 0.15, -0.11), (w / 2 - fw, y + h - fw, -0.09),
                  jitter((96, 92, 80), rng, 8), "Fabric", flags=DECOR)
            n += 1
    if variant == "barred":
        bars = max(3, int(w / 0.7))
        for i in range(bars):
            bx = -w / 2 + (i + 0.5) * w / bars
            rod(f, "Bar", (bx, y - 0.02, -0.5), (bx + rng.uniform(-0.04, 0.04), y + h + 0.02, -0.5), 0.14,
                jitter(RUST_DARK, rng, 6), "CorrodedMetal", flags=DECOR_SHADOW)
            n += 1
        for yy in (y + 0.4, y + h - 0.4):
            f.box("FlatBar", (-w / 2 - 0.3, yy - 0.08, -0.6), (w / 2 + 0.3, yy + 0.08, -0.4), jitter(RUST, rng, 6),
                  "CorrodedMetal", flags=DECOR_SHADOW)
            for s in (-1, 1):
                f.box("Lug", (s * (w / 2 + 0.12) - 0.08, yy - 0.08, -0.5), (s * (w / 2 + 0.12) + 0.08, yy + 0.08, 0),
                      RUST_DARK, "CorrodedMetal", flags=DECOR)
            n += 3
        n += streak(f, rng, "RustStreak", rng.uniform(-w / 2, w / 2), y + 0.3, rng.uniform(1.5, 2.5), 0.4, RUST_STAIN,
                    k=1, taper=2)
    return n


def back_door(D, folder, origin, ry, rng, width=4.0, height=7.6, variant="closed", light=True, x=0.0,
              stencil=None, color=None, dead_light=False):
    """A steel service door: concrete step (chipped, dirty), steel channel frame, painted
    leaf with diamond-plate kick plate, pull handle and deadlock, hinges, a closer arm,
    primer showing where paint flaked, hand grime round the handle, rust along the foot,
    stencilled warning, and a caged bulkhead light above (optional).
    Variants: "closed", "ajar" (swung out 12-25 deg, dark corridor behind), "chained"
    (a chain and padlock across the handle and a hasp). Footprint: (width + 1.2) x 1.4 deep,
    (height + 2.5) tall with the light. Parts: 38-48."""
    f = frame_at(D, folder, origin, ry).sub((x, 0, 0))
    w, h = width, height
    paint = color or jitter(rng.choice(STEEL_PAINT), rng, 6)
    n = 0
    # step
    f.part("Step", (rng.uniform(-0.1, 0.1), 0.22, -0.68), (w + 1.2, 0.45, 1.36), jitter(CONCRETE, rng, 6),
           "Concrete", rot=(0, rng.uniform(-1.5, 1.5), 0), flags=SOLID)
    f.part("StepChip", ((w / 2 + 0.45) * rng.choice((-1, 1)), 0.33, -1.3), (0.5, 0.3, 0.3), jitter(CONCRETE_DARK, rng, 6),
           "Concrete", rot=(rng.uniform(-20, 20), rng.uniform(0, 90), rng.uniform(-15, 15)), flags=DECOR)
    f.box("StepDirt", (-w / 2 - 0.5, 0.45, -1.3), (w / 2 + 0.5, 0.48, -0.05), WET_DARK, "SmoothPlastic",
          transparency=0.55, flags=DECOR)
    n += 3
    # opening, frame
    f.box("Void", (-w / 2, 0.45, -0.05), (w / 2, h, -0.02), VOID, "SmoothPlastic", flags=DECOR)
    for s in (-1, 1):
        f.box("DoorFrame", (s * w / 2, 0.45, -0.28), (s * (w / 2 + 0.32), h + 0.32, 0.0), jitter(METAL_DARK, rng, 6),
              "Metal", flags=DECOR)
    f.box("DoorFrame", (-w / 2 - 0.32, h, -0.28), (w / 2 + 0.32, h + 0.32, 0.0), jitter(METAL_DARK, rng, 6), "Metal",
          flags=DECOR)
    n += 4
    # the leaf (in its own frame about the hinge, left side)
    angle = rng.uniform(12, 25) if variant == "ajar" else 0.0
    g = f.sub((-w / 2 + 0.04, 0.47, -0.06), ry=angle)
    lw, lh = w - 0.1, h - 0.52
    g.box("DoorLeaf", (0, 0, -0.22), (lw, lh, 0), paint, "Metal", flags=SOLID)
    g.box("KickPlate", (0.1, 0.05, -0.27), (lw - 0.1, 1.25, -0.22), jitter(GALV, rng, 6, 0.2), "DiamondPlate",
          flags=DECOR)
    n += 2
    # paint wear: primer patches, grime from boots at the foot and hands round the handle
    # paint lost where the door is hit and kicked: the free edge, the bottom corners, round the lock
    spots = [(lw - rng.uniform(0.1, 0.3), rng.uniform(1.4, lh - 1)), (rng.uniform(0.15, 0.6), rng.uniform(1.3, 1.8)),
             (lw - 0.55 + rng.uniform(-0.3, 0.3), rng.uniform(4.9, 5.4))]
    for px, py in spots[:rng.randint(2, 3)]:
        g.part("PaintLoss", (px, py, -0.232), (rng.uniform(0.15, 0.45), rng.uniform(0.25, 0.8), 0.03),
               jitter(mix(paint, RUST_DARK, 0.6), rng, 6), "CorrodedMetal", rot=(0, 0, rng.uniform(-35, 35)), flags=DECOR)
        n += 1
    for _ in range(2):  # key scratches round the lock (bare steel)
        sx, sy = lw - 0.55 + rng.uniform(-0.25, 0.25), 4.6 + rng.uniform(-0.35, 0.35)
        beam(g, "Scratch", (sx, sy, -0.24), (sx + rng.uniform(-0.3, 0.3), sy + rng.uniform(-0.3, 0.3), -0.24), 0.03, 0.02,
             (120, 122, 118), "Metal", flags=DECOR)
        n += 1
    g.box("HandGrime", (lw - 0.95, 2.9, -0.245), (lw - 0.15, 4.3, -0.225), WET_DARK, "SmoothPlastic", transparency=0.75,
          flags=DECOR)
    g.box("FootGrime", (0, 1.25, -0.245), (lw, 1.9, -0.225), WET_DARK, "SmoothPlastic", transparency=0.8,
          flags=DECOR)
    g.box("RustFoot", (0, 0, -0.235), (lw, 0.12, -0.215), RUST_DARK, "CorrodedMetal", flags=DECOR)
    n += 3
    # hardware: pull handle, deadlock, hinges, closer
    rod(g, "Handle", (lw - 0.55, 3.0, -0.42), (lw - 0.55, 4.0, -0.42), 0.1, jitter(GALV, rng, 6, 0.1), "Metal",
        flags=DECOR)
    for yy in (3.05, 3.95):
        rod(g, "HandleMount", (lw - 0.55, yy, -0.22), (lw - 0.55, yy, -0.44), 0.08, METAL_DARK, "Metal", flags=DECOR)
    g.part("Lock", (lw - 0.55, 4.6, -0.25), (0.28, 0.42, 0.08), jitter(GALV, rng, 6), "Metal", flags=DECOR)
    n += 4
    for yy in (0.6, lh / 2, lh - 0.6):
        rod(g, "Hinge", (-0.06, yy - 0.3, -0.22), (-0.06, yy + 0.3, -0.22), 0.16, METAL_DARK, "Metal", flags=DECOR)
        n += 1
    g.part("Closer", (0.9, lh - 0.35, -0.33), (1.0, 0.28, 0.22), jitter(METAL, rng, 6), "Metal", flags=DECOR)
    beam(g, "CloserArm", (1.35, lh - 0.35, -0.42), (1.55, lh + 0.1, -0.3), 0.08, 0.06, METAL_DARK, "Metal",
         side=(0, 0, 1), flags=DECOR)
    n += 2
    g.part("Stencil", (lw / 2, lh * 0.62, -0.24), (lw * 0.85, 0.8, 0.05), (0, 0, 0), "SmoothPlastic", transparency=1,
           flags=DECOR, extra=sign_extra(stencil or rng.choice(["NO ENTRY", "FIRE EXIT · KEEP CLEAR", "PRIVATE",
                                                                  "DELIVERIES", "NO LOITERING"]),
                                         jitter((168, 160, 140), rng, 8), font="Oswald"))
    n += 1
    if variant == "chained":
        for i in range(4):
            a = (lw - 0.55 + 0.25 * i, 3.5 - 0.18 * i * (3 - i), -0.5)
            b = (lw - 0.3 + 0.25 * i, 3.5 - 0.18 * (i + 1) * (2 - i), -0.5)
            rod(g, "Chain", a, b, 0.08, jitter(GALV, rng, 4, 0.2), "Metal", flags=DECOR)
        g.part("Padlock", (lw + 0.3, 2.9, -0.5), (0.3, 0.4, 0.14), jitter((120, 100, 50), rng, 8), "Metal", flags=DECOR)
        f.box("Hasp", (w / 2 + 0.05, 3.3, -0.4), (w / 2 + 0.45, 3.7, -0.28), RUST_DARK, "CorrodedMetal", flags=DECOR)
        n += 6
    # rust bleeding from the frame foot, wall grime round the door (hands, shoulders)
    n += streak(f, rng, "RustStreak", w / 2 + 0.16, h + 0.3, rng.uniform(1.2, 2.4), 0.5, RUST_STAIN, k=0, taper=2)
    overlay(f, "Grime", -w / 2 - 1.0, w / 2 + 1.0, 0.45, rng.uniform(2.5, 3.6), DAMP, k=0, tr=0.7)
    n += 1
    if light:
        n += bulkhead_light(D, folder, f.world((rng.uniform(-0.3, 0.3), 0, 0)), ry_of(f), rng, y=h + 1.4,
                            dead=dead_light)
    return n


def ry_of(f):
    """The turn about Y of a frame (for passing a sub-frame on to another builder)."""
    return math.degrees(math.atan2(f.m[0, 2], f.m[2, 2]))


def roller_shutter(D, folder, origin, ry, rng, width=8.0, height=7.0, open_height=0.0, x=0.0, tag=True,
                   color=None):
    """A steel roller shutter (garage / shop back): coil housing with end plates, guide rails,
    a curtain of slats (dented, uneven shades), bottom bar with lift handle and ground lock
    padlock, rust and grime climbing up from the foot, often a tag. open_height > 0 leaves
    it jammed part-open on a dark gap. Footprint: (width + 0.8) x 1.2 deep x (height + 1.4).
    Parts: 24-30."""
    f = frame_at(D, folder, origin, ry).sub((x, 0, 0))
    w, h = width, height
    base = color or jitter(rng.choice([GALV, (84, 88, 86), (70, 76, 84), (96, 70, 56)]), rng, 6)
    n = 0
    f.box("Housing", (-w / 2 - 0.35, h, -1.15), (w / 2 + 0.35, h + 1.3, 0), jitter(base, rng, 4, 0.12), "Metal",
          flags=DECOR_SHADOW)
    for s in (-1, 1):
        f.box("EndPlate", (s * (w / 2 + 0.35) - 0.06, h - 0.05, -1.2), (s * (w / 2 + 0.35) + 0.06, h + 1.35, 0),
              METAL_DARK, "Metal", flags=DECOR)
        f.box("Guide", (s * (w / 2 + 0.05) - 0.25, 0, -0.45), (s * (w / 2 + 0.05) + 0.25, h, 0), jitter(METAL_DARK, rng, 4),
              "Metal", flags=DECOR)
        n += 2
    n += 1
    y0 = open_height
    if y0 > 0:
        f.box("Void", (-w / 2, 0, -0.05), (w / 2, y0, -0.02), VOID, "SmoothPlastic", flags=DECOR)
        n += 1
    slat = rng.uniform(0.62, 0.78)
    count = max(3, int((h - y0) / slat))
    slat = (h - y0) / count
    dent = rng.randrange(count)
    for i in range(count):
        a = y0 + i * slat
        c = jitter(base, rng, 3, 0.04 * (i % 2) + (0.18 if i < 2 else 0.0))
        rx = rng.uniform(4, 9) if i == dent else rng.uniform(-0.6, 0.6)
        zc = -0.28 if i % 2 else -0.24
        f.part("Slat", (rng.uniform(-0.02, 0.02), a + slat / 2, zc - (0.06 if i == dent else 0)), (w, slat * 0.96, 0.14),
               c, "Metal", rot=(rx, 0, rng.uniform(-0.25, 0.25)), flags=SOLID if i == 0 or i == count - 1 else SMALL)
        n += 1
    # bottom bar, handle, ground lock
    f.box("BottomBar", (-w / 2, y0, -0.42), (w / 2, y0 + 0.28, -0.12), jitter(METAL_DARK, rng, 4), "Metal", flags=DECOR)
    rod(f, "LiftHandle", (-0.5, y0 + 0.5, -0.5), (0.5, y0 + 0.5, -0.5), 0.1, GALV, "Metal", flags=DECOR)
    n += 2
    if y0 == 0:
        lx = rng.choice((-1, 1)) * w * 0.3
        f.part("GroundLock", (lx, 0.12, -0.55), (0.3, 0.24, 0.3), METAL_DARK, "Metal", flags=DECOR)
        f.part("Padlock", (lx, 0.36, -0.62), (0.26, 0.34, 0.12), jitter((120, 100, 50), rng, 8), "Metal", flags=DECOR)
        n += 2
    # wear: rust patches on the low slats, grime, streaks from the housing
    for _ in range(rng.randint(2, 3)):
        rx_ = rng.uniform(-w / 2 + 0.6, w / 2 - 0.6)
        overlay(f, "Rust", rx_ - rng.uniform(0.3, 0.9), rx_ + rng.uniform(0.3, 0.9), y0, y0 + rng.uniform(0.5, 1.6),
                jitter(RUST, rng, 8), k=11, tr=0.35, material="CorrodedMetal")
        n += 1
    f.box("FootGrime", (-w / 2, y0, -0.37), (w / 2, y0 + rng.uniform(1.0, 1.8), -0.35), WET_DARK, "SmoothPlastic",
          transparency=0.62, flags=DECOR)
    n += 1
    for _ in range(2):  # rust bleeding from the housing's screws down the curtain
        sx = rng.uniform(-w / 2 + 0.5, w / 2 - 0.5)
        sl = rng.uniform(1.2, 2.6)
        f.box("Streak", (sx - 0.12, h - sl, -0.38), (sx + 0.12, h, -0.36), RUST_STAIN, "SmoothPlastic",
              transparency=0.7, flags=DECOR)
        f.box("Streak", (sx - 0.06, h - sl * 0.6, -0.4), (sx + 0.06, h, -0.38), RUST_DARK, "SmoothPlastic",
              transparency=0.6, flags=DECOR)
        n += 2
    if tag:
        f.part("Graffiti", (rng.uniform(-w / 6, w / 6), y0 + (h - y0) * 0.55, -0.4), (w * 0.75, (h - y0) * 0.35, 0.05),
               (0, 0, 0), "SmoothPlastic", rot=(0, 0, rng.uniform(-5, 5)), transparency=1, flags=DECOR,
               extra=sign_extra(rng.choice(GRAFFITI_TAGS),
                                jitter(rng.choice([(180, 176, 160), (170, 60, 50), (30, 30, 30)]), rng, 10)))
        n += 1
    return n


# =================================================================================================
# 3. Structure: fire escape, building top, background facade, fence
# =================================================================================================


def fire_escape(D, folder, origin, ry, rng, width=12.0, floors=3, floor_h=10.0, depth=3.6, ladder=True):
    """A steel fire escape for a wall of `floors` floors: a grated landing at each upper floor
    (floor_h, 2*floor_h...), each on two diagonal brackets, with posts, top and mid rails and
    toe boards; a steep stair between landings (stringers, treads, handrail) through a hatch,
    alternating sides; a drop ladder hooked up under the first landing. Rust runs down the
    wall from every bracket. Landings and treads are SOLID (walkable).
    Footprint: width x depth, floors * floor_h tall. Parts: ~30-60 (3 floors ~55)."""
    f = frame_at(D, folder, origin, ry)
    n = 0
    steel = jitter(rng.choice([(40, 40, 40), (52, 44, 38), (46, 50, 48)]), rng, 4)
    rail_h = 3.0
    run = floor_h / math.tan(math.radians(58))
    sw = 2.0  # stair band (outer side of the landing)
    landings = list(range(1, floors))
    for li, k in enumerate(landings):
        y = k * floor_h
        hatch = None
        if li > 0:  # the flight from the landing below arrives here: hatch in the outer band
            d = 1 if (li - 1) % 2 == 0 else -1
            x_bot = d * (width / 2 - 0.6)
            x_top = x_bot - d * run
            hatch = (min(x_bot, x_top) - 0.2, max(x_bot, x_top) + 0.2)
        # deck: inner band full, outer band minus the hatch
        f.box("Landing", (-width / 2, y - 0.2, -(depth - sw)), (width / 2, y, -0.05), jitter(steel, rng, 3),
              "DiamondPlate", flags=SOLID)
        n += 1
        spans = [(-width / 2, width / 2)] if hatch is None else [(-width / 2, hatch[0]), (hatch[1], width / 2)]
        for a, b in spans:
            if b - a > 0.3:
                f.box("Landing", (a, y - 0.2, -depth), (b, y, -(depth - sw)), jitter(steel, rng, 3), "DiamondPlate",
                      flags=SOLID)
                n += 1
        f.box("Fascia", (-width / 2, y - 0.45, -depth - 0.08), (width / 2, y + 0.25, -depth), steel, "Metal",
              flags=DECOR)
        n += 1
        # brackets (diagonal struts under the deck)
        for bx in (-width / 2 + 0.6, width / 2 - 0.6):
            beam(f, "Bracket", (bx, y - 0.2, -depth + 0.3), (bx, y - 2.8, -0.1), 0.18, 0.18, steel, "Metal",
                 side=(1, 0, 0), flags=DECOR_SHADOW)
            n += 1
            n += streak(f, rng, "RustStreak", bx, y - 2.8, rng.uniform(2.5, 5), 0.5, RUST_STAIN, k=0, taper=2)
        # railing: posts, top rail, mid rail on the front and the two ends
        posts = [-width / 2, -width / 6, width / 6, width / 2]
        for px in posts:
            f.box("Post", (px - 0.08, y, -depth - 0.04), (px + 0.08, y + rail_h, -depth + 0.12), steel, "Metal",
                  flags=DECOR_SHADOW)
            n += 1
        for yy, nm in ((y + rail_h, "TopRail"), (y + rail_h * 0.5, "MidRail")):
            f.box(nm, (-width / 2, yy - 0.08, -depth - 0.06), (width / 2, yy + 0.08, -depth + 0.1), steel, "Metal",
                  flags=PROP if nm == "TopRail" else DECOR_SHADOW)
            n += 1
        for s in (-1, 1):
            f.box("EndRail", (s * width / 2 - 0.08, y + rail_h - 0.08, -depth), (s * width / 2 + 0.08, y + rail_h + 0.08, -0.05),
                  steel, "Metal", flags=PROP)
            n += 1
        # junk left on the landing: a plant pot / a crate (people use these as balconies)
        if rng.random() < 0.6:
            jx = rng.uniform(-width / 2 + 1, width / 2 - 1)
            if hatch is None or not (hatch[0] - 0.5 < jx < hatch[1] + 0.5):
                f.part("Crate", (jx, y + 0.5, -0.8), (1.2, 1.0, 1.0), jitter(WOOD_OLD, rng, 8), "WoodPlanks",
                       rot=(0, rng.uniform(-15, 15), 0), flags=SMALL)
                n += 1
    # flights between landings
    for li in range(len(landings) - 1):
        y0 = landings[li] * floor_h
        d = 1 if li % 2 == 0 else -1
        x_bot = d * (width / 2 - 0.6)
        x_top = x_bot - d * run
        for zs in (-depth + 0.15, -depth + sw - 0.15):
            beam(f, "Stringer", (x_bot, y0 - 0.1, zs), (x_top, y0 + floor_h - 0.1, zs), 0.3, 0.12, steel, "Metal",
                 side=(0, 0, 1), flags=DECOR_SHADOW)
            n += 1
        steps = 7
        for i in range(1, steps):
            t = i / steps
            tx = x_bot + (x_top - x_bot) * t
            f.box("Tread", (tx - 0.45, y0 + floor_h * t - 0.1, -depth + 0.2), (tx + 0.45, y0 + floor_h * t, -depth + sw - 0.2),
                  jitter(steel, rng, 3), "DiamondPlate", flags=SOLID)
            n += 1
        beam(f, "Handrail", (x_bot, y0 + rail_h, -depth + 0.05), (x_top, y0 + floor_h + rail_h, -depth + 0.05), 0.12,
             0.12, steel, "Metal", side=(0, 0, 1), flags=DECOR)
        n += 1
    # drop ladder, hooked up under the first landing
    if ladder and landings:
        y = landings[0] * floor_h
        lx = -(width / 2 - 0.6) if len(landings) > 1 else 0.0
        lx = lx + rng.uniform(-0.3, 0.3)
        lo, hi = y - 6.5, y + rail_h - 0.2
        for s in (-1, 1):
            f.box("LadderRail", (lx + s * 0.75 - 0.07, lo, -depth - 0.3), (lx + s * 0.75 + 0.07, hi, -depth - 0.16), steel,
                  "Metal", flags=DECOR_SHADOW)
            n += 1
        for i in range(int((hi - lo) / 1.0)):
            rod(f, "Rung", (lx - 0.75, lo + 0.5 + i, -depth - 0.23), (lx + 0.75, lo + 0.5 + i, -depth - 0.23), 0.08,
                steel, "Metal", flags=DECOR)
            n += 1
    return n


def building_top(D, folder, origin, ry, rng, width=16.0, top=30.0, depth=4.0, clutter="tank"):
    """The top of a wall seen from the alley: a cornice (string course + a row of corbels)
    with black run-off below it, a parapet, broken coping stones (one missing, others
    shifted), weeds, and rooftop clutter set back: clutter = "tank" (wooden water tank on a
    steel stand), "antenna" (mast + bars + guy wires), "vents" (stacks and a box vent) or None.
    origin: wall face at floor level; the wall is `top` tall and `depth` thick (behind).
    Footprint: width x (depth + ~8) on the roof. Parts: 20-58."""
    f = frame_at(D, folder, origin, ry)
    n = 0
    stone = jitter(STONE, rng, 6, 0.1)
    brick = jitter(rng.choice(BRICK), rng, 6)
    cy = top - 1.6
    f.box("Cornice", (-width / 2, cy, -0.55), (width / 2, cy + 0.5, depth), stone, "Limestone", flags=DECOR)
    f.box("Cornice", (-width / 2, cy - 0.3, -0.3), (width / 2, cy, depth), jitter(stone, rng, 4, 0.1), "Limestone",
          flags=DECOR)
    n += 2
    corbels = int(width / 1.4)
    for i in range(corbels):
        cx = -width / 2 + (i + 0.5) * width / corbels
        if rng.random() < 0.12:  # one fallen off
            continue
        f.box("Corbel", (cx - 0.22, cy - 0.85, -0.3), (cx + 0.22, cy - 0.3, 0), jitter(stone, rng, 5, 0.12), "Limestone",
              flags=DECOR)
        n += 1
    # black run-off down the face under the cornice
    for _ in range(rng.randint(3, 5)):
        n += streak(f, rng, "RunOff", rng.uniform(-width / 2 + 0.5, width / 2 - 0.5), cy - 0.3, rng.uniform(3, 9),
                    rng.uniform(0.6, 1.4), SOOT, k=0, tr=0.55, taper=2)
    # parapet and coping
    f.box("Parapet", (-width / 2, top, 0), (width / 2, top + 2.2, 1.0), brick, "Brick", flags=SOLID)
    n += 1
    x = -width / 2
    while x < width / 2 - 0.2:
        ln = min(rng.uniform(1.8, 2.8), width / 2 - x)
        if rng.random() > 0.1:
            f.part("Coping", (x + ln / 2, top + 2.35 + rng.uniform(-0.04, 0.06), 0.5 + rng.uniform(-0.08, 0.08)),
                   (ln - 0.06, 0.3, 1.45), jitter(STONE, rng, 2, rng.uniform(0.05, 0.3)), "Concrete",
                   rot=(rng.uniform(-1.5, 1.5), rng.uniform(-1.5, 1.5), rng.uniform(-1.2, 1.2)), flags=SOLID)
            n += 1
        x += ln
    for _ in range(rng.randint(1, 3)):  # weeds in the joints
        wx = rng.uniform(-width / 2, width / 2)
        f.part("Weed", (wx, top + 2.6, 0.3), (rng.uniform(0.4, 0.8), rng.uniform(0.3, 0.6), 0.4),
               jitter(MOSS, rng, 10), "Grass", rot=(0, rng.uniform(0, 90), rng.uniform(-20, 20)), flags=DECOR)
        n += 1
    # rooftop clutter (behind the parapet, sits on the roof at y = top)
    z0 = depth + rng.uniform(3, 5)
    cx = rng.uniform(-width / 4, width / 4)
    if clutter == "tank":
        r, th, legs = rng.uniform(2.2, 2.8), rng.uniform(5, 6.5), rng.uniform(4, 6)
        for sx in (-1, 1):
            for sz in (-1, 1):
                f.box("TankLeg", (cx + sx * r * 0.7 - 0.15, top, z0 + sz * r * 0.7 - 0.15),
                      (cx + sx * r * 0.7 + 0.15, top + legs, z0 + sz * r * 0.7 + 0.15), METAL_DARK, "Metal", flags=SOLID)
                n += 1
        for sz in (-1, 1):
            beam(f, "Brace", (cx - r * 0.7, top + 0.3, z0 + sz * r * 0.7), (cx + r * 0.7, top + legs - 0.3, z0 + sz * r * 0.7),
                 0.1, 0.1, METAL_DARK, "Metal", side=(0, 0, 1), flags=DECOR)
            n += 1
        f.box("TankBase", (cx - r, top + legs, z0 - r), (cx + r, top + legs + 0.3, z0 + r), METAL_DARK, "Metal",
              flags=SOLID)
        f.part("Tank", (cx, top + legs + 0.3 + th / 2, z0), (th, 2 * r, 2 * r), jitter(WOOD_OLD, rng, 8, 0.15),
               "WoodPlanks", rot=(0, 0, 90), shape=CYLINDER, flags=SOLID)
        n += 2
        for i in range(3):
            hy = top + legs + 0.3 + th * (0.2 + 0.3 * i)
            f.part("Hoop", (cx, hy, z0), (0.14, 2 * r + 0.08, 2 * r + 0.08), RUST_DARK, "CorrodedMetal", rot=(0, 0, 90),
                   shape=CYLINDER, flags=DECOR)
            n += 1
        f.part("TankRoof", (cx, top + legs + 0.3 + th + 0.35, z0), (0.7, 2 * r + 0.3, 2 * r + 0.3), WOOD_DARK, "Wood",
               rot=(0, 0, 90), shape=CYLINDER, flags=DECOR)
        f.part("TankRoof", (cx, top + legs + 0.3 + th + 0.9, z0), (0.6, r * 1.1, r * 1.1), WOOD_DARK, "Wood",
               rot=(0, 0, 90), shape=CYLINDER, flags=DECOR)
        n += 2
    elif clutter == "antenna":
        mh = rng.uniform(8, 13)
        rod(f, "Mast", (cx, top, z0), (cx, top + mh, z0), 0.25, GALV, "Metal", flags=DECOR_SHADOW)
        n += 1
        for i in range(3):
            yy = top + mh * (0.6 + 0.15 * i)
            hw = 1.6 - 0.4 * i
            rod(f, "Element", (cx - hw, yy, z0), (cx + hw, yy + rng.uniform(-0.1, 0.1), z0), 0.1, GALV, "Metal",
                flags=DECOR)
            n += 1
        for gx, gz in ((-3, -2), (3, -2), (0, 3)):
            rod(f, "Guy", (cx, top + mh * 0.7, z0), (cx + gx, top, z0 + gz), 0.05, CABLE, "Metal", flags=DECOR)
            n += 1
    elif clutter == "vents":
        for i in range(rng.randint(2, 3)):
            vx = cx + rng.uniform(-4, 4)
            vz = z0 + rng.uniform(-1, 2)
            vh = rng.uniform(2, 4.5)
            rod(f, "Stack", (vx, top, vz), (vx, top + vh, vz), rng.uniform(0.6, 1.0), jitter(GALV, rng, 6, 0.25),
                "Metal", flags=SOLID)
            f.part("Cap", (vx, top + vh + 0.25, vz), (0.3, 1.3, 1.3), METAL_DARK, "Metal", rot=(0, 0, 90),
                   shape=CYLINDER, flags=DECOR)
            n += 2
        f.box("BoxVent", (cx - 2, top, z0 + 2), (cx + 1, top + 2.2, z0 + 4), jitter(GALV, rng, 6, 0.2), "Metal",
              flags=SOLID)
        n += 1
    return n


def background_facade(D, folder, origin, ry, rng, width=40.0, height=60.0, depth=12.0, floor_h=10.0, style=None,
                      lit_share=0.25, ground_floor=True):
    """A tall building BEYOND the alley walls (for depth, seen above the near roofs): a solid
    mass with rows of recessed windows (glass bands behind brick piers and stone sill
    lines), a few lit (warm / cold / TV; tagged CityWindowLit, some Day = always on at
    night), a shuttered ground floor, a cornice, a water tank silhouette and a mast.
    Cheap: windows are bands, not one part each. origin: floor point at the middle of the
    facade's foot; the mass extends `depth` behind. Footprint: width x depth x height.
    Parts: 25-60."""
    f = frame_at(D, folder, origin, ry)
    n = 0
    style = style or rng.choice(["brick", "concrete", "render"])
    mass_c = {"brick": jitter(rng.choice(BRICK), rng, 6, 0.15), "concrete": jitter(CONCRETE, rng, 6, 0.2),
              "render": jitter((104, 98, 86), rng, 6, 0.15)}[style]
    mat = {"brick": "Brick", "concrete": "Concrete", "render": "Concrete"}[style]
    f.box("Mass", (-width / 2, 0, 0), (width / 2, height, depth), mass_c, mat, flags=SOLID)
    n += 1
    floors = int(height / floor_h)
    cols = max(2, int(width / 5.5))
    bay = width / cols
    win_w = bay * rng.uniform(0.45, 0.55)
    first = 1 if ground_floor else 0
    for k in range(first, floors):
        y0 = k * floor_h + floor_h * 0.3
        y1 = y0 + floor_h * 0.5
        f.box("Glass", (-width / 2 + 0.3, y0, -0.12), (width / 2 - 0.3, y1, -0.02),
              jitter((26, 28, 30), rng, 3), "Glass", flags=DECOR, reflectance=0.08)
        f.box("SillLine", (-width / 2, y0 - 0.35, -0.75), (width / 2, y0, 0), jitter(STONE, rng, 4, 0.15), "Concrete",
              flags=DECOR)
        n += 2
    # piers between the windows (full height, in front of the glass bands)
    pier_w = bay - win_w
    for i in range(cols + 1):
        px = -width / 2 + i * bay
        a, b = max(-width / 2, px - pier_w / 2), min(width / 2, px + pier_w / 2)
        f.box("Pier", (a, floor_h * first, -0.5), (b, height, 0), jitter(mass_c, rng, 3), mat, flags=DECOR)
        n += 1
    # lit windows (each a pane in front of its band)
    budget = min(14, int((floors - first) * cols * lit_share))
    cells = [(k, i) for k in range(first, floors) for i in range(cols)]
    rng.shuffle(cells)
    for k, i in cells[:budget]:
        y0 = k * floor_h + floor_h * 0.3
        cx = -width / 2 + (i + 0.5) * bay
        kind = rng.choice(["warm", "warm", "warm", "cold", "tv"])
        col = {"warm": WARM_DIM, "cold": COLD_DIM, "tv": TV_DIM}[kind]
        day = rng.random() < 0.5
        f.box("Window", (cx - win_w / 2 + 0.1, y0 + 0.1, -0.17), (cx + win_w / 2 - 0.1, y0 + floor_h * 0.5 - 0.1, -0.13),
              jitter(col, rng, 10, rng.uniform(0, 0.35)) if day else (30, 32, 34), "Neon" if day else "Glass",
              flags=DECOR, extra={"t": ["CityWindowLit"], "a": {"Kind": kind, "Day": day}})
        n += 1
        if rng.random() < 0.4:  # blind / curtain half down
            f.box("Blind", (cx - win_w / 2 + 0.1, y0 + floor_h * 0.5 * rng.uniform(0.5, 0.8), -0.2),
                  (cx + win_w / 2 - 0.1, y0 + floor_h * 0.5 - 0.1, -0.18), jitter((70, 62, 50), rng, 8), "Fabric",
                  flags=DECOR)
            n += 1
    # AC boxes stuck under some windows
    for k, i in cells[budget:budget + rng.randint(2, 5)]:
        cx = -width / 2 + (i + 0.5) * bay + rng.uniform(-1, 1)
        y0 = k * floor_h + floor_h * 0.3 - 1.6
        f.box("AC", (cx - 0.9, y0, -1.3), (cx + 0.9, y0 + 1.2, -0.75), jitter(BEIGE, rng, 8, 0.2), "Metal", flags=DECOR)
        n += 1
    if ground_floor:
        f.box("ShopShutters", (-width / 2 + 0.4, 0, -0.3), (width / 2 - 0.4, floor_h * 0.6, -0.05),
              jitter((60, 62, 62), rng, 4), "Metal", flags=SOLID)
        f.box("Fascia", (-width / 2, floor_h * 0.6, -0.6), (width / 2, floor_h * 0.75, 0), jitter((40, 40, 42), rng, 4),
              "Metal", flags=DECOR)
        n += 2
    # cornice, run-off, roof clutter
    f.box("Cornice", (-width / 2 - 0.3, height - 1.2, -1.0), (width / 2 + 0.3, height - 0.4, depth), jitter(STONE, rng, 4, 0.2),
          "Concrete", flags=DECOR)
    f.box("Parapet", (-width / 2, height, 0), (width / 2, height + 1.5, depth), jitter(mass_c, rng, 4, 0.1), mat,
          flags=DECOR)
    n += 2
    for _ in range(rng.randint(2, 4)):
        sx = rng.uniform(-width / 2, width / 2)
        overlay(f, "RunOff", sx - 0.8, sx + 0.8, height - rng.uniform(10, 25), height - 1.2, SOOT, k=10, tr=0.6)
        n += 1
    tx, tz = rng.uniform(-width / 3, width / 3), depth * 0.5
    for sx in (-1.4, 1.4):
        f.box("TankLeg", (tx + sx - 0.15, height, tz - 0.15), (tx + sx + 0.15, height + 4, tz + 0.15), METAL_DARK, "Metal",
              flags=DECOR)
    f.part("Tank", (tx, height + 6.5, tz), (5, 4.4, 4.4), jitter(WOOD_DARK, rng, 6), "WoodPlanks", rot=(0, 0, 90),
           shape=CYLINDER, flags=DECOR)
    f.part("TankRoof", (tx, height + 9.3, tz), (0.6, 2.6, 2.6), WOOD_DARK, "Wood", rot=(0, 0, 90), shape=CYLINDER,
           flags=DECOR)
    mx = rng.uniform(-width / 2 + 2, width / 2 - 2)
    rod(f, "Mast", (mx, height, depth * 0.7), (mx, height + rng.uniform(8, 14), depth * 0.7), 0.3, METAL_DARK, "Metal",
        flags=DECOR)
    return n + 5


def chainlink_fence(D, folder, origin, ry, rng, width=10.0, height=8.0, barbed=True, torn=True):
    """A free-standing chain-link fence along local X (origin = floor point at its middle):
    galvanised posts, a top rail, mesh panels (translucent, each sagging a little), a torn
    corner peeled back, barbed-wire arms leaning out (-Z side) with three strands, and
    rubbish caught at its foot. Mesh is SOLID (blocks players).
    Footprint: width x 0.3 (x ~1.6 with the arms), height (+1.4). Parts: 10-28."""
    f = frame_at(D, folder, origin, ry)
    n = 0
    galv = jitter(GALV, rng, 6, 0.15)
    posts = max(2, int(width / 5) + 1)
    xs = [-width / 2 + i * width / (posts - 1) for i in range(posts)]
    torn_i = rng.randrange(posts - 1) if torn else -1
    for i, px in enumerate(xs):
        rod(f, "Post", (px, 0, 0), (px + rng.uniform(-0.05, 0.05), height + 0.2, rng.uniform(-0.06, 0.06)), 0.28, galv,
            "Metal", flags=SOLID)
        n += 1
        if barbed:
            beam(f, "BarbArm", (px, height + 0.1, 0), (px, height + 1.4, -1.1), 0.1, 0.1, galv, "Metal", side=(1, 0, 0),
                 flags=DECOR)
            n += 1
    rod(f, "TopRail", (-width / 2, height - 0.1, 0), (width / 2, height - 0.1, 0), 0.18, galv, "Metal", flags=DECOR)
    n += 1
    for i in range(posts - 1):
        a, b = xs[i], xs[i + 1]
        lo = 0.05
        if i == torn_i:
            lo = rng.uniform(1.4, 2.2)
            # the peeled corner: a flap bent out
            fw = (b - a) * rng.uniform(0.4, 0.6)
            g = f.sub((a + 0.15, lo / 2, 0), rx=-rng.uniform(25, 45))
            g.box("MeshFlap", (0, -lo / 2, -0.03), (fw, lo / 2, 0.03), galv, "Metal", transparency=0.72, flags=DECOR)
            n += 1
        f.part("Mesh", ((a + b) / 2, (lo + height - 0.1) / 2, rng.uniform(-0.08, 0.08)),
               (b - a - 0.2, height - 0.1 - lo, 0.06), galv, "Metal", rot=(rng.uniform(-2.5, 2.5), 0, 0),
               transparency=0.72, flags=SOLID)
        n += 1
        if i == torn_i:  # (still blocks: an invisible wall where the mesh is gone, too low to crawl)
            pass
    if barbed:
        for j in range(3):
            t = (j + 1) / 3.2
            rod(f, "Barbed", (-width / 2, height + 0.1 + 1.3 * t, -1.1 * t), (width / 2, height + 0.1 + 1.3 * t - rng.uniform(0, 0.15),
                                                                         -1.1 * t), 0.06, jitter(GALV, rng, 4, 0.35),
                "Metal", flags=DECOR)
            n += 1
        # barbs: small twisted bits along the strands
        for _ in range(rng.randint(3, 6)):
            t = rng.randint(1, 3) / 3.2
            bx = rng.uniform(-width / 2, width / 2)
            f.part("Barb", (bx, height + 0.1 + 1.3 * t, -1.1 * t), (0.3, 0.05, 0.05), GALV, "Metal",
                   rot=(rng.uniform(0, 180), rng.uniform(0, 180), rng.uniform(30, 60)), flags=DECOR)
            n += 1
    # snagged rubbish: a plastic sheet in the mesh, paper at the foot, a dark rag on the wire
    f.part("Snag", (rng.uniform(-width / 3, width / 3), rng.uniform(1.5, 4), -0.12), (rng.uniform(0.8, 1.4), rng.uniform(0.6, 1.0), 0.04),
           jitter((150, 150, 140), rng, 10), "SmoothPlastic", rot=(rng.uniform(-10, 10), 0, rng.uniform(-30, 30)),
           transparency=0.35, flags=DECOR)
    f.part("Rag", (rng.uniform(-width / 2, width / 2), height + 1.0, -0.6), (0.6, 0.9, 0.06), jitter((40, 36, 34), rng, 6),
           "Fabric", rot=(rng.uniform(-20, 20), 0, rng.uniform(-30, 30)), flags=DECOR)
    for _ in range(rng.randint(1, 3)):
        f.part("Paper", (rng.uniform(-width / 2, width / 2), 0.08, rng.uniform(-0.4, 0.4)), (rng.uniform(0.5, 0.9), 0.12, 0.6),
               jitter(rng.choice(PAPER), rng, 10, 0.2), "SmoothPlastic",
               rot=(rng.uniform(-60, 60), rng.uniform(0, 180), rng.uniform(-20, 20)), flags=DECOR)
        n += 1
    return n + 2


# =================================================================================================
# 4. Services: AC, meters, cables, pipes, downpipes, vents, dish
# =================================================================================================


def ac_unit(D, folder, origin, ry, rng, y=9.0, x=0.0, scale=1.0):
    """A wall-hung air-con condenser: yellowed casing with a round fan grille (dark,
    two crossed guards), side louvres, on two steel angle brackets with diagonal struts,
    a condensate pipe dribbling down the wall (dark wet streak), rust round the screws and
    soot above the outlet. Footprint: 3 x 1.4 (x scale), 2.2 tall. Parts: 21."""
    f = frame_at(D, folder, origin, ry).sub((x, y, 0))
    s = scale
    W, H, Dp = 3.0 * s, 2.2 * s, 1.3 * s
    case = jitter(rng.choice([BEIGE, (130, 128, 118), (110, 112, 106)]), rng, 8, 0.1)
    n = 0
    f.box("Casing", (-W / 2, 0, -Dp - 0.25), (W / 2, H, -0.25), case, "Metal", flags=SMALL)
    f.box("CasingTop", (-W / 2 - 0.04, H - 0.06, -Dp - 0.29), (W / 2 + 0.04, H + 0.06, -0.21), jitter(case, rng, 4, 0.12),
          "Metal", flags=DECOR)
    n += 2
    gx = -W * 0.17
    f.part("FanHole", (gx, H / 2, -Dp - 0.26), (0.06, H * 0.78, H * 0.78), (16, 16, 18), "Metal", rot=(0, 90, 0),
           shape=CYLINDER, flags=DECOR)
    f.part("FanRing", (gx, H / 2, -Dp - 0.28), (0.04, H * 0.84, H * 0.84), jitter(case, rng, 4, 0.25), "Metal", rot=(0, 90, 0),
           shape=CYLINDER, flags=DECOR, transparency=0.55)
    n += 2
    for a in (45, -45):
        f.part("Guard", (gx, H / 2, -Dp - 0.32), (H * 0.78, 0.06, 0.04), (90, 90, 86), "Metal", rot=(0, 0, a), flags=DECOR)
        n += 1
    for i in range(4):
        yy = H * (0.2 + 0.18 * i)
        f.part("Louvre", (W * 0.3, yy, -Dp - 0.28), (W * 0.3, 0.08, 0.1), jitter(case, rng, 4, 0.3), "Metal",
               rot=(-30, 0, 0), flags=DECOR)
        n += 1
    for bx in (-W / 2 + 0.3, W / 2 - 0.3):
        f.box("Bracket", (bx - 0.08, -0.15, -Dp - 0.35), (bx + 0.08, 0.0, 0), jitter(RUST_DARK, rng, 4), "CorrodedMetal",
              flags=DECOR)
        beam(f, "Strut", (bx, -0.1, -Dp * 0.85), (bx, -1.3, -0.05), 0.12, 0.12, RUST_DARK, "CorrodedMetal", side=(1, 0, 0),
             flags=DECOR)
        n += 2
    # condensate pipe and its wet trail, rust from the bracket screws, soot above
    px = W / 2 - 0.5
    rod(f, "DrainPipe", (px, 0, -0.5), (px + 0.1, -1.0, -0.15), 0.12, (40, 40, 40), "Rubber", flags=DECOR)
    n += 1
    n += streak(f, rng, "WetTrail", px + 0.1, -1.0, rng.uniform(3, 7), 0.5, WET_DARK, k=0, tr=0.5, taper=3)
    for bx in (-W / 2 + 0.3, W / 2 - 0.3):
        overlay(f, "Rust", bx - 0.15, bx + 0.15, -rng.uniform(1.2, 2.6), -1.3, RUST_STAIN, k=0, tr=0.5)
        n += 1
    overlay(f, "Soot", -W / 2 - 0.3, W / 2 + 0.3, H, H + rng.uniform(0.8, 1.6), SOOT, k=0, tr=0.82)
    return n + 1


def meter_box(D, folder, origin, ry, rng, y=3.2, x=0.0, conduits=2):
    """Electrical meter / junction cabinet: steel box with a door (seam, hinges, hasp and
    padlock), a yellow warning label, a vent slot, conduits leaving the top (with straps)
    and one into the ground, a loose cable looping out, rust dribbling from the bottom.
    Footprint: 2.4 x 0.8, ~3 tall (+ conduits up to y + 8). Parts: 16-22."""
    f = frame_at(D, folder, origin, ry).sub((x, 0, 0))
    W, H = rng.uniform(2.0, 2.6), rng.uniform(2.6, 3.2)
    body = jitter(rng.choice([(78, 86, 78), (92, 92, 86), (60, 64, 66)]), rng, 6)
    n = 0
    f.box("Cabinet", (-W / 2, y, -0.75), (W / 2, y + H, 0), body, "Metal", flags=SMALL)
    f.box("Door", (-W / 2 + 0.08, y + 0.08, -0.8), (W / 2 - 0.08, y + H - 0.08, -0.75), jitter(body, rng, 4, 0.06), "Metal",
          flags=DECOR)
    f.box("Roof", (-W / 2 - 0.1, y + H, -0.85), (W / 2 + 0.1, y + H + 0.12, 0), jitter(body, rng, 4, 0.15), "Metal",
          flags=DECOR)
    n += 3
    for yy in (y + 0.5, y + H - 0.5):
        f.box("Hinge", (-W / 2 - 0.02, yy - 0.18, -0.85), (-W / 2 + 0.1, yy + 0.18, -0.75), METAL_DARK, "Metal", flags=DECOR)
        n += 1
    f.box("Hasp", (W / 2 - 0.3, y + H / 2 - 0.15, -0.88), (W / 2 - 0.1, y + H / 2 + 0.15, -0.8), METAL_DARK, "Metal",
          flags=DECOR)
    f.part("Padlock", (W / 2 - 0.2, y + H / 2 - 0.3, -0.92), (0.22, 0.3, 0.1), jitter((120, 100, 50), rng, 8), "Metal",
           flags=DECOR)
    f.part("Label", (0, y + H * 0.72, -0.81), (W * 0.5, 0.45, 0.03), jitter((170, 150, 40), rng, 8, 0.15),
           "SmoothPlastic", flags=DECOR, extra=sign_extra("DANGER · 415V", (30, 28, 24), font="Oswald"))
    f.box("VentSlot", (-W / 4, y + 0.35, -0.81), (W / 4, y + 0.5, -0.79), (20, 20, 20), "Metal", flags=DECOR)
    n += 4
    for i in range(conduits):
        cx = -W / 4 + i * W / 2 / max(1, conduits - 1) if conduits > 1 else 0
        top = y + H + rng.uniform(4, 8)
        rod(f, "Conduit", (cx, y + H, -0.3), (cx, top, -0.3), 0.26, jitter((70, 72, 70), rng, 6), "Metal", flags=DECOR)
        f.box("Strap", (cx - 0.22, y + H + 1.6, -0.48), (cx + 0.22, y + H + 1.75, 0), METAL_DARK, "Metal", flags=DECOR)
        n += 2
    rod(f, "Conduit", (W / 4, y, -0.3), (W / 4, 0, -0.3), 0.3, jitter((70, 72, 70), rng, 6), "Metal", flags=DECOR)
    n += 1
    # a loose cable looping out of the side (sagging, two segments)
    drop = rng.uniform(0.6, 1.4)
    pts = [(W / 2, y + H * 0.7, -0.4), (W / 2 + 0.35, y + H * 0.7 - drop, -0.55), (W / 2 + 0.75, y + H * 0.7 - drop * 0.8, -0.5),
           (W / 2 + 0.95, y + H * 0.7, -0.35), (W / 2 + 1.0, y + H + 2.0, -0.2)]
    for a, b in zip(pts, pts[1:]):
        rod(f, "LooseCable", a, b, 0.08, CABLE, "Rubber", flags=DECOR)
        n += 1
    n += streak(f, rng, "RustStreak", rng.uniform(-W / 3, W / 3), y, rng.uniform(1, y - 0.2), 0.5, RUST_STAIN, k=0,
                taper=2)
    return n


def cable_sag(D, folder, origin, ry, rng, span=14.0, y=14.0, y_end=None, cables=3, sag=None, segments=8, shoes=None):
    """A bundle of cables sagging across between two walls (catenary): origin = foot of wall
    A's face, the cables run along local -Z to wall B's face `span` studs away, from height y
    to y_end; each cable sags differently (parabola, `segments` cylinders), with wall clamps
    at both ends. shoes=True (or by chance) adds a pair of trainers tossed over a cable.
    Footprint: 1 x span. Parts: cables*segments + 4 (+5 shoes): 3 cables ~28-33."""
    f = frame_at(D, folder, origin, ry)
    y_end = y if y_end is None else y_end
    n = 0
    sags = []
    for c in range(cables):
        xo = (c - (cables - 1) / 2) * 0.35 + rng.uniform(-0.05, 0.05)
        a_y = y + rng.uniform(-0.3, 0.3)
        b_y = y_end + rng.uniform(-0.3, 0.3)
        s = (sag if sag is not None else span * 0.1) * rng.uniform(0.7, 1.4)
        d = rng.uniform(0.1, 0.2)
        pts = []
        for i in range(segments + 1):
            t = i / segments
            pts.append((xo + rng.uniform(-0.03, 0.03) * (0 < i < segments), a_y + (b_y - a_y) * t - 4 * s * t * (1 - t),
                        -0.15 - (span - 0.3) * t))
        for i in range(segments):
            rod(f, "Cable", pts[i], pts[i + 1], d, jitter(CABLE, rng, 4), "Rubber", flags=DECOR)
            n += 1
        sags.append(pts)
    for z, yy in ((-0.1, y), (-span + 0.1, y_end)):
        f.part("Clamp", (0, yy, z), (cables * 0.35 + 0.3, 0.35, 0.3), METAL_DARK, "Metal", flags=DECOR)
        f.part("Insulator", (0, yy - 0.3, z - 0.1 if z > -1 else z + 0.1), (0.25, 0.4, 0.25), (110, 100, 80), "Plastic",
               flags=DECOR)
        n += 2
    if shoes if shoes is not None else rng.random() < 0.35:
        pts = sags[rng.randrange(len(sags))]
        p = pts[segments // 2 + rng.randint(-1, 1)]
        g = f.sub(p)
        upper = jitter((150, 146, 136), rng, 6, rng.uniform(0.1, 0.35))  # once white, now grey with grime
        for s_ in (-1, 1):
            h = g.sub((0.05 * s_, -1.1 - 0.15 * (s_ > 0), 0.3 * s_), rx=rng.uniform(60, 85) * s_, rz=rng.uniform(-10, 10))
            h.part("Trainer", (0, 0.04, 0), (0.4, 0.4, 1.0), upper, "Fabric", flags=DECOR)
            h.part("Sole", (0, -0.2, 0.02), (0.42, 0.12, 1.08), (40, 38, 36), "Rubber", flags=DECOR)
            n += 2
        rod(g, "Laces", (0, 0, 0), (0, -0.7, 0.05), 0.04, (150, 150, 140), "Fabric", flags=DECOR)
        n += 1
    return n


def pipe_run(D, folder, origin, ry, rng, length=10.0, y=6.0, x=0.0, diameter=0.6, drop="down", valve=None,
             color=None):
    """A service pipe along the wall at height y, from x - length/2 to x + length/2: two or
    three lengths joined by flanges, U-clamps on wall plates, a slight sag between clamps,
    rust weeping from every joint; drop = "down" turns it down (elbow) into the ground,
    "up" up the wall, None ends in a cap. valve adds a hand wheel. Pipes low enough to bump
    are SMALL. Footprint: length x (diameter + 0.4). Parts: 10-22."""
    f = frame_at(D, folder, origin, ry).sub((x, 0, 0))
    pc = color or jitter(rng.choice([RUST, METAL, (70, 70, 64), (96, 90, 60)]), rng, 6)
    mat = "CorrodedMetal" if pc[0] > pc[2] + 15 else "Metal"
    zc = -(diameter / 2 + 0.2)
    flags = SMALL if y < 6 else DECOR_SHADOW
    n = 0
    pieces = rng.randint(2, 3)
    xs = [-length / 2 + length * i / pieces for i in range(pieces + 1)]
    sagy = [0.0] + [rng.uniform(-0.12, 0.02) for _ in range(pieces - 1)] + [0.0]
    for i in range(pieces):
        rod(f, "Pipe", (xs[i], y + sagy[i], zc), (xs[i + 1], y + sagy[i + 1], zc), diameter, jitter(pc, rng, 4), mat,
            flags=flags)
        n += 1
        if 0 < i:
            rod(f, "Flange", (xs[i] - 0.08, y + sagy[i], zc), (xs[i] + 0.08, y + sagy[i], zc), diameter + 0.3,
                jitter(pc, rng, 4, 0.15), mat, flags=DECOR)
            n += 1 + streak(f, rng, "RustStreak", xs[i], y - diameter / 2, rng.uniform(1.5, 4), 0.4, RUST_STAIN, k=0,
                            taper=2)
    clamps = max(2, int(length / 3.5))
    for i in range(clamps):
        cx = -length / 2 + (i + 0.5) * length / clamps
        f.box("WallPlate", (cx - 0.2, y - diameter / 2 - 0.25, -0.08), (cx + 0.2, y + diameter / 2 + 0.25, 0), METAL_DARK,
              "Metal", flags=DECOR)
        f.box("Clamp", (cx - 0.08, y - diameter / 2 - 0.08, zc - diameter / 2 - 0.06), (cx + 0.08, y + diameter / 2 + 0.08, -0.08),
              METAL_DARK, "Metal", flags=DECOR)
        n += 2
    end = length / 2
    if drop in ("down", "up"):
        f.part("Elbow", (end, y, zc), (diameter + 0.12, diameter + 0.12, diameter + 0.12), jitter(pc, rng, 4, 0.1), mat,
               shape=BALL, flags=DECOR)
        y1 = 0.0 if drop == "down" else y + rng.uniform(5, 10)
        rod(f, "Pipe", (end, y, zc), (end, y1, zc), diameter, jitter(pc, rng, 4), mat, flags=SMALL)
        n += 2
        if drop == "down":
            f.part("GroundCollar", (end, 0.1, zc), (0.2, diameter + 0.4, diameter + 0.4), CONCRETE_DARK, "Concrete",
                   rot=(0, 0, 90), shape=CYLINDER, flags=DECOR)
            n += 1
    else:
        f.part("Cap", (end + 0.05, y, zc), (0.2, diameter + 0.1, diameter + 0.1), jitter(pc, rng, 4, 0.15), mat,
               shape=CYLINDER, flags=DECOR)
        n += 1
    if valve if valve is not None else rng.random() < 0.4:
        vx = rng.uniform(-length / 3, length / 3)
        rod(f, "Stem", (vx, y, zc), (vx, y + diameter / 2 + 0.6, zc), 0.12, METAL_DARK, "Metal", flags=DECOR)
        f.part("Wheel", (vx, y + diameter / 2 + 0.62, zc), (0.08, 1.0, 1.0), jitter((110, 40, 34), rng, 8), "Metal",
               rot=(0, 0, 90), shape=CYLINDER, flags=DECOR)
        n += 2
    return n


def downpipe(D, folder, origin, ry, rng, height=24.0, x=0.0, gutter=6.0, color=None):
    """A rain downpipe from the roof edge: a sagging gutter along the top (with a broken
    end), an outlet and swan-neck offset, pipe lengths with collars and wall brackets, a
    cracked joint leaking a long wet stain, a shoe at the foot (tag CityGutter: it spouts in
    the rain) with a green slimy splash patch on the wall and floor.
    Footprint: gutter x 1, height tall. Parts: 18-24."""
    f = frame_at(D, folder, origin, ry).sub((x, 0, 0))
    pc = color or jitter(rng.choice([METAL_DARK, (60, 62, 60), (34, 34, 34), (70, 60, 52)]), rng, 6)
    n = 0
    gl = gutter
    gx = rng.uniform(-gl * 0.3, gl * 0.3)
    f.part("Gutter", (gx, height - 0.2, -0.45), (gl, 0.4, 0.6), jitter(pc, rng, 4), "Metal",
           rot=(0, 0, rng.uniform(-1.2, 1.2)), flags=DECOR)
    f.box("GutterLip", (gx - gl / 2, height - 0.05, -0.8), (gx + gl / 2, height + 0.05, -0.72), jitter(pc, rng, 4, 0.1),
          "Metal", flags=DECOR)
    # a broken bit hanging off one end
    f.part("GutterEnd", (gx + gl / 2 + 0.6, height - 0.6, -0.5), (1.2, 0.35, 0.55), jitter(pc, rng, 4, 0.1), "Metal",
           rot=(0, 0, -rng.uniform(15, 35)), flags=DECOR)
    n += 3
    d = 0.5
    zc = -0.45
    # outlet + swan neck (out from the gutter, back to the wall)
    rod(f, "Outlet", (0, height - 0.3, -0.45), (0, height - 0.9, -0.45), d, pc, "Metal", flags=DECOR)
    rod(f, "SwanNeck", (0, height - 0.9, -0.45), (0, height - 1.9, zc), d, pc, "Metal", flags=DECOR)
    n += 2
    top = height - 1.9
    lengths = rng.randint(3, 4)
    leak = rng.randrange(1, lengths)
    for i in range(lengths):
        a = top - i * top / lengths
        b = top - (i + 1) * top / lengths + 0.6
        rod(f, "Downpipe", (rng.uniform(-0.02, 0.02), a, zc), (0, max(b, 0.8), zc), d, jitter(pc, rng, 3), "Metal",
            flags=DECOR_SHADOW)
        f.box("Collar", (-0.32, a - 0.35, zc - 0.32), (0.32, a, zc + 0.32), jitter(pc, rng, 3, 0.15), "Metal", flags=DECOR)
        f.box("Bracket", (-0.06, a - 0.6, zc), (0.06, a - 0.45, 0), METAL_DARK, "Metal", flags=DECOR)
        n += 3
        if i == leak:
            n += streak(f, rng, "Leak", rng.uniform(0.3, 0.6), a - 0.35, rng.uniform(4, a - 1), 0.8, WET_DARK, k=0,
                        tr=0.5, taper=3)
    f.part("Shoe", (0.25, 0.55, zc - 0.15), (1.0, d, d), jitter(pc, rng, 4, 0.1), "Metal", rot=(0, 90, -30),
           shape=CYLINDER, flags=DECOR, extra={"t": ["CityGutter"]})
    overlay(f, "Slime", -0.9, 1.2, 0, rng.uniform(1.2, 2.0), jitter(MOSS, rng, 6, 0.2), k=0, tr=0.4, material="Grass")
    f.box("Splash", (-0.8, 0, -1.6), (1.2, 0.04, -0.05), jitter(MOSS, rng, 6, 0.35), "Slate", transparency=0.3,
          flags=DECOR)
    return n + 3


def vent_hood(D, folder, origin, ry, rng, y=8.0, x=0.0, width=None, grease=True):
    """A kitchen / boiler exhaust through the wall: a square duct stub with a louvred hood
    (slanted blades), a bird-mesh dark mouth, a black soot plume on the wall above it and
    brown grease weeping below. Footprint: ~2 x 1.2. Parts: 9-14."""
    f = frame_at(D, folder, origin, ry).sub((x, y, 0))
    w = width or rng.uniform(1.6, 2.4)
    h = w * rng.uniform(0.8, 1.0)
    c = jitter(rng.choice([GALV, (90, 86, 76), METAL]), rng, 6, 0.15)
    n = 0
    f.box("Duct", (-w / 2 - 0.15, -0.15, -0.6), (w / 2 + 0.15, h + 0.15, 0), c, "Metal", flags=DECOR)
    f.box("Mouth", (-w / 2, 0, -0.65), (w / 2, h, -0.6), (14, 14, 14), "Metal", flags=DECOR)
    n += 2
    blades = max(3, int(h / 0.38))
    for i in range(blades):
        yy = (i + 0.5) * h / blades
        f.part("Blade", (0, yy, -0.78), (w, h / blades * 0.95, 0.06), jitter(c, rng, 3, 0.1 + 0.05 * (i == 1)), "Metal",
               rot=(-38 + rng.uniform(-6, 6), 0, 0), flags=DECOR)
        n += 1
    # soot plume: dark at the hood, spreading and fading as it rises
    ph = rng.uniform(3, 5)
    for i in range(3):
        t = i / 2
        pw = w * (0.8 + 0.9 * (1 - t)) + 0.3
        overlay(f, "SootPlume", -pw / 2 + rng.uniform(-0.2, 0.2), pw / 2 + rng.uniform(-0.2, 0.2), h + 0.15,
                h + 0.15 + ph * (1 - 0.6 * t), SOOT, k=i, tr=0.8 - 0.1 * t)
    n += 3
    if grease:
        n += streak(f, rng, "Grease", rng.uniform(-w / 4, w / 4), -0.15, rng.uniform(1.5, 3.5), 0.7, (64, 44, 24), k=0,
                    tr=0.4, taper=2)
    return n


def satellite_dish(D, folder, origin, ry, rng, y=12.0, x=0.0, size=None):
    """An old satellite dish on a wall bracket, pointing up and sideways: wall plate, arm,
    the dish (a flattened ball, dirty white, rust spots), LNB arm and head, the coax cable
    clipped down the wall, a rust stain under the plate. Footprint: ~2.2 x 2.4.
    Parts: 8-11."""
    f = frame_at(D, folder, origin, ry).sub((x, y, 0))
    d = size or rng.uniform(1.8, 2.6)
    n = 0
    f.box("Plate", (-0.35, -0.5, -0.1), (0.35, 0.5, 0), METAL_DARK, "Metal", flags=DECOR)
    rod(f, "Arm", (0, 0, -0.1), (0, 0.1, -1.1), 0.16, METAL_DARK, "Metal", flags=DECOR)
    n += 2
    yaw = rng.uniform(-35, 35)
    g = f.sub((0, 0.1, -1.2), ry=yaw, rx=rng.uniform(20, 35))
    g.part("Dish", (0, 0, -0.05), (d, d, 0.32), jitter((166, 164, 156), rng, 8, 0.15), "SmoothPlastic", shape=BALL,
           flags=DECOR)
    g.part("DishRim", (0, 0, 0.05), (d * 0.98, d * 0.98, 0.08), jitter((130, 128, 120), rng, 6), "SmoothPlastic",
           shape=BALL, flags=DECOR)
    rod(g, "LnbArm", (0, -d * 0.45, -0.1), (0, -0.1, -d * 0.55), 0.08, (90, 90, 86), "Metal", flags=DECOR)
    g.part("Lnb", (0, -0.05, -d * 0.6), (0.22, 0.22, 0.4), (40, 40, 40), "Plastic", flags=DECOR)
    n += 4
    for _ in range(rng.randint(1, 2)):
        g.part("RustSpot", (rng.uniform(-d / 4, d / 4), rng.uniform(-d / 4, d / 4), -0.2), (0.25, 0.2, 0.05), RUST_STAIN,
               "CorrodedMetal", flags=DECOR)
        n += 1
    cy = -rng.uniform(4, 8)
    rod(f, "Coax", (0.2, 0, -0.12), (0.25, cy, -0.12), 0.06, CABLE, "Rubber", flags=DECOR)
    n += 1
    n += streak(f, rng, "RustStreak", 0, -0.5, rng.uniform(1.2, 2.5), 0.4, RUST_STAIN, k=0, taper=2)
    return n


# =================================================================================================
# 5. Wall lights (with a light extra)
# =================================================================================================


def bulkhead_light(D, folder, origin, ry, rng, y=8.0, x=0.0, dead=False, flicker=False, color=WARM, range_=18,
                   brightness=0.9):
    """A caged bulkhead light: cast back plate, body, frosted globe (the bulb part, Neon,
    carries the light: tag CityBulkhead, or CityLamp with Dead / Flicker like alleys.py
    wall_light), a wire cage, a conduit up to a junction box, soot and dead insects stain
    above, rust under. Footprint: 0.9 x 0.8, 0.9 tall (+ conduit). Parts: 10-13."""
    f = frame_at(D, folder, origin, ry).sub((x, y, 0))
    n = 0
    f.box("BackPlate", (-0.45, -0.5, -0.12), (0.45, 0.5, 0), jitter((50, 50, 48), rng, 6), "Metal", flags=DECOR)
    f.box("Body", (-0.32, -0.38, -0.42), (0.32, 0.38, -0.12), jitter((66, 66, 60), rng, 6), "Metal", flags=DECOR)
    n += 2
    attrs = {}
    if dead:
        attrs["Dead"] = True
    if flicker:
        attrs["Flicker"] = True
    tag = "CityLamp" if (dead or flicker) else "CityBulkhead"
    f.part("Bulb", (0, 0, -0.55), (0.5, 0.58, 0.4), (90, 90, 86) if dead else color, "Neon" if not dead else "Glass",
           shape=BALL, flags=DECOR,
           extra=light_extra([tag], {"type": "Point", "color": list(color), "range": range_, "brightness": brightness,
                                     "name": "Light", "shadows": False}, attrs or None))
    n += 1
    for a in (-0.2, 0.2):  # cage
        f.box("Cage", (a - 0.03, -0.36, -0.8), (a + 0.03, 0.36, -0.74), (36, 36, 36), "Metal", flags=DECOR)
        n += 1
    f.box("Cage", (-0.3, -0.03, -0.82), (0.3, 0.03, -0.76), (36, 36, 36), "Metal", flags=DECOR)
    n += 1
    top = rng.uniform(2.0, 4.0)
    rod(f, "Conduit", (0, 0.5, -0.15), (0, top, -0.15), 0.14, jitter((70, 70, 66), rng, 6), "Metal", flags=DECOR)
    f.box("JunctionBox", (-0.25, top, -0.3), (0.25, top + 0.5, 0), jitter((70, 70, 66), rng, 6), "Metal", flags=DECOR)
    n += 2
    overlay(f, "Soot", -0.9, 0.9, 0.5, rng.uniform(1.6, 2.6), SOOT, k=0, tr=0.78)
    n += 1
    n += streak(f, rng, "RustStreak", rng.uniform(-0.3, 0.3), -0.5, rng.uniform(0.8, 1.8), 0.3, RUST_STAIN, k=0, taper=2)
    return n


def gooseneck_lamp(D, folder, origin, ry, rng, y=10.0, x=0.0, reach=2.2, dead=False, flicker=False, color=None,
                   range_=24, brightness=1.2):
    """A gooseneck barn lamp: wall plate, a bent arm curving out and down (4 segments), an
    enamel shade (dark outside, two stacked cylinders: crown + wide rim) with the bulb
    under it (Neon, Spot light facing down, tag CityLamp; Dead / Flicker), rust and soot.
    Footprint: 1.6 x (reach + 0.8), ~2 tall. Parts: 9-12."""
    f = frame_at(D, folder, origin, ry).sub((x, y, 0))
    color = color or [255, 168, 96]
    shade = jitter(rng.choice([(40, 54, 46), (34, 34, 36), (70, 34, 30)]), rng, 6)
    n = 0
    f.box("WallPlate", (-0.3, -0.4, -0.1), (0.3, 0.4, 0), METAL_DARK, "Metal", flags=DECOR)
    n += 1
    pts = [(0, 0.0, -0.1), (0, 0.55, -0.45), (0, 0.85, -1.0), (0, 0.85, -reach + 0.5), (0, 0.55, -reach)]
    for i in range(4):
        rod(f, "Arm", pts[i], pts[i + 1], 0.14, jitter(shade, rng, 4, 0.2), "Metal", flags=DECOR)
        n += 1
    sx, sy, sz = 0, 0.25, -reach
    f.part("ShadeCrown", (sx, sy + 0.2, sz), (0.35, 0.5, 0.5), shade, "Metal", rot=(0, 0, 90), shape=CYLINDER,
           flags=DECOR)
    f.part("Shade", (sx, sy - 0.08, sz), (0.3, 1.5, 1.5), jitter(shade, rng, 4), "Metal", rot=(0, 0, 90), shape=CYLINDER,
           flags=DECOR_SHADOW)
    f.part("ShadeRim", (sx, sy - 0.24, sz), (0.06, 1.62, 1.62), jitter(shade, rng, 4, 0.2), "Metal", rot=(0, 0, 90),
           shape=CYLINDER, flags=DECOR)
    n += 3
    attrs = {}
    if dead:
        attrs["Dead"] = True
    if flicker:
        attrs["Flicker"] = True
    f.part("LampHead", (sx, sy - 0.32, sz), (0.36, 0.3, 0.36), (90, 90, 86) if dead else tuple(color),
           "Glass" if dead else "Neon", shape=BALL, flags=DECOR,
           extra=light_extra(["CityLamp"], {"type": "Spot", "color": list(color), "range": range_,
                                            "brightness": brightness, "angle": 100, "face": "Bottom",
                                            "shadows": True, "name": "Light"}, attrs or None))
    n += 1
    overlay(f, "Soot", -0.7, 0.7, 0.4, rng.uniform(1.4, 2.2), SOOT, k=0, tr=0.8)
    n += 1
    n += streak(f, rng, "RustStreak", 0, -0.4, rng.uniform(1, 2.2), 0.35, RUST_STAIN, k=0, taper=2)
    return n


# ------------------------------------------------------------------ catalogue
WALL_PROPS = {
    "wall_grime": wall_grime, "plaster_patch": plaster_patch, "crack": crack, "rust_streak": rust_streak,
    "efflorescence": efflorescence, "torn_posters": torn_posters, "painted_sign": painted_sign,
    "graffiti_tag": graffiti_tag, "window": window, "back_door": back_door, "roller_shutter": roller_shutter,
    "fire_escape": fire_escape, "building_top": building_top, "background_facade": background_facade,
    "chainlink_fence": chainlink_fence, "ac_unit": ac_unit, "meter_box": meter_box, "cable_sag": cable_sag,
    "pipe_run": pipe_run, "downpipe": downpipe, "vent_hood": vent_hood, "satellite_dish": satellite_dish,
    "bulkhead_light": bulkhead_light, "gooseneck_lamp": gooseneck_lamp,
}

__all__ = list(WALL_PROPS) + ["WALL_PROPS", "beam", "rod", "overlay", "streak"]

_ = (BLOCK, PROP)  # (re-exported flags kept for callers)
