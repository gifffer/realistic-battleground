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
  Waist      Dr. Rift's finisher (PortalCut, the body cut in two at the
             hips; anatomy/waist.npz, extract_waist.py): the face under the
             upper body, in the R6 torso's space (2 x 2 x 1, its bottom at
             Y = -1): the real cut through the hip joints - hip bones,
             sacrum and femoral heads in section (Bone), the muscles cut
             (Muscle / MuscleDark alternating), bladder, colon and loops of
             small intestine hanging out (Gut), the cut arteries' ends
             (Vessel), the fat under the skin (Fat), torn skin hanging over
             the edge (Skin), a dark floor under it all (FleshDark)
  HipR / HipL  ...the other face of it, on each leg's top (R6 leg space:
             1 x 2 x 1, its top at Y = 1): the femur's head in its socket,
             the thigh and hip muscles, the femoral artery and vein, fat,
             skin folding up and out (same layers)
  Gut<i>     loose lengths of the real small intestine (Gut), coiled, a
             torn end trailing, centred; the first with a strip of its
             mesentery (Fat, Vessel): they fall out of the upper body
  Splat<i> / Streak<i> / Pool<i>   blood on the floor (Blood): flat blots
             with droplets, stretched drops, a pool; 1 stud across, laid in
             X-Z (the game sizes and turns them)

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
    "Gut": (0.74, 0.52, 0.48),
    "Vessel": (0.33, 0.05, 0.12),
}


def load_anatomy():
    data = np.load(ANATOMY)
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


def torn_arm(rng):
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
    for k in range(10):  # skin torn around the top edge, hanging over the sides
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
        "Tendon": tendons,
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
    ])
    hanging = bm_join_all([
        rod((sx + 0.06, rng.uniform(0.15, 0.45), rng.uniform(-0.3, 0.3)),
            (sx + rng.uniform(0.08, 0.16), rng.uniform(-0.2, 0.05), rng.uniform(-0.35, 0.35)),
            rng.uniform(0.02, 0.035), 0.01, 6)
        for _ in range(3)
    ])
    rim = []
    for k in range(12):  # torn skin around the socket, curling out
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


def build(add_object):
    """Adds the gore pieces to the kit. `add_object(name, bm, offset, layer)`.
    Returns {piece: slot (kit-space Vector)} and the lists by kind."""
    rng = random.Random(4242)
    anatomy = load_anatomy()
    slots = {}
    kinds = {k: [] for k in ("skull", "brain", "eye", "tooth", "splat", "streak", "pool", "organ", "limb", "cut")}

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

    # Dr. Rift's finisher: the body cut in two at the waist. (Last again,
    # their own random numbers: nothing above moves.)
    waist, hip_r, hip_l = waist_cut(random.Random(9393))
    piece("Waist", waist, "cut")
    piece("HipR", hip_r, "cut")
    piece("HipL", hip_l, "cut")
    for i, layers in enumerate(gut_lengths(random.Random(9494))):
        piece(f"Gut{i + 1}", layers, "cut")
    return slots, kinds


# ---- Dr. Rift's finisher (PortalCut): the body cut in two at the waist ----

WAIST_ANATOMY = os.path.join(HERE, "anatomy", "waist.npz")  # extract_waist.py


def load_waist():
    """waist.npz: {group: [(name, v, f)]} (R6 torso space, the cut on Y = -1)."""
    data = np.load(WAIST_ANATOMY)
    groups = {}
    for key in data.files:
        group, index, kind = key.split("__")
        groups.setdefault(group, {}).setdefault(int(index), {})[kind] = data[key]
    return {g: [(str(d["n"]), d["v"], d["f"]) for _i, d in sorted(items.items())] for g, items in groups.items()}


def outline(points, centre, bins=48):
    """How far the anatomy reaches from `centre` in X-Z, by direction (bins
    round the circle; the empty ones filled from their neighbours)."""
    reach = np.zeros(bins)
    d = points[:, [0, 2]] - np.array(centre)
    ang = np.arctan2(d[:, 1], d[:, 0])
    rad = np.hypot(d[:, 0], d[:, 1])
    idx = ((ang + math.pi) / (2 * math.pi) * bins).astype(int) % bins
    for i, r in zip(idx, rad):
        reach[i] = max(reach[i], r)
    for _ in range(bins):  # (fill gaps)
        empty = reach <= 1e-6
        if not empty.any():
            break
        reach[empty] = np.maximum(np.roll(reach, 1), np.roll(reach, -1))[empty]
    smooth = (np.roll(reach, 1) + 2 * reach + np.roll(reach, -1)) / 4
    return np.maximum(smooth, 0.05)


