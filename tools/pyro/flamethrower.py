#!/usr/bin/env python3
"""Improvised flamethrower for the Pyromaniac's finisher (look-dev only, no game code).

Builds the model from code (bmesh), gives it procedural PBR-ish materials, renders a set of
studio views, writes a contact sheet, saves the .blend and exports a Roblox-friendly FBX
(separate named parts, no flame, no dummy).

Design (original junk build, v2 - moved away from the TF2 layout):
  * a red fuel-pump nozzle is the PISTOL GRIP: tilted 22 deg down under the feed pipe, its spout
    cut short and strapped to the pipe.  Its trigger pulls a bicycle brake cable that runs
    forward along the pipe and opens a ball valve (spring return);
  * a bent galvanised-conduit LOOP STOCK behind the grip, butt wrapped in inner tube and tape;
  * a repainted olive-drab gas bottle hangs on the RIGHT flank, forward of the grips and tilted
    10 deg nose-down, held by band clamps (rubber strips, ears, bolts) on an angle-iron rail
    welded to two pipe clamps on the shroud;
  * a squat diaphragm regulator + gauge on the bottle valve, a short hose into a T on the pipe,
    a copper pilot line tied down along the bottle to a burner on a welded tab under the muzzle;
  * a fat, short exhaust-tube shroud with uneven hand-drilled holes and welded end plates;
  * a slash-cut reducer tip (no bell, no cone), heat-blued crown, soot crusted inside;
  * a wooden file handle as the foregrip, on a bent strap with a bolt, a hose clamp and tape.

Axes: +X forward (muzzle), +Z up, metres.  1 stud = 0.28 m.

Usage:
  /home/user/z-anatomy/venv/bin/python -I tools/pyro/flamethrower.py --out DIR \
      [--blend X.blend] [--fbx assets/pyro/Flamethrower.fbx] [--samples 96] [--only 01,02] [--quick]
      [--tf2-ref path/to/reference.png]   (only used for the 16_silhouette comparison)
"""
import argparse
import json
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


def hi_q():
    return SEGQ >= 0.99


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)

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


def basis(X, Y, Z):
    return Matrix((V(X), V(Y), V(Z))).transposed()


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


def tube(bm, p0, p1, rin, rout, segs=16, mi=0, rings=0, pert=None):
    p0, p1 = V(p0), V(p1)
    L = (p1 - p0).length
    rings = rings if hi_q() else min(rings, 1)
    xs = [L * i / (rings + 1) for i in range(rings + 2)]
    prof = [(0, rin), (0, rout)] + [(x, rout) for x in xs[1:-1]] + [(L, rout), (L, rin)] + \
        [(x, rin) for x in reversed(xs[1:-1])]
    lathe(bm, prof, segs, frame_x(p0, p1 - p0), closed=True, mi=mi, pert=pert)


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


RECT = [(1, 1), (-1, 1), (-1, -1), (1, -1)]


def sweep(bm, pts, r, segs=12, caps=(True, True), rz=None, sq=2.0, mi=0, closed=False, upref=None, prof=None):
    """Sweep a (super)ellipse (or `prof`, a list of unit (c, s) points) along a polyline with
    parallel-transport frames.  r = half size along the side normal N, rz = along B = T x N."""
    P = [V(p) for p in pts]
    n = len(P)
    rs = list(r) if isinstance(r, (list, tuple)) else [r] * n
    if rz is None:
        rzs = rs
    else:
        rzs = list(rz) if isinstance(rz, (list, tuple)) else [rz] * n
    if prof is None:
        segs = q(segs, 4)
        prof = []
        for j in range(segs):
            a = TAU * j / segs
            c, s = math.cos(a), math.sin(a)
            if sq != 2.0:
                c = math.copysign(abs(c) ** (2 / sq), c)
                s = math.copysign(abs(s) ** (2 / sq), s)
            prof.append((c, s))
    segs = len(prof)
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
        rings.append([bm.verts.new(P[i] + N * (rs[i] * c) + B * (rzs[i] * s)) for c, s in prof])
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


def torus(bm, c, axis, R, r, su=24, sv=6, mi=0, bump=0.0, seed=0, ripple=0.0):
    M = frame_x(c, axis)
    su = q(su, 8)
    rnd = random.Random(seed)
    pts, rs = [], []
    for i in range(su):
        a = TAU * i / su
        pts.append(M @ V((0, R * math.cos(a), R * math.sin(a))))
        rs.append(r * (1 + bump * (rnd.random() - 0.5) * 2 + ripple * (1 if i % 2 else -1)))
    sweep(bm, pts, rs, sv, closed=True, mi=mi)


def weld_ring(bm, c, axis, R, r=0.0028, seed=0, mi=0):
    """A bead of stacked weld 'dimes' (ripple) with an uneven size."""
    if hi_q():
        torus(bm, c, axis, R, r, 56, 6, mi, bump=0.22, seed=seed, ripple=0.14)
    else:
        torus(bm, c, axis, R, r * 1.1, 8, 3, mi)


def weld_line(bm, pts, r=0.0025, seed=0, mi=0):
    P = crs(pts, 6)
    rnd = random.Random(seed)
    rs = [r * (1 + 0.2 * (rnd.random() - 0.5) * 2 + (0.13 * (1 if i % 2 else -1) if hi_q() else 0)) for i in range(len(P))]
    rs[0] *= 0.5
    rs[-1] *= 0.5
    sweep(bm, P, rs, 6 if hi_q() else 3, mi=mi)


def hexbolt(bm, p, axis, size=0.006, length=0.008, mi=0, washer=True, shank=True):
    """Hex head (or nut) + washer, head facing along axis."""
    p, axis = V(p), V(axis).normalized()
    if not hi_q():
        lathe(bm, [(0, 0), (0, size), (length * 0.55, size), (length * 0.55, 0)], 6, frame_x(p, axis), mi=mi)
        return
    if washer:
        cyl(bm, p - axis * 0.0006, p + axis * 0.0008, size * 1.35, 12, mi)
    lathe(bm, [(0, 0), (0, size), (length * 0.55, size), (length * 0.55, 0)], 6,
          frame_x(p + axis * 0.0008, axis), mi=mi)
    if shank:
        cyl(bm, p + axis * (0.0008 + length * 0.55), p + axis * (0.0008 + length), size * 0.5, 8, mi)


def tape_wrap(bm, p0, p1, r, width=0.013, seed=0, mi=0, tail=True, segs=20, lump=0.0004):
    """Overlapping, slightly skewed turns of tape, a little lumpy, with a frayed loose tail."""
    p0, p1 = V(p0), V(p1)
    ax = (p1 - p0)
    L = ax.length
    ax.normalize()
    M = frame_x(p0, ax)
    rnd = random.Random(seed)
    if not hi_q():
        lathe(bm, [(0, r), (0, r + 0.0012), (L, r + 0.0012), (L, r)], 10, M, closed=True, mi=mi)
        return
    n = max(2, int(L / (width * 0.62)) + 1)
    segs = q(segs, 8)
    last = None
    for k in range(n):
        x = width / 2 + (L - width) * k / (n - 1)
        tilt = math.tan(math.radians(rnd.uniform(5, 10)))
        ph = rnd.uniform(0, TAU)
        rr = r + 0.0005 + 0.00035 * (k % 3)
        pts = []
        for i in range(segs):
            a = TAU * i / segs
            dx = tilt * rr * math.cos(a + ph)
            rl = rr + lump * rnd.random()
            pts.append(M @ V((x + dx, rl * math.cos(a), rl * math.sin(a))))
        sweep(bm, pts, width / 2, closed=True, rz=0.0004, upref=ax, prof=RECT, mi=mi)
        last = (x, rr)
    if tail and last:
        x, rr = last
        a0 = rnd.uniform(-0.6, 0.6) - math.pi / 2
        base = M @ V((x, rr * math.cos(a0), rr * math.sin(a0)))
        tang = (M.to_3x3() @ V((0, -math.sin(a0), math.cos(a0)))).normalized()
        down = V((0, 0, -1))
        flap = (tang * 0.4 + down).normalized()
        side = ax
        nrm = flap.cross(side).normalized()
        Rm = basis(side, nrm, flap)
        box(bm, base + flap * 0.008, (width * 0.9, 0.0005, 0.016), Rm, mi)
        for j in range(4):   # frayed threads
            off = (j - 1.5) / 1.5 * width * 0.38
            ln = 0.002 + 0.004 * rnd.random()
            box(bm, base + side * off + flap * (0.016 + ln / 2), (width * 0.12, 0.0004, ln), Rm, mi)


def band_clamp(bm, c, axis, R, width, th, ear_dir, mi=0, nut_mi=None, ear_len=0.016, bolt=True, segs=40):
    """Steel band clamp around a cylinder: band + two ears + a tightening bolt and nut."""
    c, axis, ear_dir = V(c), V(axis).normalized(), V(ear_dir).normalized()
    M = frame_x(c - axis * width / 2, axis)
    lathe(bm, [(0, R), (0, R + th), (width, R + th), (width, R)], segs, M, closed=True, mi=mi)
    t = axis.cross(ear_dir).normalized()
    Rm = basis(axis, t, ear_dir)
    for s in (-1, 1):
        box(bm, c + ear_dir * (R + ear_len / 2) + t * s * 0.0036, (width * 0.9, 0.0028, ear_len), Rm, mi)
    if bolt:
        bc = c + ear_dir * (R + ear_len * 0.62)
        hexbolt(bm, bc + t * 0.0050, t, 0.0042, 0.016, nut_mi if nut_mi is not None else mi)
        hexbolt(bm, bc - t * 0.0050, -t, 0.0042, 0.004, nut_mi if nut_mi is not None else mi, shank=False)


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

    def scaled(self, s, vec=None):
        """Object coords scaled per axis (stretched noise = scratches / streaks)."""
        vm = self.n('ShaderNodeVectorMath', operation='MULTIPLY')
        self.l(vec if vec is not None else self.obj(), vm.inputs[0])
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

    def ramp(self, fac, stops):
        r = self.n('ShaderNodeValToRGB')
        els = r.color_ramp.elements
        while len(els) < len(stops):
            els.new(0.5)
        for el, (pos, col) in zip(els, stops):
            el.position = pos
            el.color = col
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

    def mul(self, a, b):
        return self.math('MULTIPLY', a, b, clamp=False)

    def mixc(self, fac, a, b):
        mx = self.n('ShaderNodeMix', data_type='RGBA', clamp_factor=True)
        for idx, v in ((0, fac), (6, a), (7, b)):
            if isinstance(v, bpy.types.NodeSocket):
                self.l(v, mx.inputs[idx])
            else:
                mx.inputs[idx].default_value = v
        return mx.outputs[2]

    def mixf(self, fac, a, b):
        mx = self.n('ShaderNodeMix', data_type='FLOAT', clamp_factor=True)
        for idx, v in ((0, fac), (2, a), (3, b)):
            if isinstance(v, bpy.types.NodeSocket):
                self.l(v, mx.inputs[idx])
            else:
                mx.inputs[idx].default_value = v
        return mx.outputs[0]

    def axis(self, k, vec=None):
        sep = self.n('ShaderNodeSeparateXYZ')
        self.l(vec if vec is not None else self.obj(), sep.inputs[0])
        return sep.outputs[k]

    def edge(self, radius=0.0018, a=0.02, b=0.20):
        """Convex/concave edge mask from the bevel-normal trick (curvature-like)."""
        bev = self.n('ShaderNodeBevel', {'Radius': radius}, samples=8)
        geo = self.n('ShaderNodeNewGeometry')
        dot = self.n('ShaderNodeVectorMath', operation='DOT_PRODUCT')
        self.l(bev.outputs['Normal'], dot.inputs[0])
        self.l(geo.outputs['Normal'], dot.inputs[1])
        return self.mask(self.math('SUBTRACT', 1.0, dot.outputs['Value']), a, b)

    def cavity(self, dist=0.012, a=0.15, b=0.75):
        ao = self.n('ShaderNodeAmbientOcclusion', {'Distance': dist}, only_local=True, samples=8)
        return self.mask(self.math('SUBTRACT', 1.0, ao.outputs['AO']), a, b)

    def attr(self, name):
        at = self.n('ShaderNodeAttribute', attribute_name=name)
        return at.outputs['Factor']

    def bump(self, height, strength=0.2, distance=0.002, normal=None):
        b = self.n('ShaderNodeBump', {'Strength': strength, 'Distance': distance})
        self.l(height, b.inputs['Height'])
        if normal is not None:
            self.l(normal, b.inputs['Normal'])
        return b.outputs['Normal']

    def add(self, *vals):
        acc = vals[0]
        for v in vals[1:]:
            acc = self.math('ADD', acc, v, clamp=False)
        return acc

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


def make_decal(path):
    """Stencilled bottle markings (cream paint, sprayed through a card stencil)."""
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
    W, H = 2048, 640
    im = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(im)
    big = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 230)
    small = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 88)
    txt = 'PROPANE'
    x0, y0 = 120, 70
    d.text((x0, y0), txt, fill=255, font=big)
    # stencil bridges: cut a vertical gap through every letter
    xx = x0
    for ch in txt:
        w = d.textlength(ch, font=big)
        d.rectangle((xx + w * 0.47, y0 + 30, xx + w * 0.47 + 16, y0 + 300), fill=0)
        xx += w
    d.text((x0 + 10, 400), 'FLAMMABLE  GAS', fill=255, font=small)
    d.text((x0 + 860, 400), '- NO SMOKING', fill=255, font=small)
    # hazard diamond
    cx, cy, r = 1820, 300, 210
    d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], outline=255, width=26)
    d.text((cx - 50, cy - 80), '2', fill=255, font=ImageFont.truetype(
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 150))
    im = im.filter(ImageFilter.GaussianBlur(2.2))      # overspray softness
    rgba = Image.merge('RGBA', (im, im, im, im))
    rgba.save(path)
    return path


