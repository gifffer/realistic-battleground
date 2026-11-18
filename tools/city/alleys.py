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


class Data:
    def __init__(self):
        self.colors, self.materials, self.folders, self.names = [], [], [], []
        self.parts, self.extras, self.remove = [], [], []
        self._index = {"c": {}, "m": {}, "f": {}, "n": {}}

    def _idx(self, kind, table, value):
        key = json.dumps(value)
        found = self._index[kind].get(key)
        if found is None:
            table.append(list(value) if isinstance(value, tuple) else value)
            found = len(table)
            self._index[kind][key] = found
        return found

    def part(self, folder, name, center, size, color, material, flags=SOLID, rot=(0, 0, 0), shape=1,
             transparency=0.0, reflectance=0.0, extra=None, parent=0):
        row = [
            shape,
            round(center[0], 3), round(center[1], 3), round(center[2], 3),
            rot[0], rot[1], rot[2],
            round(size[0], 3), round(size[1], 3), round(size[2], 3),
            self._idx("c", self.colors, tuple(color)),
            self._idx("m", self.materials, material),
            transparency, reflectance, flags,
            self._idx("f", self.folders, folder),
            self._idx("n", self.names, name),
            parent,
            0,
        ]
        if extra:
            self.extras.append(extra)
            row[18] = len(self.extras)
        self.parts.append(row)
        return len(self.parts)

    def box(self, folder, name, x0, x1, y0, y1, z0, z1, color, material, **kw):
        """An axis-aligned block from its bounds."""
        return self.part(folder, name, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
                         (x1 - x0, y1 - y0, z1 - z0), color, material, **kw)


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
        sx, sy, sz = row[7], row[8], row[9]
        b = (row[1] - sx / 2, row[1] + sx / 2, row[2] - sy / 2, row[2] + sy / 2, row[3] - sz / 2, row[3] + sz / 2)
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
# 3. Dressing: lights, pipes, posters, graffiti, rubbish, puddles, drips, steam
# =========================================================================================

P = "Alleys/Props"
L = "Alleys/Lights"


def wall_light(x, y, z, out, dead=False, flicker=False):
    """A caged bulkhead light on a wall (tag CityBulkhead: Ambience drives it)."""
    attrs = {}
    if dead:
        attrs["Dead"] = True
    if flicker:
        attrs["Flicker"] = True
    D.part(L, "WallLight", (x, y, z), (0.6, 0.8, 0.5), (70, 70, 64), "SmoothPlastic", flags=DECOR)
    D.part(L, "Bulb", (x + out[0] * 0.35, y - 0.05, z + out[1] * 0.35), (0.45, 0.45, 0.45), WARM, "Neon",
           flags=DECOR,
           shape=4, extra={"t": ["CityLamp" if (dead or flicker) else "CityBulkhead"], "a": attrs or None,
                           "l": {"type": "Point", "color": list(WARM), "range": 18, "brightness": 0.9,
                                 "name": "Light", "shadows": False}})


def sodium_lamp(x, y, z, facing):
    """A sodium yard lamp on a bracket (orange, casting down)."""
    dx, dz = facing
    D.part(L, "Bracket", (x + dx * 0.9, y + 0.4, z + dz * 0.9), (abs(dx) * 1.8 + 0.2, 0.2, abs(dz) * 1.8 + 0.2),
           METAL_DARK, "Metal", flags=DECOR)
    D.part(L, "LampHead", (x + dx * 1.8, y, z + dz * 1.8), (1.2, 0.5, 0.8), (40, 40, 42), "Metal", flags=DECOR,
           extra={"t": ["CityLamp"],
                  "l": {"type": "Spot", "color": list(SODIUM), "range": 30, "brightness": 1.6, "angle": 110,
                        "face": "Bottom", "shadows": True, "name": "Light"}})


