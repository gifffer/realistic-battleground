"""Street furniture of the city prop kit (the main avenues, the crossroads, the kiosk corner):
the lamp columns, the traffic signal (pole + 3-aspect head), the payphone booth, the fire
hydrants, the concrete Jersey barriers, the news kiosk with its magazine rack and newspaper
bundles, the perforated steel bench, the steel bollards, the steam grate and the manhole cover.

Why meshes: the city's versions (CityData, Props/*) were primitive stacks: a square black stick
with a flat box arm for a lamp, a box with three flat squares for a signal, three cylinders and
a bar for a hydrant, a grey box for a 3-tonne concrete barrier, a box with coloured cubes for a
kiosk. Each one here is modelled once to the real object's proportions (lathes for cast and
spun parts, sweeps for bent tube, prisms of the real section for extrusions), with the details
that make it read (flange bolts, base door, visors, chained caps, lifting loops, rolled roof
edge, perforations, cast lettering) and the wear a city street puts on it (vertex colours:
grime rising from the pavement, rust weeping from bolts, paint rubbed off edges, flyers and
stickers, chips).

Conventions (pieces/_template.py): Roblox axes, studs (1 stud ~ 0.28 m), +Y up, front = -Z.
Floor pieces: origin at the centre of the footprint on the ground. Each piece fits the
footprint of the city part it replaces (tools/city/overlay/edits/street.py wraps them; the old
colliding parts stay as invisible proxies, the mesh within ~0.3 stud of them). Only ONE kind of
tintable layer per piece (the marker's Tint goes to every tintable layer). No bottles of any
kind.

Lamps: the lit lens is a Glow layer with a Light marker under it (PropKit hands the old
LampHead's CityLamp tag, Dead / Flicker attributes and SpotLight to it); StreetLampColumnDead
has its bowl in dull Glass (the data's Dead lamp).
"""

import math

import bmesh
from mathutils import Vector

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
from fixtures import (  # noqa: F401  (shared shape helpers of the kit, read-only use)
    rbox,
    prism,
    spline,
    fillet_path,
    sweep,
    circle2,
    rrect2,
    torus,
    _transform,
    _nut,
    _dome,
)

TAU = 2 * math.pi


# ==============================================================================================
# Shared helpers
# ==============================================================================================
def bend(bm, r_fn, a_mid):
    """Bends a flat patch (x across, y up, z = thickness, centred on z = 0) round the Y axis:
    x becomes an arc at radius r_fn(y) + z centred on angle a_mid (0 = +X, pi/2 = +Z, -pi/2 =
    the front). For stickers, posters, doors laid on round poles."""
    for v in bm.verts:
        x, y, z = v.co
        r = r_fn(y)
        a = a_mid + x / max(r, 1e-3)
        v.co = Vector(((r + z) * math.cos(a), y, (r + z) * math.sin(a)))
    return bm


def patch(w, h, t, nx, ny, jag=None, rng=None):
    """A thin sheet w x h x t (cells nx * ny) whose top / bottom edges can be torn (jag:
    max amount in studs, random per column)."""
    bm = rbox(w, h, t, r=min(0.004, t * 0.45), m=1, n=(nx, ny, 1))
    if jag and rng:
        cols = {}
        for v in bm.verts:
            k = round(v.co.x, 4)
            if k not in cols:
                cols[k] = (rng.uniform(0, jag), rng.uniform(0, jag * 0.6))
        for v in bm.verts:
            top, bot = cols[round(v.co.x, 4)]
            if v.co.y > h / 2 - 1e-3:
                v.co.y -= top
            elif v.co.y < -h / 2 + 1e-3:
                v.co.y += bot
    return bm


def ring_bolts(ctx, layer, n, rad, y, r=0.045, h=0.05, a0=0.0, stud=True):
    """n hex nuts on a circle (a flange's bolts), each on a short threaded stud."""
    for k in range(n):
        a = a0 + TAU * k / n
        x, z = rad * math.cos(a), rad * math.sin(a)
        ctx.add(layer, _nut(r, h), T(x, y, z) @ R(0, -math.degrees(a)))
        if stud:
            ctx.add(layer, cyl(r * 0.45, h * 0.9, segs=6), T(x, y + h + h * 0.35, z))


def paint_wear(noise, dirt_h=1.2, dirt=0.35, rust_y=None, rust_rgb=(0.86, 0.6, 0.45), streak=0.18, scale=3.0,
               top_grime=0.15):
    """Painted street metal: dirt rising from the pavement (browner low), grime in creases,
    rubbed edges, rain streaks, an optional rusty band up to rust_y."""
    st = streaks(noise, streak, 5.0)

    def fn(p):
        x, y, z = p.co
        k = 0.88 + 0.12 * noise.fbm(p.co * scale, 2)
        g = 1 - dirt * (1 - smoothstep(0.0, dirt_h * (1 + 0.3 * noise.fbm(p.co, 2, 2.0)), y))
        c = (k * g, k * g * 0.97, k * g * 0.92)
        if rust_y is not None:
            t = (1 - smoothstep(rust_y * 0.5, rust_y, y)) * smoothstep(-0.1, 0.4, noise.fbm(p.co * 4.0, 3))
            c = tuple(lerp(a, a * b, t) for a, b in zip(c, rust_rgb))
        cav = 1 - 0.3 * smoothstep(0.0, 0.5, -p.convex)
        edge = 1 + 0.12 * smoothstep(0.05, 0.5, p.convex)
        up = 1 - top_grime * smoothstep(0.6, 0.95, p.normal.y)
        s = st(p)
        return tuple(v * cav * edge * up * s for v in c)

    return fn


def print_wear(noise, rows, base=1.0, ink=0.42, colour=None):
    """Paper / a sticker printed with bands of 'text' (dark rows) and a fading top: rows =
    [(y0, y1), ...] in piece space where the ink goes; colour = an rgb multiplier for the
    paper (a coloured flyer)."""

    def fn(p):
        x, y, z = p.co
        k = base * (0.86 + 0.14 * noise.fbm(p.co * 9, 2))
        c = colour or (1.0, 1.0, 1.0)
        for y0, y1 in rows:
            if y0 <= y <= y1:
                k *= ink + (1 - ink) * smoothstep(0.2, 0.8, noise.fbm(Vector((x * 30, y * 4, z * 30)), 1) * 0.5 + 0.5)
                break
        return tuple(k * v for v in c)

    return fn


def text_bm(txt, size, depth, bold=True, res=2):
    """Raised lettering: Blender's built-in font extruded `depth`, centred on the origin in the
    XY plane, readable from +Z (turn it R(0, 180, 0) to read from the front, -Z)."""
    import bpy

    cu = bpy.data.curves.new("_txt", "FONT")
    cu.body = txt
    cu.size = size
    cu.extrude = depth / 2
    cu.resolution_u = res
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    if bold:
        cu.offset = size * 0.035
    ob = bpy.data.objects.new("_txt", cu)
    bpy.context.scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = ev.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    ev.to_mesh_clear()
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    return bm


# ==============================================================================================
# StreetLampColumn (+Rusty, Dead). Real reference: a city street-lighting column 4.5-6 m
# (here 16 studs = 4.5 m to the top of the shaft): a hot-dip galvanised and painted conical
# steel shaft (~140 mm at the root, ~76 mm at the top) on a bolted flange plate over four
# anchor bolts, a cast base shroud with the service door (the fuse box inside), a swan-neck
# outreach arm of 1.2 m (here 4.4 studs: the city's heads stand 4.4 from the pole), and the
# luminaire: a modern flat LED head (die-cast body, cooling fins on top, a flat lens under it,
# a photocell on top), or on the old columns a 1970s "cobra head" sodium lantern (teardrop
# hood, a clear prismatic bowl hanging under it). Typical wear: pavement grime and dog marks
# on the base, rust weeping from the flange bolts, layers of flyers and stickers taped at eye
# level, the base door scuffed or missing with the wiring hanging out.
# City footprint (Props/Lamps): LampBase 1.2 cube on the ground, LampPole 0.6 square up to
# y 16.0 (both collide: the proxies), head bottom at y 14.8, its centre 4.4 out (3.9 on the
# crossroads' diagonal lamps). Here the arm points to -Z; the head's lens centre is at
# (0, 14.78, -4.4).
# ==============================================================================================
LAMP_TOP = 15.7
HEAD_Z = -4.4
HEAD_Y = 14.8  # bottom of the head


def _shaft_r(y):
    """Radius of the conical shaft at height y (above the base collar)."""
    return lerp(0.25, 0.155, smoothstep(1.4, LAMP_TOP, y) ** 0.9 if y > 1.4 else 0.0)


def _lamp_column(ctx, rusty=False, dead=False):
    noise, rng = ctx.noise, ctx.rng
    # ---- flange plate (square, chamfered corners) and its four anchor bolts
    plate_layer = "Rust" if rusty else "MetalPainted"
    ctx.add(plate_layer, rbox(0.98, 0.07, 0.98, r=0.025, m=1, n=(2, 1, 2)), T(0, 0.025, 0) @ R(0, 45 if rusty else 0, 0))
    ring_bolts(ctx, "Metal" if not rusty else "Rust", 4, 0.56, 0.06, r=0.05, h=0.05, a0=math.pi / 4 + (0 if rusty else math.pi / 4) - math.pi / 4)
    # ---- cast base shroud + conical shaft: ONE lathe (rings every ~0.6 for the wear gradient)
    prof = [(0.0, 0.06), (0.47, 0.06), (0.47, 0.13), (0.44, 0.17), (0.43, 0.24), (0.4, 0.28), (0.395, 0.34)]
    for k in range(9):  # (the base's gentle taper)
        y = lerp(0.4, 1.12, k / 8)
        prof.append((lerp(0.385, 0.3, (k / 8) ** 1.2), y))
    prof += [(0.335, 1.16), (0.345, 1.2), (0.345, 1.3), (0.3, 1.34), (0.26, 1.4)]
    ys = [1.4 + (LAMP_TOP - 1.4) * (k / 13) for k in range(1, 14)]
    prof += [(_shaft_r(y), y) for y in ys]
    prof += [(0.17, LAMP_TOP + 0.04), (0.14, LAMP_TOP + 0.1), (0.0, LAMP_TOP + 0.12)]

    def dent(a, r, y):
        d = 0.0
        if rusty:  # (a car's knock low on the shaft, the pole leaning a little)
            d -= 0.03 * math.exp(-((y - 2.4) / 0.35) ** 2) * max(0.0, math.cos(a - 0.6)) ** 3
        return r + d

    shaft = lathe(prof, segs=24, radius_fn=dent)
    if dead:  # (the old column leans: a car hit its base years ago)
        lean = math.radians(0.7)
        for v in shaft.verts:
            v.co.x += math.sin(lean) * max(0.0, v.co.y - 1.3)
    ctx.add("MetalPainted", shaft)
    # ---- the base door (+X side, eye of the fuse box): a raised panel on the taper, a key screw
    a_door = 0.0
    taper = math.degrees(math.atan2(0.085, 0.72))
    if dead:
        # the door is gone: a dark hole with the cables hanging out of it
        hole = rbox(0.24, 0.5, 0.06, r=0.03, m=2)
        ctx.add("Black", hole, T(0.343, 0.72, 0) @ R(0, 0, taper) @ R(0, 90, 0))
        for k, (dx, c) in enumerate(((-0.05, 0.0), (0.04, 0.6), (0.0, 1.2))):
            pts = [(0.37, 0.88 + dx, dx), (0.44, 0.7 + dx * 0.5, dx * 1.6), (0.47 + 0.02 * k, 0.48 - 0.05 * k, dx * 2.2 + 0.03)]
            ctx.add("Rubber", tube(spline(pts, 4), 0.022, segs=6))
    else:
        door = rbox(0.24, 0.52, 0.05, r=0.025, m=2, n=(1, 2, 1))
        ctx.add("MetalPainted", door, T(0.36, 0.72, 0) @ R(0, 0, taper) @ R(0, 90, 0))
        ctx.add("Metal", _transform(_dome(0.03, 0.02, 6), R(0, 0, -90)), T(0.385, 0.91, 0))
    # ---- swan-neck outreach arm: up out of the shaft top, round a big bend, out to the head
    arm = fillet_path([(0, LAMP_TOP - 0.6, 0), (0, LAMP_TOP + 0.3, 0), (0, LAMP_TOP + 0.55, -1.3),
                       (0, HEAD_Y + 0.26, -3.0), (0, HEAD_Y + 0.2, -3.6)], 0.8, nseg=8)
    ctx.add("MetalPainted", tube(arm, [0.1] * len(arm), segs=12))
    # (the arm's spigot collar where it leaves the shaft top)
    ctx.add("MetalPainted", cyl(0.2, 0.22, segs=16, bevel=0.03), T(0, LAMP_TOP + 0.08, 0))
    # ---- the luminaire
    if rusty or dead:
        _cobra_head(ctx, dead)
    else:
        _led_head(ctx)
    ctx.mark("Light", (0, HEAD_Y - 0.15, HEAD_Z))
    # ---- flyers, stickers, tape at eye level
    if rusty:
        r_at = lambda y: (_shaft_r(y) if y > 1.4 else 0.3) + 0.012  # noqa: E731
        posters = [(-1.2, 3.2, 0.55, 0.85), (0.9, 4.05, 0.42, 0.6), (2.6, 3.5, 0.5, 0.7), (-2.4, 4.6, 0.3, 0.38)]
        rows = []
        for k, (a, yc, w, h) in enumerate(posters):
            sheet = patch(w, h, 0.012, 3, 3, jag=0.12 if k % 2 == 0 else 0.04, rng=rng)
            bm = _transform(sheet, T(0, yc, 0))
            ctx.add("Paper", bend(bm, lambda y: r_at(y), a))
            rows += [(yc + h * 0.18, yc + h * 0.34), (yc - h * 0.1, yc + h * 0.02), (yc - h * 0.3, yc - h * 0.22)]
        tape = patch(1.2, 0.09, 0.008, 8, 1)
        ctx.add("Black", bend(_transform(tape, T(0, 2.75, 0)), lambda y: r_at(y) + 0.004, 0.3))
        ctx.wear("Paper", print_wear(noise, rows, base=0.9))
        ctx.wear("Rust", mul(lambda p: 0.75 + 0.25 * noise.fbm(p.co * 8, 2), cavity(0.3)))
    paint_fn = paint_wear(noise, dirt_h=1.6 if rusty else 1.1, dirt=0.42 if rusty else 0.3,
                          rust_y=1.4 if rusty else (0.6 if dead else None), streak=0.22 if rusty or dead else 0.14)

    def lamp_paint(p):
        c = paint_fn(p)
        x, y, z = p.co
        # (dog marks: a dark wet stain up one side of the base)
        k = 1 - 0.25 * (1 - smoothstep(0.1, 0.55, y)) * smoothstep(0.2, 0.9, math.cos(math.atan2(z, x) + 2.2))
        # (soot / dust on the arm's top, black under the head)
        if y > HEAD_Y - 0.4 and p.normal.y > 0.3:
            k *= 0.85
        return tuple(v * k for v in c)

    ctx.wear("MetalPainted", lamp_paint)
    ctx.wear("Metal", mul(lambda p: (0.82 + 0.1 * noise.fbm(p.co * 6, 2), 0.74, 0.62) if p.co.y < 0.3 else 0.85,
                          cavity(0.3)))


