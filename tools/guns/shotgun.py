#!/usr/bin/env python3
"""The 12-GAUGE TACTICAL: a gas-operated semi-auto 12 ga with an extended tube magazine (7 + 1), original
generic design in the class of the reference photo (a modern tactical semi-auto: black synthetic stock with
a swept pistol grip and a vented recoil pad, black-anodised aluminium receiver with machined flats, a micro
red dot on the receiver, heavy 18.5 in barrel with a ported choke, barrel clamp).  No logos, no copied
markings.

Builds the model from code (tools/guns/gunkit.py), follows the Model contract (docs/firearms/ARCHITECTURE.md
§5), bakes a 1024 atlas for a Roblox SurfaceAppearance, exports the FBXs and the markers JSON to
assets/guns/Shotgun/, solves the R6 holds (shotgun_holds.json next to this script) and renders the review
set into --out.

Real-world class dimensions: overall length 980 mm, barrel 470 mm (18.5 in, + ported choke to 474 mm),
height 0.20 m with the optic (0.185 m without), receiver width 31 mm, tube 7 + 1 (2 3/4 in shells),
3.6 kg loaded.  The side profile was measured on the reference photo (1.952 mm/px, breech face at px 266,
bore at py 122.5); every coordinate below is millimetres in model space (+X muzzle, +Y left, +Z up, origin
on the bore at the breech face).

Moving parts (ARCHITECTURE §5.2): Bolt (child ChargingHandle) slides -X 75 mm and locks back on empty;
BoltRelease (right side button) slides +Y 3 mm; Lifter (shell carrier) rests flush in the loading port and
swings +12 deg about -Y at its rear pin (front end UP, feeding; check_lifter asserts it never leaves the
receiver); Trigger +12 deg; Safety (tang slider, ARCHITECTURE §5.2 amended) slides +X 5 mm to FIRE.
Triangle budget (§5.1): gun FBX <= 8 000 (7 341), round <= 200 (192), hull <= 150 (144).
Shells are separate models (Shotgun_Round red, Shotgun_RoundGreen, Shotgun_Case spent hull).

Usage:
  /home/user/z-anatomy/venv/bin/python -I tools/guns/shotgun.py --out DIR [--assets assets/guns/Shotgun]
      [--samples 40] [--only 01,02] [--quick] [--no-bake] [--no-holds] [--no-render] [--no-export] [--ref photo]
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
GID = 'Shotgun'


def mm(*a):
    """mm -> metres (a number, a point or a list of 2D points)."""
    if len(a) == 1 and isinstance(a[0], (int, float)):
        return a[0] * 0.001
    if len(a) == 1:
        return [(p[0] * 0.001, p[1] * 0.001) for p in a[0]]
    return tuple(c * 0.001 for c in a)


def tab(table, x):
    """Linear interpolation in a [(x, v), ...] table sorted by increasing x (clamped)."""
    if x <= table[0][0]:
        return table[0][1]
    for (xa, va), (xb, vb) in zip(table[:-1], table[1:]):
        if xa <= x <= xb:
            t = (x - xa) / (xb - xa) if xb != xa else 0.0
            return va + (vb - va) * t
    return table[-1][1]


def slot_cutter(p0, p1, r, depth, axis, segs=8, mi=0):
    """A stadium slot from p0 to p1 cut along `axis` by +-depth (gunkit.slot_cutter without its lookup-table
    bug: the kit is frozen, so the shotgun keeps its own copy)."""
    c = bmesh.new()
    p0, p1, a = V(p0), V(p1), V(axis).normalized()
    d = (p1 - p0)
    d.normalize()
    side = a.cross(d).normalized()
    pts = []
    for k in range(segs + 1):
        t = math.pi / 2 + math.pi * k / segs
        pts.append(p0 + d * (r * math.cos(t)) + side * (r * math.sin(t)))
    for k in range(segs + 1):
        t = -math.pi / 2 + math.pi * k / segs
        pts.append(p1 + d * (r * math.cos(t)) + side * (r * math.sin(t)))
    A = [c.verts.new(p - a * depth) for p in pts]
    B = [c.verts.new(p + a * depth) for p in pts]
    m = len(pts)
    c.faces.new(A)
    c.faces.new(list(reversed(B)))
    for i in range(m):
        i1 = (i + 1) % m
        c.faces.new((A[i1], A[i], B[i], B[i1]))
    c.normal_update()
    ctr = (p0 + p1) / 2
    if sum((f.calc_center_median() - ctr).dot(f.normal) for f in c.faces) < 0:
        bmesh.ops.reverse_faces(c, faces=list(c.faces))
    for f in c.faces:
        f.material_index = mi
    return c


# --------------------------------------------------------------------------------------
# layout (mm, model space)
# --------------------------------------------------------------------------------------
MUZZLE_X = 474.0                  # crown of the ported choke (barrel 470 + choke lip)
BARREL_R = 10.7                   # heavy barrel, 21.4 mm OD
BORE_R = 9.25                     # 12 ga bore 18.5 mm
CHAMBER_R = 10.3
REC_HW = 15.5                     # receiver half width (31 mm)
REC_TOP, REC_BOT = 16.6, -44.0
TUBE_Z, TUBE_R = -32.0, 12.0      # magazine tube axis height and radius (24 mm OD)
TUBE_END = 455.0                  # front of the tube (cap beyond)
BOLT_STROKE = 75.0
PORT_X = (-106.0, 2.0)            # ejection port (right side), x range
PORT_Z = (-11.5, 12.0)
LPORT_X = (-104.0, -8.0)          # loading port (bottom), x range
LPORT_HW = 12.2
LIFTER_PIVOT = (LPORT_X[0] + 3.0, REC_BOT + 4.5)   # the carrier's rear pin (x, z)
OPTIC_X = (-128.0, -86.0)
CLAMP_X = (363.0, 402.0)
FOREND_X = (18.0, 301.0)
BUTT_X = -506.0

# stock side profile (measured): top line, bottom line (with the swept pistol grip), width, corner radii
ZTOP = [(-482, -47), (-440, -42), (-281, -25), (-262, -24), (-250, -21), (-226, -14.5), (-203, -4.5), (-186, 3),
        (-180, 4.5)]
ZBOT = [(-482, -166), (-474, -167), (-460, -159), (-300, -93), (-292, -98), (-280, -104), (-265, -108),
        (-256, -107), (-250, -102), (-246, -95), (-242, -86), (-238, -76), (-232, -68), (-226, -62), (-215, -54),
        (-203, -48), (-191, -44.5), (-180, -44)]
WIDTH = [(-482, 43), (-420, 42), (-330, 38), (-292, 34), (-250, 32), (-215, 32), (-188, 30.4), (-180, 30.4)]
RTOP = [(-482, 15), (-330, 14), (-250, 12), (-200, 9), (-180, 8)]
RBOT = [(-482, 8), (-330, 9), (-300, 12), (-250, 14), (-215, 11), (-180, 6)]
STOCK_XS = [-482, -476, -466, -452, -432, -410, -385, -360, -335, -312, -302, -296, -291, -284, -276, -268,
            -260, -254, -250, -246, -242, -238, -234, -229, -223, -216, -208, -199, -191, -185, -180]


def stock_ring(x, grow=0.0, ztrim=(0.0, 0.0)):
    """One rounded section of the stock at station x (3D points, metres)."""
    zt, zb = tab(ZTOP, x) + grow - ztrim[0], tab(ZBOT, x) - grow + ztrim[1]
    hw = tab(WIDTH, x) / 2 + grow
    hz = (zt - zb) / 2
    sec = gk.rrect2((zt + zb) / 2, 0.0, hz, hw, r_pos=tab(RTOP, x) + grow, r_neg=tab(RBOT, x) + grow, n=3)
    return [mm(x, y, z) for z, y in sec]


# --------------------------------------------------------------------------------------
# receiver (black hard-anodised aluminium): side profile ∩ rounded section, ports, flats
# --------------------------------------------------------------------------------------

def build_receiver(gun):
    rc = gun.part('Receiver', paint='Aluminium', fit=1)
    Al, Bo, In = rc.mi('Aluminium'), rc.mi('Bore'), rc.mi('RaceInner')
    bm = rc.bm
    side = [(18.0, -44.0), (18.0, 13.2), (15.0, 16.6), (-112.0, 16.6), (-140.0, 13.4), (-170.0, 8.8), (-194.0, 3.5),
            (-197.0, 1.0), (-186.0, -44.0)]
    gk.profile(bm, mm(gk.fillet2(side, 1.0, 2, radii=[1.5, 1.0, 2.5, 8.0, 8.0, 5.0, 2.0, 1.0, 1.5])), mm(2 * REC_HW + 0.8),
               bevel=mm(2.4), bevel_segs=1, mi=Al)
    sec = gk.fillet2([(-REC_HW, REC_BOT - 2), (REC_HW, REC_BOT - 2), (REC_HW, 18.0), (-REC_HW, 18.0)], 1.0, 3,
                     radii=[2.5, 2.5, 10.0, 10.0])
    c = bmesh.new()
    gk.section_x(c, mm(sec), mm(-205.0), mm(25.0), mi=Al)
    gk.boolean_bm(bm, c, op='INTERSECT')
    # (review: the recessed side flats caught the edge wear as a bright outline = toy look; the class has
    # plain anodised sides, so they are gone)
    cuts = []
    # ejection port (right side = -Y), deep into the bolt raceway
    port = [(PORT_X[0], PORT_Z[0]), (PORT_X[1], PORT_Z[0]), (PORT_X[1], PORT_Z[1]), (PORT_X[0], PORT_Z[1])]
    cuts.append(gk.prism_cutter(mm(gk.fillet2(port, 3.0, 2)), mm(-30.0), mm(2.0), mi=In))
    c = bmesh.new()
    gk.cyl(c, mm(-128.0, 0, 0), mm(1.0, 0, 0), mm(11.2), 16, mi=In)            # bolt raceway
    cuts.append(c)
    gk.boolean_bm(bm, cuts)
    cuts = []
    # loading port (bottom): open right up into the raceway (z -6), the side rails left standing, so the
    # carrier has a path to lift a shell to the chamber and the port shows the action from below
    lp = [(LPORT_X[0], -60.0), (LPORT_X[1], -60.0), (LPORT_X[1], -6.0), (LPORT_X[0], -6.0)]
    cuts.append(gk.prism_cutter(mm(gk.fillet2(lp, 4.0, 1, radii=[0, 0, 5.0, 5.0])), mm(-LPORT_HW), mm(LPORT_HW), mi=In))
    # bolt-release pocket (right side)
    c = bmesh.new()
    gk.rbox(c, mm(-20.0, -REC_HW, -27.0), mm(24.0, 4.0, 12.5), mm(1.5), 1, mi=Bo)
    cuts.append(c)
    # safety channel on the tang
    c = bmesh.new()
    gk.rbox(c, mm(-150.0, 0, 12.4), mm(19.0, 7.0, 4.0), mm(0.8), 1, R=Matrix.Rotation(math.radians(-8.5), 3, 'Y'),
            mi=Bo)
    cuts.append(c)
    gk.boolean_bm(bm, cuts)
    # optic cut: a flat milled plate seat on the top
    gk.rbox(bm, mm((OPTIC_X[0] + OPTIC_X[1]) / 2, 0, REC_TOP + 0.3), mm(46.0, 24.0, 1.2), mm(0.4), 1, mi=Al)
    return rc


def build_pins(gun):
    """Trigger-group pins, the bolt-release pivot and the tang screw (static steel)."""
    pp = gun.part('Pins', paint='SteelBlued')
    St, Bo = pp.mi('SteelBlued'), pp.mi('Bore')
    bm = pp.bm
    for (x, z, r) in ((-153.0, -30.0, 2.4), (-123.0, -30.0, 2.4)):
        gk.pin(bm, mm(x, REC_HW - 0.8, z), (0, 1, 0), mm(r), proud=mm(0.35), segs=10, mi=St, both=mm(2 * (REC_HW - 0.8)))
    gk.cyl(bm, mm(-186.0, 0, 3.4), mm(-186.0, 0, 5.4), mm(2.6), 8, mi=St)          # tang screw head (bake)
    return pp


def build_trigger_guard(gun):
    tg = gun.part('TriggerGuard', paint='Polymer')
    P = tg.mi('Polymer')
    outer = [(-174.0, -42.0), (-108.0, -42.0), (-109.0, -48.0), (-114.0, -63.0), (-120.0, -72.0), (-128.0, -76.5),
             (-158.0, -77.0), (-166.0, -73.5), (-171.0, -64.0), (-174.0, -52.0)]
    hole = [(-164.0, -46.5), (-118.0, -46.5), (-121.0, -58.0), (-126.0, -66.0), (-133.0, -70.0), (-156.0, -70.0),
            (-161.0, -65.0), (-164.0, -56.0)]
    gk.profile(tg.bm, mm(gk.fillet2(outer, 2.0, 1, radii=[1, 1, 3, 4, 5, 6, 6, 5, 4, 2])), mm(12.0),
               holes=[mm(gk.fillet2(hole, 3.0, 1))], bevel=mm(2.2), bevel_segs=0, mi=P)
    # the housing under the receiver behind the loading port (trigger group base plate)
    gk.rbox(tg.bm, mm(-145.0, 0, -44.6), mm(76.0, 27.0, 2.2), mm(0.8), 1, mi=P)
    return tg


def build_trigger(gun):
    tr = gun.part('Trigger', paint='SteelBlued', origin=mm(-146.0, 0, -44.0), fit=3)
    St = tr.mi('SteelBlued')
    blade = [(-150.5, -42.0), (-142.5, -42.0), (-142.0, -48.0), (-139.5, -56.0), (-135.5, -63.0), (-134.0, -66.5),
             (-136.0, -68.0), (-140.0, -65.5), (-145.0, -59.5), (-148.5, -52.0)]
    # a smooth curved blade with an edge bevel (review: the proud groove boxes read as a saw-tooth)
    gk.profile(tr.bm, mm(gk.fillet2(blade, 1.2, 1, radii=[0.5, 0.5, 4, 4, 3, 1.2, 1.0, 3, 4, 3])), mm(7.0),
               bevel=mm(1.4), bevel_segs=1, mi=St)
    return tr


def build_safety(gun):
    sf = gun.part('Safety', paint='Polymer', origin=mm(-150.0, 0, 13.8))
    P = sf.mi('Polymer')
    R = Matrix.Rotation(math.radians(-8.5), 3, 'Y')
    gk.rbox(sf.bm, mm(-150.0, 0, 13.6), mm(13.0, 6.2, 4.6), mm(1.0), 1, R=R, mi=P)
    gk.rbox(sf.bm, mm(-150.0, 0, 16.3), mm(15.0, 11.0, 2.4), mm(0.9), 1, R=R, mi=P)
    for k in range(4):
        gk.box(sf.bm, Vector(mm(-150.0, 0, 16.3)) + R @ Vector(mm(-4.5 + k * 3.0, 0, 1.25)), mm(0.9, 10.0, 0.8), R=R,
               mi=P)
    return sf


def build_bolt(gun):
    """Bolt (satin nickel, seen through the port) with its dark machined channels and the blued extractor on
    the right (-Y) side; child ChargingHandle on the right."""
    bo = gun.part('Bolt', paint='Nickel', origin=(0, 0, 0))
    Sb, Bk, St = bo.mi('Nickel'), bo.mi('Bore'), bo.mi('SteelBlued')
    bm = bo.bm
    n = 16
    sec = []
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        y, z = 9.4 * math.cos(a), 9.4 * math.sin(a)
        sec.append((y, z))
    gk.section_x(bm, mm(sec), mm(-110.0), mm(-0.6), end_bevel=mm(1.2), mi=Sb)
    # machined channels along the bolt body on the port side (dark, wide enough to read through the port),
    # the locking-lug step
    c = bmesh.new()
    gk.box(c, mm(-66.0, -9.4, 2.6), mm(62.0, 5.0, 5.2), mi=Bk)
    gk.box(c, mm(-22.0, 0, 0), mm(1.6, 30.0, 30.0), mi=Bk)
    gk.boolean_bm(bm, c)
    # bolt head: the extractor (blued claw standing proud on the port side) and the face recess (dark)
    gk.rbox(bm, mm(-9.0, -9.0, 0.0), mm(15.0, 2.6, 5.4), mm(0.6), 1, mi=St)
    gk.box(bm, mm(-1.4, -8.4, 0.0), mm(1.6, 2.4, 3.6), mi=St)                        # the claw hook
    gk.cyl(bm, mm(-0.4, 0, 0), mm(-0.2, 0, 0), mm(6.0), 12, mi=Bk)
    # the carrier rail under the bolt (seen through the loading port)
    gk.rbox(bm, mm(-60.0, 0, -11.2), mm(96.0, 12.0, 4.0), mm(0.6), 1, mi=Sb)
    # charging handle: rod + knob (knurl left to the bake), sticks out of the port's front
    ch = gun.part('ChargingHandle', paint='Nickel', parent='Bolt', origin=mm(-16.0, -9.0, 0.0))
    S2 = ch.mi('Nickel')
    M = gk.frame_x(V(mm(-16.0, -6.5, 0.0)), (0, -1, 0))
    gk.lathe(ch.bm, [(x * 0.001, r * 0.001) for x, r in
                     [(0, 4.0), (10.0, 4.0), (12.0, 6.0), (12.6, 6.6), (24.5, 6.6), (26.2, 5.0), (27.0, 2.4),
                      (27.0, 0)]], 10, M, mi=S2)
    return bo, ch


def build_lifter(gun):
    """Shell carrier: at rest it closes the loading port flush with the receiver bottom (the shell cradle
    trough facing up); it swings FRONT UP about its rear pin (hinge -Y, 0 -> 12 deg) to lift a shell toward the
    chamber, so it never leaves the receiver (review P0-1, contract amendment in ARCHITECTURE §5.2)."""
    lf = gun.part('Lifter', paint='SteelBlued', origin=mm(LIFTER_PIVOT[0], 0, LIFTER_PIVOT[1]))
    St, Bo = lf.mi('SteelBlued'), lf.mi('Bore')
    out = [(LPORT_X[0] + 1.0, REC_BOT + 0.6), (LPORT_X[1] - 4.0, REC_BOT + 0.6), (LPORT_X[1] - 1.5, REC_BOT + 3.0),
           (LPORT_X[1] - 1.5, REC_BOT + 8.5), (LPORT_X[0] + 1.0, REC_BOT + 8.5)]
    gk.profile(lf.bm, mm(gk.fillet2(out, 1.0, 1)), mm(2 * LPORT_HW - 1.6), bevel=mm(0.8), bevel_segs=0, mi=St)
    c = bmesh.new()
    gk.cyl(c, mm(LPORT_X[0] + 9.0, 0, REC_BOT + 17.0), mm(LPORT_X[1] - 8.0, 0, REC_BOT + 17.0), mm(10.6), 12, mi=Bo)
    gk.boolean_bm(lf.bm, c)                                                         # shell cradle trough
    # a thumb notch at the front lip (the push point of a loading thumb)
    c = bmesh.new()
    gk.cyl(c, mm(LPORT_X[1] - 1.0, -8, REC_BOT - 4.0), mm(LPORT_X[1] - 1.0, 8, REC_BOT - 4.0), mm(6.0), 10, mi=St)
    gk.boolean_bm(lf.bm, c)
    return lf


def build_bolt_release(gun):
    """A plain oblong push button with a chamfered face in its pocket (review: the ribbed one read as a grille)."""
    br = gun.part('BoltRelease', paint='SteelBlued', origin=mm(-20.0, -REC_HW, -27.0))
    St = br.mi('SteelBlued')
    gk.rbox(br.bm, mm(-20.0, -REC_HW - 0.1, -27.0), mm(19.0, 3.2, 9.0), mm(1.3), 1, mi=St)
    return br


def build_barrel(gun):
    br = gun.part('Barrel', paint='SteelBlued', origin=(0, 0, 0), fit=2)
    St, Bo, Pol = br.mi('SteelBlued'), br.mi('Bore'), br.mi('SteelBare')
    bm = br.bm
    # the barrel extension's rear face at the breech (x -1) with a polished, chamfered chamber mouth: what
    # the open ejection port shows with the bolt back (review P0-3)
    prof = [(-1.0, 11.4), (-1.0, 12.4), (20.0, 12.4), (22.0, 11.4), (40.0, 11.2), (120.0, BARREL_R),
            (444.0, BARREL_R), (444.0, BORE_R), (76.0, BORE_R), (70.0, CHAMBER_R), (1.2, CHAMBER_R)]
    M = gk.frame_x(V((0, 0, 0)), (1, 0, 0))
    gk.lathe(bm, [(x * 0.001, r * 0.001) for x, r in prof], 16, M, closed=True, mi=St)
    # the choke tube / muzzle device: a slightly bigger stepped sleeve with a crowned muzzle (its ports and
    # knurl are left to the texture)
    dev = [(443.0, 8.9), (443.0, 11.4), (445.0, 12.1), (471.5, 12.1), (473.0, 11.4), (MUZZLE_X, 10.4),
           (MUZZLE_X, 9.6), (MUZZLE_X - 1.0, 8.9)]
    gk.lathe(bm, [(x * 0.001, r * 0.001) for x, r in dev], 16, M, closed=True, mi=St)
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        c = f.calc_center_median()
        if math.hypot(c.y, c.z) < mm(10.45) and abs(f.normal.x) < 0.9 and c.x > mm(1.5):
            f.material_index = Bo
        elif c.x < mm(1.3) and math.hypot(c.y, c.z) < mm(12.0):
            f.material_index = Pol                         # the chamber mouth chamfer: bright from loading
    # front sight bead: base + red fibre (Glow)
    sg = gun.part('SightFront', paint='SteelBlued')
    S2, Gl = sg.mi('SteelBlued'), sg.mi('Glow')
    base = [(432.0, BARREL_R - 1.0), (443.0, BARREL_R - 1.0), (443.0, 13.2), (441.5, 14.6), (433.5, 14.6), (432.0, 13.2)]
    gk.profile(sg.bm, mm(gk.fillet2(base, 0.6, 1)), mm(4.4), bevel=mm(0.5), bevel_segs=0, mi=S2)
    gk.cyl(sg.bm, mm(433.0, 0, 16.0), mm(442.6, 0, 16.0), mm(1.5), 10, mi=Gl)
    gk.rbox(sg.bm, mm(437.8, 0, 14.9), mm(9.0, 4.4, 1.6), mm(0.4), 1, mi=S2)
    return br, sg


def build_tube(gun):
    tb = gun.part('MagTube', paint='SteelBlued', fit=4)
    St = tb.mi('SteelBlued')
    M = gk.frame_x(V(mm(0, 0, TUBE_Z)), (1, 0, 0))
    prof = [(-6.0, 0), (-6.0, TUBE_R), (302.0, TUBE_R), (302.0, 13.2), (303.0, 14.0)]
    prof += [(310.0, 14.0), (310.6, 13.3), (311.6, 13.3), (312.2, 14.0)]   # forend nut, one grip groove
    prof += [(329.0, 14.0), (330.0, 13.0), (331.0, TUBE_R), (TUBE_END, TUBE_R), (TUBE_END, 0)]
    gk.lathe(tb.bm, [(x * 0.001, r * 0.001) for x, r in prof], 14, M, mi=St)
    # magazine cap with grip grooves and the front sling loop
    cp = gun.part('MagCap', paint='SteelBlued', origin=mm(TUBE_END, 0, TUBE_Z))
    S2 = cp.mi('SteelBlued')
    cprof = [(TUBE_END - 1.0, 12.4), (TUBE_END + 0.5, 12.9), (TUBE_END + 5.0, 12.9), (TUBE_END + 5.5, 12.2),
             (TUBE_END + 6.6, 12.2), (TUBE_END + 7.1, 12.9), (TUBE_END + 12.5, 12.9), (TUBE_END + 14.0, 11.6),
             (TUBE_END + 14.6, 8.0), (TUBE_END + 14.8, 0)]
    gk.lathe(cp.bm, [(x * 0.001 - TUBE_END * 0.001, r * 0.001) for x, r in cprof], 14,
             gk.frame_x(V(mm(TUBE_END, 0, TUBE_Z)), (1, 0, 0)), mi=S2)
    # front sling loop: a low-poly ring (10 x 4) on a short post
    c0 = V(mm(TUBE_END + 6.5, 0, TUBE_Z - 12.4 - 9.4))
    gk.torus(cp.bm, c0, V((0, 1, 0)), mm(7.6), mm(1.25), 10, 4, S2)
    gk.cyl(cp.bm, mm(TUBE_END + 6.5, 0, TUBE_Z - 11.2), mm(TUBE_END + 6.5, 0, TUBE_Z - 14.4), mm(3.0), 6, mi=S2)
    return tb, cp


def build_clamp(gun):
    cl = gun.part('BarrelClamp', paint='Aluminium')
    Al, Bo, St = cl.mi('Aluminium'), cl.mi('Bore'), cl.mi('SteelBlued')
    # (review P1-6: hex screws, the QD bore and the top slot cost 540 triangles for 2 mm details; they are flat
    # discs now and the rest is texture)
    bm = cl.bm
    x0, x1 = CLAMP_X
    sec = gk.fillet2([(-14.5, -47.5), (14.5, -47.5), (14.5, 14.0), (-14.5, 14.0)], 5.0, 2, radii=[7, 7, 6, 6])
    gk.section_x(bm, mm(sec), mm(x0), mm(x1), end_bevel=mm(1.5), mi=Al)
    cuts = []
    # split line between the two halves (a fine groove around the waist) and side pockets
    c = bmesh.new()
    gk.box(c, mm((x0 + x1) / 2, 0, -16.0), mm(x1 - x0 + 4, 40.0, 1.0), mi=Bo)
    cuts.append(c)
    for sy in (1, -1):
        pk = [(x0 + 6.0, -43.0), (x1 - 6.0, -43.0), (x1 - 6.0, -22.0), (x0 + 6.0, -22.0)]
        cuts.append(gk.prism_cutter(mm(gk.fillet2(pk, 3.0, 1)), mm(sy * 13.4), mm(sy * 20.0), mi=Al))
    gk.boolean_bm(bm, cuts)
    for sy in (1, -1):
        # clamp screw heads: flat steel discs (hex sockets left to the bake), QD socket: a steel cup in the pocket
        for x in (x0 + 9.0, x1 - 9.0):
            gk.cyl(bm, mm(x, sy * 14.0, 2.0), mm(x, sy * 15.3, 2.0), mm(2.6), 6, mi=St)
        gk.cyl(bm, mm((x0 + x1) / 2, sy * 13.0, -32.0), mm((x0 + x1) / 2, sy * 14.2, -32.0), mm(4.2), 8, mi=St)
    return cl


FOREND_ST = [(18.0, -45.0, 44.0), (22.0, -48.0, 45.0), (30.0, -50.5, 46.0), (44.0, -51.5, 46.5), (150.0, -52.0, 46.5),
             (262.0, -51.5, 46.5), (278.0, -50.5, 45.5), (289.0, -48.0, 44.0), (296.0, -45.0, 41.0),
             (300.0, -42.0, 37.0), (301.0, -40.0, 34.0)]


def build_forend(gun):
    fe = gun.part('Forend', paint='Polymer')
    P, S, Bo = fe.mi('Polymer'), fe.mi('PolymerStipple'), fe.mi('Bore')
    bm = fe.bm
    rings = []
    for x, zb, w in FOREND_ST:
        zt = -3.5
        hz = (zt - zb) / 2
        sec = gk.rrect2((zt + zb) / 2, 0.0, hz, w / 2, r_pos=6.0, r_neg=15.0, n=3)
        rings.append([mm(x, y, z) for z, y in sec])
    gk.loft(bm, rings, mi=P)
    cuts = []
    c = bmesh.new()
    gk.cyl(c, mm(10.0, 0, 0), mm(310.0, 0, 0), mm(11.6), 22, mi=P)          # barrel channel
    cuts.append(c)
    # recessed grip panels (stippled) with three grooves each side
    panel = [(55.0, -38.0), (240.0, -30.0), (240.0, -12.5), (78.0, -16.0)]
    for sy in (1, -1):
        y_out = sy * 30.0
        cuts.append(gk.prism_cutter(mm(gk.fillet2(panel, 6.0, 2)), mm(min(sy * 21.9, y_out)), mm(max(sy * 21.9, y_out)),
                                    mi=S))
        for k, (za, zb_) in enumerate(((-33.0, -26.0), (-27.0, -20.5), (-21.0, -15.5))):
            xa = 92.0 + k * 9.0
            cuts.append(slot_cutter(mm(xa, sy * 21.9, za), mm(232.0, sy * 21.9, zb_), mm(1.1), mm(1.4), (0, 1, 0),
                                       mi=S))
    gk.boolean_bm(bm, cuts)
    # stipple on the panel floors: faces facing sideways inside the panel
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        c = f.calc_center_median()
        if abs(c.y) < mm(22.2) and abs(f.normal.y) > 0.6 and mm(50) < c.x < mm(245) and mm(-40) < c.z < mm(-11):
            f.material_index = S
    return fe


# --------------------------------------------------------------------------------------
# stock (polymer, one piece with the swept pistol grip) + vented recoil pad + sling stud
# --------------------------------------------------------------------------------------

def build_stock(gun):
    sk = gun.part('Stock', paint='Polymer')
    P, S, St = sk.mi('Polymer'), sk.mi('PolymerStipple'), sk.mi('SteelBlued')
    bm = sk.bm
    rings = [stock_ring(x) for x in STOCK_XS]
    gk.loft(bm, rings, mi=P)
    # grip and wrist texture panels
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        c = f.calc_center_median()
        x, z = c.x * 1000, c.z * 1000
        grip = -296 < x < -200 and z < tab(ZBOT, x) + 30 and z < -52
        wrist = -268 < x < -196 and -46 < z < -18 and abs(f.normal.y) > 0.55
        if grip or wrist:
            f.material_index = S
    # rear sling stud
    zs = tab(ZBOT, -407.0)
    gk.sling_swivel(bm, mm(-407.0, 0, zs + 0.6), (0, 0, -1), size=mm(18.0), mi=St)
    # recoil pad (rubber): stock end section, slightly bigger, convex rear; the ribs are surface ribs in the
    # 'RubberRibbed' material (dark grooves + normal map), not through slots (review P2-9 and the budget)
    rp = gun.part('RecoilPad', paint='Rubber')
    R = rp.mi('RubberRibbed')
    prings = []
    for x, g, tr in ((-483.5, 0.7, 0.0), (-488.0, 1.0, 0.0), (-500.0, 1.0, 0.0), (-503.5, 0.2, 1.2), (BUTT_X, -2.2, 3.0)):
        ring = stock_ring(-482.0, grow=g, ztrim=(tr, tr))
        prings.append([(mm(x), p[1], p[2]) for p in ring])
    gk.loft(rp.bm, prings, mi=R)
    return sk, rp


# --------------------------------------------------------------------------------------
# optic: a generic open-emitter micro red dot on the receiver top
# --------------------------------------------------------------------------------------

def build_optic(gun):
    op = gun.part('Optic', paint='Aluminium', origin=mm((OPTIC_X[0] + OPTIC_X[1]) / 2, 0, REC_TOP + 1.0))
    Al, Gl, St, Bo = op.mi('Aluminium'), op.mi('Glow'), op.mi('SteelBlued'), op.mi('Bore')
    bm = op.bm
    a, b = OPTIC_X
    z0 = REC_TOP + 0.9
    side = [(a, z0), (b, z0), (b, z0 + 4.5), (b - 3.5, z0 + 15.5), (b - 8.0, z0 + 19.3), (a + 9.0, z0 + 19.3),
            (a + 4.0, z0 + 16.0), (a, z0 + 7.0)]
    gk.profile(bm, mm(gk.fillet2(side, 1.0, 2, radii=[0.8, 0.8, 1.5, 5.0, 3.0, 3.0, 5.0, 1.5])), mm(25.0),
               bevel=mm(1.3), bevel_segs=1, mi=Al)
    cuts = []
    win = [(a - 5.0, z0 + 6.5), (b + 5.0, z0 + 6.5), (b + 5.0, z0 + 16.8), (a - 5.0, z0 + 16.8)]
    cuts.append(gk.prism_cutter(mm(gk.fillet2(win, 2.5, 2)), mm(-9.8), mm(9.8), mi=Al))
    # side buttons pockets
    gk.boolean_bm(bm, cuts)
    # emitter housing at the rear of the window, glowing LED
    gk.rbox(bm, mm(a + 6.0, 0, z0 + 8.2), mm(5.0, 9.0, 3.6), mm(0.8), 1, mi=Al)
    gk.cyl(bm, mm(a + 8.4, 0, z0 + 8.6), mm(a + 8.8, 0, z0 + 8.6), mm(0.9), 8, mi=Gl)
    # brightness buttons (both sides), mount screws (top front of the base), windage screw
    for sy in (1, -1):
        gk.rbox(bm, mm(a + 12.0, sy * 12.9, z0 + 4.5), mm(7.0, 1.6, 4.0), mm(0.6), 1, mi=Al)
    for sy in (1, -1):                          # mount screw heads (sockets in the bake)
        gk.cyl(bm, mm(b - 3.0, sy * 7.0, z0 + 3.6), mm(b - 2.4, sy * 7.0, z0 + 4.8), mm(1.9), 6, mi=St)
    # the lens: tinted glass leaning back in the hood
    ln = gun.part('OpticLens', paint='Lens', parent='Optic', origin=mm(b - 6.0, 0, z0 + 11.5))
    L = ln.mi('Lens')
    Rl = Matrix.Rotation(math.radians(-12), 3, 'Y')
    gk.rbox(ln.bm, mm(b - 6.0, 0, z0 + 11.6), mm(1.2, 21.0, 11.6), mm(0.4), 1, R=Rl, mi=L)
    return op, ln


# --------------------------------------------------------------------------------------
# shells (separate models): loaded red, loaded green, spent hull
# --------------------------------------------------------------------------------------

def extra_materials():
    gk.mat_simple('ShellPlasticGreen', (0.025, 0.16, 0.05), 0.0, 0.45)
    gk.mat_simple('ShellPlasticRed', (0.33, 0.025, 0.018), 0.0, 0.42)
    # inside the receiver (raceway and port walls): the anodised alloy in shadow, still lit and specular, so a
    # concave raceway reads as a hollow and not as a black cylinder (review P0-3; 'Bore' stays for real holes)
    gk.mat_aluminium('RaceInner', col=(0.075, 0.075, 0.08), rough=0.42, wear=0.0)
    # the bolt: satin nickel instead of a mirror that only reflected the black studio
    p = gk._principled(gk.MAT['Nickel'])
    p.inputs['Roughness'].default_value = 0.33
    mat_rubber_ribbed()


def mat_rubber_ribbed(name='RubberRibbed'):
    """Recoil-pad rubber with the moulded horizontal ribs on both sides: 8 grooves 3.8 mm high, 9.5 mm long
    (x -499 .. -489.5), as dark colour + a recessed bump, so the bake carries them as texture (Color, Normal,
    Roughness) instead of 650 triangles of through-slots."""
    m = gk.NB(name)
    zt, zb = tab(ZTOP, -482.0), tab(ZBOT, -482.0)
    z0 = (zb + 13.0) * 0.001
    pitch = (zt - zb - 24.0) / 7.0 * 0.001
    x = m.axis(0)
    z = m.axis(2)
    t = m.math('DIVIDE', m.math('SUBTRACT', z, z0 - pitch * 0.5, clamp=False), pitch, clamp=False)
    inside = m.mul(m.mask(t, -0.02, 0.02), m.math('SUBTRACT', 1.0, m.mask(t, 7.98, 8.02)))
    f = m.math('FRACT', t, clamp=False)
    d = m.math('ABSOLUTE', m.math('SUBTRACT', f, 0.5, clamp=False), clamp=False)       # 0 at a groove centre
    groove = m.math('SUBTRACT', 1.0, m.mask(d, 0.11, 0.16))
    xm = m.mul(m.mask(x, -0.5005, -0.4985), m.math('SUBTRACT', 1.0, m.mask(x, -0.4900, -0.4885)))
    g = m.mul(m.mul(groove, inside), xm)
    geo = m.n('ShaderNodeNewGeometry')
    side = m.mask(m.math('ABSOLUTE', m.axis(1, geo.outputs['Normal']), clamp=False), 0.5, 0.8)
    g = m.mul(g, side)
    dust = m.mx(m.mask(m.noise(20, 6, 0.6), 0.6, 0.85), m.mul(m.cavity(0.004), 0.9))
    base = m.mixc(m.mul(dust, 0.6), gk.C(0.016, 0.016, 0.017), gk.C(0.09, 0.085, 0.075))
    base = m.mixc(g, base, gk.C(0.004, 0.004, 0.004))
    h = m.add(m.mul(g, -1.0), m.mul(m.noise(2500, 2, 0.5), 0.05))
    m.bsdf(base, 0.0, m.mixf(dust, 0.78, 0.92), m.bump(h, 0.9, 0.0015))
    return m.m


def build_shells(col):
    """The separate small models, origin at their centre of mass, +X toward the mouth."""
    # 12 sides shaded smooth (30 deg steps under the 40 deg sharp angle): round, not the octagons the review saw
    out, com = {}, {}
    for name, hull, spent, length in (('Shotgun_Round', 'ShellPlastic', False, 0.065),
                                      ('Shotgun_RoundGreen', 'ShellPlasticGreen', False, 0.065),
                                      ('Shotgun_Case', 'ShellPlastic', True, 0.070)):
        bm = bmesh.new()
        if spent:
            spent_hull(bm, length, 12)
        else:
            gk.build_shell(bm, {'case': 0, 'hull': 1, 'primer': 2}, segs=12, spent=False, length=length)
        c = gk.bm_volume_com(bm)
        out[name] = gk.single_object(col, name, bm, ['Brass', hull, 'Nickel'], origin=c, smooth_angle=40.0)
        com[name] = V(c)
    return out, com


def spent_hull(bm, length, segs):
    """The fired 12 ga hull in 12 triangles per side step (<= 150 tris): primer cup (struck, mat 2), brass head
    with its rim chamfer, plastic tube, the opened crimp flaring out and the hollow inside."""
    c = gk.CARTRIDGES['12ga']
    h = c['brass_h']
    gk.lathe(bm, [(-0.00005, 0), (-0.00005, 0.0028)], segs, mi=2)
    gk.lathe(bm, [(0, 0.0028), (0, c['rim']), (0.0016, c['base']), (h, c['base'])], segs, mi=0)
    gk.lathe(bm, [(h - 0.001, c['base'] - 0.0003), (length - 0.006, c['base'] - 0.0003), (length, c['base'] + 0.0012),
                  (length - 0.012, 0.0)], segs, mi=1)


# --------------------------------------------------------------------------------------
# the model
# --------------------------------------------------------------------------------------

def build_model():
    gun = gk.GunModel(GID, mass=3.6)
    build_receiver(gun)
    build_barrel(gun)
    build_tube(gun)
    build_clamp(gun)
    build_forend(gun)
    build_stock(gun)
    build_trigger_guard(gun)
    build_trigger(gun)
    build_safety(gun)
    build_bolt(gun)
    build_lifter(gun)
    build_bolt_release(gun)
    build_optic(gun)
    build_pins(gun)
    # hinges (ARCHITECTURE §5.2)
    gun.hinge('Bolt', 'slide', (-1, 0, 0), mm(BOLT_STROKE), pivot=(0, 0, 0), lockBackOnEmpty=True,
              note='ChargingHandle rides with it (reciprocating)')
    gun.hinge('BoltRelease', 'slide', (0, 1, 0), mm(3.0))
    gun.hinge('Lifter', 'rotate', (0, -1, 0), 12.0, note='shell carrier: rest flush in the loading port, FRONT UP '
              'about its rear pin (axis -Y) to lift a shell to the chamber (ARCHITECTURE §5.2 amended)')
    gun.hinge('Trigger', 'rotate', (0, 1, 0), 12.0)
    gun.hinge('Safety', 'slide', (1, 0, 0), mm(5.0), note='tang safety: rest = SAFE (rear), +X 5 mm = FIRE '
              '(ARCHITECTURE §5.2 amended: tang slider, as the reference class)')
    # markers (ARCHITECTURE §5.3)
    gun.marker('Muzzle', mm(MUZZLE_X, 0, 0))
    ej = V((math.sin(math.radians(10)) * math.cos(math.radians(20)), -math.cos(math.radians(10)) * math.cos(math.radians(20)),
            math.sin(math.radians(20))))
    gun.marker('EjectionPort', mm(-52.0, -REC_HW, 0.5), ej, (0, -0.3, 1.0))
    gun.marker('CasingSpawn', mm(-40.0, -28.0, 3.0), (0.92, -0.35, 0.18), (0, 0, 1))
    push = V((0.82, 0, 0.57)).normalized()
    gun.marker('ShellPort', mm(-34.0, 0, -45.0), push, (0, 1, 0))
    gun.marker('LoadingPort', mm((LPORT_X[0] + LPORT_X[1]) / 2, 0, REC_BOT), (1, 0, 0), (0, 0, -1))
    gun.marker('PortLoad', mm(-38.0, -22.0, 2.0), (0, 0.94, -0.34), (1, 0, 0))
    # R6 grips (design levers, see solve_holds): GripR on the pistol grip at trigger-finger height,
    # +Z hand -> elbow; GripL under the forend at its middle
    # (iteration 2: the first solve's mean wrist (0, 31, -10) deg folded into the marker, so the neutral
    # R6 'wrist' sits at the centre of its +-25 deg range: the forearm runs back along the stock)
    # (iteration 3, pocket at the shoulder top: the shouldered stances' mean wrist folded in again)
    gun.marker('GripR', mm(-228.0, 0, -55.0), (-0.385, -0.345, 0.856), (-0.92, 0.10, -0.37))
    # support forearm: back, to the left and DOWN (elbow under the gun), not sideways across the face
    zl = V((-0.5, 0.6, -0.6)).normalized()
    gun.marker('GripL', mm(150.0, 0, -42.0), (V((1, 0, 0)) - zl * zl.x).normalized(), zl)
    zt, zb = tab(ZTOP, -482.0), tab(ZBOT, -482.0)
    gun.marker('Shoulder', mm(BUTT_X, 0, (zt + zb) / 2))
    # sight line: the dot window centre, converging with the bore at 25 m; eye 0.20 m behind the optic
    zc = REC_TOP + 0.9 + 11.6
    d = V((25.0, 0, -zc * 0.001)).normalized()
    win = V(mm((OPTIC_X[0] + OPTIC_X[1]) / 2, 0, zc))
    gun.marker('SightEye', win - d * 0.20, d, (0, 0, 1))
    gun.marker('CoM', mm(-35.0, 0, -24.0))
    gun.marker('BackMount', mm(-60.0, 0, -20.0))
    gun.marker('ChargeHandle', mm(-16.0, -34.0, 0.0), (-1, 0, 0), (0, -1, 0))
    gun.marker('BoltRelease', mm(-20.0, -REC_HW - 1.9, -27.0), (0, 1, 0), (0, 0, 1))
    gun.marker('Safety', mm(-150.0, 0, 17.6), (1, 0, 0), (0, 0, 1))
    gun.marker('SlingFront', mm(TUBE_END + 6.5, 0, TUBE_Z - 22.0), (1, 0, 0), (0, 0, -1))
    gun.marker('SlingRear', mm(-407.0, 0, tab(ZBOT, -407.0) - 10.0), (1, 0, 0), (0, 0, -1))
    gun.marker('MagCap', mm(TUBE_END + 14.8, 0, TUBE_Z), (1, 0, 0), (0, 0, 1))
    gun.separate = {'Case': 'Shotgun_Case.fbx', 'Round': 'Shotgun_Round.fbx', 'RoundGreen': 'Shotgun_RoundGreen.fbx'}
    gun.colliders = {'Shell': {'size': [0.065, 0.0226, 0.0226], 'massKg': 0.032, 'axes': 'shell local: +X toward '
                               'the mouth'}}
    gun.extra = {'capacity': {'tube': 7, 'chamber': 1}, 'feed': 'tube (shell by shell into ShellPort; port load '
                 'into the open bolt at PortLoad)'}
    return gun


def vis_samples():
    """The gun's outline for the visibility term: receiver, forend, tube, barrel, stock (model mm)."""
    pts = []
    for x in range(-460, 480, 40):
        if x < -190:
            pts += [mm(x, -20, (tab(ZTOP, x) + tab(ZBOT, x)) / 2)]
        else:
            pts += [mm(x, -20, 0 if x < 20 else -20), mm(x, -16, -30)]
    return pts


