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
or knees, and gameplay fixes the timing (impact at Config.Combat.M1_HIT_DELAY:
0.15 s for the jab and the hook; the cross and the finisher are CHARGED and
land at 0.28 / 0.38 s, see "Charged punches" below). So:

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
    impact lands exactly at 0.15 s. The first ~0.07-0.08 s play the
    source's own small load (cross, hook, overhand) or hold its guard frame
    (jab); the source's strike is then played in the last ~4-5 frames
    before the impact, fastest right before it (mocap punches slow down
    before full extension, a punch that lands doesn't). At the impact the
    fist stops on the target: only part of the source's travel past that
    point is kept for ~0.07 s (`follow`), so the hit-stop freezes a clean
    pose.
  • Wind-up (`windup`, see wind_env()): the pack's boxers barely telegraph
    (a 7-degree counter-turn at most, the fist never goes back), and 0.15 s
    is short, so a punch read as "the arm just goes". On top of the mocap we
    add a LOAD, then let it go as a KINETIC CHAIN, like a real boxer:
      - load (0 -> ~0.07 s, eased into a near-still loaded pose): the torso
        turns AGAINST the punch, the weight sits down and shifts onto the
        loading leg (Root pos; the legs bend through the fake knee), the
        punching shoulder is pulled back and the fist comes back toward the
        chin (on a rigid R6 arm, a fist closer to the shoulder reads as a
        folded elbow), the chin tucks, the other fist stays up;
      - strike: each part lets go of its load one after the other, legs and
        weight first, then the torso turn, then lean / roll, the shoulder,
        the arm last. On a rigid R6 arm the fist can't "stay behind" while
        the shoulder comes forward (it would have to slide in its socket),
        so the arm is first CARRIED, still folded, by the turning body, then
        it extends: the straight punches and the overhand are worked out
        from the shoulder (arm_target: shoulder + an arm vector that turns
        toward the target and lengthens, fastest at the end), so the fist's
        speed is the body's plus the arm's and rises every frame into the
        impact. The hook keeps its re-timed "out, then across" path.
  • Recovery: the arm comes back first, on a slow-in slow-out curve; the
    torso keeps turning a few degrees after the impact (`drive`, the weight
    sinks a little: no freeze on the hit-stop), then its turn comes back
    on its own curve (`yaw_back`) and stops a few degrees short of the Guard
    on the follow-through side until 0.38 s (`yaw_hold`): in the combo the
    next punch's load continues that way, so the torso never turns back and
    forth around a click. The clip is the exact Guard pose by its end (the
    controller's 0.12 s fade-out covers the last few degrees).
  • Charged punches (M1_2 cross, M1_4 finisher; spec "charge", see
    charged()): the player wanted these two to CHARGE: the arm goes back to
    the level of the back, like a big run-up. Their Motifect clip (made as
    above, impact at 0.15 s) is moved later so its impact lands at 0.28 /
    0.38 s, and the time before that is an authored wind-up: the arm swept
    back (cross: out to the side and back at shoulder height, fist well
    behind the body; finisher: out, up and back, fist behind the head), the torso coiled 54-64 degrees
    past the Guard, the weight down on the bent rear leg, the head on the
    target, the lead hand up (cross) or aiming at the target (finisher); a
    short held charge (5 / 4 frames, a "flat" key); then the strike: legs and
    weight first, the torso, the arm last, each faster every frame into the
    impact (the arm's last frames are a 140-155 stud/s "smear").
  • Keys: the dense 60 fps result is reduced to a few keys (greedy, error
    bounded, using the game's own Hermite spline), the impact key is always
    kept.
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
# drive: extra torso turn (degrees) after the impact, reached at `drive_end`
#   (seconds, slowing down; default 0.23): the body keeps going through the
#   target while the fist stays on it, so nothing freezes on the hit-stop.
#   sink: the weight keeps dropping that much (studs) over the same time.
# lunge: Root pos at the impact (lean / drop / forward), studs.
# reach: how far the shoulder is pushed forward at full extension, studs.
# loop: how much of the fist path's sideways/vertical arc is kept (1 = all,
#   more than 1 widens it: the hook's arc must read on a straight R6 arm).
# loop_up: extra scale on the vertical part of that arc only (default 1).
# legs: how much of the source's foot steps is kept (0 = our planted Guard legs).
# lean: extra forward lean (Root pitch, degrees) at the impact.
# tilt: how much of the chest's lean / roll is kept; hips: how much of the
#   pelvis' own drift (beyond the lunge) is kept.
# back: (start, end) of the arm's blend back into the Guard pose, seconds;
# back_lag: how much later (seconds) the head, legs and the torso's lean /
#   weight follow it.
# yaw_back: (start, end) of the torso TURN's own return, seconds; it stops
#   `yaw_hold` degrees short of the Guard, on the follow-through side, until
#   0.38 s, then reaches the Guard at 0.48 s (combo pre-load, see retarget()).
# windup: the load added on top of the mocap before the strike (see wind_env):
#   peak: when the loaded pose is reached (seconds, eased into it);
#   yaw: torso turn AGAINST the punch (degrees, on top of the source's own);
#   pitch / roll: torso lean (+ = upright) / roll (+ = left shoulder down);
#   pos: Root pos at the load (x right, y up, z back, studs): the weight sits
#     down and goes onto the loading leg (the legs bend through the fake knee);
#   tuck: chin down (Neck pitch, degrees);
#   retract: punching shoulder pulled back (studs): with the fist pulled in,
#     the rigid arm reads as a folded elbow, and the push to `reach` at the
#     impact as the arm extending;
#   fist: the fold: the punching fist's offset at the load (root space studs,
#     +z = back toward the body), on top of where the torso carries it;
#   carry / socket: how the torso carries the fist during the load (see
#     load_target in retarget());
#   off: the other fist's offset at the load;
#   pull: how far the punching shoulder may go back (studs, default 0.18);
#     step: the most it may slide in one frame (studs, default no limit);
#   chain: (release start, release end) per channel, seconds: when each part
#     lets go of its load. Legs/weight (pos) first, then the torso turn (yaw),
#     lean/roll (tilt), the shoulder, the fist last (released along a curve
#     that accelerates all the way into the impact at 0.15 s);
#   lunge_end: when the forward lunge would end (default 0.165 s): later =
#     the body still moves forward fast at the impact;
#   yaw_end / yaw_shape: the torso turn's slow-in slow-out curve ends at
#     yaw_end; yaw_shape > 1 moves its fastest moment later;
#   arm_space: the strike is worked out from the shoulder (see arm_target);
#     accel / len_accel: how late the arm turns / lengthens (higher = later
#     and faster into the impact); bump / bump_at: the overhand's lift;
#     without arm_space (the hook) the fist follows its re-timed path, its
#     distance covered growing as u^accel, corners rounded by `smooth`.
# charge: a CHARGED punch (see charged()): the Motifect impact, drive and
#   recovery come later (at `hit`, seconds) after a big authored wind-up.
#   keys: the wind-up, as (time, Root rot, Root pos, punching shoulder rot,
#     punching shoulder pos, other shoulder rot) (degrees / studs, R6Pose
#     values, Guard at 0 s). The last key is the end of the held charge (a
#     "flat" key); the one before it is the loaded pose.
#   via: shoulder angles the punching arm passes through during the strike.
#   chain: when each part leaves the charged pose (seconds) and its speed at
#     the impact (see let_go; the arm: its path is covered as u^this).
#   smooth: rounds the arm path's corners (degrees). tuck: chin down (deg).
CROSS_CHARGE = {
    "hit": 0.28,
    "keys": [
        # leave Guard: the torso starts to coil, the arm opens out to the side
        (0.05, (-6, -25, -2), (0.04, -0.06, 0.04), (104, 0, 4), (0, 0, 0.04), (117, 0, 28)),
        # swing back: the arm, raised to the side, sweeps back; weight sits back
        (0.1, (-4, -50, -5), (0.12, -0.17, 0.15), (30, 0, 72), (0, 0.01, 0.15), (120, 0, 10)),
        # loaded: arm swept back at shoulder height (the fist sticks out of the
        # silhouette, well behind the body), torso coiled ~50 deg past the
        # Guard, weight down on the bent rear leg, lead hand up in front
        (0.13, (-2, -60, -6), (0.16, -0.22, 0.2), (-20, 0, 86), (0, 0.01, 0.2), (125, 0, -3)),
        # end of the held charge (5 frames, still coiling a little)
        (0.18, (-1, -64, -7), (0.18, -0.24, 0.22), (-30, 0, 88), (0, 0.01, 0.22), (126, 0, -9)),
    ],
    # the strike stays around shoulder height: back -> side -> front
    "via": [(40, 0, 88), (105, 0, 62), (116, 0, 28)],
    "chain": {"pos": (0.18, 1.0), "yaw": (0.188, 1.6), "tilt": (0.197, 1.3), "off": (0.197, 1.5), "arm": (0.188, 1.8)},
    "smooth": 20,
    "tuck": 3,
}
FINISHER_CHARGE = {
    "hit": 0.38,
    "keys": [
        # leave Guard: the arm lifts out to the side, the lead arm reaches out
        (0.067, (-6, -32, -3), (0.06, -0.1, 0.07), (106, 0, 28), (0.02, 0, 0.08), (104, 0, -30)),
        # the arm rises up and back, the torso coils and leans back
        (0.133, (0, -59, -6), (0.08, -0.15, 0.1), (74, 0, 106), (0.16, 0.01, 0.18), (108, 0, -62)),
        # loaded: fist cocked behind the head, torso coiled ~60 deg, leaning
        # back, weight on the rear leg, lead arm pointing at the target; the
        # shoulder is pushed out (pos x 0.3) so the arm block stays out of
        # the torso's upper-back corner
        (0.2, (3, -72, -4), (0.1, -0.16, 0.12), (42, 0, 136), (0.3, 0.01, 0.22), (112, 0, -76)),
        # end of the held charge (4 frames, still coiling a little)
        (0.263, (4, -76, -5), (0.11, -0.17, 0.13), (38, 0, 140), (0.3, 0.01, 0.24), (116, 0, -80)),
    ],
    # the strike stays high: up behind -> out by the side -> over to the front
    "via": [(45, 0, 130), (82, 0, 115), (118, 0, 50)],
    "chain": {"pos": (0.263, 1.0), "yaw": (0.272, 1.6), "tilt": (0.28, 1.3), "off": (0.28, 1.5), "arm": (0.272, 2.15)},
    "smooth": 20,
    "tuck": 4,
}

SPECS = {
    "Brawler_M1_1": {
        "src": "jab_right",
        "mirror": True,
        "hand": "Left",
        "warp": [(0.067, 5.0, 0.6), (0.15, 11.2, 2.6), (0.19, 16.0, 1.8), (0.34, 23.5, 0.6)],
        "contact": (-0.03, 0.68, -2.72),
        "snap": 1.4,
        "follow": 0.55,
        "hold": 0.22,
        "yaw": -35,
        "yaw_max": 40,
        "drive": 2.5,
        "drive_end": 0.2,
        "sink": 0.02,
        "lunge": (-0.1, -0.2, -0.42),
        "reach": 0.45,
        "loop": 1.0,
        "legs": 0.6,
        "lean": -4,
        "tilt": 0.5,
        "hips": 0.5,
        "back": (0.18, 0.37),
        "back_lag": 0.025,
        "yaw_back": (0.18, 0.31),
        "yaw_hold": 7,
        "windup": {
            "peak": 0.067,
            "yaw": 15,
            "pitch": 0,
            "roll": 4,
            "pos": (0.04, -0.1, 0.08),
            "tuck": 3,
            "retract": 0.12,
            "fist": (-0.05, -0.06, 0.1),
            "carry": 0.4,
            "off": (0, 0, 0),
            "chain": {
                "pos": (0.058, 0.125),
                "yaw": (0.067, 0.15),
                "tilt": (0.075, 0.15),
                "shoulder": (0.083, 0.15),
                "fist": (0.092, 0.15),
            },
            "lunge_end": 0.185,
            "yaw_end": 0.175,
            "yaw_shape": 1.15,
            "arm_space": True,
            "accel": 2.5,
            "len_accel": 2.0,
        },
        "length": 0.5,
        "about": "Left jab (combo hit 1): a short load (torso turns back, lead shoulder dips, weight\n"
        "\t-- sits), then the hips and shoulders turn and the folded lead arm snaps straight out; fast return.",
    },
    "Brawler_M1_2": {
        "src": "combo_punch_kick",
        "mirror": False,
        "hand": "Right",
        "warp": [(0.0, 52.0, 1.5), (0.067, 57.5, 0.8), (0.15, 65.7, 2.6), (0.2, 67.3, 0.5), (0.36, 74.5, 1.4)],
        "contact": (-0.02, 0.62, -2.83),
        "snap": 1.5,
        "follow": 0.55,
        "hold": 0.22,
        "yaw": 40,
        "yaw_max": 45,
        "drive": 9,
        "drive_end": 0.2,
        "sink": 0.02,
        "lunge": (-0.06, -0.12, -0.34),
        "reach": 0.45,
        "loop": 1.0,
        "legs": 0.0,
        "lean": 0,
        "tilt": 0.3,
        "hips": 0.15,
        "back": (0.19, 0.3),
        "back_lag": 0.03,
        "yaw_back": (0.19, 0.3),
        "yaw_hold": 7,
        "yaw_hold_at": (0.295, 0.36),
        "windup": {
            "peak": 0.067,
            "yaw": 8,
            "pitch": 2,
            "roll": -2.5,
            "pos": (0.08, -0.12, 0.13),
            "tuck": 3,
            "retract": 0.15,
            "fist": (0.0, -0.02, 0.18),
            "carry": 0.3,
            "off": (-0.01, 0, -0.15),
            "chain": {
                "pos": (0.05, 0.13),
                "yaw": (0.058, 0.15),
                "tilt": (0.067, 0.15),
                "shoulder": (0.083, 0.15),
                "fist": (0.092, 0.15),
            },
            "lunge_end": 0.185,
            "yaw_end": 0.175,
            "yaw_shape": 1.15,
            "arm_space": True,
            "accel": 2.5,
            "len_accel": 2.2,
        },
        "charge": CROSS_CHARGE,
        "length": 0.6,
        "about": "Right cross (combo hit 2), CHARGED: the arm swings out and back at shoulder height, fist well behind the body,\n"
        "\t-- the torso coils hard on the bent rear leg and holds the charge, then hips, chest, shoulder and the arm\n"
        "\t-- explode through the centre line (fastest at the impact, 0.28 s).",
    },
    "Brawler_M1_3": {
        "src": "hook_left",
        "mirror": False,
        "hand": "Left",
        "warp": [(0.0, 14.0, 2.0), (0.067, 21.0, 0.8), (0.15, 28.6, 1.4), (0.2, 29.5, 0.3), (0.25, 29.7, 0.1)],
        "contact": (-0.21, 0.8, -2.22),
        "snap": 1.3,
        "follow": 0.25,
        "hold": 0.22,
        "yaw": -49,
        "yaw_max": 55,
        "drive": 2.5,
        "drive_end": 0.2,
        "sink": 0.02,
        "lunge": (-0.12, -0.2, -0.08),
        "reach": 0.3,
        "loop": 1.25,
        "loop_up": 0.3,
        "legs": 0.0,
        "lean": -3,
        "tilt": 0.5,
        "hips": 0.5,
        "back": (0.19, 0.34),
        "back_lag": 0.025,
        "yaw_back": (0.18, 0.31),
        "yaw_hold": 7,
        "windup": {
            "peak": 0.067,
            "yaw": 14,
            "pitch": -1,
            "roll": 4.5,
            "pos": (-0.08, -0.13, -0.03),
            "tuck": 3,
            "retract": 0.1,
            "fist": (-0.36, -0.18, 0.3),
            "carry": 0.0,
            "socket": False,
            "off": (0, 0.03, 0),
            "pull": 0.3,
            "chain": {
                "pos": (0.058, 0.13),
                "yaw": (0.067, 0.155),
                "tilt": (0.075, 0.15),
                "shoulder": (0.083, 0.15),
                "fist": (0.075, 0.15),
            },
            "yaw_end": 0.17,
            "accel": 2.1,
            "smooth": 0.35,
        },
        "length": 0.5,
        "about": "Left hook (combo hit 3): the torso coils right over the lead leg, elbow and fist out\n"
        "\t-- wide, then the fist whips across at head height with the chest turn; short follow-through.",
    },
    "Brawler_M1_4": {
        "src": "cross_right",
        "mirror": False,
        "hand": "Right",
        "warp": [(0.0, 9, 1.2), (0.075, 13.5, 0.3), (0.15, 23.7, 3.0), (0.2, 25.8, 0.9), (0.72, 40, 0.3)],
        "contact": (0.06, 0.92, -2.5),
        "snap": 1.8,
        "follow": 0.5,
        "hold": 0.22,
        "yaw": 50,
        "yaw_max": 70,
        "drive": 16,
        "drive_end": 0.3,
        "sink": 0.03,
        "lunge": (-0.12, -0.12, -0.5),
        "reach": 0.45,
        "loop": 0.3,
        "legs": 0.8,
        "lean": -3,
        "tilt": 0.5,
        "hips": 0.5,
        "back": (0.3, 0.6),
        "back_lag": 0.06,
        "windup": {
            "peak": 0.075,
            "yaw": 13,
            "pitch": 2,
            "roll": -3,
            "pos": (0.09, -0.18, 0.15),
            "tuck": 4,
            "retract": 0.15,
            "fist": (0.0, 0.5, 0.2),
            "carry": 0.3,
            "off": (0.04, -0.05, -0.15),
            "step": 0.3,
            "chain": {
                "pos": (0.058, 0.14),
                "yaw": (0.067, 0.16),
                "tilt": (0.075, 0.15),
                "shoulder": (0.092, 0.15),
                "fist": (0.092, 0.15),
            },
            "lunge_end": 0.185,
            "yaw_end": 0.18,
            "arm_space": True,
            "accel": 2.8,
            "len_accel": 2.2,
            "bump": 0.08,
            "bump_at": 0.4,
        },
        "charge": FINISHER_CHARGE,
        "length": 1.08,
        "about": "Overhand right (combo FINISHER), CHARGED: the biggest wind-up (arm raised out and back until\n"
        "\t-- the fist is behind the head, torso coiled and leaning back, lead arm aiming), a long held charge,\n"
        "\t-- then the arm swings out by the side and over with the whole body diving in (impact 0.38 s);\n"
        "\t-- heavy recovery. Longer than the others: see Config.Combat.FINISHER_RECOVERY.",
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
GUARD_LOW = {s: lowest(GUARD_WORLD, s + " Leg") for s in ("Left", "Right")}
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
def solve_arm(pose, joint, side, target, reach, guess, pull=0.15, step=None):
    """Shoulder angles (X, Z; Y = 0 like every clip) putting the fist on target.

    reach = how far the shoulder should be pushed forward (studs): the solver
    may push it a bit more or less (even pull it back a little) when the
    target is out of reach of a rigid 1.58-stud arm, or too close to it
    (at most `pull` studs back: a shoulder drawn back during a wind-up).
    guess = the previous frame's answer (X, Z, push): starting from it keeps
    the arm on the same solution (no flip to an arm going over the top).
    step = the most the push may change since the previous frame (studs): an
    R6 arm is one block, so a shoulder sliding half a stud in one frame looks
    like the arm popping out of its socket, not like an elbow extending."""

    def put(v):
        pose[joint] = ((v[0], 0.0, v[1]), (0.0, -0.04 * v[2], -v[2]))

    def resid(v):
        put(v)
        return np.concatenate(
            [(fist(pose, side) - target) * 10, [(v[2] - reach) * 3], (v[:2] - guess[:2]) * 0.005]
        )

    lo, hi = -pull, 0.55
    if step is not None:
        lo, hi = max(lo, guess[2] - step), min(hi, guess[2] + step)
    start = np.array(guess, dtype=float)
    start[2] = min(hi - 0.001, max(lo + 0.001, start[2]))
    sol = least_squares(resid, start, bounds=([-90, -150, lo], [250, 150, hi]))
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


def wind_env(t, peak, release, end, accelerate=False):
    """How much of the wind-up's load one body part holds at time t (0 to 1).

        1 |      .--------.
          |     /          '.
          |    /             '.
        0 |___/                '.___
          0   peak  release    end

    - 0 -> peak: into the load, fast at first then slowing down, so the
      loaded pose is reached gently and almost held (the energy is stored).
    - peak -> release: held (other parts may already be letting go: overlap,
      the body never freezes as a whole).
    - release -> end: the load is let go. Body parts use a slow-in slow-out
      curve. The fist (accelerate=True) uses 1 - u^2: it starts slowly and
      is FASTEST at the end, which is the impact (never ease into a hit)."""
    if t <= 0.0 or t >= end:
        return 0.0
    if t < peak:
        u = t / peak
        return 1.0 - (1.0 - u) ** 2
    if t < release:
        return 1.0
    u = (t - release) / (end - release)
    if accelerate:
        return 1.0 - u * u
    return 0.5 * (1.0 + math.cos(math.pi * u))


def retimer(fn, t0, t1, profile, smooth=0.0, samples=240):
    """Re-time fn (a curve over game time: a point, or a list of numbers)
    between t0 and t1. Returns a function at(t) -> (value, time) where value
    runs along the same path as fn, but has covered profile(u) of the path's
    total length at u = (t - t0) / (t1 - t0); time is the original time of
    that point. Outside [t0, t1] it is just (fn(t), t).
    smooth > 0 rounds the path's sharp corners over about that distance
    (studs; the two ends stay where they are): a corner, like the hook's
    turn from "out" to "across", would make the fist slow down there."""

    def length(p):
        return np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(p, axis=0), axis=1))])

    grid = np.linspace(t0, t1, 4 * samples + 1)
    pts = np.array([np.atleast_1d(fn(x)) for x in grid], dtype=float)
    cum = length(pts)
    if cum[-1] < 1e-9:
        return lambda t: (np.atleast_1d(fn(t)).astype(float), t)
    # resample evenly along the path, so the smoothing works in distance,
    # not in time (the fist covers most of its path in the last frames)
    even = np.linspace(0.0, cum[-1], samples + 1)
    grid = np.interp(even, cum, grid)
    pts = np.stack([np.interp(even, cum, pts[:, k]) for k in range(pts.shape[1])], 1)
    # neighbour averaging, repeated: rounds corners of ~`smooth` studs
    for _ in range(int(2 * (smooth / (cum[-1] / samples)) ** 2)):
        pts[1:-1] = 0.5 * pts[1:-1] + 0.25 * (pts[:-2] + pts[2:])
    cum = length(pts)

    def at(t):
        if t <= t0 or t >= t1:
            return np.atleast_1d(fn(t)).astype(float), t
        d = profile((t - t0) / (t1 - t0)) * cum[-1]
        k = int(np.clip(np.searchsorted(cum, d) - 1, 0, samples - 1))
        a = (d - cum[k]) / max(1e-12, cum[k + 1] - cum[k])
        return pts[k] + a * (pts[k + 1] - pts[k]), grid[k] + a * (grid[k + 1] - grid[k])

    return at


# ---------------------------------------------------------------- one clip, dense
def retarget(dump_dir, name, length=None):
    """The Motifect clip on its own timeline (impact at 0.15 s), `length`
    seconds long (default: the spec's length)."""
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

    # wind-up (see wind_env and the SPECS notes): the load added on top of
    # the mocap, and when each body part lets go of it
    wu = spec["windup"]
    # +1 if the punch turns the torso to the left (+yaw), -1 to the right:
    # the load turns it the OTHER way
    turn_sign = math.copysign(1.0, spec["yaw"] - GUARD["Root"][0][1])

    def load(part, t):
        release, end = wu["chain"][part]
        return wind_env(t, min(wu["peak"], release), release, end, accelerate=part == "fist")

    def torso_yaw(t):
        """Root yaw at game time t: Guard + the chest's (scaled) turn - the
        wind-up's counter-turn."""
        g_yaw = GUARD["Root"][0][1]
        yaw = g_yaw + chest_delta(warp(t))[1] * yaw_scale - turn_sign * wu["yaw"] * load("yaw", t)
        return float(np.clip(yaw, -spec["yaw_max"], spec["yaw_max"]))

    def after_hit(t):
        """0 at the impact, rising to 1 at `drive_end`, fast first then
        slowing down (ease-out): the follow-through that goes on after the
        impact, so the body never freezes on the hit."""
        if t <= 0.15:
            return 0.0
        u = min(1.0, (t - 0.15) / (spec.get("drive_end", 0.23) - 0.15))
        return 1.0 - (1.0 - u) ** 2

    def fist_target(t):
        """Where the punching fist must be at game time t (root space), and
        the source frame it comes from."""
        f = warp(t)
        # how far along the punch we are (0 = guard, 1 = impact, a bit more
        # past it), from the source fist's progress toward its impact position
        d = knuckle(hand, f)
        w = float(np.clip(d @ d_c / (d_c @ d_c), 0.0, 1.3))
        # straight line Guard fist -> contact, plus the source's arc around
        # that line (scaled by `loop`)
        # (`snap` > 1 bends the progress so it ends faster: the mocap actor
        # slowed down before full extension, a punch that hits doesn't)
        ws = w ** spec["snap"] if w < 1 else w
        arc = spec["loop"] * (d - w * d_c)
        # (the arc's up / down part has its own scale: a hook travels at head
        # height, it must not scoop down to the chest and come back up)
        arc[1] *= spec.get("loop_up", 1.0)
        target = GUARD_FIST[hand] + ws * (contact - GUARD_FIST[hand]) + arc
        # wind-up: the fist comes back toward the chin, then is let go last
        target = target + load("fist", t) * np.array(wu["fist"], dtype=float)
        if t > 0.15:
            # the impact: the fist stops ON the head (only `follow` of the
            # source's travel past the impact point is kept for a moment)
            keep = spec["follow"] + (1 - spec["follow"]) * smoothstep(spec["hold"], spec["hold"] + 0.08, t)
            target = contact + keep * (target - contact)
        return target, f

    # The hook's strike (no `arm_space`): its speed is set here, not by the
    # mocap's timing (which is squeezed ~2-4x and has bumps where the hook's
    # arc turns): the fist follows the SAME path (load -> arc -> contact), but
    # the distance covered grows as u^accel, so it starts slowly from the load
    # and gets faster every frame until the impact. The torso turn uses a
    # slow-in slow-out curve that ends just after the impact (it still turns
    # at the impact).
    t0 = wu["chain"]["fist"][0]
    strike = retimer(lambda x: fist_target(x)[0], t0, 0.15, lambda u: u ** wu["accel"], smooth=wu.get("smooth", 0.0))
    # (`yaw_shape` > 1 moves the turn's fastest moment later, toward the
    # impact: the body must still turn fast when the fist lands)
    k_yaw = wu.get("yaw_shape", 1.0)
    turn = retimer(torso_yaw, wu["chain"]["yaw"][0], wu["yaw_end"], lambda u: smoothstep(0.0, 1.0, u**k_yaw))

    def body_yaw(t):
        """Root yaw: the re-timed turn, plus `drive` after the impact (the
        torso keeps turning a few degrees through the target, slowing down,
        while the fist stays on it; the return to the guard takes it back)."""
        yaw = float(turn(t)[0][0]) + spec.get("drive", 0.0) * turn_sign * after_hit(t)
        return float(np.clip(yaw, -spec["yaw_max"], spec["yaw_max"]))

    def root_at(t):
        """The torso (Root joint) at game time t: (rot degrees, pos studs).
        The Guard's lean / turn plus the chest's (turn scaled to the target,
        lean and roll kept small: an R6 torso is one stiff block), plus the
        lunge, plus the wind-up's counter-turn, lean, roll and weight shift."""
        f = warp(t)
        d = knuckle(hand, f)
        w = float(np.clip(d @ d_c / (d_c @ d_c), 0.0, 1.3))
        # the weight's move toward the target (lunge): it starts as soon as
        # the legs let go of the load, BEFORE the fist moves (kinetic chain),
        # and after the impact it follows the source's fist
        # (`lunge_end`: when it would end; after 0.15 s it is cut short, so a
        # later end keeps the body moving forward fast at the impact)
        lw = smoothstep(wu["chain"]["pos"][0], wu.get("lunge_end", 0.165), t) * (w if t > 0.15 else 1.0)
        dx, _, dz = chest_delta(f)
        g_rot = GUARD["Root"][0]
        tilt = load("tilt", t)
        rot = (
            g_rot[0] + float(np.clip(dx * spec["tilt"], -10, 4)) + lw * spec["lean"] + tilt * wu["pitch"],
            body_yaw(t),
            g_rot[2] + float(np.clip(dz * spec["tilt"], -8, 8)) + tilt * wu["roll"],
        )
        pos = lw * lunge + spec["hips"] * (pelvis(f) - w * p_c) + load("pos", t) * np.array(wu["pos"], dtype=float)
        # after the impact the weight keeps sinking a little (follow-through)
        pos[1] -= spec.get("sink", 0.0) * after_hit(t)
        pos = np.clip(pos, (-0.25, -0.36, -0.6), (0.25, 0.05, 0.22))
        return rot, tuple(pos)

    def torso_at(t):
        pose = dict(GUARD)
        pose["Root"] = root_at(t)
        return solve(pose)["Torso"]

    # the punching shoulder's socket (torso space): the point the arm hangs
    # from, before any push / pull of the shoulder
    socket = np.array([1.0 if hand == "Right" else -1.0, 0.5, 0.0, 1.0])
    g_torso_inv = np.linalg.inv(GUARD_WORLD["Torso"])

    def load_target(t):
        """The punching fist until the strike: the mocap's (Guard) fist moved
        by the wind-up's fold (`fist`), and CARRIED by the torso: it moves as
        if the arm were glued to the chest, so the counter-turn and the
        weight drop take the fist back with them (the fold stays a fold),
        and when the torso starts to unwind the arm rides along with it,
        still folded, before it extends (kinetic chain on a rigid arm)."""
        # `carry` = how much of the torso's TURN is passed to the fist (1 =
        # glued to the chest). The rest of it only follows the shoulder
        # socket's move (`socket` True): the fist keeps its line toward the
        # target instead of being swept sideways by the turn, like a boxer's
        # rear hand that stays in front of the chin while the shoulder turns
        # back. The hook uses neither (its fist goes OUT while the body turns).
        torso = torso_at(t)
        glued = (torso @ g_torso_inv @ np.append(GUARD_FIST[hand], 1.0))[:3]
        sock = (torso @ socket)[:3] - (GUARD_WORLD["Torso"] @ socket)[:3]
        k = wu.get("carry", 1.0)
        rest = sock if wu.get("socket", True) else np.zeros(3)
        return strike(t)[0] + k * (glued - GUARD_FIST[hand]) + (1 - k) * rest

    # The strike (from the fist's release to the impact), `arm_space`:
    # worked out FROM THE SHOULDER. The fist = shoulder socket + the arm's
    # vector, which turns from its folded (loaded) direction to the punch's
    # direction (`accel`: faster every frame) while it gets longer from the
    # folded length to the full reach at the impact (`len_accel`). So the
    # body carries the arm forward while the arm itself extends, the fist is
    # never asked to be closer to the shoulder than a folded arm (no arm
    # sliding in its socket), and its speed is the shoulder's speed plus the
    # arm's: it keeps rising into the impact. `bump` lifts the middle of the
    # path (studs): an overhand comes up and over, then down onto the target.
    # (The hook doesn't use it: its fist goes out, then sweeps across.)
    t1 = 0.15
    v0 = load_target(t0) - (torso_at(t0) @ socket)[:3]
    vc = contact - (torso_at(t1) @ socket)[:3]

    def arm_target(t):
        u = (t - t0) / (t1 - t0)
        sd, sl = u ** wu["accel"], u ** wu.get("len_accel", wu["accel"])
        way = (1 - sd) * v0 / np.linalg.norm(v0) + sd * vc / np.linalg.norm(vc)
        size = (1 - sl) * np.linalg.norm(v0) + sl * np.linalg.norm(vc)
        # (the bump peaks at u = `bump_at`)
        up = math.sin(math.pi * u ** (math.log(0.5) / math.log(wu.get("bump_at", 0.5))))
        up = np.array([0.0, wu.get("bump", 0.0) * up, 0.0])
        return (torso_at(t) @ socket)[:3] + way / np.linalg.norm(way) * size + up

    frames = []
    guess = {
        "RightShoulder": np.array([111.0, -36.5, 0.0]),
        "LeftShoulder": np.array([115.0, 37.0, 0.0]),
        "RightHip": np.zeros(2),
        "LeftHip": np.zeros(2),
    }
    n = int(round((spec["length"] if length is None else length) * FPS))
    for i in range(n + 1):
        t = i / FPS
        f = warp(t)
        rot, pos = root_at(t)
        g_rot = GUARD["Root"][0]
        pose = dict(GUARD)  # (joints not solved yet keep their Guard values)
        pose["Root"] = (rot, pos)
        # Neck: undo most of the torso's turn and lean (eyes on the target),
        # chin tucked during the load
        pose["Neck"] = (
            (
                6 - 0.75 * (rot[0] - g_rot[0]) + load("yaw", t) * wu["tuck"],
                10 - 0.83 * (rot[1] - g_rot[1]),
                -0.8 * (rot[2] - g_rot[2]),
            ),
            (0.0, 0.0, 0.0),
        )
        # punching arm: aimed at its target: carried and folded until the
        # strike, then the strike (from the shoulder, or along the re-timed
        # path, see above), then fist_target (the stop on the target)
        t_arm = t
        if t <= t0:
            target = load_target(t)
        elif t <= 0.15 and wu.get("arm_space"):
            target = arm_target(t)
        elif t <= 0.15:
            # (the re-timed path, plus the carry by the torso, let go with
            # the fist on its accelerating curve)
            target, t_arm = strike(t)
            target = target + wind_env(t, 1e-6, *wu["chain"]["fist"], accelerate=True) * (load_target(t0) - strike(t0)[0])
        else:
            target = fist_target(t)[0]
        fist_load = load("fist", t)
        if t <= 0.15:
            # until the impact the shoulder push grows with the strike's own
            # progress: the arm block slides forward over the last frames
            ext = ((t - t0) / (0.15 - t0)) ** wu.get("len_accel", wu["accel"]) if t > t0 else 0.0
        else:
            ext = (src.extension(hand, warp(t_arm)) - e_g) / max(1e-6, e_c - e_g)
        reach = spec["reach"] * float(np.clip(ext, 0.0, 1.05))
        # wind-up: the shoulder is pulled back during the load
        reach -= wu["retract"] * load("shoulder", t)
        j = hand + "Shoulder"
        guess[j] = solve_arm(pose, j, hand, target, reach, guess[j], pull=wu.get("pull", 0.18), step=wu.get("step"))
        # other arm: stays up by the chin. It follows the head (and a third of
        # the torso turn), and its fist is never let down to shoulder height:
        # an R6 arm is rigid, so a fist at shoulder height is a straight arm
        # held out horizontally, which reads as a second punch, not a guard.
        world = solve(pose)
        head = world["Head"][:3, 3]
        follow_turn = angles(0, math.radians(0.3 * (rot[1] - g_rot[1])), 0)
        drift = 0.4 * knuckle(other, f)
        if np.linalg.norm(drift) > 0.25:
            drift *= 0.25 / np.linalg.norm(drift)
        o_target = head + follow_turn @ (GUARD_FIST[other] - GUARD_HEAD) + drift
        o_target = o_target + fist_load * np.array(wu["off"], dtype=float)
        pivot = world["Torso"] @ np.array([1.0 if other == "Right" else -1.0, 0.5, 0, 1])
        o_target[1] = max(o_target[1], pivot[1] + GUARD_LIFT[other])
        j = other + "Shoulder"
        guess[j] = solve_arm(pose, j, other, o_target, 0.0, guess[j])
        # legs: Guard feet + the source's steps (if kept); the legs turn a
        # little with the hips (heel pivot) instead of twisting over glued feet.
        # They turn one frame AHEAD of the torso: in a punch the legs and hips
        # start the turn, the chest follows (on R6 hips and chest are one part)
        hip_yaw = -0.35 * (body_yaw(t + 1 / FPS) - g_rot[1])
        for s in ("Left", "Right"):
            step = (src.pos(s + "Foot", f) - feet0[s]) * src.k_leg * spec["legs"]
            step = np.clip(step, -0.35, 0.35)
            foot = (GUARD_FOOT[s][0] + step[0], GUARD_FOOT[s][2] + step[2])
            j = s + "Hip"
            guess[j] = solve_leg(pose, j, s, foot, hip_yaw, guess[j])

        frames.append({jn: tuple(np.array(v, dtype=float) for v in pose[jn]) for jn in JOINTS})

    # start: frame 0 is the source's guard frame with nothing loaded yet, so it
    # IS our Guard, up to the solvers' tiny errors: remove those errors over
    # the first 0.1 s so the clip starts exactly in Guard. (No blend-in from
    # Guard here: the controller already fades the clip in over 0.05 s, and a
    # second blend would hide the first frames of the load.)
    # end: blend back into the exact Guard pose, the arms first, the torso,
    # head and legs `back_lag` later (the mass comes back after the hand).
    err0 = {jn: [frames[0][jn][k] - np.array(GUARD[jn][k], dtype=float) for k in (0, 1)] for jn in JOINTS}
    b0, b1 = spec["back"]
    lag = spec.get("back_lag", 0.0)
    out_frames = []
    for i, pose in enumerate(frames):
        t = i / FPS
        fix = 1 - smoothstep(0.0, 0.1, t)
        a_arm = 1 - smoothstep(b0, b1, t)
        a_body = 1 - smoothstep(b0 + lag, b1 + lag, t)
        # the legs come back with the torso's TURN (they turn with the hips):
        # if they lagged behind it, the feet would swing on the floor
        yb0, yb1 = spec.get("yaw_back", (b0 + lag, b1 + lag))
        a_legs = 1 - smoothstep(yb0, yb1 + lag, t)
        out = {}
        for jn in JOINTS:
            a = a_arm if jn.endswith("Shoulder") else a_legs if jn.endswith("Hip") else a_body
            r0, p0 = (np.array(v, dtype=float) for v in GUARD[jn])
            r1, p1 = (pose[jn][k] - err0[jn][k] * fix for k in (0, 1))
            out[jn] = (r0 + (r1 - r0) * a, p0 + (p1 - p0) * a)
        # torso turn (Root yaw): it comes back on its own, earlier curve
        # (`yaw_back`) and stops `yaw_hold` degrees short of the Guard, on the
        # follow-through side, until 0.38 s (the next click of the combo);
        # it reaches the exact Guard only between 0.38 and 0.48 s. In the
        # combo the next punch starts while this one is ~0.33-0.38 s in: its
        # load turns the torso further the SAME way (a jab's follow-through is
        # the cross's load, the cross's is the hook's...), so the torso never
        # turns back and forth around the click. The head keeps undoing the turn.
        g_yaw = GUARD["Root"][0][1]
        h0, h1 = spec.get("yaw_hold_at", (0.38, 0.48))
        rest = g_yaw + spec.get("yaw_hold", 0.0) * turn_sign * (1 - smoothstep(h0, h1, t))
        a_yaw = 1 - smoothstep(yb0, yb1, t)
        y1 = float(pose["Root"][0][1] - err0["Root"][0][1] * fix)
        r = out["Root"][0].copy()
        r[1] = rest + (y1 - rest) * a_yaw
        out["Root"] = (r, out["Root"][1])
        r = out["Neck"][0].copy()
        r[1] = GUARD["Neck"][0][1] - 0.83 * (out["Root"][0][1] - g_yaw)
        out["Neck"] = (r, out["Neck"][1])
        # blending the angles doesn't keep the soles on the floor: slide each
        # leg up or down again so they touch it. (In the exact Guard pose one
        # sole sits a hair above FLOOR because the torso leans: at the very
        # start and end the legs go back to that height, not to FLOOR.)
        for s in ("Left", "Right"):
            j = s + "Hip"
            floor = GUARD_LOW[s] + (FLOOR - GUARD_LOW[s]) * a_body * (1 - fix)
            for _ in range(30):
                err = floor - lowest(solve(out), s + " Leg")
                if abs(err) < 1e-4:
                    break
                out[j] = (out[j][0], out[j][1] + np.array([0.0, err, 0.0]))
        out_frames.append(out)
    return out_frames


# ---------------------------------------------------------------- charged punches (M1_2, M1_4)
def key_curve(times, values):
    """A smooth curve through keys (one curve per number of `values`), with
    speed 0 on the first and last key (both are holds) and, in between,
    slopes that never overshoot a key (Fritsch-Carlson, like a "monotone"
    spline): the coil slows down INTO the loaded pose instead of going past
    it and coming back."""
    times = np.asarray(times, dtype=float)
    values = np.asarray(values, dtype=float)
    d = np.diff(values, axis=0) / np.diff(times)[:, None]
    m = np.zeros_like(values)
    for i in range(1, len(times) - 1):
        h0, h1 = times[i] - times[i - 1], times[i + 1] - times[i]
        w0, w1 = 2 * h1 + h0, h1 + 2 * h0
        for k in range(values.shape[1]):
            a, b = d[i - 1, k], d[i, k]
            # a key where the curve turns back (or stops) gets speed 0
            m[i, k] = (w0 + w1) / (w0 / a + w1 / b) if a * b > 0 else 0.0

    def at(t):
        if t <= times[0]:
            return values[0].copy()
        if t >= times[-1]:
            return values[-1].copy()
        i = int(np.searchsorted(times, t, side="right")) - 1
        h = times[i + 1] - times[i]
        u = (t - times[i]) / h
        h00, h10, h01, h11 = 2 * u**3 - 3 * u**2 + 1, u**3 - 2 * u**2 + u, -2 * u**3 + 3 * u**2, u**3 - u**2
        return h00 * values[i] + h10 * h * m[i] + h01 * values[i + 1] + h11 * h * m[i + 1]

    return at


def let_go(t, start, end, speed):
    """How far (0 to 1) a body part has gone from its charged pose toward the
    impact pose at time t: it starts still at `start` and arrives at `end`
    (the impact) still moving. `speed` = its speed at the impact, relative to
    a constant-speed move (1 = constant at the end, 2 = curve u^2, 3 = u^3):
    the higher, the more of the move happens in the last frames."""
    u = min(1.0, max(0.0, (t - start) / (end - start)))
    return -2 * u**3 + 3 * u**2 + speed * (u**3 - u**2)


def charged(dump_dir, name):
    """A CHARGED punch (spec "charge"): the Motifect clip's impact, drive and
    recovery, after a big authored wind-up. Returns (times, frames).

    The Motifect clip is made on its own timeline (impact at 0.15 s, see
    retarget) and moved later so its impact lands at `hit`. Before that:
      1. wind-up (0 -> the last key): the authored keys, joined by a smooth
         curve that slows down into each pose and stops on the last one: arm
         swept back, torso coiled away, weight sat down on the rear leg;
      2. the held charge: the last two keys are close together, so the body
         keeps coiling a little, slower and slower (alive, but "charging");
      3. strike (last key -> `hit`): each part goes from the charged pose to
         the Motifect impact pose, one after the other (kinetic chain: the
         weight and legs, then the torso turn, the lean, the arm last), each
         FASTER and faster until the impact (`let_go`). The punching arm
         follows a path through the `via` angles (around the side at shoulder
         height for the cross; up, out by the side and over for the
         overhand), covered as u^accel of its length: its last frames are
         the fastest (the "smear").
    The legs are aimed at their (Guard) foot spots every frame, the head
    undoes the torso's turn (eyes on the target)."""
    spec = SPECS[name]
    ch = spec["charge"]
    hand = spec["hand"]
    other = "Right" if hand == "Left" else "Left"
    hit = ch["hit"]
    shift = hit - 0.15
    # the dense frames: every 1/60 s counted back from the impact (so the
    # impact is a frame), plus frame 0 at 0 s
    n_pre = int(math.floor(hit * FPS + 1e-6))
    times = [hit - k / FPS for k in range(n_pre, 0, -1)]
    if times[0] > 1e-6:
        times = [0.0] + times
    base = retarget(dump_dir, name, spec["length"] - shift)
    base = base[int(round(0.15 * FPS)) :]
    times += [hit + k / FPS for k in range(len(base))]
    contact = base[0]

    def pack(root, pos, arm, arm_pos, off, off_pos=(0, 0, 0)):
        return np.array([*root, *pos, *arm, *arm_pos, *off, *off_pos], dtype=float)

    def guard(j):
        return GUARD[j][0], GUARD[j][1]

    g = pack(*guard("Root"), *guard(hand + "Shoulder"), *guard(other + "Shoulder"))
    keys_t = [0.0] + [k[0] for k in ch["keys"]]
    keys_v = [g] + [pack(*k[1:]) for k in ch["keys"]]
    wind = key_curve(keys_t, keys_v)
    t_hold = keys_t[-1]
    held = keys_v[-1]
    c = pack(
        *(contact["Root"][k] for k in (0, 1)),
        *(contact[hand + "Shoulder"][k] for k in (0, 1)),
        *(contact[other + "Shoulder"][k] for k in (0, 1)),
    )
    chain = ch["chain"]

    # the punching arm's strike path, in shoulder angles: charged -> via -> impact
    # (piecewise straight in angle space, corners rounded, then re-timed so
    # its covered length grows as u^accel: fastest into the impact)
    arm_pts = [held[6:12]] + [np.array([*v, *held[9:12]], dtype=float) for v in ch.get("via", ())] + [c[6:12]]
    for k, v in enumerate(ch.get("via", ())):
        # the shoulder's push/pull goes from charged to impact along the way
        a = (k + 1) / (len(arm_pts) - 1)
        arm_pts[k + 1][3:] = held[9:12] + a * (c[9:12] - held[9:12])
    seg = np.concatenate([[0.0], np.cumsum([np.linalg.norm(b[:3] - a[:3]) for a, b in zip(arm_pts, arm_pts[1:])])])
    a0 = chain["arm"][0]

    def arm_line(t):
        d = (t - a0) / (hit - a0) * seg[-1]
        k = int(np.clip(np.searchsorted(seg, d) - 1, 0, len(seg) - 2))
        w = (d - seg[k]) / max(1e-9, seg[k + 1] - seg[k])
        return arm_pts[k] + w * (arm_pts[k + 1] - arm_pts[k])

    arm_strike = retimer(arm_line, a0, hit, lambda u: u ** chain["arm"][1], smooth=ch.get("smooth", 0.0))

    def channels(t):
        """Root rot/pos and both shoulders (packed) at time t (before `hit`)."""
        if t <= t_hold:
            return wind(t)
        v = held.copy()
        parts = (("pos", slice(3, 6)), ("off", slice(12, 18)))
        for part, sl in parts:
            start, speed = chain[part]
            v[sl] = held[sl] + let_go(t, start, hit, speed) * (c[sl] - held[sl])
        for part, k in (("tilt", 0), ("yaw", 1), ("tilt", 2)):
            start, speed = chain[part]
            v[k] = held[k] + let_go(t, start, hit, speed) * (c[k] - held[k])
        v[6:12] = arm_strike(t)[0] if t > a0 else held[6:12]
        return v

    g_rot = GUARD["Root"][0]
    yaw_h = held[1]
    frames = []
    guess = {"RightHip": np.zeros(2), "LeftHip": np.zeros(2)}
    # where the feet are at the impact (the Motifect step, if the clip keeps
    # its legs): during the strike they move there from the Guard spots
    w_c = solve(contact)
    foot_c = {s: (w_c[s + " Leg"] @ np.array([0, -1.0, 0, 1]))[:3] for s in ("Left", "Right")}
    for t in times:
        if t >= hit - 1e-9:
            break
        v = channels(t)
        nxt = channels(min(t + 1 / FPS, hit - 1e-6))
        pose = dict(GUARD)
        rot = tuple(v[0:3])
        pose["Root"] = (rot, tuple(v[3:6]))
        # head: undoes the torso's lean / turn / roll (eyes on the target),
        # chin tucked while the torso is coiled
        coil = float(np.clip((v[1] - g_rot[1]) / (yaw_h - g_rot[1]), 0.0, 1.0))
        pose["Neck"] = (
            (
                6 - 0.75 * (rot[0] - g_rot[0]) + ch.get("tuck", 0.0) * coil,
                10 - 0.83 * (rot[1] - g_rot[1]),
                -0.8 * (rot[2] - g_rot[2]),
            ),
            (0.0, 0.0, 0.0),
        )
        pose[hand + "Shoulder"] = (tuple(v[6:9]), tuple(v[9:12]))
        pose[other + "Shoulder"] = (tuple(v[12:15]), tuple(v[15:18]))
        # legs: on their foot spots, turned with the hips one frame AHEAD of
        # the torso (the hips lead the turn, see retarget)
        hip_yaw = -0.35 * (nxt[1] - g_rot[1])
        step = let_go(t, chain["pos"][0], hit, 1.0) if t > t_hold else 0.0
        for s in ("Left", "Right"):
            foot = GUARD_FOOT[s] + step * (foot_c[s] - GUARD_FOOT[s])
            j = s + "Hip"
            guess[j] = solve_leg(pose, j, s, (foot[0], foot[2]), hip_yaw, guess[j])
        frames.append({jn: tuple(np.array(x, dtype=float) for x in pose[jn]) for jn in JOINTS})

    # start exactly in Guard: remove the leg solver's tiny error at frame 0
    # over the first 0.1 s, and keep the soles on the floor (at the start the
    # Guard's own sole height, see retarget)
    err0 = {jn: [frames[0][jn][k] - np.array(GUARD[jn][k], dtype=float) for k in (0, 1)] for jn in JOINTS}
    out = []
    for t, pose in zip(times, frames):
        fix = 1 - smoothstep(0.0, 0.1, t)
        o = {jn: tuple(pose[jn][k] - err0[jn][k] * fix for k in (0, 1)) for jn in JOINTS}
        for s in ("Left", "Right"):
            j = s + "Hip"
            floor = GUARD_LOW[s] + (FLOOR - GUARD_LOW[s]) * (1 - fix)
            for _ in range(30):
                err = floor - lowest(solve(o), s + " Leg")
                if abs(err) < 1e-4:
                    break
                o[j] = (o[j][0], o[j][1] + np.array([0.0, err, 0.0]))
        out.append(o)
    return times, out + base


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


def reduce_keys(frames, contact_index, max_keys=14, force=(), times=None, flat=()):
    """Keep the fewest frames as keys so the game's spline through them stays
    within ~1.5 degrees / 0.02 stud of every joint and 0.04 stud of both fists
    (greedy: add the worst frame until it fits). The impact frame is a key.
    times: each frame's time (default: every 1/60 s); flat: frames that are
    keys with tangent "flat" (the motion stops on them: a held charge)."""
    n = len(frames)
    if times is None:
        times = [i / FPS for i in range(n)]
    dense = [rounded(p) for p in frames]
    fists = [{s: fist(p, s) for s in ("Left", "Right")} for p in dense]
    # the frame just before the impact is a key too, so the spline keeps the
    # fist's full speed into the impact (it would round it off otherwise)
    chosen = {0, contact_index - 1, contact_index, n - 1} | set(force) | set(flat)
    # the end of the clip is the plain Guard: one key where the blend finishes
    for i in range(n - 1, 0, -1):
        if any(np.abs(dense[i][jn][0] - dense[-1][jn][0]).max() > 0.05 for jn in JOINTS):
            chosen.add(min(n - 1, i + 1))
            break
    while True:
        idx = sorted(chosen)
        keys = [(times[i], dense[i], "flat" if i in flat else "smooth") for i in idx]
        worst, at = 0.0, None
        for i in range(n):
            if i in chosen:
                continue
            p = sample(keys, times[i])
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
    if "charge" in spec:
        k = int(name[-1])
        at = f"at {num(spec['charge']['hit'])} s = Config.Combat.M1_HIT_DELAY[{k}] (after the charge)."
    else:
        at = f"at 0.15 s = Config.Combat.M1_HIT_DELAY[{int(name[-1])}]."
    lines = [
        f"\t-- {spec['about']}",
        f"\t-- Source: Motifect Combat Motion Pack `{spec['src']}` frames {first}-{last}{side}; its frame",
        f"\t-- {num(impact, 1)} is the impact, {at}",
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
        if "charge" in spec:
            # charged punch: the loaded pose and the end of the held charge are
            # keys (the last one "flat": the charge stops there, then the
            # strike explodes out of it)
            ch = spec["charge"]
            times, frames = charged(dump_dir, name)

            def index(t, times=times):
                return int(np.argmin([abs(x - t) for x in times]))

            force = [index(k[0]) for k in ch["keys"][:-1]]
            flat = [index(ch["keys"][-1][0])]
            keys, err = reduce_keys(
                frames, index(ch["hit"]), 20 + int(spec["length"] * 8), force, times=times, flat=flat
            )
            out[name] = {"length": spec["length"], "keys": keys, "dense": frames, "times": times, "fit": err}
            continue
        frames = retarget(dump_dir, name)
        # the loaded pose is a key, so the spline can't round the load away
        force = [int(round(spec["windup"]["peak"] * FPS))]
        keys, err = reduce_keys(frames, int(round(0.15 * FPS)), 12 + int(spec["length"] * 6), force)
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
        hit = SPECS[name].get("charge", {}).get("hit", 0.15)
        p = sample(k, hit)
        print(f"{name}: {len(k)} keys, fit error {c['fit']:.2f}, fist at {hit} s {np.round(fist(p, SPECS[name]['hand']), 2)}")
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
