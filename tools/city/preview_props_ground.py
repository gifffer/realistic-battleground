"""Renders the ground-prop catalogue of props_ground.py (every prop, several variants), group by
group, from a few day cameras and one night view lit by a bulb, to LOOK at them.

    venv/bin/python -I tools/city/preview_props_ground.py OUT_DIR [group ...] [--fast]

Groups: litter, bags, wood, masonry, objects, floor. Writes OUT_DIR/<group>_day_<i>.png and
OUT_DIR/<group>_night_0.png. Also checks every prop stays in its part budget over many seeds.
"""

import copy
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import citykit  # noqa: E402
import props_ground as pg  # noqa: E402

GROUPS = {
    "litter": ["paper_ball", "paper_sheet", "wrapper", "cigarette_butts", "litter_scatter", "gum_spots"],
    "bags": ["trash_bag", "trash_heap", "cardboard_box", "cardboard_flat"],
    "wood": ["wood_scraps", "pallet", "pallet_stack", "plank_stack"],
    "masonry": ["cinder_block", "loose_bricks", "concrete_chunk", "rubble_pile", "rebar"],
    "objects": ["tyre", "carpet_roll", "scrap_sheet", "tarp_scrap", "rope_coil", "cement_bag", "pipe_piece",
                "traffic_cone", "milk_crate", "bucket"],
    "floor": ["oil_stain", "damp_stain", "crack", "pothole", "asphalt_patch", "manhole", "drain_grate", "weeds",
              "moss_patch", "puddle", "paint_marks", "leaves_drift", "wall_base_grime"],
}
CELL = {"litter_scatter": 6, "trash_heap": 8, "pallet_stack": 6, "plank_stack": 8, "rubble_pile": 8,
        "carpet_roll": 8, "scrap_sheet": 7, "pallet": 6, "leaves_drift": 6, "wall_base_grime": 9, "weeds": 7,
        "crack": 7, "asphalt_patch": 6, "damp_stain": 6, "trash_bag": 4.5, "cardboard_flat": 5, "tyre": 4,
        "drain_grate": 7, "manhole": 4.5, "pothole": 4.5, "tarp_scrap": 5, "paint_marks": 4, "rope_coil": 3.5}
SMALL_ONES = {"paper_ball", "paper_sheet", "wrapper", "cigarette_butts", "gum_spots"}

BY_NAME = {fn.__name__: (fn, variants) for fn, variants in pg.CATALOGUE}


def budget_check():
    """Every prop over 300 seeds: part counts (min-max) per variant, and no bottle anywhere."""
    lines = []
    for fn, variants in pg.CATALOGUE:
        lo, hi = 10 ** 9, 0
        for v in variants:
            for seed in range(300):
                D = citykit.Data()
                n = fn(D, "T", (0, 0, 0), random.Random(seed).uniform(0, 360), random.Random(seed), **v)
                assert n == len(D.parts)
                for name in D.names:
                    assert "bottle" not in name.lower(), (fn.__name__, name)
                lo, hi = min(lo, n), max(hi, n)
        lines.append(f"{fn.__name__:18s} {lo:3d}-{hi:3d} parts")
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
        for v in variants:
            for _ in range(reps):
                fn(D, "Cat", (x, 0, z), rng.uniform(-30, 30), rng, **v)
                x += cell
        width = max(width, x)
        z += cell
    # the ground: dark worn asphalt, a wall along the back (+Z... the north side here is -Z: put it behind
    # the first row) to read the "against a wall" props
    D.box("Cat", "Ground", -6, width + 2, -0.6, 0.0, -6, z + 2, (52, 52, 54), "Asphalt")
    D.box("Cat", "Wall", -6, width + 2, 0, 6, z + 2, z + 3, (84, 60, 50), "Brick")
    return D, width, z


def cameras(width, depth):
    cx, cz = width / 2 - 2, depth / 2 - 2
    span = max(width, depth)
    return [
        ((cx, span * 0.75, -span * 0.45), (cx, 0, cz * 0.9), 50),  # overview, from the front, high
        ((width * 0.22, 4.0, -4.5), (width * 0.3, 0.2, depth * 0.22), 50),  # a character's eye, front rows
        ((width * 0.78, 4.5, depth * 0.3), (width * 0.55, 0.2, depth * 0.62), 55),  # eye level, back rows
    ]


def linear(D):
    """A copy whose colours are linearised (Roblox colours are sRGB; the preview feeds them raw)."""
    L = copy.deepcopy(D)
    L.colors = [[255 * (c / 255) ** 2.2 for c in col] for col in L.colors]
    return L


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    fast = "--fast" in sys.argv
    out = args[0]
    groups = args[1:] or list(GROUPS)
    os.makedirs(out, exist_ok=True)
    if not fast:
        for line in budget_check():
            print(line)
    for g in groups:
        D, width, depth = build(g)
        cams = cameras(width, depth)
        print(g, len(D.parts), "parts")
        citykit.preview(linear(D), cams, os.path.join(out, f"{g}_day"), samples=16 if fast else 32)
        # night: the same, lit by two bare bulbs
        for (x, z) in ((width * 0.3, depth * 0.4), (width * 0.75, depth * 0.7)):
            D.part("Cat", "Bulb", (x, 7, z), (0.3, 0.3, 0.3), (255, 200, 150), "Neon", shape=citykit.BALL,
                   flags=0, extra={"l": {"type": "Point", "color": [255, 176, 110], "range": 16, "brightness": 1.2}})
        citykit.preview(linear(D), [cams[2]], os.path.join(out, f"{g}_night"), night=True,
                        samples=24 if fast else 48)


if __name__ == "__main__":
    main()
