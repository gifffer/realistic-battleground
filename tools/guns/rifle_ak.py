#!/usr/bin/env python3
"""The 7.62 RIFLE: an AK-pattern 7.62x39 select-fire rifle with wood furniture (original generic design in the
class of the reference photo: milled receiver with its long lightening cut, flush axis pins, smooth dust cover; no logos, no
copied markings; only a generic 'RB-04127' / '7.62x39' stamp engraved on the left receiver flat).

Builds the model from code (tools/guns/gunkit.py), follows the Model contract (docs/firearms/ARCHITECTURE.md
§5), bakes two 1024 atlases (steel + magazine, and the wood furniture) for Roblox SurfaceAppearances, exports
the FBXs and the markers JSON to assets/guns/Rifle/, solves the R6 holds (rifle_ak_holds.json next to this
script) and renders the review set.

Real-world class dimensions (AK-47 / AKM, fixed wood stock): overall length 880 mm, barrel 415 mm, height
255 mm with the 30-round magazine, receiver width 39 mm, sight radius 360 mm, 3.9 kg loaded.
The side profile was measured on the reference photo, levelled (rotated 44 deg) and scaled to the 880 mm
overall length (0.4536 mm / px): every coordinate below is in millimetres in model space (+X muzzle, +Y the
gun's left, +Z up; origin on the bore at the breech face).

Moving parts (ARCHITECTURE §5.2): BoltCarrier (+ child ChargingHandle) slides -X 120 mm; Selector (right
lever) rotates about +Y at its rear, SAFE 0 / AUTO +10 / SEMI +20 (exported on SEMI); MagRelease paddle -12
deg; Magazine rocks -25 deg about MagRockPivot (front lug) then comes free; Trigger +14 deg; SightRear (the
leaf) rises +8 deg about its front hinge.

Usage:
  /home/user/z-anatomy/venv/bin/python -I tools/guns/rifle_ak.py --out DIR [--assets assets/guns/Rifle]
      [--samples 40] [--only 01,02] [--quick] [--no-bake] [--no-holds] [--no-render] [--no-export] [--ref photo.png]
"""
import argparse
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import gunkit as gk  # noqa: E402
from gunkit import V  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
GID = 'Rifle'
REF_DEFAULT = '/tmp/claude-0/-home-user-realistic-battleground/e6e0272e-0bb1-5036-b293-d501c4bfb630/scratchpad/guns/refs/rifle_ak.png'
REF_ANGLE = 44.0                   # degrees that level the reference photo (bore horizontal)


def mm(*a):
    """mm -> metres (a number, a point or a list of 2D points)."""
    if len(a) == 1 and isinstance(a[0], (int, float)):
        return a[0] * 0.001
    if len(a) == 1:
        return [(p[0] * 0.001, p[1] * 0.001) for p in a[0]]
    return tuple(c * 0.001 for c in a)


def interp(table, x):
    """Linear interpolation in a [(x, v), ...] table (any order of x)."""
    t = sorted(table)
    if x <= t[0][0]:
        return t[0][1]
    for (xa, va), (xb, vb) in zip(t[:-1], t[1:]):
        if xa <= x <= xb:
            return va + (vb - va) * (x - xa) / max(1e-9, xb - xa)
    return t[-1][1]


# --------------------------------------------------------------------------------------
# layout (mm, model space; measured on the levelled reference)
# --------------------------------------------------------------------------------------
MUZZLE_X = 418.0                  # front of the muzzle nut
BARREL_L = 415.0                  # breech face -> crown
REC_X = (48.0, -213.0)            # receiver front (trunnion) / rear
REC_HW = 19.5                     # receiver half width (39 mm)
REC_TOP, REC_BOT = 24.0, -27.0
COVER_Z = 23.5                    # dust cover bottom edge
STROKE = 120.0                    # bolt carrier travel
REAR_NOTCH = (27.0, 49.7)         # rear sight notch bottom (x, z)
LEAF_TOP = 51.3                   # the leaf's top edge = the notch shoulders (the sight line passes here)
FRONT_POST = (388.0, 49.3)        # front post tip: the sight line (leaf top -> post tip) slopes 0.3 deg down to the rising bullet path (battle-sight zero)
GAS_Z = 24.0                      # gas tube axis height
# magazine: top centre of the seated mag (feed lips), spine leaves at 8.3 deg forward and bends 41 deg forward
MAGWELL = (-38.0, -8.0)
MAG_A0 = math.radians(8.3)
MAG_AX = (math.sin(MAG_A0), -math.cos(MAG_A0))
MAG_FR = (math.cos(MAG_A0), math.sin(MAG_A0))
MAG_CURVE = 41.0
MAG_LEN, MAG_BODY = 203.0, 197.0
MAG_DEPTH, MAG_W = 59.0, 27.0
MAG_ROCK = (-4.0, -10.0)           # front lug pivot
SEL_PIVOT = (-153.0, -REC_HW, 3.0)
TRIG_PIVOT = (-91.0, 0.0, -12.0)
REL_PIVOT = (-73.0, 0.0, -22.0)
LEAF_PIVOT = (88.0, 0.0, 46.0)


# --------------------------------------------------------------------------------------
# rifle-only materials (the kit's library is left untouched for the other guns)
# --------------------------------------------------------------------------------------
# handled zones (model metres, centre + radius): the wrist and the grip where the right hand sits, the lower
# handguard belly under the support hand; the oil and skin darken them and wear the finish to a dull sheen
HANDLED = [((-0.235, 0.0, -0.010), 0.045), ((-0.185, 0.0, -0.085), 0.050), ((0.120, 0.0, -0.030), 0.065)]


def mat_wood_ak(name, light=(0.150, 0.042, 0.019), dark=(0.046, 0.013, 0.006), grain_deg=0.0, coat=0.1, rough=0.45):
    """Shellacked birch / walnut AK furniture: growth rings along the part's own long axis (`grain_deg`: the
    grain direction's angle in the model XZ plane, + = front end up), strong ring contrast and figure,
    open pores, darker oily handled zones (HANDLED), lighter dented edges, a thin worn coat."""
    m = gk.NB(name)
    vr = m.n('ShaderNodeVectorRotate', rotation_type='Y_AXIS', invert=False)
    m.l(m.obj(), vr.inputs['Vector'])
    vr.inputs['Angle'].default_value = math.radians(grain_deg)
    v = vr.outputs['Vector']
    s = (10, 240, 300)
    # long straight growth lines (low distortion: flat-sawn birch/walnut, not flame figure), a finer second
    # set of lines, a broad soft figure, open pores
    g = m.noise(1.6, 6, 0.62, vec=m.scaled(s, v), distort=0.6)
    fig = m.noise(0.9, 3, 0.5, vec=m.scaled((3, 30, 30), v))
    rings = m.mask(m.wave(1.0, vec=m.scaled((3.0, 110.0, 130.0), v), kind='RINGS', direction='X',
                          distortion=5.0, detail=4.0), 0.62, 0.97)
    fine = m.mask(m.wave(1.0, vec=m.scaled((5.0, 380.0, 420.0), v), kind='RINGS', direction='X',
                         distortion=6.0, detail=3.0), 0.60, 0.95)
    base = m.mixc(m.mul(m.mask(g, 0.30, 0.70), 0.55), gk.C(*light), gk.C(*dark))
    base = m.mixc(m.mul(m.mask(fig, 0.35, 0.75), 0.45), base, gk.C(light[0] * 1.25, light[1] * 1.15, light[2] * 1.1))
    rings = m.mul(rings, m.mask(m.noise(2.5, 3, 0.5, vec=m.scaled((2, 40, 40), v)), 0.3, 0.7))   # uneven ring contrast
    base = m.mixc(m.mul(rings, 0.6), base, gk.C(dark[0] * 0.8, dark[1] * 0.7, dark[2] * 0.7))
    base = m.mixc(m.mul(fine, 0.14), base, gk.C(dark[0] * 0.9, dark[1] * 0.8, dark[2] * 0.75))
    pores = m.mask(m.noise(2, 2, 0.5, vec=m.scaled(tuple(k * 25 for k in s), v)), 0.64, 0.72)
    base = m.mixc(m.mul(pores, 0.7), base, gk.C(0.018, 0.007, 0.003))
    hand = None
    for c, r in HANDLED:
        d = m.n('ShaderNodeVectorMath', operation='DISTANCE')
        m.l(m.obj(), d.inputs[0])
        d.inputs[1].default_value = c
        h = m.math('SUBTRACT', 1.0, m.mask(d.outputs['Value'], r * 0.35, r))
        hand = h if hand is None else m.mx(hand, h)
    hand = m.mul(hand, m.mask(m.noise(14, 4, 0.6), 0.25, 0.65))
    blotch = m.mask(m.noise(9, 5, 0.6), 0.58, 0.85)
    base = m.mixc(m.mul(m.mx(hand, m.mul(blotch, 0.6)), 0.75), base,
                  gk.C(dark[0] * 0.55, dark[1] * 0.45, dark[2] * 0.4))
    e = m.edge(0.0012, 0.03, 0.2)
    dent = m.mul(e, m.mask(m.noise(70, 6, 0.6), 0.42, 0.58))
    base = m.mixc(m.mul(dent, 0.8), base, gk.C(light[0] * 1.9, light[1] * 1.8, light[2] * 1.6))
    dings = m.mask(m.voronoi(160, out='Distance'), 0.0, 0.05)
    dings = m.mul(dings, m.mask(m.noise(6, 3, 0.5), 0.55, 0.7))
    base = m.mixc(m.mul(dings, 0.6), base, gk.C(dark[0] * 0.5, dark[1] * 0.4, dark[2] * 0.35))
    rr = m.mixf(m.mul(hand, 0.8), rough, rough * 0.62)
    rr = m.mixf(m.mul(dent, 0.9), rr, 0.78)
    rr = m.mixf(m.mul(pores, 0.5), rr, 0.8)
    m.bsdf(base, 0.0, rr, m.bump(m.add(m.mul(rings, 0.35), m.mul(pores, -0.7), m.mul(dent, -0.6),
                                       m.mul(dings, -0.8)), 0.18, 0.0004),
           extra={'Coat Weight': coat, 'Coat Roughness': 0.3})
    return m.m


def mat_steel_ak(name, col=(0.050, 0.055, 0.066), rough=0.32, metal=0.88, edge_wear=1.0, flat_wear=0.6,
                 worn=(0.46, 0.46, 0.47)):
    """Old hot-blued milled steel as the photo: blue-black oxide, oily (low, patchy roughness), bluing thinned
    to grey on the flats in broad soft patches (`flat_wear`), bright silver on the edges and high spots
    (`edge_wear`, a wide bevel-normal mask), lengthwise fine scratches, dark oily grime in the recesses."""
    m = gk.NB(name)
    e = m.mx(m.edge(0.0030, 0.006, 0.06), m.mul(m.edge(0.0010, 0.02, 0.15), 0.8))
    cav = m.cavity(0.005)
    big = m.noise(9, 5, 0.62)
    var = m.noise(35, 5, 0.6)
    base = m.mixc(var, gk.C(*col), gk.C(col[0] * 1.25, col[1] * 1.28, col[2] * 1.35))
    # thinned bluing: broad grey patches on the flats, more toward the high spots (not in the recesses)
    thin = m.mul(m.mask(big, 0.36, 0.70), flat_wear)
    thin = m.mul(thin, m.math('SUBTRACT', 1.0, cav))
    grey = gk.C(col[0] * 3.4, col[1] * 3.3, col[2] * 3.0)
    base = m.mixc(thin, base, grey)
    # edge wear to bare steel, broken by a fine noise so it chips rather than outlines
    chip = m.mask(m.noise(120, 6, 0.65), 0.22, 0.46)
    wearm = m.mul(m.mul(e, chip), edge_wear)
    scr = m.mul(m.mask(m.noise(3, 3, 0.5, vec=m.scaled((30, 1400, 1400))), 0.66, 0.70),
                m.mask(m.noise(7, 3, 0.5), 0.40, 0.6))
    wearm = m.mx(wearm, m.mul(scr, 0.7))
    grime = m.mx(m.mul(cav, 0.95), m.mul(m.mask(m.noise(20, 6, 0.6), 0.66, 0.88), 0.6))
    base = m.mixc(m.mul(grime, 0.7), base, gk.C(0.016, 0.014, 0.011))
    base = m.mixc(wearm, base, gk.C(*worn))
    oil = m.mask(m.noise(14, 4, 0.6), 0.35, 0.75)
    rr = m.mixf(oil, rough * 0.7, rough * 1.35)
    rr = m.mixf(thin, rr, min(0.6, rough * 1.5))
    rr = m.mixf(m.mul(grime, 0.7), rr, 0.65)
    rr = m.mixf(wearm, rr, 0.24)
    mt = m.mixf(wearm, m.mixf(thin, metal, metal * 0.62), 1.0)
    nrm = m.bump(m.add(m.mul(m.noise(3000, 2, 0.5), 0.6), m.mul(wearm, -0.5), m.mul(scr, -0.5),
                       m.mul(m.mask(m.noise(60, 4, 0.5), 0.5, 0.8), 0.25)), 0.10, 0.0003)
    m.bsdf(base, mt, rr, nrm)
    return m.m


