#!/usr/bin/env python3
"""gunkit: the shared procedural toolkit for the firearms (Blender 5.3 headless, bpy).

Every gun script (`pistol.py`, `shotgun.py`, `rifle.py`, `sniper.py`, `lmg.py`) imports this module and
never edits it.  It follows the "Model contract" of docs/firearms/ARCHITECTURE.md §5 and the tooling style
of tools/pyro/flamethrower.py (bmesh builders that tag material indices, procedural PBR materials, a
camera / light rig, contact sheets, an R6 dummy and a hold solver).

Run a gun script with:  /home/user/z-anatomy/venv/bin/python -I tools/guns/<gun>.py --out DIR
(`-I` isolates Python, so each gun script puts this folder on sys.path itself.)

Conventions (model space, ARCHITECTURE §5.1):
  * metres, +X = muzzle (bore), +Y = the gun's LEFT, +Z = up; origin on the bore at the breech face.
  * Roblox gun space (studs): roblox = (-y, z, -x) / 0.28   (STUD = 0.28 m).
  * 2D outlines for side profiles are lists of (x, z) in metres (the side view, muzzle to +x).
  * 2D cross-sections for along-X extrusions are lists of (y, z).

Sections:
  1. maths / 2D outlines           (smoothstep, frame_x, fillet2, arc2, offset2, teeth2, ...)
  2. bmesh builders                (lathe, cyl, tube, box, rbox, sweep, torus, prism, profile, section_x, merge,
                                    rrect2 + loft for grips / stocks from stacked sections)
  3. booleans and cutters          (boolean_bm, serration_cutter, hole_cutter, slot_cutter)
  4. hardware and accessories      (pin, screw, picatinny, sling_swivel, red_dot, scope, prism_sight, bipod, sling)
  5. ammunition and magazines      (CARTRIDGES, case_profile, build_case, build_round, box_mag)
  6. materials                     (NB node builder, build_materials: the paint keys of §5.1)
  7. the gun model                 (GunModel / Part: named parts, pivots, groups, hinges, markers, JSON)
  8. UV atlas, baking, export      (uv_atlas, bake_atlas, baked_material, export_fbx, tri_counts)
  9. studio and renders            (reset_scene, setup_render, Rig, render, contact_sheet, ref_compare)
 10. R6 rig and the hold solver    (r6_frames, HoldSolver, build_r6, place_gun, holds JSON)
"""
import json
import math
import os
import random

import bpy
import bmesh
from mathutils import Matrix, Vector

TAU = 2 * math.pi
V = Vector
STUD = 0.28          # metres per stud (as the flamethrower)
MM = 0.001
SEGQ = 1.0           # segment-count scale for round things (1 = renders and FBX; lower to save triangles)


def set_quality(q):
    """Scale the segment counts of every round builder (lathe/cyl/tube/torus/sweep)."""
    global SEGQ
    SEGQ = q


def q(segs, lo=6):
    """A segment count scaled by SEGQ, never under `lo` (and never changed when already <= lo)."""
    return segs if segs <= lo else max(lo, int(round(segs * SEGQ)))


# ======================================================================================
# 1. maths and 2D outlines
# ======================================================================================

def smoothstep(a, b, x):
    """Hermite 0..1 step of x between a and b."""
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    """Linear interpolation of numbers or Vectors."""
    return a + (b - a) * t


def frame_x(origin, xdir, up=(0, 0, 1)):
    """4x4 matrix whose local X is `xdir` (local Z as close to `up` as possible), placed at `origin`."""
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
    """3x3 matrix with the given columns."""
    return Matrix((V(X), V(Y), V(Z))).transposed()


def xz(p, y=0.0):
    """(x, z) side-view point -> 3D Vector (x, y, z)."""
    return V((p[0], y, p[1]))


