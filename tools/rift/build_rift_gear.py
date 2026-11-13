"""
Builds Dr. Rift's mechanical gear as real meshes: his cyborg left arm with
the gravity glove, his ocular implant, the ray gun, the portal gun and the
flask of his potions.

    venv/bin/python -I tools/rift/build_rift_gear.py assets/rift [--preview <dir>]

Writes:
  <out_dir>/RiftGear.fbx     every piece, ready for Studio's 3D Importer
  <dir>/rift_*.png           pictures (with --preview)

Each piece = a few meshes, one per material (the game colours them, see
src/client/Combat/RiftAssets.luau), named "<Piece>_<Layer>":
  Steel      worn grey plates                SteelDark  frames, cores, screws
  Chrome     axles, piston rods, pins        Brass      rings, bolts, mounts
  Rubber     cables, hoses, grips            Glow       glowing parts (neon)
  Glass      clear covers, the flask         Liquid     what is in the flask
  Cork       the flask's stopper             Palm       the glove's emitter
Markers (tiny cubes, never shown):
  <Piece>_Pivot   where the piece's own origin is (see below)
  <Piece>_Tip     the muzzle of a gun
  Arm_PalmPoint   where the glove's power comes out
  Arm_Cell, Eye_Lens   where their green lights go
  Kit_Origin / Kit_Up / Kit_Out   1 stud apart: how the importer turned and
                                  scaled the file (as in WoundKit.fbx)

The axes are Roblox's (Y up, the front is -Z, +X is the character's right):
  Arm        Left Arm space (1 x 2 x 1, shoulder at Y = +1, hand at Y = -1;
             +X faces the torso)
  Eye        Head space, for the classic head mesh at scale 1.25 (a rounded
             cylinder of radius 0.6, straight from Y = -0.3 to 0.3); it sits
             on the RIGHT eye of the default face (X = +0.175, Y = +0.12)
  RayGun / PortalGun   Right Arm space: the fist at Y = -1.05, the barrel
             along -Y (forward when the arm is raised), the top of the gun
             toward -Z
  Flask      its own centre
"""

import math
import os
import sys

import bpy  # isort: skip  (first: it makes the other Blender modules importable)
import bmesh
from mathutils import Euler, Matrix, Vector

OUT = sys.argv[1]
PREVIEW = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None

# Where each piece sits in the kit (its pivot), well apart.
PIECES = {
    "Arm": (0.0, 0.0, 0.0),
    "Eye": (4.0, 0.0, 0.0),
    "RayGun": (8.0, 0.0, 0.0),
    "PortalGun": (12.0, 0.0, 0.0),
    "Flask": (16.0, 0.0, 0.0),
}

# The classic head (see tools/wounds/build_wound_kit.py) and the eye on it.
HEAD_RADIUS = 0.6
EYE_X, EYE_Y = 0.175, 0.12

COLORS = {  # preview only: the game sets the real colours (RiftAssets)
    "Steel": ((0.36, 0.37, 0.38), 1.0, 0.38),
    "SteelDark": ((0.11, 0.115, 0.12), 1.0, 0.45),
    "Chrome": ((0.85, 0.86, 0.88), 1.0, 0.08),
    "Brass": ((0.62, 0.45, 0.2), 1.0, 0.3),
    "Rubber": ((0.03, 0.03, 0.035), 0.0, 0.7),
    "Glass": ((0.8, 0.9, 0.86), 0.0, 0.02),
    "Liquid": ((0.45, 0.85, 0.1), 0.0, 0.1),
    "Cork": ((0.55, 0.38, 0.22), 0.0, 0.8),
    "Marker": ((1, 0, 1), 0.0, 0.5),
}
GLOWS = {"Glow": (0.35, 1.0, 0.3), "Palm": (0.6, 1.0, 0.55)}
RAY_GLOW = (1.0, 0.3, 0.08)


# --- Matrices ---------------------------------------------------------------------
def T(x, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def R(rx=0.0, ry=0.0, rz=0.0):
    """Rotation in degrees, X then Y then Z."""
    return Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_matrix().to_4x4()


def S(x, y=None, z=None):
    y = x if y is None else y
    z = x if z is None else z
    return Matrix.Diagonal((x, y, z, 1))


def aim_y(at, direction):
    """A frame at `at` whose +Y goes along `direction`."""
    d = Vector(direction).normalized()
    q = Vector((0, 1, 0)).rotation_difference(d)
    return Matrix.Translation(at) @ q.to_matrix().to_4x4()


def azim(a):
    """Unit vector round the Y axis: 0 = +X, 90 = +Z (the back), 270 = -Z (the front)."""
    return Vector((math.cos(math.radians(a)), 0, math.sin(math.radians(a))))


# --- Shapes (each a closed bmesh, centred, Y up) ------------------------------------
def bevel_edges(bm, edges, width, segments=2):
    if width > 0 and edges:
        bmesh.ops.bevel(
            bm,
            geom=list(edges),
            offset=width,
            segments=segments,
            profile=0.5,
            affect="EDGES",
            clamp_overlap=True,
        )


def box(sx, sy, sz, bevel=0.0, segments=2, taper=1.0):
    """A box; `taper` shrinks its bottom (-Y) face in X and Z."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        k = taper if v.co.y < 0 else 1.0
        v.co = Vector((v.co.x * sx * k, v.co.y * sy, v.co.z * sz * k))
    bevel_edges(bm, bm.edges[:], min(bevel, sx * 0.45, sy * 0.45, sz * 0.45), segments)
    return bm


def cyl(r, h, segs=24, r2=None, bevel=0.0, axis="Y"):
    """A cylinder (or a cone frustum: r at the bottom, r2 at the top)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=h)
    if bevel > 0:
        rim = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-6 and len(e.link_faces) == 2]
        rim = [e for e in rim if any(len(f.verts) > 4 for f in e.link_faces)]
        bevel_edges(bm, rim, min(bevel, h * 0.45, r * 0.45), 2)
    bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.radians(-90), 4, "X"))
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.radians(-90), 4, "Z"))
    elif axis == "Z":
        bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.radians(90), 4, "X"))
    return bm


def sphere(r, segs=16, rings=10):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    return bm


