"""The two shops' furniture as kit meshes: REWIND (Interiors/Rewind, the video and record store
with its dance stage) and HOLLOW THREADS (Interiors/Threadbare, the second-hand clothes shop).

REWIND: the record browser bins (cabinet + sloped bin + ~80 LP sleeves leaning in four rows),
the portable TVs on top of the CRT wall, the old electronic cash register, the DJ turntable and
the stack of VHS tapes on the counter, the stocked VHS wall shelf (spine-out back catalogue and
face-out new releases), the floor PA speakers and the mic stand of the dance stage, the upright
arcade cabinet, the mirror ball.
HOLLOW THREADS: the fibreglass mannequins of the window displays (body + stand, and their top
and trousers as separate pieces: see MANNEQUINS below), shirts and hoodies on hangers, the
folded tee stacks, the sneakers on the shelf, the wall shelving with its base cupboards and end
cupboard, the reclaimed-wood display table, the fitting room's velvet curtains and its leaning
floor mirror, the till (a modern POS: touchscreen, cash drawer, card reader, receipt printer).

Why meshes: these shops were boxes (a brown box for a record bin with 48 flat cards, a grey
box with a black square for a till, ten blocky R6 parts for a mannequin, a slab for a
curtain). Each object here is modelled from the real one and worn the way a cheap shop wears
things: kicked plinths, rubbed edges where hands go, sun-faded sleeves, yellowed beige plastic,
dust on top of everything high.

Scale (PLAN.md, scale note): the shops' interiors are sized to the R6 body, not 0.28 m a stud:
every piece takes the footprint and heights of the parts it replaces (record bin 6 x 3 x 3,
counter top 2.9 over the floor, tape shelf 16 x 10.3 x 1.4, mannequins 5.45 tall on their
plinth, display table 6 x 3 x 3...), so collision proxies and the layout do not move; real
proportions inside that envelope.

Conventions (pieces/_template.py): Roblox axes, studs, +Y up, front = -Z. Floor / counter
pieces: origin at the centre of the footprint on the surface they stand on. Wall pieces: origin
on the wall face, -Z out of the wall. Hanging pieces (MirrorBall, CurtainDrawn*): origin on the
ceiling / on the rail's axis, the piece hangs down (y < 0). Garments: origin = the rail's axis
(the hanger's hook). Only ONE kind of tintable layer per piece.

MANNEQUINS. The client's ShopFrontController paints a mannequin Model's parts by NAME (a part
whose name contains Torso / Chest / Top takes the outfit's top colour, Leg / Foot / Hip /
Pelvis / Trousers / Pants the trousers colour). PropKit names each cloned layer
"<Piece>_<Layer>", so a mannequin is three pieces, all under markers inside its Model:
MannequinDisplay(B) (the bare fibreglass figure and its stand: no painted word in the name),
MannequinTop(B) (the top: "Top") and MannequinLegs(B) (the trousers: "Leg"). Each is one
Fabric layer, built on the same pose as its body (A: relaxed, B: hand on the hip, weight on
one leg), the cloth 0.035-0.06 off the skin everywhere.

No bottles of any kind anywhere in this module.
"""

import math

import bmesh
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

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
from fixtures import rbox, prism  # noqa: F401
from market import (  # noqa: F401
    NECK,
    TIP,
    _Garment,
    _drape,
    _ellipse,
    _grid_slab,
    _rbox,
    _rr,
    _rr_loft,
    _sleeve,
    _sleeve_path,
    _sweep,
    _torus,
    _wire_hanger,
    _wood_hanger,
)

TAU = 2 * math.pi
FLOOR = 0.012  # lowest point of a floor piece above the surface it stands on


# ==============================================================================================
# Shared helpers
# ==============================================================================================
def place(bm, m):
    """Transforms a bmesh in place by matrix m and returns it."""
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm


def mirror_x(ctx):
    """Mirrors everything built so far across X (left-right): a layout written from the viewer's
    side of the piece. The faces come out inside out; finish_bmesh turns them back."""
    for bm in ctx.layers.values():
        bmesh.ops.transform(bm, matrix=Matrix.Diagonal((-1, 1, 1, 1)), verts=bm.verts)
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    for k, v in list(ctx.markers.items()):
        ctx.markers[k] = Vector((-v.x, v.y, v.z))


def ext_x(section, x0, x1, segs=1):
    """Extrudes a closed 2-D section [(z, y), ...] along X from x0 to x1. Closed."""
    rings = [[(lerp(x0, x1, k / segs), y, z) for z, y in section] for k in range(segs + 1)]
    return loft(rings, cap_start=True, cap_end=True)


def ext_z(section, z0, z1, segs=1):
    """Extrudes a closed 2-D section [(x, y), ...] along Z from z0 to z1. Closed."""
    rings = [[(x, y, lerp(z0, z1, k / segs)) for x, y in section] for k in range(segs + 1)]
    return loft(rings, cap_start=True, cap_end=True)


def plain(w, h, d):
    """An unbevelled box (thin things seen edge-on: sleeves, labels): 12 triangles."""
    return box(w, h, d)


class Dye:
    """Per-element vertex colours on one layer: dye.add(bm, rgb) records the (already placed)
    bmesh's vertices with a colour MULTIPLIER; dye.fn(extra) is the layer's wear: the colour of
    the nearest recorded vertex times extra(p). Lets one layer carry many differently coloured
    small things (record sleeves, tape spines) without a layer each."""

    def __init__(self):
        self.pts, self.cols, self.tree = [], [], None

    def add(self, bm, mult):
        for v in bm.verts:
            self.pts.append(v.co.copy())
            self.cols.append(mult)
        return bm

    def mirror(self):
        """After mirror_x: the recorded points follow."""
        self.pts = [Vector((-c.x, c.y, c.z)) for c in self.pts]
        self.tree = None

    def fn(self, extra=None):
        def f(p):
            if self.tree is None:
                self.tree = KDTree(len(self.pts))
                for i, co in enumerate(self.pts):
                    self.tree.insert(co, i)
                self.tree.balance()
            _co, i, _d = self.tree.find(p.co)
            c = self.cols[i] if i is not None else (1.0, 1.0, 1.0)
            if extra is not None:
                e = extra(p)
                if isinstance(e, (int, float)):
                    e = (e, e, e)
                c = (c[0] * e[0], c[1] * e[1], c[2] * e[2])
            return c

        return f


def mult_of(rgb, base):
    """The vertex-colour multiplier that turns a layer's base colour into rgb (clamped)."""
    return tuple(max(0.35, min(1.0, c / b)) for c, b in zip(rgb, base))


PAPER = (196, 190, 174)
# faded record / tape covers (sRGB): sun-bleached reds, mustards, teals, creams...
COVERS = [(150, 56, 48), (188, 150, 72), (72, 98, 138), (92, 122, 96), (186, 178, 160), (124, 84, 120),
          (196, 112, 64), (84, 92, 100), (146, 146, 150), (172, 96, 98), (110, 140, 150), (160, 130, 100)]


def wood_wear(noise, dirt_h=0.5, dirt=0.3, grain=0.07, rub=None):
    """Old laminate / varnished wood: grain streaks along X, grime low and in creases, edges a
    touch lighter, rubbed paler where rub(p) -> 0..1."""

    def fn(p):
        x, y, z = p.co
        c = 1 + grain * noise.fbm((x * 0.5, y * 7.0, z * 7.0), 2)
        c *= 1 - dirt * (1 - smoothstep(0.0, dirt_h * (1 + 0.3 * noise.n(p.co * 2.0)), y))
        c *= 1 - 0.3 * smoothstep(0.0, 0.5, -p.convex)
        c *= 1 + 0.1 * smoothstep(0.05, 0.5, p.convex)
        r, g, b = c, c, c
        if rub is not None:
            t = rub(p)
            r, g, b = r * (1 + 0.25 * t), g * (1 + 0.18 * t), b * (1 + 0.08 * t)
        return (r, g, b)

    return fn


def dust_top(noise, k=0.18, ny=0.6):
    """Grey dust on up-facing surfaces (multiplier > 1 lightens a dark layer a little, < 1
    darkens a light one: here a neutral greying toward the dust colour)."""

    def fn(p):
        t = smoothstep(ny, 0.95, p.normal.y) * (0.6 + 0.4 * noise.fbm(p.co * 3.0, 2))
        return 1 - k * t

    return fn


def yellowed(noise, k=0.25):
    """Beige ABS gone yellow with age (more on top, where the light falls)."""

    def fn(p):
        t = (0.5 + 0.5 * smoothstep(-0.2, 0.9, p.normal.y)) * (0.7 + 0.3 * noise.fbm(p.co * 2.0, 2))
        return (1 - 0.05 * k * t, 1 - 0.25 * k * t, 1 - 0.8 * k * t)

    return fn


def shoe_scuffs(noise, y1=0.5, k=0.35):
    """Black shoe scuffs low on front faces (kicks), patchy."""

    def fn(p):
        if p.co.y > y1 or p.normal.z > -0.3:
            return 1.0
        s = smoothstep(0.55, 0.8, noise.fbm(p.co * 5.0, 3) * 0.5 + 0.5) * (1 - smoothstep(0.0, y1, p.co.y))
        return 1 - k * s

    return fn


# ==============================================================================================
# REWIND
# ==============================================================================================
# RECORD BIN. Real reference: a record shop browser bin (crate): a cabinet ~ 85-90 cm high on a
# recessed toe-kick plinth, an open bin on top ~ 33 cm deep that holds 12-inch LPs upright in
# rows between plywood dividers, its front lip low (~10 cm, you flip the records toward you)
# and its back and end panels high and rounded, so the sleeves lean back against each other.
# White plastic index cards stick up between the rows (A-F, G-L...). Under the bin, overstock:
# sliding doors, or open cubbies with cardboard record boxes. What reads: the rows of square
# sleeves of every colour leaning back, the rounded end panels, the dividers' tabs. Wear: the
# front lip's top rubbed pale by hands, the plinth and the cabinet's bottom kicked black, sleeves
# sun-faded, a few white inner sleeves poking out.
# Data (Interiors/Rewind): RecordBin 6 x 3 x 3 (collider, y 1.9..4.9), BinPlinth 5.4 x 0.3 x 2.4,
# BinCabinet 5.88 x 1.3 x 2.88 (top 1.6 over the floor), CrateFront 0.45 high, CrateBack 1.5 high
# (top 3.1), dividers at x -1.43 / 0 / 1.43, sleeves 1.25 square leaning 14 deg.
# ==============================================================================================
BIN_TOP = 1.6  # the cabinet's top = the bin's floor
BIN_HX, BIN_HZ = 2.94, 1.44  # the cabinet's half footprint


def _bin_end_section(scale=1.0, lo=BIN_TOP - 0.01, hz=BIN_HZ + 0.015):
    """An end panel's outline (z, y): front low (2.1), back high (3.1), a rounded top between.
    hz: its half depth (the ends stand 0.015 proud of the front and back walls)."""
    pts = [(-hz, lo), (hz, lo)]
    n = 12
    for k in range(n + 1):
        t = k / n
        z = lerp(hz, -hz, t)
        y = 2.1 + (1.0 * scale) * math.cos(t * math.pi / 2) ** 0.85 - (0.08 * (1 - scale))
        pts.append((z, y))
    return pts


def _record_bin(ctx, cubbies):
    ctx.budget = 6500
    ctx.smooth_angle = 40
    noise, rng = ctx.noise, ctx.rng
    # plinth (toe kick, recessed) and the cabinet
    ctx.add("WoodDark", rbox(5.4, 0.3 - FLOOR, 2.4, r=0.02, m=2, n=(6, 1, 3)), T(0, FLOOR + (0.3 - FLOOR) / 2, 0))
    ctx.add("Wood", rbox(2 * BIN_HX, 1.3, 2 * BIN_HZ, r=0.035, m=2, n=(6, 2, 3)), T(0, 0.95, 0))
    if not cubbies:
        # two sliding doors on the front, each a panel 0.02 proud with a recessed finger pull
        for sx in (-1, 1):
            ctx.add("Wood", rbox(2.82, 1.08, 0.04, r=0.012, m=2, n=(6, 2, 1)), T(sx * 1.43, 0.95, -BIN_HZ - 0.012))
            ctx.add("Black", _rbox(0.36, 0.1, 0.04, 0.03), T(sx * 1.43 - sx * 1.0, 1.2, -BIN_HZ - 0.03))
        ctx.add("Metal", box(5.7, 0.03, 0.05, bevel=0.01), T(0, 0.39, -BIN_HZ - 0.025))  # the bottom track
    else:
        # open cubbies: three dark openings with cardboard LP boxes in them (the overstock)
        for i, x in enumerate((-1.92, 0.0, 1.92)):
            ctx.add("Black", box(1.7, 0.98, 0.04), T(x, 0.95, -BIN_HZ - 0.008))
            for side in (-1, 1):
                ctx.add("Wood", box(0.08, 1.08, 0.06, bevel=0.012), T(x + side * 0.89, 0.95, -BIN_HZ - 0.02))
            # a cardboard box poking out of the opening, lid flaps up
            bw, bh = rng.uniform(1.2, 1.45), rng.uniform(0.6, 0.85)
            yaw = rng.uniform(-6, 6)
            ctx.add("Cardboard", rbox(bw, bh, 0.5, r=0.02, m=1, n=(3, 2, 1)),
                    T(x + rng.uniform(-0.1, 0.1), 0.42 + bh / 2, -BIN_HZ - 0.05) @ R(0, yaw, 0))
            if i != 1:
                ctx.add("Cardboard", box(bw * 0.95, 0.03, 0.3), T(x, 0.42 + bh + 0.08, -BIN_HZ - 0.2) @ R(-60, yaw, 0))
        for x in (-0.96, 0.96):
            ctx.add("Wood", box(0.08, 1.08, 0.06, bevel=0.012), T(x, 0.95, -BIN_HZ - 0.02))
    # the bin: front lip, back, ends (rounded tops), all sitting on the cabinet's top
    ctx.add("Wood", rbox(2 * BIN_HX - 0.22, 0.52, 0.12, r=0.03, m=2, n=(6, 1, 1)), T(0, BIN_TOP + 0.25, -BIN_HZ + 0.07))
    ctx.add("Wood", rbox(2 * BIN_HX - 0.22, 1.51, 0.12, r=0.03, m=2, n=(6, 2, 1)), T(0, BIN_TOP + 0.745, BIN_HZ - 0.07))
    for sx in (-1, 1):
        ctx.add("Wood", ext_x(_bin_end_section(), min(sx * (BIN_HX - 0.12), sx * BIN_HX), max(sx * (BIN_HX - 0.12), sx * BIN_HX)))
    # the dividers (lower, the same rounded top), each with a white index card
    comps = [(-BIN_HX + 0.12, -1.43), (-1.43, 0.0), (0.0, 1.43), (1.43, BIN_HX - 0.12)]
    for x in (-1.43, 0.0, 1.43):
        ctx.add("WoodDark", ext_x(_bin_end_section(0.62, BIN_TOP - 0.005, BIN_HZ - 0.13), x - 0.025, x + 0.025))
        ctx.add("Paper", _rbox(0.035, 0.34, 0.5, 0.03), T(x, 2.98, -0.98))
    # the sleeves
    paper, black = Dye(), Dye()
    flipped = rng.randrange(4)
    for ci, (x0, x1) in enumerate(comps):
        cx = (x0 + x1) / 2
        n = rng.randint(16, 21)
        zs = []
        if ci == flipped:  # someone flipping: three sleeves fallen forward, a gap, the rest
            zs += [(-0.86 + 0.07 * k, -rng.uniform(17, 22)) for k in range(3)]
            start = -0.42
        else:
            start = -1.24
        rest = n - len(zs)
        for k in range(rest):
            zs.append((lerp(start, 0.93, k / max(rest - 1, 1)) + rng.uniform(-0.015, 0.015), rng.uniform(12.5, 16.5)))
        for k, (z, lean) in enumerate(zs):
            h = 1.25 if rng.random() > 0.15 else 1.17
            th = rng.uniform(0.028, 0.05) if rng.random() > 0.1 else 0.07  # (a fat double album)
            m = T(cx + rng.uniform(-0.04, 0.04), BIN_TOP, z) @ R(lean, rng.uniform(-1.5, 1.5), 0) @ T(0, h / 2, 0)
            sl = place(plain(1.25, h, th), m)
            if rng.random() < 0.22:
                black.add(sl, (1.0, 1.0, 1.0))
                ctx.add("Black", sl)
            else:
                c = COVERS[rng.randrange(len(COVERS))]
                fade = rng.uniform(0.85, 1.0)
                paper.add(sl, mult_of(tuple(v * fade + 30 * (1 - fade) for v in c), PAPER))
                ctx.add("Paper", sl)
            if rng.random() < 0.16:  # the white inner sleeve poking out of the top
                inner = place(plain(1.12, 0.3, th * 0.5), m @ T(rng.uniform(-0.03, 0.03), h / 2 - 0.1, 0))
                paper.add(inner, (1.0, 1.0, 0.98))
                ctx.add("Paper", inner)

    def rub(p):  # hands on the front lip's top edge
        return smoothstep(BIN_TOP + 0.35, BIN_TOP + 0.5, p.co.y) * smoothstep(-BIN_HZ + 0.4, -BIN_HZ, p.co.z) \
            * (1 - smoothstep(BIN_TOP + 0.55, BIN_TOP + 0.7, p.co.y))

    ctx.wear("Wood", mul(wood_wear(noise, 0.9, 0.3, rub=rub), shoe_scuffs(noise, 0.6), dust_top(noise, 0.08)))
    ctx.wear("WoodDark", mul(wood_wear(noise, 0.4, 0.35), shoe_scuffs(noise, 0.35, 0.45)))
    ctx.wear("Paper", paper.fn(lambda p: (0.92 + 0.08 * noise.fbm(p.co * 4, 2)) * (1 - 0.15 * smoothstep(0.3, -0.5, p.convex))))
    ctx.wear("Black", black.fn(lambda p: 1.0))
    if cubbies:
        ctx.wear("Cardboard", mul(ground_dirt(0.6, 0.3, noise), cavity(0.3), edge_wear(0.12)))


