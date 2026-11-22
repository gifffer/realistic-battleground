#!/usr/bin/env python3
"""The 9MM COMPACT: a compact polymer-frame, striker-fired 9x19 pistol (original generic design in the
class of the reference photo: no logos, no copied markings; only a generic 'RB-04127' / '9x19' stamp).

Builds the model from code (tools/guns/gunkit.py), follows the Model contract (docs/firearms/ARCHITECTURE.md
§5), bakes a 1024 atlas for a Roblox SurfaceAppearance, exports the FBXs and the markers JSON to
assets/guns/Pistol/, solves the R6 holds (pistol_holds.json next to this script) and renders the review set.

Real-world class dimensions (compact striker 9 mm): overall length 185 mm, barrel 102 mm, height 128 mm with
the magazine, slide width 25.5 mm, grip width 30 mm, 15-round double-stack magazine, 0.85 kg loaded.
Side-profile coordinates were measured on the reference photo (6.2 px/mm at x3, see docs in README) and are
given in millimetres in model space (+X muzzle, +Z up, origin at the breech face on the bore).

Moving parts: Slide (slides -X, stroke 28 mm, locks back on empty), Barrel (tilts -2.5 deg about +Y under
the chamber), Trigger (+10 deg about +Y at the blade top), SlideStop (-6 deg, front end up), MagRelease
(-Y 3 mm), Magazine (drops along its MagWell +X).

Usage:
  /home/user/z-anatomy/venv/bin/python -I tools/guns/pistol.py --out DIR [--assets assets/guns/Pistol]
      [--samples 48] [--only 01,02] [--quick] [--no-bake] [--no-holds] [--no-render] [--ref photo.png]
"""
import argparse
import json
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
GID = 'Pistol'


def mm(*a):
    """mm -> metres (a number, a point or a list of 2D points)."""
    if len(a) == 1 and isinstance(a[0], (int, float)):
        return a[0] * 0.001
    if len(a) == 1:
        return [(p[0] * 0.001, p[1] * 0.001) for p in a[0]]
    return tuple(c * 0.001 for c in a)


# --------------------------------------------------------------------------------------
# layout (mm, model space)
# --------------------------------------------------------------------------------------
SLIDE_X = (-67.9, 99.5)
SLIDE_Z = (-11.5, 9.7)
SLIDE_HW = 12.75                  # slide half width (25.5 mm)
STROKE = 28.0                     # slide travel to lock back
MUZZLE_X = 102.0                  # barrel crown = barrel length from the breech face
BORE_R = 4.5
GRIP_ANG = math.radians(20.5)     # grip / magazine angle from vertical (measured on the reference)
MAG_AX = (-math.sin(GRIP_ANG), -math.cos(GRIP_ANG))      # down the magazine (x, z): its extraction direction
MAG_FR = (math.cos(GRIP_ANG), -math.sin(GRIP_ANG))       # the magazine's front
MAGWELL = (-17.0, -14.0)          # top centre of the seated magazine (feed lips)
MAG_LEN = 107.3                   # lip top to baseplate bottom
MAG_DEPTH, MAG_W = 32.0, 22.5
REAR_SIGHT = (-61.0, -54.0)
FRONT_SIGHT = (89.5, 93.5)
REAR_TOP, FRONT_TOP = 14.0, 13.9  # sight tops: the line converges with the bore at ~25 m


def mag_pt(s, d=0.0):
    """Point (x, z) mm at distance s down the magazine axis and d toward its front."""
    return (MAGWELL[0] + MAG_AX[0] * s + MAG_FR[0] * d, MAGWELL[1] + MAG_AX[1] * s + MAG_FR[1] * d)


# --------------------------------------------------------------------------------------
# frame (polymer): dust cover + rail, trigger guard, upper rear frame, grip with finger grooves
# --------------------------------------------------------------------------------------

def _interp(table, z):
    """Linear interpolation of x(z) in a [(x, z), ...] table sorted by decreasing z."""
    for (xa, za), (xb, zb) in zip(table[:-1], table[1:]):
        if za >= z >= zb:
            t = (za - z) / (za - zb) if za != zb else 0.0
            return xa + (xb - xa) * t
    return table[0][0] if z > table[0][1] else table[-1][0]


# grip front edge x(z) above the front strap (the rear of the trigger-guard opening)
GRIP_FRONT = [(1.0, -29.0), (0.6, -30.5), (-0.8, -33.0), (-1.6, -38.0), (-1.7, -42.0), (-1.4, -47.0),
             (-2.6, -50.6), (-4.6, -52.4), (-6.5, -53.0)]
# backstrap x(z): palm swell, beavertail undercut (measured on the reference)
BACK = [(-58.6, -29.0), (-58.6, -34.5), (-60.4, -38.5), (-63.0, -44.0), (-65.0, -48.5), (-68.4, -58.0),
        (-72.2, -69.0), (-76.0, -80.0), (-79.6, -92.0), (-81.6, -100.0), (-82.2, -103.8), (-81.4, -105.2)]
STRAP_L = 55.0


def front_x(z):
    """Grip front x at height z (mm): the guard junction, then the front strap with two finger humps
    (finger grooves of the reference) along the 20.5 deg grip line."""
    if z >= -53.0:
        return _interp(GRIP_FRONT, z)
    s = (-53.0 - z) / math.cos(GRIP_ANG)
    off = 3.0 * math.exp(-((s - 19.5) / 3.8) ** 2) + 3.0 * math.exp(-((s - 37.5) / 3.8) ** 2) \
        - 0.7 * math.exp(-((s - 10.0) / 6.0) ** 2) - 0.7 * math.exp(-((s - 28.5) / 5.0) ** 2) \
        - 0.6 * math.exp(-((s - 46.5) / 5.0) ** 2)
    return -6.5 - s * math.sin(GRIP_ANG) + off / math.cos(GRIP_ANG)


def grip_half_width(z):
    """Half width (mm) of the grip at height z: 12.7 where it meets the 25.4 upper frame, 14.75 in the
    palm, a touch narrower at the bottom."""
    return 12.7 + 2.05 * gk.smoothstep(-37.0, -52.0, z) - 0.35 * gk.smoothstep(-90.0, -105.0, z)


GRIP_Z = [-29.0, -36.0, -42.0, -48.0, -52.2, -56.5, -62.0, -66.5, -69.0, -71.3, -73.8, -77.0, -80.5, -83.6, -86.0,
          -88.1, -90.5, -93.5, -98.0, -103.0, -104.6, -105.2]
WELL_Z = [-44.0, -60.0, -80.0, -100.0, -103.8, -105.2]


def well_center_x(z):
    s = (MAGWELL[1] - z) / math.cos(GRIP_ANG)
    return MAGWELL[0] - s * math.sin(GRIP_ANG)


