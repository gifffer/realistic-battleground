"""
The burst head of the bat finisher, built from real anatomy (Z-Anatomy,
CC BY-SA 4.0, via extract_anatomy.py -> anatomy/head.npz) and added to
WoundKit.fbx by build_wound_kit.py. The game (src/client/Combat/HeadBlast)
puts each piece where it was in the head, then lets it fly.

Pieces ("Gore_<Piece>_<Layer>", one mesh per layer, coloured by the game):
  Skull<i>   a piece of the head: the scalp (Skin, the classic head's exact
             surface, a little thick) and under it the real skull bone of
             that spot (Bone), broken along the same lines
  Brain<i>   a lump of the real brain (its folds), broken up
  Eye<i>     a real eyeball (Sclera, Iris) and its nerve (Flesh)
  Tooth<i>   real upper teeth
  Jaw        what stays on the body: the lower jaw (Bone) with its teeth
             (Tooth), the skin of the chin and cheeks torn along the top
             (Skin), the wound inside (Flesh), the top of the spine (Bone:
             atlas and axis)
  Liver      the real liver (Liver) and its gallbladder (Gallbladder), for
             the Boxer's finisher (torn out by hand); its middle the origin
  ArmEnd     the Bouncer's finisher: the top of the right arm torn off at the
             shoulder (in the R6 arm's space: 1 x 2 x 1, its top at Y = 1):
             the raw end (Flesh, FleshDark), torn skin hanging over the edges
             (Skin), the real humerus (Z-Anatomy) with its head sticking out
             (Bone), torn tendons (Tendon)
  Humerus    the same upper arm bone, whole: the real right humerus of
             Z-Anatomy (anatomy/arm.npz), pulled out of the torn arm to be
             thrown (Shared/Weapons "Bone"): its own space, along Y, the
             head at the top, scraps of flesh still on it (Bone, Flesh,
             Tendon)
  HumerusA / HumerusB   the same bone snapped in two (head half / elbow
             half), same space: when it hits something it breaks there
  Shoulder   ...and what it leaves on the torso (R6 torso space, its right
             side at X = 1): the open socket (Flesh, FleshDark), the real
             outer shoulder blade (its socket, the acromion) and the end of
             the collarbone (Bone, Z-Anatomy), torn skin around it (Skin),
             shreds of muscle hanging (Flesh)
  Splat<i> / Streak<i> / Pool<i>   blood on the floor (Blood): flat blots
             with droplets, stretched drops, a pool; 1 stud across, laid in
             X-Z (the game sizes and turns them)
  Waist      the Bull's finisher (the body torn in two at the hips): the torn
             bottom of the R6 torso, in torso space (2 x 2 x 1, its bottom
             face at Y = -1), a cap over the whole bottom face: torn skin
             hanging round the edge (Skin), the fat under it (Fat), the real
             abdominal and back muscles torn each at its own height
             (Muscle, MuscleDark), the real lumbar spine torn through a disc
             (Bone, Cartilage) with nerves hanging from it (Tendon), loops of
             the real small intestine (jejunum) bulging and hanging out
             (Gut), the colon (GutDark), the raw inside (FleshDark), blood
             (Blood). Z-Anatomy, torso.npz.
  Hips       ...and what goes off with the legs: the top of the pelvis, in
             torso space too, placed as if the legs were still on (their
             tops at Y = -1, at X = +-0.5): the real hip bones, sacrum and
             last lumbar vertebra (Bone, Cartilage), the bottom of the same
             muscles torn short (Muscle, MuscleDark), the raw flesh on the
             legs' tops (FleshDark), fat and torn skin pointing up (Fat,
             Skin), intestine spilling over it (Gut, GutDark), blood (Blood)
  Gut1..3    a short piece of small intestine (Gut, ~0.5 x 0.16 studs,
             lumpy, a little bent) with its torn mesentery along it
             (GutDark): its long axis along Y, centred - links of a chain
             lying on the floor between the two halves
  GutPile    a heap of loops of the real jejunum (Gut) with bits of its
             mesentery (GutDark), ~0.9 x 0.4 x 0.7 studs, its bottom at
             Y = 0 (it lies on the floor there), centred in X and Z

  The heavy hits (a heavy blow at the end of a big combo: Client/Combat/
  HeavyGore), Z-Anatomy from limbs.npz (extract_limbs.py):
  LegEnd     the top of the right leg torn off at the hip (R6 leg space, its
             top at Y = 1): the real thigh muscles torn each at its own
             height (Muscle, MuscleDark), the real femur's head out of it
             (Bone), its torn ligament, the real femoral artery and vein and
             the sciatic nerve torn and hanging (Artery, Vein, Nerve), the
             fat under the skin, the skin torn round the edge, blood
  Hip        ...and what stays on the torso (torso space, over X = 0..1 of
             its bottom face): the real hip bone round its socket (Bone),
             the muscles round the joint torn short and hanging (Muscle,
             MuscleDark), the raw inside, fat, skin, blood
  ArmEndL / ShoulderL   the left arm torn off: the Bouncer's ArmEnd /
             Shoulder (the real humerus, shoulder blade, muscles) mirrored,
             their skin torn ragged round the wound (no flaps)
  LegEndL / HipL   the left leg: LegEnd / Hip mirrored
  ArmEndR / ShoulderR   the right arm the same way (ArmEndL's, not mirrored)
  (The open fractures are wound inserts: build_wound_kit.py "Break",
  fracture.py.)

Head space (studs): X right of the character, Y up, Z to the back, origin =
the head's centre. Piece n sits in the kit with its head space moved to
SLOTS[n] (written in src/shared/GoreShapes.luau).
"""

import math
import os
import random

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ANATOMY = os.path.join(HERE, "anatomy", "head.npz")
ARM_ANATOMY = os.path.join(HERE, "anatomy", "arm.npz")  # extract_arm.py
TORSO_ANATOMY = os.path.join(HERE, "anatomy", "torso.npz")  # extract_anatomy.py --torso
GORE_ORIGIN = Vector((0.0, 0.0, -14.0))  # kit space: away from the inserts / frames
SLOT_STEP = 3.0
CUT_Y = -0.27  # the head bursts above this; below stays (the jaw)
SCALP = 0.05  # thickness of the scalp
SKULL_PIECES = 13
BRAIN_PIECES = 7
FLYING_TEETH = 8

COLORS = {
    "Skin": (0.80, 0.62, 0.50),
    "Bone": (0.90, 0.86, 0.76),
    "Brain": (0.80, 0.55, 0.53),
    "Sclera": (0.93, 0.92, 0.88),
    "Iris": (0.15, 0.12, 0.10),
    "Tooth": (0.95, 0.93, 0.85),
    "Flesh": (0.55, 0.06, 0.06),
    "Blood": (0.25, 0.0, 0.0),
    "Liver": (0.36, 0.09, 0.08),
    "Gallbladder": (0.27, 0.36, 0.14),
    "FleshDark": (0.36, 0.04, 0.05),
    "Muscle": (0.55, 0.1, 0.1),
    "MuscleDark": (0.42, 0.07, 0.08),
    "Fat": (0.85, 0.72, 0.42),
    "Tendon": (0.85, 0.80, 0.72),
    "Gut": (0.86, 0.56, 0.55),  # the small intestine: pink, wet (glossy)
    "GutDark": (0.58, 0.30, 0.30),  # its mesentery, the colon: darker
    "Heart": (0.42, 0.05, 0.06),
    "HeartDark": (0.20, 0.02, 0.03),
    "Lung": (0.72, 0.52, 0.54),
    "Cartilage": (0.80, 0.85, 0.88),
    "Artery": (0.62, 0.1, 0.12),
    "Vein": (0.24, 0.12, 0.24),
    "Nerve": (0.92, 0.86, 0.66),
}


def load_anatomy(path=ANATOMY):
    data = np.load(path)
    groups = {}
    for key in data.files:
        group, index, kind = key.split("__")
        groups.setdefault(group, {}).setdefault(int(index), {})[kind] = data[key]
    return {g: [(d["v"], d["f"]) for _i, d in sorted(items.items())] for g, items in groups.items()}


def bm_of(v, f):
    bm = bmesh.new()
    verts = [bm.verts.new(tuple(map(float, p))) for p in v]
    for tri in f:
        try:
            bm.faces.new([verts[int(i)] for i in tri])
        except ValueError:
            pass  # (a duplicate face)
    # Faces outward on every closed part (Z-Anatomy's left-side copies are
    # mirrored: inside out as they come, and Roblox shows one side only).
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    return bm


def bm_join(parts):
    bm = bmesh.new()
    for part in parts:
        mesh = bpy.data.meshes.new("tmp")
        part.to_mesh(mesh)
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    return bm


def bm_copy(bm):
    out = bm.copy()
    return out


