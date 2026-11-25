"""Yard and court props of the city prop kit (fix wave): the loading dock's boxes and bumpers,
the Cage's two street basketball hoops and the city's six big steel dumpsters.

Why meshes: these were among the last plain primitives on main street views: the dock's
'Crate' cubes and 'CrateStack' block (flat tan boxes), its three black 'Bumper' cubes, the
hoops (square pole and arm, a blue pad box, a rim and net of 24 straight sticks each) and the
'DumpsterOld' family (a green box with a slab lid and two bars).

Conventions (pieces/_template.py): Roblox axes, studs, +Y up, front = -Z, floor pieces with
their origin at the centre of the footprint on the ground. Each piece takes the footprint of
the city parts it replaces (tools/city/overlay/edits/yard.py wraps them; colliding parts stay
as invisible proxies, the mesh within ~0.3 stud of them: noted at each piece). One tintable
layer per piece at most. No bottles of any kind.
"""

import math

import bmesh
from mathutils import Matrix, Vector

import kitlib
from kitlib import R, T, box, cyl, lathe, lerp, loft, smoothstep, tube
from fixtures import rbox, spline, _transform  # noqa: F401  (shared shape helpers, read-only)

TAU = 2 * math.pi


def _merge(target, bm):
    me = kitlib.bpy.data.meshes.new("_tmp")
    bm.to_mesh(me)
    bm.free()
    target.from_mesh(me)
    kitlib.bpy.data.meshes.remove(me)


def _strip(p0, p1, w, t, up=(0, 1, 0)):
    """A thin flat strip (tape, a painted line) from p0 to p1, width w, thickness t; `up` is the
    strip's face normal."""
    p0, p1, up = Vector(p0), Vector(p1), Vector(up).normalized()
    d = p1 - p0
    length = d.length
    x = d.normalized()
    z = x.cross(up).normalized()
    y = z.cross(x)
    bm = box(length, t, w)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = (p0 + p1) / 2
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm


# ==============================================================================================
# CardboardBoxLarge / PalletStackBoxes. Real reference: a loading dock's goods: big corrugated
# shipping cartons (RSC: four top flaps meeting on a centre seam closed with brown packing tape
# running down the ends, a white shipping label, crushed and scuffed corners, the board
# darkened where it got wet), and a wooden pallet (EUR 1200 x 800 mm: three bottom boards,
# nine blocks, three stringer boards, five top deck boards) loaded with cartons in tiers.
# City footprint (Climb/C5, the dock top at y 4.6): Crate 3 x 3 x 3 (x2, collide + query);
# CrateStack 8 x 5 x 4 (collides: a climb step, its top must stay flat at 5.0).
# ==============================================================================================
def _carton(ctx, size, at, rng, noise, crush=0.0, label=True, layer="Cardboard", dense=True, tape=True):
    """One carton of `size` with its base centre at `at`: slightly bulged sides, the top flap
    seam, tape over the seam and down both ends, a label on the front, a crushed top corner."""
    sx, sy, sz = size
    bm = rbox(sx, sy, sz, r=0.035, m=1, n=(3, 2, 3) if dense else (1, 1, 1))
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    cx = rng.choice((-1, 1))
    cz = rng.choice((-1, 1))

    def dent(co):
        # sides bulge a little (packed full), the top sags between flaps, one corner crushed
        bx = 1 - (co.y / hy) ** 2
        k = 0.02 * bx
        co.x += k * (co.x / hx)
        co.z += k * (co.z / hz)
        if co.y > hy - 0.01:
            co.y -= 0.03 * (1 - abs(co.x / hx)) * (1 - abs(co.z / hz))
        d = Vector((co.x - cx * hx, co.y - hy, co.z - cz * hz)).length
        co.y -= crush * math.exp(-(d / 0.5) ** 2)
        return co

    kitlib.displace(bm, dent)
    ctx.add(layer, bm, T(at[0], at[1] + hy, at[2]))
    top = at[1] + sy
    tw = min(0.24, sx * 0.12)
    if not tape:
        tw = 0.0
    # tape: along the top seam (along X) and down both X ends
    if tape:
        ctx.add("Plastic", _strip((at[0] - hx - 0.012, top + 0.004, at[2]), (at[0] + hx + 0.012, top + 0.004, at[2]), tw, 0.012))
    for s in (-1, 1) if tape else ():
        x = at[0] + s * (hx + 0.006)
        ctx.add("Plastic", _strip((x, top, at[2]), (x, top - min(0.7, sy * 0.35), at[2]), tw, 0.012, up=(s, 0, 0)))
    # the flap seam (a dark line across the tape's ends), as a hairline slab on top
    if tape:
        ctx.add("Black", _strip((at[0] - hx + 0.05, top - 0.012, at[2]), (at[0] + hx - 0.05, top - 0.012, at[2]), 0.02, 0.03))
    if label:
        lw, lh = min(0.7, sx * 0.3), min(0.5, sy * 0.25)
        lx = at[0] + rng.uniform(-0.25, 0.25) * sx
        ctx.add("Paper", box(lw, lh, 0.012), T(lx, at[1] + sy * 0.62, at[2] - hz - 0.008))
        for k in range(3):  # (printed lines on the label)
            ctx.add("Black", box(lw * (0.75 - 0.15 * k), 0.035, 0.01), T(lx, at[1] + sy * 0.62 + lh * 0.25 - k * lh * 0.22,
                                                                    at[2] - hz - 0.016))


