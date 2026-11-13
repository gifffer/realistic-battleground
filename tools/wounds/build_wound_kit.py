"""
Builds the wound "inserts" of the game: realistic cuts made by glass, as
small 3D cups that sit in a hole of the skin.

    venv/bin/python tools/wounds/build_wound_kit.py <out_dir> [--preview]

Writes:
  <out_dir>/WoundKit.fbx               every insert, ready for Studio's 3D Importer
  src/shared/WoundShapes.luau          the outline of each insert (the game
                                       cuts the skin along it) - generated, do
                                       not edit by hand
  <out_dir>/preview_*.png              pictures (with --preview): each insert, and the
                                       newest gore pieces (GORE_VIEWS)

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
The Sentinel's heat vision (Burn, Bore) adds, with no blood at all:
  Char      the black charred crust (and seared black patches inside)
  Eschar    the burnt, leathery skin and seared tissue (tan-brown)
  Cartilage the costal cartilage of the ribs (blue-white)   (Bore only)
  Lung      the lung's edge (pink-grey, spongy)              (Bore only)
  Heart     the heart's muscle cut through (dark red)        (Bore only)
  HeartDark the inside of its chamber (darker still)         (Bore only)

The open fractures of the heavy hits (Break: BreakArm / BreakLeg, L for the
left limbs, see BREAK_VARIANTS and fracture.py) are deep closed cups in a
limb's front, built from the real anatomy (Z-Anatomy, limbs.npz), with the
broken bones out of them; they add:
  Marrow     the bone's marrow, sunk into its broken ends (dark red)
  MuscleDark the next muscle (a darker red: one muscle from the next)
  FleshDark  clotted blood between the muscles, where the bones were
  Artery / Vein / Nerve   the real vessels and nerves, torn

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
from mathutils import Matrix, Vector, noise  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fracture  # noqa: E402  (the open fractures)
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
# The Sentinel's finisher ("Bore"): the heat vision held on the chest over
# the heart bores a deep, round, blind hole. Cauterised: no blood at all. A
# black crust round it (Char), then the real anatomy (Z-Anatomy, torso.npz)
# cut by the beam, seared: the skin and its fat, the pectoral muscle, the
# ribs' cartilage and the sternum's edge, the lung's edge on the side, and at
# the bottom the heart: its right ventricle's wall cut through, the chamber
# open behind it. Torso only; last in the kit (the others' numbers don't
# move). S only reaches the muscle and the ribs; M the ribs and the lung;
# L goes into the heart.
BORE_VARIANTS = {
    ("Bore", "S"): dict(length=0.3, width=0.29, depth=0.2, lip=0.06, rag=0.35),
    ("Bore", "M"): dict(length=0.42, width=0.4, depth=0.35, lip=0.07, rag=0.35),
    ("Bore", "L"): dict(length=0.55, width=0.53, depth=0.5, lip=0.08, rag=0.35),
}
BORE_AT = (-0.22, 0.35)  # torso space, the front face: over the heart (the character's left)
BORE_FAT = 0.05  # depth of the muscles' front under the skin (the skin and its fat above)
# (see Chest: the ribs at ~0.17-0.25 under the skin - S just reaches them -,
# the heart's front at ~0.37 - M stops before it -, its right ventricle's
# chamber behind its wall from ~0.41 - L opens it)

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
    "Cartilage": (0.80, 0.85, 0.88),
    "Lung": (0.72, 0.52, 0.54),
    "Heart": (0.42, 0.05, 0.06),
    "HeartDark": (0.20, 0.02, 0.03),
    "Marker": (1, 1, 1),
    "Marrow": (0.33, 0.03, 0.04),
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
    if kind in ("Burn", "Bore"):
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


class Chest:
    """The real chest round the heart (torso.npz, torso space), read along
    the beam: for a point of the insert, the tissue that is there.

    Along each line straight into the chest (a "column"), the real tissues
    are found in their real order (skin side first): the pectoral muscle,
    then the ribs / their cartilage / the sternum / the muscles between the
    ribs, the lung's edge or the fat round the heart, the heart's wall, its
    chamber, its septum... The R6 torso is only 1 stud deep (the anatomy is
    thin in it) and Z-Anatomy leaves out what is between the organs (fat,
    fascia, pleura): each layer is given a real thickness in the insert
    (1 stud ~ 16 cm), the gaps between them closed up."""

    # tissue -> its groups in torso.npz; where they overlap, the first wins
    TISSUES = (
        ("Bone", ("sternum", "chestribs")),
        ("Cartilage", ("cartilage",)),
        ("Papillary", ("papillary",)),
        ("Heart", ("rventricle", "lventricle")),
        ("Muscle", ("pectoral",)),
        ("Wall", ("intercostal",)),
        ("Lung", ("lung",)),
    )
    WALL = ("Bone", "Cartilage", "Wall")  # the chest wall

    def __init__(self):
        groups = gore.load_anatomy(gore.TORSO_ANATOMY)

        def tree(names):
            # (bm_of: faces turned outward - the left side's meshes come
            # inside out from Z-Anatomy; the rays tell in from out by them)
            bm = gore.bm_join_all([gore.bm_of(vv, ff) for name in names for vv, ff in groups[name]])
            out = BVHTree.FromBMesh(bm)
            bm.free()
            return out

        self.trees = [(tissue, tree(names)) for tissue, names in self.TISSUES]
        self.cache = {}

    def torso_xy(self, p):
        """Insert axes -> the torso's X, Y (the insert's X is the torso's -X)."""
        x0, y0 = BORE_AT
        return x0 - p.x, y0 + p.y

    def spans(self, x, y):
        """The real tissues along the column at (x, y): [(tissue, z0, z1)]
        front to back (torso Z), overlaps settled by TISSUES' order."""
        d = Vector((0, 0, 1))
        cuts = set()
        found = []
        for rank, (tissue, t) in enumerate(self.trees):
            o = Vector((x, y, -1.0))
            start = None
            for _ in range(48):
                hit, n, _i, _dist = t.ray_cast(o, d, 1.4)
                if hit is None:
                    break
                if n.dot(d) < 0:
                    start = hit.z
                elif start is not None:
                    found.append((rank, tissue, start, hit.z))
                    cuts.update((start, hit.z))
                    start = None
                o = hit + d * 1e-4
        cuts = sorted(cuts)
        out = []
        for a, b in zip(cuts, cuts[1:]):
            m = (a + b) / 2
            over = [(rank, tissue) for rank, tissue, z0, z1 in found if z0 <= m <= z1]
            tissue = min(over)[1] if over else None
            if out and out[-1][0] == tissue:
                out[-1] = (tissue, out[-1][1], b)
            else:
                out.append((tissue, a, b))
        return out

    def column(self, x, y):
        """The layers of the column at (x, y) in the insert: [(layer, depth
        it ends at)], from the skin down."""
        key = (round(x / 0.004), round(y / 0.004))
        if key in self.cache:
            return self.cache[key]
        spans = self.spans(x, y)
        # (only what is between the skin and a little behind the heart)
        layers = [("Eschar", 0.016), ("Fat", BORE_FAT)]
        depth = BORE_FAT
        seen_wall = seen_heart = False

        def add(layer, thickness):
            nonlocal depth
            depth += thickness
            if layers[-1][0] == layer:
                layers[-1] = (layer, depth)
            else:
                layers.append((layer, depth))

        solid = [s for s in spans if s[0] is not None]
        if not any(s[0] == "Muscle" for s in solid[:2]):
            add("Muscle", 0.07)  # (the pectoral's edge: a thinner muscle layer)
        prev = None
        for tissue, z0, z1 in solid:
            t = z1 - z0
            gap = z0 - prev if prev is not None else 0.0
            prev = z1
            if tissue == "Muscle" and not seen_wall:
                add("Muscle", min(0.13, max(0.07, t * 2.5)))
            elif tissue in self.WALL and not seen_heart:
                if not seen_wall:
                    add("Muscle", 0.012)  # (fascia, the edge of the muscles between the ribs)
                seen_wall = True
                add("Muscle" if tissue == "Wall" else tissue, min(0.11, max(0.06, t * 3.5)))
            elif tissue == "Lung" and not seen_heart:
                if not seen_wall:
                    add("Muscle", 0.06)  # (the chest wall, even between the ribs)
                    seen_wall = True
                add("Fat", 0.008)
                add("Lung", min(0.16, max(0.04, t * 1.3)))
            elif tissue in ("Heart", "Papillary"):
                if not seen_heart:
                    if not seen_wall:
                        add("Muscle", 0.06)
                        seen_wall = True
                    # the fat round the heart up to its front (at ~0.36)
                    add("Fat", max(0.02, 0.36 - depth))
                    add("Heart", min(0.06, max(0.035, t * 2.0)))
                    seen_heart = True
                elif gap > 0.006 and gap < 0.25 and layers[-1][0] in ("Heart", "Papillary"):
                    # behind the heart's wall: its chamber, then the far wall
                    add("HeartDark", min(0.2, max(0.08, gap * 1.3)))
                    add(tissue, min(0.1, max(0.03, t * 1.5)))
                else:
                    add(tissue, min(0.1, max(0.03, t * 1.5)))
            if depth > 1.0:
                break
        if not seen_heart:
            add("Fat", 0.1)
        layers.append((layers[-1][0], 9.0))  # (the last goes on)
        self.cache[key] = layers
        return layers

    def tissue(self, p):
        """The layer at p (insert axes): "HeartDark" for the chamber's
        empty inside, "Heart" for the heart's muscle."""
        x, y = self.torso_xy(p)
        d = -p.z
        for layer, end in self.column(x, y):
            if d <= end:
                return "Heart" if layer == "Papillary" else layer
        return "Fat"

    def floor(self, p):
        """Under a point in the chamber: how deep its far wall is and what
        it looks like ((depth, layer) or None): the chamber's inside
        (HeartDark), or a papillary muscle standing in it (Heart)."""
        x, y = self.torso_xy(p)
        d = -p.z
        layers = self.column(x, y)
        for k, (layer, end) in enumerate(layers):
            if d <= end:
                if layer == "HeartDark" and k + 1 < len(layers):
                    return end, "Heart" if layers[k + 1][0] == "Papillary" else "HeartDark"
                return None
        return None


