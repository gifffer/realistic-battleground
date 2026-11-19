#!/usr/bin/env python3
"""Improvised flamethrower for the Pyromaniac's finisher (look-dev only, no game code).

Builds the model from code (bmesh), gives it procedural PBR-ish materials, renders a set of
studio views (front, profile, 3/4, top, close-ups, exploded, cutaway, R6 scale dummy), writes a
contact sheet, saves the .blend and exports a Roblox-friendly FBX (separate named parts,
no flame, no dummy).

Design (original, improvised, gritty):
  * rear grip = a red fuel-pump nozzle (painted, chipped) with its trigger lever, guard,
    a coil spring on the spout and a ribbed rubber boot where the hose enters;
  * a hose loops from the boot under the gun to a regulator bolted on a horizontal
    propane bottle hung under the feed pipe (two strap bands, a flat rail, U-bolts);
  * the bottle valve sits inside the bottle's guard collar, a pressure gauge sits on the
    regulator, and a thin copper line feeds a pilot burner under the muzzle (blue flame);
  * the feed pipe runs into a blackened barrel inside a slotted heat shroud, a strap-on
    front grip wrapped in tape, and a flared, scorched, hand-rolled muzzle bell.

Axes: +X forward (muzzle), +Z up, metres.  1 stud = 0.28 m.

Usage:
  /home/user/z-anatomy/venv/bin/python -I tools/pyro/flamethrower.py --out DIR \
      [--fbx assets/pyro/Flamethrower.fbx] [--samples 48] [--res 1600x1000] [--only 01,02] [--quick]
"""
import argparse
import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

TAU = 2 * math.pi
V = Vector
SEGQ = 1.0   # segment-count scale: 1.0 for renders, lower for the game FBX


def q(segs, lo=6):
    return segs if segs <= lo else max(lo, int(round(segs * SEGQ)))

# --------------------------------------------------------------------------------------
# geometry helpers (all write into a bmesh; every helper tags its faces with a material index)
# --------------------------------------------------------------------------------------


def frame_x(origin, xdir, up=(0, 0, 1)):
    """Matrix whose local X is xdir, placed at origin."""
    X = V(xdir).normalized()
    up = V(up)
    if abs(X.dot(up)) > 0.95:
        up = V((0, 1, 0)) if abs(X.y) < 0.95 else V((1, 0, 0))
    Y = up.cross(X).normalized()
    Z = X.cross(Y)
    M = Matrix((X, Y, Z)).transposed().to_4x4()
    M.translation = V(origin)
    return M


def _tag(bm, n0, mi):
    bm.faces.ensure_lookup_table()
    for f in bm.faces[n0:]:
        f.material_index = mi


def lathe(bm, prof, segs=24, M=None, closed=False, th=None, pert=None, mi=0):
    """Revolve a profile [(x, r), ...] around local X.  Open profiles go with increasing x;
    closed profiles go clockwise in the (x right, r up) plane - both give outward normals."""
    M = M or Matrix()
    segs = q(segs)
    n0 = len(bm.faces)
    full = th is None
    angs = [TAU * i / segs for i in range(segs)] if full else \
        [th[0] + (th[1] - th[0]) * i / segs for i in range(segs + 1)]
    rings = []
    for x, r in prof:
        if r < 1e-7:
            rings.append([bm.verts.new(M @ V((x, 0, 0)))])
            continue
        ring = []
        for a in angs:
            rr = r + (pert(x, r, a) if pert else 0.0)
            ring.append(bm.verts.new(M @ V((x, rr * math.cos(a), rr * math.sin(a)))))
        rings.append(ring)
    pairs = list(zip(rings[:-1], rings[1:]))
    if closed:
        pairs.append((rings[-1], rings[0]))
    m = len(angs)
    K = m if full else m - 1
    for A, B in pairs:
        if len(A) == 1 and len(B) == 1:
            continue
        for j in range(K):
            j1 = (j + 1) % m
            if len(A) == 1:
                bm.faces.new((A[0], B[j1], B[j]))
            elif len(B) == 1:
                bm.faces.new((A[j], A[j1], B[0]))
            else:
                bm.faces.new((A[j], A[j1], B[j1], B[j]))
    _tag(bm, n0, mi)


def cyl(bm, p0, p1, r, segs=12, mi=0, r1=None):
    p0, p1 = V(p0), V(p1)
    L = (p1 - p0).length
    lathe(bm, [(0, 0), (0, r), (L, r if r1 is None else r1), (L, 0)], segs, frame_x(p0, p1 - p0), mi=mi)


def tube(bm, p0, p1, rin, rout, segs=16, mi=0, rings=0):
    p0, p1 = V(p0), V(p1)
    L = (p1 - p0).length
    xs = [L * i / (rings + 1) for i in range(rings + 2)]
    prof = [(0, rin), (0, rout)] + [(x, rout) for x in xs[1:-1]] + [(L, rout), (L, rin)] + \
        [(x, rin) for x in reversed(xs[1:-1])]
    lathe(bm, prof, segs, frame_x(p0, p1 - p0), closed=True, mi=mi)


def box(bm, center, size, R=None, mi=0):
    n0 = len(bm.faces)
    S = Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    Rm = (R.to_4x4() if R is not None else Matrix())
    T = Matrix.Translation(V(center))
    bmesh.ops.create_cube(bm, size=1.0, matrix=T @ Rm @ S)
    _tag(bm, n0, mi)


def crs(pts, k=6):
    """Catmull-Rom resample."""
    P = [V(p) for p in pts]
    k = max(2, int(round(k * SEGQ)))
    out = []
    for i in range(len(P) - 1):
        p0 = P[max(i - 1, 0)]
        p1, p2 = P[i], P[i + 1]
        p3 = P[min(i + 2, len(P) - 1)]
        for s in range(k):
            t = s / k
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
                              (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-1])
    return out


def sweep(bm, pts, r, segs=12, caps=(True, True), rz=None, sq=2.0, mi=0, closed=False, upref=None):
    """Sweep a (super)ellipse along a polyline with parallel-transport frames.
    r = width radius (along the side normal, ~world Y), rz = height radius."""
    segs = q(segs, 4)
    P = [V(p) for p in pts]
    n = len(P)
    rs = list(r) if isinstance(r, (list, tuple)) else [r] * n
    if rz is None:
        rzs = rs
    else:
        rzs = list(rz) if isinstance(rz, (list, tuple)) else [rz] * n
    T = []
    for i in range(n):
        if closed:
            a, b = P[(i - 1) % n], P[(i + 1) % n]
        else:
            a, b = P[max(i - 1, 0)], P[min(i + 1, n - 1)]
        T.append((b - a).normalized())
    ref = V(upref) if upref else (V((0, 1, 0)) if abs(T[0].y) < 0.9 else V((0, 0, 1)))
    N = (ref - T[0] * ref.dot(T[0])).normalized()
    n0 = len(bm.faces)
    rings = []
    for i in range(n):
        if i > 0:
            N = (N - T[i] * N.dot(T[i])).normalized()
        B = T[i].cross(N)
        ring = []
        for j in range(segs):
            a = TAU * j / segs
            c, s = math.cos(a), math.sin(a)
            if sq != 2.0:
                c = math.copysign(abs(c) ** (2 / sq), c)
                s = math.copysign(abs(s) ** (2 / sq), s)
            ring.append(bm.verts.new(P[i] + N * (rs[i] * c) + B * (rzs[i] * s)))
        rings.append(ring)
    pairs = list(zip(rings[:-1], rings[1:]))
    if closed:
        pairs.append((rings[-1], rings[0]))
    for A, Bv in pairs:
        for j in range(segs):
            j1 = (j + 1) % segs
            bm.faces.new((A[j], A[j1], Bv[j1], Bv[j]))
    if not closed:
        if caps[0]:
            bm.faces.new(list(reversed(rings[0])))
        if caps[1]:
            bm.faces.new(rings[-1])
    _tag(bm, n0, mi)


def torus(bm, c, axis, R, r, su=24, sv=6, mi=0, bump=0.0, seed=0):
    M = frame_x(c, axis)
    su = q(su, 8)
    rnd = random.Random(seed)
    pts, rs = [], []
    for i in range(su):
        a = TAU * i / su
        pts.append(M @ V((0, R * math.cos(a), R * math.sin(a))))
        rs.append(r * (1 + bump * (rnd.random() - 0.5) * 2))
    sweep(bm, pts, rs, sv, closed=True, mi=mi)


def hexbolt(bm, p, axis, size=0.006, length=0.008, mi=0, washer=True):
    """Hex head + washer, head facing along axis."""
    p, axis = V(p), V(axis).normalized()
    if washer:
        cyl(bm, p - axis * 0.0006, p + axis * 0.0008, size * 1.35, 12, mi)
    lathe(bm, [(0, 0), (0, size), (length * 0.55, size), (length * 0.55, 0)], 6,
          frame_x(p + axis * 0.0008, axis), mi=mi)
    cyl(bm, p + axis * (0.0008 + length * 0.55), p + axis * (0.0008 + length), size * 0.5, 8, mi)


# --------------------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------------------
MAT = {}


