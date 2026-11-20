"""Soft goods of the city prop kit: black bin bags, a 25 kg cement sack, a bunched sleeping bag,
blankets (crumpled, folded) and a worn rucksack.

Why these are meshes: the old props were stacks of balls and boxes (a bin bag = four Roblox balls
and a cube knot; a cement sack = a box with two cylinders, which read as a sofa cushion; a
blanket = rotated slabs that read as cardboard). Soft things are all about their silhouette and
their folds, which primitives cannot give. Here:
  * bin bags and the sack are lofted rings whose radius is sculpted per angle (sag spreading on
    the ground, lumps of the contents pushing through, tension creases running into the gathered
    neck, block-bottom ends and puckered corners for the sack);
  * the blankets and the sleeping bag come out of a real CLOTH SIMULATION (Blender's cloth solver,
    run headless while the piece is built: a sheet is dropped on the floor and pushed together by
    moving walls, so it buckles into real folds), then given thickness;
  * the rucksack is a sculpted soft body with its real parts: lid with straps and buckles, front
    pocket with its zip, side mesh pockets, padded S-shaped shoulder straps, grab loop.

Each build function gets a kitlib.Piece (`ctx`) and models its piece in Roblox axes (Y up, the
front faces -Z, studs; 1 stud ~ 0.29 m, props ~15 % large like the rest of the city), the origin
at the centre of the footprint on the floor. Every piece sits 0.01 studs above the floor (never
in its plane). Layers never share a surface: details laid on a body stand >= 0.02 proud of it, or
cross it at an angle. No bottles anywhere (the player's rule).
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

from kitlib import T, R, Noise, TO_BLENDER, to_blender, angles, box, loft, lerp, smoothstep, mul, ground_dirt, cavity, edge_wear  # noqa: F401

FLOOR = 0.012  # every piece's lowest point: just above the floor, never in its plane


# ----------------------------------------------------------------------------------------------
# Shared helpers
# ----------------------------------------------------------------------------------------------
def _wrap(a):
    """An angle difference brought into [-pi, pi]."""
    return math.atan2(math.sin(a), math.cos(a))


def _interp(rows, x):
    """Linear interpolation in a list of (x, value) rows sorted by x (clamped at both ends)."""
    if x <= rows[0][0]:
        return rows[0][1]
    for (x0, v0), (x1, v1) in zip(rows, rows[1:]):
        if x <= x1:
            return lerp(v0, v1, (x - x0) / max(x1 - x0, 1e-9))
    return rows[-1][1]


def _ribbon(path, widths, thick, ups, n=10, square=0.45, cap=True):
    """A flat strip (a strap, a bag ear, a torn flap) along `path`: its cross-section a rounded
    rectangle `widths[i]` wide and `thick` thick (a superellipse, exponent `square`: lower =
    boxier), its flat face turned toward ups[i] (one vector, or one per point). Closed (capped)."""
    pts = [Vector(p) for p in path]
    ws = widths if isinstance(widths, (list, tuple)) else [widths] * len(pts)
    ths = thick if isinstance(thick, (list, tuple)) else [thick] * len(pts)
    if isinstance(ups, Vector) or (isinstance(ups, tuple) and len(ups) == 3 and not isinstance(ups[0], (tuple, Vector))):
        ups = [Vector(ups)] * len(pts)
    rings = []
    for i, p in enumerate(pts):
        d = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
        d.normalize()
        up = Vector(ups[i])
        up = (up - d * up.dot(d)).normalized()
        side = d.cross(up)
        ring = []
        for k in range(n):
            t = 2 * math.pi * k / n
            c, s = math.cos(t), math.sin(t)
            cx = math.copysign(abs(c) ** square, c) * ws[i] / 2
            cy = math.copysign(abs(s) ** square, s) * ths[i] / 2
            ring.append(tuple(p + side * cx + up * cy))
        rings.append(ring)
    return loft(rings, cap_start=cap, cap_end=cap)


def _lumpy_ball(r, noise, amp=0.15, scale=2.5, segs=12, rings=8, squash=(1.0, 1.0, 1.0), seed_off=0.0):
    """A soft lump (a knot, contents, food scraps): a UV sphere pushed in and out by noise."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    for v in bm.verts:
        n = v.co.normalized()
        k = 1 + amp * noise.fbm(n * scale + Vector((seed_off, 0, 0)), 2)
        v.co = Vector((n.x * r * k * squash[0], n.y * r * k * squash[1], n.z * r * k * squash[2]))
    return bm


