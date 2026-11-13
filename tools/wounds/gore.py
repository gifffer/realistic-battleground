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
             Y = -1), worked out cell by cell (paint_face): the real cut
             through the hip joints - hip bones and sacrum in section, a
             white rim (Bone) round the spongy core (Marrow); the muscles cut,
             domed (Muscle / MuscleDark alternating), fascia between them
             (Fascia); the belly's front packed with loops of small
             intestine cut across (bowel_rings: wall Gut, lining Mucosa,
             contents Chyme) in their fat; the bladder and the colon cut
             across, whole rings side by side (gut_sections): wall (Gut),
             lining (Mucosa), contents (Urine / Lumen); the arteries and
             veins as open tubes (Artery, Vein), an artery's lumen open and
             red (Blood), a vein's clotted (Clot); the sciatic, femoral and
             obturator nerves (Nerve); the fat under the skin in lobules
             (Fat); torn skin at the edge (Skin); drops of blood hanging
             (Blood); two loops of small intestine hanging out (Gut, its
             torn lining: Mucosa) on their mesentery (Mesentery, its
             vessels: Vessel); a dark floor (FleshDark). All of it stands
             proud of the part's face.
  HipR / HipL  ...on each leg's top (R6 leg space: 1 x 2 x 1, its top at
             Y = 1): a real section of the upper thigh (waist.npz's
             "thigh" slab): the femur's shaft (a thick ring of Bone round
             its Marrow), the quadriceps, adductors, hamstrings, sartorius
             and gracilis, the femoral artery and vein side by side, the
             deep femoral ones, the great saphenous vein, the sciatic
             nerve, fat, skin, blood pooled round the artery (same layers)
  Gut<i>     loose lengths of small intestine lying folded in hairpin
             loops side by side, fanning out (Gut, torn ends: Mucosa),
             slightly constricted here and there, on their torn mesentery
             (Mesentery, Vessel), a torn end trailing, smeared with blood
             (Blood: a skin of it a hair over the wall), centred: they fall
             out of the upper body
  Colon      a torn length of the sigmoid colon (Colon: puckered pouches
             between three bands; Fat: a few small smooth blobs of fat
             lying flat on it; Blood smeared on it; torn ends: Mucosa,
             Lumen), centred: it falls out too
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
    "Vessel": (0.33, 0.05, 0.12),
    # (Dr. Rift's cut: the inside of the body in section)
    "Fascia": (0.80, 0.74, 0.70),
    "Marrow": (0.55, 0.26, 0.18),
    "Mucosa": (0.55, 0.15, 0.16),
    "Lumen": (0.24, 0.17, 0.08),
    "Urine": (0.80, 0.62, 0.20),
    "Artery": (0.80, 0.56, 0.52),
    "Vein": (0.22, 0.13, 0.28),
    "Clot": (0.14, 0.01, 0.02),
    "Nerve": (0.92, 0.88, 0.76),
    "Mesentery": (0.88, 0.76, 0.52),
    "Colon": (0.74, 0.58, 0.50),
    "Chyme": (0.62, 0.52, 0.2),
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


def skirt(rng, y, up, inset, length, flare, thickness, count=56, spikes=9):
    """A torn band round the edge of the torso's bottom face (the skin, the
    fat under it): from y, going down (up = -1) or up (up = 1), its end
    ragged - long torn tongues here and there - and curling out."""
    phases = [rng.uniform(0, 6.3) for _ in range(4)]
    tongues = [(rng.random(), rng.uniform(0.6, 1.6), rng.uniform(0.008, 0.02)) for _ in range(spikes)]
    rows = 4
    bm = bmesh.new()
    grid = []
    for k in range(count):
        s = k / count
        base, out = perimeter(s, inset)
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
        if f.normal.dot(Vector((mid.x, 0, mid.z * 2))) < 0:
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
        for k in ("skull", "brain", "eye", "tooth", "splat", "streak", "pool", "organ", "limb", "bisect", "gut", "cut")
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

    # Dr. Rift's finisher: the body cut in two at the waist. (Last again,
    # their own random numbers: nothing above moves.)
    waist, hip_r, hip_l = waist_cut(random.Random(9393))
    piece("RiftWaist", waist, "cut")
    piece("RiftHipR", hip_r, "cut")
    piece("RiftHipL", hip_l, "cut")
    for i, layers in enumerate(gut_lengths(random.Random(9494))):
        piece(f"RiftGut{i + 1}", layers, "cut")
    piece("RiftColon", colon_length(random.Random(9595)), "cut")
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


def rim_flaps(rng, half, y, down, count, size=(0.12, 0.34), length=(0.05, 0.26), curl=(0.6, 2.2)):
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
        flaps.append(flap(rng, base, out, down, rng.uniform(*size), rng.uniform(*length), rng.uniform(*curl)))
    return bm_join_all(flaps)


def floor_plate(half, y, thick, rng):
    out = bmesh.new()
    bmesh.ops.create_cube(out, size=1.0)
    bmesh.ops.subdivide_edges(out, edges=out.edges[:], cuts=8, use_grid_fill=True)
    for v in out.verts:
        v.co = Vector((v.co.x * 2 * half[0] * 0.985, y + v.co.y * thick, v.co.z * 2 * half[1] * 0.985))
    return lumpy(out, rng, 0.012, 8.0)


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


# ---- the faces of the cut, worked out cell by cell ----
#
# Each face is laid out on a fine grid (STEP studs) over the R6 part's
# footprint: the real sections of the bones, muscles and gut (Z-Anatomy, cut
# by the plane and widened to the box) say which cell is what; the empty
# cells between them go to the nearest muscle; a band round the edge is the
# fat under the skin. Then every region is made its own solid plug, shaped by
# a height field (how far it bulges out of the cut):
#   - a cut muscle swells out, domed, its surface grained by its bundles
#     (fascicles), thin pearly lines of fascia between neighbours;
#   - a cut bone shows its hard white rim (cortical bone) round a pitted,
#     reddish spongy core (cancellous bone, marrow);
#   - the colon and the bladder are rings: their wall, the red lining
#     (mucosa) inside it, and what was in them (dark: the colon's; amber:
#     urine) sunk a little;
#   - the arteries and veins are short tubes sticking out, open, their dark
#     clotted lumen showing (an artery's wall thick and pale, a vein's thin,
#     dark, collapsed); the big nerves white cords;
#   - the fat under the skin in yellow lobules.

FOLD = (0.9, 0.8)  # how much of the box's footprint (X, Z) the anatomy is widened to (the rest: the fat)
STEP = 0.0125  # studs: the grid the faces are worked out on


def noise2(rng, cell):
    """A smooth random field over X-Z (about -1..1), its features about
    `cell` studs across: f(x, z) on arrays."""
    from scipy.ndimage import map_coordinates

    n = 64
    grid = np.array([[rng.uniform(-1, 1) for _ in range(n)] for _ in range(n)])
    ox, oz = rng.uniform(0, n), rng.uniform(0, n)

    def f(x, z):
        return 1.6 * map_coordinates(grid, [np.asarray(z, float) / cell + oz, np.asarray(x, float) / cell + ox],
                                     order=3, mode="grid-wrap")

    return f


def ridges(f):
    """A noise field folded into cells (bumps between thin creases: the
    bundles of a cut muscle, the lobules of fat): -1 (crease) .. 1."""
    return lambda x, z: 1 - 2 * np.clip(np.abs(f(x, z)), 0, 1)


def sampler(grid, xs, zs):
    """A grid [z, x] (cell centres `xs` x `zs`) read at any (x, z) arrays."""
    from scipy.ndimage import map_coordinates

    def at(x, z):
        return map_coordinates(grid, [(np.asarray(z, float) - zs[0]) / (zs[1] - zs[0]),
                                      (np.asarray(x, float) - xs[0]) / (xs[1] - xs[0])], order=1, mode="nearest")

    return at


def refine(bm, longest):
    """A flat fill's long triangles split until no edge is longer than
    `longest` (so a height field can shape it)."""
    for _ in range(8):
        long = [e for e in bm.edges if e.calc_length() > longest]
        if not long:
            break
        bmesh.ops.subdivide_edges(bm, edges=long, cuts=1)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.beautify_fill(bm, faces=bm.faces[:], edges=[e for e in bm.edges if not e.is_boundary])
    return bm


