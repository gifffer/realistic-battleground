"""Building facades of the city prop kit: windows (sash frames, blinds, boarded, barred), the
through-wall air conditioners, the shop roller shutters and their hoods, the garage and
loading-dock roller doors, the shop-front glazing frames (with the aluminium door and its push bar), the striped
shop awnings and a bracket lantern.

Why these are meshes: the city's facades (Buildings/* in CityData) draw every window as a flat
dark pane between four limestone boxes and a 0.25 stud plank for the sash; a roller shutter is
a grey slab with three thin bars on it, a garage door a diamond-plate slab with three seams, a
shop front a glass slab with one black bar, an awning a tilted 0.3 stud board. They are the
most seen things in the city. Here each is modelled to its real anatomy:
  * windows: the stone surround (jambs, a flat arch of five voussoirs, a weathered sill with
    its drip), a painted timber box frame and TWO sashes in different planes (the upper one
    outside the lower one, horns under the meeting rail), glazing bars, a brass catch;
  * roller shutters / doors: the real curved-slat curtain section (one convex slat every
    0.3 stud, interlocking at a small step), guide channels, a bottom bar with its rubber
    seal, lift handles, hasp and padlock; hood with end plates and bolts;
  * shop fronts: a moulded timber frame with glazing beads, mullions with caps, a transom bar
    (top lights), a sloped cill over the stall riser;
  * awnings: a canvas sheet in two layers of stripes (shop colour / cream), sagging between
    its folding arms, a scalloped valance, a front bar; the torn one has real holes and a
    hanging flap.

Conventions (pieces/_template.py, fixtures.py): Roblox axes, studs, +Y up. All these are WALL
pieces: the origin is in the plane named per piece (the wall face, or the old part's centre
plane when the old part is a recessed curtain or pane), local -Z points OUT of the building,
+X is the piece's right. Sizes follow the city data exactly (the facades are built on an
8 stud panel grid: a window opening is 4.4 x 6.4 upstairs, 4.4 x 5.2 on the ground floor),
because the meshes replace parts in place; the details take real proportions inside that.

Layers: stone = Concrete, painted timber / painted steel = MetalPainted (the only tintable
layer of each piece, so the overlay paints each copy), galvanised steel = Metal, rust = Rust,
blind = Paper, canvas = Fabric (tinted) + Foam (the cream stripes), weathered boards = Wood /
WoodDark, rubber seal = Rubber, the lantern's lit glass = Glow.

Real references (sizes in metres, 1 stud ~ 0.28 m):
  * double-hung sash window: sash stiles 45-55 mm, meeting rails 35-45 mm, bottom rail
    ~80 mm, the upper sash runs in the outer track (it overlaps the lower at the meeting rail),
    horns 50-80 mm under the upper sash; stone sill 150 mm deep with a drip groove;
  * rolling steel shutter: curved slats 75-80 mm pitch, 0.6-1.0 mm galvanised steel, guide
    channels 60-80 mm, bottom bar angle 40 x 40 mm with an EPDM seal, lift handles;
  * sectional / roller garage door: wider slats ~100 mm, wind locks on the slat ends;
  * through-wall air conditioner: 650-700 mm wide, 400-450 mm tall, side intake louvres,
    a rear condenser grille of vertical fins, a support bracket of angle iron under it, a
    rust stain down the wall from the drain;
  * shop front (Victorian / interwar): stall riser, sloped cill, 70-100 mm mullions with
    beads, transom bar ~1.9 m up with top lights above;
  * retractable awning: acrylic canvas 280-300 g/m2, 120 mm stripes, scalloped valance
    200-250 mm, folding arms 2.5-3.5 m.
"""

import math

import bmesh
from mathutils import Vector

from kitlib import T, R, bevel_edges, box, cyl, loft, lerp, smoothstep, mul, cavity, edge_wear, streaks, scuffs  # noqa: F401
from fixtures import rbox, prism, sweep, spline, circle2, rrect2  # noqa: F401


