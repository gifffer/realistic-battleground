"""
Takes the anatomy round the hips out of Z-Anatomy (https://www.z-anatomy.com,
CC BY-SA 4.0) for Dr. Rift's finisher (PortalCut: the body cut in two at the
waist, tools/wounds/gore.py "Waist" / "HipR" / "HipL" / "Gut<i>"):

    venv/bin/python -I tools/wounds/extract_waist.py <z-anatomy>/Resources/Models/FBX

(the folder holding SkeletalSystem100.fbx, MuscularSystem100.fbx,
VisceralSystem100.fbx and CardioVascular41.fbx of the Z-Anatomy repository:
https://github.com/LluisV/z-anatomy)

The cut plane. The R6 torso's bottom face (torso space Y = -1) falls, with
the torso mapping of extract_arm.py (TORSO_CENTER / TORSO_SCALE), at 0.95 m
on the Z-Anatomy body: the top of the sacrum and the iliac wings only, above
the hip joints - no femur, no bladder, empty belly. The R6 legs start there,
so the real cut is moved down to the hip joints: CUT_Z = 0.875 m, where the
plane goes through
  - both hip bones round the acetabulum (the socket) and the apex of the
    sacrum,
  - the upper half of both femoral heads (the femur's neck just below),
  - the iliopsoas (iliacus, psoas major), the three glutei, piriformis,
    obturator internus, sartorius, rectus femoris, tensor fasciae latae,
    the lowest abdominal wall (rectus abdominis, obliques, transversus),
  - the urinary bladder, the sigmoid colon (the small intestine's lowest
    loops just above),
  - the femoral arteries and veins (the external iliacs just above).
Everything is written in R6 TORSO space (studs: X = the character's right,
Y up, Z to the back) with CUT_Z on Y = -1: Y = (z - CUT_Z) * 4 - 1.

Writes tools/wounds/anatomy/waist.npz ("<group>__<i>__v" float32 vertices,
"<group>__<i>__f" int32 triangles; "<group>__<i>__n" the object's name):
  bone<i>     hip bones, sacrum, coccyx, femurs (a slab round the plane)
  muscle<i>   each muscle on its own (alternating colours), both sides
  gut<i>      bladder, sigmoid colon, the lowest small intestine, descending
              colon (slab)
  vessel<i>   femoral / external iliac arteries and veins, the gluteal,
              pudendal, obturator and circumflex vessels (slab)
  jejunum0    the whole small intestine (its own space: centred, studs, the
              same torso scale), for the loose loops falling out
Only needed again to change what is taken; gore.py reads the .npz.
"""

import os
import sys

import bpy
import numpy as np
from mathutils import Vector

FOLDER = sys.argv[-1]
OUT = "tools/wounds/anatomy/waist.npz"

CUT_Z = 0.875  # metres (see above)
SLAB = (CUT_Z - 0.07, CUT_Z + 0.08)  # what is kept round it (metres)
HALF_WIDTH = 0.18  # |x| (metres): the hips (not the hands hanging beside)
# The real torso -> the R6 torso (extract_arm.py), the cut on Y = -1.
TORSO_CENTER = Vector((0.0, -0.01, 1.2))
TORSO_SCALE = Vector((5.9, 4.0, 4.5))

SIDES = (".r", ".l")
BONES = ["Hip bone.r", "Hip bone.l", "Sacrum", "Coccyx", "Femur.r", "Femur.l"]
MUSCLES = [
    "Gluteus maximus muscle", "Gluteus medius muscle", "Gluteus minimus muscle",
    "Iliacus muscle", "Psoas major", "Obturator internus", "Obturator externus",
    "Piriformis muscle", "Tensor fasciae latae", "Sartorius muscle", "Rectus femoris muscle",
    "Coccygeus muscle", "Superior gemellus muscle", "Inferior gemellus muscle",
    "Pectineus muscle", "Adductor longus", "Adductor brevis", "Quadratus femoris muscle",
    "Vastus lateralis muscle", "Iliococcygeus muscle", "Pubococcygeus muscle",
    "Rectus abdominis muscle", "Transversus abdominis muscle",
    "Internal abdominal oblique muscle", "External abdominal oblique muscle", "Pyramidalis muscle",
]
GUT = ["Urinary bladder", "Sigmoid colon", "Jejunum", "Descending colon"]
VESSELS = [
    "Femoral artery", "Femoral vein", "External iliac artery", "External iliac vein",
    "Inferior gluteal artery", "Internal pudendal artery", "Obturator artery",
    "Medial circumflex femoral artery", "Lateral circumflex femoral artery",
]
BUDGET = {"bone": 1400, "muscle": 520, "gut": 1100, "vessel": 160}


