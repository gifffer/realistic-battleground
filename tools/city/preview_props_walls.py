"""Catalogue of props_walls: lays every wall / facade prop out on test walls (several
variants each) and renders the boards with citykit.preview (Cycles CPU), day and night.

    venv/bin/python -I tools/city/preview_props_walls.py [out_dir] [board ...]

Boards: surfaces, openings, services, structure. Look at the PNGs.
"""

import os
import random
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import props_walls as pw  # noqa: E402
import numpy as np  # noqa: E402
from citykit import SOLID, Data, preview, yxz_matrix  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "_preview")
ONLY = set(sys.argv[2:])
F = "Preview/Props"


def wall(D, x0, x1, top, z0=0.0, z1=1.0, color=(84, 60, 50)):
    D.box("Preview/Wall", "Wall", x0, x1, 0, top, z0, z1, color, "Brick", flags=SOLID)


def floor(D, x0, x1, z0, z1):
    D.box("Preview/Wall", "Floor", x0, x1, -0.2, 0, z0, z1, (46, 47, 50), "Asphalt", flags=SOLID)


def board_surfaces():
    D, r = Data(), random.Random(11)
    floor(D, -22, 22, -16, 1)
    wall(D, -20, 20, 14)
    o = lambda x: (x, 0, 0)  # noqa: E731
    pw.wall_grime(D, F, o(-10), 0, r, width=20, height=4.5)
    pw.wall_grime(D, F, o(10), 0, r, width=20, height=3.5)
    pw.plaster_patch(D, F, o(-15), 0, r, width=6, height=5, y=3)
    pw.plaster_patch(D, F, o(13), 0, r, width=7, height=6, y=6.5)
    pw.crack(D, F, o(-15), 0, r, length=5, y=8)
    pw.crack(D, F, o(4), 0, r, length=4, y=1)
    pw.rust_streak(D, F, o(-8), 0, r, y=11, length=5)
    pw.rust_streak(D, F, o(-6.8), 0, r, y=11.2, length=3.5, width=0.4)
    pw.efflorescence(D, F, o(-1), 0, r, width=5, y=0.3)
    pw.efflorescence(D, F, o(17), 0, r, width=3.5, y=0.5)
    pw.torn_posters(D, F, o(-7), 0, r, width=3.6, height=4.2, y=3.2)
    pw.torn_posters(D, F, o(-2.5), 0, r, width=3.0, height=3.6, y=3.6, text="MISSING")
    pw.painted_sign(D, F, o(-4), 0, r, width=12, height=2.6, y=10.4)
    pw.graffiti_tag(D, F, o(6.5), 0, r, width=5, height=1.8, y=3.5, buffed=True)
    pw.graffiti_tag(D, F, o(8), 0, r, width=6, height=2.2, y=7, text="MARROW EATS ITS OWN", color=(170, 60, 50))
    cams = [((0, 8, -30), (0, 6.5, 0), 62), ((-14, 6, -14), (-8, 6, 0), 60), ((12, 6, -14), (8, 5.5, 0), 62)]
    return D, cams


def board_openings():
    D, r = Data(), random.Random(23)
    floor(D, -26, 26, -18, 1)
    wall(D, -24, 24, 19)
    o = lambda x: (x, 0, 0)  # noqa: E731
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
    return D, cams


def board_services():
    D, r = Data(), random.Random(37)
    floor(D, -22, 22, -16, 1)
    wall(D, -20, 20, 18)
    wall(D, -20, 20, 18, -15, -14, (96, 64, 52))  # the opposite wall (for the cables)
    o = lambda x: (x, 0, 0)  # noqa: E731
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
    pw.bulkhead_light(D, F, (0, 0, -14), 180, r, y=8)
    cams = [((0, 8, -13), (0, 8, 0), 90), ((-12, 6, -8), (-11, 7, 0), 70), ((8, 5, -7), (6, 8, 0), 75)]
    return D, cams


def board_structure():
    D, r = Data(), random.Random(53)
    floor(D, -40, 40, -40, 20)
    wall(D, -16, 16, 30, 0, 4)
    o = lambda x: (x, 0, 0)  # noqa: E731
    pw.wall_grime(D, F, o(0), 0, r, width=32, height=5)
    pw.fire_escape(D, F, o(-3), 0, r, width=12, floors=3, floor_h=10)
    for x, y, v in ((-3, 12, "dirty"), (-3, 21.5, "lit"), (9, 12, "barred"), (9, 21.5, "boarded"), (-12, 21.5, "broken"),
                    (-12, 12, "lit")):
        pw.window(D, F, o(x), 0, r, variant=v, y=y, height=4.8)
    pw.back_door(D, F, o(9), 0, r)
    pw.building_top(D, F, o(0), 0, r, width=32, top=30, depth=4, clutter="tank")
    pw.chainlink_fence(D, F, (-26, 0, -8), 90, r, width=15, height=8)
    pw.chainlink_fence(D, F, (24, 0, -6), -80, r, width=10, height=7, barbed=False)
    # background buildings beyond
    pw.background_facade(D, F, (-30, 0, 30), 0, r, width=36, height=70)
    pw.background_facade(D, F, (14, 0, 40), -8, r, width=44, height=90)
    pw.background_facade(D, F, (52, 0, 20), -25, r, width=30, height=55)
    cams = [((-6, 6, -48), (0, 24, 0), 70), ((-14, 22, -14), (-3, 18, 0), 70), ((5, 33, -12), (2, 30, 3), 70)]
    return D, cams


BOARDS = {"surfaces": board_surfaces, "openings": board_openings, "services": board_services,
          "structure": board_structure}
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


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, make in BOARDS.items():
        if ONLY and name not in ONLY:
            continue
        D, cams = make()
        t = time.time()
        paths = preview(D, cams, os.path.join(OUT, name), samples=20)
        print(name, len(D.parts), "parts", paths, f"{time.time() - t:.0f}s", flush=True)
        if name in NIGHT:
            lights_out_of_bulbs(D)
            paths = preview(D, NIGHT[name], os.path.join(OUT, name + "_night"), night=True, samples=32)
            print(name, "night", paths, flush=True)


if __name__ == "__main__":
    main()
