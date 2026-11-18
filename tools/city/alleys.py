"""Generates src/server/Systems/City/AlleyData.luau: the two alleys along the
railway viaduct, east of the ring, and their hidden courtyard under the rail
tunnel (black market + squat), plus the improvised-weapon spawn markers spread
along the edges of the whole map.

    venv/bin/python -I tools/city/alleys.py

The data has the same format as the city's (City/init.luau reads both): parts
rows [shape, x, y, z, rx, ry, rz, sx, sy, sz, color, material, transparency,
reflectance, flags, folder, name, parent, extra] with their own colors /
materials / folders / names / extras tables, plus "remove": city parts that are
replaced (the ring blocks a gap is cut into, the east bounds wall). City/init
merges them into the city's data before building, so everything (tags,
lights, particles, NPC spots, weather, zones) works exactly as for the rest of
the city.

Layout (studs; road surface Y = 1.2; north = -Z, east = +X):
  • Alley A (north of the viaduct): from the Yard's dead-end pocket (X 117..131,
    Z 58..66) through a gap cut in the ring wall E3, east to X 169.
  • Alley B (south of the viaduct): from the cobbles under the viaduct's east
    end through a gap cut in the viaduct's ring block E4, east to X 169.
  • Both open into the courtyard X 169..205, Z 56..102, under the rail tunnel
    (which runs overhead at Y 27..42). A brick viaduct under the tunnel holds
    two railway arches: the BLACK MARKET (north arch, opening on the north
    yard) and the SQUAT (south arch, opening on the south strip).
"""

import json
import math
import os
import random
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
CITY_DIR = os.path.join(ROOT, "src", "server", "Systems", "City")
OUT = os.path.join(CITY_DIR, "AlleyData.luau")

FLOOR = 1.2  # road surface
FINISH = 1.255  # top of the area floors (like the city's)

COLLIDE, QUERY, SHADOW = 1, 2, 4
SOLID = COLLIDE | QUERY | SHADOW
PROP = COLLIDE | QUERY  # (small props: no shadow)
DECOR = 0  # no collision, no query, no shadow
GHOST = COLLIDE  # invisible walls

# -- palette (taken from the city's data, so it matches) --------------------------------------
BRICK = [(84, 60, 50), (96, 64, 52), (68, 49, 42), (80, 44, 36)]
SOOT = (40, 36, 34)
MORTAR = (112, 106, 96)
CONCRETE = (96, 92, 86)
CONCRETE_DARK = (70, 68, 64)
ASPHALT = (46, 47, 50)
COBBLE = (62, 60, 58)
METAL = (58, 62, 64)
METAL_DARK = (46, 44, 42)
RUST = (89, 47, 30)
RUST_DARK = (59, 29, 19)
WOOD = (104, 87, 60)
WOOD_OLD = (78, 66, 50)
WOOD_DARK = (58, 46, 36)
GRANITE = (91, 87, 81)
TUNNEL = (16, 16, 18)
TARP_BLUE = (38, 56, 74)
TARP_GREEN = (52, 62, 44)
CARDBOARD = (138, 112, 78)
CARDBOARD_DARK = (106, 86, 60)
MATTRESS = (146, 136, 112)
MATTRESS_STAIN = (110, 92, 66)
BLANKET = (72, 46, 44)
BLANKET2 = (58, 66, 72)
DUMPSTER = (44, 61, 49)
DUMPSTER_LID = (32, 49, 37)
CONTAINER = (112, 52, 40)
CONTAINER_DARK = (84, 38, 30)
WARM = (255, 176, 110)
SODIUM = (255, 150, 70)
BLACK = (18, 18, 20)
TRASH = (21, 20, 23)
GLASS_GREEN = (40, 72, 46)
GLASS_BROWN = (72, 46, 24)
RED_NEON = (210, 40, 52)
WHITE = (180, 180, 170)


import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import citykit  # noqa: E402
import props_ground as PG  # noqa: E402
import props_objects as PO  # noqa: E402
import props_walls as PW  # noqa: E402

Data = citykit.Data

D = Data()
rng = random.Random(7)

# =========================================================================================
# Reading the city (to cut the gaps and to check the weapon spots are free)
# =========================================================================================


def load_city():
    pieces = []
    index = 1
    while True:
        path = os.path.join(CITY_DIR, f"CityData{index}.luau")
        if not os.path.exists(path):
            break
        text = open(path).read()
        pieces.append(re.search(r"\[==\[(.*)\]==\]", text, re.S).group(1))
        index += 1
    return json.loads("".join(pieces))


CITY = load_city()


REMOVED = set()  # (ids of the city rows replaced here)


def city_parts():
    for row in CITY["parts"]:
        if id(row) in REMOVED:
            continue
        x, y, z, sx, sy, sz = row[1], row[2], row[3], row[7], row[8], row[9]
        yield row, (x - sx / 2, x + sx / 2, y - sy / 2, y + sy / 2, z - sz / 2, z + sz / 2)


def find(folder, name, near):
    """The city part of that folder / name whose centre is at `near` (must exist, once)."""
    hits = []
    for row, b in city_parts():
        if CITY["folders"][row[15] - 1] == folder and CITY["names"][row[16] - 1] == name:
            if all(abs(row[1 + i] - near[i]) < 0.05 for i in range(3)):
                hits.append((row, b))
    assert len(hits) == 1, (folder, name, near, len(hits))
    return hits[0]


def replace(folder, name, near, pieces, extra_attr=None):
    """Removes a city block and rebuilds it as several boxes (same look), e.g. with a gap."""
    row, _ = find(folder, name, near)
    REMOVED.add(id(row))
    D.remove.append({"folder": folder, "name": name, "at": [row[1], row[2], row[3]]})
    color = tuple(CITY["colors"][row[10] - 1])
    material = CITY["materials"][row[11] - 1]
    for (x0, x1, y0, y1, z0, z1) in pieces:
        D.box(folder, name, x0, x1, y0, y1, z0, z1, color, material, flags=row[14],
              transparency=row[12], reflectance=row[13],
              extra={"a": extra_attr} if extra_attr else None)


