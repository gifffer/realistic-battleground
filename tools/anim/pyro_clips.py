"""The Pyromaniac's clips (Shared/Kits/Pyromaniac): authored here as key
poses, written to src/client/Animation/PyroClips.luau, checked by forward
kinematics with his flamethrower in the hands, and rendered as filmstrips.

Same format and spline as Client/Animation/R6Pose (degrees, parent space;
Root X- leans forward, Y+ turns left; Shoulder X+ raises the arm forward,
RightShoulder Z- / LeftShoulder Z+ bring the arm across the body; Hip X+
swings the leg forward; Neck X+ tips the head back, Y+ turns it left).

The gun (Client/Combat/Flamethrower): slung on the Torso at SLING, welded to
the Right Arm at GRIP once drawn (both read from Combat/FlamethrowerShape,
generated from the validated model). The gun is rigid on the right arm, so
where the muzzle points is set by the Root and the RightShoulder: the firing
keys are written as an aim (a pitch, a yaw, or a point to hit) and the
RightShoulder is SOLVED for it; the LeftShoulder is solved to put the left
hand on the foregrip (or the handwheel, the valve, the pilot burner).
The finisher's pilot ritual holds the gun upright (PORT, solved here and
written into Combat/Flamethrower).

  python3 tools/anim/pyro_clips.py --write         the Luau (PyroClips, PORT)
  python3 tools/anim/pyro_clips.py --check         FK checks (exit 1 on a fail)
  python3 tools/anim/pyro_clips.py --render <dir>  the filmstrips (PIL)
"""

import json
import math
import os
import re
import sys

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHAPE_PATH = os.path.join(ROOT_DIR, "src", "client", "Combat", "FlamethrowerShape.luau")
GUN_PATH = os.path.join(ROOT_DIR, "src", "client", "Combat", "Flamethrower.luau")
CLIPS_PATH = os.path.join(ROOT_DIR, "src", "client", "Animation", "PyroClips.luau")

JOINTS = ["Root", "Neck", "RightShoulder", "LeftShoulder", "RightHip", "LeftHip"]

GUARD = {
    "Root": (-8, -12, 0),
    "Neck": (6, 10, 0),
    "RightShoulder": (111, 0, -36.5),
    "LeftShoulder": (115, 0, 37),
}

FPS = 60
MAX_STEP = 20  # degrees per frame at 60 fps (docs/references/video17.md)


# --- matrices (4x4, row-major lists) -----------------------------------------

def mat_mul(a, b):
    b0, b1, b2, b3 = b
    return [[r[0] * b0[j] + r[1] * b1[j] + r[2] * b2[j] + r[3] * b3[j] for j in range(4)] for r in a]


def translate(x, y, z):
    return [[1, 0, 0, x], [0, 1, 0, y], [0, 0, 1, z], [0, 0, 0, 1]]


def angles(rx, ry, rz):
    """CFrame.Angles(rx, ry, rz) in degrees: Rx * Ry * Rz."""
    a, b, c = math.radians(rx), math.radians(ry), math.radians(rz)
    ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
    return [
        [cb * cc, -cb * sc, sb, 0],
        [sa * sb * cc + ca * sc, -sa * sb * sc + ca * cc, -sa * cb, 0],
        [-ca * sb * cc + sa * sc, ca * sb * sc + sa * cc, ca * cb, 0],
        [0, 0, 0, 1],
    ]


def apply(m, p):
    return tuple(m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3] for i in range(3))


def turn(m, v):
    return tuple(m[i][0] * v[0] + m[i][1] * v[1] + m[i][2] * v[2] for i in range(3))


def inverse(m):
    r = [[m[j][i] for j in range(3)] for i in range(3)]
    t = [-sum(r[i][k] * m[k][3] for k in range(3)) for i in range(3)]
    return [r[0] + [t[0]], r[1] + [t[1]], r[2] + [t[2]], [0, 0, 0, 1]]


def cframe(values):
    """A Roblox CFrame.new(...) (3 or 12 numbers) as a matrix."""
    if len(values) == 3:
        return translate(*values)
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = values
    return [[r00, r01, r02, x], [r10, r11, r12, y], [r20, r21, r22, z], [0, 0, 0, 1]]


def to_euler(m):
    """XYZ degrees (R = Rx Ry Rz, like CFrame.Angles) of a rotation."""
    y = math.asin(max(-1.0, min(1.0, m[0][2])))
    x = math.atan2(-m[1][2], m[2][2])
    z = math.atan2(-m[0][1], m[0][0])
    return (math.degrees(x), math.degrees(y), math.degrees(z))


def sub(a, b):
    return tuple(a[i] - b[i] for i in range(3))


def add(a, b):
    return tuple(a[i] + b[i] for i in range(3))


def scale(a, k):
    return tuple(c * k for c in a)


def dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def length(a):
    return math.sqrt(dot(a, a))


def unit(a):
    n = length(a)
    return scale(a, 1 / n) if n > 1e-9 else (0, 0, 0)


# --- the gun -------------------------------------------------------------------