def record_bin_crate(ctx):
    """Record store browser bin, 6 x 3: laminate cabinet on a kicked plinth with two sliding
    doors, an open bin on top (low front lip rubbed pale, high back, rounded end panels), three
    dividers with white index cards, ~75 LP sleeves of every faded colour leaning back in four
    rows (one row flipped forward, a gap behind), white inner sleeves poking out."""
    _record_bin(ctx, cubbies=False)


def record_bin_crate_b(ctx):
    """The same bin with open cubbies underneath: three cardboard boxes of overstock, lids up;
    a different flip of the rows."""
    _record_bin(ctx, cubbies=True)


# ==============================================================================================
# VHS STACK. Real reference: VHS cassettes (187 x 103 x 25 mm) in rental clamshell cases
# (~ 210 x 125 x 30 mm, black or coloured hard plastic, a printed cover under a clear sleeve on
# the front), a bare cassette (two reel windows, a white paper label, the hinged dust flap) on
# top. Data: VHSStack x 3 (1 x 0.3 x 0.8 each, y 0..0.9 over the counter top).
# ==============================================================================================
def _vhs_case(ctx, dye, at, yaw, cover, w=0.98, d=0.58, h=0.2):
    """A rental clamshell case lying flat: the black shell (rounded), the cover under its clear
    sleeve on top (a paper slab 0.01 proud), the hinge ribs along one long side."""
    m = T(*at) @ R(0, yaw, 0)
    ctx.add("PlasticDark", place(_rbox(w, h, d, 0.03), m @ T(0, h / 2, 0)))
    cv = place(box(w - 0.07, 0.014, d - 0.07), m @ T(0, h + 0.002, 0))
    dye.add(cv, mult_of(cover, PAPER))
    ctx.add("Paper", cv)
    for k in range(3):  # the hinge's ribs on the back long edge
        ctx.add("PlasticDark", place(box(w * 0.26, h * 0.6, 0.02), m @ T((k - 1) * w * 0.31, h / 2, d / 2 + 0.006)))


def vhs_stack(ctx):
    """Three rental VHS clamshell cases piled crooked on the counter (black shells, faded printed
    covers under their clear sleeves, hinge ribs) and a bare cassette on top: reel windows, the
    paper label half peeled, the dust flap, the write-protect notch."""
    ctx.budget = 2200
    noise, rng = ctx.noise, ctx.rng
    dye = Dye()
    y = 0.0
    for k in range(3):
        cover = COVERS[rng.randrange(len(COVERS))]
        _vhs_case(ctx, dye, (rng.uniform(-0.05, 0.05), y, rng.uniform(-0.04, 0.04)), rng.uniform(-9, 9) + (180 if k == 1 else 0), cover)
        y += 0.2
    # the bare cassette (on top, turned): body, two windows, label, flap
    m = T(0.02, y, 0.0) @ R(0, rng.uniform(15, 25), 0)
    cw, cd, chh = 0.86, 0.47, 0.115
    ctx.add("Black", place(_rbox(cw, chh, cd, 0.015), m @ T(0, chh / 2, 0)))
    for sx in (-1, 1):  # the reel windows (dark glass, a hair proud) with the hubs
        ctx.add("Screen", place(_rbox(0.2, 0.012, 0.13, 0.02), m @ T(sx * 0.17, chh + 0.002, -0.02)))
        ctx.add("Reflective", place(cyl(0.035, 0.014, 8), m @ T(sx * 0.17, chh + 0.004, -0.02)))
    lab = place(box(0.62, 0.012, 0.13), m @ T(0, chh + 0.001, 0.14))
    dye.add(lab, (1.0, 0.98, 0.92))
    ctx.add("Paper", lab)
    peel = place(box(0.14, 0.008, 0.12), m @ T(0.36, chh + 0.035, 0.14) @ R(0, 0, -25))
    dye.add(peel, (0.95, 0.92, 0.85))
    ctx.add("Paper", peel)
    ctx.add("Black", place(box(cw - 0.06, 0.09, 0.03), m @ T(0, chh / 2, -cd / 2 - 0.008)))  # the dust flap
    ctx.wear("PlasticDark", mul(cavity(0.25), edge_wear(0.25), lambda p: 0.85 + 0.15 * noise.fbm(p.co * 6, 2)))
    ctx.wear("Paper", dye.fn(lambda p: 0.9 + 0.1 * noise.fbm(p.co * 8, 2)))
    ctx.wear("Black", mul(edge_wear(0.3), cavity(0.2)))


# ==============================================================================================
# TURNTABLE. Real reference: a Technics SL-1200 direct-drive DJ deck (453 x 353 x 162 mm with
# feet): heavy die-cast body, the platter (332 mm) with its strobe dots round the edge, a rubber
# mat, the record, the S-shaped tonearm on its gimbal base at the back right with the
# counterweight and the arm rest, the long pitch fader on the right, the start/stop button at
# the front left, 33/45 buttons beside it, the strobe lamp, four big damped feet, the dust-cover
# hinges at the back. Data: Turntable 2 x 0.4 x 1.6 + Record (1.4 disc) on the counter.
# Front = -Z (the DJ's side).
# ==============================================================================================
def turntable(ctx):
    """DJ turntable (SL-1200 style): satin silver die-cast body on four damped feet, platter with
    strobe dots, rubber mat, a black record with a faded label and its spindle, S-shaped tonearm
    on a gimbal base (counterweight, arm lift, headshell resting on the arm rest), pitch fader,
    start/stop and 33/45 buttons, strobe lamp, the dust cover's hinge blocks; worn edges, dust."""
    ctx.budget = 4500
    ctx.smooth_angle = 40
    noise, rng = ctx.noise, ctx.rng
    W, D = 2.0, 1.56
    for sx in (-1, 1):
        for sz in (-1, 1):
            ctx.add("Rubber", lathe([(0, FLOOR), (0.13, FLOOR), (0.14, 0.03), (0.14, 0.06), (0.12, 0.075), (0, 0.075)], segs=16),
                    T(sx * 0.82, 0, sz * 0.6))
    by0, by1 = 0.07, 0.3
    ctx.add("Metal", _rr_loft([(by0, W - 0.04, D - 0.04, 0.06, 0, 0), (by0 + 0.02, W, D, 0.08, 0, 0),
                               (by1 - 0.02, W, D, 0.08, 0, 0), (by1, W - 0.04, D - 0.04, 0.06, 0, 0)], "xz", k=4, m=2))
    ctx.add("Black", box(W - 0.02, 0.05, D - 0.02), T(0, by0 + 0.03, 0))  # the dark insulator base line
    px, pz, pr = -0.24, 0.0, 0.7
    top = by1
    # platter: the rim with its strobe dots, the mat, the record, the label, the spindle
    ctx.add("Metal", lathe([(0, top - 0.01), (pr, top - 0.01), (pr + 0.01, top + 0.0), (pr + 0.01, top + 0.06), (pr - 0.02, top + 0.075),
                            (0, top + 0.075)], segs=48), T(px, 0, pz))
    for k in range(40):
        a = TAU * k / 40
        ctx.add("Black", box(0.03, 0.022, 0.012), T(px + math.cos(a) * (pr + 0.012), top + 0.032, pz + math.sin(a) * (pr + 0.012)) @ R(0, -math.degrees(a) + 90, 0))
    ctx.add("Rubber", cyl(pr - 0.03, 0.016, 40), T(px, top + 0.083, pz))
    ctx.add("Black", lathe([(0, top + 0.09), (pr - 0.05, top + 0.09), (pr - 0.05, top + 0.1), (0.2, top + 0.104), (0, top + 0.104)], segs=40), T(px, 0, pz))
    ctx.add("Paper", cyl(0.2, 0.006, 24), T(px, top + 0.107, pz))
    ctx.add("Chrome", cyl(0.018, 0.09, 8), T(px, top + 0.13, pz))
    # tonearm: base (round, two rings), pillar, gimbal, the S arm, headshell on the rest,
    # counterweight behind
    bx, bz = 0.68, 0.45  # the arm base, back right (+Z is the back)
    ctx.add("Metal", lathe([(0, top), (0.22, top), (0.23, top + 0.02), (0.2, top + 0.05), (0.12, top + 0.06), (0, top + 0.06)], segs=24),
            T(bx, 0, bz))
    ctx.add("Black", cyl(0.1, 0.12, 16), T(bx, top + 0.11, bz))
    ctx.add("Chrome", _rbox(0.12, 0.09, 0.16, 0.03), T(bx, top + 0.2, bz))
    pivot = Vector((bx, top + 0.2, bz))
    head = Vector((0.78, top + 0.16, -0.38))
    path = [pivot + Vector((0, 0, -0.06)), pivot + Vector((-0.02, -0.005, -0.3)), pivot + Vector((0.06, -0.015, -0.55)),
            head + Vector((-0.02, 0.02, 0.12))]
    ctx.add("Chrome", tube(path, 0.022, segs=8))
    ctx.add("Black", _rbox(0.09, 0.025, 0.2, 0.012), T(head.x, head.y, head.z) @ R(0, -18, 0))  # the headshell
    ctx.add("Black", box(0.05, 0.045, 0.05, bevel=0.008), T(head.x - 0.01, head.y - 0.03, head.z - 0.04))  # cartridge
    ctx.add("Metal", tube([pivot + Vector((0, 0, 0.06)), pivot + Vector((0, 0, 0.3))], 0.02, segs=8))
    ctx.add("Metal", lathe([(0, 0), (0.06, 0), (0.07, 0.02), (0.07, 0.1), (0.06, 0.12), (0, 0.12)], segs=16),
            T(pivot.x, pivot.y, pivot.z + 0.24) @ R(90, 0, 0))
    ctx.add("Metal", cyl(0.025, 0.09, 8), T(head.x + 0.09, top + 0.045, head.z + 0.06))  # the arm rest
    ctx.add("Metal", cyl(0.03, 0.05, 8), T(bx - 0.25, top + 0.025, bz + 0.12))  # the arm lift
    # pitch fader slot + knob (front right), start/stop, 33/45, strobe lamp
    ctx.add("Black", box(0.06, 0.012, 0.62), T(0.82, top + 0.002, -0.2))
    ctx.add("Metal", _rbox(0.14, 0.05, 0.09, 0.015), T(0.82, top + 0.026, -0.14 + rng.uniform(-0.1, 0.1)))
    ctx.add("Metal", _rbox(0.26, 0.04, 0.18, 0.02), T(-0.82, top + 0.015, -0.62))
    for k, x in enumerate((-0.5, -0.36)):
        ctx.add("Metal", _rbox(0.11, 0.03, 0.09, 0.012), T(x, top + 0.012, -0.66))
    ctx.add("Metal", cyl(0.07, 0.06, 12), T(-0.85, top + 0.03, -0.25))
    ctx.add("Glow", sphere(0.035, 8, 5), T(-0.85, top + 0.07, -0.25))
    for sx in (-1, 1):  # dust cover hinge blocks on the back edge
        ctx.add("Black", _rbox(0.2, 0.12, 0.1, 0.02), T(sx * 0.7, top - 0.02, D / 2 + 0.03))
    ctx.wear("Metal", mul(cavity(0.3), edge_wear(0.15), dust_top(noise, 0.12), lambda p: 0.85 + 0.12 * noise.fbm(p.co * 6, 2)))
    ctx.wear("Black", mul(cavity(0.2), lambda p: 0.9 + 0.1 * noise.fbm(p.co * 12, 2)))
    ctx.wear("Paper", lambda p: (0.95, 0.62, 0.42))  # an orange label, faded
    mirror_x(ctx)  # (the platter on the DJ's left, the arm on the right)


# ==============================================================================================
# CASH REGISTERS
# ==============================================================================================
# OLD: a late-80s electronic cash register (Sharp / Casio ECR): a steel cash drawer as the base
# (lock, the seam of the drawer front), the beige ABS upper body sloping up from the keyboard
# to the printer at the back, a membrane-free keyboard of chunky keys (numeric block,
# department keys, the big CASH/TOTAL key), the mode key-lock, the little operator display in
# a dark window, the pop-up customer display on a post at the back, the receipt coming out of
# the printer and curling. Data: Register 2 x 1.4 x 1.6 on the counter. Front = -Z (the
# cashier's side).
# ==============================================================================================
def cash_register_old(ctx):
    """80s electronic cash register: steel drawer base (lock, seam), yellowed beige body sloping
    up to the printer, 30-odd chunky keys (grime between them), the key-lock, the operator's
    amber display, the customer display popped up on its post at the back, a receipt curling
    out of the printer; stickers' ghosts, rubbed key tops."""
    ctx.budget = 4200
    ctx.smooth_angle = 35
    ctx.tint("Plastic", (178, 166, 136))
    noise, rng = ctx.noise, ctx.rng
    W, D = 1.96, 1.56
    # the drawer base
    ctx.add("PlasticDark", _rr_loft([(FLOOR, W - 0.04, D - 0.04, 0.04, 0, 0), (FLOOR + 0.02, W, D, 0.05, 0, 0),
                                                                  (0.46, W, D, 0.05, 0, 0), (0.48, W - 0.04, D - 0.04, 0.04, 0, 0)], "xz", k=3, m=1))
    ctx.add("Black", box(W - 0.1, 0.02, 0.03), T(0, 0.42, -D / 2 - 0.006))  # the drawer seam
    ctx.add("Black", box(0.03, 0.34, 0.03), T(-W / 2 + 0.12, 0.25, -D / 2 - 0.006))
    ctx.add("Chrome", cyl(0.045, 0.03, 12), T(W / 2 - 0.22, 0.25, -D / 2 - 0.01) @ R(90, 0, 0))  # the lock
    ctx.add("PlasticDark", _rbox(0.5, 0.06, 0.05, 0.025), T(0, 0.2, -D / 2 - 0.02))  # the drawer's finger lip
    # the upper body: a side profile (z, y) extruded across, rounded
    prof = [(-D / 2 + 0.02, 0.47), (D / 2 - 0.02, 0.47), (D / 2 - 0.02, 1.02), (D / 2 - 0.1, 1.08), (0.22, 1.08),
            (-D / 2 + 0.06, 0.6), (-D / 2 + 0.02, 0.55)]
    from market import _ext  # (a convex outline: rounded corners, bevelled ends)
    ctx.add("Plastic", _ext(prof, -W / 2 + 0.02, W / 2 - 0.02, 0.04, 0.04, k=2, kb=2))
    # keys on the slope (the slope's surface runs from (z -0.72, y 0.6) to (z 0.22, y 1.08))
    za, zb = -D / 2 + 0.12, 0.12
    ya, yb = 0.6 + (za + 0.72) * (0.48 / 0.94), 0.6 + (zb + 0.72) * (0.48 / 0.94)
    ang = math.degrees(math.atan2(yb - ya, zb - za))
    dye = Dye()

    def slope(u, v):  # u across (x), v along the slope 0..1
        return Vector((u, lerp(ya, yb, v), lerp(za, zb, v)))

    keys = []
    for i in range(5):  # department keys (left block, 2 columns)
        for j in range(2):
            keys.append((-0.78 + j * 0.2, 0.08 + i * 0.19, 0.17, 0.15, (0.75, 0.8, 0.9) if i % 2 else (0.95, 0.9, 0.78)))
    for i in range(4):  # the numeric block
        for j in range(3):
            keys.append((-0.22 + j * 0.2, 0.08 + i * 0.235, 0.17, 0.18, (1.0, 1.0, 0.98)))
    for i in range(3):  # function keys
        keys.append((0.42, 0.12 + i * 0.3, 0.2, 0.24, (0.85, 0.7, 0.55)))
    keys.append((0.7, 0.3, 0.26, 0.55, (0.6, 0.85, 0.65)))  # CASH / TOTAL
    for u, v, kw, kd, col in keys:
        c = slope(u, v)
        kb = place(_rbox(kw, 0.07, kd * 0.95, 0.025, k=1), T(c.x, c.y + 0.012, c.z) @ R(-ang, 0, 0))
        dye.add(kb, col)
        ctx.add("Reflective", kb)
    # the key-lock (right of the slope's top) and the operator display in its dark window on the
    # flat top (amber digits = Glow)
    c = slope(0.72, 0.9)
    ctx.add("Black", place(cyl(0.08, 0.03, 16), T(c.x, c.y, c.z) @ R(-ang, 0, 0)))
    ctx.add("Chrome", place(box(0.03, 0.05, 0.1), T(c.x, c.y + 0.03, c.z) @ R(-ang, 20, 0)))
    ctx.add("Screen", box(0.72, 0.03, 0.2, bevel=0.01), T(-0.4, 1.083, 0.36))
    ctx.add("Glow", box(0.52, 0.012, 0.07), T(-0.4, 1.099, 0.36))
    # the printer cover on top (a seam), the receipt curling out of its slot
    ctx.add("Black", box(0.62, 0.012, 0.02), T(0.4, 1.083, 0.3))
    ctx.add("PlasticDark", box(0.6, 0.03, 0.05), T(0.4, 1.09, 0.5))
    rp = []
    for k in range(9):
        t = k / 8
        a = t * 2.4
        rp.append((0.4, 1.1 + 0.28 * math.sin(a) * (1 - 0.2 * t), 0.5 - 0.3 * (1 - math.cos(a))))
    ctx.add("Paper", _sweep(rp, [(-0.25, -0.004), (0.25, -0.004), (0.25, 0.004), (-0.25, 0.004)], ups=Vector((0, 0, -1))))
    # the customer display: a post at the back, a dark head with its digits toward the customer
    ctx.add("PlasticDark", cyl(0.05, 0.42, 10), T(-0.62, 1.29, 0.55))
    ctx.add("PlasticDark", _rbox(0.6, 0.22, 0.14, 0.04), T(-0.62, 1.55, 0.55))
    ctx.add("Glow", box(0.42, 0.06, 0.012), T(-0.62, 1.555, 0.625))
    ctx.add("Glow", box(0.42, 0.06, 0.012), T(-0.62, 1.555, 0.475))
    ctx.wear("Plastic", mul(yellowed(noise, 0.35), cavity(0.35), edge_wear(0.1), dust_top(noise, 0.1)))
    ctx.wear("Reflective", dye.fn(mul(cavity(0.4), lambda p: 0.82 + 0.18 * smoothstep(0.3, 0.9, p.normal.y) * (0.8 + 0.2 * noise.n(p.co * 9)))))
    ctx.wear("PlasticDark", mul(cavity(0.25), edge_wear(0.25), scuffs(noise, 0.2, 6.0)))
    ctx.wear("Paper", lambda p: (0.98, 0.96, 0.88))
    mirror_x(ctx)  # (the CASH key under the cashier's right hand)
    dye.mirror()
    _ = rng


