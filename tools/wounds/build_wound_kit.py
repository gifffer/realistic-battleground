"""
Builds the wound "inserts" of the game: realistic cuts made by glass, as
small 3D cups that sit in a hole of the skin.

    venv/bin/python tools/wounds/build_wound_kit.py <out_dir> [--preview]

Writes:
  <out_dir>/WoundKit.fbx               every insert, ready for Studio's 3D Importer
  src/shared/WoundShapes.luau          the outline of each insert (the game
                                       cuts the skin along it) - generated, do
                                       not edit by hand
  <out_dir>/preview_*.png              pictures (with --preview)

What a real glass wound looks like (forensic sources, see docs/WOUNDS_FR.md):
  - bottle SMASHED on someone ("Lac"): a laceration - ragged, irregular,
    often star-shaped splits, 1-6 cm, through the skin into the fat / flesh.
    No broken skull, no open chest.
  - BROKEN bottle slashing ("Slash"): an incised wound - long, clean edges,
    gaping in a spindle shape, pointed ends. Deep ones reach the muscle; on
    the head (thin tissue) the bone can just show at the bottom.
Sizes S / M / L. The game grows a wound (S -> M -> L) when the same spot is
hit again. 1 stud ~ 16 cm on an R6 character.

Each insert = a few meshes, one per material (Roblox colours them):
  Lip     the skin edge, rolled a little out then down into the wound (skin colour)
  Dermis  the pale pink-red cut edge of the skin
  Flesh   the red wound bed
  Fat     yellow fat lobules on the walls (body only, almost none on the head)
  Muscle  dark red muscle at the bottom of deep slashes
  Bone    the skull at the bottom of a deep head slash
  Blood   blood pooled in the wound and running down the skin

Local axes of an insert: X along the skin (its length), Y "up" along the
skin, Z out of the skin. The skin surface is Z = 0. Head versions are bent
around a vertical cylinder (radius HEAD_RADIUS).

Markers Kit_Origin / Kit_Up / Kit_Out let the game find how the importer
turned and scaled the file. Insert number i sits at X = i * SPACING.
"""

import math
import random
import sys

import bpy  # first: it makes the other Blender modules importable
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

OUT = sys.argv[1]
PREVIEW = "--preview" in sys.argv
LUA_OUT = "src/shared/WoundShapes.luau"

HEAD_RADIUS = 0.605  # outer radius of the head's skin shell (game: Gashes.luau)
SPACING = 2.0
N = 72  # points on an outline

# kind, size: length, width (studs), depth, lip width, raggedness
VARIANTS = {
    ("Lac", "S"): dict(length=0.17, width=0.075, depth=0.045, lip=0.045, rag=1.0),
    ("Lac", "M"): dict(length=0.27, width=0.11, depth=0.06, lip=0.05, rag=1.0),
    ("Lac", "L"): dict(length=0.38, width=0.15, depth=0.075, lip=0.055, rag=1.0),
    ("Slash", "S"): dict(length=0.3, width=0.045, depth=0.05, lip=0.04, rag=0.25),
    ("Slash", "M"): dict(length=0.45, width=0.075, depth=0.08, lip=0.045, rag=0.25),
    ("Slash", "L"): dict(length=0.6, width=0.1, depth=0.11, lip=0.05, rag=0.25),
}

COLORS = {  # preview only: the game sets the real colours
    "Lip": (0.80, 0.62, 0.50),
    "Dermis": (0.86, 0.52, 0.50),
    "Flesh": (0.55, 0.06, 0.06),
    "Fat": (0.93, 0.80, 0.45),
    "Muscle": (0.40, 0.03, 0.04),
    "Bone": (0.90, 0.86, 0.76),
    "Blood": (0.25, 0.0, 0.0),
    "Marker": (1, 1, 1),
    "Skin": (0.80, 0.62, 0.50),
}


# --- Outlines ---------------------------------------------------------------
def smooth_noise(rng, count, octaves=3):
    """A periodic noise function of t in [0, 2pi): sum of random harmonics."""
    terms = [(k, rng.uniform(0, 2 * math.pi), rng.uniform(0.5, 1.0) / k) for k in range(2, 2 + octaves * 2)]

    def f(t):
        return sum(a * math.sin(k * t + p) for k, p, a in terms) / count

    return f


