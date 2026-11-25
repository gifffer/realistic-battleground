"""Street furniture and street junk of the city prop kit: road cones, car tyres, 200 L steel
drums (and the burn barrel), broken concrete, demolition rubble, crumpled paper.

Each build function gets a kitlib.Piece (`ctx`) and models its piece in Roblox axes (Y up, the
front faces -Z, studs), the origin at the centre of the footprint on the floor.
"""

import math

import bmesh
import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree

from kitlib import T, R, S, box, lathe, loft, lerp, smoothstep, tube, VertexInfo  # noqa: F401  (VertexInfo: docs)

# ----------------------------------------------------------------------------------------------
# TrafficCone. The common 28-30 in (71-75 cm) road cone, at the city's prop scale (the props are
# drawn ~15 % large next to the 5-stud character): 2.8 studs tall on a 1.4-stud square base, the
# same footprint as props_objects.traffic_cone. props_ground's smaller cone is this one at
# Scale ~0.72. Real reference (real_specs.md):
#   * a separate flat square base of black recycled rubber, chamfered, corners rounded and
#     stepped down (the hand grips), a raised round boss where the cone comes out of it, the
#     square base open in the middle (the cone is hollow right through);
#   * ONE straight conical shell (bottom 27 cm across, top 5.5 cm), slightly flared just above
#     the base, a rolled lip round the open tip, real wall thickness;
#   * two retro-reflective collars ON the surface (15 cm and 10 cm), proud by ~2 mm, with their
#     own visible top and bottom edges;
#   * a faint vertical mould seam on two opposite sides;
#   * wear: grime and concrete dust on the lower third, black tyre rubber up one side, the dark
#     inside, dirty grey collars; the worn variant is run-over (a crease), squashed, its tip
#     chewed.
# No z-fighting by construction: under each collar the orange shell is recessed by REC, and the
# collar's outer face stands PROUD above the shell (gap REC + PROUD = 0.02 studs between the two
# visible depths); the cone's bottom is buried in the rubber boss (the surfaces cross, they are
# never coplanar).
# ----------------------------------------------------------------------------------------------
H = 2.8  # total height
BASE = 0.7  # half side of the square base
BASE_T = 0.13  # base slab thickness
BOSS_TOP = 0.22  # top of the raised round boss the cone comes out of
R_BOT, Y_BOT = 0.5, BOSS_TOP  # cone radius where it leaves the boss
R_TOP, Y_TOP = 0.102, 2.71  # cone radius just under the rolled lip
WALL = 0.035  # shell thickness (~1 cm: thick enough to read when it lies on its side)
REC, PROUD = 0.012, 0.008  # collar recess in the shell / collar standing proud of the shell
COLLARS = ((1.92, 2.48), (1.36, 1.73))  # (bottom, top) of the 15 cm and 10 cm collars
SEAMS = (0.0, math.pi)  # the mould seams (angles: 0 = +X side)
HOLE = 0.43  # the square base's round opening


def cone_r(y):
    """Outer radius of the shell at height y: a straight cone with a soft flare above the base."""
    t = (y - Y_BOT) / (Y_TOP - Y_BOT)
    return lerp(R_BOT, R_TOP, t) + 0.028 * math.exp(-max(0.0, y - Y_BOT) / 0.1)


def _shell_profile(worn=False):
    """The shell's closed outline (radius, y): up the outside (stepping in under the collars),
    round the rolled lip, down the inside, closed under the boss. The worn cone gets more rings
    where its crease is, on BOTH faces (the inside must follow the dent, or the outside would
    sink through it)."""
    out = []
    # (no ring exactly at the boss top: the shell must cross that plane mid-face, never on a
    # vertex ring lying in it, or the crossing flickers)
    crease = [0.95, 1.25] if worn else []
    ys = sorted([0.05, 0.15, 0.3, 0.5, 0.78, 1.1] + crease)
    for y in ys:
        out.append((cone_r(y), y))
    for y0, y1 in sorted(COLLARS):
        out.append((cone_r(y0), y0))
        out.append((cone_r(y0) - REC, y0 + 0.001))
        out.append((cone_r(y1) - REC, y1 - 0.001))
        out.append((cone_r(y1), y1))
        if y1 < 1.8:
            out.append((cone_r(1.83), 1.83))
    out.append((cone_r(2.6), 2.6))
    out.append((cone_r(Y_TOP), Y_TOP))
    # the rolled lip round the open tip (a half round over the wall)
    rt = cone_r(Y_TOP)
    out += [(rt - 0.004, Y_TOP + 0.03), (rt - 0.014, Y_TOP + 0.05), (rt - WALL * 0.5, Y_TOP + 0.058),
            (rt - WALL + 0.004, Y_TOP + 0.05), (rt - WALL - 0.002, Y_TOP + 0.03)]
    for y in sorted([Y_TOP - 0.02, 2.2, 1.4, 0.7, 0.3, 0.05] + ([1.25, 1.1, 0.95, 0.78] if worn else []), reverse=True):
        out.append((cone_r(y) - WALL, y))
    return out


def _deform(ctx, worn):
    """The per-copy imperfections, the same for the shell and the collars (so the collars stay
    ON the surface): a slight oval squash, low wobble, and for the worn cone a run-over crease
    on one side and a chewed tip. Returns radius_fn(angle, r, y) -> (r, y)."""
    rng, noise = ctx.rng, ctx.noise
    squash = rng.uniform(0.01, 0.02) * (2.2 if worn else 1.0)
    squash_a = rng.uniform(0, math.pi)
    crease_a = rng.uniform(0.6, 1.2)  # (toward the back-right, away from the seam)
    crease_y = rng.uniform(0.98, 1.08)

    def fn(a, r, y):
        k = smoothstep(Y_BOT, 0.45, y)  # (the base keeps its shape)
        d = r * squash * math.cos(2 * (a - squash_a)) * k
        d += 0.006 * noise.n((math.cos(a) * 1.5, y * 1.2, math.sin(a) * 1.5)) * k
        if worn:
            da = math.atan2(math.sin(a - crease_a), math.cos(a - crease_a))
            g = math.exp(-(da / 0.75) ** 2) * math.exp(-((y - crease_y) / 0.22) ** 2)
            d -= 0.055 * g  # pushed in (the PVC folds, it does not crack)
        # the mould seam: a hair-thin ridge on the outside only
        for s in SEAMS:
            if abs(math.atan2(math.sin(a - s), math.cos(a - s))) < 1e-3 and r > cone_r(y) - REC - 0.004:
                d += 0.0045
        yy = y
        if worn and y > Y_TOP - 0.03:
            yy -= 0.045 * max(0.0, noise.n((math.cos(a) * 4, 7.3, math.sin(a) * 4)) + 0.25)
        return (r + d, yy)

    return fn


def _base_ring(ts, inset, y, angs, dip=0.0, hole=None):
    """One ring of the base: a circle (radius `hole`) blended toward the rounded square
    (half-side BASE - inset) by `ts`; the corners dropped by `dip` (the hand grips)."""
    ring = []
    for a in angs:
        c, s = math.cos(a), math.sin(a)
        p = 7.0
        sq = (BASE - inset) / (abs(c) ** p + abs(s) ** p) ** (1 / p)
        rr = lerp(hole if hole is not None else sq, sq, ts)
        corner = smoothstep(0.86, 0.985, abs(math.sin(2 * a)))
        ring.append((rr * c, y - dip * corner, rr * s))
    return ring


def _base(ctx, angs):
    """The square rubber base: underside, chamfered sides, a plateau with stepped-down corners,
    a fillet up to the round boss, the boss's rounded top and its open middle."""
    dip = 0.045
    rings = [
        _base_ring(0, 0, 0.0, angs, hole=HOLE),  # the opening, bottom
        _base_ring(0, 0, BOSS_TOP - 0.012, angs, hole=HOLE),  # the opening, top
        _base_ring(0, 0, BOSS_TOP, angs, hole=HOLE + 0.015),
        _base_ring(0, 0, BOSS_TOP, angs, hole=0.6),  # the boss's flat top
        _base_ring(0, 0, BOSS_TOP - 0.01, angs, hole=0.622),  # its small round shoulder
        _base_ring(0, 0, BASE_T + 0.012, angs, hole=0.636),  # its wall, nearly upright
        _base_ring(0, 0, BASE_T, angs, hole=0.652),  # a small fillet at its foot
        _base_ring(0.5, 0.06, BASE_T, angs, dip=dip * 0.25, hole=0.652),  # the flat plateau
        _base_ring(1.0, 0.03, BASE_T, angs, dip=dip),
        _base_ring(1.0, 0.0, BASE_T - 0.03, angs, dip=dip * 0.8),  # top chamfer
        _base_ring(1.0, 0.0, 0.02, angs),  # side
        _base_ring(1.0, 0.02, 0.0, angs),  # bottom chamfer
        _base_ring(1.0, 0.09, 0.0, angs),  # underside
    ]
    return loft(rings, closed_profile=True)


def _shell_inside(r, y):
    return r < cone_r(y) - REC - 0.006


