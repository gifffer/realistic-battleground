"""
Renders pictures of the exported anatomy FBX files (checks the export too:
it re-imports them like Roblox would).

    venv/bin/python tools/anatomy/preview_anatomy.py <dir with Anatomy_*.fbx> <out.png> [view] [hide,layers]

view = front | side | back | head (3/4 close-up of the head), default front. Hidden layers, comma separated,
e.g. "Muscle" to see the bones and organs under the muscles.
"""

import math
import sys

import bpy  # first: it makes the other Blender modules importable

argv = sys.argv[1:]
SRC, OUT = argv[0], argv[1]
VIEW = argv[2] if len(argv) > 2 else "front"
HIDE = set(argv[3].split(",")) if len(argv) > 3 and argv[3] else set()

COLORS = {
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
}
# Roblox offsets of each part from the torso center (studs, X right, Y up),
# turned into Blender axes after import (X stays, Roblox Y -> Blender Z).
LAYOUT = {
    "Head": (0, 1.6),
    "Torso": (0, 0),
    "RightArm": (1.55, 0),
    "LeftArm": (-1.55, 0),
    "RightLeg": (0.5, -2.05),
    "LeftLeg": (-0.5, -2.05),
}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
for part, (x, y) in LAYOUT.items():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=f"{SRC}/Anatomy_{part}.fbx")
    for ob in set(bpy.data.objects) - before:
        name = ob.name.split(".")[0]  # "Muscle_FrontLeft"
        layer = name.split("_")[0]  # "Muscle"
        if layer == "Bounds":
            print(part, "Bounds size (Blender X,Y,Z):", [round(d, 3) for d in ob.dimensions])
        if layer in ("Bounds", "Cavity", "MarkUp", "MarkFront") or layer in HIDE or name in HIDE:
            ob.hide_render = True
            continue
        ob.location.x += x
        ob.location.z += y
        mat = bpy.data.materials.new(layer)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*COLORS.get(layer, (1, 0, 1)), 1)
        bsdf.inputs["Roughness"].default_value = 0.5
        ob.data.materials.clear()
        ob.data.materials.append(mat)

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 24
scene.render.resolution_x, scene.render.resolution_y = 900, 1000
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.1, 0.1, 0.11, 1)
scene.world = world
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 6.0
scene.collection.objects.link(cam)
scene.camera = cam
# After import (Y-up FBX -> Blender Z-up) the character looks toward Blender +Y.
views = {
    "front": ((0, 20, 0), (90, 0, 180)),
    "back": ((0, -20, 0), (90, 0, 0)),
    "side": ((20, 0, 0), (90, 0, 90)),  # from the character's right
    "head": ((-14, 14, 1.6 + 1.95), (84.4, 0, 180 + 45)),  # front-left 3/4, above
}
loc, rot = views[VIEW]
cam.location = loc
cam.rotation_euler = tuple(math.radians(a) for a in rot)
if VIEW == "head":
    cam.data.ortho_scale = 1.9
sun.rotation_euler = (math.radians(55), 0, math.radians(rot[2] + 25))
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
