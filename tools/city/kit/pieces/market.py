"""The black market's goods and fittings in the city prop kit: an old CRT television, a 90s
boombox, a leather jacket and a hoodie on their hangers, the chrome clothes rail they hang on,
the stall's tarp canopy on its four poles, and the table goods: an open aluminium watch case,
an open steel cash box and a cardboard tray of used phones.

Why these are meshes: the old props were boxes in boxes. The TV was a box with a box on its
back and a flat "screen" card; the boombox a box with discs stuck on; the jackets slabs with
a "collar" box sunk in them; the canopy five flat strips; the table goods (the player's photo)
stacks of boxes inside boxes whose floors and linings shared planes and flickered. Here:
  * hard goods (TV, boombox, cases, phones) are lofts of ROUNDED-RECTANGLE rings (_rr, _rr_loft):
    a shell, its bevels and its recesses in one closed skin (the TV's bezel steps into the
    opening that holds the bulging glass; the cash box and the watch case are hollow trays with
    a rolled lip and a floor of their own), details proud of the faces they sit on or crossing
    them at an angle, never lying in their plane;
  * soft goods (jackets, hoodie, tarp) are sculpted: the garments are lofted horizontal rings
    following a real hanging silhouette (shoulders sloping down the hanger's arms, a chest that
    swells, a hem that pulls in), with drape folds falling from the hanger tips, sleeves swept
    down the sides; the tarp is a grid laid over the poles with a sag curve, tension creases
    radiating from the pole tops and a torn hole cut through it (a closed slab with its cut
    edge walled: no zero-thickness face anywhere);
  * wear is vertex colour (a multiplier, see kitlib): dust on tops, grime toward the floor and
    in creases, edges rubbed (silver worn to dark on the boombox), stains where hands touch.

Conventions (pieces/_template.py): Roblox axes, studs, +Y up, the front faces -Z. Floor and
table pieces: origin at the centre of the footprint on the surface they stand on; each piece's
lowest point is FLOOR (0.012) above it, never in its plane. The jackets hang: their origin is
the centre of the rail their hook hangs on (see jacket docstrings). Only ONE tintable layer per
piece (the marker's Tint goes to every tintable layer). No bottles of any kind, nothing that
reads as one.
"""

import math

import bmesh
from mathutils import Matrix, Vector

from kitlib import (  # noqa: F401
    T,
    R,
    S,
    Noise,
    box,
    cyl,
    sphere,
    lathe,
    loft,
    tube,
    lerp,
    smoothstep,
    mul,
    ground_dirt,
    cavity,
    edge_wear,
    streaks,
    scuffs,
)

FLOOR = 0.012  # lowest point of every piece above the surface it stands on


# ----------------------------------------------------------------------------------------------
# Shared helpers
# ----------------------------------------------------------------------------------------------
def _rr(w, h, r, k=4, m=0, cx=0.0, cy=0.0):
    """A rounded rectangle w x h centred on (cx, cy): its outline as 2-D points, k segments in
    each corner and m extra points on each straight side, always 4 * (k + 1 + m) points, starting
    at the bottom of the right side and going counter-clockwise. The same (k, m) gives the same
    count for any size, so rings of different sizes loft into clean quads."""
    r = max(1e-3, min(r, w / 2 - 1e-3, h / 2 - 1e-3))
    cs = [(w / 2 - r, -h / 2 + r, -90.0), (w / 2 - r, h / 2 - r, 0.0), (-w / 2 + r, h / 2 - r, 90.0),
          (-w / 2 + r, -h / 2 + r, 180.0)]
    pts = []
    for i, (x, y, a0) in enumerate(cs):
        arc = []
        for s in range(k + 1):
            a = math.radians(a0 + 90.0 * s / k)
            arc.append((cx + x + r * math.cos(a), cy + y + r * math.sin(a)))
        pts += arc
        nx, ny, na = cs[(i + 1) % 4]
        a1 = math.radians(na)
        nxt = (cx + nx + r * math.cos(a1), cy + ny + r * math.sin(a1))
        for j in range(1, m + 1):
            t = j / (m + 1)
            pts.append((lerp(arc[-1][0], nxt[0], t), lerp(arc[-1][1], nxt[1], t)))
    return pts


def _rr_loft(stations, plane="xy", k=4, m=0, cap_start=True, cap_end=True, warp=None):
    """A closed solid lofted through rounded-rectangle rings. stations = [(pos, w, h, r, cx, cy)]:
    plane "xy" puts each ring in an X-Y plane at z = pos (w along X, h along Y: a TV shell going
    back), plane "xz" in a horizontal plane at y = pos (w along X, h along Z: a tray going up).
    warp(Vector) -> Vector moves every point (dents, squash)."""
    rings = []
    for pos, w, h, r, cx, cy in stations:
        ring = []
        for a, b in _rr(w, h, r, k, m, cx, cy):
            p = Vector((a, b, pos)) if plane == "xy" else Vector((a, pos, b))
            ring.append(tuple(warp(p) if warp else p))
        rings.append(ring)
    return loft(rings, cap_start=cap_start, cap_end=cap_end)


def _rbox(w, h, d, r, at=(0, 0, 0), k=2):
    """A rounded box w x h x d (every edge and corner rounded by r, true sphere-octant corners)
    from rounded-rectangle rings stacked along Z: softer than kitlib.box for small hard parts
    (buttons, knobs, feet). `at` = its centre."""
    r = max(1e-3, min(r, w / 2 - 2e-3, h / 2 - 2e-3, d / 2 - 2e-3))
    st = []
    for s in range(k + 1):
        a = math.radians(90.0 * s / k)
        st.append((-d / 2 + r - r * math.cos(a), a))
    for s in range(k, -1, -1):
        a = math.radians(90.0 * s / k)
        st.append((d / 2 - r + r * math.cos(a), a))
    stations = [(z, w - 2 * r + 2 * r * math.sin(a), h - 2 * r + 2 * r * math.sin(a), r * math.sin(a), 0, 0)
                for z, a in st]
    bm = _rr_loft(stations, "xy", k=k)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(at))
    return bm


def _rpoly(poly, r, k=3, inset=0.0):
    """A convex polygon [(a, b)] (counter-clockwise) with its corners rounded by r and the
    whole outline moved `inset` inward: k + 1 points per corner (same count for any inset, so
    insets loft cleanly). r may be one radius or one per corner."""
    n = len(poly)
    rs = r if isinstance(r, (list, tuple)) else [r] * n
    P = [Vector((p[0], p[1])) for p in poly]
    out = []
    for i in range(n):
        a, b, c = P[i - 1], P[i], P[(i + 1) % n]
        e1, e2 = (b - a).normalized(), (c - b).normalized()
        n1, n2 = Vector((-e1.y, e1.x)), Vector((-e2.y, e2.x))  # inward normals (CCW)
        rr = max(rs[i] - inset, 1e-3)
        off = inset + rr  # the arc's centre: offset from both edges by inset + rr
        # intersection of the two edges moved inward by `off`
        p1, p2 = a + n1 * off, b + n2 * off
        den = e1.x * e2.y - e1.y * e2.x
        t = ((p2 - p1).x * e2.y - (p2 - p1).y * e2.x) / den
        ctr = p1 + e1 * t
        a0 = math.atan2(-n1.y, -n1.x)
        a1 = math.atan2(-n2.y, -n2.x)
        while a1 < a0:
            a1 += 2 * math.pi
        for s in range(k + 1):
            ang = a0 + (a1 - a0) * s / k
            out.append((ctr.x + rr * math.cos(ang), ctr.y + rr * math.sin(ang)))
    return out


def _ext(poly, x0, x1, r, bevel, k=3, kb=2, axis="x"):
    """A convex side profile `poly` (counter-clockwise in (a, b)) extruded from x0 to x1 along
    `axis`, every edge rounded: the profile's corners by r, both ends by `bevel` (stations
    inset like a rounded box). axis "x": (a, b) = (z, y); axis "z": (a, b) = (x, y)."""
    st = []
    for s in range(kb + 1):
        a = math.radians(90.0 * s / kb)
        st.append((x0 + bevel - bevel * math.cos(a), bevel * (1 - math.sin(a))))
    for s in range(kb, -1, -1):
        a = math.radians(90.0 * s / kb)
        st.append((x1 - bevel + bevel * math.cos(a), bevel * (1 - math.sin(a))))
    rings = []
    for x, ins in st:
        ring = []
        for a, b in _rpoly(poly, r, k, ins):
            ring.append((x, b, a) if axis == "x" else (a, b, x))
        rings.append(ring)
    return loft(rings, cap_start=True, cap_end=True)