def free_spot(x, z, radius=1.6, height=4.0):
    """No solid city part (nor alley part) in a small column above the floor at (x, z)."""
    for row, b in city_parts():
        if not (row[14] & COLLIDE):
            continue
        if b[0] < x + radius and b[1] > x - radius and b[4] < z + radius and b[5] > z - radius:
            if b[2] < FLOOR + height and b[3] > FLOOR + 0.3:
                return False
    for row in D.parts:
        b = aabb(row)
        if not (row[14] & COLLIDE):
            continue
        if b[0] < x + radius and b[1] > x - radius and b[4] < z + radius and b[5] > z - radius:
            if b[2] < FLOOR + height and b[3] > FLOOR + 0.3:
                return False
    return True


def floor_at(x, z):
    """Top of the highest floor-like city part under (x, z) below Y 3 (sidewalk, area floor...)."""
    top = FLOOR
    for row, b in city_parts():
        if b[0] <= x <= b[1] and b[4] <= z <= b[5] and b[3] <= 3.0 and (row[14] & COLLIDE):
            top = max(top, b[3])
    return top


# =========================================================================================
# 1. Cutting the ring: gaps in E3 (alley A) and E4 (alley B), the east bounds wall
# =========================================================================================

UNBREAKABLE = {"Unbreakable": True}
GAP_TOP = 13.2  # lintels start here

# E3: X 131..147, Y 1.2..47.2, Z -17..71 -> gap Z 58..66 under Y 13.2
replace("Ring/E3", "E3", (139, 24.2, 27), [
    (131, 147, 1.2, 47.2, -17, 58),
    (131, 147, 1.2, 47.2, 66, 71),
    (131, 147, GAP_TOP, 47.2, 58, 66),
], UNBREAKABLE)
# E4 base: X 131..147, Y 1.2..28.2, Z 71..99 -> gap Z 90..98 under Y 13.2
replace("Ring/E4", "E4", (139, 14.7, 85), [
    (131, 147, 1.2, 28.2, 71, 90),
    (131, 147, 1.2, 28.2, 98, 99),
    (131, 147, GAP_TOP, 28.2, 90, 98),
], UNBREAKABLE)
# The east invisible wall (X 148..149, Z -153..153): open between Z 52 and 106 (the alleys'
# own walls and their invisible walls close that stretch further east).
replace("Bounds", "InvisibleWall", (148.5, 106.2, 0), [
    (148, 149, -8.8, 221.2, -153, 52),
    (148, 149, -8.8, 221.2, 106, 153),
])

# =========================================================================================
# 2. Ground, walls, the brick viaduct under the tunnel
# =========================================================================================

G = "Alleys/Ground"
W = "Alleys/Walls"
V = "Alleys/Arches"
B = "Alleys/Bounds"

# Base slab (the city's ends at X 151) and the floors.
D.box(G, "BaseSlab", 151, 209, -0.8, FLOOR, 50, 108, ASPHALT, "Asphalt",
      extra={"t": ["CityWetSurface"]})
D.box(G, "AlleyFloor", 131, 169, -0.8, FINISH, 58, 66, COBBLE, "Cobblestone", extra={"t": ["CityWetSurface"]})
D.box(G, "AlleyFloor", 131, 169, -0.8, FINISH, 90, 98, CONCRETE_DARK, "Concrete", extra={"t": ["CityWetSurface"]})
D.box(G, "CourtFloor", 169, 205, -0.8, FINISH, 56, 102, (78, 75, 70), "Concrete", extra={"t": ["CityWetSurface"]})
# A gutter down the middle of alley A, a drain grate in each alley
D.box(G, "Gully", 131, 169, FINISH, FINISH + 0.08, 61.6, 62.4, (40, 40, 40), "Slate", flags=DECOR)
for gx, gz in ((158, 62), (162, 94), (186, 66)):
    D.box(G, "Drain", gx - 0.9, gx + 0.9, FINISH, FINISH + 0.12, gz - 0.6, gz + 0.6, (30, 30, 32), "DiamondPlate", flags=DECOR)

WALL_TOP = 30.2
COURT_TOP = 34.2


def brick_wall(name, x0, x1, z0, z1, top, color):
    """A plain brick wall (the back of a building) with a soot band at its foot."""
    D.box(W, name, x0, x1, FLOOR, top, z0, z1, color, "Brick", extra={"a": UNBREAKABLE})


# alley A, north side: a wall with an old doorway (boarded up, a storeroom behind it)
DOOR_X0, DOOR_X1 = 163, 167
brick_wall("BackWall", 147, DOOR_X0 - 1, 54, 58, WALL_TOP, BRICK[0])
brick_wall("BackWall", DOOR_X1 + 1, 169, 54, 58, WALL_TOP, BRICK[0])
D.box(W, "BackWall", DOOR_X0 - 1, DOOR_X1 + 1, 10.2, WALL_TOP, 54, 58, BRICK[0], "Brick", extra={"a": UNBREAKABLE})
brick_wall("BackWall", 147, 169, 98, 102, WALL_TOP, BRICK[1])  # alley B, south side
brick_wall("BackWall", 169, 209, 52, 56, COURT_TOP, BRICK[2])  # courtyard north
brick_wall("BackWall", 169, 209, 102, 106, COURT_TOP, BRICK[3])  # courtyard south
brick_wall("BackWall", 205, 209, 56, 102, COURT_TOP, BRICK[1])  # courtyard east
# Between the two alleys: the viaduct's embankment under the tunnel (granite, like E4)
D.box(V, "Embankment", 147, 169, FLOOR, 27.2, 66, 90, GRANITE, "Granite", extra={"a": UNBREAKABLE})

# The brick viaduct under the tunnel, with its two arches (north: market, south: squat)
ARCH_TOP = 13.0
MARKET = (175, 187)  # X span of the north arch, opening at Z 72, 8 deep
SQUAT = (181, 193)  # X span of the south arch, opening at Z 92, 8 deep
for (x0, x1, z0, z1) in (
    (169, 175, 72, 92),
    (175, 181, 80, 92),
    (181, 187, 80, 84),
    (187, 193, 72, 84),
    (193, 199, 72, 92),
):
    D.box(V, "Arch", x0, x1, FLOOR, ARCH_TOP, z0, z1, BRICK[0], "Brick", extra={"a": UNBREAKABLE})
D.box(V, "Arch", 169, 199, ARCH_TOP, 27.2, 72, 92, BRICK[0], "Brick", extra={"a": UNBREAKABLE})
# Inside the vaults: a sooty ceiling and back wall
D.box(V, "Vault", MARKET[0], MARKET[1], ARCH_TOP - 0.2, ARCH_TOP, 72.05, 80, SOOT, "Brick", flags=DECOR)
D.box(V, "Vault", SQUAT[0], SQUAT[1], ARCH_TOP - 0.2, ARCH_TOP, 84, 91.95, SOOT, "Brick", flags=DECOR)


