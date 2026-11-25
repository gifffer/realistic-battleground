"""The park of the city prop kit (Park, Park/SpezColaMachine_3 and the two other SpezCola
machines): the cast-iron benches, the heritage lamp posts, the young trees (plane, lime, an
autumn one), the cast litter bins, the granite drinking fountain, the two-tier fountain of the
plaza, the Victorian bandstand and the drinks vending machines.

Why meshes: the city's park (CityData, folder Park) was built of primitives: benches of six
planks on four black sticks, lamps of a box plinth, a round stick and a cube of glass, trees of
a brown box carrying green / orange cubes or balls, bins of a green cylinder, a fountain of
eight boxes round a disc, a bandstand of eight sticks under three stacked squares, a vending
machine of a red box with flat squares on it. Each one here is modelled once to the real
object's proportions (lathes for cast and turned parts, sweeps for cast-iron scrolls and bent
bar, lofts for the roofs and bowls), with the details that make it read and the wear a city
park puts on it (vertex colours: grime rising from the ground, green damp on stone, weathered
silver-grey timber, rust weeping from cast iron, hand grime, stickers).

Conventions (pieces/_template.py): Roblox axes, studs (1 stud ~ 0.28 m), +Y up, front = -Z.
Floor pieces: origin at the centre of the footprint on the ground. Each piece takes the
footprint of the city parts it replaces (tools/city/overlay/edits/park.py wraps them; the old
colliding parts stay as invisible proxies, the mesh within ~0.3 stud of them; the numbers are
noted at each piece). Only ONE kind of tintable layer per piece (the marker's Tint goes to every
tintable layer). Leaves are the Leaves layer (tintable, two-sided sheets: the leaf cards are
modelled with both faces); bark is Bark, stakes WoodDark; stone is Concrete. No bottles of any kind.
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
    sphere,
    lerp,
    smoothstep,
    mul,
    ground_dirt,
    cavity,
    edge_wear,
    streaks,
    scuffs,
)
from fixtures import (  # noqa: F401  (the kit's shared shape helpers, read-only use)
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
import kitlib  # noqa: E402

# Leaves and bark have their own layers (kitlib.LAYERS / PropKit LOOKS: LeafyGrass, Wood);
# older kits without them used Tarp (two-sided, tintable) and Wood.
LEAF = "Leaves" if "Leaves" in kitlib.LAYERS else "Tarp"
BARK = "Bark" if "Bark" in kitlib.LAYERS else "Wood"

TAU = 2 * math.pi


# ==============================================================================================
# Shared helpers
# ==============================================================================================
def text_bm(txt, size, depth, res=2):
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
    cu.offset = size * 0.03
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


def bend_round(bm, r_fn, a_mid):
    """Wraps a flat patch (x across, y up, z = thickness, centred on z = 0) round the Y axis:
    x becomes an arc at radius r_fn(y) + z centred on angle a_mid (0 = +X, -pi/2 = the front)."""
    for v in bm.verts:
        x, y, z = v.co
        r = r_fn(y)
        a = a_mid + x / max(r, 1e-3)
        v.co = Vector(((r + z) * math.cos(a), y, (r + z) * math.sin(a)))
    return bm


def iron_wear(noise, dirt_h=0.9, dirt=0.35, rust_y=None, rust=0.0, flake=0.0, scale=3.0):
    """Painted cast iron: dirt rising from the ground, grime in creases, rubbed convex edges
    (paint worn to the dark primer), rain streaks, rust weeping low (rust_y) and, with flake,
    paint flaking in patches everywhere (rust-brown multiplier)."""
    st = streaks(noise, 0.16, 5.0)

    def fn(p):
        x, y, z = p.co
        k = 0.88 + 0.12 * noise.fbm(p.co * scale, 2)
        g = 1 - dirt * (1 - smoothstep(0.0, dirt_h * (1 + 0.3 * noise.fbm(p.co, 2, 2.0)), y))
        c = [k * g, k * g * 0.97, k * g * 0.93]
        t = 0.0
        if rust_y is not None:
            t = rust * (1 - smoothstep(rust_y * 0.4, rust_y, y)) * smoothstep(-0.15, 0.4, noise.fbm(p.co * 4.0, 3))
        if flake:
            t = max(t, flake * smoothstep(0.25, 0.55, noise.fbm(p.co * 6.0 + Vector((3.1, 0, 1.7)), 3)))
        if t:
            c = [lerp(c[0], c[0] * 1.0, t), lerp(c[1], c[1] * 0.62, t), lerp(c[2], c[2] * 0.45, t)]
        cav = 1 - 0.32 * smoothstep(0.0, 0.5, -p.convex)
        edge = 1 + 0.1 * smoothstep(0.05, 0.5, p.convex)
        s = st(p)
        return tuple(v * cav * edge * s for v in c)

    return fn


def timber_wear(noise, silver=0.5, rot=0.0, ends=None, scale=5.0):
    """Outdoor hardwood slats: silver-grey weathering on the faces the rain and sun reach (top,
    front), darker grain streaks along X, black damp and rot at the ends (ends = |x| where the
    slat stops) and in creases, the underside darker."""

    def fn(p):
        x, y, z = p.co
        grain = 0.82 + 0.18 * noise.fbm(Vector((x * 0.5, y * 11.0, z * 11.0)), 3)
        up = smoothstep(0.2, 0.9, p.normal.y)
        sil = silver * (0.55 + 0.45 * up)
        c = [grain * lerp(1.0, 0.74, sil), grain * lerp(1.0, 0.86, sil), grain * lerp(1.0, 1.0, sil)]
        if p.normal.y < -0.5:
            c = [v * 0.72 for v in c]
        if ends is not None:
            e = smoothstep(ends - 0.45, ends, abs(x))
            c = [v * (1 - 0.35 * e) for v in c]
        if rot:
            r = rot * smoothstep(0.3, 0.6, noise.fbm(p.co * 3.0 + Vector((7, 1, 3)), 2))
            c = [c[0] * (1 - 0.45 * r), c[1] * (1 - 0.48 * r), c[2] * (1 - 0.5 * r)]
        cav = 1 - 0.3 * smoothstep(0.0, 0.5, -p.convex)
        return tuple(v * cav for v in c)

    return fn


def stone_wear(noise, damp_h=0.8, damp=0.35, green=0.25, scale=2.5, speck=0.12):
    """Granite / cast stone outdoors: speckle, damp darkening rising from the ground, green
    algae on the shaded low faces and in joints, black streaks under ledges."""
    st = streaks(noise, 0.2, 4.0)

    def fn(p):
        x, y, z = p.co
        sp = 1 - speck + speck * (0.5 + 0.5 * noise.n(p.co * 26.0))
        k = sp * (0.9 + 0.1 * noise.fbm(p.co * scale, 2))
        d = 1 - smoothstep(0.0, damp_h * (1 + 0.35 * noise.fbm(p.co, 2, 1.5)), y)
        c = [k * (1 - damp * d), k * (1 - damp * d), k * (1 - damp * d)]
        gr = green * d * smoothstep(0.0, 0.6, noise.fbm(p.co * 2.0 + Vector((5, 2, 8)), 2) + 0.3)
        c = [c[0] * (1 - 0.35 * gr), c[1] * (1 - 0.12 * gr), c[2] * (1 - 0.4 * gr)]
        cav = 1 - 0.35 * smoothstep(0.0, 0.5, -p.convex)
        s = st(p)
        return tuple(v * cav * s for v in c)

    return fn


def bar(path, w, h, r=None, side=(1, 0, 0), n=1):
    """A cast-iron bar of rounded-rectangle section w (along `side`) x h along a path."""
    return sweep(path, rrect2(w, h, r if r is not None else min(w, h) * 0.3, n), side=side)


def scroll(cx, cy, r0, r1, turns, a0=0.0, n=None, cw=1):
    """A flat spiral in (u, v) around (cx, cy) from radius r0 (outside) to r1 (inside):
    the C / S scrolls of cast iron. Returns [(u, v)]."""
    n = n or max(8, int(turns * 18))
    out = []
    for k in range(n + 1):
        t = k / n
        a = a0 + cw * TAU * turns * t
        r = lerp(r0, r1, t)
        out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


def ring_of(n, rad, y, a0=0.0):
    return [(rad * math.cos(a0 + TAU * k / n), y, rad * math.sin(a0 + TAU * k / n)) for k in range(n)]


def oct_lathe(profile, sides=8, a0=None, radius_fn=None):
    """Like lathe() but with `sides` flat facets: the profile radius is the facets' INRADIUS
    (an octagonal plinth / roof whose flat faces stand at r). a0: the first corner's angle
    (default: a facet faces -Z, the front)."""
    a0 = (math.pi / sides - math.pi / 2) if a0 is None else a0
    k = 1 / math.cos(math.pi / sides)
    rings = []
    for r, y in profile:
        if r < 1e-6:
            rings.append([(0.0, y, 0.0)])
            continue
        ring = []
        for s in range(sides):
            a = a0 + TAU * s / sides
            rr = r * k
            if radius_fn:
                rr = radius_fn(a, rr, y)
            ring.append((rr * math.cos(a), y, rr * math.sin(a)))
        rings.append(ring)
    closed = len(profile) > 2 and profile[0][0] > 1e-6 and profile[-1][0] > 1e-6
    return loft(rings, closed_profile=closed)


# ==============================================================================================
# ParkBenchCast (+Worn). Real reference: the cast-iron and hardwood park bench of every city
# park (the "Victorian" / "Edwardian" pattern bench: Broxap, Furnitubes, the old LCC bench):
# two cast-iron end frames (a splayed front leg, a raked rear leg running up into the back
# support, a seat bearer, a scrolled armrest curling down onto the front leg, a C-scroll in the
# triangle under the seat), 1.8 m long, seat 0.45 m high on five hardwood slats bolted with
# coach bolts, three back slats, a brass memorial plaque ("In loving memory of...") on the
# back. Typical wear: timber gone silver-grey on top and dark at the ends, black damp where
# the slats sit on the iron, rust weeping from the bolts, paint rubbed off the armrests by
# hands, chewing gum under the seat; on the worn one a front seat slat gone (the bearers show),
# the top back slat split and sagging, paint flaking all over the iron.
# City footprint (Park, 5 benches): seat 6.0 long, top at y 1.75 over the ground, slats from
# z -0.79 to +0.79 (the middle one collides: 6 x 0.2 x 0.48, top 1.75), back boards at z +0.83
# up to y 3.5, end frames at x +-2.6 (front leg z -0.6, rear leg z +0.82).
# ==============================================================================================
BENCH_X = 2.6
SEAT_TOP = 1.75


def _bench_frame(ctx, x, worn):
    """One cast-iron end frame in the plane x (bars swept along (z, y) paths)."""
    lay = "MetalPainted"
    side = (1, 0, 0)

    def P(pts):
        return [(x, y, z) for z, y in pts]

    # front leg: a splayed, slightly cabriole leg up to the seat front
    front = spline([(-0.74, 0.0), (-0.66, 0.45), (-0.62, 1.0), (-0.66, 1.5), (-0.74, 1.66)], 3)
    ctx.add(lay, bar(P(front), 0.13, 0.15, side=side))
    # rear leg running up into the raked back support, a curl at the top
    rear = spline([(0.88, 0.0), (0.74, 0.7), (0.7, 1.5), (0.78, 2.3), (0.9, 3.0), (1.0, 3.42)], 3)
    curl = scroll(0.9, 3.42, 0.1, 0.035, 0.85, a0=0.0, cw=1)
    rear += [(z, y) for z, y in curl[1:]]
    ctx.add(lay, bar(P(rear), 0.13, 0.15, side=side))
    # seat bearer (dished a little), under the slats
    bearer = spline([(-0.8, 1.6), (-0.3, 1.55), (0.3, 1.55), (0.74, 1.59)], 4)
    ctx.add(lay, bar(P(bearer), 0.12, 0.12, side=side))
    # armrest: from the back support forward, then curling down in a scroll onto the front leg
    arm = spline([(0.8, 2.42), (0.3, 2.44), (-0.35, 2.42), (-0.66, 2.34)], 4)
    arm += [(z, y) for z, y in scroll(-0.66, 2.16, 0.18, 0.05, 0.95, a0=math.pi / 2, cw=-1)[1:]]
    ctx.add(lay, bar(P(arm), 0.12, 0.13, side=side))
    # the armrest's support strut down to the bearer
    ctx.add(lay, bar(P(spline([(-0.42, 1.58), (-0.47, 1.9), (-0.44, 2.4)], 3)), 0.09, 0.09, side=side))
    # the C-scroll under the seat and a stretcher between the legs
    sc = scroll(0.05, 1.12, 0.32, 0.08, 1.2, a0=math.pi * 0.95, cw=-1)
    ctx.add(lay, bar(P(sc), 0.08, 0.08, side=side))
    ctx.add(lay, bar(P(spline([(-0.64, 0.62), (0.0, 0.78), (0.74, 0.7)], 4)), 0.09, 0.1, side=side))
    # feet pads
    for z in (-0.76, 0.9):
        ctx.add(lay, rbox(0.17, 0.05, 0.24, r=0.02, m=1), T(x, 0.025, z))


def _bench(ctx, worn):
    noise, rng = ctx.noise, ctx.rng
    ctx.budget = 7800
    for x in (-BENCH_X, BENCH_X):
        _bench_frame(ctx, x, worn)
    # ---- seat: five slats on the bearers (top at SEAT_TOP), dished with the bearers
    slats = [-0.62, -0.31, 0.0, 0.31, 0.62]
    for k, z in enumerate(slats):
        if worn and k == 0:
            continue  # (the front slat is gone)
        w, t = 0.27, 0.12
        y0 = SEAT_TOP - t / 2 - (0.03 if abs(z) < 0.4 else 0.0)
        s = rbox(6.0, t, w, r=0.035, m=1, n=(8, 1, 1))
        if worn:  # (warped, a little sag in the middle)
            for v in s.verts:
                v.co.y -= 0.03 * math.cos(v.co.x / 3.0 * math.pi / 2) * (0.6 + 0.4 * k / 4)
        ctx.add("Wood", s, T(0, y0, z) @ R(-3 + 1.5 * k, 0, 0))
        for x in (-BENCH_X, BENCH_X):  # (coach bolt heads)
            ctx.add("Metal", _dome(0.045, 0.025, 6), T(x, y0 + t / 2 - 0.004, z))
    # ---- back: three slats on the raked back supports
    backs = [(2.35, 0.79), (2.82, 0.86), (3.27, 0.95)]
    rake = math.degrees(math.atan2(0.12, 0.92))
    for k, (y, z) in enumerate(backs):
        s = rbox(6.0, 0.36, 0.1, r=0.03, m=1, n=(8, 1, 1))
        m = T(0, y, z - 0.08) @ R(-rake, 0, 0)
        if worn and k == 2:
            # (the top slat split: the left half sags off its bolt)
            left = rbox(3.05, 0.36, 0.1, r=0.03, m=1, n=(4, 1, 1))
            right = rbox(2.95, 0.36, 0.1, r=0.03, m=1, n=(4, 1, 1))
            for v in left.verts:  # (the split end ragged)
                if v.co.x > 1.45:
                    v.co.x += 0.06 * noise.n(v.co * 9)
            ctx.add("Wood", right, m @ T(1.52, 0, 0))
            ctx.add("Wood", left, m @ T(-0.02, 0, 0) @ R(0, 0, 4.5) @ T(-1.5, 0, 0))
        else:
            ctx.add("Wood", s, m)
        for x in (-BENCH_X, BENCH_X):
            ctx.add("Metal", _transform(_dome(0.04, 0.022, 6), R(-90 - rake, 0, 0)), T(x, y, z - 0.08) @ R(-rake, 0, 0) @ T(0, 0, -0.05))
    # ---- the memorial plaque on the middle back slat (brass, raised border), one per bench
    if not worn:
        pl = rbox(0.82, 0.2, 0.025, r=0.01, m=1, n=(3, 1, 1))
        ctx.add("Metal", pl, T(0.35, 2.82, 0.86 - 0.08) @ R(-rake, 0, 0) @ T(0, 0, -0.06))
        for dx in (-0.36, 0.36):
            ctx.add("Metal", _transform(_dome(0.018, 0.012, 6), R(-90, 0, 0)), T(0.35 + dx, 2.82, 0.86 - 0.08) @ R(-rake, 0, 0) @ T(0, 0, -0.072))
    # ---- wear
    ctx.wear("MetalPainted", iron_wear(noise, dirt_h=0.8, dirt=0.4, rust_y=0.9 if worn else 0.5,
                                       rust=0.8 if worn else 0.4, flake=0.55 if worn else 0.0))
    tw = timber_wear(noise, silver=0.95 if worn else 0.7, rot=0.7 if worn else 0.2, ends=3.0)

    def wood(p):
        c = tw(p)
        x, y, z = p.co
        k = 1.0
        # (black damp where the slats sit on the iron)
        k *= 1 - 0.35 * smoothstep(0.35, 0.0, abs(abs(x) - BENCH_X)) * (1 if y < SEAT_TOP + 0.05 else 0.5)
        # (hands and backs: the middle of the seat front and of the back polished darker)
        if worn:
            k *= 1 - 0.18 * smoothstep(0.4, 0.8, noise.fbm(Vector((x * 2.5, y * 3, z * 3)), 2) * 0.5 + 0.5)
        return tuple(v * k for v in c)

    ctx.wear("Wood", wood)
    ctx.wear("Metal", mul(lambda p: (0.85 + 0.1 * noise.fbm(p.co * 9, 2), 0.72, 0.5), cavity(0.3)))


def park_bench_cast(ctx):
    """Cast-iron and hardwood park bench (scrolled end frames, five seat and three back slats,
    brass memorial plaque), 1.7 m."""
    _bench(ctx, worn=False)
    ctx.tint("MetalPainted", (34, 46, 40))


def park_bench_cast_worn(ctx):
    """The same bench gone to ruin: front seat slat missing, top back slat split and sagging,
    paint flaking off rusty iron, timber silver and rotten at the ends."""
    _bench(ctx, worn=True)
    ctx.tint("MetalPainted", (30, 32, 30))


# ==============================================================================================
# HeritageLampPost (+Worn). Real reference: the cast-iron heritage lamp column of a city park
# (the "Windsor" lantern on a fluted column, as in London's Royal Parks or New York's Central
# Park "Type B"): 3.5 m to the top, a fluted cast base (~0.45 m across, a service door on it), a
# slim fluted then plain shaft with collars, the ladder bar under the lantern (two arms with
# ball ends, for the lamplighter's ladder), a four-sided lantern wider at the top with glazing
# bars, a curved (ogee) roof with a vent cap and a ball-and-spike finial. Painted dark green or
# black. Typical wear: grime and dog marks at the foot, rust breaking through the paint at the
# base and the joints, the lantern glass dirty; on the worn one paint flaking all over, the
# column leaning a little, one ladder arm bent down, flyers and stickers on the shaft.
# City footprint (Park, 7 lamps): LampPlinth 1.1 square, y 0..1.0 over the ground (collides);
# post 0.42 round up to 9.0; glass 0.9 square 9.0..10.3 (the CityLamp light), cap to 10.8,
# finial ball to 11.12.
# ==============================================================================================
LAMP_GLASS_Y0, LAMP_GLASS_Y1 = 9.05, 10.2


def _lamp_post(ctx, worn):
    noise, rng = ctx.noise, ctx.rng
    ctx.budget = 6000
    lay = "MetalPainted"
    lean = math.radians(0.9) if worn else 0.0

    def leaned(bm):
        if lean:
            for v in bm.verts:
                v.co.x += math.sin(lean) * max(0.0, v.co.y - 0.9)
        return bm

    # ---- cast base: a square plinth block (the data's 1.1 box) with a moulded foot and cornice,
    # then a fluted round body tapering up, a collar, a neck
    block = [(0.0, 0.0), (0.55, 0.0), (0.55, 0.08), (0.52, 0.12), (0.5, 0.18), (0.5, 0.8), (0.52, 0.84),
             (0.54, 0.9), (0.54, 0.95), (0.48, 0.99), (0.0, 0.99)]
    ctx.add(lay, leaned(oct_lathe(block, sides=4)))
    prof = [(0.0, 0.97), (0.42, 0.97), (0.43, 1.02), (0.41, 1.06)]
    for k in range(5):
        prof.append((lerp(0.39, 0.31, k / 4), lerp(1.1, 1.7, k / 4)))
    prof += [(0.35, 1.73), (0.36, 1.8), (0.33, 1.86), (0.24, 1.93), (0.2, 2.02), (0.175, 2.1), (0.0, 2.1)]

    def flutes(a, r, y):
        if 1.1 < y < 1.68:
            return r - 0.025 * max(0.0, math.cos(8 * a)) ** 2
        return r

    ctx.add(lay, leaned(lathe(prof, segs=32, radius_fn=flutes)))
    # (the service door: a raised arched panel on the block's front, a key boss)
    door = rbox(0.3, 0.44, 0.04, r=0.02, m=1, n=(1, 2, 1))
    for v in door.verts:
        if v.co.y > 0.1:
            v.co.y += 0.05 * (1 - (v.co.x / 0.15) ** 2)
    ctx.add(lay, leaned(_transform(door, T(0, 0.46, -0.51))))
    ctx.add("Metal", leaned(_transform(_dome(0.035, 0.02, 8), T(0, 0.38, -0.53) @ R(-90, 0, 0))))
    # ---- shaft: fluted to 4.2, then plain, collars at the joints
    sh = []
    for k in range(15):
        y = lerp(2.08, 8.3, k / 14)
        sh.append((lerp(0.17, 0.12, (y - 2.08) / 6.22), y))
    shaft = lathe([(0.0, 2.07)] + sh + [(0.0, 8.31)], segs=20,
                  radius_fn=lambda a, r, y: r - (0.014 * max(0.0, math.cos(8 * a)) if y < 4.25 else 0.0))
    ctx.add(lay, leaned(shaft))
    for y, r in ((4.3, 0.17), (6.4, 0.15), (8.25, 0.16)):
        ctx.add(lay, leaned(lathe([(0, y - 0.07), (r - 0.02, y - 0.07), (r, y - 0.03), (r, y + 0.03), (r - 0.02, y + 0.07), (0, y + 0.07)], segs=20)))
    # ---- ladder bar: two arms with ball ends
    arm_y = 8.5
    for sgn in (-1, 1):
        droop = (-0.12 if (worn and sgn > 0) else 0.0)
        pts = [(0, arm_y, 0), (sgn * 0.35, arm_y + droop * 0.3, 0), (sgn * 0.68, arm_y + droop, 0)]
        ctx.add(lay, leaned(tube(spline(pts, 3), 0.045, segs=8)))
        ctx.add(lay, leaned(_transform(sphere(0.075, 10, 6), T(sgn * 0.7, arm_y + droop, 0))))
    # ---- capital (the spigot flaring to the lantern's floor)
    cap = [(0.0, 8.3), (0.13, 8.3), (0.14, 8.45), (0.16, 8.6), (0.22, 8.75), (0.3, 8.85), (0.34, 8.92), (0.34, 8.98),
           (0.0, 8.98)]
    ctx.add(lay, leaned(lathe(cap, segs=20)))
    # ---- lantern: four sides, wider at the top; corner posts, a glazing bar, the glass (Glow)
    y0, y1 = LAMP_GLASS_Y0, LAMP_GLASS_Y1
    h0, h1 = 0.29, 0.44  # (half widths at the bottom / top)
    ctx.add(lay, leaned(_transform(rbox(0.7, 0.08, 0.7, r=0.02, m=1), T(0, 9.0, 0))))
    ctx.add(lay, leaned(_transform(rbox(1.0, 0.07, 1.0, r=0.02, m=1), T(0, y1 + 0.03, 0))))
    for sx in (-1, 1):
        for sz in (-1, 1):
            a = (sx * h0, y0, sz * h0)
            b = (sx * h1, y1, sz * h1)
            ctx.add(lay, leaned(bar([a, b], 0.05, 0.05, side=(sx * 0.7, 0, -sz * 0.7))))
    mid = lerp(y0, y1, 0.55)
    hm = lerp(h0, h1, 0.55)
    ring = [(hm + 0.015, mid, hm + 0.015), (-hm - 0.015, mid, hm + 0.015), (-hm - 0.015, mid, -hm - 0.015),
            (hm + 0.015, mid, -hm - 0.015)]
    ctx.add(lay, leaned(tube(ring, 0.022, segs=6, closed=True)))
    glass = loft([[(-h0 + 0.02, y0 + 0.01, -h0 + 0.02), (h0 - 0.02, y0 + 0.01, -h0 + 0.02), (h0 - 0.02, y0 + 0.01, h0 - 0.02),
                   (-h0 + 0.02, y0 + 0.01, h0 - 0.02)],
                  [(-h1 + 0.02, y1 - 0.01, -h1 + 0.02), (h1 - 0.02, y1 - 0.01, -h1 + 0.02), (h1 - 0.02, y1 - 0.01, h1 - 0.02),
                   (-h1 + 0.02, y1 - 0.01, h1 - 0.02)]], cap_start=True, cap_end=True)
    ctx.add("Glow", leaned(glass))
    # (the burner / lamp holder seen through the glass: a small stem, dark)
    ctx.add("Black", leaned(_transform(cyl(0.05, 0.3, segs=8), T(0, y0 + 0.2, 0))))
    # ---- roof: square eave, ogee curve up to a vent cap, ball and spike finial
    rings = []
    eave = 0.6
    for k, (hw, y) in enumerate([(eave, y1 + 0.07), (eave, y1 + 0.12), (eave - 0.04, y1 + 0.15), (0.48, y1 + 0.2),
                                  (0.36, y1 + 0.27), (0.25, y1 + 0.36), (0.17, y1 + 0.45), (0.13, y1 + 0.52),
                                  (0.12, y1 + 0.56)]):
        rings.append([(hw, y, -hw), (-hw, y, -hw), (-hw, y, hw), (hw, y, hw)][::-1])
    roof = loft(rings, cap_start=True, cap_end=True)
    ctx.add(lay, leaned(roof))
    vent = [(0.0, y1 + 0.55), (0.1, y1 + 0.55), (0.1, y1 + 0.62), (0.2, y1 + 0.64), (0.19, y1 + 0.69), (0.06, y1 + 0.74),
            (0.05, y1 + 0.8), (0.0, y1 + 0.8)]
    ctx.add(lay, leaned(lathe(vent, segs=16)))
    fin = [(0.0, y1 + 0.79), (0.05, y1 + 0.8), (0.1, y1 + 0.86), (0.11, y1 + 0.92), (0.09, y1 + 0.98), (0.04, y1 + 1.01),
           (0.02, y1 + 1.06), (0.0, y1 + 1.13)]
    ctx.add(lay, leaned(lathe(fin, segs=12)))
    ctx.mark("Light", (math.sin(lean) * (mid - 0.9), mid, 0))
    # ---- flyers on the worn one
    if worn:
        r_at = lambda y: lerp(0.17, 0.12, (y - 2.08) / 6.22) + 0.01  # noqa: E731
        for a, yc, w, h in ((-1.4, 3.3, 0.4, 0.55), (0.6, 2.7, 0.3, 0.38), (2.5, 3.6, 0.36, 0.3)):
            sheet = rbox(w, h, 0.01, r=0.004, m=1, n=(3, 3, 1))
            for v in sheet.verts:
                if v.co.y > h / 2 - 1e-3:
                    v.co.y -= rng.uniform(0, 0.06)
            ctx.add("Paper", leaned(bend_round(_transform(sheet, T(0, yc, 0)), r_at, a)))
        ctx.wear("Paper", lambda p: (0.85 + 0.15 * noise.fbm(p.co * 9, 2)) * (0.6 if math.sin(p.co.y * 40) > 0.6 else 1.0))
    ctx.wear(lay, iron_wear(noise, dirt_h=1.3, dirt=0.42, rust_y=1.5 if worn else 0.7, rust=0.9 if worn else 0.5,
                            flake=0.5 if worn else 0.0))
    ctx.wear("Metal", mul(lambda p: (0.8, 0.7, 0.55), cavity(0.3)))


def heritage_lamp_post(ctx):
    """Cast-iron heritage lamp column: fluted base and shaft, ladder bar, four-sided Windsor
    lantern (Glow), ogee roof, finial. 3.2 m."""
    _lamp_post(ctx, worn=False)
    ctx.tint("MetalPainted", (32, 44, 38))


def heritage_lamp_post_worn(ctx):
    """The same column neglected: leaning, a ladder arm bent down, paint flaking off rust,
    flyers taped on the shaft."""
    _lamp_post(ctx, worn=True)
    ctx.tint("MetalPainted", (30, 32, 31))


# ==============================================================================================
# ParkBinCast. Real reference: the round cast-iron park litter bin (the "Victorian" pattern of
# Broxap / Furnitubes / the Royal Parks): 0.8 m tall, 0.5 m across, a moulded foot, a body of
# raised vertical ribs, a raised band with the cast word LITTER, a rolled rim, a galvanised
# liner inside with a black bin bag folded over it. Painted dark green / black. Typical wear:
# grime rising from the grass, rust on the rim where the liner rubs, the bag torn, a paper cup
# and a crumpled newspaper sticking out, drips down the front.
# City footprint (Park, 3 bins): a cylinder 1.5 across, y 0..2.6 over the ground (collides),
# a rim 1.7 across to y 2.8.
# ==============================================================================================
def park_bin_cast(ctx):
    """Cast-iron park litter bin: ribbed body, raised LITTER band, rolled rim, galvanised liner
    with a black bag folded over, litter sticking out. 0.8 m."""
    noise, rng = ctx.noise, ctx.rng
    ctx.budget = 2500
    lay = "MetalPainted"
    ribs = lambda a, r, y: r + (0.03 * max(0.0, math.cos(16 * a)) if 0.3 < y < 1.95 else 0.0)  # noqa: E731
    prof = [(0.0, 0.0), (0.8, 0.0), (0.8, 0.08), (0.75, 0.16), (0.72, 0.26)]
    for k in range(4):
        prof.append((lerp(0.715, 0.75, k / 3), lerp(0.34, 2.0, k / 3)))
    prof += [(0.8, 2.06), (0.8, 2.32), (0.76, 2.4), (0.78, 2.52), (0.84, 2.62),
             (0.86, 2.7), (0.82, 2.78), (0.74, 2.76), (0.71, 2.68), (0.71, 2.3), (0.0, 2.3)]
    ctx.add(lay, lathe(prof, segs=32, radius_fn=ribs))
    # cast lettering on the band, at the front
    t = text_bm("LITTER", 0.18, 0.03, res=1)
    ctx.add(lay, bend_round(_transform(t, R(0, 180, 0) @ T(0, 2.2, 0.0)), lambda y: 0.8, -math.pi / 2))
    # liner rim (galvanised) just inside the bin's rim
    ctx.add("Metal", lathe([(0.66, 2.5), (0.69, 2.5), (0.7, 2.74), (0.73, 2.78), (0.72, 2.81), (0.68, 2.8), (0.66, 2.76)], segs=16))
    # the black bag: folded over the liner's rim, hanging in sacks, torn on one side
    def bag_fold(a, r, y):
        w = 0.025 * math.sin(a * 9 + 1.3) + 0.015 * math.sin(a * 23)
        drop = 0.0
        if y < 2.7:
            drop = 0.08 * max(0.0, math.sin(a * 3 + 0.4)) + 0.05 * noise.n((math.cos(a) * 3, 0, math.sin(a) * 3))
        return (r + w, y - drop)
    bag = lathe([(0.725, 2.84), (0.755, 2.8), (0.765, 2.66), (0.755, 2.56), (0.735, 2.55), (0.72, 2.6), (0.715, 2.78), (0.72, 2.84)],
                segs=26, radius_fn=bag_fold)
    ctx.add("Black", bag)
    # the rubbish inside, near the top: a lumpy mass, a paper cup, a crumpled newspaper
    for k, (x, z, r) in enumerate(((0.2, 0.15, 0.42), (-0.25, -0.1, 0.38), (0.05, -0.35, 0.3))):
        lump = _blob(r, noise, squash=0.6, seed=k * 3.3)
        ctx.add("Black", lump, T(x, 2.42 + 0.05 * k, z))
    cup = lathe([(0.0, 0.0), (0.09, 0.0), (0.13, 0.3), (0.135, 0.32), (0.12, 0.32), (0.08, 0.02), (0.0, 0.02)], segs=10)
    ctx.add("Paper", cup, T(0.25, 2.58, -0.15) @ R(25, 0, -35))
    paper = box(0.5, 0.36, 0.03)
    bmesh.ops.subdivide_edges(paper, edges=paper.edges[:], cuts=2, use_grid_fill=True)
    for v in paper.verts:
        v.co.z += 0.09 * noise.n(v.co * 6) + 0.05 * math.sin(v.co.x * 9)
        v.co.y *= 0.85 + 0.15 * noise.n(v.co * 4 + Vector((2, 0, 0)))
    ctx.add("Paper", paper, T(-0.25, 2.75, 0.2) @ R(-55, 30, 10))
    base = iron_wear(noise, dirt_h=0.8, dirt=0.45)

    def paint(p):
        c = base(p)
        x, y, z = p.co
        # rust on the rim where the liner rubs, drips down the front below it
        r = smoothstep(2.55, 2.75, y) * smoothstep(-0.1, 0.5, noise.fbm(p.co * 7, 2))
        d = smoothstep(2.0, 2.5, y) * smoothstep(0.55, 0.8, noise.fbm(Vector((x * 9, y * 0.6, z * 9)), 2))
        k = max(r, d * 0.6)
        return (c[0] * lerp(1, 0.95, k), c[1] * lerp(1, 0.6, k), c[2] * lerp(1, 0.42, k))

    ctx.wear(lay, paint)
    ctx.wear("Black", lambda p: 0.8 + 0.2 * noise.fbm(p.co * 5, 2))
    ctx.wear("Paper", mul(lambda p: (0.9, 0.86, 0.78), cavity(0.4)))
    ctx.wear("Metal", mul(lambda p: 0.7 + 0.2 * noise.fbm(p.co * 8, 2), cavity(0.3)))
    ctx.tint(lay, (34, 50, 40))


# ==============================================================================================
# DrinkingFountainCast. Real reference: the Victorian granite drinking fountain of a city park
# (the Metropolitan Drinking Fountain and Cattle Trough Association's pedestals, the
# Philadelphia / Boston granite bubblers): a dressed granite pedestal ~1 m tall on a wider
# plinth, a moulded cornice, a dish of cast bronze gone green, a push-button bubbler, a little
# granite step for children in front, a dog bowl at the foot fed by the overflow, a date cut in
# a panel. Typical wear: green algae and black damp where the water runs down, the step worn
# hollow, verdigris streaks under the bronze, grime low.
# City footprint (Park, 1): a granite box 1.2 square, y 0..3.0 (collides), the bowl 1.6 square
# 3.0..3.35, spout 0.3 to the front, the step 0.9 x 0.45 x 0.4 at z -0.8.
# ==============================================================================================
def drinking_fountain_cast(ctx):
    """Granite pedestal drinking fountain: plinth, panelled shaft with a cut date, moulded
    cornice, bronze dish (Glass water) with a push-button bubbler, child's step, dog bowl.
    0.95 m."""
    noise, rng = ctx.noise, ctx.rng
    ctx.budget = 4000
    sq = lambda prof: oct_lathe(prof, sides=4)  # noqa: E731
    # plinth, shaft (slight taper), cornice: one moulded square "lathe"
    prof = [(0.0, 0.0), (0.7, 0.0), (0.7, 0.26), (0.66, 0.3), (0.62, 0.34), (0.6, 0.4)]
    for k in range(6):
        prof.append((lerp(0.58, 0.54, k / 5), lerp(0.48, 2.55, k / 5)))
    prof += [(0.57, 2.6), (0.6, 2.66), (0.66, 2.74), (0.7, 2.8), (0.7, 2.95), (0.68, 3.0), (0.0, 3.0)]
    ped = sq(prof)
    # (chips on the corners)
    for v in ped.verts:
        if abs(abs(v.co.x) - abs(v.co.z)) < 0.05 and v.co.y > 0.3:
            if noise.n(v.co * 5) > 0.35:
                v.co.x *= 0.97
                v.co.z *= 0.97
    ctx.add("Concrete", ped)
    # recessed panels: raised fillets round a panel on each face (front: a cut date)
    for k in range(4):
        a = k * 90
        face = lambda y: lerp(0.58, 0.54, (y - 0.48) / 2.07) + 0.012  # noqa: E731
        frame_pts = [(-0.34, 0.75), (0.34, 0.75), (0.34, 2.15), (-0.34, 2.15)]
        ring = [(x, y, -face(y)) for x, y in frame_pts]
        m = R(0, a, 0)
        ctx.add("Concrete", _transform(tube(ring, 0.025, segs=6, closed=True), m))
    date = text_bm("1897", 0.22, 0.025)
    ctx.add("Concrete", date, T(0, 1.6, -0.558) @ R(0, 180, 0))
    # the bronze dish on the cornice, its rim, water in it, the bubbler, the push button
    dish = [(0.0, 3.0), (0.5, 3.0), (0.72, 3.08), (0.8, 3.2), (0.82, 3.32), (0.8, 3.38), (0.76, 3.38), (0.74, 3.3),
            (0.6, 3.2), (0.3, 3.14), (0.0, 3.13)]
    ctx.add("MetalPainted", lathe(dish, segs=32))
    ctx.add("Glass", lathe([(0.0, 3.25), (0.715, 3.25), (0.715, 3.27), (0.0, 3.27)], segs=32))
    bub = [(0.0, 3.13), (0.1, 3.13), (0.09, 3.3), (0.07, 3.42), (0.045, 3.47), (0.02, 3.5), (0.0, 3.5)]
    ctx.add("MetalPainted", lathe(bub, segs=12), T(0, 0, -0.25))
    ctx.add("Black", cyl(0.012, 0.02, segs=6), T(0, 3.505, -0.25))
    ctx.add("MetalPainted", cyl(0.07, 0.08, segs=12), T(0, 2.86, -0.7) @ R(90, 0, 0))
    ctx.add("Metal", _transform(_dome(0.05, 0.03, 10), R(-90, 0, 0)), T(0, 2.86, -0.74))
    # the child's step (worn hollow in the middle)
    st = rbox(0.9, 0.45, 0.42, r=0.04, m=2, n=(6, 1, 4))
    for v in st.verts:
        if v.co.y > 0.2:
            v.co.y -= 0.04 * math.exp(-(v.co.x / 0.25) ** 2) * math.exp(-(v.co.z / 0.15) ** 2)
    ctx.add("Concrete", st, T(0, 0.225, -0.84))
    # dog bowl at the foot (+X side), filled by the overflow pipe
    db = [(0.0, 0.0), (0.26, 0.0), (0.3, 0.12), (0.3, 0.16), (0.27, 0.16), (0.24, 0.05), (0.0, 0.05)]
    ctx.add("MetalPainted", lathe(db, segs=20), T(0.98, 0, 0.1))
    ctx.add("Glass", cyl(0.255, 0.01, segs=20), T(0.98, 0.11, 0.1))
    ctx.add("MetalPainted", tube([(0.7, 0.62, 0.1), (0.82, 0.6, 0.1), (0.9, 0.5, 0.1)], 0.03, segs=8))
    sw = stone_wear(noise, damp_h=0.9, damp=0.3, green=0.4)

    def stone(p):
        c = sw(p)
        x, y, z = p.co
        # the wet run down the front from the dish, algae under the overflow
        run = smoothstep(0.35, 0.0, abs(x + 0.08 * math.sin(y * 3))) * smoothstep(-0.3, -0.55, z) * smoothstep(3.0, 1.0, y)
        k = 1 - 0.35 * run
        return (c[0] * k * (1 - 0.15 * run), c[1] * k, c[2] * k * (1 - 0.2 * run))

    ctx.wear("Concrete", stone)

    def bronze(p):
        x, y, z = p.co
        v = smoothstep(0.1, 0.5, noise.fbm(p.co * 6, 3))
        return (lerp(1.0, 0.75, v), lerp(1.0, 1.0, v), lerp(1.0, 0.95, v))

    ctx.wear("MetalPainted", mul(bronze, cavity(0.35)))
    ctx.tint("MetalPainted", (78, 70, 46))


# ==============================================================================================
# Trees: TreePlaneYoung, TreeLimeYoung, TreeAutumn. Real reference: the young street / park
# trees of a European or East-coast city park, planted 10-20 years ago: London plane (Platanus
# x acerifolia: a straight trunk with the bark flaking in olive, grey and cream patches, a broad
# rounded crown on 4-5 ascending scaffold limbs, big palmate leaves), small-leaved lime (Tilia
# cordata: smoother dark grey-brown bark, a denser ovoid crown, the bushy epicormic shoots
# round the foot that limes always throw), and one of them in autumn (a thinner crown gone
# orange, red-brown and yellow, the limbs showing through, leaves fallen on the grass round it).
# Here 3.5-4.5 m (the city's trees are 12-15 studs: young), trunk 0.3 m. The young plane still
# has its two timber stakes and rubber tree ties. The crown: the branch skeleton (tapered
# tubes), foliage clumps (low-poly displaced volumes, dark inside) with leaf sprays (two-sided
# cards) round them so the outline is broken like a real crown; vertex colours shade the
# crown (darker inside and underneath, lighter on top, cluster to cluster hue changes).
# City footprint (Park, 12 trees): Trunk ~1.1 square, y 0..7.7 over the ground (collides),
# crowns centred ~9.5 up, ~4 across each way, tops ~14.5. The overlay scales each copy to its
# trunk's height.
# ==============================================================================================
def _blob(r, noise, squash=0.75, seed=0.0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    for v in bm.verts:
        d = v.co.normalized()
        k = 1 + 0.3 * noise.n(d * 2.3 + Vector((seed, seed * 0.7, 0))) + 0.16 * noise.n(d * 6.1 + Vector((0, seed, 3)))
        v.co = Vector((v.co.x * k, v.co.y * k * squash, v.co.z * k))
    return bm


def _leaf_card(bm, c, n, size, rng, both=False):
    """A leaf spray: a jagged 5-point outline around centre c, facing n (both: two faces, for
    cards seen from both sides, like the fallen leaves' none; the crown's face outward)."""
    n = Vector(n).normalized()
    up = Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((1, 0, 0))
    u = n.cross(up).normalized()
    w = n.cross(u)
    a0 = rng.uniform(0, TAU)
    pts = []
    for k in range(5):
        a = a0 + TAU * k / 5
        rr = size * (0.55 + 0.45 * rng.random()) * (1.0 if k % 2 == 0 else 0.75)
        pts.append(c + (u * math.cos(a) + w * math.sin(a)) * rr + n * rng.uniform(-0.05, 0.05) * size)
    front = [bm.verts.new(p) for p in pts]
    bm.faces.new(front)
    if both:
        back = [bm.verts.new(p - n * 0.006) for p in pts]
        bm.faces.new(list(reversed(back)))


def _taper_tube(pts, r0, r1, segs):
    n = len(pts)
    return tube(pts, [lerp(r0, r1, (k / (n - 1)) ** 0.8) for k in range(n)], segs=segs)


def _tree(ctx, kind):
    noise, rng = ctx.noise, ctx.rng
    ctx.budget = 8000
    autumn = kind == "autumn"
    lime = kind == "lime"
    bark = BARK
    # ---- trunk with a root flare, a gentle bend, bark ridges
    # (a visible lean and bend, kept within ~0.2 of the old trunk proxy: r 0.55)
    bend_x = rng.choice((-1, 1)) * rng.uniform(0.12, 0.2)
    bend_z = rng.choice((-1, 1)) * rng.uniform(0.08, 0.16)
    top = 7.2 if not lime else 7.6

    def axis(y):
        t = y / top
        return Vector((bend_x * math.sin(t * math.pi), y, bend_z * math.sin(t * math.pi * 1.3)))

    def trunk_r(a, r, y):
        flare = 0.36 * (1 - smoothstep(0.0, 1.0, y)) * (0.5 + 0.5 * max(0.0, math.cos(5 * a + 0.7)) ** 2)
        ridge = (0.018 if lime else 0.01) * math.cos(9 * a + 2 * math.sin(y * 3))
        return r + flare + ridge

    prof = [(0.0, -0.05)]
    for k in range(13):
        y = top * (k / 12) ** 1.1
        prof.append((lerp(0.47, 0.3, (y / top) ** 1.4), max(y, -0.04)))
    prof.append((0.0, top + 0.05))
    tr = lathe(prof, segs=18, radius_fn=trunk_r)
    for v in tr.verts:
        c = axis(v.co.y)
        v.co.x += c.x
        v.co.z += c.z
    ctx.add(bark, tr)
    # ---- the crown envelope (an ellipsoid), scaffold limbs reaching into it, twigs to the clumps
    ctx.smooth_angle = 75.0
    rx = 3.6 if not lime else 3.0
    ry = 3.0 if not lime else 3.5
    crown_c = Vector((bend_x, 9.5 if not lime else 10.0, bend_z))
    limbs = 5 if not lime else 6
    skeleton = []  # points along the limbs (where twigs leave)
    for i in range(limbs):
        a = TAU * i / limbs + rng.uniform(-0.35, 0.35)
        y0 = rng.uniform(5.4, 6.8)
        base = axis(min(y0, top - 0.3))
        d = Vector((math.cos(a), 0, math.sin(a)))
        tip = crown_c + Vector(d * rx * rng.uniform(0.6, 0.78)) + Vector((0, ry * rng.uniform(0.0, 0.5), 0))
        mid = base.lerp(tip, 0.5) + Vector((0, 0.3, 0)) - d * 0.3
        pts = spline([tuple(base), tuple(mid), tuple(tip)], 3)
        ctx.add(bark, _taper_tube(pts, 0.15, 0.05, 7))
        skeleton += [Vector(q) for q in pts[2:]]
    lead = spline([tuple(axis(top - 0.3)), tuple(axis(top) + Vector((0.05, 1.2, 0.05))),
                   tuple(crown_c + Vector((rng.uniform(-0.3, 0.3), ry * 0.7, rng.uniform(-0.3, 0.3))))], 3)
    ctx.add(bark, _taper_tube(lead, 0.17, 0.05, 7))
    skeleton += [Vector(q) for q in lead[2:]]
    # clumps over the envelope (Fibonacci sphere, jittered; few underneath)
    n_clumps = 30 if not autumn else 34
    clumps = []
    gold = math.pi * (3 - math.sqrt(5))
    for k in range(n_clumps * 2):
        if len(clumps) >= n_clumps:
            break
        yy = 1 - 2 * (k + 0.5) / (n_clumps * 2)
        if yy < -0.55 or (autumn and rng.random() < 0.25):
            continue
        rr = math.sqrt(1 - yy * yy)
        th = gold * k + rng.uniform(-0.3, 0.3)
        d = Vector((rr * math.cos(th), yy, rr * math.sin(th)))
        f = rng.uniform(0.72, 0.95)
        c = crown_c + Vector((d.x * rx * f, d.y * ry * f, d.z * rx * f))
        clumps.append((c, rng.uniform(0.55, 0.85) * (0.75 if autumn else 1.0)))
    if not autumn:  # (an inner shell: no sky through the middle of a summer crown)
        for k in range(8):
            a = TAU * k / 8 + rng.uniform(-0.2, 0.2)
            c = crown_c + Vector((math.cos(a) * rx * 0.42, rng.uniform(-0.45, 0.2) * ry, math.sin(a) * rx * 0.42))
            clumps.append((c, rng.uniform(0.75, 0.95)))
    leaves = bmesh.new()
    for ci, (c, r) in enumerate(clumps):
        blob = _blob(r * (0.85 if not autumn else 0.7), noise, squash=0.7, seed=ci * 1.7)
        _transform(blob, T(*c))
        merge_into(leaves, blob)
        # a twig from the nearest limb point to the clump
        near = min(skeleton, key=lambda q: (q - c).length)
        mid = near.lerp(c, 0.5) + Vector((0, 0.15, 0))
        ctx.add(bark, _taper_tube([tuple(near), tuple(mid), tuple(c - (c - near).normalized() * r * 0.5)], 0.045, 0.018, 4))
    per = (850 if not autumn else 860) // max(1, len(clumps))
    for ci, (c, r) in enumerate(clumps):
        out = c - crown_c
        out = Vector((out.x / rx, out.y / ry, out.z / rx))
        for k in range(per):
            d = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
            if d.dot(out) < -0.1:
                d = (d - out * (2 * d.dot(out))).normalized()
            p = c + Vector((d.x, d.y * 0.7, d.z)) * r * rng.uniform(0.85, 1.18)
            n = (d * 1.2 + out * 0.6 + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.3, 0.5), rng.uniform(-0.5, 0.5)))).normalized()
            _leaf_card(leaves, p, n, rng.uniform(0.2, 0.3) if not lime else rng.uniform(0.17, 0.25), rng)
    if lime:  # epicormic shoots round the foot: little leafy twigs
        for k in range(7):
            a = rng.uniform(0, TAU)
            p0 = Vector((0.33 * math.cos(a), rng.uniform(0.1, 0.8), 0.33 * math.sin(a)))
            p1 = p0 + Vector((math.cos(a) * 0.4, 0.55, math.sin(a) * 0.4))
            ctx.add(bark, _taper_tube([tuple(p0), tuple((p0 + p1) / 2 + Vector((0, 0.05, 0))), tuple(p1)], 0.025, 0.01, 4))
            for j in range(4):
                _leaf_card(leaves, p1 + Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.25, 0.1), rng.uniform(-0.2, 0.2))),
                           (rng.uniform(-1, 1), 1, rng.uniform(-1, 1)), 0.2, rng, both=True)
    if autumn:  # fallen leaves on the grass, thicker near the trunk, none under it
        for k in range(150):
            a = rng.uniform(0, TAU)
            rr = 0.6 + abs(rng.gauss(0, 1.6))
            p = Vector((math.cos(a) * rr, 0.03 + rng.uniform(0, 0.02), math.sin(a) * rr))
            _leaf_card(leaves, p, (rng.uniform(-0.3, 0.3), 1, rng.uniform(-0.3, 0.3)), rng.uniform(0.14, 0.22), rng)
    ctx.add(LEAF, leaves)
    # ---- the young plane's stakes and tree ties
    if kind == "plane":
        for sgn in (-1, 1):
            st = rbox(0.18, 4.2, 0.18, r=0.03, m=1, n=(1, 4, 1))
            ctx.add("WoodDark", st, T(sgn * 0.85, 2.0, 0.1 * sgn) @ R(0, 0, -sgn * 2))
            ctx.add("WoodDark", _transform(cyl(0.11, 0.02, segs=6), T(0, 0, 0)), T(sgn * 0.85 - sgn * 0.075, 4.11, 0.1 * sgn))
        ctx.add("WoodDark", rbox(1.95, 0.14, 0.1, r=0.03, m=1), T(0, 3.55, 0.0))
        ctx.add("Rubber", tube([(-0.9, 3.42, -0.06), (-0.5, 3.38, -0.32), (0.0, 3.38, -0.36), (0.5, 3.38, -0.32), (0.9, 3.42, -0.06)],
                               0.035, segs=6))
    # ---- wear: bark, leaves
    def bark_c(p):
        x, y, z = p.co
        g = 0.82 + 0.18 * noise.fbm(Vector((x * 6, y * 1.5, z * 6)), 3)
        c = [g * 0.8, g * 0.78, g * 0.76] if lime else [g * 0.86, g * 0.86, g * 0.8]
        if kind == "plane" or (autumn and not lime):  # (plane bark: flaking cream / olive patches)
            m = noise.fbm(Vector((x * 2.2, y * 1.1, z * 2.2)) + Vector((4, 0, 1)), 2)
            if m > 0.15:
                c = [c[0] * 1.08, c[1] * 1.12, c[2] * 1.05]
            elif m < -0.2:
                c = [c[0] * 0.78, c[1] * 0.8, c[2] * 0.7]
        moss = (1 - smoothstep(0.0, 1.6, y)) * smoothstep(-0.2, 0.6, z + 0.2 * noise.n(p.co * 3))
        c = [c[0] * (1 - 0.3 * moss), c[1] * (1 - 0.1 * moss), c[2] * (1 - 0.4 * moss)]
        cav = 1 - 0.35 * smoothstep(0.0, 0.5, -p.convex)
        dirt = 1 - 0.25 * (1 - smoothstep(0.0, 0.5, y))
        return tuple(min(1.0, v) * cav * dirt for v in c)

    ctx.wear(bark, bark_c)


    def leaf_c(p):
        x, y, z = p.co
        if y < 0.2:  # fallen leaves: browner, dull
            h = noise.n(p.co * 3.1)
            return (0.62 + 0.1 * h, 0.5 + 0.1 * h, 0.4)
        rel = p.co - crown_c
        depth = smoothstep(0.3, 1.0, Vector((rel.x / rx, rel.y / ry, rel.z / rx)).length)
        lite = 0.55 + 0.35 * depth + 0.15 * smoothstep(-1.0, 2.5, rel.y)
        under = 1 - 0.2 * smoothstep(0.0, -0.8, p.normal.y)
        h = noise.fbm(p.co * 0.55 + Vector((2.0, 0, 7.0)), 2)
        if autumn:  # (dull, mixed: browns and ochres, a few still green-yellow; dark inside)
            c = (lerp(0.78, 1.0, smoothstep(-0.5, 0.5, h)), lerp(0.62, 1.0, smoothstep(-0.4, 0.4, h)),
                 lerp(0.55, 0.85, smoothstep(-0.2, 0.5, h)))
            lite = 0.4 + 0.45 * depth + 0.15 * smoothstep(-1.0, 2.5, rel.y)
        else:
            c = (lerp(0.82, 1.0, smoothstep(-0.5, 0.5, h)), 1.0, lerp(0.75, 1.0, smoothstep(-0.2, 0.6, -h)))
        k = min(1.0, lite * under)
        return tuple(v * k for v in c)

    ctx.wear(LEAF, leaf_c)
    ctx.wear("WoodDark", mul(ground_dirt(0.8, 0.35, noise), cavity(0.3)))
    ctx.wear("Rubber", lambda p: 0.9)


def merge_into(target, bm):
    me = bpy_mesh_from(bm)
    target.from_mesh(me)
    import bpy

    bpy.data.meshes.remove(me)


def bpy_mesh_from(bm):
    import bpy

    me = bpy.data.meshes.new("_tmp")
    bm.to_mesh(me)
    bm.free()
    return me


def tree_plane_young(ctx):
    """Young London plane, ~4 m: flaking camouflage bark, broad crown on ascending limbs, two
    timber stakes with rubber ties."""
    _tree(ctx, "plane")
    ctx.tint(LEAF, (66, 92, 44))


def tree_lime_young(ctx):
    """Young small-leaved lime, ~4.3 m: dark ridged bark, dense ovoid crown, leafy epicormic
    shoots round the foot."""
    _tree(ctx, "lime")
    ctx.tint(LEAF, (60, 88, 42))


def tree_autumn(ctx):
    """A young plane in autumn: thinner crown in orange, rust and yellow with the limbs showing
    through, fallen leaves on the grass round it."""
    _tree(ctx, "autumn")
    ctx.tint(LEAF, (150, 90, 45))


# ==============================================================================================
# FountainTwoTier. Real reference: the cast-stone two-tier fountain of a city square or park
# (Victorian / Beaux-Arts: Bethesda's little sisters, the fountains of London's squares): an
# octagonal basin 5-6 m across with a moulded coping you can sit on, a turned baluster
# pedestal in the middle with lion masks spouting into the basin, a wide shallow upper bowl
# with a gadrooned underside overflowing in thin streams, an urn finial the jet rises from.
# Typical wear: green algae at the waterline and wherever the water runs, black damp streaks
# under the bowl, the coping's top worn and stained by people sitting, coins on the bottom.
# City footprint (Park plaza, 1): FountainBase a disc r 5.0, y 0..0.55 over the plaza
# (collides); eight FountainRim boxes = an octagon of inradius 4.2..5.0, tops 1.75 / 1.83
# (collide); FountainColumn r 0.55 up to 4.2 (collides); bowl r 1.7 4.2..4.7. The data's water
# (FountainWater discs r 4.4 at 1.25, r 1.45 at 4.8) and its jet / spray stay real parts: the
# basin's inner face is round (r 4.3) so the water's edge hides in the wall; the upper bowl's
# lip (4.92) stands over its water.
# ==============================================================================================
def fountain_two_tier(ctx):
    """Two-tier cast-stone fountain: octagonal basin with a moulded coping, baluster pedestal
    with four lion-mask spouts, gadrooned upper bowl with a notched lip, urn finial; coins
    on the bottom. 5.6 m across."""
    noise, rng = ctx.noise, ctx.rng
    ctx.budget = 8000
    # ---- the plinth step (round, on the plaza)
    ctx.add("Concrete", lathe([(0.0, 0.0), (5.08, 0.0), (5.08, 0.42), (5.03, 0.5), (4.96, 0.55), (0.0, 0.55)], segs=48))
    # ---- basin wall: octagonal outside (facets facing 22.5 + 45k degrees like the data's rims)
    outer = [(4.98, 0.5), (4.98, 0.62), (4.93, 0.68), (4.93, 1.42), (4.98, 1.48), (5.06, 1.56), (5.06, 1.66),
             (4.98, 1.76), (4.8, 1.82), (4.55, 1.83), (4.4, 1.8)]
    wall_o = oct_lathe(outer, sides=8, a0=0.0)
    ctx.add("Concrete", wall_o)
    # inside: round, from the coping's inner edge down to the floor (under the water)
    # (a round band under the coping's inner edge joins the octagonal top to the round inner face)
    ctx.add("Concrete", lathe([(4.42, 1.805), (4.31, 1.76), (4.3, 1.7), (4.3, 0.6), (4.6, 0.6), (4.6, 1.805)][::-1], segs=48))
    ctx.add("Concrete", lathe([(0.0, 0.58), (4.35, 0.58), (4.35, 0.64), (0.0, 0.64)], segs=48))
    # ---- pedestal: a turned baluster (gadrooned foot, belly, neck, capital) to the upper bowl
    prof = [(0.0, 0.63), (0.92, 0.63), (0.92, 0.8), (0.85, 0.88), (0.72, 0.95), (0.7, 1.1), (0.62, 1.2), (0.6, 1.4),
            (0.66, 1.7), (0.7, 2.0), (0.66, 2.35), (0.55, 2.7), (0.44, 3.0), (0.4, 3.3), (0.46, 3.42), (0.42, 3.5),
            (0.42, 3.7), (0.52, 3.8), (0.62, 3.95), (0.66, 4.05), (0.0, 4.05)]
    gad = lambda a, r, y: r + (0.035 * math.cos(16 * a) if 0.95 < y < 1.25 else 0.0)  # noqa: E731
    ctx.add("Concrete", lathe(prof, segs=32, radius_fn=gad))
    # lion masks (four roundels with a muzzle and mane ring) spouting into the basin
    for k in range(4):
        a = math.radians(45 + 90 * k)
        d = Vector((math.cos(a), 0, math.sin(a)))
        y = 2.05
        rad = 0.7
        m = T(*(d * (rad - 0.05) + Vector((0, y, 0)))) @ R(0, -math.degrees(a) + 90, 0) @ R(90, 0, 0)
        mane = lathe([(0.0, 0.0), (0.3, 0.0), (0.32, 0.05), (0.28, 0.1), (0.2, 0.13), (0.0, 0.12)], segs=14,
                     radius_fn=lambda aa, r, yy: r * (1 + 0.1 * math.cos(9 * aa)) if r > 0.25 else r)
        ctx.add("Concrete", mane, m)
        ctx.add("Concrete", _transform(sphere(0.11, 10, 6), S(1, 0.8, 1.2)), m @ T(0, 0.15, 0.04))
        sp = [d * (rad + 0.18) + Vector((0, y - 0.02, 0)), d * (rad + 0.32) + Vector((0, y - 0.05, 0))]
        ctx.add("Metal", tube([tuple(q) for q in sp], 0.035, segs=8))
    # ---- upper bowl: wide and shallow, gadrooned underneath, a lip with eight notches
    bowl = [(0.0, 3.98), (0.7, 3.98), (0.75, 4.05), (1.0, 4.15), (1.35, 4.3), (1.62, 4.5), (1.78, 4.7), (1.84, 4.82),
            (1.82, 4.92), (1.74, 4.94), (1.68, 4.86), (1.5, 4.72), (1.1, 4.64), (0.0, 4.62)]

    def gadroon(a, r, y):
        if y < 4.55 and r > 0.8:
            r += 0.05 * max(0.0, math.cos(24 * a)) * smoothstep(0.8, 1.4, r)
        if y > 4.88:  # (the notches the overflow runs from)
            y -= 0.035 * max(0.0, math.cos(8 * a)) ** 16
        return (r, y)

    ctx.add("Concrete", lathe(bowl, segs=48, radius_fn=gadroon))
    # ---- urn finial in the bowl, the jet comes out of its mouth
    urn = [(0.0, 4.6), (0.3, 4.6), (0.32, 4.66), (0.2, 4.74), (0.16, 4.85), (0.24, 4.98), (0.27, 5.08), (0.24, 5.18),
           (0.17, 5.24), (0.2, 5.28), (0.2, 5.32), (0.14, 5.32), (0.12, 5.2), (0.0, 5.2)]
    ctx.add("Concrete", lathe(urn, segs=20, radius_fn=lambda a, r, y: r + (0.015 * math.cos(12 * a) if 4.95 < y < 5.15 else 0)))
    ctx.add("Metal", cyl(0.06, 0.12, segs=8), T(0, 5.24, 0))
    # ---- coins on the bottom
    for k in range(14):
        a = rng.uniform(0, TAU)
        rr = rng.uniform(1.2, 4.0)
        ctx.add("Metal", cyl(0.06, 0.012, segs=6), T(rr * math.cos(a), 0.647, rr * math.sin(a)) @ R(rng.uniform(-6, 6), 0, 0))
    sw = stone_wear(noise, damp_h=0.6, damp=0.3, green=0.35, speck=0.08)

    def stone(p):
        c = sw(p)
        x, y, z = p.co
        rr = math.hypot(x, z)
        k = 1.0
        g = 0.0
        if rr < 4.36 and y < 1.8:  # inside the basin: algae up to the waterline, black below
            g = smoothstep(1.6, 1.15, y)
            k *= 1 - 0.35 * smoothstep(1.3, 0.9, y)
        if 1.0 < y < 4.1 and rr < 1.0:  # the pedestal, wet from the masks and the overflow
            g = max(g, 0.6 * smoothstep(0.2, 0.7, noise.fbm(Vector((x * 4, y * 0.8, z * 4)), 2) + 0.4))
        if 4.0 < y < 4.75 and rr > 0.9:  # dark drip streaks under the bowl
            k *= 1 - 0.3 * smoothstep(0.55, 0.85, noise.fbm(Vector((x * 7, y, z * 7)), 2) * 0.5 + 0.5)
        if y > 1.7 and rr > 4.3:  # the coping top: polished by sitters, dark rings of dirt
            k *= 0.92 + 0.08 * noise.fbm(p.co * 3, 2)
        return (c[0] * k * (1 - 0.35 * g), c[1] * k * (1 - 0.1 * g), c[2] * k * (1 - 0.45 * g))

    ctx.wear("Concrete", stone)
    ctx.wear("Metal", lambda p: (0.85, 0.72, 0.5) if p.co.y < 1 else (0.7, 0.75, 0.68))


# ==============================================================================================
# BandstandVictorian. Real reference: the octagonal Victorian bandstand of a city park (Walter
# Macfarlane's Saracen Foundry catalogue, the bandstands of Clapham Common, Hyde Park, Boston
# Common): a brick plinth with a stone base course and coping, a boarded timber deck, eight
# slender cast-iron columns with moulded bases and bell capitals, pierced spandrel brackets
# arching between them under the frieze, cast railings with ring motifs between the columns
# (open on the side of the steps), a cream-painted timber frieze and scalloped valance under the
# eaves, an ogee (bell-cast) roof with roll hips, a little lantern and a finial. Green and
# cream. Typical wear: grime on the plinth and green damp on its base course, the deck boards
# grey and worn in the middle, rust weeping at the column bases and railing feet, the valance's
# paint flaking, moss and dirt on the roof's lower edge.
# City footprint (Park, 1; a fight spot): BandstandFloor a disc r 5.2, y 0..1.5 over the
# ground (collides); deck to 1.56; eight columns r 0.18 at radius 4.6, angles 22.5 + 45k,
# 1.56..8.5 (collide); railings on the facets 45k except the east one (+X: the steps, x
# 4.6..6.4, two 0.5 risers, collide); beam disc r 5 at 8.5..8.9; roof to 11.5, finial to 12.5.
# ==============================================================================================
def _oct_chord(a, x):
    """Half-length (along z) of the octagon of inradius a (facets facing 0, 45, 90... degrees)
    at x."""
    return max(0.0, min(a, math.sqrt(2) * a - abs(x)))


def bandstand_victorian(ctx):
    """Octagonal Victorian bandstand: brick plinth with stone coping, boarded deck, eight
    cast-iron columns with spandrel brackets, ring-motif railings, cream frieze and scalloped
    valance, ogee roof with roll hips, lantern and finial; stone steps on the east. 3 m across,
    3.5 m high."""
    noise, rng = ctx.noise, ctx.rng
    ctx.budget = 8000
    paint = "MetalPainted"
    A0 = math.pi / 8  # (octagon corners at 22.5 + 45k: the columns stand on them)
    # ---- plinth: stone base course, brick body, stone coping (all octagonal, inradius ~5.0)
    ctx.add("Concrete", oct_lathe([(0.0, 0.0), (5.06, 0.0), (5.06, 0.3), (5.0, 0.36), (4.95, 0.38), (0.0, 0.38)], 8, a0=A0))
    ctx.add("Brick", oct_lathe([(0.0, 0.36), (4.92, 0.36), (4.92, 1.2), (0.0, 1.2)], 8, a0=A0))
    ctx.add("Concrete", oct_lathe([(0.0, 1.18), (4.96, 1.18), (5.02, 1.26), (5.08, 1.36), (5.08, 1.44), (5.02, 1.5),
                                   (0.0, 1.5)], 8, a0=A0))
    # ---- deck boards (along Z), cut to the octagon
    ia = 4.78
    xs = [-ia + 0.4 + 0.8 * k for k in range(12)]
    for x in xs:
        hz = _oct_chord(ia, x)
        if hz < 0.3:
            continue
        ctx.add("Wood", box(0.76, 0.07, hz * 2 - 0.06), T(x, 1.535, 0))
    # (the perimeter board round the deck: it covers the boards' cut ends; the columns stand on it)
    ctx.add("WoodDark", oct_lathe([(4.0, 1.5), (4.86, 1.5), (4.86, 1.6), (4.0, 1.6)], 8, a0=A0))
    # ---- steps on the east (+X): stone, matching the data's risers
    ctx.add("Concrete", rbox(1.86, 0.5, 3.3, r=0.04, m=1, n=(3, 1, 4)), T(5.5, 0.25, 0))
    ctx.add("Concrete", rbox(1.26, 0.5, 3.3, r=0.04, m=1, n=(2, 1, 4)), T(5.2, 0.75, 0))
    # ---- columns: moulded base, slender fluted shaft, bell capital with an abacus
    cols = []
    for k in range(8):
        a = A0 + TAU * k / 8
        cols.append(Vector((4.6 * math.cos(a), 0, 4.6 * math.sin(a))))
    colp = [(0.0, 1.56), (0.3, 1.56), (0.3, 1.72), (0.22, 1.84), (0.18, 2.0), (0.165, 3.5), (0.21, 3.6), (0.16, 3.72),
            (0.15, 7.7), (0.19, 7.8), (0.27, 8.12), (0.36, 8.3), (0.36, 8.42), (0.0, 8.42)]
    for c in cols:
        ctx.add(paint, lathe(colp, segs=8), T(c.x, 0, c.z))
    # ---- spandrel brackets between the columns: an arched rib and two scrolls per bay
    for k in range(8):
        c0, c1 = cols[k], cols[(k + 1) % 8]
        mid = (c0 + c1) / 2
        u = (c1 - c0).normalized()
        arch = [c0 + u * 0.18 + Vector((0, 7.2, 0)), c0.lerp(c1, 0.25) + Vector((0, 7.9, 0)), mid + Vector((0, 8.12, 0)),
                c0.lerp(c1, 0.75) + Vector((0, 7.9, 0)), c1 - u * 0.18 + Vector((0, 7.2, 0))]
        ctx.add(paint, tube(spline([tuple(q) for q in arch], 2), 0.045, segs=5))
        for end, sgn in ((c0, 1), (c1, -1)):
            pts = [end + u * sgn * (0.2 + 0.45 * (1 - math.cos(t * 2.4))) * (1 - 0.15 * t) + Vector((0, 7.6 + 0.6 * math.sin(t * 2.4) * (1 - t * 0.3), 0))
                   for t in [i / 5 for i in range(6)]]
            ctx.add(paint, tube([tuple(q) for q in pts], 0.03, segs=4))
    # ---- railings: top and bottom rails, bars, a ring in the middle of each bay (not the east)
    for k in range(8):
        c0, c1 = cols[k], cols[(k + 1) % 8]
        mid = (c0 + c1) / 2
        ang = math.degrees(math.atan2(mid.z, mid.x))
        if abs(((ang + 180) % 360) - 180) < 10:
            continue  # (the east bay: the steps)
        u = (c1 - c0).normalized()
        p0, p1 = c0 + u * 0.2, c1 - u * 0.2
        rot = math.degrees(math.atan2(u.x, u.z))
        for y, w in ((4.3, 0.12), (1.75, 0.07)):
            ctx.add(paint, box(0.08, w, (p1 - p0).length, bevel=0.02, segments=1), T(*((p0 + p1) / 2 + Vector((0, y, 0)))) @ R(0, rot, 0))
        n = 11
        for i in range(n):
            t = (i + 0.5) / n
            q = p0.lerp(p1, t)
            if abs(t - 0.5) < 0.1:
                continue
            ctx.add(paint, box(0.045, 2.48, 0.045), T(*(q + Vector((0, 3.02, 0)))) @ R(0, rot, 0))
        ring = torus(0.42, 0.03, segs=14, sides=4)
        ctx.add(paint, ring, T(*(mid + Vector((0, 3.05, 0)))) @ R(0, rot, 0) @ R(0, 0, 90) @ R(0, 90, 0))
        for y0, y1 in ((1.78, 2.63), (3.47, 4.26)):
            ctx.add(paint, box(0.045, y1 - y0, 0.045), T(*(mid + Vector((0, (y0 + y1) / 2, 0)))) @ R(0, rot, 0))
    # ---- frieze: a cream timber band on the column heads, a scalloped valance hung from the eaves
    ctx.add("Paper", oct_lathe([(4.35, 8.42), (4.95, 8.42), (4.95, 8.92), (4.35, 8.92)], 8, a0=A0))
    side = 2 * 5.3 * math.tan(math.pi / 8)
    for k in range(8):
        a = TAU * k / 8  # (facet normals at 45k)
        sc = []
        nsc = 8  # (dagger boarding: a row of points)
        for i in range(nsc * 2 + 1):
            t = i / (nsc * 2)
            x = -side / 2 + side * t
            sc.append((x, 8.42 - (0.2 if i % 2 else 0.04)))
        poly = [(-side / 2, 8.95)] + sc + [(side / 2, 8.95)]
        val = prism([(x, y) for x, y in reversed(poly)], -0.02, 0.02)
        ctx.add("Paper", val, R(0, -math.degrees(a) - 90, 0) @ T(0, 0, -5.28))
    # ---- roof: ogee octagon with roll hips, boarded soffit, a lantern, the finial
    rings = [(5.55, 8.92), (5.6, 8.98), (5.5, 9.06), (5.1, 9.22), (4.5, 9.45), (3.8, 9.75), (3.1, 10.1), (2.4, 10.5),
             (1.75, 10.85), (1.2, 11.1), (0.8, 11.25), (0.62, 11.3)]
    ctx.add(paint, oct_lathe(rings + [(0.0, 11.3)], 8, a0=A0))
    ctx.add("WoodDark", oct_lathe([(0.0, 8.95), (5.4, 8.95), (5.4, 8.97), (0.0, 8.97)][::-1], 8, a0=A0))
    k8 = 1 / math.cos(math.pi / 8)
    for k in range(8):
        a = A0 + TAU * k / 8
        d = Vector((math.cos(a), 0, math.sin(a)))
        hip = [tuple(d * (r * k8) + Vector((0, y + 0.04, 0))) for r, y in rings[1:]]
        ctx.add(paint, tube(hip, 0.06, segs=4))
    lan = [(0.0, 11.28), (0.5, 11.28), (0.5, 11.62), (0.62, 11.66), (0.6, 11.72), (0.4, 11.86), (0.22, 11.98), (0.0, 12.02)]
    ctx.add(paint, oct_lathe(lan, 8, a0=A0))
    fin = [(0.0, 12.0), (0.08, 12.0), (0.12, 12.08), (0.08, 12.16), (0.14, 12.26), (0.12, 12.34), (0.05, 12.38), (0.03, 12.6),
           (0.0, 12.66)]
    ctx.add("Metal", lathe(fin, segs=12))
    ctx.add("Black", oct_lathe([(0.0, 11.36), (0.44, 11.36), (0.44, 11.56), (0.0, 11.56)], 8, a0=A0))  # (the lantern's louvres)
    # ---- wear
    ctx.wear("Concrete", stone_wear(noise, damp_h=0.5, damp=0.3, green=0.45))
    ctx.wear("Brick", mul(lambda p: 0.8 + 0.2 * noise.fbm(p.co * 3, 2) * (1 if math.sin(p.co.y * 25) > -0.7 else 0.6),
                          ground_dirt(0.9, 0.3, noise), cavity(0.3)))
    tw = timber_wear(noise, silver=0.8, rot=0.15)

    def deck(p):
        c = tw(p)
        x, y, z = p.co
        k = 1 - 0.18 * (1 - smoothstep(0.5, 3.2, math.hypot(x, z)))  # (worn darker in the middle)
        return tuple(v * k for v in c)

    ctx.wear("Wood", deck)
    ctx.wear(paint, iron_wear(noise, dirt_h=2.0, dirt=0.25, rust_y=2.2, rust=0.6, flake=0.15))
    ctx.wear("Paper", mul(lambda p: 0.85 + 0.15 * noise.fbm(p.co * 5, 2), streaks(noise, 0.2, 6.0), cavity(0.3)))
    ctx.wear("WoodDark", lambda p: 0.75 if p.co.y > 5 else 0.85 + 0.15 * noise.fbm(p.co * 4, 2))
    ctx.wear("Metal", lambda p: (0.95, 0.82, 0.5))
    ctx.tint(paint, (36, 62, 48))


# ==============================================================================================
# VendingMachine (+Worn). Real reference: the outdoor canned-drinks vending machine of a US city
# (Dixie-Narco / Vendo "full-front" machines): 1.83 m tall, 1.0 m wide, 0.8 m deep, a steel
# cabinet with the front door carrying the big back-lit brand panel in a chrome bezel, the
# selection column on the right (price display, selection buttons, the vend button, the coin
# insert plate, the bill acceptor, the coin return cup), the T-handle lock, the delivery bin
# at the bottom behind a smoked flap ("PUSH"), a louvred kick plate (the back stands against
# a wall in all three places: nothing modelled there). Typical wear: hand grime round the buttons and the coin slot, kick
# scuffs and dirt at the bottom, rain streaks; on the worn one dents in the door, rust at the
# bottom edges, stickers and tags, a selection button gone.
# City footprint (3 machines, Model "SpezColaMachine"): Body 3.6 x 6.85 x 2.8 at y 0.36..7.21
# over the plinth's foot (collides: the proxy), TopCap to 7.46, the Plinth 3.4 x 0.35 x 2.55.
# Kept real parts (not wrapped, the mesh is built round them): the lit Panel 2.2 x 3.6 at
# x -0.65..1.55, y 3.0..6.6, z -1.46..-1.52 (its "SpezCola" sign; the bezel's lip covers its
# edges); the vend Button 0.55 x 0.5 at x -1.22, y 4.3, z -1.46..-1.56 (its prompt); the
# invisible Dispenser (y 1.2, out of the delivery bin) and Hum.
# ==============================================================================================
VM_FRONT = -1.4


def bb(sx, sy, sz, b):
    """A small box with one-segment bevels (cheap trim, buttons, slots)."""
    return box(sx, sy, sz, bevel=b, segments=1)


def _vending(ctx, worn):
    noise, rng = ctx.noise, ctx.rng
    ctx.budget = 7200
    paint = "MetalPainted"
    F = VM_FRONT

    def dent(bm, c, rad, depth):
        for v in bm.verts:
            d = (Vector((v.co.x, v.co.y, 0)) - Vector((c[0], c[1], 0))).length
            if d < rad and v.co.z < 0:
                v.co.z += depth * (1 - (d / rad) ** 2) ** 2
        return bm

    # ---- cabinet (sides, top, back) and the door (front 0.14), a shadow gap between them
    cab = rbox(3.6, 6.85, 2.64, r=0.05, m=2, n=(4, 8, 3))
    if worn:  # (a kicked-in dent on the right side panel, low)
        for v in cab.verts:
            d = math.hypot(v.co.y + 2.2, v.co.z - 0.2)
            if v.co.x < -1.7 and d < 0.8:
                v.co.x += 0.08 * (1 - (d / 0.8) ** 2)
    ctx.add(paint, cab, T(0, 3.785, 0.08))
    door = rbox(3.56, 6.81, 0.15, r=0.04, m=2, n=(8, 14, 1))
    _transform(door, T(0, 0, 0))
    if worn:
        dent(door, (0.9, -2.3), 0.55, 0.07)
        dent(door, (-0.2, -2.9), 0.35, 0.05)
    ctx.add(paint, door, T(0, 3.785, F + 0.075))
    # top cap with a drip edge
    ctx.add(paint, rbox(3.7, 0.25, 2.85, r=0.06, m=2, n=(3, 1, 3)), T(0, 7.335, -0.025))
    # ---- plinth and the louvred kick plate
    ctx.add("PlasticDark", bb(3.4, 0.36, 2.55, 0.03), T(0, 0.18, 0.05))
    for k in range(7):
        x = -1.35 + k * 0.45
        ctx.add("Black", bb(0.32, 0.05, 0.04, 0.015), T(x, 0.5, F - 0.005))
        ctx.add("Black", bb(0.32, 0.05, 0.04, 0.015), T(x, 0.62, F - 0.005))
    # ---- the bezel round the lit brand panel (the data's Panel sits in it)
    bz = "Chrome"
    x0, x1, y0, y1 = -0.75, 1.65, 2.9, 6.7
    ix0, ix1, iy0, iy1 = -0.6, 1.5, 3.05, 6.55
    zc, zt = F - 0.08, 0.16
    ctx.add(bz, bb(x1 - x0, y1 - iy1, zt, 0.03), T((x0 + x1) / 2, (y1 + iy1) / 2, zc))
    ctx.add(bz, bb(x1 - x0, iy0 - y0, zt, 0.03), T((x0 + x1) / 2, (y0 + iy0) / 2, zc))
    ctx.add(bz, bb(ix0 - x0, iy1 - iy0 - 0.002, zt, 0.03), T((x0 + ix0) / 2, (iy0 + iy1) / 2, zc))
    ctx.add(bz, bb(x1 - ix1, iy1 - iy0 - 0.002, zt, 0.03), T((ix1 + x1) / 2, (iy0 + iy1) / 2, zc))
    # ---- the selection column (viewer's right, x -1.62..-0.82), its face at z F - 0.05
    cx = -1.22
    ctx.add("PlasticDark", rbox(0.8, 3.8, 0.07, r=0.025, m=1, n=(1, 4, 1)), T(cx, 4.8, F - 0.015))
    face = F - 0.05
    ctx.add("Screen", bb(0.56, 0.22, 0.03, 0.01), T(cx, 6.38, face - 0.01))
    for row in range(3):
        for col in range(2):
            if worn and row == 1 and col == 0:
                ctx.add("Black", bb(0.24, 0.16, 0.02, 0.005), T(cx - 0.17 + 0.34 * col, 5.95 - 0.3 * row, face - 0.005))
                continue
            ctx.add("Paper", bb(0.24, 0.16, 0.05, 0.02), T(cx - 0.17 + 0.34 * col, 5.95 - 0.3 * row, face - 0.02))
    # bill acceptor (black bezel, slot, green LED) under the selection buttons, above the vend button
    ctx.add("Black", bb(0.5, 0.26, 0.09, 0.02), T(cx, 4.9, face - 0.04))
    ctx.add("Glow", bb(0.05, 0.03, 0.02, 0.005), T(cx + 0.18, 4.98, face - 0.09))
    # coin insert plate with its slot, coin return button, coin return cup
    ctx.add("Chrome", rbox(0.5, 0.48, 0.05, r=0.02, m=1, n=(2, 2, 1)), T(cx, 3.5, face - 0.02))
    ctx.add("Black", bb(0.06, 0.2, 0.02, 0.005), T(cx, 3.58, face - 0.05))
    ctx.add("Chrome", cyl(0.07, 0.05, segs=12), T(cx, 3.17, face - 0.02) @ R(90, 0, 0))
    cup = rbox(0.42, 0.3, 0.12, r=0.04, m=2, n=(1, 1, 1))
    ctx.add("Chrome", cup, T(cx, 2.65, face - 0.05))
    ctx.add("Black", bb(0.3, 0.17, 0.02, 0.02), T(cx, 2.67, face - 0.115))
    # T-handle lock on the door's edge
    ctx.add("Chrome", cyl(0.08, 0.06, segs=12), T(-1.7, 5.0, F - 0.03) @ R(90, 0, 0))
    ctx.add("Chrome", bb(0.06, 0.32, 0.06, 0.025), T(-1.7, 5.0, F - 0.09))
    # ---- delivery bin: a recessed black frame, the smoked flap tilted in, PUSH on it
    ctx.add("PlasticDark", bb(2.9, 0.12, 0.12, 0.03), T(0, 1.69, F - 0.04))
    ctx.add("PlasticDark", bb(2.9, 0.12, 0.12, 0.03), T(0, 0.81, F - 0.04))
    for sx in (-1.39, 1.39):
        ctx.add("PlasticDark", bb(0.12, 0.76, 0.12, 0.03), T(sx, 1.25, F - 0.04))
    ctx.add("Black", bb(2.66, 0.76, 0.03, 0.01), T(0, 1.25, F + 0.06) @ R(-8, 0, 0))
    push = text_bm("PUSH", 0.16, 0.02)
    ctx.add("Paper", push, T(0, 1.35, F + 0.03) @ R(-8, 0, 0) @ R(0, 180, 0))
    # (the back stands against a wall: no grille or cord there, the vents are under the kick plate)
    # ---- stickers and tags on the worn one (and one service sticker on every machine)
    sticks = [(0.9, 6.95, 0.7, 0.18)]
    if worn:
        sticks += [(1.2, 2.55, 0.5, 0.42), (0.4, 2.3, 0.36, 0.36), (-0.4, 2.65, 0.5, 0.2), (-1.22, 1.95, 0.42, 0.3)]
    for x, y, w, h in sticks:
        st = rbox(w, h, 0.012, r=0.004, m=1, n=(2, 3, 1))
        ctx.add("Paper", st, T(x, y, F - 0.006) @ R(0, 0, rng.uniform(-8, 8)))
    if worn:  # (a sticker on the side and one on the bezel)
        ctx.add("Paper", bb(0.012, 0.6, 0.5, 0.004), T(1.806, 2.9, 0.4))
        ctx.add("Paper", bb(0.4, 0.14, 0.012, 0.004), T(1.2, 2.97, F - 0.166) @ R(0, 0, 4))
    # ---- wear
    pw = iron_wear(noise, dirt_h=1.1, dirt=0.45, rust_y=0.9 if worn else 0.5, rust=0.9 if worn else 0.3,
                   flake=0.0, scale=2.0)

    def cabinet(p):
        c = list(pw(p))
        x, y, z = p.co
        # hand grime round the selection column and the coin plate
        h = math.exp(-(((x + 1.0) / 0.7) ** 2) - ((y - 4.3) / 1.4) ** 2) * (1 if z < F + 0.2 else 0.3)
        k = 1 - 0.25 * h
        # kick scuffs low on the door
        k *= 1 - (0.35 if worn else 0.2) * smoothstep(0.55, 0.8, noise.fbm(Vector((x * 3, y * 6, z)), 2) * 0.5 + 0.5) * (1 - smoothstep(0.6, 1.6, y))
        # the top: dust and soot, darker
        if y > 7.1:
            k *= 0.78
        if worn:  # tags scratched through the paint (lighter scribbles: primer)
            t = noise.ridge(Vector((x * 4.5, y * 2.5, z * 4.5)))
            if 2.0 < y < 3.2 and z < F + 0.2 and t > 0.96:
                c = [c[0] * 0.75, c[1] * 1.0, c[2] * 1.0]
        return tuple(v * k for v in c)

    ctx.wear(paint, cabinet)
    ctx.wear("Chrome", mul(lambda p: 0.75 + 0.2 * noise.fbm(p.co * 6, 2), cavity(0.4)))
    ctx.wear("PlasticDark", mul(ground_dirt(0.6, 0.3, noise), cavity(0.3)))
    inks = [(1.0, 1.0, 1.0), (1.0, 0.92, 0.45), (0.75, 0.85, 1.0), (1.0, 0.7, 0.6)]

    def paper(p):
        x, y, z = p.co
        if abs(x + 1.22) < 0.4 and 5.0 < y < 6.2:  # (selection buttons: cream, rubbed)
            return 0.9 + 0.08 * noise.n(p.co * 9)
        c = inks[int(abs(x * 3.1 + y * 1.7)) % len(inks)]
        k = 0.92 + 0.08 * noise.fbm(p.co * 9, 2)
        band = math.sin(y * 38 + x * 2)  # (lines of print)
        if band > 0.55:
            k *= 0.5
        return tuple(v * k for v in c)

    ctx.wear("Paper", paper)


def vending_machine(ctx):
    """Outdoor drinks vending machine: steel cabinet, chrome bezel for the lit brand panel,
    selection column (price display, buttons, bill acceptor, coin plate, return cup), T-handle
    lock, delivery bin with a PUSH flap, louvred kick plate. 2 m."""
    _vending(ctx, worn=False)
    ctx.tint("MetalPainted", (172, 26, 32))


def vending_machine_worn(ctx):
    """The same machine kicked about: dented door and side, rust at the bottom, stickers and
    scratched tags, a selection button missing."""
    _vending(ctx, worn=True)
    ctx.tint("MetalPainted", (160, 30, 34))


# ==============================================================================================
# FlowerClump A-D. Real reference: a council flower bed's bedding plants, one clump per old
# "Flowers" cube (1 x 0.4-0.7 x 1 studs, 33 of them in five beds): a low mound of bark mulch,
# a rosette of leaves spilling out over it, stems carrying the heads at 0.3-0.7 studs (10-20 cm).
#   A  zonal geraniums: rounded leaves, tight balls of brick-red florets on bare stalks;
#   B  French marigolds: low, ferny leaves, orange-yellow double heads;
#   C  petunias: sprawling, sticky leaves, magenta-purple trumpets spilling over the edge;
#   D  a tired clump of white daisies late in the season: some heads gone brown, stems lying.
# Leaves and stems are the Leaves layer (tinted per copy), petals Paper coloured per kind by
# vertex colour (muted, never candy), centres LensAmber or Soil, mulch Soil. Pure decoration:
# nothing collides (the old cubes did not either). Footprint ~1.1 x 1.1 at scale 1 (the
# narrowest bed's soil is 1.2 wide), origin on the soil's top.
# ==============================================================================================
FLOWER_KINDS = {
    #     petal rgb mul      heads  stem h       leaves  petals spread  centre
    "A": ((0.74, 0.26, 0.22), 10, (0.28, 0.48), 46, 0, 0.5, None),
    "B": ((1.0, 0.66, 0.24), 16, (0.14, 0.28), 60, 8, 0.5, "LensAmber"),
    "C": ((0.6, 0.3, 0.62), 18, (0.1, 0.24), 52, 5, 0.56, None),
    "D": ((0.95, 0.93, 0.86), 13, (0.22, 0.45), 40, 9, 0.52, "LensAmber"),
}


def _blade(bm, base, d, length, width, rng, droop=0.25):
    """A leaf blade from `base` along direction d (both faces): a pointed oval bent down along
    its midrib, 5 points."""
    d = Vector(d).normalized()
    side = d.cross(Vector((0, 1, 0)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(d).normalized()
    mid = base + d * length * 0.5 + up * length * 0.06 - Vector((0, droop * length * 0.15, 0))
    tip = base + d * length - Vector((0, droop * length * 0.5, 0))
    w = width * rng.uniform(0.8, 1.1)
    pts = [base, mid + side * w * 0.5, tip, mid - side * w * 0.5]
    pts = [p.copy() for p in pts]
    pts.insert(1, base + d * length * 0.22 + side * w * 0.32)
    pts.append(base + d * length * 0.22 - side * w * 0.32)
    front = [bm.verts.new(p) for p in pts]
    bm.faces.new(front)
    back = [bm.verts.new(p - up * 0.004) for p in pts]
    bm.faces.new(list(reversed(back)))


def _head(bm, c, n, r, petals, rng, cup=0.0):
    """A flower head facing n at c: `petals` rounded petals as one star outline (both faces);
    cup > 0 turns the petal tips up (a trumpet / a cupped head)."""
    n = Vector(n).normalized()
    u = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
    w = n.cross(u)
    a0 = rng.uniform(0, TAU)
    pts = []
    step = TAU / petals
    for k in range(petals):
        a = a0 + step * k
        rr = r * rng.uniform(0.88, 1.08)
        # (valley, shoulder, tip, shoulder: a rounded petal, not a star point)
        for da, f, up in ((-0.5, 0.42, 0.0), (-0.22, 0.92, 0.8), (0.0, 1.0, 1.0), (0.22, 0.92, 0.8)):
            q = a + da * step
            pts.append(c + (u * math.cos(q) + w * math.sin(q)) * rr * f + n * cup * rr * f * up)
    front = [bm.verts.new(p) for p in pts]
    bm.faces.new(front)
    back = [bm.verts.new(p - n * 0.004) for p in pts]
    bm.faces.new(list(reversed(back)))


def _flower_clump(ctx, kind):
    noise, rng = ctx.noise, ctx.rng
    col, heads, stem_h, n_leaves, petals, spread, centre = FLOWER_KINDS[kind]
    ctx.smooth_angle = 80.0
    # mulch mound (bark chips: lumpy, dark), a little proud of the bed's soil
    prof = [(0.0, 0.07)] + [(spread * k / 4, 0.07 * (1 - (k / 4) ** 2) - 0.012) for k in range(1, 5)] + [(0.0, -0.012)]

    def lump(a, r, y):
        return r * (1 + 0.12 * noise.n(Vector((math.cos(a) * 2, y * 9, math.sin(a) * 2)))), y + 0.012 * noise.n(Vector((a, r * 7, 1.0)))

    ctx.add("Soil", lathe(prof, 12, radius_fn=lump))
    leaves = bmesh.new()
    # the rosette: blades from near the centre spilling outward and down over the mulch
    for k in range(n_leaves):
        a = TAU * k / n_leaves + rng.uniform(-0.2, 0.2)
        rr = rng.uniform(0.02, 0.18)
        base = Vector((math.cos(a) * rr, rng.uniform(0.04, 0.12) + (0.06 if k % 3 == 0 else 0.0), math.sin(a) * rr))
        rise = rng.uniform(0.15, 0.7) if kind != "C" else rng.uniform(0.0, 0.35)
        d = Vector((math.cos(a), rise, math.sin(a)))
        length = rng.uniform(0.2, 0.28) if kind == "A" else rng.uniform(0.22, 0.36) * (1.15 if kind == "C" else 1.0)
        width = {"A": 0.26, "B": 0.09, "C": 0.15, "D": 0.08}[kind]
        _blade(leaves, base, d, length, width, rng, droop=0.35 if kind in ("C", "D") else 0.2)
    flowers = bmesh.new()
    middles = bmesh.new()
    dead = bmesh.new()
    for k in range(heads):
        a = rng.uniform(0, TAU)
        rr = math.sqrt(rng.random()) * spread * 0.72
        h = rng.uniform(*stem_h)
        tilt = Vector((math.cos(a), 0, math.sin(a))) * (rr / spread) * 0.5
        top = Vector((math.cos(a) * rr, 0.08 + h, math.sin(a) * rr)) + tilt * h * 0.4
        drooping = kind == "D" and rng.random() < 0.3
        if drooping:  # (a stem gone over: lying out over the edge)
            top = Vector((math.cos(a) * (rr + 0.25), 0.1 + h * 0.3, math.sin(a) * (rr + 0.25)))
        base = Vector((math.cos(a) * rr * 0.3, 0.06, math.sin(a) * rr * 0.3))
        mid = base.lerp(top, 0.5) + Vector((0, 0.03, 0))
        merge_into(leaves, tube([tuple(base), tuple(mid), tuple(top)], 0.011, 3, cap=False))
        face = (top - base).normalized().lerp(Vector((0, 1, 0)), 0.6)
        if kind == "A":  # a ball of florets: three crossed star cards
            for j in range(3):
                nn = Vector((rng.uniform(-1, 1), rng.uniform(0.2, 1), rng.uniform(-1, 1)))
                _head(flowers, top + Vector((0, 0.05, 0)), nn, 0.08, 5, rng, cup=0.3)
            continue
        is_dead = kind == "D" and rng.random() < 0.28
        r = {"B": 0.075, "C": 0.08, "D": 0.07}[kind]
        _head(dead if is_dead else flowers, top, face, r * (0.7 if is_dead else 1.0), petals, rng,
              cup=0.5 if kind == "C" else 0.12)
        if centre and not is_dead:
            _head(middles, top + face * 0.012, face, r * 0.3, 4, rng)
    ctx.add(LEAF, leaves)
    ctx.add("Paper", flowers)
    if middles.verts:
        ctx.add(centre, middles)
    else:
        middles.free()
    if dead.verts:
        ctx.add("Soil", dead)
    else:
        dead.free()

    def leaf_c(p):
        y = p.co.y
        lite = 0.6 + 0.4 * smoothstep(0.0, 0.3, y)
        h = noise.n(p.co * 7.0)
        yellow = 1.0 + (0.12 if kind == "D" else 0.04) * h
        return (min(1.0, lite * yellow), lite, lite * (0.85 + 0.1 * h))

    def petal_c(p):
        h = 0.88 + 0.12 * noise.n(p.co * 13.0)
        return tuple(min(1.0, c * h) for c in col)

    ctx.wear(LEAF, leaf_c)
    ctx.wear("Paper", petal_c)
    ctx.wear("Soil", lambda p: 0.75 + 0.2 * noise.n(p.co * 9.0))
    ctx.wear("LensAmber", lambda p: 0.85)
    ctx.budget = 2500


def flower_clump_a(ctx):
    """Bedding geraniums: a rosette of rounded leaves on a mulch mound, balls of brick-red
    florets on bare stalks."""
    _flower_clump(ctx, "A")
    ctx.tint(LEAF, (58, 82, 42))


def flower_clump_b(ctx):
    """French marigolds: a low clump of fine leaves, orange-yellow heads with darker centres."""
    _flower_clump(ctx, "B")
    ctx.tint(LEAF, (56, 80, 40))


def flower_clump_c(ctx):
    """Petunias: sprawling leaves spilling over the bed's edge, muted magenta trumpets."""
    _flower_clump(ctx, "C")
    ctx.tint(LEAF, (60, 84, 44))


def flower_clump_d(ctx):
    """A tired clump of white daisies late in the season: some heads gone brown, stems lying
    out over the mulch, the leaves yellowing."""
    _flower_clump(ctx, "D")
    ctx.tint(LEAF, (74, 84, 46))



PIECES = {
    "ParkBenchCast": park_bench_cast,
    "ParkBenchCastWorn": park_bench_cast_worn,
    "HeritageLampPost": heritage_lamp_post,
    "HeritageLampPostWorn": heritage_lamp_post_worn,
    "ParkBinCast": park_bin_cast,
    "DrinkingFountainCast": drinking_fountain_cast,
    "TreePlaneYoung": tree_plane_young,
    "TreeLimeYoung": tree_lime_young,
    "TreeAutumn": tree_autumn,
    "FountainTwoTier": fountain_two_tier,
    "BandstandVictorian": bandstand_victorian,
    "VendingMachine": vending_machine,
    "VendingMachineWorn": vending_machine_worn,
    "FlowerClumpA": flower_clump_a,
    "FlowerClumpB": flower_clump_b,
    "FlowerClumpC": flower_clump_c,
    "FlowerClumpD": flower_clump_d,
}
