"""Bins and crates of the city prop kit: the 240 L wheelie bin (body + its hinged lid), the
1100 L galvanised communal recycling bin (body + two lids: plain, and with the paper slot), the
front-load steel dumpster (body + its hinged HDPE lid, two lid variants), the moulded milk
crate (whole and broken) and the stackable Euro produce crate.

Each build function gets a kitlib.Piece (`ctx`) and models its piece in Roblox axes (Y up, the
front faces -Z, studs), the origin at the centre of the footprint on the floor. The LIDS are
separate pieces whose pivot is ON THE HINGE AXIS (the axis runs along X; closed, the lid lies
along -Z from it; a positive rotation about X opens it), so the data can open, prop or throw
back a lid with one rx: see HINGES for where each lid's pivot sits in its body's frame.

How these shells are made (why no boxes are stacked here): moulded and pressed containers are
one continuous skin, so the bodies are LOFTED rounded rectangles (rr_ring: a rounded-rectangle
ring whose points can be pushed in or out per point: recessed panels, ribs, dents, a sloped top
edge), going up the outside, over the rim and down the inside to the floor: one closed hollow
shell, real wall thickness, nothing inside anything. The crates' lattice walls are real
see-through panels (holey_panel: a grid with the holes left out, solidified), joined by round
corner posts and a moulded rim. Thin parts that must touch a shell (ribs, lugs, hubs) cross its
surface mid-face; no face of one layer lies on another's plane.
"""

import math

import bmesh
from mathutils import Matrix, Vector

from kitlib import T, R, box, cyl, lathe, loft, lerp, smoothstep, tube, merge  # noqa: F401

# Where each lid's pivot (its hinge axis) sits in its body's frame, closed lid = rx 0. The data
# places the lid piece at body CFrame * CFrame.new(HINGES[lid]) * CFrame.Angles(rad(open), 0, 0).
HINGES = {
    "WheelieBinLid": (0.0, 3.18, 1.18),
    "RecyclingBinLid": (0.0, 3.84, 1.92),
    "RecyclingBinLidPaper": (0.0, 3.84, 1.92),
    # the dumpster has two lids side by side: x = -1.5 and +1.5
    "DumpsterLid": (1.6, 4.47, 1.72),
    "DumpsterLidWarped": (-1.6, 4.47, 1.72),
}


# ----------------------------------------------------------------------------------------------
# Shape helpers (local to this family)
# ----------------------------------------------------------------------------------------------
def rr_ring(hw, hd, r, y, cz=0.0, cn=3, xs=(), zs=(), fn=None):
    """A rounded-rectangle ring (half width hw along X, half depth hd along Z, corner radius r)
    at height y, centred on (0, cz). Goes round: right side (+X), back corner, back (+Z), ...,
    front (-Z), front-right corner. xs / zs: extra points on the straight sides, as fractions
    -1..1 of the straight part (where a panel edge, a rib or a colour gradient needs a vertex);
    the same lists on every ring of a loft keep the point count equal. fn(x, y, z, nx, nz,
    side) -> offset along the outward normal, or (offset, dy): recesses, ribs, dents, a sloped
    top edge. side is "R", "B", "L", "F" or "C" (corner)."""
    r = min(r, hw * 0.95, hd * 0.95)
    ax, az = hw - r, hd - r
    pts = []

    def put(x, z, nx, nz, side):
        o, dy = 0.0, 0.0
        if fn is not None:
            res = fn(x, y, z + cz, nx, nz, side)
            o, dy = res if isinstance(res, tuple) else (res, 0.0)
        pts.append((x + nx * o, y + dy, z + cz + nz * o))

    def arc(cx, cz2, a0):
        for k in range(cn + 1):
            a = math.radians(a0 + 90.0 * k / cn)
            put(cx + r * math.cos(a), cz2 + r * math.sin(a), math.cos(a), math.sin(a), "C")

    for f in sorted(zs):
        put(hw, f * az, 1.0, 0.0, "R")
    arc(ax, az, 0)
    for f in sorted(xs, reverse=True):
        put(f * ax, hd, 0.0, 1.0, "B")
    arc(-ax, az, 90)
    for f in sorted(zs, reverse=True):
        put(-hw, f * az, -1.0, 0.0, "L")
    arc(-ax, -az, 180)
    for f in sorted(xs):
        put(f * ax, -hd, 0.0, -1.0, "F")
    arc(ax, -az, 270)
    return pts


def ring_tube(outer, inner):
    """A closed annular solid between two rings of rings: outer = [ring bottom, ..., ring top]
    and inner the same heights inside (equal point counts): up the outside, down the inside."""
    return loft(list(outer) + list(reversed(inner)), closed_profile=True)


def rect_ring(x0, x1, y0, y1, z):
    """The 4 corners of an axis rectangle in the plane z (for lofting square tubes along Z)."""
    return [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]


def holey_panel(w, h, t, holes, round_holes=0.0):
    """A flat panel w (X) x h (Y), t thick (Z, centred), with rectangular see-through holes
    [(x0, x1, y0, y1), ...] in panel coordinates (0..w, 0..h). Built as a grid on every hole
    edge with the hole cells left out, then solidified: one closed solid whose holes have real
    walls (light passes through, the bars have depth). round_holes > 0 pulls each hole's corner
    vertices in diagonally (a softer, moulded look)."""
    us = sorted({0.0, w} | {round(c, 5) for hl in holes for c in hl[:2]})
    vs = sorted({0.0, h} | {round(c, 5) for hl in holes for c in hl[2:]})
    bm = bmesh.new()
    grid = [[bm.verts.new((u - w / 2, v, -t / 2)) for v in vs] for u in us]

    def in_hole(u0, u1, v0, v1):
        cu, cv = (u0 + u1) / 2, (v0 + v1) / 2
        return any(a < cu < b and c < cv < d for a, b, c, d in holes)

    for i in range(len(us) - 1):
        for j in range(len(vs) - 1):
            if not in_hole(us[i], us[i + 1], vs[j], vs[j + 1]):
                bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
    if round_holes > 0:
        for a, b, c, d in holes:
            for u, v, su, sv in ((a, c, 1, 1), (b, c, -1, 1), (b, d, -1, -1), (a, d, 1, -1)):
                i, j = us.index(round(u, 5)), vs.index(round(v, 5))
                vert = grid[i][j]
                # only a corner that belongs to this hole alone (not shared by a neighbour hole)
                if len(vert.link_faces) == 3:
                    vert.co.x += su * round_holes
                    vert.co.y += sv * round_holes
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    # merge the flat grid cells into a few n-gons (the panel is flat: far fewer triangles once
    # triangulated; the holes' corners stay, so the bars keep their shape)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1.0), verts=bm.verts[:], edges=bm.edges[:])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=t)
    zs = [v.co.z for v in bm.verts]
    shift = -(min(zs) + max(zs)) / 2  # (solidify grows along the normal: centre it again)
    for v in bm.verts:
        v.co.z += shift
    return bm


def rbox(sx, sy, sz, bevel=0.03, segments=2):
    """A bevelled box (the template's box), here only to keep call sites short."""
    return box(sx, sy, sz, bevel=bevel, segments=segments)


def wheel_tyre(r_out, r_in, width, segs=28):
    """A solid rubber wheel tyre round X (centred): rounded shoulders, a centre groove."""
    hw = width / 2
    prof = [
        (r_in, -hw * 0.8),
        (r_out - 0.04, -hw),
        (r_out - 0.01, -hw * 0.75),
        (r_out, -hw * 0.35),
        (r_out - 0.012, -hw * 0.12),
        (r_out - 0.012, hw * 0.12),
        (r_out, hw * 0.35),
        (r_out - 0.01, hw * 0.75),
        (r_out - 0.04, hw),
        (r_in, hw * 0.8),
    ]
    return lathe(prof, segs)


def wheel_hub(r, width, segs=20, dish=0.02):
    """A moulded wheel centre round Y (rotate it onto X): a rim lip, a dished face, a boss."""
    hw = width / 2
    prof = [
        (0.0, -hw - 0.01),
        (r * 0.35, -hw - 0.01),
        (r * 0.45, -hw + dish),
        (r * 0.92, -hw + dish),
        (r, -hw + 0.01),
        (r, hw - 0.01),
        (r * 0.92, hw - dish),
        (r * 0.45, hw - dish),
        (r * 0.35, hw + 0.01),
        (0.0, hw + 0.01),
    ]
    return lathe(prof, segs)


def plane_frame(origin, u, v):
    """A matrix from a wall's plane coordinates (u, v, w) to piece space: u and v run along
    the wall, w = u x v must point OUT of it."""
    u, v, o = Vector(u).normalized(), Vector(v).normalized(), Vector(origin)
    w = u.cross(v)
    return Matrix(((u.x, v.x, w.x, o.x), (u.y, v.y, w.y, o.y), (u.z, v.z, w.z, o.z), (0, 0, 0, 1)))