class NB:
    def __init__(self, name):
        self.m = bpy.data.materials.new(name)
        try:
            self.m.use_nodes = True
        except Exception:
            pass
        self.nt = self.m.node_tree
        self.nt.nodes.clear()
        self.out = self.n('ShaderNodeOutputMaterial')
        self.tc = self.n('ShaderNodeTexCoord')
        MAT[name] = self.m

    def n(self, t, inp=None, **attrs):
        node = self.nt.nodes.new(t)
        for k, v in attrs.items():
            setattr(node, k, v)
        for k, v in (inp or {}).items():
            if isinstance(v, bpy.types.NodeSocket):
                self.nt.links.new(v, node.inputs[k])
            else:
                node.inputs[k].default_value = v
        return node

    def l(self, a, b):
        self.nt.links.new(a, b)

    # building blocks ---------------------------------------------------------------
    def obj(self):
        return self.tc.outputs['Object']

    def scaled(self, s):
        """Object coords scaled per axis (stretched noise = scratches / streaks)."""
        vm = self.n('ShaderNodeVectorMath', operation='MULTIPLY')
        self.l(self.obj(), vm.inputs[0])
        vm.inputs[1].default_value = s
        return vm.outputs[0]

    def noise(self, scale, detail=4.0, rough=0.55, vec=None, distort=0.0, w=None):
        nz = self.n('ShaderNodeTexNoise', {'Scale': scale, 'Detail': detail, 'Roughness': rough,
                                           'Distortion': distort})
        if w is not None:
            nz.noise_dimensions = '4D'
            nz.inputs['W'].default_value = w
        self.l(vec if vec is not None else self.obj(), nz.inputs['Vector'])
        return nz.outputs['Fac']

    def ramp(self, fac, a, b, ca=(0, 0, 0, 1), cb=(1, 1, 1, 1)):
        r = self.n('ShaderNodeValToRGB')
        r.color_ramp.elements[0].position = a
        r.color_ramp.elements[0].color = ca
        r.color_ramp.elements[1].position = b
        r.color_ramp.elements[1].color = cb
        self.l(fac, r.inputs['Fac'])
        return r.outputs['Color']

    def mask(self, fac, a, b):
        """smooth 0..1 step of fac between a and b (as a float)."""
        mr = self.n('ShaderNodeMapRange', {'From Min': a, 'From Max': b}, clamp=True,
                    interpolation_type='SMOOTHSTEP')
        self.l(fac, mr.inputs['Value'])
        return mr.outputs['Result']

    def math(self, op, a, b=None, clamp=True):
        m = self.n('ShaderNodeMath', operation=op, use_clamp=clamp)
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, bpy.types.NodeSocket):
                self.l(v, m.inputs[i])
            else:
                m.inputs[i].default_value = v
        return m.outputs[0]

    def mixc(self, fac, a, b):
        mx = self.n('ShaderNodeMix', data_type='RGBA', clamp_factor=True)
        for idx, v in ((0, fac), (6, a), (7, b)):
            if isinstance(v, bpy.types.NodeSocket):
                self.l(v, mx.inputs[idx])
            else:
                mx.inputs[idx].default_value = v if idx else v
        return mx.outputs[2]

    def mixf(self, fac, a, b):
        mx = self.n('ShaderNodeMix', data_type='FLOAT', clamp_factor=True)
        for idx, v in ((0, fac), (2, a), (3, b)):
            if isinstance(v, bpy.types.NodeSocket):
                self.l(v, mx.inputs[idx])
            else:
                mx.inputs[idx].default_value = v
        return mx.outputs[0]

    def axis(self, k):
        sep = self.n('ShaderNodeSeparateXYZ')
        self.l(self.obj(), sep.inputs[0])
        return sep.outputs[k]

    def bump(self, height, strength=0.2, distance=0.002, normal=None):
        b = self.n('ShaderNodeBump', {'Strength': strength, 'Distance': distance})
        self.l(height, b.inputs['Height'])
        if normal is not None:
            self.l(normal, b.inputs['Normal'])
        return b.outputs['Normal']

    def bsdf(self, base, metal, rough, normal=None, extra=None):
        p = self.n('ShaderNodeBsdfPrincipled')
        for k, v in (('Base Color', base), ('Metallic', metal), ('Roughness', rough), ('Normal', normal)):
            if v is None:
                continue
            if isinstance(v, bpy.types.NodeSocket):
                self.l(v, p.inputs[k])
            else:
                p.inputs[k].default_value = v
        for k, v in (extra or {}).items():
            p.inputs[k].default_value = v
        self.l(p.outputs[0], self.out.inputs['Surface'])
        return p


def C(r, g, b):
    return (r, g, b, 1.0)


