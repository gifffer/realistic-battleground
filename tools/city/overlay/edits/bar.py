"""Duffy's bar (Interiors/Duffys) as kit meshes (tools/city/kit/pieces/bar.py).

Every prop's old parts are wrapped under a MeshProp marker of its piece, placed exactly on the
old footprint (the pieces are built to the parts' heights: bar top 2.9, stool seat 2.255 = the
NPC SeatHeight, booth seat 1.5, pool cloth 2.7...). PropKit keeps what collides as invisible
KitProxy parts (BarCounter / BarTop, ShelfCollider, HighTables, Jukebox, CigaretteMachine: the
same collisions), hands the lights over to the meshes' Glow (ShelfGlow, the pendants, PoolLamp,
the jukebox's flickering CityNeon) and drops the pure decoration. Without the kit, or if the
city moved a part, the old parts stay.

    counter      BarCounter, BarTop, FootRail + brackets -> BarCounterModule (west) +
                 BarCounterModuleR (east: no fallback, it only shows with the kit)
    taps         x 51 -> BeerFont3, x 45 / 57 -> BeerFont2
    stools (6)   -> BarStoolPub / BarStoolPubTorn (2), own yaw, vinyl tint off the data's
    booths (4)   seat + back -> BoothSeatTufted, facing their table
    tables (2)   BoothTable + leg -> PubTable; TableLamp + base -> TableLampBrass;
                 CandleJar x3 -> CandleJar
    barrels (2)  HighTable + hoops -> BarrelTable (own yaw); Ashtray -> Ashtray
    pool         frame, felt, cushions, legs -> PoolTableBar; balls -> PoolBallSet; cues ->
                 PoolCue (leaning as before); PoolLamp + chains -> PoolLampBillard
    jukebox, cigarette machine, dartboard (+ rings), pendants (+ cords), the speakers' brackets,
    cones, tweeters and grilles (NOT the tagged Speaker box: the mesh's cabinet encloses it),
    the pint ledge (DrinkShelf + 6 glasses), the two photos
    back bar     ShelfCollider, ShelfEnds, Mirror, boards, ShelfGlow -> BackBarShelf
    48 "Bottle"  -> 12 DecoBottleRowA/B/C markers (4 each; DECORATION only: the player's one
                 allowed exception, on these shelves only; no tag, no prompt, never an item)

The NPC spots (Npcs), the PendantLight / RoomLight / WindowSpill / Sconce lights, the
SpezCola machine and the colliders that are not wrapped are not touched.
"""

import math

from meshprop import variation, weathered
from overlay.citydata import RX, SX, X, Y, Z
from overlay.core import DECOR

F = "Interiors/Duffys"
FLOOR = 1.9  # the bar's floor top
CEIL = 15.6  # the ceiling's underside

