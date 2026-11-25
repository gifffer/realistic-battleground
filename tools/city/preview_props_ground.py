"""Renders the ground-prop catalogue of props_ground.py (every prop, several variants), group by
group, from a few day cameras and one night view lit by a bulb, to LOOK at them.

    venv/bin/python -I tools/city/preview_props_ground.py OUT_DIR [group ...] [--fast] [--check] [--night]
    venv/bin/python -I tools/city/preview_props_ground.py --close OUT_DIR prop [prop ...]   (eye-level close-ups)

Groups: litter, bags, wood, masonry, objects, floor, covers, edges. Writes OUT_DIR/<group>_day_<i>.png (and
OUT_DIR/<group>_night_0.png with --night). Renders are small (640 x 420, denoised, few samples: the machine is
shared). Also checks every prop over many seeds: its part counts, no bottle anywhere, and no two of its own
parts with same-facing faces on one plane (the z-fighting check: --check runs only the checks, no render).
"""

import copy
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import citykit  # noqa: E402
import numpy as np  # noqa: E402
import props_ground as pg  # noqa: E402

GROUPS = {
    "litter": ["paper_ball", "paper_sheet", "wrapper", "cigarette_butts", "litter_scatter"],
    "bags": ["trash_bag", "cardboard_box", "cardboard_flat", "trash_heap"],
    "wood": ["wood_scraps", "plank_stack", "pallet", "pallet_stack"],
    "masonry": ["rebar", "concrete_chunk", "loose_bricks", "cinder_block", "rubble_pile"],
    "objects": ["bucket", "milk_crate", "cement_bag", "tyre"],
    "floor": ["oil_stain", "damp_stain", "crack", "pothole", "asphalt_patch", "puddle"],
    "covers": ["paint_marks", "manhole", "drain_grate", "weeds"],
    "edges": ["leaves_drift", "wall_base_grime", "weeds"],
}
CELL = {"litter_scatter": 6, "trash_heap": 8, "pallet_stack": 6, "plank_stack": 8, "rubble_pile": 8,
        "pallet": 6, "leaves_drift": 6, "wall_base_grime": 9, "weeds": 7,
        "crack": 7, "asphalt_patch": 6, "damp_stain": 6, "trash_bag": 4.5, "cardboard_flat": 5, "tyre": 4,
        "drain_grate": 7, "manhole": 4.5, "pothole": 4.5, "paint_marks": 4}
SMALL_ONES = {"paper_ball", "paper_sheet", "wrapper", "cigarette_butts"}
# props built against a wall (on their +Z): the preview gives each row its own wall behind it
WALL_PROPS = {"leaves_drift", "wall_base_grime", "weeds"}

BY_NAME = {fn.__name__: (fn, variants) for fn, variants in pg.CATALOGUE}
# Where the catalogue is built: far from the city, whose parts the props look up (zlayers.host_at:
# decals keep out of raised things, wall-foot props find the wall) and would bump into at 0, 0.
X0, Z0 = 20000.0, 20000.0


def _faces(r):
    """[(normal, centre, half extents along the face's two axes, axes)] of a block row's 6 faces
    (wedges / cylinders: their flat faces that matter here, as blocks: a slightly wider net)."""
    R = citykit.yxz_matrix(r[4], r[5], r[6])
    h = np.array(r[7:10], float) / 2
    c = np.array(r[1:4], float)
    out = []
    for i in range(3):
        if r[0] == citykit.CYLINDER and i != 0:
            continue
        if r[0] == citykit.BALL:
            continue
        a, b = (i + 1) % 3, (i + 2) % 3
        for s in (-1, 1):
            out.append((s * R[:, i], c + s * h[i] * R[:, i], (h[a], h[b]), (R[:, a], R[:, b])))
    return out


def _inside(rows, p, skip):
    """Whether point p is inside an opaque block / cylinder row (other than those in skip)."""
    for k, r in enumerate(rows):
        if k in skip or r[12] > 0.05 or r[0] == citykit.BALL:
            continue
        loc = citykit.yxz_matrix(r[4], r[5], r[6]).T @ (p - np.array(r[1:4], float))
        h = np.array(r[7:10], float) / 2
        if r[0] == citykit.CYLINDER:
            if abs(loc[0]) <= h[0] and loc[1] ** 2 + loc[2] ** 2 <= min(h[1], h[2]) ** 2:
                return True
        elif np.all(np.abs(loc) <= h):
            return True
    return False