def arc2(c, r, a0, a1, n):
    """n+1 points on a circle arc (2D), angles in degrees, a0 -> a1."""
    return [(c[0] + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             c[1] + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def fillet2(pts, r, n=3, closed=True, radii=None):
    """Round the corners of a 2D polyline.  `r` is the default radius, `radii` an optional per-vertex list
    (0 = keep the sharp corner).  Each rounded corner becomes n+1 points.  Radii are clamped to 45 % of the
    adjacent edges so short edges never fold over."""
    out = []
    m = len(pts)
    for i in range(m):
        p = V(pts[i])
        rr = r if radii is None else radii[i]
        if (not closed and (i == 0 or i == m - 1)) or rr <= 0:
            out.append(tuple(p))
            continue
        a, b = V(pts[i - 1]), V(pts[(i + 1) % m])
        d0, d1 = (a - p), (b - p)
        l0, l1 = d0.length, d1.length
        if l0 < 1e-9 or l1 < 1e-9:
            out.append(tuple(p))
            continue
        d0.normalize()
        d1.normalize()
        cosang = max(-0.9999, min(0.9999, d0.dot(d1)))
        ang = math.acos(cosang)
        if ang > math.radians(178):
            out.append(tuple(p))
            continue
        t = rr / math.tan(ang / 2)
        t = min(t, 0.45 * l0, 0.45 * l1)
        rr = t * math.tan(ang / 2)
        p0, p1 = p + d0 * t, p + d1 * t
        bis = (d0 + d1).normalized()
        c = p + bis * (rr / math.sin(ang / 2))
        a0 = math.atan2((p0 - c).y, (p0 - c).x)
        a1 = math.atan2((p1 - c).y, (p1 - c).x)
        da = (a1 - a0 + math.pi) % TAU - math.pi
        for k in range(n + 1):
            aa = a0 + da * k / n
            out.append((c.x + rr * math.cos(aa), c.y + rr * math.sin(aa)))
    return out


def offset2(pts, d):
    """Offset a closed 2D polygon by d (positive = outward for a counter-clockwise polygon); miter joins."""
    m = len(pts)
    out = []
    for i in range(m):
        a, p, b = V(pts[i - 1]), V(pts[i]), V(pts[(i + 1) % m])
        e0 = (p - a).normalized()
        e1 = (b - p).normalized()
        n0 = V((e0.y, -e0.x))
        n1 = V((e1.y, -e1.x))
        nb = (n0 + n1)
        if nb.length < 1e-6:
            nb = n0
        nb.normalize()
        k = d / max(0.3, nb.dot(n0))
        out.append(tuple(p + nb * k))
    return out


def area2(pts):
    """Signed area of a 2D polygon (positive = counter-clockwise)."""
    return 0.5 * sum(pts[i - 1][0] * pts[i][1] - pts[i][0] * pts[i - 1][1] for i in range(len(pts)))


def ccw(pts):
    """The polygon in counter-clockwise order."""
    return list(pts) if area2(pts) > 0 else list(reversed(pts))


def along(p0, p1, t):
    """Point at fraction t on the 2D segment p0 -> p1."""
    return (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t)


def teeth2(p0, p1, n, depth, duty=0.5, side=1.0):
    """A straight 2D edge p0 -> p1 replaced by n rectangular notches `depth` deep (checkering / serrations
    seen in silhouette).  `side` = +1 cuts to the left of the walking direction, -1 to the right.
    Returns the points from p0 to p1 inclusive."""
    p0, p1 = V(p0), V(p1)
    e = (p1 - p0)
    L = e.length
    e.normalize()
    nrm = V((-e.y, e.x)) * side
    out = [tuple(p0)]
    pitch = L / n
    for i in range(n):
        s0 = p0 + e * (pitch * (i + (1 - duty) / 2))
        s1 = p0 + e * (pitch * (i + (1 + duty) / 2))
        out += [tuple(s0), tuple(s0 + nrm * depth), tuple(s1 + nrm * depth), tuple(s1)]
    out.append(tuple(p1))
    return out


def resample2(pts, closed=False):
    """Remove consecutive duplicate points of a 2D polyline."""
    out = []
    for p in pts:
        if not out or (V(p) - V(out[-1])).length > 1e-7:
            out.append(tuple(p))
    if closed and len(out) > 2 and (V(out[0]) - V(out[-1])).length < 1e-7:
        out.pop()
    return out


# ======================================================================================
# 2. bmesh builders (every builder appends to a bmesh and tags its new faces with a material index)
# ======================================================================================

def _tag(bm, n0, mi):
    bm.faces.ensure_lookup_table()
    for f in bm.faces[n0:]:
        f.material_index = mi


def merge(bm, src, M=None, mi=None):
    """Append the geometry of bmesh `src` into `bm` (optionally transformed by M; material index forced
    to `mi` when given, else kept)."""
    M = M or Matrix()
    vmap = {}
    for v in src.verts:
        vmap[v] = bm.verts.new(M @ v.co)
    for f in src.faces:
        try:
            nf = bm.faces.new([vmap[v] for v in f.verts])
        except ValueError:
            continue
        nf.material_index = f.material_index if mi is None else mi
        nf.smooth = f.smooth
    return bm


def lathe(bm, prof, segs=24, M=None, closed=False, th=None, pert=None, mi=0):
    """Revolve a profile [(x, r), ...] around local X.  Open profiles go with increasing x; closed profiles
    go clockwise in the (x right, r up) plane; both give outward normals.  `th` = (a0, a1) radians for a
    partial revolve; `pert(x, r, a)` adds a radius perturbation."""
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


def cyl(bm, p0, p1, r, segs=12, mi=0, r1=None, up=(0, 0, 1)):
    """Closed cylinder (or cone frustum with end radius r1) from p0 to p1."""
    p0, p1 = V(p0), V(p1)
    L = (p1 - p0).length
    lathe(bm, [(0, 0), (0, r), (L, r if r1 is None else r1), (L, 0)], segs, frame_x(p0, p1 - p0, up), mi=mi)


def tube(bm, p0, p1, rin, rout, segs=16, mi=0, mi_in=None):
    """Thick-walled tube from p0 to p1 (open bore); the bore faces can take another material."""
    p0, p1 = V(p0), V(p1)
    L = (p1 - p0).length
    n0 = len(bm.faces)
    lathe(bm, [(0, rin), (0, rout), (L, rout), (L, rin)], segs, frame_x(p0, p1 - p0), mi=mi, closed=True)
    if mi_in is not None:
        bm.faces.ensure_lookup_table()
        ax = (p1 - p0).normalized()
        for f in bm.faces[n0:]:
            c = f.calc_center_median()
            rel = c - p0
            rad = (rel - ax * rel.dot(ax)).length
            if rad < (rin + rout) / 2 and abs(f.normal.dot(ax)) < 0.5:
                f.material_index = mi_in


def box(bm, center, size, R=None, mi=0):
    """Axis box (or rotated by 3x3 R) centred at `center` with full extents `size`."""
    n0 = len(bm.faces)
    R = R or Matrix.Identity(3)
    res = bmesh.ops.create_cube(bm, size=1.0)
    for v in res['verts']:
        v.co = V(center) + R @ V((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    _tag(bm, n0, mi)


def rbox(bm, center, size, bevel=0.001, segs=1, R=None, mi=0):
    """Bevelled box: a box whose 12 edges are chamfered (segs=1) or rounded (segs>1) by `bevel`."""
    t = bmesh.new()
    box(t, (0, 0, 0), size)
    bmesh.ops.bevel(t, geom=list(t.edges) + list(t.verts), offset=bevel, segments=segs, affect='EDGES',
                    profile=0.5, clamp_overlap=True)
    M = Matrix.Translation(V(center)) @ (R.to_4x4() if R is not None else Matrix())
    merge(bm, t, M, mi)
    t.free()


def torus(bm, c, axis, R, r, su=24, sv=6, mi=0):
    """Torus of major radius R and minor radius r around `axis` through c."""
    M = frame_x(c, axis)
    su, sv = q(su), q(sv, 4)
    n0 = len(bm.faces)
    rings = []
    for i in range(su):
        a = TAU * i / su
        ring = []
        for j in range(sv):
            b = TAU * j / sv
            rr = R + r * math.cos(b)
            ring.append(bm.verts.new(M @ V((r * math.sin(b), rr * math.cos(a), rr * math.sin(a)))))
        rings.append(ring)
    for i in range(su):
        A, B = rings[i], rings[(i + 1) % su]
        for j in range(sv):
            j1 = (j + 1) % sv
            bm.faces.new((A[j], B[j], B[j1], A[j1]))
    _tag(bm, n0, mi)


def crs(pts, k=6):
    """Catmull-Rom resampling of a 3D polyline: k points per span (smooth hoses, straps, wires)."""
    P = [V(p) for p in pts]
    out = []
    for i in range(len(P) - 1):
        p0 = P[i - 1] if i > 0 else P[i] * 2 - P[i + 1]
        p1, p2 = P[i], P[i + 1]
        p3 = P[i + 2] if i + 2 < len(P) else P[i + 1] * 2 - P[i]
        for s in range(k):
            t = s / k
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
                              (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-1])
    return out


def sweep(bm, pts, r, segs=12, caps=(True, True), mi=0, rect=None, upref=(0, 0, 1), twist=0.0):
    """Sweep a circle of radius r (or a rectangle rect=(w, h), w across / h along `upref`) along a 3D
    polyline with parallel-transported frames.  `twist` (radians) is spread along the path."""
    P = [V(p) for p in pts]
    n = len(P)
    T = []
    for i in range(n):
        d = (P[min(i + 1, n - 1)] - P[max(i - 1, 0)])
        T.append(d.normalized())
    up = V(upref)
    if abs(T[0].dot(up)) > 0.95:
        up = V((0, 1, 0)) if abs(T[0].y) < 0.95 else V((1, 0, 0))
    N = (up - T[0] * up.dot(T[0])).normalized()
    frames = []
    for i in range(n):
        if i > 0:
            q_ = T[i - 1].rotation_difference(T[i])
            N = (q_ @ N)
            N = (N - T[i] * N.dot(T[i])).normalized()
        B = T[i].cross(N)
        a = twist * i / max(1, n - 1)
        Nn = N * math.cos(a) + B * math.sin(a)
        Bn = T[i].cross(Nn)
        frames.append((Nn, Bn))
    if rect:
        w, h = rect
        prof = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
    else:
        s = q(segs)
        prof = [(r * math.cos(TAU * k / s), r * math.sin(TAU * k / s)) for k in range(s)]
    n0 = len(bm.faces)
    rings = []
    for i in range(n):
        Nn, Bn = frames[i]
        rings.append([bm.verts.new(P[i] + Bn * a + Nn * b) for a, b in prof])
    m = len(prof)
    for i in range(n - 1):
        A, Bq = rings[i], rings[i + 1]
        for k in range(m):
            k1 = (k + 1) % m
            bm.faces.new((A[k], A[k1], Bq[k1], Bq[k]))
    if caps[0]:
        bm.faces.new(list(reversed(rings[0])))
    if caps[1]:
        bm.faces.new(rings[-1])
    _tag(bm, n0, mi)


def prism(bm, outline, y0, y1, M=None, mi=0, mi_side=None):
    """Extrude a 2D (x, z) outline (any simple polygon, concave allowed) between y = y0 and y = y1.
    No bevel: the cheapest way to get a flat plate (levers, tabs, sight blades)."""
    M = M or Matrix()
    pts = ccw(resample2(outline, True))
    n0 = len(bm.faces)
    A = [bm.verts.new(M @ V((x, y0, z))) for x, z in pts]
    B = [bm.verts.new(M @ V((x, y1, z))) for x, z in pts]
    m = len(pts)
    # ccw in (x, z) seen from -y... the face at y1 must face +y
    f1 = bm.faces.new(list(reversed(B)))
    f0 = bm.faces.new(A)
    for i in range(m):
        i1 = (i + 1) % m
        bm.faces.new((A[i], B[i], B[i1], A[i1]))
    _tag(bm, n0, mi)
    bm.normal_update()
    # make normals point outward whatever the handedness of M
    ctr = M @ V((sum(p[0] for p in pts) / m, (y0 + y1) / 2, sum(p[1] for p in pts) / m))
    bm.faces.ensure_lookup_table()
    new = bm.faces[n0:]
    if f1.normal.dot(f1.calc_center_median() - ctr) < 0:
        bmesh.ops.reverse_faces(bm, faces=new)
    if mi_side is not None:
        for f in new:
            if f is not f0 and f is not f1:
                f.material_index = mi_side
    # triangulate the concave caps cleanly
    caps = [f for f in (f0, f1) if f.is_valid and len(f.verts) > 4]
    if caps:
        bmesh.ops.triangulate(bm, faces=caps, quad_method='BEAUTY', ngon_method='BEAUTY')


_TMP_COL = None


def _tmp_collection():
    global _TMP_COL
    if _TMP_COL is None or _TMP_COL.name not in bpy.data.collections:
        _TMP_COL = bpy.data.collections.new('GunkitTmp')
        bpy.context.scene.collection.children.link(_TMP_COL)
    return _TMP_COL


def _curve_to_bm(cu):
    ob = bpy.data.objects.new('tmp_curve', cu)
    _tmp_collection().objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    t = bmesh.new()
    t.from_mesh(me)
    bmesh.ops.remove_doubles(t, verts=list(t.verts), dist=1e-6)
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    bpy.data.meshes.remove(me)
    return t


def profile(bm, outline, width, holes=(), bevel=0.0, bevel_segs=1, y=0.0, M=None, mi=0, mi_side=None,
            mi_bevel=None):
    """THE side-profile builder: a 2D (x, z) outline (with optional inner `holes`) extruded symmetric about
    y (total thickness `width`) with its outline edges bevelled by `bevel` (segs 0 = one 45 deg chamfer,
    1 = two facets, 2+ = rounder).  The outer width stays `width` (the bevel eats inward).  Built with a 2D
    Blender curve (fill both, extrude, bevel, offset), so concave outlines and holes just work.
    Faces get `mi` on the flat sides, `mi_side` on the outline band, `mi_bevel` on the bevels."""
    cu = bpy.data.curves.new('prof', 'CURVE')
    cu.dimensions = '2D'
    cu.fill_mode = 'BOTH'
    cu.resolution_u = 1
    b = min(bevel, width / 2 - 1e-5)
    cu.extrude = max(0.0, width / 2 - b)
    cu.bevel_depth = b
    cu.bevel_resolution = bevel_segs
    try:
        cu.bevel_mode = 'ROUND'
    except Exception:
        pass
    cu.offset = -b if b > 0 else 0.0
    loops = [outline] + list(holes)
    for loop in loops:
        pts = resample2(loop, True)
        sp = cu.splines.new('POLY')
        sp.points.add(len(pts) - 1)
        for i, (x, z) in enumerate(pts):
            sp.points[i].co = (x, z, 0.0, 1.0)
        sp.use_cyclic_u = True
    t = _curve_to_bm(cu)
    # curve local (x, y, z) -> model (x, -z?, y): local X -> X, local Y -> Z, local Z -> -Y
    R = Matrix(((1, 0, 0, 0), (0, 0, -1, y), (0, 1, 0, 0), (0, 0, 0, 1)))
    MM_ = (M or Matrix()) @ R
    for v in t.verts:
        v.co = MM_ @ v.co
    t.normal_update()
    # the reflection-free R keeps normals right; classify faces
    half = width / 2
    for f in t.faces:
        nl = (R.to_3x3().inverted() @ f.normal) if M is None else None
        ny = abs(f.normal.y) if M is None else abs(((M.to_3x3().inverted()) @ f.normal).y)
        if ny > 0.999:
            f.material_index = mi
        elif ny < 0.02:
            f.material_index = mi if mi_side is None else mi_side
        else:
            f.material_index = mi if mi_bevel is None else mi_bevel
    merge(bm, t)
    t.free()
    return bm


def section_x(bm, section, x0, x1, end_bevel=0.0, mi=0, mi_end=None, taper=None):
    """Extrude a closed 2D cross-section [(y, z), ...] along X from x0 to x1 (slides, receivers, rails).
    `end_bevel` chamfers both ends by shrinking the end caps (a 45 deg chamfer of that size);
    `taper(x)` optionally returns a (sy, sz, dz) scale/offset of the section at x."""
    sec = ccw(resample2(section, True))
    xs = [x0]
    if end_bevel > 0:
        xs = [x0, x0 + end_bevel, x1 - end_bevel, x1]
    else:
        xs = [x0, x1]
    n0 = len(bm.faces)
    rings = []
    cy = sum(p[0] for p in sec) / len(sec)
    cz = sum(p[1] for p in sec) / len(sec)
    for i, x in enumerate(xs):
        shrink = end_bevel if (end_bevel > 0 and i in (0, len(xs) - 1)) else 0.0
        sy, sz, dz = taper(x) if taper else (1.0, 1.0, 0.0)
        ring = []
        pts = offset2(sec, -shrink) if shrink else sec
        for y, z in pts:
            ring.append(bm.verts.new(V((x, cy + (y - cy) * sy, cz + (z - cz) * sz + dz))))
        rings.append(ring)
    m = len(sec)
    for A, B in zip(rings[:-1], rings[1:]):
        for k in range(m):
            k1 = (k + 1) % m
            bm.faces.new((A[k], A[k1], B[k1], B[k]))
    fa = bm.faces.new(list(reversed(rings[0])))
    fb = bm.faces.new(rings[-1])
    _tag(bm, n0, mi)
    if mi_end is not None:
        fa.material_index = mi_end
        fb.material_index = mi_end
    bm.normal_update()
    if fb.normal.x < 0:
        bm.faces.ensure_lookup_table()
        bmesh.ops.reverse_faces(bm, faces=bm.faces[n0:])
    bmesh.ops.triangulate(bm, faces=[f for f in (fa, fb) if len(f.verts) > 4], quad_method='BEAUTY',
                          ngon_method='BEAUTY')


def mirror_y(bm_src):
    """A copy of a bmesh mirrored across y = 0 (normals fixed)."""
    t = bm_src.copy()
    for v in t.verts:
        v.co.y = -v.co.y
    bmesh.ops.reverse_faces(t, faces=list(t.faces))
    return t


def rrect2(cx, cy, hx, hy, r_pos=None, r_neg=None, n=3):
    """A rounded rectangle (2D, counter-clockwise) centred (cx, cy), half extents hx, hy; corners on the
    +x side get radius r_pos, on the -x side r_neg (front / back of a grip section).  Always 4*(n+1) points
    (so rings of a loft match)."""
    rp = min(r_pos if r_pos is not None else 0.2 * min(hx, hy), hx * 0.98, hy * 0.98)
    rn = min(r_neg if r_neg is not None else 0.2 * min(hx, hy), hx * 0.98, hy * 0.98)
    pts = []
    for (x, y, r, a0) in ((cx + hx - rp, cy + hy - rp, rp, 0), (cx - hx + rn, cy + hy - rn, rn, 90),
                          (cx - hx + rn, cy - hy + rn, rn, 180), (cx + hx - rp, cy - hy + rp, rp, 270)):
        pts += arc2((x, y), max(r, 1e-6), a0, a0 + 90, n)
    return pts


def loft(bm, rings, cap0=True, cap1=True, mi=0, inner=None, inner_from=0, close_inner_top=True):
    """Skin a list of 3D rings (each a list of points, all the same count, same winding) into a surface:
    caps at the first / last ring.  With `inner` (rings of the same count) the solid becomes hollow from
    ring index `inner_from` of the outer list to the end: the last rings are bridged (an annular bottom),
    the inner surface faces inward and its first ring is capped (the well's ceiling).  Normals are made
    consistent and outward.  Returns the new faces."""
    n0 = len(bm.faces)
    O = [[bm.verts.new(V(p)) for p in r] for r in rings]
    m = len(rings[0])
    for A, B in zip(O[:-1], O[1:]):
        for k in range(m):
            k1 = (k + 1) % m
            bm.faces.new((A[k], A[k1], B[k1], B[k]))
    if cap0:
        bm.faces.new(O[0])
    if inner:
        I = [[bm.verts.new(V(p)) for p in r] for r in inner]
        for A, B in zip(I[:-1], I[1:]):
            for k in range(m):
                k1 = (k + 1) % m
                bm.faces.new((A[k], A[k1], B[k1], B[k]))
        for k in range(m):
            k1 = (k + 1) % m
            bm.faces.new((O[-1][k], O[-1][k1], I[-1][k1], I[-1][k]))
        if close_inner_top:
            bm.faces.new(I[0])
    elif cap1:
        bm.faces.new(O[-1])
    bm.faces.ensure_lookup_table()
    new = bm.faces[n0:]
    bmesh.ops.recalc_face_normals(bm, faces=new)
    for f in new:
        f.material_index = mi
    ngons = [f for f in new if len(f.verts) > 4]
    if ngons:
        bmesh.ops.triangulate(bm, faces=ngons, quad_method='BEAUTY', ngon_method='BEAUTY')
    bm.faces.ensure_lookup_table()
    return bm.faces[n0:]


# ======================================================================================
# 3. booleans and cutters
# ======================================================================================

def _bm_object(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me)
    _tmp_collection().objects.link(ob)
    return ob


def boolean_bm(bm, cutter, op='DIFFERENCE', mi=None, solver='EXACT'):
    """Boolean `cutter` (a bmesh, or a list of bmeshes) into `bm` (op DIFFERENCE / UNION / INTERSECT),
    exact solver, in place.  Faces created by the cutter keep the cutter's material indices, or take `mi`.
    Returns bm.  Cutters must be closed volumes."""
    cutters = cutter if isinstance(cutter, (list, tuple)) else [cutter]
    c = bmesh.new()
    for k in cutters:
        merge(c, k, mi=mi)
    if mi is not None:
        for f in c.faces:
            f.material_index = mi
    target = _bm_object(bm, 'bool_target')
    cut = _bm_object(c, 'bool_cutter')
    c.free()
    nmat = 1 + max([f.material_index for f in bm.faces] + [f.material_index for f in cut.data.polygons] + [0])
    dummies = [bpy.data.materials.get('_gk_slot%d' % i) or bpy.data.materials.new('_gk_slot%d' % i)
               for i in range(nmat)]
    for ob in (target, cut):
        for m in dummies:
            ob.data.materials.append(m)
    mod = target.modifiers.new('bool', 'BOOLEAN')
    mod.operation = op
    mod.solver = solver
    mod.object = cut
    try:
        mod.material_mode = 'INDEX'
        mod.use_self = True            # overlapping shells inside an operand are allowed
        mod.use_hole_tolerant = True
    except Exception:
        pass
    cut.hide_render = True
    dg = bpy.context.evaluated_depsgraph_get()
    ev = target.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    bm.clear()
    bm.from_mesh(me)
    for ob in (target, cut):
        md = ob.data
        bpy.data.objects.remove(ob)
        bpy.data.meshes.remove(md)
    bpy.data.meshes.remove(me)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-7)
    return bm


def serration_cutter(x0, x1, n, width, depth, y_face, z0, z1, both=True, lean=0.0, mi=0):
    """Cutter boxes for n vertical grooves between x0 and x1 on the side faces at |y| = y_face, `depth`
    deep, from z0 to z1.  `lean` (deg) tilts the grooves (forward-leaning serrations).  Returns a bmesh."""
    c = bmesh.new()
    pitch = (x1 - x0) / n
    R = Matrix.Rotation(math.radians(-lean), 3, 'Y')
    for i in range(n):
        x = x0 + pitch * (i + 0.5)
        for s in ((1, -1) if both else (1,)):
            yc = s * (y_face - depth / 2 + 0.002)
            box(c, (x, yc, (z0 + z1) / 2), (width, depth + 0.004, z1 - z0), R=R, mi=mi)
    return c


def hole_cutter(points, axis, r, depth, segs=10, mi=0):
    """Cylinders of radius r around each point along `axis`, `depth` long each way (pins, witness holes,
    vents).  Returns a bmesh."""
    c = bmesh.new()
    a = V(axis).normalized()
    for p in points:
        p = V(p)
        cyl(c, p - a * depth, p + a * depth, r, segs, mi=mi)
    return c


def slot_cutter(p0, p1, r, depth, axis, segs=8, mi=0):
    """A stadium-shaped slot from p0 to p1 (vents, M-LOK slots), cut along `axis` by +-depth."""
    c = bmesh.new()
    p0, p1, a = V(p0), V(p1), V(axis).normalized()
    d = (p1 - p0)
    L = d.length
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
    # ensure outward normals
    ctr = (p0 + p1) / 2
    f = c.faces[0] if hasattr(c.faces, '__getitem__') else None
    c.faces.ensure_lookup_table()
    tot = sum(((ff.calc_center_median() - ctr).dot(ff.normal)) for ff in c.faces)
    if tot < 0:
        bmesh.ops.reverse_faces(c, faces=list(c.faces))
    for ff in c.faces:
        ff.material_index = mi
    return c


def prism_cutter(outline, y0, y1, M=None, mi=0):
    """A closed prism (2D (x, z) outline between y0 and y1) to use as a boolean cutter."""
    c = bmesh.new()
    prism(c, outline, y0, y1, M, mi)
    return c


# ======================================================================================
# 4. hardware and accessories
# ======================================================================================

def pin(bm, p, axis, r, proud=0.0003, segs=10, mi=0, both=None):
    """A pin end showing flush (proud by `proud`) on a face whose outward normal is `axis`; with
    both=width the pin shows on both faces (a through pin across `width`)."""
    a = V(axis).normalized()
    p = V(p)
    cyl(bm, p - a * 0.0008, p + a * proud, r, segs, mi)
    if both:
        q_ = p - a * both
        cyl(bm, q_ + a * 0.0008, q_ - a * proud, r, segs, mi)


def screw(bm, p, axis, r, h=0.0012, kind='slot', mi=0, mi_recess=None, segs=12):
    """A screw head (dome) at p on a face with outward normal `axis`; kind 'slot', 'cross', 'hex' or
    'torx' puts a dark recess (material mi_recess) in it."""
    a = V(axis).normalized()
    M = frame_x(V(p), a)
    lathe(bm, [(-0.0008, 0), (-0.0008, r), (h * 0.35, r), (h * 0.8, r * 0.75), (h, r * 0.35), (h, 0)], segs, M, mi=mi)
    rm = mi if mi_recess is None else mi_recess
    if kind == 'slot':
        box(bm, M @ V((h * 0.9, 0, 0)), (h * 0.5, r * 1.6, r * 0.3), R=M.to_3x3(), mi=rm)
    elif kind == 'cross':
        box(bm, M @ V((h * 0.9, 0, 0)), (h * 0.5, r * 1.2, r * 0.25), R=M.to_3x3(), mi=rm)
        box(bm, M @ V((h * 0.9, 0, 0)), (h * 0.5, r * 0.25, r * 1.2), R=M.to_3x3(), mi=rm)
    elif kind in ('hex', 'torx'):
        lathe(bm, [(h * 0.55, 0), (h * 0.55, r * 0.45), (h * 1.02, r * 0.45), (h * 1.02, 0)], 6, M, mi=rm)


def picatinny(bm, x0, x1, z, width=0.0212, height=0.0094, pitch=0.01001, slot=0.00523, mi=0, y=0.0,
              flip=False, end_bevel=0.0008):
    """A MIL-STD-1913 style rail along X from x0 to x1 standing on z (top up; flip=True hangs it under).
    Teeth sections carry the full dovetail profile, slots the cut-down profile.  Returns the slot count."""
    w = width / 2
    full = [(-w * 0.62, 0.0), (w * 0.62, 0.0), (w * 0.62, height * 0.30), (w, height * 0.52), (w * 0.86, height * 0.68),
            (w * 0.86, height * 0.80), (w * 0.80, height), (-w * 0.80, height), (-w * 0.86, height * 0.80),
            (-w * 0.86, height * 0.68), (-w, height * 0.52), (-w * 0.62, height * 0.30)]
    low = [(-w * 0.62, 0.0), (w * 0.62, 0.0), (w * 0.62, height * 0.30), (w, height * 0.52), (w * 0.86, height * 0.66),
           (-w * 0.86, height * 0.66), (-w, height * 0.52), (-w * 0.62, height * 0.30)]
    s = -1 if flip else 1

    def place(sec):
        return [(y + yy, z + s * zz) for yy, zz in sec]
    # base strip under everything (continuous)
    section_x(bm, place(low), x0, x1, end_bevel=end_bevel, mi=mi)
    n = int((x1 - x0 - 0.004) / pitch)
    start = x0 + ((x1 - x0) - n * pitch) / 2
    for i in range(n):
        a = start + i * pitch + slot / 2
        b = start + (i + 1) * pitch - slot / 2
        section_x(bm, place(full), a, b, end_bevel=0.0004, mi=mi)
    return n


def sling_swivel(bm, p, axis_loop=(0, 0, -1), size=0.016, mi=0):
    """A QD-style sling swivel loop hanging from p (loop plane contains axis_loop and X)."""
    a = V(axis_loop).normalized()
    c = V(p) + a * (size * 0.55)
    torus(bm, c, V((0, 1, 0)) if abs(a.y) < 0.9 else V((1, 0, 0)), size * 0.45, size * 0.07, 16, 6, mi)
    cyl(bm, V(p) - a * 0.002, V(p) + a * (size * 0.15), size * 0.18, 10, mi)


def red_dot(bm, base, mats, length=0.042, height=0.034, width=0.028, tube=False):
    """A generic closed-emitter red dot on a picatinny mount.  `base` = centre of the mount's bottom
    face (sitting on the rail top), +X forward.  mats = {'body', 'lens', 'glow', 'screw'} material indices.
    Returns the sight-line point (centre of the window) for the SightEye marker."""
    b = V(base)
    mb, ml, mg = mats['body'], mats['lens'], mats['glow']
    ms = mats.get('screw', mb)
    # mount / clamp
    rbox(bm, b + V((0, 0, 0.004)), (length * 0.9, width * 0.95, 0.008), 0.0012, 1, mi=mb)
    rbox(bm, b + V((0, -width * 0.42, 0.003)), (length * 0.5, 0.006, 0.010), 0.001, 1, mi=mb)
    screw(bm, b + V((0, -width * 0.47, 0.004)), (0, -1, 0), 0.0035, 0.0025, 'hex', ms, ms)
    # hood: an octagon-ish tube along X
    hz = b.z + 0.008 + height * 0.42
    R_ = height * 0.42
    oct_ = [(math.cos(math.radians(22.5 + 45 * k)) * R_ * 1.05, math.sin(math.radians(22.5 + 45 * k)) * R_)
            for k in range(8)]
    sec = [(y, hz + z) for y, z in oct_]
    win_r = R_ * 0.78
    section_x(bm, sec, b.x - length * 0.45, b.x + length * 0.45, end_bevel=0.0015, mi=mb)
    # windows (lens discs just inside both ends)
    for xx, sgn in ((b.x - length * 0.45, -1), (b.x + length * 0.45, 1)):
        cyl(bm, V((xx - sgn * 0.0015, 0, hz)), V((xx + sgn * 0.0002, 0, hz)), win_r, 16, ml)
    # emitter + turret on top and side
    cyl(bm, V((b.x + 0.004, 0, hz + R_ * 0.95)), V((b.x + 0.004, 0, hz + R_ * 1.25)), 0.0055, 12, mb)
    cyl(bm, V((b.x + 0.004, -R_ * 1.0, hz)), V((b.x + 0.004, -R_ * 1.3, hz)), 0.0055, 12, mb)
    cyl(bm, V((b.x - length * 0.3, 0, hz - R_ * 0.55)), V((b.x - length * 0.3, 0, hz - R_ * 0.2)), 0.0012, 6, mg)
    return V((b.x, 0, hz))


def scope(bm, x_rear, x_front, z_axis, mats, tube_d=0.030, obj_d=0.056, oc_d=0.044, rings_x=None, ring_base_z=None):
    """A generic variable-power riflescope along X at height z_axis: ocular bell, power ring, tube with
    turrets, objective bell with sunshade; lenses at both ends.  mats = {'body', 'lens', 'ring'} indices.
    rings_x: x positions of the two scope rings (each clamping down to ring_base_z).
    Returns (eye point, ocular lens x) for the SightEye marker (eye relief is added by the caller)."""
    mb, ml = mats['body'], mats['lens']
    mr = mats.get('ring', mb)
    L = x_front - x_rear
    rt, ro, rc = tube_d / 2, obj_d / 2, oc_d / 2
    prof = [(0, 0), (0, rc * 0.82), (0.002, rc), (0.050, rc), (0.060, rc * 0.92), (0.085, rt * 1.15),
            (0.088, rt * 1.22), (0.112, rt * 1.22), (0.115, rt), (L - 0.150, rt), (L - 0.095, ro * 0.98),
            (L - 0.090, ro), (L, ro), (L, ro * 0.86), (L - 0.004, ro * 0.84), (L - 0.004, 0)]
    M = frame_x(V((x_rear, 0, z_axis)), (1, 0, 0))
    lathe(bm, prof, 32, M, mi=mb)
    cyl(bm, V((x_rear + 0.0015, 0, z_axis)), V((x_rear - 0.0002, 0, z_axis)), rc * 0.8, 24, ml)
    cyl(bm, V((x_front - 0.006, 0, z_axis)), V((x_front - 0.0035, 0, z_axis)), ro * 0.83, 24, ml)
    xm = x_rear + L * 0.52
    rbox(bm, V((xm, 0, z_axis)), (0.040, rt * 2.3, rt * 2.3), 0.003, 2, mi=mb)          # turret housing
    cyl(bm, V((xm, 0, z_axis + rt)), V((xm, 0, z_axis + rt + 0.016)), 0.0105, 20, mb)  # elevation
    cyl(bm, V((xm, -rt, z_axis)), V((xm, -rt - 0.016, z_axis)), 0.0105, 20, mb)       # windage
    cyl(bm, V((xm, rt, z_axis)), V((xm, rt + 0.010, z_axis)), 0.0085, 16, mb)          # parallax / illum
    for xx in (rings_x or ()):
        lathe(bm, [(-0.008, rt + 0.0045), (0.008, rt + 0.0045), (0.008, rt - 0.0002), (-0.008, rt - 0.0002)], 28,
              frame_x(V((xx, 0, z_axis)), (1, 0, 0)), closed=True, mi=mr)
        if ring_base_z is not None:
            rbox(bm, V((xx, 0, (ring_base_z + z_axis - rt) / 2)), (0.016, 0.020, z_axis - rt - ring_base_z + 0.003),
                 0.0015, 1, mi=mr)
            screw(bm, V((xx, -0.011, ring_base_z + 0.006)), (0, -1, 0), 0.003, 0.002, 'hex', mr, mr)
    return V((x_rear, 0, z_axis))


def prism_sight(bm, base, mats, length=0.070, height=0.045, width=0.034):
    """A generic compact 4x prism sight (ACOG-like silhouette, no trademark): forged body, ocular, objective,
    fibre strip, mount with two cross-bolts.  base = centre of the bottom of the mount on the rail.
    Returns the ocular lens centre (eye relief ~0.04 m behind it is the SightEye)."""
    b = V(base)
    mb, ml = mats['body'], mats['lens']
    mg = mats.get('glow', ml)
    rbox(bm, b + V((0, 0, 0.005)), (length * 0.7, width * 0.95, 0.010), 0.0015, 1, mi=mb)
    for xx in (-length * 0.2, length * 0.2):
        cyl(bm, b + V((xx, width * 0.5, 0.004)), b + V((xx, -width * 0.6, 0.004)), 0.003, 8, mb)
    zc = b.z + 0.010 + height * 0.45
    rbox(bm, V((b.x - length * 0.05, 0, zc)), (length * 0.62, width, height * 0.75), 0.004, 2, mi=mb)
    lathe(bm, [(0, 0), (0, 0.0145), (0.020, 0.0145), (0.024, 0.016), (0.024, 0)], 24,
          frame_x(V((b.x + length * 0.22, 0, zc)), (1, 0, 0)), mi=mb)
    lathe(bm, [(0, 0), (0, 0.0115), (0.016, 0.0125), (0.016, 0)], 24,
          frame_x(V((b.x - length * 0.36 - 0.012, 0, zc)), (1, 0, 0)), mi=mb)
    cyl(bm, V((b.x + length * 0.22 + 0.0235, 0, zc)), V((b.x + length * 0.22 + 0.0242, 0, zc)), 0.0135, 20, ml)
    cyl(bm, V((b.x - length * 0.36 - 0.0122, 0, zc)), V((b.x - length * 0.36 - 0.0128, 0, zc)), 0.0105, 20, ml)
    box(bm, V((b.x - length * 0.05, 0, zc + height * 0.38)), (length * 0.45, 0.004, 0.002), mi=mg)
    return V((b.x - length * 0.36 - 0.0128, 0, zc))


def bipod(pivot, leg_len=0.20, splay=8.0, folded='forward', mats=None, ext=0.08, leg_r=0.0055, foot='rubber'):
    """A generic folding bipod.  Returns {'Yoke': bm, 'BipodLegL': bm, 'BipodExtL': bm, 'BipodLegR': bm,
    'BipodExtR': bm} built in model space at REST (legs folded along +X ('forward') or -X ('back')),
    each leg rotating about +Y through `pivot`; feet get mats['foot'].  mats = {'body','foot'}."""
    mats = mats or {'body': 0, 'foot': 0}
    p = V(pivot)
    out = {'Yoke': bmesh.new()}
    rbox(out['Yoke'], p + V((0, 0, 0.008)), (0.030, 0.034, 0.016), 0.002, 1, mi=mats['body'])
    cyl(out['Yoke'], p + V((0, 0.024, 0)), p + V((0, -0.024, 0)), 0.0045, 12, mats['body'])
    sgn = 1 if folded == 'forward' else -1
    for side, sy in (('L', 1), ('R', -1)):
        leg = bmesh.new()
        e = bmesh.new()
        # at rest the leg lies along X under the pivot, splayed sideways
        d = V((sgn, sy * math.sin(math.radians(splay)), 0)).normalized()
        a = p + V((0, sy * 0.013, -0.006))
        bend = a + d * 0.012
        rbox(leg, a, (0.012, 0.008, 0.010), 0.001, 1, mi=mats['body'])
        cyl(leg, bend, bend + d * (leg_len * 0.62), leg_r * 1.25, 10, mats['body'])
        cyl(e, bend + d * (leg_len * 0.45), bend + d * leg_len, leg_r, 10, mats['body'])
        tip = bend + d * leg_len
        lathe(e, [(0, 0), (0, leg_r * 1.5), (0.010, leg_r * 1.8), (0.018, leg_r * 1.2), (0.020, 0)], 10,
              frame_x(tip, d), mi=mats['foot'])
        for k in range(4):
            torus(e, bend + d * (leg_len * (0.50 + 0.04 * k)), d, leg_r * 1.02, 0.0006, 10, 3, mats['body'])
        out['BipodLeg' + side] = leg
        out['BipodExt' + side] = e
    return out


def sling(bm, pts, width=0.025, thickness=0.0022, mi=0, k=5, twist=0.0, upref=(0, 1, 0)):
    """A flat strap (webbing) through 3D control points (smoothed by Catmull-Rom)."""
    sweep(bm, crs(pts, k), 0, rect=(width, thickness), mi=mi, upref=upref, twist=twist)


# ======================================================================================
# 5. ammunition and magazines
# ======================================================================================

# dimensions in metres: case length, rim/base/shoulder/neck/mouth radii, overall length of the round, bullet
CARTRIDGES = {
    '9x19': dict(case=0.01915, rim=0.00498, base=0.00496, mouth=0.00483, oal=0.0297, bullet=0.00451,
                 kind='straight', groove=(0.0011, 0.0019, 0.0042)),
    '7.62x39': dict(case=0.0387, rim=0.00562, base=0.00561, shoulder=0.00498, shoulder_x=0.0305, neck=0.00432,
                    mouth=0.00432, oal=0.0560, bullet=0.00395, kind='bottleneck', groove=(0.0015, 0.0026, 0.0047)),
    '5.56x45': dict(case=0.0447, rim=0.00480, base=0.00480, shoulder=0.00449, shoulder_x=0.0366, neck=0.00317,
                    mouth=0.00317, oal=0.0574, bullet=0.00285, kind='bottleneck', groove=(0.0011, 0.0022, 0.0040)),
    '.338LM': dict(case=0.0692, rim=0.00744, base=0.00744, shoulder=0.00680, shoulder_x=0.0587, neck=0.00460,
                   mouth=0.00460, oal=0.0935, bullet=0.00429, kind='bottleneck', groove=(0.0015, 0.0030, 0.0063)),
    '12ga': dict(case=0.070, rim=0.0113, base=0.0101, mouth=0.0101, oal=0.065, kind='shell', brass_h=0.016),
}


def case_profile(cal, spent=True):
    """Lathe profile [(x, r)] of a cartridge case along +X (head at x = 0, mouth at +case).  Spent cases
    are open at the mouth (a short hollow), loaded ones end at the mouth for the bullet to sit on.
    Few points on purpose (a casing must stay <= 150 triangles at 10 segments)."""
    c = CARTRIDGES[cal]
    g0, g1, gr = c['groove']
    p = [(0, 0), (0, c['rim']), (g0, c['rim']), (g0 + 0.0003, gr), (g1, gr), (g1 + 0.0004, c['base'])]
    if c['kind'] == 'straight':
        p += [(c['case'], c['mouth'])]
    else:
        p += [(c['shoulder_x'], c['shoulder']), (c['shoulder_x'] + (c['shoulder'] - c['neck']) * 1.2, c['neck']),
              (c['case'], c['mouth'])]
    if spent:
        p += [(c['case'], c['mouth'] - 0.0003), (c['case'] - 0.006, 0)]
    else:
        p += [(c['case'], 0)]
    return p


def bullet_profile(cal):
    """Lathe profile [(x, r)] of the bullet that sticks out of the case mouth (tangent-ogive FMJ)."""
    c = CARTRIDGES[cal]
    x0, x1, r = c['case'], c['oal'], c['bullet']
    L = x1 - x0
    if cal == '9x19':
        return [(x0 - 0.001, r), (x0 + L * 0.18, r), (x0 + L * 0.45, r * 0.88), (x0 + L * 0.70, r * 0.66),
                (x0 + L * 0.90, r * 0.36), (x1, 0)]
    return [(x0 - 0.001, r), (x0 + L * 0.30, r), (x0 + L * 0.55, r * 0.86), (x0 + L * 0.78, r * 0.55),
            (x0 + L * 0.95, r * 0.18), (x1, 0)]


def build_case(bm, cal, mats, M=None, segs=10, spent=True):
    """A cartridge case (+X toward the mouth, head at local x = 0) with a primer disc; mats = {'case',
    'primer'} material indices.  Spent cases have a struck primer (a dent is in the material) and an open
    mouth.  Steel-cased calibres use whatever 'case' material the caller passes (lacquer)."""
    M = M or Matrix()
    lathe(bm, case_profile(cal, spent), segs, M, mi=mats['case'])
    c = CARTRIDGES[cal]
    pr = c['rim'] * 0.44
    lathe(bm, [(-0.00005, 0), (-0.00005, pr)], segs, M, mi=mats['primer'])     # a flat disc: segs tris


def build_round(bm, cal, mats, M=None, segs=8):
    """A loaded round: case (no mouth hollow), bullet (mats['bullet']) and primer."""
    M = M or Matrix()
    build_case(bm, cal, mats, M, segs, spent=False)
    lathe(bm, bullet_profile(cal), segs, M, mi=mats['bullet'])


def build_shell(bm, mats, M=None, segs=12, spent=True, length=0.070):
    """A 12-gauge hull: brass head with rim, plastic tube, folded star crimp (loaded) or opened crimp
    (spent).  mats = {'case' (brass head), 'hull' (plastic), 'primer'}."""
    M = M or Matrix()
    c = CARTRIDGES['12ga']
    h = c['brass_h']
    lathe(bm, [(0, 0), (0, c['rim']), (0.0013, c['rim']), (0.0016, c['base']), (h, c['base']), (h, 0.0)], segs, M,
          mi=mats['case'])
    if spent:
        prof = [(h - 0.001, c['base'] - 0.0003), (length - 0.006, c['base'] - 0.0003),
                (length, c['base'] + 0.0012), (length, c['base'] + 0.0002), (length - 0.012, 0.0)]
    else:
        prof = [(h - 0.001, c['base'] - 0.0003), (length - 0.004, c['base'] - 0.0003),
                (length - 0.001, c['base'] - 0.0016), (length, c['base'] - 0.004), (length - 0.0015, 0.0)]
    lathe(bm, prof, segs, M, mi=mats['hull'])
    lathe(bm, [(-0.00005, 0), (-0.00005, 0.0028)], segs, M, mi=mats['primer'])


def box_mag(bm, top, axis, length, depth, width, mats, curve_deg=0.0, top_width=None, rib=True,
            base_h=0.006, base_over=(0.003, 0.002), segs_curve=6, lips=0.008, front_notch=None, base=True,
            body_len=None):
    """A box magazine body hanging from `top` (the centre of the feed-lip top, the MagWell point) along the
    unit 2D direction `axis` (x, z) in the side view (the extraction direction), `length` from the lip top
    to the baseplate bottom, `depth` (front-back) and `width` (y).  curve_deg bends it forward along its
    length (AK-type).  The top `lips` metres narrow to `top_width` (double -> single feed).  mats =
    {'body','base','lips'}.  Optional side ribs, a baseplate (base_h thick, overhanging base_over (front,
    back)), and a catch notch on the front face (front_notch = (from_top, height)).
    Returns the list of spine frames [(point3d, along2d, front2d)] for the caller (witness holes etc.)."""
    ax = V((axis[0], axis[1])).normalized()
    fr = V((-ax.y, ax.x))          # 'front' normal in the side view, rotated +90 deg
    if fr.x < 0:
        fr = -fr
    tw = top_width or width * 0.88
    body_len = body_len or (length - base_h)
    nseg = max(1, segs_curve if curve_deg else 1)
    spine = []
    for i in range(nseg + 1):
        t = i / nseg
        s = body_len * t
        if curve_deg:
            k = math.radians(curve_deg) / body_len
            ang = k * s
            # bend toward the front as we go down
            if abs(k) > 1e-9:
                r_ = 1 / k
                p2 = V((top[0], top[2])) + ax * (math.sin(ang) * r_) + fr * ((1 - math.cos(ang)) * r_)
            else:
                p2 = V((top[0], top[2])) + ax * s
            a2 = (ax * math.cos(ang) + fr * math.sin(ang)).normalized()
        else:
            p2 = V((top[0], top[2])) + ax * s
            a2 = ax
        f2 = V((-a2.y, a2.x))
        if f2.dot(fr) < 0:
            f2 = -f2
        spine.append((p2, a2, f2, s))
    rings = []
    n0 = len(bm.faces)
    rr = min(depth, width) * 0.18

    def sec(w, d):
        pts = fillet2([(-d / 2, -w / 2), (d / 2, -w / 2), (d / 2, w / 2), (-d / 2, w / 2)], rr, 2)
        return pts
    stations = [(0.0, tw), (lips, width)] + [(sp[3], width) for sp in spine[1:]]
    stations = sorted(set((round(s, 6), w) for s, w in stations))

    def frame_at(s):
        if s <= 0:
            return spine[0][0:3]
        for i in range(len(spine) - 1):
            if spine[i][3] <= s <= spine[i + 1][3] + 1e-9:
                t = (s - spine[i][3]) / max(1e-9, spine[i + 1][3] - spine[i][3])
                p = spine[i][0].lerp(spine[i + 1][0], t)
                a = spine[i][1].lerp(spine[i + 1][1], t).normalized()
                f = spine[i][2].lerp(spine[i + 1][2], t).normalized()
                return p, a, f
        return spine[-1][0:3]
    for s, w in stations:
        p, a, f = frame_at(s)
        ring = []
        for dd, yy in sec(w, depth):
            pp = p + f * dd
            ring.append(bm.verts.new(V((pp.x, yy, pp.y))))
        rings.append(ring)
    m = len(rings[0])
    for A, B in zip(rings[:-1], rings[1:]):
        for k in range(m):
            k1 = (k + 1) % m
            bm.faces.new((A[k], B[k], B[k1], A[k1]))
    top_face = bm.faces.new(rings[0])
    bot_face = bm.faces.new(list(reversed(rings[-1])))
    _tag(bm, n0, mats['body'])
    bm.normal_update()
    p_top = frame_at(0)[0]
    if top_face.normal.dot(V((-ax.x, 0, -ax.y))) < 0:
        bm.faces.ensure_lookup_table()
        bmesh.ops.reverse_faces(bm, faces=bm.faces[n0:])
    # steel feed lips
    p, a, f = frame_at(0)
    for sy in (1, -1):
        c3 = V(((p + a * (lips * 0.45)).x, sy * (tw / 2 - 0.0004), (p + a * (lips * 0.45)).y))
        rbox(bm, c3, (depth * 0.62, 0.0012, lips * 0.9), 0.0003, 1, R=_side_R(a, f), mi=mats.get('lips', mats['body']))
    # baseplate (callers with a shaped plate pass base=False and build their own)
    if base:
        p, a, f = frame_at(body_len)
        bo_f, bo_b = base_over
        cen = p + a * (base_h / 2) + f * ((bo_f - bo_b) / 2)
        rbox(bm, V((cen.x, 0, cen.y)), (depth + bo_f + bo_b, width + 0.002, base_h), 0.0012, 2,
             R=_side_R(a, f), mi=mats.get('base', mats['body']))
    # side ribs
    if rib:
        for sy in (1, -1):
            for s0, s1 in ((lips + 0.006, body_len - 0.010),):
                pa, aa, fa = frame_at(s0)
                pb, ab, fb = frame_at(s1)
                pts3 = []
                for kk in range(nseg + 1):
                    s = s0 + (s1 - s0) * kk / nseg
                    pp, aa_, ff = frame_at(s)
                    q2 = pp + ff * (-depth * 0.18)
                    pts3.append(V((q2.x, sy * (width / 2 + 0.0002), q2.y)))
                sweep(bm, pts3, 0, rect=(0.004, 0.0012), upref=(0, sy, 0), mi=mats['body'])
    return [frame_at(s) for s in (0.0, lips, body_len * 0.5, body_len)] + [frame_at]


def _side_R(a, f):
    """3x3 rotation whose X = the 2D front direction f, Z = -a (up the mag), Y = +Y."""
    X = V((f.x, 0, f.y)).normalized()
    Z = V((-a.x, 0, -a.y)).normalized()
    Y = Z.cross(X)
    return basis(X, Y, Z)


# ======================================================================================
# 6. materials (procedural; paint keys of ARCHITECTURE §5.1)
# ======================================================================================

MAT = {}


class NB:
    """Node-tree builder for one material (as tools/pyro/flamethrower.py), MAT[name] = the material."""

    def __init__(self, name):
        old = bpy.data.materials.get(name)
        if old:
            bpy.data.materials.remove(old)
        self.m = bpy.data.materials.new(name)
        try:
            self.m.use_nodes = True
        except Exception:
            pass
        self.nt = self.m.node_tree
        self.nt.nodes.clear()
        self.out = self.n('ShaderNodeOutputMaterial')
        self.tc = self.n('ShaderNodeTexCoord')
        self.principled = None
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

    def obj(self):
        return self.tc.outputs['Object']

    def scaled(self, s, vec=None):
        """Object coords scaled per axis (stretched noise = scratches / grain / streaks)."""
        vm = self.n('ShaderNodeVectorMath', operation='MULTIPLY')
        self.l(vec if vec is not None else self.obj(), vm.inputs[0])
        vm.inputs[1].default_value = s
        return vm.outputs[0]

    def noise(self, scale, detail=4.0, rough=0.55, vec=None, distort=0.0):
        nz = self.n('ShaderNodeTexNoise', {'Scale': scale, 'Detail': detail, 'Roughness': rough, 'Distortion': distort})
        self.l(vec if vec is not None else self.obj(), nz.inputs['Vector'])
        return nz.outputs['Fac']

    def voronoi(self, scale, vec=None, out='Distance', feature='F1', rand=1.0):
        vo = self.n('ShaderNodeTexVoronoi', {'Scale': scale, 'Randomness': rand}, feature=feature)
        self.l(vec if vec is not None else self.obj(), vo.inputs['Vector'])
        return vo.outputs[out]

    def wave(self, scale, vec=None, kind='BANDS', direction='X', distortion=0.0, detail=0.0, profile='SIN'):
        w = self.n('ShaderNodeTexWave', {'Scale': scale, 'Distortion': distortion, 'Detail': detail}, wave_type=kind,
                   bands_direction=direction, wave_profile=profile)
        self.l(vec if vec is not None else self.obj(), w.inputs['Vector'])
        return w.outputs['Fac']

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
        """Smooth 0..1 step of fac between a and b."""
        mr = self.n('ShaderNodeMapRange', {'From Min': a, 'From Max': b}, clamp=True, interpolation_type='SMOOTHSTEP')
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

    def add(self, *vals):
        acc = vals[0]
        for v in vals[1:]:
            acc = self.math('ADD', acc, v, clamp=False)
        return acc

    def mx(self, a, b):
        return self.math('MAXIMUM', a, b)

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

    def edge(self, radius=0.0007, a=0.02, b=0.20):
        """Convex/concave edge mask from the bevel-normal trick (a curvature-like wear mask)."""
        bev = self.n('ShaderNodeBevel', {'Radius': radius}, samples=8)
        geo = self.n('ShaderNodeNewGeometry')
        dot = self.n('ShaderNodeVectorMath', operation='DOT_PRODUCT')
        self.l(bev.outputs['Normal'], dot.inputs[0])
        self.l(geo.outputs['Normal'], dot.inputs[1])
        return self.mask(self.math('SUBTRACT', 1.0, dot.outputs['Value']), a, b)

    def cavity(self, dist=0.004, a=0.15, b=0.75):
        """Occlusion mask (grime in recesses)."""
        ao = self.n('ShaderNodeAmbientOcclusion', {'Distance': dist}, only_local=True, samples=8)
        return self.mask(self.math('SUBTRACT', 1.0, ao.outputs['AO']), a, b)

    def facing_up(self, a=0.3, b=0.9):
        geo = self.n('ShaderNodeNewGeometry')
        return self.mask(self.axis(2, geo.outputs['Normal']), a, b)

    def bump(self, height, strength=0.2, distance=0.0005, normal=None):
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
            if isinstance(v, bpy.types.NodeSocket):
                self.l(v, p.inputs[k])
            else:
                p.inputs[k].default_value = v
        self.l(p.outputs[0], self.out.inputs['Surface'])
        self.principled = p
        return p


def C(r, g, b):
    """An RGBA colour tuple (linear)."""
    return (r, g, b, 1.0)


def mat_polymer(name='Polymer', col=(0.014, 0.014, 0.015), stipple=False, wear=1.0):
    """Glass-filled polymer (frames, stocks, mags): matte near-black, micro texture, edge polish (handled
    edges go glossy and a bit lighter), dust in recesses, light scuffs.  stipple=True adds a dense raised
    stipple (grip panels)."""
    m = NB(name)
    e = m.edge(0.0007, 0.03, 0.22)
    cav = m.cavity(0.004)
    var = m.noise(60, 4, 0.5)
    base = m.mixc(var, C(*col), C(col[0] * 1.35, col[1] * 1.35, col[2] * 1.4))
    dust = m.mx(m.mul(cav, 0.9), m.mask(m.noise(25, 6, 0.6), 0.62, 0.85))
    base = m.mixc(m.mul(dust, 0.55), base, C(0.085, 0.080, 0.072))
    polish = m.mul(e, wear)
    base = m.mixc(m.mul(polish, 0.55), base, C(0.065, 0.064, 0.066))
    scuff = m.mul(m.mask(m.noise(3, 3, 0.5, vec=m.scaled((60, 900, 900))), 0.66, 0.70), m.mask(m.noise(9, 3, 0.5), 0.45, 0.6))
    base = m.mixc(m.mul(scuff, 0.6 * wear), base, C(0.09, 0.09, 0.092))
    if stipple:
        st = m.voronoi(1400, out='Distance')
        st2 = m.voronoi(2600, out='Distance')
        h = m.add(m.mul(m.mask(st, 0.05, 0.42), -1.0), m.mul(m.mask(st2, 0.1, 0.5), -0.5), m.mul(m.noise(4000, 2, 0.5), 0.2))
        rough = m.mixf(polish, m.mixf(dust, 0.72, 0.86), 0.55)
        nrm = m.bump(h, 0.55, 0.0004)
        pits = m.mask(st, 0.0, 0.08)
        base = m.mixc(m.mul(pits, 0.35), base, C(0.010, 0.010, 0.010))
    else:
        rough = m.mixf(polish, m.mixf(dust, 0.55, 0.82), 0.30)
        rough = m.mixf(m.mul(scuff, 0.5), rough, 0.4)
        nrm = m.bump(m.add(m.noise(3000, 2, 0.5), m.mul(scuff, -0.3)), 0.12, 0.0003)
    m.bsdf(base, 0.0, rough, nrm, extra={'Specular IOR Level': 0.45})
    return m.m


def mat_steel(name='SteelBlued', col=(0.030, 0.031, 0.034), rough=0.42, metal=0.80, wear=1.0, brushed=True,
              phosphate=False, holster=0.0):
    """Finished steel: bluing / nitride (default) or phosphate (phosphate=True: grey-green, crystalline,
    rough).  Edge wear to bright bare steel, holster wear on flats (`holster` 0..1, polished bands along
    X), fine scratches, oily grime in recesses."""
    m = NB(name)
    e = m.edge(0.0007, 0.03, 0.22)
    cav = m.cavity(0.004)
    wn = m.mask(m.noise(140, 6, 0.6), 0.30, 0.55)
    wearm = m.mul(m.mul(e, wn), wear)
    if holster > 0:
        hb = m.mask(m.noise(4, 4, 0.6, vec=m.scaled((10, 120, 120))), 0.55, 0.75)
        wearm = m.mx(wearm, m.mul(m.mul(hb, m.mask(m.noise(60, 6, 0.6), 0.45, 0.7)), holster))
    var = m.noise(30, 5, 0.6)
    if phosphate:
        cr = m.voronoi(5000, out='Distance')
        base = m.mixc(var, C(*col), C(col[0] * 1.25, col[1] * 1.3, col[2] * 1.2))
        base = m.mixc(m.mul(m.mask(cr, 0.1, 0.5), 0.35), base, C(col[0] * 0.7, col[1] * 0.7, col[2] * 0.7))
        r0 = m.mixf(var, rough, min(1.0, rough + 0.12))
        h = m.add(m.mul(m.mask(cr, 0.0, 0.6), 0.6), m.noise(2500, 2, 0.5))
    else:
        base = m.mixc(var, C(*col), C(col[0] * 1.2, col[1] * 1.2, col[2] * 1.35))
        r0 = m.mixf(var, rough, rough + 0.10)
        h = m.noise(3500, 2, 0.5)
    if brushed:
        br = m.noise(2, 2, 0.5, vec=m.scaled((15, 1800, 1800)))
        r0 = m.mixf(m.mul(br, 0.4), r0, rough - 0.1)
        h = m.add(h, m.mul(br, 0.25))
    grime = m.mx(m.mul(cav, 0.95), m.mask(m.noise(22, 6, 0.6), 0.64, 0.85))
    base = m.mixc(m.mul(grime, 0.6), base, C(0.020, 0.017, 0.013))
    scr = m.mul(m.mask(m.noise(3, 3, 0.5, vec=m.scaled((40, 1500, 1500))), 0.67, 0.70), m.mask(m.noise(8, 3, 0.5), 0.45, 0.6))
    wearm = m.mx(wearm, m.mul(scr, 0.8 * wear))
    base = m.mixc(wearm, base, C(0.42, 0.42, 0.43))
    rr = m.mixf(m.mul(grime, 0.6), r0, 0.7)
    rr = m.mixf(wearm, rr, 0.22)
    mt = m.mixf(wearm, metal, 1.0)
    nrm = m.bump(m.add(h, m.mul(wearm, -0.4), m.mul(scr, -0.4)), 0.10, 0.0003)
    m.bsdf(base, mt, rr, nrm)
    return m.m


def mat_aluminium(name='Aluminium', col=(0.018, 0.018, 0.019), rough=0.38, wear=1.0):
    """Hard-anodised aluminium (black by default): satin, slightly metallic sheen, edges worn to bright
    alloy, machining marks."""
    m = NB(name)
    e = m.edge(0.0008, 0.03, 0.22)
    wearm = m.mul(m.mul(e, m.mask(m.noise(120, 6, 0.6), 0.32, 0.55)), wear)
    base = m.mixc(m.noise(40, 4, 0.5), C(*col), C(col[0] * 1.3, col[1] * 1.3, col[2] * 1.3))
    cav = m.cavity(0.004)
    base = m.mixc(m.mul(cav, 0.5), base, C(0.03, 0.028, 0.025))
    base = m.mixc(wearm, base, C(0.62, 0.62, 0.63))
    mach = m.wave(400, kind='RINGS', distortion=0.5)
    m.bsdf(base, m.mixf(wearm, 0.55, 1.0), m.mixf(wearm, m.mixf(cav, rough, 0.7), 0.25),
           m.bump(m.add(m.mul(mach, 0.15), m.noise(3000, 2, 0.5)), 0.08, 0.0003))
    return m.m


def mat_wood(name='Wood', light=(0.30, 0.13, 0.055), dark=(0.11, 0.040, 0.016), lacquer=0.35, grain_axis='X'):
    """Wood with real grain: long stretched noise for the growth rings along `grain_axis`, pores, a
    lacquer/oil sheen, darker handled zones and lighter dented edges (AK furniture)."""
    m = NB(name)
    s = {'X': (12, 260, 260), 'Y': (260, 12, 260), 'Z': (260, 260, 12)}[grain_axis]
    g = m.noise(1.6, 6, 0.6, vec=m.scaled(s), distort=0.9)
    rings = m.mask(m.wave(1.0, vec=m.scaled(tuple(v * 0.12 for v in s)), kind='BANDS', direction='X',
                          distortion=6.0, detail=3.0), 0.25, 0.85)
    base = m.mixc(m.mask(g, 0.35, 0.65), C(*light), C(*dark))
    base = m.mixc(m.mul(rings, 0.45), base, C(dark[0] * 0.8, dark[1] * 0.8, dark[2] * 0.8))
    pores = m.mask(m.noise(2, 2, 0.5, vec=m.scaled(tuple(v * 25 for v in s))), 0.66, 0.72)
    base = m.mixc(m.mul(pores, 0.6), base, C(0.03, 0.012, 0.005))
    hand = m.mask(m.noise(5, 5, 0.6), 0.45, 0.8)
    base = m.mixc(m.mul(hand, 0.5), base, C(dark[0] * 0.6, dark[1] * 0.6, dark[2] * 0.6))
    e = m.edge(0.0012, 0.03, 0.2)
    dent = m.mul(e, m.mask(m.noise(80, 6, 0.6), 0.45, 0.6))
    base = m.mixc(m.mul(dent, 0.7), base, C(light[0] * 1.4, light[1] * 1.4, light[2] * 1.3))
    rough = m.mixf(hand, lacquer, lacquer * 0.7)
    rough = m.mixf(m.mul(dent, 0.8), rough, 0.7)
    m.bsdf(base, 0.0, rough, m.bump(m.add(m.mul(rings, 0.3), m.mul(pores, -0.6), m.mul(dent, -0.5)), 0.15, 0.0004),
           extra={'Coat Weight': 0.25, 'Coat Roughness': 0.25})
    return m.m


def mat_rubber(name='Rubber', col=(0.016, 0.016, 0.017)):
    """Matte rubber (recoil pads, feet): very rough, dust in the ribs."""
    m = NB(name)
    dust = m.mx(m.mask(m.noise(20, 6, 0.6), 0.6, 0.85), m.mul(m.cavity(0.004), 0.9))
    base = m.mixc(m.mul(dust, 0.6), C(*col), C(0.09, 0.085, 0.075))
    m.bsdf(base, 0.0, m.mixf(dust, 0.78, 0.92), m.bump(m.noise(2500, 2, 0.5), 0.15, 0.0003))
    return m.m


def mat_fabric(name='Fabric', col=(0.30, 0.24, 0.15), weave=1800):
    """Nylon webbing / cordura: a fine basket weave (two crossed waves), fuzz, dirt in folds."""
    m = NB(name)
    w1 = m.wave(weave, kind='BANDS', direction='X')
    w2 = m.wave(weave, kind='BANDS', direction='Y')
    w3 = m.wave(weave, kind='BANDS', direction='Z')
    weave_h = m.add(m.mul(w1, 0.4), m.mul(w2, 0.3), m.mul(w3, 0.3))
    dirt = m.mx(m.mul(m.cavity(0.006), 0.9), m.mask(m.noise(18, 6, 0.6), 0.55, 0.85))
    base = m.mixc(m.noise(50, 4, 0.5), C(*col), C(col[0] * 0.8, col[1] * 0.8, col[2] * 0.8))
    base = m.mixc(m.mul(dirt, 0.7), base, C(col[0] * 0.45, col[1] * 0.42, col[2] * 0.38))
    m.bsdf(base, 0.0, m.mixf(dirt, 0.85, 0.95), m.bump(weave_h, 0.35, 0.0003), extra={'Sheen Weight': 0.3})
    return m.m


def mat_brass(name='Brass', fresh=0.7):
    """Cartridge brass: warm yellow, light tarnish, polished edges; `fresh` 0..1."""
    m = NB(name)
    tarn = m.mx(m.mask(m.noise(30, 7, 0.65), 0.5 - 0.2 * fresh, 0.85), m.mul(m.cavity(0.002), 0.7))
    e = m.edge(0.0004, 0.03, 0.2)
    base = m.mixc(m.mul(tarn, 0.7), C(0.70, 0.48, 0.18), C(0.30, 0.20, 0.08))
    base = m.mixc(e, base, C(0.85, 0.66, 0.32))
    m.bsdf(base, 1.0, m.mixf(e, m.mixf(tarn, 0.22, 0.45), 0.15), m.bump(m.noise(4000, 2, 0.5), 0.05, 0.0002))
    return m.m


def mat_copper(name='Copper'):
    """Copper bullet jacket (FMJ): reddish, slight oxidation, shinier nose."""
    m = NB(name)
    tarn = m.mask(m.noise(40, 6, 0.6), 0.45, 0.8)
    base = m.mixc(m.mul(tarn, 0.6), C(0.72, 0.33, 0.17), C(0.35, 0.16, 0.08))
    m.bsdf(base, 1.0, m.mixf(tarn, 0.22, 0.42))
    return m.m


def mat_simple(name, col, metal=0.0, rough=0.5, extra=None):
    """A flat Principled material (nickel primers, lens, paint, glow, studio greys)."""
    m = NB(name)
    m.bsdf(C(*col), metal, rough, None, extra)
    return m.m


def mat_paint(name='SightPaint', col=(0.80, 0.80, 0.76)):
    """Sight paint / white dots: slightly dirty, satin."""
    m = NB(name)
    d = m.mask(m.noise(80, 5, 0.6), 0.55, 0.8)
    m.bsdf(m.mixc(m.mul(d, 0.4), C(*col), C(0.4, 0.38, 0.33)), 0.0, 0.55)
    return m.m


def mat_lens(name='Lens'):
    """Coated optic glass: dark with a green/amber coating sheen, glossy."""
    m = NB(name)
    lw = m.n('ShaderNodeLayerWeight', {'Blend': 0.35})
    base = m.mixc(lw.outputs['Facing'], C(0.010, 0.020, 0.018), C(0.06, 0.13, 0.08))
    m.bsdf(base, 0.0, 0.05, None, extra={'Specular IOR Level': 0.9, 'Coat Weight': 1.0, 'Coat Roughness': 0.02})
    return m.m


def mat_glow(name='Glow', col=(1.0, 0.05, 0.03), strength=8.0):
    """Emissive (red dot emitter, tritium)."""
    m = NB(name)
    m.bsdf(C(col[0] * 0.3, col[1] * 0.3, col[2] * 0.3), 0.0, 0.4, None,
           extra={'Emission Color': C(*col), 'Emission Strength': strength})
    return m.m


def build_materials():
    """Build the whole library (paint keys of ARCHITECTURE §5.1) plus the studio materials.
    Returns MAT (name -> material)."""
    mat_polymer('Polymer')
    mat_polymer('PolymerStipple', stipple=True)
    mat_steel('SteelBlued', holster=0.35)
    mat_steel('SteelPhosphate', col=(0.050, 0.052, 0.047), rough=0.70, metal=0.45, phosphate=True)
    mat_steel('SteelLacquer', col=(0.10, 0.11, 0.075), rough=0.38, metal=0.25, brushed=False, wear=0.6)
    mat_steel('SteelBare', col=(0.33, 0.33, 0.34), rough=0.32, metal=1.0, wear=0.3)
    mat_aluminium('Aluminium')
    mat_wood('Wood')
    mat_rubber('Rubber')
    mat_fabric('Fabric', (0.020, 0.020, 0.021))
    mat_fabric('FabricTan', (0.32, 0.25, 0.15))
    mat_brass('Brass')
    mat_copper('Copper')
    mat_simple('Nickel', (0.55, 0.53, 0.50), 1.0, 0.3)
    mat_simple('ShellPlastic', (0.35, 0.03, 0.02), 0.0, 0.45)
    mat_paint('SightPaint')
    mat_lens('Lens')
    mat_glow('Glow')
    mat_simple('Bore', (0.004, 0.004, 0.004), 0.6, 0.6)
    # studio
    mat_simple('Dummy', (0.13, 0.13, 0.14), 0.0, 0.6)
    mat_simple('DummyHead', (0.16, 0.15, 0.14), 0.0, 0.55)
    mat_simple('DummyArmR', (0.13, 0.15, 0.20), 0.0, 0.6)
    mat_simple('DummyArmL', (0.20, 0.15, 0.12), 0.0, 0.6)
    mat_simple('FlatGrey', (0.32, 0.32, 0.33), 0.0, 0.55)
    mat_simple('Marker', (1.0, 0.75, 0.1), 0.0, 0.5, extra={'Emission Color': C(1, 0.7, 0.1), 'Emission Strength': 2.0})
    m = NB('Floor')
    ln = m.n('ShaderNodeVectorMath', operation='LENGTH')
    m.l(m.obj(), ln.inputs[0])
    fade = m.mask(ln.outputs['Value'], 0.3, 3.0)
    m.bsdf(m.mixc(fade, C(0.020, 0.020, 0.021), C(0.006, 0.006, 0.007)), 0.0, 0.9, None,
           extra={'Specular IOR Level': 0.1})
    m = NB('Ground')
    m.bsdf(m.mixc(m.mask(m.noise(3, 6, 0.6), 0.3, 0.7), C(0.16, 0.155, 0.15), C(0.11, 0.105, 0.10)), 0.0, 0.9)
    return MAT


# ======================================================================================
# 7. the gun model (named parts, pivots, groups, hinges, markers) -> objects and JSON
# ======================================================================================

class Part:
    """One named mesh part under construction: a bmesh in MODEL space plus its material list.
    `origin` is the pivot (the object origin after build); `parent` another part's name."""

    def __init__(self, name, paint=None, parent=None, origin=(0, 0, 0), fit=None):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []
        self.paint = paint
        self.parent = parent
        self.origin = V(origin)
        self.fit = fit

    def mi(self, mat):
        """Material index of the paint key `mat` in this part (added on first use)."""
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)


class GunModel:
    """A gun under construction: parts, markers, hinges, groups, separate models, colliders; builds the
    Blender objects (origins at the pivots, children parented) and writes the markers JSON (§5.5)."""

    def __init__(self, gid, mass=1.0, dims=None):
        self.id = gid
        self.parts = {}
        self.order = []
        self.markers = {}
        self.hinges = {}
        self.separate = {}
        self.colliders = {}
        self.extra = {}
        self.mass = mass
        self.dims = dims or {}
        self.objects = {}

    def part(self, name, paint=None, parent=None, origin=(0, 0, 0), fit=None):
        """Get or create the part `name` (paint = its main paint key for the JSON)."""
        if name not in self.parts:
            self.parts[name] = Part(name, paint, parent, origin, fit)
            self.order.append(name)
        return self.parts[name]

    def marker(self, name, p, x=(1, 0, 0), z=(0, 0, 1)):
        """Marker MK_<name>: position p (model metres), +X axis x, +Z axis ~z (re-orthogonalised)."""
        X = V(x).normalized()
        Z = V(z)
        Z = (Z - X * Z.dot(X))
        if Z.length < 1e-6:
            Z = V((0, 0, 1)) - X * X.z
        Z.normalize()
        self.markers[name] = (V(p), X, Z)

    def hinge(self, name, kind, axis, mx, rest=0.0, mn=0.0, pivot=None, **kw):
        """A moving part's hinge (kind 'slide' metres or 'rotate' degrees, ARCHITECTURE §5.2)."""
        piv = V(pivot) if pivot is not None else self.parts[name].origin
        h = {'type': kind, 'pivot': [round(c, 5) for c in piv], 'axis': [round(c, 5) for c in V(axis)],
             'rest': rest, 'min': mn, 'max': mx}
        h.update(kw)
        self.hinges[name] = h

    def groups(self):
        out = {}
        for n in self.order:
            p = self.parts[n]
            if p.parent:
                out.setdefault(p.parent, []).append(n)
        return out

    def build(self, col, smooth_angle=32.0):
        """Create the objects: mesh data relative to each part's origin, parents set (rest = identity),
        smooth shading with sharp edges above `smooth_angle`.  Returns {name: object}."""
        for name in self.order:
            p = self.parts[name]
            bm = p.bm
            bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
            for v in bm.verts:
                v.co -= p.origin
            me = bpy.data.meshes.new(name)
            bm.to_mesh(me)
            for mname in p.mats:
                me.materials.append(MAT[mname])
            me.shade_smooth()
            try:
                me.set_sharp_from_angle(angle=math.radians(smooth_angle))
            except Exception:
                pass
            ob = bpy.data.objects.new(name, me)
            col.objects.link(ob)
            ob.location = p.origin
            self.objects[name] = ob
        for name in self.order:
            p = self.parts[name]
            if p.parent:
                ob = self.objects[name]
                par = self.objects[p.parent]
                ob.parent = par
                ob.location = p.origin - self.parts[p.parent].origin
        bpy.context.view_layer.update()
        return self.objects

    def empties(self, col, size=0.006):
        """Marker empties MK_<name> (for the .blend and the renders)."""
        out = {}
        for n, (p, X, Z) in self.markers.items():
            e = bpy.data.objects.new('MK_' + n, None)
            e.empty_display_type = 'ARROWS'
            e.empty_display_size = size
            Y = Z.cross(X)
            M = basis(X, Y, Z).to_4x4()
            M.translation = p
            e.matrix_world = M
            col.objects.link(e)
            out[n] = e
        return out

    def marker_frame(self, name):
        """4x4 model-space frame of a marker."""
        p, X, Z = self.markers[name]
        M = basis(X, Z.cross(X), Z).to_4x4()
        M.translation = p
        return M

    def to_json(self, path, tris=None):
        """Write <id>.markers.json (ARCHITECTURE §5.5)."""
        parts = {}
        for n in self.order:
            p = self.parts[n]
            e = {'paint': p.paint or (p.mats[0] if p.mats else None), 'mats': p.mats,
                 'origin': [round(c, 5) for c in p.origin]}
            if p.fit:
                e['fit'] = p.fit
            if p.parent:
                e['parent'] = p.parent
            if tris and n in tris:
                e['tris'] = tris[n]
            parts[n] = e
        data = {'id': self.id, 'units': 'm', 'axes': '+X muzzle, +Y left, +Z up',
                'roblox': 'roblox gun space (studs) = (-y, z, -x) / 0.28', 'massKg': self.mass,
                'dims': self.dims, 'parts': parts, 'groups': self.groups(), 'hinges': self.hinges,
                'markers': {n: {'p': [round(c, 5) for c in p], 'x': [round(c, 5) for c in X],
                                'z': [round(c, 5) for c in Z]} for n, (p, X, Z) in self.markers.items()},
                'separate': self.separate, 'colliders': self.colliders}
        if tris:
            data['tris'] = {'total': sum(tris[n] for n in self.order if n in tris), **{k: v for k, v in tris.items()
                                                                                        if k not in self.order}}
        data.update(self.extra)
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        with open(path, 'w') as f:
            json.dump(data, f, indent=1)
        return data


def single_object(col, name, bm, mats, origin=(0, 0, 0), smooth_angle=35.0):
    """A standalone object (casing, round, mag model) from a bmesh in its own space, origin moved to
    `origin` (e.g. its centre of mass)."""
    o = V(origin)
    for v in bm.verts:
        v.co -= o
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    for m in mats:
        me.materials.append(MAT[m])
    me.shade_smooth()
    try:
        me.set_sharp_from_angle(angle=math.radians(smooth_angle))
    except Exception:
        pass
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    ob.location = o
    return ob


def finish_meshes(objs, dissolve_deg=0.5):
    """The last step of every mesh before the UVs, the bake and the FBX (ARCHITECTURE §5.1, all five guns):
    remove degenerate faces (the FBX exporter drops them, so the JSON counts would lie), merge exactly coplanar
    faces of the same material (< `dissolve_deg`: flat caps, fans and straight lathe rings; no visible change),
    drop duplicate faces (the FBX import keeps only one) and TRIANGULATE (beauty) so Roblox's MikkTSpace tangents match the baked normal map (no quads or n-gons
    left for the importer to split its own way).  The sharp-edge flags set by the build are kept (new edges
    lie inside flat faces and stay smooth)."""
    for ob in (objs.values() if isinstance(objs, dict) else objs):
        if ob.type != 'MESH':
            continue
        me = ob.data
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-7, edges=list(bm.edges))
        if dissolve_deg > 0:
            bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(dissolve_deg), verts=list(bm.verts),
                                     edges=list(bm.edges), delimit={'MATERIAL', 'SHARP'})
        bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method='BEAUTY', ngon_method='BEAUTY')
        # duplicate faces (two triangles on the same three vertices, e.g. a cap meeting a coincident cap):
        # FBX importers keep one, so keep one here too
        bm.verts.index_update()
        seen, dup = set(), []
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
        me.update()


