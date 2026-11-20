"""kitlib: the Blender toolkit of the city prop kit (CityProps.fbx).

Used by tools/city/kit/build_city_kit.py and by every family module in tools/city/kit/pieces/.
Why a mesh kit at all: the alleys' props were stacks of primitive Parts (a cone made of five
cylinders, boxes inside boxes that z-fight). Here each prop is modelled once, properly (real
silhouette, bevels, smooth shading, vertex-colour wear), exported as a few MeshParts, and the
server clones it wherever the city data puts a "MeshProp" marker (src/server/Systems/City/
PropKit.luau). The old parts stay in the data as the fallback and as the collision proxies.

THE SPACE A PIECE IS MODELLED IN (Roblox axes, units = studs):
  +Y up, the front faces -Z, +X is the right. Floor props: the origin is the centre of the
  footprint ON the floor (y = 0 is the ground). Wall props: the origin is on the wall face and
  local -Z points OUT of the wall. kitlib converts to Blender's Z-up only when it makes the
  objects (to_blender), and the exporter converts back (axis_up = Y, axis_forward = -Z).

A PIECE = a few meshes, ONE PER MATERIAL LAYER, named "<Piece>_<Layer>" (LAYERS below; the
game colours each layer from its own table, src/server/Systems/City/PropKit.luau LOOKS). Hue
lives in the game's colour (so a layer can be tinted per copy); the vertex colours are a
near-white MULTIPLIER (0.5..1.0) that paints the wear: dirt rising from the ground, ambient
occlusion in creases, scuffs, tyre marks, drips. Optional markers (small cubes):
"<Piece>_Light" where a PointLight goes, "<Piece>_Fx" where particles come out.

Main tools (see pieces/_template.py for a worked example and the checklist):
  Piece(name, seed)            ctx handed to a build function: .add(layer, bm, matrix),
                               .mark("Light", at), .wear(layer, fn), .rng, .noise
  box / cyl / lathe / loft / tube / sphere   bmesh shapes (closed, Y up, bevel options)
  bevel_edges, merge, displace               geometry helpers
  Noise(seed)                  smooth deterministic 3-D value noise (+ fbm, ridge)
  wear helpers                 ground_dirt, cavity, streaks, scuffs (combine with mul())
  make_objects(piece, at)      the Blender objects of a piece (smooth by angle + weighted
                               normals, vertex colours, UVs, preview material)
  Preview                      Cycles preview: grey floor, a 1.8 m human silhouette, day key
                               light, optional night bulb
"""

import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

# --------------------------------------------------------------------------------------------
# Layers: preview colour (sRGB 0..255), metallic, roughness, tintable, double-sided, glow.
# The GAME's colours are in PropKit.luau (LOOKS); keep the two close so previews tell the truth.
# --------------------------------------------------------------------------------------------
LAYERS = {
    "Plastic": ((150, 120, 96), 0.0, 0.45, True, False, False),
    "PlasticDark": ((38, 38, 40), 0.0, 0.5, False, False, False),
    "Rubber": ((30, 30, 31), 0.0, 0.9, False, False, False),
    "RubberWorn": ((80, 75, 70), 0.0, 0.9, False, False, False),  # old tyres: sun-greyed sidewalls
    "Reflective": ((208, 210, 206), 0.0, 0.3, False, False, False),
    "Metal": ((128, 130, 132), 0.8, 0.45, False, False, False),
    "MetalPainted": ((84, 92, 88), 0.2, 0.5, True, False, False),
    "Rust": ((98, 58, 36), 0.3, 0.85, False, False, False),
    "Wood": ((118, 92, 64), 0.0, 0.75, False, False, False),
    "WoodDark": ((66, 50, 38), 0.0, 0.8, False, False, False),
    "Fabric": ((96, 92, 84), 0.0, 0.9, True, False, False),
    "FabricDark": ((42, 40, 40), 0.0, 0.9, False, False, False),
    "Leather": ((58, 40, 30), 0.0, 0.6, False, False, False),  # dark brown
    "LeatherBlack": ((30, 29, 29), 0.0, 0.55, False, False, False),
    "Foam": ((176, 164, 132), 0.0, 0.95, False, False, False),
    "Cardboard": ((140, 110, 76), 0.0, 0.9, False, False, False),
    "Paper": ((196, 190, 174), 0.0, 0.85, False, False, False),
    "Concrete": ((128, 126, 120), 0.0, 0.9, False, False, False),
    "Brick": ((112, 64, 50), 0.0, 0.9, False, False, False),
    "Tarp": ((52, 70, 98), 0.0, 0.7, True, True, False),
    "Glass": ((60, 72, 74), 0.0, 0.1, False, False, False),
    "Screen": ((14, 16, 18), 0.0, 0.15, False, False, False),
    "Chrome": ((200, 202, 206), 1.0, 0.15, False, False, False),
    "Black": ((16, 16, 17), 0.0, 0.7, False, False, False),
    "Glow": ((255, 200, 140), 0.0, 0.5, False, False, True),
    "Soil": ((66, 54, 42), 0.0, 1.0, False, False, False),
}
LAYER_NAMES = tuple(LAYERS)
MARKER_SUFFIXES = ("Pivot", "Light", "Fx")


