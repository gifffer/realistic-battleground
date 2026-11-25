"""Catalogue of props_walls: lays every wall / facade prop out on test walls (several
variants each) and renders the boards with citykit.preview (Cycles CPU), day and night;
and checks the library.

    venv/bin/python -I tools/city/preview_props_walls.py [out_dir] [board ...] [--day]
    venv/bin/python -I tools/city/preview_props_walls.py --check

Boards: surfaces, openings, services, structure, windows (the 20 windows' variety, close).
Renders are small (640 x 420, denoised, SAMPLES env, default 20: the machine is shared).
Look at the PNGs.

--check (no render): every prop over many seeds and its variants: its part count (min-max, and
that the count it returns is the parts it made), no bottle anywhere (no part named like one, no
small upright cylinder that could read as one), and its own same-facing faces on one plane
(a: gap < 0.02, the z-fighting; b: 0.02-0.06) on a test wall. Rough on purpose: the whole-alley
z-fight detector is the reference (overlays sit 0.055 off the wall by design: those b pairs
with the wall are not counted here).
"""

import os
import random
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import citykit  # noqa: E402
import props_walls as pw  # noqa: E402
import numpy as np  # noqa: E402
from citykit import SOLID, Data, preview, yxz_matrix  # noqa: E402

# Small denoised renders (the machine is shared). (citykit.preview itself turns the sRGB colours
# linear and gives shadows only to the parts that cast one, as in Roblox.)
citykit._PREVIEW = citykit._PREVIEW.replace(
    "sc.render.resolution_x, sc.render.resolution_y = 900, 600",
    "sc.render.resolution_x, sc.render.resolution_y = 640, 420\n"
    "sc.cycles.use_denoising = True\n"
    "try:\n    sc.cycles.denoiser = 'OPENIMAGEDENOISE'\nexcept Exception:\n    pass",
).replace("sc.cycles.use_denoising = False; ", "")
assert "640, 420" in citykit._PREVIEW

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else os.path.join(os.path.dirname(os.path.abspath(__file__)), "_preview")
ONLY = set(ARGS[1:])
F = "Preview/Props"
SAMPLES = int(os.environ.get("SAMPLES", "20"))
# Built far from the city: zlayers looks up the parts behind an overlay (city data included)
X0 = 20000.0


def wall(D, x0, x1, top, z0=0.0, z1=1.0, color=(84, 60, 50)):
    D.box("Preview/Wall", "Wall", X0 + x0, X0 + x1, 0, top, z0, z1, color, "Brick", flags=SOLID)


def floor(D, x0, x1, z0, z1):
    D.box("Preview/Wall", "Floor", X0 + x0, X0 + x1, -0.2, 0, z0, z1, (46, 47, 50), "Asphalt", flags=SOLID)


def o(x, z=0.0):
    return (X0 + x, 0, z)


def cams_at(cams):
    return [((e[0] + X0, e[1], e[2]), (t[0] + X0, t[1], t[2]), fov) for e, t, fov in cams]


def board_surfaces():
    D, r = Data(), random.Random(11)
    floor(D, -22, 22, -16, 1)
    wall(D, -20, 20, 14)
    pw.wall_grime(D, F, o(-10), 0, r, width=20, height=4.5)
    pw.wall_grime(D, F, o(10), 0, r, width=20, height=3.5)
    pw.plaster_patch(D, F, o(-15), 0, r, width=6, height=5, y=3)
    pw.plaster_patch(D, F, o(13), 0, r, width=7, height=6, y=6.5)
    pw.rust_streak(D, F, o(-8), 0, r, y=11, length=5)
    pw.rust_streak(D, F, o(-6.8), 0, r, y=11.2, length=3.5, width=0.4, bolt=False)
    pw.torn_posters(D, F, o(-7), 0, r, width=3.6, height=4.2, y=3.2)
    pw.torn_posters(D, F, o(-2.5), 0, r, width=3.0, height=3.6, y=3.6, text="MISSING")
    pw.painted_sign(D, F, o(-4), 0, r, width=12, height=2.6, y=10.4)
    pw.graffiti_tag(D, F, o(6.5), 0, r, width=5, height=1.8, y=3.5, buffed=True)
    pw.graffiti_tag(D, F, o(8), 0, r, width=6, height=2.2, y=7, text="MARROW EATS ITS OWN", color=(170, 60, 50))
    cams = [((0, 8, -30), (0, 6.5, 0), 62), ((-14, 6, -14), (-8, 6, 0), 60), ((12, 6, -14), (8, 5.5, 0), 62)]
    return D, cams_at(cams)