# Each tissue stands out of the bore's wall or shrinks back (studs, + = back
# into the wall): bone and cartilage resist the heat, the lung collapses,
# the chamber opens wider behind the heart's wall.
BORE_RELIEF = {"Bone": -0.01, "Cartilage": -0.006, "Muscle": 0.004, "Fat": 0.007, "Heart": 0.0, "HeartDark": 0.04,
               "Lung": 0.014, "Eschar": 0.002}


def build_bore(size, v, seed, chest):
    """The Sentinel's bore over the heart (see BORE_VARIANTS): a closed cup
    from the charred rim down to the bottom; every point of its wall and of
    its bottom shows the real tissue that is there (Chest), seared in
    patches (Char, Eschar)."""
    rng = random.Random(seed)
    pts = outline("Bore", v, rng)
    nrm = normals2d(pts)
    c = centroid(pts)
    b = Builder(c)
    depth, lip = v["depth"], v["lip"]
    n = len(pts)
    wobble = [rng.uniform(-1, 1) for _ in range(n + 16)]
    noise.seed_set(seed % 100000)
    grain = Vector((rng.uniform(0, 50), rng.uniform(0, 50), rng.uniform(0, 50)))

    def jit(scale):
        return lambda i: wobble[i % len(wobble)] * scale

    # Char: the black crust on the skin round the hole, raised, crinkled,
    # curling down over the edge (as a burn's), with flakes lifting off.
    reach_noise = smooth_noise(rng, 3.0)
    widths = [lip * max(0.4, 1 + 0.6 * reach_noise(2 * math.pi * i / n)) for i in range(n)]
    outer = [pts[i] + nrm[i] * widths[i] + Vector((0, 0, 0.0015)) for i in range(n)]
    crest = [pts[i] + nrm[i] * widths[i] * 0.4 + Vector((0, 0, 0.004 * (1 + 0.5 * wobble[i]))) for i in range(n)]
    edge = ring(pts, nrm, 0.0, 0.003, jitter=jit(0.004))
    curl = ring(pts, nrm, -0.012, -0.016)
    b.strip("Char", outer, crest)
    b.strip("Char", crest, edge)
    b.strip("Char", edge, curl)
    for _ in range({"S": 4, "M": 6, "L": 8}[size]):
        i = rng.randrange(n)
        p = outer[i].lerp(crest[i], rng.uniform(0.2, 0.9))
        r = rng.uniform(0.008, 0.015)
        b.blob("Char", Vector((p.x, p.y, 0.003)), (r * 1.6, r, r * 0.22), rot=rng.uniform(0, 3.14))

    def seared(tissue, p, k):
        """The tissue at p, or the char / the eschar the beam left on it in
        patches (`k`: how much of it was burnt, 0..1)."""
        g = noise.noise(p * 9 + grain) + 0.25 * noise.noise(p * 23 + grain)
        if g < -1.1 + 2.2 * k:
            return "Char"
        if g < -0.8 + 2.2 * k:
            return "Eschar"
        return tissue

    def burnt(z):
        """How burnt the wall is at depth z: seared all over near the top,
        in patches below."""
        return 0.15 + 0.5 * max(0.0, 1 + z / 0.1)

    def classify(p):
        # (the layers' edges a little uneven)
        return chest.tissue(p + Vector((0, 0, 0.012 * noise.noise(p * 17 + grain))))

    # The wall: rows from the curl down to the bottom, narrowing a little
    # (the beam's cone). Each point gets its tissue (and its relief), then
    # what it looks like (the tissue, or seared); the faces are cut between
    # different looks (split).
    rows = max(8, round((depth - 0.016) / 0.015))
    zs = [-0.016 - (depth - 0.016) * r / rows for r in range(rows + 1)]
    grid, looks = [], []
    for r, z in enumerate(zs):
        t = 1 - 0.16 * (-z) / depth
        row, look_row = [], []
        for i in range(n):
            base = c + (curl[i] - c) * t
            base = Vector((base.x, base.y, z))
            if r == 0:
                row.append(curl[i].copy())
                look_row.append("Eschar")
                continue
            tissue = classify(base)
            out = Vector((base.x - c.x, base.y - c.y, 0))
            out = out.normalized() if out.length > 1e-6 else Vector()
            relief = BORE_RELIEF.get(tissue, 0.0) + 0.004 * noise.noise(base * 40 + grain)
            if tissue == "HeartDark":
                relief += 0.012 * noise.noise(Vector((base.x * 30, base.y * 90, base.z * 30)) + grain)  # its ridges
            p = base + out * relief
            row.append(p)
            # (the cut skin, cooked: a band right under the crust)
            look_row.append("Eschar" if z > -0.03 else seared(tissue, p, burnt(z)))
        grid.append(row)
        looks.append(look_row)

    def piece(layer, points):
        bm = b.bm(layer)
        bm.faces.new([bm.verts.new(p) for p in points])

    def split(a, bb, cc, ka, kb, kc):
        """A triangle whose corners look different, cut between them along
        its edges' middles (the edges between tissues run smoothly, not in
        steps; the middles are shared with the next triangles: no cracks)."""
        if ka == kb == kc:
            piece(ka, (a, bb, cc))
            return
        if kb == kc:  # (the odd one first, the turning kept)
            pass
        elif ka == kc:
            a, bb, cc, ka, kb, kc = bb, cc, a, kb, kc, ka
        elif ka == kb:
            a, bb, cc, ka, kb, kc = cc, a, bb, kc, ka, kb
        else:  # three looks: a quad each round the middle
            g = (a + bb + cc) / 3
            mab, mbc, mca = (a + bb) / 2, (bb + cc) / 2, (cc + a) / 2
            piece(ka, (a, mab, g, mca))
            piece(kb, (bb, mbc, g, mab))
            piece(kc, (cc, mca, g, mbc))
            return
        mab, mca = (a + bb) / 2, (cc + a) / 2
        piece(ka, (a, mab, mca))
        piece(kb, (mab, bb, cc, mca))

    def quad(points, kinds):
        """Two triangles, split between looks (see split)."""
        a, bb, cc, d = points
        ka, kb, kc, kd = kinds
        split(a, bb, cc, ka, kb, kc)
        split(a, cc, d, ka, kc, kd)

    for r in range(rows):
        for i in range(n):
            j = (i + 1) % n
            # (this order faces the hole's middle)
            quad((grid[r][i], grid[r][j], grid[r + 1][j], grid[r + 1][i]),
                 (looks[r][i], looks[r][j], looks[r + 1][j], looks[r + 1][i]))

    # The bottom: a bowl where the beam stopped, rings from the wall's last
    # row to the middle. In the heart's chamber it is the chamber's far wall
    # (the septum, the papillary muscles), deeper. The beam's last spot (the
    # middle) is burnt black, then brown round it; the chamber's far wall
    # less (the beam just reached it).
    def floor_look(tissue, p, s, i):
        # (by ring, wavy round the middle: its edges follow the rings)
        a = 2 * math.pi * i / n
        rr = 0.88 * s + 0.12 * noise.noise(Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, 0)) + grain)
        if p.z < -depth - 0.03:
            rr *= 1.6
        if rr < 0.22:
            return "Char"
        if rr < 0.4:
            return "Eschar"
        return seared(tissue, p, 0.2)

    bottom = grid[-1]
    rings = 8
    floor_pts, floor_looks = [bottom], [looks[-1]]
    for k in range(1, rings + 2):
        s = 1 - k / (rings + 1) if k <= rings else 0.0
        row, look_row = [], []
        for i in range(n if k <= rings else 1):
            q = c + (bottom[i] - c) * s
            z = -depth * (1 + 0.05 * (1 - s * s)) + 0.004 * noise.noise(q * 30 + grain)
            p = Vector((q.x, q.y, z))
            tissue = classify(p)
            if tissue == "HeartDark":
                far = chest.floor(p)
                if far is not None:
                    # (its ridges of muscle: the trabeculae)
                    ridges = 0.014 * noise.noise(Vector((q.x * 25, q.y * 80, 0)) + grain)
                    p = Vector((q.x, q.y, -far[0] + ridges))
                    tissue = far[1]
                else:
                    p = Vector((q.x, q.y, z - 0.15))
            else:
                p.z -= BORE_RELIEF.get(tissue, 0.0) * 0.6
            row.append(p)
            look_row.append(floor_look(tissue, p, s, i))
        floor_pts.append(row)
        floor_looks.append(look_row)
    for k in range(rings):
        for i in range(n):
            j = (i + 1) % n
            # (this order faces out of the skin)
            quad((floor_pts[k][i], floor_pts[k][j], floor_pts[k + 1][j], floor_pts[k + 1][i]),
                 (floor_looks[k][i], floor_looks[k][j], floor_looks[k + 1][j], floor_looks[k + 1][i]))
    middle, middle_look = floor_pts[-1][0], floor_looks[-1][0]
    for i in range(n):
        j = (i + 1) % n
        split(floor_pts[rings][i], floor_pts[rings][j], middle,
              floor_looks[rings][i], floor_looks[rings][j], middle_look)

    meshes, reach = bend_and_measure(b, False)
    for bm in meshes.values():
        bm.normal_update()
    lowest = min(vert.co.z for bm in meshes.values() for vert in bm.verts)
    return pts, meshes, reach, -lowest


