"""
Takes the head's anatomy out of Z-Anatomy (https://www.z-anatomy.com,
CC BY-SA 4.0) for the bat finisher's burst head (tools/wounds/gore.py):
the bones of the skull, the brain, the lower jaw, the teeth, the eyes and the
top two vertebrae of the neck.

    venv/bin/python -I tools/wounds/extract_anatomy.py <Z-Anatomy/Startup.blend>

Also the liver (and its gallbladder) for the Boxer's finisher, and the right
lower ribs the hand breaks through, in the R6 torso's space.

    venv/bin/python -I tools/wounds/extract_anatomy.py --torso <Z-Anatomy/Startup.blend>

writes tools/wounds/anatomy/torso.npz instead (head.npz is left alone): the
chest the Sentinel's heat vision bores into over the heart (the heart's
ventricles and papillary muscles, the sternum, the left ribs and their
cartilage, the pectoral and intercostal muscles, the left lung), and the
belly and pelvis the Bull tears apart (lumbar vertebrae, the jejunum, the
colon, the abdominal and back muscles, the hip bones and the sacrum). All in
the R6 torso's space; each group cropped to a box of it (only what the
wounds show), then decimated. Curve objects (the jejunum is one) are taken
as their evaluated mesh.

Writes tools/wounds/anatomy/head.npz (small: decimated meshes, already in the
classic Roblox head's space, studs; the torso groups in the torso's space):
  X right of the character, Y up, Z toward the back (its face looks at -Z),
  origin = the head's centre. The skull is stretched to fill the classic
  head (it is wider and shorter than a real one).
Only needed again to change what is taken; gore.py reads the .npz.
"""

import re
import sys

import bpy  # noqa: I001 (first: it makes the other Blender modules importable)
import bmesh
import numpy as np
from mathutils import Vector

BLEND = sys.argv[-1]
TORSO = "--torso" in sys.argv
OUT = "tools/wounds/anatomy/torso.npz" if TORSO else "tools/wounds/anatomy/head.npz"

# name -> (pattern on Z-Anatomy object names, triangles to keep for ALL of
# them together, keep each object apart?)
GROUPS = {
    "cranium": (
        r"^(Frontal bone|Parietal bone\.[lr]|Occipital bone|Temporal bone\.[lr]|Sphenoid bone"
        r"|Zygomatic bone\.[lr]|Maxilla\.[lr]|Nasal bone\.[lr])$",
        16000,
        False,
    ),
    "brain": (
        r"(gyr|Insula|Midbrain|Lingula of cerebellum|Tonsil of cerebellum|Superior cerebellar peduncle)",
        14000,
        False,
    ),
    "mandible": (r"^Mandible$", 3500, False),
    "lowerteeth": (r"^Lower .*(incisor|canine|premolar|molar)", 2800, True),
    "upperteeth": (r"^Upper .*(incisor|canine|premolar|molar)", 2800, True),
    "sclera": (r"^Sclera\.[lr]$", 900, True),
    "iris": (r"^Anterior segment of eyeball\.[lr]$", 400, True),
    "vertebrae": (r"^(Atlas \(C1\)|Axis \(C2\))$", 2400, False),
    # (torso space)
    "liver": (r"^Liver$", 2400, False),
    "gallbladder": (r"^Gallbladder$", 300, False),
    "ribs": (r"^(Eighth|Ninth|Tenth) rib\.r$|^Costal cartilage of (eighth|ninth) rib\.r$", 5000, True),
}
TORSO_GROUPS = {"liver", "gallbladder", "ribs"}