def build_materials(decal_path=None):
    # --- dark oxidised steel: edge wear to bare metal, streaky grime, rust in cavities -------
    m = NB('SteelDark')
    e = m.edge(0.0018, 0.03, 0.22)
    wear = m.mul(e, m.mask(m.noise(38, 6, 0.6), 0.32, 0.55))
    cav = m.cavity(0.014)
    streak = m.mul(m.mask(m.noise(2.2, 6, 0.6, vec=m.scaled((90, 90, 6))), 0.52, 0.72), m.mask(m.noise(5, 3, 0.5), 0.35, 0.6))
    grime = m.math('MAXIMUM', m.mask(m.noise(9, 8, 0.6), 0.52, 0.8), m.mul(cav, 0.95))
    var = m.noise(24, 4, 0.5)
    base = m.mixc(var, C(0.060, 0.058, 0.054), C(0.040, 0.036, 0.031))
    base = m.mixc(m.mul(streak, 0.75), base, C(0.034, 0.025, 0.016))
    base = m.mixc(grime, base, C(0.026, 0.019, 0.012))
    rust = m.mul(m.mask(m.noise(28, 8, 0.7), 0.62, 0.72), m.math('MAXIMUM', cav, 0.25))
    base = m.mixc(rust, base, C(0.15, 0.055, 0.018))
    base = m.mixc(wear, base, C(0.40, 0.40, 0.41))
    scr = m.mul(m.mask(m.noise(3, 3, 0.5, vec=m.scaled((8, 200, 200))), 0.62, 0.655), m.mask(m.noise(4, 2, 0.5), 0.4, 0.6))
    base = m.mixc(m.mul(scr, 0.8), base, C(0.30, 0.30, 0.31))
    rough = m.mixf(m.mask(m.noise(6, 6, 0.6), 0.3, 0.7), 0.50, 0.78)
    rough = m.mixf(m.math('MAXIMUM', grime, rust), rough, 0.88)
    rough = m.mixf(m.math('MAXIMUM', wear, scr), rough, 0.28)
    wear = m.math('MAXIMUM', wear, scr)
    metal = m.mixf(m.math('MAXIMUM', grime, rust), 0.85, 0.25)
    metal = m.mixf(wear, metal, 1.0)
    nrm = m.bump(m.add(m.noise(320, 3, 0.6), m.mul(rust, 0.7), m.mul(wear, -0.3)), 0.12)
    m.bsdf(base, metal, rough, nrm)

    # --- galvanised conduit: dull zinc spangle, white rust, dirt ----------------------------
    m = NB('Galv')
    vor = m.n('ShaderNodeTexVoronoi', {'Scale': 90})
    m.l(m.obj(), vor.inputs['Vector'])
    sp = m.mask(vor.outputs['Distance'], 0.05, 0.6)
    dirt = m.math('MAXIMUM', m.mask(m.noise(8, 8, 0.6), 0.48, 0.8), m.cavity(0.012))
    wrust = m.mask(m.noise(30, 8, 0.7), 0.66, 0.72)
    base = m.mixc(sp, C(0.30, 0.31, 0.31), C(0.22, 0.225, 0.23))
    base = m.mixc(dirt, base, C(0.05, 0.04, 0.03))
    base = m.mixc(wrust, base, C(0.45, 0.44, 0.40))
    base = m.mixc(m.mul(m.mask(m.noise(2.2, 6, 0.6, vec=m.scaled((90, 90, 6))), 0.5, 0.72), 0.7), base, C(0.07, 0.06, 0.05))
    e = m.mul(m.edge(0.002, 0.03, 0.2), 0.8)
    base = m.mixc(e, base, C(0.45, 0.46, 0.47))
    m.bsdf(base, m.mixf(m.math('MAXIMUM', dirt, wrust), 0.9, 0.2), m.mixf(dirt, m.mixf(sp, 0.42, 0.6), 0.85),
           m.bump(m.add(m.noise(400, 3, 0.6), m.mul(wrust, 0.8)), 0.1))

    # --- heat-treated / sooted steel (shroud, barrel, muzzle) -----------------------------
    def heat(name, x_cold, x_hot, soot_start=0.80, base_col=(0.055, 0.052, 0.048), soot_end=1.0):
        m = NB(name)
        x = m.axis(0)
        nz = m.noise(14, 6, 0.6)
        bc = C(*base_col)
        t = m.mask(m.add(x, m.mul(m.math('SUBTRACT', nz, 0.5, clamp=False), 0.035 * (x_hot - x_cold) / 0.2)), x_cold, x_hot)
        heatc = m.ramp(t, [(0.00, bc), (0.30, bc), (0.40, C(0.17, 0.13, 0.075)),
                           (0.50, C(0.13, 0.075, 0.045)), (0.60, C(0.075, 0.050, 0.065)), (0.70, C(0.050, 0.056, 0.085)),
                           (0.82, C(0.055, 0.055, 0.058)), (1.0, C(0.04, 0.04, 0.041))])
        oxid = m.mask(m.noise(9, 8, 0.65), 0.35, 0.7)      # patchy oxide, so the bands are not clean rings
        heatc = m.mixc(m.mul(oxid, 0.55), heatc, m.mixc(t, bc, C(0.05, 0.048, 0.046)))
        heatband = m.math('MULTIPLY', m.mask(t, 0.32, 0.42), m.math('SUBTRACT', 1.0, m.mask(t, 0.80, 0.95)))
        e = m.edge(0.0018, 0.03, 0.2)
        wear = m.mul(e, m.mask(m.noise(40, 6, 0.6), 0.4, 0.6))
        streak = m.mul(m.mask(m.noise(2.0, 6, 0.6, vec=m.scaled((90, 90, 6))), 0.5, 0.7), 0.6)
        base = m.mixc(streak, heatc, C(0.03, 0.022, 0.016))
        base = m.mixc(wear, base, C(0.33, 0.33, 0.34))
        soot_attr = m.attr('soot')
        soot = m.math('MAXIMUM', m.mask(t, soot_start, soot_end),
                      m.mul(m.mask(soot_attr, 0.04, 0.45), m.mixf(m.noise(55, 6, 0.7), 0.55, 1.0)))
        soot = m.math('MAXIMUM', soot, m.mul(m.cavity(0.012), 0.8))
        soot = m.mul(soot, m.mixf(m.noise(30, 5, 0.6), 0.75, 1.0))
        base = m.mixc(soot, base, C(0.006, 0.0055, 0.005))
        rough = m.mixf(heatband, m.mixf(oxid, 0.58, 0.74), 0.5)
        rough = m.mixf(wear, rough, 0.3)
        rough = m.mixf(soot, rough, 0.95)
        metal = m.mixf(soot, m.mixf(oxid, 0.85, 0.45), 0.0)
        rust = m.mask(m.noise(30, 6, 0.7), 0.68, 0.75)
        base = m.mixc(m.mul(rust, 0.7), base, C(0.15, 0.06, 0.02))
        nrm = m.bump(m.add(m.noise(200, 5, 0.7), m.mul(rust, 0.5), m.mul(soot, 0.6)), 0.18)
        pb = m.bsdf(base, metal, rough, nrm)
        m.l(m.mixf(soot, 0.5, 0.08), pb.inputs['Specular IOR Level'])
    heat('ShroudHeat', 0.30, 0.53, 0.86, base_col=(0.105, 0.095, 0.085))
    heat('BarrelHeat', 0.20, 0.55, 0.85)
    heat('MuzzleHeat', 0.50, 0.66, 0.66, base_col=(0.09, 0.083, 0.075), soot_end=0.92)

    # --- soot crust inside the muzzle, burnt-orange scale on the cut lip ----------------------
    m = NB('SootInner')
    x = m.axis(0)
    sc = m.mul(m.mask(x, 0.58, 0.64), m.mask(m.noise(45, 8, 0.7), 0.45, 0.62))
    base = m.mixc(m.mask(m.noise(60, 6, 0.6), 0.3, 0.7), C(0.008, 0.007, 0.006), C(0.022, 0.018, 0.014))
    base = m.mixc(sc, base, C(0.20, 0.075, 0.025))
    m.bsdf(base, 0.0, 0.96, m.bump(m.noise(150, 8, 0.75), 0.6))
    m = NB('LipScale')
    sc = m.mask(m.noise(40, 8, 0.7), 0.35, 0.6)
    base = m.mixc(sc, C(0.06, 0.035, 0.022), C(0.24, 0.09, 0.03))
    base = m.mixc(m.mul(m.mask(m.noise(90, 4, 0.6), 0.6, 0.7), 0.7), base, C(0.3, 0.3, 0.31))
    m.bsdf(base, m.mixf(sc, 0.6, 0.1), 0.75, m.bump(m.noise(140, 8, 0.7), 0.5))

    # --- red powder coat on cast aluminium: fine bump, chips down to grey alloy -----------------
    m = NB('PaintRed')
    e = m.edge(0.0025, 0.03, 0.20)
    chip = m.math('MAXIMUM', m.mul(e, m.mask(m.noise(30, 8, 0.65), 0.42, 0.56)),
                  m.mask(m.noise(14, 10, 0.65, distort=0.25), 0.665, 0.675))
    cav = m.cavity(0.01)
    paint = m.mixc(m.mask(m.noise(40, 4, 0.5), 0.3, 0.7), C(0.30, 0.026, 0.018), C(0.23, 0.03, 0.02))
    paint = m.mixc(m.mul(m.math('MAXIMUM', cav, m.mask(m.noise(7, 8, 0.6), 0.55, 0.8)), 0.8), paint, C(0.06, 0.03, 0.018))
    base = m.mixc(chip, paint, C(0.42, 0.42, 0.43))
    rough = m.mixf(chip, m.mixf(cav, 0.40, 0.75), 0.35)
    nrm = m.bump(m.add(m.mul(chip, -0.25), m.mul(m.noise(1100, 2, 0.5), 0.35)), 0.06, 0.001)
    m.bsdf(base, m.mixf(chip, 0.0, 1.0), rough, nrm)

    # --- olive-drab repaint over an old red bottle, stencils, wear by edges/straps/gravity -------
    m = NB('BottlePaint')
    uv = m.n('ShaderNodeUVMap')
    us = m.axis(0, uv.outputs['UV'])
    vs = m.axis(1, uv.outputs['UV'])
    wz = m.axis(2)
    big = m.noise(3, 4, 0.5)
    base = m.mixc(big, C(0.105, 0.11, 0.058), C(0.075, 0.08, 0.042))
    base = m.mixc(m.mul(m.mask(m.noise(1.6, 3, 0.5), 0.55, 0.8), 0.6), base, C(0.15, 0.15, 0.10))   # sun-faded patches
    # stencil decal (u around, v along): image x <- v, image y <- u
    if decal_path:
        img = bpy.data.images.load(decal_path)
        img.pack()
        tex = m.n('ShaderNodeTexImage', image=img, extension='CLIP', interpolation='Linear')
        cx = m.n('ShaderNodeCombineXYZ')
        m.l(m.math('MULTIPLY', m.math('SUBTRACT', vs, 0.14, clamp=False), 1 / 0.72, clamp=False), cx.inputs[0])
        m.l(m.math('ADD', m.math('MULTIPLY', m.math('SUBTRACT', us, 0.5, clamp=False), -1 / 0.26, clamp=False), 0.5,
                   clamp=False), cx.inputs[1])
        m.l(cx.outputs[0], tex.inputs['Vector'])
        dmask = m.mul(tex.outputs['Alpha'], m.mixf(m.mask(m.noise(16, 8, 0.65), 0.45, 0.62), 0.8, 0.0))
        dmask = m.mul(dmask, m.mixf(m.mask(m.noise(60, 6, 0.7), 0.4, 0.6), 1.0, 0.55))
        base = m.mixc(dmask, base, C(0.33, 0.31, 0.24))
    else:
        dmask = 0.0
    # wear masks
    e = m.edge(0.0035, 0.03, 0.18)
    straps = m.math('MAXIMUM', m.mask(m.math('ABSOLUTE', m.math('SUBTRACT', vs, 0.3125, clamp=False)), 0.06, 0.03),
                    m.mask(m.math('ABSOLUTE', m.math('SUBTRACT', vs, 0.6875, clamp=False)), 0.06, 0.03))
    ends = m.math('MAXIMUM', m.mask(vs, 0.16, 0.04), m.mask(vs, 0.86, 0.97))
    wearzone = m.math('MAXIMUM', m.math('MAXIMUM', e, m.mul(straps, 0.85)), m.mul(ends, 0.8))
    chipn = m.noise(22, 10, 0.65, distort=0.25)
    chip1 = m.mul(m.mask(chipn, m.mixf(wearzone, 0.75, 0.42), m.mixf(wearzone, 0.77, 0.47)), 1.0)
    chip2 = m.mask(chipn, m.mixf(wearzone, 0.85, 0.52), m.mixf(wearzone, 0.86, 0.55))
    base = m.mixc(chip1, base, C(0.21, 0.035, 0.025))           # the old red under the olive repaint
    base = m.mixc(chip2, base, C(0.09, 0.05, 0.03))             # bare, rusting steel
    # gravity streaks running down from straps and from the chips
    streakn = m.mask(m.noise(2.4, 6, 0.6, vec=m.scaled((110, 110, 4))), 0.56, 0.72)
    src = m.math('MAXIMUM', m.mul(straps, 0.9), m.mul(m.mask(m.noise(4, 4, 0.5), 0.55, 0.7), 0.6))
    drip = m.mul(streakn, src)
    base = m.mixc(m.mul(drip, 0.85), base, C(0.17, 0.065, 0.022))
    low = m.mask(wz, -0.165, -0.215)
    grime = m.math('MAXIMUM', m.mul(low, m.mask(m.noise(6, 8, 0.6), 0.25, 0.55)), m.mul(m.cavity(0.015), 0.9))
    base = m.mixc(m.mul(grime, 0.85), base, C(0.035, 0.03, 0.02))
    # scratches through the olive coat, and dust settled on the upward faces
    scr = m.mask(m.noise(3, 3, 0.5, vec=m.scaled((14, 260, 260))), 0.63, 0.66)
    base = m.mixc(m.mul(scr, 0.7), base, C(0.20, 0.05, 0.03))
    geo = m.n('ShaderNodeNewGeometry')
    upz = m.axis(2, geo.outputs['Normal'])
    dust = m.mul(m.mask(upz, 0.35, 0.9), m.mask(m.noise(12, 6, 0.6), 0.3, 0.7))
    base = m.mixc(m.mul(dust, 0.55), base, C(0.20, 0.18, 0.14))
    grime = m.math('MAXIMUM', grime, m.mul(dust, 0.6))
    rough = m.mixf(grime, m.mixf(big, 0.55, 0.7), 0.85)
    rough = m.mixf(chip2, rough, 0.5)
    nrm = m.bump(m.add(m.mul(chip1, -0.25), m.mul(chip2, -0.3), m.mul(m.noise(500, 3, 0.6), 0.4), m.mul(dmask, 0.15)), 0.12)
    m.bsdf(base, m.mixf(chip2, 0.0, 0.5), rough, nrm)

    # --- rubber (hose, boot, butt wrap) with dust in the cavities --------------------------
    m = NB('Rubber')
    dust = m.math('MAXIMUM', m.mask(m.noise(9, 6, 0.6), 0.55, 0.85), m.mul(m.cavity(0.008), 0.9))
    e = m.mul(m.edge(0.0015, 0.03, 0.2), 0.5)
    base = m.mixc(m.mul(dust, 0.7), C(0.018, 0.018, 0.019), C(0.10, 0.09, 0.075))
    base = m.mixc(e, base, C(0.05, 0.05, 0.05))
    m.bsdf(base, 0.0, m.mixf(dust, m.mixf(e, 0.6, 0.45), 0.92), m.bump(m.noise(500, 2, 0.5), 0.15))

    # --- brass: tarnish, polished on the edges -------------------------------------------------
    m = NB('Brass')
    tarn = m.math('MAXIMUM', m.mask(m.noise(12, 7, 0.65), 0.4, 0.75), m.cavity(0.008))
    e = m.edge(0.0012, 0.03, 0.2)
    base = m.mixc(tarn, C(0.50, 0.35, 0.14), C(0.12, 0.09, 0.04))
    base = m.mixc(e, base, C(0.72, 0.55, 0.26))
    m.bsdf(base, 1.0, m.mixf(e, m.mixf(tarn, 0.3, 0.62), 0.2), m.bump(m.noise(200, 3, 0.6), 0.08))

    m = NB('ZincCast')
    dirt = m.math('MAXIMUM', m.mask(m.noise(9, 8, 0.6), 0.5, 0.8), m.cavity(0.01))
    e = m.edge(0.0015, 0.03, 0.2)
    base = m.mixc(m.noise(40, 4, 0.5), C(0.26, 0.26, 0.255), C(0.20, 0.20, 0.195))
    base = m.mixc(dirt, base, C(0.045, 0.04, 0.032))
    base = m.mixc(e, base, C(0.42, 0.42, 0.42))
    m.bsdf(base, 0.75, m.mixf(dirt, m.mixf(e, 0.5, 0.3), 0.85), m.bump(m.noise(500, 3, 0.6), 0.12))

    m = NB('Copper')
    tarn = m.mask(m.noise(15, 6, 0.6), 0.35, 0.75)
    base = m.mixc(tarn, C(0.50, 0.22, 0.11), C(0.10, 0.065, 0.04))
    base = m.mixc(m.mul(m.mask(m.noise(25, 6, 0.6), 0.65, 0.72), 0.8), base, C(0.07, 0.17, 0.12))   # verdigris
    m.bsdf(base, 1.0, m.mixf(tarn, 0.3, 0.6))

    # --- worn chrome (stamped trigger lever) -----------------------------------------------------
    m = NB('Chrome')
    scr = m.mask(m.noise(3, 3, 0.5, vec=m.scaled((10, 180, 180))), 0.6, 0.66)
    dirt = m.math('MAXIMUM', m.mask(m.noise(10, 6, 0.6), 0.52, 0.8), m.cavity(0.008))
    base = m.mixc(dirt, C(0.62, 0.62, 0.63), C(0.08, 0.07, 0.06))
    m.bsdf(base, 1.0, m.mixf(scr, m.mixf(dirt, 0.30, 0.6), 0.42), m.bump(m.add(scr, m.mul(m.noise(400, 2, 0.5), 0.3)), 0.06))

    # --- wood (file handle): grain, hand-polished grime ------------------------------------------
    m = NB('Wood')
    grain = m.noise(2.0, 6, 0.6, vec=m.scaled((140, 140, 7)), distort=0.6)
    rings = m.mask(grain, 0.45, 0.6)
    base = m.mixc(rings, C(0.16, 0.085, 0.04), C(0.09, 0.045, 0.02))
    oil = m.mask(m.noise(6, 6, 0.6), 0.45, 0.75)
    base = m.mixc(m.mul(oil, 0.7), base, C(0.045, 0.025, 0.014))
    e = m.edge(0.002, 0.03, 0.2)
    base = m.mixc(m.mul(e, 0.6), base, C(0.24, 0.15, 0.08))
    m.bsdf(base, 0.0, m.mixf(oil, 0.62, 0.42), m.bump(m.add(rings, m.mul(m.noise(300, 3, 0.6), 0.5)), 0.12))

    # --- tapes -----------------------------------------------------------------------------
    m = NB('TapeBlack')
    weave = m.noise(1.5, 1, 0.5, vec=m.scaled((900, 900, 60)))
    dirt = m.math('MAXIMUM', m.mask(m.noise(8, 6, 0.6), 0.5, 0.85), m.cavity(0.006))
    m.bsdf(m.mixc(m.mul(dirt, 0.6), C(0.018, 0.018, 0.019), C(0.07, 0.06, 0.05)), 0.0,
           m.mixf(dirt, 0.55, 0.85), m.bump(weave, 0.25))
    m = NB('TapeSilver')
    dirt = m.math('MAXIMUM', m.mask(m.noise(8, 6, 0.6), 0.4, 0.8), m.cavity(0.006))
    m.bsdf(m.mixc(dirt, C(0.30, 0.30, 0.31), C(0.08, 0.07, 0.06)), 0.4, m.mixf(dirt, 0.45, 0.85),
           m.bump(m.noise(1.5, 1, 0.5, vec=m.scaled((900, 900, 900))), 0.15))

    # --- weld beads: heat tint, ripple bump -----------------------------------------------------
    m = NB('Weld')
    nz = m.noise(260, 6, 0.75)
    base = m.mixc(m.mask(m.noise(40, 4, 0.6), 0.3, 0.7), C(0.13, 0.085, 0.045), C(0.05, 0.05, 0.065))
    base = m.mixc(m.mul(m.mask(m.noise(60, 4, 0.6), 0.6, 0.7), 0.8), base, C(0.03, 0.03, 0.035))
    e = m.mul(m.edge(0.001, 0.03, 0.2), 0.7)
    base = m.mixc(e, base, C(0.3, 0.29, 0.28))
    m.bsdf(base, 0.8, m.mixf(e, 0.55, 0.3), m.bump(nz, 0.6))

    # --- gauge dial / plain black / glass -------------------------------------------------------
    m = NB('GaugeFace')
    grime = m.mask(m.noise(20, 6, 0.6), 0.45, 0.85)
    m.bsdf(m.mixc(m.mul(grime, 0.6), C(0.70, 0.66, 0.55), C(0.28, 0.22, 0.15)), 0.0, 0.35)
    m = NB('Black')
    m.bsdf(C(0.012, 0.012, 0.012), 0.2, 0.45)
    m = NB('CableHousing')
    m.bsdf(m.mixc(m.mask(m.noise(10, 6, 0.6), 0.5, 0.8), C(0.015, 0.015, 0.016), C(0.06, 0.055, 0.05)), 0.0, 0.45,
           m.bump(m.noise(600, 2, 0.5), 0.1))

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

    # --- cutaway helpers: desaturated warm grey section with hatching -----------------------------
    m = NB('Section')
    wv = m.n('ShaderNodeTexWave', {'Scale': 1.0, 'Distortion': 0.0}, wave_type='BANDS', bands_direction='DIAGONAL')
    m.l(m.scaled((260, 260, 260)), wv.inputs['Vector'])
    hatch = m.mask(wv.outputs['Factor'], 0.80, 0.86)
    m.bsdf(m.mixc(hatch, C(0.30, 0.28, 0.25), C(0.14, 0.13, 0.12)), 0.0, 0.7)
    m = NB('Liquid')
    m.bsdf(C(0.80, 0.62, 0.30), 0.0, 0.08, extra={'Transmission Weight': 0.8, 'IOR': 1.3})

    # --- dummy / studio / flat grey (game mesh) ---------------------------------------------------
    m = NB('Dummy')
    m.bsdf(C(0.11, 0.11, 0.115), 0.0, 0.6, m.bump(m.noise(80, 3, 0.5), 0.05))
    m = NB('DummyHead')
    m.bsdf(C(0.09, 0.085, 0.08), 0.0, 0.55)
    m = NB('FlatGrey')
    m.bsdf(C(0.32, 0.32, 0.33), 0.0, 0.55)
    m = NB('Floor')
    ln = m.n('ShaderNodeVectorMath', operation='LENGTH')
    m.l(m.obj(), ln.inputs[0])
    fade = m.mask(ln.outputs['Value'], 0.5, 4.0)
    base = m.mixc(fade, C(0.009, 0.009, 0.0095), C(0.003, 0.003, 0.0035))
    m.bsdf(base, 0.0, 1.0, None, extra={'Specular IOR Level': 0.0})
    m = NB('Ground')     # gameplay-distance test: mid-grey concrete
    base = m.mixc(m.mask(m.noise(2, 6, 0.6), 0.3, 0.7), C(0.16, 0.155, 0.15), C(0.11, 0.105, 0.10))
    m.bsdf(base, 0.0, 0.9)