def lathe(profile, segs=32):
    """Spins a profile [(radius, y), ...] round Y. A point of radius 0 is a
    pole. Give the outline of a solid (closed: start and end on the axis, or
    a loop) so the result is closed."""
    bm = bmesh.new()
    rings = []
    for r, y in profile:
        if r < 1e-6:
            rings.append([bm.verts.new((0, y, 0))])
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * s / segs), y, r * math.sin(2 * math.pi * s / segs))) for s in range(segs)])
    loop = len(profile) > 2 and profile[0][0] > 1e-6 and profile[-1][0] > 1e-6
    count = len(rings) if loop else len(rings) - 1
    for i in range(count):
        a, b = rings[i], rings[(i + 1) % len(rings)]
        if len(a) == 1 and len(b) == 1:
            continue
        for s in range(segs):
            t = (s + 1) % segs
            if len(a) == 1:
                bm.faces.new((a[0], b[t], b[s]))
            elif len(b) == 1:
                bm.faces.new((a[s], a[t], b[0]))
            else:
                bm.faces.new((a[s], a[t], b[t], b[s]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    return bm


def torus(R_, r, segs=24, rsegs=8, arc=360.0):
    """A ring round Y (in the XZ plane). With arc < 360: a closed bent tube."""
    pts = []
    full = arc >= 359.9
    n = segs if full else max(2, int(segs * arc / 360) + 1)
    for i in range(n):
        a = math.radians(arc * i / (n if full else n - 1))
        pts.append(Vector((R_ * math.cos(a), 0, R_ * math.sin(a))))
    return tube(pts, r, rsegs, closed=full, smooth=0)


def catmull(points, steps):
    pts = [Vector(p) for p in points]
    if steps <= 1 or len(pts) < 3:
        return pts
    out = []
    ext = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for k in range(steps):
            t = k / steps
            out.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    out.append(pts[-1])
    return out


def tube(points, r, segs=8, closed=False, smooth=6, radii=None):
    """A round tube along a path (a cable, a hose, a coil), capped."""
    pts = catmull(points, smooth) if smooth else [Vector(p) for p in points]
    n = len(pts)
    bm = bmesh.new()
    tangents = []
    for i in range(n):
        if closed:
            d = pts[(i + 1) % n] - pts[i - 1]
        else:
            d = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        tangents.append(d.normalized())
    # parallel transport of a normal along the path
    t0 = tangents[0]
    normal = t0.cross(Vector((0, 0, 1)) if abs(t0.z) < 0.9 else Vector((1, 0, 0))).normalized()
    rings = []
    for i in range(n):
        if i > 0:
            normal = (normal - tangents[i] * normal.dot(tangents[i])).normalized()
        binormal = tangents[i].cross(normal)
        rr = radii(i / max(n - 1, 1)) if radii else r
        rings.append(
            [bm.verts.new(pts[i] + (normal * math.cos(2 * math.pi * s / segs) + binormal * math.sin(2 * math.pi * s / segs)) * rr) for s in range(segs)]
        )
    for i in range(n if closed else n - 1):
        a, b = rings[i], rings[(i + 1) % n]
        for s in range(segs):
            t = (s + 1) % segs
            bm.faces.new((a[s], a[t], b[t], b[s]))
    if not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    return bm


def shell_arc(r_in, r_out, y0, y1, a0, a1, segs=16, bevel=0.012):
    """A curved plate round the Y axis (between angles a0..a1, degrees)."""
    bm = bmesh.new()
    n = max(2, segs)
    rows = []
    for r, y in ((r_out, y0), (r_out, y1), (r_in, y1), (r_in, y0)):
        rows.append([bm.verts.new(azim(a0 + (a1 - a0) * i / (n - 1)) * r + Vector((0, y, 0))) for i in range(n)])
    for k in range(4):
        a, b = rows[k], rows[(k + 1) % 4]
        for i in range(n - 1):
            bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
    bm.faces.new([rows[k][0] for k in range(4)])
    bm.faces.new([rows[k][-1] for k in reversed(range(4))])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    sharp = [e for e in bm.edges if e.calc_face_angle(0) > math.radians(50)]
    bevel_edges(bm, sharp, bevel, 1)
    return bm


def hexbolt(r, h):
    """A hex bolt head (axis Y, sitting on Y = 0) with a dome."""
    bm = cyl(r, h, segs=6, bevel=r * 0.18)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, h / 2, 0))
    return bm


def rivet(r):
    bm = lathe([(0, 0), (r, 0), (r * 0.92, r * 0.35), (r * 0.6, r * 0.62), (0, r * 0.7)], segs=8)
    return bm


def gear_ring(r, h, teeth, depth):
    """A toothed ring (axis Y)."""
    bm = cyl(r - depth * 0.5, h, segs=teeth * 2)
    for i in range(teeth):
        a = 360 * i / teeth
        t = box(depth * 1.3, h, 2 * math.pi * r / teeth * 0.5, bevel=depth * 0.15, segments=1)
        bmesh.ops.transform(t, matrix=R(0, -a, 0) @ T(r - depth * 0.15, 0, 0), verts=t.verts)
        merge(bm, t)
    return bm


def merge(target, bm, matrix=None):
    if matrix is not None:
        bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    me = bpy.data.meshes.new("_tmp")
    bm.to_mesh(me)
    bm.free()
    target.from_mesh(me)
    bpy.data.meshes.remove(me)


class Piece:
    def __init__(self, name):
        self.name = name
        self.layers = {}
        self.markers = {}

    def add(self, layer, bm, matrix=None):
        merge(self.layers.setdefault(layer, bmesh.new()), bm, matrix)

    def bolt(self, layer, at, normal, r=0.022, h=0.016):
        self.add(layer, hexbolt(r, h), aim_y(Vector(at), normal) @ R(0, 15, 0))

    def rivet(self, layer, at, normal, r=0.018):
        self.add(layer, rivet(r), aim_y(Vector(at), normal))

    def piston(self, a, b, r=0.06, rod=0.032, split=0.55):
        """A hydraulic piston from a to b: a dark cylinder, a chrome rod, brass
        eye mounts with axles at both ends."""
        a, b = Vector(a), Vector(b)
        d = b - a
        L = d.length
        body = L * split
        self.add("SteelDark", cyl(r, body, segs=16, bevel=0.012), aim_y(a + d.normalized() * body / 2, d))
        self.add("Brass", cyl(r * 1.15, 0.03, segs=16), aim_y(a + d.normalized() * (body - 0.01), d))
        self.add("Brass", cyl(r * 1.1, 0.025, segs=16), aim_y(a + d.normalized() * 0.03, d))
        self.add("Chrome", cyl(rod, L - body + 0.02, segs=12), aim_y(a + d.normalized() * (body + (L - body) / 2), d))
        for p in (a, b):
            self.add("Brass", cyl(r * 0.9, r * 1.1, segs=12, axis="X"), aim_y(p, d))  # (its axle across, along X)
            self.add("Chrome", cyl(r * 0.35, r * 1.6, segs=8, axis="X"), aim_y(p, d))

    def mark(self, name, at):
        self.markers[name] = Vector(at)


# --- The arm ------------------------------------------------------------------------
# (Left Arm space, 1 x 2 x 1: the shoulder at the top, Y = +1; +X faces the
# torso, whose side is at X = +0.5 from the arm's centre: nothing goes past
# X = +0.48. Read from the top: the shoulder (Y 0.55..0.99), the upper arm
# (0.1..0.6), the elbow (Y ~0.03), the forearm (-0.08..-0.62), the wrist
# (-0.62..-0.72), the glove (-0.72..-1.46, its emitter at Y ~ -1.07). A bit
# wider than the R6 arm (about 1.08 x 2.45 x 1.06): it reads as a heavy limb.)
ELBOW_Y = 0.03
WRIST_Y = -0.7
KNUCKLE_Y = -1.02
EMITTER_Y = -1.07