def _led_head(ctx):
    """Flat die-cast LED street luminaire: a tapered body, cooling fins on its back, the flat lens
    under it in a frame, a photocell on top, the arm's spigot entering its back."""
    noise = ctx.noise
    z0, z1 = HEAD_Z + 1.15, HEAD_Z - 1.25  # back (on the arm) .. nose
    rings = []
    n = 12
    for k in range(n + 1):
        t = k / n
        z = lerp(z0, z1, t)
        w = 0.5 + 0.55 * smoothstep(0.0, 0.22, t) - 0.18 * smoothstep(0.75, 1.0, t)
        h = 0.36 + 0.06 * math.sin(math.pi * min(1, t * 1.2)) - 0.12 * smoothstep(0.85, 1.0, t)
        pts = rrect2(w, h, min(0.14, h * 0.45), 3)
        # (the top bulges: a die-cast crown)
        ring = []
        for x, y in pts:
            yy = y + (0.05 * (1 - (2 * x / w) ** 2) if y > 0 else 0)
            ring.append((x, HEAD_Y + h / 2 + yy, z))
        rings.append(ring)
    body = loft(rings, cap_start=True, cap_end=True)
    ctx.add("MetalPainted", body)
    # lens frame + flat lens (Glow), proud UNDER the body
    zc = HEAD_Z - 0.05
    ctx.add("MetalPainted", rbox(0.86, 0.05, 1.62, r=0.02, m=1), T(0, HEAD_Y - 0.01, zc))
    ctx.add("Glow", rbox(0.72, 0.04, 1.46, r=0.015, m=1, n=(2, 1, 4)), T(0, HEAD_Y - 0.04, zc))
    # cooling fins on the crown (between the photocell and the nose)
    for k in range(7):
        x = -0.27 + 0.09 * k
        ctx.add("MetalPainted", rbox(0.025, 0.09, 1.0, r=0.01, m=1), T(x, HEAD_Y + 0.43, HEAD_Z - 0.2))
    # photocell (a twist-lock cell on the back of the crown)
    ctx.add("PlasticDark", cyl(0.1, 0.1, segs=12, bevel=0.015), T(0, HEAD_Y + 0.47, HEAD_Z + 0.75))
    ctx.add("PlasticDark", lathe([(0, 0.0), (0.09, 0.0), (0.085, 0.05), (0.05, 0.1), (0, 0.11)], segs=12),
            T(0, HEAD_Y + 0.52, HEAD_Z + 0.75))
    ctx.wear("Glow", lambda p: 0.85 + 0.15 * noise.fbm(p.co * 5, 2))
    ctx.wear("PlasticDark", lambda p: 0.9)


def _cobra_head(ctx, dead):
    """1970s cobra-head lantern: a teardrop hood (wide at the back, a long nose), a clear
    prismatic bowl hanging under it (Glow, or dull Glass when dead), a hinge and latch."""
    noise = ctx.noise
    zb, zf = HEAD_Z + 1.2, HEAD_Z - 1.25
    rings = []
    n = 14
    prof = []
    for k in range(n + 1):
        t = k / n
        z = lerp(zb, zf, t)
        # half-width: round back, widest at 30 %, tapering nose
        w = 0.3 + 0.36 * math.sin(math.pi * min(1.0, t / 0.6) * 0.5) - 0.3 * smoothstep(0.55, 1.0, t)
        w = max(w, 0.06)
        h = 0.18 + 0.22 * math.sin(math.pi * min(1.0, t / 0.5) * 0.5) - 0.24 * smoothstep(0.6, 1.0, t)
        h = max(h, 0.06)
        prof.append((z, w, h))
        ring = []
        for j in range(16):
            a = TAU * j / 16
            ca, sa = math.cos(a), math.sin(a)
            # the hood: a half ellipse on top, a flat skirt under (the bowl hangs below)
            y = h * sa if sa > 0 else 0.05 * sa
            ring.append((w * ca, HEAD_Y + 0.18 + y, z))
        rings.append(ring)
    hood = loft([[(0, HEAD_Y + 0.2, zb - 0.02)]] + rings + [[(0, HEAD_Y + 0.17, zf - 0.02)]])
    ctx.add("MetalPainted", hood)
    # the bowl: a half ellipsoid hanging under the hood (prismatic ribs as small ripples)
    bowl_rings = []
    for k in range(8):
        t = k / 7
        s = math.sin(math.pi / 2 * t)
        ring = []
        for j in range(20):
            a = TAU * j / 20
            rr = (1 - 0.05 * (math.cos(12 * a) * 0.5 + 0.5)) * s
            ring.append((0.48 * rr * math.cos(a), HEAD_Y + 0.14 - 0.32 * math.cos(math.pi / 2 * t), HEAD_Z - 0.05 + 0.95 * rr * math.sin(a)))
        bowl_rings.append(ring)
    bowl = loft([[(0, HEAD_Y + 0.14 - 0.32, HEAD_Z - 0.05)]] + bowl_rings[1:] + [[(0, HEAD_Y + 0.14, HEAD_Z - 0.05)]])
    if dead:  # (a stone took a bite out of it: the near edge pushed in)
        for v in bowl.verts:
            d = (v.co - Vector((0.3, HEAD_Y - 0.1, HEAD_Z - 0.5))).length
            if d < 0.3:
                v.co += (Vector((0, HEAD_Y + 0.05, HEAD_Z)) - v.co) * 0.35 * (1 - d / 0.3)
    ctx.add("Glass" if dead else "Glow", bowl)
    # bowl ring (the door frame) and its latch
    ring_path = [(0.5 * math.cos(a), HEAD_Y + 0.15, HEAD_Z - 0.05 + 0.97 * math.sin(a))
                 for a in (TAU * j / 24 for j in range(24))]
    ctx.add("MetalPainted", sweep(ring_path, rrect2(0.07, 0.05, 0.015, 1), side=(0, 1, 0), closed=True))
    ctx.add("Metal", rbox(0.1, 0.08, 0.12, r=0.02, m=1), T(0, HEAD_Y + 0.14, HEAD_Z - 1.06))
    # the slip-fitter where the arm enters (a short boss) + photocell
    ctx.add("MetalPainted", cyl(0.15, 0.36, segs=12, bevel=0.03), T(0, HEAD_Y + 0.2, HEAD_Z + 1.22) @ R(90, 0, 0))
    ctx.add("PlasticDark", cyl(0.1, 0.12, segs=12, bevel=0.015), T(0, HEAD_Y + 0.6, HEAD_Z + 0.55))
    k_glass = 0.62 if dead else 0.8
    ctx.wear("Glass" if dead else "Glow",
             lambda p: k_glass * (1 - 0.4 * smoothstep(0.0, 0.8, noise.fbm(p.co * 6, 2) * 0.5 + 0.3)))
    ctx.wear("PlasticDark", lambda p: 0.85)


def street_lamp_column(ctx):
    """Street lighting column 4.5 m: conical painted shaft on a bolted flange, cast base with
    its service door, swan-neck arm, flat LED head (Glow lens, Light marker), photocell."""
    ctx.budget = 5000
    ctx.tint("MetalPainted", (44, 50, 48))
    _lamp_column(ctx)


def street_lamp_column_rusty(ctx):
    """The old column: cobra-head sodium lantern (Glow bowl), rusty flange and foot, a dented
    shaft, flyers and tape at eye level."""
    ctx.budget = 6000
    ctx.tint("MetalPainted", (48, 52, 46))
    _lamp_column(ctx, rusty=True)


def street_lamp_column_dead(ctx):
    """The dead column: cobra head with a dull, chipped glass bowl, the base door missing and
    the cables hanging out, the shaft leaning a little."""
    ctx.budget = 5200
    ctx.tint("MetalPainted", (42, 44, 44))
    _lamp_column(ctx, dead=True)


# ==============================================================================================
# TrafficSignalPole + TrafficSignalHead. Real reference: a US-style vehicle signal: a 3-aspect
# polycarbonate head (sections ~0.35 m square, 200-300 mm lenses, each under a tunnel visor)
# with a black backplate edged by a yellow retroreflective border, bolted to a 3.5-4 m painted
# steel pole by two clamp brackets; the pole stands on a bolted base with a cast collar, carries
# a pedestrian push-button unit at 1.0 m (yellow housing, steel button, arrow plate) and a
# pedestrian head (hand / man) at ~2.4 m, a cap on top. Wear: stickers on the button unit, grime
# low on the pole, faded backplate border, the visors' edges chalky.
# City footprint (Props/Signals): SignalPole 0.5 square, 11 tall (collides: the proxy), head
# 1.2 x 3.2 x 0.8 centred 9.0 over the ground, 0.65 out from the pole axis, its three lens
# parts 0.7 squares 1.0 apart (KEPT as parts: the red one is lit; street.py makes them round
# discs sitting in the head's lens bezels, 0.445 in front of the head's centre).
# Pole piece: the head is on its -Z side. Head piece: origin = the housing's centre, lenses on
# -Z, the pole behind it (+Z).
# ==============================================================================================
SIG_H = 11.0
SIG_HEAD_Y = 9.0
SIG_OUT = 0.65


