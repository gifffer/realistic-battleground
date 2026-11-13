"""
Takes the bones and muscles of the right forearm, thigh, shin and hip out of
Z-Anatomy (https://www.z-anatomy.com, CC BY-SA 4.0) for the heavy hits' gore
(tools/wounds/gore.py: a leg torn off at the hip, open fractures):

    venv/bin/python -I tools/wounds/extract_limbs.py <Z-Anatomy/Startup.blend>

Writes tools/wounds/anatomy/limbs.npz (small: decimated meshes, studs; X right
of the character, Y up, Z toward the back):
  forearm    the radius and the ulna (one mesh), scaled by BONE_SCALE, their
             middle the origin (where they snap), along Y
  shin       the tibia and the fibula, the same
  femur      the whole right femur in the R6 right leg (1 x 2 x 1, its top
             at Y = 1), its head LEG_HEAD_OUT studs out of the top (pulled
             out of the hip with the leg)
  thighmuscle<i>  the real muscles of the thigh (quadriceps, hamstrings,
             adductors, sartorius, gracilis) placed with the femur, widened
             to fill the blocky leg: the torn top shows their cut
  hipbone    the right hip bone round its socket (acetabulum), R6 torso
             space, the socket's middle at (0.5, -1, 0) (over the leg's top)
  hipmuscle<i>  the muscles that stay on the body round the hip joint
             (glutei, iliopsoas, pectineus, the tops of the adductors...),
             placed with it
Only needed again to change what is taken; gore.py reads the .npz.
"""

import re
import sys

import bpy  # noqa: I001 (first: it makes the other Blender modules importable)
import numpy as np
from mathutils import Vector

BLEND = sys.argv[-1]
OUT = "tools/wounds/anatomy/limbs.npz"

BONE_SCALE = 5.5  # studs per metre for the snapped bones: thick enough to read
LEG_SCALE = 5.0  # the femur and the thigh in the leg (uniform)
THIGH_CUT = 0.80  # metres up: where the leg's top tears (just under the groin)
ACROSS = 1.2  # the thigh's muscles widened across to fill the block
HIP_REACH = 0.11  # metres round the femur's head kept of the hip (bone, muscles)

THIGH_MUSCLES = (
    r"^(Rectus femoris muscle|Vastus lateralis muscle|Vastus medialis muscle|Vastus intermedius muscle"
    r"|Sartorius muscle|Gracilis muscle|Adductor longus|Adductor brevis|Adductor magnus|Long head of biceps femoris"
    r"|Semitendinosus muscle|Semimembranosus muscle|Tensor fasciae latae)\.r$"
)
HIP_MUSCLES = (
    r"^(Gluteus maximus muscle|Gluteus medius muscle|Gluteus minimus muscle|Iliacus muscle|Psoas major"
    r"|Pectineus muscle|Quadratus femoris muscle|Adductor longus|Adductor brevis|Rectus femoris muscle"
    r"|Sartorius muscle|Tensor fasciae latae)\.r$"
)

# The real torso -> the R6 torso (as extract_anatomy.py).
TORSO_CENTER = Vector((0.0, -0.01, 1.2))
TORSO_SCALE = Vector((5.9, 4.0, 4.5))


def to_char(p):
    """anatomical (metres, Z up, -Y = front, x < 0 = its right) -> character axes"""
    return np.array((-p[0], p[2], p[1]))


def to_torso(p):
    d = p - TORSO_CENTER
    return (-d.x * TORSO_SCALE.x, d.z * TORSO_SCALE.y, d.y * TORSO_SCALE.z)


