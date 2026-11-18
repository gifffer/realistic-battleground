"""Retargets Unreal ALS animations (UE5 mannequin, 88 bones) onto the R6 rig
(6 parts), as R6Pose clips (MovementClips / ALSClips format).

1. Dump the FBX files with Blender (bone positions / rotations per frame):
       venv/bin/python -I tools/anim/als_dump.py <dump dir> <file.FBX> ...
2. Retarget (this script) and write the generated block of
   src/client/Animation/ALSClips.luau:
       venv/bin/python -I tools/anim/als_retarget.py <dump dir> --write

How 88 bones become 6 parts (source: X = character's left, -Y = forward,
Z = up, metres; ALS_N_Pose is the rest pose = the R6 rest pose):
  • Torso (Root joint): the turn of spine_03 since the rest pose, and the
    pelvis' move since the rest pose (scaled: the hips' height = 2 studs).
  • Head (Neck): the head bone's turn since the rest pose, relative to the torso.
  • Arms: one block from the shoulder to the WRIST, so each arm points where
    upperarm → hand points (no twist).
  • Legs: one block from the hip to the sole: each leg is aimed (by forward
    kinematics on the R6 joints) at where the ankle is, the soles at the
    floor; a bent knee (the hip→ankle distance shorter than the leg) slides
    the leg up into the torso, our fake knee. Feet are spread to R6's width.
  • Cycles (walk / run / sprint...) are cut to one cycle, shifted so the LEFT
    foot plants at phase 7/16 (the right one half a cycle later), and
    resampled on 32 keys over length 1: the phase clips of Animation/Locomotion.
    Their natural stride (studs per cycle) is written next to them.
"""

import json
import math
import os
import sys

import numpy as np
from scipy.interpolate import CubicSpline
from scipy.optimize import least_squares

N_KEYS = 32
# Arms at rest: degrees out from hanging straight down along the body.
ARM_REST = 2.5
CONTACT_PHASE = 7 / 16
JOINTS = ("Root", "Neck", "RightShoulder", "LeftShoulder", "RightHip", "LeftHip")

# source axes (X left, Y back, Z up) -> Roblox (X right, Y up, Z back)
M = np.array([[-1, 0, 0], [0, 0, 1], [0, 1, 0]], dtype=float)


def conv(v):
    return M @ np.asarray(v, dtype=float)


def conv_rot(r):
    return M @ np.asarray(r, dtype=float) @ M.T


# ---------------------------------------------------------------- R6 rig
def cf(pos=(0, 0, 0), rot=None):
    m = np.eye(4)
    if rot is not None:
        m[:3, :3] = rot
    m[:3, 3] = pos
    return m


def cfm(x, y, z, *r):
    return cf((x, y, z), np.array(r, dtype=float).reshape(3, 3))


def angles(x, y, z):  # CFrame.Angles(x, y, z) = Rx Ry Rz (radians)
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return rx @ ry @ rz


def euler(r):
    """Rx Ry Rz angles (radians) of a rotation matrix."""
    y = math.asin(max(-1.0, min(1.0, r[0, 2])))
    x = math.atan2(-r[1, 2], r[2, 2])
    z = math.atan2(-r[0, 1], r[0, 0])
    return x, y, z


C = {
    "Root": (cfm(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), cfm(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)),
    "RightHip": (cfm(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), cfm(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)),
    "LeftHip": (cfm(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), cfm(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)),
}


def joint(name, rot, pos, parent):
    c0, c1 = C[name]
    axes = cf((0, 0, 0), c0[:3, :3])
    local = cf(pos, rot)
    return parent @ c0 @ (np.linalg.inv(axes) @ local @ axes) @ np.linalg.inv(c1)


# ---------------------------------------------------------------- retarget
class Rest:
    def __init__(self, frame):
        self.f = frame
        self.k = 2.0 / frame["thigh_l"]["head"][2]  # studs per metre (hips 2 studs up)
        self.pelvis = np.array(frame["pelvis"]["head"])
        self.spine = np.array(frame["spine_03"]["rot"])
        self.head = np.array(frame["head"]["rot"])
        self.ankle = frame["foot_l"]["head"][2]  # ankle height above the sole
        self.hip_x = abs(frame["thigh_l"]["head"][0])
        # The mannequin's arms hang about 16 degrees out (wide shoulders, a
        # round chest). An R6 arm pivots on the torso's edge, so the same angle
        # opens a gap under the arm: every frame's sideways angle is shifted
        # so that, at rest, the arms hang ARM_REST degrees out, close along
        # the body and the hips (the swings and gestures are kept as they are).
        self.arm_shift = {}
        for side, arm in (("l", "LeftShoulder"), ("r", "RightShoulder")):
            d = conv(np.array(frame["hand_" + side]["head"]) - np.array(frame["upperarm_" + side]["head"]))
            c0 = math.asin(max(-1.0, min(1.0, d[0] / np.linalg.norm(d))))
            self.arm_shift[arm] = c0 - math.copysign(math.radians(ARM_REST), c0)