def build_grip(bm, P):
    """The grip: horizontal rounded sections stacked from the upper frame down to the frame bottom (finger
    humps, palm swell, rounded straps), hollow from below for the magazine well (the mag really drops
    out of a well)."""
    rings = []
    for z in GRIP_Z:
        xf, xb = front_x(z), _interp(BACK, z)
        hw = grip_half_width(z)
        inset = 0.0
        if z < -104.0:
            inset = 1.4 if z > -105.0 else 2.6                # rounded bottom edge
        cx, hx = (xf + xb) / 2, (xf - xb) / 2 - inset
        sec = gk.rrect2(cx, 0.0, hx, hw - inset, r_pos=min(10.0, hw * 0.75), r_neg=min(8.5, hw * 0.65), n=3)
        rings.append([mm(x, y, z) for x, y in sec])
    inner = []
    for z in WELL_Z:
        cx = well_center_x(z)
        hx = (MAG_DEPTH + 1.4) / 2 / math.cos(GRIP_ANG)
        hy = (MAG_W + 1.2) / 2
        flare = 1.6 if z < -103.0 else 0.0
        sec = gk.rrect2(cx, 0.0, hx + flare, hy + flare, r_pos=4.0, r_neg=4.0, n=3)
        inner.append([mm(x, y, z) for x, y in sec])
    gk.loft(bm, rings, cap0=True, mi=P, inner=inner)


def build_frame(gun):
    fr = gun.part('Frame', paint='Polymer', fit=1)
    P, S = fr.mi('Polymer'), fr.mi('PolymerStipple')
    bm = fr.bm
    # (A) one outline for the upper frame behind the dust cover: trigger housing, thumb shelf, tang (25.4 wide)
    A = [(45.0, -11.5), (45.0, -27.0), (40.5, -29.3), (2.0, -29.3), (-1.0, -33.0), (-3.0, -38.0),
         (-60.4, -38.0), (-58.6, -34.5), (-57.6, -30.0), (-59.0, -25.5), (-62.5, -21.5), (-66.8, -18.6),
         (-70.6, -16.6), (-72.0, -14.6), (-71.4, -12.3), (-69.6, -11.5)]
    radii = [0, 0, 2.0, 1.5, 1.5, 1.0, 0, 1.0, 1.2, 1.5, 1.5, 1.5, 1.0, 1.2, 1.0, 0.8]
    gk.profile(bm, mm(gk.fillet2(A, 1.0, 1, radii=radii)), mm(25.4), bevel=mm(1.5), bevel_segs=1, mi=P)
    # dust cover with the accessory-rail grooves and its cross slot: a cross-section run along X
    def dust(zb):
        return [(-12.8, -11.5), (12.8, -11.5), (12.8, -21.3), (11.4, -21.7), (11.4, -24.1), (12.5, -24.5),
                (12.5, zb + 1.2), (11.3, zb), (-11.3, zb), (-12.5, zb + 1.2), (-12.5, -24.5), (-11.4, -24.1),
                (-11.4, -21.7), (-12.8, -21.3)]
    dc = bmesh.new()
    gk.section_x(dc, mm(dust(-27.6)), mm(36.0), mm(98.9), end_bevel=mm(1.3), mi=P)
    c = bmesh.new()
    gk.box(c, mm(63.0, 0, -27.6), mm(4.8, 30.0, 5.2), mi=P)               # the rail's cross slot
    gk.boolean_bm(dc, c)
    gk.merge(bm, dc)
    # (B) the grip
    build_grip(bm, P)
    # (C) the trigger guard loop (10.8 wide), with the serrated front (raised ridges)
    C = [(47.0, -27.4), (46.1, -31.0), (45.6, -49.0), (44.9, -53.6), (42.0, -56.9), (36.0, -57.7), (3.0, -57.7),
         (-3.0, -57.0), (-7.0, -54.0), (-8.0, -40.0), (-2.0, -29.0)]
    hole = [(38.0, -29.9), (38.4, -48.8), (36.8, -51.4), (32.5, -51.8), (3.5, -51.8), (-1.5, -50.6), (-4.0, -46.0),
            (-4.0, -31.0), (-2.0, -29.9)]
    gk.profile(bm, mm(gk.fillet2(C, 1.2, 1, radii=[0, 1, 0, 1.5, 2.0, 1.5, 1.5, 2.0, 2.0, 0, 0])), mm(10.8),
               holes=[mm(gk.fillet2(hole, 2.2, 1))], bevel=mm(1.4), bevel_segs=0, mi=P)
    for k in range(6):
        gk.box(bm, mm(46.0, 0, -33.0 - k * 2.6), mm(0.9, 7.6, 1.0), mi=P)
    # stipple on the grip below the thumb shelf (sides and straps), smooth above
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        c = f.calc_center_median()
        if mm(-103.5) < c.z < mm(-42.0) and c.x < mm(-3.0) and f.normal.z > -0.7:
            f.material_index = S
    return fr


def build_pins(gun):
    """Takedown lever tabs (both sides), the frame pins and the trigger-housing pin: static steel."""
    pp = gun.part('Pins', paint='SteelBlued')
    St = pp.mi('SteelBlued')
    bm = pp.bm
    tab = [(19.6, -14.6), (26.2, -14.6), (26.2, -21.0), (24.8, -22.8), (19.6, -22.8)]
    for sy in (1, -1):
        y0 = sy * 11.75
        y1 = sy * 12.75
        gk.prism(bm, mm(gk.fillet2(tab, 0.6, 1)), mm(min(y0, y1)), mm(max(y0, y1)), mi=St)
        for k in range(3):
            gk.box(bm, mm(20.8 + k * 2.0, sy * 12.8, -18.6), mm(0.7, 0.3, 6.0), mi=St)
    for (x, z, y, r) in ((8.4, -14.0, 12.0, 1.6), (11.3, -21.4, 12.0, 1.6), (-51.0, -38.0, 13.9, 1.5)):
        gk.pin(bm, mm(x, y, z), (0, 1, 0), mm(r), proud=mm(0.25), segs=7, mi=St, both=mm(2 * y))
    return pp


# --------------------------------------------------------------------------------------
# slide (steel) with sights, extractor, cover plate
# --------------------------------------------------------------------------------------