def arch_trim(x0, x1, face_z, out):
    """A segmental brick arch on the face of an opening (x0..x1, top ARCH_TOP): corner fillers
    that round the top, voussoirs and a limestone keystone."""
    width = x1 - x0
    rise = 2.2
    for side in (-1, 1):
        # corner filler wedges (solid: the opening's top really is curved)
        for step in range(3):
            w = (3 - step) * 0.9
            h = (step + 1) * rise / 3
            cx = (x0 + w / 2) if side < 0 else (x1 - w / 2)
            D.box(V, "ArchFill", cx - w / 2, cx + w / 2, ARCH_TOP - h, ARCH_TOP - h + rise / 3,
                  min(face_z, face_z - out * 8), max(face_z, face_z - out * 8), BRICK[0], "Brick",
                  flags=SOLID)
    radius = width / 2 + 0.6
    cx = (x0 + x1) / 2
    cy = ARCH_TOP - rise - 0.2
    for i in range(9):
        a = math.radians(20 + i * 17.5)
        px, py = cx - radius * math.cos(a), cy + radius * math.sin(a) * (rise + 1.4) / radius
        D.part(V, "Voussoir", (px, py, face_z + out * 0.12), (1.1, 0.7, 0.25), BRICK[3], "Brick",
               flags=DECOR, rot=(0, 0, round(90 - math.degrees(a), 1)))
    D.part(V, "Keystone", (cx, cy + rise + 1.35, face_z + out * 0.16), (1.0, 1.1, 0.32), (150, 142, 128),
           "Limestone", flags=DECOR)


arch_trim(MARKET[0], MARKET[1], 72, -1)
arch_trim(SQUAT[0], SQUAT[1], 92, 1)

# The tunnel's sides are bare dark concrete: brick cladding seen from the yard
for z0, z1 in ((74.4, 75.0), (89.0, 89.6)):
    D.box(V, "Cladding", 147, 199, 27.2, 42.4, z0, z1, BRICK[2], "Brick", flags=SOLID, extra={"a": UNBREAKABLE})
D.box(V, "Cladding", 147, 199.7, 42.2, 42.6, 74.3, 89.7, (52, 50, 48), "Slate", flags=SOLID)
D.box(V, "Cladding", 198.4, 199.6, 27.2, 42.6, 74.4, 89.6, BRICK[2], "Brick", flags=SOLID)
# Iron girder edges where the tunnel sits on the brick
for z in (73.6, 90.4):
    D.box(V, "Girder", 147, 199, 26.2, 27.8, z - 0.5, z + 0.5, METAL, "Metal", flags=SOLID)
# Rust streaks down the brick under the girders
for x in (172, 190, 196):
    for z, side in ((72.0, -1), (92.0, 1)):
        D.box(V, "Streak", x - 0.4, x + 0.4, 14, 26, z + side * 0.05 - 0.03, z + side * 0.05 + 0.03, RUST_DARK,
              "Slate", flags=DECOR, transparency=0.35)

# Invisible walls (as high as the city's) on the alleys' outline
D.box(B, "InvisibleWall", 147, 209, -8.8, 221.2, 51, 52, BLACK, "SmoothPlastic", flags=GHOST, transparency=1)
D.box(B, "InvisibleWall", 147, 209, -8.8, 221.2, 106, 107, BLACK, "SmoothPlastic", flags=GHOST, transparency=1)
D.box(B, "InvisibleWall", 208, 209, -8.8, 221.2, 51, 107, BLACK, "SmoothPlastic", flags=GHOST, transparency=1)

# =========================================================================================
# 5. Breakable fences and walls (a body thrown into them goes through: Combat / Destruction)
# =========================================================================================

K = "Alleys/Breakable"


def breakable(name, x0, x1, y0, y1, z0, z1, color, material, health, kind):
    return D.box(K, name, x0, x1, y0, y1, z0, z1, color, material, flags=SOLID,
                 extra={"t": ["Breakable"], "a": {"Material": kind, "Health": health}})


# Wooden board fences closing the east passage (X 199..205) at both ends of the arches:
for z in (71.6, 92.4):
    for i in range(2):
        x0 = 199.2 + i * 2.9
        board = breakable("FenceBoard", x0, x0 + 2.8, FINISH, FINISH + 7.0, z - 0.2, z + 0.2,
                          WOOD_OLD if i == 0 else WOOD_DARK, "WoodPlanks", 50, "Wood")
        D.box(K, "Rail", x0 + 0.1, x0 + 2.7, FINISH + 1.6, FINISH + 2.0, z - 0.32, z - 0.2, WOOD_DARK, "Wood",
              flags=DECOR, parent=board)
        D.box(K, "Rail", x0 + 0.1, x0 + 2.7, FINISH + 5.4, FINISH + 5.8, z - 0.32, z - 0.2, WOOD_DARK, "Wood",
              flags=DECOR, parent=board)
# A crumbling low brick wall in the north yard (cover; breaks if someone is slammed through)
for i in range(3):
    x0 = 170.5 + i * 2.6
    breakable("LowWall", x0, x0 + 2.5, FINISH, FINISH + 4.2 - (0.6 if i == 2 else 0), 60.6, 61.6, BRICK[i % 4],
              "Brick", 120, "Brick")
# Corrugated metal sheets propped across the end of alley B's niche
for i in range(2):
    x0 = 153 + i * 3.1
    breakable("MetalSheet", x0, x0 + 3.0, FINISH, FINISH + 6.5, 90.1, 90.4, (96, 86, 72), "CorrodedMetal", 90, "Metal")
# Plywood boarding nailed over the old doorway in alley A (a dark storeroom behind it)
D.box(W, "StoreRoom", DOOR_X0 - 1, DOOR_X1 + 1, FLOOR, 9.2, 52.0, 54.0, SOOT, "Brick", flags=SOLID,
      extra={"a": UNBREAKABLE})  # (its back wall)
D.box(W, "StoreRoomFloor", DOOR_X0 - 1, DOOR_X1 + 1, -0.8, FINISH, 52.0, 58.0, (50, 46, 42), "Concrete")
for (x0, x1) in ((DOOR_X0 - 1, DOOR_X0), (DOOR_X1, DOOR_X1 + 1)):
    D.box(W, "Jamb", x0, x1, FLOOR, 9.2, 54.0, 58.0, BRICK[0], "Brick", extra={"a": UNBREAKABLE})