def squarify(bm, centre, half, reach, fill=0.97):
    """Widens the anatomy (round, as the real body) to fill the R6 part's
    blocky footprint (`half` = its half size in X, Z): every point pushed
    out from `centre` so the outline lands on the box's edge (no empty
    corners), what is inside following in proportion."""
    bins = len(reach)
    cx, cz = centre
    for v in bm.verts:
        dx, dz = v.co.x - cx, v.co.z - cz
        a = math.atan2(dz, dx)
        f = (a + math.pi) / (2 * math.pi) * bins - 0.5
        i0 = math.floor(f) % bins
        t = f - math.floor(f)
        r = reach[i0] * (1 - t) + reach[(i0 + 1) % bins] * t
        c, s = abs(math.cos(a)), abs(math.sin(a))
        edge = min(half[0] / c if c > 1e-6 else 1e9, half[1] / s if s > 1e-6 else 1e9)
        k = edge * fill / r
        v.co.x = cx + dx * k
        v.co.z = cz + dz * k
    bm.normal_update()
    return bm


def thicken(bm, factor):
    """A thin vessel made thicker round its own axis (in X-Z): it shows."""
    if not len(bm.verts):
        return bm
    c = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
    for v in bm.verts:
        v.co.x = c.x + (v.co.x - c.x) * factor
        v.co.z = c.z + (v.co.z - c.z) * factor
    return bm


