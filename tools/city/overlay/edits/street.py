"""The street furniture of the main avenues as real kit meshes (PLAN step 3, family "street";
the pieces are in tools/city/kit/pieces/streetfurn.py): every lamp column, traffic signal, the
payphone booth, the hydrants, the Jersey barriers, the news kiosk with its rack and bundles, the
steel benches (kiosk corner, the Cage), the bollards (kiosk, Lot 9), the steam grates and the
manhole covers. The old primitive parts are wrapped under each piece's MeshProp marker: PropKit
keeps the colliding ones as invisible proxies (same collisions, still breakable), hands the
lamps' CityLamp heads (tags, Dead / Flicker, SpotLight) and the kiosk's CityShopLight hatch to
the meshes' Glow, moves the steam vents' CitySteam to the grates' Fx; without the kit (or when
the city moved a part) the old parts stay as they are.

Kept OUT of the wraps (they stay real, visible parts): the kiosk's roof sign (a lit neon with
text), the traffic lights' three lens parts (the red one is lit: they become round discs sitting
in the mesh head's lens bezels), the booth's PhoneGlass panes (CityGlass makes them transparent;
the mesh is the frame round them; the smashed booth's missing pane is wrapped away).

Every copy differs by its place (meshprop.variation): variant, tint (weathered), yaw where the
footprint allows it. Each mesh fits its proxies within ~0.3 stud (tools/city/kit/pieces/
streetfurn.py notes the footprints; measured against every colliding proxy: worst 0.3 stud, the barriers' top).

Already wrapped elsewhere (edits/reuse.py): street bins, trash bag piles, traffic cones.
"""

import math

import numpy as np

from citykit import yxz_matrix
from meshprop import variation, weathered
from overlay.citydata import RX, RY, SX, X, Y
from overlay.core import DECOR
from overlay.edits.reuse import Fr, ground, nearest_wall, pos, size, wrap_at, yaw_of

# The kit pieces' extents (studs, piece space) from the kit build's pieces.json: the marker's
# size when assets/cityprops/pieces.json does not have the piece yet (the integrator's full
# kit export writes it; then these are the same numbers).
EXTENT = {
    "StreetLampColumn": ((-0.525, -0.01, -5.65), (0.525, 16.3, 0.49)),
    "StreetLampColumnRusty": ((-0.683, -0.01, -5.67), (0.683, 16.3, 0.683)),
    "StreetLampColumnDead": ((-0.657, -0.01, -5.67), (0.657, 16.3, 0.49)),
    "TrafficSignalPole": ((-0.41, -0.01, -0.425), (1.16, 11.1, 0.425)),
    "TrafficSignalHead": ((-0.975, -1.975, -1.02), (0.975, 1.975, 0.42)),
    "PhoneBooth": ((-1.523, -0.01, -1.661), (1.523, 7.775, 1.48)),
    "PhoneBoothSmashed": ((-1.581, -0.01, -1.661), (1.523, 7.775, 1.48)),
    "FireHydrant": ((-0.835, 0.0, -0.815), (0.835, 2.505, 0.62)),
    "FireHydrantWorn": ((-0.657, -0.03, -0.749), (0.879, 2.506, 0.645)),
    "JerseyBarrier": ((-4.199, 0.0, -1.0), (4.199, 3.485, 1.0)),
    "JerseyBarrierChipped": ((-4.199, 0.0, -1.0), (4.071, 3.485, 1.0)),
    "NewsKiosk": ((-3.6, 0.0, -3.1), (3.6, 8.9, 2.24)),
    "MagazineRack": ((-2.425, -0.022, -0.616), (2.425, 2.712, 0.014)),
    "NewspaperBundle": ((-0.61, -0.041, -0.48), (0.607, 0.525, 0.48)),
    "StreetBenchSteel": ((-5.0, 0.0, -0.89), (5.0, 2.742, 0.89)),
    "BollardSteel": ((-0.44, 0.0, -0.44), (0.44, 3.2, 0.44)),
    "BollardSteelBent": ((-0.589, -0.03, -0.637), (0.726, 3.19, 0.664)),
    "StreetGrate": ((-2.0, -0.055, -2.0), (2.0, 0.07, 2.0)),
    "ManholeCover": ((-1.5, -0.05, -1.5), (1.5, 0.065, 1.5)),
}


def vr(*key):
    return variation("city_street", *(round(k, 2) if isinstance(k, float) else k for k in key))


def msize(piece, scale=1.0):
    lo, hi = EXTENT[piece]
    return tuple(max(abs(lo[i]), abs(hi[i])) * 2 for i in range(3))


def wrap(O, matches, piece, fr, tint=None, scale=1.0, name=None):
    """reuse.wrap_at with this family's marker size (the piece may not be in pieces.json yet)."""
    rx, ry, rz = fr.angles
    return O.wrap(matches, piece, fr.pos, ry=ry, rx=rx, rz=rz, tint=tint, scale=scale, size=msize(piece),
                  name=name)


