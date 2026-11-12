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


def build(add_object):
    """Adds the gore pieces to the kit. `add_object(name, bm, offset, layer)`.
    Returns {piece: slot (kit-space Vector)} and the lists by kind."""
    rng = random.Random(4242)
    anatomy = load_anatomy()
    slots = {}
    kinds = {k: [] for k in ("skull", "brain", "eye", "tooth", "splat", "streak", "pool")}

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

    # Blood on the floor.
    for i in range(4):
        piece(f"Splat{i + 1}", {"Blood": blot(rng, 0.42, 1.0 + i * 0.3, 7 + i * 2)}, "splat")
    for i in range(3):
        piece(f"Streak{i + 1}", {"Blood": blot(rng, 0.12, 0.4, 2, stretch=2.6, tail=0.5)}, "streak")
    for i in range(2):
        piece(f"Pool{i + 1}", {"Blood": blot(rng, 0.5, 0.8, 3 + i * 3, ring=72)}, "pool")
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