def gun_samples():
    """Model-space points used by the hold solver's penetration tests (outline of the gun)."""
    pts = []
    for x in (-500, -450, -400, -350, -300, -250, -200):
        for y in (-18, 18):
            pts.append(mm(x, y, tab(ZTOP, x) - 2))
            pts.append(mm(x, y, tab(ZBOT, x) + 2))
    for x in (-180, -140, -100, -60, -20, 10):
        for y in (-14, 14):
            pts += [mm(x, y, 14), mm(x, y, -42)]
    for x in range(40, 480, 50):
        pts += [mm(x, 0, 10), mm(x, 0, -10)]
    for x in range(30, 460, 50):
        for y in (-20, 20):
            pts.append(mm(x, y, -50 if x < 300 else -42))
    pts += [mm(-270, 0, -104), mm(-107, 0, 36), mm(-145, 0, -76)]
    return pts


# --------------------------------------------------------------------------------------
# stances (long gun, ARCHITECTURE §7.3): the solver finds blade, lean, neck, shoulders, wrist
# --------------------------------------------------------------------------------------
# the shoulder pocket, on the top front of the right arm block (ARCHITECTURE §7.3: the R6 pocket is inside
# it).  The review asked for y 1.05-1.1 at z -0.55; solved, that pose cannot be reached: the rigid right arm
# is 1.505 studs pivot-to-hand and the grip sits 0.99 stud ahead of the butt, so with the butt at z -0.55 the
# grip is 1.74 studs from the shoulder pivot.  The butt therefore rides 0.3 stud further forward, sunk into
# the arm block (z -0.2), at y 1.0; with the head caps below the eye still lands on the sight line (0.02 stud)
# with the head pitched only ~4 deg.
POCKET = (0.72, 1.0, -0.2)
SUPPORT_HAND = (0.0, -0.92, -0.35)   # support hand point: the bottom-front of the left arm block (review P0-4c)
HEAD_ROLL_MAX = 15.0                 # hard caps on the head (world): a cheek weld is 10-15 deg, not a dab
HEAD_PITCH_MIN = -20.0
STANCES = [
    # head_clear 0: the cheek rests on the raised right arm block (the R6 'shoulder'); the head no longer has
    # to roll away from it.  w_cant 12 / 8 (as the rifle): w_cant 3 left the Aim canted 10 deg (consistency pass).
    dict(name='Aim', pitch=0.0, shoulder=True, pocket=POCKET, eye='line', w_eye=25.0, eye_t=(-0.25, 0.25),
         blade=-55.0, blade_tol=20.0, lean=-8.0, lean_tol=5.0, wrist_limit=25.0, w_wrist=8.0, rs_ref=(80, 0, 20),
         ls_ref=(85, 0, -40), front=14.0, w_left=16.0, head_clear=0.0, w_cant=12.0, lhand=SUPPORT_HAND, w_occl=3.0),
    dict(name='Ready', pitch=-10.0, shoulder=True, pocket=POCKET, eye='over', eye_over=0.45, blade=-50.0,
         blade_tol=20.0, lean=-5.0, wrist_limit=25.0, w_wrist=8.0, rs_ref=(70, 0, 20), ls_ref=(75, 0, -40), front=14.0,
         w_left=16.0, head_pitch=-4.0, head_clear=0.0, w_cant=8.0, lhand=SUPPORT_HAND, w_occl=3.0),
    dict(name='LowReady', pitch=-38.0, shoulder=True, pocket=(0.72, 0.85, -0.25), w_butt=4.0, blade=-38.0, w_cant=8.0,
         blade_tol=20.0, lean=-6.0, head_pitch=-12.0, wrist_limit=25.0, w_wrist=8.0, rs_ref=(40, 0, 20), ls_ref=(45, 0, -35),
         front=12.0, w_left=16.0, lhand=SUPPORT_HAND, w_occl=2.0),
    # reload key poses: the gun dropped to the belly, the stock under the right armpit, muzzle forward and a
    # little down (review P0-5), the right arm hanging forward-down instead of a T-pose.  The right-arm
    # reference is (30, 0, -50), not the review's (35, 0, 15): with a rigid R6 arm the hand can only bring the
    # grip in front of the belly by swinging the arm inward (rz about -55); with rz +15 the grip sits outside
    # the hip and the left thumb cannot reach the port.  The port ends up at y -0.18 (ReloadShell) and 0.11
    # (PortLoad: the support hand over the open port holds it a little higher).
    dict(name='ReloadShell', pitch=-8.0, yaw=18.0, cant=75.0, w_cant=2.0, blade=-25.0, blade_tol=25.0, lean=-10.0,
         lean_tol=8.0, look='LoadingPort', wrist_limit=35.0, w_wrist=8.0, rs_ref=(30, 0, -50), w_rs=12.0, ls_ref=(50, 0, -40),
         front=12.0, w_left=16.0, place=('LoadingPort', (0.35, -0.2, -1.2), 3.0), shell_load=True,
         left_limit=55.0),
    dict(name='PortLoad', pitch=-6.0, yaw=8.0, cant=-30.0, w_cant=2.0, blade=-45.0, blade_tol=25.0, lean=-8.0,
         look='PortLoad', wrist_limit=30.0, w_wrist=8.0, rs_ref=(30, 0, -50), w_rs=12.0, ls_ref=(60, 0, -40), front=12.0,
         w_left=16.0, place=('EjectionPort', (0.45, 0.0, -1.2), 8.0), port_load=True, left_limit=70.0),
]
# 3/4 front camera direction (HRP space, from the gun toward the camera) for the visibility term
CAM_34 = (0.75, 0.35, -1.0)


