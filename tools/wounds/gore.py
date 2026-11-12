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
    kinds = {k: [] for k in ("skull", "brain", "eye", "tooth", "splat", "streak", "pool", "organ", "limb")}

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