def studio_world():
    """The kit's near-black studio as seen by the camera, but a soft overhead studio in reflections (top bright,
    floor dark): polished steel only reads as steel when it has something to reflect (as in-game, where it
    reflects the sky)."""
    w = bpy.context.scene.world
    nt = w.node_tree
    bg = nt.nodes.get('Background')
    lp = nt.nodes.new('ShaderNodeLightPath')
    tc = nt.nodes.new('ShaderNodeTexCoord')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(tc.outputs['Generated'], sep.inputs[0])
    mr = nt.nodes.new('ShaderNodeMapRange')
    mr.inputs['From Min'].default_value = -0.7
    mr.inputs['From Max'].default_value = 0.9
    nt.links.new(sep.outputs[2], mr.inputs['Value'])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (0.010, 0.010, 0.011, 1)
    ramp.color_ramp.elements[1].color = (0.42, 0.42, 0.43, 1)
    nt.links.new(mr.outputs[0], ramp.inputs['Fac'])
    mix = nt.nodes.new('ShaderNodeMix')
    mix.data_type = 'RGBA'
    nt.links.new(lp.outputs['Is Camera Ray'], mix.inputs[0])
    nt.links.new(ramp.outputs['Color'], mix.inputs[6])
    mix.inputs[7].default_value = (0.004, 0.004, 0.0045, 1)
    nt.links.new(mix.outputs[2], bg.inputs['Color'])


def build_rifle_materials():
    """The rifle's finishes: oily grey-blue milled/hot-blued steel with silver edge wear (no holster bands, no
    brushing streaks), a darker, rougher magazine, and the reddish shellacked furniture with the grain along
    each part's axis (handguards along X, stock along its comb, grip along its rake)."""
    mat_steel_ak('SteelBlued')
    mat_steel_ak('SteelMag', col=(0.032, 0.034, 0.039), rough=0.46, metal=0.82, edge_wear=0.9, flat_wear=0.25,
                 worn=(0.26, 0.26, 0.27))
    mat_wood_ak('Wood', grain_deg=0.0)
    mat_wood_ak('WoodStock', grain_deg=STOCK_GRAIN_DEG)
    mat_wood_ak('WoodGrip', light=(0.17, 0.038, 0.016), grain_deg=GRIP_GRAIN_DEG)


# --------------------------------------------------------------------------------------
# receiver (milled steel) + dust cover
# --------------------------------------------------------------------------------------

def build_receiver(gun):
    rc = gun.part('Receiver', paint='SteelBlued', fit=1)
    St, Bo, Ba = rc.mi('SteelBlued'), rc.mi('Bore'), rc.mi('SteelBare')
    bm = rc.bm
    # side outline: body, grip tang under the rear, rear block where the stock tang begins
    A = [(48, 24), (48, -24), (45, -27), (-146, -27), (-149, -33), (-199, -33), (-203, -28), (-213, -24),
         (-213, 22), (-210, 24)]
    gk.profile(bm, mm(gk.fillet2(A, 1.2, 1, radii=[0, 1.5, 2, 1.5, 2, 2, 2, 2, 1.5, 1])), mm(2 * REC_HW),
               bevel=mm(1.2), bevel_segs=1, mi=St)
    # front trunnion collar / lower handguard retainer
    sec = gk.rrect2(-2.0, 0.0, 22.5, 22.0, r_pos=5.0, r_neg=9.0, n=2)
    gk.section_x(bm, mm([(y, z) for z, y in sec]), mm(42.0), mm(55.0), end_bevel=mm(1.0), mi=St)
    # retainer lever (right side)
    gk.rbox(bm, mm(49.0, -22.6, -6.0), mm(7.0, 2.4, 22.0), mm(0.8), 1, mi=St)
    # (no rear block: the wood wrist is inletted straight onto the receiver's rear face, as the milled AK-47;
    #  the steel upper / lower tangs are thin straps on the wrist, built with the stock)
    # trigger guard (stamped loop, 10 wide)
    outer = [(-87, -26), (-88, -50), (-93, -58.5), (-140, -58.5), (-147, -52), (-151, -30), (-151, -26)]
    hole = [(-92, -28.5), (-93, -49), (-97, -54.5), (-137, -54.5), (-142, -49.5), (-146, -31), (-146, -28.5)]
    gk.profile(bm, mm(gk.fillet2(outer, 2.0, 1, radii=[0, 3, 4, 4, 5, 2, 0])), mm(10.0),
               holes=[mm(gk.fillet2(hole, 2.0, 1))], bevel=mm(1.0), bevel_segs=0, mi=St)
    cuts = []
    # lightening cuts (both sides) above the magazine, as on the milled receiver of the photo
    lc = gk.fillet2([(40, -3), (-60, -3), (-60, -18), (40, -18)], 3.0, 2)
    for y0, y1 in ((REC_HW - 1.6, REC_HW + 5), (-REC_HW - 5, -REC_HW + 1.6)):
        cuts.append(gk.prism_cutter(mm(lc), mm(y0), mm(y1), mi=St))
    # ejection port (right side), open to the dust cover above
    port = gk.fillet2([(-12, 3), (-92, 3), (-92, 26), (-12, 26)], 2.0, 1, radii=[2.5, 2.5, 0, 0])
    cuts.append(gk.prism_cutter(mm(port), mm(-30.0), mm(-4.0), mi=Bo))
    # charging-handle slot ahead of and behind the port
    for x0, x1 in ((-12.5, 22.0), (-112.0, -91.5)):
        cuts.append(gk.prism_cutter(mm([(x0, 15.5), (x1, 15.5), (x1, 21.0), (x0, 21.0)]), mm(-30.0), mm(-14.0), mi=Bo))
    # magazine well
    c = bmesh.new()
    gk.box(c, mm(-36.0, 0, -22.0), mm(64.5, 28.6, 26.0), mi=Bo)
    cuts.append(c)
    # selector stop notches (right side, the detents the lever tab drops into)
    # (where the lever's detent nub (-47, 14) actually lands: rotated about SEL_PIVOT by SAFE 0 / AUTO 10 / SEMI 20)
    for x, z in selector_notches():
        c = bmesh.new()
        gk.box(c, mm(x, -REC_HW, z), mm(2.4, 1.6, 2.4), mi=St)
        cuts.append(c)
    gk.boolean_bm(bm, cuts)
    receiver_stamp(bm, Bo)
    # axis pins (hammer, trigger, disconnector), selector axis; the milled receiver has no trunnion rivets: only
    # two flush cross pins (front trunnion, rear trunnion)
    for (x, z, r) in ((-77.0, -15.0, 2.6), (-91.0, -12.0, 2.6), (-130.0, -19.0, 2.2), (-180.0, -10.0, 2.0)):
        gk.pin(bm, mm(x, REC_HW, z), (0, 1, 0), mm(r), proud=mm(0.35), segs=8, mi=Ba, both=mm(2 * REC_HW))
    gk.pin(bm, mm(-153.0, REC_HW, 3.0), (0, 1, 0), mm(3.2), proud=mm(0.5), segs=10, mi=St)
    for (x, z, r) in ((42.0, 10.0, 2.2), (-204.0, -12.0, 2.2)):
        gk.pin(bm, mm(x, REC_HW, z), (0, 1, 0), mm(r), proud=mm(0.12), segs=8, mi=St, both=mm(2 * REC_HW))
    # grip-screw boss under the tang (grip bolt comes from below) and the guard rivets
    for x in (-95.0, -140.0):
        gk.pin(bm, mm(x, 5.0, -58.5), (0, 0, -1), mm(1.5), proud=mm(0.4), segs=6, mi=Ba)
    return rc


def selector_notches(nub=(-47.0, 14.0)):
    """(x, z) mm of the selector detent nub at SAFE 0, AUTO +10 and SEMI +20 deg about SEL_PIVOT (+Y rotation:
    x' = x cos + z sin, z' = -x sin + z cos, as Matrix.Rotation(a, 'Y'))."""
    out = []
    for deg in (0.0, 10.0, 20.0):
        a = math.radians(deg)
        dx, dz = nub[0] - SEL_PIVOT[0], nub[1] - SEL_PIVOT[2]
        out.append((SEL_PIVOT[0] + dx * math.cos(a) + dz * math.sin(a),
                    SEL_PIVOT[2] - dx * math.sin(a) + dz * math.cos(a)))
    return out


def receiver_stamp(bm, mi):
    """Generic serial-like stamp engraved 0.25 mm into the left receiver flat above the trigger pins:
    'RB-04127' over '7.62x39' (no trademark, no copied marking)."""
    cutters = []
    for text, size, x0, z0 in (('RB-04127', 4.2, -96.0, 7.0), ('7.62x39', 3.4, -96.0, 1.5)):
        cu = bpy.data.curves.new('stamp', 'FONT')
        cu.body = text
        cu.size = mm(size)
        cu.resolution_u = 1
        cu.extrude = mm(0.25)
        cu.align_x = 'LEFT'
        t = gk._curve_to_bm(cu)
        # font local (x right, y up, z out) -> model: seen from the left (+Y) the gun's front (+X) is on the
        # left, so text x runs along -X, text up along +Z, its extrusion straddles the flat at y = REC_HW
        M = Matrix(((-1, 0, 0, mm(x0)), (0, 0, 1, mm(REC_HW)), (0, 1, 0, mm(z0)), (0, 0, 0, 1)))
        for v in t.verts:
            v.co = M @ v.co
        bmesh.ops.remove_doubles(t, verts=list(t.verts), dist=mm(0.05))
        for f in t.faces:
            f.material_index = mi
        cutters.append(t)
    gk.boolean_bm(bm, cutters)


def build_dust_cover(gun):
    dc = gun.part('DustCover', paint='SteelBlued')
    St, Ba = dc.mi('SteelBlued'), dc.mi('SteelBare')
    bm = dc.bm
    out = [(22, COVER_Z), (22, 40), (18.5, 44.0), (-176, 44.6), (-186, 42.5), (-193, 35.5), (-196, COVER_Z)]
    gk.profile(bm, mm(gk.fillet2(out, 2.0, 1, radii=[0, 3, 4, 6, 6, 4, 0])), mm(2 * REC_HW + 0.4),
               bevel=mm(5.5), bevel_segs=2, mi=St)
    # smooth milled-pattern cover (no AKM stiffening ribs): the photo's AK-47 cover is plain sheet with only
    # its rounded rear end
    # recoil-spring guide button through the rear of the cover
    gk.lathe(bm, mm([(0, 0), (0, 4.2), (3.0, 4.2), (4.0, 3.4), (4.4, 0)]), 12,
             gk.frame_x(V(mm(-195.0, 0, 31.5)), (-1, 0, 0)), mi=Ba)
    return dc


# --------------------------------------------------------------------------------------
# barrel group: barrel, rear sight block, gas block + tube, front sight base, ferrules, muzzle nut, rod
# --------------------------------------------------------------------------------------

