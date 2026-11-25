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
# barrel tilt pivot (review 2 §2.7): a Browning-tilt barrel stays captured in the slide nose, so its effective
# pivot is FORWARD, under the nose bushing at the slide's locked-back position (nose 99.5 - 28 = 71.5 mm; hole
# 62-73 mm): the breech then drops 2.9 mm at -2.5 deg and the barrel stays centred in the nose (0.26 mm max)
BARREL_PIVOT = (67.0, 0.0, 0.0)
SIGHT_EYE_M = 0.55                # SightEye: arm's length behind the rear sight (§5.3)
STAMP_X1, STAMP_W, STAMP_ZC, STAMP_H = 66.0, 64.0, -1.2, 3.7   # generic stamp on the left slide flat (mm)


def mag_pt(s, d=0.0):
    """Point (x, z) mm at distance s down the magazine axis and d toward its front."""
    return (MAGWELL[0] + MAG_AX[0] * s + MAG_FR[0] * d, MAGWELL[1] + MAG_AX[1] * s + MAG_FR[1] * d)


# --------------------------------------------------------------------------------------
# materials beyond the kit
# --------------------------------------------------------------------------------------

def stamp_image(path):
    """The generic stamp, white on black: a serial-like code and the calibre (no logo, no maker)."""
    from PIL import Image, ImageDraw
    W, H = 1560, 92
    im = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(im)
    f = gk.font(78, bold=True)
    d.text((30, 4), 'RB-04127', fill=255, font=f)
    d.text((1180, 4), '9x19', fill=255, font=f)
    im.save(path)
    return path


def mat_stamp(name='Stamp', img_dir='.'):
    """The slide's blued steel (the kit's SteelBlued, same nodes) with the engraved stamp added: the text
    a little lighter (fresh cut steel under the finish) and bumped in.  Mapped by object coordinates."""
    m = gk.mat_steel(name, holster=0.35)
    nb = gk.NB.__new__(gk.NB)
    nb.m, nb.nt = m, m.node_tree
    nb.tc = [n for n in nb.nt.nodes if n.type == 'TEX_COORD'][0]
    p = [n for n in nb.nt.nodes if n.type == 'BSDF_PRINCIPLED'][0]
    nb.principled = p
    img = bpy.data.images.load(stamp_image(os.path.join(img_dir, 'pistol_stamp.png')))
    img.colorspace_settings.name = 'Non-Color'
    sep = nb.n('ShaderNodeSeparateXYZ')
    nb.l(nb.obj(), sep.inputs[0])
    u = nb.math('MULTIPLY', nb.math('SUBTRACT', mm(STAMP_X1), sep.outputs[0], clamp=False), 1.0 / mm(STAMP_W),
                clamp=False)
    v = nb.math('MULTIPLY', nb.math('SUBTRACT', sep.outputs[2], mm(STAMP_ZC - STAMP_H / 2), clamp=False),
                1.0 / mm(STAMP_H), clamp=False)
    cmb = nb.n('ShaderNodeCombineXYZ')
    nb.l(u, cmb.inputs[0])
    nb.l(v, cmb.inputs[1])
    tex = nb.n('ShaderNodeTexImage', extension='CLIP', interpolation='Cubic')
    tex.image = img
    nb.l(cmb.outputs[0], tex.inputs['Vector'])
    txt = tex.outputs['Color']
    base_src = p.inputs['Base Color'].links[0].from_socket
    nrm_src = p.inputs['Normal'].links[0].from_socket
    nb.l(nb.mixc(nb.mul(txt, 0.5), base_src, gk.C(0.11, 0.11, 0.115)), p.inputs['Base Color'])
    nb.l(nb.bump(nb.mul(txt, -1.0), 0.6, 0.00025, normal=nrm_src), p.inputs['Normal'])
    return m


def build_pistol_materials(img_dir):
    """The kit's library, then the pistol's own: the frame polymer WITHOUT the kit's bright scuff streaks
    (review 2 §2.10: polymer does not take bright metal scratches; edge polish and dust only), and the
    slide's Stamp."""
    gk.build_materials()
    gk.mat_polymer('Polymer', wear=0.25)
    gk.mat_polymer('PolymerStipple', stipple=True, wear=0.25)
    mat_stamp('Stamp', img_dir)


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
# backstrap x(z): palm swell, beavertail undercut (measured on the reference; review 2: the mid backstrap pulled
# forward 1-1.5 mm, the overlay's cyan band; the heel corner itself matches the photo and stays)
BACK = [(-58.6, -29.0), (-58.6, -34.5), (-60.4, -38.5), (-63.0, -44.0), (-65.0, -48.5), (-68.2, -58.0),
        (-71.4, -69.0), (-74.8, -80.0), (-78.4, -92.0), (-81.0, -100.0), (-82.2, -103.8), (-81.6, -105.2)]
STRAP_L = 55.0
HUMPS = (19.5, 37.5)               # finger humps, distance s down the front strap from z -53 (mm)
VALLEYS = (10.0, 28.5, 46.5)       # the valleys between them (horizontal ribs there, as the reference)


def front_x(z):
    """Grip front x at height z (mm): the guard junction, then the front strap with two finger humps
    (finger grooves of the reference) along the 20.5 deg grip line, drawn back a touch toward the bottom."""
    if z >= -53.0:
        return _interp(GRIP_FRONT, z)
    s = (-53.0 - z) / math.cos(GRIP_ANG)
    off = sum(2.8 * math.exp(-((s - h) / 4.4) ** 2) for h in HUMPS) \
        - 0.7 * math.exp(-((s - 10.0) / 6.0) ** 2) - 0.7 * math.exp(-((s - 28.5) / 5.0) ** 2) \
        - 0.6 * math.exp(-((s - 46.5) / 5.0) ** 2)
    return -6.5 - s * math.sin(GRIP_ANG) - 0.03 * max(0.0, s - 8.0) + off / math.cos(GRIP_ANG)


