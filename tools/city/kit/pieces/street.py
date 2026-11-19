"""Street furniture of the city prop kit: road cones (more pieces of the family go here).

Each build function gets a kitlib.Piece (`ctx`) and models its piece in Roblox axes (Y up, the
front faces -Z, studs), the origin at the centre of the footprint on the floor.
"""

import math

from kitlib import lathe, loft, lerp, smoothstep, VertexInfo  # noqa: F401  (VertexInfo: docs)

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


PIECES = {"TrafficCone": traffic_cone, "TrafficConeWorn": traffic_cone_worn}
