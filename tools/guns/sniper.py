#!/usr/bin/env python3
"""The .338 BOLT RIFLE: a bolt-action precision rifle in the class of the reference photo (AWM / L96 type):
black polymer skeleton thumbhole chassis stock with an adjustable cheek riser, a butt pad on spacers (length of
pull) and a rear monopod wheel, a long fluted heavy barrel with a ported muzzle brake, a round receiver with a
long picatinny rail, a 3-12x50 class riflescope in two rings with turrets and a sunshade, a three-lug bolt with
its swept handle and knob, an aluminium trigger guard, a detachable 5-round box magazine, a folding bipod on the
fore-end and QD sling studs.  Original generic design: no logos, no copied markings.

Builds the model from code (tools/guns/gunkit.py), follows the Model contract (docs/firearms/ARCHITECTURE.md
§5), bakes two 1024 atlases (metal + optic + magazine + bipod, and the polymer stock group) for Roblox
SurfaceAppearances, exports the FBXs and the markers JSON to assets/guns/Sniper/, solves the R6 holds
(sniper_holds.json next to this script) and renders the review set.

Real-world class dimensions (AWM-type .338): overall length 1230 mm, barrel 686 mm + brake, height 240 mm with
the scope, 7.5 kg with scope and bipod.  The side profile was measured on the reference photo (level, right side
of the gun, 2.957 mm / px, breech face at px 172, bore at py 104): every coordinate below is in millimetres in
model space (+X muzzle, +Y the gun's left, +Z up; origin on the bore at the breech face).

Moving parts (ARCHITECTURE §5.2): Bolt (+ child BoltHandle) turns about the bore axis 0 -> -60 deg (handle up),
then slides -X 115 mm; MagRelease -10 deg; Safety +15 deg; CheekPiece slides +Z 30 mm; ButtPad slides -X 40 mm;
BipodLegL/R swing +90 deg about BipodPivot (folded forward at rest), BipodExtL/R slide 80 mm along the leg;
Trigger +8 deg; Magazine drops straight out along its MagWell axis.

Usage:
  /home/user/z-anatomy/venv/bin/python -I tools/guns/sniper.py --out DIR [--assets assets/guns/Sniper]
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
GID = 'Sniper'
REF_DEFAULT = '/tmp/claude-0/-home-user-realistic-battleground/e6e0272e-0bb1-5036-b293-d501c4bfb630/scratchpad/guns/refs/sniper.png'


def mm(*a):
    """mm -> metres (a number, a point or a list of 2D points)."""
    if len(a) == 1 and isinstance(a[0], (int, float)):
        return a[0] * 0.001
    if len(a) == 1:
        return [(p[0] * 0.001, p[1] * 0.001) for p in a[0]]
    return tuple(c * 0.001 for c in a)


def interp(table, x):
    t = sorted(table)
    if x <= t[0][0]:
        return t[0][1]
    for (xa, va), (xb, vb) in zip(t[:-1], t[1:]):
        if xa <= x <= xb:
            return va + (vb - va) * (x - xa) / max(1e-9, xb - xa)
    return t[-1][1]


def ellipse2(cx, cz, rx, rz, n=20, a0=0.0):
    return [(cx + rx * math.cos(a0 + 2 * math.pi * k / n), cz + rz * math.sin(a0 + 2 * math.pi * k / n))
            for k in range(n)]


# --------------------------------------------------------------------------------------
# layout (mm, model space; measured on the reference photo)
# --------------------------------------------------------------------------------------
BARREL_L = 686.0                  # breech face -> crown
MUZZLE_X = 757.0                  # front face of the brake
BUTT_X = -473.0                   # rear face of the butt pad
REC_X = (-150.0, 98.0)            # receiver rear / front
REC_TOP = 16.0                    # receiver flat top (the rail stands on it)
RAIL_X = (-112.0, 83.0)
RAIL_Z = 15.5
RAIL_TOP = RAIL_Z + 9.4
SCOPE_X0 = -197.0                 # rear of the eyepiece
SCOPE_Z = 65.0                    # scope axis height
RINGS_X = (-80.0, 28.0)
STROKE = 115.0                    # bolt travel
LIFT = 60.0                       # bolt handle lift (deg)
MAGWELL = (-15.0, -10.0)          # top centre of the seated mag (feed lips)
MAG_LEN, MAG_DEPTH, MAG_W = 112.0, 100.0, 27.0
TRIG_PIVOT = (-108.0, 0.0, -40.0)
REL_PIVOT = (-80.0, 0.0, -47.0)
SAFE_PIVOT = (-142.0, -17.5, -3.0)
BIPOD_PIVOT = (346.0, 0.0, -61.0)    # feet at 0.663 of the length (ref 0.67); the clamp stays under the fore-end tip
BIPOD_LEG = 200.0
SPLAY = 3.0                       # leg splay (deg) baked in the rest pose
CHEEK_TOP = 9.0
SHOULDER_Z = -30.0                # Shoulder marker: the upper third of the pad (top z +2)
BOLT_GRIP_Z = tuple(float(c) for c in os.environ.get('BOLT_GRIP_Z', '-0.75,-0.55,-0.32').split(','))   # BoltCycle hand->elbow: from above / behind the knob, elbow low right
# hold design levers (mm, model space)
GRIP_R = (-170.0, 0.0, -74.0)
GRIP_R_Z = tuple(float(c) for c in os.environ.get('GRIP_R_Z', '-0.92,-0.18,-0.34').split(','))
GRIP_R_TWIST = float(os.environ.get('GRIP_R_TWIST', '-20'))
GRIP_L = (190.0, 0.0, -48.0)                  # the fore-end underside: it rests on the left arm block
GRIP_L_Z = tuple(float(c) for c in os.environ.get('GRIP_L_Z', '-0.36,0.90,0.20').split(','))


# --------------------------------------------------------------------------------------
# materials: the kit's library, with this gun's finish overrides (built here, the kit stays frozen):
# black/dark-grey parkerized receiver, sparse edge-masked scratches (no 'rain' streaks), polymer without
# bright metallic scuffs, a coarse stipple that survives the 1024 bake, and the case head with its primer
# --------------------------------------------------------------------------------------
C = gk.C


def mat_steel_worn(name, col, rough, metal, phosphate=False, wear=1.0, brushed=True):
    m = gk.NB(name)
    e = m.edge(0.0007, 0.03, 0.22)
    near = m.edge(0.0030, 0.02, 0.12)                        # a wider band along the edges
    cav = m.cavity(0.004)
    wearm = m.mul(m.mul(e, m.mask(m.noise(140, 6, 0.6), 0.36, 0.60)), wear)
    var = m.noise(30, 5, 0.6)
    if phosphate:
        cr = m.voronoi(5000, out='Distance')
        base = m.mixc(var, C(*col), C(col[0] * 1.22, col[1] * 1.22, col[2] * 1.25))
        base = m.mixc(m.mul(m.mask(cr, 0.1, 0.5), 0.35), base, C(col[0] * 0.7, col[1] * 0.7, col[2] * 0.7))
        r0 = m.mixf(var, rough, min(1.0, rough + 0.10))
        h = m.add(m.mul(m.mask(cr, 0.0, 0.6), 0.6), m.noise(2500, 2, 0.5))
    else:
        base = m.mixc(var, C(*col), C(col[0] * 1.2, col[1] * 1.2, col[2] * 1.35))
        r0 = m.mixf(var, rough, rough + 0.10)
        h = m.noise(3500, 2, 0.5)
    if brushed:
        br = m.noise(2, 2, 0.5, vec=m.scaled((15, 1800, 1800)))
        r0 = m.mixf(m.mul(br, 0.3), r0, rough - 0.08)
        h = m.add(h, m.mul(br, 0.2))
    grime = m.mx(m.mul(cav, 0.95), m.mask(m.noise(22, 6, 0.6), 0.66, 0.86))
    base = m.mixc(m.mul(grime, 0.6), base, C(0.020, 0.017, 0.013))
    # scratches: ~4x sparser than the kit's, only near edges and never in recesses, a dull grey (not white)
    scr = m.mul(m.mask(m.noise(3, 3, 0.5, vec=m.scaled((40, 1500, 1500))), 0.688, 0.700),
                m.mask(m.noise(6, 3, 0.5), 0.55, 0.68))
    scr = m.mul(m.mul(scr, m.add(0.15, m.mul(near, 0.85))), m.math('SUBTRACT', 1.0, cav))
    base = m.mixc(m.mul(scr, 0.55 * wear), base, C(0.16, 0.16, 0.165))
    base = m.mixc(wearm, base, C(0.30, 0.30, 0.31))
    rr = m.mixf(m.mul(grime, 0.6), r0, 0.7)
    rr = m.mixf(m.mx(wearm, m.mul(scr, 0.5)), rr, 0.25)
    mt = m.mixf(m.mx(wearm, m.mul(scr, 0.6)), metal, 1.0)
    nrm = m.bump(m.add(h, m.mul(wearm, -0.4), m.mul(scr, -0.3)), 0.10, 0.0003)
    m.bsdf(base, mt, rr, nrm)
    return m.m


def mat_polymer_s(name, col=(0.016, 0.016, 0.017), stipple=False):
    m = gk.NB(name)
    e = m.edge(0.0007, 0.03, 0.22)
    cav = m.cavity(0.004)
    var = m.noise(60, 4, 0.5)
    base = m.mixc(var, C(*col), C(col[0] * 1.3, col[1] * 1.3, col[2] * 1.35))
    dust = m.mx(m.mul(cav, 0.9), m.mask(m.noise(25, 6, 0.6), 0.64, 0.86))
    base = m.mixc(m.mul(dust, 0.5), base, C(0.075, 0.071, 0.064))
    base = m.mixc(m.mul(e, 0.45), base, C(0.055, 0.055, 0.057))             # handled edges: polished, a bit lighter
    # scuffs on polymer are matte and only slightly lighter (no metallic streaks)
    scuff = m.mul(m.mask(m.noise(4, 3, 0.5, vec=m.scaled((30, 300, 300))), 0.62, 0.70), m.mask(m.noise(7, 3, 0.5), 0.5, 0.65))
    base = m.mixc(m.mul(scuff, 0.25), base, C(0.040, 0.040, 0.041))
    if stipple:
        st = m.voronoi(520, out='Distance')                              # ~2 mm cells: survives a 1024 bake
        st2 = m.voronoi(1300, out='Distance')
        hgt = m.add(m.mask(st, 0.08, 0.45), m.mul(m.mask(st2, 0.1, 0.5), 0.35), m.mul(m.noise(3000, 2, 0.5), 0.15))
        nrm = m.bump(hgt, 1.0, 0.0009)
        pits = m.math('SUBTRACT', 1.0, m.mask(st, 0.0, 0.25))
        base = m.mixc(m.mul(pits, 0.55), base, C(0.006, 0.006, 0.006))
        tops = m.mask(st, 0.35, 0.6)
        base = m.mixc(m.mul(tops, 0.35), base, C(0.040, 0.040, 0.042))
        rough = m.mixf(tops, 0.90, 0.62)
    else:
        rough = m.mixf(m.mul(e, 0.8), m.mixf(dust, 0.58, 0.84), 0.36)
        rough = m.mixf(m.mul(scuff, 0.5), rough, 0.75)
        nrm = m.bump(m.add(m.noise(3000, 2, 0.5), m.mul(scuff, 0.2)), 0.12, 0.0003)
    m.bsdf(base, 0.0, rough, nrm, extra={'Specular IOR Level': 0.45})
    return m.m


def mat_case_head(name='CaseHead'):
    """The .338 head: brass with the nickel primer (r 2.75 mm about the case axis, object X) and its seam."""
    m = gk.NB(name)
    yz = m.n('ShaderNodeVectorMath', operation='MULTIPLY')
    m.l(m.obj(), yz.inputs[0])
    yz.inputs[1].default_value = (0.0, 1.0, 1.0)
    ln = m.n('ShaderNodeVectorMath', operation='LENGTH')
    m.l(yz.outputs[0], ln.inputs[0])
    r = ln.outputs['Value']
    primer = m.math('SUBTRACT', 1.0, m.mask(r, 0.00262, 0.00272))
    seam = m.mul(m.mask(r, 0.00262, 0.00272), m.math('SUBTRACT', 1.0, m.mask(r, 0.00285, 0.00300)))
    tarn = m.mask(m.noise(30, 6, 0.6), 0.45, 0.85)
    base = m.mixc(m.mul(tarn, 0.6), C(0.70, 0.48, 0.18), C(0.32, 0.21, 0.09))
    base = m.mixc(primer, base, C(0.52, 0.50, 0.47))
    base = m.mixc(seam, base, C(0.05, 0.04, 0.02))
    m.bsdf(base, m.mixf(seam, 1.0, 0.3), m.mixf(primer, m.mixf(tarn, 0.25, 0.42), 0.30),
           m.bump(m.mul(seam, -1.0), 0.3, 0.0002))
    return m.m


def mat_reticle(name='Reticle'):
    """An illuminated reticle (dim red emissive) so the eye-view renders show the sight alignment."""
    return gk.mat_simple(name, (0.25, 0.01, 0.01), 0.0, 0.5, extra={'Emission Color': C(1.0, 0.06, 0.03),
                                                                   'Emission Strength': 3.0})


def build_sniper_materials():
    gk.build_materials()
    mat_polymer_s('Polymer')
    mat_polymer_s('PolymerStipple', stipple=True)
    mat_steel_worn('SteelBlued', (0.028, 0.029, 0.032), 0.42, 0.80, wear=0.8)
    mat_steel_worn('SteelPhosphate', (0.036, 0.037, 0.039), 0.66, 0.45, phosphate=True, wear=0.8)
    mat_steel_worn('SteelBare', (0.33, 0.33, 0.34), 0.32, 1.0, wear=0.25)
    mat_case_head('CaseHead')
    mat_polymer_s('PolymerGrey', col=(0.17, 0.17, 0.16))          # the follower: reads 'empty' at a glance
    mat_reticle('Reticle')


# --------------------------------------------------------------------------------------
# the chassis stock (one polymer part: butt + thumbhole grip + action bedding + fore-end), cheek piece, butt
# pad on its spacers, monopod wheel
# --------------------------------------------------------------------------------------
REAR = [(-455, -12), (-318, -12), (-309, -15.5), (-150, -15.5), (-150, -50), (-141, -56), (-143, -80), (-146, -104),
        (-147, -126), (-152, -140), (-162, -146), (-232, -146), (-250, -137), (-292, -101), (-338, -97),
        (-348, -106), (-352, -131), (-455, -131)]
REAR_R = [3, 5, 4, 0, 3, 6, 0, 0, 10, 10, 6, 10, 10, 14, 6, 6, 4, 4]
HOLE = ellipse2(-217.0, -74.0, 29.0, 25.0, 18)
# the butt tapers in plan view: 44 mm at the pad, 36 mm at the comb's front, ~31 mm at the thumbhole pillar
# (a linear taper keeps the flat sides planar)
REAR_W0 = 36.0


def rear_width(x):
    return 44.0 + (x + 455.0) * (31.4 - 44.0) / 305.0


def taper_y(bm, base_w, minus=0.0):
    """Scale a part built `base_w` thick so its width follows rear_width(x) - minus (the butt taper)."""
    for v in bm.verts:
        v.co.y *= (rear_width(v.co.x * 1000.0) - minus) / base_w


# the action bedding + fore-end: a loft of rounded sections (x, top z, bottom z, half width, top r, bottom r):
# blends from the 31 mm pillar to the 54 mm bedding over 40 mm, rounded-U fore-end bottom, rounded tip
CENTER_ST = [(-170, -15.5, -50, 15.8, 3, 6), (-150, -15.5, -50, 19.0, 3, 7), (-147, -8, -50, 20.5, 3, 7),
             (-138, -8, -50, 24.2, 3, 8), (-128, -8, -50, 26.5, 3, 8), (-116, -8, -50, 27.0, 3, 8),
             (-90, -8, -50, 27.0, 3, 8), (-84, -8, -53.5, 27.0, 3, 8), (-79, -8, -66, 27.0, 3, 7),
             (-76, -8, -74, 27.0, 3, 6), (26, -8, -74, 27.0, 3, 6), (36, -8, -66, 27.0, 3, 8),
             (64, -8, -54, 27.0, 3, 11), (98, -8, -48.5, 27.0, 3, 14), (104, -5, -48, 26.6, 4, 16),
             (112, -2, -48, 26.2, 5, 18), (220, -2, -48, 25.6, 5, 18), (340, -2, -48, 24.8, 5, 18),
             (352, -3.5, -47, 23.6, 6, 17), (360, -9, -44, 20.5, 6, 13), (364.5, -18, -39, 13.0, 4, 6)]
# the fore-end walls rise to the bore line (as the reference chassis) around a free-float barrel channel
CHANNEL_R = 17.5


def center_bot(x):
    return interp([(s[0], s[2]) for s in CENTER_ST], x)


def build_stock(gun):
    sk = gun.part('Stock', paint='Polymer')
    Po, Ps, Ba, Bo, Al = sk.mi('Polymer'), sk.mi('PolymerStipple'), sk.mi('SteelBare'), sk.mi('Bore'), sk.mi('Aluminium')
    bm = sk.bm
    # butt + grip + wrist: one well rounded profile with the thumbhole (built 36 mm, then tapered 44 -> 31)
    rear = bmesh.new()
    gk.profile(rear, mm(gk.fillet2(REAR, 2.0, 1, radii=REAR_R)), mm(REAR_W0), holes=[mm(HOLE)], bevel=mm(8.5),
               bevel_segs=2, mi=Po)
    bmesh.ops.recalc_face_normals(rear, faces=list(rear.faces))      # the hole walls came out inverted
    cuts = []
    # moulded lightening pockets on both sides of the butt (as the photo's skeleton stock)
    pk = gk.fillet2([(-440, -30), (-330, -30), (-312, -50), (-318, -82), (-362, -82), (-372, -112), (-440, -112)],
                    8.0, 2)
    pk2 = gk.fillet2([(-262, -62), (-254, -92), (-260, -110), (-270, -110), (-282, -62)], 4.0, 1)
    for y0, y1 in ((15.0, 25.0), (-25.0, -15.0)):
        cuts.append(gk.prism_cutter(mm(pk), mm(y0), mm(y1), mi=Po))
        cuts.append(gk.prism_cutter(mm(pk2), mm(y0), mm(y1), mi=Po))
    gk.boolean_bm(rear, cuts)
    taper_y(rear, REAR_W0)
    gk.merge(bm, rear)
    rear.free()
    # stippled grip panels on the thumbhole pillar (proud 0.8 mm; the stipple itself is in the material)
    panel = gk.fillet2([(-186, -60), (-151, -64), (-149, -122), (-158, -136), (-184, -134), (-189, -96)], 5.0, 2)
    pn = bmesh.new()
    gk.profile(pn, mm(panel), mm(REAR_W0 + 1.7), bevel=mm(1.2), bevel_segs=1, mi=Ps)
    taper_y(pn, REAR_W0)
    gk.merge(bm, pn)
    pn.free()
    # action bedding + fore-end: lofted rounded sections
    ce = bmesh.new()
    rings = []
    for x, top, bot, hw, rt, rb in CENTER_ST:
        sec = gk.rrect2((top + bot) / 2, 0.0, (top - bot) / 2, hw, r_pos=rt, r_neg=rb, n=4)
        rings.append([mm(x, y, z) for z, y in sec])
    gk.loft(ce, rings, mi=Po)
    cuts = []
    c = bmesh.new()
    gk.box(c, mm(MAGWELL[0], 0, -45.0), mm(MAG_DEPTH + 4.0, MAG_W + 4.0, 66.0), mi=Bo)       # magazine well
    cuts.append(c)
    c = bmesh.new()
    gk.cyl(c, mm(99.0, 0, 0), mm(372.0, 0, 0), mm(CHANNEL_R), 20, mi=Po)                # barrel channel
    cuts.append(c)
    groove = gk.fillet2([(122, -24), (316, -24), (316, -31), (122, -31)], 3.0, 1)
    for y0, y1 in ((24.0, 30.0), (-30.0, -24.0)):
        cuts.append(gk.prism_cutter(mm(groove), mm(y0), mm(y1), mi=Po))
    # vent slots under the fore-end
    for x in (150.0, 200.0):
        s = gk.fillet2([(x - 18, -60), (x + 18, -60), (x + 18, -42), (x - 18, -42)], 5.0, 2)
        cuts.append(gk.prism_cutter(mm(s), mm(-8.0), mm(8.0), mi=Bo))
    gk.boolean_bm(ce, cuts)
    gk.merge(bm, ce)
    ce.free()
    # action screws (bedding) under the chassis
    for x in (-100.0, 50.0):
        gk.screw(bm, mm(x, 0, center_bot(x) - 0.4), (0, 0, -1), mm(4.2), mm(1.0), 'hex', mi=Ba, mi_recess=Bo)
    # cheek-riser lock wheel (left side) and the riser posts' screws
    xw = -296.0
    yw = rear_width(xw) / 2 - 1.0
    gk.lathe(bm, mm([(0, 0), (0, 8.5), (1.0, 9.5), (7.0, 9.5), (8.0, 8.5), (8.0, 0)]), 18,
             gk.frame_x(V(mm(xw, yw, -26.0)), (0, 1, 0)), mi=Al)
    for k in range(10):
        a = 2 * math.pi * k / 10
        gk.box(bm, mm(xw + 9.6 * math.cos(a), yw + 4.0, -26.0 + 9.6 * math.sin(a)), mm(1.2, 7.0, 1.2), mi=Al)
    for x in (-430.0, -340.0):
        for sy in (1, -1):
            gk.screw(bm, mm(x, sy * rear_width(x) / 2, -20.0), (0, sy, 0), mm(2.6), mm(0.6), 'hex', mi=Ba,
                     mi_recess=Bo)
    # QD sling studs: under the fore-end and under the butt
    gk.sling_swivel(bm, mm(250.0, 0, -47.5), axis_loop=(0, 0, -1), size=mm(22.0), mi=Ba)
    gk.sling_swivel(bm, mm(-425.0, 0, -130.5), axis_loop=(0, 0, -1), size=mm(22.0), mi=Ba)
    # short picatinny under the fore-end tip for the bipod clamp
    gk.picatinny(bm, mm(322.0), mm(356.0), mm(-47.5), mi=Al, flip=True)
    return sk


CHEEK_X0 = -318.0                 # the riser's front: behind the bolt shroud at full stroke (x -303, r 14)


def build_cheek(gun):
    ck = gun.part('CheekPiece', paint='Polymer', parent='Stock', origin=mm(-390.0, 0, -12.0))
    Po, Ba = ck.mi('Polymer'), ck.mi('SteelBare')
    out = [(-455, -13), (CHEEK_X0 - 4, -13), (CHEEK_X0 + 4, -7), (CHEEK_X0 + 2, 3), (CHEEK_X0 - 10, CHEEK_TOP),
           (-448, CHEEK_TOP), (-455, 5)]
    t = bmesh.new()
    gk.profile(t, mm(gk.fillet2(out, 2.0, 2, radii=[2, 3, 4, 6, 6, 5, 3])), mm(REAR_W0), bevel=mm(8.0),
               bevel_segs=2, mi=Po)
    taper_y(t, REAR_W0, minus=3.0)
    gk.merge(ck.bm, t)
    t.free()
    # the two riser posts (seen in the gap when raised)
    for x in (-430.0, -340.0):
        gk.cyl(ck.bm, mm(x, 0, -12.0), mm(x, 0, -40.0), mm(4.0), 10, mi=Ba)
    return ck


PAD_SEC = gk.rrect2(-64.0, 0.0, 66.0, 21.6, r_pos=12.0, r_neg=10.0, n=3)


def build_buttpad(gun):
    bp = gun.part('ButtPad', paint='Rubber', parent='Stock', origin=mm(-455.0, 0, -64.0))
    Ru, Po, Ba = bp.mi('Rubber'), bp.mi('Polymer'), bp.mi('SteelBare')
    sec = [(y, z) for z, y in PAD_SEC]
    # two spacers (polymer, a thin groove between them) then the rubber pad
    gk.section_x(bp.bm, mm(sec), mm(-459.2), mm(-455.0), end_bevel=mm(0.5), mi=Po)
    gk.section_x(bp.bm, mm(sec), mm(-463.5), mm(-459.4), end_bevel=mm(0.5), mi=Po)
    gk.section_x(bp.bm, mm(sec), mm(-472.0), mm(-463.6), end_bevel=mm(2.5), mi=Ru)
    # horizontal anti-slip ribs on the rear face
    for k in range(7):
        z = -14.0 - k * 16.0
        gk.rbox(bp.bm, mm(-472.3, 0, z), mm(1.6, 30.0, 3.0), mm(0.6), 1, mi=Ru)
    # LOP adjustment rods (seen when the pad is pulled out) and the pad screws
    for z in (-25.0, -103.0):
        gk.cyl(bp.bm, mm(-455.0, 0, z), mm(-420.0, 0, z), mm(4.0), 10, mi=Ba)
    return bp


def build_monopod(gun):
    mp = gun.part('Monopod', paint='Aluminium', parent='Stock', origin=mm(-365.0, 0, -131.0))
    Al, Ru, Ba = mp.mi('Aluminium'), mp.mi('Rubber'), mp.mi('SteelBare')
    bm = mp.bm
    gk.cyl(bm, mm(-365.0, 0, -120.0), mm(-365.0, 0, -150.0), mm(5.0), 12, mi=Ba)
    for k in range(2):                                                        # thread rings on the post
        gk.torus(bm, mm(-365.0, 0, -142.0 - k * 2.5), (0, 0, 1), mm(5.0), mm(0.45), 10, 3, mi=Ba)
    gk.lathe(bm, mm([(0, 0), (0, 14.0), (0.8, 15.5), (8.2, 15.5), (9.0, 14.0), (9.0, 0)]), 16,
             gk.frame_x(V(mm(-365.0, 0, -132.0)), (0, 0, -1)), mi=Al)
    for k in range(10):                                                       # knurl ribs round the wheel
        a = 2 * math.pi * k / 10
        gk.box(bm, mm(-365.0 + 15.7 * math.cos(a), 15.7 * math.sin(a), -136.5), mm(1.6, 1.6, 7.0),
               R=Matrix.Rotation(a, 3, 'Z'), mi=Al)
    gk.lathe(bm, mm([(0, 0), (0, 9.0), (3.0, 10.0), (5.5, 8.0), (6.0, 0)]), 14,
             gk.frame_x(V(mm(-365.0, 0, -149.0)), (0, 0, -1)), mi=Ru)
    return mp


# --------------------------------------------------------------------------------------
# receiver (steel) with its rail, trigger guard (aluminium)
# --------------------------------------------------------------------------------------

def build_receiver(gun):
    rc = gun.part('Receiver', paint='SteelPhosphate', fit=1)
    St, Bo, Ba, Al = rc.mi('SteelPhosphate'), rc.mi('Bore'), rc.mi('SteelBare'), rc.mi('Aluminium')
    bm = rc.bm
    sec = gk.rrect2(0.0, 0.0, REC_TOP, 16.5, r_pos=7.0, r_neg=13.0, n=3)
    gk.section_x(bm, mm([(y, z) for z, y in sec]), mm(REC_X[0]), mm(REC_X[1]), end_bevel=mm(1.5), mi=St)
    # rear tang (under the bolt shroud) blending into the stock
    gk.rbox(bm, mm(-160.0, 0, -11.0), mm(26.0, 22.0, 8.0), mm(2.0), 2, mi=St)
    cuts = []
    # ejection port (right side, under the rail) and the bolt-handle notch behind it
    port = gk.fillet2([(-88, -2), (4, -2), (4, 14), (-88, 14)], 3.0, 2)
    cuts.append(gk.prism_cutter(mm(port), mm(-30.0), mm(-6.0), mi=Bo))
    notch = gk.fillet2([(-110, -22), (-86, -22), (-86, 14), (-110, 14)], 3.0, 1, radii=[3, 0, 0, 3])
    cuts.append(gk.prism_cutter(mm(notch), mm(-30.0), mm(-5.0), mi=Bo))
    # bolt bore at the rear (the shroud enters it)
    c = bmesh.new()
    gk.cyl(c, mm(-155.0, 0, 0), mm(-130.0, 0, 0), mm(11.2), 16, mi=Bo)
    cuts.append(c)
    gk.boolean_bm(bm, cuts)
    # integral picatinny rail on the flat top, its fixing screws
    gk.picatinny(bm, mm(RAIL_X[0]), mm(RAIL_X[1]), mm(RAIL_Z), mi=St)
    # bolt release button (left rear) and the receiver ring's lug pins
    gk.rbox(bm, mm(-132.0, 17.0, 5.0), mm(11.0, 2.4, 6.5), mm(0.8), 1, mi=St)
    for (x, z) in ((70.0, -6.0), (86.0, -6.0)):
        gk.pin(bm, mm(x, 16.5, z), (0, 1, 0), mm(1.8), proud=mm(0.3), segs=8, mi=Ba, both=mm(33.0))
    # trigger guard / bottom metal (aluminium): a guard loop and its flange
    # rounded (oval) guard loop: flat top on the bottom metal, a half-ellipse below it (as the reference class)
    def guard(cx, rx, rz, z0, n=14):
        pts = [(cx + rx, z0)]
        for k in range(n + 1):
            a = math.pi * k / n
            pts.append((cx + rx * math.cos(a), z0 - 6.0 - rz * math.sin(a)))
        pts.append((cx - rx, z0))
        return pts
    tg_out = guard(-116.5, 26.5, 38.0, -47.0)
    tg_in = guard(-115.5, 20.0, 28.0, -51.5)
    gk.profile(bm, mm(tg_out), mm(11.0), holes=[mm(tg_in)], bevel=mm(1.6), bevel_segs=1, mi=Al)
    gk.rbox(bm, mm(-116.0, 0, -49.0), mm(60.0, 22.0, 4.0), mm(1.2), 1, mi=Al)
    for x in (-138.0, -94.0):
        gk.screw(bm, mm(x, 0, -51.2), (0, 0, -1), mm(2.5), mm(0.6), 'hex', mi=Ba, mi_recess=Bo)
    return rc


# --------------------------------------------------------------------------------------
# barrel group: fluted heavy barrel, brake
# --------------------------------------------------------------------------------------

def flute_ring(x, r, depth, nfl=6, per=6, phase=0.0):
    pts = []
    n = nfl * per
    for k in range(n):
        a = 2 * math.pi * k / n + phase
        u = (k % per) / per
        s = max(0.0, math.cos(math.pi * (u - 0.5) / 0.62)) if abs(u - 0.5) < 0.31 else 0.0
        rr = r - depth * s
        pts.append(mm(x, rr * math.cos(a), rr * math.sin(a)))
    return pts


def build_barrel(gun):
    br = gun.part('Barrel', paint='SteelBlued', fit=2)
    St, Bo, Ba = br.mi('SteelBlued'), br.mi('Bore'), br.mi('SteelBare')
    bm = br.bm
    R0, R1 = 15.0, 12.0

    def r_at(x):
        return interp([(98, R0), (215, 14.6), (600, R1 + 0.2), (686, R1)], x)
    # chamber section (behind the flutes) with the barrel shoulder at the receiver
    gk.lathe(bm, mm([(60, 0), (60, 16.0), (100, 16.0), (101.5, R0), (222, r_at(222))]), 24,
             gk.frame_x(V((0, 0, 0)), (1, 0, 0)), mi=St)
    # fluted section (6 flutes fading in / out)
    rings = []
    for x, f in ((215, 0.0), (228, 0.6), (240, 1.0), (400, 1.0), (575, 1.0), (590, 0.6), (604, 0.0)):
        rings.append(flute_ring(x, r_at(x), 2.6 * f, phase=math.pi / 6))
    gk.loft(bm, rings, mi=St)
    # muzzle end + threads under the brake
    gk.lathe(bm, mm([(598, 0), (598, r_at(598)), (686, R1), (686, 9.5), (700, 9.5), (700, 0)]), 24,
             gk.frame_x(V((0, 0, 0)), (1, 0, 0)), mi=St)
    return br


def build_muzzle(gun):
    md = gun.part('MuzzleDevice', paint='SteelBlued', parent='Barrel', origin=mm(686.0, 0, 0))
    St, Bo = md.mi('SteelBlued'), md.mi('Bore')
    bm = md.bm
    prof = [(684, 5.5), (684, 14.0), (687, 16.5), (MUZZLE_X - 3, 16.5), (MUZZLE_X, 14.5), (MUZZLE_X, 6.0),
            (MUZZLE_X - 1.2, 5.0)]
    gk.lathe(bm, mm(prof), 18, gk.frame_x(V((0, 0, 0)), (1, 0, 0)), closed=True, mi=St)
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        c = f.calc_center_median()
        if math.hypot(c.y, c.z) < mm(6.0):
            f.material_index = Bo
    # three side ports per side (through both sides) and two top vents
    cuts = []
    for k, x in enumerate((704.0, 720.0, 736.0)):
        c = bmesh.new()
        gk.rbox(c, mm(x, 0, 0), mm(9.0 - k * 0.6, 40.0, 17.0), mm(2.5), 2, mi=Bo)
        cuts.append(c)
    for x in (713.0, 729.0):
        c = bmesh.new()
        gk.cyl(c, mm(x, 0, 0), mm(x, 0, 20.0), mm(2.6), 10, mi=Bo)
        cuts.append(c)
    gk.boolean_bm(bm, cuts)
    # the lock nut behind it
    gk.lathe(bm, mm([(676, 0), (676, 14.0), (677, 15.0), (683.5, 15.0), (684, 14.0), (684, 0)]), 6,
             gk.frame_x(V((0, 0, 0)), (1, 0, 0), up=(0, 0, 1)), mi=St)
    return md


# --------------------------------------------------------------------------------------
# riflescope (3-12x50 class) in two rings, its lenses
# --------------------------------------------------------------------------------------

def build_optic(gun):
    op = gun.part('Optic', paint='Aluminium')
    Al, Ru, Ba, Bo = op.mi('Aluminium'), op.mi('Rubber'), op.mi('SteelBare'), op.mi('Bore')
    bm = op.bm
    X0, Z = SCOPE_X0, SCOPE_Z
    M = gk.frame_x(V(mm(X0, 0, Z)), (1, 0, 0))
    # eyepiece rubber ring, ocular bell, power ring, 30 mm tube, objective bell (local x, radius)
    gk.lathe(bm, mm([(3, 0), (3, 17.5), (0, 19.0), (0, 20.5), (1.5, 20.6), (12, 20.6), (13, 20.0)]), 20, M, mi=Ru)
    gk.lathe(bm, mm([(12.5, 20.0), (14, 20.8), (52, 20.8), (58, 19.6), (68, 17.5), (71, 17.5), (72, 18.6),
                     (98, 18.6), (99, 17.0), (102, 15.0), (222, 15.0), (262, 26.0), (265, 27.0), (312, 27.0),
                     (314, 26.0), (314, 24.0), (315, 0)]), 20, M, mi=Al)
    # power ring grip ribs + the throw lever + the magnification index
    for k in range(12):
        a = 2 * math.pi * k / 12
        gk.box(bm, mm(X0 + 85.0, 19.0 * math.cos(a), Z + 19.0 * math.sin(a)), mm(22.0, 1.4, 1.4),
               R=Matrix.Rotation(a, 3, 'X'), mi=Ru)
    gk.rbox(bm, mm(X0 + 85.0, -21.5, Z + 5.0), mm(5.0, 6.0, 3.5), mm(1.0), 1, mi=Al)
    # turret saddle with elevation (top), windage (right) and side focus (left) turrets
    xm = X0 + 170.0
    gk.rbox(bm, mm(xm, 0, Z), mm(44.0, 36.0, 36.0), mm(6.0), 2, mi=Al)

    def turret(axis, r, h, ribs=12):
        a = V(axis).normalized()
        base = V(mm(xm, 0, Z)) + a * mm(17.5)
        gk.lathe(bm, mm([(0, 0), (0, r - 1.5), (3.0, r - 1.5), (3.5, r), (h - 1.0, r), (h, r - 1.2), (h, 0)]), 16,
                 gk.frame_x(base, a, up=(1, 0, 0)), mi=Al)
        u = V((1, 0, 0))
        w = a.cross(u)
        for k in range(ribs):
            t = 2 * math.pi * k / ribs
            p = base + a * mm(3.5 + (h - 4.5) / 2) + (u * math.cos(t) + w * math.sin(t)) * mm(r + 0.3)
            Rm = gk.basis(u * math.cos(t) + w * math.sin(t), a, (u * math.cos(t) + w * math.sin(t)).cross(a))
            gk.box(bm, p, (mm(1.2), mm(h - 5.0), mm(1.4)), R=Rm, mi=Al)
        # index line on the turret cap
        gk.box(bm, base + a * mm(h + 0.15) + u * mm(r * 0.5), (mm(r * 0.9), mm(0.8), mm(0.3)),
               R=gk.basis(u, w, a), mi=Ba)
    turret((0, 0, 1), 11.5, 17.0, ribs=8)
    turret((0, -1, 0), 11.5, 15.0, ribs=8)
    turret((0, 1, 0), 13.5, 11.0, ribs=8)
    # sunshade (hollow tube) on the objective
    gk.lathe(bm, mm([(310, 25.0), (310, 27.2), (337, 27.2), (338, 26.6), (338, 25.3), (311, 25.3)]), 20, M,
             closed=True, mi=Al)
    # rings: clamps on the tube, bases on the rail with their cross bolts
    for x in RINGS_X:
        gk.lathe(bm, mm([(-8.5, 19.5), (8.5, 19.5), (8.5, 14.8), (-8.5, 14.8)]), 20,
                 gk.frame_x(V(mm(x, 0, Z)), (1, 0, 0)), closed=True, mi=Al)
        for sy in (1, -1):                                                        # cap split screws
            gk.screw(bm, mm(x, sy * 20.5, Z + 1.5), (0, sy, 0), mm(2.4), mm(1.5), 'hex', mi=Ba, mi_recess=Bo)
        gk.rbox(bm, mm(x, 0, (RAIL_TOP + Z - 15.0) / 2 + 0.5), mm(16.0, 20.0, Z - 15.0 - RAIL_TOP + 3.0), mm(2.0), 1,
                mi=Al)
        gk.rbox(bm, mm(x, 0, RAIL_TOP - 3.5), mm(16.0, 29.0, 9.0), mm(1.5), 1, mi=Al)     # clamp jaws
        gk.cyl(bm, mm(x, 15.5, RAIL_TOP - 5.0), mm(x, -18.0, RAIL_TOP - 5.0), mm(3.0), 10, mi=Ba)
        gk.lathe(bm, mm([(0, 0), (0, 6.5), (5.0, 6.5), (5.0, 0)]), 6,
                 gk.frame_x(V(mm(x, -14.5, RAIL_TOP - 5.0)), (0, -1, 0), up=(1, 0, 0)), mi=Ba)  # hex nut
    ln = gun.part('OpticLens', paint='Lens', parent='Optic', origin=mm(X0, 0, Z))
    Le = ln.mi('Lens')
    gk.cyl(ln.bm, mm(X0 + 2.6, 0, Z), mm(X0 + 2.9, 0, Z), mm(17.4), 20, mi=Le)
    gk.cyl(ln.bm, mm(X0 + 314.0, 0, Z), mm(X0 + 314.6, 0, Z), mm(23.9), 20, mi=Le)
    # duplex reticle (dim illuminated) just behind the ocular glass: fine centre wires, heavy outer posts
    Rt = ln.mi('Reticle')
    xr = X0 + 2.5
    gk.box(ln.bm, mm(xr, 0, Z), mm(0.1, 11.0, 0.22), mi=Rt)
    gk.box(ln.bm, mm(xr, 0, Z), mm(0.1, 0.22, 11.0), mi=Rt)
    for dy, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        c = 11.25
        gk.box(ln.bm, mm(xr, dy * c, Z + dz * c), mm(0.1, 11.5 if dy else 0.9, 0.9 if dy else 11.5), mi=Rt)
    return op, ln


def scope_eye():
    """SightEye: 90 mm eye relief behind the ocular lens, +X converging with the bore at 100 m."""
    p = V(mm(SCOPE_X0 - 90.0, 0, SCOPE_Z))
    d = (V((100.0, 0, 0)) - p).normalized()
    return p, d


# --------------------------------------------------------------------------------------
# moving parts: bolt + handle, safety, trigger, mag release, bipod
# --------------------------------------------------------------------------------------
HANDLE_PATH = [(-96.0, -9.0, 0.0), (-99.0, -22.0, -6.0), (-108.0, -34.0, -18.0), (-117.0, -42.0, -30.0),
               (-122.0, -46.0, -36.0)]


def knob_frame():
    end = V(mm(*HANDLE_PATH[-1]))
    d = (end - V(mm(*HANDLE_PATH[-2]))).normalized()
    return end, d, end + d * mm(9.0)


def build_bolt(gun):
    bo = gun.part('Bolt', paint='SteelBare', origin=(0, 0, 0))
    Ba, St, Bo = bo.mi('SteelBare'), bo.mi('SteelPhosphate'), bo.mi('Bore')
    bm = bo.bm
    gk.cyl(bm, mm(-150.0, 0, 0), mm(-4.0, 0, 0), mm(10.5), 18, mi=Ba)
    for sz in (1, -1):                                                         # locking lugs
        gk.rbox(bm, mm(-10.0, 0, sz * 10.5), mm(12.0, 9.0, 6.0), mm(0.8), 1, mi=Ba)
    gk.rbox(bm, mm(-16.0, -10.2, 3.0), mm(18.0, 2.4, 3.6), mm(0.5), 1, mi=Ba)  # extractor
    gk.cyl(bm, mm(-4.0, 0, 0), mm(-3.2, 0, 0), mm(7.5), 16, mi=Bo)            # bolt face recess
    gk.torus(bm, mm(-50.0, 0, 0), (1, 0, 0), mm(10.5), mm(0.6), 18, 3, mi=Bo)    # gas vent groove
    # bolt shroud with the cocking indicator at the rear
    gk.lathe(bm, mm([(-148, 0), (-148, 13.0), (-150, 14.0), (-171, 13.5), (-175, 11.5), (-178, 8.0), (-186, 7.0),
                     (-188, 5.0), (-188, 0)]), 20, gk.frame_x(V((0, 0, 0)), (1, 0, 0)), mi=St)
    gk.box(bm, mm(-183.0, 0, 7.4), mm(5.0, 4.0, 1.6), mi=gun.parts['Bolt'].mi('SightPaint'))
    ha = gun.part('BoltHandle', paint='SteelPhosphate', parent='Bolt', origin=mm(*HANDLE_PATH[0]))
    St2 = ha.mi('SteelPhosphate')
    gk.sweep(ha.bm, gk.crs([mm(*p) for p in HANDLE_PATH], 3), mm(4.2), segs=10, mi=St2)
    end, d, _ = knob_frame()
    gk.lathe(ha.bm, mm([(-3.0, 0), (-3.0, 5.0), (1.0, 9.0), (7.0, 10.5), (14.0, 10.0), (18.0, 7.0), (19.5, 0)]), 18,
             gk.frame_x(end, d), mi=St2)
    for k in range(2):
        gk.torus(ha.bm, end + d * mm(6.0 + k * 4.5), d, mm(10.2 + 0.2 * k), mm(0.55), 14, 3, mi=St2)
    return bo, ha


def build_safety(gun):
    sf = gun.part('Safety', paint='SteelPhosphate', origin=mm(*SAFE_PIVOT))
    St = sf.mi('SteelPhosphate')
    out = [(-138.0, -6.0), (-146.0, -6.0), (-152.0, 6.0), (-158.0, 9.5), (-160.0, 6.5), (-150.0, -1.0)]
    gk.profile(sf.bm, mm(gk.fillet2(out, 1.0, 1, radii=[2, 2, 1.5, 1.5, 1.5, 2])), mm(2.6), y=mm(SAFE_PIVOT[1] - 1.3),
               bevel=mm(0.5), bevel_segs=0, mi=St)
    gk.cyl(sf.bm, mm(SAFE_PIVOT[0], SAFE_PIVOT[1] + 1.0, SAFE_PIVOT[2]), mm(SAFE_PIVOT[0], SAFE_PIVOT[1] - 3.6,
                                                                         SAFE_PIVOT[2]), mm(3.4), 12, mi=St)
    return sf


def build_trigger(gun):
    tg = gun.part('Trigger', paint='Aluminium', origin=mm(*TRIG_PIVOT), fit=3)
    Al = tg.mi('Aluminium')
    # a wide, curved blade (9 mm across the face), not a bent wire
    out = [(-101.0, -38.0), (-106.0, -36.0), (-112.0, -40.0), (-118.0, -57.0), (-121.0, -69.0), (-121.5, -77.0),
           (-117.0, -80.0), (-113.0, -72.0), (-109.0, -60.0), (-102.0, -47.0)]
    gk.profile(tg.bm, mm(gk.fillet2(out, 1.0, 1, radii=[2, 2, 3, 3, 2, 1.5, 1.5, 3, 3, 2])), mm(8.0), bevel=mm(1.0),
               bevel_segs=1, mi=Al)
    for k in range(4):                                                         # face grooves
        gk.box(tg.bm, mm(-119.2 - k * 0.25, 0, -62.0 - k * 4.0), mm(0.5, 5.0, 0.6),
               R=Matrix.Rotation(math.radians(-20), 3, 'Y'), mi=Al)
    return tg


def build_mag_release(gun):
    mr = gun.part('MagRelease', paint='SteelPhosphate', origin=mm(*REL_PIVOT))
    St = mr.mi('SteelPhosphate')
    out = [(-77.0, -45.0), (-83.5, -45.0), (-84.5, -58.0), (-86.0, -70.0), (-81.0, -72.0), (-79.5, -60.0)]
    gk.profile(mr.bm, mm(gk.fillet2(out, 1.0, 1, radii=[1, 1, 2, 2, 2, 2])), mm(12.0), bevel=mm(0.8), bevel_segs=1,
               mi=St)
    for k in range(3):
        gk.box(mr.bm, mm(-85.5, 0, -62.0 - k * 2.8), mm(1.0, 10.0, 0.9), mi=St)
    return mr


def build_bipod(gun):
    mats_ok = {}
    yk = gun.part('BipodYoke', paint='Aluminium', parent='Stock', origin=mm(*BIPOD_PIVOT))
    Al, Ru, Ba = yk.mi('Aluminium'), yk.mi('Rubber'), yk.mi('SteelBare')
    res = gk.bipod(mm(*BIPOD_PIVOT), leg_len=mm(BIPOD_LEG), splay=SPLAY, folded='forward', mats={'body': Al, 'foot': Ru},
                   ext=mm(80.0), leg_r=mm(5.5))
    gk.merge(yk.bm, res['Yoke'])
    # rail clamp on top of the yoke with its lever
    gk.rbox(yk.bm, mm(BIPOD_PIVOT[0], 0, -52.5), mm(30.0, 30.0, 7.0), mm(1.5), 1, mi=Al)
    gk.rbox(yk.bm, mm(BIPOD_PIVOT[0], -17.0, -52.0), mm(20.0, 4.0, 8.0), mm(1.2), 1, mi=Al)
    gk.cyl(yk.bm, mm(BIPOD_PIVOT[0], -17.0, -52.0), mm(BIPOD_PIVOT[0], -23.0, -52.0), mm(4.0), 10, mi=Ba)
    for side in ('L', 'R'):
        lg = gun.part('BipodLeg' + side, paint='Aluminium', parent='BipodYoke', origin=mm(*BIPOD_PIVOT))
        lg.mi('Aluminium')
        lg.mi('Rubber')
        gk.merge(lg.bm, res['BipodLeg' + side])
        # close the knuckle-to-tube gap of the kit's leg (a short collar from the hinge block into the tube)
        sy = 1 if side == 'L' else -1
        ka = V(mm(*BIPOD_PIVOT)) + V((0, sy * 0.013, -0.006))
        gk.cyl(lg.bm, ka, ka + leg_dir(sy) * 0.016, mm(5.5) * 1.35, 10, lg.mi('Aluminium'))
        ex = gun.part('BipodExt' + side, paint='Aluminium', parent='BipodLeg' + side, origin=mm(*BIPOD_PIVOT))
        ex.mi('Aluminium')
        ex.mi('Rubber')
        gk.merge(ex.bm, res['BipodExt' + side])
    for b in res.values():
        b.free()
    return mats_ok


def leg_dir(sy):
    return V((1.0, sy * math.sin(math.radians(SPLAY)), 0)).normalized()


def bipod_foot(ext=0.0):
    """Foot contact of the left leg when deployed (+90 deg about +Y through the pivot), ext metres out."""
    p = V(mm(*BIPOD_PIVOT))
    d = leg_dir(1)
    a = p + V((0, 0.013, -0.006))
    tip = a + d * (0.012 + mm(BIPOD_LEG) + ext + 0.020)
    R = Matrix.Rotation(math.radians(90.0), 3, 'Y')
    return p + R @ (tip - p)


# --------------------------------------------------------------------------------------
# magazine (+ top rounds, follower), loose round, spent case
# --------------------------------------------------------------------------------------
MAG_AX = (0.0, -1.0)
MAG_T = 1.6                       # sheet steel wall
CASE_SEGS, ROUND_SEGS = 11, 10    # 11 / 10 segments keep the case <= 150 and the round <= 200 triangles
# .338 case / round lathe profiles (x mm from the head, radius mm); the head cap carries the primer in its
# material (CaseHead), the spent mouth is capped dark (Bore) so it reads hollow
CASE_PROF = [(0.0, 7.25), (1.4, 7.44), (2.3, 6.35), (3.1, 7.44), (58.7, 6.80), (61.3, 4.60), (69.2, 4.60)]
BULLET_PROF = [(77.0, 4.29), (86.0, 3.30), (93.3, 0.70)]


def lathe_capped(bm, prof, segs, M, mats, cap0, cap1):
    """Revolve [(x, r)] about local X with n-gon end caps; mats[i] = material of band i."""
    n0 = len(bm.faces)
    rings = []
    for x, r in prof:
        rings.append([bm.verts.new(M @ V(mm(x, r * math.cos(2 * math.pi * k / segs),
                                              r * math.sin(2 * math.pi * k / segs)))) for k in range(segs)])
    for i, (A, B) in enumerate(zip(rings[:-1], rings[1:])):
        for k in range(segs):
            k1 = (k + 1) % segs
            f = bm.faces.new((A[k], A[k1], B[k1], B[k]))
            f.material_index = mats[i]
    f0 = bm.faces.new(list(reversed(rings[0])))
    f0.material_index = cap0
    f1 = bm.faces.new(rings[-1])
    f1.material_index = cap1
    bm.faces.ensure_lookup_table()
    new = bm.faces[n0:]
    bmesh.ops.recalc_face_normals(bm, faces=new)
    bmesh.ops.triangulate(bm, faces=[f0, f1], quad_method='BEAUTY', ngon_method='BEAUTY')


def build_338(bm, M, mi, spent):
    """mi = {'case', 'head', 'bullet', 'mouth'} material indices.  Spent: open (dark) mouth; loaded: bullet."""
    if spent:
        lathe_capped(bm, CASE_PROF, CASE_SEGS, M, [mi['case']] * (len(CASE_PROF) - 1), mi['head'], mi['mouth'])
    else:
        prof = CASE_PROF + BULLET_PROF
        mats = [mi['case']] * (len(CASE_PROF) - 1) + [mi['bullet']] * len(BULLET_PROF)
        lathe_capped(bm, prof, ROUND_SEGS, M, mats, mi['head'], mi['bullet'])


def mag_ring(x0, z, depth, width, r=3.0):
    sec = gk.rrect2(x0, 0.0, depth / 2, width / 2, r_pos=r, r_neg=r, n=2)
    return [mm(x, y, z) for x, y in sec]


MAG_TOP_ROUNDS = ((0.0, -3.4), (-4.4, -13.6))   # (y, z below the lip top) of the two visible rounds' axes


def build_magazine(gun):
    x0, zt = MAGWELL
    org = (x0, 0, zt)
    mg = gun.part('Magazine', paint='SteelBlued', origin=mm(*org), fit=4)
    St, Ba, Po, Bo = mg.mi('SteelBlued'), mg.mi('SteelBare'), mg.mi('Polymer'), mg.mi('Bore')
    bm = mg.bm
    zb = zt - MAG_LEN + 9.0                        # body bottom (the 9 mm baseplate below)
    tw = MAG_W - 4.0                               # the lips curl in to this width
    T = MAG_T
    # hollow sheet body: open between the curled lips, a dark well down to the second round
    outer = [mag_ring(x0, z, MAG_DEPTH, w) for z, w in ((zb, MAG_W), (zt - 12.0, MAG_W), (zt - 4.0, tw), (zt, tw))]
    inner = [mag_ring(x0, z, MAG_DEPTH - 2 * T, w - 2 * T, 1.8)
             for z, w in ((zt - 25.0, MAG_W), (zt - 12.0, MAG_W), (zt - 4.0, tw), (zt, tw))]
    body = bmesh.new()
    gk.loft(body, outer, inner=inner, mi=St)
    for f in body.faces:
        c = f.calc_center_median()
        inside = abs(c.y) < mm(MAG_W / 2 - T * 0.5) and abs(c.x - mm(x0)) < mm(MAG_DEPTH / 2 - T * 0.5)
        if inside and c.z < mm(zt) - 1e-5:
            f.material_index = Bo
        elif c.z > mm(zt) - 1e-5:
            f.material_index = St                  # the lip edges (the steel's edge wear shows the rounds' rub)
    # round-count witness holes on the left side
    cuts = []
    for k in range(5):
        c = bmesh.new()
        gk.cyl(c, mm(x0 - 30.0, MAG_W / 2 - 2.5, zt - 34.0 - k * 15.0), mm(x0 - 30.0, MAG_W / 2 + 2.0, zt - 34.0 - k * 15.0),
               mm(2.4), 10, mi=Bo)
        cuts.append(c)
    gk.boolean_bm(body, cuts)
    gk.merge(bm, body)
    body.free()
    # stamped stiffening ribs: two on each side, one down the front and the back faces
    for sy in (1, -1):
        for dx in (-12.0, 22.0):
            gk.box(bm, mm(x0 + dx, sy * (MAG_W / 2 + 0.25), (zb + zt - 16.0) / 2 - 3.0), mm(4.5, 1.2, zt - 16.0 - zb - 12.0),
                   mi=St)
    for sx in (1, -1):
        gk.box(bm, mm(x0 + sx * (MAG_DEPTH / 2 + 0.25), 0, (zb + zt) / 2 - 6.0), mm(1.2, 9.0, zt - zb - 26.0), mi=St)
    # catch notch plate on the rear face (the release lever's hook)
    gk.rbox(bm, mm(x0 - MAG_DEPTH / 2 - 1.2, 0, zt - 22.0), mm(2.2, 14.0, 8.0), mm(0.6), 1, mi=St)
    # polymer baseplate, overhanging, with grip ridges
    gk.rbox(bm, mm(x0 + 0.5, 0, zb - 4.5), mm(MAG_DEPTH + 5.0, MAG_W + 2.4, 9.0), mm(1.6), 2, mi=Po)
    for k in range(5):
        gk.box(bm, mm(x0 - 30.0 + k * 15.0, 0, zb - 9.6), mm(3.0, MAG_W + 1.0, 1.6), mi=Po)
    # the two rounds seen between the lips (one part: hidden together when the mag is empty)
    head = V(mm(x0 - MAG_DEPTH / 2 + T + 0.6, 0.0, zt + MAG_TOP_ROUNDS[0][1]))
    rt = gun.part('MagRoundTop', paint='Brass', parent='Magazine', origin=tuple(head))
    mi = {'case': rt.mi('Brass'), 'head': rt.mi('CaseHead'), 'bullet': rt.mi('Copper'), 'mouth': rt.mi('Bore')}
    for y, dz in MAG_TOP_ROUNDS:
        build_338(rt.bm, gk.frame_x(V((head.x, mm(y), mm(zt + dz))), (1, 0, 0)), mi, spent=False)
    # follower (shown in the empty mag): just under the lips
    fo = gun.part('MagFollower', paint='Polymer', parent='Magazine', origin=mm(*org))
    Fp = fo.mi('PolymerGrey')
    # the follower rides up against the lips when empty: a stepped plate whose raised (staggered) top shows
    # between the lips from any angle
    gk.rbox(fo.bm, mm(x0, 0, zt - 11.5), mm(MAG_DEPTH - 2 * T - 0.6, MAG_W - 2 * T - 0.8, 4.0), mm(1.2), 1, mi=Fp)
    gk.rbox(fo.bm, mm(x0 - 4.0, -2.0, zt - 7.5), mm(MAG_DEPTH - 22.0, 14.0, 4.0), mm(1.0), 1, mi=Fp)
    return mg, rt, fo, None


def build_case_round(col):
    out = {}
    for name, spent in (('Sniper_Case', True), ('Sniper_Round', False)):
        bm = bmesh.new()
        mats = ['Brass', 'CaseHead', 'Copper', 'Bore']
        build_338(bm, Matrix(), {'case': 0, 'head': 1, 'bullet': 2, 'mouth': 3}, spent)
        com = gk.bm_volume_com(bm)
        ob = gk.single_object(col, name, bm, mats, origin=com)
        ob.data.set_sharp_from_angle(angle=math.radians(50))     # smooth round, sharp rim / shoulder steps
        out[name] = ob
    return out


# --------------------------------------------------------------------------------------
# the model
# --------------------------------------------------------------------------------------
STOCK_PARTS = ('Stock', 'CheekPiece', 'ButtPad', 'Monopod')


def build_model():
    gun = gk.GunModel(GID, mass=7.5)
    build_receiver(gun)
    build_barrel(gun)
    build_muzzle(gun)
    build_stock(gun)
    build_cheek(gun)
    build_buttpad(gun)
    build_monopod(gun)
    build_optic(gun)
    build_bolt(gun)
    build_safety(gun)
    build_trigger(gun)
    build_mag_release(gun)
    build_bipod(gun)
    _, _, _, frame_at = build_magazine(gun)
    # hinges (ARCHITECTURE §5.2)
    gun.hinge('Bolt', 'rotate', (1, 0, 0), 0.0, mn=-LIFT, pivot=(0, 0, 0),
              then={'type': 'slide', 'axis': [-1, 0, 0], 'rest': 0, 'max': mm(STROKE)},
              note='turns about the bore axis to -60 (handle up), then slides back 115 mm; carries BoltHandle')
    gun.hinge('MagRelease', 'rotate', (0, 1, 0), 0.0, mn=-10.0, note='lever ahead of the guard, pushed forward')
    gun.hinge('Safety', 'rotate', (0, 1, 0), 15.0, note='0 = FIRE (exported), 15 = SAFE')
    gun.hinge('CheekPiece', 'slide', (0, 0, 1), mm(30.0), note='cheek riser height')
    gun.hinge('ButtPad', 'slide', (-1, 0, 0), mm(40.0), note='length of pull')
    for s in ('L', 'R'):
        gun.hinge('BipodLeg' + s, 'rotate', (0, 1, 0), 90.0, pivot=mm(*BIPOD_PIVOT),
                  note='folded forward at rest; +90 swings the leg down (splay 3 deg baked so the folded legs lie along the fore-end)')
        d = leg_dir(1 if s == 'L' else -1)
        gun.hinge('BipodExt' + s, 'slide', [round(c, 5) for c in d], mm(80.0), note='along the leg (rest frame)')
    gun.hinge('Trigger', 'rotate', (0, 1, 0), 8.0)
    gun.hinge('Magazine', 'slide', (0, 0, -1), mm(140.0), then='detach', note='drops straight out along MagWell +X')
    # markers (ARCHITECTURE §5.3)
    gun.marker('Muzzle', mm(MUZZLE_X, 0, 0))
    ej = V((0.0, -math.cos(math.radians(30)), math.sin(math.radians(30))))
    gun.marker('EjectionPort', mm(-42.0, -15.5, 6.0), ej, (0, -0.95, 0.3))
    gun.marker('CasingSpawn', mm(-80.0, -24.0, 8.0), (1, 0, 0), (0, -0.5, 0.86))
    gun.marker('MagWell', mm(MAGWELL[0], 0, MAGWELL[1]), (0, 0, -1), (1, 0, 0))
    zr = V(GRIP_R_Z).normalized()
    xr = (V((0, 0, 1)) - zr * zr.z).normalized()
    xr = Matrix.Rotation(math.radians(GRIP_R_TWIST), 3, zr) @ xr
    gun.marker('GripR', mm(*GRIP_R), xr, zr)
    zl = V(GRIP_L_Z).normalized()
    gun.marker('GripL', mm(*GRIP_L), (V((0, 0, 1)) - zl * zl.z).normalized(), zl)
    gun.marker('Shoulder', mm(BUTT_X, 0, SHOULDER_Z), (1, 0, 0), (0, 0, 1))
    pe, de = scope_eye()
    gun.marker('SightEye', pe, de, (0, 0, 1))
    gun.marker('CoM', mm(-30.0, 0, -12.0))
    gun.marker('BackMount', mm(-60.0, 0, -20.0), (1, 0, 0), (0, 0, 1))
    gun.marker('MagGrab', mm(MAGWELL[0] + 20.0, 0, MAGWELL[1] - 95.0), (0, 0, -1), (0.15, 0.85, -0.5))
    end, d, kc = knob_frame()
    gun.marker('BoltKnob', kc, (-1, 0, 0), (0, -0.6, -0.8))
    # the bolt-cycle hand frame for the solver: the knob after the lift (-60 about +X), hand->elbow back, right, down
    R = Matrix.Rotation(math.radians(-LIFT), 3, 'X')
    kc_up = R @ kc
    zb = V(BOLT_GRIP_Z).normalized()
    xb = (V((0, 0, 1)) - zb * zb.z).normalized()
    gun.marker('BoltGrip', kc_up, xb, zb)
    gun.marker('MagRelease', mm(-85.0, 0, -66.0), (1, 0, 0), (0, 0, 1))
    gun.marker('BipodPivot', mm(*BIPOD_PIVOT), (1, 0, 0), (0, 0, 1))
    gun.marker('BipodFoot', bipod_foot(0.0), (1, 0, 0), (0, 0, 1))
    gun.separate = {'Case': 'Sniper_Case.fbx', 'Round': 'Sniper_Round.fbx', 'Mag': 'Sniper_Mag.fbx',
                    'MagEmpty': 'Sniper_MagEmpty.fbx'}
    gun.colliders = {'Magazine': {'size': [round(mm(MAG_LEN), 4), round(mm(MAG_W + 2), 4), round(mm(MAG_DEPTH + 5), 4)],
                                  'axes': 'magazine local: +X down the mag (MagWell +X), +Y left, +Z its front',
                                  'massKg': 0.42, 'massEmptyKg': 0.21}}
    gun.extra['atlases'] = {'Sniper': 'metal, optic, magazine, bipod (Sniper_*.png)',
                            'Sniper_Stock': 'Stock, CheekPiece, ButtPad, Monopod (Sniper_Stock_*.png)'}
    gun.extra['notes'] = {'BoltGrip': 'solver-only frame: the right hand on the knob with the bolt lifted (-60)',
                          'BipodFoot': 'left foot, legs deployed (+90), extensions in; +80 mm with BipodExt'}
    return gun


# --------------------------------------------------------------------------------------
# the model contract (ARCHITECTURE §5), checked on every build until tools/guns/check_model.py exists
# --------------------------------------------------------------------------------------
REQUIRED_PARTS = ('Receiver', 'Barrel', 'Magazine', 'MagRoundTop', 'Trigger', 'Optic', 'OpticLens', 'Stock', 'ButtPad',
                  'Bolt', 'BoltHandle', 'MagRelease', 'Safety', 'CheekPiece', 'BipodLegL', 'BipodLegR', 'BipodExtL',
                  'BipodExtR')
REQUIRED_MARKERS = ('Muzzle', 'EjectionPort', 'CasingSpawn', 'MagWell', 'GripR', 'GripL', 'Shoulder', 'SightEye', 'CoM',
                    'BackMount', 'MagGrab', 'BoltKnob', 'MagRelease', 'BipodPivot', 'BipodFoot')
GUN_TRI_CAP = 20000               # the player's brief for long guns (15-20k); the §5.1 figure (8 000) is noted
CONTRACT_GUN_TRIS = 8000


def check_contract(gun, objs, tris, tri_gun, tri_mag, tri_ammo, dims):
    bad, warn = [], []
    for n in REQUIRED_PARTS:
        if n not in objs:
            bad.append('missing part %s' % n)
    for n, ob in objs.items():
        if '.' in ob.name or ob.name != n:
            bad.append('object name %r' % ob.name)
        if any(abs(c - 1.0) > 1e-6 for c in ob.scale):
            bad.append('%s scale not applied' % n)
        if tris[n] >= 20000:
            bad.append('%s over the 20k mesh limit' % n)
    for n in REQUIRED_MARKERS:
        if n not in gun.markers:
            bad.append('missing marker %s' % n)
            continue
        _, X, Z = gun.markers[n]
        if abs(X.length - 1) > 1e-4 or abs(Z.length - 1) > 1e-4 or abs(X.dot(Z)) > 1e-4:
            bad.append('marker %s not orthonormal' % n)
    for k, target in (('length', 1.230), ('barrel', 0.686)):
        if abs(dims[k] / target - 1.0) > 0.03:
            bad.append('%s %.3f vs %.3f +-3%%' % (k, dims[k], target))
    n_parts = len([n for n in gun.order if n != 'MagFollower'])
    if n_parts > 25:
        bad.append('%d MeshParts > 25' % n_parts)
    if tri_ammo['Sniper_Case'] > 150:
        bad.append('case %d tris > 150' % tri_ammo['Sniper_Case'])
    if tri_ammo['Sniper_Round'] > 200:
        bad.append('round %d tris > 200' % tri_ammo['Sniper_Round'])
    if tri_mag > 1200:
        bad.append('mag %d tris > 1200' % tri_mag)
    if tri_gun > GUN_TRI_CAP:
        bad.append('gun %d tris > %d' % (tri_gun, GUN_TRI_CAP))
    elif tri_gun > CONTRACT_GUN_TRIS:
        warn.append('gun %d tris: over the ARCHITECTURE 5.1 figure (%d), inside the brief for long guns (<= %d)'
                    % (tri_gun, CONTRACT_GUN_TRIS, GUN_TRI_CAP))
    m = gun.markers
    if m['EjectionPort'][2].y > -0.5:
        bad.append('EjectionPort normal not on the right side')
    if m['Muzzle'][0].x < dims['length'] - 0.473 - 0.002:
        bad.append('Muzzle not at the front')
    print('CONTRACT', 'OK' if not bad else 'FAIL %s' % bad, ('WARN %s' % warn) if warn else '', flush=True)
    return bad


def gun_samples():
    """Model-space points for the solver's penetration tests (barrel, scope, receiver, mag, grip, butt underside;
    the comb under the cheek and the butt face are left out: the cheek weld and the pocket are wanted)."""
    pts = []
    for x in (757, 680, 600, 500, 400, 300, 200, 120):
        for z in (-14, 14):
            pts.append(mm(x, 0, z))
    for x in (300, 200, 100):
        pts.append(mm(x, 0, -46))
    for x in (130, 80, 0, -80, -150, -190):
        for z in (45, 85):
            pts.append(mm(x, 0, z))
    for x in (90, 0, -90, -150):
        for y in (-16, 16):
            pts.append(mm(x, y, 0))
    for x in (-70, 20):
        for z in (-80, -128):
            pts.append(mm(x, 0, z))
    pts += [mm(-165, 0, -140), mm(-235, 0, -142), mm(-116, 0, -90)]
    pts += [mm(-430, 0, -128), mm(-350, 0, -128), mm(-280, 0, -128)]
    return pts


# --------------------------------------------------------------------------------------
# stances (ARCHITECTURE §7.3) and the sniper's hold solver
# --------------------------------------------------------------------------------------
# The shoulder pocket (Torso space).  The Shoulder marker is on the upper third of the pad, the scope axis
# 95 mm (0.34 stud) above it; the R6 eye is 0.6 stud above the torso top, so with the butt on the raised
# arm block at y ~1.05 the head only has to drop ~0.2 stud (pitch <= 25 deg) to reach the line.
POCKET_HIGH = (0.72, 1.05, -0.45)
RHAND = (0.0, -0.92, float(os.environ.get('RHAND_Z', '-0.30')))     # grip point: toward the arm's front face
SUPPORT_HAND = (0.0, -0.92, -0.45)       # the fore-end rests on the top (front) face of the left arm block
ROOT_ROLL_MAX, NECK_PITCH_MAX, NECK_ROLL_MAX = 3.0, 25.0, 12.0
WRIST_MAX = 25.0
CAMS = ((0.8, 0.35, -1.0), (1.0, 0.08, 0.0))   # HRP-space view directions of the 3/4 front and right side renders
# per stance: aim (yaw, pitch, cant), blade / lean as HARD bounds (target +- tol), eye on the scope line
# ('line', checked <= eye_tol) or a set height above it ('over' +- 0.10), shouldered pocket, left target
STANCES = [
    dict(name='Aim', pitch=0.0, shoulder=True, pocket=POCKET_HIGH, eye='line', eye_t=(-0.10, 0.10), w_eye=30.0,
         eye_tol=0.15, blade=-50.0, blade_tol=15.0, lean=-10.0, lean_tol=7.0, w_wrist=4.0, wrist_limit=WRIST_MAX,
         left_limit=35.0, rs_ref=(85, 0, 20), ls_ref=(85, 0, -45), front=14.0, w_left=14.0, w_butt=6.0,
         head_clear=0.0, w_occl=3.0, lhand=SUPPORT_HAND, w_cant=4.0),
    dict(name='Ready', pitch=-10.0, shoulder=True, pocket=POCKET_HIGH, eye='over', eye_over=0.30, blade=-45.0,
         blade_tol=15.0, lean=-6.0, lean_tol=6.0, head_pitch=-8.0, wrist_limit=WRIST_MAX, left_limit=35.0,
         rs_ref=(75, 0, 20), ls_ref=(75, 0, -45), front=12.0, w_left=14.0, w_butt=6.0, head_clear=0.0, w_occl=3.0,
         lhand=SUPPORT_HAND, w_cant=5.0),
    dict(name='LowReady', pitch=-38.0, shoulder=True, pocket=(0.72, 0.85, -0.35), blade=-38.0, blade_tol=15.0,
         lean=-5.0, lean_tol=6.0, head_pitch=-14.0, wrist_limit=WRIST_MAX, left_limit=50.0, rs_ref=(45, 0, 15),
         ls_ref=(45, 0, -40), front=10.0, w_left=14.0, w_butt=5.0, w_occl=2.0, lhand=SUPPORT_HAND, w_cant=5.0),
    dict(name='BoltCycle', grip='BoltGrip', pitch=0.0, cant=4.0, shoulder=True, pocket=POCKET_HIGH, eye='line',
         eye_t=(-0.12, 0.12), w_eye=30.0, eye_tol=0.15, blade=-50.0, blade_tol=15.0, lean=-10.0, lean_tol=7.0,
         w_wrist=4.0, wrist_limit=WRIST_MAX, left_limit=35.0, rs_ref=(70, 0, 30), ls_ref=(85, 0, -45), front=14.0,
         w_left=22.0, w_butt=6.0, head_clear=0.0, w_occl=2.0, lhand=SUPPORT_HAND, w_cant=4.0),
    dict(name='ReloadMag', pitch=-12.0, yaw=8.0, cant=9.0, w_cant=2.0, shoulder=True, pocket=(0.75, 0.6, -0.5),
         w_butt=4.0, blade=-40.0, blade_tol=15.0, lean=-8.0, lean_tol=6.0, look='gun', wrist_limit=WRIST_MAX,
         rs_ref=(60, 0, 30), ls_ref=(60, 0, -30), front=12.0, left='MagGrab', left_limit=50.0, w_left=14.0,
         w_occl=1.0),
]


class SniperHoldSolver(gk.HoldSolver):
    """gk.HoldSolver plus this gun's review terms (the kit is frozen):
    - the right grip point RHAND and a per-stance support hand point `lhand` (arm faces, not centre lines),
      so the gun sits against the arm blocks instead of inside them;
    - HARD bounds: Root roll |rz| <= 3 (the legs only follow pitch, so roll would lift a foot), blade and lean
      within their stance tolerance, neck pitch <= 25 and roll <= 12;
    - the Root drops so the lowest foot is on y = -3 and both feet stay level;
    - no head inside the right arm block, no gun inside the arm blocks (away from the hands), and the share
      of the gun hidden from the 3/4-front / right-side cameras."""

    def __init__(self, gun, samples, grip='GripR', rhand=RHAND):
        import numpy as np
        super().__init__(gun, samples, grip=grip)
        self.rhand = tuple(rhand)
        self.cams = [np.array(c, float) / np.linalg.norm(c) for c in CAMS]
        g = np.array(self.G_grip[:3, 3])
        gl = np.array(self.m['GripL'][:3, 3])
        mg = np.array(self.m['MagGrab'][:3, 3])
        d = lambda c: np.linalg.norm(self.samples - c, axis=1)
        self.away_r = d(g) > 0.45                   # samples not in the right hand (studs)
        self.away_l = (d(gl) > 0.35) & (d(mg) > 0.35)
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
        # occlusion from the two review cameras (ray from each sample toward the camera through the boxes)
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
        if st.get('w_occl'):
            r.append(max(0.0, e['occl'] - 0.35) * st['w_occl'])
        if 'eye_over' in e:
            r.append(max(0.0, abs(e['eye_over'] - st['eye_over']) - 0.05) * 20.0)
        return np.array(r, float)

    def solve(self, st, starts=24, seed=1, x0=None):
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
            v = base + rng.normal(0, 1, 15) * np.array([4, 8, 1.5, 10, 15, 4, 45, 45, 45, 45, 45, 45, 10, 10, 10])
            inits.append(v)
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
    """The stance's hard limits (as pyro_clips.py --check): returns a list of violations."""
    res, p = r['residuals'], r['pose']
    bad = []
    lean, blade, roll = p['Root'][0], p['Root'][1], p['Root'][2]
    if abs(lean - st['lean']) > st['lean_tol'] + 0.05:
        bad.append('lean %.1f vs %.0f+-%.0f' % (lean, st['lean'], st['lean_tol']))
    if abs(blade - st['blade']) > st['blade_tol'] + 0.05:
        bad.append('blade %.1f vs %.0f+-%.0f' % (blade, st['blade'], st['blade_tol']))
    if abs(roll) > ROOT_ROLL_MAX + 0.05:
        bad.append('root roll %.1f' % roll)
    nk = p['Neck']
    if abs(nk[0]) > NECK_PITCH_MAX + 0.05 or abs(nk[2]) > NECK_ROLL_MAX + 0.05:
        bad.append('neck %s' % (nk,))
    if res['wristDeg'] > st.get('wrist_limit', WRIST_MAX) + 0.3:
        bad.append('wrist %.1f' % res['wristDeg'])
    if res.get('left', 0.0) > 0.10:
        bad.append('left hand %.3f stud' % res['left'])
    if res.get('leftAngleDeg', 0.0) > st.get('left_limit', 35.0) + 3.0:
        bad.append('left arm angle %.1f' % res['leftAngleDeg'])
    if st.get('eye') == 'line' and res.get('eyeToSightLine', 0.0) > st.get('eye_tol', 0.15):
        bad.append('eye to line %.3f stud' % res['eyeToSightLine'])
    if st.get('eye') == 'over' and abs(res.get('eyeOver', 0.0) - st['eye_over']) > 0.10:
        bad.append('eye over %.3f vs %.2f' % (res.get('eyeOver', 0.0), st['eye_over']))
    if abs(res['cantDeg'] - st.get('cant', 0.0)) > 8.0:
        bad.append('cant %.1f vs %.0f' % (res['cantDeg'], st.get('cant', 0.0)))
    if res['headInRightArm'] > 0.06:
        bad.append('head in right arm %.3f' % res['headInRightArm'])
    if abs(res['feetY'][0] - res['feetY'][1]) > 0.05:
        bad.append('feet %s' % (res['feetY'],))
    return bad