def _sweep(points, section, ups=None, cap=True, closed=False):
    """A tube along `points` with any cross-section: section = [(u, v)] (a closed 2-D outline
    in the plane across the path, u to the side, v toward `ups`), or a function i -> such a
    list (a sleeve flattening toward the cuff). ups = one Vector or one per point (which way is
    'v'); defaults to +Y bent away from the path direction."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    rings = []
    for i, p in enumerate(pts):
        if closed:
            d = pts[(i + 1) % n] - pts[i - 1]
        else:
            d = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        d.normalize()
        up = Vector((0, 1, 0)) if ups is None else Vector(ups if isinstance(ups, Vector) else ups[i])
        if abs(up.dot(d)) > 0.98:
            up = Vector((0, 0, -1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        up = (up - d * up.dot(d)).normalized()
        side = d.cross(up)
        sec = section(i) if callable(section) else section
        rings.append([tuple(p + side * u + up * v) for u, v in sec])
    return loft(rings, closed_profile=closed, cap_start=cap and not closed, cap_end=cap and not closed)


def _ellipse(a, b, n=10, rot=0.0):
    return [(a * math.cos(2 * math.pi * s / n + rot), b * math.sin(2 * math.pi * s / n + rot)) for s in range(n)]


def _torus(R_, r, segs=12, rsegs=6):
    """A ring round Y (a grommet, a coin edge): major radius R_, tube radius r."""
    prof = [(R_ + r * math.cos(2 * math.pi * k / rsegs), r * math.sin(2 * math.pi * k / rsegs)) for k in range(rsegs)]
    return lathe(prof, segs=segs)


def _align_y(n):
    """A rotation matrix taking +Y onto the direction n."""
    return Vector((0, 1, 0)).rotation_difference(Vector(n).normalized()).to_matrix().to_4x4()


def _grid_slab(top, bot, keep=None):
    """A closed slab between two grids of points (rows x cols), `top` and `bot`. keep(i, j) ->
    False drops cell (i, j) (a tear); every edge left open by a dropped cell or by the border is
    walled from top to bottom, so the slab stays closed (no see-through, one-sided safe)."""
    rows, cols = len(top), len(top[0])
    bm = bmesh.new()
    vt = [[bm.verts.new(p) for p in r] for r in top]
    vb = [[bm.verts.new(p) for p in r] for r in bot]
    cells = {(i, j) for i in range(rows - 1) for j in range(cols - 1) if keep is None or keep(i, j)}
    for i, j in cells:
        bm.faces.new((vt[i][j], vt[i + 1][j], vt[i + 1][j + 1], vt[i][j + 1]))
        bm.faces.new((vb[i][j + 1], vb[i + 1][j + 1], vb[i + 1][j], vb[i][j]))
    # the walls: each cell edge with a kept cell on one side only
    for i, j in cells:
        for (a, b), nb in ((((i, j), (i + 1, j)), (i, j - 1)), (((i + 1, j), (i + 1, j + 1)), (i + 1, j)),
                           (((i + 1, j + 1), (i, j + 1)), (i, j + 1)), (((i, j + 1), (i, j)), (i - 1, j))):
            if nb in cells:
                continue
            bm.faces.new((vt[b[0]][b[1]], vt[a[0]][a[1]], vb[a[0]][a[1]], vb[b[0]][b[1]]))
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    return bm


def _tray(w, d, h, wall, floor, r, y0=0.0, bevel=0.015, lip=0.0, k=4, m=1, warp=None):
    """An open tray / box body as ONE closed skin: up the outside from a bevelled bottom edge, over
    the rim (a rolled lip `lip` wide bulging outward if > 0), down the inside to its own floor
    `floor` above the bottom. Footprint w x d (X, Z), corner radius r, bottom at y0."""
    b = bevel
    st = [(y0, w - 2 * b, d - 2 * b, r - b, 0, 0), (y0 + b * 0.3, w - b * 0.6, d - b * 0.6, r - b * 0.3, 0, 0),
          (y0 + b, w, d, r, 0, 0)]
    if lip > 0:
        st += [(y0 + h - 2.2 * lip, w, d, r, 0, 0), (y0 + h - 1.6 * lip, w + lip, d + lip, r + lip / 2, 0, 0),
               (y0 + h - 0.4 * lip, w + lip, d + lip, r + lip / 2, 0, 0), (y0 + h, w - wall * 0.4, d - wall * 0.4, r, 0, 0)]
    else:
        st += [(y0 + h - b, w, d, r, 0, 0), (y0 + h - b * 0.3, w - b * 0.6, d - b * 0.6, r - b * 0.3, 0, 0),
               (y0 + h, w - wall * 0.5, d - wall * 0.5, r - wall * 0.25, 0, 0)]
    st += [(y0 + h - 0.006, w - 2 * wall, d - 2 * wall, max(r - wall, 0.004), 0, 0),
           (y0 + floor + 0.01, w - 2 * wall, d - 2 * wall, max(r - wall, 0.004), 0, 0),
           (y0 + floor, w - 2 * wall - 0.02, d - 2 * wall - 0.02, max(r - wall - 0.01, 0.003), 0, 0)]
    return _rr_loft(st, "xz", k=k, m=m, warp=warp)


def _rr_band(w, d, r, y0, y1, inset, out, k=4, m=1):
    """A closed rounded-rectangle ring band (an extrusion round a case's edge): from `inset`
    inside the outline w x d to `out` outside it, from y0 to y1, its outer edges rounded."""
    e = min(0.012, (y1 - y0) / 3, (out + inset) / 3)
    prof = [(-inset, y0), (out - e, y0), (out, y0 + e), (out, y1 - e), (out - e, y1), (-inset, y1)]
    rings = []
    for o, y in prof:
        rings.append([(a, y, b) for a, b in _rr(w + 2 * o, d + 2 * o, max(r + o, 0.004), k, m)])
    return loft(rings, closed_profile=True)


def _dust_top(noise, strength=0.22, base=0.8):
    """Dust settled on upward faces of a dark object: the colour multiplier is `base` on sides and
    rises to 1 on tops (the default tint is the dusty top colour), patchy."""

    def fn(p):
        up = smoothstep(0.35, 0.9, p.normal.y)
        k = base + (1 - base) * up * (0.7 + 0.3 * noise.fbm(p.co * 3.0, 2))
        return k * (1 - strength * 0.25 * (1 - up) * (0.5 + 0.5 * noise.fbm(p.co * 6.0, 2)))

    return fn


def _hand_grime(noise, at, rad, strength=0.25):
    """Darker where hands touch, round `at` (a handle, a door edge)."""
    at = Vector(at)

    def fn(p):
        d = (p.co - at).length / rad
        return 1 - strength * (1 - smoothstep(0.3, 1.0, d)) * (0.7 + 0.3 * noise.fbm(p.co * 8, 2))

    return fn


# ----------------------------------------------------------------------------------------------
# CRT television
# ----------------------------------------------------------------------------------------------
def crt_tv(ctx):
    """Old 20-inch CRT television (2.0 x 1.55 x 1.6): a thick front shell with a bevelled bezel
    stepping into the screen opening, the convex glass with rounded corners, the deep back
    tapering in two steps to the tube's neck hump (vent slots on top and back), slotted speaker
    grilles under the screen, a door flap over the controls, power button and red LED, a badge,
    rabbit-ear aerial on top and the mains cable out of the back. Dusty top, grime low down."""
    ctx.budget = 6500
    ctx.smooth_angle = 40
    ctx.tint("Plastic", (58, 56, 54))  # 90s dark grey (the data can tint beige: 150, 140, 118)
    noise = ctx.noise
    W, H, D = 2.0, 1.55, 1.6
    zf = -D / 2  # the front face
    y0 = FLOOR + 0.035  # the shell's underside (on four rubber feet)
    hs = H - y0  # shell height
    yc = y0 + hs / 2
    # the screen opening (a 20" tube: ~41 x 31 cm visible, higher than centre)
    ow, oh, ocy = 1.46, 1.08, y0 + hs - 0.13 - 0.54
    k, m = 4, 2
    b = 0.05  # bevel round the front edge
    st = [
        (-0.36, W - 0.03, hs - 0.03, 0.09, 0, yc),  # the back of the front shell (lip)
        (-0.38, W, hs, 0.1, 0, yc),
        (zf + b, W, hs, 0.1, 0, yc),
        (zf + b * 0.3, W - b * 0.9, hs - b * 0.9, 0.1 - b * 0.4, 0, yc),
        (zf, W - 2 * b, hs - 2 * b, 0.07, 0, yc),  # the flat front face ...
        (zf, ow + 0.1, oh + 0.1, 0.12, 0, ocy),  # ... to the bezel's edge
        (zf + 0.05, ow + 0.02, oh + 0.02, 0.1, 0, ocy),  # the bezel chamfers into the opening
        (zf + 0.1, ow, oh, 0.09, 0, ocy),
        (zf + 0.1, ow - 0.1, oh - 0.1, 0.06, 0, ocy),  # (hidden behind the glass)
    ]
    ctx.add("Plastic", _rr_loft(st, "xy", k=k, m=m, cap_start=True, cap_end=True))
    # the glass: a convex slab with rounded corners, its rim 0.075 behind the front face, its
    # centre bulging to 0.012 behind it (a real tube face is a shallow dome)
    gw, gh = ow - 0.02, oh - 0.02
    nu, nv = 14, 11
    top, bot = [], []
    for i in range(nu):
        rt, rb = [], []
        for j in range(nv):
            u, v = 2 * i / (nu - 1) - 1, 2 * j / (nv - 1) - 1
            # squircle-ish domain: pull the corners in
            cu, cv = u * math.sqrt(1 - 0.5 * v * v * 0.35), v * math.sqrt(1 - 0.5 * u * u * 0.35)
            x, y = cu * gw / 2, ocy + cv * gh / 2
            dome = (1 - cu * cu) * (1 - cv * cv)
            z = zf + 0.075 - 0.063 * (0.35 * (1 - cu * cu) + 0.35 * (1 - cv * cv) + 0.3 * dome)
            rt.append(Vector((x, y, z)))
            rb.append(Vector((x, y, z + 0.035)))
        top.append(rt)
        bot.append(rb)
    ctx.add("Screen", _grid_slab(top, bot))
    # the back: tapering in two steps to the neck hump, its underside rising off the floor
    back = [
        (-0.40, W - 0.16, hs - 0.14, 0.12, 0, yc),
        (-0.05, W - 0.34, hs - 0.3, 0.14, 0, yc + 0.06),
        (0.28, W - 0.52, hs - 0.44, 0.15, 0, yc + 0.1),
        (0.31, W - 0.56, hs - 0.48, 0.15, 0, yc + 0.1),
        (0.33, W - 0.86, hs - 0.7, 0.14, 0, yc + 0.14),  # the step to the hump
        (0.36, W - 0.9, hs - 0.74, 0.14, 0, yc + 0.14),
        (D / 2 - 0.05, W - 1.12, hs - 0.86, 0.13, 0, yc + 0.16),
        (D / 2 - 0.01, W - 1.16, hs - 0.9, 0.11, 0, yc + 0.16),
        (D / 2, W - 1.22, hs - 0.96, 0.08, 0, yc + 0.16),
    ]
    ctx.add("Plastic", _rr_loft(back, "xy", k=k, m=1))
    # vent slots: dark strips across the top of the back, crossing its slope a hair proud of it
    def back_top(z):
        for (z0, _w0, h0, _r0, _c0, cy0), (z1, _w1, h1, _r1, _c1, cy1) in zip(back, back[1:]):
            if z0 <= z <= z1:
                t = (z - z0) / max(z1 - z0, 1e-6)
                return lerp(cy0 + h0 / 2, cy1 + h1 / 2, t), (cy1 + h1 / 2 - cy0 - h0 / 2) / max(z1 - z0, 1e-6)
        return back[-1][5] + back[-1][2] / 2, 0.0

    for row, (za, zb) in enumerate(((-0.3, -0.12), (0.0, 0.2), (0.44, 0.66))):
        zm = (za + zb) / 2
        yt, slope = back_top(zm)
        wid = (W - 0.5 - 0.35 * row) / 2
        n_sl = 9 - 2 * row
        for s in range(n_sl):
            x = -wid + 2 * wid * (s + 0.5) / n_sl
            ang = math.degrees(math.atan(slope))
            ctx.add("Black", _rbox(0.07, 0.024, zb - za, 0.01, k=1), T(x, yt + 0.003, zm) @ R(ang, 0, 0))
    # the back panel at the hump: a recessed screw plate and vents (proud strips)
    zb_ = D / 2
    for s in range(7):
        y = yc + 0.16 - 0.22 + s * 0.075
        ctx.add("Black", _rbox(0.5, 0.032, 0.03, 0.01, k=1), T(0, y, zb_ + 0.005))
    # four rubber feet
    for sx in (-1, 1):
        for sz in (-1, 1):
            ctx.add("Rubber", cyl(0.07, 0.04, 12, bevel=0.012), T(sx * 0.78, FLOOR + 0.02, zf + 0.12 if sz < 0 else -0.5))
    # under the screen: two slotted speaker grilles, the badge, the control door, power + LED
    gy = y0 + 0.155
    for sx in (-1, 1):
        gx = sx * 0.62
        ctx.add("Black", _rbox(0.52, 0.17, 0.03, 0.03), T(gx, gy, zf - 0.006))
        for s in range(6):
            ctx.add("Plastic", _rbox(0.5, 0.016, 0.03, 0.007, k=1), T(gx, gy - 0.07 + s * 0.028, zf - 0.016))
    ctx.add("Chrome", _rbox(0.24, 0.05, 0.03, 0.015), T(0, y0 + 0.21, zf - 0.006))  # the badge
    # the control door: a flap 1 cm proud, a finger notch in its top edge
    ctx.add("Plastic", _rbox(0.36, 0.1, 0.04, 0.02), T(0.0, y0 + 0.1, zf - 0.012))
    ctx.add("Black", _rbox(0.08, 0.02, 0.03, 0.008), T(0.0, y0 + 0.148, zf - 0.025))
    # power button (left of the badge) and the standby LED
    ctx.add("PlasticDark", _rbox(0.09, 0.07, 0.05, 0.02), T(-0.27, y0 + 0.11, zf - 0.016))
    ctx.add("Glow", sphere(0.012, 8, 5), T(0.27, y0 + 0.11, zf - 0.006))
    # rabbit ears: an oval base on top, two telescopic chrome rods in a V, ball tips
    ty = yc + 0.16 + (hs - 0.9) / 2  # the hump's top... the aerial sits on the shell's top instead
    ty = y0 + hs
    base = lathe([(0.0, 0.0), (0.2, 0.0), (0.21, 0.02), (0.18, 0.06), (0.1, 0.09), (0.0, 0.095)], segs=20)
    bmesh.ops.scale(base, vec=(1.0, 1.0, 0.7), verts=base.verts)
    ctx.add("PlasticDark", base, T(0.25, ty + 0.004, 0.05))
    for s, (ax, az) in enumerate(((-34, 12), (28, -8))):
        rod_dir = R(az, 0, ax) @ Vector((0, 1, 0))
        p0 = Vector((0.25, ty + 0.07, 0.05)) + Vector((math.copysign(0.05, ax), 0, 0))
        lens = (0.38, 0.34, 0.3) if s == 0 else (0.38, 0.34, 0.12)  # one rod half pushed in
        rad = (0.022, 0.016, 0.011)
        p = p0
        for k_, (ln, rr) in enumerate(zip(lens, rad)):
            # each thinner segment starts inside the end of the one below, whose end carries a
            # collar ring (radius 1.3x, clear of both tubes)
            q = p + rod_dir * ln
            ctx.add("Chrome", tube([p - rod_dir * (0.03 if k_ else 0.0), q], rr, segs=8))
            if k_ < 2:
                ctx.add("Chrome", tube([q - rod_dir * 0.025, q + rod_dir * 0.004], rr * 1.3, segs=8))
            p = q
        ctx.add("Chrome", sphere(0.025, 8, 6), T(*p))
        ctx.add("Chrome", sphere(0.03, 8, 6), T(*p0))
    # the mains cable out of the back, down to the floor and away
    cb = [Vector((0.42, yc - 0.15, D / 2 - 0.02)), Vector((0.45, yc - 0.2, D / 2 + 0.08)),
          Vector((0.5, 0.18, D / 2 + 0.16)), Vector((0.55, FLOOR + 0.025, D / 2 + 0.3)),
          Vector((0.9, FLOOR + 0.025, D / 2 + 0.55)), Vector((1.25, FLOOR + 0.025, D / 2 + 0.5))]
    ctx.add("Black", tube(cb, 0.022, segs=6))

    ctx.wear("Plastic", mul(_dust_top(noise), ground_dirt(0.35, 0.3, noise), cavity(0.35),
                            _hand_grime(noise, (0.0, y0 + 0.1, zf), 0.3, 0.2),
                            lambda p: 0.92 + 0.08 * noise.fbm(p.co * 4, 2)))
    ctx.wear("Screen", lambda p: 0.85 + 0.15 * noise.fbm(p.co * 2.5, 2))
    ctx.wear("Black", cavity(0.2))
    ctx.wear("Chrome", lambda p: 0.75 + 0.2 * noise.fbm(p.co * 6, 2))


# ----------------------------------------------------------------------------------------------
# Boombox
# ----------------------------------------------------------------------------------------------
def _speaker(ctx, cx, cy, zf, rad, noise):
    """A boombox woofer on the front face z = zf: the black surround plate, the chrome trim ring,
    the paper cone dished back with its rubber roll surround and chrome dust cap, and the
    horizontal grille bars across it (ends tucked into the trim)."""
    ctx.add("PlasticDark", _rbox(rad * 2 + 0.1, rad * 2 + 0.1, 0.05, 0.06), T(cx, cy, zf - 0.012))
    # (a short black sleeve from the plate to the trim, hiding the back of the cone)
    ctx.add("PlasticDark", cyl(rad + 0.01, 0.05, 28), T(cx, cy, zf - 0.06) @ R(90, 0, 0))
    zp = zf - 0.037 - 0.035  # (the speaker stands 3.5 cm proud of the plate's face, -0.037)
    trim = lathe([(rad + 0.035, 0.0), (rad + 0.035, 0.012), (rad + 0.02, 0.04), (rad - 0.005, 0.045),
                  (rad - 0.02, 0.03), (rad - 0.02, 0.0)], segs=28)
    m = T(cx, cy, zp + 0.008) @ R(-90, 0, 0)  # (the lathe's +Y turned to -Z, out of the face)
    ctx.add("Chrome", trim, m)
    # the cone: roll surround, dish, dust cap (a closed lathe, its back hidden in the plate)
    cone = lathe([(0.0, -0.02), (rad - 0.01, -0.02), (rad - 0.01, 0.012), (rad - 0.035, 0.03),
                  (rad - 0.06, 0.012), (rad * 0.62, -0.0), (rad * 0.3, -0.014), (rad * 0.28, -0.012), (0.0, -0.012)],
                 segs=28)
    ctx.add("Black", cone, m)
    ctx.add("Chrome", lathe([(0.0, 0.03), (rad * 0.12, 0.028), (rad * 0.2, 0.016), (rad * 0.24, 0.0),
                             (rad * 0.24, -0.005), (0.0, -0.005)], segs=16), m)
    for s in range(7):
        y = (s - 3) * rad * 0.27
        half = math.sqrt(max(rad * rad - y * y, 0.0)) + 0.012
        ctx.add("Metal", tube([(cx - half, cy + y, zp - 0.05), (cx + half, cy + y, zp - 0.05)], 0.011, segs=6))


def radio(ctx):
    """90s boombox (2.0 x 0.96 x 0.56, handle to 1.32): silver body with a sloped top front,
    two woofers on black surround plates behind horizontal grille bars, the cassette door with
    its smoked window and the tape inside, the long tuning-dial window over the front, VU meters,
    piano keys on the slope, volume and tuning knobs, a chrome carry handle on two posts with
    masking tape wound round it, a telescopic aerial half out. Silver rubbed dark on edges."""
    ctx.budget = 7000
    ctx.smooth_angle = 40
    ctx.tint("Plastic", (150, 150, 154))  # silver (the data can tint black: 46, 46, 48)
    noise = ctx.noise
    W, H, D = 2.0, 0.96, 0.56
    y0 = FLOOR + 0.03
    zf = -D / 2
    ys = 0.8  # where the front starts sloping back
    zt = zf + 0.14  # the top's front edge
    side = [(zf, y0), (D / 2, y0), (D / 2, H), (zt, H), (zf, ys)]
    ctx.add("Plastic", _ext(side, -W / 2, W / 2, [0.05, 0.06, 0.08, 0.05, 0.04], 0.06, k=3, kb=2))
    # woofers
    for sx in (-1, 1):
        _speaker(ctx, sx * 0.6, y0 + 0.33, zf, 0.27, noise)
    # the cassette deck between them: a black bezel, the door, the smoked window, the tape behind
    ctx.add("PlasticDark", _rbox(0.56, 0.46, 0.05, 0.03), T(0, y0 + 0.36, zf - 0.012))
    ctx.add("PlasticDark", _rbox(0.46, 0.36, 0.05, 0.02), T(0, y0 + 0.36, zf - 0.03))  # the door
    # the cassette seen through the door's window: its shell, the label, the two hub windows
    ctx.add("Black", _rbox(0.36, 0.22, 0.03, 0.012), T(0, y0 + 0.39, zf - 0.06))
    ctx.add("Paper", _rbox(0.3, 0.06, 0.02, 0.006, k=1), T(0, y0 + 0.455, zf - 0.075))
    ctx.add("Paper", _rbox(0.3, 0.04, 0.02, 0.006, k=1), T(0, y0 + 0.315, zf - 0.075))
    for sx in (-1, 1):
        ctx.add("Chrome", cyl(0.028, 0.03, 10), T(sx * 0.08, y0 + 0.385, zf - 0.075) @ R(90, 0, 0))
    ctx.add("Black", _rbox(0.1, 0.03, 0.03, 0.01), T(0, y0 + 0.21, zf - 0.06))  # eject notch
    # the dial: a long window across the top of the front, the scale behind, the red needle
    ctx.add("PlasticDark", _rbox(1.86, 0.1, 0.04, 0.03), T(0, ys - 0.055, zf - 0.008))
    ctx.add("Paper", _rbox(1.7, 0.07, 0.02, 0.01, k=1), T(0, ys - 0.055, zf - 0.03))
    for t in range(25):  # the scale's ticks, long every fifth
        ln = 0.035 if t % 5 == 0 else 0.018
        ctx.add("Black", box(0.008, ln, 0.012), T(-0.78 + 1.56 * t / 24, ys - 0.03 - ln / 2, zf - 0.042))
    ctx.add("Glow", _rbox(0.014, 0.065, 0.02, 0.005, k=1), T(-0.357, ys - 0.055, zf - 0.046))
    # two VU meters over the cassette deck
    for sx in (-1, 1):
        ctx.add("Paper", _rbox(0.15, 0.05, 0.03, 0.01, k=1), T(sx * 0.11, y0 + 0.62, zf - 0.02))
    # the slope: piano keys (one pressed down), knobs, a band slider
    slope = math.atan2(H - ys, zt - zf)  # (angle of the slope face from horizontal-back)
    nrm = Vector((0, zt - zf, -(H - ys))).normalized()  # outward normal of the slope

    def on_slope(x, t, lift):
        p = Vector((x, lerp(ys, H, t), lerp(zf, zt, t)))
        return p + nrm * lift

    ang = -math.degrees(math.atan2(zt - zf, H - ys))
    for k_ in range(6):
        x = -0.3 + k_ * 0.12
        down = 0.0 if k_ != 2 else -0.012
        ctx.add("PlasticDark", _rbox(0.1, 0.05, 0.14, 0.015, k=1), T(*on_slope(x, 0.5, 0.025 + down)) @ R(ang + 90, 0, 0))
    for sx in (0.55, 0.78):
        ctx.add("PlasticDark", cyl(0.055, 0.06, 16, bevel=0.012), T(*on_slope(sx, 0.5, 0.03)) @ R(ang + 90, 0, 0))
    ctx.add("PlasticDark", _rbox(0.06, 0.04, 0.05, 0.012), T(*on_slope(-0.7, 0.5, 0.02)) @ R(ang + 90, 0, 0))
    ctx.add("Black", _rbox(0.26, 0.012, 0.03, 0.005), T(*on_slope(-0.7, 0.5, 0.002)) @ R(ang + 90, 0, 0))
    # the carry handle: a chrome tube on two posts, masking tape wound round its middle
    hy = H + 0.33
    path = [(-0.62, H - 0.02, 0.06), (-0.62, H + 0.18, 0.06), (-0.58, hy - 0.03, 0.06), (-0.52, hy, 0.06),
            (0.52, hy, 0.06), (0.58, hy - 0.03, 0.06), (0.62, H + 0.18, 0.06), (0.62, H - 0.02, 0.06)]
    ctx.add("Chrome", tube(path, 0.035, segs=10))
    for sx in (-1, 1):
        ctx.add("PlasticDark", _rbox(0.14, 0.06, 0.14, 0.025), T(sx * 0.62, H + 0.02, 0.06))
    tx = 0.04 + 0.1 * ctx.rng.uniform(-1, 1)
    tape = []
    for k_ in range(14):
        x = tx - 0.17 + 0.34 * k_ / 13
        tape.append((x, hy, 0.06))
    ctx.add("Paper", tube(tape, [0.046 + 0.006 * noise.n((k_ * 0.7, 1, 2)) for k_ in range(14)], segs=10))
    # the telescopic aerial: a knuckle at the back right, three segments, the top one bent
    base = Vector((W / 2 - 0.16, H + 0.012, D / 2 - 0.08))
    ctx.add("PlasticDark", cyl(0.04, 0.05, 12, bevel=0.01), T(*base))
    d1 = (R(-14, 0, -22) @ Vector((0, 1, 0))).normalized()
    p = base + Vector((0, 0.03, 0))
    for ln, rr in ((0.36, 0.016), (0.32, 0.012), (0.18, 0.009)):
        q = p + d1 * ln
        ctx.add("Chrome", tube([p, q], rr, segs=6))
        p = q
        d1 = (R(0, 0, -12) @ d1).normalized()
    ctx.add("Chrome", sphere(0.018, 8, 5), T(*p))
    # rubber feet; a battery door on the back
    for sx in (-1, 1):
        for sz in (-1, 1):
            ctx.add("Rubber", _rbox(0.16, 0.035, 0.08, 0.012, k=1), T(sx * 0.78, FLOOR + 0.0175, sz * 0.17))
    ctx.add("Plastic", _rbox(1.0, 0.42, 0.04, 0.02), T(0, y0 + 0.36, D / 2 + 0.008))
    for k_ in range(5):
        ctx.add("Plastic", _rbox(0.04, 0.2, 0.03, 0.01, k=1), T(-0.12 + 0.06 * k_, y0 + 0.36, D / 2 + 0.03))

    def silver(p):
        # silver paint rubbed through to the dark plastic on edges and corners, grimy low down
        rub = smoothstep(0.08, 0.45, p.convex) * (0.5 + 0.5 * smoothstep(-0.2, 0.6, noise.fbm(p.co * 9, 2)))
        k = 1 - 0.55 * rub
        return k * (0.9 + 0.1 * noise.fbm(p.co * 3, 2))

    ctx.wear("Plastic", mul(silver, ground_dirt(0.25, 0.3, noise), cavity(0.35)))
    ctx.wear("Chrome", mul(lambda p: 0.75 + 0.2 * noise.fbm(p.co * 7, 2), _hand_grime(noise, (0, hy, 0.06), 0.5, 0.25)))
    ctx.wear("Paper", lambda p: (0.85, 0.8, 0.66) if p.co.y > H else (0.95, 0.92, 0.84))
    ctx.wear("PlasticDark", mul(cavity(0.3), edge_wear(0.2), lambda p: 0.8))
    ctx.wear("Metal", lambda p: 0.7)
    ctx.wear("Black", cavity(0.3))


# ----------------------------------------------------------------------------------------------
# Clothes on hangers, and the rail they hang on
# ----------------------------------------------------------------------------------------------
# A hanging garment is modelled in its own space: the ORIGIN is the centre of the rail the
# hanger's hook hangs on (the rail runs along Z there), the shoulders along X, the front -Z, the
# garment hanging down -Y. The data hangs it at a point of the ClothesRack's rail (y = RAIL_Y)
# turned 90 degrees (its X across the rail), as the old clothes_rack did.
RAIL_Y = 5.2  # the rack's rail height (props_objects.clothes_rack: H)
RAIL_R = 0.06  # the rail tube's radius
NECK = (0.25, -0.31)  # (half-width, y) of the neckline on the hanger
TIP = (0.75, -0.53)  # (half-width, y) of the shoulder tips


def _shoulder_y(x):
    """Height of the hanger's shoulder line (the garment's shoulder seam) at |x|."""
    t = (abs(x) - NECK[0]) / (TIP[0] - NECK[0])
    return lerp(NECK[1], TIP[1], max(0.0, min(1.0, t)) ** 1.15)


class _Garment:
    """The body of a garment hanging on a hanger: horizontal superellipse rings from the neck
    (narrow, on the hanger) down the sloping shoulders (each ring as wide as the shoulder line at
    its height), the chest and the waist to the hem. prof(y) -> (half-width, front depth, back
    depth); fold(x, y) -> extra depth (drape folds: + swells, - hollows), scaled by how far the
    point is from the side seam, so the sides stay put. front(x, y) / back(x, y) give the surface
    at any point, for laying details (zips, pockets, lapels) on it."""

    P = 2.6  # the superellipse exponent: flattish front and back, rounded sides

    def __init__(self, hem, prof, fold, n=40, rings=None):
        self.hem, self.prof, self.fold, self.n = hem, prof, fold, n
        ys = rings or self.default_rings(hem)
        self.ys = ys

    @staticmethod
    def default_rings(hem):
        top = [NECK[1] - 0.06, NECK[1] - 0.005]
        sh = [lerp(NECK[1] - 0.03, TIP[1] - 0.02, t / 5) for t in range(1, 6)]
        body = [lerp(TIP[1] - 0.08, hem + 0.06, t / 17) for t in range(18)]
        return top + sh + body + [hem + 0.015, hem]

    def width(self, y):
        a, _f, _b = self.prof(y)
        if y > TIP[1]:  # on the shoulders: as wide as the shoulder line at that height
            t = (y - TIP[1]) / (NECK[1] - TIP[1])
            a = min(a, lerp(TIP[0], NECK[0], max(0.0, min(1.0, t)) ** 0.85))
        return a

    def q(self, x, y):
        a = self.width(y)
        u = min(abs(x) / a, 1.0)
        return (1 - u ** self.P) ** (1 / self.P)

    def front(self, x, y):
        _a, bf, _bb = self.prof(y)
        return -self.q(x, y) * (bf + self.fold(x, y, -1))

    def back(self, x, y):
        _a, _bf, bb = self.prof(y)
        return self.q(x, y) * (bb + self.fold(x, y, 1))

    def build(self, warp=None):
        rings = []
        for k_, y in enumerate(self.ys):
            a = self.width(y)
            ring = []
            for i in range(self.n):
                th = 2 * math.pi * i / self.n
                c, s_ = math.cos(th), math.sin(th)
                x = a * math.copysign(abs(c) ** (2 / self.P), c)
                yy = y
                if k_ == 0:  # the neck opening dips into the garment
                    x *= 0.78
                if s_ < 0:
                    z = self.front(x, y) * (abs(s_) ** (2 / self.P)) / max(self.q(x, y), 1e-3)
                else:
                    z = self.back(x, y) * (abs(s_) ** (2 / self.P)) / max(self.q(x, y), 1e-3)
                if k_ == 0:
                    z *= 0.6
                p = Vector((x, yy, z))
                ring.append(tuple(warp(p) if warp else p))
            rings.append(ring)
        # the hem: the last ring pulled in a little and closed (the lining inside)
        return loft(rings, cap_start=True, cap_end=True)


def _drape(noise, amp, start, wave=0.42, seed=0.0, hem=-2.6):
    """Drape folds of a garment on a hanger: vertical folds falling from the shoulder tips (wave
    `wave`), deeper toward the hem, wandering sideways, broken by noise. Returns fold(x, y, side)."""

    def fold(x, y, side):
        t = smoothstep(start, hem, y)  # 0 at the shoulders, 1 at the hem
        ph = 0.6 * noise.n((x * 0.8 + seed, y * 0.9, side * 3.1))
        f = math.sin(2 * math.pi * x / wave + ph + seed + 1.3 * side) * 0.6
        f += 0.55 * noise.fbm((x * 2.6 + seed, y * 1.1, side * 1.7), 2)
        # big folds from the tips: two broad swells hanging below the hanger's ends
        for sx in (-1, 1):
            f += 0.5 * math.exp(-((x - sx * 0.48) / 0.18) ** 2)
        return amp * t * f

    return fold


def _sleeve_path(sx, hem_y, fwd=0.07, out=0.0, bend=0.0):
    """A sleeve hanging down the side: from inside the shoulder, over the tip, down the side a
    little in front, the elbow bending forward a touch."""
    x = sx
    return [Vector((x * 0.5, TIP[1] - 0.06, 0.0)), Vector((x * 0.71, TIP[1] - 0.1, 0.0)),
            Vector((x * (0.82 + out * 0.3), TIP[1] - 0.34, -0.01)),
            Vector((x * (0.86 + out * 0.6), lerp(TIP[1], hem_y, 0.45), -0.03 - fwd * 0.4 - bend)),
            Vector((x * (0.86 + out), lerp(TIP[1], hem_y, 0.75), -0.04 - fwd * 0.8 - bend * 1.5)),
            Vector((x * (0.84 + out), hem_y + 0.2, -0.05 - fwd - bend))]


def _resample(path, n):
    """`n` points evenly spaced along a polyline (Catmull-Rom smoothed)."""
    pts = [Vector(p) for p in path]
    dense = []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, len(pts) - 1)]
        for k_ in range(12):
            t = k_ / 12
            t2, t3 = t * t, t * t * t
            dense.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                                + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    dense.append(pts[-1])
    acc = [0.0]
    for a, b in zip(dense, dense[1:]):
        acc.append(acc[-1] + (b - a).length)
    out, j = [], 0
    for k_ in range(n):
        target = acc[-1] * k_ / (n - 1)
        while j < len(acc) - 2 and acc[j + 1] < target:
            j += 1
        t = (target - acc[j]) / max(acc[j + 1] - acc[j], 1e-9)
        out.append(dense[j].lerp(dense[j + 1], t))
    return out


def _sleeve(path, r_top, r_cuff, noise, seed, n=14, segs=12, bunch=0.25):
    """A limp sleeve along `path`: a flattened tube (thin across X, wide front to back) tapering
    from the armhole to the cuff, its outline rippled by noise (bunching near the cuff). Returns
    the bmesh and the resampled path."""
    pts = _resample(path, n)

    def sec(i):
        t = i / (n - 1)
        ru = lerp(r_top[0], r_cuff[0], t)
        rv = lerp(r_top[1], r_cuff[1], t)
        out = []
        for k_ in range(segs):
            a = 2 * math.pi * k_ / segs
            j = 1 + (0.06 + bunch * t * t) * noise.n((i * 0.9 + seed, k_ * 0.7, 2.0)) * 0.6
            out.append((ru * math.cos(a) * j, rv * math.sin(a) * j))
        return out

    return _sweep(pts, sec, ups=[Vector((0, 0, -1))] * n), pts


def _hook(ctx, layer, neck_y=-0.24):
    """The hanger's hook round the rail: a wire circle over the rail (radius 0.085 from its
    centre, the origin), its tip turned out, down into the neck."""
    rr = RAIL_R + 0.028
    pts = []
    for a in range(-40, 271, 18):
        t = math.radians(a)
        pts.append((rr * math.cos(t), rr * math.sin(t) + 0.004, 0.0))
    pts += [(-0.015, -0.13, 0.0), (0.0, -0.17, 0.0), (0.0, neck_y, 0.0)]
    ctx.add(layer, tube(pts, 0.019, segs=7))


def _wire_hanger(ctx):
    """A wire hanger: the hook, the twisted neck, the two shoulders to the tips, the bottom bar."""
    _hook(ctx, "Metal", -0.2)
    for s in range(4):  # the twist
        y = -0.2 - s * 0.028
        ctx.add("Metal", _torus(0.012, 0.012, segs=8, rsegs=4), T(0, y, 0) @ R(90 + 25 * (-1) ** s, 0, 0))
    hy = TIP[1] - 0.05
    pts = [(0.0, -0.31, 0.0)]
    pts += [(TIP[0] - 0.08, hy + 0.01, 0.0), (TIP[0] - 0.03, hy - 0.01, 0.0), (TIP[0] - 0.02, hy - 0.05, 0.0),
            (TIP[0] - 0.07, hy - 0.07, 0.0), (-TIP[0] + 0.07, hy - 0.07, 0.0), (-TIP[0] + 0.02, hy - 0.05, 0.0),
            (-TIP[0] + 0.03, hy - 0.01, 0.0), (-TIP[0] + 0.08, hy + 0.01, 0.0), (0.0, -0.31, 0.0)]
    ctx.add("Metal", tube(pts, 0.016, segs=6, cap=True))


def _wood_hanger(ctx):
    """A wooden hanger: a curved bar following the shoulders (thicker in the middle), its middle
    showing in the collar, the chrome hook screwed into its top."""
    _hook(ctx, "Chrome", -0.25)
    n = 15
    path = []
    for k_ in range(n):
        x = lerp(-TIP[0] + 0.09, TIP[0] - 0.09, k_ / (n - 1))
        path.append((x, _shoulder_y(x) - 0.095, 0.0))

    def sec(i):
        t = abs(2 * i / (n - 1) - 1)
        h = lerp(0.055, 0.035, t)
        w = lerp(0.03, 0.036, t)  # (a little broader at the shoulder ends)
        return [(u * w, v * h) for u, v in _rpoly([(-1, -1), (1, -1), (1, 1), (-1, 1)], 0.5, 2)]

    ctx.add("Wood", _sweep(path, sec, ups=Vector((0, 1, 0))))
    ctx.add("Chrome", cyl(0.03, 0.03, 10), T(0, _shoulder_y(0) - 0.02, 0))


def jacket1(ctx):
    """Dark leather biker jacket on a wooden hanger (hook = origin, on the rail; 1.95 wide,
    hanging 2.35 below the rail): broad wide-lapelled collar, the asymmetric zip running from
    the hem up to the left shoulder, slanted zip pockets, a belt round the hem with its buckle,
    zips at the cuffs, sleeves hanging limp down the sides; stiff leather: few broad folds,
    creased elbows, scuffed lighter on the folds' ridges."""
    ctx.budget = 6000
    ctx.smooth_angle = 60
    noise, rng = ctx.noise, ctx.rng
    hem = -2.42
    fold = _drape(noise, 0.07, TIP[1] - 0.2, wave=0.55, seed=rng.uniform(0, 6), hem=hem)

    def prof(y):
        t = smoothstep(TIP[1] + 0.05, TIP[1] - 0.6, y)
        a = lerp(TIP[0] + 0.02, 0.8, t) - 0.04 * smoothstep(-1.6, hem, y)
        bf = lerp(0.07, 0.25, t) - 0.04 * smoothstep(-1.4, hem, y)
        bb = lerp(0.06, 0.19, t)
        return a, bf, bb

    g = _Garment(hem, prof, fold, n=40)
    ctx.add("Leather", g.build())
    # the belt round the hem: a band proud of the body, the buckle on the left side
    belt_y = hem + 0.13
    ring = []
    for i in range(41):
        th = 2 * math.pi * i / 40
        c, s_ = math.cos(th), math.sin(th)
        a = g.width(belt_y)
        x = a * math.copysign(abs(c) ** (2 / g.P), c)
        z = (g.front(x, belt_y) if s_ < 0 else g.back(x, belt_y)) * (abs(s_) ** (2 / g.P)) / max(g.q(x, belt_y), 1e-3)
        out = Vector((x, 0, z))
        out = out + out.normalized() * 0.022
        ring.append((out.x, belt_y, out.z))
    ctx.add("Leather", _sweep(ring[:-1], [(-0.012, -0.08), (0.012, -0.08), (0.016, 0.0), (0.012, 0.08), (-0.012, 0.08)],
                              ups=Vector((0, 1, 0)), closed=True))
    bx = -0.5
    bz = g.front(bx, belt_y) - 0.05
    ctx.add("Chrome", _rbox(0.14, 0.17, 0.03, 0.02), T(bx, belt_y, bz) @ R(0, -18, 0))
    ctx.add("Leather", _rbox(0.1, 0.12, 0.03, 0.02), T(bx, belt_y, bz - 0.012) @ R(0, -18, 0))
    # the asymmetric zip: from the hem (right of centre) up across the chest to under the lapel
    zp = []
    for k_ in range(12):
        t = k_ / 11
        y = lerp(hem + 0.24, -0.86, t)
        x = lerp(0.2, -0.3, smoothstep(0.35, 1.0, t))
        zp.append(Vector((x, y, g.front(x, y) - 0.02)))
    ctx.add("Metal", _sweep(zp, [(-0.025, -0.008), (0.025, -0.008), (0.025, 0.01), (-0.025, 0.01)],
                            ups=[Vector((0, 0, -1))] * 12))
    ctx.add("Chrome", _rbox(0.04, 0.09, 0.025, 0.012), T(zp[-1].x + 0.01, zp[-1].y - 0.05, zp[-1].z - 0.02))
    # the lapels: wide flaps laid over the chest, from the collar down to the zip's top
    for sx in (-1, 1):
        rows, cols = 6, 5
        top, bot = [], []
        for i in range(rows):
            v = i / (rows - 1)
            y = lerp(NECK[1] - 0.1, -0.95 + 0.05 * sx, v)
            x_in = lerp(sx * 0.21, sx * 0.04 - 0.1, v)
            x_out = lerp(sx * 0.36, sx * 0.13 - 0.1 * (sx < 0), v ** 0.8)
            rt, rb = [], []
            for j in range(cols):
                x = lerp(x_in, x_out, j / (cols - 1))
                z = g.front(x, y) - 0.012
                lift = 0.02 * math.sin(math.pi * j / (cols - 1)) * (1 - v * 0.5)
                rt.append(Vector((x, y, z - 0.035 - lift)))
                rb.append(Vector((x, y, z - lift * 0.5)))
            top.append(rt)
            bot.append(rb)
        ctx.add("Leather", _grid_slab(top, bot))
    # the collar: a band round the back of the neck, standing then folding over
    cp = []
    for k_ in range(13):
        th = math.radians(lerp(200, 340, k_ / 12))
        x = (NECK[0] + 0.03) * math.cos(th)
        z = 0.14 * -math.sin(th) + 0.02
        cp.append((x, NECK[1] - 0.02 + 0.03 * math.sin(math.radians(lerp(0, 180, k_ / 12))), z))
    cp = [(-0.22, NECK[1] - 0.08, -0.1)] + cp + [(0.22, NECK[1] - 0.08, -0.1)]
    ctx.add("Leather", _sweep(cp, [(-0.02, -0.05), (0.02, -0.05), (0.035, 0.07), (0.0, 0.08)], ups=Vector((0, 1, 0))))
    # sleeves (stiff, creased at the elbow), zips at the cuffs
    for sx in (-1, 1):
        sl, pts = _sleeve(_sleeve_path(sx, hem + 0.1, fwd=0.06, out=0.02), (0.1, 0.17), (0.08, 0.11), noise,
                          sx * 3.0 + 1, n=16, segs=12, bunch=0.12)
        ctx.add("Leather", sl)
        c = pts[-1]
        ctx.add("Metal", _sweep([c + Vector((sx * 0.065, 0.24, 0.0)), c + Vector((sx * 0.075, 0.02, 0.0))],
                                [(-0.008, -0.02), (0.008, -0.02), (0.008, 0.02), (-0.008, 0.02)], ups=Vector((0, 0, -1))))
    # slanted zip pockets on the lower front, a small one on the chest
    for x0, y0_, x1, y1 in ((-0.62, -1.75, -0.3, -1.45), (0.36, -1.5, 0.64, -1.78), (0.24, -0.98, 0.5, -1.0)):
        pts = []
        for k_ in range(5):
            x = lerp(x0, x1, k_ / 4)
            y = lerp(y0_, y1, k_ / 4)
            pts.append(Vector((x, y, g.front(x, y) - 0.012)))
        ctx.add("Metal", _sweep(pts, [(-0.015, -0.006), (0.015, -0.006), (0.015, 0.006), (-0.015, 0.006)],
                                ups=[Vector((0, 0, -1))] * 5))
    _wood_hanger(ctx)

    def leather(p):
        # black leather: rubbed paler (here: less dark) on the ridges of the folds, darker in the
        # creases, dust on the shoulders
        k = 0.8 + 0.2 * smoothstep(0.0, 0.4, p.convex)
        k *= 1 - 0.3 * smoothstep(0.0, 0.4, -p.convex)
        k *= 1 + 0.12 * smoothstep(0.5, 0.9, p.normal.y)
        return k * (0.9 + 0.1 * noise.fbm(p.co * 5, 2))

    ctx.wear("Leather", leather)
    ctx.wear("Metal", lambda p: 0.75 + 0.15 * noise.fbm(p.co * 9, 2))
    ctx.wear("Wood", mul(edge_wear(0.15), lambda p: 0.85))
    ctx.wear("Chrome", lambda p: 0.8)