# torso.npz: name -> (pattern, triangles, apart?, crop box in torso space or
# None). The box keeps the faces with a corner in it (before decimating: the
# triangles go where the wound is).
CHEST = ((-0.62, -0.02, -0.62), (0.22, 0.72, 0.16))  # round the heart
BELLY = ((-1.2, -1.32, -0.7), (1.2, -0.42, 0.7))  # the waist, where the Bull tears
PELVIS = ((-1.2, -1.3, -0.7), (1.2, -0.6, 0.7))  # the top of the pelvis
TORSO_SET = {
    # (the Sentinel: the bore over the heart, the character's left)
    "rventricle": (r"^Right ventricle$", 3000, False, CHEST),
    "lventricle": (r"^Left ventricle$", 3000, False, CHEST),
    "papillary": (r"^(Anterior|Septal|Inferior) papillary muscle of (right|left) ventricle$", 1600, False, CHEST),
    "sternum": (r"^Body of sternum$", 1600, False, CHEST),
    "chestribs": (r"^(Third|Fourth|Fifth|Sixth) rib\.l$", 3200, True, CHEST),
    "cartilage": (r"^Costal cartilage of (third|fourth|fifth|sixth) rib\.l$", 2000, True, CHEST),
    "pectoral": (
        r"^(Sternocostal head of pectoralis major muscle|\(Abdominal part of pectoralis major muscle\))\.l$",
        2400,
        False,
        CHEST,
    ),
    "intercostal": (r"^Internal intercostal muscles\.l$", 2400, False, CHEST),
    "lung": (r"^(Superior|Inferior) lobe of left lung$", 1800, False, CHEST),
    # (the Bull: torn in two at the waist)
    "lumbar": (r"^Vertebra L[345]$", 3600, True, None),
    "disc": (r"^Intervertebral disc L[34]-L[45]$", 800, True, None),
    "jejunum": (r"^Jejunum$", 6000, False, None),
    "colon": (r"^(Ascending|Descending|Sigmoid|Transverse) colon$", 2400, True, None),
    "abdominal": (
        r"^(Rectus abdominis muscle|External abdominal oblique muscle|Internal abdominal oblique muscle"
        r"|Transversus abdominis muscle)\.[lr]$",
        5000,
        True,
        BELLY,
    ),
    "back": (
        r"^(Psoas major|Quadratus lumborum muscle|Iliocostalis lumborum muscle|Longissimus thoracis muscle"
        r"|Multifidus lumborum muscle)\.[lr]$",
        4000,
        True,
        BELLY,
    ),
    "hipbone": (r"^Hip bone\.[lr]$", 3200, True, PELVIS),
    "sacrum": (r"^Sacrum$", 1600, False, PELVIS),
}

# The real head (Z-Anatomy, metres, Z up, -Y = the face) -> the classic
# head (1.2 studs; the skull a little inside it, under the skin).
CENTER = Vector((0.0, -0.007, 1.6005))
SCALE = Vector((7.5, 5.3, 5.1))  # across, up, front-back


# The real torso -> the R6 torso (2 x 2 x 1 studs, its centre the origin).
TORSO_CENTER = Vector((0.0, -0.01, 1.2))
TORSO_SCALE = Vector((5.9, 4.0, 4.5))  # across, up, front-back


def to_torso(p):
    d = p - TORSO_CENTER
    return (-d.x * TORSO_SCALE.x, d.z * TORSO_SCALE.y, d.y * TORSO_SCALE.z)


def to_head(p):
    d = p - CENTER
    # anatomical right (x < 0) -> the character's right (+X); up -> Y; front (-y) -> -Z
    return (-d.x * SCALE.x, d.z * SCALE.y, d.y * SCALE.z)