def rust_blob(frame, cu, cv, radius, noise, key, vmin=None, run=1.6, n=16, lift=0.012, sink=0.01):
    """A patch of rust that has eaten through the paint, on a flat wall given by `frame`
    (plane_frame): a ragged outline (radius broken up by noise, drawn out downward by `run`
    where the rust has bled), cut flat at v = vmin (a bottom edge), as a thin closed scab whose
    face stands `lift` proud of the paint and whose back sinks `sink` into the wall (two visible
    surfaces 1.2 cm apart: no z-fight)."""
    outline = []
    for k in range(n):
        a = 2 * math.pi * k / n
        f = noise.fbm((math.cos(a) * 1.7 + key * 3.1, math.sin(a) * 1.7, key * 1.3), 3) * 0.5 + 0.5
        rr = radius * (0.45 + 0.75 * f)
        du, dv = math.cos(a) * rr, math.sin(a) * rr
        if dv < 0:
            dv *= run
        v = cv + dv
        if vmin is not None:
            v = max(v, vmin)
        outline.append((cu + du, v))
    rings = [[tuple(frame @ Vector((u, v, w))) for u, v in outline] for w in (lift, -sink)]
    return loft(rings, cap_start=True, cap_end=True)


def bump(x, y, cx, cy, rx, ry):
    """A smooth bump 1 at (cx, cy) falling to 0 at the ellipse (rx, ry) (dents, pockets)."""
    d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
    return 0.0 if d >= 1 else (1 - d) ** 2


# ----------------------------------------------------------------------------------------------
# WheelieBin + WheelieBinLid: the 240 L two-wheeled bin (EN 840). Real: 58 W x 74 D x 107 H cm.
# At the city's prop scale (props drawn ~15 % large) it keeps props_objects.wheelie_bin's
# footprint: 1.96 wide, 2.5 deep (handle and wheels at the back, +Z), the rim at 3.2, the closed
# lid's top at 3.36. Recognised by: the body tapering in toward the floor (wider at the top),
# a stacking shoulder 3/4 up, recessed side panels, the front "comb" lifting ledge under the
# lid's lip, the axle housing at the bottom back with two big wheels outboard on a steel axle,
# the handle bar and the hinge lugs at the back top, front feet; the lid: a flat top with a
# raised panel, a skirt round three sides, a deep front lip with a finger grip, knuckles round
# the hinge rod.
# ----------------------------------------------------------------------------------------------
WB_TOP = 3.2  # rim top
WB_STEP = 2.55  # the stacking shoulder
WB_WALL = 0.05
WB_HINGE = Vector(HINGES["WheelieBinLid"])
WB_LUGS = (-0.75, 0.0, 0.75)


def _wb_dims(y):
    """(half width, front z, back z) of the body's outside at height y, before its panels."""
    t = max(0.0, min(1.0, y / 3.0))
    s = 0.035 * smoothstep(WB_STEP - 0.04, WB_STEP + 0.04, y)  # the shoulder step
    hw = lerp(0.72, 0.84, t) + s
    zf = -lerp(0.92, 1.04, t) - s
    zb = lerp(0.84, 0.98, t) + s
    return hw, zf, zb


def _wb_ring(y, off=0.0, fn=None, r=None):
    hw, zf, zb = _wb_dims(y)
    rr = r if r is not None else lerp(0.17, 0.22, y / 3.2)
    return rr_ring(hw + off, (zb - zf) / 2 + off, rr + off, y, cz=(zb + zf) / 2, cn=4,
                   xs=WB_XS, zs=WB_ZS, fn=fn)


WB_XS = (-0.62, -0.55, -0.2, 0.2, 0.55, 0.62)
WB_ZS = (-0.66, -0.58, -0.25, 0.1, 0.45, 0.58, 0.66)


def _wb_panels(dent):
    """The recessed side panels (0.025 deep between the 0.58 marks, from y 0.6 to 2.35) and the
    front label recess; `dent` adds a kick dent low on the front."""

    def fn(x, y, z, nx, nz, side):
        o = 0.0
        hw, zf, zb = _wb_dims(y)
        cz, hd = (zb + zf) / 2, (zb - zf) / 2
        if side in ("R", "L"):
            u = (z - cz) / max(hd - 0.2, 1e-3)
            inside_u = 1 - smoothstep(0.58, 0.66, abs(u))
            inside_v = smoothstep(0.55, 0.62, y) * (1 - smoothstep(2.32, 2.4, y))
            o -= 0.04 * inside_u * inside_v
        if side == "F":
            u = x / max(hw - 0.2, 1e-3)
            o -= 0.02 * (1 - smoothstep(0.55, 0.62, abs(u))) * smoothstep(1.35, 1.42, y) * (1 - smoothstep(2.12, 2.2, y))
        if dent and side in ("F", "C") and nz < -0.3:
            o -= 0.09 * bump(x, y, 0.3, 0.95, 0.42, 0.38)
        return o

    return fn


def _wheelie_bin(ctx, worn):
    ctx.budget = 5400
    ctx.smooth_angle = 38
    ctx.tint("Plastic", (54, 88, 58))  # municipal green HDPE, dulled (the data picks grey/black/blue/brown)
    fn = _wb_panels(worn)
    # the shell: up the outside, the shoulder, the rim lip, over the top, down the inside
    ys = [0.16, 0.3, 0.55, 0.62, 0.9, 1.35, 1.42, 1.8, 2.12, 2.2, 2.35, 2.42, WB_STEP - 0.04,
          WB_STEP + 0.04, 2.8, 2.98]
    rings = [_wb_ring(0.1, -0.06)]  # the rounded bottom edge
    rings += [_wb_ring(y, 0.0, fn) for y in ys]
    rings += [_wb_ring(3.02, 0.05), _wb_ring(3.16, 0.05), _wb_ring(WB_TOP, 0.02),
              _wb_ring(WB_TOP, -WB_WALL - 0.005), _wb_ring(3.1, -WB_WALL)]
    rings += [_wb_ring(y, -WB_WALL) for y in (WB_STEP + 0.04, WB_STEP - 0.04, 1.2, 0.22)]
    shell = loft(rings, cap_start=True, cap_end=True)
    if worn:  # the lid never closed again: the rim pushed out of true at the front right
        for v in shell.verts:
            v.co.x += 0.03 * bump(v.co.x, v.co.y, 0.8, 3.0, 0.7, 0.6) * (1 if v.co.x > 0 else 0)
    ctx.add("Plastic", shell)
    # the axle housing (bottom back) and the front feet, both crossing the shell mid-face
    ctx.add("Plastic", rbox(1.36, 0.56, 0.44, 0.07, 3), T(0, 0.42, 0.86))
    for x in (-0.42, 0.42):
        ctx.add("Plastic", rbox(0.32, 0.2, 0.3, 0.05, 2), T(x, 0.1, -0.72))
    # the front comb: a thick lifting ledge under the lid's lip, four gussets under it
    ctx.add("Plastic", rbox(1.3, 0.16, 0.2, 0.04, 2), T(0, 2.86, -1.12))
    for x in (-0.55, -0.18, 0.18, 0.55):
        ctx.add("Plastic", rbox(0.05, 0.28, 0.13, 0.015, 1), T(x, 2.68, -1.08))
    # the hinge lugs and the handle bar at the back top, the hinge rod through the lugs
    for x in WB_LUGS:
        ctx.add("Plastic", rbox(0.16, 0.3, 0.34, 0.045, 2), T(x, 3.05, 1.15))
    ctx.add("Plastic", tube([(-0.83, 3.0, 1.29), (0.83, 3.0, 1.29)], 0.058, segs=12))
    ctx.add("Metal", cyl(0.024, 1.66, 8), T(*WB_HINGE) @ R(0, 0, 90))
    # the axle, the wheels outboard of the body, the hubs and push-on caps
    axle_y, axle_z, wx = 0.36, 0.94, 0.88
    ctx.add("Metal", cyl(0.035, 2.0, 10), T(0, axle_y, axle_z) @ R(0, 0, 90))
    for s in (-1, 1):
        m = T(s * wx, axle_y, axle_z) @ R(0, 0, -90 * s)
        ctx.add("Rubber", wheel_tyre(0.36, 0.2, 0.17, 24), m)
        ctx.add("PlasticDark", wheel_hub(0.215, 0.15, 16), m)
        ctx.add("Metal", cyl(0.05, 0.05, 10), T(s * (wx + 0.09), axle_y, axle_z) @ R(0, 0, 90))

    noise = ctx.noise

    def plastic(p):
        x, y, z = p.co
        hw, zf, zb = _wb_dims(y)
        k = 0.9
        inside = abs(x) < hw - 0.03 and zf + 0.03 < z < zb - 0.03 and 0.15 < y < WB_TOP - 0.02
        if inside:  # the dark, filthy inside
            return 0.42 + 0.25 * smoothstep(0.2, 3.1, y)
        k *= 1 - 0.45 * (1 - smoothstep(0.0, 1.1 + 0.4 * noise.fbm(p.co, 2, 2.0), y))  # dirt from the floor
        k *= 1 - 0.3 * smoothstep(0.0, 0.5, -p.convex)  # grime in the panel edges and under the comb
        k *= 1 - 0.25 * smoothstep(0.55, 0.8, noise.fbm((x * 3, y * 0.4, z * 3), 2)) * (1 - smoothstep(2.6, 3.1, y))
        if worn and z < zf + 0.2:  # the kick dent scuffed grey-black
            k *= 1 - 0.3 * smoothstep(0.05, 0.6, bump(x, y, 0.3, 0.95, 0.5, 0.45))
        if z < zf + 0.15 and y < 1.6:  # boot and kerb scuffs low on the front
            k *= 1 - 0.3 * smoothstep(0.6, 0.85, noise.fbm(p.co, 3, 6.0) * 0.5 + 0.5)
        if 2.8 < y < 3.25:  # sticky grime on the rim and the comb where hands go
            k *= 1 - 0.18 * smoothstep(0.4, 0.7, noise.fbm(p.co, 2, 5.0) * 0.5 + 0.5)
        return k

    def rubber(p):
        return 0.8 + 0.2 * smoothstep(0.0, 0.5, p.co.y) - 0.15 * smoothstep(0.2, 0.6, noise.fbm(p.co, 2, 6.0))

    ctx.wear("Plastic", plastic)
    ctx.wear("Rubber", rubber)
    ctx.wear("PlasticDark", lambda p: 0.75 + 0.25 * smoothstep(0.0, 0.6, p.co.y))
    ctx.wear("Metal", lambda p: 0.6 - 0.15 * smoothstep(0.3, 0.7, noise.fbm(p.co, 2, 8.0) * 0.5 + 0.5))


