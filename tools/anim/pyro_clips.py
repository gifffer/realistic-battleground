"""The Pyromaniac's clips (Shared/Kits/Pyromaniac): authored here as key
poses, written to src/client/Animation/PyroClips.luau, and rendered as
filmstrips (front, side, top) to check them by eye.

Same format and spline as Client/Animation/R6Pose (degrees, parent space;
Root X- leans forward, Y+ turns left; Shoulder X+ raises the arm forward,
RightShoulder Z- / LeftShoulder Z+ bring the arm across the body; Hip X+
swings the leg forward; Neck X+ tips the head back, Y+ turns it left).

  python3 tools/anim/pyro_clips.py --write         the Luau file
  python3 tools/anim/pyro_clips.py --render <dir>  the filmstrips (PIL)
"""

import math
import os
import sys

JOINTS = ["Root", "Neck", "RightShoulder", "LeftShoulder", "RightHip", "LeftHip"]

GUARD = {
    "Root": (-8, -12, 0),
    "Neck": (6, 10, 0),
    "RightShoulder": (111, 0, -36.5),
    "LeftShoulder": (115, 0, 37),
}


def pose(**joints):
    out = dict(GUARD)
    for name, value in joints.items():
        out[name] = value
    return out


def key(time, p, tangent=None):
    return {"time": time, "pose": p, "tangent": tangent}


CLIPS = {}

# Zippo flare (0.8 s): the lighter up in front of the chest, flicked open
# (0.15), struck (0.27), a short coil, then thrust at their face with a
# squirt of fluid through the flame: the hit at 0.42. Closed at 0.68.
CLIPS["Pyro_Zippo"] = {
    "length": 0.8,
    "keys": [
        key(0, pose()),
        key(0.12, pose(Root=(-6, -6, 0), Neck=(-4, 4, 0), RightShoulder=(70, 0, -22), LeftShoulder=(80, 0, 30))),
        key(0.2, pose(Root=(-6, -4, 0), Neck=(-8, 2, 0), RightShoulder=(76, 0, -20), LeftShoulder=(82, 0, 28)), "flat"),
        key(0.32, pose(Root=(-4, -22, 0), Neck=(2, 16, 0), RightShoulder=(70, 0, -8), LeftShoulder=(86, 0, 30),
                       RightHip=(-6, 0, 0), LeftHip=(6, 0, 0))),
        key(0.42, pose(Root=(-14, 18, 0, 0, -0.05, -0.12), Neck=(4, -14, 0), RightShoulder=(97, 0, -10),
                       LeftShoulder=(92, 0, 26), RightHip=(-12, 0, 0), LeftHip=(16, 0, 0))),
        key(0.54, pose(Root=(-12, 14, 0, 0, -0.05, -0.1), Neck=(4, -10, 0), RightShoulder=(94, 0, -12),
                       LeftShoulder=(84, 0, 24), RightHip=(-10, 0, 0), LeftHip=(14, 0, 0)), "flat"),
        key(0.68, pose(Root=(-8, 0, 0), Neck=(-2, 4, 0), RightShoulder=(72, 0, -24), LeftShoulder=(96, 0, 32),
                       RightHip=(-3, 0, 0), LeftHip=(4, 0, 0))),
        key(0.8, pose()),
    ],
}

# Molotov (1.0 s): the bottle up in front of the chest in his right fist,
# the Zippo in his left brought to the rag (lit at 0.3), the left hand
# drops; the bottle cocked up and back over his head as the left foot steps
# in, an overhand lob: it leaves the hand at 0.68 with the arm a little past
# vertical, going forward; follow-through across the body.
CLIPS["Pyro_Molotov"] = {
    "length": 1.0,
    "keys": [
        key(0, pose()),
        key(0.14, pose(Root=(-6, -6, 0), Neck=(-14, 6, 0), RightShoulder=(58, 0, -36), LeftShoulder=(86, 0, 58))),
        key(0.3, pose(Root=(-7, -4, 0), Neck=(-18, 4, 0), RightShoulder=(56, 0, -40), LeftShoulder=(92, 0, 64)), "flat"),
        key(0.44, pose(Root=(-4, -10, 0), Neck=(-6, 8, 0), RightShoulder=(80, 0, -10), LeftShoulder=(30, 0, 10))),
        key(0.56, pose(Root=(6, -32, 4, 0, -0.08, 0.1), Neck=(0, 26, 0), RightShoulder=(196, 0, 10),
                       LeftShoulder=(86, 0, 4), RightHip=(-10, 0, 0), LeftHip=(22, 0, 0))),
        key(0.68, pose(Root=(-12, 6, -2, 0, -0.14, -0.1), Neck=(2, -4, 0), RightShoulder=(150, 0, -2),
                       LeftShoulder=(50, 0, 0), RightHip=(-18, 0, 0), LeftHip=(26, 0, 0))),
        key(0.8, pose(Root=(-22, 24, -4, 0, -0.18, -0.16), Neck=(12, -18, 0), RightShoulder=(40, 0, -30),
                      LeftShoulder=(20, 0, -6), RightHip=(-16, 0, 0), LeftHip=(24, 0, 0))),
        key(1.0, pose()),
    ],
}

