"""The two shops' furniture as kit meshes (tools/city/kit/pieces/shops.py): REWIND (Interiors/
Rewind, the video and record store) and HOLLOW THREADS (Interiors/Threadbare, the clothes shop).

Every prop's old parts are wrapped under a MeshProp marker of its piece, placed on the old
footprint (the pieces are built to the parts' sizes: record bin 6 x 3 x 3, tape shelf 16 x 10.3,
counter top at 4.8, mannequin 5.45 on its plinth, display table 6 x 3 x 3...). PropKit keeps
what collides as invisible KitProxy parts (RecordBin, ShelfCollider x 2, Arcade, DisplayTable:
the same collisions) and drops the pure decoration. Without the kit, or if the city moved a
part, the old parts stay.

    REWIND   record bins (3: crate, cabinet, plinth, dividers, tabs, 48 sleeves each) ->
             RecordBinCrate / RecordBinCrateB; portable TVs (4) -> CrtTvPortable(B); counter:
             Register -> CashRegisterOld, Turntable + Record -> Turntable, VHSStack x 3 ->
             VhsStack; tape shelf (sides, boards, top, 40 Tapes) -> VhsShelfStocked; stage: floor
             speakers (2) -> PaSpeakerFloor / PaSpeakerFloorWorn, mic -> MicStand, MirrorBall +
             Chain -> MirrorBall; Arcade -> ArcadeCabinet (its lit ArcadeScreen laid on the mesh's glass)
    THREADS  mannequins (4 Models) -> MannequinDisplay(B) + MannequinTop(B) + MannequinLegs(B)
             (three markers INSIDE the Model: ShopFrontController paints the cloned layers by
             name, "MannequinTop_Fabric" = Top, "MannequinLegs_Fabric" = Trousers, exactly like
             the old Torso / Leg parts); shelf wall (collider, end, sides, boards, top) ->
             ShopShelfWall; folded tees (12) -> FoldedTeeStack(Short); sneakers (8) ->
             SneakerPair(High); display table -> DisplayTableWood, its 6 stacks ->
             FoldedTeeStackLow; Till + TillDisplay -> CashRegisterModern; the fitting room's
             curtains -> CurtainDrawn(B), its mirror -> StandingMirror; 4 face-out garments on
             pegboard hooks (no fallback: they only show with the kit)

NOT touched: the ShopCounters (prompts), the neons (CounterNeon, NewReleasesNeon, OpenNeon,
DanceTiles), the lights (CRTGlow, StageSpot, CounterLight, Tubes, RoomLight, WindowSpill,
FittingLamp, EmergencyLight), the posters and the sale sign (SurfaceGui text), the tagged wall
Speakers and their brackets, the stage, the plinths, the fitting walls, the curtain rail, the
CRT wall (edits/reuse.py) and the clothes rail (edits/reuse.py), the NPC spots.
"""

import math

from meshprop import variation, weathered
from overlay.citydata import RY, X, Y, Z
from overlay.core import DECOR

RW = "Interiors/Rewind"
TB = "Interiors/Threadbare"
FLOOR = 1.9  # both shops' floor top
COUNTER = 4.8  # both counters' top