def _crumple(r, rng):
    """A crumpled ball of paper: an icosphere whose vertices are pushed in and out at random,
    so its facets catch the light like creased paper."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    off = Vector((rng.uniform(0, 50), rng.uniform(0, 50), rng.uniform(0, 50)))
    nz = Noise(rng.randrange(1 << 20))
    for v in bm.verts:
        n = v.co.normalized()
        # sharp creases (ridged noise) plus a coarse squash: crumpled, not a polyhedron
        k = 0.82 + 0.2 * nz.fbm(n * 1.6 + off, 2) - 0.16 * nz.ridge(n * 2.4 + off) ** 3
        v.co = n * r * k * Vector((1.0, 0.85, 1.1))
    return bm


def _puddle(cx, cz, rad, noise, top=0.056, seg=28, stretch=(1.0, 1.0)):
    """A flat wet stain (leak, spilt powder base) on the floor: an irregular lobed outline, a
    rounded lip, top `top` over the floor (>= 0.05: no depth fight with the ground), its
    underside at FLOOR."""
    angs = [2 * math.pi * k / seg for k in range(seg)]

    def rim(a, f):
        q = (math.cos(a) * 1.3 + cx, math.sin(a) * 1.3 + cz, 4.2)
        rr = rad * f * (1 + 0.32 * noise.fbm(q, 2) + 0.1 * math.sin(3 * a + cx))
        return (cx + math.cos(a) * rr * stretch[0], math.sin(a) * rr * stretch[1] + cz)

    rings = [[(cx, top, cz)]]
    for f, y in ((0.55, top), (0.86, top - 0.004), (0.97, top - 0.018), (1.0, (top + FLOOR) / 2), (0.985, FLOOR)):
        rings.append([(rim(a, f)[0], y, rim(a, f)[1]) for a in angs])
    rings.append([(cx, FLOOR, cz)])
    return loft(rings)


def _transform(bm, fn):
    for v in bm.verts:
        v.co = fn(v.co.copy())


def _delete_faces(bm, keep_fn):
    """Removes the faces whose centre fails keep_fn(centre) (a tear, a hole)."""
    dead = [f for f in bm.faces if not keep_fn(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=dead, context="FACES")


# ----------------------------------------------------------------------------------------------
# TrashBag1 / 2 / 3. A full 60-80 L black LDPE bin bag (real: ~50 cm across, 60-70 cm tall when
# full; at the city's prop scale ~2.2 studs across, 2 tall to the knot). What makes it read
# (real_specs.md): a pear that SLUMPS, its bottom spread and flattened on the ground by the
# weight; hard lumps of rubbish pushing the film out; long tension creases running up into the
# gathered, twisted neck; the knot with its two limp ears; glossy highlights breaking on all
# those lumps and creases. 1 = standing full bag, 2 = split low on the front, rubbish spilling
# out over a dark leak, 3 = a half-empty bag fallen on its side and flattened (the top of a heap).
# props_ground.trash_bag(size = s) -> TrashBag1/2 at Scale = s / 2.2.
# ----------------------------------------------------------------------------------------------
BAG_PROFILE = [  # (radius fraction, height fraction of the body) from the floor up to the neck
    (0.40, 0.0), (0.72, 0.004), (0.89, 0.022), (0.965, 0.06), (1.0, 0.13), (1.012, 0.22), (1.0, 0.32),
    (0.975, 0.42), (0.93, 0.52), (0.86, 0.61), (0.76, 0.70), (0.63, 0.78), (0.49, 0.85), (0.35, 0.91),
    (0.23, 0.955), (0.145, 0.985),
]
NECK = [(0.0, 0.15), (0.06, 0.122), (0.12, 0.104), (0.18, 0.1), (0.23, 0.112)]  # (height over body, radius)


def _bag_body(ctx, Rb, Hb, lean, lumps, creases, segs=64, pleats=8, twist=1.6, wrinkle=0.05):
    """The bag's film from the floor to the top of its neck, one closed loft. Returns (bm,
    surface(a, yf) -> point on the outside, neck top centre)."""
    noise = ctx.noise
    lx, lz = lean

    def centre(yf):
        k = smoothstep(0.3, 1.0, yf) ** 1.3
        return lx * k, lz * k

    def modulation(a, yf):
        m = 1 + 0.045 * noise.fbm((math.cos(a) * 1.4, yf * 2.2, math.sin(a) * 1.4), 3)
        for la, ly, amp, wa, wy in lumps:
            m += amp * math.exp(-((_wrap(a - la) / wa) ** 2) - ((yf - ly) / wy) ** 2)
        g = smoothstep(0.38, 0.97, yf)
        for ca, depth, w in creases:
            da = _wrap(a - (ca + twist * 0.25 * yf))
            ww = w * (1.25 - 0.6 * yf)
            m -= depth * g * math.exp(-((da / ww) ** 2))
        # fine tension wrinkles: thin valleys stretched up the film (ridged noise), strongest
        # where the film is pulled toward the neck
        q = (math.cos(a) * 3.2, yf * 1.1, math.sin(a) * 3.2)
        m -= wrinkle * (0.35 + 0.65 * g) * noise.ridge(q, 1.0) ** 6
        return m

    def surface(a, yf):
        rf = _interp([(y, r) for r, y in BAG_PROFILE], yf)
        cx, cz = centre(yf)
        r = Rb * rf * modulation(a, yf)
        y = FLOOR + yf * Hb if yf > 0.0 else FLOOR
        return Vector((cx + r * math.cos(a), y, cz + r * math.sin(a)))

    angs = angles(segs)
    rings = [[tuple(Vector((0, FLOOR, 0)))]]
    for rf, yf in BAG_PROFILE:
        rings.append([tuple(surface(a, yf)) for a in angs])
    # the gathered neck: pleats (8 folds of film twisted together), narrowing into the knot
    ncx, ncz = centre(1.0)
    for i, (h, rr) in enumerate(NECK):
        ring = []
        for a in angs:
            pa = a + twist * h * 3.0
            pleat = abs(math.sin(pleats / 2 * pa)) ** 0.7 - 0.45
            r = rr * (1 + 0.42 * pleat * (0.4 + 0.6 * min(1.0, i / 2)))
            ring.append((ncx + r * math.cos(a), FLOOR + Hb + h, ncz + r * math.sin(a)))
        rings.append(ring)
    top = Vector((ncx, FLOOR + Hb + NECK[-1][0] + 0.03, ncz))
    rings.append([tuple(top)])
    return loft(rings), surface, top


def _bag_knot(ctx, top, ears):
    """The knot (a lumpy squashed ball) and its two limp ears (the bag's corners tied together:
    thin film strips, fanning out then pointed, flopping down)."""
    rng = ctx.rng
    bms = []
    knot = _lumpy_ball(0.165, ctx.noise, amp=0.22, scale=3.0, segs=12, rings=8, squash=(1.05, 0.78, 0.95))
    bmesh.ops.transform(knot, matrix=T(*top) @ R(rng.uniform(-15, 15), rng.uniform(0, 180), rng.uniform(-15, 15)),
                        verts=knot.verts)
    bms.append(knot)
    for ea, length, droop, lift in ears:
        d = Vector((math.cos(ea), 0, math.sin(ea)))
        side = Vector((0, 1, 0)).cross(d)
        path, widths, ups = [], [], []
        n = 7
        for k in range(n):
            s = k / (n - 1)
            p = top + d * (0.04 + length * s) + Vector((0, 0.06 + lift * math.sin(math.pi * s * 0.7) - droop * s * s, 0))
            p += side * 0.05 * math.sin(s * 3.0)
            path.append(p)
            widths.append(0.16 + 0.3 * math.sin(math.pi * min(1.0, s * 1.3)) * (1 - s) + 0.04 * (1 - s))
            # the strip's face turns as it hangs (a limp twist of film)
            tw = 0.9 * s
            ups.append(Vector((0, math.cos(tw), 0)) + side * math.sin(tw))
        widths[-1] = 0.03
        bms.append(_ribbon(path, widths, 0.032, ups, n=8, square=0.35))
    return bms


def _bag_wear(ctx, torn_at=None):
    noise = ctx.noise

    def fn(p):
        x, y, z = p.co
        k = 1 - 0.32 * (1 - smoothstep(0.0, 0.32 * (1 + 0.4 * noise.fbm((x * 2, 0.0, z * 2), 2)), y))  # dust, wet floor
        k *= 1 - 0.45 * smoothstep(0.0, 0.5, -p.convex)  # creases and pleats
        k *= 1 - 0.1 * smoothstep(0.3, 0.8, noise.fbm((x * 5, y * 5, z * 5), 2) * 0.5 + 0.5)  # smears
        if torn_at is not None:
            k *= 1 - 0.35 * math.exp(-((Vector((x, y, z)) - torn_at).length / 0.45) ** 2)  # muck round the split
        return k

    return fn


def _bag_setup(ctx):
    ctx.budget = 3600
    ctx.smooth_angle = 62  # (film: everything soft, the creases shaded, not cut)
    ctx.tint("Plastic", (20, 20, 22))  # black LDPE (the data can pick grey, green, blue)


def trash_bag1(ctx):
    """Full black bin bag standing slumped: sagging pear, lumps of rubbish, creases into the
    twisted neck, knot and two limp ears (2.2 across, 2.0 tall)."""
    _bag_setup(ctx)
    rng = ctx.rng
    lumps = [(-2.2, 0.28, 0.13, 0.6, 0.16), (0.4, 0.5, 0.1, 0.45, 0.12), (2.3, 0.16, 0.1, 0.7, 0.12),
             (1.2, 0.66, -0.08, 0.5, 0.1), (-0.9, 0.62, 0.09, 0.35, 0.09), (-0.2, 0.25, -0.07, 0.4, 0.1),
             (3.0, 0.45, 0.08, 0.4, 0.1)]
    creases = [(rng.uniform(0, 2 * math.pi), rng.uniform(0.08, 0.15), rng.uniform(0.12, 0.2)) for _ in range(10)]
    body, surface, top = _bag_body(ctx, 1.0, 1.58, (0.1, -0.06), lumps, creases)
    ctx.add("Plastic", body)
    for bm in _bag_knot(ctx, top, [(0.5, 0.58, 0.42, 0.1), (0.5 + math.pi + 0.5, 0.5, 0.34, 0.07)]):
        ctx.add("Plastic", bm)
    ctx.wear("Plastic", _bag_wear(ctx))


def trash_bag2(ctx):
    """Bin bag split low on the front: the film torn open with curled flaps, the rubbish bulging
    out, crumpled paper, a crushed carton and food scraps spilt in front over a dark leak."""
    _bag_setup(ctx)
    ctx.budget = 4600  # (the bag plus what spilt out of it)
    rng, noise = ctx.rng, ctx.noise
    lumps = [(1.8, 0.3, 0.12, 0.7, 0.15), (-0.2, 0.55, 0.09, 0.45, 0.12), (3.0, 0.2, 0.1, 0.5, 0.12),
             (-1.6, 0.32, 0.1, 0.5, 0.12), (0.9, 0.62, -0.08, 0.5, 0.1)]
    creases = [(rng.uniform(0, 2 * math.pi), rng.uniform(0.08, 0.14), rng.uniform(0.12, 0.2)) for _ in range(9)]
    Rb, Hb = 1.0, 1.5
    body, surface, top = _bag_body(ctx, Rb, Hb, (-0.08, 0.1), lumps, creases)
    # the split: low on the front (-Z), ragged
    ta, ty = -math.pi / 2 + 0.25, 0.3
    hole_c = surface(ta, ty)

    def keep(c):
        a = math.atan2(c.z, c.x)
        yf = (c.y - FLOOR) / Hb
        d = (_wrap(a - ta) / 0.36) ** 2 + ((yf - ty) / 0.15) ** 2
        rag = 0.25 * noise.fbm((math.cos(a) * 6, yf * 6, math.sin(a) * 6), 2)
        return d > 1.0 + rag

    _delete_faces(body, keep)
    ctx.add("Plastic", body)
    for bm in _bag_knot(ctx, top, [(2.2, 0.55, 0.4, 0.08), (2.2 + math.pi - 0.4, 0.5, 0.36, 0.06)]):
        ctx.add("Plastic", bm)
    # torn flaps of film curling out of the split's edge
    out = Vector((hole_c.x, 0, hole_c.z)).normalized()
    for fa, fy, length, curl in ((ta - 0.4, ty + 0.06, 0.34, 1.0), (ta + 0.36, ty - 0.02, 0.3, -0.8),
                                 (ta + 0.05, ty + 0.17, 0.26, 0.4)):
        base = surface(fa, fy)
        n_out = Vector((base.x, 0, base.z)).normalized()
        tang = Vector((0, 1, 0)).cross(n_out)
        path, ups, widths = [], [], []
        for k in range(6):
            s = k / 5
            p = base - n_out * 0.03 + n_out * (0.22 * s) * length / 0.3 + Vector((0, -0.22 * s * s, 0)) + tang * curl * 0.08 * s
            path.append(p)
            ups.append(n_out * math.cos(s * 1.2) + Vector((0, 1, 0)) * math.sin(s * 1.2))
            widths.append(lerp(0.22, 0.04, s))
        ctx.add("Plastic", _ribbon(path, widths, 0.022, ups, n=8, square=0.3))
    # the rubbish bulging out of the split (behind the film everywhere else)
    stuff_c = Vector((hole_c.x, hole_c.y - 0.02, hole_c.z)) - out * 0.3
    ctx.add("Soil", _lumpy_ball(0.36, noise, amp=0.25, scale=3.5, segs=14, rings=9, squash=(1.1, 0.85, 1.0)),
            T(*stuff_c))
    # what fell out: paper balls, a crushed carton, scraps, over the leak
    fx, fz = hole_c.x, hole_c.z
    ctx.add("Black", _puddle(fx + 0.15, fz - 0.6, 0.62, noise, stretch=(1.25, 0.8)))
    for px, pz, r in ((fx - 0.45, fz - 0.55, 0.16), (fx + 0.55, fz - 0.85, 0.13), (fx - 0.1, fz - 1.15, 0.14)):
        ctx.add("Paper", _crumple(r, rng), T(px, FLOOR + 0.06 + r * 0.8, pz) @ R(rng.uniform(0, 90), rng.uniform(0, 180), 0))
    carton = box(0.5, 0.16, 0.36, bevel=0.025)
    bmesh.ops.subdivide_edges(carton, edges=[e for e in carton.edges if abs((e.verts[0].co - e.verts[1].co).x) > 0.3],
                              cuts=2, use_grid_fill=False)

    def crush(co):
        co.y *= 1 - 0.55 * max(0.0, co.x / 0.25) ** 2 * (0.5 + 0.5 * math.sin(co.z * 6))
        co.y += 0.03 * math.sin(co.x * 9)
        return co

    _transform(carton, crush)
    ctx.add("Cardboard", carton, T(fx + 0.75, FLOOR + 0.09, fz - 0.4) @ R(rng.uniform(-6, 6), 35, rng.uniform(4, 9)))
    for px, pz, r in ((fx + 0.05, fz - 0.55, 0.12), (fx - 0.3, fz - 0.85, 0.09), (fx + 0.35, fz - 0.6, 0.08)):
        ctx.add("Soil", _lumpy_ball(r, noise, amp=0.35, scale=5.0, segs=8, rings=5, squash=(1.2, 0.55, 1.0),
                                    seed_off=px * 7), T(px, FLOOR + r * 0.45 + 0.03, pz))
    ctx.wear("Plastic", _bag_wear(ctx, torn_at=hole_c))
    ctx.wear("Paper", mul(ground_dirt(0.3, 0.45, noise), cavity(0.5), lambda p: 0.78))
    ctx.wear("Cardboard", mul(ground_dirt(0.2, 0.45, noise), cavity(0.3), edge_wear(0.1)))
    ctx.wear("Soil", cavity(0.3))
    ctx.wear("Black", lambda p: 0.85)


def trash_bag3(ctx):
    """A half-empty bin bag fallen on its side, flattened by its own weight (the top of a heap,
    a bag dropped in a doorway): 2.7 x 1.9, 1.1 tall, the knot lying on the ground."""
    _bag_setup(ctx)
    rng = ctx.rng
    lumps = [(-0.6, 0.3, 0.12, 0.6, 0.16), (1.6, 0.45, 0.1, 0.5, 0.14), (2.8, 0.2, -0.1, 0.5, 0.12),
             (0.2, 0.7, -0.1, 0.7, 0.12), (-2.0, 0.55, 0.08, 0.4, 0.1)]
    creases = [(rng.uniform(0, 2 * math.pi), rng.uniform(0.12, 0.2), rng.uniform(0.12, 0.2)) for _ in range(13)]
    Rb, Hb = 0.95, 1.55
    body, _surface, top = _bag_body(ctx, Rb, Hb, (0.0, 0.0), lumps, creases, wrinkle=0.09)
    parts = [body] + _bag_knot(ctx, top, [(1.2, 0.55, 0.05, 0.05), (1.2 + math.pi - 0.3, 0.5, 0.05, 0.04)])
    # lay it down: the neck toward +X, rolled a little, then flattened onto the floor
    rot = R(0, 0, -84) @ R(0, rng.uniform(-20, 20), 0)
    mid = Vector((0, Hb * 0.4, 0))
    for bm in parts:
        bmesh.ops.transform(bm, matrix=T(*(-mid)), verts=bm.verts)
        bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    lo = min(v.co.y for bm in parts for v in bm.verts)
    xs = [v.co.x for v in body.verts]
    xc = (min(xs) + max(xs)) / 2
    hmax = max(v.co.y for v in body.verts) - lo

    def flatten(co):
        y = (co.y - lo) * 0.6  # (half empty: it spreads)
        spread = 1 + 0.2 * (1 - smoothstep(0.0, hmax * 0.6, y))
        co.z *= spread
        co.x = xc + (co.x - xc) * (1 + 0.06 * (1 - smoothstep(0, hmax * 0.6, y)))
        # the knot end droops to the floor
        tip = smoothstep(xc + 0.6, xc + 1.6, co.x)
        y = y * (1 - 0.55 * tip)
        co.y = max(FLOOR, y + FLOOR)
        co.x -= xc
        return co

    for bm in parts:
        _transform(bm, flatten)
        ctx.add("Plastic", bm)
    ctx.wear("Plastic", _bag_wear(ctx))


# ----------------------------------------------------------------------------------------------
# CementBag. A 25 kg multiwall paper valve sack of cement lying flat (real: ~60 x 40 x 11 cm;
# here 1.95 x 1.25 x 0.45 studs, the footprint of props_ground.cement_bag). What makes it read
# (real_specs.md): a firm "brick pillow" (flat underneath, a domed top, rounded sides) with
# square BLOCK-BOTTOM ends (each end a flat rectangle with its pasted flap) and pointed creased
# corners, the filling valve tucked in at one top corner, big printed colour bands across it;
# set hard in a lumpy, slightly bent shape after the rain, creased, the bottom wet-dark; one top
# corner torn open, the grey powder spilt in a low drift with hardened lumps.
# ----------------------------------------------------------------------------------------------
SACK_L, SACK_W, SACK_H = 1.95, 1.25, 0.45
BANDS = ((-0.32, 0.08, (1.0, 0.36, 0.3)), (0.15, 0.23, (1.0, 0.82, 0.3)), (0.27, 0.31, (0.42, 0.55, 0.95)))


def _sack_ring(ctx, x, angs, end_k):
    """One cross-section of the sack (a closed ring in the z-y plane at `x`): a superellipse,
    pillowy in the middle, squarer toward the block-bottom ends, flat on the floor, its corners
    pulled out into the creased paper points at the ends."""
    noise = ctx.noise
    t = x / (SACK_L / 2)
    n = lerp(3.0, 5.0, end_k)
    b = SACK_W / 2 * (1 - 0.03 * t * t)
    c = SACK_H / 2 * (1 - 0.1 * t ** 4)
    yc = FLOOR + c
    pts = []
    for th in angs:
        co, si = math.cos(th), math.sin(th)
        z = b * math.copysign(abs(co) ** (2 / n), co)
        y = yc + c * math.copysign(abs(si) ** (2 / n), si)
        corner = abs(math.sin(2 * th)) ** 6 * end_k
        z += math.copysign(0.05 * corner, z)
        y += math.copysign(0.025 * corner, si)
        top = smoothstep(yc - 0.05, yc + c, y)
        # set hard in lumps, sagging a little in the middle, slightly bent along its length
        y += top * (0.07 * noise.fbm((x * 1.1, 0.3, z * 1.1), 3) - 0.03 * (1 - t * t))
        z += math.copysign(0.035 * noise.fbm((x * 1.6, y * 2, 5.0), 2), z)  # (lumpy sides)
        z += 0.05 * t * t - 0.03
        # creases across the top (folds of the paper set in the cement)
        for px, pz, ang, depth in ((-0.45, 0.1, 0.5, 0.03), (0.35, -0.2, 2.0, 0.025), (0.7, 0.25, 1.2, 0.02)):
            dl = abs((x - px) * math.sin(ang) - (z - pz) * math.cos(ang))
            y -= top * depth * math.exp(-((dl / 0.07) ** 2))
        pts.append((x, max(FLOOR, y), z))
    return pts


def cement_bag(ctx):
    """25 kg paper cement sack lying flat, set hard: block-bottom ends with pasted flaps, pointed
    corners, the valve, faded print bands, creases, one corner torn open and the powder spilt
    in a low drift with hard lumps (1.95 x 1.25, 0.45 tall; the drift reaches 0.6 further)."""
    ctx.budget = 3500
    ctx.smooth_angle = 48
    rng, noise = ctx.rng, ctx.noise
    angs = [2 * math.pi * k / 30 + math.pi / 30 for k in range(30)]  # (no point exactly on the floor line)
    hl = SACK_L / 2
    xs = [i / 9 * (hl - 0.07) for i in range(-9, 10)]
    for x0, x1, _ in BANDS:  # crisp band edges: two sections hugging each edge
        for e in (x0, x1):
            xs += [e - 0.012, e + 0.012]
    xs = sorted(set(round(x, 4) for x in xs))
    rings = [[(-hl - 0.012, FLOOR + SACK_H * 0.47, 0.02)]]
    # the block-bottom ends: the section closes onto a flat, slightly domed rectangle
    ends = [(-hl - 0.008, 0.55), (-hl, 0.9), (-hl + 0.025, 0.975)]
    for x, k in ends:
        ring = _sack_ring(ctx, x, angs, 1.0)
        cy = FLOOR + SACK_H / 2
        rings.append([(x, cy + (p[1] - cy) * k, 0.02 + (p[2] - 0.02) * k) for p in ring])
    for x in xs:
        rings.append(_sack_ring(ctx, x, angs, smoothstep(hl - 0.35, hl - 0.03, abs(x))))
    for x, k in reversed(ends):
        ring = _sack_ring(ctx, -x, angs, 1.0)
        cy = FLOOR + SACK_H / 2
        rings.append([(-x, cy + (p[1] - cy) * k, 0.02 + (p[2] - 0.02) * k) for p in ring])
    rings.append([(hl + 0.012, FLOOR + SACK_H * 0.47, 0.02)])
    sack = loft(rings)
    # the torn corner: front-left, top
    tc = Vector((-hl + 0.12, FLOOR + SACK_H * 0.72, -SACK_W / 2 + 0.12))

    def keep(c):
        d = (c - tc).length
        return d > 0.24 * (1 + 0.35 * noise.fbm(c * 7.0, 2))

    _delete_faces(sack, keep)
    ctx.add("Paper", sack)
    # the pasted block-bottom flaps on both ends, the valve sleeve tucked in at one top corner
    for sx in (-1, 1):
        flap = box(0.05, SACK_H * 0.5, SACK_W * 0.66, bevel=0.012)
        ctx.add("Paper", flap, T(sx * (hl + 0.006), FLOOR + SACK_H * 0.48, 0.02) @ R(rng.uniform(-3, 3), 0, 0))
    valve = box(0.06, 0.12, 0.3, bevel=0.015)
    ctx.add("Paper", valve, T(hl + 0.012, FLOOR + SACK_H * 0.78, 0.02 + SACK_W * 0.24) @ R(4, 0, 0))
    # torn paper flaps hanging from the tear (multiwall: thick, stiff)
    for a, length in ((0.3, 0.26), (1.9, 0.22)):
        base = tc + Vector((math.cos(a) * 0.2, 0.04, -math.sin(a) * 0.12 - 0.06))
        out = Vector((math.cos(a) * 0.4, 0, -1)).normalized()
        path = [base + out * (length * s) + Vector((0, -0.18 * s * s, 0)) for s in (0, 0.33, 0.66, 1.0)]
        ctx.add("Paper", _ribbon(path, [0.2, 0.18, 0.13, 0.05], 0.022, [Vector((0, 1, 0.4))] * 4, n=8, square=0.25))
    # the powder: filling the torn corner, and spilt in a low drift with hardened lumps
    ctx.add("Concrete", _lumpy_ball(0.24, noise, amp=0.2, scale=4.0, segs=12, rings=8, squash=(1.0, 0.75, 1.0)),
            T(tc.x + 0.12, tc.y - 0.1, tc.z + 0.12))
    drift_c = (tc.x - 0.04, tc.z - 0.3)
    seg = 30
    rings = [[(drift_c[0], FLOOR + 0.008 + 0.22, drift_c[1] + 0.08)]]
    for f, hfrac in ((0.2, 0.9), (0.42, 0.62), (0.62, 0.36), (0.8, 0.16), (0.93, 0.05), (1.0, 0.0)):
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            rr = 0.46 * f * (1 + 0.3 * noise.fbm((math.cos(a) * 1.5, 3.3, math.sin(a) * 1.5), 2))
            # (stretched back toward the sack: the powder poured down its side)
            px = drift_c[0] + math.cos(a) * rr * 1.25
            pz = drift_c[1] + math.sin(a) * rr * (1.0 if math.sin(a) < 0 else 0.75)
            # (the heap leans on the sack: higher on the sack side)
            lean = 1 + 0.35 * math.sin(a)
            y = FLOOR + 0.008 + 0.22 * hfrac * lean * (1 + 0.15 * noise.n((px * 5, 1.0, pz * 5)))
            ring.append((px, y, pz))
        rings.append(ring)
    rings.append([(drift_c[0], FLOOR, drift_c[1])])
    ctx.add("Concrete", loft(rings))
    for dx, dz, r in ((-0.38, -0.2, 0.09), (0.3, -0.35, 0.07), (-0.05, -0.5, 0.06)):
        ctx.add("Concrete", _lumpy_ball(r, noise, amp=0.35, scale=6.0, segs=8, rings=6, squash=(1.2, 0.7, 1.0),
                                        seed_off=dx * 9), T(drift_c[0] + dx, FLOOR + 0.05 + r * 0.5, drift_c[1] + dz))

    def paper(p):
        x, y, z = p.co
        k = (1.0, 1.0, 1.0)
        on_body = abs(x) < hl - 0.02
        for x0, x1, rgb in BANDS:
            if on_body and x0 <= x <= x1:
                fade = 0.6 + 0.2 * smoothstep(-0.4, 0.6, noise.fbm((x * 4, y * 4, z * 4), 2))  # sun-faded
                k = tuple(lerp(1.0, c, fade) for c in rgb)
        g = 0.86 - 0.36 * (1 - smoothstep(FLOOR, 0.16 * (1 + 0.5 * noise.fbm((x * 3, 0, z * 3), 2)), y))  # wet bottom
        g *= 1 - 0.35 * smoothstep(0.0, 0.5, -p.convex)  # creases
        g *= 1 - 0.24 * smoothstep(0.0, 0.6, noise.fbm((x * 2.5, y * 2.5, z * 2.5), 3))  # water stains
        g *= 1 - 0.12 * smoothstep(0.2, 0.8, noise.fbm((x * 9, y * 9, z * 9), 2))  # scuffs, footprints
        g *= 1 - 0.3 * math.exp(-(((Vector((x, y, z)) - tc).length / 0.35) ** 2))  # cement-wet round the tear
        return (k[0] * g, k[1] * g, k[2] * g)

    ctx.wear("Paper", paper)
    ctx.wear("Concrete", mul(cavity(0.3), lambda p: 1.0 - 0.12 * (1 - smoothstep(0.0, 0.06, p.co.y))))


# ----------------------------------------------------------------------------------------------
# Backpack. A worn 40 L top-loading rucksack standing on its base, slumped forward (real: ~55 x 32
# x 22 cm daypack/trekking hybrid; here 1.25 wide, 0.75 deep, 2.05 tall: the footprint of
# props_objects.backpack "standing"). What makes it read (real_specs.md): the soft body squarer
# at the back (padded back panel) and bulging at the front; a LID over the top with two straps
# coming down the front to plastic side-release buckles; a front pocket with its zip; mesh side
# pockets; padded S-curved shoulder straps on the back with their webbing to the bottom corners;
# the grab loop; grime on the base and the straps, the fabric shiny where it rubs.
# ----------------------------------------------------------------------------------------------
PACK_RINGS = [  # (scale of the section, height) from the base up into the dome under the lid
    (0.55, FLOOR), (0.84, FLOOR + 0.006), (0.95, 0.05), (1.0, 0.14), (1.0, 0.3), (1.0, 0.48), (1.0, 0.66),
    (1.0, 0.84), (1.0, 1.02), (0.99, 1.2), (0.98, 1.36), (0.965, 1.5), (0.94, 1.62), (0.9, 1.72),
    (0.83, 1.81), (0.72, 1.89), (0.56, 1.95), (0.34, 1.99),
]
PACK_TOP = 2.01


class _Pack:
    """The rucksack's body as a function: point(a, y) on its surface (a = angle round the
    vertical, 0 = +X, -pi/2 = the front), and helpers to find the surface along an axis."""

    def __init__(self, ctx):
        self.noise = ctx.noise

    def section(self, y):
        k = _interp([(yy, s) for s, yy in PACK_RINGS], y)
        t = y / PACK_TOP
        a = 0.62 - 0.05 * t * t  # half width
        bf = 0.33 + 0.08 * math.sin(math.pi * min(1.0, t * 1.1))  # front bulge (the load)
        bb = 0.27  # back panel
        zc = -0.1 * t * t  # slumped forward
        return k, a, bf, bb, zc

    def point(self, a, y):
        k, ha, bf, bb, zc = self.section(y)
        co, si = math.cos(a), math.sin(a)
        n = 3.0 if si < 0 else 4.2  # (the back is flatter, squarer)
        b = bf if si < 0 else bb
        x = ha * math.copysign(abs(co) ** (2 / n), co)
        z = b * math.copysign(abs(si) ** (2 / n), si)
        m = 1 + 0.035 * self.noise.fbm((co * 1.5, y * 1.6, si * 1.5), 3)
        # a slack fold across the front where the load has settled
        m -= 0.04 * math.exp(-(((y - 1.28) / 0.08) ** 2)) * max(0.0, -si)
        yy = y
        if y > 1.6:  # the top sags a little to the front
            yy -= 0.04 * max(0.0, -si) * (y - 1.6) / 0.4
        return Vector((x * k * m, yy, zc + z * k * m))

    def along(self, y, axis, value, lo, hi):
        """The surface point at height y whose `axis` coordinate is `value`, searching the angle
        between lo and hi (where that coordinate is monotonic)."""
        f_lo = self.point(lo, y)[axis] - value
        for _ in range(26):
            mid = (lo + hi) / 2
            f = self.point(mid, y)[axis] - value
            if (f < 0) == (f_lo < 0):
                lo, f_lo = mid, f
            else:
                hi = mid
        return self.point((lo + hi) / 2, y)

    def normal(self, a, y):
        p = self.point(a, y)
        da = self.point(a + 0.01, y) - p
        dy = self.point(a, y + 0.01) - p
        n = dy.cross(da)
        if n.length < 1e-9:
            return Vector((math.cos(a), 0, math.sin(a)))
        n.normalize()
        if n.dot(Vector((p.x, 0, p.z - self.section(y)[4]))) < 0:
            n = -n
        return n


def _patch(body_fn, outline, depth, rings=(1.0, 1.0, 0.96, 0.85, 0.62, 0.3), dz=(-0.05, 0.03, 0.4, 0.75, 0.93, 1.0)):
    """A soft panel bulging out of the body (a pocket, the back pad): `outline` = list of
    (u, v) points round its edge (unit square coordinates scaled by the caller), body_fn(u, v,
    lift) -> the point `lift` out of the body surface at (u, v). The first ring is sunk 0.05
    INTO the body (the seam: the surfaces cross, never coplanar), then the panel swells to
    `depth`, closing on a pole."""
    out = []
    for s, f in zip(rings, dz):
        out.append([tuple(body_fn(u * s, v * s, depth * f)) for u, v in outline])
    out.append([tuple(body_fn(0.0, 0.0, depth * 1.02))])
    return loft(out, cap_start=True)


def _squircle(n=24, p=3.5):
    pts = []
    for k in range(n):
        t = 2 * math.pi * k / n
        c, s = math.cos(t), math.sin(t)
        pts.append((math.copysign(abs(c) ** (2 / p), c), math.copysign(abs(s) ** (2 / p), s)))
    return pts


def backpack(ctx):
    """Worn top-loading rucksack standing slumped: soft bulging body, lid with two straps and
    buckles, zipped front pocket, mesh side pockets, padded S-curved shoulder straps, grab loop,
    grime on the base (1.25 x 0.75 + straps, 2.05 tall)."""
    ctx.budget = 4300
    ctx.smooth_angle = 50
    ctx.tint("Fabric", (66, 72, 54))  # faded olive Cordura (the data can pick navy, maroon, black)
    rng, noise = ctx.rng, ctx.noise
    pk = _Pack(ctx)
    angs = angles(32)
    rings = [[(0.0, FLOOR, -0.0)]]
    for s, y in PACK_RINGS:
        rings.append([tuple(pk.point(a, y)) for a in angs])
    rings.append([tuple(pk.point(0, PACK_TOP) * 0 + Vector((0, PACK_TOP, pk.section(PACK_TOP)[4])))])
    ctx.add("Fabric", loft(rings))

    # ---- the lid: a padded cap over the top, lower at the front, 0.02-0.07 off the body
    def rim(a):
        return 1.5 + 0.2 * math.sin(a)  # (front, sin < 0: lower)

    cen = Vector((0, 1.45, -0.08))

    def lid_pt(a, t, off):
        y = lerp(rim(a), PACK_TOP, t)
        p = pk.point(a, y) if y < PACK_TOP - 0.005 else Vector((0, PACK_TOP, pk.section(PACK_TOP)[4]))
        d = (p - cen).normalized()
        return p + d * off

    ts = (0.0, 0.25, 0.5, 0.72, 0.88, 0.97)
    lid = [[tuple(lid_pt(a, 0.0, 0.025)) for a in angs], [tuple(lid_pt(a, 0.0, 0.05) + Vector((0, -0.025, 0))) for a in angs]]
    for t in ts:
        lid.append([tuple(lid_pt(a, t, 0.075 + 0.02 * math.sin(math.pi * t))) for a in angs])
    lid.append([tuple(Vector((0, PACK_TOP, pk.section(PACK_TOP)[4])) + Vector((0, 0.085, 0)))])
    # (underside: from the inner rim to a point inside the body: closes the cap, hidden)
    ctx.add("Fabric", loft([[tuple(cen)]] + lid))

    # ---- lid straps down the front to their buckles, the lower webbing sewn to the body
    for sx in (-1, 1):
        a0 = -math.pi / 2 + sx * 0.5
        path, ups = [], []
        for y in (2.0, 1.92, 1.82, 1.7, 1.58, 1.46, 1.36, 1.26, 1.18):
            p = pk.along(y, 0, sx * 0.3, -math.pi, 0.0)
            a = math.atan2(p.z - pk.section(y)[4], p.x)
            nrm = pk.normal(a, y)
            over_lid = y > rim(a) - 0.04
            path.append(p + nrm * (0.105 if over_lid else 0.03))
            ups.append(nrm)
        ctx.add("FabricDark", _ribbon(path, 0.13, 0.024, ups, n=6, square=0.2))
        # the buckle where the strap meets the webbing
        y = 1.12
        p = pk.along(y, 0, sx * 0.3, -math.pi, 0.0)
        a = math.atan2(p.z - pk.section(y)[4], p.x)
        nrm = pk.normal(a, y)
        rot = Vector((0, 0, -1)).rotation_difference(-nrm).to_matrix().to_4x4()
        buckle = box(0.17, 0.2, 0.05, bevel=0.016, segments=1)
        ctx.add("PlasticDark", buckle, T(*(p + nrm * 0.045)) @ rot)
        tongue = box(0.12, 0.08, 0.035, bevel=0.01, segments=1)
        ctx.add("PlasticDark", tongue, T(*(pk.along(1.24, 0, sx * 0.3, -math.pi, 0.0) + nrm * 0.07)) @ rot)
        path = []
        for y in (1.06, 0.98, 0.9, 0.82):
            q = pk.along(y, 0, sx * 0.3, -math.pi, 0.0)
            path.append(q + nrm * 0.03)
        ctx.add("FabricDark", _ribbon(path, 0.12, 0.022, [nrm] * 4, n=6, square=0.2))

    # ---- the front pocket (bulging, zipped round its top)
    def front(u, v, lift):
        x, y = u * 0.42, 0.6 + v * 0.36
        p = pk.along(y, 0, x, -math.pi, 0.0)
        a = math.atan2(p.z - pk.section(y)[4], p.x)
        return p + pk.normal(a, y) * lift

    outline = _squircle(24, 3.2)
    ctx.add("Fabric", _patch(front, outline, 0.17))
    zip_path = []
    for k in range(10):
        t = math.pi * (0.06 + 0.88 * k / 9)
        u, v = math.cos(t), math.sin(t)
        su = math.copysign(abs(u) ** (2 / 3.2), u) * 0.95
        sv = math.copysign(abs(v) ** (2 / 3.2), v) * 0.95
        zip_path.append(front(su, sv, 0.17 * 0.4 + 0.022))
    zip_path.reverse()
    ctx.add("PlasticDark", _ribbon(zip_path, 0.05, 0.026, [Vector((0, 0.3, -1))] * len(zip_path), n=6, square=0.4))
    pull = zip_path[2]
    ctx.add("PlasticDark", box(0.05, 0.13, 0.03, bevel=0.01, segments=1), T(pull.x, pull.y - 0.06, pull.z - 0.012) @ R(-12, 0, 8))

    # ---- mesh side pockets with their elastic hem, a compression strap above each
    for sx in (-1, 1):
        def side(u, v, lift, sx=sx):
            z, y = u * 0.24 + 0.0, 0.5 + v * 0.34
            lo, hi = (-math.pi / 2, math.pi / 2) if sx > 0 else (math.pi / 2, 3 * math.pi / 2)
            if sx < 0:
                p = pk.along(y, 2, z, hi, lo)
            else:
                p = pk.along(y, 2, z, lo, hi)
            a = math.atan2(p.z - pk.section(y)[4], p.x)
            return p + pk.normal(a, y) * lift

        ctx.add("FabricDark", _patch(side, _squircle(18, 3.0), 0.13))
        hem = [side(u, 0.95, 0.13 * 0.55 + 0.02) for u in (-0.95, -0.6, -0.2, 0.2, 0.6, 0.95)]
        ctx.add("FabricDark", _ribbon(hem, 0.05, 0.035, [Vector((0, 1, 0))] * len(hem), n=6, square=0.5))
        strap = []
        ups = []
        for u in (-0.95, -0.6, -0.25, 0.1, 0.45, 0.8, 1.0):
            q = side(u * 1.25, 3.0, 0.03)
            strap.append(q)
            ups.append(Vector((sx, 0, 0)))
        ctx.add("FabricDark", _ribbon(strap, 0.1, 0.022, ups, n=6, square=0.2))
        bq = side(0.25, 3.0, 0.065)
        ctx.add("PlasticDark", box(0.05, 0.13, 0.16, bevel=0.014, segments=1), T(*bq))

    # ---- the back: padded panel, S-curved shoulder straps, grab loop
    def back(u, v, lift):
        x, y = u * 0.46, 1.0 + v * 0.66
        p = pk.along(y, 0, x, math.pi, 0.0)
        a = math.atan2(p.z - pk.section(y)[4], p.x)
        return p + pk.normal(a, y) * lift

    ctx.add("FabricDark", _patch(back, _squircle(20, 4.0), 0.06))
    for sx in (-1, 1):
        path, widths, ths, ups = [], [], [], []
        pts = [(0.2, 1.78, -0.02), (0.24, 1.66, 0.06), (0.3, 1.45, 0.16), (0.38, 1.2, 0.2), (0.45, 0.95, 0.16),
               (0.5, 0.7, 0.1), (0.53, 0.5, 0.05)]
        for i, (x, y, lift) in enumerate(pts):
            p = pk.along(y, 0, sx * x, math.pi, 0.0)
            a = math.atan2(p.z - pk.section(y)[4], p.x)
            nrm = pk.normal(a, y)
            path.append(p + nrm * (0.075 + lift))
            widths.append(0.24 if i < 5 else lerp(0.24, 0.11, (i - 4) / 2))
            ths.append(0.075 if i < 5 else lerp(0.075, 0.024, (i - 4) / 2))
            ups.append(nrm)
        ctx.add("FabricDark", _ribbon(path, widths, ths, ups, n=10, square=0.45))
        # the webbing from the strap's end to the bottom corner, with its ladder-lock
        end = path[-1]
        foot = pk.along(0.18, 0, sx * 0.55, math.pi, 0.0)
        a = math.atan2(foot.z - pk.section(0.18)[4], foot.x)
        fn = pk.normal(a, 0.18)
        web = [end, end.lerp(foot + fn * 0.03, 0.5) + fn * 0.03, foot + fn * 0.03]
        ctx.add("FabricDark", _ribbon(web, 0.1, 0.02, [fn] * 3, n=6, square=0.2))
        lk = end.lerp(foot, 0.25) + fn * 0.035
        ctx.add("PlasticDark", box(0.14, 0.06, 0.04, bevel=0.012, segments=1), T(*lk))
    top = Vector((0, PACK_TOP, pk.section(PACK_TOP)[4]))
    loop = [top + Vector((0, -0.12 + 0.13 * math.sin(math.pi * s), 0.28 - 0.06 * math.sin(math.pi * s)))
            + Vector((lerp(-0.1, 0.1, s), 0, 0)) for s in (0, 0.25, 0.5, 0.75, 1.0)]
    ctx.add("FabricDark", _ribbon(loop, 0.08, 0.025, [Vector((0, 0.2, 1))] * 5, n=6, square=0.3))

    def fabric(p):
        x, y, z = p.co
        k = 1 - 0.4 * (1 - smoothstep(FLOOR, 0.3 * (1 + 0.4 * noise.fbm((x * 3, 0, z * 3), 2)), y))  # base grime
        k *= 1 - 0.32 * smoothstep(0.0, 0.5, -p.convex)  # seams, folds, under the lid
        k *= 1 + 0.1 * smoothstep(0.1, 0.5, p.convex)  # rubbed shiny on the edges
        k *= 1 - 0.18 * smoothstep(0.15, 0.75, noise.fbm((x * 3.5, y * 3.5, z * 3.5), 3))  # stains
        k *= 1 - 0.1 * smoothstep(0.2, 0.7, noise.fbm((x * 1.5, y * 0.4, z * 1.5), 2))  # rain streaks
        return min(1.0, k) * 0.94

    ctx.wear("Fabric", fabric)
    ctx.wear("FabricDark", mul(ground_dirt(0.35, 0.35, noise), cavity(0.35), edge_wear(0.15)))
    ctx.wear("PlasticDark", mul(edge_wear(0.25), cavity(0.3)))


# ----------------------------------------------------------------------------------------------
# Cloth: a real simulation (Blender's cloth solver, headless) for the blankets and the sleeping
# bag. Folds are what make cloth read, and procedural noise never gets them right: here a sheet
# is laid over the floor (and what lies under it), then walls slide in and push it together so
# it buckles into real folds and piles up, exactly as a kicked-off blanket does. The sheet then
# gets its thickness (two closed slabs, so every layer is a closed mesh and the game's one-sided
# faces always point out).
# ----------------------------------------------------------------------------------------------
def _cloth(nu, nv, pos_fn, frames, thick, colliders=(), walls=(), bend=0.5, mass=0.3, stiff=15.0,
           friction=5.0, self_gap=None, compress=None):
    """Simulates a nu x nv sheet (pos_fn(i, j) -> its starting point, Roblox axes) for `frames`
    frames. colliders: closed bmeshes (Roblox axes) it rests on; the floor is always there.
    walls: (size or bmesh, start, end, f0, f1): a box of that size (frictionless) or that
    closed shape, sliding from start to end between frames f0 and f1 (Roblox axes). Returns the final points, index i * nv + j. Everything it makes is
    removed afterwards."""
    sc = bpy.context.scene
    made_obs, made_meshes = [], []

    def link(name, me):
        ob = bpy.data.objects.new(name, me)
        sc.collection.objects.link(ob)
        made_obs.append(ob)
        made_meshes.append(me)
        return ob

    verts = [to_blender(pos_fn(i, j)) for i in range(nu) for j in range(nv)]
    faces = [(i * nv + j, i * nv + j + 1, (i + 1) * nv + j + 1, (i + 1) * nv + j) for i in range(nu - 1) for j in range(nv - 1)]
    me = bpy.data.meshes.new("_cloth")
    me.from_pydata(verts, [], faces)
    ob = link("_cloth", me)
    m = ob.modifiers.new("Cloth", "CLOTH")
    st = m.settings
    st.quality = 7
    st.mass = mass
    st.tension_stiffness = stiff
    st.compression_stiffness = stiff if compress is None else compress
    st.shear_stiffness = stiff * 0.4
    st.bending_stiffness = bend
    st.air_damping = 2.0
    cs = m.collision_settings
    cs.collision_quality = 4
    cs.distance_min = thick / 2 + 0.012
    cs.use_self_collision = True
    # (self-collision closer than ~1/3 of an edge makes a flat sheet ripple at the grid scale:
    # thick slabs simply interpenetrate a little where folds touch, hidden inside each other)
    cs.self_distance_min = self_gap if self_gap is not None else min(thick * 0.6, 0.04)
    cs.self_friction = 8.0
    m.point_cache.frame_start = 1
    m.point_cache.frame_end = frames

    def collider(name, bm, fric):
        cm = bpy.data.meshes.new(name)
        bm.to_mesh(cm)
        bm.free()
        cm.transform(TO_BLENDER)
        co = link(name, cm)
        co.modifiers.new("Collision", "COLLISION")
        co.collision.cloth_friction = fric
        co.collision.thickness_outer = 0.01
        return co

    fl = bmesh.new()
    bmesh.ops.create_cube(fl, size=1)
    bmesh.ops.transform(fl, matrix=T(0, FLOOR - 0.5, 0) @ Matrix.Diagonal((40, 1, 40, 1)), verts=fl.verts)
    collider("_floor", fl, friction)
    for k, bm in enumerate(colliders):
        collider(f"_lump{k}", bm, friction)
    for k, (shape, a, b, f0, f1) in enumerate(walls):
        if isinstance(shape, bmesh.types.BMesh):
            w, fr = shape, friction
        else:
            w, fr = bmesh.new(), 0.0
            bmesh.ops.create_cube(w, size=1)
            bmesh.ops.transform(w, matrix=Matrix.Diagonal((shape[0], shape[1], shape[2], 1)), verts=w.verts)
        wo = collider(f"_wall{k}", w, fr)
        for f, at in ((1, a), (f0, a), (f1, b)):
            wo.location = to_blender(Vector(at))
            wo.keyframe_insert("location", frame=f)
    sc.frame_start, sc.frame_end = 1, frames
    for f in range(1, frames + 1):
        sc.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    em = ev.to_mesh()
    pts = [Vector((v.co.x, v.co.z, -v.co.y)) for v in em.vertices]  # (back to Roblox axes)
    ev.to_mesh_clear()
    sc.frame_set(1)
    for o in made_obs:
        bpy.data.objects.remove(o, do_unlink=True)
    for me in made_meshes:
        if me.users == 0:
            bpy.data.meshes.remove(me)
    for a in list(bpy.data.actions):
        if a.users == 0:
            bpy.data.actions.remove(a)
    return pts


def _uv_wear(pts, nu, nv, fn, stripes=False, bands=()):
    """Wear for a simulated sheet that also knows where on the cloth each vertex is (its grid
    row u along the length, 0..1): the woven stripes of a wool blanket near both ends, or the
    quilting lines of a sleeping bag (bands = list of (u0, u1, multiplier))."""
    kd = KDTree(len(pts))
    for k, p in enumerate(pts):
        kd.insert(p, k)
    kd.balance()
    lines = list(bands)
    if stripes:
        for u0, u1 in ((0.05, 0.075), (0.095, 0.11), (0.89, 0.905), (0.925, 0.95)):
            lines.append((u0, u1, 0.55))

    def wear(p):
        _co, k, _d = kd.find(p.co)
        u = (k // nv) / (nu - 1)
        m = 1.0
        for u0, u1, mult in lines:
            m *= lerp(1.0, mult, smoothstep(u0 - 0.012, u0, u) * (1 - smoothstep(u1, u1 + 0.012, u)))
        w = fn(p)
        return w * m if isinstance(w, (int, float)) else tuple(c * m for c in w)

    return wear


def _sheet_normals(pts, nu, nv):
    """Vertex normals of the simulated sheet, on the side that faced UP when it was laid."""
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    for i in range(nu - 1):
        for j in range(nv - 1):
            # (j along +X, i along +Z: this winding faces +Y on the flat sheet)
            bm.faces.new((vs[i * nv + j], vs[(i + 1) * nv + j], vs[(i + 1) * nv + j + 1], vs[i * nv + j + 1]))
    bm.normal_update()
    out = [v.normal.copy() for v in bm.verts]
    bm.free()
    return out


def _slab(pts, nrm, nu, nv, off_hi, off_lo):
    """A closed slab between two offsets of the sheet along its normals: off_hi(k) > off_lo(k)
    (k = vertex index). The top follows the sheet's winding, the bottom is reversed, the rim
    closes the four edges."""
    bm = bmesh.new()
    hi = [bm.verts.new(pts[k] + nrm[k] * off_hi(k)) for k in range(len(pts))]
    lo = [bm.verts.new(pts[k] + nrm[k] * off_lo(k)) for k in range(len(pts))]
    for i in range(nu - 1):
        for j in range(nv - 1):
            a, b, c, d = i * nv + j, (i + 1) * nv + j, (i + 1) * nv + j + 1, i * nv + j + 1
            bm.faces.new((hi[a], hi[b], hi[c], hi[d]))
            bm.faces.new((lo[d], lo[c], lo[b], lo[a]))
    ring = [i * nv for i in range(nu)] + [(nu - 1) * nv + j for j in range(1, nv)] + \
           [i * nv + nv - 1 for i in range(nu - 2, -1, -1)] + [j for j in range(nv - 2, 0, -1)]
    for k in range(len(ring)):
        a, b = ring[k], ring[(k + 1) % len(ring)]
        bm.faces.new((hi[b], hi[a], lo[a], lo[b]))
    return bm


# ----------------------------------------------------------------------------------------------
# Blankets1 / Blankets2. Old wool / fleece blankets (real: 150 x 200 cm, wool ~6 mm). 1 = one
# kicked off a bed and lying in a crumpled heap (simulated: pushed together on the floor over a
# lump, its folds piling up); 2 = a stack of three folded blankets (each folded in thirds: one
# side the round fold, the other the layered edges), sagging, not squared. Wool blankets carry
# the classic darker stripes near their ends. props_objects.blankets "crumpled" -> Blankets1,
# "folded" -> Blankets2.
# ----------------------------------------------------------------------------------------------
def blankets1(ctx):
    """Old wool blanket dropped in a heap: real folds (cloth simulation: draped over a ball that
    sinks to the floor, the cloth collapsing round it), the hem showing, darker stripes near its
    ends, grime (about 3 x 3, 0.8 tall)."""
    ctx.budget = 4200
    ctx.smooth_angle = 70
    ctx.tint("Fabric", (112, 52, 46))  # faded red wool (the data picks grey, brown, green...)
    rng, noise = ctx.rng, ctx.noise
    L, W, t = 4.6, 3.6, 0.07
    nu, nv = 31, 25

    def start(i, j):
        z = (i / (nu - 1) - 0.5) * L
        x = (j / (nv - 1) - 0.5) * W
        return Vector((x + 0.3, 2.3 + 0.05 * noise.n((x, 0.5, z)), z - 0.2))

    ball = _lumpy_ball(0.45, noise, amp=0.15, segs=14, rings=9, squash=(1.2, 0.9, 1.0))
    # (lowered askew, so the heap is lopsided and the folds fall one way)
    walls = [(ball, (0.0, 1.85, 0.0), (0.35, -0.12, -0.25), 25, 110)]
    pts = _cloth(nu, nv, start, 150, t, walls=walls, bend=1.5, mass=0.4, friction=60.0)
    nrm = _sheet_normals(pts, nu, nv)
    ctx.add("Fabric", _slab(pts, nrm, nu, nv, lambda k: t / 2, lambda k: -t / 2))

    def wool(p):
        x, y, z = p.co
        k = 1 - 0.3 * (1 - smoothstep(FLOOR, 0.25, y))  # grime where it lies on the floor
        k *= 1 - 0.4 * smoothstep(0.0, 0.45, -p.convex)  # deep in the folds
        k *= 1 - 0.15 * smoothstep(0.1, 0.7, noise.fbm((x * 2.2, y * 2.2, z * 2.2), 3))  # stains
        return k

    ctx.wear("Fabric", _uv_wear(pts, nu, nv, wool, stripes=True))



def _folded_blanket(ctx, Wx, D, th, seed):
    """One blanket folded in three: the fold side (-Z) a full round roll, the open side (+Z)
    the three layered edges with dark gaps between them, the top domed and sagging, the ends
    rounded; wobbly everywhere (cloth is never square). Bottom at y = 0."""
    nz = Noise(seed)
    out = []
    # bottom: fold side -> open side
    for k in range(6):
        out.append((lerp(-D / 2 + th / 2, D / 2 - 0.04, k / 5), 0.0))
    # the open side: three layers, each edge bulging, a notch between them
    for k in range(3):
        y0 = th * k / 3
        out.append((D / 2 - 0.035, y0 + 0.012))
        out.append((D / 2 + 0.01, y0 + th / 6))
        out.append((D / 2 - 0.03, y0 + th / 3 - 0.012))
    # top: open side -> fold side, domed
    for k in range(7):
        z = lerp(D / 2 - 0.04, -D / 2 + th / 2, k / 6)
        out.append((z, th + 0.03 * math.sin(math.pi * k / 6)))
    # the fold: a half round roll down to the bottom
    for k in range(1, 7):
        a = math.pi / 2 + math.pi * k / 7
        out.append((-D / 2 + th / 2 + math.cos(a) * th / 2, th / 2 + math.sin(a) * th / 2))
    rings = []
    xs = [lerp(-Wx / 2, Wx / 2, k / 12) for k in range(13)]
    cz, cy = 0.0, th / 2

    def section(x, shrink):
        ring = []
        for z, y in out:
            zz, yy = cz + (z - cz) * shrink, cy + (y - cy) * shrink
            t = x / (Wx / 2)
            yy -= 0.035 * (1 - t * t) * smoothstep(0, th, y)  # sags in the middle
            zz += 0.035 * nz.fbm((x * 1.3, 0.2, 0.0), 2) * smoothstep(0, D / 2, z)  # wavy open edge
            q = (x * 2.2, yy * 3.0, zz * 2.2)
            lump = 0.03 * nz.fbm(q, 3) * smoothstep(0.3 * th, th, y)  # (rucked, not ironed)
            ring.append((x + 0.025 * nz.n(q), max(0.0, yy + 0.015 * nz.fbm(q, 2) + lump), zz + 0.02 * nz.n((q[2], q[0], q[1]))))
        return ring

    rings.append([(-Wx / 2 - 0.035, th / 2, 0.0)])
    rings.append(section(-Wx / 2 - 0.025, 0.6))
    rings.append(section(-Wx / 2 - 0.008, 0.88))
    for x in xs:
        rings.append(section(x, 1.0))
    rings.append(section(Wx / 2 + 0.008, 0.88))
    rings.append(section(Wx / 2 + 0.025, 0.6))
    rings.append([(Wx / 2 + 0.035, th / 2, 0.0)])
    return loft(rings)


def blankets2(ctx):
    """Three old blankets folded and stacked (grey army wool, a green check, a beige fleece):
    round folds on one side, the layered edges on the other, sagging, askew, end stripes on the
    wool, grime (2.2 x 1.7, 0.75 tall)."""
    ctx.budget = 3200
    ctx.smooth_angle = 50
    ctx.tint("Fabric", (74, 88, 64))  # dull green wool (the data can pick another)
    rng, noise = ctx.rng, ctx.noise
    y = FLOOR
    stack = (("FabricDark", 2.05, 1.5, 0.24), ("Fabric", 1.95, 1.42, 0.22), ("Foam", 1.85, 1.38, 0.28))
    for k, (layer, Wx, D, th) in enumerate(stack):
        bm = _folded_blanket(ctx, Wx, D, th, rng.randrange(1 << 20))
        ry = rng.uniform(-9, 9) + (180 if k == 1 else 0)
        ctx.add(layer, bm, T(rng.uniform(-0.1, 0.1), y, rng.uniform(-0.08, 0.08)) @ R(0, ry, rng.uniform(-1.5, 1.5)))
        # each sinks into the one under it (soft wool squashed): its flat underside stays below
        # the lower one's sagging top everywhere, so no two surfaces ever share a plane
        y += th - 0.09

    def wool(stripes):
        def fn(p):
            x, yy, z = p.co
            k = 1 - 0.32 * (1 - smoothstep(FLOOR, 0.2, yy))
            k *= 1 - 0.45 * smoothstep(0.0, 0.4, -p.convex)  # the gaps between the layers
            k *= 1 - 0.14 * smoothstep(0.1, 0.7, noise.fbm((x * 2.5, yy * 2.5, z * 2.5), 3))
            if stripes:
                ax = abs(x)
                for x0, x1 in ((0.62, 0.7), (0.76, 0.8)):
                    k *= 1 - 0.4 * smoothstep(x0 - 0.02, x0, ax) * (1 - smoothstep(x1, x1 + 0.02, ax))
            return k

        return fn

    ctx.wear("FabricDark", wool(False))
    ctx.wear("Fabric", wool(True))
    ctx.wear("Foam", wool(False))


# ----------------------------------------------------------------------------------------------
# SleepingBag. A synthetic mummy sleeping bag (real: 215 x 78 cm shoulders, 50 cm at the foot,
# 5-10 cm loft; here 6.6 x 2.5 studs laid out, 0.22 thick) slept in and left BUNCHED in a heap
# (props_objects.sleeping_bag "bunched", footprint ~3 x 3, on the squat's mattress). Simulated
# like the blanket but stiff and puffy; what makes it read (real_specs.md): the quilted baffles
# (sewn lines across it every ~18 cm, pinched in and darker), the coil zip with its draft tube
# down one side and its puller, the tapered mummy outline with the rounded hood, the nylon
# shell's sheen, grime at the head end.
# ----------------------------------------------------------------------------------------------
def sleeping_bag(ctx):
    """Mummy sleeping bag left bunched in a heap (cloth simulation): puffy quilted baffles, the
    side zip with its puller, tapered foot, rounded hood, grimy head end (about 3 x 3, 1.1
    tall)."""
    ctx.budget = 4200
    ctx.smooth_angle = 70
    ctx.tint("Fabric", (44, 58, 86))  # faded navy ripstop (the data picks red, olive, grey...)
    noise = ctx.noise
    L, W, t = 6.6, 2.5, 0.3
    nu, nv = 48, 15
    baffle = 0.55

    def width(u):
        w = _interp([(0.0, 0.5), (0.04, 0.6), (0.15, 0.64), (0.65, 1.0), (0.86, 0.98), (0.95, 0.85), (1.0, 0.55)], u)
        return W * w

    def start(i, j):
        u = i / (nu - 1)
        z = (u - 0.5) * L
        x = (j / (nv - 1) - 0.5) * width(u)
        # laid out flat a little above the floor, with a gentle wave and a side-to-side tilt to
        # seed the folds' direction; then pushed together from both ends (moving walls) so it
        # buckles into the bunched, puffy heap of a bag kicked off in the morning
        return Vector((x + 0.25 * math.sin(u * 3.0), FLOOR + 0.55 + 0.06 * x + 0.1 * math.sin(u * 9.0 + 0.7), z))

    lump = _lumpy_ball(0.6, noise, amp=0.25, segs=12, rings=8, squash=(1.3, 0.55, 1.0))
    bmesh.ops.transform(lump, matrix=T(0.15, FLOOR + 0.2, -0.3), verts=lump.verts)
    end = L / 2 + 0.4
    walls = [((6.0, 3.0, 0.4), (0.0, 1.5, -end), (0.0, 1.5, -1.55), 8, 95),
             ((6.0, 3.0, 0.4), (0.0, 1.5, end), (0.0, 1.5, 1.45), 8, 95)]
    pts = _cloth(nu, nv, start, 130, t, colliders=[lump], walls=walls, bend=2.0, mass=0.5, friction=40.0)
    nrm = _sheet_normals(pts, nu, nv)

    def puff(k):
        # each baffle swells between its sewn lines (pinched to 30 % on the line, thinner at the side seams)
        u = (k // nv) / (nu - 1) * L
        d = abs(((u + baffle / 2) % baffle) - baffle / 2) / (baffle / 2)
        j = k % nv
        edge = min(j, nv - 1 - j) / 2.0
        return t / 2 * (0.3 + 0.7 * smoothstep(0.0, 0.9, d) ** 0.7) * (0.6 + 0.4 * min(1.0, edge))

    ctx.add("Fabric", _slab(pts, nrm, nu, nv, puff, lambda k: -puff(k)))
    # the coil zip with its draft tube, down the +side edge from the hood to near the foot
    zp = [pts[i * nv + nv - 1] for i in range(nu - 1, 6, -1)]
    zn = [nrm[i * nv + nv - 1] for i in range(nu - 1, 6, -1)]
    side = []
    for i in range(nu - 1, 6, -1):
        a, b = pts[i * nv + nv - 1], pts[i * nv + nv - 2]
        side.append((a - b).normalized())
    path = [p + sd * 0.02 for p, sd in zip(zp, side)]
    ctx.add("PlasticDark", _ribbon(path, 0.07, 0.11, zn, n=6, square=0.6))
    pull = path[4] + side[4] * 0.06
    rot = Vector((0, 0, -1)).rotation_difference(side[4]).to_matrix().to_4x4()
    ctx.add("Metal", box(0.07, 0.04, 0.16, bevel=0.012, segments=1), T(*pull) @ rot)
    # the hood's drawcord and its cord lock, dangling from the head end
    head = pts[(nu - 1) * nv + nv // 2]
    hn = nrm[(nu - 1) * nv + nv // 2]
    cord = [head + hn * 0.05, head + hn * 0.1 + Vector((0.08, -0.1, 0)), head + Vector((0.14, -0.3, 0.05)),
            Vector((head.x + 0.18, FLOOR + 0.05, head.z + 0.12))]
    cord[-1].y = max(cord[-1].y, FLOOR + 0.03)
    ctx.add("Black", _ribbon(cord, 0.035, 0.035, [Vector((0, 0, 1))] * 4, n=6, square=1.0))
    ctx.add("PlasticDark", box(0.08, 0.12, 0.08, bevel=0.02, segments=1), T(*(cord[2] + Vector((0, -0.04, 0)))))

    def shell(p):
        x, y, z = p.co
        k = 1 - 0.3 * (1 - smoothstep(FLOOR, 0.35, y))
        k *= 1 - 0.42 * smoothstep(0.0, 0.45, -p.convex)
        k *= 1 - 0.15 * smoothstep(0.1, 0.7, noise.fbm((x * 2, y * 2, z * 2), 3))
        return k

    bands = []
    for b in range(1, int(L / baffle)):
        u = b * baffle / L
        bands.append((u - 0.008, u + 0.008, 0.62))
    # grime at the head end (the hood, where the face and hair were)
    wear = _uv_wear(pts, nu, nv, shell, bands=bands + [(0.88, 1.01, 0.72)])
    ctx.wear("Fabric", wear)
    ctx.wear("PlasticDark", mul(cavity(0.3), edge_wear(0.2)))


PIECES = {
    "TrashBag1": trash_bag1,
    "TrashBag2": trash_bag2,
    "TrashBag3": trash_bag3,
    "CementBag": cement_bag,
    "Backpack": backpack,
    "Blankets1": blankets1,
    "Blankets2": blankets2,
    "SleepingBag": sleeping_bag,
}
