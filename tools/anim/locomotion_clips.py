"""Builds the locomotion clips (MovementClips: Idle, Walk, WalkBack, WalkLeft,
WalkRight, Run) from the poses measured frame by frame on the player's
reference video 17 (docs/references/video17.md).

Every locomotion clip runs on ONE shared phase (CharacterAnimationController /
Locomotion): `length = 1` is one full cycle (two steps), 16 keys at i/16 (at
full walking speed one key is about one frame at 30 fps), looped, no copy of
the first key at the end. Only one side is written; the other side and the
second half of the cycle are made by the mirror rule, so left and right are
exactly symmetric:
    right joint at key i = mirror(left joint at key i + 8),  mirror(rot) = (X, -Y, -Z)
    Root / Neck at key i + 8 = mirror(their value at key i)
Foot contacts are at the same keys in every clip (7 and 15; WalkBack 0 and 8),
so blending them never scissors the legs.

R6 conventions (R6Pose): shoulder / hip rot.X > 0 swings forward; Root / Neck
X > 0 tilts back; Root Y > 0 brings the right shoulder forward; Root Z > 0
leans the top to the character's left; RightShoulder Z < 0 / LeftShoulder
Z > 0 = inward; RightHip Z > 0 / LeftHip Z < 0 = outward; leg pos.Y > 0 slides
the leg up into the torso (a bent knee).

    venv/bin/python -I tools/anim/locomotion_clips.py --write
(rewrites the generated block of src/client/Animation/MovementClips.luau,
between its "BEGIN generated locomotion" / "END generated locomotion"
markers; without --write it prints the entries)
"""

import sys

N = 16
JOINTS = ("Root", "Neck", "RightShoulder", "LeftShoulder", "RightHip", "LeftHip")


def mirror(rot):
    return (rot[0], -rot[1], -rot[2])


def zeros():
    return [(0.0, 0.0, 0.0)] * N


class Clip:
    def __init__(self):
        self.rot = {j: zeros() for j in JOINTS}
        self.pos = {j: zeros() for j in JOINTS}

    def set_rot(self, joint, xs=None, ys=None, zs=None):
        cur = self.rot[joint]
        self.rot[joint] = [
            (
                xs[i] if xs is not None else cur[i][0],
                ys[i] if ys is not None else cur[i][1],
                zs[i] if zs is not None else cur[i][2],
            )
            for i in range(N)
        ]

    def set_posy(self, joint, ys):
        self.pos[joint] = [(0.0, ys[i], 0.0) for i in range(N)]

    def mirror_limbs(self):
        """Right arm / leg from the left one, half a cycle later."""
        for left, right in (("LeftShoulder", "RightShoulder"), ("LeftHip", "RightHip")):
            self.rot[right] = [mirror(self.rot[left][(i + 8) % N]) for i in range(N)]
            self.pos[right] = [self.pos[left][(i + 8) % N] for i in range(N)]

    def mirror_half(self, joint):
        """Keys 8..15 of a Root / Neck track = keys 0..7 mirrored."""
        for i in range(8):
            self.rot[joint][i + 8] = mirror(self.rot[joint][i])
            self.pos[joint][i + 8] = self.pos[joint][i]

    def mirrored(self):
        """The whole clip mirrored left <-> right (WalkLeft -> WalkRight)."""
        out = Clip()
        swap = {"RightShoulder": "LeftShoulder", "LeftShoulder": "RightShoulder", "RightHip": "LeftHip", "LeftHip": "RightHip"}
        for j in JOINTS:
            src = swap.get(j, j)
            out.rot[j] = [mirror(r) for r in self.rot[src]]
            out.pos[j] = list(self.pos[src])
        return out


def half(values):
    """8 values -> 16 (the same 8 twice)."""
    return list(values) + list(values)


def stabilise_neck(clip, share=0.6, pitch=None):
    """Head kept steady: the neck turns back part of the torso's yaw / roll."""
    rot = []
    for i in range(N):
        rx, ry, rz = clip.rot["Root"][i]
        nx = pitch[i] if pitch is not None else -share * rx
        rot.append((nx, -share * ry, -share * rz))
    clip.rot["Neck"] = rot