class ShotgunHoldSolver(gk.HoldSolver):
    """gk.HoldSolver plus the review's terms (kept here: the kit is frozen):
    - a per-stance support hand point (`lhand`, Left Arm space) instead of the arm's centre line;
    - hard caps on the head's world roll (|roll| <= 15 deg) and pitch (>= -20 deg);
    - a visibility term: the share of the gun's outline points hidden by the arms / head / torso from the
      3/4 front camera, penalised above 50 %;
    - feet on the ground: the Root drops so the lowest foot touches y = -3, and both feet are kept level;
    - an optional stronger right-shoulder reference (`w_rs`)."""

    def __init__(self, gun, samples, vis_samples):
        import numpy as np
        super().__init__(gun, samples)
        self.vis = np.array([gk.model_to_gun(p) for p in vis_samples])
        c = np.array(CAM_34, float)
        self.cam = c / np.linalg.norm(c)

    def feet(self, F):
        import numpy as np
        out = []
        for leg in ('Right Leg', 'Left Leg'):
            pts = [F[leg] @ np.array([sx * 0.5, -1.0, sz * 0.5, 1.0]) for sx in (-1, 1) for sz in (-1, 1)]
            out.append(min(float(p[1]) for p in pts))
        return out

    def pose_of(self, x, st):
        p = super().pose_of(x, st)
        F = gk.r6_frames(p)
        lowest = min(self.feet(F))
        r = list(p['Root'])
        r[4] += -3.0 - lowest
        p['Root'] = tuple(r)
        return p

    def evaluate(self, x, st):
        import numpy as np
        e = super().evaluate(x, st)
        if st.get('lhand') is not None and e['lerr'] is not None:
            hand = e['F']['Left Arm'] @ np.array(tuple(st['lhand']) + (1.0,))
            e['lhand'] = hand[:3]
            e['lerr'] = hand[:3] - e['lgoal']
        H = e['F']['Head']
        e['head_roll'] = math.degrees(math.asin(max(-1.0, min(1.0, float(H[1, 0])))))
        e['head_pitch'] = math.degrees(math.asin(max(-1.0, min(1.0, float(-H[1, 2])))))
        e['feet'] = self.feet(e['F'])
        # visibility from the 3/4 camera: ray from each outline point toward the camera through the boxes
        G = e['G']
        P = (G[:3, :3] @ self.vis.T).T + G[:3, 3]
        occ = np.zeros(len(P))
        for part, half in (('Right Arm', (0.5, 1.0, 0.5)), ('Left Arm', (0.5, 1.0, 0.5)),
                           ('Head', (0.62, 0.62, 0.62)), ('Torso', (1.0, 1.0, 0.5))):
            Fi = np.linalg.inv(e['F'][part])
            o = (Fi[:3, :3] @ P.T).T + Fi[:3, 3]
            d = Fi[:3, :3] @ self.cam
            hv = np.array(half)
            with np.errstate(divide='ignore', invalid='ignore'):
                t1 = (-hv - o) / d
                t2 = (hv - o) / d
            tmin = np.nanmax(np.minimum(t1, t2), axis=1)
            tmax = np.nanmin(np.maximum(t1, t2), axis=1)
            tmin = np.maximum(tmin, 0.0)
            seg = np.clip(tmax - tmin, 0.0, None)
            occ = np.maximum(occ, np.clip(seg / 0.15, 0.0, 1.0))
        e['occl'] = float(occ.mean())
        e['visible'] = float((occ < 0.5).mean())
        self._last = e              # residual() reads the evaluation super().residual() just made
        return e

    def residual(self, x, st):
        import numpy as np
        r = list(super().residual(x, st))
        e = self._last              # set by the evaluate() inside super().residual()
        r.append(max(0.0, abs(e['head_roll']) - HEAD_ROLL_MAX) * 1.5)
        r.append(max(0.0, HEAD_PITCH_MIN - e['head_pitch']) * 1.5)
        f = e['feet']
        r.append(abs(f[0] - f[1]) * 12.0)
        if st.get('w_occl'):
            r.append(max(0.0, e['occl'] - 0.5) * st['w_occl'])
        if st.get('w_rs') and st.get('rs_ref') is not None:
            r += [(x[6 + i] - st['rs_ref'][i]) / 240.0 * st['w_rs'] for i in range(3)]
        return np.array(r, float)