# The pieces' bounds (tools/city/kit/pieces/shops.py; the marker box = twice the extent from the
# pivot), until assets/cityprops/pieces.json has them.
EXTENT = {
    "ArcadeCabinet": ((-1.19, 0.006, -1.207), (1.19, 5.988, 1.19)),
    "CashRegisterModern": ((-0.98, 0.012, -0.821), (0.98, 1.489, 0.865)),
    "CashRegisterOld": ((-0.98, 0.012, -0.825), (0.98, 1.66, 0.78)),
    "CrtTvPortable": ((-0.773, 0.012, -0.667), (0.707, 1.661, 0.6)),
    "CrtTvPortableB": ((-0.734, 0.012, -0.667), (0.707, 1.54, 0.6)),
    "CurtainDrawn": ((-2.621, -8.16, -0.207), (2.621, 0.212, 0.207)),
    "CurtainDrawnB": ((-2.021, -8.1, -0.209), (2.021, 0.212, 0.231)),
    "DisplayTableWood": ((-3.017, 0.012, -1.485), (3.013, 3.009, 1.485)),
    "FoldedTeeStack": ((-1.101, 0.012, -0.61), (1.067, 1.357, 0.59)),
    "FoldedTeeStackLow": ((-0.822, 0.012, -0.629), (0.769, 1.166, 0.607)),
    "FoldedTeeStackShort": ((-1.042, 0.012, -0.572), (1.066, 0.847, 0.594)),
    "HoodieOnHanger": ((-0.982, -2.45, -0.308), (0.972, 0.11, 0.304)),
    "MannequinDisplay": ((-0.854, 0.012, -0.8), (0.854, 5.429, 0.8)),
    "MannequinDisplayB": ((-0.864, 0.012, -0.8), (1.105, 5.428, 0.8)),
    "MannequinLegs": ((-0.61, 0.5, -0.36), (0.61, 3.44, 0.42)),
    "MannequinLegsB": ((-0.61, 0.498, -0.36), (0.61, 3.44, 0.42)),
    "MannequinTop": ((-0.907, 2.659, -0.447), (0.91, 4.59, 0.494)),
    "MannequinTopB": ((-0.924, 2.662, -0.44), (1.148, 4.59, 0.5)),
    "MicStand": ((-0.42, 0.001, -0.534), (1.401, 4.306, 0.42)),
    "MirrorBall": ((-0.691, -2.592, -0.691), (0.692, 0.0, 0.692)),
    "PaSpeakerFloor": ((-1.057, 0.002, -0.975), (1.057, 3.924, 1.444)),
    "PaSpeakerFloorWorn": ((-1.057, 0.002, -0.975), (1.057, 3.949, 1.444)),
    "PegboardHook": ((-0.05, -0.13, -0.54), (0.05, 0.13, 0.0)),
    "RecordBinCrate": ((-2.94, 0.012, -1.49), (2.94, 3.15, 1.455)),
    "RecordBinCrateB": ((-2.94, 0.012, -1.784), (2.94, 3.15, 1.455)),
    "ShirtOnHanger": ((-0.947, -2.25, -0.215), (0.949, 0.11, 0.189)),
    "ShopShelfWall": ((-10.4, 0.012, -0.86), (10.4, 9.3, 0.69)),
    "SneakerPair": ((-0.505, 0.012, -0.58), (0.478, 0.517, 0.599)),
    "SneakerPairHigh": ((-0.511, 0.012, -0.58), (0.486, 0.764, 0.595)),
    "StandingMirror": ((-1.7, -0.015, -0.84), (1.7, 7.393, -0.068)),
    "Turntable": ((-1.0, 0.012, -0.78), (1.0, 0.57, 0.86)),
    "VhsShelfStocked": ((-8.0, 0.012, -0.69), (8.0, 10.305, 0.68)),
    "VhsStack": ((-0.497, 0.0, -0.396), (0.555, 0.783, 0.351)),
}

# The pieces' default tints (ctx.tint in pieces/shops.py), written on the marker when the copy
# has no tint of its own (pieces.json does not have them yet).
BRASS = (150, 118, 62)
TINT = {
    "ArcadeCabinet": (36, 40, 80), "CashRegisterOld": (178, 166, 136), "CrtTvPortable": (210, 202, 186),
    "CrtTvPortableB": (46, 46, 48), "CurtainDrawn": (110, 40, 40), "CurtainDrawnB": (110, 40, 40),
    "FoldedTeeStack": (120, 118, 112), "FoldedTeeStackLow": (120, 118, 112), "FoldedTeeStackShort": (120, 118, 112),
    "HoodieOnHanger": (58, 62, 54), "MannequinDisplay": (206, 202, 194), "MannequinDisplayB": (206, 202, 194),
    "MannequinLegs": (40, 44, 58), "MannequinLegsB": (40, 44, 58), "MannequinTop": (60, 60, 64),
    "MannequinTopB": (60, 60, 64), "PaSpeakerFloor": (34, 34, 36), "PaSpeakerFloorWorn": (34, 34, 36),
    "ShirtOnHanger": (128, 44, 40), "ShopShelfWall": BRASS, "SneakerPair": (140, 60, 50),
    "SneakerPairHigh": (140, 60, 50), "StandingMirror": (150, 120, 64),
}