def read_shape():
    text = open(SHAPE_PATH).read()

    def numbers(block):
        return [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?(?:e-?\d+)?", block)]

    def constant(name):
        m = re.search(r"Shape\.%s = CFrame\.new\(([^)]*)\)" % name, text)
        return cframe(numbers(m.group(1)))

    points = {}
    block = re.search(r"Shape\.POINTS = \{(.*?)\n\} ::", text, re.S).group(1)
    for m in re.finditer(r"(\w+) = CFrame\.new\(([^)]*)\)", block):
        points[m.group(1)] = cframe(numbers(m.group(2)))
    pivots = {}
    block = re.search(r"Shape\.PIVOTS = \{(.*?)\n\} ::", text, re.S).group(1)
    for m in re.finditer(r"(\w+) = CFrame\.new\(([^)]*)\)", block):
        pivots[m.group(1)] = cframe(numbers(m.group(2)))
    return constant("GRIP"), constant("SLING"), points, pivots


GRIP, SLING, POINTS, PIVOTS = read_shape()


def point(name):
    return apply(POINTS[name], (0, 0, 0))


MUZZLE = point("Muzzle")
GRIP_R = point("GripR")
GRIP_L = point("GripL")
STOCK = point("Stock")
PILOT = point("PilotLight")
WHEEL = apply(PIVOTS["Wheel"], (0, 0, 0))
VALVE = apply(PIVOTS["Valve"], (0, 0, 0))
BOTTLE = (0.43, -0.52, -1.23)  # (the tank's centre, gun space)

# The finisher's upright hold (Right Arm space), set by solve_port() below.
PORT = None


# --- the rig (R6Pose: T = C0rot^-1 * pose * C0rot) ----------------------------

# part -> (joint, parent part, joint point in parent, part centre in parent)
RIG = {
    "Torso": ("Root", "HRP", (0, 0, 0), (0, 0, 0)),
    "Head": ("Neck", "Torso", (0, 1, 0), (0, 1.5, 0)),
    "Right Arm": ("RightShoulder", "Torso", (1, 0.5, 0), (1.5, 0, 0)),
    "Left Arm": ("LeftShoulder", "Torso", (-1, 0.5, 0), (-1.5, 0, 0)),
    "Right Leg": ("RightHip", "Torso", (1, -1, 0), (0.5, -2, 0)),
    "Left Leg": ("LeftHip", "Torso", (-1, -1, 0), (-0.5, -2, 0)),
}
PARTS = ["Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"]
HAND = (0, -0.92, 0)  # a hand, in its arm's space (the palm, near the end)


def joint_matrix(v):
    v = tuple(v) + (0, 0, 0) if len(v) == 3 else tuple(v)
    return mat_mul(translate(*v[3:]), angles(*v[:3]))


def frames_of(p, base):
    frames = {"HRP": base}
    for part in PARTS:
        joint, parent, jp, centre = RIG[part]
        v = p.get(joint, (0, 0, 0))
        local = mat_mul(mat_mul(translate(*jp), joint_matrix(v)),
                        translate(centre[0] - jp[0], centre[1] - jp[1], centre[2] - jp[2]))
        frames[part] = mat_mul(frames[parent], local)
    return frames


def gun_frame(frames, mount):
    if mount == "grip":
        return mat_mul(frames["Right Arm"], GRIP)
    if mount == "port":
        return mat_mul(frames["Right Arm"], PORT)
    return mat_mul(frames["Torso"], SLING)


def aim_of(gun):
    """(yaw, pitch) of the gun's forward (-Z) in HRP space, degrees; yaw + = left."""
    d = turn(gun, (0, 0, -1))
    return math.degrees(math.atan2(-d[0], -d[2])), math.degrees(math.asin(max(-1, min(1, d[1]))))


# --- a tiny solver (damped least squares, numeric Jacobian) -------------------

def solve3(a, b):
    m = [row[:] + [b[i]] for i, row in enumerate(a)]
    for c in range(3):
        piv = max(range(c, 3), key=lambda r: abs(m[r][c]))
        m[c], m[piv] = m[piv], m[c]
        if abs(m[c][c]) < 1e-12:
            return [0, 0, 0]
        for r in range(3):
            if r != c:
                f = m[r][c] / m[c][c]
                for k in range(c, 4):
                    m[r][k] -= f * m[c][k]
    return [m[i][3] / m[i][i] for i in range(3)]


def least_squares(residual, x0, iterations=25):
    x = list(x0)
    lam = 1e-2
    r = residual(x)
    cost = sum(v * v for v in r)
    for _ in range(iterations):
        h = 1e-3
        jac = []
        for i in range(3):
            xp = x[:]
            xp[i] += h
            rp = residual(xp)
            jac.append([(rp[k] - r[k]) / h for k in range(len(r))])
        jtj = [[sum(jac[i][k] * jac[j][k] for k in range(len(r))) for j in range(3)] for i in range(3)]
        jtr = [sum(jac[i][k] * r[k] for k in range(len(r))) for i in range(3)]
        while True:
            a = [[jtj[i][j] + (lam * (1 + jtj[i][i]) if i == j else 0) for j in range(3)] for i in range(3)]
            step = solve3(a, [-v for v in jtr])
            xn = [x[i] + step[i] for i in range(3)]
            rn = residual(xn)
            cn = sum(v * v for v in rn)
            if cn < cost:
                x, r, cost = xn, rn, cn
                lam = max(1e-6, lam * 0.3)
                break
            lam *= 10
            if lam > 1e8:
                return x
        if max(abs(s) for s in step) < 1e-4:
            break
    return x


def direction(yaw, pitch):
    y, p = math.radians(yaw), math.radians(pitch)
    return (-math.sin(y) * math.cos(p), math.sin(p), -math.cos(y) * math.cos(p))


def solve_right(p, want=None, at=None, ref=(40, -15, -60), hold="grip", base=None):
    """RightShoulder so the gun points along `want` (HRP space) or its muzzle
    ray goes through the point `at`; `ref` picks the twist about the gun."""
    base = base or translate(0, 0, 0)

    def residual(x):
        q = dict(p)
        q["RightShoulder"] = tuple(x)
        gun = gun_frame(frames_of(q, base), hold)
        d = turn(gun, (0, 0, -1))
        if at is not None:
            m = apply(gun, MUZZLE)
            to = unit(sub(at, m))
            err = sub(d, to)
        else:
            err = sub(d, want)
        return [e * 20 for e in err] + [(x[i] - ref[i]) / 90 for i in range(3)]

    return tuple(round(v, 2) for v in least_squares(residual, ref))


def solve_left(p, target, ref=(80, 0, 20), hold="grip", base=None, hand=HAND):
    """LeftShoulder so the left hand reaches `target` (a point in gun space)."""
    base = base or translate(0, 0, 0)

    def residual(x):
        q = dict(p)
        q["LeftShoulder"] = tuple(x)
        frames = frames_of(q, base)
        goal = apply(gun_frame(frames, hold), target)
        h = apply(frames["Left Arm"], hand)
        return [e * 4 for e in sub(h, goal)] + [(x[i] - ref[i]) / 120 for i in range(3)]

    return tuple(round(v, 2) for v in least_squares(residual, ref))


def solve_reach(p, side, goal, ref, base=None):
    """A shoulder so that hand reaches `goal` (a point in TORSO space)."""
    base = base or translate(0, 0, 0)
    joint = "RightShoulder" if side == "R" else "LeftShoulder"
    arm = "Right Arm" if side == "R" else "Left Arm"

    def residual(x):
        q = dict(p)
        q[joint] = tuple(x)
        frames = frames_of(q, base)
        h = apply(inverse(frames["Torso"]), apply(frames[arm], HAND))
        return [e * 4 for e in sub(h, goal)] + [(x[i] - ref[i]) / 120 for i in range(3)]

    return tuple(round(v, 2) for v in least_squares(residual, ref))


def look_neck(root, yaw=0.0, tilt=0.0, roll=0.0):
    """The Neck that turns the head back to `yaw` (HRP space), tipped `tilt`."""
    r = angles(*root[:3])
    want = mat_mul(mat_mul(angles(0, yaw, 0), angles(tilt, 0, 0)), angles(0, 0, roll))
    rt = [[r[j][i] for j in range(3)] + [0] for i in range(3)] + [[0, 0, 0, 1]]
    return tuple(round(v, 2) for v in to_euler(mat_mul(rt, want)))


def stance(drop=0.0, front=0.0, lean=0.0, spread=None):
    """Hips for a stance: the root `drop`s (studs) and the legs spread so the
    feet stay on the floor; `front` splits them (left leg forward, +deg);
    `lean` = the Root's X (the legs are kept under him)."""
    if spread is None:
        spread = math.degrees(math.acos(max(-1, min(1, 1 - drop / 2)))) if drop > 0 else 0
    return {
        "RightHip": (round(-lean - front * 0.6, 2), 0, round(spread, 2)),
        "LeftHip": (round(-lean + front, 2), 0, round(-spread, 2)),
    }


def pose(**joints):
    out = dict(GUARD)
    for name, value in joints.items():
        out[name] = value
    return out


def key(time, p, tangent=None, left=False, note=None):
    return {"time": time, "pose": p, "tangent": tangent, "left": left, "note": note}


def root_of(lean, yaw, roll=0.0, x=0.0, y=0.0, z=0.0):
    return (lean, yaw, roll, x, y, z)


LEFT_POINTS = {"grip": GRIP_L, "wheel": add(WHEEL, (-0.1, -0.12, 0)), "valve": add(VALVE, (0, 0.12, 0)),
               "pilot": add(PILOT, (0, -0.1, 0.05))}


def left_error(p, target, hold="grip", base=None):
    frames = frames_of(p, base or translate(0, 0, 0))
    goal = apply(gun_frame(frames, hold), target)
    return length(sub(apply(frames["Left Arm"], HAND), goal))


def aim(time, root, pitch=0.0, yaw=0.0, at=None, hips=None, neck=None, left="grip", rs_ref=(40, -15, -60),
        ls_ref=(80, 0, 20), tangent=None, look=(0.0, 4.0), note=None, hold="grip", base=None, ls=None, fit=True):
    """A key with the gun drawn: the muzzle along (yaw, pitch) from the HRP
    (or through `at`), the left hand on `left` ("grip", "wheel", "valve",
    "pilot", a gun-space point, or None: `ls` / a relaxed arm). `fit`: the
    torso's yaw and the arm's twist are adjusted (a few degrees) so the left
    hand reaches; the muzzle keeps its aim."""
    target = LEFT_POINTS.get(left, left) if isinstance(left, str) else left

    def build(dyaw, twist, dlean):
        r = (root[0] + dlean, root[1] + dyaw) + tuple(root[2:])
        p = pose(Root=r)
        if hips:
            p.update(hips)
        p["Neck"] = neck if neck is not None else look_neck(r, look[0], look[1])
        ref = (rs_ref[0], rs_ref[1] + twist, rs_ref[2])
        p["RightShoulder"] = solve_right(p, None if at else direction(yaw, pitch), at, ref, hold, base)
        if target is not None:
            p["LeftShoulder"] = solve_left(p, target, ls_ref, hold, base)
        else:
            p["LeftShoulder"] = ls or (40, 0, 14)
        return p

    key_id = repr((time, root, pitch, yaw, at, hips, neck, left, rs_ref, ls_ref, look, hold, fit, ls))
    FIT_USED.add(key_id)
    best = FIT_CACHE.get(key_id)
    if best is None:
        best = [0.0, 0.0, 0.0]
        if fit and target is not None:
            # a pattern search on (torso yaw, arm twist, lean)
            def score(v):
                err = left_error(build(*v), target, hold, base)
                return max(0, err - 0.1) + abs(v[0]) * 0.004 + abs(v[1]) * 0.002 + abs(v[2]) * 0.006

            current = score(best)
            steps = [12.0, 30.0, 8.0]
            while max(steps) > 1.0:
                moved = False
                for i in range(3):
                    for sign in (1, -1):
                        trial = best[:]
                        trial[i] += sign * steps[i]
                        value = score(trial)
                        if value < current - 1e-5:
                            best, current, moved = trial, value, True
                if not moved:
                    steps = [v * 0.5 for v in steps]
        FIT_CACHE[key_id] = best
    return key(time, build(*best), tangent, left=left if left else False, note=note)


FIT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pyro_fit.json")
try:
    FIT_CACHE = json.load(open(FIT_PATH))
except (OSError, ValueError):
    FIT_CACHE = {}
FIT_USED = set()


# Reaching back for the slung grip (just behind the right hip): the right
# hand at the gun's grip, in Torso space.
SLUNG_GRIP = apply(SLING, GRIP_R)


def reach(time, root, hips=None, ls=(70, 0, 24), look=(0.0, 2.0), tangent="flat", note=None):
    p = pose(Root=root)
    if hips:
        p.update(hips)
    p["Neck"] = look_neck(root, look[0], look[1])
    p["LeftShoulder"] = ls
    p["RightShoulder"] = solve_reach(p, "R", SLUNG_GRIP, (-20, 0, -8))
    return key(time, p, tangent, note=note)


CLIPS = {}
DRAWN = {}     # clip -> [(time, mount)]: where the gun is (sling / grip / port)
WINDOWS = {}   # clip -> [(from, to, label, pitch range, max |yaw|)]: the muzzle while it fires
SNAPS = {}     # clip -> [(from, to)]: deliberate snaps (over 20 deg / frame allowed)
RELEASES = {}  # clip -> [time]: a glob leaves the muzzle (FlaskDef.origin)

# --- the poses every move shares ---------------------------------------------

# Hip fire: bladed, the torso turned ~55 deg right, the stock by the right
# hip, the left hand on the foregrip, the head turned back to the target.
HIP = root_of(-12, -55)
HIP_LOW = root_of(-14, -56, 0, 0, -0.16, 0)
WIDE = stance(0.16, 10, -12)


def blend(pa, pb, u):
    out = {}
    for joint in JOINTS:
        va = tuple(pa.get(joint, (0, 0, 0))) + (0, 0, 0)
        vb = tuple(pb.get(joint, (0, 0, 0))) + (0, 0, 0)
        out[joint] = tuple(round(va[i] + (vb[i] - va[i]) * u, 2) for i in range(6))
    return out


def draw_keys(quick=False):
    """GUARD -> the hand at the slung grip -> the gun at the hip. A key
    half-way keeps the arm's speed even (no peak in the middle)."""
    t = 0.08 if quick else 0.15
    grab = reach(t, root_of(-6, -22, 0, 0, -0.04, 0), note="Grip")
    return [key(0, pose()), key(t * 0.5, blend(pose(), grab["pose"], 0.5)), grab]


def holster_keys(t, length):
    """The gun carried back to the hip (the Sling beat at `t`), then GUARD."""
    carry = reach(t, root_of(-6, -24, 0, 0, -0.04, 0), note="Sling")
    return [carry, key((t + length) * 0.5, blend(carry["pose"], pose(), 0.55)), key(length, pose())]


# --- SLOT 1: FLASH BURST (0.85): swings the gun up, blips the trigger: a
# fireball pops in their face at 0.42 (the hit) ----------------------------------
CLIPS["Pyro_Burst"] = {
    "length": 0.85,
    "keys": draw_keys() + [
        aim(0.27, HIP, -2, hips=WIDE, note="Pilot"),
        aim(0.32, root_of(-15, -61, 0, 0, -0.14, 0.02), -8, hips=stance(0.2, 10, -15), look=(0, 0)),
        aim(0.38, root_of(-13, -56, 0, 0, -0.12, -0.04), 3, hips=stance(0.18, 12, -13), tangent="flat",
            note="Trigger"),
        aim(0.42, root_of(-13, -55, 0, 0, -0.12, -0.05), 3, hips=stance(0.18, 12, -13), note="Pop"),
        aim(0.49, root_of(-5, -53, 0, 0, -0.08, 0.15), 11, hips=stance(0.12, 12, -5), look=(0, 8)),
        aim(0.57, root_of(-9, -54, 0, 0, -0.06, 0.06), -1, hips=stance(0.1, 10, -9), tangent="flat"),
    ] + holster_keys(0.68, 0.85),
}
DRAWN["Pyro_Burst"] = [(0, "sling"), (0.15, "grip"), (0.68, "sling")]
WINDOWS["Pyro_Burst"] = [(0.38, 0.43, "burst", (-6, 4), 4)]

# --- SLOT 2: NAPALM LOB (1.0): high port, the valve choked (0.25), pressure,
# the snap (0.6), the glob at 0.62 -------------------------------------------------
HIGH = root_of(4, -50, 0, 0, -0.06, 0)
HIGH_HIPS = stance(0.08, 18, 4)
CLIPS["Pyro_Napalm"] = {
    "length": 1.0,
    "keys": draw_keys() + [
        aim(0.29, HIGH, 35, hips=HIGH_HIPS, look=(0, 10), rs_ref=(80, -10, -60), note="Pilot"),
        aim(0.33, root_of(3, -50, 0, 0, -0.08, 0), 35, hips=HIGH_HIPS, left="valve", look=(0, 10),
            rs_ref=(80, -10, -60), ls_ref=(140, 0, 20), note="Choke"),
        aim(0.39, root_of(3, -50, 0, 0, -0.12, 0), 35, hips=stance(0.12, 18, 3), look=(0, 10),
            rs_ref=(80, -10, -60)),
        aim(0.58, root_of(2, -50, 0, 0, -0.18, 0), 35, hips=stance(0.18, 18, 2), look=(0, 10),
            rs_ref=(80, -10, -60), tangent="flat", note="Snap"),
        aim(0.62, root_of(2, -50, 0, 0, -0.18, 0), 35, hips=stance(0.18, 18, 2), look=(0, 10),
            rs_ref=(80, -10, -60), note="Release"),
        aim(0.68, root_of(9, -49, 0, 0, -0.12, 0.25), 45, hips=stance(0.12, 18, 9), look=(0, 12),
            rs_ref=(80, -10, -60)),
    ] + holster_keys(0.83, 1.0),
}
DRAWN["Pyro_Napalm"] = [(0, "sling"), (0.15, "grip"), (0.83, "sling")]
WINDOWS["Pyro_Napalm"] = [(0.58, 0.63, "lob", (30, 40), 4)]
RELEASES["Pyro_Napalm"] = [0.62]

# --- SLOT 3: FLAME STREAM (1.3): planted, braced; the stream 0.45 -> 1.0,
# swept left then right by the torso ------------------------------------------------
PLANT = stance(0.2, 12, -14)


def stream(time, yaw, lean=-14, pitch=-3, drop=-0.2, z=0.0, **kw):
    return aim(time, root_of(lean, -55 + yaw, 0, 0, drop, z), pitch, yaw, hips=stance(-drop, 12, lean),
               look=(yaw * 0.5, 0), **kw)


CLIPS["Pyro_Stream"] = {
    "length": 1.3,
    "keys": draw_keys() + [
        stream(0.27, 0, lean=-12, drop=-0.16, note="Pilot"),
        stream(0.42, 0, lean=-17, drop=-0.22, z=-0.06, tangent="flat", note="Trigger"),
        stream(0.585, 7, lean=-17, drop=-0.22, z=-0.06),
        stream(0.72, 12, lean=-17, drop=-0.22, z=-0.06),
        stream(0.86, 0, lean=-17, drop=-0.22, z=-0.06),
        stream(1.0, -12, lean=-16, drop=-0.22, z=-0.04, tangent="flat", note="Release"),
    ] + holster_keys(1.12, 1.3),
}
DRAWN["Pyro_Stream"] = [(0, "sling"), (0.15, "grip"), (1.12, "sling")]
WINDOWS["Pyro_Stream"] = [(0.45, 1.0, "stream", (-6, 3), 14)]

# --- SLOT 4: FUEL SPRAY (0.95): the pilot shut (0.18), backswing, a flat fan
# of raw fuel swept right -> left (0.4 -> 0.62), the pilot relit (0.72) ------------
def spray(time, yaw, pitch=-10, lean=-12, **kw):
    return aim(time, root_of(lean, -50 + yaw, 0, 0, -0.12, 0), pitch, yaw, hips=stance(0.12, 10, lean),
               look=(yaw * 0.4, -4), **kw)


CLIPS["Pyro_Spray"] = {
    "length": 0.95,
    "keys": draw_keys() + [
        spray(0.27, 0, note="PilotOut"),
        spray(0.38, -25, lean=-10, tangent="flat"),
        spray(0.45, -14, lean=-14, note="Hit"),
        spray(0.62, 20, pitch=-6, lean=-14, note="Release"),
        spray(0.66, 14, pitch=-8, lean=-10, tangent="flat", note="PilotRelight"),
    ] + holster_keys(0.77, 0.95),
}
DRAWN["Pyro_Spray"] = [(0, "sling"), (0.15, "grip"), (0.77, "sling")]
WINDOWS["Pyro_Spray"] = [(0.4, 0.62, "spray", (-14, -2), 26)]

# --- AWAKENING (1.0): quick draw, the handwheel cranked wide open, the gun
# swung straight up: a pillar of fire (0.45), the blowback (0.55), down to
# the hip (0.75) ---------------------------------------------------------------------
_crank_end = aim(0.27, root_of(-8, -50, 0, 0, -0.1, 0), 0, hips=stance(0.1, 10, -8), left="wheel",
                 ls_ref=(60, 0, -20))
_up = aim(0.42, root_of(8, -30, 0, 0, -0.12, 0.05), 78, hips=stance(0.12, 6, 8), left=None, ls=(30, 0, 30),
          rs_ref=(160, 0, -20), look=(0, 30), tangent="flat", note="Up")
CLIPS["Pyro_Awaken"] = {
    "length": 1.0,
    "keys": draw_keys(True) + [
        aim(0.14, root_of(-8, -50, 0, 0, -0.08, 0), 0, hips=stance(0.08, 10, -8), left="wheel",
            ls_ref=(60, 0, -20), note="Crank"),
        aim(0.2, root_of(-9, -52, 0, 0, -0.1, 0), 2, hips=stance(0.1, 10, -9), left="wheel",
            ls_ref=(60, 0, -20)),
        _crank_end,
        key(0.345, blend(_crank_end["pose"], _up["pose"], 0.5)),
        _up,
        aim(0.55, root_of(10, -28, 0, 0, -0.16, 0.12), 82, hips=stance(0.16, 6, 10), left=None,
            ls=(40, 0, 50), rs_ref=(160, 0, -20), look=(0, 34), note="Blowback"),
        aim(0.72, root_of(-12, -52, 0, 0, -0.14, 0), -6, hips=stance(0.14, 10, -12), left=None,
            ls=(55, 0, -10), look=(0, 0), note="Swing"),
    ] + holster_keys(0.83, 1.0),
}
DRAWN["Pyro_Awaken"] = [(0, "sling"), (0.08, "grip"), (0.83, "sling")]
WINDOWS["Pyro_Awaken"] = [(0.45, 0.55, "pillar", (70, 90), 90)]
SNAPS["Pyro_Awaken"] = [(0, 0.14)]

# --- AWAKENED 1: BLOWTORCH (0.6): chambered at the hip, a bayonet thrust, the
# lance lit at 0.22, the hit at 0.26, released 0.36 --------------------------------
CLIPS["Pyro_Torch"] = {
    "length": 0.6,
    "keys": draw_keys(True) + [
        aim(0.16, root_of(-8, -78, 0, 0, -0.1, 0.3), 0, hips=stance(0.1, 8, -8), tangent="flat",
            note="Chamber"),
        aim(0.22, root_of(-12, -64, 0, 0, -0.12, 0.05), 0, hips=stance(0.12, 14, -12), note="Trigger"),
        aim(0.26, root_of(-17, -48, 0, 0, -0.14, -0.4), 0, hips=stance(0.14, 20, -17), note="Hit"),
        aim(0.34, root_of(-16, -47, 0, 0, -0.14, -0.42), 1, hips=stance(0.14, 20, -16), tangent="flat"),
        aim(0.4, root_of(-10, -50, 0, 0, -0.1, -0.2), -4, hips=stance(0.1, 12, -10)),
    ] + holster_keys(0.45, 0.6),
}
DRAWN["Pyro_Torch"] = [(0, "sling"), (0.08, "grip"), (0.45, "sling")]
WINDOWS["Pyro_Torch"] = [(0.22, 0.36, "lance", (-6, 3), 4)]
SNAPS["Pyro_Torch"] = [(0, 0.16), (0.4, 0.6)]

# --- AWAKENED 2: NAPALM MORTAR (0.8): braced like a mortar at 45 deg, the
# shroud spits (0.25-0.4), the glob at 0.45, a big recoil ---------------------------
MORTAR_HIPS = stance(0.2, 14, 0)
CLIPS["Pyro_Mortar"] = {
    "length": 0.8,
    "keys": draw_keys(True) + [
        aim(0.18, root_of(0, -48, 0, 0, -0.2, 0), 45, hips=MORTAR_HIPS, look=(0, 14),
            rs_ref=(90, -10, -60), note="Pilot"),
        aim(0.33, root_of(-2, -48, 0, 0, -0.24, 0), 45, hips=stance(0.24, 14, -2), look=(0, 14),
            rs_ref=(90, -10, -60)),
        aim(0.43, root_of(-3, -48, 0, 0, -0.26, -0.02), 45, hips=stance(0.26, 14, -3), look=(0, 14),
            rs_ref=(90, -10, -60), tangent="flat", note="Trigger"),
        aim(0.45, root_of(-3, -48, 0, 0, -0.26, -0.02), 45, hips=stance(0.26, 14, -3), look=(0, 14),
            rs_ref=(90, -10, -60), note="Release"),
        aim(0.52, root_of(10, -46, 0, 0, -0.18, 0.4), 59, hips=stance(0.18, 14, 10), look=(0, 18),
            rs_ref=(90, -10, -60)),
        aim(0.6, root_of(2, -48, 0, 0, -0.14, 0.2), 40, hips=stance(0.14, 18, 2), look=(0, 10),
            rs_ref=(90, -10, -60), tangent="flat"),
    ] + holster_keys(0.64, 0.8),
}
DRAWN["Pyro_Mortar"] = [(0, "sling"), (0.08, "grip"), (0.64, "sling")]
WINDOWS["Pyro_Mortar"] = [(0.4, 0.46, "mortar", (40, 50), 4)]
RELEASES["Pyro_Mortar"] = [0.45]
SNAPS["Pyro_Mortar"] = [(0, 0.18), (0.6, 0.8)]


# --- AWAKENED 3: INFERNO (1.5): low and wide, the handwheel cranked (0.22-0.4),
# a huge stream 0.45 -> 1.25 swept +-16, then raked down the floor --------------------
def inferno(time, yaw, pitch=-3, lean=-16, drop=-0.24, **kw):
    return aim(time, root_of(lean, -55 + yaw, 0, 0, drop, -0.04), pitch, yaw, hips=stance(-drop, 14, lean),
               look=(yaw * 0.5, min(0, pitch * 0.5)), **kw)


CLIPS["Pyro_Inferno"] = {
    "length": 1.5,
    "keys": draw_keys(True) + [
        inferno(0.2, 0, lean=-12, drop=-0.2, left="wheel", ls_ref=(60, 0, -20), note="Crank"),
        inferno(0.3, 0, lean=-13, drop=-0.22, left="wheel", ls_ref=(60, 0, -20)),
        inferno(0.4, 0, lean=-13, drop=-0.22, left="wheel", ls_ref=(60, 0, -20)),
        inferno(0.45, 0, note="Trigger"),
        inferno(0.6, 10),
        inferno(0.72, 16),
        inferno(0.86, 0),
        inferno(1.0, -16),
        inferno(1.1, -10, pitch=-13),
        inferno(1.25, 0, pitch=-20, lean=-20, tangent="flat", note="Release"),
    ] + holster_keys(1.34, 1.5),
}
DRAWN["Pyro_Inferno"] = [(0, "sling"), (0.08, "grip"), (1.34, "sling")]
WINDOWS["Pyro_Inferno"] = [(0.45, 1.0, "inferno", (-6, 3), 18), (1.12, 1.25, "rake", (-22, -10), 12)]
SNAPS["Pyro_Inferno"] = [(0, 0.2), (1.25, 1.5)]


# --- AWAKENED 4: TORCH CHARGE (0.9): a low charge behind a wedge of fire
# (0.12 -> 0.55), the shroud rammed into them, a skid stop ----------------------------
def charge(time, step, **kw):
    hips = {"RightHip": (round(25 + 30 * step, 2), 0, 4), "LeftHip": (round(25 - 30 * step, 2), 0, -4)}
    return aim(time, root_of(-25, -50, 0, 0, -0.26, 0), -12, hips=hips, look=(0, 12), **kw)


CLIPS["Pyro_TorchCharge"] = {
    "length": 0.9,
    "keys": draw_keys(True) + [
        charge(0.14, 0, note="Trigger"),
        charge(0.25, 1),
        charge(0.36, -1),
        charge(0.47, 1),
        charge(0.55, 0, note="Release"),
        aim(0.64, root_of(4, -52, 0, 0, -0.2, 0.22), -6, hips=stance(0.2, 22, 4), look=(0, 4), tangent="flat"),
    ] + holster_keys(0.73, 0.9),
}
DRAWN["Pyro_TorchCharge"] = [(0, "sling"), (0.08, "grip"), (0.73, "sling")]
WINDOWS["Pyro_TorchCharge"] = [(0.16, 0.55, "wedge", (-16, -6), 4)]
SNAPS["Pyro_TorchCharge"] = [(0, 0.14), (0.64, 0.9)]


# --- FINISHER: IMMOLATION (5.8, Shared/Finishers "Immolate") -------------------------
# The body lies across in front of him (SIDE_VICTIM: its head to his left,
# chest up at about Y = -2). He steps back, cranks the valve (0.15), kills
# the pilot (0.25), hoses raw fuel head -> legs (0.4 -> 1.45), shakes the
# drips off (1.6); the gun stood upright (PORT), the Zippo to the pilot
# burner (1.85 -> 2.3); the quiet hold, the muzzle down to their face
# (2.8); point-blank full bore (3.05 -> 4.25) face -> legs; the vent (4.8).
SIDE_VICTIM = [[0, -1, 0, 0.3], [0, 0, -1, -2.5], [1, 0, 0, -2.7], [0, 0, 0, 1]]
IDENTITY = translate(0, 0, 0)
CHEST_Y = -1.95  # the top of the lying body


def on_body(x, z=-2.9):
    return (x, CHEST_Y, z)


BACK = 1.4  # the step back (studs) while he hoses them (the gun is 4.3 studs long)
HOSE_HIPS = stance(0.1, 16, -6)


def hose(time, x, lean=-6, yaw=0.0, drop=-0.1, back=BACK, **kw):
    return aim(time, root_of(lean, -55 + yaw, 0, 0, drop, back), at=on_body(x), hips=stance(-drop, 16, lean),
               look=(yaw * 0.6 + 10, -34), rs_ref=(60, -10, -60), **kw)


def solve_port():
    """The upright hold: the right hand low by the right hip, the gun stood
    up across his chest, the pilot burner by his left shoulder (where the
    left hand can bring the Zippo). Returns (PORT, the arm pose)."""
    root = root_of(-4, -20, 0, 0, -0.06, BACK * 0.6)
    p = pose(Root=root)
    p.update(stance(0.06, 10, -4))
    p["Neck"] = look_neck(root, 30, -12)
    rs = solve_reach(p, "R", (0.95, -0.85, -0.75), (20, 0, 10))
    p["RightShoulder"] = rs
    frames = frames_of(p, IDENTITY)
    torso = frames["Torso"]
    grip = apply(frames["Right Arm"], HAND)
    pilot_at = apply(torso, (-0.85, 1.2, -1.05))
    fwd = unit(sub(pilot_at, grip))  # the gun's forward (its -Z)
    # (the bottle side, +X of the gun, turned toward his front)
    out = unit(turn(torso, (0, 0, -1)))
    right = unit(sub(out, scale(fwd, dot(out, fwd))))
    up = cross(scale(fwd, -1), right)  # Y = Z x X with Z = -fwd
    z = scale(fwd, -1)
    rot = [[right[0], up[0], z[0], 0], [right[1], up[1], z[1], 0], [right[2], up[2], z[2], 0], [0, 0, 0, 1]]
    # the gun's grip point on the hand
    origin = sub(grip, turn(rot, GRIP_R))
    rot[0][3], rot[1][3], rot[2][3] = origin
    return mat_mul(inverse(frames["Right Arm"]), rot), p


PORT, PORT_POSE = solve_port()


def port_key(time, left_on, tangent=None, note=None, lean=-4, neck=None):
    p = dict(PORT_POSE)
    r = p["Root"]
    p["Root"] = (lean,) + tuple(r[1:])
    p["Neck"] = neck or p["Neck"]
    if left_on:
        p["LeftShoulder"] = solve_left(p, add(PILOT, (0.05, -0.15, 0.25)), (100, 0, 40), "port")
    else:
        p["LeftShoulder"] = solve_reach(p, "L", (-0.7, -0.1, -0.85), (60, 0, 10))
    return key(time, p, tangent, left="pilot" if left_on else False, note=note)


CLIPS["Pyro_FinisherImmolate"] = {
    "length": 5.8,
    "keys": draw_keys() + [
        hose(0.33, -0.6, back=1.1, left="wheel", ls_ref=(60, 0, -20), note="ValveOpen"),
        hose(0.42, -1.0, yaw=10, note="Douse"),
        hose(0.9, 0.4, yaw=2),
        hose(1.45, 2.3, yaw=-8, note="DouseEnd"),
        hose(1.6, 2.0, yaw=-6, lean=-2, tangent="flat", note="Drip"),
        port_key(1.85, False, note="Open"),
        port_key(2.15, False, tangent="flat", note="Strike"),
        port_key(2.3, True, note="PilotLit"),
        port_key(2.45, True, tangent="flat", note="Plea"),
        hose(2.8, -1.1, yaw=12, lean=-2, tangent="flat", note="Lower"),
        hose(3.05, -1.1, yaw=12, lean=-8, note="Ignite"),
        hose(3.3, -0.7, yaw=9, lean=-4),
        hose(3.8, 0.6, yaw=0, lean=-4),
        hose(4.25, 2.4, yaw=-9, lean=-2, note="StreamEnd"),
        hose(4.6, 1.6, yaw=-6, lean=2, tangent="flat", note="Still"),
        aim(5.0, root_of(0, -50, 0, 0, -0.08, 0.7), -20, hips=stance(0.08, 12, 0), look=(10, -30),
            tangent="flat", note="Vent"),
    ] + holster_keys(5.4, 5.8),
}
DRAWN["Pyro_FinisherImmolate"] = [(0, "sling"), (0.15, "grip"), (1.7, "port"), (2.62, "grip"), (5.4, "sling")]
WINDOWS["Pyro_FinisherImmolate"] = [
    (0.45, 1.45, "pour", (-32, -15), 40),
    (3.05, 4.25, "stream", (-32, -15), 40),
]


# The victim (5.8 s), laid on its back at Finishers.SIDE_VICTIM (identity =
# lying straight; Shoulder X+ lifts an arm toward the sky). Limp, its head
# turned toward him; it flinches and coughs as the fuel hits its face; a
# hand comes up, begging (2.4) and stays up as a shield until the fire
# (3.05): arms fly up, it thrashes, kicks, rolls its shoulders, its head
# thrown about; from 4.3 it curls up (the heat tightens the muscles: arms
# up and in, fists at the face, knees up) and goes still at 4.6 (the kill:
# the ragdoll takes it from there).
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
        key(2.85, victim(neck=(-20, 28, 0), rs=(64, 0, -10), ls=(12, 0, -4)), "flat"),
        key(3.05, victim(neck=(-6, 26, 0), rs=(56, 0, -4), ls=(12, 0, -4))),
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
-- --write; --check runs the forward-kinematics checks with his flamethrower
-- in the hands, --render draws filmstrips). Every clip starts and ends on
-- the Guard pose (the victim's on the floor): the gun is drawn off his back
-- and slung again in each one (Combat/Flamethrower). The beats must stay in
-- sync with the kit (Shared/Kits/Pyromaniac), Shared/Finishers "Immolate"
-- and Client/Combat/PyroFx:
--
{beats}
local R6Pose = require(script.Parent.R6Pose)

local clips: {{ [string]: R6Pose.Clip }} = {{
"""


def beats_comment():
    lines = []
    for name, clip in CLIPS.items():
        notes = [f"{k['note']} {num(k['time'])}" for k in clip["keys"] if k.get("note")]
        if notes:
            text = f"--   * {name} ({num(clip['length'])} s): " + ", ".join(notes) + "."
            while len(text) > 96:
                cut = text.rfind(", ", 0, 96)
                lines.append(text[:cut + 1])
                text = "--     " + text[cut + 2:]
            lines.append(text)
    return "\n".join(lines) + "\n"


def num(value):
    text = f"{value:.3f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def vec(values):
    return f"Vector3.new({num(values[0])}, {num(values[1])}, {num(values[2])})"


def luau():
    out = [HEADER.format(beats=beats_comment())]
    for name, clip in CLIPS.items():
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
                pos = value[3:] if len(value) > 3 and any(abs(v) > 1e-4 for v in value[3:]) else None
                if pos:
                    out.append(f"\t\t\t\t\t{joint} = {{ rot = {vec(rot)}, pos = {vec(pos)} }},\n")
                else:
                    out.append(f"\t\t\t\t\t{joint} = {{ rot = {vec(rot)} }},\n")
            out.append("\t\t\t\t},\n\t\t\t},\n")
        out.append("\t\t},\n\t},\n")
    out.append("}\n\nreturn clips\n")
    return "".join(out)


def port_luau():
    m = PORT
    vals = [m[0][3], m[1][3], m[2][3], m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1],
            m[2][2]]
    return "CFrame.new(" + ", ".join(f"{v:.4f}".rstrip("0").rstrip(".") if abs(v) > 1e-5 else "0" for v in vals) + ")"


def write_port():
    text = open(GUN_PATH).read()
    new = re.sub(r"local PORT = CFrame\.new\([^)]*\)", "local PORT = " + port_luau(), text)
    assert "local PORT = " in new, "Flamethrower.luau has no PORT line"
    open(GUN_PATH, "w").write(new)


# --- sampling (the same spline as R6Pose) ---------------------------------------

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


def mount_at(name, t):
    current = "sling"
    for time, mount in DRAWN.get(name, []):
        if t >= time - 1e-9:
            current = mount
    return current


def left_at(clip, t):
    """What the left hand holds at `t` (both keys around it agree), or None."""
    keys = clip["keys"]
    for i in range(len(keys) - 1):
        a, b = keys[i], keys[i + 1]
        if a["time"] <= t <= b["time"]:
            if a["left"] and a["left"] == b["left"]:
                return a["left"]
            if abs(t - a["time"]) < 1e-6 and a["left"]:
                return a["left"]
            if abs(t - b["time"]) < 1e-6 and b["left"]:
                return b["left"]
            return None
    return None


LEFT_TARGETS = {"grip": GRIP_L, "wheel": WHEEL, "valve": VALVE, "pilot": PILOT}


def rotation_angle(a, b):
    """Degrees between two rotations."""
    tr = sum(a[i][k] * b[i][k] for i in range(3) for k in range(3))
    return math.degrees(math.acos(max(-1, min(1, (tr - 1) / 2))))


def check():
    fails = []
    print("FK CHECK (60 fps). Muzzle yaw / pitch from the HRP facing; left hand to what it holds.")
    for name, clip in CLIPS.items():
        if name.endswith("Victim"):
            continue
        base = IDENTITY
        frames_n = int(round(clip["length"] * FPS))
        worst_step = (0, "", 0)
        worst_left = (0, 0, "")
        snaps = SNAPS.get(name, [])
        changes = [t for t, _ in DRAWN.get(name, [])]
        previous = None
        window_stats = {w[2]: [] for w in WINDOWS.get(name, [])}
        for f in range(frames_n + 1):
            t = f / FPS
            p = sample(clip, t)
            # joint speed
            mats = {j: angles(*p[j][:3]) for j in JOINTS}
            if previous:
                snapped = any(a - 1e-6 <= t <= b + 1e-6 for a, b in snaps)
                for j in JOINTS:
                    step = rotation_angle(previous[j], mats[j])
                    if step > worst_step[0] and not snapped:
                        worst_step = (step, j, t)
            previous = mats
            frames = frames_of(p, base)
            mount = mount_at(name, t)
            settled = all(abs(t - c) > 0.12 or t < c for c in changes)
            gun = gun_frame(frames, mount)
            held = left_at(clip, t)
            if held and mount != "sling" and settled:
                target = apply(gun, LEFT_TARGETS.get(held, GRIP_L))
                hand_a = apply(frames["Left Arm"], (0, -1, 0))
                hand_b = apply(frames["Left Arm"], (0, -0.55, 0))
                # distance from the target to the forearm's end segment
                ab = sub(hand_b, hand_a)
                u = max(0, min(1, dot(sub(target, hand_a), ab) / dot(ab, ab)))
                d = length(sub(target, add(hand_a, scale(ab, u))))
                if d > worst_left[0]:
                    worst_left = (d, t, held)
            for (a, b, label, prange, ymax) in WINDOWS.get(name, []):
                if a - 1e-6 <= t <= b + 1e-6:
                    yaw, pitch = aim_of(gun)
                    window_stats[label].append((t, yaw, pitch))
        # report
        print(f"\n{name} ({clip['length']} s)")
        step_ok = worst_step[0] <= MAX_STEP
        print(f"  joint speed: max {worst_step[0]:.1f} deg/frame ({worst_step[1]} at {worst_step[2]:.3f})"
              + ("" if step_ok else "  FAIL") + (f"  (snaps allowed: {snaps})" if snaps else ""))
        if not step_ok:
            fails.append(f"{name}: joint speed {worst_step[0]:.1f}")
        left_ok = worst_left[0] <= 0.35
        print(f"  left hand: worst {worst_left[0]:.2f} stud from the {worst_left[2] or '-'} at {worst_left[1]:.3f}"
              + ("" if left_ok else "  FAIL"))
        if not left_ok:
            fails.append(f"{name}: left hand {worst_left[0]:.2f}")
        for (a, b, label, prange, ymax) in WINDOWS.get(name, []):
            rows = window_stats[label]
            yaws = [r[1] for r in rows]
            pitches = [r[2] for r in rows]
            ok = (min(pitches) >= prange[0] - 1e-6 and max(pitches) <= prange[1] + 1e-6
                  and max(abs(y) for y in yaws) <= ymax + 1e-6)
            print(f"  {label} {a:.2f}-{b:.2f}: pitch {min(pitches):.1f}..{max(pitches):.1f} (want {prange[0]}..{prange[1]}),"
                  f" yaw {min(yaws):.1f}..{max(yaws):.1f} (|yaw| <= {ymax})" + ("" if ok else "  FAIL"))
            if not ok:
                fails.append(f"{name}: {label} aim")
        for t in RELEASES.get(name, []):
            frames = frames_of(sample(clip, t), base)
            gun = gun_frame(frames, "grip")
            m = apply(gun, MUZZLE)
            yaw, pitch = aim_of(gun)
            print(f"  release {t:.2f}: muzzle in root space ({m[0]:.2f}, {m[1]:.2f}, {m[2]:.2f}), "
                  f"yaw {yaw:.1f} pitch {pitch:.1f}")
        # the right hand at the slung grip on the Grip / Sling beats
        for k in clip["keys"]:
            if k.get("note") in ("Grip", "Sling"):
                frames = frames_of(sample(clip, k["time"]), base)
                hand = apply(inverse(frames["Torso"]), apply(frames["Right Arm"], HAND))
                d = length(sub(hand, SLUNG_GRIP))
                print(f"  {k['note']} {k['time']:.2f}: right hand {d:.2f} stud from the slung grip")
        if name == "Pyro_FinisherImmolate":
            for t in (0.4, 0.9, 1.45, 3.05, 3.8, 4.25):
                frames = frames_of(sample(clip, t), base)
                gun = gun_frame(frames, "grip")
                m = apply(gun, MUZZLE)
                print(f"  {t:.2f}: muzzle ({m[0]:.2f}, {m[1]:.2f}, {m[2]:.2f}), {m[1] - CHEST_Y:.2f} above the chest")
    print()
    if fails:
        print("FAILED:", "; ".join(fails))
        return False
    print("ALL CLIPS PASS")
    return True


# --- preview -------------------------------------------------------------------

SIZES = {"Torso": (2, 2, 1), "Head": (1.2, 1, 1), "Right Arm": (1, 2, 1), "Left Arm": (1, 2, 1),
         "Right Leg": (1, 2, 1), "Left Leg": (1, 2, 1)}
COLORS = {"Torso": (90, 80, 70), "Head": (220, 180, 150), "Right Arm": (200, 90, 60),
          "Left Arm": (70, 120, 200), "Right Leg": (60, 60, 70), "Left Leg": (90, 90, 110)}
GUN_LINE = [STOCK, (0, -0.25, 1.45), GRIP_R, (0, 0, 0.9), (0, 0, -1.3), MUZZLE]


def box_faces(m, size):
    sx, sy, sz = (s / 2 for s in size)
    corners = [apply(m, (x * sx, y * sy, z * sz)) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    faces = [(0, 1, 3, 2), (4, 5, 7, 6), (0, 1, 5, 4), (2, 3, 7, 6), (0, 2, 6, 4), (1, 3, 7, 5)]
    return [[corners[i] for i in f] for f in faces]


def firing(name, t):
    return any(a <= t <= b for a, b, *_ in WINDOWS.get(name, []))


def render(name, path, frames=12):
    from PIL import Image, ImageDraw

    clip = CLIPS[name]
    victim_clip = CLIPS["Pyro_FinisherImmolateVictim"] if name == "Pyro_FinisherImmolate" else None
    views = {
        "front": lambda p: (-p[0], -p[1], p[2]),  # camera at -Z looking +Z (his right on our left)
        "side": lambda p: (-p[2], -p[1], -p[0]),  # from his right
        "top": lambda p: (p[0], p[2], -p[1]),
    }
    cell = 170
    scale_px = 15
    img = Image.new("RGB", (cell * frames, cell * len(views)), (235, 232, 225))
    draw = ImageDraw.Draw(img)
    for vi, (vname, proj) in enumerate(views.items()):
        for fi in range(frames):
            t = clip["length"] * fi / (frames - 1)
            polys = []
            sets = [(clip, IDENTITY)]
            if victim_clip:
                sets.append((victim_clip, SIDE_VICTIM))
            gun_pts = None
            for c, b in sets:
                fr = frames_of(sample(c, t), b)
                for part, size in SIZES.items():
                    for face in box_faces(fr[part], size):
                        pts = [proj(q) for q in face]
                        depth = sum(q[2] for q in pts) / 4
                        polys.append((depth, COLORS[part], pts))
                if c is clip:
                    gun = gun_frame(fr, mount_at(name, t))
                    gun_pts = gun
            # the gun: a thick dark stick, the bottle, the muzzle ray
            line = [proj(apply(gun_pts, q)) for q in GUN_LINE]
            bottle = proj(apply(gun_pts, BOTTLE))
            depth = sum(q[2] for q in line) / len(line)
            polys.append((depth - 0.01, "gun", (line, bottle)))
            polys.sort(key=lambda x: -x[0])
            ox, oy = fi * cell + cell / 2, vi * cell + cell / 2 + (8 if vname != "top" else 0)
            for _, color, pts in polys:
                if color == "gun":
                    line, bottle = pts
                    xy = [(ox + q[0] * scale_px, oy + q[1] * scale_px) for q in line]
                    draw.line(xy, fill=(25, 22, 20), width=5)
                    draw.line(xy[-2:], fill=(70, 62, 66), width=6)
                    bx, by = ox + bottle[0] * scale_px, oy + bottle[1] * scale_px
                    draw.ellipse([bx - 4, by - 4, bx + 4, by + 4], fill=(78, 84, 52), outline=(20, 20, 20))
                    if firing(name, t):
                        m = apply(gun_pts, MUZZLE)
                        tip = apply(gun_pts, add(MUZZLE, (0, 0, -3)))
                        a, b2 = proj(m), proj(tip)
                        draw.line([(ox + a[0] * scale_px, oy + a[1] * scale_px),
                                   (ox + b2[0] * scale_px, oy + b2[1] * scale_px)], fill=(255, 120, 20), width=3)
                else:
                    draw.polygon([(ox + q[0] * scale_px, oy + q[1] * scale_px) for q in pts], fill=color,
                                 outline=(30, 30, 30))
            if vname != "top":
                fy = oy + 3 * scale_px
                draw.line([(fi * cell, fy), (fi * cell + cell, fy)], fill=(120, 120, 120))
            draw.text((fi * cell + 3, vi * cell + 2), f"{vname} {t:.2f}", fill=(0, 0, 0))
    img.save(path)


if __name__ == "__main__":
    # (the fitted torso yaw / twist / lean per key: a cache, recomputed when a key changes)
    json.dump({k: FIT_CACHE[k] for k in sorted(FIT_USED)}, open(FIT_PATH, "w"), indent=0)
    if "--check" in sys.argv:
        if not check():
            sys.exit(1)
    if "--write" in sys.argv:
        open(CLIPS_PATH, "w").write(luau())
        write_port()
    if "--render" in sys.argv:
        out = sys.argv[sys.argv.index("--render") + 1]
        os.makedirs(out, exist_ok=True)
        for clip_name in CLIPS:
            if clip_name.endswith("Victim"):
                continue
            render(clip_name, f"{out}/{clip_name}.png", 16 if clip_name == "Pyro_FinisherImmolate" else 12)