# MODERN: a shop POS of the 2010s: the black steel cash drawer under everything, a 15-inch
# touchscreen terminal on a tilting stand (thick bezel, a logo, a USB hub at the back), the
# customer display (a small second screen) on the back of the stand, a card terminal in its
# cradle beside it (keypad, card slot, the cable), the thermal receipt printer (dark cube, the
# paper slot, a curled receipt), cables bundled down the back. Data: Till 2 x 1.4 x 1.6 +
# TillDisplay (green neon) on its +Z face (the customers' side). Front = -Z (the clerk).
def cash_register_modern(ctx):
    """Modern POS till: black steel cash drawer (lock, the drawer front's seam), a touchscreen
    terminal on a tilting stand (thick bezel, dark glass with a faint glow), the customer
    display glowing on the back of the stand, a card terminal in its cradle (keypad), a thermal
    receipt printer with a curled receipt, cables down the back; scuffed drawer front."""
    ctx.budget = 4200
    ctx.smooth_angle = 35
    noise, rng = ctx.noise, ctx.rng
    W, D = 1.96, 1.56
    ctx.add("PlasticDark", _rr_loft([(FLOOR, W - 0.04, D - 0.04, 0.03, 0, 0), (FLOOR + 0.02, W, D, 0.04, 0, 0),
                                     (0.42, W, D, 0.04, 0, 0), (0.44, W - 0.04, D - 0.04, 0.03, 0, 0)], "xz", k=3, m=1))
    ctx.add("Black", box(W - 0.1, 0.015, 0.03), T(0, 0.39, -D / 2 - 0.006))
    ctx.add("Metal", cyl(0.04, 0.03, 12), T(W / 2 - 0.2, 0.22, -D / 2 - 0.01) @ R(90, 0, 0))
    ctx.add("Black", _rbox(0.6, 0.05, 0.05, 0.02), T(0, 0.12, -D / 2 - 0.016))
    # the stand: a round foot, a neck tilting back, the hinge
    ctx.add("Black", lathe([(0, 0.44), (0.36, 0.44), (0.37, 0.46), (0.33, 0.5), (0, 0.5)], segs=24), T(0.15, 0, 0.15))
    neck = [(0.15, 0.5, 0.2), (0.15, 0.82, 0.32)]
    ctx.add("Black", _sweep(neck, _ellipse(0.12, 0.05, 10), ups=Vector((0, 0, 1))))
    ctx.add("Metal", cyl(0.06, 0.32, 10), T(0.15, 0.86, 0.33) @ R(0, 0, 90))
    # the touchscreen head, tilted back 25 deg, facing the clerk
    tilt = R(-25, 0, 0)
    hm = T(0.15, 1.02, 0.2) @ tilt
    ctx.add("PlasticDark", place(_rr_loft([(-0.06, 1.3, 0.92, 0.05, 0, 0), (-0.04, 1.36, 0.98, 0.07, 0, 0),
                                            (0.06, 1.36, 0.98, 0.07, 0, 0), (0.1, 1.1, 0.8, 0.08, 0, 0)], "xy", k=3), hm))
    ctx.add("Screen", place(box(1.18, 0.8, 0.02), hm @ T(0, 0.02, -0.068)))
    ctx.add("Black", place(box(0.12, 0.03, 0.02), hm @ T(0, -0.43, -0.065)))  # the logo bar
    # the customer display on the back of the head (toward +Z)
    ctx.add("PlasticDark", place(_rbox(0.6, 0.36, 0.08, 0.03), hm @ T(0, 0.1, 0.14)))
    ctx.add("Glow", place(box(0.5, 0.26, 0.012), hm @ T(0, 0.1, 0.183)))
    # the card terminal in its cradle (left, angled toward the clerk... and the customer)
    cm = T(-0.68, 0.44, -0.1) @ R(-35, 25, 0)
    ctx.add("Black", place(_rbox(0.34, 0.08, 0.5, 0.04), cm @ T(0, 0.04, 0)))
    ctx.add("PlasticDark", place(_rbox(0.3, 0.07, 0.62, 0.05), cm @ T(0, 0.11, 0.02)))
    ctx.add("Screen", place(box(0.22, 0.012, 0.14), cm @ T(0, 0.147, -0.17)))
    for i in range(4):
        for j in range(3):
            ctx.add("Reflective", place(_rbox(0.06, 0.02, 0.045, 0.01, k=1), cm @ T((j - 1) * 0.08, 0.15, 0.0 + i * 0.065)))
    # the receipt printer (right), its paper slot and a curled receipt
    pm = T(0.72, 0.44, 0.35)
    ctx.add("PlasticDark", place(_rr_loft([(0.0, 0.46, 0.56, 0.05, 0, 0), (0.02, 0.5, 0.6, 0.06, 0, 0), (0.33, 0.5, 0.6, 0.06, 0, 0),
                                            (0.36, 0.46, 0.56, 0.05, 0, 0)], "xz", k=3), pm))
    ctx.add("Black", place(box(0.4, 0.012, 0.03), pm @ T(0, 0.362, -0.12)))
    rp = []
    for k in range(8):
        t = k / 7
        rp.append((0.72, 0.44 + 0.37 + 0.16 * math.sin(t * 2.2), 0.35 - 0.12 - 0.2 * (1 - math.cos(t * 2.2))))
    ctx.add("Paper", _sweep(rp, [(-0.17, -0.003), (0.17, -0.003), (0.17, 0.003), (-0.17, 0.003)], ups=Vector((0, 0, -1))))
    # cables down the back
    for k, (x0, z0) in enumerate(((0.15, 0.4), (0.72, 0.67), (-0.6, 0.1))):
        ctx.add("Black", tube([(x0, 0.6 if k == 0 else 0.5, z0), (x0 + 0.05, 0.47, D / 2 - 0.05), (x0 + 0.1, 0.4, D / 2 + 0.04),
                                (x0 + 0.12, 0.2, D / 2 + 0.06)], 0.025, segs=6))
    ctx.wear("PlasticDark", mul(cavity(0.25), edge_wear(0.2), scuffs(noise, 0.25, 5.0), dust_top(noise, 0.08)))
    ctx.wear("Black", mul(cavity(0.2), edge_wear(0.2)))
    ctx.wear("Screen", lambda p: 0.9 + 0.1 * noise.fbm(p.co * 5, 2))
    ctx.wear("Reflective", mul(cavity(0.3), lambda p: 0.75))
    ctx.wear("Paper", lambda p: 1.0)
    _ = rng


# ==============================================================================================
# PORTABLE TV. Real reference: a 1980s 9-10 inch portable TV (Sony Trinitron KV-9, Panasonic,
# Grundig): ~ 26 x 23 x 28 cm, the screen on the left of the front, a column of controls on the
# right (tuning dial, volume / brightness thumbwheels, the speaker's slots, the on switch), a
# fold-down carry handle over the top, a telescopic aerial on the back corner, a deep back
# with vent slots. Data: PortableTV 1.4 x 1 x 1.4 (x along the wall, y up) on the top CRT shelf,
# its screen toward the shop. Front = -Z.
# ==============================================================================================
def _portable_tv(ctx, light):
    ctx.budget = 3600
    ctx.smooth_angle = 40
    ctx.tint("Plastic", (210, 202, 186) if light else (46, 46, 48))
    noise, rng = ctx.noise, ctx.rng
    W, H, D = 1.3, 0.92, 1.2
    y0 = FLOOR + 0.03
    yc = y0 + H / 2
    zf = -D / 2
    # the front shell and the deep back tapering to the tube's neck
    ctx.add("Plastic", _rr_loft([(zf + 0.05, W - 0.06, H - 0.06, 0.06, 0, yc), (zf + 0.012, W - 0.012, H - 0.012, 0.07, 0, yc),
                                 (zf + 0.05, W, H, 0.08, 0, yc), (0.05, W, H, 0.08, 0, yc), (0.08, W - 0.08, H - 0.07, 0.08, 0, yc + 0.01),
                                 (D / 2 - 0.04, W - 0.42, H - 0.36, 0.08, -0.02, yc + 0.06),
                                 (D / 2, W - 0.48, H - 0.42, 0.06, -0.02, yc + 0.06)], "xy", k=4, m=1))
    # the screen on the left: a dark bezel window and the convex glass
    sx_, sy_ = -0.16, yc + 0.02
    ctx.add("Black", _rr_loft([(zf - 0.006, 0.84, 0.68, 0.1, sx_, sy_), (zf + 0.004, 0.86, 0.7, 0.1, sx_, sy_),
                               (zf + 0.03, 0.82, 0.66, 0.1, sx_, sy_)], "xy", k=3))
    ctx.add("Screen", _rr_loft([(zf + 0.02, 0.76, 0.6, 0.12, sx_, sy_), (zf + 0.0, 0.74, 0.58, 0.115, sx_, sy_),
                                (zf - 0.012, 0.62, 0.48, 0.1, sx_, sy_), (zf - 0.016, 0.4, 0.3, 0.08, sx_, sy_)], "xy", k=4))
    # the control column: speaker slots, tuning dial, thumbwheels, power switch
    cx = 0.45
    for k in range(6):
        ctx.add("Black", box(0.24, 0.018, 0.02), T(cx, yc + 0.28 - k * 0.04, zf - 0.004))
    ctx.add("PlasticDark", cyl(0.085, 0.06, 18, bevel=0.012), T(cx, yc - 0.02, zf - 0.02) @ R(90, 0, 0))
    ctx.add("Chrome", cyl(0.04, 0.03, 12), T(cx, yc - 0.02, zf - 0.052) @ R(90, 0, 0))
    for k in range(2):
        ctx.add("Black", cyl(0.055, 0.04, 12), T(cx - 0.07 + k * 0.14, yc - 0.24, zf - 0.008) @ R(0, 0, 90))
    ctx.add("PlasticDark", _rbox(0.12, 0.07, 0.04, 0.015), T(cx, y0 + 0.07, zf - 0.012))
    # the carry handle: two pivots on the sides, the bar folded back over the top
    hy = yc + H / 2 - 0.1
    for s in (-1, 1):
        ctx.add("PlasticDark", cyl(0.07, 0.05, 12), T(s * (W / 2 + 0.02), hy, 0.0) @ R(0, 0, 90))
    up = rng.random() < 0.5
    ang = 0 if up else 70
    hp = []
    for k in range(9):
        t = k / 8
        x = lerp(-W / 2 - 0.03, W / 2 + 0.03, t)
        lift = 0.22 * (1 - (2 * t - 1) ** 8)
        p = Vector((x, lift, 0))
        p = R(ang, 0, 0) @ p
        hp.append((p.x, hy + p.y, p.z))
    ctx.add("PlasticDark", _sweep(hp, [(-0.035, -0.02), (0.035, -0.02), (0.035, 0.02), (-0.035, 0.02)], ups=Vector((0, 0, 1))))
    # the telescopic aerial from the back right corner
    a0 = Vector((W / 2 - 0.12, yc + H / 2 - 0.04, D / 2 - 0.25))
    ctx.add("PlasticDark", cyl(0.05, 0.06, 10), T(a0.x, a0.y, a0.z))
    d = (R(-25, 0, -18) @ Vector((0, 1, 0))).normalized()
    p = a0 + Vector((0, 0.03, 0))
    for k, (ln, rr) in enumerate(((0.3, 0.018), (0.28, 0.013), (0.22 if light else 0.08, 0.009))):
        q = p + d * ln
        ctx.add("Chrome", tube([p - d * (0.02 if k else 0.0), q], rr, segs=6))
        p = q
    ctx.add("Chrome", sphere(0.02, 8, 5), T(p.x, p.y, p.z))
    # vent slots on the back's top and the rubber feet
    for k in range(7):
        z = 0.15 + k * 0.05
        yt = yc + H / 2 - 0.01 - (0.06 * (z - 0.08) / (D / 2 - 0.12))
        ctx.add("Black", box(0.45, 0.014, 0.022), T(-0.02, yt + 0.004, z))
    for sx in (-1, 1):
        for sz in (-1, 1):
            ctx.add("Rubber", cyl(0.05, 0.03, 10), T(sx * 0.5, FLOOR + 0.015, sz * 0.4))
    ctx.wear("Plastic", mul(yellowed(noise, 0.4 if light else 0.0), cavity(0.3), edge_wear(0.12), dust_top(noise, 0.15)))
    ctx.wear("PlasticDark", mul(cavity(0.25), edge_wear(0.2)))
    ctx.wear("Screen", lambda p: 0.85 + 0.15 * noise.fbm(p.co * 5, 2))
    mirror_x(ctx)  # (the controls on the right of the screen, seen from the front)


def crt_tv_portable(ctx):
    """80s portable TV, cream: screen on the left in a dark bezel, the control column (speaker
    slots, tuning dial, thumbwheels, switch), the carry handle over the top, a telescopic aerial
    pulled out of the back corner, the deep back with its vents; yellowed, dusty top."""
    _portable_tv(ctx, light=True)


def crt_tv_portable_b(ctx):
    """The same portable TV in black, its handle folded back, the aerial pushed in."""
    _portable_tv(ctx, light=False)



# ==============================================================================================
# VHS WALL. Real reference: a 90s video rental store's wall bay: plain laminate uprights and
# shelves, a price-ticket channel along each shelf's front, a header fascia on top (the shop's
# "NEW RELEASES" neon sits on it), the new releases shown FACE-OUT (the cover toward you, the
# copies standing behind it, rented ones leaving gaps), the back catalogue SPINE-OUT along the
# bottom shelf (black rental clamshells with printed spine labels). Data: TapeShelf: ShelfCollider
# 16 x 10.3 x 1.4 (y 1.9..12.2), sides 0.3 thick, boards at 0.08 / 2.68 / 5.27 / 7.88 over the
# floor, ShelfTop 0.55 thick (top 10.3), the neon on its front face (kept: z must stay 0.02
# behind it), the wall 0.7 behind the centre. Front = -Z.
# ==============================================================================================
def vhs_shelf_stocked(ctx):
    """A stocked VHS wall bay (16 x 10.3): laminate uprights and shelves with their ticket
    channels, a header fascia, a back panel; the bottom shelf packed spine-out with black rental
    clamshells and their coloured spine labels (a few leaning, a gap), three shelves of new
    releases face-out with their copies behind (covers in faded colours, title bands), gaps
    where tapes are out; dust on the tops, kicked plinth."""
    ctx.budget = 8000
    ctx.smooth_angle = 35
    noise, rng = ctx.noise, ctx.rng
    W2, ZF, ZB = 7.7, -0.68, 0.66
    ctx.add("WoodDark", box(15.4, 0.28, 1.2, bevel=0.02), T(0, FLOOR + 0.14, 0.05))  # the kick
    for sx in (-1, 1):
        ctx.add("WoodDark", rbox(0.3, 10.3 - FLOOR, 1.36, r=0.025, m=2, n=(1, 6, 1)), T(sx * 7.85, FLOOR + (10.3 - FLOOR) / 2, 0.0))
    ctx.add("WoodDark", rbox(16.0, 0.55, 1.36, r=0.03, m=2, n=(6, 1, 1)), T(0, 10.03, 0.0))  # header fascia (front at -0.68)
    ctx.add("WoodDark", box(15.4, 9.5, 0.04), T(0, 0.3 + 4.75, ZB - 0.02))  # back panel
    tops = (0.3, 2.755, 5.345, 7.955)
    for y in tops:
        ctx.add("Wood", rbox(15.4, 0.12, 1.32, r=0.02, m=2, n=(6, 1, 1)), T(0, y - 0.06, 0.0))
        ctx.add("Metal", box(15.4, 0.12, 0.03, bevel=0.008), T(0, y - 0.07, ZF + 0.0 - 0.0 + 0.005))  # the ticket channel
    dye = Dye()
    # bottom shelf: spine-out back catalogue
    x = -W2 + 0.05
    while x < W2 - 0.25:
        if rng.random() < 0.03:  # a gap
            x += rng.uniform(0.3, 0.6)
            continue
        th = rng.uniform(0.19, 0.23)
        lean = 0.0 if rng.random() > 0.06 else rng.uniform(8, 14)
        m = T(x + th / 2, tops[0], -0.28) @ R(0, 0, -lean) @ T(0, 0.56, 0)
        ctx.add("Black", place(plain(th - 0.008, 1.12, 0.7), m))
        lab = place(plain(th - 0.05, 0.92, 0.012), m @ T(0, -0.02, -0.355))
        dye.add(lab, mult_of(COVERS[rng.randrange(len(COVERS))], PAPER))
        ctx.add("Paper", lab)
        x += th + (0.0 if lean == 0 else 0.15)
    # the three upper shelves: face-out new releases, copies behind
    for row, y in enumerate(tops[1:]):
        n = 20
        step = 15.2 / n
        for k in range(n):
            cx = -7.6 + step * (k + 0.5) + rng.uniform(-0.03, 0.03)
            copies = rng.choice((0, 1, 2, 3, 3, 4))
            if copies == 0:
                continue  # all rented
            lean = rng.uniform(7, 12)
            if copies > 1:  # the copies behind: their tops show
                ctx.add("Black", plain(0.64, 1.08, 0.21 * (copies - 1)),
                        T(cx, y + 0.54, -0.3 + 0.105 * (copies - 1)) @ R(lean * 0.5, 0, 0))
            m = T(cx, y, -0.42) @ R(lean, rng.uniform(-2, 2), 0) @ T(0, 0.56, -0.1)
            ctx.add("Black", place(plain(0.66, 1.12, 0.2), m))
            cov = place(plain(0.6, 1.04, 0.012), m @ T(0, 0, -0.105))
            c = COVERS[rng.randrange(len(COVERS))]
            dye.add(cov, mult_of(c, PAPER))
            ctx.add("Paper", cov)
            band = place(plain(0.56, 0.2, 0.012), m @ T(0, rng.choice((0.36, -0.36)), -0.114))
            dye.add(band, mult_of((40, 38, 36) if sum(c) > 380 else (225, 218, 200), PAPER))
            ctx.add("Paper", band)
    ctx.wear("WoodDark", mul(wood_wear(noise, 0.5, 0.3), shoe_scuffs(noise, 0.4, 0.4), dust_top(noise, 0.12)))
    ctx.wear("Wood", mul(wood_wear(noise, 0.3, 0.1), dust_top(noise, 0.15)))
    ctx.wear("Paper", dye.fn(lambda p: 0.9 + 0.1 * noise.fbm(p.co * 6, 2)))
    ctx.wear("Black", mul(edge_wear(0.25), dust_top(noise, 0.0)))
    ctx.wear("Metal", mul(cavity(0.3), lambda p: 0.8))


