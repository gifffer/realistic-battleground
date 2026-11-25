"""zlayers: keeps the alleys' thin surface layers (wall stains, posters, floor decals) off each
other's planes, so nothing z-fights or flickers.

Why: Roblox cannot tell which of two faces on (almost) the same plane is in front. They show
as stripes or swap colours as the camera moves (z-fighting). Translucent parts are sorted per
part, by their centre, not per pixel, so two translucent slabs that intersect swap their draw
order as the camera moves ("two textures at once"). The prop libraries used to place every
overlay at a fixed depth per layer index k, restarting at k = 0 in every prop. So all the
props on one wall shared the same planes, and the 0.05-thick layers on a 0.022 step
intersected each other. Floor stains stepped by 0.004 between layers.
(Research: scratchpad quality/research_zfight.md; DevForum "Incorrect rendering for
intersecting transparent parts", "Z-fight rendering issues that occur on mobile".)

What this module does:
  • WALL LAYERS (wall_layer): every wall plane (a world normal plus an offset) has a few depth
    SLOTS in front of it: WALL_BASE + slot * WALL_STEP, each WALL_TH thick, with an air gap
    of 0.025 between slots. A new overlay goes one slot in front of every overlay already on
    that plane that it overlaps. Overlays elsewhere on the same wall don't use up slots, and
    pieces of one sheet (same prop, k, name and look) share one. The order follows (prop
    instance, k hint, call order), so a prop's k still means "behind / in front" among its
    own layers, and a later prop goes on top of an earlier one. When an earlier call gets a
    higher k than a later one, the overlapping layers are re-stacked: the rows already
    written are moved. At most WALL_MAX slots, and faint tints (transparency > WALL_FAINT_TR)
    only in the WALL_FAINT_MAX back ones, so haze never pushes posters and moss out. An
    overlay that would need more is REFUSED (None) rather than squeezed onto a used plane. A
    refused faint tint is folded into the colour of its prop's top layer under it (_fold),
    so the stain keeps its average darkness.
  • FLOOR DECALS (floor_layer): the same idea flat on a level surface (the floor, a board's
    top...), per surface height. A new decal goes at least FLOOR_STEP above every decal it
    overlaps that comes before it in the order (prop instance, requested thickness, call
    order), with an air gap under it. At most FLOOR_MAX levels in one place.
  • OPAQUE BLENDING (_beneath): a translucent layer lying wholly over ONE opaque look (the
    wall / floor part behind it, found in the alley data or the city data, and the lower
    opaque layers under it, all of one material and within a few colour units) is made
    opaque, with the blended colour computed here. Then nothing needs depth sorting. When it
    mostly lets the surface through (transparency >= 0.5), it also takes that surface's
    material, so the brick or asphalt texture carries on under the stain. A layer over
    several things, over glass, or over nothing known stays translucent, on its own slot
    (slots never intersect).

State lives on the citykit.Data object (D._zlayers), so every Data (alleys.py, the preview
scripts) starts clean.
"""

import json
import math
import os
import re

import numpy as np

# -- wall slots (studs, measured out of the wall face) -----------------------------------------
WALL_BASE = 0.03  # air gap between the wall face and the back of slot 0 (its front: 0.055 out)
WALL_STEP = 0.05  # slot spacing: front faces 0.05 apart (24-bit depth: safe to ~290 studs)
WALL_TH = 0.025  # slot thickness: leaves a 0.025 air gap between slots (they never intersect)
WALL_MAX = 5  # slots per place on a wall plane (the front one 0.255 out); a 6th is refused
WALL_FAINT_TR = 0.7  # a layer asked more transparent than this is a faint tint (haze, damp)...
WALL_FAINT_MAX = 2  # ...and may only take the 2 back slots: posters, signs, moss keep the 3 others

# -- floor levels (studs above the floor's top) ------------------------------------------------
FLOOR_STEP = 0.035  # min rise between overlapping decals' top faces
FLOOR_LIFTED_TH = 0.02  # thickness of a decal lifted over another (keeps a 0.015 air gap)
FLOOR_MAX = 3  # decal levels per place; a 4th is refused
FLOOR_DECAL_MAX_TH = 0.07  # _disk / _flat on the floor up to this thick count as decals