def tri_counts(objs):
    """{name: triangle count} of mesh objects (dict or list)."""
    out = {}
    items = objs.items() if isinstance(objs, dict) else ((o.name, o) for o in objs)
    for name, ob in items:
        if ob.type != 'MESH':
            continue
        ob.data.calc_loop_triangles()
        out[name] = len(ob.data.loop_triangles)
    return out


def bm_volume_com(bm):
    """Approximate centre of mass of a closed bmesh (signed tetra volumes)."""
    vol = 0.0
    c = V((0, 0, 0))
    for f in bm.faces:
        vs = [v.co for v in f.verts]
        for i in range(1, len(vs) - 1):
            a, b, cc = vs[0], vs[i], vs[i + 1]
            v6 = a.dot(b.cross(cc))
            vol += v6
            c += (a + b + cc) * v6 / 4
    if abs(vol) < 1e-12:
        return V((0, 0, 0))
    return c / vol


# ======================================================================================
# 8. UV atlas, baking (Color / Normal / Roughness / Metalness), export
# ======================================================================================

def _select_only(objs, active=None):
    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def uv_atlas(objs, margin=0.003, angle=60.0):
    """One shared UV atlas for all `objs` (Smart UV per object, islands at the same texel density, packed
    together into 0..1).  Every object gets a 'UVMap' layer."""
    objs = [o for o in objs if o.type == 'MESH']
    for ob in objs:
        if not ob.data.uv_layers:
            ob.data.uv_layers.new(name='UVMap')
    _select_only(objs)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.select_all(action='SELECT')
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=True, margin=margin)
    bpy.ops.object.mode_set(mode='OBJECT')


