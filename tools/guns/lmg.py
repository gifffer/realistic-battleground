#!/usr/bin/env python3
"""The 5.56 LMG: a belt-fed 5.56x45 light machine gun in the class of the reference photo (M249 / Minimi
"para" type): a stamped steel receiver (recessed side panels with pressed ribs, rivets, two big take-down pins,
a generic stamp plate), its hollow pressed feed cover hinged at the FRONT on the trunnion and latched at the
rear (picatinny rail on top carrying a generic 4x prism sight on a low throw-lever base; the feed lever, pawls
and guides under it), the feed tray in an open feed well, a bottom ejection port (cases fall straight down) and
a link port on the right side, a non-reciprocating charging handle in a slot on the right, a polymer trigger
group with a large guard and an AR-type pistol grip, a quick-change barrel with its folding carry handle, gas
block, front sight and a slotted flash hider, an aluminium rail handguard over the gas cylinder with a vertical
foregrip, a folding bipod on canted hinges (legs folded back under the handguard either side of the foregrip,
swinging down and out), a telescoping single-tube stock with a cheek comb, a solid polymer butt and rubber pad, a
200-round soft drum pouch (round padded cordura bag in fine digital camo, binding tape, compression strap, polymer
adapter hooked under the receiver, hung left of the bottom ejection port) with a visible belt of linked rounds
hanging outside the left wall up into the feed tray.  The tan sling is a
separate rest-pose model (Lmg_Sling) and two markers (SlingFront / SlingRear).  Original generic design: no
logos, no copied markings.

Builds the model from code (tools/guns/gunkit.py), follows the Model contract (docs/firearms/ARCHITECTURE.md
§5, FeedCover row amended: front hinge), bakes three atlases (metal + polymer 1024, soft goods 1024, ammo 512)
for Roblox SurfaceAppearances, exports the FBXs and the markers JSON to assets/guns/Lmg/, solves the R6 holds
(lmg_holds.json next to this script: Aim, Ready, HighReady, LowReady, HipCarry, SprintCarry, ObstructedHigh,
ObstructedLow, BeltReload, Bipod) and renders the review set.

Real-world class dimensions (M249 para type): overall length 893 mm (stock extended; 790 collapsed), barrel
349 mm, height 280 mm (carry handle top to grip bottom, without optic, pouch or bipod), 7.1 kg + 3.0 kg for a
full 200-round pouch.  5.56x45 round 57.4 mm, M27-type link pitch ~10.2 mm.  Coordinates below are millimetres
in model space (+X muzzle, +Y the gun's left, +Z up; origin on the bore at the breech face).

Moving parts (ARCHITECTURE §5.2): FeedCover (+ child Optic, OpticLens) +70 deg about +Y at its FRONT hinge
(rear edge rises); FeedTray -20 deg; ChargingHandle slides -X 140 mm; Stock slides +X 100 mm (collapsed);
BipodLegL/R -90 deg about their canted axes (+Y tilted 22 deg toward +-Z, JSON hinges); Trigger +12 deg; AmmoPouch
detaches at PouchMount; Belt01..Belt12 shown / hidden by the round count (Belt01 = the round on the feed tray).

Usage:
  /home/user/z-anatomy/venv/bin/python -I tools/guns/lmg.py --out DIR [--assets assets/guns/Lmg]
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
GID = 'Lmg'
REF_DEFAULT = '/tmp/claude-0/-home-user-realistic-battleground/e6e0272e-0bb1-5036-b293-d501c4bfb630/scratchpad/guns/refs/lmg.png'


def mm(*a):
    """mm -> metres (a number, a point or a list of 2D points)."""
    if len(a) == 1 and isinstance(a[0], (int, float)):
        return a[0] * 0.001
    if len(a) == 1:
        return [(p[0] * 0.001, p[1] * 0.001) for p in a[0]]
    return tuple(c * 0.001 for c in a)


def sec_yz(cz, top, bot, hy, r_top, r_bot, n=3):
    """A closed (y, z) cross-section: rounded rectangle from z = bot to top, half width hy."""
    hz = (top - bot) / 2
    cz = (top + bot) / 2
    s = gk.rrect2(cz, 0.0, hz, hy, r_pos=r_top, r_neg=r_bot, n=n)
    return [(y, z) for z, y in s]


def rot_y(piv, deg):
    p = V(piv)
    return Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, 'Y') @ Matrix.Translation(-p)


# --------------------------------------------------------------------------------------
# layout (mm, model space)
# --------------------------------------------------------------------------------------
BARREL_L = 349.0                  # breech face -> crown
MUZZLE_X = 395.0                  # front of the flash hider
BUTT_X = -498.0                   # rear face of the butt pad (stock extended)
REC_X = (-235.0, 78.0)            # receiver rear / front (trunnion)
REC_TOP, REC_BOT, REC_HY = 22.0, -40.0, 28.0
WELL = (-112.0, 30.0, 3.0, 24.0)  # the feed well under the cover: x0, x1, floor z, half width (receiver open on top)
COVER_X = (-122.0, 38.0)
COVER_TOP = 48.0
# the cover is hinged at its FRONT (on the trunnion, as the real class) and latched at the rear by the rear
# sight; it opens rear edge up: +Y, 0 -> +COVER_OPEN (ARCHITECTURE §5.2, amended by the LMG review)
COVER_PIVOT = (34.0, 0.0, 30.0)
COVER_OPEN = 70.0
TRAY_PIVOT = (-80.0, 0.0, 6.0)
HG_X = (116.0, 252.0)             # rail handguard
HG_TOP, HG_BOT, HG_HY = 16.0, -40.0, 25.0
GAS_Z = -27.0
# vertical foregrip on the handguard's bottom rail (the reference photo's second strongest shape after the drum):
# polymer, 26 mm wide, from the rail clamp down 100 mm, its bottom raked 8 deg forward
FG_TOP = (188.0, 0.0, -50.0)
FG_BOT = (202.0, 0.0, -150.0)
FG_HY = 13.0
# folding bipod on the gas cylinder: two canted hinges (the real class), legs folded back under the handguard
# straddling the foregrip at rest, swinging down AND out (22 deg splay) when deployed
BIPOD_PIVOT = (300.0, 0.0, -46.0)  # the marker (yoke centre); each leg pivots at y = +-BIPOD_Y
BIPOD_Y = 21.0
BIPOD_LEG = 228.0                  # hinge axis -> foot contact
SPLAY = 22.0
TRIG_PIVOT = (-120.0, 0.0, -50.0)
CH_X, CH_Z, CH_STROKE = 42.0, -7.0, 140.0       # charging handle rest x, height, travel
STOCK_TRAVEL = 100.0
RAIL_TOP = COVER_TOP + 9.4        # top of the cover rail
# 4x prism sight (generic, ACOG-class proportions): 147 mm long, objective bell 46 mm with a 7 mm sunshade,
# ocular 36 mm, both lenses recessed; mounted straight on the cover rail with a low throw-lever base
OPT_X = (-147.0, 0.0)             # ocular rim / objective (sunshade) rim
OPT_Z = 95.0                      # optical axis above the bore: the cover rail (57 mm) + a 15 mm riser base (R6 head: see README)
OPT_RELIEF = 38.0                 # eye relief behind the ocular lens
# the 200-round soft pouch: a round drum-shaped bag as the reference photo (circular camo faces, a deep rounded
# rim), its axis along Y, hung LEFT of the bottom ejection port so the falling cases clear it
DRUM_C = (-8.0, 46.0, -146.0)     # centre
DRUM_R, DRUM_D = 85.0, 88.0       # radius, depth (y)
POUCH_TOP = DRUM_C[2] + DRUM_R    # -61
STAMP_C, STAMP_W, STAMP_H = (-188.0, REC_HY + 0.2, -6.0), 58.0, 14.0   # stamp plate (left flat)
SLING_LOOP = (274.0, 14.0, GAS_Z - 4.0)
SLING_FRONT = (274.0, 14.0, GAS_Z - 11.0)   # strap attach points (bottom of the front loop / the butt swivel)
SLING_REAR = (-466.0, 0.0, -107.0)
POUCH_MOUNT = (-14.0, 12.0, -40.0)
ROUND_HEAD_X = -60.0              # case head of the belted rounds (bullet tip at -2.6)
PITCH = 10.2                      # M27-type link pitch
# the belt path in the (y, z) plane: from the feed position on the tray, out through the feed opening in the
# left wall, then hanging straight down OUTSIDE the left wall into the pouch mouth (as the photo)
BELT_PATH = [(2.0, 13.0), (16.0, 13.0), (28.0, 12.0), (36.0, 6.5), (39.5, -4.0), (40.0, -16.0), (40.0, -28.0),
             (40.0, -40.0), (40.0, -52.0), (40.0, -64.0), (40.0, -76.0)]
# bottom ejection port (right of centre) and the spent case's spawn / mean direction: down, 10 deg forward,
# 28 deg right, so the cases clear the drum (checked by check_case_sweep)
PORT = (-32.0, -18.0)             # port centre x, y
CASE_SPAWN = (-32.0, -21.0, REC_BOT - 9.0)
CASE_FWD, CASE_RIGHT = 10.0, 28.0
# hold design levers (mm)
GRIP_R = (-170.0, 0.0, -92.0)
# the neutral right "wrist" frame, from the solver's hints over Aim / Ready / LowReady / Bipod (the weld's mean
# rotation off the marker), so the solved wrists sit well inside the 25 deg limit
GRIP_R_Z = (-0.94, -0.27, -0.19)
GRIP_R_X = (-0.13, -0.20, 0.97)
GRIP_L = (196.0, 0.0, -96.0)      # the support hand on the vertical foregrip (mid height)
GRIP_L_Z = (-0.64, 0.63, 0.44)   # the support forearm's neutral direction (solver hints, all stances)
CARRY = (150.0, 0.0, 88.0)


def cheap_rail(bm, x0, x1, M=None, mi=0, pitch=10.01, slot=5.23):
    """A low-poly picatinny along X standing on z = 0 (top +Z) in the frame M: a dovetail base strip and
    simple teeth (6-point sections): about 20 triangles per tooth instead of ~100."""
    M = M or Matrix()
    t = bmesh.new()
    w = 10.6
    base = [(-w * 0.62, 0), (w * 0.62, 0), (w, 4.9), (w * 0.86, 6.2), (-w * 0.86, 6.2), (-w, 4.9)]
    gk.section_x(t, [mm(*p) for p in base], mm(x0), mm(x1), end_bevel=mm(0.8), mi=mi)
    tooth = [(-w * 0.86, 6.0), (w * 0.86, 6.0), (w * 0.80, 9.4), (-w * 0.80, 9.4)]
    n = int((x1 - x0 - 4.0) / pitch)
    start = x0 + ((x1 - x0) - n * pitch) / 2
    for i in range(n):
        a = start + i * pitch + slot / 2
        b = start + (i + 1) * pitch - slot / 2
        gk.section_x(t, [mm(*p) for p in tooth], mm(a), mm(b), mi=mi)
    gk.merge(bm, t, M)
    t.free()


# --------------------------------------------------------------------------------------
# materials beyond the kit: the pouch's digital camo cordura
# --------------------------------------------------------------------------------------

def mat_camo(name='FabricCamo'):
    """Digital camo cordura (pale grey / sand / grey-green / dark pixels, as the reference pouch): 1.6 mm pixel
    grid, clusters ~4 mm (UCP-like scale), low contrast, basket weave, crease / wrinkle relief, dirt in folds."""
    m = gk.NB(name)
    snap = m.n('ShaderNodeVectorMath', operation='SNAP')
    m.l(m.obj(), snap.inputs[0])
    snap.inputs[1].default_value = (0.0016, 0.0016, 0.0016)
    n1 = m.noise(85.0, 2.0, 0.5, vec=snap.outputs[0])
    n2 = m.noise(145.0, 2.0, 0.5, vec=snap.outputs[0])
    n3 = m.noise(200.0, 2.0, 0.5, vec=snap.outputs[0])
    c_light, c_sand = gk.C(0.150, 0.153, 0.136), gk.C(0.140, 0.124, 0.088)
    c_green, c_dark = gk.C(0.078, 0.090, 0.064), gk.C(0.050, 0.054, 0.043)
    base = m.mixc(m.mask(n1, 0.47, 0.49), c_light, c_sand)
    base = m.mixc(m.mask(n2, 0.53, 0.55), base, c_green)
    base = m.mixc(m.mask(n3, 0.60, 0.61), base, c_dark)
    w1 = m.wave(2400, kind='BANDS', direction='X')
    w2 = m.wave(2400, kind='BANDS', direction='Z')
    weave = m.add(m.mul(w1, 0.5), m.mul(w2, 0.5))
    # wrinkles: stretched noise (long soft creases, mostly vertical where the pouch hangs) + small puckers
    wr = m.mask(m.noise(9.0, 3.0, 0.55, vec=m.scaled((5.0, 5.0, 1.4))), 0.35, 0.75)
    pk = m.noise(60.0, 2.0, 0.5)
    relief = m.add(m.mul(weave, 0.25), m.mul(wr, 1.0), m.mul(pk, 0.25))
    dirt = m.mx(m.mul(m.cavity(0.010), 0.9), m.mask(m.noise(14, 6, 0.6), 0.58, 0.85))
    base = m.mixc(m.mul(dirt, 0.5), base, gk.C(0.06, 0.055, 0.045))
    base = m.mixc(m.mul(wr, 0.18), base, gk.C(0.05, 0.05, 0.042))
    fz = m.mask(m.noise(80, 3, 0.5), 0.4, 0.7)
    base = m.mixc(m.mul(fz, 0.08), base, gk.C(0.30, 0.29, 0.27))
    m.bsdf(base, 0.0, m.mixf(dirt, 0.86, 0.96), m.bump(relief, 0.45, 0.0012), extra={'Sheen Weight': 0.15,
                                                                                    'Sheen Tint': gk.C(0.5, 0.5, 0.45)})
    return m.m


def stamp_image(path):
    """The generic stamp (serial-like code + calibre), white on black, for the receiver's plate."""
    from PIL import Image, ImageDraw
    W, H = 1160, 280
    im = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(im)
    d.text((40, 22), 'RB-24581', fill=255, font=gk.font(118, bold=True))
    d.text((40, 152), 'CAL 5.56 NATO', fill=255, font=gk.font(96, bold=True))
    im.save(path)
    return path


def mat_stamp(name='Stamp', img_dir='.'):
    """The phosphate stamp plate with the engraved text, mapped by object coordinates (the Receiver's
    origin is the model origin): text = slightly brighter worn steel in the engraving, bumped in."""
    m = gk.NB(name)
    img = bpy.data.images.load(stamp_image(os.path.join(img_dir, 'lmg_stamp.png')))
    img.colorspace_settings.name = 'Non-Color'
    sep = m.n('ShaderNodeSeparateXYZ')
    m.l(m.obj(), sep.inputs[0])
    x1 = mm(STAMP_C[0] + STAMP_W / 2 - 3.0)       # seen from the left the text runs toward the butt (-X)
    z0 = mm(STAMP_C[2] - STAMP_H / 2 + 2.0)
    u = m.math('MULTIPLY', m.math('SUBTRACT', x1, sep.outputs[0], clamp=False), 1.0 / mm(STAMP_W - 6.0), clamp=False)
    v = m.math('MULTIPLY', m.math('SUBTRACT', sep.outputs[2], z0, clamp=False), 1.0 / mm(STAMP_H - 4.0), clamp=False)
    cmb = m.n('ShaderNodeCombineXYZ')
    m.l(u, cmb.inputs[0])
    m.l(v, cmb.inputs[1])
    tex = m.n('ShaderNodeTexImage', extension='CLIP', interpolation='Cubic')
    tex.image = img
    m.l(cmb.outputs[0], tex.inputs['Vector'])
    txt = tex.outputs['Color']
    base = m.mixc(m.mask(m.noise(60, 4, 0.6), 0.4, 0.8), gk.C(0.050, 0.052, 0.047), gk.C(0.062, 0.063, 0.058))
    base = m.mixc(m.mul(txt, 0.55), base, gk.C(0.16, 0.16, 0.155))
    m.bsdf(base, m.mixf(txt, 0.45, 0.85), m.mixf(txt, 0.68, 0.45), m.bump(m.mul(txt, -1.0), 0.6, 0.0003))
    return m.m


def mat_phosphate(name='SteelPhosphate', col=(0.050, 0.052, 0.047), rough=0.70, metal=0.45):
    """The LMG's stamped-steel phosphate (review M2a): the kit's phosphate look (crystalline grey-green,
    grime in recesses) WITHOUT its long white scratch dashes, which baked into pixel noise on the big flat
    receiver and cover: wear only on real edges (wider bevel radius, dim bare steel, not white), short
    faint scuffs."""
    m = gk.NB(name)
    e = m.edge(0.0012, 0.06, 0.30)
    cav = m.cavity(0.004)
    wn = m.mask(m.noise(60, 6, 0.6), 0.35, 0.60)
    wearm = m.mul(m.mul(e, wn), 0.8)
    var = m.noise(30, 5, 0.6)
    cr = m.voronoi(5000, out='Distance')
    base = m.mixc(var, gk.C(*col), gk.C(col[0] * 1.25, col[1] * 1.3, col[2] * 1.2))
    base = m.mixc(m.mul(m.mask(cr, 0.1, 0.5), 0.35), base, gk.C(col[0] * 0.7, col[1] * 0.7, col[2] * 0.7))
    r0 = m.mixf(var, rough, min(1.0, rough + 0.12))
    h = m.add(m.mul(m.mask(cr, 0.0, 0.6), 0.6), m.noise(2500, 2, 0.5))
    grime = m.mx(m.mul(cav, 0.95), m.mask(m.noise(22, 6, 0.6), 0.64, 0.85))
    base = m.mixc(m.mul(grime, 0.6), base, gk.C(0.020, 0.017, 0.013))
    scuff = m.mul(m.mask(m.noise(18, 4, 0.6, vec=m.scaled((3.0, 1.0, 1.0))), 0.70, 0.78), 0.35)
    wearm = m.mx(wearm, scuff)
    base = m.mixc(wearm, base, gk.C(0.17, 0.17, 0.165))
    rr = m.mixf(m.mul(grime, 0.6), r0, 0.75)
    rr = m.mixf(wearm, rr, 0.35)
    mt = m.mixf(wearm, metal, 0.9)
    m.bsdf(base, mt, rr, m.bump(m.add(h, m.mul(wearm, -0.3)), 0.10, 0.0003))
    return m.m