D.box(W, "StoreRoomCeiling", DOOR_X0 - 1, DOOR_X1 + 1, 9.2, 10.2, 52.0, 58.0, SOOT, "Concrete",
      extra={"a": UNBREAKABLE})
for i in range(2):
    x0 = DOOR_X0 + i * 2
    breakable("Boards", x0, x0 + 2, FINISH, 9.2, 57.7, 58.0, (120, 104, 76) if i == 0 else (104, 90, 66), "WoodPlanks",
              50, "Wood")
# (the BackWall of alley A must not cover the doorway: it is rebuilt around it below)

# =========================================================================================
# 6. Dressing: every place tells what happened there (prop libraries props_*.py)
# =========================================================================================
#   Alley A   the back of the "Golden Dragon", a Chinese restaurant gone bust: kitchen door,
#             extractor, overflowing dumpster, recycling, staff smoking corner, a fire escape.
#   Alley B   a demolition job stopped half-way: scaffolding, rubble, cinder blocks, cement
#             bags, rebar, cones, a warning barrier; dark (one dying lamp).
#   Yard N    Vic's black market: a canopy stall in front of the north arch, stock inside.
#   Yard S    the squat: Old Ray's arch, a tent, a cardboard shelter, a lean-to on the wall,
#             a fire drum with an armchair, a loaded shopping cart.
#   Behind    the backs of tall buildings beyond the walls (lit windows), so the alleys sit
#             in a city and not in a box.
# Lights are few and failing ("Faulty", FaultyLightController): some corners stay dark.

P = "Alleys/Props"
L = "Alleys/Lights"
F = "Alleys/Facades"
MK = "Alleys/Market"
SQ = "Alleys/Squat"
N_ = "Alleys/Npcs"
Z_ = "Alleys/Zones"
R = random.Random(1717)

OUT_N, OUT_S, OUT_W, OUT_E = 180, 0, 90, -90  # ry for a wall whose face points +Z / -Z / -X / +X


def faulty_since(start, value, extra_attrs=None):
    """Lights created since extras index `start` get Faulty = value (and other attributes)."""
    for ex in D.extras[start:]:
        if ex.get("l"):
            attrs = dict(ex.get("a") or {})
            attrs.pop("Flicker", None)
            if value is not None:
                attrs["Faulty"] = value
            if extra_attrs:
                attrs.update(extra_attrs)
            ex["a"] = attrs


def zone_folder(x, z):
    """Which folder a floor prop goes in, by where it stands."""
    if 169 <= x <= 205 and 56 <= z <= 80:
        return MK
    if 169 <= x <= 205 and 84 <= z <= 102:
        return SQ
    return P


def place(fn, x, z, ry=0.0, folder=None, floor_y=FINISH, faulty=None, **kw):
    start = len(D.extras)
    fn(D, folder or zone_folder(x, z), (x, floor_y, z), ry, R, **kw)
    if faulty is not None:
        faulty_since(start, faulty)


def wall(fn, x, z, ry, faulty=None, folder=P, **kw):
    """A wall prop: (x, z) on the wall's face at floor level, ry turns -Z out of the wall."""
    place(fn, x, z, ry, folder=folder, floor_y=FLOOR, faulty=faulty, **kw)


# -- the old lights, rebuilt: a few bulkheads (failing), the rest is dark --------------------
def wall_light(x, y, z, out, dead=False, faulty=None):
    """A caged bulkhead on a wall: CityBulkhead (dead ones CityLamp + Dead)."""
    attrs = {}
    if dead:
        attrs["Dead"] = True
    if faulty is not None:
        attrs["Faulty"] = faulty
    D.part(L, "WallLight", (x, y, z), (0.6, 0.8, 0.5), (60, 60, 56), "Metal", flags=DECOR)
    D.part(L, "Bulb", (x + out[0] * 0.35, y - 0.05, z + out[1] * 0.35), (0.45, 0.45, 0.45), WARM, "Neon",
           flags=DECOR, shape=4,
           extra={"t": ["CityLamp" if dead else "CityBulkhead"], "a": attrs or None,
                  "l": {"type": "Point", "color": list(WARM), "range": 18, "brightness": 0.9, "name": "Light",
                        "shadows": True}})


# Above the two gaps, seen from the Yard and from under the viaduct (what draws you in)
wall_light(130.75, 15, 62, (-1, 0), faulty=0.3)
wall_light(130.75, 15, 94, (-1, 0), faulty=0.85)

# -- the walls ---------------------------------------------------------------------------------
# Alley A, north side (z 58): the restaurant's back. Kitchen door, extractor, AC, meter box,
# windows above (one lit, one barred, the rest boarded), a fire escape, a gutter, posters.
wall(PW.wall_grime, 158, 58, OUT_N, width=22, height=5)
wall(PW.back_door, 151.5, 58, OUT_N, faulty=0.55, variant="closed", stencil="KITCHEN - NO ENTRY")
wall(PW.vent_hood, 155.5, 58, OUT_N, y=8.5, grease=True)
wall(PW.pipe_run, 156, 58, OUT_N, length=9, y=11.2, drop="down")
wall(PW.ac_unit, 159.5, 58, OUT_N, y=12.5)
wall(PW.meter_box, 148.4, 58, OUT_N, y=3.4)
wall(PW.window, 152, 58, OUT_N, y=12.5, variant="barred")
wall(PW.window, 160.5, 58, OUT_N, y=21.5, variant="lit", kind="tv")
wall(PW.window, 152, 58, OUT_N, y=21.5, variant="boarded")
wall(PW.window, 166, 58, OUT_N, y=21.5, variant="broken")
wall(PW.fire_escape, 162.5, 58, OUT_N, width=8, floors=2, floor_h=10)
wall(PW.downpipe, 168.2, 58, OUT_N, height=28.5, gutter=5)
wall(PW.torn_posters, 161.2, 58, OUT_N, y=4.2, width=2.8, height=3.6)
wall(PW.graffiti_tag, 155.2, 58, OUT_N, y=4.5, width=4.6, text="NO COPS. NO NAMES.")
wall(PW.plaster_patch, 165, 58, OUT_N, y=10.8, width=4, height=3)
wall(PW.building_top, 158, 58, OUT_N, width=22, top=WALL_TOP, clutter="tank")
# Alley A, south side (z 66): the viaduct's granite embankment and the ring's end
wall(PW.wall_grime, 158, 66, OUT_S, width=22, height=4, soot=True)
wall(PW.efflorescence, 152, 66, OUT_S, width=5)
wall(PW.rust_streak, 150, 66, OUT_S, y=24, length=7)
wall(PW.rust_streak, 163.5, 66, OUT_S, y=24, length=9, bolt=False)
wall(PW.graffiti_tag, 158, 66, OUT_S, y=5, width=6, text="MARROW EATS ITS OWN", color=(170, 60, 50))
wall(PW.crack, 166, 66, OUT_S, length=6, y=8)
wall(PW.wall_grime, 139, 66, OUT_S, width=16, height=4)
wall(PW.wall_grime, 139, 58, OUT_N, width=16, height=4)
wall(PW.graffiti_tag, 139, 58, OUT_N, y=3.6, width=5, text="ARCHES >", color=(190, 180, 120))
wall(PW.cable_sag, 153, 58, OUT_N, span=8, y=17, y_end=19, cables=3)
wall(PW.cable_sag, 166.5, 58, OUT_N, span=8, y=15, y_end=17, cables=2, shoes=True)