def jacket2(ctx):
    """Pullover hoodie on a wire hanger (hook = origin, on the rail; 1.95 wide, hanging 2.5 below
    the rail): the hood hanging down the back with its rolled rim standing behind the neck, white
    drawstrings with metal tips, the kangaroo pocket, a ribbed hem band pulling the body in so it
    blouses above it, ribbed cuffs on limp sleeves; soft cotton: many drape folds. Grime at the
    cuffs and the pocket, dust on the shoulders."""
    ctx.budget = 6000
    ctx.smooth_angle = 70
    ctx.tint("Fabric", (74, 78, 86))  # washed-out navy grey (data: any JACKET colour)
    noise, rng = ctx.noise, ctx.rng
    hem = -2.55
    band = 0.2  # the ribbed hem band
    fold = _drape(noise, 0.09, TIP[1] - 0.15, wave=0.4, seed=rng.uniform(0, 6), hem=hem)

    def prof(y):
        t = smoothstep(TIP[1] + 0.05, TIP[1] - 0.55, y)
        a = lerp(TIP[0] + 0.02, 0.82, t) + 0.03 * smoothstep(hem + 0.9, hem + band + 0.1, y)
        bf = lerp(0.07, 0.23, t) + 0.03 * smoothstep(hem + 0.9, hem + band + 0.1, y)
        bb = lerp(0.06, 0.2, t)
        if y < hem + band + 0.04:  # the band: pulled in, a crease at its top
            k = smoothstep(hem + band + 0.04, hem + band - 0.02, y)
            a -= 0.12 * k
            bf -= 0.06 * k
            bb -= 0.05 * k
        return a, bf, bb

    def fold2(x, y, side):
        f = fold(x, y, side)
        if y < hem + band:
            f *= 0.25
        return f

    rings = _Garment.default_rings(hem)
    rings = [y for y in rings if y > hem + band + 0.06] + [hem + band + 0.04, hem + band, hem + band - 0.03,
                                                           hem + 0.1, hem + 0.02, hem]
    g = _Garment(hem, prof, fold2, n=40, rings=rings)
    ctx.add("Fabric", g.build())
    # the hood, hanging down the back: a soft puffy shell pressed on the back, its centre seam,
    # and its rim rolled up behind the neck
    hood = bmesh.new()
    bmesh.ops.create_uvsphere(hood, u_segments=18, v_segments=12, radius=1.0)
    hc = Vector((0.0, -0.78, 0.0))
    for v in hood.verts:
        n = v.co.normalized()
        p = hc + Vector((n.x * 0.43, n.y * 0.47, 0.0))
        p.y += 0.08 * (1 - n.y) * (abs(n.x) ** 2)  # (rounder at the bottom, squarer at the top)
        bz = g.back(p.x, p.y)
        puff = 0.13 * max(n.z, 0.0) ** 0.7 * (1 + 0.15 * noise.fbm(n * 2.2, 2))
        p.z = bz + 0.01 + puff if n.z > -0.05 else bz - 0.05
        v.co = p
    ctx.add("Fabric", hood)
    seam = []
    for k_ in range(9):
        y = lerp(-0.42, -1.18, k_ / 8)
        seam.append((0.0, y, g.back(0.0, y) + 0.01 + 0.13 * math.sin(math.pi * (0.1 + 0.8 * k_ / 8)) ** 0.7 + 0.004))
    ctx.add("Fabric", tube(seam, 0.018, segs=6))
    rim = []
    for k_ in range(15):
        th = math.radians(lerp(195, 345, k_ / 14))
        x = (NECK[0] + 0.07) * math.cos(th)
        z = 0.16 * -math.sin(th) + 0.04
        rim.append((x, NECK[1] - 0.05 + 0.05 * math.sin(math.pi * k_ / 14), z))
    rim = [(-0.27, NECK[1] - 0.16, -0.06)] + rim + [(0.27, NECK[1] - 0.16, -0.06)]
    ctx.add("Fabric", tube(rim, [0.05] + [0.06] * 15 + [0.05], segs=9))
    # drawstrings out of the neck, hanging down the chest, metal tips
    for sx in (-1, 1):
        cord = []
        for k_ in range(8):
            t = k_ / 7
            y = lerp(NECK[1] - 0.14, -1.05 - 0.12 * (sx > 0), t)
            x = sx * (0.1 + 0.03 * t) + 0.03 * math.sin(t * 3 + sx)
            cord.append(Vector((x, y, g.front(x, y) - 0.03)))
        ctx.add("Paper", tube(cord, 0.017, segs=6))
        tip = cord[-1]
        ctx.add("Metal", tube([tip, tip + (cord[-1] - cord[-2]).normalized() * 0.07], 0.021, segs=6))
        ctx.add("Metal", _torus(0.03, 0.012, segs=8, rsegs=4), T(sx * 0.1, NECK[1] - 0.15, g.front(sx * 0.1, NECK[1] - 0.15) - 0.008) @ R(90, 0, 0))
    # the kangaroo pocket: a panel laid on the front, its sides curved (the hand openings)
    rows, cols = 7, 9
    top, bot = [], []
    pb, pt = hem + band + 0.05, hem + band + 0.56
    for i in range(rows):
        v = i / (rows - 1)
        y = lerp(pb, pt, v)
        half = lerp(0.56, 0.36, v) - 0.08 * math.sin(math.pi * min(1.0, v * 1.4)) * (v < 0.72)
        rt, rb = [], []
        for j in range(cols):
            x = lerp(-half, half, j / (cols - 1))
            z = g.front(x, y)
            puff = 0.012 * math.sin(math.pi * j / (cols - 1)) * math.sin(math.pi * v)
            rt.append(Vector((x, y, z - 0.03 - puff)))
            rb.append(Vector((x, y, z + 0.004)))
        top.append(rt)
        bot.append(rb)
    ctx.add("Fabric", _grid_slab(top, bot))
    # sleeves, the cuffs' rib bands
    for sx in (-1, 1):
        sl, pts = _sleeve(_sleeve_path(sx, hem + 0.12, fwd=0.08, out=0.03, bend=0.02), (0.1, 0.17), (0.075, 0.1), noise,
                          sx * 5.0 + 2, n=16, segs=12, bunch=0.35)
        ctx.add("Fabric", sl)
        d = (pts[-1] - pts[-2]).normalized()
        c0 = pts[-1] - d * 0.02
        ctx.add("Fabric", _sweep([c0, c0 + d * 0.14], _ellipse(0.068, 0.088, 12), ups=[Vector((0, 0, -1))] * 2))
    _wire_hanger(ctx)

    def cotton(p):
        k = 0.88 + 0.12 * noise.fbm(p.co * 7, 2)  # pilled, uneven
        k *= 1 - 0.32 * smoothstep(0.0, 0.35, -p.convex)  # shadowed fold valleys
        k *= 1 + 0.12 * smoothstep(0.6, 0.95, p.normal.y)  # (dust on the shoulders: the tint is the dusty top)
        y = p.co.y
        k *= 1 - 0.18 * smoothstep(hem + 0.3, hem, y) * (abs(p.co.x) > 0.7)  # grimy cuffs
        k *= 1 - 0.12 * (1 - smoothstep(0.0, 0.25, abs(y - (hem + band + 0.4)))) * (abs(p.co.x) < 0.5) * (p.co.z < 0)
        return k * 0.92

    ctx.wear("Fabric", cotton)
    ctx.wear("Paper", lambda p: (0.88, 0.86, 0.8))
    ctx.wear("Metal", lambda p: 0.8)