# ==============================================================================================
# PA SPEAKER. Real reference: a 15-inch two-way passive PA cabinet (Peavey / Electro-Voice
# "wedge-sided" box, ~ 50 x 75 x 45 cm): a trapezoid cabinet (narrower at the back, so a pair
# can be splayed), black carpet covering, steel corner protectors, recessed bar handles in the
# sides, a top-hat socket for a pole, a jack plate at the back; behind a black steel grille
# the woofer (cone, rubber surround, dust cap) and the constant-directivity horn above it.
# Data: Speaker 2 x 4 x 2 (y 1.9..5.9) on the floor west of the stage. Front = -Z.
# ==============================================================================================
def ext_y(poly, y0, y1, r, bevel, k=3, kb=2):
    """A convex plan outline [(x, z)] (counter-clockwise seen from below... any order works)
    extruded up from y0 to y1, its corners rounded by r, top and bottom edges by `bevel`."""
    from market import _rpoly

    st = []
    for s_ in range(kb + 1):
        a = math.radians(90.0 * s_ / kb)
        st.append((y0 + bevel - bevel * math.cos(a), bevel * (1 - math.sin(a))))
    for s_ in range(kb, -1, -1):
        a = math.radians(90.0 * s_ / kb)
        st.append((y1 - bevel + bevel * math.cos(a), bevel * (1 - math.sin(a))))
    rings = []
    for y, ins in st:
        rings.append([(a, y, b) for a, b in _rpoly(poly, r, k, ins)])
    return loft(rings, cap_start=True, cap_end=True)


def _pa_speaker(ctx, worn):
    ctx.budget = 5200
    ctx.smooth_angle = 40
    noise, rng = ctx.noise, ctx.rng
    y0, y1 = 0.08, 3.86
    FW, BW, ZF_, ZB_ = 1.92, 1.36, -0.86, 0.86
    plan = [(-FW / 2, ZF_), (FW / 2, ZF_), (BW / 2, ZB_), (-BW / 2, ZB_)]
    plan = plan[::-1] if True else plan
    ctx.add("FabricDark", ext_y(plan, y0, y1, 0.05, 0.05, k=2, kb=2))
    # the baffle and the grille's frame on the front
    ctx.add("Black", box(FW - 0.12, y1 - y0 - 0.14, 0.03), T(0, (y0 + y1) / 2, ZF_ - 0.005))
    # woofer behind the grille (cone, surround, dust cap), horn above it
    wy = y0 + 1.25
    ctx.add("Black", lathe([(0.0, -0.02), (0.74, -0.02), (0.74, 0.0), (0.68, 0.02), (0.6, 0.03), (0.2, 0.17), (0.12, 0.2), (0.0, 0.2)], segs=32),
            T(0, wy, ZF_ - 0.03) @ R(90, 0, 0) @ S(1, 1, 1))
    ctx.add("Rubber", _torus(0.66, 0.04, 32, 6), T(0, wy, ZF_ - 0.04) @ R(90, 0, 0))
    ctx.add("PlasticDark", sphere(0.15, 14, 8), T(0, wy, ZF_ + 0.14) @ S(1, 1, 0.45))
    hy = y0 + 2.75
    ctx.add("PlasticDark", _rr_loft([(ZF_ - 0.02, 1.5, 0.66, 0.05, 0, hy), (ZF_ + 0.02, 1.4, 0.58, 0.04, 0, hy),
                                     (ZF_ + 0.32, 0.3, 0.14, 0.03, 0, hy), (ZF_ + 0.4, 0.26, 0.12, 0.03, 0, hy)], "xy", k=3))
    # the grille: a frame and a mesh of thin bars, 0.07 in front of the baffle
    gz = ZF_ - 0.07
    dent = (lambda x, y: 0.05 * math.exp(-((x - 0.35) ** 2 + (y - 1.6) ** 2) / 0.08)) if worn else (lambda x, y: 0.0)
    for s_ in (-1, 1):
        ctx.add("MetalPainted", box(0.06, y1 - y0 - 0.12, 0.06, bevel=0.012), T(s_ * (FW / 2 - 0.07), (y0 + y1) / 2, gz))
        ctx.add("MetalPainted", box(FW - 0.08, 0.06, 0.06, bevel=0.012), T(0, y0 + 0.06 if s_ < 0 else y1 - 0.06, gz))
    nh, nv = 22, 11
    for i in range(nh):
        y = lerp(y0 + 0.13, y1 - 0.13, i / (nh - 1))
        nt = 6 if worn else 1
        pts = [(lerp(-FW / 2 + 0.08, FW / 2 - 0.08, t / nt), y, gz + dent(lerp(-FW / 2 + 0.08, FW / 2 - 0.08, t / nt), y - y0)) for t in range(nt + 1)]
        ctx.add("MetalPainted", tube(pts, 0.012, segs=4))
    for j in range(nv):
        x = lerp(-FW / 2 + 0.13, FW / 2 - 0.13, j / (nv - 1))
        nt = 10 if worn else 1
        pts = [(x, lerp(y0 + 0.08, y1 - 0.08, t / nt), gz - 0.015 + dent(x, lerp(0.08, y1 - y0 - 0.08, t / nt))) for t in range(nt + 1)]
        ctx.add("MetalPainted", tube(pts, 0.012, segs=4))
    ctx.add("Metal", _rbox(0.34, 0.08, 0.03, 0.02), T(0.55, y0 + 0.3, gz - 0.03))  # the badge
    ctx.tint("MetalPainted", (34, 34, 36))
    # corner protectors (one missing on the worn one)
    k = 0
    for sx in (-1, 1):
        for y in (y0 + 0.02, y1 - 0.02):
            for zc, half in ((ZF_, FW / 2), (ZB_, BW / 2)):
                k += 1
                if worn and k == 3:
                    continue
                ctx.add("Metal", sphere(0.11, 8, 5), T(sx * (half - 0.03), y, zc + (0.03 if zc < 0 else -0.03)) @ S(1, 0.8, 1))
    # recessed handles in the sides, the top-hat pole socket, feet, the jack plate and a cable
    for sx in (-1, 1):
        hx = sx * (lerp(FW, BW, 0.55) / 2 + 0.005)
        ang = math.degrees(math.atan2((FW - BW) / 2, ZB_ - ZF_)) * sx
        m = T(hx, y0 + 2.7, 0.1) @ R(0, ang, 0)
        ctx.add("Black", place(box(0.03, 0.3, 0.6, bevel=0.01), m))
        ctx.add("Metal", place(tube([(0.02, 0.0, -0.22), (0.02, 0.0, 0.22)], 0.025, segs=6), m))
    ctx.add("Metal", lathe([(0, y1 - 0.01), (0.14, y1 - 0.01), (0.15, y1 + 0.02), (0.12, y1 + 0.03), (0.08, y1 + 0.03), (0.08, y1 + 0.0), (0, y1 + 0.0)], segs=16),
            T(0, 0, 0.0))
    for sx in (-1, 1):
        for zc in (-0.6, 0.6):
            ctx.add("Rubber", cyl(0.09, 0.08, 8), T(sx * (0.7 if zc < 0 else 0.48), y0 / 2 + FLOOR / 2, zc))
    ctx.add("Metal", box(0.5, 0.36, 0.03, bevel=0.01), T(0, y0 + 0.7, ZB_ + 0.01))
    for x in (-0.1, 0.1):
        ctx.add("Black", cyl(0.05, 0.06, 10), T(x, y0 + 0.7, ZB_ + 0.04) @ R(90, 0, 0))
    ctx.add("Black", tube([(0.1, y0 + 0.7, ZB_ + 0.08), (0.12, y0 + 0.6, ZB_ + 0.25), (0.2, 0.2, ZB_ + 0.4), (0.4, 0.04, ZB_ + 0.5),
                           (0.9, 0.035, ZB_ + 0.55)], 0.035, segs=6))
    if worn:  # a strip of silver gaffer tape across the top, peeling at one end
        ctx.add("Reflective", box(1.2, 0.012, 0.16), T(-0.05, y1 + 0.006, -0.1) @ R(0, 12, 0))
        ctx.add("Reflective", box(0.16, 0.012, 0.14), T(0.62, y1 + 0.04, 0.03) @ R(0, 12, 28))
    def carpet(p):
        c = 1.0 + 0.25 * smoothstep(0.05, 0.4, p.convex) * (0.7 + 0.3 * noise.n(p.co * 6))  # rubbed grey on edges
        c *= 1 - 0.2 * (1 - smoothstep(0.0, 0.6, p.co.y))
        c *= 1 + 0.25 * smoothstep(0.6, 0.95, p.normal.y) * (0.5 + 0.5 * noise.fbm(p.co * 3, 2))  # dust on top
        return c
    ctx.wear("FabricDark", carpet)
    ctx.wear("MetalPainted", mul(edge_wear(0.3), scuffs(noise, 0.2, 5.0)))
    ctx.wear("Metal", mul(cavity(0.3), lambda p: 0.75 + 0.2 * noise.fbm(p.co * 8, 2)))
    _ = rng


def pa_speaker_floor(ctx):
    """15-inch PA cabinet on the floor: trapezoid box in black carpet, steel corner protectors,
    recessed handles, top-hat pole socket, a black steel grille over the woofer (cone, surround,
    dust cap) and the horn, a badge, the jack plate and its cable trailing off; carpet rubbed
    grey on the edges, dust on top."""
    _pa_speaker(ctx, worn=False)


def pa_speaker_floor_worn(ctx):
    """The same PA cabinet after years of gigs: the grille dented in, a corner protector gone,
    silver gaffer tape across the top peeling at one end."""
    _pa_speaker(ctx, worn=True)


# ==============================================================================================
# MIC STAND. Real reference: a round-base microphone stand (cast-iron base ~ 25 cm, chrome tube
# in two telescoping sections with a twist clutch, a mic clip on a short swivel) and an SM58
# dynamic mic (ball grille ~ 5 cm, tapering black handle, the XLR plug and cable), the cable
# looped down the stand and taped to it. Data: MicBase 0.8 disc on the stage top, MicStand to
# 4.1 above it, Mic at 4.2. Front = -Z (the singer's side: the mic points toward -Z).
# ==============================================================================================
def mic_stand(ctx):
    """Round-base mic stand: heavy cast base (dimpled, a rubber ring), chrome lower tube, twist
    clutch, thinner upper tube, a swivel and mic clip holding an SM58-type mic (steel ball
    grille with its band, tapering black handle, the XLR plug), the cable spiralling down the
    stand, taped, and off across the floor; chrome dulled, base scuffed."""
    ctx.budget = 3200
    ctx.smooth_angle = 40
    noise = ctx.noise
    ctx.add("Black", lathe([(0, FLOOR), (0.4, FLOOR), (0.42, 0.02), (0.41, 0.05), (0.3, 0.09), (0.1, 0.12), (0.06, 0.14), (0, 0.14)], segs=32))
    ctx.add("Rubber", _torus(0.39, 0.02, 32, 5), T(0, 0.02, 0))
    ctx.add("Chrome", cyl(0.045, 2.3, 12), T(0, 0.14 + 1.15, 0))
    ctx.add("Black", lathe([(0, 2.36), (0.065, 2.36), (0.075, 2.4), (0.075, 2.56), (0.06, 2.6), (0, 2.6)], segs=14))
    ctx.add("Chrome", cyl(0.03, 1.4, 10), T(0, 2.6 + 0.7, 0))
    top = 3.98
    ctx.add("Black", cyl(0.04, 0.08, 10), T(0, top + 0.02, 0))
    # the clip, tilted toward the singer
    tilt = R(-28, 0, 0)
    mb = Vector((0, top + 0.08, 0))
    m = T(mb.x, mb.y, mb.z) @ tilt
    ctx.add("Black", place(_rbox(0.1, 0.06, 0.08, 0.02), m @ T(0, 0.03, 0)))
    ctx.add("Black", place(lathe([(0.07, -0.12), (0.075, -0.12), (0.075, 0.12), (0.07, 0.12)], segs=14), m @ T(0, 0.08, -0.1) @ R(90, 0, 0) @ S(1, 1, 1)))
    # the mic: handle along the clip's axis (toward -Z, tilted up), the ball at the front
    def at(t):
        return m @ Vector((0, 0.08, -0.1 - t))
    hm = m @ T(0, 0.08, -0.1) @ R(-90, 0, 0)  # local +Y -> toward the front
    ctx.add("Black", place(lathe([(0, -0.3), (0.05, -0.3), (0.055, -0.27), (0.06, 0.0), (0.072, 0.18), (0.08, 0.22), (0, 0.22)], segs=16), hm))
    ctx.add("Metal", place(lathe([(0, 0.2), (0.09, 0.22), (0.11, 0.28), (0.115, 0.33), (0.1, 0.39), (0.06, 0.43), (0, 0.44)], segs=20), hm))
    ctx.add("Chrome", place(_torus(0.1, 0.014, 20, 5), hm @ T(0, 0.27, 0)))
    ctx.add("Chrome", place(cyl(0.05, 0.08, 12), hm @ T(0, -0.34, 0)))  # the XLR plug's shell
    # the cable: from the plug, down the stand in a loose spiral, taped twice, off over the floor
    p0 = hm @ Vector((0, -0.4, 0))
    pts = [p0, p0 + Vector((0.0, -0.18, 0.06))]
    for k in range(12):
        t = k / 11
        a = t * TAU * 1.3 + 0.8
        y = lerp(3.6, 0.35, t)
        rr = 0.1 if y > 2.6 else 0.12
        pts.append(Vector((math.cos(a) * rr, y, math.sin(a) * rr)))
    pts += [Vector((0.42, 0.13, 0.25)), Vector((0.75, 0.035, 0.35)), Vector((1.4, 0.035, 0.32))]
    ctx.add("Black", tube(pts, 0.028, segs=6))
    for y in (1.6, 3.2):
        ctx.add("Reflective", cyl(0.075, 0.1, 10), T(0, y, 0))
    ctx.wear("Chrome", mul(cavity(0.3), lambda p: 0.75 + 0.2 * noise.fbm(p.co * 6, 2)))
    ctx.wear("Black", mul(edge_wear(0.3), scuffs(noise, 0.2, 6.0)))
    ctx.wear("Metal", lambda p: 0.8 + 0.15 * noise.n(p.co * 20))
    ctx.wear("Reflective", lambda p: (0.6, 0.6, 0.58))


# ==============================================================================================
# ARCADE CABINET. Real reference: an 80s upright arcade cabinet (Pac-Man / Galaga dedicated
# cabinet: ~ 64 cm wide, 180 cm tall, 85 cm deep): two painted plywood side panels cut to the
# classic profile (marquee overhang, the monitor's sloped bezel, the control panel jutting out,
# the coin door below), black T-molding round their edges, the backlit marquee, a speaker grille
# under it, the CRT behind dark glass, the control panel (a joystick with a ball top, buttons),
# the steel coin door (two lit coin entries, coin returns, a lock), a kick plate, levelling
# feet; the back panel with vents and the power cord. Data: Arcade 2.4 x 6 x 2.4 (collider),
# ArcadeScreen (neon, kept by the overlay and fitted onto the glass). Front = -Z.
# ==============================================================================================
ARC_SCREEN = ((-0.43, 5.0), (-0.8, 3.72))  # the monitor glass's top and bottom (z, y) on its slope


