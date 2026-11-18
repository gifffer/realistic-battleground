"""Dumps Unreal ALS FBX animations for tools/anim/als_retarget.py: for every frame,
the world position (head / tail) and rotation of the bones the retarget uses.

    venv/bin/python -I tools/anim/als_dump.py <dump dir> <file.FBX> ...
(writes <dump dir>/<animation name>.json; the FBX files themselves are not in
the repo: the player has them.)
"""
import bpy, sys, json, os
BONES = ["pelvis", "spine_01", "spine_03", "spine_05", "neck_01", "head", "clavicle_l", "clavicle_r",
         "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r",
         "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r"]
out_dir = sys.argv[1]
for path in sys.argv[2:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
    act = arm.animation_data.action if arm.animation_data else None
    f0, f1 = (int(round(act.frame_range[0])), int(round(act.frame_range[1]))) if act else (1, 1)
    sc = bpy.context.scene
    frames = []
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        fr = {}
        for b in BONES:
            pb = arm.pose.bones.get(b)
            if pb is None:
                continue
            m = arm.matrix_world @ pb.matrix
            fr[b] = {"head": list(arm.matrix_world @ pb.head), "tail": list(arm.matrix_world @ pb.tail),
                     "rot": [list(r) for r in m.to_3x3().normalized()]}
        frames.append(fr)
    name = os.path.splitext(os.path.basename(path))[0]
    json.dump({"name": name, "fps": sc.render.fps, "frames": frames}, open(os.path.join(out_dir, name + ".json"), "w"))
    print("dumped", name, len(frames))