def to_floor(rest, p):
    """Source point (m) -> R6 space (studs; HRP at the origin, floor at y = -3)."""
    q = conv(p) * rest.k
    q[1] -= 3.0
    return q


def solve_leg(name, torso, target, guess):
    side = 1 if name == "RightHip" else -1

    def bottom(v):
        a, c, py = v
        leg = joint(name, angles(a, 0, c), (0, py, 0), torso)
        return (leg @ np.array([0, -1, 0, 1]))[:3]

    def lowest(v):
        a, c, py = v
        leg = joint(name, angles(a, 0, c), (0, py, 0), torso)
        return min((leg @ np.array([x, -1, z, 1]))[1] for x in (-0.5, 0.5) for z in (-0.5, 0.5))

    def resid(v):
        # reach the target; never a corner under the floor; a knee only when needed
        sink = max(0.0, -3.0 - lowest(v))
        return np.concatenate([(bottom(v) - target) * 10, [sink * 40, v[2] * 0.3, (v[1] - guess[1]) * 0.05 * side]])

    # (strictly inside the bounds: a start ON a bound never leaves it)
    start = np.clip(np.asarray(guess, dtype=float), [-2.55, -1.55, 0.02], [2.55, 1.55, 1.55])
    sol = least_squares(resid, start, bounds=([-2.6, -1.6, 0.0], [2.6, 1.6, 1.6]))
    return sol.x


def retarget_frame(rest, fr, prev=None):
    pose = {}
    torso_rot = conv_rot(np.array(fr["spine_03"]["rot"]) @ rest.spine.T)
    root_pos = conv(np.array(fr["pelvis"]["head"]) - rest.pelvis) * rest.k
    # (the source turns about the pelvis, R6 about the torso's centre: keep
    # the R6 hip line on the pelvis whatever the torso's turn)
    root_pos = root_pos - (torso_rot @ np.array([0.0, -1.0, 0.0]) - np.array([0.0, -1.0, 0.0]))
    pose["Root"] = (torso_rot, root_pos)
    torso = cf(root_pos, torso_rot)  # (Root C0 / C1 cancel: torso centre at the root joint)
    head_rot = conv_rot(np.array(fr["head"]["rot"]) @ rest.head.T)
    pose["Neck"] = (torso_rot.T @ head_rot, np.zeros(3))
    for side, arm in (("l", "LeftShoulder"), ("r", "RightShoulder")):
        d = conv(np.array(fr["hand_" + side]["head"]) - np.array(fr["upperarm_" + side]["head"]))
        d = torso_rot.T @ (d / np.linalg.norm(d))
        c = math.asin(max(-1.0, min(1.0, d[0]))) - rest.arm_shift[arm]
        a = math.atan2(-d[2], -d[1])
        if prev:
            # (arm out sideways: the swing angle is ill-defined there and can
            # flip; it only follows the arm as much as the arm points down /
            # forward / back, instead of twisting the arm round)
            t = min(1.0, max(0.0, (abs(math.cos(c)) - 0.1) / 0.4))
            follow = t * t * (3 - 2 * t)
            delta = (a - prev[arm] + math.pi) % (2 * math.pi) - math.pi
            a = prev[arm] + delta * follow
        pose[arm] = (angles(a, 0, c), np.zeros(3))
        pose[arm + "_a"] = a
    for side, hip in (("l", "LeftHip"), ("r", "RightHip")):
        ankle = to_floor(rest, fr["foot_" + side]["head"])
        widen = 0.5 - rest.hip_x * rest.k  # R6 legs are wider apart
        ankle[0] += widen * (1 if side == "r" else -1)
        target = ankle - np.array([0, rest.ankle * rest.k, 0])
        guess = prev[hip] if prev else np.array([0.0, 0.0, 0.0])
        a, c, py = solve_leg(hip, torso, target, guess)
        pose[hip] = (angles(a, 0, c), np.array([0, py, 0]))
        pose[hip + "_v"] = np.array([a, c, py])
    return pose


def values(pose):
    """joint -> (rot degrees XYZ, pos) as plain arrays."""
    out = {}
    for j in JOINTS:
        r, p = pose[j]
        out[j] = (np.degrees(np.array(euler(r))), np.asarray(p, dtype=float))
    return out


def retarget_clip(rest, frames):
    out, prev = [], None
    for fr in frames:
        pose = retarget_frame(rest, fr, prev)
        prev = {h: pose[h + "_v"] for h in ("LeftHip", "RightHip")}
        prev.update({a: pose[a + "_a"] for a in ("LeftShoulder", "RightShoulder")})
        out.append(values(pose))
    return out