# ==============================================================================================
# Helpers
# ==============================================================================================
def bx(x0, x1, y0, y1, z0, z1, r=0.02, n=(1, 1, 1), m=1):
    """A rounded box by its extents (r: edge round, n: cells per axis for wear gradients)."""
    bm = rbox(abs(x1 - x0), abs(y1 - y0), abs(z1 - z0), r=r, m=m, n=n)
    bmesh.ops.translate(bm, verts=bm.verts, vec=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    return bm


def dbox(x0, x1, y0, y1, d0, d1, r=0.02, n=(1, 1, 1), m=1):
    """bx() with depth given as distance OUT of the wall (d = -z)."""
    return bx(x0, x1, y0, y1, -d1, -d0, r, n, m)


def pbox(x0, x1, y0, y1, d0, d1):
    """A plain box (12 triangles) by its extents, depth as distance out of the wall: for tiny
    or hidden parts (fins, clips) where a bevel would not show."""
    bm = box(abs(x1 - x0), abs(y1 - y0), abs(d1 - d0))
    bmesh.ops.translate(bm, verts=bm.verts, vec=((x0 + x1) / 2, (y0 + y1) / 2, -(d0 + d1) / 2))
    return bm


def cbox(x0, x1, y0, y1, d0, d1, r=0.02):
    """A box with chamfered edges (one bevel segment, ~44 triangles), depth out of the wall."""
    bm = box(abs(x1 - x0), abs(y1 - y0), abs(d1 - d0), bevel=r, segments=1)
    bmesh.ops.translate(bm, verts=bm.verts, vec=((x0 + x1) / 2, (y0 + y1) / 2, -(d0 + d1) / 2))
    return bm


def xprism(poly, x0, x1, segs=1):
    """Extrudes a section [(d, y), ...] (d = out of the wall) along X from x0 to x1."""
    rings = [[(lerp(x0, x1, k / segs), y, -d) for d, y in poly] for k in range(segs + 1)]
    return loft(rings, cap_start=True, cap_end=True)


def yprism(poly, y0, y1, segs=1):
    """Extrudes a section [(x, d), ...] along Y from y0 to y1."""
    rings = [[(x, lerp(y0, y1, k / segs), -d) for x, d in poly] for k in range(segs + 1)]
    return loft(rings, cap_start=True, cap_end=True)


def displace(bm, fn):
    for v in bm.verts:
        v.co = fn(v.co.copy())
    return bm


def below(y0, y1, strength):
    """Darker toward y0 (dirt / rust rising from the bottom of a wall piece)."""

    def fn(p):
        return 1 - strength * (1 - smoothstep(y0, y1, p.co.y))

    return fn


def near_wall(strength, depth=0.25):
    """Grime where a wall piece meets the wall (z near 0)."""

    def fn(p):
        return 1 - strength * (1 - smoothstep(0.0, depth, -p.co.z))

    return fn


def old_rust(p):
    """Old, dark rust (years of wet grime on it), not the fresh orange of the layer's colour."""
    return 0.72


def soot_under(xs, y_top, length, width, strength):
    """Dark rain streaks running down from points (x, y_top): under the ends of a lintel,
    a sill, a bracket."""

    def fn(p):
        s = 0.0
        for x in xs:
            dy = y_top - p.co.y
            if dy < -0.05:
                continue
            fall = 1 - smoothstep(0.0, length, dy)
            s = max(s, fall * (1 - smoothstep(0.0, width, abs(p.co.x - x))))
        return 1 - strength * s

    return fn


def patches(noise, strength, scale, lo=0.55, hi=0.8, offset=(0, 0, 0)):
    """Blotches (peeled paint, damp, rust) where the noise is high."""

    def fn(p):
        q = p.co + Vector(offset)
        v = noise.fbm(q, 3, scale) * 0.5 + 0.5
        return 1 - strength * smoothstep(lo, hi, v)

    return fn


# ==============================================================================================
# Windows
# ==============================================================================================
# The opening is 4.4 wide; the stone jambs stand 0.3 wide just outside it (0.35 proud of the
# wall), the timber box frame lines the opening (its stiles 0.2 wide cover the pane's edges),
# the two sashes slide in two tracks in front of the old pane (which stays: CityWindowLit /
# CityGlass drive it): the upper sash at 0.15..0.23 out, the lower at 0.24..0.32.
WIN_W = 4.4
FRAME = 0.2  # box frame lining width
UP_D = (0.15, 0.23)  # upper sash track (out of the wall)
LO_D = (0.24, 0.32)  # lower sash track
BOX_D = (0.12, 0.335)  # box frame lining


def _stone_surround(ctx, hh, lintel_h, sill_d, head="arch", sill_w=5.4):
    """Jambs, lintel (flat arch of voussoirs or a plain head) and the weathered sill, in the
    Concrete layer (the city's limestone)."""
    rng = ctx.rng
    hw = WIN_W / 2
    for s in (-1, 1):
        # jamb: two stones (a joint at 55 % of the height), arris chamfered
        yj = lerp(-hh, hh, 0.55 + rng.uniform(-0.05, 0.05))
        for y0, y1 in ((-hh + 0.01, yj - 0.012), (yj + 0.012, hh - 0.01)):
            ctx.add("Concrete", dbox(min(s * hw, s * (hw + 0.3)), max(s * hw, s * (hw + 0.3)), y0, y1,
                                     -0.02, 0.35, r=0.035, n=(1, 3, 1)))
    if head == "arch":
        # five voussoirs, the middle one (keystone) a little taller and prouder; their joints
        # fan out from a point below the opening (a flat "jack" arch)
        span = 5.0  # at the bottom (on the jambs); the joints fan out to ~5.6 at the top
        top = hh + lintel_h
        centre = Vector((0, hh - 6.0, 0))
        xs = [-span / 2 + span * k / 5 for k in range(6)]
        for k in range(5):
            xa, xb = xs[k] + 0.012, xs[k + 1] - 0.012
            yb = hh + 0.005
            yt = top + (0.08 if k == 2 else 0.0)
            proud = 0.4 + (0.05 if k == 2 else 0.0)

            def slant(x, y):
                # point on the joint line from `centre` through (x, yb), at height y
                return centre.x + (x - centre.x) * (y - centre.y) / (yb - centre.y)

            poly = [(slant(xa, yb), yb), (slant(xb, yb), yb), (slant(xb, yt), yt), (slant(xa, yt), yt)]
            bm = loft([[(px, py, 0.02) for px, py in poly], [(px, py, -proud) for px, py in poly]],
                      cap_start=True, cap_end=True)
            bevel_edges(bm, [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-6
                             and min(e.verts[0].co.z, e.verts[1].co.z) < -0.1], 0.025, 1)
            ctx.add("Concrete", bm)
    else:
        # a plain head stone, slightly chamfered
        ctx.add("Concrete", dbox(-2.65, 2.65, hh + 0.005, hh + lintel_h, -0.02, 0.4, r=0.04, n=(2, 1, 1)))
    # sill: sloped top (water runs off), front nose, drip groove underneath, the ends ("stools")
    # wider than the jambs
    y0 = -hh
    sec = [(-0.02, y0), (sill_d - 0.04, y0 - 0.06), (sill_d, y0 - 0.09), (sill_d, y0 - 0.34),
           (sill_d - 0.04, y0 - 0.4), (sill_d - 0.12, y0 - 0.4), (sill_d - 0.12, y0 - 0.36),
           (sill_d - 0.17, y0 - 0.36), (sill_d - 0.17, y0 - 0.4), (-0.02, y0 - 0.4)]
    bm = xprism(sec, -sill_w / 2, sill_w / 2, segs=6)
    ctx.add("Concrete", bm)


def _stone_wear(ctx, hh):
    nz = ctx.noise
    ctx.wear("Concrete", mul(cavity(0.45), edge_wear(0.1), near_wall(0.25, 0.12),
                             soot_under((-2.4, 2.4), hh + 0.9, 1.6, 0.4, 0.45),
                             soot_under((-1.4, 0.3, 1.9), -hh, 0.5, 0.35, 0.3),
                             streaks(nz, 0.3, 4.0), patches(nz, 0.4, 1.6, 0.55, 0.85),
                             lambda p: 1 - 0.25 * smoothstep(-0.02, -0.0, -p.co.y - hh) * smoothstep(0.1, 0.0, abs(p.co.y + hh))))


def _box_frame(ctx, hh, sill_top):
    """The painted timber box frame lining the opening: stiles, head, a timber sub-sill."""
    hw = WIN_W / 2
    for s in (-1, 1):
        ctx.add("MetalPainted", dbox(s * (hw - FRAME), s * (hw + 0.02), sill_top, hh - 0.005, BOX_D[0], BOX_D[1],
                                     r=0.02, n=(1, 2, 1)))
    ctx.add("MetalPainted", dbox(-hw + FRAME - 0.01, hw - FRAME + 0.01, hh - 0.2, hh - 0.005, BOX_D[0], BOX_D[1],
                                 r=0.02, n=(2, 1, 1)))
    # sub-sill: sloped timber, sits on the stone sill
    sec = [(0.11, sill_top + 0.14), (0.4, sill_top + 0.05), (0.42, sill_top + 0.01), (0.42, sill_top - 0.03),
           (0.11, sill_top - 0.03)]
    ctx.add("MetalPainted", xprism(sec, -hw - 0.01, hw + 0.01, segs=4))


def _sash(ctx, x0, x1, y0, y1, d0, d1, top=0.15, bottom=0.12, stile=0.13, bars=0, horns=False, catch=False):
    """One sash: two stiles, top and bottom rails (the meeting rail is the bottom rail of the
    upper sash / the top rail of the lower one), `bars` vertical glazing bars, optional horns
    under the stiles (upper sash) and the brass catch on the meeting rail."""
    rr = 0.015
    ctx.add("MetalPainted", dbox(x0, x0 + stile, y0, y1, d0, d1, r=rr, n=(1, 2, 1)))
    ctx.add("MetalPainted", dbox(x1 - stile, x1, y0, y1, d0, d1, r=rr, n=(1, 2, 1)))
    ctx.add("MetalPainted", dbox(x0 + stile - 0.01, x1 - stile + 0.01, y1 - top, y1, d0, d1, r=rr, n=(2, 1, 1)))
    ctx.add("MetalPainted", dbox(x0 + stile - 0.01, x1 - stile + 0.01, y0, y0 + bottom, d0, d1, r=rr, n=(2, 1, 1)))
    # putty fillets inside the rails (a small chamfered bead toward the glass)
    for k in range(bars):
        xc = lerp(x0, x1, (k + 1) / (bars + 1))
        sec = [(xc - 0.035, d0 + 0.01), (xc + 0.035, d0 + 0.01), (xc + 0.02, d1 - 0.01), (xc - 0.02, d1 - 0.01)]
        ctx.add("MetalPainted", yprism(sec, y0 + bottom - 0.01, y1 - top + 0.01, segs=3))
    if horns:
        # ogee horns: a short tapered extension of each stile below the meeting rail
        for xa, xb in ((x0, x0 + stile), (x1 - stile, x1)):
            rings = []
            for t, w in ((0.0, 1.0), (0.4, 0.92), (0.7, 0.62), (1.0, 0.35)):
                y = y0 - 0.16 * t
                xm, hwid = (xa + xb) / 2, (xb - xa) / 2 * w
                rings.append([(xm - hwid, y, -d0 - 0.005), (xm + hwid, y, -d0 - 0.005), (xm + hwid, y, -d1 + 0.005),
                              (xm - hwid, y, -d1 + 0.005)])
            ctx.add("MetalPainted", loft(rings, cap_start=True, cap_end=True))
    if catch:
        # fitch catch on the meeting rail (brass: Metal), screwed on the top of the lower sash
        ctx.add("Metal", cyl(0.05, 0.03, 10, bevel=0.008), T(0.0, y1 + 0.015, -(d0 + d1) / 2))
        ctx.add("Metal", bx(-0.1, 0.1, y1 + 0.002, y1 + 0.02, -(d1 - 0.01), -(d0 + 0.01), r=0.006))


def _sash_window(ctx, hh, meet, bars, blind=None, lintel=0.7, head="arch", sill_d=0.6, sill_w=5.4):
    """A complete double-hung window around a 4.4 x 2hh opening. meet: the meeting rails'
    height (y); bars: glazing bars per sash; blind: None or (drop fraction, skew)."""
    hw = WIN_W / 2
    _stone_surround(ctx, hh, lintel, sill_d, head, sill_w)
    _stone_wear(ctx, hh)
    sill_top = -hh + 0.02
    _box_frame(ctx, hh, sill_top)
    xi0, xi1 = -hw + FRAME - 0.02, hw - FRAME + 0.02
    # upper sash (outer track): from the head down to the meeting rail, horns below it
    _sash(ctx, xi0, xi1, meet - 0.06, hh - 0.18, UP_D[0], UP_D[1], top=0.14, bottom=0.11, bars=bars,
          horns=True)
    # lower sash (inner track): bottom rail sits on the sub-sill, its top rail meets the upper
    _sash(ctx, xi0, xi1, sill_top + 0.14, meet + 0.06, LO_D[0], LO_D[1], top=0.11, bottom=0.22, bars=bars,
          catch=True)
    nz = ctx.noise
    ctx.wear("MetalPainted", mul(cavity(0.35), edge_wear(0.1), below(sill_top, sill_top + 1.4, 0.35),
                                 patches(nz, 0.35, 3.0, 0.62, 0.8), streaks(nz, 0.15, 6.0)))
    if blind is not None:
        drop, skew = blind
        top = hh - 0.2
        bottom = top - (2 * hh - 0.4) * drop
        # the blind (yellowed holland cloth: Paper) in front of the pane, behind the sashes;
        # slightly wavy, hanging a little askew, a wooden lath and a pull ring at the bottom
        segs_y = max(3, int((top - bottom) / 0.5))
        sheet = dbox(-hw + FRAME + 0.02, hw - FRAME - 0.02, bottom, top, 0.122, 0.138, r=0.004, n=(8, segs_y, 1))

        def wave(co):
            t = (top - co.y) / max(0.01, top - bottom)
            co.y -= skew * (co.x / hw) * t * 0.5
            co.z -= 0.004 * math.sin(co.x * 5.1 + co.y * 0.7)
            return co

        ctx.add("Paper", displace(sheet, wave))
        yb = bottom - skew * 0.0
        # the lath follows the skew of the hem
        ctx.add("WoodDark", cyl(0.025, WIN_W - 2 * FRAME - 0.1, 8),
                T(0, yb, -0.14) @ R(0, 0, 90 - math.degrees(skew * 0.5 / hw)))
        ctx.add("Metal", sweep([(math.cos(a) * 0.05, yb - 0.09 + math.sin(a) * 0.05, -0.142)
                                for a in [2 * math.pi * k / 12 for k in range(12)]], circle2(0.008, 5),
                               side=(0, 0, 1), closed=True))
        ctx.add("Metal", cyl(0.006, 0.05, 4), T(0, yb - 0.025, -0.142))
        ctx.wear("Paper", mul(cavity(0.2), patches(nz, 0.25, 2.2, 0.55, 0.8),
                              below(bottom, bottom + 0.8, 0.12), streaks(nz, 0.15, 3.0)))


def window_frame_sash(ctx):
    """Upstairs window (4.4 x 6.4 opening): stone jambs, a flat arch of five voussoirs, sloped
    sill with drip groove, painted box frame, two-over-two sashes in two tracks (horns, brass
    catch). Origin: the pane's centre ON the wall face, -Z out."""
    ctx.budget = 3200
    _sash_window(ctx, 3.2, 0.02, bars=1)


def window_frame_sash_plain(ctx):
    """Upstairs window, one-over-one sashes (later replacement sashes), plain flat lintel."""
    ctx.budget = 3000
    _sash_window(ctx, 3.2, 0.02, bars=0, head="plain")


def window_frame_blind(ctx):
    """Upstairs window, one-over-one, a yellowed roller blind pulled 40 % down and a little
    askew (lit windows glow under it at night)."""
    ctx.budget = 3400
    _sash_window(ctx, 3.2, 0.02, bars=0, blind=(0.42, 0.12))


def window_frame_blind_low(ctx):
    """Upstairs window, two-over-two, the blind pulled most of the way down."""
    ctx.budget = 3600
    _sash_window(ctx, 3.2, 0.02, bars=1, blind=(0.72, -0.08), head="plain")


def window_frame_sash_low(ctx):
    """Ground-floor window (4.4 x 5.2 opening), shallow head stone instead of the arch, the
    meeting rails below the middle (data: 0.78 under the centre), deep sill."""
    ctx.budget = 3000
    _sash_window(ctx, 2.6, -0.78, bars=0, lintel=0.4, head="plain")


def _bars(ctx, hh, d=(0.37, 0.49)):
    """Security bars in front of a ground-floor window: four round iron bars through three
    flat bars, the flats' ends turned into the stone (lugs)."""
    dc = (d[0] + d[1]) / 2
    for x in (-1.65, -0.55, 0.55, 1.65):
        bend = ctx.rng.uniform(-0.03, 0.03)
        pts = [(x, -hh - 0.05, -dc), (x + bend, 0.0, -dc - abs(bend)), (x, hh + 0.05, -dc)]
        ctx.add("Rust", sweep(spline(pts, 4), circle2(0.06, 8), side=(0, 0, 1)))
    for y in (-hh + 0.35, 0.0, hh - 0.35):
        ctx.add("Rust", dbox(-2.55, 2.55, y - 0.09, y + 0.09, dc - 0.07, dc - 0.02, r=0.012, n=(2, 1, 1)))
        for s in (-1, 1):
            # the lug: the flat bent back into the jamb
            ctx.add("Rust", dbox(s * 2.45, s * 2.6, y - 0.09, y + 0.09, 0.2, dc - 0.02, r=0.012))
            ctx.add("Metal", cyl(0.035, 0.03, 6), T(s * 2.5, y, -0.36) @ R(90, 0, 0))
    nz = ctx.noise
    ctx.wear("Rust", mul(old_rust, cavity(0.3), patches(nz, 0.3, 4.0, 0.5, 0.75), below(-hh, -hh + 1.0, 0.25)))


def window_frame_barred(ctx):
    """Ground-floor window with security bars (rusted iron: round bars through flat bars,
    lugs into the jambs)."""
    ctx.budget = 4600
    _sash_window(ctx, 2.6, -0.78, bars=0, lintel=0.4, head="plain")
    _bars(ctx, 2.6)


def _plank(ctx, layer, x0, x1, y0, y1, d0, d1, rot, nails=True, broken=None):
    """A rough board: slightly cupped, split ends, nailed at both ends."""
    w, h = x1 - x0, y1 - y0
    bm = bx(-w / 2, w / 2, -h / 2, h / 2, -(d1 - d0) / 2, (d1 - d0) / 2, r=0.02, n=(10, 2, 1))
    nz = ctx.noise
    seed = ctx.rng.uniform(0, 50)

    def shape(co):
        u = co.x / (w / 2)
        co.z += 0.02 * (co.y / (h / 2)) ** 2 - 0.01  # cupping
        co.z += 0.01 * nz.n((co.x * 2 + seed, co.y * 3, 0))
        if broken is not None and u * broken[0] > 0:
            # a broken-off corner: the end shortened on one edge
            cut = broken[1] * smoothstep(-0.2, 1.0, co.y * broken[2] / (h / 2))
            if abs(u) > 1 - cut / (w / 2):
                co.x = math.copysign(w / 2 - cut, co.x) + 0.15 * (co.x - math.copysign(w / 2 - cut, co.x))
        return co

    displace(bm, shape)
    m = T((x0 + x1) / 2, (y0 + y1) / 2, -(d0 + d1) / 2) @ R(0, 0, rot)
    ctx.add(layer, bm, m)
    if nails:
        for xs in (x0 + 0.25, x1 - 0.25):
            for ys in (-h / 4, h / 4):
                p = m @ Vector((xs - (x0 + x1) / 2, ys, -(d1 - d0) / 2 - 0.006))
                ctx.add("Metal", cyl(0.035, 0.02, 6), T(p.x, p.y, p.z) @ R(90, 0, 0))


def _boarded(ctx, head):
    """Upstairs window boarded up: a weathered plywood sheet over the opening (it replaces the
    data's wooden pane), two 2x4 battens screwed across, the stone surround and sill kept,
    no sashes (taken out). Origin: the opening's centre ON the wall face, -Z out."""
    ctx.budget = 3200
    hh = 3.2
    _stone_surround(ctx, hh, 0.7, 0.6, head)
    _stone_wear(ctx, hh)
    # plywood: 4.5 x 6.3, 0.07 thick, standing 0.03 off the wall, its plies showing at the edges
    ply = dbox(-2.22, 2.22, -hh + 0.03, hh - 0.04, 0.03, 0.1, r=0.012, n=(6, 8, 1))
    nz = ctx.noise

    def warp(co):
        co.z -= 0.025 * math.sin((co.y + hh) / (2 * hh) * math.pi) * (1 - abs(co.x) / 2.3)
        return co

    ctx.add("Wood", displace(ply, warp))
    for y, rot in ((1.6, 1.2), (-1.5, -0.8)):
        _plank(ctx, "WoodDark", -2.45, 2.45, y - 0.2, y + 0.2, 0.1, 0.24, rot)
    ctx.wear("Wood", mul(lambda p: 0.74, cavity(0.3), patches(nz, 0.35, 1.8, 0.5, 0.8), streaks(nz, 0.35, 5.0),
                         below(-hh, -hh + 1.6, 0.3)))
    ctx.wear("WoodDark", mul(cavity(0.3), patches(nz, 0.25, 3.0), streaks(nz, 0.2, 6.0)))


def window_frame_boarded(ctx):
    """Upstairs window boarded up under a flat arch of voussoirs (the buildings whose windows
    have the arched head: see _boarded)."""
    _boarded(ctx, "arch")


def window_frame_boarded_plain(ctx):
    """Upstairs window boarded up under a plain head stone (the buildings whose windows have
    the plain head, so a boarded window keeps its neighbours' surround: see _boarded)."""
    _boarded(ctx, "plain")


def window_frame_boarded_low(ctx):
    """Ground-floor window boarded with three rough planks (as the data: 4.6 x 1.6 boards,
    nailed a little askew, alternately 0.2 and 0.4 out), one with a split corner, over the old
    stone sill. Origin: where the glass's centre would be ON the wall face (y = panel centre
    + 1, as the other ground-floor windows), -Z out."""
    ctx.budget = 2600
    nz = ctx.noise
    # stone sill (shallower here: 5.2 x 0.4 x 0.4 in the data)
    y0 = -2.6
    sec = [(-0.02, y0), (0.36, y0 - 0.05), (0.4, y0 - 0.08), (0.4, y0 - 0.36), (0.36, y0 - 0.4), (-0.02, y0 - 0.4)]
    ctx.add("Concrete", xprism(sec, -2.6, 2.6, segs=4))
    ctx.wear("Concrete", mul(cavity(0.3), patches(nz, 0.3, 2.0), streaks(nz, 0.2, 4.0)))
    for (yc, d0, rot, broken) in ((-1.6, 0.02, 3.35, None), (0.15, 0.2, -3.48, (1, 0.35, 1)),
                                  (1.9, 0.02, 2.11, None)):
        _plank(ctx, "Wood", -2.3, 2.3, yc - 0.8, yc + 0.8, d0, d0 + 0.18, rot, broken=broken)
    ctx.wear("Wood", mul(lambda p: 0.8, cavity(0.35), patches(nz, 0.35, 2.0, 0.5, 0.8), streaks(nz, 0.3, 5.0),
                         below(-2.4, -1.0, 0.35)))


# ==============================================================================================
# Through-wall air conditioners
# ==============================================================================================
def _ac(ctx, rusty):
    """A through-wall air conditioner: a steel sleeve flange on the wall, the casing (3.2 wide,
    2.0 tall, 2.2 out as the data's box), stamped side louvres, a rear condenser grille of
    vertical fins in a frame, a drain spout, two angle-iron support struts, a rust stain down
    the wall. Origin: the unit's centre ON the wall face, -Z out."""
    W, H, D = 3.2, 2.0, 2.2
    nz = ctx.noise
    # sleeve flange (on the wall, its back 0.02 into the wall)
    for y0, y1, x0, x1 in ((H / 2 - 0.02, H / 2 + 0.12, -W / 2 - 0.12, W / 2 + 0.12),
                           (-H / 2 - 0.12, -H / 2 + 0.02, -W / 2 - 0.12, W / 2 + 0.12),
                           (-H / 2, H / 2, -W / 2 - 0.12, -W / 2 + 0.02), (-H / 2, H / 2, W / 2 - 0.02, W / 2 + 0.12)):
        ctx.add("MetalPainted", dbox(x0, x1, y0, y1, -0.02, 0.07, r=0.015))
    # casing: a wrap-around cover (top, bottom, sides; open at the back where the condenser
    # grille is), its edges rounded, the top a little dented / sagging
    dents = [(ctx.rng.uniform(-1.2, 1.2), ctx.rng.uniform(0.6, 1.8)) for _ in range(3 if rusty else 1)]

    def dent(co):
        if co.y > H / 2 - 0.12:
            for dx, dd in dents:
                dist = math.hypot(co.x - dx, -co.z - dd)
                co.y -= 0.05 * max(0.0, 1 - dist / 0.5)
        co.y -= (0.04 if rusty else 0.015) * ((-co.z) / D) ** 2  # the outer end sags a little
        return co

    t = 0.06
    for x0, x1, y0, y1, n in ((-W / 2 + 0.03, W / 2 - 0.03, H / 2 - 0.03 - t, H / 2 - 0.03, (4, 1, 4)),
                              (-W / 2 + 0.03, W / 2 - 0.03, -H / 2 + 0.03, -H / 2 + 0.03 + t, (2, 1, 2)),
                              (-W / 2 + 0.03, -W / 2 + 0.03 + t, -H / 2 + 0.05, H / 2 - 0.05, (1, 2, 4)),
                              (W / 2 - 0.03 - t, W / 2 - 0.03, -H / 2 + 0.05, H / 2 - 0.05, (1, 2, 4))):
        ctx.add("MetalPainted", displace(dbox(x0, x1, y0, y1, 0.06, D - 0.02, r=0.03, n=n), dent))
    # the indoor part's back (closes the box against the wall)
    ctx.add("MetalPainted", pbox(-W / 2 + 0.08, W / 2 - 0.08, -H / 2 + 0.08, H / 2 - 0.08, 0.06, 0.12))
    # stamped louvres on both sides: 2 columns x 5 rows of short slanted lips
    for s in (-1, 1):
        for col in range(2):
            for row in range(5):
                if rusty and (col, row) in ((1, 3), (0, 0)):
                    continue  # (rusted through, gone)
                dc = 0.55 + col * 0.75
                yc = -0.55 + row * 0.27
                sec = [(-0.01, 0.0), (-0.01, 0.035), (0.05, 0.0)]
                rings = []
                for dd in (dc - 0.3, dc + 0.3):
                    rings.append([(s * (W / 2 - 0.03 + px), yc + py, -dd) for px, py in sec])
                ctx.add("MetalPainted", loft(rings, cap_start=True, cap_end=True))
    # rear grille: frame + vertical fins + a mesh guard bar
    df = D - 0.1
    ctx.add("MetalPainted", dbox(-W / 2 + 0.09, W / 2 - 0.09, H / 2 - 0.2, H / 2 - 0.09, df - 0.06, D - 0.04, r=0.02))
    ctx.add("MetalPainted", dbox(-W / 2 + 0.09, W / 2 - 0.09, -H / 2 + 0.09, -H / 2 + 0.2, df - 0.06, D - 0.04, r=0.02))
    for s in (-1, 1):
        ctx.add("MetalPainted", dbox(min(s * (W / 2 - 0.2), s * (W / 2 - 0.09)), max(s * (W / 2 - 0.2), s * (W / 2 - 0.09)),
                                     -H / 2 + 0.2, H / 2 - 0.2, df - 0.06, D - 0.04, r=0.02))
    fin_layer = "Rust" if rusty else "Metal"
    n_fins = 26
    for k in range(n_fins):
        x = lerp(-W / 2 + 0.28, W / 2 - 0.28, k / (n_fins - 1))
        if rusty and k in (7, 8, 19):
            continue  # (bent out / missing fins)
        ctx.add(fin_layer, pbox(x - 0.012, x + 0.012, -H / 2 + 0.18, H / 2 - 0.18, df - 0.25, df - 0.04))
    # coil behind the fins (dark)
    ctx.add("Black", dbox(-W / 2 + 0.2, W / 2 - 0.2, -H / 2 + 0.2, H / 2 - 0.2, df - 0.35, df - 0.25, r=0.01))
    # guard bars across the grille
    for y in (-0.35, 0.35):
        ctx.add("Metal", dbox(-W / 2 + 0.2, W / 2 - 0.2, y - 0.02, y + 0.02, df - 0.04, df + 0.0, r=0.008))
    # drain spout under the front, and the base pan (rusts first)
    ctx.add("Metal", cyl(0.05, 0.18, 8), T(W / 2 - 0.4, -H / 2 - 0.06, -(D - 0.35)))
    ctx.add("Rust" if rusty else "MetalPainted",
            dbox(-W / 2 + 0.03, W / 2 - 0.03, -H / 2 - 0.02, -H / 2 + 0.06, 0.06, D - 0.12, r=0.02, n=(4, 1, 4)))
    # support struts: angle iron from the wall 1.1 below the unit to the front corners
    for s in (-1, 1):
        x = s * (W / 2 - 0.25)
        a, b = (x, -H / 2 - 1.1, -0.03), (x, -H / 2 + 0.01, -(D - 0.3))
        angle_iron = [(-0.06, -0.06), (0.06, -0.06), (0.06, -0.04), (-0.04, -0.04), (-0.04, 0.06), (-0.06, 0.06)]
        ctx.add("Rust" if rusty else "Metal", sweep([a, b], angle_iron, side=(1, 0, 0)))
        ctx.add("Metal", dbox(x - 0.09, x + 0.09, -H / 2 - 1.25, -H / 2 - 0.95, -0.02, 0.03, r=0.01))
    # rust stain down the wall from the drain / struts (a thin sheet 0.02 off the wall)
    for x, length, w in ((W / 2 - 0.4, 2.6 if rusty else 1.4, 0.22), (-(W / 2 - 0.25), 1.3 if rusty else 0.0, 0.14)):
        if length <= 0:
            continue
        rings = []
        for k in range(7):
            t = k / 6
            y = -H / 2 - 1.25 - t * length if x < 0 else -H / 2 - 0.1 - t * length
            ww = w * (1 - 0.7 * t) * (1 + 0.2 * math.sin(k * 2.1))
            xo = 0.04 * math.sin(k * 1.3)
            rings.append([(x + xo - ww / 2, y, 0.005), (x + xo + ww / 2, y, 0.005), (x + xo + ww / 2, y, -0.012),
                          (x + xo - ww / 2, y, -0.012)])
        ctx.add("Rust", loft(rings, cap_start=True, cap_end=True))
    ctx.wear("MetalPainted", mul(cavity(0.4), edge_wear(0.08), streaks(nz, 0.35 if rusty else 0.2, 5.0),
                                 patches(nz, 0.45 if rusty else 0.2, 2.5, 0.55, 0.8),
                                 below(-H / 2, -H / 2 + 0.8, 0.3 if rusty else 0.15)))
    ctx.wear("Rust", mul(old_rust, cavity(0.25), patches(nz, 0.3, 4.0, 0.45, 0.75)))
    ctx.wear("Metal", mul(cavity(0.3), patches(nz, 0.3, 3.0, 0.5, 0.75)))


def window_ac_unit(ctx):
    """Through-wall air conditioner, painted beige-grey steel, grimy (see _ac)."""
    ctx.budget = 3600
    ctx.tint("MetalPainted", (168, 162, 146))
    _ac(ctx, False)


def window_ac_unit_rusty(ctx):
    """Through-wall air conditioner gone to rust: rusted base pan and fins, dented top, missing
    louvres and fins, long rust stains down the wall."""
    ctx.budget = 3600
    ctx.tint("MetalPainted", (150, 146, 132))
    _ac(ctx, True)


# ==============================================================================================
# Roller shutters, their hoods, garage roller doors
# ==============================================================================================
def _curtain(ctx, layer, W, H, pitch, amp, back=-0.06, segs=10, dents=(), bottom_bar=0.3, bulge=0.0):
    """The curved-slat curtain: section in (d, y) extruded along X. Each slat is a convex arc
    `amp` proud with a small interlock step; dents push the front in (kicked, rammed)."""
    y0, y1 = -H / 2 + bottom_bar, H / 2
    n = max(2, int(round((y1 - y0) / pitch)))
    p = (y1 - y0) / n
    front = []
    for k in range(n):
        ya = y0 + k * p
        # interlock (a small step back), then the curved face
        front.append((0.0, ya + 0.004))
        for t in (0.25, 0.6):
            front.append((amp * math.sin(math.pi * t) ** 0.7, ya + p * t))
        front.append((0.012, ya + p - 0.006))
    front.append((0.0, y1))
    poly = [(d, y) for d, y in front] + [(back, y1), (back, y0)]
    rings = []
    for k in range(segs + 1):
        x = lerp(-W / 2, W / 2, k / segs)
        rings.append([(x, y, -d) for d, y in poly])
    bm = loft(rings, cap_start=True, cap_end=True)

    def dent(co):
        for dx, dy, r, depth in dents:
            dist = math.hypot(co.x - dx, (co.y - dy) * 1.4)
            co.z += depth * max(0.0, 1 - (dist / r) ** 2) ** 2
        co.z -= bulge * math.sin(math.pi * (co.x + W / 2) / W) * math.sin(math.pi * (co.y - y0) / (y1 - y0))
        return co

    ctx.add(layer, displace(bm, dent))


def _bottom_bar(ctx, W, H, layer, handles=True, rubber=True, d_front=0.13):
    """The bottom bar: an angle with a front lip, the rubber seal under it, lift handles."""
    y0 = -H / 2
    sec = [(-0.07, y0 + 0.02), (d_front, y0 + 0.02), (d_front, y0 + 0.3), (d_front - 0.04, y0 + 0.3),
           (d_front - 0.04, y0 + 0.08), (-0.07, y0 + 0.08)]
    ctx.add(layer, xprism(sec, -W / 2, W / 2, segs=8))
    ctx.add(layer, dbox(-W / 2, W / 2, y0 + 0.02, y0 + 0.3, -0.08, 0.02, r=0.015, n=(4, 1, 1)))
    if rubber:
        ctx.add("Rubber", dbox(-W / 2 + 0.02, W / 2 - 0.02, y0 + 0.005, y0 + 0.03, -0.05, d_front - 0.02, r=0.01,
                               n=(2, 1, 1)))
    if handles:
        for x in (-W / 4, W / 4):
            pts = [(x - 0.25, y0 + 0.2, -d_front), (x - 0.22, y0 + 0.2, -d_front - 0.12),
                   (x + 0.22, y0 + 0.2, -d_front - 0.12), (x + 0.25, y0 + 0.2, -d_front)]
            ctx.add("Metal", sweep(pts, circle2(0.035, 6), side=(0, 1, 0)))


def _guide(ctx, x_in, x_out, H, d0, d1, layer="Metal"):
    """A C-channel guide rail: back, two cheeks (the curtain runs between them)."""
    s = 1 if x_out > x_in else -1
    xa, xb = min(x_in, x_out), max(x_in, x_out)
    ctx.add(layer, dbox(xa, xb, -H / 2, H / 2, d0, d0 + 0.05, r=0.01, n=(1, 3, 1)))
    ctx.add(layer, dbox(xa, xb, -H / 2, H / 2, d1 - 0.05, d1, r=0.01, n=(1, 3, 1)))
    xw = x_out - s * 0.05
    ctx.add(layer, dbox(min(xw, x_out), max(xw, x_out), -H / 2, H / 2, d0, d1, r=0.01, n=(1, 3, 1)))
    # fixing bolts down the outer cheek
    for y in (-H / 2 + 0.8, 0.0, H / 2 - 0.8):
        ctx.add("Metal", cyl(0.04, 0.02, 6), T((xa + xb) / 2, y, -d1 - 0.008) @ R(90, 0, 0))


def _padlock(ctx, x, y, d):
    """Hasp and staple on the bottom bar, a heavy steel padlock hanging from it."""
    ctx.add("Metal", dbox(x - 0.3, x - 0.04, y - 0.1, y + 0.18, d, d + 0.03, r=0.01))
    ctx.add("Metal", dbox(x + 0.04, x + 0.3, y - 0.1, y + 0.18, d, d + 0.03, r=0.01))
    ctx.add("Metal", sweep([(x - 0.07, y - 0.15, -d - 0.03), (x - 0.07, y + 0.02, -d - 0.12),
                            (x + 0.07, y + 0.02, -d - 0.12), (x + 0.07, y - 0.15, -d - 0.03)],
                           circle2(0.02, 6), side=(0, 1, 0)))
    # padlock body (laminated steel: a rounded block) + shackle
    ctx.add("Chrome", sweep(spline([(x - 0.08, y - 0.2, -d - 0.1), (x - 0.08, y - 0.05, -d - 0.1),
                                    (x, y + 0.02, -d - 0.1), (x + 0.08, y - 0.05, -d - 0.1),
                                    (x + 0.08, y - 0.2, -d - 0.1)], 3), circle2(0.025, 6), side=(0, 0, 1)))
    ctx.add("Metal", bx(x - 0.15, x + 0.15, y - 0.5, y - 0.18, -d - 0.17, -d - 0.04, r=0.035, n=(1, 3, 1)))


def _shutter(ctx, rusty):
    """Shop roller shutter on the data's 15.2 x 7.6 curtain (see the module doc). Origin: the
    curtain's centre (the old Shutter part's centre), -Z out (the wall face is 0.65 out)."""
    W, H = 15.2, 7.6
    nz = ctx.noise
    dents = [(-4.1, -2.2, 1.2, 0.07), (5.3, -2.9, 0.8, 0.05)] if rusty else [(2.6, -2.6, 0.9, 0.035)]
    _curtain(ctx, "MetalPainted", W + 0.3, H, 0.3, 0.06, back=-0.09, segs=20, dents=dents, bulge=0.03)
    _bottom_bar(ctx, W + 0.3, H, "Rust" if rusty else "Metal")
    for s in (-1, 1):
        # (galvanised guides even on the rusty one: they rust at the foot only, see the wear)
        _guide(ctx, s * 7.58, s * 8.0, H, -0.2, 0.62, "Metal")
    # (the hasp's staple welded on the bar's top lip: the padlock body hangs in front of the
    # bar and stops just above the pavement)
    _padlock(ctx, 0.0, -H / 2 + 0.45, 0.13)
    # (grime kept low-contrast: the curtain has a vertex every ~0.8 stud across, so strong
    # streaks read as blotches; the dirt rises from the pavement, the soot runs under the hood)
    ctx.wear("MetalPainted", mul(cavity(0.3), below(-H / 2, -H / 2 + 2.2, 0.4 if rusty else 0.28),
                                 streaks(nz, 0.14 if rusty else 0.08, 6.0), scuffs(nz, 0.08, 0.8, 0.65),
                                 soot_under((-5.5, -1.0, 3.8), H / 2, 2.0, 0.6, 0.1 if rusty else 0.05)))
    ctx.wear("Metal", mul(cavity(0.35), below(-H / 2, -H / 2 + 1.5, 0.55 if rusty else 0.35), streaks(nz, 0.12, 6.0)))
    ctx.wear("Rust", mul(old_rust, cavity(0.3), patches(nz, 0.3, 3.0, 0.45, 0.75), below(-H / 2, -H / 2 + 1.0, 0.25)))


def roller_shutter_shop(ctx):
    """Galvanised shop roller shutter: curved slats, C-channel guides, bottom bar with seal and
    lift handles, hasp and padlock; one shallow dent, grime rising from the pavement."""
    ctx.budget = 7600
    ctx.tint("MetalPainted", (128, 132, 130))
    _shutter(ctx, False)


def roller_shutter_shop_rusty(ctx):
    """The same shutter years later: rammed dents low down, rusted bottom bar and guides, rust
    streaks running down the slats."""
    ctx.budget = 7600
    ctx.tint("MetalPainted", (112, 116, 112))
    _shutter(ctx, True)


def shutter_box_hood(ctx):
    """The roll housing over a shop shutter (data: 16 x 1.0 x 1.4 box, 0.2 proud of the wall):
    a folded steel hood with a rounded front, a drip flashing on top, end plates with bolts,
    rust running from the joints. Origin: the old ShutterBox's centre, -Z out."""
    ctx.budget = 2400
    ctx.tint("MetalPainted", (104, 108, 104))
    W, H, D = 16.0, 1.0, 1.4
    nz = ctx.noise
    # hood: section (d, y) front curved under, back open into the wall
    sec = [(-0.7, H / 2 - 0.02), (0.62, H / 2 - 0.02), (0.68, H / 2 - 0.06), (0.69, 0.0), (0.66, -0.25),
           (0.56, -0.42), (0.42, -0.49), (0.2, -0.49), (0.2, -0.43), (0.4, -0.43), (0.5, -0.37),
           (0.6, -0.22), (0.62, 0.0), (0.62, H / 2 - 0.08), (-0.7, H / 2 - 0.08)]
    ctx.add("MetalPainted", xprism(sec, -W / 2 + 0.06, W / 2 - 0.06, segs=14))
    # drip flashing on top (sloped, sealed to the wall)
    fl = [(-0.05, H / 2 + 0.08), (0.72, H / 2 - 0.0), (0.72, H / 2 - 0.03), (-0.05, H / 2 - 0.015)]
    ctx.add("Metal", xprism(fl, -W / 2, W / 2, segs=10))
    # end plates
    for s in (-1, 1):
        ctx.add("MetalPainted", dbox(s * (W / 2 - 0.07), s * (W / 2 - 0.0), -H / 2 + 0.01, H / 2 - 0.02, -0.7, 0.66,
                                     r=0.02))
        for y, d in ((0.25, 0.3), (-0.2, 0.3), (0.25, -0.3)):
            ctx.add("Metal", cyl(0.04, 0.03, 6), T(s * W / 2 + s * 0.012, y, -d) @ R(0, 0, 90))
    # joints of the hood sheets (cover straps), the shutter's roll seen through the slot (dark)
    for x in (-W / 6, W / 6):
        ctx.add("MetalPainted", dbox(x - 0.06, x + 0.06, -0.3, H / 2 - 0.05, 0.6, 0.715, r=0.01))
    ctx.add("Black", dbox(-W / 2 + 0.1, W / 2 - 0.1, -0.45, -0.1, -0.6, 0.18, r=0.05))
    ctx.wear("MetalPainted", mul(cavity(0.35), streaks(nz, 0.3, 3.0), soot_under((-W / 6, W / 6), 0.4, 1.0, 0.3, 0.35),
                                 patches(nz, 0.25, 1.4, 0.6, 0.85), edge_wear(0.08)))
    ctx.wear("Metal", mul(cavity(0.3), patches(nz, 0.3, 2.0)))


def _garage(ctx, W, worn, H=10.0):
    """Garage roller door on the data's W x H curtain: wide flat-ribbed slats, wind-lock
    clips on their ends, guide channels inside the opening, bottom bar with seal, centre lock
    and two lift handles. Origin: the curtain's centre (the old RollerDoor), -Z out."""
    nz = ctx.noise
    dents = [(W * 0.18, -3.4, 1.3, 0.09), (-W * 0.3, -4.0, 0.7, 0.05)] if worn else [(-W * 0.22, -3.8, 0.8, 0.04)]
    _curtain(ctx, "MetalPainted", W - 0.1, H, 0.36, 0.045, back=-0.08, segs=18, dents=dents, bulge=0.04,
             bottom_bar=0.32)
    _bottom_bar(ctx, W - 0.1, H, "Rust" if worn else "Metal", handles=True)
    # centre lock: a round barrel lock in a plate
    ctx.add("Metal", dbox(-0.2, 0.2, -H / 2 + 1.0, -H / 2 + 1.5, 0.05, 0.09, r=0.02))
    ctx.add("Chrome", cyl(0.07, 0.05, 12, bevel=0.01), T(0, -H / 2 + 1.3, -0.11) @ R(90, 0, 0))
    for s in (-1, 1):
        _guide(ctx, s * (W / 2 - 0.3), s * (W / 2 - 0.02), H, -0.15, 0.45, "Metal")
        # wind-lock clips: small blocks on the slat ends inside the channel's mouth
        for k in range(1, 26, 3):
            y = -H / 2 + 0.32 + k * 0.36
            if y < H / 2 - 0.2:
                ctx.add("Metal", pbox(min(s * (W / 2 - 0.36), s * (W / 2 - 0.3)), max(s * (W / 2 - 0.36), s * (W / 2 - 0.3)), y - 0.06, y + 0.06, 0.0, 0.07))
    ctx.wear("MetalPainted", mul(cavity(0.3), below(-H / 2, -H / 2 + 2.6, 0.42 if worn else 0.28),
                                 streaks(nz, 0.14 if worn else 0.08, 6.0), scuffs(nz, 0.08, 0.8, 0.65),
                                 soot_under((-W * 0.3, W * 0.1, W * 0.35), H / 2, 2.5, 0.7, 0.1 if worn else 0.05)))
    ctx.wear("Metal", mul(cavity(0.35), below(-H / 2, -H / 2 + 1.5, 0.35), streaks(nz, 0.2, 4.0)))
    ctx.wear("Rust", mul(old_rust, cavity(0.3), patches(nz, 0.3, 3.0, 0.45, 0.75), below(-H / 2, -H / 2 + 1.0, 0.25)))


def roller_door_garage(ctx):
    """Garage roller door, 12 x 10 (grey galvanised, see _garage)."""
    ctx.budget = 7000
    ctx.tint("MetalPainted", (116, 120, 118))
    _garage(ctx, 12.0, False)


def roller_door_garage_worn(ctx):
    """Garage roller door, 12 x 10, rammed and rusting at the bottom."""
    ctx.budget = 7000
    ctx.tint("MetalPainted", (104, 108, 104))
    _garage(ctx, 12.0, True)


def roller_door_garage_narrow(ctx):
    """Garage roller door, 9.8 x 10 (the lock-up at L)."""
    ctx.budget = 7000
    ctx.tint("MetalPainted", (108, 112, 108))
    _garage(ctx, 9.8, True)


def roller_door_dock(ctx):
    """Loading-dock roller door, 10 x 9 (B13's two dock doors over the dock walls), worn: the
    forklifts' scrapes and a rusting bottom bar."""
    ctx.budget = 7000
    ctx.tint("MetalPainted", (100, 106, 102))
    _garage(ctx, 10.0, True, H=9.0)


# ==============================================================================================
# Shop fronts
# ==============================================================================================
def _moulded_bar(ctx, layer, x0, x1, y0, y1, d0, d1, vertical, cap=0.05, n=4):
    """A moulded glazing bar / frame member: a flat face with a rounded cap moulding on its
    outer face (a half-round along its length)."""
    ctx.add(layer, dbox(x0, x1, y0, y1, d0, d1, r=0.02, n=(1, n, 1) if vertical else (n, 1, 1)))
    if cap > 0:
        if vertical:
            xc = (x0 + x1) / 2
            ctx.add(layer, cyl(cap, y1 - y0 - 0.04, 10), T(xc, (y0 + y1) / 2, -d1 + cap * 0.35))
        else:
            yc = (y0 + y1) / 2
            ctx.add(layer, cyl(cap, x1 - x0 - 0.04, 10), T((x0 + x1) / 2, yc, -d1 + cap * 0.35) @ R(0, 0, 90))


def _shopfront(ctx, W, mullions, H=7.4, transom=True):
    """The glazing frame of a shop window W x H (data ShopGlass, 0.3 thick, its centre in the
    middle of a 1.2 wall: the wall face is 0.6 out): outer frame and beads in front of the
    glass, thin beads behind it, mullions with caps, a transom bar 1.6 under the head (top
    lights), a sloped cill projecting over the stall riser. Origin: the glass's centre."""
    hw, hh = W / 2, H / 2
    L = "MetalPainted"
    nz = ctx.noise
    g = 0.17  # the glass's face is 0.15 out: frames start 0.02 off it
    # outer frame: stiles and head, a glazing bead inside them
    for s in (-1, 1):
        ctx.add(L, dbox(s * (hw - 0.32), s * (hw - 0.005), -hh + 0.25, hh - 0.005, g, 0.52, r=0.025, n=(1, 3, 1)))
        ctx.add(L, dbox(s * (hw - 0.42), s * (hw - 0.3), -hh + 0.25, hh - 0.3, g, 0.27, r=0.015, n=(1, 3, 1)))
        # behind the glass: a thin bead
        ctx.add(L, dbox(s * (hw - 0.2), s * (hw - 0.005), -hh + 0.05, hh - 0.005, -0.32, -g, r=0.015, n=(1, 2, 1)))
    ctx.add(L, dbox(-hw + 0.3, hw - 0.3, hh - 0.32, hh - 0.005, g, 0.52, r=0.025, n=(2, 1, 1)))
    ctx.add(L, dbox(-hw + 0.3, hw - 0.3, hh - 0.42, hh - 0.3, g, 0.27, r=0.015, n=(2, 1, 1)))
    ctx.add(L, dbox(-hw + 0.2, hw - 0.2, hh - 0.2, hh - 0.005, -0.32, -g, r=0.015, n=(2, 1, 1)))
    # bottom rail + sloped cill: over the stall riser's top (the riser's face is 0.6 out)
    y0 = -hh
    sec = [(-0.32, y0 + 0.02), (-0.32, y0 + 0.12), (-g, y0 + 0.12), (-g, y0 + 0.3), (g, y0 + 0.3), (g, y0 + 0.36),
           (0.3, y0 + 0.34), (0.68, y0 + 0.14), (0.72, y0 + 0.1), (0.72, y0 - 0.03), (0.66, y0 - 0.06),
           (0.6, y0 - 0.06), (0.6, y0 + 0.02)]
    ctx.add(L, xprism(sec, -hw + 0.005, hw - 0.005, segs=8))
    # mullions (face + cap outside, bead inside)
    for x in mullions:
        _moulded_bar(ctx, L, x - 0.16, x + 0.16, -hh + 0.3, hh - 0.3, g, 0.45, True, 0.055)
        ctx.add(L, dbox(x - 0.09, x + 0.09, -hh + 0.12, hh - 0.2, -0.3, -g, r=0.015, n=(1, 2, 1)))
    if transom:
        yt = hh - 1.6
        xs = [-hw + 0.3] + sorted(mullions) + [hw - 0.3]
        for a, b in zip(xs, xs[1:]):
            a2 = a + (0.15 if a != xs[0] else 0.0)
            b2 = b - (0.15 if b != xs[-1] else 0.0)
            _moulded_bar(ctx, L, a2, b2, yt - 0.12, yt + 0.12, g, 0.42, False, 0.045)
            ctx.add(L, dbox(a2, b2, yt - 0.07, yt + 0.07, -0.29, -g, r=0.015))
    ctx.wear(L, mul(cavity(0.35), edge_wear(0.1), below(-hh, -hh + 1.6, 0.35), streaks(nz, 0.2, 4.0),
                    patches(nz, 0.3, 2.2, 0.62, 0.82)))


def _sf(W, mullions, tint, doc):
    def build(ctx):
        ctx.budget = 3400
        ctx.tint("MetalPainted", tint)
        _shopfront(ctx, W, mullions)

    build.__doc__ = doc
    return build


shopfront_frame_10 = _sf(10.0, (0.0,), (34, 52, 44),
                         "Shop-window glazing frame for a 10 x 7.4 glass: moulded timber frame and beads, one "
                         "capped mullion, a transom bar (top lights), sloped cill over the stall riser.")
shopfront_frame_12 = _sf(12.0, (0.0,), (34, 52, 44), "As ShopfrontFrame10, for a 12 x 7.4 glass.")
shopfront_frame_14 = _sf(14.0, (-2.33, 2.33), (34, 52, 44), "As ShopfrontFrame10, 14 x 7.4, two mullions.")
shopfront_frame_16 = _sf(16.0, (-2.67, 2.67), (34, 52, 44), "As ShopfrontFrame10, 16 x 7.4, two mullions.")


def shopfront_door_frame(ctx):
    """Interwar aluminium shop front with its entrance door (data: the 14.4 x 5.6 glass of the
    liquor store and the corner shop, two mullions, the door at the left end): extruded frames
    (box sections with a glazing bead), mullions, the door leaf (stiles, top rail, a brushed
    kick plate, a transom light above the door). The push bar is PushBarHardware. Origin: the
    glass's centre, -Z out (the push-bar side)."""
    ctx.budget = 3600
    ctx.tint("MetalPainted", (52, 48, 44))
    W, H = 14.4, 5.6
    hw, hh = W / 2, H / 2
    L = "MetalPainted"
    nz = ctx.noise
    g = 0.17
    for s in (-1, 1):
        ctx.add(L, dbox(s * (hw - 0.25), s * (hw - 0.005), -hh + 0.005, hh - 0.005, g, 0.42, r=0.02, n=(1, 3, 1)))
        ctx.add(L, dbox(s * (hw - 0.18), s * (hw - 0.005), -hh + 0.005, hh - 0.005, -0.3, -g, r=0.015, n=(1, 2, 1)))
    for y0, y1 in ((hh - 0.25, hh - 0.005), (-hh + 0.005, -hh + 0.22)):
        ctx.add(L, dbox(-hw + 0.24, hw - 0.24, y0, y1, g, 0.42, r=0.02, n=(2, 1, 1)))
        ctx.add(L, dbox(-hw + 0.17, hw - 0.17, y0, y1, -0.3, -g, r=0.015, n=(2, 1, 1)))
    for x in (-2.4, 2.4):
        ctx.add(L, dbox(x - 0.25, x + 0.25, -hh + 0.21, hh - 0.24, g, 0.33, r=0.02, n=(1, 3, 1)))
        ctx.add(L, dbox(x - 0.15, x + 0.15, -hh + 0.21, hh - 0.24, 0.32, 0.36, r=0.012, n=(1, 3, 1)))
        ctx.add(L, dbox(x - 0.12, x + 0.12, -hh + 0.15, hh - 0.18, -0.3, -g, r=0.012, n=(1, 2, 1)))
    # the door leaf: stiles at -2.8 and -7.05, its top rail at +2.25, the kick rail
    for x in (-2.8, -7.05):
        ctx.add(L, dbox(x - 0.16, x + 0.16, -hh + 0.22, 2.4, g, 0.36, r=0.02, n=(1, 3, 1)))
    ctx.add(L, dbox(-6.9, -2.95, 2.1, 2.42, g, 0.36, r=0.02, n=(2, 1, 1)))
    ctx.add(L, dbox(-6.9, -2.95, -hh + 0.22, -hh + 1.25, g, 0.3, r=0.02, n=(2, 1, 1)))
    ctx.add("Metal", dbox(-6.88, -2.97, -hh + 0.3, -hh + 1.15, 0.3, 0.33, r=0.008, n=(2, 1, 1)))
    # transom bar over the door (the light above it)
    ctx.add(L, dbox(-7.05, -2.4, 2.42, 2.62, g, 0.33, r=0.02))
    # hinges on the left stile, a lock cylinder on the right one
    for y in (-1.6, 1.7):
        ctx.add("Metal", cyl(0.05, 0.35, 8), T(-7.24, y, -0.3))
    ctx.add("Chrome", cyl(0.045, 0.04, 10, bevel=0.008), T(-2.8, -0.9, -0.38) @ R(90, 0, 0))
    ctx.wear(L, mul(cavity(0.35), edge_wear(0.12), below(-hh, -hh + 1.2, 0.35), streaks(nz, 0.15, 4.0),
                    scuffs(nz, 0.25, 2.0, 0.62)))
    ctx.wear("Metal", mul(cavity(0.3), scuffs(nz, 0.35, 3.0, 0.5)))


def push_bar_hardware(ctx):
    """A shop door's push bar: a brushed stainless oval tube on two cranked stand-offs, rosettes
    on the stiles, the middle rubbed brighter by hands (edge wear), grimy ends. 3.95 long as
    the data's bar. Origin: the old PushBar's centre, -Z out."""
    ctx.budget = 1400
    nz = ctx.noise
    L = 4.25
    # oval bar
    pts = [(x, 0.0, -0.05) for x in (-1.9, -1.0, 0.0, 1.0, 1.9)]
    sec = [(0.055 * math.cos(a), 0.075 * math.sin(a)) for a in [2 * math.pi * k / 14 for k in range(14)]]
    ctx.add("Metal", sweep(pts, sec, side=(0, 1, 0)))
    for s in (-1, 1):
        x = s * (L / 2 - 0.1)
        # end cap + cranked stand-off back to the stile
        ctx.add("Metal", sweep(spline([(s * 1.88, 0.0, -0.05), (s * 2.0, 0.0, -0.03), (x, 0.0, 0.04),
                                       (x, 0.0, 0.11)], 4), circle2(0.04, 8), side=(0, 1, 0)))
        ctx.add("Metal", cyl(0.09, 0.025, 12, bevel=0.008), T(x, 0.0, 0.11) @ R(90, 0, 0))
    ctx.wear("Metal", mul(cavity(0.35), scuffs(nz, 0.3, 4.0, 0.55),
                          lambda p: 1 - 0.25 * smoothstep(0.6, 2.0, abs(p.co.x))))


# ==============================================================================================
# Awnings
# ==============================================================================================
AW_W, AW_D, AW_DROP = 16.0, 3.86, 1.04  # width, projection, drop of the front edge (15 degrees)


def _solid_sheet(ctx, layer, faces_fn, nu, nv, pos, thick=0.05, keep=lambda i, j: True):
    """A thin canvas: a grid (nu x nv cells; pos(u, v) -> (x, y, z)) of the kept cells, made
    solid (bmesh solidify) so it reads from both sides; faces_fn(i, j) picks the cells of this
    layer (the stripes)."""
    bm = bmesh.new()
    verts = {}

    def V(i, j):
        if (i, j) not in verts:
            verts[(i, j)] = bm.verts.new(pos(i / nu, j / nv))
        return verts[(i, j)]

    faces = []
    for i in range(nu):
        for j in range(nv):
            if faces_fn(i, j) and keep(i, j):
                faces.append(bm.faces.new((V(i, j), V(i + 1, j), V(i + 1, j + 1), V(i, j + 1))))
    if not faces:
        bm.free()
        return
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thick)
    ctx.add(layer, bm)