def tube(path, radius, rng, segments=10, rib=0.18, ribs=9.0):
    """A soft tube along `path` (points): an intestine (ribbed: its folds),
    closed at both ends."""
    pts = [Vector(p) for p in path]
    bm = bmesh.new()
    rings = []
    length = 0.0
    prev_side = None
    for i, p in enumerate(pts):
        if i > 0:
            length += (p - pts[i - 1]).length
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
        side = t.cross(ref).normalized() if prev_side is None else (prev_side - t * prev_side.dot(t)).normalized()
        prev_side = side
        up = t.cross(side).normalized()
        r = radius * (1 + rib * math.sin(length / radius * ribs / 6))
        rings.append([bm.verts.new(p + (side * math.cos(2 * math.pi * k / segments)
                                        + up * math.sin(2 * math.pi * k / segments)) * r)
                      for k in range(segments)])
    for i in range(len(rings) - 1):
        for k in range(segments):
            j = (k + 1) % segments
            bm.faces.new((rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    lumpy(bm, rng, radius * 0.12, 14.0)
    return bm


def hanging_loop(rng, a, b, depth, radius):
    """A loop of gut hanging out of the cut from `a` to `b` (both on it),
    sagging `depth` out of it, swinging a little to one side."""
    a, b = Vector(a), Vector(b)
    sway = Vector((rng.uniform(-0.15, 0.15), 0, rng.uniform(-0.15, 0.15)))
    path = []
    n = 16
    for i in range(n + 1):
        t = i / n
        p = a.lerp(b, t)
        # (down, and back a little: once the upper body lies on its back
        # they droop to the floor)
        p += Vector((0, -0.86, 0.5)) * depth * math.sin(math.pi * t) ** 0.8
        p += sway * math.sin(math.pi * t)
        path.append(p)
    return tube(path, radius, rng)


def rim_walls(rng, half, y, height, thick, sign):
    """The fat under the skin: a band just inside the box's edge (`half` = the
    footprint's half size), from y up (`sign` = 1: up, -1: down) `height`."""
    walls = []
    hx, hz = half
    for axis, length, at in ((0, hx, hz), (0, hx, -hz), (2, hz, hx), (2, hz, -hx)):
        wall = bmesh.new()
        bmesh.ops.create_cube(wall, size=1.0)
        bmesh.ops.subdivide_edges(wall, edges=wall.edges[:], cuts=6, use_grid_fill=True)
        for v in wall.verts:
            u, w, d = v.co.x, v.co.y, v.co.z
            yy = y + sign * (w + 0.5) * height
            depth = at - math.copysign(thick / 2, at) + d * thick
            if axis == 0:
                v.co = Vector((u * 2 * length * 0.99, yy, depth))
            else:
                v.co = Vector((depth, yy, u * 2 * length * 0.99))
        tear(wall, rng, y, 0.03)
        walls.append(wall)
    return bm_join_all(walls)


def rim_flaps(rng, half, y, down, count, size=(0.12, 0.34), length=(0.05, 0.26)):
    """Torn skin round a box's edge (footprint `half`), at height `y`: a
    ragged lip of skin all round, and uneven flaps of it hanging out and
    over the edge (`down` = the way they fall: (0, -1, 0) under the upper
    body, (0, 1, 0) folding up/out round a leg's top)."""
    hx, hz = half
    up = -down[1]
    # the lip: a thin ragged band just outside the edge, torn unevenly
    lip = rim_walls(rng, (hx + 0.012, hz + 0.012), 0.0, 0.05, 0.016, -up)
    for v in lip.verts:
        if abs(v.co.y) < 0.02:  # (its free edge: deeper tears here and there)
            v.co.y -= up * 0.04 * max(0.0, math.sin(v.co.x * 9.1 + v.co.z * 7.3) + rng.uniform(-0.3, 0.3))
    bmesh.ops.translate(lip, vec=Vector((0, y + up * 0.035, 0)), verts=lip.verts)
    flaps = [lip]
    perimeter = 4 * (hx + hz)
    for k in range(count):
        if rng.random() < 0.25:
            continue  # (torn off there)
        s = (k + rng.uniform(-0.4, 0.4)) / count * perimeter % perimeter
        if s < 2 * hx:
            base, out = Vector((-hx + s, y, -hz)), Vector((0, 0, -1))
        elif s < 2 * hx + 2 * hz:
            base, out = Vector((hx, y, -hz + (s - 2 * hx))), Vector((1, 0, 0))
        elif s < 4 * hx + 2 * hz:
            base, out = Vector((hx - (s - 2 * hx - 2 * hz), y, hz)), Vector((0, 0, 1))
        else:
            base, out = Vector((-hx, y, hz - (s - 4 * hx - 2 * hz))), Vector((-1, 0, 0))
        base.x = max(-hx, min(hx, base.x)) * 1.005
        base.z = max(-hz, min(hz, base.z)) * 1.005
        base.y += rng.uniform(-0.02, 0.03) * up
        # (not all straight out: twisted a little)
        turn = rng.uniform(-0.45, 0.45)
        out = Vector((out.x * math.cos(turn) - out.z * math.sin(turn), rng.uniform(-0.2, 0.3) * -up,
                      out.x * math.sin(turn) + out.z * math.cos(turn)))
        flaps.append(flap(rng, base, out, down, rng.uniform(*size), rng.uniform(*length), rng.uniform(0.6, 2.2)))
    return bm_join_all(flaps)


def floor_plate(half, y, thick, rng):
    out = bmesh.new()
    bmesh.ops.create_cube(out, size=1.0)
    bmesh.ops.subdivide_edges(out, edges=out.edges[:], cuts=8, use_grid_fill=True)
    for v in out.verts:
        v.co = Vector((v.co.x * 2 * half[0] * 0.985, y + v.co.y * thick, v.co.z * 2 * half[1] * 0.985))
    return lumpy(out, rng, 0.012, 8.0)


WAIST_FOLD = 0.93  # how much of the box's footprint the anatomy is widened to


def section(bm, plane_y, up, sag, rng, rough, grow=0.0):
    """The real cross-section of a mesh at `plane_y` (its outline: Z-Anatomy's
    shape there), made a solid plug: from a little inside the body (`up`
    side) out to `sag` past the plane (the cut flesh bulging out), its outer
    face roughened (`rough`), its outline pushed out by `grow` (the gaps
    between muscles closed up: they swell once cut). None when the plane
    misses it."""
    work = bm.copy()
    geom = work.verts[:] + work.edges[:] + work.faces[:]
    res = bmesh.ops.bisect_plane(work, geom=geom, dist=1e-6, plane_co=(0, plane_y, 0), plane_no=(0, 1, 0))
    edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    if len(edges) < 3:
        work.free()
        return None
    out = bmesh.new()
    index = {}
    for e in edges:
        for v in e.verts:
            if v not in index:
                index[v] = out.verts.new((v.co.x, plane_y, v.co.z))
    for e in edges:
        a, b = index[e.verts[0]], index[e.verts[1]]
        if a is not b and out.edges.get((a, b)) is None:
            out.edges.new((a, b))
    work.free()
    bmesh.ops.remove_doubles(out, verts=out.verts[:], dist=1e-4)
    filled = bmesh.ops.triangle_fill(out, use_beauty=True, use_dissolve=False, edges=out.edges[:], normal=(0, 1, 0))
    faces = [f for f in filled["geom"] if isinstance(f, bmesh.types.BMFace)]
    if not faces:
        out.free()
        return None
    # (loose edges the fill didn't use: gone)
    bmesh.ops.delete(out, geom=[e for e in out.edges if not e.link_faces], context="EDGES")
    if grow:
        push = {}
        for e in out.edges:
            if len(e.link_faces) != 1:
                continue
            a, b = e.verts
            n = Vector((b.co.z - a.co.z, 0, a.co.x - b.co.x))
            if n.length < 1e-9:
                continue
            n.normalize()
            if n.dot(e.link_faces[0].calc_center_median() - (a.co + b.co) / 2) > 0:
                n = -n
            for v in (a, b):
                push[v] = push.get(v, Vector()) + n
        for v, n in push.items():
            if n.length > 1e-9:
                v.co += n.normalized() * grow
    return extrude_plug(out, plane_y, up, sag, rng, rough)


def extrude_plug(out, plane_y, up, sag, rng, rough):
    """A flat outline (filled faces in X-Z) made a solid plug: from a little
    inside the body (`up` side) out to `sag` past the plane, its outer face
    roughened (`rough`)."""
    for v in out.verts:
        v.co.y = plane_y + up * 0.04
    ext = bmesh.ops.extrude_face_region(out, geom=out.faces[:])
    cap = [v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)]
    phase = [rng.uniform(0, 6.3) for _ in range(3)]
    for v in cap:
        bulge = math.sin(v.co.x * 17 + phase[0]) * math.sin(v.co.z * 13 + phase[1])
        v.co.y = plane_y - up * (sag + rough * (0.7 * bulge + 0.3 * math.sin((v.co.x - v.co.z) * 37 + phase[2])))
    bmesh.ops.recalc_face_normals(out, faces=out.faces[:])
    return orient_plug(out, plane_y, up)


def orient_plug(bm, plane_y, up):
    """The cap out of the cut and the base inside face their own ways, even
    where the outline crosses itself and the normals' recalculation can't
    tell (Roblox shows one side only)."""
    bm.normal_update()
    for face in bm.faces:
        out = [(plane_y - v.co.y) * up for v in face.verts]
        cap_wrong = min(out) > 0.005 and face.normal.y * up > 0  # (the cap: away from the body)
        base_wrong = max(out) < -0.02 and face.normal.y * up < 0  # (the base: into it)
        if cap_wrong or base_wrong:
            face.normal_flip()
    bm.normal_update()
    return bm


def sharp_split(bm, angle=50.0):
    """The edges sharper than `angle` split (their vertices doubled): the
    flat cut face of each plug shaded flat, not rounded off into its walls
    (every gore face is exported smooth)."""
    bm.normal_update()
    limit = math.cos(math.radians(angle))
    sharp = [e for e in bm.edges if len(e.link_faces) == 2
             and e.link_faces[0].normal.dot(e.link_faces[1].normal) < limit]
    if sharp:
        bmesh.ops.split_edges(bm, edges=sharp)
    bm.normal_update()
    return bm


def _raster(bm, xs, zs, up):
    """The cells (cell centres `xs` x `zs`) under a plug's cap (its faces
    looking out of the cut), a boolean grid [z, x]."""
    mask = np.zeros((len(zs), len(xs)), bool)
    work = bm.copy()
    bmesh.ops.triangulate(work, faces=work.faces[:])
    work.normal_update()
    step_x, step_z = xs[1] - xs[0], zs[1] - zs[0]
    for f in work.faces:
        if f.normal.y * up > -0.3:
            continue
        (ax, az), (bx, bz), (cx, cz) = [(v.co.x, v.co.z) for v in f.verts]
        i0 = max(0, math.floor((min(ax, bx, cx) - xs[0]) / step_x))
        i1 = min(len(xs) - 1, math.ceil((max(ax, bx, cx) - xs[0]) / step_x))
        j0 = max(0, math.floor((min(az, bz, cz) - zs[0]) / step_z))
        j1 = min(len(zs) - 1, math.ceil((max(az, bz, cz) - zs[0]) / step_z))
        if i1 < i0 or j1 < j0:
            continue
        px, pz = np.meshgrid(xs[i0:i1 + 1], zs[j0:j1 + 1])
        d = (bz - cz) * (ax - cx) + (cx - bx) * (az - cz)
        if abs(d) < 1e-12:
            continue
        l1 = ((bz - cz) * (px - cx) + (cx - bx) * (pz - cz)) / d
        l2 = ((cz - az) * (px - cx) + (ax - cx) * (pz - cz)) / d
        inside = (l1 >= 0) & (l2 >= 0) & (l1 + l2 <= 1)
        mask[j0:j1 + 1, i0:i1 + 1] |= inside
    work.free()
    return mask


def _region_outline(mask, xs, zs, plane_y, spacing):
    """A region of the grid as a flat filled outline (bmesh at `plane_y`):
    its edge smoothed (no staircase), holes kept (the bone through it)."""
    from contourpy import LineType, contour_generator
    from scipy.ndimage import gaussian_filter

    pad = 3
    z = gaussian_filter(np.pad(mask.astype(float), pad), 0.9)
    step_x, step_z = xs[1] - xs[0], zs[1] - zs[0]
    gx = xs[0] + (np.arange(z.shape[1]) - pad) * step_x
    gz = zs[0] + (np.arange(z.shape[0]) - pad) * step_z
    lines = contour_generator(gx, gz, z, line_type=LineType.Separate).lines(0.42)
    bm = bmesh.new()
    for line in lines:
        pts = [line[0]]
        for q in line[1:]:
            if np.hypot(*(q - pts[-1])) >= spacing:
                pts.append(q)
        if len(pts) > 2 and np.hypot(*(pts[-1] - pts[0])) < spacing * 0.5:
            pts.pop()
        if len(pts) < 4:
            continue
        a = np.array(pts)
        area = 0.5 * abs(np.dot(a[:, 0], np.roll(a[:, 1], 1)) - np.dot(a[:, 1], np.roll(a[:, 0], 1)))
        if area < 4 * step_x * step_z:
            continue
        vs = [bm.verts.new((float(x), plane_y, float(zz))) for x, zz in pts]
        for i in range(len(vs)):
            bm.edges.new((vs[i], vs[(i + 1) % len(vs)]))
    if len(bm.edges) < 3:
        bm.free()
        return None
    filled = bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=bm.edges[:], normal=(0, 1, 0))
    if not [f for f in filled["geom"] if isinstance(f, bmesh.types.BMFace)]:
        bm.free()
        return None
    bmesh.ops.delete(bm, geom=[e for e in bm.edges if not e.link_faces], context="EDGES")
    return bm