wall_light(150, 10, 58.25, (0, 1))  # alley A, on its north wall, by the gap
wall_light(160, 9, 58.25, (0, 1), flicker=True)
wall_light(152, 10, 97.75, (0, -1))  # alley B, on its south wall
wall_light(164, 9, 97.75, (0, -1), dead=True)
wall_light(204.75, 11, 80, (-1, 0))  # courtyard, east wall (facing west), in the fenced passage
# Above the two gaps, on the ring's inner face (seen from the Yard and from under the viaduct)
wall_light(130.75, 15, 62, (-1, 0))
wall_light(130.75, 15, 94, (-1, 0), flicker=True)
sodium_lamp(204.6, 16, 96, (-1, 0))
sodium_lamp(171, 18, 56.2, (0, 1))

# Pipes running along the walls
for (x0, x1, y, z) in ((147, 169, 21.5, 58.3), (147, 169, 7.5, 97.7), (169, 205, 24.5, 56.3)):
    D.box(P, "Pipe", x0, x1, y - 0.25, y + 0.25, z - 0.25, z + 0.25, RUST, "CorrodedMetal", flags=DECOR)
for (x, z0, z1) in ((157.5, 58.0, 58.6), (166.5, 97.4, 98.0)):
    D.box(P, "Downpipe", x - 0.3, x + 0.3, FINISH, WALL_TOP, z0, z1, METAL_DARK, "Metal", flags=DECOR)


def graffiti(x, y, z, w, h, text, face, color=WHITE, rot=0):
    D.part(P, "Graffiti", (x, y, z), (w, h, 0.05), BLACK, "SmoothPlastic", flags=DECOR, transparency=1,
           rot=(0, rot, 0),
           extra={"g": {"text": text, "font": "PermanentMarker", "color": list(color), "face": face,
                        "lit": False, "bg": None, "bg_tr": 1.0, "rot": 0, "align": "Center"}})


graffiti(158, 12.5, 58.08, 10, 3, "NO COPS. NO NAMES.", "Back")
graffiti(130.95, 7, 54, 7, 2.6, "ARCHES >", "Front", (190, 180, 120), rot=90)
graffiti(155, 7, 97.92, 9, 3, "MARROW EATS ITS OWN", "Front", (170, 60, 50))
graffiti(190, 20, 56.08, 14, 4, "ARCHES", "Back", (150, 150, 140))
graffiti(178, 16.5, 71.9, 9, 2.4, "ASK FOR VIC", "Front", (190, 180, 120))
graffiti(196, 5.5, 101.92, 8, 2.5, "SLEEP LIGHT", "Front", (150, 150, 150))

# Posters peeling on the walls (a few, sun-faded)
for (x, y, z, w, h, c) in ((152, 6, 58.07, 2.4, 3.2, (150, 140, 120)), (166, 5.5, 97.93, 2.2, 3, (120, 110, 100)),
                           (199, 6, 56.07, 2.6, 3.4, (140, 120, 100))):
    D.part(P, "Poster", (x, y, z), (w, h, 0.08), c, "SmoothPlastic", flags=DECOR)

# Rubbish: trash bags, cans, newspapers, a burnt-out tyre...
def trash_bag(x, z, s=2.2):
    D.part(P, "TrashBag", (x, FINISH + s * 0.32, z), (s, s * 0.8, s * 0.9), TRASH, "Plastic", flags=PROP, shape=4)


for (x, z) in ((150.5, 64.6), (151.8, 64.2), (168, 92), (145, 96.6), (171, 60), (172.4, 59), (203, 99.5),
               (202, 100.4), (133, 59.4)):
    trash_bag(x, z, rng.uniform(1.8, 2.4))
for (x, z, r) in ((156, 60, 20), (160, 64, 75), (174, 66, 140), (190, 98, 60), (150, 92.5, 10), (198, 63, 110)):
    D.part(P, "Newspaper", (x, FINISH + 0.02, z), (1.6, 0.04, 1.1), (150, 146, 136), "SmoothPlastic", flags=DECOR,
           rot=(0, r, 0))
for (x, z) in ((165, 60), (180, 96), (188, 70), (170, 95)):
    D.part(P, "Can", (x, FINISH + 0.2, z), (0.4, 0.6, 0.4), (120, 40, 36), "Metal", flags=DECOR, shape=3,
           rot=(0, rng.uniform(0, 180), 90))