def grip_half_width(z):
    """Half width (mm) of the grip at height z.  The loft starts INSIDE the upper frame (A, 25.4 wide, bottom
    at z -38) 0.3 mm narrower, so the two never share coplanar side faces (review 2 §2.1: the black slot),
    reaches 12.7 at A's bevel, swells to 14.75 in the palm and narrows a touch at the bottom."""
    return 12.4 + 0.3 * gk.smoothstep(-33.0, -36.6, z) + 2.05 * gk.smoothstep(-37.5, -52.0, z) \
        - 0.35 * gk.smoothstep(-90.0, -105.0, z)


# rings: sparse on the straight parts, every ~2 mm over the finger humps (review 2 §2.2: no staircase)
GRIP_Z = [-33.0, -36.6, -40.0, -44.0, -48.0, -52.2, -56.5, -60.5] + \
    [round(-62.5 - 2.05 * k, 2) for k in range(18)] + [-100.0, -103.0, -104.6, -105.2]
WELL_Z = [-44.0, -103.8, -105.2]


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
        sec = gk.rrect2(cx, 0.0, hx, hw - inset, r_pos=min(10.0, hw * 0.75), r_neg=min(8.5, hw * 0.65), n=2)
        rings.append([mm(x, y, z) for x, y in sec])
    inner = []
    for z in WELL_Z:
        cx = well_center_x(z)
        hx = (MAG_DEPTH + 1.4) / 2 / math.cos(GRIP_ANG)
        hy = (MAG_W + 1.2) / 2
        flare = 1.6 if z < -103.0 else 0.0
        sec = gk.rrect2(cx, 0.0, hx + flare, hy + flare, r_pos=4.0, r_neg=4.0, n=2)
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
    # the recoil-spring opening at the front of the dust cover (half of a round hole shared with the slide
    # nose, the guide rod tip inside: review 2 §2.3)
    gk.cyl(c, mm(93.0, 0, RSPRING_Z), mm(101.0, 0, RSPRING_Z), mm(RSPRING_R), 12, mi=dc_bore(fr))
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
    # serrated (squared) guard front: kept, the reference's Gen-3 guard has these grooves (review 2 §2.4 rejected)
    for k in range(6):
        box5(bm, mm(46.0, 0, -33.0 - k * 2.6), mm(0.9, 7.6, 1.0), V((1, 0, 0)), mi=P)
    # stipple on the grip SIDE panels only (the reference's stipple stops at the straps), smooth above
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        c = f.calc_center_median()
        if mm(-102.5) < c.z < mm(-43.0) and c.x < mm(-3.0) and abs(f.normal.y) > 0.72:
            f.material_index = S
    # horizontal ribs: the lower backstrap and the front-strap valleys (review 2 §2.3), raised 0.9 mm, as thin
    # bars following the strap's slope (they read in the silhouette as the reference's grooves do)
    def rib(x, z, slope_dx, outward, width, h=1.3, d=1.8):
        t = V((slope_dx, 0, -1.0)).normalized()                 # down the strap
        n = V((outward, 0, 0)) - t * (t.x * outward)
        n.normalize()
        R = gk.basis(n, t.cross(n), t)
        box5(bm, V(mm(x, 0, z)) + n * mm(0.9 - d / 2), (mm(d), mm(width), mm(h)), n, R=R, mi=P)
    for k in range(8):
        z = -66.5 - k * 4.0
        dx = (_interp(BACK, z - 1.0) - _interp(BACK, z + 1.0)) / 2.0
        rib(_interp(BACK, z), z, dx, -1.0, 2 * (grip_half_width(z) - 7.0))
    for v in VALLEYS:
        for j in (-0.5, 0.5):
            s = v + j * 2.6
            z = -53.0 - s * math.cos(GRIP_ANG)
            dx = (front_x(z - 1.0) - front_x(z + 1.0)) / 2.0
            rib(front_x(z), z, dx, 1.0, 2 * (grip_half_width(z) - 8.5), h=1.1, d=1.6)
    return fr


def box5(bm, center, size, outward, R=None, mi=0):
    """A box without its hidden inner face (the one facing away from `outward`, buried in the surface)."""
    n0 = len(bm.faces)
    gk.box(bm, center, size, R=R, mi=mi)
    bm.faces.ensure_lookup_table()
    new = list(bm.faces[n0:])
    worst = min(new, key=lambda f: f.normal.dot(V(outward)))
    bmesh.ops.delete(bm, geom=[worst], context='FACES_ONLY')


RSPRING_Z, RSPRING_R = -11.6, 3.7     # recoil spring / guide rod opening (shared by the slide nose and dust cover)