# --- The open fractures ("Break": heavy hits, Client/Combat/HeavyGore) -------
# A huge blow at the end of a big combo snaps the forearm / the shin: the
# real bones (Z-Anatomy, limbs.npz) broken obliquely, jagged, each broken
# end a thick solid cortex round the sunk dark marrow; one fragment
# angulated so that a short length of it, its broken end facing out, has
# gone out through the front of the limb, through a torn hole in the skin
# (the forearm: the radius' upper fragment, pointing down; the shin: the
# tibia's lower fragment, pointing up - seen end on from above); in the hole
# the real muscles torn, the fat, torn vessels and nerves, clotted blood,
# splinters of bone. One insert per limb (the left ones
# mirrored), body only, size "L", at fracture.BREAK_AT. Last in the kit (the
# others' numbers don't move).
#   hole      its length (along the limb) and width on the skin
#   depth     how deep the torn hole goes
#   bones     each bone (limbs.npz order): where it breaks (insert Y), the
#             fracture's slope, the cortex (share of its half width), `thin`
#             (its width scaled: the blocky limb's bones were widened); its
#             upper fragment's broken end: how far out of the skin (studs;
#             < 0: still in the hole), how high, the shaft's tilt; the
#             lower fragment's the same (None: it stays as it is)
BREAK_VARIANTS = {
    "BreakArm": dict(limb="arm", length=0.62, width=0.4, depth=0.44, lip=0.06, rag=1.5,
                     bones=(dict(y=0.0, slope=0.5, cortex=0.36, out=0.22, tip=-0.2, tilt=math.radians(64),
                                 low=-0.3, tip_low=-0.02, tilt_low=math.radians(14)),
                            dict(y=0.07, slope=0.6, cortex=0.38, out=-0.1, tip=-0.12, tilt=math.radians(30),
                                 low=-0.36, tip_low=0.0, tilt_low=math.radians(10)))),
    "BreakLeg": dict(limb="leg", length=0.52, width=0.42, depth=0.3, lip=0.06, rag=1.5,
                     bones=(dict(y=0.0, slope=0.35, cortex=0.34, thin=0.78, out=-0.12, tip=0.1,
                                 tilt=math.radians(10), low=0.3, tip_low=0.02, tilt_low=math.radians(66)),
                            dict(y=0.16, slope=0.8, cortex=0.36, out=None, low=None))),
}
BREAK_LOOK_LAYERS = ("Lip", "Dermis", "Fat", "Flesh", "FleshDark", "Muscle", "MuscleDark", "Bone", "Marrow",
                     "Blood", "Artery", "Vein", "Nerve")


