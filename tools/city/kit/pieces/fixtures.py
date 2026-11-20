"""Building fixtures of the city prop kit: the split air-con condenser, the gooseneck barn lamp,
the oval bulkhead light, the offset satellite dish, the cast-iron downpipe kit (straight
length, swan-neck offset, shoe, pipe bracket), the rooftop wooden water tank and the dumped
office chair.

Why these are meshes: the old props (tools/city/props_walls.py, props_objects.py) were
primitive stacks. The AC was a flat box with a disc and an X of bars, the lamp shade three
stacked cylinders on a kinked rod, the bulkhead a box and a ball, the dish a convex lentil of
two balls, the downpipe square box collars round a round pipe, the water tank a cylinder under
two stacked discs (exactly the "stacked cylinders" the player complained about), the chair a
box seat on a slab back. Here each one is modelled once, to its real proportions:
  * round things are lathes or swept tubes with enough segments; bends are real arcs
    (fillet_path), arms are smooth splines (spline);
  * pressed / cast / moulded parts are rounded boxes (rbox: every edge a true round) or
    prisms of their real section (angle iron, I-beams, U casings);
  * soft things (the chair's cushions) are rounded boxes sculpted by displacement (crown,
    waterfall front, lumbar curve) and smooth shaded;
  * nothing lies in another surface's plane: layers laid on others stand PROUD (>= 0.01) or
    cross them mid-face (a pipe's spigot inside the socket below it, rods sunk into staves,
    wall pieces' back faces 0.01-0.02 INTO the wall, never on its face).

Conventions (pieces/_template.py): Roblox axes, studs, +Y up. Floor pieces (WaterTank,
OfficeChair*): origin at the centre of the footprint on the floor, front = -Z. Wall pieces
(everything else): origin ON the wall face, local -Z out of the wall, +Z into it; where it sits
in height is said per piece (it matches the props_walls.py function it replaces, so the data
can pass the same origin). Only ONE tintable layer kind per piece (the marker's Tint goes to
every tintable layer). No bottles of any kind, nothing that reads as one.

Lamps: PropKit hides the old Neon bulb part (it keeps carrying the PointLight / SpotLight and
its tags, moved to the piece's Light marker), so the lit part is in the mesh: the gooseneck's
frosted bulb and the bulkhead's lens are Glow layers; GooseneckLampDead / BulkheadLightDead
have them in dull Glass (for the data's dead=True lamps).
"""

import math

import bmesh
from mathutils import Quaternion, Vector

from kitlib import (  # noqa: F401
    T,
    R,
    S,
    box,
    cyl,
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


# ==============================================================================================
# Shared helpers
# ==============================================================================================
def _axis_coords(h, r, m=3, n=1):
    """Coordinates from -h to h for one axis of a rounded box: `m` steps inside each rounded
    band (tan-spaced, so the rounding gets even angles) and `n` cells across the flat middle."""
    inner = h - r
    band = [inner + r * math.tan(math.pi / 4 * k / m) for k in range(1, m + 1)] if r > 1e-6 else []
    mid = [-inner + 2 * inner * k / n for k in range(n + 1)]
    return [-b for b in reversed(band)] + mid + band


def _grid_box(xs, ys, zs):
    """A closed box surface whose faces are grids on the given coordinate lists."""
    bm = bmesh.new()
    vs = {}
    nx, ny, nz = len(xs) - 1, len(ys) - 1, len(zs) - 1

    def V(i, j, k):
        key = (i, j, k)
        if key not in vs:
            vs[key] = bm.verts.new((xs[i], ys[j], zs[k]))
        return vs[key]

    for j in range(ny):
        for k in range(nz):
            bm.faces.new((V(0, j, k), V(0, j, k + 1), V(0, j + 1, k + 1), V(0, j + 1, k)))
            bm.faces.new((V(nx, j, k), V(nx, j + 1, k), V(nx, j + 1, k + 1), V(nx, j, k + 1)))
    for i in range(nx):
        for k in range(nz):
            bm.faces.new((V(i, 0, k), V(i + 1, 0, k), V(i + 1, 0, k + 1), V(i, 0, k + 1)))
            bm.faces.new((V(i, ny, k), V(i, ny, k + 1), V(i + 1, ny, k + 1), V(i + 1, ny, k)))
    for i in range(nx):
        for j in range(ny):
            bm.faces.new((V(i, j, 0), V(i, j + 1, 0), V(i + 1, j + 1, 0), V(i + 1, j, 0)))
            bm.faces.new((V(i, j, nz), V(i + 1, j, nz), V(i + 1, j + 1, nz), V(i, j + 1, nz)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def rbox(sx, sy, sz, r=0.03, m=3, n=(1, 1, 1)):
    """A box sx * sy * sz centred on the origin with EVERY edge a true round of radius r
    (m segments per quarter round), n = flat-middle cells per axis (more vertices for
    displacement and vertex colours). The rounding is exact (each band vertex is pushed onto
    the circle round its edge), so it shades like a pressed or moulded part."""
    r = min(r, sx * 0.49, sy * 0.49, sz * 0.49)
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    bm = _grid_box(_axis_coords(hx, r, m, n[0]), _axis_coords(hy, r, m, n[1]), _axis_coords(hz, r, m, n[2]))
    inner = (hx - r, hy - r, hz - r)
    for v in bm.verts:
        p = v.co
        c = Vector([max(-inner[i], min(inner[i], p[i])) for i in range(3)])
        d = p - c
        if d.length > 1e-9:
            v.co = c + d.normalized() * r
    return bm


def prism(poly, z0, z1, segs=1):
    """Extrudes a 2-D polygon [(x, y), ...] (convex or not) along Z from z0 to z1 (segs rings:
    more vertices along the length). Closed."""
    rings = [[(x, y, lerp(z0, z1, k / segs)) for x, y in poly] for k in range(segs + 1)]
    return loft(rings, cap_start=True, cap_end=True)


def spline(ctrl, n=6):
    """A Catmull-Rom curve through the control points (n points per span): smooth bent arms."""
    P = [Vector(p) for p in ctrl]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-2])
    return out


def fillet_path(pts, rad, nseg=8):
    """A polyline whose inner corners are replaced by circular arcs of radius `rad` (shrunk if a
    leg is too short): real pipe bends, not kinks."""
    P = [Vector(p) for p in pts]
    out = [P[0]]
    for i in range(1, len(P) - 1):
        a, b, c = P[i - 1], P[i], P[i + 1]
        d1, d2 = (a - b).normalized(), (c - b).normalized()
        ang = d1.angle(d2)
        if ang > math.pi - 1e-3:
            out.append(b)
            continue
        t = rad / math.tan(ang / 2)
        t = min(t, (a - b).length * (0.98 if i == 1 else 0.5), (c - b).length * (0.98 if i == len(P) - 2 else 0.5))
        r = t * math.tan(ang / 2)
        p1, p2 = b + d1 * t, b + d2 * t
        centre = b + (d1 + d2).normalized() * (r / math.sin(ang / 2))
        v1, v2 = p1 - centre, p2 - centre
        q = v1.rotation_difference(v2)
        for k in range(nseg + 1):
            out.append(centre + Quaternion().slerp(q, k / nseg) @ v1)
    out.append(P[-1])
    return out


def _frames(path, side=None, closed=False):
    """Parallel-transported frames (point, u, w) along a path (no twist)."""
    pts = [Vector(p) for p in path]
    n = len(pts)
    out = []
    u = None
    for i, p in enumerate(pts):
        if closed:
            d = pts[(i + 1) % n] - pts[i - 1]
        else:
            d = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        d.normalize()
        if u is None:
            ref = Vector(side) if side is not None else (Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0)))
            u = (ref - d * ref.dot(d)).normalized()
        else:
            u = (u - d * u.dot(d)).normalized()
        out.append((p, u.copy(), d.cross(u)))
    return out


def sweep(path, section, side=None, scales=None, cap=True, closed=False):
    """Sweeps a 2-D section [(u, v), ...] (u along `side`, v along tangent x side) along a path,
    parallel-transported (no twist). scales: per-point multiplier (or (su, sv) tuples) for
    tapering. Closed solid when cap=True (or closed=True: a ring)."""
    rings = []
    for i, (p, u, w) in enumerate(_frames(path, side, closed)):
        s = scales[i] if scales is not None else 1.0
        su, sv = (s, s) if isinstance(s, (int, float)) else s
        rings.append([tuple(p + u * (a * su) + w * (b * sv)) for a, b in section])
    return loft(rings, closed_profile=closed, cap_start=cap and not closed, cap_end=cap and not closed)


def circle2(r, n=12, start=0.0):
    return [(r * math.cos(start + 2 * math.pi * k / n), r * math.sin(start + 2 * math.pi * k / n)) for k in range(n)]


def rrect2(w, h, r, n=3):
    """A rounded rectangle outline (w x h, corner radius r, n points per corner), centred."""
    out = []
    for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180),
                       (w / 2 - r, -h / 2 + r, 270)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


def torus(R_, r, segs=32, sides=6, y=0.0):
    """A ring round Y (major radius R_, wire radius r) at height y."""
    path = [(R_ * math.cos(2 * math.pi * k / segs), y, R_ * math.sin(2 * math.pi * k / segs)) for k in range(segs)]
    return sweep(path, circle2(r, sides), side=(0, 1, 0), closed=True)


def hollow_tube(path, ro, ri, segs=16, side=None):
    """A pipe with a real wall: the outer skin along the path, the inner skin back along it,
    each open end walled by an annulus. Closed (a torus-like solid)."""
    fr = _frames(path, side)
    sec_o, sec_i = circle2(ro, segs), circle2(ri, segs)
    rings = [[tuple(p + u * a + w * b) for a, b in sec_o] for p, u, w in fr]
    rings += [[tuple(p + u * a + w * b) for a, b in sec_i] for p, u, w in reversed(fr)]
    return loft(rings, closed_profile=True)


def _transform(bm, mat):
    bmesh.ops.transform(bm, matrix=mat, verts=bm.verts)
    return bm


def _wrap(a):
    return math.atan2(math.sin(a), math.cos(a))


def _nut(r=0.04, h=0.03):
    """A hex nut / bolt head (axis Y, sitting on y = 0)."""
    return _transform(cyl(r, h, segs=6), T(0, h / 2))


def _dome(r=0.03, h=0.018, segs=6):
    """A round-headed screw / rivet head (axis Y, base on y = 0)."""
    return lathe([(0, h), (r * 0.6, h * 0.86), (r * 0.92, h * 0.45), (r, 0.0), (r * 0.7, -0.01), (0, -0.01)], segs=segs)


OUT = R(-90)  # turns a +Y axis into -Z (out of the wall): for lathes made round Y


# ==============================================================================================
# Downpipe kit (cast-iron style, round). Real reference: 3 in (75-76 mm) cast-iron rainwater
# pipe in 1.83 m lengths, each length with a SOCKET at its top (a short wider collar with a
# bead) carrying two cast EARS (lugs) nailed to the wall over spacer bobbins; the spigot (plain
# end) of the length above drops into it. A swan neck (offset) brings the pipe out to the
# gutter, a shoe at the foot kicks the water away from the wall. Old black paint, rust bloom
# at the joints, a wet dark streak under a leaking socket.
# The props scale (props_walls.downpipe): pipe diameter 0.36, axis 0.38 out of the wall.
# The pieces tile: each one's origin is on the wall face at the JOINT LINE at its bottom (the
# top of the socket below it); its spigot runs 0.32 down into that socket (the pipe's skin
# crosses the socket's top ring mid-face: the socket's bore is narrower than the pipe, never
# coplanar). DownpipeStraight is 6.0 tall (next origin at y + 6), DownpipeStraightShort 1.5,
# DownpipeShoe has its socket top at 1.2 (the first straight's origin), DownpipeOffset is 2.4
# tall with its top socket 0.6 further out (it takes the gutter outlet).
# ==============================================================================================
PR = 0.18  # pipe radius
ZC = -0.38  # pipe axis, out of the wall
SOCK_H = 0.38  # socket height
SPIGOT = 0.32  # how far a spigot goes down into the socket below