def traffic_signal_pole(ctx):
    """Signal pole 3.1 m: painted steel shaft on a bolted base, two clamp brackets for the head,
    a pedestrian push-button unit (yellow housing, steel button) and a pedestrian head."""
    ctx.budget = 4400
    ctx.tint("MetalPainted", (40, 42, 42))
    noise = ctx.noise
    # base: flange plate, cast collar, then the shaft (one lathe), a domed cap on top
    ctx.add("MetalPainted", rbox(0.82, 0.06, 0.82, r=0.02, m=1), T(0, 0.02, 0))
    ring_bolts(ctx, "Metal", 4, 0.48, 0.05, r=0.042, h=0.045, a0=math.pi / 4)
    prof = [(0.0, 0.05), (0.33, 0.05), (0.33, 0.12), (0.3, 0.16), (0.29, 0.5), (0.31, 0.54), (0.31, 0.62),
            (0.23, 0.68), (0.22, 0.75)]
    prof += [(0.22 - 0.02 * (k / 8), lerp(0.75, SIG_H - 0.12, k / 8)) for k in range(1, 9)]
    prof += [(0.235, SIG_H - 0.1), (0.235, SIG_H - 0.02), (0.16, SIG_H + 0.06), (0.0, SIG_H + 0.1)]
    ctx.add("MetalPainted", lathe(prof, segs=20))
    # head brackets: clamp bands round the pole, an arm to the head's back
    for y in (SIG_HEAD_Y - 0.9, SIG_HEAD_Y + 0.9):
        ctx.add("MetalPainted", torus(0.215, 0.035, segs=20, sides=6, y=y))
        ctx.add("MetalPainted", rbox(0.16, 0.14, 0.12, r=0.03, m=1), T(0, y, -0.26))
        ctx.add("Metal", _nut(0.035, 0.04), T(0.09, y, -0.24) @ R(0, 0, -90))
    # pedestrian push button unit (+X side, 3.6 over the pavement)
    yb = 3.6
    ctx.add("Reflective", rbox(0.18, 0.62, 0.36, r=0.05, m=2), T(0.3, yb, 0))
    ctx.add("Metal", cyl(0.075, 0.06, segs=14, bevel=0.015), T(0.41, yb + 0.08, 0) @ R(0, 0, 90))
    ctx.add("Black", rbox(0.02, 0.16, 0.24, r=0.008, m=1), T(0.395, yb - 0.17, 0))  # arrow plate
    for y in (yb - 0.22, yb + 0.22):
        ctx.add("Metal", torus(0.225, 0.02, segs=16, sides=4, y=y))
    # pedestrian head (hand / man): +X side, facing +X, 7.0 up
    yp = 7.0
    ctx.add("PlasticDark", rbox(0.5, 0.95, 0.85, r=0.06, m=2), T(0.55, yp, 0))
    ctx.add("Glass", rbox(0.03, 0.72, 0.62, r=0.02, m=1), T(0.81, yp, 0))
    ctx.add("Black", rbox(0.36, 0.05, 0.72, r=0.015, m=1), T(0.98, yp + 0.38, 0))  # the cap visor
    ctx.add("Black", rbox(0.36, 0.5, 0.03, r=0.01, m=1), T(0.98, yp + 0.13, 0.355))
    ctx.add("Black", rbox(0.36, 0.5, 0.03, r=0.01, m=1), T(0.98, yp + 0.13, -0.355))
    ctx.add("MetalPainted", rbox(0.24, 0.3, 0.24, r=0.04, m=1), T(0.28, yp, 0))  # its bracket
    for y in (yp - 0.1, yp + 0.1):
        ctx.add("MetalPainted", torus(0.215, 0.03, segs=16, sides=5, y=y))
    # stickers on the shaft (+X / back) and on the button unit
    rows = []
    for k, (a, yc, w, h) in enumerate(((0.4, 5.3, 0.22, 0.3), (2.6, 4.6, 0.28, 0.2), (-0.9, 4.2, 0.18, 0.18))):
        r_ = 0.212 + 0.008
        ctx.add("Paper", bend(_transform(patch(w, h, 0.008, 2, 2), T(0, yc, 0)), lambda y: r_, a))
        rows.append((yc - h * 0.2, yc + h * 0.1))
    ctx.wear("Paper", print_wear(noise, rows, base=0.85, colour=(1.0, 0.92, 0.8)))
    ctx.wear("MetalPainted", paint_wear(noise, dirt_h=1.3, dirt=0.35, rust_y=0.35, streak=0.16))
    ctx.wear("Reflective", lambda p: (1.0 * (0.85 + 0.1 * noise.fbm(p.co * 8, 2)), 0.78, 0.2))
    ctx.wear("Metal", mul(lambda p: 0.8 + 0.12 * noise.fbm(p.co * 7, 2), cavity(0.3)))
    ctx.wear("Glass", lambda p: 0.7)
    ctx.wear("PlasticDark", mul(lambda p: 0.9, cavity(0.3)))


def _visor(z0, z1, r, t=0.03, open_deg=70, n=14):
    """A tunnel visor: a tube shell round the lens axis (Z), open at the bottom (open_deg wide)."""
    half = math.radians(open_deg) / 2
    a0, a1 = -math.pi / 2 + half, 1.5 * math.pi - half  # (from the bottom right, over the top)
    arc = [lerp(a0, a1, k / n) for k in range(n + 1)]
    rings = []
    for k in range(4):
        t_ = k / 3
        z = lerp(z0, z1, t_)
        sag = 0.0
        outer = [((r + sag) * math.cos(a), (r + sag) * math.sin(a), z) for a in arc]
        inner = [((r - t) * math.cos(a), (r - t) * math.sin(a), z) for a in reversed(arc)]
        rings.append(outer + inner)
    return loft(rings, cap_start=True, cap_end=True)


def traffic_signal_head(ctx):
    """Three-aspect vehicle signal head: three moulded sections, lens bezels (the city's lens
    parts sit in them), tunnel visors, a black backplate with a yellow reflective border."""
    ctx.budget = 4500
    noise = ctx.noise
    for k, (y0, y1) in enumerate(((-1.6, -0.515), (-0.485, 0.485), (0.515, 1.6))):
        h = y1 - y0
        ctx.add("PlasticDark", rbox(1.2, h, 0.76, r=0.07, m=2), T(0, (y0 + y1) / 2, -0.01))
        yc = (k - 1) * 1.0
        # lens door bezel ring (the lens disc part sits inside it, 0.015 proud of the housing)
        path = [(0.34 * math.cos(a), yc + 0.34 * math.sin(a), -0.42) for a in (TAU * j / 24 for j in range(24))]
        ctx.add("PlasticDark", sweep(path, rrect2(0.07, 0.06, 0.02, 1), side=(0, 0, 1), closed=True))
        ctx.add("Black", _transform(_visor(-0.41, -1.02, 0.4, open_deg=80), T(0, yc, 0)))
        # hinge lugs (left) and latch (right) of the lens door
        ctx.add("PlasticDark", rbox(0.08, 0.16, 0.08, r=0.02, m=1), T(-0.46, yc + 0.25, -0.43))
        ctx.add("PlasticDark", rbox(0.08, 0.16, 0.08, r=0.02, m=1), T(-0.46, yc - 0.25, -0.43))
        ctx.add("Metal", rbox(0.08, 0.1, 0.07, r=0.02, m=1), T(0.46, yc, -0.43))
    # end caps (top / bottom), a cable entry on top
    ctx.add("PlasticDark", rbox(1.1, 0.06, 0.7, r=0.025, m=1), T(0, 1.62, -0.01))
    ctx.add("PlasticDark", rbox(1.1, 0.06, 0.7, r=0.025, m=1), T(0, -1.62, -0.01))
    ctx.add("Metal", cyl(0.09, 0.12, segs=10, bevel=0.02), T(0, 1.7, 0.05))
    # backplate (behind the housing) and its reflective border (proud on its front)
    plate = prism(rrect2(1.95, 3.95, 0.12, 2), 0.385, 0.42)
    ctx.add("Black", plate)
    border = []
    o, i = rrect2(1.95, 3.95, 0.12, 2), rrect2(1.69, 3.69, 0.06, 2)
    for (x0, y0), (x1, y1), (x2, y2), (x3, y3) in zip(o, o[1:] + o[:1], i[1:] + i[:1], i):
        border.append(prism([(x0, y0), (x1, y1), (x2, y2), (x3, y3)], 0.37, 0.39))
    for b in border:
        ctx.add("Reflective", b)
    ctx.wear("Reflective", lambda p: (0.95 * (0.8 + 0.2 * noise.fbm(p.co * 3, 2)), 0.74, 0.18))
    ctx.wear("PlasticDark", mul(lambda p: 0.85 + 0.15 * noise.fbm(p.co * 3, 2), cavity(0.35),
                                lambda p: 0.8 if p.normal.y > 0.6 else 1.0))
    ctx.wear("Black", mul(lambda p: 0.9 + 0.1 * noise.fbm(p.co * 4, 2),
                          lambda p: 1.25 if p.co.z < -0.95 and p.convex > 0.1 else 1.0))
    ctx.wear("Metal", lambda p: 0.75)


# ==============================================================================================
# PhoneBooth (+Smashed). Real reference: the US street payphone booth of the 70s-90s (Bell
# System / Western Electric aluminium booth): 0.8-1 m square, 2.2 m tall, four extruded
# aluminium corner posts, a painted back panel carrying the armoured payphone (stainless
# housing, 12-key pad, coin slot and return, the handset on a steel-sheathed cord) over a
# directory shelf with a binder on a chain, glass side panels on kickplates, a bi-fold door with
# vertical pull bars, a roof canopy whose three sides carry a lit PHONE sign band. Wear: tags
# and scratches on the glass, grime and gum on the kickplates, a sticker-covered phone, the
# Smashed one: a side pane gone (shards left in the frame and on the floor), the handset
# hanging, the door folded half open.
# City footprint (Props/Street): PhoneCollider 3 x 7.8 x 3 (the proxy), door side = the -Z
# side here; everything stays inside x, z within +-1.5 and y 0..7.8.
# ==============================================================================================
PB_W = 2.96  # outside width
PB_POST = 0.22
PB_ROOF0 = 7.18  # roof canopy bottom
PB_TOP = 7.78


def _pane(ctx, x0, x1, y0, y1, z, axis, glass=True, gone=False, rng=None):
    """One side of the booth between two posts: kickplate, frame rails, a mid rail, the glass
    (or its shards if gone). axis "x": the pane spans X at depth z; "z": spans Z at x = z."""
    def put(layer, bm, cx, cy, sx, sy, sz):
        if axis == "x":
            ctx.add(layer, bm(sx, sy, sz), T(cx, cy, z))
        else:
            ctx.add(layer, bm(sz, sy, sx), T(z, cy, cx))

    def rb(r):
        return lambda sx, sy, sz: rbox(sx, sy, sz, r=r, m=1)

    w = x1 - x0
    cx = (x0 + x1) / 2
    put("MetalPainted", rb(0.02), cx, y0 + 0.4, w, 0.8, 0.08)  # kickplate
    for yy, hh in ((y0 + 0.84, 0.1), (y0 + 3.3, 0.12), (y1 - 0.06, 0.12)):
        put("Metal", rb(0.025), cx, yy, w, hh, 0.13)  # rails
    if not glass:
        return
    if not gone:
        return  # (the glass itself is the city's PhoneGlass part, kept: transparent, as CityGlass dresses it)
    # shards left in the frame: jagged triangles along the rails and posts
    edges = [(y0 + 0.89, 1), (y0 + 3.24, -1), (y0 + 3.36, 1), (y1 - 0.12, -1)]
    for ye, sgn in edges:
        x = x0 + 0.02
        while x < x1 - 0.1:
            ww = rng.uniform(0.12, 0.35)
            hh = rng.uniform(0.08, 0.4) * (0.4 if rng.random() < 0.5 else 1)
            xt = x + ww * rng.uniform(0.2, 0.8)
            tri = [(x, ye), (min(x + ww, x1 - 0.02), ye), (xt, ye + sgn * hh)]
            if sgn < 0:
                tri = [tri[1], tri[0], tri[2]]
            bm = prism(tri, -0.02, 0.02)
            if axis == "x":
                ctx.add("Glass", bm, T(0, 0, z))
            else:
                ctx.add("Glass", bm, T(z, 0, 0) @ R(0, -90, 0))
            x += ww + rng.uniform(0.0, 0.15)