# Firebomb (0.75 s, awakened): the bottle's rag lit off his own burning
# left fist (0.12), cocked, released at 0.42.
CLIPS["Pyro_Firebomb"] = {
    "length": 0.75,
    "keys": [
        key(0, pose()),
        key(0.12, pose(Root=(-6, -6, 0), Neck=(-12, 6, 0), RightShoulder=(70, 0, -14), LeftShoulder=(86, 0, 40)), "flat"),
        key(0.3, pose(Root=(6, -30, 4, 0, -0.08, 0.1), Neck=(0, 24, 0), RightShoulder=(194, 0, 10),
                      LeftShoulder=(86, 0, 4), RightHip=(-10, 0, 0), LeftHip=(22, 0, 0))),
        key(0.42, pose(Root=(-12, 6, -2, 0, -0.14, -0.1), Neck=(2, -4, 0), RightShoulder=(150, 0, -2),
                       LeftShoulder=(50, 0, 0), RightHip=(-18, 0, 0), LeftHip=(26, 0, 0))),
        key(0.55, pose(Root=(-22, 24, -4, 0, -0.18, -0.16), Neck=(12, -18, 0), RightShoulder=(40, 0, -30),
                       LeftShoulder=(20, 0, -6), RightHip=(-16, 0, 0), LeftHip=(24, 0, 0))),
        key(0.75, pose()),
    ],
}

# Fire breath (1.4 s; INFERNO BREATH plays it too): a swig from the hip
# flask in his left hand, head back (0.15-0.32); the Zippo up in his right
# (struck at 0.38) under his lips; leaning in, he spits the fuel through the
# flame from 0.55 (the cone: 0.55 → 1.0 / 1.15), swaying a little; then
# back to guard.
_spray = dict(Root=(-14, 0, 0, 0, -0.04, -0.08), Neck=(-4, 0, 0), RightShoulder=(112, 0, -48),
              LeftShoulder=(24, 0, 12), RightHip=(-8, 0, 0), LeftHip=(12, 0, 0))
CLIPS["Pyro_Breath"] = {
    "length": 1.4,
    "keys": [
        key(0, pose()),
        key(0.16, pose(Root=(2, -4, 0), Neck=(22, 2, 0), RightShoulder=(60, 0, -26), LeftShoulder=(132, 0, 52))),
        key(0.3, pose(Root=(4, -4, 0), Neck=(26, 2, 0), RightShoulder=(62, 0, -26), LeftShoulder=(130, 0, 55)), "flat"),
        key(0.42, pose(Root=(-6, -2, 0), Neck=(0, 0, 0), RightShoulder=(100, 0, -40), LeftShoulder=(40, 0, 14))),
        key(0.55, pose(**_spray)),
        key(0.75, pose(**dict(_spray, Root=(-15, 8, 0, 0, -0.04, -0.09), Neck=(-4, -4, 0)))),
        key(0.95, pose(**dict(_spray, Root=(-14, -8, 0, 0, -0.04, -0.08), Neck=(-4, 4, 0)))),
        key(1.15, pose(**_spray)),
        key(1.25, pose(Root=(-8, -6, 0), Neck=(2, 4, 0), RightShoulder=(86, 0, -30), LeftShoulder=(70, 0, 24))),
        key(1.4, pose()),
    ],
}
CLIPS["Pyro_BreathBig"] = CLIPS["Pyro_Breath"]