# --------------------------------------------------------------------------------------
# layout constants
# --------------------------------------------------------------------------------------
PIPE_R = 0.021            # feed pipe outer radius (1.35x the v1 pipe)
SHR_R = 0.052             # shroud (exhaust tube) outer radius
SHR_X0, SHR_X1 = 0.225, 0.495
NZ_B = V((-0.425, 0.0, -0.105))       # rear of the nozzle body
NZ_ANG = math.radians(22)             # nozzle tilted 22 deg down (pistol grip)
FG_X = -0.045                         # foregrip strap position
FG_TILT = math.radians(12)
TANK_C = V((0.33, -0.120, -0.145))    # bottle centre (right flank)
TANK_TILT = math.radians(10)          # nose down
TANK_R = 0.084
TANK_BANDS = (-0.075, 0.075)          # band positions along the bottle (local x)


def MG():
    return Matrix.Translation(NZ_B) @ Matrix.Rotation(-NZ_ANG, 4, 'Y')


def MB():
    return Matrix.Translation(TANK_C) @ Matrix.Rotation(TANK_TILT, 4, 'Y')


def handle_frame():
    top = V((FG_X, 0, -0.056))
    d = V((math.sin(FG_TILT), 0, -math.cos(FG_TILT)))
    return top, d


def hand_points():
    """(rear hand, front hand) in weapon space - where the R6 'hands' must sit."""
    top, d = handle_frame()
    return MG() @ V((0.09, 0, 0.0)), top + d * 0.068


# --------------------------------------------------------------------------------------
# the model
# --------------------------------------------------------------------------------------
class Part:
    def __init__(self, name, mats, group, label=None):
        self.name, self.mats, self.group, self.label = name, mats, group, label
        self.bm = bmesh.new()


PARTS = {}


def P(name, mats, group=None):
    if name not in PARTS:
        PARTS[name] = Part(name, mats if isinstance(mats, list) else [mats], group or name)
    return PARTS[name]


def mi(part, mat):
    return part.mats.index(mat)


def build_grip():
    M = MG()
    g = P('NozzleGrip', ['PaintRed', 'Rubber', 'SteelDark'], 'grip')
    bm = g.bm
    # cast body: smooth tapering superellipse sections along the (tilted) nozzle axis
    N = 26 if hi_q() else 9
    us = [0.19 * i / (N - 1) for i in range(N)]
    path, ry, rz = [], [], []
    for u in us:
        dome = math.sqrt(max(0.06, 1 - ((0.022 - u) / 0.022) ** 2)) if u < 0.022 else 1.0
        taper = smoothstep(0.10, 0.19, u)
        hump = 0.005 * math.exp(-((u - 0.150) / 0.025) ** 2)
        ry.append((0.0225 - 0.004 * taper) * dome)
        rz.append((0.034 - 0.012 * taper + hump) * dome)
        path.append(M @ V((u, 0, 0.004 * math.sin(math.pi * u / 0.19) + hump * 0.6)))
    sweep(bm, path, ry, 20, rz=rz, sq=3.2, mi=mi(g, 'PaintRed'))
    # moulded rubber cover over the back of the body: ribs + a clear lip edge
    n2 = 44 if hi_q() else 10
    cu = [0.008 + 0.090 * i / (n2 - 1) for i in range(n2)]
    cp, cry, crz = [], [], []
    for k, u in enumerate(cu):
        dome = math.sqrt(max(0.06, 1 - ((0.022 - u) / 0.022) ** 2)) if u < 0.022 else 1.0
        rib = 0.0011 * (0.5 + 0.5 * math.cos(TAU * u / 0.0075)) if hi_q() else 0.0
        taper = smoothstep(0.10, 0.19, u)
        cry.append((0.0225 - 0.004 * taper) * dome * 1.06 + 0.0012 + rib)
        crz.append((0.034 - 0.012 * taper) * dome * 1.06 + 0.0012 + rib)
        cp.append(M @ V((u, 0, 0.004 * math.sin(math.pi * u / 0.19))))
    sweep(bm, cp, cry, 20, rz=crz, sq=3.2, mi=mi(g, 'Rubber'))
    lipu = 0.098
    lipc = M @ V((lipu, 0, 0.004 * math.sin(math.pi * lipu / 0.19)))
    lp = []
    nl = q(28, 10)
    for i in range(nl):
        a = TAU * i / nl
        c, s = math.cos(a), math.sin(a)
        c = math.copysign(abs(c) ** (2 / 3.2), c)
        s = math.copysign(abs(s) ** (2 / 3.2), s)
        lp.append(lipc + (M.to_3x3() @ V((0, 0.0225 * 1.06 * c + 0.0016 * c, 0.034 * 1.06 * s + 0.0016 * s))))
    sweep(bm, lp, 0.0022, 6, closed=True, mi=mi(g, 'Rubber'))
    # cast boss + screws on both sides, a latch housing on top
    for s in (-1, 1):
        cyl(bm, M @ V((0.135, s * 0.017, 0.0)), M @ V((0.135, s * 0.0215, 0.0)), 0.007, 12, mi(g, 'PaintRed'))
        hexbolt(bm, M @ V((0.135, s * 0.0215, 0.0)), M.to_3x3() @ V((0, s, 0)), 0.0035, 0.003, mi(g, 'SteelDark'),
                washer=False, shank=False)
    # spout stub, cut short, into the saddle under the pipe
    sp0 = M @ V((0.18, 0, 0.002))
    sp1 = V((-0.236, 0, -PIPE_R - 0.004))
    cyl(bm, sp0, sp1, 0.0105, 14, mi(g, 'SteelDark'))
    # rear boot (ribbed rubber) the conduit stock pushes into
    nbt = 10 if hi_q() else 4
    bp = [M @ V((-0.045 + 0.05 * i / (nbt - 1), 0, 0)) for i in range(nbt)]
    rb = [0.0175 + 0.0035 * i / (nbt - 1) + (0.0014 if i % 2 and hi_q() else 0) for i in range(nbt)]
    sweep(bm, bp, rb, 16, mi=mi(g, 'Rubber'))

    # trigger lever: stamped steel channel, worn chrome, pivot pin through the body
    tl = P('TriggerLever', ['Chrome', 'SteelDark'], 'grip')
    lever = crs([M @ V(p) for p in ((0.168, 0, -0.024), (0.15, 0, -0.037), (0.10, 0, -0.045), (0.05, 0, -0.045),
                                    (0.026, 0, -0.040))], 5)
    sweep(tl.bm, lever, 0.0064, rz=0.0026, prof=RECT, mi=0)
    pv = M @ V((0.168, 0, -0.024))
    yax = M.to_3x3() @ V((0, 1, 0))
    cyl(tl.bm, pv - yax * 0.030, pv + yax * 0.030, 0.0028, 10, 1)
    for s in (-1, 1):
        cyl(tl.bm, pv + yax * s * 0.028, pv + yax * s * 0.031, 0.0045, 10, 1)
    # guard: flat cast band (wider than thick), painted
    gd = P('TriggerGuard', 'PaintRed', 'grip')
    guard = crs([M @ V(p) for p in ((0.184, 0, -0.018), (0.180, 0, -0.048), (0.158, 0, -0.064), (0.100, 0, -0.071),
                                    (0.045, 0, -0.067), (0.020, 0, -0.052), (0.014, 0, -0.028))], 4)
    sweep(gd.bm, guard, 0.0090, 10, rz=0.0042, sq=3.5, mi=0)

    # saddle + bent strap clamping the spout under the feed pipe, with a weld
    sd = P('GripMount', 'SteelDark', 'grip')
    box(sd.bm, (-0.236, 0, -PIPE_R - 0.007), (0.034, 0.024, 0.012))
    band_clamp(sd.bm, (-0.236, 0, 0), (1, 0, 0), PIPE_R, 0.020, 0.003, (0, 0, 1), segs=40 if hi_q() else 12)
    wd = P('WeldsGrip', 'Weld', 'grip')
    for s in (-1, 1):
        weld_line(wd.bm, [(-0.253, s * 0.012, -PIPE_R - 0.001), (-0.236, s * 0.0125, -PIPE_R + 0.0005),
                          (-0.219, s * 0.012, -PIPE_R - 0.001)], 0.0022, seed=5 + s)
    weld_ring(wd.bm, sp1 + (sp0 - sp1).normalized() * 0.002, sp0 - sp1, 0.0108, 0.0022, seed=9)