SHELL_IN = 0.016          # how deep the thumbed shell is already in the loading port (m)


def shell_hand_point(gun):
    """ReloadShell: the support thumb behind the head of a shell 16 mm into the port (model metres)."""
    p, X, Z = gun.markers['ShellPort']
    base = p - X * (0.065 - SHELL_IN)
    return base - X * 0.010, base


def portload_hand_point(gun):
    p, X, Z = gun.markers['PortLoad']
    return p - X * 0.045


def solve_holds(gun, out_json):
    vis = vis_samples()
    solver = ShotgunHoldSolver(gun, gun_samples(), vis)
    # shouldered: the stock behind the receiver lies against the cheek (the R6 head is a 0.62-stud cylinder
    # whose eye is 0.2 stud inside it, so a cheek weld means the stock comb enters the head block): the
    # penetration test keeps only the gun ahead of the tang there
    solver_sh = ShotgunHoldSolver(gun, [p for p in gun_samples() if p[0] > -0.150], vis)
    results = []
    for st in STANCES:
        st = dict(st)
        sv = solver_sh if st.get('shoulder') else solver
        if 'place' in st and isinstance(st['place'][0], str):
            nm, goal, w = st['place']
            st['place'] = (tuple(gun.markers[nm][0]), goal, w)
        if st.pop('shell_load', False):
            hp, _ = shell_hand_point(gun)
            st['left'] = tuple(hp)
            st['left_z'] = (0.30, 0.43, -0.85)        # the support arm comes from under the rolled gun
        if st.pop('port_load', False):
            st['left'] = tuple(portload_hand_point(gun))
            st['left_z'] = (-0.3, 0.2, 0.93)
        r = sv.solve(st, starts=16)
        e = r['_eval']
        r['supportHand'] = list(st.get('lhand') or gk.HAND)
        r['residuals'].update({'headRollDeg': round(e['head_roll'], 1), 'headPitchDeg': round(e['head_pitch'], 1),
                               'gunVisible34': round(e['visible'], 2), 'feetY': [round(v, 3) for v in e['feet']],
                               # reported as the other four guns do (consistency pass)
                               'cantDeg': round(math.degrees(math.asin(max(-1.0, min(1.0, float(-e['right'][1]))))), 1),
                               'rootRollDeg': r['pose']['Root'][2]})
        print('HOLD %-12s cost %.4f residuals %s pose %s wrist %s' % (r['name'], r['cost'], r['residuals'],
                                                                       r['pose'], r['wrist']), flush=True)
        results.append(r)
        # design-lever hints: the grip marker axes that would centre the solved wrist, and the left arm
        import numpy as np
        e = r['_eval']
        M2G = np.array(gk.M2G, float)
        N = solver.G_grip[:3, :3] @ gk.rotvec(r['wrist']).T
        larm = e['G'][:3, :3].T @ e['F']['Left Arm'][:3, 1]
        print('   hint GripR x %s z %s ; left arm (hand->shoulder) in model %s' % (
            np.round(M2G.T @ N[:, 0], 3), np.round(M2G.T @ N[:, 2], 3), np.round(M2G.T @ larm, 3)), flush=True)
    gk.holds_to_json(out_json, GID, results, extra={
        'note': 'Solved by tools/guns/shotgun.py (ShotgunHoldSolver over gunkit.HoldSolver). R6: rigid arms, '
                'right hand point (0,-0.92,0) in arm space, the weld is the only wrist; the support hand point is '
                'per stance (supportHand: (0,-0.92,-0.35) = bottom-front of the arm block when shouldered, so the '
                'forend rides on the end of the block). Head world roll <= 15 deg, pitch >= -20 deg; Root y drops '
                'so the feet stand on y = -3 (HRP space). Aim/Ready/LowReady: stock in the shoulder pocket '
                '(0.72, 1.08, -0.55). ReloadShell: gun at the belly, rolled belly-out (cant +75), support thumb '
                'behind a shell 16 mm into ShellPort. PortLoad: bolt locked open, gun at the belly rolled port-up '
                '(cant -30), support hand over PortLoad.',
        'markers': {k: [round(c, 5) for c in gun.markers[k][0]] for k in ('GripR', 'GripL', 'SightEye', 'Shoulder')}})
    return results, solver