def build_barrel(gun):
    br = gun.part('Barrel', paint='SteelBlued', fit=2)
    St, Bo, Ba = br.mi('SteelBlued'), br.mi('Bore'), br.mi('SteelBare')
    bm = br.bm
    prof = [(30, 0), (30, 10.5), (98, 10.5), (100, 8.8), (200, 8.4), (283, 8.1), (322, 7.9), (372, 7.7), (399, 7.5),
            (399, 6.6), (416, 6.6), (416, 4.6), (415.3, 3.9), (404, 3.9), (404, 0)]
    gk.lathe(bm, mm(prof), 18, gk.frame_x(V((0, 0, 0)), (1, 0, 0)), mi=St)
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        c = f.calc_center_median()
        if c.x > mm(403.5) and math.hypot(c.y, c.z) < mm(4.3):
            f.material_index = Bo
    # rear sight block (its leaf is SightRear)
    rs = [(25, 6), (97, 6), (97, 30), (93, 36), (93, 44), (90, 47), (30, 47), (25, 44)]
    gk.profile(bm, mm(gk.fillet2(rs, 1.5, 1)), mm(30.0), bevel=mm(1.4), bevel_segs=1, mi=St)
    gk.rbox(bm, mm(91.0, 0, 47.2), mm(7.0, 26.0, 3.0), mm(0.8), 1, mi=St)           # leaf hinge ears
    gk.pin(bm, mm(LEAF_PIVOT[0], 13.0, LEAF_PIVOT[2]), (0, 1, 0), mm(1.4), proud=mm(0.4), segs=6, mi=Ba, both=mm(26))
    # gas block with the tube socket, its lower lug for the cleaning rod, the front sling loop
    gb = [(283, -11), (316, -11), (316, -2), (303, 15), (296, 26), (291, 30.5), (286, 31.5), (283, 29)]   # front slope as the reference
    gk.profile(bm, mm(gk.fillet2(gb, 1.5, 1)), mm(24.0), bevel=mm(1.6), bevel_segs=1, mi=St)
    gk.rbox(bm, mm(302.0, 0, -13.5), mm(14.0, 10.0, 6.0), mm(1.0), 1, mi=St)
    gk.sling_swivel(bm, mm(300.0, 11.5, -6.0), axis_loop=(0, 1, 0), size=mm(17.0), mi=St)
    gk.pin(bm, mm(292.0, 12.0, 18.0), (0, 1, 0), mm(1.6), proud=mm(0.3), segs=6, mi=Ba, both=mm(24))
    # gas tube with its vents (through holes) and the upper-handguard front cap
    gt = bmesh.new()
    gk.lathe(gt, mm([(95, 0), (95, 9.0), (279, 9.0), (281, 10.2), (289, 10.2), (289, 0)]), 16,
             gk.frame_x(V(mm(0, 0, GAS_Z)), (1, 0, 0)), mi=St)
    gk.boolean_bm(gt, gk.hole_cutter([mm(x, 0, GAS_Z + 1.0) for x in (252.0, 262.0, 272.0)], (0, 1, 0), mm(2.3),
                                     mm(14.0), segs=10, mi=Bo))
    gk.merge(bm, gt)
    gt.free()
    gk.rbox(bm, mm(199.0, 0, 30.0), mm(6.0, 31.0, 26.0), mm(2.0), 2, mi=St)
    # front sight base: ring around the barrel, tower, protective ears, bayonet lug, rod stop
    fs = [(372, -13), (402, -13), (402, 12), (398, 16), (376, 16), (372, 12)]
    gk.profile(bm, mm(gk.fillet2(fs, 1.5, 1)), mm(24.0), bevel=mm(1.6), bevel_segs=1, mi=St)
    # the ears must rise above the rear leaf's top edge as seen from the eye (51.3 at 280 mm -> > 53.1 at 640 mm)
    # or the sight picture loses them: kept at 54 although the photo reads ~3 mm lower
    ear = [(378, 14), (398, 14), (398, 42), (394.5, 54.0), (382, 54.0), (378, 46)]
    for sy in (1, -1):
        y0, y1 = sy * 6.2, sy * 9.4
        gk.profile(bm, mm(gk.fillet2(ear, 1.0, 1, radii=[0, 0, 2, 1.5, 1.5, 2])), mm(3.2), y=mm((y0 + y1) / 2),
                   bevel=mm(0.6), bevel_segs=0, mi=St)
    gk.rbox(bm, mm(394.0, 0, -16.5), mm(14.0, 8.0, 7.0), mm(1.0), 1, mi=St)        # bayonet lug
    gk.rbox(bm, mm(376.0, 0, -16.0), mm(6.0, 9.0, 6.0), mm(0.8), 1, mi=St)         # rod stop
    gk.pin(bm, mm(385.0, 12.0, 4.0), (0, 1, 0), mm(1.5), proud=mm(0.3), segs=6, mi=Ba, both=mm(24))
    # lower handguard front ferrule
    sec = gk.rrect2(-2.0, 0.0, 20.0, 20.5, r_pos=4.0, r_neg=11.0, n=2)
    gk.section_x(bm, mm([(y, z) for z, y in sec]), mm(199.0), mm(207.0), end_bevel=mm(1.2), mi=St)
    return br


def build_muzzle(gun):
    md = gun.part('MuzzleDevice', paint='SteelBlued', parent='Barrel')
    St, Bo = md.mi('SteelBlued'), md.mi('Bore')
    prof = [(399.5, 4.4), (399.5, 7.6), (400.5, 8.4), (416.5, 8.4), (MUZZLE_X, 7.4), (MUZZLE_X, 4.6)]
    gk.lathe(md.bm, mm(prof), 18, gk.frame_x(V((0, 0, 0)), (1, 0, 0)), closed=True, mi=St)
    bm = md.bm
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        c = f.calc_center_median()
        if math.hypot(c.y, c.z) < mm(5.0):
            f.material_index = Bo
    # detent pin hole (the nut's retaining plunger) seen from the left
    gk.boolean_bm(bm, gk.hole_cutter([mm(404.0, 8.4, 0)], (0, 1, 0), mm(1.2), mm(1.0), segs=6, mi=Bo))
    return md


def build_cleaning_rod(gun):
    cr = gun.part('CleaningRod', paint='SteelBlued')
    St, Ba = cr.mi('SteelBlued'), cr.mi('SteelBare')
    gk.cyl(cr.bm, mm(40.0, 0, -14.8), mm(396.0, 0, -14.8), mm(3.0), 8, mi=St)
    gk.rbox(cr.bm, mm(401.0, 0, -14.8), mm(10.0, 4.6, 8.4), mm(1.2), 1, mi=Ba)
    gk.boolean_bm(cr.bm, gk.hole_cutter([mm(402.0, 0, -14.8)], (0, 1, 0), mm(1.7), mm(4.0), segs=8, mi=St))
    return cr


# --------------------------------------------------------------------------------------
# wood furniture: lower and upper handguards, pistol grip, stock (+ steel butt plate)
# --------------------------------------------------------------------------------------

def yz_ring(x, zc, hz, hw, r_top, r_bot, n=3):
    """A rounded-rectangle cross-section in the (y, z) plane at x (mm): centre height zc, half height hz,
    half width hw; top corners r_top, bottom corners r_bot.  Returns 3D points in metres."""
    sec = gk.rrect2(zc, 0.0, hz, hw, r_pos=r_top, r_neg=r_bot, n=n)
    return [mm(x, y, z) for z, y in sec]


def build_handguards(gun):
    lo = gun.part('HandguardLower', paint='Wood')
    W = lo.mi('Wood')
    rings = []
    for x in (50.0, 53.0, 58.0, 68.0, 85.0, 105.0, 125.0, 145.0, 165.0, 183.0, 192.0, 197.0, 200.0):
        bot = interp([(50, -24.5), (53, -27.0), (60, -28.5), (80, -27.6), (110, -24.5), (150, -22.6), (200, -21.6)], x)
        top = 22.0 if x > 52 else 20.5
        hw = interp([(50, 19.0), (53, 21.3), (62, 22.4), (90, 22.2), (120, 21.3), (170, 20.6), (196, 20.1), (200, 18.8)], x)
        rings.append(yz_ring(x, (top + bot) / 2, (top - bot) / 2, hw, 4.0, 12.0, n=5))
    gk.loft(lo.bm, rings, mi=W)
    # the steel retaining spring clip at the rear edge: a thin band wrapped round the wood (its top is hidden in
    # the rear sight block)
    St = lo.mi('SteelBlued')
    x0, x1 = 60.0, 66.0
    bot = interp([(53, -27.0), (60, -28.5), (80, -27.6)], 63.0)
    hw = interp([(53, 21.3), (62, 22.4), (90, 22.2)], 63.0)
    ring = gk.rrect2((22.0 + bot) / 2, 0.0, (22.0 - bot) / 2 + 0.7, hw + 0.7, r_pos=4.5, r_neg=12.5, n=5)
    gk.section_x(lo.bm, mm([(y, z) for z, y in ring]), mm(x0), mm(x1), end_bevel=mm(0.4), mi=St)
    up = gun.part('HandguardUpper', paint='Wood')
    W2 = up.mi('Wood')
    rings = []
    for x in (97.0, 99.0, 104.0, 130.0, 160.0, 186.0, 193.0, 196.0):
        top = interp([(97, 44.5), (100, 45.2), (196, 41.6)], x)
        bot = 17.5
        hw = interp([(97, 13.6), (100, 15.0), (190, 14.4), (196, 13.2)], x)
        if x in (97.0, 196.0):
            top -= 1.0
        rings.append(yz_ring(x, (top + bot) / 2, (top - bot) / 2, hw, 11.0, 2.5, n=5))
    gk.loft(up.bm, rings, mi=W2)
    return lo, up


# (measured row by row on the levelled reference: the top of the grip is fuller at the front, the heel of the
#  bottom rounds forward)
GRIP_FRONT = [(-29, -147.5), (-36, -148.5), (-45, -149.0), (-60, -152.0), (-80, -160.5), (-100, -169.5),
              (-115, -175.5), (-124, -178.0), (-129, -180.0)]
GRIP_BACK = [(-29, -200.0), (-36, -200.8), (-45, -201.5), (-60, -203.8), (-80, -210.0), (-100, -218.0),
             (-115, -222.8), (-124, -220.6), (-129, -217.8)]


def build_pistol_grip(gun):
    pg = gun.part('PistolGrip', paint='Wood')
    W, Ba = pg.mi('WoodGrip'), pg.mi('SteelBare')
    rings = []
    for z in (-29.0, -36.0, -45.0, -60.0, -80.0, -100.0, -112.0, -120.0, -125.5, -128.5, -130.5):
        xf, xb = interp([(a, b) for a, b in GRIP_FRONT], z), interp([(a, b) for a, b in GRIP_BACK], z)
        hw = interp([(-130.5, 12.0), (-128.5, 13.6), (-125.5, 14.5), (-110, 15.0), (-60, 15.2), (-36, 13.9), (-29, 13.5)], z)
        inset = {-130.5: 3.2, -128.5: 1.2, -125.5: 0.3}.get(z, 0.0)
        sec = gk.rrect2((xf + xb) / 2, 0.0, (xf - xb) / 2 - inset, hw, r_pos=8.5, r_neg=10.5, n=3)
        rings.append([mm(x, y, z) for x, y in sec])
    gk.loft(pg.bm, rings, mi=W)
    # grip bolt head in the bottom recess
    gk.screw(pg.bm, mm(-199.0, 0, -130.6), (0, 0, -1), mm(4.0), mm(1.4), 'slot', mi=Ba, mi_recess=pg.mi('Bore'))
    return pg


# (measured column by column on the levelled reference: the wrist dips 4-5 mm lower, the comb behind it runs
#  level to x -350 and then drops less, the toe sits 4 mm higher)
STOCK_TOP = [(-212.5, 21.0), (-222, 17.0), (-240, 7.5), (-262, 4.0), (-290, 4.0), (-300, 4.6), (-310, 6.0),
             (-322, 6.8), (-350, 6.6), (-455, -8.0)]