def coplanar_pairs(D, gap=0.06):
    """Pairs of parts of D (by row) with same-facing parallel faces less than `gap` apart that
    overlap (by their bounding squares in the face plane, sampled) where it can be seen (points
    just in front of the front face not inside another part): what z-fights or flickers. Rough on
    purpose (the whole-alley detector is the reference); returns [(i, j, gap)]."""
    rows = [r for r in D.parts if r[12] < 1]
    # (a face down on the floor, y 0, is hidden by the floor: never counted)
    F = [[fc for fc in _faces(r) if not (fc[0][1] < -0.99 and abs(fc[1][1]) < 0.01)] for r in rows]
    out = []
    for i in range(len(rows)):
        for j in range(i + 1, len(rows)):
            if np.linalg.norm(np.array(rows[i][1:4]) - np.array(rows[j][1:4])) > \
                    (max(rows[i][7:10]) + max(rows[j][7:10])) * 0.9 + 0.1:
                continue
            best = None
            for n1, c1, e1, ax1 in F[i]:
                for n2, c2, e2, ax2 in F[j]:
                    if n1 @ n2 < 0.9995:
                        continue
                    g = abs((c2 - c1) @ n1)
                    if g >= gap - 1e-4:
                        continue
                    # overlap: some sample points of face 2 (inset 10 %) inside face 1, seen
                    hits = 0
                    front = max(0.0, (c2 - c1) @ n1) + 0.01
                    for u in (-0.8, 0, 0.8):
                        for v in (-0.8, 0, 0.8):
                            p = c2 + u * e2[0] * ax2[0] + v * e2[1] * ax2[1]
                            d = p - c1
                            if abs(d @ ax1[0]) < e1[0] * 0.98 and abs(d @ ax1[1]) < e1[1] * 0.98:
                                q = p - ((p - c1) @ n1) * n1 + front * n1
                                if not _inside(rows, q, (i, j)):
                                    hits += 1
                    area = 4 * e2[0] * e2[1] * hits / 9
                    if hits >= 2 and area > 0.01 and (best is None or g < best):
                        best = g
            if best is not None:
                out.append((i, j, round(best, 4)))
    return out


def budget_check(seeds=300, zseeds=12):
    """Every prop over many seeds: part counts (min-max) per variant, no bottle anywhere, and
    its own coplanar same-facing face pairs (a: gap < 0.02, b: 0.02-0.06) over a few seeds."""
    lines = []
    for fn, variants in pg.CATALOGUE:
        lo, hi = 10 ** 9, 0
        za = zb = 0
        for v in variants:
            for seed in range(seeds):
                D = citykit.Data()
                n = fn(D, "T", (X0, 0, Z0), random.Random(seed).uniform(0, 360), random.Random(seed), **v)
                assert n == len(D.parts)
                for name in D.names:
                    assert "bottle" not in name.lower(), (fn.__name__, name)
                lo, hi = min(lo, n), max(hi, n)
                if seed < zseeds:
                    for _i, _j, g in coplanar_pairs(D):
                        if g < 0.02:
                            za += 1
                        else:
                            zb += 1
        lines.append(f"{fn.__name__:18s} {lo:3d}-{hi:3d} parts   own coplanar pairs over {zseeds} seeds x "
                     f"{len(variants)} variants: a {za}, b {zb}")
    return lines


def build(group, seed=1):
    D = citykit.Data()
    rng = random.Random(seed)
    z = 0.0
    width = 0.0
    names = GROUPS[group]
    for name in names:
        fn, variants = BY_NAME[name]
        cell = CELL.get(name, 3.5 if name in SMALL_ONES else 4.5)
        reps = 2 if name in SMALL_ONES else 1
        x = 0.0
        if name in WALL_PROPS:  # a wall behind the row, 1 stud past its origins (they find its face)
            D.box("Cat", "Wall", X0 - 6, X0 + len(variants) * reps * cell, 0, 2.8, Z0 + z + 1.0, Z0 + z + 1.6,
                  (84, 60, 50), "Brick")
        for v in variants:
            for _ in range(reps):
                fn(D, "Cat", (X0 + x, 0, Z0 + z), rng.uniform(-30, 30), rng, **v)
                x += cell
        width = max(width, x)
        z += cell
    # the ground: dark worn asphalt, a wall along the back
    D.box("Cat", "Ground", X0 - 6, X0 + width + 2, -0.6, 0.0, Z0 - 6, Z0 + z + 2, (52, 52, 54), "Asphalt")
    D.box("Cat", "Wall", X0 - 6, X0 + width + 2, 0, 6, Z0 + z + 2, Z0 + z + 3, (84, 60, 50), "Brick")
    return D, width, z


def small_preview(D, cams, out, night=False, samples=16):
    """citykit.preview at 640 x 420 with denoising (the machine is shared: small, few samples)."""
    src = citykit._PREVIEW
    citykit._PREVIEW = src.replace("sc.render.resolution_x, sc.render.resolution_y = 900, 600",
                                   "sc.render.resolution_x, sc.render.resolution_y = 640, 420\n"
                                   "sc.cycles.use_denoising = True\n"
                                   "try:\n    sc.cycles.denoiser = 'OPENIMAGEDENOISE'\nexcept Exception:\n    pass")
    citykit._PREVIEW = citykit._PREVIEW.replace("sc.cycles.use_denoising = False; ", "")
    try:
        return citykit.preview(D, cams, out, night=night, samples=samples)
    finally:
        citykit._PREVIEW = src


