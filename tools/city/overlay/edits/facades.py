"""The buildings' facades as kit meshes (tools/city/kit/pieces/facades.py): windows, the
through-wall air conditioners, the shop roller shutters and their hoods, the garage / dock
roller doors, the shop-window frames and the two striped awnings.

Every prop's old primitive parts are wrapped under a MeshProp marker of its piece, placed on
the old footprint (the pieces are built to the data's sizes: a window opening is 4.4 x 6.4
upstairs, 4.4 x 5.2 on the ground floor; a shop shutter 15.2 x 7.6; a garage door 12 x 10).
Without the kit, or if the city moved a part, the old parts stay.

    windows      the stone jambs, lintel / head, sash bar and sill of each window -> a window
                 frame piece. The PANE is never wrapped: it keeps CityGlass (the glass look) and
                 CityWindowLit (lit at night); the sashes sit 0.15-0.32 in front of it. Each
                 building keeps ONE head style (flat arch of voussoirs, or a plain head stone),
                 as a real facade does; within it the copies differ: two-over-two or
                 one-over-one sashes, a roller blind drawn on some (more often on lit rooms),
                 the paint of the building with now and then one window repainted.
                 Boarded windows (a wooden pane + batten) -> WindowFrameBoarded(Plain): the
                 wooden pane and the batten go too (the plywood mesh replaces them).
                 Broken windows keep their glass shard, moved into the lower sash's plane.
                 Ground floor: glass + sash + jambs + head + sill (+ security bars) ->
                 WindowFrameSashLow / WindowFrameBarred; the boarded ones (sill + 3 boards) ->
                 WindowFrameBoardedLow. These hang under their Breakable wall panel: the marker
                 does too, so the window goes with the panel when it breaks.
    air cond.    WindowAC + its Grille -> WindowAcUnit / WindowAcUnitRusty (decoration).
    shutters     Shutter (Breakable) + slats, rails, padlock -> RollerShutterShop(Rusty); the
                 ShutterBox (Breakable) -> ShutterBoxHood. Both stay invisible KitProxy parts
                 (same collision, still breakable: Destruction hides the mesh with them).
    roller doors RollerDoor (Breakable or plain collider) + bottom bar + seams ->
                 RollerDoorGarage / RollerDoorGarageWorn (12 wide), RollerDoorGarageNarrow
                 (9.8); B13's DockDoor (10 x 9) -> RollerDoorDock. Proxies as above.
    shop fronts  the Mullion(s) under each ShopGlass -> ShopfrontFrame10/12/14/16 (moulded
                 frame, beads, mullions, transom, sloped cill), tinted per shop. ShopGlass is
                 NOT wrapped (Breakable glass, GlassController, CityGlass); the marker hangs
                 under it like the old mullion did. B7 / B11's fixed door-in-window (mullions,
                 door stiles, push bar: no CityDoor tag, they never move) ->
                 ShopfrontDoorFrame + PushBarHardware.
    awnings      Awning + its two arms (B7 torn, B11) -> ShopAwningTorn / ShopAwningFabric,
                 the canvas in the data's colour. The fascia, the neon sign and the sign board
                 are not touched.

NOT here: the CityDoor leaves (CityDoors moves each tagged part on its own: a mesh under a
marker would not follow; PushBarHardware waits for that), the bulkheads (reuse.py), the
ring blocks' windows (P3, out of scope).
"""

import math

from meshprop import variation, weathered
from overlay.citydata import COLOR, MATERIAL, PARENT, RX, SX, X, Y, Z, folder_of
from overlay.edits.reuse import yaw_of

B = "Buildings"