def dc_bore(part):
    return part.mi('Bore')


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
        # (the tab's three grip ridges went into the budget: review 2 §3, 4 000 tris)
    for (x, z, y, r) in ((8.4, -14.0, 12.0, 1.6), (11.3, -21.4, 12.0, 1.6), (-51.0, -38.0, 13.9, 1.5)):
        gk.pin(bm, mm(x, y, z), (0, 1, 0), mm(r), proud=mm(0.25), segs=6, mi=St, both=mm(2 * y))
    # the guide-rod tip with the last spring coil, seen in the recoil-spring opening (static: the slide rides
    # over it), recessed 2.5 mm behind the slide face
    gk.cyl(bm, mm(86.0, 0, RSPRING_Z), mm(97.0, 0, RSPRING_Z), mm(1.9), 8, mi=St)
    gk.cyl(bm, mm(93.6, 0, RSPRING_Z), mm(95.0, 0, RSPRING_Z), mm(3.1), 8, mi=St)
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
    # barrel hole in the slide nose, and under it the recoil-spring opening (its lower half is in the dust
    # cover: review 2 §2.3, the reference's front view)
    c = bmesh.new()
    gk.cyl(c, mm(90.0, 0, 0), mm(101.0, 0, 0), mm(6.95), 20, mi=Bo)
    gk.cyl(c, mm(92.0, 0, RSPRING_Z), mm(101.0, 0, RSPRING_Z), mm(RSPRING_R), 12, mi=Bo)
    cuts.append(c)
    # rear serrations only (both sides): the reference (Gen 3) has no front cuts (review 2 §2.4)
    cuts.append(gk.serration_cutter(mm(-61.0), mm(-32.5), 8, mm(1.55), mm(0.9), mm(hw), mm(z0 - 1), mm(7.6), mi=St))
    # rear: cover plate recess
    c = bmesh.new()
    gk.box(c, mm(SLIDE_X[0], 0, -2.6), mm(1.6, 10.8, 13.6), mi=Pl)
    cuts.append(c)
    gk.boolean_bm(bm, cuts)
    # the cover plate (polymer, slightly proud) with its striker-channel indicator dimple
    gk.rbox(bm, mm(SLIDE_X[0] + 0.15, 0, -2.6), mm(1.0, 10.4, 13.2), mm(0.35), 1, mi=Pl)
    # the generic stamp (serial-like code + calibre) engraved on the left flat: the 'Stamp' paint (blued steel
    # with the text, mapped by object coordinates; the Slide's origin is the model origin)
    Sp = sl.mi('Stamp')
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        if f.normal.y > 0.95 and f.calc_center_median().y > mm(hw - 0.2) and f.material_index == St:
            f.material_index = Sp
    return sl


def build_sights(gun):
    rs = gun.part('SightRear', paint='SteelBlued', parent='Slide')
    St, Wh = rs.mi('SteelBlued'), rs.mi('SightPaint')
    x0, x1 = REAR_SIGHT
    side = [(x0, 9.2), (x1, 9.2), (x1, 11.2), (x1 - 2.5, REAR_TOP), (x0, REAR_TOP)]
    gk.profile(rs.bm, mm(gk.fillet2(side, 0.6, 1)), mm(12.6), bevel=mm(0.45), bevel_segs=1, mi=St)
    c = bmesh.new()
    gk.box(c, mm((x0 + x1) / 2, 0, REAR_TOP), mm(12.0, 3.4, 4.6), mi=St)       # U notch
    gk.cyl(c, mm(x0 - 2, 0, REAR_TOP - 2.3), mm(x1 + 2, 0, REAR_TOP - 2.3), mm(1.7), 6, mi=St)
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
    br = gun.part('Barrel', paint='SteelBlued', origin=mm(*BARREL_PIVOT), fit=2)
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
    # review 2 §2.6: a wider, more upright shoe (5-6 mm in profile, as the reference) whose tip clears the
    # guard floor (z -51.8) by ~2 mm, and a safety blade that reads: a slot down the shoe face with the blade
    # standing 1.2 mm proud of it
    # (second pass: the lower half 2 mm further forward, the overlay's red wedge ahead of the old shoe)
    front = [(6.0, -30.0), (8.4, -35.5), (11.8, -40.3), (15.6, -44.0), (19.0, -46.6), (21.0, -47.8)]
    back = [(20.3, -49.6), (17.4, -49.3), (13.4, -47.3), (9.6, -44.2), (6.0, -40.1), (3.2, -35.4), (1.4, -30.0)]
    shoe = front + [(21.5, -48.8)] + back
    gk.profile(tg.bm, mm(shoe), mm(6.4), bevel=mm(1.3), bevel_segs=0, mi=P)

    def offs(pts, d):
        out = []
        for i, (x, z) in enumerate(pts):
            a, b = pts[max(0, i - 1)], pts[min(len(pts) - 1, i + 1)]
            tx, tz = b[0] - a[0], b[1] - a[1]
            L = math.hypot(tx, tz)
            out.append((x - tz / L * d, z + tx / L * d))
        return out
    edge = front[1:5]
    slot = offs(edge, 0.6) + list(reversed(offs(edge, -1.6)))
    gk.boolean_bm(tg.bm, gk.prism_cutter(mm(slot), mm(-1.55), mm(1.55), mi=P))
    blade = offs(edge, 1.2) + list(reversed(offs(edge, -2.2)))
    gk.prism(tg.bm, mm(blade), mm(-1.1), mm(1.1), mi=P)
    return tg


def build_slide_stop(gun):
    ss = gun.part('SlideStop', paint='SteelBlued', origin=mm(-23.0, 13.4, -15.0))
    St = ss.mi('SteelBlued')
    out = [(-25.2, -13.2), (-8.6, -12.2), (-7.8, -13.4), (-8.6, -15.4), (-17.0, -16.4), (-25.2, -17.0)]
    gk.prism(ss.bm, mm(gk.fillet2(out, 0.9, 1)), mm(12.7), mm(13.7), mi=St)
    gk.rbox(ss.bm, mm(-14.6, 14.1, -13.1), mm(8.0, 1.0, 2.2), mm(0.35), 1, mi=St)      # thumb ledge
    gk.pin(ss.bm, mm(-23.0, 13.7, -15.0), (0, 1, 0), mm(1.3), proud=mm(0.25), segs=6, mi=St)
    return ss