# Alley B, south side (z 98): the back of the demolition contractor's yard: a roller
# shutter, a faded painted sign, boarded windows, a dead AC, a dying lamp.
wall(PW.wall_grime, 158, 98, OUT_S, width=22, height=5)
wall(PW.roller_shutter, 158.5, 98, OUT_S, width=7, height=7)
wall(PW.painted_sign, 158, 98, OUT_S, y=17, width=14, text="KESSLER BROS · DEMOLITION & SALVAGE")
wall(PW.window, 151, 98, OUT_S, y=12.5, variant="boarded")
wall(PW.window, 165.5, 98, OUT_S, y=12.5, variant="barred")
wall(PW.window, 151, 98, OUT_S, y=22, variant="dirty")
wall(PW.ac_unit, 165.5, 98, OUT_S, y=20)
wall(PW.gooseneck_lamp, 163, 98, OUT_S, faulty=0.9, y=11, reach=2.4, color=(255, 196, 140), range_=22,
     brightness=1.0)
wall(PW.downpipe, 148.2, 98, OUT_S, height=28.5)
wall(PW.torn_posters, 153.8, 98, OUT_S, y=4, width=3, height=3.8)
wall(PW.building_top, 158, 98, OUT_S, width=22, top=WALL_TOP, clutter="antenna")
# Alley B, north side (z 90): the embankment
wall(PW.wall_grime, 158, 90, OUT_N, width=22, height=4)
wall(PW.graffiti_tag, 163.5, 90, OUT_N, y=4.5, width=5, text="SLEEP LIGHT")
wall(PW.rust_streak, 152, 90, OUT_N, y=24, length=8)
wall(PW.wall_grime, 139, 90, OUT_N, width=16, height=4)
wall(PW.wall_grime, 139, 98, OUT_S, width=16, height=4)

# The yard's walls: the backs of three buildings, 34 high
wall(PW.wall_grime, 187, 56, OUT_N, width=36, height=5)
wall(PW.back_door, 173, 56, OUT_N, faulty=0.35, variant="chained", dead_light=False)
wall(PW.window, 178, 56, OUT_N, y=13, variant="boarded")
wall(PW.window, 184, 56, OUT_N, y=13, variant="dirty")
wall(PW.window, 196, 56, OUT_N, y=13, variant="lit", kind="warm")
wall(PW.window, 178, 56, OUT_N, y=23, variant="dirty")
wall(PW.window, 190, 56, OUT_N, y=23, variant="broken")
wall(PW.window, 202, 56, OUT_N, y=23, variant="lit", kind="tv")
wall(PW.satellite_dish, 193, 56, OUT_N, y=19)
wall(PW.downpipe, 171, 56, OUT_N, height=32.5)
wall(PW.building_top, 187, 56, OUT_N, width=36, top=COURT_TOP, clutter="tank")
wall(PW.wall_grime, 205, 79, OUT_W, width=46, height=5)
wall(PW.fire_escape, 205, 66, OUT_W, width=10, floors=3, floor_h=10)
wall(PW.window, 205, 84, OUT_W, y=13, variant="barred")
wall(PW.window, 205, 98, OUT_W, y=13, variant="boarded")
wall(PW.window, 205, 84, OUT_W, y=23, variant="lit", kind="warm")
wall(PW.window, 205, 98, OUT_W, y=23, variant="dirty")
wall(PW.meter_box, 205, 88, OUT_W, y=3.4)
wall(PW.gooseneck_lamp, 205, 95, OUT_W, faulty=0.45, y=15, reach=2.6, color=(255, 150, 70), range_=30,
     brightness=1.4)
wall(PW.ac_unit, 205, 76, OUT_W, y=8)
wall(PW.building_top, 205, 79, OUT_W, width=46, top=COURT_TOP, clutter="antenna")
wall(PW.wall_grime, 187, 102, OUT_S, width=36, height=5)
wall(PW.window, 175, 102, OUT_S, y=13, variant="boarded")
wall(PW.window, 199, 102, OUT_S, y=13, variant="broken")
wall(PW.window, 187, 102, OUT_S, y=23, variant="dirty")
wall(PW.torn_posters, 192.5, 102, OUT_S, y=4, width=3.4, height=4)
wall(PW.graffiti_tag, 184, 102, OUT_S, y=6.5, width=6, text="GOD SEES ALL", color=(150, 150, 150))
wall(PW.downpipe, 203, 102, OUT_S, height=32.5)
wall(PW.building_top, 187, 102, OUT_S, width=36, top=COURT_TOP, clutter="tank")
wall(PW.cable_sag, 186, 102, OUT_S, span=10, y=16, y_end=14, cables=2)
# The arch block's faces (brick, sooty, posters and tags)
wall(PW.wall_grime, 172, 72, OUT_S, width=6, height=4)
wall(PW.wall_grime, 193, 72, OUT_S, width=12, height=4)
wall(PW.torn_posters, 171.8, 72, OUT_S, y=4, width=2.6, height=3.4)
wall(PW.graffiti_tag, 192.5, 72, OUT_S, y=6, width=5, text="ASK FOR VIC", color=(190, 180, 120))
wall(PW.rust_streak, 172, 72, OUT_S, y=26, length=10, bolt=False)
wall(PW.rust_streak, 196, 72, OUT_S, y=26, length=8, bolt=False)
wall(PW.wall_grime, 175, 92, OUT_N, width=12, height=4)
wall(PW.wall_grime, 196, 92, OUT_N, width=6, height=4)
wall(PW.rust_streak, 175, 92, OUT_N, y=26, length=9, bolt=False)
wall(PW.efflorescence, 196, 92, OUT_N, width=4)