def _caster(ctx, at, yaw):
    """A swivel castor under a rack foot: the top plate, the swivel bearing, the pressed-steel
    fork, the rubber wheel on its axle (wheel touching down at FLOOR)."""
    x, y, z = at  # (y = the plate's top)
    m = T(x, 0, z) @ R(0, yaw, 0)
    wr = 0.11
    wy = FLOOR + wr
    ctx.add("Metal", _rbox(0.2, 0.025, 0.2, 0.01, k=1), m @ T(0, y - 0.0125, 0))
    ctx.add("Metal", cyl(0.06, 0.04, 12, bevel=0.01), m @ T(0, y - 0.045, 0))
    for sx in (-1, 1):  # the fork's cheeks
        cheek = _rpoly([(-0.07, wy - 0.02), (0.1, wy - 0.02), (0.08, y - 0.06), (-0.06, y - 0.06)], 0.025, 2)
        ctx.add("Metal", _cheek(cheek, sx * 0.045), m)
    ctx.add("Metal", _rbox(0.13, 0.03, 0.17, 0.008, k=1), m @ T(0, y - 0.065, 0.015))
    wheel = lathe([(0.0, -0.032), (wr - 0.025, -0.032), (wr - 0.006, -0.028), (wr, -0.012), (wr, 0.012),
                   (wr - 0.006, 0.028), (wr - 0.025, 0.032), (0.0, 0.032)], segs=18)
    ctx.add("Rubber", wheel, m @ T(0.0, wy, 0.03) @ R(0, 0, 90))
    ctx.add("Metal", cyl(0.018, 0.12, 8), m @ T(0.0, wy, 0.03) @ R(0, 0, 90))


