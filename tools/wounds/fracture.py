"""
The open fractures of the heavy hits, from the real forearm and shin of
Z-Anatomy (CC BY-SA 4.0, via extract_limbs.py -> anatomy/limbs.npz). Used by
build_wound_kit.py (build_break: the "Break" inserts) - the game opens the
limb's skin and puts the insert in the hole (src/client/Combat/Gashes).

What a real open fracture of the forearm / the shin looks like: the two
bones snapped across their shafts, obliquely, the broken ends jagged and
sharp - the hard white cortex round the dark red marrow of the bone's
cavity - the fragments angulated so that one broken end has gone through
the muscles and out of a torn hole in the skin, smeared with blood, shreds
of muscle and periosteum on it; in the hole the torn muscles, the yellow
fat under the skin, torn vessels and nerves, clotted blood.

Here the bones are the real ones (their real shape, their real place in the
limb), broken with a jagged fracture surface (a boolean with a cutter whose
face is the fracture: oblique, toothed, a little different on each side),
the middle of their broken ends (inside the cortex: a thick solid ring) sunk
in and drawn as the marrow (Marrow); the muscles, vessels and nerves are the real ones too.

Insert axes (as every wound insert): X along the skin (the limb's -X), Y up,
Z out of the skin (the limb's -Z), the skin at Z = 0, the origin the point
BREAK_AT of the limb's front face.
"""

import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

import gore

LIMBS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "anatomy", "limbs.npz")

# Where each insert sits on the R6 right limb's front face (limb space X, Y:
# extract_limbs.py's LIMBS "y" is the break's height). The game places them
# at exactly these points (Shared/Util/HeavyGore BREAK_AT, the left limbs
# mirrored).
BREAK_AT = {"arm": (0.06, -0.3), "leg": (-0.1, -0.35)}


def to_insert(v, limb):
    """R6 right limb space -> the insert's axes (numpy, n x 3)."""
    x0, y0 = BREAK_AT[limb]
    return np.column_stack([-(v[:, 0] - x0), v[:, 1] - y0, -(v[:, 2] + 0.5)]).astype(np.float64)


def load(limb):
    """{"bone": [bmesh], "muscle": [...], "vessel": [...]} of the limb, in the
    insert's axes."""
    data = np.load(LIMBS)
    out = {"bone": [], "muscle": [], "vessel": []}
    for group in out:
        index = 0
        while f"{limb}{group}__{index}__v" in data.files:
            v = to_insert(data[f"{limb}{group}__{index}__v"], limb)
            bm = gore.bm_of(v, data[f"{limb}{group}__{index}__f"])
            if group == "bone":
                gore.cut(bm, [], fill=True)  # (closed: its ends were cropped)
            out[group].append(bm)
            index += 1
    return out


# --- Booleans ----------------------------------------------------------------
def _object(bm, name, material):
    for f in bm.faces:  # (one material: what an earlier boolean left is reset)
        f.material_index = 0
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    mesh.materials.append(bpy.data.materials.get(material) or bpy.data.materials.new(material))
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def boolean(bm, cutter, operation="INTERSECT"):
    """bm (op) cutter, exact. Returns (bmesh, set of the face indices that
    come from the cutter: the new cut surface)."""
    a = _object(bm, "frac_a", "frac_keep")
    b = _object(cutter, "frac_b", "frac_cut")
    mod = a.modifiers.new("b", "BOOLEAN")
    mod.operation = operation
    mod.solver = "EXACT"
    mod.object = b
    mod.material_mode = "TRANSFER"
    mod.use_self = True
    evaluated = a.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    names = [m.name if m else "" for m in mesh.materials]
    out = bmesh.new()
    out.from_mesh(mesh)
    cut_faces = {f.index for f in out.faces if f.material_index < len(names) and names[f.material_index] == "frac_cut"}
    evaluated.to_mesh_clear()
    for ob in (a, b):
        data = ob.data
        bpy.data.objects.remove(ob)
        bpy.data.meshes.remove(data)
    out.normal_update()
    return out, cut_faces