def build_stock():
    st = P('StockConduit', 'Galv', 'stock')
    M = MG()
    end = M @ V((-0.040, 0, 0))
    path = crs([(-0.350, 0, 0.0), (-0.42, 0, 0.003), (-0.49, 0, 0.0), (-0.532, 0, -0.018), (-0.552, 0, -0.058),
                (-0.546, 0, -0.098), (-0.522, 0, -0.122), (-0.49, 0, -0.130), tuple(end + V((-0.004, 0, -0.002))),
                tuple(end + V((0.012, 0, 0.005)))], 7)
    sweep(st.bm, path, 0.0135, 16 if hi_q() else 12, mi=0)
    # flattened crimp where the conduit was squashed to bend (a real junk tell)
    bp = P('StockButt', ['Rubber', 'TapeBlack'], 'stock')
    idx = [i for i, p in enumerate(path) if p.x < -0.515]
    seg = [path[i] for i in idx]
    rnd = random.Random(3)
    if not hi_q():
        seg = seg[::2] + ([seg[-1]] if len(seg) % 2 == 0 else [])
    sweep(bp.bm, seg, [0.0175 + 0.0018 * ((k % 3) == 0) + 0.0006 * rnd.random() for k in range(len(seg))], 16, mi=0)
    tape_wrap(bp.bm, (-0.455, 0, 0.0018), (-0.405, 0, 0.0025), 0.0135, 0.014, seed=4, mi=1)
    ws = P('WeldsStock', 'Weld', 'stock')
    weld_ring(ws.bm, (-0.351, 0, 0.0), (1, 0, 0), 0.0137, 0.0026, seed=21)
    # hose clamp holding the conduit in the rubber boot
    hc = P('StockClamp', 'SteelDark', 'stock')
    bc = MG() @ V((-0.030, 0, 0))
    ax = MG().to_3x3() @ V((1, 0, 0))
    band_clamp(hc.bm, bc, ax, 0.0215, 0.010, 0.0012, MG().to_3x3() @ V((0, -1, 0)), ear_len=0.008)


def build_pipe():
    f = P('FeedPipe', 'SteelDark', 'pipe')
    lathe(f.bm, [(-0.362, 0.0), (-0.362, 0.012), (-0.360, 0.018), (-0.356, PIPE_R + 0.001), (-0.348, PIPE_R + 0.001),
                 (-0.348, 0.0)], 20)  # welded end cap
    tube(f.bm, (-0.350, 0, 0), (0.230, 0, 0), 0.0165, PIPE_R, 20, rings=8)
    lathe(f.bm, [(-0.147, 0.0), (-0.147, 0.029), (-0.123, 0.029), (-0.123, 0.0)], 6)        # union nut
    lathe(f.bm, [(-0.123, 0.0), (-0.123, 0.024), (-0.113, 0.024), (-0.113, 0.0)], 20)
    tp = P('TapeFeed', 'TapeBlack', 'pipe')
    tape_wrap(tp.bm, (-0.208, 0, 0), (-0.168, 0, 0), PIPE_R, 0.014, seed=7)
    tape_wrap(tp.bm, (0.008, 0, 0), (0.046, 0, 0), PIPE_R + 0.004, 0.014, seed=8)
    wp = P('WeldsPipe', 'Weld', 'pipe')
    weld_ring(wp.bm, (-0.349, 0, 0), (1, 0, 0), PIPE_R + 0.0006, 0.0026, seed=31)

    # T fitting (hose in from the right side)
    t = P('TeeFitting', ['SteelDark', 'Brass'], 'tee')
    lathe(t.bm, [(0.063, 0.0), (0.063, 0.0285), (0.071, 0.0285), (0.071, 0.0)], 6)
    lathe(t.bm, [(0.099, 0.0), (0.099, 0.0285), (0.107, 0.0285), (0.107, 0.0)], 6)
    lathe(t.bm, [(0.070, 0.0), (0.070, 0.026), (0.100, 0.026), (0.100, 0.0)], 20)
    cyl(t.bm, (0.085, 0.0, 0.0), (0.085, -0.050, 0.0), 0.0135, 16)
    lathe(t.bm, [(0, 0), (0, 0.0165), (0.010, 0.0165), (0.010, 0)], 6, frame_x((0.085, -0.040, 0.0), (0, -1, 0)), mi=1)
    lathe(t.bm, [(0, 0), (0, 0.0075), (0.018, 0.0075), (0.018, 0)], 12, frame_x((0.085, -0.050, 0.0), (0, -1, 0)), mi=1)

    # ball valve: brass body, steel stem, lever (red vinyl grip) pulled by the brake cable
    bv = P('BallValve', ['Brass', 'SteelDark'], 'valve')
    lathe(bv.bm, [(0.116, 0.0), (0.116, 0.0285), (0.127, 0.0285), (0.127, 0.0)], 6)
    lathe(bv.bm, [(0.173, 0.0), (0.173, 0.0285), (0.184, 0.0285), (0.184, 0.0)], 6)
    lathe(bv.bm, [(0.125, 0.0), (0.125, 0.026), (0.132, 0.031), (0.150, 0.0335), (0.168, 0.031), (0.175, 0.026),
                  (0.175, 0.0)], 24)
    cyl(bv.bm, (0.150, 0, 0.030), (0.150, 0, 0.047), 0.0075, 12)
    hexbolt(bv.bm, (0.150, 0, 0.047), (0, 0, 1), 0.0062, 0.006, mi(bv, 'SteelDark'), washer=False)
    lv = P('ValveLever', ['PaintRed', 'SteelDark'], 'valve')
    lpath = crs([(0.150, 0.0, 0.052), (0.128, -0.012, 0.054), (0.104, -0.032, 0.056), (0.086, -0.050, 0.057)], 4)
    sweep(lv.bm, lpath[:6], 0.0085, rz=0.0024, prof=RECT, mi=mi(lv, 'SteelDark'))
    sweep(lv.bm, lpath[4:], 0.0105, 10, rz=0.0055, sq=3, mi=mi(lv, 'PaintRed'))
    # return spring from the lever to a tab on the valve nut
    sp = []
    a0, a1 = V((0.112, -0.028, 0.052)), V((0.130, -0.040, 0.020))
    ax = (a1 - a0)
    Ms = frame_x(a0, ax)
    hn = q(10, 6)
    turns = 7
    for i in range(turns * hn + 1):
        a = TAU * i / hn
        sp.append(Ms @ V((ax.length * i / (turns * hn), 0.0035 * math.cos(a), 0.0035 * math.sin(a))))
    if hi_q():
        sweep(lv.bm, sp, 0.0008, 5, mi=mi(lv, 'SteelDark'))
    box(lv.bm, (0.131, -0.036, 0.016), (0.008, 0.012, 0.003), mi=mi(lv, 'SteelDark'))
    # inner ball with its bore (only seen in the cutaway)
    bb = P('ValveBall', 'Chrome', 'valve')
    lathe(bb.bm, [(0.1265 - 0.150, 0.0)] + [(-0.0235 * math.cos(math.pi * i / 12), 0.0235 * math.sin(math.pi * i / 12))
                                           for i in range(1, 12)] + [(0.0235, 0.0)], 20,
          Matrix.Translation((0.150, 0, 0)))

    # brake cable: housing along the pipe, inner wire to the lever tip, zip ties, a stop tab
    cb = P('BrakeCable', ['CableHousing', 'Chrome', 'Black', 'SteelDark'], 'cable')
    c0 = MG() @ V((0.168, -0.012, -0.028))
    hp = crs([tuple(c0), (-0.226, -0.030, -0.028), (-0.19, -0.026, 0.010), (-0.12, -0.0215, 0.0165),
              (-0.05, -0.0215, 0.0165), (0.02, -0.024, 0.0175), (0.050, -0.030, 0.026), (0.068, -0.035, 0.038)], 6)
    sweep(cb.bm, hp if hi_q() else hp[::2] + [hp[-1]], 0.0034, 10 if hi_q() else 4, mi=0)
    cyl(cb.bm, hp[-1], hp[-1] + (hp[-1] - hp[-2]).normalized() * 0.008, 0.0045, 10, mi(cb, 'SteelDark'))   # ferrule
    wire = [hp[-1] + (hp[-1] - hp[-2]).normalized() * 0.008, V((0.086, -0.050, 0.057))]
    cyl(cb.bm, wire[0], wire[1], 0.0009, 6, mi(cb, 'Chrome'))
    cyl(cb.bm, c0, c0 - (hp[1] - hp[0]).normalized() * 0.007, 0.0045, 10, mi(cb, 'SteelDark'))
    for xz in (-0.105, -0.005):
        lathe(cb.bm, [(xz, PIPE_R), (xz, PIPE_R + 0.0012), (xz + 0.0042, PIPE_R + 0.0012), (xz + 0.0042, PIPE_R)], 20,
              closed=True, mi=mi(cb, 'Black'))
        box(cb.bm, (xz + 0.002, -0.006, PIPE_R + 0.009), (0.006, 0.006, 0.006), mi=mi(cb, 'Black'))
        if hi_q():
            lathe(cb.bm, [(0, 0.0034), (0, 0.0046), (0.0042, 0.0046), (0.0042, 0.0034)], 10,
                  frame_x(V((xz, -0.0215, 0.0165)), (1, 0, 0)), closed=True, mi=mi(cb, 'Black'))
    box(cb.bm, (0.064, -0.033, 0.034), (0.014, 0.003, 0.012), Matrix.Rotation(math.radians(-40), 3, 'Z'),
        mi(cb, 'SteelDark'))   # cable stop tab
    wv = P('WeldsValve', 'Weld', 'cable')
    weld_line(wv.bm, [(0.058, -0.0215, 0.0175), (0.064, -0.026, 0.022), (0.070, -0.030, 0.026)], 0.0018, seed=41)


def build_foregrip():
    top, d = handle_frame()
    fc = P('ForeGripClamp', 'SteelDark', 'fgrip')
    # crude bent strap: band round the pipe, both legs bent down into a tang, one bolt
    lathe(fc.bm, [(FG_X - 0.011, PIPE_R), (FG_X - 0.011, PIPE_R + 0.0032), (FG_X + 0.011, PIPE_R + 0.0032),
                  (FG_X + 0.011, PIPE_R)], 32, closed=True)
    for s in (-1, 1):
        box(fc.bm, (FG_X, s * 0.0062, -0.037), (0.021, 0.0032, 0.030), Matrix.Rotation(s * math.radians(4), 3, 'X'))
    hexbolt(fc.bm, (FG_X, 0.0080, -0.040), (0, 1, 0), 0.0048, 0.020)
    hexbolt(fc.bm, (FG_X, -0.0080, -0.040), (0, -1, 0), 0.0048, 0.004, shank=False)
    box(fc.bm, top + d * (-0.004), (0.016, 0.0085, 0.020), Matrix.Rotation(-FG_TILT, 3, 'Y'))   # tang into the ferrule
    fh = P('ForeGripHandle', ['Wood', 'SteelDark'], 'fgrip')
    Mh = frame_x(top, d)
    lathe(fh.bm, [(0.0, 0.0), (0.0, 0.0125), (0.013, 0.0135), (0.013, 0.0)], 20, Mh, mi=1)       # steel ferrule
    prof = [(0.012, 0.0), (0.012, 0.0142), (0.03, 0.0158), (0.06, 0.0172), (0.09, 0.0178), (0.115, 0.0170),
            (0.130, 0.0150), (0.138, 0.0110), (0.141, 0.0)]
    lathe(fh.bm, prof, 22, Mh, mi=0, pert=lambda x, r, a: 0.0006 * math.sin(3 * a + x * 90) if r > 0.005 else 0.0)
    fb = P('ForeGripBand', ['SteelDark', 'TapeBlack'], 'fgrip')
    band_clamp(fb.bm, top + d * 0.098, d, 0.0180, 0.009, 0.0010, V((0, -1, 0)), ear_len=0.007, segs=28)
    tape_wrap(fb.bm, top + d * 0.014, top + d * 0.044, 0.0150, 0.012, seed=12, mi=1, tail=False)
    wf = P('WeldsFrontGrip', 'Weld', 'fgrip')
    for s in (-1, 1):
        weld_line(wf.bm, [(FG_X - 0.010, s * 0.0078, -PIPE_R - 0.0025), (FG_X, s * 0.0080, -PIPE_R - 0.004),
                          (FG_X + 0.010, s * 0.0078, -PIPE_R - 0.0025)], 0.0018, seed=50 + s)


HOLES = []