def _cone(ctx, worn):
    ctx.budget = 3400 if worn else 3000
    ctx.tint("Plastic", (204, 84, 32))  # fluorescent orange PVC, a little dulled by the city
    # (the shell's 15-degree facets smooth, the base's chamfers crisp; the worn dent stays soft)
    ctx.smooth_angle = 55 if worn else 32
    noise = ctx.noise
    seam_angles = [s + d for s in SEAMS for d in (-0.035, 0.0, 0.035)]
    deform = _deform(ctx, worn)
    ctx.add("Plastic", lathe(_shell_profile(worn), segs=24, extra_angles=seam_angles, radius_fn=deform))
    for y0, y1 in COLLARS:
        # a band: inner face on the recessed shell, outer face PROUD of the plain shell, square
        # edges (real sheeting is 1 mm thick: its top and bottom edges catch the light)
        prof = [(cone_r(y0) - REC, y0), (cone_r(y0) + PROUD, y0), (cone_r(y1) + PROUD, y1), (cone_r(y1) - REC, y1)]
        ctx.add("Reflective", lathe(prof, segs=24, extra_angles=seam_angles, radius_fn=deform))
    ctx.add("Rubber", _base(ctx, [2 * math.pi * k / 32 for k in range(32)]))

    # ------------------------------------------------------------------ wear (vertex colours)
    tyre_a = ctx.rng.uniform(-2.4, -1.6)  # tyre marks up the front-left side
    tyre = 0.55 if worn else 0.4
    dirt_h = 0.95 if worn else 0.7

    def plastic(p):
        x, y, z = p.co
        r = math.hypot(x, z)
        a = math.atan2(z, x)
        k = 1.0
        if _shell_inside(r, y):
            # inside: dark (no light gets in), darker down the shaft
            return 0.42 + 0.16 * smoothstep(0.3, 2.6, y)
        # grime and concrete dust on the lower third, broken up
        h = dirt_h * (1 + 0.3 * noise.fbm((x * 2, y, z * 2), 2))
        k *= 1 - (0.42 if worn else 0.3) * (1 - smoothstep(0.15, h, y))
        # black tyre rubber smeared up one side: streaks along a slant
        da = math.atan2(math.sin(a - tyre_a), math.cos(a - tyre_a))
        side = math.exp(-(da / 0.9) ** 2) * (1 - smoothstep(0.5, 1.7, y))
        # (broad and soft: the colour lives on vertices 15 degrees apart, sharp marks turn blocky)
        streak = smoothstep(-0.1, 0.6, noise.fbm((a * 2.2 + y * 1.2, y * 0.35, 0.0), 2))
        k *= 1 - tyre * side * streak
        # fine scuffs everywhere, a few dark rubs
        k *= 1 - 0.12 * smoothstep(0.35, 0.8, noise.fbm((x * 6, y * 6, z * 6), 2) * 0.5 + 0.5)
        # rain streaks down from the lip, faint
        k *= 1 - 0.08 * smoothstep(0.2, 0.7, noise.fbm((math.cos(a) * 9, y * 0.3, math.sin(a) * 9), 2))
        # creased PVC: the crease bottom collects grime
        k *= 1 - 0.12 * smoothstep(0.08, 0.6, -p.convex) if worn else 1.0
        return k

    def reflective(p):
        x, y, z = p.co
        a = math.atan2(z, x)
        if _shell_inside(math.hypot(x, z), y):
            return 0.5
        k = 0.9 - 0.08 * smoothstep(0.0, 0.8, noise.fbm((x * 5, y * 3, z * 5), 2) * 0.5 + 0.5)
        k *= 1 - (0.25 if worn else 0.12) * (1 - smoothstep(1.3, 1.9, y))  # dirt splashed up
        da = math.atan2(math.sin(a - tyre_a), math.cos(a - tyre_a))
        k *= 1 - 0.5 * tyre * math.exp(-(da / 0.7) ** 2) * smoothstep(0.2, 0.6, noise.fbm((a * 4, y * 2, 1.0), 2))
        # sheeting peeling / scratched near the seam
        ds = min(abs(math.atan2(math.sin(a - s), math.cos(a - s))) for s in SEAMS)
        k *= 1 - 0.18 * math.exp(-(ds / 0.12) ** 2)
        return k

    def rubber(p):
        x, y, z = p.co
        # black rubber: dust (lighter) caught on the plateau and the corners, darker underneath
        dust = smoothstep(0.1, 0.13, y) * (0.5 + 0.5 * smoothstep(0.2, 0.75, noise.fbm((x * 3, 0, z * 3), 3) * 0.5 + 0.5))
        dust += 0.4 * smoothstep(0.2, 0.6, p.convex)
        k = 0.72 + 0.28 * min(1.0, dust)
        if y < 0.002:
            k *= 0.7
        return k

    ctx.wear("Plastic", plastic)
    ctx.wear("Reflective", reflective)
    ctx.wear("Rubber", rubber)


def traffic_cone(ctx):
    """Road cone, 75 cm kind (2.8 tall, base 1.4 x 1.4): hollow orange shell, two reflective
    collars, square rubber base; grime low down, tyre marks up one side."""
    _cone(ctx, worn=False)


def traffic_cone_worn(ctx):
    """The same cone run over: a crease in its side, squashed oval, chewed tip, filthy."""
    _cone(ctx, worn=True)



# ----------------------------------------------------------------------------------------------
# Shared helpers
# ----------------------------------------------------------------------------------------------
def _hexa(pts):
    """A closed six-faced solid from 8 corners: the bottom four, then the top four, both going
    round the same way (a tread block, a brick, a lettering stroke...)."""
    return loft([pts[:4], pts[4:]], cap_start=True, cap_end=True)


def _wrap(a):
    """An angle folded into -pi..pi."""
    return math.atan2(math.sin(a), math.cos(a))


def _interp(profile, x):
    """Linear interpolation in a sorted [(x, y)] table, clamped at both ends."""
    if x <= profile[0][0]:
        return profile[0][1]
    for (x0, y0), (x1, y1) in zip(profile, profile[1:]):
        if x <= x1:
            return lerp(y0, y1, (x - x0) / max(x1 - x0, 1e-9))
    return profile[-1][1]


def _modified(bm, mods):
    """Runs Blender modifiers over a bmesh (remesh, decimate, ...) and returns the result as a
    new bmesh (the input is freed). mods: [(type, {attribute: value})]."""
    me = bpy.data.meshes.new("_mod")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("_mod", me)
    bpy.context.scene.collection.objects.link(ob)
    for kind, attrs in mods:
        m = ob.modifiers.new(kind, kind)
        for k, v in attrs.items():
            setattr(m, k, v)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    out = bmesh.new()
    out.from_mesh(ev.to_mesh())
    ev.to_mesh_clear()
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    return out


# ----------------------------------------------------------------------------------------------
# Tyre / TyreBald. A worn car tyre lying flat (205/55 R16 kind, at the props' ~10 % large scale):
# 2.3 studs across (real 63 cm = 2.1), 0.74 tall at the sidewall bulge, the bead hole 1.47
# across (real 40.6 cm). Same footprint as props_ground.tyre (R 1.05-1.2, W 0.62-0.75); the stack
# is 2-3 copies placed by the data. Real reference (real_specs.md "CAR TYRE", photos of scrap
# tyres): the carcass is a rounded torus whose sidewalls BULGE past the tread, rounded shoulders,
# a rim-protector rib and a thick round bead lip round the hole; the tread is blocks: two
# shoulder rows and two centre rows split by circumferential grooves, the lateral grooves
# slanted (a directional pattern), the shoulder blocks running down over the shoulder; raised
# lettering in two arcs on the sidewall. Old rubber: dust caught on the upper sidewall and in
# the bead, grime in the grooves, a grey-brown blush where the sun hit, the lower half dirtier.
# TyreBald: tread worn to the wear bars, a dented bead, ovalised, dustier.
# The tread blocks are separate closed solids sunk 0.012 into the carcass: their sides CROSS the
# carcass surface (never coplanar); the lettering likewise.
# ----------------------------------------------------------------------------------------------
TY_RO = 1.15  # outer radius at the tread blocks' top
TY_YC = 0.37  # half the section width (the tyre lies on its lower sidewall bulge)


def _tyre_profile(depth, rib=None):
    """Upper half of the carcass section (r, dy from the mid-plane), from the crown up round the
    shoulder, out along the bulging sidewall, over the rim-protector rib, round the bead lip and
    down the bead's inner face. The carcass crown sits `depth` under the tread's top; the two
    centre ribs (continuous, like most road tyres) are part of the section: a centre groove, a
    rib, a second groove, then the shoulder where the separate blocks sit. rib: rib height."""
    rc = TY_RO - depth
    h = depth if rib is None else rib
    return [
        (rc, 0.0), (rc, 0.02), (rc + h - 0.006, 0.025), (rc + h, 0.031),
        (rc + h, 0.146), (rc + h - 0.006, 0.152), (rc, 0.157), (rc, 0.2), (rc - 0.004, 0.24),
        (rc - 0.014, 0.275), (rc - 0.034, 0.315),
        (rc - 0.07, 0.346), (rc - 0.12, 0.364), (0.97, 0.37), (0.91, 0.366), (0.86, 0.356),
        (0.825, 0.349), (0.808, 0.356), (0.79, 0.357), (0.776, 0.343), (0.762, 0.318),
        (0.748, 0.288), (0.742, 0.25), (0.732, 0.0),
    ]


# Old tyres: the "RubberWorn" layer (sun-greyed, dusty; plain "Rubber" is new black rubber).
RUBBER = "RubberWorn"