def outline(kind, v, rng, with_tears=True):
    """Points of the cut's edge (counter-clockwise, studs, centred on 0).
    with_tears=False: the same edge without the thin star-shaped splits -
    the hole the game cuts in the skin (the splits are drawn by the insert's
    torn skin edge only)."""
    a, b = v["length"] / 2, v["width"] / 2
    pts = []
    if kind == "Lac":
        noise = smooth_noise(rng, 2.2)
        # star-shaped splits: a few sharp tears going out of the ellipse
        tears = [(rng.uniform(0, 2 * math.pi), rng.uniform(0.25, 0.55), rng.uniform(0.08, 0.16)) for _ in range(rng.randint(3, 5))]
        for i in range(N):
            t = 2 * math.pi * i / N
            r = 1 + 0.18 * v["rag"] * noise(t) + 0.05 * rng.uniform(-1, 1)
            for at, amp, w in tears if with_tears else ():
                d = math.atan2(math.sin(t - at), math.cos(t - at))
                r += amp * max(0.0, 1 - abs(d) / w) ** 1.5
            pts.append(Vector((a * r * math.cos(t), b * r * math.sin(t), 0)))
    else:
        bend = rng.uniform(-0.25, 0.25) * b  # a slightly curved cut
        noise = smooth_noise(rng, 6)
        for i in range(N):
            t = 2 * math.pi * i / N
            x = a * math.cos(t)
            # pointed ends: the width falls to 0 at both tips
            y = b * math.sin(t) * (1 - abs(math.cos(t)) ** 2.5) ** 0.8
            y *= 1 + 0.15 * v["rag"] * noise(t)
            y += bend * (1 - (x / a) ** 2)
            pts.append(Vector((x, y, 0)))
    return pts


def normals2d(pts, smooth=4):
    """Outward directions along the outline, smoothed over a few points so
    the skin edge doesn't fold over itself at the sharp tips of a tear."""
    raw = []
    n = len(pts)
    for i in range(n):
        d = pts[(i + 1) % n] - pts[i - 1]
        raw.append(Vector((d.y, -d.x, 0)))  # outward for counter-clockwise points
    out = []
    for i in range(n):
        nn = sum((raw[(i + k) % n] for k in range(-smooth, smooth + 1)), Vector())
        out.append(nn.normalized() if nn.length > 1e-9 else Vector((0, 0, 0)))
    return out


def centroid(pts):
    return sum(pts, Vector()) / len(pts)


# --- Mesh helpers -------------------------------------------------------------
class Builder:
    def __init__(self, center):
        self.parts = {}
        self.center = center  # middle of the cut: the walls must face it

    def bm(self, layer):
        if layer not in self.parts:
            self.parts[layer] = bmesh.new()
        return self.parts[layer]

    def face_up(self, bm, verts):
        """A face of an open surface (lip, walls, bed, blood): Roblox draws
        one side only, so it must face the way it is seen - out of the skin
        (+Z) and, for the walls, toward the middle of the cut.
        (Blender's "recalculate normals" guesses wrong on open sheets.)"""
        f = bm.faces.new(verts)
        f.normal_update()
        mid = f.calc_center_median()
        inward = Vector((self.center.x - mid.x, self.center.y - mid.y, 0))
        if inward.length > 1e-9:
            inward.normalize()
        if f.normal.dot(inward + Vector((0, 0, 1))) < 0:
            f.normal_flip()
        return f

    def strip(self, layer, ring_a, ring_b):
        """Quads between two closed rings of equal length."""
        bm = self.bm(layer)
        va = [bm.verts.new(p) for p in ring_a]
        vb = [bm.verts.new(p) for p in ring_b]
        n = len(va)
        for i in range(n):
            j = (i + 1) % n
            self.face_up(bm, (va[i], va[j], vb[j], vb[i]))

    def fan(self, layer, ring, center):
        bm = self.bm(layer)
        vs = [bm.verts.new(p) for p in ring]
        c = bm.verts.new(center)
        n = len(vs)
        for i in range(n):
            self.face_up(bm, (vs[i], vs[(i + 1) % n], c))

    def blob(self, layer, at, radii, rot=0.0, subdiv=1):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
        for vert in bm.verts:
            x, y, z = vert.co.x * radii[0], vert.co.y * radii[1], vert.co.z * radii[2]
            c, s = math.cos(rot), math.sin(rot)
            vert.co = Vector((x * c - y * s, x * s + y * c, z)) + at
        target = self.bm(layer)
        mesh = bpy.data.meshes.new("tmp")
        bm.to_mesh(mesh)
        bm.free()
        target.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)


