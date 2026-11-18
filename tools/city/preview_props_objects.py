"""Renders the object-prop catalogue of props_objects.py (every prop, several variants), group by
group, from a few day cameras and one night view lit by bulbs (plus the props' own lights), to
LOOK at them.

    venv/bin/python -I tools/city/preview_props_objects.py OUT_DIR [group ...] [--fast] [--nocheck]

Groups: bins, drums, container, crates, market, goods, goods2, squat, camp, site. Writes OUT_DIR/<group>_day_<i>.png
and OUT_DIR/<group>_night_0.png. Also checks every prop's part count over many seeds (min-max per
prop) and that no part anywhere is a bottle.
"""

import copy
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import citykit  # noqa: E402
import props_objects as po  # noqa: E402

GROUPS = {
    "bins": ["dumpster", "recycling_bin"],
    "drums": ["wheelie_bin", "oil_drum", "gas_canisters", "traffic_cone"],
    "container": ["shipping_container"],
    "crates": ["wooden_crates", "plastic_crates", "ladder"],
    "market": ["market_canopy", "folding_table", "clothes_rack", "market_stall"],
    "goods": ["phone_tray", "watch_case", "car_stereos", "cash_box"],
    "goods2": ["shoe_boxes", "radio", "tv"],
    "squat": ["mattress", "sleeping_bag", "blankets", "cardboard_shelter", "armchair", "cardboard_sign"],
    "camp": ["tent", "lean_to", "camp_stool", "camp_stove", "shopping_cart", "backpack"],
    "site": ["construction_barrier", "scaffolding", "plastic_sheeting", "office_chair"],
}
CELL = {
    "dumpster": 9,
    "recycling_bin": 6.5,
    "wheelie_bin": 5,
    "oil_drum": 4,
    "shipping_container": 24,
    "gas_canisters": 6,
    "wooden_crates": 7,
    "plastic_crates": 6,
    "traffic_cone": 4,
    "ladder": 5,
    "market_canopy": 12,
    "folding_table": 8,
    "clothes_rack": 7,
    "market_stall": 14,
    "phone_tray": 3,
    "watch_case": 3,
    "shoe_boxes": 3.5,
    "car_stereos": 3,
    "radio": 3.5,
    "cash_box": 2.5,
    "tv": 5,
    "mattress": 5.5,
    "sleeping_bag": 4.5,
    "blankets": 4.5,
    "cardboard_shelter": 6,
    "armchair": 5,
    "cardboard_sign": 4,
    "tent": 8,
    "lean_to": 8,
    "camp_stool": 3,
    "camp_stove": 3,
    "shopping_cart": 7,
    "backpack": 3,
    "construction_barrier": 9,
    "scaffolding": 17,
    "plastic_sheeting": 6,
    "office_chair": 5,
}
ROW = {
    "shipping_container": 12,
    "market_canopy": 10,
    "market_stall": 11,
    "scaffolding": 9,
    "tent": 10,
    "lean_to": 8,
    "mattress": 9,
    "sleeping_bag": 8,
    "cardboard_shelter": 9,
    "ladder": 11,
    "dumpster": 9,
    "shopping_cart": 8,
}
TABLE_TOP = {"phone_tray", "watch_case", "car_stereos", "cash_box"}  # shown on a table

BY_NAME = {fn.__name__: (fn, variants) for fn, variants in po.CATALOGUE}


def budget_check(seeds=200):
    """Every prop over many seeds: part counts (min-max) over its variants, no bottle anywhere."""
    lines = []
    for fn, variants in po.CATALOGUE:
        lo, hi = 10**9, 0
        for v in variants:
            for seed in range(seeds):
                D = citykit.Data()
                n = fn(D, "T", (0, 0, 0), random.Random(seed).uniform(0, 360), random.Random(seed), **v)
                assert n == len(D.parts)
                for name in D.names:
                    assert "bottle" not in name.lower(), (fn.__name__, name)
                lo, hi = min(lo, n), max(hi, n)
        lines.append(f"{fn.__name__:22s} {lo:3d}-{hi:3d} parts")
    return lines