def solve_holds(gun, out_json, strict=True):
    import numpy as np
    samples = gun_samples()
    solvers = {'GripR': SniperHoldSolver(gun, samples), 'BoltGrip': SniperHoldSolver(gun, samples, grip='BoltGrip')}
    results, failures = [], []
    M2G = np.array(gk.M2G, float)
    for st0 in STANCES:
        st = dict(st0)
        grip = st.pop('grip', 'GripR')
        sv = solvers[grip]
        r = sv.solve(st, starts=16)
        e = r['_eval']
        r['grip'] = grip
        r['rightHand'] = list(sv.rhand)
        r['supportHand'] = list(st.get('lhand') or gk.HAND)
        r['residuals']['cantDeg'] = round(math.degrees(math.asin(max(-1.0, min(1.0, float(-e['right'][1]))))), 1)
        r['residuals'].update({'headRollDeg': round(e['head_roll'], 1), 'headPitchDeg': round(e['head_pitch'], 1),
                               'headInRightArm': round(e['head_in_rarm'], 3), 'gunInArms': round(e['gun_in_arms'], 3),
                               'gunVisible': round(e['visible'], 2), 'feetY': [round(v, 3) for v in e['feet']]})
        if 'eye_over' in e:
            r['residuals']['eyeOver'] = round(e['eye_over'], 3)
        bad = check_hold(r, st0)
        r['check'] = 'ok' if not bad else bad
        print('HOLD %-10s cost %.4f %s residuals %s pose %s wrist %s' % (r['name'], r['cost'], 'OK' if not bad else
                                                                        'FAIL %s' % bad, r['residuals'], r['pose'],
                                                                        r['wrist']), flush=True)
        N = sv.G_grip[:3, :3] @ gk.rotvec(r['wrist']).T
        larm = e['G'][:3, :3].T @ e['F']['Left Arm'][:3, 1]
        print('   hint %s x %s z %s ; left arm (hand->shoulder) in model %s' % (
            grip, np.round(M2G.T @ N[:, 0], 3), np.round(M2G.T @ N[:, 2], 3), np.round(M2G.T @ larm, 3)), flush=True)
        if bad:
            failures.append((r['name'], bad))
        results.append(r)
    gk.holds_to_json(out_json, GID, results, extra={
        'note': 'Solved by tools/guns/sniper.py (SniperHoldSolver over gunkit.HoldSolver). R6: rigid arms; the weld '
                '(Right Arm space) is the only wrist (<= 25 deg off GripR / BoltGrip). rightHand / supportHand are '
                'the hand points in arm space: on the arm blocks\' front faces, so the gun rides against the blocks '
                'instead of through their centre lines. Hard limits per stance (checked, see "check"): blade and '
                'lean within the stance tolerance, Root roll <= 3 deg (the hips only counter pitch), neck pitch '
                '<= 25 and roll <= 12, eye within 0.15 stud of the scope line (Aim, BoltCycle; the first-person '
                'scope view comes from the camera), feet level on y = -3. BoltCycle: the right hand on the lifted '
                'bolt knob (bolt at -60 deg), cheek on the stock. ReloadMag: stock low in the pocket, gun canted '
                '9 deg, the left hand on the seated magazine (MagGrab).',
        'markers': {k: [round(c, 5) for c in gun.markers[k][0]] for k in ('GripR', 'GripL', 'SightEye', 'Shoulder',
                                                                         'MagGrab', 'BoltKnob', 'BoltGrip')}})
    if failures and strict:
        raise SystemExit('HOLD CHECK FAILED: %s' % failures)
    return results