def _principled(mat):
    for n in mat.node_tree.nodes:
        if n.type == 'BSDF_PRINCIPLED':
            return n
    return None


def _gain_normal(path, gain):
    """Scale the tangent-space XY of a normal map PNG by `gain` and renormalise (procedural bumps bake
    subtle; Roblox shows normal maps softer than Cycles)."""
    import numpy as np
    from PIL import Image
    a = np.asarray(Image.open(path).convert('RGB')).astype(np.float32) / 255.0 * 2.0 - 1.0
    a[..., 0:2] *= gain
    a[..., 2] = np.clip(a[..., 2], 0.05, 1.0)
    a /= np.linalg.norm(a, axis=2, keepdims=True)
    Image.fromarray(np.clip((a + 1.0) * 127.5, 0, 255).astype(np.uint8)).save(path)


def bake_atlas(objs, out_dir, prefix, size=1024, samples=16, margin=6, normal_gain=2.5):
    """Bake the procedural materials of `objs` (sharing one UV atlas, see uv_atlas) into four PNGs for a
    Roblox SurfaceAppearance: <prefix>_Color.png (sRGB), _Normal.png (tangent, OpenGL +Y), _Roughness.png
    and _Metalness.png (linear greys).  Colour / roughness / metalness use the emission trick (the
    Principled input re-routed to an Emission shader), the normal map is a real Cycles NORMAL bake (so
    the procedural bumps: stipple, serrations, weave, grain, become texture), its XY scaled by
    `normal_gain`.  Returns {kind: path}."""
    sc = bpy.context.scene
    prev_engine, prev_samples = sc.render.engine, sc.cycles.samples
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = samples
    try:
        sc.cycles.use_denoising = False
    except Exception:
        pass
    objs = [o for o in objs if o.type == 'MESH']
    mats = []
    for ob in objs:
        for m in ob.data.materials:
            if m and m not in mats:
                mats.append(m)
    paths = {}
    os.makedirs(out_dir, exist_ok=True)
    for kind, socket, cs, default in (('Color', 'Base Color', 'sRGB', (0.5, 0.5, 0.5, 1)),
                                      ('Roughness', 'Roughness', 'Non-Color', None),
                                      ('Metalness', 'Metallic', 'Non-Color', None),
                                      ('Normal', None, 'Non-Color', (0.5, 0.5, 1.0, 1))):
        img = bpy.data.images.new('%s_%s' % (prefix, kind), size, size, alpha=False, float_buffer=False)
        img.colorspace_settings.name = cs
        img.generated_color = default or (0.5, 0.5, 0.5, 1)
        restore = []
        for m in mats:
            nt = m.node_tree
            tex = nt.nodes.new('ShaderNodeTexImage')
            tex.image = img
            nt.nodes.active = tex
            out = [n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'][0]
            old_link = out.inputs['Surface'].links[0].from_socket if out.inputs['Surface'].links else None
            em = None
            if socket:
                p = _principled(m)
                em = nt.nodes.new('ShaderNodeEmission')
                src = p.inputs[socket] if p else None
                if src is not None and src.links:
                    nt.links.new(src.links[0].from_socket, em.inputs['Color'])
                elif src is not None:
                    v = src.default_value
                    em.inputs['Color'].default_value = (v[0], v[1], v[2], 1) if hasattr(v, '__len__') else (v, v, v, 1)
                nt.links.new(em.outputs[0], out.inputs['Surface'])
            restore.append((m, tex, em, old_link, out))
        _select_only(objs)
        bk = sc.render.bake
        bk.use_selected_to_active = False
        bk.margin = margin
        bk.target = 'IMAGE_TEXTURES'
        bk.use_clear = True
        if kind == 'Normal':
            bk.normal_space = 'TANGENT'
            bpy.ops.object.bake(type='NORMAL', margin=margin, use_clear=True)
        else:
            bpy.ops.object.bake(type='EMIT', margin=margin, use_clear=True)
        path = os.path.join(out_dir, '%s_%s.png' % (prefix, kind))
        img.filepath_raw = path
        img.file_format = 'PNG'
        img.save()
        if kind == 'Normal' and normal_gain != 1.0:
            _gain_normal(path, normal_gain)
        paths[kind] = path
        for m, tex, em, old_link, out in restore:
            nt = m.node_tree
            nt.nodes.remove(tex)
            if em:
                nt.nodes.remove(em)
            if old_link is not None:
                nt.links.new(old_link, out.inputs['Surface'])
        print('baked', path, flush=True)
    sc.render.engine, sc.cycles.samples = prev_engine, prev_samples
    try:
        sc.cycles.use_denoising = True
    except Exception:
        pass
    return paths


def baked_material(name, paths):
    """A material that shows the baked maps exactly as a Roblox SurfaceAppearance would (for the
    'game look' render)."""
    m = NB(name)
    uv = m.n('ShaderNodeUVMap', uv_map='UVMap')
    tex = {}
    for k in ('Color', 'Normal', 'Roughness', 'Metalness'):
        img = bpy.data.images.load(paths[k], check_existing=True)
        img.colorspace_settings.name = 'sRGB' if k == 'Color' else 'Non-Color'
        t = m.n('ShaderNodeTexImage', image=img)
        m.l(uv.outputs['UV'], t.inputs['Vector'])
        tex[k] = t
    nm = m.n('ShaderNodeNormalMap', uv_map='UVMap')
    m.l(tex['Normal'].outputs['Color'], nm.inputs['Color'])
    m.bsdf(tex['Color'].outputs['Color'], tex['Metalness'].outputs['Color'], tex['Roughness'].outputs['Color'],
           nm.outputs['Normal'])
    return m.m


def swap_materials(objs, mat):
    """Put `mat` in every slot of `objs`; returns a restore list for restore_materials."""
    saved = []
    for ob in objs:
        if ob.type != 'MESH':
            continue
        saved.append((ob, [s.material for s in ob.material_slots]))
        for s in ob.material_slots:
            s.material = mat
    return saved


def restore_materials(saved):
    for ob, mats in saved:
        for s, m in zip(ob.material_slots, mats):
            s.material = m


def export_fbx(objs, path):
    """FBX of the given mesh objects (named parts, UVs, metres; import in Roblox with 'Meter' units),
    the same axis settings as the flamethrower (axis_forward -Z, axis_up Y, FBX_SCALE_UNITS)."""
    keep = [o for o in objs if o.type == 'MESH']
    _select_only(keep)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=os.path.abspath(path), use_selection=True, object_types={'MESH'},
                             apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS', axis_forward='-Z',
                             axis_up='Y', mesh_smooth_type='FACE', use_mesh_modifiers=True, add_leaf_bones=False,
                             bake_anim=False, path_mode='STRIP', use_tspace=True)
    print('FBX', path, flush=True)
    return path


