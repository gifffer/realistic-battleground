"""The park (and the three SpezCola machines) as real kit meshes (PLAN step 3, family "park"; the
pieces are in tools/city/kit/pieces/park.py): the five benches, the seven lamp posts, the twelve
trees, the three litter bins, the drinking fountain, the plaza's fountain, the bandstand and the
vending machines; the footbridge gets darker, wet, weathered timber and mossy abutments (colour
only). The old primitive parts are wrapped under each piece's MeshProp marker: PropKit keeps the
colliding ones as invisible proxies (same collisions, still breakable), hands the lamps' CityLamp
glass (tag, light) to the lanterns' Glow; without the kit (or when the city moved a part) the
old parts stay as they are.

Kept OUT of the wraps (they stay real, visible parts):
  * the fountain's water discs, jet and spray (FountainWater, FountainJet, FountainSpray): the
    basin's round inner face (r 4.3) hides the big disc's edge (r 4.4), the upper bowl's lip
    stands over its disc; their colour is made murkier here;
  * on each SpezCola machine, the parts the SpezCola systems find by name in the Model
    (SpezCola.luau / SpezColaController: "Button" with its prompt, "Dispenser", "Hum") and the
    lit "Panel" (CityShopLight, its SpezCola sign: Ambience drives it). The mesh is built round
    them: the panel sits in the bezel, the button on the selection column. The machine's other
    parts (Body included) go under a marker INSIDE the Model (force: PROTECTED_FOLDERS), so the
    Model keeps Button / Dispenser / Hum as direct children.

Every copy differs by its place (meshprop.variation): variant (worn benches, the two unlit
lamps are the neglected ones, plane / lime / autumn trees), tint (weathered), yaw where the
footprint allows it, the trees' scale from their crown. Each mesh fits its proxies within ~0.3
stud (checked numerically: tools/city/kit/pieces/park.py notes each footprint).
"""

import math

from meshprop import variation, weathered
from citykit import yxz_matrix
from overlay.citydata import RX, RY, SX, X, extra_of
from overlay.edits.reuse import Fr, pos, size, solids

# The kit pieces' extents (studs, piece space) from the kit build's pieces.json: the marker's
# size when assets/cityprops/pieces.json does not have the piece yet.
EXTENT = {
    "BandstandVictorian": ((-5.633, 0.0, -5.633), (6.43, 12.66, 5.633)),
    "DrinkingFountainCast": ((-0.82, 0.0, -1.05), (1.28, 3.515, 0.82)),
    "FountainTwoTier": ((-5.477, 0.0, -5.477), (5.477, 5.32, 5.477)),
    "HeritageLampPost": ((-0.771, 0.0, -0.6), (0.771, 11.33, 0.6)),
    "HeritageLampPostWorn": ((-0.652, 0.0, -0.6), (0.889, 11.33, 0.6)),
    "ParkBenchCast": ((-3.0, -0.016, -0.88), (3.0, 3.577, 1.074)),
    "ParkBenchCastWorn": ((-3.047, -0.016, -0.88), (3.0, 3.577, 1.074)),
    "ParkBinCast": ((-0.86, 0.0, -0.86), (0.86, 2.908, 0.86)),
    "TreeAutumn": ((-3.398, -0.05, -3.764), (4.377, 12.641, 4.645)),
    "TreeLimeYoung": ((-3.45, -0.05, -3.499), (2.952, 13.389, 3.073)),
    "TreePlaneYoung": ((-3.404, -0.101, -3.893), (4.146, 12.493, 3.627)),
    "VendingMachine": ((-1.85, 0.0, -1.575), (1.85, 7.46, 1.4)),
    "VendingMachineWorn": ((-1.85, 0.0, -1.575), (1.85, 7.46, 1.4)),
    "FlowerClumpA": ((-0.461, -0.019, -0.464), (0.461, 0.677, 0.509)),
    "FlowerClumpB": ((-0.461, -0.019, -0.464), (0.473, 0.377, 0.509)),
    "FlowerClumpC": ((-0.516, -0.023, -0.519), (0.525, 0.377, 0.570)),
    "FlowerClumpD": ((-0.479, -0.021, -0.605), (0.644, 0.510, 0.529)),
}
# The default colour of each piece's tintable layer (pieces.json "tint"): the marker always
# carries a Tint (PropKit's LOOKS grey otherwise).
TINT = {
    "BandstandVictorian": (36, 62, 48),
    "DrinkingFountainCast": (78, 70, 46),
    "HeritageLampPost": (32, 44, 38),
    "HeritageLampPostWorn": (30, 32, 31),
    "ParkBenchCast": (34, 46, 40),
    "ParkBenchCastWorn": (30, 32, 30),
    "ParkBinCast": (34, 50, 40),
    "TreeAutumn": (150, 90, 45),
    "TreeLimeYoung": (60, 88, 42),
    "TreePlaneYoung": (66, 92, 44),
    "VendingMachine": (172, 26, 32),
    "VendingMachineWorn": (160, 30, 34),
}
# The top of the trees' crowns in piece space (TreeX: its y max): a copy is scaled so its crown
# ends where the city's crown ended.
CROWN_TOP = {k: v[1][1] for k, v in EXTENT.items() if k.startswith("Tree")}