OPAQUE_SKIP = {"Glass", "Neon", "ForceField"}  # never blend against these
_CITY_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src", "server", "Systems", "City")


# ------------------------------------------------------------------ geometry
def _yxz(rx, ry, rz):
    """CFrame.fromEulerAnglesYXZ (degrees) as a matrix (same as citykit.yxz_matrix)."""
    a, b, c = math.radians(rx), math.radians(ry), math.radians(rz)
    cx, sx, cy, sy, cz, sz = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
    mx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    my = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    mz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return my @ mx @ mz


def _rects_overlap(a, b, margin=0.02):
    """2D boxes (u0, u1, v0, v1) overlapping by more than `margin` on both axes."""
    return a[0] < b[1] - margin and b[0] < a[1] - margin and a[2] < b[3] - margin and b[2] < a[3] - margin


def _hits(a, b, margin=0.02):
    """Whether layers a and b (dicts with "r" bounds, "poly" corners in plane coordinates,
    "sheet") cover some of the same place, by more than `margin` (touching edges and hairline
    overlaps of jittered neighbours don't count). Two pieces of ONE sheet (same prop, same k,
    same name, colour, material and transparency: a poster's intact top and its torn remnant,
    the runs of one tide mark) share a slot, so they don't count either: where they overlap,
    both faces look the same."""
    if a.get("sheet") is not None and a.get("sheet") == b.get("sheet"):
        return False
    if not _rects_overlap(a["r"], b["r"], margin):
        return False
    pa, pb = a["poly"], b["poly"]
    for poly in (pa, pb):  # separating axis test (both convex quads)
        for i in range(len(poly)):
            (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % len(poly)]
            nx, ny = y0 - y1, x1 - x0
            ln = math.hypot(nx, ny)
            if ln < 1e-9:
                continue
            nx, ny = nx / ln, ny / ln
            ja = [px * nx + py * ny for px, py in pa]
            jb = [px * nx + py * ny for px, py in pb]
            if max(ja) < min(jb) + margin or max(jb) < min(ja) + margin:
                return False
    return True


# ------------------------------------------------------------------ host lookup
class _Solids:
    """Blocks of a parts table as arrays, to find the part behind / under a point."""

    def __init__(self):
        self.c = np.zeros((0, 3))
        self.h = np.zeros((0, 3))
        self.m = np.zeros((0, 3, 3))
        self.lo = np.zeros((0, 3))
        self.hi = np.zeros((0, 3))
        self.info = []  # (color, material, transparency)

    def add(self, rows, colors, materials):
        cs, hs, ms, infos = [], [], [], []
        for r in rows:
            if r[0] not in (1, 2):  # blocks and wedges (a wedge as its box: good enough for a host)
                continue
            size = (r[7], r[8], r[9])
            if min(size) < 0.04:
                continue
            cs.append((r[1], r[2], r[3]))
            hs.append((size[0] / 2, size[1] / 2, size[2] / 2))
            ms.append(_yxz(r[4], r[5], r[6]) if (r[4] or r[5] or r[6]) else np.eye(3))
            infos.append((tuple(colors[r[10] - 1]), materials[r[11] - 1], r[12], r[0]))
        if not cs:
            return
        c, h, m = np.array(cs, float), np.array(hs, float), np.array(ms, float)
        ext = np.einsum("nij,nj->ni", np.abs(m), h)
        self.c = np.vstack([self.c, c])
        self.h = np.vstack([self.h, h])
        self.m = np.concatenate([self.m, m])
        self.lo = np.vstack([self.lo, c - ext])
        self.hi = np.vstack([self.hi, c + ext])
        self.info += infos

    def at(self, p, tol=1e-4):
        """(volume, color, material, transparency, wedge?) of the smallest part containing p, or None."""
        if not len(self.c):
            return None
        p = np.asarray(p, float)
        cand = np.nonzero(np.all((self.lo - tol <= p) & (p <= self.hi + tol), axis=1))[0]
        best = None
        for i in cand:
            loc = self.m[i].T @ (p - self.c[i])
            if np.all(np.abs(loc) <= self.h[i] + tol):
                vol = float(np.prod(self.h[i]))
                if best is None or vol < best[0]:
                    best = (vol,) + self.info[i]
        return best