# --------------------------------------------------------------------------------------
# renders
# --------------------------------------------------------------------------------------

def set_pose(objs, bolt=0.0, lifter=0.0, trigger=0.0, release=0.0, safety=0.0):
    """Moving parts away from rest (bolt metres back, lifter deg, trigger deg, release metres, safety m)."""
    o = objs
    o['Bolt'].location = V((-bolt, 0, 0))
    o['Lifter'].rotation_euler = (0, -math.radians(lifter), 0)          # hinge axis -Y: front up
    o['Trigger'].rotation_euler = (0, math.radians(trigger), 0)
    o['BoltRelease'].location = V(mm(-20.0, -REC_HW, -27.0)) + V((0, release, 0))
    o['Safety'].location = V(mm(-150.0, 0, 13.8)) + V((safety, 0, 0))
    bpy.context.view_layer.update()


def check_lifter(objs, steps=7):
    """The carrier must stay inside the receiver over its whole range: its lowest vertex never below
    REC_BOT - 1 mm (review P0-1).  Returns the worst z (mm); raises if it fails."""
    ob = objs['Lifter']
    worst = 1e9
    for k in range(steps):
        a = 12.0 * k / (steps - 1)
        set_pose(objs, lifter=a)
        mw = ob.matrix_world
        zmin = min((mw @ v.co).z for v in ob.data.vertices) * 1000.0
        worst = min(worst, zmin)
    set_pose(objs)
    print('LIFTER lowest z over 0..12 deg: %.2f mm (REC_BOT %.1f)' % (worst, REC_BOT), flush=True)
    if worst < REC_BOT - 1.0:
        raise SystemExit('lifter leaves the receiver: %.2f mm < %.1f' % (worst, REC_BOT - 1.0))
    return worst