# Douse (0.9 s): the jerrycan in his right hand. A backswing (0.14), the
# swing forward and up: the petrol leaves the spout at 0.42; follow-through.
CLIPS["Pyro_Douse"] = {
    "length": 0.9,
    "keys": [
        key(0, pose()),
        key(0.16, pose(Root=(-10, -26, 0, 0, -0.04, 0.04), Neck=(4, 22, 0), RightShoulder=(-34, 0, 6),
                       LeftShoulder=(40, 0, 20), RightHip=(6, 0, 0), LeftHip=(-4, 0, 0))),
        key(0.3, pose(Root=(-12, -6, 0, 0, -0.08, -0.04), Neck=(2, 6, 0), RightShoulder=(40, 0, -4),
                      LeftShoulder=(36, 0, 14), RightHip=(-8, 0, 0), LeftHip=(16, 0, 0))),
        key(0.42, pose(Root=(-14, 14, 0, 0, -0.1, -0.1), Neck=(4, -10, 0), RightShoulder=(100, 0, -6),
                       LeftShoulder=(30, 0, 10), RightHip=(-14, 0, 0), LeftHip=(22, 0, 0))),
        key(0.58, pose(Root=(-10, 18, 0, 0, -0.08, -0.1), Neck=(6, -12, 0), RightShoulder=(124, 0, -8),
                       LeftShoulder=(28, 0, 8), RightHip=(-12, 0, 0), LeftHip=(20, 0, 0))),
        key(0.9, pose()),
    ],
}

# Burning fist (0.6 s, awakened): a right hook. Coil (0.1), the fist round
# at chin height (the hit at 0.24), follow-through.
CLIPS["Pyro_FirePunch"] = {
    "length": 0.6,
    "keys": [
        key(0, pose()),
        key(0.1, pose(Root=(-8, -30, 0), Neck=(6, 26, 0), RightShoulder=(88, 0, 16), LeftShoulder=(112, 0, 38),
                      RightHip=(0, 0, 0), LeftHip=(4, 0, 0))),
        key(0.24, pose(Root=(-12, 26, 0, 0, -0.04, -0.08), Neck=(6, -22, 0), RightShoulder=(92, 0, -62),
                       LeftShoulder=(110, 0, 40), RightHip=(-8, 0, 0), LeftHip=(10, 0, 0))),
        key(0.34, pose(Root=(-12, 34, 0, 0, -0.04, -0.08), Neck=(6, -26, 0), RightShoulder=(86, 0, -84),
                       LeftShoulder=(100, 0, 36), RightHip=(-8, 0, 0), LeftHip=(10, 0, 0))),
        key(0.6, pose()),
    ],
}

# Burning man (1.0 s, the Awakening): arms crossed in front, the Zippo in
# his right touches his left forearm (0.4), the petrol-soaked wraps go up
# (0.55): both arms flung out at 0.75, chest out, head back.
CLIPS["Pyro_Awaken"] = {
    "length": 1.0,
    "keys": [
        key(0, pose()),
        key(0.18, pose(Root=(-10, 0, 0), Neck=(-20, 0, 0), RightShoulder=(70, 0, -44), LeftShoulder=(76, 0, 30))),
        key(0.4, pose(Root=(-12, 4, 0, 0, -0.06, 0), Neck=(-24, 4, 0), RightShoulder=(66, 0, -56),
                      LeftShoulder=(80, 0, 26)), "flat"),
        key(0.55, pose(Root=(-14, 0, 0, 0, -0.08, 0), Neck=(-18, 0, 0), RightShoulder=(80, 0, -20),
                       LeftShoulder=(82, 0, 20))),
        key(0.75, pose(Root=(6, 0, 0, 0, 0, 0.04), Neck=(18, 0, 0), RightShoulder=(40, 0, 70),
                       LeftShoulder=(40, 0, -70), RightHip=(-4, 0, 4), LeftHip=(4, 0, -4)), "flat"),
        key(1.0, pose()),
    ],
}

# Immolation (5.8 s, Shared/Finishers "Immolate"): the body lies across in
# front of him (its head to his left). The jerrycan in his right fist:
# lifted over their head (0.15), poured from the head down along the body
# (0.4 → 1.45) as his torso turns from left to right, tossed out to his
# right (1.6); the Zippo up at his chest, opened (1.85), struck (2.15); he
# looks at it, then down at them (2.4); his arm out over their chest, the
# hand opens (2.8); the fire goes up (3.05): he leans away from the heat,
# half a step back, then stands and watches, breathing.
_watch = dict(Root=(-6, 0, 0, 0, 0, 0.3), Neck=(-22, 0, 0), RightShoulder=(6, 0, 4),
              LeftShoulder=(4, 0, -4))