def _tyre(ctx, bald):
    """The tyre (see the block comment above): carcass lathe, tread blocks, lettering, wear."""
    ctx.budget = 5600
    ctx.smooth_angle = 40
    rng, noise = ctx.rng, ctx.noise
    depth = 0.02 if bald else 0.036
    half = _tyre_profile(depth)
    # the full section, closed: down the upper half (bead inside to crown), then the lower half
    prof = [(r, TY_YC + dy) for r, dy in reversed(half)] + [(r, TY_YC - dy) for r, dy in half[1:-1]]
    oval = rng.uniform(0.01, 0.018) * (2.0 if bald else 1.0)
    oval_a = rng.uniform(0, math.pi)
    dent_a = rng.uniform(0, 2 * math.pi)
    sag = rng.uniform(0.004, 0.01)

    def carcass_fn(a, r, y):
        d = r * oval * math.cos(2 * (a - oval_a))
        d += 0.006 * noise.n((math.cos(a) * 2.0, y * 2.0, math.sin(a) * 2.0))
        yy = y - sag * (1 + math.cos(a - oval_a)) * smoothstep(0.75, 1.1, r)  # a slight warp
        if bald and r < 0.8:
            # a dented bead: pushed out and down on one side (it was levered off a rim)
            g = math.exp(-(_wrap(a - dent_a) / 0.35) ** 2)
            d += 0.035 * g
            yy -= 0.02 * g * (1 if y > TY_YC else -1)
        return (r + d, yy)

    ctx.add(RUBBER, lathe(prof, segs=40, radius_fn=carcass_fn))

    # ---- tread blocks: 4 rows, slanted lateral grooves, the shoulders running over the shoulder
    def carc_r(dy):
        return _interp([(d, r) for r, d in half[6:12]], abs(dy))

    rows = [(-0.335, -0.2, 1), (0.2, 0.335, 1)]
    n = 56
    pitch = 2 * math.pi / n
    for ri, (y0, y1, shoulder) in enumerate(rows):
        off = (0.5 * pitch) if ri == 1 else 0.0
        side = -1 if y0 < 0 else 1
        fill = 0.7 if shoulder else 0.78  # share of the pitch that is block
        for k in range(n):
            a0 = k * pitch + off
            wear = bald and rng.random() < 0.6

            def corner(t_a, dy, top):
                # slanted: the block's angle shifts with |dy| (V-shaped, directional)
                a = a0 + t_a * pitch * fill + 0.45 * (abs(dy) - 0.2)
                y = TY_YC + dy
                r0 = carc_r(dy)
                if top:
                    h = depth * (0.55 if wear else 1.0)
                    # shoulder blocks: the outer corner drops with the shoulder's curve
                    r = r0 + h
                    if abs(dy) > 0.3:
                        y += side * 0.004
                else:
                    r = r0 - 0.012
                rr, yy = carcass_fn(a, r, y)
                return (rr * math.cos(a), yy, rr * math.sin(a))

            ys = (y0, y1)
            bot = [corner(0, ys[0], False), corner(1, ys[0], False), corner(1, ys[1], False), corner(0, ys[1], False)]
            # the top face a little smaller than the foot (blocks are tapered)
            ins = 0.06
            top = [corner(ins, ys[0] + 0.006, True), corner(1 - ins, ys[0] + 0.006, True),
                   corner(1 - ins, ys[1] - 0.006, True), corner(ins, ys[1] - 0.006, True)]
            ctx.add(RUBBER, _hexa(bot + top))

    # ---- raised lettering on the upper sidewall: two arcs (the maker, the size), stroke blocks
    def side_y(r):
        return TY_YC + _interp(sorted((rr, dy) for rr, dy in half[12:19]), r)

    for arc0, length in ((rng.uniform(0, math.pi), 0.95), (rng.uniform(math.pi, 2 * math.pi), 0.6)):
        a = arc0
        while a < arc0 + length:
            w = rng.uniform(0.018, 0.034)  # stroke width along the arc (radians at r ~0.9)
            r0, r1 = 0.865, 0.865 + rng.choice((0.07, 0.07, 0.045))
            if rng.random() < 0.25:
                r0 += 0.025
            pts = []
            for top in (False, True):
                for aa, rr in ((a, r0), (a + w, r0), (a + w, r1), (a, r1)):
                    y = side_y(rr) + (0.012 if top else -0.012)
                    rr2, yy = carcass_fn(aa, rr, y)
                    pts.append((rr2 * math.cos(aa), yy, rr2 * math.sin(aa)))
            ctx.add(RUBBER, _hexa(pts))
            a += w + rng.uniform(0.012, 0.03) + (0.06 if rng.random() < 0.15 else 0)

    # ---- wear
    dust_k = 1.0 if bald else 0.8

    def rubber(p):
        x, y, z = p.co
        r = math.hypot(x, z)
        k = 0.72
        # the upper sidewall (facing the sky) caught dust and sun blush: lighter, patchy
        up = smoothstep(0.3, 0.9, p.normal.y)
        k += 0.28 * up * (0.6 + 0.4 * smoothstep(-0.4, 0.5, noise.fbm((x * 2.5, 0, z * 2.5), 3)))
        # tread top faces: rubbed smooth and dusty
        if r > TY_RO - depth * 0.4:
            k = 0.9 + 0.1 * noise.n((x * 6, y * 6, z * 6))
        # grooves and the bead's inside: grime
        k *= 1 - 0.3 * smoothstep(0.0, 0.5, -p.convex)
        k *= 1 - 0.25 * (1 - smoothstep(0.0, 0.3, y)) * dust_k  # the bottom (mud, wet)
        if r < 0.75:
            k *= 0.85
        return k

    ctx.wear(RUBBER, rubber)


def tyre(ctx):
    """Old car tyre lying flat (2.3 across, 0.74 tall, hole 1.47): bulging sidewalls, four rows
    of slanted tread blocks, raised lettering, a bead lip; dusty upper sidewall."""
    _tyre(ctx, bald=False)


def tyre_bald(ctx):
    """The same tyre worn bald, its bead dented, ovalised, dustier (a stack mixes the two)."""
    _tyre(ctx, bald=True)


# ----------------------------------------------------------------------------------------------
# OilDrum / OilDrumBurn. The 200 L (55 US gal) steel drum: 1.9 studs across the hoops, 2.8 tall
# (real 58.4 x 88 cm; the props_objects.oil_drum footprint: d 1.85 + hoops, H 2.8). Real
# reference (real_specs.md "55-GAL STEEL DRUM", photos of scrap and burn barrels):
#   * a plain cylinder with two swaged ROLLING HOOPS at 1/3 and 2/3 of the height (a ridge 3 cm
#     proud with a small valley each side, pressed through the wall), faint corrugations between;
#   * rolled CHIMES top and bottom standing 2 cm past the heads, so the lid sits RECESSED; the
#     drum stands on its bottom chime;
#   * a closed head with a 2" bung and a 3/4" vent near the rim (ribbed / hex steel caps);
#   * a vertical weld seam; dents between the hoops; paint chipped on the hoops and chimes;
#   * rust: the bottom chime rusted through (its own Rust ring), rust scabs bubbling the paint
#     (proud Rust patches) with rust bleeding down under them (vertex colour), a half-torn
#     hazard label (a proud Paper patch, orange by vertex colour).
# OilDrumBurn: a burn barrel. The top cut off under the chime with a chisel (a jagged rim, a
# few teeth bent out), vent holes punched round the bottom (real holes through the wall, their
# petals bent in), the paint burnt off to rust and soot (Rust layer, black above), an ember bed
# 0.55 under the rim (Glow) with charred wood sticking out (Black), the glow of the fire seen
# through the holes, ash heaped round its foot. Markers: Fx (the flames) and Light at the top.
# No z-fighting: every patch / label / ring crosses or stands >= 0.01 off the surface it sits on.
# ----------------------------------------------------------------------------------------------
DR_R = 0.93  # shell radius
DR_H = 2.8
DR_HOOPS = (DR_H / 3, 2 * DR_H / 3)
DR_WALL = 0.03  # the burn barrel's wall (exaggerated from 1.2 mm so its cut rim reads)


def _hoop(y, r=DR_R):
    """A rolling hoop's profile points (r, y), bottom to top: valley, ridge, valley."""
    return [(r, y - 0.11), (r - 0.012, y - 0.075), (r + 0.012, y - 0.045), (r + 0.042, y - 0.018),
            (r + 0.046, y), (r + 0.042, y + 0.018), (r + 0.012, y + 0.045), (r - 0.012, y + 0.075), (r, y + 0.11)]


def _drum_wall(r, y0, y1, extra=()):
    """The outside of the shell from y0 to y1: the hoops, a faint corrugation midway between
    them, and any `extra` heights (more rings where holes or dents need them)."""
    pts = [(r, y) for y in extra if y0 < y < y1]
    for h in DR_HOOPS:
        if y0 < h < y1:
            pts += _hoop(h, r)
    for c in (DR_H / 6, DR_H / 2, 5 * DR_H / 6):
        if y0 < c - 0.08 and c + 0.08 < y1 and not any(abs(c - e) < 0.12 for e in extra):
            pts += [(r, c - 0.07), (r + 0.008, c), (r, c + 0.07)]
    pts += [(r, y0), (r, y1)]
    return sorted(pts, key=lambda p: p[1])


def _drum_deform(ctx, burnt):
    """Per-copy imperfections shared by the shell and everything laid on it: a dent or two
    between the hoops, a slight lean of the top, the weld seam's ridge. -> fn(a, r, y)."""
    rng, noise = ctx.rng, ctx.noise
    dents = []
    for _ in range(3 if burnt else 2):
        dents.append((rng.uniform(0, 2 * math.pi), rng.choice((0.5, 1.4, 2.3)) + rng.uniform(-0.12, 0.12),
                       rng.uniform(0.06, 0.1), rng.uniform(0.28, 0.42)))
    seam = rng.uniform(0, 2 * math.pi)
    lean_a = rng.uniform(0, 2 * math.pi)

    def fn(a, r, y):
        if r < 0.5:  # (the heads: only the lean)
            return (r, y + 0.01 * math.cos(a - lean_a) * smoothstep(2.5, 2.8, y))
        d = 0.0
        for da, dy, depth, size in dents:
            g = math.exp(-(_wrap(a - da) * DR_R / size) ** 2 - ((y - dy) / (size * 0.8)) ** 2)
            # (the hoops stiffen the wall: dents fade out at them)
            stiff = min(smoothstep(0.06, 0.2, abs(y - h)) for h in DR_HOOPS)
            d -= depth * g * stiff
        d += 0.004 * noise.n((math.cos(a) * 3, y * 2, math.sin(a) * 3))
        if abs(_wrap(a - seam)) < 1e-3 and 0.09 < y < DR_H - 0.09:
            d += 0.006  # the weld seam
        return (r + d, y + 0.01 * math.cos(a - lean_a) * smoothstep(2.5, 2.8, y))

    fn.seam = seam
    return fn