def bare(O, folder, piece, fr, tint=None, scale=1.0):
    """A marker with no fallback parts (it only shows with the kit), like reuse.bare_at."""
    attrs = {"Piece": piece}
    if tint is not None:
        attrs["Tint"] = ",".join(str(int(round(c))) for c in tint)
    if scale != 1.0:
        attrs["Scale"] = round(float(scale), 3)
    sz = tuple(max(0.05, v * scale) for v in msize(piece))
    return O.add(folder, "MeshProp", fr.pos, sz, (128, 128, 128), "SmoothPlastic", rot=fr.angles,
                 transparency=1.0, flags=DECOR, extra={"a": attrs})


def unit(dx, dz):
    d = math.hypot(dx, dz)
    return (dx / d, dz / d)


# ---------------------------------------------------------------------------------- lamps
LAMP_PAINT = ((44, 50, 48), (30, 31, 32), (40, 46, 56), (52, 54, 50))


def lamps(O):
    """The 20 lighting columns (avenues, crossroads diagonals, viaduct coping): the column at the
    old base, its arm toward the old head. The data's Dead lamp gets the dead column (dull glass
    bowl, door gone); about a third are the old rusty cobra-head columns (the Flicker ones
    first); the rest the modern LED column."""
    F = "Props/Lamps"
    bases = O.box(F, "LampBase")
    parts = {n: O.box(F, n) for n in ("LampPole", "LampArm", "LampBrace", "LampHood", "LampHead")}
    for b in bases:
        bx, by, bz = pos(O, b)
        near = {}
        for n, ms in parts.items():
            if n == "LampPole":
                near[n] = min(ms, key=lambda m: math.dist((bx, bz), (pos(O, m)[0], pos(O, m)[2])))
            else:  # (the arm's parts: within the outreach of this base, at the top)
                near[n] = min(ms, key=lambda m: math.dist((bx, by + 14, bz), pos(O, m)))
        head = near["LampHead"]
        hx, _, hz = pos(O, head)
        d = unit(hx - bx, hz - bz)
        a = (O.extra(head) or {}).get("a") or {}
        v = vr("lamp", bx, bz)
        if a.get("Dead"):
            piece = "StreetLampColumnDead"
        elif a.get("Flicker") or v.random() < 0.3:
            piece = "StreetLampColumnRusty"
        else:
            piece = "StreetLampColumn"
        foot = by - size(O, b)[1] / 2
        fr = Fr((bx, foot, bz), ry=yaw_of((-d[0], -d[1])))
        pr = O.row(near["LampPole"])
        if pr is not None and (abs(pr[RX]) > 0.5 or abs(pr[RX + 2]) > 0.5):
            # a knocked column (the pole leans off its base): the same lean, pivoting on the
            # base's top, the mesh's shaft along the old pole
            pm = yxz_matrix(*pr[RX:RX + 3])
            lean = pm @ np.linalg.inv(yxz_matrix(0, pr[RX + 1], 0))
            axis = lean @ np.array((0.0, 1.0, 0.0))
            top = np.array((bx, foot + size(O, b)[1], bz))
            fr = Fr(top - axis * size(O, b)[1], m=lean @ fr.m)
        tint = weathered(v.choice(LAMP_PAINT), v, 4, 0.1)
        wrap(O, [b, near["LampPole"], near["LampArm"], near["LampBrace"], near["LampHood"], head], piece, fr,
             tint=tint, name=f"lamp_{bx}_{bz}")


# ---------------------------------------------------------------------------------- signals
def signals(O):
    """The four signals at the crossroads: the pole piece on the old pole, its brackets toward
    the head; the head piece at the old head (lenses away from the pole). The three lens parts
    stay (the red one is the lit Neon) and become round 0.62 discs in the head's bezels."""
    F = "Props/Signals"
    for pole in O.box(F, "SignalPole"):
        px, py, pz = pos(O, pole)
        head = min(O.box(F, "SignalHead"), key=lambda m: math.dist(pos(O, m), (px, py + 3.5, pz)))
        hood = min(O.box(F, "SignalHood"), key=lambda m: math.dist(pos(O, m), (px, py + 5.2, pz)))
        hx, hy, hz = pos(O, head)
        d = unit(hx - px, hz - pz)
        foot = py - size(O, pole)[1] / 2
        ry = yaw_of((-d[0], -d[1]))
        v = vr("signal", px, pz)
        with O.entry(f"signal_{px}_{pz}"):
            wrap(O, [pole], "TrafficSignalPole", Fr((px, foot, pz), ry=ry),
                 tint=weathered((40, 42, 42), v, 4, 0.1))
            wrap(O, [head, hood], "TrafficSignalHead", Fr((hx, hy, hz), ry=ry))
            lens_ry = math.degrees(math.atan2(-d[1], d[0]))  # (a Cylinder's axis is its X)
            for lens in O.box(F, "SignalLens", lo=(hx - 0.8, hy - 1.6, hz - 0.8), hi=(hx + 0.8, hy + 1.6, hz + 0.8)):
                ly = pos(O, lens)[1]
                O.set(lens, shape="Cylinder", size=(0.05, 0.62, 0.62), rot=(0, lens_ry, 0),
                      pos=(hx + d[0] * 0.445, ly, hz + d[1] * 0.445))