STOCK_BOT = [(-212.5, -23.5), (-222, -27.5), (-240, -36.5), (-260, -45.5), (-300, -60.5), (-440, -119.0),
             (-455, -121.5)]
STOCK_GRAIN_DEG = 14.0            # the stock's long axis rises ~14 deg toward the front (grain along it)
GRIP_GRAIN_DEG = 74.0             # the grip's long axis (raked ~16 deg back from vertical)
STOCK_HW = [(-212.5, 18.6), (-240, 17.6), (-250, 18.3), (-300, 20.0), (-380, 21.0), (-455, 21.0)]


BUTT_RAKE = 0.13                  # the butt face rakes ~7.5 deg: heel back, toe forward (as the reference)


def stock_ring(x, grow=0.0, n=3):
    top, bot, hw = interp(STOCK_TOP, x) + grow, interp(STOCK_BOT, x) - grow, interp(STOCK_HW, x) + grow
    return yz_ring(x, (top + bot) / 2, (top - bot) / 2, hw, 8.5 + grow, 9.0 + grow, n)


def build_stock(gun):
    sk = gun.part('Stock', paint='Wood')
    W, St, Ba = sk.mi('WoodStock'), sk.mi('SteelBlued'), sk.mi('SteelBare')
    rings = [stock_ring(x) for x in (-212.5, -216.0, -222.0, -231.0, -240.0, -250.0, -262.0, -290.0, -300.0,
                                     -310.0, -322.0, -350.0, -385.0, -420.0, -448.0, -455.0)]
    gk.loft(sk.bm, rings, mi=W)
    # steel upper tang strap inletted along the top of the wrist (its screw is the tang screw below) and the
    # lower tang under the wrist, behind the grip
    up = [mm(x, 0, interp(STOCK_TOP, x) - 0.2) for x in (-212.0, -222.0, -235.0, -248.0, -262.0)]
    gk.sweep(sk.bm, up, 0, rect=(mm(11.0), mm(1.6)), upref=(0, 0, 1), mi=St)
    lo_ = [mm(x, 0, interp(STOCK_BOT, x) + 0.2) for x in (-212.0, -219.0, -228.0, -238.0)]
    gk.sweep(sk.bm, lo_, 0, rect=(mm(10.0), mm(1.6)), upref=(0, 0, 1), mi=St)
    gk.pin(sk.bm, mm(-232.0, 0, interp(STOCK_BOT, -232.0) - 1.4), (0, 0, -1), mm(2.4), proud=mm(0.4), segs=8, mi=Ba)
    # left-side sling loop on its riveted plate
    gk.rbox(sk.bm, mm(-283.0, 20.6, -12.0), mm(22.0, 1.6, 12.0), mm(0.6), 1, mi=St)
    gk.torus(sk.bm, mm(-279.0, 22.0, -16.0), (0, 1, 0), mm(11.0), mm(1.7), 18, 6, mi=St)
    for x in (-290.0, -276.0):
        gk.pin(sk.bm, mm(x, 21.4, -12.0), (0, 1, 0), mm(1.6), proud=mm(0.5), segs=6, mi=Ba)
    # tang screw on the top of the wrist
    gk.screw(sk.bm, mm(-258.0, 0, interp(STOCK_TOP, -258.0) + 1.5), (0, 0, 1), mm(3.2), mm(1.0), 'slot', mi=Ba, mi_recess=sk.mi('Bore'))
    bp = gun.part('ButtPlate', paint='SteelBlued')
    St2, Ba2, Bo2 = bp.mi('SteelBlued'), bp.mi('SteelBare'), bp.mi('Bore')
    r0 = [(p[1] / 0.001, p[2] / 0.001) for p in stock_ring(-455.0, grow=0.4)]
    gk.section_x(bp.bm, mm(r0), mm(-462.0), mm(-454.6), end_bevel=mm(1.3), mi=St2)
    for z in (-24.0, -103.0):
        gk.screw(bp.bm, mm(-462.0, 0, z), (-1, 0, 0), mm(3.4), mm(1.0), 'slot', mi=Ba2, mi_recess=Bo2)
    # trap door (cleaning-kit compartment) outline: a shallow raised lid with its push button
    gk.rbox(bp.bm, mm(-462.4, 0, -63.0), mm(1.2, 22.0, 46.0), mm(0.5), 1, mi=St2)
    gk.cyl(bp.bm, mm(-462.6, 0, -88.5), mm(-463.6, 0, -88.5), mm(2.6), 10, mi=Ba2)
    # the butt's rear face is raked (heel back, toe forward ~5 deg) as on the reference
    for bm_ in (sk.bm, bp.bm):
        for v in bm_.verts:
            t = min(1.0, max(0.0, (mm(-430.0) - v.co.x) / mm(32.0)))
            v.co.x += t * BUTT_RAKE * (mm(-11.0) - v.co.z)
    return sk, bp


# --------------------------------------------------------------------------------------
# sights
# --------------------------------------------------------------------------------------

def build_sights(gun):
    fp = gun.part('SightFront', paint='SteelBlued', parent='Barrel', origin=mm(FRONT_POST[0], 0, 14.0))
    St = fp.mi('SteelBlued')
    gk.cyl(fp.bm, mm(FRONT_POST[0], 0, 13.5), mm(FRONT_POST[0], 0, 22.0), mm(5.6), 14, mi=St)  # windage drum
    for k in range(4):                                                                          # drum index marks
        gk.box(fp.bm, mm(FRONT_POST[0] - 5.6, 0, 15.0 + k * 1.8), mm(0.5, 1.0, 0.5), mi=St)
    gk.cyl(fp.bm, mm(FRONT_POST[0], 0, 22.0), mm(FRONT_POST[0], 0, FRONT_POST[1] - 0.8), mm(1.45), 8, mi=St, r1=mm(1.15))
    gk.cyl(fp.bm, mm(FRONT_POST[0], 0, FRONT_POST[1] - 0.8), mm(FRONT_POST[0], 0, FRONT_POST[1]), mm(1.15), 8, mi=St,
           r1=mm(1.0))
    # rear sight leaf (hinged at its front on the block), notch at its rear upright, range slider
    lf = gun.part('SightRear', paint='SteelBlued', parent='Barrel', origin=mm(*LEAF_PIVOT))
    St2, Ba2 = lf.mi('SteelBlued'), lf.mi('SteelBare')
    # the notch is shallow (1.6 mm): the sight picture is the post tip level with the leaf's top edge, the
    # front-sight ears rising above that edge on either side of the post
    side = [(91.5, 45.0), (91.5, 48.0), (86.0, 47.6), (33.0, 48.0), (29.0, 51.3), (24.5, 51.3), (24.5, 47.5),
            (28.0, 45.6)]
    gk.profile(lf.bm, mm(gk.fillet2(side, 0.6, 1)), mm(19.0), bevel=mm(0.5), bevel_segs=0, mi=St2)
    c = bmesh.new()
    gk.box(c, mm(26.5, 0, REAR_NOTCH[1] + 3.0), mm(8.0, 2.4, 6.0), mi=St2)                    # the notch
    gk.boolean_bm(lf.bm, c)
    gk.rbox(lf.bm, mm(58.0, 0, 47.7), mm(10.0, 22.0, 2.8), mm(0.8), 1, mi=St2)      # range slider (under the sight line)
    for sy in (1, -1):
        gk.rbox(lf.bm, mm(58.0, sy * 11.6, 47.6), mm(6.0, 1.6, 2.4), mm(0.5), 1, mi=Ba2)      # its latch buttons
    for k in range(6):                                                                          # range graduations
        gk.box(lf.bm, mm(40.0 + k * 7.0, 9.6, 47.4), mm(0.5, 0.25, 1.0), mi=Ba2)
    return fp, lf


# --------------------------------------------------------------------------------------
# moving parts: bolt carrier + charging handle, selector, trigger, mag release
# --------------------------------------------------------------------------------------

def build_bolt_carrier(gun):
    bc = gun.part('BoltCarrier', paint='SteelBlued', origin=mm(0, 0, 13.0))
    St, Ba = bc.mi('SteelBlued'), bc.mi('SteelBare')
    bm = bc.bm
    gk.rbox(bm, mm(-52.0, -3.0, 16.0), mm(96.0, 24.0, 13.0), mm(1.5), 1, mi=St)       # carrier body (port side)
    gk.cyl(bm, mm(-4.0, 0, 0), mm(-78.0, 0, 0), mm(10.4), 14, mi=Ba)                # bolt
    gk.rbox(bm, mm(-8.0, 0, 0), mm(8.0, 18.0, 18.0), mm(1.2), 1, mi=Ba)              # locking lugs
    gk.rbox(bm, mm(-24.0, -10.2, 3.6), mm(15.0, 2.6, 4.0), mm(0.5), 1, mi=St)        # extractor
    gk.box(bm, mm(-36.0, -10.5, 1.0), mm(5.0, 0.4, 2.6), mi=St)                      # bolt cam lug face
    gk.rbox(bm, mm(4.0, -16.5, 18.2), mm(30.0, 5.0, 5.0), mm(0.8), 1, mi=St)         # arm to the handle
    gk.rbox(bm, mm(-100.0, -16.5, 18.2), mm(16.0, 5.0, 5.0), mm(0.8), 1, mi=St)      # rear rail tab
    # carrier front block and the long-stroke piston (op rod) running forward into the gas tube: hidden at rest
    # inside the cover / rear sight block / handguard / tube, visible through the port when the carrier is back
    gk.rbox(bm, mm(18.0, 0, 21.0), mm(44.0, 15.0, 11.0), mm(1.5), 1, mi=St)
    gk.cyl(bm, mm(38.0, 0, GAS_Z), mm(262.0, 0, GAS_Z), mm(4.4), 10, mi=Ba)
    gk.cyl(bm, mm(262.0, 0, GAS_Z), mm(276.0, 0, GAS_Z), mm(7.2), 12, mi=Ba)        # piston head
    for x in (264.5, 268.0):                                                             # its gas rings
        gk.cyl(bm, mm(x, 0, GAS_Z), mm(x + 1.2, 0, GAS_Z), mm(7.5), 12, mi=St)
    ch = gun.part('ChargingHandle', paint='SteelBlued', parent='BoltCarrier', origin=mm(13.0, -18.5, 18.5))
    St2 = ch.mi('SteelBlued')
    path = [mm(14.0, -17.0, 18.4), mm(13.8, -26.0, 18.6), mm(13.0, -33.0, 20.4), mm(12.0, -38.0, 23.6)]
    gk.sweep(ch.bm, gk.crs(path, 3), mm(3.4), segs=10, mi=St2)
    d = (V(path[-1]) - V(path[-2])).normalized()
    gk.lathe(ch.bm, mm([(-2.0, 0), (-2.0, 4.6), (2.0, 6.8), (8.5, 6.6), (11.5, 4.2), (12.4, 0)]), 16,
             gk.frame_x(V(path[-1]), d), mi=St2)
    return bc, ch


def build_selector(gun):
    """The big right-side lever: built at SAFE (up) then turned +20 deg to SEMI, the exported rest."""
    se = gun.part('Selector', paint='SteelBlued', origin=mm(*SEL_PIVOT))
    St = se.mi('SteelBlued')
    t = bmesh.new()
    out = [(-163.0, -1.0), (-151.0, -5.5), (-100.0, 8.2), (-52.0, 17.6), (-44.0, 19.4), (-41.0, 23.4), (-44.0, 26.2),
           (-54.0, 25.6), (-100.0, 20.6), (-150.0, 12.0), (-163.0, 8.0)]
    gk.profile(t, mm(gk.fillet2(out, 2.0, 1, radii=[5, 4, 6, 3, 1.5, 1.5, 2, 3, 6, 4, 5])), mm(1.7),
               y=mm(-REC_HW - 1.05), bevel=mm(0.4), bevel_segs=0, mi=St)
    gk.lathe(t, mm([(0, 0), (0, 8.5), (2.2, 8.5), (3.0, 7.2), (3.2, 0)]), 16,
             gk.frame_x(V(mm(SEL_PIVOT[0], -REC_HW - 0.2, SEL_PIVOT[2])), (0, -1, 0)), mi=St)
    gk.rbox(t, mm(-44.5, -REC_HW - 4.2, 22.4), mm(5.5, 6.4, 7.0), mm(1.0), 1, mi=St)      # finger tab
    gk.rbox(t, mm(-47.0, -REC_HW - 0.2, 14.0), mm(2.2, 1.4, 2.0), mm(0.3), 1, mi=St)       # detent nub
    piv = V(mm(*SEL_PIVOT))
    R = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(20.0), 4, 'Y') @ Matrix.Translation(-piv)
    gk.merge(se.bm, t, R)
    t.free()
    return se


