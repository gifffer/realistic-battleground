"""Yard and court props as kit meshes (tools/city/kit/pieces/yard.py), the fix wave after the
wave-1 review: the loading dock's cartons and pallet stack (Climb/C5 Crate x2, CrateStack, the
climb step) and its three rubber bumpers, the Cage's two basketball hoops, and the six
'DumpsterOld' dumpsters (Lot 9, the Cage, the Yard, Doyle's x2 and the C1 climb step).

The old parts are wrapped under each piece's MeshProp marker: PropKit keeps the colliding ones
(Crate, CrateStack, HoopBase, HoopPole, Dumpster, the shut Lid) as invisible proxies with the
same collision (the climb steps keep their exact tops: the meshes' tops are within 0.05) and
drops the decoration (bumpers, pads, rims, net sticks, bars, the bags under an open lid).
Without the kit, or when the city moved a part, the old parts stay as they are.
"""

import math

from meshprop import variation, weathered
from overlay.citydata import RY, SX, X, Y, Z, folder_of, name_of


def vr(*key):
    return variation("city_yard", *(round(k, 2) if isinstance(k, float) else k for k in key))


def _rows(O, folder, names, centre, radius):
    """Matches of the built rows of `folder` named in `names` within `radius` (x / z) of centre."""
    out = []
    for i, r in enumerate(O.data["parts"]):
        if i in O.skip or folder_of(O.data, r) != folder or name_of(O.data, r) not in names:
            continue
        if math.hypot(r[X] - centre[0], r[Z] - centre[1]) <= radius:
            out.append((O.match(folder, name_of(O.data, r), tuple(r[X:X + 3])), r))
    return out


def _color(O, r):
    return tuple(O.data["colors"][r[10] - 1])


# ---------------------------------------------------------------------------------- the dock
def dock(O):
    F = "Climb/C5"
    top = 4.6  # (the LoadingDock's top: 2.9 + 3.4 / 2)
    for k, (x, z) in enumerate(((84.5, 47.5), (87.5, 47.5))):
        m = O.match(F, "Crate", (x, 6.1, z))
        v = vr("crate", x, z)
        O.wrap([m], "CardboardBoxLarge" if k == 0 else "CardboardBoxLargeB", (x, top, z),
               ry=v.uniform(-4, 4) + v.choice((0, 90, 180, 270)), tint=weathered((176, 132, 82), v, 6, 0.08),
               name=f"crate_{x}_{z}")
    stack = O.match(F, "CrateStack", (103, 7.1, 47))
    O.wrap([stack], "PalletStackBoxes", (103, top, 47), ry=180, tint=(172, 128, 80), name="crate_stack")
    for x in (87, 95, 103):
        m = O.match(F, "Bumper", (x, 3.3, 49.3))
        v = vr("bumper", x)
        # (the piece's -Z out of the dock: the dock face looks +z)
        O.wrap([m], "DockBumper", (x, 3.3, 49.3), ry=180, tint=weathered((148, 124, 44), v, 8, 0.15),
               name=f"dock_bumper_{x}")


# ---------------------------------------------------------------------------------- the hoops
HOOP_PARTS = {"HoopBase", "HoopPole", "HoopPad", "HoopArm", "HoopBrace", "BoardMount", "Backboard", "BoardSquare",
              "RimBracket", "Rim", "HoopNet"}


def hoops(O):
    """The Cage's two hoops: the board 3.9 ahead of the pole (-x for the east one, +x west)."""
    F = "Zones/Cage"
    for px, face in ((-45.0, -1), (-109.0, 1)):
        group = _rows(O, F, HOOP_PARTS, (px + face * 3.0, 97.0), 4.6)
        pole = [r for m, r in group if name_of(O.data, r) == "HoopPole"]
        if len(pole) != 1:
            O.warn(f"yard: hoop at {px} has {len(pole)} poles")
            continue
        v = vr("hoop", px)
        ry = 90 if face < 0 else -90  # (the piece's -Z toward the board)
        O.wrap([m for m, r in group], "StreetHoop", (px, 1.2, 97.0), ry=ry,
               tint=weathered((52, 62, 58), v, 6, 0.1), name=f"hoop_{px}")


# ---------------------------------------------------------------------------------- dumpsters
DUMPSTERS = (("Climb/C1", (-105.0, -83.8)), ("Zones/Lot9", (63.35, -127.0)), ("Zones/Cage", (-37.8, 116.55)),
             ("Zones/Yard", (61.2, 23.45)), ("Zones/Doyle", (-86.55, 2.45)), ("Zones/Doyle", (-77.45, 30.2)))


def dumpsters(O):
    for folder, at in DUMPSTERS:
        group = _rows(O, folder, {"Dumpster", "Lid", "Bar", "Bag"}, at, 4.2)
        bodies = [r for m, r in group if name_of(O.data, r) == "Dumpster"]
        if len(bodies) != 1:
            O.warn(f"yard: dumpster at {at}: {len(bodies)} bodies")
            continue
        body = bodies[0]
        lids = [r for m, r in group if name_of(O.data, r) == "Lid"]
        piece = "DumpsterLarge" if len(lids) == 1 else "DumpsterLargeOpen"
        v = vr("dumpster", *at)
        ground = body[Y] - body[SX + 1] / 2
        O.wrap([m for m, r in group], piece, (body[X], round(ground, 3), body[Z]), ry=body[RY],
               tint=weathered(_color(O, body), v, 5, 0.1), name=f"dumpster_{at[0]}_{at[1]}")


def edits(O):
    dock(O)
    hoops(O)
    dumpsters(O)