def fill_footprint(rng, out, centre, half, plane_y, up, step=0.02):
    """The cut face filled with meat, wall to wall: the real sections of the
    muscles and the gut kept where they are, every empty bit of the R6
    footprint between them given to the nearest one (they swell and spread
    once cut, nothing left bare but the bone), each made a flat plug.
    Neighbours get different colours ("muscle" / "muscle_dark") so the
    muscles read apart. Returns `out` with its "muscle" / "gut" replaced
    and "muscle_dark" added."""
    from scipy.ndimage import distance_transform_edt

    hx, hz = half[0] * 0.995, half[1] * 0.995
    xs = np.arange(centre[0] - hx + step / 2, centre[0] + hx, step)
    zs = np.arange(centre[1] - hz + step / 2, centre[1] + hz, step)
    bone = np.zeros((len(zs), len(xs)), bool)
    for _name, plug in out.get("bone", []):
        bone |= _raster(plug, xs, zs, up)
    soft = [(g, name, plug) for g in ("muscle", "gut") for name, plug in out.get(g, [])]
    labels = np.full(bone.shape, -1, int)
    for k, (_g, _name, plug) in enumerate(soft):
        m = _raster(plug, xs, zs, up) & (labels < 0)
        labels[m] = k
    if not soft or (labels < 0).all():
        return out
    _d, (iz, ix) = distance_transform_edt(labels < 0, return_indices=True)
    labels = labels[iz, ix]
    labels[bone] = -1
    # neighbours (shared border length) for the colours
    touch = {}
    for a, b in ((labels[:, 1:], labels[:, :-1]), (labels[1:, :], labels[:-1, :])):
        diff = (a != b) & (a >= 0) & (b >= 0)
        for p, q in zip(a[diff], b[diff]):
            key = (min(p, q), max(p, q))
            touch[key] = touch.get(key, 0) + 1
    sizes = np.bincount(labels[labels >= 0], minlength=len(soft))
    shade = {}
    for k in np.argsort(-sizes):
        cost = [0, 0]
        for (p, q), n in touch.items():
            other = q if p == k else p if q == k else None
            if other is not None and other in shade:
                cost[shade[other]] += n
        shade[k] = 0 if cost[0] <= cost[1] else 1
    for g in ("muscle", "gut"):
        for _name, plug in out.get(g, []):
            plug.free()
    new = {g: list(v) for g, v in out.items() if g not in ("muscle", "gut")}
    m = 0.995
    cx, cz = centre
    for k, (group, name, _plug) in enumerate(soft):
        if sizes[k] < 3:
            continue
        flat = _region_outline(labels == k, xs, zs, plane_y, step * 1.6)
        if flat is None:
            continue
        sag = {"muscle": rng.uniform(0.04, 0.09), "gut": rng.uniform(0.06, 0.12)}[group]
        if up < 0:
            sag = 0.03 + sag * 0.35
        plug = extrude_plug(flat, plane_y, up, sag, rng, 0.004)
        cut(plug, [((cx + half[0] * m, 0, 0), (1, 0, 0)), ((cx - half[0] * m, 0, 0), (-1, 0, 0)),
                   ((0, 0, cz + half[1] * m), (0, 0, 1)), ((0, 0, cz - half[1] * m), (0, 0, -1))], fill=True)
        orient_plug(plug, plane_y, up)
        if len(plug.faces) < 4:
            plug.free()
            continue
        key = "gut" if group == "gut" else ("muscle", "muscle_dark")[shade[k]]
        new.setdefault(key, []).append((name, plug))
    return new


