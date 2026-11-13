# Preview of Dr. Rift's burns on an R6 body (blocks and a round head),
# rendered in Blender (Cycles), to compare with real burns. The pictures
# (assets/burns/*.png, from make_burns.py) are laid out the way
# src/client/Combat/RiftBurn.luau does it: fire in a band along every part,
# the same height on its four sides, big overlapping pictures and a soot
# halo; acid where it landed, running down, a few small splashes; small
# flat plates on the head. "fallback" draws instead the simpler patches the
# game shows while BURN_IMAGES is empty (overlapping flattened ovals).
#
#   venv/bin/python -I tools/burns/preview_burns.py <assets/burns> <out prefix> <fire|acid> <seed> [fallback]
#
# Writes <out prefix>_0.png (whole body), _1.png (torso and arm), _2.png
# (legs, close).
import math
import os
import random
import sys

import bpy
import numpy as np
from PIL import Image

ASSETS, OUT, KIND, SEED = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
FALLBACK = len(sys.argv) > 5 and sys.argv[5] == "fallback"
PPS = 160  # pixels per stud, as in the game
SKIN = np.array([206, 160, 128]) / 255
rng = random.Random(SEED)
PARTS = {  # name: (size xyz, centre), Roblox axes (Y up, front -Z)
    "Torso": ((2, 2, 1), (0, 3, 0)),
    "Right Arm": ((1, 2, 1), (1.5, 3, 0)),
    "Left Arm": ((1, 2, 1), (-1.5, 3, 0)),
    "Right Leg": ((1, 2, 1), (0.5, 1, 0)),
    "Left Leg": ((1, 2, 1), (-0.5, 1, 0)),
}
HEAD_CENTRE, HEAD_RADIUS, HEAD_HALF = (0, 4.6, 0), 0.6, 0.32
WEIGHT = {"Torso": 1, "Right Arm": 0.7, "Left Arm": 0.7, "Right Leg": 0.58, "Left Leg": 0.58}
SIDES = ["Front", "Back", "Left", "Right"]
BAND = {"Torso": 0.6, "Right Arm": 0.55, "Left Arm": 0.55, "Right Leg": 0.5, "Left Leg": 0.5}
FIRE_CELL = 1.2
HEAD_PICTURE = 0.32
HALO_FIRE, HALO_ACID = (70, 46, 36), (150, 84, 70)


def face_size(name, face):
    sx, sy, sz = PARTS[name][0]
    return (sz, sy) if face in ("Left", "Right") else (sx, sy)


imgs = {k: [Image.open(f"{ASSETS}/{k}_{i}.png").convert("RGBA") for i in (1, 2, 3)] for k in ("acid", "fire")}
halo_img = Image.open(f"{ASSETS}/burn_halo.png").convert("RGBA")
pictures = {}  # (name, face) -> [(layer, image, colour, transparency, size, at, rotation)]
head_plates = []  # (angle, height, size, image, colour, transparency, layer)


def burn(name, face, at, size, drip):
    flip = 0 if drip or rng.random() < 0.5 else 180
    shade = rng.uniform(0.88, 1)
    pictures.setdefault((name, face), []).append(
        (rng.randint(2, 4), rng.choice(imgs[KIND]), (int(255 * shade),) * 3, rng.uniform(0, 0.08), size, at, flip + rng.uniform(-8, 8))
    )


def halo(name, face, at, size):
    fire = KIND == "fire"
    pictures.setdefault((name, face), []).append(
        (1, halo_img, HALO_FIRE if fire else HALO_ACID, 0.45 if fire else 0.62, size, at, rng.uniform(-8, 8))
    )


def on_head():
    angle = rng.uniform(0, 2 * math.pi)
    top = HEAD_HALF - 0.08
    height = rng.uniform(-top, top)
    head_plates.append((angle, height, HEAD_PICTURE * 1.35, halo_img, HALO_FIRE if KIND == "fire" else HALO_ACID, 0.5, 1))
    head_plates.append((angle, height, HEAD_PICTURE, rng.choice(imgs[KIND]), (245, 245, 245), 0.04, 2))