def mat_web(name='Fabric', col=(0.040, 0.044, 0.034), weave=1800):
    """Dark olive nylon webbing / binding tape: the kit's fabric without its white sheen (review M2c: the sheen
    lit the binding and the strap as a pale beige band in the renders, while the bake keeps them dark)."""
    m = gk.NB(name)
    w1 = m.wave(weave, kind='BANDS', direction='X')
    w2 = m.wave(weave, kind='BANDS', direction='Y')
    w3 = m.wave(weave, kind='BANDS', direction='Z')
    weave_h = m.add(m.mul(w1, 0.4), m.mul(w2, 0.3), m.mul(w3, 0.3))
    dirt = m.mx(m.mul(m.cavity(0.006), 0.9), m.mask(m.noise(18, 6, 0.6), 0.55, 0.85))
    base = m.mixc(m.noise(50, 4, 0.5), gk.C(*col), gk.C(col[0] * 1.3, col[1] * 1.3, col[2] * 1.25))
    base = m.mixc(m.mul(dirt, 0.5), base, gk.C(col[0] * 0.6, col[1] * 0.58, col[2] * 0.55))
    m.bsdf(base, 0.0, m.mixf(dirt, 0.86, 0.95), m.bump(weave_h, 0.35, 0.0003),
           extra={'Sheen Weight': 0.15, 'Sheen Tint': gk.C(0.30, 0.32, 0.26)})
    return m.m


def build_lmg_materials(img_dir):
    """The kit's library plus the LMG's own: FabricCamo, Stamp, Reticle; this scene's Glow is the prism sight's
    amber fibre light pipe (emission <= 1, not an LED bar), Fabric the dark olive binding / webbing."""
    gk.build_materials()
    mat_phosphate('SteelPhosphate')
    mat_camo('FabricCamo')
    mat_stamp('Stamp', img_dir=img_dir)
    gk.mat_glow('Glow', col=(1.0, 0.42, 0.06), strength=0.9)
    gk.mat_simple('Reticle', (0.03, 0.012, 0.004), 0.0, 0.5, extra={'Emission Color': gk.C(1.0, 0.45, 0.08),
                                                                    'Emission Strength': 1.0})
    mat_web('Fabric', (0.040, 0.044, 0.034))


# --------------------------------------------------------------------------------------
# receiver group (one mesh): stamped receiver, front trunnion, trigger housing, grip, guard, rear sight,
# handguard + rails, gas cylinder, bipod yoke, sling loops
# --------------------------------------------------------------------------------------

def build_receiver(gun):
    rc = gun.part('Receiver', paint='SteelPhosphate', fit=1)
    St, Bo, Ba = rc.mi('SteelPhosphate'), rc.mi('Bore'), rc.mi('SteelBare')
    Po, Ps, Al = rc.mi('Polymer'), rc.mi('PolymerStipple'), rc.mi('Aluminium')
    Sp = rc.mi('Stamp')
    bm = rc.bm
    body = bmesh.new()
    # the stamped box: 4-6 mm radius on the long top / bottom edges, 3 mm chamfer at the ends
    gk.section_x(body, mm(sec_yz(0, REC_TOP, REC_BOT, REC_HY, 4.0, 6.0, n=2)), mm(REC_X[0]), mm(REC_X[1]),
                 end_bevel=mm(3.0), mi=St)
    # front trunnion block (a little proud), rear end cap
    gk.rbox(body, mm(66.0, 0, -9.0), mm(26.0, 2 * REC_HY + 4.0, REC_TOP - REC_BOT + 4.0), mm(3.0), 1, mi=St)
    gk.rbox(body, mm(-237.0, 0, -9.0), mm(6.0, 2 * REC_HY + 3.0, REC_TOP - REC_BOT + 3.0), mm(2.0), 1, mi=St)
    cuts = []
    # ejection port in the bottom (right of centre), link port right side at tray level, charging handle slot,
    # the feed opening in the left wall at tray level (the belt enters there), the feed well under the cover
    # (open top: the tray, the bolt's feed lug and the cartridge guides show with the cover up)
    c = bmesh.new()
    gk.rbox(c, mm(PORT[0], PORT[1], REC_BOT), mm(54.0, 16.0, 26.0), mm(3.0), 1, mi=Bo)
    cuts.append(c)
    cuts.append(gk.prism_cutter(mm(gk.fillet2([(-54, 4), (-8, 4), (-8, 20), (-54, 20)], 2.5, 1)), mm(-40.0),
                                mm(-20.0), mi=Bo))
    cuts.append(gk.prism_cutter(mm(gk.fillet2([(-102, CH_Z - 4.5), (CH_X + 22, CH_Z - 4.5), (CH_X + 22, CH_Z + 4.5),
                                               (-102, CH_Z + 4.5)], 3.5, 1)), mm(-40.0), mm(-22.0), mi=Bo))
    cuts.append(gk.prism_cutter(mm(gk.fillet2([(-62, 2), (0, 2), (0, 23), (-62, 23)], 2.5, 1)), mm(20.0),
                                mm(40.0), mi=Bo))
    cuts.append(gk.prism_cutter(mm(gk.fillet2([(WELL[0], WELL[2]), (WELL[1], WELL[2]), (WELL[1], REC_TOP + 4),
                                               (WELL[0], REC_TOP + 4)], 3.0, 1)), mm(-WELL[3]), mm(WELL[3]), mi=Bo))
    gk.boolean_bm(body, cuts)
    gk.merge(bm, body)
    body.free()
    # well floor details: the bolt's feed lug and the feed ramp, dark in the well
    gk.box(bm, mm(-96.0, 0, WELL[2] + 3.0), mm(22.0, 14.0, 6.0), mi=Ba)
    gk.box(bm, mm(8.0, 0, WELL[2] + 2.0), mm(20.0, 30.0, 4.0), R=Matrix.Rotation(math.radians(-12), 3, 'Y'), mi=Ba)
    # stamped side plates: the raised reinforcing plates of the class (proud 1.2 mm, chamfered), with pressed
    # half-round stiffening ribs on them; rivets
    for sy in (1, -1):
        y = sy * (REC_HY + 0.6)
        gk.rbox(bm, mm(-172.0, y, -24.0), mm(118.0, 1.2, 24.0), mm(0.6), 1, mi=St)
        if sy < 0:
            gk.rbox(bm, mm(-188.0, y, 9.0), mm(66.0, 1.2, 16.0), mm(0.6), 1, mi=St)
        gk.cyl(bm, mm(-224.0, sy * (REC_HY + 1.0), -27.0), mm(-120.0, sy * (REC_HY + 1.0), -27.0), mm(2.6), 6,
               mi=St)
        for x in (-228.0, -100.0, 52.0, 70.0):
            gk.pin(bm, mm(x, sy * REC_HY, -35.0), (0, sy, 0), mm(2.0), proud=mm(0.9), segs=6, mi=Ba)
        for x in (56.0, 72.0):
            gk.pin(bm, mm(x, sy * (REC_HY + 2.0), 8.0), (0, sy, 0), mm(2.4), proud=mm(0.8), segs=6, mi=Ba)
    # the two big take-down pins (trigger housing to receiver), heads on the left with a detent groove, the
    # pin ends flush on the right
    for x in (-206.0, -98.0):
        gk.cyl(bm, mm(x, REC_HY + 2.4, -40.0), mm(x, -REC_HY - 1.0, -40.0), mm(3.2), 8, mi=Ba)
        gk.lathe(bm, mm([(0, 0), (0, 5.4), (2.4, 5.6), (3.0, 4.8), (3.0, 0)]), 10,
                 gk.frame_x(V(mm(x, REC_HY + 1.0, -40.0)), (0, 1, 0), up=(1, 0, 0)), mi=Ba)
    # generic stamp plate on the left rear flat (serial-like code + calibre, engraved in the material)
    gk.box(bm, mm(STAMP_C[0], STAMP_C[1] + 1.2, STAMP_C[2]), mm(STAMP_W, 0.8, STAMP_H), mi=Sp)
    # link-port spring cover (open, hinged on the port's top edge) and its hinge rod
    gk.box(bm, mm(-31.0, -REC_HY - 4.0, 23.0), mm(46.0, 9.0, 1.4), R=Matrix.Rotation(math.radians(-25), 3, 'X'),
           mi=St)
    gk.cyl(bm, mm(-56.0, -REC_HY - 0.6, 21.0), mm(-6.0, -REC_HY - 0.6, 21.0), mm(1.4), 6, mi=Ba)
    # feed-cover hinge knuckles at the FRONT (on the trunnion) and the hinge pin
    for sy in (1, -1):
        gk.rbox(bm, mm(COVER_PIVOT[0], sy * (REC_HY + 2.5), 26.0), mm(14.0, 5.0, 14.0), mm(1.5), 1, mi=St)
    gk.cyl(bm, mm(COVER_PIVOT[0], REC_HY + 5.2, COVER_PIVOT[2]), mm(COVER_PIVOT[0], -REC_HY - 5.2, COVER_PIVOT[2]),
           mm(3.0), 8, mi=Ba)
    # rear sight (folding aperture on the receiver, behind the cover) with its elevation drum (right) and the
    # windage knob (left); the cover latches against its front
    gk.rbox(bm, mm(-142.0, 0, REC_TOP + 3.0), mm(28.0, 30.0, 6.0), mm(1.5), 1, mi=St)
    rs = [(-150, 24), (-134, 24), (-136, 44), (-140, 47), (-145, 47), (-149, 44)]
    gk.profile(bm, mm(gk.fillet2(rs, 1.0, 1)), mm(14.0), holes=[mm(gk.arc2((-142.5, 39.0), 2.3, 0, 360, 8)[:-1])],
               bevel=mm(0.8), bevel_segs=0, mi=St)
    for sy in (1, -1):
        gk.box(bm, mm(-142.0, sy * 11.5, 33.0), mm(10.0, 3.0, 14.0), mi=St)
    gk.lathe(bm, mm([(0, 0), (0, 7.0), (6.6, 7.6), (7.0, 0)]), 10,
             gk.frame_x(V(mm(-142.0, -15.0, 29.0)), (0, -1, 0), up=(1, 0, 0)), mi=Ps)   # (knurl = stipple bump)
    gk.lathe(bm, mm([(0, 0), (0, 4.5), (4.0, 4.5), (4.0, 0)]), 8,
             gk.frame_x(V(mm(-142.0, 15.0, 29.0)), (0, 1, 0), up=(1, 0, 0)), mi=Ba)
    # trigger housing (polymer) with a recessed side relief, its front pivot boss, the cross-bolt safety
    th = [(-215, -36), (-92, -36), (-88, -44), (-96, -60), (-150, -62), (-208, -62), (-215, -54)]
    gk.profile(bm, mm(gk.fillet2(th, 2.0, 1, radii=[4, 3, 5, 6, 3, 6, 4])), mm(50.0), bevel=mm(4.0), bevel_segs=1,
               mi=Po)
    for sy in (1, -1):
        gk.box(bm, mm(-156.0, sy * 24.6, -49.0), mm(88.0, 1.2, 14.0), mi=Ps)
    gk.cyl(bm, mm(-104.0, 26.5, -50.0), mm(-104.0, -26.5, -50.0), mm(4.2), 8, mi=Po)
    for sy in (1, -1):
        gk.pin(bm, mm(-210.0, sy * 25.0, -48.0), (0, sy, 0), mm(3.0), proud=mm(0.8), segs=6, mi=Ba)
    # large trigger guard (gloved hand) as one moulded loop
    tg_out = [(-150, -58), (-88, -50), (-86, -62), (-92, -88), (-104, -95), (-150, -95)]
    tg_in = [(-144, -64), (-96, -58), (-95, -66), (-100, -84), (-108, -88), (-144, -88)]
    gk.profile(bm, mm(gk.fillet2(tg_out, 2.0, 1, radii=[0, 3, 4, 8, 6, 0])), mm(14.0),
               holes=[mm(gk.fillet2(tg_in, 2.0, 1, radii=[2, 3, 4, 7, 5, 3]))], bevel=mm(2.0), bevel_segs=1, mi=Po)
    # pistol grip: rounded profile with finger swells, stippled side panels, a back strap hump
    gp = [(-146, -60), (-150, -86), (-152, -100), (-148, -112), (-156, -126), (-152, -140), (-160, -154),
          (-166, -178), (-174, -186), (-206, -186), (-210, -176), (-200, -140), (-190, -100), (-186, -76),
          (-178, -60)]
    gk.profile(bm, mm(gk.fillet2(gp, 2.0, 1, radii=[3, 6, 6, 6, 6, 6, 8, 8, 6, 6, 8, 12, 12, 8, 3])), mm(31.0),
               bevel=mm(9.0), bevel_segs=1, mi=Po)
    panel = [(-158, -92), (-160, -114), (-166, -150), (-172, -174), (-198, -174), (-192, -140), (-182, -100),
             (-178, -88)]
    gk.profile(bm, mm(gk.fillet2(panel, 3.0, 1)), mm(32.4), bevel=mm(1.0), bevel_segs=0, mi=Ps)
    # rail handguard (aluminium): body with vents in its lower corners, a full top rail, ladder rail covers
    # (polymer) on the sides as the photo, the bottom rail carrying the vertical foregrip
    hg = bmesh.new()
    gk.section_x(hg, mm(sec_yz(0, HG_TOP, HG_BOT, HG_HY, 7.0, 7.0, n=2)), mm(HG_X[0]), mm(HG_X[1]),
                 end_bevel=mm(2.0), mi=Al)
    cuts = []
    for k in range(4):
        x = HG_X[0] + 26.0 + k * 28.0
        for sy in (1, -1):
            c = bmesh.new()
            gk.box(c, mm(x, sy * HG_HY, -33.0), mm(16.0, 14.0, 6.0), R=Matrix.Rotation(math.radians(-45 * sy), 3, 'X'),
                   mi=Bo)
            cuts.append(c)
    gk.boolean_bm(hg, cuts)
    gk.merge(bm, hg)
    hg.free()
    cheap_rail(bm, HG_X[0] + 4.0, HG_X[1] - 4.0, Matrix.Translation(mm(0, 0, HG_TOP - 0.5)), mi=Al)
    # bottom rail: the dovetail strip only (teeth where the foregrip does not cover them would not be seen
    # behind the folded legs)
    gk.rbox(bm, mm((HG_X[0] + HG_X[1]) / 2, 0, HG_BOT - 3.0), mm(HG_X[1] - HG_X[0] - 8.0, 19.0, 6.4), mm(1.2), 1,
            mi=Al)
    for sy in (1, -1):
        # ladder rail cover on the side rail: a flat strip with five grip ribs
        gk.rbox(bm, mm(HG_X[0] + 72.0, sy * (HG_HY + 2.0), -10.0), mm(104.0, 4.0, 15.0), mm(1.4), 1, mi=Po)
        for k in range(6):
            gk.box(bm, mm(HG_X[0] + 32.0 + k * 16.0, sy * (HG_HY + 4.2), -10.0), mm(4.0, 1.2, 13.0), mi=Po)
        for x in (HG_X[0] + 12.0, HG_X[1] - 10.0):
            gk.pin(bm, mm(x, sy * (HG_HY - 0.5), 6.0), (0, sy, 0), mm(2.4), proud=mm(0.7), segs=6, mi=Ba)
    # the vertical foregrip: rail clamp, a slightly tapered polymer body with three finger ridges at the front,
    # a flared bottom cap
    gk.rbox(bm, mm(FG_TOP[0], 0, HG_BOT - 6.5), mm(40.0, 24.0, 9.0), mm(2.0), 1, mi=Po)
    gk.cyl(bm, mm(FG_TOP[0] - 10.0, 12.6, HG_BOT - 6.0), mm(FG_TOP[0] - 10.0, 15.2, HG_BOT - 6.0), mm(3.0), 6, mi=Ba)
    ax = (V(FG_BOT) - V(FG_TOP)).normalized()
    fg = [(0.0, 15.0), (14.0, 14.6), (60.0, 14.0), (92.0, 15.0), (98.0, 16.6), (101.0, 16.0), (102.0, 0.0)]
    Mfg = gk.frame_x(V(mm(*FG_TOP)) + ax * mm(-2.0), tuple(ax), up=(1, 0, 0))
    gk.lathe(bm, mm([(x, r) for x, r in fg]), 10, Mfg @ Matrix.Diagonal((1.0, FG_HY / 15.0, 1.0, 1.0)), mi=Po)
    for k in range(3):
        c0 = V(mm(*FG_TOP)) + ax * mm(28.0 + k * 20.0) + V((mm(13.5), 0, 0))
        gk.cyl(bm, c0 + V((0, mm(-9.0), 0)), c0 + V((0, mm(9.0), 0)), mm(3.4), 6, mi=Ps)
    # handguard rear collar against the trunnion, the lower link to the trunnion
    gk.rbox(bm, mm(HG_X[0] - 6.0, 0, -12.0), mm(14.0, 2 * HG_HY - 2.0, HG_TOP - HG_BOT - 4.0), mm(3.0), 1, mi=St)
    gk.rbox(bm, mm(97.0, 0, -24.0), mm(40.0, 30.0, 30.0), mm(3.0), 1, mi=St)
    # gas cylinder in front of the handguard, its regulator nut, the bipod yoke clamped under its front end
    gk.cyl(bm, mm(HG_X[1] - 4.0, 0, GAS_Z), mm(318.0, 0, GAS_Z), mm(10.0), 12, mi=St)
    gk.lathe(bm, mm([(0, 0), (0, 10.5), (1.0, 11.5), (7.0, 11.5), (8.0, 10.5), (8.0, 0)]), 6,
             gk.frame_x(V(mm(318.0, 0, GAS_Z)), (1, 0, 0), up=(0, 0, 1)), mi=St)
    yoke = bipod_yoke()
    gk.merge(bm, yoke)
    yoke.free()
    # sling loop on the left of the gas cylinder (the rear swivel is under the butt, on the stock)
    gk.torus(bm, mm(*SLING_LOOP), (1, 0, 0), mm(7.0), mm(1.6), 10, 4, mi=Ba)
    gk.box(bm, mm(SLING_LOOP[0], 9.0, GAS_Z - 2.0), mm(8.0, 6.0, 10.0), mi=St)
    return rc


