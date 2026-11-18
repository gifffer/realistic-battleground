"""Retargets punches of the Motifect Combat Motion Pack (Unreal, 76-bone
humanoid) onto our R6 rig, as the 4 basic punches Brawler_M1_1..4 of
src/client/Animation/CombatClips.luau (R6Pose format).

1. Dump the FBX files with Blender (bone positions / rotations per frame):
       venv/bin/python -I tools/anim/motifect_dump.py <dump dir> <file.fbx> ...
2. Retarget (this script), check the numbers, and, with --write, replace the
   4 Brawler_M1_N blocks (and only them) in CombatClips.luau:
       venv/bin/python -I tools/anim/motifect_retarget.py <dump dir> [--write] [--json out.json]
   then format with `stylua src`.

Why it is not a plain bone-by-bone copy: R6 has 6 rigid parts and no elbows
or knees, and gameplay fixes the timing (impact at 0.15 s). So:

  • Axes: the dump is Blender world space (X = character's left, -Y =
    forward, Z = up, metres). Roblox: X = right, Y = up, -Z = forward, studs.
    conv() swaps them; a "mirror" option flips X and swaps Left/Right (a
    southpaw clip becomes orthodox, like ours).
  • Everything is measured RELATIVE to the source's own guard pose (the
    first frame used), then added onto OUR Guard pose (the first key of the
    Guard clip). So every clip starts exactly in our Guard and only the
    motion of the source is kept.
  • Torso (Root joint): the chest bone's turn since the guard frame (yaw /
    lean / roll), the yaw scaled so the turn at the impact matches the turn
    our R6 needs for that punch (a jab ~ -35 deg, cross ~ +40, hook ~ -49).
    A small lunge (Root pos) follows the punch and comes back: no root
    motion, the server moves nobody for an M1.
  • Head (Neck): turned against the torso so the eyes stay on the target.
  • Arms: an R6 arm is a rigid 1.58-stud block, so copying the upper-arm
    direction would point a bent (guard) arm at the chin. Instead the FIST is
    aimed at a target (end-effector IK, like Unreal's IK Retargeter goals):
    the source knuckle path is mapped so that the source guard -> our Guard
    fist and the source impact -> our impact point (the old clips' contact
    point, inside the hitbox zone), keeping the path's shape in between
    (the hook's arc, the overhand's loop, optionally scaled down). The
    shoulder angles that put the R6 fist on that target are then solved,
    starting from the previous frame's answer (no flips). Extension beyond
    1.58 studs comes from the shoulder pushed forward (pos), like the old
    clips. The other fist stays by the chin.
  • Legs: each leg is aimed at its foot target (our Guard foot, plus the
    source foot's step when the clip's legs are usable), with the fake knee
    (the leg slides up into the torso when the body drops) and the soles on
    the floor: the feet never slide.
  • Time warp: source time is remapped by a smooth monotone curve (cubic
    Hermite through a few (game time, source frame, speed) anchors) so the
    impact lands exactly at 0.15 s; the wind-up is compressed (never cut),
    played fastest right before the impact (mocap punches slow down before
    full extension, a punch that lands doesn't), and the recovery kept close
    to natural. At the impact the fist stops on the target: only part of
    the source's travel past that point is kept for ~0.07 s (`follow`), so
    the hit-stop freezes a clean pose. The clip blends back into the exact
    Guard pose at the end (smoothstep), and the controller's own 0.12 s
    fade-out happens on that Guard pose.
  • Keys: the dense 60 fps result is reduced to a few keys (greedy, error
    bounded, using the game's own Hermite spline), the impact key at 0.15 s
    is always kept.
"""

import argparse
import json
import math
import os
import re

import numpy as np
from scipy.optimize import least_squares

FPS = 60
JOINTS = ("Root", "Neck", "RightShoulder", "LeftShoulder", "RightHip", "LeftHip")
CLIPS_FILE = os.path.join(os.path.dirname(__file__), "..", "..", "src", "client", "Animation", "CombatClips.luau")

# Our Guard pose (first key of the Guard clip) with the legs straight: every
# punch starts and ends EXACTLY here so the combo chains.
GUARD = {
    "Root": ((-8, -12, 0), (0, 0, 0)),
    "Neck": ((6, 10, 0), (0, 0, 0)),
    "RightShoulder": ((111, 0, -36.5), (0, 0, 0)),
    "LeftShoulder": ((115, 0, 37), (0, 0, 0)),
    "RightHip": ((0, 0, 0), (0, 0, 0)),
    "LeftHip": ((0, 0, 0), (0, 0, 0)),
}