def _patch(deform, a0, y0, w, h, out, inn, rng, n=12, r=DR_R):
    """An irregular patch lying on the shell (a rust scab, a torn label): outer face `out` above
    the shell, inner face `inn` under it (so it never shares the shell's surface), outline
    w x h with a ragged edge, following the shell's dents (deform)."""
    jag = [rng.uniform(0.7, 1.15) for _ in range(n)]

    def ring(scale, dr):
        pts = []
        for k in range(n):
            t = 2 * math.pi * k / n
            u, v = math.cos(t) * w / 2 * jag[k] * scale, math.sin(t) * h / 2 * jag[k] * scale
            a, y = a0 + u / r, y0 + v
            rr, yy = deform(a, r + dr, y)
            pts.append((rr * math.cos(a), yy, rr * math.sin(a)))
        return pts

    def pole(dr):
        rr, yy = deform(a0, r + dr, y0)
        return [(rr * math.cos(a0), yy, rr * math.sin(a0))]

    return loft([pole(out), ring(0.55, out), ring(1.0, out), ring(1.0, -inn), ring(0.55, -inn), pole(-inn)])


def _label(deform, a0, y0, s, rng, r=DR_R):
    """A diamond hazard label stuck on the shell with its right corner torn off (a jagged tear):
    a thin proud card, 0.012 off the paint, its back 0.012 into it."""
    h = s / 2
    tear = [(h * 0.42, h * 0.5), (h * 0.5, h * 0.3), (h * 0.36, h * 0.14), (h * 0.47, -0.02),
            (h * 0.3, -h * 0.2), (h * 0.44, -h * 0.5)]
    outline = [(0.0, h)] + [(u + rng.uniform(-0.02, 0.02), v) for u, v in tear] + [(0.0, -h), (-h, 0.0)]
    outline.reverse()  # (counter-clockwise seen from outside)

    def ring(scale, dr):
        pts = []
        for u, v in outline:
            a, y = a0 + u * scale / r, y0 + v * scale
            rr, yy = deform(a, r + dr, y)
            pts.append((rr * math.cos(a), yy, rr * math.sin(a)))
        return pts

    def pole(dr):
        rr, yy = deform(a0 - 0.1 / r, r + dr, y0)
        return [(rr * math.cos(a0 - 0.1 / r), yy, rr * math.sin(a0 - 0.1 / r))]

    # (rings at 0.82 / 0.86: the vertex colours need them to draw the black border)
    return loft([pole(0.012), ring(0.3, 0.012), ring(0.58, 0.012), ring(0.82, 0.012), ring(0.86, 0.012),
                 ring(1.0, 0.012), ring(1.0, -0.012), ring(0.5, -0.012), pole(-0.012)])


def _bung(ctx, x, z, y, big):
    """A bung on the head: a round flange and a ribbed hex cap (steel)."""
    rf, rc = (0.15, 0.105) if big else (0.085, 0.058)
    ctx.add("Metal", lathe([(0.0, y - 0.01), (rf, y - 0.01), (rf, y + 0.018), (rf - 0.015, y + 0.03),
                            (0.0, y + 0.03)], segs=20), T(x, 0, z))
    ctx.add("Metal", lathe([(0.0, y + 0.02), (rc, y + 0.02), (rc, y + 0.06), (rc - 0.012, y + 0.072),
                            (0.0, y + 0.072)], segs=6), T(x, 0, z) @ R(0, 15, 0))


def _oil_drum(ctx):
    ctx.budget = 6000
    ctx.smooth_angle = 38
    ctx.tint("MetalPainted", (34, 66, 112))  # RAL 5010-ish blue, dulled (the data picks others)
    rng, noise = ctx.rng, ctx.noise
    deform = _drum_deform(ctx, False)
    seam_angles = [deform.seam + d for d in (-0.02, 0.0, 0.02)]
    head = 0.055  # the heads sit this far inside the chimes
    # the shell: bottom head, up the wall, the top chime rolled over, the recessed top head
    prof = [(0.0, head + 0.004), (DR_R - 0.07, head + 0.004), (DR_R - 0.045, 0.07)]
    prof += _drum_wall(DR_R, 0.085, DR_H - 0.075)
    prof += [(DR_R + 0.02, DR_H - 0.06), (DR_R + 0.032, DR_H - 0.035), (DR_R + 0.026, DR_H - 0.008),
             (DR_R + 0.008, DR_H), (DR_R - 0.016, DR_H - 0.004), (DR_R - 0.03, DR_H - 0.02),
             (DR_R - 0.04, DR_H - head), (DR_R - 0.07, DR_H - head - 0.004), (0.0, DR_H - head - 0.004)]
    ctx.add("MetalPainted", lathe(prof, segs=48, extra_angles=seam_angles, radius_fn=deform))
    # the bottom chime, rusted through: its own ring, the shell's bottom end buried inside it
    chime = [(DR_R - 0.05, 0.0), (DR_R + 0.022, 0.0), (DR_R + 0.034, 0.03), (DR_R + 0.024, 0.07),
             (DR_R + 0.004, 0.092), (DR_R - 0.022, 0.085), (DR_R - 0.055, 0.05), (DR_R - 0.06, 0.02)]
    ctx.add("Rust", lathe(chime, segs=48, extra_angles=seam_angles, radius_fn=deform))
    # bungs: the 2" and the 3/4" near the rim, on opposite sides of the centre line
    ba = rng.uniform(0, 2 * math.pi)
    yh = DR_H - head - 0.004
    _bung(ctx, math.cos(ba) * 0.6, math.sin(ba) * 0.6, yh, True)
    _bung(ctx, math.cos(ba + 2.6) * 0.66, math.sin(ba + 2.6) * 0.66, yh, False)
    # rust scabs, low down and on the hoops (where water sits and the paint chipped)
    scabs = []
    for _ in range(rng.randint(6, 8)):
        a = rng.uniform(0, 2 * math.pi)
        # (on the plain wall only: a flat scab laid over a hoop's ridge would stand off it)
        y = rng.choice((rng.uniform(0.2, 0.62), rng.uniform(0.2, 0.62), rng.uniform(1.12, 1.68),
                        rng.uniform(2.06, 2.5)))
        w, h = rng.uniform(0.16, 0.36), rng.uniform(0.1, 0.22)
        ctx.add("Rust", _patch(deform, a, y, w, h, 0.012, 0.02, rng))
        scabs.append((a, y, w))
    # the hazard label, half torn off (orange by vertex colour), mid-height on the front
    la, ly = -math.pi / 2 + rng.uniform(-0.5, 0.5), rng.uniform(1.15, 1.6)
    ctx.add("Paper", _label(deform, la, ly, 0.44, rng))

    def paint(p):
        x, y, z = p.co
        a = math.atan2(z, x)
        r = math.hypot(x, z)
        # faded and dirty: a broken-up base tone, darker low down (splashes, wet ground)
        k = 0.82 + 0.18 * smoothstep(-0.5, 0.5, noise.fbm((x * 1.5, y * 1.2, z * 1.5), 3))
        k *= 1 - 0.35 * (1 - smoothstep(0.05, 0.7 + 0.25 * noise.fbm((x * 2, 0, z * 2), 2), y))
        # rust bleeding down from each scab: brown streaks under it
        rb = 0.0
        for sa, sy, sw in scabs:
            du = abs(_wrap(a - sa)) * DR_R
            if y < sy:
                rb = max(rb, math.exp(-(du / max(sw, 0.2)) ** 2) * math.exp(-(sy - y) / 0.9)
                         * smoothstep(-0.4, 0.2, noise.fbm((a * 7, y * 0.5, 0), 2)))
            else:
                rb = max(rb, math.exp(-(du / (sw * 0.6)) ** 2 - ((y - sy) / 0.15) ** 2))
        # chipped hoops and top chime: worn darker (steel showing, going brown)
        chip = 0.0
        if r > DR_R + 0.015:
            chip = 0.9 * smoothstep(-0.1, 0.4, noise.fbm((x * 5, y * 5, z * 5), 2))
        if y < 0.4:  # the rust ring creeping up from the chime
            chip = max(chip, (1 - smoothstep(0.08, 0.4, y)) * smoothstep(-0.4, 0.3, noise.fbm((a * 6, y * 3, 0), 2)))
        k *= 1 - 0.12 * smoothstep(0.25, 0.8, noise.fbm((x * 3, y * 3, z * 3), 2) * 0.5 + 0.5)  # scuffs
        k *= 1 - 0.25 * smoothstep(0.0, 0.5, -p.convex)
        if y > DR_H - 0.2 and p.normal.y > 0.7:
            k *= 0.8 + 0.2 * noise.n((x * 4, 0, z * 4))  # rainwater stains on the head
        f = max(rb, chip)
        f = min(1.0, f)
        return (k * (1 - 0.1 * f), k * (1 - 0.5 * f), k * (1 - 0.68 * f))

    def rust(p):
        x, y, z = p.co
        k = 0.75 + 0.25 * smoothstep(-0.5, 0.6, noise.fbm((x * 6, y * 6, z * 6), 3))
        return k * (1 - 0.2 * smoothstep(0.0, 0.5, -p.convex))

    def label(p):
        x, y, z = p.co
        a = math.atan2(z, x)
        u, v = _wrap(a - la) * DR_R, y - ly
        # the hazard diamond: an orange square on its point with a dark border and symbol, dirty
        d = abs(u) + abs(v)
        k = 0.8 + 0.2 * noise.n((x * 8, y * 8, z * 8))
        k *= 1 - 0.3 * smoothstep(0.0, 0.5, -v / 0.22)  # rain-dirtied toward its bottom
        if d > 0.185:
            return (k * 0.2, k * 0.2, k * 0.2)  # the black border
        if v < -0.02:
            return (k, k, k * 0.95)  # the white lower half
        return (k * 0.95, k * 0.48, k * 0.16)  # the orange upper half

    ctx.wear("MetalPainted", paint)
    ctx.wear("Rust", rust)
    ctx.wear("Paper", label)
    ctx.wear("Metal", lambda p: 0.7 + 0.3 * smoothstep(0.0, 0.5, p.convex + 0.2))