def world_mesh(ob, budget):
    """The object's mesh in world space, decimated to about `budget` triangles:
    (vertices as Vectors, triangles)."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = ob.evaluated_get(depsgraph).to_mesh().copy()
    mesh.transform(ob.matrix_world)
    temp = bpy.data.objects.new("tmp", mesh)
    bpy.context.scene.collection.objects.link(temp)
    temp.modifiers.new("t", "TRIANGULATE")
    dec = temp.modifiers.new("d", "DECIMATE")
    dec.ratio = min(1.0, budget / max(1, len(mesh.polygons)))
    done = temp.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    done.calc_loop_triangles()
    v = [Vector(x.co) for x in done.vertices]
    f = np.array([tuple(t.vertices) for t in done.loop_triangles], dtype=np.int32).reshape(-1, 3)
    bpy.data.objects.remove(temp)
    return v, f


def keep(v, f, test):
    """Only the triangles with a corner passing `test` (re-indexed)."""
    ok = np.array([test(p) for p in v])
    tris = [t for t in f if ok[t[0]] or ok[t[1]] or ok[t[2]]]
    used = sorted({int(i) for t in tris for i in t})
    remap = {old: new for new, old in enumerate(used)}
    return [v[i] for i in used], np.array([[remap[int(i)] for i in t] for t in tris], dtype=np.int32).reshape(-1, 3)


def joined(names, budget):
    """Several objects in one (world, metres)."""
    vs, fs, base = [], [], 0
    for name in names:
        v, f = world_mesh(bpy.data.objects[name], budget)
        vs += v
        fs.append(f + base)
        base += len(v)
    return vs, np.vstack(fs)


def snapped_pair(names, budget):
    """Two bones side by side (character axes), scaled, their middle (between
    the ends, on the shafts' axis) at the origin."""
    v, f = joined(names, budget)
    c = np.array([to_char(p) for p in v])
    lo, hi = c[:, 1].min(), c[:, 1].max()
    mid = (lo + hi) / 2
    band = c[np.abs(c[:, 1] - mid) < 0.05]
    centre = np.array((band[:, 0].mean(), mid, band[:, 2].mean()))
    return ((c - centre) * BONE_SCALE).astype(np.float32), f


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    arrays = {}

    for key, names in (("forearm", ("Radius.r", "Ulna.r")), ("shin", ("Tibia.r", "Fibula.r"))):
        v, f = snapped_pair(names, 2400)
        arrays[f"{key}__0__v"], arrays[f"{key}__0__f"] = v, f

    # The femur in the leg: the thigh's middle at the tear (its muscles, not
    # the bone: the head sits to the inside, as in a real hip) at X = Z = 0.
    fv, ff = world_mesh(bpy.data.objects["Femur.r"], 3000)
    femur = np.array([to_char(p) for p in fv])
    muscles = []
    rx = re.compile(THIGH_MUSCLES)
    for ob in bpy.data.objects:
        if ob.type == "MESH" and rx.search(ob.name):
            mv, mf = world_mesh(ob, 1400)
            muscles.append((ob.name, np.array([to_char(p) for p in mv]), mf))
    every = np.vstack([m for _n, m, _f in muscles])
    band = every[np.abs(every[:, 1] - (THIGH_CUT - 0.03)) < 0.03]
    cx, cz = band[:, 0].mean(), band[:, 2].mean()

    def in_leg(c, across=1.0):
        return np.column_stack([
            (c[:, 0] - cx) * LEG_SCALE * across,
            (c[:, 1] - THIGH_CUT) * LEG_SCALE + 1.0,
            (c[:, 2] - cz) * LEG_SCALE * across,
        ]).astype(np.float32)

    arrays["femur__0__v"], arrays["femur__0__f"] = in_leg(femur), ff
    for index, (name, m, mf) in enumerate(muscles):
        arrays[f"thighmuscle__{index}__v"], arrays[f"thighmuscle__{index}__f"] = in_leg(m, ACROSS), mf
        print("thigh", index, name)

    # The hip: the femur's head (its middle) is the socket's middle.
    top = femur[:, 1].max()
    head = femur[femur[:, 1] > top - 0.035]
    head_c = Vector((-head[:, 0].mean(), head[:, 2].mean(), head[:, 1].mean()))  # (back to world)
    near = lambda p: (p - head_c).length < HIP_REACH  # noqa: E731
    socket = Vector(to_torso(head_c))
    shift = Vector((0.5, -1.0, 0.0)) - socket

    def in_torso(v):
        return np.array([tuple(Vector(to_torso(p)) + shift) for p in v], dtype=np.float32)

    hv, hf = world_mesh(bpy.data.objects["Hip bone.r"], 9000)
    hv, hf = keep(hv, hf, near)
    arrays["hipbone__0__v"], arrays["hipbone__0__f"] = in_torso(hv), hf
    rx = re.compile(HIP_MUSCLES)
    index = 0
    for ob in bpy.data.objects:
        if ob.type == "MESH" and rx.search(ob.name):
            mv, mf = world_mesh(ob, 1400)
            mv, mf = keep(mv, mf, near)
            if len(mf):
                arrays[f"hipmuscle__{index}__v"], arrays[f"hipmuscle__{index}__f"] = in_torso(mv), mf
                print("hip", index, ob.name)
                index += 1
    for key in sorted(arrays):
        if key.endswith("__v"):
            print(key, arrays[key].shape, arrays[key].min(0).round(2), arrays[key].max(0).round(2))
    np.savez_compressed(OUT, **arrays)
    print("wrote", OUT)


main()