# ---------------------------------------------------------------- the 4 punches
# src / mirror: the source animation, mirrored (left <-> right) or not.
# hand: the punching hand ON OUR RIG (after mirroring).
# warp: the time warp, as (game time s, source frame, speed) anchors. Source
#   frames are indices in the dump (0 = first frame of the FBX, 30 per
#   second); speed = how fast the source plays there (1 = real time, 2 =
#   twice as fast). The anchor at 0.15 s is the impact. Between anchors the
#   source frame follows a smooth curve (cubic Hermite) that never goes back.
# contact: where our fist must be at 0.15 s (root space, studs, -Z forward).
# snap: > 1 makes the fist's progress toward the impact point end faster
#   (progress ** snap): mocap fists slow down before full extension because
#   the actor punched air; in game the fist must still be fast at the impact.
# follow: how much of the source fist's travel PAST the impact point is kept
#   until `hold` (seconds): a real punch stops on the head, the actor punched
#   air and kept extending. 1 = all of it. It is back to 1 at hold + 0.08 s.
# yaw: torso turn (Root yaw, degrees) at the impact; yaw_max: the turn never
#   goes past this (degrees, either way), so the follow-through can't over-rotate.
# drive: extra torso turn (degrees) just after the impact, given back before
#   the return to the guard (default 0): the body drives through the target.
# lunge: Root pos at the impact (lean / drop / forward), studs.
# reach: how far the shoulder is pushed forward at full extension, studs.
# loop: how much of the fist path's sideways/vertical arc is kept (1 = all,
#   more than 1 widens it: the hook's arc must read on a straight R6 arm).
# loop_up: extra scale on the vertical part of that arc only (default 1).
# legs: how much of the source's foot steps is kept (0 = our planted Guard legs).
# lean: extra forward lean (Root pitch, degrees) at the impact.
# tilt: how much of the chest's lean / roll is kept; hips: how much of the
#   pelvis' own drift (beyond the lunge) is kept.
# back: (start, end) of the blend back into the Guard pose, seconds.
SPECS = {
    "Brawler_M1_1": {
        "src": "jab_right",
        "mirror": True,
        "hand": "Left",
        "warp": [(0.0, 6.8, 0.8), (0.15, 11.2, 2.6), (0.19, 16.0, 1.8), (0.34, 23.5, 0.6)],
        "contact": (-0.03, 0.68, -2.72),
        "snap": 1.4,
        "follow": 0.55,
        "hold": 0.22,
        "yaw": -35,
        "yaw_max": 40,
        "lunge": (-0.1, -0.2, -0.42),
        "reach": 0.45,
        "loop": 1.0,
        "legs": 0.6,
        "lean": -4,
        "tilt": 0.5,
        "hips": 0.5,
        "back": (0.26, 0.38),
        "length": 0.5,
        "about": "Left jab (combo hit 1): the lead hand snaps straight out while the hips and\n"
        "\t-- shoulders turn together, then a fast return to the guard.",
    },
    "Brawler_M1_2": {
        "src": "combo_punch_kick",
        "mirror": False,
        "hand": "Right",
        "warp": [(0.0, 57.5, 0.8), (0.15, 65.7, 2.0), (0.2, 67.3, 0.5), (0.36, 74.5, 1.4)],
        "contact": (-0.02, 0.62, -2.83),
        "snap": 1.5,
        "follow": 0.55,
        "hold": 0.22,
        "yaw": 40,
        "yaw_max": 45,
        "lunge": (-0.06, -0.2, -0.34),
        "reach": 0.45,
        "loop": 1.0,
        "legs": 0.0,
        "lean": 0,
        "tilt": 0.3,
        "hips": 0.15,
        "back": (0.26, 0.4),
        "length": 0.5,
        "about": "Right cross (combo hit 2): the hips start the turn, the chest follows, the\n"
        "\t-- rear hand drives straight through the centre line, the left fist stays at the chin.",
    },
    "Brawler_M1_3": {
        "src": "hook_left",
        "mirror": False,
        "hand": "Left",
        "warp": [(0.0, 21.5, 0.6), (0.15, 28.6, 1.4), (0.2, 29.5, 0.3), (0.25, 29.7, 0.1)],
        "contact": (-0.21, 0.8, -2.22),
        "snap": 1.3,
        "follow": 0.25,
        "hold": 0.22,
        "yaw": -49,
        "yaw_max": 55,
        "lunge": (-0.12, -0.2, -0.08),
        "reach": 0.3,
        "loop": 1.5,
        "loop_up": 0.3,
        "legs": 0.0,
        "lean": -3,
        "tilt": 0.5,
        "hips": 0.5,
        "back": (0.19, 0.37),
        "length": 0.5,
        "about": "Left hook (combo hit 3): the fist goes out, then whips across at head height\n"
        "\t-- with the chest turn; the follow-through is cut short and eases back to the guard.",
    },
    "Brawler_M1_4": {
        "src": "cross_right",
        "mirror": False,
        "hand": "Right",
        "warp": [(0.0, 9, 2.0), (0.08, 19, 3.0), (0.15, 23.7, 3.4), (0.2, 25.8, 0.9), (0.72, 40, 0.3)],
        "contact": (0.06, 0.92, -2.5),
        "snap": 1.8,
        "follow": 0.5,
        "hold": 0.22,
        "yaw": 50,
        "yaw_max": 58,
        "drive": 8,
        "lunge": (-0.12, -0.28, -0.5),
        "reach": 0.45,
        "loop": 0.4,
        "legs": 0.8,
        "lean": -6,
        "tilt": 0.5,
        "hips": 0.5,
        "back": (0.58, 0.73),
        "length": 0.85,
        "about": "Overhand right (combo FINISHER): the rear hand loops out and comes over the\n"
        "\t-- top with the whole body turning in, the rear heel drives; heavy, slower recovery.\n"
        "\t-- Longer than the others: see Config.Combat.FINISHER_RECOVERY.",
    },
}


