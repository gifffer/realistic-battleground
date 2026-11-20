#!/usr/bin/env python3
"""The Pyromaniac's flamethrower rebuilt from Roblox primitives (Parts, Cylinders, Wedges,
Sphere meshes), read from the validated model (tools/pyro/flamethrower.py), for the game.

Writes src/client/Combat/FlamethrowerShape.luau (the parts, the points the effects use, the
pivots of the moving bits, the grip and sling welds, how to fit the imported FBX) and renders
previews of the primitive version next to the validated model (same cameras), on an R6 dummy
slung on the back and in the hip-fire hold, and hot (Awakened / finisher heat).

Spaces: the model is metres, +X muzzle, +Y left, +Z up.  The game's gun space is studs
(1 stud = 0.28 m), -Z muzzle (LookVector), +X right, +Y up: roblox = (-y, z, -x) / 0.28.

Usage (Blender python, from the repo root):
  /home/user/z-anatomy/venv/bin/python -I tools/pyro/flamethrower_parts.py \
      [--write] [--render DIR] [--quick] [--fbx assets/pyro/Flamethrower.fbx]
then run stylua on src (the written Luau is formatted by it).
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import flamethrower as F  # noqa: E402

V = Vector
S = 0.28  # metres per stud
C = Matrix(((0, -1, 0), (0, 0, 1), (-1, 0, 0)))  # model axes -> game axes
OUT_LUAU = os.path.join(ROOT, 'src', 'client', 'Combat', 'FlamethrowerShape.luau')

# --------------------------------------------------------------------------------------
# paints (the Luau side has the same keys; colours are what Roblox shows)
# --------------------------------------------------------------------------------------
PAINTS = {
    # key: (rgb, Roblox material, reflectance)
    'Steel': ((58, 54, 50), 'Metal', 0.0),
    'Shroud': ((64, 57, 52), 'Metal', 0.0),
    'Muzzle': ((70, 62, 66), 'Metal', 0.0),
    'Lip': ((78, 60, 50), 'Metal', 0.0),
    'Soot': ((14, 12, 11), 'SmoothPlastic', 0.0),
    'Hole': ((16, 13, 11), 'SmoothPlastic', 0.0),
    'Olive': ((78, 84, 52), 'Metal', 0.0),
    'Collar': ((66, 72, 44), 'Metal', 0.0),
    'Red': ((150, 30, 25), 'SmoothPlastic', 0.0),
    'Wood': ((110, 72, 40), 'Wood', 0.0),
    'Galv': ((140, 140, 135), 'Metal', 0.0),
    'Rubber': ((25, 25, 25), 'Fabric', 0.0),
    'Hose': ((30, 30, 30), 'Rubber', 0.0),
    'Tape': ((22, 22, 22), 'Fabric', 0.0),
    'Brass': ((170, 130, 60), 'Metal', 0.0),
    'Copper': ((160, 90, 50), 'Metal', 0.0),
    'Chrome': ((185, 188, 192), 'Metal', 0.15),
    'Zinc': ((120, 120, 115), 'Metal', 0.0),
    'Face': ((220, 215, 200), 'SmoothPlastic', 0.0),
    'Black': ((20, 20, 20), 'SmoothPlastic', 0.0),
    'Weld': ((60, 55, 50), 'Metal', 0.0),
    'Glow': ((255, 120, 40), 'Neon', 0.0),
}

# The imported FBX's parts: their paint and the moving bit they belong to.
MESH_PAINT = {
    'BallValve': 'Brass', 'Barrel': 'Steel', 'BoltsMount': 'Steel', 'BrakeCable': 'Black', 'FeedPipe': 'Steel',
    'ForeGripBand': 'Steel', 'ForeGripClamp': 'Steel', 'ForeGripHandle': 'Wood', 'Gauge': 'Brass',
    'GripMount': 'Steel', 'HeatShroud': 'Shroud', 'Hose': 'Hose', 'HoseFittings': 'Steel', 'Muzzle': 'Muzzle',
    'NozzleGrip': 'Red', 'PilotBurner': 'Steel', 'PilotLine': 'Copper', 'Regulator': 'Zinc',
    'ShroudClamps': 'Steel', 'StockButt': 'Rubber', 'StockClamp': 'Steel', 'StockConduit': 'Galv', 'Tank': 'Olive',
    'TankBands': 'Steel', 'TankCollar': 'Collar', 'TankRail': 'Steel', 'TankValve': 'Brass', 'TapeFeed': 'Tape',
    'TeeFitting': 'Steel', 'TriggerGuard': 'Red', 'TriggerLever': 'Chrome', 'ValveLever': 'Red',
    'ValveWheel': 'Red', 'WeldsFrontGrip': 'Weld', 'WeldsGrip': 'Weld', 'WeldsMount': 'Weld',
    'WeldsMuzzle': 'Weld', 'WeldsPipe': 'Weld', 'WeldsShroud': 'Weld', 'WeldsStock': 'Weld', 'WeldsValve': 'Weld',
}
MESH_GROUP = {'TriggerLever': 'Trigger', 'ValveLever': 'Valve', 'ValveWheel': 'Wheel'}
FIT_PARTS = ('Muzzle', 'StockConduit', 'Tank', 'ValveLever')   # 3 to fit, the 4th to check

# --------------------------------------------------------------------------------------
# primitives (model space, metres)
# --------------------------------------------------------------------------------------
PARTS = []       # dict(name, shape, pos, axes (3x3, columns = local X, Y, Z), size, paint, group, extra)
PIVOTS = {}      # group -> (pos, axes)
POINTS = {}      # name -> (pos, axes)


def frame(xdir, up=(0, 0, 1)):
    """Right-handed axes whose X is xdir (a cylinder's axis)."""
    X = V(xdir).normalized()
    u = V(up)
    if abs(X.dot(u.normalized())) > 0.95:
        u = V((0, 1, 0)) if abs(X.y) < 0.9 else V((1, 0, 0))
    Z = X.cross(u).normalized()
    Y = Z.cross(X)
    return Matrix((X, Y, Z)).transposed()


def look(zdir_forward, up=(0, 0, 1)):
    """Axes whose -Z is `zdir_forward` (Roblox LookVector), Y near `up`."""
    Bk = -V(zdir_forward).normalized()
    u = V(up)
    if abs(Bk.dot(u.normalized())) > 0.95:
        u = V((0, 1, 0))
    X = u.cross(Bk).normalized()
    Y = Bk.cross(X)
    return Matrix((X, Y, Bk)).transposed()


I3 = Matrix.Identity(3)


def add(name, shape, pos, axes, size, paint, group='Body', **extra):
    PARTS.append(dict(name=name, shape=shape, pos=V(pos), axes=axes.copy(), size=V(size), paint=paint,
                      group=group, extra=extra))


def cyl(name, p0, p1, r, paint, group='Body', up=(0, 0, 1)):
    p0, p1 = V(p0), V(p1)
    L = (p1 - p0).length
    add(name, 'Cyl', (p0 + p1) / 2, frame(p1 - p0, up), (L, 2 * r, 2 * r), paint, group)


def cylx(name, x0, x1, r, paint, group='Body'):
    cyl(name, (x0, 0, 0), (x1, 0, 0), r, paint, group)


def bar(name, p0, p1, w, t, paint, group='Body', up=(0, 0, 1)):
    """A flat bar from p0 to p1: w across (local Z), t thick (local Y, near `up`)."""
    p0, p1 = V(p0), V(p1)
    L = (p1 - p0).length
    add(name, 'Block', (p0 + p1) / 2, frame(p1 - p0, up), (L, t, w), paint, group)


def block(name, c, size, axes, paint, group='Body'):
    add(name, 'Block', c, axes, size, paint, group)


def ell(name, c, size, axes, paint, group='Body'):
    add(name, 'Sphere', c, axes, size, paint, group)


def tube_path(name, pts, r, paint, group='Body', joints=True, k=1):
    pts = [V(p) for p in pts]
    for i in range(0, len(pts) - 1, k):
        j = min(i + k, len(pts) - 1)
        cyl(name, pts[i], pts[j], r, paint, group)
        if joints and 0 < j < len(pts) - 1:
            ell(name + 'Joint', pts[j], (2 * r, 2 * r, 2 * r), I3, paint, group)


def resample(pts, n):
    """n+1 points evenly spaced along a polyline."""
    pts = [V(p) for p in pts]
    seg = [(pts[i + 1] - pts[i]).length for i in range(len(pts) - 1)]
    total = sum(seg)
    out = [pts[0]]
    for s in range(1, n):
        d = total * s / n
        for i, L in enumerate(seg):
            if d <= L or i == len(seg) - 1:
                out.append(pts[i].lerp(pts[i + 1], min(1.0, d / max(L, 1e-9))))
                break
            d -= L
    out.append(pts[-1])
    return out


def build():
    PARTS.clear()
    PIVOTS.clear()
    POINTS.clear()
    MG = F.MG()
    MG3 = MG.to_3x3()
    MB = F.MB()
    MB3 = MB.to_3x3()
    PIPE_R, SHR_R = F.PIPE_R, F.SHR_R

    # --- feed pipe, union, tape -----------------------------------------------------------
    cylx('FeedCap', -0.362, -0.348, PIPE_R + 0.001, 'Steel')
    cylx('FeedPipe', -0.350, 0.214, PIPE_R, 'Steel')
    cylx('UnionNut', -0.147, -0.123, 0.029, 'Steel')
    cylx('UnionCollar', -0.123, -0.113, 0.024, 'Steel')
    cylx('Tape', -0.208, -0.168, PIPE_R + 0.0018, 'Tape')
    cylx('Tape', 0.008, 0.046, PIPE_R + 0.0052, 'Tape')

    # --- nozzle grip (cast red body, ribbed rubber cover, spout, rear boot) ----------------
    def g(u, z=0.0, y=0.0):
        return MG @ V((u, y, z))
    ell('GripDome', g(0.012), (0.034, 0.047, 0.070), MG3, 'Red')
    block('GripCover', g(0.053), (0.088, 0.050, 0.074), MG3, 'Rubber')
    for u in (0.028, 0.050, 0.072):
        block('GripRib', g(u), (0.004, 0.053, 0.077), MG3, 'Rubber')
    block('GripBody', g(0.126, 0.001), (0.056, 0.045, 0.064), MG3, 'Red')
    block('GripNose', g(0.170, 0.004), (0.036, 0.036, 0.046), MG3, 'Red')
    for s in (-1, 1):
        cyl('GripBoss', g(0.135, 0, s * 0.017), g(0.135, 0, s * 0.0235), 0.007, 'Red', up=(1, 0, 0))
    sp0, sp1 = g(0.18, 0.002), V((-0.236, 0, -PIPE_R - 0.004))
    cyl('Spout', sp0, sp1, 0.0105, 'Steel')
    cyl('GripBoot', g(-0.045), g(0.006), 0.0195, 'Rubber')
    cyl('GripBootClamp', g(-0.035), g(-0.025), 0.0225, 'Steel')
    # saddle + strap under the pipe
    block('GripSaddle', (-0.236, 0, -PIPE_R - 0.007), (0.034, 0.024, 0.012), I3, 'Steel')
    cylx('GripStrap', -0.246, -0.226, PIPE_R + 0.003, 'Steel')

    # trigger lever (moves: a pull turns it about its pivot pin)
    pv = g(0.168, -0.024)
    PIVOTS['Trigger'] = (pv, MG3)
    lever = [g(0.168, -0.024), g(0.14, -0.040), g(0.10, -0.045), g(0.05, -0.045), g(0.026, -0.040)]
    for a, b in zip(lever[:-1], lever[1:]):
        bar('TriggerLever', a, b, 0.0128, 0.0052, 'Chrome', 'Trigger', up=MG3 @ V((0, 0, 1)))
    cyl('TriggerPin', pv - V((0, 0.028, 0)), pv + V((0, 0.028, 0)), 0.0035, 'Steel', 'Trigger', up=(1, 0, 0))
    # guard: a flat cast band
    guard = [g(0.184, -0.018), g(0.180, -0.048), g(0.158, -0.064), g(0.100, -0.071), g(0.045, -0.067),
             g(0.020, -0.052), g(0.014, -0.028)]
    for a, b in zip(guard[:-1], guard[1:]):
        bar('TriggerGuard', a, b, 0.018, 0.0084, 'Red', up=MG3 @ V((0, 0, 1)))

    # --- conduit loop stock, inner-tube butt, tape ------------------------------------------
    end = g(-0.040)
    path = F.crs([(-0.350, 0, 0.0), (-0.42, 0, 0.003), (-0.49, 0, 0.0), (-0.532, 0, -0.018), (-0.552, 0, -0.058),
                  (-0.546, 0, -0.098), (-0.522, 0, -0.122), (-0.49, 0, -0.130), tuple(end + V((-0.004, 0, -0.002))),
                  tuple(end + V((0.012, 0, 0.005)))], 7)
    pts = resample(path, 13)
    for a, b in zip(pts[:-1], pts[1:]):
        butt = a.x < -0.512 and b.x < -0.512
        cyl('StockButt' if butt else 'Stock', a, b, 0.0182 if butt else 0.0135, 'Rubber' if butt else 'Galv')
    for p in pts[1:-1]:
        butt = p.x < -0.512
        r = 0.0182 if butt else 0.0135
        ell('StockJoint', p, (2 * r, 2 * r, 2 * r), I3, 'Rubber' if butt else 'Galv')
    cylx('Tape', -0.455, -0.405, 0.0152, 'Tape')

    # --- T fitting, ball valve, lever (moves), brake cable ---------------------------------
    cylx('Tee', 0.063, 0.107, 0.0275, 'Steel')
    cyl('TeeBranch', (0.085, 0, 0), (0.085, -0.040, 0), 0.0135, 'Steel')
    cyl('TeeNut', (0.085, -0.040, 0), (0.085, -0.050, 0), 0.0165, 'Brass')
    cyl('TeeBarb', (0.085, -0.050, 0), (0.085, -0.066, 0), 0.0075, 'Brass')
    cylx('ValveEnd', 0.116, 0.127, 0.0285, 'Brass')
    cylx('ValveEnd', 0.173, 0.184, 0.0285, 'Brass')
    ell('ValveBody', (0.150, 0, 0), (0.060, 0.067, 0.067), I3, 'Brass')
    cyl('ValveStem', (0.150, 0, 0.028), (0.150, 0, 0.047), 0.0075, 'Steel')
    cyl('ValveNut', (0.150, 0, 0.045), (0.150, 0, 0.053), 0.0068, 'Steel')
    PIVOTS['Valve'] = (V((0.150, 0, 0.052)), I3)
    bar('ValveLever', (0.152, 0.0016, 0.053), (0.104, -0.032, 0.056), 0.017, 0.0048, 'Steel', 'Valve')
    bar('ValveGrip', (0.106, -0.0306, 0.056), (0.082, -0.054, 0.0572), 0.021, 0.011, 'Red', 'Valve')
    c0 = MG @ V((0.168, -0.012, -0.028))
    hp = F.crs([tuple(c0), (-0.226, -0.030, -0.028), (-0.19, -0.026, 0.010), (-0.12, -0.0215, 0.0165),
                (-0.05, -0.0215, 0.0165), (0.02, -0.024, 0.0175), (0.050, -0.030, 0.026), (0.068, -0.035, 0.038)], 6)
    tube_path('BrakeCable', resample(hp, 7), 0.0036, 'Black', joints=False)
    cyl('CableWire', hp[-1], V((0.086, -0.050, 0.057)), 0.0012, 'Chrome')

    # --- file-handle foregrip on a bent strap -----------------------------------------------
    top, d = F.handle_frame()
    FG = F.FG_X
    cylx('ForeGripStrap', FG - 0.011, FG + 0.011, PIPE_R + 0.0032, 'Steel')
    for s in (-1, 1):
        block('ForeGripLeg', (FG, s * 0.0062, -0.037), (0.021, 0.0032, 0.030), I3, 'Steel')
    cyl('ForeGripBolt', (FG, -0.012, -0.040), (FG, 0.016, -0.040), 0.0042, 'Steel', up=(1, 0, 0))
    cyl('ForeGripFerrule', top, top + d * 0.014, 0.0135, 'Steel')
    cyl('ForeGrip', top + d * 0.012, top + d * 0.128, 0.0172, 'Wood')
    ell('ForeGripEnd', top + d * 0.128, (0.026, 0.032, 0.032), frame(d), 'Wood')
    cyl('ForeGripBand', top + d * 0.093, top + d * 0.103, 0.0188, 'Steel')
    cyl('Tape', top + d * 0.014, top + d * 0.044, 0.0158, 'Tape')

    # --- barrel, shroud (drilled), clamps, muzzle, pilot burner -----------------------------
    cylx('Barrel', 0.200, 0.540, 0.022, 'Steel')
    cylx('ShroudPlate', 0.214, 0.2255, 0.0548, 'Steel')
    cylx('Shroud', 0.2255, 0.4945, SHR_R, 'Shroud')
    cylx('ShroudPlate', 0.4945, 0.5055, 0.0548, 'Steel')
    ear = V((0, 0.25, 1)).normalized()
    for xb in F.bottle_band_world_x():
        cylx('ShroudClamp', xb - 0.010, xb + 0.010, SHR_R + 0.0035, 'Steel')
        block('ShroudClampEar', V((xb, 0, 0)) + ear * (SHR_R + 0.011), (0.020, 0.018, 0.010),
              look((0, -ear.z, ear.y), ear), 'Steel')
    for (x, a, r) in F.HOLES:
        dvec = V((0, math.cos(a), math.sin(a)))
        cyl('Hole', V((x, 0, 0)) + dvec * (SHR_R - 0.0012), V((x, 0, 0)) + dvec * (SHR_R + 0.0009), r, 'Hole',
            'Holes', up=(1, 0, 0))
    # muzzle: reducer (two steps), tip tube, slash cut (a wedge), sooty bore on the cut
    cylx('Reducer', 0.5055, 0.5235, 0.0495, 'Muzzle')
    cylx('Reducer', 0.5235, 0.540, 0.0405, 'Muzzle')
    cylx('Tip', 0.536, 0.605, 0.0338, 'Muzzle')
    wedge_axes = Matrix(((0, 0, -1), (1, 0, 0), (0, -1, 0)))   # local X = +Y, Y = -Z, Z = -X
    add('TipSlash', 'Wedge', (0.630, 0, 0), wedge_axes, (0.0640, 0.0676, 0.050), 'Muzzle')
    n = V((1, 0, -0.75)).normalized()
    ell('TipBore', V((0.630, 0, 0)) + n * 0.0012, (0.0010, 0.0524, 0.0656), frame(n, (0, 1, 0)), 'Soot')
    ell('TipLip', V((0.630, 0, 0)) + n * 0.0004, (0.0010, 0.0630, 0.0790), frame(n, (0, 1, 0)), 'Lip')
    # pilot burner on its welded tab
    tab = Matrix.Rotation(math.radians(-25), 3, 'Y')
    block('PilotTab', (0.527, 0, -0.050), (0.018, 0.0045, 0.030), tab, 'Steel')
    p0, p1 = V((0.522, 0, -0.064)), V((0.600, 0, -0.058))
    cyl('PilotTube', p0, p1, 0.0062, 'Steel')
    cyl('PilotCollar', p0.lerp(p1, 0.25), p0.lerp(p1, 0.25) + (p1 - p0).normalized() * 0.010, 0.0078, 'Brass')
    tip_dir = V((math.cos(math.radians(24)), 0, math.sin(math.radians(24))))
    cyl('PilotJet', p1 - (p1 - p0).normalized() * 0.003, p1 + tip_dir * 0.011, 0.0052, 'Brass')
    ftip = p1 + tip_dir * 0.011

    # --- the bottle (right flank), collar, valve + handwheel (moves), regulator, gauge ------
    def b(x, y=0.0, z=0.0):
        return MB @ V((x, y, z))
    bax = MB3 @ V((1, 0, 0))
    cyl('Tank', b(-0.125), b(0.125), F.TANK_R, 'Olive')
    for x in (-0.125, 0.125):
        ell('TankDome', b(x), (0.096, 2 * F.TANK_R, 2 * F.TANK_R), MB3, 'Olive')
    cyl('TankFoot', b(0.150), b(0.190), 0.066, 'Collar')
    cyl('TankCollar', b(-0.222), b(-0.165), 0.0595, 'Collar')
    for xl in F.TANK_BANDS:
        cyl('TankBand', b(xl - 0.011), b(xl + 0.011), F.TANK_R + 0.0045, 'Steel')
    vax = MB3 @ V((-1, 0, 0))
    cyl('TankValve', b(-0.171), b(-0.206), 0.0135, 'Brass')
    cyl('TankValveHex', b(-0.180), b(-0.191), 0.0185, 'Brass')
    out_dir = MB3 @ V((0, -1, 0))
    cyl('TankOutlet', b(-0.192), b(-0.192) + out_dir * 0.064, 0.0068, 'Brass')
    wc = b(-0.219)
    PIVOTS['Wheel'] = (wc, frame(vax))
    cyl('WheelHub', wc - vax * 0.004, wc + vax * 0.005, 0.0065, 'Red', 'Wheel')
    fw = frame(vax)
    wy, wz = fw.col[1], fw.col[2]
    for k in range(6):
        a0, a1 = math.tau * k / 6, math.tau * (k + 1) / 6
        q0 = wc + (wy * math.cos(a0) + wz * math.sin(a0)) * 0.020
        q1 = wc + (wy * math.cos(a1) + wz * math.sin(a1)) * 0.020
        cyl('WheelRim', q0, q1, 0.0040, 'Red', 'Wheel')
    for k in range(3):
        a = math.tau * k / 3 + 0.4
        cyl('WheelSpoke', wc, wc + (wy * math.cos(a) + wz * math.sin(a)) * 0.020, 0.0028, 'Red', 'Wheel')
    up = V((0, 0, 1))
    fwd = MB3 @ V((1, 0, 0))
    RC = b(-0.192) + out_dir * 0.080
    cyl('Regulator', RC - out_dir * 0.012, RC + out_dir * 0.012, 0.0335, 'Zinc')
    cyl('RegulatorRim', RC - out_dir * 0.001, RC + out_dir * 0.004, 0.0370, 'Zinc')
    cyl('RegulatorKnob', RC + out_dir * 0.012, RC + out_dir * 0.030, 0.012, 'Black')
    cyl('RegulatorInlet', RC - out_dir * 0.020, RC - out_dir * 0.010, 0.0125, 'Brass')
    ob = RC + up * 0.030 - out_dir * 0.004
    cyl('RegulatorOutlet', ob, ob + up * 0.020, 0.0072, 'Brass')
    pt = RC + fwd * 0.030 - out_dir * 0.004
    cyl('NeedleValve', pt, pt + fwd * 0.016, 0.0050, 'Brass')
    cyl('NeedleKnob', pt + fwd * 0.012, pt + fwd * 0.012 + up * 0.010, 0.0045, 'Brass')
    gs = RC + (-fwd + up).normalized() * 0.031 - out_dir * 0.004
    gdir = (-fwd * 0.6 + up).normalized()
    cyl('GaugeStem', gs, gs + gdir * 0.024, 0.0042, 'Brass')
    gc = gs + gdir * 0.034
    face_n = (out_dir * 0.85 + up * 0.25).normalized()
    cyl('GaugeCase', gc - face_n * 0.010, gc + face_n * 0.0065, 0.0215, 'Brass')
    cyl('GaugeFace', gc + face_n * 0.0060, gc + face_n * 0.0072, 0.0180, 'Face', 'Face')
    gu = (up - face_n * up.dot(face_n)).normalized()
    gr = face_n.cross(gu)
    # needle pivot: X = gr, Y = gu, Z = -face_n; the needle along local X turned by the dial angle
    nax = Matrix((gr, gu, -face_n)).transposed()
    npv = gc + face_n * 0.0082
    PIVOTS['Needle'] = (npv, nax)
    block('Needle', npv + gr * 0.0062, (0.0160, 0.0012, 0.0006), nax, 'Black', 'Needle')
    for k in (9, 10):
        a = math.radians(225 - 27 * k)
        dv = gr * math.cos(a) + gu * math.sin(a)
        block('GaugeRed', gc + face_n * 0.0074 + dv * 0.0148, (0.0050, 0.0035, 0.0006),
              Matrix((dv, dv.cross(face_n).normalized(), -face_n)).transposed(), 'Red', 'Face')

    # rail: stubs from the shroud clamps, an angle iron along the bottle
    rail = []
    for xl in F.TANK_BANDS:
        Pk = F.bottle_axis_pt(xl)
        Sk = V((Pk.x, 0, 0))
        dvec = (Sk - Pk).normalized()
        Rk = Sk - dvec * (SHR_R + 0.0035 + 0.017)
        a0 = Sk - dvec * (SHR_R + 0.0035)
        tk = V((1, 0, 0)).cross(dvec).normalized()
        block('RailStub', (a0 + Rk) / 2, (0.020, 0.010, (Rk - a0).length + 0.004),
              Matrix((V((1, 0, 0)), tk, -dvec)).transposed(), 'Steel')
        ear_len = (Rk - Pk).length - (F.TANK_R + 0.0058)
        e0 = Pk + dvec * (F.TANK_R + 0.004)
        bar('BandEar', e0, e0 + dvec * (ear_len + 0.006), 0.014, 0.022, 'Steel', up=bax)
        rail.append((Pk, Rk, dvec))
    (P0, R0, d0), (P1, R1, d1) = rail
    x0, x1 = R0 - (R1 - R0).normalized() * 0.03, R1 + (R1 - R0).normalized() * 0.03
    dm = ((d0 + d1) / 2).normalized()
    bar('Rail', x0, x1, 0.026, 0.0035, 'Steel', up=(x1 - x0).normalized().cross(dm))
    tt = (x1 - x0).normalized().cross(dm).normalized()
    bar('Rail', x0 + dm * 0.0115 + tt * 0.010, x1 + dm * 0.0115 + tt * 0.010, 0.020, 0.0035, 'Steel', up=dm)

    # short hose regulator -> T, copper pilot line along the bottle to the burner
    hb = ob + up * 0.020
    tee = V((0.085, -0.068, 0.0))
    hose = F.crs([hb, hb + up * 0.014, hb + up * 0.034 + V((-0.006, 0.004, 0)), (0.12, -0.15, 0.016),
                  (0.10, -0.112, 0.012), tee + V((0.0, -0.030, 0.0)), tee], 6)
    tube_path('Hose', resample(hose, 6), 0.0118, 'Hose')
    a_line = math.radians(128)
    rr = F.TANK_R + 0.0085

    def on_bottle(xl):
        return MB @ V((xl, rr * math.cos(a_line), rr * math.sin(a_line)))
    nv = pt + fwd * 0.016
    line = F.crs([nv, nv + fwd * 0.012 + up * 0.004, on_bottle(-0.120), on_bottle(F.TANK_BANDS[0]), on_bottle(0.0),
                  on_bottle(F.TANK_BANDS[1]), on_bottle(0.150), V((0.505, -0.060, -0.075)), V((0.512, -0.012, -0.068)),
                  V((0.522, 0.0, -0.064))], 6)
    tube_path('PilotLine', resample(line, 9), 0.0032, 'Copper', joints=False)

    # --- heat: the finisher's red-hot shells (hidden until heat is high), the mesh's core ---
    cylx('HotShroud', 0.2245, 0.4955, SHR_R + 0.0012, 'Glow', 'Shell')
    cylx('HotReducer', 0.5055, 0.5235, 0.0505, 'Glow', 'Shell')
    cylx('HotTip', 0.534, 0.606, 0.0348, 'Glow', 'Shell')
    cylx('Core', 0.2265, 0.4935, 0.0455, 'Glow', 'Core')

    # --- points the animations and effects use -----------------------------------------------
    hr, hf = F.hand_points()
    POINTS['Muzzle'] = (V((0.636, 0, 0)), look((1, 0, 0)))
    POINTS['PilotLight'] = (ftip, look(tip_dir))
    POINTS['GripR'] = (hr, look(MG3 @ V((1, 0, 0))))
    POINTS['GripL'] = (hf, look(d, (1, 0, 0)))
    POINTS['Stock'] = (V((-0.556, 0, -0.064)), look((-1, 0, 0)))
    POINTS['ShroudGlow'] = (V((0.36, 0, 0)), look((1, 0, 0)))
    POINTS['GaugeFace'] = (gc + face_n * 0.008, look(face_n))
    POINTS['Regulator'] = (RC + up * 0.035, look(up, (1, 0, 0)))
    POINTS['BackMount'] = (V((0.0, F.PIPE_R + 0.004, 0)), look((1, 0, 0)))


# --------------------------------------------------------------------------------------
# game space, the grip and sling welds
# --------------------------------------------------------------------------------------
def to_game(pos, axes):
    return C @ V(pos) / S, C @ axes


def solve_grip():
    """The validated hold (flamethrower.solve_hold) as the gun's CFrame in Right Arm space."""
    W, R, Fh, yaw = F.solve_hold()
    s = 0.28
    piv = V((0, -1.5 * s, 3.75 * s))
    q = V((0, 0, -1)).rotation_difference((R - piv).normalized())
    arm = Matrix.Translation(piv) @ q.to_matrix().to_4x4() @ Matrix.Translation((0, 0, -0.75 * s))
    rel = arm.inverted() @ W
    # (a relative transform: both of its spaces change to game axes)
    return C @ rel.translation / S, C @ rel.to_3x3() @ C.transposed(), (W, R, Fh, yaw)


def sling():
    """Slung across the back: grip behind the right hip, muzzle up behind the left shoulder,
    the bottle (gun's right flank) facing out.  Torso space, game axes (back = +Z)."""
    ang = math.radians(57)
    fwd = V((-math.cos(ang), math.sin(ang), 0))       # gun forward, in the torso's plane
    right = V((0, 0, 1))                              # gun's right flank (bottle) faces out
    # game gun axes: X = right, Y = up, Z = back (-fwd); right-handed: X x Y = Z
    Z = -fwd
    X = right
    Y = Z.cross(X)
    axes = Matrix((X, Y, Z)).transposed()
    hr, _ = F.hand_points()
    hr_g = C @ hr / S
    grip_at = V((0.86, -1.02, 0.5 + 0.21))           # just behind the right hip
    origin = grip_at - axes @ hr_g
    return origin, axes


# --------------------------------------------------------------------------------------
# Luau
# --------------------------------------------------------------------------------------
def f(v):
    s = '%.4f' % v
    s = s.rstrip('0').rstrip('.') if '.' in s else s
    return '0' if s in ('-0', '') else s


def cf(pos, axes):
    vals = [pos.x, pos.y, pos.z] + [axes[i][j] for i in range(3) for j in range(3)]
    if all(abs(axes[i][j] - (1 if i == j else 0)) < 1e-6 for i in range(3) for j in range(3)):
        return 'CFrame.new(%s, %s, %s)' % tuple(f(v) for v in vals[:3])
    return 'CFrame.new(%s)' % ', '.join(f(v) for v in vals)


def v3(v):
    return 'Vector3.new(%s, %s, %s)' % (f(v.x), f(v.y), f(v.z))


def fbx_centres(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    out = {}
    for ob in bpy.context.scene.objects:
        if ob.type != 'MESH':
            continue
        cs = [ob.matrix_world @ V(c) for c in ob.bound_box]
        lo = V([min(c[i] for c in cs) for i in range(3)])
        hi = V([max(c[i] for c in cs) for i in range(3)])
        out[ob.name.split('.')[0]] = (lo + hi) / 2
    return out


def write_luau(grip, sling_cf, centres):
    L = []
    L.append('--!strict')
    L.append('-- FlamethrowerShape: GENERATED by tools/pyro/flamethrower_parts.py (do not edit by hand).')
    L.append('-- The Pyromaniac\'s flamethrower from Roblox primitives, read from the validated model')
    L.append('-- (tools/pyro/flamethrower.py). Gun space, studs: -Z muzzle, +Y up, +X right (the bottle side).')
    L.append('-- Shapes: "Cyl" (a Cylinder part, axis X), "Block", "Wedge", "Sphere" (a sphere mesh filling')
    L.append('-- the part). Groups: "Body" (rigid), "Trigger" / "Valve" / "Wheel" / "Needle" (turn about their')
    L.append('-- pivot), "Holes" (glow with the heat), "Face" (gauge dial, kept on the imported mesh too),')
    L.append('-- "Shell" (red-hot skin, finisher), "Core" (glow inside the imported shroud only).')
    L.append('')
    L.append('export type PartDef = {')
    L.append('\tname: string,')
    L.append('\tshape: string,')
    L.append('\tcf: CFrame,')
    L.append('\tsize: Vector3,')
    L.append('\tpaint: string,')
    L.append('\tgroup: string,')
    L.append('}')
    L.append('')
    L.append('local function p(name: string, shape: string, cf: CFrame, size: Vector3, paint: string, group: string): PartDef')
    L.append('\treturn { name = name, shape = shape, cf = cf, size = size, paint = paint, group = group }')
    L.append('end')
    L.append('')
    L.append('export type Paint = { color: Color3, material: Enum.Material, shine: number }')
    L.append('')
    L.append('local function paint(r: number, g: number, b: number, material: Enum.Material, shine: number): Paint')
    L.append('\treturn { color = Color3.fromRGB(r, g, b), material = material, shine = shine }')
    L.append('end')
    L.append('')
    L.append('local Shape = {}')
    L.append('')
    L.append('-- Colour, material, reflectance of each paint.')
    L.append('Shape.PAINTS = {')
    for k, (rgb, mat, refl) in PAINTS.items():
        L.append('\t%s = paint(%d, %d, %d, Enum.Material.%s, %s),' % (k, *rgb, mat, f(refl)))
    L.append('} :: { [string]: Paint }')
    L.append('')
    L.append('Shape.PARTS = {')
    for pd in PARTS:
        pos, axes = to_game(pd['pos'], pd['axes'])
        L.append('\tp("%s", "%s", %s, %s, "%s", "%s"),' % (pd['name'], pd['shape'], cf(pos, axes), v3(pd['size'] / S),
                                                         pd['paint'], pd['group']))
    L.append('}')
    L.append('')
    L.append('-- Where each moving bit turns (its parts are placed in gun space, like the others).')
    L.append('Shape.PIVOTS = {')
    for k, (pos, axes) in PIVOTS.items():
        gp, ga = to_game(pos, axes)
        L.append('\t%s = %s,' % (k, cf(gp, ga)))
    L.append('} :: { [string]: CFrame }')
    L.append('')
    L.append('-- Points (attachments) the clips and effects use; LookVector = where it points.')
    L.append('Shape.POINTS = {')
    for k, (pos, axes) in POINTS.items():
        gp, ga = to_game(pos, axes)
        L.append('\t%s = %s,' % (k, cf(gp, ga)))
    L.append('} :: { [string]: CFrame }')
    L.append('')
    L.append('-- The gun in Right Arm space in the validated hip-fire hold (solve_hold), and in Torso')
    L.append('-- space slung across the back.')
    L.append('Shape.GRIP = %s' % cf(*grip))
    L.append('Shape.SLING = %s' % cf(*sling_cf))
    L.append('')
    L.append('-- The imported FBX (assets/pyro/Flamethrower.fbx): each part\'s paint, the moving bit it')
    L.append('-- belongs to, and the centres (gun space) of the parts used to fit it.')
    L.append('Shape.MESH_PAINT = {')
    for k in sorted(MESH_PAINT):
        L.append('\t%s = "%s",' % (k, MESH_PAINT[k]))
    L.append('} :: { [string]: string }')
    L.append('Shape.MESH_GROUP = {')
    for k in sorted(MESH_GROUP):
        L.append('\t%s = "%s",' % (k, MESH_GROUP[k]))
    L.append('} :: { [string]: string }')
    L.append('Shape.MESH_FIT = {')
    for k in FIT_PARTS:
        L.append('\t{ name = "%s", centre = %s },' % (k, v3(C @ centres[k] / S)))
    L.append('} :: { { name: string, centre: Vector3 } }')
    L.append('')
    L.append('return table.freeze(Shape)')
    with open(OUT_LUAU, 'w') as fh:
        fh.write('\n'.join(L) + '\n')
    print('WROTE', OUT_LUAU, len(PARTS), 'parts', flush=True)


# --------------------------------------------------------------------------------------
# preview (Blender rebuild of exactly the Luau data, back in model space)
# --------------------------------------------------------------------------------------
def srgb(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


PMAT = {}


def paint_mat(key, heat=0.0):
    name = '%s_%.2f' % (key, heat)
    if name in PMAT:
        return PMAT[name]
    rgb, mat, refl = PAINTS[key]
    m = bpy.data.materials.new('P_' + name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes['Principled BSDF']
    col = [srgb(v) for v in rgb] + [1]
    bsdf.inputs['Base Color'].default_value = col
    rough = {'Metal': 0.45, 'SmoothPlastic': 0.25, 'Wood': 0.7, 'Fabric': 0.95, 'Rubber': 0.8, 'Neon': 0.5}[mat]
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = 0.55 if mat == 'Metal' else 0.0
    if mat == 'Neon' or (key == 'Hole' and heat > 0):
        c = [srgb(v) for v in (rgb if key != 'Hole' else (255, 120, 40))] + [1]
        bsdf.inputs['Emission Color'].default_value = c
        bsdf.inputs['Emission Strength'].default_value = 6.0 * max(heat, 0.2)
    PMAT[name] = m
    return m


def unit_mesh(shape):
    bm = bmesh.new()
    if shape == 'Block':
        bmesh.ops.create_cube(bm, size=1.0)
    elif shape == 'Cyl':
        bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.5, radius2=0.5, depth=1.0,
                              matrix=Matrix.Rotation(math.radians(90), 4, 'Y'))
    elif shape == 'Sphere':
        bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=0.5)
    elif shape == 'Wedge':
        # Roblox wedge: full bottom (y=-.5) and back (z=+.5), slope up to the top-back edge
        vs = [bm.verts.new(p) for p in ((-.5, -.5, -.5), (.5, -.5, -.5), (.5, -.5, .5), (-.5, -.5, .5),
                                        (-.5, .5, .5), (.5, .5, .5))]
        for fc in ((0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)):
            bm.faces.new([vs[i] for i in fc])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('U' + shape)
    bm.to_mesh(me)
    bm.free()
    if shape in ('Cyl', 'Sphere'):
        me.shade_smooth()
        try:
            me.set_sharp_from_angle(angle=math.radians(40))
        except Exception:
            pass
    return me


UNITS = {}


def build_preview(col, heat=0.0, hide=('Shell', 'Core')):
    """The Luau parts (game space) under an empty that maps them back to model space."""
    root = bpy.data.objects.new('GunRoot', None)
    col.objects.link(root)
    back = (C.inverted() * S).to_4x4()
    root.matrix_world = back
    objs = []
    for pd in PARTS:
        if pd['group'] in hide:
            continue
        if pd['group'] == 'Shell' and heat < 0.8:
            continue
        shape = pd['shape']
        if shape not in UNITS:
            UNITS[shape] = unit_mesh(shape)
        pos, axes = to_game(pd['pos'], pd['axes'])
        size = pd['size'] / S
        if shape == 'Cyl':
            dmin = min(size.y, size.z)
            size = V((size.x, dmin, dmin))
        me = UNITS[shape].copy()
        me.materials.append(paint_mat(pd['paint'], heat))
        ob = bpy.data.objects.new(pd['name'], me)
        col.objects.link(ob)
        M = axes.to_4x4()
        M.translation = pos
        ob.matrix_basis = M @ Matrix.Diagonal((size.x, size.y, size.z, 1))
        ob.parent = root
        if pd['group'] == 'Shell':
            ob.data.materials[0] = shell_mat(heat)
        objs.append(ob)
    return root, objs


def shell_mat(heat):
    m = bpy.data.materials.new('Shell')
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (srgb(190), srgb(50), srgb(15), 1)
    bsdf.inputs['Emission Color'].default_value = (srgb(190), srgb(50), srgb(15), 1)
    bsdf.inputs['Emission Strength'].default_value = 3.0
    bsdf.inputs['Alpha'].default_value = 0.55
    try:
        m.blend_method = 'BLEND'
    except Exception:
        pass
    return m


def pilot_flame(col, root, big=False):
    pos, axes = POINTS['PilotLight']
    gp, ga = to_game(pos, axes)
    bm = bmesh.new()
    k = 1.8 if big else 1.0
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.006 * k / S, radius2=0.0, depth=0.05 * k / S,
                          matrix=Matrix.Translation((0, 0, -0.025 * k / S)) @ Matrix.Rotation(math.pi, 4, 'X'))
    me = bpy.data.meshes.new('Pilot')
    bm.to_mesh(me)
    bm.free()
    m = bpy.data.materials.new('PilotBlue')
    m.use_nodes = True
    b_ = m.node_tree.nodes['Principled BSDF']
    b_.inputs['Emission Color'].default_value = (0.25, 0.45, 1.0, 1)
    b_.inputs['Emission Strength'].default_value = 25.0
    b_.inputs['Base Color'].default_value = (0.2, 0.4, 1.0, 1)
    me.materials.append(m)
    ob = bpy.data.objects.new('PilotFlame', me)
    col.objects.link(ob)
    M = ga.to_4x4()
    M.translation = gp
    ob.matrix_basis = M
    ob.parent = root
    return ob


def setup(args):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    F.MAT.clear()
    F.PARTS.clear()
    col = bpy.context.scene.collection

    class A:
        pass
    a = A()
    a.samples = 12 if args.quick else 48
    a.res = (800, 500) if args.quick else (1600, 1000)
    F.setup_scene(a)
    return col


def render_previews(args, centres_ok):
    out = args.render
    os.makedirs(out, exist_ok=True)
    from PIL import Image, ImageDraw
    col = setup(args)
    sc = bpy.context.scene
    valid = F.build_all(col, F.make_decal(os.path.join(out, '_stencil.png')))
    valid_objs = [o for n, o in valid.items() if n not in ('ValveBall',)]
    valid['ValveBall'].hide_render = True
    rootP, prim = build_preview(col)
    pil = pilot_flame(col, rootP)
    bpy.context.view_layer.update()
    lo, hi = F.world_bbox([o for o in valid_objs if o.name != 'PilotFlame'])
    floor = F.add_floor(col, F.FLOOR_Z)
    rig = F.Rig(col)
    rig.glow.location = V((0.64, 0, -0.046))
    shots = [('side', dict(bbox=(lo, hi), view_dir=(0, -1, 0.02), ortho=True, margin=1.08)),
             ('three_quarter', dict(bbox=(lo, hi), view_dir=(0.8, -0.85, 0.40), lens=60, margin=1.06)),
             ('three_quarter_back', dict(bbox=(lo, hi), view_dir=(-0.8, -0.75, 0.42), lens=60, margin=1.06)),
             ('top', dict(bbox=(lo, hi), view_dir=(0, -0.001, 1), ortho=True, margin=1.10, up=(0, 1, 0),
                          cam_lights=True))]
    pairs = []
    for tag, kw in shots:
        rig.frame(**kw)
        for which, show, hidden in (('validated', valid_objs, prim + [pil]), ('roblox', prim + [pil], valid_objs)):
            for o in show:
                o.hide_render = False
            for o in hidden:
                o.hide_render = True
            p = os.path.join(out, 'cmp_%s_%s.png' % (tag, which))
            F.render(p)
        pairs.append((tag, os.path.join(out, 'cmp_%s_validated.png' % tag), os.path.join(out, 'cmp_%s_roblox.png' % tag)))
    # hot: Awakened glow through the holes, then the finisher's red-hot shells
    for o in valid_objs:
        o.hide_render = True
    for o in prim + [pil]:
        bpy.data.objects.remove(o)
    bpy.data.objects.remove(rootP)
    hots = []
    for heat in (0.55, 1.0):
        rootH, primH = build_preview(col, heat=heat, hide=('Core',))
        pilH = pilot_flame(col, rootH, big=True)
        rig.frame(**dict(shots[1][1]))
        p = os.path.join(out, 'hot_%d.png' % int(heat * 100))
        F.render(p)
        hots.append(p)
        for o in primH + [pilH]:
            bpy.data.objects.remove(o)
        bpy.data.objects.remove(rootH)
    # on an R6 dummy: slung on the back, and in the validated hold (the Right Arm weld)
    dummy, arms = F.build_dummy(col)
    floor.location.z = 0.0
    grip_pos, grip_axes, (W, Rh, Fh, yaw) = GRIP
    F.pose_arm(arms['R'], Rh)
    F.pose_arm(arms['L'], Fh)
    bpy.context.view_layer.update()
    # the gun from the GRIP weld (arm world x GRIP), not from W: checks the weld itself
    s = 0.28
    armR = arms['R']
    armW = armR.matrix_world @ Matrix.Translation((0, 0, -0.75 * s))
    gripM = (C.inverted() @ grip_axes @ C).to_4x4()
    gripM.translation = C.inverted() @ grip_pos * S
    gunW = armW @ gripM
    rootG, primG = build_preview(col)
    pilG = pilot_flame(col, rootG)
    rootG.matrix_world = gunW @ rootG.matrix_world
    bpy.context.view_layer.update()
    lo3, hi3 = F.world_bbox(dummy + primG)
    lo3.z = 0.0
    rig.frame(bbox=(lo3, hi3), view_dir=V((0.75, -1.0, 0.70)), lens=50, margin=1.06, light_scale=1.3)
    held = os.path.join(out, 'r6_hold.png')
    F.render(held)
    err = (gunW @ F.hand_points()[0] - Rh).length
    print('GRIP check: grip point vs right hand %.4f m' % err, flush=True)
    # slung: arms down, gun on the torso by SLING (torso centre at z = 3 s; torso space game axes)
    for o in primG + [pilG]:
        bpy.data.objects.remove(o)
    bpy.data.objects.remove(rootG)
    for arm in arms.values():
        arm.rotation_mode = 'QUATERNION'
        arm.rotation_quaternion = (1, 0, 0, 0)
    sp, sa = SLING
    torsoW = Matrix.Translation((0, 0, 3 * s)) @ (C.inverted()).to_4x4()   # torso: game axes -> model axes
    slingM = sa.to_4x4()
    slingM.translation = sp
    rootS, primS = build_preview(col)
    rootS.matrix_world = torsoW @ Matrix.Diagonal((s, s, s, 1)) @ slingM
    bpy.context.view_layer.update()
    lo4, hi4 = F.world_bbox(dummy + primS)
    lo4.z = 0.0
    slung = []
    for tag, vd in (('back', (-1.0, 0.45, 0.35)), ('side', (0.2, -1.0, 0.25)), ('front', (1.0, -0.5, 0.3))):
        rig.frame(bbox=(lo4, hi4), view_dir=V(vd), lens=50, margin=1.06, light_scale=1.3)
        p = os.path.join(out, 'r6_sling_%s.png' % tag)
        F.render(p)
        slung.append(p)

    # sheets
    W0, H0 = Image.open(pairs[0][1]).size
    sheet = Image.new('RGB', (W0 * 2, H0 * len(pairs) + 40 * len(pairs)), (12, 12, 14))
    d = ImageDraw.Draw(sheet)
    for i, (tag, a, b) in enumerate(pairs):
        y = i * (H0 + 40)
        d.text((10, y + 12), '%s   left: validated model   right: Roblox primitives (%d parts)' % (tag, len(PARTS)),
               fill=(220, 220, 220))
        sheet.paste(Image.open(a), (0, y + 40))
        sheet.paste(Image.open(b), (W0, y + 40))
    sheet.save(os.path.join(out, 'compare_sheet.png'))
    imgs = hots + [held] + slung
    W1, H1 = Image.open(imgs[0]).size
    s2 = Image.new('RGB', (W1 * 2, H1 * 3), (12, 12, 14))
    for i, p in enumerate(imgs):
        s2.paste(Image.open(p), ((i % 2) * W1, (i // 2) * H1))
    s2.save(os.path.join(out, 'states_sheet.png'))
    print('SHEETS', out, flush=True)


GRIP = None
SLING = None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--render', default=None)
    ap.add_argument('--quick', action='store_true')
    ap.add_argument('--fbx', default=os.path.join(ROOT, 'assets', 'pyro', 'Flamethrower.fbx'))
    args = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
    global GRIP, SLING
    centres = fbx_centres(args.fbx)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    F.SEGQ = 0.3
    F.PARTS.clear()
    F.build_parts()      # (fills F.HOLES: the same drilled holes)
    for prt in F.PARTS.values():
        prt.bm.free()
    F.PARTS.clear()
    F.SEGQ = 1.0
    build()
    GRIP = solve_grip()
    SLING = sling()
    print('PARTS', len(PARTS), {g: sum(1 for p in PARTS if p['group'] == g) for g in {p['group'] for p in PARTS}},
          flush=True)
    if args.write:
        write_luau(GRIP[:2], SLING, centres)
    if args.render:
        render_previews(args, centres)


if __name__ == '__main__':
    main()