def _cheek(poly, x):
    """A flat fork cheek: the 2-D outline (z, y) extruded 0.016 across X at x."""
    rings = [[(x - 0.008, b, a) for a, b in poly], [(x + 0.008, b, a) for a, b in poly]]
    return loft(rings, cap_start=True, cap_end=True)


def clothes_rack(ctx):
    """Chrome rolling garment rail (4.8 between the uprights, rail at 5.2, feet 1.8 deep): two
    telescopic uprights (the thinner top tube in the lower one, a clamp knob at the joint), the
    rail through T-fittings with end caps, a low cross bar, two feet on swivel castors. One
    upright bent, tarnished and pitted chrome, grime at the feet. No clothes: Jacket1 / Jacket2
    hang on its rail (their origin = a point of the rail: (x, 5.2, 0), turned 90 degrees)."""
    ctx.budget = 6000
    ctx.smooth_angle = 40
    noise, rng = ctx.noise, ctx.rng
    W, H = 4.8, RAIL_Y
    fy = 0.4  # the feet's axis
    for sx in (-1, 1):
        x = sx * W / 2
        bent = sx > 0
        # the foot: a tube along Z, end caps, the T-fitting where the upright stands
        ctx.add("Chrome", tube([(x, fy, -0.86), (x, fy, 0.86)], 0.065, segs=12))
        for sz in (-1, 1):
            ctx.add("PlasticDark", cyl(0.072, 0.07, 12, bevel=0.015), T(x, fy, sz * 0.9) @ R(90, 0, 0))
            _caster(ctx, (x, fy - 0.065, sz * 0.78), rng.uniform(-40, 40))
        ctx.add("PlasticDark", _rbox(0.2, 0.22, 0.24, 0.05), T(x, fy + 0.03, 0))
        # the lower tube (bent a little on one side), the clamp collar and knob, the top tube
        top_low = Vector((x + (0.05 if bent else 0.0), 3.0, 0.0))
        mid = Vector((x + (0.07 if bent else 0.0), 1.7, 0.02 if bent else 0.0))
        ctx.add("Chrome", tube(_resample([(x, fy + 0.1, 0), mid, top_low], 6), 0.07, segs=12))
        ctx.add("PlasticDark", cyl(0.095, 0.16, 14, bevel=0.025), T(*top_low))
        ctx.add("PlasticDark", cyl(0.04, 0.1, 10, bevel=0.012), T(top_low.x, top_low.y, -0.13) @ R(90, 0, 0))
        ctx.add("PlasticDark", _rbox(0.16, 0.05, 0.05, 0.02), T(top_low.x, top_low.y, -0.2))
        tx = x + (0.035 if bent else 0.0)
        ctx.add("Chrome", tube([(top_low.x, 2.9, 0), (tx, H - 0.05, 0)], 0.056, segs=12))
        # the T-fitting at the top, the rail passing through it
        ctx.add("PlasticDark", cyl(0.085, 0.24, 14, bevel=0.02), T(tx, H, 0) @ R(0, 0, 90))
        ctx.add("PlasticDark", cyl(0.075, 0.14, 14, bevel=0.02), T(tx, H - 0.1, 0))
        # the cross bar's fitting
        ctx.add("PlasticDark", cyl(0.088, 0.14, 14, bevel=0.02), T(x + (0.01 if bent else 0.0), 0.62, 0))
    rx1 = W / 2 + 0.035 + 0.16
    ctx.add("Chrome", tube([(-W / 2 - 0.16, H, 0), (rx1, H, 0)], RAIL_R, segs=14))
    for xe in (-W / 2 - 0.16, rx1):
        ctx.add("PlasticDark", cyl(0.068, 0.04, 14, bevel=0.012), T(xe, H, 0) @ R(0, 0, 90))
    ctx.add("Chrome", tube([(-W / 2, 0.62, 0), (W / 2 + 0.01, 0.62, 0)], 0.05, segs=10))

    def chrome(p):
        # tarnished, pitted chrome: dull patches, rust freckles low down, grime at the feet
        k = 0.78 + 0.18 * noise.fbm(p.co * Vector((2, 6, 2)), 2)
        pit = smoothstep(0.62, 0.8, noise.fbm(p.co * 14, 2) * 0.5 + 0.5) * (1 - smoothstep(0.5, 3.0, p.co.y))
        k *= 1 - 0.3 * (1 - smoothstep(0.0, 0.9, p.co.y))
        return (k * (1 - 0.3 * pit), k * (1 - 0.45 * pit), k * (1 - 0.6 * pit))

    ctx.wear("Chrome", chrome)
    ctx.wear("PlasticDark", mul(ground_dirt(0.9, 0.3, noise), cavity(0.3), edge_wear(0.15)))
    ctx.wear("Metal", mul(lambda p: (0.8, 0.72, 0.62), cavity(0.3)))
    ctx.wear("Rubber", ground_dirt(0.25, 0.25, noise))


# ----------------------------------------------------------------------------------------------
# The stall's canopy
# ----------------------------------------------------------------------------------------------
CANOPY_W, CANOPY_D = 6.8, 5.4  # between the poles (market_stall compact: cw, cd)
CANOPY_HF, CANOPY_HB = 7.5, 6.65  # the front and back poles' tops


def _cinder_block(ctx, at, yaw):
    """A cinder block (1.3 x 0.65 x 0.65 here: 40 x 20 x 20 cm): one hollow shell (an open-topped
    box skin, _tray, its bottom on the ground) and the web across the middle, 1.2 cm lower than
    the rim, its ends buried in the walls: two open cores, the pole standing in one."""
    x, z = at
    w, h, d = 1.3, 0.65, 0.65
    m = T(x, 0, z) @ R(0, yaw, 0)
    ctx.add("Concrete", _tray(w, d, h, 0.11, 0.1, 0.02, FLOOR, bevel=0.02, k=2, m=1), m)
    ctx.add("Concrete", box(0.11, h - 0.08, d - 0.18, bevel=0.015, segments=1), m @ T(0, FLOOR + 0.06 + (h - 0.08) / 2, 0))


def _bucket(ctx, at):
    """A builder's bucket set with concrete (the pole stuck in it): tapered black plastic, a
    rolled rim, two hoops, the grey concrete a little below the rim."""
    x, z = at
    r0, r1, h = 0.36, 0.44, 0.9
    prof = [(0.0, 0.0), (r0 - 0.02, 0.0), (r0, 0.02), (lerp(r0, r1, 0.3), h * 0.3), (lerp(r0, r1, 0.3) + 0.012, h * 0.31),
            (lerp(r0, r1, 0.33) + 0.012, h * 0.34), (lerp(r0, r1, 0.33), h * 0.35), (lerp(r0, r1, 0.75), h * 0.75),
            (lerp(r0, r1, 0.75) + 0.012, h * 0.76), (lerp(r0, r1, 0.78) + 0.012, h * 0.79), (lerp(r0, r1, 0.78), h * 0.8),
            (r1, h - 0.03), (r1 + 0.03, h - 0.02), (r1 + 0.03, h + 0.005), (r1 - 0.02, h + 0.01), (r1 - 0.035, h - 0.01),
            (r1 - 0.04, h - 0.09), (0.0, h - 0.09)]
    ctx.add("PlasticDark", lathe(prof, segs=24), T(x, FLOOR, z))
    ctx.add("Concrete", cyl(r1 - 0.045, 0.03, 20), T(x, FLOOR + h - 0.08, z))