def build_materials():
    # --- dark gunmetal steel: grime + scratches along the pipe axis -------------------------
    m = NB('SteelDark')
    grime = m.mask(m.noise(14, 8, 0.6), 0.45, 0.75)
    scr = m.mask(m.noise(3, 3, 0.5, vec=m.scaled((6, 160, 160))), 0.66, 0.70)
    pits = m.mask(m.noise(90, 4, 0.7), 0.62, 0.72)
    base = m.mixc(grime, C(0.055, 0.057, 0.062), C(0.03, 0.024, 0.018))
    base = m.mixc(m.math('MULTIPLY', pits, 0.6), base, C(0.09, 0.05, 0.03))
    base = m.mixc(m.math('MULTIPLY', scr, 0.8), base, C(0.32, 0.32, 0.33))
    rough = m.mixf(grime, 0.38, 0.72)
    rough = m.mixf(scr, rough, 0.22)
    nrm = m.bump(m.math('ADD', m.noise(220, 3, 0.6), m.math('MULTIPLY', pits, 0.6), clamp=False), 0.12)
    m.bsdf(base, m.mixf(grime, 0.95, 0.55), rough, nrm)

    # --- blackened / heat-tinted / sooted barrel steel (soot grows towards the muzzle) ------
    m = NB('SteelBurnt')
    x = m.axis(0)
    nz = m.noise(10, 8, 0.65)
    heat = m.ramp(x, 0.12, 0.46, C(0.12, 0.075, 0.04), C(0.05, 0.05, 0.09))   # bronze -> blue tint
    heatmask = m.math('MULTIPLY', m.mask(x, 0.10, 0.20), m.mask(nz, 0.40, 0.70))
    base = m.mixc(m.math('MULTIPLY', heatmask, 0.75), C(0.045, 0.042, 0.04), heat)
    sootx = m.mask(m.math('ADD', x, m.math('MULTIPLY', nz, 0.10, clamp=False), clamp=False), 0.40, 0.60)
    soot = m.math('MAXIMUM', sootx, m.math('MULTIPLY', m.mask(m.noise(5, 6, 0.6), 0.55, 0.8), 0.7))
    base = m.mixc(soot, base, C(0.016, 0.014, 0.012))
    rust = m.mask(m.noise(30, 6, 0.7), 0.68, 0.76)
    base = m.mixc(m.math('MULTIPLY', rust, 0.6), base, C(0.16, 0.06, 0.02))
    rough = m.mixf(soot, 0.42, 0.92)
    metal = m.mixf(soot, 0.9, 0.15)
    nrm = m.bump(m.math('ADD', m.noise(160, 5, 0.7), m.math('MULTIPLY', rust, 0.5), clamp=False), 0.18)
    m.bsdf(base, metal, rough, nrm)

    # --- chipped red paint over steel (pump nozzle, guard, valve wheel) ---------------------
    m = NB('PaintRed')
    chipn = m.noise(16, 10, 0.62, distort=0.3)
    chip = m.mask(chipn, 0.60, 0.62)
    grime = m.mask(m.noise(7, 8, 0.6), 0.38, 0.7)
    paint = m.mixc(m.mask(m.noise(40, 4, 0.5), 0.3, 0.7), C(0.30, 0.022, 0.016), C(0.24, 0.03, 0.02))
    paint = m.mixc(m.math('MULTIPLY', grime, 0.75), paint, C(0.07, 0.035, 0.02))
    base = m.mixc(chip, paint, C(0.10, 0.10, 0.105))
    rough = m.mixf(chip, m.mixf(grime, 0.42, 0.75), 0.3)
    nrm = m.bump(m.math('ADD', m.math('MULTIPLY', chip, -0.4, clamp=False), m.noise(260, 3, 0.6), clamp=False), 0.25)
    m.bsdf(base, m.mixf(chip, 0.0, 1.0), rough, nrm)

    # --- cream / beige gas-bottle paint: grime pooled low, rust streaks, chips --------------
    m = NB('TankPaint')
    z = m.axis(2)
    low = m.mask(z, -0.13, -0.19)
    nz = m.noise(6, 8, 0.62)
    grime = m.math('MAXIMUM', m.math('MULTIPLY', low, m.mask(nz, 0.2, 0.5)), m.mask(nz, 0.52, 0.72))
    streak = m.math('MULTIPLY', m.mask(m.noise(2.5, 6, 0.6, vec=m.scaled((70, 70, 5))), 0.55, 0.68),
                    m.mask(m.noise(5, 3, 0.5), 0.40, 0.55))
    chip = m.mask(m.noise(22, 10, 0.65, distort=0.25), 0.625, 0.64)
    base = m.mixc(m.mask(m.noise(60, 3, 0.5), 0.3, 0.7), C(0.44, 0.40, 0.31), C(0.36, 0.33, 0.25))
    base = m.mixc(m.math('MULTIPLY', grime, 0.9), base, C(0.09, 0.07, 0.045))
    base = m.mixc(m.math('MULTIPLY', streak, 0.85), base, C(0.17, 0.065, 0.02))
    base = m.mixc(chip, base, C(0.07, 0.045, 0.03))
    rough = m.mixf(grime, 0.5, 0.82)
    nrm = m.bump(m.math('ADD', m.math('MULTIPLY', chip, -0.5, clamp=False), m.noise(180, 4, 0.6), clamp=False), 0.2)
    m.bsdf(base, m.mixf(chip, 0.0, 0.6), rough, nrm)

    # --- rubber (hose, boot, grip cap) with dust ---------------------------------------------
    m = NB('Rubber')
    dust = m.mask(m.noise(9, 6, 0.6), 0.5, 0.85)
    base = m.mixc(m.math('MULTIPLY', dust, 0.6), C(0.016, 0.016, 0.017), C(0.09, 0.08, 0.07))
    m.bsdf(base, 0.0, m.mixf(dust, 0.62, 0.9), m.bump(m.noise(400, 2, 0.5), 0.15))

    # --- brass (valve, fittings, gauge bezel) with tarnish ----------------------------------
    m = NB('Brass')
    tarn = m.mask(m.noise(12, 7, 0.65), 0.4, 0.75)
    base = m.mixc(tarn, C(0.55, 0.38, 0.15), C(0.15, 0.11, 0.05))
    m.bsdf(base, 1.0, m.mixf(tarn, 0.28, 0.62), m.bump(m.noise(200, 3, 0.6), 0.08))

    # --- copper pilot line ------------------------------------------------------------------
    m = NB('Copper')
    tarn = m.mask(m.noise(15, 6, 0.6), 0.4, 0.8)
    base = m.mixc(tarn, C(0.55, 0.24, 0.12), C(0.12, 0.08, 0.05))
    m.bsdf(base, 1.0, m.mixf(tarn, 0.3, 0.6))

    # --- tapes ----------------------------------------------------------------------------
    m = NB('TapeBlack')
    weave = m.noise(1.5, 1, 0.5, vec=m.scaled((900, 900, 60)))
    dirt = m.mask(m.noise(8, 6, 0.6), 0.5, 0.85)
    m.bsdf(m.mixc(m.math('MULTIPLY', dirt, 0.5), C(0.02, 0.02, 0.021), C(0.07, 0.06, 0.05)), 0.0,
           0.82, m.bump(weave, 0.25))
    m = NB('TapeSilver')
    dirt = m.mask(m.noise(8, 6, 0.6), 0.4, 0.8)
    m.bsdf(m.mixc(dirt, C(0.38, 0.38, 0.39), C(0.11, 0.1, 0.085)), 0.45, m.mixf(dirt, 0.45, 0.8),
           m.bump(m.noise(1.5, 1, 0.5, vec=m.scaled((900, 900, 900))), 0.15))

    # --- weld beads -------------------------------------------------------------------------
    m = NB('Weld')
    nz = m.noise(260, 6, 0.75)
    base = m.mixc(m.mask(m.noise(40, 4, 0.6), 0.3, 0.7), C(0.16, 0.10, 0.05), C(0.05, 0.05, 0.06))
    m.bsdf(base, 0.75, 0.55, m.bump(nz, 0.6))

    # --- gauge dial / needle / label / misc -------------------------------------------------
    m = NB('GaugeFace')
    grime = m.mask(m.noise(20, 6, 0.6), 0.45, 0.85)
    m.bsdf(m.mixc(m.math('MULTIPLY', grime, 0.6), C(0.78, 0.74, 0.64), C(0.3, 0.24, 0.16)), 0.0, 0.35)
    m = NB('Black')
    m.bsdf(C(0.012, 0.012, 0.012), 0.2, 0.4)
    m = NB('Label')
    y = m.axis(0)
    band = m.mask(m.math('SINE', m.math('MULTIPLY', y, 80, clamp=False), clamp=False), 0.6, 0.65)
    wear = m.mask(m.noise(12, 8, 0.6), 0.5, 0.75)
    base = m.mixc(band, C(0.30, 0.12, 0.035), C(0.40, 0.36, 0.28))
    base = m.mixc(wear, base, C(0.12, 0.09, 0.06))
    m.bsdf(base, 0.0, 0.7, m.bump(m.noise(150, 3, 0.6), 0.1))

    # --- pilot flame: emissive, transparent edges -----------------------------------------
    for name, col, strength in (('FlameBlue', (0.06, 0.20, 1.0), 3.0), ('FlameCore', (0.35, 0.65, 1.0), 6.0)):
        m = NB(name)
        em = m.n('ShaderNodeEmission', {'Color': col + (1.0,), 'Strength': strength})
        tr = m.n('ShaderNodeBsdfTransparent')
        lw = m.n('ShaderNodeLayerWeight', {'Blend': 0.75})
        mix = m.n('ShaderNodeMixShader')
        m.l(lw.outputs['Facing'], mix.inputs[0])
        m.l(em.outputs[0], mix.inputs[1])
        m.l(tr.outputs[0], mix.inputs[2])
        m.l(mix.outputs[0], m.out.inputs['Surface'])

    # --- cutaway helpers --------------------------------------------------------------------
    m = NB('Section')
    m.bsdf(C(0.85, 0.30, 0.04), 0.0, 0.55)
    m = NB('Liquid')
    m.bsdf(C(0.85, 0.62, 0.25), 0.0, 0.08, extra={'Transmission Weight': 0.85, 'IOR': 1.3})

    # --- dummy / studio ---------------------------------------------------------------------
    m = NB('Dummy')
    m.bsdf(C(0.16, 0.16, 0.17), 0.0, 0.6, m.bump(m.noise(80, 3, 0.5), 0.05))
    m = NB('DummyHead')
    m.bsdf(C(0.20, 0.19, 0.17), 0.0, 0.55)
    m = NB('Floor')
    ln = m.n('ShaderNodeVectorMath', operation='LENGTH')
    m.l(m.obj(), ln.inputs[0])
    fade = m.mask(ln.outputs['Value'], 0.4, 4.5)
    base = m.mixc(fade, C(0.010, 0.010, 0.011), C(0.0015, 0.0015, 0.0017))
    m.bsdf(base, 0.0, 0.92, m.bump(m.noise(300, 2, 0.5), 0.03), extra={'Specular IOR Level': 0.15})


# --------------------------------------------------------------------------------------
# the model
# --------------------------------------------------------------------------------------
TANK_Z = -0.115          # bottle axis height
TANK_R = 0.075
GROUPS = {}              # object name -> exploded-view offset group


class Part:
    def __init__(self, name, mats, group):
        self.name, self.mats, self.group = name, mats, group
        self.bm = bmesh.new()


PARTS = {}


def P(name, mats, group=None):
    if name not in PARTS:
        PARTS[name] = Part(name, mats if isinstance(mats, list) else [mats], group or name)
    return PARTS[name]


def mi(part, mat):
    return part.mats.index(mat)