def build_trigger(gun):
    tg = gun.part('Trigger', paint='SteelBlued', origin=mm(*TRIG_PIVOT), fit=3)
    St = tg.mi('SteelBlued')
    out = [(-85.0, -10.0), (-90.0, -5.5), (-97.0, -7.0), (-123.0, -19.5), (-124.0, -30.0), (-125.5, -38.0),
           (-127.5, -44.0), (-130.5, -48.5), (-129.0, -51.5), (-125.0, -51.0), (-120.5, -46.0), (-117.0, -38.0),
           (-114.5, -29.0), (-97.0, -17.0), (-88.0, -15.0)]
    gk.profile(tg.bm, mm(gk.fillet2(out, 1.0, 1, radii=[3, 3, 2, 2, 0, 0, 1, 2, 1.6, 1.5, 1, 0, 2, 3, 2])), mm(7.0),
               bevel=mm(1.1), bevel_segs=1, mi=St)
    for k in range(5):                                                                    # face serrations
        gk.box(tg.bm, mm(-118.6 - k * 1.05, 0, -32.0 - k * 3.2), mm(0.6, 5.0, 0.6),
               R=Matrix.Rotation(math.radians(-25), 3, 'Y'), mi=St)
    return tg


def build_mag_release(gun):
    mr = gun.part('MagRelease', paint='SteelBlued', origin=mm(*REL_PIVOT))
    St = mr.mi('SteelBlued')
    # paddle ends just above the trigger guard's bottom line (-58.5), 11 mm wide
    out = [(-69.0, -20.0), (-77.5, -20.0), (-79.0, -33.0), (-81.0, -44.0), (-84.8, -53.5), (-84.2, -57.0),
           (-79.8, -56.0), (-76.4, -50.0), (-73.5, -38.0), (-70.0, -27.0)]
    gk.profile(mr.bm, mm(gk.fillet2(out, 1.2, 1, radii=[1, 1, 3, 3, 2, 1.5, 2, 3, 3, 1])), mm(11.0),
               bevel=mm(1.0), bevel_segs=1, mi=St)
    for k in range(3):                                                                    # paddle grip ribs
        gk.box(mr.bm, mm(-82.4 - k * 0.6, 0, -48.5 - k * 2.3), mm(1.0, 9.4, 0.8),
               R=Matrix.Rotation(math.radians(30), 3, 'Y'), mi=St)
    gk.pin(mr.bm, mm(REL_PIVOT[0], 5.7, REL_PIVOT[2]), (0, 1, 0), mm(1.6), proud=mm(0.4), segs=6, mi=St, both=mm(11.4))
    return mr


# --------------------------------------------------------------------------------------
# magazine (+ top round, follower), loose round, spent case
# --------------------------------------------------------------------------------------

def build_magazine(gun):
    org = (MAGWELL[0], 0, MAGWELL[1])
    mg = gun.part('Magazine', paint='SteelBlued', origin=mm(*org), fit=4)
    St, Ba = mg.mi('SteelMag'), mg.mi('SteelBare')
    bm = mg.bm
    res = gk.box_mag(bm, mm(*org), MAG_AX, mm(MAG_LEN), mm(MAG_DEPTH), mm(MAG_W),
                     {'body': St, 'base': St, 'lips': Ba}, curve_deg=MAG_CURVE, top_width=mm(MAG_W * 0.78),
                     rib=False, base_h=mm(6.0), base_over=(mm(3.0), mm(2.0)), segs_curve=8, lips=mm(9.0),
                     body_len=mm(MAG_BODY))
    frame_at = res[-1]
    # stamped side ribs following the curve (4 per side), the spine rib on the back
    for sy in (1, -1):
        for d in (-0.33, -0.12, 0.09, 0.30):
            pts = []
            for k in range(9):
                s = mm(24.0) + (mm(MAG_BODY - 12.0) - mm(24.0)) * k / 8
                p, a, f = frame_at(s)
                q2 = p + f * (mm(MAG_DEPTH) * d)
                pts.append(V((q2.x, sy * (mm(MAG_W) / 2 + 0.0003), q2.y)))
            gk.sweep(bm, pts, 0, rect=(mm(3.4), mm(1.5)), upref=(0, sy, 0), mi=St)
    pts = []
    for k in range(9):
        s = mm(14.0) + (mm(MAG_BODY - 6.0) - mm(14.0)) * k / 8
        p, a, f = frame_at(s)
        q2 = p - f * (mm(MAG_DEPTH) / 2 + 0.0004)
        pts.append(V((q2.x, 0, q2.y)))
    gk.sweep(bm, pts, 0, rect=(mm(6.0), mm(1.6)), upref=(0, 1, 0), mi=St)
    # front locking lug (hooks the trunnion: the rock pivot) and the rear catch lug
    p, a, f = frame_at(mm(4.0))
    R3 = gk._side_R(a, f)
    c = p + f * (mm(MAG_DEPTH) / 2 + mm(2.0))
    gk.rbox(bm, V((c.x, 0, c.y)), mm(5.0, 14.0, 6.0), mm(0.8), 1, R=R3, mi=St)
    p, a, f = frame_at(mm(17.0))
    c = p - f * (mm(MAG_DEPTH) / 2 + mm(1.8))
    gk.rbox(bm, V((c.x, 0, c.y)), mm(4.0, 12.0, 5.0), mm(0.6), 1, R=gk._side_R(a, f), mi=St)
    # top round in the lips (double stack: offset to the left), perpendicular to the mag at the top
    head = V(mm(MAGWELL[0], 0, MAGWELL[1])) - V((MAG_FR[0], 0, MAG_FR[1])) * mm(27.8) + \
        V((MAG_AX[0], 0, MAG_AX[1])) * mm(3.6) + V((0, mm(3.4), 0))
    rt = gun.part('MagRoundTop', paint='SteelLacquer', parent='Magazine', origin=tuple(head))
    mats = {'case': rt.mi('SteelLacquer'), 'primer': rt.mi('Brass'), 'bullet': rt.mi('Copper')}
    gk.build_round(rt.bm, '7.62x39', mats, gk.frame_x(head, V((MAG_FR[0], 0, MAG_FR[1]))), segs=7)
    # follower (shown in the empty-magazine model only), at the top of the body
    fo = gun.part('MagFollower', paint='SteelBlued', parent='Magazine', origin=mm(*org))
    p, a, f = frame_at(mm(7.0))
    gk.rbox(fo.bm, V((p.x, 0, p.y)), mm(MAG_DEPTH - 4.0, MAG_W - 4.0, 5.0), mm(1.0), 1, R=gk._side_R(a, f),
            mi=fo.mi('SteelBlued'))
    p, a, f = frame_at(mm(4.5))
    c = p - f * mm(12.0)
    gk.rbox(fo.bm, V((c.x, mm(4.0), c.y)), mm(26.0, 9.0, 3.0), mm(0.8), 1, R=gk._side_R(a, f), mi=fo.mi('SteelBlued'))
    return mg, rt, fo, frame_at


def build_case_round(col):
    """The separate small models: spent lacquered-steel case and loose round (origins at their centre of mass)."""
    out = {}
    for name, fn in (('Rifle_Case', 'case'), ('Rifle_Round', 'round')):
        bm = bmesh.new()
        if fn == 'case':
            mats = ['SteelLacquer', 'Brass']
            gk.build_case(bm, '7.62x39', {'case': 0, 'primer': 1}, segs=8, spent=True)
        else:
            mats = ['SteelLacquer', 'Brass', 'Copper']
            gk.build_round(bm, '7.62x39', {'case': 0, 'primer': 1, 'bullet': 2}, segs=7)
        com = gk.bm_volume_com(bm)
        out[name] = gk.single_object(col, name, bm, mats, origin=com)
    return out


# --------------------------------------------------------------------------------------
# the model
# --------------------------------------------------------------------------------------
WOOD_PARTS = ('Stock', 'PistolGrip', 'HandguardLower', 'HandguardUpper')


def build_model():
    gun = gk.GunModel(GID, mass=3.9)
    build_receiver(gun)
    build_dust_cover(gun)
    build_barrel(gun)
    build_muzzle(gun)
    build_cleaning_rod(gun)
    build_handguards(gun)
    build_pistol_grip(gun)
    build_stock(gun)
    build_sights(gun)
    build_bolt_carrier(gun)
    build_selector(gun)
    build_trigger(gun)
    build_mag_release(gun)
    _, _, _, frame_at = build_magazine(gun)
    # hinges (ARCHITECTURE §5.2)
    gun.hinge('BoltCarrier', 'slide', (-1, 0, 0), mm(STROKE), note='carries ChargingHandle; cycles each shot')
    gun.hinge('Selector', 'rotate', (0, 1, 0), 20.0, rest=20.0, mn=0.0,
              detents={'SAFE': 0.0, 'AUTO': 10.0, 'SEMI': 20.0}, note='exported on SEMI (rest 20)')
    gun.hinge('MagRelease', 'rotate', (0, 1, 0), 0.0, mn=-12.0, note='paddle pushed forward')
    gun.hinge('Magazine', 'rotate', (0, 1, 0), 0.0, mn=-25.0, pivot=mm(MAG_ROCK[0], 0, MAG_ROCK[1]),
              then='detach', note='rocks forward about MagRockPivot (front lug), then comes free')
    gun.hinge('Trigger', 'rotate', (0, 1, 0), 14.0)
    gun.hinge('SightRear', 'rotate', (0, 1, 0), 8.0,
              note='the leaf hinges at its FRONT on the block, so raising the notch is positive here '
                   '(ARCHITECTURE lists RearSight 0 -> -8 for a rear pivot)', alias='RearSight')
    # markers (ARCHITECTURE §5.3)
    gun.marker('Muzzle', mm(MUZZLE_X, 0, 0))
    a, b = math.radians(35), math.radians(18)                 # AK: thrown forward-right (30-45 deg) and up
    ej = V((math.sin(a) * math.cos(b), -math.cos(a) * math.cos(b), math.sin(b)))
    gun.marker('EjectionPort', mm(-52.0, -REC_HW, 13.0), ej, (0, -0.6, 0.8))
    gun.marker('CasingSpawn', mm(-40.0, -REC_HW - 8.0, 12.0), (0.97, -0.17, 0.17), (0, 0, 1))
    gun.marker('MagWell', mm(MAGWELL[0], 0, MAGWELL[1]), (MAG_AX[0], 0, MAG_AX[1]), (MAG_FR[0], 0, MAG_FR[1]))
    gun.marker('MagRockPivot', mm(MAG_ROCK[0], 0, MAG_ROCK[1]), (1, 0, 0), (0, 0, 1))
    # GripR: centre of the pistol grip at trigger-finger height; +Z hand -> elbow (the shouldered forearm
    # runs back, a little down and out to the right), +X the arm's front face (up, orthogonalised)
    zr = V(GRIP_R_Z).normalized()
    xr = (V((0, 0, 1)) - zr * zr.z).normalized()
    xr = Matrix.Rotation(math.radians(GRIP_R_TWIST), 3, zr) @ xr      # design lever: neutral wrist twist
    gun.marker('GripR', mm(*GRIP_R), xr, zr)
    zl = V(GRIP_L_Z).normalized()
    gun.marker('GripL', mm(*GRIP_L), (V((0, 0, 1)) - zl * zl.z).normalized(), zl)
    gun.marker('Shoulder', mm(-462.0 + BUTT_RAKE * (-11.0 + 67.0), 0, -67.0), (1, 0, 0), (0, 0, 1))
    # AK sight picture: the post tip level with the notch shoulders (the leaf's top edge, 1.6 mm above the notch
    # floor), centred in the notch, so the post shows in the notch and the ears either side of it
    rear = V(mm(REAR_NOTCH[0], 0, LEAF_TOP))
    front = V(mm(FRONT_POST[0], 0, FRONT_POST[1]))
    d = (front - rear).normalized()
    gun.marker('SightEye', rear - d * 0.28, d, (0, 0, 1))
    gun.marker('CoM', mm(-55.0, 0, -22.0))
    gun.marker('BackMount', mm(-60.0, 0, 0.0), (1, 0, 0), (0, 0, 1))
    p, a2, f2 = frame_at(mm(110.0))
    gun.marker('MagGrab', (p.x + f2.x * mm(10), 0, p.y + f2.y * mm(10)), (MAG_AX[0], 0, MAG_AX[1]), (0.15, 0.85, 0.5))
    gun.marker('ChargeHandle', mm(11.0, -43.0, 27.0), (-1, 0, 0), (0, -0.5, 0.85))
    gun.marker('MagRelease', mm(-83.0, 0, -55.0), (1, 0, 0), (0, 0, 1))
    gun.marker('Selector', mm(-50.0, -REC_HW - 4.0, -8.0), (0, 0, -1), (0, -1, 0))
    gun.separate = {'Case': 'Rifle_Case.fbx', 'Round': 'Rifle_Round.fbx', 'Mag': 'Rifle_Mag.fbx',
                    'MagEmpty': 'Rifle_MagEmpty.fbx'}
    gun.colliders = {'Magazine': {'size': [0.20, round(mm(MAG_W + 2), 4), 0.075],
                                  'axes': 'magazine local: +X down the mag (MagWell +X), +Y left, +Z its front',
                                  'massKg': 0.80, 'massEmptyKg': 0.33}}
    gun.extra['aliases'] = {'RearSight': 'SightRear'}
    gun.extra['atlases'] = {'Rifle': 'steel parts, magazine (Rifle_*.png)',
                            'Rifle_Wood': 'Stock, PistolGrip, HandguardLower, HandguardUpper (Rifle_Wood_*.png)'}
    return gun