def arcade_cabinet(ctx):
    """Upright 80s arcade cabinet: painted side panels cut to the classic profile with black
    T-molding round them, a lit marquee, the speaker grille, the CRT under its dark sloped glass
    in a bezel, the control panel (ball-top joystick, six buttons, a start button), the steel
    coin door with two lit coin entries, returns and a lock, kick plate, levelling feet, vents
    and the power cord at the back; paint chipped on the corners, kicked and greasy low, dust
    on the top."""
    ctx.budget = 6500
    ctx.smooth_angle = 35
    ctx.tint("MetalPainted", (36, 40, 80))
    noise, rng = ctx.noise, ctx.rng
    prof = [(-1.0, 0.06), (1.12, 0.06), (1.12, 5.96), (-0.66, 5.96), (-0.66, 5.2), (-0.44, 5.06), (-0.82, 3.66),
            (-1.18, 3.52), (-1.18, 3.22), (-0.94, 3.06), (-0.94, 0.3), (-1.0, 0.25)]
    for sx in (-1, 1):
        x0, x1 = (1.12, 1.19) if sx > 0 else (-1.19, -1.12)
        ctx.add("MetalPainted", ext_x(prof, x0, x1))
        path = [(sx * 1.155, y, z) for z, y in prof]
        ctx.add("PlasticDark", tube(path, 0.035, segs=6, closed=True))
    W = 2.24  # between the sides
    ctx.add("Black", box(W, 5.86, 0.04), T(0, 3.0, 1.1))  # back
    ctx.add("Black", box(W, 0.04, 1.76), T(0, 5.94, 0.23))  # top
    # marquee: lit panel in a thin black frame
    ctx.add("Glow", box(W - 0.06, 0.66, 0.03), T(0, 5.58, -0.64))
    for y in (5.23, 5.93):
        ctx.add("Black", box(W, 0.05, 0.06), T(0, y, -0.65))
    # speaker grille under the marquee (slots), the bezel round the monitor, the glass
    (zt, yt), (zb, yb) = ARC_SCREEN
    ang = math.degrees(math.atan2(zt - zb, yt - yb))  # the slope's lean back from vertical
    mid = Vector((0, (yt + yb) / 2, (zt + zb) / 2))
    ln = math.hypot(zt - zb, yt - yb)
    sm = T(mid.x, mid.y, mid.z) @ R(ang, 0, 0)  # local Y along the slope, -Z out of it
    ctx.add("Black", place(box(W, ln + 0.3, 0.04), sm @ T(0, 0.0, 0.03)))
    ctx.add("Screen", place(_rr_loft([(0.0, 1.5, 1.2, 0.08, 0, 0), (-0.012, 1.46, 1.16, 0.08, 0, 0), (-0.03, 1.2, 0.9, 0.08, 0, 0)], "xy", k=3), sm))
    ctx.add("PlasticDark", place(box(W, 0.18, 0.05), T(0, 5.12, -0.5) @ R(-35, 0, 0)))
    for k in range(9):
        ctx.add("Black", place(box(0.08, 0.1, 0.03), T(-0.5 + k * 0.125, 5.12, -0.53) @ R(-35, 0, 0)))
    # control panel: a box jutting out, its top sloping toward the player
    cp = [(-1.17, 3.22), (-0.9, 3.08), (-0.82, 3.66), (-1.17, 3.52)]
    cp = [(-1.17, 3.22), (-0.86, 3.07), (-0.8, 3.66), (-1.17, 3.52)][::-1]
    ctx.add("PlasticDark", ext_x([(z, y) for z, y in [(-1.17, 3.23), (-0.86, 3.07), (-0.8, 3.65), (-1.17, 3.51)]], -W / 2, W / 2))
    top_a = math.degrees(math.atan2(3.65 - 3.51, -0.8 + 1.17))
    tm = T(0, (3.65 + 3.51) / 2, (-0.8 - 1.17) / 2) @ R(-top_a, 0, 0)
    ctx.add("MetalPainted", place(box(W - 0.02, 0.02, 0.4), tm @ T(0, 0.01, 0)))
    dye = Dye()
    jx = -0.45
    ctx.add("Black", place(cyl(0.09, 0.02, 14), tm @ T(jx, 0.025, 0.0)))
    ctx.add("Chrome", place(cyl(0.022, 0.28, 8), tm @ T(jx, 0.16, 0.0) @ R(8, 0, -6)))
    ball = place(sphere(0.09, 14, 9), tm @ T(jx + 0.03, 0.32, -0.02))
    dye.add(ball, (0.8, 0.18, 0.16))
    ctx.add("Reflective", ball)
    for k, (bx_, col) in enumerate(((0.05, (0.85, 0.2, 0.18)), (0.25, (0.95, 0.82, 0.3)), (0.45, (0.3, 0.45, 0.85)))):
        for row in (0, 1):
            b = place(lathe([(0, 0.0), (0.06, 0.0), (0.06, 0.03), (0.05, 0.045), (0, 0.05)], segs=12), tm @ T(bx_ + row * 0.06, 0.02, -0.08 + row * 0.16))
            dye.add(b, col)
            ctx.add("Reflective", b)
    st = place(lathe([(0, 0.0), (0.045, 0.0), (0.045, 0.025), (0, 0.03)], segs=10), tm @ T(0.85, 0.02, 0.05))
    dye.add(st, (1.0, 1.0, 0.95))
    ctx.add("Reflective", st)
    # front: lower panel, coin door, kick plate, feet
    ctx.add("PlasticDark", box(W, 2.76, 0.04), T(0, 1.68, -0.92))
    ctx.add("Metal", box(0.84, 1.2, 0.04, bevel=0.012), T(0, 2.05, -0.95))
    for x in (-0.2, 0.2):
        ctx.add("Black", box(0.18, 0.3, 0.03, bevel=0.01), T(x, 2.3, -0.975))
        ctx.add("Glow", box(0.06, 0.12, 0.02), T(x, 2.32, -0.99))
        ctx.add("Black", box(0.16, 0.12, 0.03, bevel=0.01), T(x, 1.72, -0.975))
    ctx.add("Chrome", cyl(0.04, 0.03, 10), T(0, 2.48, -0.975) @ R(90, 0, 0))
    ctx.add("Metal", box(W, 0.26, 0.05, bevel=0.012), T(0, 0.17, -0.985))
    for sx in (-1, 1):
        for zc in (-0.8, 0.95):
            ctx.add("Metal", cyl(0.06, 0.06, 8), T(sx * 1.0, 0.03 + FLOOR / 2, zc))
    for k in range(6):  # back vents and the cord
        ctx.add("PlasticDark", box(1.0, 0.04, 0.03), T(0, 4.6 + k * 0.12, 1.135))
    ctx.add("Black", tube([(0.6, 0.6, 1.13), (0.64, 0.4, 1.15), (0.7, 0.04, 1.16), (1.06, 0.035, 1.16)], 0.03, segs=6))

    def paint(p):
        c = 1.0 - 0.3 * (1 - smoothstep(0.0, 1.2, p.co.y)) * (0.6 + 0.4 * noise.fbm(p.co * 3, 2))
        c *= 1 + 0.35 * smoothstep(0.2, 0.6, p.convex) * smoothstep(0.55, 0.75, noise.fbm(p.co * 5, 2) * 0.5 + 0.5)
        c *= 1 - 0.2 * smoothstep(0.0, 0.5, -p.convex)
        return c

    ctx.wear("MetalPainted", paint)
    ctx.wear("PlasticDark", mul(cavity(0.3), edge_wear(0.25), shoe_scuffs(noise, 1.0, 0.3), dust_top(noise, 0.0)))
    ctx.wear("Black", mul(cavity(0.2), dust_top(noise, 0.0)))
    ctx.wear("Reflective", dye.fn(mul(cavity(0.3), lambda p: 0.9 + 0.1 * noise.n(p.co * 15))))
    ctx.wear("Metal", mul(cavity(0.35), lambda p: 0.7 + 0.25 * noise.fbm(p.co * 6, 2)))
    _ = (rng, cp)


# ==============================================================================================
# MIRROR BALL. Real reference: a 30-40 cm disco mirror ball: a sphere covered in ~1 cm square
# glass mirror tiles glued in latitude rows (the rows shorter toward the poles), dark glue lines
# between them, an eye bolt on top, hung on a chain from a small rotating motor screwed to the
# ceiling. Data: MirrorBall 1.4 ball (centre 1.9 under the ceiling), its Chain. Origin: the
# ceiling face, the piece hangs down.
# ==============================================================================================
def mirror_ball(ctx):
    """Disco mirror ball: ~ 280 square mirror tiles in latitude rows over a dark core (glue
    lines between them), a few catching the light, an eye bolt, a chain of real links up to the
    small rotator motor on its ceiling plate; tiles dulled with dust on the upper half."""
    ctx.budget = 5400
    ctx.smooth_angle = 1
    noise, rng = ctx.noise, ctx.rng
    ctx.add("Metal", cyl(0.2, 0.03, 16, bevel=0.008), T(0, -0.015, 0))
    ctx.add("Black", lathe([(0, -0.03), (0.15, -0.03), (0.15, -0.26), (0.12, -0.29), (0, -0.29)], segs=16))
    ctx.add("Metal", cyl(0.025, 0.08, 8), T(0, -0.32, 0))
    # the chain: links alternating 90 degrees
    y = -0.36
    k = 0
    while y > -1.12:
        ctx.add("Metal", place(_torus(0.04, 0.011, 10, 4), T(0, y, 0) @ R(0, 90 * (k % 2), 90) @ S(1, 1, 1.6)))
        y -= 0.09
        k += 1
    cy, rad = -1.9, 0.68
    ctx.add("Metal", place(_torus(0.05, 0.014, 10, 4), T(0, cy + rad + 0.07, 0) @ R(0, 0, 90)))
    ctx.add("Metal", cyl(0.02, 0.06, 6), T(0, cy + rad + 0.01, 0))
    ctx.add("Black", sphere(rad - 0.005, 24, 14), T(0, cy, 0))
    tile = 0.138
    rows = int(round(math.pi * rad / tile))
    lit = set()
    for i in range(rows):
        lat = -math.pi / 2 + math.pi * (i + 0.5) / rows
        n = max(3, int(round(TAU * rad * math.cos(lat) / tile)))
        off = rng.uniform(0, TAU)
        for j in range(n):
            lon = off + TAU * j / n
            nrm = Vector((math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon)))
            c = Vector((0, cy, 0)) + nrm * (rad + 0.004)
            east = Vector((-math.sin(lon), 0.0, math.cos(lon)))
            north = nrm.cross(east).normalized()
            rot = Matrix((east, north, nrm)).transposed().to_4x4()  # (columns: tile x, y, z)
            m = Matrix.Translation(c) @ rot
            w = min(tile, TAU * rad * math.cos(lat) / n) - 0.022
            layer = "Glow" if (rng.random() < 0.03 and nrm.y < 0.2) else "Chrome"
            ctx.add(layer, place(plain(w, tile - 0.022, 0.012), m))
            if layer == "Glow":
                lit.add((i, j))
    ctx.wear("Chrome", lambda p: (0.82 + 0.18 * noise.n(p.co * 25)) * (1 - 0.12 * smoothstep(-1.9, -1.3, p.co.y)))
    ctx.wear("Metal", mul(cavity(0.3), lambda p: 0.75))
    ctx.wear("Black", lambda p: 0.6)
    ctx.doc = "Disco mirror ball on its chain and rotator motor (origin on the ceiling, hangs 2.6)."
    _ = lit


# ==============================================================================================
# HOLLOW THREADS
# ==============================================================================================
# MANNEQUINS. Real reference: a male fibreglass display mannequin (~ 185 cm, an abstract egg
# head, matt off-white finish), standing on a calf rod screwed into a round steel base plate,
# feet a few cm off the plate; poses: relaxed (arms down, slight bend) or contrapposto with one
# hand on the hip. Proportions from a standing adult (heights as a fraction of the stature:
# knee 0.285, crotch 0.47, waist 0.61, chest 0.72, shoulder 0.82, chin 0.87; shoulder breadth
# 0.23). What reads: the smooth continuous body (no blocks), the egg head, the hands' shape, the
# base and rod. Wear: chips and grey scuffs on hands, elbows and toes, dust on the shoulders.
# Data (Mannequin_<Outfit> Models): base 2.6 on the plinth, the figure's soles 0.25 over the
# base's bottom, head top 5.45 over it. Origin: the base plate's bottom centre. Front = -Z (the
# overlay turns each one to face the window, as citygen's figures did).
# ==============================================================================================
MQ_SOLE = 0.12


def _mq_pose(b):
    """The pose: leg and arm paths (hip -> knee -> ankle, shoulder -> elbow -> wrist), the hands'
    frames, the head's tilt. b: False = relaxed, True = hand on hip / weight on one leg."""
    if not b:
        legs = [[(sx * 0.26, 2.86, 0.0), (sx * 0.25, 2.2, -0.02), (sx * 0.24, 1.62, -0.03), (sx * 0.23, 0.9, 0.02), (sx * 0.22, 0.36, 0.04)]
                for sx in (-1, 1)]
        arms = [[(sx * 0.5, 4.36, 0.02), (sx * 0.64, 4.2, 0.03), (sx * 0.72, 3.8, 0.05), (sx * 0.74, 3.4, 0.05), (sx * 0.76, 3.0, -0.03),
                 (sx * 0.76, 2.66, -0.1)] for sx in (-1, 1)]
        tilt = (3.0, 4.0, 0.0)
    else:
        legs = [[(-0.26, 2.86, 0.0), (-0.24, 2.2, -0.02), (-0.23, 1.62, -0.03), (-0.22, 0.9, 0.02), (-0.22, 0.36, 0.04)],  # straight
                [(0.27, 2.84, 0.0), (0.27, 2.2, -0.08), (0.24, 1.66, -0.16), (0.3, 0.95, -0.06), (0.36, 0.38, 0.0)]]  # relaxed, knee forward
        arms = [[(-0.5, 4.36, 0.02), (-0.64, 4.2, 0.03), (-0.72, 3.8, 0.06), (-0.75, 3.4, 0.06), (-0.77, 3.0, -0.02), (-0.77, 2.66, -0.08)],
                [(0.5, 4.36, 0.02), (0.68, 4.18, 0.04), (0.86, 3.85, 0.1), (1.0, 3.55, 0.14), (0.86, 3.28, 0.06), (0.66, 3.08, -0.02)]]
        tilt = (-2.0, -12.0, 4.0)
    return legs, arms, tilt


LEG_R = [(0.0, 0.27), (0.2, 0.235), (0.45, 0.16), (0.55, 0.15), (0.7, 0.155), (0.88, 0.11), (1.0, 0.085)]
ARM_R = [(0.0, 0.17), (0.18, 0.15), (0.45, 0.115), (0.55, 0.11), (0.7, 0.1), (1.0, 0.07)]


def _radius(table, t):
    for (t0, r0), (t1, r1) in zip(table, table[1:]):
        if t0 <= t <= t1:
            return lerp(r0, r1, smoothstep(0, 1, (t - t0) / max(t1 - t0, 1e-6)))
    return table[-1][1]


def _limb(path, table, extra=0.0, n=16, segs=12, noise=None, seed=0.0, wrinkle=0.0, flat=0.9, t1=1.0):
    """A limb (or a sleeve / trouser leg when extra > 0) swept along a smoothed path, its radius
    from `table` (+ extra), slightly flattened (flat), wrinkled by noise near bends. t1: where
    it stops along the path (a sleeve ends at the wrist, a trouser leg at the ankle)."""
    from market import _resample

    pts = _resample(path, n + int(n * (1 - t1) / max(t1, 0.2)))
    m = max(2, int(round((len(pts) - 1) * t1)) + 1)
    pts = pts[:m]

    def sec(i):
        t = i / (len(pts) - 1) * t1
        r = _radius(table, t) + extra
        out = []
        for k in range(segs):
            a = TAU * k / segs
            j = 1.0
            if noise is not None and wrinkle > 0:
                j += wrinkle * noise.n((i * 0.8 + seed, k * 0.9, seed * 0.3))
            out.append((r * math.cos(a) * j, r * flat * math.sin(a) * j))
        return out

    return _sweep(pts, sec, ups=[Vector((0, 0, -1))] * len(pts)), pts


TORSO = [  # y, half width, half depth, centre z (the body's rings, crotch to neck)
    (2.56, 0.4, 0.27, 0.0), (2.66, 0.5, 0.31, 0.02), (2.86, 0.56, 0.34, 0.03), (3.1, 0.5, 0.31, 0.01), (3.36, 0.46, 0.29, 0.0),
    (3.65, 0.5, 0.31, -0.01), (3.95, 0.56, 0.36, -0.03), (4.2, 0.6, 0.35, -0.01), (4.38, 0.6, 0.28, 0.01), (4.48, 0.42, 0.22, 0.01),
    (4.55, 0.2, 0.17, 0.0)]


def _ring(hw, hd, cz, y, segs=28, p=2.5, warp=None):
    out = []
    for k in range(segs):
        a = TAU * k / segs
        c, s_ = math.cos(a), math.sin(a)
        x = hw * math.copysign(abs(c) ** (2 / p), c)
        z = cz + hd * math.copysign(abs(s_) ** (2 / p), s_)
        q = Vector((x, y, z))
        out.append(tuple(warp(q, a)) if warp else tuple(q))
    return out


def _torso(off=0.0, y0=None, y1=None, segs=28, warp=None, off_fn=None):
    """The torso skin (or a garment over it: off = how far off the skin), between y0 and y1."""
    rows = [r for r in TORSO if (y0 is None or r[0] >= y0 - 1e-6) and (y1 is None or r[0] <= y1 + 1e-6)]
    if y0 is not None and rows[0][0] > y0:
        rows = [_torso_at(y0)] + rows
    if y1 is not None and rows[-1][0] < y1:
        rows = rows + [_torso_at(y1)]
    rings = []
    for y, hw, hd, cz in rows:
        o = off_fn(y) if off_fn else off
        # (the rings round off toward the shoulders: no corner peaks above the sleeves)
        rings.append(_ring(hw + o, hd + o, cz, y, segs, p=lerp(2.5, 2.0, smoothstep(3.9, 4.4, y)), warp=warp))
    return loft(rings, cap_start=True, cap_end=True)


