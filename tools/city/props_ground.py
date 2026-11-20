"""props_ground: the ground clutter and floor detail of the alleys, built from parts.

Every prop is one function

    name(D, folder, origin, ry, rng, **options) -> number of parts made

  • D       a citykit.Data
  • folder  the folder the parts go in (e.g. "Alleys/Props")
  • origin  the floor point (x, y, z) the prop stands on (y = the floor's top)
  • ry      its turn about Y in degrees (its front faces -Z when ry = 0; "against a wall" props
            have the wall behind them, on +Z)
  • rng     a random.Random: sizes, tilts, wear and colours all come from it (no two alike)

Scale: a Roblox character is about 5 studs tall, 1 stud ~ 0.3 m. Sizes follow the real objects
(scratchpad quality/real_specs.md): a brick 0.72 x 0.22 x 0.34, a cinder block 1.3 x 0.65 x 0.65,
a EUR pallet 4.0 x 2.67 x 0.48, a milk crate 1.1 x 1.1 x 0.93, a cigarette butt 0.03 thick.

Flags: DECOR for litter and floor marks (no collision, no shadow), DECOR_SHADOW for loose things
that should still shade the ground, SMALL / PROP for things a player bumps into or stands on.

NO Z-FIGHTING (the player's photo: surfaces flickering, two textures at once). The rules here:
  • Floor marks (stains, puddles, damp, paint, cracks, paper lying flat) are floor DECALS made by
    _disk / _flat: zlayers.floor_layer gives each one its own height over the decals under it
    (props from every library share the allocator) and makes a translucent one opaque with the
    blended colour. A prop makes ONE layer per place, at most one more on top (a glossy core,
    a lid): never a stack of half-transparent blots. Broad marks are DECAL_TH thick so their top
    clears the floor's top by 0.06 or more (no depth fight at any range); narrow ones (cracks,
    paint lines) are LINE_TH, their top 0.03 above the floor, so they read flush, not as sticks.
  • A detail ON a surface (tape on a box, a label, a wet band, a print band, a hand hole, a
    sealed seam) is INLAID in it: the surface is cut into butted pieces (_grid / _slab), the
    detail one of them, flush, same thickness. Nothing sits 0.01 over anything.
  • Parts that touch share faces only back to back (a block on a board), never two same-facing
    faces on one plane; parts in a row keep air gaps; nothing hides inside another part.
  • Wall-foot props (wall_base_grime, leaves_drift, weeds "line") find the wall face themselves
    (_wall_face) and build nothing inside the wall. Decals shrink away from raised things already
    there (a gutter, a drain, a crate) instead of cutting through them.

Only built-in Materials and colours (no textures, no meshes). The 2024 Material "Cardboard" is used
for cardboard; set CARDBOARD_MAT to "SmoothPlastic" if a build ever lacks it.

NO BOTTLES of any kind (glass or plastic, decoration or litter), nor anything that reads as one:
there is none in here, keep it so.

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
import zlayers  # noqa: E402

CARDBOARD_MAT = "Cardboard"

DECAL_TH = 0.062  # a broad floor mark: its top 0.062 over the floor (>= 0.06: no depth fight)
LINE_TH = 0.03  # a narrow mark (crack, paint line, chalk): reads flush; a thicker one reads as a stick
SHEET_TH = 0.025  # paper, foil, tape: real thin things

# -- palette (dirty, desaturated; matches alleys.py) -------------------------------------------
PAPER = [(178, 172, 156), (164, 158, 142), (170, 156, 124), (150, 146, 134), (182, 178, 166)]
NEWSPRINT = (156, 152, 140)
INK = (46, 45, 44)
FLYER = [(150, 60, 50), (60, 90, 120), (176, 150, 60), (90, 110, 70), (160, 150, 140)]
CARDBOARD = (132, 106, 72)
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
PALLET = [(122, 102, 72), (108, 92, 66), (96, 88, 74), (130, 112, 80), (118, 112, 100)]
BRICK = [(84, 60, 50), (96, 64, 52), (68, 49, 42), (80, 44, 36), (102, 70, 56)]
MORTAR = (118, 112, 102)
CONCRETE = (116, 113, 106)
CONCRETE_OLD = (92, 89, 84)
CONCRETE_FRESH = (146, 142, 134)
CINDER = (112, 110, 104)
ASPHALT_NEW = (34, 34, 36)
ASPHALT_WORN = (64, 64, 66)
TAR = (14, 14, 15)
CRACK_DARK = (20, 19, 18)
RUST = (89, 47, 30)
IRON = (46, 44, 42)
RUBBER = (30, 30, 32)
RUBBER_OLD = (48, 47, 46)
OIL = (14, 13, 13)
DAMP = (28, 27, 26)
GRASS = [(62, 76, 40), (52, 64, 34), (84, 86, 48), (104, 98, 58), (70, 82, 44)]
MOSS = [(44, 56, 30), (38, 48, 26), (56, 64, 34)]
WATER = (38, 42, 48)
PAINT = {"orange": (196, 98, 42), "white": (188, 186, 176), "yellow": (186, 162, 62), "red": (150, 44, 40),
         "blue": (60, 92, 140)}
CHALK = (200, 198, 188)
CRATE = [(120, 40, 36), (40, 60, 92), (34, 34, 36), (48, 76, 52)]
CAN = [(150, 30, 34), (40, 70, 130), (30, 30, 32), (60, 120, 60), (180, 160, 40)]

CATALOGUE = []  # [(function, [options, ...])]


def prop(*variants):
    """Registers a prop for the catalogue and makes it return the number of parts it made."""

    def wrap(fn):
        @functools.wraps(fn)
        def inner(D, folder, origin, ry, rng, **opts):
            n0 = len(D.parts)
            zlayers.new_instance(D)  # (its floor decals stack over earlier props')
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


def _decal(f, th, flags, kw):
    """Whether a flat part is a floor DECAL for zlayers (stain, puddle, moss, paper...): thin,
    no collision, lying on a level frame, no parent / extra. Those go through
    zlayers.floor_layer, which gives each one its own height (overlapping decals of every prop
    stack at least 0.035 apart, never coplanar, at most 3 in one place) and makes a
    translucent one opaque with the blended colour when it lies on one opaque surface."""
    return (th <= zlayers.FLOOR_DECAL_MAX_TH and flags == DECOR and abs(f.m[1, 1]) > 0.9995
            and not kw.get("extra") and not kw.get("parent"))


def _free(f, x, y, z):
    """Whether the local point is in the open air (inside no part of the data or the city):
    decals and litter keep out of raised things placed before them (a gutter, a drain, a crate)."""
    return zlayers.host_at(f.D, tuple(float(v) for v in f.world((x, y, z)))) is None


def _fit(f, y, points):
    """The largest scale (1, 0.85 ... 0.4) at which every point of points(scale) is free 0.03
    above the local height y, or 0 (the decal would cut through something raised: skip it)."""
    for k in (1.0, 0.85, 0.7, 0.55, 0.4):
        if all(_free(f, px, y + 0.03, pz) for px, pz in points(k)):
            return k
    return 0.0


def _disk(f, name, x, z, d, th, color, mat, y=0.0, flags=DECOR, fit=True, **kw):
    """A flat disk lying on the floor (a cylinder turned upright). A thin DECOR one is a floor
    decal (see _decal): it shrinks away from raised parts already there (fit), may be lifted
    over decals under it, made opaque, or dropped (None) where 3 decals already overlap."""
    if not _decal(f, th, flags, kw):
        return f.part(name, (x, y + th / 2, z), (th, d, d), color, mat, rot=(0, 0, 90), shape=CYLINDER,
                      flags=flags, flush=(0, 1), **kw)
    if fit:
        ring = [(math.cos(i * math.pi / 8) * d * 0.48, math.sin(i * math.pi / 8) * d * 0.48) for i in range(16)]
        ring += [(math.cos(i * math.pi / 4) * d * 0.26, math.sin(i * math.pi / 4) * d * 0.26) for i in range(8)]
        k = _fit(f, y, lambda s: [(x, z)] + [(x + u * s, z + v * s) for u, v in ring])
        if k <= 0:
            return None
        d *= k
    tr0 = kw.pop("transparency", 0.0)

    def make(yc, t, col, tr, m):
        return f.part(name, (x, yc, z), (t, d, d), col, m, rot=(0, 0, 90), shape=CYLINDER, flags=flags,
                      transparency=tr, flush=(0, 1), **kw)

    r = d * 0.85  # (a disk's square bounds overstate it: count only clear overlaps)
    return zlayers.floor_layer(f, name, x, y, z, r, r, th, 0.0, make, color, tr0, mat)


def _rect_pts(x, z, w, d, yaw, s=1.0):
    """Centre, corners and edge middles of a w x d rectangle turned yaw (local floor points)."""
    a = math.radians(yaw)
    ca, sa = math.cos(a), math.sin(a)
    out = []
    for ux, uz in ((0, 0), (-1, -1), (1, -1), (1, 1), (-1, 1), (0, -1), (1, 0), (0, 1), (-1, 0)):
        lx, lz = ux * w * 0.47 * s, uz * d * 0.47 * s
        out.append((x + lx * ca + lz * sa, z - lx * sa + lz * ca))
    return out


def _flat(f, name, x, z, w, d, th, color, mat, yaw=0.0, y=0.0, flags=DECOR, fit=True, **kw):
    """A flat plate lying on the floor (w along local X, d along Z, turned yaw). A thin DECOR one
    is a floor decal (see _decal); `fit` shrinks it away from raised parts already there."""
    if not _decal(f, th, flags, kw):
        return f.part(name, (x, y + th / 2, z), (w, th, d), color, mat, rot=(0, yaw, 0), flags=flags, flush=(1, 1),
                      **kw)
    if fit:
        k = _fit(f, y, lambda s: _rect_pts(x, z, w, d, yaw, s))
        if k <= 0:
            return None
        w, d = w * k, d * k
    tr0 = kw.pop("transparency", 0.0)

    def make(yc, t, col, tr, m):
        return f.part(name, (x, yc, z), (w, t, d), col, m, rot=(0, yaw, 0), flags=flags, transparency=tr,
                      flush=(1, 1), **kw)

    return zlayers.floor_layer(f, name, x, y, z, w, d, th, yaw, make, color, tr0, mat)


def _top(f, idx, default=0.0):
    """The local height of the top of row idx (a decal made in level frame f) over f's origin:
    what something lying on it rests on (the decal may have been lifted over others)."""
    if idx is None:
        return default
    r = f.D.parts[idx - 1]
    th = r[7] if r[0] == CYLINDER else r[8]
    return float(r[2] + th / 2 - f.origin[1])


def _in_quad(poly, px, pz):
    """Whether (px, pz) is inside the convex polygon poly ([(x, z), ...] in order)."""
    sign = 0
    for i in range(len(poly)):
        (x0, z0), (x1, z1) = poly[i], poly[(i + 1) % len(poly)]
        c = (x1 - x0) * (pz - z0) - (z1 - z0) * (px - x0)
        if abs(c) < 1e-9:
            continue
        if sign == 0:
            sign = 1 if c > 0 else -1
        elif (c > 0) != (sign > 0):
            return False
    return True


def _rest(f, x, z):
    """The local height (over f's origin) of the top of the highest floor decal under the local
    floor point (x, z), 0 when there is none: litter lies ON a stain, not sunk in it."""
    p = f.world((x, 0, z))
    best = 0.0
    for fl in zlayers._state(f.D)["floors"]:
        if abs(fl["y"] - p[1]) > 0.03:
            continue
        for it in fl["items"]:
            if "top" in it and _in_quad(it["poly"], p[0], p[2]):
                best = max(best, fl["y"] + it["top"] - p[1])
    return best


def _on_decals(D, folder, origin, ry):
    """A prop's frame lifted onto the floor decals or the raised slab (a gutter) under its origin
    (see _rest, _raised)."""
    f = Frame(D, folder, origin, ry=ry)
    ring = [(0, 0)] + [(math.cos(i * math.pi / 3) * 0.42, math.sin(i * math.pi / 3) * 0.42) for i in range(6)]
    lift = max(max(_rest(f, x, z) for x, z in ring), _raised(f, ring, reach=0.2))
    return f if lift <= 0 else Frame(D, folder, (origin[0], origin[1] + lift, origin[2]), ry=ry)


def _tri(f, name, x, z, w, d, th, color, mat, yaw=0.0, y=0.0, flags=DECOR, **kw):
    """A flat right triangle lying in frame f (a wedge on its side): legs w (along -X) and d (Z)."""
    return f.part(name, (x, y + th / 2, z), (th, w, d), color, mat, rot=(0, yaw, 90), shape=WEDGE, flags=flags,
                  **kw)


def _look(color, mat, name, tr=0.0, refl=0.0):
    """A piece's look for _grid: (colour, material, name, transparency, reflectance)."""
    return (tuple(round(c, 2) for c in color), mat, name, tr, refl)


def _grid(u0, u1, v0, v1, base, inlays):
    """Cuts the rectangle u0..u1 x v0..v1 into butted pieces so that each inlay
    (a0, a1, b0, b1, look) is a piece of its own: tape on a box, a wet band, a label, a print
    band, a seam, a hole (look None). The detail is then IN the surface (flush, same thickness),
    not a slab over it, so no two faces share a plane. A later inlay wins where two cross.
    Returns [(a0, a1, b0, b1, look)], holes left out, neighbouring cells of one look merged."""
    def breaks(lo, hi, cuts):
        # (a cut closer than 0.065 to the rectangle's edge snaps onto it: no sliver along an edge,
        # whose inner face would lie a hair behind its outer one)
        out = {lo, hi}
        for c in cuts:
            c = min(max(c, lo), hi)
            out.add(lo if c - lo < 0.065 else hi if hi - c < 0.065 else c)
        return sorted(out)

    us = breaks(u0, u1, [a for il in inlays for a in il[0:2]])
    vs = breaks(v0, v1, [b for il in inlays for b in il[2:4]])

    def look(u, v):
        out = base
        for il in inlays:
            if il[0] <= u <= il[1] and il[2] <= v <= il[3]:
                out = il[4]
        return out

    pieces, live = [], {}
    for j in range(len(vs) - 1):
        va, vb = vs[j], vs[j + 1]
        if vb - va < 1e-4:
            continue
        runs = []
        for i in range(len(us) - 1):
            if us[i + 1] - us[i] < 1e-4:
                continue
            lk = look((us[i] + us[i + 1]) / 2, (va + vb) / 2)
            if runs and runs[-1][2] == lk and abs(runs[-1][1] - us[i]) < 1e-6:
                runs[-1][1] = us[i + 1]
            else:
                runs.append([us[i], us[i + 1], lk])
        nxt = {}
        for a, b, lk in runs:
            key = (round(a, 5), round(b, 5), lk)
            p = live.get(key)
            if p is not None and abs(p[3] - va) < 1e-6:
                p[3] = vb
            else:
                p = [a, b, va, vb, lk]
                pieces.append(p)
            nxt[key] = p
        live = nxt
    return [tuple(p) for p in pieces if p[4] is not None]


def _slab(f, lo, hi, axes, base, inlays=(), flags=DECOR):
    """A box from local corner lo to hi whose face (spanned by local axes `axes` = (u, v)) carries
    inlays (see _grid): built as butted boxes. Returns their indices."""
    au, av = axes
    out = []
    for a, b, va, vb, (col, mat, name, tr, refl) in _grid(lo[au], hi[au], lo[av], hi[av], base, inlays):
        p, q = list(lo), list(hi)
        p[au], q[au], p[av], q[av] = a, b, va, vb
        out.append(f.box(name, p, q, col, mat, flags=flags, transparency=tr, reflectance=refl))
    return out


def _floor_grid(f, x, z, w, d, yaw, th, base, inlays=(), fit=False):
    """A floor decal of w x d (turned yaw, centred on (x, z)) carrying inlays: butted flat pieces
    (seams, a cover in its frame, grate bars and voids), all on one level, flush. Inlay
    coordinates are local to the rectangle's centre (u along its width, v along its depth).
    Returns the indices made (pieces refused by zlayers left out)."""
    g = f.sub((x, 0, z), ry=yaw)
    if fit and not all(_free(g, px, 0.03, pz) for px, pz in _rect_pts(0, 0, w, d, 0)):
        return []
    out = []
    for a, b, va, vb, (col, mat, name, tr, refl) in _grid(-w / 2, w / 2, -d / 2, d / 2, base, inlays):
        i = _flat(g, name, (a + b) / 2, (va + vb) / 2, b - a, vb - va, th, col, mat, fit=False, transparency=tr,
                  reflectance=refl)
        if i is not None:
            out.append(i)
    return out


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


def _line(f, name, pts, w0, w1, color, mat, th=LINE_TH, **kw):
    """A narrow floor mark along the local floor points pts (crack, painted line): butted flat
    decals tapering from width w0 to w1, each segment ending where the next starts (no overlap,
    so they share one level). Returns the indices made."""
    out = []
    m = len(pts) - 1
    for i in range(m):
        (x0, z0), (x1, z1) = pts[i], pts[i + 1]
        ln = math.hypot(x1 - x0, z1 - z0)
        if ln < 0.02:
            continue
        w = w0 + (w1 - w0) * i / max(1, m - 1)
        yaw = math.degrees(math.atan2(x1 - x0, z1 - z0))
        trim = (w * 0.12 if i > 0 else 0) + (w * 0.12 if i < m - 1 else 0)  # (bends: no corner overlap)
        if not all(_free(f, px, 0.03, pz) for px, pz in ((x0, z0), (x1, z1), ((x0 + x1) / 2, (z0 + z1) / 2))):
            continue  # (the crack stops at the gutter: no line cutting through it)
        idx = _flat(f, name, (x0 + x1) / 2, (z0 + z1) / 2, w, max(0.02, ln - trim), th, color, mat, yaw=yaw, fit=False,
                    **kw)
        if idx is not None:
            out.append(idx)
    return out


def _tone(color, rng, amount=8, darken=0.0):
    """A colour a little lighter or darker each time, keeping its hue (per-channel noise would turn
    browns pink or green): amount ~ the brightness swing in colour units."""
    mean = max(1.0, sum(color) / 3)
    k = (1 + rng.uniform(-amount, amount) / mean) * (1 - darken)
    return tuple(max(0, min(255, c * k + rng.uniform(-2, 2))) for c in color)


def _tilt(rng, lo, hi):
    """A tilt of lo..hi degrees either way: never under lo, so a small thing lying on a surface is
    never parallel to it (its top would sit a hair over the surface's and flicker)."""
    return rng.uniform(lo, hi) * rng.choice((-1, 1))


def _pick(rng, seq):
    return seq[rng.randrange(len(seq))]


def _w(f, x, z, y=0.0):
    """A local floor point as a world tuple (to place a sub-prop)."""
    return tuple(float(v) for v in f.world((x, y, z)))


def _yaw(f):
    """The frame's own turn about Y in degrees (for sub-props)."""
    return math.degrees(math.atan2(f.m[0, 2], f.m[2, 2]))


def _raised(f, points, reach=0.3):
    """How high the highest raised thing (a gutter slab, a drain, a step's lip) under the local
    floor points stands, up to `reach` (0 if none): a box set down there stands on it."""
    top = 0.0
    for px, pz in points:
        for i in range(int(reach / 0.01), 0, -1):
            if not _free(f, px, i * 0.01 - 0.005, pz):
                top = max(top, i * 0.01)
                break
    return top


def _wall_face(f, x, reach=1.6, y=0.0):
    """How far behind the local floor point (x, y, 0), along +Z, the face of the wall is: the
    first point solid at both 0.9 and 2.6 studs up (a wall, not a crate), to 0.01. 0 when the
    point is already in the wall's face, None when there is no wall within `reach`.
    Wall-foot props build against it so that nothing goes inside the wall."""

    def solid(z):
        return all(not _free(f, x, y + h, z) for h in (0.9, 2.6))

    if solid(0.0):
        return 0.0
    step = 0.05
    for i in range(1, int(reach / step) + 1):
        if solid(i * step):
            lo, hi = (i - 1) * step, i * step
            for _ in range(5):
                mid = (lo + hi) / 2
                if solid(mid):
                    hi = mid
                else:
                    lo = mid
            return lo
    return None


def _leaf(f, x, y, z, rng, col=None, wet=False, tilt=22, size=1.0):
    """A dead leaf lying on the surface at height y: a thin card, often cupped (two halves folded
    up along the midrib), turned at random; its lowest edge on the surface. 1-2 parts, DECOR."""
    col = col or _tone(_pick(rng, LEAF), rng, 10, darken=0.3 if wet else rng.uniform(0, 0.18))
    ln = rng.uniform(0.18, 0.32) * size
    wd = ln * rng.uniform(0.45, 0.65)
    rx, rz = _tilt(rng, 3, max(4, tilt)), _tilt(rng, 3, max(4, tilt))
    lift = 0.5 * (ln * abs(math.sin(math.radians(rx))) + wd * abs(math.sin(math.radians(rz))))
    g = f.sub((x, y + 0.012 + lift, z), ry=rng.uniform(0, 360))
    g = g.sub((0, 0, 0), rx=rx, rz=rz)
    if rng.random() < 0.3:
        fold = rng.uniform(10, 22)
        for e in (-1, 1):
            h = g.sub((0, 0, 0), rz=e * fold)
            h.part("Leaf", (e * wd / 4, 0, 0), (wd / 2, 0.02, ln), col if e < 0 else _tone(col, rng, 5), "Fabric",
                   flags=DECOR)
    else:
        g.part("Leaf", (0, 0, 0), (wd, 0.02, ln * 0.92), col, "Fabric", flags=DECOR)


# =============================================================================================
# Paper, cardboard, wrappers, butts
# =============================================================================================
@prop({}, {"size": 0.36}, {"size": 0.26})
def paper_ball(D, folder, origin, ry, rng, size=None, color=None):
    """A crumpled ball of paper (a sheet crushed in a fist: 8-11 cm across): a lumpy core of
    2-3 overlapping balls with a sheet's edge or two sticking out of it. Footprint 0.25-0.4
    studs. 3-5 parts, DECOR."""
    f = _on_decals(D, folder, origin, ry)
    s = size or rng.uniform(0.25, 0.36)
    col = color or _tone(_pick(rng, PAPER), rng, 10, darken=rng.uniform(0, 0.3))
    y = s * 0.44
    _ball(f, "PaperBall", (0, y, 0), s, col, "SmoothPlastic")
    for _ in range(rng.randint(1, 2)):  # lumps: it is never round
        a = rng.uniform(0, 2 * math.pi)
        d = s * rng.uniform(0.55, 0.72)
        _ball(f, "PaperBall", (math.cos(a) * s * 0.34, d * 0.46, math.sin(a) * s * 0.34), d, _tone(col, rng, 8),
              "SmoothPlastic")
    for _ in range(rng.randint(1, 2)):  # the crushed sheet's edges, poking out
        a = rng.uniform(0, 360)
        g = f.sub((0, y, 0), ry=a, rz=rng.uniform(-50, 50))
        g.part("PaperEdge", (s * 0.42, 0, 0), (s * 0.4, 0.02, s * rng.uniform(0.3, 0.45)), _tone(col, rng, 6, 0.04),
               "SmoothPlastic", flags=DECOR, rot=(rng.uniform(-40, 40), 0, 0))


def _page(f, x, z, W, Lp, col, kind, rng, decal=True):
    """One printed page lying in frame f, its top edge at z - Lp/2: margins, a headline band
    and body columns (newspaper), a coloured band and an image block (flyer), or lines of text
    (sheet), all INLAID (butted pieces, see _grid). decal: on the floor (zlayers decals);
    otherwise plain parts in a tilted frame."""
    ink = mix(col, INK, 0.5)
    grey = mix(col, INK, 0.2)
    m = 0.06
    v0 = -Lp / 2
    if kind == "newspaper":
        hb = Lp * 0.09
        gut = W * 0.05
        inl = [(-W / 2 + m, W / 2 - m, v0 + m, v0 + m + hb, _look(ink, "SmoothPlastic", "Print")),
               (-W / 2 + m, -gut / 2, v0 + 2 * m + hb, Lp / 2 - m, _look(grey, "SmoothPlastic", "Print")),
               (gut / 2, W / 2 - m, v0 + 2 * m + hb, Lp / 2 - m, _look(_tone(grey, rng, 3), "SmoothPlastic", "Print"))]
    elif kind == "flyer":
        inl = [(-W / 2, W / 2, v0, v0 + Lp * 0.22, _look(_tone(col, rng, 4, 0.25), "SmoothPlastic", "Print")),
               (-W / 2 + m, W / 2 - m, v0 + Lp * 0.3, v0 + Lp * 0.66,
                _look(mix(col, (40, 40, 44), 0.45), "SmoothPlastic", "Print"))]
    else:
        text = _look(mix(col, INK, 0.1), "SmoothPlastic", "Print")
        inl = [(-W / 2 + m * 1.4, W / 2 - m, v0 + m * 1.5, Lp / 2 - m * 2, text)]
    base = _look(col, "SmoothPlastic", "Paper")
    if decal:
        return _floor_grid(f, x, z, W, Lp, 0.0, SHEET_TH, base, inl)
    g = f.sub((x, 0, z))
    return _slab(g, (-W / 2, -SHEET_TH / 2, -Lp / 2), (W / 2, SHEET_TH / 2, Lp / 2), (0, 2), base, inl)


@prop({"kind": "sheet"}, {"kind": "newspaper"}, {"kind": "newspaper", "wet": True}, {"kind": "flyer"})
def paper_sheet(D, folder, origin, ry, rng, kind="sheet", wet=None):
    """A loose sheet / an open newspaper / a flyer lying flat, the part past its fold lifted and
    curling, maybe soaked dark. Print, headline and columns are inlaid in the paper (flush).
    Footprint: sheet 0.7 x 1.0, newspaper (open spread) 1.9 x 1.4, flyer 0.6 x 0.85 studs.
    3-12 parts, DECOR."""
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
    if wet:
        col = mix(col, CARDBOARD_WET, rng.uniform(0.35, 0.55))
    th = SHEET_TH
    if not all(_free(f, px, 0.03, pz) for px, pz in _rect_pts(0, 0, W * (2 if kind == "newspaper" else 1), L, 0)):
        return  # (something raised there: no paper cutting through it)
    if kind == "newspaper":
        # an open spread, trodden on: the left page lies flat (headline band and two columns),
        # the right page crumpled along its middle, its outer half lifted and twisted
        _page(f, -W / 2, 0, W, L, col, "newspaper", rng)
        g = f.sub((0.07, 0, rng.uniform(-0.04, 0.04)), ry=rng.uniform(1, 3.5))
        top = _top(g, _flat(g, "Paper", W * 0.24, 0, W * 0.48, L, th, _tone(col, rng, 4), "SmoothPlastic", fit=False),
                   th)
        h = g.sub((W * 0.48, top, 0), rz=rng.uniform(8, 20), rx=rng.uniform(-5, 5))
        h.part("Paper", (W * 0.13, -th / 2, 0), (W * 0.26, th, L * rng.uniform(0.94, 0.99)), _tone(col, rng, 6, 0.03),
               "SmoothPlastic", flags=DECOR)
        k = h.sub((W * 0.26, 0, 0), rz=rng.uniform(10, 25))
        k.part("Paper", (W * 0.12, -th / 2, 0), (W * 0.24, th, L * rng.uniform(0.86, 0.95)), _tone(col, rng, 6, 0.06),
               "SmoothPlastic", flags=DECOR)
    else:
        # the half before the fold lies flat (printed), the other half rises off it and curls
        idx = _page(f, 0, -L / 4, W, L / 2, col, kind, rng)
        g = f.sub((0, _top(f, idx[0], th) if idx else th, 0), rx=-rng.uniform(4, 9), ry=rng.uniform(-4, 4))
        g.part("Paper", (0, -th / 2, L / 8), (W * rng.uniform(0.96, 1.0), th, L / 4), _tone(col, rng, 5),
               "SmoothPlastic", flags=DECOR)
        h = g.sub((0, 0, L / 4), rx=-rng.uniform(8, 22))
        h.part("Paper", (0, -th / 2, L / 8), (W * rng.uniform(0.92, 0.98), th, L / 4), _tone(col, rng, 5, 0.04),
               "SmoothPlastic", flags=DECOR)


@prop({}, {"wet": True}, {"torn": True, "w": 3.6})
def cardboard_flat(D, folder, origin, ry, rng, w=None, d=None, wet=None, torn=None):
    """A flattened cardboard box on the floor: its two faces peaked a little at the crease, the
    packing tape along the crease and a printed logo INLAID in the board (flush), the flaps at
    both ends (one torn ragged, one bent up), one end soaked dark by the wet. Footprint
    2.6-3.8 x 2.6-4 studs. 10-18 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    W = w or rng.uniform(2.6, 3.6)
    L = d or rng.uniform(1.8, 2.6)
    lift = _raised(f, _rect_pts(0, 0, W, L * 1.8, 0), reach=0.2)
    if lift:  # (laid over the gutter's slab: it rests on it)
        f = f.sub((0, lift, 0))
    fl = L * rng.uniform(0.32, 0.45)
    base = _tone(CARDBOARD, rng, 8, darken=rng.uniform(0, 0.18))
    wet = (rng.random() < 0.5) if wet is None else wet
    torn = (rng.random() < 0.5) if torn is None else torn
    th = 0.04
    a = rng.uniform(2.5, 4.5)  # (> 1.8 deg: the faces are never parallel to the floor)
    torn_flap = rng.randrange(4) if torn else -1
    bent_flap = rng.randrange(4)
    wet_side = rng.choice((-1, 1)) if wet else 0
    tw = 0.14  # half the tape's width (it runs along the crease, over both faces)
    k = 0
    for s in (-1, 1):
        g = f.sub((s * W / 2, 0, 0), rz=-s * a)
        col = _tone(base, rng, 5)
        # the face, from its outer edge (x 0 in g) to the crease (x -s W/2): tape at the crease,
        # a printed logo on one face, the soaked half on the wet face (all inlaid)
        u0, u1 = (-W / 2, 0) if s > 0 else (0, W / 2)
        crease = u0 if s > 0 else u1
        inl = [(min(crease, crease + s * tw), max(crease, crease + s * tw), -L / 2, L / 2,
                _look(TAPE, "SmoothPlastic", "Tape", refl=0.06))]
        if s > 0:
            lx = rng.uniform(0.25, 0.55) * W / 2
            inl.insert(0, (-lx - 0.35, -lx + 0.35, -0.25, 0.25, _look(mix(col, INK, 0.45), CARDBOARD_MAT, "Print")))
        if s == wet_side:
            wz = rng.uniform(-0.1, 0.25) * L
            inl.insert(0, (u0, u1, -L / 2, wz, _look(mix(col, CARDBOARD_WET, 0.75), CARDBOARD_MAT, "Soggy")))
        _slab(g, (u0, 0, -L / 2), (u1, th, L / 2), (0, 2), _look(col, CARDBOARD_MAT, "Cardboard"), inl)
        for e in (-1, 1):
            fc = _tone(base, rng, 6, darken=0.05)
            if s == wet_side and e < 0:
                fc = mix(fc, CARDBOARD_WET, 0.7)
            fx = (u0 + u1) / 2
            if k == torn_flap:
                # torn off ragged: a short strip left, a jagged triangle of it still hanging on
                ft = fl * rng.uniform(0.25, 0.4)
                g.part("Cardboard", (fx, th / 2, e * (L / 2 + 0.03 + ft / 2)), (W / 2 - 0.05, th, ft), fc,
                       CARDBOARD_MAT, flags=DECOR)
                wt = fl * 0.6
                _tri(g, "Cardboard", fx + rng.uniform(-0.3, 0.3), e * (L / 2 + 0.03 + ft + wt / 2 + 0.01), wt,
                     W * 0.22, th, fc, CARDBOARD_MAT, yaw=90 if e > 0 else -90)
            elif k == bent_flap:
                h = g.sub((fx, th, e * (L / 2 + 0.03)), rx=e * -rng.uniform(15, 35))
                h.part("Cardboard", (0, -th / 2, e * fl / 2), (W / 2 - 0.06, th, fl), fc, CARDBOARD_MAT, flags=DECOR)
            else:
                g.part("Cardboard", (fx, th / 2, e * (L / 2 + fl / 2 + 0.03)), (W / 2 - 0.05, th, fl), fc,
                       CARDBOARD_MAT, flags=DECOR)
            k += 1


@prop({"state": "open"}, {"state": "closed"}, {"state": "crushed"}, {"state": "open", "wet": True})
def cardboard_box(D, folder, origin, ry, rng, size=None, state=None, wet=None):
    """A battered cardboard box standing on the floor (a moving box: 1.3-1.9 studs a side):
    open (flaps splayed at odd angles, one torn off), closed (the two top flaps meeting on a
    taped seam, the tape running down both ends), or crushed (a wall caved in, the lid sagging).
    The packing tape, a shipping label, a wet band soaked up from the ground and the hand holes
    are INLAID in the walls (flush, no stickers). Footprint 1.3-1.9 x 1.2-1.7 studs, 1.1-1.6 tall.
    7-22 parts; walls SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    W, H, Dp = size or (rng.uniform(1.4, 1.9), rng.uniform(1.1, 1.6), rng.uniform(1.2, 1.7))
    lift = _raised(f, _rect_pts(0, 0, W, Dp, 0))
    if lift:  # (set down on the gutter's slab, not sunk into it)
        f = f.sub((0, lift, 0))
    state = state or _pick(rng, ["open", "open", "closed", "crushed"])
    wet = (rng.random() < 0.5) if wet is None else wet
    col = _tone(CARDBOARD, rng, 8, darken=rng.uniform(0, 0.2))
    th = 0.065  # (>= 0.06: a wall's end face hidden behind the next wall is never near its outer face)
    M = CARDBOARD_MAT
    wb = rng.uniform(0.18, 0.4) if wet else 0.0
    wetl = _look(mix(col, CARDBOARD_WET, 0.8), M, "WetBand")
    tape = _look(TAPE, "SmoothPlastic", "Tape", refl=0.06)
    tw = 0.12  # half the tape's width
    hole = _look((40, 32, 24), M, "HandHole")

    def wall(lo, hi, axes, inl, tone=4, dark=0.0):
        _slab(f, lo, hi, axes, _look(_tone(col, rng, tone, dark), M, "Cardboard"), inl, flags=SMALL)

    # the bottom sits between the walls (no face of it shares a plane with theirs)
    f.box("Cardboard", (-W / 2 + th, 0, -Dp / 2 + th), (W / 2 - th, th, Dp / 2 - th), mix(col, CARDBOARD_WET, 0.5), M,
          flags=SMALL)
    front_inl = [(-W / 2, W / 2, 0, wb, wetl)] if wb else []
    if rng.random() < 0.75:  # a shipping label on the front, half torn
        lx, ly = rng.uniform(-0.3, 0.3) * W, H * rng.uniform(0.45, 0.62)
        label = _look(_tone((176, 172, 160), rng, 8, 0.1), "SmoothPlastic", "Label")
        front_inl.append((lx - 0.28, lx + 0.28, ly - 0.2, ly + 0.2, label))
        front_inl.append((lx - 0.28, lx - 0.05, ly + 0.08, ly + 0.2, _look(_tone(col, rng, 4), M, "Cardboard")))
    if state == "crushed":
        cut = H * rng.uniform(0.4, 0.6)
        wall((-W / 2, 0, -Dp / 2), (W / 2, cut, -Dp / 2 + th), (0, 1), [i for i in front_inl if i[3] <= cut])
        g = f.sub((0, cut, -Dp / 2), rx=rng.uniform(12, 18), rz=_tilt(rng, 2, 5))
        g.box("Cardboard", (-W / 2 + th + 0.01, 0, 0), (W / 2 - th - 0.01, H - cut, th), _tone(col, rng, 6, 0.04), M,
              flags=SMALL)
    else:
        wall((-W / 2, 0, -Dp / 2), (W / 2, H, -Dp / 2 + th), (0, 1), front_inl)
    wall((-W / 2, 0, Dp / 2 - th), (W / 2, H, Dp / 2), (0, 1), [(-W / 2, W / 2, 0, wb * 0.8, wetl)] if wb else [])
    for s in (-1, 1):  # the ends: hand holes, the tape down them on a closed box
        inl = [(-Dp / 2, Dp / 2, 0, wb * rng.uniform(0.7, 1.2), wetl)] if wb else []
        if rng.random() < 0.6 or state == "closed":
            hy = H - 0.42
            inl.append((-0.22, 0.22, hy, hy + 0.1, hole))
        if state == "closed":
            inl.append((-tw, tw, H - 0.26, H, tape))
        x0 = -W / 2 if s < 0 else W / 2 - th
        wall((x0, 0, -Dp / 2 + th), (x0 + th, H, Dp / 2 - th), (2, 1), inl, dark=0.05)
    if state == "closed":
        # the two long flaps meet on the seam under the tape (all one flush lid)
        _slab(f, (-W / 2, H, -Dp / 2), (W / 2, H + th, Dp / 2), (0, 2), _look(_tone(col, rng, 4), M, "Cardboard"),
              [(-W / 2, W / 2, -tw, tw, tape)], flags=SMALL)
    elif state == "crushed":
        # the lid sags into the box, toward the caved wall, its tape still on
        g = f.sub((0, H, Dp / 2), rx=rng.uniform(24, 30), rz=rng.uniform(-6, 6))
        _slab(g, (-W / 2 + 0.03, 0, -Dp), (W / 2 - 0.03, th, 0), (0, 2), _look(_tone(col, rng, 5), M, "Cardboard"),
              [(-W / 2, W / 2, -Dp / 2 - tw, -Dp / 2 + tw, tape)], flags=SMALL)
    else:
        missing = rng.randrange(4)
        for i, (hinge, rot_axis, centre, size) in enumerate((
                ((0, H, -Dp / 2), "x-", (0, 0, Dp * 0.24), (W - 0.04, th, Dp * 0.48)),
                ((0, H, Dp / 2), "x+", (0, 0, -Dp * 0.24), (W - 0.04, th, Dp * 0.48)),
                ((-W / 2, H, 0), "z+", (W * 0.22, 0, 0), (W * 0.44, th, Dp - 0.16)),
                ((W / 2, H, 0), "z-", (-W * 0.22, 0, 0), (W * 0.44, th, Dp - 0.16)))):
            if i == missing and rng.random() < 0.6:
                continue
            ang = rng.uniform(100, 165) if rng.random() < 0.8 else rng.uniform(25, 50)  # splayed / drooping in
            sgn = -1 if rot_axis[1] == "-" else 1
            if rot_axis[0] == "x":
                g = f.sub(hinge, rx=sgn * ang, rz=rng.uniform(-6, 6))
            else:
                g = f.sub(hinge, rz=sgn * ang, rx=rng.uniform(-6, 6))
            g.part("Flap", centre, size, _tone(col, rng, 7, 0.03), M, flags=DECOR_SHADOW)


@prop({"kind": "packet"}, {"kind": "takeaway"}, {"kind": "cup"}, {"kind": "foil"}, {"kind": "can"})
def wrapper(D, folder, origin, ry, rng, kind=None):
    """Food litter: a crushed crisp packet (pillowed, crimped silver seals), an open foam takeaway
    clamshell (a hollow tray with leftovers, its lid thrown back), a paper coffee cup lying on its
    side (the dark mouth, the sleeve; its lid beside it, a dried spill), a crumpled foil ball, or a
    drink can (lying, or stamped flat with a kink). Footprint 0.3-1.2 studs. 2-9 parts, DECOR."""
    f0 = Frame(D, folder, origin, ry=ry)  # (the floor: its decals go on the floor's level)
    f = _on_decals(D, folder, origin, ry)
    kind = kind or _pick(rng, ["packet", "packet", "takeaway", "cup", "foil", "can", "can"])
    if kind == "packet":
        col = _tone(_pick(rng, FLYER), rng, 12, darken=rng.uniform(0.05, 0.3))
        tw = rng.uniform(8, 25)
        f.part("Wrapper", (-0.02, 0.06, -0.12), (0.5, 0.11, 0.3), col, "Plastic", flags=DECOR,
               rot=(_tilt(rng, 3, 6), 0, _tilt(rng, 3, 7)), reflectance=0.08)
        f.part("Wrapper", (0.02, 0.065, 0.12), (0.48, 0.12, 0.3), _tone(col, rng, 8), "Plastic", flags=DECOR,
               rot=(_tilt(rng, 8, 12), tw, _tilt(rng, 9, 13)), reflectance=0.08)
        for e in (-1, 1):  # crimped seals, silver
            f.part("Seal", (0, 0.04, e * 0.31), (0.54, 0.05, 0.08), (150, 150, 146), "Metal", flags=DECOR,
                   rot=(e * rng.uniform(4, 15), tw * (0.5 + e * 0.5), 0))
    elif kind == "takeaway":
        # a 0.78 x 0.5 clamshell: a hollow tray (floor and four thin walls), leftovers in it
        foam = _tone(FOAM, rng, 6, darken=rng.uniform(0.05, 0.3))
        W, Dp, h, t, tb = 0.78, 0.5, 0.15, 0.03, 0.065
        f.box("Takeaway", (-W / 2, 0, -Dp / 2 + t), (W / 2, tb, Dp / 2 - t), _tone(foam, rng, 3, 0.05),
              "SmoothPlastic", flags=DECOR)
        for e in (-1, 1):  # the long walls flare out 6 deg (moulding draft: and no face of theirs is
            # parallel to the end walls' edges hidden behind them)
            g = f.sub((0, 0, e * (Dp / 2 - t)), rx=e * 6)
            g.box("Takeaway", (-W / 2, 0, -t / 2 + e * t / 2), (W / 2, h, t / 2 + e * t / 2), foam, "SmoothPlastic",
                  flags=DECOR)
        for s in (-1, 1):
            x0 = -W / 2 if s < 0 else W / 2 - t
            f.box("Takeaway", (x0, tb, -Dp / 2 + t), (x0 + t, h, Dp / 2 - t), _tone(foam, rng, 3), "SmoothPlastic",
                  flags=DECOR)
        for _ in range(rng.randint(1, 2)):  # cold leftovers, lumpy
            f.part("Leftovers", (rng.uniform(-0.18, 0.18), tb + 0.03, rng.uniform(-0.08, 0.08)),
                   (rng.uniform(0.18, 0.3), 0.08, rng.uniform(0.14, 0.22)), _tone(_pick(rng, FOOD), rng, 8), "Sand",
                   flags=DECOR, rot=(rng.uniform(-12, 12), rng.uniform(0, 180), rng.uniform(-12, 12)))
        # the lid on its hinge (the back edge): thrown back past flat, its dome down
        g = f.sub((0, h, Dp / 2), rx=rng.uniform(150, 172), rz=rng.uniform(-6, 6))
        g.box("Lid", (-W / 2, 0, -Dp), (W / 2, 0.09, 0), _tone(foam, rng, 6), "SmoothPlastic", flags=DECOR)
        _disk(f0, "Grease", rng.uniform(-0.2, 0.2), -Dp / 2 - 0.3, 0.42, DECAL_TH, OIL, "SmoothPlastic",
              transparency=0.55)
    elif kind == "cup":
        # a takeaway coffee cup (8 cm mouth, 11 cm tall) on its side, its plastic lid still on
        # (the lid 2 cm deep, a little wider), the cardboard sleeve; a dried coffee spill
        col = _tone((176, 170, 158), rng, 8, darken=rng.uniform(0, 0.25))
        d = 0.25
        _disk(f0, "Spill", -0.55, rng.uniform(-0.15, 0.15), rng.uniform(0.45, 0.7), DECAL_TH, (44, 32, 22),
              "SmoothPlastic", transparency=0.45)
        g = f.sub((0, d / 2, 0), ry=rng.uniform(-20, 20))
        _cyl(g, "Cup", (0, 0, 0), 0.36, d, col, "SmoothPlastic")
        _cyl(g, "CupLid", (-0.18 - 0.0325, 0, 0), 0.065, d + 0.02, _pick(rng, [(36, 36, 38), (196, 194, 188)]),
             "Plastic")
        _cyl(g, "Sleeve", (0.03, 0, 0), 0.15, d + 0.02, _tone(CARDBOARD, rng, 8), CARDBOARD_MAT)
    elif kind == "can":
        # a 330 ml can (6.6 x 12 cm) on its side, or stamped flat and kinked; its silver
        # shoulders and ends butted to the painted body (end faces >= 0.06 apart)
        col = _tone(_pick(rng, CAN), rng, 10, darken=rng.uniform(0.05, 0.35))
        d = 0.22
        if rng.random() < 0.5:
            g = f.sub((0, d / 2, 0))
            _cyl(g, "Can", (0, 0, 0), 0.28, d, col, "Metal", reflectance=0.08)
            for e in (-1, 1):
                _cyl(g, "CanEnd", (e * 0.1725, 0, 0), 0.065, d * 0.94, (150, 150, 148), "Metal")
        else:
            kink = rng.uniform(12, 30)
            for e in (-1, 1):
                g = f.sub((0, 0.05, 0), rz=e * kink * 0.5)
                g.part("Can", (e * 0.1, 0, 0), (0.2, 0.08, d * 1.25), col if e < 0 else _tone(col, rng, 6), "Metal",
                       flags=DECOR, rot=(rng.uniform(-6, 6), 0, 0), reflectance=0.08)
    else:
        s = rng.uniform(0.2, 0.28)
        _ball(f, "Foil", (0, s * 0.42, 0), s, (150, 150, 148), "Metal", reflectance=0.1)
        for _ in range(2):
            a = rng.uniform(0, 2 * math.pi)
            dd = s * rng.uniform(0.5, 0.7)
            _ball(f, "Foil", (math.cos(a) * s * 0.36, dd * 0.45, math.sin(a) * s * 0.36), dd, (138, 138, 136), "Metal")


@prop({}, {"count": 7})
def cigarette_butts(D, folder, origin, ry, rng, count=None, radius=0.7, ash=True):
    """Cigarette butts where someone stood and smoked, over a light grey ash smudge: real size
    (8 mm thick, 5-8 cm long: 0.03 x 0.17-0.27 studs), a cork or white filter and what is left of
    the paper, the black burnt end; some bent where they were stubbed out.
    Footprint ~1.4 studs. 5-20 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    n = count or rng.randint(3, 6)
    ar = radius * rng.uniform(1.3, 1.6)  # (its diameter: most butts lie on it)
    ash = _disk(f, "Ash", 0, 0, ar, DECAL_TH, (104, 102, 98), "Sand", transparency=0.75) if ash else None
    top = _top(f, ash)
    d = 0.03
    spots = []
    for i in range(n):
        r = radius * math.sqrt(rng.random())
        a = rng.uniform(0, 2 * math.pi)
        x, z = math.cos(a) * r, math.sin(a) * r
        if any(math.hypot(x - px, z - pz) < 0.3 for px, pz in spots):
            continue  # (two butts never lie through each other)
        spots.append((x, z))
        y = (top if (ash is not None and r < ar * 0.45) else _rest(f, x, z)) + d / 2
        if not _free(f, x, y, z):
            continue  # (not inside the gutter, a crate...)
        cork = rng.random() < 0.7
        filt = _tone((176, 134, 84) if cork else (196, 192, 182), rng, 8, darken=rng.uniform(0, 0.3))
        paper = _tone((196, 192, 184), rng, 6, darken=rng.uniform(0.05, 0.3))
        fl = rng.uniform(0.07, 0.09)
        pl = rng.uniform(0.07, 0.18) if i else rng.uniform(0.2, 0.26)  # (one barely smoked)
        g = f.sub((x, y, z), ry=rng.uniform(0, 360))
        _cyl(g, "Butt", (-fl / 2, 0, 0), fl, d, filt, "SmoothPlastic")
        bent = rng.random() < 0.35
        h = g.sub((0, 0, 0), ry=rng.uniform(20, 40) * rng.choice((-1, 1))) if bent else g
        _cyl(h, "Butt", (pl / 2, 0, 0), pl, d * 0.97, paper, "SmoothPlastic")
        if rng.random() < 0.6:  # the charred end (2 cm of ash: its face 0.065 past the paper's)
            _cyl(h, "ButtAsh", (pl + 0.0325, 0, 0), 0.065, d * 0.9, (40, 38, 36), "Sand")


@prop({}, {"width": 5, "depth": 2.4}, {"corner": True})
def leaves_drift(D, folder, origin, ry, rng, width=None, depth=None, corner=False, wet=None):
    """Dead leaves blown against a wall (the wall on +Z; the prop finds its face up to 1.6 studs
    past its own depth and builds nothing inside it, nor inside anything else there): a drift of
    loose leaves, real size (5-13 cm), flat or curled, in every shade of brown, overlapping in
    layers: heaped against the wall over a low core of rotted leaves (a wedge of the same brown,
    hidden under them) and thinning out to a few strays; `corner` piles them toward the -X end.
    Footprint width 2.5-5 x depth 1.4-2.6 studs. 30-60 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    W = width or rng.uniform(2.6, 4.2)
    Dp = depth or rng.uniform(1.4, 2.2)
    wet = (rng.random() < 0.4) if wet is None else wet
    back = _wall_face(f, 0, reach=Dp / 2 + 1.6)
    if back is None:
        back = Dp / 2  # (free standing: the footprint centred on the origin, its back edge at +Z)
    cx = -W * 0.18 if corner else 0.0
    cw = W * (0.6 if corner else 0.8)
    hm, dm = rng.uniform(0.09, 0.14), rng.uniform(0.5, 0.75)
    core = _tone(mix(LEAF[0], LEAF[5], 0.5), rng, 4, darken=0.2 if wet else 0.05)
    heap = all(_free(f, px, 0.05, pz) for px, pz in _rect_pts(cx, back - dm / 2, cw, dm, 0))
    if heap:
        f.part("Mulch", (cx, hm / 2, back - dm / 2), (cw, hm, dm), core, "Ground", shape=WEDGE, flags=DECOR)
    slope = math.degrees(math.atan2(hm, dm))
    n = int(rng.uniform(5, 6) * W * Dp) + 10
    n = max(30, min(n, 48))
    for i in range(n):
        if heap and i < n * 0.6:  # most of them heaped on the core, in layers, hiding it
            x = cx + rng.uniform(-0.5, 0.5) * cw
            dz = rng.uniform(0.05, dm * 1.05)
            y = max(0.0, hm * (1 - dz / dm)) + rng.uniform(0.0, 0.03)
            z = back - dz
            g = f.sub((x, y, z), rx=-slope if dz < dm else 0)
            if _free(f, x, hm + 0.05, z):  # (above the core: zlayers sees a wedge as its box)
                _leaf(g, 0, 0, 0, rng, wet=wet, size=1.25)
            continue
        dz = Dp * (rng.random() ** 1.5)  # (the rest thinning out away from the wall)
        z = back - 0.08 - dz
        x = (-W / 2 + (rng.random() ** 1.6) * W) if corner else rng.uniform(-W / 2, W / 2)
        y = _rest(f, x, z)
        if not _free(f, x, y + 0.05, z):
            continue  # (not inside a step, a wall, a crate)
        _leaf(f, x, y, z, rng, wet=wet, size=1.25)


@prop({}, {"length": 8})
def wall_base_grime(D, folder, origin, ry, rng, length=None):
    """The dirty foot of a wall (the wall on +Z, running along X; the prop finds the wall's face up
    to 1.2 studs behind the origin and builds nothing inside it): a low continuous fillet of silt
    in the corner (one even profile, its stretches butted, some mossy), a soft damp band on the
    floor in front of it (a dark strip then a fainter one with a ragged outer edge), grit and
    gravel, leaves caught on the silt, maybe a scrap of paper leaning on the wall. Where the wall
    has a gap (a doorway) that stretch stays clean. Footprint length 3-30 x 1-1.6 studs.
    ~2 parts per stud, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    L = length or rng.uniform(4, 8)
    n = max(1, round(L / rng.uniform(1.8, 2.6)))
    seg = L / n
    xs = [-L / 2 + seg * (i + 0.5) for i in range(n)]
    faces = [_wall_face(f, x, reach=1.2) for x in xs]
    if all(z is None for z in faces):
        faces = [0.0] * n  # (no wall: the origin is on its face)
    hs, ds = rng.uniform(0.05, 0.075), rng.uniform(0.32, 0.45)
    silt = _tone(mix(SOIL, SOIL_DARK, rng.uniform(0.2, 0.6)), rng, 4)
    d1 = rng.uniform(0.28, 0.38)
    for x, zf in zip(xs, faces):
        if zf is None:
            continue
        col = _tone(silt, rng, 3)
        if rng.random() < 0.25:
            col = mix(col, _pick(rng, MOSS), 0.5)  # a mossy stretch
        f.part("Silt", (x, hs / 2, zf - ds / 2), (seg, hs, ds), col, "Ground", shape=WEDGE, flags=DECOR)
        d2 = rng.uniform(0.1, 0.55)  # (its outer edge ragged from one stretch to the next)
        for zc, dd, tr in ((zf - ds - d1 / 2, d1, 0.42), (zf - ds - d1 - d2 / 2, d2, 0.7)):
            # (a strip that would run under something standing at the wall foot is cut in three
            # and only its free pieces are kept)
            if all(_free(f, px, 0.03, pz) for px, pz in _rect_pts(x, zc, seg, dd, 0)):
                _flat(f, "Damp", x, zc, seg, dd, DECAL_TH, DAMP, "Concrete", transparency=tr, fit=False)
                continue
            for k in (-1, 0, 1):
                xk = x + k * seg / 3
                if all(_free(f, px, 0.03, pz) for px, pz in _rect_pts(xk, zc, seg / 3, dd, 0)):
                    _flat(f, "Damp", xk, zc, seg / 3, dd, DECAL_TH, DAMP, "Concrete", transparency=tr, fit=False)
    walls = [(x, zf) for x, zf in zip(xs, faces) if zf is not None]
    if not walls:
        return
    slope = math.degrees(math.atan2(hs, ds))
    for _ in range(int(L * rng.uniform(0.3, 0.5))):  # grit and gravel washed against the silt
        x0, zf = _pick(rng, walls)
        s = rng.uniform(0.06, 0.15)
        gx, gz = x0 + rng.uniform(-seg, seg) / 2, zf - ds - rng.uniform(0.03, d1)
        if not _free(f, gx, 0.1, gz):
            continue
        f.part("Grit", (gx, _rest(f, gx, gz) + s * 0.2, gz),
               (s, s * 0.6, s * 0.8), _tone(_pick(rng, [CONCRETE_OLD, DUST, CINDER]), rng, 8, 0.1), "Pebble",
               flags=DECOR, rot=(_tilt(rng, 5, 30), rng.uniform(0, 180), _tilt(rng, 5, 30)))
    for _ in range(int(L * rng.uniform(0.25, 0.45))):  # leaves caught on the silt
        x0, zf = _pick(rng, walls)
        dz = rng.uniform(0.08, ds * 0.85)
        lx = x0 + rng.uniform(-seg, seg) / 2
        if not _free(f, lx, hs * (1 - dz / ds) + 0.05, zf - dz):
            continue
        g = f.sub((lx, hs * (1 - dz / ds), zf - dz), rx=-slope)
        _leaf(g, 0, 0, 0, rng, tilt=14, col=_tone(_pick(rng, LEAF), rng, 10, darken=0.25))
    if rng.random() < 0.5:  # a scrap of paper blown against the wall, leaning on it
        x0, zf = _pick(rng, walls)
        lp, phi = rng.uniform(0.32, 0.42), rng.uniform(50, 70)
        zb = zf - 0.02 - lp * math.cos(math.radians(phi))
        g = f.sub((x0 + rng.uniform(-seg, seg) * 0.4, hs * (1 - (zf - zb) / ds) + 0.01, zb), rx=-phi,
                  ry=rng.uniform(-10, 10))
        g.part("Paper", (0, 0.013, lp / 2), (lp * 0.8, SHEET_TH, lp),
               mix(_pick(rng, PAPER), SOIL, rng.uniform(0.35, 0.55)),
               "SmoothPlastic", flags=DECOR)


@prop({}, {"radius": 2.4, "density": 1.4})
def litter_scatter(D, folder, origin, ry, rng, radius=None, density=1.0):
    """A natural spread of small litter over an area, thicker toward its +Z side (where it
    piles against a wall): crumpled paper, a sheet or a flyer, crisp packets, a cup, cans, a few
    butts, leaves; each piece a real thing at real size, never two in the same spot, no two
    spreads with the same mix. Footprint 2-5 studs across. 6-60 parts (a cluster of litter props),
    DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    R = radius or rng.uniform(1.6, 2.6)
    n = max(4, int(R * R * 1.6 * density))
    weights = {"ball": rng.uniform(2, 4), "sheet": rng.uniform(1, 2.5), "packet": rng.uniform(1, 2.5),
               "can": rng.uniform(0.5, 2), "cup": rng.uniform(0, 1), "butts": rng.uniform(0.5, 1.5),
               "leaf": rng.uniform(1, 3), "foil": rng.uniform(0, 0.8)}
    total = sum(weights.values())
    reach = {"ball": 0.2, "sheet": 0.62, "packet": 0.32, "can": 0.25, "cup": 0.4, "butts": 0.45, "leaf": 0.18,
             "foil": 0.15}  # (how far each piece spreads from its spot: no two pieces through each other)
    placed = []
    for _ in range(n):
        k = rng.uniform(0, total)
        kind = "ball"
        for kind, wgt in weights.items():  # noqa: B007 (the kind the draw lands on)
            k -= wgt
            if k <= 0:
                break
        for _try in range(8):
            a = rng.uniform(0, 2 * math.pi)
            r = R * math.sqrt(rng.random())
            x, z = math.cos(a) * r, math.sin(a) * r
            if z < 0 and rng.random() < 0.5:
                z = -z  # (more toward the wall side)
            if all(math.hypot(x - px, z - pz) > reach[kind] + pr for px, pz, pr in placed):
                break
        else:
            continue
        if not _free(f, x, 0.1, z):
            continue  # (not inside a wall, a crate, a step)
        placed.append((x, z, reach[kind]))
        o = _w(f, x, z)
        yaw = _yaw(f) + rng.uniform(0, 360)
        if kind == "ball":
            paper_ball(D, folder, o, yaw, rng)
        elif kind == "sheet":
            paper_sheet(D, folder, o, yaw, rng, kind=_pick(rng, ["sheet", "sheet", "flyer"]))
        elif kind in ("packet", "can", "cup", "foil"):
            wrapper(D, folder, o, yaw, rng, kind=kind)
        elif kind == "butts":
            cigarette_butts(D, folder, o, yaw, rng, count=rng.randint(2, 3), radius=0.3, ash=False)
        else:
            _leaf(f, x, max(_rest(f, x, z), _raised(f, [(x, z)], reach=0.2)), z, rng, tilt=12)


# =============================================================================================
# Trash bags
# =============================================================================================
@prop({}, {"torn": True}, {"size": 1.7, "color": (36, 38, 42)}, {"size": 2.5})
def trash_bag(D, folder, origin, ry, rng, size=None, torn=False, color=None):
    """A full bin bag slumped on the floor: lumpy (several bulges, stretched creases), knotted at
    the top with its two ears; `torn` splits it at the front, rubbish spilling out over a dark leak.
    Footprint 1.7-2.6 studs (torn: + 1.5 in front), 1.6-2.3 tall. 7-10 parts (torn 11-30);
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
        x0, _y0, z0, d = lobes[0]
        _ball(f, "BagTear", (x0 + rng.uniform(-0.15, 0.15), d * 0.28, z0 - d * 0.44), d * 0.42, BAG_INSIDE,
              "SmoothPlastic")
        f.part("BagFlap", (x0 + 0.25, d * 0.22, z0 - d * 0.5), (0.5, 0.05, 0.4), col, "Plastic", flags=DECOR,
               rot=(rng.uniform(-50, -30), rng.uniform(-30, 30), 0), reflectance=refl)
        _disk(f, "Leak", rng.uniform(-0.2, 0.2), -d * 0.75, rng.uniform(1.1, 1.6), DECAL_TH, (24, 20, 16),
              "SmoothPlastic", transparency=0.35, reflectance=0.1)
        for i in range(rng.randint(3, 5)):
            px, pz = rng.uniform(-0.8, 0.8), -d * 0.55 - rng.uniform(0.1, 1.2)
            o = _w(f, px, pz)
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
    if kind == "planks":
        kind = "scatter"  # (the name alleys.py uses)
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
        placed = []
        for i in range(rng.randint(3, 5)):
            L = rng.uniform(1.0, 2.6)
            w, th = rng.uniform(0.3, 0.55), rng.uniform(0.1, 0.16)
            col = _tone(_pick(rng, [WOOD_OLD, WOOD_GREY, WOOD, WOOD_DARK]), rng, 8)
            if i == 0:
                col = _tone((64, 86, 70), rng, 6, 0.1)  # an offcut of old green-painted board
            yaw = rng.uniform(0, 180)
            for _try in range(8):  # (lying on the floor, not through each other nor anything there)
                x, z = rng.uniform(-1.4, 1.4), rng.uniform(-1.0, 1.0)
                if all(math.hypot(x - px, z - pz) > (L + pl) / 2 + 0.05 for px, pz, pl in placed) and \
                        all(_free(f, px, 0.06, pz) for px, pz in _rect_pts(x, z, L * 1.05, w + 0.06, yaw)):
                    break
            else:
                continue
            placed.append((x, z, L))
            _plank(f, "Offcut", x, th / 2, z, L, w, th, col, yaw=yaw,
                   broken=rng.choice((-1, 0, 1)), rng=rng)
    else:
        for _ in range(rng.randint(5, 9)):
            L = rng.uniform(0.4, 1.2)
            col = mix(_tone(_pick(rng, [WOOD_OLD, WOOD, WOOD_GREY]), rng, 10), WOOD_FRESH, rng.uniform(0, 0.4))
            f.part("Splinter", (rng.uniform(-0.8, 0.8), 0.1, rng.uniform(-0.6, 0.6)),
                   (L, rng.uniform(0.06, 0.1), rng.uniform(0.08, 0.16)), col, "Wood", flags=DECOR,
                   rot=(_tilt(rng, 2, 8), rng.uniform(0, 180), _tilt(rng, 2, 6)))
        _disk(f, "Sawdust", 0, 0, rng.uniform(1.0, 1.5), DECAL_TH, mix(WOOD_FRESH, DUST, 0.5), "Sand",
              transparency=0.55)


def _pallet_in(f, rng, L, Wd, state):
    """A EUR block pallet in frame f standing on y = 0, its deck boards along X (length L), Wd deep
    along Z (1200 x 800 x 144 mm: 4.0 x 2.67 x 0.48): 3 bottom boards, 9 blocks with the fork
    openings between them on all four sides, 3 cross boards on the blocks, 5 deck boards
    (145 / 100 mm) with gaps. Weathered boards of mismatched tones, one oil-soaked; whole (maybe
    a board missing) or broken (boards missing, one snapped and kicked up, a block crushed).
    Faces only meet back to back (a board on a block), so nothing z-fights. Returns its height."""
    tone = _tone(_pick(rng, PALLET), rng, 10, darken=rng.uniform(0, 0.25))
    bt, bh, bd = 0.073, 0.26, 0.4  # board thickness (22 mm), block height (78 mm), block depth along Z
    zr = (-Wd / 2 + bd / 2, 0.0, Wd / 2 - bd / 2)
    xc = ((-L / 2, -L / 2 + 0.48), (-0.24, 0.24), (L / 2 - 0.48, L / 2))
    for z in zr:  # bottom boards, under each row of blocks
        f.box("PalletBoard", (-L / 2, 0, z - bd / 2), (L / 2, bt, z + bd / 2), _tone(tone, rng, 8, 0.12), "Wood",
              flags=SMALL)
    crushed = rng.randrange(9) if state == "broken" and rng.random() < 0.6 else -1
    k = 0
    for x0, x1 in xc:
        for z in zr:
            col = _tone(tone, rng, 8, 0.15)
            if k == crushed:  # split and squashed: lower, leaning
                f.part("PalletBlock", ((x0 + x1) / 2, bt + bh * 0.42, z), (x1 - x0 - 0.05, bh * 0.84, bd - 0.04), col,
                       "Wood", flags=SMALL, rot=(rng.uniform(-5, 5), 0, rng.uniform(-5, 5)))
            else:
                f.box("PalletBlock", (x0, bt, z - bd / 2), (x1, bt + bh, z + bd / 2), col, "Wood", flags=SMALL)
            k += 1
    y1 = bt + bh
    for x0, x1 in xc:  # cross boards on the blocks
        f.box("PalletBoard", (x0, y1, -Wd / 2), (x1, y1 + bt, Wd / 2), _tone(tone, rng, 8, 0.08), "Wood", flags=SMALL)
    y2 = y1 + bt
    widths = (0.48, 0.33, 0.48, 0.33, 0.48)
    gap = (Wd - sum(widths)) / 4
    missing = set()
    if state == "broken":
        missing = set(rng.sample(range(1, 4), rng.randint(1, 2)))
    elif rng.random() < 0.3:
        missing = {rng.randrange(1, 4)}
    snapped = rng.choice([i for i in range(5) if i not in missing]) if state == "broken" else -1
    oily = rng.randrange(5) if rng.random() < 0.4 else -1
    z = -Wd / 2
    for i, w in enumerate(widths):
        zc = z + w / 2
        z += w + gap
        if i in missing:
            continue
        col = _tone(tone, rng, 12, darken=rng.uniform(0, 0.2))
        if rng.random() < 0.25:
            col = mix(col, WOOD_GREY, 0.5)  # a replaced, sun-greyed board
        if i == oily:
            col = mix(col, (34, 28, 22), 0.55)
        if i == snapped:
            cut = rng.uniform(-0.35, 0.35) * L
            f.box("PalletBoard", (-L / 2, y2, zc - w / 2), (cut - 0.02, y2 + bt, zc + w / 2), col, "Wood", flags=SMALL)
            g = f.sub((cut + 0.02, y2 + bt, zc), rz=rng.uniform(12, 30), ry=rng.uniform(-6, 6))
            g.box("PalletBoard", (0, -bt, -w / 2 + 0.02), (L / 2 - cut - 0.06, 0, w / 2 - 0.02),
                  mix(col, WOOD_FRESH, 0.15), "Wood", flags=DECOR_SHADOW)
        else:
            f.part("PalletBoard", (0, y2 + bt / 2, zc), (L - rng.uniform(0, 0.06), bt, w), col, "Wood", flags=SMALL,
                   rot=(0, rng.uniform(-0.8, 0.8), 0))
    return y2 + bt


@prop({"state": "whole"}, {"state": "broken"}, {"state": "leaning"})
def pallet(D, folder, origin, ry, rng, state=None):
    """A wooden EUR pallet (see _pallet_in): whole but weathered, broken, or leaning against a
    wall (on +Z), stood on its long edge. Footprint 4 x 2.7 studs, 0.48 tall (leaning: 4 x 1,
    2.6 tall). 18-21 parts; boards SMALL (you stand on it)."""
    state = state or _pick(rng, ["whole", "whole", "broken", "leaning"])
    L, Wd = rng.uniform(3.95, 4.1), rng.uniform(2.62, 2.75)
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
    """A stack of 2-4 EUR pallets, each a little off the one below, the top one maybe broken.
    Footprint 4.4 x 3 studs, 0.48 per pallet. 36-84 parts, SMALL (climbable)."""
    f = Frame(D, folder, origin, ry=ry)
    n = count or rng.randint(2, 3)
    y = 0.0
    for i in range(n):
        g = f.sub((rng.uniform(-0.2, 0.2), y, rng.uniform(-0.15, 0.15)), ry=rng.uniform(-6, 6))
        y += _pallet_in(g, rng, rng.uniform(3.95, 4.1), rng.uniform(2.62, 2.75),
                        "broken" if (i == n - 1 and rng.random() < 0.5) else "whole")


@prop({}, {"count": 9})
def plank_stack(D, folder, origin, ry, rng, count=None):
    """Old lumber stacked on two bearers: rows of weathered boards of mixed sizes (2x6, 2x4,
    1x6, a scaffold board) side by side with small gaps, each row square on the one below, the
    ends staggered; the last one or two thrown on top askew, one of them snapped.
    Footprint 6-7.4 x 2.6 studs, 0.45-0.9 tall. 9-16 parts, SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    n = count or rng.randint(6, 9)
    for e in (-1, 1):
        f.part("Bearer", (e * 1.8, 0.15, 0), (0.3, 0.3, 2.4), _tone(WOOD_DARK, rng, 8), "Wood", flags=SMALL,
               rot=(0, rng.uniform(-3, 3), 0))

    def col():
        return _tone(_pick(rng, [WOOD_OLD, WOOD_GREY, WOOD, WOOD_GREY]), rng, 8, darken=rng.uniform(0, 0.2))

    y = 0.3
    loose = 1 if n < 8 else 2
    left = n - loose
    while left > 0:
        th = _pick(rng, [0.13, 0.13, 0.08])
        row, z = [], 0.0
        while left > 0:
            w = _pick(rng, [0.3, 0.47, 0.47, 0.62])
            if z + w > 2.3:
                break
            row.append((z + w / 2, w))
            z += w + rng.uniform(0.03, 0.08)
            left -= 1
        if not row:
            break
        off = -(z - 0.05) / 2
        for zc, w in row:
            x, L = rng.uniform(-0.4, 0.4), rng.uniform(5.4, 7.2)
            for _try in range(6):  # (not into a bag or a heap standing at its end)
                if all(_free(f, x + e * L / 2, y + th / 2, zc + off) for e in (-1, 1)):
                    break
                L *= 0.9
                x *= 0.5
            _plank(f, "Plank", x, y + th / 2, zc + off, L, w, th, col(), flags=SMALL, rng=rng)
        y += th
    for i in range(loose):  # thrown on top, askew; the last one snapped
        th = 0.13
        _plank(f, "Plank", rng.uniform(-0.6, 0.6), y + th / 2, rng.uniform(-0.5, 0.5), rng.uniform(4.6, 6.6),
               _pick(rng, [0.3, 0.47]), th, col(), yaw=rng.uniform(6, 16) * rng.choice((-1, 1)),
               broken=(rng.choice((-1, 1)) if i == loose - 1 else 0), flags=SMALL, rng=rng)
        y += th


# =============================================================================================
# Masonry and concrete: cinder blocks, bricks, chunks, rubble, rebar
# =============================================================================================
def _cinder_in(f, rng, col, half=False, chip=False):
    """A hollow concrete block (390 x 190 x 190 mm: 1.3 x 0.65 x 0.65) in frame f on y = 0: two
    face shells, the end webs and a thinner middle web around the two cores. `chip`: a corner
    knocked off the top of the front shell. A half block has a rough broken end: its shells
    snapped at different lengths, no web there, the pale inside showing."""
    L = 0.68 if half else 1.3
    H, Wd, t, tm = 0.65, 0.65, 0.12, 0.09
    fs = _tone(col, rng, 5)
    if chip and not half:
        c = rng.uniform(0.12, 0.22)
        f.box("CinderBlock", (-L / 2 + c, 0, -Wd / 2), (L / 2, H, -Wd / 2 + t), fs, "Concrete", flags=SMALL)
        f.box("CinderBlock", (-L / 2, 0, -Wd / 2), (-L / 2 + c, H - rng.uniform(0.07, 0.14), -Wd / 2 + t),
              mix(fs, CONCRETE_FRESH, 0.25), "Concrete", flags=SMALL)
    elif half:
        f.box("CinderBlock", (-L / 2, 0, -Wd / 2), (L / 2, H, -Wd / 2 + t), fs, "Concrete", flags=SMALL)
    else:
        f.box("CinderBlock", (-L / 2, 0, -Wd / 2), (L / 2, H, -Wd / 2 + t), fs, "Concrete", flags=SMALL)
    lb = L - (rng.uniform(0.07, 0.15) if half else 0.0)
    f.box("CinderBlock", (-L / 2, 0, Wd / 2 - t), (-L / 2 + lb, H, Wd / 2), _tone(col, rng, 5), "Concrete", flags=SMALL)
    webs = [(-L / 2, -L / 2 + t)] if half else [(-L / 2, -L / 2 + t), (-tm / 2, tm / 2), (L / 2 - t, L / 2)]
    for x0, x1 in webs:
        f.box("CinderBlock", (x0, 0, -Wd / 2 + t), (x1, H, Wd / 2 - t), _tone(col, rng, 5, 0.04), "Concrete",
              flags=SMALL)
    if half:  # a stub of the broken middle web, pale and jagged
        f.part("BrokenFace", (L / 2 - 0.06, H * 0.42, 0.02), (0.1, H * 0.7, Wd - 2 * t - 0.04),
               mix(col, CONCRETE_FRESH, 0.5), "Concrete", flags=DECOR,
               rot=(rng.uniform(-8, 8), rng.uniform(-14, 14), rng.uniform(-10, 10)))


@prop({"state": "flat"}, {"state": "side"}, {"state": "broken"}, {"state": "stack"})
def cinder_block(D, folder, origin, ry, rng, state=None):
    """A hollow concrete (cinder) block: lying flat (cores up, maybe a chipped corner and a crust
    of old mortar), on its side (cores showing), broken in half with a pale break and a chip,
    or a small stack of 3-5 in half bond (the lower course dirtier, one knocked off beside it).
    Footprint 1.3 x 0.65 studs (stack ~2.8 x 2). 5-8 parts (stack 15-35), SMALL."""
    state = state or _pick(rng, ["flat", "side", "broken"])
    f = Frame(D, folder, origin, ry=ry)
    col = _tone(_pick(rng, [CINDER, CONCRETE, CONCRETE_OLD]), rng, 6, darken=rng.uniform(0, 0.15))
    if state == "flat":
        _cinder_in(f, rng, col, chip=rng.random() < 0.5)
        if rng.random() < 0.4:  # a lump of old mortar stuck on top
            f.part("Mortar", (rng.uniform(-0.4, 0.4), 0.67, -0.27), (0.3, 0.06, 0.1), _tone(MORTAR, rng, 6), "Concrete",
                   flags=DECOR, rot=(rng.uniform(6, 14), rng.uniform(-15, 15), rng.uniform(-8, 8)))
    elif state == "side":
        _cinder_in(f.sub((0, 0.325, 0), rx=90).sub((0, -0.325, 0)), rng, col)
    elif state == "broken":
        _cinder_in(f.sub((0, 0, 0), ry=rng.uniform(-10, 10)), rng, col, half=True)
        f.part("Chip", (rng.uniform(0.75, 1.0), 0.1, rng.uniform(-0.4, 0.4)), (0.28, 0.18, 0.24),
               mix(col, CONCRETE_FRESH, 0.3), "Concrete", flags=DECOR,
               rot=(rng.uniform(-30, 30), rng.uniform(0, 90), rng.uniform(-30, 30)))
    else:
        y = 0.0
        rows = rng.randint(2, 3)
        for r in range(rows):
            m = 2 if r < rows - 1 else rng.randint(1, 2)
            for k in range(m):
                x = (k - (m - 1) / 2) * 1.37 + (0.34 if r % 2 else 0) + rng.uniform(-0.03, 0.03)
                g = f.sub((x, y, rng.uniform(-0.03, 0.03)), ry=rng.uniform(-1.5, 1.5))
                _cinder_in(g, rng, _tone(mix(col, SOIL_DARK, 0.25) if r == 0 else col, rng, 6),
                           chip=rng.random() < 0.3)
            y += 0.65
        g = f.sub((rng.uniform(-0.6, 0.6), 0, -1.25), ry=rng.uniform(20, 70))
        _cinder_in(g.sub((0, 0.325, 0), rx=90).sub((0, -0.325, 0)), rng, _tone(col, rng, 6))


def _brick(f, rng, x, y, z, half=False, rot=(0, 0, 0), col=None, mortar=False):
    """A brick (215 x 65 x 102 mm: 0.72 x 0.22 x 0.34, a half bat 0.34 long) centred on (x, y, z),
    turned rot; `mortar`: a crust of old mortar stuck on its top."""
    col = col or _tone(_pick(rng, BRICK), rng, 8, darken=rng.uniform(0, 0.15))
    L = 0.34 if half else 0.72
    g = f.sub((x, y, z), rx=rot[0], ry=rot[1], rz=rot[2])
    g.part("Brick", (0, 0, 0), (L, 0.22, 0.34), col, "Brick", flags=DECOR_SHADOW)
    if mortar:
        g.part("Mortar", (rng.uniform(-L, L) * 0.2, 0.12, rng.uniform(-0.06, 0.06)), (L * 0.5, 0.06, 0.2),
               _tone(MORTAR, rng, 6), "Concrete", flags=DECOR,
               rot=(_tilt(rng, 5, 12), rng.uniform(-20, 20), _tilt(rng, 4, 10)))


@prop({}, {"count": 6})
def loose_bricks(D, folder, origin, ry, rng, count=None):
    """A few loose bricks: whole and half bricks lying flat or on edge, one or two propped on
    another at the angle it really rests at, old mortar crusted on one, red dust around.
    Footprint ~2 studs. 5-10 parts, DECOR_SHADOW."""
    f = Frame(D, folder, origin, ry=ry)
    n = count or rng.randint(3, 6)
    dust = _disk(f, "BrickDust", 0, 0, rng.uniform(1.3, 1.8), DECAL_TH, mix(BRICK[0], DUST, 0.4), "Sand",
                 transparency=0.78)
    base = _top(f, dust)
    flat, spots = [], []
    for i in range(n):
        if flat and rng.random() < 0.35:
            # propped: its low end on the floor, its high end on a flat one's top edge
            bx, bz, byaw = _pick(rng, flat)
            a = math.degrees(math.asin(0.22 / (0.72 * rng.uniform(0.82, 0.95))))
            yaw = byaw + 90 + rng.uniform(-25, 25)
            d = 0.36 * math.cos(math.radians(a)) * 0.6
            cx = bx - math.cos(math.radians(yaw)) * d
            cz = bz + math.sin(math.radians(yaw)) * d
            yc = base + 0.36 * math.sin(math.radians(a)) + 0.11 * math.cos(math.radians(a))
            _brick(f, rng, cx, yc, cz, rot=(0, yaw, a), mortar=(i == 0))
            continue
        for _try in range(8):
            x, z = rng.uniform(-0.9, 0.9), rng.uniform(-0.7, 0.7)
            if all(math.hypot(x - px, z - pz) > 0.8 for px, pz in spots):
                break
        else:
            continue
        spots.append((x, z))
        yaw = rng.uniform(0, 180)
        half = rng.random() < 0.3
        if rng.random() < 0.25:  # on its edge
            _brick(f, rng, x, base + 0.17, z, half=half, rot=(90, yaw, 0))
        else:
            _brick(f, rng, x, base + 0.11, z, half=half, rot=(0, yaw, 0), mortar=(i == 0))
            if not half:
                flat.append((x, z, yaw))


def _chunk(f, rng, x, y, z, s, col, flags=DECOR_SHADOW, rebar=False):
    """An irregular broken lump of concrete: two blocks and a wedge interpenetrating at angles."""
    rot = (rng.uniform(-25, 25), rng.uniform(0, 180), rng.uniform(-25, 25))
    g = f.sub((x, y, z), rx=rot[0], ry=rot[1], rz=rot[2])
    g.part("Chunk", (0, 0, 0), (s, s * rng.uniform(0.45, 0.65), s * rng.uniform(0.6, 0.85)), col, "Concrete",
           flags=flags)
    g.part("Chunk", (s * 0.18, s * 0.08, s * 0.1), (s * 0.7, s * 0.5, s * 0.6), _tone(col, rng, 6, 0.05),
           "Concrete", flags=DECOR, rot=(rng.uniform(15, 40), rng.uniform(20, 50), rng.uniform(-30, 30)))
    g.part("BreakFace", (-s * 0.42, s * 0.12, 0), (s * 0.5, s * 0.35, s * 0.55), mix(col, CONCRETE_FRESH, 0.45),
           "Concrete", shape=WEDGE, flags=DECOR,
           rot=(rng.uniform(8, 20) * rng.choice((-1, 1)), rng.uniform(-30, 30) + 90, rng.uniform(6, 16)))
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
        g = f.sub((0, 0, 0), ry=yaw, rz=_tilt(rng, 2, 5))  # (no two sides parallel)
        g.part("Rubble", (0, hi / 2, -ri / 2), (ri * 1.2, hi, ri),
               _tone(_pick(rng, [DUST, mix(DUST, SOIL, 0.4), CONCRETE_OLD]), rng, 6),
               _pick(rng, ["Pebble", "Ground", "Pebble"]), shape=WEDGE, flags=PROP)
    hmax = max(heights)

    def surf(r):
        return max(0.0, hmax * (1 - r / R))

    # spread dust around the foot
    _disk(f, "Dust", rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), R * 2.5, DECAL_TH, mix(DUST, CONCRETE_FRESH, 0.2),
          "Sand", transparency=0.5)
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
    p = (-L / 2 * 0.8, 0.04, 0.0)
    a = 0.0
    col = _tone(RUST, rng, 8)
    for i in range(n):
        a += math.radians(rng.uniform(-45, 45)) if i else 0
        q = (p[0] + math.cos(a) * seg, 0.04 + (rng.uniform(0.05, 0.25) if i == n - 1 else 0),
             p[2] + math.sin(a) * seg)
        _rod(f, "Rebar", p, q, 0.08, _tone(col, rng, 6), "CorrodedMetal", flags=DECOR_SHADOW, extend=0.05)
        p = q