def _phone_booth(ctx, smashed):
    noise, rng = ctx.noise, ctx.rng
    h = PB_W / 2 - PB_POST / 2  # post centre offset
    # base plinth (a cast step), the floor plate inside it
    ctx.add("MetalPainted", rbox(PB_W, 0.24, PB_W, r=0.04, m=1, n=(3, 1, 3)), T(0, 0.11, 0))
    ctx.add("Metal", rbox(PB_W - 0.5, 0.03, PB_W - 0.5, r=0.01, m=1, n=(3, 1, 3)), T(0, 0.24, 0))  # diamond floor
    # corner posts (extruded aluminium, rounded)
    for sx in (-1, 1):
        for sz in (-1, 1):
            ctx.add("Metal", rbox(PB_POST, PB_ROOF0 - 0.22, PB_POST, r=0.05, m=1, n=(1, 4, 1)), T(sx * h, (PB_ROOF0 + 0.22) / 2, sz * h))
    y0, y1 = 0.22, PB_ROOF0
    # back panel (+Z): painted sheet, the phone on it
    ctx.add("MetalPainted", rbox(PB_W - 2 * PB_POST, y1 - y0, 0.08, r=0.02, m=1, n=(2, 6, 1)), T(0, (y0 + y1) / 2, h + 0.02))
    # sides (+-X): glass on kickplates; the smashed booth lost its left (-X) pane
    _pane(ctx, -h + PB_POST / 2, h - PB_POST / 2, y0, y1, -h, "z", gone=smashed, rng=rng)
    _pane(ctx, -h + PB_POST / 2, h - PB_POST / 2, y0, y1, h, "z")
    # front (-Z): a bi-fold door, two leaves; the smashed one folded half open
    leaf_w = (2 * h - PB_POST) / 2
    for k, s in enumerate((-1, 1)):
        hinge_x = s * (h - PB_POST / 2)
        ang = 3 * (1 if k == 0 else -1)
        ctx_m = T(hinge_x, 0, -h) @ R(0, ang, 0)
        bm_parts = []
        x0, x1 = (0, leaf_w) if s < 0 else (-leaf_w, 0)
        cx = (x0 + x1) / 2
        bm_parts.append(("MetalPainted", rbox(leaf_w - 0.02, 0.78, 0.07, r=0.02, m=1), (cx, y0 + 0.42, 0)))
        bm_parts.append(("Metal", rbox(leaf_w, 0.1, 0.11, r=0.025, m=1), (cx, y0 + 0.84, 0)))
        bm_parts.append(("Metal", rbox(leaf_w, 0.12, 0.11, r=0.025, m=1), (cx, y1 - 0.08, 0)))
        bm_parts.append(("Metal", rbox(0.1, y1 - y0 - 0.1, 0.11, r=0.025, m=1), (x0 + 0.05 if s < 0 else x1 - 0.05, (y0 + y1) / 2, 0)))
        bm_parts.append(("Metal", rbox(0.1, y1 - y0 - 0.1, 0.11, r=0.025, m=1), (x1 - 0.05 if s < 0 else x0 + 0.05, (y0 + y1) / 2, 0)))
        xb = x1 - 0.18 if s < 0 else x0 + 0.18  # the pull bar near the leaves' meeting edge
        bar = fillet_path([(xb, 2.6, -0.06), (xb, 2.6, -0.2), (xb, 4.6, -0.2), (xb, 4.6, -0.06)], 0.08, 4)
        bm_parts.append(("Chrome", tube(bar, 0.035, segs=8), (0, 0, 0)))
        for layer, bm, (px, py, pz) in bm_parts:
            ctx.add(layer, bm, ctx_m @ T(px, py, pz))
    # roof canopy: a painted box with a lit-look sign band on three sides, raised letters
    ctx.add("MetalPainted", rbox(PB_W, PB_TOP - PB_ROOF0 - 0.06, PB_W, r=0.05, m=2), T(0, (PB_ROOF0 + PB_TOP - 0.06) / 2, 0))
    ctx.add("MetalPainted", rbox(PB_W - 0.3, 0.06, PB_W - 0.3, r=0.03, m=1), T(0, PB_TOP - 0.035, 0))  # cap
    yb = (PB_ROOF0 + PB_TOP - 0.06) / 2
    for ry in (0, 90, -90):
        m = R(0, ry, 0)
        ctx.add("Paper", rbox(2.3, 0.4, 0.04, r=0.01, m=1), m @ T(0, yb, -PB_W / 2 - 0.005))
        ctx.add("Black", text_bm("PHONE", 0.36, 0.025), m @ T(0, yb - 0.01, -PB_W / 2 - 0.03) @ R(0, 180, 0))
    # ---- inside: the payphone on the back wall, facing -Z
    zp = h - 0.02 - 0.04  # back panel's inner face
    ph = T(0.15, 4.45, zp)
    ctx.add("Metal", rbox(0.78, 1.5, 0.36, r=0.05, m=2), ph @ T(0, 0, -0.18))  # housing
    ctx.add("Metal", rbox(0.7, 0.2, 0.3, r=0.04, m=1), ph @ T(0, 0.85, -0.17))  # top hood
    for kx in range(3):
        for ky in range(4):
            ctx.add("Chrome", box(0.11, 0.09, 0.04, bevel=0.012, segments=1), ph @ T(-0.14 + 0.13 * kx, 0.12 - 0.12 * ky, -0.37))
    ctx.add("Black", rbox(0.4, 0.16, 0.02, r=0.006, m=1), ph @ T(0.0, 0.46, -0.365))  # display / instructions
    ctx.add("Black", rbox(0.18, 0.03, 0.02, r=0.006, m=1), ph @ T(0.24, 0.3, -0.37))  # coin slot
    ctx.add("Black", rbox(0.2, 0.14, 0.05, r=0.01, m=1), ph @ T(0.2, -0.6, -0.355))  # coin return
    ctx.add("Metal", rbox(0.12, 0.62, 0.14, r=0.03, m=1), ph @ T(-0.48, 0.05, -0.18))  # the cradle hook
    if smashed:  # the handset hangs on its cord to the floor
        hs = (-0.55, 1.5, zp - 0.35)
        cord = spline([(-0.45, 3.95, zp - 0.15), (-0.52, 3.0, zp - 0.3), hs], 5)
        hand = T(*hs) @ R(12, 0, 8)
    else:
        cord = spline([(-0.48, 3.95, zp - 0.2), (-0.5, 3.4, zp - 0.3), (-0.42, 3.15, zp - 0.3), (-0.38, 3.55, zp - 0.24),
                       (-0.33, 4.1, zp - 0.3)], 4)
        hand = ph @ T(-0.62, 0.05, -0.22)
    ctx.add("Metal", tube(cord, 0.03, segs=6))
    hb = []
    hb.append(rbox(0.14, 0.62, 0.12, r=0.05, m=1))
    ctx.add("PlasticDark", hb[0], hand)
    for sy in (-1, 1):
        ctx.add("PlasticDark", rbox(0.2, 0.2, 0.18, r=0.07, m=1), hand @ T(0.0, sy * 0.36, -0.03))
    # directory shelf and a binder hanging on its chain
    ctx.add("MetalPainted", rbox(1.6, 0.08, 0.55, r=0.025, m=1), T(0.1, 3.05, zp - 0.28))
    ctx.add("Black", rbox(0.9, 0.12, 0.5, r=0.03, m=1), T(0.2, 3.15, zp - 0.3) @ R(0, 6, 0))
    ctx.add("Metal", tube(spline([(-0.25, 3.13, zp - 0.3), (-0.4, 2.85, zp - 0.2), (-0.45, 3.04, zp - 0.06)], 3), 0.012, segs=4))
    # floor junk: cigarette ends, a cup (the smashed booth: glass shards)
    if smashed:
        for k in range(16):
            x = rng.uniform(-1.6, -0.9) if k < 10 else rng.uniform(-1.3, 0.6)
            zz = rng.uniform(-1.1, 1.1)
            sz = rng.uniform(0.06, 0.2)
            tri = [(0, 0), (sz, rng.uniform(-0.03, 0.03)), (sz * rng.uniform(0.2, 0.8), sz * rng.uniform(0.5, 1.0))]
            y = 0.012 if x < -1.5 else 0.272
            ctx.add("Glass", prism(tri, 0, 0.012), T(x, y, zz) @ R(90, rng.uniform(0, 360), 0))
    # wear
    pf = paint_wear(noise, dirt_h=1.4, dirt=0.4, rust_y=0.5 if smashed else 0.25, streak=0.2)
    ctx.wear("MetalPainted", pf)
    ctx.wear("Metal", mul(lambda p: 0.72 + 0.22 * noise.fbm(p.co * 5, 2), ground_dirt(1.2, 0.3, noise), cavity(0.35)))
    ctx.wear("Glass", lambda p: 0.75 * (1 - 0.35 * smoothstep(0.35, 0.8, noise.ridge(Vector((p.co.x * 3, p.co.y * 1.2, p.co.z * 3)) * 1.0))))
    ctx.wear("Paper", lambda p: (0.95, 0.9, 0.78) if not smashed else (0.75, 0.7, 0.6))
    ctx.wear("Chrome", lambda p: 0.7 + 0.2 * noise.fbm(p.co * 4, 2))
    ctx.wear("PlasticDark", lambda p: 0.85)
    ctx.wear("Black", lambda p: 0.9)


def phone_booth(ctx):
    """Street payphone booth: aluminium posts, kickplates and rails (the glass is the city's
    kept PhoneGlass parts), bi-fold door, armoured payphone over a directory shelf, PHONE sign
    band in raised letters round the canopy."""
    ctx.budget = 7500
    ctx.tint("MetalPainted", (52, 60, 72))
    _phone_booth(ctx, False)


def phone_booth_smashed(ctx):
    """The same booth vandalised: a side pane smashed (shards in the frame and on the floor),
    the handset hanging on its cord, rust on the kickplates."""
    ctx.budget = 8000
    ctx.tint("MetalPainted", (60, 48, 46))
    _phone_booth(ctx, True)


# ==============================================================================================
# FireHydrant (+Worn). Real reference: a US dry-barrel pillar hydrant (Mueller / Kennedy / AVK
# type), 0.75-0.85 m over the pavement: a breakaway ground flange with its bolt ring, the cast
# barrel, the nozzle section with two 2.5-inch hose outlets (left, right) and one 4.5-inch
# pumper outlet (front), each under a cap with a pentagon nut and a short chain to the barrel,
# the bonnet flange with six bolts, the domed bonnet and the pentagon operating nut on top.
# Paint: red or chrome yellow, chalky; the worn one: paint flaked to rust on the caps and the
# flange, a side cap gone (the bare thread and the dark bore), the chain hanging, the whole
# hydrant tipped a few degrees by a bumper.
# City footprint (Props/Street): Hydrant 0.9 across, 2.2 tall + cap to 2.5 over the ground,
# side nozzles to +-0.8 (no collision: the old parts are pure decoration).
# ==============================================================================================
HY_PROF = [(0.0, 0.0), (0.6, 0.0), (0.62, 0.04), (0.62, 0.11), (0.58, 0.14), (0.44, 0.16), (0.41, 0.2),
           (0.4, 0.5), (0.395, 0.9), (0.4, 1.3), (0.43, 1.36), (0.46, 1.42), (0.46, 1.82), (0.53, 1.84),
           (0.56, 1.87), (0.56, 1.95), (0.52, 1.98), (0.47, 2.02), (0.42, 2.13), (0.33, 2.24), (0.2, 2.31),
           (0.14, 2.34), (0.0, 2.34)]


def _hy_nozzle(ctx, layer, cap_layer, r, out, y, ang, cap=True):
    """An outlet along the horizontal direction `ang` (0 = +X, pi/2 = +Z): a boss out of the
    barrel, a thread ring, a cap with a pentagon nut (or, capless, a bare bore)."""
    m = T(0, y, 0) @ R(0, -math.degrees(ang), 0) @ R(0, 0, -90)  # (the lathe's +Y along `ang`)
    boss = lathe([(0.0, 0.25), (r * 1.18, 0.25), (r * 1.12, 0.35), (r, 0.38), (r, out - 0.06), (r * 1.08, out - 0.04),
                  (r * 1.08, out), (0.0, out)], segs=12)
    ctx.add(layer, boss, m)
    if cap:
        capm = lathe([(0.0, out - 0.01), (r * 1.18, out - 0.01), (r * 1.2, out + 0.02), (r * 1.2, out + 0.11),
                      (r * 1.12, out + 0.13), (0.0, out + 0.13)], segs=12)
        ctx.add(cap_layer, capm, m)
        ctx.add(cap_layer, cyl(r * 0.55, 0.09, segs=5), m @ T(0, out + 0.17, 0))  # pentagon nut
        for k in range(4):  # (lugs round the cap)
            a = TAU * k / 4 + 0.4
            ctx.add(cap_layer, box(0.05, 0.09, 0.05, bevel=0.012, segments=1), m @ T(r * 1.22 * math.cos(a), out + 0.06, r * 1.22 * math.sin(a)))
    else:
        ctx.add("Black", cyl(r * 0.78, 0.06, segs=16), m @ T(0, out - 0.02, 0))  # the dark bore