def ring(pts, normals, offset, z, center=None, shrink=None, jitter=None):
    out = []
    for i, p in enumerate(pts):
        q = p + normals[i] * offset
        if shrink is not None:
            q = center + (q - center) * shrink
        zz = z(i) if callable(z) else z
        if jitter:
            q = q + Vector((jitter(i), jitter(i + 7), 0))
        out.append(Vector((q.x, q.y, zz)))
    return out


# --- One insert ---------------------------------------------------------------
def build_insert(kind, size, v, head, seed):
    rng = random.Random(seed)
    pts = outline(kind, v, rng)
    hole = outline(kind, v, random.Random(seed), with_tears=False)  # same draws, no splits
    nrm = normals2d(pts)
    c = centroid(pts)
    b = Builder(c)
    depth, lip = v["depth"], v["lip"]
    wobble = [rng.uniform(-1, 1) for _ in range(N + 16)]

    def jit(scale):
        return lambda i: wobble[i % len(wobble)] * scale

    # Lip: from the skin (outside, flush) up over a small raised crest, then
    # rolling down into the cut.
    outer = ring(pts, nrm, lip, 0.002)
    # A torn edge is a little swollen; a clean cut lies almost flat.
    swell = 0.005 if kind == "Lac" else 0.0015
    crest = ring(pts, nrm, lip * 0.45, lambda i: swell * (1 + 0.5 * wobble[i]))
    edge = ring(pts, nrm, 0.0, 0.004)
    curl = ring(pts, nrm, -0.01, -0.012)
    b.strip("Lip", outer, crest)
    b.strip("Lip", crest, edge)
    b.strip("Lip", edge, curl)
    # Dermis: the thin pale cut edge of the skin.
    dermis_low = ring(pts, nrm, -0.016, -0.028, jitter=jit(0.003))
    b.strip("Dermis", curl, dermis_low)
    # Walls down to the bed (red flesh), narrowing like a V.
    mid = ring(pts, nrm, 0, lambda i: -depth * (0.6 + 0.12 * wobble[i]), center=c, shrink=0.72, jitter=jit(0.004))
    low = ring(pts, nrm, 0, lambda i: -depth * (0.95 + 0.08 * wobble[i + 3]), center=c, shrink=0.42, jitter=jit(0.003))
    deep = kind == "Slash" and size == "L"
    b.strip("Flesh", dermis_low, mid)
    bed_layer = "Muscle" if deep and not head else "Flesh"
    b.strip(bed_layer, mid, low)
    b.fan(bed_layer, low, Vector((c.x, c.y, -depth * 1.05)))

    # Fat lobules on the walls (body only: little fat under the skin of the head).
    if not head:
        for _ in range({"S": 6, "M": 10, "L": 16}[size]):
            i = rng.randrange(N)
            t = rng.uniform(0.15, 0.6)
            p = dermis_low[i].lerp(mid[i], t)
            inward = (c - Vector((p.x, p.y, 0)))
            inward = inward.normalized() if inward.length > 1e-6 else Vector()
            r = rng.uniform(0.006, 0.012) * (1.3 if size == "L" else 1.0)
            b.blob("Fat", p + inward * r * 0.4, (r, r * rng.uniform(0.7, 1.0), r * 0.8))

    # Muscle fibres at the bottom of a deep slash (body): ridges along the cut.
    if deep and not head:
        for k in range(5):
            y = c.y + (k - 2) * v["width"] * 0.12
            b.blob("Muscle", Vector((c.x, y, -depth * 0.98)), (v["length"] * 0.28, 0.007, 0.006), subdiv=2)
    # Bone at the bottom of a deep head slash: the skull just shows.
    if deep and head:
        b.blob("Bone", Vector((c.x, c.y, -depth * 1.0)), (v["length"] * 0.22, v["width"] * 0.22, 0.008), subdiv=2)

    # Blood: pooled at the low side of the bed, and running down the skin.
    pool = []
    for i in range(N):
        p = low[i]
        q = Vector((p.x, min(p.y, c.y + v["width"] * 0.05), 0))
        pool.append(Vector((q.x, q.y, -depth * 0.82)))
    b.fan("Blood", pool, Vector((c.x, c.y - v["width"] * 0.15, -depth * 0.8)))
    lowest = sorted(range(N), key=lambda i: outer[i].y)[: N // 6]
    drips = {"S": rng.randint(0, 1), "M": 1, "L": 2}[size]
    for _ in range(drips):
        i = rng.choice(lowest)
        start = outer[i]
        length = rng.uniform(0.035, 0.09) * (1.4 if size == "L" else 1.0)
        w = rng.uniform(0.007, 0.012)
        steps = 10
        phase = rng.uniform(0, 6.3)
        bm = b.bm("Blood")
        prev = None
        for s in range(steps + 1):
            f = s / steps
            y = start.y + 0.012 - length * f
            x = start.x + 0.006 * math.sin(phase + f * 5)  # runs a little crooked
            ww = w * (1 - 0.4 * f + 0.25 * math.sin(phase * 2 + f * 9))
            l_ = bm.verts.new((x - ww, y, 0.0035))
            m_ = bm.verts.new((x, y, 0.0035 + ww * 0.4))
            r_ = bm.verts.new((x + ww, y, 0.0035))
            if prev:
                pl, pm, pr = prev
                b.face_up(bm, (pl, l_, m_, pm))
                b.face_up(bm, (pm, m_, r_, pr))
            prev = (l_, m_, r_)
        b.blob("Blood", Vector((x, y - 0.003, 0.003)), (w * 0.9, w * 1.2, w * 0.45))  # the drop

    # How far the insert reaches on the skin (drips included), before bending.
    reach_x = max(abs(vert.co.x) for bm in b.parts.values() for vert in bm.verts)
    reach_y = max(abs(vert.co.y) for bm in b.parts.values() for vert in bm.verts)

    # Head version: bend everything around the head's vertical axis.
    meshes = {}
    for layer, bm in b.parts.items():
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        if head:
            for vert in bm.verts:
                x, y, z = vert.co
                th = x / HEAD_RADIUS
                r = HEAD_RADIUS + z
                vert.co = Vector((r * math.sin(th), y, r * math.cos(th) - HEAD_RADIUS))
        meshes[layer] = bm
    return hole, meshes, (reach_x, reach_y)


# --- Scene & export ---------------------------------------------------------------
def material(layer):
    mat = bpy.data.materials.get("W_" + layer) or bpy.data.materials.new("W_" + layer)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*COLORS[layer], 1)
    bsdf.inputs["Roughness"].default_value = 0.15 if layer in ("Blood", "Flesh", "Muscle") else 0.5
    return mat