def board_openings():
    D, r = Data(), random.Random(23)
    floor(D, -26, 26, -18, 1)
    wall(D, -24, 24, 19)
    pw.wall_grime(D, F, o(0), 0, r, width=48, height=4)
    for x, v in ((-18, "dirty"), (-10, "lit"), (-2, "boarded"), (6, "barred"), (14, "broken")):
        pw.window(D, F, o(x), 0, r, variant=v, y=11.5)
    pw.back_door(D, F, o(-18), 0, r, variant="closed")
    pw.back_door(D, F, o(-10), 0, r, variant="ajar", stencil="FIRE EXIT · KEEP CLEAR")
    pw.back_door(D, F, o(-2.5), 0, r, variant="chained", dead_light=True)
    pw.roller_shutter(D, F, o(7), 0, r, width=8, height=7)
    pw.roller_shutter(D, F, o(17.5), 0, r, width=7, height=6.5, open_height=1.6, tag=False)
    pw.window(D, F, o(21.5), 0, r, variant="dirty", y=11.5, width=3.0)
    cams = [((0, 10, -40), (0, 8, 0), 62), ((-16, 6, -12), (-10, 6, 0), 62), ((12, 6, -11), (12, 7, 0), 64)]
    return D, cams_at(cams)


def board_windows():
    """Ten windows side by side, the way the alleys use them (default size), seen close."""
    D, r = Data(), random.Random(5)
    floor(D, -26, 26, -18, 1)
    wall(D, -24, 24, 22)
    variants = ["dirty", "lit", "dirty", "boarded", "barred", "broken", "dirty", "lit", "broken", "dirty"]
    for i, v in enumerate(variants):
        pw.window(D, F, o(-21 + i * 4.7), 0, r, variant=v, y=3 if i % 2 else 12.5, kind="warm")
    cams = [((-12, 10, -24), (-12, 10, 0), 58), ((9, 10, -24), (9, 10, 0), 58), ((-14, 4, -7), (-16.5, 6, 0), 60)]
    return D, cams_at(cams)


def board_services():
    D, r = Data(), random.Random(37)
    floor(D, -22, 22, -16, 1)
    wall(D, -20, 20, 18)
    wall(D, -20, 20, 18, -15, -14, (96, 64, 52))  # the opposite wall (for the cables)
    pw.wall_grime(D, F, o(0), 0, r, width=40, height=3.5, soot=False)
    pw.ac_unit(D, F, o(-15), 0, r, y=9)
    pw.ac_unit(D, F, o(-9), 0, r, y=12, scale=0.85)
    pw.meter_box(D, F, o(-16), 0, r, y=2.6)
    pw.meter_box(D, F, o(-11), 0, r, y=3.2, conduits=1)
    pw.pipe_run(D, F, o(-3), 0, r, length=10, y=5.0, drop="down", valve=True)
    pw.pipe_run(D, F, o(4), 0, r, length=14, y=15.5, drop="up", diameter=0.45)
    pw.downpipe(D, F, o(2.5), 0, r, height=18)
    pw.downpipe(D, F, o(18), 0, r, height=18, gutter=4)
    pw.vent_hood(D, F, o(7), 0, r, y=7.5)
    pw.vent_hood(D, F, o(11), 0, r, y=3.2, width=1.4)
    pw.satellite_dish(D, F, o(-4), 0, r, y=11.5)
    pw.satellite_dish(D, F, o(15), 0, r, y=13.5, size=1.6)
    pw.bulkhead_light(D, F, o(-6.5), 0, r, y=7.5)
    pw.bulkhead_light(D, F, o(13.5), 0, r, y=7.5, flicker=True)
    pw.gooseneck_lamp(D, F, o(-1.5), 0, r, y=10.5)
    pw.gooseneck_lamp(D, F, o(9), 0, r, y=12)
    pw.cable_sag(D, F, o(-12), 0, r, span=14, y=16, y_end=15, cables=3, shoes=True)
    pw.cable_sag(D, F, o(6), 0, r, span=14, y=14, y_end=16, cables=2)
    # a few lights on the opposite wall (facing back, ry = 180)
    pw.bulkhead_light(D, F, o(0, -14), 180, r, y=8)
    cams = [((0, 8, -13), (0, 8, 0), 90), ((-12, 6, -8), (-11, 7, 0), 70), ((8, 5, -7), (6, 8, 0), 75)]
    return D, cams_at(cams)