# Every placed marker (piece, origin, ry, wrapped Matches): for the proxy-vs-mesh check
# (tools: the numeric check in the module's __main__ is run by hand, see the bottom).
PLACED = []


def msize(piece):
    lo, hi = EXTENT[piece]
    return tuple(max(abs(lo[i]), abs(hi[i])) * 2 for i in range(3))


def vr(*key):
    return variation("city_shops", *(round(k, 2) if isinstance(k, float) else k for k in key))


def wrap(O, matches, piece, at, ry=0.0, tint=None, name=None, force=None):
    PLACED.append((piece, at, ry, list(matches)))
    return O.wrap(matches, piece, at, ry=ry, tint=tint or TINT.get(piece), size=msize(piece), name=name, force=force)


def bare(O, folder, piece, at, ry=0.0, tint=None):
    """A marker with no fallback parts (it only shows with the kit), like bar.bare."""
    PLACED.append((piece, at, ry, []))
    attrs = {"Piece": piece}
    tint = tint or TINT.get(piece)
    if tint is not None:
        attrs["Tint"] = ",".join(str(int(round(c))) for c in tint)
    return O.add(folder, "MeshProp", at, msize(piece), (128, 128, 128), "SmoothPlastic", rot=(0, ry, 0),
                 transparency=1.0, flags=DECOR, extra={"a": attrs})


def m(O, folder, name, at):
    return O.match(folder, name, at)


def colour(O, mt, default=(120, 118, 112)):
    r = O.row(mt)
    return tuple(O.data["colors"][r[10] - 1]) if r is not None else default


def yaw(O, mt):
    r = O.row(mt)
    return r[RY] if r is not None else 0.0


# ---------------------------------------------------------------------------------- REWIND
def record_bins(O):
    """The three browser bins (67 parts each) -> the bin mesh; the middle one has the overstock
    boxes underneath. RecordBin (the invisible collider) stays as the proxy."""
    for k, z in enumerate((-6.5, 2.5, 11.5)):
        parts = O.box(RW, None, lo=(-50.8, 1.85, z - 1.6), hi=(-44.4, 5.0, z + 1.6))
        if len(parts) != 67:
            O.error(f"shops: record bin at z {z} has {len(parts)} parts (expected 67)")
            continue
        col = next(p for p in parts if p.name == "RecordBin")
        parts.remove(col)
        piece = "RecordBinCrateB" if k == 1 else "RecordBinCrate"
        wrap(O, [col] + parts, piece, (-47.6, FLOOR, z), name=f"rewind_bin_{k}")


def portable_tvs(O):
    """The four portable TVs on top of the CRT wall, screens to the shop (alternately cream and
    black, a little turned)."""
    for k, z in enumerate((-5.0, 1.0, 7.0, 11.0)):
        v = vr("ptv", z)
        piece = "CrtTvPortable" if k % 2 == 0 else "CrtTvPortableB"
        tint = weathered(TINT[piece], v, 6, 0.1)
        wrap(O, [m(O, RW, "PortableTV", (-57.7, 10.7, z))], piece, (-57.7, 10.2, z + v.uniform(-0.1, 0.1)),
             ry=-90.0 + v.uniform(-8, 8), tint=tint, name=f"rewind_ptv_{k}")


def counter(O):
    """Behind the till: the register and the turntable face the clerk (+Z), the tapes lie
    crooked. The ShopCounter, its top and its neon are not touched."""
    wrap(O, [m(O, RW, "Register", (-50, 5.5, 20.2))], "CashRegisterOld", (-50.0, COUNTER, 20.2),
         ry=180.0 + vr("reg").uniform(-6, 6), name="rewind_register")
    wrap(O, [m(O, RW, "Turntable", (-45, 5, 20.2)), m(O, RW, "Record", (-45, 5.23, 20.2))], "Turntable",
         (-45.0, COUNTER, 20.2), ry=180.0 + vr("tt").uniform(-4, 4), name="rewind_turntable")
    tapes = [m(O, RW, "VHSStack", (-42.1, y, 20)) for y in (4.95, 5.25, 5.55)]
    wrap(O, tapes, "VhsStack", (-42.1, COUNTER, 20.0), ry=vr("vhs").uniform(0, 360), name="rewind_vhs")