# The kit pieces' extents (studs, piece space) from the kit build's pieces.json: the marker's
# size when assets/cityprops/pieces.json does not have the piece yet (the integrator's full
# kit export writes it; then these are the same numbers).
EXTENT = {
    "PushBarHardware": ((-2.115, -0.090, -0.123), (2.115, 0.090, 0.123)),
    "RollerDoorDock": ((-4.980, -4.500, -0.468), (4.980, 4.500, 0.150)),
    "RollerDoorGarage": ((-5.980, -5.000, -0.468), (5.980, 5.000, 0.150)),
    "RollerDoorGarageNarrow": ((-4.880, -5.000, -0.468), (4.880, 5.000, 0.150)),
    "RollerDoorGarageWorn": ((-5.980, -5.000, -0.468), (5.980, 5.000, 0.150)),
    "RollerShutterShop": ((-8.000, -3.850, -0.638), (8.000, 3.800, 0.200)),
    "RollerShutterShopRusty": ((-8.000, -3.850, -0.638), (8.000, 3.800, 0.200)),
    "ShopAwningFabric": ((-8.001, -2.300, -3.950), (8.001, 0.180, 0.620)),
    "ShopAwningTorn": ((-8.001, -2.328, -3.950), (8.001, 0.180, 0.620)),
    "ShopfrontDoorFrame": ((-7.290, -2.795, -0.420), (7.195, 2.795, 0.300)),
    "ShopfrontFrame10": ((-4.995, -3.760, -0.720), (4.995, 3.695, 0.320)),
    "ShopfrontFrame12": ((-5.995, -3.760, -0.720), (5.995, 3.695, 0.320)),
    "ShopfrontFrame14": ((-6.995, -3.760, -0.720), (6.995, 3.695, 0.320)),
    "ShopfrontFrame16": ((-7.995, -3.760, -0.720), (7.995, 3.695, 0.320)),
    "ShutterBoxHood": ((-8.027, -0.490, -0.720), (8.027, 0.580, 0.700)),
    "WindowAcUnit": ((-1.720, -2.500, -2.180), (1.720, 1.120, 0.020)),
    "WindowAcUnitRusty": ((-1.720, -3.700, -2.180), (1.720, 1.120, 0.020)),
    "WindowFrameBarred": ((-2.700, -3.000, -0.600), (2.700, 3.000, 0.020)),
    "WindowFrameBlind": ((-2.776, -3.600, -0.600), (2.776, 3.980, 0.020)),
    "WindowFrameBlindLow": ((-2.700, -3.600, -0.600), (2.700, 3.900, 0.020)),
    "WindowFrameBoarded": ((-2.776, -3.600, -0.600), (2.776, 3.980, 0.020)),
    "WindowFrameBoardedPlain": ((-2.700, -3.600, -0.600), (2.700, 3.900, 0.020)),
    "WindowFrameBoardedLow": ((-2.600, -3.000, -0.400), (2.600, 2.783, 0.020)),
    "WindowFrameSash": ((-2.776, -3.600, -0.600), (2.776, 3.980, 0.020)),
    "WindowFrameSashLow": ((-2.700, -3.000, -0.600), (2.700, 3.000, 0.020)),
    "WindowFrameSashPlain": ((-2.700, -3.600, -0.600), (2.700, 3.900, 0.020)),
}


def vr(*key):
    return variation("city_facades", *(round(k, 2) if isinstance(k, float) else k for k in key))


def msize(piece):
    lo, hi = EXTENT[piece]
    return tuple(max(abs(lo[i]), abs(hi[i])) * 2 for i in range(3))


def wrap(O, matches, piece, origin, out, tint=None, name=None):
    """The marker of `piece` at `origin`, its -Z (the piece's front) along the horizontal unit
    vector `out` (out of the building)."""
    ry = yaw_of((-out[0], -out[1]))  # (the piece's +Z into the wall)
    return O.wrap(matches, piece, origin, ry=ry, tint=tint, size=msize(piece), name=name)


# ------------------------------------------------------------------------------- geometry
def pos(O, m):
    r = O.row(m)
    return (r[X], r[Y], r[Z])


def size(O, m):
    return tuple(O.row(m)[SX:SX + 3])


def bld(O, m):
    """The building of a row: 'B1' from 'Buildings/B1/Facade_S'."""
    return folder_of(O.data, O.row(m)).split("/")[1]


def thin_axis(s):
    """0 (x) or 2 (z): the thin horizontal axis of an axis-aligned facade part."""
    return 0 if s[0] < s[2] else 2