def _awning(ctx, torn):
    """A retractable shop awning. Origin: the middle of the roller bar where it meets the
    fascia, -Z out; the canvas slopes 15 degrees down to the front bar 3.86 out, the valance
    hangs 0.65 under it. Stripes: shop colour (Fabric, tinted) / cream (Foam)."""
    nz = ctx.noise
    nu, nv = 64, 14  # 64 stripes-cells across (4 per stripe pair), 14 down the slope
    stripe = 4  # cells per stripe: 16 / 64 * 4 = 1.0 stud stripes

    def canvas(u, v):
        x = lerp(-AW_W / 2, AW_W / 2, u)
        d = AW_D * v
        y = -AW_DROP * v
        # sag between the arms, more at the front; wind ripple
        sag = (0.18 if torn else 0.08) * math.sin(math.pi * u) * v ** 1.5
        y -= sag + 0.02 * math.sin(u * 37.0) * v
        if torn:
            y -= 0.25 * max(0.0, 1 - abs(u - 0.7) / 0.12) * v ** 2  # a slack, torn bay
        return (x, y, -d)

    def hole(i, j):
        if not torn:
            return True
        u, v = (i + 0.5) / nu, (j + 0.5) / nv
        for hu, hv, r in ((0.7, 0.55, 0.06), (0.25, 0.8, 0.035), (0.62, 0.86, 0.04)):
            if math.hypot((u - hu) * 3.0, v - hv) < r * 3 * (0.8 + 0.4 * nz.n((i * 0.7, j * 0.7, 3.0))):
                return False
        return True

    _solid_sheet(ctx, "Fabric", lambda i, j: (i // stripe) % 2 == 0, nu, nv, canvas, 0.05, hole)
    _solid_sheet(ctx, "Foam", lambda i, j: (i // stripe) % 2 == 1, nu, nv, canvas, 0.05, hole)
    # valance: hangs from the front bar, scalloped bottom edge (one scallop per stripe)
    nvv = 4

    def valance(u, v):
        x, y, z = canvas(u, 1.0)
        sc = abs(math.sin(math.pi * u * 16))  # 16 scallops
        depth = 0.45 + 0.2 * sc
        flap = 0.0
        if torn and 0.33 < u < 0.42:
            flap = 0.5 * math.sin(math.pi * (u - 0.33) / 0.09)  # a torn strip hanging lower
        return (x, y - 0.04 - (depth + flap) * v, z - 0.06 - 0.03 * v)

    _solid_sheet(ctx, "Fabric", lambda i, j: (i // stripe) % 2 == 0, nu, nvv, valance, 0.04)
    _solid_sheet(ctx, "Foam", lambda i, j: (i // stripe) % 2 == 1, nu, nvv, valance, 0.04)
    # roller bar and its wall brackets, front bar
    ctx.add("Metal", cyl(0.14, AW_W - 0.1, 16), T(0, 0.02, 0.02) @ R(0, 0, 90))
    front = canvas(0.5, 1.0)
    ctx.add("Metal", dbox(-AW_W / 2 + 0.1, AW_W / 2 - 0.1, front[1] - 0.12, front[1] + 0.05,
                                 -front[2] - 0.08, -front[2] + 0.08, r=0.03, n=(5, 1, 1)))
    for s in (-1, 1):
        x = s * 7.4
        # wall bracket at the bottom of the arm, the folding arm (two members with an elbow)
        wb = Vector((x, -2.06, 0.56))
        fb = Vector((x, front[1] - 0.05, front[2] + 0.05))
        elbow = (wb + fb) / 2 + Vector((-s * 0.25, -0.35, 0))
        if torn and s > 0:
            elbow += Vector((0, -0.25, 0))  # a bent arm
        ctx.add("Metal", dbox(x - 0.15, x + 0.15, -2.3, -1.8, -0.62, -0.5, r=0.03))
        ctx.add("Metal", sweep([tuple(wb), tuple(elbow)], rrect2(0.09, 0.12, 0.03, 2), side=(1, 0, 0)))
        ctx.add("Metal", sweep([tuple(elbow), tuple(fb)], rrect2(0.08, 0.1, 0.03, 2), side=(1, 0, 0)))
        ctx.add("Metal", cyl(0.07, 0.16, 10), T(elbow.x, elbow.y, elbow.z) @ R(0, 0, 90))
        ctx.add("Metal", dbox(x - 0.2, x + 0.2, -0.18, 0.18, -0.6, 0.1, r=0.03))  # roller bracket
    ctx.wear("Fabric", mul(streaks(nz, 0.35 if torn else 0.22, 3.0), patches(nz, 0.3 if torn else 0.15, 1.2, 0.55, 0.8),
                           lambda p: 1 - 0.2 * smoothstep(1.5, 3.9, -p.co.z), cavity(0.2)))
    ctx.wear("Foam", mul(streaks(nz, 0.4 if torn else 0.28, 3.0), patches(nz, 0.35 if torn else 0.2, 1.2, 0.55, 0.8),
                         lambda p: 1 - 0.25 * smoothstep(1.5, 3.9, -p.co.z), cavity(0.2)))
    ctx.wear("Metal", mul(cavity(0.3), edge_wear(0.1), patches(nz, 0.3, 3.0)))


def shop_awning_fabric(ctx):
    """Striped retractable awning, 16 wide, 3.86 out at 15 degrees, scalloped valance, two
    folding arms, sag and rain streaks (see _awning). Tint = the shop's colour."""
    ctx.budget = 7800
    ctx.tint("Fabric", (44, 52, 65))
    _awning(ctx, False)


def shop_awning_torn(ctx):
    """The same awning neglected: holes torn through the canvas, a slack bay, a strip of the
    valance hanging, a bent arm, heavier stains."""
    ctx.budget = 7800
    ctx.tint("Fabric", (73, 41, 38))
    _awning(ctx, True)


# ==============================================================================================
# Bracket lantern
# ==============================================================================================
def wall_lantern(ctx):
    """A wrought-iron bracket lantern: a scrolled swan-neck bracket from a back plate, the
    lantern hanging under it on a short chain-like stem (square tapered body, four glass panes
    = Glow, a pyramid roof with a finial, a smoke cap). Origin: on the wall face, at the
    bracket's height; the lantern's bulb (Light marker) 1.6 out and 0.9 below."""
    ctx.budget = 2600
    nz = ctx.noise
    # back plate
    ctx.add("Black", dbox(-0.22, 0.22, -0.4, 0.4, -0.02, 0.06, r=0.03))
    # swan-neck bracket: main arm + a scroll under it
    arm = spline([(0, 0.15, -0.06), (0, 0.32, -0.6), (0, 0.3, -1.2), (0, 0.18, -1.6)], 5)
    ctx.add("Black", sweep(arm, rrect2(0.07, 0.07, 0.02, 1), side=(1, 0, 0)))
    scroll = spline([(0, -0.3, -0.06), (0, -0.2, -0.45), (0, 0.05, -0.8), (0, 0.22, -0.95)], 5)
    ctx.add("Black", sweep(scroll, rrect2(0.05, 0.05, 0.015, 1), side=(1, 0, 0)))
    curl = [(0, -0.3 + 0.08 * math.sin(a), -0.06 - 0.08 + 0.08 * math.cos(a)) for a in
            [math.pi * k / 6 for k in range(10)]]
    ctx.add("Black", sweep(curl, rrect2(0.045, 0.045, 0.012, 1), side=(1, 0, 0)))
    # hook and stem
    ctx.add("Black", cyl(0.03, 0.3, 6), T(0, 0.04, -1.6))
    yt = -0.12  # lantern roof top
    # roof: square pyramid with flared eaves, finial, smoke cap
    roof = loft([[(-0.36, yt - 0.3, -1.6 - 0.36), (0.36, yt - 0.3, -1.6 - 0.36), (0.36, yt - 0.3, -1.6 + 0.36),
                  (-0.36, yt - 0.3, -1.6 + 0.36)],
                 [(-0.3, yt - 0.24, -1.6 - 0.3), (0.3, yt - 0.24, -1.6 - 0.3), (0.3, yt - 0.24, -1.6 + 0.3),
                  (-0.3, yt - 0.24, -1.6 + 0.3)],
                 [(-0.09, yt - 0.02, -1.6 - 0.09), (0.09, yt - 0.02, -1.6 - 0.09), (0.09, yt - 0.02, -1.6 + 0.09),
                  (-0.09, yt - 0.02, -1.6 + 0.09)]], cap_start=True, cap_end=True)
    ctx.add("Black", roof)
    ctx.add("Black", cyl(0.06, 0.08, 8), T(0, yt + 0.02, -1.6))
    # body: tapered frame (corner posts) with glass panes between, a base
    ytop, ybot = yt - 0.3, yt - 1.05
    for sx in (-1, 1):
        for sz in (-1, 1):
            a = (sx * 0.3, ytop, -1.6 + sz * 0.3)
            b = (sx * 0.22, ybot, -1.6 + sz * 0.22)
            ctx.add("Black", sweep([a, b], rrect2(0.045, 0.045, 0.012, 1), side=(1, 0, 0)))
    rings = []
    for y, h in ((ytop - 0.01, 0.275), (ybot + 0.01, 0.2)):
        rings.append([(-h, y, -1.6 - h), (h, y, -1.6 - h), (h, y, -1.6 + h), (-h, y, -1.6 + h)])
    ctx.add("Glow", loft(rings, cap_start=True, cap_end=True))
    ctx.add("Black", dbox(-0.26, 0.26, ybot - 0.1, ybot + 0.01, 1.34, 1.86, r=0.03))
    ctx.add("Black", cyl(0.05, 0.12, 8), T(0, ybot - 0.15, -1.6))
    ctx.mark("Light", (0, (ytop + ybot) / 2, -1.6))
    ctx.wear("Black", mul(cavity(0.3), patches(nz, 0.25, 4.0)))
    ctx.wear("Glow", mul(lambda p: 1 - 0.3 * smoothstep(ybot, ybot + 0.25, p.co.y) * 0.0, cavity(0.0)))


PIECES = {
    "WindowFrameSash": window_frame_sash,
    "WindowFrameSashPlain": window_frame_sash_plain,
    "WindowFrameBlind": window_frame_blind,
    "WindowFrameBlindLow": window_frame_blind_low,
    "WindowFrameSashLow": window_frame_sash_low,
    "WindowFrameBarred": window_frame_barred,
    "WindowFrameBoarded": window_frame_boarded,
    "WindowFrameBoardedPlain": window_frame_boarded_plain,
    "WindowFrameBoardedLow": window_frame_boarded_low,
    "WindowAcUnit": window_ac_unit,
    "WindowAcUnitRusty": window_ac_unit_rusty,
    "RollerShutterShop": roller_shutter_shop,
    "RollerShutterShopRusty": roller_shutter_shop_rusty,
    "ShutterBoxHood": shutter_box_hood,
    "RollerDoorGarage": roller_door_garage,
    "RollerDoorGarageWorn": roller_door_garage_worn,
    "RollerDoorGarageNarrow": roller_door_garage_narrow,
    "RollerDoorDock": roller_door_dock,
    "ShopfrontFrame10": shopfront_frame_10,
    "ShopfrontFrame12": shopfront_frame_12,
    "ShopfrontFrame14": shopfront_frame_14,
    "ShopfrontFrame16": shopfront_frame_16,
    "ShopfrontDoorFrame": shopfront_door_frame,
    "PushBarHardware": push_bar_hardware,
    "ShopAwningFabric": shop_awning_fabric,
    "ShopAwningTorn": shop_awning_torn,
    "WallLantern": wall_lantern,
}