# --------------------------------------------------------------------------------------
# feed cover (+ optic), feed tray
# --------------------------------------------------------------------------------------

def build_cover(gun):
    cv = gun.part('FeedCover', paint='SteelPhosphate', origin=mm(*COVER_PIVOT))
    St, Ba, Bo, Al = cv.mi('SteelPhosphate'), cv.mi('SteelBare'), cv.mi('Bore'), cv.mi('Aluminium')
    bm = cv.bm
    # a pressed shell (2 mm walls, open underneath): the outer section, hollowed by a cutter
    sh = bmesh.new()
    gk.section_x(sh, mm(sec_yz(0, COVER_TOP, REC_TOP - 1.0, REC_HY + 3.0, 9.0, 1.5, n=2)), mm(COVER_X[0] + 4.0),
                 mm(COVER_X[1]), end_bevel=mm(2.5), mi=St)
    inner = gk.fillet2([(COVER_X[0] + 8.0, REC_TOP - 4.0), (COVER_X[1] - 4.0, REC_TOP - 4.0),
                        (COVER_X[1] - 4.0, COVER_TOP - 2.0), (COVER_X[0] + 8.0, COVER_TOP - 2.0)], 6.0, 1)
    gk.boolean_bm(sh, [gk.prism_cutter(mm(inner), mm(-(REC_HY + 1.0)), mm(REC_HY + 1.0), mi=Bo)])
    gk.merge(bm, sh)
    sh.free()
    # hinge eye at the FRONT, around the receiver's pin
    gk.cyl(bm, mm(COVER_PIVOT[0], REC_HY - 1.0, COVER_PIVOT[2]), mm(COVER_PIVOT[0], -REC_HY + 1.0, COVER_PIVOT[2]),
           mm(6.0), 8, mi=St)
    gk.rbox(bm, mm(COVER_PIVOT[0] - 4.0, 0, 38.0), mm(10.0, 2 * REC_HY - 2.0, 18.0), mm(3.0), 1, mi=St)
    # stamped side ribs, the latches and the latch button on the rear (free) edge, the rail on top
    for sy in (1, -1):
        gk.cyl(bm, mm(-104.0, sy * (REC_HY + 2.4), 37.0), mm(20.0, sy * (REC_HY + 2.4), 37.0), mm(2.6), 6, mi=St)
        gk.rbox(bm, mm(COVER_X[0] + 1.0, sy * (REC_HY - 3.0), 39.0), mm(8.0, 8.0, 10.0), mm(1.5), 1, mi=St)
    gk.rbox(bm, mm(COVER_X[0] + 1.0, 0, 44.0), mm(6.0, 18.0, 6.0), mm(1.5), 1, mi=Ba)
    cheap_rail(bm, COVER_X[0] + 8.0, COVER_X[1] - 6.0, Matrix.Translation(mm(0, 0, COVER_TOP - 0.6)), mi=St)
    # underneath (seen with the cover up): the feed lever riding in the cam groove, its roller, the two
    # spring-loaded feed pawls, the cartridge guide and the belt-holding pawl's spring
    gk.box(bm, mm(-48.0, 0, COVER_TOP - 4.5), mm(96.0, 26.0, 2.5), mi=Ba)          # cam plate
    gk.box(bm, mm(-60.0, 0, COVER_TOP - 8.0), mm(70.0, 7.0, 4.0),
           R=Matrix.Rotation(math.radians(22), 3, 'Z'), mi=Ba)                                    # feed lever
    gk.cyl(bm, mm(-90.0, -12.0, COVER_TOP - 6.0), mm(-90.0, -12.0, COVER_TOP - 14.0), mm(4.0), 6, mi=Ba)
    for sy in (1, -1):
        gk.rbox(bm, mm(-31.0, sy * 9.0, COVER_TOP - 14.0), mm(8.0, 5.0, 14.0), mm(1.0), 1,
                R=Matrix.Rotation(math.radians(-sy * 14), 3, 'X'), mi=Ba)                         # feed pawls
        gk.cyl(bm, mm(-36.0, sy * 9.0, COVER_TOP - 6.0), mm(-26.0, sy * 9.0, COVER_TOP - 6.0), mm(1.6), 6, mi=Ba)
    for x in (-66.0, -2.0):                                                                         # guides
        gk.rbox(bm, mm(x, 0, COVER_TOP - 11.0), mm(4.0, 2 * REC_HY - 6.0, 14.0), mm(0.8), 1, mi=St)
    op, ln, eye = build_optic(gun)
    return cv, op, ln, eye


def build_optic(gun):
    """A generic fixed 4x prism sight (ACOG-class proportions, no trademark): forged tubular body with a
    rounded top ridge carrying the fibre light pipe in its slot, elevation cap on top / windage on the right,
    ocular bell (36 mm) and objective bell (46 mm, 7 mm sunshade) with both lenses recessed, an integral low
    base with a throw-lever clamp straight on the cover rail.  Child of FeedCover."""
    x0, Z = OPT_X[0], OPT_Z
    op = gun.part('Optic', paint='Aluminium', parent='FeedCover', origin=mm(x0 + 73.0, 0, RAIL_TOP))
    Al, Ba, Gl, Bo, Ru = op.mi('Aluminium'), op.mi('SteelBare'), op.mi('Glow'), op.mi('Bore'), op.mi('Rubber')
    bm = op.bm
    X = gk.frame_x(V(mm(x0, 0, Z)), (1, 0, 0))
    prof = [(5.0, 0), (5.0, 15.0), (0.6, 15.4), (0.0, 16.2), (0.4, 18.0), (19.0, 18.0), (23.0, 16.6), (30.0, 15.2),
            (116.0, 15.2), (126.0, 20.6), (130.0, 23.0), (147.0, 23.0), (147.0, 21.6), (146.4, 21.0), (141.0, 20.7),
            (141.0, 0)]
    gk.lathe(bm, mm(prof), 14, X, mi=Al)
    # a rubber ring on the ocular (the eye side)
    gk.lathe(bm, mm([(0.2, 18.0), (0.2, 18.8), (6.0, 18.8), (6.0, 18.0)]), 14, X, closed=True, mi=Ru)
    # forged top ridge (rounded) with the fibre slot cut in it
    ridge = [(22, -4), (124, -4), (124, 8), (116, 18), (104, 21.5), (40, 21.5), (28, 18), (22, 10)]
    gk.profile(bm, mm(gk.fillet2([(x0 + x, Z + z) for x, z in ridge], 3.0, 1, radii=[1, 1, 4, 6, 6, 6, 6, 4])),
               mm(24.0), bevel=mm(7.0), bevel_segs=1, mi=Al)
    gk.box(bm, mm(x0 + 68.0, 0, Z + 21.6), mm(58.0, 4.4, 1.0), mi=Bo)                                # fibre slot
    gk.box(bm, mm(x0 + 68.0, 0, Z + 21.9), mm(56.0, 3.0, 1.0), mi=Gl)                                # light pipe
    # adjustment caps: elevation on top of the ridge front, windage on the right, knurled
    for p0, d in (((x0 + 112.0, 0, Z + 15.0), (0, 0, 1)), ((x0 + 72.0, -11.0, Z + 2.0), (0, -1, 0))):
        up = (1, 0, 0)
        gk.lathe(bm, mm([(0, 0), (0, 8.0), (8.5, 8.0), (9.5, 7.0), (9.5, 0)]), 8,
                 gk.frame_x(V(mm(*p0)), d, up=up), mi=Al)
    # integral base on the rail: clamp jaws hanging down the rail sides, recoil lug, throw lever (right)
    base = [(34, RAIL_TOP), (112, RAIL_TOP), (112, Z - 10), (102, Z - 13), (44, Z - 13), (34, Z - 10)]
    gk.profile(bm, mm(gk.fillet2([(x0 + x, z) for x, z in base], 2.0, 1, radii=[0.8, 0.8, 3, 3, 3, 3])), mm(26.0),
               bevel=mm(2.0), bevel_segs=1, mi=Al)
    for sy in (1, -1):
        gk.rbox(bm, mm(x0 + 73.0, sy * 12.0, RAIL_TOP - 3.0), mm(70.0, 3.0, 7.0), mm(1.0), 1, mi=Al)
    gk.cyl(bm, mm(x0 + 58.0, 13.5, RAIL_TOP - 3.0), mm(x0 + 58.0, -14.0, RAIL_TOP - 3.0), mm(2.6), 6, mi=Ba)
    lever = [(-16, -3), (14, -4), (17, 0), (14, 4), (-16, 3)]
    gk.profile(bm, mm(gk.fillet2([(x0 + 84.0 + x, RAIL_TOP - 2.0 + z) for x, z in lever], 1.5, 1)), mm(3.0),
               y=mm(-15.5), bevel=mm(0.8), bevel_segs=1, mi=Ba)
    gk.cyl(bm, mm(x0 + 70.0, -13.5, RAIL_TOP - 2.0), mm(x0 + 70.0, -18.0, RAIL_TOP - 2.0), mm(3.4), 6, mi=Ba)
    # lenses (recessed 5 / 6 mm) and the reticle at the ocular: chevron on a post with the BDC stadia
    ln = gun.part('OpticLens', paint='Lens', parent='Optic', origin=mm(x0 + 5.0, 0, Z))
    Le, Rt = ln.mi('Lens'), ln.mi('Reticle')
    # (radii a little under the bores so the lens rims do not z-fight with the bell lips: review M2d)
    gk.cyl(ln.bm, mm(x0 + 4.8, 0, Z), mm(x0 + 5.1, 0, Z), mm(14.5), 14, mi=Le)
    gk.cyl(ln.bm, mm(x0 + 140.2, 0, Z), mm(x0 + 140.5, 0, Z), mm(20.0), 14, mi=Le)
    xr = x0 + 4.5
    for sy in (1, -1):
        gk.box(ln.bm, mm(xr, sy * 0.95, Z - 0.95), mm(0.1, 0.45, 3.0),
               R=Matrix.Rotation(math.radians(sy * 45), 3, 'X'), mi=Rt)
    gk.box(ln.bm, mm(xr, 0, Z - 6.4), mm(0.1, 0.30, 7.0), mi=Rt)
    for k, w in enumerate((3.4, 2.6, 2.0, 1.5)):
        gk.box(ln.bm, mm(xr, 0, Z - 4.0 - k * 1.6), mm(0.1, w, 0.26), mi=Rt)
    eye = V(mm(x0 + 5.0 - OPT_RELIEF, 0, Z))
    return op, ln, eye


def build_tray(gun):
    tr = gun.part('FeedTray', paint='SteelBare', origin=mm(*TRAY_PIVOT))
    Ba, St = tr.mi('SteelBare'), tr.mi('SteelPhosphate')
    bm = tr.bm
    w = 2 * WELL[3] - 1.0
    gk.rbox(bm, mm(-35.0, 0, 6.0), mm(90.0, w, 4.0), mm(1.0), 1, mi=St)
    # cartridge guides (front and rear rails across the tray), the feed throat stop and the belt-holding pawl
    for x, h in ((-64.0, 6.0), (-10.0, 5.0)):
        gk.rbox(bm, mm(x, 0, 8.0 + h / 2), mm(5.0, w, h), mm(1.0), 1, mi=Ba)
    gk.rbox(bm, mm(-36.0, -4.0, 9.0), mm(46.0, 3.0, 2.0), mm(0.6), 1, mi=Ba)
    gk.rbox(bm, mm(-36.0, 18.0, 9.5), mm(20.0, 4.0, 3.0), mm(0.8), 1, mi=Ba)
    gk.cyl(bm, mm(TRAY_PIVOT[0], 16.0, TRAY_PIVOT[2]), mm(TRAY_PIVOT[0], -16.0, TRAY_PIVOT[2]), mm(2.2), 8, mi=Ba)
    return tr


# --------------------------------------------------------------------------------------
# barrel group: barrel, collar + carry handle, gas block, front sight, flash hider
# --------------------------------------------------------------------------------------

def build_barrel(gun):
    br = gun.part('Barrel', paint='SteelPhosphate', fit=2)
    St, Bo, Ba, Po = br.mi('SteelPhosphate'), br.mi('Bore'), br.mi('SteelBare'), br.mi('Polymer')
    bm = br.bm
    X = gk.frame_x(V((0, 0, 0)), (1, 0, 0))
    gk.lathe(bm, mm([(-4, 0), (-4, 13.0), (112, 13.5), (120, 11.0), (246, 10.4), (250, 10.0), (BARREL_L - 12, 9.2),
                     (BARREL_L, 9.0), (BARREL_L, 7.6), (BARREL_L + 4, 7.6), (BARREL_L + 4, 0)]), 12, X, mi=St)
    # collar for the handle (with its locking lever), knurled
    gk.lathe(bm, mm([(84, 0), (84, 16.0), (86, 18.0), (108, 18.0), (110, 16.0), (110, 0)]), 12, X, mi=St)
    for k in range(6):
        a = 2 * math.pi * (k + 0.5) / 6
        gk.box(bm, mm(97.0, 18.0 * math.cos(a), 18.0 * math.sin(a)), mm(18.0, 1.2, 1.2),
               R=Matrix.Rotation(a, 3, 'X'), mi=St)
    # carry handle: a post on the collar, the bar running forward (polymer grip), the front tip turned down
    path = [mm(96.0, 0, 16.0), mm(96.0, 0, 46.0), mm(100.0, 0, 66.0), mm(114.0, 0, 80.0), mm(140.0, 0, 84.0),
            mm(176.0, 0, 84.0), mm(196.0, 0, 83.0)]
    gk.sweep(bm, gk.crs(path, 3), 0, rect=(mm(12.0), mm(9.0)), upref=(0, 1, 0), mi=St)
    gp = [mm(118.0, 0, 82.0), mm(140.0, 0, 85.5), mm(176.0, 0, 85.5), mm(192.0, 0, 82.5)]
    gk.sweep(bm, gk.crs(gp, 3), mm(8.0), segs=8, mi=Po)
    for k in range(5):                                          # grip ribs (underside finger grooves)
        gk.box(bm, mm(130.0 + k * 12.0, 0, 77.6), mm(3.0, 13.0, 2.2), mi=Po)
    gk.lathe(bm, mm([(0, 0), (0, 6.5), (3.0, 7.5), (6.0, 6.0), (8.0, 0)]), 8,
             gk.frame_x(V(mm(193.0, 0, 83.2)), (1, -0.0, -0.05)), mi=Po)         # end cap
    gk.rbox(bm, mm(96.0, 0, 34.0), mm(16.0, 16.0, 18.0), mm(2.0), 1, mi=St)      # hinge block on the collar
    gk.cyl(bm, mm(96.0, 9.0, 30.0), mm(96.0, -9.0, 30.0), mm(3.0), 6, mi=Ba)
    # gas block (round + its lug down to the gas cylinder) and the hooded front sight
    gk.lathe(bm, mm([(0, 0), (0, 14.0), (1.5, 15.5), (22.5, 15.5), (24.0, 14.0), (24.0, 0)]), 12,
             gk.frame_x(V(mm(254.0, 0, 0)), (1, 0, 0)), mi=St)
    gk.rbox(bm, mm(266.0, 0, -15.0), mm(22.0, 20.0, 22.0), mm(2.0), 1, mi=St)
    gk.pin(bm, mm(262.0, 15.5, -4.0), (0, 1, 0), mm(2.2), proud=mm(0.4), segs=6, mi=Ba, both=mm(31.0))
    fs = [(298, 9), (318, 9), (314, 30), (309, 38), (307, 38), (302, 30)]
    gk.lathe(bm, mm([(0, 0), (0, 11.5), (1.0, 12.5), (18.0, 12.5), (19.0, 11.5), (19.0, 0)]), 10,
             gk.frame_x(V(mm(298.0, 0, 0)), (1, 0, 0)), mi=St)
    for sy in (1, -1):                                          # protective ears
        ear = [(300, 8), (316, 8), (314, 40), (310, 44), (304, 44), (301, 36)]
        gk.profile(bm, mm(gk.fillet2(ear, 1.5, 1)), mm(3.0), y=mm(sy * 7.0), bevel=mm(0.6), bevel_segs=0, mi=St)
    gk.profile(bm, mm(gk.fillet2(fs, 1.0, 1)), mm(4.0), bevel=mm(0.5), bevel_segs=0, mi=St)
    gk.cyl(bm, mm(308.0, 0, 37.5), mm(308.0, 0, 41.0), mm(1.4), 6, mi=Ba)
    # flash hider: slotted cylinder (5 prongs), bore
    fh = bmesh.new()
    gk.lathe(fh, mm([(332, 6.0), (332, 10.5), (334, 11.5), (MUZZLE_X - 2, 11.5), (MUZZLE_X, 10.5), (MUZZLE_X, 7.2),
                     (332, 6.0)]), 15, X, closed=True, mi=St)
    fh.faces.ensure_lookup_table()
    for f in fh.faces:
        cc = f.calc_center_median()
        if math.hypot(cc.y, cc.z) < mm(7.5) and cc.x < mm(MUZZLE_X - 0.5):
            f.material_index = Bo
    cuts = []
    for k in range(5):
        a = 2 * math.pi * k / 5 + math.pi / 2
        d = V((0, math.cos(a), math.sin(a)))
        c = bmesh.new()
        gk.box(c, V(mm(MUZZLE_X - 13.0, 0, 0)) + d * mm(10.0), mm(30.0, 10.0, 3.4), R=Matrix.Rotation(a, 3, 'X'), mi=Bo)
        cuts.append(c)
    gk.boolean_bm(fh, cuts)
    gk.merge(bm, fh)
    fh.free()
    gk.cyl(bm, mm(BARREL_L + 4.0, 0, 0), mm(BARREL_L + 4.5, 0, 0), mm(6.5), 8, mi=Bo)
    return br