def tape_shelf(O):
    """The VHS wall bay (sides, boards, top, 40 Tapes) -> the stocked shelf mesh, its front to
    the shop. ShelfCollider stays as the proxy; the NewReleasesNeon (CityNeon) stays a part."""
    parts = [m(O, RW, "ShelfCollider", (-45, 7.05, 28.3)), m(O, RW, "ShelfSide", (-52.85, 7.05, 28.3)),
             m(O, RW, "ShelfSide", (-37.15, 7.05, 28.3)), m(O, RW, "ShelfTop", (-45, 11.925, 28.3))]
    parts += [m(O, RW, "ShelfBoard", (-45, y, 28.3)) for y in (1.975, 4.575, 7.175, 9.775)]
    tapes = O.box(RW, "Tapes", lo=(-53, 2, 27.5), hi=(-37, 11, 29))
    if len(tapes) != 40:
        O.error(f"shops: {len(tapes)} Tapes on the shelf (expected 40)")
        return
    wrap(O, parts + tapes, "VhsShelfStocked", (-45.0, FLOOR, 28.3), name="rewind_tape_shelf")


def stage(O):
    """The dance stage: the two floor PA cabinets (pointing at the dance floor, west; their backs
    0.1 off the stage's side), the mic stand on the tiles, the mirror ball from the ceiling."""
    for k, z in enumerate((-2.0, 8.0)):
        v = vr("pa", z)
        piece = "PaSpeakerFloorWorn" if k == 1 else "PaSpeakerFloor"
        wrap(O, [m(O, RW, "Speaker", (-39.6, 3.9, z))], piece, (-39.56, FLOOR, z), ry=90.0 + v.uniform(-6, 6),
             name=f"rewind_pa_{k}")
    wrap(O, [m(O, RW, "MicStand", (-36.525, 5.24, 2.975)), m(O, RW, "MicBase", (-36.525, 3.24, 2.975)),
             m(O, RW, "Mic", (-36.525, 7.32, 2.975))], "MicStand", (-36.525, 3.2, 2.975), ry=-90.0 + vr("mic").uniform(-20, 20),
         name="rewind_mic")
    wrap(O, [m(O, RW, "MirrorBall", (-33.4, 13.7, 3)), m(O, RW, "Chain", (-33.4, 15, 3))], "MirrorBall",
         (-33.4, 15.6, 3.0), ry=vr("ball").uniform(0, 360), name="rewind_mirror_ball")


def arcade(O):
    """The upright arcade cabinet against the west wall, screen to the shop (+X). The Arcade box
    (it collides) stays as the proxy. The lit ArcadeScreen (Neon) stays a part: it is laid on the
    mesh's monitor glass (pieces/shops.py ARC_SCREEN: the glass's slope, its crown 0.03 proud),
    0.01 in front of the crown, tilted back with it, so the game still glows at night."""
    x0, ry = -57.79, -90.0
    with O.entry("rewind_arcade"):
        wrap(O, [m(O, RW, "Arcade", (-57.8, 4.9, -14.6))], "ArcadeCabinet", (x0, FLOOR, -14.6), ry=ry)
        (zt, yt), (zb, yb) = ((-0.43, 5.0), (-0.8, 3.72))
        ang = math.atan2(zt - zb, yt - yb)
        # (piece space: the slope's middle, then 0.05 out of it along the glass's normal)
        py = (yt + yb) / 2 + 0.05 * math.sin(ang)
        pz = (zt + zb) / 2 - 0.05 * math.cos(ang)
        # (ry -90: piece -Z = world +X)
        O.set(m(O, RW, "ArcadeScreen", (-56.55, 5.6, -14.6)), pos=(round(x0 - pz, 3), round(FLOOR + py, 3), -14.6),
              rot=(0, 0, round(math.degrees(ang), 2)), size=(0.02, 1.0, 1.3))