def _torso_at(y):
    for a, b in zip(TORSO, TORSO[1:]):
        if a[0] <= y <= b[0]:
            t = (y - a[0]) / (b[0] - a[0])
            return (y, lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t))
    return TORSO[0] if y < TORSO[0][0] else TORSO[-1]


def _mannequin_body(ctx, b):
    ctx.budget = 5500
    ctx.smooth_angle = 60
    ctx.tint("Plastic", (206, 202, 194))
    noise, rng = ctx.noise, ctx.rng
    legs, arms, tilt = _mq_pose(b)
    # base plate and rod (into the straight leg's calf)
    ctx.add("Chrome", lathe([(0, FLOOR), (0.78, FLOOR), (0.8, 0.025), (0.8, 0.045), (0.77, 0.06), (0, 0.06)], segs=40))
    ctx.add("Chrome", cyl(0.06, 0.03, 12), T(legs[0][3][0], 0.075, legs[0][3][2] + 0.04))
    rx, rz = legs[0][3][0], legs[0][3][2] + 0.04
    ctx.add("Chrome", cyl(0.035, 1.1, 10), T(rx, 0.6, rz))
    ctx.add("Plastic", _torso())
    for path in legs:
        ctx.add("Plastic", _limb(path, LEG_R, n=18, segs=14)[0])
        # the foot: heel under the ankle, toes forward, the sole flat at MQ_SOLE
        ax, _ay, az = path[-1]
        st = [(az + 0.16, 0.18, 0.16, 0.07, ax, MQ_SOLE + 0.1), (az + 0.08, 0.24, 0.26, 0.1, ax, MQ_SOLE + 0.13),
              (az - 0.12, 0.27, 0.2, 0.08, ax, MQ_SOLE + 0.1), (az - 0.36, 0.29, 0.13, 0.06, ax, MQ_SOLE + 0.065),
              (az - 0.52, 0.24, 0.09, 0.04, ax, MQ_SOLE + 0.045), (az - 0.58, 0.14, 0.06, 0.025, ax, MQ_SOLE + 0.035)]
        rings = []
        for z, w, h, r, cx, cy in st:
            rings.append([(cx + a, cy + bb, z) for a, bb in _rr(w, h, r, 3, 0)])
        ctx.add("Plastic", loft(rings, cap_start=True, cap_end=True))
    for k, path in enumerate(arms):
        ctx.add("Plastic", _limb(path, ARM_R, n=16, segs=12)[0])
        # the hand: a flattened mitten along the forearm's direction, a thumb
        from market import _resample
        pts = _resample(path, 12)
        d = (pts[-1] - pts[-3]).normalized()
        w = pts[-1]
        hip_hand = b and k == 1
        if hip_hand:
            d = (Vector((-0.6, -0.55, -0.1))).normalized()
        side = Vector((0, 0, -1)).cross(d).normalized() if abs(d.z) < 0.9 else Vector((1, 0, 0))
        up = d.cross(side).normalized()
        rot = Matrix((side, d, up)).transposed().to_4x4()
        hc = w + d * 0.17
        hand = sphere(1.0, 12, 8)
        bmesh.ops.scale(hand, vec=(0.075, 0.2, 0.13), verts=hand.verts)
        ctx.add("Plastic", place(hand, Matrix.Translation(hc) @ rot))
        th = sphere(1.0, 8, 6)
        bmesh.ops.scale(th, vec=(0.04, 0.1, 0.04), verts=th.verts)
        ctx.add("Plastic", place(th, Matrix.Translation(hc) @ rot @ T(0.03, -0.04, -0.12) @ R(-30, 0, 0)))
    # neck and the abstract egg head
    ctx.add("Plastic", tube([(0, 4.42, 0.02), (0, 4.62, 0.01), (0, 4.8, -0.01)], [0.15, 0.135, 0.13], segs=14))
    head = lathe([(0, 0.0), (0.13, 0.02), (0.2, 0.1), (0.235, 0.24), (0.24, 0.38), (0.22, 0.52), (0.16, 0.63), (0.08, 0.68), (0, 0.69)], segs=22)
    bmesh.ops.scale(head, vec=(1.0, 1.0, 1.22), verts=head.verts)
    ctx.add("Plastic", place(head, T(0, 4.74, -0.04) @ R(*tilt)))

    def finish(p):
        c = 1 - 0.18 * smoothstep(0.0, 0.4, -p.convex)
        c *= 1 - 0.12 * smoothstep(0.6, 0.95, p.normal.y) * (0.5 + 0.5 * noise.fbm(p.co * 3, 2))  # dust
        # grey rub and chips at the hands, elbows, knees and toes (the places that get knocked)
        chip = smoothstep(0.6, 0.85, noise.fbm(p.co * 9, 3) * 0.5 + 0.5)
        low = 1 - smoothstep(0.1, 0.5, p.co.y)
        c *= 1 - 0.3 * chip * (0.4 + 0.6 * low)
        return (c, c * 0.99, c * 0.97)

    ctx.wear("Plastic", finish)
    ctx.wear("Chrome", mul(cavity(0.3), lambda p: 0.8 + 0.15 * noise.fbm(p.co * 6, 2), dust_top(noise, 0.1)))
    _ = rng


def _cloth(noise, rib_y=None):
    def fn(p):
        k = 0.88 + 0.12 * noise.fbm(p.co * 7, 2)
        k *= 1 - 0.3 * smoothstep(0.0, 0.35, -p.convex)
        k *= 1 + 0.1 * smoothstep(0.6, 0.95, p.normal.y)
        return k * 0.95
    return fn


def _mannequin_top(ctx, b):
    """A long-sleeved crew sweater on the pose: body shell off the skin (looser below the chest,
    blousing over the trousers' waist), sleeves along the arms to ribbed cuffs, a rib collar and
    hem band; soft folds at the elbows and the waist."""
    ctx.budget = 4200
    ctx.smooth_angle = 60
    ctx.tint("Fabric", (60, 60, 64))
    noise, rng = ctx.noise, ctx.rng
    legs, arms, _tilt = _mq_pose(b)
    hem = 2.74

    def off(y):
        return lerp(0.12, 0.05, smoothstep(3.3, 3.95, y))

    def warp(q, a):
        f = noise.fbm((q.x * 2.2, q.y * 3.0, q.z * 2.2), 2) * 0.03 * smoothstep(3.9, 3.0, q.y)
        return q + Vector((q.x, 0, q.z - 0.0)).normalized() * f if (q.x * q.x + q.z * q.z) > 1e-6 else q

    ctx.add("Fabric", _torso(y0=hem, y1=4.55, off_fn=off, warp=warp))
    # rib hem band and collar
    hb = _torso_at(hem + 0.06)
    ctx.add("Fabric", loft([_ring(hb[1] + 0.1, hb[2] + 0.1, hb[3], hem - 0.005, 28), _ring(hb[1] + 0.11, hb[2] + 0.11, hb[3], hem + 0.12, 28)],
                           cap_start=True, cap_end=True))
    ctx.add("Fabric", _torus(0.2, 0.035, 20, 6), T(0, 4.56, 0.0) @ S(1, 1, 0.95))
    for k, path in enumerate(arms):
        sl, pts = _limb(path, ARM_R, extra=0.055, n=16, segs=12, noise=noise, seed=k * 3.1 + rng.uniform(0, 2), wrinkle=0.12, t1=0.96)
        ctx.add("Fabric", sl)
        d = (pts[-1] - pts[-2]).normalized()
        c0 = pts[-1] - d * 0.02
        ctx.add("Fabric", _sweep([c0, c0 + d * 0.12], [(u * 1.0, v * 1.0) for u, v in _ellipse(0.105, 0.095, 12)], ups=[Vector((0, 0, -1))] * 2))
    ctx.wear("Fabric", _cloth(noise))
    _ = legs


def _mannequin_legs(ctx, b):
    """Straight-leg trousers on the pose: the seat and the waistband, the legs off the skin,
    looser below the knee, the hems breaking on the feet."""
    ctx.budget = 4200
    ctx.smooth_angle = 60
    ctx.tint("Fabric", (40, 44, 58))
    noise, rng = ctx.noise, ctx.rng
    legs, _arms, _tilt = _mq_pose(b)
    ctx.add("Fabric", _torso(off=0.05, y0=2.56, y1=3.42))
    wb = _torso_at(3.36)
    ctx.add("Fabric", loft([_ring(wb[1] + 0.06, wb[2] + 0.06, wb[3], 3.28, 28), _ring(wb[1] + 0.065, wb[2] + 0.065, wb[3], 3.44, 28)],
                           cap_start=True, cap_end=True))
    # (no belt loops, fly or back pockets: the sweater's hem always covers them)
    table = [(t, r + (0.05 if t < 0.5 else 0.05 + 0.05 * smoothstep(0.5, 0.75, t))) for t, r in LEG_R]
    for k, path in enumerate(legs):
        p2 = [tuple(pt) for pt in path]
        lg, pts = _limb(p2, table, extra=0.0, n=18, segs=14, noise=noise, seed=k * 2.3 + rng.uniform(0, 2), wrinkle=0.08, t1=0.97)
        ctx.add("Fabric", lg)
    ctx.wear("Fabric", _cloth(noise))


def mannequin_display(ctx):
    """Male fibreglass display mannequin, relaxed pose: smooth matt off-white body, abstract egg
    head, real hands, on a calf rod and a round steel base plate; chips and grey rubs on the
    hands, knees and toes, dust on the shoulders. Dressed by MannequinTop + MannequinLegs."""
    _mannequin_body(ctx, False)


def mannequin_display_b(ctx):
    """The same mannequin in contrapposto: one hand on the hip, weight on the straight leg, the
    other knee forward, the head turned."""
    _mannequin_body(ctx, True)


def mannequin_top(ctx):
    """The relaxed mannequin's sweater (coloured by the shop's outfit: 'Top' in the name)."""
    _mannequin_top(ctx, False)


def mannequin_top_b(ctx):
    """The hand-on-hip mannequin's sweater."""
    _mannequin_top(ctx, True)


def mannequin_legs(ctx):
    """The relaxed mannequin's trousers (coloured by the shop's outfit: 'Leg' in the name)."""
    _mannequin_legs(ctx, False)


def mannequin_legs_b(ctx):
    """The hand-on-hip mannequin's trousers."""
    _mannequin_legs(ctx, True)


# ==============================================================================================
# GARMENTS ON HANGERS (the shop's face-out pegs above the shelving; origin = the hook's rod).
# Real references: a flannel work shirt (button front with its placket, two-point collar, a
# flapped chest pocket, cuffs) on a wire hanger; a full-zip hoodie (open a little at the top,
# the zip's teeth, two slanted hand pockets, ribbed cuffs and hem, the hood hanging behind) on
# a plastic hanger. Built with the market kit's garment tools (pieces/market.py: _Garment).
# ==============================================================================================
def shirt_on_hanger(ctx):
    """Flannel button-up shirt on a wire hanger: soft drape folds, the two-point collar, the
    placket with its buttons, a flapped chest pocket, limp sleeves with buttoned cuffs; faded
    at the shoulders, grimy cuffs."""
    ctx.budget = 4500
    ctx.smooth_angle = 70
    ctx.tint("Fabric", (128, 44, 40))
    noise, rng = ctx.noise, ctx.rng
    hem = -2.25
    fold = _drape(noise, 0.06, TIP[1] - 0.15, wave=0.36, seed=rng.uniform(0, 6), hem=hem)

    def prof(y):
        t = smoothstep(TIP[1] + 0.05, TIP[1] - 0.5, y)
        a = lerp(TIP[0] + 0.01, 0.7, t) + 0.03 * smoothstep(-1.2, hem, y)
        return a, lerp(0.06, 0.17, t), lerp(0.05, 0.15, t)

    g = _Garment(hem, prof, fold, n=36)
    ctx.add("Fabric", g.build())
    # the placket down the front, its buttons
    pts = [Vector((0.0, y, g.front(0.0, y) - 0.012)) for y in [lerp(NECK[1] - 0.08, hem + 0.05, k / 9) for k in range(10)]]
    ctx.add("Fabric", _sweep(pts, [(-0.06, -0.008), (0.06, -0.008), (0.06, 0.008), (-0.06, 0.008)], ups=[Vector((0, 0, -1))] * 10))
    for k in range(6):
        y = lerp(NECK[1] - 0.14, hem + 0.3, k / 5)
        ctx.add("Reflective", cyl(0.028, 0.02, 8), T(0.0, y, g.front(0.0, y) - 0.03) @ R(90, 0, 0))
    # the collar: two points folded down over the chest, a band round the back of the neck
    for sx in (-1, 1):
        rows, cols = 4, 4
        top, bot = [], []
        for i_ in range(rows):
            v = i_ / (rows - 1)
            rt, rb = [], []
            for j in range(cols):
                u = j / (cols - 1)
                x = sx * lerp(0.03 + 0.2 * v, 0.24 - 0.06 * v, u)
                y = lerp(NECK[1] - 0.02, NECK[1] - 0.26 - 0.05 * u, v)
                z = g.front(x, y) - 0.025 - 0.02 * (1 - v)
                rt.append(Vector((x, y, z - 0.02)))
                rb.append(Vector((x, y, z + 0.004)))
            top.append(rt)
            bot.append(rb)
        ctx.add("Fabric", _grid_slab(top, bot))
    band = [((NECK[0] + 0.03) * math.cos(math.radians(a)), NECK[1] + 0.0, 0.12 * -math.sin(math.radians(a)) + 0.02) for a in range(200, 341, 20)]
    ctx.add("Fabric", _sweep(band, [(-0.015, -0.04), (0.015, -0.04), (0.02, 0.05), (-0.01, 0.05)], ups=Vector((0, 1, 0))))
    # the chest pocket with its flap and button
    px, py = 0.34, -0.95
    ctx.add("Fabric", box(0.3, 0.34, 0.02), T(px, py, g.front(px, py) - 0.012))
    ctx.add("Fabric", box(0.32, 0.1, 0.025), T(px, py + 0.16, g.front(px, py + 0.16) - 0.03))
    ctx.add("Reflective", cyl(0.022, 0.015, 8), T(px, py + 0.14, g.front(px, py + 0.14) - 0.05) @ R(90, 0, 0))
    for sx in (-1, 1):
        sl, pts = _sleeve(_sleeve_path(sx, hem + 0.12, fwd=0.05, out=0.01), (0.09, 0.15), (0.07, 0.1), noise, sx * 4.0 + 1.5,
                          n=14, segs=10, bunch=0.3)
        ctx.add("Fabric", sl)
        d = (pts[-1] - pts[-2]).normalized()
        c0 = pts[-1] - d * 0.02
        ctx.add("Fabric", _sweep([c0, c0 + d * 0.16], _ellipse(0.074, 0.105, 10), ups=[Vector((0, 0, -1))] * 2))
    _wire_hanger(ctx)

    def flannel(p):
        k = 0.85 + 0.15 * noise.fbm(p.co * 6, 2)
        # the check: darker bands crossing (vertex colours on the folds' grid)
        chk = 0.5 + 0.5 * math.sin(p.co.x * 18) * math.sin(p.co.y * 18)
        k *= 1 - 0.18 * smoothstep(0.4, 0.9, chk)
        k *= 1 - 0.3 * smoothstep(0.0, 0.35, -p.convex)
        k *= 1 + 0.12 * smoothstep(0.6, 0.95, p.normal.y)
        return k

    ctx.wear("Fabric", flannel)
    ctx.wear("Reflective", lambda p: (0.92, 0.9, 0.84))
    ctx.wear("Metal", lambda p: 0.8)