class LimbTissue:
    """What is where inside the forearm / the shin (insert axes): the real
    muscles (each its own, Muscle or MuscleDark in turn), with the skin and
    its fat over them. The bones are left out (they are drawn for real,
    broken): where they were, clotted blood (FleshDark)."""

    def __init__(self, parts):
        self.trees = []
        for index, bm in enumerate(parts["muscle"]):
            self.trees.append(("Muscle" if index % 2 == 0 else "MuscleDark", BVHTree.FromBMesh(bm)))
        for bm in parts["bone"]:
            self.trees.append(("FleshDark", BVHTree.FromBMesh(bm)))
        self.cache = {}

    def spans(self, x, y):
        """[(tissue, depth in, depth out)] along the column at (x, y), from
        the skin in (depth = -Z)."""
        d = Vector((0, 0, -1))
        found = []
        for rank, (tissue, tree) in enumerate(self.trees):
            o = Vector((x, y, 0.2))
            start = None
            for _ in range(32):
                hit = tree.ray_cast(o, d, 2.0)
                if hit[0] is None:
                    break
                if hit[1].dot(d) < 0:
                    start = -hit[0].z
                elif start is not None:
                    found.append((start, -hit[0].z, rank, tissue))
                    start = None
                o = hit[0] + d * 1e-4
        found.sort()
        return found

    def column(self, x, y):
        """[(layer, the depth it ends at)] from the skin down."""
        key = (round(x / 0.004), round(y / 0.004))
        if key in self.cache:
            return self.cache[key]
        spans = self.spans(x, y)
        first = spans[0][0] if spans else 0.2
        fat_end = min(0.075, max(0.035, first - 0.004))
        layers = [("Dermis", 0.014), ("Fat", fat_end)]
        depth = fat_end
        if first > depth + 0.01:
            layers.append(("Flesh", first))  # (loose tissue, soaked: red)
            depth = first
        for start, end, _rank, tissue in spans:
            if end <= depth:
                continue
            if start > depth + 0.008:
                layers.append(("FleshDark", start))  # (between the muscles)
            layers.append((tissue, end))
            depth = end
        layers.append(("FleshDark", 9.0))
        self.cache[key] = layers
        return layers

    def tissue(self, p):
        d = -p.z
        for layer, end in self.column(p.x, p.y):
            if d <= end:
                return layer
        return "FleshDark"


# Each tissue stands out of the hole's wall or sinks back (studs, + = back
# into the wall): torn muscle bulges, the fat swells in lobules, the clots
# lie back.
BREAK_RELIEF = {"Muscle": -0.012, "MuscleDark": -0.008, "Fat": -0.004, "Dermis": 0.0, "Flesh": 0.004,
                "FleshDark": 0.012}


def place_fragment(rng, bm, extra, tilt, tip, upper):
    """Moves a bone's fragment (and what goes with it: `extra`): its shaft
    tilted `tilt` radians off the limb's axis, its broken end toward the
    front (out of the skin), turned a little about itself; then moved so
    that its broken end's point (the farthest out) is at `tip`."""
    centre = sum((v.co for v in bm.verts), Vector()) / max(1, len(bm.verts))
    twist = Matrix.Rotation(rng.uniform(-0.5, 0.5), 4, "Y")
    turn = Matrix.Rotation(-tilt if upper else tilt, 4, "X") @ Matrix.Rotation(rng.uniform(-0.12, 0.12), 4, "Z")
    m = Matrix.Translation(centre) @ turn @ twist @ Matrix.Translation(-centre)
    for item in [bm] + extra:
        bmesh.ops.transform(item, matrix=m, verts=item.verts)
    point = max((v.co for v in bm.verts), key=lambda co: co.z).copy()
    shift = Vector(tip) - point
    for item in [bm] + extra:
        bmesh.ops.translate(item, vec=shift, verts=item.verts)
        item.normal_update()