def _hydrant(ctx, worn):
    noise, rng = ctx.noise, ctx.rng

    def shape(a, r, y):
        d = 0.0
        if worn:  # (a bumper's dent low on the front)
            d -= 0.03 * math.exp(-((y - 0.7) / 0.25) ** 2) * max(0.0, math.cos(a + math.pi / 2)) ** 4
        return r + d

    ctx.add("MetalPainted", lathe(HY_PROF, segs=18, radius_fn=shape))
    # ground flange bolts (8) and bonnet flange bolts (6)
    ring_bolts(ctx, "Rust" if worn else "Metal", 6, 0.52, 0.11, r=0.045, h=0.05, a0=0.2)
    ring_bolts(ctx, "MetalPainted", 6, 0.5, 1.95, r=0.04, h=0.045, a0=0.5, stud=False)
    # operating nut on top (pentagon) with its weather shield
    ctx.add("MetalPainted", cyl(0.16, 0.05, segs=16, bevel=0.015), T(0, 2.355, 0))
    ctx.add("Metal" if worn else "MetalPainted", cyl(0.11, 0.13, segs=5, bevel=0.01), T(0, 2.44, 0))
    # outlets: two hose outlets (sides), the pumper (front)
    cap_layer = "Rust" if worn else "MetalPainted"
    _hy_nozzle(ctx, "MetalPainted", cap_layer, 0.14, 0.62, 1.62, 0.0, cap=True)
    _hy_nozzle(ctx, "MetalPainted", cap_layer, 0.14, 0.62, 1.62, math.pi, cap=not worn)
    _hy_nozzle(ctx, "MetalPainted", "MetalPainted", 0.22, 0.6, 1.6, -math.pi / 2, cap=True)
    # chains: from each cap down to a lug on the barrel
    for ang, hang in ((0.0, 0.0), (math.pi, 0.35 if worn else 0.0), (-math.pi / 2, 0.0)):
        ca, sa = math.cos(ang), math.sin(ang)
        tx, tz = -sa, ca  # (to the side of the outlet)
        start = (ca * 0.68 + tx * 0.16, 1.5, sa * 0.68 + tz * 0.16)
        end = (ca * 0.46 + tx * 0.3, 1.5 - hang, sa * 0.46 + tz * 0.3)
        mid = ((start[0] + end[0]) / 2, 1.38 - hang, (start[2] + end[2]) / 2)
        pts = spline([start, mid, end], 4)
        ctx.add(cap_layer if worn else "Metal", tube(pts, 0.018, segs=5))
    if worn:
        tilt = R(2.5, 0, -1.5)
        for layer, bm in list(ctx.layers.items()):
            bmesh.ops.transform(bm, matrix=tilt, verts=bm.verts)

    def paint(p):
        x, y, z = p.co
        k = 0.85 + 0.15 * noise.fbm(p.co * 4, 2)
        k *= 1 - 0.35 * (1 - smoothstep(0.0, 0.5, y))  # (gutter grime)
        k *= 1 - 0.3 * smoothstep(0.0, 0.5, -p.convex)
        c = (k, k, k)
        # chalky faded top, flaked paint (rust-brown) where the noise peaks
        if p.normal.y > 0.5:
            c = (c[0] * 1.0, c[1] * 1.08, c[2] * 1.1)
        f = smoothstep(0.25 if worn else 0.5, 0.6 if worn else 0.75, noise.fbm(p.co * (5 if worn else 3), 3) * 0.5 + 0.5)
        if worn:
            f = max(f, (1 - smoothstep(0.1, 0.4, y)) * 0.8)
        rust = (0.62, 0.42, 0.36)
        return tuple(a * lerp(1, b, f) for a, b in zip(c, rust))

    ctx.wear("MetalPainted", paint)
    ctx.wear("Metal", mul(lambda p: (0.8, 0.68, 0.56), cavity(0.3)))
    ctx.wear("Rust", mul(lambda p: 0.7 + 0.3 * noise.fbm(p.co * 9, 2), cavity(0.3)))
    ctx.wear("Black", lambda p: 0.7)


def fire_hydrant(ctx):
    """Pillar fire hydrant 0.7 m: ground flange with 6 bolts, two hose outlets and a pumper
    outlet with chained caps, bonnet flange, domed bonnet, pentagon operating nut."""
    ctx.budget = 3500
    ctx.tint("MetalPainted", (128, 34, 28))
    _hydrant(ctx, False)


def fire_hydrant_worn(ctx):
    """The same hydrant knocked and neglected: paint flaked to rust, rusty caps and flange bolts,
    one hose cap gone (bare bore, chain hanging), a dent, tipped a few degrees."""
    ctx.budget = 3500
    ctx.tint("MetalPainted", (150, 120, 40))
    _hydrant(ctx, True)


# ==============================================================================================
# JerseyBarrier (+Chipped). Real reference: the precast New Jersey shape concrete barrier:
# 0.81 m tall, 0.61 m wide at the base, 0.15 m at the top, a 75 mm vertical reveal at the
# foot, then a 55-degree slope up to 0.33 m, then an 84-degree face to the top; 3-6 m long,
# with drainage / forklift slots through the foot, steel pin-and-loop connectors on the ends,
# lifting loops of rebar on top. Wear: chipped arrises, a broken corner with rebar showing,
# tyre rubber on the foot, stencilled number, a red / white reflector, grime.
# City footprint (Props/Barricades): JerseyBarrier 8 x 3.2 x 1.6 (collides: the proxy). Here
# the length runs along X, the height is the city's 3.2, the base 1.96 wide (0.18 out of the
# proxy each side: the real shape's flare), the top 1.0 (0.3 inside it: the NJ top is narrower
# still, but the mesh must stay within ~0.3 of the box players collide with).
# ==============================================================================================
JB_L = 8.0
JB_H = 3.2


def _jb_half(y):
    """The barrier's half-width at height y (the New Jersey profile, studs)."""
    if y <= 0.26:
        return 0.98
    if y <= 1.25:
        return lerp(0.98, 0.62, (y - 0.26) / 0.99)
    return lerp(0.62, 0.5, (y - 1.25) / (JB_H - 1.25))


def _jb_section(y0):
    """The closed cross-section (z, y) from y0 up (rounded top)."""
    ys = [y0] + [y for y in (0.26, 1.25, 2.2) if y > y0 + 0.01] + [JB_H - 0.08]
    right = [(_jb_half(y), y) for y in ys]
    top = [(0.5 - 0.08 + 0.08 * math.cos(a), JB_H - 0.08 + 0.08 * math.sin(a)) for a in (math.radians(d) for d in (30, 60, 90))]
    top_l = [(-z, y) for z, y in reversed(top)]
    left = [(-z, y) for z, y in reversed(right)]
    return right + top + top_l[1:] + left


def _jersey(ctx, chipped):
    noise, rng = ctx.noise, ctx.rng
    slots = (-2.6, 2.6)
    sw = 0.9  # slot width
    # blocks between the slots (full section) and over them (section from the slot's top)
    cuts = [-JB_L / 2, slots[0] - sw / 2, slots[0] + sw / 2, slots[1] - sw / 2, slots[1] + sw / 2, JB_L / 2]
    for k in range(len(cuts) - 1):
        x0, x1 = cuts[k], cuts[k + 1]
        over = k in (1, 3)
        sec = _jb_section(0.38 if over else 0.0)
        segs = 2 if over else max(2, int((x1 - x0) / 0.5))
        if chipped and k == 4:
            segs = 8
        bm = prism([(z, y) for z, y in sec], x0, x1, segs=segs)
        bmesh.ops.transform(bm, matrix=R(0, -90, 0), verts=bm.verts)  # (extrusion along X)
        # (the prism's ends share planes with the neighbours: pull the over-slot block 0.002 in)
        ctx.add("Concrete", bm)
    # chips along the top arrises and the ends (vertices pushed in where the noise is high)
    conc = ctx.layers["Concrete"]
    bmesh.ops.remove_doubles(conc, verts=conc.verts, dist=1e-4)
    cut_n = Vector((0.62, 0.62, 0.48)).normalized()
    cut_at = Vector((JB_L / 2 - 0.55, JB_H - 0.75, 0.0))
    for v in conc.verts:
        x, y, z = v.co
        hw = _jb_half(y)
        edge = abs(abs(z) - hw) < 0.02 and (y > JB_H - 0.3 or abs(abs(x) - JB_L / 2) < 0.02)
        n = noise.fbm(v.co * 2.5, 2)
        if edge and n > 0.15:
            v.co.y -= 0.05 * (n - 0.15) * 4 * (1 if y > JB_H - 0.3 else 0)
            v.co.z -= math.copysign(0.05 * (n - 0.15) * 4, z)
        if chipped:  # a whole corner broken away at the +X end: everything past a rough plane
            d = v.co - cut_at
            depth = d.dot(cut_n)
            if depth > 0:
                v.co -= cut_n * depth
                v.co += cut_n * 0.06 * noise.fbm(v.co * 3.0, 2)
    # lifting loops of rebar on top, pin-and-loop connectors on each end
    for x in (-2.4, 2.4):
        if chipped and x > 0:
            continue
        loop = fillet_path([(x - 0.3, JB_H - 0.15, 0), (x - 0.3, JB_H + 0.25, 0), (x + 0.3, JB_H + 0.25, 0),
                            (x + 0.3, JB_H - 0.15, 0)], 0.15, 4)
        ctx.add("Rust", tube(loop, 0.04, segs=6))
    for sx in (-1, 1):
        if chipped and sx > 0:
            continue
        for y in (0.9, 2.3):
            loop = fillet_path([(sx * (JB_L / 2 - 0.12), y - 0.22, 0), (sx * (JB_L / 2 + 0.16), y - 0.22, 0),
                                (sx * (JB_L / 2 + 0.16), y + 0.22, 0), (sx * (JB_L / 2 - 0.12), y + 0.22, 0)], 0.12, 3)
            ctx.add("Rust", tube(loop, 0.045, segs=6))
    if chipped:  # bent rebar ends sticking out of the broken corner
        for k, (y, z) in enumerate(((2.5, 0.18), (2.85, -0.05), (2.2, 0.32))):
            p0 = (JB_L / 2 - 0.75, y, z)
            pts = spline([p0, (JB_L / 2 - 0.25, y + 0.05, z + 0.05 * k), (JB_L / 2 + 0.05, y + 0.25 - 0.1 * k, z + 0.12)], 3)
            ctx.add("Rust", tube(pts, 0.035, segs=5))
    # red / white reflector plates on both steep faces near the -X end
    for sz in (-1, 1):
        y = 2.55
        hw = _jb_half(y) + 0.012
        tilt = math.degrees(math.atan2(0.12, JB_H - 1.25)) * sz
        for k, xo in enumerate((-0.28, 0.28)):
            ctx.add("Reflective", rbox(0.5, 0.6, 0.03, r=0.01, m=1), T(-2.3 + xo, y, sz * hw) @ R(tilt, 0, 0))
        ctx.wear("Reflective", lambda p: (1.0, 0.35, 0.35) if p.co.x < -2.3 else (0.95, 0.95, 0.9))
    # stencilled number on the +Z steep face (paint, a hair proud)
    num = text_bm("MD 41" if not chipped else "MD 17", 0.42, 0.006)
    y = 1.85
    hw = _jb_half(y) + 0.006
    tilt = math.degrees(math.atan2(0.12, JB_H - 1.25))
    ctx.add("Paper", num, T(0.8, y, hw) @ R(tilt, 0, 0))

    def conc_wear(p):
        x, y, z = p.co
        k = 0.82 + 0.18 * noise.fbm(p.co * 1.5, 3)
        k *= 1 - 0.38 * (1 - smoothstep(0.0, 0.7 + 0.3 * noise.fbm(p.co, 2, 1.5), y))  # road grime, tyre rubber
        k *= 1 - 0.25 * smoothstep(0.0, 0.5, -p.convex)
        k *= 1 + 0.12 * smoothstep(0.05, 0.5, p.convex)  # chipped arrises paler
        k *= 1 - 0.2 * smoothstep(0.2, 0.7, noise.fbm(Vector((x * 4, y * 0.6, z * 4)), 2))  # rain streaks
        if chipped and x > JB_L / 2 - 1.2 and y > 1.8:
            k *= 1.08  # (fresh break: paler)
        return (k, k * 0.98, k * 0.94)

    ctx.wear("Concrete", conc_wear)
    ctx.wear("Rust", mul(lambda p: 0.7 + 0.3 * noise.fbm(p.co * 8, 2), cavity(0.3)))
    ctx.wear("Paper", lambda p: (0.95, 0.92, 0.75 if chipped else 0.9))