# The pieces' bounds (tools/city/kit/pieces/bar.py; the marker box = twice the extent from the
# pivot), until assets/cityprops/pieces.json has them.
EXTENT = {
    "Ashtray": ((-0.31, 0.0, -0.31), (0.31, 0.12, 0.31)),
    "BackBarShelf": ((-11.2, 0.0, -0.58), (11.0, 11.35, 0.41)),
    "BarCounterModule": ((-4.26, 0.0, -1.6), (4.297, 2.9, 1.21)),
    "BarCounterModuleR": ((-4.2, 0.0, -1.6), (4.26, 2.9, 1.21)),
    "BarStoolPub": ((-0.692, 0.0, -0.692), (0.692, 2.264, 0.692)),
    "BarStoolPubTorn": ((-0.692, 0.0, -0.718), (0.692, 2.302, 0.692)),
    "BarrelTable": ((-1.588, 0.0, -1.597), (1.588, 2.88, 1.597)),
    "BeerFont2": ((-0.65, 0.0, -0.67), (0.65, 2.06, 0.75)),
    "BeerFont3": ((-0.95, 0.0, -0.725), (0.95, 2.13, 0.75)),
    "BoothSeatTufted": ((-4.0, 0.0, -0.82), (4.0, 3.642, 0.8)),
    "CandleJar": ((-0.2, 0.0, -0.2), (0.2, 0.4, 0.2)),
    "CigaretteMachine": ((-1.5, 0.0, -1.52), (1.5, 5.3, 1.2)),
    "Dartboard": ((-1.566, -1.2, -1.1), (1.566, 1.2, 0.0)),
    "DecoBottleRowA": ((-1.025, 0.0, -0.263), (1.046, 1.515, 0.226)),
    "DecoBottleRowB": ((-1.054, 0.0, -0.197), (1.034, 1.607, 0.219)),
    "DecoBottleRowC": ((-1.015, 0.0, -0.241), (1.075, 1.607, 0.255)),
    "Jukebox": ((-1.55, 0.0, -1.0), (1.55, 6.55, 1.0)),
    "PendantLampPub": ((-0.61, -3.45, -0.61), (0.61, 0.0, 0.61)),
    "PendantLampPubDented": ((-0.61, -3.45, -0.61), (0.61, 0.0, 0.596)),
    "PictureFrame": ((-1.0, -1.2, -0.11), (1.0, 1.2, 0.0)),
    "PictureFrameB": ((-1.0, -1.2, -0.11), (1.0, 1.2, 0.0)),
    "PintGlassRow": ((-8.0, -0.9, -0.54), (8.0, 0.636, 0.0)),
    "PoolBallSet": ((-1.475, 0.0, -3.245), (1.511, 0.242, 3.125)),
    "PoolCue": ((-0.071, 0.0, -0.071), (0.071, 4.4, 0.071)),
    "PoolLampBillard": ((-0.61, -5.825, -2.7), (0.61, 0.0, 2.7)),
    "PoolTableBar": ((-2.045, 0.0, -3.76), (2.045, 2.82, 3.76)),
    "PubTable": ((-3.045, -0.01, -1.245), (3.045, 2.5, 1.245)),
    "TableLampBrass": ((-0.276, 0.0, -0.276), (0.276, 0.86, 0.276)),
    "WallSpeakerBracket": ((-0.74, -3.2, -1.852), (0.74, 1.178, 0.0)),
}


# The pieces' default tints (ctx.tint in pieces/bar.py: brass on MetalPainted until the kit has a
# Brass layer, the pool cloth, the lamps' green enamel, the jukebox's cream plastic...), written
# on the marker when the copy has no tint of its own (pieces.json does not have them yet).
BRASS = (150, 118, 62)
TINT = {
    "BarCounterModule": BRASS, "BarCounterModuleR": BRASS, "PubTable": BRASS, "TableLampBrass": BRASS,
    "BackBarShelf": BRASS, "PoolTableBar": (36, 80, 52), "PoolLampBillard": (34, 70, 46),
    "PendantLampPub": (36, 66, 46), "PendantLampPubDented": (36, 66, 46), "Jukebox": (226, 206, 160),
    "CigaretteMachine": (82, 64, 46), "Dartboard": (40, 90, 160), "BarStoolPub": (70, 24, 24),
    "BarStoolPubTorn": (70, 24, 24), "BoothSeatTufted": (70, 24, 24),
}


def msize(piece, scale=1.0):
    lo, hi = EXTENT[piece]
    return tuple(max(abs(lo[i]), abs(hi[i])) * 2 * scale for i in range(3))


def vr(*key):
    return variation("city_bar", *(round(k, 2) if isinstance(k, float) else k for k in key))


def wrap(O, matches, piece, at, ry=0.0, rx=0.0, rz=0.0, tint=None, name=None):
    return O.wrap(matches, piece, at, ry=ry, rx=rx, rz=rz, tint=tint or TINT.get(piece), size=msize(piece), name=name)