def build_mag_release(gun):
    mr = gun.part('MagRelease', paint='Polymer', origin=mm(-12.6, 14.6, -46.8))
    P = mr.mi('Polymer')
    out = [(-9.3, -42.6), (-15.9, -42.6), (-15.9, -51.0), (-9.3, -51.0)]
    gk.profile(mr.bm, mm(gk.fillet2(out, 1.1, 1)), mm(2.6), y=mm(14.6), bevel=mm(0.5), bevel_segs=0, mi=P)
    for k in range(3):
        gk.box(mr.bm, mm(-12.6, 15.95, -44.8 - k * 2.0), mm(5.0, 0.35, 0.6), mi=P)
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
    # the hole bottoms show the brass of the stacked rounds (review 2 §2.9: they rendered black)
    bm.faces.ensure_lookup_table()
    fr_ = V((MAG_FR[0], 0, MAG_FR[1]))
    for f in bm.faces:
        c = f.calc_center_median()
        for h in holes:
            if (c - V(h)).length < mm(2.0) and f.normal.dot(fr_) < -0.8:
                f.material_index = Br
    # top round, lying in the lips, offset to one side (double stack)
    rt = gun.part('MagRoundTop', paint='Brass', parent='Magazine', origin=mm(-18.9, 2.0, -17.6))
    mats = {'case': rt.mi('Brass'), 'primer': rt.mi('Nickel'), 'bullet': rt.mi('Copper')}
    M = gk.frame_x(V(mm(-33.6, 2.0, -18.6)), V((math.cos(math.radians(3.5)), 0, math.sin(math.radians(3.5)))))
    gk.build_round(rt.bm, '9x19', mats, M, segs=8)
    # follower (only in the empty-magazine model, where it stands up between the lips, 1 mm proud of the
    # body's top so the empty mag reads; parked inside the body here, under the stack)
    fo = gun.part('MagFollower', paint='Polymer', parent='Magazine', origin=mm(*org))
    Pf = fo.mi('Polymer')
    q_ = mag_pt(FOLLOWER_PARK + 1.2, 1.5)
    gk.rbox(fo.bm, mm(q_[0], 0, q_[1]), mm(MAG_DEPTH - 8.0, 17.6, 4.4), mm(0.8), 1,
            R=gk.basis(X_, Z_.cross(X_), Z_), mi=Pf)
    q2 = mag_pt(FOLLOWER_PARK - 0.4, -7.0)
    gk.rbox(fo.bm, mm(q2[0], 0, q2[1]), mm(9.0, 17.6, 2.4), mm(0.5), 1,
            R=gk.basis(X_, Z_.cross(X_), Z_), mi=Pf)          # the raised rear step of the follower
    return mg, rt, fo


FOLLOWER_PARK = 60.0     # mm down the magazine where the follower sits in the full-mag model


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
    gun.hinge('Barrel', 'rotate', (0, 1, 0), 0.0, mn=-2.5,
              note='breech drops 2.9 mm as the slide unlocks; pivot forward under the locked-back slide nose '
                   '(the muzzle stays captured in the nose; ARCHITECTURE §5.2 amendment, pistol review 2)')
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
    # sight line: rear notch top -> front blade top, eye at ARM'S LENGTH behind (§5.3 'pistol: arm's length':
    # 0.55 m, a real extended isosceles).  The rigid R6 cannot put its head that far (arm 0.42 m, eye 0.31 m
    # above the shoulder): the solver puts the head ON this line, wherever along it (eye_t), and the game's ADS
    # camera sits on the line too (the sight picture is the same anywhere on it, only its size changes)
    rear = V(mm((REAR_SIGHT[0]), 0, REAR_TOP))
    front = V(mm(FRONT_SIGHT[0], 0, FRONT_TOP))
    d = (front - rear).normalized()
    gun.marker('SightEye', rear - d * SIGHT_EYE_M, d, (0, 0, 1))
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
# stances (pistol, ARCHITECTURE §7.3 / §7.4) and the pistol's hold solver
# --------------------------------------------------------------------------------------
# Review 2 §4: the old solve had none of the later terms (head roll / pitch, head in the arm, gun in the arms,
# gun visibility, feet) and 4 limit breaches.  PistolSolver adds them (the same terms as lmg.py / sniper.py; the
# kit is frozen) and check_hold() fails loudly.  R6 facts that bound a pistol hold: rigid arms 1.505 studs from
# the shoulder pivot, the eye 1.1 studs above the shoulders: with the sights ON the eye line the gun sits
# 0.55-0.80 stud (0.15-0.22 m) in front of the eye whatever the lean (worked out in the README); a real
# shooter's 0.55-0.65 m is out of reach of a rigid R6, so the eye is solved ON the line (<= 0.01 stud) and the
# game's ADS camera sits on that same line (SightEye +X), where the picture is identical, only larger.
RHAND = (0.0, -0.97, -0.10)             # the gun's grip in the right fist: the arm block's end, toward its front
LHAND = (0.0, -0.95, 0.05)              # the support hand wraps the left panel (its thumb along the frame)
EYE_P = (0.0, 0.10, -0.42)              # the eye in Head space (the pistol is centred: R6 face centre)
ROOT_ROLL_MAX, NECK_PITCH_MAX, NECK_ROLL_MAX, HEAD_ROLL_MAX = 3.0, 30.0, 12.0, 12.0
WRIST_MAX = 25.0
CAMS = ((0.8, 0.35, -1.0), (1.0, 0.08, 0.0))   # HRP-space view directions of the 3/4 front and right side renders
SIGHT_EYE_STUD = SIGHT_EYE_M / gk.STUD
# eye distance to the rear sight allowed along the line (studs): 0.50-0.95 -> t = SightEye distance - that
EYE_T = (SIGHT_EYE_STUD - 0.95, SIGHT_EYE_STUD - 0.50)
_C = dict(wrist_limit=WRIST_MAX, left_limit=35.0, w_left=16.0, head_clear=0.0, w_occl=2.0, w_cant=4.0,
          lean_tol=5.0, blade_tol=10.0, front=12.0, neck_max=NECK_PITCH_MAX)
