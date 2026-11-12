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
import os
import random
import sys

import bpy  # first: it makes the other Blender modules importable
import bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gore  # noqa: E402  (the burst head of the bat finisher)

OUT = sys.argv[1]
PREVIEW = "--preview" in sys.argv
LUA_OUT = "src/shared/WoundShapes.luau"
GORE_LUA_OUT = "src/shared/GoreShapes.luau"

# The classic R6 head (Roblox's avatar/heads/head.mesh, measured): a
# cylinder of radius 0.6 whose straight part is 0.6 high (y -0.3..0.3), with
# edges rounded by a radius of 0.3 up to flat caps of radius 0.3 at y = +-0.6.
HEAD_RADIUS = 0.6
HEAD_BAND = 0.3  # half height of the straight part
HEAD_BEVEL = 0.3  # radius of the rounded edges
HEAD_ORIGIN = (-4.0, 0.0, 0.0)  # where the head-shell pieces sit in the kit (insert axes)
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
    # The Boxer's finisher: a hand driven in under the right ribs, the liver
    # torn out through it. Body only. Broken real ribs in it (gore.py's anatomy).
    ("Tear", "L"): dict(length=0.8, width=0.6, depth=0.44, lip=0.075, rag=1.7),
}
# The Sentinel's heat vision ("Burn"): the skin burnt through and gone - a
# wide, round-ish hole with a black charred crust around it, the burnt skin
# of its walls leathery and tan, and at the bottom what was under the skin:
# cooked muscle (body) or the skull (head, where the skin is thin). No
# blood: a burn this hot cauterizes. Last in the kit (added after the
# others: their numbers don't move).
BURN_VARIANTS = {
    ("Burn", "S"): dict(length=0.3, width=0.26, depth=0.06, lip=0.06, rag=0.55),
    ("Burn", "M"): dict(length=0.46, width=0.4, depth=0.075, lip=0.07, rag=0.55),
    ("Burn", "L"): dict(length=0.64, width=0.54, depth=0.09, lip=0.08, rag=0.55),
}
# Where a "Tear" sits on the torso (torso space, the front face): the ribs
# inside it are taken from there.
TEAR_AT = (0.5, -0.3)

