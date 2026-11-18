"""Dumps the Motifect Combat Motion Pack FBX animations (made for Unreal) so they
can be studied and retargeted onto our R6 rig: for every frame, the world
position (head / tail) and rotation of the bones a retarget needs.

    venv/bin/python -I tools/anim/motifect_dump.py <dump dir> <file.fbx> ...
(writes <dump dir>/<animation name>.json; the FBX files themselves are not in
the repo: the player has them.)

What these files look like (checked on all 40 of them):
  • One armature object called "Hips" (scale 0.01: the file is in centimetres,
    Blender shows it in metres) and a "StickmanLines" preview mesh we ignore.
    The armature OBJECT itself moves: it is the pelvis/root, so its world
    matrix is dumped too, under the name "Hips".
  • 76 bones. Root bones: Spine1, LeftLeg, RightLeg (thighs). Chain names:
    Spine1 > Spine2 > Chest > Neck1 > Neck2 > Head; Chest > Left/RightShoulder
    (clavicle) > Left/RightArm (upper arm) > Left/RightForeArm > Left/RightHand
    (+ fingers); Left/RightLeg (thigh) > Left/RightShin > Left/RightFoot >
    Left/RightToeBase > Left/RightToeEnd.
  • 30 frames per second.
  • Axes in Blender world space, after import: +Z is up, the character faces
    -Y, and its LEFT side is +X. Units: metres. The floor is at Z = 0 (toe ends
    sit at about Z = 0.003).
  • Bind (rest) pose: a T-pose, arms straight out along X, about 1.77 m tall.
    The bone TAILS are not meaningful (imported without automatic bone
    orientation, they point along each bone's own Y axis, e.g. the leg bones
    point UP). Use bone HEADS as joint positions: hip, knee (Shin head), ankle
    (Foot head), ball (ToeBase head), shoulder (Arm head), elbow (ForeArm
    head), wrist (Hand head).
"""
import bpy, sys, json, os

BONES = ["Spine1", "Spine2", "Chest", "Neck1", "Head", "HeadEnd",
         "LeftShoulder", "RightShoulder", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm",
         "LeftHand", "RightHand", "LeftHandMiddle1", "RightHandMiddle1",
         "LeftLeg", "RightLeg", "LeftShin", "RightShin", "LeftFoot", "RightFoot",
         "LeftToeBase", "RightToeBase", "LeftToeEnd", "RightToeEnd"]


def vec(v):
    return [round(x, 5) for x in v]


def mat3(m):
    return [vec(r) for r in m.to_3x3().normalized()]


out_dir = sys.argv[1]
os.makedirs(out_dir, exist_ok=True)
for path in sys.argv[2:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
    act = arm.animation_data.action if arm.animation_data else None
    f0, f1 = (int(round(act.frame_range[0])), int(round(act.frame_range[1]))) if act else (1, 1)
    sc = bpy.context.scene
    rest = {}
    for b in BONES:
        bone = arm.data.bones.get(b)
        if bone is not None:
            rest[b] = {"head": vec(arm.matrix_world @ bone.head_local)}
    frames = []
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        mw = arm.matrix_world
        fr = {"Hips": {"head": vec(mw.translation), "rot": mat3(mw)}}
        for b in BONES:
            pb = arm.pose.bones.get(b)
            if pb is None:
                continue
            fr[b] = {"head": vec(mw @ pb.head), "tail": vec(mw @ pb.tail), "rot": mat3(mw @ pb.matrix)}
        frames.append(fr)
    name = os.path.splitext(os.path.basename(path))[0]
    with open(os.path.join(out_dir, name + ".json"), "w") as fh:
        json.dump({"name": name, "fps": sc.render.fps, "first_frame": f0, "rest": rest, "frames": frames}, fh)
    print("dumped", name, len(frames), "frames at", sc.render.fps, "fps")
