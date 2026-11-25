"""The city's props that an EXISTING piece of the city prop kit already covers (PLAN step 2): the
old primitive parts are wrapped under a MeshProp marker of that piece (CityOverlay "wrap"), so
PropKit swaps in the mesh exactly as in the alleys, keeps what collides as invisible proxies
(collisions, Breakable, Destruction unchanged) and hands lights / fire / gutters to the mesh.
Without the kit (or if the city moved a part) the old parts stay as they are.

Every copy is a little different, from its place (meshprop.variation): variant, tint (weathered
off its catalogue colour), yaw, a slight lean. Sizes follow the old collision boxes (the mesh
within ~0.3 stud of its proxy); decorative-only props (bags, cones) take their real size.

    trash bag piles (Props/Street, 56 balls -> 3-5 bags a pile) and the bags in open dumpsters,
    traffic cones (upright and knocked over), street bins (WheelieBin + lid), the Cage's burn
    barrel and tyre stack, the bulkhead lights over back doors, the downpipes (shoe, lengths,
    brackets; the old hopper stays), the rooftop water tanks, REWIND's wall of CRTs (the lit
    screens are kept and fitted into the meshes' screen openings), Hollow Threads' clothes rail
    (two racks and their jackets).

NOT here: the dumpsters (the kit's is a real 1.2 m dumpster, the city's are 0.95 m squat boxes
whose tops are climb steps: a uniform Scale cannot fit both; they wait for a per-axis scale in
PropKit), the rooftop AC boxes (no kit piece of that shape), the roof
dishes (the kit's is a wall-hung dish).
"""

import math

import numpy as np

import meshprop
from citykit import yxz_angles, yxz_matrix
from meshprop import variation, weathered
from overlay.citydata import COLLIDE, FLAGS, RX, SX, X, Y, extra_of, folder_of, name_of
from overlay.core import DECOR



def vr(*key):
    return variation("city_reuse", *(round(k, 2) if isinstance(k, float) else k for k in key))


# ---------------------------------------------------------------------------------- geometry
_SOLIDS = {}


def solids(O):
    """[(lo, hi)] of the built, colliding, axis-aligned parts (what bags stand on, what pipes
    hang on)."""
    key = id(O)
    if key not in _SOLIDS:
        out = []
        for i, r in enumerate(O.data["parts"]):
            if i in O.skip or not (r[FLAGS] & COLLIDE):
                continue
            rot = [round(a) % 180 for a in r[RX:RX + 3]]
            if any(a not in (0, 90) for a in rot):
                continue
            s = list(r[SX:SX + 3])
            if rot[0] == 90:
                s[1], s[2] = s[2], s[1]
            if rot[1] == 90:
                s[0], s[2] = s[2], s[0]
            if rot[2] == 90:
                s[0], s[1] = s[1], s[0]
            out.append(([r[X + k] - s[k] / 2 for k in range(3)], [r[X + k] + s[k] / 2 for k in range(3)]))
        _SOLIDS[key] = out
    return _SOLIDS[key]


def ground(O, x, z, below, fallback):
    """The top of the highest solid under (x, z) whose top is under `below` (else fallback)."""
    best = None
    for lo, hi in solids(O):
        if lo[0] <= x <= hi[0] and lo[2] <= z <= hi[2] and hi[1] <= below + 0.01:
            best = hi[1] if best is None else max(best, hi[1])
    return fallback if best is None else best


def nearest_wall(O, p, reach=4.0, ignore=()):
    """(unit direction (dx, dz), distance) toward the nearest vertical solid face around p at its
    height (None if none within reach). ignore: [(lo, hi)] boxes to skip (the prop itself)."""
    best = None
    for lo, hi in solids(O):
        if (lo, hi) in ignore or not (lo[1] < p[1] < hi[1]):
            continue
        if hi[1] - lo[1] < 2.0 or (hi[0] - lo[0] < 3.0 and hi[2] - lo[2] < 3.0):
            continue  # (a wall, not a bin or a post standing next to the prop)
        for k, other in ((0, 2), (2, 0)):
            if not (lo[other] - 0.2 <= p[other] <= hi[other] + 0.2):
                continue
            for face, sign in ((lo[k], 1), (hi[k], -1)):
                d = (face - p[k]) * sign
                if 0 <= d <= reach and (best is None or d < best[1]):
                    best = ((sign if k == 0 else 0, sign if k == 2 else 0), d)
    return best