def build_front():
    b = P('Barrel', 'BarrelHeat', 'barrel')
    tube(b.bm, (0.200, 0, 0), (0.524, 0, 0), 0.016, 0.022, 20, rings=8)
    lathe(b.bm, [(0.517, 0.0), (0.517, 0.016), (0.521, 0.016), (0.521, 0.0)], 16)   # jet orifice plate
    s = P('HeatShroud', 'ShroudHeat', 'shroud')
    tube(s.bm, (SHR_X0, 0, 0), (SHR_X1, 0, 0), 0.0475, SHR_R, 64 if hi_q() else 32, rings=44)
    crude = lambda x, r, a: (0.0012 * math.sin(5 * a + 1.7) + 0.0008 * math.sin(11 * a)) if r > 0.05 else 0.0
    lathe(s.bm, [(0.214, 0.0212), (0.214, 0.0548), (0.2255, 0.0548), (0.2255, 0.0212)], 40, closed=True, pert=crude)
    lathe(s.bm, [(0.4945, 0.0225), (0.4945, 0.0548), (0.5055, 0.0548), (0.5055, 0.0225)], 40, closed=True, pert=crude)
    w = P('WeldsShroud', 'Weld', 'shroud')
    for x, R, sd in ((0.2125, PIPE_R + 0.0005, 1), (0.2265, SHR_R, 2), (0.4935, SHR_R, 3), (0.5065, 0.0225, 4)):
        weld_ring(w.bm, (x, 0, 0), (1, 0, 0), R, 0.0028, seed=60 + sd)
    # pipe clamps on the shroud for the bottle rail (bolt + nut on top)
    sb = P('ShroudClamps', 'SteelDark', 'mount')
    for xb in bottle_band_world_x():
        band_clamp(sb.bm, (xb, 0, 0), (1, 0, 0), SHR_R, 0.020, 0.0035, (0, 0.25, 1), ear_len=0.018, segs=40 if hi_q() else 24)

    # hand-drilled holes: uneven spacing and sizes, none on the bottle side or under the clamps
    HOLES.clear()
    rnd = random.Random(1234)
    bxs = bottle_band_world_x()
    tries = 0
    while len(HOLES) < 26 and tries < 5000:
        tries += 1
        x = rnd.uniform(0.245, 0.478)
        a = rnd.uniform(0, TAU)
        ad = math.degrees(a) % 360
        if 195 < ad < 300 or any(abs(x - xb) < 0.020 for xb in bxs):
            continue
        if any(abs(x - xb) < 0.03 for xb in bxs) and 60 < ad < 120:
            continue
        r = rnd.uniform(0.0042, 0.0068)
        ok = True
        for (hx, ha, hr) in HOLES:
            da = abs(((a - ha + math.pi) % TAU) - math.pi) * SHR_R
            if math.hypot(x - hx, da) < (r + hr) + rnd.uniform(0.006, 0.016):
                ok = False
                break
        if ok:
            HOLES.append((x, a, r))

    # muzzle: welded concentric reducer + a thick tip with a slash cut (no bell, no cone)
    mz = P('Muzzle', ['MuzzleHeat', 'SootInner', 'LipScale'], 'muzzle')
    lathe(mz.bm, [(0.5055, 0.046), (0.5055, 0.0525), (0.512, 0.052), (0.532, 0.037), (0.540, 0.0355),
                  (0.540, 0.0285), (0.532, 0.030), (0.512, 0.0455)], 40, closed=True)
    beat = lambda x, r, a: (x - 0.585) * 0.04 * (math.sin(3 * a + 0.8) * 0.6 + math.sin(7 * a + 2) * 0.4) if x > 0.585 else 0.0
    xs = [0.536 + i * 0.012 for i in range(12)] if hi_q() else [0.536, 0.59, 0.63]
    prof = [(0.536, 0.0262)] + [(x, 0.0338) for x in xs] + [(0.672, 0.0338), (0.672, 0.0262)] + \
           [(x, 0.0262) for x in reversed(xs[1:])]
    lathe(mz.bm, prof, 44 if hi_q() else 16, closed=True, pert=beat)
    wm = P('WeldsMuzzle', 'Weld', 'muzzle')
    weld_ring(wm.bm, (0.5065, 0, 0), (1, 0, 0), 0.0505, 0.0026, seed=71)
    weld_ring(wm.bm, (0.539, 0, 0), (1, 0, 0), 0.0345, 0.0026, seed=72)

    # pilot burner on a welded tab under the reducer
    pl = P('PilotBurner', ['SteelDark', 'Brass', 'Weld'], 'pilot')
    box(pl.bm, (0.527, 0, -0.050), (0.018, 0.0045, 0.030), Matrix.Rotation(math.radians(-25), 3, 'Y'))
    weld_line(pl.bm, [(0.519, -0.003, -0.039), (0.527, -0.0033, -0.036), (0.535, -0.003, -0.034)], 0.0018, seed=80,
              mi=mi(pl, 'Weld'))
    weld_line(pl.bm, [(0.519, 0.003, -0.039), (0.527, 0.0033, -0.036), (0.535, 0.003, -0.034)], 0.0018, seed=81,
              mi=mi(pl, 'Weld'))
    p0, p1 = V((0.522, 0, -0.064)), V((0.600, 0, -0.058))
    cyl(pl.bm, p0, p1, 0.0062, 14, 0)
    lathe(pl.bm, [(0.0, 0.0062), (0.0, 0.0078), (0.010, 0.0078), (0.010, 0.0062)], 12,
          frame_x(p0.lerp(p1, 0.25), p1 - p0), closed=True, mi=mi(pl, 'Brass'))
    tip_dir = V((math.cos(math.radians(24)), 0, math.sin(math.radians(24))))
    cyl(pl.bm, p1 - (p1 - p0).normalized() * 0.003, p1 + tip_dir * 0.011, 0.0068, 12, mi(pl, 'Brass'), r1=0.0036)
    flame = P('PilotFlame', ['FlameBlue', 'FlameCore'], 'pilot')
    ftip = p1 + tip_dir * 0.011
    fM = frame_x(ftip, tip_dir)
    lathe(flame.bm, [(0, 0.0), (0.0, 0.0045), (0.008, 0.0085), (0.025, 0.0080), (0.045, 0.0042), (0.062, 0.0)], 14, fM, mi=0)
    lathe(flame.bm, [(0.0005, 0.0), (0.0005, 0.0032), (0.008, 0.0040), (0.018, 0.0)], 10, fM, mi=1)


def bottle_band_world_x():
    return [(MB() @ V((xl, 0, 0))).x for xl in TANK_BANDS]


def bottle_axis_pt(xl):
    return MB() @ V((xl, 0, 0))


def build_bottle():
    M = MB()
    tk = P('Tank', 'BottlePaint', 'tank')
    prof = []
    nd, nb = (8, 22) if hi_q() else (4, 4)
    for i in range(nd + 1):
        ph = (math.pi / 2) * i / nd
        prof.append((-0.125 - 0.048 * math.cos(ph), TANK_R * math.sin(ph)))
    for k in range(1, nb):
        x = -0.125 + 0.25 * k / nb
        prof.append((x, TANK_R + (0.0018 if abs(x) < 0.006 and hi_q() else 0.0)))
    for i in range(nd, -1, -1):
        ph = (math.pi / 2) * i / nd
        prof.append((0.125 + 0.048 * math.cos(ph), TANK_R * math.sin(ph)))
    lathe(tk.bm, prof, 56 if hi_q() else 20, M)
    # three real dents + a crease, and a little shell noise
    Mi = M.inverted()
    rnd = random.Random(11)
    dents = [(-0.055, math.radians(205), 0.030, 0.011), (0.070, math.radians(160), 0.020, 0.008),
             (0.010, math.radians(258), 0.034, 0.012)]
    for v in tk.bm.verts:
        lp = Mi @ v.co
        rr = math.hypot(lp.y, lp.z)
        if rr < 1e-5:
            continue
        a = math.atan2(lp.z, lp.y)
        d = 0.0
        for dx, da, sig, depth in dents:
            arc = (((a - da + math.pi) % TAU) - math.pi) * TANK_R
            d += depth * math.exp(-((lp.x - dx) ** 2 / (sig ** 2) + arc ** 2 / ((sig * 0.7) ** 2)))
        # a sharp crease line across the first dent
        arc = (((a - math.radians(212) + math.pi) % TAU) - math.pi) * TANK_R
        if abs(lp.x + 0.05) < 0.03:
            d += 0.003 * math.exp(-(arc / 0.003) ** 2) * (1 - abs(lp.x + 0.05) / 0.03)
        d += 0.0005 * (rnd.random() - 0.5)
        k = (rr - d) / rr
        lp.y *= k
        lp.z *= k
        v.co = M @ lp
    # foot ring (front) with a dented rolled lip
    dent_r = lambda x, r, a: -0.004 * math.exp(-((((a - 4.0 + math.pi) % TAU) - math.pi) / 0.25) ** 2) if x > 0.185 else 0.0
    lathe(tk.bm, [(0.150, 0.0620), (0.150, 0.0660), (0.190, 0.0660), (0.190, 0.0620)], 40, M, closed=True, pert=dent_r)
    torus(tk.bm, M @ V((0.191, 0, 0)), M.to_3x3() @ V((1, 0, 0)), 0.064, 0.0038, 40, 6 if hi_q() else 3)
    # guard collar round the valve (thick, dented rim) - cut-outs are booleaned later
    col = P('TankCollar', 'BottlePaint', 'collar')
    dent_c = lambda x, r, a: -0.006 * math.exp(-((((a - 1.2 + math.pi) % TAU) - math.pi) / 0.3) ** 2) * smoothstep(-0.19, -0.222, x)
    lathe(col.bm, [(-0.222, 0.0545), (-0.222, 0.0595), (-0.165, 0.0595), (-0.165, 0.0545)], 40 if hi_q() else 16, M, closed=True,
          pert=dent_c)
    rim = []
    nr = q(40, 10)
    for i in range(nr):
        a = TAU * i / nr
        rr = 0.0570 + dent_c(-0.224, 0.057, a)
        rim.append(M @ V((-0.224, rr * math.cos(a), rr * math.sin(a))))
    sweep(col.bm, rim, 0.0048, 8 if hi_q() else 3, closed=True)

    # valve + handwheel (axis along the bottle, out of the rear pole)
    va = P('TankValve', 'Brass', 'bvalve')
    ax = M.to_3x3() @ V((-1, 0, 0))
    vp = lambda x: M @ V((x, 0, 0))
    cyl(va.bm, vp(-0.171), vp(-0.206), 0.0135, 14)
    lathe(va.bm, [(0, 0), (0, 0.0185), (0.011, 0.0185), (0.011, 0)], 6, frame_x(vp(-0.180), ax))
    cyl(va.bm, vp(-0.204), vp(-0.222), 0.0045, 8)
    out_dir = M.to_3x3() @ V((0, -1, 0))
    cyl(va.bm, vp(-0.192), vp(-0.192) + out_dir * 0.064, 0.0068, 12)        # side outlet to the regulator
    lathe(va.bm, [(0, 0), (0, 0.0115), (0.010, 0.0115), (0.010, 0)], 6, frame_x(vp(-0.192) + out_dir * 0.050, out_dir))
    vw = P('ValveWheel', 'PaintRed', 'bvalve')
    wc = vp(-0.219)
    torus(vw.bm, wc, ax, 0.020, 0.0038, 28, 6)
    for k in range(3):
        a = TAU * k / 3 + 0.4
        cyl(vw.bm, wc, wc + M.to_3x3() @ V((0, 0.020 * math.cos(a), 0.020 * math.sin(a))), 0.0028, 6)
    cyl(vw.bm, wc - ax * 0.004, wc + ax * 0.005, 0.0065, 10)

    # regulator: squat diaphragm housing, rim screws, brass inlet nut, knob, outlet barb, pilot needle valve
    rg = P('Regulator', ['ZincCast', 'Brass', 'Black'], 'regulator')
    RC = vp(-0.192) + out_dir * 0.080
    F = frame_x(RC, out_dir)
    lathe(rg.bm, [(-0.012, 0.0), (-0.012, 0.030), (-0.006, 0.0335), (-0.001, 0.0335), (-0.001, 0.0370),
                  (0.004, 0.0370), (0.004, 0.0335), (0.008, 0.0330), (0.011, 0.0300), (0.0125, 0.0200),
                  (0.013, 0.0)], 32 if hi_q() else 12, F)
    for k in range(8 if hi_q() else 4):
        a = TAU * k / (8 if hi_q() else 4) + 0.2
        hexbolt(rg.bm, F @ V((0.004, 0.0352 * math.cos(a), 0.0352 * math.sin(a))), out_dir, 0.0026, 0.003, 0,
                washer=False, shank=False)
    lathe(rg.bm, [(0, 0), (0, 0.012), (0.016, 0.012), (0.018, 0.009), (0.018, 0)], 16, frame_x(RC + out_dir * 0.012, out_dir),
          mi=mi(rg, 'Black'), pert=lambda x, r, a: 0.0009 * (1 if int(a / TAU * 16 + 0.5) % 2 else 0) if r > 0.011 else 0.0)
    lathe(rg.bm, [(0, 0), (0, 0.0125), (0.010, 0.0125), (0.010, 0)], 6, frame_x(RC - out_dir * 0.020, out_dir),
          mi=mi(rg, 'Brass'))   # inlet nut
    up = V((0, 0, 1))
    fwd = M.to_3x3() @ V((1, 0, 0))
    ob = RC + up * 0.030 - out_dir * 0.004
    cyl(rg.bm, ob, ob + up * 0.020, 0.0070, 12, mi(rg, 'Brass'))
    for k in range(3):
        cyl(rg.bm, ob + up * (0.010 + 0.004 * k), ob + up * (0.012 + 0.004 * k), 0.0085, 12, mi(rg, 'Brass'))
    pt = RC + fwd * 0.030 - out_dir * 0.004
    cyl(rg.bm, pt, pt + fwd * 0.016, 0.0050, 10, mi(rg, 'Brass'))
    hexbolt(rg.bm, pt + fwd * 0.012, up, 0.0045, 0.010, mi(rg, 'Brass'), washer=False)      # needle valve knob
    gs = RC + (-fwd + up).normalized() * 0.031 - out_dir * 0.004
    gdir = (-fwd * 0.6 + up).normalized()
    cyl(rg.bm, gs, gs + gdir * 0.022, 0.0042, 10, mi(rg, 'Brass'))
    gg = P('Gauge', ['Brass', 'GaugeFace', 'Black', 'PaintRed'], 'regulator')
    gc = gs + gdir * 0.034
    face_n = (out_dir * 0.85 + up * 0.25).normalized()
    Fg = frame_x(gc, face_n)
    lathe(gg.bm, [(-0.010, 0), (-0.010, 0.019), (0.003, 0.0215), (0.008, 0.0215), (0.009, 0.0195),
                  (0.0085, 0.0178), (0.0065, 0.0178), (0.0065, 0)], 28, Fg, mi=0)
    lathe(gg.bm, [(0.0067, 0), (0.0067, 0.0179)], 28, Fg, mi=mi(gg, 'GaugeFace'))
    gu = (up - face_n * up.dot(face_n)).normalized()
    gr = face_n.cross(gu)
    for k in range(11 if hi_q() else 0):
        a = math.radians(225 - 27 * k)
        dv = gr * math.cos(a) + gu * math.sin(a)
        Rm = basis(dv.cross(face_n), face_n, dv)
        box(gg.bm, gc + face_n * 0.0069 + dv * 0.0148, (0.0012, 0.0005, 0.0045 if k % 5 == 0 else 0.0028), Rm,
            mi(gg, 'PaintRed' if k >= 9 else 'Black'))
    a = math.radians(225 - 27 * 3.4)
    dv = gr * math.cos(a) + gu * math.sin(a)
    box(gg.bm, gc + face_n * 0.0075 + dv * 0.0062, (0.0011, 0.0005, 0.016), basis(dv.cross(face_n), face_n, dv),
        mi(gg, 'Black'))
    cyl(gg.bm, gc + face_n * 0.0072, gc + face_n * 0.0082, 0.0021, 8, mi(gg, 'Black'))

    # band clamps (with rubber strips under them) on an angle-iron rail welded to the shroud clamps
    mt = P('TankBands', ['SteelDark', 'Rubber'], 'mount')
    rl = P('TankRail', 'SteelDark', 'mount')
    wr = P('WeldsMount', 'Weld', 'mount')
    rail_pts = []
    for xl in TANK_BANDS:
        Pk = bottle_axis_pt(xl)
        Sk = V((Pk.x, 0, 0))
        dvec = (Sk - Pk)
        dist = dvec.length
        dvec.normalize()
        Rk = Sk - dvec * (SHR_R + 0.0035 + 0.017)
        rail_pts.append((Pk, Sk, Rk, dvec))
        axb = M.to_3x3() @ V((1, 0, 0))
        if hi_q():
            lathe(mt.bm, [(-0.016, TANK_R + 0.0002), (-0.016, TANK_R + 0.0028), (0.016, TANK_R + 0.0028),
                          (0.016, TANK_R + 0.0002)], 48, frame_x(Pk, axb), closed=True, mi=mi(mt, 'Rubber'))
        ear_len = (Rk - Pk).length - (TANK_R + 0.0058) + 0.012
        band_clamp(mt.bm, Pk, axb, TANK_R + 0.0028, 0.022, 0.0030, (dvec - axb * dvec.dot(axb)).normalized(),
                   ear_len=ear_len, segs=48 if hi_q() else 24, bolt=False)
        # stub between the shroud clamp and the rail, welded both ends
        a0 = Sk - dvec * (SHR_R + 0.0035)
        t = V((1, 0, 0)).cross(dvec).normalized()
        box(rl.bm, (a0 + Rk) / 2 - dvec * 0.0, (0.020, 0.010, (Rk - a0).length + 0.002), basis((1, 0, 0), t, dvec))
        for sgn in (-1, 1):
            weld_line(wr.bm, [a0 + t * sgn * 0.0055 + V((-0.010, 0, 0)), a0 + t * sgn * 0.006, a0 + t * sgn * 0.0055 + V((0.010, 0, 0))],
                      0.0018, seed=90 + int(sgn) + int(xl * 100))
    # angle iron along the bottle: a vertical-ish flange (sandwiched by the ears) + a flat flange
    (P0, S0, R0, d0), (P1, S1, R1, d1) = rail_pts
    x0, x1 = R0 - (R1 - R0).normalized() * 0.03, R1 + (R1 - R0).normalized() * 0.03
    ax_r = (x1 - x0)
    dm = ((d0 + d1) / 2).normalized()
    t = ax_r.normalized().cross(dm).normalized()
    Rm = basis(ax_r.normalized(), t, dm)
    mid = (x0 + x1) / 2
    box(rl.bm, mid, (ax_r.length, 0.0035, 0.026), Rm)
    box(rl.bm, mid + dm * 0.0115 + t * 0.010, (ax_r.length, 0.020, 0.0035), Rm)
    bt = P('BoltsMount', 'SteelDark', 'mount')
    for (Pk, Sk, Rk, dk) in rail_pts:
        hexbolt(bt.bm, Rk + t * 0.0045 + dk * 0.002, t, 0.0045, 0.018)
        hexbolt(bt.bm, Rk - t * 0.0045 + dk * 0.002, -t, 0.0045, 0.004, shank=False)

    # short hose regulator -> T on the pipe (right side, no loop off the back)
    h = P('Hose', 'Rubber', 'hose')
    hb = ob + up * 0.020
    tee = V((0.085, -0.068, 0.0))
    hp = crs([hb, hb + up * 0.014, hb + up * 0.034 + V((-0.006, 0.004, 0)), (0.12, -0.15, 0.016), (0.10, -0.112, 0.012),
              tee + V((0.0, -0.030, 0.0)), tee], 6)
    sweep(h.bm, hp, 0.0118, 14, mi=0)
    hf = P('HoseFittings', 'SteelDark', 'hose')
    sweep(hf.bm, hp[:3], 0.0136, 14)
    sweep(hf.bm, hp[-3:], 0.0136, 14)

    # copper pilot line: needle valve -> along the bottle top (tied at each band) -> burner
    cu = P('PilotLine', ['Copper', 'SteelDark'], 'pline')
    a_line = math.radians(128)
    rr = TANK_R + 0.0085

    def on_bottle(xl):
        return M @ V((xl, rr * math.cos(a_line), rr * math.sin(a_line)))
    nv = pt + fwd * 0.016
    line = crs([nv, nv + fwd * 0.012 + up * 0.004, on_bottle(-0.120), on_bottle(TANK_BANDS[0]), on_bottle(0.0),
                on_bottle(TANK_BANDS[1]), on_bottle(0.150), V((0.505, -0.060, -0.075)), V((0.512, -0.012, -0.068)),
                V((0.522, 0.0, -0.064))], 6)
    sweep(cu.bm, line, 0.0030, 8, mi=0)
    # wire ties every ~15 cm (at the bands, mid-bottle and on the way to the burner)
    for xl in (TANK_BANDS[0], 0.0, TANK_BANDS[1], 0.150):
        c0 = on_bottle(xl)
        ax = (on_bottle(xl + 0.01) - c0).normalized()
        if not hi_q():
            continue
        torus(cu.bm, c0, ax, 0.0046, 0.0010, 10, 4, mi=mi(cu, 'SteelDark'))
        torus(cu.bm, c0 + ax * 0.003, ax, 0.0046, 0.0010, 10, 4, mi=mi(cu, 'SteelDark'))
        tw = M @ V((xl, (rr + 0.006) * math.cos(a_line), (rr + 0.006) * math.sin(a_line)))
        cyl(cu.bm, tw, tw + (tw - bottle_axis_pt(xl)).normalized() * 0.006, 0.0011, 5, mi(cu, 'SteelDark'))


