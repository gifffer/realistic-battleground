"""
Builds the anatomy meshes (bones, muscles, organs, brain...) that sit INSIDE
each R6 body part, from the Z-Anatomy atlas.

Run with Blender's Python module (no Blender window needed):

    python -m venv venv && venv/bin/pip install bpy==5.3.0
    venv/bin/python tools/anatomy/build_anatomy.py <Startup.blend> <out_dir> [--preview]

<Startup.blend> comes from Z-Anatomy.zip (github.com/Z-Anatomy/The-blend).

What it does, for each R6 part (Head, Torso, Left/Right Arm, Left/Right Leg):
  1. picks the real anatomy meshes that belong to that body region,
  2. merges them into a few LAYERS (Skull, Brain, Muscle, Lungs...),
  3. melts each layer into one closed surface (voxel remesh: removes the
     hidden inner faces) and simplifies it (decimate) to a Roblox-friendly
     triangle count,
  4. squeezes the region into the R6 block (limbs are straightened first),
  5. adds "Cavity" (dark inside walls), "Bounds" (the exact size of the R6
     part) and two markers "MarkUp" / "MarkFront": the game code uses them
     to place, turn and scale everything, whatever the importer did,
  6. exports one FBX per part: Anatomy_<Part>.fbx.

Axes of the FBX: Y up, the character looks toward -Z, its right is +X
(the same as a Roblox character).

License: Z-Anatomy is CC BY-SA 4.0 (models from BodyParts3D, CC BY-SA 2.1 JP).
The meshes made here are derived works: same license, credit required.
Kidneys and inner ear are skipped (they are under a NonCommercial license).
"""

import math
import re
import sys

import bpy  # first: it makes the other Blender modules importable
import bmesh  # noqa: E402
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
BLEND, OUT = argv[0], argv[1]
PREVIEW = "--preview" in argv

# --- R6 parts -------------------------------------------------------------
# Size of the visible block in studs (X width, Y height, Z depth), Roblox axes.
# The head part is 2x1x1 but its mesh shows a ~1.2 stud rounded head.
R6 = {
    "Head": (1.2, 1.2, 1.2),
    "Torso": (2.0, 2.0, 1.0),
    "RightArm": (1.0, 2.0, 1.0),
    "LeftArm": (1.0, 2.0, 1.0),
    "RightLeg": (1.0, 2.0, 1.0),
    "LeftLeg": (1.0, 2.0, 1.0),
}
SKIN = 0.06  # room left for the skin shell (made by the game code)

# Triangle budget per layer (a layer = one MeshPart in Roblox).
BUDGET = {
    "Head": {"Skull": 5000, "Teeth": 900, "Brain": 3500, "Eyes": 500, "Muscle": 5000},
    "Torso": {
        "Bone": 5000,
        "Muscle": 5000,
        "Lungs": 1600,
        "Heart": 900,
        "Liver": 900,
        "Guts": 2600,
    },
    "Arm": {"Bone": 1400, "Muscle": 2400},
    "Leg": {"Bone": 1400, "Muscle": 2600},
}
# Layers melted into one surface (others keep their separate small pieces).
NO_REMESH = {"Teeth", "Eyes"}

COLORS = {  # only for the preview / FBX materials, the game sets its own
    "Skull": (0.89, 0.85, 0.74),
    "Bone": (0.89, 0.85, 0.74),
    "Teeth": (0.96, 0.94, 0.86),
    "Brain": (0.86, 0.62, 0.62),
    "Eyes": (0.95, 0.95, 0.93),
    "Muscle": (0.55, 0.09, 0.08),
    "Lungs": (0.86, 0.47, 0.47),
    "Heart": (0.45, 0.05, 0.05),
    "Liver": (0.36, 0.08, 0.06),
    "Guts": (0.82, 0.56, 0.46),
    "Cavity": (0.22, 0.02, 0.02),
    "Bounds": (1, 1, 1),
}

# --- Choosing the meshes ---------------------------------------------------
# Z-Anatomy axes: Z up, the body looks toward -Y, its left side is +X, meters.
SKIP_TOP = ("2:", "3:", "6:", "9:")  # insertions, joints, lymph, regions
SKIP_NAME = re.compile(
    r"kidney|malleus|incus|stapes|cochlea|labyrinth|semicircular|vestibul|tympan|"
    r"fascia|bursa|sheath|retinacul|aponeuros|nerve|ganglion|genital|penis|testis|"
    r"ovary|uterus|prostate|scrotum|vagina|vulva|peritone|mesocolon|omentum|mesentery|"
    r"pleura|pericardi",
    re.I,
)
TEETH = re.compile(r"incisor|canine|molar|tooth|teeth", re.I)
EYES = re.compile(r"eyeball|lens|cornea|iris|retina|vitreous|sclera|choroid|pupil", re.I)
LUNGS = re.compile(r"lung|bronch|trachea", re.I)
LIVER = re.compile(r"liver|gallbladder", re.I)
HEART = re.compile(r"heart|atrium|ventricle|auricle|myocard", re.I)