def yaw_of(direction):
    """ry (degrees) that turns a piece's +Z (its back) toward the world direction (dx, dz)."""
    return math.degrees(math.atan2(direction[0], direction[1]))


class Fr:
    """A frame (origin, rotation matrix) to place pieces relative to each other."""

    def __init__(self, origin, ry=0.0, rx=0.0, rz=0.0, m=None):
        self.o = np.array(origin, dtype=float)
        self.m = m if m is not None else yxz_matrix(rx, ry, rz)

    def sub(self, offset, ry=0.0, rx=0.0, rz=0.0):
        return Fr(self.o + self.m @ np.array(offset, dtype=float), m=self.m @ yxz_matrix(rx, ry, rz))

    def world(self, p):
        return tuple(float(v) for v in self.o + self.m @ np.array(p, dtype=float))

    @property
    def pos(self):
        return tuple(float(v) for v in self.o)

    @property
    def angles(self):
        return yxz_angles(self.m)


def wrap_at(O, matches, piece, fr, tint=None, scale=1.0, name=None):
    rx, ry, rz = fr.angles
    return O.wrap(matches, piece, fr.pos, ry=ry, rx=rx, rz=rz, tint=tint, scale=scale, name=name)


def bare_at(O, folder, piece, fr, tint=None, scale=1.0, under=None):
    """A marker with no fallback parts (a lid, a pipe length, a jacket): it only shows with the
    kit. Same attributes as meshprop / Overlay.wrap."""
    info = meshprop.pieces()[piece]
    size = tuple(max(0.05, max(abs(info["min"][i]), abs(info["max"][i])) * 2 * scale) for i in range(3))
    attrs = {"Piece": piece}
    if tint is None and info.get("tint"):
        tint = next(iter(info["tint"].values()))
    if tint is not None:
        attrs["Tint"] = ",".join(str(int(round(c))) for c in tint)
    if scale != 1.0:
        attrs["Scale"] = round(float(scale), 3)
    return O.add(folder, "MeshProp", fr.pos, size, (128, 128, 128), "SmoothPlastic", rot=fr.angles,
                 transparency=1.0, flags=DECOR, extra={"a": attrs}, under=under)


def pos(O, m):
    r = O.row(m)
    return None if r is None else (r[X], r[Y], r[X + 2])


def size(O, m):
    r = O.row(m)
    return None if r is None else tuple(r[SX:SX + 3])


def color(O, m):
    r = O.row(m)
    return tuple(O.data["colors"][r[10] - 1]) if r is not None else (40, 40, 40)


def brighten(rgb, k):
    return tuple(min(255, c * k) for c in rgb)


# ---------------------------------------------------------------------------------- families
BLACK_BAGS = ((20, 20, 22), (26, 26, 28), (18, 20, 24), (30, 30, 30))