def _pallet(ctx, w, d, at, rng):
    """A wooden pallet w (X) x d (Z), 0.5 tall, its base centre at `at`: bottom boards, blocks,
    stringer boards, top deck boards with gaps (WoodDark: old grey-brown softwood)."""
    x0, y0, z0 = at
    for k in range(3):  # bottom boards along X
        z = z0 + lerp(-d / 2 + 0.25, d / 2 - 0.25, k / 2)
        ctx.add("WoodDark", box(w, 0.08, 0.45), T(x0, y0 + 0.04, z))
    for i in range(3):
        for k in range(3):
            x = x0 + lerp(-w / 2 + 0.3, w / 2 - 0.3, i / 2)
            z = z0 + lerp(-d / 2 + 0.25, d / 2 - 0.25, k / 2)
            ctx.add("WoodDark", box(0.55, 0.28, 0.45), T(x, y0 + 0.22, z) @ R(0, rng.uniform(-2, 2), 0))
    for i in range(3):  # stringer boards along Z
        x = x0 + lerp(-w / 2 + 0.3, w / 2 - 0.3, i / 2)
        ctx.add("WoodDark", box(0.55, 0.08, d), T(x, y0 + 0.4, z0))
    n = max(5, int(w / 1.3))
    for k in range(n):  # top deck boards along Z... across X spacing
        x = x0 + lerp(-w / 2 + 0.33, w / 2 - 0.33, k / (n - 1))
        ctx.add("WoodDark", box(0.66, 0.07, d), T(x, y0 + 0.475, z0) @ R(0, 0, rng.uniform(-0.6, 0.6)))


def _carton_wear(noise):
    def fn(p):
        damp = 1 - 0.28 * (1 - smoothstep(0.0, 0.9 + 0.4 * noise.fbm(p.co, 2, 1.2), p.co.y))
        scuff = 1 - 0.18 * smoothstep(0.1, 0.5, p.convex) * (0.5 + 0.5 * noise.n(p.co * 5.0))
        blot = 1 - 0.12 * smoothstep(0.55, 0.85, noise.fbm(p.co, 3, 1.6) * 0.5 + 0.5)
        cav = 1 - 0.25 * smoothstep(0.0, 0.45, -p.convex)
        return (damp * scuff * blot * cav, damp * scuff * blot * cav * 0.97, damp * scuff * blot * cav * 0.93)

    return fn


def cardboard_box_large(ctx):
    """A big corrugated carton (3 x 3 x 3 studs, ~85 cm): flaps on a centre seam under brown
    packing tape running down both ends, a shipping label, bulged sides, a crushed top corner,
    the bottom darkened by a wet dock."""
    rng, noise = ctx.rng, ctx.noise
    _carton(ctx, (2.96, 2.96, 2.96), (0, 0, 0), rng, noise, crush=0.12)
    ctx.wear("Cardboard", _carton_wear(noise))
    ctx.wear("Plastic", kitlib.mul(kitlib.cavity(0.2), lambda p: (0.95, 0.82, 0.62)))
    ctx.tint("Plastic", (176, 132, 82))