def vr(*key):
    return variation("city_park", *(round(k, 2) if isinstance(k, float) else k for k in key))


def msize(piece):
    lo, hi = EXTENT[piece]
    return tuple(max(abs(lo[i]), abs(hi[i])) * 2 for i in range(3))


def wrap(O, matches, piece, fr, tint=None, scale=1.0, name=None, force=None):
    """reuse.wrap_at with this family's marker size (the piece may not be in pieces.json yet)."""
    rx, ry, rz = fr.angles
    sz = msize(piece)
    if tint is None:
        tint = TINT.get(piece)
    return O.wrap(matches, piece, fr.pos, ry=ry, rx=rx, rz=rz, tint=tint, scale=scale, size=sz, name=name,
                  force=force)


def rows_named(O, folder, names):
    """Every built row of `folder` whose name is in `names`, as Matches."""
    return O.box(folder, set(names))


def color(O, m):
    r = O.row(m)
    return tuple(O.data["colors"][r[10] - 1])


def bottom(O, m):
    """The lowest y of the matched part (its box turned by its rotation: a Roblox cylinder lies
    along X, so a standing one is turned 90 degrees about Z)."""
    r = O.row(m)
    rot = yxz_matrix(r[RX], r[RX + 1], r[RX + 2])
    half = sum(abs(rot[1][k]) * r[SX + k] / 2 for k in range(3))
    return r[X + 1] - half


def flat(p):
    return (p[0], p[2])


# ---------------------------------------------------------------------------------- benches
BENCH_PAINT = ((34, 46, 40), (28, 30, 30), (40, 52, 46), (30, 38, 34))


def benches(O):
    """The five benches: each one's eleven parts (seat, slats, back rails, legs, end rails) round
    its middle slat (the one that collides). Two of them are the worn bench."""
    F = "Park"
    names = ("BenchSeat", "BenchSlat", "BenchBack", "BenchRail", "BenchLeg")
    parts = rows_named(O, F, names)
    mids = [m for m in parts if m.name == "BenchSlat" and (O.row(m)[14] & 1)]
    worn_at = sorted(mids, key=lambda m: vr("bench_pick", pos(O, m)[0], pos(O, m)[2]).random())[:2]
    for mid in mids:
        c = pos(O, mid)
        group = [m for m in parts if math.dist(flat(pos(O, m)), flat(c)) < 3.4]
        legs = [m for m in group if m.name == "BenchLeg"]
        foot = min(bottom(O, m) for m in legs)
        ry = O.row(mid)[RY]
        v = vr("bench", c[0], c[2])
        piece = "ParkBenchCastWorn" if mid in worn_at else "ParkBenchCast"
        tint = weathered(v.choice(BENCH_PAINT), v, 4, 0.1)
        wrap(O, [mid] + [m for m in group if m is not mid], piece, Fr((c[0], foot, c[2]), ry=ry + v.uniform(-0.6, 0.6)),
             tint=tint, name=f"bench_{c[0]:.1f}_{c[2]:.1f}")


# ---------------------------------------------------------------------------------- lamps
LAMP_PAINT = ((32, 44, 38), (26, 28, 28), (36, 50, 44))