def build_parts():
    build_grip()
    build_stock()
    build_pipe()
    build_foregrip()
    build_front()
    build_bottle()


LABELS = {
    'stock': 'conduit loop stock\n+ inner-tube butt', 'grip': 'fuel-pump nozzle grip\n+ trigger, guard, saddle',
    'pipe': 'feed pipe\n+ union, tape', 'cable': 'brake cable\n+ zip ties', 'tee': 'T-fitting',
    'valve': 'ball valve\n+ lever, spring', 'fgrip': 'file-handle foregrip\n+ bent strap',
    'barrel': 'barrel + jet plate', 'shroud': 'exhaust-tube shroud\n(hand-drilled)', 'muzzle': 'slash-cut reducer tip',
    'pilot': 'pilot burner', 'pline': 'copper pilot line\n+ wire ties', 'tank': 'olive-drab gas bottle', 'collar': 'guard collar',
    'bvalve': 'bottle valve\n+ handwheel', 'regulator': 'regulator + gauge', 'mount': 'band clamps, rail,\npipe clamps',
    'hose': 'hose + crimps',
}


def build_objects(col):
    objs = {}
    for name, part in PARTS.items():
        me = bpy.data.meshes.new(name)
        part.bm.to_mesh(me)
        part.bm.free()
        for mname in part.mats:
            me.materials.append(MAT[mname])
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(38 if hi_q() else 64))
        ob = bpy.data.objects.new(name, me)
        col.objects.link(ob)
        ob['group'] = part.group
        objs[name] = ob
    return objs


def tank_uvs(ob):
    """Cylindrical UVs round the bottle axis: u = angle (0.5 = facing -Y), v = along the bottle."""
    me = ob.data
    uv = me.uv_layers.new(name='UVMap')
    Mi = MB().inverted()
    for poly in me.polygons:
        us, vs = [], []
        for li in poly.loop_indices:
            lp = Mi @ me.vertices[me.loops[li].vertex_index].co
            a = math.atan2(lp.z, lp.y)
            us.append((a / TAU) % 1.0)
            vs.append((lp.x + 0.20) / 0.40)
        if max(us) - min(us) > 0.5:
            us = [u + 1.0 if u < 0.5 else u for u in us]
        for li, u, v in zip(poly.loop_indices, us, vs):
            uv.data[li].uv = (u, v)


def shroud_soot(ob):
    """Vertex attribute 'soot': streaks trailing back (and a little up) from every drilled hole."""
    me = ob.data
    at = me.attributes.new('soot', 'FLOAT', 'POINT')
    vals = []
    for v in me.vertices:
        x, y, z = v.co
        r = math.hypot(y, z)
        if r < 0.03:
            vals.append(0.0)
            continue
        a = math.atan2(z, y)
        s = 0.0
        for hx, ha, hr in HOLES:
            da = (((a - ha + math.pi) % TAU) - math.pi) * SHR_R
            dx = x - hx
            # streak drifts back and slightly upward (the gun is usually fired level)
            da_up = da - (-dx) * 0.25 * math.copysign(1.0, math.cos(ha)) if dx < 0 else da
            along = math.exp(dx / 0.030) if dx < 0 else math.exp(-dx / 0.004)
            s += along * math.exp(-(da_up / (hr * 1.05)) ** 2)
        vals.append(min(1.0, s))
    at.data.foreach_set('value', vals)


def slot_cutter(col):
    """Radial drill bits for the shroud holes."""
    bm = bmesh.new()
    for (x, a, r) in (HOLES if hi_q() else HOLES[:18]):
        d = V((0, math.cos(a), math.sin(a)))
        cyl(bm, V((x, 0, 0)) + d * 0.040, V((x, 0, 0)) + d * 0.062, r, 12 if hi_q() else 6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('HoleCutter')
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new('HoleCutter', me)
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
    M = MB()
    R3 = M.to_3x3()
    for c, size in (((-0.193, -0.055, 0.0), (0.030, 0.03, 0.024)), ((-0.193, 0.055, 0.0), (0.030, 0.03, 0.024)),
                    ((-0.205, 0.0, 0.055), (0.034, 0.034, 0.026))):
        box(bm, M @ V(c), size, R3)
    me = bpy.data.meshes.new('CollarCutter')
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new('CollarCutter', me)
    col.objects.link(ob)
    return ob


def slash_cutter(col):
    """Slash cut on the muzzle tip: removes x > 0.630 + 0.75 z; its faces become 'LipScale'."""
    bm = bmesh.new()
    ang = math.atan(0.75)
    R = Matrix.Rotation(ang, 3, 'Y')    # tilt the cutting box
    n = V((1, 0, -0.75)).normalized()
    box(bm, V((0.630, 0, 0)) + n * 0.10, (0.2, 0.3, 0.3), R)
    me = bpy.data.meshes.new('SlashCutter')
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MAT['LipScale'])
    ob = bpy.data.objects.new('SlashCutter', me)
    col.objects.link(ob)
    return ob


def tag_inner(ob, mat_name, axis_ok=lambda p: True):
    """Faces whose normal points towards the bore axis (inside of the tip) get the soot crust."""
    me = ob.data
    names = [m.name for m in me.materials]
    if mat_name not in names:
        return
    idx = names.index(mat_name)
    keep = {names.index(n) for n in ('LipScale',) if n in names}
    for poly in me.polygons:
        if poly.material_index in keep:
            continue
        c = poly.center
        radial = V((0, c.y, c.z))
        if radial.length < 1e-6 or c.x < 0.536:
            continue
        if poly.normal.dot(radial.normalized()) < -0.4:
            poly.material_index = idx


def finish_objects(objs, col):
    cutter = slot_cutter(col)
    apply_bool(objs['HeatShroud'], cutter)
    bpy.data.objects.remove(cutter)
    cc = collar_cutter(col)
    apply_bool(objs['TankCollar'], cc)
    bpy.data.objects.remove(cc)
    sc = slash_cutter(col)
    apply_bool(objs['Muzzle'], sc, transfer=True)
    bpy.data.objects.remove(sc)
    tag_inner(objs['Muzzle'], 'SootInner')
    for ob in objs.values():
        ob.data.set_sharp_from_angle(angle=math.radians(38 if hi_q() else 64))
    tank_uvs(objs['Tank'])
    if hi_q():
        shroud_soot(objs['HeatShroud'])


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
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.adaptive_threshold = 0.015
    sc.cycles.use_denoising = True
    try:
        sc.cycles.denoiser = 'OPENIMAGEDENOISE'
        sc.cycles.denoising_prefilter = 'ACCURATE'
    except Exception:
        pass
    sc.cycles.max_bounces = 6
    sc.cycles.transparent_max_bounces = 8
    sc.render.resolution_x, sc.render.resolution_y = args.res
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.render.film_transparent = False
    try:
        sc.view_settings.view_transform = 'AgX'
        sc.view_settings.look = 'AgX - Medium High Contrast'
        sc.view_settings.exposure = -0.75
    except Exception:
        pass
    w = bpy.data.worlds.new('Studio')
    sc.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = w.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value = (0.0035, 0.0035, 0.004, 1)
    bg.inputs['Strength'].default_value = 1.0
    return bg


def add_floor(col, z, mat='Floor'):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=12)
    me = bpy.data.meshes.new('Floor')
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MAT[mat])
    ob = bpy.data.objects.new('Floor', me)
    ob.location = (0, 0, z)
    col.objects.link(ob)
    return ob