def _socket_profile(top, flare=0.0):
    """The socket ring's closed section (r, y) under y = top: its bore narrower than the pipe
    (the spigot crosses the top ring), a chamfer down to the pipe, a bead round the top."""
    f = flare
    return [
        (PR - 0.012, top - SOCK_H - 0.06),
        (PR + 0.006, top - SOCK_H - 0.04),
        (PR + 0.038 + f, top - SOCK_H + 0.03),
        (PR + 0.042 + f, top - 0.075),
        (PR + 0.054 + f, top - 0.06),
        (PR + 0.058 + f, top - 0.03),
        (PR + 0.05 + f, top - 0.004),
        (PR + 0.036 + f, top),
        (PR - 0.012, top),
    ]


def _socket(ctx, layer, top, ears=True, rng=None):
    """A socket at y = top on the pipe axis (+ its two cast ears, spacers and pipe nails)."""
    ctx.add(layer, lathe(_socket_profile(top), segs=20), T(0, 0, ZC))
    if not ears:
        return
    for s in (-1, 1):
        # the ear: a cast lug off the socket's back, out to the side, standing 0.05 off the
        # wall on a spacer bobbin (sunk 0.015 into the wall), a pipe nail through its boss
        ctx.add(layer, rbox(0.34, 0.22, 0.07, r=0.03, m=1), T(s * 0.25, top - 0.2, -0.085))
        ctx.add(layer, rbox(0.2, 0.15, 0.13, r=0.03, m=1), T(s * 0.13, top - 0.2, -0.155))
        ctx.add(layer, _transform(cyl(0.05, 0.1, segs=10), R(90)), T(s * 0.3, top - 0.2, -0.09))
        ctx.add("Metal", _transform(cyl(0.04, 0.08, segs=8), R(90)), T(s * 0.3, top - 0.2, -0.025))
        ctx.add("Metal", _transform(_dome(0.032, 0.02), OUT), T(s * 0.3, top - 0.2, -0.138))


def _pipe(ctx, layer, y0, y1, step=0.8):
    rings = max(2, int((y1 - y0) / step))
    prof = [(0.0, y0)] + [(PR, lerp(y0, y1, k / rings)) for k in range(rings + 1)] + [(0.0, y1)]
    ctx.add(layer, lathe(prof, segs=20), T(0, 0, ZC))


def _pipe_wear(ctx, noise, leak_a=None, joints=()):
    """Old black paint: dust lighter on the up-facing bead, grime and wet dark under the joints
    (one leaking: a long dark run down one side), rust-brown blush at the sockets."""

    def fn(p):
        x, y, z = p.co
        a = math.atan2(z - ZC, x)
        k = 0.92 + 0.08 * noise.fbm((x * 3, y * 0.5, z * 3), 2)
        for j in joints:
            below = j - y
            if 0 < below < 2.5:
                k *= 1 - 0.18 * math.exp(-below / 0.8)
            if -SOCK_H - 0.08 < y - j < 0.02:
                k_r = 0.82 + 0.1 * noise.fbm((x * 9, y * 9, z * 9), 2)
                return (k * k_r * 1.15, k * k_r * 0.9, k * k_r * 0.75)  # rust bloom
            if leak_a is not None and 0 < below < 4.5:
                da = _wrap(a - leak_a)
                k *= 1 - 0.35 * math.exp(-(da / 0.5) ** 2) * (1 - below / 4.5)
        if p.normal.y > 0.6:
            k *= 1.08
        return k

    ctx.wear("MetalPainted", fn)
    ctx.wear("Metal", lambda p: (0.85, 0.72, 0.6) if p.co.z > -0.25 else 0.8)


def _downpipe_setup(ctx):
    ctx.tint("MetalPainted", (46, 48, 47))  # old black-green paint on cast iron
    ctx.smooth_angle = 40


def downpipe_straight(ctx, length=6.0):
    """One 6-stud length of round cast-iron downpipe: its spigot drops 0.32 into the socket
    below the origin, its own socket (bead, two cast ears nailed to the wall over spacers) at
    the top. Origin: wall face, the joint line at its foot; tile every 6 studs up the wall."""
    _downpipe_setup(ctx)
    ctx.budget = 1600
    noise = ctx.noise
    _pipe(ctx, "MetalPainted", -SPIGOT, length - 0.16)
    _socket(ctx, "MetalPainted", length)
    leak = ctx.rng.uniform(-2.5, -0.6)  # the side facing out of the wall (-Z) and a bit sideways
    _pipe_wear(ctx, noise, leak_a=leak, joints=(length, 0.0))


def downpipe_straight_short(ctx):
    """A 1.5-stud length of the same pipe (to make up a run's height: 6 + 6 + 1.5...)."""
    downpipe_straight(ctx, length=1.5)
    ctx.budget = 1200


def downpipe_offset(ctx):
    """The swan neck: a spigot into the socket below the origin, two long-radius bends that
    carry the pipe 0.6 further out from the wall, and a socket at the top (y 2.4) that takes the
    gutter outlet. Origin: wall face, the joint line at its foot."""
    _downpipe_setup(ctx)
    ctx.budget = 1800
    off = 0.6
    top = 2.4
    path = fillet_path([(0, -SPIGOT, ZC), (0, 0.55, ZC), (0, 1.45, ZC - off), (0, top - 0.16, ZC - off)], 0.55, 10)
    ctx.add("MetalPainted", tube(path, PR, segs=20))
    # the top socket (its bore open: the pipe's end, 0.16 down in it, is its floor)
    ctx.add("MetalPainted", lathe(_socket_profile(top), segs=20), T(0, 0, ZC - off))
    _pipe_wear(ctx, ctx.noise, joints=(top, 0.0))


def downpipe_shoe(ctx):
    """The shoe at the foot of the run: a socket (with ears) whose top is 1.2 above the floor,
    a short drop, a bend kicking the open spout out from the wall, hollow, its lip 0.3 above
    the ground. Origin: wall face, on the floor (the first straight goes at y 1.2)."""
    _downpipe_setup(ctx)
    ctx.budget = 2000
    top = 1.2
    path = fillet_path([(0, top - 0.16, ZC), (0, 0.6, ZC), (0, 0.22, ZC - 0.42)], 0.32, 8)
    # the open spout: a real wall (0.025), its mouth bevelled square to the flow
    ctx.add("MetalPainted", hollow_tube(path, PR, PR - 0.028, segs=20))
    _socket(ctx, "MetalPainted", top)
    ctx.mark("Fx", (0, 0.18, ZC - 0.46))  # (the spout's mouth: where the rain pours out, CityGutter)
    noise = ctx.noise
    _pipe_wear(ctx, noise, joints=(top,))  # (the shared rust at the socket, then the spout's own)
    inner_fn = ctx.wears["MetalPainted"]

    def fn(p):
        x, y, z = p.co
        k = inner_fn(p)
        if isinstance(k, tuple):
            return k
        # the mouth: dark wet inside, green slime round the lip, splashed mud low down
        d = math.hypot(x, z - ZC)
        if y < 0.5 and z < ZC - 0.1 and d < PR + 0.4:
            k *= 0.72
        k *= 1 - 0.3 * (1 - smoothstep(0.0, 0.5, y))
        return (k * 0.9, k, k * 0.86) if y < 0.4 else k

    ctx.wear("MetalPainted", fn)


def downpipe_bracket(ctx):
    """A two-piece pipe clip (holderbat) round the pipe: a flat iron band round it (its bore
    narrower than the pipe: the pipe skin crosses it), the two lugs bolted together at the
    front, and the flat stem back into the wall, built into a mortar joint. Origin: wall face,
    the clip's centre height. Goes on any pipe length, anywhere."""
    ctx.budget = 1000
    ctx.smooth_angle = 40
    ctx.tint("MetalPainted", (46, 48, 47))
    band = [(PR - 0.008, -0.07), (PR + 0.022, -0.07), (PR + 0.03, -0.06), (PR + 0.03, 0.06), (PR + 0.022, 0.07),
            (PR - 0.008, 0.07)]
    ctx.add("MetalPainted", lathe(band, segs=24), T(0, 0, ZC))
    # the two lugs at the front, bolted
    for s in (-1, 1):
        ctx.add("MetalPainted", rbox(0.03, 0.13, 0.15, r=0.01, m=1), T(s * 0.03, 0, ZC - PR - 0.08))
    bolt = _transform(cyl(0.022, 0.16, segs=8), R(0, 0, 90))
    ctx.add("Metal", bolt, T(0, 0, ZC - PR - 0.1))
    for s in (-1, 1):
        ctx.add("Metal", _transform(_nut(0.035, 0.025), R(0, 0, -90 * s)), T(s * 0.045, 0, ZC - PR - 0.1))
    # the stem: a flat bar from the band's back into the wall (0.06 into it)
    ctx.add("MetalPainted", rbox(0.05, 0.11, 0.24, r=0.012, m=1), T(0, 0, (ZC + PR + 0.06) / 2 + 0.01))
    # a dab of mortar round the stem where it was built into the joint (irregular, flat)
    noise = ctx.noise
    dab = rbox(0.17, 0.12, 0.05, r=0.02, m=2)
    for v in dab.verts:
        v.co += Vector((0.02 * noise.n(v.co * 9), 0.02 * noise.n(v.co * 9 + Vector((3, 1, 2))), 0))
    ctx.add("Concrete", dab, T(0, -0.01, 0.0))
    ctx.wear("MetalPainted", lambda p: (0.95 * (0.9 + 0.1 * noise.n(p.co * 12)), 0.8, 0.7) if p.normal.y < -0.3
             else 0.9 + 0.1 * noise.n(p.co * 12))
    ctx.wear("Metal", lambda p: (0.85, 0.7, 0.58))
    ctx.wear("Concrete", lambda p: 0.75 + 0.15 * noise.fbm(p.co * 8, 2))


# ==============================================================================================
# GooseneckLamp. A barn / warehouse gooseneck light (real_specs "GOOSENECK LAMP"): a spun steel
# dish shade (RLM kind) 1.54 across, porcelain-enamelled (dark green outside, white inside),
# a rolled bead round its rim, a crown rising to the fitter neck; one smooth bent pipe arm
# (0.11 thick) leaving the round wall plate, rising, arching over and dropping into the neck;
# a thin scroll brace under it; a frosted bulb in the black lampholder. Origin: the wall
# plate's centre on the wall face (props_walls.gooseneck_lamp's origin); the shade hangs 2.4
# out, its rim at y 0. Light marker at (0, 0.05, -2.4), in the bulb. GooseneckLampDead: the
# bulb dead.
# ==============================================================================================
SH_Z = -2.4


def _offset2(pts, d):
    """Offsets a 2-D polyline [(r, y)] by d along its left normal (-dy, dr)."""
    out = []
    n = len(pts)
    for i in range(n):
        a = Vector(pts[max(i - 1, 0)])
        b = Vector(pts[min(i + 1, n - 1)])
        t = (b - a).normalized()
        nrm = Vector((-t.y, t.x))
        out.append(tuple(Vector(pts[i]) + nrm * d))
    return out