def out_from(O, part, toward):
    """(dx, dz): the unit horizontal vector out of the wall, from a part and a row known to be
    in front of it (a sill, a padlock, a bottom bar, a grille)."""
    k = thin_axis(size(O, part))
    d = pos(O, toward)[k] - pos(O, part)[k]
    sgn = 1 if d > 0 else -1
    return (sgn, 0) if k == 0 else (0, sgn)


def lateral(out):
    """The axis along the wall (0 = x, 2 = z) for an out vector."""
    return 2 if out[0] != 0 else 0


def gather(rows_by_name, names, centre, out, half_w, y0, y1, d0, d1):
    """The rows of `names` around a facade element: within half_w along the wall, y0..y1 from
    its centre height, d0..d1 out of `centre` (studs)."""
    lat = lateral(out)
    k = 0 if out[0] != 0 else 2
    s = out[0] + out[1]
    found = []
    for n in names:
        for m, p in rows_by_name.get(n, ()):
            if abs(p[lat] - centre[lat]) > half_w:
                continue
            if not (y0 <= p[1] - centre[1] <= y1):
                continue
            d = (p[k] - centre[k]) * s
            if d0 <= d <= d1:
                found.append(m)
    return found


def index(O, names):
    """{name: [(Match, pos)]} of the built rows under Buildings/ with these names."""
    out = {}
    for m in O.box(B, set(names), prefix=True):
        out.setdefault(m.name, []).append((m, pos(O, m)))
    return out


def tags(O, m):
    return (O.extra(m) or {}).get("t") or []


# ------------------------------------------------------------------------------- windows
# Head style per building (one per facade, as built): "arch" = a flat arch of five voussoirs,
# "plain" = a plain head stone. Paint of the sashes per building (painted timber), worn.
HEAD = {"B1": "arch", "B5": "plain", "B7": "arch", "B11": "plain", "B12": "arch", "B13": "plain",
        "SEN": "arch", "M": "plain", "S1": "plain", "B2": "plain", "B2n": "plain", "L": "arch", "o": "plain"}
PAINT = {"B1": (30, 40, 34), "B5": (150, 144, 128), "B7": (26, 26, 28), "B11": (88, 34, 30),
         "B12": (32, 46, 38), "B13": (112, 116, 112), "SEN": (140, 134, 118), "M": (58, 50, 42),
         "S1": (100, 104, 100), "B2": (70, 72, 70), "B2n": (70, 72, 70), "L": (40, 44, 40), "o": (120, 116, 104)}
REPAINT = ((150, 144, 128), (30, 40, 34), (26, 26, 28), (112, 116, 112), (88, 34, 30))
SASH = {"arch": ("WindowFrameSash", "WindowFrameBlind"), "plain": ("WindowFrameSashPlain", "WindowFrameBlindLow")}
BOARDED = {"arch": "WindowFrameBoarded", "plain": "WindowFrameBoardedPlain"}

UNIT = ("WindowJamb", "Lintel", "Head", "Sash", "Sill", "Batten", "Bar", "Shard", "Board")


def paint(b, rng):
    if rng.random() < 0.14:  # (one owner repainted his window)
        return weathered(rng.choice(REPAINT), rng, 8, 0.15)
    return weathered(PAINT.get(b, (60, 62, 58)), rng, 6, 0.1)