def cut_face(rng, anatomy, centre, half, plane_y, up, select, side=0):
    """The cut through the body, one side of it: each Z-Anatomy object cut
    by the plane (`up` = +1: the upper body, the face looking down; -1: a
    leg, the face looking up), widened to the R6 footprint (`half`, round
    `centre` in X-Z): its real cross-section there made a solid plug (cut
    bone: solid white; muscle: its meat), each bulging out of the plane by
    its own amount (flesh sags out, bone doesn't). `select(name, v)` ->
    whether to keep an object; `side` (+1 / -1): only that half of the body
    (X > 0 / X < 0: a leg's). Returns {group: [(name, bmesh)]}."""
    pts = np.concatenate([v[np.abs(v[:, 1] - plane_y) < 0.08] for g in ("bone", "muscle", "gut")
                          for name, v, _f in anatomy[g] if select(name, v)])
    if side:
        pts = pts[pts[:, 0] * side > 0]
    reach = outline(pts, centre)
    hx, hz = half
    cx, cz = centre

    def squarified(c):
        probe = bmesh.new()
        probe.verts.new(c)
        squarify(probe, centre, (hx * WAIST_FOLD, hz * WAIST_FOLD), reach, 1.0)
        probe.verts.ensure_lookup_table()
        at = probe.verts[0].co.copy()
        probe.free()
        return at

    if side:
        near = np.concatenate([v[(np.abs(v[:, 1] - plane_y) < 0.06) & (v[:, 0] * side > 0)]
                               for name, v, _f in anatomy["bone"] if select(name, v)])
        bone_c = Vector(near.mean(0))
        bone_at = squarified(bone_c)
    out = {}
    for group in ("bone", "muscle", "gut", "vessel"):
        for name, v, f in anatomy[group]:
            if not select(name, v):
                continue
            bm = bm_of(v, f)
            if side:  # (the hips split down the middle)
                cut(bm, [((0, 0, 0), (-side, 0, 0))], fill=False)
                if len(bm.faces) < 4:
                    bm.free()
                    continue
            if group == "vessel":
                # (thin: moved with the flesh round it, not stretched; thicker
                # so it shows)
                c = sum((x.co for x in bm.verts), Vector()) / len(bm.verts)
                moved = squarified(c) - c
                bmesh.ops.translate(bm, vec=Vector((moved.x, 0, moved.z)), verts=bm.verts)
                thicken(bm, 1.7)
            elif group == "bone" and side:
                # (a leg's bones: moved together, kept their shape - the round
                # femoral head in its socket)
                for x in bm.verts:
                    x.co.x = bone_at.x + (x.co.x - bone_c.x) * 1.15
                    x.co.z = bone_at.z + (x.co.z - bone_c.z) * 1.15
            else:
                squarify(bm, centre, (hx * WAIST_FOLD, hz * WAIST_FOLD), reach, 1.0)
            sag = {"bone": rng.uniform(0.02, 0.04), "muscle": rng.uniform(0.03, 0.11),
                   "gut": rng.uniform(0.05, 0.12), "vessel": rng.uniform(0.1, 0.2)}[group]
            if up < 0:  # (a leg's top, facing up: it doesn't hang out as much)
                sag = 0.02 + sag * 0.4 if group != "vessel" else sag
            rough = {"bone": 0.0015, "muscle": 0.003, "gut": 0.003, "vessel": 0.002}[group]
            grow = {"bone": 0.0, "muscle": 0.03, "gut": 0.01, "vessel": 0.0}[group]
            plug = section(bm, plane_y, up, sag, rng, rough, grow)
            bm.free()
            if plug is None:
                continue
            m = 0.995
            cut(plug, [((cx + hx * m, 0, 0), (1, 0, 0)), ((cx - hx * m, 0, 0), (-1, 0, 0)),
                       ((0, 0, cz + hz * m), (0, 0, 1)), ((0, 0, cz - hz * m), (0, 0, -1))], fill=True)
            orient_plug(plug, plane_y, up)
            if len(plug.faces) >= 4:
                out.setdefault(group, []).append((name, plug))
    return fill_footprint(rng, out, centre, half, plane_y, up)