def cut(bm, planes, fill=True):
    """Keeps the side of every plane (point, normal) the normal points away from."""
    for co, no in planes:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=co, plane_no=no, clear_outer=True)
    if fill:
        boundary = [e for e in bm.edges if e.is_boundary]
        if boundary:
            filled = bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
            bmesh.ops.triangulate(bm, faces=filled["faces"])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])  # (the fills: outward too)
    bm.normal_update()
    return bm


def cell_planes(seeds, i):
    planes = []
    for j, other in enumerate(seeds):
        if j != i:
            planes.append(((seeds[i] + other) / 2, (other - seeds[i]).normalized()))
    return planes


def head_radius(y):
    """The classic head (Roblox head.mesh): radius at height y."""
    a = abs(y)
    if a <= 0.3:
        return 0.6
    return 0.3 + math.sqrt(max(0.0, 0.09 - (a - 0.3) ** 2))


def head_surface(rings=40, segments=64):
    bm = bmesh.new()
    rows = []
    for r in range(1, rings):
        y = 0.6 - 1.2 * r / rings
        rad = head_radius(y)
        rows.append([bm.verts.new((rad * math.sin(2 * math.pi * s / segments), y,
                                   rad * math.cos(2 * math.pi * s / segments))) for s in range(segments)])
    top = bm.verts.new((0, 0.6, 0))
    bottom = bm.verts.new((0, -0.6, 0))
    for s in range(segments):
        t = (s + 1) % segments
        bm.faces.new((top, rows[0][t], rows[0][s]))
        bm.faces.new((bottom, rows[-1][s], rows[-1][t]))
        for r in range(len(rows) - 1):
            bm.faces.new((rows[r][s], rows[r][t], rows[r + 1][t], rows[r + 1][s]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def solidify(bm, thickness):
    """An open patch of skin -> a closed plate `thickness` thick (inward)."""
    mesh = bpy.data.meshes.new("tmp")
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new("tmp", mesh)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("s", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = -1
    mod.use_rim = True
    mod.use_even_offset = False  # (True: spikes at the slivers the cuts leave)
    mod.use_quality_normals = True
    evaluated = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    out = bmesh.new()
    out.from_mesh(evaluated)
    bmesh.ops.triangulate(out, faces=out.faces[:])
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(mesh)
    return out


def rough_rim(bm, rng, amount, where):
    """Jags the open edge of a patch (a tear, not a clean cut)."""
    rim = {v for e in bm.edges if e.is_boundary for v in e.verts}
    for v in rim:
        if where(v.co):
            v.co.y += rng.uniform(-amount, amount * 0.4)
    return bm


def squeeze(v, axis, factor):
    """Squeezes a mesh around its centre (the anatomy is stretched in X to fill
    the head: round things - eyes, teeth - are put back round)."""
    v = v.copy()
    c = v.mean(0)
    v[:, axis] = c[axis] + (v[:, axis] - c[axis]) * factor
    return v


def fibonacci(n, rng, jitter):
    pts = []
    for i in range(n):
        y = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(1 - y * y)
        a = i * math.pi * (3 - math.sqrt(5)) + rng.uniform(-jitter, jitter)
        pts.append(Vector((r * math.cos(a), y, r * math.sin(a))))
    return pts


def blot(rng, radius, lobes, droplets, stretch=1.0, tail=0.0, ring=48):
    """A flat blot of blood in X-Z (thin slab), with droplets around it."""
    bm = bmesh.new()

    def disc(cx, cz, r, wobble, n, sx=1.0):
        phase = [rng.uniform(0, 6.3) for _ in range(4)]
        amps = [rng.uniform(0, wobble) for _ in range(4)]
        top, bot = [], []
        for k in range(n):
            a = 2 * math.pi * k / n
            rr = r * (1 + sum(amps[m] * math.sin((m + 2) * a + phase[m]) for m in range(4)))
            x, z = cx + rr * math.cos(a) * sx, cz + rr * math.sin(a)
            top.append(bm.verts.new((x, 0.006, z)))
            bot.append(bm.verts.new((x, 0.0, z)))
        bm.faces.new(top)
        bm.faces.new(list(reversed(bot)))
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((bot[k], bot[j], top[j], top[k]))

    disc(0, 0, radius, 0.12 * lobes, ring, stretch)
    for _ in range(droplets):
        a = rng.uniform(0, 2 * math.pi)
        d = radius * rng.uniform(1.15, 2.0)
        disc(d * math.cos(a) * stretch, d * math.sin(a), radius * rng.uniform(0.04, 0.12), 0.05, 10)
    if tail > 0:  # a line of drops trailing behind (a stretched drop)
        for k in range(1, 6):
            disc(-radius * stretch - tail * k / 5, rng.uniform(-0.03, 0.03), radius * 0.16 * (1 - k / 7), 0.05, 10)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])  # (each slab: outward)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.normal_update()
    return bm


def lumpy(bm, rng, amount, scale=6.0):
    """Roughens a surface (raw flesh, a broken end): each vertex pushed out
    or in along its normal by a smooth random amount."""
    phases = [rng.uniform(0, 6.3) for _ in range(6)]
    bm.normal_update()
    for v in bm.verts:
        p = v.co
        n = (math.sin(p.x * scale + phases[0]) * math.sin(p.y * scale * 1.3 + phases[1])
             + 0.6 * math.sin(p.z * scale * 1.7 + phases[2]) * math.sin(p.x * scale * 2.1 + phases[3])
             + 0.3 * math.sin((p.x + p.y + p.z) * scale * 3.1 + phases[4]))
        v.co = p + v.normal * amount * n / 1.9
    bm.normal_update()
    return bm


def blob(rng, center, radii, segments=12, rings=8, rough=0.0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2])) + Vector(center)
    if rough:
        lumpy(bm, rng, rough, 9.0)
    return bm


def rod(start, end, r1, r2=None, segments=8):
    """A cylinder from `start` to `end` (a bone shaft, a tendon)."""
    start, end = Vector(start), Vector(end)
    axis = end - start
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=r1, radius2=r2 if r2 is not None else r1,
                          depth=axis.length)
    # (made along Z, centred): turn it onto the axis, move it to the middle
    rot = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=(start + end) / 2, verts=bm.verts)
    return bm


def flap(rng, base, out, down, width, length, curl):
    """A torn flap of skin: a thin strip from `base`, going `out` then bending
    `down` (curling), ragged at its end."""
    base, out, down = Vector(base), Vector(out).normalized(), Vector(down).normalized()
    side = out.cross(down).normalized()
    bm = bmesh.new()
    rows = []
    steps = 5
    for i in range(steps + 1):
        t = i / steps
        bend = (out * math.cos(curl * t) + down * math.sin(curl * t)) * length * t
        w = width * (1 - 0.5 * t) * (1 + rng.uniform(-0.15, 0.15))
        c = base + bend
        rows.append([bm.verts.new(c - side * w / 2), bm.verts.new(c + side * w / 2)])
    for i in range(steps):
        bm.faces.new((rows[i][0], rows[i][1], rows[i + 1][1], rows[i + 1][0]))
    return solidify(bm, 0.025)


def load_arm_lists():
    """The muscles of arm.npz (lists of bmeshes)."""
    data = np.load(ARM_ANATOMY)
    out = {"armmuscle": [], "shouldermuscle": []}
    for key in sorted(data.files):
        group, index, kind = key.split("__")
        if group in out and kind == "v":
            out[group].append(bm_of(data[key], data[f"{group}__{index}__f"]))
    return out


def tear(bm, rng, near_y, amount):
    """Jags a cut end: the vertices near the cut pushed up / down (torn fibres,
    not a clean slice)."""
    phase = [rng.uniform(0, 6.3) for _ in range(3)]
    for v in bm.verts:
        if abs(v.co.y - near_y) < 0.06:
            # (smooth tufts and dips, a little grain on them)
            wave = math.sin(v.co.x * 23 + phase[0]) * math.sin(v.co.z * 19 + phase[1])
            v.co.y += amount * (0.8 * wave + 0.5 * math.sin((v.co.x + v.co.z) * 41 + phase[2])) + rng.uniform(-0.2, 0.2) * amount
    bm.normal_update()
    return bm