def windows(O, rows):
    """Every upstairs window (Window pane) and ground-floor window (Glass pane with a Sash)."""
    n = 0
    for pane_name, hh, low in (("Window", 3.2, False), ("Glass", 2.6, True)):
        for pane, c in rows.get(pane_name, ()):
            s = size(O, pane)
            if abs(s[1] - 2 * hh) > 0.01 or min(s[0], s[2]) > 0.11 or abs(max(s[0], s[2]) - 4.4) > 0.01:
                continue
            k = thin_axis(s)
            sills = [m for m, p in rows.get("Sill", ()) if abs(p[1] - (c[1] - hh - 0.2)) < 0.05
                     and abs(p[2 - k] - c[2 - k]) < 0.1 and abs(p[k] - c[k]) < 0.6]
            if len(sills) != 1:
                O.warn(f"facades: no sill under {pane}")
                continue
            out = out_from(O, pane, sills[0])
            face = list(c)
            face[k] -= (out[0] + out[1]) * s[k] / 2  # (the pane's back = the wall face)
            parts = gather(rows, UNIT, face, out, 2.85, -hh - 0.75, hh + 1.15, -0.05, 0.75)
            names = [m.name for m in parts]
            if names.count("WindowJamb") != 2 or names.count("Sill") != 1:
                O.warn(f"facades: incomplete window at {pane} ({sorted(names)})")
                continue
            b = bld(O, pane)
            head = HEAD.get(b, "plain")
            rng = vr("win", *c)
            tint = paint(b, rng)
            shard = [m for m in parts if m.name == "Shard"]
            parts = [m for m in parts if m.name != "Shard"]
            wood = O.data["materials"][O.row(pane)[MATERIAL] - 1] == "Wood" or "Batten" in names
            if low:
                piece = "WindowFrameBarred" if "Bar" in names else "WindowFrameSashLow"
            elif wood:
                piece = BOARDED[head]
                parts = [pane] + parts  # (the wooden "pane" goes: the plywood replaces it)
                if tags(O, pane):
                    O.warn(f"facades: boarded pane {pane} has tags {tags(O, pane)}: kept")
                    parts.remove(pane)
            else:
                # (a drawn blind only behind an unlit pane: the kit's blind sheet hangs at the
                # pane's plane, so on a lit one it would hide the glow Ambience gives the pane)
                lit = "CityWindowLit" in tags(O, pane)
                pick = rng.random()
                piece = SASH[head][1] if (not lit and pick < 0.25) else SASH[head][0]
            wrap(O, parts, piece, tuple(face), out, tint=tint, name=f"window_{b}_{c[0]:g}_{c[1]:g}_{c[2]:g}")
            n += 1
            for sh in shard:
                # the shard stays (a broken pane), set into the lower sash's plane (0.28 out)
                p = list(pos(O, sh))
                p[k] = face[k] + (out[0] + out[1]) * 0.28
                O.set(sh, pos=tuple(p))
    return n


def boarded_low(O, rows):
    """Ground-floor windows boarded with three planks over a stone sill (no glass)."""
    n = 0
    for sill, c in rows.get("Sill", ()):
        s = size(O, sill)
        if abs(max(s[0], s[2]) - 5.2) > 0.01 or abs(s[1] - 0.4) > 0.01:
            continue
        boards = [m for m, p in rows.get("Board", ()) if abs(p[0] - c[0]) < 0.1 and abs(p[2] - c[2]) < 0.4
                  and 0.5 < p[1] - c[1] < 5.0]
        if len(boards) != 3:
            continue
        k = thin_axis(s)
        par = O.row(sill)[PARENT] - 1
        pr = O.data["parts"][par]
        sgn = 1 if c[k] - pr[X + k] > 0 else -1  # (the sill stands out of its wall panel)
        out = (sgn, 0) if k == 0 else (0, sgn)
        face = list(c)
        face[k] = pr[X + k] + sgn * pr[SX + k] / 2
        face[1] = c[1] + 0.2 + 2.6  # (the sill's top is the opening's bottom, 5.2 tall)
        b = bld(O, sill)
        wrap(O, [sill] + boards, "WindowFrameBoardedLow", tuple(face), out,
             name=f"boardedlow_{b}_{c[0]:g}_{c[2]:g}")
        n += 1
    return n


# ------------------------------------------------------------------------------- air conditioners
AC_PAINT = ((168, 162, 146), (150, 148, 138), (112, 114, 110), (176, 172, 160))


def air_conditioners(O, rows):
    n = 0
    for ac, c in rows.get("WindowAC", ()):
        grilles = [m for m, p in rows.get("Grille", ()) if math.dist(p, c) < 1.4]
        if len(grilles) != 1:
            O.warn(f"facades: AC {ac} without its grille")
            continue
        s = size(O, ac)
        k = 0 if s[0] < s[2] and abs(s[0] - 2.2) < 0.01 else 2
        d = pos(O, grilles[0])[k] - c[k]
        sgn = 1 if d > 0 else -1
        out = (sgn, 0) if k == 0 else (0, sgn)
        face = list(c)
        face[k] -= sgn * s[k] / 2
        rng = vr("ac", *c)
        rusty = rng.random() < 0.4
        tint = weathered(rng.choice(AC_PAINT), rng, 8, 0.15)
        wrap(O, [ac, grilles[0]], "WindowAcUnitRusty" if rusty else "WindowAcUnit", tuple(face), out, tint=tint,
             name=f"ac_{c[0]:g}_{c[1]:g}_{c[2]:g}")
        n += 1
    return n