def bag_piles(O):
    """The 10 piles of black balls along the streets, as 2-4 kit bags on the ground (spread from
    the pile's balls so they press against each other, not through, and kept off the wall) and,
    on a big pile, one more thrown on top. Each ball is wrapped under the bag nearest to it."""
    balls = O.box("Props/Street", "TrashBag")
    piles = []
    for m in balls:
        p = pos(O, m)
        for pile in piles:
            if any(math.dist((p[0], p[2]), (q[0], q[2])) < 3.2 for q in (pos(O, b) for b in pile)):
                pile.append(m)
                break
        else:
            piles.append([m])
    for n, pile in enumerate(piles):
        pile.sort(key=lambda b: -size(O, b)[0])
        xz = [(pos(O, b)[0], pos(O, b)[2]) for b in pile]
        y0 = pos(O, pile[0])[1]
        g = ground(O, xz[0][0], xz[0][1], y0, y0 - 1.0)
        count = max(2, min(4, round(len(pile) * 0.5)))
        # farthest-point picks from the biggest ball, then pushed apart to 1.5 and off the walls
        picks = [0]
        while len(picks) < count:
            picks.append(max(range(len(pile)), key=lambda i: min(math.dist(xz[i], xz[k]) for k in picks)))
        spots = [list(xz[i]) for i in picks]
        for _ in range(40):
            for a in range(len(spots)):
                for b in range(a + 1, len(spots)):
                    d = math.dist(spots[a], spots[b])
                    if d < 1.5:
                        ux, uz = ((spots[b][0] - spots[a][0]) / d, (spots[b][1] - spots[a][1]) / d) if d > 1e-6 else (1, 0)
                        push = (1.5 - d) / 2
                        spots[a][0] -= ux * push
                        spots[a][1] -= uz * push
                        spots[b][0] += ux * push
                        spots[b][1] += uz * push
            for sp in spots:
                w = nearest_wall(O, (sp[0], g + 1.0, sp[1]), reach=1.0)
                if w and w[1] < 0.95:
                    sp[0] -= w[0][0] * (0.95 - w[1])
                    sp[1] -= w[0][1] * (0.95 - w[1])
        groups = [[] for _ in spots]
        for b, p in zip(pile, xz):
            groups[min(range(len(spots)), key=lambda k: math.dist(p, spots[k]))].append(b)
        cx = sum(p[0] for p in spots) / len(spots)
        cz = sum(p[1] for p in spots) / len(spots)
        with O.entry(f"bag_pile_{n}"):
            for k, (sp, group) in enumerate(zip(spots, groups)):
                x, z = sp
                d = max(size(O, b)[0] for b in group) if group else 1.8
                v = vr("bag", x, z)
                if d < 1.45:
                    piece, scale = "TrashBag3", d / 1.6
                elif k > 0 and v.random() < 0.35:
                    piece, scale = "TrashBag2", d / 2.3
                else:
                    piece, scale = "TrashBag1", d / 2.15
                scale = round(max(0.75, min(1.1, scale * v.uniform(0.95, 1.06))), 3)
                c = color(O, group[0]) if group else (20, 20, 22)
                tint = weathered(brighten(c, 0.5), v, 4, 0.1) if sum(c) > 150 else v.choice(BLACK_BAGS)  # (grey / blue sacks, dull)
                # (a bag leans away from the pile's middle, a few degrees)
                away = math.atan2(x - cx, z - cz)
                fr = Fr((x, g - 0.03, z), m=yxz_matrix(0, math.degrees(away), 0) @ yxz_matrix(v.uniform(2, 6), 0, 0)
                        @ yxz_matrix(0, v.uniform(0, 360), 0))
                if group:
                    wrap_at(O, group, piece, fr, tint=tint, scale=scale)
                else:
                    bare_at(O, "Props/Street", piece, fr, tint=tint, scale=scale)
            # a big pile: one more bag thrown on top, between the two first (its bottom in them)
            if len(pile) >= 5:
                x, z = (spots[0][0] + spots[1][0]) / 2, (spots[0][1] + spots[1][1]) / 2
                v = vr("bag_top", x, z)
                fr = Fr((x, g + 0.95, z), ry=v.uniform(0, 360), rx=v.uniform(-12, 12), rz=v.uniform(-12, 12))
                bare_at(O, "Props/Street", "TrashBag3", fr, tint=v.choice(BLACK_BAGS), scale=round(v.uniform(0.8, 0.9), 3))