class Rig:
    """Camera + key / fill / two rims / top that follow the camera direction."""
    BASE = {'Key': 85, 'Fill': 10, 'Rim': 260, 'Kick': 150, 'Top': 6}

    def __init__(self, col):
        cd = bpy.data.cameras.new('Cam')
        self.cam = bpy.data.objects.new('Cam', cd)
        col.objects.link(self.cam)
        bpy.context.scene.camera = self.cam
        self.lights = {}
        for name, size, color in (('Key', 1.4, (1.0, 0.93, 0.85)), ('Fill', 2.5, (0.8, 0.88, 1.0)),
                                  ('Rim', 0.8, (1.0, 0.95, 0.9)), ('Kick', 0.8, (0.85, 0.9, 1.0)),
                                  ('Top', 3.0, (1, 1, 1))):
            ld = bpy.data.lights.new(name, 'AREA')
            ld.size = size
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
        self.mult = 1.0

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

    def frame(self, bbox, view_dir, lens=70, ortho=False, margin=1.12, up=(0, 0, 1), target=None, light_scale=1.0,
              shift=(0, 0), cam_lights=False):
        lo, hi = V(bbox[0]), V(bbox[1])
        center = V(target) if target else (lo + hi) / 2
        d = V(view_dir).normalized()
        corners = [V((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
        sc = bpy.context.scene
        aspect = sc.render.resolution_x / sc.render.resolution_y
        cam = self.cam
        cam.data.sensor_fit = 'HORIZONTAL'
        cam.data.sensor_width = 36
        cam.data.shift_x, cam.data.shift_y = shift
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
            lo_d, hi_d = 0.05, 60.0
            for _ in range(48):
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
        cam.data.clip_end = 200
        self.place_lights(center, max(1.6, dist * 0.8) * light_scale, cam_lights)

    def place_lights(self, center, L, cam_lights=False):
        R = self.cam.matrix_world.to_3x3()
        right, back = R.col[0], R.col[2]
        worldup = R.col[1] if cam_lights else V((0, 0, 1))
        place = {'Key': -right * 0.9 + worldup * 0.9 + back * 0.8, 'Fill': right * 1.1 + worldup * 0.1 + back * 0.8,
                 'Rim': right * 0.55 + worldup * 0.7 - back * 1.0, 'Kick': -right * 0.8 + worldup * 0.35 - back * 1.0,
                 'Top': worldup * 1.6}
        for name, off in place.items():
            ob = self.lights[name]
            loc = center + off.normalized() * L
            self.aim(ob, loc, center)
            ob.data.energy = self.BASE[name] * self.mult * (L / 2.0) ** 2


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
# exploded view: three rows, each laid out along X in assembly order (numbers follow reading order)
EXPLODE_ROWS = [
    ['stock', 'grip', 'pipe', 'cable'],
    ['fgrip', 'tee', 'valve', 'barrel', 'shroud', 'muzzle', 'pilot'],
    ['hose', 'regulator', 'bvalve', 'collar', 'tank', 'mount', 'pline'],
]


def explode_offsets(groups, gap=0.07, row_z=(0.0, -0.30, -0.62)):
    offs = {}
    for r, row in enumerate(EXPLODE_ROWS):
        bbs = {g: world_bbox(groups[g]) for g in row if g in groups}
        total = sum(bb[1].x - bb[0].x for bb in bbs.values()) + gap * (len(bbs) - 1)
        x = -total / 2
        for g in row:
            if g not in bbs:
                continue
            lo, hi = bbs[g]
            c = (lo + hi) / 2
            w = hi.x - lo.x
            offs[g] = V((x + w / 2, 0, row_z[r])) - c
            x += w + gap
    return offs


def build_dummy(col):
    s = 0.28
    obs = []
    parts = {'Torso': ((0, 0, 3 * s), (1 * s, 2 * s, 2 * s)),
             'LegL': ((0, 0.5 * s, 1 * s), (1 * s, 1 * s, 2 * s)), 'LegR': ((0, -0.5 * s, 1 * s), (1 * s, 1 * s, 2 * s))}
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


def solve_hold():
    """Find a weapon placement for a rigid-armed R6 dummy (arms only rotate at the shoulder).
    Right 'hand' (bottom face of the arm block) on the nozzle grip at belly height, left 'hand' on
    the file handle, gun pitched 5-10 deg down, stock tucked against the right hip.  With rigid
    2-stud arms on shoulders 3 studs apart the body has to be bladed ~30 deg to the gun."""
    import numpy as np
    s = 0.28
    SL, SR = np.array([0, 1.5 * s, 3.75 * s]), np.array([0, -1.5 * s, 3.75 * s])
    ARM = 1.75 * s                     # shoulder pivot to the bottom face of the arm block
    hr, hf = hand_points()
    hr, hf = np.array(hr), np.array(hf)
    gun_pts = np.array([[x, 0, 0] for x in np.linspace(-0.30, 0.67, 24)] +
                       [list(TANK_C + V((dx, 0, 0))) for dx in (-0.14, 0, 0.14)] + [list(hf)])
    stock_pts = np.array([[x, 0, z] for x in np.linspace(-0.56, -0.36, 6) for z in (0.0, -0.12)])
    rng = np.random.default_rng(7)
    best = None

    def body_pen(G, pad):
        return np.clip(np.minimum.reduce([0.14 + pad - np.abs(G[:, 0]), 0.28 + pad - np.abs(G[:, 1]),
                                          np.minimum(G[:, 2] - 0.5, 1.15 - G[:, 2])]), 0, None)
    for _ in range(160000):
        yaw = math.radians(rng.uniform(25, 60))
        pit = math.radians(rng.uniform(6, 10))
        cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pit), math.sin(pit)
        Rz = np.array([[cy, -sy, 0], [sy, cy, 0], [0, 0, 1]])
        Ry = np.array([[cp, 0, sp], [0, 1, 0], [-sp, 0, cp]])
        Rot = Rz @ Ry
        u = rng.normal(size=3)
        u /= np.linalg.norm(u)
        R = SR + u * rng.uniform(ARM - 0.12, ARM + 0.01)
        if R[0] < 0.05:
            continue
        tr = R - Rot @ hr
        F = Rot @ hf + tr
        dl = np.linalg.norm(F - SL)
        cost = 3000 * (max(0, dl - ARM - 0.01) ** 2 + max(0, ARM - 0.12 - dl) ** 2)   # grip in the hand/forearm zone
        cost += 200 * (R[2] - 0.78) ** 2 + (math.degrees(yaw) - 40) ** 2 / 400
        cost += 300 * float(np.sum(body_pen(gun_pts @ Rot.T + tr, 0.03) ** 2))
        cost += 300 * float(np.sum(body_pen(stock_pts @ Rot.T + tr, -0.05) ** 2))   # the butt tucks against the body
        for S_, H_ in ((SR, R), (SL, F)):   # arms should not dive through the torso
            for t in (0.3, 0.55, 0.8):
                pnt = S_ + (H_ - S_) * t
                pn = min(0.14 + 0.01 - abs(pnt[0]), 0.28 + 0.01 - abs(pnt[1]))
                if pn > 0 and 0.5 < pnt[2] < 1.15:
                    cost += 60 * pn ** 2
        if best is None or cost < best[0]:
            best = (cost, yaw, pit, R, F, tr, Rot)
    cost, yaw, pit, R, F, tr, Rot = best
    print('HOLD cost %.4f yaw %.1f pitch %.1f right %s left %s  reachL %.3f reachR %.3f' % (
        cost, math.degrees(yaw), math.degrees(pit), np.round(R, 3), np.round(F, 3),
        np.linalg.norm(F - SL), np.linalg.norm(R - SR)), flush=True)
    W = Matrix.Translation(V(tuple(tr))) @ Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(pit, 4, 'Y')
    return W, V(tuple(R)), V(tuple(F)), yaw


def pose_arm(arm, target):
    piv = arm.location.copy()
    d = (target - piv).normalized()
    q_ = V((0, 0, -1)).rotation_difference(d)
    arm.rotation_mode = 'QUATERNION'
    arm.rotation_quaternion = q_


def cut_objects(col, objs, names, plane_y):
    """Sectioned copies (y < plane_y removed) of the named parts; returns the new objects."""
    bm = bmesh.new()
    box(bm, (0, plane_y - 1.0, 0), (3, 2.0, 3))
    me = bpy.data.meshes.new('SectionBox')
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MAT['Section'])
    cutter = bpy.data.objects.new('SectionBox', me)
    col.objects.link(cutter)
    out = []
    for name in names:
        src = objs[name]
        ob = src.copy()
        ob.data = src.data.copy()
        ob.name = name + '_cut'
        ob.hide_render = False
        col.objects.link(ob)
        if name == 'Tank':
            ob.data.materials.append(MAT['SteelDark'])
            sol = ob.modifiers.new('sol', 'SOLIDIFY')
            sol.thickness = 0.004
            sol.offset = -1
            sol.material_offset = 1
            sol.material_offset_rim = 1
            dg = bpy.context.evaluated_depsgraph_get()
            dg.update()
            me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
            ob.modifiers.clear()
            ob.data = me2
        apply_bool(ob, cutter, 'DIFFERENCE', transfer=True)
        out.append(ob)
    bpy.data.objects.remove(cutter)
    return out


def cutaway_extras(col):
    """Liquid propane (level, pooled nose-down) and the dip tube, already cut at the bottle plane."""
    out = []
    M = MB()
    bm = bmesh.new()
    prof = [(-0.168, 0.0)]
    for i in range(1, 9):
        ph = (math.pi / 2) * i / 8
        prof.append((-0.121 - 0.044 * math.cos(ph), (TANK_R - 0.005) * math.sin(ph)))
    prof += [(0.121 + 0.044 * math.cos(ph), (TANK_R - 0.005) * math.sin(ph))
             for ph in [(math.pi / 2) * i / 8 for i in range(8, 0, -1)]] + [(0.168, 0.0)]
    lathe(bm, prof, 48, M)
    me = bpy.data.meshes.new('Liquid')
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MAT['Liquid'])
    liq = bpy.data.objects.new('PropaneLiquid', me)
    col.objects.link(liq)
    bm = bmesh.new()
    level = TANK_C.z - 0.015
    box(bm, (0, TANK_C.y + 0.5, level - 0.5), (3, 1.0, 1.0))
    me = bpy.data.meshes.new('LiqBox')
    bm.to_mesh(me)
    bm.free()
    lb = bpy.data.objects.new('LiqBox', me)
    col.objects.link(lb)
    apply_bool(liq, lb, 'INTERSECT')
    bpy.data.objects.remove(lb)
    liq.data.shade_smooth()
    out.append(liq)
    bm = bmesh.new()
    off = V((0, 0.0025, 0))
    sweep(bm, crs([M @ V((-0.172, 0, 0)) + off, M @ V((-0.150, 0, -0.025)) + off, M @ V((-0.06, 0, -0.068)) + off,
                   M @ V((0.08, 0, -0.078)) + off, M @ V((0.13, 0, -0.075)) + off], 6), 0.0035, 10)
    me = bpy.data.meshes.new('DipTube')
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MAT['Copper'])
    me.shade_smooth()
    dt = bpy.data.objects.new('DipTube', me)
    col.objects.link(dt)
    out.append(dt)
    return out


# --------------------------------------------------------------------------------------
# 2D post: contact sheet, labels, silhouettes
# --------------------------------------------------------------------------------------
def font(size, bold=False):
    from PIL import ImageFont
    try:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf' % ('-Bold' if bold else ''), size)
    except Exception:
        return ImageFont.load_default()