class Warp:
    """Game time -> source frame: a cubic Hermite curve through the anchors
    (time, frame, speed), with the slope at each anchor = speed x 30 frames
    per second. Checked to never go back in time (monotone)."""

    def __init__(self, anchors):
        self.t = [a[0] for a in anchors]
        self.f = [float(a[1]) for a in anchors]
        self.v = [a[2] * 30.0 for a in anchors]
        prev = -1e9
        for i in range(int(self.t[-1] * 1000) + 1):
            x = self(i / 1000)
            assert x >= prev - 1e-6, f"time warp goes back in time near {i / 1000:.3f} s"
            prev = x

    def __call__(self, t):
        t = min(max(t, self.t[0]), self.t[-1])
        i = max(k for k in range(len(self.t) - 1) if self.t[k] <= t) if t < self.t[-1] else len(self.t) - 2
        span = self.t[i + 1] - self.t[i]
        u = (t - self.t[i]) / span
        h00, h10, h01, h11 = 2 * u**3 - 3 * u**2 + 1, u**3 - 2 * u**2 + u, -2 * u**3 + 3 * u**2, u**3 - u**2
        return h00 * self.f[i] + h10 * span * self.v[i] + h01 * self.f[i + 1] + h11 * span * self.v[i + 1]


# ---------------------------------------------------------------- R6 rig (same math as Motor6D)
ROOTR = (-1, 0, 0, 0, 0, 1, 0, 1, 0)
RS = (0, 0, 1, 0, 1, 0, -1, 0, 0)
LS = (0, 0, -1, 0, 1, 0, 1, 0, 0)


def cfm(x, y, z, *r):
    m = np.eye(4)
    m[:3, 3] = (x, y, z)
    m[:3, :3] = np.array(r, dtype=float).reshape(3, 3)
    return m


# joint: (parent part, part, C0, C1)
RIG = {
    "Root": ("HRP", "Torso", cfm(0, 0, 0, *ROOTR), cfm(0, 0, 0, *ROOTR)),
    "Neck": ("Torso", "Head", cfm(0, 1, 0, *ROOTR), cfm(0, -0.5, 0, *ROOTR)),
    "RightShoulder": ("Torso", "Right Arm", cfm(1, 0.5, 0, *RS), cfm(-0.5, 0.5, 0, *RS)),
    "LeftShoulder": ("Torso", "Left Arm", cfm(-1, 0.5, 0, *LS), cfm(0.5, 0.5, 0, *LS)),
    "RightHip": ("Torso", "Right Leg", cfm(1, -1, 0, *RS), cfm(0.5, 1, 0, *RS)),
    "LeftHip": ("Torso", "Left Leg", cfm(-1, -1, 0, *LS), cfm(-0.5, 1, 0, *LS)),
}


def angles(x, y, z):
    """CFrame.Angles(x, y, z) = Rx Ry Rz, radians, 3x3."""
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return rx @ ry @ rz