def hoodie_on_hanger(ctx):
    """Full-zip hoodie on a plastic hanger: the zip open a hand's width at the top (its metal
    teeth, the pull), two slanted hand pockets, the hood hanging down the back with its rim
    behind the neck, drawstrings, ribbed cuffs and hem band; pilled cotton, many soft folds."""
    ctx.budget = 5200
    ctx.smooth_angle = 70
    ctx.tint("Fabric", (58, 62, 54))
    noise, rng = ctx.noise, ctx.rng
    hem = -2.45
    band = 0.18
    fold = _drape(noise, 0.085, TIP[1] - 0.15, wave=0.42, seed=rng.uniform(0, 6), hem=hem)

    def prof(y):
        t = smoothstep(TIP[1] + 0.05, TIP[1] - 0.55, y)
        a = lerp(TIP[0] + 0.02, 0.8, t)
        bf, bb = lerp(0.07, 0.22, t), lerp(0.06, 0.19, t)
        if y < hem + band + 0.04:
            k = smoothstep(hem + band + 0.04, hem + band - 0.02, y)
            a -= 0.1 * k
            bf -= 0.05 * k
            bb -= 0.04 * k
        return a, bf, bb

    rings = [y for y in _Garment.default_rings(hem) if y > hem + band + 0.06] + [hem + band + 0.04, hem + band, hem + 0.1, hem]
    g = _Garment(hem, prof, fold, n=38, rings=rings)
    ctx.add("Fabric", g.build())
    # the zip: two tapes with teeth up the front, opening into a V near the top
    for sx in (-1, 1):
        pts = []
        for k in range(10):
            y = lerp(hem + 0.02, NECK[1] - 0.1, k / 9)
            x = sx * (0.012 + 0.1 * smoothstep(-1.1, NECK[1] - 0.1, y))
            pts.append(Vector((x, y, g.front(x, y) - 0.014)))
        ctx.add("Metal", _sweep(pts, [(-0.014, -0.006), (0.014, -0.006), (0.014, 0.008), (-0.014, 0.008)], ups=[Vector((0, 0, -1))] * 10))
    zy = -1.12
    ctx.add("Metal", _rbox(0.05, 0.12, 0.025, 0.012), T(0.0, zy - 0.06, g.front(0, zy) - 0.04))
    # hand pockets (slanted welts)
    for sx in (-1, 1):
        pts = []
        for k in range(5):
            x = sx * lerp(0.22, 0.48, k / 4)
            y = lerp(hem + band + 0.5, hem + band + 0.1, k / 4)
            pts.append(Vector((x, y, g.front(x, y) - 0.012)))
        ctx.add("Fabric", _sweep(pts, [(-0.03, -0.012), (0.03, -0.012), (0.03, 0.01), (-0.03, 0.01)], ups=[Vector((0, 0, -1))] * 5))
    # the hood down the back (a puffy shell pressed on the back) and its rim behind the neck
    hood = bmesh.new()
    bmesh.ops.create_uvsphere(hood, u_segments=16, v_segments=10, radius=1.0)
    hc = Vector((0.0, -0.8, 0.0))
    for v in hood.verts:
        n = v.co.normalized()
        q = hc + Vector((n.x * 0.42, n.y * 0.46, 0.0))
        bz = g.back(q.x, q.y)
        puff = 0.12 * max(n.z, 0.0) ** 0.7 * (1 + 0.15 * noise.fbm(n * 2.2, 2))
        q.z = bz + 0.01 + puff if n.z > -0.05 else bz - 0.05
        v.co = q
    ctx.add("Fabric", hood)
    rim = []
    for k in range(13):
        th = math.radians(lerp(195, 345, k / 12))
        rim.append(((NECK[0] + 0.07) * math.cos(th), NECK[1] - 0.05 + 0.05 * math.sin(math.pi * k / 12), 0.16 * -math.sin(th) + 0.04))
    ctx.add("Fabric", tube(rim, 0.055, segs=8))
    for sx in (-1, 1):
        cord = []
        for k in range(7):
            t = k / 6
            y = lerp(NECK[1] - 0.12, -0.95 - 0.1 * (sx > 0), t)
            x = sx * (0.16 + 0.02 * t)
            cord.append(Vector((x, y, g.front(x, y) - 0.03)))
        ctx.add("Paper", tube(cord, 0.016, segs=5))
    for sx in (-1, 1):
        sl, pts = _sleeve(_sleeve_path(sx, hem + 0.1, fwd=0.08, out=0.03, bend=0.02), (0.1, 0.17), (0.075, 0.1), noise,
                          sx * 5.0 + 3.0, n=14, segs=10, bunch=0.35)
        ctx.add("Fabric", sl)
        d = (pts[-1] - pts[-2]).normalized()
        c0 = pts[-1] - d * 0.02
        ctx.add("Fabric", _sweep([c0, c0 + d * 0.14], _ellipse(0.068, 0.088, 10), ups=[Vector((0, 0, -1))] * 2))
    # the plastic hanger: hook, a flat bar along the shoulders
    from market import _hook, _shoulder_y
    _hook(ctx, "PlasticDark", -0.24)
    path = [(x, _shoulder_y(x) - 0.08, 0.0) for x in [lerp(-TIP[0] + 0.06, TIP[0] - 0.06, k / 10) for k in range(11)]]
    ctx.add("PlasticDark", _sweep(path, [(-0.03, -0.035), (0.03, -0.035), (0.03, 0.035), (-0.03, 0.035)], ups=Vector((0, 1, 0))))

    def cotton(p):
        k = 0.86 + 0.14 * noise.fbm(p.co * 7, 2)
        k *= 1 - 0.32 * smoothstep(0.0, 0.35, -p.convex)
        k *= 1 + 0.12 * smoothstep(0.6, 0.95, p.normal.y)
        k *= 1 - 0.15 * smoothstep(hem + 0.3, hem, p.co.y) * (abs(p.co.x) > 0.7)
        return k * 0.93

    ctx.wear("Fabric", cotton)
    ctx.wear("Metal", lambda p: 0.75)
    ctx.wear("Paper", lambda p: (0.85, 0.83, 0.78))
    ctx.wear("PlasticDark", mul(edge_wear(0.2), cavity(0.2)))


def pegboard_hook(ctx):
    """A face-out pegboard arm (the shop's wall pegs): a bent steel plate hooked into the board, a
    round rod sticking out 0.5 and tilted up, a ball end so hangers stay on. Origin: on the
    board's face, -Z out; a garment's hook origin goes at (0, -0.04, -0.36)."""
    ctx.budget = 600
    ctx.add("Chrome", _rbox(0.1, 0.26, 0.04, 0.015), T(0, 0.0, -0.02))
    rod = [(0, 0.0, -0.03), (0, 0.035, -0.25), (0, 0.07, -0.5)]
    ctx.add("Chrome", tube(rod, 0.024, segs=8))
    ctx.add("Chrome", sphere(0.04, 10, 6), T(0, 0.07, -0.5))
    ctx.wear("Chrome", lambda p: 0.75 + 0.2 * ctx.noise.n(p.co * 15))


# ==============================================================================================
# FOLDED TEES. Real reference: T-shirts folded shop-style (a board fold: sleeves folded behind,
# ~ 25 x 33 cm, 1.5-2 cm each) in stacks of 6-12 on a shelf or a table; the top one shows its
# neckline and the fold lines, the stack's sides show the layers (folded edges, not quite
# aligned), the lower ones flattened by the weight. Data: FoldedTee 2.2 x 1.15 x 1.2 + top
# (shelf), FoldedStack 1.6 x 0.95 x 1.25 + top (display table). Origin: the stack's bottom
# centre. Front = -Z (the folded edge toward the customer).
# ==============================================================================================
def _tee_stack(ctx, w, d, n, top_y):
    ctx.budget = 3200
    ctx.smooth_angle = 55
    ctx.tint("Fabric", (120, 118, 112))
    noise, rng = ctx.noise, ctx.rng
    y = FLOOR
    for k in range(n):
        last = k == n - 1
        th = (top_y - FLOOR) / n * rng.uniform(0.92, 1.08) * (1.0 - 0.15 * (1 - k / max(n - 1, 1)))
        th = min(th, top_y - y) if last else th
        ox, oz, yaw = rng.uniform(-0.04, 0.04), rng.uniform(-0.035, 0.035), rng.uniform(-2.5, 2.5)
        ww, dd = w * rng.uniform(0.96, 1.0), d * rng.uniform(0.96, 1.0)
        r = min(th * 0.48, 0.07)

        def puff(q, cy=y + th / 2, hh=th / 2, ww=ww, dd=dd):
            # the layer bulges a little in the middle, its front fold rounder than its back
            u = min(1.0, abs(q.x) / (ww / 2))
            v = min(1.0, abs(q.z) / (dd / 2))
            b = (1 - u * u) * (1 - v * v)
            if q.y > cy:
                q.y += hh * 0.35 * b
            return q

        st = [(y, ww - 2 * r, dd - 2 * r, 0.04, 0, 0), (y + r * 0.4, ww - r * 0.6, dd - r * 0.6, 0.06, 0, 0),
              (y + r, ww, dd, 0.08, 0, 0), (y + th - r, ww, dd, 0.08, 0, 0), (y + th - r * 0.4, ww - r * 0.6, dd - r * 0.6, 0.06, 0, 0),
              (y + th, ww - 2 * r, dd - 2 * r, 0.04, 0, 0)]
        bm = _rr_loft(st, "xz", k=3, m=2, warp=puff)
        ctx.add("Fabric", place(bm, T(ox, 0, oz) @ R(0, yaw, 0)))
        if last:  # the top tee: the neckline (a rib arc near the back), the folds' lines
            yt = y + th + th * 0.3
            arc = []
            for a in range(0, 181, 15):
                ar = math.radians(a)
                arc.append((ox + 0.28 * math.cos(ar), yt - 0.01, oz + dd / 2 - 0.12 - 0.18 * math.sin(ar)))
            ctx.add("Fabric", tube(arc, 0.03, segs=6))
            for sx in (-1, 1):
                ctx.add("Fabric", box(0.035, 0.025, dd * 0.86), T(ox + sx * ww * 0.31, yt - 0.02, oz) @ R(0, yaw, 0))
        y += th
    ctx.wear("Fabric", mul(lambda p: 0.88 + 0.12 * noise.fbm(p.co * 8, 2), cavity(0.35),
                           lambda p: 1 + 0.08 * smoothstep(0.6, 0.95, p.normal.y)))


def folded_tee_stack(ctx):
    """A shelf stack of nine folded tees (2.2 x 1.15, 1.4 high): layers not quite aligned, each
    bulging, the top one showing its neckline's rib and the folds' ridges."""
    _tee_stack(ctx, 2.1, 1.12, 9, 1.4)


def folded_tee_stack_short(ctx):
    """A shorter shelf stack: five tees (0.85 high), the rest sold."""
    _tee_stack(ctx, 2.1, 1.12, 5, 0.85)


def folded_tee_stack_low(ctx):
    """A display-table stack of eight smaller folds (1.6 x 1.2, 1.2 high)."""
    _tee_stack(ctx, 1.55, 1.18, 8, 1.2)


# ==============================================================================================
# SNEAKERS. Real reference: a pair of canvas low-tops (Converse / Vans type: 30 x 11 x 12 cm):
# a white vulcanised rubber sole with a toe cap and a thin coloured stripe round it, the canvas
# upper, the tongue, white laces through eyelets in a zigzag, the collar's opening, a heel
# patch; the high-top has the ankle panel up to 18 cm. Shop display: the pair side by side,
# one a little ahead, toes out. Data: Sneaker 1.2 x 0.6 x 0.5 on the shelf (one per 2.1).
# Origin: the pair's centre on the shelf; toes toward -Z.
# ==============================================================================================
def _sneaker(ctx, dye, x, z, yaw, high, mirror):
    L = 1.1
    m = T(x, 0, z) @ R(0, yaw, 0) @ (S(-1, 1, 1) if mirror else Matrix.Identity(4))

    def width(t):  # t: 0 heel .. 1 toe; half width
        return 0.15 + 0.06 * math.sin(math.pi * min(1.0, t * 1.15)) * 1.0 - 0.03 * smoothstep(0.85, 1.0, t)

    # sole: a plan outline extruded (toe and heel rounded)
    plan = []
    for k in range(14):
        a = TAU * k / 14
        t = 0.5 - 0.5 * math.cos(a)  # 0 heel .. 1 toe
        zz = lerp(L / 2, -L / 2, t)
        xx = width(t) * math.sin(a) * (1.0 if math.sin(a) > 0 else 0.9) + 0.02
        plan.append((xx, zz))
    sole = ext_y(plan[::-1], FLOOR, 0.13, 0.04, 0.025, k=2, kb=2)
    sb = place(sole, m)
    dye.add(sb, (1.0, 0.99, 0.95))
    ctx.add("Reflective", sb)
    stripe = place(ext_y(plan[::-1], 0.085, 0.105, 0.04, 0.004, k=2, kb=1), m @ S(1.012, 1, 1.008))
    ctx.add("Black", stripe)
    # upper: rings along the length (x-y sections), lower and narrower at the toe, the collar high
    rings = []
    n = 13
    for k in range(n):
        t = k / (n - 1)
        zz = lerp(L / 2 - 0.05, -L / 2 + 0.08, t)
        hw = width(t) - 0.025
        if high:
            h = lerp(0.62, 0.62, 0) if t < 0.35 else lerp(0.62, 0.2, smoothstep(0.35, 0.6, t))
            h = h if t > 0.02 else 0.58
        else:
            h = 0.28 if t < 0.12 else lerp(0.3, 0.2, smoothstep(0.3, 0.75, t))
        h = max(h - 0.12 * smoothstep(0.82, 1.0, t), 0.06)
        ring = []
        for a, b in _rr(2 * hw, h, min(hw * 0.95, h * 0.48), 3, 0):
            ring.append((0.02 + a, 0.12 + h / 2 + b, zz))
        rings.append(ring)
    up = place(loft(rings, cap_start=True, cap_end=True), m)
    ctx.add("Fabric", up)
    # the toe cap (rubber, over the front), the collar's opening (dark), tongue, laces
    toe = sphere(1.0, 12, 7)
    bmesh.ops.scale(toe, vec=(0.17, 0.09, 0.16), verts=toe.verts)
    tb = place(toe, m @ T(0.02, 0.14, -L / 2 + 0.17))
    dye.add(tb, (0.98, 0.97, 0.93))
    ctx.add("Reflective", tb)
    oz0, oz1 = (0.42, 0.12) if not high else (0.44, 0.2)
    oy = (0.12 + 0.3 + 0.005) if not high else (0.12 + 0.62 + 0.005)
    op = place(ext_y([(0.02 + 0.1 * math.cos(TAU * k / 12), lerp(oz0, oz1, 0.5) + (oz0 - oz1) / 2 * math.sin(TAU * k / 12)) for k in range(12)][::-1],
                     oy - 0.03, oy, 0.02, 0.006, k=1, kb=1), m)
    ctx.add("Black", op)
    tg = place(_rbox(0.2, 0.05, 0.36, 0.03), m @ T(0.02, oy - 0.01 if not high else 0.5, oz1 - 0.12) @ R(-30 if not high else -55, 0, 0))
    ctx.add("Fabric", tg)
    def upper_h(t):  # the upper's height at t (0 heel .. 1 toe), as in the rings above
        if high:
            h = 0.62 if t < 0.35 else lerp(0.62, 0.2, smoothstep(0.35, 0.6, t))
        else:
            h = 0.28 if t < 0.12 else lerp(0.3, 0.2, smoothstep(0.3, 0.75, t))
        return max(h - 0.12 * smoothstep(0.82, 1.0, t), 0.06)

    def top_at(zz, dx):  # the upper's surface height over the point (dx off the centre line, zz)
        t = (L / 2 - 0.05 - zz) / (L - 0.13)
        h = upper_h(t)
        hw = width(t) - 0.025
        rr = min(hw * 0.95, h * 0.48)
        inner = hw - rr
        drop = 0.0
        if abs(dx) > inner:
            drop = rr - math.sqrt(max(0.0, rr * rr - (abs(dx) - inner) ** 2))
        return 0.12 + h - drop

    nl = 5 if not high else 7
    z_lo = oz1 - 0.05 if not high else 0.28
    for k in range(nl):  # criss-cross laces lying on the instep, between two eyelet rows
        zz = lerp(z_lo, -0.2, k / (nl - 1))
        z2 = zz - (z_lo + 0.2) / (nl - 1) * 0.5
        pts = []
        for dx, zq in ((-0.075, zz), (0.0, (zz + z2) / 2), (0.075, z2)):
            pts.append((0.02 + dx, top_at(zq, dx) + 0.012, zq))
        lace = place(tube(pts, 0.013, segs=5), m)
        dye.add(lace, (0.95, 0.94, 0.9))
        ctx.add("Reflective", lace)
        for sx in (-1, 1):  # eyelets
            ey = place(_torus(0.022, 0.007, 6, 3), m @ T(0.02 + sx * 0.08, top_at(zz, sx * 0.08) + 0.004, zz))
            ctx.add("Black", ey)
    hp = place(box(0.12, 0.14, 0.02), m @ T(0.02, 0.24 if not high else 0.4, L / 2 - 0.04))
    ctx.add("Black", hp)


def _sneaker_pair(ctx, high):
    ctx.budget = 5000  # two shoes
    ctx.smooth_angle = 50
    ctx.tint("Fabric", (140, 60, 50))
    noise, rng = ctx.noise, ctx.rng
    dye = Dye()
    _sneaker(ctx, dye, 0.25, -0.04, rng.uniform(-3, 5), high, False)
    _sneaker(ctx, dye, -0.27, 0.06, rng.uniform(-8, -2), high, True)
    ctx.wear("Fabric", mul(cavity(0.3), lambda p: 0.88 + 0.12 * noise.fbm(p.co * 9, 2), ground_dirt(0.2, 0.15, noise)))
    ctx.wear("Reflective", dye.fn(mul(cavity(0.25), ground_dirt(0.1, 0.2, noise))))
    ctx.wear("Black", lambda p: 0.9)


def sneaker_pair(ctx):
    """A pair of canvas low-top sneakers (toes out, one a little ahead): white vulcanised sole
    with the toe cap and a black stripe, the canvas upper, tongue, white laces, the collar's
    opening, a heel patch; dust settled on the toe caps."""
    _sneaker_pair(ctx, False)


def sneaker_pair_high(ctx):
    """The same pair as high-tops (ankle panel to 0.62, more lace rows)."""
    _sneaker_pair(ctx, True)


