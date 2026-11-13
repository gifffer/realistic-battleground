"""
Takes the bones of the right shoulder out of Z-Anatomy (https://www.z-anatomy.com,
CC BY-SA 4.0) for the Bouncer's finisher (the arm torn off) and the bone you
can pick up and throw (tools/wounds/gore.py):

    venv/bin/python -I tools/wounds/extract_arm.py \
        "<z-anatomy>/Z-Anatomy PC/Assets/Models/1.0 Models/SkeletalSystem100.fbx" \
        "<z-anatomy>/Z-Anatomy PC/Assets/Models/1.0 Models/MuscularSystem100.fbx"

(the Z-Anatomy repository: https://github.com/LluisV/z-anatomy)

Writes tools/wounds/anatomy/arm.npz (small: decimated meshes, already in the
game's spaces, studs; X right of the character, Y up, Z toward the back):
  humerus    the whole right upper arm bone, its middle the origin, along Y
             (the head at the top), 1.7 studs long
  armhead    the same bone placed in the R6 right arm (1 x 2 x 1, its top at
             Y = 1): its round head sticking out of the torn end
  scapula    the outer part of the right shoulder blade (the socket the head
             sat in, the acromion over it), in the R6 torso's space
  clavicle   the outer end of the right collarbone, in the R6 torso's space
  armmuscle<i>   the real muscles of the upper arm (deltoid, biceps, triceps,
             brachialis, coracobrachialis) in the R6 arm, with the humerus,
             widened to fill the blocky arm: the torn end shows their cut
  shouldermuscle<i>  the muscles that stay on the body at the shoulder
             (rotator cuff, pectoralis major, latissimus, teres), torso space
Only needed again to change what is taken; gore.py reads the .npz.
"""

import sys

import bpy  # noqa: I001
import numpy as np
from mathutils import Vector

FBX = sys.argv[-2]
MUSCLES = sys.argv[-1]
ARM_MUSCLES = [
    "Acromial part of deltoid muscle.r", "Clavicular part of deltoid muscle.r",
    "Scapular spinal part of deltoid muscle.r", "Long head of biceps brachii.r",
    "Short head of biceps brachii.r", "Long head of triceps brachii.r",
    "Lateral head of triceps brachii.r", "Medial head of triceps brachii.r",
    "Brachialis muscle.r", "Coracobrachialis muscle.r",
]
SHOULDER_MUSCLES = [
    "Supraspinatus muscle.r", "Infraspinatus muscle.r", "Subscapularis muscle.r",
    "Teres minor muscle.r", "Teres major muscle.r",
    "Sternocostal head of pectoralis major muscle.r", "Clavicular head of pectoralis major muscle.r",
]
# The real upper arm is round and thin; the R6 arm a 1 x 1 block: the
# muscles are widened across (not along) to fill it.
ACROSS = 1.55
OUT = "tools/wounds/anatomy/arm.npz"

# The real torso -> the R6 torso (same as extract_anatomy.py).
TORSO_CENTER = Vector((0.0, -0.01, 1.2))
TORSO_SCALE = Vector((5.9, 4.0, 4.5))


def to_torso(p):
    d = p - TORSO_CENTER
    return (-d.x * TORSO_SCALE.x, d.z * TORSO_SCALE.y, d.y * TORSO_SCALE.z)


def to_char(p):
    """anatomical (metres, Z up, -Y = front, x < 0 = its right) -> character axes"""
    return (-p.x, p.z, p.y)


def mesh_of(name, budget):
    ob = bpy.data.objects[name]
    mesh = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh().copy()
    mesh.transform(ob.matrix_world)
    temp = bpy.data.objects.new("tmp", mesh)
    bpy.context.scene.collection.objects.link(temp)
    temp.modifiers.new("t", "TRIANGULATE")
    dec = temp.modifiers.new("d", "DECIMATE")
    dec.ratio = min(1.0, budget / max(1, len(mesh.polygons)))
    ev = temp.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    ev.calc_loop_triangles()
    v = [Vector(x.co) for x in ev.vertices]
    f = np.array([tuple(t.vertices) for t in ev.loop_triangles], dtype=np.int32)
    return v, f