# ---------------------------------------------------------------------------------- THREADS
MANNEQUINS = (  # (folder suffix, base centre, pose)
    ("OutfitBlack", (-37.0, -73.6), ""),
    ("OutfitBlood", (-32.0, -73.6), "B"),
    ("OutfitOlive", (-29.4, -81.0), ""),
    ("OutfitGrey", (-29.7, -76.6), "B"),
)
MQ_NAMES = ("MannequinBase", "MannequinPole", "MannequinTorso", "MannequinHead", "MannequinRightArm",
            "MannequinRightHand", "MannequinRightLeg", "MannequinLeftArm", "MannequinLeftHand", "MannequinLeftLeg")


def mannequins(O):
    """The four window mannequins: the bare figure + stand (with the old ten parts as its
    fallback), its top and its trousers, three markers on the same pivot inside the Model.
    citygen's figures face +Z at yaw 0 (their right arm is at -X), the pieces face -Z: + 180."""
    for suffix, (x, z), pose in MANNEQUINS:
        folder = f"{TB}/Mannequin_{suffix}"
        parts = O.box(folder, set(MQ_NAMES))
        if len(parts) != 10:
            O.error(f"shops: mannequin {suffix} has {len(parts)} parts (expected 10)")
            continue
        torso = next(p for p in parts if p.name == "MannequinTorso")
        leg = next(p for p in parts if p.name == "MannequinRightLeg")
        v = vr("mq", suffix)
        ry = yaw(O, torso) + 180.0 + v.uniform(-4, 4)
        at = (x, 3.4, z)
        with O.entry(f"threads_mannequin_{suffix}"):
            wrap(O, parts, "MannequinDisplay" + pose, at, ry=ry, tint=weathered(TINT["MannequinDisplay"], v, 4, 0.05),
                 force="the marker stays inside the Mannequin Model; ShopFrontController paints its descendants by name")
            bare(O, folder, "MannequinTop" + pose, at, ry=ry, tint=colour(O, torso))
            bare(O, folder, "MannequinLegs" + pose, at, ry=ry, tint=colour(O, leg))


def shelf_wall(O):
    """The back wall unit: shelves, base cupboards, the end cupboard at the east end (-28.2),
    front to the shop (+Z). ShelfCollider stays as the proxy; the Pegboard stays."""
    parts = [m(O, TB, "ShelfCollider", (-38.6, 6.55, -99.3)), m(O, TB, "ShelfEnd", (-29.6, 6.55, -99.3)),
             m(O, TB, "ShelfSide", (-48.85, 6.55, -99.3)), m(O, TB, "ShelfSide", (-31.15, 6.55, -99.3)),
             m(O, TB, "ShelfTop", (-40, 11.125, -99.3))]
    parts += [m(O, TB, "ShelfBoard", (-40, y, -99.3)) for y in (4.275, 6.875, 9.475)]
    wrap(O, parts, "ShopShelfWall", (-38.6, FLOOR, -99.3), ry=180.0, name="threads_shelf_wall")


def shelf_stock(O):
    """The twelve folded-tee stacks (two shelves; some half sold), the eight pairs of sneakers on
    the bottom board (toes to the shelf's lip, heels 0.04 off its back), tinted from the old
    parts, each a little turned."""
    for y, top in ((7.525, 6.95), (10.125, 9.55)):
        for k, x in enumerate((-47.0, -44.3, -41.6, -38.9, -36.2, -33.5)):
            tee = m(O, TB, "FoldedTee", (x, y, -99.3))
            tt = O.near(TB, "FoldedTeeTop", (x, y + 0.705, -99.3), radius=0.12)
            v = vr("tee", x, y)
            piece = "FoldedTeeStackShort" if v.random() < 0.3 else "FoldedTeeStack"
            wrap(O, [tee, tt], piece, (x + v.uniform(-0.06, 0.06), top, -99.3), ry=180.0 + v.uniform(-4, 4),
                 tint=weathered(colour(O, tee), v, 4, 0.05), name=f"threads_tee_{x}_{y}")
    for x in (-47.6, -45.5, -43.4, -41.3, -39.2, -37.1, -35.0, -32.9):
        sn = m(O, TB, "Sneaker", (x, 4.65, -99.35))
        v = vr("sneaker", x)
        piece = "SneakerPairHigh" if v.random() < 0.4 else "SneakerPair"
        wrap(O, [sn], piece, (x, 4.35, -99.25), ry=180.0 + v.uniform(-5, 5), tint=weathered(colour(O, sn), v, 5, 0.05),
             name=f"threads_sneakers_{x}")