# --------------------------------------------------------------------------------------
# renders
# --------------------------------------------------------------------------------------

def place(objs, gun, name, M):
    """Pose part `name` by the model-space transform M (relative to its parent's rest frame)."""
    p = gun.parts[name]
    off = gun.parts[p.parent].origin if p.parent else V((0, 0, 0))
    objs[name].matrix_basis = Matrix.Translation(-off) @ M @ Matrix.Translation(p.origin)


def rot_y(piv, deg):
    p = V(piv)
    return Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, 'Y') @ Matrix.Translation(-p)


def set_pose(objs, gun, bolt_rot=0.0, bolt_back=0.0, trigger=0.0, safety=0.0, release=0.0, mag_out=0.0, cheek=0.0,
             pad=0.0, bipod=0.0, ext=0.0):
    place(objs, gun, 'Bolt', Matrix.Translation(V((-bolt_back, 0, 0))) @ Matrix.Rotation(math.radians(bolt_rot), 4, 'X'))
    place(objs, gun, 'Trigger', rot_y(mm(*TRIG_PIVOT), trigger))
    place(objs, gun, 'Safety', rot_y(mm(*SAFE_PIVOT), safety))
    place(objs, gun, 'MagRelease', rot_y(mm(*REL_PIVOT), release))
    place(objs, gun, 'Magazine', Matrix.Translation(V((0, 0, -mag_out))))
    place(objs, gun, 'CheekPiece', Matrix.Translation(V((0, 0, cheek))))
    place(objs, gun, 'ButtPad', Matrix.Translation(V((-pad, 0, 0))))
    for s, sy in (('L', 1), ('R', -1)):
        place(objs, gun, 'BipodLeg' + s, rot_y(mm(*BIPOD_PIVOT), bipod))
        place(objs, gun, 'BipodExt' + s, Matrix.Translation(leg_dir(sy) * ext))
    bpy.context.view_layer.update()