def cut_keep(v, f, keep):
    """Keeps the triangles whose 3 corners pass `keep` (then re-indexes)."""
    ok = np.array([keep(p) for p in v])
    tris = [t for t in f if ok[t[0]] and ok[t[1]] and ok[t[2]]]
    used = sorted({i for t in tris for i in t})
    remap = {old: new for new, old in enumerate(used)}
    return [v[i] for i in used], np.array([[remap[i] for i in t] for t in tris], dtype=np.int32)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=FBX)
    arrays = {}

    # The humerus, in character axes (metres), then scaled uniformly.
    hv, hf = mesh_of("Humerus.r", 2600)
    hc = np.array([to_char(p) for p in hv], dtype=np.float64)
    length = hc[:, 1].max() - hc[:, 1].min()
    # the shaft's middle (between the ends) on the axis, the head up
    lo, hi = hc[:, 1].min(), hc[:, 1].max()
    shaft = hc[(hc[:, 1] > lo + 0.3 * length) & (hc[:, 1] < lo + 0.7 * length)]
    axis_x, axis_z = shaft[:, 0].mean(), shaft[:, 2].mean()
    k = 1.7 / length
    whole = np.column_stack([(hc[:, 0] - axis_x) * k, (hc[:, 1] - (lo + hi) / 2) * k, (hc[:, 2] - axis_z) * k])
    arrays["humerus__0__v"] = whole.astype(np.float32)
    arrays["humerus__0__f"] = hf
    # In the arm: as long as the arm (2 studs), centred on it, its head 0.38
    # out of the top (pulled out of the shoulder with it).
    k2 = 2.0 / length
    inarm = np.column_stack([(hc[:, 0] - axis_x) * k2, (hc[:, 1] - hi) * k2 + 1.38, (hc[:, 2] - axis_z) * k2])
    arrays["armhead__0__v"] = inarm.astype(np.float32)
    arrays["armhead__0__f"] = hf

    # The outer part of the shoulder blade (the socket, the acromion) and the
    # outer end of the collarbone, in the torso.
    sv, sf = mesh_of("Scapula.r", 9000)
    sv, sf = cut_keep(sv, sf, lambda p: p.x < -0.128 and p.z > 1.33)
    arrays["scapula__0__v"] = np.array([to_torso(p) for p in sv], dtype=np.float32)
    arrays["scapula__0__f"] = sf
    cv, cf = mesh_of("Clavicle.r", 1500)
    cv, cf = cut_keep(cv, cf, lambda p: p.x < -0.1)
    arrays["clavicle__0__v"] = np.array([to_torso(p) for p in cv], dtype=np.float32)
    arrays["clavicle__0__f"] = cf
    # The muscles (another file): the arm's with the humerus' placement, the
    # shoulder's in the torso.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=MUSCLES)
    for index, name in enumerate(ARM_MUSCLES):
        mv, mf = mesh_of(name, 1400)
        mc = np.array([to_char(p) for p in mv], dtype=np.float64)
        placed = np.column_stack([(mc[:, 0] - axis_x) * k2 * ACROSS, (mc[:, 1] - hi) * k2 + 1.38, (mc[:, 2] - axis_z) * k2 * ACROSS])
        arrays[f"armmuscle__{index}__v"] = placed.astype(np.float32)
        arrays[f"armmuscle__{index}__f"] = mf
    for index, name in enumerate(SHOULDER_MUSCLES):
        mv, mf = mesh_of(name, 1400)
        mv, mf = cut_keep(mv, mf, lambda p: p.x < -0.11 and p.z > 1.27)  # (by the joint)
        if len(mf):
            arrays[f"shouldermuscle__{index}__v"] = np.array([to_torso(p) for p in mv], dtype=np.float32)
            arrays[f"shouldermuscle__{index}__f"] = mf
    for key in arrays:
        if key.endswith("__v"):
            print(key, arrays[key].shape, arrays[key].min(0).round(2), arrays[key].max(0).round(2))
    np.savez_compressed(OUT, **arrays)
    print("wrote", OUT)


main()