def to_torso(p):
    """anatomical metres (Z up, -Y = front, x < 0 = its right) -> R6 torso
    studs, the cut plane on Y = -1"""
    return (-(p[0] - TORSO_CENTER.x) * TORSO_SCALE.x,
            (p[2] - CUT_Z) * TORSO_SCALE.y - 1.0,
            (p[1] - TORSO_CENTER.y) * TORSO_SCALE.z)


def world_mesh(name):
    """(vertices N x 3 metres, triangles M x 3) of a Z-Anatomy object, whole."""
    ob = bpy.data.objects[name]
    mesh = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh().copy()
    mesh.transform(ob.matrix_world)
    mesh.calc_loop_triangles()
    v = np.array([tuple(x.co) for x in mesh.vertices], dtype=np.float64)
    f = np.array([tuple(t.vertices) for t in mesh.loop_triangles], dtype=np.int64)
    bpy.data.meshes.remove(mesh)
    return v, f


def clip(v, f, keep):
    """The triangles whose 3 corners pass `keep` (a mask on the vertices)."""
    tris = f[keep[f].all(1)]
    used = np.unique(tris)
    remap = np.full(len(v), -1, dtype=np.int64)
    remap[used] = np.arange(len(used))
    return v[used], remap[tris]


def decimate(v, f, budget):
    if len(f) <= budget:
        return v, f
    mesh = bpy.data.meshes.new("tmp")
    mesh.from_pydata(v.tolist(), [], f.tolist())
    ob = bpy.data.objects.new("tmp", mesh)
    bpy.context.scene.collection.objects.link(ob)
    dec = ob.modifiers.new("d", "DECIMATE")
    dec.ratio = budget / len(f)
    ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    ev.calc_loop_triangles()
    out_v = np.array([tuple(x.co) for x in ev.vertices], dtype=np.float64)
    out_f = np.array([tuple(t.vertices) for t in ev.loop_triangles], dtype=np.int64)
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(mesh)
    return out_v, out_f


def slab(name, budget):
    v, f = world_mesh(name)
    keep = (v[:, 2] > SLAB[0]) & (v[:, 2] < SLAB[1]) & (np.abs(v[:, 0]) < HALF_WIDTH)
    v, f = clip(v, f, keep)
    if len(f) == 0:
        return None
    return decimate(v, f, budget)


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)


def main():
    arrays = {}
    counts = {}

    def put(group, name, vf):
        if vf is None:
            print("  (nothing of", name, "in the slab)")
            return
        v, f = vf
        index = counts.get(group, 0)
        counts[group] = index + 1
        arrays[f"{group}__{index}__v"] = np.array([to_torso(p) for p in v], dtype=np.float32)
        arrays[f"{group}__{index}__f"] = f.astype(np.int32)
        arrays[f"{group}__{index}__n"] = np.array(name)
        print(f"  {group}{index}: {name}, {len(f)} triangles")

    def names(base):
        if base in bpy.data.objects:
            return [base]
        found = [base + s for s in SIDES if base + s in bpy.data.objects]
        if not found:
            print("  MISSING:", base)
        return found

    print(f"cut plane: z = {CUT_Z} m (the R6 torso's bottom by the torso mapping: "
          f"{TORSO_CENTER.z - 1.0 / TORSO_SCALE.y:.3f} m, above the hip joints)")
    load(os.path.join(FOLDER, "SkeletalSystem100.fbx"))
    for name in BONES:
        put("bone", name, slab(name, BUDGET["bone"]))
    load(os.path.join(FOLDER, "MuscularSystem100.fbx"))
    for base in MUSCLES:
        for name in names(base):
            put("muscle", name, slab(name, BUDGET["muscle"]))
    load(os.path.join(FOLDER, "VisceralSystem100.fbx"))
    for name in GUT:
        put("gut", name, slab(name, BUDGET["gut"]))
    # the whole small intestine, centred (its own space), same scale
    v, f = world_mesh("Jejunum")
    v, f = decimate(v, f, 5000)
    t = np.array([to_torso(p) for p in v], dtype=np.float64)
    t -= (t.min(0) + t.max(0)) / 2
    arrays["jejunum__0__v"] = t.astype(np.float32)
    arrays["jejunum__0__f"] = f.astype(np.int32)
    arrays["jejunum__0__n"] = np.array("Jejunum")
    print(f"  jejunum0: whole, {len(f)} triangles, size {np.round(t.max(0) - t.min(0), 2)}")
    load(os.path.join(FOLDER, "CardioVascular41.fbx"))
    for base in VESSELS:
        for name in names(base):
            put("vessel", name, slab(name, BUDGET["vessel"]))
    np.savez_compressed(OUT, **arrays)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")


main()