def bare(O, piece, at, ry=0.0, tint=None):
    """A marker with no fallback parts (it only shows with the kit), like reuse.bare_at."""
    attrs = {"Piece": piece}
    tint = tint or TINT.get(piece)
    if tint is not None:
        attrs["Tint"] = ",".join(str(int(round(c))) for c in tint)
    return O.add(F, "MeshProp", at, msize(piece), (128, 128, 128), "SmoothPlastic", rot=(0, ry, 0),
                 transparency=1.0, flags=DECOR, extra={"a": attrs})


def m(O, name, at, folder=F):
    return O.match(folder, name, at)


def colour(O, mt):
    r = O.row(mt)
    return tuple(O.data["colors"][r[10] - 1]) if r is not None else (70, 24, 24)


# ---------------------------------------------------------------------------------- the bar
def counter(O):
    parts = [m(O, "BarCounter", (50.6, 3.15, 11.8)), m(O, "BarTop", (50.6, 4.6, 11.6)),
             m(O, "FootRail", (50.6, 2.48, 10.32))]
    parts += [m(O, "FootRailBracket", (x, 2.48, 10.5)) for x in (44.0, 50.6, 57.2)]
    with O.entry("bar_counter"):
        wrap(O, parts, "BarCounterModule", (46.4, FLOOR, 11.8), name="bar_counter_west")
        bare(O, "BarCounterModuleR", (54.8, FLOOR, 11.8))
    for x, piece in ((45.0, "BeerFont2"), (51.0, "BeerFont3"), (57.0, "BeerFont2")):
        v = vr("font", x)
        wrap(O, [m(O, "Tap", (x, 5.5, 12.15)), m(O, "TapHandle", (x, 6.55, 12.15)), m(O, "TapSpout", (x, 5.62, 11.88))],
             piece, (x, 4.8, 12.15), ry=v.uniform(-3, 3), name=f"bar_font_{int(x)}")


def back_bar(O):
    parts = [m(O, "ShelfCollider", (52, 7.55, 19.4)), m(O, "ShelfEnd", (62, 7.55, 19.4)), m(O, "ShelfEnd", (40.9, 7.55, 19.35)),
             m(O, "Mirror", (51, 10.8, 19.73)), m(O, "ShelfGlow", (51, 5.95, 19.75))]
    parts += [m(O, "ShelfBoard", (51, y, 19.4)) for y in (6.28, 8.68, 11.07)]
    wrap(O, parts, "BackBarShelf", (52.0, FLOOR, 19.4), name="bar_back_bar")


def deco_rows(O):
    """The 48 decorative Bottle parts, by board and group of four, under 12 row markers (pure
    decoration, the player's one exception: see the module docstring)."""
    bottles = O.box(F, "Bottle")
    boards = {}
    for b in bottles:
        r = O.row(b)
        top = min((6.355, 8.755, 11.145), key=lambda t: abs((r[Y] - r[SX] / 2) - t))
        boards.setdefault(top, []).append(b)
    n = 0
    for top in sorted(boards):
        row = sorted(boards[top], key=lambda b: O.row(b)[X])
        groups = []
        for b in row:
            if groups and O.row(b)[X] - O.row(groups[-1][-1])[X] < 1.0:
                groups[-1].append(b)
            else:
                groups.append([b])
        for g in groups:
            cx = sum(O.row(b)[X] for b in g) / len(g)
            piece = "DecoBottleRow" + "ABC"[n % 3]
            v = vr("deco", round(cx, 2), top)
            wrap(O, g, piece, (round(cx, 3), top, 19.3), ry=180.0 if v.random() < 0.4 else 0.0, name=f"bar_deco_{n}")
            n += 1
    if n != 12:
        O.error(f"bar: {n} bottle groups (expected 12)")