def dumpster_bags(O):
    """The bags showing over the rim of the three open dumpsters (Cage, Yard, Doyle): squat
    kit bags whose tops poke out where the balls did, their bottoms inside the bin."""
    for folder, pairs in (("Zones/Cage", [((-35.276, 4.25, 116.297), (-35.607, 4.25, 116.524))]),
                          ("Zones/Yard", [((62.256, 4.25, 22.565),), ((62.543, 4.25, 23.859),)]),
                          ("Zones/Doyle", [((-78.063, 4.25, 28.034),), ((-77.435, 4.25, 29.445),)])):
        with O.entry(f"dumpster_bags_{folder.split('/')[-1]}"):
            for group in pairs:
                ms = [O.match(folder, "Bag", at) for at in group]
                x = sum(a[0] for a in group) / len(group)
                z = sum(a[2] for a in group) / len(group)
                v = vr("dbag", x, z)
                scale = 1.02 if len(group) > 1 else 0.84
                fr = Fr((x, 3.98, z), ry=v.uniform(0, 360), rx=v.uniform(-6, 6), rz=v.uniform(-6, 6))
                wrap_at(O, ms, "TrashBag3", fr, tint=v.choice(BLACK_BAGS), scale=scale)


CONE = (204, 84, 32)


def cones(O):
    """Two upright cones and a knocked-over one at the barricades and at the crossroads."""
    for folder, up, down in (("Props/Barricades", [(-113, -54), (-114.6, -52.8)], (-116.2, 1.6, -45.6)),
                             ("Zones/Crossroads", [(13.8, -79.5), (14, -82.6)], (12.4, 1.6, -78))):
        with O.entry(f"cones_{folder.split('/')[-1]}"):
            for i, (x, z) in enumerate(up):
                ms = [O.match(folder, "ConeBase", (x, 1.35, z)), O.match(folder, "Cone", (x, 2.15, z)),
                      O.match(folder, "ConeStripe", (x, 2.2, z))]
                v = vr("cone", x, z)
                g = ground(O, x, z, 1.5, 1.2)
                piece = "TrafficConeWorn" if (i == 1) ^ (v.random() < 0.3) else "TrafficCone"
                fr = Fr((x, g, z), ry=v.uniform(0, 360), rx=v.uniform(-1.5, 1.5), rz=v.uniform(-1.5, 1.5))
                wrap_at(O, ms, piece, fr, tint=weathered(CONE, v, 8, 0.12), scale=round(v.uniform(0.92, 1.0), 3))
            # knocked over: lying on its side, tip on the ground, where the old one lay (same
            # heading: its base where the old base was)
            cone = O.match(folder, "Cone", down)
            r = O.row(cone)
            ms = [cone]
            if r is not None:
                ry = r[RX + 1]
                bx = down[0] - 0.78 * math.cos(math.radians(ry))
                bz = down[2] + 0.78 * math.sin(math.radians(ry))
                ms.append(O.near(folder, "ConeBase", (bx, 1.8, bz), radius=0.2))
                v = vr("cone_down", *down)
                s = round(v.uniform(0.92, 0.98), 3)
                g = ground(O, bx, bz, 1.5, 1.2)
                fr = Fr((bx, g + 0.735 * s, bz), ry=ry, rz=-102.9, rx=v.choice((-4, 4)))
                wrap_at(O, ms, "TrafficConeWorn", fr, tint=weathered((196, 80, 34), v, 8, 0.15), scale=s)
            else:
                O.wrap(ms, "TrafficConeWorn", down)  # (not found: reported, entry dropped)