def prep_reference(src, out):
    """The reference photo (already level) upscaled, its white background made transparent."""
    import numpy as np
    from PIL import Image
    from scipy import ndimage
    im = Image.open(src).convert('RGBA')
    im = im.resize((im.width * 4, im.height * 4), Image.LANCZOS)
    a = np.array(im).astype(float)
    mask = (a[:, :, :3].sum(2) < 600)
    mask = ndimage.binary_closing(mask, iterations=2)
    a[:, :, 3] = mask * 255
    r = Image.fromarray(a.astype('uint8'))
    ys, xs = np.nonzero(mask)
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

    def shot(name, view, res=(1600, 900), bbox=None, **kw):
        gk.set_res(*res)
        rig.frame(bbox or (lo, hi), view, **kw)
        p = os.path.join(out, name + '.png')
        gk.render(p)
        files.append(p)
        return p

    d = info['dims']
    tri_line = 'gun FBX %d tris (seated mag + top rounds %d included), %d parts; L %.0f mm, H %.0f mm, W %.0f mm' % (
        info['tri_gun'], info['tri_mag'], len(gun_names), d['length'] * 1000, d['height'] * 1000,
        d['width'] * 1000)
    if want('01') or want('12'):
        # the reference shows the RIGHT side with the bipod deployed: same framing here
        set_pose(objs, gun, bipod=90.0)
        lo1, hi1 = gk.world_bbox(gobjs)
        floor.hide_render = True
        sc.render.film_transparent = True
        gk.set_res(1900, 1000)
        rig.frame((lo1, hi1), (0, -1, 0), ortho=True, margin=1.04)
        pa = os.path.join(out, '_01_side_alpha.png')
        gk.render(pa)
        sc.render.film_transparent = False
        floor.hide_render = False
        im = Image.open(pa).convert('RGBA')
        bg = Image.new('RGBA', im.size, (226, 226, 224, 255))
        p1 = os.path.join(out, '01_side_right_ortho.png')
        Image.alpha_composite(bg, im).convert('RGB').save(p1)
        ref = args.ref or REF_DEFAULT
        if os.path.exists(ref):
            lv = prep_reference(ref, os.path.join(out, '_ref_level.png'))
            pc, iou = gk.ref_compare(lv, p1, pa, os.path.join(out, '12_reference_compare.png'),
                                     title='.338 BOLT RIFLE side profile (bipod down as in the photo)')
            info['iou'] = iou
            files.append(pc)
        gk.caption(p1, ['.338 BOLT RIFLE - right side, orthographic (reference framing, bipod deployed)', tri_line],
                   color=(30, 30, 30))
        files.append(p1)
        set_pose(objs, gun)
    if want('02'):
        shot('02_three_quarter_front', (0.85, -0.8, 0.38), lens=50)
    if want('03'):
        shot('03_three_quarter_back', (-0.8, 0.85, 0.45), lens=50)
    if want('04'):
        shot('04_top', (0, 0, 1), ortho=True, up=(0, 1, 0), margin=1.05, res=(1900, 500))
    if want('05'):
        shot('05_left_side_rest', (0, 1, 0), ortho=True, margin=1.04, res=(1900, 650))
    if want('06'):
        shot('06_closeup_action', (-0.35, -1.0, 0.45), lens=70, margin=1.0,
             bbox=(V(mm(-240, -60, -150)), V(mm(80, 30, 110))))
    if want('08'):
        set_pose(objs, gun, bolt_rot=-LIFT, bolt_back=mm(STROKE), trigger=8.0, safety=0.0, release=-10.0,
                 mag_out=0.07, cheek=mm(30.0), pad=mm(40.0), bipod=90.0, ext=mm(80.0))
        p = shot('08_cycle_pose', (0.25, -1.0, 0.3), lens=55, res=(1600, 1000),
                 bbox=(V(mm(-520, -80, -420)), V(mm(420, 40, 120))))
        gk.caption(p, ['bolt lifted 60 deg and drawn back 115 mm, magazine released (lever -10) and dropping, '
                       'trigger +8,', 'cheek riser +30 mm, butt pad out 40 mm (length of pull), bipod down '
                       '(+90) with legs extended 80 mm'])
        p = shot('08b_cycle_pose_top', (0, 0, 1), ortho=True, up=(1, 0, 0), res=(1400, 900),
                 bbox=(V(mm(-480, -70, -60)), V(mm(-60, 70, 60))))
        gk.caption(p, ['bolt fully back (115 mm) from above: the shroud clears the cheek riser (front x -318) '
                       'and the comb (wrist top z -15.5)'])
        set_pose(objs, gun)
    if want('07'):
        offs = {'Optic': V((0, 0, 0.09)), 'Bolt': V((-0.06, -0.10, 0.03)), 'MuzzleDevice': V((0.06, 0, 0)),
                'CheekPiece': V((0, 0, 0.07)), 'ButtPad': V((-0.07, 0, 0)), 'Monopod': V((0, 0, -0.06)),
                'Safety': V((-0.02, -0.07, 0.04)), 'Trigger': V((0, 0, -0.06)), 'MagRelease': V((0.0, -0.04, -0.07)),
                'Magazine': V((0.03, 0, -0.12)), 'BipodYoke': V((0, 0, -0.08)), 'Receiver': V((0, 0, 0.03)),
                'Barrel': V((0.0, 0, 0.03))}
        base = {n: objs[n].matrix_basis.copy() for n in offs}
        for n, dv in offs.items():
            objs[n].matrix_basis = Matrix.Translation(dv) @ base[n]
        bpy.context.view_layer.update()
        lo2, hi2 = gk.world_bbox(gobjs)
        gk.set_res(1900, 1100)
        rig.frame((lo2, hi2), (0.2, -1, 0.3), lens=50, margin=1.06)
        # black parts on a light backdrop (on the shadowed studio floor the monopod and magazine vanished)
        floor.hide_render = True
        sc.render.film_transparent = True
        p = os.path.join(out, '07_exploded.png')
        gk.render(p)
        sc.render.film_transparent = False
        floor.hide_render = False
        im = Image.open(p).convert('RGBA')
        Image.alpha_composite(Image.new('RGBA', im.size, (214, 214, 210, 255)), im).convert('RGB').save(p)
        items = []
        for n, (dx, dy) in (('Receiver', (0, -60)), ('Barrel', (40, -60)), ('MuzzleDevice', (0, -50)),
                            ('Optic', (0, -60)), ('OpticLens', (-60, -30)), ('Bolt', (-40, 60)),
                            ('BoltHandle', (40, 50)), ('Stock', (300, -10)), ('CheekPiece', (0, -50)),
                            ('ButtPad', (-40, -50)), ('Monopod', (-60, 60)), ('Safety', (-60, -40)),
                            ('Trigger', (40, 90)), ('MagRelease', (-120, 120)), ('Magazine', (90, 50)),
                            ('MagRoundTop', (70, -30)), ('BipodYoke', (-40, 60)), ('BipodLegR', (60, 60)),
                            ('BipodLegL', (-60, -50)), ('BipodExtL', (70, -50)), ('BipodExtR', (110, 40))):
            blo, bhi = gk.world_bbox([objs[n]])
            items.append((n, (blo + bhi) / 2, (dx, dy)))
        gk.label_points(p, items, size=19)
        gk.caption(p, ['exploded (right side): named parts of the FBX; moving: Bolt (+BoltHandle), Safety, Trigger, '
                       'MagRelease, Magazine, CheekPiece, ButtPad, BipodLeg/Ext L+R'])
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
        empty.matrix_world = Matrix.Translation(V((0.11, -0.065, 0))) @ mag.matrix_world
        fo = objs['MagFollower']
        fo_keep = (fo.parent, fo.matrix_world.copy())
        fo.parent = None
        fo.hide_render = False
        fo.matrix_world = Matrix.Translation(V((0.11, -0.065, 0))) @ mag.matrix_world
        bpy.context.view_layer.update()
        rd, cs = ammo['Sniper_Round'], ammo['Sniper_Case']
        rd.hide_render = cs.hide_render = False
        z0 = floor.location.z + 0.00745
        rd.matrix_world = Matrix.Translation(V((-0.03, 0.09, z0))) @ Matrix.Rotation(0.4, 4, 'Z')
        cs.matrix_world = Matrix.Translation(V((0.09, 0.06, z0))) @ Matrix.Rotation(-0.6, 4, 'Z')
        bpy.context.view_layer.update()
        alo, ahi = gk.world_bbox([mag, empty, rd, cs])
        gk.set_res(1500, 950)
        rig.frame((alo, ahi), (0.5, 0.9, 0.5), lens=60, margin=1.08)
        p = os.path.join(out, '09_ammo_and_magazines.png')
        gk.render(p)
        gk.caption(p, ['5-round .338 box magazine (full: top round in the lips; empty: follower up), '
                       '.338 round (%d tris), spent brass case (%d tris)' % (
                           info['tri_ammo']['Sniper_Round'], info['tri_ammo']['Sniper_Case']),
                       'mag + top round %d tris' % info['tri_mag']])
        files.append(p)
        bpy.data.objects.remove(empty)
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
        bm_ = gk.baked_material('BakedSniper', paths['metal'])
        bs_ = gk.baked_material('BakedSniperStock', paths['stock'])
        saved = gk.swap_materials([o for o in gobjs if o.name not in STOCK_PARTS], bm_)
        saved += gk.swap_materials([objs[n] for n in STOCK_PARTS], bs_)
        p = shot('10_game_look_baked', (0.85, -0.8, 0.38), lens=50)
        gk.caption(p, ['GAME LOOK: the baked 1024 atlases only (metal + stock; Color / Normal / Roughness / '
                       'Metalness), as SurfaceAppearances'])
        gk.restore_materials(saved)
    if want('11'):
        saved = gk.swap_materials(gobjs, gk.MAT['FlatGrey'])
        p = shot('11_game_mesh', (0.85, -0.8, 0.38), lens=50)
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
        sheet = gk.contact_sheet(keyf, os.path.join(out, 'sniper_sheet.png'), '.338 BOLT RIFLE (tools/guns/sniper.py) - '
                                 + tri_line, cols=3)
        if not args.no_export:
            import shutil
            shutil.copy(sheet, os.path.join(args.assets, 'sniper_sheet.png'))
            if hold_files:
                gk.grid(hold_files, os.path.join(args.assets, 'sniper_holds.png'), cols=2, tw=1100, th=820,
                        title='.338 BOLT RIFLE - solved R6 holds (front 3/4, side, hands, eye)')