def unwrap(series):
    return np.degrees(np.unwrap(np.radians(series), axis=0))


def same_frame(a, b):
    return all(
        np.allclose(a[k]["rot"], b[k]["rot"], atol=1e-5) and np.allclose(a[k]["head"], b[k]["head"], atol=1e-5)
        for k in a
    )


def strip_closing(frames):
    """The source ends with copies of its first frame (closing the loop): off."""
    frames = list(frames)
    while len(frames) > 1 and same_frame(frames[-1], frames[0]):
        frames.pop()
    return frames


def contact_frame(frames, side="l"):
    """First frame of a foot's longest time on the floor (cyclic)."""
    z = np.array([f["foot_" + side]["head"][2] for f in frames])
    low = z < z.min() + 0.015
    n = len(z)
    best, best_len = 0, -1
    for s in range(n):
        if low[s] and not low[s - 1]:
            length = 0
            while low[(s + length) % n] and length < n:
                length += 1
            if length > best_len:
                best, best_len = s, length
    return best


def stride(frames, fps, k):
    """Distance the body travels per cycle (studs): the planted feet's speed
    (median over the frames both ends of which are on the floor)."""
    n = len(frames)
    speeds = []
    for side in ("l", "r"):
        z = np.array([f["foot_" + side]["head"][2] for f in frames])
        low = z < z.min() + 0.015
        for i in range(n):
            j = (i + 1) % n
            if low[i] and low[j]:
                a = np.array(frames[i]["foot_" + side]["head"])
                b = np.array(frames[j]["foot_" + side]["head"])
                speeds.append(np.linalg.norm((b - a)[:2]) * fps)
    return float(np.median(speeds)) * (n / fps) * k


def cycle_clip(rest, data):
    frames = strip_closing(data["frames"])
    vals = retarget_clip(rest, frames)
    n = len(vals)
    # Phase of each source frame: the left contact at 7/16, the right one at
    # 15/16 (piecewise linear between them: a gait isn't always even).
    s_l, s_r = contact_frame(frames, "l"), contact_frame(frames, "r")
    d = ((s_r - s_l) % n) / n
    if not 0.3 <= d <= 0.7:
        d = 0.5
    u = ((np.arange(n) - s_l) % n) / n
    phase_src = np.where(u < d, CONTACT_PHASE + u * (0.5 / d), CONTACT_PHASE + 0.5 + (u - d) * (0.5 / (1 - d)))
    keys = []
    for j in JOINTS:
        rot = unwrap(np.array([v[j][0] for v in vals]))
        pos = np.array([v[j][1] for v in vals])
        both = np.concatenate([rot, pos], axis=1)
        order = np.argsort(phase_src % 1)
        x = (phase_src % 1)[order]
        y = both[order]
        x = np.concatenate([x, [x[0] + 1]])
        y = np.concatenate([y, y[:1]])
        spline = CubicSpline(x, y, bc_type="periodic")
        t = np.arange(N_KEYS) / N_KEYS
        t = np.where(t < x[0], t + 1, t)
        keys.append((j, spline(t)))
    return {
        "length": 1,
        "looped": True,
        "keys": [{j: (sampled[i][:3], sampled[i][3:]) for j, sampled in keys} for i in range(N_KEYS)],
        "times": [i / N_KEYS for i in range(N_KEYS)],
        "stride": stride(frames, data["fps"], rest.k),
        "duration": n / data["fps"],
    }


def plain_clip(rest, data, looped=False, step=1):
    frames = data["frames"]
    if looped:
        frames = strip_closing(frames)
    vals = retarget_clip(rest, frames)
    # (angles made continuous: a jump from +179 to -179 degrees would be
    # played as a turn all the way round)
    for j in JOINTS:
        rot = unwrap(np.array([v[j][0] for v in vals]))
        for v, r in zip(vals, rot):
            v[j] = (r, v[j][1])
    fps = data["fps"]
    n = len(vals)
    idx = list(range(0, n, step))
    if not looped and idx[-1] != n - 1:
        idx.append(n - 1)
    keys = [vals[i] for i in idx]
    if looped:
        # (loops wrap onto their first key: bring it back within 180 degrees)
        for j in JOINTS:
            first, last = keys[0][j][0], keys[-1][j][0]
            shift = np.round((last - first) / 360) * 360
            if np.abs(shift).max() > 0:
                keys = [{**k, j: (k[j][0] - shift * (i / max(len(keys) - 1, 1)), k[j][1])} for i, k in enumerate(keys)]
    return {
        "length": (n if looped else n - 1) / fps,
        "looped": looped,
        "keys": keys,
        "times": [i / fps for i in idx],
    }


# ---------------------------------------------------------------- Luau
def num(x):
    x = round(float(x), 2)
    if x == 0:
        x = 0.0
    return str(int(x)) if x == int(x) else f"{x:g}"