def build_slide(gun):
    sl = gun.part('Slide', paint='SteelBlued', fit=None)
    St, Pl, Bo = sl.mi('SteelBlued'), sl.mi('Polymer'), sl.mi('Bore')
    bm = sl.bm
    hw = SLIDE_HW
    z0, z1 = SLIDE_Z
    sec = [(-hw, z0 + 0.8), (-hw + 0.8, z0), (hw - 0.8, z0), (hw, z0 + 0.8), (hw, 6.8), (9.9, z1), (-9.9, z1),
           (-hw, 6.8)]
    gk.section_x(bm, mm(sec), mm(SLIDE_X[0]), mm(SLIDE_X[1]), end_bevel=mm(0.9), mi=St)
    cuts = []
    # front nose: chamfers top and bottom of the muzzle end
    for z, ang in ((z1, 45), (z0, -40)):
        c = bmesh.new()
        R = Matrix.Rotation(math.radians(ang), 3, 'Y')
        gk.box(c, mm(SLIDE_X[1] + 0.4, 0, z), mm(4.2, 40.0, 4.2), R=R, mi=St)
        cuts.append(c)
    # ejection port (right side = -Y): pocket deep enough to show the barrel hood and darkness
    c = bmesh.new()
    port = [(-7.5, -3.5), (24.5, -3.5), (24.5, 12.0), (-7.5, 12.0)]
    gk.prism(c, mm(gk.fillet2(port, 1.2, 1)), mm(-15.0), mm(2.6), mi=St)
    cuts.append(c)
    # barrel hole in the slide nose
    c = bmesh.new()
    gk.cyl(c, mm(90.0, 0, 0), mm(101.0, 0, 0), mm(6.95), 20, mi=Bo)
    cuts.append(c)
    # rear and front serrations (both sides)
    cuts.append(gk.serration_cutter(mm(-61.0), mm(-32.5), 8, mm(1.55), mm(0.9), mm(hw), mm(z0 - 1), mm(7.6), mi=St))
    cuts.append(gk.serration_cutter(mm(69.0), mm(87.0), 5, mm(1.4), mm(0.8), mm(hw), mm(z0 - 1), mm(7.4), lean=0,
                                    mi=St))
    # rear: cover plate recess
    c = bmesh.new()
    gk.box(c, mm(SLIDE_X[0], 0, -2.6), mm(1.6, 10.8, 13.6), mi=Pl)
    cuts.append(c)
    gk.boolean_bm(bm, cuts)
    # the cover plate (polymer, slightly proud) with its striker-channel indicator dimple
    gk.rbox(bm, mm(SLIDE_X[0] + 0.15, 0, -2.6), mm(1.0, 10.4, 13.2), mm(0.35), 1, mi=Pl)
    # serial-like stamp plate area on the left flat is in the material; nothing modelled
    return sl


def build_sights(gun):
    rs = gun.part('SightRear', paint='SteelBlued', parent='Slide')
    St, Wh = rs.mi('SteelBlued'), rs.mi('SightPaint')
    x0, x1 = REAR_SIGHT
    side = [(x0, 9.2), (x1, 9.2), (x1, 11.2), (x1 - 2.5, REAR_TOP), (x0, REAR_TOP)]
    gk.profile(rs.bm, mm(gk.fillet2(side, 0.6, 1)), mm(12.6), bevel=mm(0.45), bevel_segs=1, mi=St)
    c = bmesh.new()
    gk.box(c, mm((x0 + x1) / 2, 0, REAR_TOP), mm(12.0, 3.4, 4.6), mi=St)       # U notch
    gk.cyl(c, mm(x0 - 2, 0, REAR_TOP - 2.3), mm(x1 + 2, 0, REAR_TOP - 2.3), mm(1.7), 10, mi=St)
    gk.boolean_bm(rs.bm, c)
    # white U outline on the rear face
    xr = x0 - 0.12
    for (yc, zc, wy, hz) in ((-2.35, REAR_TOP - 1.25, 0.9, 2.5), (2.35, REAR_TOP - 1.25, 0.9, 2.5),
                             (0.0, REAR_TOP - 4.35, 5.6, 0.9)):
        gk.box(rs.bm, mm(xr, yc, zc), mm(0.25, wy, hz), mi=Wh)
    # front sight blade with a white dot
    fsg = gun.part('SightFront', paint='SteelBlued', parent='Slide')
    St2, Wh2 = fsg.mi('SteelBlued'), fsg.mi('SightPaint')
    a, b = FRONT_SIGHT
    side = [(a, 9.2), (b, 9.2), (b, FRONT_TOP - 1.1), (b - 1.0, FRONT_TOP), (a, FRONT_TOP)]
    gk.profile(fsg.bm, mm(gk.fillet2(side, 0.5, 1)), mm(3.4), bevel=mm(0.35), bevel_segs=1, mi=St2)
    gk.cyl(fsg.bm, mm(a + 0.05, 0, FRONT_TOP - 1.5), mm(a - 0.18, 0, FRONT_TOP - 1.5), mm(0.95), 10, mi=Wh2)
    return rs, fsg


def build_extractor(gun):
    ex = gun.part('Extractor', paint='SteelBlued', parent='Slide')
    St = ex.mi('SteelBlued')
    out = [(-20.0, 1.8), (-7.0, 1.8), (-6.2, 3.2), (-7.0, 6.6), (-20.0, 6.6), (-21.0, 4.2)]
    gk.prism(ex.bm, mm(gk.fillet2(out, 0.6, 1)), mm(-SLIDE_HW - 0.55), mm(-SLIDE_HW + 0.3), mi=St)
    gk.box(ex.bm, mm(-15.0, -SLIDE_HW - 0.6, 4.2), mm(3.0, 0.2, 0.6), mi=St)    # the loaded-chamber step
    return ex


def build_barrel(gun):
    br = gun.part('Barrel', paint='SteelBlued', origin=mm(22.0, 0, -9.0), fit=2)
    St, Bo, Ba = br.mi('SteelBlued'), br.mi('Bore'), br.mi('SteelBare')
    bm = br.bm
    # hood (fills the ejection port) and chamber block
    gk.rbox(bm, mm(11.6, 0, 1.15), mm(25.6, 16.8, 15.3), mm(0.6), 1, mi=St)
    # tube with a crowned muzzle and an open bore
    prof = [(24.0, 0.0), (24.0, 6.8), (40.0, 6.6), (MUZZLE_X - 0.8, 6.45), (MUZZLE_X, 6.1), (MUZZLE_X, BORE_R + 0.4),
            (MUZZLE_X - 0.6, BORE_R), (MUZZLE_X - 12.0, BORE_R), (MUZZLE_X - 12.0, 0.0)]
    gk.lathe(bm, [(x * 0.001, r * 0.001) for x, r in prof], 14, gk.frame_x(V((0, 0, 0)), (1, 0, 0)), mi=St)
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        c = f.calc_center_median()
        if c.x > mm(MUZZLE_X - 12.5) and math.hypot(c.y, c.z) < mm(BORE_R + 0.1) and abs(f.normal.x) < 0.9:
            f.material_index = Bo
        if c.x > mm(MUZZLE_X - 12.5) and abs(f.normal.x) > 0.9 and math.hypot(c.y, c.z) < mm(BORE_R + 0.05):
            f.material_index = Bo
    # the locking lug / cam under the chamber (seen when the slide is back)
    gk.rbox(bm, mm(14.0, 0, -9.3), mm(9.0, 8.0, 5.0), mm(0.5), 1, mi=St)
    return br


# --------------------------------------------------------------------------------------
# trigger, slide stop, mag release
# --------------------------------------------------------------------------------------