def finger(p, base, out, curls=(25, -20, -65), width=0.17, thick=0.155, lengths=(0.2, 0.16, 0.13)):
    """A finger of 3 segments from the knuckle `base`, opening along `out`
    (a horizontal unit vector), curling back in round the emitter."""
    side = out.cross(Vector((0, -1, 0))).normalized()  # the joints' axis
    at = Vector(base)
    # knuckle servo
    p.add("SteelDark", cyl(width * 0.5, width * 1.4, segs=14, bevel=0.012), aim_y(at, side))
    p.add("Chrome", cyl(width * 0.2, width * 1.62, segs=8), aim_y(at, side))
    for i, (curl, L) in enumerate(zip(curls, lengths)):
        if L < 1e-3:
            continue
        d = (Vector((0, -1, 0)) * math.cos(math.radians(curl)) + out * math.sin(math.radians(curl))).normalized()
        w = width * (1 - 0.1 * i)
        t = thick * (1 - 0.1 * i)
        back = side.cross(d)  # out of the back of the finger
        frame = Matrix((side, d, back)).transposed().to_4x4()
        frame.translation = at + d * (L / 2)
        # the segment: a dark inner bone, an armour shell over its back
        p.add("SteelDark", box(w * 0.78, L * 0.96, t * 0.8, bevel=0.02, segments=1), frame)
        shell = frame.copy()
        shell.translation = at + d * (L * 0.48) + back * (t * 0.12)
        p.add("Steel", box(w, L * 0.82, t * 0.78, bevel=0.03, segments=2, taper=0.86), shell)
        # two rivets on each shell, a tendon pin on the side
        for f in (0.28, 0.68):
            p.rivet("Steel", at + d * (L * f) + back * (t * 0.52), back, r=0.012)
        at = at + d * L
        if i < len(curls) - 1 and lengths[i + 1] > 1e-3:
            p.add("SteelDark", cyl(w * 0.4, w * 1.16, segs=12, bevel=0.008), aim_y(at, side))
            p.add("Chrome", cyl(w * 0.15, w * 1.34, segs=8), aim_y(at, side))
    # the fingertip: a hard pad
    p.add("SteelDark", sphere(width * 0.4, 12, 8), Matrix.Translation(at) @ S(1, 0.8, 1))