CLIPS["Pyro_FinisherImmolate"] = {
    "length": 5.8,
    "keys": [
        key(0, pose()),
        key(0.15, pose(Root=(-14, 38, 0), Neck=(-20, -8, 0), RightShoulder=(52, 0, -6), LeftShoulder=(58, 0, 30))),
        key(0.4, pose(Root=(-18, 40, 0, 0, -0.06, -0.04), Neck=(-26, -6, 0), RightShoulder=(46, 0, -4),
                      LeftShoulder=(54, 0, 30))),
        key(0.9, pose(Root=(-18, 10, 0, 0, -0.06, -0.04), Neck=(-28, 0, 0), RightShoulder=(44, 0, -2),
                      LeftShoulder=(52, 0, 28))),
        key(1.45, pose(Root=(-16, -22, 0, 0, -0.06, -0.04), Neck=(-26, 6, 0), RightShoulder=(44, 0, 0),
                       LeftShoulder=(50, 0, 26))),
        key(1.6, pose(Root=(-8, -34, 0), Neck=(-10, 20, 0), RightShoulder=(48, 0, 56), LeftShoulder=(20, 0, 10))),
        key(1.85, pose(Root=(-6, -2, 0), Neck=(-18, 2, 0), RightShoulder=(74, 0, -22), LeftShoulder=(8, 0, -2))),
        key(2.15, pose(Root=(-6, 0, 0), Neck=(-16, 2, 0), RightShoulder=(78, 0, -22), LeftShoulder=(8, 0, -2)), "flat"),
        key(2.45, pose(Root=(-10, 0, 0), Neck=(-30, 0, 0), RightShoulder=(76, 0, -18), LeftShoulder=(6, 0, -2)), "flat"),
        key(2.8, pose(Root=(-26, 8, 0, 0, -0.1, -0.12), Neck=(-30, 0, 0), RightShoulder=(56, 0, -40),
                      LeftShoulder=(6, 0, -2)), "flat"),
        key(3.05, pose(Root=(-18, 4, 0, 0, -0.06, -0.06), Neck=(-28, 0, 0), RightShoulder=(48, 0, -24),
                       LeftShoulder=(6, 0, -2))),
        key(3.3, pose(Root=(8, 10, 0, 0, 0, 0.35), Neck=(-6, 24, 0), RightShoulder=(70, 0, -30),
                      LeftShoulder=(20, 0, -4), RightHip=(6, 0, 0), LeftHip=(-6, 0, 0))),
        key(3.8, pose(**_watch)),
        key(4.6, pose(**dict(_watch, Root=(-7, 0, 0, 0, -0.02, 0.3), Neck=(-24, 2, 0)))),
        key(5.3, pose(**_watch)),
        key(5.8, pose()),
    ],
}

# The victim (5.8 s), laid on its back at Finishers.SIDE_VICTIM (identity =
# lying straight; Shoulder X+ lifts an arm toward the sky). Limp, its head
# turned toward him; it flinches and coughs as the petrol hits its face; a
# hand comes up, begging (2.4); the fire (3.05): arms fly up, it thrashes,
# kicks, rolls its shoulders, its head thrown about; from 4.3 it curls up
# (the heat tightens the muscles: arms up and in, fists at the face, knees
# up) and goes still at 4.6 (the kill: the ragdoll takes it from there).
def victim(root=(0, 0, 0), neck=(0, 30, 0), rs=(4, 0, 4), ls=(6, 0, -4), rh=(6, 0, 4), lh=(4, 0, -4)):
    return {"Root": root, "Neck": neck, "RightShoulder": rs, "LeftShoulder": ls, "RightHip": rh, "LeftHip": lh}