def display_table(O):
    """The reclaimed-wood display table (the DisplayTable box stays as its proxy) and its six
    low stacks; the two caps stay as they are."""
    wrap(O, [m(O, TB, "DisplayTable", (-48, 3.4, -81.5))], "DisplayTableWood", (-48.0, FLOOR, -81.5),
         ry=180.0 if vr("table").random() < 0.5 else 0.0, name="threads_table")
    for x in (-49.8, -48.0, -46.2):
        for z in (-82.1, -80.7):
            st = m(O, TB, "FoldedStack", (x, 5.375, z))
            top = O.near(TB, "FoldedStackTop", (x, 5.98, z), radius=0.12)
            v = vr("stack", x, z)
            wrap(O, [st, top], "FoldedTeeStackLow", (x, 4.9, z), ry=(180.0 if z > -81.5 else 0.0) + v.uniform(-6, 6),
                 tint=weathered(colour(O, st), v, 4, 0.05), name=f"threads_stack_{x}_{z}")


def till(O):
    """The till (a modern POS: screen to the clerk at -Z). Lamp and key bowl stay."""
    wrap(O, [m(O, TB, "Till", (-40, 5.5, -90.8)), m(O, TB, "TillDisplay", (-40, 5.7, -89.95))], "CashRegisterModern",
         (-40.0, COUNTER, -90.8), ry=vr("till").uniform(-5, 5), name="threads_till")


def fitting_room(O):
    """The fitting room: the two velvet curtains on the kept rail (closed 5.2 one, pulled-aside
    4.0 one bunched toward the wall at +Z), the gilt mirror leaning on the cubicle wall."""
    wrap(O, [m(O, TB, "Curtain", (-54.95, 6.2, -97.2))], "CurtainDrawn", (-55.0, 10.3, -97.2), ry=-90.0,
         name="threads_curtain_a")
    wrap(O, [m(O, TB, "Curtain", (-54.95, 6.2, -90.6))], "CurtainDrawnB", (-55.0, 10.3, -90.6), ry=-90.0,
         name="threads_curtain_b")
    wrap(O, [m(O, TB, "MirrorFrame", (-58.5, 5.9, -87.95)), m(O, TB, "Mirror", (-58.5, 5.9, -87.85))], "StandingMirror",
         (-58.5, FLOOR, -88.0), ry=180.0, name="threads_mirror")


def pegboard(O):
    """Four face-out garments on pegboard arms above the shelves (the board at z -99.9, y
    11.6..14.8): shirts and hoodies, coloured like the shop's outfits. No fallback."""
    peg = m(O, TB, "Pegboard", (-40, 13.2, -99.95))
    if O.row(peg) is None:
        return
    face = -99.9
    looks = (("ShirtOnHanger", (128, 44, 40)), ("HoodieOnHanger", (58, 62, 54)), ("ShirtOnHanger", (52, 66, 96)),
             ("HoodieOnHanger", (120, 118, 112)))
    with O.entry("threads_pegboard"):
        for k, x in enumerate((-45.0, -41.5, -38.0, -34.5)):
            v = vr("peg", x)
            piece, tint = looks[k]
            hy = 14.25
            bare(O, TB, "PegboardHook", (x, hy, face), ry=180.0)
            # (the garment's hook on the arm: (0, -0.04, -0.36) in the arm's space, turned 180)
            bare(O, TB, piece, (x, hy - 0.04, face + 0.36), ry=180.0 + v.uniform(-3, 3),
                 tint=weathered(tint, v, 6, 0.08))


def edits(O):
    record_bins(O)
    portable_tvs(O)
    counter(O)
    tape_shelf(O)
    stage(O)
    arcade(O)
    mannequins(O)
    shelf_wall(O)
    shelf_stock(O)
    display_table(O)
    till(O)
    fitting_room(O)
    pegboard(O)


_ = (X, Y, Z)