def mask_plug(mask, xs, zs, plane_y, up, height, longest=0.05, spacing=STEP * 1.5):
    """A region of the grid (`mask` [z, x]) made a solid plug out of the cut:
    its outline smoothed, its cap shaped by `height(x, z)` (studs out of the
    plane, on arrays), its sides going a little into the body (no base: it is
    inside the part). None when there is nothing."""
    if mask.sum() < 3:
        return None
    flat = _region_outline(mask, xs, zs, plane_y, spacing)
    if flat is None:
        return None
    refine(flat, longest)
    for v in flat.verts:
        v.co.y = plane_y + up * 0.04
    ext = bmesh.ops.extrude_face_region(flat, geom=flat.faces[:])
    cap = [v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)]
    hs = height(np.array([v.co.x for v in cap]), np.array([v.co.z for v in cap]))
    for v, h in zip(cap, hs):
        v.co.y = plane_y - up * max(0.006, float(h))
    bmesh.ops.recalc_face_normals(flat, faces=flat.faces[:])
    orient_plug(flat, plane_y, up)
    base = [f for f in flat.faces if all(abs(v.co.y - (plane_y + up * 0.04)) < 1e-5 for v in f.verts)]
    bmesh.ops.delete(flat, geom=base, context="FACES_ONLY")
    return flat if len(flat.faces) >= 3 else None


def split_faces(bm, tags):
    """A bmesh whose faces are tagged (`tags[i]`: face i's layer) split into
    one bmesh per tag: {tag: bmesh}."""
    out = {}
    for tag in set(tags):
        part = bm.copy()
        part.faces.ensure_lookup_table()
        bmesh.ops.delete(part, geom=[part.faces[i] for i, t in enumerate(tags) if t != tag], context="FACES")
        out[tag] = part
    bm.free()
    return out


def vessel_stub(rng, centre, radius, plane_y, up, length, artery):
    """A cut artery or vein: a short tube out of the cut at `centre` (X, Z),
    open, a little bent, its end torn a bit unevenly; inside, sunk, its
    lumen: an artery's open and full of bright blood (Blood), a vein's dark
    and clotted (Clot). An artery's wall is thick, a vein's thin and
    collapsed (flattened). Returns {layer: bmesh} ("Artery" / "Vein",
    "Blood" / "Clot")."""
    seg = 12
    flat = 1.0 if artery else rng.uniform(0.5, 0.65)
    wall = radius * (0.34 if artery else 0.16)
    turn = rng.uniform(0, 2 * math.pi)
    lean = Vector((math.cos(turn), 0, math.sin(turn))) * rng.uniform(0.1, 0.35)
    out = Vector((0, -up, 0))
    bm = bmesh.new()
    tags = []

    def ring(t, r, back=0.0, jag=0.0):
        c = Vector((centre[0], plane_y + up * 0.04, centre[1])) + (out * (length + 0.04) + lean * length * t * t) * t
        c -= out * back
        return [bm.verts.new(c + Vector((math.cos(2 * math.pi * k / seg) * r,
                                          rng.uniform(-jag, jag) if jag else 0.0,
                                          math.sin(2 * math.pi * k / seg) * r * flat))) for k in range(seg)]

    outer = [ring(0.0, radius), ring(0.5, radius * 1.03), ring(1.0, radius, jag=radius * 0.15)]
    inner_r = radius - wall
    lip = ring(1.0, inner_r)
    deep = ring(1.0, inner_r * 0.92, back=radius * (0.45 if artery else 0.9))

    def band(a, b, tag):
        for k in range(seg):
            j = (k + 1) % seg
            bm.faces.new((a[k], a[j], b[j], b[k]))
            tags.append(tag)

    wall_tag = "Artery" if artery else "Vein"
    band(outer[0], outer[1], wall_tag)
    band(outer[1], outer[2], wall_tag)
    band(outer[2], lip, wall_tag)
    lumen = "Blood" if artery else "Clot"
    band(lip, deep, lumen)
    bottom = bm.verts.new(sum((v.co for v in deep), Vector()) / seg - out * radius * 0.2)
    for k in range(seg):
        bm.faces.new((deep[k], deep[(k + 1) % seg], bottom))
        tags.append(lumen)
    # lip at the torn end: matched to the outer ring's jagged heights
    for a, b in zip(outer[2], lip):
        b.co.y = a.co.y
    bm.normal_update()
    # (outward: the outer wall's normals away from the axis)
    bm.faces.ensure_lookup_table()
    f0 = bm.faces[0]
    radial = f0.calc_center_median() - Vector((centre[0], f0.calc_center_median().y, centre[1]))
    if f0.normal.dot(radial) < 0:
        for f in bm.faces:
            f.normal_flip()
    bm.normal_update()
    return split_faces(bm, tags)