CLIPS["Pyro_FinisherImmolateVictim"] = {
    "length": 5.8,
    "keys": [
        key(0, victim()),
        key(0.4, victim(neck=(0, 34, 0))),
        key(0.55, victim(neck=(-10, -20, 0), rs=(24, 0, 6), ls=(30, 0, -8))),
        key(0.8, victim(neck=(-6, 30, 0), rs=(14, 0, 6), ls=(40, 0, -10), rh=(14, 0, 4))),
        key(1.05, victim(neck=(-12, -14, 0), rs=(30, 0, 8), ls=(22, 0, -6), lh=(12, 0, -4))),
        key(1.4, victim(neck=(-8, 24, 0), rs=(18, 0, 6), ls=(14, 0, -4))),
        key(2.0, victim(neck=(-4, 32, 0), rs=(10, 0, 4), ls=(8, 0, -4))),
        key(2.4, victim(neck=(-24, 30, 0), rs=(62, 0, -6), ls=(10, 0, -4)), "flat"),
        key(2.85, victim(neck=(-20, 28, 0), rs=(56, 0, -4), ls=(12, 0, -4)), "flat"),
        key(3.05, victim(neck=(-6, 26, 0), rs=(40, 0, 4), ls=(12, 0, -4))),
        key(3.15, victim(root=(0, 0, 8), neck=(24, 10, 0), rs=(130, 0, 20), ls=(120, 0, -24), rh=(40, 0, 6),
                         lh=(10, 0, -6))),
        key(3.35, victim(root=(0, 4, -12), neck=(10, -30, 0), rs=(80, 0, -20), ls=(150, 0, -10), rh=(8, 0, 4),
                         lh=(46, 0, -6))),
        key(3.55, victim(root=(0, -4, 14), neck=(16, 30, 0), rs=(150, 0, 10), ls=(70, 0, 20), rh=(50, 0, 8),
                         lh=(6, 0, -4))),
        key(3.75, victim(root=(0, 3, -10), neck=(6, -26, 0), rs=(70, 0, -30), ls=(140, 0, -16), rh=(12, 0, 4),
                         lh=(52, 0, -8))),
        key(3.95, victim(root=(0, -3, 12), neck=(14, 24, 0), rs=(140, 0, 6), ls=(80, 0, 28), rh=(46, 0, 6),
                         lh=(18, 0, -4))),
        key(4.15, victim(root=(0, 2, -6), neck=(4, -10, 0), rs=(96, 0, -20), ls=(110, 0, 10), rh=(30, 0, 4),
                         lh=(38, 0, -6))),
        key(4.4, victim(root=(-4, 0, 2), neck=(-16, 10, 0), rs=(84, 0, -34), ls=(84, 0, 34), rh=(40, 0, 6),
                        lh=(36, 0, -6))),
        key(4.6, victim(root=(-6, 0, 2), neck=(-20, 12, 0), rs=(80, 0, -38), ls=(80, 0, 38), rh=(44, 0, 6),
                        lh=(40, 0, -6)), "flat"),
        key(5.8, victim(root=(-6, 0, 2), neck=(-20, 12, 0), rs=(80, 0, -38), ls=(80, 0, 38), rh=(44, 0, 6),
                        lh=(40, 0, -6))),
    ],
}

HEADER = """--!strict
-- The Pyromaniac's clips (Shared/Kits/Pyromaniac). R6Pose format, see R6Pose /
-- CombatClips. Merged into CombatClips (the end of that file).
--
-- GENERATED by tools/anim/pyro_clips.py (edit the key poses there, then
-- --write; --render draws filmstrips to check them). Whole-body key poses,
-- anticipation before each action, the torso leading and the arm after it,
-- eased holds on the beats. Every clip starts and ends on the Guard pose
-- (the victim's on the floor). The timings must stay in sync with the kit
-- (Shared/Kits/Pyromaniac), Shared/Finishers "Immolate" and Client/Combat/
-- PyroFx (the props and sounds):
--
--   • Pyro_Zippo: opened 0.15, struck 0.27, thrust into the face 0.42 (the hit).
--   • Pyro_Molotov: the rag lit 0.3, the bottle released 0.68.
--   • Pyro_Firebomb: lit off his fist 0.12, released 0.42.
--   • Pyro_Breath / Pyro_BreathBig: swig 0.15-0.32, struck 0.38, the flame
--     0.55 → 1.0 / 1.15.
--   • Pyro_Douse: the petrol leaves the can at 0.42.
--   • Pyro_FirePunch: the hook lands at 0.24.
--   • Pyro_Awaken: 1.0 s (Config.Kits.AWAKEN_TIME), lit at 0.55.
--   • Pyro_FinisherImmolate / ...Victim: 5.8 s, see Shared/Finishers.
--   • (Pyro_Rush is the Street Brawler's tackle run: CombatClips.)

local R6Pose = require(script.Parent.R6Pose)

local clips: { [string]: R6Pose.Clip } = {
"""


def num(value):
    text = f"{value:.3f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def vec(values):
    return f"Vector3.new({num(values[0])}, {num(values[1])}, {num(values[2])})"