def market_tarp(ctx):
    """Market stall canopy (6.8 x 5.4 between the poles, front 7.5 high, back 6.65; the sheet
    7.4 x 6.2): one woven blue tarp tied over four mismatched poles (galvanised scaffold tube,
    square timbers, grey conduit) footed in cinder blocks and a bucket of concrete, sagging in
    the middle where rain pools, tension creases running in from the corners, the front edge
    hanging in a ragged valance, a torn hole with a flap hanging from it, gaffer-tape patches,
    grommets tied to the pole tops, guy ropes to pegs at the front, a bare bulb on its flex
    (Light marker at the bulb)."""
    ctx.budget = 7800
    ctx.smooth_angle = 60
    ctx.tint("Tarp", (44, 86, 150))  # the classic blue PE tarp, faded (data: TARP colours)
    noise, rng = ctx.noise, ctx.rng
    W, Dp, hf, hb = CANOPY_W, CANOPY_D, CANOPY_HF, CANOPY_HB
    Wt, Dt = W + 0.6, Dp + 0.8
    th = 0.03
    sag_c, sag_e = 0.75, 0.32

    def surf(x, z):
        u, v = 2 * x / W, 2 * z / Dp
        plane = lerp(hf, hb, (v + 1) / 2) + 0.05
        cu, cv = max(0.0, 1 - u * u), max(0.0, 1 - v * v)
        y = plane - sag_c * cu * cv - sag_e * 0.5 * (cu + cv) * (1 - 0.6 * cu * cv)
        # pooled water weighs the middle down a little more, a bit off centre
        y -= 0.25 * math.exp(-((x - 0.5) / 1.4) ** 2 - ((z + 0.2) / 1.1) ** 2)
        # past the poles the sheet falls away
        ou, ov = max(0.0, abs(u) - 1) * W / 2, max(0.0, abs(v) - 1) * Dp / 2
        y -= 1.4 * ou ** 1.4 + 1.1 * ov ** 1.4
        # tension creases radiating from the four tied corners toward the middle
        for sx in (-1, 1):
            for sz in (-1, 1):
                cx, cz = sx * W / 2, sz * Dp / 2
                dx, dz = -cx, -cz
                ln = math.hypot(dx, dz)
                px, pz = x - cx, z - cz
                along = (px * dx + pz * dz) / ln
                across = (px * dz - pz * dx) / ln
                if 0 < along < ln * 0.55:
                    fall = math.sin(math.pi * along / (ln * 0.55))
                    for k_, off in enumerate((-0.35, 0.0, 0.4)):
                        y += 0.05 * fall * math.exp(-((across - off - 0.08 * k_) / 0.09) ** 2) * (1 - 0.3 * k_)
        y += 0.03 * noise.fbm((x * 0.9, z * 0.9, 0.5), 2)
        return y

    nu, nv = 31, 27
    xs = [lerp(-Wt / 2, Wt / 2, i / (nu - 1)) for i in range(nu)]
    zs = [lerp(Dt / 2, -Dt / 2, j / (nv - 1)) for j in range(nv)]  # back to front
    pts = [[Vector((x + 0.04 * noise.n((x, z, 3.0)), surf(x, z), z)) for z in zs] for x in xs]
    # the front valance: rows hanging from the front edge, ragged at the bottom
    hang_rows = 4
    for i in range(nu):
        edge = pts[i][-1]
        saw = (xs[i] * 1.45 + 0.35 * noise.n((xs[i] * 0.7, 5.0, 1.0))) % 1.0  # torn into hanging tatters
        drop = 0.42 + 0.2 * noise.fbm((xs[i] * 0.5, 4.0, 1.0), 2) + 0.28 * (1 - abs(2 * saw - 1)) ** 1.5
        for k_ in range(1, hang_rows + 1):
            t = k_ / hang_rows
            sway = 0.05 * math.sin(xs[i] * 2.3 + t * 2) * t
            pts[i].append(edge + Vector((0.0, -drop * t, -0.06 * t + sway)))
    nvv = nv + hang_rows
    # the tear: cells cut out on the right side of the middle, a ragged outline
    tc = Vector((1.6, 0.0, 0.9))

    def torn(i, j):
        if j >= nv - 2:
            return False
        c = (pts[i][j] + pts[i + 1][j + 1]) / 2
        d = math.hypot((c.x - tc.x) / 0.62, (c.z - tc.z) / 0.42)
        return d < 1 + 0.3 * noise.n((math.cos(math.atan2(c.z - tc.z, c.x - tc.x)) * 1.5,
                                      math.sin(math.atan2(c.z - tc.z, c.x - tc.x)) * 1.5, 7.0))

    # the hole's edge: the grid points round the cut moved onto its ragged outline
    def hole_r(a):
        return 1 + 0.3 * noise.n((math.cos(a) * 1.5, math.sin(a) * 1.5, 7.0)) + 0.12 * noise.n((a * 5.0, 1.0, 3.0))

    for i in range(1, nu - 1):
        for j in range(1, nv - 2):
            cells = [torn(a, b) for a in (i - 1, i) for b in (j - 1, j)]
            if any(cells) and not all(cells):
                p = pts[i][j]
                dx, dz = (p.x - tc.x) / 0.62, (p.z - tc.z) / 0.42
                a = math.atan2(dz, dx)
                rr = hole_r(a) * 0.92
                p.x, p.z = tc.x + math.cos(a) * rr * 0.62, tc.z + math.sin(a) * rr * 0.42
                p.y = surf(p.x, p.z)
    top, bot = [], []
    for i in range(nu):
        rt, rb = [], []
        for j in range(nvv):
            p = pts[i][j]
            du = pts[min(i + 1, nu - 1)][j] - pts[max(i - 1, 0)][j]
            dv = pts[i][min(j + 1, nvv - 1)] - pts[i][max(j - 1, 0)]
            n = du.cross(dv).normalized()
            if n.y < -0.1 or (abs(n.y) <= 0.1 and n.z > 0):
                n = -n
            hem = i in (0, nu - 1) or j in (0, nvv - 1)
            t = th * (1.6 if hem else 1.0)
            rt.append(p + n * t / 2)
            rb.append(p - n * t / 2)
        top.append(rt)
        bot.append(rb)
    ctx.add("Tarp", _grid_slab(top, bot, keep=lambda i, j: not torn(i, j)))

    def on(x, z):
        """The tarp's top surface point and normal at (x, z) (on the grid, bilinear)."""
        i = (x + Wt / 2) / Wt * (nu - 1)
        j = (Dt / 2 - z) / Dt * (nv - 1)
        i0, j0 = max(0, min(int(i), nu - 2)), max(0, min(int(j), nv - 2))
        fi, fj = i - i0, j - j0
        p = top[i0][j0].lerp(top[i0 + 1][j0], fi).lerp(top[i0][j0 + 1].lerp(top[i0 + 1][j0 + 1], fi), fj)
        n = (top[i0][j0] - bot[i0][j0]).normalized()
        return p, n

    # the flap of the tear, hanging down through the hole from its back edge
    fp, fn_ = on(tc.x, tc.z + 0.38)
    flap_t, flap_b = [], []
    for i in range(5):
        x = tc.x + lerp(-0.42, 0.42, i / 4)
        rt, rb = [], []
        for j in range(5):
            t = j / 4
            p = Vector((x, fp.y - 0.04 - 0.55 * t, tc.z + 0.36 - 0.12 * t - 0.05 * math.sin(math.pi * t)))
            p.x += 0.04 * noise.n((x * 5, t * 3, 9.0))
            rt.append(p + Vector((0, 0, -th / 2)))
            rb.append(p + Vector((0, 0, th / 2)))
        flap_t.append(rt)
        flap_b.append(rb)
    ctx.add("Tarp", _grid_slab(flap_t, flap_b))
    # gaffer-tape patches over old rips, a hair above the top surface
    for k_ in range(3):
        x, z = rng.uniform(-2.4, 2.4), rng.uniform(-1.8, 1.8)
        if math.hypot(x - tc.x, z - tc.z) < 1.0:
            continue
        ang = rng.uniform(0, 180)
        ln = rng.uniform(0.5, 0.9)
        rows = []
        for a in range(4):
            t = lerp(-ln / 2, ln / 2, a / 3)
            rows.append([(x + math.cos(math.radians(ang)) * t - math.sin(math.radians(ang)) * w,
                          z + math.sin(math.radians(ang)) * t + math.cos(math.radians(ang)) * w) for w in (-0.12, 0.0, 0.12)])
        tt, tb = [], []
        for row in rows:
            rt, rb = [], []
            for x_, z_ in row:
                p, n = on(x_, z_)
                rt.append(p + n * 0.022)
                rb.append(p + n * 0.006)
            tt.append(rt)
            tb.append(rb)
        ctx.add("FabricDark", _grid_slab(tt, tb))
    # the poles: scaffold tube, two timbers, grey conduit; their feet; rope lashings and grommets
    poles = {(-1, -1): "scaffold", (1, -1): "timber", (-1, 1): "conduit", (1, 1): "timber"}
    for (sx, sz), kind in poles.items():
        x, z = sx * W / 2, sz * Dp / 2
        ptop, pn = on(x, z)
        ytop = ptop.y - th - 0.012
        foot = Vector((x + rng.uniform(-0.12, 0.12), FLOOR, z + rng.uniform(-0.12, 0.12)))
        topv = Vector((x, ytop, z))
        if kind == "scaffold":
            ctx.add("Metal", tube([foot + Vector((0, 0.3, 0)), topv], 0.1, segs=12))
            ctx.add("Metal", cyl(0.13, 0.12, 12, bevel=0.015), T(*(topv - Vector((0, 0.32, 0)))))  # a coupler
            _cinder_block(ctx, (foot.x + 0.33, foot.z), 0)
        elif kind == "conduit":
            ctx.add("PlasticDark", tube([foot + Vector((0, 0.2, 0)), topv], 0.07, segs=10))
            _bucket(ctx, (foot.x, foot.z))
        else:
            ln = (topv - foot).length
            dirv = (topv - foot).normalized()
            m = T(*foot) @ _align_y(dirv) @ R(0, rng.uniform(-10, 10), 0) @ T(0, ln / 2 + 0.3, 0)
            ctx.add("Wood" if sx < 0 or sz < 0 else "WoodDark", box(0.26, ln - 0.62, 0.26, bevel=0.04), m)
            _cinder_block(ctx, (foot.x + (0.33 if sx > 0 else -0.33), foot.z), 0)
        # lashing: rope turns round the pole top, a grommet in the tarp above
        for k_ in range(2):
            ctx.add("FabricDark", _torus(0.16 if kind == "timber" else 0.13, 0.025, segs=8, rsegs=4),
                    T(x, ytop - 0.12 - 0.05 * k_, z) @ R(rng.uniform(-8, 8), 0, rng.uniform(-8, 8)))
        gp, gn = on(x + sx * 0.18, z + sz * 0.18)
        ctx.add("Metal", _torus(0.055, 0.02, segs=10, rsegs=4), T(*(gp + gn * 0.004)) @ _align_y(gn))
        ctx.add("FabricDark", tube([gp + gn * 0.01, gp + Vector((-sx * 0.05, -0.12, -sz * 0.05)),
                                    Vector((x, ytop - 0.16, z)) + Vector((sx * 0.12, 0, sz * 0.12))], 0.022, segs=5))
    # guy ropes from the front corners to steel pegs in front
    for sx in (-1, 1):
        x, z = sx * W / 2, -Dp / 2
        top_p = Vector((x, CANOPY_HF - 0.3, z))
        peg = Vector((x + sx * 0.9, FLOOR + 0.25, z - 1.4))
        mid = top_p.lerp(peg, 0.5) - Vector((0, 0.08, 0))
        ctx.add("FabricDark", tube([top_p, mid, peg], 0.026, segs=5))
        ctx.add("Metal", tube([peg + Vector((0, 0.06, 0)), Vector((peg.x, FLOOR - 0.15, peg.z))], 0.035, segs=6))
        ctx.add("Metal", _torus(0.05, 0.016, segs=8, rsegs=4), T(peg.x, peg.y + 0.07, peg.z) @ R(90, 0, 0))
    # the bulb on its flex, hanging from the middle
    bp, bn = on(-0.4, -0.3)
    drop = 1.35
    by = bp.y - th - drop
    ctx.add("Black", tube([bp - Vector((0, th, 0)), Vector((bp.x + 0.03, by + 0.6, bp.z)), Vector((bp.x, by + 0.12, bp.z))],
                          0.02, segs=6))
    ctx.add("PlasticDark", lathe([(0.0, 0.0), (0.05, 0.0), (0.055, 0.02), (0.055, 0.12), (0.03, 0.15), (0.0, 0.15)], segs=12),
            T(bp.x, by - 0.03, bp.z))
    bulb = lathe([(0.0, -0.2), (0.05, -0.19), (0.08, -0.15), (0.085, -0.1), (0.06, -0.04), (0.035, 0.0), (0.0, 0.0)],
                 segs=14)
    ctx.add("Glow", bulb, T(bp.x, by - 0.03, bp.z))
    ctx.mark("Light", (bp.x, by - 0.15, bp.z))

    def tarp(p):
        x, y, z = p.co
        k = 0.86 + 0.14 * noise.fbm(p.co * 1.3, 2)
        k *= 1 - 0.3 * smoothstep(0.0, 0.5, -p.convex)
        if p.normal.y > 0.3:  # the pool: a dark wet patch and its dried tide rings
            d = math.hypot((x - 0.5) / 1.4, (z + 0.2) / 1.1) * (1 + 0.2 * noise.fbm(p.co * 1.4, 2))
            ring = smoothstep(0.75, 0.95, d) * (1 - smoothstep(1.0, 1.2, d))
            k *= 1 - 0.38 * (1 - smoothstep(0.2, 0.8, d)) - 0.12 * ring
        else:  # the underside: shaded
            k *= 0.82
        k *= 1 - 0.2 * smoothstep(-2.6, -3.3, z)  # grime on the valance
        return (k * 0.95, k * 0.97, k)

    ctx.wear("Tarp", tarp)
    ctx.wear("Concrete", mul(ground_dirt(0.4, 0.35, noise), cavity(0.35), lambda p: 0.8 + 0.2 * noise.fbm(p.co * 4, 2)))
    ctx.wear("Wood", mul(ground_dirt(1.0, 0.4, noise), edge_wear(0.1), lambda p: 0.75 + 0.25 * noise.fbm(p.co * Vector((6, 0.6, 6)), 2)))
    ctx.wear("WoodDark", mul(ground_dirt(1.0, 0.3, noise), lambda p: 0.8 + 0.2 * noise.fbm(p.co * Vector((6, 0.6, 6)), 2)))
    ctx.wear("Metal", mul(ground_dirt(1.2, 0.35, noise), lambda p: (0.82, 0.8, 0.78)))
    ctx.wear("PlasticDark", mul(ground_dirt(0.9, 0.3, noise), cavity(0.3)))
    ctx.wear("FabricDark", lambda p: 0.8 + 0.2 * noise.fbm(p.co * 3, 2))


# ----------------------------------------------------------------------------------------------
# The table goods (origin = the table top under the item's centre; lowest point FLOOR above it)
# ----------------------------------------------------------------------------------------------
def _watch(ctx, at, yaw, kind, noise, r=0.07):
    """A wristwatch lying on a pillow top at `at` (the case's underside centre): a steel or gold
    case with lugs and a crown, a polished bezel ring proud of the dial (white or black), four
    hour batons and the two hands proud of the dial. kind = (case layer, dial layer). (No
    crystal: an opaque glass layer would hide the dial.)"""
    m = T(*at) @ R(0, yaw, 0)
    case, dial = kind
    ctx.add(case, lathe([(0.0, 0.0), (r * 0.8, 0.0), (r * 0.97, 0.008), (r, 0.022), (r * 0.97, 0.034),
                         (r * 0.86, 0.04), (0.0, 0.04)], segs=14), m)
    ctx.add(case, _torus(r * 0.86, 0.009, segs=12, rsegs=3), m @ T(0, 0.043, 0))  # the bezel
    for sz in (-1, 1):  # lugs (one block each end, the strap between them)
        ctx.add(case, box(r * 1.05, 0.02, 0.05), m @ T(0, 0.016, sz * (r + 0.012)))
    ctx.add(case, cyl(0.013, 0.025, 8), m @ T(r + 0.008, 0.022, 0) @ R(0, 0, 90))
    ctx.add(dial, cyl(r * 0.8, 0.008, 14), m @ T(0, 0.046, 0))
    ink = "Black" if dial == "Paper" else "Chrome"
    for k_ in range(4):
        a = 2 * math.pi * k_ / 4
        ctx.add(ink, box(0.008, 0.008, 0.018), m @ T(math.cos(a) * r * 0.6, 0.053, math.sin(a) * r * 0.6) @ R(0, -math.degrees(a) + 90, 0))
    for ln, ang in ((r * 0.45, 40.0), (r * 0.65, 200.0)):  # hands
        ctx.add(ink, box(0.01, 0.006, ln), m @ R(0, ang, 0) @ T(0, 0.061 if ang > 100 else 0.06, ln / 2))