# --------------------------------------------------------------------------------------------
# Matrices (Roblox axes)
# --------------------------------------------------------------------------------------------
def T(x, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def R(rx=0.0, ry=0.0, rz=0.0):
    """Rotation in degrees, applied X, then Y, then Z."""
    return Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_matrix().to_4x4()


def S(x, y=None, z=None):
    y = x if y is None else y
    z = x if z is None else z
    return Matrix.Diagonal((x, y, z, 1))


# Roblox (x, y, z) -> Blender (x, -z, y): Y up becomes Z up, the front (-Z) becomes -Y.
TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def to_blender(v):
    return Vector((v[0], -v[2], v[1]))


# --------------------------------------------------------------------------------------------
# Noise: deterministic, smooth, no dependencies (a few thousand vertices per piece: fast enough)
# --------------------------------------------------------------------------------------------
class Noise:
    """3-D value noise from a seed. n(p) in [-1, 1], smooth; fbm(p, octaves) sums octaves;
    ridge(p) is 1 - |n| (thin lines, for scratches and creases)."""

    def __init__(self, seed=0):
        self.seed = int(seed) & 0x7FFFFFFF

    def _hash(self, x, y, z):
        h = (x * 374761393 + y * 668265263 + z * 2147483647 + self.seed * 1442695041) & 0xFFFFFFFF
        h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((h ^ (h >> 16)) & 0xFFFF) / 32767.5 - 1.0

    def n(self, p):
        x, y, z = p
        xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
        xf, yf, zf = x - xi, y - yi, z - zi
        u, v, w = (t * t * (3 - 2 * t) for t in (xf, yf, zf))
        h = self._hash

        def lerp(a, b, t):
            return a + (b - a) * t

        x0 = lerp(lerp(h(xi, yi, zi), h(xi + 1, yi, zi), u), lerp(h(xi, yi + 1, zi), h(xi + 1, yi + 1, zi), u), v)
        x1 = lerp(lerp(h(xi, yi, zi + 1), h(xi + 1, yi, zi + 1), u), lerp(h(xi, yi + 1, zi + 1), h(xi + 1, yi + 1, zi + 1), u), v)
        return lerp(x0, x1, w)

    def fbm(self, p, octaves=3, scale=1.0):
        total, amp, norm = 0.0, 1.0, 0.0
        q = Vector(p) * scale
        for _ in range(octaves):
            total += self.n(q) * amp
            norm += amp
            amp *= 0.5
            q = q * 2.03 + Vector((17.1, 3.7, 9.3))
        return total / norm

    def ridge(self, p, scale=1.0):
        return 1.0 - abs(self.n(Vector(p) * scale))


def smoothstep(a, b, x):
    if a == b:
        return 1.0 if x >= b else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


# --------------------------------------------------------------------------------------------
# Shapes: closed bmeshes in Roblox axes, centred on the origin unless said otherwise
# --------------------------------------------------------------------------------------------
def bevel_edges(bm, edges, width, segments=2, profile=0.5):
    """Rounds `edges` (a list of BMEdges). Real objects never have knife edges: 0.02..0.06
    studs reads well in Roblox."""
    if width > 0 and edges:
        bmesh.ops.bevel(bm, geom=list(edges), offset=width, segments=segments, profile=profile,
                        affect="EDGES", clamp_overlap=True)


def box(sx, sy, sz, bevel=0.0, segments=2):
    """A box sx * sy * sz centred on the origin, every edge rounded by `bevel`."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    bevel_edges(bm, bm.edges[:], min(bevel, sx * 0.45, sy * 0.45, sz * 0.45), segments)
    return bm


def cyl(r, h, segs=24, r2=None, bevel=0.0):
    """A cylinder (or frustum: r at the bottom, r2 at the top) round Y, centred."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r,
                          radius2=r if r2 is None else r2, depth=h)
    bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.radians(-90), 4, "X"))
    if bevel > 0:
        rim = [e for e in bm.edges if len(e.link_faces) == 2 and any(len(f.verts) > 4 for f in e.link_faces)]
        bevel_edges(bm, rim, min(bevel, h * 0.45, r * 0.45), 2)
    return bm


