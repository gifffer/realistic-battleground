"""
Takes the bones, muscles, vessels and nerves of the right forearm, shin,
thigh and hip out of Z-Anatomy (https://www.z-anatomy.com, CC BY-SA 4.0) for
the heavy hits' gore (tools/wounds/gore.py: a leg torn off at the hip;
tools/wounds/fracture.py: the open fractures):

    venv/bin/python -I tools/wounds/extract_limbs.py <Z-Anatomy/Startup.blend>

Writes tools/wounds/anatomy/limbs.npz (small: decimated meshes, studs; X right
of the character, Y up, Z toward the back):
  armbone<i> / armmuscle<i> / armvessel<i>   the real right forearm in the
             R6 right arm (1 x 2 x 1, its centre the origin): the radius and
             the ulna (full detail: they are broken), every muscle of its
             front and back compartments, its arteries, veins and nerves.
             The forearm's axis along Y, its middle third round
             ARM_BREAK_Y; across, it fills the block (scaled in X and Z
             each, a little more than along it: the blocky arm is wide)
  legbone<i> / legmuscle<i> / legvessel<i>   the real right shin the same
             way in the R6 right leg (tibia, fibula; the muscles of its
             front, side and back compartments; its vessels and nerves),
             round LEG_BREAK_Y
  femur      the whole right femur in the R6 right leg (1 x 2 x 1, its top
             at Y = 1), its head LEG_HEAD_OUT studs out of the top (pulled
             out of the hip with the leg)
  thighmuscle<i>  the real muscles of the thigh (quadriceps, hamstrings,
             adductors, sartorius, gracilis) placed with the femur, widened
             to fill the blocky leg: the torn top shows their cut
  thighvessel<i>  the femoral artery and vein and the sciatic nerve, placed
             with them (torn out of the top)
  hipbone    the right hip bone round its socket (acetabulum), R6 torso
             space, the socket's middle at (0.5, -1, 0) (over the leg's top)
  hipmuscle<i>  the muscles that stay on the body round the hip joint
             (glutei, iliopsoas, pectineus, the tops of the adductors...),
             placed with it
The names of what was taken are printed. Only needed again to change what is
taken; gore.py and fracture.py read the .npz.
"""

import re
import sys

import bpy  # noqa: I001 (first: it makes the other Blender modules importable)
import numpy as np
from mathutils import Vector

BLEND = sys.argv[-1]
OUT = "tools/wounds/anatomy/limbs.npz"

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

# The forearm and the shin in the R6 arm / leg (see the doc): where their
# break is, which part of the bone it is (0 = the lower end, 1 = the upper),
# how much of the block's width the muscles fill, how much less they are
# scaled along the limb than across it.
LIMBS = {
    "arm": dict(
        bones=("Radius.r", "Ulna.r"),
        compartments=("Anterior compartment of forearm", "Posterior compartment of forearm"),
        # (name, radius in metres: thicker than Z-Anatomy's 0.5 mm curves)
        vessels=(("Radial artery.r", 0.0021), ("Ulnar artery.r", 0.0023), ("Median nerve.r", 0.0019),
                 ("Ulnar nerve.r", 0.0017), ("Cephalic vein.r", 0.0024), ("Basilic vein.r", 0.0026)),
        at=0.42, y=-0.3, fill=0.9, along=0.62,
    ),
    "leg": dict(
        bones=("Tibia.r", "Fibula.r"),
        compartments=("Anterior compartment of leg", "Lateral compartment of leg", "Posterior compartment of leg"),
        vessels=(("Anterior tibial artery.r", 0.0024), ("Posterior tibial artery.r", 0.0026),
                 ("Tibial nerve.r", 0.0024), ("Great saphenous vein.r", 0.0028), ("Deep fibular nerve.r", 0.0016)),
        at=0.36, y=-0.35, fill=0.9, along=0.62,
    ),
}
LIMB_SPAN = 0.95  # studs above / below the break kept
THIGH_VESSELS = (("Femoral artery.r", 0.0042), ("Femoral vein.r", 0.0048), ("Sciatic nerve.r", 0.0045))

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