# Beyond the walls: the backs of tall buildings, some windows lit (depth at night)
wall(PW.background_facade, 211, 80, OUT_W, folder=F, width=56, height=72, depth=12, lit_share=0.18)
wall(PW.background_facade, 188, 44, OUT_N, folder=F, width=48, height=62, depth=12, lit_share=0.2)
wall(PW.background_facade, 188, 114, OUT_S, folder=F, width=48, height=58, depth=12, lit_share=0.15)

# -- the floor: alley A (kitchen back) ----------------------------------------------------------
place(PO.dumpster, 156.6, 60.2, OUT_N, lid="open", full=True, against_wall=True)
place(PG.trash_heap, 151.6, 60.4, OUT_N, count=5)
place(PO.recycling_bin, 144.5, 60.2, OUT_N, kind="paper", lid="closed")
place(PG.cardboard_flat, 161.4, 60.0, OUT_N + 10, wet=True, torn=True)
place(PG.cardboard_box, 160.6, 61.0, 25, state="crushed")
place(PG.milk_crate, 149.6, 61.0, 15, state="upside")
place(PG.cigarette_butts, 149.8, 62.4, 0, count=9, radius=1.1)
place(PG.oil_stain, 155.8, 63.4, 30, size=3)
place(PG.damp_stain, 158.4, 63.2, 0, size=4, run=True)
place(PG.crack, 144.5, 61.5, 70, length=7)
place(PG.crack, 163.8, 64.2, -20, length=5)
place(PG.wall_base_grime, 158, 65.8, OUT_S, length=20)
place(PG.weeds, 151, 65.6, OUT_S, kind="wall", length=5)
place(PG.leaves_drift, 167.8, 64.9, OUT_S, corner=True)
place(PG.litter_scatter, 164.5, 63.0, 0, radius=2.5, density=0.8)
place(PG.tyre, 136.5, 64.6, 10, state="stack")
place(PG.paper_sheet, 140.5, 60.2, 35, kind="newspaper", wet=True)
place(PG.wrapper, 146.0, 63.3, 0, kind="takeaway")

# -- the floor: alley B (demolition job) --------------------------------------------------------
place(PO.scaffolding, 150.5, 96.2, OUT_S, bays=1, levels=2, netting=True)
place(PO.construction_barrier, 134.5, 96.3, 10, kind="aframe", banner=True)
place(PG.cinder_block, 158.0, 96.9, 0, state="stack")
place(PG.cement_bag, 160.8, 97.0, 10, torn=True)
place(PG.plank_stack, 165.5, 96.6, OUT_S, count=6)
place(PG.rubble_pile, 160.5, 92.6, 0, radius=2.2)
place(PG.rebar, 156.8, 93.6, 75, bends=1, length=4)
place(PG.loose_bricks, 163.6, 94.2, 20, count=6)
place(PO.traffic_cone, 140.2, 96.8, 0, state="standing")
place(PO.traffic_cone, 143.4, 92.6, 120, state="fallen")
place(PG.wood_scraps, 146.2, 94.6, 40, kind="planks")
place(PG.concrete_chunk, 167.2, 92.2, 10, size=1.6, rebar=True)
place(PG.paint_marks, 154.8, 94.2, 0)
place(PG.pothole, 141.8, 94.0, 0, radius=2)
place(PG.asphalt_patch, 158.2, 94.2, 5)
place(PG.wall_base_grime, 158, 90.2, OUT_N, length=20)
place(PG.leaves_drift, 168.0, 97.0, OUT_S, corner=True)

# -- the yard, north: Vic's black market ---------------------------------------------------------
start = len(D.extras)
place(PO.market_stall, 180.0, 68.2, 0, goods="electronics", light=True, compact=True)
faulty_since(start, 0.25)
for ex in D.extras[start:]:
    if ex.get("l"):
        ex["t"] = sorted(set((ex.get("t") or []) + ["CityBulkhead"]))
        ex["l"]["shadows"] = False
place(PO.wooden_crates, 177.7, 76.4, 0, count=3)
place(PO.wooden_crates, 184.2, 77.6, 180, count=2)
place(PO.clothes_rack, 181.0, 78.6, 0, count=5)
place(PO.tv, 177.7, 76.4, 10, floor_y=FINISH + 4.4, kind="crt", state="ok")
place(PO.plastic_crates, 191.0, 66.6, 90, count=4)
place(PO.shoe_boxes, 172.6, 70.6, 90, count=5)
place(PO.radio, 184.4, 75.2, 180)
# the neon in the arch (the S dead), flickering like a failing tube
D.part(MK, "NeonSign", ((MARKET[0] + MARKET[1]) / 2, 11.1, 72.3), (6.8, 1.2, 0.1), BLACK, "SmoothPlastic",
       flags=DECOR,
       extra={"t": ["CityNeon"], "a": {"Color": "red", "Flicker": "random"},
              "l": {"type": "Point", "color": list(RED_NEON), "range": 14, "brightness": 1.2, "name": "Light",
                    "shadows": False},
              "g": {"text": "BUY · ELL", "font": "Oswald", "color": list(RED_NEON), "face": "Front", "lit": True,
                    "bg": None, "bg_tr": 1.0, "rot": 0, "align": "Center"}})
D.part(N_, "NpcSpot", (181.5, FINISH, 72.8), (1, 1, 1), BLACK, "SmoothPlastic", flags=DECOR, transparency=1,
       extra={"a": {"NpcRole": "Dealer", "NpcName": "Vic", "NpcPose": "ArmsCrossed", "NpcSeed": 31}})