def wheelie_bin(ctx):
    """240 L wheelie bin body (EN 840): tapered moulded HDPE shell with a stacking shoulder,
    recessed side panels, front lifting comb, axle housing, two wheels on a steel axle, handle
    bar and hinge lugs. Lid = WheelieBinLid on its hinge (0, 3.18, 1.18). Plastic is tintable."""
    _wheelie_bin(ctx, False)


def wheelie_bin_worn(ctx):
    """The same 240 L bin knocked about: a kick dent low on the front, the rim pushed out of
    true, filthier. Lid = WheelieBinLid."""
    _wheelie_bin(ctx, True)


def wheelie_bin_lid(ctx):
    """The 240 L bin's lid, pivot ON its hinge axis (closed = lying along -Z; rotate about X to
    open: ~15-25 ajar on a full bag, 100-118 thrown back). Flat top with a raised moulded panel
    and lettering bars, skirt on three sides, deep front lip with a finger grip, ribs under it,
    two knuckles round the hinge rod. Plastic tintable (same colour as the body)."""
    ctx.budget = 2600
    ctx.smooth_angle = 38
    ctx.tint("Plastic", (54, 88, 58))
    # plan: from just behind the body's rim at the back to the front lip, in the lid's frame
    zb, zf = -0.08, -2.365
    cz, hd, hw, rr = (zb + zf) / 2, (zb - zf) / 2, 0.98, 0.16
    under, top = 0.06, 0.16  # (world 3.24: 4 cm over the rim; world 3.34)
    xs = (-0.8, -0.4, 0.0, 0.4, 0.8)
    zs = (-0.8, -0.4, 0.0, 0.4, 0.8)

    def skirt(x, y, z, nx, nz, side):
        # the skirt hangs 0.18 on the sides, 0.24 at the front, 0.02 at the back (hinge side)
        u = (z - cz) / hd  # -1 front .. +1 back
        drop = lerp(0.24, 0.18, smoothstep(-1.0, -0.6, u))
        drop = lerp(drop, 0.02, smoothstep(0.75, 1.0, u))
        return (0.0, -drop)

    def ring(off, y, f=None):
        return rr_ring(hw + off, hd + off, max(0.02, rr + off), y, cz=cz, cn=4, xs=xs, zs=zs, fn=f)

    rings = [
        ring(-0.42, under),  # the underside, going outward
        ring(-0.035, under),
        ring(-0.035, under, skirt),  # down the skirt's inside
        ring(0.0, under, skirt),  # its bottom edge
        ring(0.0, under + 0.06),
        ring(-0.02, top - 0.012),  # the rounded top edge
        ring(-0.07, top),
        ring(-0.24, top),
        ring(-0.26, top + 0.022),  # the raised moulded panel
        ring(-0.42, top + 0.022),
    ]
    lid = loft(rings, cap_start=True, cap_end=True)
    ctx.add("Plastic", lid)
    # finger grip on the front lip, ribs under the lid (they cross the underside mid-face)
    ctx.add("Plastic", rbox(0.7, 0.07, 0.07, 0.025, 2), T(0, under - 0.17, zf - 0.015))
    for x in (-0.5, 0.0, 0.5):
        ctx.add("Plastic", rbox(0.04, 0.09, 1.9, 0.012, 1), T(x, under - 0.035, cz))
    ctx.add("Plastic", rbox(1.7, 0.09, 0.04, 0.012, 1), T(0, under - 0.035, cz - 0.3))
    # moulded lettering on the top: short raised bars in two lines (reads as embossed text)
    rng = ctx.rng
    for line, z in enumerate((cz - 0.05, cz + 0.2)):
        x = -0.45 + line * 0.12
        while x < 0.42 - line * 0.12:
            w = rng.uniform(0.03, 0.08)
            ctx.add("Plastic", box(w, 0.024, 0.08), T(x + w / 2, top + 0.022 + 0.006, z))
            x += w + rng.uniform(0.02, 0.035) + (0.07 if rng.random() < 0.25 else 0.0)
    # the two knuckles round the hinge rod, with their webs to the lid's back edge
    for x in (-0.38, 0.38):
        ctx.add("Plastic", cyl(0.065, 0.34, 14), T(x, 0, 0) @ R(0, 0, 90))
        ctx.add("Plastic", rbox(0.3, 0.12, 0.14, 0.03, 2), T(x, 0.08, -0.07))
    noise = ctx.noise

    def plastic(p):
        x, y, z = p.co
        k = 1.0
        if p.normal.y < -0.3 or y < under - 0.01:  # the underside and the inside of the skirt
            k = 0.62 if p.normal.y < -0.3 else 0.85
        k *= 1 - 0.25 * smoothstep(0.0, 0.5, -p.convex)
        k *= 1 - 0.2 * smoothstep(0.55, 0.8, noise.fbm((x * 2, y, z * 2), 2) * 0.5 + 0.5)  # rain marks
        if z < zf + 0.25:  # grubby front lip where it is lifted
            k *= 1 - 0.25 * smoothstep(0.35, 0.7, noise.fbm(p.co, 2, 6.0) * 0.5 + 0.5)
        return k

    ctx.wear("Plastic", plastic)


# ----------------------------------------------------------------------------------------------
# RecyclingBin + RecyclingBinLid / RecyclingBinLidPaper: the 1100 L continental communal bin
# (EN 840-3), what props_objects.recycling_bin draws. Real: 137 W x 107 D x 146 H cm. Here it
# keeps the prop's footprint: 4.2 x 3.4 (4.9 with the handles and trunnions), the galvanised
# body from y 0.5 to 3.8 on four swivel castors, the domed lid's crown at ~4.5. Recognised by:
# hot-dip galvanised body, rounded corners, a slight taper, pressed horizontal stiffening beads
# and vertical beads on the long faces, a rolled top rim, DIN trunnions (lifting pins) and
# tubular push handles on both ends, a foot-pedal bar at the front, four castors; the lid: a
# coloured plastic dome curved front to back, a skirt, a front lip; the paper version has a
# raised posting slot on its front slope. Wear: dull patchy spangle, grime from the floor,
# white-rusty scratches gone orange at the bottom corners, a pale peeling recycling sticker.
# ----------------------------------------------------------------------------------------------
RB_Y0, RB_TOP = 0.5, 3.8
RB_HINGE = Vector(HINGES["RecyclingBinLid"])
RB_XS = tuple(-0.9 + 0.15 * i for i in range(13))
RB_ZS = (-0.75, -0.4, 0.0, 0.4, 0.75)
RB_BEADS = (1.45, 2.75)  # horizontal stiffening beads


def _rb_dims(y):
    t = max(0.0, min(1.0, (y - RB_Y0) / (RB_TOP - RB_Y0)))
    return lerp(1.98, 2.1, t), lerp(1.58, 1.7, t)  # half width, half depth


def _rb_beads(x, y, z, nx, nz, side):
    o = 0.0
    for yb in RB_BEADS:  # rounded beads 4 cm proud, 0.18 tall
        o += 0.045 * max(0.0, 1 - ((y - yb) / 0.1) ** 2)
    if side in ("F", "B"):  # vertical beads on the long faces, between the horizontal ones
        hw, _ = _rb_dims(y)
        for xb in (-0.9, -0.3, 0.3, 0.9):
            mask = smoothstep(1.6, 1.7, y) * (1 - smoothstep(2.55, 2.65, y))
            o += 0.035 * max(0.0, 1 - ((x - xb * (hw - 0.4)) / 0.09) ** 2) * mask
    return o


def _rb_ring(y, off=0.0, fn=None):
    hw, hd = _rb_dims(y)
    return rr_ring(hw + off, hd + off, 0.38 + off, y, cn=4, xs=RB_XS, zs=RB_ZS, fn=fn)