def euler(r):
    """The Rx Ry Rz angles (radians) of a rotation matrix."""
    y = math.asin(max(-1.0, min(1.0, r[0, 2])))
    return math.atan2(-r[1, 2], r[2, 2]), y, math.atan2(-r[0, 1], r[0, 0])


def solve(pose):
    """World matrix of every part (HRP at the origin). pose: joint -> (rot deg, pos)."""
    world = {"HRP": np.eye(4)}
    for name in JOINTS:
        parent, part, c0, c1 = RIG[name]
        rot, pos = pose[name]
        local = np.eye(4)
        local[:3, :3] = angles(*np.radians(rot))
        local[:3, 3] = pos
        axes = np.eye(4)
        axes[:3, :3] = c0[:3, :3]
        world[part] = world[parent] @ c0 @ (np.linalg.inv(axes) @ local @ axes) @ np.linalg.inv(c1)
    return world


def fist(pose, side):
    """Centre of the bottom of the arm (the fist), root space."""
    return (solve(pose)[side + " Arm"] @ np.array([0, -1.0, 0, 1]))[:3]


def lowest(world, part):
    m = world[part]
    return min((m @ np.array([x, -1, z, 1]))[1] for x in (-0.5, 0.5) for z in (-0.5, 0.5))


GUARD_WORLD = solve(GUARD)
# The Guard's soles: the torso leans 8 degrees, so its lowest corner is a bit
# under y = -3; that is "the floor" for these clips (legs straight in Guard).
FLOOR = min(lowest(GUARD_WORLD, "Left Leg"), lowest(GUARD_WORLD, "Right Leg"))
GUARD_FOOT = {s: (GUARD_WORLD[s + " Leg"] @ np.array([0, -1.0, 0, 1]))[:3] for s in ("Left", "Right")}
GUARD_FIST = {s: fist(GUARD, s) for s in ("Left", "Right")}
GUARD_HEAD = GUARD_WORLD["Head"][:3, 3]
# how high each Guard fist sits above its shoulder pivot (studs)
GUARD_LIFT = {
    s: GUARD_FIST[s][1] - (GUARD_WORLD["Torso"] @ np.array([1.0 if s == "Right" else -1.0, 0.5, 0, 1]))[1]
    for s in ("Left", "Right")
}


# ---------------------------------------------------------------- source data
M = np.array([[-1, 0, 0], [0, 0, 1], [0, 1, 0]], dtype=float)  # source -> Roblox axes
SX = np.diag([-1.0, 1.0, 1.0])  # mirror (source X)


class Source:
    """One dumped animation, mirrored if asked, readable at fractional frames."""

    def __init__(self, path, mirror):
        data = json.load(open(path))
        self.frames = data["frames"]
        self.mirror = mirror
        rest = data["rest"]
        # studs per metre: legs by the hip height (R6 hips are 2 studs up),
        # arms by the arm length (R6 shoulder pivot -> fist = 1.581 studs)
        self.k_leg = 2.0 / rest["LeftLeg"]["head"][2]
        arm = np.linalg.norm(np.array(rest["LeftHandMiddle1"]["head"]) - np.array(rest["LeftArm"]["head"]))
        self.k_arm = 1.581 / arm

    def _name(self, bone):
        if not self.mirror:
            return bone
        if bone.startswith("Left"):
            return "Right" + bone[4:]
        if bone.startswith("Right"):
            return "Left" + bone[5:]
        return bone

    def _at(self, f, fn):
        f = min(max(f, 0.0), len(self.frames) - 1.0)
        i = min(int(f), len(self.frames) - 2)
        u = f - i
        return fn(self.frames[i]) * (1 - u) + fn(self.frames[i + 1]) * u

    def pos(self, bone, f):
        """Position (metres) in Roblox axes, mirrored if asked."""
        b = self._name(bone)
        p = self._at(f, lambda fr: np.array(fr[b]["head"], dtype=float))
        if self.mirror:
            p = SX @ p
        return M @ p

    def rot(self, bone, f):
        """World rotation (Roblox axes). Blended per frame, then re-orthogonalised."""
        b = self._name(bone)
        r = self._at(f, lambda fr: np.array(fr[b]["rot"], dtype=float))
        u, _, vt = np.linalg.svd(r)
        r = u @ vt
        if self.mirror:
            r = SX @ r @ SX
        return M @ r @ M.T

    def extension(self, side, f):
        """Shoulder -> knuckle distance over the arm length (1 = arm straight)."""
        d = self.pos(side + "HandMiddle1", f) - self.pos(side + "Arm", f)
        return float(np.linalg.norm(d)) * self.k_arm / 1.581