# --------------------------------------------------------------------------------------
# stock (telescoping tubes, polymer butt, rubber pad), trigger, charging handle, bipod legs
# --------------------------------------------------------------------------------------

def build_stock(gun):
    """The collapsible stock of the photo: one heavy guide tube (not the old three-rod skeleton, review M6),
    a polymer saddle with a raised cheek comb riding on it, a solid polymer butt with a rubber pad, the latch
    lever and the rear sling swivel."""
    sk = gun.part('Stock', paint='Polymer', origin=mm(REC_X[0], 0, -10.0))
    Po, Ru, St, Ba = sk.mi('Polymer'), sk.mi('Rubber'), sk.mi('SteelPhosphate'), sk.mi('SteelBare')
    bm = sk.bm
    gk.cyl(bm, mm(-470.0, 0, -6.0), mm(-214.0, 0, -6.0), mm(12.5), 10, mi=St)
    # tube guide block at the receiver end (stays visible: it is the stock's front yoke)
    gk.rbox(bm, mm(-250.0, 0, -12.0), mm(18.0, 46.0, 50.0), mm(3.0), 1, mi=Po)
    gk.box(bm, mm(-246.0, 0, -42.0), mm(16.0, 12.0, 10.0), mi=Ba)                         # latch lever
    # saddle and cheek comb (sits on the tube's top, the R6 cheek rests there in Aim)
    cheek = [(-452, -4), (-322, -4), (-316, 6), (-326, 16), (-360, 24), (-446, 26), (-454, 16)]
    gk.profile(bm, mm(gk.fillet2(cheek, 2.0, 1, radii=[3, 3, 5, 8, 8, 6, 4])), mm(40.0), bevel=mm(8.0), bevel_segs=1,
               mi=Po)
    # solid butt, its toe; rubber pad with a few ribs
    butt = [(-486, 30), (-452, 26), (-446, 12), (-444, -22), (-452, -60), (-460, -86), (-486, -92)]
    gk.profile(bm, mm(gk.fillet2(butt, 2.0, 1, radii=[6, 8, 6, 10, 10, 10, 4])), mm(44.0), bevel=mm(7.0),
               bevel_segs=1, mi=Po)
    pad = [(-498, 31), (-485, 31), (-485, -93), (-498, -93)]
    gk.profile(bm, mm(gk.fillet2(pad, 2.0, 1, radii=[8, 1, 1, 10])), mm(46.0), bevel=mm(5.0), bevel_segs=1, mi=Ru)
    for k in range(5):
        gk.box(bm, mm(-498.6, 0, 16.0 - k * 22.0), mm(1.6, 36.0, 3.4), mi=Ru)
    gk.sling_swivel(bm, mm(-466.0, 0, -88.0), axis_loop=(0, 0, -1), size=mm(20.0), mi=Ba)
    return sk


def build_trigger(gun):
    tg = gun.part('Trigger', paint='SteelPhosphate', origin=mm(*TRIG_PIVOT), fit=3)
    St = tg.mi('SteelPhosphate')
    out = [(-116.0, -47.0), (-122.0, -46.0), (-126.0, -54.0), (-131.0, -68.0), (-132.0, -80.0), (-128.0, -82.0),
           (-125.0, -72.0), (-120.0, -58.0)]
    gk.profile(tg.bm, mm(gk.fillet2(out, 1.0, 1, radii=[2, 2, 3, 3, 1.5, 1.5, 3, 3])), mm(7.0), bevel=mm(1.0),
               bevel_segs=1, mi=St)
    for k in range(4):
        gk.box(tg.bm, mm(-130.6 - k * 0.2, 0, -64.0 - k * 4.0), mm(0.6, 6.0, 0.6),
               R=Matrix.Rotation(math.radians(-15), 3, 'Y'), mi=St)
    return tg


def build_charging(gun):
    ch = gun.part('ChargingHandle', paint='SteelPhosphate', origin=mm(CH_X, -REC_HY, CH_Z))
    St, Ba = ch.mi('SteelPhosphate'), ch.mi('SteelBare')
    bm = ch.bm
    gk.rbox(bm, mm(CH_X, -REC_HY + 4.0, CH_Z), mm(36.0, 10.0, 8.0), mm(1.2), 1, mi=Ba)      # slider in the slot
    gk.cyl(bm, mm(CH_X, -REC_HY, CH_Z), mm(CH_X, -REC_HY - 12.0, CH_Z), mm(3.6), 6, mi=St)
    # folding paddle (open, horizontal), with grip grooves
    paddle = [(CH_X - 9, CH_Z - 5), (CH_X + 9, CH_Z - 5), (CH_X + 7, CH_Z + 5), (CH_X - 7, CH_Z + 5)]
    gk.profile(bm, mm(gk.fillet2([(x, z) for x, z in paddle], 1.5, 1)), mm(22.0), y=mm(-REC_HY - 21.0), bevel=mm(2.0),
               bevel_segs=1, mi=St)
    for k in range(4):
        gk.box(bm, mm(CH_X - 6.0 + k * 4.0, -REC_HY - 29.0, CH_Z + 5.2), mm(1.0, 12.0, 0.8), mi=St)
    gk.cyl(bm, mm(CH_X, -REC_HY - 9.0, CH_Z - 6.0), mm(CH_X, -REC_HY - 9.0, CH_Z + 6.0), mm(2.0), 6, mi=Ba)
    return ch


def leg_axis(sy):
    """The canted hinge axis of a bipod leg (sy = +1 left, -1 right): +Y tilted by SPLAY toward +-Z, so the
    -90 deg swing takes the leg from back along -X to down AND out by SPLAY (the real class's canted pivots;
    a pure +Y hinge with a baked splay would leave the folded legs sticking out sideways)."""
    s = math.radians(SPLAY)
    return V((0.0, math.cos(s), sy * math.sin(s)))


def leg_pivot(sy):
    return V(mm(BIPOD_PIVOT[0], sy * BIPOD_Y, BIPOD_PIVOT[2]))


def rot_axis(piv, axis, deg):
    p = V(piv)
    return Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, V(axis)) @ Matrix.Translation(-p)


def bipod_yoke():
    """The bipod yoke (part of Receiver): a clamp round the gas cylinder's front, two hinge ears per leg
    hugging the leg knuckles (no gap), the canted hinge pins."""
    t = bmesh.new()
    px, pz = BIPOD_PIVOT[0], BIPOD_PIVOT[2]
    gk.lathe(t, mm([(0, 12.5), (2.0, 14.0), (20.0, 14.0), (22.0, 12.5)]), 10,
             gk.frame_x(V(mm(px - 11.0, 0, GAS_Z)), (1, 0, 0)), mi=0)
    gk.rbox(t, mm(px, 0, pz + 15.0), mm(22.0, 2 * BIPOD_Y + 16.0, 16.0), mm(2.0), 1, mi=0)
    for sy in (1, -1):
        a = leg_axis(sy)
        c = leg_pivot(sy)
        for e in (-1, 1):                                    # the two ears either side of the knuckle
            gk.box(t, c + a * mm(e * 7.6), mm(18.0, 3.2, 18.0), R=gk.basis((1, 0, 0), a, V((1, 0, 0)).cross(a)), mi=0)
        gk.cyl(t, c - a * mm(10.0), c + a * mm(10.0), mm(2.2), 6, 0)
    return t


def build_bipod_legs(gun):
    """BipodLegL/R: knuckle (wrapping the hinge pin between the yoke ears), upper tube, the extension with its
    lock collar, the rubber foot; at rest along -X under the handguard, straddling the foregrip."""
    for side, sy in (('L', 1), ('R', -1)):
        lg = gun.part('BipodLeg' + side, paint='SteelPhosphate', origin=tuple(leg_pivot(sy)))
        st, po = lg.mi('SteelPhosphate'), lg.mi('Polymer')
        bm = lg.bm
        p = leg_pivot(sy)
        a = leg_axis(sy)
        d = V((-1.0, 0.0, 0.0))
        gk.cyl(bm, p - a * mm(5.8), p + a * mm(5.8), mm(6.5), 8, st)                  # knuckle round the pin
        gk.rbox(bm, p + d * mm(9.0), mm(16.0, 11.0, 10.0), mm(1.5), 1,
                R=gk.basis(d, a, d.cross(a)), mi=st)                                 # clevis neck
        gk.cyl(bm, p + d * mm(14.0), p + d * mm(150.0), mm(6.0), 8, st)              # upper tube
        gk.cyl(bm, p + d * mm(140.0), p + d * mm(BIPOD_LEG - 18.0), mm(4.6), 6, st)  # extension
        gk.cyl(bm, p + d * mm(138.0), p + d * mm(152.0), mm(7.4), 8, st)             # lock collar
        gk.lathe(bm, mm([(0, 0), (0, 6.0), (8.0, 8.4), (16.0, 7.0), (18.0, 0)]), 8,
                 gk.frame_x(p + d * mm(BIPOD_LEG - 18.0), tuple(d)), mi=po)          # rubber foot


def bipod_foot(sy=1):
    """Foot contact of a leg when deployed (-90 deg about its canted axis)."""
    p = leg_pivot(sy)
    tip = p + V((-mm(BIPOD_LEG), 0, 0))
    return rot_axis(p, leg_axis(sy), -90.0) @ tip


# --------------------------------------------------------------------------------------
# ammunition: belted rounds + M27-type links, case, round, link, pouch, sling
# --------------------------------------------------------------------------------------
ROUND_PROF = [(0, 0), (0, 4.8), (1.0, 4.8), (1.3, 4.1), (2.3, 4.1), (2.7, 4.75), (36.6, 4.49), (39.3, 3.17),
              (44.7, 3.17), (44.7, 2.85), (50.0, 2.62), (54.5, 1.6), (57.4, 0)]


def belted_round(bm, head, axis, out_n, mats, segs=6, link=True, nxt=None):
    """One belt segment, cheap (~96 tris; the rounds are mostly hidden in the feed opening and against the
    pouch, and their facets are smoothed by the normals, review B1 / minor): a 6-sided loaded 5.56 round (case
    head at `head`, along unit `axis`) and its M27-type link drawn as two open bands round the case (front and
    rear loops) and the strap toward the next round (`nxt` = its head point) on the belt's outer side
    `out_n`.  segs > 6: the full profile (stand-alone models)."""
    h, a, n = V(head), V(axis).normalized(), V(out_n).normalized()
    M = gk.frame_x(h, a, up=n)
    if segs > 6:
        case = ROUND_PROF[:ROUND_PROF.index((44.7, 3.17)) + 1]
        bullet = ROUND_PROF[ROUND_PROF.index((44.7, 3.17)):]
    else:
        case = [(0, 0), (0, 4.8), (36.6, 4.49), (39.3, 3.17), (44.7, 3.17)]
        bullet = [(44.7, 3.17), (54.5, 1.6), (57.4, 0)]
    gk.lathe(bm, mm(case), segs, M, mi=mats['case'])
    gk.lathe(bm, mm(bullet), segs, M, mi=mats['bullet'])
    if not link:
        return
    for x, R in ((7.4, 5.45), (31.4, 5.25)):
        gk.lathe(bm, mm([(x, R), (x + 3.2, R)]), segs, M, mi=mats['link'])
    if nxt is not None:
        q = V(nxt)
        d = (q - h)
        d -= a * d.dot(a)
        t = d.normalized()
        mid = h + d * 0.5 + n * mm(5.0) + a * mm(21.0)
        gk.box(bm, mid, (mm(26.0), d.length + mm(1.0), mm(0.9)), R=gk.basis(a, t, a.cross(t)), mi=mats['link'])


def belt_frames():
    """The 12 belt positions (case head point, outer normal) along BELT_PATH at the link pitch."""
    pts = gk.crs([V((0, y, z)) for y, z in BELT_PATH], 6)
    seg = [(pts[i + 1] - pts[i]).length for i in range(len(pts) - 1)]
    out = []
    want = [k * PITCH for k in range(12)]
    acc = 0.0
    i = 0
    for s in want:
        while i < len(seg) - 1 and acc + seg[i] < s:
            acc += seg[i]
            i += 1
        t = (s - acc) / max(1e-9, seg[i])
        p = pts[i].lerp(pts[i + 1], min(1.0, t))
        tang = (pts[i + 1] - pts[i]).normalized()
        nrm = V((0, -tang.z, tang.y))       # the belt's outer side: up on the tray, left where it hangs
        out.append((V((ROUND_HEAD_X, p.y, p.z)), nrm))
    return out


def build_belt(gun):
    fr = belt_frames()
    names = []
    for k, (h, n) in enumerate(fr):
        name = 'Belt%02d' % (k + 1)
        c = h * 0.001
        bp = gun.part(name, paint='Brass', origin=tuple(c + V((0.0223, 0, 0))))
        mats = {'case': bp.mi('Brass'), 'bullet': bp.mi('Copper'), 'link': bp.mi('SteelBlued')}
        nxt = fr[k + 1][0] * 0.001 if k + 1 < len(fr) else None
        belted_round(bp.bm, c, (1, 0, 0), n, mats, nxt=nxt)
        names.append(name)
    return names


def pouch_bottom_z(x):
    """Model z (mm) of the full drum pouch's lowest point at x (for the sling drape), None outside."""
    cx, _, cz = DRUM_C
    u = x - cx
    if abs(u) >= DRUM_R:
        return None
    return cz - math.sqrt(DRUM_R ** 2 - u * u)


# the drum's half-profile (axial y from its centre, radius), outer face (+Y) to the receiver-side face: soft
# domed faces, a rounded rim (the deep rounded rim of the photo), binding tape on the two seams
DRUM_PROF = [(-44.0, 0.0), (-43.0, 40.0), (-40.5, 66.0), (-36.0, 77.0), (-30.0, 83.0), (-22.0, 85.0), (0.0, 85.8),
             (22.0, 85.0), (30.0, 83.0), (36.0, 77.0), (40.5, 66.0), (43.0, 40.0), (44.0, 0.0)]
DRUM_TAPE = (3, 8)          # profile bands (index of their first point) wearing the binding tape