def cardboard_box_large_b(ctx):
    """The same carton knocked about: the top caved in at one corner, a torn flap edge, a second
    label, darker board (rained on)."""
    rng, noise = ctx.rng, ctx.noise
    rng.random()
    _carton(ctx, (2.96, 2.94, 2.96), (0, 0, 0), rng, noise, crush=0.26)
    ctx.add("Cardboard", box(0.9, 0.02, 0.35), T(0.7, 2.96, -1.32) @ R(-14, 8, 0))  # (the torn flap lifted)
    ctx.add("Paper", box(0.5, 0.36, 0.012), T(-0.9, 1.1, -1.49))
    w = _carton_wear(noise)
    ctx.wear("Cardboard", lambda p: tuple(0.86 * c for c in w(p)))
    ctx.wear("Plastic", kitlib.mul(kitlib.cavity(0.2), lambda p: (0.95, 0.82, 0.62)))
    ctx.tint("Plastic", (170, 126, 78))


def pallet_stack_boxes(ctx):
    """A pallet of cartons on the dock (8 x 5 x 4 studs, the climb step's block): a wooden
    pallet under three tiers of cartons (two sizes, a little out of line), the top tier full so
    the top stays flat at 5.0, tape and labels, a sheet of stretch film torn off one side."""
    rng, noise = ctx.rng, ctx.noise
    ctx.budget = 4000
    _pallet(ctx, 7.9, 3.95, (0, 0, 0), rng)
    y = 0.51
    tiers = ((1.49, 4, 2), (1.49, 4, 2), (1.49, 4, 2))
    for tier, (th, nx, nz) in enumerate(tiers):
        for i in range(nx):
            for k in range(nz):
                w, dd = 7.9 / nx, 3.95 / nz
                x = -3.95 + w * (i + 0.5) + rng.uniform(-0.04, 0.04)
                z = -1.975 + dd * (k + 0.5) + rng.uniform(-0.04, 0.04)
                _carton(ctx, (w - 0.06, th - 0.01, dd - 0.06), (x, y, z), rng, noise,
                        crush=0.0, label=(k == 0 and rng.random() < 0.6), layer="Cardboard", dense=False,
                        tape=(tier == len(tiers) - 1))
        y += th
    # the torn stretch film hanging off the back corner (two-sided thin sheet)
    film = bmesh.new()
    rows = []
    for j in range(4):
        yy = lerp(0.6, 3.6, j / 3)
        rows.append([Vector((3.97 + 0.05 * math.sin(i + j), yy - 0.25 * (i / 3) ** 2, lerp(1.98, 0.6, i / 3))) for i in range(4)])
    g0 = [[p for p in r] for r in rows]
    g1 = [[p + Vector((0.01, 0, 0)) for p in r] for r in rows]
    from vehicles import _slab  # (the vehicles family's slab helper, read-only)

    _merge(film, _slab(g0, g1))
    ctx.add("Glass", film)
    ctx.wear("Cardboard", _carton_wear(noise))
    ctx.wear("WoodDark", kitlib.mul(kitlib.ground_dirt(0.6, 0.35, noise), kitlib.cavity(0.3), kitlib.scuffs(noise, 0.25, 3.0)))
    ctx.wear("Plastic", kitlib.mul(kitlib.cavity(0.2), lambda p: (0.95, 0.82, 0.62)))
    ctx.tint("Plastic", (176, 132, 82))