def _gooseneck(ctx, dead):
    ctx.budget = 4900
    ctx.smooth_angle = 50
    ctx.tint("MetalPainted", (38, 56, 46))  # bottle-green enamel gone dull (outside of the shade)
    noise, rng = ctx.noise, ctx.rng
    # ---- the shade: outer skin from the rim bead up to the neck (radius, height above rim)
    # (a dome near the neck flaring out into a shallow skirt: the RLM barn shade)
    outer = [(0.74, 0.05), (0.68, 0.068), (0.6, 0.104), (0.52, 0.158), (0.45, 0.228), (0.39, 0.3), (0.33, 0.37),
             (0.26, 0.43), (0.19, 0.47), (0.13, 0.49), (0.105, 0.5)]
    inner = list(reversed(_offset2(outer, 0.03)))  # the skin's inside, 0.03 under it (r small -> big)
    prof = ([(0.715, -0.004), (0.74, -0.012), (0.762, 0.0), (0.77, 0.022), (0.758, 0.042)] + outer
            + [(0.1, 0.52), (0.1, 0.64), (0.112, 0.65), (0.112, 0.72), (0.098, 0.735), (0.062, 0.735), (0.062, 0.48)]
            + inner[1:] + [(0.7, 0.012)])
    # (a slight out-of-round and a dent in the rim: spun shades get knocked)
    dent_a = rng.uniform(0, 2 * math.pi)

    def shade_fn(a, r, y):
        k = 1 + 0.006 * math.cos(2 * a + 0.7)
        dy = 0.0
        if r > 0.6:
            g = math.exp(-(_wrap(a - dent_a) / 0.25) ** 2)
            dy = 0.02 * g
            k -= 0.012 * g
        return (r * k, y + dy)

    ctx.add("MetalPainted", lathe(prof, segs=28, radius_fn=shade_fn), T(0, 0, SH_Z))
    # ---- white enamel inside: its face 0.012 proud of the steel's inside, its back in the steel
    ins = [p for p in inner if p[0] > 0.12 and p[0] < 0.69]
    front = _offset2(list(reversed(ins)), 0.012)  # (into the cavity: down and in)
    back = _offset2(list(reversed(ins)), -0.012)
    enamel = list(reversed(front)) + back
    ctx.add("Reflective", lathe(enamel, segs=28, radius_fn=shade_fn), T(0, 0, SH_Z))
    # ---- the lampholder (black bakelite) hanging in the neck
    sock = [(0, 0.51), (0.07, 0.51), (0.076, 0.44), (0.076, 0.35), (0.088, 0.34), (0.088, 0.28), (0.07, 0.245),
            (0.04, 0.24), (0, 0.24)]
    ctx.add("Black", lathe(sock, segs=14), T(0, 0, SH_Z))
    # the bulb (an A19 pear, frosted): its neck in the lampholder
    bulb = [(0, -0.06), (0.06, -0.045), (0.1, -0.01), (0.12, 0.04), (0.115, 0.09), (0.09, 0.14), (0.066, 0.18),
            (0.06, 0.26), (0, 0.26)]
    ctx.add("Glass" if dead else "Glow", lathe(bulb, segs=14), T(0, 0, SH_Z))
    ctx.mark("Light", (0, 0.05, SH_Z))
    # ---- the arm: one bent pipe from the wall plate's boss, up, over, down into the neck
    arm = fillet_path([(0, 0, -0.1), (0, 0, -0.42), (0, 1.02, -1.22), (0, 1.02, SH_Z), (0, 0.66, SH_Z)], 0.48, 8)
    ctx.add("MetalPainted", tube(arm, 0.055, segs=10))
    # a knuckle where the arm leaves the plate, a collar where it enters the neck
    ctx.add("MetalPainted", lathe([(0.0, 0.12), (0.075, 0.12), (0.085, 0.14), (0.085, 0.24), (0.07, 0.26), (0, 0.26)],
                                  segs=14), OUT)
    # the scroll brace under the arm
    brace = spline([(0, -0.24, -0.06), (0, -0.25, -0.3), (0, -0.05, -0.62), (0, 0.33, -0.8)], 5)
    ctx.add("MetalPainted", tube(brace, 0.026, segs=6))
    ctx.add("MetalPainted", _transform(_nut(0.04, 0.05), OUT), T(0, -0.24, -0.04))
    # ---- the round wall plate (back 0.015 into the wall), four screws
    plate = [(0, -0.015), (0.34, -0.015), (0.34, 0.022), (0.326, 0.042), (0.25, 0.058), (0.16, 0.08), (0.11, 0.1),
             (0.098, 0.13), (0, 0.135)]
    ctx.add("MetalPainted", lathe(plate, segs=24), OUT)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        ctx.add("Metal", _transform(_dome(0.03, 0.02), OUT), T(0.255 * math.cos(a), 0.255 * math.sin(a), -0.05))

    # ---- wear
    def paint(p):
        x, y, z = p.co
        k = 0.9 + 0.1 * noise.fbm(p.co * 5, 2)
        d = math.hypot(x, z - SH_Z)
        if z < -1.5 and y < 0.07 and d > 0.69:
            # the rim: enamel chipped to black iron, rust weeping from the chips
            chip = smoothstep(0.1, 0.45, noise.fbm(p.co * 14, 2))
            return (k * (1 - 0.5 * chip), k * (1 - 0.62 * chip), k * (1 - 0.7 * chip))
        if p.normal.y > 0.5:
            k *= 0.82  # dust and soot settled on top
        if z < -1.5 and y < 0.45 and d < 0.11:
            k *= 0.7
        return mul(cavity(0.3))(p)[0] * k

    def enamel_fn(p):
        x, y, z = p.co
        d = math.hypot(x, z - SH_Z)
        k = 0.92
        # heat soot round the socket, yellowed, a ring of crud; chips near the rim
        k_heat = smoothstep(0.45, 0.15, d)
        chip = smoothstep(0.35, 0.6, noise.fbm(p.co * 16, 2)) * smoothstep(0.5, 0.68, d)
        k *= 1 - 0.55 * chip
        return (k * (1 - 0.2 * k_heat), k * (1 - 0.3 * k_heat), k * (1 - 0.5 * k_heat))

    ctx.wear("MetalPainted", paint)
    ctx.wear("Reflective", enamel_fn)
    ctx.wear("Black", lambda p: 0.8)
    ctx.wear("Metal", lambda p: (0.8, 0.66, 0.52))
    ctx.wear("Glass" if dead else "Glow", lambda p: 0.75 if dead else 1.0)


def gooseneck_lamp(ctx):
    """Gooseneck barn light: enamelled dish shade on a smooth bent arm, round wall plate, lit bulb."""
    _gooseneck(ctx, dead=False)


def gooseneck_lamp_dead(ctx):
    """The same gooseneck light with a dead (unlit, dusty) bulb."""
    _gooseneck(ctx, dead=True)


# ==============================================================================================
# BulkheadLight. The oval cast-aluminium bulkhead (real_specs "BULKHEAD LIGHT"): an oval base
# 1.0 x 0.62 (real 25-30 x 15-18 cm, a little large like every prop), a domed frosted lens
# with faint prismatic flutes, a cast bezel ring clamping it, two cast bars across the lens
# (the "bar grille"), fixing lugs at both ends; a conduit gland on top and the galvanised
# conduit running up the wall (saddle clips) to a junction box. Origin: wall face, the lens's
# centre (props_walls.bulkhead_light / alleys.wall_light). Light marker in the lens.
# BulkheadLightDead: the same with a dull glass lens (no glow) full of dead insects.
# ==============================================================================================
BH_A, BH_B, BH_P = 0.5, 0.31, 2.6  # oval semi-axes and superellipse exponent
# the lens: (scale of the oval, depth out of the wall)
BH_LENS = [(0.9, -0.1), (0.9, -0.13), (0.86, -0.19), (0.77, -0.245), (0.62, -0.285), (0.42, -0.31), (0.0, -0.322)]


def _oval(s, a, ax=BH_A, by=BH_B, p=BH_P):
    c, si = math.cos(a), math.sin(a)
    return (ax * s * math.copysign(abs(c) ** (2 / p), c), by * s * math.copysign(abs(si) ** (2 / p), si))


def _oval_rings(prof, n=40, mod=None):
    """Loft rings of the oval: prof [(scale, z)], scale 0 = a pole."""
    angs = [2 * math.pi * k / n for k in range(n)]
    rings = []
    for s, z in prof:
        if s < 1e-6:
            rings.append([(0.0, 0.0, z)])
            continue
        ring = []
        for a in angs:
            ss = s * (mod(a, s) if mod else 1.0)
            x, y = _oval(ss, a)
            ring.append((x, y, z))
        rings.append(ring)
    return rings


def _lens_z(x, y):
    s = ((abs(x) / BH_A) ** BH_P + (abs(y) / BH_B) ** BH_P) ** (1 / BH_P)
    tab = sorted(BH_LENS[1:])
    if s <= tab[0][0]:
        return tab[0][1]
    for (s0, z0), (s1, z1) in zip(tab, tab[1:]):
        if s <= s1:
            return lerp(z0, z1, (s - s0) / (s1 - s0))
    return tab[-1][1]


def _bulkhead(ctx, dead):
    ctx.budget = 3200
    ctx.smooth_angle = 45
    ctx.tint("MetalPainted", (56, 58, 56))  # dark grey cast paint
    noise = ctx.noise
    # ---- base: a cast oval tray, its back 0.015 into the wall
    base = [(1.0, 0.015), (1.0, -0.075), (0.985, -0.098), (0.95, -0.11), (0.9, -0.114), (0.0, -0.114)]
    ctx.add("MetalPainted", loft(_oval_rings([(0.0, 0.015)] + base, 40)))
    # ---- lens (fluted, frosted)
    flutes = lambda a, s: 1 + (0.012 * math.cos(22 * a) if 0.5 < s < 0.95 else 0.0)  # noqa: E731
    ctx.add("Glass" if dead else "Glow", loft(_oval_rings([(0.0, -0.1)] + BH_LENS, 44, flutes)))
    # ---- bezel ring clamping the lens edge (in front of the lens skin all round its lip)
    bez = [(0.84, -0.212), (0.88, -0.222), (0.95, -0.205), (1.01, -0.165), (1.02, -0.112), (1.0, -0.09),
           (0.86, -0.09), (0.83, -0.16)]
    ctx.add("MetalPainted", loft(_oval_rings(bez, 40), closed_profile=True))
    # ---- two cast bars over the lens, following its dome 0.035 in front of it
    for yb in (-0.1, 0.1):
        xs = [lerp(-0.47, 0.47, k / 12) for k in range(13)]
        path = [(x, yb, min(_lens_z(x, yb), -0.2) - 0.034) for x in xs]
        ctx.add("MetalPainted", sweep(path, rrect2(0.05, 0.034, 0.014, 2), side=(0, 1, 0)))
    # ---- fixing lugs at both ends, a screw in each
    for s in (-1, 1):
        ctx.add("MetalPainted", rbox(0.2, 0.17, 0.05, r=0.02, m=1), T(s * 0.53, 0, -0.012))
        ctx.add("Metal", _transform(_dome(0.032, 0.02), OUT), T(s * 0.57, 0, -0.035))
    # ---- conduit gland on top, conduit up the wall, saddle clips, junction box
    ctx.add("Metal", _transform(cyl(0.075, 0.08, segs=6), T(0, 0.04)), T(0, 0.27, -0.07))
    ctx.add("Metal", tube([(0, 0.3, -0.07), (0, 2.45, -0.07)], 0.055, segs=10))
    for yc in (0.95, 1.85):
        ctx.add("Metal", sweep([(-0.15, yc, 0.01), (-0.075, yc, 0.01), (-0.07, yc, -0.07), (0, yc, -0.135),
                                (0.07, yc, -0.07), (0.075, yc, 0.01), (0.15, yc, 0.01)],
                               rrect2(0.012, 0.07, 0.004, 1), side=(0, 0, 1)))
    ctx.add("MetalPainted", rbox(0.5, 0.5, 0.26, r=0.04, m=1), T(0, 2.66, -0.115))
    ctx.add("MetalPainted", rbox(0.44, 0.44, 0.04, r=0.015, m=1), T(0, 2.66, -0.255))  # its lid, proud
    for sx in (-1, 1):
        for sy in (-1, 1):
            ctx.add("Metal", _transform(_dome(0.022, 0.014), OUT), T(sx * 0.17, 2.66 + sy * 0.17, -0.27))
    ctx.mark("Light", (0, 0, -0.2))

    def paint(p):
        x, y, z = p.co
        k = 0.88 + 0.12 * noise.fbm(p.co * 6, 2)
        if p.normal.y > 0.5:
            k *= 0.8
        # rust weeping from the screws and down from the box
        for sx, sy in ((-0.57, 0.0), (0.57, 0.0)):
            if abs(x - sx) < 0.05 and sy - 0.5 < y < sy:
                return (k * 0.95, k * 0.72, k * 0.55)
        return k * (1 - 0.3 * smoothstep(0.0, 0.5, -p.convex))

    def lens(p):
        x, y, z = p.co
        # dead insects and dust pooled in the bottom of the lens, soot on top
        k = 1.0 - 0.35 * smoothstep(-0.05, -0.25, y) * smoothstep(0.2, 0.6, noise.fbm(p.co * 10, 2) * 0.5 + 0.5)
        k *= 1 - 0.18 * smoothstep(0.12, 0.3, y)
        if dead:
            k *= 0.75
        return k

    ctx.wear("MetalPainted", paint)
    ctx.wear("Glass" if dead else "Glow", lens)
    ctx.wear("Metal", lambda p: 0.8 + 0.15 * noise.fbm(p.co * 4, 2))