_AIM = dict(_C, eye='line', eye_t=EYE_T, w_eye=60.0, eye_tol=0.01, blade=-10.0, lean=-7.0, lean_tol=5.0, w_left=25.0,
            head_pitch=-6.0, w_nod=3.0, w_relief=20.0, rs_ref=(120, -10, -55), ls_ref=(125, -5, 58), front=14.0)
STANCES = [
    dict(_AIM, name='Aim', pitch=0.0),
    dict(_C, name='Ready', pitch=-12.0, place=(mm(-36, 0, -46), (0.12, 0.45, -1.15), 4.0), eye='over',
         eye_over=0.55, blade=-10.0, lean=-6.0, head_pitch=-6.0, rs_ref=(90, -5, -59), ls_ref=(90, 5, 60)),
    # muzzle up, the gun under the chin line, the eyes over it (entry / moving through a crowd)
    dict(_C, name='HighReady', pitch=40.0, blade=-10.0, lean=-3.0, lean_tol=4.0, head_pitch=-2.0, left_limit=45.0,
         rs_ref=(120, 0, -55), ls_ref=(120, 0, 55), w_occl=1.0),
    # review 2: upright torso (spec -6 +- 4 hard), arms extended down ~45 deg, the muzzle at the ground ahead
    dict(_C, name='LowReady', pitch=-45.0, blade=-8.0, lean=-5.0, lean_tol=4.0, head_pitch=-14.0,
         rs_ref=(60, 0, -55), ls_ref=(60, 0, 55), left_limit=40.0),
    # both hands, the gun low in front of the belly, muzzle down: arms hang, torso leans into the run
    dict(_C, name='SprintCarry', pitch=-65.0, blade=-5.0, lean=-14.0, lean_tol=5.0, head_pitch=-4.0,
         rs_ref=(30, 0, -40), ls_ref=(30, 0, 40), left_limit=45.0, w_occl=1.0),
    # wall in the face: the muzzle up and pulled to the right, or down and in
    dict(_C, name='ObstructedHigh', pitch=50.0, yaw=-10.0, yaw_tol=12.0, blade=-12.0, lean=-2.0, lean_tol=4.0,
         head_pitch=0.0, head_yaw=0.0, rs_ref=(140, 0, -50), ls_ref=(140, 0, 50), left_limit=55.0, w_left=20.0,
         w_occl=1.0),
    dict(_C, name='ObstructedLow', pitch=-70.0, yaw=5.0, yaw_tol=12.0, blade=-8.0, lean=-6.0, lean_tol=4.0,
         head_pitch=-16.0, head_yaw=0.0, rs_ref=(35, 0, -45), ls_ref=(35, 0, 45), left_limit=50.0, w_occl=1.0),
    # the reload: gun at chest height, muzzle up ~25 deg and canted in, mag well toward the support hand that
    # brings the new mag from the belt (its hand on the baseplate, the mag 10 mm short of seated), eyes on it
    # (left_limit 60: the support forearm comes UP from the belt under the gun, a real reload's angle to the mag)
    dict(_C, name='ReloadInsert', pitch=25.0, yaw=10.0, yaw_tol=10.0, cant=-22.0, w_cant=2.0, blade=-14.0,
         blade_tol=10.0, lean=-8.0, look='gun', rs_ref=(85, 0, -60), ls_ref=(60, 20, 60), left_mag=True,
         left_limit=60.0, wrist_limit=WRIST_MAX, w_occl=1.0),
]
# §7.4 aim-pitch rows (the pistol: -60, -30, 0, +30, +60) and tuck columns (the gun pulled back 0.3 / 0.6 stud
# along the bore for the wall check, §7.8).  Rows keep the eye on the line; at +-60 the neck alone cannot pitch
# the head that far, so the rows allow neck 40 and lean +-12 (the game splits pitch between Root and Neck).
ROWS = (-60.0, -30.0, 30.0, 60.0)
TUCKS = (0.5, 1.0)


def row_stance(p):
    """Down rows keep the eye on the line.  Up rows cannot (rigid arms raising the gun 30-60 deg put the sight
    line above and in front of the head: the neck would have to tilt the head back past 40 deg with the gun
    0.5 stud from the face), so they aim the gun with the head looking along it at the muzzle; the ADS camera
    stays on the line either way."""
    st = dict(_AIM, name='Aim_p%+d' % int(p), pitch=p, lean=-7.0 - 0.10 * p, lean_tol=10.0, neck_max=40.0,
              head_pitch=p - 6.0, eye_tol=0.03, w_occl=1.0)
    if p > 0:
        for k in ('eye', 'eye_t', 'w_eye', 'eye_tol', 'w_relief', 'w_nod'):
            st.pop(k, None)
        st.update(look='Muzzle', left_limit=45.0 if p < 45 else 60.0, w_dir=24.0, w_cant=6.0, rs_ref=(120 + p * 0.7, -10, -55), ls_ref=(125 + p * 0.7, -5, 58))
    return st