# hold design levers (mm, model space)
GRIP_R = (-176.0, 0.0, -46.0)
GRIP_R_Z = (-0.92, -0.05, -0.38)
GRIP_R_TWIST = float(os.environ.get('GRIP_R_TWIST', '-10'))
GRIP_L = (176.0, 0.0, -9.0)
GRIP_L_Z = (-0.33, 0.93, -0.12)


def gun_samples():
    """Model-space points for the solver's penetration tests: barrel, receiver, magazine, grip, the butt
    (the stock comb under the cheek is left out: the cheek weld is wanted)."""
    pts = []
    for x in (418, 380, 320, 260, 200, 140, 90, 40):
        for z in (-20, 30):
            pts.append(mm(x, 0, z))
    for x in (40, -40, -120, -190):
        for z in (-27, 24):
            for y in (-19, 19):
                pts.append(mm(x, y, z))
    for s in (40, 100, 160, 190):
        for d in (-25, 25):
            pts.append(mm(MAGWELL[0] + MAG_AX[0] * s + MAG_FR[0] * d + 0.25 * s,
                          0, MAGWELL[1] + MAG_AX[1] * s + MAG_FR[1] * d))
    pts += [mm(-180, 0, -128), mm(-222, 0, -126), mm(-120, 0, -58)]
    pts += [mm(-455, 0, -110), mm(-400, 0, -90), mm(-330, 0, -60)]
    return pts


# --------------------------------------------------------------------------------------
# stances (long gun, ARCHITECTURE §7.3): stock in the pocket, the solver finds blade, lean, neck, arms, wrist
# --------------------------------------------------------------------------------------
# the butt rides high in the R6 shoulder pocket (top front of the right arm block): the R6 eye sits 1.6 studs
# above the torso centre, so a real-height cheek weld needs the stock up there and the torso leaning in
POCKET_HIGH = (0.72, 1.0, -0.5)
# the game camera's 70 deg vertical FOV on a 1100 x 820 frame, as a 36 mm-wide-sensor lens
EYE_LENS_GAME = 18.0 / (math.tan(math.radians(35.0)) * 1100.0 / 820.0)
STANCES = [
    # Aim: cheek weld (the stock behind the receiver may enter the R6 head block: a real cheek sits on the comb),
    # head tipped 20 deg forward onto the stock and turned 20 deg toward it, torso upright or leaning in
    dict(name='Aim', pitch=0.0, cant=0.0, w_cant=12.0, cant_max=3.0, shoulder=True, pocket=(0.72, 1.1, -0.45),
         eye='line', eye_t=(-0.45, 0.45), w_eye=60.0, w_dir=35.0, blade=-50.0, blade_tol=20.0, lean=-12.0,
         lean_tol=15.0, lean_max=0.0, head_pitch=-20.0, head_yaw=-20.0, cheek=True, w_wrist=4.0, wrist_limit=25.0,
         left_limit=35.0, rs_ref=(70, 0, 35), ls_ref=(100, 0, -35), front=14.0, w_left=30.0, w_butt=8.0),
    dict(name='Ready', pitch=-10.0, cant=0.0, w_cant=8.0, shoulder=True, pocket=POCKET_HIGH, eye='over',
         eye_over=0.30, blade=-40.0, blade_tol=20.0, lean=-5.0, lean_max=0.0, head_pitch=-5.0, wrist_limit=25.0, left_limit=35.0,
         rs_ref=(70, 0, 30), ls_ref=(80, 0, -45), front=12.0, w_left=12.0, w_butt=8.0, cant_max=6.0),
    dict(name='LowReady', pitch=-38.0, cant=0.0, w_cant=8.0, shoulder=True, blade=-35.0, blade_tol=20.0, lean=-4.0,
         head_pitch=-12.0, wrist_limit=25.0, left_limit=35.0, rs_ref=(50, 0, 15), ls_ref=(50, 0, -40), front=10.0,
         w_left=12.0, w_butt=6.0, cant_max=6.0),
    dict(name='ReloadMag', pitch=-12.0, yaw=8.0, cant=20.0, w_cant=2.0, shoulder=True, pocket=(0.75, 0.55, -0.55),
         w_butt=4.0, blade=-40.0, blade_tol=25.0, lean=-8.0, look='gun', wrist_limit=35.0, rs_ref=(60, 0, 30),
         ls_ref=(60, 0, -30), front=12.0, left='MagGrab', left_limit=50.0, w_left=12.0),
]
# posture limits added on top of gunkit.HoldSolver's costs (rifle only): a level, upright shooter: root roll
# |rz| <= 5 deg, neck pitch |rx| <= 25 deg, neck roll |rz| <= 10 deg, and a hard cant band per stance
ROOT_ROLL_MAX, NECK_PITCH_MAX, NECK_ROLL_MAX = 5.0, 25.0, 10.0


def cant_of(e):
    """Cant in degrees of a solved gun frame (+ = top rolled to the right), as gunkit's cant term measures it."""
    return math.degrees(math.asin(max(-1.0, min(1.0, float(-e['right'][1])))))


class RifleHoldSolver(gk.HoldSolver):
    def residual(self, x, st):
        import numpy as np
        r = super().residual(x, st)
        extra = [max(0.0, abs(x[2]) - ROOT_ROLL_MAX) / 0.5,
                 max(0.0, abs(x[3]) - NECK_PITCH_MAX) / 2.0,
                 max(0.0, abs(x[5]) - NECK_ROLL_MAX) / 1.5,
                 max(0.0, x[0] - st.get('lean_max', 99.0)) / 1.5]
        if 'cant_max' in st:
            e = self.evaluate(x, st)
            extra.append(max(0.0, abs(cant_of(e) - st.get('cant', 0.0)) - st['cant_max']) / 1.0)
        return np.concatenate([r, np.array(extra, float)])


def solve_holds(gun, out_json):
    import numpy as np
    solver = RifleHoldSolver(gun, gun_samples())
    cheek = RifleHoldSolver(gun, [p for p in gun_samples() if p[0] > mm(REC_X[1] - 1.0)])
    results = []
    for st in STANCES:
        st = dict(st)
        r = (cheek if st.pop('cheek', False) else solver).solve(st, starts=18)
        r['residuals']['cantDeg'] = round(cant_of(r['_eval']), 2)
        r['residuals']['rootRollDeg'] = r['pose']['Root'][2]
        print('HOLD %-10s cost %.4f residuals %s pose %s wrist %s' % (r['name'], r['cost'], r['residuals'],
                                                                     r['pose'], r['wrist']), flush=True)
        e = r['_eval']
        Ginv = np.linalg.inv(e['G'])
        for arm in ('Right Arm', 'Left Arm'):
            yg = Ginv[:3, :3] @ e['F'][arm][:3, 1]
            print('   %s hand->elbow in model axes %s' % (arm, np.round(np.array(gk.M2G, float).T @ yg, 3)))
        results.append(r)
    gk.holds_to_json(out_json, GID, results, extra={
        'note': 'Solved by tools/guns/rifle_ak.py (RifleHoldSolver = gunkit.HoldSolver + rifle posture limits: '
                'root roll <= 5, neck pitch <= 25, neck roll <= 10 deg, cant band per stance). R6: rigid arms, hand '
                'point (0,-0.92,0) in arm space; the weld is the only wrist. Shouldered stances keep the Shoulder '
                'marker in the stance pocket (Torso space). Aim: cheek weld on the comb, cant ~0, eye on the sight '
                'line. ReloadMag: stock low on the shoulder, gun canted 20 deg on purpose, the left hand on the '
                'seated magazine (MagGrab) about to rock it out. residuals.cantDeg = solved cant (+ = top right).',
        'markers': {k: [round(c, 5) for c in gun.markers[k][0]] for k in ('GripR', 'GripL', 'SightEye', 'Shoulder',
                                                                         'MagGrab')}})
    return results, solver


# --------------------------------------------------------------------------------------
# renders
# --------------------------------------------------------------------------------------

def set_pose(objs, carrier=0.0, trigger=0.0, selector=20.0, release=0.0, rock=0.0, mag_out=0.0, leaf=0.0):
    """Moving parts away from rest (carrier metres back, angles in degrees; rock = magazine angle about
    MagRockPivot (negative = swung forward), mag_out = metres further down its rocked MagWell axis)."""
    def rot_about(name, piv, deg, extra=V((0, 0, 0))):
        ob = objs[name]
        o = V(ob['origin'])
        p = V(piv)
        M = Matrix.Translation(p + extra) @ Matrix.Rotation(math.radians(deg), 4, 'Y') @ Matrix.Translation(o - p)
        ob.matrix_basis = M
    objs['BoltCarrier'].matrix_basis = Matrix.Translation(V(objs['BoltCarrier']['origin']) + V((-carrier, 0, 0)))
    rot_about('Trigger', mm(*TRIG_PIVOT), trigger)
    rot_about('Selector', mm(*SEL_PIVOT), selector - 20.0)
    rot_about('MagRelease', mm(*REL_PIVOT), release)
    ra = math.radians(rock)
    ax = V((MAG_AX[0] * math.cos(ra) + MAG_AX[1] * math.sin(ra), 0, -MAG_AX[0] * math.sin(ra) + MAG_AX[1] * math.cos(ra)))
    rot_about('Magazine', mm(MAG_ROCK[0], 0, MAG_ROCK[1]), rock, ax * mag_out)
    ob = objs['SightRear']
    ob.matrix_basis = Matrix.Translation(V(ob['origin'])) @ Matrix.Rotation(math.radians(leaf), 4, 'Y')
    bpy.context.view_layer.update()