def waist_cut(rng):
    """Dr. Rift's finisher: the two faces of the cut, built from the real
    anatomy of the hips (anatomy/waist.npz). Returns (waist, hip_r, hip_l),
    each {layer: bmesh}:
      waist   R6 torso space (2 x 2 x 1), the face under the upper body
              (Y = -1), hanging down a little
      hip_r   R6 right leg space (1 x 2 x 1), the face on its top (Y = 1)
      hip_l   the left leg's"""
    anatomy = load_waist()

    def layers(parts, half, plane_y, up, centre):
        # (neighbouring muscles in alternating colours: fill_footprint)
        out = {
            "Muscle": bm_join_all([bm for _n, bm in parts.get("muscle", [])]),
            "MuscleDark": bm_join_all([bm for _n, bm in parts.get("muscle_dark", [])]),
            "Bone": bm_join_all([bm for _n, bm in parts.get("bone", [])]),
            "Gut": bm_join_all([bm for _n, bm in parts.get("gut", [])]),
            "Vessel": bm_join_all([bm for _n, bm in parts.get("vessel", [])]),
        }
        # the dark floor of the cut (nothing see-through between the parts)
        floor = floor_plate(half, 0.0, 0.012, rng)
        bmesh.ops.translate(floor, vec=Vector((centre[0], plane_y - up * 0.008, centre[1])), verts=floor.verts)
        out["FleshDark"] = floor
        fat = rim_walls(rng, (half[0] * 0.985, half[1] * 0.985), 0.0, 0.07, 0.07, up)
        bmesh.ops.translate(fat, vec=Vector((centre[0], plane_y - up * 0.04, centre[1])), verts=fat.verts)
        out["Fat"] = fat
        return out

    # ---- the upper body's face (torso space, its bottom at Y = -1)
    upper = cut_face(rng, anatomy, (0.0, 0.0), (1.0, 0.5), -1.0, 1,
                     lambda name, v: (v[:, 1] > -1.0).any())
    waist = layers(upper, (1.0, 0.5), -1.0, 1, (0.0, 0.0))
    # loops of small intestine hanging out of it (the belly's front half)
    loops = []
    for _ in range(4):
        a = Vector((rng.uniform(-0.55, 0.55), -1.02, rng.uniform(-0.38, 0.05)))
        b = a + Vector((rng.uniform(-0.35, 0.35), 0, rng.uniform(-0.12, 0.2)))
        b.z = max(-0.42, min(0.3, b.z))
        loops.append(hanging_loop(rng, a, b, rng.uniform(0.3, 0.9), rng.uniform(0.05, 0.065)))
    # the lowest loops of the small intestine (just over the cut), slumping
    # out of it
    for name, v, f in anatomy["gut"]:
        if name == "Jejunum":
            spill = bm_of(v, f)
            squarify(spill, (0.0, 0.0), (WAIST_FOLD, 0.5 * WAIST_FOLD), outline(v, (0.0, 0.0)), 0.9)
            cut(spill, [((0, -0.82, 0), (0, 1, 0))], fill=True)
            bmesh.ops.translate(spill, vec=Vector((0, -0.2, 0)), verts=spill.verts)
            loops.append(spill)
    waist["Gut"] = bm_join_all([waist["Gut"]] + loops)
    waist["Skin"] = rim_flaps(rng, (1.0, 0.5), -1.0, (0, -1, 0), 24)

    # ---- each leg's top (its own space: 1 x 2 x 1, its top at Y = 1)
    def leg(side, leg_rng):
        # the leg's half of the body: X > 0 is the right (torso space); the
        # hips split down the middle
        cx = 0.5 * side
        parts = cut_face(leg_rng, anatomy, (cx, 0.0), (0.5, 0.5), -1.0, -1,
                         lambda name, v: (v[:, 1] < -1.0).any() and (v[:, 0] * side > 0.02).any(), side)
        top = layers(parts, (0.5, 0.5), -1.0, -1, (cx, 0.0))
        top["Skin"] = rim_flaps(leg_rng, (0.5, 0.5), -1.0, (0, 1, 0), 12, (0.14, 0.26), (0.08, 0.18))
        bmesh.ops.translate(top["Skin"], vec=Vector((cx, 0, 0)), verts=top["Skin"].verts)
        for bm in top.values():  # torso space -> the leg's (its top at Y = 1)
            bmesh.ops.translate(bm, vec=Vector((-cx, 2.0, 0)), verts=bm.verts)
        return top

    hip_r = leg(1, random.Random(rng.randrange(1 << 30)))
    hip_l = leg(-1, random.Random(rng.randrange(1 << 30)))
    for piece in (waist, hip_r, hip_l):
        for layer, bm in piece.items():
            if layer != "Skin":
                sharp_split(bm)
    return waist, hip_r, hip_l