def tuck_stance(c, aim):
    """The gun pulled back c * 0.6 stud along the bore from the solved Aim (its grip point placed there)."""
    import numpy as np
    G = aim['_eval']['G']
    grip = G @ np.append(gk.model_to_gun(mm(-36, 0, -46)), 1.0)
    bore = G[:3, :3] @ np.array([0, 0, -1.0])
    goal = grip[:3] - bore * 0.6 * c
    return dict(_AIM, name='Aim_t%.1f' % c, pitch=0.0, place=(mm(-36, 0, -46), tuple(float(v) for v in goal), 8.0),
                eye_t=(EYE_T[0] - 0.6 * c - 0.2, EYE_T[1]), w_eye=25.0, eye_tol=0.05, lean_tol=8.0, w_occl=1.0)


class PistolSolver(gk.HoldSolver):
    """gk.HoldSolver plus the review terms (as lmg.py's LmgSolver / sniper.py's solver):
    - RHAND / LHAND hand points at the arm blocks' ends (the grip in the fists, not at their centres);
    - HARD bounds: Root roll <= 3, blade / lean within the stance tolerance, neck pitch <= 30 (rows 40), roll <= 12;
    - the Root drops so the lowest foot is on y = -3, feet level;
    - no head inside the right arm block, no gun inside the arm blocks (away from the hands) or the head, and the
      share of the gun hidden from the 3/4-front and right-side review cameras (visible fraction)."""

    def __init__(self, gun, samples):
        import numpy as np
        super().__init__(gun, samples)
        self.cams = [np.array(c, float) / np.linalg.norm(c) for c in CAMS]
        g = np.array(self.G_grip[:3, 3])
        near = [np.array(self.m[k][:3, 3]) for k in ('GripL', 'MagGrab')]
        d = lambda c: np.linalg.norm(self.samples - c, axis=1)
        self.away_r = d(g) > 0.30
        self.away_l = np.all([d(c) > 0.25 for c in near], axis=0)
        hp = [(0, 0, 0)] + [(sx * 0.42, sy * 0.4, sz * 0.42) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        self.head_pts = np.array([p + (1.0,) for p in hp])

    def weld(self, w):
        import numpy as np
        A = np.eye(4)
        A[:3, :3] = self.Rn @ gk.rotvec(w)
        A[:3, 3] = RHAND
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
        if e['lerr'] is not None:
            hand = F['Left Arm'] @ np.array(LHAND + (1.0,))
            e['lhand'] = hand[:3]
            e['lerr'] = hand[:3] - e['lgoal']
        H = F['Head']
        e['eye'] = (H @ np.array(EYE_P + (1.0,)))[:3]
        if 'sight_o' in e:
            rel = e['eye'] - e['sight_o']
            t = float(np.dot(rel, e['sight_d']))
            e['sight_t'], e['sight_perp'] = t, rel - e['sight_d'] * t
            e['eye_over'] = float(e['eye'][1] - (e['sight_o'][1] + e['sight_d'][1] * t))
        e['head_roll'] = math.degrees(math.asin(max(-1.0, min(1.0, float(H[1, 0])))))
        e['head_pitch'] = math.degrees(math.asin(max(-1.0, min(1.0, float(-H[1, 2])))))
        e['feet'] = self.feet(F)
        Ri = np.linalg.inv(F['Right Arm'])
        Li = np.linalg.inv(F['Left Arm'])
        hp = (H @ self.head_pts.T).T[:, :3]
        e['head_in_rarm'] = float(np.max(self._inside(hp, Ri, (0.5, 1.0, 0.5))))
        P = e['pts']
        away_l = self.away_l
        if st.get('left') is not None and not isinstance(st.get('left'), str):
            # (a stance-specific support target, e.g. the mag baseplate: only the points there may be in the
            # left fist; the grip panel is not held then)
            away_l = np.linalg.norm(self.samples - np.array(gk.model_to_gun(st['left'])), axis=1) > 0.25
        pin = np.maximum(self._inside(P, Ri, (0.47, 0.97, 0.47)) * self.away_r,
                         self._inside(P, Li, (0.47, 0.97, 0.47)) * away_l)
        e['gun_in_arms'] = float(np.sqrt(np.mean(pin ** 2)))
        e['gun_in_head'] = float(np.max(self._inside(P, np.linalg.inv(H), (0.6, 0.6, 0.6))))
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
        # (only the points away from both hands count: a pistol's grip is IN the two fists by design)
        occ = np.mean(occ_all, axis=0)[self.away_r & self.away_l]
        e['occl'] = float(occ.mean())
        e['visible'] = float((occ < 0.5).mean())
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
        r.append(e['gun_in_arms'] * 25.0)
        r.append(e['gun_in_head'] * 40.0)
        r.append(max(0.0, abs(e['head_roll']) - HEAD_ROLL_MAX + 1.0) * 1.5)
        if st.get('w_occl'):
            r.append(max(0.0, e['occl'] - 0.25) * st['w_occl'])
        if st.get('eye') == 'over' and 'eye_over' in e:
            r.append(max(0.0, abs(e['eye_over'] - st['eye_over']) - 0.05) * 20.0)
        if st.get('eye') == 'line' and 'sight_t' in e:
            tmin, tmax = st.get('eye_t', EYE_T)
            r.append((max(0.0, tmin - e['sight_t']) + max(0.0, e['sight_t'] - tmax)) * st.get('w_relief', 0.0))
        if st.get('w_nod'):
            r.append(max(0.0, abs(e['head_pitch'] - st['head_pitch']) - 5.0) / 10.0 * st['w_nod'])
        return np.array(r, float)

    def solve(self, st, starts=16, seed=1, x0=None):
        import numpy as np
        from scipy.optimize import least_squares
        rng = np.random.default_rng(seed)
        nk = st.get('neck_max', NECK_PITCH_MAX)
        lo = np.array([-35, -75, -ROOT_ROLL_MAX, -nk, -80, -NECK_ROLL_MAX, -200, -200, -200, -200, -200,
                       -200, -WRIST_MAX, -WRIST_MAX, -WRIST_MAX], float)
        hi = -lo
        lo[0], hi[0] = st['lean'] - st['lean_tol'], min(15.0, st['lean'] + st['lean_tol'])
        lo[1], hi[1] = st['blade'] - st['blade_tol'], st['blade'] + st['blade_tol']
        wl = st.get('wrist_limit', WRIST_MAX)
        lo[12:15], hi[12:15] = -wl, wl
        best = None
        base = np.array([st['lean'], st['blade'], 0, 0, 0, 0] +
                        list(st.get('rs_ref', (90, 0, 0))) + list(st.get('ls_ref', (90, 0, 0))) + [0, 0, 0], float)
        inits = [base] + ([np.array(x0, float)] if x0 is not None else [])
        for _ in range(starts):
            inits.append(base + rng.normal(0, 1, 15) * np.array([3, 6, 1.5, 10, 15, 4, 40, 40, 40, 40, 40, 40, 10, 10,
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
    """The stance's hard limits (ARCHITECTURE §7.4, review 2 §4): returns the list of violations."""
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
    if st.get('eye') == 'line' and res.get('eyeToSightLine', 0.0) > st.get('eye_tol', 0.01):
        bad.append('eye to line %.3f stud' % res['eyeToSightLine'])
    if st.get('eye') == 'line':
        tmin, tmax = st.get('eye_t', EYE_T)
        if not (tmin - 0.02 <= res.get('eyeAlongSight', 0.0) <= tmax + 0.02):
            bad.append('eye along line %.3f' % res.get('eyeAlongSight', 0.0))
    if st.get('eye') == 'over' and abs(res.get('eyeOver', 0.0) - st['eye_over']) > 0.10:
        bad.append('eye over %.3f' % res.get('eyeOver', 0.0))
    if abs(res['headRollDeg']) > HEAD_ROLL_MAX + 0.5:
        bad.append('head roll %.1f' % res['headRollDeg'])
    if abs(res['cantDeg'] - st.get('cant', 0.0)) > 8.0:
        bad.append('cant %.1f' % res['cantDeg'])
    if res['gunInHead'] > 0.03:
        bad.append('gun in head %.3f stud' % res['gunInHead'])
    if res['gunInArms'] > 0.03:
        bad.append('gun in arms %.3f stud' % res['gunInArms'])
    if res['headInRightArm'] > 0.06:
        bad.append('head in right arm %.3f' % res['headInRightArm'])
    if abs(res['feetY'][0] - res['feetY'][1]) > 0.05:
        bad.append('feet %s' % (res['feetY'],))
    if res['gunVisible'] < 0.5:
        bad.append('gun visible %.0f%%' % (100 * res['gunVisible']))
    by = res['boreYawPitch']
    if abs(by[1] - st.get('pitch', 0.0)) > 6.0 or abs(by[0] - st.get('yaw', 0.0)) > st.get('yaw_tol', 8.0):
        bad.append('bore %s' % (by,))
    return bad


def _left_mag(st):
    # support hand on the magazine baseplate, the mag 10 mm short of seated
    s = MAG_LEN + 10.0
    p = mag_pt(s, 0.0)
    st['left'] = mm(p[0], 0.0, p[1])
    st['left_z'] = (MAG_AX[0] * 0.7, 0.55, MAG_AX[1] * 0.7)


def solve_holds(gun, out_json):
    import numpy as np
    sv = PistolSolver(gun, gun_samples(gun))
    results, failures = [], []
    starts = int(os.environ.get('PISTOL_STARTS', '16'))
    only = os.environ.get('PISTOL_STANCES')
    todo = list(STANCES) + [row_stance(p) for p in ROWS]
    aim = None
    for st0 in todo + [None] * len(TUCKS):
        if st0 is None:
            if aim is None:
                continue
            st0 = tuck_stance(TUCKS[len([r for r in results if r['name'].startswith('Aim_t')])], aim)
        if only and st0['name'].split('_')[0] not in only.split(','):
            continue
        st = {k: v for k, v in st0.items() if k != 'left_mag'}
        if st0.get('left_mag'):
            _left_mag(st)
        r = sv.solve(st, starts=starts)
        e = r['_eval']
        r['grip'] = 'GripR'
        r['owner'] = 'Torso'
        r['rightHand'] = list(RHAND)
        r['supportHand'] = list(LHAND)
        r['supportTarget'] = 'MagBaseplate(10mm short)' if st0.get('left_mag') else 'GripL'
        r['residuals']['cantDeg'] = round(math.degrees(math.asin(max(-1.0, min(1.0, float(-e['right'][1]))))), 1)
        r['residuals'].update({'headRollDeg': round(e['head_roll'], 1), 'headPitchDeg': round(e['head_pitch'], 1),
                               'headInRightArm': round(e['head_in_rarm'], 3), 'gunInArms': round(e['gun_in_arms'], 3),
                               'gunInHead': round(e['gun_in_head'], 3),
                               'gunVisible': round(e['visible'], 2), 'feetY': [round(v, 3) for v in e['feet']]})
        if 'eye_over' in e:
            r['residuals']['eyeOver'] = round(e['eye_over'], 3)
        if 'sight_t' in e:
            r['residuals']['eyeToRearSightStud'] = round(SIGHT_EYE_STUD - e['sight_t'], 3)
        bad = check_hold(r, st0)
        r['check'] = 'ok' if not bad else bad
        print('HOLD %-14s cost %.4f %s residuals %s pose %s wrist %s' % (
            r['name'], r['cost'], 'OK' if not bad else 'FAIL %s' % bad, r['residuals'], r['pose'], r['wrist']),
            flush=True)
        if bad:
            failures.append((r['name'], bad))
        if r['name'] == 'Aim':
            aim = r
        results.append(r)
    gk.holds_to_json(out_json, GID, results, extra={
        'note': 'Solved by tools/guns/pistol.py (PistolSolver = gunkit.HoldSolver + the review terms). R6: rigid '
                'arms; the right fist holds the grip at arm space %s, the support hand at %s; the weld is the only '
                'wrist. ReloadInsert: left hand on the baseplate of a magazine 10 mm short of seated (MagWell +X). '
                'Eye ON the sight line (Aim); the R6 eye sits %.2f-%.2f stud from the rear sight (a rigid R6 cannot '
                'reach arm\'s length); the ADS camera uses SightEye.' % (RHAND, LHAND, 0.50, 0.95),
        'aimRows': {'-60': 'Aim_p-60', '-30': 'Aim_p-30', '0': 'Aim', '30': 'Aim_p+30', '60': 'Aim_p+60'},
        'tuckColumns': {'0': 'Aim', '0.5': 'Aim_t0.5', '1': 'Aim_t1.0'},
        'failures': {n: b for n, b in failures},
        'markers': {k: [round(c, 5) for c in gun.markers[k][0]] for k in ('GripR', 'GripL', 'SightEye')}})
    if failures:
        print('HOLD CHECK FAILED: %s' % failures, flush=True)
    return results, sv


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
        fo.matrix_world = empty.matrix_world @ Matrix.Translation(V((MAG_AX[0], 0, MAG_AX[1])) * -mm(FOLLOWER_PARK))
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
            vw = ('front', 'side', 'close', 'eye') if '_' not in r['name'] else ('front', 'eye')
            hold_files.append(render_hold(args, rig, gun, objs, root, gobjs, r, solver, views=vw))
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


def render_hold(args, rig, gun, objs, root, gobjs, r, solver, views=('front', 'side', 'close', 'eye')):
    """One stance on the R6 dummy: front 3/4, right side, hands close-up and the eye's view, in a grid.  The eye
    view: ADS stances look from the sight line (the ADS camera, at the R6 eye's distance); the others from the
    R6 eye toward the gun (review 2: ReloadInsert's eye view was black, the camera looked along the gun at the
    sky)."""
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
    ads = r['name'].startswith('Aim')
    allv = {'front': ((1.0, -0.75, 0.35), dict(lens=50)), 'side': ((0.0, -1.0, 0.08), dict(lens=50)),
            'close': ((1.0, -0.55, 0.25), dict(lens=60)), 'eye': (None, {})}
    for tag in views:
        view, kw = allv[tag]
        gk.set_res(1100, 820)
        bpy.context.scene.cycles.samples = 24 if not args.quick else 8
        if view is None:
            head.hide_render = True
            for o in arms:
                o.hide_render = True
            if ads and 'sight_d' in e:
                eye_p = e['sight_o'] + e['sight_d'] * e['sight_t']
                eye_b = gk.r2b_point(eye_p)
                tgt = gk.r2b_point(eye_p + e['sight_d'] * 4.0)
                rig.cam.data.lens = 35
            else:
                eye_b = gk.r2b_point(e['eye'])
                G = e['G']
                tgt = gk.r2b_point((G @ np.append(gk.model_to_gun(mm(0, 0, -30)), 1.0))[:3])
                rig.cam.data.lens = 28
            rig.cam.data.type = 'PERSP'
            rig.cam.data.clip_start = 0.01
            rig.aim(rig.cam, eye_b, tgt)
            rig.place_lights((lo + hi) / 2, 2.5)
        elif tag == 'close':
            head.hide_render = False
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
    txt = '%s: blade %.0f, lean %.0f, wrist %.0f; left %.3f stud (%.0f deg)%s; bore %s; head roll %.0f pitch %.0f; ' \
          'visible %.0f%%; %s' % (
              r['name'], r['pose']['Root'][1], r['pose']['Root'][0], res['wristDeg'], res.get('left', float('nan')),
              res.get('leftAngleDeg', float('nan')),
              ('; eye-line %.3f stud, %.2f stud from the rear sight' % (res['eyeToSightLine'],
                                                                        res['eyeToRearSightStud'])) if ads else '',
              res['boreYawPitch'], res['headRollDeg'], res['headPitchDeg'], 100 * res['gunVisible'],
              'CHECK OK' if r['check'] == 'ok' else 'FAIL %s' % r['check'])
    labels = {'front': 'front 3/4', 'side': 'right side', 'close': 'hands close-up',
              'eye': 'eye view (head and arms hidden%s)' % (', on the sight line' if ads else '')}
    out = gk.grid(names, os.path.join(args.out, '13_hold_%s.png' % r['name']), cols=2, tw=1100, th=820,
                  labels=[labels[v] for v in views], title=txt)
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
    build_pistol_materials(args.out)
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
    gk.finish_meshes(objs)          # triangulated, no degenerates (ARCHITECTURE §5.1)
    gk.finish_meshes(ammo)
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
        fo.location = V(mm(MAG_AX[0] * -FOLLOWER_PARK, 0, MAG_AX[1] * -FOLLOWER_PARK))
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