def level_reference(src, out, angle=REF_ANGLE):
    """The reference photo rotated so the bore is horizontal, background made transparent and the steel
    highlights inside the silhouette darkened just enough for gk.ref_compare's mask (sum < 600)."""
    import numpy as np
    from PIL import Image
    from scipy import ndimage
    im = Image.open(src).convert('RGBA')
    im = im.resize((im.width * 4, im.height * 4), Image.LANCZOS)
    a = np.array(im).astype(float)
    mask = (a[:, :, :3].sum(2) < 690)
    mask = ndimage.binary_closing(mask, iterations=3)
    mask = ndimage.binary_opening(mask, iterations=1)
    s = a[:, :, :3].sum(2, keepdims=True)
    a[:, :, :3] = np.where(s > 585, a[:, :, :3] * (585.0 / np.maximum(s, 1)), a[:, :, :3])
    a[:, :, 3] = mask * 255
    r = Image.fromarray(a.astype('uint8')).rotate(angle, resample=Image.BICUBIC, expand=True)
    ra = np.array(r)
    ys, xs = np.nonzero(ra[:, :, 3] > 40)
    r.crop((xs.min() - 10, ys.min() - 10, xs.max() + 10, ys.max() + 10)).save(out)
    return out


def render_all(args, gun, objs, root, ammo, paths, holds, info, want):
    from PIL import Image
    out = args.out
    studio = bpy.data.collections['Studio']
    rig = gk.Rig(studio)
    sc = bpy.context.scene
    gun_names = [n for n in gun.order if n != 'MagFollower']
    gobjs = [objs[n] for n in gun_names]
    objs['MagFollower'].hide_render = True
    for a in ammo.values():
        a.hide_render = True
    lo, hi = gk.world_bbox(gobjs)
    floor = gk.add_floor(studio, lo.z - 0.0005)
    files = []

    def shot(name, view, res=(1500, 900), bbox=None, **kw):
        gk.set_res(*res)
        rig.frame(bbox or (lo, hi), view, **kw)
        p = os.path.join(out, name + '.png')
        gk.render(p)
        files.append(p)
        return p

    d = info['dims']
    tri_line = 'gun FBX %d tris (+ mag %d), %d parts; L %.0f mm, H %.0f mm, W %.0f mm' % (
        info['tri_gun'] - info['tri_mag'], info['tri_mag'], len(gun_names), d['length'] * 1000, d['height'] * 1000,
        d['width'] * 1000)
    if want('01') or want('12'):
        floor.hide_render = True
        sc.render.film_transparent = True
        gk.set_res(1800, 700)
        rig.frame((lo, hi), (0, 1, 0), ortho=True, margin=1.04)
        pa = os.path.join(out, '_01_side_alpha.png')
        gk.render(pa)
        sc.render.film_transparent = False
        floor.hide_render = False
        im = Image.open(pa).convert('RGBA')
        bg = Image.new('RGBA', im.size, (226, 226, 224, 255))
        p1 = os.path.join(out, '01_side_left_ortho.png')
        Image.alpha_composite(bg, im).convert('RGB').save(p1)
        ref = args.ref or REF_DEFAULT
        if os.path.exists(ref):
            lv = level_reference(ref, os.path.join(out, '_ref_level.png'))
            pc, iou = gk.ref_compare(lv, p1, pa, os.path.join(out, '12_reference_compare.png'),
                                     title='7.62 RIFLE side profile (ref levelled %.0f deg)' % REF_ANGLE)
            info['iou'] = iou
            files.append(pc)
        gk.caption(p1, ['7.62 RIFLE - left side, orthographic (reference framing)', tri_line], color=(30, 30, 30))
        files.append(p1)
    if want('02'):
        shot('02_three_quarter_front', (0.85, 0.8, 0.38), lens=55)
    if want('03'):
        shot('03_three_quarter_back', (-0.8, -0.85, 0.45), lens=55)
    if want('04'):
        shot('04_top', (0, 0, 1), ortho=True, up=(0, 1, 0), margin=1.05, res=(1800, 600))
    if want('05'):
        shot('05_right_side', (0, -1, 0), ortho=True, margin=1.04, res=(1800, 700))
    if want('06'):
        shot('06_closeup_action', (-0.35, -1.0, 0.45), lens=70, margin=1.0,
             bbox=(V(mm(-215, -45, -65)), V(mm(60, 20, 55))))
    if want('08'):
        set_pose(objs, carrier=mm(STROKE), trigger=14.0, selector=10.0, release=-12.0, rock=-25.0, mag_out=0.03,
                 leaf=8.0)
        lo2, hi2 = gk.world_bbox(gobjs)
        p = shot('08_cycle_pose', (0.15, -1.0, 0.3), lens=60, bbox=(V(mm(-260, -50, -230)), V(mm(120, 30, 60))))
        gk.caption(p, ['carrier back 120 mm with its handle, selector AUTO (+10), trigger +14 deg, leaf +8 deg,',
                       'mag release paddle -12 deg, magazine rocked -25 deg about its front lug and coming out'])
        set_pose(objs)
    if want('07'):
        offs = {'DustCover': V((0, 0, 0.07)), 'BoltCarrier': V((0, -0.0, 0.13)), 'ChargingHandle': V((0, 0, 0)),
                'HandguardUpper': V((0, 0, 0.07)), 'HandguardLower': V((0, 0, -0.08)), 'CleaningRod': V((0, 0, -0.12)),
                'Stock': V((-0.07, 0, 0)), 'ButtPlate': V((-0.11, 0, 0)), 'PistolGrip': V((0, 0, -0.06)),
                'Selector': V((0, -0.06, 0.02)), 'Trigger': V((0, 0, -0.05)), 'MagRelease': V((0.0, 0, -0.07)),
                'Magazine': V((0.05, 0, -0.10)), 'MagRoundTop': V((0, 0, 0.035)), 'MuzzleDevice': V((0.05, 0, 0)),
                'SightRear': V((0, 0, 0.03)), 'SightFront': V((0, 0, 0.04))}
        base = {n: objs[n].matrix_basis.copy() for n in offs}
        for n, dv in offs.items():
            objs[n].matrix_basis = Matrix.Translation(dv) @ base[n]
        bpy.context.view_layer.update()
        lo2, hi2 = gk.world_bbox(gobjs)
        gk.set_res(1800, 1100)
        rig.frame((lo2, hi2), (0.25, -1, 0.3), lens=55, margin=1.08)
        p = os.path.join(out, '07_exploded.png')
        gk.render(p)
        items = []
        for n, (dx, dy) in (('Receiver', (0, 90)), ('DustCover', (0, -50)), ('BoltCarrier', (-40, -60)),
                            ('ChargingHandle', (60, -40)), ('Barrel', (40, -70)), ('MuzzleDevice', (40, 50)),
                            ('CleaningRod', (0, 40)), ('HandguardUpper', (0, -50)), ('HandguardLower', (0, 60)),
                            ('SightFront', (30, -40)), ('SightRear', (-30, -40)), ('Selector', (-60, 50)),
                            ('Trigger', (40, 40)), ('MagRelease', (-60, 40)), ('PistolGrip', (-50, 50)),
                            ('Stock', (0, 70)), ('ButtPlate', (-30, 60)), ('Magazine', (70, 40)),
                            ('MagRoundTop', (70, -30))):
            blo, bhi = gk.world_bbox([objs[n]])
            items.append((n, (blo + bhi) / 2, (dx, dy)))
        gk.label_points(p, items, size=19)
        gk.caption(p, ['exploded (right side): named parts of the FBX; moving: BoltCarrier (+ChargingHandle), '
                       'Selector, Trigger, MagRelease, Magazine, SightRear'])
        files.append(p)
        for n in offs:
            objs[n].matrix_basis = base[n]
        bpy.context.view_layer.update()
    if want('09'):
        for ob in gobjs:
            ob.hide_render = True
        mag = objs['Magazine']
        keep_par, keep = mag.parent, mag.matrix_world.copy()
        mag.parent = None
        objs['MagRoundTop'].hide_render = False
        mag.hide_render = False
        mag.matrix_world = Matrix.Translation(V((0, -0.05, 0))) @ keep
        bpy.context.view_layer.update()
        mlo, _ = gk.world_bbox([mag])
        mag.location.z -= (mlo.z - floor.location.z)
        empty = bpy.data.objects.new('MagEmptyPreview', mag.data.copy())
        studio.objects.link(empty)
        empty.matrix_world = Matrix.Translation(V((0.0, 0.06, 0))) @ mag.matrix_world
        fo = objs['MagFollower']
        fo_keep = (fo.parent, fo.matrix_world.copy())
        fo.parent = None
        fo.hide_render = False
        fo.matrix_world = Matrix.Translation(V((0.0, 0.06, 0))) @ mag.matrix_world @ \
            Matrix.Translation(-V(mm(*(MAGWELL[0], 0, MAGWELL[1])))) @ Matrix.Translation(V(mm(MAGWELL[0], 0, MAGWELL[1])))
        bpy.context.view_layer.update()
        rd, cs = ammo['Rifle_Round'], ammo['Rifle_Case']
        rd.hide_render = cs.hide_render = False
        z0 = floor.location.z + 0.00562
        rd.matrix_world = Matrix.Translation(V((0.14, 0.03, z0))) @ Matrix.Rotation(0.4, 4, 'Z')
        cs.matrix_world = Matrix.Translation(V((0.15, -0.03, z0))) @ Matrix.Rotation(-0.6, 4, 'Z')
        bpy.context.view_layer.update()
        alo, ahi = gk.world_bbox([mag, empty, rd, cs])
        gk.set_res(1500, 950)
        rig.frame((alo, ahi), (0.5, 0.9, 0.5), lens=60, margin=1.08)
        p = os.path.join(out, '09_ammo_and_magazines.png')
        gk.render(p)
        gk.caption(p, ['30-round curved steel magazine (full: top round in the lips; empty: follower up), '
                       '7.62x39 round (%d tris), spent lacquered-steel case (%d tris)' % (
                           info['tri_ammo']['Rifle_Round'], info['tri_ammo']['Rifle_Case']),
                       'mag + top round %d tris' % info['tri_mag']])
        files.append(p)
        bpy.data.objects.remove(empty)
        fo.matrix_world = fo_keep[1]
        fo.parent = fo_keep[0]
        fo.matrix_world = fo_keep[1]
        fo.hide_render = True
        mag.parent = keep_par
        mag.matrix_world = keep
        rd.hide_render = cs.hide_render = True
        for ob in gobjs:
            ob.hide_render = False
        bpy.context.view_layer.update()
    if want('10') and paths:
        saved = []
        bm_ = gk.baked_material('BakedRifle', paths['steel'])
        bw_ = gk.baked_material('BakedRifleWood', paths['wood'])
        saved += gk.swap_materials([o for o in gobjs if o.name not in WOOD_PARTS], bm_)
        saved += gk.swap_materials([objs[n] for n in WOOD_PARTS], bw_)
        p = shot('10_game_look_baked', (0.85, 0.8, 0.38), lens=55)
        gk.caption(p, ['GAME LOOK: the baked 1024 atlases only (steel + wood; Color / Normal / Roughness / '
                       'Metalness), as SurfaceAppearances'])
        gk.restore_materials(saved)
    if want('11'):
        saved = gk.swap_materials(gobjs, gk.MAT['FlatGrey'])
        p = shot('11_game_mesh', (0.85, 0.8, 0.38), lens=55)
        gk.caption(p, ['game mesh (flat grey): ' + tri_line])
        gk.restore_materials(saved)
    hold_files = []
    if holds and want('13'):
        floor.hide_render = True
        for r in holds:
            hold_files.append(render_hold(args, rig, gun, objs, root, gobjs, r))
        floor.hide_render = False
        files += hold_files
    keyf = sorted(f for f in files if os.path.basename(f)[:2].isdigit())
    if keyf:
        sheet = gk.contact_sheet(keyf, os.path.join(out, 'rifle_sheet.png'), '7.62 RIFLE (tools/guns/rifle_ak.py) - '
                                 + tri_line, cols=3)
        if not args.no_export:
            import shutil
            shutil.copy(sheet, os.path.join(args.assets, 'rifle_sheet.png'))
            if hold_files:
                gk.grid(hold_files, os.path.join(args.assets, 'rifle_holds.png'), cols=2, tw=1100, th=820,
                        title='7.62 RIFLE - solved R6 holds (front 3/4, side, hands, eye at game FOV, eye crop)')