# =============================================================================================
# Worn urban objects
# =============================================================================================
def _ring(f, rng, R_out, t, W, col, n=16, flags=DECOR_SHADOW, wear=0.25):
    """A tyre ring around the frame's Y axis, centred on its origin: n rubber blocks, each a
    little longer than its share of the ring so the ring is closed; every other one is 0.124
    narrower (W) so the faces of neighbours never share a plane (no z-fighting: their top and
    bottom faces step by 0.062, like the ribs of a sidewall)."""
    rm = R_out - t / 2
    chord = 2 * R_out * math.tan(math.pi / n) + 0.02
    for i in range(n):
        th = 2 * math.pi * i / n
        c = _tone(col, rng, 3)
        if rng.random() < wear:
            c = mix(c, RUBBER_OLD, rng.uniform(0.3, 0.7))
        f.part("Tyre", (math.cos(th) * rm, 0, math.sin(th) * rm), (t, W if i % 2 == 0 else W - 0.124, chord), c,
               "Rubber",
               rot=(0, -math.degrees(th), 0), flags=flags if i % 4 == 0 else DECOR_SHADOW)


@prop({"state": "flat"}, {"state": "leaning"}, {"state": "stack"})
def tyre(D, folder, origin, ry, rng, state=None):
    """An old car tyre: lying flat (wet dirt in its hole), leaning against a wall (on +Z),
    or a stack of 2-3 slightly off each other. Built as a ring of 16 rubber segments, sun-greyed in
    patches. Footprint 2.3 studs (stack ~2.6). 16-17 parts (stack 33-49); some segments SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["flat", "leaning", "stack"])
    R, t, W = rng.uniform(1.05, 1.2), 0.46, rng.uniform(0.62, 0.75)
    col = _tone(RUBBER, rng, 4)
    if state == "flat":
        g = f.sub((0, W / 2, 0), rx=rng.uniform(-3, 3), rz=rng.uniform(-3, 3))
        _ring(g, rng, R, t, W, col, flags=SMALL)
        _disk(f, "TyreDirt", 0, 0, (R - t) * 1.9, DECAL_TH, SOIL_DARK, "Ground", reflectance=0.06)
    elif state == "leaning":
        lean = rng.uniform(12, 22)
        lr = math.radians(lean)
        g = f.sub((0, R * math.cos(lr) + W / 2 * math.sin(lr), R * math.sin(lr)), rx=90 + lean)
        _ring(g, rng, R, t, W, col, flags=SMALL)
    else:
        n = rng.randint(2, 3)
        for i in range(n):
            g = f.sub((rng.uniform(-0.25, 0.25), W / 2 + i * W, rng.uniform(-0.25, 0.25)),
                      rx=rng.uniform(-3, 3), rz=rng.uniform(-3, 3))
            _ring(g, rng, R * rng.uniform(0.95, 1.05), t, W, _tone(col, rng, 4), flags=SMALL)
        _disk(f, "TyreDirt", 0, 0, (R - t) * 1.9, DECAL_TH, SOIL_DARK, "Ground")


@prop({}, {"torn": True})
def cement_bag(D, folder, origin, ry, rng, torn=None):
    """A paper sack of cement, set hard and lumpy: rounded pillow shape, crimped ends, a faded red
    print band; torn, it spills grey powder and hardened lumps. Footprint 1.9 x 1.2 studs, 0.5 tall
    (torn: + 1.2). 6-12 parts; the body is PROP."""
    f0 = Frame(D, folder, origin, ry=ry)
    f = Frame(D, folder, origin, ry=ry, rz=_tilt(rng, 2, 3))
    torn = (rng.random() < 0.5) if torn is None else torn
    L, Wd, h = rng.uniform(1.8, 2.0), rng.uniform(1.1, 1.25), rng.uniform(0.42, 0.52)
    col = _tone((150, 136, 108), rng, 8, darken=rng.uniform(0.05, 0.3))
    # the body with its printed band inlaid (flush), two rolls along its sides, the crimped ends
    _slab(f, (-L * 0.46, 0.0, -(Wd - h) / 2), (L * 0.46, h * 0.96, (Wd - h) / 2), (0, 2),
          _look(col, "Fabric", "CementBag"),
          [(L * 0.04, L * 0.26, -Wd, Wd, _look(mix(col, (122, 56, 44), 0.6), "Fabric", "Print"))], flags=PROP)
    for e in (-1, 1):
        _cyl(f, "CementBag", (0, h / 2, e * (Wd / 2 - h / 2)), L * 0.8, h, _tone(col, rng, 4), "Fabric")
        f.part("BagSeam", (e * L * 0.47, h * 0.35, 0), (0.12, h * 0.6, Wd * 0.95), _tone(col, rng, 6, 0.08),
               "Fabric", flags=DECOR, rot=(0, 0, e * rng.uniform(4, 12)))
    if torn:
        f.part("Tear", (-L * 0.32, h * 0.65, -Wd * 0.3), (0.5, 0.2, 0.35), (60, 56, 50), "Fabric", flags=DECOR,
               rot=(rng.uniform(10, 25) * rng.choice((-1, 1)), rng.uniform(15, 60), rng.uniform(10, 25)))
        powder = _tone((166, 162, 152), rng, 6)
        pi = _disk(f0, "Powder", -L * 0.35, -Wd * 0.85, rng.uniform(1.2, 1.8), DECAL_TH, powder, "Sand")
        for _ in range(2):
            lx, lz = rng.uniform(-1.2, 0.2), -Wd * rng.uniform(0.7, 1.3)
            f0.part("Lump", (lx, _top(f0, pi) if pi else 0.08, lz), (0.3, 0.2, 0.25),
                    _tone(powder, rng, 6, 0.1), "Concrete", flags=DECOR,
                    rot=(_tilt(rng, 5, 20), rng.uniform(0, 90), _tilt(rng, 5, 20)))


@prop({"state": "upright"}, {"state": "upside"}, {"state": "broken"})
def milk_crate(D, folder, origin, ry, rng, state=None):
    """A plastic milk crate (33 x 33 x 28 cm: 1.1 x 1.1 x 0.93), faded and scuffed: round corner
    posts standing a little proud as stacking lugs, a thick top rim, a middle rail and a bottom
    rail on each side, the wall slats set 0.065 back behind the rails (the moulded lattice and its
    depth; and no two faces on one plane), a slotted floor. Upright, upside down (a seat), or
    broken (slats and a rail gone, a piece lying beside it). Footprint 1.1 x 1.1 studs, 0.93
    tall. 18-27 parts; frame SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["upright", "upside", "broken"])
    col = _tone(_pick(rng, CRATE), rng, 8, darken=rng.uniform(0.1, 0.35))
    S, H = 1.1, 0.93
    lift = _raised(f, _rect_pts(0, 0, S, S, 0))
    if lift:
        f = f.sub((0, lift, 0))
    pc = S / 2 - 0.07  # post centres
    lug = 0.065  # posts stand this much proud of the rims, top and bottom
    if state == "upside":
        f = f.sub((0, H, 0), rx=180)
    for sx in (-1, 1):
        for sz in (-1, 1):
            f.part("Crate", (sx * pc, H / 2, sz * pc), (H, 0.14, 0.14), _tone(col, rng, 3), "Plastic",
                   rot=(0, 0, 90), shape=CYLINDER, flags=SMALL)
    broken = set(rng.sample(range(12), 2)) if state == "broken" else set()
    scuffed = rng.randrange(4)
    k = 0
    for y0, hh, t in ((lug, 0.1, 0.05), (H * 0.47, 0.07, 0.05), (H - lug - 0.13, 0.13, 0.07)):
        for side in range(4):
            if k in broken:
                k += 1
                continue
            c = _tone(col, rng, 4)
            if t == 0.07 and side == scuffed:
                c = mix(c, (176, 176, 170), 0.3)  # the top rim scuffed pale where it was dragged
            e = -1 if side % 2 == 0 else 1
            if side < 2:
                z0 = e * S / 2 - (t if e > 0 else 0)
                f.box("Crate", (-pc, y0, z0), (pc, y0 + hh, z0 + t), c, "Plastic", flags=SMALL)
            else:
                x0 = e * S / 2 - (t if e > 0 else 0)
                f.box("Crate", (x0, y0, -pc), (x0 + t, y0 + hh, pc), c, "Plastic", flags=SMALL)
            k += 1
    # the lattice slats, 0.065 behind the rails' faces (>= 0.06: no depth fight)
    ya, yb = lug + 0.1, H - lug - 0.13
    for side in range(4):
        e = -1 if side % 2 == 0 else 1
        for u in (-S / 6, S / 6):
            if state == "broken" and rng.random() < 0.3:
                continue
            c = _tone(col, rng, 4, 0.04)
            z0, z1 = e * (S / 2 - 0.115), e * (S / 2 - 0.065)
            if side < 2:
                f.box("Crate", (u - 0.045, ya, min(z0, z1)), (u + 0.045, yb, max(z0, z1)), c, "Plastic", flags=DECOR)
            else:
                f.box("Crate", (min(z0, z1), ya, u - 0.045), (max(z0, z1), yb, u + 0.045), c, "Plastic", flags=DECOR)
    # the slotted floor (between the bottom rails, its faces clear of theirs)
    for i in range(3):
        z = -S / 2 + 0.05 + 0.04 + i * 0.34
        f.box("CrateFloor", (-S / 2 + 0.11, lug + 0.02, z), (S / 2 - 0.11, lug + 0.07, z + 0.26),
              _tone(col, rng, 5, 0.15), "Plastic", flags=SMALL)
    if state == "broken":
        f.part("CrateBit", (rng.uniform(0.95, 1.3), 0.03, rng.uniform(-0.5, 0.5)), (S * 0.6, 0.05, 0.1), col,
               "Plastic", flags=DECOR, rot=(0, rng.uniform(0, 180), rng.uniform(-6, 6)))