# ======================================================================================
# 9. studio and renders
# ======================================================================================

def reset_scene():
    """Empty the file (objects, meshes, materials, curves, images, lights, cameras)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MAT.clear()
    global _TMP_COL
    _TMP_COL = None


def setup_render(samples=64, res=(1600, 1000), transparent=False, exposure=-0.4):
    """Cycles CPU, adaptive sampling, OIDN denoise, AgX; a near-black studio world.  Returns the world
    background node (change its colour / strength for other looks)."""
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.adaptive_threshold = 0.02
    sc.cycles.use_denoising = True
    try:
        sc.cycles.denoiser = 'OPENIMAGEDENOISE'
    except Exception:
        pass
    sc.cycles.max_bounces = 6
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.render.film_transparent = transparent
    try:
        sc.view_settings.view_transform = 'AgX'
        sc.view_settings.look = 'AgX - Medium High Contrast'
        sc.view_settings.exposure = exposure
    except Exception:
        pass
    sc.unit_settings.system = 'METRIC'
    sc.unit_settings.scale_length = 1.0
    w = bpy.data.worlds.new('Studio')
    sc.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = w.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value = (0.004, 0.004, 0.0045, 1)
    bg.inputs['Strength'].default_value = 1.0
    return bg


def set_res(w, h):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = w, h


def add_floor(col, z, mat='Floor', size=12):
    """A big floor plane at height z."""
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size)
    me = bpy.data.meshes.new('Floor')
    bm.to_mesh(me)
    bm.free()
    me.materials.append(MAT[mat])
    ob = bpy.data.objects.new('Floor', me)
    ob.location = (0, 0, z)
    col.objects.link(ob)
    return ob


class Rig:
    """Camera + key / fill / two rims / top lights that follow the camera (as the flamethrower's Rig).
    frame(bbox, view_dir, ...) fits the bbox in view (ortho or perspective) and re-aims the lights."""
    BASE = {'Key': 85, 'Fill': 12, 'Rim': 240, 'Kick': 140, 'Top': 8}

    def __init__(self, col):
        cd = bpy.data.cameras.new('Cam')
        self.cam = bpy.data.objects.new('Cam', cd)
        col.objects.link(self.cam)
        bpy.context.scene.camera = self.cam
        self.lights = {}
        for name, size, color in (('Key', 1.4, (1.0, 0.94, 0.86)), ('Fill', 2.5, (0.82, 0.88, 1.0)),
                                  ('Rim', 0.8, (1.0, 0.96, 0.9)), ('Kick', 0.8, (0.85, 0.9, 1.0)),
                                  ('Top', 3.0, (1, 1, 1))):
            ld = bpy.data.lights.new(name, 'AREA')
            ld.size = size
            ld.color = color
            ob = bpy.data.objects.new(name, ld)
            col.objects.link(ob)
            self.lights[name] = ob
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

    def frame(self, bbox, view_dir, lens=70, ortho=False, margin=1.10, up=(0, 0, 1), target=None, light_scale=1.0,
              shift=(0, 0), ortho_scale=None):
        lo, hi = V(bbox[0]), V(bbox[1])
        center = V(target) if target is not None else (lo + hi) / 2
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
            self.aim(cam, center + d * 3, center, up)
            Mi = cam.matrix_world.inverted()
            pts = [Mi @ c for c in corners]
            w = max(abs(p.x) for p in pts) * 2 * margin
            hgt = max(abs(p.y) for p in pts) * 2 * margin
            cam.data.ortho_scale = ortho_scale or max(w, hgt * aspect)
            dist = 1.0
        else:
            cam.data.type = 'PERSP'
            cam.data.lens = lens
            lo_d, hi_d = 0.02, 60.0
            for _ in range(48):
                dist = (lo_d + hi_d) / 2
                self.aim(cam, center + d * dist, center, up)
                Mi = cam.matrix_world.inverted()
                ok = True
                for c in corners:
                    p = Mi @ c
                    zc = -p.z
                    if zc <= 0.005 or abs(p.x / zc) > tx / margin or abs(p.y / zc) > ty / margin:
                        ok = False
                        break
                if ok:
                    hi_d = dist
                else:
                    lo_d = dist
            dist = hi_d
            self.aim(cam, center + d * dist, center, up)
        cam.data.clip_start = 0.005
        cam.data.clip_end = 100
        size = (hi - lo).length
        self.place_lights(center, max(size * 2.2, 0.6) * light_scale)

    def place_lights(self, center, L):
        R = self.cam.matrix_world.to_3x3()
        right, back = R.col[0], R.col[2]
        worldup = V((0, 0, 1))
        place = {'Key': -right * 0.9 + worldup * 1.0 + back * 0.8, 'Fill': right * 1.1 + worldup * 0.15 + back * 0.8,
                 'Rim': right * 0.55 + worldup * 0.7 - back * 1.0, 'Kick': -right * 0.8 + worldup * 0.35 - back * 1.0,
                 'Top': worldup * 1.6}
        for name, off in place.items():
            ob = self.lights[name]
            loc = center + off.normalized() * L
            self.aim(ob, loc, center)
            ob.data.size = max(0.25, L * 0.6) if name != 'Top' else max(0.5, L)
            ob.data.energy = self.BASE[name] * self.mult * (L / 2.0) ** 2


def render(path):
    """Render the scene camera to `path` (PNG)."""
    sc = bpy.context.scene
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print('rendered', path, flush=True)
    return path


def world_bbox(objs):
    """(lo, hi) world bounding box of objects (meshes only; empties ignored)."""
    lo = V((1e9, 1e9, 1e9))
    hi = V((-1e9, -1e9, -1e9))
    for ob in objs:
        if ob.type != 'MESH':
            continue
        for c in ob.bound_box:
            w = ob.matrix_world @ V(c)
            lo = V((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = V((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    return lo, hi


def font(size, bold=False):
    from PIL import ImageFont
    try:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf' % ('-Bold' if bold else ''), size)
    except Exception:
        return ImageFont.load_default()


def caption(path, lines, size=22, color=(225, 218, 205), pos=(20, 16)):
    """Write text lines on a PNG in place."""
    from PIL import Image, ImageDraw
    im = Image.open(path).convert('RGB')
    d = ImageDraw.Draw(im)
    y = pos[1]
    for ln in (lines if isinstance(lines, (list, tuple)) else [lines]):
        d.text((pos[0] + 1, y + 1), ln, fill=(0, 0, 0), font=font(size))
        d.text((pos[0], y), ln, fill=color, font=font(size))
        y += int(size * 1.3)
    im.save(path)
    return path


def contact_sheet(files, path, title, cols=3, tw=560, th=350):
    """A labelled grid of the given PNGs (file names as labels)."""
    from PIL import Image, ImageDraw
    rows = math.ceil(len(files) / cols)
    pad, lab = 10, 26
    sheet = Image.new('RGB', (cols * (tw + pad) + pad, rows * (th + lab + pad) + pad + 46), (12, 12, 13))
    d = ImageDraw.Draw(sheet)
    d.text((pad, 10), title, fill=(220, 210, 195), font=font(22, True))
    for i, fpath in enumerate(files):
        im = Image.open(fpath).convert('RGB')
        im.thumbnail((tw, th))
        x = pad + (i % cols) * (tw + pad)
        y = 46 + pad + (i // cols) * (th + lab + pad)
        sheet.paste(im, (x + (tw - im.width) // 2, y + (th - im.height) // 2))
        d.text((x + 4, y + th + 3), os.path.splitext(os.path.basename(fpath))[0], fill=(190, 185, 175), font=font(17))
    sheet.save(path)
    print('SHEET', path, flush=True)
    return path


def grid(files, path, cols=2, tw=800, th=600, labels=None, title=None):
    """A plain image grid (holds: front / side / top / eye)."""
    from PIL import Image, ImageDraw
    rows = math.ceil(len(files) / cols)
    top = 40 if title else 0
    sheet = Image.new('RGB', (cols * tw, rows * th + top), (10, 10, 11))
    d = ImageDraw.Draw(sheet)
    if title:
        d.text((10, 8), title, fill=(225, 215, 200), font=font(22, True))
    for i, f in enumerate(files):
        im = Image.open(f).convert('RGB')
        im.thumbnail((tw, th))
        x, y = (i % cols) * tw, top + (i // cols) * th
        sheet.paste(im, (x + (tw - im.width) // 2, y + (th - im.height) // 2))
        if labels:
            d.text((x + 10, y + 8), labels[i], fill=(235, 225, 205), font=font(20))
    sheet.save(path)
    return path


def project(co):
    """World point -> pixel (x, y) in the current camera's render."""
    from bpy_extras.object_utils import world_to_camera_view
    sc = bpy.context.scene
    p = world_to_camera_view(sc, sc.camera, V(co))
    return p.x * sc.render.resolution_x, (1 - p.y) * sc.render.resolution_y


def label_points(path, items, size=20):
    """Labels with leader lines on a rendered PNG: items = [(text, world_point, (dx, dy) pixel offset)].
    Call right after rendering (uses the current camera)."""
    from PIL import Image, ImageDraw
    im = Image.open(path).convert('RGB')
    d = ImageDraw.Draw(im)
    f = font(size)
    for text, co, off in items:
        x, y = project(co)
        tx, ty = x + off[0], y + off[1]
        d.line([(x, y), (tx, ty)], fill=(230, 200, 120), width=2)
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(230, 200, 120))
        w = d.textlength(text, font=f)
        bx = tx - w / 2
        d.rectangle([bx - 4, ty - 2, bx + w + 4, ty + size + 4], fill=(18, 18, 20))
        d.text((bx, ty), text, fill=(240, 232, 215), font=f)
    im.save(path)
    return path