def build_break(name, v, seed):
    """An open fracture (see BREAK_VARIANTS): a closed cup in the limb's
    front face, the broken real bones through it. (outline, meshes, reach,
    depth)"""
    rng = random.Random(seed)
    noise.seed_set(seed % 100000)
    grain = Vector((rng.uniform(0, 50), rng.uniform(0, 50), rng.uniform(0, 50)))
    limb = v["limb"]
    parts = fracture.load(limb)
    tissue = LimbTissue(parts)
    # the torn hole: long along the limb (outline makes it along X: turned)
    flat = dict(length=v["length"], width=v["width"], rag=v["rag"])
    pts = [Vector((-p.y, p.x, 0)) for p in outline("Lac", flat, rng)]
    hole = [Vector((-p.y, p.x, 0)) for p in outline("Lac", flat, random.Random(seed), with_tears=False)]
    n = len(pts)
    nrm = normals2d(pts)
    c = centroid(pts)
    b = Builder(c)
    depth, lip = v["depth"], v["lip"]
    wobble = [rng.uniform(-1, 1) for _ in range(n + 16)]

    def jit(scale):
        return lambda i: wobble[i % len(wobble)] * scale

    # ---- the skin's torn edge: raised, swollen, rolling into the hole
    outer = ring(pts, nrm, lip, 0.002)
    crest = ring(pts, nrm, lip * 0.45, lambda i: 0.012 * (1 + 0.6 * wobble[i]))
    edge = ring(pts, nrm, 0.0, 0.006)
    curl = ring(pts, nrm, -0.012, -0.012, jitter=jit(0.004))
    b.strip("Lip", outer, crest)
    b.strip("Lip", crest, edge)
    b.strip("Lip", edge, curl)

    # ---- the hole's wall and floor: what is really there at each point
    def piece(layer, points):
        bm = b.bm(layer)
        bm.faces.new([bm.verts.new(p) for p in points])

    def split(a, bb, cc, ka, kb, kc):
        if ka == kb == kc:
            piece(ka, (a, bb, cc))
            return
        if kb == kc:
            pass
        elif ka == kc:
            a, bb, cc, ka, kb, kc = bb, cc, a, kb, kc, ka
        elif ka == kb:
            a, bb, cc, ka, kb, kc = cc, a, bb, kc, ka, kb
        else:
            g = (a + bb + cc) / 3
            mab, mbc, mca = (a + bb) / 2, (bb + cc) / 2, (cc + a) / 2
            piece(ka, (a, mab, g, mca))
            piece(kb, (bb, mbc, g, mab))
            piece(kc, (cc, mca, g, mbc))
            return
        mab, mca = (a + bb) / 2, (cc + a) / 2
        piece(ka, (a, mab, mca))
        piece(kb, (mab, bb, cc, mca))

    def quad(points, kinds):
        a, bb, cc, d = points
        ka, kb, kc, kd = kinds
        split(a, bb, cc, ka, kb, kc)
        split(a, cc, d, ka, kc, kd)

    def classify(p):
        return tissue.tissue(p + Vector((0, 0, 0.01 * noise.noise(p * 19 + grain))))

    rows = max(10, round((depth - 0.012) / 0.014))
    zs = [-0.012 - (depth - 0.012) * r / rows for r in range(rows + 1)]
    grid, looks = [], []
    for r, z in enumerate(zs):
        # (a torn hole: wider under the skin than at it in places, ragged)
        t = 1 - 0.3 * (-z) / depth
        row, look_row = [], []
        for i in range(n):
            if r == 0:
                row.append(curl[i].copy())
                look_row.append("Dermis")
                continue
            base = c + (curl[i] - c) * t
            base = Vector((base.x, base.y, z))
            layer = classify(base)
            out = Vector((base.x - c.x, base.y - c.y, 0))
            out = out.normalized() if out.length > 1e-6 else Vector()
            relief = BREAK_RELIEF.get(layer, 0.0)
            relief += 0.012 * noise.noise(base * 24 + grain) + 0.003 * noise.noise(base * 60 + grain)
            if layer in ("Muscle", "MuscleDark"):
                # torn fibres: ridges along the limb
                relief += 0.006 * noise.noise(Vector((base.x * 70, base.y * 12, base.z * 70)) + grain)
            row.append(base + out * relief)
            look_row.append(layer)
        grid.append(row)
        looks.append(look_row)
    for r in range(rows):
        for i in range(n):
            j = (i + 1) % n
            quad((grid[r][i], grid[r][j], grid[r + 1][j], grid[r + 1][i]),
                 (looks[r][i], looks[r][j], looks[r + 1][j], looks[r + 1][i]))
    # the floor: torn tissue, lumpy, down to the middle
    bottom = grid[-1]
    rings = 6
    floor_pts, floor_looks = [bottom], [looks[-1]]
    for k in range(1, rings + 2):
        s = 1 - k / (rings + 1) if k <= rings else 0.0
        row, look_row = [], []
        for i in range(n if k <= rings else 1):
            q = c + (bottom[i] - c) * s
            z = -depth * (1 + 0.08 * (1 - s * s)) + 0.02 * noise.noise(q * 14 + grain)
            p = Vector((q.x, q.y, z))
            layer = classify(p)
            p.z -= BREAK_RELIEF.get(layer, 0.0) * 0.8
            row.append(p)
            look_row.append(layer)
        floor_pts.append(row)
        floor_looks.append(look_row)
    for k in range(rings):
        for i in range(n):
            j = (i + 1) % n
            quad((floor_pts[k][i], floor_pts[k][j], floor_pts[k + 1][j], floor_pts[k + 1][i]),
                 (floor_looks[k][i], floor_looks[k][j], floor_looks[k + 1][j], floor_looks[k + 1][i]))
    middle, middle_look = floor_pts[-1][0], floor_looks[-1][0]
    for i in range(n):
        j = (i + 1) % n
        split(floor_pts[rings][i], floor_pts[rings][j], middle, floor_looks[rings][i], floor_looks[rings][j],
              middle_look)
    # (the walls face the hole's middle; the floor faces out)
    for layer, bm in b.parts.items():
        if layer in BREAK_LOOK_LAYERS:
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    cup_lowest = min(vert.co.z for bm in b.parts.values() for vert in bm.verts)

    # fat lobules in the fat under the skin
    for _ in range(18):
        i = rng.randrange(n)
        p = grid[min(2, rows)][i].lerp(grid[min(4, rows)][i], rng.uniform(0, 1))
        if classify(p) != "Fat":
            continue
        inward = Vector((c.x - p.x, c.y - p.y, 0))
        inward = inward.normalized() if inward.length > 1e-6 else Vector()
        r = rng.uniform(0.008, 0.016)
        b.blob("Fat", p + inward * r * 0.3, (r, r * rng.uniform(0.7, 1.1), r * 0.8))

    # ---- the bones, broken
    x0, _y0 = fracture.BREAK_AT[limb]
    # (only round the hole: the rest of them is hidden inside the limb)
    keep_planes = [
        ((min(x0 + 0.47, c.x + v["width"] * 0.8), 0, 0), (1, 0, 0)),
        ((max(x0 - 0.47, c.x - v["width"] * 0.8), 0, 0), (-1, 0, 0)),
        ((0, 0, -0.97), (0, 0, -1)),  # (the limb's back)
        ((0, c.y + v["length"] * 0.8, 0), (0, 1, 0)), ((0, c.y - v["length"] * 0.85, 0), (0, -1, 0)),
    ]
    bones, marrow, chips, film, shreds = [], [], [], [], []
    for bone, spec in zip(parts["bone"], v["bones"]):
        bone = fracture.solid(bone)
        if spec.get("thin"):
            # (the blocky limb's bones were widened to fill it: the one that
            # comes out a little less, or it fills the whole hole)
            middle = fracture.section(bone, spec["y"], 0.04)[0]
            for vert in bone.verts:
                vert.co.x = middle.x + (vert.co.x - middle.x) * spec["thin"]
                vert.co.z = middle.z + (vert.co.z - middle.z) * spec["thin"]
            bone.normal_update()
        toward = Vector((rng.uniform(-0.3, 0.3), 0, 1))  # (the fracture rises toward the front)
        upper, upper_m, lower, lower_m, fr = fracture.break_bone(
            bone, rng, spec["y"], spec["slope"], toward, spec["cortex"], fr_sink(spec), 0.012)
        centre = fr.centre
        with_upper, with_lower = [upper_m], [lower_m]
        # the fragment whose broken end came out of the skin (if one did)
        out_upper = spec["out"] is not None and spec["out"] > 0
        out_lower = spec["low"] is not None and spec["low"] > 0
        # a shred of real muscle torn off with it, stuck near its end
        if out_upper or out_lower:
            # (down its shaft, by the skin: its broken end left clear)
            reach = fr.radius * (2.5 if out_upper else -4.5)
            near = Vector((centre.x, spec["y"] + reach, centre.z + fr.radius))
            for m in sorted(parts["muscle"], key=lambda mb: min((vv.co - near).length for vv in mb.verts))[:2]:
                ball = bmesh.new()
                bmesh.ops.create_icosphere(ball, subdivisions=2, radius=rng.uniform(0.06, 0.085))
                along = rng.uniform(0, 0.1) * (1 if out_upper else -1)
                bmesh.ops.translate(ball, vec=near + Vector((rng.uniform(-0.03, 0.03), along, 0)), verts=ball.verts)
                gore.lumpy(ball, rng, 0.02, 40.0)
                chunk, _cut = fracture.boolean(m.copy(), ball)
                ball.free()
                if len(chunk.faces):
                    gore.lumpy(chunk, rng, 0.006, 60.0)
                    shreds.append(chunk)
                    (with_upper if out_upper else with_lower).append(chunk)
        # (the one that comes out: through the middle of the hole)
        x = min(c.x + v["width"] * 0.22, max(c.x - v["width"] * 0.22, centre.x))
        if spec["out"] is not None:
            at = c.x if out_upper else x
            place_fragment(rng, upper, with_upper, spec["tilt"], (at, spec["tip"], spec["out"]), True)
        if spec["low"] is not None:
            at = c.x if out_lower else x
            place_fragment(rng, lower, with_lower, spec["tilt_low"], (at, spec["tip_low"], spec["low"]), False)
        for bm in [upper, upper_m, lower, lower_m]:
            gore.cut(bm, keep_planes, fill=bm in (upper, lower))
        if out_upper or out_lower:
            # blood on the end that came out: a collar where it left the
            # skin (the rest of it clean ivory: it reads as bone)
            piece = upper if out_upper else lower
            film.append(fracture.blood_film(piece, rng, lambda p: -0.04 < p.z < 0.016, 0.004, -0.6))
            # splinters of its wall in the hole
            for _ in range(3):
                shard = fracture.splinter(bone, rng, Vector((centre.x, spec["y"] + rng.uniform(-0.05, 0.05),
                                                             centre.z)), fr.radius * rng.uniform(0.3, 0.45))
                if len(shard.faces):
                    sc = sum((vv.co for vv in shard.verts), Vector()) / len(shard.verts)
                    a = rng.uniform(0, 2 * math.pi)
                    to = Vector((c.x + math.cos(a) * v["width"] * 0.28, c.y + math.sin(a) * v["length"] * 0.28,
                                 -depth * rng.uniform(0.5, 0.85)))
                    m = (Matrix.Translation(to) @ Matrix.Rotation(rng.uniform(0, 6.3), 4, "Y")
                         @ Matrix.Rotation(rng.uniform(0, 6.3), 4, "X") @ Matrix.Translation(-sc))
                    bmesh.ops.transform(shard, matrix=m, verts=shard.verts)
                    chips.append(shard)
        bone.free()
        bones += [upper, lower]
        marrow += [upper_m, lower_m]
    # (nothing of the bones may come out of the skin anywhere but the hole)
    for bm in bones:
        for vert in bm.verts:
            if -0.004 < vert.co.z < 0.015 and not fracture.polygon_contains(hole, vert.co.x, vert.co.y):
                print(f"[break] {name}: bone out of the skin at {tuple(round(x, 3) for x in vert.co)}")
                break

    # ---- the vessels and nerves: torn across the hole, an end hanging out
    for index, vessel in enumerate(parts["vessel"]):
        y_tear = c.y + rng.uniform(-0.25, 0.25) * v["length"]
        keep_up = rng.random() < 0.5
        gore.cut(vessel, [((0, y_tear, 0), (0, -1 if keep_up else 1, 0)),
                          ((0, c.y + v["length"] * 0.55, 0), (0, 1, 0)), ((0, c.y - v["length"] * 0.55, 0), (0, -1, 0)),
                          ((c.x + v["width"] * 0.6, 0, 0), (1, 0, 0)), ((c.x - v["width"] * 0.6, 0, 0), (-1, 0, 0)),
                          ((0, 0, -0.03), (0, 0, 1))], fill=True)
        if not len(vessel.faces):
            continue
        gore.tear(vessel, rng, y_tear, 0.02)
        # (out of the wall into the hole: drooping toward the floor)
        for vert in vessel.verts:
            reach = max(0.0, 0.15 - abs(vert.co.y - y_tear)) / 0.15
            vert.co.z += 0.03 * reach
        names = ("Artery", "Artery", "Nerve", "Nerve", "Vein", "Vein") if limb == "arm" else \
            ("Artery", "Artery", "Nerve", "Vein", "Nerve")
        b.parts.setdefault(names[index % len(names)], bmesh.new())
        mesh = bpy.data.meshes.new("tmp")
        vessel.to_mesh(mesh)
        b.parts[names[index % len(names)]].from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        vessel.free()
    for bm in parts["muscle"]:
        bm.free()

    def add(layer, items):
        b.parts.setdefault(layer, bmesh.new())
        for bm in items:
            mesh = bpy.data.meshes.new("tmp")
            bm.to_mesh(mesh)
            b.parts[layer].from_mesh(mesh)
            bpy.data.meshes.remove(mesh)
            bm.free()

    add("Bone", [gore.decimate(gore.bm_join_all(bones), 5200)] + chips)
    for bm in bones:
        bm.free()
    add("Marrow", marrow)
    add("Muscle", shreds)

    # ---- blood: pooled low in the hole, a clot, running down the skin
    pool = []
    for i in range(n):
        p = floor_pts[1][i]
        q = Vector((p.x, min(p.y, c.y - v["length"] * 0.05), 0))
        pool.append(Vector((q.x, q.y, -depth * 0.9)))
    b.fan("Blood", pool, Vector((c.x, c.y - v["length"] * 0.18, -depth * 0.88)))
    lowest = sorted(range(n), key=lambda i: outer[i].y)[: n // 4]
    for k in range(6):
        i = rng.choice(lowest)
        start = outer[i]
        length = rng.uniform(0.16, 0.36) if k < 3 else rng.uniform(0.04, 0.12)
        w = rng.uniform(0.007, 0.014)
        steps = 12
        phase = rng.uniform(0, 6.3)
        bm = b.bm("Blood")
        prev = None
        x = start.x
        y = start.y
        for s in range(steps + 1):
            f = s / steps
            y = start.y + 0.015 - length * f
            x = start.x + 0.008 * math.sin(phase + f * 5)
            ww = w * (1 - 0.35 * f + 0.25 * math.sin(phase * 2 + f * 9))
            l_ = bm.verts.new((x - ww, y, 0.003))
            m_ = bm.verts.new((x, y, 0.003 + ww * 0.25))
            r_ = bm.verts.new((x + ww, y, 0.003))
            if prev:
                pl, pm, pr = prev
                b.face_up(bm, (pl, l_, m_, pm))
                b.face_up(bm, (pm, m_, r_, pr))
            prev = (l_, m_, r_)
        b.blob("Blood", Vector((x, y - 0.004, 0.0035)), (w * 1.1, w * 1.4, w * 0.35))
    add("Blood", film)

    meshes, reach = bend_and_measure(b, False)
    for bm in meshes.values():
        bm.normal_update()
    return hole, meshes, reach, -cup_lowest


def fr_sink(spec):
    """How deep the marrow cavity shows at a broken end (studs)."""
    return 0.03 + 0.05 * spec["cortex"]


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
    # The Sentinel's bore over the heart (torso only), after the burns.
    chest = Chest()
    for (kind, size), v in BORE_VARIANTS.items():
        name = f"{kind}{size}"
        seed = sum(map(ord, name)) * 7919
        pts, meshes, reach, deep = build_bore(size, v, seed, chest)
        offset = Vector((index * SPACING, 0, 0))
        for layer, bm in meshes.items():
            objects.append(add_object(f"{name}_{layer}", bm, offset, layer))
        shapes.append((name, index, kind, size, False, dict(v, reach_depth=deep), pts, reach))
        index += 1
    bore_seed = seed
    # The open fractures (heavy hits), after the bores: the right limbs'
    # inserts, then the left ones (the same, mirrored: X -> -X).
    for name, v in BREAK_VARIANTS.items():
        seed = sum(map(ord, name)) * 7919
        pts, meshes, reach, deep = build_break(name, v, seed)
        for side in ("", "L"):
            if side:
                pts = [Vector((-p.x, p.y, 0)) for p in reversed(pts)]
                meshes = gore.mirrored(meshes)
            offset = Vector((index * SPACING, 0, 0))
            for layer, bm in (meshes.items() if side else list((k, b.copy()) for k, b in meshes.items())):
                objects.append(add_object(f"{name}{side}_{layer}", bm, offset, layer))
            shapes.append((name + side, index, "Break", "L", False, dict(v, reach_depth=deep), pts, reach))
            index += 1
    # (the noise as the bores left it: what is built after keeps its shapes)
    noise.seed_set(bore_seed % 100000)
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
        "\tdepth: number?, -- how deep it goes under the skin, when it is deep (Bore: a closed cup)",
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
        if "reach_depth" in v:
            lines.append(f"\t\t\tdepth = {lua_number(v['reach_depth'])},")
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
        render_gore_preview(gore_slots)
        render_break_preview(shapes)


def render_preview(shapes):
    """Each insert in a skin plate with its hole, lit, seen from the front."""
    scene = bpy.context.scene
    for idx, (name, i, kind, size, head, v, pts, _reach) in enumerate(shapes):
        if kind == "Break":
            continue  # (render_break_preview: in the whole limb)
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
    # (a deep hole: a light from the camera too, or its inside is all shadow)
    fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "SUN"))
    fill.data.energy = 1.2
    fill.rotation_euler = (math.radians(15), 0, 0)
    scene.collection.objects.link(fill)
    shown = scene.view_settings.view_transform
    for name, i, kind, *_ in shapes:  # noqa: B007
        if kind == "Break":
            continue
        fill.hide_render = kind != "Bore"
        # (and its colours as they are: the char black, not washed out)
        scene.view_settings.view_transform = "Standard" if kind == "Bore" else shown
        scene.view_settings.exposure = -1.3 if kind == "Bore" else 0.0
        cam.location = (i * SPACING, -0.55, 2.0)  # a little below, looking up at the cut
        cam.rotation_euler = (math.radians(15), 0, 0)
        cam.data.ortho_scale = 0.85
        scene.render.filepath = f"{OUT}/preview_{name}.png"
        bpy.ops.render.render(write_still=True)