def oil_drum(ctx):
    """200 L steel drum (1.9 x 2.8): rolling hoops, chimes, recessed head with two bungs, weld
    seam, dents, rust scabs bleeding down, a torn hazard label, the bottom chime rusted."""
    _oil_drum(ctx)


BB_TOP = DR_H - 0.13  # the burn barrel's cut rim (mean), under where the top chime was
BB_EMBERS = DR_H - 0.55  # the ember bed (as props_objects.oil_drum's "fire" state)
BB_HOLES = (0.3, 0.62)  # the band of punched vent holes


def _burn_shell(ctx, deform):
    """The burn barrel's shell: one lathe, outside up to the jagged cut rim and back down the
    inside, the bottom closed by the head; then the vent holes cut THROUGH it (the faces of the
    outer and inner skins removed in each hole's window and the two openings bridged, so each
    hole has a real thickness), their edges bent in."""
    rng, noise = ctx.rng, ctx.noise
    holes = []
    a = rng.uniform(0, 2 * math.pi)
    for _ in range(5):
        a += 2 * math.pi / 5 + rng.uniform(-0.3, 0.3)
        holes.append(a % (2 * math.pi))
    step = 0.065
    hole_angles = [h + k * step for h in holes for k in (-1, 0, 1)]
    band = [BB_HOLES[0] + k * 0.08 for k in range(5)]  # (0.3 .. 0.62: the holes' rows of vertices)
    teeth = [rng.uniform(0.0, 1.0) for _ in range(48)]  # (one per ~0.12 studs of rim)
    flare_a = rng.uniform(0, 2 * math.pi)

    def fn(a, r, y):
        r, y = deform(a, r, y)
        # the chisel-cut rim: teeth of different heights, a few bent outward
        k = smoothstep(BB_TOP - 0.25, BB_TOP, y)
        if k > 0:
            t = (a % (2 * math.pi)) / (2 * math.pi) * 48
            i = int(t) % 48
            f = t - int(t)
            tooth = lerp(teeth[i], teeth[(i + 1) % 48], f) if f < 0.5 else teeth[(i + 1) % 48]
            y -= k * (0.05 + 0.1 * tooth + 0.04 * noise.n((math.cos(a) * 3, 2.0, math.sin(a) * 3)))
            g = math.exp(-(_wrap(a - flare_a) / 0.35) ** 2)
            r += k * k * (0.1 * g + 0.025 * max(0.0, noise.n((math.cos(a) * 5, 9.0, math.sin(a) * 5))))
        # the punched holes: the metal round each one pushed in
        for h in holes:
            du = abs(_wrap(a - h))
            if du < 0.18 and BB_HOLES[0] - 0.12 < y < BB_HOLES[1] + 0.12:
                g = math.exp(-(du / 0.11) ** 2 - ((y - 0.46) / 0.2) ** 2)
                r -= 0.035 * g
        return (r, y)

    wall_out = _drum_wall(DR_R, 0.085, BB_TOP, extra=band)
    # the inside: plain (its hoops are hidden under the embers), the same rows as the outside
    # where the holes are, so their two openings match
    wall_in = [(DR_R - DR_WALL, y) for y in [0.12] + band + [0.8, 1.5, BB_EMBERS - 0.2, BB_EMBERS + 0.2,
                                                           BB_TOP - 0.12]]
    head = 0.06
    prof = [(0.0, head), (DR_R - 0.07, head), (DR_R - 0.045, 0.07)] + wall_out
    prof += [(DR_R - DR_WALL * 0.3, BB_TOP + 0.012), (DR_R - DR_WALL * 0.7, BB_TOP + 0.012)]  # the cut edge
    prof += list(reversed(wall_in))
    prof += [(DR_R - DR_WALL - 0.02, head + DR_WALL), (0.0, head + DR_WALL)]
    bm = lathe(prof, segs=40, extra_angles=hole_angles, radius_fn=fn)

    # ---- cut the holes through: per hole, the faces of both skins inside its window go, the
    # two openings are bridged
    for h in holes:
        width = rng.choice((0.7, 1.1)) * step  # (half-width: 2 cells wide, or 2 and a sliver)
        y0, y1 = (0.38, 0.54) if rng.random() < 0.5 else (0.38, 0.62)
        dead = []
        for f in bm.faces:
            c = f.calc_center_median()
            a = math.atan2(c.z, c.x)
            if abs(_wrap(a - h)) < width and y0 < c.y < y1 and math.hypot(c.x, c.z) > 0.5:
                dead.append(f)
        if len(dead) < 4:
            continue
        bmesh.ops.delete(bm, geom=dead, context="FACES")
        edges = [e for e in bm.edges if len(e.link_faces) == 1]
        bmesh.ops.bridge_loops(bm, edges=edges)
    return bm, holes


def _oil_drum_burn(ctx):
    ctx.budget = 7600
    ctx.smooth_angle = 40
    rng, noise = ctx.rng, ctx.noise
    deform = _drum_deform(ctx, True)
    shell, holes = _burn_shell(ctx, deform)
    ctx.add("Rust", shell)
    chime = [(DR_R - 0.05, 0.0), (DR_R + 0.022, 0.0), (DR_R + 0.034, 0.03), (DR_R + 0.024, 0.07),
             (DR_R + 0.004, 0.092), (DR_R - 0.022, 0.085), (DR_R - 0.055, 0.05), (DR_R - 0.06, 0.02)]
    ctx.add("Rust", lathe(chime, segs=48, radius_fn=deform))

    # ---- the fire inside: a flat glowing bed (Glow) under a lumpy crust of charcoal and ash
    # (Black) that dips under it here and there, so the embers glow through in cracks and pits
    # (the two surfaces cross, never coplanar); charred boards sticking up out of it; the glow
    # at the bottom seen through the holes (Glow, never seen otherwise). Their rims follow the
    # shell's dents (deform) so nothing pokes out through a dent.
    rin = DR_R - DR_WALL - 0.004

    def rim(a, r, y):
        if r > 0.8:
            return (deform(a, r, y)[0] - DR_R + r, y)
        return (r, y)

    ctx.add("Glow", lathe([(0.0, BB_EMBERS - 0.1), (rin + 0.01, BB_EMBERS - 0.1), (rin + 0.01, BB_EMBERS),
                           (0.0, BB_EMBERS)], segs=40, radius_fn=rim))

    def crust(a, r, y):
        rr, yy = rim(a, r, y)
        if y > BB_EMBERS - 0.05 and r < rin:
            q = (math.cos(a) * r * 3.0, 0.0, math.sin(a) * r * 3.0)
            yy += 0.05 * noise.fbm(q, 3) + 0.03 * (noise.ridge(q, 1.7) - 0.5) - 0.02
        return (rr, yy)

    ring_r = [rin * k for k in (1.0, 0.93, 0.84, 0.74, 0.63, 0.52, 0.41, 0.3, 0.19, 0.08)]
    prof = [(0.0, BB_EMBERS - 0.08), (rin + 0.012, BB_EMBERS - 0.08), (rin + 0.012, BB_EMBERS + 0.03)]
    prof += [(r, BB_EMBERS + 0.02 + 0.03 * (1 - r / rin)) for r in ring_r[1:]] + [(0.0, BB_EMBERS + 0.05)]
    ctx.add("Black", lathe(prof, segs=40, radius_fn=crust))
    ctx.add("Glow", lathe([(0.0, 0.05), (rin - 0.05, 0.05), (rin - 0.05, 0.85), (0.0, 0.85)], segs=20))
    for k in range(3):
        a = rng.uniform(0, 2 * math.pi) + k * 2.1
        L = rng.uniform(0.9, 1.5)
        plank = box(rng.uniform(0.3, 0.45), L, 0.1, bevel=0.025, segments=1)
        bmesh.ops.subdivide_edges(plank, edges=[e for e in plank.edges
                                                if abs(e.verts[0].co.y - e.verts[1].co.y) > L * 0.5],
                                  cuts=3, use_grid_fill=True)
        # charred: the top burnt away in a ragged, thinned end, the faces checked
        for v in plank.verts:
            t = (v.co.y + L / 2) / L
            if t > 0.4:
                v.co.y -= 0.22 * t * (0.5 + 0.5 * noise.n((v.co.x * 9, 3.0 + k, v.co.z * 9)))
                v.co.x *= 1 - 0.35 * smoothstep(0.6, 1.0, t)
        lean = rng.uniform(20, 38)
        ctx.add("Black", plank, T(math.cos(a) * 0.3, BB_EMBERS - 0.2 + L / 2 * 0.85, math.sin(a) * 0.3)
                @ R(0, -math.degrees(a) + rng.uniform(-30, 30), 0) @ R(0, 0, -lean))

    # ---- ash heaped round its foot (two low lumpy mounds)
    for _ in range(2):
        a = rng.uniform(0, 2 * math.pi)
        rr = DR_R + rng.uniform(0.15, 0.3)
        sx, sz, sh = rng.uniform(0.6, 0.9), rng.uniform(0.45, 0.6), rng.uniform(0.05, 0.08)

        def mound(a2, r, y, seed=a):
            return (r * (1 + 0.18 * noise.n((math.cos(a2) * 2 + seed, 0, math.sin(a2) * 2))), y)

        # (a soft, low heap: its foot 0.02 under the floor, so the edge melts into it)
        heap = lathe([(0.0, -0.02), (1.0, -0.02), (0.85, sh * 0.25), (0.55, sh * 0.75), (0.25, sh * 0.97),
                      (0.0, sh)], segs=14, radius_fn=mound)
        ctx.add("Concrete", heap, T(math.cos(a) * rr, 0, math.sin(a) * rr) @ R(0, rng.uniform(0, 180), 0)
                @ S(sx, 1, sz))

    ctx.mark("Fx", (0, BB_EMBERS + 0.15, 0))
    ctx.mark("Light", (0, DR_H + 0.2, 0))

    def burnt(p):
        x, y, z = p.co
        r = math.hypot(x, z)
        a = math.atan2(z, x)
        if r < DR_R - DR_WALL * 0.8 and y > BB_EMBERS - 0.2:
            return 0.38  # the inside above the embers: soot
        # rust brown below, burnt black above (soot licking up the outside from the rim)
        soot = smoothstep(0.9, 2.2, y + 0.4 * noise.fbm((math.cos(a) * 2, y * 0.8, math.sin(a) * 2), 3))
        k = 0.85 + 0.15 * smoothstep(-0.4, 0.5, noise.fbm((x * 5, y * 5, z * 5), 3))
        k *= 1 - 0.68 * soot
        # round the holes: blackened by the fire inside
        for h in holes:
            du = abs(_wrap(a - h)) * DR_R
            k *= 1 - 0.5 * math.exp(-(du / 0.25) ** 2 - ((y - 0.5) / 0.3) ** 2)
        k *= 1 - 0.25 * (1 - smoothstep(0.0, 0.3, y))
        return (k, k * (0.92 - 0.1 * soot), k * (0.85 - 0.12 * soot))

    def glow(p):
        x, y, z = p.co
        if y < 1.0:
            return (1.0, 0.6, 0.35)
        # the embers: deep orange, hotter (yellower) in spots
        n = noise.fbm((x * 4, y, z * 4), 3)
        return (1.0, 0.5 + 0.35 * smoothstep(0.0, 0.6, n), 0.22 + 0.3 * smoothstep(0.2, 0.7, n))

    def ash(p):
        x, y, z = p.co
        k = 0.42 + 0.2 * smoothstep(-0.4, 0.5, noise.fbm((x * 5, y * 5, z * 5), 2))
        return k * (0.75 + 0.25 * smoothstep(0.0, 0.05, y))

    ctx.wear("Rust", burnt)
    ctx.wear("Glow", glow)
    ctx.wear("Concrete", ash)
    def black(p):
        x, y, z = p.co
        # white-grey ash on the crust's high points, charcoal in the dips
        if abs(y - BB_EMBERS) < 0.12 and math.hypot(x, z) < rin:
            hi = smoothstep(0.0, 0.05, y - BB_EMBERS - 0.01)
            return 0.7 + 0.3 * hi
        return 0.75 + 0.25 * smoothstep(0.0, 0.5, p.convex)

    ctx.wear("Black", black)