def drop(rng, at, size, down):
    """A drop of blood hanging from `at` (a teardrop, stretched `down`)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=5, radius=1.0)
    down = Vector(down).normalized()
    for v in bm.verts:
        t = v.co.dot(Vector((0, -1, 0)))  # (1 at the bottom)
        r = size * (0.55 + 0.45 * max(0.0, t))
        v.co = Vector((v.co.x * r, 0, v.co.z * r)) + down * (size * 1.4 * (t + 1) * (1 + rng.uniform(0, 0.6)))
        v.co += Vector(at)
    bm.normal_update()
    return bm


def gut_sections(found, X, Z, keep_off, least=0.085):
    """The gut cut across (`found`: [(name, its cells)], the bladder first):
    each section a whole ring at least `least` stud in radius (the colon,
    squeezed thin by the widening to the R6 part, would be a crescent with no
    room for its lining or what is in it: then it is made the oval it really
    is, on its middle, along its length, of its area), then moved the least
    it can off the ones before it and off `keep_off` (bone, the fat under the
    skin) - they lie side by side, not in one another. Returns [(name,
    cells)], the bladder first, each one its own."""
    from scipy.ndimage import distance_transform_edt

    step = float(X[0, 1] - X[0, 0])
    order = sorted(found, key=lambda f: ("bladder" not in f[0].lower(), -int(f[1].sum())))
    taken = keep_off.copy()
    out = []
    for name, m in order:
        count = int(m.sum())
        if count < 3:
            continue
        if distance_transform_edt(m, sampling=step).max() < least * 0.6:
            cx, cz = float(X[m].mean()), float(Z[m].mean())
            # (its long way: the cells' main axis)
            cov = np.cov(np.stack([X[m] - cx, Z[m] - cz]))
            w, v = np.linalg.eigh(cov)
            ax = v[:, 1]
            radius = max(least, math.sqrt(count * step * step / math.pi))
            aspect = min(1.3, math.sqrt(max(w[1], 1e-9) / max(w[0], 1e-9)))
            a, b = radius * math.sqrt(aspect), radius / math.sqrt(aspect)
            u = (X - cx) * ax[0] + (Z - cz) * ax[1]
            t = -(X - cx) * ax[1] + (Z - cz) * ax[0]
            ang = np.arctan2(t, u)
            wob = 1 + 0.06 * np.sin(3 * ang + count) + 0.04 * np.sin(5 * ang + 1.7 * count)
            m = (u / a) ** 2 + (t / b) ** 2 < wob ** 2
            count = int(m.sum())
        best = None
        for ring in range(0, 40):
            for k in range(max(1, ring * 6)):
                a = 2 * math.pi * k / max(1, ring * 6)
                dx, dz = int(round(math.cos(a) * ring)), int(round(math.sin(a) * ring))
                moved = np.roll(np.roll(m, dz, 0), dx, 1)
                if (dz > 0 and moved[:dz].any()) or (dz < 0 and moved[dz:].any()):
                    continue
                if (dx > 0 and moved[:, :dx].any()) or (dx < 0 and moved[:, dx:].any()):
                    continue
                if (moved & taken).sum() <= count * 0.03:
                    best = moved
                    break
            if best is not None:
                break
        m = (best if best is not None else m) & ~taken
        taken |= m
        out.append((name, m))
    return out


# The smallest a vessel / nerve of a thigh is drawn (radius, studs: real
# size at the R6 scale, a little more so it reads from a few studs away).
THIGH_TUBES = {"Femoral artery": 0.056, "Femoral vein": 0.064, "Deep femoral artery": 0.036,
               "Deep femoral vein": 0.04, "Great saphenous vein": 0.03, "Sciatic nerve": 0.05,
               "Saphenous nerve": 0.02}


def bowel_rings(rng, room, X, Z, step, least=0.05, most=0.085, gap=0.01):
    """Loops of small intestine cut across, packed into `room` (a grid mask):
    discs (a little oval, wobbly) as big as fit, a gap of fat between them.
    Returns [(centre x, z, radius, aspect, angle)]."""
    from scipy.ndimage import distance_transform_edt

    space = distance_transform_edt(room, sampling=step)
    rings = []
    cells = np.argwhere(space > least * 0.95)
    order = list(range(len(cells)))
    rng.shuffle(order)
    for i in order:
        j, k = cells[i]
        x, z = float(X[j, k]), float(Z[j, k])
        r = min(most, float(space[j, k]) + 0.01) * rng.uniform(0.88, 1.0)
        if r < least:
            continue
        if all(math.hypot(x - a, z - b) > r + c + gap for a, b, c, _q, _t in rings):
            rings.append((x, z, r, rng.uniform(1.0, 1.35), rng.uniform(0, math.pi)))
    return rings


def paint_face(rng, raw, centre, half, plane_y, up, bowel=False):
    """One face of the cut, from the real sections (`raw`: {group: [(name,
    plug)]}, cut_face) laid on the grid (see above); `bowel`: the belly's
    front filled with loops of small intestine cut across (bowel_rings), in
    their yellow fat. Returns {layer: [bmesh]} and where each artery's end
    is ({name: Vector})."""
    from scipy.ndimage import distance_transform_edt, label

    hx, hz = half
    cx, cz = centre
    xs = np.arange(cx - hx * 0.995 + STEP / 2, cx + hx * 0.995, STEP)
    zs = np.arange(cz - hz * 0.995 + STEP / 2, cz + hz * 0.995, STEP)
    X, Z = np.meshgrid(xs, zs)
    leg = up < 0

    def s(h):
        # (how far out of the part's face: all of it stands proud of it -
        # whatever is drawn flat on the part's face, a burn, a decal, stays
        # under; a leg's face, looking up, a little flatter)
        return 0.03 + h * 0.85 if leg else 0.02 + h

    out = {}
    ends = {}

    def add(layer, bm):
        if bm is not None and len(bm.faces) >= 3:
            out.setdefault(layer, []).append(bm)

    def edt(mask):
        return distance_transform_edt(mask, sampling=STEP)

    def swell(mask):
        # (how far into a region, softened: no ridge down its middle)
        from scipy.ndimage import gaussian_filter

        return gaussian_filter(edt(mask), 2.0)

    # the bones
    bones = [(name, _raster(plug, xs, zs, up)) for name, plug in raw.get("bone", [])]
    bone = np.zeros(X.shape, bool)
    for _name, m in bones:
        bone |= m
    # the fat under the skin: a band round the edge, thicker over the belly
    edge = np.minimum(hx - np.abs(X - cx), hz - np.abs(Z - cz))
    wob = noise2(rng, 0.1)
    thick = 0.062 + 0.012 * wob(X, Z) + 0.02 * (Z < cz)
    fat = (edge < thick) & ~bone
    # the soft parts: each piece of gut first (each made a whole ring, room
    # kept for it: see gut_sections), then each muscle, then every empty cell
    # given to the nearest (they swell once cut)
    guts = gut_sections([(name, _raster(plug, xs, zs, up)) for name, plug in raw.get("gut", [])],
                        X, Z, bone | fat)
    soft = [("gut", name, None) for name, _m in guts] + [("muscle", name, plug) for name, plug in raw.get("muscle", [])]
    labels = np.full(X.shape, -1, int)
    own = []
    for k, (_g, _name, plug) in enumerate(soft):
        m = guts[k][1] if plug is None else _raster(plug, xs, zs, up)
        own.append(m)
        labels[m & (labels < 0) & ~bone] = k
    if (labels >= 0).any():
        _d, (iz, ix) = distance_transform_edt(labels < 0, return_indices=True)
        labels = labels[iz, ix]
    labels[fat | bone] = -1
    # (round the gut only its own section is gut: the rest, the fat it lies in)
    for k, (g, _name, _plug) in enumerate(soft):
        if g == "gut":
            extra = (labels == k) & ~own[k]
            fat |= extra
            labels[extra] = -1
    # the belly's front: loops of small intestine cut across, in their fat
    # (the mesentery's): they push the muscles there aside
    loops = []
    if bowel:
        taken = bone | fat
        for k, (g, _name, _plug) in enumerate(soft):
            if g == "gut":
                taken |= own[k]
        room = ((Z < cz + 0.06) & (Z > cz - hz + 0.11) & (np.abs(X - cx) < hx * 0.66) & ~taken)
        loops = bowel_rings(rng, room, X, Z, STEP)
        labels[room] = -1
        fat |= room
    # where the vessels and nerves are (drawn last)
    tubes = []  # [group, name, i, cells or None, centre [x, z], radius]
    for group in ("vessel", "nerve"):
        for name, plug in raw.get(group, []):
            m = _raster(plug, xs, zs, up)
            parts, n = label(m)
            for i in range(1, n + 1):
                cells = parts == i
                count = int(cells.sum())
                if count < 3:
                    continue
                c = [float(X[cells].mean()), float(Z[cells].mean())]
                r = max(0.026, min(0.075, math.sqrt(count * STEP * STEP / math.pi)))
                least = THIGH_TUBES.get(name.rsplit(".", 1)[0]) if leg else None
                if least is not None:
                    if least <= 0.03 and group == "nerve":
                        continue  # (too thin to show)
                    r = max(r, least)
                    if group == "nerve":
                        cells = None  # (a big nerve: a round cord of its real size)
                tubes.append([group, name, i, cells, c, r])
    # (side by side, not in one another - the femoral vein hugs its artery -
    # nor in a bone)
    fixed = []
    for _name, m in bones:
        if m.any():
            fixed.append(([float(X[m].mean()), float(Z[m].mean())], float(edt(m).max()) * 1.15))
    for _ in range(40):
        moved = False
        for j, ta in enumerate(tubes):
            for tb in tubes[j + 1:]:
                dx, dz = tb[4][0] - ta[4][0], tb[4][1] - ta[4][1]
                dist = math.hypot(dx, dz)
                need = ta[5] + tb[5] + 0.012
                if dist < need:
                    if dist < 1e-6:
                        dx, dz, dist = 1.0, 0.0, 1.0
                    push = (need - dist) / 2
                    for t, k in ((ta, -1), (tb, 1)):
                        t[4][0] += k * dx / dist * push
                        t[4][1] += k * dz / dist * push
                        t[3] = None if t[0] == "nerve" else t[3]
                    moved = True
            for at, size in fixed:
                dx, dz = ta[4][0] - at[0], ta[4][1] - at[1]
                dist = math.hypot(dx, dz)
                need = ta[5] + size + 0.012
                if dist < need:
                    if dist < 1e-6:
                        dx, dz, dist = 0.0, -1.0, 1.0
                    ta[4][0] += dx / dist * (need - dist)
                    ta[4][1] += dz / dist * (need - dist)
                    ta[3] = None if ta[0] == "nerve" else ta[3]
                    moved = True
        for t in tubes:  # (inside the fat's band at most)
            t[4][0] = min(max(t[4][0], cx - hx + 0.07 + t[5]), cx + hx - 0.07 - t[5])
            t[4][1] = min(max(t[4][1], cz - hz + 0.07 + t[5]), cz + hz - 0.07 - t[5])
        if not moved:
            break
    # (each in its own pocket: the muscles and fat round it pulled back)
    for _group, _name, _i, _cells, c, r in tubes:
        hole = np.hypot(X - c[0], Z - c[1]) < r + 0.014
        labels[hole] = -1
        fat &= ~hole
    # neighbouring muscles in two shades (by shared border)
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

    grain = ridges(noise2(rng, 0.022))
    fine = noise2(rng, 0.012)
    # the fat: yellow lobules
    lobes = ridges(noise2(rng, 0.04))
    add("Fat", mask_plug(fat & ~bone, xs, zs, plane_y, up,
                         lambda x, z: s(0.05 + 0.005 * lobes(x, z) + 0.0015 * fine(x, z)), 0.065, 0.03))
    # the muscles: the fascia between them, each one domed and grained
    muscles = np.zeros(X.shape, bool)
    for k, (g, _name, _plug) in enumerate(soft):
        if g == "muscle":
            muscles |= labels == k
    add("Fascia", mask_plug(muscles, xs, zs, plane_y, up, lambda x, z: s(0.054 + 0.002 * fine(x, z)), 0.08, 0.025))
    for k, (g, name, _plug) in enumerate(soft):
        region = labels == k
        if sizes[k] < 4:
            continue
        d = edt(region)
        if g == "muscle":
            core = d > 0.012  # (a thin pale line of fascia between two)
            at = sampler(swell(region), xs, zs)
            base = rng.uniform(0.04, 0.058)
            add(("Muscle", "MuscleDark")[shade[k]],
                mask_plug(core, xs, zs, plane_y, up,
                          lambda x, z, at=at, base=base: s(base + 0.035 * (1 - np.exp(-at(x, z) / 0.03))
                                                           + 0.004 * grain(x, z)), 0.035))
        else:
            # a piece of gut cut across: wall, lining, what was in it (sunk);
            # by how deep into it (its own widest), so each one is a ring
            at = sampler(d, xs, zs)
            top = rng.uniform(0.055, 0.08)
            deep = float(d.max())
            wall = region & (d <= max(0.016, deep * 0.3))
            lining = region & (d > max(0.016, deep * 0.3)) & (d <= max(0.03, deep * 0.55))
            inside = region & (d > max(0.03, deep * 0.55))
            if not inside.any():
                lining = region & (d > max(0.016, deep * 0.3))
            add("Gut", mask_plug(wall, xs, zs, plane_y, up,
                                 lambda x, z, at=at, top=top: s(top + np.minimum(at(x, z), 0.03) * 0.3), 0.03))
            add("Mucosa", mask_plug(lining, xs, zs, plane_y, up,
                                    lambda x, z, top=top: s(top - 0.002 + 0.005 * grain(x, z)), 0.02))
            content = "Urine" if "bladder" in name.lower() else "Lumen"
            add(content, mask_plug(inside, xs, zs, plane_y, up,
                                   lambda x, z, top=top: s(top - 0.028 + 0.002 * fine(x, z)), 0.03))
    # the loops of small intestine: each a ring (its pink wall, the red
    # velvety lining, what was in it: yellow-brown chyme, sunk), bulging out
    # of the cut, a little squeezed (oval), here and there a small vessel of
    # the mesentery in the fat between them
    for x0, z0, r, aspect, turn in loops:
        u = (X - x0) * math.cos(turn) + (Z - z0) * math.sin(turn)
        t = -(X - x0) * math.sin(turn) + (Z - z0) * math.cos(turn)
        ang = np.arctan2(t, u)
        dist = np.hypot(u / math.sqrt(aspect), t * math.sqrt(aspect)) * (
            1 + 0.05 * np.sin(3 * ang + x0 * 40) + 0.03 * np.sin(5 * ang + z0 * 30))
        wall_w = r * rng.uniform(0.26, 0.32)
        top = rng.uniform(0.06, 0.09)
        bulge = sampler(np.clip(r - dist, 0, None), xs, zs)
        add("Gut", mask_plug((dist <= r) & (dist > r - wall_w), xs, zs, plane_y, up,
                             lambda x, z, top=top, bulge=bulge: s(top + 0.25 * np.minimum(bulge(x, z), 0.03)), 0.03))
        add("Mucosa", mask_plug((dist <= r - wall_w) & (dist > r - wall_w * 1.9), xs, zs, plane_y, up,
                                lambda x, z, top=top: s(top - 0.004 + 0.006 * grain(x, z)), 0.02))
        add("Chyme" if rng.random() < 0.7 else "Mucosa",
            mask_plug(dist <= r - wall_w * 1.9, xs, zs, plane_y, up,
                      lambda x, z, top=top: s(top - 0.03 + 0.003 * fine(x, z)), 0.03))
    for _ in range(9 if loops else 0):
        x0, z0, r, _a, _t = loops[rng.randrange(len(loops))]
        a = rng.uniform(0, 2 * math.pi)
        c = (x0 + math.cos(a) * (r + 0.02), z0 + math.sin(a) * (r + 0.02))
        artery = rng.random() < 0.5
        for layer, bm in vessel_stub(rng, c, rng.uniform(0.012, 0.018), plane_y, up,
                                     s(rng.uniform(0.05, 0.07)), artery).items():
            add(layer, bm)
    # the bones: their hard white rim (cortex: a thick ring in a thigh's
    # femur), standing a little proud of the yellow-red spongy core
    for name, m in bones:
        d = edt(m)
        cortex = max(0.042, float(d.max()) * 0.38) if leg else 0.026
        top = 0.05 + rng.uniform(0, 0.008)
        pits = noise2(rng, 0.011)
        core = m & (d > cortex)
        if core.sum() < 6:  # (too thin for its core: a sliver of it anyway)
            core = m & (d > float(d.max()) * 0.5)
        add("Bone", mask_plug(m & ~core, xs, zs, plane_y, up, lambda x, z, top=top: s(top + 0.001 * fine(x, z)), 0.05))
        add("Marrow", mask_plug(core, xs, zs, plane_y, up,
                                lambda x, z, top=top, pits=pits: s(top - 0.012 - 0.008 * np.clip((pits(x, z) - 0.05) * 2.5, 0, 1)),
                                0.02))
    # the vessels: tubes sticking out, open; the nerves: white cords
    for group, name, i, cells, c, r in tubes:
        if group == "nerve":
            if cells is None:
                cells = np.hypot(X - c[0], Z - c[1]) < r
            d = edt(cells)
            at = sampler(d, xs, zs)
            add("Nerve", mask_plug(cells, xs, zs, plane_y, up,
                                   lambda x, z, at=at: s(0.07 + np.minimum(at(x, z), 0.03) * 0.6
                                                         + 0.006 * grain(x, z)), 0.012))
            continue
        artery = "artery" in name.lower()
        length = s(rng.uniform(0.09, 0.12) if artery else rng.uniform(0.06, 0.08))
        for layer, bm in vessel_stub(rng, c, r, plane_y, up, length, artery).items():
            add(layer, bm)
        if artery:
            key = name if name not in ends else f"{name}#{i}"
            ends[key] = Vector((c[0], plane_y - up * length, c[1]))
    # blood: pooled on a leg's face round its femoral artery (it fills the
    # low places), hanging in drops under the upper body's
    if leg:
        for name, at in ends.items():
            if "Femoral artery" in name:
                ring = noise2(rng, 0.08)
                dist = np.hypot(X - at.x, Z - at.z)
                pool = (dist < 0.14 + 0.06 * ring(X, Z)) & ~bone
                add("Blood", mask_plug(pool, xs, zs, plane_y, up, lambda x, z: s(0.094) + 0.0 * x, 0.06))
    else:
        for at in ends.values():
            for _ in range(2):
                p = at + Vector((rng.uniform(-0.03, 0.03), 0.0, rng.uniform(-0.03, 0.03)))
                add("Blood", drop(rng, p, rng.uniform(0.014, 0.022), (0, -1, 0)))
        for _ in range(14):  # (from the fat and the skin at the edge)
            a = rng.uniform(0, 2 * math.pi)
            ex, ez = math.cos(a), math.sin(a)
            k = min(hx / max(abs(ex), 1e-3), hz / max(abs(ez), 1e-3)) * rng.uniform(0.86, 0.95)
            p = Vector((cx + ex * k, plane_y - 0.075, cz + ez * k))
            add("Blood", drop(rng, p, rng.uniform(0.012, 0.02), (0, -1, 0)))
    return out, ends


def cut_face(rng, anatomy, centre, half, plane_y, up, select, side=0, bone_scale=1.15, bowel=False):
    """The cut through the body, one side of it: each Z-Anatomy object cut
    by the plane (`up` = +1: the upper body, the face looking down; -1: a
    leg, the face looking up), widened to the R6 footprint (`half`, round
    `centre` in X-Z, FOLD of it), its real cross-section there made a plug,
    then the whole face worked out cell by cell (paint_face). `select(name,
    v)` -> whether to keep an object; `side` (+1 / -1): only that half of
    the body (X > 0 / X < 0: a leg's), its bones `bone_scale` as big;
    `bowel`: see paint_face. Returns ({layer: [bmesh]}, {artery: its cut
    end})."""
    pts = np.concatenate([v[np.abs(v[:, 1] - plane_y) < 0.08] for g in ("bone", "muscle", "gut")
                          for name, v, _f in anatomy[g] if select(name, v)])
    if side:
        pts = pts[pts[:, 0] * side > 0]
    reach = outline(pts, centre)
    hx, hz = half
    fold = (hx * FOLD[0], hz * FOLD[1])

    def squarified(c):
        probe = bmesh.new()
        probe.verts.new(c)
        squarify(probe, centre, fold, reach, 1.0)
        probe.verts.ensure_lookup_table()
        at = probe.verts[0].co.copy()
        probe.free()
        return at

    if side:
        near = np.concatenate([v[(np.abs(v[:, 1] - plane_y) < 0.06) & (v[:, 0] * side > 0)]
                               for name, v, _f in anatomy["bone"] if select(name, v)])
        bone_c = Vector(near.mean(0))
        bone_at = squarified(bone_c)
        if bowel is False and bone_scale > 1.2:
            # (a thigh's femur: nearer the middle than the widening puts it)
            mid = Vector((centre[0], bone_at.y, centre[1]))
            bone_at = mid + (bone_at - mid) * 0.4
    raw = {}
    for group in ("bone", "muscle", "gut", "vessel", "nerve"):
        for name, v, f in anatomy.get(group, []):
            if not select(name, v):
                continue
            bm = bm_of(v, f)
            if side:  # (the hips split down the middle)
                cut(bm, [((0, 0, 0), (-side, 0, 0))], fill=False)
                if len(bm.faces) < 4:
                    bm.free()
                    continue
            if group in ("vessel", "nerve"):
                # (thin: moved with the flesh round it, not stretched; thicker
                # so it shows)
                c = sum((x.co for x in bm.verts), Vector()) / len(bm.verts)
                moved = squarified(c) - c
                bmesh.ops.translate(bm, vec=Vector((moved.x, 0, moved.z)), verts=bm.verts)
                thicken(bm, 1.7 if group == "vessel" else 1.3)
            elif group == "bone" and side:
                # (a leg's bones: moved together, kept their shape - the round
                # femoral head in its socket)
                for x in bm.verts:
                    x.co.x = bone_at.x + (x.co.x - bone_c.x) * bone_scale
                    x.co.z = bone_at.z + (x.co.z - bone_c.z) * bone_scale
            else:
                squarify(bm, centre, fold, reach, 1.0)
            grow = {"muscle": 0.03, "gut": 0.01}.get(group, 0.0)
            plug = section(bm, plane_y, up, 0.05, rng, 0.0, grow)
            bm.free()
            if plug is not None:
                raw.setdefault(group, []).append((name, plug))
    painted = paint_face(rng, raw, centre, half, plane_y, up, bowel)
    for plugs in raw.values():
        for _name, plug in plugs:
            plug.free()
    return painted


# ---- the gut: coiled, wet, on its mesentery ----

def coil(rng, start, heading, steps, step, radius, centre, reach, pull=None, target=None):
    """The path of a length of small intestine lying in a heap: it winds
    (turning smoothly, at random), keeps a gut's width off itself, stays
    within `reach` of `centre`; `pull` (a vector) drags it (its weight);
    `target`: it comes back and ends there."""
    pts = [Vector(start)]
    d = Vector(heading).normalized()
    w = Vector()
    centre = Vector(centre)
    for i in range(steps):
        w = w * 0.7 + Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))) * 0.55
        steer = Vector(w)
        p = pts[-1]
        for q in pts[:-5]:
            dq = p - q
            dist = dq.length
            if 1e-6 < dist < radius * 2.7:
                steer += dq / dist * (radius * 2.7 - dist) / radius * 1.6
        off = (p - centre).length
        if off > reach:
            steer += (centre - p).normalized() * (0.9 + 8 * (off - reach) / reach)
        if pull is not None:
            steer += Vector(pull) * (1 - i / steps)
        if target is not None:
            t = i / steps
            steer += (Vector(target) - p).normalized() * 3.0 * t ** 3
        d = (d + steer * 0.3).normalized()
        pts.append(p + d * step)
    if target is not None:  # (bent to end exactly there)
        miss = Vector(target) - pts[-1]
        n = len(pts)
        for i in range(n):
            t = i / (n - 1)
            pts[i] += miss * (t * t * (3 - 2 * t))
    for _ in range(2):  # (smoothed, the ends kept)
        pts = [pts[0]] + [(pts[i - 1] + pts[i] * 2 + pts[i + 1]) / 4 for i in range(1, len(pts) - 1)] + [pts[-1]]
    return pts


def gut_tube(path, radius, rng, segments=10, folds=0.03, torn=(True, True), shape=None, skin="Gut"):
    """A length of gut along `path`: a soft tube, narrowing and swelling a
    little (peristalsis), faint rings of its folds through the wall;
    `shape(length, angle)` -> a radius factor (the colon's pouches). Its
    ends torn (ragged, the red lining showing, the colon's contents in it)
    or closed round. Returns {layer: bmesh} (`skin`, "Mucosa", "Lumen")."""
    pts = [Vector(p) for p in path]
    bm = bmesh.new()
    tags = []
    rings = []
    length = 0.0
    prev_side = None
    phase = [rng.uniform(0, 6.3) for _ in range(2)]
    tangents = []
    for i, p in enumerate(pts):
        if i > 0:
            length += (p - pts[i - 1]).length
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        tangents.append(t)
        ref = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
        side = t.cross(ref).normalized() if prev_side is None else (prev_side - t * prev_side.dot(t)).normalized()
        prev_side = side
        upv = t.cross(side).normalized()
        r = radius * (1 + 0.1 * math.sin(length * 3.1 + phase[0]) * math.sin(length * 1.3 + phase[1])
                      + folds * math.sin(length / radius * 2.4))
        ring = []
        for k in range(segments):
            a = 2 * math.pi * k / segments
            rk = r * (shape(length, a) if shape else 1.0)
            ring.append(bm.verts.new(p + (side * math.cos(a) + upv * math.sin(a)) * rk))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segments):
            j = (k + 1) % segments
            bm.faces.new((rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]))
            tags.append(skin)

    def end(ring, centre, inward, is_torn):
        # inward: into the tube from this end
        if is_torn:
            # (ragged, but in soft scallops: single jags read as teeth)
            n = len(ring)
            depth = [rng.uniform(-0.35, 0.25) for _ in ring]
            flare = [rng.uniform(0.92, 1.06) for _ in ring]
            for _ in range(2):
                depth = [(depth[k - 1] + depth[k] * 2 + depth[(k + 1) % n]) / 4 for k in range(n)]
                flare = [(flare[k - 1] + flare[k] * 2 + flare[(k + 1) % n]) / 4 for k in range(n)]
            for k, v in enumerate(ring):
                v.co += inward * depth[k] * radius
                v.co = centre + (v.co - centre) * flare[k]
            lip = [bm.verts.new(centre + (v.co - centre) * 0.72 + inward * radius * 0.2) for v in ring]
            core = [bm.verts.new(centre + (v.co - centre) * 0.45 + inward * radius * 0.45) for v in ring]
            mid = bm.verts.new(centre + inward * radius * 0.6)
            layers = ("Mucosa", "Lumen" if skin == "Colon" else "Mucosa")
        else:
            lip = [bm.verts.new(centre + (v.co - centre) * 0.75 - inward * radius * 0.45) for v in ring]
            core = [bm.verts.new(centre + (v.co - centre) * 0.4 - inward * radius * 0.8) for v in ring]
            mid = bm.verts.new(centre - inward * radius * 0.92)
            layers = (skin, skin)
        n = len(ring)
        for k in range(n):
            j = (k + 1) % n
            bm.faces.new((ring[k], ring[j], lip[j], lip[k]))
            tags.append(layers[0])
            bm.faces.new((lip[k], lip[j], core[j], core[k]))
            tags.append(layers[1])
            bm.faces.new((core[k], core[j], mid))
            tags.append(layers[1])

    end(rings[0], pts[0], tangents[0], torn[0])
    end(rings[-1], pts[-1], -tangents[-1], torn[1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    return split_faces(bm, tags)


def mesentery(rng, path, radius, root, width=0.45, skip=4):
    """The gut's mesentery along `path`: a band of the fatty sheet it hangs
    from, from the gut's inner edge toward `root`, ruffled, its far edge
    torn; on it the vessels: an arcade along it, short straight ones (vasa
    recta) to the gut. Returns {"Mesentery": bmesh, "Vessel": bmesh}."""
    root = Vector(root)
    sheet = bmesh.new()
    rows = []
    mids = []
    frames = []
    phase = rng.uniform(0, 6.3)
    path = [Vector(p) for p in path][skip:len(path) - skip]
    for i, p in enumerate(path):
        toward = root - p
        dist = toward.length
        toward = toward.normalized() if dist > 1e-6 else Vector((0, 1, 0))
        a = p + toward * radius * 0.55
        reach = min(dist * width, 0.3) * (1 + 0.12 * math.sin(i * 0.37 + phase))
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        frill = t.cross(toward).normalized() * 0.022 * math.sin(i * 0.8 + phase)
        b = p + toward * (radius * 0.55 + reach) + frill
        rows.append((sheet.verts.new(a), sheet.verts.new(b)))
        mids.append(a.lerp(b, 0.55) + frill * 0.5)
        frames.append((p, t, toward))
    for i in range(len(rows) - 1):
        sheet.faces.new((rows[i][0], rows[i + 1][0], rows[i + 1][1], rows[i][1]))
    vessels = []
    for i in range(0, len(mids) - 3, 3):
        vessels.append(rod(mids[i], mids[i + 3], 0.011, 0.01, 5))
    for i in range(1, len(mids), 3):
        vessels.append(rod(mids[i], rows[i][0].co.copy(), 0.007, 0.006, 4))
        # (and on round the gut's wall, both ways, branching thinner)
        p, t, u = frames[i]
        side = t.cross(u).normalized()
        for sign in (1, -1):
            reach = rng.uniform(1.3, 2.2)
            wrap = [p + (u * math.cos(sign * reach * k / 3) + side * math.sin(sign * reach * k / 3)) * radius * 1.02
                    + t * 0.012 * k * rng.uniform(-1, 1) for k in range(4)]
            for k in range(3):
                vessels.append(rod(wrap[k], wrap[k + 1], 0.0058 - k * 0.001, 0.005 - k * 0.001, 4))
    return {"Mesentery": solidify(sheet, 0.012), "Vessel": bm_join_all(vessels)}


def blood_coat(rng, bm, cover=0.3, lift=0.004):
    """Blood smeared over a length of gut (`bm`: its wall): patches of its
    surface (`cover` of it, blotchy, with round soft outlines - no shards),
    a hair out of it - a separate skin of wet blood (Blood)."""
    phase = [rng.uniform(0, 6.3) for _ in range(6)]
    coat = bm.copy()
    coat.normal_update()
    # (finer first: the patches' edges follow the blotches, not the quads)
    bmesh.ops.subdivide_edges(coat, edges=coat.edges[:], cuts=2, use_grid_fill=True)
    coat.normal_update()

    def blotch(p):
        return (math.sin(p.x * 9 + phase[0]) * math.sin(p.z * 8 + phase[1])
                + 0.6 * math.sin(p.y * 11 + p.x * 5 + phase[2]) + 0.25 * math.sin((p.x - p.z) * 15 + phase[3]))

    value = {v: blotch(v.co) for v in coat.verts}
    level = sorted(value.values())[int(len(value) * (1 - cover))]
    # (whole faces kept or dropped by their mean: no snapping of single
    # vertices, which left star-shaped, splintered outlines)
    bmesh.ops.delete(coat, geom=[f for f in coat.faces if sum(value[v] for v in f.verts) / len(f.verts) < level],
                     context="FACES")
    # (crumbs and slivers - a few faces, or faces hanging on by a corner -
    # dropped: only real patches stay)
    seen = set()
    small = []
    for f in coat.faces:
        if f in seen:
            continue
        group, todo = [], [f]
        seen.add(f)
        while todo:
            g = todo.pop()
            group.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        todo.append(h)
        if len(group) < 14:
            small.extend(group)
    bmesh.ops.delete(coat, geom=small, context="FACES")
    bmesh.ops.delete(coat, geom=[v for v in coat.verts if not v.link_faces], context="VERTS")
    # (each patch's outline rounded off: its border relaxed along itself)
    for _ in range(8):
        moves = []
        for v in coat.verts:
            ends = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(ends) == 2:
                moves.append((v, v.co * 0.5 + (ends[0].co + ends[1].co) * 0.25))
        for v, at in moves:
            v.co = at
    coat.normal_update()
    for v in coat.verts:
        v.co += v.normal * lift
    coat.normal_update()
    return coat


def mesentery_fan(rng, path, radius, focus, toward, floor_y):
    """The mesentery of a loose length of gut lying folded on the floor: the
    thin see-through sheet it hangs from, spread flat in the fan between its
    loops (from its torn root near `focus` out to the gut, in the X-Z plane,
    `toward`: where the loops fan out to; under the tubes' middle, `floor_y`
    up, so its edges tuck under them), and on it its vessels: trunks out of
    the root, joined in arches (arcades), short straight ones (vasa recta)
    from the arches into the gut, then round its wall. Returns
    {"Mesentery": bmesh, "Vessel": bmesh}."""
    focus = Vector((focus[0], 0, focus[2]))
    toward = Vector((toward[0], 0, toward[2])).normalized()
    side = Vector((0, 1, 0)).cross(toward).normalized()
    pts = [Vector(p) for p in path]
    polar = []
    for p in pts:
        d = Vector((p.x, 0, p.z)) - focus
        polar.append((math.atan2(d.dot(side), d.dot(toward)), d.length))
    # (from the first loop's leg to the last: its sides tuck under them)
    lo = min(a for a, _ in polar) + 0.03
    hi = max(a for a, _ in polar) - 0.03
    inner = min(r for _, r in polar)
    n = 40

    def outer(a):
        # (out to the gut lying furthest out at that angle, a little under it)
        near = [r for b, r in polar if abs(b - a) < 0.09]
        return (max(near) if near else inner + radius) - radius * 0.35

    def at(a, r, h=0.0):
        d = toward * math.cos(a) + side * math.sin(a)
        p = focus + d * r
        p.y = floor_y + h
        return p

    angles = [lo + (hi - lo) * i / (n - 1) for i in range(n)]
    reach = [outer(a) for a in angles]
    for _ in range(2):  # (its edge smoothed)
        reach = [reach[0]] + [(reach[i - 1] + reach[i] * 2 + reach[i + 1]) / 4 for i in range(1, n - 1)] + [reach[-1]]
    # the root: torn, a little inside the loops' inner turns (its edge
    # uneven but soft - jags read as teeth)
    root = [inner * rng.uniform(0.6, 0.72) for _ in angles]
    for _ in range(3):
        root = [root[0]] + [(root[i - 1] + root[i] * 2 + root[i + 1]) / 4 for i in range(1, n - 1)] + [root[-1]]
    rows = 6
    sheet = bmesh.new()
    grid = []
    wave = rng.uniform(0, 6.3)
    for i, a in enumerate(angles):
        col = []
        for k in range(rows + 1):
            t = k / rows
            r = root[i] + (reach[i] - root[i]) * t
            # (it lies in soft folds, never quite flat)
            h = radius * 0.12 * math.sin(a * 23 + wave) * math.sin(t * math.pi)
            col.append(sheet.verts.new(at(a, r, h)))
        grid.append(col)
    for i in range(n - 1):
        for k in range(rows):
            sheet.faces.new((grid[i][k], grid[i][k + 1], grid[i + 1][k + 1], grid[i + 1][k]))
    bmesh.ops.recalc_face_normals(sheet, faces=sheet.faces[:])
    if sheet.faces[0].normal.y < 0:
        bmesh.ops.reverse_faces(sheet, faces=sheet.faces[:])
    sheet.normal_update()
    vessels = []
    top = 0.008  # (on the sheet, just over it)

    def lerp_r(a):
        x = (a - lo) / (hi - lo) * (n - 1)
        i = max(0, min(n - 2, int(x)))
        f = x - i
        return root[i] * (1 - f) + root[i + 1] * f, reach[i] * (1 - f) + reach[i + 1] * f

    trunks = max(3, int((hi - lo) / 0.2))
    ends = []
    for j in range(trunks):
        a = lo + (hi - lo) * (j + 0.5) / trunks + rng.uniform(-0.03, 0.03)
        r0, r1 = lerp_r(a)
        mid = r0 + (r1 - r0) * rng.uniform(0.5, 0.62)
        vessels.append(rod(at(a, r0 + 0.01, top), at(a, mid, top), 0.013, 0.01, 6))
        ends.append((a, mid))
    # the arches: each trunk forks, its branches meet its neighbours'
    for (a0, r0), (a1, r1) in zip(ends, ends[1:]):
        bow = [at(a0 + (a1 - a0) * t, r0 + (r1 - r0) * t + 0.035 * math.sin(math.pi * t), top)
               for t in (0, 0.25, 0.5, 0.75, 1)]
        for k in range(4):
            vessels.append(rod(bow[k], bow[k + 1], 0.009, 0.009, 5))
    # the vasa recta: straight out of the arches into the gut, then round it
    a = lo + 0.04
    while a < hi - 0.04:
        r0, r1 = lerp_r(a)
        k = min(range(len(ends) - 1), key=lambda m: abs((ends[m][0] + ends[m + 1][0]) / 2 - a)) if len(ends) > 1 else 0
        base = ends[k][1] if len(ends) == 1 else ends[k][1] + (ends[k + 1][1] - ends[k][1]) * 0.5 + 0.035
        start = at(a, min(base, r1 - 0.03), top)
        end = at(a, r1 + radius * 0.3, top)
        vessels.append(rod(start, end, 0.006, 0.005, 4))
        # (and on round the wall of the gut it reaches)
        q = min(range(len(pts)), key=lambda m: (Vector((pts[m].x, 0, pts[m].z)) - Vector((end.x, 0, end.z))).length)
        p = pts[q]
        t = (pts[min(q + 1, len(pts) - 1)] - pts[max(q - 1, 0)]).normalized()
        u = Vector((end.x - p.x, 0, end.z - p.z))
        u = (u - t * u.dot(t)).normalized() if u.length > 1e-6 else side
        w = t.cross(u).normalized()
        if w.y < 0:
            w = -w
        wrap = [p + (u * math.cos(1.5 * s / 3) + w * math.sin(1.5 * s / 3)) * radius * 1.02 for s in range(4)]
        for s in range(3):
            vessels.append(rod(wrap[s], wrap[s + 1], 0.005 - s * 0.0008, 0.0045 - s * 0.0008, 4))
        a += rng.uniform(0.07, 0.11)
    return {"Mesentery": solidify(sheet, 0.01), "Vessel": bm_join_all(vessels)}


def merge_layers(*pieces):
    """Several {layer: bmesh} merged into one (by layer)."""
    out = {}
    for piece in pieces:
        for layer, bm in piece.items():
            out.setdefault(layer, []).append(bm)
    return {layer: (bms[0] if len(bms) == 1 else bm_join_all(bms)) for layer, bms in out.items()}


def hanging_loop(rng, a, b, depth, radius):
    """A loop of small intestine hanging out of the cut from `a` to `b` (both
    on it), winding, sagging about `depth` out of it (down and back: once the
    upper body lies on its back it droops to the floor), its mesentery in
    the loop."""
    a, b = Vector(a), Vector(b)
    sag = Vector((0, -0.86, 0.5))
    mid = (a + b) / 2 + sag * depth * 0.6
    path = coil(rng, a, sag, int(depth * 26) + 14, radius * 0.9, radius, mid, depth * 0.55,
                pull=sag * 0.6, target=b)
    gut = gut_tube(path, radius, rng, 10, torn=(False, False))
    root = (a + b) / 2 + sag * 0.05
    return merge_layers(gut, mesentery(rng, path, radius, root, 0.55, 3))


def waist_cut(rng):
    """Dr. Rift's finisher: the two faces of the cut, built from the real
    anatomy of the hips (anatomy/waist.npz). Returns (waist, hip_r, hip_l),
    each {layer: bmesh}:
      waist   R6 torso space (2 x 2 x 1), the face under the upper body
              (Y = -1), hanging down a little
      hip_r   R6 right leg space (1 x 2 x 1), the face on its top (Y = 1)
      hip_l   the left leg's
    (and prints where the arteries' cut ends are: WaistCut's FEMORAL /
    ILIAC)"""
    anatomy = load_waist()

    def layers(painted, half, plane_y, up, centre):
        out = {layer: bm_join_all(bms) for layer, bms in painted.items()}
        # the dark floor of the cut (nothing see-through between the parts)
        floor = floor_plate(half, 0.0, 0.012, rng)
        bmesh.ops.translate(floor, vec=Vector((centre[0], plane_y - up * 0.008, centre[1])), verts=floor.verts)
        out["FleshDark"] = floor
        return out

    # ---- the upper body's face (torso space, its bottom at Y = -1)
    painted, ends = cut_face(rng, anatomy, (0.0, 0.0), (1.0, 0.5), -1.0, 1,
                             lambda name, v: (v[:, 1] > -1.0).any(), bowel=True)
    print("  waist: artery ends", {k: tuple(round(c, 2) for c in v) for k, v in ends.items()})
    waist = layers(painted, (1.0, 0.5), -1.0, 1, (0.0, 0.0))
    # loops of small intestine hanging out of it: two, out of the belly's
    # front corners (the rest of the face stays in sight)
    loops = []
    for i, x in enumerate((-0.5, 0.45)):
        a = Vector((x + rng.uniform(-0.06, 0.06), -1.05, rng.uniform(-0.36, -0.3)))
        b = a + Vector((rng.uniform(0.15, 0.25) * (1 if x < 0 else -1), 0, rng.uniform(-0.04, 0.04)))
        loops.append(hanging_loop(rng, a, b, rng.uniform(0.22, 0.3), rng.uniform(0.075, 0.085)))
    hanging = merge_layers(*loops)
    for layer, bm in hanging.items():
        waist[layer] = bm_join_all([waist[layer], bm]) if layer in waist else bm
    waist["Skin"] = rim_flaps(rng, (1.0, 0.5), -1.0, (0, -1, 0), 12, (0.08, 0.2), (0.03, 0.1), (0.9, 1.7))

    # ---- each leg's top (its own space: 1 x 2 x 1, its top at Y = 1): a
    # real section of the upper thigh (extract_waist.py's "thigh" slab, its
    # plane on Y = -1 too) - the femur's shaft, a thick ring of bone, in the
    # middle of the big muscles of the thigh - reads far better there than
    # the hip joint (the bones a bit bigger: they show)
    thigh = {group: anatomy["thigh" + group] for group in ("bone", "muscle", "vessel", "nerve")}
    thigh["gut"] = []

    def leg(side, leg_rng):
        # the leg's half of the body: X > 0 is the right (torso space)
        cx = 0.5 * side
        painted, ends = cut_face(leg_rng, thigh, (cx, 0.0), (0.5, 0.5), -1.0, -1,
                                 lambda name, v: (v[:, 0] * side > 0.02).any(), side, bone_scale=1.4)
        print(f"  leg {side}: artery ends (leg space)",
              {k: (round(v.x - cx, 2), round(v.y + 2, 2), round(v.z, 2)) for k, v in ends.items()})
        top = layers(painted, (0.5, 0.5), -1.0, -1, (cx, 0.0))
        top["Skin"] = rim_flaps(leg_rng, (0.5, 0.5), -1.0, (0, 1, 0), 7, (0.08, 0.18), (0.03, 0.09), (0.9, 1.6))
        bmesh.ops.translate(top["Skin"], vec=Vector((cx, 0, 0)), verts=top["Skin"].verts)
        for bm in top.values():  # torso space -> the leg's (its top at Y = 1)
            bmesh.ops.translate(bm, vec=Vector((-cx, 2.0, 0)), verts=bm.verts)
        return top

    hip_r = leg(1, random.Random(rng.randrange(1 << 30)))
    hip_l = leg(-1, random.Random(rng.randrange(1 << 30)))
    for piece in (waist, hip_r, hip_l):
        for layer, bm in piece.items():
            if layer in ("Muscle", "MuscleDark", "Fat", "Fascia", "Bone", "Marrow", "FleshDark"):
                sharp_split(bm)
    return waist, hip_r, hip_l


def centred(layers):
    """{layer: bmesh} moved so its bounding box is centred on the origin (it
    spawns where it is meant to)."""
    allv = [x.co for bm in layers.values() for x in bm.verts]
    mid = Vector([(min(c[k] for c in allv) + max(c[k] for c in allv)) / 2 for k in range(3)])
    for bm in layers.values():
        bmesh.ops.translate(bm, vec=-mid, verts=bm.verts)
    return layers


def folds(rng, focus, toward, legs, length, radius, fan, lift=None):
    """The path of a length of small intestine lying folded on its mesentery,
    as it does: side by side to and fro (hairpin loops), its legs fanning out
    from `focus` (where the mesentery gathers) along `toward` (X-Z) and
    `fan` radians apart, each about `length` long, a rounded turn at each
    end; `lift(point)` -> how high it lies there (over other loops). Returns
    the points (on the floor, Y = its radius)."""
    toward = Vector((toward[0], 0, toward[2])).normalized()
    side = Vector((0, 1, 0)).cross(toward).normalized()
    near = 2.15 * radius / fan  # (the legs' inner ends a gut's width apart)
    pts = []
    for j in range(legs):
        a = (j - (legs - 1) / 2) * fan + rng.uniform(-0.05, 0.05)
        d = toward * math.cos(a) + side * math.sin(a)
        far = near + length * rng.uniform(0.75, 1.15)
        r0, r1 = (near, far) if j % 2 == 0 else (far, near)
        n = max(4, int(abs(far - near) / (radius * 0.8)))
        wob = rng.uniform(0, 6.3)
        for i in range(n + 1):
            t = i / n
            r = r0 + (r1 - r0) * t
            sway = (side * math.cos(a) - toward * math.sin(a)) * 0.025 * math.sin(t * 5 + wob)
            pts.append(Vector(focus) + d * r + sway)
        if j < legs - 1:  # the turn to the next leg: half round
            a2 = a + fan
            mid_a = (a + a2) / 2
            rr = r1 + (radius * 1.05 if j % 2 == 0 else -radius * 0.4)
            pts.append(Vector(focus) + (toward * math.cos(mid_a) + side * math.sin(mid_a)) * rr)
    for _ in range(3):  # (smoothed, the ends kept)
        pts = [pts[0]] + [(pts[i - 1] + pts[i] * 2 + pts[i + 1]) / 4 for i in range(1, len(pts) - 1)] + [pts[-1]]
    for p in pts:
        p.y = radius + (lift(p) if lift else 0.0)
    return pts


def resample(pts, step):
    """`pts` (a path) evened out to points about `step` apart."""
    out = [Vector(pts[0])]
    left = 0.0
    for i in range(1, len(pts)):
        a, b = Vector(pts[i - 1]), Vector(pts[i])
        seg = (b - a).length
        t = step - left
        while t <= seg:
            out.append(a.lerp(b, t / seg))
            t += step
        left = seg - (t - step)
    out.append(Vector(pts[-1]))
    return out


def gut_lengths(rng):
    """Loose lengths of small intestine torn out (jejunum / ileum: Z-Anatomy's
    is about 0.17 stud thick at the torso's scale), each lying folded as the
    real one does: hairpin loops side by side fanning out on their
    mesentery (a sheet with its vessels, gathered toward its torn root), a
    leg here and there riding a little onto the next, a torn end trailing
    out; centred."""
    out = []
    for i in range(3):
        radius = rng.uniform(0.08, 0.09)
        a = rng.uniform(0, 2 * math.pi)
        toward = Vector((math.cos(a), 0, math.sin(a)))
        focus = Vector((0, 0, 0)) - toward * 0.32
        ride = {j: rng.uniform(0.3, 0.8) * radius for j in range(8) if rng.random() < 0.35}
        legs = (5, 6, 4)[i]

        def lift(p, focus=focus, toward=toward, legs=legs, ride=ride):
            # (which leg it is on: by its angle round the focus)
            d = p - focus
            side = Vector((0, 1, 0)).cross(toward).normalized()
            a = math.atan2(d.dot(side), d.dot(toward))
            return sum(h * math.exp(-((a - (j - (legs - 1) / 2) * 0.33) / 0.12) ** 2) for j, h in ride.items())

        path = folds(rng, focus, toward, legs, rng.uniform(0.36, 0.46), radius, 0.33, lift)
        # a torn end trailing out of it
        d = path[-1] - path[-2]
        d.y = 0
        d = d.normalized() if d.length > 1e-6 else Vector((1, 0, 0))
        side = Vector((0, 1, 0)).cross(d)
        path += [path[-1] + d * radius * 0.9 * k + side * 0.04 * math.sin(k * 0.6) for k in range(1, 6)]
        path = resample(path, radius * 0.75)
        # (slight constrictions along it: it is a soft tube that kneads)
        gut = gut_tube(path, radius, rng, 10, folds=0.06, torn=(True, True))
        gut["Blood"] = blood_coat(rng, gut["Gut"], 0.2)
        # (its mesentery spread flat between the loops, under their middle)
        sheet = mesentery_fan(rng, path[:-6], radius, focus, toward, radius * 0.45)
        out.append(centred(merge_layers(gut, sheet)))
    return out


def colon_length(rng):
    """A torn length of the sigmoid colon (it lies at the cut's height): a
    thicker tube (about 0.28 stud), puckered into its pouches (haustra)
    between three flat bands (taeniae), its little fatty tags (appendices
    epiploicae: flattened fingers of fat, of all sizes, at uneven spacing
    along the bands, lying against the wall), both ends torn, its dark
    contents in them; centred."""
    radius = 0.14
    bands = [k * 2 * math.pi / 3 + 0.4 for k in range(3)]

    def shape(length, a):
        band = max(math.exp(-((math.atan2(math.sin(a - b), math.cos(a - b))) / 0.22) ** 2) for b in bands)
        pouch = 0.8 + 0.2 * abs(math.sin(math.pi * length / 0.21)) ** 0.6
        return band * 0.84 + (1 - band) * pouch

    n = 44
    path = [Vector(((t - 0.5) * 1.7, 0.12 * math.sin(2 * math.pi * t), 0.28 * math.sin(math.pi * t * 1.4) - 0.1))
            for t in (i / (n - 1) for i in range(n))]
    colon = gut_tube(path, radius, rng, 18, folds=0.0, torn=(True, True), shape=shape, skin="Colon")
    tags = []
    i = rng.uniform(4, 6)
    while i < n - 5:
        k = int(i)
        p = path[k]
        t = (path[k + 1] - path[k - 1]).normalized()
        side = t.cross(Vector((0, 1, 0))).normalized()
        upv = t.cross(side).normalized()
        a = bands[rng.randrange(3)] + rng.uniform(-0.15, 0.15)
        outv = (side * math.cos(a) + upv * math.sin(a)).normalized()
        tags.append(fat_tag(rng, p + outv * radius * 0.8, outv, t, rng.uniform(0.7, 1.1)))
        i += rng.uniform(4.0, 7.0)
    colon["Fat"] = bm_join_all(tags)
    colon["Blood"] = blood_coat(rng, colon["Colon"], 0.22, 0.005)
    return centred(colon)


def fat_tag(rng, base, out, along, size):
    """One appendix epiploica: a small smooth blob of yellow fat lying flat on
    the colon's wall at `base` (`out`: away from the wall), longer along it
    than wide, sunk a little into it (no stalk sticking out: a stalk reads as
    a thorn)."""
    out, along = Vector(out).normalized(), Vector(along).normalized()
    flat = out.cross(along).normalized()
    along = flat.cross(out).normalized()
    length, width, height = 0.055 * size, 0.034 * size, 0.018 * size
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=1.0)
    for v in bm.verts:
        x, y, z = v.co
        v.co = Vector(base) + along * x * length + flat * y * width + out * z * height
    bm.normal_update()
    return lumpy(bm, rng, 0.003, 40.0)


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
