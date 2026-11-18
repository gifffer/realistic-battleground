"""citykit: the shared toolkit of the city's code-made scenery (tools/city/alleys.py and the
prop libraries props_*.py next to it).

  • Data           the rows of a city data file (same format as CityData / AlleyData).
  • Frame          a local frame (origin + turn about Y, optionally a full turn) to build a
                   prop in its own space: f.box(...), f.part(...) place parts relative to it.
  • preview(...)   renders a Data (or a part of it) with Blender Cycles, to LOOK at a prop.

Coordinates are Roblox studs: X east, Y up, Z south (-Z = north = a part's LookVector).
A part's rotation is CFrame.fromEulerAnglesYXZ(rx, ry, rz) in degrees (as City/init reads it).
Shapes: 1 Block, 2 Wedge, 3 Cylinder (its axis is the part's X), 4 Ball.
Flags: 1 collide, 2 query, 4 cast shadow.

Rules for props (realism, performance):
  • Build from several parts with slight irregularities (a few degrees of tilt, uneven
    sizes, worn edges as thin darker parts), never one clean box.
  • Small things: DECOR (no collision); things a player stands on / bumps into: PROP or SOLID.
  • Only built-in materials (no texture ids): Brick, Concrete, Cobblestone, CorrodedMetal,
    DiamondPlate, Fabric, Granite, Grass, Ground, Leather, Metal, Pebble, Plastic, Rubber,
    Sand, Slate, SmoothPlastic, Wood, WoodPlanks, Asphalt, Limestone, Glass, Neon...
  • Colours: desaturated, dirty, never pure. Use jitter() for variety.
  • NO BOTTLES of any kind anywhere (the player's absolute rule for the alleys).
"""

import json
import math
import os
import random

import numpy as np

COLLIDE, QUERY, SHADOW = 1, 2, 4
SOLID = COLLIDE | QUERY | SHADOW
PROP = COLLIDE | QUERY | SHADOW
SMALL = COLLIDE | QUERY  # small solid things: no shadow (cheaper)
DECOR = 0  # no collision, no query, no shadow
DECOR_SHADOW = SHADOW  # decoration that still casts a shadow
GHOST = COLLIDE  # invisible walls

BLOCK, WEDGE, CYLINDER, BALL = 1, 2, 3, 4


class Data:
    def __init__(self):
        self.colors, self.materials, self.folders, self.names = [], [], [], []
        self.parts, self.extras, self.remove = [], [], []
        self._index = {"c": {}, "m": {}, "f": {}, "n": {}}

    def _idx(self, kind, table, value):
        key = json.dumps(value)
        found = self._index[kind].get(key)
        if found is None:
            table.append(list(value) if isinstance(value, tuple) else value)
            found = len(table)
            self._index[kind][key] = found
        return found

    def part(self, folder, name, center, size, color, material, flags=SOLID, rot=(0, 0, 0), shape=BLOCK,
             transparency=0.0, reflectance=0.0, extra=None, parent=0):
        color = tuple(int(max(0, min(255, round(c)))) for c in color)
        row = [
            shape,
            round(center[0], 3), round(center[1], 3), round(center[2], 3),
            round(rot[0], 2), round(rot[1], 2), round(rot[2], 2),
            round(max(size[0], 0.05), 3), round(max(size[1], 0.05), 3), round(max(size[2], 0.05), 3),
            self._idx("c", self.colors, color),
            self._idx("m", self.materials, material),
            transparency, reflectance, flags,
            self._idx("f", self.folders, folder),
            self._idx("n", self.names, name),
            parent,
            0,
        ]
        if extra:
            self.extras.append(extra)
            row[18] = len(self.extras)
        self.parts.append(row)
        return len(self.parts)

    def box(self, folder, name, x0, x1, y0, y1, z0, z1, color, material, **kw):
        """An axis-aligned block from its bounds."""
        return self.part(folder, name, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
                         (x1 - x0, y1 - y0, z1 - z0), color, material, **kw)

    def to_json(self):
        return {
            "colors": self.colors, "materials": self.materials, "folders": self.folders,
            "names": self.names, "parts": self.parts, "extras": self.extras, "remove": self.remove,
        }