def build_trigger(gun):
    tg = gun.part('Trigger', paint='Polymer', origin=mm(3.5, 0, -31.0), fit=3)
    P = tg.mi('Polymer')
    shoe = [(4.8, -30.0), (6.3, -36.0), (9.3, -41.0), (13.3, -45.5), (17.3, -48.8), (19.4, -50.3), (19.1, -51.7),
            (17.6, -52.1), (15.3, -50.9), (11.4, -47.6), (7.6, -43.7), (4.0, -39.1), (1.4, -34.7), (0.4, -30.0)]
    gk.profile(tg.bm, mm(gk.fillet2(shoe, 0.7, 1)), mm(6.4), bevel=mm(1.3), bevel_segs=0, mi=P)
    blade = [(7.0, -35.6), (10.3, -40.9), (14.4, -45.4), (18.5, -48.7), (17.8, -49.9), (13.8, -47.0), (9.8, -43.0),
             (6.2, -38.0)]
    gk.prism(tg.bm, mm(blade), mm(-1.15), mm(1.15), mi=P)
    return tg


def build_slide_stop(gun):
    ss = gun.part('SlideStop', paint='SteelBlued', origin=mm(-23.0, 13.4, -15.0))
    St = ss.mi('SteelBlued')
    out = [(-25.2, -13.2), (-8.6, -12.2), (-7.8, -13.4), (-8.6, -15.4), (-17.0, -16.4), (-25.2, -17.0)]
    gk.prism(ss.bm, mm(gk.fillet2(out, 0.9, 1)), mm(12.7), mm(13.7), mi=St)
    gk.rbox(ss.bm, mm(-14.6, 14.1, -13.1), mm(8.0, 1.0, 2.2), mm(0.35), 1, mi=St)      # thumb ledge
    for k in range(3):
        gk.box(ss.bm, mm(-17.4 + k * 2.6, 14.62, -13.1), mm(0.6, 0.25, 2.0), mi=St)
    gk.pin(ss.bm, mm(-23.0, 13.7, -15.0), (0, 1, 0), mm(1.3), proud=mm(0.25), segs=8, mi=St)
    return ss


def build_mag_release(gun):
    mr = gun.part('MagRelease', paint='Polymer', origin=mm(-12.6, 14.6, -46.8))
    P = mr.mi('Polymer')
    out = [(-9.3, -42.6), (-15.9, -42.6), (-15.9, -51.0), (-9.3, -51.0)]
    gk.profile(mr.bm, mm(gk.fillet2(out, 1.1, 1)), mm(2.6), y=mm(14.6), bevel=mm(0.5), bevel_segs=0, mi=P)
    for k in range(4):
        gk.box(mr.bm, mm(-12.6, 15.95, -44.2 - k * 1.75), mm(5.0, 0.35, 0.55), mi=P)
    return mr


# --------------------------------------------------------------------------------------
# magazine (+ top round, follower), loose round, spent case
# --------------------------------------------------------------------------------------

def build_magazine(gun):
    org = (MAGWELL[0], 0, MAGWELL[1])
    mg = gun.part('Magazine', paint='Polymer', origin=mm(*org), fit=4)
    P, St, Br = mg.mi('Polymer'), mg.mi('SteelBlued'), mg.mi('Brass')
    bm = mg.bm
    gk.box_mag(bm, mm(*org), MAG_AX, mm(MAG_LEN), mm(MAG_DEPTH), mm(MAG_W),
               {'body': P, 'base': P, 'lips': St}, top_width=mm(19.6), rib=False, lips=mm(9.0), base=False,
               body_len=mm(98.0))
    # wedge-shaped floorplate (measured on the reference: nearly horizontal bottom, front finger lip)
    plate = [(-30.6, -105.0), (-29.8, -109.8), (-31.0, -111.5), (-71.0, -114.5), (-72.2, -113.0), (-71.6, -106.4),
             (-69.8, -105.0)]
    gk.profile(bm, mm(gk.fillet2(plate, 1.0, 1)), mm(MAG_W + 2.6), bevel=mm(0.9), bevel_segs=1, mi=P)
    for k in range(3):                                                   # grip ribs on the lip
        gk.box(bm, mm(-30.0 - k * 0.0, 0, -107.0 - k * 1.3), mm(0.8, MAG_W, 0.5), mi=P)
    cuts = []
    # catch notch (front face, near the top) and the witness holes on the back (rounds show brass)
    X_ = V((MAG_FR[0], 0, MAG_FR[1]))
    Z_ = V((-MAG_AX[0], 0, -MAG_AX[1]))
    R = gk.basis(X_, Z_.cross(X_), Z_)
    p = mag_pt(31.0, MAG_DEPTH / 2)
    c = bmesh.new()
    gk.box(c, mm(p[0], 0, p[1]), mm(3.2, 9.0, 4.0), R=R, mi=St)
    cuts.append(c)
    holes = []
    for k, s in enumerate((40.0, 55.0, 70.0, 85.0)):
        q_ = mag_pt(s, -MAG_DEPTH / 2)
        holes.append(mm(q_[0], 0, q_[1]))
    cuts.append(gk.hole_cutter(holes, V((MAG_FR[0], 0, MAG_FR[1])), mm(1.6), mm(1.2), segs=8, mi=Br))
    gk.boolean_bm(bm, cuts)
    # top round, lying in the lips, offset to one side (double stack)
    rt = gun.part('MagRoundTop', paint='Brass', parent='Magazine', origin=mm(-18.9, 2.0, -17.6))
    mats = {'case': rt.mi('Brass'), 'primer': rt.mi('Nickel'), 'bullet': rt.mi('Copper')}
    M = gk.frame_x(V(mm(-33.6, 2.0, -18.6)), V((math.cos(math.radians(3.5)), 0, math.sin(math.radians(3.5)))))
    gk.build_round(rt.bm, '9x19', mats, M, segs=8)
    # follower (only seen in the empty-magazine model; parked under the stack here)
    fo = gun.part('MagFollower', paint='Polymer', parent='Magazine', origin=mm(*org))
    Pf = fo.mi('Polymer')
    q_ = mag_pt(95.0, 1.0)
    gk.rbox(fo.bm, mm(q_[0], 0, q_[1]), mm(MAG_DEPTH - 3.0, MAG_W - 3.5, 6.0), mm(0.8), 1,
            R=gk.basis(X_, Z_.cross(X_), Z_), mi=Pf)
    return mg, rt, fo


def build_case_round(col):
    """The separate small models: spent case and loose round (origins at their centre of mass)."""
    out = {}
    for name, fn in (('Pistol_Case', 'case'), ('Pistol_Round', 'round')):
        bm = bmesh.new()
        if fn == 'case':
            mats = ['Brass', 'Nickel']
            gk.build_case(bm, '9x19', {'case': 0, 'primer': 1}, segs=10, spent=True)
        else:
            mats = ['Brass', 'Nickel', 'Copper']
            gk.build_round(bm, '9x19', {'case': 0, 'primer': 1, 'bullet': 2}, segs=8)
        com = gk.bm_volume_com(bm)
        out[name] = gk.single_object(col, name, bm, mats, origin=com)
    return out