def ref_compare(ref_png, ours_png, ours_alpha_png, path, title='', flip=False):
    """Side-by-side of the reference photo and our side ortho at the SAME framing (both cropped to the
    gun's silhouette bbox and scaled to the same width), plus an overlay: reference silhouette in red,
    ours in cyan, overlap white.  `ours_alpha_png` is our render with a transparent background.
    Returns (path, iou) where iou is the silhouette intersection-over-union."""
    from PIL import Image, ImageDraw
    import numpy as np
    ref = Image.open(ref_png).convert('RGBA')
    ra = np.array(ref).astype(float)
    rmask = (ra[:, :, :3].sum(2) < 600) & (ra[:, :, 3] > 10)
    ys, xs = np.nonzero(rmask)
    rb = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    our = Image.open(ours_alpha_png).convert('RGBA')
    oa = np.array(our)
    omask = oa[:, :, 3] > 40
    ys, xs = np.nonzero(omask)
    ob = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    W = 900
    def crop_scale(im, b, mask):
        c = im.crop(b)
        h = int(round(c.height * W / c.width))
        m = Image.fromarray((mask[b[1]:b[3], b[0]:b[2]] * 255).astype('uint8')).resize((W, h), Image.LANCZOS)
        return c.resize((W, h), Image.LANCZOS), m
    rc, rm = crop_scale(ref, rb, rmask)
    shot = Image.open(ours_png).convert('RGBA')
    oc, om = crop_scale(shot, ob, omask)
    if flip:
        oc, om = oc.transpose(Image.FLIP_LEFT_RIGHT), om.transpose(Image.FLIP_LEFT_RIGHT)
    H = max(rc.height, oc.height)
    out = Image.new('RGB', (W * 3 + 40, H + 70), (235, 235, 235))
    d = ImageDraw.Draw(out)
    bgw = Image.new('RGBA', rc.size, (255, 255, 255, 255))
    out.paste(Image.alpha_composite(bgw, rc).convert('RGB'), (10, 50))
    out.paste(oc.convert('RGB'), (W + 20, 50))
    a = np.array(rm.resize((W, H))) > 128
    b = np.array(om.resize((W, H))) > 128
    ov = np.zeros((H, W, 3), 'uint8') + 30
    ov[a & ~b] = (230, 60, 50)
    ov[b & ~a] = (40, 200, 230)
    ov[a & b] = (235, 235, 235)
    out.paste(Image.fromarray(ov), (2 * W + 30, 50))
    iou = float((a & b).sum()) / max(1, float((a | b).sum()))
    d.text((10, 12), '%s   reference | ours (same width) | overlay: red = ref only, cyan = ours only, white = both;'
                     ' IoU %.3f' % (title, iou), fill=(20, 20, 20), font=font(22))
    out.save(path)
    print('COMPARE', path, 'IoU %.3f' % iou, flush=True)
    return path, iou