# ------------------------------------------------------------------------------- shutters, roller doors
def shutters(O, rows):
    n = 0
    for sh, c in rows.get("Shutter", ()):
        locks = [m for m, p in rows.get("Padlock", ()) if math.dist(p, c) < 3.0]
        if len(locks) != 1:
            O.warn(f"facades: shutter {sh} without its padlock")
            continue
        out = out_from(O, sh, locks[0])
        lat = lateral(out)
        kids = gather(rows, ("Slat", "Rail", "Padlock"), c, out, 8.0, -3.9, 3.9, -0.6, 0.6)
        kids = [m for m in kids if O.row(m)[PARENT] - 1 == sh.row]
        rng = vr("shutter", *c)
        rusty = rng.random() < 0.5
        tint = weathered((126, 130, 128) if not rusty else (112, 116, 112), rng, 6, 0.1)
        wrap(O, [sh], "RollerShutterShopRusty" if rusty else "RollerShutterShop", c, out, tint=tint,
             name=f"shutter_{c[0]:g}_{c[2]:g}")
        n += 1
        boxes = [m for m, p in rows.get("ShutterBox", ()) if abs(p[lat] - c[lat]) < 0.1 and 3.5 < p[1] - c[1] < 5.0]
        if len(boxes) == 1:
            bc = pos(O, boxes[0])
            wrap(O, boxes, "ShutterBoxHood", bc, out, tint=weathered((104, 108, 104), rng, 8, 0.1),
                 name=f"shutterbox_{bc[0]:g}_{bc[2]:g}")
            n += 1
    return n


def roller_doors(O, rows):
    n = 0
    for door_name in ("RollerDoor", "DockDoor"):
        for door, c in rows.get(door_name, ()):
            s = size(O, door)
            kids = [m for nm in ("BottomBar", "Seam") for m, p in rows.get(nm, ())
                    if O.row(m)[PARENT] - 1 == door.row]
            front = [m for m in kids if m.name == "Seam"]
            if not front:
                O.warn(f"facades: door {door} has no seams")
                continue
            out = out_from(O, door, front[0])
            w = max(s[0], s[2])
            rng = vr("door", *c)
            if door_name == "DockDoor":
                if abs(w - 10) > 0.01 or abs(s[1] - 9) > 0.01:
                    continue
                piece = "RollerDoorDock"
            elif abs(w - 12) < 0.01 and abs(s[1] - 10) < 0.01:
                piece = "RollerDoorGarageWorn" if rng.random() < 0.45 else "RollerDoorGarage"
            elif abs(w - 9.8) < 0.01 and abs(s[1] - 10) < 0.01:
                piece = "RollerDoorGarageNarrow"
            else:
                O.warn(f"facades: door {door} {w} x {s[1]}: no piece")
                continue
            base = {"RollerDoorGarage": (116, 120, 118), "RollerDoorGarageWorn": (104, 108, 104)}.get(piece, (106, 110, 106))
            if rng.random() < 0.3:  # (a painted one: the lock-up's colour, faded)
                base = rng.choice(((70, 82, 74), (96, 70, 52), (60, 70, 86)))
            wrap(O, [door], piece, c, out, tint=weathered(base, rng, 6, 0.12),
                 name=f"rollerdoor_{c[0]:g}_{c[2]:g}")
            n += 1
    return n


# ------------------------------------------------------------------------------- shop fronts
SHOP_PAINT = {"B1": (30, 34, 38), "B5": (62, 26, 28), "B12": (24, 40, 32)}