# --------------------------------------------------------------------------------------
# the model
# --------------------------------------------------------------------------------------

def build_model():
    gun = gk.GunModel(GID, mass=0.85)
    build_frame(gun)
    build_slide(gun)
    build_sights(gun)
    build_extractor(gun)
    build_barrel(gun)
    build_trigger(gun)
    build_slide_stop(gun)
    build_mag_release(gun)
    build_pins(gun)
    build_magazine(gun)
    # hinges (ARCHITECTURE §5.2)
    gun.hinge('Slide', 'slide', (-1, 0, 0), mm(STROKE), pivot=(0, 0, 0), lockBackOnEmpty=True)
    gun.hinge('Barrel', 'rotate', (0, 1, 0), 0.0, mn=-2.5, note='breech drops as the slide unlocks')
    gun.hinge('Trigger', 'rotate', (0, 1, 0), 10.0)
    gun.hinge('SlideStop', 'rotate', (0, 1, 0), 0.0, mn=-6.0, note='front end up = slide locked')
    gun.hinge('MagRelease', 'slide', (0, -1, 0), mm(3.0))
    gun.hinge('Magazine', 'detach', (MAG_AX[0], 0, MAG_AX[1]), mm(MAG_LEN), note='drops along MagWell +X')
    # markers (ARCHITECTURE §5.3)
    gun.marker('Muzzle', mm(MUZZLE_X, 0, 0))
    ej = V((-math.sin(math.radians(20)) * math.cos(math.radians(35)), -math.cos(math.radians(20)) * math.cos(math.radians(35)),
            math.sin(math.radians(35))))
    gun.marker('EjectionPort', mm(8.5, -6.0, 8.0), ej, (0, -0.6, 0.8))
    gun.marker('CasingSpawn', mm(8.5, -15.0, 9.0), (0.96, -0.22, 0.18), (0, 0, 1))
    gun.marker('MagWell', mm(MAGWELL[0], 0, MAGWELL[1]), (MAG_AX[0], 0, MAG_AX[1]), (MAG_FR[0], 0, MAG_FR[1]))
    # the R6 grips (GripR: centre of the grip at the web / finger height; +Z hand -> elbow (forearm
    # continuing the bore line back and a bit down, slightly from the right as in an isosceles grip),
    # +X = completes the frame toward the bore (pistol: the forearm is roughly parallel to the bore)
    zr = V((-0.94, -0.20, -0.27)).normalized()
    xr = (V((0, 0, 1)) - zr * zr.z).normalized()
    # design lever (solve_holds iteration 2): R6 arms converge ~45 deg on a centred pistol, so the neutral
    # wrist is yawed 22 deg further about the marker's own X (all four stances then sit inside +-25 deg)
    Rw = Matrix.Rotation(math.radians(22.0), 3, xr)
    zr = (Rw @ zr).normalized()
    gun.marker('GripR', mm(-36.0, 0, -46.0), xr, zr)
    zl = V((-0.70, 0.62, -0.36)).normalized()
    gun.marker('GripL', mm(-38.0, 17.0, -54.0), (V((0, 0, 1)) - zl * zl.z).normalized(), zl)
    # sight line: rear notch top -> front blade top, eye at arm's length behind
    rear = V(mm((REAR_SIGHT[0]), 0, REAR_TOP))
    front = V(mm(FRONT_SIGHT[0], 0, FRONT_TOP))
    d = (front - rear).normalized()
    gun.marker('SightEye', rear - d * 0.30, d, (0, 0, 1))
    gun.marker('CoM', mm(-16.0, 0, -30.0))
    gun.marker('HolsterMount', mm(20.0, 0, -20.0))
    mgp = mag_pt(MAG_LEN - 4.0)
    gun.marker('MagGrab', mm(mgp[0], 0, mgp[1]), (MAG_AX[0], 0, MAG_AX[1]), (0.3, 0.3, -0.9))
    gun.marker('SlideGrip', mm(-46.0, 0, 3.0), (1, 0, 0), (-0.2, 0.6, 0.77))
    gun.marker('MagRelease', mm(-12.6, 16.1, -46.8), (0, -1, 0), (0, 0, 1))
    gun.marker('SlideStop', mm(-14.6, 14.7, -13.1), (0, 0, -1), (0, 1, 0))
    gun.separate = {'Case': 'Pistol_Case.fbx', 'Round': 'Pistol_Round.fbx', 'Mag': 'Pistol_Mag.fbx',
                    'MagEmpty': 'Pistol_MagEmpty.fbx'}
    gun.colliders = {'Magazine': {'size': [round(mm(MAG_LEN), 4), round(mm(MAG_W + 1), 4), round(mm(MAG_DEPTH + 5), 4)],
                                  'axes': 'magazine local: +X down the mag (extraction), +Y left, +Z its front',
                                  'massKg': 0.25, 'massEmptyKg': 0.07}}
    return gun


def gun_samples(gun):
    """Model-space points used by the hold solver's penetration tests (outline of the gun)."""
    pts = []
    for x in (-68, -40, -10, 20, 50, 80, 100):
        for z in (-11, 9):
            for y in (-12, 12):
                pts.append(mm(x, y, z))
    for s in (0, 30, 60, 95):
        p = mag_pt(s)
        for d in (-20, 15):
            q_ = mag_pt(s, d)
            pts.append(mm(q_[0], 0, q_[1]))
    pts += [mm(45, 0, -57), mm(0, 0, -57)]
    return pts


# --------------------------------------------------------------------------------------
# stances (pistol, ARCHITECTURE §7.3): the solver finds blade, lean, neck, shoulders, wrist
# --------------------------------------------------------------------------------------
STANCES = [
    dict(name='Aim', pitch=0.0, eye='line', w_left=16.0, eye_t=(-0.7, 0.9), blade=-10.0, blade_tol=15.0, lean=-12.0,
         lean_tol=12.0, wrist_limit=25.0, rs_ref=(95, 0, 40), ls_ref=(95, 0, -40), front=14.0),
    dict(name='Ready', pitch=-12.0, place=(mm(-36, 0, -46), (0.12, 0.45, -1.15), 4.0), eye='over', eye_over=0.55, blade=-10.0, blade_tol=15.0, lean=-8.0,
         head_pitch=-6.0, wrist_limit=25.0, rs_ref=(70, 0, 40), ls_ref=(70, 0, -40), front=12.0),
    dict(name='LowReady', pitch=-45.0, place=(mm(-36, 0, -46), (0.12, -0.45, -1.0), 8.0), blade=-8.0, blade_tol=15.0, lean=-6.0, head_pitch=-12.0,
         wrist_limit=25.0, rs_ref=(35, 0, 30), ls_ref=(35, 0, -30), front=10.0),
    dict(name='ReloadInsert', pitch=28.0, yaw=8.0, cant=-35.0, w_cant=2.0, blade=-12.0, lean=-10.0,
         look='gun', wrist_limit=35.0, rs_ref=(40, 0, 50), ls_ref=(30, 0, -20), front=12.0,
         left=None, left_mag=True),
]