_CITY = None


def _city_solids():
    """The city's own parts (CityData1..N.luau, read once): most alley walls and floors are
    city parts, not in the alley data."""
    global _CITY
    if _CITY is None:
        _CITY = _Solids()
        pieces, i = [], 1
        while os.path.exists(os.path.join(_CITY_DIR, f"CityData{i}.luau")):
            text = open(os.path.join(_CITY_DIR, f"CityData{i}.luau")).read()
            pieces.append(re.search(r"\[==\[(.*)\]==\]", text, re.S).group(1))
            i += 1
        if pieces:
            city = json.loads("".join(pieces))
            _CITY.add(city["parts"], city["colors"], city["materials"])
    return _CITY


def _state(D):
    st = D.__dict__.get("_zlayers")
    if st is None:
        st = {"planes": [], "floors": [], "solids": _Solids(), "seen": 0, "seq": 0, "instance": 0, "skip": set()}
        D.__dict__["_zlayers"] = st
    return st


def new_instance(D):
    """Starts a new prop instance (its layers go in front of every earlier prop's)."""
    _state(D)["instance"] += 1


def host_at(D, p):
    """(color, material, transparency) of the part at world point p (smallest one containing it;
    alley data first, then the city), or None. Thin parts (< 0.04) and layers never count."""
    st = _state(D)
    if st["seen"] < len(D.parts):
        rows = [r for i, r in enumerate(D.parts[st["seen"]:], st["seen"] + 1) if i not in st["skip"]]
        st["solids"].add(rows, D.colors, D.materials)
        st["seen"] = len(D.parts)
    hits = [h for h in (st["solids"].at(p), _city_solids().at(p)) if h is not None]
    if not hits:
        return None
    best = min(hits, key=lambda h: h[0])
    return best[1], best[2], best[3]


def blend(D, color, tr, material, beneath):
    """(color, transparency, material) of a translucent layer made opaque over `beneath`
    ((color, material, transparency) or None). Unchanged when it can't be blended."""
    if tr <= 0 or beneath is None:
        return color, tr, material
    bcol, bmat, btr = beneath
    if btr > 0 or bmat in OPAQUE_SKIP or material in OPAQUE_SKIP:
        return color, tr, material
    a = 1.0 - tr
    col = tuple(b + (c - b) * a for b, c in zip(bcol, color))
    return col, 0.0, (bmat if tr >= 0.5 else material)


def _uniform(looks, spread=14):
    """The one look (color, material, transparency) all of `looks` share, or None. They
    count as one when all are known, opaque, of one material and within `spread` colour
    units of each other (layers and hosts vary a little by jitter). The mean colour is used."""
    if not looks or any(lk is None or lk[2] > 0 for lk in looks):
        return None
    if len({lk[1] for lk in looks}) != 1:
        return None
    cols = np.array([lk[0] for lk in looks], float)
    if float((cols.max(axis=0) - cols.min(axis=0)).max()) > spread:
        return None
    return tuple(float(c) for c in cols.mean(axis=0)), looks[0][1], 0.0


def _inside(poly, a, b):
    """Point (a, b) inside a convex quad (either winding)."""
    sgn = 0
    for i in range(len(poly)):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % len(poly)]
        c = (x1 - x0) * (b - y0) - (y1 - y0) * (a - x0)
        if abs(c) < 1e-12:
            continue
        if sgn == 0:
            sgn = 1 if c > 0 else -1
        elif (c > 0) != (sgn > 0):
            return False
    return True