def vec(v):
    return f"Vector3.new({num(v[0])}, {num(v[1])}, {num(v[2])})"


def luau(name, clip, comment):
    lines = [f"\t-- {comment}", f"\t{name} = {{", f"\t\tlength = {num(clip['length']) if clip['length'] != 1 else 1},", f"\t\tlooped = {'true' if clip['looped'] else 'false'},", "\t\tkeyframes = {"]
    for t, key in zip(clip["times"], clip["keys"]):
        lines.append(f"\t\t\t{{ time = {round(t, 4):g}, pose = {{")
        for j in JOINTS:
            rot, pos = key[j]
            s = f"rot = {vec(rot)}"
            if np.abs(pos).max() > 0.004:
                s += f", pos = {vec(pos)}"
            lines.append(f"\t\t\t\t{j} = {{ {s} }},")
        lines.append("\t\t\t} },")
    lines += ["\t\t},", "\t},"]
    return "\n".join(lines)


# name in ALSClips -> (source animation, kind, comment)
CYCLES = {
    "Walk": "ALS_N_Walk_F",
    "WalkBack": "ALS_N_Walk_B",
    "WalkLeft": "ALS_N_Walk_LF",
    "WalkRight": "ALS_N_Walk_RF",
    "Jog": "ALS_N_Run_F",
    "JogBack": "ALS_N_Run_B",
    "JogLeft": "ALS_N_Run_LF",
    "JogRight": "ALS_N_Run_RF",
    "Sprint": "ALS_N_Sprint_F",
    "CrouchWalk": "ALS_CLF_Walk_F",
    "CrouchWalkBack": "ALS_CLF_Walk_B",
    "CrouchWalkLeft": "ALS_CLF_Walk_L",
    "CrouchWalkRight": "ALS_CLF_Walk_R",
}
SHOTS = {
    # name: (source, looped, keep every n-th frame). (Other ALS animations -
    # turns on the spot, stops, mantles... - can be added here the same way.)
    "Stand": ("ALS_N_Pose", False, 1),
    "Crouch": ("ALS_CLF_Pose", False, 1),
    "JumpLoop": ("ALS_N_JumpLoop", True, 2),
    "FallLoop": ("ALS_N_FallLoop", True, 2),
    "FallFast": ("ALS_N_FallLoop_Fast", True, 2),
    "Flail": ("ALS_Flail", True, 2),
    "LandLight": ("ALS_N_Land_Light", False, 2),
    "LandHeavy": ("ALS_N_Land_Heavy", False, 2),
    "LandRoll": ("ALS_N_LandRoll_F", False, 2),
    "GetUpBack": ("ALS_CLF_GetUp_Back", False, 2),
    "GetUpFront": ("ALS_CLF_GetUp_Front", False, 2),
}

BEGIN = "\t-- BEGIN generated ALS clips (tools/anim/als_retarget.py)"
END = "\t-- END generated ALS clips"


def build(dump_dir):
    load = lambda n: json.load(open(os.path.join(dump_dir, n + ".json")))
    rest = Rest(load("ALS_N_Pose")["frames"][0])
    blocks, info = [], {}
    for name, src in CYCLES.items():
        data = load(src)
        clip = cycle_clip(rest, data)
        info[name] = clip
        comment = (
            f"{src}: phase clip (one cycle = 1), left foot plants at {CONTACT_PHASE:g}; "
            f"natural cycle {clip['duration']:.3f} s, stride {clip['stride']:.2f} studs per cycle"
        )
        blocks.append(luau(name, clip, comment))
        print(f"{name:16s} {src:20s} cycle {clip['duration']:.3f}s stride {clip['stride']:.2f} studs")
    for name, (src, looped, step) in SHOTS.items():
        data = load(src)
        clip = plain_clip(rest, data, looped, step)
        info[name] = clip
        blocks.append(luau(name, clip, f"{src}: {clip['length']:.2f} s"))
        print(f"{name:16s} {src:20s} {clip['length']:.2f}s {len(clip['keys'])} keys")
    return "\n".join(blocks), info


def main():
    dump_dir = sys.argv[1]
    text, info = build(dump_dir)
    json.dump(
        {n: {k: c[k] for k in ("stride", "duration") if k in c} for n, c in info.items()},
        open(os.path.join(dump_dir, "_info.json"), "w"),
        indent=1,
    )
    if "--write" not in sys.argv:
        return
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src", "client", "Animation", "ALSClips.luau")
    lines = open(path).read().split("\n")
    start, end = lines.index(BEGIN), lines.index(END)
    lines[start + 1 : end] = text.split("\n")
    open(path, "w").write("\n".join(lines))
    print("wrote", os.path.normpath(path))


if __name__ == "__main__":
    main()