def oil_drum_burn(ctx):
    """The same drum as a burn barrel: top cut off (jagged rim, teeth bent out), vent holes
    punched round the bottom, paint burnt to rust and soot, an ember bed with charred wood,
    ash at its foot. Markers: Fx (flames, on the embers) and Light (above the rim)."""
    _oil_drum_burn(ctx)


# ----------------------------------------------------------------------------------------------
# ConcreteChunk1 / ConcreteChunk2. Broken pieces of a cast concrete slab (props_ground
# .concrete_chunk: size 0.6-2.2, "size=1.6, rebar=True" in alley B; the data scales them with
# Scale = size / 1.6). Real reference (photos of demolition debris; the audit's "slab fragment
# with two flat cast faces and the other sides rough conchoidal fracture, exposed aggregate,
# chipped edges, and a rebar stub bent with a rusty ribbed surface"):
#   * ConcreteChunk1: a slab fragment 1.7 x 0.5 x 1.2 (a 15 cm slab), its top and bottom the
#     flat cast faces (weathered, darker), every other side a rough fracture (paler, fresh),
#     two ribbed rebars along its mid-plane sticking out of the broken end, one bent up;
#   * ConcreteChunk2: a smaller, thicker lump (1.0 x 0.6 x 0.8) broken on most sides, one cast
#     face left, no steel.
# How: a box cut by random planes (the breaks), voxel-remeshed for an even mesh, every vertex
# not on a cast face pushed along its normal by ridged noise (the fracture's relief), then
# decimated to budget. Lying on the floor slightly tilted, its lowest point 0.03 into it.
# ----------------------------------------------------------------------------------------------
def _fragment(rng, noise, size, cuts, cast=(1, -1), rough=0.1, edge=0.11):
    """A broken concrete fragment: a box size=(x, y, z) centred, cut by `cuts` planes: the big
    breaks across the slab (normals mostly sideways) and small chips knocked off its edges and
    corners (normals half up / down, near the surface). Broken concrete is ANGULAR: flat-ish
    facets meeting at sharp ridges, so the planes do the shaping; then every face is cut into
    triangles no longer than `edge` and the fracture faces get a little relief and grit. The
    cast faces (+Y top, -Y bottom: those listed in `cast`) stay flat.
    -> (bmesh, is_fracture(co_local) function)."""
    sx, sy, sz = size
    bm = box(sx, sy, sz)
    for k in range(cuts):
        a = rng.uniform(0, 2 * math.pi)
        if k % 2 == 0:  # a break across the slab
            n = Vector((math.cos(a), rng.uniform(-0.35, 0.35), math.sin(a))).normalized()
            depth = rng.uniform(0.4, 0.75)
        else:  # a chip off an edge / corner
            n = Vector((math.cos(a), rng.choice((-1, 1)) * rng.uniform(0.6, 1.1), math.sin(a))).normalized()
            depth = rng.uniform(0.78, 0.9)
        reach = abs(n.x) * sx / 2 + abs(n.y) * sy / 2 + abs(n.z) * sz / 2
        co = n * reach * depth
        res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=co, plane_no=n,
                                     clear_outer=True)
        cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if cut:
            bmesh.ops.holes_fill(bm, edges=cut, sides=0)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    for _ in range(6):
        long = [e for e in bm.edges if e.calc_length() > edge]
        if not long:
            break
        bmesh.ops.subdivide_edges(bm, edges=long, cuts=1, use_grid_fill=False)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.normal_update()

    def cast_side(v):
        """+1 / -1 if v lies in a cast face's plane (listed in `cast`), else 0."""
        for c in cast:
            if abs(v.co.y - c * sy / 2) < 1e-4:
                return c
        return 0

    flags = {}
    moves = {}
    for v in bm.verts:
        c = cast_side(v)
        in_cast = c != 0 and all(abs(f.normal.y) > 0.99 for f in v.link_faces)
        q = v.co * 2.0
        if in_cast:
            moves[v] = Vector((0, 0.003 * noise.n(v.co * 6), 0))  # (cast, not machined)
        else:
            # conchoidal relief: broad shell-like lumps, a few sharp ridges, fine grit
            d = rough * (0.5 * noise.fbm(q, 3) + 0.7 * (noise.ridge(q * 1.8) - 0.65) + 0.35 * noise.n(q * 5))
            nrm = v.normal.copy()
            if c != 0:
                d = -abs(d) * 0.5  # (on a cast face's rim: never bulging over the face)
            moves[v] = nrm * d
        flags[v.index] = not in_cast
    pts = []
    for v in bm.verts:
        v.co += moves[v]
        pts.append((v.co.copy(), flags[v.index]))
    kd = KDTree(len(pts))
    for i, (co, _) in enumerate(pts):
        kd.insert(co, i)
    kd.balance()

    def is_fracture(co):
        return pts[kd.find(co)[1]][1]

    return bm, is_fracture


def _rebar(path, rng, r=0.05, rib=0.007, segs=8, pitch=0.05):
    """A length of rebar along `path` (points): ribbed (rings of alternating radius every
    `pitch` studs), its ends cut square. Thicker than real (a 12 mm bar is 0.04 studs) so it
    reads."""
    pts = []
    for p0, p1 in zip(path, path[1:]):
        p0, p1 = Vector(p0), Vector(p1)
        n = max(2, int((p1 - p0).length / pitch))
        for k in range(n):
            pts.append(p0.lerp(p1, k / n))
    pts.append(Vector(path[-1]))
    radii = [r + (rib if i % 2 else 0.0) for i in range(len(pts))]
    radii[0] = radii[-1] = r
    return tube(pts, radii, segs=segs)