def add_object(name, bm, offset, layer):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = layer not in ("Marker",)
    ob = bpy.data.objects.new(name, mesh)
    ob.location = offset
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(material(layer))
    return ob


def cube(size):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=size)
    return bm


def lua_number(x):
    return f"{x:.4f}".rstrip("0").rstrip(".") if x != 0 else "0"


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shapes = []
    index = 0
    objects = []
    for head in (False, True):
        for (kind, size), v in VARIANTS.items():
            name = f"{kind}{size}" + ("_Head" if head else "")
            seed = sum(map(ord, name)) * 7919  # same shapes on every run
            pts, meshes, reach = build_insert(kind, size, v, head, seed)
            offset = Vector((index * SPACING, 0, 0))
            for layer, bm in meshes.items():
                objects.append(add_object(f"{name}_{layer}", bm, offset, layer))
            shapes.append((name, index, kind, size, head, v, pts, reach))
            index += 1
    # Markers: origin, 1 stud up, 1 stud out of the skin.
    # (Below the inserts: Kit_Origin is the point (0, -3, 0) of the inserts' axes.)
    for name, at in (("Kit_Origin", (0, -3, 0)), ("Kit_Up", (0, -2, 0)), ("Kit_Out", (0, -3, 1))):
        objects.append(add_object(name, cube(0.03), Vector(at), "Marker"))

    # Bake object locations into the meshes (one less thing for the importer).
    for ob in objects:
        ob.data.transform(ob.matrix_basis)
        ob.matrix_basis.identity()

    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=f"{OUT}/WoundKit.fbx",
        use_selection=True,
        object_types={"MESH"},
        mesh_smooth_type="OFF",
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_UNITS",
        bake_space_transform=True,
        path_mode="STRIP",
    )

    # The outlines, for the game (it cuts the skin along them).
    lines = [
        "--!strict",
        "-- GENERATED by tools/wounds/build_wound_kit.py - do not edit by hand.",
        "-- Outline of every wound insert of assets/wounds/WoundKit.fbx (studs,",
        "-- X along the skin, Y up the skin; head versions: X = arc length).",
        "-- `index`: the insert's origin sits at (index * spacing, markerDrop, 0)",
        "-- from the Kit_Origin marker, in the kit's axes (Kit_Up = Y, Kit_Out = Z).",
        "",
        "export type Shape = {",
        "\tindex: number,",
        "\tkind: string, -- \"Lac\" (smashed bottle) / \"Slash\" (broken bottle)",
        "\tsize: string, -- \"S\" / \"M\" / \"L\"",
        "\thead: boolean, -- bent for the round head",
        "\tlip: number, -- width of the skin edge around the hole (studs)",
        "\textent: Vector2, -- half size of the whole insert on the skin (X, Y)",
        "\tpoints: { Vector2 }, -- the hole cut in the skin (the edge without its thin splits)",
        "}",
        "",
        "local WoundShapes = {",
        f"\tspacing = {lua_number(SPACING)},",
        f"\theadRadius = {lua_number(HEAD_RADIUS)},",
        "\tmarkerDrop = 3,",
        "\tshapes = {",
    ]
    for name, idx, kind, size, head, v, pts, reach in shapes:
        ex, ey = reach
        lines.append(f"\t\t{name} = {{")
        lines.append(f"\t\t\tindex = {idx},")
        lines.append(f'\t\t\tkind = "{kind}",')
        lines.append(f'\t\t\tsize = "{size}",')
        lines.append(f"\t\t\thead = {'true' if head else 'false'},")
        lines.append(f"\t\t\tlip = {lua_number(v['lip'])},")
        lines.append(f"\t\t\textent = Vector2.new({lua_number(ex)}, {lua_number(ey)}),")
        lines.append("\t\t\tpoints = {")
        for p in pts:
            lines.append(f"\t\t\t\tVector2.new({lua_number(p.x)}, {lua_number(p.y)}),")
        lines.append("\t\t\t},")
        lines.append("\t\t},")
    lines += ["\t} :: { [string]: Shape },", "}", "", "return WoundShapes", ""]
    with open(LUA_OUT, "w") as f:
        f.write("\n".join(lines))
    print("inserts:", len(shapes), "objects:", len(objects))

    if PREVIEW:
        render_preview(shapes)