D.part(P, "Tyre", (167, FINISH + 0.4, 64.5), (0.75, 3, 3), (24, 24, 24), "Rubber", flags=PROP, shape=3, rot=(0, 0, 90))
D.part(P, "Tyre", (167, FINISH + 1.1, 64.6), (0.75, 3, 3), (24, 24, 24), "Rubber", flags=PROP, shape=3, rot=(0, 0, 90))

# Puddles (shown when it rains), drips from the tunnel, steam from a vent in alley A
for (x, z, s) in ((140, 62, 3.5), (156, 64.6, 2.6), (161, 94, 3.5), (182, 68, 4.0), (199, 97, 3.0), (190, 68, 2.5)):
    D.part(P, "Puddle", (x, FINISH + 0.02, z), (0.25, s, s), (72, 78, 90), "SmoothPlastic", flags=DECOR, shape=3,
           transparency=1, rot=(0, 0, 90), extra={"t": ["CityPuddle"], "a": {"RainOnly": False}})
for (x, y, z) in ((177.5, 12.6, 73.0), (185.0, 12.6, 78.5), (183.0, 12.6, 90.7), (190.5, 12.6, 85.5)):
    D.part(P, "Drip", (x, y, z), (0.4, 0.2, 0.4), (52, 50, 48), "Metal", flags=DECOR, transparency=1,
           extra={"t": ["CityDrip"], "fx": "drip"})
D.part(P, "SteamVent", (147.5, FINISH + 0.1, 64.8), (3, 0.2, 2.2), (50, 50, 50), "DiamondPlate", flags=DECOR,
       extra={"t": ["CitySteam"], "a": {"BaseRate": 4}, "fx": "steam_small"})

# =========================================================================================
# 4. Dumpsters and a container (cover, things to climb, to be slammed against)
# =========================================================================================

C_ = "Alleys/Cover"


def dumpster(x, z, ry, color=DUMPSTER, lid=DUMPSTER_LID, open_lid=False):
    """A wheeled dumpster (6.4 x 3.2 x 4), solid, its lid shut or flipped open."""
    rad = math.radians(ry)
    D.part(C_, "Dumpster", (x, FINISH + 0.45 + 1.6, z), (6.4, 3.2, 4), color, "Metal", flags=SOLID, rot=(0, ry, 0))
    if open_lid:
        # (lid flipped back against the wall behind)
        bx, bz = x - math.sin(rad) * 2.2, z - math.cos(rad) * 2.2
        D.part(C_, "Lid", (bx, FINISH + 0.45 + 3.2 + 1.9, bz), (6.6, 0.2, 4.2), lid, "Plastic", flags=PROP,
               rot=(-80, ry, 0))
    else:
        D.part(C_, "Lid", (x, FINISH + 0.45 + 3.3, z), (6.6, 0.2, 4.2), lid, "Plastic", flags=PROP, rot=(4, ry, 0))
    for (u, v) in ((-2.7, -1.6), (2.7, -1.6), (-2.7, 1.6), (2.7, 1.6)):
        wx = x + u * math.cos(rad) + v * math.sin(rad)
        wz = z - u * math.sin(rad) + v * math.cos(rad)
        D.part(C_, "Wheel", (wx, FINISH + 0.3, wz), (0.3, 0.6, 0.6), (20, 20, 20), "Rubber", flags=DECOR, shape=3)


dumpster(157, 61.3, 0, open_lid=True)
dumpster(150.5, 95.6, 0, color=(70, 52, 38), lid=(50, 38, 28))
dumpster(178.5, 98.8, 0)

# A rusted shipping container in the north yard, doors ajar, to climb on and hide behind
CX0, CX1, CZ0, CZ1 = 186, 204, 57, 65.2
D.box(C_, "Container", CX0, CX1, FINISH, FINISH + 8.6, CZ0, CZ1, CONTAINER, "CorrodedMetal", extra={"a": UNBREAKABLE})
for i in range(int(CX0) + 1, int(CX1), 2):
    D.box(C_, "Rib", i - 0.15, i + 0.15, FINISH + 0.2, FINISH + 8.4, CZ1, CZ1 + 0.12, CONTAINER_DARK,
          "CorrodedMetal", flags=DECOR)