def watch_case(ctx):
    """Open aluminium attache case of watches (1.5 x 1.1 x 0.28, the lid open ~100 degrees standing
    1.1 up behind): brushed panels between aluminium edge extrusions, chrome ball corners, two
    latches and a combination lock, the black handle; inside a wine velvet lining with six
    oval watch pillows in two rows, each with a watch strapped round it (steel, gold, leather
    and bracelet straps, white and black dials); egg-crate foam in the lid. Dented corner,
    scuffed panels."""
    ctx.budget = 8000
    ctx.smooth_angle = 40
    ctx.tint("Fabric", (92, 26, 32))  # wine velvet
    noise, rng = ctx.noise, ctx.rng
    w, d, hb, hl = 1.5, 1.1, 0.27, 0.1
    y0 = FLOOR
    wall = 0.035

    def dent(p):  # the front left bottom corner knocked in
        c = Vector((-w / 2, y0 + 0.05, -d / 2))
        k = math.exp(-((p - c).length / 0.14) ** 2)
        return p + Vector((0.025, 0.01, 0.025)) * k

    ctx.add("Metal", _tray(w, d, hb, wall, 0.04, 0.05, y0, bevel=0.012, warp=dent))
    # the extrusions: a band round the top edge and one round the bottom
    ctx.add("Chrome", _rr_band(w, d, 0.05, y0 + hb - 0.05, y0 + hb + 0.008, 0.006, 0.018, k=3, m=0))
    ctx.add("Chrome", _rr_band(w, d, 0.05, y0 + 0.004, y0 + 0.055, 0.006, 0.016, k=3, m=0))
    for sx in (-1, 1):  # ball corners at the bottom
        for sz in (-1, 1):
            ctx.add("Chrome", sphere(0.045, 8, 4), T(sx * (w / 2 - 0.005), y0 + 0.045, sz * (d / 2 - 0.005)) @ S(1, 1.1, 1))
    # front: latches, the lock, the handle on its two posts
    for sx in (-1, 1):
        ctx.add("Chrome", _rbox(0.13, 0.13, 0.03, 0.02, k=1), T(sx * 0.48, y0 + hb - 0.08, -d / 2 - 0.028))
        ctx.add("Black", _rbox(0.07, 0.03, 0.02, 0.008, k=1), T(sx * 0.48, y0 + hb - 0.08, -d / 2 - 0.046))
    ctx.add("Chrome", _rbox(0.2, 0.1, 0.03, 0.015, k=1), T(0, y0 + hb - 0.08, -d / 2 - 0.028))
    for k_ in range(3):
        ctx.add("Metal", cyl(0.016, 0.035, 10), T(-0.04 + 0.04 * k_, y0 + hb - 0.08, -d / 2 - 0.05) @ R(0, 0, 90))
    for sx in (-1, 1):
        ctx.add("Chrome", _rbox(0.05, 0.05, 0.08, 0.015, k=1), T(sx * 0.17, y0 + 0.12, -d / 2 - 0.045))
    hp = [(-0.17, y0 + 0.12, -d / 2 - 0.085), (-0.14, y0 + 0.12, -d / 2 - 0.14), (0.14, y0 + 0.12, -d / 2 - 0.14),
          (0.17, y0 + 0.12, -d / 2 - 0.085)]
    ctx.add("Black", _sweep(_resample(hp, 10), _rpoly([(-0.02, -0.035), (0.02, -0.035), (0.02, 0.035), (-0.02, 0.035)], 0.015, 2),
                            ups=Vector((0, 1, 0))))
    # inside: the velvet lining (its own floor 1.5 cm above the shell's), the six pillows
    iw, idp = w - 2 * wall - 0.02, d - 2 * wall - 0.02
    ctx.add("Fabric", _rbox(iw, 0.06, idp, 0.02), T(0, y0 + 0.04 + 0.012 + 0.03, 0))
    floor_y = y0 + 0.04 + 0.012 + 0.06
    kinds = [("Chrome", "Paper"), ("Chrome", "Black"), ("Gold", "Paper"), ("Chrome", "Black"), ("Gold", "Black"),
             ("Chrome", "Paper")]
    straps = ["Leather", "Chrome", "Gold", "Leather", "Leather", "Chrome"]
    rng.shuffle(kinds)
    pr = 0.058  # pillow half-height
    for k_, (row, col) in enumerate([(r_, c_) for r_ in range(2) for c_ in range(3)]):
        cx = (col - 1) * 0.44 + rng.uniform(-0.02, 0.02)
        cz = -0.2 + row * 0.4
        # the pillow: a soft oval cushion lying across X, squashed where it sits
        pil = bmesh.new()
        bmesh.ops.create_uvsphere(pil, u_segments=12, v_segments=8, radius=1.0)
        cy_ = floor_y + pr - 0.01
        for v in pil.verts:
            n = v.co.copy()
            # a fat oval cylinder with soft rounded ends (superellipse along X), squashed flat
            # where it sits on the velvet
            ex = math.copysign(abs(n.x) ** 0.35, n.x)
            p = Vector((ex * 0.16, n.y * pr, n.z * 0.085))
            p.y = max(p.y, -pr + 0.01)
            v.co = p + Vector((cx, cy_, cz))
        ctx.add("Fabric", pil)
        case, dial = kinds[k_]
        layer = "Chrome"
        strap = straps[k_]
        st_layer = "Leather" if strap == "Leather" else "Chrome"
        # the strap round the pillow (an ellipse in the Y-Z plane), a hair outside its surface
        ring = []
        for a in range(16):
            t = 2 * math.pi * a / 16
            ring.append((cx, max(cy_ + math.sin(t) * (pr + 0.012), floor_y + 0.008), cz + math.cos(t) * (0.085 + 0.012)))
        ctx.add(st_layer, _sweep(ring, [(-0.035, -0.006), (0.035, -0.006), (0.035, 0.006), (-0.035, 0.006)],
                                 ups=Vector((1, 0, 0)), closed=True))
        _watch(ctx, (cx, cy_ + pr + 0.014, cz), rng.uniform(-12, 12), (layer, dial), noise)
        if case == "Gold":
            ctx.gold = getattr(ctx, "gold", []) + [Vector((cx, cy_, cz))]
        if strap == "Gold":
            ctx.gold = getattr(ctx, "gold", []) + [Vector((cx, cy_, cz))]
    # the lid: built closed (a shallow tray upside down over the base), then swung open about
    # the hinge at the back top edge
    ang = 100 + rng.uniform(-4, 4)
    hinge = Vector((0, y0 + hb + 0.012, d / 2 - 0.005))
    lid_m = T(*hinge) @ R(ang, 0, 0) @ T(*(-hinge))
    lid = _tray(w, d, hl, wall, 0.03, 0.05, 0.0, bevel=0.012)
    bmesh.ops.transform(lid, matrix=T(0, y0 + hb + 0.012 + hl, 0) @ R(180, 0, 0), verts=lid.verts)
    ctx.add("Metal", lid, lid_m)
    ctx.add("Chrome", _rr_band(w, d, 0.05, y0 + hb + 0.004, y0 + hb + 0.06, 0.006, 0.018, k=3, m=0), lid_m)
    for sx in (-1, 1):
        for sz in (-1, 1):
            ctx.add("Chrome", sphere(0.045, 8, 4), lid_m @ T(sx * (w / 2 - 0.005), y0 + hb + hl - 0.03, sz * (d / 2 - 0.005)) @ S(1, 1.1, 1))
    for sx in (-1, 1):  # hinges
        ctx.add("Chrome", cyl(0.03, 0.2, 10), T(sx * 0.45, hinge.y + 0.01, hinge.z + 0.05) @ R(0, 0, 90))
    # egg-crate foam in the lid (its back 1 cm off the lid's inner floor)
    nu, nv = 17, 13
    ft, fb = [], []
    for i in range(nu):
        rt, rb = [], []
        for j in range(nv):
            x = lerp(-iw / 2, iw / 2, i / (nu - 1))
            z = lerp(-idp / 2, idp / 2, j / (nv - 1))
            edge = min(i, j, nu - 1 - i, nv - 1 - j)
            bump = 0.04 * (0.5 + 0.5 * math.cos(math.pi * i / 2) * math.cos(math.pi * j / 2)) * smoothstep(0, 2, edge)
            ybase = y0 + hb + 0.012 + hl - 0.03 - 0.012  # under the lid's inner floor (closed pose)
            rt.append(Vector((x, ybase - 0.035 - bump, z)))
            rb.append(Vector((x, ybase, z)))
        ft.append(rt)
        fb.append(rb)
    ctx.add("Foam", _grid_slab(ft, fb), lid_m)
    gold = getattr(ctx, "gold", [])

    def chrome(p):
        k = 0.82 + 0.15 * noise.fbm(p.co * 8, 2)
        for g in gold:
            if (p.co - g).length < 0.2:
                return (k * 1.0, k * 0.78, k * 0.42)
        return k

    def alu(p):
        # brushed aluminium: streaky, scuffed on the lower front, grime in the corners
        k = 0.82 + 0.1 * noise.fbm((p.co.x * 30, p.co.y * 2, p.co.z * 2), 2)
        k *= 1 - 0.18 * smoothstep(0.55, 0.85, noise.fbm(p.co * 6, 2) * 0.5 + 0.5)
        return k

    ctx.wear("Metal", mul(alu, cavity(0.35)))
    ctx.wear("Chrome", chrome)
    ctx.wear("Fabric", mul(cavity(0.4), lambda p: 0.85 + 0.15 * noise.fbm(p.co * 9, 2)))
    ctx.wear("Foam", mul(cavity(0.5), lambda p: (0.5, 0.5, 0.52)))
    ctx.wear("Leather", lambda p: (0.9, 0.62, 0.45))
    ctx.wear("Black", cavity(0.2))
    ctx.wear("Paper", lambda p: 0.95)


def _coin_stack(ctx, x, y, z, n, r, lean, noise, rng):
    """A short stack of coins (one ribbed cylinder per few coins, grooves between them), leaning a
    little, its top coin slid aside."""
    h = 0.011
    m = T(x, y, z) @ R(lean[0], 0, lean[1])
    for k_ in range(n):
        ctx.add("Metal", lathe([(0.0, 0.0), (r - 0.003, 0.0), (r, 0.002), (r, h - 0.003), (r - 0.003, h - 0.0005), (0.0, h - 0.0005)],
                               segs=14), m @ T(rng.uniform(-0.004, 0.004), k_ * h, rng.uniform(-0.004, 0.004)))


def cash_box(ctx):
    """Open steel cash box (1.0 x 0.78 x 0.22, the lid open ~100 degrees standing 0.8 up behind):
    folded powder-coated steel with a rolled lip, the lid with its folding handle lying in a
    pressed recess, the cylinder lock on the front with the key in it on a ring with a paper
    tag; inside, the black plastic coin tray (five round-bottomed coin cups at the front, three
    note slots behind) sitting 1.2 cm clear of the walls, coin stacks in the cups, a wad of
    notes held by a paper band and a few loose notes in the slots. Dented corner, grimy."""
    ctx.budget = 5500
    ctx.smooth_angle = 40
    ctx.tint("MetalPainted", (62, 66, 74))  # (data: grey / black / red 120, 36, 32 / blue 40, 60, 110)
    noise, rng = ctx.noise, ctx.rng
    w, d, hb, hl = 1.0, 0.78, 0.22, 0.07
    y0 = FLOOR
    wall = 0.022

    def dent(p):  # the back right top corner knocked in
        c = Vector((w / 2, y0 + hb, d / 2))
        k = math.exp(-((p - c).length / 0.12) ** 2)
        return p - Vector((0.02, 0.015, 0.02)) * k

    ctx.add("MetalPainted", _tray(w, d, hb, wall, 0.025, 0.04, y0, bevel=0.012, lip=0.014, warp=dent))
    # the lock and the key on its ring, a paper tag hanging from it
    ly = y0 + hb * 0.55
    ctx.add("Chrome", lathe([(0.0, 0.0), (0.05, 0.0), (0.05, 0.012), (0.042, 0.03), (0.0, 0.03)], segs=16),
            T(0, ly, -d / 2 - 0.005) @ R(-90, 0, 0))
    ctx.add("Black", box(0.018, 0.045, 0.01), T(0, ly, -d / 2 - 0.038))
    key = [(0.0, 0.0), (0.035, 0.0), (0.035, 0.04), (0.02, 0.06), (-0.02, 0.06), (-0.035, 0.04), (-0.035, 0.0)]
    ctx.add("Metal", box(0.007, 0.024, 0.06), T(0, ly, -d / 2 - 0.06))
    rings = [[(x * 1.0, ly + yv - 0.015 + 0.03, -d / 2 - 0.09 - 0.006) for x, yv in key][::-1],
             [(x * 1.0, ly + yv - 0.015 + 0.03, -d / 2 - 0.09 + 0.006) for x, yv in key][::-1]]
    ctx.add("Metal", loft([[(p[0], p[1] - 0.045, p[2]) for p in r] for r in rings], cap_start=True, cap_end=True))
    ctx.add("Metal", _torus(0.03, 0.005, segs=12, rsegs=4), T(0, ly - 0.055, -d / 2 - 0.1) @ R(90, 0, 25))
    ctx.add("Cardboard", _rbox(0.07, 0.1, 0.008, 0.004, k=1), T(0.025, ly - 0.07, -d / 2 - 0.11) @ R(25, 0, 14))
    # the lid: built closed (an upside-down tray on the rim), swung open about the back hinge
    ang = 100 + rng.uniform(-3, 3)
    hinge = Vector((0, y0 + hb + 0.008, d / 2 + 0.008))
    lid_m = T(*hinge) @ R(ang, 0, 0) @ T(*(-hinge))
    lid = _tray(w + 0.03, d + 0.03, hl, wall, 0.02, 0.05, 0.0, bevel=0.012)
    bmesh.ops.transform(lid, matrix=T(0, y0 + hb + 0.008 + hl, 0) @ R(180, 0, 0), verts=lid.verts)
    ctx.add("MetalPainted", lid, lid_m)
    # the folding handle lying in its pressed recess on the lid's top
    ltop = y0 + hb + 0.008 + hl
    ctx.add("MetalPainted", _rbox(0.46, 0.012, 0.14, 0.006, k=1), lid_m @ T(0, ltop + 0.004, 0.0))
    hp = [(-0.18, ltop + 0.012, 0.02), (-0.16, ltop + 0.022, -0.04), (0.16, ltop + 0.022, -0.04), (0.18, ltop + 0.012, 0.02)]
    ctx.add("Metal", tube(_resample(hp, 8), 0.012, segs=6), lid_m)
    for sx in (-1, 1):
        ctx.add("Metal", _rbox(0.04, 0.02, 0.04, 0.008, k=1), lid_m @ T(sx * 0.18, ltop + 0.02, 0.02))
    ctx.add("Metal", cyl(0.014, 0.7, 10), T(0, hinge.y, hinge.z) @ R(0, 0, 90))  # the hinge pin
    # the coin tray: its own skin, 1.2 cm clear of the box walls, its rim 2 cm under the box's
    tw, td = w - 2 * wall - 0.024, d - 2 * wall - 0.024
    th = 0.095  # (shallow cups: the tray rests on the box's pressed ledges, the note well below)
    ty = y0 + hb - 0.02 - th
    ctx.add("PlasticDark", _tray(tw, td, th, 0.012, 0.012, 0.03, ty, bevel=0.006))
    zl = -td / 2 + td * 0.48  # the long divider: coin cups in front, note slots behind
    ctx.add("PlasticDark", _rbox(tw - 0.01, th - 0.018, 0.012, 0.004, k=1), T(0, ty + th / 2 - 0.0, zl))
    for k_ in range(1, 5):
        x = -tw / 2 + tw * k_ / 5
        ctx.add("PlasticDark", _rbox(0.012, th - 0.018, zl + td / 2 - 0.01, 0.004, k=1), T(x, ty + th / 2, (zl - td / 2) / 2))
    for k_ in (1, 2):
        x = -tw / 2 + tw * k_ / 3
        ctx.add("PlasticDark", _rbox(0.012, th - 0.018, td / 2 - zl - 0.01, 0.004, k=1), T(x, ty + th / 2, (zl + td / 2) / 2))
    # coins in the cups
    floor_t = ty + 0.012 + 0.004
    cup = tw / 5
    sizes = [0.042, 0.036, 0.046, 0.032, 0.04]
    for k_ in range(5):
        if k_ == 3:
            continue  # (an empty cup)
        x = -tw / 2 + cup * (k_ + 0.5)
        z = (-td / 2 + zl) / 2
        n = rng.randint(3, 6)
        _coin_stack(ctx, x + rng.uniform(-0.015, 0.015), floor_t, z - 0.02, n, sizes[k_], (rng.uniform(-6, 6), rng.uniform(-6, 6)),
                    noise, rng)
        if rng.random() < 0.7:
            _coin_stack(ctx, x + rng.uniform(-0.02, 0.02), floor_t, z + 0.06, 1, sizes[k_], (rng.uniform(-12, 12), rng.uniform(-12, 12)),
                        noise, rng)
    # the wad of notes: a bent block of paper with a paper band, lying across two note slots
    nw, nd, nt = 0.5, 0.23, 0.05
    zc = (zl + td / 2) / 2
    ybase = ty + th + 0.006
    rows, cols = 3, 7
    top, bot = [], []
    for i in range(cols):
        rt, rb = [], []
        for j in range(rows):
            x = lerp(-nw / 2, nw / 2, i / (cols - 1))
            z = lerp(-nd / 2, nd / 2, j / (rows - 1))
            sag = 0.02 * (1 - (2 * i / (cols - 1) - 1) ** 2)  # curling up at the ends
            rt.append(Vector((x, ybase + nt + 0.01 - sag, z)))
            rb.append(Vector((x, ybase + 0.01 - sag * 0.9, z)))
        top.append(rt)
        bot.append(rb)
    wad_m = T(0.04, 0, zc) @ R(0, 8, 0)
    ctx.add("Paper", _grid_slab(top, bot), wad_m)
    ctx.add("Paper", _rbox(0.07, nt + 0.024, nd + 0.024, 0.006, k=1), wad_m @ T(0.02, ybase + 0.01 + nt / 2 - 0.02, 0))
    # loose notes in the right slot, standing on edge, fanned
    for k_ in range(3):
        x = tw / 2 - tw / 6 + (k_ - 1) * 0.03
        ctx.add("Paper", _rbox(0.012, 0.16, 0.22, 0.004, k=1), T(x, ty + 0.012 + 0.09, zc) @ R(0, 0, (k_ - 1) * 9))

    coin_tint = {}

    def coin(p):
        if p.co.z < -d / 2:  # the brass key and its ring
            return (0.95, 0.78, 0.45)
        if p.co.y > y0 + hb or abs(p.co.x) > w / 2 - wall:  # the handle, the hinge pin: plain steel
            return 0.7
        key = (round(p.co.x * 6), round(p.co.z * 6))
        if key not in coin_tint:
            coin_tint[key] = [(1.0, 0.62, 0.45), (1.0, 0.86, 0.52), (0.95, 0.95, 0.95)][len(coin_tint) % 3]
        c = coin_tint[key]
        k = 0.8 + 0.2 * noise.fbm(p.co * 20, 2)
        return (c[0] * k, c[1] * k, c[2] * k)

    def notes(p):
        k = 0.85 + 0.15 * noise.fbm(p.co * 12, 2)
        stripe = 0.85 + 0.15 * math.sin(p.co.y * 700)  # (the sheets' edges)
        return (0.72 * k * stripe, 0.8 * k * stripe, 0.66 * k * stripe)

    ctx.wear("MetalPainted", mul(cavity(0.35), edge_wear(0.1), _hand_grime(noise, (0, y0 + hb, -d / 2), 0.35, 0.25),
                                 lambda p: 0.85 + 0.15 * noise.fbm(p.co * 5, 2)))
    ctx.wear("Metal", coin)
    ctx.wear("Paper", notes)
    ctx.wear("PlasticDark", cavity(0.35))
    ctx.wear("Chrome", lambda p: 0.8)
    ctx.wear("Cardboard", lambda p: (0.95, 0.9, 0.8))