# ==============================================================================================
# DockBumper. Real reference: a laminated dock bumper (Durable / Rite-Hite style): 10-15 cm
# of recycled tyre-rubber plies stacked face out, clamped between two steel angle end plates
# bolted through the stack into the dock face with four anchor bolts; the front face scuffed
# grey by trailers, black rubber smears on the concrete around it.
# City footprint (Climb/C5): Bumper 1 x 1.4 x 0.6 (decor), its back on the dock face. Origin:
# the old part's centre, -Z out of the dock.
# ==============================================================================================
def dock_bumper(ctx):
    """Laminated rubber dock bumper: stacked tyre plies (grooved faces, cut edges) held between
    two steel angle end plates with four through-bolts into the dock face."""
    noise, rng = ctx.noise, ctx.rng
    plies = 9
    h = 1.24
    for k in range(plies):
        y = -h / 2 + (k + 0.5) * h / plies
        d = 0.56 - 0.03 * abs(math.sin(k * 1.7))  # (worn unevenly: the middle plies pushed in)
        sag = 0.02 * math.sin(k * 2.3)
        ctx.add("Rubber", rbox(0.9 - 0.02 * (k % 2), h / plies - 0.012, d, r=0.02, m=1),
                T(sag, y, 0.3 - d / 2))
    for s in (-1, 1):  # steel angle end plates top and bottom
        y = s * (h / 2 + 0.04)
        ctx.add("MetalPainted", box(0.98, 0.07, 0.58, bevel=0.01), T(0, y, 0.0))
        ctx.add("MetalPainted", box(0.98, 0.3, 0.06, bevel=0.01), T(0, y - s * 0.11, 0.27))
        for x in (-0.33, 0.33):
            ctx.add("Metal", cyl(0.035, 1.42, 6), T(x, 0, -0.18 if s < 0 else 0.1))
            ctx.add("Metal", cyl(0.06, 0.04, 6), T(x, s * (h / 2 + 0.095), -0.18 if s < 0 else 0.1))
    ctx.wear("Rubber", lambda p: (0.85 + 0.15 * smoothstep(0.1, 0.3, -p.co.z) * (0.6 + 0.4 * noise.n(p.co * 7))) * 1.0)
    ctx.wear("MetalPainted", kitlib.mul(kitlib.cavity(0.35), kitlib.scuffs(noise, 0.35, 5.0, 0.45),
                                       kitlib.streaks(noise, 0.3, 6.0)))
    ctx.tint("MetalPainted", (148, 124, 44))