# ==============================================================================================
# SHOP SHELVING. Real reference: a small boutique's wall unit in stained pine: a run of open
# shelves on uprights over a row of base cupboards (doors with knobs, a recessed plinth), a tall
# end cupboard, a tongue-and-groove back. Data (Interiors/Threadbare): ShelfCollider 20.8 x 9.3
# x 1.4 (y 1.9..11.2) on the back wall, ShelfEnd 2.8 wide at one end (here local x < -7.6),
# uprights at local x +10.25 / -7.45, boards at 2.38 / 4.98 / 7.57 and the top at 9.22 over
# the floor. Front = -Z (the overlay turns it into the shop).
# ==============================================================================================
def shop_shelf_wall(ctx):
    """Boutique wall shelving, 20.8 long: open stained-pine shelves on three uprights over base
    cupboards (six doors with brass knobs, a recessed plinth), a tall end cupboard with a
    panelled door, a tongue-and-groove back; rubbed shelf edges, kicked plinth and doors, dust."""
    ctx.budget = 8000
    ctx.smooth_angle = 35
    noise, rng = ctx.noise, ctx.rng
    ZF_, ZB_ = -0.69, 0.68
    X0, X1 = -7.6, 10.4  # the open run (the end cupboard from -10.4 to -7.6)
    # plinth and base cupboards (0..2.3)
    ctx.add("WoodDark", box(X1 - X0 - 0.1, 0.3, 1.2, bevel=0.02), T((X0 + X1) / 2, FLOOR + 0.15, 0.05))
    ctx.add("Wood", rbox(X1 - X0, 2.0, 1.38, r=0.03, m=1, n=(6, 1, 1)), T((X0 + X1) / 2, 1.3, 0.0))
    nd = 6
    dw = (X1 - X0 - 0.2) / nd
    for k in range(nd):
        cx = X0 + 0.1 + dw * (k + 0.5)
        ctx.add("Wood", rbox(dw - 0.08, 1.7, 0.05, r=0.015, m=1, n=(1, 1, 1)), T(cx, 1.3, ZF_ - 0.02))
        ctx.add("WoodDark", box(dw - 0.5, 1.2, 0.03, bevel=0.01), T(cx, 1.3, ZF_ - 0.045))
        kx = cx + (dw / 2 - 0.25) * (1 if k % 2 == 0 else -1)
        ctx.add("MetalPainted", sphere(0.06, 10, 6), T(kx, 1.6, ZF_ - 0.1))
        ctx.add("MetalPainted", cyl(0.025, 0.06, 6), T(kx, 1.6, ZF_ - 0.06) @ R(90, 0, 0))
    ctx.tint("MetalPainted", (150, 118, 62))
    # uprights, boards, top
    for x in (X0 + 0.15, 1.45, X1 - 0.15):
        ctx.add("Wood", rbox(0.3, 9.3 - 2.3, 1.36, r=0.025, m=2, n=(1, 3, 1)), T(x, 2.3 + (9.3 - 2.3) / 2, 0.0))
    for y in (2.38, 4.98, 7.57, 9.22):
        ctx.add("Wood", rbox(X1 - X0, 0.15, 1.36, r=0.025, m=2, n=(5, 1, 1)), T((X0 + X1) / 2, y, 0.0))
    # tongue-and-groove back
    nb = int((X1 - X0) / 0.6)
    pw = (X1 - X0) / nb
    for k in range(nb):
        ctx.add("WoodDark", box(pw - 0.02, 9.3 - 2.3, 0.05, bevel=0.012, segments=1), T(X0 + pw * (k + 0.5), 2.3 + 3.5, ZB_ - 0.03))
    ctx.add("WoodDark", box(X1 - X0, 9.3 - 2.3, 0.02), T((X0 + X1) / 2, 2.3 + 3.5, ZB_ - 0.002))  # the board behind the joints
    # the end cupboard: carcass, a panelled door, a knob
    ex = (-10.4 - 7.6) / 2
    ctx.add("Wood", rbox(2.8, 9.3 - FLOOR - 0.3, 1.38, r=0.03, m=1, n=(1, 4, 1)), T(ex, 0.3 + (9.3 - 0.3) / 2, 0.0))
    ctx.add("WoodDark", box(2.7, 0.3, 1.2, bevel=0.02), T(ex, FLOOR + 0.15, 0.05))
    ctx.add("Wood", rbox(2.5, 8.6, 0.05, r=0.015, m=1, n=(1, 3, 1)), T(ex, 4.75, ZF_ - 0.02))
    for cy, hh in ((2.6, 3.4), (7.0, 3.4)):
        ctx.add("WoodDark", box(1.9, hh, 0.03, bevel=0.01), T(ex, cy, ZF_ - 0.045))
    ctx.add("MetalPainted", sphere(0.07, 10, 6), T(ex + 1.0, 4.8, ZF_ - 0.1))

    def rub(p):  # shelf fronts rubbed pale where hands take the stock
        return smoothstep(-0.55, -0.68, p.co.z) * (1 - smoothstep(0.0, 0.1, abs(math.fmod(p.co.y + 10, 2.6) - 0.2)))

    ctx.wear("Wood", mul(wood_wear(noise, 0.8, 0.25, rub=None), shoe_scuffs(noise, 0.9, 0.35), dust_top(noise, 0.1)))
    ctx.wear("WoodDark", mul(wood_wear(noise, 0.4, 0.3), shoe_scuffs(noise, 0.4, 0.4)))
    ctx.wear("MetalPainted", mul(cavity(0.3), lambda p: 0.8 + 0.2 * noise.n(p.co * 12)))
    _ = (rng, rub)


# ==============================================================================================
# DISPLAY TABLE. Real reference: a boutique's reclaimed-pine display table (~ 180 x 90 x 76 cm):
# a top of five planks with open joints and nail heads, an apron, square legs, a lower shelf on
# stretchers; old wax finish, dents, saw marks, the legs' feet black from mopping. Data:
# DisplayTable 6 x 3 x 3 (collider, y 1.9..4.9). Origin: floor centre. Front = -Z.
# ==============================================================================================
def display_table_wood(ctx):
    """Reclaimed-pine display table (6 x 3, top at 3.0): five top planks with open joints, cupped
    a little, nail heads, an apron, square legs on stretchers, a lower slatted shelf; dents and
    darker grime in the joints, the leg feet black, rubbed pale on the top's edges."""
    ctx.budget = 6000
    ctx.smooth_angle = 35
    noise, rng = ctx.noise, ctx.rng
    W, D, H = 6.0, 3.0, 3.0
    npl = 5
    pw = D / npl
    for k in range(npl):
        z = -D / 2 + pw * (k + 0.5)
        th = 0.16 + rng.uniform(-0.01, 0.01)
        bm = rbox(W - rng.uniform(0.0, 0.06), th, pw - 0.03, r=0.03, m=2, n=(5, 1, 2))

        def cup(q, z=z):  # cupped planks: the edges a hair higher
            q.y += 0.012 * ((q.z - z) / (pw / 2)) ** 2 if q.y > 0 else 0.0
            return q

        for v in bm.verts:
            v.co = cup(v.co + Vector((0, 0, z))) - Vector((0, 0, z))
        ctx.add("Wood", place(bm, T(rng.uniform(-0.03, 0.03), H - th / 2, z)))
        for sx in (-1, 1):
            for dz in (-0.12, 0.12):
                ctx.add("Metal", cyl(0.025, 0.01, 6), T(sx * (W / 2 - 0.5), H + 0.004, z + dz))
    ctx.add("WoodDark", box(W - 0.5, 0.4, D - 0.5, bevel=0.02), T(0, H - 0.16 - 0.2, 0))  # apron
    for sx in (-1, 1):
        for sz in (-1, 1):
            ctx.add("Wood", rbox(0.26, H - 0.17 - FLOOR, 0.26, r=0.025, m=1, n=(1, 3, 1)), T(sx * (W / 2 - 0.3), FLOOR + (H - 0.17 - FLOOR) / 2, sz * (D / 2 - 0.3)))
    # stretchers and the lower shelf's slats
    for sz in (-1, 1):
        ctx.add("WoodDark", box(W - 0.6, 0.16, 0.12, bevel=0.015), T(0, 0.55, sz * (D / 2 - 0.3)))
    for sx in (-1, 1):
        ctx.add("WoodDark", box(0.12, 0.16, D - 0.6, bevel=0.015), T(sx * (W / 2 - 0.3), 0.55, 0))
    for k in range(6):
        z = lerp(-D / 2 + 0.55, D / 2 - 0.55, k / 5)
        ctx.add("Wood", rbox(W - 0.7, 0.07, 0.28, r=0.015, m=1, n=(3, 1, 1)), T(0, 0.665, z))

    def rub(p):
        return smoothstep(H - 0.2, H, p.co.y) * smoothstep(0.1, 0.6, p.convex)

    ctx.wear("Wood", mul(wood_wear(noise, 0.5, 0.45, grain=0.1, rub=rub), scuffs(noise, 0.15, 3.0), dust_top(noise, 0.05)))
    ctx.wear("WoodDark", mul(wood_wear(noise, 0.5, 0.3), cavity(0.2)))
    ctx.wear("Metal", lambda p: 0.6)


# ==============================================================================================
# FITTING ROOM CURTAIN. Real reference: a heavy velvet fitting-room curtain on rings round a
# rail: deep regular pleats at the top where the rings gather it, the folds opening and
# swinging toward the hem, the hem 10 cm off the floor, dirtier there; the pulled-aside one
# bunched toward one end. Data: Curtain 0.1 x 8 x 5.2 and 0.1 x 8 x 4 (hem 0.3 over the floor),
# CurtainRail at y 10.3 (kept). Origin: on the rail's axis at the curtain's middle; the curtain
# spans X, hangs down.
# ==============================================================================================
def _curtain(ctx, width, bunched):
    ctx.budget = 4800
    ctx.smooth_angle = 60
    ctx.tint("Fabric", (110, 40, 40))
    noise, rng = ctx.noise, ctx.rng
    top, hem = -0.3, -8.1
    cols, rows = 46, 12
    lam = 0.42 if not bunched else 0.3
    tops, bots = [], []
    for i in range(rows):
        v = i / (rows - 1)
        y = lerp(top, hem, v ** 0.9)
        rt, rb = [], []
        for j in range(cols):
            u = j / (cols - 1)
            if bunched:  # the pleats crowd toward +X (pulled aside)
                u = 1 - (1 - u) ** 1.35
            x = lerp(-width / 2, width / 2, u)
            amp = lerp(0.09, 0.15, v) * (1.3 if bunched else 1.0)
            ph = 0.5 * noise.n((x * 0.7, y * 0.25, 1.0)) * v
            z = amp * math.sin(TAU * x / lam + ph) + 0.06 * noise.fbm((x * 0.4, y * 0.15, 3.0), 2) * v
            yy = y + (0.06 * math.sin(TAU * x / lam * 0.5 + 1.0) * v ** 3 if not bunched else 0.1 * v ** 3 * u)
            rt.append(Vector((x, yy, z - 0.018)))
            rb.append(Vector((x, yy, z + 0.018)))
        tops.append(rt)
        bots.append(rb)
    ctx.add("Fabric", _grid_slab(tops, bots))
    # rings round the rail at each pleat's crest, their hooks down to the heading
    nr = int(width / lam)
    for k in range(nr + 1):
        x = -width / 2 + width * k / nr
        if bunched:
            x = lerp(-width / 2, width / 2, 1 - (1 - k / nr) ** 1.35)
        ctx.add("Metal", _torus(0.19, 0.022, 14, 5), T(x, 0, 0) @ R(0, 0, 90))
        ctx.add("Metal", tube([(x, -0.2, 0.0), (x, -0.26, 0.0), (x, -0.36, 0.0)], 0.012, segs=4))

    def velvet(p):
        k = 0.82 + 0.18 * smoothstep(0.0, 0.5, p.convex)  # the crests catch the light (pile)
        k *= 1 - 0.35 * smoothstep(0.0, 0.4, -p.convex)
        k *= 1 - 0.25 * smoothstep(hem + 1.2, hem, p.co.y) * (0.6 + 0.4 * noise.fbm(p.co * 2, 2))
        k *= 1 + 0.1 * smoothstep(-2.0, top, p.co.y) * 0.5  # sun-faded heading
        return k

    ctx.wear("Fabric", velvet)
    ctx.wear("Metal", mul(cavity(0.3), lambda p: 0.7))
    _ = rng


def curtain_drawn(ctx):
    """A heavy velvet fitting-room curtain drawn closed (5.2 wide): deep regular pleats gathered
    by brass rings round the rail, opening and swinging toward the hem, pile catching the light
    on the crests, the hem grimy, the heading sun-faded."""
    _curtain(ctx, 5.2, False)


def curtain_drawn_b(ctx):
    """The second curtain (4.0 wide), pulled aside: its pleats bunched toward one end, the hem
    lifting there."""
    _curtain(ctx, 4.0, True)


# ==============================================================================================
# FLOOR MIRROR. Real reference: a tall leaning floor mirror (~ 60 x 170 cm) in a moulded gilt
# frame (ogee profile, gilt rubbed to the dark gesso on the high points, mitred corners), its
# glass desilvering in dark patches round the edges, a hardboard back, felt pads under it,
# leaning ~ 5 degrees against the wall. Data: MirrorFrame 3.4 x 7.4 on the fitting-room wall.
# Origin: on the floor at the wall's face, -Z out of the wall; the mirror leans back on it.
# ==============================================================================================
def _member(L, prof, along):
    """One mitred frame member: the profile [(u, v)] (u from the outer edge inward, v out of
    the wall) along a length L (outer); returns a closed bmesh along X centred on the origin,
    u along -Y (the outer edge at y = 0)."""
    rings = []
    for side in (-1, 1):
        rings.append([(side * (L / 2 - u), -u, -v) for u, v in prof])
    bm = loft(rings, cap_start=True, cap_end=True)
    return bm


def standing_mirror(ctx):
    """Tall leaning floor mirror (3.4 x 7.4): moulded gilt frame with mitred corners (gilt rubbed
    to the dark ground on its ridges), the glass desilvering round the edges, a hardboard back,
    felt pads; it leans 5 degrees against the wall."""
    ctx.budget = 3600
    ctx.smooth_angle = 30
    ctx.tint("MetalPainted", (150, 120, 64))
    noise, rng = ctx.noise, ctx.rng
    W, H = 3.4, 7.4
    lean = math.degrees(math.asin(0.62 / H))
    base = T(0, 0.0, -0.7) @ R(lean, 0, 0)  # the bottom edge 0.7 out from the wall, the top back on it
    prof = [(0.0, 0.0), (0.0, 0.08), (0.04, 0.12), (0.1, 0.15), (0.16, 0.13), (0.2, 0.09), (0.26, 0.1), (0.3, 0.06), (0.3, 0.0)]
    prof = prof[::-1]
    for (cx, cy, rot, L) in ((0, H, 0, W), (0, 0, 180, W), (W / 2, H / 2, -90, H), (-W / 2, H / 2, 90, H)):
        ctx.add("MetalPainted", place(_member(L, prof, "x"), base @ T(cx, cy + FLOOR, 0.0) @ R(0, 0, rot)))
    # the glass on a grid (vertex colours for the desilvering), the back board, felt pads
    gw, gh = W - 0.5, H - 0.5
    nx, ny = 9, 20
    tops, bots = [], []
    for i in range(ny):
        rt, rb = [], []
        for j in range(nx):
            x = lerp(-gw / 2, gw / 2, j / (nx - 1))
            y = lerp(0.25, H - 0.25, i / (ny - 1)) + FLOOR
            rt.append(Vector((x, y, -0.04)))
            rb.append(Vector((x, y, -0.015)))
        tops.append(rt)
        bots.append(rb)
    ctx.add("Chrome", place(_grid_slab(tops, bots), base))
    ctx.add("WoodDark", place(box(W - 0.1, H - 0.1, 0.03), base @ T(0, H / 2 + FLOOR, 0.0)))
    for sx in (-1, 1):
        ctx.add("FabricDark", place(box(0.3, 0.03, 0.12), base @ T(sx * 1.2, 0.0, -0.06)))

    def desilver(p):
        q = base.inverted() @ p.co
        e = min(abs(q.x) - gw / 2, abs(q.y - FLOOR - H / 2) - gh / 2)  # (negative inside: distance to the edge)
        t = smoothstep(-0.5, 0.0, e) * smoothstep(0.45, 0.7, noise.fbm(q * 2.5, 3) * 0.5 + 0.5)
        return (1 - 0.55 * t) * (0.92 + 0.08 * noise.n(q * 8))

    def gilt(p):
        c = 0.85 + 0.15 * noise.fbm(p.co * 6, 2)
        c *= 1 - 0.45 * smoothstep(0.1, 0.5, p.convex) * smoothstep(0.4, 0.7, noise.fbm(p.co * 9, 2) * 0.5 + 0.5)
        c *= 1 - 0.3 * smoothstep(0.0, 0.4, -p.convex)
        return (c, c * 0.97, c * 0.9)

    ctx.wear("Chrome", desilver)
    ctx.wear("MetalPainted", gilt)
    ctx.wear("WoodDark", lambda p: 0.7)
    ctx.wear("FabricDark", lambda p: 0.8)
    _ = rng

PIECES = {
    "RecordBinCrate": record_bin_crate,
    "RecordBinCrateB": record_bin_crate_b,
    "VhsStack": vhs_stack,
    "Turntable": turntable,
    "CashRegisterOld": cash_register_old,
    "CashRegisterModern": cash_register_modern,
    "CrtTvPortable": crt_tv_portable,
    "CrtTvPortableB": crt_tv_portable_b,
    "VhsShelfStocked": vhs_shelf_stocked,
    "PaSpeakerFloor": pa_speaker_floor,
    "PaSpeakerFloorWorn": pa_speaker_floor_worn,
    "MicStand": mic_stand,
    "ArcadeCabinet": arcade_cabinet,
    "MirrorBall": mirror_ball,
    "MannequinDisplay": mannequin_display,
    "MannequinDisplayB": mannequin_display_b,
    "MannequinTop": mannequin_top,
    "MannequinTopB": mannequin_top_b,
    "MannequinLegs": mannequin_legs,
    "MannequinLegsB": mannequin_legs_b,
    "ShirtOnHanger": shirt_on_hanger,
    "HoodieOnHanger": hoodie_on_hanger,
    "PegboardHook": pegboard_hook,
    "FoldedTeeStack": folded_tee_stack,
    "FoldedTeeStackShort": folded_tee_stack_short,
    "FoldedTeeStackLow": folded_tee_stack_low,
    "SneakerPair": sneaker_pair,
    "SneakerPairHigh": sneaker_pair_high,
    "ShopShelfWall": shop_shelf_wall,
    "DisplayTableWood": display_table_wood,
    "CurtainDrawn": curtain_drawn,
    "CurtainDrawnB": curtain_drawn_b,
    "StandingMirror": standing_mirror,
}
