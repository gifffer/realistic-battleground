"""Renders the object-prop catalogue of props_objects.py (every prop, several variants), group by
group, from a few day cameras and one night view lit by bulbs (plus the props' own lights), to
LOOK at them.

    venv/bin/python -I tools/city/preview_props_objects.py OUT_DIR [group ...] [--fast] [--nocheck]
    venv/bin/python -I tools/city/preview_props_objects.py OUT_DIR --close prop[,prop...] [--seed N]
    venv/bin/python -I tools/city/preview_props_objects.py --check

Groups: bins, drums, container, crates, market, goods, goods2, squat, camp, site. Writes
OUT_DIR/<group>_day_<i>.png and OUT_DIR/<group>_night_0.png. `--close` renders each named prop's
variants in a row from two close cameras (a 3/4 view at eye height and a high one) to
OUT_DIR/close_<prop>_<i>.png. Renders are small (640 x 420, Cycles CPU, denoised) so several
agents can share the machine. `--check` (also run before renders unless --nocheck) checks every
prop's part count over many seeds (min-max per prop) and that nothing is a bottle: no part
named like one (bottle, flask, canister, gas cylinder) and no free-standing bottle-shaped
upright cylinder (glass, plastic or metal, 0.25-1.2 studs across, at least 2.2 times as tall,
not a leg, pole or post).
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
    "drums": ["wheelie_bin", "oil_drum", "traffic_cone"],
    "container": ["shipping_container"],
    "crates": ["wooden_crates", "plastic_crates"],
    "market": ["market_canopy", "folding_table", "clothes_rack", "market_stall"],
    "goods": ["phone_tray", "watch_case", "car_stereos", "cash_box"],
    "goods2": ["shoe_boxes", "radio", "tv"],
    "squat": ["mattress", "sleeping_bag", "blankets", "cardboard_shelter", "armchair"],
    "camp": ["tent", "lean_to", "camp_stool", "camp_stove", "shopping_cart", "backpack"],
    "site": ["construction_barrier", "scaffolding", "office_chair"],
}
CELL = {
    "dumpster": 9,
    "recycling_bin": 6.5,
    "wheelie_bin": 5,
    "oil_drum": 4,
    "shipping_container": 24,
    "wooden_crates": 7,
    "plastic_crates": 6,
    "traffic_cone": 4,
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
    "tent": 8,
    "lean_to": 8,
    "camp_stool": 3,
    "camp_stove": 3,
    "shopping_cart": 7,
    "backpack": 3,
    "construction_barrier": 9,
    "scaffolding": 17,
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
    "dumpster": 9,
    "shopping_cart": 8,
}
TABLE_TOP = {"phone_tray", "watch_case", "car_stereos", "cash_box"}  # shown on a table

BY_NAME = {fn.__name__: (fn, variants) for fn, variants in po.CATALOGUE}


BOTTLE_WORDS = ("bottle", "flask", "canister", "gascylinder", "jerrycan", "thermos")
NOT_BOTTLE = ("leg", "pole", "post", "upright", "pipe", "tube", "rod", "aerial", "flex", "rope", "peg", "foot",
              "rail", "brace", "standard", "ledger", "transom", "handle", "axle", "hinge", "lift", "stem", "neck")


def bottle_like(D):
    """Names of parts that are, or read as, a bottle: a bottle-ish name, or an upright cylinder
    0.25-1.2 studs across and at least 2.2 times as tall that is not a leg / pole / post."""
    bad = []
    for r in D.parts:
        name = D.names[r[16] - 1]
        low = name.lower()
        if any(w in low for w in BOTTLE_WORDS):
            bad.append(name)
            continue
        if r[0] != citykit.CYLINDER or any(w in low for w in NOT_BOTTLE):
            continue
        if D.materials[r[11] - 1] not in ("Glass", "Plastic", "SmoothPlastic", "Metal", "Neon", "ForceField"):
            continue  # (a rolled blanket or a log is no bottle)
        m = citykit.yxz_matrix(r[4], r[5], r[6])
        length, dia = r[7], min(r[8], r[9])
        if abs(m[1, 0]) > 0.94 and 0.25 <= dia <= 1.2 and length >= 2.2 * dia:
            bad.append(name)
    return bad


def budget_check(seeds=200):
    """Every prop over many seeds: part counts (min-max) over its variants, nothing bottle-like."""
    lines = []
    for fn, variants in po.CATALOGUE:
        lo, hi = 10**9, 0
        for v in variants:
            for seed in range(seeds):
                D = citykit.Data()
                n = fn(D, "T", (0, 0, 0), random.Random(seed).uniform(0, 360), random.Random(seed), **v)
                assert n == len(D.parts)
                bad = bottle_like(D)
                assert not bad, (fn.__name__, v, seed, bad)
                lo, hi = min(lo, n), max(hi, n)
        lines.append(f"{fn.__name__:22s} {lo:3d}-{hi:3d} parts")
    return lines


SMALL_RENDER = (640, 420)


def render(D, cams, out, night=False, samples=20):
    """citykit.preview's Blender scene, made small and denoised (OpenImageDenoise when the build
    has it): renders D from each camera to out_<i>.png and returns the paths."""
    import json
    import subprocess
    import tempfile

    script = citykit._PREVIEW.replace(
        "sc.render.resolution_x, sc.render.resolution_y = 900, 600",
        f"sc.render.resolution_x, sc.render.resolution_y = {SMALL_RENDER[0]}, {SMALL_RENDER[1]}",
    ).replace(
        "sc.cycles.use_denoising = False",
        "sc.cycles.use_denoising = True\ntry:\n    sc.cycles.denoiser = 'OPENIMAGEDENOISE'\nexcept Exception:\n    pass",
    )
    tmp = tempfile.mkdtemp()
    for name, obj in (("d.json", D.to_json()), ("c.json", cams)):
        with open(os.path.join(tmp, name), "w") as fh:
            json.dump(obj, fh)
    with open(os.path.join(tmp, "r.py"), "w") as fh:
        fh.write(script)
    py = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "venv", "bin", "python")
    subprocess.run([py, "-I", os.path.join(tmp, "r.py"), "--", os.path.join(tmp, "d.json"), os.path.join(tmp, "c.json"),
                    out, "night" if night else "day", str(samples), "1.0"], check=True, capture_output=True)
    return [f"{out}_{i}.png" for i in range(len(cams))]


def close(name, out, seed=3):
    """The variants of one prop in a row (table goods on a stand), from two close cameras."""
    fn, variants = BY_NAME[name]
    D = citykit.Data()
    rng = random.Random(seed)
    cell = CELL.get(name, 5)
    x, top = 0.0, 0.0
    for v in variants:
        y = 0.0
        if name in TABLE_TOP:
            D.box("Cat", "Stand", x - 1.2, x + 1.2, 0, 2.0, -0.9, 0.9, (70, 60, 48), "WoodPlanks")
            y = 2.0
        fn(D, "Cat", (x, y, 0), rng.uniform(-12, 12), rng, **v)
        x += cell
    for r in D.parts:
        top = max(top, r[2] + max(r[7], r[8], r[9]) / 2)
    width = x - cell
    D.box("Cat", "Ground", -cell, width + cell, -0.6, 0.0, -cell, cell, (52, 52, 54), "Asphalt")
    cx = width / 2
    span = max(width + cell, top * 1.6, 4)
    h = max(2.0, min(top, 8))
    cams = [
        ((cx - span * 0.35, h * 0.75 + 1.5, -span * 0.75), (cx, h * 0.4, 0), 50),
        ((cx + span * 0.1, h + span * 0.55, -span * 0.45), (cx, h * 0.3, 0.3), 50),
    ]
    return render(linear(D), cams, os.path.join(out, f"close_{name}"))


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
    if "--check" in sys.argv:
        for line in budget_check(60 if fast else 200):
            print(line)
        print("ok: no bottle-like part")
        return
    out = args[0]
    os.makedirs(out, exist_ok=True)
    if "--close" in sys.argv:
        names = sys.argv[sys.argv.index("--close") + 1].split(",")
        seed = int(sys.argv[sys.argv.index("--seed") + 1]) if "--seed" in sys.argv else 3
        for name in names:
            print(*close(name, out, seed), flush=True)
        return
    groups = args[1:] or list(GROUPS)
    if "--nocheck" not in sys.argv:
        for line in budget_check(60 if fast else 200):
            print(line)
    for g in groups:
        D, width, depth = build(g)
        first = GROUPS[g][0]
        cams = cameras(width, depth, ROW.get(first, CELL.get(first, 5)))
        print(g, len(D.parts), "parts", flush=True)
        render(linear(D), cams, os.path.join(out, f"{g}_day"), samples=12 if fast else 20)
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
        render(linear(D), [cams[0]], os.path.join(out, f"{g}_night"), night=True, samples=16 if fast else 24)


if __name__ == "__main__":
    main()