def lamps(O):
    """The seven lamp posts (plinth, post, glass, cap, finial). The two whose glass has no light
    (no CityLamp in the data: dead lamps) are the neglected, leaning ones."""
    F = "Park"
    plinths = rows_named(O, F, ("LampPlinth",))
    rest = rows_named(O, F, ("LampPost", "LampGlass", "LampCap", "LampFinial"))
    for b in plinths:
        bx, _, bz = pos(O, b)
        group = [m for m in rest if math.dist(flat(pos(O, m)), (bx, bz)) < 0.3]
        glass = next(m for m in group if m.name == "LampGlass")
        lit = "CityLamp" in ((extra_of(O.data, O.row(glass)) or {}).get("t") or [])
        v = vr("lamp", bx, bz)
        piece = "HeritageLampPost" if lit else "HeritageLampPostWorn"
        tint = weathered(v.choice(LAMP_PAINT), v, 4, 0.1)
        wrap(O, [b] + group, piece, Fr((bx, bottom(O, b), bz), ry=v.choice((0, 90, 180, 270)) + v.uniform(-4, 4)),
             tint=tint, name=f"lamp_{bx:.1f}_{bz:.1f}")


# ---------------------------------------------------------------------------------- trees
LEAF_SUMMER = ((66, 92, 44), (58, 86, 40), (74, 98, 48), (62, 90, 50))
LEAF_AUTUMN = ((150, 90, 45), (120, 70, 35), (142, 100, 50))  # (dull ochre / rust browns, not cartoon orange)


def trees(O):
    """The twelve trees: trunk, flare, branches, leaf boxes / balls (each leaf and branch goes to
    the nearest trunk). Orange crowns -> autumn (three thin autumn crowns where their fallen
    leaves have open grass, two full limes turned yellow); box crowns -> plane; ball and
    stacked crowns -> lime. Scaled so the crown ends where the old one did (0.85-1.2)."""
    F = "Park"
    trunks = rows_named(O, F, ("Trunk",))
    others = rows_named(O, F, ("TrunkFlare", "Branch", "Leaves"))
    groups = {id(t): [t] for t in trunks}
    for m in others:
        p = flat(pos(O, m))
        t = min(trunks, key=lambda t: math.dist(p, flat(pos(O, t))))
        if math.dist(p, flat(pos(O, t))) < 4.5:
            groups[id(t)].append(m)
    autumn = [t for t in trunks if any(m.name == "Leaves" and color(O, m)[0] > 120 for m in groups[id(t)])]

    def kerbs_near(t):
        """Low solids (pond edges, kerbs, steps) within the fallen leaves' reach: a thin autumn
        crown drops its leaves round it, they would lie under those stones."""
        x, _, z = pos(O, t)
        foot = bottom(O, t)
        return sum(1 for lo, hi in solids(O) if foot + 0.05 < hi[1] < foot + 1.5 and hi[0] - lo[0] < 20 and hi[2] - lo[2] < 20
                   and max(lo[0] - x, 0, x - hi[0]) ** 2 + max(lo[2] - z, 0, z - hi[2]) ** 2 < 4.5 ** 2)

    # (the thin autumn crowns where their fallen leaves have open grass; the others turn gold)
    autumn.sort(key=lambda t: (kerbs_near(t), vr("autumn_pick", pos(O, t)[0], pos(O, t)[2]).random()))
    for t in trunks:
        g = groups[id(t)]
        x, _, z = pos(O, t)
        foot = bottom(O, t)
        leaves = [m for m in g if m.name == "Leaves"]
        top = max(pos(O, m)[1] + size(O, m)[1] / 2 for m in leaves) - foot
        balls = sum(1 for m in leaves if O.row(m)[0] == 4)
        stacked = len({round(pos(O, m)[0], 1) for m in leaves}) == 1
        v = vr("tree", x, z)
        if t in autumn:
            if autumn.index(t) < 3:
                piece, tint = "TreeAutumn", weathered(v.choice(LEAF_AUTUMN), v, 8, 0.05)
            else:  # (a lime turns butter-yellow, still in full leaf)
                piece, tint = "TreeLimeYoung", weathered((140, 122, 56), v, 8, 0.05)
        else:
            piece = "TreeLimeYoung" if (balls or stacked) else "TreePlaneYoung"
            tint = weathered(v.choice(LEAF_SUMMER), v, 5, 0.05)
        scale = round(max(0.85, min(1.2, top / CROWN_TOP[piece])), 3)
        wrap(O, g, piece, Fr((x, foot, z), ry=v.uniform(0, 360)), tint=tint, scale=scale,
             name=f"tree_{x:.1f}_{z:.1f}")