def render_hold(args, rig, gun, objs, root, gobjs, r):
    import numpy as np
    e = r['_eval']
    studio = bpy.data.collections['Studio']
    dummy = gk.build_r6(studio, e['F'], name='R6_' + r['name'])
    if r['name'] == 'BoltCycle':
        set_pose(objs, gun, bolt_rot=-LIFT)
    gk.place_gun(root, e['G'])
    floor = gk.add_floor(studio, -3 * gk.STUD - 0.001, 'Ground')
    lo, hi = gk.world_bbox(dummy + gobjs)
    names = []
    res = r['residuals']
    head = [o for o in dummy if o.name.endswith('Head')][0]
    arms = [o for o in dummy if 'Arm' in o.name]
    scoped = r['name'] in ('Aim', 'BoltCycle')
    G = e['G']

    def gun_pt(p):
        return gk.r2b_point((G @ np.append(gk.model_to_gun(p), 1.0))[:3])
    for tag, view, kw in (('front', (1.0, -0.8, 0.35), dict(lens=40)), ('side', (0.0, -1.0, 0.08), dict(lens=40)),
                          ('close', (0.25, -1.0, 0.25), dict(lens=50)), ('eye', None, {})):
        gk.set_res(1100, 820)
        bpy.context.scene.cycles.samples = 24 if not args.quick else 8
        head.hide_render = False
        for o in arms:
            o.hide_render = False
        if view is None:
            head.hide_render = True
            for o in arms:
                o.hide_render = True
            d = e['sight_d']
            rig.cam.data.type = 'PERSP'
            rig.cam.data.clip_start = 0.01
            if scoped:
                # 0.4 m behind the solved eye, along the sight line, narrow field: the reticle sits in the middle
                # of the ocular when the eye is on the line; an offset eye shows the reticle off-centre
                back = 0.40 / gk.STUD
                eye_b = gk.r2b_point(e['eye'] - d * back)
                tgt = gk.r2b_point(e['eye'] + d * 8.0)
                rig.cam.data.lens = 130
            elif r['name'] == 'ReloadMag':
                eye_b = gk.r2b_point(e['eye'])
                tgt = gun_pt(gun.markers['MagGrab'][0])
                rig.cam.data.lens = 35
            else:
                eye_b = gk.r2b_point(e['eye'])
                tgt = gk.r2b_point(e['eye'] + d * 8.0)
                rig.cam.data.lens = 35
            rig.aim(rig.cam, eye_b, tgt)
            rig.place_lights((lo + hi) / 2, 2.5)
        elif tag == 'close':
            # the right side at the action: the receiver, bolt and magazine must be visible past the arms
            c = gun_pt(mm(-110, 0, -20))
            rig.frame((c - V((0.36, 0.36, 0.25)), c + V((0.36, 0.36, 0.25))), view, margin=1.0, **kw)
        else:
            rig.frame((lo, hi), view, margin=1.08, **kw)
        p = os.path.join(args.out, '_hold_%s_%s.png' % (r['name'], tag))
        gk.render(p)
        names.append(p)
    head.hide_render = False
    for o in arms:
        o.hide_render = False
    nk = r['pose']['Neck']
    txt = '%s (%s): blade %.0f, lean %.0f, roll %.0f, neck (%.0f, %.0f, %.0f), wrist %.0f; left %.3f stud%s; %s' % (
        r['name'], r['grip'], r['pose']['Root'][1], r['pose']['Root'][0], r['pose']['Root'][2], nk[0], nk[1], nk[2],
        res['wristDeg'], res.get('left', float('nan')),
        ('; eye-line %.3f stud' % res['eyeToSightLine']) if scoped else
        ('; eye over line %.2f' % res['eyeOver'] if 'eyeOver' in res else ''),
        'CHECK OK' if r.get('check') == 'ok' else 'CHECK FAIL')
    eye_lbl = ('eye view: 0.4 m behind the solved eye along the sight line (reticle centred = on line)' if scoped
               else 'eye view (head and arms hidden)')
    out = gk.grid(names, os.path.join(args.out, '13_hold_%s.png' % r['name']), cols=2, tw=1100, th=820,
                  labels=['front 3/4', 'right side', 'right side close-up (action)', eye_lbl], title=txt)
    for o in dummy:
        bpy.data.objects.remove(o)
    bpy.data.objects.remove(floor)
    root.matrix_world = Matrix()
    set_pose(objs, gun)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='/tmp/sniper_out')
    ap.add_argument('--assets', default=os.path.join(ROOT, 'assets', 'guns', 'Sniper'))
    ap.add_argument('--samples', type=int, default=40)
    ap.add_argument('--only', default='')
    ap.add_argument('--quick', action='store_true')
    ap.add_argument('--no-bake', action='store_true')
    ap.add_argument('--no-holds', action='store_true')
    ap.add_argument('--no-render', action='store_true')
    ap.add_argument('--no-export', action='store_true')
    ap.add_argument('--ref', default='')
    ap.add_argument('--allow-fail', action='store_true', help='write the holds even if a stance check fails')
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)
    only = set(args.only.split(',')) if args.only else None

    def want(k):
        return only is None or k in only

    gk.reset_scene()
    build_sniper_materials()
    gk.setup_render(16 if args.quick else args.samples, (1600, 1000))
    col = bpy.data.collections.new('Sniper')
    bpy.context.scene.collection.children.link(col)
    studio = bpy.data.collections.new('Studio')
    bpy.context.scene.collection.children.link(studio)
    gun = build_model()
    objs = gun.build(col)
    objs['MagRoundTop'].data.set_sharp_from_angle(angle=math.radians(38))   # 10-segment rounds: smooth
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
            'width': round(hi.y - lo.y, 4), 'boltStroke': mm(STROKE), 'boltLiftDeg': LIFT,
            'scopeAxisAboveBore': mm(SCOPE_Z), 'lengthOfPullAdjust': mm(40.0)}
    gun.dims = dims
    print('DIMS', dims, 'bbox', tuple(lo), tuple(hi), flush=True)
    if check_contract(gun, objs, tris, tri_gun, tri_mag, tri_ammo, dims) and not args.allow_fail:
        raise SystemExit('MODEL CONTRACT FAILED')

    stock = [objs[n] for n in STOCK_PARTS]
    metal = [objs[n] for n in gun.order if n not in STOCK_PARTS]
    gk.uv_atlas(metal, margin=0.003)
    gk.uv_atlas(stock, margin=0.004)
    gk.uv_atlas(list(ammo.values()), margin=0.01)
    paths = None
    if not args.no_bake:
        paths = {'metal': gk.bake_atlas(metal, args.assets, GID, size=1024, samples=12),
                 'stock': gk.bake_atlas(stock, args.assets, GID + '_Stock', size=1024, samples=12)}
        gk.bake_atlas(list(ammo.values()), args.assets, GID + '_Ammo', size=256, samples=12)
    if not args.no_export:
        gk.export_fbx([objs[n] for n in gun_parts], os.path.join(args.assets, GID + '.fbx'))
        gk.export_fbx([ammo['Sniper_Case']], os.path.join(args.assets, 'Sniper_Case.fbx'))
        gk.export_fbx([ammo['Sniper_Round']], os.path.join(args.assets, 'Sniper_Round.fbx'))
        mag = objs['Magazine']
        saved, par = mag.matrix_world.copy(), mag.parent
        mag.parent = None
        mag.matrix_world = Matrix()
        bpy.context.view_layer.update()
        gk.export_fbx([mag, objs['MagRoundTop']], os.path.join(args.assets, 'Sniper_Mag.fbx'))
        gk.export_fbx([mag, objs['MagFollower']], os.path.join(args.assets, 'Sniper_MagEmpty.fbx'))
        mag.parent = par
        mag.matrix_world = saved
        bpy.context.view_layer.update()
        gun.to_json(os.path.join(args.assets, 'sniper.markers.json'),
                    tris={**{n: tris[n] for n in gun.order}, 'gunFbx': tri_gun, 'magFbx': tri_mag,
                          'case': tri_ammo['Sniper_Case'], 'round': tri_ammo['Sniper_Round']})
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(args.out, 'sniper.blend'))

    holds = None
    if not args.no_holds:
        holds = solve_holds(gun, os.path.join(HERE, 'sniper_holds.json'), strict=not args.allow_fail)
    if args.no_render:
        return
    render_all(args, gun, objs, root, ammo, paths, holds,
               dict(tris=tris, tri_gun=tri_gun, tri_mag=tri_mag, tri_ammo=tri_ammo, dims=dims), want)


if __name__ == '__main__':
    main()