def pouch_mesh(bm, mats, empty=False):
    """The 200-round soft pouch in model space: a round drum-shaped padded bag (170 mm across, 88 deep, axis
    along Y) in fine digital camo with dark binding on its two seams, a compression strap round the rim, a
    flat MOLLE panel on the outer face, the fabric mouth collar under the feed opening (the belt dives into
    it), the polymer adapter that hooks under the receiver, a drain grommet.  empty=True (Lmg_PouchEmpty,
    review M3): the bag collapsed to ~55 % of its height, the top folded over toward the outer face, the
    faces caved in and the bottom spread; the mouth flap hanging open."""
    Ca, Fa, Po, Ba = mats['camo'], mats['web'], mats['poly'], mats['metal']
    cx, cy, cz = DRUM_C
    n = 28
    rings = []
    zbot = cz - DRUM_R
    for i, (ay, r) in enumerate(DRUM_PROF):
        ring = []
        for k in range(n if r > 0 else 1):
            ang = 2 * math.pi * k / n
            x, z = r * math.cos(ang), r * math.sin(ang)
            # soft goods: the weight sags the bag a little (lower half fuller), faint quilting noise
            yy = ay * (1.0 + 0.05 * max(0.0, -z / DRUM_R)) + 1.0 * math.sin(x * 0.11 + z * 0.05) * (abs(ay) / 44.0)
            if i in DRUM_TAPE or i - 1 in DRUM_TAPE:
                yy += math.copysign(0.5, ay) if i in DRUM_TAPE and i - 1 in DRUM_TAPE else 0.0
            px, py, pz = cx + x, cy + yy, cz + z
            if empty:
                rel = (pz - zbot) / (2 * DRUM_R)                       # 0 bottom .. 1 top
                pz = zbot + 2 * DRUM_R * (0.56 * rel - 0.10 * rel * rel * max(0.0, x / DRUM_R))
                fold = max(0.0, rel - 0.55) / 0.45                    # the top folds over toward the outer face
                py += 26.0 * fold * fold
                face = abs(ay) > 30.0
                if face:                                              # the faces cave in, a crease across
                    d = max(0.0, 1.0 - math.hypot(x / 70.0, (z + 8.0) / 60.0))
                    py -= math.copysign(14.0 * d + 3.0 * math.sin(x * 0.09) * d, ay)
                py += math.copysign(7.0 * max(0.0, 0.5 - rel), ay)    # the crushed bottom spreads
            ring.append(bm.verts.new(V(mm(px, py, pz))))
        rings.append(ring)
    faces = []
    for i in range(len(rings) - 1):
        A, B = rings[i], rings[i + 1]
        mi = Fa if i in DRUM_TAPE else Ca
        for k in range(n):
            k1 = (k + 1) % n
            if len(A) == 1:
                f = bm.faces.new((A[0], B[k1], B[k]))
            elif len(B) == 1:
                f = bm.faces.new((A[k], A[k1], B[0]))
            else:
                f = bm.faces.new((A[k], A[k1], B[k1], B[k]))
            f.material_index = mi
            faces.append(f)
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    # compression strap round the rim (webbing band, front of centre) with its ladder buckle
    sq = 0.56 if empty else 1.0
    band = []
    for k in range(n + 1):
        ang = 2 * math.pi * k / n
        rr = DRUM_R + 1.6
        x, z = rr * math.cos(ang), rr * math.sin(ang)
        pz = cz + z
        if empty:
            pz = zbot + (pz - zbot) * sq
        band.append(V(mm(cx + x, cy + 22.0, pz)))
    gk.sweep(bm, band[:-1] + [band[0]], 0, rect=(mm(1.6), mm(25.0)), upref=(0, 1, 0), mi=Fa, caps=(False, False))
    bx = V(mm(cx + DRUM_R + 2.6, cy + 22.0, zbot + DRUM_R * (0.8 if empty else 1.0)))
    gk.box(bm, bx, mm(3.0, 30.0, 18.0), mi=Po)
    # MOLLE panel on the outer (+Y) face: a flat stitched patch with three rows of loops
    yf = cy + 43.6 - (12.0 if empty else 0.0)
    zc = cz if not empty else zbot + DRUM_R * 0.52
    gk.box(bm, mm(cx, yf, zc), mm(96.0, 1.4, 66.0 * (0.6 if empty else 1.0)), mi=Ca)
    for k in range(3):
        gk.box(bm, mm(cx, yf + 1.0, zc + (k - 1) * 22.0 * (0.6 if empty else 1.0)), mm(96.0, 1.2, 4.0), mi=Fa)
    # mouth collar under the feed opening (the belt dives into it); the flap folded back (full) or hanging
    # open (empty); the polymer adapter hooking under the receiver, its latch; a brass drain grommet
    top = POUCH_TOP if not empty else zbot + 2 * DRUM_R * 0.56
    gk.rbox(bm, mm(-31.0, 40.0, top + 1.0), mm(70.0, 26.0, 14.0), mm(4.0), 1, mi=Ca)
    if not empty:
        gk.box(bm, mm(-31.0, 54.0, top - 12.0), mm(64.0, 2.4, 24.0), R=Matrix.Rotation(math.radians(10), 3, 'X'),
               mi=Ca)
        ad = [(-50, POUCH_MOUNT[2] - 1), (24, POUCH_MOUNT[2] - 1), (16, top - 2), (-42, top - 2)]
        gk.profile(bm, mm(gk.fillet2(ad, 3.0, 1)), mm(30.0), y=mm(POUCH_MOUNT[1] + 4.0), bevel=mm(3.0), bevel_segs=1,
                   mi=Po)
        gk.box(bm, mm(20.0, POUCH_MOUNT[1] + 4.0, POUCH_MOUNT[2] - 6.0), mm(8.0, 24.0, 10.0), mi=Ba)
    else:
        R = Matrix.Rotation(math.radians(-62), 3, 'X')
        hc = V(mm(-31.0, 52.0, top + 4.0))
        gk.box(bm, hc + R @ V(mm(0, 0, 12.0)), mm(64.0, 2.4, 24.0), R=R, mi=Ca)
        ad = [(-50, top + 12), (24, top + 12), (16, top - 2), (-42, top - 2)]
        gk.profile(bm, mm(gk.fillet2(ad, 3.0, 1)), mm(30.0), y=mm(POUCH_MOUNT[1] + 4.0), bevel=mm(3.0), bevel_segs=1,
                   mi=Po)
    gc = mm(cx - 40.0, cy, cz - 74.5) if not empty else mm(cx - 40.0, cy, zbot + 3.0)
    gk.torus(bm, gc, (-0.47, 0, -0.88), mm(4.0), mm(1.2), 8, 3, mi=Ba)


def build_pouch(gun):
    pc = gun.part('AmmoPouch', paint='FabricCamo', origin=mm(*POUCH_MOUNT), fit=4)   # §5.7: the fourth fit-check part
    mats = {'camo': pc.mi('FabricCamo'), 'web': pc.mi('Fabric'), 'poly': pc.mi('Polymer'), 'metal': pc.mi('SteelBare')}
    pouch_mesh(pc.bm, mats)
    return pc


def sling_path():
    """The rest-pose sling (Lmg_Sling, not in the gun FBX): a flat strap hanging under gravity in the X-Z plane
    at y = +20 mm from the front loop (SlingFront) to the butt swivel (SlingRear): a catenary that drapes
    under the pouch where it would cut through it (it rests on the pouch bottom).  Returns model-mm points."""
    f, r = SLING_FRONT, SLING_REAR
    y = 20.0
    zmin = -205.0                                   # free-hanging low point (sag ~120 mm under the chord)
    k1, k2 = math.sqrt(f[2] - zmin), math.sqrt(r[2] - zmin)
    x0 = (f[0] * k2 + r[0] * k1) / (k1 + k2)
    A = (f[2] - zmin) / (f[0] - x0) ** 2
    pts = []
    n = 48
    for i in range(n + 1):
        x = f[0] + (r[0] - f[0]) * i / n
        z = zmin + A * (x - x0) ** 2
        pb = pouch_bottom_z(x)
        if pb is not None:
            z = min(z, pb - 2.5)
        pts.append([x, y, z])
    # relax the kinks where the strap meets the pouch (a strap has stiffness)
    for _ in range(6):
        for i in range(1, n):
            zz = (pts[i - 1][2] + pts[i + 1][2]) / 2
            pb = pouch_bottom_z(pts[i][0])
            pts[i][2] = min(zz, pb - 2.5) if pb is not None else min(zz, pts[i][2] + 2.0)
    # the two ends: the strap comes straight down out of its loop / swivel
    pts = [[f[0], y - 6.0, f[2] + 4.0]] + pts + [[r[0], y - 14.0, r[2] + 4.0]]
    return [V(mm(*p)) for p in pts]


def build_sling_model(col):
    """Lmg_Sling: the tan strap with its pad, ladder-lock buckle (polymer) and keeper, at rest (gun's model
    space, origin at SlingFront)."""
    bm = bmesh.new()
    Ft, Po = 0, 1
    path = sling_path()
    gk.sweep(bm, path, 0, rect=(mm(2.4), mm(30.0)), upref=(0, 1, 0), mi=Ft, caps=(True, True))
    # padded shoulder section where it hangs lowest (wider, thicker), flat in the strap plane
    lo_i = min(range(len(path)), key=lambda i: path[i].z)
    a, b = max(1, lo_i - 14), min(len(path) - 2, lo_i + 8)
    gk.sweep(bm, path[a:b], 0, rect=(mm(6.0), mm(46.0)), upref=(0, 1, 0), mi=Ft, caps=(True, True))
    for i, (sz, mat) in ((6, ((26.0, 36.0, 5.0), Po)), (a - 3, ((12.0, 34.0, 4.0), Ft))):
        p0, p1 = path[i], path[i + 1]
        t = (p1 - p0).normalized()
        yv = (V((0, 1, 0)) - t * t.y).normalized()
        gk.rbox(bm, p0, (mm(sz[0]), mm(sz[1]), mm(sz[2])), mm(1.2), 1, R=gk.basis(t, yv, t.cross(yv)), mi=mat)
    return gk.single_object(col, 'Lmg_Sling', bm, ['FabricTan', 'Polymer'], origin=mm(*SLING_FRONT))


def build_separate(col):
    """Lmg_Case, Lmg_Round, Lmg_Link, Lmg_BeltSegment (10 linked rounds)."""
    out = {}
    bm = bmesh.new()
    gk.build_case(bm, '5.56x45', {'case': 0, 'primer': 1}, segs=8, spent=True)
    out['Lmg_Case'] = gk.single_object(col, 'Lmg_Case', bm, ['Brass', 'Nickel'], origin=gk.bm_volume_com(bm))
    bm = bmesh.new()
    gk.build_round(bm, '5.56x45', {'case': 0, 'primer': 1, 'bullet': 2}, segs=8)
    out['Lmg_Round'] = gk.single_object(col, 'Lmg_Round', bm, ['Brass', 'Nickel', 'Copper'],
                                        origin=gk.bm_volume_com(bm))
    # one link: the three loops and the strap (no round), +X = the round axis
    bm = bmesh.new()
    h = V((-0.021, 0, 0))
    for x, R in ((9.0, 5.45), (33.0, 5.25)):
        gk.torus(bm, h + V((mm(x), 0, 0)), (1, 0, 0), mm(R), mm(0.75), 10, 3, mi=0)
    gk.torus(bm, h + V((mm(21.0), mm(PITCH), 0)), (1, 0, 0), mm(5.4), mm(0.75), 10, 3, mi=0)
    gk.box(bm, h + V((mm(21.0), mm(PITCH / 2), mm(5.0))), (mm(26.0), mm(PITCH + 1), mm(0.9)), mi=0)
    out['Lmg_Link'] = gk.single_object(col, 'Lmg_Link', bm, ['SteelBlued'], origin=gk.bm_volume_com(bm))
    # a 10-round belt segment (straight, rounds along Y, belt travel +X)
    bm = bmesh.new()
    mats = {'case': 0, 'bullet': 1, 'link': 2}
    heads = [V((mm(k * PITCH), -0.022, 0)) for k in range(10)]
    for k, hp in enumerate(heads):
        belted_round(bm, hp, (0, 1, 0), (0, 0, 1), mats, nxt=heads[k + 1] if k + 1 < 10 else None)
    out['Lmg_BeltSegment'] = gk.single_object(col, 'Lmg_BeltSegment', bm, ['Brass', 'Copper', 'SteelBlued'],
                                              origin=gk.bm_volume_com(bm))
    return out


# --------------------------------------------------------------------------------------
# the model
# --------------------------------------------------------------------------------------
SOFT_PARTS = ('AmmoPouch',)


def case_dir():
    """Mean case ejection direction (model space): down, CASE_FWD forward, CASE_RIGHT to the right."""
    d = V((math.tan(math.radians(CASE_FWD)), -math.tan(math.radians(CASE_RIGHT)), -1.0))
    return d.normalized()


def check_case_sweep(n=500, seed=3):
    """Review B5: the spent cases must not pass through the pouch.  Monte-Carlo over the ARCHITECTURE §10.1/10.2
    spread (direction +-12 deg, 1-2 m/s +-15 %, spin 10-20 rev/s about a random axis within 30 deg of the case's
    short axes, gravity 9.8 m/s^2) for 0.15 s: the case (7 points along its 44.7 mm axis, radius 4.8 mm) against
    the drum (cylinder radius DRUM_R + 3, depth DRUM_D + 6).  Returns (share of cases touching, share whose
    centre touches); asserts the centre never does and fewer than 3 % graze it."""
    import numpy as np
    rng = np.random.default_rng(seed)
    mean = np.array(case_dir())
    c0 = np.array(CASE_SPAWN, float)
    dc = np.array(DRUM_C, float)
    R, H = DRUM_R + 3.0 + 4.8, DRUM_D / 2 + 3.0 + 4.8
    hits = chits = 0
    ts = np.arange(0.0, 0.15, 0.0025)
    for _ in range(n):
        a = rng.normal(size=3)
        a -= mean * a.dot(mean)
        a /= np.linalg.norm(a)
        th = math.radians(12.0) * math.sqrt(rng.random())
        d = mean * math.cos(th) + a * math.sin(th)
        v = d * rng.uniform(1.0, 2.0) * rng.uniform(0.85, 1.15) * 1000.0
        phi = rng.uniform(0, 2 * math.pi)
        ax = np.array([0.0, math.cos(phi), math.sin(phi)])
        tl = math.radians(rng.uniform(-30, 30))
        ax = ax * math.cos(tl) + np.array([1.0, 0, 0]) * math.sin(tl)
        ax /= np.linalg.norm(ax)
        w = rng.uniform(10, 20) * 2 * math.pi * rng.choice([-1, 1])
        hit = chit = False
        for t in ts:
            c = c0 + v * t + np.array([0, 0, -0.5 * 9800.0 * t * t])
            g = w * t
            u = np.array([math.cos(g), 0, 0]) + np.cross(ax, [1.0, 0, 0]) * math.sin(g) + ax * ax[0] * (1 - math.cos(g))
            for sgn in np.linspace(-1, 1, 7):
                p = c + u * 22.35 * sgn - dc
                if abs(p[1]) < H and math.hypot(p[0], p[2]) < R:
                    hit = True
                    chit = chit or sgn == 0
        hits += hit
        chits += chit
    res = (hits / n, chits / n)
    print('CASE SWEEP touching %.1f %%, centre %.1f %%' % (100 * res[0], 100 * res[1]), flush=True)
    assert res[1] == 0.0 and res[0] < 0.03, 'spent cases hit the pouch: %s' % (res,)
    return res


def build_model():
    gun = gk.GunModel(GID, mass=10.1)
    build_receiver(gun)
    build_barrel(gun)
    cv, op, ln, eye = build_cover(gun)
    build_tray(gun)
    build_stock(gun)
    build_trigger(gun)
    build_charging(gun)
    build_bipod_legs(gun)
    build_pouch(gun)
    belts = build_belt(gun)
    # hinges (ARCHITECTURE §5.2)
    gun.hinge('FeedCover', 'rotate', (0, 1, 0), COVER_OPEN, note='FRONT hinge on the trunnion (the real class); '
              '+%d lifts the rear (latch) edge; carries Optic and OpticLens' % COVER_OPEN)
    gun.hinge('FeedTray', 'rotate', (0, 1, 0), 0.0, mn=-20.0, note='rear hinge, lifts with the cover for cleaning')
    gun.hinge('ChargingHandle', 'slide', (-1, 0, 0), mm(CH_STROKE), note='right side, non-reciprocating')
    gun.hinge('Stock', 'slide', (1, 0, 0), mm(STOCK_TRAVEL), note='0 = extended (exported), +0.100 collapsed')
    for s, sy in (('L', 1), ('R', -1)):
        gun.hinge('BipodLeg' + s, 'rotate', tuple(round(c, 5) for c in leg_axis(sy)), 0.0, mn=-90.0,
                  pivot=tuple(leg_pivot(sy)),
                  note='folded back under the handguard at rest (straddling the foregrip); -90 swings the leg down '
                       'and out: the hinge axis is +Y canted %.0f deg toward %sZ (the real class\'s canted pivots), '
                       'so the deployed feet stand %.0f mm apart' % (SPLAY, '+' if sy > 0 else '-',
                                                                     2000 * bipod_foot(1).y))
    gun.hinge('Trigger', 'rotate', (0, 1, 0), 12.0)
    gun.hinge('AmmoPouch', 'slide', (0, 0, -1), mm(40.0), then='detach',
              note='unhooks down off the adapter, then free (Magazines.luau, pouch_drop)')
    for k, b in enumerate(belts):
        gun.hinge(b, 'show', (0, 0, 0), 0.0, note='visible while the rounds left >= %d; twitch one pitch along '
                  'the belt per shot' % (k + 1))
    # markers (ARCHITECTURE §5.3)
    gun.marker('Muzzle', mm(MUZZLE_X, 0, 0))
    gun.marker('EjectionPort', mm(PORT[0], PORT[1], REC_BOT - 0.5), case_dir(), (0, 0, -1))
    gun.marker('CasingSpawn', mm(*CASE_SPAWN), (1, 0, 0), (0, -0.3, -1))
    lk = V((0.0, -math.cos(math.radians(10)), -math.sin(math.radians(10))))
    gun.marker('LinkPort', mm(-31.0, -REC_HY - 0.5, 12.0), lk, (0, -1, 0))
    gun.marker('LinkSpawn', mm(-31.0, -REC_HY - 7.0, 12.0), lk, (0, 0, 1))
    gun.marker('FeedTrayEntry', mm(-31.0, REC_HY + 2.0, 13.0), (0, -1, 0), (0, 0, 1))
    gun.marker('PouchMount', mm(*POUCH_MOUNT), (0, 0, 1), (0, -1, 0))
    gun.marker('GripR', mm(*GRIP_R), GRIP_R_X, GRIP_R_Z)
    zl = V(GRIP_L_Z).normalized()
    gun.marker('GripL', mm(*GRIP_L), (V((0, 0, 1)) - zl * zl.z).normalized(), zl)
    gun.marker('Shoulder', mm(BUTT_X, 0, -31.0), (1, 0, 0), (0, 0, 1))
    de = (V((100.0, 0, 0)) - eye).normalized()
    gun.marker('SightEye', eye, de, (0, 0, 1))
    gun.marker('CoM', mm(-20.0, 8.0, -40.0))
    gun.marker('BackMount', mm(-60.0, 0, -10.0), (1, 0, 0), (0, 0, 1))
    gun.marker('ChargeHandle', mm(CH_X, -REC_HY - 24.0, CH_Z), (-1, 0, 0), (0, -1, 0))
    gun.marker('FeedCoverLatch', mm(COVER_X[0] - 2.0, 0, 46.0), (1, 0, 0), (0.3, 0, 1))    # rear (free) edge
    gun.marker('CarryHandle', mm(*CARRY), (1, 0, 0), (0, 0, 1))
    gun.marker('BipodPivot', mm(*BIPOD_PIVOT), (1, 0, 0), (0, 1, 0))
    gun.marker('BipodFoot', bipod_foot(1), (1, 0, 0), tuple(leg_axis(1)))
    gun.marker('PouchGrab', mm(DRUM_C[0], DRUM_C[1] + DRUM_D / 2 + 4.0, DRUM_C[2]), (0, 0, -1), (-0.2, 0.9, -0.3))
    zb = V((-0.20, 0.82, -0.54)).normalized()      # the support forearm laying the belt (solver hint)
    gun.marker('BeltGrab', mm(-31.0, REC_HY + 46.0, 16.0), (V((1, 0, 0)) - zb * zb.x).normalized(), zb)
    gun.marker('SlingFront', mm(*SLING_FRONT), (1, 0, 0), (0, 0, -1))
    gun.marker('SlingRear', mm(*SLING_REAR), (1, 0, 0), (0, 0, -1))
    gun.separate = {'Case': 'Lmg_Case.fbx', 'Round': 'Lmg_Round.fbx', 'Link': 'Lmg_Link.fbx',
                    'BeltSegment': 'Lmg_BeltSegment.fbx', 'Pouch': 'Lmg_Pouch.fbx', 'PouchEmpty': 'Lmg_PouchEmpty.fbx',
                    'Sling': 'Lmg_Sling.fbx'}
    off = [round(c, 4) for c in (V(mm(*DRUM_C)) - V(mm(*POUCH_MOUNT)))]
    gun.colliders = {'AmmoPouch': {'size': [round(mm(2 * DRUM_R + 6), 4), round(mm(DRUM_D + 6), 4),
                                            round(mm(2 * DRUM_R + 6), 4)],
                                   'shape': 'cylinder along model +Y (radius %.3f, length %.3f); the box is its bound'
                                            % (mm(DRUM_R + 3), mm(DRUM_D + 6)),
                                   'center': off,
                                   'axes': 'GUN MODEL AXES (+X muzzle, +Y left, +Z up), NOT the PouchMount marker '
                                           'frame; centre = PouchMount position + center (m) (review M5)',
                                   'massKg': 3.0, 'massEmptyKg': 0.35,
                                   'emptySize': [round(mm(2 * DRUM_R + 20), 4), round(mm(DRUM_D + 30), 4),
                                                 round(mm(2 * DRUM_R * 0.6), 4)]}}
    gun.extra['atlases'] = {'Lmg': 'metal + polymer + optic + bipod (Lmg_*.png)',
                            'Lmg_Soft': 'AmmoPouch (= Lmg_Pouch), Lmg_PouchEmpty, Lmg_Sling (Lmg_Soft_*.png)',
                            'Lmg_Ammo': 'Belt01..Belt12, Lmg_Case, Lmg_Round, Lmg_Link, Lmg_BeltSegment (512)'}
    gun.extra['notes'] = {
        'EjectionPort': 'cases DOWN out of the bottom port: forward %.0f deg, right %.0f deg; the drum pouch hangs '
                        'left of the port and check_case_sweep() asserts the falling cases clear it' % (
                            CASE_FWD, CASE_RIGHT),
        'LinkSpawn': 'links out of the right-side port: right, down 10 deg',
        'PouchMount': '+X = belt travel out of the pouch mouth (up); the pouch drops along -X',
        'BeltGrab': 'solver frame: the support hand laying the belt on the tray (cover open)',
        'PouchGrab': 'support hand on the pouch outer face (reload: seat / strip the pouch)',
        'Sling': 'NOT in Lmg.fbx (review): the game drives the strap between SlingFront and SlingRear (rope / Beam, '
                 'tan FabricTan); Lmg_Sling.fbx is the rest-pose strap hanging under gravity (pickup / display), '
                 'origin at SlingFront',
        'FeedCover': 'front hinge (amended contract §5.2): the latches and FeedCoverLatch are on the rear edge',
        'Belt': 'Belt01 is the round on the feed tray (fires next); Belt12 dives into the pouch mouth'}
    return gun