def street_bins(O):
    """The six street bins (pairs on the pavements): 240 L wheelie bins, their backs to the wall,
    lids closed, one ajar on a bag, one thrown back. Same box as the old bins (1.8 x 3 x 1.8 + lid)."""
    s = 0.88
    for x, z, lid_at in ((-87.7, 25, (-87.7, 4.35, 25)), (-87.7, 26.8, (-87.7, 4.35, 26.8)),
                         (29.1, -91, (29.1, 4.35, -91)), (29.1, -89.2, (29.1, 4.35, -89.2)),
                         (-115.7, 77, (-116.238, 5.242, 77)), (-115.7, 78.8, (-115.7, 4.35, 78.8))):
        binm = O.match("Props/Street", "Bin", (x, 2.75, z))
        lid = O.match("Props/Street", "Lid", lid_at)
        if O.row(binm) is None:
            O.wrap([binm, lid], "WheelieBin", (x, 1.25, z))
            continue
        me = ([x - 0.9, 1.25, z - 0.9], [x + 0.9, 4.25, z + 0.9])
        wall = nearest_wall(O, (x, 2.75, z), reach=5, ignore=(me,))
        back = wall[0] if wall else (1, 0)
        v = vr("bin", x, z)
        g = ground(O, x, z, 1.5, 1.25)
        fr = Fr((x, g, z), ry=yaw_of(back) + v.uniform(-2, 2))
        tint = weathered(brighten(color(O, binm), 1.3), v, 5, 0.1)
        piece = "WheelieBinWorn" if v.random() < 0.5 else "WheelieBin"
        if lid_at[1] > 5:
            open_ = 104.0  # (the old lid lay knocked open: thrown back on its hinge)
        elif v.random() < 0.25:
            open_ = v.uniform(12, 20)  # (ajar on a full bag)
        else:
            open_ = v.uniform(0, 2)
        with O.entry(f"bin_{x}_{z}"):
            wrap_at(O, [binm, lid], piece, fr, tint=tint, scale=s)
            bare_at(O, "Props/Street", "WheelieBinLid", fr.sub((0, 3.18 * s, 1.18 * s), rx=open_), tint=tint, scale=s)


def cage_fire_and_tyres(O):
    """The Cage's burn barrel (its fire and embers handed to the kit drum's Fx / Light / Glow)
    and the stack of tyres by the court (three kit tyres in the old stack's collider)."""
    v = vr("burn")
    barrel = O.match("Zones/Cage", "BurnBarrel", (-109, 2.85, 111))
    embers = O.match("Zones/Cage", "Embers", (-109, 4.525, 111))
    wrap_at(O, [barrel, embers], "OilDrumBurn", Fr((-109, 1.25, 111), ry=v.uniform(0, 360)), scale=1.11,
            name="burn_barrel")
    tyres = [O.match("Zones/Cage", "Tyre", at) for at in ((-115.38, 1.61, 48.7), (-115.6, 2.36, 48.92),
                                                          (-115.42, 3.11, 48.9), (-115.62, 3.86, 48.72))]
    hole = O.match("Zones/Cage", "TyreHole", (-115.62, 4.215, 48.72))
    s = 1.3
    y = 1.25
    with O.entry("cage_tyres"):
        for i in range(3):
            v = vr("tyre", i)
            fr = Fr((-115.5 + v.uniform(-0.12, 0.12), y, 48.8 + v.uniform(-0.12, 0.12)), ry=v.uniform(0, 360),
                    rx=v.uniform(-1.2, 1.2), rz=v.uniform(-1.2, 1.2))
            piece = "TyreBald" if i == 1 else "Tyre"
            if i == 0:
                wrap_at(O, tyres + [hole], piece, fr, scale=s)
            else:
                bare_at(O, "Zones/Cage", piece, fr, scale=s)
            y += 0.75 * s + 0.03


# (folder, centre): every old WallLight box (0.5 deep, its centre 0.25 off the wall)
WALL_LIGHTS = (("Buildings/B1/Facade_E", (-26.75, 11.95, -109.4)), ("Buildings/B1/Facade_W", (-73.25, 10.15, -85.6)),
               ("Buildings/B2n/Facade_S", (-126, 8.15, -70.75)), ("Buildings/B5/Facade_W", (-75.25, 10.15, -8)),
               ("Buildings/B7/Facade_E", (-88.75, 10.15, 22)), ("Buildings/B11/Facade_W", (106.75, 10.15, -121.6)),
               ("Buildings/o/Facade_S", (88.5, 10.15, -124.75)), ("Buildings/SEN/Facade_N", (-11, 11.95, 118.75)),
               ("Buildings/B12", (73, 14.35, 21.25)), ("Zones/Cage", (-55, 12.15, 118.75)),
               ("Park/Passage", (-139, 7.95, 118.75)))