def jersey_barrier(ctx):
    """Precast New Jersey concrete barrier 3.2 tall, 8 long: the stepped profile, drainage slots,
    rebar lifting loops, pin-and-loop end connectors, red / white reflectors, stencilled number."""
    ctx.budget = 3000
    ctx.smooth_angle = 22
    _jersey(ctx, False)


def jersey_barrier_chipped(ctx):
    """The same barrier with a corner smashed off one end (rusty rebar ends sticking out of the
    break), chipped arrises."""
    ctx.budget = 3000
    ctx.smooth_angle = 22
    _jersey(ctx, True)


# ==============================================================================================
# NewsKiosk + MagazineRack + NewspaperBundle. Real reference: a steel street news kiosk
# (newsstand) 1.7 m deep, 2.2 m tall, 1.1 m... here the city's 4 x 7.6 x 6 box: standing-seam
# sheet-steel walls on a plinth, a canopy roof with a rolled edge and a gutter over the serving
# hatch, the roll-shutter box over the hatch with its guide rails, a counter ledge on brackets,
# inside: a fluorescent tube, shelves of cigarette cartons and sweets, a till; on the sides
# newspaper headline poster frames (the "bill" boards), under the counter a wire magazine rack;
# bundles of the day's papers strapped on the pavement. Wear: grime and rust along the plinth,
# stickers and fly posters, chalky paint on the roof.
# City footprint (Props/Kiosk): Kiosk 4 deep x 7.6 x 6 wide, KioskRoof 5 x 0.5 x 7 over it (1.0
# out over the hatch side), KioskCounter 0.9 x 0.4 x 5.2 (all three collide: proxies), the
# hatch (CityShopLight + its light: handed to the tube's Glow), the roof sign (KioskSign, kept:
# its text is a lit neon) standing on the roof's front edge. Here: hatch side = -Z, width
# along X (6), depth along Z (4), origin = the footprint's centre on the ground.
# ==============================================================================================
KI_W, KI_D, KI_H = 6.0, 4.0, 7.6
KI_HATCH = (2.4, 3.3, 6.6)  # half width, bottom (counter top), top
KI_RECESS = 0.85


def news_kiosk(ctx):
    """Steel news kiosk: standing-seam walls on a plinth, canopy roof with rolled edge and
    gutter, roll-shutter box and rails over the serving hatch, counter ledge, a lit interior
    (fluorescent tube Glow + Light marker, shelves of cartons, till), headline poster frames."""
    ctx.budget = 8000
    ctx.tint("MetalPainted", (38, 62, 50))
    noise, rng = ctx.noise, ctx.rng
    hw, hd = KI_W / 2, KI_D / 2
    hx, hy0, hy1 = KI_HATCH
    zr = -hd + KI_RECESS  # the recess back wall
    # plinth (a darker steel skirt, a hair inside the walls' footprint)
    ctx.add("PlasticDark", rbox(KI_W - 0.04, 0.32, KI_D - 0.04, r=0.03, m=1, n=(4, 1, 3)), T(0, 0.16, 0))
    # walls: back, two sides (full), front: under the hatch, over it, the two jambs
    t = 0.12
    walls = [
        ((0, (0.32 + KI_H) / 2, hd - t / 2), (KI_W, KI_H - 0.32, t)),
        ((-hw + t / 2, (0.32 + KI_H) / 2, 0), (t, KI_H - 0.32, KI_D - 2 * t)),
        ((hw - t / 2, (0.32 + KI_H) / 2, 0), (t, KI_H - 0.32, KI_D - 2 * t)),
        ((0, (0.32 + hy0) / 2, -hd + t / 2), (KI_W, hy0 - 0.32, t)),
        ((0, (hy1 + KI_H) / 2, -hd + t / 2), (KI_W, KI_H - hy1, t)),
        ((-(hw + hx) / 2, (hy0 + hy1) / 2, -hd + t / 2), (hw - hx, hy1 - hy0, t)),
        ((+(hw + hx) / 2, (hy0 + hy1) / 2, -hd + t / 2), (hw - hx, hy1 - hy0, t)),
    ]
    for (x, y, z), (sx, sy, sz) in walls:
        ctx.add("MetalPainted", rbox(sx, sy, sz, r=0.02, m=1, n=(max(1, int(sx / 3)), max(1, int(sy / 2.5)), 1)),
                T(x, y, z))
    # standing seams (vertical ribs) on the back and the sides
    for k in range(9):
        x = -hw + 0.6 + 0.6 * k
        ctx.add("MetalPainted", box(0.05, KI_H - 0.5, 0.05, bevel=0.012, segments=1), T(x, (0.4 + KI_H - 0.1) / 2, hd + 0.015))
    for sx in (-1, 1):
        for k in range(5):
            z = -hd + 0.6 + 0.6 * k
            ctx.add("MetalPainted", box(0.05, KI_H - 0.5, 0.05, bevel=0.012, segments=1), T(sx * (hw + 0.015), (0.4 + KI_H - 0.1) / 2, z))
    # the hatch recess: lining (dark), shelves with cartons, the tube light, a till
    ctx.add("PlasticDark", rbox(2 * hx, hy1 - hy0, 0.06, r=0.01, m=1, n=(3, 2, 1)), T(0, (hy0 + hy1) / 2, zr + 0.03))
    for sx in (-1, 1):
        ctx.add("PlasticDark", rbox(0.06, hy1 - hy0, KI_RECESS - t, r=0.01, m=1), T(sx * (hx - 0.03), (hy0 + hy1) / 2, (zr - hd + t) / 2))
    ctx.add("PlasticDark", rbox(2 * hx, 0.06, KI_RECESS - t, r=0.01, m=1), T(0, hy1 - 0.03, (zr - hd + t) / 2))
    ctx.add("WoodDark", rbox(2 * hx, 0.08, KI_RECESS - t + 0.02, r=0.02, m=1), T(0, hy0 + 0.04, (zr - hd + t) / 2))  # inner sill
    colours = [(1.0, 0.36, 0.35), (0.98, 0.96, 0.9), (0.36, 0.45, 0.95), (1.0, 0.8, 0.36), (0.4, 0.75, 0.5),
               (0.8, 0.4, 0.7), (0.95, 0.95, 0.95), (0.9, 0.5, 0.36)]
    cart_cols = []
    for ys in (hy0 + 1.15, hy0 + 2.15):
        ctx.add("WoodDark", rbox(2 * hx - 0.1, 0.07, 0.42, r=0.02, m=1), T(0, ys, zr - 0.21))
        x = -hx + 0.12
        while x < hx - 0.45:
            w = rng.uniform(0.42, 0.62)
            h = rng.uniform(0.42, 0.6)
            ctx.add("Paper", box(w - 0.03, h, 0.3, bevel=0.015, segments=1), T(x + w / 2, ys + 0.035 + h / 2, zr - 0.2))
            cart_cols.append(((x, x + w), colours[rng.randrange(len(colours))]))
            x += w
    ctx.add("PlasticDark", rbox(0.9, 0.42, 0.6, r=0.05, m=1), T(-1.3, hy0 + 0.29, zr - 0.38))  # till
    ctx.add("Black", rbox(0.5, 0.25, 0.04, r=0.01, m=1), T(-1.3, hy0 + 0.62, zr - 0.3) @ R(-20, 0, 0))  # its display
    ctx.add("Glow", cyl(0.07, 2 * hx - 0.6, segs=8), T(0, hy1 - 0.16, -hd + 0.28) @ R(0, 0, 90))  # fluorescent tube
    ctx.add("Metal", box(2 * hx - 0.4, 0.06, 0.2, bevel=0.015, segments=1), T(0, hy1 - 0.06, -hd + 0.28))  # its batten
    ctx.mark("Light", (0, hy1 - 0.3, -hd + 0.1))
    # roll-shutter box over the hatch, guide rails down its sides
    ctx.add("MetalPainted", rbox(2 * hx + 0.4, 0.62, 0.42, r=0.12, m=2, n=(4, 1, 1)), T(0, hy1 + 0.36, -hd - 0.2))
    for sx in (-1, 1):
        ctx.add("Metal", rbox(0.12, hy1 - hy0 + 0.05, 0.14, r=0.02, m=1), T(sx * (hx + 0.07), (hy0 + hy1) / 2, -hd - 0.06))
        ctx.add("Metal", cyl(0.05, 0.05, segs=8), T(sx * (hx + 0.07), hy0 + 0.05, -hd - 0.13) @ R(90, 0, 0))  # padlock eye
    # counter ledge on two brackets
    ctx.add("WoodDark", rbox(5.2, 0.12, 0.9, r=0.03, m=1, n=(4, 1, 1)), T(0, hy0 - 0.06, -hd - 0.45))
    ctx.add("MetalPainted", rbox(5.3, 0.26, 0.08, r=0.02, m=1), T(0, hy0 - 0.25, -hd - 0.04))  # its rail
    for sx in (-1.9, 1.9):
        br = prism([(0, 0), (0.82, 0), (0, -0.7)], -0.04, 0.04)
        ctx.add("MetalPainted", br, T(sx, hy0 - 0.12, -hd - 0.02) @ R(0, 90, 0))
    # canopy roof: a slab sloping back, rolled edge round three sides, a gutter at the back
    rz0, rz1 = -hd - 1.0, hd  # (front .. back)
    roof = prism([(-3.5, 0.0), (3.5, 0.0), (3.5, 0.5), (-3.5, 0.5)], rz0, rz1, segs=3)
    for v in roof.verts:
        if v.co.y > 0.25:
            v.co.y += 0.02 - 0.05 * (v.co.z - rz0) / (rz1 - rz0)  # (falls to the back gutter)
    ctx.add("MetalPainted", roof, T(0, KI_H, 0))
    edge = [(-3.5, KI_H + 0.42, rz1 - 0.1), (-3.5, KI_H + 0.42, rz0), (3.5, KI_H + 0.42, rz0), (3.5, KI_H + 0.42, rz1 - 0.1)]
    ctx.add("MetalPainted", tube(fillet_path(edge, 0.12, 3), 0.1, segs=8))
    gut = prism([(-0.12, 0.12), (-0.1, -0.08), (0.1, -0.08), (0.14, 0.14), (0.11, 0.14), (0.08, -0.05), (-0.07, -0.05), (-0.09, 0.12)], -3.5, 3.5)
    ctx.add("Metal", gut, T(0, KI_H + 0.33, rz1 + 0.12) @ R(0, 90, 0))
    # brackets behind the roof sign (the city's KioskSign stands on the roof's front edge)
    for sx in (-2.6, 0.0, 2.6):
        ctx.add("Metal", box(0.08, 0.8, 0.5, bevel=0.015, segments=1), T(sx, KI_H + 0.5 + 0.4, rz0 + 0.45))
    # headline poster frames on both sides (the old Headline boards' places)
    for sx in (-1, 1):
        xf = sx * (hw + 0.07)
        zc = -0.2
        ctx.add("Metal", rbox(0.06, 4.0, 2.4, r=0.025, m=1), T(xf, 3.4, zc))
        ctx.add("Paper", rbox(0.03, 3.7, 2.15, r=0.01, m=1), T(xf + sx * 0.03, 3.4, zc))
        lines = (("BODY FOUND", "IN THE DOCKS"), ("STRIKE!", "CITY SHUTS DOWN"))[0 if sx < 0 else 1]
        for k, (txt, size, yy) in enumerate(((lines[0], 0.42, 4.55), (lines[1], 0.3, 3.95))):
            bm = text_bm(txt, size, 0.012, res=1)
            lo = min(v.co.x for v in bm.verts)
            hi = max(v.co.x for v in bm.verts)
            fit = min(1.0, 1.95 / max(hi - lo, 1e-3))
            bmesh.ops.scale(bm, vec=(fit, fit, 1.0), verts=bm.verts)
            ctx.add("Black", bm, T(xf + sx * 0.05, yy, zc) @ R(0, 90 * sx, 0))  # (readable from outside)
        ctx.add("Metal", box(0.04, 0.08, 2.2, bevel=0.012, segments=1), T(xf + sx * 0.05, 1.6, zc))  # the bottom clip rail
    # fly posters and stickers on the back wall and the front corners
    posters = ((-1.6, 2.2, 0.9, 1.25), (-0.5, 2.0, 0.8, 1.1), (1.8, 2.6, 0.6, 0.85), (2.6, 1.3, 0.35, 0.35))
    for k, (x, y, w, h) in enumerate(posters):
        ctx.add("Paper", _transform(patch(w, h, 0.01, 2, 3, jag=0.08, rng=rng), R(0, 180, 0)), T(x, y, hd + 0.045))
    ctx.wear("MetalPainted", paint_wear(noise, dirt_h=1.6, dirt=0.4, rust_y=0.9, streak=0.22, top_grime=0.25))

    def paper(p):
        x, y, z = p.co
        n = noise.fbm(p.co * 6, 2)
        if abs(x) > hw:  # headline bills: big black words on white
            k = 0.95
            if 4.6 < y < 5.0 or 3.9 < y < 4.4 or 2.3 < y < 2.6:
                k = 0.36 + 0.3 * smoothstep(0.3, 0.7, noise.fbm(Vector((x, y * 3, z * 14)), 1) * 0.5 + 0.5)
            return (k, k * 0.98, k * 0.92)
        if z > hd:  # fly posters: faded colours, rain-streaked, a dark title band
            j = min(range(len(posters)), key=lambda q: abs(posters[q][0] - x))
            c = colours[(j * 3 + 2) % len(colours)]
            px, py, pw, ph = posters[j]
            k = 0.75 + 0.15 * n
            if py + ph * 0.15 < y < py + ph * 0.32:
                k *= 0.5
            return tuple(k * v for v in c)
        for (x0, x1), c in cart_cols:
            if x0 - 0.01 <= x <= x1 + 0.01:
                k = 0.85 + 0.15 * n
                band = 0.55 if abs(y - round(y * 2) / 2) < 0.04 else 1.0
                return tuple(k * v * band for v in c)
        return 0.9

    ctx.wear("Paper", paper)
    ctx.wear("PlasticDark", mul(lambda p: 0.85 + 0.15 * noise.fbm(p.co * 2, 2), ground_dirt(0.4, 0.3, noise)))
    ctx.wear("WoodDark", mul(lambda p: 0.8 + 0.2 * noise.fbm(Vector((p.co.x * 0.5, p.co.y * 8, p.co.z * 8)), 2), cavity(0.3)))
    ctx.wear("Metal", mul(lambda p: (0.78, 0.74, 0.68), cavity(0.3)))
    ctx.wear("Glow", lambda p: 1.0)
    ctx.wear("Black", lambda p: 0.9)