# ---------------------------------------------------------------------------------- booth
def phone_booth(O):
    """The payphone booth: the smashed one (its +X side pane gone: that PhoneGlass is wrapped
    away; the other three panes stay, transparent, in the mesh's frames). Door side = +Z."""
    F = "Props/Street"
    names = {"PhoneCollider", "PhoneBase", "PhonePost", "PhoneRoof", "PhoneBack", "PhoneKick", "PhoneSign",
             "PhoneUnit", "PhoneHandset"}
    lo, hi = (-71.2, 0, -71), (-67.8, 12, -67.2)
    ms = O.box(F, names, lo=lo, hi=hi)
    gone = O.match(F, "PhoneGlass", (-68.15, 5.9, -69.1))
    col = O.match(F, "PhoneCollider", (-69.5, 5.7, -69.1))
    r = O.row(col)
    if r is None:
        return
    foot = r[Y] - r[SX + 1] / 2
    wrap(O, [col] + [m for m in ms if m.name != "PhoneCollider"] + [gone], "PhoneBoothSmashed",
         Fr((r[X], foot, r[X + 2]), ry=180), tint=weathered((60, 48, 46), vr("booth"), 4, 0.1), name="phone_booth")


# ---------------------------------------------------------------------------------- hydrants
HYDRANT_PAINT = ((128, 34, 28), (118, 30, 26), (150, 120, 40))


def hydrants(O):
    """The three hydrants: the pumper outlet toward the road (away from the nearest wall); one
    old worn one (paint flaked, a cap gone)."""
    F = "Props/Street"
    for k, body in enumerate(O.box(F, "Hydrant")):
        x, y, z = pos(O, body)
        cap = O.match(F, "HydrantCap", (x, 4.15, z))
        noz = O.match(F, "Nozzle", (x, 3.4, z))
        foot = y - size(O, body)[0] / 2  # (a Cylinder along X turned upright: its length is X)
        v = vr("hydrant", x, z)
        worn = k == 1
        wall = nearest_wall(O, (x, foot + 1.0, z), reach=12)
        out = (-wall[0][0], -wall[0][1]) if wall else (0, -1)
        fr = Fr((x, foot, z), ry=yaw_of((-out[0], -out[1])) + v.uniform(-12, 12))
        tint = weathered(HYDRANT_PAINT[2] if worn else v.choice(HYDRANT_PAINT[:2]), v, 6, 0.15)
        wrap(O, [body, cap, noz], "FireHydrantWorn" if worn else "FireHydrant", fr, tint=tint,
             name=f"hydrant_{x}_{z}")


# ---------------------------------------------------------------------------------- barriers
def barriers(O):
    """The two Jersey barriers at the barricades: same box, same heading; the second one with
    its corner smashed off. The red reflector block becomes the mesh's reflector plates."""
    F = "Props/Barricades"
    for k, (at, refl) in enumerate((((-123, 2.8, -55.6), (-123.399, 3.2, -53.335)), ((-117, 2.8, -33.5), None))):
        jb = O.match(F, "JerseyBarrier", at)
        r = O.row(jb)
        if r is None:
            continue
        ms = [jb] + ([O.match(F, "Reflector", refl)] if refl else [])
        foot = at[1] - r[SX + 1] / 2
        ry = r[RY]  # (RY: the barrier's length is its X, like the piece's)
        wrap(O, ms, "JerseyBarrierChipped" if k == 1 else "JerseyBarrier", Fr((at[0], foot, at[2]), ry=ry),
             name=f"jersey_{at[0]}_{at[2]}")