def _beneath(items, new, host):
    """The single look under layer `new` (see _uniform), or None. Sampled at a 3 x 3 grid of
    its area plus the middle of its overlap with every lower layer (so a small layer under it
    is never missed). At each point it is the top lower layer there, else host(a, b) (the
    part behind / below that plane point)."""
    under = [it for it in items if it["level"] < new["level"] and _hits(it, new, 0.0)]
    r = new["r"]
    pts = [(r[0] + (r[1] - r[0]) * fa, r[2] + (r[3] - r[2]) * fb) for fa in (0.1, 0.5, 0.9) for fb in (0.1, 0.5, 0.9)]
    pts = [p for p in pts if _inside(new["poly"], *p)] or [((r[0] + r[1]) / 2, (r[2] + r[3]) / 2)]
    for it in under:
        q = it["r"]
        pts.append(((max(q[0], r[0]) + min(q[1], r[1])) / 2, (max(q[2], r[2]) + min(q[3], r[3])) / 2))
    looks = []
    for a, b in pts:
        top = max((it for it in under if _inside(it["poly"], a, b)), key=lambda it: it["level"], default=None)
        looks.append((top["color"], top["material"], top["tr"]) if top is not None else host(a, b))
    return _uniform(looks)


# ------------------------------------------------------------------ the shared stacking
def _stack(items, new, gap_fn):
    """Stacks `new` among `items` (dicts with "r" rect, "key", "level"). Returns {id(item):
    level} for every item whose level changes (the new one included), or None if a level
    would go past its cap (gap_fn(item, level) is False). Order: by key; each item one level above
    the highest earlier item it overlaps."""
    over = [it for it in items if _hits(it, new)]
    if all(it["key"] < new["key"] for it in over):  # the common case: on top of what's there
        lvl = 1 + max((it["level"] for it in over), default=-1)
        return {id(new): lvl} if gap_fn(new, lvl) else None
    # an earlier call ranks above the new one: re-stack the overlapping group in key order
    group, todo = {id(new): new}, [new]
    while todo:  # (everything transitively connected to the new item)
        cur = todo.pop()
        for it in items:
            if id(it) not in group and _hits(it, cur):
                group[id(it)] = it
                todo.append(it)
    order = sorted(group.values(), key=lambda it: it["key"])
    levels = {}
    for i, it in enumerate(order):
        lv = 1 + max((levels[id(o)] for o in order[:i] if _hits(o, it)), default=-1)
        if not gap_fn(it, lv):
            return None
        levels[id(it)] = lv
    return {k: v for k, v in levels.items() if k == id(new) or group[k]["level"] != v}


def _move_row(D, idx, world):
    D.parts[idx - 1][1:4] = [round(float(world[0]), 3), round(float(world[1]), 3), round(float(world[2]), 3)]


# ------------------------------------------------------------------ walls
def _wall_plane(st, n, d):
    for pl in st["planes"]:
        if float(np.dot(pl["n"], n)) > 0.9995 and abs(pl["d"] - d) < 0.03:
            return pl
    up = np.array((0.0, 1.0, 0.0))
    u = np.cross(up, n)
    if np.linalg.norm(u) < 1e-3:  # a horizontal plane: any in-plane axis
        u = np.cross(np.array((0.0, 0.0, 1.0)), n)
    u = u / np.linalg.norm(u)
    pl = {"n": n, "d": d, "u": u, "v": np.cross(n, u), "items": []}
    st["planes"].append(pl)
    return pl


def _wall_depth(slot):
    return WALL_BASE + slot * WALL_STEP + WALL_TH / 2