def bulkhead_light(ctx):
    """Oval cast bulkhead light: frosted lens (lit), bezel and two bars, conduit to a box."""
    _bulkhead(ctx, dead=False)


def bulkhead_light_dead(ctx):
    """The same bulkhead dead: a dull glass lens with dead insects pooled in it."""
    _bulkhead(ctx, dead=True)


# ==============================================================================================
# AcUnit. The wall-hung outdoor unit of a 9-12k BTU split air-con (real_specs "AC CONDENSER"):
# 2.55 wide, 1.8 tall, 0.96 deep (real 75 x 54 x 28 cm, the props' ~15 % large), standing
# 0.22 off the wall on two angle-iron L-brackets with diagonal braces and rubber feet.
#   * the casing: a pressed-steel U (top, right side, bottom, rounded corners) under an
#     overhanging lid; the FRONT panel is one pressed sheet with the round fan opening on the
#     left two-thirds (a raised pressed ring round it, the edge rolled into a short shroud)
#     and six stamped louvres on the right;
#   * the round fan guard: concentric wire rings over eight radial spokes, a maker's badge in
#     the middle; behind it the three swept, pitched blades on their hub, the motor on its strap;
#   * the condenser coil (aluminium fins) wrapping the left side and the back, behind a wire
#     guard;
#   * the right side: the service valve cover, two valves with flare nuts, the insulated
#     copper lines bending back into the wall, the power cable; a condensate hose dribbling
#     from the bottom.
# Origin: wall face, the casing's bottom centre (props_walls.ac_unit's frame: f.sub((x, y, 0))).
# props_walls.ac_unit with scale 1 (its W 2.58, H 1.89, front 1.37 out) fits within 0.2.
# ==============================================================================================
AC_W, AC_H = 2.55, 1.8
AC_Z0, AC_Z1 = -0.22, -1.18  # back / front plane of the casing (out of the wall = more negative)
FAN_X, FAN_Y, FAN_R = -0.4, 0.9, 0.68


def _rrect_ray(cx, cy, dx, dy, x0, x1, y0, y1, rc):
    """Where the ray from (cx, cy) along (dx, dy) leaves the rounded rectangle."""
    ts = []
    if dx > 1e-9:
        ts.append((x1 - cx) / dx)
    if dx < -1e-9:
        ts.append((x0 - cx) / dx)
    if dy > 1e-9:
        ts.append((y1 - cy) / dy)
    if dy < -1e-9:
        ts.append((y0 - cy) / dy)
    t = min(ts)
    px, py = cx + dx * t, cy + dy * t
    ccx = x1 - rc if px > x1 - rc else (x0 + rc if px < x0 + rc else None)
    ccy = y1 - rc if py > y1 - rc else (y0 + rc if py < y0 + rc else None)
    if ccx is not None and ccy is not None:
        ox, oy = cx - ccx, cy - ccy
        b = ox * dx + oy * dy
        c = ox * ox + oy * oy - rc * rc
        t = -b + math.sqrt(max(0.0, b * b - c))
        px, py = cx + dx * t, cy + dy * t
    return px, py


def _ac_front():
    """The front panel: one closed sheet from its rounded-rectangle edge, across the face, up
    over the pressed ring round the fan opening, rolled into the shroud and back."""
    x0, x1, y0, y1, rc = -AC_W / 2, AC_W / 2, 0.0, AC_H - 0.01, 0.06
    angs = [2 * math.pi * k / 48 for k in range(48)]
    for cx, cy in ((x1 - rc, y1 - rc), (x0 + rc, y1 - rc), (x0 + rc, y0 + rc), (x1 - rc, y0 + rc)):
        angs.append(math.atan2(cy - FAN_Y, cx - FAN_X) % (2 * math.pi))
    angs = sorted(angs)

    def rect(inset, z):
        out = []
        for a in angs:
            px, py = _rrect_ray(FAN_X, FAN_Y, math.cos(a), math.sin(a), x0 + inset, x1 - inset, y0 + inset,
                                y1 - inset, rc - inset)
            out.append((px, py, z))
        return out

    def circ(r, z):
        return [(FAN_X + r * math.cos(a), FAN_Y + r * math.sin(a), z) for a in angs]

    def blend(t, z):
        a, b = rect(0.012, z), circ(FAN_R + 0.13, z)
        return [tuple(lerp(p[i], q[i], t) for i in range(3)) for p, q in zip(a, b)]

    Z = AC_Z1
    R_ = FAN_R
    rings = [rect(0, Z + 0.035), rect(0, Z + 0.012), rect(0.012, Z), blend(0.35, Z), blend(0.7, Z),
             circ(R_ + 0.13, Z), circ(R_ + 0.1, Z - 0.03), circ(R_ + 0.05, Z - 0.036), circ(R_ + 0.015, Z - 0.02),
             circ(R_, Z + 0.01), circ(R_ - 0.008, Z + 0.06), circ(R_, Z + 0.3), circ(R_ + 0.03, Z + 0.3),
             circ(R_ + 0.03, Z + 0.05)]
    return loft(rings, closed_profile=True)


def _arc2(cx, cy, r, a0, a1, n=4):
    return [(cx + r * math.cos(math.radians(lerp(a0, a1, k / n))), cy + r * math.sin(math.radians(lerp(a0, a1, k / n))))
            for k in range(n + 1)]


def _ac_casing():
    """The pressed U (top, right side, bottom) the front panel closes; open on the left (the
    coil) and at the back (the coil)."""
    xl, xr, yb, yt, rc, t = -AC_W / 2 + 0.012, AC_W / 2 - 0.012, 0.012, AC_H - 0.005, 0.06, 0.03
    outer = [(xl, yt)] + _arc2(xr - rc, yt - rc, rc, 90, 0) + _arc2(xr - rc, yb + rc, rc, 0, -90) + [(xl, yb)]
    ri = rc - t
    inner = [(xl, yb + t)] + _arc2(xr - rc, yb + rc, ri, -90, 0) + _arc2(xr - rc, yt - rc, ri, 0, 90) + [(xl, yt - t)]
    return prism(outer + inner, AC_Z1 + 0.02, AC_Z0, segs=3)


def _fins(u0, u1, pitch, depth):
    """A zigzag edge from u0 to u1 (the coil's fins seen edge-on), as (u, w) points, w in 0..depth."""
    n = max(2, int(abs(u1 - u0) / pitch))
    return [(lerp(u0, u1, k / n), depth if k % 2 else 0.0) for k in range(n + 1)]


def _blade(phi0, zc):
    """One swept, pitched fan blade (a closed thin solid), its root at the hub."""
    rings = []
    for i in range(7):
        t = i / 6
        r = lerp(0.1, 0.6, t)
        half = lerp(0.3, 0.62, t ** 0.8) * (1 - 0.3 * t ** 4)
        mid = phi0 + 0.42 * t * t
        pitch = math.tan(math.radians(lerp(40, 24, t)))
        top, bot = [], []
        for j in range(6):
            u = -1 + 2 * j / 5
            a = mid + u * half
            z = zc + pitch * r * half * u - 0.025 * (1 - u * u)  # (pitched, and cambered)
            x, y = FAN_X + r * math.cos(a), FAN_Y + r * math.sin(a)
            top.append((x, y, z - 0.011))
            bot.append((x, y, z + 0.011))
        rings.append(top + list(reversed(bot)))
    return loft(rings, cap_start=True, cap_end=True)