# ---------------------------------------------------------------------------------- bins, fountains
def bins(O):
    F = "Park"
    rims = rows_named(O, F, ("ParkBinRim",))
    for b in rows_named(O, F, ("ParkBin",)):
        x, _, z = pos(O, b)
        rim = min(rims, key=lambda m: math.dist(flat(pos(O, m)), (x, z)))
        v = vr("bin", x, z)
        wrap(O, [b, rim], "ParkBinCast", Fr((x, bottom(O, b), z), ry=v.uniform(0, 360)),
             tint=weathered((34, 50, 40), v, 4, 0.1), name=f"bin_{x:.1f}_{z:.1f}")


def drinking_fountain(O):
    F = "Park"
    body = O.match(F, "DrinkingFountain", (-147.8, 3.0, 105.5))
    r = O.row(body)
    if r is None:
        return
    x, _, z = pos(O, body)
    parts = [body] + [m for m in rows_named(O, F, ("FountainBowl", "FountainWater", "FountainSpout", "FountainStep"))
                      if math.dist(flat(pos(O, m)), (x, z)) < 1.5]
    wrap(O, parts, "DrinkingFountainCast", Fr((x, bottom(O, body), z), ry=r[RY]), name="drinking_fountain")


WATER = (52, 76, 72)  # (a park fountain's water: murky green-grey, never swimming-pool blue)


def fountain(O):
    """The plaza's fountain: base, the eight rims, the column and the upper bowl are wrapped; the
    water discs, the jet and the spray stay (murkier)."""
    F = "Park"
    base = O.match(F, "FountainBase", (-173.0, 1.82, 122.5))
    r = O.row(base)
    if r is None:
        return
    x, _, z = pos(O, base)
    near = lambda m: math.dist(flat(pos(O, m)), (x, z)) < 6  # noqa: E731
    parts = [base] + [m for m in rows_named(O, F, ("FountainRim", "FountainColumn", "FountainBowl")) if near(m)]
    wrap(O, parts, "FountainTwoTier", Fr((x, bottom(O, base), z), ry=0), name="plaza_fountain")
    for m in rows_named(O, F, ("FountainWater",)):
        if near(m):
            big = size(O, m)[1] > 4
            O.set(m, color=WATER if big else (66, 92, 90), transparency=0.18 if big else 0.25)
    # the jet and its spray: thin, clear water, not a white bulb on a stick
    for m in rows_named(O, F, ("FountainJet", "FountainSpray")):
        if near(m):
            O.set(m, color=(186, 206, 208), transparency=0.62 if m.name == "FountainJet" else 0.78)


def bandstand(O):
    F = "Park"
    floor = O.match(F, "BandstandFloor", (-182.5, 2.25, 112.0))
    r = O.row(floor)
    if r is None:
        return
    x, _, z = pos(O, floor)
    names = ("BandstandDeck", "BandstandStep", "BandstandColumn", "BandstandRail", "BandstandLattice",
             "BandstandBeam", "BandstandRoof", "BandstandFinial")
    parts = [floor] + [m for m in rows_named(O, F, names) if math.dist(flat(pos(O, m)), (x, z)) < 7]
    v = vr("bandstand")
    wrap(O, parts, "BandstandVictorian", Fr((x, bottom(O, floor), z), ry=0), tint=weathered((36, 62, 48), v, 3, 0.08),
         name="bandstand")


# ---------------------------------------------------------------------------------- SpezCola
SPEZ_KEEP = {"Panel", "Button", "Dispenser", "Hum"}