def wall_lights(O):
    """The bulkheads over the back doors: the kit's cast oval bulkhead (lit ones keep their
    CityBulkhead tag, light and Flicker: handed over to the lens); the unlit grey boxes become
    the dead bulkhead (dull glass, insects in it)."""
    for folder, at in WALL_LIGHTS:
        m = O.match(folder, "WallLight", at)
        r = O.row(m)
        if r is None:
            O.wrap(m, "BulkheadLight", at)
            continue
        s = r[SX:SX + 3]
        k = 0 if s[0] < s[2] else 2  # (the thin axis: out of the wall)
        out = None
        for sign in (1, -1):  # (the wall is on the side whose face touches a solid)
            p = list(at)
            p[k] -= sign * (s[k] / 2 + 0.05)
            for lo, hi in solids(O):
                if all(lo[j] <= p[j] <= hi[j] for j in range(3)):
                    out = sign
                    break
            if out:
                break
        if out is None:
            O.error(f"reuse: no wall behind {m}")
            continue
        face = list(at)
        face[k] -= out * s[k] / 2
        d = (out, 0) if k == 0 else (0, out)
        ry = yaw_of((-d[0], -d[1]))  # (the piece's +Z into the wall)
        lit = "CityBulkhead" in ((extra_of(O.data, r) or {}).get("t") or [])
        wrap_at(O, [m], "BulkheadLight" if lit else "BulkheadLightDead", Fr(face, ry=ry),
                tint=weathered((56, 58, 56), vr("bulkhead", *at), 5, 0.1), name=f"bulkhead_{at[0]}_{at[2]}")


DRAINPIPES = (("Buildings/B5", (-51, 20.825, 47.6)), ("Buildings/B5", (-75.6, 20.825, 23)),
              ("Buildings/B7", (-88.4, 26.325, 39)), ("Buildings/B11", (106.4, 26.325, -74.6)),
              ("Buildings/B13", (91, 11.3, -17.6)), ("Buildings/M", (-79, 31.825, 118.4)),
              ("Buildings/M", (-111, 31.825, 118.4)))