def gun_samples():
    """Model-space points for the solver's penetration tests (barrel, handguard, receiver, cover, optic,
    pouch, grip); the stock is left out (the pocket is wanted)."""
    pts = []
    for x in (395, 330, 270, 200, 130):
        for z in (-12, 12):
            pts.append(mm(x, 0, z))
    for x in (230, 160):
        pts.append(mm(x, 0, -44))
    pts.append(mm(150, 0, 88))
    for x in (60, 0, -60, -120, -200):
        for z in (-38, 20):
            pts.append(mm(x, 0, z))
    for x in (0, -100):
        for y in (-28, 28):
            pts.append(mm(x, y, -10))
    for x, z in ((-140, 95), (-100, 100), (-60, 100), (-20, 100), (-5, 80), (-147, 80), (-147, 62), (-142, 47),
                 (-180, 24), (-232, 22), (-232, -20), (-120, 50), (-80, 50)):
        pts.append(mm(x, 0, z))
    for y in (-18, 18):
        pts.append(mm(-147, y, 80))
    cx, cy, cz = DRUM_C
    for k in range(8):
        a = 2 * math.pi * k / 8
        for y in (cy - 30, cy + 30):
            pts.append(mm(cx + 80 * math.cos(a), y, cz + 80 * math.sin(a)))
    for k in range(4):
        pts.append(mm(FG_TOP[0] + 0.25 * k * (FG_BOT[0] - FG_TOP[0]) * 1.3, 0, -60 - 28 * k))
    pts += [mm(-185, 0, -180), mm(-150, 0, -100)]
    return pts


# --------------------------------------------------------------------------------------
# stances (ARCHITECTURE §7.3) and the LMG's hold solver
# --------------------------------------------------------------------------------------
# Torso-space shoulder pockets.  Aim: between the pectoral and the shoulder joint (review: x 0.55, not 0.72),
# with the RIGHT eye (head space +0.2 stud X, as the R6 face) on the prism line, the head rolled <= 15 deg.
POCKET_AIM = (0.55, 1.05, -0.45)
RHAND = (0.0, -0.92, -0.30)              # grip point toward the right arm block's front face (as the sniper)
SUPPORT_HAND = (0.0, -0.92, -0.40)       # the handguard rests on the front face of the left arm block
EYE_R = (0.20, 0.10, -0.42)              # the right eye in Head space
ROOT_ROLL_MAX, NECK_PITCH_MAX, NECK_ROLL_MAX, HEAD_ROLL_MAX = 3.0, 30.0, 15.0, 15.0
WRIST_MAX = 25.0
CAMS = ((0.8, 0.35, -1.0), (1.0, 0.08, 0.0))   # HRP-space view directions of the 3/4 front and right side renders
_C = dict(wrist_limit=WRIST_MAX, left_limit=35.0, w_left=14.0, head_clear=0.0, w_occl=3.0, lhand=SUPPORT_HAND,
          w_cant=4.0, lean_tol=7.0, blade_tol=15.0, front=12.0)
STANCES = [
    dict(_C, name='Aim', pitch=0.0, shoulder=True, pocket=POCKET_AIM, eye='line', eye_t=(-0.20, 0.12), w_eye=30.0,
         eye_tol=0.12, blade=-48.0, lean=-10.0, head_pitch=-8.0, w_relief=25.0, w_nod=8.0, w_dir=24.0, w_wrist=4.0, w_cant=8.0, rs_ref=(85, 0, 20),
         ls_ref=(85, 0, -45), front=14.0, w_butt=6.0),
    dict(_C, name='Ready', pitch=-10.0, shoulder=True, pocket=(0.58, 0.95, -0.45), eye='over', eye_over=0.30,
         blade=-45.0, lean=-6.0, head_pitch=-10.0, rs_ref=(75, 0, 20), ls_ref=(75, 0, -45), w_butt=6.0),
    dict(_C, name='HighReady', pitch=25.0, shoulder=True, pocket=(0.65, 0.45, -0.60), blade=-38.0, lean=-4.0,
         head_pitch=-2.0, rs_ref=(100, 0, 15), ls_ref=(100, 0, -40), w_butt=4.0, left_limit=50.0, w_occl=2.0,
         yaw_tol=12.0),
    dict(_C, name='LowReady', pitch=-36.0, yaw_tol=10.0, shoulder=True, pocket=(0.66, 0.85, -0.40), blade=-38.0, lean=-5.0,
         head_pitch=-14.0, rs_ref=(45, 0, 15), ls_ref=(45, 0, -40), w_butt=5.0, left_limit=50.0, w_occl=2.0),
    # assault carry: the butt clamped at the right side under the arm, the gun across the belly (rigid R6 arms
    # cannot reach 0.6 m ahead of the armpit with the muzzle straight forward: the muzzle turns ~35 deg left, as
    # the real carry does), the left hand on the vertical foregrip (review B6: the old carry-handle hold needed
    # its limit raised to 78 deg), the sling takes the weight
    dict(_C, name='HipCarry', pitch=-12.0, yaw=35.0, yaw_tol=12.0, shoulder=True, pocket=(0.85, 0.20, -0.45),
         w_butt=8.0, blade=-20.0, lean=-4.0, head_pitch=-6.0, head_yaw=0.0, left_limit=50.0, w_up=20.0, rs_ref=(30, 0, 10), ls_ref=(60, 0, -50), w_occl=1.0, owner='Torso'),
    dict(_C, name='SprintCarry', pitch=-34.0, yaw=42.0, yaw_tol=12.0, shoulder=False, blade=-20.0, lean=-14.0,
         head_pitch=-2.0, head_yaw=0.0, w_up=10.0, left_limit=50.0, rs_ref=(25, 0, 25), ls_ref=(45, 0, -45),
         w_occl=1.0, place=(mm(BUTT_X + 20.0, 0, -31.0), (0.90, -0.20, -0.60), 3.0)),
    # (rigid R6 arms cannot raise the muzzle much past ~25 deg with the right hand on the grip, the left on the
    # handguard and the gun clear of the head: the solved 'high port' is the gun pulled off the shoulder, muzzle
    # up-left; a clip adds the rest with the back arching)
    dict(_C, name='ObstructedHigh', pitch=25.0, yaw=20.0, yaw_tol=12.0, shoulder=False, blade=-40.0, w_left=20.0,
         place=(mm(BUTT_X + 20.0, 0, -31.0), (0.55, -0.45, -0.75), 4.0), lean=-2.0, head_pitch=8.0, rs_ref=(120, 0, 15), ls_ref=(130, 0, -40),
         left_limit=50.0, w_occl=1.0),
    dict(_C, name='ObstructedLow', pitch=-58.0, yaw=10.0, yaw_tol=12.0, shoulder=True, pocket=(0.50, 1.10, -0.45),
         w_butt=4.0, blade=-42.0, lean=-6.0, head_pitch=-22.0, rs_ref=(30, 0, 15), ls_ref=(30, 0, -40),
         left_limit=50.0, w_occl=1.0),
    dict(_C, name='BeltReload', pitch=-14.0, yaw=6.0, cant=14.0, w_cant=2.0, shoulder=True, pocket=(0.75, 0.55, -0.55),
         w_butt=4.0, blade=-40.0, lean=-10.0, lean_tol=8.0, look='FeedTrayEntry', rs_ref=(60, 0, 30),
         ls_ref=(60, 0, -30), left='BeltGrab', lhand=None, left_limit=50.0, w_up=6.0, w_occl=1.0),
    # bipod deployed on a ledge in front of the gunner (owner World): the body solved behind the planted gun,
    # leaning in, cheek on the stock, the right eye on the prism line; the support hand stays on the handguard
    dict(_C, name='Bipod', pitch=0.0, shoulder=True, pocket=POCKET_AIM, eye='line', eye_t=(-0.20, 0.12), w_eye=30.0,
         eye_tol=0.12, blade=-40.0, lean=-16.0, lean_tol=8.0, head_pitch=-10.0, w_relief=25.0, w_nod=8.0, w_dir=24.0, w_wrist=4.0, w_cant=8.0,
         rs_ref=(85, 0, 20), ls_ref=(85, 0, -45), front=16.0, w_butt=6.0, owner='World', bipod=True),
]