def tops(o):
    return [c.name for c in o.users_collection if re.match(r"^\d:", c.name)]


def all_collections(o):
    # every collection that contains the object, also through parents
    names = set()
    for c in bpy.data.collections:
        if o.name in c.all_objects:
            names.add(c.name)
    return names


def world_bounds(o):
    corners = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector([min(v[i] for v in corners) for i in range(3)])
    hi = Vector([max(v[i] for v in corners) for i in range(3)])
    return lo, hi


def classify(o, colls):
    """-> (part, layer) or None"""
    t = tops(o)
    if not t or any(x.startswith(SKIP_TOP) for x in t):
        return None
    name = o.name
    if SKIP_NAME.search(name):
        return None
    if t[0].startswith("5:") and not HEART.search(name) and "Heart" not in colls:
        return None
    lo, hi = world_bounds(o)
    c = (lo + hi) / 2
    if abs(c.x) > 0.45:
        return None  # labels placed beside the body
    side = "Left" if c.x > 0 else "Right"  # Z-Anatomy +X = the body's left
    is_upper = any("upper limb" in x for x in colls)
    is_lower = any("lower limb" in x for x in colls)
    girdle = re.search(r"clavicle|scapula|hip bone|sacrum|coccyx", name, re.I)

    if c.z > 1.49 and abs(c.x) < 0.13:
        part = "Head"
    elif not girdle and c.z < 1.42 and (
        (is_upper and abs(c.x) > 0.12) or (abs(c.x) > 0.185 and c.z > 0.95)
    ):
        part = side + "Arm"
    elif not girdle and (c.z < 0.78 or (is_lower and c.z < 0.97)):
        part = side + "Leg"
    elif 0.78 <= c.z <= 1.49:
        part = "Torso"
    else:
        return None

    top = t[0]
    if top.startswith("1:"):
        if part == "Head":
            layer = "Teeth" if (TEETH.search(name) or "Teeth" in colls) else "Skull"
        else:
            layer = "Bone"
    elif top.startswith("4:"):
        layer = "Muscle"
    elif top.startswith("7:"):
        if part != "Head":
            return None
        if EYES.search(name):
            layer = "Eyes"
        elif colls & {"Central nervous system", "Brain", "Cerebrum", "Cerebellum", "Brainstem"}:
            layer = "Brain"
        else:
            return None
    elif top.startswith("5:"):
        layer = "Heart" if part == "Torso" else None
    elif top.startswith("8:"):
        if part == "Head":
            layer = "Muscle"  # tongue, pharynx: meat
        elif part == "Torso":
            if LUNGS.search(name):
                layer = "Lungs"
            elif LIVER.search(name):
                layer = "Liver"
            elif HEART.search(name):
                layer = "Heart"
            else:
                layer = "Guts"
        else:
            return None
    else:
        return None
    if layer is None:
        return None
    return part, layer


# --- Mesh helpers ------------------------------------------------------------
def evaluated_arrays(o, dg):
    """World-space vertices and triangles of an object, modifiers applied
    (but no subdivision: we simplify anyway)."""
    for md in o.modifiers:
        if md.type == "SUBSURF":
            md.show_viewport = False
    dg.update()
    ev = o.evaluated_get(dg)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    nv = len(me.vertices)
    co = np.empty(nv * 3, dtype=np.float64)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    tri = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("vertices", tri)
    ev.to_mesh_clear()
    m = np.array(o.matrix_world)
    co = co @ m[:3, :3].T + m[:3, 3]
    return co, tri.reshape(-1, 3)


# Height range (Z-Anatomy meters) kept for each part: a muscle that runs into
# the next body part (neck muscles, psoas...) is cut at the joint.
CLIP_Z = {
    "Head": (1.475, 9.0),
    "Torso": (0.80, 1.50),
    "RightArm": (-9.0, 1.45),
    "LeftArm": (-9.0, 1.45),
    "RightLeg": (-9.0, 0.94),
    "LeftLeg": (-9.0, 0.94),
}


def clip(verts, tris, zmin, zmax):
    """Keeps the triangles whose 3 corners are inside [zmin, zmax]."""
    z = verts[:, 2][tris]
    keep = np.all((z >= zmin) & (z <= zmax), axis=1)
    return tris[keep]


def make_object(name, verts, tris):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts.tolist(), [], tris.tolist())
    me.validate()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def apply_modifier(ob, kind, **props):
    md = ob.modifiers.new("m", kind)
    for k, v in props.items():
        setattr(md, k, v)
    dg = bpy.context.evaluated_depsgraph_get()
    new = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    ob.modifiers.clear()
    ob.data = new
    bpy.data.meshes.remove(old)