def build_parts():
    # ---------------- rear grip: red fuel-pump nozzle --------------------------------------
    g = P('NozzleGrip', ['PaintRed', 'SteelDark', 'Black'], 'grip')
    bm = g.bm
    path = crs([(-0.568, 0, 0.006), (-0.535, 0, 0.014), (-0.47, 0, 0.012), (-0.40, 0, 0.004), (-0.352, 0, 0.0)], 5)
    n = len(path)
    ry = [0.019 + 0.006 * math.sin(math.pi * min(1, i / (n * 0.55))) - 0.007 * max(0, (i - n * 0.6) / (n * 0.4))
          for i in range(n)]
    rz = [0.024 + 0.012 * math.sin(math.pi * min(1, i / (n * 0.6))) - 0.012 * max(0, (i - n * 0.6) / (n * 0.4))
          for i in range(n)]
    sweep(bm, path, ry, 16, rz=rz, sq=3.2, mi=mi(g, 'PaintRed'))
    # ribbed black rubber sleeve over the back of the housing (where the palm sits)
    idx = [i for i, p_ in enumerate(path) if -0.545 <= p_.x <= -0.43]
    sp = [path[i] for i in idx]
    sweep(bm, sp, [ry[i] * 1.07 + 0.0012 * (k % 2) for k, i in enumerate(idx)], 16,
          rz=[rz[i] * 1.05 + 0.0012 * (k % 2) for k, i in enumerate(idx)], sq=3.2, mi=mi(g, 'Black'))
    # cast seam / latch block on top, a screw on the side
    box(bm, (-0.505, 0, 0.044), (0.05, 0.012, 0.010), mi=mi(g, 'PaintRed'))
    hexbolt(bm, (-0.47, -0.0245, 0.012), (0, -1, 0), 0.0045, 0.004, mi(g, 'SteelDark'), washer=False)
    hexbolt(bm, (-0.47, 0.0245, 0.012), (0, 1, 0), 0.0045, 0.004, mi(g, 'SteelDark'), washer=False)
    # spout + coil spring
    cyl(bm, (-0.36, 0, 0.0), (-0.300, 0, 0.0), 0.0095, 14, mi(g, 'SteelDark'))
    hel = []
    hn = q(12, 6)
    for i in range(4 * hn + 1):
        a = TAU * i / hn
        hel.append((-0.352 + 0.044 * i / (4 * hn), 0.0118 * math.cos(a), 0.0118 * math.sin(a)))
    sweep(bm, hel, 0.0016, 5, mi=mi(g, 'SteelDark'))
    # trigger lever (bare steel) and guard (painted)
    lever = crs([(-0.372, 0, -0.016), (-0.40, 0, -0.035), (-0.45, 0, -0.044), (-0.50, 0, -0.040), (-0.522, 0, -0.030)], 4)
    sweep(bm, lever, 0.0095, 8, rz=0.0034, sq=4, mi=mi(g, 'SteelDark'))
    guard = crs([(-0.358, 0, -0.008), (-0.360, 0, -0.050), (-0.380, 0, -0.078), (-0.43, 0, -0.089),
                 (-0.50, 0, -0.085), (-0.545, 0, -0.062), (-0.557, 0, -0.018)], 4)
    sweep(bm, guard, 0.0058, 8, rz=0.0048, mi=mi(g, 'PaintRed'))
    # ribbed rubber boot where the hose enters
    boot = crs([(-0.560, 0, 0.008), (-0.60, 0, 0.0), (-0.632, 0, -0.012)], 6)
    rb = [0.0175 - 0.005 * i / (len(boot) - 1) + 0.0016 * (i % 2) for i in range(len(boot))]
    sweep(bm, boot, rb, 14, mi=mi(g, 'Black'))

    # ---------------- feed pipe, couplings, tape -------------------------------------------
    f = P('FeedPipe', 'SteelDark', 'pipe')
    lathe(f.bm, [(-0.312, 0.0), (-0.312, 0.020), (-0.292, 0.020), (-0.292, 0.0)], 6, mi=0)    # coupling nut
    tube(f.bm, (-0.295, 0, 0), (0.115, 0, 0), 0.0115, 0.0155, 16, rings=6)
    lathe(f.bm, [(0.098, 0.0), (0.098, 0.0215), (0.118, 0.0215), (0.118, 0.0)], 6, mi=0)      # union nut
    lathe(f.bm, [(0.116, 0.0), (0.116, 0.017), (0.13, 0.017), (0.13, 0.0)], 6, mi=0)
    t = P('TapeFeed', 'TapeBlack', 'pipe')
    for x0, x1 in ((-0.25, -0.212), (-0.072, -0.044)):
        lathe(t.bm, [(x0, 0.0154), (x0, 0.0172), (x1, 0.0176), (x1, 0.0154)], 16, closed=True,
              pert=lambda x, r, a: 0.0006 * math.sin(3 * a + x * 300))
    box(t.bm, (-0.214, -0.0165, -0.012), (0.012, 0.002, 0.016), mi=0)   # loose tape tail

    # ---------------- barrel, slotted heat shroud, welds -----------------------------------
    b = P('Barrel', 'SteelBurnt', 'barrel')
    tube(b.bm, (0.122, 0, 0), (0.50, 0, 0), 0.0135, 0.0200, 16, rings=6)
    s = P('HeatShroud', 'SteelBurnt', 'shroud')
    tube(s.bm, (0.160, 0, 0), (0.430, 0, 0), 0.0370, 0.0400, 24, rings=10)
    tube(s.bm, (0.150, 0, 0), (0.160, 0, 0), 0.0195, 0.0400, 24)
    tube(s.bm, (0.430, 0, 0), (0.440, 0, 0), 0.0195, 0.0400, 24)
    w = P('WeldsBarrel', 'Weld', 'shroud')
    for x, R in ((0.149, 0.0204), (0.441, 0.0204), (0.160, 0.0402), (0.430, 0.0402)):
        torus(w.bm, (x, 0, 0), (1, 0, 0), R, 0.0026, 28, 5, bump=0.35, seed=int(x * 1000))

    # ---------------- front grip (strap band on the shroud + taped tube) -------------------
    fg = P('FrontGrip', ['SteelDark', 'Rubber'], 'fgrip')
    lathe(fg.bm, [(0.248, 0.0402), (0.248, 0.0445), (0.276, 0.0445), (0.276, 0.0402)], 24, closed=True)
    for yy in (-0.0065, 0.0065):
        box(fg.bm, (0.262, yy, 0.051), (0.026, 0.004, 0.016))
    cyl(fg.bm, (0.262, 0, -0.040), (0.276, 0, -0.178), 0.0150, 14, 0)
    cyl(fg.bm, (0.2758, 0, -0.176), (0.2775, 0, -0.193), 0.0185, 14, mi(fg, 'Rubber'))
    tg = P('TapeGrip', 'TapeBlack', 'fgrip')
    gp = [V((0.262, 0, -0.040)).lerp(V((0.276, 0, -0.178)), t_) for t_ in (0.27, 0.86)]
    lathe(tg.bm, [(0, 0.0151), (0, 0.0168), ((gp[1] - gp[0]).length, 0.0172), ((gp[1] - gp[0]).length, 0.0151)],
          16, frame_x(gp[0], gp[1] - gp[0]), closed=True, pert=lambda x, r, a: 0.0005 * math.sin(5 * a + x * 400))
    wg = P('WeldsFrontGrip', 'Weld', 'fgrip')
    torus(wg.bm, (0.2625, 0, -0.043), (0.1, 0, -1), 0.0158, 0.0024, 22, 5, bump=0.35, seed=3)
    bf = P('BoltsFrontGrip', 'SteelDark', 'fgrip')
    hexbolt(bf.bm, (0.262, -0.0085, 0.054), (0, -1, 0), 0.0045, 0.008)
    hexbolt(bf.bm, (0.262, 0.0085, 0.054), (0, 1, 0), 0.0042, 0.004, washer=False)

    # ---------------- muzzle: hand-rolled flared bell, collar, seam, bolts ------------------
    mz = P('Muzzle', 'SteelBurnt', 'muzzle')
    # straight nozzle extension -> short welded cone -> rolled lip (no trumpet, no cup)
    outer = [(0.490, 0.0245), (0.548, 0.0245), (0.556, 0.0275), (0.570, 0.0350), (0.585, 0.0430),
             (0.600, 0.0505), (0.612, 0.0565)]
    inner = [(0.612, 0.0525), (0.600, 0.0468), (0.585, 0.0395), (0.570, 0.0318), (0.556, 0.0246),
             (0.548, 0.0205), (0.490, 0.0205)]
    dent = lambda x, r, a: (x - 0.565) * 0.05 * (math.sin(3 * a + 1.3) * 0.6 + math.sin(7 * a) * 0.4) if x > 0.565 else 0
    lathe(mz.bm, outer + inner, 40, closed=True, pert=dent)
    lip = []
    nl = q(40)
    for i in range(nl):
        a_ = TAU * i / nl
        rr = 0.0548 + dent(0.612, 0.0548, a_)
        lip.append((0.6135, rr * math.cos(a_), rr * math.sin(a_)))
    sweep(mz.bm, lip, 0.0042, 8, closed=True)
    lathe(mz.bm, [(0.474, 0.0203), (0.474, 0.0300), (0.500, 0.0300), (0.500, 0.0203)], 20, closed=True)
    lathe(mz.bm, [(0.538, 0.0240), (0.538, 0.0285), (0.552, 0.0285), (0.552, 0.0240)], 20, closed=True)
    for k in range(3):   # crude swirl vanes welded inside the cone
        a_ = TAU * k / 3 + 0.3
        Rm = Matrix.Rotation(a_, 3, 'X') @ Matrix.Rotation(math.radians(28), 3, 'Z')
        box(mz.bm, V((0.578, 0, 0)) + Matrix.Rotation(a_, 3, 'X') @ V((0, 0.017, 0)), (0.026, 0.024, 0.0022), Rm)
    seam = []
    for x, r in outer[1:]:
        a = math.radians(205)
        seam.append((x, (r + 0.0012) * math.cos(a), (r + 0.0012) * math.sin(a)))
    sweep(mz.bm, crs(seam, 3), 0.0022, 5, mi=0)
    bm_ = P('BoltsMuzzle', 'SteelDark', 'muzzle')
    for ang in (90, 210, 330):
        a = math.radians(ang)
        d = V((0, math.cos(a), math.sin(a)))
        hexbolt(bm_.bm, V((0.487, 0, 0)) + d * 0.030, d, 0.0042, 0.0065)
    wm = P('WeldsMuzzle', 'Weld', 'muzzle')
    torus(wm.bm, (0.4735, 0, 0), (1, 0, 0), 0.0207, 0.0024, 24, 5, bump=0.35, seed=7)
    torus(wm.bm, (0.5535, 0, 0), (1, 0, 0), 0.0262, 0.0024, 24, 5, bump=0.35, seed=8)

    # ---------------- pilot light (burner under the muzzle) --------------------------------
    pl = P('PilotLight', ['SteelBurnt', 'Brass'], 'pilot')
    p0, p1 = V((0.452, 0, -0.060)), V((0.584, 0, -0.082))
    cyl(pl.bm, p0, p1, 0.0056, 12, 0)
    tip_dir = V((math.cos(math.radians(22)), 0, math.sin(math.radians(22))))
    cyl(pl.bm, p1 - (p1 - p0).normalized() * 0.003, p1 + tip_dir * 0.010, 0.0062, 10, mi(pl, 'Brass'), r1=0.0035)
    # holes/air intake ring and hanger strap from the muzzle collar
    lathe(pl.bm, [(0.0, 0.0056), (0.0, 0.0070), (0.008, 0.0070), (0.008, 0.0056)], 10,
          frame_x(p0.lerp(p1, 0.18), p1 - p0), closed=True, mi=mi(pl, 'Brass'))
    box(pl.bm, (0.492, 0, -0.047), (0.010, 0.0035, 0.030), mi=0)
    flame = P('PilotFlame', ['FlameBlue', 'FlameCore'], 'pilot')
    ftip = p1 + tip_dir * 0.010
    fM = frame_x(ftip, tip_dir)
    lathe(flame.bm, [(0, 0.0), (0.0, 0.0045), (0.008, 0.0085), (0.025, 0.0080), (0.045, 0.0042), (0.062, 0.0)], 14, fM, mi=0)
    lathe(flame.bm, [(0.0005, 0.0), (0.0005, 0.0032), (0.008, 0.0040), (0.018, 0.0), ], 10, fM, mi=1)
    cu = P('PilotLine', 'Copper', 'tank')
    line = crs([(-0.222, -0.070, -0.112), (-0.19, -0.090, -0.100), (-0.10, -0.091, -0.092), (0.05, -0.088, -0.086),
                (0.14, -0.060, -0.070), (0.22, -0.034, -0.058), (0.40, -0.030, -0.058), (0.440, -0.010, -0.059),
                (0.454, 0, -0.0605)], 6)
    sweep(cu.bm, line, 0.0028, 6, mi=0)
    for idx in (int(len(line) * 0.29), int(len(line) * 0.71)):   # two little wire clips holding the copper line
        torus(cu.bm, line[idx], line[idx + 1] - line[idx - 1], 0.0045, 0.0011, 10, 4)

    # ---------------- propane bottle (dented), foot ring, guard collar, label ---------------
    tk = P('Tank', 'TankPaint', 'tank')
    prof = [(-0.236, 0.0), (-0.235, 0.014), (-0.232, 0.028), (-0.224, 0.045), (-0.212, 0.060), (-0.198, 0.070),
            (-0.182, 0.0748)]
    xs = [-0.182 + i * 0.0185 for i in range(1, 12)]
    for x in xs:
        prof.append((x, 0.0765 if abs(x - (-0.071)) < 0.006 else 0.075))
    prof += [(0.038, 0.0748), (0.052, 0.070), (0.065, 0.060), (0.074, 0.046), (0.079, 0.028), (0.081, 0.012),
             (0.0815, 0.0)]
    M = Matrix.Translation((0, 0, TANK_Z))
    lathe(tk.bm, prof, 32, M)
    # dents: push the shell in with a few gaussian dimples
    rnd = random.Random(11)
    dents = [(-0.12, math.radians(250), 0.024, 0.006), (-0.03, math.radians(215), 0.018, 0.0045),
             (0.02, math.radians(120), 0.03, 0.005), (-0.15, math.radians(60), 0.02, 0.004),
             (-0.06, math.radians(290), 0.014, 0.003)]
    for v in tk.bm.verts:
        lx, ly, lz = v.co.x, v.co.y, v.co.z - TANK_Z
        rr = math.hypot(ly, lz)
        if rr < 1e-5:
            continue
        a = math.atan2(lz, ly)
        d = 0.0
        for dx, da, sig, depth in dents:
            arc = (((a - da + math.pi) % TAU) - math.pi) * TANK_R
            d += depth * math.exp(-((lx - dx) ** 2 + arc ** 2) / (sig ** 2))
        d += 0.0006 * (rnd.random() - 0.5)
        k = (rr - d) / rr
        v.co.y, v.co.z = ly * k, lz * k + TANK_Z
    lathe(tk.bm, [(0.062, 0.0575), (0.062, 0.0610), (0.097, 0.0610), (0.097, 0.0575)], 28, M, closed=True)  # foot ring
    lb = P('TankLabel', 'Label', 'tank')
    lathe(lb.bm, [(-0.15, 0.0762), (-0.02, 0.0762)], 10, M, th=(math.radians(200), math.radians(250)))
    col = P('TankCollar', 'TankPaint', 'collar')
    lathe(col.bm, [(-0.292, 0.0475), (-0.292, 0.0510), (-0.212, 0.0510), (-0.212, 0.0475)], 28, M, closed=True)
    lathe(col.bm, [(-0.296, 0.0505), (-0.296, 0.0540), (-0.290, 0.0540), (-0.290, 0.0505)], 28, M, closed=True)  # rolled lip

    # ---------------- valve, handwheel, regulator, gauge ----------------------------------
    va = P('Valve', 'Brass', 'valve')
    cyl(va.bm, (-0.233, 0, TANK_Z), (-0.270, 0, TANK_Z), 0.0130, 12)
    lathe(va.bm, [(0, 0), (0, 0.0175), (0.010, 0.0175), (0.010, 0)], 6, frame_x((-0.246, 0, TANK_Z), (-1, 0, 0)))
    cyl(va.bm, (-0.268, 0, TANK_Z), (-0.287, 0, TANK_Z), 0.0042, 8)
    cyl(va.bm, (-0.252, 0, TANK_Z), (-0.252, -0.060, TANK_Z), 0.0062, 10)          # outlet to regulator
    lathe(va.bm, [(0, 0), (0, 0.0105), (0.010, 0.0105), (0.010, 0)], 6, frame_x((-0.252, -0.046, TANK_Z), (0, -1, 0)))
    vw = P('ValveWheel', 'PaintRed', 'valve')
    torus(vw.bm, (-0.284, 0, TANK_Z), (1, 0, 0), 0.019, 0.0036, 24, 6)
    for k in range(3):
        a = TAU * k / 3 + 0.4
        cyl(vw.bm, (-0.284, 0, TANK_Z), (-0.284, 0.019 * math.cos(a), TANK_Z + 0.019 * math.sin(a)), 0.0026, 6)
    cyl(vw.bm, (-0.281, 0, TANK_Z), (-0.289, 0, TANK_Z), 0.0062, 10)
    rg = P('Regulator', ['SteelDark', 'Brass'], 'valve')
    rc = V((-0.252, -0.070, TANK_Z))
    lathe(rg.bm, [(0, 0), (0, 0.030), (0.012, 0.030), (0.016, 0.026), (0.022, 0.012), (0.024, 0)], 22,
          frame_x(rc + V((0, 0.010, 0)), (0, -1, 0)))
    lathe(rg.bm, [(0, 0), (0, 0.031), (0.004, 0.031), (0.004, 0)], 22, frame_x(rc + V((0, 0.011, 0)), (0, -1, 0)))
    for k in range(6):   # rim screws
        a = TAU * k / 6
        hexbolt(rg.bm, rc + V((0.026 * math.cos(a), -0.0072, 0.026 * math.sin(a))), (0, -1, 0), 0.0024, 0.0025, 0,
                washer=False)
    cyl(rg.bm, rc + V((-0.026, 0, 0)), rc + V((-0.050, 0, 0)), 0.0060, 10, mi(rg, 'Brass'))   # hose outlet
    lathe(rg.bm, [(0, 0), (0, 0.0085), (0.008, 0.0085), (0.008, 0)], 6, frame_x(rc + V((-0.040, 0, 0)), (-1, 0, 0)),
          mi=mi(rg, 'Brass'))
    cyl(rg.bm, rc + V((0.026, 0, 0)), rc + V((0.034, 0, 0.003)), 0.0040, 8, mi(rg, 'Brass'))   # pilot tee
    cyl(rg.bm, rc + V((0, -0.004, 0.026)), rc + V((0, -0.004, 0.052)), 0.0050, 8, mi(rg, 'Brass'))  # gauge stem
    gg = P('Gauge', ['Brass', 'GaugeFace', 'Black', 'PaintRed'], 'gauge')
    gc = rc + V((0, -0.006, 0.066))
    F = frame_x(gc, (0, -1, 0))
    lathe(gg.bm, [(-0.006, 0), (-0.006, 0.020), (0.004, 0.0225), (0.010, 0.0225), (0.011, 0.0205),
                  (0.0105, 0.0185), (0.008, 0.0185), (0.008, 0)], 24, F, mi=0)
    lathe(gg.bm, [(0.0082, 0), (0.0082, 0.0186)], 24, F, mi=mi(gg, 'GaugeFace'))
    face_n = V((0, -1, 0))
    for k in range(11):   # tick marks over a 270 degree sweep
        a = math.radians(225 - 27 * k)
        dirv = V((math.cos(a), 0, math.sin(a)))
        red = k >= 9
        box(gg.bm, gc + face_n * 0.0084 + dirv * 0.0155, (0.0012, 0.0006, 0.0045 if k % 5 == 0 else 0.003),
            Matrix.Rotation(-a + math.pi / 2, 3, 'Y'), mi(gg, 'PaintRed' if red else 'Black'))
    a = math.radians(225 - 27 * 6.3)
    dirv = V((math.cos(a), 0, math.sin(a)))
    box(gg.bm, gc + face_n * 0.0090 + dirv * 0.0065, (0.0011, 0.0005, 0.017), Matrix.Rotation(-a + math.pi / 2, 3, 'Y'),
        mi(gg, 'Black'))
    cyl(gg.bm, gc + face_n * 0.0088, gc + face_n * 0.0096, 0.0022, 8, mi(gg, 'Black'))

    # ---------------- tank mount: straps, rail, saddles, U-bolts ----------------------------
    tm = P('TankMount', 'SteelDark', 'mount')
    for x0 in (-0.170, -0.004):
        x1 = x0 + 0.022
        lathe(tm.bm, [(x0, 0.0755), (x0, 0.0785), (x1, 0.0785), (x1, 0.0755)], 32, M, closed=True)
        xc = (x0 + x1) / 2
        for dz in (-0.0065, 0.0065):
            box(tm.bm, (xc, 0.085, TANK_Z + dz), (0.022, 0.016, 0.0035))
        box(tm.bm, (xc, 0, -0.0355), (0.022, 0.026, 0.006))     # saddle
    box(tm.bm, (-0.068, 0, -0.0305), (0.27, 0.022, 0.006))      # rail
    for xu in (-0.135, 0.040):
        u = []
        for k in range(15):
            a = math.pi * k / 14
            u.append((xu, -0.0185 * math.cos(a), 0.0185 * math.sin(a)))
        u = [(xu, -0.0185, -0.036)] + u + [(xu, 0.0185, -0.036)]
        sweep(tm.bm, u, 0.0024, 6)
    bt = P('BoltsTankMount', 'SteelDark', 'mount')
    for x0 in (-0.170, -0.004):
        xc = x0 + 0.011
        hexbolt(bt.bm, (xc, 0.088, TANK_Z + 0.0085), (0, 0, 1), 0.0045, 0.008)
        hexbolt(bt.bm, (xc, 0.088, TANK_Z - 0.0085), (0, 0, -1), 0.0045, 0.006, washer=False)
    for xu in (-0.135, 0.040):
        for yy in (-0.0185, 0.0185):
            hexbolt(bt.bm, (xu, yy, -0.0335), (0, 0, -1), 0.0040, 0.005)

    # ---------------- hose loop, crimp ferrules, duct tape repair -------------------------
    h = P('Hose', 'Rubber', 'hose')
    hp = crs([(-0.300, -0.070, TANK_Z), (-0.325, -0.072, -0.128), (-0.37, -0.064, -0.178), (-0.45, -0.045, -0.214),
              (-0.55, -0.026, -0.206), (-0.628, -0.010, -0.165), (-0.672, 0, -0.100), (-0.668, 0, -0.045),
              (-0.632, 0, -0.012)], 7)
    sweep(h.bm, hp, 0.0105, 10, mi=0)
    hf = P('HoseFittings', 'SteelDark', 'hose')
    for i0, i1 in ((0, 3), (len(hp) - 4, len(hp) - 1)):
        seg = hp[i0:i1 + 1]
        sweep(hf.bm, seg, 0.0128, 10)
    ts = P('TapeHose', 'TapeSilver', 'hose')
    seg = hp[int(len(hp) * 0.667):int(len(hp) * 0.77) + 1]
    sweep(ts.bm, seg, [0.0122 + 0.0006 * ((k * 7) % 3) for k in range(len(seg))], 10)