# ---------------------------------------------------------------------------
# Walk: the heel-flick power-walk (ref 0-6.4 s). Phase 0 = passing, just
# before the LEFT flick; 0-0.5 left leg flicks back, left arm punches forward
# and across, right arm swings back behind; 0.5-1 the mirror.
# Rise in 2 keys, a 3-key dwell with a little drift, a return that slows into
# the passing; the arm leads the leg by a key on the rise and lags it by a key
# on the release; the arms swing out mid-swing and cross in at the extremes
# (arcs), and never hang still together at the passing.
# ---------------------------------------------------------------------------
def walk():
    c = Clip()
    c.set_rot(
        "LeftShoulder",
        xs=[5, 30, 65, 80, 82, 75, 50, 18, -12, -40, -58, -62, -60, -45, -22, -5],
        ys=[0, -5, -15, -20, -20, -18, -10, -3, 0, 0, 0, 0, 0, 0, 0, 0],
        zs=[-10, 0, 15, 25, 25, 20, 5, -8, -12, -2, 12, 18, 16, 5, -6, -11],
    )
    c.set_rot(
        "LeftHip",
        xs=[0, -5, -35, -70, -75, -70, -40, -4, 0, 6, 10, 12, 10, 6, 3, 0],
        zs=[0, -2, -10, -16, -18, -16, -10, -3, 0, 0, 0, 0, 0, 0, 0, 0],
    )
    c.set_posy("LeftHip", [0, 0, 0.05, 0.10, 0.10, 0.10, 0.05, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    c.mirror_limbs()
    c.set_rot(
        "Root",
        xs=half([-6, -6, -7, -8, -8, -7, -6, -6]),
        ys=[0, -3, -7, -10, -10, -8, -4, -1] + [0] * 8,
        zs=[0, -1, -2, -3, -3, -2.5, -1.5, -0.5] + [0] * 8,
    )
    c.set_posy("Root", half([0, 0.03, 0.07, 0.08, 0.07, 0.03, -0.03, -0.04]))
    c.mirror_half("Root")
    # (the head stays level against the pitch, and turns back 60 % of the twist)
    stabilise_neck(c, pitch=half([4, 4, 4.5, 5, 5, 4.5, 4, 4]))
    return c


# ---------------------------------------------------------------------------
# WalkBack: the guard backpedal (ref 6.5-9 s). Both arms locked up and out in
# front (no swing: the see-saw comes from the torso roll); the front leg is
# lifted (bent knee) at its forward extreme, the back leg straight and
# planted; the body rocks side to side.
# ---------------------------------------------------------------------------
def walk_back():
    c = Clip()
    c.set_rot("LeftShoulder", xs=[88] * N, zs=[-40] * N)  # (Z < 0 = outward for the left arm)
    c.set_rot(
        "LeftHip",
        xs=[50, 48, 45, 33, 20, 0, -25, -37, -45, -44, -42, -30, -15, 0, 20, 35],
    )
    c.set_posy("LeftHip", [0.35, 0.34, 0.32, 0.27, 0.21, 0.14, 0.08, 0.03, 0, 0, 0, 0, 0, 0.05, 0.15, 0.25])
    c.mirror_limbs()
    c.set_rot(
        "Root",
        xs=[3] * N,
        ys=[0, 1, 1.5, 2, 2, 1.5, 1, 0.5] + [0] * 8,
        zs=[0, 2, 4, 5, 6, 6, 4, 2] + [0] * 8,
    )
    c.set_posy("Root", half([-0.11, -0.10, -0.08, 0.02, 0.10, 0.07, 0.02, -0.06]))
    c.mirror_half("Root")
    stabilise_neck(c, pitch=[-2] * N)
    return c


# ---------------------------------------------------------------------------
# WalkLeft: the side-hop to the left (ref 1.5-4.3 s). The LEAD leg (left)
# kicks out sideways to hip height on every hop, two hops per cycle; the arms
# take turns: one crosses behind the back while the other is flung out, and
# they loop instead of ping-ponging. WalkRight is the full mirror.
# ---------------------------------------------------------------------------
def walk_left():
    c = Clip()
    c.set_rot("LeftHip", zs=half([-5, -20, -45, -80, -85, -83, -62, -25]))
    c.set_posy("LeftHip", half([0.10, 0.06, 0.05, 0.08, 0.08, 0.08, 0.12, 0.24]))
    c.set_rot("RightHip", zs=half([0, 6, 12, 4, 2, 2, 2, 0]))
    c.set_posy("RightHip", half([0.13, 0.03, 0, 0, 0, 0, 0.05, 0.13]))
    c.set_rot(
        "LeftShoulder",
        xs=[0, -15, -30, -55, -60, -60, -50, -28, -5, 5, 8, 10, 10, 10, 6, 2],
        zs=[-8, 2, 10, 30, 35, 35, 28, 8, -15, -38, -52, -62, -65, -62, -48, -25],
    )
    # right arm = the left one mirrored, half a cycle later (legs set by hand)
    c.rot["RightShoulder"] = [mirror(c.rot["LeftShoulder"][(i + 8) % N]) for i in range(N)]
    root_y = [0, 3, 5, 8, 8, 8, 6, 1]
    c.set_rot(
        "Root",
        ys=root_y + [-v for v in root_y],
        zs=half([0, -2, -4, -5, -5, -5, -4, -1]),
    )
    c.set_posy("Root", half([-0.12, 0.04, 0.14, 0.10, 0.07, 0.03, -0.05, -0.13]))
    stabilise_neck(c)
    return c


# ---------------------------------------------------------------------------
# Run (sprint, ref 15.5-16.3 s in profile): the walk's shape, bigger and
# faster. Arms swing about +-70 (the forward arm on the same side as the
# trailing leg, like the walk), the trailing leg nearly horizontal behind (-78, knee
# bent), the leading leg +35, the torso pitched forward, a strong bob.
# Same phase and contacts as Walk, so walk <-> run is an exact blend.
# ---------------------------------------------------------------------------
def run():
    c = Clip()
    c.set_rot(
        "LeftShoulder",
        xs=[5, 35, 60, 70, 70, 58, 35, 5, -20, -45, -65, -70, -68, -55, -30, -8],
        zs=[-10, -6, 4, 10, 10, 4, -6, -10, -10, -8, -4, 0, 0, -3, -8, -10],
    )
    c.set_rot(
        "LeftHip",
        xs=[0, -15, -50, -78, -78, -65, -35, -5, 0, 12, 28, 35, 35, 28, 15, 5],
    )
    c.set_posy("LeftHip", [0, 0.03, 0.10, 0.15, 0.15, 0.12, 0.06, 0, 0, 0.02, 0.04, 0.05, 0.05, 0.04, 0.02, 0])
    c.mirror_limbs()
    c.set_rot(
        "Root",
        xs=half([-8, -9, -11, -12, -12, -11, -9, -8]),
        ys=[0, -2, -4.5, -6, -6, -5, -3, -1] + [0] * 8,
        zs=[0, -0.5, -1.2, -2, -2, -1.5, -1, -0.3] + [0] * 8,
    )
    c.set_posy("Root", half([-0.10, -0.02, 0.08, 0.13, 0.12, 0.06, -0.03, -0.10]))
    c.mirror_half("Root")
    stabilise_neck(c, pitch=half([6, 6, 7, 7, 7, 7, 6, 6]))
    return c


# ---------------------------------------------------------------------------
# Idle: standing in the walk's carriage (arms a little out, a slight forward
# set), breathing. The walk's amplitude fades TO this pose when slowing down,
# so idle <-> walk never jumps. Its own length (3.6 s, not a phase clip).
# ---------------------------------------------------------------------------
def idle():
    keys = []
    for t, f in ((0, 0.0), (1.8, 1.0)):
        keys.append(
            (
                t,
                {
                    "Root": ((-2 - 0.6 * f, 0, 0), (0, 0.012 * f, 0)),
                    "Neck": ((0.8 * f + 2, 0, 0), None),
                    "RightShoulder": ((1 * f, 0, 8 + 1 * f), None),
                    "LeftShoulder": ((1 * f, 0, -8 - 1 * f), None),
                    "RightHip": ((0, 0, 3), None),
                    "LeftHip": ((0, 0, -3), None),
                },
            )
        )
    return keys



# ---------------------------------------------------------------------------
# Feet on the floor: R6 forward kinematics (root at the origin, floor at
# y = -3). A tilted leg block touches the floor with a CORNER, which can dip
# under it, and a body bobbing down pushes the support leg into it: at each
# key the sinking leg is pulled up into the torso by what it sinks (a bent
# support knee). The body's bob stays exactly as written (low at the plant,
# high at the flick / hop).
# ---------------------------------------------------------------------------
import math

import numpy as np


def _cf(pos, rot=None):
    m = np.eye(4)
    if rot is not None:
        m[:3, :3] = rot
    m[:3, 3] = pos
    return m


def _cfm(x, y, z, *r):
    return _cf((x, y, z), np.array(r, dtype=float).reshape(3, 3))


def _angles(x, y, z):
    x, y, z = map(math.radians, (x, y, z))
    rx = np.array([[1, 0, 0], [0, math.cos(x), -math.sin(x)], [0, math.sin(x), math.cos(x)]])
    ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
    rz = np.array([[math.cos(z), -math.sin(z), 0], [math.sin(z), math.cos(z), 0], [0, 0, 1]])
    return rx @ ry @ rz


_C = {  # standard R6 Motor6D C0 / C1
    "Root": (_cfm(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), _cfm(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)),
    "RightHip": (_cfm(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), _cfm(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)),
    "LeftHip": (_cfm(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), _cfm(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)),
}


def _joint(name, rot, pos, parent):
    c0, c1 = _C[name]
    axes = _cf((0, 0, 0), c0[:3, :3])
    local = _cf(pos, _angles(*rot))
    return parent @ c0 @ (np.linalg.inv(axes) @ local @ axes) @ np.linalg.inv(c1)


def leg_low(clip, i, hip):
    torso = _joint("Root", clip.rot["Root"][i], clip.pos["Root"][i], np.eye(4))
    leg = _joint(hip, clip.rot[hip][i], clip.pos[hip][i], torso)
    return min((leg @ np.array([x, -1, z, 1]))[1] for x in (-0.5, 0.5) for z in (-0.5, 0.5))


def lowest_foot(clip, i):
    return min(leg_low(clip, i, hip) for hip in ("RightHip", "LeftHip"))


def plant(clip, floor=-3.0):
    for i in range(N):
        for hip in ("RightHip", "LeftHip"):
            for _ in range(4):
                sink = floor - leg_low(clip, i, hip)
                if sink <= 1e-4:
                    break
                x, y, z = clip.pos[hip][i]
                clip.pos[hip][i] = (x, y + sink, z)
    return clip

# ---------------------------------------------------------------------------
# Luau output
# ---------------------------------------------------------------------------
def num(x):
    x = round(float(x), 3)
    if x == 0:
        x = 0.0
    if x == int(x):
        return str(int(x))
    return f"{x:g}"


def vec(v):
    return f"Vector3.new({num(v[0])}, {num(v[1])}, {num(v[2])})"


def joint_line(joint, rot, pos):
    s = f"rot = {vec(rot)}"
    if pos is not None and any(abs(p) > 1e-9 for p in pos):
        s += f", pos = {vec(pos)}"
    return f"\t\t\t\t\t{joint} = {{ {s} }},"


def phase_clip(name, clip):
    lines = [f"\t{name} = {{", "\t\tlength = 1,", "\t\tlooped = true,", "\t\tkeyframes = {"]
    for i in range(N):
        lines += ["\t\t\t{", f"\t\t\t\ttime = {num(i / N)},", "\t\t\t\tpose = {"]
        for j in JOINTS:
            lines.append(joint_line(j, clip.rot[j][i], clip.pos[j][i]))
        lines += ["\t\t\t\t},", "\t\t\t},"]
    lines += ["\t\t},", "\t},"]
    return "\n".join(lines)


def idle_clip():
    lines = ["\tIdle = {", "\t\tlength = 3.6,", "\t\tlooped = true,", "\t\tkeyframes = {"]
    for t, pose in idle():
        lines += ["\t\t\t{", f"\t\t\t\ttime = {num(t)},", "\t\t\t\tpose = {"]
        for j in JOINTS:
            rot, pos = pose[j]
            lines.append(joint_line(j, rot, pos))
        lines += ["\t\t\t\t},", "\t\t\t},"]
    lines += ["\t\t},", "\t},"]
    return "\n".join(lines)


CLIPS = None


def clips():
    left = plant(walk_left())
    return {
        "Walk": plant(walk()),
        "WalkBack": plant(walk_back()),
        "WalkLeft": left,
        "WalkRight": left.mirrored(),
        "Run": plant(run()),
    }


BEGIN = "\t-- BEGIN generated locomotion (tools/anim/locomotion_clips.py)"
END = "\t-- END generated locomotion"


def main():
    out = [idle_clip()]
    for name, clip in clips().items():
        out.append(phase_clip(name, clip))
    text = "\n".join(out)
    if "--write" not in sys.argv:
        sys.stdout.write(text + "\n")
        return
    import os

    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src", "client", "Animation", "MovementClips.luau")
    lines = open(path).read().split("\n")
    start, end = lines.index(BEGIN), lines.index(END)
    lines[start + 1 : end] = text.split("\n")
    open(path, "w").write("\n".join(lines))
    print("wrote", os.path.normpath(path))


if __name__ == "__main__":
    main()