def torn_arm(rng, ragged=False):
    """The Bouncer's finisher: (the arm's torn end, what stays on the torso),
    each {layer: bmesh}. R6 part spaces (studs): X right, Y up, Z back.

    The arm's end shows the real cut of its muscles (Z-Anatomy: deltoid,
    biceps, triceps, brachialis, coracobrachialis), each torn at its own
    height, the real humerus' head out of the middle, the fat under the skin
    in a yellow band round the edge, the skin torn and hanging. The shoulder
    keeps the real rotator cuff and pectoralis major torn short round the
    empty socket of the real shoulder blade."""
    arm = load_arm()
    lists = load_arm_lists()

    # ---- the arm's end: its top face (1 x 1 at Y = 1) torn open
    half = 0.47
    muscles, dark_muscles = [], []
    for index, muscle in enumerate(lists["armmuscle"]):
        for v in muscle.verts:  # (a little wider still: they fill the block)
            v.co.x *= 1.15
            v.co.z *= 1.15
        # each torn at its own height, out of the stump (they bulge out of it)
        y = 1.06 + rng.uniform(0.0, 0.16)
        # (cut() keeps the side its normal points away from)
        cut(muscle, [
            ((0, y, 0), (0, 1, 0)), ((0, 0.8, 0), (0, -1, 0)),
            ((half, 0, 0), (1, 0, 0)), ((-half, 0, 0), (-1, 0, 0)),
            ((0, 0, half), (0, 0, 1)), ((0, 0, -half), (0, 0, -1)),
        ], fill=True)
        if len(muscle.faces):
            tear(muscle, rng, y, 0.045)
            (muscles if index % 2 == 0 else dark_muscles).append(muscle)
    bone = arm["armhead"]
    cut(bone, [((0, 0.55, 0), (0, -1, 0))], fill=True)
    # under it all (between the muscles): dark, wet
    floor = bmesh.new()
    bmesh.ops.create_cube(floor, size=1.0)
    for v in floor.verts:
        v.co = Vector((v.co.x * 0.96, 1.01 + v.co.y * 0.03, v.co.z * 0.96))
    # the fat under the skin: a band round the edge, ragged on top
    fat = []
    for side in range(4):
        wall = bmesh.new()
        bmesh.ops.create_cube(wall, size=1.0)
        bmesh.ops.subdivide_edges(wall, edges=wall.edges[:], cuts=6, use_grid_fill=True)
        for v in wall.verts:
            x, y, z = v.co.x, v.co.y, v.co.z
            local = Vector((x * 0.98, 1.0 + y * 0.1, 0.475 + z * 0.05))
            ang = side * math.pi / 2
            v.co = Vector((local.x * math.cos(ang) + local.z * math.sin(ang), local.y,
                           -local.x * math.sin(ang) + local.z * math.cos(ang)))
        tear(wall, rng, 1.05, 0.03)
        fat.append(wall)
    tendons = bm_join_all([
        rod((rng.uniform(-0.25, 0.25), 1.0, rng.uniform(-0.25, 0.25)),
            (rng.uniform(-0.4, 0.4), 1.0 + rng.uniform(0.12, 0.3), rng.uniform(-0.4, 0.4)), 0.022, 0.01, 6)
        for _ in range(4)
    ])
    skin = []
    if ragged:  # (the heavy hits': the skin torn round the edge, ragged)
        skin.append(skirt(rng, 0.995, 1, 0.002, 0.1, 0.9, 0.02, count=40, spikes=6, hx=0.5, hz=0.5))
        fat.append(skirt(rng, 0.97, 1, 0.022, 0.07, 0.2, 0.035, count=40, spikes=4, hx=0.5, hz=0.5))
    for k in range(0 if ragged else 10):  # skin torn around the top edge, hanging over the sides
        a = 2 * math.pi * k / 10 + rng.uniform(-0.2, 0.2)
        out = Vector((math.cos(a), 0, math.sin(a)))
        edge = 0.5 / max(abs(out.x), abs(out.z))  # (on the square's edge)
        base = Vector((out.x * edge * 0.99, 1.0, out.z * edge * 0.99))
        skin.append(flap(rng, base, out, (0, -1, 0), rng.uniform(0.18, 0.32), rng.uniform(0.1, 0.22), rng.uniform(1.2, 1.9)))
    arm_end = {
        "Muscle": bm_join_all(muscles),
        "MuscleDark": bm_join_all(dark_muscles),
        "FleshDark": floor,
        "Fat": bm_join_all(fat),
        "Bone": bone,
        "Tendon": tendons if not ragged else None,  # (the heavy hits': no sticks)
        "Skin": bm_join_all(skin),
    }

    # ---- the torso's right side: the socket left open
    sx = 1.0
    glenoid = bm_join_all([arm["scapula"], arm["clavicle"]])
    # The socket (glenoid: the outermost bone at its height) moved to the
    # middle of the wound, just out of the side: it shows, empty, where the
    # head of the arm bone was. Its muscles move with it.
    band = [v.co for v in glenoid.verts if 0.5 < v.co.y < 0.75]
    edge = max(c.x for c in band)
    cup = [c for c in band if c.x > edge - 0.05]
    centre = sum(cup, Vector()) / len(cup)
    shift = Vector((sx + 0.06, 0.5, 0.0)) - centre
    bmesh.ops.translate(glenoid, vec=shift, verts=glenoid.verts)
    cuff, cuff_dark = [], []
    for index, muscle in enumerate(lists["shouldermuscle"]):
        bmesh.ops.translate(muscle, vec=shift, verts=muscle.verts)
        # torn short just out of the side (each at its own depth)
        x = sx + rng.uniform(0.04, 0.14)
        cut(muscle, [((x, 0, 0), (1, 0, 0)), ((0, -0.05, 0), (0, -1, 0)), ((0, 1.02, 0), (0, 1, 0)),
                     ((0, 0, 0.5), (0, 0, 1)), ((0, 0, -0.5), (0, 0, -1))], fill=True)
        if len(muscle.faces):
            for v in muscle.verts:  # torn fibres at the end
                if abs(v.co.x - x) < 0.06:
                    v.co.x += rng.uniform(-0.04, 0.06)
            (cuff if index % 2 == 0 else cuff_dark).append(muscle)
    deep = blob(rng, (sx + 0.01, 0.5, 0.0), (0.02, 0.4, 0.38), 14, 8, 0.012)
    # the fat under the skin: a torn yellow band just inside the skin's edge
    angles = [2 * math.pi * k / 11 + rng.uniform(-0.2, 0.2) for k in range(11)]
    fat_ring = bm_join_all([
        flap(rng, Vector((sx + 0.02, 0.5 + math.sin(a) * rng.uniform(0.38, 0.44), math.cos(a) * rng.uniform(0.35, 0.41))),
             Vector((0.0, math.sin(a), math.cos(a))), (1, 0, 0),
             rng.uniform(0.12, 0.3), rng.uniform(0.03, 0.08), rng.uniform(0.1, 0.7))
        for a in angles if rng.random() < 0.8
    ]) if not ragged else None
    hanging = bm_join_all([
        rod((sx + 0.06, rng.uniform(0.15, 0.45), rng.uniform(-0.3, 0.3)),
            (sx + rng.uniform(0.08, 0.16), rng.uniform(-0.2, 0.05), rng.uniform(-0.35, 0.35)),
            rng.uniform(0.02, 0.035), 0.01, 6)
        for _ in range(3)
    ])
    # (the heavy hits': the skin torn round it in a ragged line, not a circle)
    phase = rng.uniform(0, 6.3)

    def torn(a):
        return 1 + 0.07 * math.sin(3 * a + phase) + 0.04 * math.sin(7 * a + 2 * phase)

    rim = [] if not ragged else [ragged_ring(
        rng, [(Vector((sx + 0.003, 0.5 + math.sin(a) * 0.47 * torn(a), math.cos(a) * 0.45 * torn(a))),
               Vector((0.0, math.sin(a), math.cos(a)))) for a in (2 * math.pi * k / 44 for k in range(44))],
        (1, 0, 0), 0.1, 0.9, 0.02, 6)]
    if ragged:
        fat_ring = ragged_ring(
            rng, [(Vector((sx + 0.005, 0.5 + math.sin(a) * 0.42 * torn(a), math.cos(a) * 0.4 * torn(a))),
                   Vector((0.0, math.sin(a), math.cos(a)))) for a in (2 * math.pi * k / 40 for k in range(40))],
            (1, 0, 0), 0.06, 0.2, 0.035, 4)
    for k in range(0 if ragged else 12):  # torn skin around the socket, curling out
        a = 2 * math.pi * k / 12 + rng.uniform(-0.15, 0.15)
        base = Vector((sx + 0.01, 0.5 + math.sin(a) * 0.48, math.cos(a) * 0.45))
        out = Vector((0.0, math.sin(a), math.cos(a)))
        rim.append(flap(rng, base, out, (1, 0, 0), rng.uniform(0.14, 0.24), rng.uniform(0.08, 0.16), rng.uniform(0.6, 1.2)))
    hanging.free()  # (no sticks hanging out: the torn cuff is enough)
    shoulder = {
        "Muscle": bm_join_all(cuff),
        "MuscleDark": bm_join_all(cuff_dark),
        "FleshDark": deep,
        "Fat": fat_ring,
        "Bone": glenoid,
        "Skin": bm_join_all(rim),
    }
    return arm_end, shoulder