def build_objects(col):
    objs = {}
    for name, part in PARTS.items():
        me = bpy.data.meshes.new(name)
        part.bm.to_mesh(me)
        part.bm.free()
        for mname in part.mats:
            me.materials.append(MAT[mname])
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(38 if SEGQ >= 0.99 else 64))
        ob = bpy.data.objects.new(name, me)
        col.objects.link(ob)
        ob['group'] = part.group
        objs[name] = ob
    return objs


def slot_cutter(col):
    """Stadium-shaped radial prisms for the shroud vent slots."""
    bm = bmesh.new()
    L, W = 0.050, 0.0105
    for row in range(6):
        a = math.radians(30 + 60 * row)
        radial = V((0, math.cos(a), math.sin(a)))
        tang = V((0, -math.sin(a), math.cos(a)))
        centers = (0.198, 0.322, 0.398) if row % 2 == 0 else (0.205, 0.330, 0.400)
        for xc in centers:
            outline = []
            half = L / 2 - W / 2
            ne = 7 if SEGQ >= 0.99 else 4
            for k in range(ne):
                t = -math.pi / 2 + math.pi * k / (ne - 1)
                outline.append((half + W / 2 * math.cos(t), W / 2 * math.sin(t)))
            for k in range(ne):
                t = math.pi / 2 + math.pi * k / (ne - 1)
                outline.append((-half + W / 2 * math.cos(t), W / 2 * math.sin(t)))
            inner = [bm.verts.new(V((xc + u, 0, 0)) + radial * 0.030 + tang * v) for u, v in outline]
            outer = [bm.verts.new(V((xc + u, 0, 0)) + radial * 0.050 + tang * v) for u, v in outline]
            bm.faces.new(inner)
            bm.faces.new(list(reversed(outer)))
            n = len(outline)
            for k in range(n):
                k1 = (k + 1) % n
                bm.faces.new((inner[k], outer[k], outer[k1], inner[k1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('SlotCutter')
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new('SlotCutter', me)
    col.objects.link(ob)
    return ob


def apply_bool(obj, cutter, op='DIFFERENCE', transfer=False):
    mod = obj.modifiers.new('bool', 'BOOLEAN')
    mod.operation = op
    mod.object = cutter
    mod.solver = 'EXACT'
    mod.use_self = True            # parts are unions of overlapping closed pieces
    mod.use_hole_tolerant = True
    if transfer:
        mod.material_mode = 'TRANSFER'
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    obj.modifiers.clear()
    old = obj.data
    obj.data = me
    me.name = old.name
    bpy.data.meshes.remove(old)


def collar_cutter(col):
    bm = bmesh.new()
    box(bm, (-0.255, -0.05, TANK_Z), (0.034, 0.03, 0.026))     # regulator outlet window
    box(bm, (-0.255, 0.05, TANK_Z), (0.034, 0.03, 0.026))
    box(bm, (-0.262, 0, TANK_Z + 0.05), (0.050, 0.04, 0.03))   # carry handle slot on top
    me = bpy.data.meshes.new('CollarCutter')
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new('CollarCutter', me)
    col.objects.link(ob)
    return ob


def tri_counts(objs):
    out = {}
    for name, ob in objs.items():
        ob.data.calc_loop_triangles()
        out[name] = len(ob.data.loop_triangles)
    return out


# --------------------------------------------------------------------------------------
# studio, cameras, lights
# --------------------------------------------------------------------------------------
FLOOR_Z = -0.30


def setup_scene(args):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = args.samples
    sc.cycles.use_denoising = True
    try:
        sc.cycles.denoiser = 'OPENIMAGEDENOISE'
    except Exception:
        pass
    sc.cycles.max_bounces = 6
    sc.cycles.transparent_max_bounces = 8
    sc.render.resolution_x, sc.render.resolution_y = args.res
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    try:
        sc.view_settings.view_transform = 'AgX'
        sc.view_settings.look = 'AgX - Medium High Contrast'
    except Exception:
        pass
    w = bpy.data.worlds.new('Studio')
    sc.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = w.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value = (0.004, 0.004, 0.0045, 1)
    bg.inputs['Strength'].default_value = 1.0


def add_floor(col, z):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=12)
    me = bpy.data.meshes.new('Floor')
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MAT['Floor'])
    ob = bpy.data.objects.new('Floor', me)
    ob.location = (0, 0, z)
    col.objects.link(ob)
    return ob


class Rig:
    """Camera + 3-point lights that follow the camera direction."""

    def __init__(self, col):
        cd = bpy.data.cameras.new('Cam')
        self.cam = bpy.data.objects.new('Cam', cd)
        col.objects.link(self.cam)
        bpy.context.scene.camera = self.cam
        self.lights = {}
        for name, size, energy, color in (('Key', 1.6, 260, (1.0, 0.93, 0.85)), ('Fill', 2.5, 55, (0.8, 0.88, 1.0)),
                                          ('Rim', 1.0, 380, (1.0, 0.95, 0.9)), ('Top', 3.0, 40, (1, 1, 1))):
            ld = bpy.data.lights.new(name, 'AREA')
            ld.size = size
            ld.energy = energy
            ld.color = color
            ob = bpy.data.objects.new(name, ld)
            col.objects.link(ob)
            self.lights[name] = ob
        pd = bpy.data.lights.new('PilotGlow', 'POINT')
        pd.energy = 0.6
        pd.color = (0.3, 0.5, 1.0)
        pd.shadow_soft_size = 0.01
        self.glow = bpy.data.objects.new('PilotGlow', pd)
        col.objects.link(self.glow)

    @staticmethod
    def aim(ob, loc, target, up=(0, 0, 1)):
        d = (V(target) - V(loc)).normalized()
        upv = V(up)
        if abs(d.dot(upv)) > 0.98:
            upv = V((0, 1, 0))
        right = d.cross(upv).normalized()
        camup = right.cross(d)
        R = Matrix((right, camup, -d)).transposed()
        ob.matrix_world = Matrix.Translation(V(loc)) @ R.to_4x4()

    def frame(self, bbox, view_dir, lens=70, ortho=False, margin=1.12, up=(0, 0, 1), target=None, light_scale=1.0):
        lo, hi = V(bbox[0]), V(bbox[1])
        center = V(target) if target else (lo + hi) / 2
        d = V(view_dir).normalized()
        corners = [V((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
        sc = bpy.context.scene
        aspect = sc.render.resolution_x / sc.render.resolution_y
        cam = self.cam
        cam.data.sensor_fit = 'HORIZONTAL'
        cam.data.sensor_width = 36
        tx = 18 / lens
        ty = tx / aspect
        if ortho:
            cam.data.type = 'ORTHO'
            self.aim(cam, center + d * 5, center, up)
            Mi = cam.matrix_world.inverted()
            pts = [Mi @ c for c in corners]
            w = max(abs(p.x) for p in pts) * 2 * margin
            hgt = max(abs(p.y) for p in pts) * 2 * margin
            cam.data.ortho_scale = max(w, hgt * aspect)
            dist = 2.5
        else:
            cam.data.type = 'PERSP'
            cam.data.lens = lens
            lo_d, hi_d = 0.05, 30.0
            for _ in range(40):
                dist = (lo_d + hi_d) / 2
                self.aim(cam, center + d * dist, center, up)
                Mi = cam.matrix_world.inverted()
                ok = True
                for c in corners:
                    p = Mi @ c
                    zc = -p.z
                    if zc <= 0.01 or abs(p.x / zc) > tx / margin or abs(p.y / zc) > ty / margin:
                        ok = False
                        break
                if ok:
                    hi_d = dist
                else:
                    lo_d = dist
            dist = hi_d
            self.aim(cam, center + d * dist, center, up)
        cam.data.clip_start = 0.01
        cam.data.clip_end = 100
        # lights in the camera frame
        R = cam.matrix_world.to_3x3()
        right, camup, back = R.col[0], R.col[1], R.col[2]
        L = max(1.6, dist * 0.8) * light_scale
        worldup = V((0, 0, 1))
        place = {'Key': -right * 0.9 + worldup * 1.0 + back * 0.7, 'Fill': right * 1.1 + worldup * 0.2 + back * 0.8,
                 'Rim': right * 0.3 + worldup * 0.9 - back * 1.1, 'Top': worldup * 1.6}
        for name, off in place.items():
            ob = self.lights[name]
            loc = center + off.normalized() * L
            self.aim(ob, loc, center)
            base = {'Key': 110, 'Fill': 22, 'Rim': 190, 'Top': 12}[name]
            ob.data.energy = base * (L / 2.0) ** 2


def render(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print('rendered', path, flush=True)


def world_bbox(objs):
    lo = V((1e9, 1e9, 1e9))
    hi = V((-1e9, -1e9, -1e9))
    for ob in objs:
        for c in ob.bound_box:
            w = ob.matrix_world @ V(c)
            lo = V((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = V((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    return lo, hi


# --------------------------------------------------------------------------------------
# exploded view, cutaway, scale dummy
# --------------------------------------------------------------------------------------
EXPLODE = {
    'grip': (-0.20, 0, 0.06), 'hose': (-0.16, -0.06, -0.16), 'pipe': (0, 0, 0.13), 'barrel': (0.10, 0, 0.13),
    'shroud': (0.10, 0, 0.29), 'fgrip': (0.10, 0, -0.10), 'muzzle': (0.30, 0, 0.13), 'pilot': (0.30, 0, -0.06),
    'tank': (0, 0, -0.24), 'collar': (-0.07, 0, -0.24), 'valve': (-0.15, 0, -0.24), 'gauge': (-0.15, -0.03, -0.14),
    'mount': (0, 0, -0.07),
}


def build_dummy(col):
    s = 0.28
    bm = bmesh.new()
    parts = {'Torso': ((0, 0, 3 * s), (1 * s, 2 * s, 2 * s)),
             'LegL': ((0, 0.5 * s, 1 * s), (1 * s, 1 * s, 2 * s)), 'LegR': ((0, -0.5 * s, 1 * s), (1 * s, 1 * s, 2 * s))}
    obs = []
    for name, (c, size) in parts.items():
        bm = bmesh.new()
        box(bm, c, size)
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.012, segments=2, affect='EDGES', profile=0.5)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(MAT['Dummy'])
        ob = bpy.data.objects.new('Dummy' + name, me)
        col.objects.link(ob)
        obs.append(ob)
    # head (rounded cylinder, Roblox-like) on a neck
    bm = bmesh.new()
    lathe(bm, [(0, 0), (0, 0.13), (0.012, 0.165), (0.04, 0.17), (0.30, 0.17), (0.328, 0.165), (0.34, 0.13), (0.34, 0)],
          24, frame_x((0, 0, 4 * s), (0, 0, 1)))
    me = bpy.data.meshes.new('Head')
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MAT['DummyHead'])
    me.shade_smooth()
    me.set_sharp_from_angle(angle=math.radians(50))
    ob = bpy.data.objects.new('DummyHead', me)
    col.objects.link(ob)
    obs.append(ob)
    # arms, pivoting at the shoulder: (pitch forward deg, yaw inward deg)
    arms = {}
    for side, yy in (('L', 1.5 * s), ('R', -1.5 * s)):
        bm = bmesh.new()
        box(bm, (0, 0, -0.75 * s), (1 * s, 1 * s, 2 * s))
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.012, segments=2, affect='EDGES', profile=0.5)
        me = bpy.data.meshes.new('Arm' + side)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(MAT['Dummy'])
        ob = bpy.data.objects.new('DummyArm' + side, me)
        ob.location = (0, yy, 3.75 * s)
        col.objects.link(ob)
        obs.append(ob)
        arms[side] = ob
    return obs, arms


def cut_half(col, objs, keep_names):
    """Make sectioned copies (y < 0 removed) of the named parts; returns the new objects."""
    bm = bmesh.new()
    box(bm, (0, -0.5, 0), (3, 1.0, 3))
    me = bpy.data.meshes.new('SectionBox')
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MAT['Section'])
    cutter = bpy.data.objects.new('SectionBox', me)
    col.objects.link(cutter)
    out = []
    for name in keep_names:
        src = objs[name]
        ob = src.copy()
        ob.data = src.data.copy()
        ob.name = name + '_cut'
        col.objects.link(ob)
        if name == 'Tank':
            sol = ob.modifiers.new('sol', 'SOLIDIFY')
            sol.thickness = 0.004
            sol.offset = -1
            dg = bpy.context.evaluated_depsgraph_get()
            dg.update()
            me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
            ob.modifiers.clear()
            ob.data = me2
        apply_bool(ob, cutter, 'DIFFERENCE', transfer=True)
        out.append(ob)
    cutter.hide_render = True
    # liquid propane: the lower part of the bottle volume, cut too
    bm = bmesh.new()
    lathe(bm, [(-0.226, 0.0), (-0.226, 0.040), (-0.205, 0.062), (-0.182, 0.0705), (0.036, 0.0705), (0.06, 0.062),
               (0.075, 0.035), (0.075, 0.0)], 32, Matrix.Translation((0, 0, TANK_Z)))
    me = bpy.data.meshes.new('Liquid')
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MAT['Liquid'])
    liq = bpy.data.objects.new('PropaneLiquid', me)
    col.objects.link(liq)
    bm = bmesh.new()
    box(bm, (0, 0.5, TANK_Z - 0.5 + 0.018), (3, 1.0, 1.0))
    me = bpy.data.meshes.new('LiqBox')
    bm.to_mesh(me)
    bm.free()
    lb = bpy.data.objects.new('LiqBox', me)
    col.objects.link(lb)
    apply_bool(liq, lb, 'INTERSECT')
    bpy.data.objects.remove(lb)
    liq.data.shade_smooth()
    out.append(liq)
    # dip tube (valve -> bottom of the bottle: the bottle is liquid-fed)
    bm = bmesh.new()
    sweep(bm, crs([(-0.233, 0, TANK_Z), (-0.215, 0, TANK_Z - 0.02), (-0.18, 0, TANK_Z - 0.055),
                   (-0.10, 0, TANK_Z - 0.064), (0.0, 0, TANK_Z - 0.066)], 6), 0.0035, 8)
    me = bpy.data.meshes.new('DipTube')
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MAT['Copper'])
    me.shade_smooth()
    dt = bpy.data.objects.new('DipTube', me)
    col.objects.link(dt)
    out.append(dt)
    return out, cutter


# --------------------------------------------------------------------------------------
# contact sheet
# --------------------------------------------------------------------------------------
def contact_sheet(out_dir, files):
    from PIL import Image, ImageDraw, ImageFont
    tw, th = 520, 325
    cols = 3
    rows = math.ceil(len(files) / cols)
    pad, lab = 10, 26
    sheet = Image.new('RGB', (cols * (tw + pad) + pad, rows * (th + lab + pad) + pad + 44), (12, 12, 13))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 17)
        big = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 22)
    except Exception:
        font = big = ImageFont.load_default()
    d.text((pad, 10), 'Pyromaniac finisher - improvised flamethrower (look-dev)', fill=(220, 210, 195), font=big)
    for i, fpath in enumerate(files):
        im = Image.open(fpath).convert('RGB')
        im.thumbnail((tw, th))
        x = pad + (i % cols) * (tw + pad)
        y = 44 + pad + (i // cols) * (th + lab + pad)
        sheet.paste(im, (x + (tw - im.width) // 2, y))
        d.text((x + 4, y + th + 3), os.path.splitext(os.path.basename(fpath))[0], fill=(190, 185, 175), font=font)
    sheet.save(os.path.join(out_dir, 'sheet.png'))
    return os.path.join(out_dir, 'sheet.png')


# --------------------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--fbx', default=None)
    ap.add_argument('--blend', default=None)
    ap.add_argument('--samples', type=int, default=48)
    ap.add_argument('--res', default='1600x1000')
    ap.add_argument('--only', default='')
    ap.add_argument('--quick', action='store_true')
    ap.add_argument('--game-q', type=float, default=0.5)
    ap.add_argument('--q', type=float, default=1.0, help='segment scale for the renders (0.5 = game mesh)')
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    args = ap.parse_args(argv)
    args.res = tuple(int(v) for v in args.res.split('x'))
    if args.quick:
        args.res = (args.res[0] // 2, args.res[1] // 2)
        args.samples = min(args.samples, 16)
    os.makedirs(args.out, exist_ok=True)
    only = set(v for v in args.only.split(',') if v)

    global SEGQ
    SEGQ = args.q
    bpy.ops.wm.read_factory_settings(use_empty=True)
    col = bpy.context.scene.collection
    build_materials()
    build_parts()
    objs = build_objects(col)
    cutter = slot_cutter(col)
    apply_bool(objs['HeatShroud'], cutter)
    bpy.data.objects.remove(cutter)
    cc = collar_cutter(col)
    apply_bool(objs['TankCollar'], cc)
    bpy.data.objects.remove(cc)
    for ob in objs.values():
        ob.data.set_sharp_from_angle(angle=math.radians(38 if SEGQ >= 0.99 else 64))

    tris = tri_counts({k: v for k, v in objs.items() if k != 'PilotFlame'})
    total = sum(tris.values())
    print('TRIS', total, sorted(tris.items(), key=lambda kv: -kv[1]), flush=True)

    setup_scene(args)
    floor = add_floor(col, FLOOR_Z)
    rig = Rig(col)
    flame_tip = objs['PilotFlame'].data.vertices[-1].co
    rig.glow.location = V((0.60, 0, -0.072))

    weapon = [o for n, o in objs.items()]
    lo, hi = world_bbox([o for o in weapon if o.name != 'PilotFlame'])
    print('BBOX', tuple(round(v, 3) for v in lo), tuple(round(v, 3) for v in hi), 'length', round(hi.x - lo.x, 3), flush=True)
    full = (lo, hi)
    rendered = []

    def want(tag):
        return not only or tag in only

    def shot(tag, name, **kw):
        if not want(tag):
            return
        rig.frame(**kw)
        p = os.path.join(args.out, f'{tag}_{name}.png')
        render(p)
        rendered.append(p)

    sel = lambda names: world_bbox([objs[n] for n in names])

    shot('01', 'front', bbox=full, view_dir=(1, -0.22, 0.16), lens=110, margin=1.25)
    shot('02', 'side_profile', bbox=full, view_dir=(0, -1, 0.02), ortho=True, margin=1.1)
    shot('03', 'three_quarter_front', bbox=full, view_dir=(0.8, -0.85, 0.42), lens=60, margin=1.08)
    shot('04', 'three_quarter_back', bbox=full, view_dir=(-0.8, 0.8, 0.45), lens=60, margin=1.08)
    shot('05', 'top', bbox=full, view_dir=(0, -0.001, 1), ortho=True, margin=1.12, up=(0, 1, 0))
    shot('06', 'closeup_grip_trigger_hose', bbox=(V((-0.69, -0.05, -0.12)), V((-0.29, 0.03, 0.06))),
         view_dir=(0.35, -1, 0.35), lens=85, margin=1.05)
    shot('07', 'closeup_tank_valve_gauge', bbox=(V((-0.31, -0.10, -0.20)), V((0.0, 0.06, 0.0))),
         view_dir=(-0.45, -1, 0.3), lens=85, margin=1.03)
    shot('08', 'closeup_muzzle_shroud_pilot', bbox=(V((0.33, -0.08, -0.10)), V((0.63, 0.08, 0.08))),
         view_dir=(0.75, -1, 0.15), lens=85, margin=1.03)

    if want('09'):
        for ob in weapon:
            ob.location = V(EXPLODE.get(ob['group'], (0, 0, 0)))
        rig.glow.location = V((0.60, 0, -0.072)) + V(EXPLODE['pilot'])
        floor.location.z = FLOOR_Z - 0.25
        lo2, hi2 = world_bbox([o for o in weapon if o.name != 'PilotFlame'])
        shot('09', 'exploded', bbox=(lo2, hi2), view_dir=(0.45, -1, 0.42), lens=50, margin=1.06)
        for ob in weapon:
            ob.location = (0, 0, 0)
        rig.glow.location = V((0.60, 0, -0.072))
        floor.location.z = FLOOR_Z

    if want('10'):
        cut_names = ['Tank', 'TankCollar', 'Valve', 'FeedPipe', 'Barrel', 'HeatShroud', 'Muzzle', 'NozzleGrip',
                     'TankMount', 'FrontGrip']
        cuts, sbox = cut_half(col, objs, cut_names)
        for n in cut_names:
            objs[n].hide_render = True
        for n in ('TankLabel', 'Gauge', 'Regulator', 'PilotLine', 'Hose', 'HoseFittings', 'TapeHose', 'TapeFeed', 'TapeGrip'):
            objs[n].hide_render = True
        shot('10', 'cutaway', bbox=full, view_dir=(0.12, -1, 0.22), lens=60, margin=1.05)
        for n in objs:
            objs[n].hide_render = False
        for ob in cuts + [sbox]:
            bpy.data.objects.remove(ob)

    if want('11'):
        dummy, arms = build_dummy(col)
        s = 0.28
        floor.location.z = 0.0
        # right arm forward/down holding the pump grip, left arm reaching for the front grip
        arms['R'].rotation_euler = (0, math.radians(-62), 0)
        arms['L'].rotation_euler = (math.radians(-12), math.radians(-88), 0)
        hand_local = V((0, 0, -1.55 * s))
        handR = arms['R'].matrix_basis @ hand_local
        rigE = bpy.data.objects.new('WeaponRig', None)
        col.objects.link(rigE)
        for ob in weapon:
            ob.parent = rigE
        rigE.rotation_euler = (0, math.radians(-6), 0)
        bpy.context.view_layer.update()
        grip_local = V((-0.455, 0, 0.0))
        rigE.location = handR - (rigE.matrix_world.to_3x3() @ grip_local) + V((0, -0.05, 0))
        bpy.context.view_layer.update()
        rig.glow.location = rigE.matrix_world @ V((0.60, 0, -0.072))
        lo3, hi3 = world_bbox(dummy + [o for o in weapon if o.name != 'PilotFlame'])
        lo3.z = 0.0
        shot('11', 'scale_r6_dummy', bbox=(lo3, hi3), view_dir=(0.85, -1, 0.35), lens=50, margin=1.08,
             light_scale=1.4)
        shot('12', 'scale_r6_dummy_side', bbox=(lo3, hi3), view_dir=(0, -1, 0.05), ortho=True, margin=1.1,
             light_scale=1.4)
        for ob in weapon:
            ob.parent = None
            ob.matrix_world = Matrix()
        for ob in dummy + [rigE]:
            bpy.data.objects.remove(ob)
        floor.location.z = FLOOR_Z
        rig.glow.location = V((0.60, 0, -0.072))

    files = sorted(os.path.join(args.out, f) for f in os.listdir(args.out)
                   if f[:2].isdigit() and f.endswith('.png'))
    if files:
        print('SHEET', contact_sheet(args.out, files), flush=True)

    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.blend))
        print('BLEND', args.blend, flush=True)
    if args.fbx:
        SEGQ = args.game_q
        PARTS.clear()
        bpy.ops.wm.read_factory_settings(use_empty=True)
        col = bpy.context.scene.collection
        MAT.clear()
        build_materials()
        build_parts()
        gobjs = build_objects(col)
        for nm, cut in (('HeatShroud', slot_cutter(col)), ('TankCollar', collar_cutter(col))):
            apply_bool(gobjs[nm], cut)
            bpy.data.objects.remove(cut)
            gobjs[nm].data.set_sharp_from_angle(angle=math.radians(64))
        gt = tri_counts({k: v for k, v in gobjs.items() if k != 'PilotFlame'})
        print('GAME TRIS', sum(gt.values()), sorted(gt.items(), key=lambda kv: -kv[1]), flush=True)
        export_fbx(gobjs, args.fbx)


def export_fbx(objs, path):
    """Separate named mesh parts, metres (import in Roblox with 'Meter' units), no flame/studio."""
    for ob in bpy.context.scene.objects:
        ob.select_set(False)
    keep = [o for n, o in objs.items() if n != 'PilotFlame']
    for ob in keep:
        ob.select_set(True)
        if not ob.data.uv_layers:
            # simple box-projected UVs so the parts can take textures later
            me = ob.data
            uv = me.uv_layers.new(name='UVMap')
            lo, hi = world_bbox([ob])
            ext = max((hi - lo).x, (hi - lo).y, (hi - lo).z, 1e-4)
            for poly in me.polygons:
                nrm = poly.normal
                ax = max(range(3), key=lambda k: abs(nrm[k]))
                u_i, v_i = [(1, 2), (0, 2), (0, 1)][ax]
                for li in poly.loop_indices:
                    co = me.vertices[me.loops[li].vertex_index].co
                    uv.data[li].uv = ((co[u_i] - lo[u_i]) / ext, (co[v_i] - lo[v_i]) / ext)
    bpy.context.view_layer.objects.active = keep[0]
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=os.path.abspath(path), use_selection=True, object_types={'MESH'},
                             apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS', axis_forward='-Z',
                             axis_up='Y', mesh_smooth_type='FACE', use_mesh_modifiers=True, add_leaf_bones=False,
                             bake_anim=False, path_mode='STRIP')
    print('FBX', path, flush=True)


if __name__ == '__main__':
    main()