# ==============================================================================================
# StreetHoop. Real reference: an in-ground outdoor basketball hoop in a city court (Marrow's
# Cage): a round steel post on a bolted base plate, its lower part wrapped in a padded vinyl
# cover strapped on, a horizontal offset arm with a diagonal brace, a perforated steel
# backboard (1.83 x 1.07 m, here the data's 6 x 3.5 studs) with a painted shooter's square and
# border, a fixed steel rim (45 cm, orange paint mostly rusted off) on its bracket, and a chain
# net, some links broken and hanging. Rust weeping from the bolts, the paint chipped.
# City footprint (Zones/Cage, x2): HoopBase 2.4 x 0.3 x 2.4 (collides), HoopPole 0.7 square up
# 13.05 (collides), pad 1.1 to 5.55, arm at 12.85, Backboard 0.2 x 3.5 x 6 centred 3.9 ahead
# at 11.5, rim centre 5.15 ahead at 9.97 (radius 0.82). Origin: the pole's foot on the court,
# -Z toward the board.
# ==============================================================================================
def street_hoop(ctx):
    """Outdoor in-ground basketball hoop: round post on a bolted base plate, padded wrap,
    offset arm with a diagonal brace, perforated steel backboard with a painted square, a
    rusty fixed rim and a chain net with broken strands."""
    noise, rng = ctx.noise, ctx.rng
    ctx.budget = 5000
    ctx.smooth_angle = 50.0
    # base plate with four anchor nuts
    ctx.add("MetalPainted", box(2.36, 0.08, 2.36, bevel=0.02), T(0, 0.04, 0))
    ctx.add("Concrete", box(2.4, 0.22, 2.4, bevel=0.06), T(0, 0.19, 0))  # (the grout pad)
    ctx.add("MetalPainted", box(1.2, 0.06, 1.2, bevel=0.01), T(0, 0.33, 0))
    for sx in (-1, 1):
        for sz in (-1, 1):
            ctx.add("Rust", cyl(0.07, 0.1, 6), T(sx * 0.45, 0.4, sz * 0.45))
    # the post and its gooseneck to the arm, the arm, the brace
    pole = [(0, 0.3, 0), (0, 6.0, 0), (0, 12.2, 0)]
    elbow = spline([(0, 12.2, 0), (0, 12.6, -0.12), (0, 12.85, -0.55)], 4)
    arm = [(0, 12.85, -0.55), (0, 12.85, -3.55)]
    path = pole + [tuple(p) for p in elbow[1:]] + arm[1:]
    ctx.add("MetalPainted", tube(path, 0.3, 16))
    ctx.add("MetalPainted", tube([(0, 9.0, -0.25), (0, 12.7, -2.75)], 0.14, 10))
    ctx.add("MetalPainted", cyl(0.31, 0.05, 16), T(0, 12.22, 0))  # (the weld seam ring)
    # board mount: a steel frame of two uprights and two rails behind the board
    for z in (-3.58,):
        for x in (-1.3, 1.3):
            ctx.add("MetalPainted", box(0.14, 3.6, 0.14), T(x, 11.5, z + 0.1))
        for y in (10.1, 12.9):
            ctx.add("MetalPainted", box(3.0, 0.14, 0.14), T(0, y, z + 0.1))
        ctx.add("MetalPainted", box(0.16, 0.16, 0.34), T(0, 12.85, -3.62))
    # the backboard: a steel sheet with a rolled border, holes punched in rows (dark dots)
    ctx.add("Metal", box(6.0, 3.5, 0.08, bevel=0.03), T(0, 11.5, -3.86))
    ctx.add("Metal", tube([(-2.98, 9.77, -3.9), (2.98, 9.77, -3.9), (2.98, 13.23, -3.9), (-2.98, 13.23, -3.9)], 0.05, 6, closed=True))
    for i in range(10):
        for j in range(5):
            if 3 <= i <= 6 and j <= 2:
                continue  # (the square's area is solid)
            x = -2.55 + i * 0.567
            y = 10.15 + j * 0.62
            ctx.add("Black", box(0.12, 0.12, 0.02), T(x, y, -3.91))
    # painted border and shooter's square (white, chipped): strips proud of the face
    def paint(x0, y0, x1, y1, w):
        ctx.add("Reflective", _strip((x0, y0, -3.915), (x1, y1, -3.915), w, 0.012, up=(0, 0, -1)))

    for (x0, y0, x1, y1) in ((-2.85, 9.88, 2.85, 9.88), (-2.85, 13.12, 2.85, 13.12), (-2.85, 9.88, -2.85, 13.12),
                             (2.85, 9.88, 2.85, 13.12)):
        paint(x0, y0, x1, y1, 0.1)
    for (x0, y0, x1, y1) in ((-0.98, 10.12, 0.98, 10.12), (-0.98, 11.48, 0.98, 11.48), (-0.98, 10.12, -0.98, 11.48),
                             (0.98, 10.12, 0.98, 11.48)):
        paint(x0, y0, x1, y1, 0.14)
    # rim bracket and the rim (rusty orange), the net hooks
    ctx.add("Rust", box(0.7, 0.4, 0.3, bevel=0.03), T(0, 9.95, -4.05))
    ctx.add("Rust", box(0.12, 0.5, 0.36), T(0, 9.75, -4.2) @ R(-35, 0, 0))
    rc = Vector((0, 9.97, -5.15))
    ring = [tuple(rc + Vector((0.82 * math.cos(TAU * k / 20), 0, 0.82 * math.sin(TAU * k / 20)))) for k in range(20)]
    ctx.add("Rust", tube(ring, 0.05, 6, closed=True))
    # the chain net: 12 strands zig-zagging to a smaller ring 1.25 below (diamonds); three
    # broken: hanging straight down, shorter
    n = 12
    broken = set(rng.sample(range(n), 3))
    for k in range(n):
        a0 = TAU * k / n
        pts = []
        for j in range(4):
            t = j / 3
            r = lerp(0.8, 0.5, t)
            a = a0 + (TAU / n) * 0.5 * (j % 2)
            y = rc.y - 1.25 * t
            pts.append(tuple(rc + Vector((r * math.cos(a), y - rc.y, r * math.sin(a)))))
        if k in broken:
            p0 = Vector(pts[0])
            pts = [tuple(p0), tuple(p0 + Vector((0.02, -0.45, 0.01))), tuple(p0 + Vector((0.0, -0.8, 0.03)))]
        ctx.add("Metal", tube(pts, 0.018, 3))
        ctx.add("Metal", cyl(0.025, 0.08, 4), T(*pts[0]))  # (the hook)
    # the padded wrap round the post: vinyl over foam, strapped, split near the top
    pad = lathe([(0.0, 0.42), (0.54, 0.42), (0.55, 0.5), (0.55, 5.3), (0.53, 5.5), (0.0, 5.5)], 16)
    ctx.add("FabricDark", pad)
    for y in (1.2, 3.0, 4.8):
        ctx.add("Black", lathe([(0.555, y - 0.07), (0.575, y - 0.06), (0.575, y + 0.06), (0.555, y + 0.07)], 16))

    def iron(p):
        y = p.co.y
        rust = smoothstep(0.55, 0.85, noise.fbm(Vector((p.co.x * 2, y * 0.6, p.co.z * 2)), 3) * 0.5 + 0.5)
        dirt = 1 - 0.3 * (1 - smoothstep(0.0, 1.5, y))
        cav = 1 - 0.3 * smoothstep(0.0, 0.45, -p.convex)
        k = dirt * cav
        return (k * (1 - 0.15 * rust), k * (1 - 0.35 * rust), k * (1 - 0.5 * rust))

    ctx.wear("MetalPainted", iron)
    ctx.wear("Metal", kitlib.mul(kitlib.cavity(0.3), kitlib.streaks(noise, 0.35, 4.0),
                                 lambda p: (0.9, 0.86, 0.8) if p.co.y > 9 else 0.8))
    ctx.wear("Rust", kitlib.mul(kitlib.cavity(0.3), lambda p: 0.75 + 0.25 * noise.n(p.co * 6)))
    ctx.wear("Reflective", lambda p: 0.72 + 0.2 * noise.n(p.co * 4.0))
    ctx.wear("FabricDark", kitlib.mul(kitlib.ground_dirt(1.5, 0.3, noise), kitlib.scuffs(noise, 0.3, 3.0)))
    ctx.wear("Concrete", kitlib.mul(kitlib.ground_dirt(0.4, 0.3, noise), kitlib.cavity(0.3)))
    ctx.tint("MetalPainted", (52, 62, 58))