def build_arm():
    p = Piece("Arm")
    cx = -0.04  # the arm's own axis leans a hair away from the torso
    # --- the shoulder: a rounded pauldron over a dark rim, a second plate ---------------
    dome = lathe([(0, 0), (0.5, 0), (0.5, 0.07), (0.48, 0.16), (0.43, 0.24), (0.33, 0.31), (0.17, 0.35), (0, 0.36)], segs=40)
    p.add("Steel", dome, T(cx, 0.6, 0) @ R(0, 0, 4) @ S(0.94, 0.95, 0.94))
    p.add("SteelDark", lathe([(0, 0), (0.49, 0), (0.49, 0.045), (0, 0.045)], segs=40), T(cx, 0.565, 0))  # the rim
    # a flared collar under the rim, from the upper arm out to the dome (no mushroom overhang)
    p.add("SteelDark", lathe([(0, 0.44), (0.335, 0.44), (0.36, 0.49), (0.42, 0.54), (0.46, 0.57), (0, 0.57)], segs=32), T(cx, 0, 0))
    for a in range(0, 360, 30):  # rivets round the rim
        u = azim(a)
        if u.x * 0.47 + cx < 0.42:
            p.rivet("Steel", Vector((cx + u.x * 0.47, 0.59, u.z * 0.47)), Vector((u.x, 0, u.z)), r=0.018)
    # a second, older plate over the outer side (salvaged, a bit crooked), bolted
    tilt = T(cx, 0, 0) @ R(0, 0, -5)
    p.add("Steel", shell_arc(0.49, 0.535, 0.48, 0.74, 145, 215, segs=12, bevel=0.014), tilt)
    for a in (151, 209):
        for y in (0.53, 0.69):
            p.bolt("Brass", tilt @ (azim(a) * 0.537 + Vector((0, y, 0))), tilt.to_3x3() @ azim(a), r=0.022, h=0.014)
    # a raised ridge over the dome, front to back
    ridge = [Vector((cx - 0.02, 0.6 + 0.34 * math.sin(math.radians(a)) + 0.02, 0.47 * math.cos(math.radians(a)) * 0.97)) for a in range(25, 160, 9)]
    p.add("SteelDark", tube(ridge, 0.026, segs=8, smooth=3))
    # vents at the back of the dome
    for i in range(3):
        p.add("SteelDark", box(0.32, 0.026, 0.07, bevel=0.01, segments=1), T(cx - 0.05, 0.84 - i * 0.06, 0.3 + i * 0.045) @ R(-28 - i * 9, 0, 0))
    # a status light on the front
    p.add("SteelDark", cyl(0.045, 0.035, segs=16, bevel=0.01, axis="Z"), T(0.12, 0.76, -0.42) @ R(-30, 0, 0))
    p.add("Glow", sphere(0.028, 10, 6), T(0.12, 0.77, -0.44))
    # --- the shoulder servo, under the dome on the outer side --------------------------
    sy = 0.46
    p.add("SteelDark", cyl(0.2, 0.14, segs=28, bevel=0.022, axis="X"), T(-0.4, sy, 0))
    p.add("Brass", gear_ring(0.22, 0.045, 18, 0.04), T(-0.48, sy, 0) @ R(0, 0, 90))
    p.add("Chrome", cyl(0.065, 0.12, segs=16, bevel=0.01, axis="X"), T(-0.52, sy, 0))
    p.add("SteelDark", hexbolt(0.045, 0.025), T(-0.575, sy, 0) @ R(0, 0, 90))
    for i in range(6):
        a = math.radians(i * 60 + 30)
        p.bolt("Chrome", (-0.505, sy + 0.14 * math.sin(a), 0.14 * math.cos(a)), (-1, 0, 0), r=0.015, h=0.01)
    # --- the upper arm: a dark core, armour over it ---------------------------------
    p.add("SteelDark", cyl(0.3, 0.56, segs=28, r2=0.33, bevel=0.02), T(cx, 0.33, 0))
    p.add("SteelDark", torus(0.32, 0.02, segs=28, rsegs=6), T(cx, 0.16, 0))
    # a curved armour plate over the front and the outer side
    p.add("Steel", shell_arc(0.34, 0.385, 0.18, 0.52, 150, 290, segs=18), T(cx, 0, 0))
    for a in (158, 200, 242, 282):
        for y in (0.22, 0.48):
            p.rivet("Steel", azim(a) * 0.387 + Vector((cx, y, 0)), azim(a), r=0.016)
    # a dark scrap plate at the back
    p.add("SteelDark", shell_arc(0.33, 0.37, 0.22, 0.5, 45, 125, segs=12), T(cx, 0, 0))
    for a in (52, 118):
        p.bolt("Brass", azim(a) * 0.372 + Vector((cx, 0.36, 0)), azim(a), r=0.018)
    # --- hydraulics: one piston in front, one at the back-outer, over the elbow ---------
    front = ((-0.06, 0.52, -0.43), (-0.06, -0.24, -0.41))
    back = ((-0.34, 0.5, 0.3), (-0.34, -0.22, 0.33))
    p.piston(*front, r=0.05, rod=0.026, split=0.5)
    p.piston(*back, r=0.044, rod=0.023, split=0.52)
    for (a, b), toward in ((front, -1), (back, 1)):
        for q in (a, b):
            p.add("SteelDark", box(0.13, 0.08, 0.12, bevel=0.02), T(q[0], q[1], q[2] - toward * 0.06))
    # --- the elbow: a servo across the arm ------------------------------------------
    p.add("SteelDark", cyl(0.25, 0.6, segs=32, bevel=0.03, axis="X"), T(cx, ELBOW_Y, 0.03))
    for x in (cx - 0.32, cx + 0.32):
        p.add("Brass", cyl(0.265, 0.04, segs=32, bevel=0.009, axis="X"), T(x, ELBOW_Y, 0.03))
        s = math.copysign(1, x - cx)
        for i in range(6):
            a = math.radians(i * 60 + 30)
            p.bolt("Chrome", (x + s * 0.02, ELBOW_Y + 0.2 * math.sin(a), 0.03 + 0.2 * math.cos(a)), (s, 0, 0), r=0.015, h=0.01)
    p.add("Chrome", cyl(0.08, 0.76, segs=20, bevel=0.012, axis="X"), T(cx, ELBOW_Y, 0.03))
    p.add("SteelDark", hexbolt(0.06, 0.03), T(cx - 0.38, ELBOW_Y, 0.03) @ R(0, 0, 90))
    # the elbow guard at the back
    p.add("Steel", shell_arc(0.27, 0.315, ELBOW_Y - 0.14, ELBOW_Y + 0.15, 55, 125, segs=10), T(cx, 0, 0.03))
    # --- the forearm: segmented plates round a dark core, wide at the elbow ----------
    p.add("SteelDark", cyl(0.29, 0.66, segs=28, r2=0.32, bevel=0.02), T(cx, -0.37, 0))
    window = (252, 288)  # the front, where the power cell shows
    bands = ((-0.09, -0.24, 0.39), (-0.265, -0.415, 0.375), (-0.44, -0.6, 0.36))
    for y1, y0, r in bands:
        p.add("Steel", shell_arc(r - 0.045, r, y0, y1, window[1], window[0] + 360, segs=30, bevel=0.014), T(cx, 0, 0))
        for a in range(window[1] + 14, window[0] + 360 - 8, 30):
            p.rivet("Steel", azim(a) * (r + 0.002) + Vector((cx, (y0 + y1) / 2, 0)), azim(a), r=0.014)
    # the window frame and its glass, the power cell behind
    for a in window:
        p.add("SteelDark", box(0.05, 0.53, 0.08, bevel=0.012), T(*(azim(a) * 0.37 + Vector((cx, -0.34, 0)))) @ R(0, -a, 0))
    p.add("Glass", shell_arc(0.345, 0.357, -0.59, -0.1, window[0] - 3, window[1] + 3, segs=8, bevel=0.004), T(cx, 0, 0))
    cell = Vector((cx, -0.345, -0.25))
    p.add("Glow", cyl(0.075, 0.36, segs=16, bevel=0.012), T(*cell))
    for dy in (0.19, -0.19):
        p.add("Brass", cyl(0.09, 0.04, segs=16, bevel=0.01), T(*(cell + Vector((0, dy, 0)))))
    for dy in (-0.09, 0.0, 0.09):
        p.add("SteelDark", torus(0.077, 0.008, segs=16, rsegs=5), T(*(cell + Vector((0, dy, 0)))))  # the cell's bands
    p.mark("Arm_Cell", cell + Vector((0, 0, -0.16)))  # (its light: just in front of the glass)
    # --- cables: hoses from the shoulder down the back into the forearm --------------
    hoses = [
        ([(0.16, 0.55, 0.42), (0.16, 0.36, 0.45), (0.16, 0.14, 0.43), (0.13, -0.06, 0.39), (0.1, -0.2, 0.37)], 0.034),
        ([(0.02, 0.56, 0.45), (0.02, 0.36, 0.49), (0.0, 0.14, 0.46), (-0.02, -0.06, 0.41), (-0.04, -0.21, 0.38)], 0.04),
        ([(-0.16, 0.55, 0.42), (-0.19, 0.36, 0.45), (-0.21, 0.14, 0.43), (-0.2, -0.05, 0.39), (-0.17, -0.2, 0.36)], 0.03),
    ]
    for pts, r in hoses:
        p.add("Rubber", tube(pts, r, segs=10, smooth=6))
        path = catmull(pts, 6)
        for t in (0.2, 0.7):
            i = int(t * (len(path) - 1))
            p.add("Brass", tube([path[i - 1], path[i + 1]], r * 1.3, segs=10, smooth=0))
    # a thin cable from the power cell round the wrist into the glove
    p.add("Rubber", tube([(cx + 0.1, -0.56, -0.33), (cx + 0.22, -0.64, -0.29), (cx + 0.32, -0.74, -0.15), (cx + 0.36, -0.86, 0.0)], 0.018, segs=8))
    # --- the wrist: a brass ring, a turning chrome collar -----------------------------
    p.add("Brass", cyl(0.33, 0.05, segs=32, bevel=0.012), T(cx, WRIST_Y + 0.07, 0))
    p.add("Chrome", cyl(0.27, 0.07, segs=32, bevel=0.012), T(cx, WRIST_Y + 0.01, 0))
    p.add("SteelDark", torus(0.272, 0.012, segs=32, rsegs=5), T(cx, WRIST_Y - 0.02, 0))
    # --- the gravity glove: a heavy hand curled round the emitter ---------------------
    hy = (WRIST_Y - 0.04 + KNUCKLE_Y) / 2
    hh = (WRIST_Y - 0.04) - KNUCKLE_Y
    p.add("SteelDark", cyl(0.37, hh, segs=10, r2=0.3, bevel=0.03), T(cx, hy, 0) @ R(0, 18, 0))  # the palm frame
    # armour plates round the hand (the back of the hand is the outer side, -X)
    p.add("Steel", shell_arc(0.36, 0.405, KNUCKLE_Y + 0.03, WRIST_Y - 0.06, 120, 240, segs=14, bevel=0.016), T(cx, 0, 0))
    p.add("Steel", shell_arc(0.36, 0.395, KNUCKLE_Y + 0.03, WRIST_Y - 0.08, 300, 420, segs=12, bevel=0.016), T(cx, 0, 0))
    for a in (128, 180, 232, 308, 412):
        for y in (KNUCKLE_Y + 0.07, WRIST_Y - 0.12):
            p.rivet("Steel", azim(a) * 0.407 + Vector((cx, y, 0)), azim(a), r=0.015)
    # capacitor lights on the back of the hand
    for k, a in enumerate((165, 180, 195)):
        u = azim(a)
        p.add("SteelDark", box(0.035, 0.15, 0.05, bevel=0.01), aim_y(u * 0.41 + Vector((cx, hy - 0.01, 0)), (0, 1, 0)) @ R(0, -a, 0))
        p.add("Glow", box(0.02, 0.11, 0.03, bevel=0.006), aim_y(u * 0.425 + Vector((cx, hy - 0.01, 0)), (0, 1, 0)) @ R(0, -a, 0))
    p.add("SteelDark", cyl(0.39, 0.05, segs=40, bevel=0.012), T(cx, KNUCKLE_Y + 0.015, 0))  # the knuckle ring
    # the emitter at the end: a brass ring, a chrome ring, the glowing disc (Palm), a hub
    p.add("Brass", torus(0.24, 0.035, segs=32, rsegs=8), T(cx, EMITTER_Y + 0.005, 0))
    p.add("Chrome", torus(0.175, 0.018, segs=28, rsegs=6), T(cx, EMITTER_Y - 0.002, 0))
    p.add("Palm", cyl(0.215, 0.03, segs=32), T(cx, EMITTER_Y + 0.012, 0))
    p.add("SteelDark", cyl(0.045, 0.03, segs=12), T(cx, EMITTER_Y - 0.008, 0))
    for k in range(3):  # three spokes from the hub
        a = 90 + 120 * k
        p.add("SteelDark", box(0.16, 0.014, 0.018), T(cx, EMITTER_Y - 0.006, 0) @ R(0, -a, 0) @ T(0.12, 0, 0))
    p.mark("Arm_PalmPoint", (cx, EMITTER_Y - 0.08, 0))
    # three fingers and a thumb, round the emitter (the thumb toward the torso)
    for a in (125, 180, 235):
        finger(p, azim(a) * 0.3 + Vector((cx, KNUCKLE_Y, 0)), azim(a))
    finger(p, azim(5) * 0.3 + Vector((cx, KNUCKLE_Y + 0.07, 0)), azim(5), curls=(35, -10, -55), lengths=(0.19, 0.15, 0.12), width=0.18, thick=0.16)
    # a tendon cable on the back of each finger
    for a in (125, 180, 235, 5):
        u = azim(a)
        p.add(
            "Rubber",
            tube(
                [u * 0.36 + Vector((cx, WRIST_Y - 0.06, 0)), u * 0.415 + Vector((cx, hy, 0)), u * 0.39 + Vector((cx, KNUCKLE_Y - 0.01, 0))],
                0.013,
                segs=6,
                smooth=4,
            ),
        )
    return p