def cameras(width, depth):
    """An overview from the front, high, fitted to the grid; two views at a character's eye height
    (5 studs) on the front rows and the back rows."""
    cx, cz = width / 2 - 1.5, depth / 2 - 2
    span = max(width * 0.62, depth * 0.95, 8)
    cams = [
        ((cx, span * 1.5, cz - span * 0.7), (cx, 0, cz + 0.4), 50),
        ((width * 0.3, 5.0, -5.5), (width * 0.38, 0.0, depth * 0.3), 55),
        ((width * 0.7, 5.0, depth * 0.25 - 4.5), (width * 0.55, 0.0, depth * 0.75), 55),
    ]
    return [((e[0] + X0, e[1], e[2] + Z0), (t[0] + X0, t[1], t[2] + Z0), fov) for e, t, fov in cams]


def linear(D):
    """A copy ready for citykit.preview: its wedges turned the way the preview's mesh expects."""
    L = copy.deepcopy(D)
    # (citykit.preview already turns the sRGB colours linear: doing it here too made every render
    # far too dark)
    # citykit.preview builds its wedge mesh turned 180 deg about X (full face up, slope underneath):
    # pre-turn every wedge by 180 deg about its own X so the render shows it as Roblox does
    flip = citykit.yxz_matrix(180, 0, 0)
    for r in L.parts:
        if r[0] == citykit.WEDGE:
            m = citykit.yxz_matrix(r[4], r[5], r[6]) @ flip
            r[4], r[5], r[6] = (round(a, 2) for a in citykit.yxz_angles(m))
    return L


def close(name, seed=1, wall=None):
    """One prop's variants in a row on a concrete floor (a wall behind them for the wall-foot
    props), with two cameras at a standing player's eye (5 studs up, 6-9 studs away)."""
    fn, variants = BY_NAME[name]
    cell = CELL.get(name, 3.5 if name in SMALL_ONES else 4.5)
    rng = random.Random(seed)
    D = citykit.Data()
    wall = name in WALL_PROPS if wall is None else wall
    n = len(variants) * (2 if name in SMALL_ONES else 1)
    width = n * cell
    D.box("Cat", "Ground", X0 - 4, X0 + width + 4, -0.6, 0.0, Z0 - 8, Z0 + 4, (92, 89, 84), "Concrete")
    if wall:
        D.box("Cat", "Wall", X0 - 4, X0 + width + 4, 0, 6, Z0 + 0.6, Z0 + 1.6, (84, 60, 50), "Brick")
    x = 0.0
    for v in variants:
        for _ in range(2 if name in SMALL_ONES else 1):
            fn(D, "Cat", (X0 + x, 0, Z0), 0 if wall else rng.uniform(-30, 30), rng, **v)
            x += cell
    cx = X0 + (width - cell) / 2
    far = max(6.0, width * 0.55)
    cams = [((cx - width * 0.15, 5.0, Z0 - far), (cx, 0.2, Z0 + 0.2), 55),
            ((X0 - 1.5, 3.2, Z0 - 3.5), (X0 + cell * 0.6, 0.2, Z0 + 0.3), 50)]
    return D, cams


def main():
    if "--close" in sys.argv:  # --close OUT_DIR name [name ...]: eye-level close-ups of single props
        args = [a for a in sys.argv[1:] if not a.startswith("--")]
        os.makedirs(args[0], exist_ok=True)
        for name in args[1:]:
            D, cams = close(name)
            print(name, len(D.parts), "parts")
            small_preview(linear(D), cams, os.path.join(args[0], f"{name}"), samples=16)
        return
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    fast = "--fast" in sys.argv
    check = "--check" in sys.argv
    out = args[0] if args else None
    groups = args[1:] or list(GROUPS)
    if check or not fast:
        for line in budget_check(seeds=60 if check else 300):
            print(line)
    if check:
        return
    os.makedirs(out, exist_ok=True)
    for g in groups:
        D, width, depth = build(g)
        cams = cameras(width, depth)
        print(g, len(D.parts), "parts")
        small_preview(linear(D), cams, os.path.join(out, f"{g}_day"), samples=12 if fast else 20)
        if "--night" in sys.argv:  # the same, lit by two bare bulbs
            for (x, z) in ((width * 0.3, depth * 0.4), (width * 0.75, depth * 0.7)):
                D.part("Cat", "Bulb", (x, 7, z), (0.3, 0.3, 0.3), (255, 200, 150), "Neon", shape=citykit.BALL,
                       flags=0, extra={"l": {"type": "Point", "color": [255, 176, 110], "range": 16,
                                             "brightness": 1.2}})
            small_preview(linear(D), [cams[2]], os.path.join(out, f"{g}_night"), night=True, samples=20)


if __name__ == "__main__":
    main()