def solve_holds(gun, out_json):
    import numpy as np
    solver = gk.HoldSolver(gun, gun_samples(gun))
    results = []
    for st in STANCES:
        st = dict(st)
        if st.pop('left_mag', False):
            # support hand on the magazine baseplate, the mag two-thirds of the way in
            s = MAG_LEN + 10.0
            p = mag_pt(s, 0.0)
            st['left'] = mm(p[0], 0.0, p[1])
            st['left_z'] = (MAG_AX[0] * 0.7, 0.55, MAG_AX[1] * 0.7)
            st['left_limit'] = 50.0
        r = solver.solve(st, starts=18)
        print('HOLD %-12s cost %.4f residuals %s pose %s wrist %s' % (r['name'], r['cost'], r['residuals'],
                                                                       r['pose'], r['wrist']), flush=True)
        results.append(r)
    gk.holds_to_json(out_json, GID, results, extra={
        'note': 'Solved by tools/guns/pistol.py (gunkit.HoldSolver). R6: rigid arms, hand point (0,-0.92,0) in '
                'arm space; the weld is the only wrist. ReloadInsert: left hand on the baseplate of a magazine '
                '10 mm short of seated (MagWell +X).',
        'markers': {k: gun.markers[k][0][:] and [round(c, 5) for c in gun.markers[k][0]]
                    for k in ('GripR', 'GripL', 'SightEye')}})
    return results, solver


# --------------------------------------------------------------------------------------
# renders
# --------------------------------------------------------------------------------------

class Scene:
    def __init__(self, args):
        self.args = args
        self.col = bpy.data.collections.new('Pistol')
        bpy.context.scene.collection.children.link(self.col)
        self.studio = bpy.data.collections.new('Studio')
        bpy.context.scene.collection.children.link(self.studio)


def set_pose(objs, slide=0.0, trigger=0.0, stop=0.0, mag=0.0, barrel=0.0, release=0.0):
    """Moving parts away from rest (slide metres back, trigger deg, slide stop deg (negative up), magazine
    metres out along MagWell +X)."""
    o = objs
    o['Slide'].location = V(mm(0, 0, 0)) + V((-slide, 0, 0))
    o['Trigger'].rotation_euler = (0, math.radians(trigger), 0)
    o['SlideStop'].rotation_euler = (0, math.radians(stop), 0)
    o['Barrel'].rotation_euler = (0, math.radians(barrel), 0)
    mo = V(mm(MAGWELL[0], 0, MAGWELL[1]))
    o['Magazine'].location = mo + V((MAG_AX[0], 0, MAG_AX[1])) * mag
    o['MagRelease'].location = V(mm(-12.6, 14.6, -46.8)) + V((0, -release, 0))
    bpy.context.view_layer.update()


REF_DEFAULT = '/tmp/claude-0/-home-user-realistic-battleground/e6e0272e-0bb1-5036-b293-d501c4bfb630/scratchpad/guns/refs/pistol.png'