def build(group, seed=3):
    D = citykit.Data()
    rng = random.Random(seed)
    z = 0.0
    width = 0.0
    for name in GROUPS[group]:
        fn, variants = BY_NAME[name]
        cell = CELL.get(name, 5)
        row = ROW.get(name, cell if cell < 8 else 7)
        row = max(row, 4.5)
        x = 0.0
        for v in variants:
            y = 0.0
            if name in TABLE_TOP:  # a crate as a little table under it
                D.box("Cat", "Stand", x - 1.2, x + 1.2, 0, 2.0, z - 0.9, z + 0.9, (70, 60, 48), "WoodPlanks")
                y = 2.0
            fn(D, "Cat", (x, y, z), rng.uniform(-12, 12), rng, **v)
            x += cell
        width = max(width, x)
        z += row
    D.box("Cat", "Ground", -8, width + 4, -0.6, 0.0, -8, z + 3, (52, 52, 54), "Asphalt")
    D.box("Cat", "Wall", -8, width + 4, 0, 9, z + 3, z + 4, (84, 60, 50), "Brick")
    return D, width, z


def cameras(width, depth, first_row):
    """A high overview from the front fitted to the grid; two views at a character's eye height
    (5 studs) on the left and right halves, standing in front of the first row."""
    cx, cz = width / 2 - 2.5, depth / 2 - 2
    span = max(width * 0.6, depth * 0.95, 10)
    ez = -5.0 - 0.55 * first_row
    return [
        ((cx, span * 0.95, cz - span * 1.0), (cx, 0.5, cz + 0.6), 50),
        ((width * 0.2, 5.0, ez), (width * 0.3, 1.5, depth * 0.4), 62),
        ((width * 0.75, 5.5, ez + 0.5), (width * 0.6, 1.5, depth * 0.55), 62),
    ]


def linear(D):
    """A copy whose colours are linearised (Roblox colours are sRGB; the preview feeds them raw), and
    whose wedges are pre-turned so citykit.preview shows them as Roblox does."""
    L = copy.deepcopy(D)
    L.colors = [[255 * (c / 255) ** 2.2 for c in col] for col in L.colors]
    flip = citykit.yxz_matrix(180, 0, 0)
    for r in L.parts:
        if r[0] == citykit.WEDGE:
            m = citykit.yxz_matrix(r[4], r[5], r[6]) @ flip
            r[4], r[5], r[6] = (round(a, 2) for a in citykit.yxz_angles(m))
    return L


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    fast = "--fast" in sys.argv
    out = args[0]
    groups = args[1:] or list(GROUPS)
    os.makedirs(out, exist_ok=True)
    if "--nocheck" not in sys.argv:
        for line in budget_check(60 if fast else 200):
            print(line)
    for g in groups:
        D, width, depth = build(g)
        first = GROUPS[g][0]
        cams = cameras(width, depth, ROW.get(first, CELL.get(first, 5)))
        print(g, len(D.parts), "parts", flush=True)
        citykit.preview(linear(D), cams, os.path.join(out, f"{g}_day"), samples=16 if fast else 32)
        for x, z in ((width * 0.25, depth * 0.35), (width * 0.7, depth * 0.65)):
            D.part(
                "Cat",
                "Bulb",
                (x, 9, z),
                (0.3, 0.3, 0.3),
                (255, 200, 150),
                "Neon",
                shape=citykit.BALL,
                flags=0,
                extra={"l": {"type": "Point", "color": [255, 176, 110], "range": 20, "brightness": 1.0}},
            )
        citykit.preview(linear(D), [cams[0]], os.path.join(out, f"{g}_night"), night=True, samples=24 if fast else 48)


if __name__ == "__main__":
    main()