# ======================================================================================
# 10. the R6 rig and the hold solver (Roblox studs, Y up, -Z forward; joint values like pyro_clips)
# ======================================================================================
# part -> (joint, parent, joint point in parent, part centre in parent)  (tools/anim/pyro_clips.py RIG)
R6_RIG = {
    'Torso': ('Root', 'HRP', (0, 0, 0), (0, 0, 0)),
    'Head': ('Neck', 'Torso', (0, 1, 0), (0, 1.5, 0)),
    'Right Arm': ('RightShoulder', 'Torso', (1, 0.5, 0), (1.5, 0, 0)),
    'Left Arm': ('LeftShoulder', 'Torso', (-1, 0.5, 0), (-1.5, 0, 0)),
    'Right Leg': ('RightHip', 'Torso', (1, -1, 0), (0.5, -2, 0)),
    'Left Leg': ('LeftHip', 'Torso', (-1, -1, 0), (-0.5, -2, 0)),
}
R6_PARTS = ['Torso', 'Head', 'Right Arm', 'Left Arm', 'Right Leg', 'Left Leg']
R6_SIZE = {'Torso': (2, 2, 1), 'Head': (1.2, 1.2, 1.2), 'Right Arm': (1, 2, 1), 'Left Arm': (1, 2, 1),
           'Right Leg': (1, 2, 1), 'Left Leg': (1, 2, 1)}
HAND = (0.0, -0.92, 0.0)        # a hand point in its arm's space (ARCHITECTURE §5.3)
EYE = (0.0, 0.10, -0.42)        # the eye in Head space (Torso (0, 1.6, -0.42) at rest)
M2G = ((0, -1, 0), (0, 0, 1), (-1, 0, 0))   # model axes -> Roblox gun axes (then / STUD)


def np_angles(rx, ry, rz):
    """CFrame.Angles(rx, ry, rz) in degrees (Rx Ry Rz) as a 4x4 numpy matrix."""
    import numpy as np
    a, b, c = np.radians([rx, ry, rz])
    ca, sa, cb, sb, cc, s_ = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
    return np.array([[cb * cc, -cb * s_, sb, 0],
                     [sa * sb * cc + ca * s_, -sa * sb * s_ + ca * cc, -sa * cb, 0],
                     [-ca * sb * cc + sa * s_, ca * sb * s_ + sa * cc, ca * cb, 0],
                     [0, 0, 0, 1.0]])


def np_T(x, y, z):
    import numpy as np
    M = np.eye(4)
    M[:3, 3] = (x, y, z)
    return M


def joint_M(v):
    """A joint value (rx, ry, rz[, x, y, z]) -> T(x, y, z) * Angles(rx, ry, rz)."""
    v = tuple(v) + (0, 0, 0) if len(v) == 3 else tuple(v)
    return np_T(*v[3:]) @ np_angles(*v[:3])


def r6_frames(pose, base=None):
    """World (HRP-space) frames of the six R6 parts for a pose {joint: value} (pyro_clips.frames_of)."""
    import numpy as np
    frames = {'HRP': np.eye(4) if base is None else base}
    for part in R6_PARTS:
        joint, parent, jp, centre = R6_RIG[part]
        v = pose.get(joint, (0, 0, 0))
        local = np_T(*jp) @ joint_M(v) @ np_T(centre[0] - jp[0], centre[1] - jp[1], centre[2] - jp[2])
        frames[part] = frames[parent] @ local
    return frames


def to_euler_xyz(R):
    """XYZ degrees (R = Rx Ry Rz, like CFrame.Angles) of a 3x3 rotation."""
    y = math.asin(max(-1.0, min(1.0, R[0][2])))
    x = math.atan2(-R[1][2], R[2][2])
    z = math.atan2(-R[0][1], R[0][0])
    return (math.degrees(x), math.degrees(y), math.degrees(z))


def rotvec(w_deg):
    """3x3 rotation from a rotation vector in degrees (numpy)."""
    import numpy as np
    w = np.radians(np.asarray(w_deg, float))
    th = np.linalg.norm(w)
    if th < 1e-12:
        return np.eye(3)
    k = w / th
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + math.sin(th) * K + (1 - math.cos(th)) * K @ K


def cframe12(M):
    """A 4x4 numpy matrix -> the 12 numbers of CFrame.new(x, y, z, r00 ... r22) (rounded)."""
    return [round(float(v), 5) for v in (M[0, 3], M[1, 3], M[2, 3], M[0, 0], M[0, 1], M[0, 2], M[1, 0], M[1, 1],
                                         M[1, 2], M[2, 0], M[2, 1], M[2, 2])]


def model_to_gun(p):
    """Model metres -> Roblox gun-space studs."""
    import numpy as np
    return np.array(M2G) @ np.asarray(p, float) / STUD


def marker_gun_frame(gun, name):
    """4x4 numpy frame of a marker in Roblox gun space (studs)."""
    import numpy as np
    p, X, Z = gun.markers[name]
    C_ = np.array(M2G, float)
    x = C_ @ np.array(X)
    z = C_ @ np.array(Z)
    y = np.cross(z, x)
    M = np.eye(4)
    M[:3, 0], M[:3, 1], M[:3, 2] = x, y, z
    M[:3, 3] = model_to_gun(p)
    return M