def board_structure():
    D, r = Data(), random.Random(53)
    floor(D, -40, 40, -40, 20)
    wall(D, -16, 16, 30, 0, 4)
    pw.wall_grime(D, F, o(0), 0, r, width=32, height=5)
    for x, y, v in ((-3, 12, "dirty"), (-3, 21.5, "lit"), (9, 12, "barred"), (9, 21.5, "boarded"), (-12, 21.5, "broken"),
                    (-12, 12, "lit")):
        pw.window(D, F, o(x), 0, r, variant=v, y=y, height=4.8)
    pw.fire_escape(D, F, o(-3), 0, r, width=12, floors=3, floor_h=10)
    pw.back_door(D, F, o(9), 0, r)
    pw.building_top(D, F, o(0), 0, r, width=32, top=30, depth=4, clutter="tank")
    # background buildings beyond
    pw.background_facade(D, F, o(-30, 30), 0, r, width=36, height=70)
    pw.background_facade(D, F, o(14, 40), -8, r, width=44, height=90)
    pw.background_facade(D, F, o(52, 20), -25, r, width=30, height=55)
    cams = [((-6, 6, -48), (0, 24, 0), 70), ((-14, 22, -14), (-3, 18, 0), 70), ((5, 33, -12), (2, 30, 3), 70)]
    return D, cams_at(cams)


BOARDS = {"surfaces": board_surfaces, "openings": board_openings, "windows": board_windows,
          "services": board_services, "structure": board_structure}
NIGHT = {"openings": [((0, 8, -26), (0, 8, 0), 72)], "services": [((0, 8, -13), (0, 8, 0), 90)],
         "structure": [((-6, 6, -48), (0, 24, 0), 70)]}


def lights_out_of_bulbs(D):
    """Preview only: Blender's lights are blocked by the (opaque) bulb part they sit in, Roblox's
    are not. Move each light onto a tiny part just in front of its bulb (local -Z / -Y)."""
    for row in list(D.parts):
        if not row[18]:
            continue
        ex = D.extras[row[18] - 1]
        if not ex.get("l"):
            continue
        m = yxz_matrix(row[4], row[5], row[6])
        down = ex["l"].get("type") == "Spot"
        axis = m @ np.array((0, -1, 0) if down else (0, 0, -1))
        reach = (row[8] if down else row[9]) / 2 + 0.15
        c = np.array(row[1:4]) + axis * reach
        D.part("Preview/Light", "Light", tuple(c), (0.05, 0.05, 0.05), (0, 0, 0), "SmoothPlastic", rot=row[4:7],
               transparency=0.98, extra={"l": ex["l"]})
        ex.pop("l")


# ------------------------------------------------------------------ checks
VARIANTS = {
    "window": [dict(variant=v) for v in ("dirty", "lit", "boarded", "barred", "broken")],
    "back_door": [dict(variant=v) for v in ("closed", "ajar", "chained")],
    "roller_shutter": [dict(), dict(open_height=1.6)],
    "building_top": [dict(clutter=c) for c in ("tank", "antenna", "vents", None)],
    "fire_escape": [dict(floors=2, width=8), dict(floors=3, width=10)],
    "pipe_run": [dict(drop="down", valve=True), dict(drop="up"), dict(drop=None)],
    "background_facade": [dict(width=48, height=60)],
    "wall_grime": [dict(width=22, height=5), dict(width=6, height=4)],
}
BOTTLE_WORDS = ("bottle", "flask", "canister", "gascylinder", "jerrycan", "thermos")
# upright cylinders that are not bottles (pipes, posts, fittings...)
NOT_BOTTLE = ("pipe", "conduit", "stack", "mast", "baluster", "bar", "hinge", "handle", "collar", "clip", "clamp", "post",
              "rung", "leg", "stem", "flange", "cap", "hoop", "tank", "neck", "swan", "outlet", "coax", "cable", "lines",
              "chain", "rod", "rim", "reflector", "disc", "plate", "meter", "fan", "dish", "spot", "shoe", "roof", "wheel")


def bottle_like(D):
    bad = []
    for r in D.parts:
        name = D.names[r[16] - 1].lower()
        if any(w in name for w in BOTTLE_WORDS):
            bad.append(name)
            continue
        if r[0] != citykit.CYLINDER or any(w in name for w in NOT_BOTTLE):
            continue
        axis = yxz_matrix(r[4], r[5], r[6])[:, 0]
        if abs(axis[1]) > 0.8 and min(r[8], r[9]) < 0.8 and 1.6 < r[7] / min(r[8], r[9]) < 6:
            bad.append(name)
    return bad


