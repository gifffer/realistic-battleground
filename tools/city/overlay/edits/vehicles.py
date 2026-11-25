"""The city's vehicles as kit meshes (tools/city/kit/pieces/vehicles.py): the eight parked sedans
(Props/Cars, Lot 9, the crossroads taxi, the one up on stands at Ferro's), and the Yard's box van.

Every car's old parts (CarBody, CarDeck, CarCabin, screens, roof, wheels, lamps...) are wrapped
under ONE MeshProp marker of the right piece, placed exactly on the old car: the marker's pivot
is the old body's centre on the ground (the van: under its box), turned by the old yaw. PropKit
then keeps what collides (body, deck, cabin, screens, roof, the wreck's hood, the van's box / cab
/ roof) as invisible KitProxy parts with the same collision, hands the taxi's blinking Hazard
neon over to the mesh's Glow lamps, and drops the pure decoration. Without the kit, or if the
city moved a car, the old parts stay.

    Props/Cars  (-12, -115)  dark blue      -> Sedan
    Props/Cars  ( 12,   38)  grey           -> SedanWorn
    Lot 9       (92.5, -109.5) black        -> Sedan
    Lot 9       (92.5,  -94.5) navy         -> SedanWorn
    Lot 9       (52.5, -111.5) near black   -> Sedan (a clean one between the two worn)
    Lot 9       (71.5,  -89.5) rust wreck   -> SedanWrecked (its hood buckled up like the proxy,
                                               no rear-right wheel like the data)
    Crossroads  (10.6,  -89)   yellow taxi  -> SedanTaxi (Hazard -> the mesh's amber lamps)
    Ferro       (-87.5, -77.5) up on stands -> SedanOnJacks (wheels off: two stacks of kit tyres
                                               on the forecourt, hood open)
    Yard        (40.75,   25)  Halvorsen    -> BoxVanWorn; its Livery sign is NOT wrapped (its
                                               SurfaceGui would be hidden): the sign part turns
                                               invisible, the text stays, 0.05 off the new box.

Tints: each car's own body colour from the data, weathered a little per copy (meshprop
variation from its position), the wreck a faded paint so its rust reads.
"""

import math

import meshprop
from meshprop import variation, weathered
from overlay.citydata import RY, SX, X, Y, Z, folder_of, name_of
from overlay.core import DECOR

CAR_PARTS = {"CarBody", "CarDeck", "HoodNose", "BootLip", "CarCabin", "Windscreen", "RearScreen", "CarRoof",
             "Pillar", "ArchLip", "DoorSeam", "Mirror", "Wheel", "Rim", "Bumper", "Grille", "Plate", "Headlight",
             "TailLight", "Hazard", "TaxiSign", "Hood", "DentPanel", "JackStand"}
VAN_PARTS = {"VanBody", "VanCab", "CabGlass", "CabRoof", "Windscreen", "Seam", "ArchLip", "RubStrip", "Mirror",
             "DoorSplit", "DoorHandle", "Plate", "TailLight", "Grille", "Headlight", "Wheel", "Rim", "Bumper"}

# (folder, CarBody centre (x, z), piece, tint or None = the data's body colour)
CARS = (
    ("Props/Cars", (-12.0, -115.0), "Sedan", None),
    ("Props/Cars", (12.0, 38.0), "SedanWorn", None),
    ("Zones/Lot9", (92.5, -109.5), "Sedan", None),
    ("Zones/Lot9", (92.5, -94.5), "SedanWorn", None),
    ("Zones/Lot9", (52.5, -111.5), "Sedan", None),
    ("Zones/Lot9", (71.5, -89.5), "SedanWrecked", (98, 108, 96)),
    ("Zones/Crossroads", (10.6, -89.0), "SedanTaxi", None),
    ("Zones/Ferro", (-87.5, -77.5), "SedanOnJacks", None),
)
BODY_ABOVE_GROUND = 1.6  # the CarBody's centre over the ground (its wheels' contact)
JACK_LIFT = 1.05  # the Ferro car: body 1.05 higher, on stands


def _local(r, cx, cz, ry):
    """(lx, lz) of row r in the frame of a body at (cx, cz) turned ry (Roblox yaw)."""
    c, s = math.cos(math.radians(ry)), math.sin(math.radians(ry))
    dx, dz = r[X] - cx, r[Z] - cz
    return dx * c - dz * s, dx * s + dz * c