def _chunk(ctx, size, cuts, rebars, tilt, cast, edge):
    """A concrete fragment piece (see the block comment above)."""
    rng, noise = ctx.rng, ctx.noise
    ctx.smooth_angle = 26  # (crisp facets: broken concrete is sharp)
    bm, is_fracture = _fragment(rng, noise, size, cuts, cast=cast, edge=edge)
    bars = [_rebar(p, rng, segs=6, pitch=0.065) for p in rebars]
    m = R(*tilt)
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    low = min(v.co.y for v in bm.verts)
    lift = T(0, -low - 0.03, 0)
    bmesh.ops.transform(bm, matrix=lift, verts=bm.verts)
    inv = (lift @ m).inverted()
    ctx.add("Concrete", bm)
    exits = []
    for b, p in zip(bars, rebars):
        ctx.add("Rust", b, lift @ m)
        exits.append((lift @ m) @ Vector(p[0]).lerp(Vector(p[1]), 0.5))

    def concrete(pv):
        local = inv @ pv.co
        fresh = is_fracture(local)
        q = pv.co * 9
        grit = 0.08 * noise.n(q) + 0.05 * noise.n(q * 2.3)  # exposed aggregate (where it can show)
        if fresh:
            k = 0.86 + 0.12 * smoothstep(-0.5, 0.5, noise.fbm(pv.co * 3, 3)) + grit
        else:
            # the cast faces: weathered, stained in blotches
            k = 0.68 + 0.14 * smoothstep(-0.4, 0.5, noise.fbm(pv.co * 1.5, 3)) + grit * 0.5
        k *= 1 - 0.45 * smoothstep(0.0, 0.4, -pv.convex)  # dirt in the pits
        k *= 1 + 0.08 * smoothstep(0.1, 0.5, pv.convex)  # dust caught on the ridges
        k *= 1 - 0.3 * (1 - smoothstep(0.0, 0.18, pv.co.y))  # ground contact
        rust = 0.0
        for e in exits:
            d = (pv.co - e).length
            if pv.co.y < e.y + 0.05:
                rust = max(rust, math.exp(-(d / 0.3) ** 2))
        return (k * (1 - 0.15 * rust), k * (1 - 0.4 * rust), k * (1 - 0.55 * rust))

    def steel(pv):
        return 0.7 + 0.3 * smoothstep(-0.3, 0.6, noise.fbm(pv.co * 8, 2))

    ctx.wear("Concrete", concrete)
    if bars:
        ctx.wear("Rust", steel)


def concrete_chunk1(ctx):
    """Broken slab fragment (1.7 x 0.5 x 1.2): flat weathered cast faces, rough pale fracture
    sides, two ribbed rusty rebars sticking out of the broken end, one bent up."""
    ctx.budget = 3000
    _chunk(ctx, (1.7, 0.5, 1.2), 9,
           [[(-0.3, -0.02, -0.28), (0.98, -0.02, -0.3), (1.12, 0.0, -0.31)],
            [(-0.2, 0.02, 0.26), (0.95, 0.02, 0.27), (1.12, 0.06, 0.29), (1.24, 0.3, 0.33), (1.28, 0.52, 0.36)]],
           tilt=(4, 18, -6), cast=(1, -1), edge=0.12)


def concrete_chunk2(ctx):
    """A smaller, thicker lump of broken concrete (1.0 x 0.6 x 0.8): fracture all round, one
    cast face left, no steel."""
    ctx.budget = 2200
    _chunk(ctx, (1.1, 0.52, 0.86), 12, [], tilt=(-9, -25, 7), cast=(1,), edge=0.085)


# ----------------------------------------------------------------------------------------------
# RubblePile1 / RubblePile2. A heap of demolition rubble (props_ground.rubble_pile: radius
# 2.2-3.4, about 0.38 x radius tall; the data scales the piece with Scale = radius / 2.6).
# Real reference (photos of demolition sites; the audit: "a heap at its angle of repose with a
# soft rounded crest, a granular surface of fines and gravel, half-buried broken slab pieces,
# rebar bent in curves, brick halves, a dust skirt fading out"):
#   * ONE mound of fines (Concrete, dusty by vertex colour): a soft crest, slopes that steepen
#     then flatten into a skirt sunk 0.03 into the floor, a lumpy, gravelly surface, an
#     irregular outline; its shape stays close to the old wedge cone (height ~0.38 x radius),
#     which remains the invisible collision, so feet land on it;
#   * concrete fragments (the ConcreteChunk recipe, smaller) and bricks (whole, half, broken)
#     half buried in the slopes, more near the foot (they roll down), tilted with the slope;
#   * rusty rebar bent in curves sticking out of the top, a broken plank slid down a side.
# Everything crosses the mound's surface at an angle (never lies in it): no z-fighting.
# RubblePile2 is longer (two crests), with a leaning slab piece and more brick.
# ----------------------------------------------------------------------------------------------
RP_R, RP_H = 2.6, 1.2  # (H / R ~0.46: a tipped heap of rubble settles near its angle of repose)


def _mound(noise, R, H, stretch=(1.0, 1.0), crests=((0.0, 0.0, 1.0),)):
    """The mound as a height function and its mesh. crests: [(x, z, weight)] (one or two tops).
    -> (bm, height(x, z))."""
    sx, sz = stretch

    def outline(a):
        # (lobes and bays, not a circle: a heap is tipped load by load)
        return R * (1 + 0.3 * noise.fbm((math.cos(a) * 0.9, 4.0, math.sin(a) * 0.9), 2)
                    + 0.12 * noise.n((math.cos(a) * 3, 7.0, math.sin(a) * 3)))

    def height(x, z):
        best = 0.0
        for cx, cz, w in crests:
            dx, dz = (x - cx) / sx, (z - cz) / sz
            a = math.atan2(dz, dx)
            t = math.hypot(dx, dz) / outline(a)
            if t < 1:
                best = max(best, w * H * (1 - t ** 1.9) ** 1.5)
        q = (x * 1.4, 0.0, z * 1.4)
        lumps = 0.1 * noise.fbm(q, 3) + 0.06 * noise.n((x * 4, 1.0, z * 4)) + 0.03 * noise.n((x * 9, 2.0, z * 9))
        return best + lumps * smoothstep(0.0, 0.25, best) - 0.03 * (1 - smoothstep(0.0, 0.1, best))

    rings = []
    nr, segs = 20, 60
    # (out past the outline's widest lobe: 1 + 0.3 + 0.12 at most)
    span = R * 1.45 * max(sx, sz) + max(math.hypot(cx, cz) for cx, cz, _ in crests)

    def reach(a):
        """How far the heap goes along the direction a (its foot), + a thin skirt."""
        far = 0.3
        for i in range(1, 121):
            r = span * i / 120
            if height(math.cos(a) * r, math.sin(a) * r) > 0.0:
                far = r
        return far + 0.12

    reaches = [reach(2 * math.pi * j / segs) for j in range(segs)]
    for k in range(nr, 0, -1):
        t = (k / nr) ** 1.25
        ring = []
        for j in range(segs):
            a = 2 * math.pi * j / segs
            r = t * reaches[j]  # (the rings follow the foot's lobes and bays)
            x, z = math.cos(a) * r, math.sin(a) * r
            ring.append((x, max(height(x, z), -0.03), z))
        rings.append(ring)
    rings.append([(0.0, height(0.0, 0.0), 0.0)])
    bottom = [(p[0], -0.03, p[2]) for p in rings[0]]
    bm = loft([bottom] + rings, cap_start=True)
    return bm, height


def _brick(rng, noise, half=False):
    """A brick (21.5 x 10 x 6.5 cm at the props' scale: 0.78 x 0.37 x 0.24), rounded arrises,
    whole or a half bat with a broken end."""
    L = 0.78 * (rng.uniform(0.45, 0.6) if half else 1.0)
    bm = box(L, 0.24, 0.37, bevel=0.025, segments=1)
    if half:
        # the broken end: its verts pushed about by noise (a rough break, not a saw cut)
        for v in bm.verts:
            if v.co.x > 0:
                v.co.x += 0.05 * noise.n(v.co * 9) - 0.03 * abs(v.co.z) / 0.18
    for v in bm.verts:
        v.co += Vector((0.008 * noise.n(v.co * 7), 0.006 * noise.n(v.co * 5 + Vector((3, 0, 0))), 0.0))
    return bm