# ---------------------------------------------------------------- solvers
def solve_arm(pose, joint, side, target, reach, guess):
    """Shoulder angles (X, Z; Y = 0 like every clip) putting the fist on target.

    reach = how far the shoulder should be pushed forward (studs): the solver
    may push it a bit more or less (even pull it back a little) when the
    target is out of reach of a rigid 1.58-stud arm, or too close to it.
    guess = the previous frame's answer (X, Z, push): starting from it keeps
    the arm on the same solution (no flip to an arm going over the top)."""

    def put(v):
        pose[joint] = ((v[0], 0.0, v[1]), (0.0, -0.04 * v[2], -v[2]))

    def resid(v):
        put(v)
        return np.concatenate(
            [(fist(pose, side) - target) * 10, [(v[2] - reach) * 3], (v[:2] - guess[:2]) * 0.005]
        )

    start = np.array(guess, dtype=float)
    start[2] = min(0.54, max(-0.14, start[2]))
    sol = least_squares(resid, start, bounds=([-90, -150, -0.15], [250, 150, 0.55]))
    put(sol.x)
    return sol.x


def solve_leg(pose, joint, side, foot_xz, yaw, guess):
    """Aim the leg at its foot spot, then slide it up/down (fake knee) so the
    sole touches the floor. Returns (X, Z) angles."""
    part = side + " Leg"

    def resid(v):
        pose[joint] = ((v[0], yaw, v[1]), (0.0, 0.0, 0.0))
        m = solve(pose)[part]
        top = m[:3, 3] + m[:3, 1]  # centre of the top of the leg
        down = -m[:3, 1]
        want = np.array([foot_xz[0], FLOOR, foot_xz[1]]) - top
        return np.concatenate([down - want / np.linalg.norm(want), (v - guess) * 0.001])

    sol = least_squares(resid, np.asarray(guess, dtype=float))
    rot = (sol.x[0], yaw, sol.x[1])
    py = 0.0
    for _ in range(30):  # slide the leg so its lowest corner is on the floor
        pose[joint] = (rot, (0.0, py, 0.0))
        err = FLOOR - lowest(solve(pose), part)
        if abs(err) < 1e-4:
            break
        py += err
    pose[joint] = (rot, (0.0, py, 0.0))
    return sol.x


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- one clip, dense
def retarget(dump_dir, name):
    spec = SPECS[name]
    src = Source(os.path.join(dump_dir, spec["src"] + ".json"), spec["mirror"])
    warp = Warp(spec["warp"])
    hand = spec["hand"]
    other = "Right" if hand == "Left" else "Left"
    g = warp(0.0)  # the source's guard frame
    c = warp(0.15)  # the source's impact frame

    # torso: the chest's rotation since the guard frame (world axes), split
    # into a turn about the vertical (yaw: where the chest's front points)
    # and what is left (lean forward/back, roll), so a big turn never leaks
    # into the lean
    chest_g = src.rot("Chest", g)

    def heading(v):
        return math.atan2(-v[0], -v[2])  # 0 = facing -Z, + = turned left

    def chest_delta(f):
        rel = src.rot("Chest", f) @ chest_g.T
        front = rel @ np.array([0.0, 0.0, -1.0])
        dyaw = heading(front)
        dx, _, dz = euler(angles(0, -dyaw, 0) @ rel)
        return np.degrees(np.array([dx, dyaw, dz]))

    yaw_scale = (spec["yaw"] - GUARD["Root"][0][1]) / chest_delta(c)[1]

    # fist paths relative to the source's guard frame, in R6 arm scale
    def knuckle(side, f):
        return (src.pos(side + "HandMiddle1", f) - src.pos(side + "HandMiddle1", g)) * src.k_arm

    def pelvis(f):
        return (src.pos("Spine1", f) - src.pos("Spine1", g)) * src.k_leg

    d_c = knuckle(hand, c)
    p_c = pelvis(c)
    e_g, e_c = src.extension(hand, g), src.extension(hand, c)
    contact = np.array(spec["contact"], dtype=float)
    lunge = np.array(spec["lunge"], dtype=float)
    feet0 = {s: src.pos(s + "Foot", g) for s in ("Left", "Right")}

    frames = []
    guess = {
        "RightShoulder": np.array([111.0, -36.5, 0.0]),
        "LeftShoulder": np.array([115.0, 37.0, 0.0]),
        "RightHip": np.zeros(2),
        "LeftHip": np.zeros(2),
    }
    n = int(round(spec["length"] * FPS))
    for i in range(n + 1):
        t = i / FPS
        f = warp(t)
        # how far along the punch we are (0 = guard, 1 = impact, a bit more
        # past it), from the source fist's progress toward its impact position
        d = knuckle(hand, f)
        w = float(np.clip(d @ d_c / (d_c @ d_c), 0.0, 1.3))

        # Root: the Guard's lean / turn plus the chest's (turn scaled to the
        # target, lean and roll kept small: an R6 torso is one stiff block),
        # plus the lunge
        dx, dy, dz = chest_delta(f)
        g_rot = GUARD["Root"][0]
        # `drive`: the torso keeps turning a little after the impact (the
        # body's weight goes through the target while the fist stays on it),
        # then gives it back before the return to the guard
        drive = spec.get("drive", 0.0) * math.copysign(1.0, spec["yaw"] - g_rot[1])
        drive *= smoothstep(0.12, 0.24, t) * (1 - smoothstep(0.24, spec["back"][0] + 0.1, t))
        rot = (
            g_rot[0] + float(np.clip(dx * spec["tilt"], -10, 4)) + w * spec["lean"],
            float(np.clip(g_rot[1] + dy * yaw_scale + drive, -spec["yaw_max"], spec["yaw_max"])),
            g_rot[2] + float(np.clip(dz * spec["tilt"], -8, 8)),
        )
        pos = w * lunge + spec["hips"] * (pelvis(f) - w * p_c)
        pos = np.clip(pos, (-0.25, -0.36, -0.6), (0.25, 0.05, 0.22))
        pose = dict(GUARD)  # (joints not solved yet keep their Guard values)
        pose["Root"] = (tuple(rot), tuple(pos))
        # Neck: undo most of the torso's turn and lean (eyes on the target)
        pose["Neck"] = (
            (6 - 0.75 * (rot[0] - g_rot[0]), 10 - 0.83 * (rot[1] - g_rot[1]), -0.8 * (rot[2] - g_rot[2])),
            (0.0, 0.0, 0.0),
        )
        # punching arm: fist target = straight line Guard fist -> contact, plus
        # the source's arc around that line (scaled by `loop`)
        # (`snap` > 1 bends the progress so it ends faster: the mocap actor
        # slowed down before full extension, a punch that hits doesn't)
        ws = w ** spec["snap"] if w < 1 else w
        arc = spec["loop"] * (d - w * d_c)
        # (the arc's up / down part has its own scale: a hook travels at head
        # height, it must not scoop down to the chest and come back up)
        arc[1] *= spec.get("loop_up", 1.0)
        target = GUARD_FIST[hand] + ws * (contact - GUARD_FIST[hand]) + arc
        if t > 0.15:
            # the impact: the fist stops ON the head (only `follow` of the
            # source's travel past the impact point is kept for a moment)
            keep = spec["follow"] + (1 - spec["follow"]) * smoothstep(spec["hold"], spec["hold"] + 0.08, t)
            target = contact + keep * (target - contact)
        ext = (src.extension(hand, f) - e_g) / max(1e-6, e_c - e_g)
        reach = spec["reach"] * float(np.clip(ext, 0.0, 1.05))
        j = hand + "Shoulder"
        guess[j] = solve_arm(pose, j, hand, target, reach, guess[j])
        # other arm: stays up by the chin. It follows the head (and a third of
        # the torso turn), and its fist is never let down to shoulder height:
        # an R6 arm is rigid, so a fist at shoulder height is a straight arm
        # held out horizontally, which reads as a second punch, not a guard.
        world = solve(pose)
        head = world["Head"][:3, 3]
        turn = angles(0, math.radians(0.3 * (rot[1] - g_rot[1])), 0)
        drift = 0.4 * knuckle(other, f)
        if np.linalg.norm(drift) > 0.25:
            drift *= 0.25 / np.linalg.norm(drift)
        o_target = head + turn @ (GUARD_FIST[other] - GUARD_HEAD) + drift
        pivot = world["Torso"] @ np.array([1.0 if other == "Right" else -1.0, 0.5, 0, 1])
        o_target[1] = max(o_target[1], pivot[1] + GUARD_LIFT[other])
        j = other + "Shoulder"
        guess[j] = solve_arm(pose, j, other, o_target, 0.0, guess[j])
        # legs: Guard feet + the source's steps (if kept); the legs turn a
        # little with the hips (heel pivot) instead of twisting over glued feet
        hip_yaw = -0.35 * (rot[1] - g_rot[1])
        for s in ("Left", "Right"):
            step = (src.pos(s + "Foot", f) - feet0[s]) * src.k_leg * spec["legs"]
            step = np.clip(step, -0.35, 0.35)
            foot = (GUARD_FOOT[s][0] + step[0], GUARD_FOOT[s][2] + step[2])
            j = s + "Hip"
            guess[j] = solve_leg(pose, j, s, foot, hip_yaw, guess[j])

        # blend into the exact Guard pose at the start and the end
        a = smoothstep(0.0, 0.05, t) * (1 - smoothstep(spec["back"][0], spec["back"][1], t))
        out = {}
        for jn in JOINTS:
            r0, p0 = (np.array(v, dtype=float) for v in GUARD[jn])
            r1, p1 = (np.array(v, dtype=float) for v in pose[jn])
            out[jn] = (r0 + (r1 - r0) * a, p0 + (p1 - p0) * a)
        if 0 < a < 1:
            # blending the angles doesn't keep the soles on the floor: slide
            # each leg up or down again so they touch it
            for s in ("Left", "Right"):
                j = s + "Hip"
                for _ in range(30):
                    err = FLOOR - lowest(solve(out), s + " Leg")
                    if abs(err) < 1e-4:
                        break
                    out[j] = (out[j][0], out[j][1] + np.array([0.0, err, 0.0]))
        frames.append(out)
    return frames