def magazine_rack(ctx):
    """Wall-hung wire magazine rack, 3 tiers, 4.8 wide: bent wire frame, slanted wire shelves with
    lip rails, rows of magazines leaning back (coloured covers). Wall piece: origin on the wall
    face at the rack's bottom, -Z out of the wall."""
    ctx.budget = 3000
    noise, rng = ctx.noise, ctx.rng
    W = 4.8
    tiers = (0.25, 1.0, 1.75)
    # side frames (bent wire): from the wall out and up, three hooks
    for sx in (-W / 2, W / 2):
        side = [(sx, 0.0, 0.01), (sx, 0.0, -0.34), (sx, 2.3, -0.24), (sx, 2.35, 0.01)]
        ctx.add("Metal", tube(fillet_path(side, 0.06, 3), 0.025, segs=6))
    covers = []
    for y in tiers:
        # the slanted shelf (two wires) and the lip rail
        for z in (-0.06, -0.24):
            ctx.add("Metal", tube([(-W / 2, y + (0.04 if z < -0.1 else 0.0), z), (W / 2, y + (0.04 if z < -0.1 else 0.0), z)], 0.018, segs=5))
        ctx.add("Metal", tube([(-W / 2, y + 0.22, -0.31), (W / 2, y + 0.22, -0.31)], 0.016, segs=5))
        x = -W / 2 + 0.08
        while x < W / 2 - 0.55:
            w = rng.uniform(0.62, 0.78)
            h = rng.uniform(0.82, 0.98)
            th = rng.uniform(0.03, 0.08)
            lean = rng.uniform(14, 22)
            ctx.add("Paper", box(w, h, th, bevel=0.008, segments=1), T(x + w / 2, y + 0.04, -0.22) @ R(-lean, 0, 0) @ T(0, h / 2, 0))
            covers.append((x, x + w, y, rng.choice(((1.0, 0.4, 0.38), (0.4, 0.55, 0.95), (0.95, 0.85, 0.4), (0.95, 0.95, 0.92),
                                                    (0.45, 0.8, 0.55), (0.85, 0.45, 0.8), (0.36, 0.36, 0.4)))))
            x += w + rng.uniform(0.02, 0.08)

    def cover(p):
        x, y, z = p.co
        for x0, x1, y0, c in covers:
            if x0 - 0.02 <= x <= x1 + 0.02 and y0 <= y <= y0 + 1.1:
                k = 0.8 + 0.2 * noise.fbm(p.co * 9, 2)
                t = (y - y0) / 1.0
                if 0.72 < t < 0.88:  # (the masthead band)
                    return (k * 0.95, k * 0.95, k * 0.95)
                if p.normal.z > 0.3:  # (backs: plain paper)
                    return 0.8
                return tuple(k * v for v in c)
        return 0.85

    ctx.wear("Paper", cover)
    ctx.wear("Metal", mul(lambda p: (0.75, 0.72, 0.68), lambda p: 0.85 + 0.15 * noise.fbm(p.co * 5, 2)))


def newspaper_bundle(ctx):
    """A bundle of the day's papers: folded newspapers stacked a little askew, two plastic straps
    biting into the top edges, a torn top sheet."""
    ctx.budget = 1500
    ctx.tint("Plastic", (210, 190, 60))
    noise, rng = ctx.noise, ctx.rng
    L, D, H = 1.15, 0.85, 0.48
    n = 6
    y = 0.0
    for k in range(n):
        th = H / n
        dx, dz, a = rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), rng.uniform(-2.5, 2.5)
        sheet = rbox(L, th * 0.94, D, r=0.018, m=1, n=(3, 1, 1))
        # (the folded edge rounds over on +Z, the open edges a little fanned)
        for v in sheet.verts:
            if v.co.z < -D / 2 + 0.05:
                v.co.y += 0.008 * math.sin(v.co.x * 9 + k)
        ctx.add("Paper", sheet, T(dx, y + th / 2, dz) @ R(0, a, 0))
        y += th
    # straps: thin bands round the stack across Z at x = +-0.3, pressing the top edges in
    for xs in (-0.3, 0.3):
        band = [(xs, -0.01, -D / 2 - 0.02), (xs, H + 0.01, -D / 2 - 0.02), (xs, H + 0.01, D / 2 + 0.02), (xs, -0.01, D / 2 + 0.02)]
        ctx.add("Plastic", sweep(fillet_path(band, 0.06, 2), rrect2(0.012, 0.07, 0.004, 1), side=(1, 0, 0), closed=True))
        ctx.add("Plastic", rbox(0.09, 0.03, 0.06, r=0.01, m=1), T(xs, H + 0.02, 0.1))  # the crimp seal

    def paper(p):
        x, y, z = p.co
        k = 0.82 + 0.12 * noise.fbm(p.co * 8, 2)
        if p.normal.y > 0.7 and y > H - 0.05:
            if (0.05 < z < 0.28 or -0.3 < z < -0.22) and abs(x) < 0.5:  # the headline and columns
                k *= 0.45 + 0.3 * smoothstep(0.3, 0.7, noise.fbm(Vector((x * 20, 0, z * 3)), 1) * 0.5 + 0.5)
        if abs(p.normal.y) < 0.5:
            k *= 0.82  # (the stacked edges: grey lines of the folds)
        k *= 1 - 0.25 * (1 - smoothstep(0.0, 0.15, y))  # (wet pavement)
        return (k, k * 0.98, k * 0.9)

    ctx.wear("Paper", paper)
    ctx.wear("Plastic", lambda p: 0.85)


# ==============================================================================================
# StreetBenchSteel. Real reference: a municipal steel bench 1.8-2.8 m long, seat 0.45 m high:
# flat steel slats on three or four cast / fabricated end frames, the two inner frames carrying
# "anti-sleep" armrests that split it into three seats, feet bolted to the paving. Wear: paint
# worn off the slats' front edges and the armrests where hands go, rust in the joints, gum and
# scratched tags, grime at the feet.
# City footprint (Props/Kiosk Bench, Zones/Cage Bench): a 10 x 0.4 x 1.6 seat slab whose top
# is 2.05 over the ground (collides: the proxy), two leg blocks. Backless, like the city's.
# ==============================================================================================
BE_L, BE_D, BE_TOP = 10.0, 1.6, 2.05


def street_bench_steel(ctx):
    """Municipal steel bench, backless, 10 long: six flat steel slats on four fabricated leg
    frames, two armrests splitting it into three seats, feet bolted down."""
    ctx.budget = 4200
    ctx.tint("MetalPainted", (46, 50, 48))
    noise = ctx.noise
    # slats: six flat bars across the depth
    n = 6
    sw = (BE_D - 0.05 * (n - 1)) / n
    for k in range(n):
        z = -BE_D / 2 + sw / 2 + k * (sw + 0.05)
        ctx.add("MetalPainted", rbox(BE_L, 0.1, sw, r=0.03, m=1, n=(5, 1, 1)), T(0, BE_TOP - 0.05, z))
    # leg frames: two splayed legs (flat bar) under a cross rail, feet plates and bolts
    for x in (-4.4, -1.5, 1.5, 4.4):
        ctx.add("MetalPainted", rbox(0.14, 0.14, BE_D - 0.1, r=0.03, m=1), T(x, BE_TOP - 0.17, 0))  # cross rail
        for sz in (-1, 1):
            leg = [(x, BE_TOP - 0.2, sz * 0.62), (x, 0.06, sz * 0.72)]
            ctx.add("MetalPainted", sweep(leg, rrect2(0.12, 0.16, 0.03, 1), side=(1, 0, 0)))
            ctx.add("MetalPainted", rbox(0.3, 0.04, 0.34, r=0.012, m=1), T(x, 0.02, sz * 0.72))
            for dz in (-0.1, 0.1):
                ctx.add("Metal", _nut(0.03, 0.03), T(x, 0.04, sz * 0.72 + dz))
        ctx.add("MetalPainted", rbox(0.1, 0.1, 1.2, r=0.025, m=1), T(x, 0.75, 0))  # (the low stretcher)
        if abs(x) < 2:  # armrest: a bent flat bar loop over the seat
            arm = fillet_path([(x, BE_TOP - 0.02, -0.66), (x, BE_TOP + 0.62, -0.5), (x, BE_TOP + 0.66, 0.5),
                               (x, BE_TOP - 0.02, 0.66)], 0.25, 5)
            ctx.add("MetalPainted", sweep(arm, rrect2(0.12, 0.08, 0.03, 1), side=(1, 0, 0)))
    pf = paint_wear(noise, dirt_h=0.8, dirt=0.4, rust_y=0.3, streak=0.12)

    def bench(p):
        c = pf(p)
        x, y, z = p.co
        # (paint rubbed off the seat's front edge and the armrest tops: paler, metal showing)
        if (y > BE_TOP - 0.1 and z < -BE_D / 2 + 0.25 and p.convex > 0.05) or (y > BE_TOP + 0.5):
            c = tuple(v * 1.25 for v in c)
        # (gum and dark tags on the seat)
        g = smoothstep(0.55, 0.62, noise.fbm(p.co * 7, 2) * 0.5 + 0.5)
        if y > BE_TOP - 0.02 and p.normal.y > 0.5:
            c = tuple(v * (1 - 0.35 * g) for v in c)
        return c

    ctx.wear("MetalPainted", bench)
    ctx.wear("Metal", lambda p: (0.7, 0.6, 0.5))