def place_shell(src, root, M, name='ShellCopy'):
    """A linked copy of a shell model, parented to the gun root at model-space matrix M (its COM frame)."""
    ob = bpy.data.objects.new(name, src.data)
    bpy.data.collections['Studio'].objects.link(ob)
    ob.parent = root
    ob.matrix_parent_inverse = Matrix()
    ob.matrix_basis = M
    bpy.context.view_layer.update()
    return ob


def shell_frame(base, d, com):
    """Model-space matrix of a shell whose head (x = 0) sits at `base` with its axis along d."""
    d = V(d).normalized()
    M = gk.frame_x(V(base) + d * com.x, d)
    return M


REF_DEFAULT = '/tmp/claude-0/-home-user-realistic-battleground/e6e0272e-0bb1-5036-b293-d501c4bfb630/scratchpad/guns/refs/shotgun.png'


def render_all(args, gun, objs, root, ammo, com, empties, paths, holds, solver, info, want):
    from PIL import Image
    out = args.out
    studio = bpy.data.collections['Studio']
    rig = gk.Rig(studio)
    sc = bpy.context.scene
    gun_names = list(gun.order)
    gobjs = [objs[n] for n in gun_names]
    for e in empties.values():
        e.hide_render = True
    for a in ammo.values():
        a.hide_render = True
    lo, hi = gk.world_bbox(gobjs)
    floor = gk.add_floor(studio, lo.z - 0.0005)
    files = []

    def shot(name, view, res=(1600, 900), **kw):
        gk.set_res(*res)
        rig.frame((lo, hi), view, **kw)
        p = os.path.join(out, name + '.png')
        gk.render(p)
        files.append(p)
        return p

    tri_line = 'gun FBX %d tris, %d parts; L %.0f mm, H %.0f mm (no optic %.0f), W %.0f mm' % (
        info['tri_gun'], len(gun_names), info['dims']['length'] * 1000, info['dims']['height'] * 1000,
        info['dims']['heightNoOptic'] * 1000, info['dims']['width'] * 1000)
    if want('01') or want('12'):
        floor.hide_render = True
        sc.render.film_transparent = True
        gk.set_res(1800, 700)
        rig.frame((lo, hi), (0, -1, 0), ortho=True, margin=1.04)
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
            pc, iou = gk.ref_compare(ref, p1, pa, os.path.join(out, '12_reference_compare.png'),
                                     title='12-GAUGE TACTICAL side profile')
            files.append(pc)
            info['iou'] = iou
        gk.caption(p1, ['12-GAUGE TACTICAL - right side, orthographic (reference framing)', tri_line], color=(30, 30, 30))
        files.append(p1)
    if want('02'):
        shot('02_three_quarter_front', (0.85, -0.8, 0.40), lens=50)
    if want('03'):
        shot('03_three_quarter_back', (-0.85, 0.75, 0.45), lens=50)
    if want('04'):
        shot('04_top', (0, 0, 1), res=(1800, 600), ortho=True, up=(0, 1, 0), margin=1.04)
    if want('05'):
        shot('05_left_side', (0, 1, 0), res=(1800, 700), ortho=True, margin=1.04)
    if want('06'):
        gk.set_res(1600, 1000)
        slo, shi = V(mm(-200, -30, -80)), V(mm(30, 20, 40))
        rig.frame((slo, shi), (0.45, -0.85, -0.25), lens=70, margin=1.0)
        p = os.path.join(out, '06_closeup_action.png')
        gk.render(p)
        files.append(p)
    if want('08'):
        # the feed cycle seen from below-right: bolt locked back (chamber mouth open in the ejection port), the
        # carrier swung front-up 12 deg in the loading port lifting a shell toward the chamber, a spent hull
        # leaving the port
        set_pose(objs, bolt=mm(BOLT_STROKE), lifter=12.0, trigger=12.0, release=mm(3.0), safety=mm(5.0))
        T = objs['Lifter'].matrix_world @ Matrix.Translation(-V(mm(LIFTER_PIVOT[0], 0, LIFTER_PIVOT[1])))
        rest = Matrix.Translation(V(mm(LPORT_X[0] + 9.0, 0, REC_BOT + 17.5)) + V((com['Shotgun_Round'].x, 0, 0)))
        sh = place_shell(ammo['Shotgun_Round'], root, T @ rest)                   # a shell riding in the trough
        cs = place_shell(ammo['Shotgun_Case'], root, Matrix.Translation(V(mm(-20.0, -85.0, 45.0))) @
                         Matrix.Rotation(math.radians(30), 4, 'Z') @ Matrix.Rotation(math.radians(-20), 4, 'Y'))
        floor.hide_render = True
        gk.set_res(1100, 820)
        # (a) the ejection port from the right, a little above: bolt face back, raceway, chamber mouth
        slo, shi = V(mm(-140, -40, -30)), V(mm(25, 20, 40))
        cs.hide_render = True                    # the hull would hide the port; it shows in 09 and the exploded view
        rig.frame((slo, shi), (0.30, -1.0, 0.30), lens=60, margin=1.0)
        pa = os.path.join(out, '_08a_port.png')
        gk.render(pa)
        # (b) from underneath: the loading port, the carrier swung front-up with its shell (the studio's top
        # light goes under the gun for this one)
        cs.hide_render = True
        slo, shi = V(mm(-150, -30, -60)), V(mm(20, 30, -20))
        rig.frame((slo, shi), (0.55, -0.35, -0.85), lens=60, margin=1.0)
        ctr = (slo + shi) / 2
        top = rig.lights['Top']
        rig.aim(top, ctr + V((0.05, -0.10, -0.45)), ctr)
        top.data.size = 0.25
        pb = os.path.join(out, '_08b_loading_port.png')
        gk.render(pb)
        cs.hide_render = False
        floor.hide_render = False
        p = gk.grid([pa, pb], os.path.join(out, '08_bolt_locked_shell_in.png'), cols=2, tw=1100, th=820,
                    labels=['ejection port: bolt locked back 75 mm, chamber mouth open, the lifted shell below',
                            'loading port from below-front: carrier swung FRONT UP 12 deg (the shell rides on top of it)'],
                    title='feed cycle: bolt locked back, carrier up (hinge -Y, 0 -> 12 deg), trigger +12 deg, '
                          'bolt release pressed, safety on FIRE')
        files.append(p)
        for ob in (sh, cs):
            bpy.data.objects.remove(ob)
        set_pose(objs)
    if want('07'):
        offs = {'Bolt': V((-0.085, -0.10, 0.04)), 'ChargingHandle': V((0, -0.02, 0)), 'Lifter': V((0, 0, -0.09)),
                'BoltRelease': V((0, -0.06, -0.02)), 'Trigger': V((0, 0, -0.10)), 'TriggerGuard': V((0, 0, -0.06)),
                'Safety': V((0, 0, 0.06)), 'Optic': V((0, 0, 0.07)), 'OpticLens': V((0.02, 0, 0.0)),
                'Stock': V((-0.08, 0, 0)), 'RecoilPad': V((-0.05, 0, 0)), 'Forend': V((0, 0, -0.09)),
                'MagCap': V((0.06, 0, 0)), 'BarrelClamp': V((0, 0, 0.07)), 'SightFront': V((0, 0, 0.04)),
                'Pins': V((0, 0.08, 0)), 'MagTube': V((0, 0, -0.035))}
        base = {n: objs[n].location.copy() for n in offs}
        for n, d in offs.items():
            objs[n].location = base[n] + d
        bpy.context.view_layer.update()
        lo2, hi2 = gk.world_bbox(gobjs)
        gk.set_res(1800, 1100)
        rig.frame((lo2, hi2), (0.25, -1, 0.3), lens=45, margin=1.08)
        p = os.path.join(out, '07_exploded.png')
        gk.render(p)
        items = []
        lab = {'Receiver': (0, -70), 'Barrel': (0, -60), 'SightFront': (0, -40), 'MagTube': (40, 50), 'MagCap': (40, 40),
               'BarrelClamp': (0, -50), 'Forend': (0, 60), 'Stock': (-40, -60), 'RecoilPad': (-30, 60),
               'TriggerGuard': (-60, 40), 'Trigger': (40, 40), 'Safety': (-50, -40), 'Bolt': (-60, -40),
               'ChargingHandle': (50, 30), 'Lifter': (50, 40), 'BoltRelease': (60, 10), 'Optic': (50, -40),
               'OpticLens': (60, -20), 'Pins': (-40, -40)}
        for n, dxy in lab.items():
            blo, bhi = gk.world_bbox([objs[n]])
            items.append((n, (blo + bhi) / 2, dxy))
        gk.label_points(p, items, size=18)
        gk.caption(p, ['exploded: named parts of Shotgun.fbx (moving: Bolt + ChargingHandle, Lifter, BoltRelease, '
                       'Trigger, Safety)'])
        files.append(p)
        for n in offs:
            objs[n].location = base[n]
        bpy.context.view_layer.update()
    if want('09'):
        for ob in gobjs:
            ob.hide_render = True
        rd, rg, cs = ammo['Shotgun_Round'], ammo['Shotgun_RoundGreen'], ammo['Shotgun_Case']
        fz = floor.location.z
        keep = {o: o.matrix_world.copy() for o in (rd, rg, cs)}
        for o in (rd, rg, cs):
            o.hide_render = False
        up = Matrix.Rotation(-math.pi / 2, 4, 'Y')     # +X -> +Z (standing on the head)
        rd.matrix_world = Matrix.Translation(V((0.0, 0.0, fz + com['Shotgun_Round'].x))) @ up
        rg.matrix_world = Matrix.Translation(V((0.0, 0.032, fz + com['Shotgun_RoundGreen'].x))) @ up
        cs.matrix_world = Matrix.Translation(V((0.045, -0.01, fz + 0.0113))) @ Matrix.Rotation(0.6, 4, 'Z')
        r2 = place_shell(rd, None, Matrix.Translation(V((0.05, 0.05, fz + 0.0113))) @ Matrix.Rotation(-0.4, 4, 'Z'))
        r2.parent = None
        r2.matrix_world = Matrix.Translation(V((0.05, 0.055, fz + 0.0113))) @ Matrix.Rotation(-0.4, 4, 'Z')
        bpy.context.view_layer.update()
        alo, ahi = gk.world_bbox([rd, rg, cs, r2])
        gk.set_res(1400, 900)
        rig.frame((alo, ahi), (0.75, -0.8, 0.55), lens=60, margin=1.1)
        p = os.path.join(out, '09_shells.png')
        gk.render(p)
        t = info['tri_ammo']
        gk.caption(p, ['12 ga 2 3/4 in shells: loaded red (%d tris) and green (%d), folded star crimp, brass head; '
                       % (t['Shotgun_Round'], t['Shotgun_RoundGreen']),
                       'spent hull, crimp opened, struck primer (%d tris)' % t['Shotgun_Case']])
        files.append(p)
        bpy.data.objects.remove(r2)
        for o, m in keep.items():
            o.matrix_world = m
            o.hide_render = True
        for ob in gobjs:
            ob.hide_render = False
        bpy.context.view_layer.update()
    if want('10') and paths:
        bm_ = gk.baked_material('BakedShotgun', paths)
        saved = gk.swap_materials(gobjs, bm_)
        p = shot('10_game_look_baked', (0.85, -0.8, 0.40), lens=50)
        gk.caption(p, ['GAME LOOK: the baked 1024 atlas only (Color / Normal / Roughness / Metalness), as a '
                       'SurfaceAppearance'])
        gk.restore_materials(saved)
    if want('11'):
        saved = gk.swap_materials(gobjs, gk.MAT['FlatGrey'])
        p = shot('11_game_mesh', (0.85, -0.8, 0.40), lens=50)
        gk.caption(p, ['game mesh (flat grey): ' + tri_line])
        gk.restore_materials(saved)
    hold_files = []
    if holds and want('13'):
        floor.hide_render = True
        for r in holds:
            hold_files.append(render_hold(args, rig, gun, objs, root, gobjs, ammo, com, r))
        floor.hide_render = False
        files += hold_files
    keyf = sorted(f for f in files if os.path.basename(f)[:2].isdigit())
    if keyf:
        sheet = gk.contact_sheet(keyf, os.path.join(out, 'shotgun_sheet.png'), '12-GAUGE TACTICAL (tools/guns/shotgun.py)'
                                 ' - ' + tri_line, cols=3)
        if not args.no_export:
            import shutil
            shutil.copy(sheet, os.path.join(args.assets, 'shotgun_sheet.png'))
            if hold_files:
                gk.grid(hold_files, os.path.join(args.assets, 'shotgun_holds.png'), cols=2, tw=1100, th=820,
                        title='12-GAUGE TACTICAL - solved R6 holds (front 3/4, side, hands, eye)')