# ---------------------------------------------------------------- R6Pose spline (as in the game)
def sample(keys, t):
    """keys: list of (time, pose, tangent). Same Hermite spline as R6Pose.sample."""
    times = [k[0] for k in keys]
    n = len(keys)
    if t <= times[0]:
        return keys[0][1]
    if t >= times[-1]:
        return keys[-1][1]
    i = max(k for k in range(n) if times[k] <= t)
    t0, t1 = times[i], times[i + 1]
    span = t1 - t0
    u = (t - t0) / span

    def slope(k, jn, f):
        if k <= 0 or k >= n - 1 or keys[k][2] == "flat":
            return np.zeros(3)
        return (keys[k + 1][1][jn][f] - keys[k - 1][1][jn][f]) / (times[k + 1] - times[k - 1])

    h00, h10, h01, h11 = 2 * u**3 - 3 * u**2 + 1, u**3 - 2 * u**2 + u, -2 * u**3 + 3 * u**2, u**3 - u**2
    out = {}
    for jn in JOINTS:
        out[jn] = tuple(
            h00 * keys[i][1][jn][f]
            + h10 * span * slope(i, jn, f)
            + h01 * keys[i + 1][1][jn][f]
            + h11 * span * slope(i + 1, jn, f)
            for f in (0, 1)
        )
    return out