class LmgSolver(gk.HoldSolver):
    """gk.HoldSolver plus the review terms (the kit is frozen; the same terms as sniper.py's solver):
    - RHAND / per-stance support hand point `lhand` on the arm blocks' front faces;
    - the RIGHT eye (EYE_R) on the sight line, the head's world roll capped at 15 deg;
    - HARD bounds: Root roll <= 3, blade / lean within the stance tolerance, neck pitch <= 30, roll <= 15;
    - the Root drops so the lowest foot is on y = -3, feet level;
    - no head inside the right arm block, no gun inside the arm blocks (away from the hands), and the
      share of the gun hidden from the 3/4-front and right-side review cameras (visible fraction);
    - 'upright': the gun's up axis near world up (low carries otherwise solve upside down)."""

    def __init__(self, gun, samples, rhand=RHAND):
        import numpy as np
        super().__init__(gun, samples)
        self.rhand = tuple(rhand)
        self.cams = [np.array(c, float) / np.linalg.norm(c) for c in CAMS]
        g = np.array(self.G_grip[:3, 3])
        near = [np.array(self.m[k][:3, 3]) for k in ('GripL', 'CarryHandle', 'BeltGrab')]
        d = lambda c: np.linalg.norm(self.samples - c, axis=1)
        self.away_r = d(g) > 0.45
        self.away_l = np.all([d(c) > 0.35 for c in near], axis=0)
        # (only points AHEAD of the sight's eye point: with the 1.2-stud R6 head the receiver's rear and the
        # stock always sit inside the head block under a correct cheek weld; what must not happen is the rear
        # sight, the cover or the optic front pushing into the face)
        self.head_test = np.array([p[0] > -0.180 and not (p[0] < -0.10 and p[2] > 0.055) for p in samples])
        hp = [(0, 0, 0)] + [(sx * 0.42, sy * 0.4, sz * 0.42) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        self.head_pts = np.array([p + (1.0,) for p in hp])

    def weld(self, w):
        import numpy as np
        A = np.eye(4)
        A[:3, :3] = self.Rn @ gk.rotvec(w)
        A[:3, 3] = self.rhand
        return A @ self.G_grip_inv

    def feet(self, F):
        import numpy as np
        out = []
        for leg in ('Right Leg', 'Left Leg'):
            pts = [F[leg] @ np.array([sx * 0.5, -1.0, sz * 0.5, 1.0]) for sx in (-1, 1) for sz in (-1, 1)]
            out.append(min(float(p[1]) for p in pts))
        return out

    def pose_of(self, x, st):
        p = super().pose_of(x, st)
        lowest = min(self.feet(gk.r6_frames(p)))
        r = list(p['Root'])
        r[4] += -3.0 - lowest
        p['Root'] = tuple(r)
        return p

    @staticmethod
    def _inside(P, Finv, half):
        import numpy as np
        q = (Finv[:3, :3] @ P.T).T + Finv[:3, 3]
        return np.clip(np.min(np.array(half) - np.abs(q), axis=1), 0.0, None)

    def evaluate(self, x, st):
        import numpy as np
        e = super().evaluate(x, st)
        F = e['F']
        if st.get('lhand') is not None and e['lerr'] is not None:
            hand = F['Left Arm'] @ np.array(tuple(st['lhand']) + (1.0,))
            e['lhand'] = hand[:3]
            e['lerr'] = hand[:3] - e['lgoal']
        H = F['Head']
        e['eye'] = (H @ np.array(EYE_R + (1.0,)))[:3]
        if 'sight_o' in e:
            rel = e['eye'] - e['sight_o']
            t = float(np.dot(rel, e['sight_d']))
            e['sight_t'], e['sight_perp'] = t, rel - e['sight_d'] * t
        e['head_roll'] = math.degrees(math.asin(max(-1.0, min(1.0, float(H[1, 0])))))
        e['head_pitch'] = math.degrees(math.asin(max(-1.0, min(1.0, float(-H[1, 2])))))
        e['feet'] = self.feet(F)
        Ri = np.linalg.inv(F['Right Arm'])
        Li = np.linalg.inv(F['Left Arm'])
        hp = (H @ self.head_pts.T).T[:, :3]
        e['head_in_rarm'] = float(np.max(self._inside(hp, Ri, (0.5, 1.0, 0.5))))
        P = e['pts']
        pin = np.maximum(self._inside(P, Ri, (0.47, 0.97, 0.47)) * self.away_r,
                         self._inside(P, Li, (0.47, 0.97, 0.47)) * self.away_l)
        e['gun_in_arms'] = float(np.sqrt(np.mean(pin ** 2)))
        # review M1: the gun against the head (the R6 head as its 1.2 x 1.2 x 1.2 block, points near the butt
        # excluded: the cheek rests on the comb)
        Hi = np.linalg.inv(H)
        e['gun_in_head'] = float(np.max(self._inside(P[self.head_test], Hi, (0.6, 0.6, 0.6)))) if \
            self.head_test.any() else 0.0
        occ_all = []
        for cam in self.cams:
            occ = np.zeros(len(P))
            for part, half in (('Right Arm', (0.5, 1.0, 0.5)), ('Left Arm', (0.5, 1.0, 0.5)),
                               ('Head', (0.6, 0.6, 0.6)), ('Torso', (1.0, 1.0, 0.5))):
                Fi = np.linalg.inv(F[part])
                o = (Fi[:3, :3] @ P.T).T + Fi[:3, 3]
                dv = Fi[:3, :3] @ cam
                hv = np.array(half)
                with np.errstate(divide='ignore', invalid='ignore'):
                    t1 = (-hv - o) / dv
                    t2 = (hv - o) / dv
                tmin = np.maximum(np.nanmax(np.minimum(t1, t2), axis=1), 0.0)
                tmax = np.nanmin(np.maximum(t1, t2), axis=1)
                occ = np.maximum(occ, np.clip((tmax - tmin) / 0.15, 0.0, 1.0))
            occ_all.append(occ)
        occ = np.mean(occ_all, axis=0)
        e['occl'] = float(occ.mean())
        e['visible'] = float((occ < 0.5).mean())
        if 'sight_perp' in e and st.get('eye') == 'over':
            e['eye_over'] = float(e['eye'][1] - (e['sight_o'][1] + e['sight_d'][1] * e['sight_t']))
        if st.get('bipod'):
            e['foot'] = (e['G'] @ self.m['BipodFoot'][:, 3])[:3]
        self._last = e
        return e

    def residual(self, x, st):
        import numpy as np
        r = list(super().residual(x, st))
        e = self._last
        f = e['feet']
        r.append(abs(f[0] - f[1]) * 30.0)
        wn = float(np.linalg.norm(x[12:15]))
        r.append(max(0.0, wn - st.get('wrist_limit', WRIST_MAX) + 1.0) * 2.0)
        r.append(e['head_in_rarm'] * 60.0)
        r.append(e['gun_in_arms'] * 20.0)
        r.append(e['gun_in_head'] * 40.0)
        r.append(max(0.0, abs(e['head_roll']) - HEAD_ROLL_MAX + 1.0) * 1.5)
        if st.get('w_occl'):
            r.append(max(0.0, e['occl'] - 0.30) * st['w_occl'])
        if 'eye_over' in e:
            r.append(max(0.0, abs(e['eye_over'] - st['eye_over']) - 0.05) * 20.0)
        if st.get('eye') == 'line' and 'sight_t' in e:
            # the eye AT the prism's eye relief (the kit's own term is weak: the head drifted 0.4 stud back)
            tmin, tmax = st.get('eye_t', (-0.12, 0.12))
            r.append((max(0.0, tmin - e['sight_t']) + max(0.0, e['sight_t'] - tmax)) * st.get('w_relief', 0.0))
        if st.get('w_nod'):
            # review M1: no hard nod onto the optic (the kit's head-level term is weak against the eye terms)
            r.append(max(0.0, abs(e['head_pitch'] - st['head_pitch']) - 4.0) / 10.0 * st['w_nod'])
        w = st.get('w_up', 0.0)
        if w:
            r.append(max(0.0, 0.94 - float(e['up'][1])) * w)
        return np.array(r, float)

    def solve(self, st, starts=16, seed=1, x0=None):
        import numpy as np
        from scipy.optimize import least_squares
        rng = np.random.default_rng(seed)
        lo = np.array([-35, -75, -ROOT_ROLL_MAX, -NECK_PITCH_MAX, -80, -NECK_ROLL_MAX, -200, -200, -200, -200, -200,
                       -200, -WRIST_MAX, -WRIST_MAX, -WRIST_MAX], float)
        hi = -lo
        lo[0], hi[0] = st['lean'] - st['lean_tol'], st['lean'] + st['lean_tol']
        lo[1], hi[1] = st['blade'] - st['blade_tol'], st['blade'] + st['blade_tol']
        best = None
        base = np.array([st['lean'], st['blade'], 0, 0, -st['blade'] * 0.8, 0] +
                        list(st.get('rs_ref', (90, 0, 0))) + list(st.get('ls_ref', (90, 0, 0))) + [0, 0, 0], float)
        inits = [base] + ([np.array(x0, float)] if x0 is not None else [])
        for _ in range(starts):
            inits.append(base + rng.normal(0, 1, 15) * np.array([4, 8, 1.5, 10, 15, 4, 45, 45, 45, 45, 45, 45, 10, 10,
                                                                 10]))
        for v in inits:
            v = np.clip(v, lo + 1e-3, hi - 1e-3)
            try:
                res = least_squares(self.residual, v, args=(st,), bounds=(lo, hi), method='trf', x_scale=10.0,
                                    max_nfev=500)
            except Exception as ex:
                print('solve start failed', ex)
                continue
            if best is None or res.cost < best.cost:
                best = res
        return self.report(best.x, st, best.cost)


def check_hold(r, st):
    """The stance's hard limits: returns a list of violations."""
    res, p = r['residuals'], r['pose']
    bad = []
    lean, blade, roll = p['Root'][0], p['Root'][1], p['Root'][2]
    if abs(lean - st['lean']) > st['lean_tol'] + 0.05:
        bad.append('lean %.1f' % lean)
    if abs(blade - st['blade']) > st['blade_tol'] + 0.05:
        bad.append('blade %.1f' % blade)
    if abs(roll) > ROOT_ROLL_MAX + 0.05:
        bad.append('root roll %.1f' % roll)
    if res['wristDeg'] > st.get('wrist_limit', WRIST_MAX) + 0.3:
        bad.append('wrist %.1f' % res['wristDeg'])
    if res.get('left', 0.0) > 0.10:
        bad.append('left hand %.3f stud' % res['left'])
    if res.get('leftAngleDeg', 0.0) > st.get('left_limit', 35.0) + 0.5:
        bad.append('left arm angle %.1f' % res['leftAngleDeg'])
    if st.get('eye') == 'line' and res.get('eyeToSightLine', 0.0) > st.get('eye_tol', 0.12):
        bad.append('eye to line %.3f stud' % res['eyeToSightLine'])
    if st.get('eye') == 'over' and abs(res.get('eyeOver', 0.0) - st['eye_over']) > 0.10:
        bad.append('eye over %.3f' % res.get('eyeOver', 0.0))
    if abs(res['headRollDeg']) > HEAD_ROLL_MAX + 0.5:
        bad.append('head roll %.1f' % res['headRollDeg'])
    if abs(res['cantDeg'] - st.get('cant', 0.0)) > 8.0:
        bad.append('cant %.1f' % res['cantDeg'])
    if res.get('gunInHead', 0.0) > 0.03:
        bad.append('gun in head %.3f stud' % res['gunInHead'])
    if res['headInRightArm'] > 0.06:
        bad.append('head in right arm %.3f' % res['headInRightArm'])
    if abs(res['feetY'][0] - res['feetY'][1]) > 0.05:
        bad.append('feet %s' % (res['feetY'],))
    by = res['boreYawPitch']
    if abs(by[1] - st.get('pitch', 0.0)) > 6.0 or abs(by[0] - st.get('yaw', 0.0)) > st.get('yaw_tol', 8.0):
        bad.append('bore %s' % (by,))
    return bad


def solve_holds(gun, out_json):
    import numpy as np
    sv = LmgSolver(gun, gun_samples())
    results, failures = [], []
    only = os.environ.get('LMG_STANCES')
    for st0 in STANCES:
        if only and st0['name'] not in only.split(','):
            continue
        st = {k: v for k, v in st0.items() if k not in ('owner', 'bipod')} | ({'bipod': True} if st0.get('bipod')
                                                                                  else {})
        r = sv.solve(st, starts=int(os.environ.get('LMG_STARTS', '16')))
        e = r['_eval']
        r['grip'] = 'GripR'
        r['owner'] = st0.get('owner', 'Torso')
        r['rightHand'] = list(sv.rhand)
        r['supportHand'] = list(st.get('lhand') or gk.HAND)
        r['supportTarget'] = st.get('left', 'GripL')
        r['residuals']['cantDeg'] = round(math.degrees(math.asin(max(-1.0, min(1.0, float(-e['right'][1]))))), 1)
        r['residuals'].update({'headRollDeg': round(e['head_roll'], 1), 'headPitchDeg': round(e['head_pitch'], 1),
                               'headInRightArm': round(e['head_in_rarm'], 3), 'gunInArms': round(e['gun_in_arms'], 3),
                               'gunInHead': round(e['gun_in_head'], 3),
                               'gunVisible': round(e['visible'], 2), 'feetY': [round(v, 3) for v in e['feet']]})
        if 'eye_over' in e:
            r['residuals']['eyeOver'] = round(e['eye_over'], 3)
        if 'foot' in e:
            r['ledgeY'] = round(float(e['foot'][1]), 3)
            r['ledgeNote'] = ('HRP-space height of the deployed bipod feet: the ledge / sill top the gun stands on '
                              '(%.2f m above the floor)' % ((float(e['foot'][1]) + 3.0) * gk.STUD))
        bad = check_hold(r, st0)
        r['check'] = 'ok' if not bad else bad
        print('HOLD %-14s cost %.4f %s residuals %s pose %s wrist %s' % (
            r['name'], r['cost'], 'OK' if not bad else 'FAIL %s' % bad, r['residuals'], r['pose'], r['wrist']),
            flush=True)
        N = sv.G_grip[:3, :3] @ gk.rotvec(r['wrist']).T
        M2G = np.array(gk.M2G, float)
        print('   hint GripR x %s z %s' % (np.round(M2G.T @ N[:, 0], 3), np.round(M2G.T @ N[:, 2], 3)), flush=True)
        la = np.linalg.inv(e['G'][:3, :3]) @ e['F']['Left Arm'][:3, 1]
        print('   hint left arm (model) %s' % np.round(M2G.T @ la, 3), flush=True)
        if bad:
            failures.append((r['name'], bad))
        results.append(r)
    if only:
        return results
    gk.holds_to_json(out_json, GID, results, extra={
        'note': 'Solved by tools/guns/lmg.py (LmgSolver over gunkit.HoldSolver, the sniper review terms). R6: rigid '
                'arms; the weld (Right Arm space) is the only wrist (<= 25 deg off GripR). rightHand / supportHand '
                'are the hand points in arm space (on the blocks\' front faces). Hard limits per stance (see '
                '"check"): blade and lean within tolerance, Root roll <= 3, neck pitch <= 30 / roll <= 15, the head '
                'world roll <= 15 (cheek weld, not a dab), the RIGHT eye (head space (0.2, 0.1, -0.42)) within 0.12 '
                'stud of the prism line (Aim, Bipod), feet level on y = -3. Aim: pocket between pectoral and '
                'shoulder joint. HipCarry: M249 assault carry, butt under the right armpit, left hand on the carry '
                'handle (CarryHandle), the sling takes the weight. SprintCarry: muzzle down-left across the body. '
                'HighReady / ObstructedHigh / ObstructedLow: butt out of the pocket, muzzle up / steeply up / '
                'steeply down. BeltReload: feed cover open (+%d, front hinge), gun canted, head on the tray, left '
                'hand at BeltGrab. Bipod: owner World, bipod deployed on a ledge at ledgeY, the body leaning in '
                'behind it.' % COVER_OPEN,
        'failures': failures,
        'markers': {k: [round(c, 5) for c in gun.markers[k][0]] for k in ('GripR', 'GripL', 'SightEye', 'Shoulder',
                                                                         'CarryHandle', 'BeltGrab', 'FeedTrayEntry',
                                                                         'BipodFoot')}})
    return results


# --------------------------------------------------------------------------------------
# renders
# --------------------------------------------------------------------------------------

def place(objs, gun, name, M):
    """Pose part `name` by the model-space transform M (relative to its parent's rest frame)."""
    p = gun.parts[name]
    off = gun.parts[p.parent].origin if p.parent else V((0, 0, 0))
    objs[name].matrix_basis = Matrix.Translation(-off) @ M @ Matrix.Translation(p.origin)


def set_pose(objs, gun, cover=0.0, tray=0.0, charge=0.0, stock=0.0, bipod=0.0, trigger=0.0, pouch_out=0.0):
    place(objs, gun, 'FeedCover', rot_y(mm(*COVER_PIVOT), cover))
    place(objs, gun, 'FeedTray', rot_y(mm(*TRAY_PIVOT), tray))
    place(objs, gun, 'ChargingHandle', Matrix.Translation(V((-charge, 0, 0))))
    place(objs, gun, 'Stock', Matrix.Translation(V((stock, 0, 0))))
    place(objs, gun, 'Trigger', rot_y(mm(*TRIG_PIVOT), trigger))
    place(objs, gun, 'AmmoPouch', Matrix.Translation(V((0, 0, -pouch_out))))
    for s, sy in (('L', 1), ('R', -1)):
        place(objs, gun, 'BipodLeg' + s, rot_axis(leg_pivot(sy), leg_axis(sy), bipod))
    bpy.context.view_layer.update()


def prep_reference(src, out):
    """The reference photo upscaled, its white background made transparent, cropped."""
    import numpy as np
    from PIL import Image
    from scipy import ndimage
    im = Image.open(src).convert('RGBA')
    im = im.resize((im.width * 4, im.height * 4), Image.LANCZOS)
    a = np.array(im).astype(float)
    mask = (a[:, :, :3].sum(2) < 640) & (a[:, :, 3] > 10)
    mask = ndimage.binary_closing(mask, iterations=2)
    mask = ndimage.binary_opening(mask, iterations=1)
    a[:, :, 3] = mask * 255
    r = Image.fromarray(a.astype('uint8'))
    ys, xs = np.nonzero(mask)
    r.crop((xs.min() - 10, ys.min() - 10, xs.max() + 10, ys.max() + 10)).save(out)
    return out


def render_all(args, gun, objs, root, sep, paths, holds, info, want):
    from PIL import Image
    out = args.out
    studio = bpy.data.collections['Studio']
    rig = gk.Rig(studio)
    sc = bpy.context.scene
    gun_names = list(gun.order)
    gobjs = [objs[n] for n in gun_names]
    for a in sep.values():
        a.hide_render = True
    lo, hi = gk.world_bbox(gobjs)
    floor = gk.add_floor(studio, lo.z - 0.0005)
    files = []

    def shot(name, view, res=(1600, 900), bbox=None, **kw):
        gk.set_res(*res)
        rig.frame(bbox or (lo, hi), view, **kw)
        p = os.path.join(out, name + '.png')
        gk.render(p)
        files.append(p)
        return p

    d = info['dims']
    tri_line = 'gun FBX %d tris (pouch %d, belt %d), %d parts; L %.0f mm, H %.0f mm, W %.0f mm' % (
        info['tri_gun'], info['tris']['AmmoPouch'], info['tri_belt'], len(gun_names), d['length'] * 1000,
        d['height'] * 1000, d['width'] * 1000)
    sling = sep['Lmg_Sling']
    if want('01') or want('12'):
        # the reference shows the LEFT side (muzzle left) with the bipod deployed and the sling hanging
        set_pose(objs, gun, bipod=-90.0)
        sling.hide_render = False
        lo1, hi1 = gk.world_bbox(gobjs)
        floor.hide_render = True
        sc.render.film_transparent = True
        gk.set_res(1900, 1150)
        rig.frame((lo1, hi1), (0, 1, 0), ortho=True, margin=1.04)
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
            lv = prep_reference(ref, os.path.join(out, '_ref_level.png'))
            pc, iou = gk.ref_compare(lv, p1, pa, os.path.join(out, '12_reference_compare.png'),
                                     title='5.56 LMG left side, bipod down (photo is a slight 3/4 view)')
            info['iou'] = iou
            files.append(pc)
        gk.caption(p1, ['5.56 LMG - left side, orthographic (reference framing: bipod deployed, sling hanging)',
                        tri_line], color=(30, 30, 30))
        files.append(p1)
        set_pose(objs, gun)
    if want('02'):
        p = shot('02_three_quarter_front', (0.85, 0.8, 0.38), lens=50)
        gk.caption(p, ['3/4 front, left (Lmg_Sling shown at rest: it is a separate model, not in Lmg.fbx)'])
    sling.hide_render = True
    if want('03'):
        shot('03_three_quarter_back', (-0.8, -0.85, 0.45), lens=50)
    if want('04'):
        shot('04_top', (0, 0, 1), ortho=True, up=(0, 1, 0), margin=1.05, res=(1900, 600))
    if want('05'):
        sling.hide_render = False
        shot('05_right_side', (0, -1, 0), ortho=True, margin=1.04, res=(1900, 1000))
        sling.hide_render = True
    if want('06'):
        p = shot('06_closeup_receiver', (0.45, 1.0, 0.55), lens=60, margin=1.0,
                 bbox=(V(mm(-200, -40, -130)), V(mm(120, 90, 140))))
        gk.caption(p, ['receiver, left side: front-hinged feed cover + rail, 4x prism (amber fibre pipe), stamp '
                       'plate, take-down pins, belt into the tray window, pouch adapter'])
    if want('14'):
        p = shot('14_closeup_right', (0.35, -1.0, 0.1), lens=60, margin=1.0,
                 bbox=(V(mm(-200, -60, -110)), V(mm(120, 30, 60))))
        gk.caption(p, ['right side: link port (spring cover open), charging handle in its slot, bottom ejection '
                       'port, cross-bolt safety, rear-sight elevation drum, prism throw lever'])
    if want('15'):
        set_pose(objs, gun, bipod=-90.0)
        lo3, hi3 = gk.world_bbox(gobjs)
        p = shot('15_front_bipod', (1.0, 0.0, 0.06), ortho=True, margin=1.06, res=(1200, 1000), bbox=(lo3, hi3))
        fl, fr = bipod_foot(1), bipod_foot(-1)
        gk.caption(p, ['front, bipod deployed: canted hinges, splay %.0f deg, feet %.0f mm apart, %.0f mm below the bore'
                       % (SPLAY, (fl.y - fr.y) * 1000, -fl.z * 1000), 'the drum pouch hangs left of the bottom '
                       'ejection port (cases fall to the right of it)'])
        set_pose(objs, gun)
    if want('08'):
        set_pose(objs, gun, cover=COVER_OPEN, tray=-20.0, charge=mm(CH_STROKE), stock=mm(STOCK_TRAVEL),
                 bipod=-90.0, trigger=12.0)
        p = shot('08_reload_pose', (0.35, 1.0, 0.6), lens=50, res=(1600, 1100),
                 bbox=(V(mm(-420, -60, -300)), V(mm(420, 100, 260))))
        gk.caption(p, ['belt reload pose: feed cover open +%d deg on its FRONT hinge (optic rides on it; feed lever, '
                       'pawls, guides under it), feed tray -20,' % COVER_OPEN, 'charging handle back 140 mm, stock '
                       'collapsed 100 mm, bipod down (-90), trigger +12'])
        set_pose(objs, gun)
    if want('07'):
        offs = {'FeedCover': V((0, 0, 0.10)), 'FeedTray': V((0, 0, 0.05)), 'Barrel': V((0.10, 0, 0.0)),
                'Stock': V((-0.10, 0, 0)), 'ChargingHandle': V((0, -0.09, 0)), 'Trigger': V((0, -0.03, -0.07)),
                'AmmoPouch': V((0, 0.06, -0.14)), 'BipodLegL': V((0, 0.05, -0.08)),
                'BipodLegR': V((0, -0.05, -0.08))}
        for k in range(12):
            offs['Belt%02d' % (k + 1)] = V((0, 0.04, -0.07))
        base = {n: objs[n].matrix_basis.copy() for n in offs}
        for n, dv in offs.items():
            objs[n].matrix_basis = Matrix.Translation(dv) @ base[n]
        bpy.context.view_layer.update()
        lo2, hi2 = gk.world_bbox(gobjs)
        gk.set_res(1900, 1150)
        rig.frame((lo2, hi2), (0.25, 1, 0.35), lens=50, margin=1.06)
        p = os.path.join(out, '07_exploded.png')
        gk.render(p)
        items = []
        for n, (dx, dy) in (('Receiver', (0, 70)), ('Barrel', (40, -60)), ('FeedCover', (-40, -50)),
                            ('Optic', (40, -50)), ('OpticLens', (-60, -30)), ('FeedTray', (-70, -20)),
                            ('Stock', (0, -60)), ('ChargingHandle', (60, -30)), ('Trigger', (-30, 50)),
                            ('AmmoPouch', (60, 40)), ('Belt06', (70, -20)),
                            ('BipodLegL', (40, 40))):
            blo, bhi = gk.world_bbox([objs[n]])
            items.append((n, (blo + bhi) / 2, (dx, dy)))
        gk.label_points(p, items, size=19)
        gk.caption(p, ['exploded (left side): the named parts of Lmg.fbx; moving: FeedCover (+Optic, OpticLens), '
                       'FeedTray, ChargingHandle, Stock, Trigger, BipodLegL/R, AmmoPouch, Belt01..12'])
        files.append(p)
        for n in offs:
            objs[n].matrix_basis = base[n]
        bpy.context.view_layer.update()
    if want('09'):
        for ob in gobjs:
            ob.hide_render = True
        shown = []
        for n, ob in sep.items():
            if n == 'Lmg_Sling':
                continue
            ob.hide_render = False
            shown.append(ob)
        z0 = floor.location.z
        lay = {'Lmg_Pouch': (V((0.0, 0.0, 0)), 0.0), 'Lmg_PouchEmpty': (V((0.0, -0.20, 0)), 0.3),
               'Lmg_BeltSegment': (V((0.17, 0.02, 0)), 1.2), 'Lmg_Link': (V((0.16, -0.10, 0)), 0.6),
               'Lmg_Case': (V((0.20, -0.14, 0)), -0.4), 'Lmg_Round': (V((0.22, -0.07, 0)), 0.3)}
        keep = {n: sep[n].matrix_world.copy() for n in lay}
        for n, (pos, rz) in lay.items():
            ob = sep[n]
            ob.matrix_world = Matrix.Translation(pos) @ Matrix.Rotation(rz, 4, 'Z')
            bpy.context.view_layer.update()
            blo, _ = gk.world_bbox([ob])
            ob.location.z += z0 - blo.z
        bpy.context.view_layer.update()
        alo, ahi = gk.world_bbox(shown)
        gk.set_res(1600, 1000)
        rig.frame((alo, ahi), (0.55, 0.85, 0.6), lens=55, margin=1.06)
        p = os.path.join(out, '09_pouch_belt_ammo.png')
        gk.render(p)
        ta = info['tri_sep']
        gk.caption(p, ['200-round pouch full (%d tris) and empty / slumped (%d), 10-round belt segment (%d), '
                       'M27-type link (%d), 5.56 round (%d), spent brass case (%d)' % (
                           ta['Lmg_Pouch'], ta['Lmg_PouchEmpty'], ta['Lmg_BeltSegment'], ta['Lmg_Link'],
                           ta['Lmg_Round'], ta['Lmg_Case'])])
        files.append(p)
        for n in lay:
            sep[n].matrix_world = keep[n]
            sep[n].hide_render = True
        for ob in gobjs:
            ob.hide_render = False
        bpy.context.view_layer.update()
    if want('10') and paths:
        mats = {k: gk.baked_material('BakedLmg_' + k, v) for k, v in paths.items()}
        saved = []
        saved += gk.swap_materials([objs[n] for n in gun_names if n in SOFT_PARTS], mats['soft'])
        saved += gk.swap_materials([objs[n] for n in gun_names if n.startswith('Belt')], mats['ammo'])
        saved += gk.swap_materials([objs[n] for n in gun_names if n not in SOFT_PARTS and not n.startswith('Belt')],
                                   mats['metal'])
        p = shot('10_game_look_baked', (0.85, 0.8, 0.38), lens=50)
        gk.caption(p, ['GAME LOOK: the baked atlases only (metal 1024, soft 1024, ammo 512; Color / Normal / '
                       'Roughness / Metalness), as SurfaceAppearances'])
        gk.restore_materials(saved)
    if want('11'):
        saved = gk.swap_materials(gobjs, gk.MAT['FlatGrey'])
        p = shot('11_game_mesh', (0.85, 0.8, 0.38), lens=50)
        gk.caption(p, ['game mesh (flat grey): ' + tri_line])
        gk.restore_materials(saved)
    hold_files = []
    if holds and want('13'):
        floor.hide_render = True
        pick = os.environ.get('LMG_RENDER_HOLDS')
        for r in holds:
            if pick and r['name'] not in pick.split(','):
                continue
            hold_files.append(render_hold(args, rig, gun, objs, root, gobjs, r))
        floor.hide_render = False
        files += hold_files
    keyf = sorted(f for f in files if os.path.basename(f)[:2].isdigit())
    if keyf:
        sheet = gk.contact_sheet(keyf, os.path.join(out, 'lmg_sheet.png'), '5.56 LMG (tools/guns/lmg.py) - '
                                 + tri_line, cols=3)
        if not args.no_export:
            import shutil
            shutil.copy(sheet, os.path.join(args.assets, 'lmg_sheet.png'))
            if hold_files:
                gk.grid(hold_files, os.path.join(args.assets, 'lmg_holds.png'), cols=2, tw=1100, th=820,
                        title='5.56 LMG - solved R6 holds (front 3/4, side, hands, eye)')


def render_hold(args, rig, gun, objs, root, gobjs, r):
    import numpy as np
    e = r['_eval']
    studio = bpy.data.collections['Studio']
    dummy = gk.build_r6(studio, e['F'], name='R6_' + r['name'])
    if r['name'] == 'BeltReload':
        set_pose(objs, gun, cover=COVER_OPEN, tray=0.0)
    ledge = None
    if r['name'] == 'Bipod':
        set_pose(objs, gun, bipod=-90.0)
        fy = float(e['foot'][1])
        lb = bmesh.new()
        gk.rbox(lb, V((0, 0, 0)), (1.2 * gk.STUD, 3.2 * gk.STUD, (fy + 3.0) * gk.STUD), 0.006, 1)
        me = bpy.data.meshes.new('Ledge')
        lb.to_mesh(me)
        lb.free()
        me.materials.append(gk.MAT['Ground'])
        ledge = bpy.data.objects.new('Ledge', me)
        fb = gk.r2b_point(e['foot'])
        ledge.location = (fb.x, fb.y, (fy - (fy + 3.0) / 2) * gk.STUD - 0.0015)
        studio.objects.link(ledge)
    gk.place_gun(root, e['G'])
    floor = gk.add_floor(studio, -3 * gk.STUD - 0.001, 'Ground')
    vis = [o for o in gobjs if not o.hide_render]
    lo, hi = gk.world_bbox(dummy + vis)
    names = []
    res = r['residuals']
    head = [o for o in dummy if o.name.endswith('Head')][0]
    arms = [o for o in dummy if 'Arm' in o.name]
    scoped = r['name'] in ('Aim', 'Bipod')
    for tag, view, kw in (('front', (1.0, -0.8, 0.35), dict(lens=40)), ('side', (0.0, -1.0, 0.08), dict(lens=40)),
                          ('close', (0.9, -0.9, 0.55), dict(lens=50)), ('eye', None, {})):
        gk.set_res(1100, 820)
        bpy.context.scene.cycles.samples = 24 if not args.quick else 8
        if view is None:
            head.hide_render = True
            for o in arms:
                o.hide_render = True
            if 'sight_d' in e and scoped:
                eye_p = e['sight_o'] + e['sight_d'] * e['sight_t']
                tgt = gk.r2b_point(eye_p + e['sight_d'] * 4.0)
                eye_b = gk.r2b_point(eye_p)
            else:
                eye_b = gk.r2b_point(e['eye'])
                G = e['G']
                look = mm(-31, 20, 10) if r['name'] == 'BeltReload' else mm(60, 0, 0)
                tgt = gk.r2b_point((G @ np.append(gk.model_to_gun(look), 1.0))[:3])
            rig.cam.data.type = 'PERSP'
            rig.cam.data.lens = 45 if scoped else 30
            rig.cam.data.clip_start = 0.01
            rig.aim(rig.cam, eye_b, tgt)
            rig.place_lights((lo + hi) / 2, 2.5)
        elif tag == 'close':
            head.hide_render = False
            G = e['G']
            c = gk.r2b_point((G @ np.append(gk.model_to_gun(mm(-60, 0, -40)), 1.0))[:3])
            rig.frame((c - V((0.40, 0.40, 0.30)), c + V((0.40, 0.40, 0.30))), view, margin=1.0, **kw)
        else:
            head.hide_render = False
            rig.frame((lo, hi), view, margin=1.08, **kw)
        p = os.path.join(args.out, '_hold_%s_%s.png' % (r['name'], tag))
        gk.render(p)
        names.append(p)
    head.hide_render = False
    for o in arms:
        o.hide_render = False
    txt = '%s: blade %.0f, lean %.0f, wrist %.0f deg; left hand %.3f stud (%.0f deg)%s%s; bore yaw/pitch %s' % (
        r['name'], r['pose']['Root'][1], r['pose']['Root'][0], res['wristDeg'], res.get('left', float('nan')),
        res.get('leftAngleDeg', float('nan')),
        ('; eye to sight line %.3f stud' % res['eyeToSightLine']) if scoped else '',
        ('; butt %s' % res['buttInTorso']) if 'buttInTorso' in res else '', res['boreYawPitch'])
    txt += '; head roll %.0f; visible %.0f%%%s; %s' % (res['headRollDeg'], 100 * res['gunVisible'],
                                                      ('; ledge %.2f m' % ((r['ledgeY'] + 3) * gk.STUD)) if 'ledgeY' in r
                                                      else '', 'CHECK OK' if r['check'] == 'ok' else 'FAIL %s' % r['check'])
    out = gk.grid(names, os.path.join(args.out, '13_hold_%s.png' % r['name']), cols=2, tw=1100, th=820,
                  labels=['front 3/4', 'right side', 'hands close-up', 'eye view (head and arms hidden)'], title=txt)
    for o in dummy:
        bpy.data.objects.remove(o)
    bpy.data.objects.remove(floor)
    if ledge is not None:
        bpy.data.objects.remove(ledge)
    root.matrix_world = Matrix()
    set_pose(objs, gun)
    return out


SMOOTH = {'Barrel': 50.0, 'Optic': 50.0, 'Stock': 50.0, 'BipodLegL': 50.0, 'BipodLegR': 50.0, 'AmmoPouch': 55.0,
          'Receiver': 40.0, 'Lmg_Pouch': 55.0, 'Lmg_PouchEmpty': 55.0, 'Lmg_Sling': 50.0}


def finish_meshes(objs):
    """Review M4 and the facet minor: triangulate every mesh (beauty, fixed) BEFORE the UVs, the bake and the
    FBX, so Roblox's MikkTSpace tangents match the baked normal map (no n-gons left for the exporter to split
    its own way), and set the smoothing angle per part: the low-segment round things (8-12 sided barrels,
    legs, tubes; the 6-sided belted rounds) shade round instead of faceted, boxes and chamfers stay crisp."""
    for ob in objs:
        if ob.type != 'MESH':
            continue
        me = ob.data
        ang = 70.0 if ob.name.startswith('Belt') or ob.name in ('Lmg_BeltSegment', 'Lmg_Link') else \
            SMOOTH.get(ob.name, 32.0)
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=list(bm.edges))   # the FBX drops them: keep the JSON true
        bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method='BEAUTY', ngon_method='BEAUTY')
        bm.verts.index_update()
        seen, dup = set(), []          # duplicate faces: the FBX import keeps one (the JSON counts must match)
        for f in bm.faces:
            k = tuple(sorted(v.index for v in f.verts))
            if k in seen:
                dup.append(f)
            else:
                seen.add(k)
        if dup:
            bmesh.ops.delete(bm, geom=dup, context='FACES_ONLY')
        bm.to_mesh(me)
        bm.free()
        me.shade_smooth()
        try:
            me.set_sharp_from_angle(angle=math.radians(ang))
        except Exception:
            pass