def wall_layer(f, name, cx, cy, w, h, rz, color, k, tr, material, flags, **kw):
    """Makes one overlay (a w x h layer centred on local (cx, cy) of frame f's z = 0 plane,
    its outside towards local -Z, spun rz degrees) in the next free slot of that wall plane.
    Returns the part index, or None when the place already has WALL_MAX layers."""
    D = f.D
    st = _state(D)
    n = f.m @ np.array((0.0, 0.0, -1.0))
    o = f.world((0.0, 0.0, 0.0))
    pl = _wall_plane(st, n, float(np.dot(n, o)))
    p = f.world((cx, cy, 0.0))
    p = p - pl["n"] * (float(np.dot(pl["n"], p)) - pl["d"])  # onto the shared plane
    a = math.radians(rz)
    ca, sa = math.cos(a), math.sin(a)
    us, vs = [], []
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        lx, ly = sx * w / 2, sy * h / 2
        q = f.world((cx + lx * ca - ly * sa, cy + lx * sa + ly * ca, 0.0))
        us.append(float(np.dot(q, pl["u"])))
        vs.append(float(np.dot(q, pl["v"])))
    st["seq"] += 1
    new = {"name": name, "r": (min(us), max(us), min(vs), max(vs)), "poly": list(zip(us, vs)),
           "key": (st["instance"], k, st["seq"]), "level": 0, "p": p, "idx": None,
           "sheet": (st["instance"], k, name, tuple(round(c) for c in color), material, tr)}
    new["faint"] = tr > WALL_FAINT_TR
    levels = _stack(pl["items"], new, lambda it, lv: lv < (WALL_FAINT_MAX if it["faint"] else WALL_MAX))
    if levels is None:
        if new["faint"]:
            _fold(D, pl, new, color, tr)
        return None
    for it in pl["items"]:
        if id(it) in levels:
            it["level"] = levels[id(it)]
            _move_row(D, it["idx"], it["p"] + pl["n"] * _wall_depth(it["level"]))
    new["level"] = levels[id(new)]
    if tr > 0:  # opaque when everything under it looks the same (one surface)
        n_, u_, v_, d_ = pl["n"], pl["u"], pl["v"], pl["d"]
        beneath = _beneath(pl["items"], new, lambda a, b: host_at(D, n_ * (d_ - 0.03) + u_ * a + v_ * b))
        color, tr, material = blend(D, color, tr, material, beneath)
    new.update(color=tuple(color), tr=tr, material=material)
    centre = p + pl["n"] * _wall_depth(new["level"])
    m = f.m @ _yxz(0, 0, rz)
    from citykit import yxz_angles  # (lazy: citykit imports nothing from here)

    idx = D.part(kw.pop("folder", None) or f.folder, name, tuple(float(v) for v in centre), (w, h, WALL_TH),
                 color, material, rot=yxz_angles(m), flags=flags, transparency=tr, **kw)
    new["idx"] = idx
    st["skip"].add(idx)
    pl["items"].append(new)
    return idx


def _area(r):
    return max(0.0, r[1] - r[0]) * max(0.0, r[3] - r[2])


def _fold(D, pl, new, color, tr):
    """A refused FAINT layer (a tint: rising damp, soot haze) is not lost: its darkness is
    folded into the top layer of the same prop it overlaps, weighted by how much of that
    layer it covers. So the average tone of the stain stays as asked; only its gradient has
    fewer steps. A small tint doesn't spread over a much larger layer (coverage < 0.3)."""
    mine = [it for it in pl["items"] if it["key"][0] == new["key"][0] and _hits(it, new, 0.0)]
    if not mine:
        return
    top = max(mine, key=lambda it: it["level"])
    r, q = new["r"], top["r"]
    inter = (max(r[0], q[0]), min(r[1], q[1]), max(r[2], q[2]), min(r[3], q[3]))
    cover = _area(inter) / max(_area(q), 1e-6)
    if cover < 0.3:
        return
    a = (1 - tr) * min(1.0, cover)
    row = D.parts[top["idx"] - 1]
    col = tuple(c + (n - c) * a for c, n in zip(top["color"], color))
    top["color"] = col
    row[10] = D._idx("c", D.colors, tuple(int(max(0, min(255, round(c)))) for c in col))
    if top["tr"] > 0:  # (still translucent: a little less so)
        top["tr"] = round(top["tr"] * (1 - a), 3)
        row[12] = top["tr"]


