"""
Takes the head's anatomy out of Z-Anatomy (https://www.z-anatomy.com,
CC BY-SA 4.0) for the bat finisher's burst head (tools/wounds/gore.py):
the bones of the skull, the brain, the lower jaw, the teeth, the eyes and the
top two vertebrae of the neck.

    venv/bin/python -I tools/wounds/extract_anatomy.py <Z-Anatomy/Startup.blend>

Writes tools/wounds/anatomy/head.npz (small: decimated meshes, already in the
classic Roblox head's space, studs):
  X right of the character, Y up, Z toward the back (its face looks at -Z),
  origin = the head's centre. The skull is stretched to fill the classic
  head (it is wider and shorter than a real one).
Only needed again to change what is taken; gore.py reads the .npz.
"""

import re
import sys

import bpy  # noqa: I001 (first: it makes the other Blender modules importable)
import numpy as np
from mathutils import Vector

BLEND = sys.argv[-1]
OUT = "tools/wounds/anatomy/head.npz"

# name -> (pattern on Z-Anatomy object names, triangles to keep for ALL of
# them together, keep each object apart?)
GROUPS = {
    "cranium": (
        r"^(Frontal bone|Parietal bone\.[lr]|Occipital bone|Temporal bone\.[lr]|Sphenoid bone"
        r"|Zygomatic bone\.[lr]|Maxilla\.[lr]|Nasal bone\.[lr])$",
        16000,
        False,
    ),
    "brain": (
        r"(gyr|Insula|Midbrain|Lingula of cerebellum|Tonsil of cerebellum|Superior cerebellar peduncle)",
        14000,
        False,
    ),
    "mandible": (r"^Mandible$", 3500, False),
    "lowerteeth": (r"^Lower .*(incisor|canine|premolar|molar)", 2800, True),
    "upperteeth": (r"^Upper .*(incisor|canine|premolar|molar)", 2800, True),
    "sclera": (r"^Sclera\.[lr]$", 900, True),
    "iris": (r"^Anterior segment of eyeball\.[lr]$", 400, True),
    "vertebrae": (r"^(Atlas \(C1\)|Axis \(C2\))$", 2400, False),
}

# The real head (Z-Anatomy, metres, Z up, -Y = the face) -> the classic
# head (1.2 studs; the skull a little inside it, under the skin).
CENTER = Vector((0.0, -0.007, 1.6005))
SCALE = Vector((7.5, 5.3, 5.1))  # across, up, front-back


def to_head(p):
    d = p - CENTER
    # anatomical right (x < 0) -> the character's right (+X); up -> Y; front (-y) -> -Z
    return (-d.x * SCALE.x, d.z * SCALE.y, d.y * SCALE.z)


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    arrays = {}
    for group, (pattern, budget, apart) in GROUPS.items():
        rx = re.compile(pattern, re.I)
        found = []
        for ob in bpy.data.objects:
            if ob.type != "MESH" or not rx.search(ob.name):
                continue
            world = ob.matrix_world
            if min((world @ Vector(c)).z for c in ob.bound_box) < 1.45:
                continue  # (the brain pattern: only what is in the head)
            mesh = ob.evaluated_get(depsgraph).to_mesh().copy()
            mesh.transform(world)
            found.append((ob.name, mesh))
        total = sum(len(m.polygons) for _n, m in found) or 1
        meshes = []
        for name, mesh in found:
            temp = bpy.data.objects.new("tmp", mesh)
            bpy.context.scene.collection.objects.link(temp)
            # (triangles first: Z-Anatomy has n-gons)
            tri = temp.modifiers.new("t", "TRIANGULATE")
            dec = temp.modifiers.new("d", "DECIMATE")
            dec.ratio = min(1.0, budget / total)
            evaluated = temp.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
            evaluated.calc_loop_triangles()
            v = np.array([to_head(vx.co) for vx in evaluated.vertices], dtype=np.float32)
            f = np.array([tuple(t.vertices) for t in evaluated.loop_triangles], dtype=np.int32)
            temp.modifiers.remove(tri)
            temp.modifiers.remove(dec)
            if len(f):
                meshes.append((name, v, f))
        if not apart and meshes:
            base = 0
            vs, fs = [], []
            for _n, v, f in meshes:
                vs.append(v)
                fs.append(f + base)
                base += len(v)
            meshes = [(group, np.vstack(vs), np.vstack(fs))]
        for index, (name, v, f) in enumerate(meshes):
            arrays[f"{group}__{index}__v"] = v
            arrays[f"{group}__{index}__f"] = f
            print(group, index, name, len(v), "verts", len(f), "tris")
    np.savez_compressed(OUT, **arrays)
    print("wrote", OUT)


main()
