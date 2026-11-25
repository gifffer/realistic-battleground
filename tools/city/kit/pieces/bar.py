"""Duffy's bar (Interiors/Duffys) as kit meshes: the counter, its beer fonts, the back bar with
the mirror and the decorative spirits rows, the stools, the booths and their tables, the barrel
tables and ashtrays, the coin-op pool table with its balls, cues and lamp, the jukebox, the
cigarette machine, the dartboard cabinet, the green enamel pendants, the wall speakers, the
pint-glass ledge, the photos on the wall, the booth lamps and candle jars.

Why meshes: the city's Duffy's was boxes and cylinders (a black box with a brown slab for a
counter, three white sticks for taps, coloured sticks for bottles, a disc on a pole for a
stool, a red box for a booth). Each object here is modelled to the real thing (panelled oak
counter with a bullnose top and a brass foot rail on brackets, T-bar fonts with lever taps
over a perforated drip tray, a mirror-backed back bar with lit shelves, pub stools with a
welted vinyl cushion, a swivel plate and a foot ring, button-tufted booth backs, a cast-iron
pedestal table, a coopered oak barrel with riveted hoops, a coin-op bar table with diamonds,
pockets and a coin slide...) and worn the way 30 years of a dive bar wear things: varnish
rubbed to the wood on the counter's edge, ring stains and cigarette burns on tops, kicked and
scuffed kick boards, split vinyl, chalk on the cloth, nicotine on everything high.

Scale (PLAN.md, scale note): the bar's INTERIOR is sized to the R6 body, not to 0.28 m a stud:
every piece takes the heights of the parts it replaces (bar top 2.9 above the floor, stool
seat 2.255 = the NpcSpot SeatHeight 2.25, booth seat 1.5 = SeatHeight 1.5, pool cloth 2.7,
barrel table 2.9) and their footprints, so the collision proxies, the NPC poses and the
16-player layout do not move. Small things in hands' reach (glasses, balls, ashtrays, darts)
are near real size.

Conventions (pieces/_template.py): Roblox axes, studs, +Y up, front = -Z. Floor pieces: origin
at the centre of the footprint on the floor. Wall pieces: origin on the wall face, -Z out of
the wall. CEILING pieces (PendantLampPub, PoolLampBillard): origin on the ceiling face, the
piece hangs down (y < 0). Shelf rows (DecoBottleRow*, PintGlassRow): origin on the board's top
at the row's centre (PintGlassRow: on the wall face at the ledge's top). Only ONE kind of
tintable layer per piece (the marker's Tint goes to every tintable layer).

Brass and vinyl: the kit has no brass or vinyl layer yet. BRASS / VINYL below use the layers
"Brass" / "Vinyl" as soon as kitlib.LAYERS has them (requested), else MetalPainted / Fabric
tinted (a piece that already tints another layer gets Metal for its brass).

Bottles: NOTHING bottle-like anywhere, EXCEPT the three DecoBottleRow pieces, which the player
allowed as pure decoration on Duffy's back-bar shelves only (never pickable, no tag, no
prompt: they replace the 48 decorative "Bottle" parts, which PropKit removes). The kit's name
check has a narrow whitelist for exactly those three names.
"""

import math

import bmesh
from mathutils import Vector