# ==============================================================================================
# DumpsterLarge / DumpsterLargeOpen. Real reference: a 6-yard front-load steel dumpster with
# flat plastic lids: a tapered welded body on four swivel casters, a rolled top rim, vertical
# hat-channel stiffeners, fork / lifting channels along both long sides, two black HDPE lids
# hinged at the back (ribbed, a handle moulded at the front). Typical wear: dents low on the
# sides, paint chipped to rust along the bottom, the corners and the rim, grime running down,
# a stencilled number, lids warped.
# City footprint (DumpsterOld x6, one is the C1 climb step): Dumpster 6.4 x 3.2 x 4 (y 0..3.2,
# collides), Lid 6.6 x 0.2 x 4.2 at 3.2..3.4 (collides: its top is the climb's step, flat) or
# two 3.3 halves (the -X one closed and colliding, the +X one raised 15 degrees at the front
# with bags under it, decor), Bars 6 x 0.3 x 0.3 at 2.75, z +-2.15. Origin: the body's footprint
# centre on the ground, -Z the front, hinges at +Z.
# ==============================================================================================
D_W, D_D, D_H = 6.4, 4.0, 3.2


def _dumpster_body(ctx, rng, noise):
    # the body: a tapered tub (bottom 6.0 x 3.6 at y 0.5, top 6.36 x 3.96 at 3.12)
    def ring(y, hw, hd, r=0.12):
        pts = []
        for cx, cz, a0 in ((hw - r, hd - r, 0), (-hw + r, hd - r, 90), (-hw + r, -hd + r, 180), (hw - r, -hd + r, 270)):
            for k in range(3):
                a = math.radians(a0 + 45 * k)
                pts.append((cx + r * math.cos(a), y, cz + r * math.sin(a)))
        return pts

    rings = [ring(0.5, 3.0, 1.8), ring(0.9, 3.07, 1.87), ring(2.0, 3.12, 1.92), ring(3.12, 3.18, 1.98)]
    body = loft(rings, cap_start=True, cap_end=True)
    dents = [(Vector((rng.uniform(-2, 2), 1.3, -1.9)), 0.6, 0.08), (Vector((3.1, 1.6, rng.uniform(-1, 1))), 0.5, 0.06)]
    for v in body.verts:
        for c, rad, depth in dents:
            d = (v.co - c).length
            if d < rad * 2:
                v.co -= Vector((v.co.x, 0, v.co.z)).normalized() * depth * math.exp(-(d / rad) ** 2)
    ctx.add("MetalPainted", body)
    # rolled top rim
    rim = [tuple(Vector(p) + Vector((0, 0.04, 0))) for p in ring(3.12, 3.2, 2.0)]
    ctx.add("MetalPainted", tube(rim, 0.07, 6, closed=True))
    # vertical hat-channel stiffeners on the long sides, a horizontal band
    for sz in (-1, 1):
        for x in (-2.0, 0.0, 2.0):
            ctx.add("MetalPainted", box(0.3, 2.5, 0.1, bevel=0.03), T(x, 1.85, sz * 1.97) @ R(sz * 1.2, 0, 0))
    for sx in (-1, 1):
        for z in (-0.9, 0.9):
            ctx.add("MetalPainted", box(0.1, 2.5, 0.3, bevel=0.03), T(sx * 3.17, 1.85, z) @ R(0, 0, -sx * 1.2))
    # lifting channels along both long sides (the data's Bars) on four brackets
    for sz in (-1, 1):
        ctx.add("MetalPainted", box(6.0, 0.3, 0.26, bevel=0.03), T(0, 2.75, sz * 2.13))
        ctx.add("Black", box(5.8, 0.16, 0.05), T(0, 2.75, sz * 2.25))
        for x in (-2.6, 2.6):
            ctx.add("MetalPainted", box(0.2, 0.36, 0.22), T(x, 2.75, sz * 2.0))
    # four swivel casters
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * 2.55, sz * 1.4
            ctx.add("Metal", box(0.5, 0.05, 0.5), T(x, 0.47, z))
            ctx.add("Metal", box(0.08, 0.3, 0.32), T(x - 0.12, 0.3, z))
            ctx.add("Metal", box(0.08, 0.3, 0.32), T(x + 0.12, 0.3, z))
            w = cyl(0.2, 0.16, 12)
            bmesh.ops.transform(w, matrix=R(0, 0, 90), verts=w.verts)
            ctx.add("Rubber", w, T(x, 0.2, z + rng.uniform(-0.05, 0.05)))
    # rust along the bottom edge and the front corners (ragged patches proud of the paint)
    for sz in (-1, 1):
        for k in range(3):
            x0 = rng.uniform(-2.75, 1.55)
            ln = rng.uniform(0.6, 1.2)
            hgt = rng.uniform(0.18, 0.42)
            pts0, pts1 = [], []
            for i in range(6):
                x = x0 + ln * i / 5
                top = 0.55 + hgt * (0.6 + 0.4 * noise.n(Vector((x * 3, k, sz))))
                pts0.append([Vector((x, 0.55, 0)), Vector((x, top, 0))])
            rows = [[Vector((p[j].x, p[j].y, sz * (1.81 + (p[j].y - 0.5) * 0.06 / 0.4 + 0.012))) for p in pts0] for j in range(2)]
            rows_o = [[q + Vector((0, 0, sz * 0.02)) for q in r] for r in rows]
            from vehicles import _slab

            ctx.add("Rust", _slab(rows, rows_o) if sz > 0 else _slab(rows_o, rows))
    # a stencilled number on the front (white, worn): three digit blocks
    for k in range(3):  # (each digit two worn strokes)
        x = -0.4 + k * 0.4
        ctx.add("Concrete", box(0.06, 0.42, 0.02), T(x - 0.07, 2.1, -1.985))
        ctx.add("Concrete", box(0.2, 0.06, 0.02), T(x, 2.1 + (0.18 if k % 2 else -0.18), -1.985))