@prop({"state": "standing"}, {"state": "tipped"})
def bucket(D, folder, origin, ry, rng, state=None):
    """An old paint bucket: tapered, rolled rim, wire handle, crusted paint inside and dried drips down
    its side; standing or tipped over with a dried, trodden spill. Footprint 1 studs (tipped 1 x 2),
    1.1 tall. 7-9 parts, SMALL."""
    f = Frame(D, folder, origin, ry=ry)
    state = state or _pick(rng, ["standing", "tipped"])
    paint = _tone(_pick(rng, [PAINT["white"], (150, 150, 140), PAINT["blue"], (120, 110, 90)]), rng, 8, 0.1)
    if state == "tipped":
        # a dried spill, dirtied and trodden: two overlapping blots and a smear
        dried = mix(paint, DUST, rng.uniform(0.3, 0.5))
        _disk(f, "Spill", -0.15, -1.0, rng.uniform(1.0, 1.2), DECAL_TH, dried, "SmoothPlastic", transparency=0.15)
        _flat(f, "Spill", rng.uniform(0.55, 0.75), -1.75, 0.3, 0.8, DECAL_TH, mix(dried, SOIL_DARK, 0.4),
              "SmoothPlastic", yaw=rng.uniform(-30, 30), transparency=0.35)
        f = f.sub((0, 0.46, 0), rx=-90 + rng.uniform(-4, 4)).sub((0, -0.5, 0))
    col = _tone(_pick(rng, [(176, 172, 160), (60, 62, 66), (140, 40, 34)]), rng, 8, darken=rng.uniform(0.1, 0.3))
    _cyl(f, "Bucket", (0, 0.25, 0), 0.5, 0.84, col, "Plastic", rot=(0, 0, 90), flags=SMALL)
    _cyl(f, "Bucket", (0, 0.715, 0), 0.45, 0.92, _tone(col, rng, 4), "Plastic", rot=(0, 0, 90), flags=SMALL)
    _cyl(f, "Rim", (0, 0.975, 0), 0.07, 0.98, _tone(col, rng, 4, 0.1), "Plastic", rot=(0, 0, 90))
    for e in (-1, 1):
        _rod(f, "Handle", (e * 0.47, 0.9, 0), (e * 0.3, 1.2, -0.1), 0.04, IRON, "Metal")
    _rod(f, "Handle", (-0.3, 1.2, -0.1), (0.3, 1.2, -0.1), 0.04, IRON, "Metal")
    f.part("Drip", (0.1, 0.75, -0.465), (0.14, 0.45, 0.05), paint, "SmoothPlastic", flags=DECOR,
           rot=(4, 0, rng.uniform(-3, 3)))