def _instance(O, folder, body_name, at, names, half=(4.6, 9.0)):
    """The body row near `at` and every row of `folder` named in `names` inside the body's
    local box (half extents in x / z): [Match], body row."""
    rows = O.data["parts"]
    body = None
    for i, r in enumerate(rows):
        if i in O.skip or folder_of(O.data, r) != folder or name_of(O.data, r) != body_name:
            continue
        if math.dist((r[X], r[Z]), at) < 0.3:
            body = r
            break
    if body is None:
        O.error(f"vehicles: no {body_name} in {folder} at {at}")
        return [], None
    ms = []
    for i, r in enumerate(rows):
        if i in O.skip or folder_of(O.data, r) != folder or name_of(O.data, r) not in names:
            continue
        lx, lz = _local(r, body[X], body[Z], body[RY])
        if abs(lx) <= half[0] and abs(lz) <= half[1]:
            ms.append(O.match(folder, name_of(O.data, r), tuple(r[X:X + 3])))
    return ms, body


def _size(piece, fallback):
    info = meshprop.pieces().get(piece)
    if info is None:
        return fallback  # (the piece is not in the committed kit yet: the marker's box by hand)
    return tuple(max(abs(info["min"][i]), abs(info["max"][i])) * 2 for i in range(3))


def _color(O, r):
    return tuple(O.data["colors"][r[10] - 1])


def cars(O):
    for folder, at, piece, tint in CARS:
        ms, body = _instance(O, folder, "CarBody", at, CAR_PARTS)
        if body is None:
            continue
        v = variation("city_vehicles", folder, at[0], at[1])
        ground = body[Y] - BODY_ABOVE_GROUND - (JACK_LIFT if piece == "SedanOnJacks" else 0.0)
        colour = weathered(tint or _color(O, body), v, 5, 0.08)
        O.wrap(ms, piece, (body[X], round(ground, 3), body[Z]), ry=body[RY], tint=colour,
               size=_size(piece, (6.7, 6.4 if piece == "SedanOnJacks" else 5.2, 15.8)),
               name=f"car_{folder.split('/')[-1]}_{at[0]}_{at[1]}")


def ferro_tyres(O):
    """The four wheels Ferro took off the car on stands: two stacks of two tyres on the
    forecourt, in front of and behind the car (kit Tyre, no fallback: only with the kit)."""
    floor = 1.255  # (the forecourt's top)
    with O.entry("ferro_tyres"):
        for n, (x, z) in enumerate(((-99.3, -78.6), (-76.9, -77.9))):
            y = floor
            for k in range(2):
                v = variation("city_vehicles_tyre", n, k)
                fr = (x + v.uniform(-0.15, 0.15), round(y, 3), z + v.uniform(-0.15, 0.15))
                _bare(O, "Zones/Ferro", "TyreBald" if (n + k) % 3 == 2 else "Tyre", fr, ry=v.uniform(0, 360),
                      rx=v.uniform(-1.5, 1.5), rz=v.uniform(-1.5, 1.5), scale=1.05)
                y += 0.75 * 1.05 + 0.02


def _bare(O, folder, piece, pos, ry=0.0, rx=0.0, rz=0.0, scale=1.0):
    """A marker with no fallback parts (as reuse.bare_at)."""
    info = meshprop.pieces()[piece]
    size = tuple(max(0.05, max(abs(info["min"][i]), abs(info["max"][i])) * 2 * scale) for i in range(3))
    attrs = {"Piece": piece}
    if scale != 1.0:
        attrs["Scale"] = round(float(scale), 3)
    return O.add(folder, "MeshProp", pos, size, (128, 128, 128), "SmoothPlastic", rot=(rx, ry, rz),
                 transparency=1.0, flags=DECOR, extra={"a": attrs})


def van(O):
    ms, body = _instance(O, "Zones/Yard", "VanBody", (40.75, 25.0), VAN_PARTS, half=(4.3, 12.0))
    if body is None:
        return
    v = variation("city_vehicles", "van")
    colour = weathered(_color(O, body), v, 4, 0.08)
    # (the van's local front is +Z in the data; the piece's front is -Z: turned half a turn)
    ground = body[Y] - body[SX + 1] / 2 - 0.8
    with O.entry("van_yard"):
        O.wrap(ms, "BoxVanWorn", (body[X], round(ground, 3), body[Z]), ry=body[RY] + 180, tint=colour,
               size=_size("BoxVanWorn", (8.3, 8.4, 23.2)), name="van_yard_wrap")
        livery = _livery(O, body)
        if livery is not None:
            O.set(livery, transparency=1.0)


def _livery(O, body):
    for i, r in enumerate(O.data["parts"]):
        if i in O.skip or folder_of(O.data, r) != "Zones/Yard" or name_of(O.data, r) != "Livery":
            continue
        if math.dist((r[X], r[Z]), (body[X], body[Z])) < 6:
            return O.match("Zones/Yard", "Livery", tuple(r[X:X + 3]))
    O.error("vehicles: the van's Livery sign not found")
    return None


def edits(O):
    cars(O)
    ferro_tyres(O)
    van(O)