# the container you can climb (pallets and a crate as steps), its corner of rubbish
place(PO.shipping_container, 195.0, 61.1, 0, length=18, doors="ajar")
place(PG.pallet_stack, 183.6, 59.9, 90, count=4)
place(PO.wooden_crates, 183.6, 59.9, 90, floor_y=FINISH + 2.25, count=1)
place(PO.recycling_bin, 173.0, 58.4, OUT_N, kind="general", lid="open")
place(PG.trash_bag, 176.3, 58.0, 30, size=2.2)
place(PG.trash_bag, 177.4, 59.0, 120, size=1.9, torn=True)
place(PG.manhole, 179.0, 63.6, 0)
place(PG.crack, 186.0, 66.8, -35, length=6)
place(PG.oil_stain, 191.2, 67.8, 0, size=2.5)
place(PG.leaves_drift, 169.8, 57.4, OUT_N, corner=True)
place(PG.litter_scatter, 174.5, 66.0, 0, radius=2.2, density=0.7)
place(PG.cigarette_butts, 186.8, 66.6, 0, count=7)
# behind the fences (east passage): what nobody comes to see
place(PO.office_chair, 202.0, 75.5, 40, state="tipped")
place(PO.mattress, 204.0, 87.0, OUT_W, state="leaning", torn=True)
place(PO.wheelie_bin, 201.0, 90.4, 160, state="tipped")
place(PG.litter_scatter, 202.2, 79.0, 0, radius=1.6, density=0.6)

# -- the yard, south: the squat ---------------------------------------------------------------------
place(PO.mattress, 189.8, 87.4, 0, state="flat", torn=True)
place(PO.sleeping_bag, 189.8, 87.6, 0, floor_y=FINISH + 0.7, state="bunched")
place(PO.blankets, 186.6, 89.8, 15, kind="crumpled")
place(PO.camp_stove, 186.8, 85.6, 0, lit=True, pot=True, light=True)
place(PO.backpack, 192.2, 85.0, -20, state="standing")
place(PO.tent, 174.2, 97.0, 90, kind="ridge", open=True)
place(PO.cardboard_shelter, 180.6, 98.6, 0, blanket=True)
place(PO.lean_to, 198.0, 99.7, 0, closed_side=True)
place(PO.shopping_cart, 192.0, 99.6, 30, full=True, state="upright")
start = len(D.extras)
place(PO.oil_drum, 187.6, 96.0, 0, state="fire", light=True)
place(PO.armchair, 184.2, 97.6, -60, state="worn", blanket=True)
place(PO.camp_stool, 189.5, 97.9, 200)
place(PG.milk_crate, 186.0, 94.2, 40, state="upright")
place(PG.cardboard_flat, 174.2, 93.4, 5, wet=True)
place(PG.wrapper, 177.5, 94.0, 0, kind="foil")
place(PG.wrapper, 183.0, 94.4, 0, kind="cup")
place(PG.cigarette_butts, 185.4, 95.6, 0, count=6)
place(PG.litter_scatter, 196.0, 95.0, 0, radius=2.0, density=0.7)
place(PG.wall_base_grime, 187, 101.8, OUT_S, length=30)
place(PG.weeds, 202.0, 101.6, OUT_S, kind="wall", length=4)
place(PG.leaves_drift, 204.0, 100.8, OUT_S, corner=True)
place(PG.damp_stain, 195.0, 94.6, 90, size=3)
D.part(N_, "NpcSpot", (184.4, FINISH, 84.8), (1, 1, 1), BLACK, "SmoothPlastic", flags=DECOR, transparency=1,
       rot=(0, 180, 0),
       extra={"a": {"NpcRole": "Vagrant", "NpcName": "Old Ray", "NpcPose": "SitGround", "NpcSeed": 47}})

# -- weather and smell: puddles that show in the rain, drips under the vaults, kitchen steam --
for (x, z, s) in ((140, 62, 3.5), (161, 94, 3.5), (182, 66.8, 3.0), (199, 96.2, 2.6), (152.5, 63.6, 2.4)):
    D.part(P, "Puddle", (x, FINISH + 0.02, z), (0.25, s, s), (72, 78, 90), "SmoothPlastic", flags=DECOR, shape=3,
           transparency=1, rot=(0, 0, 90), extra={"t": ["CityPuddle"], "a": {"RainOnly": False}})
for (x, y, z) in ((177.5, 12.6, 73.0), (185.0, 12.6, 78.5), (183.0, 12.6, 90.7), (190.5, 12.6, 85.5)):
    D.part(P, "Drip", (x, y, z), (0.4, 0.2, 0.4), (52, 50, 48), "Metal", flags=DECOR, transparency=1,
           extra={"t": ["CityDrip"], "fx": "drip"})
D.part(P, "SteamVent", (147.6, FINISH + 0.1, 64.6), (3, 0.2, 2.2), (50, 50, 50), "DiamondPlate", flags=DECOR,
       extra={"t": ["CitySteam"], "a": {"BaseRate": 4}, "fx": "steam"})
D.part(P, "SteamVent", (155.5, 9.4, 58.9), (1.0, 0.2, 1.4), (50, 50, 50), "Metal", flags=DECOR, transparency=1,
       rot=(0, 90, 0),
       extra={"t": ["CitySteam"], "a": {"BaseRate": 2}, "fx": "steam_small"})

# -- the mood zones (AlleyAtmosphereController: darker, hazier inside) ---------------------------
for (x0, x1, z0, z1) in ((131, 169, 57, 67), (131, 169, 89, 99), (169, 205, 55, 103)):
    D.box(Z_, "AlleyZone", x0, x1, FLOOR, FLOOR + 26, z0, z1, (0, 0, 0), "SmoothPlastic", flags=DECOR,
          transparency=1, extra={"t": ["AlleyZone"]})

# =========================================================================================
# 7. Improvised weapons: spawn markers at the edges of the whole map and in the alleys
# =========================================================================================

WS_ALLEY = "Alleys/WeaponSpawns"
WS_CITY = "Extras/WeaponSpawns"
KINDS = ["IronBar", "Plank"]


LENGTH = {"IronBar": 3.2, "Plank": 3.2, "Random": 3.2}


def aabb(row):
    """World bounds of a part row (its rotation included)."""
    m = citykit.yxz_matrix(row[4], row[5], row[6])
    half = abs(m) @ [row[7] / 2, row[8] / 2, row[9] / 2]
    return (row[1] - half[0], row[1] + half[0], row[2] - half[1], row[2] + half[1], row[3] - half[2], row[3] + half[2])


def boxes_all():
    for row, b in city_parts():
        if row[12] < 1:
            yield aabb(row) if (row[4] or row[5] or row[6]) else b
    for row in D.parts:
        if row[12] >= 1:
            continue
        yield aabb(row)