def recycling_bin(ctx):
    """1100 L galvanised communal bin body (EN 840-3): tapered pressed-steel shell with beads,
    rolled rim, trunnions, push handles, foot pedal, four swivel castors. Lid = RecyclingBinLid
    or RecyclingBinLidPaper on the hinge (0, 3.84, 1.92). Not tinted (the lid carries the
    colour)."""
    ctx.budget = 8000
    ctx.smooth_angle = 40
    ys = [RB_Y0 + 0.06, 0.62, 0.7, 0.78, 0.88, 1.0, 1.25, 1.35, 1.45, 1.55, 1.65, 2.0, 2.4, 2.65, 2.75, 2.85, 3.0, 3.3, 3.6]
    rings = [_rb_ring(RB_Y0, -0.06)]
    rings += [_rb_ring(y, 0.0, _rb_beads) for y in ys]
    # the rolled rim: out, round over the top, back down inside
    rings += [_rb_ring(3.68, 0.02), _rb_ring(3.72, 0.07), _rb_ring(3.78, 0.09), _rb_ring(RB_TOP, 0.06),
              _rb_ring(RB_TOP, -0.03), _rb_ring(3.72, -0.05)]
    rings += [_rb_ring(y, -0.05) for y in (3.0, 1.5, RB_Y0 + 0.08)]
    shell = loft(rings, cap_start=True, cap_end=True)
    # dents: a knock on the front left corner, a shallow push in the right end
    for v in shell.verts:
        x, y, z = v.co
        d = 0.08 * bump(x, y, -1.75, 1.0, 0.6, 0.5) * (1 if z < -1.2 else 0)
        d += 0.05 * bump(z, y, 0.6, 2.2, 0.6, 0.5) * (1 if x > 1.8 else 0)
        if d:
            v.co.z += d * (1 if z < -1.2 else 0)
            v.co.x -= d * (1 if x > 1.8 else 0)
    # rust where the zinc was scraped through: small ragged spots low on the front, bled down
    noise = ctx.noise
    tilt = Vector((0.0, RB_TOP - RB_Y0, -(_rb_dims(RB_TOP)[1] - _rb_dims(RB_Y0)[1])))
    front = plane_frame((0, RB_Y0, -_rb_dims(RB_Y0)[1]), (-1, 0, 0), tilt)
    for k, (u, v, r) in enumerate(((1.3, 0.12, 0.2), (-1.25, 0.1, 0.14), (0.35, 0.3, 0.07), (1.05, 0.62, 0.06))):
        ctx.add("Rust", rust_blob(front, u, v, r, noise, k, vmin=0.07, run=1.3))
    ctx.add("Metal", shell)
    # trunnions (DIN lifting pins) and push handles on both ends, the hinge brackets at the back
    for s in (-1, 1):
        hw, _ = _rb_dims(3.3)
        m = T(s * (hw + 0.02), 3.3, 0.0) @ R(0, 0, -90 * s)
        ctx.add("Metal", lathe([(0.0, -0.05), (0.2, -0.05), (0.22, 0.0), (0.2, 0.05), (0.11, 0.06), (0.1, 0.3),
                                (0.13, 0.32), (0.14, 0.38), (0.12, 0.42), (0.0, 0.42)], 16), m)
        hx = hw - 0.02
        pts = [(s * hx, 2.85, -0.95), (s * (hx + 0.2), 2.85, -0.9), (s * (hx + 0.27), 2.85, -0.78),
               (s * (hx + 0.27), 2.85, -0.45)]
        ctx.add("Metal", tube(pts, 0.055, 10))
        ctx.add("Metal", tube([(p[0], p[1], -p[2]) for p in pts], 0.055, 10))
        ctx.add("Black", tube([(s * (hx + 0.27), 2.85, -0.52), (s * (hx + 0.27), 2.85, 0.52)], 0.075, 12))
    for x in (-1.5, -0.5, 0.5, 1.5):
        ctx.add("Metal", rbox(0.1, 0.23, 0.2, 0.025, 1), T(x * 1.05, 3.775, 1.88))
    ctx.add("Metal", cyl(0.035, 3.4, 10), T(*RB_HINGE) @ R(0, 0, 90))
    # the foot pedal: a bar across the front on two arms pivoting on the ends
    hw0, hd0 = _rb_dims(0.8)
    for s in (-1, 1):
        ctx.add("Metal", rbox(0.06, 0.16, 0.16, 0.02, 1), T(s * (hw0 + 0.02), 0.85, -0.6))
    ctx.add("Metal", tube([(-(hw0 + 0.06), 0.85, -0.6), (-(hw0 + 0.06), 0.72, -hd0 - 0.32),
                           (-(hw0 - 0.1), 0.7, -hd0 - 0.4), (hw0 - 0.1, 0.7, -hd0 - 0.4),
                           (hw0 + 0.06, 0.72, -hd0 - 0.32), (hw0 + 0.06, 0.85, -0.6)], 0.045, 10))
    ctx.add("Rubber", tube([(-0.7, 0.7, -hd0 - 0.4), (0.7, 0.7, -hd0 - 0.4)], 0.07, 10))
    # four swivel castors: plate, kingpin, fork, wheel (two with brake pedals)
    for i, (sx, sz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        cx, cz = sx * 1.55, sz * 1.15
        ctx.add("Metal", rbox(0.42, 0.05, 0.42, 0.015, 1), T(cx, RB_Y0 - 0.01, cz))
        ctx.add("Metal", cyl(0.07, 0.08, 12), T(cx, RB_Y0 - 0.075, cz))
        spin = 25.0 * sx + 10 * i
        m = T(cx, 0.0, cz) @ R(0, spin, 0)
        for u in (-1, 1):
            ctx.add("Metal", rbox(0.025, 0.3, 0.2, 0.01, 1), m @ T(u * 0.1, 0.3, 0.05))
        ctx.add("Metal", rbox(0.25, 0.03, 0.2, 0.01, 1), m @ T(0, 0.43, 0.05))
        ctx.add("Rubber", wheel_tyre(0.2, 0.1, 0.13, 14), m @ T(0, 0.2, 0.1) @ R(0, 0, 90))
        ctx.add("Metal", wheel_hub(0.11, 0.12, 12), m @ T(0, 0.2, 0.1) @ R(0, 0, 90))
        if sz < 0:
            ctx.add("Black", rbox(0.12, 0.04, 0.16, 0.015, 1), m @ T(0, 0.36, -0.15) @ R(-20, 0, 0))
    # the recycling sticker on the front, pale and half peeled (Paper, tinted green by its wear)
    hwS, hdS = _rb_dims(2.15)
    tilt = math.degrees(math.atan2(0.12, RB_TOP - RB_Y0))
    ctx.add("Paper", rbox(1.0, 0.7, 0.02, 0.004, 1), T(-0.05, 2.15, -hdS - 0.012) @ R(-tilt, 0, 1.5))
    ctx.add("Paper", rbox(0.3, 0.22, 0.012, 0.003, 1), T(0.36, 2.42, -hdS - 0.05) @ R(-tilt + 28, 12, 6))

    def metal(p):
        x, y, z = p.co
        hw, hd = _rb_dims(y)
        if abs(x) < hw - 0.08 and abs(z) < hd - 0.08 and y < RB_TOP - 0.02 and RB_Y0 + 0.04 < y:
            return 0.4 + 0.2 * smoothstep(RB_Y0, RB_TOP, y)  # the filthy inside
        k = 0.93 + 0.07 * noise.fbm(p.co, 2, 1.5)  # patchy spangle, dull and bright zones
        k *= 1 - 0.35 * (1 - smoothstep(RB_Y0, RB_Y0 + 1.1 + 0.4 * noise.fbm(p.co, 2, 2.0), y))
        k *= 1 - 0.3 * smoothstep(0.0, 0.4, -p.convex)
        k *= 1 - 0.22 * smoothstep(0.5, 0.8, noise.fbm((x * 4, y * 0.3, z * 4), 2) * 0.5 + 0.5)  # run-off
        return (k * 0.98, k, k * 1.01)

    def paper(p):
        if p.co.x > 0.25 and p.co.y > 2.35:
            return (0.92, 0.92, 0.88)  # the peeled corner: the sticker's white back
        g = 0.9 - 0.2 * smoothstep(0.3, 0.8, noise.fbm(p.co, 2, 8.0) * 0.5 + 0.5)
        return (0.55 * g, 0.78 * g, 0.55 * g)  # faded recycling green

    ctx.wear("Metal", metal)
    ctx.wear("Paper", paper)
    ctx.wear("Rust", lambda p: 0.8 + 0.2 * noise.fbm(p.co, 2, 6.0))
    ctx.wear("Rubber", lambda p: 0.75 + 0.25 * smoothstep(0.0, 0.3, p.co.y))
    ctx.wear("Black", lambda p: 0.85)


def _rb_lid(ctx, paper):
    ctx.budget = 3600
    ctx.smooth_angle = 40
    ctx.tint("Plastic", (44, 98, 62) if paper else (92, 96, 94))  # recycling green / general grey
    # plan in the lid's frame: from just behind the hinge back to past the rim's front
    zb, zf = -0.04, -3.79
    cz, hd, hw, rr = (zb + zf) / 2, (zb - zf) / 2, 2.28, 0.42
    dome_h, th = 0.55, 0.07
    lid_y0 = 0.04  # the skirt's top / the underside at the edge (world 3.88: 8 cm over the rim)
    xs = tuple(-0.9 + 0.15 * i for i in range(13))
    zs = tuple(-0.9 + 0.15 * i for i in range(13))

    def dome(x, z):
        u = max(-1.0, min(1.0, (z - cz) / hd))
        end = 1 - 0.4 * smoothstep(hw - 0.9, hw, abs(x))
        return dome_h * (1 - u * u) * end

    def at(dy0, f=None):
        def fn(x, y, z, nx, nz, side):
            o = 0.0
            extra = 0.0
            if f is not None:
                o, extra = f(x, z, side)
            return (o, dome(x, z) + dy0 + extra)
        return fn

    def skirt(x, z, side):
        u = (z - cz) / hd
        drop = lerp(0.3, 0.2, smoothstep(-1.0, -0.7, u))
        drop = lerp(drop, 0.06, smoothstep(0.7, 1.0, u))
        return (0.0, -drop)

    def ring(off, dy, f=None):
        return rr_ring(hw + off, hd + off, max(0.05, rr + off), lid_y0, cz=cz, cn=4, xs=xs, zs=zs, fn=at(dy, f))

    rings = [ring(-1.6, 0.0), ring(-0.9, 0.0), ring(-0.4, 0.0), ring(-0.06, 0.0), ring(-0.06, 0.0, skirt),
             ring(0.0, 0.0, skirt), ring(0.0, th * 0.4), ring(-0.03, th), ring(-0.12, th), ring(-0.4, th),
             ring(-0.9, th), ring(-1.6, th)]
    lid = loft(rings, cap_start=True, cap_end=True)
    ctx.add("Plastic", lid)
    # the front lip handle, two stiffening ribs along the crown, the hinge knuckles
    ctx.add("Plastic", rbox(1.6, 0.1, 0.1, 0.035, 2), T(0, lid_y0 - 0.22, zf - 0.04))
    for x in (-1.2, 1.2):
        n = 8
        pts = [(x, lid_y0 + dome(x, zf + 0.5 + i * (hd * 2 - 1.0) / n) + th - 0.01, zf + 0.5 + i * (hd * 2 - 1.0) / n)
               for i in range(n + 1)]
        ctx.add("Plastic", tube(pts, 0.05, 8))
    for x in (-1.05, 0.0, 1.05):  # (between the body's hinge brackets at +-0.525, +-1.575)
        ctx.add("Plastic", cyl(0.075, 0.4, 14), T(x, 0, 0) @ R(0, 0, 90))
        ctx.add("Plastic", rbox(0.36, 0.1, 0.12, 0.03, 2), T(x, lid_y0 + 0.03, -0.07))
    rng = ctx.rng
    zc = cz + 0.3
    for line in range(2):  # moulded lettering on the crown
        x = -0.7 + 0.15 * line
        z = zc + line * 0.18
        while x < 0.7 - 0.15 * line:
            w = rng.uniform(0.04, 0.12)
            ctx.add("Plastic", box(w, 0.03, 0.1), T(x + w / 2, lid_y0 + dome(x, z) + th + 0.008, z))
            x += w + rng.uniform(0.03, 0.05) + (0.09 if rng.random() < 0.2 else 0.0)
    if paper:
        # the posting slot: a raised frame on the front slope, the dark slot inside it
        zs0 = cz - hd * 0.55
        slope = math.degrees(math.atan2(2 * dome_h * 0.55 / hd, 1.0))
        base = lid_y0 + dome(0, zs0) + th
        m = T(0, base, zs0) @ R(-slope, 0, 0)
        for u in (-1, 1):
            ctx.add("Plastic", rbox(1.7, 0.1, 0.07, 0.025, 2), m @ T(0, 0.03, u * 0.13))
            ctx.add("Plastic", rbox(0.07, 0.1, 0.33, 0.025, 2), m @ T(u * 0.82, 0.03, 0))
        ctx.add("Black", rbox(1.6, 0.06, 0.2, 0.01, 1), m @ T(0, 0.0, 0))
    noise = ctx.noise

    def plastic(p):
        x, y, z = p.co
        k = 1.0
        if p.normal.y < -0.3:
            k = 0.55  # the underside
        k *= 1 - 0.25 * smoothstep(0.0, 0.4, -p.convex)
        k *= 1 - 0.18 * smoothstep(0.5, 0.8, noise.fbm((x * 2, y, z * 3), 2) * 0.5 + 0.5)
        if z < zf + 0.4:
            k *= 1 - 0.22 * smoothstep(0.35, 0.7, noise.fbm(p.co, 2, 5.0) * 0.5 + 0.5)
        return k

    ctx.wear("Plastic", plastic)
    ctx.wear("Black", lambda p: 0.7)


def recycling_bin_lid(ctx):
    """Domed plastic lid of the 1100 L bin (general waste grey), pivot ON its hinge axis
    (closed = along -Z; rx 55-65 propped open). Curved front to back, rounded ends, skirt,
    front lip handle, crown ribs, embossed lettering. Plastic tintable."""
    _rb_lid(ctx, False)


def recycling_bin_lid_paper(ctx):
    """The same domed lid in recycling green with the raised paper posting slot on its front
    slope (keep it closed: the slot is how paper goes in). Plastic tintable."""
    _rb_lid(ctx, True)


# ----------------------------------------------------------------------------------------------
# Dumpster + DumpsterLid / DumpsterLidWarped: the front-load steel container (3-4 yd), what
# props_objects.dumpster draws. Real 3 yd: 198 W x 109 D x 104 front / 127 rear cm; 4 yd: 203 x
# 130 x 117 / 142. At the prop scale it keeps the prop's footprint: 6.0 long (X) plus the fork
# pockets (6.7), 3.6 deep (Z, back to the wall at +Z), the shell from y 0.55 on four casters,
# its top sloping from 3.9 at the front to 4.35 at the back. Recognised by: the slant top, the
# lower front raked back, the formed square-tube top rim, three hat-channel stiffeners on the
# front, fork pockets (open rectangular steel sleeves) along both ends with gussets, the hinge
# bar at the back, swivel casters, a drain plug, a riveted info plate; two black ribbed HDPE
# lids on the hinge bar (separate pieces). Wear: fork dents in the front, rust eating the
# bottom edges, the pocket ends and the rim corners, grease and rain streaks down the sides,
# dirt rising from the floor; paint is the tintable MetalPainted (forest green by default).
# ----------------------------------------------------------------------------------------------
DU_L, DU_W = 6.0, 3.6
DU_Y0, DU_H, DU_H2 = 0.55, 3.35, 3.8  # shell bottom, front and back heights above it
DU_RAKE = 0.9  # height of the raked lower front
DU_SET = 0.45  # how far the bottom of the front is set back
DU_XS = tuple(-0.95 + 0.1 * i for i in range(20))
DU_ZS = tuple(-0.9 + 0.2 * i for i in range(10))
DU_RIBS = (-1.95, 0.0, 1.95)
DU_HINGE = Vector((0.0, 4.47, 1.72))  # the hinge bar's axis (the lids' x: HINGES)


def _du_front(y):
    """z of the front face at height y (the raked lower front)."""
    t = max(0.0, min(1.0, (y - DU_Y0) / DU_RAKE))
    return -DU_W / 2 + DU_SET * (1 - t)


def _du_top(z):
    """Height of the top edge at z (front low, back high)."""
    return DU_Y0 + DU_H + (DU_H2 - DU_H) * (z + DU_W / 2) / DU_W


def _du_dent(x, y):
    """Fork dents pushed into the front (both skins follow, so the wall keeps its thickness)."""
    return 0.09 * bump(x, y, -1.0, 1.9, 0.55, 0.45) + 0.06 * bump(x, y, 1.15, 2.6, 0.5, 0.35) + 0.05 * bump(
        x, y, 2.55, 1.4, 0.35, 0.5)


def _du_ring(y, off, top=None):
    """A ring of the shell at height y (or ON the sloped top edge + top when top is given),
    offset `off` outward (at the back by 2 cm at most: the back goes flat against a wall, so
    the rim does not stick out there)."""
    zf = _du_front(y if top is None else DU_Y0 + DU_H) - off
    zb = DU_W / 2 + min(off, 0.02)
    cz, hd = (zf + zb) / 2, (zb - zf) / 2

    def fn(x, yy, z, nx, nz, side):
        o, dy = 0.0, 0.0
        if top is not None:
            dy = _du_top(z) + top - yy
        if nz < -0.5:
            o -= _du_dent(x, yy + dy)
        return (o, dy)

    return rr_ring(DU_L / 2 + off, hd, 0.12 + off, y, cz=cz, cn=2, xs=DU_XS, zs=DU_ZS, fn=fn)


def _hat_channel(x, y0, y1, z, w=0.36, face=0.22, depth=0.14):
    """A vertical hat-channel stiffener standing on a wall whose face is at z (it sticks out
    toward -Z), tapering to nothing at both ends."""
    rings = []
    ys = [y0, y0 + 0.12, y1 - 0.12, y1]
    for i, y in enumerate(ys):
        d = depth if 0 < i < 3 else 0.015
        rings.append([(x - w / 2, y, z + 0.03), (x - face / 2, y, z - d), (x + face / 2, y, z - d),
                      (x + w / 2, y, z + 0.03)])
    return loft(rings, cap_start=True, cap_end=True)


def dumpster(ctx):
    """Front-load steel dumpster body (3-4 yd): slant top, raked lower front, formed rim,
    hat-channel stiffeners, fork pockets, hinge bar, casters, drain plug, info plate; dents,
    rust, streaks. MetalPainted tintable. Lids = 2 x DumpsterLid / DumpsterLidWarped on the
    hinge bar (+-1.6, 4.47, 1.72)."""
    ctx.budget = 8000
    ctx.smooth_angle = 40
    ctx.tint("MetalPainted", (38, 72, 48))  # forest green enamel, dulled
    noise = ctx.noise
    ys = [DU_Y0 + 0.05, 0.68, 0.8, 0.92, 1.05, 1.25, DU_Y0 + DU_RAKE, 1.6, 1.9, 2.2, 2.5, 2.8, 3.1, 3.4]
    rings = [_du_ring(DU_Y0, -0.08)]
    rings += [_du_ring(y, 0.0) for y in ys]
    # the formed rim (a square tube round the top, following the slope), then the inside
    rings += [_du_ring(0, 0.0, top=-0.22), _du_ring(0, 0.1, top=-0.2), _du_ring(0, 0.1, top=0.0),
              _du_ring(0, -0.08, top=0.0), _du_ring(0, -0.08, top=-0.25)]
    rings += [_du_ring(y, -0.08) for y in (2.6, 1.6, DU_Y0 + 0.12)]
    shell = loft(rings, cap_start=True, cap_end=True)

    # rust eating the raked lower front along its bottom edge, the ends' low corners, a spot
    # under a front corner: ragged scabs on the flat walls, clear of the dents
    raked = plane_frame((0, DU_Y0, _du_front(DU_Y0)), (-1, 0, 0), (0, DU_RAKE, -DU_SET))
    spots = [(raked, -2.6, 0.12, 0.42), (raked, -1.7, 0.08, 0.3), (raked, -0.6, 0.1, 0.22), (raked, 0.5, 0.05, 0.3),
             (raked, 1.5, 0.12, 0.36), (raked, -2.2, 0.62, 0.12), (raked, 1.1, 0.7, 0.09)]
    for s_ in (-1, 1):
        end = plane_frame((s_ * DU_L / 2, DU_Y0, 0), (0, 0, -s_), (0, 1, 0))
        spots += [(end, -s_ * 0.6, 0.12, 0.3), (end, s_ * 0.9, 0.1, 0.38), (end, -s_ * 0.2, 0.42, 0.1)]
    spots.append((plane_frame((0, 0, -DU_W / 2), (-1, 0, 0), (0, 1, 0)), 2.6, 1.75, 0.16))
    for k, (fr, u, v, r) in enumerate(spots):
        ctx.add("Rust", rust_blob(fr, u, v, r, noise, k, vmin=0.07, run=2.2))
    ctx.add("MetalPainted", shell)
    # three hat-channel stiffeners on the vertical front
    zf = -DU_W / 2
    for x in DU_RIBS:
        ctx.add("MetalPainted", _hat_channel(x, DU_Y0 + DU_RAKE + 0.05, DU_Y0 + DU_H - 0.3, zf))
    # fork pockets on both ends: open rectangular sleeves running front to back, gussets under
    yp = 1.95
    for s in (-1, 1):
        x0, x1 = (DU_L / 2 - 0.02, DU_L / 2 + 0.36) if s > 0 else (-DU_L / 2 - 0.36, -DU_L / 2 + 0.02)
        za, zb = -DU_W / 2 + 0.15, DU_W / 2 - 0.25
        t = 0.05
        outer = [rect_ring(x0, x1, yp, yp + 0.55, z) for z in (za, zb)]
        inner = [rect_ring(x0 + t, x1 - t, yp + t, yp + 0.55 - t, z) for z in (za, zb)]
        ring_list = [outer[0], outer[1], inner[1], inner[0]]
        ctx.add("MetalPainted", loft(ring_list, closed_profile=True))
        for z in (za + 0.45, zb - 0.45):
            g = loft([[(x0, yp, z - 0.03), (x1, yp, z - 0.03), (x0, yp - 0.4, z - 0.03)],
                      [(x0, yp, z + 0.03), (x1, yp, z + 0.03), (x0, yp - 0.4, z + 0.03)]], cap_start=True, cap_end=True)
            ctx.add("MetalPainted", g, T(-0.02 * s, 0, 0))
    # the hinge bar at the back top on three brackets, the lid stops
    # (the bar rides just over the back rim, inside the footprint: the back can touch a wall)
    hy, hz = DU_HINGE.y, DU_HINGE.z
    ctx.add("Metal", cyl(0.05, DU_L + 0.2, 12), T(0, hy, hz) @ R(0, 0, 90))
    for x in (-2.95, -0.1, 0.1, 2.95):
        ctx.add("MetalPainted", rbox(0.1, 0.3, 0.12, 0.02, 1), T(x, hy - 0.135, hz))
    # casters: plate, fork, wheel
    for sx in (-1, 1):
        for sz in (-1, 1):
            cx, cz = sx * (DU_L / 2 - 0.55), sz * 1.05 + (0.2 if sz < 0 else 0)
            ctx.add("Metal", rbox(0.55, 0.06, 0.5, 0.015, 1), T(cx, DU_Y0 - 0.02, cz))
            m = T(cx, 0, cz) @ R(0, 15 * sx * sz, 0)
            for u in (-1, 1):
                ctx.add("Metal", rbox(0.035, 0.36, 0.28, 0.012, 1), m @ T(u * 0.11, 0.33, 0.04))
            ctx.add("Rubber", wheel_tyre(0.25, 0.12, 0.15, 20), m @ T(0, 0.25, 0.08) @ R(0, 0, 90))
            ctx.add("Metal", wheel_hub(0.13, 0.14, 12), m @ T(0, 0.25, 0.08) @ R(0, 0, 90))
    # the drain plug low on the raked front, the riveted info plate between two stiffeners
    rake = math.degrees(math.atan2(DU_SET, DU_RAKE))
    zd = _du_front(DU_Y0 + 0.3)
    ctx.add("Metal", cyl(0.11, 0.08, 6), T(2.2, DU_Y0 + 0.3, zd - 0.02) @ R(90 - rake, 0, 0))
    ctx.add("Metal", cyl(0.14, 0.03, 16), T(2.2, DU_Y0 + 0.3, zd - 0.005) @ R(90 - rake, 0, 0))
    px, py = 0.97, 3.05
    ctx.add("Metal", rbox(1.1, 0.6, 0.03, 0.008, 1), T(px, py, zf - 0.022) @ R(0, 0, 1.2))
    for u in (-1, 1):
        for v in (-1, 1):
            ctx.add("Metal", cyl(0.03, 0.03, 8), T(px + u * 0.48, py + v * 0.23, zf - 0.045) @ R(90, 0, 0))

    def paint(p):
        x, y, z = p.co
        inside = abs(x) < DU_L / 2 - 0.1 and _du_front(y) + 0.1 < z < DU_W / 2 - 0.1 and DU_Y0 + 0.05 < y < _du_top(z) - 0.05
        if inside:
            return 0.4 + 0.15 * smoothstep(DU_Y0, 4.0, y)
        k = 0.95
        k *= 1 - 0.45 * (1 - smoothstep(DU_Y0 - 0.2, DU_Y0 + 1.0 + 0.5 * noise.fbm(p.co, 2, 1.5), y))
        k *= 1 - 0.3 * smoothstep(0.0, 0.4, -p.convex)
        # grease and rain streaks running down from the rim
        s = smoothstep(0.35, 0.75, noise.fbm((x * 5, y * 0.25, z * 5), 2) * 0.5 + 0.5)
        k *= 1 - 0.32 * s * smoothstep(1.0, 3.2, y)
        # rust bloom (orange-brown stain) round the rust scabs and under the rim corners
        r = smoothstep(0.1, 0.5, noise.fbm(p.co, 3, 3.0)) * (1 - smoothstep(DU_Y0, DU_Y0 + 0.9, y))
        k2 = (1 - 0.1 * r, 1 - 0.3 * r, 1 - 0.45 * r)
        # pockets: the steel worn by the forks
        if abs(x) > DU_L / 2 and 1.9 < y < 2.55:
            k *= 0.8 + 0.2 * noise.fbm(p.co, 2, 6.0)
        # the fork dents scraped dark
        k *= 1 - 0.35 * smoothstep(0.02, 0.06, _du_dent(x, y)) * (1 if z < -1.5 else 0)
        return (k * k2[0], k * k2[1], k * k2[2])

    def rust(p):
        return 0.75 + 0.25 * noise.fbm(p.co, 2, 5.0)

    ctx.wear("MetalPainted", paint)
    ctx.wear("Rust", rust)
    ctx.wear("Metal", lambda p: 0.55 + 0.2 * noise.fbm(p.co, 2, 4.0))
    ctx.wear("Rubber", lambda p: 0.75 + 0.25 * smoothstep(0.0, 0.4, p.co.y))


def _du_lid(ctx, warped):
    ctx.budget = 3200
    ctx.smooth_angle = 38
    hw = 1.57  # x: 0.03 .. 3.17 from the dumpster's centre (outside the end rim)
    # length along the slope from the hinge (behind the rim) to past the front rim
    slope = math.atan2(DU_H2 - DU_H, DU_W)
    length = (DU_HINGE.z + DU_W / 2 + 0.12 + 0.06) / math.cos(slope)
    th, drop = 0.07, 0.17
    ribs = (-0.95, 0.0, 0.95)

    def section(z, front=False):
        """The lid's cross-section at z (a closed outline in x-y): skirt down both sides, the
        ribbed top skin, the hollow underside."""
        pts = []
        d = drop if z < -0.3 else lerp(drop, 0.03, smoothstep(-0.3, 0.0, z))
        pts.append((-hw, -d))
        pts.append((-hw, -0.01))
        pts.append((-hw + 0.03, th * 0.8))
        xs = [-hw + 0.09]
        for rx in ribs:
            xs += [rx - 0.26, rx - 0.17, rx - 0.1, rx + 0.1, rx + 0.17, rx + 0.26]
        xs += [hw - 0.09]
        for x in xs:
            up = 0.0
            for rx in ribs:
                up = max(up, 0.09 * smoothstep(0.26, 0.13, abs(x - rx)))
            pts.append((x, th + up))
        pts.append((hw - 0.03, th * 0.8))
        pts.append((hw, -0.01))
        pts.append((hw, -d))
        pts.append((hw - 0.05, -d))
        pts.append((hw - 0.05, 0.0))
        for x in reversed(xs[1:-1]):
            pts.append((x, 0.0 + (0.06 if any(abs(x - rx) < 0.11 for rx in ribs) else 0.0)))
        pts.append((-hw + 0.05, 0.0))
        pts.append((-hw + 0.05, -d))
        return [(x, y, z) for x, y in pts]

    zs = [-0.1, -0.2, -0.35, -0.6] + [-0.6 - (length - 0.75) * i / 8 for i in range(1, 9)] + [-length]
    rings = [section(z) for z in zs]
    lid = loft(rings, cap_start=True, cap_end=True)
    # the front lip: a rounded downturned edge across the front, crossing the end
    lip = rbox(2 * hw + 0.02, 0.26, 0.08, 0.035, 2)
    merge(lid, lip, T(0, -0.07, -length + 0.02))
    # knuckles round the hinge bar (between the body's brackets), webs to the lid
    for x in (-1.0, 1.0):
        merge(lid, cyl(0.09, 0.5, 14), T(x, 0, 0) @ R(0, 0, 90))
        merge(lid, rbox(0.46, 0.08, 0.16, 0.02, 1), T(x, 0.03, -0.1))
    if warped:
        n = ctx.noise
        for v in lid.verts:
            x, y, z = v.co
            u = -z / length
            v.co.y += 0.12 * u * u * (x / hw) + 0.05 * n.fbm(v.co, 2, 0.8) * u  # twisted, sagging
            if x > hw - 0.6 and z < -length + 0.5:  # the front corner cracked and bent down
                v.co.y -= 0.12 * smoothstep(hw - 0.6, hw, x) * smoothstep(-length + 0.5, -length, z)
    ctx.add("PlasticDark", lid, R(-math.degrees(slope), 0, 0))
    noise = ctx.noise

    def plastic(p):
        x, y, z = p.co
        k = 0.95
        if p.normal.y < -0.4:
            k = 0.7
        k *= 1 - 0.25 * smoothstep(0.0, 0.4, -p.convex)
        k *= 1 + 0.12 * smoothstep(0.1, 0.5, p.convex)
        k *= 1 - 0.2 * smoothstep(0.5, 0.8, noise.fbm((x * 3, y, z * 1.5), 2) * 0.5 + 0.5)
        # dusty chalky top (sun-bleached HDPE): lighter, slightly warm
        if p.normal.y > 0.5:
            return (k * 1.0, k * 0.98, k * 0.95)
        return k

    ctx.wear("PlasticDark", plastic)


def dumpster_lid(ctx):
    """One of the dumpster's two black HDPE lids, modelled CLOSED on the slope, pivot ON the
    hinge bar (rx 0 = closed; 14-30 propped on rubbish; 95-115 thrown back). Three moulded
    ribs, skirt, rounded front lip, hollow ribbed underside, knuckles. Not tinted."""
    _du_lid(ctx, False)


def dumpster_lid_warped(ctx):
    """The same lid warped by the sun and the trucks: twisted, sagging, a cracked front corner
    bent down. Use for one of the two lids."""
    _du_lid(ctx, True)


# ----------------------------------------------------------------------------------------------
# MilkCrate / MilkCrateBroken: the 16 qt (4 gal) dairy crate, 33 x 33 x 28 cm, at
# props_ground.milk_crate's 1.1 x 1.1 x 0.93. PlasticCrate: the Euro 600 x 400 stacking produce
# crate at props_objects.plastic_crates' 2.0 x 1.33 x 0.9 (stack them every 0.9: the feet nest
# just inside the rim). Both are injection-moulded HDPE / PP: real see-through lattice walls
# (holey_panel), rounded corner posts that run down as the feet, a thick moulded top band with
# the hand slots, a grid floor, ribs; wear: chalky sun fade on the top band (the rest a little
# darker), dirt in the floor and from the ground, scuffed corners. Plastic tintable.
# ----------------------------------------------------------------------------------------------
MC_S, MC_H = 1.1, 0.93


def _wall(ctx, layer, panel, x, z, ry, y=0.0, lean=0.0):
    """Places a holey panel (built in X-Y, thickness along Z) as a wall: its centre line at
    (x, z), turned ry about Y, leaning `lean` degrees outward (the crate's draft)."""
    ctx.add(layer, panel, T(x, y, z) @ R(0, ry, 0) @ R(-lean, 0, 0))


def _milk_crate(ctx, broken):
    ctx.budget = 2800
    ctx.smooth_angle = 40
    ctx.tint("Plastic", (168, 36, 34))  # dairy red (the data picks blue, black, green, orange...)
    S, H = MC_S, MC_H
    a = S / 2  # outer half size
    pc = a - 0.075  # post centres
    t = 0.04  # wall thickness
    rng = ctx.rng
    # the walls: a lower and an upper row of tall openings, the hand slot under the band
    w = 2 * pc  # (each wall ends inside the posts)
    cols = 5
    bar = 0.06
    hole_w = (w - 2 * 0.1 - (cols - 1) * bar) / cols
    for side in range(4):
        holes = []
        for row, (y0, y1) in enumerate(((0.1, 0.34), (0.41, 0.6))):
            for c in range(cols):
                u0 = 0.1 + c * (hole_w + bar)
                holes.append([u0, u0 + hole_w, y0, y1])
        holes.append([w / 2 - 0.22, w / 2 + 0.22, 0.645, 0.725])  # the hand slot, just under the band
        if broken and side == 1:  # two bars snapped out: one ragged hole
            h0, h1 = holes[1], holes[3]
            holes = [hl for i, hl in enumerate(holes) if i not in (1, 2, 3)] + [[h0[0], h1[1], h0[2], h1[3]]]
            holes.append([h0[0] + 0.05, h1[1] - 0.05, 0.34, 0.41])  # the middle rail broken through
        if broken and side == 2:
            holes = [hl for i, hl in enumerate(holes) if i not in (6, 7)] + [[holes[6][0], holes[7][1], 0.41, 0.6]]
        p = holey_panel(w, 0.84, t, holes, round_holes=0.012)
        off = a - 0.012 - t / 2
        ry = 90 * side
        d = [(0, -off), (off, 0), (0, off), (-off, 0)][side]
        _wall(ctx, "Plastic", p, d[0], d[1], ry, y=0.04)
    # the corner posts (they run down to the floor as the stacking feet)
    for sx in (-1, 1):
        for sz in (-1, 1):
            ctx.add("Plastic", cyl(0.075, H - 0.005, 10, bevel=0.02), T(sx * pc, (H - 0.005) / 2, sz * pc))
    # the bands: a thick top band (stacking lip), a middle rib, a bottom rail, all rounded

    def band(y0, y1, o_out, o_in, r=0.11):
        outer = [rr_ring(a + o_out - 0.012, a + o_out - 0.012, r, y0, cn=2), rr_ring(a + o_out, a + o_out, r, y0 + 0.012, cn=2),
                 rr_ring(a + o_out, a + o_out, r, y1 - 0.012, cn=2), rr_ring(a + o_out - 0.012, a + o_out - 0.012, r, y1, cn=2)]
        inner = [rr_ring(a - o_in, a - o_in, r - o_in, y, cn=2) for y in (y0, y0 + 0.012, y1 - 0.012, y1)]
        return ring_tube(outer, inner)

    ctx.add("Plastic", band(H - 0.15, H, 0.012, 0.075))
    ctx.add("Plastic", band(0.385, 0.445, 0.004, 0.045))
    ctx.add("Plastic", band(0.03, 0.12, 0.004, 0.045))
    # the floor: a square grid
    n, fb = 4, 0.06
    fw = 2 * pc
    cell = (fw - (n + 1) * fb) / n
    holes = [[fb + i * (cell + fb), fb + i * (cell + fb) + cell, fb + j * (cell + fb), fb + j * (cell + fb) + cell]
             for i in range(n) for j in range(n)]
    if broken:
        holes = [hl for k, hl in enumerate(holes) if k not in (5, 6, 9, 10)] + [[holes[5][0], holes[10][1], holes[5][2], holes[10][3]]]
    floor = holey_panel(fw, fw, 0.045, holes)
    ctx.add("Plastic", floor, T(0, 0.085, fw / 2) @ R(-90, 0, 0))
    # embossed lettering on the band (two sides): short raised bars
    for side in (0, 2):
        z = -(a + 0.012) if side == 0 else (a + 0.012)
        x = -0.3
        while x < 0.3:
            ww = rng.uniform(0.02, 0.06)
            ctx.add("Plastic", box(ww, 0.045, 0.012), T(x + ww / 2, H - 0.075, z + (0.004 if side == 2 else -0.004)))
            x += ww + rng.uniform(0.012, 0.025) + (0.04 if rng.random() < 0.2 else 0.0)
    noise = ctx.noise

    def plastic(p):
        x, y, z = p.co
        k = 0.86 + 0.14 * smoothstep(H - 0.2, H, y)  # the top band sun-bleached lighter
        k *= 1 - 0.3 * (1 - smoothstep(0.0, 0.35 + 0.15 * noise.fbm(p.co, 2, 4.0), y))
        k *= 1 - 0.3 * smoothstep(0.0, 0.3, -p.convex)
        if abs(x) < a - 0.05 and abs(z) < a - 0.05 and y < 0.15:
            k *= 0.7 + 0.2 * noise.fbm(p.co, 2, 8.0)  # dirt in the floor grid
        k *= 1 - 0.2 * smoothstep(0.6, 0.85, noise.fbm(p.co, 3, 6.0) * 0.5 + 0.5)  # scuffs
        return k

    ctx.wear("Plastic", plastic)


def milk_crate(ctx):
    """16 qt dairy milk crate: rounded corner posts/feet, two rows of tall see-through openings
    and a hand slot on each side, thick top band with embossed lettering, middle rib, bottom
    rail, square grid floor. Plastic tintable. Upside down (a seat): rx 180 about y = 0.465."""
    _milk_crate(ctx, False)


def milk_crate_broken(ctx):
    """The same crate kicked about: bars snapped out of two walls (ragged holes), the middle
    rail broken through, the floor grid caved in at one corner."""
    _milk_crate(ctx, True)


PC_W, PC_D, PC_H = 2.0, 1.33, 0.9
PC_DRAFT = 0.04  # each wall is this much further out at the top than at the bottom


def plastic_crate(ctx):
    """Euro 600 x 400 stacking produce crate: drafted lattice walls (two rows of slots on the
    long sides, slots and a moulded hand hole on the ends), corner posts, thick top rim with
    corner stacking lugs, a grid floor on nesting feet. Plastic tintable. Stacks every 0.9."""
    ctx.budget = 2600
    ctx.smooth_angle = 40
    ctx.tint("Plastic", (52, 92, 140))  # crate blue (the data picks green, grey, black, red, yellow)
    W, D, H = PC_W, PC_D, PC_H
    t = 0.045
    lean = math.degrees(math.atan2(PC_DRAFT, H))
    hx, hz = W / 2 - 0.02, D / 2 - 0.02  # wall centre lines at mid height
    pr = 0.08
    # long walls: two rows of 7 slots
    wl = W - 2 * 0.1
    cols, bar = 7, 0.07
    hw_ = (wl - 2 * 0.09 - (cols - 1) * bar) / cols
    holes = []
    for y0, y1 in ((0.14, 0.38), (0.45, 0.66)):
        for c in range(cols):
            u0 = 0.09 + c * (hw_ + bar)
            holes.append([u0, u0 + hw_, y0, y1])
    for s in (-1, 1):
        p = holey_panel(wl, 0.76, t, holes, round_holes=0.012)
        _wall(ctx, "Plastic", p, 0, s * (hz - PC_DRAFT), 0 if s < 0 else 180, y=0.05, lean=lean)
    # ends: three slots low, the hand hole up under the rim
    we = D - 2 * 0.1
    cols_e = 3
    he = (we - 2 * 0.08 - (cols_e - 1) * bar) / cols_e
    holes_e = [[0.08 + c * (he + bar), 0.08 + c * (he + bar) + he, 0.14, 0.42] for c in range(cols_e)]
    holes_e.append([we / 2 - 0.27, we / 2 + 0.27, 0.53, 0.66])
    for s in (-1, 1):
        p = holey_panel(we, 0.76, t, holes_e, round_holes=0.015)
        _wall(ctx, "Plastic", p, s * (hx - PC_DRAFT), 0, -90 if s > 0 else 90, y=0.05, lean=lean)
    # corner posts, leaning with the draft
    for sx in (-1, 1):
        for sz in (-1, 1):
            b = (sx * (W / 2 - 0.1 - PC_DRAFT / 2), 0.04, sz * (D / 2 - 0.1 - PC_DRAFT / 2))
            tp = (sx * (W / 2 - 0.1 + PC_DRAFT / 2), H - 0.02, sz * (D / 2 - 0.1 + PC_DRAFT / 2))
            ctx.add("Plastic", tube([b, tp], pr, 10))
    # the top rim: a thick rounded band (its outside 0.02 beyond the walls), corner lugs

    def band(y0, y1, gx, gz, o_out, o_in, r=0.14):
        outer = [rr_ring(gx + o_out - 0.012, gz + o_out - 0.012, r, y0, cn=3),
                 rr_ring(gx + o_out, gz + o_out, r, y0 + 0.015, cn=3),
                 rr_ring(gx + o_out, gz + o_out, r, y1 - 0.015, cn=3),
                 rr_ring(gx + o_out - 0.012, gz + o_out - 0.012, r, y1, cn=3)]
        inner = [rr_ring(gx - o_in, gz - o_in, r - o_in, y, cn=3) for y in (y0, y0 + 0.015, y1 - 0.015, y1)]
        return ring_tube(outer, inner)

    ctx.add("Plastic", band(H - 0.13, H, W / 2, D / 2, 0.015, 0.08))
    # the bottom: a nesting foot ring set in from the walls, the floor grid on it
    ctx.add("Plastic", band(0.0, 0.1, W / 2 - 0.06, D / 2 - 0.06, 0.0, 0.06, r=0.1))
    fw, fd = W - 0.2, D - 0.2
    n_x, n_z, fb = 7, 4, 0.06
    cx_ = (fw - (n_x + 1) * fb) / n_x
    cz_ = (fd - (n_z + 1) * fb) / n_z
    holes_f = [[fb + i * (cx_ + fb), fb + i * (cx_ + fb) + cx_, fb + j * (cz_ + fb), fb + j * (cz_ + fb) + cz_]
               for i in range(n_x) for j in range(n_z)]
    ctx.add("Plastic", holey_panel(fw, fd, 0.04, holes_f), T(0, 0.09, fd / 2) @ R(-90, 0, 0))
    # ribs under the floor (front to back) on the feet
    for i in range(1, n_x):
        x = -fw / 2 + i * (cx_ + fb) + fb / 2 - 0.0
        ctx.add("Plastic", rbox(0.035, 0.06, fd - 0.05, 0.01, 1), T(x - fb / 2 + 0.0, 0.065, 0))
    noise = ctx.noise

    def plastic(p):
        x, y, z = p.co
        k = 0.84 + 0.16 * smoothstep(H - 0.18, H, y)
        k *= 1 - 0.28 * (1 - smoothstep(0.0, 0.3 + 0.15 * noise.fbm(p.co, 2, 3.0), y))
        k *= 1 - 0.3 * smoothstep(0.0, 0.3, -p.convex)
        if abs(x) < W / 2 - 0.1 and abs(z) < D / 2 - 0.1 and y < 0.14:
            k *= 0.68 + 0.2 * noise.fbm(p.co, 2, 6.0)
        k *= 1 - 0.18 * smoothstep(0.6, 0.85, noise.fbm(p.co, 3, 5.0) * 0.5 + 0.5)
        return k

    ctx.wear("Plastic", plastic)


PIECES = {
    "WheelieBin": wheelie_bin,
    "WheelieBinWorn": wheelie_bin_worn,
    "WheelieBinLid": wheelie_bin_lid,
    "RecyclingBin": recycling_bin,
    "RecyclingBinLid": recycling_bin_lid,
    "RecyclingBinLidPaper": recycling_bin_lid_paper,
    "Dumpster": dumpster,
    "DumpsterLid": dumpster_lid,
    "DumpsterLidWarped": dumpster_lid_warped,
    "MilkCrate": milk_crate,
    "MilkCrateBroken": milk_crate_broken,
    "PlasticCrate": plastic_crate,
}