def plan_pictures():
    if KIND == "fire":
        for name in ["Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"]:
            if name == "Head":
                for _ in range(3):
                    on_head()
                continue
            height = PARTS[name][0][1]
            length = height * rng.uniform(BAND[name], 1)
            top = rng.uniform(0, height - length)
            for face in SIDES:
                w, _ = face_size(name, face)
                columns = max(1, round(w))
                rows = max(1, math.ceil(length / FIRE_CELL))
                cx, cy = w / columns, length / rows
                halo(name, face, (w / 2, top + length / 2 + rng.uniform(-0.1, 0.1)), (w * 1.7, length * 1.35 + 0.4))
                for c in range(columns):
                    for r in range(rows):
                        width = cx * rng.uniform(1.75, 2)
                        size = (width, max(cy * rng.uniform(1.8, 2.2), width * rng.uniform(1.1, 1.3)))
                        at = (cx * (c + 0.5) + rng.uniform(-0.12, 0.12) * cx, top + cy * (r + 0.5) + rng.uniform(-0.18, 0.18) * cy)
                        burn(name, face, at, size, False)
        return
    # acid: the torso and the right arm hit, a few small splashes
    for name in ["Torso", "Right Arm"]:
        faces = ["Front", "Back"] if name == "Torso" else ["Front", "Right"]
        for face in faces:
            w, h = face_size(name, face)
            s = rng.uniform(1.1, 1.6)
            size = (s, s * rng.uniform(1.3, 1.7))
            top = h * rng.uniform(0.02, 0.3)
            at = (w * rng.uniform(0.35, 0.65), top + size[1] / 2)
            halo(name, face, at, (size[0] * 1.35, size[1] * 1.35))
            burn(name, face, at, size, True)
    on_head()
    for _ in range(3):
        name = rng.choice(list(PARTS))
        face = rng.choice(SIDES)
        w, h = face_size(name, face)
        s = rng.uniform(0.45, 0.7)
        size = (s, s * rng.uniform(1.2, 1.6))
        at = (w * rng.uniform(0.25, 0.75), h * rng.uniform(0.15, 0.6))
        halo(name, face, at, (size[0] * 1.35, size[1] * 1.35))
        burn(name, face, at, size, True)


def paste(canvas, piece, x, y):
    """Composites `piece` at (x, y), clipped to the canvas (the face edge)."""
    big = Image.new("RGBA", (canvas.width + 2 * piece.width, canvas.height + 2 * piece.height), (0, 0, 0, 0))
    big.paste(canvas, (piece.width, piece.height))
    big.alpha_composite(piece, (x + piece.width, y + piece.height))
    canvas.paste(big.crop((piece.width, piece.height, piece.width + canvas.width, piece.height + canvas.height)))


def draw(canvas, items):
    for layer, im, color, alpha, size, at, rot in sorted(items, key=lambda p: p[0]):
        pw, ph = max(int(size[0] * PPS), 1), max(int(size[1] * PPS), 1)
        arr = np.array(im.resize((pw, ph), Image.LANCZOS)).astype(float)
        arr[..., :3] *= np.array(color) / 255
        arr[..., 3] *= 1 - alpha
        piece = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA").rotate(-rot, expand=True, resample=Image.BICUBIC)
        paste(canvas, piece, int(at[0] * PPS - piece.width / 2), int(at[1] * PPS - piece.height / 2))


def tinted(name):
    k = (0.28 if KIND == "fire" else 0.2) if not FALLBACK else (0.55 if KIND == "fire" else 0.38)
    tint = np.array([40, 28, 22] if KIND == "fire" else [184, 96, 80]) / 255
    return SKIN * (1 - k * WEIGHT.get(name, 0.7)) + tint * k * WEIGHT.get(name, 0.7)


def face_texture(name, face):
    w, h = face_size(name, face)
    base = tinted(name)
    canvas = Image.new("RGBA", (int(w * PPS), int(h * PPS)), tuple(int(c * 255) for c in base) + (255,))
    draw(canvas, pictures.get((name, face), []))
    return canvas


# --- the fallback: patches of overlapping flattened ovals (RiftBurn addMarks)
CHAR, CHAR_PURPLE, SCORCH = (26, 16, 16), (54, 32, 36), (84, 52, 38)
SHEEN, GLOW = (150, 116, 112), (255, 92, 20)
RAW, RAW_DEEP, CRUST, SLOUGH = (156, 56, 44), (110, 38, 30), (84, 30, 20), (204, 158, 128)
MARKS = {"Torso": 4, "Head": 2, "Right Arm": 2, "Left Arm": 2, "Right Leg": 1, "Left Leg": 1}