def gut_lengths(rng):
    """Loose loops of the real small intestine (Z-Anatomy's jejunum and
    ileum, anatomy/waist.npz), torn in three, each 1 to 2 studs, centred, a
    torn end trailing; the first with a strip of its mesentery (Fat, its
    vessels: Vessel)."""
    scale = 1.7  # (the real coil, a little bigger: 1 to 2 studs each)
    _name, v, f = load_waist()["jejunum"][0]
    whole = bm_of(v * scale, f)
    seeds = [Vector((-0.35, 0.2, 0)), Vector((0.4, 0.15, 0)), Vector((0.0, -0.35, 0))]
    out = []
    for i in range(len(seeds)):
        part = cut(bm_copy(whole), cell_planes([s * scale for s in seeds], i), fill=True)
        c = sum((x.co for x in part.verts), Vector()) / max(1, len(part.verts))
        bmesh.ops.translate(part, vec=-c, verts=part.verts)
        lo = Vector([min(x.co[k] for x in part.verts) for k in range(3)])
        hi = Vector([max(x.co[k] for x in part.verts) for k in range(3)])
        # a torn end trailing out of the coil
        start = Vector((hi.x * 0.7, rng.uniform(lo.y, hi.y) * 0.5, 0))
        bend = rng.uniform(-1.0, 1.0)
        path = [start + Vector((0.07 * k, -0.012 * k * k, 0.05 * math.sin(k * 0.8 + bend))) for k in range(9)]
        layers = {"Gut": bm_join_all([part, tube(path, 0.075, rng, 9)])}
        if i == 0:
            strip = flap(rng, (lo.x * 0.5, hi.y * 0.6, 0), (1, -0.3, 0), (0, -1, 0.2), 0.22, 0.5, 0.9)
            layers["Fat"] = strip
            layers["Vessel"] = bm_join_all([
                rod((lo.x * 0.5 + 0.1 * k, hi.y * 0.6, 0.03), (lo.x * 0.5 + 0.12 * k + 0.1, hi.y * 0.3, 0.03), 0.012, 0.008, 5)
                for k in range(3)
            ])
        # (centred on its bounding box: it spawns where it is meant to)
        allv = [x.co for bm in layers.values() for x in bm.verts]
        mid = Vector([(min(c[k] for c in allv) + max(c[k] for c in allv)) / 2 for k in range(3)])
        for bm in layers.values():
            bmesh.ops.translate(bm, vec=-mid, verts=bm.verts)
        out.append(layers)
    whole.free()
    return out


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