class HoldSolver:
    """Solve how a rigid-armed R6 holds a gun (ARCHITECTURE §7.4, generalising flamethrower.solve_hold and
    pyro_clips.solve_right / solve_left).

    The gun hangs from the Right Arm through a weld W = T(HAND) * Rn * Rw * GripR^-1, where Rn maps the
    GripR marker frame onto the arm (marker +Z -> arm +Y: hand toward the elbow; marker +X -> arm -Z: the
    arm's front face), and Rw is the "wrist" (a rotation vector, |w| <= wrist_limit).  Unknowns (degrees):
    Root (rx lean, ry blade yaw, rz roll), Neck (3), RightShoulder (3), LeftShoulder (3), wrist (3).

    Costs (soft, least squares): the bore along the stance direction (yaw, pitch in HRP space), the gun's
    cant, the left hand point on GripL (or a stance-specific gun-space target), the left arm within
    left_limit of the GripL +Z, the wrist within its limit, the eye on the SightEye line (ADS) or a set
    height above it (ready), shouldered: the Shoulder marker in the pocket, no gun point inside the torso
    or head, arms not through the torso, preferences (blade, lean, low roll, the head level / looking at a
    point).  Several random starts, best kept.

    gun: a GunModel (markers in model metres).  samples: model-space points used for penetration tests."""

    def __init__(self, gun, samples, grip='GripR', grip_l='GripL'):
        import numpy as np
        self.gun = gun
        self.G_grip = marker_gun_frame(gun, grip)
        self.G_grip_inv = np.linalg.inv(self.G_grip)
        self.left_default = grip_l
        self.samples = np.array([model_to_gun(p) for p in samples])
        self.m = {n: marker_gun_frame(gun, n) for n in gun.markers}
        Rn = np.zeros((3, 3))
        Rn[:, 0] = (0, 0, -1)     # marker X -> arm -Z
        Rn[:, 2] = (0, 1, 0)      # marker Z -> arm +Y
        Rn[:, 1] = np.cross(Rn[:, 2], Rn[:, 0])
        self.Rn = Rn

    def weld(self, w):
        import numpy as np
        A = np.eye(4)
        A[:3, :3] = self.Rn @ rotvec(w)
        A[:3, 3] = HAND
        return A @ self.G_grip_inv

    def pose_of(self, x, st):
        lean, yaw, roll = x[0:3]
        p = {'Root': (lean, yaw, roll, 0, -st.get('drop', 0.0), 0), 'Neck': tuple(x[3:6]),
             'RightShoulder': tuple(x[6:9]), 'LeftShoulder': tuple(x[9:12])}
        p.update(legs_for(lean, st.get('drop', 0.0), st.get('front', 12.0)))
        return p

    def evaluate(self, x, st):
        """Everything about a candidate: frames, gun frame (HRP space), points, residual pieces."""
        import numpy as np
        pose = self.pose_of(x, st)
        F = r6_frames(pose)
        W = self.weld(x[12:15])
        G = F['Right Arm'] @ W
        out = {'pose': pose, 'F': F, 'W': W, 'G': G}
        bore = G[:3, :3] @ np.array([0, 0, -1.0])
        up = G[:3, :3] @ np.array([0, 1.0, 0])
        right = G[:3, :3] @ np.array([1.0, 0, 0])
        out['bore'], out['up'], out['right'] = bore, up, right
        lt = st.get('left', self.left_default)
        if lt is None:
            out['lerr'] = None
        else:
            if isinstance(lt, str):
                Lm = self.m[lt]
            else:
                Lm = np.eye(4)
                Lm[:3, 3] = model_to_gun(lt)
                if 'left_z' in st:
                    Lm[:3, 2] = np.array(M2G) @ np.asarray(st['left_z'], float)
            goal = G @ Lm[:, 3]
            hand = F['Left Arm'] @ np.array(HAND + (1.0,))
            out['lgoal'], out['lhand'] = goal[:3], hand[:3]
            out['lerr'] = hand[:3] - goal[:3]
            zgoal = (G[:3, :3] @ Lm[:3, 2])
            larm = F['Left Arm'][:3, 1]
            out['lang'] = math.degrees(math.acos(max(-1, min(1, float(np.dot(larm, zgoal) / np.linalg.norm(zgoal))))))
        rarm = F['Right Arm'][:3, 1]
        zr = G[:3, :3] @ self.G_grip[:3, 2]
        out['rang'] = math.degrees(math.acos(max(-1, min(1, float(np.dot(rarm, zr))))))
        eye = F['Head'] @ np.array(EYE + (1.0,))
        out['eye'] = eye[:3]
        if 'SightEye' in self.m:
            S = G @ self.m['SightEye']
            o, d = S[:3, 3], S[:3, 0]
            rel = out['eye'] - o
            t = float(np.dot(rel, d))
            perp = rel - d * t
            out['sight_t'], out['sight_perp'] = t, perp
            out['sight_o'], out['sight_d'] = o, d
        if 'Shoulder' in self.m:
            out['butt'] = (G @ self.m['Shoulder'][:, 3])[:3]
        out['pts'] = (G[:3, :3] @ self.samples.T).T + G[:3, 3]
        return out

    def residual(self, x, st):
        import numpy as np
        e = self.evaluate(x, st)
        r = []
        # aim direction
        yaw, pitch = math.radians(st.get('yaw', 0.0)), math.radians(st.get('pitch', 0.0))
        want = np.array([-math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch)])
        r += list((e['bore'] - want) * st.get('w_dir', 12.0))
        # cant: the gun's right vs the horizontal (positive cant = top rolls to the right)
        cant = math.degrees(math.asin(max(-1, min(1, float(-e['right'][1])))))
        r.append((cant - st.get('cant', 0.0)) / 25.0 * st.get('w_cant', 1.0))
        # left hand
        if e['lerr'] is not None:
            r += list(e['lerr'] * st.get('w_left', 8.0))
            r.append(max(0.0, e['lang'] - st.get('left_limit', 35.0)) / 20.0)
        # wrist
        wmag = float(np.linalg.norm(x[12:15]))
        r.append(max(0.0, wmag - st.get('wrist_limit', 25.0)) / 6.0 * st.get('w_wrist', 1.0))
        r.append(wmag / 120.0)
        # eye
        if st.get('eye') == 'line' and 'sight_perp' in e:
            r += list(e['sight_perp'] * st.get('w_eye', 25.0))
            t = e['sight_t']
            tmin, tmax = st.get('eye_t', (-1.0, 0.25))
            r.append((max(0.0, tmin - t) + max(0.0, t - tmax)) * 4.0)
        elif st.get('eye') == 'over' and 'sight_perp' in e:
            h = float(e['eye'][1] - (e['sight_o'][1] + e['sight_d'][1] * e['sight_t']))
            r.append((h - st.get('eye_over', 0.4)) * 4.0)
            r.append(float(e['sight_perp'][0]) * 2.0)
        # shouldered
        if st.get('shoulder') and 'butt' in e:
            pocket = np.array(st.get('pocket', (0.75, 0.55, -0.55)))
            Ft = e['F']['Torso']
            bt = np.linalg.inv(Ft) @ np.append(e['butt'], 1.0)
            r += list((bt[:3] - pocket) * st.get('w_butt', 6.0))
        # where the gun sits (optional): a gun-space point should be at an HRP-space spot
        if 'place' in st:
            pt, goal, w = st['place']
            gp = e['G'] @ np.append(model_to_gun(pt), 1.0)
            r += list((gp[:3] - np.array(goal)) * w)
        # penetration: gun points in torso / head
        Ft_inv = np.linalg.inv(e['F']['Torso'])
        Fh_inv = np.linalg.inv(e['F']['Head'])
        P = np.c_[e['pts'], np.ones(len(e['pts']))]
        pt = (Ft_inv @ P.T).T[:, :3]
        pad = st.get('pad', 0.05)
        pen = np.clip(np.minimum.reduce([1 + pad - np.abs(pt[:, 0]), 1 + pad - np.abs(pt[:, 1]),
                                         0.5 + pad - np.abs(pt[:, 2])]), 0, None)
        ph = (Fh_inv @ P.T).T[:, :3]
        rh = np.sqrt(ph[:, 0] ** 2 + ph[:, 2] ** 2)
        penh = np.clip(np.minimum(0.62 + pad - rh, 0.62 + pad - np.abs(ph[:, 1])), 0, None)
        if st.get('shoulder'):
            pen = pen * 0.15
        r.append(float(np.sqrt(np.sum(pen ** 2))) * 30.0)
        r.append(float(np.sqrt(np.sum(penh ** 2))) * 30.0)
        # arms through the torso (sample along each arm axis, arm half-width allowance)
        for arm in ('Right Arm', 'Left Arm'):
            A = e['F'][arm]
            for t in (0.0, -0.5, -0.9):
                c = (Ft_inv @ A @ np.array([0, t, 0, 1.0]))[:3]
                d = min(1.5 - abs(c[0]), 1.0 - abs(c[1]) + 0.2, 1.0 - abs(c[2]))
                r.append(max(0.0, d) * 3.0)
        # arm blocks must not pass through the head (cylinder r 0.62 + the arm's half width)
        for arm in ('Right Arm', 'Left Arm'):
            A = e['F'][arm]
            for t in (0.6, 0.2, -0.2, -0.6, -0.95):
                c = (Fh_inv @ A @ np.array([0, t, 0, 1.0]))[:3]
                if abs(c[1]) < 0.62 + 0.45:
                    rad = math.hypot(c[0], c[2])
                    r.append(max(0.0, 0.62 + st.get('head_clear', 0.42) - rad) * st.get('w_head', 4.0))
                else:
                    r.append(0.0)
        # preferences
        lean, yaw_, roll = x[0:3]
        r.append((yaw_ - st.get('blade', 0.0)) / st.get('blade_tol', 25.0))
        r.append((lean - st.get('lean', -5.0)) / st.get('lean_tol', 20.0))
        r.append(roll / 10.0)
        # the head: level (world pitch / roll) or looking at a point
        H = e['F']['Head']
        fwd = -H[:3, 2]
        look = st.get('look')
        if look is not None:
            if isinstance(look, str):
                if look == 'gun':
                    tgt = (e['G'] @ self.m.get('MagWell', self.m[self.left_default])[:, 3])[:3]
                else:
                    tgt = (e['G'] @ self.m[look][:, 3])[:3]
            else:
                tgt = np.array(look)
            dd = tgt - e['eye']
            dd /= max(1e-6, np.linalg.norm(dd))
            r += list((fwd - dd) * 2.0)
        else:
            hp = math.degrees(math.asin(max(-1, min(1, float(fwd[1])))))
            r.append((hp - st.get('head_pitch', 0.0)) / 15.0)
            hy = math.degrees(math.atan2(-fwd[0], -fwd[2]))
            r.append((hy - st.get('head_yaw', st.get('yaw', 0.0))) / 12.0)
        r.append(float(H[1, 0]) * 2.0)   # head roll (its right axis should stay horizontal)
        neck = x[3:6]
        r += [max(0.0, abs(neck[0]) - 45) / 10, max(0.0, abs(neck[1]) - 70) / 10, max(0.0, abs(neck[2]) - 20) / 5]
        r += [neck[2] / 60.0]
        # arm twist references (pick the natural twist among equivalent solutions)
        for k, ref in ((6, st.get('rs_ref')), (9, st.get('ls_ref'))):
            if ref is not None:
                r += [(x[k + i] - ref[i]) / 240.0 for i in range(3)]
        return np.array(r, float)

    def solve(self, st, starts=24, seed=1, x0=None):
        """Solve one stance (a dict, see class doc) -> result dict (pose, weld, gun frame, residuals)."""
        import numpy as np
        from scipy.optimize import least_squares
        rng = np.random.default_rng(seed)
        lo = np.array([-35, -75, -20, -60, -80, -30, -200, -200, -200, -200, -200, -200, -70, -70, -70], float)
        hi = -lo
        hi[0] = 15
        best = None
        inits = []
        if x0 is not None:
            inits.append(np.array(x0, float))
        base = np.array([st.get('lean', -5), st.get('blade', 0), 0, 0, 0, 0] +
                        list(st.get('rs_ref', (90, 0, 0))) + list(st.get('ls_ref', (90, 0, 0))) + [0, 0, 0], float)
        inits.append(base)
        for _ in range(starts):
            v = base + rng.normal(0, 1, 15) * np.array([8, 15, 4, 15, 20, 5, 45, 45, 45, 45, 45, 45, 15, 15, 15])
            inits.append(np.clip(v, lo + 1, hi - 1))
        for v in inits:
            try:
                res = least_squares(self.residual, np.clip(v, lo + 1e-3, hi - 1e-3), args=(st,), bounds=(lo, hi),
                                    method='trf', x_scale=10.0, max_nfev=400)
            except Exception as ex:
                print('solve start failed', ex)
                continue
            if best is None or res.cost < best.cost:
                best = res
        return self.report(best.x, st, best.cost)

    def report(self, x, st, cost=0.0):
        import numpy as np
        e = self.evaluate(x, st)
        pose = {k: tuple(round(float(c), 2) for c in v) for k, v in e['pose'].items()}
        gun_torso = np.linalg.inv(e['F']['Torso']) @ e['G']
        out = {'name': st.get('name'), 'cost': round(float(cost), 5), 'pose': pose,
               'wrist': [round(float(c), 2) for c in x[12:15]],
               'weld': cframe12(e['W']), 'gunInTorso': cframe12(gun_torso), 'gunInHRP': cframe12(e['G']),
               'aim': {'yaw': st.get('yaw', 0.0), 'pitch': st.get('pitch', 0.0), 'cant': st.get('cant', 0.0)},
               'residuals': {'right': 0.0, 'rightAngleDeg': round(e['rang'], 1),
                             'wristDeg': round(float(np.linalg.norm(x[12:15])), 1)}}
        if e['lerr'] is not None:
            out['residuals']['left'] = round(float(np.linalg.norm(e['lerr'])), 4)
            out['residuals']['leftAngleDeg'] = round(e['lang'], 1)
        if 'sight_perp' in e:
            out['residuals']['eyeToSightLine'] = round(float(np.linalg.norm(e['sight_perp'])), 4)
            out['residuals']['eyeAlongSight'] = round(e['sight_t'], 3)
        if 'butt' in e:
            Ft = e['F']['Torso']
            bt = np.linalg.inv(Ft) @ np.append(e['butt'], 1.0)
            out['residuals']['buttInTorso'] = [round(float(c), 3) for c in bt[:3]]
        bore = e['bore']
        out['residuals']['boreYawPitch'] = [round(math.degrees(math.atan2(-bore[0], -bore[2])), 2),
                                            round(math.degrees(math.asin(max(-1, min(1, float(bore[1]))))), 2)]
        out['_x'] = [float(v) for v in x]
        out['_eval'] = e
        return out


def legs_for(lean, drop=0.0, front=12.0):
    """Hips that keep the legs under a leaning / dropped Root (pyro_clips.stance): the root's X lean is
    cancelled, `front` splits the stance (left leg forward), `drop` spreads the legs."""
    spread = math.degrees(math.acos(max(-1, min(1, 1 - drop / 2)))) if drop > 0 else 4.0
    return {'RightHip': (round(-lean - front * 0.6, 2), 0, round(spread, 2)),
            'LeftHip': (round(-lean + front, 2), 0, round(-spread, 2))}


def r2b(M):
    """Roblox 4x4 (numpy, studs) -> Blender world Matrix (metres): blender = (-z, -x, y) * 0.28."""
    import numpy as np
    P = np.array([[0, 0, -1], [-1, 0, 0], [0, 1, 0]], float)
    R = P @ M[:3, :3] @ P.T
    t = P @ M[:3, 3] * STUD
    B = Matrix(((R[0, 0], R[0, 1], R[0, 2], t[0]), (R[1, 0], R[1, 1], R[1, 2], t[1]),
                (R[2, 0], R[2, 1], R[2, 2], t[2]), (0, 0, 0, 1)))
    return B


def r2b_point(p):
    return V((-p[2] * STUD, -p[0] * STUD, p[1] * STUD))


def build_r6(col, frames, name='R6', with_face=True):
    """R6 dummy meshes for the given frames (bevelled boxes, a rounded head with a face plate so the
    facing reads).  Arms are tinted (right blue-grey, left brown-grey) so the hands read in the renders.
    Returns the list of objects."""
    obs = []
    P = Matrix(((0, 0, -1), (-1, 0, 0), (0, 1, 0)))
    for part in R6_PARTS:
        sx, sy, sz = R6_SIZE[part]
        bm = bmesh.new()
        if part == 'Head':
            lathe(bm, [(-0.6, 0), (-0.6, 0.48), (-0.55, 0.58), (-0.45, 0.62), (0.45, 0.62), (0.55, 0.58), (0.6, 0.48),
                       (0.6, 0)], 24, frame_x((0, 0, 0), (0, 1, 0), up=(0, 0, 1)))
            if with_face:
                box(bm, (0, 0.10, -0.60), (0.5, 0.10, 0.06), mi=1)
        else:
            rbox(bm, (0, 0, 0), (sx, sy, sz), 0.05, 2)
        for v in bm.verts:
            v.co = P @ v.co * STUD
        me = bpy.data.meshes.new(name + part)
        bm.to_mesh(me)
        bm.free()
        mat = {'Head': 'DummyHead', 'Right Arm': 'DummyArmR', 'Left Arm': 'DummyArmL'}.get(part, 'Dummy')
        me.materials.append(MAT[mat])
        me.materials.append(MAT['Bore'])
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(40))
        ob = bpy.data.objects.new(name + part.replace(' ', ''), me)
        ob.matrix_world = r2b(frames[part])
        col.objects.link(ob)
        obs.append(ob)
    return obs


def place_gun(root_obj, G):
    """Put the gun (its root empty, whose children are the parts at model coordinates) at the Roblox
    HRP-space frame G (numpy 4x4, the gun's Roblox gun space)."""
    root_obj.matrix_world = r2b(G)
    bpy.context.view_layer.update()


def holds_to_json(path, gid, results, extra=None):
    """Write the solved holds (without the private evaluation data) as JSON."""
    data = {'id': gid, 'units': 'studs', 'space': 'Roblox; HRP space for gunInHRP, Torso space for gunInTorso, '
            'Right Arm space for weld (the gun\'s Roblox gun space frame: -Z muzzle, +X right, +Y up)',
            'hand': list(HAND), 'eye': list(EYE),
            'joints': 'degrees, CFrame.Angles(rx, ry, rz) order; Root also has (x, y, z) studs (R6Pose convention)',
            'stances': {}}
    for r in results:
        data['stances'][r['name']] = {k: v for k, v in r.items() if not k.startswith('_')}
    if extra:
        data.update(extra)
    with open(path, 'w') as f:
        json.dump(data, f, indent=1)
    return path