def plan_fallback():
    """[(part, face, centre (u, v) studs on the face, radius, [(scale, dx, dy, stretch, spin, colour, alpha, glossy)])]"""
    marks = []
    fire = KIND == "fire"
    for name, count in MARKS.items():
        if name == "Head":
            continue
        for _ in range(count):
            radius = rng.uniform(0.28, 0.55) if name == "Torso" else rng.uniform(0.22, 0.42)
            face = rng.choice(SIDES)
            w, h = face_size(name, face)
            fit = min(radius, w * 0.45, h * 0.45)
            at = (rng.uniform(fit, w - fit), rng.uniform(fit, h - fit))
            j = lambda: rng.uniform(-0.32, 0.32)
            L = []

            def layer(scale, dx, dy, color, alpha, glossy=False, stretch=None, spin=None):
                L.append((scale, dx, dy, stretch or rng.uniform(0.5, 1), spin if spin is not None else rng.uniform(0, 6.28), color, alpha, glossy))

            if fire:
                layer(0.95, j() * 0.3, j() * 0.3, SCORCH, 0.5)
                layer(0.75, j(), j(), SCORCH, 0.4)
                for clump in range(1, rng.randint(2, 3) + 1):
                    layer(rng.uniform(0.3, 0.55), j(), j(), CHAR_PURPLE if clump == 2 else CHAR, rng.uniform(0.05, 0.25))
                if rng.random() < 0.45:
                    layer(rng.uniform(0.14, 0.24), j(), j(), SHEEN, 0.2, True)
                if rng.random() < 0.45:
                    layer(rng.uniform(0.08, 0.16), j(), j(), CHAR, 0.15)  # (a glowing speck, cooled down)
            else:
                layer(0.95, j() * 0.3, j() * 0.3, CRUST, 0.3, True)
                for _ in range(rng.randint(1, 2)):
                    layer(rng.uniform(0.5, 0.75), j() * 0.6, j() * 0.6, RAW if rng.random() < 0.5 else RAW_DEEP, 0.05, True)
                for _ in range(rng.randint(1, 2)):
                    long = rng.uniform(0.7, 1.2)
                    layer(rng.uniform(0.18, 0.28), j() * 1.4, -long * 0.9, RAW_DEEP, 0.1, True, long / 0.25, 0)
                if rng.random() < 0.4:
                    layer(rng.uniform(0.12, 0.22), j(), j(), SLOUGH, 0.15, True)
            marks.append((name, face, at, fit, L))
    return marks


# ---- Blender scene
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.device = "CPU"
scene.render.resolution_x, scene.render.resolution_y = 1000, 1000
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.37, 0.4, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
tmp = os.path.join(os.path.dirname(os.path.abspath(OUT)), "tex")
os.makedirs(tmp, exist_ok=True)


def material(name, path=None, rgb=None, alpha=False, roughness=0.75):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = roughness
    if path:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(path)
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha:
            m.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    else:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    return m


def quad(verts, mat):
    mesh = bpy.data.meshes.new("q")
    mesh.from_pydata(verts, [], [(0, 1, 2, 3)])
    uv = mesh.uv_layers.new()
    for i, c in enumerate([(0, 0), (1, 0), (1, 1), (0, 1)]):
        uv.data[i].uv = c
    obj = bpy.data.objects.new("q", mesh)
    obj.data.materials.append(mat)
    scene.collection.objects.link(obj)
    return obj


def B(p):
    """Roblox (x, y, z) -> Blender (x, z, y): Z up, Roblox front (-Z) -> Blender -Y."""
    return (p[0], p[2], p[1])


def face_frame(name, face):
    """Origin (top left corner of the face), right and down axes, outward normal (Roblox space)."""
    (sx, sy, sz), c = PARTS[name]
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    c = np.array(c, float)
    return {
        "Front": (c + (-hx, hy, -hz), np.array((1, 0, 0.0)), np.array((0, -1, 0.0)), np.array((0, 0, -1.0))),
        "Back": (c + (hx, hy, hz), np.array((-1, 0, 0.0)), np.array((0, -1, 0.0)), np.array((0, 0, 1.0))),
        "Right": (c + (hx, hy, -hz), np.array((0, 0, 1.0)), np.array((0, -1, 0.0)), np.array((1, 0, 0.0))),
        "Left": (c + (-hx, hy, hz), np.array((0, 0, -1.0)), np.array((0, -1, 0.0)), np.array((-1, 0, 0.0))),
    }[face]