def render_preview(shapes):
    """Each insert in a skin plate with its hole, lit, seen from the front."""
    scene = bpy.context.scene
    for idx, (name, i, kind, size, head, v, pts, _reach) in enumerate(shapes):
        x0 = i * SPACING
        # skin plate with the hole (a grid, cells whose center is inside removed)
        bm = bmesh.new()
        cell = 0.02
        half = 0.5
        import numpy as np  # noqa: PLC0415

        poly = np.array([(p.x, p.y) for p in pts])

        def inside(x, y):
            j = len(poly) - 1
            ok = False
            for k in range(len(poly)):
                xi, yi = poly[k]
                xj, yj = poly[j]
                if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
                    ok = not ok
                j = k
            return ok

        steps = int(2 * half / cell)
        for gx in range(steps):
            for gy in range(steps):
                x = -half + (gx + 0.5) * cell
                y = -half + (gy + 0.5) * cell
                if inside(x, y):
                    continue
                vs = []
                for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    px, py = x + dx * cell / 2, y + dy * cell / 2
                    if head:
                        th = px / HEAD_RADIUS
                        vs.append(bm.verts.new((HEAD_RADIUS * math.sin(th), py, HEAD_RADIUS * math.cos(th) - HEAD_RADIUS)))
                    else:
                        vs.append(bm.verts.new((px, py, 0)))
                bm.faces.new(vs)
        add_object(f"plate_{name}", bm, Vector((x0, 0, 0)), "Skin")
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.12, 0.12, 0.13, 1)
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(35), math.radians(-20), 0)
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 420, 320
    for name, i, *_ in shapes:  # noqa: B007
        cam.location = (i * SPACING, -0.55, 2.0)  # a little below, looking up at the cut
        cam.rotation_euler = (math.radians(15), 0, 0)
        cam.data.ortho_scale = 0.85
        scene.render.filepath = f"{OUT}/preview_{name}.png"
        bpy.ops.render.render(write_still=True)


main()