# --- The eye -------------------------------------------------------------------------
def on_head(x, y, lift=0.0):
    """A frame on the classic head's front at (x, y): +Y out of the skin,
    +X round the head toward its right, +Z up."""
    angle = math.asin(max(-1, min(1, x / HEAD_RADIUS)))
    r = HEAD_RADIUS + lift
    pos = Vector((r * math.sin(angle), y, -r * math.cos(angle)))
    normal = Vector((math.sin(angle), 0, -math.cos(angle)))
    tangent = Vector((math.cos(angle), 0, math.sin(angle)))
    up = Vector((0, 1, 0))
    m = Matrix((tangent, normal, up)).transposed().to_4x4()
    m.translation = pos
    return m


def head_patch(outline, lift, thickness, segs_per_edge=4):
    """A thin plate lying ON the head (bent round it): `outline` is a list of
    (x, y) points on the face (x measured round the head, in studs)."""
    bm = bmesh.new()
    pts = []
    for i in range(len(outline)):
        a, b = Vector(outline[i]), Vector(outline[(i + 1) % len(outline)])
        for k in range(segs_per_edge):
            pts.append(a.lerp(b, k / segs_per_edge))
    cx = sum(p.x for p in pts) / len(pts)
    cy = sum(p.y for p in pts) / len(pts)

    def place(x, y, r):
        ang = x / HEAD_RADIUS
        return Vector((r * math.sin(ang), y, -r * math.cos(ang)))

    rings = 4
    layers = []
    for side, r in ((0, HEAD_RADIUS + lift), (1, HEAD_RADIUS + lift + thickness)):
        grid = []
        for k in range(rings + 1):
            f = 1 - k / rings
            if k == rings:
                grid.append([bm.verts.new(place(cx, cy, r))])
            else:
                grid.append([bm.verts.new(place(cx + (p.x - cx) * f, cy + (p.y - cy) * f, r)) for p in pts])
        layers.append(grid)
    n = len(pts)
    for side, grid in enumerate(layers):
        for k in range(rings):
            a, b = grid[k], grid[k + 1]
            for i in range(n):
                j = (i + 1) % n
                if len(b) == 1:
                    face = (a[i], a[j], b[0])
                else:
                    face = (a[i], a[j], b[j], b[i])
                bm.faces.new(face if side == 1 else tuple(reversed(face)))
    inner, outer = layers[0][0], layers[1][0]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((inner[i], inner[j], outer[j], outer[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    edge_ring = [e for e in bm.edges if e.calc_face_angle(0) > math.radians(55)]
    bevel_edges(bm, edge_ring, thickness * 0.35, 1)
    return bm


def build_eye():
    p = Piece("Eye")
    ex = HEAD_RADIUS * math.asin(EYE_X / HEAD_RADIUS)  # the eye, measured round the head
    # the plate grafted into the skin: round the eye, reaching back to the temple
    outline = [
        (ex - 0.13, EYE_Y + 0.02),
        (ex - 0.09, EYE_Y + 0.13),
        (ex + 0.06, EYE_Y + 0.15),
        (ex + 0.2, EYE_Y + 0.11),
        (ex + 0.34, EYE_Y + 0.07),
        (ex + 0.36, EYE_Y - 0.03),
        (ex + 0.2, EYE_Y - 0.06),
        (ex + 0.08, EYE_Y - 0.13),
        (ex - 0.06, EYE_Y - 0.12),
    ]
    p.add("Steel", head_patch(outline, -0.004, 0.018))
    # screws holding it into the skull
    for x, y in (
        (ex - 0.1, EYE_Y + 0.06),
        (ex + 0.02, EYE_Y + 0.12),
        (ex + 0.3, EYE_Y + 0.05),
        (ex + 0.12, EYE_Y - 0.08),
        (ex - 0.04, EYE_Y - 0.09),
        (ex + 0.22, EYE_Y - 0.03),
    ):
        f = on_head(HEAD_RADIUS * math.sin(x / HEAD_RADIUS), y, 0.012)
        p.add("SteelDark", hexbolt(0.014, 0.008), f)
    # the bezel round the eye: a brass ring, standing out a little
    eye = on_head(EYE_X, EYE_Y, 0.012)
    p.add("Brass", lathe([(0.062, -0.01), (0.104, -0.01), (0.108, 0.018), (0.098, 0.034), (0.07, 0.04), (0.062, 0.03)], segs=32), eye)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        p.add("SteelDark", hexbolt(0.009, 0.006), eye @ T(0.085 * math.cos(a), 0.03, 0.085 * math.sin(a)))
    # inside: a dark barrel, the glowing lens, the iris ring and the pupil
    p.add("SteelDark", lathe([(0, -0.01), (0.064, -0.01), (0.064, 0.03), (0.058, 0.03), (0, 0.004)], segs=24), eye)
    p.add("Glow", lathe([(0, 0.006), (0.054, 0.006), (0.054, 0.012), (0.04, 0.02), (0, 0.024)], segs=24), eye)
    p.add("Chrome", torus(0.036, 0.0055, segs=24, rsegs=5), eye @ T(0, 0.022, 0))
    p.add("SteelDark", cyl(0.014, 0.01, segs=12), eye @ T(0, 0.024, 0))
    p.add("Glass", lathe([(0, 0.026), (0.062, 0.026), (0.062, 0.03), (0.045, 0.037), (0, 0.04)], segs=24), eye)
    p.mark("Eye_Lens", eye @ Vector((0, 0.07, 0)))  # (its light: just out of the lens)
    # the module on the temple and its antenna going back
    temple = on_head(HEAD_RADIUS * math.sin((ex + 0.3) / HEAD_RADIUS), EYE_Y + 0.02, 0.01)
    p.add("SteelDark", box(0.11, 0.04, 0.09, bevel=0.012), temple @ T(0, 0.02, 0))
    p.add("Glow", sphere(0.012, 8, 5), temple @ T(-0.03, 0.045, 0.02))
    base = temple @ Vector((0.02, 0.04, 0.03))
    tip = base + Vector((0.04, 0.24, 0.12))
    p.add("Chrome", cyl(0.007, (tip - base).length, segs=6), aim_y((base + tip) / 2, tip - base))
    p.add("Brass", cyl(0.014, 0.02, segs=8), aim_y(base, tip - base))
    p.add("Glow", sphere(0.014, 8, 5), Matrix.Translation(tip))
    # a cable from the bezel to the module, then back round the side of the head
    path = []
    for deg, dy in ((20, -0.075), (27, -0.082), (36, -0.08), (46, -0.07), (56, -0.06)):
        a = math.radians(deg)
        r = HEAD_RADIUS + 0.013
        path.append(Vector((r * math.sin(a), EYE_Y + dy, -r * math.cos(a))))
    p.add("Rubber", tube(path, 0.011, segs=6, smooth=4))
    end = on_head(HEAD_RADIUS * math.sin(math.radians(56)), EYE_Y - 0.06, 0.0)
    p.add("SteelDark", cyl(0.02, 0.02, segs=10), end)  # where it goes into the skull
    return p


# --- The guns -------------------------------------------------------------------------
# (Right Arm space: the fist is the arm's end, Y = -1; the barrel's axis is
# at Z = BARREL_Z, the gun's top toward -Z, the grip going down toward +Z.)
BARREL_Z = -0.3


def gun_common(p, start):
    """Grip, frame, trigger and its guard, the rear cap: what both guns share.
    `start` = where the body begins (Y)."""
    z = BARREL_Z
    # the grip, in the fist, raked back like a pistol's
    # (in the fist: the R6 hand is the end of the arm, so most of it is hidden)
    p.add("Rubber", box(0.17, 0.62, 0.15, bevel=0.055, segments=3, taper=0.9), T(0, -0.9, 0.16) @ R(-90 + 16, 0, 0))
    p.add("Brass", box(0.19, 0.07, 0.07, bevel=0.018), T(0, -0.83, 0.47) @ R(16, 0, 0))  # the butt plate
    # the frame, from the grip up to the barrel
    p.add("SteelDark", box(0.2, 0.36, 0.2, bevel=0.04), T(0, start - 0.1, z + 0.1))
    # the trigger guard (a bent bar) and the trigger
    guard = [(0, -1.08, z + 0.17), (0, -1.2, z + 0.22), (0, -1.22, z + 0.33), (0, -1.12, z + 0.4)]
    p.add("SteelDark", tube(guard, 0.018, segs=8, smooth=5))
    p.add("Chrome", box(0.035, 0.04, 0.11, bevel=0.014), T(0, -1.15, z + 0.27) @ R(-25, 0, 0))
    # the rear cap and its knob, over the fist
    p.add("Brass", lathe([(0, 0), (0.1, 0), (0.13, 0.03), (0.14, 0.08), (0.13, 0.12), (0, 0.12)], segs=24), T(0, start + 0.1, z) @ R(180, 0, 0))
    p.add("Chrome", sphere(0.045, 12, 8), T(0, start + 0.12, z))


def build_ray_gun():
    p = Piece("RayGun")
    z = BARREL_Z
    y0 = -0.95  # the body starts just in front of the fist
    gun_common(p, y0)
    # the body: a fat rocket-like fuselage along -Y
    body = lathe(
        [(0, 0), (0.11, 0.0), (0.165, 0.05), (0.175, 0.18), (0.17, 0.34), (0.135, 0.46), (0.09, 0.52), (0.078, 0.66), (0.072, 0.8), (0.0, 0.8)],
        segs=32,
    )
    p.add("Steel", body, T(0, y0, z) @ R(180, 0, 0))
    for i in range(4):  # cooling fins
        p.add("Brass", lathe([(0.15, -0.012), (0.215, -0.012), (0.222, 0), (0.215, 0.012), (0.15, 0.012)], segs=32), T(0, y0 - 0.07 - i * 0.07, z))
    p.add("SteelDark", cyl(0.18, 0.06, segs=32, bevel=0.01), T(0, y0 - 0.38, z))
    # a copper coil round the barrel
    coil = [Vector((0.098 * math.cos(t), y0 - 0.5 - t * 0.011, 0.098 * math.sin(t))) for t in [k * 0.35 for k in range(66)]]
    p.add("Brass", tube(coil, 0.012, segs=6, smooth=0), T(0, 0, z))
    # the glass tube on top with glowing fluid, its brass holders
    p.add("Glass", cyl(0.052, 0.46, segs=16, bevel=0.016), T(0, y0 - 0.22, z - 0.21))
    p.add("Glow", cyl(0.037, 0.42, segs=12), T(0, y0 - 0.22, z - 0.21))
    for dy in (0.0, -0.44):
        p.add("Brass", cyl(0.064, 0.045, segs=16, bevel=0.009), T(0, y0 + dy, z - 0.21))
        p.add("SteelDark", box(0.05, 0.04, 0.1), T(0, y0 + dy, z - 0.14))
    # hoses from the tank to the dish, one each side
    for side in (-1, 1):
        p.add(
            "Rubber",
            tube([(side * 0.15, y0 - 0.1, z - 0.06), (side * 0.2, y0 - 0.35, z), (side * 0.14, y0 - 0.65, z), (side * 0.1, y0 - 0.78, z)], 0.018, segs=8),
        )
    # the emitter dish at the front, the needle, three prongs, the glowing tip
    d0 = y0 - 0.8
    p.add("Chrome", lathe([(0.05, 0.0), (0.27, 0.11), (0.28, 0.125), (0.265, 0.132), (0.045, 0.026), (0.04, 0.0)], segs=40), T(0, d0, z) @ R(180, 0, 0))
    p.add("Brass", torus(0.272, 0.013, segs=40, rsegs=6), T(0, d0 - 0.127, z))
    p.add("SteelDark", cyl(0.065, 0.07, segs=16), T(0, d0 - 0.02, z))
    p.add("Brass", cyl(0.02, 0.2, segs=8, r2=0.008), T(0, d0 - 0.13, z) @ R(180, 0, 0))
    for k in range(3):
        a = math.radians(90 + 120 * k)
        u = Vector((math.cos(a), 0, math.sin(a)))
        pts = [Vector((0, d0 - 0.1, z)) + u * 0.21, Vector((0, d0 - 0.2, z)) + u * 0.12, Vector((0, d0 - 0.26, z)) + u * 0.045]
        p.add("Chrome", tube(pts, 0.01, segs=6, smooth=4))
    p.add("Glow", sphere(0.048, 14, 8), T(0, d0 - 0.27, z))
    p.mark("RayGun_Tip", (0, d0 - 0.27, z))
    return p


def build_portal_gun():
    p = Piece("PortalGun")
    z = BARREL_Z
    y0 = -0.95
    gun_common(p, y0)
    # a boxy lab device: a dark frame, two curved grey covers, rivets
    p.add("SteelDark", box(0.3, 0.6, 0.3, bevel=0.07, segments=3), T(0, y0 - 0.28, z))
    for a0, a1 in ((200, 340), (20, 160)):
        p.add("Steel", shell_arc(0.17, 0.205, y0 - 0.54, y0 - 0.03, a0, a1, segs=12), T(0, 0, z))
        for y in (y0 - 0.07, y0 - 0.5):
            for a in (a0 + 6, a1 - 6):
                p.rivet("Steel", azim(a) * 0.207 + Vector((0, y, z)), azim(a), r=0.013)
    # a glass capsule of green fluid on top
    cap = T(0, y0 - 0.28, z - 0.25)
    p.add("Glass", lathe([(0, -0.25), (0.03, -0.245), (0.062, -0.21), (0.068, 0.21), (0.03, 0.245), (0, 0.25)], segs=18), cap)
    p.add("Glow", lathe([(0, -0.21), (0.047, -0.2), (0.052, 0.17), (0, 0.18)], segs=12), cap)
    for dy in (0.22, -0.22):
        p.add("Brass", cyl(0.078, 0.04, segs=16, bevel=0.009), cap @ T(0, dy, 0))
        p.add("SteelDark", box(0.05, 0.04, 0.12), cap @ T(0, dy, 0.08))
    # coils and a dark neck at the front of the body
    for i in range(3):
        p.add("Brass", lathe([(0.14, -0.024), (0.205, -0.024), (0.212, 0), (0.205, 0.024), (0.14, 0.024)], segs=28), T(0, y0 - 0.64 - i * 0.07, z))
    p.add("SteelDark", cyl(0.14, 0.26, segs=24, bevel=0.02), T(0, y0 - 0.71, z))
    # the glass bulb with the core inside, held by three chrome claws
    b = y0 - 0.98
    p.add("Glass", sphere(0.17, 24, 14), T(0, b, z))
    p.add("Glow", sphere(0.075, 16, 10), T(0, b, z))
    p.add("Brass", torus(0.13, 0.022, segs=28, rsegs=6), T(0, b + 0.14, z))
    for k in range(3):
        a = math.radians(90 + 120 * k)
        u = Vector((math.cos(a), 0, math.sin(a)))
        pts = [Vector((0, b + 0.15, z)) + u * 0.14, Vector((0, b + 0.04, z)) + u * 0.2, Vector((0, b - 0.08, z)) + u * 0.17, Vector((0, b - 0.15, z)) + u * 0.1]
        p.add("Chrome", tube(pts, 0.018, segs=8, smooth=5, radii=lambda t: 0.019 * (1 - 0.5 * t)))
    # hoses from the capsule to the bulb
    for side in (-1, 1):
        p.add("Rubber", tube([(side * 0.06, y0 - 0.48, z - 0.29), (side * 0.12, y0 - 0.68, z - 0.24), (side * 0.13, y0 - 0.83, z - 0.13)], 0.017, segs=8))
    p.mark("PortalGun_Tip", (0, b, z))
    return p


# --- The flask -------------------------------------------------------------------------
def build_flask():
    p = Piece("Flask")
    # (profile of the glass, outside then inside: a closed solid with a thin wall)
    bulb_r, neck_r, wall = 0.2, 0.055, 0.012
    out = []
    for k in range(15):
        a = math.radians(-90 + k * (90 + 72) / 14)  # round bottom up to the shoulder
        out.append((bulb_r * math.cos(a), bulb_r * math.sin(a)))
    sh = out[-1]
    out += [(neck_r + 0.004, sh[1] + 0.05), (neck_r, sh[1] + 0.08), (neck_r, 0.32), (neck_r + 0.014, 0.33), (neck_r + 0.014, 0.35)]
    inner = [(max(r - wall, 0.0), y) for r, y in reversed(out)]
    inner[-1] = (0.0, inner[-1][1] + wall)
    profile = [(0.0, -bulb_r)] + out[1:] + [(neck_r - wall, 0.35)] + inner[2:]
    p.add("Glass", lathe(profile, segs=32))
    # the liquid: fills the bulb up to just over its middle, a flat top
    level = 0.04
    liq = [(0, -bulb_r + wall + 0.002)]
    for k in range(1, 12):
        a = math.radians(-90 + k * 90 / 12 * (1 + math.asin(level / (bulb_r - wall - 0.003)) / (math.pi / 2)))
        liq.append(((bulb_r - wall - 0.003) * math.cos(a), (bulb_r - wall - 0.003) * math.sin(a)))
    liq[-1] = (math.sqrt((bulb_r - wall - 0.003) ** 2 - level**2), level)
    liq.append((0, level))
    p.add("Liquid", lathe(liq, segs=32))
    # the cork
    p.add(
        "Cork",
        lathe(
            [
                (0, 0.27),
                (neck_r - wall - 0.002, 0.27),
                (neck_r - wall + 0.004, 0.35),
                (neck_r + 0.02, 0.36),
                (neck_r + 0.022, 0.42),
                (neck_r + 0.012, 0.43),
                (0, 0.43),
            ],
            segs=20,
        ),
    )
    # pivot at the centre of the whole flask (bottom -0.2, top 0.43)
    p.pivot_offset = Vector((0, (-0.2 + 0.43) / 2, 0))
    return p


# --- Scene & export ---------------------------------------------------------------------
def material(layer, emit=None):
    key = "R_" + layer + ("_" + str(emit) if emit else "")
    mat = bpy.data.materials.get(key)
    if mat:
        return mat
    mat = bpy.data.materials.new(key)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if layer in GLOWS or emit:
        c = emit or GLOWS[layer]
        bsdf.inputs["Base Color"].default_value = (*c, 1)
        bsdf.inputs["Emission Color"].default_value = (*c, 1)
        bsdf.inputs["Emission Strength"].default_value = 6.0
    else:
        c, metal, rough = COLORS[layer]
        bsdf.inputs["Base Color"].default_value = (*c, 1)
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
        if layer == "Glass":
            bsdf.inputs["Transmission Weight"].default_value = 1.0
            bsdf.inputs["IOR"].default_value = 1.45
    return mat


def islands(bm):
    """The connected pieces of a mesh (lists of faces)."""
    seen = set()
    out = []
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


def finish(bm, name):
    """Outward faces (Roblox draws one side only), triangles, box-projected UVs
    (so the game's materials have a texture to show: one tile per 2 studs)."""
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.faces.ensure_lookup_table()
    bm.faces.index_update()
    flipped = 0
    for group in islands(bm):
        # the signed volume of a closed piece is > 0 when its faces look out
        volume = sum(f.verts[0].co.dot(f.verts[1].co.cross(f.verts[2].co)) for f in group)
        if volume < 0:
            bmesh.ops.reverse_faces(bm, faces=group)
            flipped += 1
    if flipped:
        print(f"  {name}: {flipped} piece(s) turned outward")
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        n = f.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][axis]
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co[a] * 0.5, loop.vert.co[b] * 0.5)


def build_objects(pieces, preview_glow=None):
    objects = []
    stats = []
    for piece in pieces:
        origin = Vector(PIECES[piece.name])
        shift = getattr(piece, "pivot_offset", Vector((0, 0, 0)))
        for layer, bm in piece.layers.items():
            finish(bm, f"{piece.name}_{layer}")
            mesh = bpy.data.meshes.new(f"{piece.name}_{layer}")
            bm.to_mesh(mesh)
            bm.free()
            for poly in mesh.polygons:
                poly.use_smooth = True
            mesh.set_sharp_from_angle(angle=math.radians(38))
            ob = bpy.data.objects.new(mesh.name, mesh)
            ob.location = origin - shift
            bpy.context.scene.collection.objects.link(ob)
            emit = (preview_glow or {}).get(piece.name) if layer == "Glow" else None
            ob.data.materials.append(material(layer, emit))
            objects.append(ob)
            tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
            stats.append((mesh.name, tris))
        piece.layers = {}
        # markers: the pivot, then the piece's own points
        for name, at in [(f"{piece.name}_Pivot", Vector((0, 0, 0)) + shift)] + list(piece.markers.items()):
            objects.append(marker(name, origin - shift + Vector(at)))
    return objects, stats


def marker(name, at):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=0.03)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new(name, mesh)
    ob.location = at
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(material("Marker"))
    return ob