if FALLBACK:
    marks = plan_fallback()
else:
    plan_pictures()

skinmat = {}
for name, ((sx, sy, sz), c) in PARTS.items():
    for face in SIDES:
        o, right, down, _ = face_frame(name, face)
        w, h = face_size(name, face)
        tex = face_texture(name, face)
        path = f"{tmp}/{KIND}_{name.replace(' ', '')}_{face}.png"
        tex.save(path)
        verts = [o + down * h, o + down * h + right * w, o + right * w, o]  # uv (0,0) bottom left
        quad([B(v) for v in verts], material(path, path))
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    m = material("skin_" + name, rgb=tuple(tinted(name) ** 2.2))
    cx, cy, cz = c
    quad([B((cx - hx, cy + hy, cz - hz)), B((cx + hx, cy + hy, cz - hz)), B((cx + hx, cy + hy, cz + hz)), B((cx - hx, cy + hy, cz + hz))], m)

# the head: a cylinder, its plates just outside it
bpy.ops.mesh.primitive_cylinder_add(radius=HEAD_RADIUS, depth=0.9, location=B(HEAD_CENTRE), vertices=48)
bpy.context.object.data.materials.append(material("head", rgb=tuple(tinted("Head") ** 2.2)))
for i, (angle, height, size, im, color, alpha, layer) in enumerate(head_plates):
    n = np.array((math.sin(angle), 0, math.cos(angle)))
    across = np.cross((0, 1, 0), n)
    centre = np.array(HEAD_CENTRE) + n * (HEAD_RADIUS + 0.003 + 0.0015 * layer) + np.array((0, height, 0))
    arr = np.array(im.resize((256, 256), Image.LANCZOS)).astype(float)
    arr[..., :3] *= np.array(color) / 255
    arr[..., 3] *= 1 - alpha
    path = f"{tmp}/{KIND}_head_{i}.png"
    Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA").save(path)
    m = material(f"plate{i}", path, alpha=True)
    hs = size / 2
    verts = [centre - across * hs - (0, hs, 0), centre + across * hs - (0, hs, 0), centre + across * hs + (0, hs, 0), centre - across * hs + (0, hs, 0)]
    quad([B(v) for v in verts], m)

if FALLBACK:
    for name, face, at, fit, layers in marks:
        o, right, down, normal = face_frame(name, face)
        centre = o + right * at[0] + down * at[1]
        thick = 0.07
        for k, (scale, dx, dy, stretch, spin, color, alpha, glossy) in enumerate(layers):
            width = fit * 2 * scale
            p = centre + right * dx * fit - down * dy * fit + normal * (thick * 0.18)
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, location=B(p), segments=24, ring_count=12)
            ob = bpy.context.object
            ob.scale = (width, width * stretch, thick + 0.004 * k)
            # turn the oval into the face's plane (its Z out along the normal)
            z = normal
            x = right * math.cos(spin) - down * math.sin(spin)
            y = np.cross(z, x)
            M = np.array([B(x), B(y), B(z)]).T
            ob.rotation_mode = "QUATERNION"
            from mathutils import Matrix

            ob.rotation_quaternion = Matrix(M.tolist()).to_quaternion()
            mat = material(f"m{name}{k}", rgb=tuple((np.array(color) / 255) ** 2.2), roughness=0.3 if glossy else 0.85)
            mat.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 1 - alpha
            ob.data.materials.append(mat)

floor_mat = material("floor", rgb=(0.3, 0.3, 0.3))
bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
bpy.context.object.data.materials.append(floor_mat)
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.2
sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
views = [((-5.5, -9.5, 4.2), (0, 0, 2.7), 40), ((3.6, -4.8, 3.9), (0.9, 0, 3.4), 40), ((-1.6, -4.5, 1.6), (0, 0, 1.2), 42)]
for i, (loc, target, lens) in enumerate(views):
    cam.location = loc
    cam.data.lens = lens
    d = np.array(target) - np.array(loc)
    cam.rotation_euler = (math.atan2(math.hypot(d[0], d[1]), -d[2]), 0, math.atan2(d[1], d[0]) - math.pi / 2)
    scene.render.filepath = f"{OUT}_{i}.png"
    bpy.ops.render.render(write_still=True)