def solid(bm, voxel=0.008, tris=6000):
    """The bone made one clean closed surface (voxel remesh: Z-Anatomy's
    meshes have holes and stray faces, which the booleans can't take),
    smooth, about `tris` triangles."""
    mesh = bpy.data.meshes.new("tmp")
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new("tmp", mesh)
    bpy.context.scene.collection.objects.link(ob)
    remesh = ob.modifiers.new("r", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    smooth = ob.modifiers.new("s", "SMOOTH")
    smooth.iterations = 2
    smooth.factor = 0.5
    evaluated = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    out = bmesh.new()
    out.from_mesh(evaluated)
    bmesh.ops.triangulate(out, faces=out.faces[:])
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(mesh)
    out = gore.decimate(out, tris)
    bmesh.ops.triangulate(out, faces=out.faces[:])
    out.normal_update()
    return out


# --- The fracture surface ------------------------------------------------------
class Fracture:
    """The fracture's surface across a bone: y = height(x, z). Oblique
    (rising toward `toward`, `slope` = tan of its angle to the shaft's
    cross-section), toothed (sharp ridges and teeth), with a long spike on
    its high side (where long bones break into a point)."""

    def __init__(self, rng, y, centre, radius, toward, slope):
        self.y = y
        self.centre = Vector((centre.x, 0, centre.z))
        self.radius = radius
        self.toward = Vector((toward.x, 0, toward.z)).normalized()
        self.slope = slope
        self.seed = Vector((rng.uniform(0, 90), rng.uniform(0, 90), rng.uniform(0, 90)))
        self.spike = rng.uniform(-0.6, 0.6)  # where across the high side the spike is

    def height(self, x, z, side=0.0):
        """`side`: another draw of its fine teeth (the two fragments don't
        fit exactly: crumbs of bone were lost)."""
        p = Vector((x, 0, z)) - self.centre
        r = self.radius
        # -1 .. 1 across the bone (held there past it: the surface stays
        # level round the bone, never reaching up the shaft)
        along = max(-1.2, min(1.2, p.dot(self.toward) / r))
        across = max(-1.5, min(1.5, p.cross(Vector((0, 1, 0))).dot(self.toward) / r))
        h = self.slope * along * r
        q = Vector((x * 9 / r, z * 9 / r, side * 7)) + self.seed
        ridge = 1 - 2 * abs(noise.noise(q * 0.22))  # a few sharp ridges
        h += r * (0.2 * ridge + 0.08 * noise.noise(q * 0.7) + 0.025 * noise.noise(q * 2.2))
        # the spike: up on the high side, narrow across it
        spike = max(0.0, along - 0.15) ** 1.6 * max(0.0, 1 - abs(across - self.spike) / 0.7)
        h += r * 0.45 * spike
        return self.y + h

    def cutter(self, lo, hi, upper, side=0.0, gap=0.0, step=None):
        """A closed solid whose face toward the bone is the fracture surface
        (upper: above it, else below it) over x in lo.x..hi.x, z in
        lo.z..hi.z."""
        step = step or self.radius / 9
        nx = max(4, int((hi.x - lo.x) / step))
        nz = max(4, int((hi.z - lo.z) / step))
        far = self.y + (6.0 if upper else -6.0)
        bm = bmesh.new()
        grid = []
        for i in range(nx + 1):
            row = []
            for k in range(nz + 1):
                x = lo.x + (hi.x - lo.x) * i / nx
                z = lo.z + (hi.z - lo.z) * k / nz
                y = self.height(x, z, side) + (gap if upper else -gap)
                row.append(bm.verts.new((x, y, z)))
            grid.append(row)
        cap = [[bm.verts.new((v.co.x, far, v.co.z)) for v in row] for row in grid]
        for i in range(nx):
            for k in range(nz):
                bm.faces.new((grid[i][k], grid[i + 1][k], grid[i + 1][k + 1], grid[i][k + 1]))
                bm.faces.new((cap[i][k], cap[i][k + 1], cap[i + 1][k + 1], cap[i + 1][k]))
        border = ([grid[i][0] for i in range(nx + 1)] + [grid[nx][k] for k in range(1, nz + 1)]
                  + [grid[i][nz] for i in range(nx - 1, -1, -1)] + [grid[0][k] for k in range(nz - 1, 0, -1)])
        border_cap = ([cap[i][0] for i in range(nx + 1)] + [cap[nx][k] for k in range(1, nz + 1)]
                      + [cap[i][nz] for i in range(nx - 1, -1, -1)] + [cap[0][k] for k in range(nz - 1, 0, -1)])
        n = len(border)
        for j in range(n):
            m = (j + 1) % n
            bm.faces.new((border[j], border[m], border_cap[m], border_cap[j]))
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        return bm


def section(bm, y, band):
    """The bone's cross-section round height y: (its middle, its radius, its
    lower and upper corners in X-Z)."""
    pts = [v.co for v in bm.verts if abs(v.co.y - y) < band]
    if not pts:
        pts = sorted((v.co for v in bm.verts), key=lambda c: abs(c.y - y))[:40]
    xs, zs = [p.x for p in pts], [p.z for p in pts]
    centre = Vector(((min(xs) + max(xs)) / 2, y, (min(zs) + max(zs)) / 2))
    radius = max(max(xs) - min(xs), max(zs) - min(zs)) / 2
    return centre, radius, Vector((min(xs), 0, min(zs))), Vector((max(xs), 0, max(zs)))


def canal(bone, ratio):
    """The bone's marrow canal: the bone itself shrunk toward the middle of
    each of its cross-sections (the cortex all round it)."""
    inner = bone.copy()
    lo = min(v.co.y for v in bone.verts)
    step = 0.03
    bins = {}
    for v in bone.verts:
        bins.setdefault(int((v.co.y - lo) / step), []).append(v.co)
    middles = {k: sum(pts, Vector()) / len(pts) for k, pts in bins.items()}

    def middle(y):
        # (between two sections' middles: no steps, no folds)
        f = (y - lo) / step - 0.5
        k = int(math.floor(f))
        a, b = middles.get(k), middles.get(k + 1)
        if a is None or b is None:
            return a or b
        return a.lerp(b, f - k)

    for v in inner.verts:
        c = middle(v.co.y)
        if c is not None:
            v.co = Vector((c.x + (v.co.x - c.x) * ratio, v.co.y, c.z + (v.co.z - c.z) * ratio))
    inner.normal_update()
    return inner


def recessed(fragment, cut_faces, canal_tree, upper, sink, radius):
    """The marrow at a broken end: the middle of the fragment's fracture
    surface (what is inside the canal) sunk `sink` into the bone, smoothly
    (the cortex round it stays: a thick solid ring, no thin shell). Returns
    the marrow: a copy of that sunk middle a hair out of it (dark red)."""
    fragment.faces.ensure_lookup_table()
    cut = [fragment.faces[i] for i in cut_faces]
    into = Vector((0, 1 if upper else -1, 0))
    soft = radius * 0.18  # (the cortex's inner edge: no step)
    weight = {}
    for face in cut:
        for v in face.verts:
            if v in weight:
                continue
            w = 0.0
            if inside(canal_tree, v.co):
                hit = canal_tree.find_nearest(v.co)
                distance = (hit[0] - v.co).length if hit[0] is not None else soft
                w = min(1.0, distance / soft)
            weight[v] = w
    for v, w in weight.items():
        v.co += into * sink * (w * w * (3 - 2 * w))
    fragment.normal_update()
    marrow = bmesh.new()
    lookup = {}
    for face in cut:
        if min(weight[v] for v in face.verts) < 0.25:
            continue
        verts = []
        for v in face.verts:
            if v not in lookup:
                lookup[v] = marrow.verts.new(v.co - into * 0.002)
            verts.append(lookup[v])
        try:
            marrow.faces.new(verts)
        except ValueError:
            pass
    marrow.normal_update()
    return marrow


def break_bone(bone, rng, y, slope, toward, cortex, sink, gap=0.012):
    """The real bone `bone` (insert axes, along Y, a closed solid) broken at
    height y: (upper fragment, its marrow, lower fragment, its marrow, the
    fracture). `cortex`: how much of the bone's half width is its hard wall
    (the marrow shows inside it, sunk `sink`)."""
    centre, radius, lo, hi = section(bone, y, 0.04)
    fracture = Fracture(rng, y, centre, radius, toward, slope)
    margin = Vector((radius * 1.6, 0, radius * 1.6))
    lo, hi = lo - margin, hi + margin
    inner = canal(bone, 1 - cortex)
    canal_tree = BVHTree.FromBMesh(inner)
    # (a fine cutter: the marrow's edge on it is smooth)
    step = radius / 16
    upper, upper_cut = boolean(bone, fracture.cutter(lo, hi, True, 0.0, gap / 2, step))
    lower, lower_cut = boolean(bone, fracture.cutter(lo, hi, False, 1.0, gap / 2, step))
    upper_marrow = recessed(upper, upper_cut, canal_tree, True, sink, radius)
    lower_marrow = recessed(lower, lower_cut, canal_tree, False, sink, radius)
    inner.free()
    return upper, upper_marrow, lower, lower_marrow, fracture


def pivot(bms, axis_point, angle, axis="X"):
    """Turns the meshes about a line through `axis_point`."""
    m = Matrix.Translation(axis_point) @ Matrix.Rotation(angle, 4, axis) @ Matrix.Translation(-axis_point)
    for bm in bms:
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
        bm.normal_update()


def splinter(bone, rng, near, size):
    """A shard of the real bone's wall near `near`: the bone cut by a few
    random planes round a point of its surface (curved outside, sharp
    edges)."""
    tree = BVHTree.FromBMesh(bone)
    hit = tree.find_nearest(near)
    at = hit[0] if hit[0] is not None else near
    planes = []
    # (round every way: the six sides of a box, each turned at random)
    for axis in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))):
        for sign in (1, -1):
            d = (axis * sign + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5))))
            d.normalize()
            planes.append((at + d * size * rng.uniform(0.5, 1.0) * (1.8 if axis.y else 1.0), d))
    return gore.cut(bone.copy(), planes, fill=True)