# ==============================================================================================
# BollardSteel (+Bent). Real reference: a 168 mm steel pipe bollard filled with concrete,
# ~1 m out of the ground, a domed cap, two bands of reflective tape near the top, a collar
# where it goes into the paving; the bent one was hit by a car: leaning, the shaft kinked low,
# a scraped dent with the car's paint smeared on it, the paving cracked round its foot.
# City footprint (Props/Kiosk 3 x 0.8 x 0.8, Zones/Lot9 3.5 x 0.8 x 0.8, collide: proxies; the
# old yellow BollardBand near the top). Built 3.2 tall (scaled per copy to 3.0 / 3.5).
# ==============================================================================================
BO_H = 3.2


def _bollard(ctx, bent):
    noise = ctx.noise
    r = 0.34
    prof = [(0.0, 0.0), (0.44, 0.0), (0.44, 0.05), (0.39, 0.09), (r + 0.015, 0.11), (r, 0.16)]
    prof += [(r, lerp(0.16, BO_H - 0.32, k / 8)) for k in range(1, 9)]
    prof += [(r + 0.012, BO_H - 0.3), (r + 0.012, BO_H - 0.24), (r * 0.96, BO_H - 0.2), (r * 0.82, BO_H - 0.1),
             (r * 0.55, BO_H - 0.03), (0.0, BO_H)]

    def dent(a, rr, y):
        if not bent:
            return rr
        return rr - 0.06 * math.exp(-((y - 1.4) / 0.35) ** 2) * max(0.0, math.cos(a + math.pi / 2)) ** 3

    shaft = lathe(prof, segs=20, radius_fn=dent)
    bands = []
    for y0 in (BO_H - 0.75, BO_H - 0.5):
        bands.append(lathe([(r + 0.01, y0), (r + 0.01, y0 + 0.16), (r - 0.01, y0 + 0.16), (r - 0.01, y0)], segs=20, radius_fn=dent))
    for bm in [shaft] + bands:
        if bent:  # kinked at 0.45 up, leaning away from the hit (toward +Z), 5 degrees
            for v in bm.verts:
                h = max(0.0, v.co.y - 0.45)
                a = math.radians(5.0) * smoothstep(0.0, 0.5, h)
                v.co.z += h * math.sin(a)
                v.co.y = 0.45 + h * math.cos(a) if v.co.y > 0.45 else v.co.y
    ctx.add("MetalPainted", shaft)
    for b in bands:
        ctx.add("Reflective", b)
    if bent:  # cracked paving chunks lifted round its foot
        rng = ctx.rng
        for k in range(5):
            a = TAU * k / 5 + rng.uniform(-0.3, 0.3)
            d = rng.uniform(0.5, 0.65)
            chunk = rbox(rng.uniform(0.2, 0.32), 0.08, rng.uniform(0.15, 0.25), r=0.02, m=1)
            ctx.add("Concrete", chunk, T(d * math.cos(a), 0.02, d * math.sin(a)) @ R(rng.uniform(-8, 8), math.degrees(-a), rng.uniform(-6, 6)))
        ctx.wear("Concrete", lambda p: 0.7 + 0.2 * noise.fbm(p.co * 6, 2))
    pf = paint_wear(noise, dirt_h=0.9, dirt=0.4, rust_y=0.5, streak=0.15, top_grime=0.1)

    def paint(p):
        c = pf(p)
        x, y, z = p.co
        # (bumper scuffs at 0.9-1.5 all round; the hit one: a smear of red car paint in the dent)
        sc = smoothstep(0.45, 0.65, noise.fbm(Vector((x * 6, y * 2, z * 6)), 2) * 0.5 + 0.5)
        if 0.9 < y < 1.6:
            c = tuple(v * (1 + 0.35 * sc) for v in c)
        if bent and 1.1 < y < 1.75 and z < -0.15:
            c = (c[0] * 1.6, c[1] * 0.7, c[2] * 0.65)
        return c

    ctx.wear("MetalPainted", paint)
    ctx.wear("Reflective", lambda p: (0.95 * (0.8 + 0.2 * noise.fbm(p.co * 9, 2)), 0.78, 0.25))


def bollard_steel(ctx):
    """Concrete-filled steel pipe bollard: domed cap, two reflective bands, base collar."""
    ctx.budget = 1500
    ctx.tint("MetalPainted", (34, 34, 34))
    _bollard(ctx, False)


def bollard_steel_bent(ctx):
    """The bollard a car hit: kinked low and leaning, dented, red paint smeared on it, the
    paving cracked round its foot."""
    ctx.budget = 1600
    ctx.tint("MetalPainted", (34, 34, 34))
    _bollard(ctx, True)


# ==============================================================================================
# StreetGrate. Real reference: a cast-iron ventilation / steam grating in the roadway (subway
# vent, utility vault): a heavy angle frame round a grid of bearing bars and cross bars, the dark
# void under it, the bar tops polished by tyres, rust and grime in the frame.
# City footprint (Props/Steam): SteamVent 4 x 0.2 x 4 (CitySteam: kept, invisible, its steam
# moved to the Fx marker over the grate). Here: 4 x 4, its top 0.07 over the road (y = 0).
# ==============================================================================================
def street_grate(ctx):
    """Cast-iron road grating 4 x 4: angle frame, bearing bars and cross bars over a dark void,
    tyre-polished tops."""
    ctx.budget = 2500
    ctx.tint("MetalPainted", (50, 48, 46))
    noise = ctx.noise
    S_, top = 4.0, 0.07
    # frame: four angle-iron sides (bevelled outer edge down to the road)
    for k in range(4):
        sec = [(-0.2, -0.04), (0.2, -0.04), (0.2, top - 0.03), (0.17, top), (-0.18, top), (-0.2, top - 0.015)]
        half = S_ / 2 if k % 2 == 0 else S_ / 2 - 0.4  # (two sides full length, two between them)
        ctx.add("MetalPainted", prism(sec, -half, half, segs=4), R(0, 90 * k, 0) @ T(S_ / 2 - 0.2, 0, 0))
    # bearing bars (along X) and cross bars (along Z)
    for k in range(13):
        z = -1.62 + k * 0.27
        ctx.add("MetalPainted", box(3.62, 0.12, 0.06, bevel=0.012, segments=1), T(0, top - 0.065, z))
    for k in range(5):
        x = -1.5 + k * 0.75
        ctx.add("MetalPainted", box(0.05, 0.08, 3.62, bevel=0.01, segments=1), T(x, top - 0.075, 0))
    ctx.add("Black", box(3.62, 0.02, 3.62), T(0, 0.004, 0))  # the void under the bars
    ctx.mark("Fx", (0, 0.4, 0))

    def iron(p):
        x, y, z = p.co
        k = 0.7 + 0.2 * noise.fbm(p.co * 3, 2)
        if p.normal.y > 0.7 and y > top - 0.012:
            k *= 1.35 - 0.25 * smoothstep(1.0, 1.9, max(abs(x), abs(z)))  # (polished bar tops)
        else:
            k *= 0.7
        rust = smoothstep(0.1, 0.5, noise.fbm(p.co * 5, 2))
        return (k, k * lerp(1, 0.75, rust), k * lerp(1, 0.6, rust))

    ctx.wear("MetalPainted", iron)
    ctx.wear("Black", lambda p: 0.5)


# ==============================================================================================
# ManholeCover. Real reference: a 0.6-0.8 m cast-iron sewer cover (US: a raised grid / waffle
# of square lugs for grip, the word SEWER cast across the middle, two pick holes), seated in a
# cast frame set in the asphalt; the lug tops polished bright by tyres, rust in the frame and
# the gaps, the road's patch ring round it.
# City footprint (Ground/Manholes): Manhole cylinder 3 across, 0.2 thick, top 0.15 over the
# road (no collision). Here: 3.0 across, the cover's top 0.05 over the road (y = 0), flush-ish.
# ==============================================================================================
def manhole_cover(ctx):
    """Cast-iron sewer cover 3.0 across in its frame: raised square-lug grid, SEWER cast in the
    middle, two pick holes, tyre-polished lug tops, rusty frame."""
    ctx.budget = 2500
    ctx.tint("MetalPainted", (48, 46, 44))
    noise = ctx.noise
    R0 = 1.5
    # frame ring (rusty), the cover disc a hair lower inside it
    ctx.add("Rust", lathe([(R0 - 0.2, -0.05), (R0, -0.05), (R0, 0.02), (R0 - 0.04, 0.045), (R0 - 0.16, 0.045),
                           (R0 - 0.2, 0.03)], segs=40))
    ctx.add("MetalPainted", lathe([(0.0, -0.03), (R0 - 0.215, -0.03), (R0 - 0.215, 0.025), (R0 - 0.24, 0.035), (0.0, 0.035)], segs=40))
    # raised lugs: a grid of small squares inside the rim band, cleared round the lettering
    lugs = []
    step = 0.22
    for i in range(-6, 7):
        for j in range(-6, 7):
            x, z = i * step, j * step
            if math.hypot(x, z) > R0 - 0.42 or (abs(z) < 0.3 and abs(x) < 0.95):
                continue
            if math.hypot(x - 0.75, z + 0.85) < 0.12 or math.hypot(x + 0.75, z - 0.85) < 0.12:
                continue
            lugs.append((x, z))
            ctx.add("Metal", box(0.13, 0.03, 0.13), T(x, 0.05, z))
    # a raised ring band inside the rim
    ctx.add("Metal", lathe([(R0 - 0.4, 0.03), (R0 - 0.3, 0.03), (R0 - 0.3, 0.058), (R0 - 0.4, 0.058)], segs=40))
    # SEWER (raised letters across the middle, read from the -Z side)
    txt = text_bm("SEWER", 0.36, 0.03, res=1)
    ctx.add("Metal", txt, T(0, 0.05, 0) @ R(0, 180, 0) @ R(-90, 0, 0))  # (reads from the -Z side)
    # pick holes: dark slots
    for x, z in ((0.75, -0.85), (-0.75, 0.85)):
        ctx.add("Black", rbox(0.16, 0.02, 0.07, r=0.03, m=1), T(x, 0.037, z) @ R(0, 35, 0))

    def iron(p):
        x, y, z = p.co
        k = 0.65 + 0.2 * noise.fbm(p.co * 4, 2)
        if p.normal.y > 0.7:
            k *= 1.0 + 0.35 * (1 - smoothstep(0.3, 1.3, math.hypot(x, z)))
        k *= 1 - 0.3 * smoothstep(0.0, 0.5, -p.convex)
        return (k, k * 0.96, k * 0.92)

    ctx.wear("MetalPainted", iron)
    ctx.wear("Metal", lambda p: 0.75 + 0.25 * (1 - smoothstep(0.2, 1.3, math.hypot(p.co.x, p.co.z))) if p.normal.y > 0.7 else 0.55)
    ctx.wear("Rust", mul(lambda p: 0.6 + 0.3 * noise.fbm(p.co * 8, 2), cavity(0.3)))
    ctx.wear("Black", lambda p: 0.4)


PIECES = {
    "StreetLampColumn": street_lamp_column,
    "StreetLampColumnRusty": street_lamp_column_rusty,
    "StreetLampColumnDead": street_lamp_column_dead,
    "TrafficSignalPole": traffic_signal_pole,
    "TrafficSignalHead": traffic_signal_head,
    "PhoneBooth": phone_booth,
    "PhoneBoothSmashed": phone_booth_smashed,
    "FireHydrant": fire_hydrant,
    "FireHydrantWorn": fire_hydrant_worn,
    "JerseyBarrier": jersey_barrier,
    "JerseyBarrierChipped": jersey_barrier_chipped,
    "NewsKiosk": news_kiosk,
    "MagazineRack": magazine_rack,
    "NewspaperBundle": newspaper_bundle,
    "StreetBenchSteel": street_bench_steel,
    "BollardSteel": bollard_steel,
    "BollardSteelBent": bollard_steel_bent,
    "StreetGrate": street_grate,
    "ManholeCover": manhole_cover,
}