def luau():
    out = [HEADER]
    written = {}
    for name, clip in CLIPS.items():
        if id(clip) in written:
            continue
        written[id(clip)] = name
        out.append(f"\t{name} = {{\n\t\tlength = {num(clip['length'])},\n\t\tlooped = false,\n\t\tkeyframes = {{\n")
        for k in clip["keys"]:
            out.append(f"\t\t\t{{\n\t\t\t\ttime = {num(k['time'])},\n")
            if k["tangent"]:
                out.append(f"\t\t\t\ttangent = \"{k['tangent']}\",\n")
            out.append("\t\t\t\tpose = {\n")
            for joint in JOINTS:
                value = k["pose"].get(joint)
                if value is None:
                    continue
                rot = value[:3]
                pos = value[3:] if len(value) > 3 else None
                if pos:
                    out.append(f"\t\t\t\t\t{joint} = {{ rot = {vec(rot)}, pos = {vec(pos)} }},\n")
                else:
                    out.append(f"\t\t\t\t\t{joint} = {{ rot = {vec(rot)} }},\n")
            out.append("\t\t\t\t},\n\t\t\t},\n")
        out.append("\t\t},\n\t},\n")
    out.append("}\n")
    for name, clip in CLIPS.items():
        first = written[id(clip)]
        if first != name:
            out.append(f"-- (the same clip)\nclips.{name} = clips.{first}\n")
    out.append("\nreturn clips\n")
    return "".join(out)


# --- preview: the same spline and joints as R6Pose, drawn with PIL ----------

def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def translate(x, y, z):
    return [[1, 0, 0, x], [0, 1, 0, y], [0, 0, 1, z], [0, 0, 0, 1]]


def angles(rx, ry, rz):
    def rx_m(a):
        c, s = math.cos(a), math.sin(a)
        return [[1, 0, 0, 0], [0, c, -s, 0], [0, s, c, 0], [0, 0, 0, 1]]

    def ry_m(a):
        c, s = math.cos(a), math.sin(a)
        return [[c, 0, s, 0], [0, 1, 0, 0], [-s, 0, c, 0], [0, 0, 0, 1]]

    def rz_m(a):
        c, s = math.cos(a), math.sin(a)
        return [[c, -s, 0, 0], [s, c, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]

    return mat_mul(mat_mul(rx_m(math.radians(rx)), ry_m(math.radians(ry))), rz_m(math.radians(rz)))


def apply(m, p):
    return tuple(m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3] for i in range(3))


# joint → (parent part, joint point in parent, part centre in parent)
RIG = {
    "Torso": ("Root", "HRP", (0, 0, 0), (0, 0, 0)),
    "Head": ("Neck", "Torso", (0, 1, 0), (0, 1.5, 0)),
    "Right Arm": ("RightShoulder", "Torso", (1, 0.5, 0), (1.5, 0, 0)),
    "Left Arm": ("LeftShoulder", "Torso", (-1, 0.5, 0), (-1.5, 0, 0)),
    "Right Leg": ("RightHip", "Torso", (1, -1, 0), (0.5, -2, 0)),
    "Left Leg": ("LeftHip", "Torso", (-1, -1, 0), (-0.5, -2, 0)),
}
SIZES = {"Torso": (2, 2, 1), "Head": (1.2, 1, 1), "Right Arm": (1, 2, 1), "Left Arm": (1, 2, 1),
         "Right Leg": (1, 2, 1), "Left Leg": (1, 2, 1)}
COLORS = {"Torso": (90, 80, 70), "Head": (220, 180, 150), "Right Arm": (200, 90, 60),
          "Left Arm": (70, 120, 200), "Right Leg": (60, 60, 70), "Left Leg": (90, 90, 110)}