COLORS = {  # preview only: the game sets the real colours
    "Lip": (0.80, 0.62, 0.50),
    "Dermis": (0.86, 0.52, 0.50),
    "Flesh": (0.55, 0.06, 0.06),
    "Fat": (0.93, 0.80, 0.45),
    "Muscle": (0.40, 0.03, 0.04),
    "Bone": (0.90, 0.86, 0.76),
    "Blood": (0.25, 0.0, 0.0),
    "Char": (0.10, 0.07, 0.06),
    "Eschar": (0.69, 0.55, 0.41),
    "Marker": (1, 1, 1),
    "Skin": (0.80, 0.62, 0.50),
    **{k: v for k, v in gore.COLORS.items()},
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
    if kind == "Burn":
        # round-ish, wavy (the burn spreads unevenly), no splits
        noise = smooth_noise(rng, 2.5)
        for i in range(N):
            t = 2 * math.pi * i / N
            r = 1 + 0.16 * v["rag"] * noise(t) + 0.03 * rng.uniform(-1, 1)
            pts.append(Vector((a * r * math.cos(t), b * r * math.sin(t), 0)))
        return pts
    if kind in ("Lac", "Tear"):
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
def tear_ribs(pts, v):
    """The real ribs under a Tear, in the insert's axes (X = the torso's -X,
    Y up, Z out of the front), kept inside the hole and snapped in two
    where the hand went through."""
    anatomy = gore.load_anatomy()
    x0, y0 = TEAR_AT
    a, b = v["length"] / 2 * 0.92, v["width"] / 2 * 0.92
    planes = []
    for k in range(16):  # the hole, roughly (an ellipse of planes)
        t = 2 * math.pi * k / 16
        n = Vector((math.cos(t) / a, math.sin(t) / b, 0)).normalized()
        co = Vector((a * math.cos(t), b * math.sin(t), 0))
        planes.append((co, n))
    pieces = []
    for vv, ff in anatomy["ribs"]:
        local = np.stack([-(vv[:, 0] - x0), vv[:, 1] - y0, -vv[:, 2] - 0.5], axis=1)
        for side in (-1, 1):  # the two broken halves, a gap in the middle
            gap = [((side * 0.09, 0, 0), (-side, 0, 0))]
            bm = gore.cut(gore.bm_of(local, ff), planes + gap, fill=True)
            if len(bm.faces):
                pieces.append(bm)
            else:
                bm.free()
    return pieces


def bend_and_measure(b, head):
    """How far the insert reaches (before bending), then the head version
    bent around the head's vertical axis."""
    reach_x = max(abs(vert.co.x) for bm in b.parts.values() for vert in bm.verts)
    reach_low = -min(vert.co.y for bm in b.parts.values() for vert in bm.verts)
    reach_high = max(vert.co.y for bm in b.parts.values() for vert in bm.verts)
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
    return meshes, (reach_x, reach_low, reach_high)


def build_burn(size, v, head, seed):
    """A burn: the skin burnt through (see BURN_VARIANTS)."""
    rng = random.Random(seed)
    pts = outline("Burn", v, rng)
    nrm = normals2d(pts)
    c = centroid(pts)
    b = Builder(c)
    depth = v["depth"] * (0.7 if head else 1.0)  # (the skull is right under the skin)
    lip = v["lip"]
    wobble = [rng.uniform(-1, 1) for _ in range(N + 16)]

    def jit(scale):
        return lambda i: wobble[i % len(wobble)] * scale

    # Char: the black crust - from the skin, a little raised and crinkled,
    # then curling down over the edge.
    # (its width wanders: the burn ate further into the skin here and there)
    reach_noise = smooth_noise(rng, 3.0)
    widths = [lip * max(0.35, 1 + 0.75 * reach_noise(2 * math.pi * i / N)) for i in range(N)]
    outer = [pts[i] + nrm[i] * widths[i] + Vector((0, 0, 0.0015)) for i in range(N)]
    crest = [pts[i] + nrm[i] * widths[i] * 0.45 + Vector((0, 0, 0.0028 * (1 + 0.5 * wobble[i]))) for i in range(N)]
    edge = ring(pts, nrm, 0.0, 0.0022, jitter=jit(0.004))
    curl = ring(pts, nrm, -0.012, -0.014)
    b.strip("Char", outer, crest)
    b.strip("Char", crest, edge)
    b.strip("Char", edge, curl)
    # a few flat flakes of crust lifting off the rim
    for _ in range({"S": 3, "M": 5, "L": 7}[size]):
        i = rng.randrange(N)
        p = outer[i].lerp(crest[i], rng.uniform(0.2, 0.9))
        r = rng.uniform(0.007, 0.013)
        b.blob("Char", Vector((p.x, p.y, 0.0025)), (r * 1.6, r, r * 0.22), rot=rng.uniform(0, 3.14))
    # Eschar: the burnt skin of the walls, leathery, down into the hole.
    wall = ring(pts, nrm, -0.02, -depth * 0.45, center=c, shrink=0.88, jitter=jit(0.004))
    b.strip("Eschar", curl, wall)
    low = ring(pts, nrm, 0, lambda i: -depth * (0.85 + 0.06 * wobble[i]), center=c, shrink=0.72, jitter=jit(0.003))
    if head:
        # the skull: a dome of bone filling the bottom
        b.strip("Eschar", wall, low)
        b.fan("Bone", low, Vector((c.x, c.y, -depth * 0.95)))
        b.blob("Bone", Vector((c.x, c.y, -depth * 0.9)), (v["length"] * 0.3, v["width"] * 0.3, 0.012), subdiv=2)
    else:
        # cooked flesh, a few lobules of fat cooked yellow-brown, and the
        # muscle at the bottom with its fibres
        b.strip("Flesh", wall, low)
        b.fan("Muscle", low, Vector((c.x, c.y, -depth)))
        for _ in range({"S": 4, "M": 7, "L": 10}[size]):
            i = rng.randrange(N)
            p = wall[i].lerp(low[i], rng.uniform(0.2, 0.7))
            r = rng.uniform(0.006, 0.011)
            b.blob("Fat", p, (r, r * 0.8, r * 0.7))
        turn = rng.uniform(-0.5, 0.5)
        for k in range(6):
            off = (k - 2.5) * v["width"] * 0.11
            at = Vector((c.x - math.sin(turn) * off, c.y + math.cos(turn) * off, -depth * 0.96))
            b.blob("Muscle", at, (v["length"] * 0.3, 0.008, 0.006), rot=turn, subdiv=2)
    meshes, reach = bend_and_measure(b, head)
    return pts, meshes, reach


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
    swell = {"Lac": 0.005, "Tear": 0.014}.get(kind, 0.0015)
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
    deep = (kind == "Slash" and size == "L") or kind == "Tear"
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
    # Torn open by a hand: the real right lower ribs (and their cartilage)
    # across it, broken where the hand went through.
    if kind == "Tear":
        for part in tear_ribs(pts, v):
            b.parts.setdefault("Bone", bmesh.new())
            mesh = bpy.data.meshes.new("tmp")
            part.to_mesh(mesh)
            b.parts["Bone"].from_mesh(mesh)
            bpy.data.meshes.remove(mesh)
            part.free()
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
    drips = 4 if kind == "Tear" else {"S": rng.randint(0, 1), "M": 1, "L": 2}[size]
    for _ in range(drips):
        i = rng.choice(lowest)
        start = outer[i]
        length = rng.uniform(0.035, 0.09) * (1.4 if size == "L" else 1.0) * (3 if kind == "Tear" else 1)
        if head:
            length *= 0.6  # the face is short: the blood stays on the straight part
        w = rng.uniform(0.007, 0.012) * (2.2 if kind == "Tear" else 1)
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
    reach_low = -min(vert.co.y for bm in b.parts.values() for vert in bm.verts)
    reach_high = max(vert.co.y for bm in b.parts.values() for vert in bm.verts)

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
    return hole, meshes, (reach_x, reach_low, reach_high)


# --- Head shell -------------------------------------------------------------------
# Smooth pieces of the classic head, used by the game to rebuild a cut head
# exactly as it was (only the cut is open). Insert axes (X along, Y up, Z out
# of the head); the head's centre is the origin; each piece is centred on the
# angle 0 (its middle faces +Z). Normals are the true ones of the round
# shape, so the pieces join without any visible seam.
#   Shell_Band24   1/24 of the straight part, 1 stud high (the game scales Y)
#   Shell_Band192  1/192 of it (thin columns next to a cut)
#   Shell_Face<Band|Top|Bottom>_<i>  the face picture's pieces (see face_piece)
#   Shell_Bevel24  1/24 of the top rounded edge (the bottom one: turned over)
#   Shell_Cap      the flat top (the bottom one: turned over)
def shell_piece(points_normals_faces, name):
    verts, normals, faces = points_normals_faces
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    outward_check(mesh, name)
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.normals_split_custom_set_from_vertices(normals)
    return mesh


def band(arc_deg, segments):
    half = math.radians(arc_deg) / 2
    verts, normals, faces = [], [], []
    for i in range(segments + 1):
        a = -half + 2 * half * i / segments
        out = (math.sin(a), 0, math.cos(a))
        for y in (-0.5, 0.5):
            verts.append((HEAD_RADIUS * out[0], y, HEAD_RADIUS * out[2]))
            normals.append(out)
    for i in range(segments):
        a0, a1, b0, b1 = 2 * i, 2 * i + 1, 2 * i + 2, 2 * i + 3
        faces.append((a0, b0, b1, a1))  # counter-clockwise seen from outside
    return verts, normals, faces


def bevel(arc_deg, segments, rings):
    half = math.radians(arc_deg) / 2
    verts, normals, faces = [], [], []
    for i in range(segments + 1):
        a = -half + 2 * half * i / segments
        out = (math.sin(a), math.cos(a))
        for j in range(rings + 1):
            t = math.radians(90) * j / rings  # 0 = side, 90 = top
            r = HEAD_RADIUS - HEAD_BEVEL + HEAD_BEVEL * math.cos(t)
            y = HEAD_BAND + HEAD_BEVEL * math.sin(t)
            verts.append((r * out[0], y, r * out[1]))
            normals.append((math.cos(t) * out[0], math.sin(t), math.cos(t) * out[1]))
    row = rings + 1
    for i in range(segments):
        for j in range(rings):
            p, q = i * row + j, (i + 1) * row + j
            faces.append((p, q, q + 1, p + 1))
    return verts, normals, faces


def cap(segments):
    r = HEAD_RADIUS - HEAD_BEVEL
    top = HEAD_BAND + HEAD_BEVEL
    verts, normals, faces = [(0, top, 0)], [(0, 1, 0)], []
    for i in range(segments):
        a = 2 * math.pi * i / segments
        verts.append((r * math.sin(a), top, r * math.cos(a)))
        normals.append((0, 1, 0))
    for i in range(segments):
        faces.append((0, 1 + (i + 1) % segments, 1 + i))
    return verts, normals, faces


def outward_check(mesh, name):
    """Every face must face away from the head's axis (one-sided in Roblox)."""
    flipped = []
    for poly in mesh.polygons:
        c = poly.center
        away = Vector((c.x, c.y if name == "Shell_Cap" else 0, c.z))
        if poly.normal.dot(away) <= 0:
            poly.flip()
            flipped.append(poly.index)
    print(name, "faces flipped to face out:", len(flipped))


FACE_SECTORS = 24  # same as the head's columns (Gashes.luau HEAD_SECTORS)


def face_piece(index, part, segments=8, band_rows=8, bevel_rings=12):
    """The face picture's piece on one 15-degree sector of the head's front:
    its straight part ("Band"), or its top / bottom rounded edge. Its UVs are
    exactly how Roblox maps a face on the classic head (measured from
    head.mesh: a flat projection from the front, u = 0.5 - x / 1.2,
    v = 0.5 - y / 1.2), so the pieces together draw the face in one go,
    without seams; next to a cut, the game leaves out the Band piece (the
    hole is there). Built at its real place around the head (angle 0 = the
    face, insert axes)."""
    profile = []  # (radius, y, normal radial part, normal y), bottom to top
    if part == "Bottom":
        for j in range(bevel_rings, -1, -1):
            t = math.radians(90) * j / bevel_rings
            profile.append((HEAD_RADIUS - HEAD_BEVEL + HEAD_BEVEL * math.cos(t), -HEAD_BAND - HEAD_BEVEL * math.sin(t), math.cos(t), -math.sin(t)))
    elif part == "Band":
        for j in range(band_rows + 1):
            profile.append((HEAD_RADIUS, -HEAD_BAND + 2 * HEAD_BAND * j / band_rows, 1.0, 0.0))
    else:
        for j in range(bevel_rings + 1):
            t = math.radians(90) * j / bevel_rings
            profile.append((HEAD_RADIUS - HEAD_BEVEL + HEAD_BEVEL * math.cos(t), HEAD_BAND + HEAD_BEVEL * math.sin(t), math.cos(t), math.sin(t)))
    rows = len(profile)
    sector = 360 / FACE_SECTORS
    # Gashes: sector `index` covers head angles index*15 .. (index+1)*15
    # degrees, measured toward the head's +X; the kit's +X is the head's -X.
    start = -(index + 1) * sector
    verts, normals, faces, uvs = [], [], [], []
    for i in range(segments + 1):
        a = math.radians(start + sector * i / segments)
        sa, ca = math.sin(a), math.cos(a)
        for r, y, nr, ny in profile:
            x, z = r * sa, r * ca
            verts.append((x, y, z))
            normals.append((nr * sa, ny, nr * ca))
            # the head's x is -x here
            uvs.append((0.5 + x / (2 * HEAD_RADIUS), 1 - (0.5 - y / (2 * HEAD_RADIUS))))
    for i in range(segments):
        for j in range(rows - 1):
            p, q = i * rows + j, (i + 1) * rows + j
            faces.append((p, q, q + 1, p + 1))
    return verts, normals, faces, uvs


def front_sectors():
    """The sectors whose middle faces the front (where the face is)."""
    sector = 2 * math.pi / FACE_SECTORS
    return [i for i in range(FACE_SECTORS) if math.cos((i + 0.5) * sector) > 0]


def build_head_shell():
    pieces = {
        "Shell_Band24": band(15, 8),
        "Shell_Band192": band(1.875, 2),
        "Shell_Bevel24": bevel(15, 8, 10),
        "Shell_Cap": cap(192),  # same rim points as the 24 bevels (8 each): no crack
    }
    out = {name: shell_piece(data, name) for name, data in pieces.items()}
    for index in front_sectors():
        for part in ("Band", "Top", "Bottom"):
            name = f"Shell_Face{part}_{index}"
            verts, normals, faces, uvs = face_piece(index, part)
            mesh = shell_piece((verts, normals, faces), name)
            uv = mesh.uv_layers.new(name="UVMap")
            for poly in mesh.polygons:
                for li in poly.loop_indices:
                    uv.data[li].uv = uvs[mesh.loops[li].vertex_index]
            out[name] = mesh
    return out


# --- Block frames (torso, limbs) ------------------------------------------------
# Roblox draws an R6 torso / arm / leg as a box whose edges are cut at 45 deg
# by CHAMFER (avatar/meshes/torso.mesh), the clothes stretched over it. The
# game rebuilds a cut torso as: flat tiles for the inside of each face (with
# the hole), plus this FRAME: the 12 bevelled edges and 8 corners, textured
# with the shirt / pants template (MeshPart.TextureID), so the edges look
# exactly like before. Built in the part's own axes (X right, Y up, -Z front),
# then turned like the head pieces (angle 0: X and Z flipped).
CHAMFER = 0.065
INSET = 0.034  # the template's face region reaches this far into the bevel
TEMPLATE_W, TEMPLATE_H = 585, 559
REGIONS = {  # same as Gashes.luau: {x, y, w, h} pixels per face
    "Torso": {"Front": (231, 74, 128, 128), "Back": (427, 74, 128, 128), "Left": (361, 74, 64, 128),
              "Right": (165, 74, 64, 128), "Top": (231, 8, 128, 64), "Bottom": (231, 204, 128, 64)},
    "Right": {"Front": (217, 355, 64, 128), "Back": (85, 355, 64, 128), "Left": (19, 355, 64, 128),
              "Right": (151, 355, 64, 128), "Top": (217, 289, 64, 64), "Bottom": (217, 485, 64, 64)},
    "Left": {"Front": (308, 355, 64, 128), "Back": (440, 355, 64, 128), "Left": (374, 355, 64, 128),
             "Right": (506, 355, 64, 128), "Top": (308, 289, 64, 64), "Bottom": (308, 485, 64, 64)},
}
FACES = {  # outward normal, picture "up" (as in Gashes.luau)
    "Front": ((0, 0, -1), (0, 1, 0)), "Back": ((0, 0, 1), (0, 1, 0)),
    "Left": ((-1, 0, 0), (0, 1, 0)), "Right": ((1, 0, 0), (0, 1, 0)),
    "Top": ((0, 1, 0), (0, 0, 1)), "Bottom": ((0, -1, 0), (0, 0, -1)),
}


def face_uv(face, regions, size, p):
    """UV of point p (part axes) in the template, seen on `face` (clamped to
    that face's region)."""
    n, up = (Vector(v) for v in FACES[face])
    right = (-n).cross(up)
    half = Vector(size) / 2
    sw = abs(right.dot(half)) - INSET
    sh = abs(up.dot(half)) - INSET
    a = (p.dot(right) + sw) / (2 * sw)  # 0 = your left
    b = (sh - p.dot(up)) / (2 * sh)  # 0 = top
    x, y, w, h = regions[face]
    px = x + min(max(a, 0), 1) * w
    py = y + min(max(b, 0), 1) * h
    return (px / TEMPLATE_W, 1 - py / TEMPLATE_H)  # Blender UVs: v up


def frame(size, regions):
    hx, hy, hz = (d / 2 for d in size)
    c = CHAMFER
    verts, normals, uvs, faces = [], [], [], []

    def on(face, sx, sy, sz):
        """The corner of `face`'s flat inside toward signs (sx, sy, sz)."""
        n = FACES[face][0]
        x = sx * (hx if n[0] else hx - c)
        y = sy * (hy if n[1] else hy - c)
        z = sz * (hz if n[2] else hz - c)
        return Vector((x, y, z)), Vector(n)

    def poly(points):
        """points: (position, normal, face whose picture it shows)."""
        idx = []
        for (p, n, face) in points:
            verts.append(tuple(p))
            normals.append(tuple(n))
            uvs.append(face_uv(face, regions, size, p))
            idx.append(len(verts) - 1)
        # wind it to face outward (away from the centre)
        centre = sum((Vector(verts[i]) for i in idx), Vector()) / len(idx)
        a, b2, c2 = (Vector(verts[i]) for i in idx[:3])
        if (b2 - a).cross(c2 - a).dot(centre) < 0:
            idx.reverse()
        faces.append(tuple(idx))

    sign_face = {(0, -1): "Left", (0, 1): "Right", (1, -1): "Bottom", (1, 1): "Top", (2, -1): "Front", (2, 1): "Back"}
    # 12 edges: faces A and B (axes i, j with signs), running along axis k.
    # Each bevel is cut along its middle: each half shows its own face's
    # picture, the middle being the edge of both pictures (INSET ~ CHAMFER/2),
    # like Roblox. The normals blend from one face to the other.
    for i, j in ((0, 1), (0, 2), (1, 2)):
        k = 3 - i - j
        for si in (-1, 1):
            for sj in (-1, 1):
                fa, fb = sign_face[(i, si)], sign_face[(j, sj)]
                ends = []
                for sk in (-1, 1):
                    s3 = [0, 0, 0]
                    s3[i], s3[j], s3[k] = si, sj, sk
                    (pa, na), (pb, nb) = on(fa, *s3), on(fb, *s3)
                    mid, nm = (pa + pb) / 2, (na + nb).normalized()
                    ends.append((pa, na, pb, nb, mid, nm))
                (a0, na0, b0, nb0, m0, nm0), (a1, na1, b1, nb1, m1, nm1) = ends
                poly([(a0, na0, fa), (a1, na1, fa), (m1, nm1, fa), (m0, nm0, fa)])
                poly([(m0, nm0, fb), (m1, nm1, fb), (b1, nb1, fb), (b0, nb0, fb)])
    # 8 corners: 3 quads (one per face) meeting in the middle of the corner.
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                fx, fy, fz = sign_face[(0, sx)], sign_face[(1, sy)], sign_face[(2, sz)]
                px, py, pz = on(fx, sx, sy, sz), on(fy, sx, sy, sz), on(fz, sx, sy, sz)
                centre = (px[0] + py[0] + pz[0]) / 3
                nc = (px[1] + py[1] + pz[1]).normalized()

                def half(p, q):
                    return (p[0] + q[0]) / 2, (p[1] + q[1]).normalized()

                for own, a, b in ((px, py, pz), (py, pz, px), (pz, px, py)):
                    face = fx if own is px else fy if own is py else fz
                    ma, mb = half(own, a), half(own, b)
                    poly([(own[0], own[1], face), (ma[0], ma[1], face), (centre, nc, face), (mb[0], mb[1], face)])
    # part axes -> kit axes (as the head pieces at angle 0): X and Z flipped
    verts = [(-x, y, -z) for x, y, z in verts]
    normals = [(-x, y, -z) for x, y, z in normals]
    mesh = bpy.data.meshes.new("frame")
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    # (that turn is a rotation: the faces still point outward)
    uv = mesh.uv_layers.new(name="UVMap")
    for poly_ in mesh.polygons:
        for li in poly_.loop_indices:
            uv.data[li].uv = uvs[mesh.loops[li].vertex_index]
    for poly_ in mesh.polygons:
        poly_.use_smooth = True
    mesh.normals_split_custom_set_from_vertices(normals)
    return mesh


FRAMES = {  # name: (size, regions, where in the kit)
    "Shell_FrameTorso": ((2, 2, 1), "Torso", (-8.0, 0.0, 0.0)),
    "Shell_FrameRight": ((1, 2, 1), "Right", (-11.0, 0.0, 0.0)),
    "Shell_FrameLeft": ((1, 2, 1), "Left", (-13.0, 0.0, 0.0)),
}


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
            if head and kind == "Tear":
                continue  # (body only)
            name = f"{kind}{size}" + ("_Head" if head else "")
            seed = sum(map(ord, name)) * 7919  # same shapes on every run
            pts, meshes, reach = build_insert(kind, size, v, head, seed)
            offset = Vector((index * SPACING, 0, 0))
            for layer, bm in meshes.items():
                objects.append(add_object(f"{name}_{layer}", bm, offset, layer))
            shapes.append((name, index, kind, size, head, v, pts, reach))
            index += 1
    # The burns, last (the numbers of the others don't move).
    for head in (False, True):
        for (kind, size), v in BURN_VARIANTS.items():
            name = f"{kind}{size}" + ("_Head" if head else "")
            seed = sum(map(ord, name)) * 7919
            pts, meshes, reach = build_burn(size, v, head, seed)
            offset = Vector((index * SPACING, 0, 0))
            for layer, bm in meshes.items():
                objects.append(add_object(f"{name}_{layer}", bm, offset, layer))
            shapes.append((name, index, kind, size, head, v, pts, reach))
            index += 1
    # The head shell pieces.
    for name, mesh in build_head_shell().items():
        ob = bpy.data.objects.new(name, mesh)
        ob.location = Vector(HEAD_ORIGIN)
        bpy.context.scene.collection.objects.link(ob)
        ob.data.materials.append(material("Skin"))
        objects.append(ob)
    # The bevelled frames of the torso and limbs.
    for name, (size, regions, where) in FRAMES.items():
        ob = bpy.data.objects.new(name, frame(size, REGIONS[regions]))
        ob.location = Vector(where)
        bpy.context.scene.collection.objects.link(ob)
        ob.data.materials.append(material("Skin"))
        objects.append(ob)
    # The burst head (bat finisher): real anatomy, broken up.
    before = len(bpy.context.scene.collection.objects)
    gore_slots, gore_kinds = gore.build(
        lambda name, bm, offset, layer: objects.append(add_object(name, bm, offset, layer))
    )
    print("gore objects:", len(bpy.context.scene.collection.objects) - before)
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
        "-- The head shell pieces (Shell_*) are around headOrigin (+ markerDrop in Y).",
        "",
        "export type Shape = {",
        "\tindex: number,",
        "\tkind: string, -- \"Lac\" (smashed bottle) / \"Slash\" (broken bottle)",
        "\tsize: string, -- \"S\" / \"M\" / \"L\"",
        "\thead: boolean, -- bent for the round head",
        "\tlip: number, -- width of the skin edge around the hole (studs)",
        "\textent: Vector2, -- half size of the whole insert on the skin (X, Y)",
        "\tlow: number, -- how far it reaches below its centre (blood drips)",
        "\thigh: number, -- how far it reaches above its centre",
        "\tpoints: { Vector2 }, -- the hole cut in the skin (the edge without its thin splits)",
        "}",
        "",
        "local WoundShapes = {",
        f"\tspacing = {lua_number(SPACING)},",
        f"\theadRadius = {lua_number(HEAD_RADIUS)},",
        "\tmarkerDrop = 3,",
        f"\theadBand = {lua_number(HEAD_BAND)},",
        f"\theadBevel = {lua_number(HEAD_BEVEL)},",
        f"\theadOrigin = Vector3.new({', '.join(lua_number(x) for x in HEAD_ORIGIN)}),",
        f"\tchamfer = {lua_number(CHAMFER)},",
        f"\tinset = {lua_number(INSET)},",
        "\tframes = {",
        *[f"\t\t{n} = Vector3.new({', '.join(lua_number(x) for x in w)})," for n, (_s, _r, w) in FRAMES.items()],
        "\t} :: { [string]: Vector3 },",
        "\tshapes = {",
    ]
    for name, idx, kind, size, head, v, pts, reach in shapes:
        ex, low, high = reach
        ey = max(low, high)
        lines.append(f"\t\t{name} = {{")
        lines.append(f"\t\t\tindex = {idx},")
        lines.append(f'\t\t\tkind = "{kind}",')
        lines.append(f'\t\t\tsize = "{size}",')
        lines.append(f"\t\t\thead = {'true' if head else 'false'},")
        lines.append(f"\t\t\tlip = {lua_number(v['lip'])},")
        lines.append(f"\t\t\textent = Vector2.new({lua_number(ex)}, {lua_number(ey)}),")
        lines.append(f"\t\t\tlow = {lua_number(low)},")
        lines.append(f"\t\t\thigh = {lua_number(high)},")
        lines.append("\t\t\tpoints = {")
        for p in pts:
            lines.append(f"\t\t\t\tVector2.new({lua_number(p.x)}, {lua_number(p.y)}),")
        lines.append("\t\t\t},")
        lines.append("\t\t},")
    lines += ["\t} :: { [string]: Shape },", "}", "", "return WoundShapes", ""]
    with open(LUA_OUT, "w") as f:
        f.write("\n".join(lines))
    with open(GORE_LUA_OUT, "w") as f:
        f.write(gore.lua(gore_slots, gore_kinds))
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