def _phone(ctx, kind, m, noise, rng):
    """One used phone lying in the tray (m: its frame, its underside at y = 0, long axis Z). kind:
    slab_up / slab_down (modern slab, glass face or back with the camera module), home (an older
    one with a round home button), cracked (a slab whose glass is broken into tilted shards),
    case_down (in a bright rubber case), flip (a closed clamshell), candy (a keypad brick)."""
    if kind in ("slab_up", "slab_down", "home", "cracked", "case_down"):
        w, ln, t = 0.235, 0.49, 0.045
        r = 0.04 if kind != "home" else 0.03
        body = _rr_loft([(0.0, w - 0.02, ln - 0.02, r - 0.01, 0, 0), (0.008, w, ln, r, 0, 0), (t - 0.008, w, ln, r, 0, 0),
                         (t, w - 0.016, ln - 0.016, r - 0.008, 0, 0)], "xz", k=3)
        if kind == "case_down":  # the rubber case: a thicker shell round it, lips over the glass
            ctx.add("Plastic", _rr_loft([(0.0, w + 0.02, ln + 0.02, r + 0.004, 0, 0), (0.012, w + 0.04, ln + 0.04, r + 0.012, 0, 0),
                                         (t + 0.012, w + 0.04, ln + 0.04, r + 0.012, 0, 0), (t + 0.02, w + 0.02, ln + 0.02, r + 0.006, 0, 0)],
                                        "xz", k=3), m)
            ctx.add("Black", _rbox(0.09, 0.03, 0.09, 0.02, k=1), m @ T(-0.05, t + 0.012, -ln / 2 + 0.08))
            return
        ctx.add("Chrome" if kind == "home" else "PlasticDark", body, m)
        if kind == "slab_down":  # the back: glass back + camera module with lenses
            ctx.add("PlasticDark", _rbox(0.1, 0.02, 0.1, 0.025, k=1), m @ T(-0.055, t + 0.004, -ln / 2 + 0.08))
            for dx, dz in ((-0.075, -ln / 2 + 0.058), (-0.035, -ln / 2 + 0.058), (-0.075, -ln / 2 + 0.1)):
                ctx.add("Black", cyl(0.016, 0.02, 10), m @ T(dx, t + 0.016, dz))
                ctx.add("Chrome", _torus(0.017, 0.004, segs=10, rsegs=3), m @ T(dx, t + 0.024, dz))
            return
        if kind == "cracked":  # the glass broken into shards, each tilted a little
            cx, cz = rng.uniform(-0.04, 0.04), rng.uniform(0.0, 0.12)
            n_ = 7
            gw, gl = w - 0.03, ln - 0.03
            for k_ in range(n_):
                a0, a1 = 2 * math.pi * k_ / n_, 2 * math.pi * (k_ + 1) / n_
                poly = [(cx, cz)]
                for a in (a0, (a0 + a1) / 2, a1):
                    # ray from the impact to the screen's edge
                    dx, dz = math.cos(a), math.sin(a)
                    tx = (gw / 2 - 0.003 - abs(cx)) / max(abs(dx), 1e-6) if dx else 1e9
                    tz = (gl / 2 - 0.003 - (cz if dz > 0 else -cz)) / max(abs(dz), 1e-6) if dz else 1e9
                    tt = min(tx, tz)
                    poly.append((cx + dx * tt, cz + dz * tt))
                c = Vector((sum(p[0] for p in poly) / 4, 0, sum(p[1] for p in poly) / 4))
                pts = [Vector((p[0], 0, p[1])).lerp(c, 0.04) for p in poly]
                rings = [[(p.x, t + 0.004, p.z) for p in pts], [(p.x, t + 0.012, p.z) for p in pts]]
                tilt = R(rng.uniform(-2.5, 2.5), 0, rng.uniform(-2.5, 2.5))
                bm = loft(rings, cap_start=True, cap_end=True)
                ctx.add("Glass", bm, m @ T(c.x, t + 0.008, c.z) @ tilt @ T(-c.x, -(t + 0.008), -c.z))
            return
        # the glass face: a screen slab proud of the frame, black
        sw, sl = w - 0.025, ln - (0.12 if kind == "home" else 0.03)
        ctx.add("Screen", _rr_loft([(t - 0.004, sw, sl, r - 0.012, 0, 0), (t + 0.006, sw, sl, r - 0.012, 0, 0),
                                    (t + 0.008, sw - 0.006, sl - 0.006, r - 0.015, 0, 0)], "xz", k=3), m)
        if kind == "home":
            ctx.add("PlasticDark", cyl(0.028, 0.012, 14), m @ T(0, t + 0.004, ln / 2 - 0.035))
            ctx.add("Black", box(0.06, 0.008, 0.012), m @ T(0, t + 0.004, -ln / 2 + 0.03))
        return
    if kind == "flip":
        w, ln, t = 0.2, 0.36, 0.075
        ctx.add("PlasticDark", _rbox(w, t * 0.5, ln, 0.03), m @ T(0, t * 0.25, 0))
        ctx.add("Chrome", _rbox(w - 0.004, t * 0.48, ln - 0.004, 0.03), m @ T(0, t * 0.5 + t * 0.24 + 0.002, 0))
        ctx.add("PlasticDark", cyl(0.03, w - 0.03, 12), m @ T(0, t * 0.5, -ln / 2 + 0.01) @ R(0, 0, 90))
        ctx.add("Screen", _rbox(0.09, 0.012, 0.1, 0.012, k=1), m @ T(0, t + 0.004, -ln / 2 + 0.11))
        ctx.add("Black", cyl(0.012, 0.012, 8), m @ T(0, t + 0.004, -ln / 2 + 0.04))
        return
    # candy: the keypad brick
    w, ln, t = 0.18, 0.42, 0.065
    ctx.add("PlasticDark", _rbox(w, t, ln, 0.035), m @ T(0, t / 2, 0))
    ctx.add("Screen", _rbox(0.12, 0.012, 0.11, 0.01, k=1), m @ T(0, t + 0.001, -ln / 2 + 0.11))
    ctx.add("Black", _rbox(0.14, 0.016, 0.2, 0.02, k=1), m @ T(0, t + 0.002, 0.07))
    for i in range(3):
        for j in range(4):
            ctx.add("Chrome", _rbox(0.036, 0.016, 0.03, 0.008, k=1), m @ T((i - 1) * 0.044, t + 0.015, 0.0 + j * 0.044))


def phone_tray(ctx):
    """Shallow cardboard tray (1.5 x 1.25 x 0.2) of second-hand phones on the stall: butted
    corrugated walls with a raw cut top edge, the front flap and one side flap folded down
    outside, a torn corner; seven phones in two rows, a few millimetres apart and above the
    floor: modern slabs face up and face down (camera modules), an older one with a home
    button, one with its glass smashed into shards, one in a bright rubber case, a closed
    flip phone and a keypad brick. Dusty, finger-marked."""
    ctx.budget = 6000
    ctx.smooth_angle = 35
    ctx.tint("Plastic", (190, 60, 80))  # the bright rubber case
    noise, rng = ctx.noise, ctx.rng
    w, d, h = 1.5, 1.25, 0.2
    y0 = FLOOR
    wall, fl = 0.03, 0.035

    def sag(p):  # a soft, slightly crushed cardboard tray: walls bowing, a dipped corner
        bow = 0.012 * math.sin(math.pi * (p.x / w + 0.5)) * (p.y - y0) / h
        p = p + Vector((0, 0, -bow if p.z < 0 else bow))
        c = Vector((w / 2, y0 + h, -d / 2))
        p.y -= 0.05 * math.exp(-((p - c).length / 0.22) ** 2)
        return p

    ctx.add("Cardboard", _tray(w, d, h, wall, fl, 0.02, y0, bevel=0.006, m=3, warp=sag))
    # the folded flaps, hanging outside the front wall and the right wall
    for side in ("front", "right"):
        if side == "front":
            fw, hang = w * 0.86, h * 0.72
            hinge = Vector((0, y0 + h - 0.004, -d / 2 - 0.012))
            ang = rng.uniform(14, 24)
            m = T(*hinge) @ R(-ang, 0, 0)
            ctx.add("Cardboard", _rbox(fw, hang, 0.024, 0.008, k=1), m @ T(0, -hang / 2, -0.012))
        else:
            fw, hang = d * 0.7, h * 0.7
            hinge = Vector((w / 2 + 0.012, y0 + h - 0.004, 0.05))
            ang = rng.uniform(14, 24)
            m = T(*hinge) @ R(0, 0, -ang)
            ctx.add("Cardboard", _rbox(0.024, hang, fw, 0.008, k=1), m @ T(0.012, -hang / 2, 0))
    # the phones
    kinds = ["slab_up", "slab_down", "home", "cracked", "case_down", "flip", "candy", "slab_up"]
    rng.shuffle(kinds)
    slots = [(i, j) for j in range(2) for i in range(4)]
    empty = rng.randrange(8)
    iw, idp = w - 2 * wall, d - 2 * wall
    for n_, (i, j) in enumerate(slots):
        if n_ == empty:
            continue
        cx = -iw / 2 + iw * (i + 0.5) / 4 + rng.uniform(-0.02, 0.02)
        cz = -idp / 2 + idp * (j + 0.5) / 2 + rng.uniform(-0.03, 0.03)
        m = T(cx, y0 + fl + 0.012, cz) @ R(0, rng.uniform(-7, 7), 0)
        _phone(ctx, kinds[n_ % len(kinds)], m, noise, rng)

    def card(p):
        k = 0.82 + 0.18 * noise.fbm(p.co * 4, 2)
        k *= 1 - 0.3 * smoothstep(0.0, 0.4, -p.convex)
        k *= 1 - 0.15 * smoothstep(0.55, 0.8, noise.fbm(p.co * 9, 2) * 0.5 + 0.5)  # water marks
        return (k, k * 0.97, k * 0.92)

    ctx.wear("Cardboard", card)
    ctx.wear("PlasticDark", mul(edge_wear(0.15), lambda p: 0.85))
    ctx.wear("Screen", lambda p: 0.75 + 0.25 * noise.fbm(p.co * 10, 2))  # finger smears
    ctx.wear("Glass", lambda p: 0.9 + 0.1 * noise.fbm(p.co * 20, 2))
    ctx.wear("Chrome", lambda p: 0.75)
    ctx.wear("Plastic", mul(edge_wear(0.1), lambda p: 0.85 + 0.15 * noise.fbm(p.co * 8, 2)))
    ctx.wear("Black", lambda p: 1.0)


PIECES = {
    "CrtTv": crt_tv,
    "Radio": radio,
    "Jacket1": jacket1,
    "Jacket2": jacket2,
    "ClothesRack": clothes_rack,
    "MarketTarp": market_tarp,
    "WatchCase": watch_case,
    "CashBox": cash_box,
    "PhoneTray": phone_tray,
}