def sphere(r, segs=16, rings=10):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    return bm


def angles(segs, extra=()):
    """`segs` evenly spaced angles (radians) plus `extra` ones (e.g. both sides of a mould
    seam, to make a narrow ridge), sorted."""
    a = [2 * math.pi * s / segs for s in range(segs)] + [x % (2 * math.pi) for x in extra]
    a.sort()
    out = []
    for x in a:
        if not out or x - out[-1] > 1e-4:
            out.append(x)
    return out


def loft(rings, closed_profile=False, cap_start=False, cap_end=False):
    """Skins a list of rings (each a list of (x, y, z) points, all the same length, going round
    the same way) into quads. A ring of length 1 is a pole (fan). closed_profile joins the last
    ring back to the first (a torus-like solid). cap_start / cap_end close the open ends with
    one n-gon (triangulated later). This is the general tool behind lathe(): any profile swept
    round any outline (circle, rounded square...)."""
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = max(len(r) for r in vr)
    count = len(vr) if closed_profile else len(vr) - 1
    for i in range(count):
        a, b = vr[i], vr[(i + 1) % len(vr)]
        for s in range(n):
            t = (s + 1) % n
            if len(a) == 1:
                bm.faces.new((a[0], b[t], b[s]))
            elif len(b) == 1:
                bm.faces.new((a[s], a[t], b[0]))
            else:
                bm.faces.new((a[s], a[t], b[t], b[s]))
    if cap_start and len(vr[0]) > 2:
        bm.faces.new(list(reversed(vr[0])))
    if cap_end and len(vr[-1]) > 2:
        bm.faces.new(vr[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    return bm


def lathe(profile, segs=32, extra_angles=(), radius_fn=None):
    """Spins a profile [(radius, y), ...] round Y. Radius 0 = a pole. Give the outline of a
    solid going round it (start and end on the axis, or closed) so the result is closed.
    radius_fn(angle, r, y) -> r or (r, y) lets the caller dent / squash / chew the shape per
    angle (angle 0 = +X, pi/2 = +Z, the back)."""
    angs = angles(segs, extra_angles)
    rings = []
    for r, y in profile:
        if r < 1e-6:
            rings.append([(0.0, y, 0.0)])
        else:
            ring = []
            for a in angs:
                rr, yy = r, y
                if radius_fn:
                    res = radius_fn(a, r, y)
                    rr, yy = res if isinstance(res, tuple) else (res, y)
                ring.append((rr * math.cos(a), yy, rr * math.sin(a)))
            rings.append(ring)
    closed = len(profile) > 2 and profile[0][0] > 1e-6 and profile[-1][0] > 1e-6
    return loft(rings, closed_profile=closed)


def tube(points, r, segs=8, closed=False, cap=True):
    """A round tube along `points` (Roblox axes), radius r (or a list of radii)."""
    pts = [Vector(p) for p in points]
    radii = r if isinstance(r, (list, tuple)) else [r] * len(pts)
    rings = []
    prev = None
    for i, p in enumerate(pts):
        if closed:
            d = pts[(i + 1) % len(pts)] - pts[i - 1]
        else:
            d = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
        d.normalize()
        if prev is None:
            ref = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
            u = d.cross(ref).normalized()
        else:
            u = (prev - d * prev.dot(d)).normalized()
        w = d.cross(u)
        prev = u
        rings.append([tuple(p + (u * math.cos(2 * math.pi * k / segs) + w * math.sin(2 * math.pi * k / segs)) * radii[i])
                      for k in range(segs)])
    return loft(rings, closed_profile=closed, cap_start=cap and not closed, cap_end=cap and not closed)


def merge(target, bm, matrix=None):
    """Appends bm (transformed by matrix) to target and frees bm."""
    if matrix is not None:
        bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    me = bpy.data.meshes.new("_tmp")
    bm.to_mesh(me)
    bm.free()
    target.from_mesh(me)
    bpy.data.meshes.remove(me)


def displace(bm, fn):
    """Moves every vertex: fn(co: Vector) -> new co (Vector). For dents, squash, sag."""
    for v in bm.verts:
        v.co = fn(v.co.copy())


# --------------------------------------------------------------------------------------------
# Wear: functions that give a vertex its colour MULTIPLIER (1 = clean, 0.5 = filthy).
# Each takes a VertexInfo and returns a float (grey) or an (r, g, b) tuple. mul() combines.
# Wear comes from POSITION, never at random: dirt rises from the ground, grime sits in creases,
# scuffs on corners and edges, streaks run down.
# --------------------------------------------------------------------------------------------
class VertexInfo:
    __slots__ = ("co", "normal", "convex")

    def __init__(self, co, normal, convex):
        self.co, self.normal, self.convex = co, normal, convex


def ground_dirt(height=0.6, strength=0.35, noise=None, scale=3.0):
    """Darker toward the floor: 1 - strength at y = 0 fading to 1 at y = height, broken up by
    noise so the line is never straight."""

    def fn(p):
        h = height * (1 + (0.35 * noise.fbm(p.co, 2, scale) if noise else 0))
        return 1 - strength * (1 - smoothstep(0, max(h, 1e-3), p.co.y))

    return fn


def cavity(strength=0.3):
    """Ambient occlusion in creases (concave vertices), from VertexInfo.convex (< 0 = concave)."""

    def fn(p):
        return 1 - strength * smoothstep(0.0, 0.5, -p.convex)

    return fn


def edge_wear(strength=0.12):
    """Convex edges a little lighter (paint rubbed, dust caught)."""

    def fn(p):
        return 1 + strength * smoothstep(0.05, 0.5, p.convex)

    return fn


def streaks(noise, strength=0.25, width=6.0, top=None):
    """Vertical dirt streaks (rain drips), stretched along Y."""

    def fn(p):
        q = (p.co.x * width, p.co.y * 0.35, p.co.z * width)
        s = smoothstep(0.15, 0.7, noise.fbm(q, 2))
        if top is not None:
            s *= 1 - smoothstep(top - 0.3, top, p.co.y)
        return 1 - strength * s

    return fn


def scuffs(noise, strength=0.4, scale=4.0, threshold=0.55):
    """Patchy dark scuffs (rubbed dirt, tyre rubber) where the noise is high."""

    def fn(p):
        s = smoothstep(threshold, threshold + 0.25, noise.fbm(p.co, 3, scale) * 0.5 + 0.5)
        return 1 - strength * s

    return fn


def mul(*fns):
    """The product of several wear functions (floats and rgb tuples mix fine)."""

    def fn(p):
        r = g = b = 1.0
        for f in fns:
            v = f(p)
            if isinstance(v, (int, float)):
                r, g, b = r * v, g * v, b * v
            else:
                r, g, b = r * v[0], g * v[1], b * v[2]
        return (r, g, b)

    return fn


def default_wear(noise):
    """What a layer gets if the piece sets nothing: a little ground dirt and cavity grime."""
    return mul(ground_dirt(0.5, 0.25, noise), cavity(0.25))


# --------------------------------------------------------------------------------------------
# The piece being built (the `ctx` handed to every build function)
# --------------------------------------------------------------------------------------------
class Piece:
    """ctx.add(layer, bm, matrix=None)  add a closed bmesh to a material layer
    ctx.wear(layer, fn)                  the vertex-colour wear of that layer (VertexInfo -> mul)
    ctx.mark("Light" | "Fx", at)         a marker point (Roblox axes, piece space)
    ctx.rng, ctx.noise                   deterministic randomness for this piece
    ctx.budget                           max triangles for the whole piece (default 3000;
                                         raise to <= 8000 for a hero prop)
    ctx.smooth_angle                     smooth-by-angle threshold in degrees (default 35)
    ctx.doc                              one line for the README (defaults to the docstring)
    ctx.tint(layer, (r, g, b))           the default colour of a TINTABLE layer (sRGB 0..255):
                                         written to assets/cityprops/pieces.json, which
                                         tools/city/meshprop.py reads to give the marker its
                                         Tint when the data does not choose one
    """

    def __init__(self, name, seed=1):
        self.name = name
        self.layers = {}
        self.wears = {}
        self.markers = {}
        self.rng = random.Random(seed)
        self.noise = Noise(seed)
        self.budget = 3000
        self.smooth_angle = 35.0
        self.doc = ""
        self.tints = {}

    def add(self, layer, bm, matrix=None):
        if layer not in LAYERS:
            raise ValueError(f"{self.name}: unknown layer {layer!r} (allowed: {', '.join(LAYER_NAMES)})")
        merge(self.layers.setdefault(layer, bmesh.new()), bm, matrix)

    def tint(self, layer, rgb):
        if not LAYERS.get(layer, (0, 0, 0, False))[3]:
            raise ValueError(f"{self.name}: layer {layer!r} is not tintable")
        self.tints[layer] = tuple(int(c) for c in rgb)

    def wear(self, layer, fn):
        self.wears[layer] = fn

    def mark(self, kind, at):
        if kind not in ("Light", "Fx"):
            raise ValueError(f"{self.name}: marker {kind!r} (Light or Fx)")
        self.markers[kind] = Vector(at)


# --------------------------------------------------------------------------------------------
# Turning a piece into Blender objects
# --------------------------------------------------------------------------------------------
def islands(bm):
    seen, out = set(), []
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, group = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            group.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        out.append(group)
    return out


def finish_bmesh(bm, name):
    """Merge by distance, outward faces (each closed island checked by its signed volume:
    Roblox draws one side only), triangles."""
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.faces.ensure_lookup_table()
    bm.faces.index_update()
    for group in islands(bm):
        boundary = any(not e.is_manifold for f in group for e in f.edges)
        if boundary:
            continue  # (an open card: keep the side it was built with)
        volume = sum(f.verts[0].co.dot(f.verts[1].co.cross(f.verts[2].co)) for f in group)
        if volume < 0:
            bmesh.ops.reverse_faces(bm, faces=group)
    bm.normal_update()


def convexity(bm):
    """Per vertex: > 0 on convex edges / tips, < 0 in creases (mean of normal . direction to the
    neighbours). Used by cavity() and edge_wear()."""
    out = {}
    for v in bm.verts:
        if not v.link_edges:
            out[v.index] = 0.0
            continue
        s = 0.0
        for e in v.link_edges:
            o = e.other_vert(v)
            d = v.co - o.co
            if d.length > 1e-9:
                s += v.normal.dot(d.normalized())
        out[v.index] = s / len(v.link_edges)
    return out


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def preview_material(layer, tint=None):
    key = "K_" + layer + ("" if tint is None else "_%d_%d_%d" % tint)
    mat = bpy.data.materials.get(key)
    if mat:
        return mat
    rgb, metal, rough, _, _, glow = LAYERS[layer]
    rgb = tint or rgb
    mat = bpy.data.materials.new(key)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    base = tuple(srgb_to_linear(c) for c in rgb) + (1.0,)
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs["A"].default_value = base
    nt.links.new(attr.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if glow:
        bsdf.inputs["Emission Color"].default_value = base
        bsdf.inputs["Emission Strength"].default_value = 4.0
    if layer == "Reflective":
        bsdf.inputs["Specular IOR Level"].default_value = 0.7
        bsdf.inputs["Coat Weight"].default_value = 0.3
    return mat


def make_objects(piece, at=(0, 0, 0)):
    """The Blender objects of a built piece, its origin at `at` (Roblox axes): one mesh per
    layer "<Piece>_<Layer>" (triangulated, outward, smooth by angle + weighted normals, vertex
    colours "Col", box UVs) and its markers. Returns (objects, {layer: tris})."""
    at = Vector(at)
    objects, stats = [], {}
    tints = piece.tints
    for layer, bm in piece.layers.items():
        name = f"{piece.name}_{layer}"
        finish_bmesh(bm, name)
        conv = convexity(bm)
        fn = piece.wears.get(layer) or default_wear(piece.noise)
        colors = {}
        for v in bm.verts:
            c = fn(VertexInfo(v.co.copy(), v.normal.copy(), conv[v.index]))
            if isinstance(c, (int, float)):
                c = (c, c, c)
            colors[v.index] = tuple(max(0.35, min(1.0, x)) for x in c)
        # box-projected UVs, one tile per 2 studs (built-in materials need sane UVs)
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            n = f.normal
            axis = max(range(3), key=lambda i: abs(n[i]))
            a, b = [(1, 2), (0, 2), (0, 1)][axis]
            for loop in f.loops:
                loop[uv].uv = (loop.vert.co[a] * 0.5, loop.vert.co[b] * 0.5)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.transform(TO_BLENDER)
        attr = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        for loop in mesh.loops:
            c = colors[loop.vertex_index]
            attr.data[loop.index].color_srgb = (c[0], c[1], c[2], 1.0)
        mesh.color_attributes.active_color = attr
        for poly in mesh.polygons:
            poly.use_smooth = True
        mesh.set_sharp_from_angle(angle=math.radians(piece.smooth_angle))
        ob = bpy.data.objects.new(name, mesh)
        ob.location = to_blender(at)
        bpy.context.scene.collection.objects.link(ob)
        wn = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
        wn.mode = "FACE_AREA"
        wn.keep_sharp = True
        ob.data.materials.append(preview_material(layer, tints.get(layer)))
        objects.append(ob)
        stats[layer] = len(mesh.polygons)
    piece.layers = {}
    for kind, p in [("Pivot", Vector((0, 0, 0)))] + list(piece.markers.items()):
        objects.append(marker(f"{piece.name}_{kind}", at + p))
    return objects, stats


def marker(name, at):
    """A tiny cube (never drawn by the game) at `at` (Roblox axes)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=0.03)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new(name, mesh)
    ob.location = to_blender(at)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def bounds(objects):
    """(min, max) of the drawn objects, in ROBLOX axes."""
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for ob in objects:
        if ob.name.endswith(MARKER_SUFFIXES):
            continue
        for v in ob.data.vertices:
            w = ob.matrix_world @ v.co
            r = Vector((w.x, w.z, -w.y))
            lo = Vector(map(min, lo, r))
            hi = Vector(map(max, hi, r))
    return lo, hi


# --------------------------------------------------------------------------------------------
# Preview (Cycles CPU, small and quick: the machine is shared)
# --------------------------------------------------------------------------------------------
def human_silhouette(at):
    """A plain 1.8 m figure (6.2 studs: 1 stud ~ 0.29 m) standing at `at` (Roblox axes), for
    scale. Built of rounded boxes, dark grey."""
    bm = bmesh.new()
    parts = [
        ((0.0, 5.75, 0.0), (0.72, 0.85, 0.8)),  # head
        ((0.0, 5.2, 0.0), (0.4, 0.3, 0.4)),  # neck
        ((0.0, 4.15, 0.0), (1.55, 1.9, 0.75)),  # torso
        ((0.0, 3.05, 0.0), (1.35, 0.5, 0.7)),  # hips
        ((-0.38, 1.45, 0.0), (0.55, 2.9, 0.6)),  # legs
        ((0.38, 1.45, 0.0), (0.55, 2.9, 0.6)),
        ((-0.98, 3.9, 0.0), (0.4, 2.4, 0.45)),  # arms
        ((0.98, 3.9, 0.0), (0.4, 2.4, 0.45)),
    ]
    for c, s in parts:
        merge(bm, box(*s, bevel=0.15, segments=3), T(*c))
    mesh = bpy.data.meshes.new("Human")
    bm.to_mesh(mesh)
    bm.free()
    mesh.transform(TO_BLENDER)
    for poly in mesh.polygons:
        poly.use_smooth = True
    ob = bpy.data.objects.new("Human", mesh)
    ob.location = to_blender(Vector(at))
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.new("Human")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.05, 0.055, 1)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
    mesh.materials.append(mat)
    return ob


class Preview:
    """A Cycles preview scene: neutral grey floor, sky fill, a day key light (sun) and an
    optional night bulb. Small and quick on purpose (640 x 420, 24 samples, denoised).

        pv = Preview(res=(640, 420), samples=24, night=False)
        pv.shoot(eye, target, path, lens=50)        # Roblox axes
    """

    def __init__(self, res=(640, 420), samples=24, night=False):
        sc = bpy.context.scene
        self.scene = sc
        sc.render.engine = "CYCLES"
        sc.cycles.device = "CPU"
        sc.cycles.samples = samples
        sc.cycles.max_bounces = 4
        sc.render.threads_mode = "FIXED"
        sc.render.threads = 2
        try:
            sc.cycles.use_denoising = True
            sc.cycles.denoiser = "OPENIMAGEDENOISE"
        except Exception:  # (no OIDN in this build: plain render)
            sc.cycles.use_denoising = False
        sc.render.resolution_x, sc.render.resolution_y = res
        sc.render.resolution_percentage = 100
        sc.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in sc.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
        world = bpy.data.worlds.new("kit_world")
        world.use_nodes = True
        bg = world.node_tree.nodes["Background"]
        bg.inputs[0].default_value = (0.03, 0.035, 0.05, 1) if night else (0.55, 0.6, 0.68, 1)
        bg.inputs[1].default_value = 0.25 if night else 0.9
        sc.world = world
        # floor: neutral grey, slightly rough (like dry concrete)
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=60)
        me = bpy.data.meshes.new("Floor")
        bm.to_mesh(me)
        bm.free()
        floor = bpy.data.objects.new("Floor", me)
        sc.collection.objects.link(floor)
        fm = bpy.data.materials.new("Floor")
        fm.use_nodes = True
        fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.16, 0.16, 0.16, 1)
        fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85
        me.materials.append(fm)
        self.floor = floor
        sun = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
        sun.data.energy = 0.6 if night else 3.2
        sun.data.angle = math.radians(3)
        sun.rotation_euler = Euler((math.radians(50), 0, math.radians(-35)))
        sc.collection.objects.link(sun)
        self.bulb = None
        if night:
            bulb = bpy.data.objects.new("Bulb", bpy.data.lights.new("Bulb", "POINT"))
            bulb.data.energy = 900
            bulb.data.color = (1.0, 0.72, 0.45)
            bulb.data.shadow_soft_size = 0.3
            sc.collection.objects.link(bulb)
            self.bulb = bulb
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        sc.collection.objects.link(cam)
        sc.camera = cam
        self.cam = cam

    def place_floor(self, at):
        self.floor.location = to_blender(Vector(at))
        if self.bulb:
            self.bulb.location = to_blender(Vector(at) + Vector((3, 7, -4)))

    def shoot(self, eye, target, path, lens=50):
        e, t = to_blender(Vector(eye)), to_blender(Vector(target))
        self.cam.location = e
        self.cam.rotation_euler = (t - e).to_track_quat("-Z", "Y").to_euler()
        self.cam.data.lens = lens
        self.cam.data.clip_start = 0.05
        self.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        return path