def shop_fronts(O, rows):
    n = 0
    for glass, c in rows.get("ShopGlass", ()):
        s = size(O, glass)
        kids = [m for nm in ("Mullion", "DoorStile", "PushBar") for m, p in rows.get(nm, ())
                if O.row(m)[PARENT] - 1 == glass.row]
        mull = [m for m in kids if m.name == "Mullion"]
        if not mull:
            continue
        out = out_from(O, glass, mull[0])
        w = max(s[0], s[2])
        b = bld(O, glass)
        rng = vr("shop", *c)
        if any(m.name == "PushBar" for m in kids):
            if abs(w - 14.4) > 0.01 or abs(s[1] - 5.6) > 0.01:
                continue
            frame = [m for m in kids if m.name != "PushBar"]
            bar = [m for m in kids if m.name == "PushBar"]
            if any(tags(O, m) for m in kids):
                O.warn(f"facades: shop door at {glass} is tagged: left alone")
                continue
            wrap(O, frame, "ShopfrontDoorFrame", c, out, tint=weathered((52, 48, 44), rng, 5, 0.1),
                 name=f"shopdoor_{b}_{c[0]:g}_{c[2]:g}")
            wrap(O, bar, "PushBarHardware", pos(O, bar[0]), out, name=f"pushbar_{b}_{c[0]:g}_{c[2]:g}")
            n += 2
            continue
        piece = {10.0: "ShopfrontFrame10", 12.0: "ShopfrontFrame12", 14.0: "ShopfrontFrame14",
                 16.0: "ShopfrontFrame16"}.get(round(w, 2))
        if piece is None or abs(s[1] - 7.4) > 0.01:
            O.warn(f"facades: shop glass {glass} {w} x {s[1]}: no frame piece")
            continue
        wrap(O, mull, piece, c, out, tint=weathered(SHOP_PAINT.get(b, (34, 52, 44)), rng, 4, 0.08),
             name=f"shopfront_{b}_{c[0]:g}_{c[2]:g}")
        n += 1
    return n


# ------------------------------------------------------------------------------- awnings
def awnings(O, rows):
    n = 0
    for aw, c in rows.get("Awning", ()):
        r = O.row(aw)
        s = size(O, aw)
        if abs(s[0] - 16) > 0.01 or abs(s[2] - 4) > 0.01:
            continue
        ry = math.radians(r[RX + 1])
        rx = math.radians(r[RX])
        # the slab's local +Z and +Y in world (R = Ry Rx)
        fz = (math.sin(ry) * math.cos(rx), -math.sin(rx), math.cos(ry) * math.cos(rx))
        fy = (math.sin(ry) * math.sin(rx), math.cos(rx), math.cos(ry) * math.sin(rx))
        ends = [tuple(c[i] + e * 2.0 * fz[i] + 0.15 * fy[i] for i in range(3)) for e in (1, -1)]
        back = max(ends, key=lambda p: p[1])  # (the end at the wall is the high one)
        fr = min(ends, key=lambda p: p[1])
        dx, dz = fr[0] - back[0], fr[2] - back[2]
        L = math.hypot(dx, dz)
        out = (round(dx / L), round(dz / L))
        arms = [m for m, p in rows.get("AwningArm", ()) if math.dist(p, c) < 8.5 and abs(p[1] - c[1]) < 2]
        if len(arms) != 2:
            O.warn(f"facades: awning {aw} has {len(arms)} arms")
            continue
        col = tuple(O.data["colors"][r[COLOR] - 1])
        b = bld(O, aw)
        piece = "ShopAwningTorn" if b == "B7" else "ShopAwningFabric"
        wrap(O, [aw] + arms, piece, back, out, tint=col, name=f"awning_{b}")
        n += 1
    return n


def edits(O):
    rows = index(O, UNIT + ("Window", "Glass", "WindowAC", "Grille", "Shutter", "Slat", "Rail", "Padlock",
                            "ShutterBox", "RollerDoor", "DockDoor", "BottomBar", "Seam", "ShopGlass",
                            "Mullion", "DoorStile", "PushBar", "Awning", "AwningArm"))
    counts = {
        "windows": windows(O, rows),
        "boarded_low": boarded_low(O, rows),
        "air_conditioners": air_conditioners(O, rows),
        "shutters": shutters(O, rows),
        "roller_doors": roller_doors(O, rows),
        "shop_fronts": shop_fronts(O, rows),
        "awnings": awnings(O, rows),
    }
    O.facade_counts = counts