def rounded(pose):
    return {
        jn: (np.round(np.array(r, dtype=float), 1) + 0.0, np.round(np.array(p, dtype=float), 2) + 0.0)
        for jn, (r, p) in pose.items()
    }


def reduce_keys(frames, contact_index, max_keys=14):
    """Keep the fewest frames as keys so the game's spline through them stays
    within ~1.5 degrees / 0.02 stud of every joint and 0.04 stud of both fists
    (greedy: add the worst frame until it fits). The impact frame is a key."""
    n = len(frames)
    dense = [rounded(p) for p in frames]
    fists = [{s: fist(p, s) for s in ("Left", "Right")} for p in dense]
    # the frame just before the impact is a key too, so the spline keeps the
    # fist's full speed into the impact (it would round it off otherwise)
    chosen = {0, contact_index - 1, contact_index, n - 1}
    # the end of the clip is the plain Guard: one key where the blend finishes
    for i in range(n - 1, 0, -1):
        if any(np.abs(dense[i][jn][0] - dense[-1][jn][0]).max() > 0.05 for jn in JOINTS):
            chosen.add(min(n - 1, i + 1))
            break
    while True:
        idx = sorted(chosen)
        keys = [(i / FPS, dense[i], "smooth") for i in idx]
        worst, at = 0.0, None
        for i in range(n):
            if i in chosen:
                continue
            p = sample(keys, i / FPS)
            err = 0.0
            for jn in JOINTS:
                err = max(err, np.abs(np.array(p[jn][0]) - dense[i][jn][0]).max() / 1.5)
                err = max(err, np.abs(np.array(p[jn][1]) - dense[i][jn][1]).max() / 0.02)
            for s in ("Left", "Right"):
                err = max(err, float(np.linalg.norm(fist(p, s) - fists[i][s])) / 0.04)
            # and the spline must not push a foot into the floor (5 mm allowed)
            world = solve({jn: (np.array(r), np.array(q)) for jn, (r, q) in p.items()})
            for leg in ("Left Leg", "Right Leg"):
                err = max(err, (FLOOR - 0.005 - lowest(world, leg)) / 0.003)
            if err > worst:
                worst, at = err, i
        if worst <= 1.0 or at is None or len(chosen) >= max_keys:
            return keys, worst
        chosen.add(at)