def ac_unit(ctx):
    """Split air-con outdoor unit on L-brackets: round fan guard, louvres, coil, pipes."""
    ctx.budget = 8000
    ctx.smooth_angle = 38
    ctx.tint("MetalPainted", (198, 190, 168))  # powder-coated steel, yellowed by the sun
    noise, rng = ctx.noise, ctx.rng
    Z = AC_Z1
    P = "MetalPainted"
    # Modelled with the fan at -X, then mirrored: seen from the street (looking at the wall,
    # +X on the viewer's LEFT) the fan is on the left and the valves on the right, as on real
    # units. (finish_bmesh re-orients the mirrored solids' faces.)
    mirror = S(-1, 1, 1)
    add0 = ctx.add

    def add(layer, bm, matrix=None):
        add0(layer, bm, mirror @ matrix if matrix is not None else mirror)

    ctx.add = add
    ctx.add(P, _ac_front())
    ctx.add(P, _ac_casing())
    # the lid: overhangs the front and sides, a drip edge turned down at the front
    ctx.add(P, rbox(AC_W + 0.05, 0.06, AC_Z0 - Z + 0.05, r=0.02, m=1, n=(6, 1, 3)),
            T(0, AC_H + 0.01, (Z - 0.03 + AC_Z0 + 0.02) / 2))
    ctx.add(P, rbox(AC_W + 0.05, 0.07, 0.025, r=0.01, m=1, n=(6, 1, 1)), T(0, AC_H - 0.03, Z - 0.042))
    # stamped louvres on the right of the front (a sloped hood over a dark slot each)
    for k in range(6):
        yk = 0.36 + k * 0.2
        prof = [(yk, Z + 0.006), (yk, Z - 0.036), (yk + 0.014, Z - 0.042), (yk + 0.12, Z - 0.004),
                (yk + 0.12, Z + 0.006)]
        lv = loft([[(x, y, z) for y, z in prof] for x in (0.5, 1.12)], cap_start=True, cap_end=True)
        ctx.add(P, lv)
    # screws in the corners of the front and on the right side
    screws = [(sx * (AC_W / 2 - 0.07), sy) for sx in (-1, 1) for sy in (0.08, AC_H - 0.1)]
    for sx, sy in screws:
        ctx.add("Metal", _transform(_dome(0.03, 0.016), OUT), T(sx, sy, Z + 0.004))
    # ---- fan guard: rings over spokes, a badge
    for r_ in (0.15, 0.255, 0.36, 0.465, 0.57):
        ctx.add(P, torus(r_, 0.017, segs=28, sides=4), T(FAN_X, FAN_Y, Z - 0.076) @ R(90))
    ctx.add(P, torus(FAN_R + 0.035, 0.02, segs=36, sides=4), T(FAN_X, FAN_Y, Z - 0.062) @ R(90))
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        p0 = (FAN_X + 0.09 * math.cos(a), FAN_Y + 0.09 * math.sin(a), Z - 0.047)
        p1 = (FAN_X + (FAN_R + 0.075) * math.cos(a), FAN_Y + (FAN_R + 0.075) * math.sin(a), Z - 0.047)
        ctx.add(P, tube([p0, p1], 0.014, segs=5))
    badge = [(0, 0.04), (0.1, 0.04), (0.122, 0.025), (0.122, 0.0), (0, 0.0)]
    ctx.add(P, lathe(badge, segs=20), T(FAN_X, FAN_Y, Z - 0.056) @ OUT)
    # ---- the fan behind it: three blades, the hub, the motor on a strap
    zc = Z + 0.2
    phase = rng.uniform(0, 2 * math.pi)
    for k in range(3):
        ctx.add("PlasticDark", _blade(phase + 2 * math.pi * k / 3, zc))
    hub = [(0, 0.11), (0.06, 0.1), (0.1, 0.07), (0.125, 0.02), (0.125, -0.06), (0, -0.06)]
    ctx.add("PlasticDark", lathe(hub, segs=18), T(FAN_X, FAN_Y, zc + 0.03) @ OUT)
    ctx.add("Black", _transform(cyl(0.17, 0.2, segs=18, bevel=0.02), R(90)), T(FAN_X, FAN_Y, Z + 0.4))
    yb, yt = 0.012 + 0.03, AC_H - 0.005 - 0.03
    ctx.add("Metal", rbox(0.07, yt - yb + 0.02, 0.025, r=0.008, m=1), T(FAN_X, (yb + yt) / 2, Z + 0.51))
    # ---- condenser coil: the back and the left side, fins edge-on, a wire guard on the left
    xL = -AC_W / 2 + 0.045
    back = [(u, AC_Z0 - 0.13 + w) for u, w in _fins(xL, AC_W / 2 - 0.045, 0.05, 0.022)]
    back += [(AC_W / 2 - 0.045, AC_Z0 - 0.01), (xL, AC_Z0 - 0.01)]
    ctx.add("Metal", loft([[(x, y, z) for x, z in back] for y in (yb + 0.005, yt - 0.005)], cap_start=True, cap_end=True))
    side = [(xL + w, v) for v, w in _fins(AC_Z0 - 0.1, Z + 0.06, 0.05, 0.022)]
    side += [(xL + 0.13, Z + 0.06), (xL + 0.13, AC_Z0 - 0.1)]
    ctx.add("Metal", loft([[(x, y, z) for x, z in side] for y in (yb + 0.005, yt - 0.005)], cap_start=True, cap_end=True))
    for yy in (0.25, 0.55, 0.85, 1.15, 1.45):
        ctx.add("Black", tube([(xL - 0.022, yy, Z + 0.03), (xL - 0.022, yy, AC_Z0 - 0.012)], 0.012, segs=5))
    for zz in (Z + 0.35, AC_Z0 - 0.3):
        ctx.add("Black", tube([(xL - 0.042, 0.03, zz), (xL - 0.042, AC_H - 0.03, zz)], 0.012, segs=5))
    # ---- right side: valve cover, two service valves, insulated lines into the wall, cable
    xr = AC_W / 2 - 0.012
    ctx.add(P, rbox(0.05, 0.44, 0.46, r=0.015, m=1), T(xr + 0.008, 0.86, -0.5))
    for sy in (0.7, 1.02):
        ctx.add("Metal", _transform(_dome(0.022, 0.014), R(0, 0, -90)), T(xr + 0.032, sy, -0.32))
    lines = ((0.26, 0.058), (0.46, 0.046))
    for yv, ri in lines:
        ctx.add("Metal", _transform(cyl(0.05, 0.17, segs=10), R(0, 0, -90)), T(xr + 0.06, yv, -0.62))
        ctx.add("Metal", _transform(cyl(0.056, 0.07, segs=6), R(0, 0, -90)), T(xr + 0.17, yv, -0.62))
        dx = 0.33 if yv < 0.3 else 0.2
        path = fillet_path([(xr + 0.18, yv, -0.62), (xr + dx, yv, -0.62), (xr + dx, -0.25, -0.62),
                            (xr + dx, -0.25, 0.12)], 0.15, 6)
        ctx.add("Rubber", tube(path, ri, segs=8))
    cable = spline([(xr + 0.03, 0.66, -0.36), (xr + 0.1, 0.5, -0.36), (xr + 0.1, -0.1, -0.36), (xr + 0.1, -0.12, 0.1)], 4)
    ctx.add("Black", tube(cable, 0.022, segs=6))
    # condensate spigot and hose
    ctx.add("PlasticDark", tube([(1.06, 0.04, -0.72), (1.06, -0.06, -0.72)], 0.04, segs=10))
    hose = spline([(1.06, -0.04, -0.72), (1.07, -0.3, -0.68), (1.1, -0.65, -0.45), (1.12, -1.05, -0.22),
                   (1.12, -1.5, -0.14)], 4)
    ctx.add("Black", tube(hose, 0.032, segs=8))
    # ---- L-brackets (angle iron 0.14 x 0.022), rubber feet, braces, bolts
    a, t = 0.14, 0.022
    ya = -0.065
    for bx in (-0.85, 0.85):
        s = 1 if bx > 0 else -1
        xo = bx + s * 0.07
        arm = [(bx - s * 0.07, ya), (xo, ya), (xo, ya - a), (xo - s * t, ya - a), (xo - s * t, ya - t), (bx - s * 0.07, ya - t)]
        ctx.add("Rust", prism(arm, 0.012, Z - 0.12, segs=2))
        leg = [(bx - s * 0.07, 0.012), (xo, 0.012), (xo, 0.012 - a), (xo - s * t, 0.012 - a), (xo - s * t, 0.012 - t),
               (bx - s * 0.07, 0.012 - t)]
        ctx.add("Rust", loft([[(x, y, z) for x, z in leg] for y in (ya - 1.2, ya - 0.006)], cap_start=True, cap_end=True))
        # the brace: a flat bar inside the flanges, from the leg's foot to the arm's end
        xb = xo - s * (t + 0.022)
        p0, p1 = Vector((xb, ya - 1.08, -0.07)), Vector((xb, ya - 0.08, Z + 0.1))
        d = p1 - p0
        ang = math.degrees(math.atan2(d.z, d.y))
        ctx.add("Rust", rbox(0.022, d.length + 0.1, 0.09, r=0.008, m=1), T(*((p0 + p1) / 2)) @ R(ang))
        for p in (p0 + d.normalized() * 0.03, p1 - d.normalized() * 0.03):
            ctx.add("Metal", _transform(_nut(0.035, 0.035), R(0, 0, -90 * s)), T(xo - s * 0.005, p.y, p.z))
        for yy in (ya - 0.3, ya - 1.0):
            ctx.add("Metal", _transform(_nut(0.04, 0.03), OUT), T(bx - s * 0.02, yy, 0.017 - t))
        for zf in (-0.42, -0.98):
            ctx.add("Rubber", rbox(0.16, 0.085, 0.2, r=0.025, m=1), T(bx, ya + 0.0375, zf))

    ctx.add = add0

    # ---- wear (x mirrored back to the modelling side)
    def paint(p):
        x, y, z = p.co
        x = -x
        k = 0.93 + 0.07 * noise.fbm(p.co * 4, 2)
        rr = math.hypot(x - FAN_X, y - FAN_Y)
        if p.normal.y > 0.6 and y > AC_H - 0.05:
            k *= 0.7 + 0.15 * noise.fbm(p.co * 3, 2)  # dust, soot and leaf litter on the lid
        k *= 1 - 0.25 * (1 - smoothstep(0.0, 0.7, y))  # grime splashed up the lower part
        if z < Z + 0.02:
            k *= 1 - 0.22 * math.exp(-((rr - FAN_R - 0.06) / 0.14) ** 2)  # dirt dragged in round the fan
        if z > Z + 0.02 and rr < FAN_R + 0.04:
            k *= 0.55  # inside the shroud
        if z < Z + 0.03 and x < -0.0 and rr < FAN_R + 0.1 and z < Z - 0.03:
            k *= 0.92  # the guard
        # rust weeping down from the front screws and the lid's front corners
        for sx, sy in screws:
            if abs(x - sx) < 0.045 and sy - 0.75 < y < sy:
                f = (y - (sy - 0.75)) / 0.75
                return (k * (1 - 0.1 * f), k * (1 - 0.3 * f), k * (1 - 0.45 * f))
        k *= 1 - 0.3 * smoothstep(0.0, 0.5, -p.convex)
        return k

    def rust(p):
        k = 0.75 + 0.25 * noise.fbm(p.co * 7, 2)
        return k * (1 - 0.25 * smoothstep(-0.2, -1.2, p.co.y))

    ctx.wear(P, paint)
    ctx.wear("Rust", rust)
    ctx.wear("Metal", lambda p: (0.6 + 0.25 * noise.fbm(p.co * 9, 2)) if p.co.z > Z + 0.06 else 0.85)
    ctx.wear("PlasticDark", lambda p: 0.7 + 0.2 * noise.fbm(p.co * 6, 2))
    ctx.wear("Rubber", mul(cavity(0.3), lambda p: 0.85 + 0.15 * noise.fbm(p.co * 5, 2)))
    ctx.wear("Black", lambda p: 0.85)


# ==============================================================================================
# SatelliteDish. An old offset satellite dish on a wall bracket (real_specs "SATELLITE DISH"):
# the reflector is a real OFF-AXIS section of a paraboloid (z = r^2 / 4f, f = 1.15, the
# section centred 1.25 above the axis), an oval 2.24 x 2.04 (real 60-80 cm), pressed steel
# 0.025 thick with its edge rolled back; the LNB sits at the focal point, below and in front of
# the dish, looking back up at it, on a square-tube feed arm that passes under the lower rim;
# a mount bracket and clamp on a vertical mast pipe; the mast on a galvanised stand-off arm
# with a strut, bolted to a wall plate; the coax looping from the LNB down the arm and the
# wall. The dish is turned 28 degrees sideways and its axis raised 24 degrees (a satellite
# low in the sky): the face looks nearly vertical, as offset dishes do.
# Origin: the wall plate's centre on the wall face (props_walls.satellite_dish's origin).
# ==============================================================================================
DF, DCY, DA, DB = 1.15, 1.25, 1.12, 1.02


def _dz(x, y):
    return (x * x + y * y) / (4 * DF)


def _dish_shell(noise, dent):
    """The reflector, in dish space (axis +Z toward the satellite, focus at (0, 0, DF))."""
    n = 44
    angs = [2 * math.pi * k / n for k in range(n)]
    th = 0.025

    def pt(s, a, back=0.0):
        x, y = DA * s * math.cos(a), DCY + DB * s * math.sin(a)
        z = _dz(x, y) - back
        # a dent (a thrown brick, a ladder): pushed in toward the back
        dx, dy = x - dent[0], y - dent[1]
        z -= 0.035 * math.exp(-(dx * dx + dy * dy) / 0.1)
        return (x, y, z)

    rings = [[pt(0, 0)]]
    for s in (0.07, 0.18, 0.32, 0.48, 0.62, 0.74, 0.85, 0.94, 1.0):
        rings.append([pt(s, a) for a in angs])
    # the rolled rim: out and back
    rings.append([pt(1.012, a, 0.01) for a in angs])
    rings.append([pt(1.018, a, 0.03) for a in angs])
    rings.append([pt(1.006, a, 0.048) for a in angs])
    rings.append([pt(0.992, a, 0.04) for a in angs])
    for s in (0.94, 0.8, 0.6, 0.35):
        rings.append([pt(s, a, th) for a in angs])
    rings.append([pt(0, 0, th)])
    return loft(rings)