def _lid(ctx, x0, open_deg=0.0, warp=0.0):
    """One HDPE lid half (3.3 x 0.2 x 4.2) over x0, hinged at +Z: ribs, the front handle."""
    m = T(x0, 3.2, 2.1) @ R(open_deg, 0, 0) @ T(0, 0, -2.1)
    lid = rbox(3.26, 0.16, 4.18, r=0.05, m=1, n=(3, 1, 3))
    kitlib.displace(lid, lambda co: co + Vector((0, -warp * (1 - (co.x / 1.63) ** 2) * (1 - (co.z / 2.09) ** 2), 0)))
    ctx.add("PlasticDark", lid, m @ T(0, 0.08, 0))
    for x in (-0.9, 0.0, 0.9):
        ctx.add("PlasticDark", rbox(0.16, 0.06, 3.7, r=0.02, m=1), m @ T(x, 0.18, 0))
    ctx.add("PlasticDark", rbox(1.1, 0.12, 0.14, r=0.04, m=1), m @ T(0, 0.12, -2.12))
    for x in (-1.1, 1.1):  # hinge knuckles at the back
        k = cyl(0.08, 0.36, 8)
        bmesh.ops.transform(k, matrix=R(0, 0, 90), verts=k.verts)
        ctx.add("Metal", k, T(x0 + x, 3.2, 2.1))