def build_pouch_empty(col):
    """Lmg_PouchEmpty: the empty pouch rebuilt slumped (pouch_mesh(empty=True)), its own UVs in the soft atlas;
    origin at PouchMount like Lmg_Pouch."""
    bm = bmesh.new()
    pouch_mesh(bm, {'camo': 0, 'web': 1, 'poly': 2, 'metal': 3}, empty=True)
    return gk.single_object(col, 'Lmg_PouchEmpty', bm, ['FabricCamo', 'Fabric', 'Polymer', 'SteelBare'],
                            origin=mm(*POUCH_MOUNT))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='/tmp/lmg_out')
    ap.add_argument('--assets', default=os.path.join(ROOT, 'assets', 'guns', 'Lmg'))
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
    os.makedirs(args.assets, exist_ok=True)
    only = set(args.only.split(',')) if args.only else None

    def want(k):
        return only is None or k in only

    gk.reset_scene()
    gk.set_quality(0.8)            # round things at 80 % segments: the FBX budget (see README)
    check_case_sweep()
    build_lmg_materials(args.out)
    gk.setup_render(16 if args.quick else args.samples, (1600, 1000))
    col = bpy.data.collections.new('Lmg')
    bpy.context.scene.collection.children.link(col)
    studio = bpy.data.collections.new('Studio')
    bpy.context.scene.collection.children.link(studio)
    gun = build_model()
    objs = gun.build(col)
    finish_meshes(objs.values())
    root = bpy.data.objects.new('GunRoot', None)
    col.objects.link(root)
    for n, ob in objs.items():
        if ob.parent is None:
            ob.parent = root
    empties = gun.empties(studio)
    for e_ in empties.values():
        e_.hide_render = True
    sep = build_separate(col)
    sep['Lmg_Sling'] = build_sling_model(col)
    sep['Lmg_PouchEmpty'] = build_pouch_empty(col)
    finish_meshes(sep.values())
    tris = gk.tri_counts(objs)
    gun_parts = list(gun.order)
    belts = [n for n in gun_parts if n.startswith('Belt')]
    tri_gun = sum(tris[n] for n in gun_parts)
    tri_belt = sum(tris[n] for n in belts)
    print('TRIS', tris, 'gun FBX total', tri_gun, 'belt', tri_belt, flush=True)
    body = [objs[n] for n in gun_parts if n not in ('AmmoPouch', 'Optic', 'OpticLens') and n not in belts]
    lo, hi = gk.world_bbox(body)
    alo, ahi = gk.world_bbox([objs[n] for n in gun_parts])
    dims = {'length': round(hi.x - lo.x, 4), 'barrel': round(mm(BARREL_L), 4), 'height': round(hi.z - lo.z, 4),
            'heightNote': 'carry handle top to grip bottom (no optic, pouch, belt, sling)',
            'heightAll': round(ahi.z - alo.z, 4), 'width': round(ahi.y - alo.y, 4),
            'lengthCollapsed': round(hi.x - lo.x - mm(STOCK_TRAVEL), 4), 'chargeStroke': mm(CH_STROKE),
            'opticAxisAboveBore': round(gun.markers['SightEye'][0].z, 4), 'linkPitch': mm(PITCH)}
    gun.dims = dims
    print('DIMS', dims, flush=True)

    soft = [objs[n] for n in SOFT_PARTS] + [sep['Lmg_PouchEmpty'], sep['Lmg_Sling']]
    ammo = [objs[n] for n in belts] + [sep[n] for n in ('Lmg_Case', 'Lmg_Round', 'Lmg_Link', 'Lmg_BeltSegment')]
    metal = [objs[n] for n in gun_parts if n not in SOFT_PARTS and n not in belts]
    gk.uv_atlas(metal, margin=0.003)
    gk.uv_atlas(soft, margin=0.004)
    gk.uv_atlas(ammo, margin=0.006)
    # the stand-alone pouch models share the soft atlas (same mesh / UVs)
    pm = objs['AmmoPouch']
    pouch = bpy.data.objects.new('Lmg_Pouch', pm.data.copy())
    col.objects.link(pouch)
    sep['Lmg_Pouch'] = pouch
    tri_sep = gk.tri_counts(sep)
    print('SEPARATE TRIS', tri_sep, flush=True)
    paths = None
    if not args.no_bake:
        paths = {'metal': gk.bake_atlas(metal, args.assets, GID, size=1024, samples=12),
                 'soft': gk.bake_atlas(soft, args.assets, GID + '_Soft', size=1024, samples=12),
                 'ammo': gk.bake_atlas(ammo, args.assets, GID + '_Ammo', size=512, samples=12)}
    if not args.no_export:
        gk.export_fbx([objs[n] for n in gun_parts], os.path.join(args.assets, GID + '.fbx'))
        for n in ('Lmg_Case', 'Lmg_Round', 'Lmg_Link', 'Lmg_BeltSegment', 'Lmg_Pouch', 'Lmg_PouchEmpty', 'Lmg_Sling'):
            gk.export_fbx([sep[n]], os.path.join(args.assets, n + '.fbx'))
        gun.to_json(os.path.join(args.assets, 'lmg.markers.json'),
                    tris={**{n: tris[n] for n in gun.order}, 'gunFbx': tri_gun, 'belt': tri_belt,
                          **{k: v for k, v in tri_sep.items()}})
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(args.out, 'lmg.blend'))

    holds = None
    if not args.no_holds:
        holds = solve_holds(gun, os.path.join(HERE, 'lmg_holds.json'))
    if args.no_render:
        return
    render_all(args, gun, objs, root, sep, paths, holds,
               dict(tris=tris, tri_gun=tri_gun, tri_belt=tri_belt, tri_sep=tri_sep, dims=dims), want)


if __name__ == '__main__':
    main()