D.box(C_, "Door", CX0 - 0.12, CX0, FINISH + 0.2, FINISH + 8.4, CZ0 + 0.2, CZ1 - 0.2, CONTAINER_DARK, "CorrodedMetal",
      flags=DECOR)
D.box(C_, "Rust", CX0 + 2, CX0 + 9, FINISH + 0.5, FINISH + 3.5, CZ1 + 0.13, CZ1 + 0.15, RUST_DARK, "Slate",
      flags=DECOR, transparency=0.3)
# Pallets to climb on to the container
for k in range(3):
    D.box(C_, "Pallet", 182.2, 186, FINISH + k * 0.75, FINISH + 0.7 + k * 0.75, 58, 62, WOOD_OLD, "WoodPlanks",
          flags=SOLID)
D.box(C_, "Crate", 182.5, 185.5, FINISH + 2.25, FINISH + 5.25, 58.5, 61.5, WOOD, "WoodPlanks", flags=SOLID)

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
    breakable("LowWall", x0, x0 + 2.5, FINISH, FINISH + 4.2 - (0.6 if i == 2 else 0), 66.6, 67.6, BRICK[i % 4],
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
# 6. The black market (north arch) and the squat (south arch)
# =========================================================================================

MK = "Alleys/Market"
SQ = "Alleys/Squat"
N_ = "Alleys/Npcs"

# -- Market: a blue tarp on poles in front of the arch, tables of stolen goods, crates, a
# flickering broken neon, string lights under the arch.
mx0, mx1 = MARKET
D.part(MK, "Tarp", ((mx0 + mx1) / 2, 10.6, 68.6), (14, 0.12, 7.4), TARP_BLUE, "Fabric", flags=PROP, rot=(-12, 0, 0))
for px in (mx0 - 0.4, mx1 + 0.4):
    D.box(MK, "Pole", px - 0.15, px + 0.15, FINISH, 10.0, 65.2, 65.5, METAL, "Metal", flags=PROP)
    D.box(MK, "Rope", px - 0.03, px + 0.03, 10.0, 11.6, 65.3, 65.4, (120, 110, 90), "Fabric", flags=DECOR)
# folding tables
for (x0, x1, z0, z1) in ((176.5, 181.5, 69.2, 71.6), (182.5, 186.5, 69.6, 71.6)):
    D.box(MK, "Table", x0, x1, FINISH + 2.6, FINISH + 2.8, z0, z1, (88, 84, 78), "Plastic", flags=PROP)
    for (lx, lz) in ((x0 + 0.2, z0 + 0.2), (x1 - 0.2, z0 + 0.2), (x0 + 0.2, z1 - 0.2), (x1 - 0.2, z1 - 0.2)):
        D.box(MK, "Leg", lx - 0.06, lx + 0.06, FINISH, FINISH + 2.6, lz - 0.06, lz + 0.06, METAL, "Metal", flags=DECOR)
# goods on the tables: phones, watches, a car stereo, boxed sneakers, a laptop, bottles
TOP = FINISH + 2.8
goods = [
    ((177.2, 70.0), (0.35, 0.05, 0.7), (20, 20, 22), "Glass"),
    ((177.8, 70.2), (0.35, 0.05, 0.7), (30, 30, 34), "Glass"),
    ((178.4, 69.9), (0.35, 0.05, 0.7), (24, 24, 26), "Glass"),
    ((179.6, 70.6), (1.8, 0.6, 1.0), (40, 40, 44), "Plastic"),
    ((180.9, 70.0), (0.9, 0.12, 0.7), (160, 150, 130), "Metal"),
    ((183.4, 70.4), (1.6, 0.9, 1.0), (180, 170, 160), "SmoothPlastic"),
    ((185.3, 70.5), (1.6, 0.9, 1.0), (60, 60, 64), "SmoothPlastic"),
    ((184.4, 70.6), (1.4, 0.08, 1.0), (30, 30, 34), "Metal"),
]
for (gx, gz), size, color, mat in goods:
    D.part(MK, "Goods", (gx, TOP + size[1] / 2, gz), size, color, mat, flags=DECOR, rot=(0, rng.uniform(-12, 12), 0))
for k, (gx, gz) in enumerate(((181.8, 69.8), (182.1, 70.4), (186.0, 69.9))):
    D.part(MK, "Bottle", (gx, TOP + 0.45, gz), (0.3, 0.9, 0.3), GLASS_GREEN if k % 2 else GLASS_BROWN, "Glass",
           flags=DECOR, shape=3, rot=(0, 0, 90), transparency=0.2)
# crates stacked inside the arch, a TV on top, a rack of jackets
for (x, y, z) in ((176.6, 0, 76), (176.6, 3, 76.2), (179.8, 0, 77.4), (184.6, 0, 77.6), (184.4, 3, 77.4)):
    D.box(MK, "Crate", x - 1.5, x + 1.5, FINISH + y, FINISH + y + 3, z - 1.5, z + 1.5, WOOD, "WoodPlanks", flags=SOLID)
D.part(MK, "TV", (176.6, FINISH + 6 + 1.0, 76.2), (2.4, 2.0, 1.6), (34, 34, 36), "SmoothPlastic", flags=PROP)
D.part(MK, "Screen", (176.6, FINISH + 7.05, 75.39), (2.0, 1.6, 0.04), (40, 60, 70), "Glass", flags=DECOR)
D.box(MK, "Rack", 180.4, 183.6, FINISH + 4.6, FINISH + 4.75, 78.6, 78.75, METAL, "Metal", flags=DECOR)
for k in range(4):
    D.part(MK, "Jacket", (180.9 + k * 0.8, FINISH + 3.4, 78.7), (0.7, 2.2, 0.35),
           [(40, 36, 32), (60, 54, 46), (30, 34, 40), (70, 30, 30)][k], "Fabric", flags=DECOR)
# a broken neon in the arch: "BUY · SELL", the S dead, flickering
D.part(MK, "NeonSign", ((mx0 + mx1) / 2, 11.1, 72.3), (6.8, 1.2, 0.1), BLACK, "SmoothPlastic", flags=DECOR,
       extra={"t": ["CityNeon"], "a": {"Color": "red", "Flicker": "random"},
              "l": {"type": "Point", "color": list(RED_NEON), "range": 14, "brightness": 1.2, "name": "Light",
                    "shadows": False},
              "g": {"text": "BUY · ELL", "font": "Oswald", "color": list(RED_NEON), "face": "Front", "lit": True,
                    "bg": None, "bg_tr": 1.0, "rot": 0, "align": "Center"}})
# string lights under the arch
for k in range(6):
    x = mx0 + 1 + k * 2
    D.part(MK, "Bulb", (x, ARCH_TOP - 1.4 - (0.5 if k % 2 else 0.2), 74.5), (0.35, 0.35, 0.35), WARM, "Neon",
           flags=DECOR, shape=4,
           extra={"t": ["CityBulkhead"],
                  "l": {"type": "Point", "color": list(WARM), "range": 10, "brightness": 0.8, "name": "Light",
                        "shadows": False}})
# a caged work lamp hanging under the tarp, lighting the tables
D.box(MK, "Cord", 180.97, 181.03, 8.6, 10.6, 69.47, 69.53, BLACK, "SmoothPlastic", flags=DECOR)
D.part(MK, "WorkLamp", (181, 8.4, 69.5), (0.8, 0.6, 0.8), (60, 60, 56), "Metal", flags=DECOR,
       extra={"t": ["CityBulkhead"],
              "l": {"type": "Spot", "color": [255, 196, 140], "range": 20, "brightness": 1.5, "angle": 120,
                    "face": "Bottom", "shadows": True, "name": "Light"}})
D.box(MK, "Wire", mx0 + 0.6, mx1 - 0.6, ARCH_TOP - 1.25, ARCH_TOP - 1.2, 74.47, 74.53, BLACK, "SmoothPlastic",
      flags=DECOR)
# the dealer, standing by his tables, facing the yard (north)
D.part(N_, "NpcSpot", (181.5, FINISH, 72.8), (1, 1, 1), BLACK, "SmoothPlastic", flags=DECOR, transparency=1,
       extra={"a": {"NpcRole": "Dealer", "NpcName": "Vic", "NpcPose": "ArmsCrossed", "NpcSeed": 31}})

# -- Squat: mattresses, cardboard, blankets, a shopping cart, empties, a burn barrel outside.
sx0, sx1 = SQUAT
D.box(SQ, "Mattress", 185.6, 189.4, FINISH, FINISH + 0.7, 86.2, 91.0, MATTRESS, "Fabric", flags=PROP)
D.box(SQ, "Stain", 186.4, 188.4, FINISH + 0.7, FINISH + 0.72, 87.2, 89.7, MATTRESS_STAIN, "Fabric", flags=DECOR)
D.part(SQ, "Blanket", (187.5, FINISH + 0.85, 89.0), (3.6, 0.25, 3.2), BLANKET, "Fabric", flags=DECOR, rot=(0, 8, 2))
D.box(SQ, "Mattress", 189.4, 192.8, FINISH, FINISH + 0.6, 85.0, 89.8, (130, 122, 104), "Fabric", flags=PROP)
D.part(SQ, "Blanket", (191.1, FINISH + 0.75, 86.4), (3.0, 0.2, 2.6), BLANKET2, "Fabric", flags=DECOR, rot=(0, -10, 0))
for (x, z, r, w, d) in ((182.4, 88.6, 5, 2.2, 3.0), (188.6, 89.4, -20, 2.0, 2.6), (192.0, 91.2, 30, 2.6, 2.0)):
    D.part(SQ, "Cardboard", (x, FINISH + 0.03, z), (w, 0.06, d), CARDBOARD_DARK, "SmoothPlastic", flags=DECOR,
           rot=(0, r, 0))
# a cardboard wall leaning in the arch's mouth, boxes as a table
D.part(SQ, "Cardboard", (181.6, FINISH + 2.0, 90.8), (0.08, 4.0, 3.2), CARDBOARD, "SmoothPlastic", flags=PROP,
       rot=(0, 0, -10))
D.box(SQ, "Box", 187.8, 189.2, FINISH, FINISH + 1.4, 84.4, 86.0, CARDBOARD, "SmoothPlastic", flags=PROP)
D.part(SQ, "Candle", (188.5, FINISH + 1.55, 85.2), (0.2, 0.3, 0.2), (220, 210, 180), "SmoothPlastic", flags=DECOR,
       shape=3, rot=(0, 0, 90),
       extra={"l": {"type": "Point", "color": [255, 170, 90], "range": 7, "brightness": 0.6, "name": "Light",
                    "shadows": False}})
for k, (x, z) in enumerate(((183.2, 91.5), (183.7, 91.7), (191.6, 84.6), (184.6, 91.4))):
    D.part(SQ, "Bottle", (x, FINISH + 0.15, z), (0.3, 0.9, 0.3), GLASS_GREEN if k % 2 else GLASS_BROWN, "Glass",
           flags=DECOR, shape=3, rot=(rng.uniform(-20, 20), rng.uniform(0, 180), 0 if k == 1 else 90),
           transparency=0.2)
# a shopping cart full of junk
CART = (195.6, 96.5)
cx, cz = CART
D.box(SQ, "CartBasket", cx - 1.6, cx + 1.6, FINISH + 1.4, FINISH + 3.4, cz - 1.0, cz + 1.0, (150, 150, 150), "Metal",
      flags=PROP, transparency=0.55)
D.box(SQ, "CartJunk", cx - 1.4, cx + 1.4, FINISH + 1.6, FINISH + 3.8, cz - 0.8, cz + 0.8, (60, 52, 46), "Fabric",
      flags=DECOR)
D.box(SQ, "CartHandle", cx + 1.6, cx + 1.8, FINISH + 3.4, FINISH + 3.6, cz - 1.0, cz + 1.0, (40, 40, 40), "Metal",
      flags=DECOR)
for (u, v) in ((-1.4, -0.8), (1.4, -0.8), (-1.4, 0.8), (1.4, 0.8)):
    D.part(SQ, "Wheel", (cx + u, FINISH + 0.3, cz + v), (0.25, 0.6, 0.6), (20, 20, 20), "Rubber", flags=DECOR, shape=3)
    D.box(SQ, "CartLeg", cx + u - 0.04, cx + u + 0.04, FINISH + 0.6, FINISH + 1.4, cz + v - 0.04, cz + v + 0.04,
          (150, 150, 150), "Metal", flags=DECOR)
# the burn barrel, outside the arch (the city's: CityFire + CityFireEmbers with its light and fire)
BX, BZ = 187.6, 96.0
D.part(SQ, "BurnBarrel", (BX, FINISH + 1.6, BZ), (3.2, 2.4, 2.4), (64, 40, 30), "CorrodedMetal", flags=PROP, shape=3,
       rot=(0, 0, 90), extra={"t": ["CityFire"]})
D.part(SQ, "Embers", (BX, FINISH + 3.28, BZ), (0.15, 2, 2), (255, 120, 40), "Neon", flags=DECOR, shape=3,
       rot=(0, 0, 90),
       extra={"t": ["CityFireEmbers"],
              "l": {"type": "Point", "color": [255, 130, 50], "range": 18, "brightness": 1.6, "name": "Light",
                    "shadows": False},
              "fx": "fire"})
# milk crates as seats around it
for (x, z) in ((185.0, 96.4), (190.2, 95.4)):
    D.box(SQ, "MilkCrate", x - 0.7, x + 0.7, FINISH, FINISH + 1.3, z - 0.7, z + 0.7, (40, 70, 120), "Plastic", flags=PROP)
# the vagrant, sitting on the ground against the arch's back wall, facing out (south)
D.part(N_, "NpcSpot", (183.3, FINISH, 84.8), (1, 1, 1), BLACK, "SmoothPlastic", flags=DECOR, transparency=1,
       rot=(0, 180, 0),
       extra={"a": {"NpcRole": "Vagrant", "NpcName": "Old Ray", "NpcPose": "SitGround", "NpcSeed": 47}})

# =========================================================================================
# 7. Improvised weapons: spawn markers at the edges of the whole map and in the alleys
# =========================================================================================

WS_ALLEY = "Alleys/WeaponSpawns"
WS_CITY = "Extras/WeaponSpawns"
KINDS = ["IronBar", "Bottle", "Plank"]


LENGTH = {"IronBar": 3.2, "Plank": 3.2, "Bottle": 1.0, "Random": 3.2}


def boxes_all():
    for row, b in city_parts():
        if row[12] < 1:
            yield b
    for row in D.parts:
        if row[12] >= 1:
            continue
        sx, sy, sz = row[7], row[8], row[9]
        yield (row[1] - sx / 2, row[1] + sx / 2, row[2] - sy / 2, row[2] + sy / 2, row[3] - sz / 2, row[3] + sz / 2)


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
                if b[2] < base + 3.0 and b[3] > base + 0.15:
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
    for (dx, dz) in ((0, 0), (0.8, 0), (-0.8, 0), (0, 0.8), (0, -0.8), (1.6, 0), (-1.6, 0), (0, 1.6), (0, -1.6)):
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
weapon_spawn(WS_ALLEY, 166, 92.0, "Bottle")
weapon_spawn(WS_ALLEY, 171.5, 64.0, "Plank", 15)
weapon_spawn(WS_ALLEY, 197.5, 99.0, "Bottle")
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
    weapon_spawn(WS_CITY, x, z, KINDS[k % 3])
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
    with open(OUT, "w") as f:
        f.write(header + "return [==[" + text + "]==]\n")
    print(f"wrote {os.path.normpath(OUT)}: {len(D.parts)} parts, {len(D.remove)} city parts replaced, "
          f"{placed} weapon spots on the city's edges, {len(text) // 1024} KB")


if __name__ == "__main__":
    main()