def wall_text_depth(k):
    """Local z centre of a 0.05-thick text carrier (an invisible part with a SurfaceGui on its
    front) for layer hint k: half a slot in front of slot k, never past the last slot."""
    k = max(0, min(int(k), WALL_MAX - 1))
    return -(WALL_BASE + WALL_TH + k * WALL_STEP + WALL_STEP / 2 - 0.025)


# ------------------------------------------------------------------ floors
def floor_layer(f, name, x, y, z, sx, sz, th, yaw, make, color, tr, material):
    """Places a floor decal of footprint sx x sz (local, turned `yaw`) lying on the level
    surface at frame f's local height y (the floor, or the top of a board...), th thick as
    asked. `make(y_centre, th, color, tr, material)` creates the
    part in local coordinates and returns its index. Returns the index, or None when the
    place already has FLOOR_MAX decals. The decal keeps its height when nothing is under it;
    otherwise its top goes FLOOR_STEP above the highest earlier decal it overlaps and it
    becomes FLOOR_LIFTED_TH thick (an air gap under it, so translucent decals never
    intersect)."""
    D = f.D
    st = _state(D)
    base = f.world((x, y, z))
    fl = None
    for cand in st["floors"]:
        if abs(cand["y"] - base[1]) < 0.03:
            fl = cand
            break
    if fl is None:
        fl = {"y": float(base[1]), "items": []}
        st["floors"].append(fl)
    a = math.radians(yaw)
    ca, sa = math.cos(a), math.sin(a)
    xs, zs = [], []
    for ux, uz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        lx, lz = ux * sx / 2, uz * sz / 2
        q = f.world((x + lx * ca + lz * sa, y, z - lx * sa + lz * ca))
        xs.append(float(q[0]))
        zs.append(float(q[2]))
    st["seq"] += 1
    new = {"r": (min(xs), max(xs), min(zs), max(zs)), "poly": list(zip(xs, zs)),
           "key": (st["instance"], round(th, 4), st["seq"]), "level": 0, "th": th,
           "idx": None, "local": (f, x, y, z)}
    levels = _stack(fl["items"], new, lambda it, lv: lv < FLOOR_MAX)
    if levels is None:
        return None
    fl["items"].append(new)  # (so items re-stacked above the new one see its top)
    moved = [it for it in fl["items"] if id(it) in levels]
    for it in moved:
        it["level"] = levels[id(it)]
    for it in sorted(moved, key=lambda it: it["level"]):
        _place_floor(D, fl, it, dry=it is new)
    fl["items"].pop()
    if tr > 0:
        yb = fl["y"] - 0.03
        beneath = _beneath(fl["items"], new, lambda a, b: host_at(D, (a, yb, b)))
        color, tr, material = blend(D, color, tr, material, beneath)
    new.update(color=tuple(color), tr=tr, material=material)
    y0, t = new["span"]
    idx = make(y + y0 + t / 2, t, color, tr, material)
    new["idx"] = idx
    st["skip"].add(idx)
    fl["items"].append(new)
    return idx


def _place_floor(D, fl, it, dry=False):
    """Works out it's local span (bottom, thickness) from its level and moves its row."""
    if it["level"] == 0:
        it["top"] = it["th"]
        span = (0.0, it["th"])
    else:
        below = [o["top"] for o in fl["items"] if o is not it and o["level"] < it["level"]
                 and _hits(o, it)]
        top = max(it["th"], max(below, default=0.0) + FLOOR_STEP)
        t = min(it["th"], FLOOR_LIFTED_TH)
        it["top"] = top
        span = (top - t, t)
    it["span"] = span
    if dry or it["idx"] is None:
        return
    f, x, y, z = it["local"]
    row = D.parts[it["idx"] - 1]
    _move_row(D, it["idx"], f.world((x, y + span[0] + span[1] / 2, z)))
    # the thickness axis: local Y for a plate (rot (0, yaw, 0)), local X for a disk (upright cylinder)
    axis = 7 if row[0] == 3 else 8
    row[axis] = round(max(span[1], 0.02), 3)