def blood_film(bm, rng, keep, offset=0.004, threshold=0.0):
    """Blood smeared on a surface: where `keep(point)`, in patches (a noise
    over `threshold`), a film a hair out of it. (The surface is cut finer
    first: the patches' edges are smooth, not the big faces'.)"""
    src = bmesh.new()
    lookup = {}
    for face in bm.faces:
        if not keep(face.calc_center_median()):
            continue
        verts = []
        for v in face.verts:
            if v not in lookup:
                lookup[v] = src.verts.new(v.co)
            verts.append(lookup[v])
        try:
            src.faces.new(verts)
        except ValueError:
            pass
    for _ in range(2):
        bmesh.ops.subdivide_edges(src, edges=src.edges[:], cuts=1, use_grid_fill=True)
        bmesh.ops.triangulate(src, faces=src.faces[:])
    src.normal_update()
    seed = Vector((rng.uniform(0, 50), rng.uniform(0, 50), rng.uniform(0, 50)))
    # (it runs down: patches longer along Y)
    # (`keep` again on the finer faces: a big face of the bone half in it
    # leaves nothing outside it)
    gone = [f for f in src.faces
            if not keep(f.calc_center_median())
            or noise.noise(Vector((1, 0.35, 1)) * f.calc_center_median() * 9 + seed) < threshold]
    bmesh.ops.delete(src, geom=gone, context="FACES")
    for v in src.verts:
        v.co += v.normal * offset
    # (one side: it lies on the bone, seen from outside only)
    return gore.decimate(src, 3000) if len(src.faces) else src


def tree_of(bm):
    return BVHTree.FromBMesh(bm)


def inside(tree, p, direction=Vector((0.0, 0.0, 1.0))):
    """Is p inside the closed mesh of `tree` (odd number of crossings)?"""
    count, o = 0, p.copy()
    for _ in range(64):
        hit = tree.ray_cast(o, direction, 4.0)
        if hit[0] is None:
            break
        count += 1
        o = hit[0] + direction * 1e-5
    return count % 2 == 1


def polygon_contains(pts, x, y):
    """Is (x, y) inside the closed outline `pts` (Vectors)?"""
    ok, j = False, len(pts) - 1
    for i in range(len(pts)):
        a, b = pts[i], pts[j]
        if (a.y > y) != (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y + 1e-12) + a.x:
            ok = not ok
        j = i
    return ok