def _dumpster_wear(ctx, noise):
    def paint(p):
        y = p.co.y
        dirt = 1 - 0.35 * (1 - smoothstep(0.3, 1.6 + 0.5 * noise.fbm(p.co, 2, 1.0), y))
        q = (p.co.x * 3.0, y * 0.35, p.co.z * 3.0)
        streak = 1 - 0.25 * smoothstep(0.15, 0.7, noise.fbm(q, 2))
        cav = 1 - 0.35 * smoothstep(0.0, 0.45, -p.convex)
        chip = smoothstep(0.62, 0.8, noise.fbm(p.co, 3, 2.5) * 0.5 + 0.5) * smoothstep(0.1, 0.5, p.convex)
        k = dirt * streak * cav
        return (k * (1 - 0.1 * chip), k * (1 - 0.3 * chip), k * (1 - 0.45 * chip))

    ctx.wear("MetalPainted", paint)
    ctx.wear("PlasticDark", kitlib.mul(kitlib.cavity(0.3), kitlib.scuffs(noise, 0.3, 3.0), lambda p: 1.0 + 0.0 * p.co.y))
    ctx.wear("Rust", kitlib.mul(kitlib.cavity(0.3), lambda p: 0.6 + 0.4 * smoothstep(0.55, 0.95, p.co.y)))
    ctx.wear("Metal", kitlib.mul(kitlib.ground_dirt(0.6, 0.4, noise), kitlib.cavity(0.3)))
    ctx.wear("Concrete", lambda p: 0.9 + 0.1 * noise.n(p.co * 5.0))


def dumpster_large(ctx):
    """6-yard steel dumpster on casters, both flat lids shut (one warped): tapered welded body,
    rolled rim, stiffeners, lifting channels, rust along the bottom, a stencilled number."""
    rng, noise = ctx.rng, ctx.noise
    ctx.budget = 5000
    _dumpster_body(ctx, rng, noise)
    _lid(ctx, -1.65, 0.0, 0.0)
    _lid(ctx, 1.65, 0.0, 0.05)
    _dumpster_wear(ctx, noise)
    ctx.tint("MetalPainted", (44, 70, 52))


def dumpster_large_open(ctx):
    """The same dumpster overfull: the right lid propped up 15 degrees on two black bin bags."""
    rng, noise = ctx.rng, ctx.noise
    ctx.budget = 5000
    _dumpster_body(ctx, rng, noise)
    _lid(ctx, -1.65, 0.0, 0.04)
    _lid(ctx, 1.65, 15.0, 0.0)
    for c, r in (((2.3, 3.05, -0.3), 0.95), ((1.25, 3.0, 0.1), 0.9)):
        b = kitlib.sphere(r, 12, 8)
        kitlib.displace(b, lambda co: Vector((co.x * 1.05, co.y * 0.8, co.z)) * (1 + 0.08 * noise.n(co * 3)))
        ctx.add("PlasticDark", b, T(*c))
        ctx.add("PlasticDark", cyl(0.12, 0.25, 6, r2=0.04), T(c[0] + 0.1, c[1] + r * 0.78, c[2]))  # (the knot)
    _dumpster_wear(ctx, noise)
    ctx.tint("MetalPainted", (44, 70, 52))


PIECES = {
    "CardboardBoxLarge": cardboard_box_large,
    "CardboardBoxLargeB": cardboard_box_large_b,
    "PalletStackBoxes": pallet_stack_boxes,
    "DockBumper": dock_bumper,
    "StreetHoop": street_hoop,
    "DumpsterLarge": dumpster_large,
    "DumpsterLargeOpen": dumpster_large_open,
}