def drainpipes(O):
    """The downpipes: the kit's shoe at the foot (the CityGutter part moves to its spout), 6-stud
    lengths with a bracket at each joint, 1.5-stud lengths to reach the old hopper (kept)."""
    for folder, at in DRAINPIPES:
        pipe = O.match(folder, "Drainpipe", at)
        r = O.row(pipe)
        if r is None:
            O.wrap(pipe, "DownpipeStraight", at)
            continue
        length = r[SX + 1]
        top = at[1] + length / 2
        cands = [(i, q) for i, q in enumerate(O.data["parts"]) if i not in O.skip
                 and folder_of(O.data, q) == folder and abs(q[X] - at[0]) < 0.4 and abs(q[X + 2] - at[2]) < 0.4]
        shoe_i = [i for i, q in cands if name_of(O.data, q) == "Shoe"]
        hop_i = [i for i, q in cands if name_of(O.data, q) == "Hopper"]
        if len(shoe_i) != 1 or len(hop_i) != 1:
            O.error(f"reuse: drainpipe {at}: shoe {len(shoe_i)} hopper {len(hop_i)}")
            continue
        sq, hq = O.data["parts"][shoe_i[0]], O.data["parts"][hop_i[0]]
        shoe = O.match(folder, "Shoe", (sq[X], sq[Y], sq[X + 2]))
        dx, dz = sq[X] - at[0], sq[X + 2] - at[2]
        out = (1 if dx > 0 else -1, 0) if abs(dx) > abs(dz) else (0, 1 if dz > 0 else -1)
        foot = sq[Y] - sq[SX + 1] / 2
        hopper_lo, hopper_hi = hq[Y] - hq[SX + 1] / 2, hq[Y] + hq[SX + 1] / 2
        face = (at[0] - out[0] * 0.4, foot, at[2] - out[1] * 0.4)  # (the old pipe touched the wall)
        fr = Fr(face, ry=yaw_of((-out[0], -out[1])))
        tint = weathered(brighten(color(O, pipe), 1.15), vr("pipe", *at), 4, 0.1)
        run = max(top, hopper_lo) - (foot + 1.2)
        n6 = int(run // 6)
        n15 = math.ceil((run - 6 * n6) / 1.5 - 0.15)
        if foot + 1.2 + 6 * n6 + 1.5 * n15 > hopper_hi - 0.15:
            n15 -= 1
        with O.entry(f"downpipe_{at[0]}_{at[2]}"):
            wrap_at(O, [shoe], "DownpipeShoe", fr, tint=tint)
            y = 1.2
            for i in range(n6):
                if i == 0:
                    wrap_at(O, [pipe], "DownpipeStraight", fr.sub((0, y, 0)), tint=tint)
                else:
                    bare_at(O, folder, "DownpipeStraight", fr.sub((0, y, 0)), tint=tint)
                bare_at(O, folder, "DownpipeBracket", fr.sub((0, y + 3.0, 0)), tint=tint)
                y += 6.0
            for i in range(n15):
                if i == 0 and n6 == 0:
                    wrap_at(O, [pipe], "DownpipeStraightShort", fr.sub((0, y, 0)), tint=tint)
                else:
                    bare_at(O, folder, "DownpipeStraightShort", fr.sub((0, y, 0)), tint=tint)
                y += 1.5


TANKS = (("Buildings/B1/Roof", -41, 61.5, -115), ("Buildings/B7/Roof", -111, 50.5, 17),
         ("Buildings/B11/Roof", 119, 50.5, -115), ("Buildings/B12/Roof", 41, 50.5, 1),
         ("Buildings/B12/Roof", 67, 50.5, 7), ("Buildings/B13/Roof", 119, 19.9, -5))


def water_tanks(O):
    """The rooftop wooden water tanks: the kit's staved tank on its steel stand. Scale 1.75: the
    staves 4.8 across (the old tank 5), its body over the old one (the stand's feet go through
    the 0.6 platform into the roof, where the old legs stood on it)."""
    s = 1.75
    for folder, x, py, z in TANKS:
        top = py + 0.3
        tank_y = top + 6.0 + 4.5
        parts = [O.match(folder, "Tank", (x, tank_y, z)), O.match(folder, "TankCap", (x, tank_y + 4.8, z)),
                 O.match(folder, "TankCap", (x, tank_y + 5.5, z))]
        parts += [O.match(folder, "TankLeg", (x + sx * 4, top + 3.0, z + sz * 4)) for sx in (-1, 1) for sz in (-1, 1)]
        v = vr("tank", x, z)
        base = (tank_y - 4.5) - 4.24 * s  # (the kit tank's bottom at the old tank's bottom)
        fr = Fr((x, base, z), ry=v.choice((0, 90, 180, 270)) + v.uniform(-4, 4))
        wrap_at(O, parts, "WaterTank", fr, tint=weathered((60, 62, 62), v, 6, 0.1), scale=s,
                name=f"water_tank_{x}_{z}")


def crt_wall(O):
    """REWIND's wall of eight big CRTs: the kit's 20-inch CRT (scale 1.45 on the bottom shelf,
    1.36 on the middle one so the rabbit ears clear the shelf above), screen to the shop. The
    lit screens (CityWindowLit, Ambience drives them) stay parts: each is fitted into its
    mesh's screen opening, 0.02 in front of the tube glass."""
    for row, (cy, shelf, s) in enumerate(((4.1, 2.4, 1.45), (8.1, 6.4, 1.36))):
        for z in (-4.5, 0.5, 5.5, 10.5):
            crt = O.match("Interiors/Rewind", "CRT", (-57.5, cy, z))
            ctl = O.match("Interiors/Rewind", "CRTControls", (-56.37, cy - 1.45, z - 0.45))
            led = O.match("Interiors/Rewind", "CRTLed", (-56.36, cy - 1.45, z + 1.15))
            screen = O.match("Interiors/Rewind", "Screen", (-56.35, cy, z))
            v = vr("crt", row, z)
            beige = sum(color(O, crt)) > 300
            tint = weathered((150, 140, 118) if beige else (52, 50, 48), v, 5, 0.1)
            px = -56.4 - 0.8 * s
            fr = Fr((px, shelf, z + v.uniform(-0.15, 0.15)), ry=-90 + v.uniform(-3, 3))
            with O.entry(f"crt_{row}_{z}"):
                wrap_at(O, [crt, ctl, led], "CrtTv", fr, tint=tint, scale=s)
                sx = -0.79 * s - 0.015  # (local z of the slab's middle: its back on the glass's crown)
                centre = fr.world((0, 0.88 * s, sx))
                O.set(screen, pos=centre, rot=(0, fr.angles[1] + 90, 0), size=(0.03, 1.02 * s, 1.40 * s))


JACKETS = ("Jacket1", "Jacket1Brown", "Jacket2")


def clothes_rail(O):
    """Hollow Threads' 9.4-stud clothes rail: two kit clothes racks end to end (scale 0.9: 9.4
    long, rail 4.7 over the floor, inside the old collider), four jackets on each, coloured
    from the old garments (dark ones leather)."""
    F = "Interiors/Threadbare"
    rail = O.match(F, "RackRail", (-60.3, 6.3, -77.1))
    brackets = [O.match(F, "RackBracket", (-60.55, 6.3, z)) for z in (-81.6, -72.6)]
    garments = [O.match(F, "Garment", (-60.25, 4.7, -81.1 + 0.92 * i)) for i in range(10)]
    floor = ground(O, -60.2, -77.1, 2.0, 1.9)
    s = 0.9
    with O.entry("clothes_rail"):
        for k, zc in enumerate((-79.45, -74.75)):
            v = vr("rack", k)
            rack = Fr((-60.25, floor, zc), ry=90 + v.uniform(-1.5, 1.5))
            wrap_at(O, [rail, brackets[0]] if k == 0 else [brackets[1]], "ClothesRack", rack, scale=s)
            mine = garments[5 * k:5 * k + 5]
            last = None
            xs = [-1.5, -0.62, 0.3, 1.25]  # (along the rack's rail, rack space, before scaling)
            for j, x in enumerate(xs):
                group = [mine[j]] if j < 3 else mine[3:]
                c = color(O, mine[j])
                vj = vr("jacket", k, j)
                if sum(c) < 110:
                    piece, tint = ("Jacket1" if vj.random() < 0.5 else "Jacket1Brown"), None
                    if piece == last:
                        piece = "Jacket1Brown" if piece == "Jacket1" else "Jacket1"
                else:
                    piece, tint = "Jacket2", weathered(brighten(c, 1.2), vj, 5, 0.1)
                last = piece
                fr = rack.sub(((x + vj.uniform(-0.08, 0.08)) * s, 5.2 * s, 0), ry=90 + vj.uniform(-2.5, 2.5),
                              rz=vj.uniform(-3, 3))
                wrap_at(O, group, piece, fr, tint=tint, scale=s)



def edits(O):
    bag_piles(O)
    dumpster_bags(O)
    cones(O)
    street_bins(O)
    cage_fire_and_tyres(O)
    wall_lights(O)
    drainpipes(O)
    water_tanks(O)
    crt_wall(O)
    clothes_rail(O)