def render_all(args, gun, objs, root, ammo, empties, paths, holds, solver, info, want):
    """The review set: side ortho (reference framing), 3/4 front and back, top, right (port side), action
    close-up, exploded, cycle pose (slide locked, mag dropping, trigger pressed), ammo and magazines, game
    look (baked maps), game mesh, reference comparison, the R6 holds; then the contact sheets."""
    from PIL import Image
    out = args.out
    studio = bpy.data.collections['Studio']
    rig = gk.Rig(studio)
    sc = bpy.context.scene
    gun_names = [n for n in gun.order if n != 'MagFollower']
    gobjs = [objs[n] for n in gun_names]
    objs['MagFollower'].hide_render = True
    for e in empties.values():
        e.hide_render = True
    for a in ammo.values():
        a.hide_render = True
    lo, hi = gk.world_bbox(gobjs)
    floor = gk.add_floor(studio, lo.z - 0.0005)
    files = []

    def shot(name, view, res=(1400, 900), **kw):
        gk.set_res(*res)
        rig.frame((lo, hi), view, **kw)
        p = os.path.join(out, name + '.png')
        gk.render(p)
        files.append(p)
        return p

    tri_line = 'gun FBX %d tris (+ mag %d), %d parts; L %.1f mm, H %.1f mm, W %.1f mm' % (
        info['tri_gun'] - info['tri_mag'], info['tri_mag'], len(gun_names), info['dims']['length'] * 1000,
        info['dims']['height'] * 1000, info['dims']['width'] * 1000)
    # 01 side ortho, reference framing (left side, muzzle left), transparent for the comparison
    if want('01') or want('12'):
        floor.hide_render = True
        sc.render.film_transparent = True
        gk.set_res(1400, 1000)
        rig.frame((lo, hi), (0, 1, 0), ortho=True, margin=1.06)
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
            pc, iou = gk.ref_compare(ref, p1, pa, os.path.join(out, '12_reference_compare.png'),
                                     title='9MM COMPACT side profile')
            files.append(pc)
        gk.caption(p1, ['9MM COMPACT - left side, orthographic (reference framing)', tri_line], color=(30, 30, 30))
        files.append(p1)
    if want('02'):
        p = shot('02_three_quarter_front', (0.9, 0.75, 0.42), lens=60)
    if want('03'):
        p = shot('03_three_quarter_back', (-0.85, -0.85, 0.5), lens=60)
    if want('04'):
        p = shot('04_top', (0, 0, 1), ortho=True, up=(0, 1, 0), margin=1.08)
    if want('05'):
        p = shot('05_right_side_port', (0, -1, 0), ortho=True, margin=1.06)
    if want('06'):
        gk.set_res(1400, 900)
        slo, shi = V(mm(-70, -14, -40)), V(mm(30, 14, 15))
        rig.frame((slo, shi), (-0.55, -0.85, 0.55), lens=85, margin=1.0)
        p = os.path.join(out, '06_closeup_action.png')
        gk.render(p)
        files.append(p)
    if want('08'):
        set_pose(objs, slide=mm(STROKE), trigger=10.0, stop=-6.0, mag=0.045, barrel=-2.5, release=mm(3.0))
        lo2, hi2 = gk.world_bbox(gobjs)
        gk.set_res(1400, 900)
        rig.frame((lo2, hi2), (0.55, -0.9, 0.25), lens=60)
        p = os.path.join(out, '08_slide_locked_mag_out.png')
        gk.render(p)
        gk.caption(p, ['slide locked back 28 mm (SlideStop -6 deg), barrel tilted -2.5 deg, trigger +10 deg,',
                       'mag release pressed 3 mm, magazine dropping along MagWell +X'])
        files.append(p)
        set_pose(objs)
    if want('07'):
        offs = {'Slide': V((0, 0, 0.055)), 'SightRear': V((0, 0, 0.014)), 'SightFront': V((0, 0, 0.014)),
                'Extractor': V((0, 0, 0.026)), 'Barrel': V((0.0, 0, 0.026)), 'Trigger': V((0.012, 0, -0.045)),
                'SlideStop': V((0, 0.035, 0.012)), 'MagRelease': V((0, 0.035, -0.006)), 'Pins': V((0, 0.06, 0)),
                'Magazine': V((MAG_AX[0], 0, MAG_AX[1])) * 0.075, 'MagRoundTop': V((-MAG_AX[0], 0, -MAG_AX[1])) * 0.022}
        base = {n: objs[n].location.copy() for n in offs}
        for n, d in offs.items():
            objs[n].location = base[n] + d
        bpy.context.view_layer.update()
        lo2, hi2 = gk.world_bbox(gobjs)
        gk.set_res(1500, 1100)
        rig.frame((lo2, hi2), (0.3, 1, 0.35), lens=55, margin=1.12)
        p = os.path.join(out, '07_exploded.png')
        gk.render(p)
        items = []
        for n, (dx, dy) in (('Slide', (0, -60)), ('SightRear', (-40, -50)), ('SightFront', (30, -50)),
                            ('Extractor', (-90, -40)), ('Barrel', (90, -30)), ('Frame', (-160, 60)),
                            ('Trigger', (60, 50)), ('SlideStop', (80, -40)), ('MagRelease', (-120, 20)),
                            ('Pins', (90, 30)), ('Magazine', (110, 40)), ('MagRoundTop', (110, -10))):
            ob = objs[n]
            blo, bhi = gk.world_bbox([ob])
            items.append((n, (blo + bhi) / 2, (dx, dy)))
        gk.label_points(p, items, size=19)
        gk.caption(p, ['exploded: named parts of the FBX (moving: Slide, Barrel, Trigger, SlideStop, MagRelease, Magazine)'])
        files.append(p)
        for n in offs:
            objs[n].location = base[n]
        bpy.context.view_layer.update()
    if want('09'):
        for ob in gobjs:
            ob.hide_render = True
        # a full magazine standing, an empty one (follower up), a round and a spent case lying on the floor
        mag = objs['Magazine']
        keep = mag.matrix_world.copy()
        mag.hide_render = False
        objs['MagRoundTop'].hide_render = False
        mag.parent = None
        mag.matrix_world = Matrix.Translation(V((-0.03, 0, 0.0))) @ Matrix.Rotation(-GRIP_ANG, 4, 'Y')
        bpy.context.view_layer.update()
        mlo, mhi = gk.world_bbox([mag])
        mag.location.z -= (mlo.z - floor.location.z)
        # empty copy
        me2 = mag.data.copy()
        empty = bpy.data.objects.new('MagEmptyPreview', me2)
        studio.objects.link(empty)
        empty.matrix_world = Matrix.Translation(V((0.045, 0.0, 0))) @ mag.matrix_world
        fo = objs['MagFollower']
        fo_keep = (fo.parent, fo.matrix_world.copy())
        fo.parent = None
        fo.hide_render = False
        fo.matrix_world = empty.matrix_world @ Matrix.Translation(V((MAG_AX[0], 0, MAG_AX[1])) * -0.084 +
                                                                V((0, 0, 0)))
        rd, cs = ammo['Pistol_Round'], ammo['Pistol_Case']
        rd.hide_render = cs.hide_render = False
        rd.matrix_world = Matrix.Translation(V((0.11, 0.025, floor.location.z + 0.00498))) @ Matrix.Rotation(0.3, 4, 'Z')
        cs.matrix_world = Matrix.Translation(V((0.115, -0.012, floor.location.z + 0.00498))) @ Matrix.Rotation(-0.5, 4, 'Z')
        bpy.context.view_layer.update()
        alo, ahi = gk.world_bbox([mag, empty, rd, cs])
        gk.set_res(1400, 900)
        rig.frame((alo, ahi), (0.55, 0.9, 0.55), lens=60, margin=1.08)
        p = os.path.join(out, '09_ammo_and_magazines.png')
        gk.render(p)
        gk.caption(p, ['15-round magazine (full: top round in the lips; empty: follower up), 9x19 round (%d tris), '
                       'spent case (%d tris)' % (info['tri_ammo']['Pistol_Round'], info['tri_ammo']['Pistol_Case']),
                       'mag + top round %d tris; witness holes show brass' % info['tri_mag']])
        files.append(p)
        bpy.data.objects.remove(empty)
        fo.matrix_world = fo_keep[1]
        fo.parent = fo_keep[0]
        fo.matrix_world = fo_keep[1]
        fo.hide_render = True
        mag.parent = root
        mag.matrix_world = keep
        rd.hide_render = cs.hide_render = True
        for ob in gobjs:
            ob.hide_render = False
        bpy.context.view_layer.update()
    if want('10') and paths:
        bm_ = gk.baked_material('BakedPistol', paths)
        saved = gk.swap_materials(gobjs, bm_)
        p = shot('10_game_look_baked', (0.9, 0.75, 0.42), lens=60)
        gk.caption(p, ['GAME LOOK: the baked 1024 atlas only (Color / Normal / Roughness / Metalness), as a '
                       'SurfaceAppearance'])
        gk.restore_materials(saved)
    if want('11'):
        saved = gk.swap_materials(gobjs, gk.MAT['FlatGrey'])
        p = shot('11_game_mesh', (0.9, 0.75, 0.42), lens=60)
        gk.caption(p, ['game mesh (flat grey): ' + tri_line])
        gk.restore_materials(saved)
    # the R6 holds
    hold_files = []
    if holds and want('13'):
        floor.hide_render = True
        for r in holds:
            hold_files.append(render_hold(args, rig, gun, objs, root, gobjs, r, solver))
        floor.hide_render = False
        files += hold_files
    keyf = sorted(f for f in files if os.path.basename(f)[:2].isdigit())
    if keyf:
        sheet = gk.contact_sheet(keyf, os.path.join(out, 'pistol_sheet.png'), '9MM COMPACT (tools/guns/pistol.py) - '
                                 + tri_line, cols=3)
        if not args.no_export:
            import shutil
            shutil.copy(sheet, os.path.join(args.assets, 'pistol_sheet.png'))
            if hold_files:
                hs = gk.grid(hold_files, os.path.join(args.assets, 'pistol_holds.png'), cols=2, tw=1100, th=820,
                             title='9MM COMPACT - solved R6 holds (front 3/4, side, hands, eye)')