# ------------------------------------------------------------------ rotations
def _rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def _ry(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def _rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def yxz_matrix(rx, ry, rz):
    """CFrame.fromEulerAnglesYXZ(rx, ry, rz) (degrees) as a matrix: Ry * Rx * Rz."""
    return _ry(math.radians(ry)) @ _rx(math.radians(rx)) @ _rz(math.radians(rz))


def yxz_angles(m):
    """The (rx, ry, rz) degrees of a rotation matrix, for fromEulerAnglesYXZ."""
    sx = -m[1, 2]
    sx = max(-1.0, min(1.0, sx))
    rx = math.asin(sx)
    if abs(sx) < 0.99999:
        ry = math.atan2(m[0, 2], m[2, 2])
        rz = math.atan2(m[1, 0], m[1, 1])
    else:  # gimbal: put everything in ry
        ry = math.atan2(-m[2, 0], m[0, 0])
        rz = 0.0
    return (math.degrees(rx), math.degrees(ry), math.degrees(rz))


class Frame:
    """A local frame to build a prop in its own space.

        f = Frame(D, "Alleys/Props", origin=(x, y, z), ry=30)       # turned 30 deg about Y
        f.box("Crate", (-1, 0, -1), (1, 2, 1), color, "WoodPlanks")  # local bounds
        f.part("Lid", (0, 2.1, 0), (2, 0.2, 2), color, "Wood", rot=(5, 0, 0))
        g = f.sub((0, 2, 0), ry=15, rx=3)                             # a child frame

    Local axes: +X right, +Y up, -Z forward (the prop's front faces -Z when ry = 0).
    """

    def __init__(self, data, folder, origin=(0, 0, 0), ry=0.0, rx=0.0, rz=0.0, matrix=None):
        self.D = data
        self.folder = folder
        self.origin = np.array(origin, dtype=float)
        self.m = matrix if matrix is not None else yxz_matrix(rx, ry, rz)

    def world(self, p):
        return self.origin + self.m @ np.array(p, dtype=float)

    def part(self, name, center, size, color, material, rot=(0, 0, 0), folder=None, **kw):
        m = self.m @ yxz_matrix(*rot)
        c = self.world(center)
        return self.D.part(folder or self.folder, name, tuple(c), size, color, material, rot=yxz_angles(m), **kw)

    def box(self, name, lo, hi, color, material, rot=(0, 0, 0), **kw):
        center = [(a + b) / 2 for a, b in zip(lo, hi)]
        size = [abs(b - a) for a, b in zip(lo, hi)]
        return self.part(name, center, size, color, material, rot=rot, **kw)

    def sub(self, offset, ry=0.0, rx=0.0, rz=0.0):
        return Frame(self.D, self.folder, self.world(offset), matrix=self.m @ yxz_matrix(rx, ry, rz))


# ------------------------------------------------------------------ colours
def jitter(color, rng, amount=8, darken=0.0):
    """A colour a little different each time (and optionally darker): no two alike."""
    k = 1 - darken
    return tuple(max(0, min(255, (c + rng.uniform(-amount, amount)) * k)) for c in color)


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


# ------------------------------------------------------------------ preview
_PREVIEW = r'''
import bpy, json, math, sys
from mathutils import Matrix, Vector
data = json.load(open(sys.argv[sys.argv.index("--") + 1]))
cams = json.load(open(sys.argv[sys.argv.index("--") + 2]))
out = sys.argv[sys.argv.index("--") + 3]
night = sys.argv[sys.argv.index("--") + 4] == "night"
samples = int(sys.argv[sys.argv.index("--") + 5])
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = samples
sc.cycles.use_denoising = False; sc.cycles.max_bounces = 4
sc.render.resolution_x, sc.render.resolution_y = 900, 600
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.04, 0.05, 0.08, 1) if night else (0.6, 0.64, 0.7, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.35 if night else 1.0
if not night:
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(40), math.radians(15), math.radians(130)); sc.collection.objects.link(sun)
mats = {}
ROUGH = {"Metal": 0.35, "Glass": 0.05, "SmoothPlastic": 0.5, "Plastic": 0.55, "Neon": 0.5, "DiamondPlate": 0.4}
def mat(rgb, name, tr):
    key = (tuple(rgb), name, tr)
    if key in mats: return mats[key]
    m = bpy.data.materials.new(str(len(mats))); m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    c = tuple((v / 255) ** 2.2 for v in rgb) + (1,)  # (Roblox colours are sRGB)
    p.inputs["Base Color"].default_value = c
    p.inputs["Roughness"].default_value = ROUGH.get(name, 0.85)
    if name in ("Metal", "DiamondPlate", "CorrodedMetal"): p.inputs["Metallic"].default_value = 0.6
    if name == "Neon":
        p.inputs["Emission Color"].default_value = c; p.inputs["Emission Strength"].default_value = 5
    if tr > 0:
        p.inputs["Alpha"].default_value = max(0.05, 1 - tr)
    mats[key] = m; return m
def RX(a): c,s=math.cos(a),math.sin(a); return Matrix(((1,0,0),(0,c,-s),(0,s,c)))
def RY(a): c,s=math.cos(a),math.sin(a); return Matrix(((c,0,s),(0,1,0),(-s,0,c)))
def RZ(a): c,s=math.cos(a),math.sin(a); return Matrix(((c,-s,0),(s,c,0),(0,0,1)))
C = Matrix(((1,0,0),(0,0,-1),(0,1,0)))
for r in data["parts"]:
    if r[12] >= 0.99: continue
    shape = r[0]
    if shape == 3:
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.5, depth=1); ob = bpy.context.active_object
        ob.data.transform(Matrix.Rotation(math.radians(90), 4, "Y"))
    elif shape == 4:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=16, ring_count=10); ob = bpy.context.active_object
    elif shape == 2:
        import bmesh
        me = bpy.data.meshes.new("w"); bm = bmesh.new()
        vs = [bm.verts.new(v) for v in [(-.5,-.5,-.5),(.5,-.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(-.5,.5,.5),(.5,.5,.5)]]
        # Roblox wedge (local): bottom face full, back (+Z) face full, slope from bottom-front to top-back
        for f in [(0,1,3,2),(2,3,5,4),(0,4,5,1),(0,2,4),(1,5,3)]: bm.faces.new([vs[i] for i in f])
        bm.to_mesh(me); ob = bpy.data.objects.new("w", me); sc.collection.objects.link(ob)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1); ob = bpy.context.active_object
    R = RY(math.radians(r[5])) @ RX(math.radians(r[4])) @ RZ(math.radians(r[6]))
    S = Matrix(((r[7],0,0),(0,r[8],0),(0,0,r[9])))
    Mb = C @ (R @ S) @ C.transposed()
    m4 = Matrix(((Mb[0][0],Mb[0][1],Mb[0][2],r[1]),(Mb[1][0],Mb[1][1],Mb[1][2],-r[3]),(Mb[2][0],Mb[2][1],Mb[2][2],r[2]),(0,0,0,1)))
    if shape == 2:
        # (our wedge mesh is built in Roblox local axes: convert)
        m4 = m4 @ Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
    ob.matrix_world = m4
    ob.data.materials.append(mat(data["colors"][r[10]-1], data["materials"][r[11]-1], r[12]))
    ob.visible_shadow = bool(r[14] & 4) or r[12] < 0.2 and (r[7] > 0.3 and r[8] > 0.3 and r[9] > 0.3)
    ex = data["extras"][r[18]-1] if r[18] else None
    if night and ex and ex.get("l"):
        l = ex["l"]
        ld = bpy.data.lights.new("l", "POINT" if l["type"] == "Point" else "SPOT")
        ld.color = tuple(v / 255 for v in l["color"]); ld.energy = l["brightness"] * l["range"] ** 2 * 1.2
        ld.use_shadow = bool(l.get("shadows", True)) or True
        ld.shadow_soft_size = 0.2
        lo = bpy.data.objects.new("l", ld); lo.location = (r[1], -r[3], r[2]); sc.collection.objects.link(lo)
        if l["type"] == "Spot":
            ld.spot_size = math.radians(l.get("angle", 90)); lo.location = (r[1], -r[3], r[2] - 0.5)
# floor
bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, -0.01))
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
for i, (eye, look, fov) in enumerate(cams):
    e = Vector((eye[0], -eye[2], eye[1])); l = Vector((look[0], -look[2], look[1]))
    cam.location = e; cam.rotation_euler = (l - e).to_track_quat("-Z", "Y").to_euler()
    cam.data.angle = math.radians(fov)
    sc.render.filepath = f"{out}_{i}.png"
    bpy.ops.render.render(write_still=True)
'''


def preview(data, cams, out, night=False, samples=24, python=None):
    """Renders `data` (a Data) from each camera (eye, look, fov) to out_0.png, out_1.png...
    Returns the image paths. Look at them!"""
    import subprocess
    import tempfile
    tmp = tempfile.mkdtemp()
    with open(os.path.join(tmp, "d.json"), "w") as f:
        json.dump(data.to_json(), f)
    with open(os.path.join(tmp, "c.json"), "w") as f:
        json.dump(cams, f)
    with open(os.path.join(tmp, "r.py"), "w") as f:
        f.write(_PREVIEW)
    py = python or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "venv", "bin", "python")
    subprocess.run([py, "-I", os.path.join(tmp, "r.py"), "--", os.path.join(tmp, "d.json"),
                    os.path.join(tmp, "c.json"), out, "night" if night else "day", str(samples)],
                   check=True, capture_output=True)
    return [f"{out}_{i}.png" for i in range(len(cams))]