def load_arm():
    data = np.load(ARM_ANATOMY)
    return {g: bm_of(data[f"{g}__0__v"], data[f"{g}__0__f"]) for g in ("humerus", "armhead", "scapula", "clavicle")}


def humerus(rng):
    """The whole right humerus (Z-Anatomy), 1.7 studs along Y, the head up;
    torn flesh and tendons still on its head."""
    bone = load_arm()["humerus"]
    flesh = bm_join_all([
        blob(rng, (rng.uniform(-0.15, 0.05), 0.62 + rng.uniform(-0.12, 0.08), rng.uniform(-0.1, 0.1)),
             (rng.uniform(0.04, 0.08), rng.uniform(0.04, 0.09), rng.uniform(0.04, 0.08)), 8, 6, 0.01)
        for _ in range(6)
    ])
    tendons = bm_join_all([
        rod((rng.uniform(-0.1, 0.05), 0.6, rng.uniform(-0.08, 0.08)),
            (rng.uniform(-0.25, 0.2), 0.6 + rng.uniform(-0.25, 0.05), rng.uniform(-0.2, 0.2)), 0.02, 0.01, 6)
        for _ in range(3)
    ])
    return {"Bone": bone, "Flesh": flesh, "Tendon": tendons}


def snapped(bone, rng):
    """The bone broken in two a little below its middle: a jagged break."""
    halves = []
    for side in (1, -1):
        part = bm_copy(bone)
        y = -0.12
        # a slanted, toothed break: two planes
        cut(part, [((0, y, 0), (0.25 * side, -1 * side, 0.1 * side))], fill=True)
        rough_rim(part, rng, 0.06, lambda co: abs(co.y - y) < 0.2)
        halves.append(part)
    return halves[0], halves[1]


def bm_join_all(parts):
    out = bmesh.new()
    for part in parts:
        mesh = bpy.data.meshes.new("tmp")
        part.to_mesh(mesh)
        out.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    out.normal_update()
    return out


def tris_of(bm):
    return sum(len(f.verts) - 2 for f in bm.faces)


def decimate(bm, tris):
    """Fewer triangles (about `tris`), the shape kept."""
    total = tris_of(bm)
    if total <= tris:
        return bm
    mesh = bpy.data.meshes.new("tmp")
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new("tmp", mesh)
    bpy.context.scene.collection.objects.link(ob)
    ob.modifiers.new("t", "TRIANGULATE")
    mod = ob.modifiers.new("d", "DECIMATE")
    mod.ratio = tris / total
    evaluated = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    out = bmesh.new()
    out.from_mesh(evaluated)
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(mesh)
    out.normal_update()
    return out


def placed(v, scale=(1, 1, 1), shift=(0, 0, 0)):
    """Torso.npz vertices scaled about the torso's centre, then moved."""
    return v * np.array(scale, dtype=np.float32) + np.array(shift, dtype=np.float32)


# The abdomen is narrower than the blocky R6 torso: widened across to fill it.
WIDEN = (1.16, 1.0, 1.0)
TEAR_Y = -1.0  # the torso's bottom face / the legs' tops: where the body tears
HIDDEN_ABOVE = TEAR_Y + 0.03  # (Waist: above its raw floor, inside the torso: not kept)
HIDDEN_BELOW = TEAR_Y - 0.04  # (Hips: under its raw floor, inside the legs)


def perimeter(s, inset=0.0, hx=1.0, hz=0.5):
    """The point at `s` (0..1, by length) round the edge of the torso's
    bottom face (2 x 1, `inset` inside it), and the way out there (the
    corners rounded)."""
    hx, hz = hx - inset, hz - inset
    total = 4 * hx + 4 * hz
    d = (s % 1.0) * total
    # front (-Z) left to right, right side, back right to left, left side
    for length, start, step, normal in (
        (2 * hx, Vector((-hx, 0, -hz)), Vector((1, 0, 0)), Vector((0, 0, -1))),
        (2 * hz, Vector((hx, 0, -hz)), Vector((0, 0, 1)), Vector((1, 0, 0))),
        (2 * hx, Vector((hx, 0, hz)), Vector((-1, 0, 0)), Vector((0, 0, 1))),
        (2 * hz, Vector((-hx, 0, hz)), Vector((0, 0, -1)), Vector((-1, 0, 0))),
    ):
        if d <= length:
            point = start + step * d
            # (near a corner: the way out turns, half and half at the corner)
            near = min(d, length - d)
            if near < 0.08:
                other = normal.cross(Vector((0, 1, 0))) * (1 if d < length / 2 else -1)
                normal = normal.lerp(other, 0.5 * (1 - near / 0.08)).normalized()
            return point, normal
        d -= length
    return Vector((-hx, 0, -hz)), Vector((0, 0, -1))