# ---------------------------------------------------------------- Luau
def num(x, d=2):
    s = f"{x:.{d}f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "", "-") else s


def vec(v, d=2):
    return f"Vector3.new({', '.join(num(float(a), d) for a in v)})"


def luau(name, keys, length):
    spec = SPECS[name]
    first = spec["warp"][0][1]
    last = spec["warp"][-1][1]
    impact = Warp(spec["warp"])(0.15)
    side = ", mirrored (left and right swapped)" if spec["mirror"] else ""
    lines = [
        f"\t-- {spec['about']}",
        f"\t-- Source: Motifect Combat Motion Pack `{spec['src']}` frames {first}-{last}{side}; its frame",
        f"\t-- {num(impact, 1)} is the impact, at 0.15 s = Config.Combat.HIT_DELAY.",
        "\t-- Generated by tools/anim/motifect_retarget.py (edit the script, not these keys).",
        f"\t{name} = {{",
        f"\t\tlength = {num(length)},",
        "\t\tlooped = false,",
        "\t\tkeyframes = {",
    ]
    for t, pose, tangent in keys:
        lines.append("\t\t\t{")
        lines.append(f"\t\t\t\ttime = {num(t, 3)},")
        if tangent == "flat":
            lines.append('\t\t\t\ttangent = "flat",')
        lines.append("\t\t\t\tpose = {")
        for jn in JOINTS:
            r, p = pose[jn]
            s = f"rot = {vec(r, 1)}"
            if np.abs(p).max() > 0.004:
                s += f", pos = {vec(p)}"
            lines.append(f"\t\t\t\t\t{jn} = {{ {s} }},")
        lines.append("\t\t\t\t},")
        lines.append("\t\t\t},")
    lines += ["\t\t},", "\t},"]
    return "\n".join(lines) + "\n"


def replace_block(text, name, block):
    """Replace `name = {...},` and the comment lines right above it."""
    start = text.index(f"\n\t{name} = {{\n") + 1
    end = text.index("\n\t},\n", start) + len("\n\t},\n")
    while True:  # include the comment lines above
        prev = text.rfind("\n", 0, start - 1) + 1
        if text[prev:start].startswith("\t--"):
            start = prev
        else:
            break
    return text[:start] + block + text[end:]


def build(dump_dir):
    out = {}
    for name, spec in SPECS.items():
        frames = retarget(dump_dir, name)
        keys, err = reduce_keys(frames, int(round(0.15 * FPS)), 12 + int(spec["length"] * 6))
        out[name] = {"length": spec["length"], "keys": keys, "dense": frames, "fit": err}
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("dump_dir")
    ap.add_argument("--write", action="store_true", help="replace the Brawler_M1_N blocks in CombatClips.luau")
    ap.add_argument("--json", help="also save the clips (anim.py format) to this file")
    args = ap.parse_args()
    clips = build(args.dump_dir)
    for name, c in clips.items():
        k = c["keys"]
        p = sample(k, 0.15)
        print(f"{name}: {len(k)} keys, fit error {c['fit']:.2f}, fist at 0.15 s {np.round(fist(p, SPECS[name]['hand']), 2)}")
    if args.json:
        js = {}
        for name, c in clips.items():
            keys = []
            for t, pose, tangent in c["keys"]:
                keys.append({"time": round(t, 3), "tangent": tangent, "pose": {jn: {"rot": [float(a) for a in r], "pos": [float(a) for a in p]} for jn, (r, p) in pose.items()}})
            js[name] = {"length": c["length"], "looped": False, "keys": keys}
        json.dump(js, open(args.json, "w"), indent=1)
    if args.write:
        text = open(CLIPS_FILE).read()
        for name, c in clips.items():
            text = replace_block(text, name, luau(name, [(round(t, 3), p, tg) for t, p, tg in c["keys"]], c["length"]))
        open(CLIPS_FILE, "w").write(text)
        print("wrote", os.path.normpath(CLIPS_FILE), "(run `stylua src` to format it)")


if __name__ == "__main__":
    main()