def render_hold(args, rig, gun, objs, root, gobjs, r, solver):
    """One stance on the R6 dummy: front 3/4, right side, top and the eye's view, in a 2x2 grid."""
    import numpy as np
    e = r['_eval']
    studio = bpy.data.collections['Studio']
    dummy = gk.build_r6(studio, e['F'], name='R6_' + r['name'])
    if r['name'] == 'ReloadInsert':
        set_pose(objs, slide=mm(STROKE), stop=-6.0, mag=mm(10.0), barrel=-2.5)
    gk.place_gun(root, e['G'])
    floor = gk.add_floor(studio, -3 * gk.STUD - 0.001, 'Ground')
    lo, hi = gk.world_bbox(dummy + gobjs)
    names = []
    res = r['residuals']
    head = [o for o in dummy if o.name.endswith('Head')][0]
    arms = [o for o in dummy if 'Arm' in o.name]
    hands = gobjs + arms
    for tag, view, kw in (('front', (1.0, -0.75, 0.35), dict(lens=50)), ('side', (0.0, -1.0, 0.08), dict(lens=50)),
                          ('close', (1.0, -0.55, 0.25), dict(lens=60)), ('eye', None, {})):
        gk.set_res(1100, 820)
        bpy.context.scene.cycles.samples = 24 if not args.quick else 8
        if view is None:
            # the eye's view along the gun's sight line (head hidden)
            head.hide_render = True
            for o in arms:
                o.hide_render = True
            eye_b = gk.r2b_point(e['eye'])
            if 'sight_d' in e:
                d = e['sight_d']
                tgt = gk.r2b_point(e['eye'] + d * 4.0)
            else:
                tgt = gk.r2b_point(e['eye'] + np.array([0, 0, -4.0]))
            rig.cam.data.type = 'PERSP'
            rig.cam.data.lens = 28
            rig.cam.data.clip_start = 0.01
            rig.aim(rig.cam, eye_b, tgt)
            rig.place_lights((lo + hi) / 2, 2.5)
        elif tag == 'close':
            G = e['G']
            c = gk.r2b_point((G @ np.append(gk.model_to_gun(mm(20, 0, -30)), 1.0))[:3])
            rig.frame((c - V((0.17, 0.17, 0.13)), c + V((0.17, 0.17, 0.13))), view, margin=1.0, **kw)
        else:
            head.hide_render = False
            rig.frame((lo, hi), view, margin=1.08, **kw)
        p = os.path.join(args.out, '_hold_%s_%s.png' % (r['name'], tag))
        gk.render(p)
        names.append(p)
 
    head.hide_render = False
    for o in arms:
        o.hide_render = False
    txt = '%s: blade %.0f, lean %.0f, wrist %.0f deg; left hand %.3f stud%s; bore yaw/pitch %s' % (
        r['name'], r['pose']['Root'][1], r['pose']['Root'][0], res['wristDeg'], res.get('left', float('nan')),
        ('; eye to sight line %.3f stud' % res['eyeToSightLine']) if 'eyeToSightLine' in res and r['name'] == 'Aim'
        else '', res['boreYawPitch'])
    out = gk.grid(names, os.path.join(args.out, '13_hold_%s.png' % r['name']), cols=2, tw=1100, th=820,
                  labels=['front 3/4', 'right side', 'hands close-up', 'eye view (head and arms hidden, as an ADS camera)'],
                  title=txt)
    for o in dummy:
        bpy.data.objects.remove(o)
    bpy.data.objects.remove(floor)
    root.matrix_world = Matrix()
    set_pose(objs)
    bpy.context.view_layer.update()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='/tmp/pistol_out')
    ap.add_argument('--assets', default=os.path.join(ROOT, 'assets', 'guns', 'Pistol'))
    ap.add_argument('--samples', type=int, default=48)
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
    samples = 16 if args.quick else args.samples
    gk.setup_render(samples, (1600, 1000))
    sc = Scene(args)
    gun = build_model()
    objs = gun.build(sc.col)
    root = bpy.data.objects.new('GunRoot', None)
    sc.col.objects.link(root)
    for n, ob in objs.items():
        if ob.parent is None:
            ob.parent = root
    empties = gun.empties(sc.studio)
    ammo = build_case_round(sc.col)
    tris = gk.tri_counts(objs)
    gun_parts = [n for n in gun.order if n != 'MagFollower']
    tri_gun = sum(tris[n] for n in gun_parts)
    tri_mag = tris['Magazine'] + tris['MagRoundTop']
    tri_ammo = gk.tri_counts(ammo)
    print('TRIS', tris, 'gun FBX total', tri_gun, 'mag', tri_mag, 'ammo', tri_ammo, flush=True)

    # dims check (rest, mag seated)
    lo, hi = gk.world_bbox([objs[n] for n in gun_parts])
    dims = {'length': round(hi.x - lo.x, 4), 'barrel': round(mm(MUZZLE_X), 4), 'height': round(hi.z - lo.z, 4),
            'width': round(hi.y - lo.y, 4), 'slideStroke': mm(STROKE)}
    gun.dims = dims
    print('DIMS', dims, flush=True)

    # UV atlas + bake + export
    atlas_objs = [objs[n] for n in gun.order]
    gk.uv_atlas(atlas_objs, margin=0.004)
    gk.uv_atlas(list(ammo.values()), margin=0.01)
    paths = None
    if not args.no_bake:
        paths = gk.bake_atlas(atlas_objs, args.assets, GID, size=1024, samples=12)
        gk.bake_atlas(list(ammo.values()), args.assets, GID + '_Ammo', size=256, samples=12)
    if not args.no_export:
        gk.export_fbx([objs[n] for n in gun_parts], os.path.join(args.assets, GID + '.fbx'))
        gk.export_fbx([ammo['Pistol_Case']], os.path.join(args.assets, 'Pistol_Case.fbx'))
        gk.export_fbx([ammo['Pistol_Round']], os.path.join(args.assets, 'Pistol_Round.fbx'))
        # separate magazine models at their own origin (the MagWell point): parent cleared temporarily
        mag = objs['Magazine']
        saved = mag.matrix_world.copy()
        par = mag.parent
        mag.parent = None
        mag.matrix_world = Matrix()
        gk.export_fbx([mag, objs['MagRoundTop']], os.path.join(args.assets, 'Pistol_Mag.fbx'))
        # empty: follower up at the lips
        fo = objs['MagFollower']
        fo.location = V(mm(MAG_AX[0] * -84.0, 0, MAG_AX[1] * -84.0))
        bpy.context.view_layer.update()
        gk.export_fbx([mag, fo], os.path.join(args.assets, 'Pistol_MagEmpty.fbx'))
        fo.location = V((0, 0, 0))
        mag.parent = par
        mag.matrix_world = saved
        bpy.context.view_layer.update()
        gun.to_json(os.path.join(args.assets, 'pistol.markers.json'),
                    tris={**{n: tris[n] for n in gun.order}, 'gunFbx': tri_gun, 'magFbx': tri_mag,
                          'case': tri_ammo['Pistol_Case'], 'round': tri_ammo['Pistol_Round']})
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(args.out, 'pistol.blend'))

    holds, solver = None, None
    if not args.no_holds:
        holds, solver = solve_holds(gun, os.path.join(HERE, 'pistol_holds.json'))

    if args.no_render:
        return
    render_all(args, gun, objs, root, ammo, empties, paths, holds, solver,
               dict(tris=tris, tri_gun=tri_gun, tri_mag=tri_mag, tri_ammo=tri_ammo, dims=dims), want)


if __name__ == '__main__':
    main()