def satellite_dish(ctx):
    """Offset satellite dish (a real off-axis paraboloid) with LNB arm, mast and wall bracket."""
    ctx.budget = 4600
    ctx.smooth_angle = 40
    ctx.tint("MetalPainted", (188, 186, 178))  # off-white paint gone grey
    noise, rng = ctx.noise, ctx.rng
    yaw, elev = 28.0, 24.0
    rot = R(0, yaw) @ R(elev) @ R(0, 180)
    nb = Vector((0, -DCY / (2 * DF), 1)).normalized()  # the dish's normal at its centre (front side)
    B = Vector((0, DCY, _dz(0, DCY)))
    mount = B - nb * 0.1  # (the clamp, behind the dish centre)
    clamp_w = Vector((0.0, 0.62, -0.98))  # where the clamp sits, out of the wall
    M = T(*clamp_w) @ rot @ T(*(-mount))
    da = rng.uniform(0, 2 * math.pi)
    dent = (0.72 * DA * math.cos(da), DCY + 0.72 * DB * math.sin(da))  # (a knock near the rim)
    ctx.add("MetalPainted", _dish_shell(noise, dent), M)
    # the mount bracket behind the dish: a pressed plate, its four bolts, the clamp block
    plate = rbox(0.5, 0.44, 0.05, r=0.02, m=1)
    q = Vector((0, 0, 1)).rotation_difference(nb).to_matrix().to_4x4()
    ctx.add("Metal", plate, M @ T(*(B - nb * 0.04)) @ q)  # (its face crosses the shell's back)
    for sx in (-0.17, 0.17):
        for sy in (-0.15, 0.15):
            ctx.add("Metal", _transform(_nut(0.03, 0.03), R(-90)), M @ T(*(B - nb * 0.06)) @ q @ T(sx, sy, 0))
    ctx.add("Metal", rbox(0.2, 0.32, 0.16, r=0.03, m=1), M @ T(*(mount)) @ q)
    # ---- the mast, stand-off arm, strut and wall plate (world, galvanised)
    back_w = (rot @ (-nb).to_4d()).to_3d()
    hz = Vector((back_w.x, 0, back_w.z)).normalized()
    mast = clamp_w + hz * 0.15
    ctx.add("Metal", tube(fillet_path([(mast.x * 0.0, 0.0, 0.02), (mast.x, 0.0, mast.z), (mast.x, 0.95, mast.z)], 0.16, 8),
                          0.06, segs=12))
    ctx.add("Metal", lathe([(0, 0.0), (0.07, 0.0), (0.072, 0.03), (0.06, 0.05), (0, 0.05)], segs=12), T(mast.x, 0.95, mast.z))
    for yy in (0.48, 0.76):  # U-bolts round the mast, their nuts on the clamp
        ctx.add("Metal", sweep(_arc3(mast, 0.075, -hz, yy), circle2(0.016, 5)))
    ctx.add("Metal", tube([(0, -0.3, 0.0), (mast.x * 0.62, -0.01, mast.z * 0.62)], 0.032, segs=8))
    ctx.add("Metal", rbox(0.46, 0.7, 0.04, r=0.02, m=1, n=(2, 3, 1)), T(0, -0.05, -0.005))
    for sx in (-0.15, 0.15):
        for sy in (-0.32, 0.22):
            ctx.add("Metal", _transform(_nut(0.042, 0.03), OUT), T(sx, sy, -0.025))
    # ---- feed arm (square tube) from under the bracket, round the lower rim, to the LNB
    F = Vector((0, 0, DF))
    C = Vector((0, DCY, _dz(0, DCY)))
    v = (C - F).normalized()
    lo = DCY - DB
    # (it keeps 0.1+ behind the curved shell all the way down, then turns under the lower rim)
    arm = fillet_path([mount + Vector((0, -0.12, -0.12)), Vector((0, DCY - 0.6, _dz(0, DCY - 0.6) - 0.16)),
                       Vector((0, lo - 0.14, _dz(0, lo) - 0.1)),
                       Vector((0, -0.03, DF * 0.62)), F - v * 0.3], 0.25, 7)
    ctx.add("MetalPainted", sweep(arm, rrect2(0.075, 0.05, 0.012, 2), side=(1, 0, 0)), M)
    # ---- LNB: body, feed horn cap toward the dish, holder ring, F connector
    q2 = Vector((0, 1, 0)).rotation_difference(v).to_matrix().to_4x4()
    lnb = [(0, -0.34), (0.055, -0.34), (0.072, -0.31), (0.072, -0.05), (0.098, -0.035), (0.112, 0.0), (0.112, 0.1),
           (0.095, 0.125), (0, 0.128)]
    ctx.add("PlasticDark", lathe(lnb, segs=16), M @ T(*F) @ q2)
    ring = [(0.066, -0.27), (0.1, -0.27), (0.1, -0.17), (0.066, -0.17)]
    ctx.add("Metal", loft([[(r * math.cos(a), y, r * math.sin(a)) for a in [2 * math.pi * k / 14 for k in range(14)]]
                           for r, y in ring], closed_profile=True), M @ T(*F) @ q2)
    ctx.add("Metal", lathe([(0, -0.4), (0.028, -0.4), (0.028, -0.33), (0, -0.33)], segs=6), M @ T(*F) @ q2)
    # ---- coax: from the LNB along under the arm, round the mast, along the stand-off, down the wall
    def w(p):
        return (M @ Vector(p).to_4d()).to_3d()

    path_d = [F - v * 0.42, F - v * 0.6 + Vector((0.06, -0.08, 0)), Vector((0.07, -0.08, DF * 0.55)),
              Vector((0.07, lo - 0.2, _dz(0, lo) - 0.12)), Vector((0.08, DCY - 0.6, _dz(0, DCY - 0.6) - 0.2)),
              mount + Vector((0.08, -0.2, -0.16))]
    pts = [w(p) for p in path_d] + [Vector((mast.x + 0.07, 0.3, mast.z)), Vector((mast.x + 0.06, 0.07, mast.z * 0.8)),
                                    Vector((0.2, 0.08, -0.12)), Vector((0.26, -0.3, -0.03)), Vector((0.26, -2.3, -0.03)),
                                    Vector((0.27, -2.55, 0.0)), Vector((0.27, -2.62, 0.08))]
    ctx.add("Black", tube(spline(pts, 4), 0.022, segs=6))
    for yy in (-0.9, -1.8):
        ctx.add("Metal", rbox(0.09, 0.05, 0.04, r=0.012, m=1), T(0.26, yy, -0.045))

    # (wear in dish space: how far out from the dish's centre a vertex is, 0..1 at the rim)
    Mi = M.inverted()

    def paint(p):
        q = (Mi @ p.co.to_4d()).to_3d()
        s_ = math.hypot(q.x / DA, (q.y - DCY) / DB)
        k = 0.9 + 0.1 * noise.fbm(q * 3, 2)
        # grime washing down the face from the top rim in soft streaks, heavier low down
        k *= 1 - 0.14 * smoothstep(0.1, 0.6, noise.fbm((q.x * 5, q.y * 0.5, 0.0), 2))
        k *= 1 - 0.12 * smoothstep(0.3, -0.6, (q.y - DCY) / DB)
        # the rolled rim rusts first: brown at the edge, bleeding a little onto the face
        r_ = smoothstep(0.86, 1.0, s_) * smoothstep(-0.1, 0.4, noise.fbm(q * 6, 2))
        if r_ > 0.02:
            return (k * (1 - 0.3 * r_), k * (1 - 0.5 * r_), k * (1 - 0.65 * r_))
        return k * (1 - 0.3 * smoothstep(0.0, 0.5, -p.convex))

    ctx.wear("MetalPainted", paint)
    ctx.wear("Metal", lambda p: (0.82 + 0.15 * noise.fbm(p.co * 5, 2)) * (1 - 0.2 * smoothstep(0.2, 0.6, noise.fbm(p.co * 9, 2))))
    ctx.wear("PlasticDark", lambda p: 0.8)
    ctx.wear("Black", lambda p: 0.85)


def _arc3(centre, r, toward, y):
    """A U-bolt's bend: a half circle of radius r round a vertical pipe at height y, its open
    side toward `toward` (horizontal unit vector), its legs running on 0.12 that way."""
    a0 = math.atan2(toward.z, toward.x)
    pts = [Vector((centre.x, y, centre.z)) + toward * 0.12 + Vector((-toward.z, 0, toward.x)) * r]
    for k in range(11):
        a = a0 + math.pi / 2 + math.pi * k / 10
        pts.append(Vector((centre.x + r * math.cos(a), y, centre.z + r * math.sin(a))))
    pts.append(Vector((centre.x, y, centre.z)) + toward * 0.12 - Vector((-toward.z, 0, toward.x)) * r)
    return pts


# ==============================================================================================
# WaterTank. The New York rooftop wooden water tank (prop_audits "building_top water tank";
# the props draw it r 2.2-2.8, 5-6.5 tall on 4-6 stud legs): 28 vertical cedar staves in a
# slight cone (5.5 across at the foot, 5.24 at the top), 5.3 tall, their tops ragged; seven
# round steel hoops, closer together low down where the pressure is, each with its tightening
# lug (staggered round the tank); a shallow conical roof of tar paper in courses with an eave
# overhang, a hatch and a finial; the tank on timber dunnage over two steel I-beams, on four
# I-section columns 3.6 tall with X-bracing; a steel ladder up the side to the hatch; the
# outlet pipe down through the dunnage with a gate valve, turning into the roof.
# Origin: the centre of the footprint on the roof (floor piece). 11.6 tall; footprint about
# 6.2 x 6.4 with the ladder and outlet. Scale ~0.9-1.0 for props_walls' sizes (the data
# chooses; the far background facades can use Scale 0.8).
# ==============================================================================================
TK_R0, TK_R1, TK_N = 2.75, 2.62, 28
LEGS = 3.6
TK_Y0 = LEGS + 0.36 + 0.3 - 0.02  # tank bottom (sunk 0.02 into the dunnage)
TK_H = 5.3


def _tk_r(y):
    return lerp(TK_R0, TK_R1, (y - TK_Y0) / TK_H)


def _ibeam(w, d, tf=0.035, tw=0.03):
    """An I-section outline (flange width w along u, depth d along v), centred."""
    return [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, -d / 2 + tf), (tw / 2, -d / 2 + tf), (tw / 2, d / 2 - tf),
            (w / 2, d / 2 - tf), (w / 2, d / 2), (-w / 2, d / 2), (-w / 2, d / 2 - tf), (-tw / 2, d / 2 - tf),
            (-tw / 2, -d / 2 + tf), (-w / 2, -d / 2 + tf)]