# =============================================================================================
# Floor wear: stains, cracks, potholes, patches, covers, grates, weeds, puddles, marks
# All of it lies flat on the floor as zlayers decals: one layer per place, a glossy core or a
# lid at most on top; details inlaid (_floor_grid) or butted (_line), never stacked.
# =============================================================================================
def _satellite(rng, R, d):
    """A point for a small blot of diameter d just off a round mark of radius R: far enough that
    neither the real disks nor zlayers' square bounds of them overlap (so it stays on the floor
    level, not stacked on the mark)."""
    a = rng.uniform(0, 2 * math.pi)
    r = max(R + d / 2 + 0.03, 0.62 * (2 * R + d)) + rng.uniform(0, 0.4)
    return math.cos(a) * r, math.sin(a) * r


@prop({}, {"size": 1.6})
def oil_stain(D, folder, origin, ry, rng, size=None):
    """A black oil stain soaked into the ground: one dark layer that lets the ground's texture
    through (made opaque with the blended colour), a smaller glossy core where it is still wet,
    and a few drips beside it. Footprint 1.5-5 studs. 1-5 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    s = size or rng.uniform(1.0, 1.6)
    d = s * rng.uniform(1.2, 1.6)
    ox = rng.uniform(-0.2, 0.2) * s
    base = _disk(f, "OilStain", ox, 0, d, DECAL_TH, _tone(OIL, rng, 3), "SmoothPlastic", transparency=0.55,
                 reflectance=0.06)
    if base is None:
        return
    R = f.D.parts[base - 1][8] / 2  # (its diameter after fitting)
    _disk(f, "OilStain", ox + rng.uniform(-0.15, 0.15) * R, rng.uniform(-0.15, 0.15) * R, R * rng.uniform(0.7, 1.0),
          DECAL_TH, OIL, "SmoothPlastic", reflectance=0.2, fit=False)
    for _ in range(rng.randint(0, 3)):
        dd = rng.uniform(0.12, 0.3)
        x, z = _satellite(rng, R, dd)
        _disk(f, "OilDrip", ox + x, z, dd, DECAL_TH, OIL, "SmoothPlastic", transparency=0.3, reflectance=0.1)


@prop({}, {"size": 3.0, "run": True})
def damp_stain(D, folder, origin, ry, rng, size=None, run=None):
    """A damp patch: dark wet ground (one layer, the ground's texture carrying on through it),
    a few smaller wet spots beside it, sometimes a long wet streak running off toward -Z (to a
    drain), starting right at its edge. Footprint 2-6 studs. 1-5 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    s = size or rng.uniform(1.8, 3.0)
    run = (rng.random() < 0.5) if run is None else run
    base = _disk(f, "Damp", 0, 0, s * rng.uniform(0.9, 1.2), DECAL_TH, _tone(DAMP, rng, 4), "Concrete",
                 transparency=0.55)
    if base is None:
        return
    R = f.D.parts[base - 1][8] / 2
    for _ in range(rng.randint(1, 2)):
        dd = R * rng.uniform(0.3, 0.6)
        x, z = _satellite(rng, R, dd)
        if run and z < 0 and abs(x) < R:
            z = -z
        _disk(f, "Damp", x, z, dd, DECAL_TH, _tone(DAMP, rng, 4), "Concrete", transparency=0.65)
    if run:
        ln = s * rng.uniform(1.2, 2.0)
        w = R * rng.uniform(0.25, 0.4)
        yaw = rng.uniform(-12, 12)
        a = math.radians(yaw)
        z0 = -(R + 0.01) - ln / 2  # (its end just touching the patch's edge: no overlap)
        _flat(f, "Damp", math.sin(a) * z0, math.cos(a) * z0, w, ln, DECAL_TH, DAMP, "Concrete", yaw=yaw,
              transparency=0.6)


@prop({}, {"length": 7})
def crack(D, folder, origin, ry, rng, length=None, branches=None):
    """A crack in the ground: a jagged dark line wandering along -Z..+Z, tapering out, with 1-2
    side branches; thin and flush (LINE_TH), its segments butted end to end, so it reads as a
    crack, not a stick lying on the floor. Footprint length 3-8 studs. 4-16 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    L = length or rng.uniform(3, 6)
    n = max(3, int(L / 0.7))
    pts = [(0.0, -L / 2)]
    for i in range(n):
        x, z = pts[-1]
        pts.append((x + rng.uniform(-0.3, 0.3), z + L / n * rng.uniform(0.8, 1.2)))
    w0 = rng.uniform(0.06, 0.09)
    col = _tone(CRACK_DARK, rng, 3)
    _line(f, "Crack", pts, w0, 0.03, col, "SmoothPlastic")
    for _ in range(branches if branches is not None else rng.randint(1, 2)):
        j = rng.randrange(1, len(pts) - 1)
        x, z = pts[j]
        side = rng.choice((-1, 1))
        wj = w0 + (0.03 - w0) * j / max(1, n - 1)
        bp = [(x + side * (wj / 2 + 0.008), z)]  # (starting at the main line's edge, not on it)
        for _k in range(rng.randint(2, 3)):
            x, z = bp[-1][0] + side * rng.uniform(0.35, 0.7), bp[-1][1] + rng.uniform(-0.25, 0.45)
            bp.append((x, z))
        _line(f, "Crack", bp, min(0.05, wj), 0.025, col, "SmoothPlastic")


@prop({}, {"radius": 1.8})
def pothole(D, folder, origin, ry, rng, radius=None):
    """A pothole: a dark wet depression (the broken-down asphalt and mud, one flush layer) with
    muddy water glinting in its bottom, broken chunks of the road's edge lying around and in it,
    tilted down into the hole, short cracks running out from its rim, loose gravel kicked out.
    Footprint 2-4 studs. 13-23 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    R = radius or rng.uniform(1.0, 1.7)
    base = _disk(f, "Pothole", 0, 0, 2 * R, DECAL_TH, _tone((40, 36, 31), rng, 3), "Ground", reflectance=0.03)
    if base is None:
        return
    R = f.D.parts[base - 1][8] / 2
    top = _top(f, base)
    _disk(f, "PotholeWater", rng.uniform(-0.25, 0.25) * R, rng.uniform(-0.25, 0.25) * R, R * rng.uniform(0.7, 1.05),
          DECAL_TH, _tone((30, 31, 32), rng, 3), "SmoothPlastic", reflectance=0.3, fit=False)
    # the road's own surface (what the broken pieces are made of)
    host = zlayers.host_at(D, tuple(float(v) for v in f.world((0, -0.05, 0))))
    road, road_mat = (host[0], host[1]) if host else (ASPHALT_WORN, "Asphalt")
    sides = [rng.uniform(0, 2 * math.pi) for _ in range(rng.randint(1, 2))]
    k = rng.randint(6, 9)
    for i in range(k):  # the broken edge: slabs of the road where it gave way (on one or two sides,
        # straddling the rim and sloping in), a couple fallen into the hole
        a = sides[i % len(sides)] + rng.uniform(-1.1, 1.1)
        r = R * (rng.uniform(0.88, 1.02) if i < k - 2 else rng.uniform(0.3, 0.6))
        sz = (rng.uniform(0.25, 0.55), rng.uniform(0.07, 0.11), rng.uniform(0.25, 0.5))
        f.part("PotholeEdge", (math.cos(a) * r, top + sz[1] * 0.15, math.sin(a) * r), sz,
               _tone(mix(road, (40, 36, 31), rng.uniform(0, 0.35)), rng, 6), road_mat, flags=DECOR,
               rot=(_tilt(rng, 3, 8), -math.degrees(a) + rng.uniform(-25, 25), 7 + 2.5 * i + rng.uniform(0, 1)))
    for _ in range(rng.randint(2, 3)):  # cracks running out of the rim
        a = rng.uniform(0, 2 * math.pi)
        r = R * 1.22  # (clear of zlayers' square bounds of the hollow: on the road's level)
        pts = [(math.cos(a) * r, math.sin(a) * r)]
        for _k in range(rng.randint(1, 2)):
            a += rng.uniform(-0.3, 0.3)
            r += rng.uniform(0.35, 0.7)
            pts.append((math.cos(a) * r, math.sin(a) * r))
        _line(f, "Crack", pts, 0.05, 0.03, CRACK_DARK, "SmoothPlastic")
    for _ in range(rng.randint(2, 4)):
        a = rng.uniform(0, 2 * math.pi)
        r = R * rng.uniform(1.2, 1.8)
        x, z = math.cos(a) * r, math.sin(a) * r
        f.part("Gravel", (x, _rest(f, x, z) + 0.03, z), (0.16, 0.1, 0.13), _tone(road, rng, 10), road_mat,
               flags=DECOR, rot=(_tilt(rng, 5, 20), rng.uniform(0, 90), _tilt(rng, 5, 20)))


@prop({}, {"w": 5, "d": 3})
def asphalt_patch(D, folder, origin, ry, rng, w=None, d=None):
    """A patched repair: a rectangle of newer, blacker asphalt flush with the road, its sealed
    edges a glossy tar band INLAID along its rim, a crack already running out of one corner
    into the old road, crumbs at a chewed corner. Footprint 2.5-6 x 2-4 studs. 6-10 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    W = w or rng.uniform(2.5, 5.0)
    L = d or rng.uniform(2.0, 3.5)
    yaw = rng.uniform(-2, 2)
    sw = rng.uniform(0.1, 0.16)
    tar = _look(TAR, "SmoothPlastic", "Seam", refl=0.12)
    made = _floor_grid(f, 0, 0, W, L, yaw, DECAL_TH, _look(_tone(ASPHALT_NEW, rng, 3), "Asphalt", "Patch"),
                       [(-W / 2, W / 2, -L / 2, -L / 2 + sw, tar), (-W / 2, W / 2, L / 2 - sw, L / 2, tar),
                        (-W / 2, -W / 2 + sw, -L / 2, L / 2, tar), (W / 2 - sw, W / 2, -L / 2, L / 2, tar)], fit=True)
    if not made:
        return
    cx, cz = rng.choice((-1, 1)), rng.choice((-1, 1))
    a = math.radians(yaw)
    px, pz = cx * (W / 2 + 0.06), cz * (L / 2 + 0.06)
    p0 = (px * math.cos(a) + pz * math.sin(a), -px * math.sin(a) + pz * math.cos(a))
    pts = [p0]
    for _ in range(rng.randint(2, 4)):
        pts.append((pts[-1][0] + cx * rng.uniform(0.3, 0.6), pts[-1][1] + cz * rng.uniform(0.1, 0.5)))
    _line(f, "Crack", pts, 0.06, 0.03, CRACK_DARK, "SmoothPlastic")
    for _ in range(rng.randint(1, 3)):
        x, z = -cx * (W / 2 + rng.uniform(0.1, 0.4)), -cz * (L / 2 + rng.uniform(-0.6, 0.2))
        f.part("Gravel", (x, _rest(f, x, z) + 0.03, z), (0.16, 0.09, 0.13), _tone(ASPHALT_WORN, rng, 8), "Asphalt",
               flags=DECOR, rot=(_tilt(rng, 5, 15), rng.uniform(0, 90), _tilt(rng, 5, 15)))


@prop({}, {"square": True})
def manhole(D, folder, origin, ry, rng, diameter=None, square=None):
    """A cast-iron manhole cover set in its frame, flush with the road: square (the cover, the
    3 cm seating gap, the iron frame and the concrete collar all inlaid in one flush layer, the
    two pick holes in the cover) or round (the frame ring, the chequered cover on it with a
    slight lip, the pick holes). Rust tints the frame. Footprint 2.4-3.4 studs. 4-14 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    dm = diameter or rng.uniform(2.0, 2.3)
    square = (rng.random() < 0.5) if square is None else square
    lid = _tone(IRON, rng, 4)
    iron = mix(_tone(IRON, rng, 4), RUST, rng.uniform(0.15, 0.4))
    if square:
        gap, fw, cw = 0.04, 0.16, 0.24
        S = dm + 2 * (gap + fw + cw)
        e1, e2, e3 = dm / 2 + gap + fw, dm / 2 + gap, dm / 2
        hole = _look(TAR, "SmoothPlastic", "PickHole")
        inl = [(-e1, e1, -e1, e1, _look(iron, "CorrodedMetal", "ManholeFrame")),
               (-e2, e2, -e2, e2, _look(TAR, "SmoothPlastic", "ManholeGap")),
               (-e3, e3, -e3, e3, _look(lid, "DiamondPlate", "ManholeCover", refl=0.04))]
        for e in (-1, 1):
            hx = e * dm * 0.36
            inl.append((hx - 0.07, hx + 0.07, -0.035, 0.035, hole))
        _floor_grid(f, 0, 0, S, S, 0.0, DECAL_TH, _look(_tone(CONCRETE_OLD, rng, 6, 0.1), "Concrete", "ManholeCollar"),
                    inl, fit=True)
    else:
        fr = _disk(f, "ManholeFrame", 0, 0, dm + 0.36, DECAL_TH, iron, "CorrodedMetal")
        if fr is None:
            return
        _disk(f, "ManholeCover", 0, 0, dm, DECAL_TH, lid, "DiamondPlate", reflectance=0.04, fit=False)
        for e in (-1, 1):
            _disk(f, "PickHole", e * dm * 0.36, 0, 0.13, DECAL_TH, TAR, "SmoothPlastic", fit=False)


@prop({"kind": "gully"}, {"kind": "channel"})
def drain_grate(D, folder, origin, ry, rng, kind=None):
    """A drain, flush with the floor: a gully grate (square iron frame, bars over the black
    void) or a channel drain along X (a slotted grate); the frame, bars, voids and the wet dark
    surround all inlaid in one layer; leaves and a scrap of paper caught on it.
    Footprint gully 2.5 x 2.2, channel 5-7 x 1.4 studs. 15-40 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["gully", "channel"])
    iron = _tone(IRON, rng, 5)
    fr = 0.12
    if kind == "gully":
        W, L, nb = 1.5, 1.2, 6
    else:
        W, L, nb = rng.uniform(5, 7), 0.6, 0
    halo = 0.35
    inl = [(-W / 2, W / 2, -L / 2, L / 2, _look(mix(iron, RUST, rng.uniform(0.1, 0.4)), "CorrodedMetal", "DrainFrame")),
           (-W / 2 + fr, W / 2 - fr, -L / 2 + fr, L / 2 - fr, _look((8, 8, 8), "SmoothPlastic", "DrainVoid"))]
    bar = _look(mix(iron, RUST, rng.uniform(0, 0.3)), "CorrodedMetal", "DrainBar")
    if kind == "gully":
        pitch = (W - 2 * fr) / nb
        for i in range(1, nb):
            x = -W / 2 + fr + pitch * i
            inl.append((x - 0.045, x + 0.045, -L / 2 + fr, L / 2 - fr, bar))
    else:
        n = int((W - 2 * fr) / 0.45)
        pitch = (W - 2 * fr) / n
        for i in range(1, n):
            x = -W / 2 + fr + pitch * i
            inl.append((x - 0.06, x + 0.06, -L / 2 + fr, L / 2 - fr, bar))
    made = _floor_grid(f, 0, 0, W + 2 * halo, L + 2 * halo, 0.0, DECAL_TH,
                       _look(DAMP, "Concrete", "DrainDamp", tr=0.55), inl, fit=True)
    if not made:
        return
    top = _top(f, made[0])
    for _ in range(rng.randint(2, 4)):
        _leaf(f, rng.uniform(-W, W) * 0.4, top, rng.uniform(-L, L) * 0.35, rng, tilt=10, wet=True)
    if rng.random() < 0.6:
        f.part("Paper", (rng.uniform(-W, W) * 0.3, top + 0.03, rng.uniform(-L, L) * 0.2), (0.5, SHEET_TH, 0.4),
               mix(_pick(rng, PAPER), CARDBOARD_WET, 0.5), "SmoothPlastic", flags=DECOR,
               rot=(rng.uniform(-6, 6), rng.uniform(0, 180), rng.uniform(-6, 6)))


@prop({"kind": "tuft"}, {"kind": "line", "length": 6}, {"kind": "crack", "length": 4})
def weeds(D, folder, origin, ry, rng, kind=None, length=None):
    """Weeds: a tuft growing out of a crack (tapered grass blades leaning out of it, or a
    dandelion-like rosette of leaves flat on the ground), a line of tufts along a wall base over
    a strip of moss in the joint (kind "line", alias "wall": the wall on +Z, along X; the prop
    finds the wall's face and grows at its foot), or tufts following a crack (along Z).
    Dry yellowed blades mixed with green. Footprint tuft 0.6, line/crack length 3-8 studs.
    tuft 4-11, line 10-36, crack 8-30 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["tuft", "tuft", "line"])
    if kind == "wall":
        kind = "line"

    def tuft(x, z, n, hmax, root=True):
        if not _free(f, x, 0.1, z):
            return  # (not inside a heap of leaves, a crate...)
        if root:
            _disk(f, "WeedRoot", x, z, rng.uniform(0.22, 0.36), DECAL_TH, _tone(mix(SOIL_DARK, MOSS[0], 0.4), rng, 5),
                  "Ground")
        if rng.random() < 0.3:  # a rosette: broad leaves lying almost flat, tips curling up
            m = rng.randint(4, 6)
            for i in range(m):
                a = i * 360 / m + rng.uniform(-12, 12)
                ln = rng.uniform(0.2, 0.34)
                g = f.sub((x, 0.07, z), ry=a, rx=8 + 3.5 * i + rng.uniform(-1, 1))
                g.part("Weed", (0, 0, -ln / 2), (ln * 0.32, 0.02, ln), _tone(_pick(rng, GRASS[:2]), rng, 8), "Grass",
                       flags=DECOR)
            return
        for i in range(n):  # tapered blades (a wedge: wide at the root, a point at the tip), fanning out
            h = hmax * rng.uniform(0.45, 1.0)
            g = f.sub((x + rng.uniform(-0.06, 0.06), 0.03, z + rng.uniform(-0.06, 0.06)),
                      ry=i * 360 / n + rng.uniform(-25, 25), rz=rng.uniform(8, 38), rx=_tilt(rng, 2, 8))
            col = _tone(_pick(rng, GRASS), rng, 8, darken=rng.uniform(0, 0.2))
            g.part("Weed", (0, h / 2, 0), (0.02, h, rng.uniform(0.09, 0.17)), col, "Grass", shape=WEDGE, flags=DECOR)

    if kind == "tuft":
        tuft(0, 0, rng.randint(7, 11), rng.uniform(0.5, 1.0))
    elif kind == "line":
        L = length or rng.uniform(3, 7)
        n = max(1, round(L / 2.4))
        seg = L / n
        xs = [-L / 2 + seg * (i + 0.5) for i in range(n)]
        faces = [_wall_face(f, x, reach=1.2) for x in xs]
        if all(z is None for z in faces):
            faces = [0.0] * n
        for x0, zf in zip(xs, faces):
            if zf is None:
                continue
            _flat(f, "Moss", x0, zf - 0.12, seg, 0.24, DECAL_TH, _tone(mix(_pick(rng, MOSS), SOIL_DARK, 0.35), rng, 6),
                  "Grass", fit=False)
            x = x0 - seg / 2 + rng.uniform(0.1, 0.5)
            while x < x0 + seg / 2:
                tuft(x, zf - rng.uniform(0.1, 0.2), rng.randint(5, 8), rng.uniform(0.4, 0.85), root=False)
                x += rng.uniform(0.6, 1.4)
    else:
        L = length or rng.uniform(3, 6)
        z = -L / 2
        while z < L / 2:
            tuft(rng.uniform(-0.1, 0.1), z, rng.randint(4, 6), rng.uniform(0.3, 0.65))
            z += rng.uniform(0.8, 1.6)


@prop({}, {"radius": 2.0})
def puddle(D, folder, origin, ry, rng, radius=None, debris=None):
    """A standing puddle: the damp ground soaking out around it (one layer, the ground's texture
    through it), the water on it (glossy, dark: it reflects), one or two small pools beside the
    main one, maybe a leaf floating. Footprint 1.5-5 studs. 2-6 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    R = radius or rng.uniform(0.9, 1.6)
    rim = _disk(f, "PuddleRim", 0, 0, R * rng.uniform(2.6, 3.0), DECAL_TH, DAMP, "Concrete", transparency=0.55)
    if rim is None:
        return
    Rr = f.D.parts[rim - 1][8] / 2
    Rw = Rr * rng.uniform(0.55, 0.65)
    water = _tone(WATER, rng, 4)
    _disk(f, "PuddleWater", 0, 0, 2 * Rw, DECAL_TH, water, "SmoothPlastic", reflectance=0.35, fit=False)
    for _ in range(rng.randint(0, 2)):
        dd = Rw * rng.uniform(0.35, 0.6)
        x, z = _satellite(rng, Rw, dd)
        if math.hypot(x, z) + dd / 2 < Rr * 0.95:
            _disk(f, "PuddleWater", x, z, dd, DECAL_TH, water, "SmoothPlastic", reflectance=0.35, fit=False)
    debris = (rng.random() < 0.5) if debris is None else debris
    if debris:
        x, z = rng.uniform(-0.4, 0.4) * Rw, rng.uniform(-0.3, 0.3) * Rw
        _leaf(f, x, _rest(f, x, z), z, rng, tilt=4, wet=True)


@prop({"kind": "survey"}, {"kind": "chalk"}, {"kind": "spray"})
def paint_marks(D, folder, origin, ry, rng, kind=None, color=None):
    """Marks on the ground, half worn away, every stroke a flush decal butted to the next (no
    stroke over another): faded utility survey paint (an arrow along -Z and dashes), chalk tally
    marks (someone counting: four strokes, the fifth crossing them in pieces between them), or a
    sprayed X with a ring of dashes. Footprint 1.5-4 studs. 4-14 parts, DECOR."""
    f = Frame(D, folder, origin, ry=ry)
    kind = kind or _pick(rng, ["survey", "chalk", "spray"])
    t = LINE_TH
    if kind == "survey":
        col = color or PAINT[_pick(rng, ["orange", "yellow", "white", "blue"])]
        tr = rng.uniform(0.3, 0.5)
        _flat(f, "Paint", 0, 0.45, 0.15, 1.5, t, col, "SmoothPlastic", transparency=tr, fit=False)
        for e in (-1, 1):  # the head: two strokes from the tip, their inner corners just apart
            a = math.radians(e * 32)
            ln = 0.55
            cx, cz = math.sin(a) * ln / 2 + e * 0.09, -0.36 + math.cos(a) * ln / 2
            _flat(f, "Paint", cx, cz, 0.14, ln, t, col, "SmoothPlastic", yaw=e * 32, transparency=tr, fit=False)
        for i in range(rng.randint(1, 3)):
            _flat(f, "Paint", 0, 1.55 + i * 0.6, 0.15, 0.38, t, col, "SmoothPlastic", transparency=tr + 0.15,
                  fit=False)
    elif kind == "chalk":
        col = color or CHALK
        tr = 0.45
        xs = [-0.3 + i * 0.2 + rng.uniform(-0.02, 0.02) for i in range(4)]
        w = 0.06
        for x in xs:
            _flat(f, "Chalk", x, 0, w, 0.75, t, col, "SmoothPlastic", yaw=rng.uniform(-4, 4), transparency=tr,
                  fit=False)
        # the fifth stroke crosses them diagonally: drawn in pieces between the four
        k = math.tan(math.radians(35))  # (its slope: z = k * x)
        ends = [xs[0] - 0.2] + xs + [xs[-1] + 0.2]
        for i in range(len(ends) - 1):
            xa = ends[i] + (w / 2 + 0.035 if i > 0 else 0)
            xb = ends[i + 1] - (w / 2 + 0.035 if i < len(ends) - 2 else 0)
            if xb - xa < 0.02:
                continue
            ln = (xb - xa) * math.sqrt(1 + k * k)
            _flat(f, "Chalk", (xa + xb) / 2, k * (xa + xb) / 2, w, ln, t, col, "SmoothPlastic",
                  yaw=math.degrees(math.atan2(1, k)), transparency=tr, fit=False)
    else:
        col = color or PAINT[_pick(rng, ["red", "white", "orange"])]
        tr = 0.35
        w = 0.18
        _flat(f, "Paint", 0, 0, w, w, t, col, "SmoothPlastic", yaw=45, transparency=tr, fit=False)
        for i in range(4):  # the X: four arms from the centre square (butted, not crossing)
            a = math.radians(45 + 90 * i)
            r0, r1 = w * 0.71 + 0.01, 0.8 + rng.uniform(-0.1, 0.1)
            rm = (r0 + r1) / 2
            _flat(f, "Paint", math.sin(a) * rm, math.cos(a) * rm, w, r1 - r0, t, col, "SmoothPlastic",
                  yaw=math.degrees(a), transparency=tr, fit=False)
        k = 8
        for i in range(k):
            if rng.random() < 0.25:
                continue  # sprayed in one go, gaps where it ran dry
            a = 2 * math.pi * i / k
            _flat(f, "Paint", math.cos(a) * 1.05, math.sin(a) * 1.05, 0.12, 0.62, t, col, "SmoothPlastic",
                  yaw=-math.degrees(a), transparency=tr + 0.1, fit=False)