def all_pieces():
    return [build_arm(), build_eye(), build_ray_gun(), build_portal_gun(), build_flask()]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objects, stats = build_objects(all_pieces(), {"RayGun": RAY_GLOW})
    for name, at in (("Kit_Origin", (0, -4, 0)), ("Kit_Up", (0, -3, 0)), ("Kit_Out", (0, -4, 1))):
        objects.append(marker(name, Vector(at)))
    for name, tris in stats:
        print(f"{name:22s} {tris:6d} tris")
        assert tris < 10000, name + " is too heavy for one MeshPart"
    # Bake object locations into the meshes (one less thing for the importer).
    for ob in objects:
        ob.data.transform(ob.matrix_basis)
        ob.matrix_basis.identity()
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=f"{OUT}/RiftGear.fbx",
        use_selection=True,
        object_types={"MESH"},
        mesh_smooth_type="OFF",
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_UNITS",
        bake_space_transform=True,
        path_mode="STRIP",
    )
    print("written", f"{OUT}/RiftGear.fbx")
    if PREVIEW:
        render_previews(PREVIEW)


# --- Previews ---------------------------------------------------------------------------
def classic_head():
    """The classic head mesh at scale 1.25 (radius 0.6, straight band +-0.3,
    edges rounded by 0.3), as in build_wound_kit.py."""
    prof = [(0, 0.6)]
    for k in range(1, 9):
        a = math.radians(90 - 90 * k / 8)
        prof.append((0.3 + 0.3 * math.cos(a), 0.3 + 0.3 * math.sin(a)))
    for k in range(9):
        a = math.radians(-90 * k / 8)
        prof.append((0.3 + 0.3 * math.cos(a), -0.3 + 0.3 * math.sin(a)))
    prof.append((0, -0.6))
    return lathe(prof, segs=48)