def stools(O):
    torn = {46.8, 58.0}
    for x in (44.0, 46.8, 49.6, 52.4, 55.2, 58.0):
        v = vr("stool", x)
        seat = m(O, "StoolSeat", (x, 3.98, 8.8))
        tint = weathered(colour(O, seat), v, 8, 0.15)
        piece = "BarStoolPubTorn" if x in torn else "BarStoolPub"
        wrap(O, [m(O, "StoolBase", (x, 1.98, 8.8)), m(O, "StoolPole", (x, 2.92, 8.8)), seat], piece, (x, FLOOR, 8.8),
             ry=v.uniform(0, 360), tint=tint, name=f"bar_stool_{x}")


def booths(O):
    for zt in (-1.5, 16.3):
        for zs, zb, ry in ((zt - 2.7, zt - 3.25, 180.0), (zt + 2.7, zt + 3.25, 0.0)):
            v = vr("booth", zs)
            seat = m(O, "BoothSeat", (32.2, 2.65, zs))
            tint = weathered(colour(O, seat), v, 6, 0.1)
            wrap(O, [seat, m(O, "BoothBack", (32.2, 4.4, zb))], "BoothSeatTufted", (32.2, FLOOR, zs), ry=ry, tint=tint,
                 name=f"bar_booth_{zs}")
        wrap(O, [m(O, "BoothTable", (32.2, 4.25, zt)), m(O, "TableLeg", (32.2, 3.0, zt))], "PubTable", (32.2, FLOOR, zt),
             name=f"bar_table_{zt}")
        wrap(O, [m(O, "TableLamp", (30.2, 5.05, zt)), m(O, "LampBase", (30.2, 4.61, zt))], "TableLampBrass", (30.2, 4.4, zt),
             ry=vr("lamp", zt).uniform(0, 360), name=f"bar_lamp_{zt}")
        wrap(O, [m(O, "CandleJar", (34.0, 4.6, zt))], "CandleJar", (34.0, 4.4, zt), name=f"bar_candle_{zt}")
    wrap(O, [m(O, "CandleJar", (55.0, 5.0, 11.6))], "CandleJar", (55.0, 4.8, 11.6), name="bar_candle_counter")


def barrels(O):
    for x, z in ((45.0, -7.0), (53.0, -1.0)):
        v = vr("barrel", x)
        parts = [m(O, "HighTable", (x, 3.35, z)), m(O, "BarrelHoop", (x, 2.6, z)), m(O, "BarrelHoop", (x, 4.3, z))]
        wrap(O, parts, "BarrelTable", (x, FLOOR, z), ry=v.uniform(0, 360), name=f"bar_barrel_{x}")
        wrap(O, [m(O, "Ashtray", (x + 0.6, 4.88, z))], "Ashtray", (x + 0.6, 4.8, z), ry=v.uniform(0, 360), name=f"bar_ashtray_{x}")


def pool(O):
    parts = [m(O, "PoolTableFrame", (73, 4.15, -5.3)), m(O, "Felt", (73, 4.55, -5.3))]
    parts += [m(O, "Cushion", at) for at in ((73, 4.6, -8.8), (73, 4.6, -1.8), (71.2, 4.6, -5.3), (74.8, 4.6, -5.3))]
    parts += [m(O, "TableLeg", (x, 2.85, z)) for x in (71.6, 74.4) for z in (-8.4, -2.2)]
    wrap(O, parts, "PoolTableBar", (73.0, FLOOR, -5.3), name="bar_pool_table")
    balls = O.box(F, "PoolBall", lo=(70, 4, -9), hi=(76, 6, -1))
    wrap(O, balls, "PoolBallSet", (73.0, 4.6, -5.3), ry=180.0, name="bar_pool_balls")
    for z in (4.0, 5.4):
        cue = m(O, "Cue", (81.45, 4.1, z))
        r = O.row(cue)
        a = math.radians(r[RX + 2]) if r is not None else math.radians(-6)
        half = (r[SX + 1] if r is not None else 4.4) / 2
        # (the cue's butt end: the box's centre minus half its length along its turned +Y)
        bx, by = 81.45 + math.sin(a) * half, 4.1 - math.cos(a) * half
        wrap(O, [cue], "PoolCue", (round(bx, 3), round(by, 3), z), rz=math.degrees(a), ry=0.0,
             name=f"bar_cue_{z}")
    wrap(O, [m(O, "PoolLamp", (73, 10.2, -5.3)), m(O, "Chain", (73, 13, -7.3)), m(O, "Chain", (73, 13, -3.3))],
         "PoolLampBillard", (73.0, CEIL, -5.3), name="bar_pool_lamp")