def _rubble(ctx, two):
    rng, noise = ctx.rng, ctx.noise
    ctx.budget = 7800
    ctx.smooth_angle = 40
    if two:
        crests = ((-0.9, 0.1, 1.0), (1.0, -0.15, 0.82))
        mound, height = _mound(noise, RP_R * 0.82, RP_H, stretch=(1.0, 0.85), crests=crests)
    else:
        # an off-centre main tip and a lower shoulder, a little longer than wide
        crests = ((-0.5, 0.2, 1.0), (0.9, -0.3, 0.6))
        mound, height = _mound(noise, RP_R * 0.82, RP_H, stretch=(1.0, 0.82), crests=crests)
    ctx.add("Concrete", mound)
    reach = RP_R * (1.25 if two else 1.0)

    def slope_at(x, z):
        e = 0.15
        gx = (height(x + e, z) - height(x - e, z)) / (2 * e)
        gz = (height(x, z + e) - height(x, z - e)) / (2 * e)
        return gx, gz

    def on_slope(x, z, sink, spin, extra_tilt=10.0):
        """A matrix putting an object on the mound at (x, z): tilted with the slope, `sink`
        studs into it, spun by `spin` degrees."""
        gx, gz = slope_at(x, z)
        rx = math.degrees(math.atan(gz)) + rng.uniform(-extra_tilt, extra_tilt)
        rz = -math.degrees(math.atan(gx)) + rng.uniform(-extra_tilt, extra_tilt)
        return T(x, max(height(x, z), 0.0) - sink, z) @ R(rx, 0, rz) @ R(0, spin, 0)

    def spot(rmin, rmax):
        a = rng.uniform(0, 2 * math.pi)
        r = reach * rng.uniform(rmin, rmax)
        return math.cos(a) * r, math.sin(a) * r * (0.85 if two else 1.0)

    # concrete fragments: a few big ones in the slopes, many small ones all over it (a rubble
    # heap is mostly lumps), the smallest rolled down to the foot
    for k in range(26 if two else 22):
        big = k < 4
        sz = rng.uniform(0.55, 0.85) if big else rng.uniform(0.18, 0.42)
        # (two of the big ones rolled to the foot: they break the outline)
        x, z = (spot(0.05, 0.6) if k < 2 else spot(0.85, 1.05)) if big else spot(0.0, 1.05)
        bm, _ = _fragment(rng, noise, (sz, sz * rng.uniform(0.45, 0.7), sz * rng.uniform(0.6, 0.9)), 5,
                          cast=(1,), rough=0.03, edge=0.24 if big else 0.4)
        ctx.add("Concrete", bm, on_slope(x, z, sz * 0.15, rng.uniform(0, 360), 30))
    if two:
        # a slab piece leaning on the heap
        bm, _ = _fragment(rng, noise, (1.5, 0.3, 1.0), 6, cast=(1, -1), rough=0.05, edge=0.25)
        x = 0.1
        ctx.add("Concrete", bm, T(x, height(x, 0.9) * 0.6 + 0.25, 1.15) @ R(-28, rng.uniform(-15, 15), 4))
    # bricks, whole and broken
    for k in range(12 if two else 9):
        x, z = spot(0.05, 1.0)
        ctx.add("Brick", _brick(rng, noise, half=rng.random() < 0.45), on_slope(x, z, 0.03, rng.uniform(0, 360), 30))
    # rebar bent in curves out of the top: a long one arching over, a short kinked stub
    for k, (rise, run) in enumerate(((1.0, 1.6), (0.55, 0.5))):
        a = rng.uniform(0, 2 * math.pi)
        x0, z0 = math.cos(a) * (0.3 + 0.4 * k), math.sin(a) * (0.3 + 0.4 * k)
        y0 = height(x0, z0) - 0.25
        d = Vector((math.cos(a + 1.2), 0, math.sin(a + 1.2)))
        pts = []
        for i in range(7):
            t = i / 6
            p = Vector((x0, y0, z0)) + Vector((0, 1, 0)) * math.sin(t * 2.0) * rise + d * (t ** 1.7) * run
            pts.append(tuple(p))
        ctx.add("Rust", _rebar(pts, rng, r=0.045, segs=6, pitch=0.07))
    # a broken plank slid down one side
    a = rng.uniform(0, 2 * math.pi)
    x, z = math.cos(a) * reach * 0.55, math.sin(a) * reach * 0.55
    plank = box(2.4, 0.13, 0.5, bevel=0.025, segments=1)
    bmesh.ops.subdivide_edges(plank, edges=[e for e in plank.edges if abs(e.verts[0].co.x - e.verts[1].co.x) > 1],
                              cuts=4, use_grid_fill=True)
    for v in plank.verts:
        if v.co.x > 0.9:  # the snapped end: splinters
            v.co.x += 0.25 * max(0.0, noise.n((0.0, v.co.y * 9, v.co.z * 9))) - 0.1
    gx, gz = slope_at(x, z)
    ctx.add("WoodDark", plank, T(x, max(height(x, z), 0) + 0.02, z) @ R(0, -math.degrees(a) + rng.uniform(-25, 25), 0)
            @ R(0, 0, -math.degrees(math.atan(math.hypot(gx, gz))) * 0.9))

    def concrete(p):
        x, y, z = p.co
        k = 0.7 + 0.22 * smoothstep(-0.5, 0.5, noise.fbm((x * 2.5, y * 2.5, z * 2.5), 3))
        k += 0.08 * noise.n((x * 11, y * 11, z * 11))  # gravel
        k *= 1 - 0.45 * smoothstep(0.0, 0.4, -p.convex)  # gaps between stones
        # brownish fines and damp low down; pale dust higher up
        damp = 1 - smoothstep(0.0, 0.3, y)
        return (k * (1 - 0.18 * damp), k * (1 - 0.22 * damp) * 0.97, k * (1 - 0.26 * damp) * 0.92)

    def brick(p):
        x, y, z = p.co
        k = 0.8 + 0.2 * smoothstep(-0.4, 0.5, noise.fbm((x * 4, y * 4, z * 4), 2))
        return k * (1 - 0.3 * smoothstep(0.0, 0.4, -p.convex)) * (1 - 0.2 * (1 - smoothstep(0.0, 0.3, y)))

    ctx.wear("Concrete", concrete)
    ctx.wear("Brick", brick)
    ctx.wear("Rust", lambda p: 0.7 + 0.3 * smoothstep(-0.3, 0.6, noise.fbm(p.co * 8, 2)))
    ctx.wear("WoodDark", lambda p: (0.8 + 0.2 * noise.n(p.co * 4)) * (1 - 0.3 * smoothstep(0.0, 0.5, -p.convex)))


def rubble_pile1(ctx):
    """Demolition rubble heap (5.2 across, 1 tall): a gritty mound with a soft crest, concrete
    fragments and bricks half buried in it, bent rebar out of the top, a broken plank."""
    _rubble(ctx, two=False)


def rubble_pile2(ctx):
    """A longer rubble heap with two crests, a slab piece leaning on it and more brick."""
    _rubble(ctx, two=True)


# ----------------------------------------------------------------------------------------------
# PaperBall / PaperBall2. A sheet of paper crushed in a fist: ~8-9 cm across = 0.3 studs (the
# props_ground.paper_ball footprint 0.25-0.36: the data scales it with Scale = size / 0.3).
# Real reference (crumpled office paper / newspaper): a lumpy, faceted ball, flat facets meeting
# at sharp creases (paper folds, it does not dent), a few corners of the sheet sticking out of
# it, a flattened side where it rests. PaperBall: white office paper, clean-ish. PaperBall2: a
# newspaper page, greyer with print, trodden flatter, its underside wet and dirty.
# ----------------------------------------------------------------------------------------------
def _paper_ball(ctx, flat, news):
    rng, noise = ctx.rng, ctx.noise
    ctx.budget = 700
    ctx.smooth_angle = 18  # (sharp folds between flat facets)
    r0 = 0.15
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=r0)  # (320 faces)
    # crumpling: a few random fold planes clip the ball into facets (the sheet folded flat
    # there), then every vertex is pushed in or out a little (the creases between facets)
    planes = []
    for _ in range(14):
        n = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
        planes.append((n, r0 * rng.uniform(0.72, 0.92)))
    for v in bm.verts:
        d = v.co.normalized()
        r = r0
        for n, h in planes:
            c = d.dot(n)
            if c > 0.2:
                r = min(r, h / c)
        r *= 1 + rng.uniform(-0.1, 0.08) + 0.08 * noise.n(d * 3)
        v.co = d * r
    # sheet corners sticking out of the ball: thin folded triangles, their base buried in it
    for _ in range(3 if not flat else 2):
        n = Vector((rng.gauss(0, 1), abs(rng.gauss(0, 0.6)) + 0.2, rng.gauss(0, 1))).normalized()
        t = n.cross(Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((1, 0, 0))).normalized()
        # (a short wide corner leaning over, not a horn)
        base = n * r0 * 0.6
        tip = n * r0 * rng.uniform(1.1, 1.22) + t * rng.uniform(-0.05, 0.05) + n.cross(t) * rng.uniform(-0.04, 0.04)
        w = t * rng.uniform(0.065, 0.085)
        th = n.cross(t).normalized() * 0.008
        tri0 = [base - w - th, base + w - th, tip - th]
        tri1 = [base - w + th, base + w + th, tip + th]
        flap = loft([[tuple(p) for p in tri0], [tuple(p) for p in tri1]], cap_start=True, cap_end=True)
        me = bpy.data.meshes.new("_flap")
        flap.to_mesh(me)
        flap.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    squash = 0.62 if flat else 0.88
    for v in bm.verts:
        v.co.y *= squash
    low = min(v.co.y for v in bm.verts)
    for v in bm.verts:
        v.co.y -= low + 0.006
        if v.co.y < 0.012:  # (the side it rests on: pressed flat, a hair into the floor)
            v.co.y = -0.006 + 0.018 * (v.co.y + 0.006) / 0.018
    ctx.add("Paper", bm)

    def paper(p):
        x, y, z = p.co
        k = 0.92 + 0.08 * noise.n((x * 20, y * 20, z * 20))
        k *= 1 - 0.35 * smoothstep(0.0, 0.5, -p.convex)  # shadowed folds
        k *= 1 - (0.35 if news else 0.2) * (1 - smoothstep(0.0, 0.07, y))  # dirty / wet underside
        if news:
            # newsprint: grey paper, columns of print in blotches
            ink = smoothstep(0.1, 0.5, noise.fbm((x * 30, y * 30, z * 30), 2))
            k *= 0.82 * (1 - 0.35 * ink)
            return (k * 0.97, k * 0.96, k * 0.9)
        return k

    ctx.wear("Paper", paper)


def paper_ball(ctx):
    """A crumpled ball of white paper, 0.3 across: faceted folds, sheet corners sticking out."""
    _paper_ball(ctx, flat=False, news=False)


def paper_ball2(ctx):
    """A crumpled newspaper page, trodden flatter (0.32 x 0.2), grey print, wet underside."""
    _paper_ball(ctx, flat=True, news=True)


PIECES = {
    "TrafficCone": traffic_cone,
    "TrafficConeWorn": traffic_cone_worn,
    "Tyre": tyre,
    "TyreBald": tyre_bald,
    "OilDrum": oil_drum,
    "OilDrumBurn": oil_drum_burn,
    "ConcreteChunk1": concrete_chunk1,
    "ConcreteChunk2": concrete_chunk2,
    "RubblePile1": rubble_pile1,
    "RubblePile2": rubble_pile2,
    "PaperBall": paper_ball,
    "PaperBall2": paper_ball2,
}