# The new gore pieces' pictures (preview_<Piece>.png): (where the camera
# is from the point it looks at, that point, the view's width), from the
# piece's slot. Waist / Hips with a plain torso / legs round them.
GORE_VIEWS = {
    "Waist": (Vector((1.6, -2.0, -2.6)), Vector((0, -1.1, 0)), 2.6),
    "Hips": (Vector((1.4, 2.2, -2.6)), Vector((0, -1.0, 0)), 2.6),
    "GutPile": (Vector((0.9, 1.3, -1.6)), Vector((0, 0.12, 0)), 1.3),
    "Gut1": (Vector((0.6, 0.6, -1.6)), Vector((0, 0, 0)), 0.8),
    # the heavy hits ("<piece>@<view>": another view of the same piece)
    "LegEnd": (Vector((1.4, 2.2, -2.4)), Vector((0, 0.7, 0)), 1.9),
    "Hip": (Vector((1.8, -1.4, -2.6)), Vector((0.4, -1.1, 0)), 2.4),
    "ArmEndR": (Vector((1.4, 2.2, -2.4)), Vector((0, 0.7, 0)), 1.9),
    "ShoulderR": (Vector((2.8, 0.5, -1.4)), Vector((1.0, 0.4, 0)), 2.0),
    "ShoulderL": (Vector((-2.8, 0.5, -1.4)), Vector((-1.0, 0.4, 0)), 2.0),
}
# (what is drawn round them: (where, size, the face left open) boxes, or
# "head": the round head)
GORE_CONTEXT = {
    "Waist": [((0, 0, 0), (2, 2, 1), "bottom")],
    "Hips": [((-0.5, -2, 0), (1, 2, 1), "top"), ((0.5, -2, 0), (1, 2, 1), "top")],
    "LegEnd": [((0, 0, 0), (1, 2, 1), "top")],
    "ArmEndR": [((0, 0, 0), (1, 2, 1), "top")],
    "Hip": [((0, 0, 0), (2, 2, 1), None), ((-0.5, -2, 0), (1, 2, 1), None)],
    "ShoulderR": [((0, 0, 0), (2, 2, 1), None)],
    "ShoulderL": [((0, 0, 0), (2, 2, 1), None)],
}