def tri_count(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


def to_arrays(ob):
    me = ob.data
    me.calc_loop_triangles()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    tri = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("vertices", tri)
    return co.reshape(-1, 3), tri.reshape(-1, 3)


def box_object(name, size, inward=False):
    """Box centered on 0 with Roblox size (X, Y, Z) -> Blender (X, Z, Y)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = size
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sz, v.co.z * sy))
    if inward:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def material(name):
    mat = bpy.data.materials.get("AN_" + name) or bpy.data.materials.new("AN_" + name)
    mat.diffuse_color = (*COLORS[name], 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*COLORS[name], 1)
        bsdf.inputs["Roughness"].default_value = 0.45
    return mat


# --- Pieces -------------------------------------------------------------------
# The outer layers are cut into pieces so a wound only removes the flesh (then
# the bone) where it was hit. Each triangle goes to the piece of its center:
# the borders follow the triangles, which looks like torn flesh.
# Axes here (after the 180° turn): X = the body's right, Y = front, Z = up.
def chunk_ids(kind, layer, centers):
    x, y, z = centers[:, 0], centers[:, 1], centers[:, 2]
    if kind == "Head" and layer in ("Skull", "Muscle"):
        sector = (np.floor((np.degrees(np.arctan2(x, y)) + 360 + 30) / 60) % 6).astype(int)
        names = np.array(["Front", "FrontRight", "BackRight", "Back", "BackLeft", "FrontLeft"])
        out = names[sector].astype(object)
        out[z > 0.32] = "Top"
        return out
    if kind == "Torso" and layer == "Muscle":
        return np.array(
            [
                ("Front" if b > 0 else "Back") + ("Up" if c > 0 else "Low") + ("R" if a > 0 else "L")
                for a, b, c in zip(x, y, z)
            ],
            dtype=object,
        )
    if kind in ("Arm", "Leg") and layer == "Muscle":
        return np.array(
            [("Front" if b > 0 else "Back") + ("Up" if c > 0 else "Low") for b, c in zip(y, z)],
            dtype=object,
        )
    return np.array([""] * len(centers), dtype=object)


# --- Main ---------------------------------------------------------------------
def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    dg = bpy.context.evaluated_depsgraph_get()

    # 1. pick and merge
    groups = {}  # (part, layer) -> list of (verts, tris)
    for o in list(bpy.data.objects):
        if o.type != "MESH" or len(o.data.vertices) < 30:
            continue
        if re.search(r"\.(j|i|g|o[lr]?|e[lr]?)$", o.name):
            continue  # labels, group titles and insertion markers, not anatomy
        colls = all_collections(o)
        got = classify(o, colls)
        if got is None:
            continue
        groups.setdefault(got, []).append(evaluated_arrays(o, dg))
    print("groups:", {f"{p}/{l}": len(v) for (p, l), v in sorted(groups.items())})

    # Start from an empty scene for the results.
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    parts = {}
    for (part, layer), chunks in groups.items():
        verts, tris, off = [], [], 0
        for co, tri in chunks:
            verts.append(co)
            tris.append(tri + off)
            off += len(co)
        verts = np.vstack(verts)
        tris = clip(verts, np.vstack(tris), *CLIP_Z[part])
        used = np.unique(tris)  # drop the vertices no triangle uses anymore
        remap = np.full(len(verts), -1, dtype=np.int64)
        remap[used] = np.arange(len(used))
        parts.setdefault(part, {})[layer] = (verts[used], remap[tris])

    built = {}
    for part, layers in parts.items():
        kind = "Arm" if "Arm" in part else "Leg" if "Leg" in part else part
        allv = np.vstack([v for v, _ in layers.values()])

        # 2. straighten limbs: main axis of the bones -> vertical
        rot = Matrix.Identity(3)
        if kind in ("Arm", "Leg"):
            bv = layers.get("Bone", (allv, None))[0]
            centered = bv - bv.mean(axis=0)
            _, _, vt = np.linalg.svd(centered, full_matrices=False)
            axis = Vector(vt[0])
            if axis.z < 0:
                axis = -axis
            rot = axis.rotation_difference(Vector((0, 0, 1))).to_matrix()
        R = np.array(rot)
        rv = allv @ R.T
        lo, hi = rv.min(axis=0), rv.max(axis=0)
        src = hi - lo
        center = (lo + hi) / 2

        # 3. fit into the R6 block. Blender axes here: X width, Y depth, Z height.
        rx, ry, rz = R6[part]
        target = np.array([rx, rz, ry]) - 2 * SKIN
        aniso = target / src
        uni = aniso.min()
        scale = np.sqrt(aniso * uni)  # between "real proportions" and "fill the block"

        out = {}
        for layer, (v, t) in layers.items():
            # remesh / decimate in real size (meters), then transform
            ob = make_object(f"{part}_{layer}", v, t)
            if layer not in NO_REMESH:
                # Muscles: bigger voxels melt the thin sheets into one smooth layer
                fine = 260 if part == "Head" else 220
                voxel = max(src) / (150 if layer == "Muscle" else fine)
                apply_modifier(ob, "REMESH", mode="VOXEL", voxel_size=voxel, use_smooth_shade=True)
            budget = BUDGET[kind][layer]
            n = tri_count(ob)
            if n > budget:
                apply_modifier(ob, "DECIMATE", decimate_type="COLLAPSE", ratio=budget / n)
            co, tri = to_arrays(ob)
            co = (co @ R.T - center) * scale
            # Blender -> "Roblox once exported": turn 180° around Z so the body
            # looks toward +Y in Blender (= -Z in Roblox after FBX Y-up export)
            co[:, 0] *= -1
            co[:, 1] *= -1
            bpy.data.objects.remove(ob, do_unlink=True)
            ids = chunk_ids(kind, layer, co[tri].mean(axis=1))
            for cid in sorted(set(ids)):
                sub = tri[ids == cid]
                used = np.unique(sub)
                remap = np.full(len(co), -1, dtype=np.int64)
                remap[used] = np.arange(len(used))
                name = layer if cid == "" else f"{layer}_{cid}"
                obj = make_object(name, co[used], remap[sub])
                for poly in obj.data.polygons:
                    poly.use_smooth = True
                obj.data.materials.append(material(layer))
                out[name] = obj
            print(f"{part:9s} {layer:7s} tris={len(tri):6d}  from {n}  pieces={len(set(ids))}")

        cav = box_object("Cavity", tuple(s - 2 * SKIN + 0.02 for s in R6[part]), inward=True)
        cav.data.materials.append(material("Cavity"))
        out["Cavity"] = cav
        # Two tiny cubes the game uses to find "up" and "front" whatever the
        # importer did (turned, scaled): top center and front center of the
        # block. Blender axes here: Roblox Y (up) = Blender Z, Roblox -Z
        # (front) = Blender +Y.
        for mark, where in (
            ("MarkUp", Vector((0, 0, R6[part][1] / 2))),
            ("MarkFront", Vector((0, R6[part][2] / 2, 0))),
        ):
            mk = box_object(mark, (0.03, 0.03, 0.03))
            mk.data.transform(Matrix.Translation(where))
            mk.data.materials.append(material("Bounds"))
            out[mark] = mk
        bnd = box_object("Bounds", R6[part])
        bnd.data.materials.append(material("Bounds"))
        out["Bounds"] = bnd
        built[part] = out

        # 4. export
        bpy.ops.object.select_all(action="DESELECT")
        for ob in out.values():
            ob.select_set(True)
        bpy.ops.export_scene.fbx(
            filepath=f"{OUT}/Anatomy_{part}.fbx",
            use_selection=True,
            object_types={"MESH"},
            mesh_smooth_type="OFF",
            use_mesh_modifiers=False,
            axis_forward="-Z",
            axis_up="Y",
            apply_scale_options="FBX_SCALE_UNITS",
            bake_space_transform=True,
            path_mode="STRIP",
        )
        # hide this part's objects from the next exports
        for ob in out.values():
            ob.select_set(False)
            ob.name = f"{part}_{ob.name}"

    if PREVIEW:
        render_preview(built)


# --- Preview (Cycles on the CPU, no screen needed) ------------------------------
LAYOUT = {  # where each part sits in the preview, Blender axes, studs
    "Head": (0, 0, 2.0 + 0.6),
    "Torso": (0, 0, 1.0),
    "RightArm": (-1.5, 0, 1.0),  # body looks toward +Y here: its right is -X
    "LeftArm": (1.5, 0, 1.0),
    "RightLeg": (-0.5, 0, -1.0),
    "LeftLeg": (0.5, 0, -1.0),
}


def render_preview(built):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.render.resolution_x, scene.render.resolution_y = 1100, 900
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.08, 0.08, 0.09, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scene.world = world
    for part, objs in built.items():
        for layer, ob in objs.items():
            ob.location = LAYOUT[part]
            ob.hide_render = layer in ("Bounds", "Cavity")
    light = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
    light.data.energy = 3.5
    light.rotation_euler = (math.radians(50), math.radians(10), math.radians(200))
    scene.collection.objects.link(light)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 6.4
    scene.collection.objects.link(cam)
    scene.camera = cam
    for view, loc, rotz in (("front", (0, 12, 0.4), 180), ("side", (-12, 0, 0.4), -90)):
        cam.location = loc
        cam.rotation_euler = (math.radians(90), 0, math.radians(rotz))
        scene.render.filepath = f"{OUT}/preview_{view}.png"
        bpy.ops.render.render(write_still=True)


main()