def water_tank(ctx):
    """Rooftop wooden water tank: staves, steel hoops, conical tar roof, steel stand, ladder."""
    ctx.budget = 8000
    ctx.smooth_angle = 30
    ctx.tint("MetalPainted", (60, 62, 62))
    noise, rng = ctx.noise, ctx.rng
    top = TK_Y0 + TK_H
    # ---- steel stand: four I-columns on base plates, X-braced, two I-beams on top
    k = 1.9
    for sx in (-1, 1):
        for sz in (-1, 1):
            col = [(x + sx * k, z + sz * k) for x, z in _ibeam(0.3, 0.3)]
            ctx.add("MetalPainted", loft([[(x, y, z) for x, z in col] for y in (0.0, LEGS + 0.01)],
                                         cap_start=True, cap_end=True))
            ctx.add("MetalPainted", rbox(0.5, 0.04, 0.5, r=0.01, m=1), T(sx * k, 0.0, sz * k))
            for bx in (-0.17, 0.17):
                ctx.add("Metal", _nut(0.035, 0.03), T(sx * k + bx, 0.02, sz * k + 0.17 * sx))
    for sz in (-1, 1):  # X braces on the two long sides (the planes outside the flanges)
        for i, (ya, yb) in enumerate(((0.35, LEGS - 0.3), (LEGS - 0.3, 0.35))):
            zz = sz * (k + 0.15 + 0.012 + 0.03 * i)
            ctx.add("MetalPainted", sweep([(-k, ya, zz), (k, yb, zz)], rrect2(0.02, 0.14, 0.006, 1), side=(0, 0, 1)))
    for sx in (-1, 1):
        for i, (ya, yb) in enumerate(((0.35, LEGS - 0.3), (LEGS - 0.3, 0.35))):
            xx = sx * (k + 0.15 + 0.012 + 0.03 * i)
            ctx.add("MetalPainted", sweep([(xx, ya, -k), (xx, yb, k)], rrect2(0.02, 0.14, 0.006, 1), side=(1, 0, 0)))
    for sz in (-1, 1):
        beam = [(z + sz * k, y + LEGS + 0.18) for z, y in _ibeam(0.24, 0.36)]
        ctx.add("MetalPainted", loft([[(x, y, z) for z, y in beam] for x in (-(TK_R0 + 0.35), TK_R0 + 0.35)],
                                     cap_start=True, cap_end=True))
    # ---- dunnage: timbers across the beams
    for i in range(9):
        x = -2.4 + 0.6 * i
        ln = 2 * k + 0.7 + rng.uniform(-0.08, 0.08)
        ctx.add("WoodDark", box(0.22, 0.31, ln, bevel=0.025, segments=1), T(x, LEGS + 0.36 + 0.145, rng.uniform(-0.04, 0.04)))
    # ---- the staves (one lathe): flat boards, a groove at each joint, each board its own
    # thickness and top height
    step = 2 * math.pi / TK_N
    off = [rng.uniform(-0.012, 0.012) for _ in range(TK_N)]
    tops = [rng.uniform(0.07, 0.13) for _ in range(TK_N)]  # (ragged, all crossing into the roof)
    extra = [step * i + d for i in range(TK_N) for d in (-0.008, 0.008)]

    def stave_fn(a, r, y):
        if r < TK_R1 - 0.05:
            return (r, y)
        i = int((a % (2 * math.pi)) / step + 1e-4) % TK_N
        near = abs(_wrap(a - round(a / step) * step))
        rr = r + off[i]
        if near < 1e-4:
            rr = r - 0.016
        yy = y
        if y > top - 0.01:
            yy += tops[i] if near > 1e-4 else min(tops[i], tops[i - 1])
        return (rr, yy)

    prof = [(0, TK_Y0 + 0.14), (TK_R0 - 0.1, TK_Y0 + 0.14), (TK_R0 - 0.1, TK_Y0), (TK_R0, TK_Y0)]
    prof += [(_tk_r(y), y) for y in (TK_Y0 + 0.25, TK_Y0 + 1.4, TK_Y0 + 2.8, TK_Y0 + 4.2, top - 0.1)]
    prof += [(TK_R1, top), (TK_R1 - 0.1, top), (TK_R1 - 0.1, top - 0.3), (0, top - 0.3)]
    ctx.add("Wood", lathe(prof, segs=TK_N, extra_angles=extra, radius_fn=stave_fn))
    # ---- hoops (round rods sunk 0.01 into the staves) and their lugs
    for j, h in enumerate((0.35, 0.85, 1.42, 2.05, 2.75, 3.55, 4.5)):
        y = TK_Y0 + h
        rr = _tk_r(y) + 0.022
        ctx.add("Rust", torus(rr, 0.034, segs=TK_N, sides=4, y=y))
        a = 0.6 + j * 2.1 + rng.uniform(-0.2, 0.2)
        c = Vector((math.cos(a), 0, math.sin(a)))
        lug = box(0.12, 0.11, 0.2, bevel=0.02, segments=1)
        ang = math.degrees(math.atan2(c.x, c.z))
        ctx.add("Rust", lug, T(*(c * (rr + 0.04) + Vector((0, y, 0)))) @ R(0, ang))
    # ---- conical roof: tar paper in courses (a small step at each), eave, underside
    rise = 1.15
    re = TK_R1 + 0.22

    def roof_y(r):
        return top + 0.12 + (re - r) / re * rise

    prof = [(0, roof_y(0) + 0.0)]
    n_c = 7
    for i in range(n_c):
        r = 0.22 + (re - 0.22) * i / n_c
        prof.append((r, roof_y(r)))
        prof.append((r + 0.006, roof_y(r) - 0.03))
    prof += [(re, roof_y(re)), (re + 0.01, top + 0.04), (re - 0.08, top + 0.03), (TK_R1 - 0.2, top + 0.05), (0, top + 0.05)]
    sag = rng.uniform(0.02, 0.05)
    ctx.add("Black", lathe(prof, segs=TK_N, radius_fn=lambda a, r, y: (r, y - sag * math.sin(math.pi * min(1, r / re))
                                                                        * (1 + 0.5 * math.cos(3 * a)))))
    # fascia board round the eave
    ctx.add("WoodDark", lathe([(re - 0.02, top - 0.08), (re + 0.035, top - 0.08), (re + 0.035, top + 0.1),
                               (re - 0.02, top + 0.1)], segs=TK_N), T(0, 0, 0))
    # hatch on the roof (toward the ladder), finial on top
    ha = math.radians(-120)
    hr = 1.25
    slope = math.degrees(math.atan2(rise, re))
    hp = Vector((hr * math.cos(ha), roof_y(hr) + 0.04, hr * math.sin(ha)))
    yaw = math.degrees(math.atan2(math.cos(ha), math.sin(ha)))
    ctx.add("WoodDark", rbox(0.75, 0.14, 0.7, r=0.03, m=1), T(*hp) @ R(0, yaw) @ R(slope))
    ctx.add("Metal", lathe([(0, roof_y(0) + 0.45), (0.05, roof_y(0) + 0.42), (0.1, roof_y(0) + 0.33), (0.08, roof_y(0) + 0.25),
                            (0.04, roof_y(0) + 0.2), (0.05, roof_y(0) - 0.05), (0, roof_y(0) - 0.05)], segs=10))
    # ---- ladder up the side, to the hatch
    la = ha
    er, et = Vector((math.cos(la), 0, math.sin(la))), Vector((-math.sin(la), 0, math.cos(la)))
    yb_, yt_ = LEGS + 0.36, top + 0.55
    for s in (-1, 1):
        p0 = er * (TK_R0 + 0.42) + et * (0.24 * s) + Vector((0, yb_, 0))
        p1 = er * (TK_R1 + 0.36) + et * (0.24 * s) + Vector((0, yt_, 0))
        ctx.add("Rust", sweep([p0, p1], rrect2(0.12, 0.05, 0.01, 1), side=tuple(er)))
        for yy in (TK_Y0 + 0.6, TK_Y0 + 3.0, top - 0.3):  # stand-off brackets to the hoops
            t_ = (yy - yb_) / (yt_ - yb_)
            pr = p0.lerp(p1, t_)
            ctx.add("Rust", tube([pr, er * (_tk_r(yy) - 0.01) + et * (0.24 * s) + Vector((0, yy, 0))], 0.022, segs=5))
    for i in range(int((yt_ - yb_ - 0.3) / 0.45)):
        yy = yb_ + 0.4 + i * 0.45
        t_ = (yy - yb_) / (yt_ - yb_)
        rr = lerp(TK_R0 + 0.42, TK_R1 + 0.36, t_)
        c = er * rr + Vector((0, yy, 0))
        ctx.add("Rust", tube([c - et * 0.26, c + et * 0.26], 0.024, segs=6))
    # ---- outlet: down between two timbers, a gate valve, then along and into the roof
    ox, oz = 0.9, -1.0
    path = fillet_path([(ox, TK_Y0 + 0.3, oz), (ox, 0.55, oz), (ox, 0.55, -3.0), (ox, -0.1, -3.0)], 0.35, 8)
    ctx.add("Rust", tube(path, 0.12, segs=12))
    ctx.add("Rust", lathe([(0.0, -0.2), (0.17, -0.2), (0.19, -0.1), (0.19, 0.1), (0.17, 0.2), (0.0, 0.2)], segs=12), T(ox, 1.9, oz))
    ctx.add("Rust", tube([(ox, 1.9, oz), (ox, 1.9, oz - 0.42)], 0.03, segs=6))
    ctx.add("Rust", torus(0.17, 0.022, segs=16, sides=5), T(ox, 1.9, oz - 0.42) @ R(90))
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        ctx.add("Rust", tube([(ox, 1.9, oz - 0.42), (ox + 0.16 * math.cos(a), 1.9 + 0.16 * math.sin(a), oz - 0.42)], 0.016, segs=4))
    ctx.add("Rust", lathe([(0.0, 0.0), (0.2, 0.0), (0.2, 0.06), (0.0, 0.06)], segs=12), T(ox, 2.6, oz))

    # ---- wear
    def wood(p):
        x, y, z = p.co
        a = math.atan2(z, x)
        # silver-grey weathered cedar, darker and wet toward the foot, dark streaks running down
        # from the hoops and the roof drip line, a green-black stain on the shaded north side
        g = 0.85 + 0.15 * noise.fbm((x * 0.8, y * 2.0, z * 0.8), 2)
        wet = 1 - 0.35 * (1 - smoothstep(TK_Y0, TK_Y0 + 1.6, y))
        drip = 1 - 0.25 * smoothstep(0.1, 0.7, noise.fbm((math.cos(a) * 12, y * 0.25, math.sin(a) * 12), 2))
        k = g * wet * drip * (1 - 0.3 * smoothstep(0.0, 0.5, -p.convex))
        if y < TK_Y0 + 0.16 and math.hypot(x, z) < TK_R0 - 0.05:
            k *= 0.5
        north = smoothstep(0.2, 1.0, math.sin(a))
        return (k * (0.82 - 0.1 * north), k * (0.88 - 0.05 * north), k * (0.98 - 0.08 * north))

    ctx.wear("Wood", wood)
    ctx.wear("Rust", lambda p: (0.7 + 0.3 * noise.fbm(p.co * 3, 2)) * (1 - 0.3 * smoothstep(0.0, 0.5, -p.convex)))
    ctx.wear("Black", lambda p: (0.8 + 0.2 * noise.fbm(p.co * 2.5, 3)) if p.normal.y > 0 else 0.6)
    ctx.wear("WoodDark", mul(lambda p: 0.75 + 0.25 * noise.fbm(p.co * 3, 2), cavity(0.3)))
    ctx.wear("MetalPainted", mul(ground_dirt(0.8, 0.35, noise), lambda p: (1.0, 0.92, 0.86) if noise.fbm(p.co * 4, 2) > 0.25
                                 else 0.95, cavity(0.3)))
    ctx.wear("Metal", lambda p: 0.75)


# ==============================================================================================
# OfficeChair / OfficeChairWorn. A task chair dumped in the alley (real_specs "OFFICE CHAIR",
# props_objects.office_chair: footprint 2.4 x 2.4, 4 tall):
#   * a five-star nylon base (2.2 across): five tapered arms rising to a hub, a twin-wheel
#     castor under each tip (each swivelled its own way);
#   * the gas lift: a black telescopic shroud, the chrome cylinder above it;
#   * the tilt mechanism under the seat, its paddle lever on the right;
#   * the seat: a contoured cushion (crowned, a waterfall front edge rolling down, slight side
#     bolsters) on a black moulded seat pan;
#   * the back: a curved cushion (wrapping round the sitter, a lumbar bulge, the top rolling
#     back) on its moulded shell, carried by a curved steel spine from the mechanism;
#   * T-armrests: a flat steel bracket under the seat, an upright post, a soft pad.
# Fabric is the one tintable layer (default faded charcoal blue). Wear: pilled, stained,
# grimy at the front edge and the arm pads where hands go.
# OfficeChairWorn: the back snapped and flopped back, the seat split with yellow foam bulging
# out, one arm pad gone, one castor missing, the seat sagging to one side, filthier. The data's
# "tipped" state is this piece on its side (rz = 90 about a point 1.2 up, as the props do).
# Origin: the centre of the base on the floor, front = -Z.
# ==============================================================================================
def _seat_shape(sag):
    hx, hy, hz = 0.93, 0.17, 0.88

    def fn(co):
        x, y, z = co
        u, w = x / hx, z / hz
        top = smoothstep(-0.4, 1.0, y / hy)
        y2 = y + 0.055 * (1 - u * u) * (1 - w * w) * top  # crown
        y2 += 0.025 * u ** 4 * top  # side bolsters
        front = smoothstep(-0.3, -1.0, w)  # waterfall: the front edge rolls down
        y2 -= 0.1 * front * (0.5 + 0.5 * top)
        z2 = z - 0.03 * front * top
        y2 -= sag * (1 - u * u) * (1 - w * w) * top
        return Vector((x, y2, z2))

    return fn