from kitlib import (  # noqa: F401
    LAYERS,
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
from fixtures import rbox, prism, sweep, circle2, rrect2, torus, fillet_path, _transform, _nut, _dome  # noqa: F401

TAU = 2 * math.pi

# Brass / vinyl until the kit has those layers (see the top).
HAS_BRASS = "Brass" in LAYERS
HAS_VINYL = "Vinyl" in LAYERS
BRASS_RGB = (150, 118, 62)
VINYL_RGB = (70, 24, 24)  # Duffy's oxblood (the data's seats)


def brass(ctx, tinted_elsewhere=False):
    """The layer brass goes on for this piece (and tint it when it is the fallback)."""
    if HAS_BRASS:
        return "Brass"
    if tinted_elsewhere:
        return "Metal"
    ctx.tint("MetalPainted", BRASS_RGB)
    return "MetalPainted"


def vinyl(ctx, rgb=VINYL_RGB):
    layer = "Vinyl" if HAS_VINYL else "Fabric"
    ctx.tint(layer, rgb)
    return layer


# ==============================================================================================
# Shared helpers
# ==============================================================================================
def ext_x(section, x0, x1, segs=1):
    """Extrudes a 2-D section [(z, y), ...] along X from x0 to x1 (segs rings: vertices along
    the length for the wear). Closed."""
    rings = [[(lerp(x0, x1, k / segs), y, z) for z, y in section] for k in range(segs + 1)]
    return loft(rings, cap_start=True, cap_end=True)


def ext_z(section, z0, z1, segs=1):
    """Extrudes a 2-D section [(x, y), ...] along Z from z0 to z1. Closed."""
    rings = [[(x, y, lerp(z0, z1, k / segs)) for x, y in section] for k in range(segs + 1)]
    return loft(rings, cap_start=True, cap_end=True)


def arc2(cx, cy, r, a0, a1, n):
    """Points of an arc (degrees a0 -> a1, n segments, both ends)."""
    return [(cx + r * math.cos(math.radians(lerp(a0, a1, k / n))), cy + r * math.sin(math.radians(lerp(a0, a1, k / n))))
            for k in range(n + 1)]


def rect_ring(w, h, z, cx=0.0, cy=0.0):
    return [(cx - w / 2, cy - h / 2, z), (cx + w / 2, cy - h / 2, z), (cx + w / 2, cy + h / 2, z), (cx - w / 2, cy + h / 2, z)]


def raised_panel(w, h, raise_, border, z0=0.0, cx=0.0, cy=0.0):
    """A raised-and-fielded door panel in the XY plane: its back at z0, the bevelled border
    rising toward -Z to a flat field `raise_` proud (a frame round it hides the back). Closed."""
    rings = [rect_ring(w, h, z0, cx, cy), rect_ring(w, h, z0 - raise_ * 0.35, cx, cy),
             rect_ring(w - 2 * border, h - 2 * border, z0 - raise_, cx, cy)]
    return loft(rings, cap_start=True, cap_end=True)


def tube_path(points, r, segs=10, rad=0.0, nseg=6, cap=True):
    """A round tube along a polyline, its corners filleted (rad) like a bent rail."""
    pts = fillet_path(points, rad, nseg) if rad > 0 else points
    return tube(pts, r, segs=segs, cap=cap)


def subdivide(bm, cuts=1):
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    return bm


def disc_spots(rng, n, x0, x1, z0, z1, r0, r1):
    """n random circles (x, z, r) inside a rectangle (stains, burns, wear patches)."""
    return [(rng.uniform(x0, x1), rng.uniform(z0, z1), rng.uniform(r0, r1)) for _ in range(n)]


def varnish_wear(noise, spots=(), burns=(), rub=None, dirt_h=0.5, dirt=0.3, grain=0.08, top_y=None):
    """Old varnished wood: grain streaks (along X), grime low and in creases, ring stains
    (spots: (x, z, r) circles on the top), cigarette burns (darker blotches), rubbed lighter
    where hands and elbows go (rub(p) -> 0..1)."""

    def fn(p):
        x, y, z = p.co
        g = 1 + grain * noise.fbm((x * 0.6, y * 9.0, z * 9.0), 2)
        c = g * (1 - dirt * (1 - smoothstep(0.0, dirt_h, y)))
        c *= 1 - 0.3 * smoothstep(0.0, 0.5, -p.convex)
        c *= 1 + 0.1 * smoothstep(0.05, 0.5, p.convex)
        top = top_y is None or y > top_y - 0.05
        if top and p.normal.y > 0.5:
            for sx, sz, sr in spots:
                d = math.hypot(x - sx, z - sz)
                c *= 1 - 0.22 * smoothstep(sr * 0.25, 0.0, abs(d - sr)) - 0.06 * smoothstep(sr, sr * 0.6, d)
            for sx, sz, sr in burns:
                d = math.hypot(x - sx, z - sz)
                c *= 1 - 0.5 * smoothstep(sr, 0.0, d)
        r, gg, b = c, c, c
        if rub is not None:
            t = rub(p)
            r, gg, b = r * (1 + 0.28 * t), gg * (1 + 0.2 * t), b * (1 + 0.1 * t)
        return (r, gg, b)

    return fn


def metal_wear(noise, dirt=0.25, tarnish=(0.8, 0.72, 0.6), scale=4.0, rub_y=None):
    """Brass / chrome: tarnish in creases and patches, bright where rubbed (rub_y: polished on
    top faces above that height, e.g. a foot rail's top)."""

    def fn(p):
        t = smoothstep(0.1, 0.7, noise.fbm(p.co * scale, 2) * 0.5 + 0.5) * dirt
        t += 0.35 * smoothstep(0.0, 0.5, -p.convex)
        if rub_y is not None and p.normal.y > 0.3:
            t *= 0.3
        t = min(1.0, t)
        return tuple(lerp(1.0, c, t) for c in tarnish)

    return fn


def nicotine(noise, y0, y1, k=0.25):
    """Yellow-brown film rising with height (smoke collects high): multiply into a wear."""

    def fn(p):
        t = smoothstep(y0, y1, p.co.y) * (0.7 + 0.3 * noise.fbm(p.co, 2, 1.5))
        return (1 - 0.3 * k * t, 1 - 0.55 * k * t, 1 - 1.0 * k * t)

    return fn


# ==============================================================================================
# THE COUNTER. Real reference: a pub / dive-bar counter, 42 in (1.07 m) high, about 24 in deep
# with a 2 in (5 cm) bullnosed hardwood top overhanging the front by 6-8 in, a panelled front
# (raised-and-fielded oak panels between stiles, a recessed toe kick so feet do not scuff the
# panels), a 2 in brass foot rail 7-9 in off the floor on cast brackets screwed to the front,
# and behind it the under-bar: open bays with a shelf at knee height. What makes it read: the
# bullnose and its shadow line, the panels, the gleam of the brass rail and its brackets, the
# toe-kick shadow. Wear: varnish worn to pale wood along the top's front edge (forearms), ring
# stains and a few cigarette burns on the top, black shoe scuffs on the kick and bottom rail,
# the brass polished on top by feet, tarnished underneath.
# Data (Interiors/Duffys): BarCounter 16.8 x 2.5 x 2.4 (y 1.9..4.4, z 10.6..13.0), BarTop 16.8 x
# 0.4 x 2.8 (y 4.4..4.8, z 10.2..13.0), FootRail at y 2.48 z 10.32, brackets x 44 / 50.6 / 57.2.
# Two modules of 8.4 (BarCounterModule = the west half with its end, BarCounterModuleR = the
# east half with its end; their seams meet at x 50.6). Origin: the body's centre on the floor
# (z = 0 at the data's z 11.8): the body is z -1.2..1.2, the top z -1.6..1.2, y 2.5..2.9.
# ==============================================================================================
CW = 8.4  # module width
CH = 2.5  # body height (top's underside)
CT = 0.4  # top thickness
CZF = -1.2  # body front face
CZB = 1.2  # back (bartender side)
TOP_F = -1.6  # top's front edge
RAIL_Y, RAIL_Z, RAIL_R = 0.58, -1.48, 0.085


def _bartop_section():
    """The top's section (z, y): flat back, bullnose front (radius 0.2) with a drip groove."""
    y0, y1 = CH, CH + CT
    pts = [(CZB, y0), (CZB, y1)]
    pts += [(TOP_F + 0.2 + 0.2 * math.cos(math.radians(a)), y1 - 0.2 + 0.2 * math.sin(math.radians(a)))
            for a in (90, 112, 135, 158, 180)]
    pts += [(TOP_F + 0.2 + 0.2 * math.cos(math.radians(a)), y0 + 0.2 + 0.2 * math.sin(math.radians(a)))
            for a in (180, 202, 225, 248)]
    pts += [(TOP_F + 0.24, y0 + 0.012), (TOP_F + 0.3, y0 + 0.045), (TOP_F + 0.36, y0 + 0.012), (TOP_F + 0.4, y0)]
    # (a drip groove under the bullnose), then the underside back to the body
    pts.reverse()
    return pts


def _counter(ctx, end_side, worn_seed):
    """One 8.4 module of the counter, its end panel on `end_side` (-1 = -X, +1 = +X)."""
    ctx.budget = 7600
    rng = ctx.rng
    BR = brass(ctx)
    hx = CW / 2
    endx = end_side * hx
    x_lo = -hx + (0.36 if end_side < 0 else 0.0)  # (the carcass stops at the end post)
    x_hi = hx - (0.36 if end_side > 0 else 0.0)

    # --- carcass: the body behind the front frame (z -1.12 .. 0.45), the toe kick recess
    ctx.add("WoodDark", box(CW - 0.02, CH - 0.36, 1.57), T(0, 0.36 + (CH - 0.36) / 2, -1.12 + 1.57 / 2))
    ctx.add("Black", box(CW - 0.04, 0.38, 2.15), T(0, 0.19, -0.98 + 2.15 / 2))  # kick board, recessed 0.22
    # --- front frame: bottom rail, top rail, stiles (WoodDark), proud of the carcass
    FZ = CZF + 0.04  # frame centre z (0.08 thick: -1.2 .. -1.12)
    ctx.add("WoodDark", rbox(CW, 0.34, 0.1, r=0.02, m=2, n=(8, 1, 1)), T(0, 0.36 + 0.17, FZ - 0.01))
    ctx.add("WoodDark", rbox(CW, 0.3, 0.1, r=0.02, m=2, n=(8, 1, 1)), T(0, CH - 0.24 - 0.15, FZ - 0.01))
    n_pan = 3
    pitch = CW / n_pan
    stiles = [-hx + k * pitch for k in range(n_pan + 1)]
    for sx in stiles:
        a, b = max(-hx, sx - 0.16), min(hx, sx + 0.16)
        if b - a < 0.05:
            continue
        # (stiles butt between the rails, 0.025 proud of them: never coplanar)
        y0s, y1s = 0.36 + 0.34 - 0.01, CH - 0.24 - 0.3 + 0.01
        ctx.add("WoodDark", rbox(b - a, y1s - y0s, 0.1, r=0.02, m=2, n=(1, 3, 1)),
                T((a + b) / 2, (y0s + y1s) / 2, FZ - 0.035))
    # raised panels between the stiles (the field 0.05 proud of the panel's back, still behind
    # the frame's face); R's middle panel is a replacement (paler, newer wood, no field)
    for k in range(n_pan):
        cx = -hx + (k + 0.5) * pitch
        w = pitch - 0.32 - 0.02
        h = CH - 0.36 - 0.34 - 0.3 - 0.02
        cy = 0.36 + 0.34 + h / 2 + 0.01
        if end_side > 0 and k == 1:
            ctx.add("Wood", rbox(w + 0.04, h + 0.04, 0.06, r=0.01, m=1, n=(4, 4, 1)), T(cx, cy, -1.13))
            for j in range(3):  # (screw heads holding the replacement board)
                ctx.add("Metal", _dome(0.025, 0.012), T(cx - w / 2 + 0.12 + j * (w - 0.24) / 2, cy + h / 2 - 0.1, -1.16) @ R(-90))
            continue
        ctx.add("WoodDark", raised_panel(w + 0.04, h + 0.04, 0.06, 0.2, z0=-1.1, cx=cx, cy=cy))
    # top rail moulding: an ogee strip under the bullnose, proud of the frame
    og = [(-0.0, 0.0), (-0.07, 0.0), (-0.1, 0.04), (-0.08, 0.08), (-0.1, 0.13), (-0.12, 0.17), (-0.0, 0.2)]
    ctx.add("WoodDark", ext_x([(CZF + 0.01 + z, CH - 0.21 + y) for z, y in og], -hx, hx, 6))
    # --- the end: a corner post and a panelled end side
    if end_side:
        ex = endx - end_side * 0.18
        ctx.add("WoodDark", rbox(0.36, CH - 0.02, 2.42, r=0.03, m=2, n=(1, 4, 6)), T(ex, CH / 2, 0.0))
        side_x = endx + end_side * 0.0
        ctx.add("WoodDark", raised_panel(1.5, 1.4, 0.06, 0.18, z0=0, cx=0, cy=0),
                T(side_x, 1.35, 0.0) @ R(0, -90 * end_side))
    # --- the top (Wood): bullnose, 16 rings along X for the wear
    ctx.add("Wood", ext_x(_bartop_section(), -hx, hx, 16))
    # --- the back (bartender side): two open bays with a shelf, a frame round them
    for k, bx in enumerate((-hx / 2, hx / 2)):
        bw = hx - 0.5
        ctx.add("WoodDark", box(bw, 1.6, 0.74), T(bx, 0.55 + 0.8, 0.45 + 0.37 - 0.01))  # (the bay's inside)
        ctx.add("WoodDark", box(bw, 0.07, 0.72), T(bx, 1.15, 0.45 + 0.36))  # shelf
    ctx.add("WoodDark", box(CW, 0.55, 0.76), T(0, 0.275, 0.45 + 0.38))  # bottom rail of the back frame
    ctx.add("WoodDark", box(CW, 0.36, 0.76), T(0, CH - 0.18, 0.45 + 0.38))  # top rail
    for sx in (-hx + 0.13, 0.0, hx - 0.13):
        ctx.add("WoodDark", box(0.26, CH - 0.02, 0.76), T(sx, CH / 2, 0.45 + 0.38))
    # on the under-bar shelves: a folded bar towel, a glass-washer rack (open grid crate), a
    # stack of drip mats; on the floor of the bays a bucket
    ctx.add("FabricDark", rbox(1.1, 0.06, 0.5, r=0.025, m=2, n=(3, 1, 2)), T(-hx / 2 + rng.uniform(-0.6, 0.6), 1.22, 0.85))
    rx_ = hx / 2 + rng.uniform(-0.8, 0.5)
    ctx.add("PlasticDark", box(1.5, 0.08, 0.66, bevel=0.02), T(rx_, 1.23, 0.84))
    for k in range(4):
        ctx.add("PlasticDark", box(0.05, 0.3, 0.66, bevel=0.01), T(rx_ - 0.72 + k * 0.48, 1.38, 0.84))
    for k in range(2):
        ctx.add("PlasticDark", box(1.5, 0.3, 0.05, bevel=0.01), T(rx_, 1.38, 0.84 - 0.3 + k * 0.6))
    ctx.add("Paper", cyl(0.2, 0.12, segs=16, bevel=0.01), T(-hx / 2 - 1.2, 1.25, 0.8))
    ctx.add("Metal", lathe([(0, 0.0), (0.3, 0.0), (0.36, 0.55), (0.34, 0.56), (0.28, 0.04), (0, 0.04)], segs=16),
            T(hx / 2 - 1.4 * end_side, 0.55, 0.85))

    # --- the brass foot rail on its brackets; its end turns back to the counter (elbow)
    rail_end = endx - end_side * 0.45
    far = -endx  # the seam side
    if end_side < 0:
        pts = [(far, RAIL_Y, RAIL_Z), (rail_end, RAIL_Y, RAIL_Z), (rail_end, RAIL_Y, CZF)]
    else:
        pts = [(far, RAIL_Y, RAIL_Z), (rail_end, RAIL_Y, RAIL_Z), (rail_end, RAIL_Y, CZF)]
    ctx.add(BR, tube_path(pts, RAIL_R, segs=14, rad=0.22, nseg=7))
    ctx.add(BR, cyl(0.14, 0.03, segs=14), T(rail_end, RAIL_Y, CZF - 0.012) @ R(90))  # wall flange
    # brackets: a curved cast arm from a round flange on the frame up under the rail
    bxs = [-2.4 if end_side < 0 else 2.4]
    if end_side < 0:
        bxs.append(hx - 0.02)  # (the seam bracket: data x 50.6, it belongs to the west module)
    for bx in bxs:
        arm = [(bx, RAIL_Y - 0.28, CZF - 0.01), (bx, RAIL_Y - 0.26, CZF - 0.12), (bx, RAIL_Y - 0.2, RAIL_Z + 0.1),
               (bx, RAIL_Y - 0.08, RAIL_Z)]
        ctx.add(BR, tube(arm, [0.04, 0.038, 0.034, 0.03], segs=8))
        ctx.add(BR, cyl(0.12, 0.03, segs=14), T(bx, RAIL_Y - 0.28, CZF - 0.012) @ R(90))
        ctx.add(BR, torus(RAIL_R + 0.018, 0.022, segs=14, sides=6), T(bx, RAIL_Y, RAIL_Z) @ R(0, 0, 90))
        for dy in (-0.07, 0.07):
            ctx.add(BR, _dome(0.02, 0.012), T(bx + dy, RAIL_Y - 0.28, CZF - 0.03) @ R(-90))

    # --- wear: top ring stains and burns, its front edge rubbed pale, kick / rail scuffs
    rng2 = __import__("random").Random(worn_seed)
    spots = disc_spots(rng2, 9 if end_side < 0 else 6, -hx + 0.4, hx - 0.4, -1.2, 0.9, 0.12, 0.22)
    burns = disc_spots(rng2, 2 if end_side < 0 else 4, -hx + 0.4, hx - 0.4, -1.3, -0.6, 0.04, 0.08)
    noise = ctx.noise

    def rub_top(p):
        x, y, z = p.co
        return smoothstep(-0.6, -1.55, z) * smoothstep(CH + CT - 0.25, CH + CT, y) * (0.6 + 0.4 * noise.fbm((x * 0.8, 0, 0), 2))

    ctx.wear("Wood", mul(varnish_wear(noise, spots, burns, rub_top, dirt=0.0, grain=0.12, top_y=CH + CT),
                         lambda p: (0.62, 0.6, 0.6)))

    def body(p):
        x, y, z = p.co
        s = 1 - 0.45 * smoothstep(0.55, 0.8, noise.fbm((x * 3.0, y * 2.0, z), 3) * 0.5 + 0.5) * (1 - smoothstep(0.3, 0.8, y))
        return s

    ctx.wear("WoodDark", mul(varnish_wear(noise, dirt=0.25, dirt_h=0.9, grain=0.1), body, nicotine(noise, 1.5, 2.6, 0.2)))
    ctx.wear("Black", mul(ground_dirt(0.4, 0.2, noise), scuffs(noise, 0.25, 3.0)))
    ctx.wear(BR, metal_wear(noise, 0.4, rub_y=RAIL_Y))
    ctx.wear("FabricDark", mul(scuffs(noise, 0.3, 6.0, 0.4), cavity(0.3)))


def bar_counter_module(ctx):
    """West half of Duffy's counter (8.4 wide): panelled oak front between stiles, bullnosed
    top worn pale at the front edge with ring stains, brass foot rail on cast brackets turning
    back into the end post, under-bar bays behind."""
    _counter(ctx, -1, 11)


def bar_counter_module_r(ctx):
    """East half of Duffy's counter: same build, its end at +X, the middle panel a newer
    screwed-on board, more burns and fewer stains on the top."""
    _counter(ctx, +1, 23)


# ==============================================================================================
# BEER FONTS. Real reference: a chrome T-bar font (a 30-40 cm column with a horizontal tee
# carrying 3 faucets) and an older two-tap pillar font, each faucet a forward-sealing body with
# a down-turned spout and a lever handle screwed on top (tall branded handles: tapered wood, a
# black ball knob, a flat-sided badge handle); a perforated stainless drip tray under the
# spouts, a ribbed rubber bar mat on the customers' side. The faucets face the bartender (+Z);
# the handles read from the room. Wear: chrome dulled by fingerprints and limescale at the
# spouts, the tray's grid stained, the mat sticky.
# Data: Tap 0.3 x 1.4 x 0.3 on the bar top (y 4.8 .. 6.2) at x 45 / 51 / 57, z 12.15, handle to
# y 6.9. Origin: on the bar top under the font's column (data z 12.15).
# ==============================================================================================
def _faucet(ctx, x, y, z, handle, rng):
    """One faucet at (x, y, z) on the font's +Z side: shank, body, spout, lever, handle."""
    ctx.add("Chrome", cyl(0.045, 0.22, segs=10), T(x, y, z + 0.1) @ R(90))  # shank
    ctx.add("Chrome", cyl(0.075, 0.05, segs=12), T(x, y, z + 0.01) @ R(90))  # escutcheon
    body = lathe([(0, -0.16), (0.04, -0.16), (0.05, -0.12), (0.07, -0.05), (0.075, 0.06), (0.06, 0.1), (0, 0.1)], segs=12)
    ctx.add("Chrome", body, T(x, y - 0.02, z + 0.24))
    ctx.add("Chrome", lathe([(0, -0.14), (0.028, -0.14), (0.035, -0.1), (0.035, 0.0), (0, 0.0)], segs=10),
            T(x, y - 0.17, z + 0.27))  # spout
    ctx.add("Chrome", cyl(0.03, 0.16, segs=10), T(x, y + 0.15, z + 0.24))  # lever stem
    h0 = y + 0.22
    if handle == "wood":
        ctx.add("Black", cyl(0.045, 0.1, segs=12), T(x, h0 + 0.05, z + 0.24))
        prof = [(0, 0), (0.05, 0), (0.06, 0.05), (0.075, 0.45), (0.085, 0.62), (0.07, 0.68), (0, 0.69)]
        ctx.add("WoodDark", lathe(prof, segs=12), T(x, h0 + 0.1, z + 0.24) @ R(rng.uniform(-4, 4), 0, rng.uniform(-3, 3)))
    elif handle == "ball":
        ctx.add("Chrome", cyl(0.025, 0.25, segs=8), T(x, h0 + 0.12, z + 0.24))
        ctx.add("Black", lathe([(0, 0), (0.06, 0.02), (0.1, 0.1), (0.09, 0.18), (0.04, 0.22), (0, 0.225)], segs=14),
                T(x, h0 + 0.24, z + 0.24))
    else:  # a flat-sided badge handle: black body, a cream badge front and back
        ctx.add("Black", cyl(0.045, 0.1, segs=12), T(x, h0 + 0.05, z + 0.24))
        ctx.add("Black", rbox(0.18, 0.62, 0.1, r=0.03, m=2, n=(1, 3, 1)), T(x, h0 + 0.42, z + 0.24))
        for sz in (-1, 1):
            ctx.add("Paper", rbox(0.13, 0.3, 0.02, r=0.008, m=1, n=(2, 3, 1)), T(x, h0 + 0.5, z + 0.24 + sz * 0.055))


def _drip_tray(ctx, w, d, at_z):
    """A stainless drip tray (w x d) on the bar top: rim, grid of slots (the bars proud)."""
    ctx.add("Metal", rbox(w, 0.05, d, r=0.015, m=1), T(0, 0.025, at_z))
    n = max(4, int(w / 0.09))
    for k in range(n):
        x = -w / 2 + 0.08 + k * (w - 0.16) / (n - 1)
        ctx.add("Metal", box(0.03, 0.025, d - 0.1), T(x, 0.06, at_z))


def _bar_mat(ctx, w, d, at_z):
    """A ribbed rubber bar mat (the ribs across)."""
    ctx.add("Rubber", rbox(w, 0.025, d, r=0.01, m=1, n=(4, 1, 2)), T(0, 0.0125, at_z))
    for k in range(int(d / 0.1)):
        ctx.add("Rubber", box(w - 0.08, 0.02, 0.04, bevel=0.008), T(0, 0.03, at_z - d / 2 + 0.07 + k * 0.1))


def _font_wear(ctx):
    n = ctx.noise
    ctx.wear("Chrome", mul(metal_wear(n, 0.35, tarnish=(0.75, 0.74, 0.7), scale=7.0), ground_dirt(0.25, 0.3, n)))
    ctx.wear("Metal", mul(scuffs(n, 0.4, 6.0, 0.45), cavity(0.4)))
    ctx.wear("Rubber", mul(scuffs(n, 0.3, 5.0), cavity(0.2)))
    ctx.wear("WoodDark", mul(edge_wear(0.25), cavity(0.2)))
    ctx.wear("Paper", lambda p: (1.0, 0.55 + 0.1 * math.sin(p.co.y * 40), 0.4))  # (a red-orange badge)


def beer_font3(ctx):
    """A chrome T-bar beer font: column on a round base, a tee with three faucets (a tapered
    wood handle, a black ball knob, a flat badge handle), perforated drip tray, rubber mat."""
    ctx.budget = 4200
    ctx.smooth_angle = 40
    rng = ctx.rng
    _drip_tray(ctx, 1.9, 0.5, 0.5)
    _bar_mat(ctx, 1.4, 0.55, -0.45)
    ctx.add("Chrome", lathe([(0, 0), (0.2, 0), (0.2, 0.03), (0.14, 0.07), (0.11, 0.1), (0, 0.1)], segs=20), T(0, 0, 0))
    ctx.add("Chrome", lathe([(0, 0.08), (0.1, 0.08), (0.095, 0.6), (0.085, 1.05), (0.1, 1.08), (0, 1.1)], segs=16))
    tee = lathe([(0, -0.8), (0.07, -0.8), (0.085, -0.76), (0.085, 0.76), (0.07, 0.8), (0, 0.8)], segs=14)
    ctx.add("Chrome", tee, T(0, 1.12, 0) @ R(0, 0, 90))
    ctx.add("Chrome", sphere(0.12, 14, 8), T(0, 1.12, 0))
    for x, h in ((-0.55, "wood"), (0.0, "badge"), (0.55, "ball")):
        _faucet(ctx, x, 1.12, 0.0, h, rng)
    _font_wear(ctx)


def beer_font2(ctx):
    """An older two-tap pillar font: two curved chrome necks off one drip tray, their faucets
    on the bartender's side (a ball knob and a tapered wood handle), a rubber mat in front."""
    ctx.budget = 3400
    ctx.smooth_angle = 40
    rng = ctx.rng
    _drip_tray(ctx, 1.3, 0.5, 0.5)
    _bar_mat(ctx, 1.1, 0.5, -0.42)
    for x, h in ((-0.3, "ball"), (0.3, "wood")):
        ctx.add("Chrome", lathe([(0, 0), (0.13, 0), (0.13, 0.03), (0.08, 0.08), (0, 0.08)], segs=16), T(x, 0, 0))
        neck = [(x, 0.05, 0.0), (x, 0.7, 0.0), (x, 0.92, 0.02), (x, 1.02, 0.1), (x, 1.05, 0.2)]
        ctx.add("Chrome", tube(neck, [0.065, 0.06, 0.058, 0.055, 0.055], segs=12))
        _faucet(ctx, x, 1.05, 0.06, h, rng)
    _font_wear(ctx)


# ==============================================================================================
# BAR STOOLS. Real reference: a pub / diner bar stool, seat 29-30 in (75 cm) high: a domed cast
# base (40 cm) bolted to the floor or weighted, a steel column, a chrome foot ring on three
# spokes about a third of the way up, a swivel bearing under a plywood seat pan, and a padded
# cushion in buttoned vinyl with a welt (piping) round its top edge. Wear: vinyl split and
# taped, foam showing through a tear, the foot ring's chrome rubbed to steel on top, the base
# chipped and black with floor grime.
# Data: StoolBase 1.2 disc, StoolPole, StoolSeat 1.4 x 0.35 with its top at y 4.155 = 2.255 over
# the floor (the NPC spot's SeatHeight 2.25). Origin: centre on the floor.
# ==============================================================================================
SEAT_TOP = 2.255


def _stool(ctx, torn):
    ctx.budget = 3300
    ctx.smooth_angle = 40
    VN = vinyl(ctx)
    noise = ctx.noise
    rng = ctx.rng
    # base: domed cast iron, chipped
    base = [(0, 0.0), (0.6, 0.0), (0.62, 0.02), (0.6, 0.05), (0.45, 0.1), (0.25, 0.17), (0.14, 0.24), (0.12, 0.28), (0, 0.28)]
    ctx.add("Black", lathe(base, segs=28))
    ctx.add("Metal", lathe([(0, 0.26), (0.095, 0.26), (0.09, 1.82), (0.13, 1.84), (0.13, 1.9), (0, 1.9)], segs=16))
    # foot ring (drooping on the torn one: a kicked spoke)
    ring_y = 0.78
    droop = 0.1 if torn else 0.0
    pts = []
    for k in range(36):
        a = TAU * k / 36
        pts.append((0.56 * math.cos(a), ring_y - droop * max(0.0, math.cos(a - 1.0)) ** 2, 0.56 * math.sin(a)))
    ctx.add("Chrome", tube(pts, 0.04, segs=8, closed=True))
    for k in range(3):
        a = TAU * k / 3 + 0.5
        tip = (0.53 * math.cos(a), ring_y - droop * max(0.0, math.cos(a - 1.0)) ** 2, 0.53 * math.sin(a))
        ctx.add("Chrome", tube([(0.09 * math.cos(a), ring_y + 0.06, 0.09 * math.sin(a)), tip], 0.025, segs=6))
    ctx.add("Chrome", cyl(0.13, 0.08, segs=16), T(0, ring_y + 0.06, 0))  # (the spokes' collar)
    # swivel plate and seat pan
    ctx.add("Black", cyl(0.3, 0.04, segs=20, bevel=0.01), T(0, 1.92, 0))
    ctx.add("WoodDark", cyl(0.64, 0.05, segs=28, bevel=0.01), T(0, 1.965, 0))
    # cushion: lathe, a soft crown, the welt round its top edge; the torn one split open
    tear_a, tear_w = rng.uniform(0, TAU), 0.55

    def gouge(a, r, y):
        if not torn:
            return r
        da = math.atan2(math.sin(a - tear_a), math.cos(a - tear_a))
        t = smoothstep(tear_w, 0.0, abs(da)) * smoothstep(2.08, 2.2, y)
        return r - 0.09 * t * (0.7 + 0.3 * math.sin(a * 23))

    prof = [(0, 1.985), (0.66, 1.985), (0.68, 2.03), (0.69, 2.1), (0.685, 2.16), (0.665, 2.2), (0.6, 2.235), (0.45, 2.25),
            (0.25, 2.254), (0, SEAT_TOP)]
    ctx.add(VN, lathe(prof, segs=40, radius_fn=gouge))
    welt = [(0.67 * math.cos(TAU * k / 40), 2.2, 0.67 * math.sin(TAU * k / 40)) for k in range(40)]
    ctx.add(VN, tube(welt, 0.022, segs=6, closed=True))
    ctx.add(VN, lathe([(0, 2.24), (0.045, 2.24), (0.05, 2.25), (0.03, 2.262), (0, 2.264)], segs=10))  # button
    if torn:
        # the foam under the split, and two strips of black tape over an older tear
        ctx.add("Foam", lathe([(0, 2.0), (0.6, 2.0), (0.62, 2.12), (0.56, 2.2), (0.3, 2.225), (0, 2.23)], segs=28))
        b = tear_a + math.pi * 0.9
        for k, off in enumerate((-0.06, 0.07)):
            c, s_ = math.cos(b + off), math.sin(b + off)
            strip = [(r * c, 2.248 - 0.11 * smoothstep(0.42, 0.7, r) + 0.004 * k, r * s_) for r in (0.18, 0.3, 0.42, 0.55, 0.64, 0.7)]
            strip[-1] = (0.705 * c, 2.12, 0.705 * s_)
            ctx.add("Black", sweep(strip, [(-0.05, 0.0), (0.05, 0.0), (0.05, 0.006), (-0.05, 0.006)], side=(0, 1, 0)))

    def vin(p):
        x, y, z = p.co
        top = smoothstep(2.15, 2.25, y)
        shine = 1 + 0.15 * top * smoothstep(0.5, 0.0, math.hypot(x, z))  # (polished by trousers)
        crack = 1 - 0.3 * smoothstep(0.72, 0.9, noise.ridge((x * 6, y * 6, z * 6)))
        return (shine * crack, shine * crack, shine * crack)

    ctx.wear(VN, mul(vin, cavity(0.35)))
    ctx.wear("Black", mul(ground_dirt(0.25, 0.25, noise), edge_wear(0.6), scuffs(noise, 0.2, 5.0)))
    ctx.wear("Chrome", mul(metal_wear(noise, 0.45, (0.7, 0.68, 0.64), 5.0, rub_y=0.0), ground_dirt(0.5, 0.3, noise)))
    ctx.wear("Metal", mul(ground_dirt(0.8, 0.35, noise), metal_wear(noise, 0.3)))
    ctx.wear("Foam", mul(scuffs(noise, 0.35, 8.0, 0.4), lambda p: (1.0, 0.9, 0.7)))


def bar_stool_pub(ctx):
    """A pub bar stool: domed cast base, steel column, chrome foot ring on three spokes,
    swivel plate, welted vinyl cushion with a button, its crown polished by use."""
    _stool(ctx, False)


def bar_stool_pub_torn(ctx):
    """The same stool, abused: the cushion split with yellow foam showing, black tape over an
    older tear, the foot ring drooping where a spoke was kicked."""
    _stool(ctx, True)


# ==============================================================================================
# BOOTH SEATING. Real reference: a pub / diner booth (banquette): a seat at 45-48 cm on a
# plinth, a tall upholstered back (100-110 cm) in deep diamond button tufting, piping, a wooden
# cap rail on top and moulded wooden end panels; oxblood vinyl or leather. Wear: the seat's
# front roll rubbed pale and cracked, the tufts' creases black with grime, the end panels
# kicked, a tear patched on the seat.
# Data: BoothSeat 8 x 1.5 x 1.6 (seat top 1.5 over the floor = the NPC SeatHeight 1.5) +
# BoothBack 8 x 2 x 0.5 behind it (top 3.5 over the floor), the BoothCollider round the whole
# booth. Origin: the centre of seat + back on the floor, the seat's front at -Z (z -0.8), the
# back's rear face at z +0.8.
# ==============================================================================================
BW = 8.0


def booth_seat_tufted(ctx):
    """An 8-stud booth banquette: plinth, seat cushion with a front roll (two sagged places),
    diamond button-tufted back leaning a little, piping, oak cap rail, moulded end panels."""
    ctx.budget = 7800
    ctx.smooth_angle = 50
    VN = vinyl(ctx)
    noise = ctx.noise
    hx = BW / 2 - 0.12  # (inside the end panels)
    # plinth and seat apron
    ctx.add("Black", box(BW - 0.3, 0.3, 1.3, bevel=0.02), T(0, 0.15, 0.05))
    ctx.add("WoodDark", rbox(BW - 0.24, 0.85, 0.12, r=0.025, m=2, n=(8, 2, 1)), T(0, 0.3 + 0.425, -0.66))
    ctx.add("WoodDark", box(BW - 0.3, 0.9, 1.0), T(0, 0.75, 0.0))  # (the seat's box inside)
    # seat cushion: a section with a front roll swept along X, sagged where people sit
    sec = [(0.32, 1.12), (-0.62, 1.12)] + arc2(-0.62, 1.31, 0.19, -90, 90, 6)[1:] + [(-0.2, 1.505), (0.32, 1.505)]

    def sag(x):
        return 0.06 * sum(math.exp(-((x - c) / 0.9) ** 2) for c in (-1.9, 1.9))

    rings = []
    nx = 28
    for k in range(nx + 1):
        x = lerp(-hx, hx, k / nx)
        rings.append([(x, y - sag(x) * smoothstep(1.3, 1.5, y), z) for z, y in sec])
    ctx.add(VN, loft(rings, cap_start=True, cap_end=True))
    # piping along the seat's front top edge
    ctx.add(VN, tube([(x, 1.49 - sag(x), -0.66) for x in (lerp(-hx, hx, k / 20) for k in range(21))], 0.028, segs=6))
    # tufted back: a slab subdivided, its front pushed out into pillows between the buttons
    th, bh = 0.42, 2.02  # thickness, height
    back = rbox(2 * hx, bh, th, r=0.08, m=2, n=(40, 10, 1))
    cols, rows = 8, 3
    px, py = 2 * hx / cols, (bh - 0.3) / rows
    buttons = []
    for j in range(rows + 1):
        for i in range(cols + 1):
            if (i + j) % 2 == 0:
                buttons.append((-hx + i * px, -bh / 2 + 0.15 + j * py))

    def tuft(co):
        if co.z > -th / 2 + 0.05:
            return co
        d = min(math.hypot((co.x - bx) / px, (co.y - by) / py) for bx, by in buttons)
        edge = smoothstep(0.0, 0.12, min(hx - abs(co.x), bh / 2 - abs(co.y)))
        co.z -= (0.09 * smoothstep(0.0, 0.7, d) - 0.03) * edge
        return co

    for v in back.verts:
        v.co = tuft(v.co)
    lean = R(-7)
    ctx.add(VN, back, T(0, 1.5, 0.55) @ lean @ T(0, bh / 2, 0))
    for bx, by in buttons:
        if abs(bx) < hx - 0.05 and abs(by) < bh / 2 - 0.05:
            ctx.add(VN, sphere(0.035, 8, 5), T(0, 1.5, 0.55) @ lean @ T(bx, bh / 2 + by, -th / 2 + 0.025))
    # cap rail on top of the back
    top = T(0, 1.5, 0.55) @ lean @ T(0, bh, 0)
    ctx.add("WoodDark", rbox(BW - 0.1, 0.12, 0.56, r=0.05, m=2, n=(8, 1, 1)), top @ T(0, 0.05, 0.0))
    # end panels: the seat-and-back silhouette, 0.1 thick, moulded edge
    side = [(-0.82, 0.0), (0.8, 0.0), (0.8, 3.56), (0.42, 3.6), (0.3, 3.4), (0.36, 1.75), (0.1, 1.6), (-0.72, 1.6),
            (-0.82, 1.5)]
    for sx in (-1, 1):
        ctx.add("WoodDark", ext_x([(z, y) for z, y in side], sx * (BW / 2 - 0.12), sx * BW / 2, 1))
    # the booth's outer back: tongue-and-groove boards (seen from the room behind it)
    nb = 20
    for k in range(nb):
        x0 = -hx + k * (2 * hx / nb)
        ctx.add("WoodDark", box(2 * hx / nb - 0.025, 3.3, 0.08), T(x0 + hx / nb, 0.15 + 1.65, 0.755))
    ctx.add("WoodDark", box(2 * hx, 3.3, 0.08), T(0, 0.15 + 1.65, 0.705))  # (the board's backing: fills the grooves)

    def vin(p):
        x, y, z = p.co
        roll = smoothstep(-0.45, -0.75, z) * smoothstep(1.0, 1.4, y) * (1 - smoothstep(1.6, 1.7, y))
        seat = smoothstep(1.35, 1.5, y) * (1 - smoothstep(1.6, 1.7, y))
        rub = max(roll * (0.6 + 0.4 * noise.fbm((x * 2, 0, 0), 2)), seat * 0.4 * sum(math.exp(-((x - c) / 1.0) ** 2) for c in (-1.9, 1.9)))
        crack = 1 - 0.35 * smoothstep(0.78, 0.92, noise.ridge((x * 5, y * 5, z * 5))) * (0.4 + rub)
        g = (1 + 0.32 * rub) * crack
        return (g, g * 0.97, g * 0.95)

    ctx.wear(VN, mul(vin, cavity(0.55), nicotine(noise, 2.5, 3.6, 0.3)))
    ctx.wear("WoodDark", mul(varnish_wear(noise, dirt=0.35, dirt_h=0.8), scuffs(noise, 0.3, 3.0, 0.5)))
    ctx.wear("Black", ground_dirt(0.3, 0.3, noise))


# ==============================================================================================
# PUB TABLE. Real reference: a pub dining table on two cast-iron "Britannia" pedestals (column
# with mouldings, four splayed scrolled feet), a 30-35 mm hardwood top with a rounded edge on
# an apron frame, a brass edge band. 75 cm high. Wear: ring stains, a cigarette burn, knife-
# carved initials, the edge's varnish worn by forearms, the feet's paint chipped.
# Data: BoothTable 6 x 0.3 x 2.4 (top at 2.5 over the floor), TableLeg 0.6 square under it.
# Origin: the centre on the floor.
# ==============================================================================================
def _pedestal(ctx, x):
    col = [(0, 0.12), (0.22, 0.12), (0.2, 0.2), (0.12, 0.26), (0.1, 0.4), (0.085, 1.3), (0.1, 1.72), (0.13, 1.8),
           (0.2, 1.86), (0.22, 1.98), (0, 1.98)]
    ctx.add("Black", lathe(col, segs=16), T(x, 0, 0))
    for k in range(4):
        a = 45 + 90 * k
        c, s_ = math.cos(math.radians(a)), math.sin(math.radians(a))
        foot = [(0.12 * c, 0.3, 0.12 * s_), (0.35 * c, 0.2, 0.35 * s_), (0.6 * c, 0.1, 0.6 * s_), (0.72 * c, 0.05, 0.72 * s_)]
        ctx.add("Black", sweep(foot, [(-0.05, -0.05), (0.05, -0.05), (0.05, 0.05), (-0.05, 0.05)], side=(0, 1, 0),
                               scales=[1.4, 1.1, 0.9, 0.8]), T(x, 0, 0))
        ctx.add("Black", sphere(0.06, 10, 6), T(x + 0.74 * c, 0.05, 0.74 * s_))


def pub_table(ctx):
    """A pub table: oak top with a rounded edge and a brass edge band on an apron, two cast
    Britannia pedestals; ring stains, a burn, carved initials, rubbed edges."""
    ctx.budget = 4800
    ctx.smooth_angle = 40
    BR = brass(ctx)
    rng = ctx.rng
    noise = ctx.noise
    top = rbox(6.0, 0.24, 2.4, r=0.08, m=2, n=(18, 1, 8))
    ctx.add("Wood", top, T(0, 2.38, 0))
    # brass band round the edge, under the rounded top
    band = rrect2(6.02, 2.42, 0.1, n=3)
    ring = [(u, 2.29, v) for u, v in band]
    ctx.add(BR, sweep(ring, [(-0.0, -0.035), (0.018, -0.035), (0.018, 0.035), (0.0, 0.035)], side=(0, 1, 0), closed=True))
    ctx.add("WoodDark", box(5.0, 0.22, 1.6, bevel=0.02), T(0, 2.15, 0))  # apron
    for x in (-1.9, 1.9):
        _pedestal(ctx, x)
    ctx.add("Black", box(3.6, 0.1, 0.1, bevel=0.02), T(0, 0.45, 0))  # stretcher
    spots = disc_spots(rng, 7, -2.6, 2.6, -0.9, 0.9, 0.12, 0.2)
    burns = disc_spots(rng, 1, -2.0, 2.0, -0.9, 0.9, 0.05, 0.08)
    cx, cz = rng.uniform(-1.5, 1.5), rng.uniform(-0.5, 0.5)

    def carve(p):
        x, y, z = p.co
        if p.normal.y < 0.5:
            return 1.0
        t = smoothstep(0.88, 0.97, noise.ridge(((x - cx) * 9, 0, (z - cz) * 9))) * smoothstep(0.5, 0.2, math.hypot(x - cx, z - cz))
        return 1 - 0.45 * t

    def rub(p):
        x, y, z = p.co
        return smoothstep(0.85, 1.2, abs(z)) * 0.8

    ctx.wear("Wood", mul(varnish_wear(noise, spots, burns, rub, dirt=0.0, grain=0.12, top_y=2.5), carve, lambda p: (0.66, 0.6, 0.56)))
    ctx.wear("WoodDark", mul(varnish_wear(noise, dirt=0.0), cavity(0.3)))
    ctx.wear("Black", mul(ground_dirt(0.4, 0.25, noise), edge_wear(0.7), scuffs(noise, 0.2, 4.0)))
    ctx.wear(BR, metal_wear(noise, 0.5))


def table_lamp_brass(ctx):
    """A small brass table lamp: turned base, stem, pleated parchment shade gone yellow, the
    bulb under it (Glow). Real: a 30-35 cm booth lamp. Data: LampBase + TableLamp (a lit ball),
    about 0.95 tall on the table. Origin: on the table top."""
    ctx.budget = 1600
    BR = brass(ctx)
    noise = ctx.noise
    ctx.add(BR, lathe([(0, 0), (0.2, 0), (0.21, 0.03), (0.17, 0.07), (0.1, 0.1), (0.06, 0.16), (0, 0.16)], segs=20))
    ctx.add(BR, lathe([(0, 0.15), (0.03, 0.15), (0.03, 0.5), (0.05, 0.53), (0.045, 0.6), (0.02, 0.62), (0, 0.62)], segs=12))
    ctx.add("Glow", sphere(0.11, 12, 8), T(0, 0.66, 0))
    # pleated shade: a frustum whose radius ripples, open at top and bottom (a ring solid)
    n = 48

    def pleat(a, r, y):
        return r * (1 + 0.04 * math.cos(a * 16))

    shade = lathe([(0.26, 0.47), (0.265, 0.47), (0.16, 0.86), (0.155, 0.86), (0.25, 0.475)], segs=n, radius_fn=pleat)
    ctx.add("Paper", shade)
    ctx.wear("Paper", mul(nicotine(noise, 0.5, 0.9, 1.0), lambda p: (1.0, 0.95, 0.82)))
    ctx.wear(BR, metal_wear(noise, 0.5))


def candle_jar(ctx):
    """A red glass candle holder in a plastic net (the old pub-table kind), a stub of wax and
    the flame inside (Glow, no light: it just glows). Data: CandleJar 0.4 x 0.4. Origin: on
    the table."""
    ctx.budget = 1400
    noise = ctx.noise
    jar = [(0.0, 0.0), (0.12, 0.0), (0.17, 0.04), (0.2, 0.15), (0.19, 0.3), (0.14, 0.38), (0.13, 0.4), (0.115, 0.4),
           (0.125, 0.37), (0.17, 0.3), (0.18, 0.15), (0.15, 0.06), (0.1, 0.03), (0.0, 0.03)]
    # hobnail glass: small round bumps all over (the cut-glass look of the old red holders)
    def hob(a, r, y):
        if y < 0.04 or y > 0.37 or r < 0.15:
            return r
        return r + 0.012 * max(0.0, math.cos(a * 10)) * max(0.0, math.cos(y * 70))

    ctx.add("Glass", lathe(jar, segs=40, radius_fn=hob))
    ctx.add("Glow", lathe([(0, 0.03), (0.1, 0.03), (0.1, 0.14), (0, 0.13)], segs=12))  # wax stub
    ctx.add("Glow", lathe([(0, 0.135), (0.02, 0.15), (0.025, 0.18), (0.012, 0.22), (0, 0.25)], segs=8))  # flame
    ctx.wear("Glass", lambda p: (1.0, 0.42 + 0.05 * noise.n(p.co * 9), 0.36))


# ==============================================================================================
# BARREL TABLE. Real reference: a 225-litre oak wine / whisky barrel stood on end as a poseur
# table: 22-24 bevelled staves bulging at the belly, 4-6 galvanised or black iron hoops with
# rivets, the bung on the belly, a round board top (often a little wider than the head) made of
# 4-5 planks with dark gaps. Wear: oak greyed and dark low, hoops rusty at the rivets and the
# bottom, the top's varnish ringed, chalk marks of the cooperage on a stave.
# Data: HighTable 3 dia x 2.9 (top 2.9 over the floor), BarrelHoop 3.08 dia at 0.7 and 2.4.
# Origin: the centre on the floor.
# ==============================================================================================
def barrel_table(ctx):
    """An oak barrel table: 22 staves bulging at the belly, four riveted iron hoops, a bung,
    a round plank top a little wider than the head; greyed oak, rusty hoops, ringed top."""
    ctx.budget = 6600
    ctx.smooth_angle = 30
    noise = ctx.noise
    rng = ctx.rng
    H = 2.74
    staves = 22

    def r_at(y):
        t = y / H
        return 1.3 + 0.18 * math.sin(math.pi * t)

    def groove(a, r, y):
        f = (a * staves / TAU) % 1.0
        d = min(f, 1 - f)
        rr = r - 0.018 * smoothstep(0.06, 0.0, d) + 0.006 * noise.n((math.cos(a) * 3, y * 2, math.sin(a) * 3))
        return rr

    prof = [(0, 0.04), (1.22, 0.04), (1.28, 0.0)] + [(r_at(y), y) for y in [H * k / 14 for k in range(15)]][1:] + [(1.28, H), (1.22, H - 0.05), (0, H - 0.05)]
    extra = [TAU * (k + 0.5) / staves for k in range(staves)]
    ctx.add("Wood", lathe(prof, segs=staves * 3, extra_angles=[e - 0.004 for e in extra] + [e + 0.004 for e in extra], radius_fn=groove))
    # hoops: bands following the bulge, 0.025 proud, rivets
    for y0, w in ((0.12, 0.16), (0.7, 0.2), (2.0, 0.2), (2.55, 0.16)):
        prof_h = [(r_at(y0) + 0.002, y0), (r_at(y0) + 0.03, y0 + 0.01), (r_at(y0 + w) + 0.03, y0 + w - 0.01), (r_at(y0 + w) + 0.002, y0 + w),
                  (r_at(y0 + w / 2) - 0.03, y0 + w / 2)]
        ctx.add("Metal", lathe(prof_h, segs=48))
        a0 = rng.uniform(0, TAU)
        for k in range(2):
            a = a0 + k * math.pi
            rr = r_at(y0 + w / 2) + 0.03
            ctx.add("Metal", _dome(0.025, 0.014), T(rr * math.cos(a), y0 + w / 2, rr * math.sin(a)) @ R(0, -math.degrees(a), -90))
    # bung on the belly (front)
    rb = r_at(H / 2)
    ctx.add("WoodDark", cyl(0.1, 0.06, segs=12), T(0, H / 2 + 0.12, -rb - 0.0) @ R(90))
    # the top: five planks with gaps, a round outline, on battens
    TR = 1.6
    for k in range(5):
        x0, x1 = -TR + k * (2 * TR / 5) + 0.012, -TR + (k + 1) * (2 * TR / 5) - 0.012
        ring = []
        for j in range(13):
            z = lerp(-1, 1, j / 12)
            ring.append(z)
        poly = []
        xs = [lerp(x0, x1, j / 3) for j in range(4)]
        for x in xs:
            poly.append((x, -math.sqrt(max(0.0, TR * TR - x * x))))
        for x in reversed(xs):
            poly.append((x, math.sqrt(max(0.0, TR * TR - x * x))))
        sec = [(x, -z) for x, z in poly]
        bm = prism(sec, 0.0, 0.14)
        ctx.add("WoodDark", bm, T(0, H + 0.14, 0) @ R(90))
    ctx.add("WoodDark", box(2.3, 0.08, 0.2), T(0, H + 0.0, -0.6))
    ctx.add("WoodDark", box(2.3, 0.08, 0.2), T(0, H + 0.0, 0.6))
    spots = disc_spots(rng, 6, -1.1, 1.1, -1.1, 1.1, 0.12, 0.2)

    def oak(p):
        x, y, z = p.co
        g = 0.62 * (1 + 0.1 * noise.fbm((x * 4, y * 0.4, z * 4), 2))
        g *= 1 - 0.35 * (1 - smoothstep(0.0, 0.9, y))
        chalk = 1 + 0.5 * smoothstep(0.86, 0.95, noise.ridge((x * 3, y * 6, z * 3))) * smoothstep(1.0, 1.4, y) * smoothstep(2.0, 1.6, y) * smoothstep(0.3, 1.0, -z)
        return (g * chalk, g * 0.95 * chalk, g * 0.9 * chalk)

    ctx.wear("Wood", mul(oak, cavity(0.45)))
    ctx.wear("WoodDark", mul(varnish_wear(noise, spots, (), None, dirt=0.0, grain=0.15, top_y=H + 0.14), lambda p: (0.8, 0.75, 0.7)))

    def hoop(p):
        x, y, z = p.co
        rust = smoothstep(0.2, 0.7, noise.fbm(p.co * 5, 3) * 0.5 + 0.5) * (0.5 + 0.5 * (1 - smoothstep(0.1, 1.0, y)))
        return (lerp(0.42, 0.62, rust), lerp(0.42, 0.36, rust), lerp(0.44, 0.24, rust))

    ctx.wear("Metal", hoop)


def ashtray(ctx):
    """A pressed tin pub ashtray (round, three cigarette rests), grey ash, four crushed butts
    (white paper, cork-coloured filters). Real: 12-15 cm. Data: Ashtray 0.6 x 0.15. Origin: on
    the table."""
    ctx.budget = 1300
    ctx.smooth_angle = 45
    noise = ctx.noise
    rng = ctx.rng

    def notches(a, r, y):
        if y < 0.08 or r < 0.25:
            return r if isinstance(r, float) else r
        d = min(abs(math.atan2(math.sin(a - TAU * k / 3), math.cos(a - TAU * k / 3))) for k in range(3))
        return (r, y - 0.035 * smoothstep(0.18, 0.0, d))

    prof = [(0, 0.0), (0.24, 0.0), (0.29, 0.02), (0.3, 0.1), (0.31, 0.11), (0.3, 0.12), (0.27, 0.115), (0.26, 0.04),
            (0.24, 0.025), (0, 0.025)]
    ctx.add("Metal", lathe(prof, segs=36, radius_fn=notches))
    ctx.add("Concrete", lathe([(0, 0.02), (0.22, 0.02), (0.18, 0.045), (0.08, 0.06), (0, 0.062)], segs=16))
    for k in range(4):
        a = rng.uniform(0, TAU)
        r0 = rng.uniform(0.0, 0.12)
        x, z = r0 * math.cos(a), r0 * math.sin(a)
        yaw = rng.uniform(0, 360)
        L = rng.uniform(0.12, 0.2)
        bend_ = rng.uniform(-30, 30)
        m = T(x, 0.06, z) @ R(0, yaw, 0) @ R(0, 0, rng.uniform(-12, 18))
        ctx.add("Foam", cyl(0.022, 0.08, segs=8), m @ T(0.04, 0, 0) @ R(0, 0, 90))
        ctx.add("Paper", cyl(0.021, L - 0.08, segs=8), m @ T(0.08, 0, 0) @ R(0, bend_ * 0.2, 0) @ T((L - 0.08) / 2, 0, 0) @ R(0, 0, 90))
    ctx.wear("Metal", mul(metal_wear(noise, 0.6, (0.62, 0.6, 0.56), 8.0), cavity(0.4)))
    ctx.wear("Concrete", lambda p: 0.55 + 0.3 * (noise.fbm(p.co * 20, 2) * 0.5 + 0.5))
    ctx.wear("Foam", lambda p: (0.95, 0.72, 0.45))
    ctx.wear("Paper", lambda p: 1.0 - 0.4 * smoothstep(0.1, 0.0, abs(p.co.x)))


# ==============================================================================================
# POOL. Real reference: a coin-op 7 ft "bar box" (Valley / Dynamo): a laminated cabinet on four
# square corner legs with levellers, solid wood top rails with mother-of-pearl diamond sights,
# K-66 rubber cushions under the cloth, six pockets with black rubber liners, a chrome coin
# slide on the foot end and the ball-return window under it; slate bed under a green worsted
# cloth, 2.1 x 1.2 m outside. Cues: 57-58 in, maple shaft with a white ferrule and a blue-
# chalked leather tip, a dark butt with a black linen wrap and a joint ring. Balls: 57 mm, the
# cue ball, solids, stripes and the black 8 with a white number spot. Lamp: a three-shade
# billiard lamp on chains, green enamel domes, white inside.
# Wear: the cloth bald and pale on the break spot and along the cushions, blue chalk smudges, a
# cigarette burn; the rails' varnish worn where bridges rest; chrome scratched round the slide.
# Data: PoolTableCollider 4 x 2.8 x 7.4 (top 2.8 over the floor), Felt top at 2.7, PoolBall 0.35
# at y 4.78, Cue 0.12 x 4.4 leaning on the east wall, PoolLamp 1 x 0.4 x 5 at y 10.2 on two
# Chains to the ceiling (15.6). Table origin: centre on the floor, long side along Z.
# ==============================================================================================
PT_W, PT_L = 4.0, 7.4
BED_Y = 2.7  # the cloth's top
RAIL_TOP = 2.8
IN_W, IN_L = 3.2, 6.6  # the playing area inside the cushions' noses
POCKETS = [(sx * IN_W / 2, sz * IN_L / 2) for sx in (-1, 1) for sz in (-1, 1)] + [(sx * (IN_W / 2 + 0.06), 0.0) for sx in (-1, 1)]


def pool_table_bar(ctx):
    """A coin-op bar pool table: laminate cabinet on square legs with levellers, oak rails with
    diamond sights, cloth-covered cushions, six rubber-lined pockets, slate bed, chrome coin
    slide and ball-return window; the cloth bald on the break spot and chalk-marked."""
    ctx.budget = 8000
    ctx.smooth_angle = 40
    ctx.tint("Fabric", (36, 80, 52))
    noise = ctx.noise
    hw, hl = PT_W / 2, PT_L / 2
    # cabinet + legs
    ctx.add("Wood", rbox(PT_W - 0.5, 1.95, PT_L - 0.5, r=0.04, m=2, n=(3, 3, 6)), T(0, 0.4 + 0.975, 0))
    for sx in (-1, 1):
        for sz in (-1, 1):
            ctx.add("WoodDark", rbox(0.5, 2.0, 0.5, r=0.03, m=1, n=(1, 3, 1)), T(sx * (hw - 0.3), 0.32 + 1.0, sz * (hl - 0.3)))
            ctx.add("Black", cyl(0.17, 0.32, segs=10), T(sx * (hw - 0.3), 0.16, sz * (hl - 0.3)))
    # the slate bed under the cloth, the cloth over it
    ctx.add("Black", box(IN_W + 0.5, 0.25, IN_L + 0.5), T(0, BED_Y - 0.17, 0))
    ctx.add("Fabric", rbox(IN_W + 0.36, 0.08, IN_L + 0.36, r=0.02, m=1, n=(10, 1, 20)), T(0, BED_Y - 0.04, 0))
    # rails (WoodDark): segments between the pockets, rounded outer edge
    seg = []
    for sx in (-1, 1):  # long rails, two pieces each
        for z0, z1 in ((-hl + 0.45, -0.3), (0.3, hl - 0.45)):
            seg.append(((sx * (hw - 0.22), (z0 + z1) / 2), (0.44, z1 - z0)))
    for sz in (-1, 1):
        seg.append(((0.0, sz * (hl - 0.22)), (PT_W - 0.9, 0.44)))
    for (cx, cz), (sx_, sz_) in seg:
        ctx.add("WoodDark", rbox(sx_, 0.42, sz_, r=0.06, m=1, n=(1, 1, 4)), T(cx, RAIL_TOP - 0.21, cz))
    # corner and side pocket castings (black), the pocket mouths (dark discs over the cloth)
    for px, pz in POCKETS:
        side = abs(pz) < 0.01
        ox = math.copysign(0.22 if side else 0.2, px)
        oz = 0.0 if side else math.copysign(0.2, pz)
        ctx.add("Black", cyl(0.26, 0.42, segs=14, bevel=0.03), T(px + ox * 0.6, RAIL_TOP - 0.21, pz + oz))
        ctx.add("Black", cyl(0.2, 0.03, segs=12), T(px, BED_Y + 0.006, pz))
        ctx.add("Rubber", torus(0.2, 0.035, segs=12, sides=4, y=BED_Y + 0.03), T(px, 0, pz))
    # cushions: a nosed section swept along each rail's inside between the pockets
    sec = [(0.0, BED_Y - 0.005), (0.0, RAIL_TOP - 0.035), (-0.06, RAIL_TOP - 0.02), (-0.16, BED_Y + 0.06), (-0.12, BED_Y)]
    for sx in (-1, 1):
        for z0, z1 in ((-IN_L / 2 + 0.3, -0.28), (0.28, IN_L / 2 - 0.3)):
            x_in = sx * (IN_W / 2 + 0.16)
            ring = lambda z: [(x_in + sx * -u, y, z) for u, y in sec]  # noqa: E731
            ctx.add("Fabric", loft([ring(lerp(z0, z1, k / 6)) for k in range(7)], cap_start=True, cap_end=True))
    for sz in (-1, 1):
        z_in = sz * (IN_L / 2 + 0.16)
        x0, x1 = -IN_W / 2 + 0.3, IN_W / 2 - 0.3
        ring = lambda x: [(x, y, z_in + sz * -u) for u, y in sec]  # noqa: E731
        ctx.add("Fabric", loft([ring(lerp(x0, x1, k / 4)) for k in range(5)], cap_start=True, cap_end=True))
    # diamond sights on the rail tops
    for sx in (-1, 1):
        for z in (-2.48, -1.65, -0.83, 0.83, 1.65, 2.48):
            ctx.add("Paper", box(0.07, 0.03, 0.07), T(sx * (hw - 0.2), RAIL_TOP + 0.005, z) @ R(0, 45, 0))
    for sz in (-1, 1):
        for x in (-0.8, 0.0, 0.8):
            ctx.add("Paper", box(0.07, 0.03, 0.07), T(x, RAIL_TOP + 0.005, sz * (hl - 0.2)) @ R(0, 45, 0))
    # coin slide on the foot end (-Z): chrome plate, the slide with coin slots, the return
    fz = -hl + 0.25 - 0.02
    ctx.add("Chrome", rbox(1.3, 0.55, 0.06, r=0.02, m=2), T(0, 1.75, fz))
    ctx.add("Chrome", rbox(0.9, 0.16, 0.22, r=0.03, m=2), T(0, 1.75, fz - 0.12))
    for k in range(3):
        ctx.add("Black", box(0.13, 0.03, 0.02), T(-0.25 + k * 0.25, 1.84, fz - 0.15))
    ctx.add("Chrome", rbox(0.2, 0.12, 0.1, r=0.03, m=1), T(0.5, 1.75, fz - 0.08))  # (the slide's knob)
    ctx.add("Black", box(1.0, 0.36, 0.06), T(0, 0.95, fz + 0.005))  # ball-return window (dark)
    ctx.add("Chrome", rbox(1.12, 0.48, 0.03, r=0.02, m=1), T(0, 0.95, fz - 0.03) @ T(0, 0, 0))
    ctx.add("Black", box(0.96, 0.32, 0.05), T(0, 0.95, fz - 0.035))
    # (balls waiting in the return)
    for k in range(3):
        ctx.add("Reflective", sphere(0.12, 12, 8), T(-0.3 + k * 0.26, 0.9, fz - 0.03))

    def cloth(p):
        x, y, z = p.co
        if y < BED_Y - 0.05:
            return 0.7
        bald = 0.22 * math.exp(-((x / 0.5) ** 2 + ((z - 1.65) / 0.6) ** 2)) + 0.1 * math.exp(-((x / 0.4) ** 2 + ((z + 1.65) / 0.4) ** 2))
        rim = 0.12 * smoothstep(1.35, 1.6, abs(x)) + 0.1 * smoothstep(3.0, 3.3, abs(z))
        chalk = smoothstep(0.75, 0.9, noise.fbm((x * 3, 0, z * 3), 3) * 0.5 + 0.5)
        g = 0.85 + 0.1 * noise.fbm((x * 8, 0, z * 8), 2)
        burn = 1 - 0.6 * smoothstep(0.08, 0.0, math.hypot(x + 0.9, z - 2.4))
        c = (g * (1 + bald) * (1 - rim) * burn, g * (1 + bald * 0.8) * (1 - rim) * burn, g * (1 + bald * 0.6) * (1 - rim) * burn)
        return (c[0] * (1 - 0.25 * chalk), c[1] * (1 - 0.05 * chalk), c[2] * (1 + 0.6 * chalk))

    ctx.wear("Fabric", mul(cloth, cavity(0.3)))

    def rails(p):
        x, y, z = p.co
        rub = smoothstep(RAIL_TOP - 0.05, RAIL_TOP, y) * smoothstep(0.6, 0.9, noise.fbm(p.co * 3, 2) * 0.5 + 0.5)
        return 0.8 + 0.3 * rub

    ctx.wear("WoodDark", mul(varnish_wear(noise, dirt=0.25, dirt_h=0.6), rails))
    ctx.wear("Wood", mul(varnish_wear(noise, dirt=0.35, dirt_h=0.9, grain=0.05), scuffs(noise, 0.25, 3.0, 0.5),
                         lambda p: (0.55, 0.47, 0.4)))
    ctx.wear("Black", mul(ground_dirt(0.3, 0.2, noise), edge_wear(0.5)))
    ctx.wear("Chrome", mul(metal_wear(noise, 0.4, (0.7, 0.7, 0.68), 6.0), scuffs(noise, 0.25, 9.0, 0.5)))
    ctx.wear("Reflective", lambda p: (1.0, 0.95, 0.85))


def pool_cue(ctx):
    """A pool cue: dark two-piece butt with a black linen wrap, chrome joint ring, maple shaft
    tapering to a white ferrule and a blue-chalked tip. Origin: the butt's end on the floor,
    the cue along +Y (data Cue 4.4 long)."""
    ctx.budget = 900
    L = 4.4
    noise = ctx.noise
    butt = [(0, 0.0), (0.06, 0.0), (0.068, 0.02), (0.07, 0.08), (0.066, 0.3), (0.06, 1.35), (0.054, 1.98), (0, 1.98)]
    ctx.add("WoodDark", lathe(butt, segs=12))
    ctx.add("Black", lathe([(0.067, 0.32), (0.071, 0.33), (0.066, 1.28), (0.06, 1.29), (0.06, 1.3), (0.066, 0.32)], segs=12))  # wrap
    ctx.add("Chrome", lathe([(0.053, 1.97), (0.058, 1.98), (0.058, 2.04), (0.05, 2.05), (0.048, 2.0)], segs=12))
    shaft = [(0.0, 2.0), (0.05, 2.0), (0.05, 2.06), (0.043, 2.6), (0.034, 3.6), (0.031, L - 0.08), (0, L - 0.08)]
    ctx.add("Wood", lathe(shaft, segs=12))
    ctx.add("Paper", lathe([(0, L - 0.09), (0.031, L - 0.09), (0.031, L - 0.03), (0, L - 0.03)], segs=12))  # ferrule
    ctx.add("Leather", lathe([(0, L - 0.035), (0.03, L - 0.035), (0.03, L - 0.01), (0.022, L), (0, L)], segs=12))  # tip
    ctx.wear("Wood", lambda p: (1.0, 0.92 - 0.1 * smoothstep(3.6, 4.3, p.co.y), 0.78 - 0.12 * smoothstep(3.6, 4.3, p.co.y)))
    ctx.wear("Leather", lambda p: (0.7, 0.9, 1.0))  # (blue chalk)
    ctx.wear("WoodDark", mul(edge_wear(0.2), lambda p: 0.9 + 0.1 * noise.fbm(p.co * 9, 2)))


BALLS = [  # (colour multiplier on the Reflective layer, stripe?)
    ((1.0, 0.85, 0.3), False), ((0.35, 0.42, 1.0), False), ((1.0, 0.3, 0.28), False), ((0.6, 0.35, 0.85), False),
    ((1.0, 0.55, 0.25), False), ((0.35, 0.75, 0.4), False), ((0.65, 0.3, 0.3), False), (None, False),
    ((1.0, 0.85, 0.3), True), ((0.35, 0.42, 1.0), True), ((1.0, 0.3, 0.28), True), ((0.6, 0.35, 0.85), True),
    ((1.0, 0.55, 0.25), True), ((0.35, 0.75, 0.4), True), ((0.65, 0.3, 0.3), True),
]
BALL_R = 0.12


def pool_ball_set(ctx):
    """A game in progress on the cloth: the cue ball, the black 8 and eleven coloured balls
    (solids and stripes, a white spot each) scattered as after a few shots, two by pockets;
    the plastic triangle lying at the foot, a cube of blue chalk. Decoration (no physics).
    Origin: on the cloth, at the table's centre."""
    ctx.budget = 4200
    ctx.smooth_angle = 60
    rng = ctx.rng
    spots = [(0.2, 1.7), (-0.9, 2.6), (1.1, 1.2), (-0.4, 0.6), (0.7, -0.2), (-1.2, -0.8), (0.95, -1.5), (-0.3, -2.1),
             (1.35, 3.0), (-1.38, 0.05), (0.15, -0.9), (-0.8, 1.6), (0.5, 2.5)]
    which = [7, 0, 9, 2, 11, 4, 13, 5, 1, 12, 8, 3]  # (the 8 first; the rest pocketed)
    balls = []
    cue = (-0.25, -2.65)
    centres = [(cue, None, False)]
    for (x, z), b in zip(spots, which):
        centres.append(((x + rng.uniform(-0.05, 0.05), z + rng.uniform(-0.05, 0.05)), BALLS[b][0], BALLS[b][1]))
    for (x, z), col, stripe in centres:
        yaw, tilt = rng.uniform(0, 360), rng.uniform(-60, 60)
        m = T(x, BALL_R, z) @ R(tilt, yaw, 0)
        layer = "Black" if col is None and (x, z) != cue else "Reflective"
        ctx.add(layer, sphere(BALL_R, 14, 10), m)
        if layer == "Black":
            ctx.add("Reflective", lathe([(0, BALL_R + 0.002), (0.045, BALL_R - 0.006), (0.05, BALL_R - 0.03), (0, BALL_R - 0.03)], segs=12), m)
        balls.append((Vector((x, BALL_R, z)), m.to_3x3().inverted(), col, stripe, (x, z) == cue))
    # the triangle (black plastic) lying at the foot end, chalk on the corner of the cloth
    tri = [(math.cos(math.radians(a)) * 0.62, math.sin(math.radians(a)) * 0.62) for a in (90, 210, 330)]
    for k in range(3):
        a, b = tri[k], tri[(k + 1) % 3]
        ctx.add("PlasticDark", tube([(a[0], 0.04, a[1] - 2.9), (b[0], 0.04, b[1] - 2.9)], 0.035, segs=6))
    ctx.add("Paper", box(0.1, 0.09, 0.1, bevel=0.012), T(1.45, 0.045, -3.05) @ R(0, 23, 0))

    def ball(p):
        if abs(p.co.y) < 0.01 and p.co.y < 0.06:
            pass
        best = min(balls, key=lambda b: (p.co - b[0]).length)
        c, inv, col, stripe, is_cue = best
        if (p.co - c).length > BALL_R * 1.4:
            if abs(p.co.x - 1.45) < 0.1 and p.co.y < 0.1:
                return (0.45, 0.6, 1.0)  # chalk
            return (0.95, 0.95, 0.9)
        if is_cue:
            return (1.0, 0.98, 0.92)
        if col is None:
            return (0.98, 0.98, 0.94)  # (the 8's spot)
        q = inv @ (p.co - c)
        spot = math.hypot(q.x, q.z) < 0.045 and q.y > 0
        if spot:
            return (1.0, 0.98, 0.92)
        if stripe and abs(q.y) > BALL_R * 0.55:
            return (1.0, 0.98, 0.92)
        return col

    ctx.wear("Reflective", ball)
    ctx.wear("Black", edge_wear(0.3))
    ctx.wear("Paper", lambda p: (0.45, 0.6, 1.0))


def _chain(ctx, layer, top, bottom, link=0.4, r=0.02):
    """A hanging chain of oval links (alternating 90 degrees) from top to bottom (on Y)."""
    n = max(2, int(abs(top[1] - bottom[1]) / link))
    for k in range(n):
        y = top[1] - (k + 0.5) * (top[1] - bottom[1]) / n
        ring = [(0.07 * math.cos(TAU * j / 8), (link * 0.55) * math.sin(TAU * j / 8), 0.0) for j in range(8)]
        ctx.add(layer, tube(ring, r, segs=4, closed=True), T(top[0], y, top[2]) @ R(0, 90 * (k % 2), 0))


def _enamel_shade(r, h, t=0.03, dent=None):
    """A spun enamel dome shade (outside, rim, inside), its top at y = 0, open below."""
    out = [(0.06, 0.0), (0.18 * r / 0.6, -0.04), (0.45 * r / 0.6, -0.16 * h / 0.45), (0.58 * r / 0.6, -0.34 * h / 0.45), (r, -h)]
    inn = [(r - t, -h + 0.005), (0.56 * r / 0.6 - t, -0.34 * h / 0.45), (0.43 * r / 0.6 - t, -0.16 * h / 0.45), (0.17 * r / 0.6, -0.04 - t), (0.06, -t)]
    prof = out + [(r + 0.01, -h - 0.015)] + inn
    return lathe(prof, segs=32, radius_fn=dent)


def pool_lamp_billard(ctx):
    """A three-shade billiard lamp: a dark wood bar with brass ends hung on two chains from
    ceiling plates, three green enamel domes (white inside) with their bulbs (Glow). Origin: on
    the ceiling over the table's centre; the bar 5.0 below it."""
    ctx.budget = 6000
    ctx.smooth_angle = 40
    ctx.tint("MetalPainted", (34, 70, 46))
    noise = ctx.noise
    bar_y = -5.0
    ctx.add("WoodDark", rbox(0.36, 0.3, 5.2, r=0.06, m=2, n=(1, 1, 8)), T(0, bar_y, 0))
    for sz in (-1, 1):
        ctx.add("Metal", rbox(0.4, 0.34, 0.12, r=0.04, m=2), T(0, bar_y, sz * 2.64))
    for z in (-2.0, 2.0):
        ctx.add("Metal", cyl(0.25, 0.06, segs=16, bevel=0.015), T(0, -0.03, z))  # ceiling plate
        ctx.add("Metal", torus(0.06, 0.018, segs=8, sides=4, y=bar_y + 0.18), T(0, 0, z))
        _chain(ctx, "Metal", (0, -0.06, z), (0, bar_y + 0.2, z))
    for z in (-1.75, 0.0, 1.75):
        ctx.add("Metal", cyl(0.05, 0.25, segs=8), T(0, bar_y - 0.25, z))
        ctx.add("MetalPainted", _enamel_shade(0.6, 0.45), T(0, bar_y - 0.36, z))
        ctx.add("Glow", sphere(0.14, 12, 8), T(0, bar_y - 0.62, z))
    ctx.mark("Light", (0, bar_y - 0.85, 0))
    ctx.wear("MetalPainted", mul(lambda p: 1.0 if p.normal.y > -0.2 else 1.0, scuffs(noise, 0.3, 8.0, 0.55), nicotine(noise, -5.6, -5.2, 0.6)))
    ctx.wear("WoodDark", varnish_wear(noise, dirt=0.0))
    ctx.wear("Metal", metal_wear(noise, 0.5, (0.6, 0.58, 0.55)))


# ==============================================================================================
# JUKEBOX. Real reference: a Wurlitzer 1015 (1946) style bubbler: 1.5 m tall, 0.84 m wide,
# 0.6 m deep; walnut cabinet, a semicircular arch of lit bubble tubes over the top, lit tubes
# down both front pilasters, a domed window over the record mechanism, the title-strip panel
# with selector buttons, a chrome speaker grille low on the front, coin entry on the side.
# Wear: the walnut's varnish crazed and scuffed at kick height, chrome pitted, the plastic
# yellowed. Data: Jukebox 2 x 5 x 3 (y 1.9..6.9, facing -X), JukeboxArch (half cylinder r 1.5
# at y 6.9), JukeboxFront (Neon, CityNeon, Flicker random, a PointLight). Origin: centre on the
# floor, front -Z (the overlay turns it to face -X).
# ==============================================================================================
JB_W, JB_D, JB_H = 3.0, 2.0, 5.0  # width, depth, body height (the arch's centre)


def jukebox(ctx):
    """A bubbler jukebox: walnut cabinet, an arch of lit tubes over the top and down the front
    pilasters (Glow: the bar's magenta neon flickers through them), domed record window,
    title-strip panel with selector buttons, chrome speaker grille, coin entry."""
    ctx.budget = 7800
    ctx.smooth_angle = 40
    ctx.tint("Plastic", (226, 206, 160))  # (the yellowed cream plastic)
    noise = ctx.noise
    hw, hd = JB_W / 2, JB_D / 2
    # cabinet sides (walnut), a plinth, the back
    side = [(-hd, 0.0), (hd, 0.0), (hd, JB_H)] + [(hd - (JB_D) * k / 8, JB_H) for k in range(1, 8)] + [(-hd + 0.25, JB_H), (-hd, JB_H - 0.3)]
    for sx in (-1, 1):
        ctx.add("WoodDark", ext_x([(z, y) for z, y in side], sx * hw - 0.22 * (sx > 0), sx * hw + 0.22 * (sx < 0) * 0 - (0.22 if sx < 0 else 0) * -1, 1))
    ctx.add("WoodDark", box(JB_W - 0.4, JB_H - 0.2, JB_D - 0.3), T(0, (JB_H - 0.2) / 2 + 0.1, 0.1))
    ctx.add("Black", box(JB_W - 0.1, 0.3, JB_D - 0.2), T(0, 0.15, 0))
    # arch: a half cylinder along Z (depth), walnut with a lit tube band on its front face
    arch_c = JB_H
    ring_out = [(math.cos(math.radians(a)) * 1.5, arch_c + math.sin(math.radians(a)) * 1.5) for a in range(0, 181, 10)]
    sec = ring_out + [(-1.2, arch_c)] + [(math.cos(math.radians(a)) * 1.2, arch_c + math.sin(math.radians(a)) * 1.2) for a in range(180, -1, -10)]
    ctx.add("WoodDark", ext_z(sec, -hd + 0.35, hd, 1))
    # the lit tubes: the arch's front band and the two pilasters
    band = [(math.cos(math.radians(a)) * 1.35, arch_c + math.sin(math.radians(a)) * 1.35, -hd + 0.22) for a in range(0, 181, 8)]
    ctx.add("Glow", tube(band, 0.13, segs=10))
    for sx in (-1, 1):
        ctx.add("Glow", tube([(sx * 1.35, 0.5, -hd + 0.22), (sx * 1.35, arch_c, -hd + 0.22)], 0.13, segs=10))
        # bubble tube caps (chrome) and the chrome frames round the tubes
        ctx.add("Chrome", cyl(0.17, 0.12, segs=12), T(sx * 1.35, 0.44, -hd + 0.22))
        ctx.add("Chrome", tube([(sx * 1.52, 0.4, -hd + 0.2), (sx * 1.52, arch_c, -hd + 0.2)], 0.035, segs=6))
    ctx.add("Chrome", tube([(math.cos(math.radians(a)) * 1.52, arch_c + math.sin(math.radians(a)) * 1.52, -hd + 0.2) for a in range(0, 181, 10)], 0.035, segs=6))
    # inside the arch: the record dome window (glass) with the mechanism behind it
    ctx.add("Black", box(2.2, 1.1, 0.1), T(0, arch_c + 0.4, -hd + 0.55))
    ctx.add("Black", cyl(0.6, 0.04, segs=24), T(0, arch_c + 0.45, -hd + 0.48) @ R(90))  # a record
    ctx.add("Chrome", cyl(0.08, 0.06, segs=10), T(0, arch_c + 0.45, -hd + 0.44) @ R(90))
    dome = lathe([(0, 0.0), (1.05, 0.0), (1.0, 0.12), (0.7, 0.3), (0, 0.36)], segs=24, radius_fn=lambda a, r, y: r * (0.62 + 0.38 * abs(math.cos(a))))
    ctx.add("Glass", dome, T(0, arch_c + 0.4, -hd + 0.38) @ R(90))
    # front: title-strip panel (slanted), selector buttons, cream plastic surrounds
    ctx.add("Plastic", rbox(2.4, 1.0, 0.25, r=0.06, m=2), T(0, 3.85, -hd + 0.32) @ R(20))
    for row in range(2):
        for col in range(5):
            ctx.add("Paper", box(0.38, 0.14, 0.03), T(-0.84 + col * 0.42, 4.0 - row * 0.3, -hd + 0.18) @ R(20))
    for col in range(10):
        ctx.add("Chrome", rbox(0.15, 0.1, 0.12, r=0.025, m=1), T(-0.9 + col * 0.2, 3.25, -hd + 0.2))
    ctx.add("Plastic", rbox(2.5, 0.35, 0.3, r=0.05, m=2), T(0, 3.25, -hd + 0.3))
    # the speaker grille: chrome bars over black cloth, cream frame
    ctx.add("FabricDark", box(2.2, 1.7, 0.06), T(0, 1.45, -hd + 0.33))
    ctx.add("Plastic", rbox(2.5, 2.1, 0.1, r=0.05, m=2), T(0, 1.45, -hd + 0.38))
    for k in range(9):
        x = -0.96 + k * 0.24
        ctx.add("Chrome", tube([(x, 0.62, -hd + 0.27), (x, 2.28, -hd + 0.27)], 0.03, segs=6))
    ctx.add("Chrome", tube([(-1.08, 1.45, -hd + 0.25), (1.08, 1.45, -hd + 0.25)], 0.035, segs=6))
    # coin entry on the right side
    ctx.add("Chrome", rbox(0.06, 0.5, 0.36, r=0.02, m=1), T(hw + 0.01, 3.6, -0.3))
    ctx.add("Black", box(0.03, 0.18, 0.04), T(hw + 0.035, 3.7, -0.3))
    ctx.mark("Light", (0, 3.6, -hd - 0.5))

    def walnut(p):
        x, y, z = p.co
        kick = 1 - 0.35 * smoothstep(0.6, 0.85, noise.fbm((x * 3, y * 4, z * 3), 3) * 0.5 + 0.5) * (1 - smoothstep(0.3, 1.2, y))
        craze = 1 - 0.2 * smoothstep(0.86, 0.95, noise.ridge((x * 8, y * 8, z * 8)))
        return kick * craze

    ctx.wear("WoodDark", mul(varnish_wear(noise, dirt=0.3, dirt_h=0.7), walnut, lambda p: (1.05, 0.85, 0.7)))
    ctx.wear("Plastic", mul(cavity(0.4), nicotine(noise, 2.0, 5.0, 0.6), scuffs(noise, 0.2, 6.0)))
    ctx.wear("Chrome", mul(metal_wear(noise, 0.45, (0.72, 0.7, 0.66), 6.0), ground_dirt(0.6, 0.3, noise)))
    ctx.wear("Paper", lambda p: (1.0, 0.94 - 0.15 * (p.co.x > 0), 0.78))


# ==============================================================================================
# CIGARETTE MACHINE. Real reference: a 1970s-80s pub cigarette vending machine (National /
# Rowe): 1.6-1.7 m tall, 70 cm wide, a lit header, a glass display of the packs over a row of
# chrome pull-knobs (one per brand, a small price window above each), the coin slot and the
# coin-return button on the right, the delivery tray at the bottom; painted steel cabinet with
# chrome trims. Wear: the paint chipped and rusty low, the knobs' chrome worn to brass, the
# display window nicotine-yellow, a dent where it gets kicked. No brand text. Data:
# CigaretteMachine 2.4 x 5.3 x 3 (facing -X), MachineFront (Neon, untagged). Origin: centre on
# the floor, front -Z (the overlay turns it to face -X).
# ==============================================================================================
def cigarette_machine(ctx):
    """A pub cigarette machine: painted steel cabinet with a lit header, a glass display of 16
    packs, a row of eight chrome pull-knobs under price windows, coin slot and return button,
    the delivery tray; chipped, nicotine-yellowed, kicked."""
    ctx.budget = 5600
    ctx.smooth_angle = 40
    ctx.tint("MetalPainted", (82, 64, 46))  # (a brown baked enamel)
    noise = ctx.noise
    rng = ctx.rng
    W, D, H = 3.0, 2.4, 5.3
    hw, hd = W / 2, D / 2
    body = rbox(W, H - 0.3, D, r=0.08, m=2, n=(3, 6, 3))
    # (a kick dent low on the front)
    for v in body.verts:
        if v.co.z < -hd + 0.05:
            d = math.hypot(v.co.x - 0.6, v.co.y + (H - 0.3) / 2 - 0.7)
            v.co.z += 0.06 * smoothstep(0.5, 0.0, d)
    ctx.add("MetalPainted", body, T(0, 0.3 + (H - 0.3) / 2, 0))
    for sx in (-1, 1):
        for sz in (-1, 1):
            ctx.add("Black", cyl(0.12, 0.3, segs=10), T(sx * (hw - 0.25), 0.15, sz * (hd - 0.25)))
    fz = -hd - 0.01
    # header: lit panel in a chrome frame
    ctx.add("Chrome", rbox(W - 0.2, 0.75, 0.08, r=0.03, m=2), T(0, H - 0.5, fz))
    ctx.add("Glow", box(W - 0.4, 0.55, 0.06), T(0, H - 0.5, fz - 0.03))
    # display: the packs on shelves behind a glass, a chrome frame
    ctx.add("Black", box(W - 0.4, 1.7, 0.08), T(0, 3.55, fz + 0.06))
    packs = []
    for row in range(2):
        for col in range(8):
            x = -1.1 + col * 0.315
            y = 2.95 + row * 0.8
            ctx.add("Paper", box(0.24, 0.5, 0.12, bevel=0.01), T(x, y + 0.25, fz - 0.03) @ R(0, rng.uniform(-6, 6), 0))
            packs.append((x, y))
    ctx.add("Chrome", sweep([(-hw + 0.2, 2.7, fz - 0.12), (hw - 0.2, 2.7, fz - 0.12), (hw - 0.2, 4.4, fz - 0.12), (-hw + 0.2, 4.4, fz - 0.12)],
                            [(-0.04, -0.04), (0.04, -0.04), (0.04, 0.04), (-0.04, 0.04)], side=(0, 0, 1), closed=True))
    # the knob row: price windows and pull-knobs
    ctx.add("Chrome", rbox(W - 0.3, 0.7, 0.06, r=0.02, m=2), T(0, 2.25, fz))
    for col in range(8):
        x = -1.1 + col * 0.315
        ctx.add("Paper", box(0.2, 0.12, 0.02), T(x, 2.45, fz - 0.035))
        ctx.add("Chrome", cyl(0.05, 0.22, segs=10), T(x, 2.12, fz - 0.12) @ R(90))
        ctx.add("Chrome", lathe([(0, 0), (0.1, 0.0), (0.11, 0.04), (0.08, 0.08), (0, 0.09)], segs=12), T(x, 2.12, fz - 0.22) @ R(-90))
    # coin slot, coin return button (right), tray
    ctx.add("Chrome", rbox(0.5, 0.9, 0.06, r=0.03, m=2), T(hw - 0.45, 1.35, fz))
    ctx.add("Black", box(0.05, 0.25, 0.03), T(hw - 0.45, 1.55, fz - 0.035))
    ctx.add("Chrome", cyl(0.08, 0.06, segs=12), T(hw - 0.45, 1.15, fz - 0.05) @ R(90))
    ctx.add("Black", box(1.3, 0.45, 0.25), T(-0.4, 0.85, fz + 0.1))  # delivery opening
    ctx.add("Chrome", sweep([(-1.1, 0.6, fz - 0.03), (0.3, 0.6, fz - 0.03), (0.3, 1.1, fz - 0.03), (-1.1, 1.1, fz - 0.03)],
                            [(-0.03, -0.03), (0.03, -0.03), (0.03, 0.03), (-0.03, 0.03)], side=(0, 0, 1), closed=True))
    ctx.mark("Light", (0, H - 0.5, fz - 0.4))
    cols = [(1.0, 0.35, 0.3), (1.0, 1.0, 0.95), (0.4, 0.5, 1.0), (1.0, 0.85, 0.3), (0.35, 0.7, 0.4), (0.9, 0.9, 0.9), (1.0, 0.55, 0.3), (0.5, 0.5, 0.55)]

    def pack(p):
        x, y, z = p.co
        if y > 2.7 and y < 4.5:
            col = min(range(8), key=lambda k: abs(x - (-1.1 + k * 0.315)))
            c = cols[col]
            band = 0.8 if (y % 0.8) > 0.55 else 1.0
            return tuple(v * band for v in c)
        return (0.95, 0.9, 0.75)

    ctx.wear("Paper", pack)

    def paint(p):
        x, y, z = p.co
        chip = smoothstep(0.65, 0.8, noise.fbm(p.co * 5, 3) * 0.5 + 0.5) * smoothstep(0.1, 0.5, p.convex + 0.15)
        rust = (1 - smoothstep(0.3, 1.2, y)) * smoothstep(0.4, 0.7, noise.fbm(p.co * 3, 2) * 0.5 + 0.5)
        g = 1 - 0.3 * (1 - smoothstep(0.0, 1.0, y))
        return (g * (1 - 0.3 * chip) * (1 - 0.2 * rust), g * (1 - 0.35 * chip) * (1 - 0.35 * rust), g * (1 - 0.4 * chip) * (1 - 0.5 * rust))

    ctx.wear("MetalPainted", mul(paint, cavity(0.3), nicotine(noise, 2.0, 5.3, 0.3)))
    ctx.wear("Chrome", mul(metal_wear(noise, 0.5, (0.85, 0.72, 0.5), 7.0), ground_dirt(0.8, 0.3, noise)))
    ctx.wear("Glow", lambda p: (1.0, 0.92, 0.78))


# ==============================================================================================
# DARTBOARD. Real reference: a bristle (sisal) board, 451 mm (1.6 studs) across, 20 segments
# alternating black and cream, red / green doubles and trebles, a wire spider, the black number
# ring; hung (centre 1.73 m) in a wooden cabinet whose open doors are chalkboards for the score.
# Wear: the 20 and the treble 20 torn by thousands of darts (pale fluff), wall round the
# cabinet peppered, the chalkboards smeared grey with old scores. Data: Dartboard cylinder 1.6 x
# 0.2 on the partition (x 62.9, y 7.2), DartRing x 2. Origin: on the wall face at the board's
# centre, -Z out of the wall.
# ==============================================================================================
DB_R = 0.6  # the doubles' outer edge (the number ring goes on to 0.8)


def _sector(r0, r1, a0, a1, z0, z1, n=3):
    pts = [(r0 * math.cos(lerp(a0, a1, k / n)), r0 * math.sin(lerp(a0, a1, k / n))) for k in range(n + 1)]
    pts += [(r1 * math.cos(lerp(a1, a0, k / n)), r1 * math.sin(lerp(a1, a0, k / n))) for k in range(n + 1)]
    return prism(pts, z0, z1)


def dartboard(ctx):
    """A bristle dartboard in a chalkboard cabinet with its doors open: 20 black / cream
    segments, red and green doubles and trebles, a wire spider, the black number ring, three
    darts in the treble 20, scores chalked on the doors."""
    ctx.budget = 6000
    ctx.smooth_angle = 30
    noise = ctx.noise
    rng = ctx.rng
    # cabinet: back board, frame, two open doors (hinged on the sides, 110 degrees open)
    CWd, CHt, CD = 2.3, 2.4, 0.32
    ctx.add("WoodDark", box(CWd, CHt, 0.05), T(0, 0, -0.025))
    for sx in (-1, 1):
        ctx.add("WoodDark", rbox(0.1, CHt, CD, r=0.02, m=1), T(sx * (CWd / 2 - 0.05), 0, -CD / 2))
    for sy in (-1, 1):
        ctx.add("WoodDark", rbox(CWd, 0.1, CD, r=0.02, m=1), T(0, sy * (CHt / 2 - 0.05), -CD / 2))
    for sx in (-1, 1):
        hinge = T(sx * CWd / 2, 0, -CD)
        door = hinge @ R(0, -sx * 105, 0) @ T(-sx * CWd / 4, 0, 0)
        ctx.add("WoodDark", rbox(CWd / 2, CHt, 0.06, r=0.015, m=1), door)
        ctx.add("Black", box(CWd / 2 - 0.2, CHt - 0.3, 0.02), door @ T(0, 0, -0.035))
        # chalk: rows of score strokes (thin raised strips)
        for row in range(7):
            for k in range(rng.randint(1, 3)):
                w = rng.uniform(0.08, 0.3)
                ctx.add("Paper", box(w, 0.025, 0.01), door @ T(sx * rng.uniform(-0.25, 0.25) * 0 + (-0.32 + k * 0.32) * (1 if sx > 0 else 1), 0.8 - row * 0.25, -0.05) @ R(0, 0, rng.uniform(-8, 8)))
        ctx.add("Paper", box(0.012, CHt - 0.5, 0.01), door @ T(0, 0, -0.05))  # (the column line)
    # the board: the number ring, sectors and rings, the bull
    zf, zb = -0.28, -0.05  # board front / back (the city's DartRings stay inside it)
    ctx.add("Black", lathe([(0, zb), (0.8, zb), (0.8, zf + 0.04), (0.77, zf + 0.01), (0, zf + 0.01)], segs=40), R(90))
    rings = [(0.57, DB_R, "d"), (0.38, 0.57, "s"), (0.355, 0.38, "t"), (0.065, 0.355, "s")]
    for k in range(20):
        a0 = math.radians(90 - 9 + 18 * k)
        a1 = a0 + math.radians(18)
        dark = k % 2 == 0
        for r0, r1, kind in rings:
            layer = ("Black" if dark else "Paper") if kind == "s" else "Paper"
            ctx.add(layer, _sector(r0, r1, a0, a1, zf - 0.0, zf + 0.06, n=2))
    ctx.add("Paper", cyl(0.065, 0.06, segs=16), T(0, 0, zf + 0.03) @ R(90))
    ctx.add("Paper", cyl(0.028, 0.07, segs=12), T(0, 0, zf + 0.03) @ R(90))
    # spider: ring wires and radial wires, proud of the face
    for r in (DB_R, 0.57, 0.38, 0.355, 0.065, 0.028):
        ctx.add("Metal", torus(r, 0.006, segs=40 if r > 0.1 else 16, sides=4), T(0, 0, zf - 0.004) @ R(90))
    for k in range(20):
        a = math.radians(90 - 9 + 18 * k)
        ctx.add("Metal", tube([(0.065 * math.cos(a), 0.065 * math.sin(a), zf - 0.004), (DB_R * math.cos(a), DB_R * math.sin(a), zf - 0.004)], 0.006, segs=4))
    # numbers: small raised wire marks round the ring (no legible text at this size)
    for k in range(20):
        a = math.radians(90 + 18 * k)
        ctx.add("Metal", box(0.07, 0.04, 0.012), T(0.69 * math.cos(a), 0.69 * math.sin(a), zf + 0.006) @ R(0, 0, math.degrees(a) - 90))
    # three darts in the treble 20 / the 20 (top)
    for k, (x, y, rx, ry) in enumerate(((-0.03, 0.37, 8, -6), (0.05, 0.42, 4, 7), (-0.08, 0.5, 12, 3))):
        m = T(x, y, zf) @ R(-rx, ry, 0)
        ctx.add("Chrome", lathe([(0, 0.0), (0.008, 0.02), (0.008, 0.1), (0.028, 0.12), (0.03, 0.26), (0.02, 0.29), (0, 0.29)], segs=8), m @ R(-90))
        ctx.add("Black", cyl(0.012, 0.18, segs=6), m @ T(0, 0, -0.38))
        for j in range(4):
            ctx.add("Plastic", box(0.004, 0.09, 0.14), m @ T(0, 0, -0.44) @ R(0, 0, 45 + 90 * j) @ T(0, 0.045, 0))
    ctx.tint("Plastic", (40, 90, 160))

    def segc(p):
        x, y, z = p.co
        r = math.hypot(x, y)
        if r > DB_R + 0.01 or r < 0.07:
            if r < 0.03:
                return (1.0, 0.3, 0.28)  # bull
            if r < 0.07:
                return (0.35, 0.65, 0.38)
            return (0.85, 0.8, 0.7)  # (chalk, on the doors)
        a = (math.degrees(math.atan2(y, x)) - 81) % 360
        k = int(a // 18)
        dark = k % 2 == 0
        if 0.565 <= r or 0.352 <= r <= 0.382:
            return (1.0, 0.3, 0.28) if dark else (0.35, 0.65, 0.38)
        top = smoothstep(0.3, 0.05, math.hypot(x, y - 0.42))
        return (0.95 - 0.1 * top, 0.88 - 0.1 * top, 0.72 - 0.05 * top)

    ctx.wear("Paper", segc)
    ctx.wear("Black", lambda p: 1.0 + 0.6 * smoothstep(0.25, 0.0, math.hypot(p.co.x, p.co.y - 0.42)) if abs(p.co.z) > 0.1 else 1.0)
    ctx.wear("WoodDark", mul(varnish_wear(noise, dirt=0.0), scuffs(noise, 0.25, 5.0, 0.5)))


# ==============================================================================================
# PENDANT. Real reference: a green enamel "school-house" pendant over a bar: a 30-35 cm spun
# steel dome, green outside, white inside, a cloth-braided flex from a ceiling rose, a bare
# squirrel-cage bulb. Wear: the enamel chipped to black at the rim, nicotine on the top.
# Data: Pendant (lit ball 0.7, CityShopLight) at y 12.2 on a Cord from the ceiling (15.6).
# Origin: on the ceiling; the bulb 3.4 below it.
# ==============================================================================================
def _pendant(ctx, dented):
    ctx.budget = 1800
    ctx.smooth_angle = 40
    ctx.tint("MetalPainted", (36, 66, 46))
    noise = ctx.noise
    ctx.add("Paper", lathe([(0, 0.0), (0.22, 0.0), (0.2, -0.06), (0.12, -0.1), (0.04, -0.12), (0, -0.12)], segs=20))
    ctx.add("FabricDark", tube([(0, -0.1, 0), (0.01, -1.5, 0.005), (0, -2.85, 0)], 0.035, segs=6))
    ctx.add("Black", lathe([(0, -2.82), (0.06, -2.82), (0.07, -2.95), (0.05, -3.02), (0, -3.02)], segs=12))  # lamp holder
    dent = None
    if dented:
        def dent(a, r, y):
            return r - 0.06 * smoothstep(0.7, 0.0, abs(math.atan2(math.sin(a - 2.0), math.cos(a - 2.0)))) * smoothstep(-0.1, -0.35, y)
    ctx.add("MetalPainted", _enamel_shade(0.6, 0.42, dent=dent), T(0, -2.94, 0))
    ctx.add("Glow", lathe([(0, -3.0), (0.06, -3.02), (0.13, -3.15), (0.14, -3.3), (0.1, -3.42), (0, -3.45)], segs=12))
    ctx.mark("Light", (0, -3.35, 0))

    def enamel(p):
        x, y, z = p.co
        rim = smoothstep(-3.3, -3.36, y)
        chip = smoothstep(0.6, 0.75, noise.fbm(p.co * 9, 3) * 0.5 + 0.5) * rim
        inside = p.normal.y < -0.3 and math.hypot(x, z) < 0.55
        if inside:
            return (2.6, 2.4, 2.1)  # (white enamel inside: clamped to the brightest)
        return (1 - 0.6 * chip, 1 - 0.6 * chip, 1 - 0.6 * chip)

    ctx.wear("MetalPainted", mul(enamel, nicotine(noise, -3.2, -2.9, 0.6)))
    ctx.wear("Paper", nicotine(noise, -0.2, 0.0, 1.0))


def pendant_lamp_pub(ctx):
    """A green enamel pendant: ceiling rose, braided flex, bakelite holder, a spun dome shade
    (white inside, chipped at the rim), its bulb (Glow, Light marker)."""
    _pendant(ctx, False)


def pendant_lamp_pub_dented(ctx):
    """The same pendant, its shade dented by a cue on one side and more chipped."""
    _pendant(ctx, True)


# ==============================================================================================
# WALL SPEAKER. Real reference: a two-way PA / install speaker (Bose 101 / JBL Control 1 size up
# to a 12 in cabinet) on a wall yoke: a rounded black cabinet, a perforated steel grille over
# the woofer and tweeter, a badge, a swivel bracket screwed to the wall, the cable stapled down.
# Data: Speaker 1.4 x 2.1 x 1.1 tilted 14 degrees down, its centre 1.0 out of the wall (it stays:
# tagged Speaker, its LookVector is where the music goes); the mesh's cabinet encloses it 0.04
# all round. Origin: on the wall face at the bracket's height, -Z out of the wall.
# ==============================================================================================
def wall_speaker_bracket(ctx):
    """A wall speaker on a swivel yoke: rounded black cabinet, perforated grille, badge, wall
    plate and arm, the cable running down the wall; tilted down 14 degrees."""
    ctx.budget = 2600
    ctx.smooth_angle = 40
    noise = ctx.noise
    cab = T(0, 0, -1.0) @ R(-14)
    ctx.add("PlasticDark", rbox(1.48, 2.18, 1.18, r=0.1, m=2, n=(2, 3, 2)), cab)
    ctx.add("Metal", rbox(1.38, 2.08, 0.05, r=0.05, m=1, n=(6, 8, 1)), cab @ T(0, 0, -0.6))
    for k in range(9):  # (the perforation rows)
        ctx.add("Black", box(1.2, 0.03, 0.01), cab @ T(0, -0.9 + k * 0.225, -0.628))
    ctx.add("Chrome", rbox(0.3, 0.08, 0.02, r=0.01, m=1), cab @ T(0, -0.85, -0.64))
    ctx.add("Metal", box(0.55, 0.75, 0.04, bevel=0.01), T(0, 0, -0.02))
    for sx in (-1, 1):
        for sy in (-1, 1):
            ctx.add("Metal", _dome(0.03, 0.015), T(sx * 0.2, sy * 0.28, -0.04) @ R(-90))
    ctx.add("Metal", rbox(0.18, 0.18, 0.5, r=0.03, m=1), T(0, 0, -0.27))
    ctx.add("Black", tube([(0.4, -0.95, -0.44), (0.45, -1.2, -0.12), (0.45, -1.4, -0.03), (0.45, -3.2, -0.03)], 0.03, segs=6))
    ctx.wear("PlasticDark", mul(edge_wear(0.4), nicotine(noise, 0.0, 1.2, 0.4), cavity(0.3)))
    ctx.wear("Metal", mul(metal_wear(noise, 0.4, (0.6, 0.6, 0.58)), cavity(0.4)))


# ==============================================================================================
# PINT-GLASS LEDGE. Real reference: a drinkers' wall ledge (a 15 cm board on iron brackets) with
# nonic pint glasses (16 cm, the bulge near the top) in all states: a fresh pint with a head, a
# half-drunk one with lacing, empties, one upside down, beer mats under some. Not bottles: pint
# glasses only. Data: DrinkShelf 0.6 x 0.2 x 16 on the east wall (top at y 5.8), Glass x6.
# Origin: on the wall face at the ledge's top, at its centre; the ledge along X.
# ==============================================================================================
def _nonic(full, foam, upside=False):
    """Profiles of a nonic pint (outer/inner skin) and of its beer (height `full`, 0..1)."""
    H = 0.62
    out = [(0, 0), (0.13, 0), (0.14, 0.02), (0.165, 0.48), (0.185, 0.53), (0.175, 0.56), (0.18, H)]
    inn = [(0.17, H), (0.163, 0.56), (0.172, 0.53), (0.152, 0.48), (0.128, 0.05), (0, 0.05)]
    glass = out + inn
    liquid = None
    if full > 0:
        top = 0.05 + (0.5 - 0.05) * full
        r_top = 0.128 + (0.152 - 0.128) * min(1.0, (top - 0.05) / 0.43) - 0.004
        liquid = [(0, 0.052), (0.124, 0.052), (r_top, top), (0, top)]
        if foam:
            foam = [(0, top - 0.005), (r_top - 0.001, top - 0.005), (r_top - 0.004, top + 0.05), (r_top * 0.6, top + 0.07), (0, top + 0.072)]
    return glass, liquid, foam if full > 0 and foam else None


def pint_glass_row(ctx):
    """A wall ledge on three iron brackets with seven nonic pint glasses in all states (fresh
    with a head, half-drunk with lacing, dregs, empties, one upside down), beer mats under
    some. Not a bottle in sight."""
    ctx.budget = 5200
    ctx.smooth_angle = 50
    noise = ctx.noise
    rng = ctx.rng
    L = 16.0
    sec = [(0.0, -0.2), (-0.5, -0.2)] + arc2(-0.5, -0.1, 0.1, -90, 90, 4)[1:] + [(0.0, 0.0)]
    ctx.add("WoodDark", ext_x(sec, -L / 2, L / 2, 16))
    for x in (-6.5, 0.0, 6.5):
        br = [(0.0, -0.22), (0.0, -0.9), (-0.08, -0.9), (-0.42, -0.25), (-0.42, -0.22)]
        ctx.add("Black", ext_x(br, x - 0.04, x + 0.04, 1))
    # (x, state): state = fill fraction, None = empty, "up" = upside down
    glasses = [(-7.0, 0.95), (-6.5, 0.0), (-4.0, 0.45), (-1.4, None), (-0.9, 0.12), (1.8, "up"), (4.4, 0.8), (7.0, None)]
    centres = []
    for x, st in glasses:
        z = -0.25 + rng.uniform(-0.04, 0.04)
        x = x + rng.uniform(-0.1, 0.1)
        if st == 0.0:
            continue
        if rng.random() < 0.6:
            ctx.add("Cardboard", rbox(0.38, 0.015, 0.38, r=0.02, m=1), T(x, 0.008, z) @ R(0, rng.uniform(0, 90), 0))
            y0 = 0.016
        else:
            y0 = 0.0
        if st == "up":
            g, _, _ = _nonic(0, False)
            ctx.add("Glass", lathe(g, segs=20), T(x, y0 + 0.62, z) @ R(180))
            centres.append((x, z, 0.0))
            continue
        g, liq, foam = _nonic(st or 0, st is not None and st > 0.3)
        ctx.add("Glass", lathe(g, segs=20), T(x, y0, z))
        if liq:
            ctx.add("Glass", lathe(liq, segs=16), T(x, y0, z))
        if foam:
            ctx.add("Foam", lathe(foam, segs=16), T(x, y0, z))
        centres.append((x, z, (0.05 + 0.45 * st) if st else 0.0))

    def glass(p):
        x, y, z = p.co
        best = min(centres, key=lambda c: abs(c[0] - x))
        r = math.hypot(x - best[0], z - best[1])
        if r < 0.15 and y < best[2] + 0.01 and y > 0.05:
            return (1.0, 0.62, 0.26)  # beer (amber)
        return (0.95, 1.0, 0.98)

    ctx.wear("Glass", glass)
    ctx.wear("Foam", lambda p: (1.0, 0.97, 0.88))
    ctx.wear("WoodDark", mul(varnish_wear(noise, disc_spots(rng, 10, -7.5, 7.5, -0.5, -0.05, 0.1, 0.17), (), None, dirt=0.0, top_y=0.0),
                             nicotine(noise, -0.2, 0.0, 0.2)))
    ctx.wear("Black", mul(edge_wear(0.4), scuffs(noise, 0.2, 5.0)))
    ctx.wear("Cardboard", lambda p: (1.0, 0.85 - 0.25 * (math.sin(p.co.x * 30) > 0.5), 0.7))


# ==============================================================================================
# PHOTO FRAMES. Real reference: old framed photos on a pub wall: a moulded dark frame, a cream
# mat, a sepia print (the old boxer, the darts team), hung a little crooked, the glass gone
# yellow-grey with smoke. Data: Photo 2 x 2.4 x 0.1 and PhotoPrint 1.5 x 1.9 on the wall.
# Origin: on the wall face at the frame's centre, -Z out.
# ==============================================================================================
def _frame(ctx, kind):
    ctx.budget = 1800
    noise = ctx.noise
    W, H = 2.0, 2.4
    prof = [(-0.11, 0.0), (0.11, 0.0), (0.11, -0.06), (0.06, -0.1), (0.0, -0.11), (-0.08, -0.08), (-0.11, -0.04)]
    path = [(-W / 2 + 0.11, -H / 2 + 0.11, 0), (W / 2 - 0.11, -H / 2 + 0.11, 0), (W / 2 - 0.11, H / 2 - 0.11, 0), (-W / 2 + 0.11, H / 2 - 0.11, 0)]
    for k in range(4):
        a, b = Vector(path[k]), Vector(path[(k + 1) % 4])
        d = (b - a).normalized()
        n = Vector((-d.y, d.x, 0))  # (inward)
        L = (b - a).length + 0.22
        c = (a + b) / 2
        bm = ext_x([(z, u) for u, z in prof], -L / 2, L / 2, 2)
        # mitre the ends: pull the inner edge in so the four sides meet at 45 degrees
        for v in bm.verts:
            u = v.co.y  # (across: +u inward after the turn below)
            k_ = (0.11 - u) / 0.22
            v.co.x = math.copysign(min(abs(v.co.x), L / 2 - 0.22 * (1 - k_)), v.co.x)
        ang = math.degrees(math.atan2(d.y, d.x))
        ctx.add("WoodDark", bm, T(c.x, c.y, 0) @ R(0, 0, ang) @ R(0, 0, 0) @ T(0, 0, 0) @ _flip_y_to_inward())
        del n
    ctx.add("Paper", box(W - 0.3, H - 0.3, 0.03), T(0, 0, -0.02))  # the mat
    ctx.add("Paper", subdivide(box(1.3, 1.6, 0.02), 9), T(0, 0.05, -0.04))  # the print
    rng = ctx.rng

    def photo(p):
        x, y, z = p.co
        if z > -0.045:
            return nicotine(noise, -2, 2, 0.4)(p) if abs(x) > 0.66 or abs(y - 0.05) > 0.81 else (0.85, 0.8, 0.7)
        if abs(x) > 0.64 or abs(y - 0.05) > 0.79:
            return (0.9, 0.86, 0.76)
        u, v = x / 0.65, (y - 0.05) / 0.8
        if kind == "boxer":
            head = math.hypot(u * 1.2, (v - 0.35) * 1.0) < 0.28
            body = abs(u) < 0.6 - 0.25 * (v + 0.2) and v < 0.15
            fists = math.hypot(abs(u) - 0.32, v - 0.18) < 0.16
            fig = head or body or fists
            t = 0.42 if fig else 0.75
        else:  # a darts team: three rows of heads and shoulders
            t = 0.78
            for row, vy in enumerate((0.35, 0.0, -0.35)):
                for k in range(5 - row % 2):
                    hx_ = -0.8 + (k + 0.5 * (row % 2)) * 0.4
                    if math.hypot(u - hx_, v - vy) < 0.11 or (abs(u - hx_) < 0.17 and vy - 0.28 < v < vy - 0.08):
                        t = 0.45
        t *= 0.9 + 0.15 * noise.fbm((u * 3, v * 3, 0), 2)
        fade = 1 + 0.25 * smoothstep(0.6, 1.0, max(abs(u), abs(v)))
        return (min(1.0, t * 1.12 * fade), min(1.0, t * 0.98 * fade), min(1.0, t * 0.78 * fade))

    ctx.wear("Paper", photo)
    ctx.wear("WoodDark", mul(edge_wear(0.3), cavity(0.3), lambda p: 0.85))
    del rng


def _flip_y_to_inward():
    """ext_x builds the section in (z, y): turn it so the section's y is the frame's inward
    direction (piece +Y before the side's own turn) and its z stays out of the wall."""
    return R(0, 0, 0)


def picture_frame(ctx):
    """An old framed photo: dark moulded frame, cream mat, a sepia print of a boxer with his
    guard up, smoke-yellowed."""
    _frame(ctx, "boxer")


def picture_frame_b(ctx):
    """An old framed photo: the bar's darts team in three rows, sepia, faded at the edges."""
    _frame(ctx, "team")


# ==============================================================================================
# BACK BAR. Real reference: a pub back bar (gantry): a low cupboard (doors, a worktop at about
# 1 m) along the wall behind the counter, and above it mirror-backed shelves for the spirits,
# divided into bays by slim pilasters, each shelf edged with a small brass gallery rail, lit
# from under the shelves' front edges (LED / tube strips), a cornice on top. What makes it read:
# the mirror behind the bottles doubling the room, the lit edges, the bays. Wear: the mirror's
# silvering gone black at the edges, nicotine on everything high, rings on the worktop.
# Data: ShelfCollider 22 x 11.3 x 0.8 (x 41..63, y 1.9..13.2, z 19.0..19.8; the wall at z 19.8),
# ShelfBoards (tops at 4.455 / 6.855 / 9.245 over the floor), Mirror, ShelfEnd x2, ShelfGlow
# (CityShopLight, handed over to the strips' Glow). Origin: centre of the collider's foot (data
# x 52, z 19.4) on the floor, front -Z; the wall at z +0.4.
# ==============================================================================================
BB_TOPS = (4.455, 6.855, 9.245)
BB_X0, BB_X1 = -10.9, 9.0  # the bays (the tall column is x 9 .. 11)
BB_PILASTERS = (-5.45, -0.3, 4.75)


def back_bar_shelf(ctx):
    """Duffy's back bar: panelled low cupboard with a worktop, three bays of mirror-backed
    shelves with brass gallery rails, slim pilasters, lit strips under the shelf edges and the
    cornice (Glow), a tall panelled column at the east end, the mirror's silvering going."""
    ctx.budget = 7800
    ctx.smooth_angle = 35
    BR = brass(ctx)
    noise = ctx.noise
    rng = ctx.rng
    zf, zw = -0.4, 0.4
    # lower cupboard: plinth, carcass, five panelled doors, the worktop (= the bottom board)
    ctx.add("Black", box(BB_X1 - BB_X0, 0.3, 0.6), T((BB_X0 + BB_X1) / 2, 0.15, 0.08))
    ctx.add("WoodDark", box(BB_X1 - BB_X0, 4.0, 0.68), T((BB_X0 + BB_X1) / 2, 0.3 + 2.0, 0.06))
    nd = 5
    dw = (BB_X1 - BB_X0) / nd
    for k in range(nd):
        cx = BB_X0 + (k + 0.5) * dw
        ctx.add("WoodDark", rbox(dw - 0.06, 3.85, 0.08, r=0.02, m=1, n=(2, 4, 1)), T(cx, 0.32 + 1.95, -0.31))
        ctx.add("WoodDark", raised_panel(dw - 0.5, 3.2, 0.06, 0.22, z0=-0.35, cx=cx, cy=0.32 + 1.95))
        kx = cx + (dw / 2 - 0.25) * (1 if k % 2 else -1)
        ctx.add(BR, lathe([(0, 0), (0.05, 0), (0.05, 0.02), (0.02, 0.05), (0.04, 0.1), (0, 0.12)], segs=10), T(kx, 3.2, -0.35) @ R(-90))
    top0 = BB_TOPS[0]
    ctx.add("Wood", rbox(BB_X1 - BB_X0 + 0.1, 0.15, 0.86, r=0.04, m=2, n=(16, 1, 2)), T((BB_X0 + BB_X1) / 2, top0 - 0.075, -0.02))
    # mirror (Chrome) behind the shelves, on a dark backing
    ctx.add("Black", box(BB_X1 - BB_X0, 10.95 - top0, 0.05), T((BB_X0 + BB_X1) / 2, (top0 + 10.95) / 2, 0.37))
    mirror = subdivide(box(BB_X1 - BB_X0 - 0.1, 10.9 - top0 - 0.05, 0.04), 7)
    ctx.add("Chrome", mirror, T((BB_X0 + BB_X1) / 2, (top0 + 10.9) / 2, 0.325))
    # shelves (upper two), their brass gallery rails, the lit strips under their fronts
    for y in BB_TOPS[1:]:
        ctx.add("WoodDark", rbox(BB_X1 - BB_X0, 0.15, 0.72, r=0.03, m=1, n=(12, 1, 1)), T((BB_X0 + BB_X1) / 2, y - 0.075, -0.04))
        ctx.add(BR, tube([(BB_X0 + 0.15, y + 0.14, -0.36), (BB_X1 - 0.15, y + 0.14, -0.36)], 0.018, segs=6))
        for x in [BB_X0 + 0.15 + k * (BB_X1 - BB_X0 - 0.3) / 8 for k in range(9)]:
            ctx.add(BR, cyl(0.012, 0.14, segs=5), T(x, y + 0.07, -0.36))
        ctx.add("Glow", box(BB_X1 - BB_X0 - 0.3, 0.035, 0.06), T((BB_X0 + BB_X1) / 2, y - 0.17, -0.3))
    ctx.add("Glow", box(BB_X1 - BB_X0 - 0.3, 0.035, 0.06), T((BB_X0 + BB_X1) / 2, 10.85, -0.3))
    # pilasters (in front of the mirror) and the left end panel
    for x in BB_PILASTERS:
        ctx.add("WoodDark", rbox(0.24, 10.9 - top0, 0.62, r=0.03, m=1, n=(1, 4, 1)), T(x, (top0 + 10.9) / 2, 0.0))
    ctx.add("WoodDark", rbox(0.3, 11.3, 0.86, r=0.03, m=2, n=(1, 6, 2)), T(BB_X0 - 0.15, 5.65, -0.02))
    # the tall east column (data ShelfEnd 61..63): panelled
    ctx.add("WoodDark", box(2.0, 10.9, 0.78), T(10.0, 5.45, 0.0))
    for y0, h in ((0.5, 4.0), (5.0, 5.4)):
        ctx.add("WoodDark", raised_panel(1.5, h, 0.06, 0.2, z0=-0.39, cx=10.0, cy=y0 + h / 2))
    # cornice: a stepped moulding over the whole length
    corn = [(0.4, 10.9), (-0.45, 10.9), (-0.45, 10.98), (-0.52, 11.05), (-0.52, 11.2), (-0.58, 11.26), (-0.58, 11.35), (0.4, 11.35)]
    ctx.add("WoodDark", ext_x(corn, BB_X0 - 0.3, 11.0, 12))
    ctx.mark("Light", (0.0, 7.5, -1.0))

    def mirror_age(p):
        x, y, z = p.co
        edge = min(x - BB_X0, BB_X1 - x, y - top0, 10.9 - y)
        rot = smoothstep(0.5, 0.0, edge) * (0.6 + 0.4 * noise.fbm(p.co * 3, 2)) + 0.5 * smoothstep(0.75, 0.9, noise.fbm(p.co * 1.5, 3) * 0.5 + 0.5)
        return (1 - 0.55 * min(1.0, rot), 1 - 0.55 * min(1.0, rot), 1 - 0.6 * min(1.0, rot))

    # (an old smoky bar mirror: dimmed overall so it reads as a mirror, not a lit panel)
    ctx.wear("Chrome", mul(mirror_age, nicotine(noise, 5.0, 11.0, 0.4), lambda p: (0.5, 0.48, 0.45)))
    ctx.wear("WoodDark", mul(varnish_wear(noise, dirt=0.3, dirt_h=1.2), nicotine(noise, 5.0, 11.3, 0.35)))
    ctx.wear("Wood", mul(varnish_wear(noise, disc_spots(rng, 10, BB_X0 + 0.5, BB_X1 - 0.5, -0.35, 0.3, 0.1, 0.18), (), None, dirt=0.0, top_y=top0),
                         lambda p: (0.6, 0.55, 0.5)))
    ctx.wear(BR, metal_wear(noise, 0.55))
    ctx.wear("Black", ground_dirt(0.3, 0.3, noise))


# ==============================================================================================
# THE BACK-BAR DECOR (the ONE allowed exception to the no-bottle rule: pure decoration on
# Duffy's back-bar shelves, never pickable, no tag, no prompt; it replaces the 48 decorative
# "Bottle" parts). Real reference: a bar's spirits gantry: square-shouldered whiskey, tall round
# gin, squat rum with a wooden-topped cork, long-necked green wine-style, slim vodka with a
# chrome speed pourer, a flat oval liqueur flask; paper labels, black / chrome caps; each half
# drunk to a different level. Data: 12 groups of 4 "Bottle" cylinders (0.44-0.5 x 1.1-1.55) on
# the three boards, centres 0.56 apart. Origin: on the board's top at the group's centre (data
# z 19.3); the four along X.
# ==============================================================================================
KINDS = {
    # kind: (body radius, height, shoulder start, neck radius, glass colour, label layer + colour, top)
    "square": (0.2, 1.15, 0.78, 0.06, (1.0, 0.62, 0.32), ("Black", None), "cap"),
    "gin": (0.2, 1.45, 0.95, 0.055, (0.85, 1.0, 1.0), ("Paper", (1.0, 0.95, 0.85)), "chrome"),
    "rum": (0.24, 1.1, 0.72, 0.065, (0.85, 0.5, 0.3), ("Paper", (1.0, 0.85, 0.55)), "cork"),
    "wine": (0.19, 1.5, 0.82, 0.05, (0.45, 0.72, 0.45), ("Paper", (0.95, 0.9, 0.8)), "foil"),
    "vodka": (0.18, 1.4, 0.95, 0.05, (0.95, 1.0, 1.0), ("Paper", (1.0, 0.45, 0.4)), "pourer"),
    "liqueur": (0.22, 1.2, 0.8, 0.055, (1.0, 0.5, 0.35), ("Paper", (0.98, 0.88, 0.5)), "cap"),
}


def _deco_row(ctx, kinds):
    ctx.budget = 3600
    ctx.smooth_angle = 50
    rng = ctx.rng
    noise = ctx.noise
    info = []
    for k, kind in enumerate(kinds):
        r, h, sh, nr, gcol, (llayer, lcol), top = KINDS[kind]
        x = -0.84 + k * 0.56 + rng.uniform(-0.03, 0.03)
        z = rng.uniform(-0.03, 0.03)
        yaw = rng.uniform(-25, 25)
        m = T(x, 0, z) @ R(0, yaw, 0)
        if kind == "square":
            shape = lambda a, rr, y: rr / max(abs(math.cos(a)) ** 4 + abs(math.sin(a)) ** 4, 1e-6) ** 0.25 * 0.92 if y < 0.8 else rr  # noqa: E731
        elif kind == "liqueur":
            shape = lambda a, rr, y: rr * (1.0 - 0.38 * abs(math.sin(a))) if y < 0.85 else rr  # noqa: E731
        else:
            shape = None
        nk = h - sh
        prof = [(0, 0.0), (r * 0.9, 0.0), (r, 0.03), (r, sh - 0.02)]
        prof += [(lerp(r, nr, smoothstep(0, 1, t)), sh + t * nk * 0.45) for t in (0.25, 0.5, 0.75, 1.0)]
        prof += [(nr, h - 0.06), (nr + 0.012, h - 0.05), (nr + 0.012, h - 0.02), (nr * 0.8, h), (0, h)]
        segs = 20 if shape else 16
        ctx.add("Glass", lathe(prof, segs=segs, radius_fn=shape), m)
        # label: a band round the body (proud 0.008), its height by kind
        y0, y1 = sh * 0.33, sh * 0.74
        band = [(r - 0.02, y0), (r + 0.008, y0), (r + 0.008, y1), (r - 0.02, y1)]
        bshape = (lambda a, rr, y, f=shape: f(a, rr, 0.0)) if shape else None
        ctx.add(llayer, lathe(band, segs=segs, radius_fn=bshape), m)
        # top
        if top == "cap":
            ctx.add("Black", lathe([(0, h - 0.04), (nr + 0.02, h - 0.04), (nr + 0.022, h + 0.08), (0, h + 0.085)], segs=10), m)
        elif top == "chrome":
            ctx.add("Chrome", lathe([(0, h - 0.04), (nr + 0.018, h - 0.04), (nr + 0.018, h + 0.06), (0, h + 0.065)], segs=10), m)
        elif top == "cork":
            ctx.add("Wood", lathe([(0, h - 0.02), (nr + 0.04, h), (nr + 0.04, h + 0.09), (nr + 0.02, h + 0.11), (0, h + 0.11)], segs=10), m)
        elif top == "foil":
            ctx.add("Black", lathe([(0, h - 0.22), (nr + 0.006, h - 0.22), (nr + 0.006, h + 0.01), (0, h + 0.015)], segs=10), m)
        else:  # a chrome speed pourer: collar, angled spout
            ctx.add("Chrome", lathe([(0, h - 0.04), (nr + 0.012, h - 0.04), (nr + 0.012, h + 0.03), (0, h + 0.03)], segs=10), m)
            ctx.add("Chrome", tube([(0, h + 0.02, 0), (0, h + 0.12, -0.02), (0, h + 0.2, -0.07)], 0.014, segs=6), m)
        info.append((x, z, h, sh, gcol, lcol, rng.uniform(0.25, 0.9)))

    def glass(p):
        x, y, z = p.co
        b = min(info, key=lambda b: abs(b[0] - x))
        fill = b[3] * b[6]
        if y > fill:
            return (0.92 * b[4][0] ** 0.3, 0.95 * b[4][1] ** 0.3, 0.95 * b[4][2] ** 0.3)  # (empty glass above the level)
        return b[4]

    def label(p):
        x, y, z = p.co
        b = min(info, key=lambda b: abs(b[0] - x))
        c = b[5] or (1.0, 1.0, 1.0)
        mid = abs(y - b[3] * 0.52) < 0.06
        return tuple(v * (0.7 if mid else 1.0) * (0.9 + 0.1 * noise.n(p.co * 20)) for v in c)

    ctx.wear("Glass", glass)
    ctx.wear("Paper", label)
    ctx.wear("Black", edge_wear(0.4))


def deco_bottle_row_a(ctx):
    """Back-bar decor (Duffy's only, never an item): a square whiskey, a gin, a rum with a
    wooden cork, a long-necked green one; labels, caps, each drunk to its own level."""
    _deco_row(ctx, ("square", "gin", "rum", "wine"))


def deco_bottle_row_b(ctx):
    """Back-bar decor (Duffy's only, never an item): a vodka with a speed pourer, a flat
    liqueur flask, a square whiskey, a gin."""
    _deco_row(ctx, ("vodka", "liqueur", "square", "gin"))


def deco_bottle_row_c(ctx):
    """Back-bar decor (Duffy's only, never an item): a long-necked green one, a rum, a vodka
    with a pourer, a liqueur flask."""
    _deco_row(ctx, ("wine", "rum", "vodka", "liqueur"))


PIECES = {
    "BarCounterModule": bar_counter_module,
    "BarCounterModuleR": bar_counter_module_r,
    "BeerFont3": beer_font3,
    "BeerFont2": beer_font2,
    "BarStoolPub": bar_stool_pub,
    "BarStoolPubTorn": bar_stool_pub_torn,
    "BoothSeatTufted": booth_seat_tufted,
    "PubTable": pub_table,
    "TableLampBrass": table_lamp_brass,
    "CandleJar": candle_jar,
    "BarrelTable": barrel_table,
    "Ashtray": ashtray,
    "PoolTableBar": pool_table_bar,
    "PoolCue": pool_cue,
    "PoolBallSet": pool_ball_set,
    "PoolLampBillard": pool_lamp_billard,
    "Jukebox": jukebox,
    "CigaretteMachine": cigarette_machine,
    "Dartboard": dartboard,
    "PendantLampPub": pendant_lamp_pub,
    "PendantLampPubDented": pendant_lamp_pub_dented,
    "WallSpeakerBracket": wall_speaker_bracket,
    "PintGlassRow": pint_glass_row,
    "PictureFrame": picture_frame,
    "PictureFrameB": picture_frame_b,
    "BackBarShelf": back_bar_shelf,
    # (the one whitelisted exception to the no-bottle names: decor only, see the top)
    "DecoBottleRowA": deco_bottle_row_a,
    "DecoBottleRowB": deco_bottle_row_b,
    "DecoBottleRowC": deco_bottle_row_c,
}