def tube(name, radius, budget):
    """A curve object (a vessel, a nerve) as a mesh `radius` thick (world,
    metres)."""
    ob = bpy.data.objects[name]
    ob.data.bevel_depth = radius
    ob.data.bevel_resolution = 1
    return world_mesh(ob, budget)


def in_limb(name, spec):
    """The forearm / the shin of LIMBS[name] in the R6 limb: {group: [(v, f)]}
    (see the doc)."""
    bones = [world_mesh(bpy.data.objects[b], 6000) for b in spec["bones"]]
    every = np.array([tuple(p) for v, _f in bones for p in v])
    low, high = every[:, 2].min(), every[:, 2].max()
    length = high - low

    def middle(z0, z1):
        band = every[(every[:, 2] >= z0) & (every[:, 2] <= z1)]
        return Vector(band.mean(0))

    # the limb's axis: from between the bones' lower ends to their upper ones
    bottom = middle(low, low + 0.06 * length)
    top = middle(high - 0.06 * length, high)
    turn = (top - bottom).rotation_difference(Vector((0, 0, 1))).to_matrix()
    at = bottom.lerp(top, spec["at"])

    def upright(p):
        return to_char(turn @ (Vector(p) - at))

    # (the names first: making meshes adds and removes objects)
    names = sorted({
        ob.name
        for coll in spec["compartments"]
        for ob in bpy.data.collections[coll].all_objects
        if ob.type == "MESH" and ob.name.endswith(".r") and "tendon" not in ob.name.lower()
    })
    muscles = []
    for n in names:
        v, f = world_mesh(bpy.data.objects[n], 1600)
        muscles.append((n, np.array([upright(p) for p in v]), f))
    # across: the muscles round the break fill the block
    band = np.vstack([m[np.abs(m[:, 1]) < 0.012] for _n, m, _f in muscles])
    lo, hi = band.min(0), band.max(0)
    centre = (lo + hi) / 2
    sx, sz = spec["fill"] / (hi[0] - lo[0]), spec["fill"] / (hi[2] - lo[2])
    sy = min(sx, sz) * spec["along"]
    print(name, "across", round(sx, 2), round(sz, 2), "along", round(sy, 2))

    def place(c):
        out = np.column_stack([(c[:, 0] - centre[0]) * sx, c[:, 1] * sy + spec["y"], (c[:, 2] - centre[2]) * sz])
        return out.astype(np.float32)

    def kept(v, f):
        # (only what is near the break, inside the limb's length)
        return keep([Vector(p) for p in v], f, lambda p: abs(p.y - spec["y"]) < LIMB_SPAN and abs(p.y) < 1.0)

    groups = {"bone": [], "muscle": [], "vessel": []}
    for b, (v, f) in zip(spec["bones"], bones):
        groups["bone"].append(kept(place(np.array([upright(p) for p in v])), f))
        print(name, "bone", b)
    for n, m, f in muscles:
        piece = kept(place(m), f)
        if len(piece[1]):
            groups["muscle"].append(piece)
            print(name, "muscle", len(groups["muscle"]) - 1, n)
    for n, radius in spec["vessels"]:
        v, f = tube(n, radius, 900)
        piece = kept(place(np.array([upright(p) for p in v])), f)
        if len(piece[1]):
            groups["vessel"].append(piece)
            print(name, "vessel", len(groups["vessel"]) - 1, n)
    return groups


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    arrays = {}

    for name, spec in LIMBS.items():
        for group, items in in_limb(name, spec).items():
            for index, (v, f) in enumerate(items):
                arrays[f"{name}{group}__{index}__v"] = np.array([tuple(p) for p in v], dtype=np.float32)
                arrays[f"{name}{group}__{index}__f"] = f

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
    for index, (name, radius) in enumerate(THIGH_VESSELS):
        mv, mf = tube(name, radius, 900)
        arrays[f"thighvessel__{index}__v"], arrays[f"thighvessel__{index}__f"] = in_leg(
            np.array([to_char(p) for p in mv]), ACROSS), mf
        print("thigh vessel", index, name)

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