def item_clear(x, z, ry, length, width=0.4):
    """Nothing visible (props, bags, kerbs, walls...) where the item would lie."""
    dx, dz = -math.sin(math.radians(ry)), -math.cos(math.radians(ry))
    base = floor_at(x, z)
    boxes = list(boxes_all())
    for i in range(9):
        t = i / 8 - 0.5
        px, pz = x + dx * t * (length + 0.3), z + dz * t * (length + 0.3)
        for b in boxes:
            if b[0] < px + width and b[1] > px - width and b[4] < pz + width and b[5] > pz - width:
                if b[2] < base + 3.0 and b[3] > base + 0.3:
                    return False
    return True


def weapon_ry(x, z, kind, ry=None):
    for r in ([ry] if ry is not None else [0, 30, 60, 90, 120, 150]):
        if item_clear(x, z, r, LENGTH[kind]):
            return r
    return None


def weapon_spawn(folder, x, z, kind, ry=None):
    # (the given turn first, then any; nudged a little if the spot is taken)
    found = None
    ring = [(0.0, 0.0)] + [(r * math.cos(a), r * math.sin(a)) for r in (0.8, 1.6, 2.4, 3.2) for a in
                         [i * math.pi / 4 for i in range(8)]]
    for (dx, dz) in ring:
        r = weapon_ry(x + dx, z + dz, kind, ry)
        if r is None and ry is not None:
            r = weapon_ry(x + dx, z + dz, kind)
        if r is not None:
            found = (x + dx, z + dz, r)
            break
    assert found is not None, ("weapon spot not free", x, z)
    x, z, ry = found
    y = floor_at(x, z) if folder == WS_CITY else FINISH
    D.part(folder, "WeaponSpawn", (x, y, z), (1, 1, 1), BLACK, "SmoothPlastic", flags=DECOR, transparency=1,
           rot=(0, ry, 0),
           extra={"t": ["WeaponSpawn"], "a": {"Weapon": kind}})


# in the alleys and the courtyard
weapon_spawn(WS_ALLEY, 144, 64.6, "IronBar", 90)
weapon_spawn(WS_ALLEY, 164.6, 93.4, "Plank")
weapon_spawn(WS_ALLEY, 172.0, 64.0, "Plank", 15)
weapon_spawn(WS_ALLEY, 197.5, 97.0, "IronBar")
weapon_spawn(WS_ALLEY, 201.5, 68.0, "IronBar", 0)
weapon_spawn(WS_ALLEY, 202.0, 82.0, "Random", 0)  # (behind the fences: break in to get it)

# Along the edges of the city's open ground, never mid-map: a spot is kept if it is free,
# outdoors (nothing overhead), on the street level (not a roof), right against a tall wall
# (a building's foot or the ring) and far from the middle of the map; then a spread-out set is
# picked from them (each as far as possible from the ones already picked).
CENTER = (0.0, -10.0)
SOLIDS = [b for row, b in city_parts() if row[14] & COLLIDE]


def outdoors(x, z):
    for b in SOLIDS:
        if b[0] <= x <= b[1] and b[4] <= z <= b[5] and b[2] > FLOOR + 3:
            return False
    return True


def against_wall(x, z, reach=2.6):
    for b in SOLIDS:
        if b[3] - b[2] < 8 or b[2] > FLOOR + 1:
            continue
        if b[0] - reach < x < b[1] + reach and b[4] - reach < z < b[5] + reach:
            return True
    return False


candidates = []
for gx in range(-128, 129, 2):
    for gz in range(-132, 116, 2):
        x, z = float(gx), float(gz)
        if math.hypot(x - CENTER[0], z - CENTER[1]) < 70:
            continue
        if floor_at(x, z) > 2.0 or not outdoors(x, z) or not against_wall(x, z):
            continue
        if not free_spot(x, z, 1.0, 3.0) or weapon_ry(x, z, "Random") is None:
            continue
        candidates.append((x, z))
picked = []
start = min(candidates, key=lambda c: (c[0] + 128) ** 2 + (c[1] + 132) ** 2)
picked.append(start)
WANT = 16
while len(picked) < WANT and candidates:
    best = max(candidates, key=lambda c: min(math.hypot(c[0] - p[0], c[1] - p[1]) for p in picked))
    picked.append(best)
placed = 0
for k, (x, z) in enumerate(picked):
    weapon_spawn(WS_CITY, x, z, KINDS[k % len(KINDS)])
    placed += 1
print("weapon spots on the edges:", [(round(x), round(z)) for x, z in picked])

# =========================================================================================
# Output
# =========================================================================================


def main():
    for k, row in enumerate(D.parts, start=1):
        assert row[17] < k, "a part's parent must come before it"
    data = {
        "colors": D.colors,
        "materials": D.materials,
        "folders": D.folders,
        "names": D.names,
        "parts": D.parts,
        "extras": D.extras,
        "remove": D.remove,
    }
    text = json.dumps(data, separators=(",", ":"))
    header = (
        "--!strict\n"
        "-- GENERATED by tools/city/alleys.py: do not edit by hand (change the tool, run it again).\n"
        "-- The two alleys along the viaduct, east of the ring, their courtyard (black market,\n"
        "-- squat) and the improvised-weapon spawn markers. Same format as CityData (one JSON\n"
        "-- text); City/init.luau merges it into the city's data before building.\n"
    )
    # Split in pieces of at most CHUNK characters (Studio's script size limit), like CityData:
    # AlleyData1, AlleyData2... City/init joins them in order.
    CHUNK = 150000
    for old in os.listdir(CITY_DIR):
        if re.fullmatch(r"AlleyData\d*\.luau", old):
            os.remove(os.path.join(CITY_DIR, old))
    pieces = [text[i : i + CHUNK] for i in range(0, len(text), CHUNK)]
    for n, piece in enumerate(pieces, start=1):
        assert "]==]" not in piece
        with open(os.path.join(CITY_DIR, f"AlleyData{n}.luau"), "w") as f:
            f.write(header + f"-- (piece {n} of {len(pieces)})\n" + "return [==[" + piece + "]==]\n")
    print(f"wrote {len(pieces)} AlleyData pieces: {len(D.parts)} parts, {len(D.remove)} city parts replaced, "
          f"{placed} weapon spots on the city's edges, {len(text) // 1024} KB")


if __name__ == "__main__":
    main()