def spezcola(O):
    """The three machines (Duffy's, the Cage, the park). The Cage's (outdoors, in the fight
    yard) is the worn one."""
    machines = (("Interiors/Duffys/SpezColaMachine_1", "VendingMachine"),
                ("Zones/Cage/SpezColaMachine_2", "VendingMachineWorn"),
                ("Park/SpezColaMachine_3", "VendingMachine"))
    for folder, piece in machines:
        parts = O.box(folder)
        body = next((m for m in parts if m.name == "Body"), None)
        plinth = next((m for m in parts if m.name == "Plinth"), None)
        if body is None or plinth is None:
            continue
        r = O.row(body)
        bx, _, bz = pos(O, body)
        wrapped = [body] + [m for m in parts if m.name not in SPEZ_KEEP and m is not body]
        v = vr("spez", folder)
        tint = weathered(color(O, body), v, 3, 0.04)
        # (the body is the machine's PrimaryPart and, swapped, a KitProxy that would break
        # whole: the mesh would vanish and leave the lit Panel and the Button, which stay outside
        # the marker, floating. The machine is made unbreakable instead.)
        O.set(body, attrs={"Unbreakable": True})
        wrap(O, wrapped, piece, Fr((bx, bottom(O, plinth), bz), ry=r[RY]), tint=tint,
             name=f"spezcola_{folder.rsplit('_', 1)[-1]}",
             force="park.py spezcola(): marker inside the Model, Button / Dispenser / Hum / Panel kept out")


# ---------------------------------------------------------------------------------- footbridge
def footbridge(O):
    """The arched footbridge (101 parts, reads well): IMPROVE only. Its timber goes from fresh
    brown to old, wet, weathered oak (each plank / rail a little different), the posts' caps
    darker, the stone abutments and steps damp and mossy. Colours only: nothing moves."""
    F = "Park"
    tones = {
        "BridgePlank": ((74, 62, 50), 7),
        "BridgeRail": ((84, 74, 62), 6),
        "BridgeStringer": ((54, 42, 32), 4),
        "BridgePost": ((62, 50, 38), 5),
        "BridgePostCap": ((46, 38, 30), 3),
        "BridgeAbutment": ((96, 100, 86), 4),
        "BridgeStep": ((104, 104, 94), 4),
    }
    for name, (rgb, amount) in tones.items():
        for m in rows_named(O, F, (name,)):
            x, y, z = pos(O, m)
            v = vr("bridge", name, x, y, z)
            O.set(m, color=weathered(rgb, v, amount, 0.0))


# ---------------------------------------------------------------------------------- flower beds
# Each bed is planted with one kind (council bedding), the odd clump a different one; per copy:
# leaf tint, yaw, scale from the old cube's height (taller cube, taller clump).
BED_KIND = {(-166.5, 106.75): "A", (-166.5, 138.75): "C", (-159.5, 116.5): "B", (-196.75, 113.0): "D",
            (-149.75, 139.0): "B"}
LEAF_TINTS = ((58, 82, 42), (54, 78, 40), (64, 86, 44), (70, 84, 46), (50, 72, 38))


def flower_beds(O):
    """The 33 'Flowers' cubes on the five beds' soil: a FlowerClump each (pure decoration:
    the cubes did not collide either)."""
    soils = rows_named(O, "Park", ("BedSoil",))
    for m in rows_named(O, "Park", ("Flowers",)):
        x, y, z = pos(O, m)
        h = size(O, m)[1]
        bed = None
        for sm in soils:
            sx_, sy_, sz_ = pos(O, sm)
            w = size(O, sm)
            if abs(x - sx_) <= w[0] / 2 and abs(z - sz_) <= w[2] / 2:
                bed = (sm, (sx_, sz_), sy_ + w[1] / 2, min(w[0], w[2]))
        if bed is None:
            O.warn(f"park: flowers {m} not on a bed")
            continue
        sm, key, top, narrow = bed
        v = vr("flowers", x, z)
        kind = BED_KIND.get((round(key[0], 2), round(key[1], 2)), "A")
        if v.random() < 0.15:
            kind = v.choice("ABCD")
        scale = max(0.85, min(1.12 if narrow > 1.5 else 1.0, 0.85 + (h - 0.4) * 0.9 + v.uniform(-0.05, 0.05)))
        tint = weathered(v.choice(LEAF_TINTS), v, 4, 0.08)
        wrap(O, [m], f"FlowerClump{kind}", Fr((x + v.uniform(-0.06, 0.06), top, z + v.uniform(-0.06, 0.06)),
             ry=v.uniform(0, 360)), tint=tint, scale=round(scale, 3), name=f"flowers_{x:.2f}_{z:.2f}")


def edits(O):
    benches(O)
    lamps(O)
    trees(O)
    bins(O)
    drinking_fountain(O)
    fountain(O)
    bandstand(O)
    spezcola(O)
    footbridge(O)
    flower_beds(O)