def crop_to_torso(mesh, box):
    """The mesh (world, metres) -> torso space; only the faces with a corner
    in `box` (torso space) kept."""
    for v in mesh.vertices:
        v.co = Vector(to_torso(v.co))
    # (to_torso turns and scales by positive numbers: the faces keep their side)
    if box is None:
        return mesh
    lo, hi = box
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    inside = [all(lo[k] <= v.co[k] <= hi[k] for k in range(3)) for v in bm.verts]
    gone = [f for f in bm.faces if not any(inside[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def extract_torso():
    """torso.npz (see TORSO_SET)."""
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    arrays = {}
    for group, (pattern, budget, apart, box) in TORSO_SET.items():
        rx = re.compile(pattern)
        found = []
        for ob in bpy.data.objects:
            # (curves too: the jejunum is a curve with a bevel - its mesh)
            if ob.type not in ("MESH", "CURVE") or not rx.search(ob.name):
                continue
            evaluated = ob.evaluated_get(depsgraph)
            mesh = evaluated.to_mesh().copy()
            evaluated.to_mesh_clear()
            mesh.transform(ob.matrix_world)
            crop_to_torso(mesh, box)
            if len(mesh.polygons):
                found.append((ob.name, mesh))
            else:
                bpy.data.meshes.remove(mesh)
        if not found:
            raise SystemExit(f"nothing found for {group} ({pattern})")
        for _n, mesh in found:
            mesh.calc_loop_triangles()
        total = sum(len(m.loop_triangles) for _n, m in found) or 1  # (the budget is in triangles)
        meshes = []
        for name, mesh in found:
            temp = bpy.data.objects.new("tmp", mesh)
            bpy.context.scene.collection.objects.link(temp)
            temp.modifiers.new("t", "TRIANGULATE")
            dec = temp.modifiers.new("d", "DECIMATE")
            dec.ratio = min(1.0, budget / total)
            done = temp.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
            done.calc_loop_triangles()
            v = np.array([tuple(vx.co) for vx in done.vertices], dtype=np.float32)
            f = np.array([tuple(t.vertices) for t in done.loop_triangles], dtype=np.int32)
            bpy.data.objects.remove(temp)
            if len(f):
                meshes.append((name, v, f))
        if not apart and meshes:
            base = 0
            vs, fs = [], []
            for _n, v, f in meshes:
                vs.append(v)
                fs.append(f + base)
                base += len(v)
            meshes = [(group, np.vstack(vs), np.vstack(fs))]
        for index, (name, v, f) in enumerate(meshes):
            arrays[f"{group}__{index}__v"] = v
            arrays[f"{group}__{index}__f"] = f
            print(group, index, name, len(v), "verts", len(f), "tris")
    np.savez_compressed(OUT, **arrays)
    print("wrote", OUT)


def main():
    if TORSO:
        extract_torso()
        return
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    arrays = {}
    for group, (pattern, budget, apart) in GROUPS.items():
        rx = re.compile(pattern, re.I)
        found = []
        for ob in bpy.data.objects:
            if ob.type != "MESH" or not rx.search(ob.name):
                continue
            world = ob.matrix_world
            if group not in TORSO_GROUPS and min((world @ Vector(c)).z for c in ob.bound_box) < 1.45:
                continue  # (the brain pattern: only what is in the head)
            mesh = ob.evaluated_get(depsgraph).to_mesh().copy()
            mesh.transform(world)
            found.append((ob.name, mesh))
        total = sum(len(m.polygons) for _n, m in found) or 1
        meshes = []
        for name, mesh in found:
            temp = bpy.data.objects.new("tmp", mesh)
            bpy.context.scene.collection.objects.link(temp)
            # (triangles first: Z-Anatomy has n-gons)
            tri = temp.modifiers.new("t", "TRIANGULATE")
            dec = temp.modifiers.new("d", "DECIMATE")
            dec.ratio = min(1.0, budget / total)
            evaluated = temp.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
            evaluated.calc_loop_triangles()
            place = to_torso if group in TORSO_GROUPS else to_head
            v = np.array([place(vx.co) for vx in evaluated.vertices], dtype=np.float32)
            f = np.array([tuple(t.vertices) for t in evaluated.loop_triangles], dtype=np.int32)
            temp.modifiers.remove(tri)
            temp.modifiers.remove(dec)
            if len(f):
                meshes.append((name, v, f))
        if not apart and meshes:
            base = 0
            vs, fs = [], []
            for _n, v, f in meshes:
                vs.append(v)
                fs.append(f + base)
                base += len(v)
            meshes = [(group, np.vstack(vs), np.vstack(fs))]
        for index, (name, v, f) in enumerate(meshes):
            arrays[f"{group}__{index}__v"] = v
            arrays[f"{group}__{index}__f"] = f
            print(group, index, name, len(v), "verts", len(f), "tris")
    np.savez_compressed(OUT, **arrays)
    print("wrote", OUT)


main()