# ---------------------------------------------------------------------------------- kiosk corner
def kiosk(O):
    """The news kiosk (hatch to the west), its magazine rack under the counter, the bundles of
    papers on the pavement, the bench and the three bollards. The roof's lit KioskSign stays."""
    F = "Props/Kiosk"
    shell = O.match(F, "Kiosk", (129, 5.6, -44))
    r = O.row(shell)
    if r is None:
        return
    foot = r[Y] - r[SX + 1] / 2
    ms = [shell, O.match(F, "KioskRoof", (128.5, 9.65, -44)), O.match(F, "KioskHatch", (126.95, 6.75, -44)),
          O.match(F, "KioskCounter", (126.55, 4.9, -44)), O.match(F, "Till", (126.85, 5.4, -44))]
    ms += O.box(F, {"KioskShelf", "Packs", "Headline"})
    wrap(O, ms, "NewsKiosk", Fr((129, foot, -44), ry=90), tint=weathered((38, 62, 50), vr("kiosk"), 4, 0.1),
         name="news_kiosk")
    mags = O.box(F, "Magazines")
    wrap(O, mags, "MagazineRack", Fr((127.0, foot + 0.15, -44), ry=90), name="magazine_rack")
    # bundles: the tall one is two bundles stacked
    with O.entry("bundles"):
        b1 = O.match(F, "Bundle", (128, 2.3, -54.2))
        b2 = O.match(F, "Bundle", (128, 2.05, -55.5))
        g = foot
        v = vr("bundle")
        wrap(O, [b1], "NewspaperBundle", Fr((128, g, -54.2), ry=v.uniform(-6, 6)))
        bare(O, F, "NewspaperBundle", Fr((128.03, g + 0.5, -54.18), ry=v.uniform(170, 190)))
        wrap(O, [b2], "NewspaperBundle", Fr((128, g, -55.5), ry=v.uniform(80, 100)))
    bench(O, F, (115, 3.6, -19.6), (111, 2.575, -19.6), (119, 2.575, -19.6))
    for k, z in enumerate((-56, -44, -32)):
        bollard(O, F, (121, 3.3, z), (121, 4.35, z), bent=(k == 2))


def bench(O, F, seat_at, leg1, leg2):
    seat = O.match(F, "Bench", seat_at)
    r = O.row(seat)
    if r is None:
        return
    top = seat_at[1] + r[SX + 1] / 2
    v = vr("bench", seat_at[0], seat_at[2])
    fr = Fr((seat_at[0], top - 2.05, seat_at[2]), ry=r[RY] + v.choice((0, 180)))
    wrap(O, [seat, O.match(F, "BenchLeg", leg1), O.match(F, "BenchLeg", leg2)], "StreetBenchSteel", fr,
         tint=weathered(v.choice(((46, 50, 48), (34, 34, 36), (58, 52, 44))), v, 4, 0.1),
         name=f"bench_{seat_at[0]}_{seat_at[2]}")


def bollard(O, F, at, band_at, bent=False):
    b = O.match(F, "Bollard", at)
    r = O.row(b)
    if r is None:
        return
    h = r[SX + 1]
    foot = at[1] - h / 2
    v = vr("bollard", at[0], at[2])
    wrap(O, [b, O.match(F, "BollardBand", band_at)], "BollardSteelBent" if bent else "BollardSteel",
         Fr((at[0], foot, at[2]), ry=v.uniform(0, 360)), tint=weathered((34, 34, 34), v, 4, 0.1),
         scale=round(h / 3.2, 3), name=f"bollard_{at[0]}_{at[2]}")


def cage_and_lot9(O):
    """The Cage's two benches and Lot 9's four bollards (one knocked crooked)."""
    for x in (-86, -66):
        bench(O, "Zones/Cage", (x, 3.05, 118.2), (x - 4, 2.025, 118.2), (x + 4, 2.025, 118.2))
    for k, (x, z) in enumerate(((27.6, -114.6), (27.6, -99.4), (45.4, -71.6), (60.6, -71.6))):
        bollard(O, "Zones/Lot9", (x, 2.95, z), (x, 4.25, z), bent=(k == 1))


# ---------------------------------------------------------------------------------- road
def road(O):
    """The steam vents become cast road gratings (the CitySteam part stays, invisible, its steam
    from the grate's Fx), the manholes cast-iron sewer covers, each a little proud of the road."""
    for m in O.box("Props/Steam", "SteamVent"):
        x, y, z = pos(O, m)
        # (the old part's centre is just above the road: the road / alley floor top under it
        # is the surface the piece sits on, its pivot on that surface)
        g = ground(O, x, z, y, y - 0.05)
        v = vr("grate", x, z)
        wrap(O, [m], "StreetGrate", Fr((x, g, z), ry=v.choice((0, 90, 180, 270))), name=f"grate_{x}_{z}")
    for m in O.box("Ground/Manholes", "Manhole"):
        x, y, z = pos(O, m)
        g = ground(O, x, z, y, y - 0.05)
        v = vr("manhole", x, z)
        wrap(O, [m], "ManholeCover", Fr((x, g, z), ry=v.uniform(0, 360)), tint=weathered((48, 46, 44), v, 4, 0.1),
             name=f"manhole_{x}_{z}")


def edits(O):
    lamps(O)
    signals(O)
    phone_booth(O)
    hydrants(O)
    barriers(O)
    kiosk(O)
    cage_and_lot9(O)
    road(O)