def skin(name, bm, at, color):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.set_sharp_from_angle(angle=math.radians(40))
    ob = bpy.data.objects.new(name, mesh)
    ob.location = at
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = 0.6
    ob.data.materials.append(mat)
    return ob


def setup_render(res=(520, 520)):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.render.resolution_x, scene.render.resolution_y = res
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.18, 0.19, 0.2, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    for name, direction, energy in (("key", (0.5, -0.8, 0.6), 3.5), ("rim", (-0.6, -0.3, -0.8), 2.0), ("fill", (-0.8, -0.2, 0.5), 1.0)):
        light = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        light.data.energy = energy
        light.rotation_euler = facing(Vector(direction)).to_euler()
        scene.collection.objects.link(light)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


def facing(d):
    """A rotation whose -Z goes along `d`, its +Y as close to world +Y (up)."""
    z = -d.normalized()
    x = Vector((0, 1, 0)).cross(z).normalized()
    return Matrix((x, z.cross(x), z)).transposed()


def look(cam, at, target, lens=50, ortho=None):
    cam.location = at
    cam.rotation_euler = facing(Vector(target) - Vector(at)).to_euler()
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    else:
        cam.data.type = "PERSP"
        cam.data.lens = lens


def render_previews(out):
    os.makedirs(out, exist_ok=True)
    tag = os.environ.get("RIFT_TAG", "a")
    # 1) the pieces alone
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene, cam = setup_render()
    # (the guns in a fist: the Right Arm, see-through)
    for gun in ("RayGun", "PortalGun"):
        ob = skin("HeldBy" + gun, box(1, 2, 1, bevel=0.02), Vector(PIECES[gun]), (0.95, 0.8, 0.45))
        ob.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.35
    for ob in build_objects(all_pieces(), {"RayGun": RAY_GLOW})[0]:
        if ob.name.endswith(("_Pivot", "_PalmPoint", "_Tip", "_Cell", "_Lens")):
            ob.hide_render = True
    shots = [
        ("arm_front", (0, 0, 0), (-1.2, 0.3, -5.0), (0, -0.25, 0), 55),
        ("arm_back", (0, 0, 0), (-2.8, 0.5, 4.0), (0, -0.25, 0), 55),
        ("hand", (0, 0, 0), (-1.0, -2.3, -1.7), (0, -1.0, 0), 70),
        ("raygun", PIECES["RayGun"], (-3.2, -0.6, -1.4), (0, -1.1, -0.2), 50),
        ("portalgun", PIECES["PortalGun"], (-3.2, -0.6, -1.4), (0, -1.1, -0.2), 50),
        ("raygun_top", PIECES["RayGun"], (-1.2, -3.4, -1.6), (0, -1.3, -0.25), 50),
        ("flask", PIECES["Flask"], (0.4, 0.4, -2.2), (0, 0, 0), 60),
        ("eye", PIECES["Eye"], (0.5, 0.25, -1.6), (0.2, 0.1, -0.5), 85),
    ]
    for name, base, at, target, lens in shots:
        b = Vector(base)
        look(cam, b + Vector(at), b + Vector(target), lens)
        scene.render.filepath = f"{out}/rift_{name}_{tag}.png"
        bpy.ops.render.render(write_still=True)
    # 2) on a character: R6 boxes, the classic head with a face, the gear on
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene, cam = setup_render((560, 640))
    skin_c = (0.95, 0.8, 0.45)
    shirt = (0.12, 0.13, 0.16)
    skin("Torso", box(2, 2, 1, bevel=0.02), Vector((0, 0, 0)), shirt)
    skin("RightArm", box(1, 2, 1, bevel=0.02), Vector((1.5, 0, 0)), skin_c)
    skin("LeftLeg", box(1, 2, 1, bevel=0.02), Vector((-0.5, -2, 0)), (0.2, 0.2, 0.25))
    skin("RightLeg", box(1, 2, 1, bevel=0.02), Vector((0.5, -2, 0)), (0.2, 0.2, 0.25))
    skin("Head", classic_head(), Vector((0, 1.5, 0)), skin_c)
    # the default face: two dark ovals and a smile
    for x in (-EYE_X, EYE_X):
        eye = sphere(1, 12, 8)
        bmesh.ops.transform(eye, matrix=on_head(x, EYE_Y, -0.006) @ S(0.035, 0.012, 0.065), verts=eye.verts)
        skin("FaceEye", eye, Vector((0, 1.5, 0)), (0.02, 0.02, 0.02))
    smile = [on_head(0.16 * math.sin(t), -0.12 - 0.07 * math.cos(t), 0.0).translation for t in [math.radians(-80 + 160 * k / 12) for k in range(13)]]
    skin("Smile", tube(smile, 0.012, segs=6, smooth=0), Vector((0, 1.5, 0)), (0.02, 0.02, 0.02))
    arm, eye = build_arm(), build_eye()
    PIECES_SAVE = dict(PIECES)
    PIECES["Arm"] = (-1.5, 0, 0)
    PIECES["Eye"] = (0, 1.5, 0)
    objs, _ = build_objects([arm, eye])
    PIECES.update(PIECES_SAVE)
    for ob in objs:
        if ob.name.endswith(("_Pivot", "_PalmPoint", "_Tip", "_Cell", "_Lens")):
            ob.hide_render = True
    for name, at, target, lens in (
        ("char_front", (-2.2, 1.6, -7.5), (-0.4, 0.3, 0), 50),
        ("char_back", (-4.5, 2.2, 5.5), (-0.6, 0.3, 0), 50),
        ("char_face", (0.6, 1.8, -2.6), (0.1, 1.55, 0), 70),
        ("char_side", (-6.5, 1.0, -1.5), (-1.2, 0.2, 0), 50),
    ):
        look(cam, Vector(at), Vector(target), lens)
        scene.render.filepath = f"{out}/rift_{name}_{tag}.png"
        bpy.ops.render.render(write_still=True)


main()