def _back_shape(puff):
    hx, hy = 0.87, 0.95

    def fn(co):
        x, y, z = co
        u, v = x / hx, y / hy
        x2 = x * (1 - 0.1 * smoothstep(0.1, -1.0, v))  # narrower at the waist
        z2 = z - 0.2 * u * u  # wraps round the sitter (front = -Z)
        z2 -= 0.07 * math.exp(-((v + 0.38) / 0.35) ** 2) * (1 - 0.5 * u * u)  # lumbar
        z2 += 0.08 * smoothstep(0.45, 1.0, v)  # the top rolls back
        if puff and z < 0:
            z2 -= 0.035 * (1 - u * u) * (1 - v * v)
        return Vector((x2, y, z2))

    return fn


def _chair(ctx, worn):
    ctx.budget = 7200
    ctx.smooth_angle = 48
    ctx.tint("Fabric", (52, 58, 70))
    noise, rng = ctx.noise, ctx.rng
    missing = 3 if worn else -1
    # ---- base: hub, five arms, castors
    hub = [(0, 0.3), (0.19, 0.3), (0.215, 0.33), (0.215, 0.47), (0.18, 0.52), (0.12, 0.54), (0, 0.545)]
    ctx.add("PlasticDark", lathe(hub, segs=20))
    for kk in range(5):
        a = math.radians(kk * 72 + (6 if worn else 0))
        d = Vector((math.sin(a), 0, -math.cos(a)))
        side = Vector((math.cos(a), 0, math.sin(a)))
        rings = []
        for i in range(8):
            t = i / 7
            c = d * lerp(0.1, 1.02, t) + Vector((0, lerp(0.44, 0.33, t) + 0.02 * math.sin(math.pi * t), 0))
            w, h = lerp(0.2, 0.13, t), lerp(0.17, 0.1, t)
            sec = rrect2(w, h, min(w, h) * 0.4, 1)
            rings.append([tuple(c + side * su + Vector((0, sv, 0))) for su, sv in sec])
        ctx.add("PlasticDark", loft(rings, cap_start=True, cap_end=True))
        tip = d * 1.02
        ctx.add("PlasticDark", cyl(0.07, 0.1, segs=12), T(tip.x, 0.31, tip.z))
        ctx.add("Metal", cyl(0.022, 0.1, segs=8), T(tip.x, 0.23, tip.z))
        if kk == missing:
            continue
        sw = rng.uniform(0, 360)
        cm = T(tip.x, 0, tip.z) @ R(0, sw)
        ctx.add("PlasticDark", rbox(0.075, 0.12, 0.2, r=0.03, m=1), cm @ T(0, 0.19, 0.03))
        for s in (-1, 1):
            wheel = lathe([(0.0, -0.028), (0.08, -0.028), (0.095, -0.015), (0.095, 0.015), (0.08, 0.028), (0.0, 0.028)], segs=8)
            ctx.add("Rubber", wheel, cm @ T(s * 0.068, 0.097, 0.07) @ R(0, 0, 90))
    # ---- gas lift: shroud and chrome
    shroud = [(0, 0.52), (0.118, 0.52), (0.118, 0.8), (0.108, 0.81), (0.108, 0.96), (0.098, 0.97), (0.098, 1.02), (0, 1.02)]
    ctx.add("PlasticDark", lathe(shroud, segs=18))
    ctx.add("Chrome", cyl(0.068, 0.36, segs=16), T(0, 1.15, 0))
    # ---- seat group (tilted / sagging for the worn one)
    lean = 4.0 if worn else 0.0
    G = T(0, 0, 0) @ R(0, 0, lean)
    ctx.add("Black", rbox(0.64, 0.14, 0.64, r=0.03, m=1), G @ T(0, 1.32, 0.02))
    lever = [(0.3, 1.3, -0.08), (0.62, 1.28, -0.16), (0.78, 1.24, -0.2)]
    ctx.add("PlasticDark", tube(lever, 0.025, segs=6), G)
    ctx.add("PlasticDark", rbox(0.16, 0.05, 0.09, r=0.02, m=1), G @ T(0.82, 1.235, -0.21))
    ctx.add("PlasticDark", rbox(1.72, 0.08, 1.62, r=0.035, m=1, n=(3, 1, 3)), G @ T(0, 1.42, 0.0))
    seat = rbox(1.86, 0.34, 1.76, r=0.13, m=2, n=(8, 2, 8))
    for v in seat.verts:
        v.co = _seat_shape(0.06 if worn else 0.0)(v.co)
    foam = None
    if worn:
        # the split: the fabric torn open on the right-front, yellow foam bulging out of it
        cx, cz, rx, rz = 0.3, -0.2, 0.34, 0.26
        dead = [f for f in seat.faces
                if f.calc_center_median().y > 0.1 and
                ((f.calc_center_median().x - cx) / rx) ** 2 + ((f.calc_center_median().z - cz) / rz) ** 2
                < 1 + 0.35 * noise.n(f.calc_center_median() * 6)]
        bmesh.ops.delete(seat, geom=dead, context="FACES")
        for v in seat.verts:
            if v.is_boundary:
                v.co.y += 0.02  # the torn edge curls up
        foam = bmesh.new()
        bmesh.ops.create_icosphere(foam, subdivisions=3, radius=1.0)
        for v in foam.verts:
            p = v.co.copy()
            bump = 1 + 0.18 * noise.fbm(p * 2.2, 3)
            v.co = Vector((p.x * rx * 1.22 * bump, p.y * 0.13 * bump, p.z * rz * 1.22 * bump))
        # (centred under the cushion's skin: its section at the skin is about the split's size,
        # its top 0.05 proud, so the foam swells out of the tear and fills it to its edges)
        top_y = _seat_shape(0.06)(Vector((cx, 0.17, cz))).y
        ctx.add("Foam", foam, G @ T(cx, 1.6 + top_y - 0.055, cz))
    ctx.add("Fabric", seat, G @ T(0, 1.6, 0))
    # ---- back: the spine from the mechanism, the shell, the cushion
    tilt = 36.0 if worn else 9.0
    pivot = Vector((0, 1.4, 0.88))
    Bk = G @ T(*pivot) @ R(tilt) @ T(*(-pivot))
    spine = fillet_path([(0, 1.3, 0.2), (0, 1.3, 0.92), (0, 2.45, 1.06)], 0.3, 8)
    ctx.add("Black", sweep(spine, rrect2(0.26, 0.05, 0.018, 1), side=(1, 0, 0)), Bk if worn else G)
    back = rbox(1.74, 1.9, 0.26, r=0.12, m=2, n=(8, 8, 1))
    for v in back.verts:
        v.co = _back_shape(True)(v.co)
    ctx.add("Fabric", back, Bk @ T(0, 2.92, 0.86))
    shell = rbox(1.64, 1.8, 0.1, r=0.045, m=1, n=(6, 6, 1))
    for v in shell.verts:
        v.co = _back_shape(False)(v.co)
    ctx.add("PlasticDark", shell, Bk @ T(0, 2.92, 0.99))
    # ---- T-armrests
    pad_gone = 1 if worn else -1
    for i, s in enumerate((-1, 1)):
        br = fillet_path([(s * 0.25, 1.355, 0.1), (s * 1.02, 1.355, 0.1), (s * 1.02, 1.62, 0.1)], 0.12, 5)
        ctx.add("Black", sweep(br, rrect2(0.03, 0.12, 0.01, 1), side=(0, 1, 0)), G)
        ctx.add("PlasticDark", rbox(0.1, 0.78, 0.2, r=0.04, m=1, n=(1, 2, 1)), G @ T(s * 1.02, 1.82 + (0.0 if i != pad_gone else -0.02), 0.08))
        if i != pad_gone:
            ctx.add("Rubber", rbox(0.27, 0.09, 0.8, r=0.04, m=1, n=(1, 1, 2)), G @ T(s * 1.02, 2.24, -0.02))
        else:
            for zz in (-0.06, 0.2):  # the screw bosses the pad was on
                ctx.add("Metal", cyl(0.025, 0.04, segs=6), G @ T(s * 1.02, 2.215, zz))

    # ---- wear
    def fabric(p):
        x, y, z = p.co
        k = 0.88 + 0.12 * noise.fbm(p.co * 9, 2)  # pilling, uneven fade
        st = smoothstep(0.5, 0.75, noise.fbm(p.co * 2.2 + Vector((4, 1, 7)), 3) * 0.5 + 0.5)
        if st > 0:
            k *= 1 - (0.45 if worn else 0.3) * st  # stains (rain, coffee, worse)
            return (k * 0.95, k * 0.88, k * 0.75)
        if y < 1.9 and z < -0.55:
            k *= 0.8  # the seat's front edge, grimy from legs
        if worn:
            k *= 0.85 - 0.15 * smoothstep(0.3, 0.8, noise.fbm(p.co * 1.5, 2))
        return k * (1 - 0.3 * smoothstep(0.0, 0.4, -p.convex))

    def plastic(p):
        k = mul(ground_dirt(0.6, 0.4, noise), cavity(0.35))(p)[0]
        return k * (0.85 + 0.15 * noise.fbm(p.co * 5, 2)) + 0.12 * smoothstep(0.1, 0.5, p.convex)

    ctx.wear("Fabric", fabric)
    ctx.wear("PlasticDark", plastic)
    ctx.wear("Rubber", lambda p: 0.78 + 0.22 * noise.fbm(p.co * 6, 2) if p.co.y > 1 else 0.65)
    ctx.wear("Black", cavity(0.3))
    ctx.wear("Chrome", lambda p: 0.7 + 0.3 * noise.fbm(p.co * 12, 2))
    ctx.wear("Metal", lambda p: 0.7)
    if foam is not None:
        ctx.wear("Foam", lambda p: tuple(c * (0.8 + 0.2 * noise.fbm(p.co * 8, 2)) for c in (0.95, 0.84, 0.55)))


def office_chair(ctx):
    """Task chair: five-star base on castors, gas lift, contoured seat and back, T-arms."""
    _chair(ctx, worn=False)


def office_chair_worn(ctx):
    """The same chair wrecked: back snapped back, seat split with foam out, pad and castor gone."""
    _chair(ctx, worn=True)


PIECES = {
    "AcUnit": ac_unit,
    "GooseneckLamp": gooseneck_lamp,
    "GooseneckLampDead": gooseneck_lamp_dead,
    "BulkheadLight": bulkhead_light,
    "BulkheadLightDead": bulkhead_light_dead,
    "SatelliteDish": satellite_dish,
    "DownpipeStraight": downpipe_straight,
    "DownpipeStraightShort": downpipe_straight_short,
    "DownpipeOffset": downpipe_offset,
    "DownpipeShoe": downpipe_shoe,
    "DownpipeBracket": downpipe_bracket,
    "WaterTank": water_tank,
    "OfficeChair": office_chair,
    "OfficeChairWorn": office_chair_worn,
}