def sample(clip, t):
    keys = clip["keys"]
    times = [k["time"] for k in keys]
    t = max(0, min(clip["length"], t))
    result = {}
    for joint in JOINTS:
        vals = []
        for k in keys:
            v = k["pose"].get(joint, (0, 0, 0))
            v = tuple(v) + (0, 0, 0) if len(v) == 3 else tuple(v)
            vals.append(v)
        n = len(vals)
        tangents = []
        for i in range(n):
            if i == 0 or i == n - 1 or keys[i]["tangent"] == "flat":
                tangents.append((0,) * 6)
            else:
                span = times[i + 1] - times[i - 1]
                tangents.append(tuple((vals[i + 1][c] - vals[i - 1][c]) / span for c in range(6)))
        index = n - 2
        for i in range(n - 1):
            if times[i + 1] > t:
                index = i
                break
        span = times[index + 1] - times[index]
        u = (t - times[index]) / span if span > 0 else 0
        u = max(0, min(1, u))
        h00, h10 = 2 * u**3 - 3 * u**2 + 1, (u**3 - 2 * u**2 + u) * span
        h01, h11 = -2 * u**3 + 3 * u**2, (u**3 - u**2) * span
        result[joint] = tuple(
            vals[index][c] * h00 + tangents[index][c] * h10 + vals[index + 1][c] * h01 + tangents[index + 1][c] * h11
            for c in range(6)
        )
    return result


def parts_at(clip, t, base):
    p = sample(clip, t)
    frames = {"HRP": base}
    for part in ["Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"]:
        joint, parent, jp, centre = RIG[part]
        v = p[joint]
        local = mat_mul(mat_mul(translate(*jp), mat_mul(translate(*v[3:]), angles(*v[:3]))),
                        translate(centre[0] - jp[0], centre[1] - jp[1], centre[2] - jp[2]))
        frames[part] = mat_mul(frames[parent], local)
    return frames


def box_faces(m, size):
    sx, sy, sz = (s / 2 for s in size)
    corners = [apply(m, (x * sx, y * sy, z * sz)) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    faces = [(0, 1, 3, 2), (4, 5, 7, 6), (0, 1, 5, 4), (2, 3, 7, 6), (0, 2, 6, 4), (1, 3, 7, 5)]
    return [[corners[i] for i in f] for f in faces]


def render(clip, base, path, victim_clip=None, victim_base=None, frames=12):
    from PIL import Image, ImageDraw

    views = {
        "front": lambda p: (-p[0], -p[1], p[2]),  # camera at -Z looking +Z (his right on our left)
        "side": lambda p: (-p[2], -p[1], -p[0]),  # from his right
        "top": lambda p: (p[0], p[2], -p[1]),
    }
    cell = 150
    scale = 17
    img = Image.new("RGB", (cell * frames, cell * len(views)), (235, 232, 225))
    draw = ImageDraw.Draw(img)
    for vi, (vname, proj) in enumerate(views.items()):
        for fi in range(frames):
            t = clip["length"] * fi / (frames - 1)
            polys = []
            sets = [(clip, base)]
            if victim_clip:
                sets.append((victim_clip, victim_base))
            for c, b in sets:
                fr = parts_at(c, t, b)
                for part, size in SIZES.items():
                    for face in box_faces(fr[part], size):
                        pts = [proj(q) for q in face]
                        depth = sum(q[2] for q in pts) / 4
                        polys.append((depth, part, pts))
            polys.sort(key=lambda x: -x[0])
            ox, oy = fi * cell + cell / 2, vi * cell + cell / 2 + (10 if vname != "top" else 0)
            for _, part, pts in polys:
                draw.polygon([(ox + q[0] * scale, oy + q[1] * scale) for q in pts], fill=COLORS[part],
                             outline=(30, 30, 30))
            # the floor line (feet at Y = -3)
            if vname != "top":
                fy = oy + 3 * scale
                draw.line([(fi * cell, fy), (fi * cell + cell, fy)], fill=(120, 120, 120))
            draw.text((fi * cell + 3, vi * cell + 2), f"{vname} {t:.2f}", fill=(0, 0, 0))
    img.save(path)


SIDE_VICTIM = [[0, -1, 0, 0.3], [0, 0, -1, -2.5], [1, 0, 0, -2.7], [0, 0, 0, 1]]
IDENTITY = translate(0, 0, 0)

if __name__ == "__main__":
    if "--write" in sys.argv:
        open("src/client/Animation/PyroClips.luau", "w").write(luau())
    if "--render" in sys.argv:
        out = sys.argv[sys.argv.index("--render") + 1]
        os.makedirs(out, exist_ok=True)
        for name, clip in CLIPS.items():
            if name in ("Pyro_BreathBig", "Pyro_FinisherImmolateVictim"):
                continue
            if name == "Pyro_FinisherImmolate":
                render(clip, IDENTITY, f"{out}/{name}.png", CLIPS["Pyro_FinisherImmolateVictim"], SIDE_VICTIM, 16)
            else:
                render(clip, IDENTITY, f"{out}/{name}.png")