def _faces(r):
    """[(normal, centre, half extents, in-plane axes)] of a row's flat faces: a block's six, a
    cylinder's two caps, a wedge's bottom, back and two ends (as rectangles: rough)."""
    R = yxz_matrix(r[4], r[5], r[6])
    h = np.array(r[7:10], float) / 2
    c = np.array(r[1:4], float)
    out = []
    for i in range(3):
        if r[0] == citykit.BALL or (r[0] == citykit.CYLINDER and i != 0):
            continue
        a, b = (i + 1) % 3, (i + 2) % 3
        for s in (-1, 1):
            if r[0] == citykit.WEDGE and (i, s) in ((1, 1), (2, -1)):
                continue  # (a wedge has no top face and no front face: its slope)
            out.append((s * R[:, i], c + s * h[i] * R[:, i], (h[a], h[b]), (R[:, a], R[:, b])))
    return out


def _inside(rows, p, skip):
    """Whether point p is inside an opaque block / cylinder row (other than those in skip)."""
    for k, r in enumerate(rows):
        if k in skip or r[12] > 0.05 or r[0] in (citykit.BALL, citykit.WEDGE):
            continue
        loc = yxz_matrix(r[4], r[5], r[6]).T @ (p - np.array(r[1:4], float))
        h = np.array(r[7:10], float) / 2
        if r[0] == citykit.CYLINDER:
            if abs(loc[0]) <= h[0] and loc[1] ** 2 + loc[2] ** 2 <= min(h[1], h[2]) ** 2:
                return True
        elif np.all(np.abs(loc) <= h):
            return True
    return False


def coplanar_pairs(rows):
    """[(i, j, gap)] of rows with same-facing parallel faces < 0.06 apart whose face boxes overlap
    (sampled: 2 of 9 points of one inside the other). Wedges count as their box (rough)."""
    F = [_faces(r) for r in rows]
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
                    if g >= 0.06:
                        continue
                    hits = 0  # (seen: a point just in front of both faces is not inside a third part)
                    front = max(0.0, (c2 - c1) @ n1) + 0.01
                    for u in (-0.8, 0, 0.8):
                        for v in (-0.8, 0, 0.8):
                            p = c2 + u * e2[0] * ax2[0] + v * e2[1] * ax2[1]
                            d = p - c1
                            if abs(d @ ax1[0]) < e1[0] * 0.98 and abs(d @ ax1[1]) < e1[1] * 0.98:
                                q = p - ((p - c1) @ n1) * n1 + front * n1
                                if not _inside(rows, q, (i, j)):
                                    hits += 1
                    if hits >= 2 and 4 * e2[0] * e2[1] * hits / 9 > 0.01 and (best is None or g < best):
                        best = g
            if best is not None:
                out.append((i, j, round(best, 4)))
    return out


def check(seeds=60, zseeds=4):
    lines, ok = [], True
    for name, fn in pw.WALL_PROPS.items():
        lo, hi, za, zb, bad = 10 ** 9, 0, 0, 0, set()
        for v in VARIANTS.get(name, [dict()]):
            for seed in range(seeds):
                D = Data()
                wall(D, -40, 40, 80, 0, 4)
                base = len(D.parts)
                n = fn(D, "T", o(0), 0, random.Random(seed), **v)
                assert n == len(D.parts) - base, (name, v, seed, n, len(D.parts) - base)
                lo, hi = min(lo, n), max(hi, n)
                bad.update(bottle_like(D))
                if seed < zseeds:
                    rows = [r for r in D.parts if r[12] < 1]  # (the wall too: it hides faces on it)
                    for _i, _j, g in coplanar_pairs(rows):
                        if _i == 0:
                            continue  # (the wall: an overlay is 0.055 off it by design)
                        if g < 0.02:
                            za += 1
                        else:
                            zb += 1
        ok &= not bad
        lines.append(f"{name:18s} {lo:3d}-{hi:3d} parts   own coplanar pairs ({zseeds} seeds x variants): a {za:3d}, "
                     f"b {zb:3d}" + (f"   BOTTLE-LIKE: {sorted(bad)}" if bad else ""))
    lines.append("ok: no bottle-like part" if ok else "FAILED: bottle-like parts")
    return lines


def main():
    if "--check" in sys.argv:
        for line in check():
            print(line, flush=True)
        return
    os.makedirs(OUT, exist_ok=True)
    for name, make in BOARDS.items():
        if ONLY and name not in ONLY:
            continue
        D, cams = make()
        t = time.time()
        paths = preview(D, cams, os.path.join(OUT, name), samples=SAMPLES)
        print(name, len(D.parts), "parts", paths, f"{time.time() - t:.0f}s", flush=True)
        if name in NIGHT and "--day" not in sys.argv:
            lights_out_of_bulbs(D)
            paths = preview(D, cams_at(NIGHT[name]), os.path.join(OUT, name + "_night"), night=True,
                            samples=SAMPLES * 2)
            print(name, "night", paths, flush=True)


if __name__ == "__main__":
    main()