def render_hold(args, rig, gun, objs, root, gobjs, ammo, com, r):
    """One stance on the R6 dummy: front 3/4, right side, hands close-up and the eye's view, 2x2 grid."""
    import numpy as np
    e = r['_eval']
    studio = bpy.data.collections['Studio']
    dummy = gk.build_r6(studio, e['F'], name='R6_' + r['name'])
    extra = []
    if r['name'] == 'ReloadShell':
        set_pose(objs, lifter=6.0)
        _, base = shell_hand_point(gun)
        extra.append(place_shell(ammo['Shotgun_Round'], root, shell_frame(base, gun.markers['ShellPort'][1],
                                                                          com['Shotgun_Round'])))
    if r['name'] == 'PortLoad':
        set_pose(objs, bolt=mm(BOLT_STROKE))
        p, X, Z = gun.markers['PortLoad']
        base = p - X * 0.030 + V((-0.030, 0, 0))
        extra.append(place_shell(ammo['Shotgun_Round'], root, shell_frame(base, (1, 0, 0), com['Shotgun_Round'])))
    gk.place_gun(root, e['G'])
    floor = gk.add_floor(studio, -3 * gk.STUD - 0.001, 'Ground')
    lo, hi = gk.world_bbox(dummy + gobjs)
    names = []
    res = r['residuals']
    head = [o for o in dummy if o.name.endswith('Head')][0]
    arms = [o for o in dummy if 'Arm' in o.name]
    for tag, view, kw in (('front', (1.0, -0.75, 0.35), dict(lens=45)), ('side', (0.0, -1.0, 0.08), dict(lens=45)),
                          ('close', (1.0, -0.55, 0.25), dict(lens=55)), ('eye', None, {})):
        gk.set_res(1100, 820)
        bpy.context.scene.cycles.samples = 24 if not args.quick else 8
        if view is None:
            head.hide_render = True
            for o in arms:
                o.hide_render = True
            eye_b = gk.r2b_point(e['eye'])
            if 'sight_d' in e and r['name'] in ('Aim', 'Ready', 'LowReady'):
                tgt = gk.r2b_point(e['eye'] + e['sight_d'] * 4.0)
            else:
                lt = e.get('lgoal', e['eye'] + np.array([0, 0, -4.0]))
                tgt = gk.r2b_point(lt)
            rig.cam.data.type = 'PERSP'
            rig.cam.data.lens = 24
            rig.cam.data.clip_start = 0.01
            rig.aim(rig.cam, eye_b, tgt)
            rig.place_lights((lo + hi) / 2, 2.5)
        elif tag == 'close':
            G = e['G']
            mid = gk.model_to_gun(mm(-40, 0, -30)) if r['name'] in ('Aim', 'Ready', 'LowReady') else \
                gk.model_to_gun(mm(-60, 0, -40))
            c = gk.r2b_point((G @ np.append(mid, 1.0))[:3])
            rig.frame((c - V((0.33, 0.33, 0.22)), c + V((0.33, 0.33, 0.22))), view, margin=1.0, **kw)
        else:
            head.hide_render = False
            rig.frame((lo, hi), view, margin=1.08, **kw)
        p = os.path.join(args.out, '_hold_%s_%s.png' % (r['name'], tag))
        gk.render(p)
        names.append(p)
    head.hide_render = False
    for o in arms:
        o.hide_render = False
    txt = '%s: blade %.0f, lean %.0f, wrist %.0f deg; left hand %.3f stud%s%s; bore yaw/pitch %s' % (
        r['name'], r['pose']['Root'][1], r['pose']['Root'][0], res['wristDeg'], res.get('left', float('nan')),
        ('; eye to sight line %.3f stud' % res['eyeToSightLine']) if r['name'] == 'Aim' else '',
        ('; butt in torso %s' % (res['buttInTorso'],)) if 'buttInTorso' in res and r['name'] in
        ('Aim', 'Ready', 'LowReady') else '', res['boreYawPitch'])
    outp = gk.grid(names, os.path.join(args.out, '13_hold_%s.png' % r['name']), cols=2, tw=1100, th=820,
                   labels=['front 3/4', 'right side', 'hands close-up', 'eye view (head and arms hidden)'], title=txt)
    for o in dummy + extra:
        bpy.data.objects.remove(o)
    bpy.data.objects.remove(floor)
    root.matrix_world = Matrix()
    set_pose(objs)
    bpy.context.view_layer.update()
    return outp


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='/tmp/shotgun_out')
    ap.add_argument('--assets', default=os.path.join(ROOT, 'assets', 'guns', 'Shotgun'))
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
    extra_materials()
    samples = 16 if args.quick else args.samples
    gk.setup_render(samples, (1600, 1000))
    col = bpy.data.collections.new('Shotgun')
    bpy.context.scene.collection.children.link(col)
    studio = bpy.data.collections.new('Studio')
    bpy.context.scene.collection.children.link(studio)
    gun = build_model()
    objs = gun.build(col)
    root = bpy.data.objects.new('GunRoot', None)
    col.objects.link(root)
    for n, ob in objs.items():
        if ob.parent is None:
            ob.parent = root
    empties = gun.empties(studio)
    check_lifter(objs)
    ammo, com = build_shells(col)
    gk.finish_meshes(objs)          # triangulated, no degenerates (ARCHITECTURE §5.1)
    gk.finish_meshes(ammo)
    tris = gk.tri_counts(objs)
    tri_gun = sum(tris[n] for n in gun.order)
    tri_ammo = gk.tri_counts(ammo)
    print('TRIS', tris, 'gun FBX total', tri_gun, 'ammo', tri_ammo, flush=True)

    lo, hi = gk.world_bbox([objs[n] for n in gun.order])
    lo2, hi2 = gk.world_bbox([objs[n] for n in gun.order if n not in ('Optic', 'OpticLens')])
    dims = {'length': round(hi.x - lo.x, 4), 'barrel': round(mm(MUZZLE_X), 4), 'height': round(hi.z - lo.z, 4),
            'heightNoOptic': round(hi2.z - lo2.z, 4), 'width': round(hi.y - lo.y, 4), 'boltStroke': mm(BOLT_STROKE)}
    gun.dims = dims
    print('DIMS', dims, flush=True)

    atlas_objs = [objs[n] for n in gun.order]
    gk.uv_atlas(atlas_objs, margin=0.003)
    gk.uv_atlas(list(ammo.values()), margin=0.01)
    paths = None
    if not args.no_bake:
        paths = gk.bake_atlas(atlas_objs, args.assets, GID, size=1024, samples=12)
        gk.bake_atlas(list(ammo.values()), args.assets, GID + '_Ammo', size=256, samples=12)
    if not args.no_export:
        gk.export_fbx(atlas_objs, os.path.join(args.assets, GID + '.fbx'))
        for n in ('Shotgun_Case', 'Shotgun_Round', 'Shotgun_RoundGreen'):
            gk.export_fbx([ammo[n]], os.path.join(args.assets, n + '.fbx'))
        gun.to_json(os.path.join(args.assets, 'shotgun.markers.json'),
                    tris={**{n: tris[n] for n in gun.order}, 'gunFbx': tri_gun, 'case': tri_ammo['Shotgun_Case'],
                          'round': tri_ammo['Shotgun_Round'], 'roundGreen': tri_ammo['Shotgun_RoundGreen']})
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(args.out, 'shotgun.blend'))

    holds, solver = None, None
    if not args.no_holds:
        holds, solver = solve_holds(gun, os.path.join(HERE, 'shotgun_holds.json'))
    if args.no_render:
        return
    info = dict(tris=tris, tri_gun=tri_gun, tri_ammo=tri_ammo, dims=dims)
    render_all(args, gun, objs, root, ammo, com, empties, paths, holds, solver, info, want)
    if 'iou' in info:
        print('IOU %.3f' % info['iou'], flush=True)


if __name__ == '__main__':
    main()