# The open fractures' pictures (preview_<Insert>_<view>.png): the insert in
# the whole limb (its skin with the hole, the block round it), from the
# front and a little to the side, from below, and from above (as a third
# person camera sees it).
BREAK_VIEWS = {
    "q": (Vector((1.3, -0.4, 1.6)), Vector((0, -0.15, 0)), 1.5),
    "low": (Vector((0.5, -1.0, 1.6)), Vector((0, -0.05, 0)), 0.9),
    "top": (Vector((0.3, 2.0, 1.4)), Vector((0, -0.05, 0)), 1.0),
}


def render_break_preview(shapes):
    """Pictures of the open fractures' inserts (after render_preview)."""
    scene = bpy.context.scene
    cam = scene.camera
    fill = scene.objects.get("fill")
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = -1.0
    for name, i, kind, _size, _head, v, pts, _reach in shapes:
        if kind != "Break" or name.endswith("L"):
            continue
        origin = Vector((i * SPACING, 0, 0))
        x0, y0 = fracture.BREAK_AT[v["limb"]]
        # (insert axes: the limb's X is -X, its front face at Z = 0)
        skin = bmesh.new()
        cell = 0.02
        for gx in range(50):
            for gy in range(100):
                x = x0 - 0.5 + (gx + 0.5) * cell
                y = -1 - y0 + (gy + 0.5) * cell
                if fracture.polygon_contains(pts, x, y):
                    continue
                skin.faces.new([skin.verts.new((x + dx * cell / 2, y + dy * cell / 2, 0))
                                for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
        block = bmesh.new()
        bmesh.ops.create_cube(block, size=1.0)
        for vert in block.verts:
            vert.co = Vector((x0 + vert.co.x * 0.999, -y0 + vert.co.y * 1.998, -0.5 + vert.co.z * 0.999))
        bmesh.ops.delete(block, geom=[f for f in block.faces if f.normal.z > 0.9], context="FACES")
        context = [add_object(f"ctx_{name}", skin, origin, "Skin"), add_object(f"ctx2_{name}", block, origin, "Skin")]
        for view, (eye, target, width) in BREAK_VIEWS.items():
            at = origin + target
            cam.location = at + eye
            back = eye.normalized()
            right = Vector((0, 1, 0)).cross(back).normalized()
            cam.rotation_euler = Matrix((right, back.cross(right), back)).transposed().to_euler()
            cam.data.ortho_scale = width
            if fill:
                fill.hide_render = False
                fill.rotation_euler = cam.rotation_euler
            scene.render.filepath = f"{OUT}/preview_{name}_{view}.png"
            bpy.ops.render.render(write_still=True)
        for ob in context:
            mesh = ob.data
            bpy.data.objects.remove(ob)
            bpy.data.meshes.remove(mesh)


def render_gore_preview(slots):
    """Pictures of the new gore pieces (after render_preview: its lights)."""
    scene = bpy.context.scene
    cam = scene.camera
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = -1.0
    for name, (eye, target, width) in GORE_VIEWS.items():
        piece = name.split("@")[0]
        if piece not in slots:
            continue
        slot = slots[piece]
        boxes = GORE_CONTEXT.get(piece, [])
        context = []
        if boxes == "head":
            context.append(add_object(f"ctx_{name}", gore.head_surface(), slot, "Skin"))
            boxes = []
        for at, size, opened in boxes:
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            bmesh.ops.scale(bm, vec=size, verts=bm.verts)
            gone = [f for f in bm.faces if opened and (f.normal.y < -0.9 if opened == "bottom" else f.normal.y > 0.9)]
            bmesh.ops.delete(bm, geom=gone, context="FACES")
            context.append(add_object(f"ctx_{name}", bm, slot + Vector(at), "Skin"))
        at = slot + target
        cam.location = at + eye
        # (looking at it, the kit's up (+Y) up in the picture)
        back = eye.normalized()
        right = Vector((0, 1, 0)).cross(back).normalized()
        cam.rotation_euler = Matrix((right, back.cross(right), back)).transposed().to_euler()
        cam.data.ortho_scale = width
        fill = scene.objects.get("fill")
        if fill:  # (lit from the camera too)
            fill.hide_render = False
            fill.rotation_euler = cam.rotation_euler
        scene.render.filepath = f"{OUT}/preview_{name.replace('@', '_')}.png"
        bpy.ops.render.render(write_still=True)
        for ob in context:
            mesh = ob.data
            bpy.data.objects.remove(ob)
            bpy.data.meshes.remove(mesh)


if __name__ == "__main__":
    main()