def contact_sheet(out_dir, files):
    from PIL import Image, ImageDraw
    tw, th = 520, 325
    cols = 3
    rows = math.ceil(len(files) / cols)
    pad, lab = 10, 26
    sheet = Image.new('RGB', (cols * (tw + pad) + pad, rows * (th + lab + pad) + pad + 44), (12, 12, 13))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 10), 'Pyromaniac finisher - improvised flamethrower v2 (look-dev)', fill=(220, 210, 195), font=font(22, True))
    for i, fpath in enumerate(files):
        im = Image.open(fpath).convert('RGB')
        im.thumbnail((tw, th))
        x = pad + (i % cols) * (tw + pad)
        y = 44 + pad + (i // cols) * (th + lab + pad)
        sheet.paste(im, (x + (tw - im.width) // 2, y + (th - im.height) // 2))
        d.text((x + 4, y + th + 3), os.path.splitext(os.path.basename(fpath))[0], fill=(190, 185, 175), font=font(17))
    sheet.save(os.path.join(out_dir, 'sheet.png'))
    return os.path.join(out_dir, 'sheet.png')


def project(co):
    from bpy_extras.object_utils import world_to_camera_view
    sc = bpy.context.scene
    p = world_to_camera_view(sc, sc.camera, V(co))
    return p.x * sc.render.resolution_x, (1 - p.y) * sc.render.resolution_y


def annotate_exploded(path, items):
    """items: [(label, anchor_xy (part bottom), centre_xy, number, row)].  Dashed guide through each row
    (the assembly axis), a short leader from each part down to its label, labels staggered in two tiers."""
    from PIL import Image, ImageDraw
    im = Image.open(path).convert('RGB')
    d = ImageDraw.Draw(im)
    W, H = im.size
    k = W / 1600.0
    f = font(max(10, int(16 * k)))
    fb = font(max(10, int(16 * k)), True)
    rows = {}
    for it in items:
        rows.setdefault(it[4], []).append(it)
    for r, its in rows.items():
        its.sort(key=lambda it: it[2][0])
        cy = sum(it[2][1] for it in its) / len(its)
        x0, x1 = its[0][2][0] - 30 * k, its[-1][2][0] + 30 * k
        xx = x0
        while xx < x1:
            d.line([(xx, cy), (min(xx + 10 * k, x1), cy)], fill=(95, 120, 140), width=max(1, int(2 * k)))
            xx += 18 * k
        for j, (lab, (ax, ay), (cx, cyy), num, _) in enumerate(its):
            lines = lab.split('\n')
            bw = max(d.textlength(s_, font=f) for s_ in lines) + 40 * k
            bh = (20 * len(lines) + 6) * k
            ty = ay + (14 + 46 * (j % 2)) * k
            tx = min(max(6, cx - bw / 2), W - bw - 6)
            d.line([(cx, ay - 4 * k), (cx, ty)], fill=(200, 190, 170), width=max(1, int(1.5 * k)))
            d.ellipse((cx - 4 * k, ay - 8 * k, cx + 4 * k, ay), fill=(230, 160, 60))
            d.rectangle((tx, ty, tx + bw, ty + bh), fill=(16, 16, 18), outline=(85, 83, 80))
            d.text((tx + 6 * k, ty + 3 * k), '%d' % num, fill=(230, 160, 60), font=fb)
            for q_, s_ in enumerate(lines):
                d.text((tx + 32 * k, ty + (3 + 20 * q_) * k), s_, fill=(225, 218, 205), font=f)
    d.text((14 * k, H - 30 * k), 'exploded view - each row laid out along the assembly axis; numbers = assembly order',
           fill=(165, 160, 150), font=f)
    im.save(path)


def silhouette_compare(out_dir, ours_alpha_png, tf2_ref, path):
    """Black flat silhouettes at the same length: ours (side profile) vs the reference image."""
    from PIL import Image, ImageDraw, ImageOps
    import numpy as np
    W, H = 1600, 1000
    sheet = Image.new('RGB', (W, H), (236, 234, 230))
    d = ImageDraw.Draw(sheet)

    def crop_mask(m):
        bb = m.getbbox()
        return m.crop(bb)
    a = Image.open(ours_alpha_png).split()[-1]
    ours = crop_mask(a.point(lambda v: 255 if v > 90 else 0))
    rows = [('v2 (this model) - side profile', ours)]
    if tf2_ref and os.path.exists(tf2_ref):
        ref = Image.open(tf2_ref).convert('RGBA')
        arr = np.asarray(ref).astype(np.float32)
        lum = arr[..., :3].mean(axis=2)
        alpha = arr[..., 3]
        m = ((lum < 228) & (alpha > 40)).astype(np.uint8) * 255
        refm = ImageOps.mirror(crop_mask(Image.fromarray(m)))
        rows.append(('reference image (user ref 40, perspective) - same length', refm))
    L = 1000
    y = 70
    d.text((40, 20), 'Silhouette test - flat black, equal length; right column = gameplay size (~100 px, 17 studs)',
           fill=(30, 30, 30), font=font(24, True))
    for title, m in rows:
        sc_ = L / m.width
        big = m.resize((L, max(1, int(m.height * sc_))), Image.LANCZOS)
        smallw = 100
        small = m.resize((smallw, max(1, int(m.height * smallw / m.width))), Image.LANCZOS)
        d.text((40, y), title, fill=(40, 40, 40), font=font(22))
        blk = Image.new('RGB', big.size, (10, 10, 10))
        sheet.paste(blk, (40, y + 34), big)
        blk2 = Image.new('RGB', small.size, (10, 10, 10))
        sheet.paste(blk2, (1250, y + 34 + big.height // 2 - small.height // 2), small)
        y += big.height + 90
    sheet.save(path)


# --------------------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------------------
def build_all(col, decal):
    build_materials(decal)
    build_parts()
    objs = build_objects(col)
    finish_objects(objs, col)
    return objs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--fbx', default=None)
    ap.add_argument('--blend', default=None)
    ap.add_argument('--samples', type=int, default=96)
    ap.add_argument('--close-samples', type=int, default=160)
    ap.add_argument('--res', default='1600x1000')
    ap.add_argument('--only', default='')
    ap.add_argument('--quick', action='store_true')
    ap.add_argument('--game-q', type=float, default=0.5)
    ap.add_argument('--tf2-ref', default=None)
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    args = ap.parse_args(argv)
    args.res = tuple(int(v) for v in args.res.split('x'))
    if args.quick:
        args.res = (args.res[0] // 2, args.res[1] // 2)
        args.samples = min(args.samples, 16)
        args.close_samples = min(args.close_samples, 24)
    os.makedirs(args.out, exist_ok=True)
    only = set(v for v in args.only.split(',') if v)

    global SEGQ
    SEGQ = 1.0
    bpy.ops.wm.read_factory_settings(use_empty=True)
    col = bpy.context.scene.collection
    decal = make_decal(os.path.join(args.out, '_bottle_stencil.png'))
    objs = build_all(col, decal)
    tris = tri_counts({k: v for k, v in objs.items() if k != 'PilotFlame'})
    print('TRIS', sum(tris.values()), sorted(tris.items(), key=lambda kv: -kv[1])[:8], flush=True)

    sc = bpy.context.scene
    bg = setup_scene(args)
    floor = add_floor(col, FLOOR_Z)
    rig = Rig(col)
    GLOW = V((0.64, 0, -0.046))
    rig.glow.location = GLOW

    weapon = list(objs.values())
    solid = [o for o in weapon if o.name not in ('PilotFlame', 'ValveBall')]
    objs['ValveBall'].hide_render = True
    lo, hi = world_bbox(solid)
    print('BBOX', tuple(round(v, 3) for v in lo), tuple(round(v, 3) for v in hi), 'length', round(hi.x - lo.x, 3), flush=True)
    full = (lo, hi)
    rendered = []

    def want(tag):
        return not only or tag in only

    def shot(tag, name, samples=None, **kw):
        if not want(tag):
            return None
        sc.cycles.samples = samples or args.samples
        rig.frame(**kw)
        p = os.path.join(args.out, f'{tag}_{name}.png')
        render(p)
        rendered.append(p)
        return p

    cs = args.close_samples
    # 01 true front: muzzle-on at eye height, near-orthographic, gun ~60% of the frame height
    shot('01', 'front', bbox=full, view_dir=(1, 0.0, 0.035), lens=400, margin=1.22)
    shot('02', 'side_profile', bbox=full, view_dir=(0, -1, 0.02), ortho=True, margin=1.08)
    shot('03', 'three_quarter_front', bbox=full, view_dir=(0.8, -0.85, 0.40), lens=60, margin=1.06)
    shot('04', 'three_quarter_back', bbox=full, view_dir=(-0.8, -0.75, 0.42), lens=60, margin=1.06)
    shot('05', 'top', bbox=full, view_dir=(0, -0.001, 1), ortho=True, margin=1.10, up=(0, 1, 0), cam_lights=True)
    shot('06', 'closeup_grip_trigger_hose', cs, bbox=(V((-0.58, -0.05, -0.15)), V((-0.17, 0.03, 0.03))),
         view_dir=(0.30, -1, 0.25), lens=85, margin=1.03)
    shot('07', 'closeup_tank_valve_gauge', cs, bbox=(V((0.05, -0.23, -0.17)), V((0.22, -0.04, 0.02))),
         view_dir=(-0.55, -1, 0.35), lens=85, margin=1.02)
    shot('08', 'closeup_muzzle_shroud_pilot', cs, bbox=(V((0.38, -0.07, -0.09)), V((0.68, 0.07, 0.06))),
         view_dir=(0.85, -1, 0.12), lens=85, margin=1.02)

    if want('09'):
        groups = {}
        for ob in solid:
            groups.setdefault(ob['group'], []).append(ob)
        offs = explode_offsets(groups)
        for ob in weapon:
            ob.location = offs.get(ob['group'], V((0, 0, 0)))
        bpy.context.view_layer.update()
        rig.glow.location = GLOW + offs['pilot']
        floor.location.z = FLOOR_Z - 0.60
        lo2, hi2 = world_bbox(solid)
        lo2.z -= 0.10
        p = shot('09', 'exploded', bbox=(lo2, hi2), view_dir=(0.0, -1, 0.10), ortho=True, margin=1.04)
        items = []
        num = 0
        for r, row in enumerate(EXPLODE_ROWS):
            pts = []
            for g in row:
                if g not in groups:
                    continue
                num += 1
                lo_g, hi_g = world_bbox(groups[g])
                c = (lo_g + hi_g) / 2
                items.append((LABELS.get(g, g), project(V((c.x, c.y, lo_g.z))), project(c), num, r))
        annotate_exploded(p, items)
        for ob in weapon:
            ob.location = (0, 0, 0)
        rig.glow.location = GLOW
        floor.location.z = FLOOR_Z

    if want('10'):
        bore = ['FeedPipe', 'Barrel', 'HeatShroud', 'Muzzle', 'TeeFitting', 'BallValve', 'ValveBall']
        bottle = ['Tank', 'TankCollar', 'TankValve']
        cuts = cut_objects(col, objs, bore, 0.0) + cut_objects(col, objs, bottle, TANK_C.y) + cutaway_extras(col)
        for n in bore + bottle:
            objs[n].hide_render = True
        hidden = ['Hose', 'HoseFittings', 'Regulator', 'Gauge', 'PilotLine', 'TankBands', 'TankRail', 'BoltsMount',
                  'WeldsMount', 'TapeFeed', 'BrakeCable', 'ValveLever', 'WeldsShroud', 'WeldsMuzzle', 'ShroudClamps',
                  'ValveWheel']
        for n in hidden:
            objs[n].hide_render = True
        shot('10', 'cutaway', cs, bbox=full, view_dir=(0.08, -1, 0.20), lens=60, margin=1.04)
        for n in objs:
            objs[n].hide_render = False
        objs['ValveBall'].hide_render = True
        for ob in cuts:
            bpy.data.objects.remove(ob)

    shot('13', 'rear', bbox=full, view_dir=(-1, 0.0, 0.035), lens=400, margin=1.22)
    if want('14'):
        floor.hide_render = True
        shot('14', 'underside', bbox=full, view_dir=(0, 0.001, -1), ortho=True, margin=1.10, up=(0, -1, 0), cam_lights=True)
        floor.hide_render = False

    if want('11') or want('12') or want('15'):
        dummy, arms = build_dummy(col)
        floor.location.z = 0.0
        W, Rh, Fh, yaw = solve_hold()
        pose_arm(arms['R'], Rh)
        pose_arm(arms['L'], Fh)
        rigE = bpy.data.objects.new('WeaponRig', None)
        col.objects.link(rigE)
        for ob in weapon:
            ob.parent = rigE
        rigE.matrix_world = W
        bpy.context.view_layer.update()
        rig.glow.location = W @ GLOW
        lo3, hi3 = world_bbox(dummy + solid)
        lo3.z = 0.0
        gd = V((math.cos(yaw), math.sin(yaw), 0))
        gr = V((math.sin(yaw), -math.cos(yaw), 0))     # weapon's right side
        shot('11', 'scale_r6_dummy', bbox=(lo3, hi3), view_dir=V((0.75, -1.0, 0.70)), lens=50,
             margin=1.06, light_scale=1.3)
        # square to the gun's right side: the gun in profile, both arms reaching down to the grips
        shot('12', 'scale_r6_dummy_side', bbox=(lo3, hi3), view_dir=gr + V((0, 0, 0.10)), ortho=True, margin=1.08,
             light_scale=1.3)
        if want('15'):
            # gameplay distance: ~17 studs, Roblox default 70 deg vertical FOV, mid-grey ground, 480p
            from PIL import Image, ImageDraw
            floor.data.materials[0] = MAT['Ground']
            dcol = MAT['Dummy'].node_tree.nodes['Principled BSDF'].inputs['Base Color']
            dcol.default_value = (0.30, 0.30, 0.31, 1)
            bg.inputs['Color'].default_value = (0.30, 0.34, 0.40, 1)
            bg.inputs['Strength'].default_value = 0.55
            saved = {n: o.data.energy for n, o in rig.lights.items()}
            for o in rig.lights.values():
                o.data.energy = 0.0
            sd = bpy.data.lights.new('Sun', 'SUN')
            sd.energy = 3.2
            sd.angle = math.radians(2.5)
            sun = bpy.data.objects.new('Sun', sd)
            col.objects.link(sun)
            Rig.aim(sun, V((0, 0, 0)), V((0.45, -0.55, -0.70)))
            old_res = (sc.render.resolution_x, sc.render.resolution_y)
            sc.render.resolution_x, sc.render.resolution_y = 1708, 960
            sc.cycles.samples = 48
            tiles = []
            vfov = math.radians(70)
            for k, vd in enumerate((gr + V((0, 0, 0.12)), -gd * 0.7 + gr * 0.9 + V((0, 0, 0.35)))):
                cam = rig.cam
                cam.data.type = 'PERSP'
                cam.data.sensor_fit = 'VERTICAL'
                cam.data.sensor_height = 24
                cam.data.lens = 12 / math.tan(vfov / 2)
                cam.data.shift_x = cam.data.shift_y = 0
                tgt = V((0, 0, 0.8))
                Rig.aim(cam, tgt + vd.normalized() * 17 * 0.28, tgt)
                pp = os.path.join(args.out, '_gp%d.png' % k)
                render(pp)
                tiles.append(Image.open(pp).convert('RGB').resize((854, 480), Image.LANCZOS))
                os.remove(pp)
            cam.data.sensor_fit = 'HORIZONTAL'
            strip = Image.new('RGB', (1708, 480 + 40), (12, 12, 13))
            for k, t_ in enumerate(tiles):
                strip.paste(t_, (854 * k, 40))
            ImageDraw.Draw(strip).text((10, 8), 'gameplay distance: 17 studs, 70 deg FOV, sun + sky, 854x480 each (side / over-shoulder)',
                                       fill=(220, 210, 195), font=font(20))
            p = os.path.join(args.out, '15_gameplay_distance.png')
            strip.save(p)
            rendered.append(p)
            sc.render.resolution_x, sc.render.resolution_y = old_res
            floor.data.materials[0] = MAT['Floor']
            dcol.default_value = (0.11, 0.11, 0.115, 1)
            bg.inputs['Color'].default_value = (0.0035, 0.0035, 0.004, 1)
            bg.inputs['Strength'].default_value = 1.0
            bpy.data.objects.remove(sun)
            for n, o in rig.lights.items():
                o.data.energy = saved[n]
        for ob in weapon:
            ob.parent = None
            ob.matrix_world = Matrix()
        for ob in dummy + [rigE]:
            bpy.data.objects.remove(ob)
        floor.location.z = FLOOR_Z
        rig.glow.location = GLOW

    if want('16'):
        sc.render.film_transparent = True
        floor.hide_render = True
        objs['PilotFlame'].hide_render = True
        old = sc.cycles.samples
        sc.cycles.samples = 4
        rig.frame(bbox=full, view_dir=(0, -1, 0.0), ortho=True, margin=1.02)
        pa = os.path.join(args.out, '_sil.png')
        render(pa)
        p = os.path.join(args.out, '16_silhouette_vs_reference.png')
        silhouette_compare(args.out, pa, args.tf2_ref, p)
        os.remove(pa)
        rendered.append(p)
        sc.cycles.samples = old
        sc.render.film_transparent = False
        floor.hide_render = False
        objs['PilotFlame'].hide_render = False

    if args.blend:
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args.blend))
        print('BLEND', args.blend, flush=True)

    if args.fbx or want('17'):
        SEGQ = args.game_q
        PARTS.clear()
        bpy.ops.wm.read_factory_settings(use_empty=True)
        col = bpy.context.scene.collection
        MAT.clear()
        gobjs = build_all(col, None)
        gt = tri_counts({k: v for k, v in gobjs.items() if k not in ('PilotFlame', 'ValveBall')})
        print('GAME TRIS', sum(gt.values()), sorted(gt.items(), key=lambda kv: -kv[1]), flush=True)
        if args.fbx:
            export_fbx(gobjs, args.fbx)
        if want('17'):
            sc = bpy.context.scene
            setup_scene(args)
            sc.cycles.samples = 64
            add_floor(col, FLOOR_Z)
            rig = Rig(col)
            for n, ob in gobjs.items():
                if n in ('PilotFlame', 'ValveBall'):
                    ob.hide_render = True
                    continue
                ob.data.materials.clear()
                ob.data.materials.append(MAT['FlatGrey'])
            lo, hi = world_bbox([o for n, o in gobjs.items() if n not in ('PilotFlame', 'ValveBall')])
            rig.frame(bbox=(lo, hi), view_dir=(0.55, -1, 0.35), lens=60, margin=1.05)
            p = os.path.join(args.out, '17_game_mesh.png')
            render(p)
            from PIL import Image, ImageDraw
            im = Image.open(p).convert('RGB')
            ImageDraw.Draw(im).text((24, 20), 'game FBX mesh (flat grey): %d tris, %d parts, biggest part %s %d tris' % (
                sum(gt.values()), len(gt), max(gt, key=gt.get), max(gt.values())), fill=(225, 218, 205), font=font(20))
            im.save(p)
            rendered.append(p)

    files = sorted(os.path.join(args.out, f) for f in os.listdir(args.out)
                   if f[:2].isdigit() and f.endswith('.png'))
    if files:
        print('SHEET', contact_sheet(args.out, files), flush=True)


def export_fbx(objs, path):
    """Separate named mesh parts, metres (import in Roblox with 'Meter' units), no flame/studio."""
    for ob in bpy.context.scene.objects:
        ob.select_set(False)
    keep = [o for n, o in objs.items() if n not in ('PilotFlame', 'ValveBall')]
    for ob in keep:
        ob.select_set(True)
        if not ob.data.uv_layers:
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