def skirt(rng, y, up, inset, length, flare, thickness, count=56, spikes=9, hx=1.0, hz=0.5, cx=0.0):
    """A torn band round the edge of the torso's bottom face (the skin, the
    fat under it): from y, going down (up = -1) or up (up = 1), its end
    ragged - long torn tongues here and there - and curling out. (`hx`,
    `hz`, `cx`: another face's half size and middle - a limb's 1 x 1.)"""
    phases = [rng.uniform(0, 6.3) for _ in range(4)]
    tongues = [(rng.random(), rng.uniform(0.6, 1.6), rng.uniform(0.008, 0.02)) for _ in range(spikes)]
    rows = 4
    bm = bmesh.new()
    grid = []
    for k in range(count):
        s = k / count
        base, out = perimeter(s, inset, hx, hz)
        base = base + Vector((cx, 0, 0))
        a = 2 * math.pi * s
        reach = length * (0.55 + 0.3 * math.sin(a * 5 + phases[0]) * math.sin(a * 3 + phases[1])
                          + 0.25 * rng.random())
        for at, extra, width in tongues:  # torn tongues
            d = abs((s - at + 0.5) % 1.0 - 0.5)
            reach += length * extra * max(0.0, 1 - d / width) ** 0.7
        curl = flare * (0.6 + 0.4 * math.sin(a * 7 + phases[2]))
        column = []
        for r in range(rows + 1):
            t = r / rows
            along = Vector((0, up, 0)) * math.cos(curl * t) + out * math.sin(curl * t)
            p = Vector((base.x, y, base.z)) + along * reach * t
            p += out * 0.004 * math.sin(a * 23 + r + phases[3])  # (crumpled)
            column.append(bm.verts.new(p))
        grid.append(column)
    for k in range(count):
        q = (k + 1) % count
        for r in range(rows):
            bm.faces.new((grid[k][r], grid[q][r], grid[q][r + 1], grid[k][r + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:  # facing out of the body (solidify: inward)
        f.normal_update()
        mid = f.calc_center_median()
        if f.normal.dot(Vector((mid.x - cx, 0, mid.z * (hx / hz)))) < 0:
            f.normal_flip()
    return solidify(bm, thickness)


def ragged_ring(rng, ring, up, length, flare, thickness, spikes=6):
    """skirt() round any closed edge: `ring` = [(point, the way out of the
    wound there)], the torn band going `up` from it (out of the body), its
    end ragged with torn tongues, curling outward."""
    phases = [rng.uniform(0, 6.3) for _ in range(4)]
    tongues = [(rng.random(), rng.uniform(0.6, 1.5), rng.uniform(0.02, 0.05)) for _ in range(spikes)]
    rows = 4
    up = Vector(up).normalized()
    bm = bmesh.new()
    grid = []
    count = len(ring)
    for k, (base, out) in enumerate(ring):
        s = k / count
        a = 2 * math.pi * s
        reach = length * (0.55 + 0.3 * math.sin(a * 5 + phases[0]) * math.sin(a * 3 + phases[1])
                          + 0.25 * rng.random())
        for at, extra, width in tongues:
            d = abs((s - at + 0.5) % 1.0 - 0.5)
            reach += length * extra * max(0.0, 1 - d / width) ** 0.7
        curl = flare * (0.6 + 0.4 * math.sin(a * 7 + phases[2]))
        column = []
        for r in range(rows + 1):
            t = r / rows
            along = up * math.cos(curl * t) + out * math.sin(curl * t)
            p = base + along * reach * t + out * 0.004 * math.sin(a * 23 + r + phases[3])
            column.append(bm.verts.new(p))
        grid.append(column)
    for k in range(count):
        q = (k + 1) % count
        for r in range(rows):
            f = bm.faces.new((grid[k][r], grid[q][r], grid[q][r + 1], grid[k][r + 1]))
            f.normal_update()
            if f.normal.dot(ring[k][1]) < 0:  # (facing out of the wound; solidify: inward)
                f.normal_flip()
    return solidify(bm, thickness)


def raw_floor(rng, y, inset=0.03):
    """The raw, dark inside closing the torn face (2 x 1 at height y), lumpy."""
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=20, y_segments=10, size=1.0)
    half = max(max(abs(v.co.x), abs(v.co.y)) for v in bm.verts)
    for v in bm.verts:  # (made in X-Y, a square): onto X-Z, 2 x 1
        v.co = Vector((v.co.x / half * (1 - inset), y, v.co.y / half * (0.5 - inset)))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    phases = [rng.uniform(0, 6.3) for _ in range(4)]
    for v in bm.verts:
        v.co.y += 0.02 * math.sin(v.co.x * 9 + phases[0]) * math.sin(v.co.z * 11 + phases[1]) + rng.uniform(-0.006, 0.006)
    return bm


def solid_floor(rng, y, facing):
    """raw_floor made a thin slab (seen from both sides), its top facing
    `facing` (+1 up, -1 down)."""
    top = raw_floor(rng, y)
    for f in top.faces:
        f.normal_update()
        if f.normal.y * facing < 0:
            f.normal_flip()
    return solidify(top, 0.03)


def drip(rng, start, length, width):
    """A drip of blood hanging from `start`: a thin tapering string and its drop."""
    end = start + Vector((rng.uniform(-0.02, 0.02), -length, rng.uniform(-0.02, 0.02)))
    string = rod(start, end, width, width * 0.45, 6)
    drop = blob(rng, end, (width * 1.3, width * 1.8, width * 1.3), 8, 6)
    return bm_join_all([string, drop])


def torn_muscles(rng, groups, keep_above, top, bottom, spread, back_drop=0.0):
    """Each muscle cut where the body tore, each at its own height (torn
    fibres at the end), then kept between `bottom` and `top`. Returns
    (light, dark) lists. `back_drop`: the back's muscles moved down by it
    (as the spine: their thick part at the tear)."""
    light, dark = [], []
    index = 0
    for name in ("abdominal", "back"):
        for v, f in groups[name]:
            v = placed(v, WIDEN)
            if name == "back":  # (thicker: they fill the back of the cut)
                middle = v.mean(0)
                v = (v - middle) * np.array((1.35, 1, 1.35), dtype=np.float32) + middle
                v[:, 1] += back_drop
            bm = bm_of(v, f)
            y = TEAR_Y + (-1 if keep_above else 1) * rng.uniform(*spread)
            sign = -1 if keep_above else 1
            cut(bm, [((0, y, 0), (0, sign, 0)), ((0, top, 0), (0, 1, 0)), ((0, bottom, 0), (0, -1, 0))], fill=True)
            if len(bm.faces):
                tear(bm, rng, y, 0.04)
                (light if index % 2 == 0 else dark).append(bm)
            else:
                bm.free()
            index += 1
    return light, dark


def torn_waist(rng):
    """The Bull's finisher: (the torso's torn bottom, the top of the pelvis
    with the legs), each {layer: bmesh}, both in R6 torso space (see the
    module's doc: Waist, Hips)."""
    t = load_anatomy(TORSO_ANATOMY)

    # ---- Waist: what stays on the torso (above the tear), its cap below
    # (what is above the raw floor is hidden in the torso: cut away)
    drop = TEAR_Y - 0.08 - float(t["lumbar"][1][0][:, 1].min())  # (L4's bottom just out of the cut)
    muscles, muscles_dark = torn_muscles(rng, t, True, HIDDEN_ABOVE, -1.4, (0.02, 0.14), drop)
    # the lumbar spine (L3, L4) moved down to the tear, torn through the
    # disc under L4 (its upper half still on the bone)
    spine = bm_join_all([bm_of(placed(v, (1, 1, 1), (0, drop, 0)), f) for v, f in t["lumbar"][:2]])
    cut(spine, [((0, HIDDEN_ABOVE, 0), (0, 1, 0))], fill=True)
    disc = bm_of(placed(t["disc"][1][0], (1, 1, 1), (0, drop, 0)), t["disc"][1][1])
    disc_mid = float(np.mean(t["disc"][1][0][:, 1])) + drop
    cut(disc, [((0, disc_mid - 0.01, 0), (0, -1, 0))], fill=True)
    tear(disc, rng, disc_mid - 0.01, 0.015)
    canal = Vector((0.0, TEAR_Y - 0.04, 0.19))  # (the spinal canal, behind the bodies)
    nerves = bm_join_all([
        rod(canal + Vector((rng.uniform(-0.03, 0.03), 0.04, rng.uniform(-0.02, 0.02))),
            canal + Vector((rng.uniform(-0.06, 0.06), -rng.uniform(0.08, 0.22), rng.uniform(-0.05, 0.05))),
            rng.uniform(0.008, 0.014), 0.005, 5)
        for _ in range(5)
    ])
    # the small intestine: its lower loops, widened, sagging out of the
    # opening (the lower, the more)
    jv, jf = t["jejunum"][0]
    # (the whole mass moved down: most of it out of the opening, hanging,
    # spread over the front half of the cut)
    jv = jv.copy()
    jv[:, 0] = jv[:, 0] * 1.3 + 0.03
    jv[:, 1] = -0.9 + (jv[:, 1] + 0.44) * 0.72
    jv[:, 2] = -0.1 + (jv[:, 2] + 0.18) * 1.5
    gut = bm_of(jv, jf)
    cut(gut, [((0, HIDDEN_ABOVE, 0), (0, 1, 0))], fill=True)
    gut = decimate(gut, 3600)
    lumpy(gut, rng, 0.006, 14.0)
    colon = []
    for v, f in t["colon"][:2]:  # (ascending, descending)
        bm = bm_of(placed(v, (1.25, 1, 1)), f)
        cut(bm, [((0, HIDDEN_ABOVE, 0), (0, 1, 0)), ((0, TEAR_Y - 0.12, 0), (0, -1, 0))], fill=True)
        if len(bm.faces):
            tear(bm, rng, TEAR_Y - 0.12, 0.03)
            colon.append(bm)
    # the skin torn round the edge, hanging and curling out; the fat inside it
    skin = skirt(rng, TEAR_Y + 0.005, -1, 0.003, 0.11, 0.8, 0.02)
    fat = skirt(rng, TEAR_Y + 0.03, -1, 0.024, 0.06, 0.15, 0.04, spikes=5)
    # shreds of torn muscle hanging from the walls of the cut
    for k in range(12):
        base, out = perimeter((k + rng.random() * 0.6) / 12, 0.09)
        top = Vector((base.x, TEAR_Y - 0.01, base.z))
        shred = blob(rng, top + Vector((0, -0.05, 0)) - out * 0.02,
                     (rng.uniform(0.025, 0.05), rng.uniform(0.05, 0.1), rng.uniform(0.02, 0.035)), 8, 6, 0.01)
        (muscles if k % 2 == 0 else muscles_dark).append(shred)
    blood = []
    for _ in range(7):
        base, _out = perimeter(rng.random())
        at = Vector((base.x * rng.uniform(0.3, 0.9), TEAR_Y - rng.uniform(0.04, 0.12), base.z * rng.uniform(0.3, 0.9)))
        blood.append(drip(rng, at, rng.uniform(0.06, 0.18), rng.uniform(0.012, 0.02)))
    waist = {
        "Gut": gut,
        "GutDark": bm_join_all(colon),
        "Muscle": bm_join_all(muscles),
        "MuscleDark": bm_join_all(muscles_dark),
        "Bone": spine,
        "Cartilage": disc,
        "Tendon": nerves,
        "Fat": fat,
        "Skin": skin,
        "FleshDark": solid_floor(rng, TEAR_Y - 0.015, -1),
        "Blood": bm_join_all(blood),
    }

    # ---- Hips: what goes with the legs (below the tear), as if they were on
    muscles, muscles_dark = torn_muscles(rng, t, False, TEAR_Y + 0.3, HIDDEN_BELOW, (0.02, 0.16))
    pelvis = []
    for v, f in t["hipbone"] + t["sacrum"]:
        bm = bm_of(placed(v, (1.12, 1, 1)), f)
        cut(bm, [((0, HIDDEN_BELOW, 0), (0, -1, 0))], fill=True)
        pelvis.append(bm)
    l5 = bm_of(*t["lumbar"][2])
    cut(l5, [((0, HIDDEN_BELOW, 0), (0, -1, 0))], fill=True)
    pelvis.append(l5)
    lower_disc = bm_of(*t["disc"][1])
    middle = float(np.mean(t["disc"][1][0][:, 1]))
    cut(lower_disc, [((0, middle + 0.01, 0), (0, 1, 0))], fill=True)
    tear(lower_disc, rng, middle + 0.01, 0.015)
    # the intestine's lowest loops spilling over the top (their torn ends
    # up), the sigmoid colon
    jv, jf = t["jejunum"][0]
    jv = placed(jv, (1.3, 1, 1.15), (0.03, 0.2, -0.04))
    spill = bm_of(jv, jf)
    cut(spill, [((0, TEAR_Y + 0.2, 0), (0, 1, 0)), ((0, HIDDEN_BELOW, 0), (0, -1, 0))], fill=True)
    tear(spill, rng, TEAR_Y + 0.2, 0.025)
    spill = decimate(spill, 1800)
    lumpy(spill, rng, 0.006, 14.0)
    sv, sf = t["colon"][2]
    sigmoid = bm_of(placed(sv, (1.2, 1, 1), (0, 0.32, -0.05)), sf)
    cut(sigmoid, [((0, HIDDEN_BELOW, 0), (0, -1, 0))], fill=True)
    # the skin torn round the edge, standing up and curling out; the fat inside it
    skin = skirt(rng, TEAR_Y - 0.005, 1, 0.003, 0.12, 0.9, 0.02)
    fat = skirt(rng, TEAR_Y - 0.03, 1, 0.024, 0.07, 0.15, 0.04, spikes=5)
    pools = []
    for _ in range(5):  # blood pooled on the raw tops
        at = Vector((rng.uniform(-0.8, 0.8), TEAR_Y + 0.01, rng.uniform(-0.35, 0.35)))
        pools.append(blob(rng, at, (rng.uniform(0.08, 0.18), 0.012, rng.uniform(0.06, 0.14)), 12, 6, 0.004))
    hips = {
        "Bone": decimate(bm_join_all(pelvis), 2600),
        "Cartilage": lower_disc,
        "Muscle": bm_join_all(muscles),
        "MuscleDark": bm_join_all(muscles_dark),
        "Gut": spill,
        "GutDark": sigmoid,
        "Fat": fat,
        "Skin": skin,
        "FleshDark": solid_floor(rng, TEAR_Y + 0.015, 1),
        "Blood": bm_join_all(pools),
    }
    return waist, hips


def gut_segment(rng, length=0.5, radius=0.072):
    """A short piece of small intestine, along Y, centred: a lumpy, a
    little bent tube (Gut), closed at its torn ends, its mesentery torn
    along its inner side (GutDark)."""
    rings, segments = 22, 12
    bend = rng.uniform(0.04, 0.09) * rng.choice((-1, 1))
    twist = rng.uniform(-0.03, 0.03)
    phase = rng.uniform(0, 6.3)

    def centre(t):  # t in [-1, 1]
        return Vector((bend * (1 - t * t), t * length / 2, twist * t * t * t))

    bm = bmesh.new()
    rows = []
    for k in range(rings + 1):
        t = -1 + 2 * k / rings
        p = centre(t)
        ahead = (centre(min(1, t + 0.01)) - centre(max(-1, t - 0.01))).normalized()
        side = ahead.cross(Vector((0, 0, 1))).normalized()
        up = side.cross(ahead).normalized()
        # bulges between the narrowings, thinner at the torn ends
        r = radius * (1 + 0.12 * math.sin(t * 12 + phase)) * (0.72 + 0.28 * math.sqrt(max(0.0, 1 - t ** 8)))
        row = []
        for s in range(segments):
            a = 2 * math.pi * s / segments
            rr = r * (1 + rng.uniform(-0.04, 0.04))
            row.append(bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * rr))
        rows.append(row)
    for k in range(rings):
        for s in range(segments):
            q = (s + 1) % segments
            bm.faces.new((rows[k][s], rows[k][q], rows[k + 1][q], rows[k + 1][s]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    lumpy(bm, rng, 0.008, 22.0)
    # the torn ends: the dark red inside showing, sunk in a little
    ends = bmesh.new()
    for row, end in ((rows[0], -1), (rows[-1], 1)):
        ring_ = [ends.verts.new(v.co) for v in row]  # (the tube's own edge: no crack)
        c = ends.verts.new(centre(end) - Vector((0, end * radius * 0.35, 0)))
        for s in range(segments):
            f = ends.faces.new((ring_[s], ring_[(s + 1) % segments], c))
            f.normal_update()
            if f.normal.y * end < 0:  # (facing out of the end)
                f.normal_flip()
    # the mesentery: a thin torn sheet along the inner side of the bend
    sheet = bmesh.new()
    inner = Vector((-1 if bend > 0 else 1, 0, 0))
    edge_rows = []
    for k in range(9):
        t = -0.8 + 1.6 * k / 8
        p = centre(t) + inner * radius * 0.7
        width = rng.uniform(0.04, 0.09) * (1 - 0.5 * abs(t))
        edge_rows.append((sheet.verts.new(p), sheet.verts.new(p + inner * width + Vector((0, 0, rng.uniform(-0.02, 0.02))))))
    for k in range(8):
        a, b = edge_rows[k], edge_rows[k + 1]
        sheet.faces.new((a[0], b[0], b[1], a[1]))
    mesentery = solidify(sheet, 0.014)
    # centred (its box), for the chain
    lo = Vector([min(v.co[k] for v in bm.verts) for k in range(3)])
    hi = Vector([max(v.co[k] for v in bm.verts) for k in range(3)])
    dark = bm_join_all([mesentery, ends])
    for part in (bm, dark):
        bmesh.ops.translate(part, vec=-(lo + hi) / 2, verts=part.verts)
    return {"Gut": bm, "GutDark": dark}


def gut_pile(rng):
    """A heap of loops of the real jejunum (see the module's doc)."""
    t = load_anatomy(TORSO_ANATOMY)
    v, f = t["jejunum"][0]
    v = v.astype(np.float64)
    c = (v.min(0) + v.max(0)) / 2
    # laid down: the torso's up -> along the floor (Z), its depth -> up
    x = (v[:, 0] - c[0]) * 0.82
    z = (v[:, 1] - c[1]) * 0.8
    y = (v[:, 2] - v[:, 2].min()) * 0.82
    y += 0.16 * np.clip(1 - (x / 0.47) ** 2 - (z / 0.36) ** 2, 0, 1)  # heaped up in the middle
    pile = bm_of(np.stack([x, y, z], axis=1), f)
    pile = decimate(pile, 3200)
    lumpy(pile, rng, 0.007, 14.0)
    low = min(vv.co.y for vv in pile.verts)
    bmesh.ops.translate(pile, vec=(0, -low, 0), verts=pile.verts)
    # bits of mesentery among the loops
    bits = bm_join_all([
        blob(rng, (rng.uniform(-0.3, 0.3), rng.uniform(0.06, 0.2), rng.uniform(-0.22, 0.22)),
             (rng.uniform(0.04, 0.08), rng.uniform(0.015, 0.03), rng.uniform(0.04, 0.07)), 8, 5, 0.008)
        for _ in range(7)
    ])
    return {"Gut": pile, "GutDark": bits}


def build(add_object):
    """Adds the gore pieces to the kit. `add_object(name, bm, offset, layer)`.
    Returns {piece: slot (kit-space Vector)} and the lists by kind."""
    rng = random.Random(4242)
    anatomy = load_anatomy()
    slots = {}
    kinds = {
        k: []
        for k in ("skull", "brain", "eye", "tooth", "splat", "streak", "pool", "organ", "limb", "bisect", "gut",
                  "dismember")
    }

    def piece(name, layers, kind=None):
        slot = GORE_ORIGIN + Vector((len(slots) * SLOT_STEP, 0, 0))
        slots[name] = slot
        for layer, bm in layers.items():
            if bm is not None and len(bm.faces) > 0:
                add_object(f"Gore_{name}_{layer}", bm, slot, layer)
        if kind:
            kinds[kind].append(name)

    cranium = bm_of(*anatomy["cranium"][0])
    brain = bm_of(*anatomy["brain"][0])
    surface = head_surface()

    # The skull and the scalp, broken along the same lines (above the jaw).
    seeds = [s * 0.55 for s in fibonacci(SKULL_PIECES, rng, 0.35)]
    seeds = [s for s in seeds if s.y > CUT_Y - 0.05] or seeds
    above = [((0, CUT_Y, 0), (0, -1, 0))]
    for i in range(len(seeds)):
        planes = cell_planes(seeds, i) + above
        bone = cut(bm_copy(cranium), planes, fill=True)
        skin_patch = cut(bm_copy(surface), planes, fill=False)
        skin = solidify(skin_patch, SCALP) if len(skin_patch.faces) else None
        piece(f"Skull{i + 1}", {"Skin": skin, "Bone": bone}, "skull")

    # The brain, in lumps.
    bseeds = [Vector((rng.uniform(-0.35, 0.35), rng.uniform(-0.1, 0.4), rng.uniform(-0.3, 0.35)))
              for _ in range(BRAIN_PIECES)]
    for i in range(len(bseeds)):
        lump = cut(bm_copy(brain), cell_planes(bseeds, i), fill=True)
        piece(f"Brain{i + 1}", {"Brain": lump}, "brain")

    # The eyes (round again) and their nerve.
    for i, ((sv, sf), (iv, iff)) in enumerate(zip(anatomy["sclera"], anatomy["iris"])):
        center = sv.mean(0)
        sclera = squeeze(sv, 0, 5.1 / 7.5)
        iris = iv.copy()
        iris[:, 0] = center[0] + (iris[:, 0] - center[0]) * (5.1 / 7.5)
        # (the cone is built along Z: the back of the head; from the back of the eye)
        nerve = bmesh.new()
        bmesh.ops.create_cone(nerve, cap_ends=True, segments=8, radius1=0.025, radius2=0.02, depth=0.22)
        back = float(sv[:, 2].max())
        bmesh.ops.translate(nerve, verts=nerve.verts, vec=Vector((center[0], center[1], back + 0.1)))
        piece(f"Eye{i + 1}", {"Sclera": bm_of(sclera, sf), "Iris": bm_of(iris, iff), "Flesh": nerve}, "eye")

    # Some upper teeth fly out.
    upper = list(anatomy["upperteeth"])
    rng.shuffle(upper)
    for i, (v, f) in enumerate(upper[:FLYING_TEETH]):
        piece(f"Tooth{i + 1}", {"Tooth": bm_of(squeeze(v, 0, 0.75), f)}, "tooth")

    # What stays: the lower jaw and its teeth, the skin of the chin and
    # cheeks (torn along the top), the wound inside, the top of the spine.
    mandible = bm_of(*anatomy["mandible"][0])
    teeth = bm_join([bm_of(squeeze(v, 0, 0.75), f) for v, f in anatomy["lowerteeth"]])
    below = [((0, CUT_Y, 0), (0, 1, 0))]
    jaw_skin_patch = cut(bm_copy(surface), below, fill=False)
    rough_rim(jaw_skin_patch, rng, 0.07, lambda co: co.y > CUT_Y - 0.01)
    jaw_skin = solidify(jaw_skin_patch, SCALP)
    flesh = bmesh.new()
    rim = []
    for k in range(40):
        a = 2 * math.pi * k / 40
        r = 0.55 * (1 + rng.uniform(-0.05, 0.03))
        rim.append(flesh.verts.new((r * math.sin(a), CUT_Y - 0.13 + rng.uniform(-0.03, 0.03), r * math.cos(a))))
    middle = flesh.verts.new((0, CUT_Y - 0.16, 0.05))
    for k in range(40):
        flesh.faces.new((middle, rim[k], rim[(k + 1) % 40]))
    bmesh.ops.recalc_face_normals(flesh, faces=flesh.faces)
    for face in flesh.faces:  # facing up
        if face.normal.y < 0:
            face.normal_flip()
    vertebrae = bm_of(*anatomy["vertebrae"][0])
    piece("Jaw", {"Bone": bm_join([mandible, vertebrae]), "Tooth": teeth, "Skin": jaw_skin, "Flesh": flesh})

    # The Boxer's finisher: the real liver and its gallbladder, torn out
    # (centred on the liver's middle: it ends up in a hand).
    lv, lf = anatomy["liver"][0]
    gv, gf = anatomy["gallbladder"][0]
    middle = lv.mean(0)
    piece("Liver", {"Liver": bm_of(lv - middle, lf), "Gallbladder": bm_of(gv - middle, gf)}, "organ")

    # Blood on the floor.
    for i in range(4):
        piece(f"Splat{i + 1}", {"Blood": blot(rng, 0.42, 1.0 + i * 0.3, 7 + i * 2)}, "splat")
    for i in range(3):
        piece(f"Streak{i + 1}", {"Blood": blot(rng, 0.12, 0.4, 2, stretch=2.6, tail=0.5)}, "streak")
    for i in range(2):
        piece(f"Pool{i + 1}", {"Blood": blot(rng, 0.5, 0.8, 3 + i * 3, ring=72)}, "pool")

    # The Bouncer's finisher: the right arm torn off at the shoulder. (Last,
    # with its own random numbers: the pieces above keep their slots.)
    arm_end, shoulder = torn_arm(random.Random(7171))
    piece("ArmEnd", arm_end, "limb")
    piece("Shoulder", shoulder, "limb")
    bone = humerus(random.Random(5151))
    top, bottom = snapped(bone["Bone"], random.Random(5252))  # (before: piece() frees the meshes)
    piece("Humerus", bone, "limb")
    piece("HumerusA", {"Bone": top}, "limb")
    piece("HumerusB", {"Bone": bottom}, "limb")

    # The Bull's finisher: the body torn in two at the hips, the guts
    # between the halves. (Last, their own random numbers: the pieces above
    # keep their slots.)
    waist, hips = torn_waist(random.Random(8383))
    piece("Waist", waist, "bisect")
    piece("Hips", hips, "bisect")
    for i in range(3):
        piece(f"Gut{i + 1}", gut_segment(random.Random(9191 + i)), "gut")
    piece("GutPile", gut_pile(random.Random(9494)), "gut")

    # The heavy hits (a heavy blow at the end of a big combo): the legs torn
    # off, the left arm and leg. (Last, their own random numbers: the pieces
    # above keep their slots.)
    heavy_gore(6060, piece)
    return slots, kinds


def lua(slots, kinds):
    def num(x):
        return f"{x:.4f}".rstrip("0").rstrip(".") if abs(x) > 1e-9 else "0"

    lines = [
        "--!strict",
        "-- GENERATED by tools/wounds/build_wound_kit.py (gore.py) - do not edit by hand.",
        "-- The burst head's pieces in WoundKit (\"Gore_<Piece>_<Layer>\"): where each",
        "-- piece's head space sits in the kit (kit studs, from the Kit_Origin marker,",
        "-- in the kit's axes), and the pieces by kind. Head space: X right,",
        "-- Y up, Z back, origin = the head's centre (studs).",
        "",
        "local GoreShapes = {",
        "\tslots = {",
    ]
    for name, slot in slots.items():
        at = slot + Vector((0, 3, 0))  # (from Kit_Origin, which is 3 below)
        lines.append(f"\t\t{name} = Vector3.new({num(at.x)}, {num(at.y)}, {num(at.z)}),")
    lines.append("\t} :: { [string]: Vector3 },")
    for kind, names in kinds.items():  # (one per line: as StyLua writes it)
        lines.append(f"\t{kind} = {{")
        lines += [f'\t\t"{n}",' for n in names]
        lines.append("\t},")
    lines += ["}", "", "return table.freeze(GoreShapes)", ""]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# The heavy hits (a heavy blow at the end of a big combo): a leg torn off at
# the hip, both arms / legs (the left ones mirrored). Z-Anatomy, limbs.npz
# (extract_limbs.py).

LIMB_ANATOMY = os.path.join(HERE, "anatomy", "limbs.npz")  # extract_limbs.py


def load_limbs():
    """limbs.npz: {group: [bmesh, ...]} (see extract_limbs.py)."""
    data = np.load(LIMB_ANATOMY)
    out = {}
    for key in sorted(data.files, key=lambda k: (k.split("__")[0], int(k.split("__")[1]))):
        group, index, kind = key.split("__")
        if kind == "v":
            out.setdefault(group, []).append(bm_of(data[key], data[f"{group}__{index}__f"]))
    return out


def mirrored(layers):
    """{layer: bmesh} -> the same, mirrored left / right (X -> -X), faces
    still outward (a left limb from a right one)."""
    out = {}
    for layer, bm in layers.items():
        if bm is None:
            continue
        copy = bm_copy(bm)
        for v in copy.verts:
            v.co.x = -v.co.x
        bmesh.ops.reverse_faces(copy, faces=copy.faces[:])
        copy.normal_update()
        out[layer] = copy
    return out


def square_edge(a, cx=0.0, half=0.5):
    """The point at angle `a` on the edge of the square `half` round (cx, 0)
    in X-Z, and the way out there."""
    out = Vector((math.cos(a), 0, math.sin(a)))
    edge = half / max(abs(out.x), abs(out.z))
    return Vector((cx + out.x * edge, 0, out.z * edge)), out


def torn_leg(rng):
    """The leg torn off at the hip: (the leg's torn top, what stays on the
    torso), each {layer: bmesh}. R6 spaces: the right leg (1 x 2 x 1, its
    top face at Y = 1), the torso (its bottom face at Y = -1, the right leg
    under X = 0..1).

    The leg's top shows the real cut of the thigh's muscles (quadriceps,
    hamstrings, adductors, sartorius, gracilis), each torn at its own height,
    the real femur's head out of it (to the inside, as it is), the fat in a
    yellow band, the skin torn and hanging. The hip keeps the real hip bone
    round its empty socket and the muscles round the joint (glutei,
    iliopsoas, pectineus...) torn short, hanging."""
    limbs = load_limbs()
    half = 0.47

    # ---- the leg's top
    muscles, dark = [], []
    for index, muscle in enumerate(limbs["thighmuscle"]):
        for v in muscle.verts:  # (wider still: they fill the blocky leg)
            v.co.x *= 1.3
            v.co.z *= 1.45
        y = 1.05 + rng.uniform(0.0, 0.17)
        cut(muscle, [
            ((0, y, 0), (0, 1, 0)), ((0, 0.78, 0), (0, -1, 0)),
            ((half, 0, 0), (1, 0, 0)), ((-half, 0, 0), (-1, 0, 0)),
            ((0, 0, half), (0, 0, 1)), ((0, 0, -half), (0, 0, -1)),
        ], fill=True)
        if len(muscle.faces):
            tear(muscle, rng, y, 0.05)
            (muscles if index % 2 == 0 else dark).append(muscle)
    for k in range(5):  # torn muscle bellies bulging out of the cut
        a = 2 * math.pi * k / 5 + rng.uniform(-0.3, 0.3)
        at = (math.cos(a) * rng.uniform(0.12, 0.3), 1.0, math.sin(a) * rng.uniform(0.12, 0.3))
        belly = blob(rng, at, (rng.uniform(0.12, 0.2), rng.uniform(0.04, 0.08), rng.uniform(0.1, 0.18)), 14, 8, 0.02)
        lumpy(belly, rng, 0.012, 30.0)
        (muscles if k % 2 else dark).append(belly)
    bone = limbs["femur"][0]
    cut(bone, [((0, 0.6, 0), (0, -1, 0))], fill=True)
    floor = bmesh.new()
    bmesh.ops.create_cube(floor, size=1.0)
    for v in floor.verts:
        v.co = Vector((v.co.x * 0.96, 1.01 + v.co.y * 0.03, v.co.z * 0.96))
    lumpy(floor, rng, 0.004, 14.0)
    fat = []
    for side in range(4):
        wall = bmesh.new()
        bmesh.ops.create_cube(wall, size=1.0)
        bmesh.ops.subdivide_edges(wall, edges=wall.edges[:], cuts=6, use_grid_fill=True)
        for v in wall.verts:
            local = Vector((v.co.x * 0.98, 1.0 + v.co.y * 0.12, 0.47 + v.co.z * 0.06))
            ang = side * math.pi / 2
            v.co = Vector((local.x * math.cos(ang) + local.z * math.sin(ang), local.y,
                           -local.x * math.sin(ang) + local.z * math.cos(ang)))
        tear(wall, rng, 1.06, 0.035)
        fat.append(wall)
    # the real femoral artery and vein, the sciatic nerve: torn, their ends
    # out of the cut (the nerve, thick and pale, the longest)
    vessels = {}
    for index, vessel in enumerate(limbs["thighvessel"]):
        for v in vessel.verts:
            v.co.x *= 1.3
            v.co.z *= 1.45
        y = 1.0 + (0.18, 0.1, 0.24)[index % 3] * rng.uniform(0.7, 1.2)
        cut(vessel, [((0, y, 0), (0, 1, 0)), ((0, 0.8, 0), (0, -1, 0)),
                     ((half, 0, 0), (1, 0, 0)), ((-half, 0, 0), (-1, 0, 0)),
                     ((0, 0, half), (0, 0, 1)), ((0, 0, -half), (0, 0, -1))], fill=True)
        if len(vessel.faces):
            tear(vessel, rng, y, 0.02)
            for v in vessel.verts:  # (limp: the end flops over)
                over = max(0.0, v.co.y - 1.0)
                v.co.x += over * over * rng.uniform(-1.5, 1.5)
            layer = ("Artery", "Vein", "Nerve")[index % 3]
            vessels.setdefault(layer, []).append(vessel)
    # the round ligament of the femur's head, torn: a white string off its top
    head = max(bone.verts, key=lambda v: v.co.y).co.copy()
    tendons = rod(head - Vector((0, 0.02, 0)), head + Vector((0.05, 0.12, -0.03)), 0.02, 0.008, 6)
    # the skin torn round the top edge (ragged, tongues of it, curling out)
    # and the fat under it
    skin = skirt(rng, 0.995, 1, 0.002, 0.1, 0.9, 0.02, count=40, spikes=6, hx=0.5, hz=0.5)
    fat_rim = skirt(rng, 0.97, 1, 0.022, 0.07, 0.2, 0.035, count=40, spikes=4, hx=0.5, hz=0.5)
    blood = bm_join_all([
        drip(rng, Vector((p.x * 1.02, 0.98, p.z * 1.02)), rng.uniform(0.12, 0.35), rng.uniform(0.014, 0.022))
        for p in (square_edge(rng.uniform(0, 2 * math.pi))[0] for _ in range(5))
    ])
    leg_end = {
        "Muscle": bm_join_all(muscles),
        "MuscleDark": bm_join_all(dark),
        "FleshDark": floor,
        "Fat": bm_join_all(fat + [fat_rim]),
        "Bone": bone,
        "Tendon": tendons,
        "Skin": skin,
        "Blood": blood,
    }
    for layer, items in vessels.items():
        leg_end[layer] = bm_join_all(items)

    # ---- the hip: the torso's bottom face over the leg (X = 0..1), opened
    pelvis = limbs["hipbone"][0]
    cut(pelvis, [((0, -0.72, 0), (0, 1, 0)), ((0, -1.1, 0), (0, -1, 0)),
                 ((1.04, 0, 0), (1, 0, 0)), ((0, 0, 0.52), (0, 0, 1)), ((0, 0, -0.52), (0, 0, -1))], fill=True)
    stubs, stubs_dark = [], []
    for index, muscle in enumerate(limbs["hipmuscle"]):
        y = -1.0 - rng.uniform(0.04, 0.17)
        cut(muscle, [((0, y, 0), (0, -1, 0)), ((0, -0.75, 0), (0, 1, 0)),
                     ((1.02, 0, 0), (1, 0, 0)), ((-0.02, 0, 0), (-1, 0, 0)),
                     ((0, 0, 0.5), (0, 0, 1)), ((0, 0, -0.5), (0, 0, -1))], fill=True)
        if len(muscle.faces):
            tear(muscle, rng, y, 0.045)
            (stubs if index % 2 == 0 else stubs_dark).append(muscle)
    deep = bmesh.new()
    bmesh.ops.create_cube(deep, size=1.0)
    for v in deep.verts:
        v.co = Vector((0.5 + v.co.x * 0.95, -1.01 + v.co.y * 0.03, v.co.z * 0.95))
    lumpy(deep, rng, 0.004, 14.0)
    # the skin torn round the edge of the hole (hanging, ragged) and the fat
    # under it
    rim = skirt(rng, -0.995, -1, 0.002, 0.1, 0.8, 0.02, count=40, spikes=6, hx=0.5, hz=0.5, cx=0.5)
    rim_fat = skirt(rng, -0.97, -1, 0.022, 0.06, 0.18, 0.035, count=40, spikes=4, hx=0.5, hz=0.5, cx=0.5)
    drops = bm_join_all([
        drip(rng, Vector((rng.uniform(0.15, 0.85), -1.05, rng.uniform(-0.35, 0.35))),
             rng.uniform(0.08, 0.25), rng.uniform(0.014, 0.022))
        for _ in range(5)
    ])
    hip = {
        "Muscle": bm_join_all(stubs),
        "MuscleDark": bm_join_all(stubs_dark),
        "FleshDark": deep,
        "Fat": rim_fat,
        "Bone": pelvis,
        "Skin": rim,
        "Blood": drops,
    }
    return leg_end, hip


def heavy_gore(rng_seed, piece):
    """Adds the heavy hits' pieces (see the module's doc), in this order."""
    leg_end, hip = torn_leg(random.Random(rng_seed))
    piece("LegEnd", leg_end, "dismember")
    piece("Hip", hip, "dismember")
    # the left arm and leg: the right ones mirrored (the same random numbers)
    # the arms (the Bouncer's ArmEnd / Shoulder are the finisher's own):
    # the skin torn ragged round the wound, no flaps
    arm_end, shoulder = torn_arm(random.Random(7171), ragged=True)
    piece("ArmEndL", mirrored(arm_end), "dismember")
    piece("ShoulderL", mirrored(shoulder), "dismember")
    leg_end, hip = torn_leg(random.Random(rng_seed))
    piece("LegEndL", mirrored(leg_end), "dismember")
    piece("HipL", mirrored(hip), "dismember")
    piece("ArmEndR", arm_end, "dismember")
    piece("ShoulderR", shoulder, "dismember")
    for layers in (leg_end, hip):
        for bm in layers.values():
            bm.free()