def render_hold(args, rig, gun, objs, root, gobjs, r):
    """One stance on the R6 dummy: front 3/4, right side, a hands close-up and the eye's view (2x2 grid)."""
    import numpy as np
    e = r['_eval']
    studio = bpy.data.collections['Studio']
    dummy = gk.build_r6(studio, e['F'], name='R6_' + r['name'])
    gk.place_gun(root, e['G'])
    floor = gk.add_floor(studio, -3 * gk.STUD - 0.001, 'Ground')
    lo, hi = gk.world_bbox(dummy + gobjs)
    names = []
    res = r['residuals']
    head = [o for o in dummy if o.name.endswith('Head')][0]
    arms = [o for o in dummy if 'Arm' in o.name]
    # down-range backdrop for the eye views: a lit target wall, so the front post and the notch read in
    # silhouette against it (as the pistol's eye view)
    wall = None
    if 'sight_d' in e:
        import bmesh as _bm
        d_b = (gk.r2b_point(e['eye'] + e['sight_d'] * 10.0) - gk.r2b_point(e['eye'])).normalized()
        c_b = gk.r2b_point(e['eye']) + d_b * 7.0
        bm_ = _bm.new()
        gk.box(bm_, (0, 0, 0), (12.0, 12.0, 0.02))
        me_ = bpy.data.meshes.new('EyeWall')
        bm_.to_mesh(me_)
        bm_.free()
        if 'EyeWall' not in gk.MAT:
            m_ = gk.NB('EyeWall')
            ring = m_.mask(m_.math('ABSOLUTE', clamp=False, a=m_.math('SINE', clamp=False, a=m_.mul(m_.n('ShaderNodeVectorMath', operation='LENGTH',
                                                                          inp={0: m_.obj()}).outputs['Value'], 9.0))), 0.0, 0.25)
            col_ = m_.mixc(ring, gk.C(0.08, 0.075, 0.07), gk.C(0.62, 0.60, 0.56))
            em = m_.n('ShaderNodeEmission', {'Strength': 2.6})
            m_.l(col_, em.inputs['Color'])
            m_.l(em.outputs[0], m_.out.inputs['Surface'])
        me_.materials.append(gk.MAT['EyeWall'])
        wall = bpy.data.objects.new('EyeWall', me_)
        studio.objects.link(wall)
        z_ = V((0, 0, 1))
        x_ = z_.cross(d_b).normalized() if abs(d_b.z) < 0.99 else V((1, 0, 0))
        y_ = d_b.cross(x_)
        R_ = Matrix((x_, y_, d_b)).transposed().to_4x4()
        wall.matrix_world = Matrix.Translation(c_b) @ R_
        wall.hide_render = True
    views = [('front', (1.0, -0.8, 0.35), dict(lens=45)), ('side', (0.0, -1.0, 0.08), dict(lens=45)),
             ('close', (0.9, -0.9, 0.55), dict(lens=50)), ('eye', None, dict(lens=EYE_LENS_GAME)),
             ('eyezoom', None, dict(lens=200.0))]
    for tag, view, kw in views:
        gk.set_res(1100, 820)
        bpy.context.scene.cycles.samples = 24 if not args.quick else 8
        if view is None:
            # the solved R6 eye itself (not a point put on the sight line), game FOV (70 deg vertical) and a
            # 60 mm crop on the notch; looking along the sight line, rolled to world up: a canted gun shows tilted
            head.hide_render = True
            for o in arms:
                o.hide_render = True
            eye_b = gk.r2b_point(e['eye'])
            if tag == 'eyezoom' and 'sight_o' in e and r['name'] in ('Aim', 'Ready'):
                # the crop is the game's ADS camera: on the SightEye marker (the solved R6 eye is a few mm off
                # the line, enough to hide a 2 mm post behind the notch at this magnification)
                eye_b = gk.r2b_point(e['sight_o'])
            if 'sight_d' in e and r['name'] in ('Aim', 'Ready'):
                tgt = gk.r2b_point((e['sight_o'] if tag == 'eyezoom' else e['eye']) + e['sight_d'] * 4.0)
                if wall is not None:
                    wall.hide_render = False
            else:
                G = e['G']
                tgt = gk.r2b_point((G @ np.append(gk.model_to_gun(mm(-60, 0, -40)), 1.0))[:3])
            rig.cam.data.type = 'PERSP'
            rig.cam.data.sensor_fit = 'HORIZONTAL'
            rig.cam.data.sensor_width = 36
            rig.cam.data.shift_x = rig.cam.data.shift_y = 0.0
            rig.cam.data.lens = kw['lens'] if r['name'] in ('Aim', 'Ready') or tag == 'eye' else 35
            rig.cam.data.clip_start = 0.01
            rig.aim(rig.cam, eye_b, tgt)
            rig.place_lights((lo + hi) / 2, 2.5)
            if r['name'] in ('Aim', 'Ready'):
                # back-lit sights: the bright wall behind, the studio lights dimmed, so the post and the notch
                # read as dark silhouettes (as a real sight picture against the sky)
                for ln, lo_ in rig.lights.items():
                    lo_.data.energy *= 0.35
        elif tag == 'close':
            head.hide_render = False
            G = e['G']
            c = gk.r2b_point((G @ np.append(gk.model_to_gun(mm(-60, 0, -10)), 1.0))[:3])
            rig.frame((c - V((0.36, 0.36, 0.26)), c + V((0.36, 0.36, 0.26))), view, margin=1.0, **kw)
        else:
            head.hide_render = False
            rig.frame((lo, hi), view, margin=1.08, **kw)
        p = os.path.join(args.out, '_hold_%s_%s.png' % (r['name'], tag))
        gk.render(p)
        if wall is not None:
            wall.hide_render = True
        names.append(p)
    if wall is not None:
        bpy.data.objects.remove(wall)
    head.hide_render = False
    for o in arms:
        o.hide_render = False
    txt = '%s: cant %.1f, root roll %.1f, neck %s; blade %.0f, lean %.0f, wrist %.0f deg; left hand %.3f stud%s%s; bore yaw/pitch %s' % (
        r['name'], res.get('cantDeg', 0.0), r['pose']['Root'][2], tuple(round(c) for c in r['pose']['Neck']),
        r['pose']['Root'][1], r['pose']['Root'][0], res['wristDeg'], res.get('left', float('nan')),
        ('; eye to sight line %.3f stud' % res['eyeToSightLine']) if r['name'] == 'Aim' else '',
        ('; butt %s' % res['buttInTorso']) if 'buttInTorso' in res and r['name'] != 'ReloadMag' else '',
        res['boreYawPitch'])
    out = gk.grid(names, os.path.join(args.out, '13_hold_%s.png' % r['name']), cols=3, tw=1100, th=820,
                  labels=['front 3/4', 'right side', 'hands close-up', 'R6 eye, game FOV 70 deg (head, arms hidden)',
                          '200 mm crop on the notch (Aim/Ready: ADS camera on SightEye)'], title=txt)
    for o in dummy:
        bpy.data.objects.remove(o)
    bpy.data.objects.remove(floor)
    root.matrix_world = Matrix()
    bpy.context.view_layer.update()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='/tmp/rifle_out')
    ap.add_argument('--assets', default=os.path.join(ROOT, 'assets', 'guns', 'Rifle'))
    ap.add_argument('--samples', type=int, default=40)
    ap.add_argument('--only', default='')
    ap.add_argument('--quick', action='store_true')
    ap.add_argument('--no-bake', action='store_true')
    ap.add_argument('--no-holds', action='store_true')
    ap.add_argument('--no-render', action='store_true')
    ap.add_argument('--no-export', action='store_true')
    ap.add_argument('--ref', default='')
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)
    only = set(args.only.split(',')) if args.only else None

    def want(k):
        return only is None or k in only

    gk.reset_scene()
    gk.build_materials()
    build_rifle_materials()
    gk.setup_render(16 if args.quick else args.samples, (1600, 1000))
    studio_world()
    col = bpy.data.collections.new('Rifle')
    bpy.context.scene.collection.children.link(col)
    studio = bpy.data.collections.new('Studio')
    bpy.context.scene.collection.children.link(studio)
    gun = build_model()
    objs = gun.build(col)
    for n, ob in objs.items():
        ob['origin'] = list(gun.parts[n].origin - (gun.parts[gun.parts[n].parent].origin if gun.parts[n].parent
                                                   else V((0, 0, 0))))
    root = bpy.data.objects.new('GunRoot', None)
    col.objects.link(root)
    for n, ob in objs.items():
        if ob.parent is None:
            ob.parent = root
    empties = gun.empties(studio)
    for e_ in empties.values():
        e_.hide_render = True
    ammo = build_case_round(col)
    tris = gk.tri_counts(objs)
    gun_parts = [n for n in gun.order if n != 'MagFollower']
    tri_gun = sum(tris[n] for n in gun_parts)
    tri_mag = tris['Magazine'] + tris['MagRoundTop']
    tri_ammo = gk.tri_counts(ammo)
    print('TRIS', tris, 'gun FBX total', tri_gun, 'mag', tri_mag, 'ammo', tri_ammo, flush=True)
    lo, hi = gk.world_bbox([objs[n] for n in gun_parts])
    dims = {'length': round(hi.x - lo.x, 4), 'barrel': round(mm(BARREL_L), 4), 'height': round(hi.z - lo.z, 4),
            'width': round(hi.y - lo.y, 4), 'carrierStroke': mm(STROKE),
            'sightRadius': round(mm(FRONT_POST[0] - REAR_NOTCH[0]), 4)}
    gun.dims = dims
    print('DIMS', dims, flush=True)

    steel = [objs[n] for n in gun.order if n not in WOOD_PARTS]
    wood = [objs[n] for n in WOOD_PARTS]
    gk.uv_atlas(steel, margin=0.003)
    gk.uv_atlas(wood, margin=0.004)
    gk.uv_atlas(list(ammo.values()), margin=0.01)
    paths = None
    if not args.no_bake:
        paths = {'steel': gk.bake_atlas(steel, args.assets, GID, size=1024, samples=12),
                 'wood': gk.bake_atlas(wood, args.assets, GID + '_Wood', size=1024, samples=12)}
        gk.bake_atlas(list(ammo.values()), args.assets, GID + '_Ammo', size=256, samples=12)
    if not args.no_export:
        gk.export_fbx([objs[n] for n in gun_parts], os.path.join(args.assets, GID + '.fbx'))
        gk.export_fbx([ammo['Rifle_Case']], os.path.join(args.assets, 'Rifle_Case.fbx'))
        gk.export_fbx([ammo['Rifle_Round']], os.path.join(args.assets, 'Rifle_Round.fbx'))
        mag = objs['Magazine']
        saved, par = mag.matrix_world.copy(), mag.parent
        mag.parent = None
        mag.matrix_world = Matrix()
        bpy.context.view_layer.update()
        gk.export_fbx([mag, objs['MagRoundTop']], os.path.join(args.assets, 'Rifle_Mag.fbx'))
        gk.export_fbx([mag, objs['MagFollower']], os.path.join(args.assets, 'Rifle_MagEmpty.fbx'))
        mag.parent = par
        mag.matrix_world = saved
        bpy.context.view_layer.update()
        gun.to_json(os.path.join(args.assets, 'rifle.markers.json'),
                    tris={**{n: tris[n] for n in gun.order}, 'gunFbx': tri_gun, 'magFbx': tri_mag,
                          'case': tri_ammo['Rifle_Case'], 'round': tri_ammo['Rifle_Round']})
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(args.out, 'rifle_ak.blend'))

    holds = None
    if not args.no_holds:
        holds, _ = solve_holds(gun, os.path.join(HERE, 'rifle_ak_holds.json'))
    if args.no_render:
        return
    render_all(args, gun, objs, root, ammo, paths, holds,
               dict(tris=tris, tri_gun=tri_gun, tri_mag=tri_mag, tri_ammo=tri_ammo, dims=dims), want)


if __name__ == '__main__':
    main()