def machines(O):
    wrap(O, [m(O, "Jukebox", (61.9, 4.4, -14.3)), m(O, "JukeboxArch", (61.95, 6.9, -14.3)),
             m(O, "JukeboxFront", (60.85, 4.2, -14.3))], "Jukebox", (61.9, FLOOR, -14.3), ry=90.0, name="bar_jukebox")
    wrap(O, [m(O, "CigaretteMachine", (80.6, 4.55, 12.5)), m(O, "MachineFront", (79.35, 5.4, 12.5))],
         "CigaretteMachine", (80.6, FLOOR, 12.5), ry=90.0, tint=(82, 64, 46), name="bar_cigarettes")
    # (the two DartRings are 0.04 apart: a match cannot tell them apart, so they stay where they
    # are, inside the mesh's board, whose face is 0.01 in front of the front one)
    wrap(O, [m(O, "Dartboard", (62.9, 7.2, -2.0))], "Dartboard", (63.0, 7.2, -2.0), ry=90.0, name="bar_dartboard")


def lights_and_walls(O):
    for x in (45.0, 51.0, 57.0):
        v = vr("pendant", x)
        piece = "PendantLampPubDented" if x == 57.0 else "PendantLampPub"
        wrap(O, [m(O, "Pendant", (x, 12.2, 11.8)), m(O, "Cord", (x, 14.07, 11.8))], piece, (x, CEIL, 11.8),
             ry=v.uniform(0, 360), name=f"bar_pendant_{x}")
    # speakers: (cabinet centre, wall face origin, yaw); the tagged Speaker box itself stays
    for (sx, sy, sz), origin, ry in (((38.6, 11.8, 18.8), (38.6, 11.8, 19.8), 0.0),
                                     ((62.0, 11.6, -10.5), (63.0, 11.6, -10.5), 90.0),
                                     ((65.3, 11.6, 15.5), (64.3, 11.6, 15.5), -90.0)):
        near = [p for p in O.box(F, {"SpeakerBracket", "SpeakerCone", "SpeakerTweeter", "SpeakerGrille"},
                                 lo=(sx - 1.2, sy - 1.5, sz - 1.2), hi=(sx + 1.2, sy + 1.5, sz + 1.2))]
        if len(near) != 4:
            O.error(f"bar: speaker at {(sx, sy, sz)} has {len(near)} parts")
            continue
        wrap(O, near, "WallSpeakerBracket", origin, ry=ry, name=f"bar_speaker_{sx}")
    glasses = O.box(F, "Glass", lo=(81, 5.5, -14), hi=(82, 7, 3))
    wrap(O, [m(O, "DrinkShelf", (81.5, 5.7, -5.0))] + glasses, "PintGlassRow", (81.8, 5.8, -5.0), ry=90.0,
         name="bar_pint_ledge")
    for x, y, piece in ((32.0, 8.2, "PictureFrame"), (36.0, 8.6, "PictureFrameB")):
        v = vr("photo", x)
        wrap(O, [m(O, "Photo", (x, y, 19.75)), m(O, "PhotoPrint", (x, y, 19.67))], piece, (x, y, 19.8),
             rz=v.uniform(-2.5, 2.5), name=f"bar_photo_{x}")


def edits(O):
    counter(O)
    back_bar(O)
    deco_rows(O)
    stools(O)
    booths(O)
    barrels(O)
    pool(O)
    machines(O)
    lights_and_walls(O)


# (kept for the numeric check: Z is imported for readers of the rows)
_ = Z
