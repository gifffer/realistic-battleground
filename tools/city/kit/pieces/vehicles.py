"""Vehicles of the city prop kit: the parked sedans (clean, worn, wrecked, the taxi, the one up on
jack stands at Ferro's garage) and the Yard's box van.

Each build function gets a kitlib.Piece (`ctx`) and models its piece in Roblox axes (Y up, the
front faces -Z, studs), the origin at the centre of the footprint on the ground.

THE CITY'S CARS ARE SMALLER THAN LIFE. Every sedan in CityData is the same box: body 6.2 x 1.6 x 15
over 2.4-stud wheels, deck top 2.8 studs above the ground, cabin 5.5 x 1.6 x 4.8, roof 5.7 wide,
bumpers 6.4 wide at 15.6 overall. A real late-80s / 90s US full-size sedan (Ford Crown Victoria,
Chevrolet Caprice: 5.4 x 2.0 x 1.45 m) is 19.3 x 7.1 x 5.2 studs: the city's car is that sedan
at ~0.85 in width and height and ~0.8 in length. The colliding parts (CarBody, CarDeck, CarCabin,
Windscreen, RearScreen, CarRoof) stay as invisible proxies, so the meshes keep that box (within
~0.2 stud everywhere) and borrow the REAL car's proportions inside it: three-box notchback,
upright formal C-pillar, slab sides with a shoulder line, flat front with sealed-beam style
rectangular headlamps either side of a chrome egg-crate grille, wraparound corner lamps, full
width tail lamps, chrome bumpers with a black rubber strip, full wheel covers, drip rails.
Wheels: 2.4 studs (0.67 m: a 215/70 R15 is 0.69 m).

How the body is made (no stacked boxes):
  * the lower body is ONE loft of cross-sections along the car (a slab side with a little
    tumble-under at the sill, a shoulder crease, a crowned hood / deck), the plan corners rounded,
    the hood falling to the nose; the wheel arches are cut out of it with a real boolean, and a
    black liner (with a lip proud of the body) fills each well;
  * the greenhouse is a second loft (sections with tumblehome, the windscreen and the rear window
    raked, crowned roof): it is the glass; the roof skin, the A / B / C pillars, the drip rails and
    the chrome belt mouldings are slabs laid ON it (0.04 proud), so the glass reads set in;
  * door gaps, hood / deck seams, rust scabs, primer, the taxi's checker band: thin closed slabs
    projected on the body (ray-cast), 0.02 proud, never coplanar;
  * wear is vertex colour: road dirt rising from the ground, grime round the arches and in the
    gaps, the windscreen clean only where the wipers sweep.

The box van (Halvorsen Freight, the Yard): see box_van below.
"""

import math

import bmesh
import bpy
from mathutils import Vector
from mathutils import Matrix  # noqa: E402
from mathutils.bvhtree import BVHTree

import kitlib
from kitlib import R, S, T, cyl, lathe, lerp, loft, smoothstep, tube
from kitlib import box as _kbox


def box(sx, sy, sz, bevel=0.0, segments=None):
    """kitlib.box, a plain chamfer (one segment) on the small parts: a 2-segment round on a
    lamp bezel costs 100 triangles nobody sees."""
    if segments is None:
        segments = 1 if max(sx, sy, sz) < 3.0 else 2
    if max(sx, sy, sz) < 0.45:
        bevel = 0.0  # (too small for a bevel to show)
    return _kbox(sx, sy, sz, bevel=bevel, segments=segments)


def _layer(name, fallback):
    """A layer the integrator may add to kitlib.LAYERS / PropKit LOOKS (red and amber lamp
    lenses); until then the nearest existing one."""
    return name if name in kitlib.LAYERS else fallback


LENS_RED = _layer("LensRed", "Rust")
LENS_AMBER = _layer("LensAmber", "Reflective")


# ==============================================================================================
# Generic geometry helpers
# ==============================================================================================
def _boolean(bm, cutters, op="DIFFERENCE"):
    """bm minus (or union / intersect) every cutter, with Blender's exact boolean. Frees inputs."""

    def obj(b, name):
        me = bpy.data.meshes.new(name)
        b.to_mesh(me)
        b.free()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob

    a = obj(bm, "_veh_bool")
    tmp = [a]
    for i, c in enumerate(cutters):
        o = obj(c, f"_veh_cut{i}")
        tmp.append(o)
        m = a.modifiers.new(f"b{i}", "BOOLEAN")
        m.operation = op
        m.object = o
        m.solver = "EXACT"
    dg = bpy.context.evaluated_depsgraph_get()
    ev = a.evaluated_get(dg)
    me = ev.to_mesh()
    out = bmesh.new()
    out.from_mesh(me)
    ev.to_mesh_clear()
    for o in tmp:
        data = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(data)
    return out


def _copy(bm):
    c = bm.copy()
    return c


def _slab(g0, g1):
    """A closed slab between two grids of points (rows x cols, same shape): g0 the inner face,
    g1 the outer one, side walls round the border."""
    bm = bmesh.new()
    rows, cols = len(g0), len(g0[0])
    v0 = [[bm.verts.new(p) for p in row] for row in g0]
    v1 = [[bm.verts.new(p) for p in row] for row in g1]
    for j in range(rows - 1):
        for i in range(cols - 1):
            bm.faces.new((v1[j][i], v1[j][i + 1], v1[j + 1][i + 1], v1[j + 1][i]))
            bm.faces.new((v0[j][i], v0[j + 1][i], v0[j + 1][i + 1], v0[j][i + 1]))
    border = ([(0, i) for i in range(cols)] + [(j, cols - 1) for j in range(1, rows)]
              + [(rows - 1, i) for i in range(cols - 2, -1, -1)] + [(j, 0) for j in range(rows - 2, 0, -1)])
    for k in range(len(border)):
        a, b = border[k], border[(k + 1) % len(border)]
        bm.faces.new((v0[a[0]][a[1]], v0[b[0]][b[1]], v1[b[0]][b[1]], v1[a[0]][a[1]]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    return bm


def _cells_slab(points, keep, na, nb):
    """A closed slab made of the kept cells of a grid. points[(i, j)] = (inner, outer) Vectors
    (i < na + 1, j < nb + 1; missing = no surface there); keep(i, j) for cell (i, j)."""
    cells = set()
    for i in range(na):
        for j in range(nb):
            ks = ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))
            if all(k in points for k in ks) and keep(i, j):
                cells.add((i, j))
    bm = bmesh.new()
    if not cells:
        return bm
    vin, vout = {}, {}

    def vi(k):
        if k not in vin:
            vin[k] = bm.verts.new(points[k][0])
        return vin[k]

    def vo(k):
        if k not in vout:
            vout[k] = bm.verts.new(points[k][1])
        return vout[k]

    for i, j in cells:
        ks = ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))
        bm.faces.new([vo(k) for k in ks])
        bm.faces.new([vi(k) for k in reversed(ks)])
        edges = (((i, j), (i + 1, j), (i, j - 1)), ((i + 1, j), (i + 1, j + 1), (i + 1, j)),
                 ((i + 1, j + 1), (i, j + 1), (i, j + 1)), ((i, j + 1), (i, j), (i - 1, j)))
        for a, b, nb_cell in edges:
            if nb_cell not in cells:
                bm.faces.new((vi(a), vi(b), vo(b), vo(a)))
    return bm


def _card(bvh, c, ua, va, d, na, nb, keep=None, off0=0.0, off1=0.02, jitter=0.0, noise=None):
    """A thin closed slab laid on a surface (its BVH): a grid c + a*ua + b*va (a, b in -1..1,
    na x nb cells) is ray-cast along d onto the surface and each hit pushed out along the
    surface normal by off0 (inner face) and off1 (outer face). keep(a, b) picks the cells (the
    centre of each cell, in -1..1); cells whose corners miss the surface are dropped."""
    c, ua, va, d = Vector(c), Vector(ua), Vector(va), Vector(d).normalized()
    pts = {}
    for i in range(na + 1):
        for j in range(nb + 1):
            q = c + ua * (-1 + 2 * i / na) + va * (-1 + 2 * j / nb)
            if jitter and noise and 0 < i < na and 0 < j < nb:  # (ragged, not a pixel grid)
                e = q * 7.3
                q = q + ua * (jitter * 2 / na * noise.n(e)) + va * (jitter * 2 / nb * noise.n(e + Vector((5.1, 2.3, 7.7))))
            hit, nrm, _, _ = bvh.ray_cast(q - d * 2.5, d, 5.0)
            if hit is not None:
                if nrm.dot(d) > 0:
                    nrm = -nrm
                pts[(i, j)] = (hit + nrm * off0, hit + nrm * off1)

    def k(i, j):
        return keep is None or keep(-1 + 2 * (i + 0.5) / na, -1 + 2 * (j + 0.5) / nb)

    return _cells_slab(pts, k, na, nb)


def _blob(bvh, c, ua, va, d, noise, seed, off0=-0.01, off1=0.022, n=11, rings=(1.0,)):
    """An organic closed patch (a rust scab, a stain) laid on a surface: a lobed outline round c
    (half axes ua, va, ray-cast along d), two rings so it follows the curvature, pushed out by
    off0 / off1 along the surface normal. Rays that miss (a wheel arch) drop that spoke."""
    c, ua, va, d = Vector(c), Vector(ua), Vector(va), Vector(d).normalized()
    seed = Vector(seed)

    def cast(q):
        hit, nrm, _, _ = bvh.ray_cast(q - d * 2.5, d, 5.0)
        if hit is None:
            return None
        if nrm.dot(d) > 0:
            nrm = -nrm
        return hit + nrm * off0, hit + nrm * off1

    mid = cast(c)
    if mid is None:
        return bmesh.new()
    spokes = []
    for k in range(n):
        a = 2 * math.pi * k / n
        lobe = 0.55 + 0.45 * (0.5 + 0.5 * noise.fbm(seed + Vector((math.cos(a), math.sin(a), 0.0)) * 1.6, 2))
        pts = [cast(c + (ua * math.cos(a) + va * math.sin(a)) * lobe * f) for f in rings]
        if all(pts):
            spokes.append(pts)
    bm = bmesh.new()
    if len(spokes) < 3:
        return bm
    ci, co = bm.verts.new(mid[0]), bm.verts.new(mid[1])
    ins = [[bm.verts.new(p[0]) for p in sp] for sp in spokes]
    outs = [[bm.verts.new(p[1]) for p in sp] for sp in spokes]
    m, last = len(spokes), len(rings) - 1
    for k in range(m):
        j = (k + 1) % m
        bm.faces.new((co, outs[k][0], outs[j][0]))
        bm.faces.new((ci, ins[j][0], ins[k][0]))
        for r in range(last):
            bm.faces.new((outs[k][r], outs[k][r + 1], outs[j][r + 1], outs[j][r]))
            bm.faces.new((ins[k][r], ins[j][r], ins[j][r + 1], ins[k][r + 1]))
        bm.faces.new((ins[k][last], ins[j][last], outs[j][last], outs[k][last]))
    return bm


def _bvh(bm):
    bm.normal_update()
    return BVHTree.FromBMesh(bm)


def _ring(points_xy, z):
    return [(x, y, z) for x, y in points_xy]


def _sweep(path, profile, closed=False, cap=True):
    """A profile [(n, y)] swept along a plan path [(x, z)] (y up): n is measured along the path's
    horizontal outward normal (the left of the direction of travel, +90 degrees)."""
    rings = []
    m = len(path)
    for k in range(m):
        x, z = path[k]
        if closed:
            px, pz = path[k - 1]
            nx, nz = path[(k + 1) % m]
        else:
            px, pz = path[max(k - 1, 0)]
            nx, nz = path[min(k + 1, m - 1)]
        dx, dz = nx - px, nz - pz
        ln = math.hypot(dx, dz) or 1.0
        ox, oz = dz / ln, -dx / ln
        rings.append([(x + ox * n, y, z + oz * n) for n, y in profile])
    return loft(rings, closed_profile=closed, cap_start=cap and not closed, cap_end=cap and not closed)


def _frame(cx, cy, cz, w, h, t, d, bev=0.012):
    """A rectangular frame (bezel) in the XY plane: outer w x h, bar width t, depth d (along Z)."""
    out = []
    for (sx, sy, ox, oy) in ((w, t, 0, (h - t) / 2), (w, t, 0, -(h - t) / 2),
                             (t, h - 2 * t + 0.002, (w - t) / 2, 0), (t, h - 2 * t + 0.002, -(w - t) / 2, 0)):
        out.append((box(sx, sy, d, bevel=0.0), T(cx + ox, cy + oy, cz)))
    return out


def _rot_x_wheel(bm):
    """A lathe made round Y turned to roll along Z (its axis on X)."""
    bmesh.ops.transform(bm, matrix=R(0, 0, -90), verts=bm.verts)
    return bm


class Lift:
    """ctx.add through a fixed matrix (the car raised on its jack stands, a dropped bumper)."""

    def __init__(self, ctx, matrix):
        self.ctx, self.m = ctx, matrix

    def add(self, layer, bm, matrix=None):
        self.ctx.add(layer, bm, self.m @ matrix if matrix is not None else self.m)


# ==============================================================================================
# SEDAN
# ==============================================================================================
L_HALF = 7.5  # body ends (bumpers stand 0.28 past them)
W_HALF = 3.1
PLAN_R = 0.7  # the plan corners' radius
BELT = 2.84  # hood / deck / belt height
WHEEL_R = 1.2
WHEEL_Z = 4.8
WHEEL_X = 2.72  # wheel centre (the tread's outer face ~3.15, flush with the body side)
ARCH_R = 1.48

# The lower body's half cross-section, normalised: (x / half width, (y - bottom) / height), from
# the bottom centre round the right side to the top centre: a flat floor, the sill tucking under,
# the slab side bulging 1 %, a shoulder crease, the crowned top.
PROF = [(0.0, 0.0), (0.82, 0.0), (0.985, 0.08), (1.012, 0.42), (1.008, 0.62),
        (0.99, 0.79), (0.968, 0.9), (0.93, 0.96), (0.86, 0.99), (0.5, 1.01), (0.0, 1.018)]


def sed_w(z):
    a = abs(z)
    if a <= L_HALF - PLAN_R:
        return W_HALF
    t = math.asin(min(1.0, (a - (L_HALF - PLAN_R)) / PLAN_R))
    return W_HALF - PLAN_R + PLAN_R * math.cos(t)


def sed_top(z):
    if z < -4.45:
        return BELT - 0.2 * ((-4.45 - z) / 3.05) ** 1.6
    if z > 5.0:
        return BELT - 0.1 * ((z - 5.0) / 2.5) ** 2
    return BELT


def sed_bot(z):
    a = abs(z)
    return 0.78 + 0.22 * smoothstep(6.3, L_HALF, a)


def _end_stations():
    out = []
    for deg in (0, 25, 50, 68, 82, 90):
        out.append(L_HALF - PLAN_R + PLAN_R * math.sin(math.radians(deg)))
    return out


def sedan_lower_rings(bay=False):
    """The rings of the lower body. bay=True: the engine bay is open (hood up): the top between
    the fender tops is sunk to the bay floor from the radiator support to the cowl."""
    mid = [-6.35, -4.45, -3.5, -0.4, 2.9, 3.6, 5.0]
    if bay:
        mid += [-7.25, -7.1, -4.7, -4.58]
    ends = _end_stations()
    zs = sorted(set([-e for e in ends] + mid + ends))
    rings = []
    for z in zs:
        w, bot, top = sed_w(z), sed_bot(z), sed_top(z)
        a = abs(z)
        if a > L_HALF - 0.01:  # (the end ring: rounded off top and bottom)
            bot, top, w = bot + 0.07, top - 0.07, w - 0.02
        elif a > L_HALF - 0.05:
            bot, top = bot + 0.025, top - 0.025
        sunk = bay and -7.15 <= z <= -4.65
        ring = []
        for xn, yn in PROF:
            x = xn * w
            y = bot + yn * (top - bot)
            if sunk and xn < 0.8:
                y = 2.12 - 0.04 * (1 - xn)
            ring.append((x, y, z))
        rings.append(ring + [(-x, y, z) for (x, y, z) in reversed(ring[1:-1])])
    return rings


def _wheel_cutters(zs=(-WHEEL_Z, WHEEL_Z), r=ARCH_R, cx=2.95, length=1.5, cy=WHEEL_R, segs=22):
    out = []
    for z in zs:
        for sx in (-1, 1):
            c = _rot_x_wheel(cyl(r, length, segs))
            bmesh.ops.translate(c, vec=(sx * cx, cy, z), verts=c.verts)
            out.append(c)
    return out


def _arch_liner(ctx, z, sx, r=ARCH_R, cy=WHEEL_R, floor=0.8, x_in=2.21, x_lip=3.16, layer="Black", lift=None):
    """The black wheel-well liner: an arched band just inside the cut (its front edge a lip
    0.02-0.05 proud of the body side) and the inner wall closing the well."""
    th0 = math.asin(max(-1.0, min(1.0, (floor - cy) / (r - 0.02))))
    arc = [th0 + (math.pi - 2 * th0) * k / 7 for k in range(8)]
    ro, ri = r - 0.02, r - 0.08
    poly = [(cy + ro * math.sin(a), z + ro * math.cos(a)) for a in arc]
    poly += [(cy + ri * math.sin(a), z + ri * math.cos(a)) for a in reversed(arc)]
    rings = [[(sx * x, y, zz) for y, zz in poly] for x in (x_in + 0.03, x_lip)]
    add = lift.add if lift else ctx.add
    add(layer, loft(rings, cap_start=True, cap_end=True))
    d = [(cy + (r - 0.01) * math.sin(a), z + (r - 0.01) * math.cos(a)) for a in arc]
    rings = [[(sx * x, y, zz) for y, zz in d] for x in (x_in, x_in + 0.07)]
    add(layer, loft(rings, cap_start=True, cap_end=True))


# ---------------------------------------------------------------------------------- greenhouse
class Greenhouse:
    """The cabin's glass solid as a function: point(z, s) on its outside, s in [-1, 1] going
    from the left belt over the roof (s = 0 the roof's middle) to the right belt; slab(...)
    lays a closed slab on a (s, z) window of it."""

    def __init__(self, z0=-4.3, z1=4.9, wb=2.84, tumble=0.2, base=2.70, top=4.5, crown=0.12, rc=0.22,
                 wind_top=-2.0, rear_top=2.95):
        self.z0, self.z1, self.wb, self.tumble, self.base = z0, z1, wb, tumble, base
        self.top, self.crown, self.rc = top, crown, rc
        self.base_y = base + 0.1
        self.ws = (top - self.base_y) / (wind_top - z0)  # windscreen slope
        self.rs = (top - self.base_y) / (z1 - rear_top)
        self.wind_top, self.rear_top = wind_top, rear_top
        self.hfull = top - base
        self.cy = base + 0.35 * (top - base)  # (a point inside, to orient normals)

    def H(self, z):
        a = self.base_y + (z - self.z0) * self.ws
        b = self.top + 0.04 * math.sin(math.pi * min(1, max(0, (z - self.wind_top) / (self.rear_top - self.wind_top))))
        c = self.base_y + (self.z1 - z) * self.rs
        k = 0.09
        m = min(a, b, c)
        return m - k * math.log(sum(math.exp(-(v - m) / k) for v in (a, b, c)))

    def point(self, z, s):
        sign = 1.0 if s >= 0 else -1.0
        s = min(1.0, abs(s))
        H = self.H(z)
        h = max(0.03, H - self.base)
        kk = min(1.0, h / self.hfull)
        wt = self.wb - self.tumble * kk
        rc = min(self.rc, 0.42 * h)
        crown = self.crown * min(1.0, h / 0.6)

        def roofy(x):
            return H + crown * (1 - (x / wt) ** 2)

        if s <= 0.45:
            x = s / 0.45 * (wt - rc)
            y = roofy(x)
        elif s <= 0.6:
            a = (s - 0.45) / 0.15 * math.pi / 2
            cx = wt - rc
            cy = roofy(cx) - rc
            x, y = cx + rc * math.sin(a), cy + rc * math.cos(a)
        else:
            t = (s - 0.6) / 0.4
            ytop = roofy(wt - rc) - rc
            x, y = lerp(wt, self.wb, t), lerp(ytop, self.base, t)
        return Vector((sign * x, y, z))

    def normal(self, z, s):
        dz, ds = 0.01, 0.004
        a = self.point(z + dz, s) - self.point(z - dz, s)
        b = self.point(z, min(1.0, s + ds)) - self.point(z, max(-1.0, s - ds))
        n = a.cross(b)
        if n.length < 1e-9:
            n = Vector((0, 1, 0))
        n.normalize()
        p = self.point(z, s)
        if n.dot(p - Vector((0, self.cy, z))) < 0:
            n = -n
        return n

    def solid(self, stations=None):
        S = [0.0, 0.22, 0.45, 0.52, 0.6, 0.8, 1.0]
        zs = stations or [self.z0, self.z0 + 0.15, -3.7, -3.0, -2.4, -2.0, -1.6, -0.35, 0.0, 1.75, 2.6, 3.0,
                          3.5, 4.2, self.z1 - 0.12, self.z1]
        rings = []
        for z in zs:
            right = [tuple(self.point(z, s)) for s in S]
            left = [tuple(self.point(z, -s)) for s in reversed(S[1:])]
            rings.append(right + [(0.0, self.base, z)] + left)
        return loft(rings, cap_start=True, cap_end=True)

    def slab(self, s0, s1, z0, z1, ns, nz, off=-0.01, th=0.05, dent=None):
        g0, g1 = [], []
        for j in range(nz + 1):
            z = lerp(z0, z1, j / nz)
            r0, r1 = [], []
            for i in range(ns + 1):
                s = lerp(s0, s1, i / ns)
                p, n = self.point(z, s), self.normal(z, s)
                if dent:
                    p = p + n * dent(p)
                r0.append(p + n * off)
                r1.append(p + n * (off + th))
            g0.append(r0)
            g1.append(r1)
        return _slab(g0, g1)


# ---------------------------------------------------------------------------------- wheels
def _tyre(flat=0.0, segs=22, r=WHEEL_R, hw=0.43, bead=0.8):
    """A tyre round X, centred (+X the outer face): a flat tread band with rounded shoulders,
    the outer sidewall bulging past the rim (a real 70-series tyre's balloon), a plainer inner
    side nobody sees; the bottom pressed flat on the road (flat > 0: a flat tyre, its sidewall
    bulging out). 22 sides: the outline stays round at eye level."""
    k = r / 1.2
    prof = [(bead, -hw * 0.82), (r - 0.07 * k, -hw * 0.97), (r, -hw * 0.5), (r, hw * 0.42),
            (r - 0.04 * k, hw * 0.83), (r - 0.2 * k, hw * 1.03), (bead + 0.13 * k, hw * 1.02),
            (bead, hw * 0.86)]
    bm = _rot_x_wheel(lathe(prof, segs))
    floor = -r + 0.03 + flat
    for v in bm.verts:
        y = v.co.y
        if y < floor:
            v.co.y = floor - (floor - y) * 0.12
            if flat > 0:
                v.co.x *= 1 + 0.35 * flat * smoothstep(floor, -r, y) / max(abs(v.co.x), 0.3)
    return bm


def _wheel_cover(segs=16):
    """A 90s full wheel cover, pressed steel painted silver: a domed centre cap, a dished ring
    falling from it, a raised ridge ring, the flat outer band and the rolled lip tucked into
    the tyre's bead (its slots are added by _add_wheel)."""
    prof = [(0.0, 0.5), (0.13, 0.49), (0.18, 0.42), (0.33, 0.385), (0.57, 0.39), (0.65, 0.47), (0.8, 0.425),
            (0.86, 0.33), (0.0, 0.33)]
    return _rot_x_wheel(lathe(prof, segs))


def _steel_wheel(segs=16):
    """A plain pressed-steel wheel: rim lip, the dish stepping in to the hub face, a ring of
    ventilation holes (dark, added by _add_wheel), the hub (lug nuts added separately)."""
    prof = [(0.0, 0.3), (0.22, 0.37), (0.34, 0.31), (0.55, 0.31), (0.84, 0.43), (0.86, 0.36), (0.0, 0.3)]
    return _rot_x_wheel(lathe(prof, segs))


def _wheel_slots(add, m, n, rad, axial, size, layer="Black", a0=0.0):
    """n dark slots / holes on a wheel face (lathe space: axial along Y), turned onto X."""
    for j in range(n):
        a = a0 + 2 * math.pi * j / n
        bm = _kbox(size[0], 0.03, size[1])
        bmesh.ops.transform(bm, matrix=Matrix.Rotation(-a, 4, "Y"), verts=bm.verts)
        bmesh.ops.translate(bm, vec=Vector((rad * math.cos(a), axial, rad * math.sin(a))), verts=bm.verts)
        add(layer, _rot_x_wheel(bm), m)


def _add_wheel(add, x, z, style, sx, flat=0.0, cy=WHEEL_R, tyre_layer="Rubber", k=1.0, segs=None, nuts=5, holes=0,
               tyre_segs=None):
    """One road wheel at (x, cy, z) on side sx (+1 right): tyre + cover / steel wheel (k: size).
    Wheels are mid-grey steel (Metal), never chrome-white: the brake dust and road grime are
    the wheel layer's vertex colours (see _wheel_wear)."""
    m = T(x, cy, z) @ (R(0, 180, 0) if sx < 0 else R()) @ S(k)
    add(tyre_layer, _tyre(flat=flat, segs=tyre_segs or segs or 22), m)
    if style == "cover":
        add("Metal", _wheel_cover(), m)
        _wheel_slots(add, m, 6, 0.46, 0.392, (0.2, 0.075), a0=0.2)
    elif style in ("steel", "rusty"):
        add("Metal", _steel_wheel(segs or 16), m)
        if holes:
            _wheel_slots(add, m, holes, 0.47, 0.316, (0.12, 0.1))
        hub = _rot_x_wheel(cyl(0.14, 0.12, 8))
        add("Rust" if style == "rusty" else "Black", hub, m @ T(0.38, 0, 0))
        for j in range(nuts):
            a = 2 * math.pi * j / max(nuts, 1)
            nut = _rot_x_wheel(cyl(0.045, 0.08, 5))
            add("Metal", nut, m @ T(0.39, 0.25 * math.cos(a), 0.25 * math.sin(a)))
        if style == "rusty":  # (rust weeping from the holes and the rim over the dark steel)
            for j, (a, ln) in enumerate(((0.4, 0.18), (1.9, 0.13), (3.5, 0.16), (5.0, 0.12))):
                bm = _kbox(ln, 0.03, 0.05)
                bmesh.ops.translate(bm, vec=Vector((ln / 2, 0, 0)), verts=bm.verts)
                bmesh.ops.transform(bm, matrix=Matrix.Rotation(-a, 4, "Y"), verts=bm.verts)
                bmesh.ops.translate(bm, vec=Vector((0.36 * math.cos(a), 0.322, 0.36 * math.sin(a))), verts=bm.verts)
                add("Rust", _rot_x_wheel(bm), m)
    elif style == "hubcap":  # (a steel wheel with a small domed dog-dish cap, satin steel)
        # (only the outer ring of the wheel shows round the cap: its middle is left plain)
        add("Metal", _rot_x_wheel(lathe([(0.0, 0.31), (0.55, 0.31), (0.84, 0.43), (0.86, 0.36), (0.0, 0.3)], 18)), m)
        cap = _rot_x_wheel(lathe([(0.0, 0.5), (0.2, 0.485), (0.36, 0.43), (0.43, 0.34), (0.0, 0.32)], 18))
        add("Metal", cap, m)


def _tyre_wear(wheels, cy, noise):
    """Tyres: the tread band darker and greasy, the sidewalls a little dusty toward the road."""

    def fn(p):
        best = 0.0
        for wx, wz in wheels:
            if abs(abs(p.co.x) - wx) < 0.7:
                best = max(best, math.hypot(p.co.y - cy, p.co.z - wz))
        tread = smoothstep(WHEEL_R - 0.09, WHEEL_R - 0.02, best) if best else 0.0
        low = 1 - 0.18 * (1 - smoothstep(0.0, 0.8, p.co.y - cy + WHEEL_R))
        cav = 1 - 0.25 * smoothstep(0.0, 0.45, -p.convex)
        return (1 - 0.3 * tread) * low * cav * (0.92 + 0.08 * noise.n(p.co * 9.0))

    return fn


def _rust_wear(noise, mask=None):
    """Rust: dark brown in the heart of a patch (the metal eaten through), the brighter orange
    only along its ragged edge where the paint is still lifting; loose rusty parts (a hub, a
    hanging bumper) dark with orange streaks. `mask(p)` is how deep inside a body patch p is
    (0 at its edge), or None for parts that are not body patches."""

    def fn(p):
        cav = 1 - 0.3 * smoothstep(0.0, 0.45, -p.convex)
        m = mask(p.co) if mask else None
        if m is None:
            streak = smoothstep(0.1, 0.6, noise.fbm(Vector((p.co.x * 5, p.co.y * 0.8, p.co.z * 5)), 2))
            k = 0.62 + 0.38 * streak
        else:
            k = 0.82 - 0.4 * smoothstep(0.02, 0.12, m) + 0.06 * noise.n(p.co * 11.0)
        return (k * cav, k * 0.94 * cav, k * 0.9 * cav)

    return fn


def _wheel_wear(wheels, cy, level, noise, rusty=False):
    """The wheels' vertex colours (the Metal layer, also its other small steel parts): brake
    dust and road grime darkening toward the rim (brown-grey), cleaner toward the centre; a rusty
    wheel goes dark steel. Parts away from the wheels: grime in creases."""

    def fn(p):
        best = None
        for wx, wz in wheels:
            if abs(abs(p.co.x) - wx) < 0.7:
                d = math.hypot(p.co.y - cy, p.co.z - wz)
                if d < 1.0 and (best is None or d < best):
                    best = d
        cav = 1 - 0.3 * smoothstep(0.0, 0.45, -p.convex)
        if best is None:
            return cav * (1 - 0.2 * level)
        dust = smoothstep(0.35, 0.86, best) * (0.75 + 0.25 * noise.n(p.co * 6.0))
        k = (1 - (0.25 + 0.3 * level) * dust) * 0.8  # (satin steel, never bright: ~105 grey)
        c = (k * 1.0, k * 0.93, k * 0.84)  # (brake dust is brown)
        if rusty:
            c = (c[0] * 0.55, c[1] * 0.52, c[2] * 0.5)
        return tuple(v * cav for v in c)

    return fn


def _brake(add, x, z, sx, cy):
    """A bare hub (the wheel off): brake disc, hat, five studs, caliper."""
    m = T(x, cy, z) @ (R(0, 180, 0) if sx < 0 else R())
    disc = _rot_x_wheel(lathe([(0.3, -0.06), (0.76, -0.06), (0.76, 0.06), (0.3, 0.06)], 14))
    add("Metal", disc, m @ T(-0.15, 0, 0))
    hat = _rot_x_wheel(lathe([(0.0, 0.1), (0.35, 0.09), (0.36, -0.1), (0.0, -0.1)], 12))
    add("Rust", hat, m @ T(-0.06, 0, 0))
    for k in range(5):
        a = 2 * math.pi * k / 5
        add("Metal", box(0.2, 0.06, 0.06), m @ T(0.08, 0.22 * math.cos(a), 0.22 * math.sin(a)))
    add("Black", box(0.3, 0.42, 0.5), m @ T(-0.2, 0.42, 0.5) @ R(-35, 0, 0))


# ---------------------------------------------------------------------------------- wear
def _car_wear(ctx, lift=0.0, level=0.4, wheels=((WHEEL_X, -WHEEL_Z), (WHEEL_X, WHEEL_Z)), arch=1.6):
    n = ctx.noise

    def fn(p):
        y = p.co.y - lift
        dirt = 1 - (0.16 + 0.22 * level) * (1 - smoothstep(0.0, 1.2 + 0.5 * level + 0.35 * n.fbm(p.co, 2, 1.3), y))
        a = 1.0
        for wx, wz in wheels:
            d = math.hypot(p.co.z - wz, y - WHEEL_R)
            if abs(abs(p.co.x) - wx) < 1.2:
                a = min(a, 1 - (0.2 + 0.25 * level) * (1 - smoothstep(arch - 0.2, arch + 0.55, d)))
        cav = 1 - 0.35 * smoothstep(0.0, 0.45, -p.convex)
        edge = 1 + 0.06 * smoothstep(0.1, 0.5, p.convex)
        q = (p.co.x * 5.0, y * 0.4, p.co.z * 5.0)
        streak = 1 - 0.1 * level * smoothstep(0.2, 0.75, n.fbm(q, 2))
        blot = 1 - 0.18 * level * smoothstep(0.55, 0.85, n.fbm(p.co, 3, 1.1) * 0.5 + 0.5)
        return dirt * a * cav * edge * streak * blot

    return fn


def _glass_wear(ctx, g, level=0.4, lift=0.0):
    n = ctx.noise
    pivots = (Vector((-1.15, g.base_y + lift + 0.15, g.z0 + 0.25)), Vector((0.55, g.base_y + lift + 0.15, g.z0 + 0.25)))

    def fn(p):
        y = p.co.y - lift
        dust = 1 - (0.14 + 0.3 * level) * (0.6 + 0.4 * n.fbm(p.co, 2, 0.8))
        if p.co.z < g.wind_top + 0.1 and p.normal.y > 0.2:
            swept = any((p.co - c).length < 1.95 for c in pivots)
            dust = 1 - (0.2 + 0.25 * level) if not swept else 0.97
        low = 1 - 0.12 * (1 - smoothstep(g.base + 0.1, g.base + 0.7, y))
        return dust * low

    return fn


# ---------------------------------------------------------------------------------- the build
def sedan(ctx, kind="clean"):
    """kind: clean, worn, taxi, wrecked, jacks."""
    worn = kind in ("worn", "wrecked")
    lift = 1.05 if kind == "jacks" else 0.0
    L = Lift(ctx, T(0, lift, 0))
    add = L.add
    rng, noise = ctx.rng, ctx.noise
    level = {"clean": 0.25, "taxi": 0.4, "jacks": 0.55, "worn": 0.75, "wrecked": 1.0}[kind]
    g = Greenhouse()

    # ---- lower body
    body = loft(sedan_lower_rings(bay=(kind == "jacks")), cap_start=True, cap_end=True)
    body = _boolean(body, _wheel_cutters())
    body.normal_update()
    dents = []
    if kind == "worn":
        dents = [(Vector((3.15, 1.6, 1.4)), 0.55, 0.09), (Vector((-2.9, 1.2, 7.4)), 0.5, 0.07)]
    elif kind == "wrecked":
        dents = [(Vector((-3.15, 1.6, -1.0)), 0.9, 0.2), (Vector((-3.0, 2.2, -1.8)), 0.5, 0.1),
                 (Vector((2.4, 2.1, -7.5)), 0.8, 0.22), (Vector((0.6, 2.5, -7.5)), 0.6, 0.12),
                 (Vector((3.0, 1.4, 6.6)), 0.6, 0.1), (Vector((-1.5, 2.85, 6.2)), 0.7, 0.06)]
    if dents:
        for v in body.verts:
            for c, rad, depth in dents:
                d = (v.co - c).length
                if d < rad * 2.2:
                    v.co -= v.normal * depth * math.exp(-(d / rad) ** 2) * (0.75 + 0.5 * noise.n(v.co * 3) * 0.5)
        body.normal_update()
    bvh = _bvh(body)
    add("MetalPainted", body)

    for z in (-WHEEL_Z, WHEEL_Z):
        for sx in (-1, 1):
            _arch_liner(ctx, z, sx, lift=L)

    def card(layer, c, ua, va, d, na, nb, keep=None, off0=-0.005, off1=0.02, jitter=0.0):
        bm = _card(bvh, c, ua, va, d, na, nb, keep, off0, off1, jitter, noise)
        if bm.verts:
            add(layer, bm)
        else:
            bm.free()

    # door gaps, hood and deck seams (dark lines just proud)
    for sx in (-1, 1):
        for zz, y0, y1 in ((-3.15, 0.98, 2.78), (-0.2, 0.92, 2.8), (3.08, 1.9, 2.8)):
            card("Black", (sx * 3.0, (y0 + y1) / 2, zz), (0, 0, 0.012), (0, (y1 - y0) / 2, 0), (-sx, 0, 0), 1, 3,
                 off0=-0.01, off1=0.012)
        card("Black", (sx * 2.58, 3.0, -5.95), (0, 0, 1.45), (0.012, 0, 0), (0, -1, 0), 3, 1, off0=-0.01, off1=0.012)
        card("Black", (sx * 2.58, 3.0, 6.25), (0, 0, 1.2), (0.012, 0, 0), (0, -1, 0), 3, 1, off0=-0.01, off1=0.012)
    if kind != "jacks":
        card("Black", (0, 3.0, -4.5), (2.58, 0, 0), (0, 0, 0.012), (0, -1, 0), 6, 1, off0=-0.01, off1=0.012)
    card("Black", (0, 3.0, 5.02), (2.58, 0, 0), (0, 0, 0.012), (0, -1, 0), 6, 1, off0=-0.01, off1=0.012)
    card("Black", (0, 2.46, 7.6), (2.3, 0, 0), (0, 0.012, 0), (0, 0, -1), 4, 1, off0=-0.01, off1=0.012)

    # body-side moulding (black rubber with a chrome top line on the clean cars)
    for sx in ((-1,) if kind == "wrecked" else (-1, 1)):  # (the wreck lost its right moulding)
        for z0, z1 in ((-7.2, -6.45), (-3.25, 3.25), (6.45, 7.2)):
            c = ((z0 + z1) / 2)
            card("Black", (sx * 3.0, 1.62, c), (0, 0, (z1 - z0) / 2), (0, 0.07, 0), (-sx, 0, 0),
                 max(2, int((z1 - z0) / 1.1)), 1, off0=-0.01, off1=0.055)
            if kind == "clean":
                card("Chrome", (sx * 3.0, 1.71, c), (0, 0, (z1 - z0) / 2), (0, 0.018, 0), (-sx, 0, 0),
                     max(2, int((z1 - z0) / 1.1)), 1, off0=-0.01, off1=0.04)

    # rust (worn / wrecked): ragged patches where water sits on a real car - along the sills,
    # round the wheel-arch lips, at the bottom of the door seams, on the deck lid - never round
    # spots in the middle of a panel. Each patch is dark in its heart and orange only along its
    # edge (_rust_wear reads rust_mask: how deep inside a patch a point is).
    patches = []

    def scab(c, ua, va, seed, n=7):
        c, ua, va = Vector(c), Vector(ua), Vector(va)
        d = Vector((-1 if c.x > 0 else 1, 0, 0)) if abs(c.x) > 2.5 else Vector((0, -1, 0))
        bm = _blob(bvh, c, ua, va, d, noise, seed, n=n)
        if bm.verts:
            add("Rust", bm)
            patches.append((c, ua, va))
        else:
            bm.free()

    if worn:
        wreck = kind == "wrecked"
        for sx in (-1, 1):
            x = sx * 3.0
            # sills: long ragged runs between the arches, lifting the paint above them
            runs = ((-2.0, 1.25), (0.6, 1.1), (2.5, 0.65)) if wreck else ((-1.4 * sx, 0.8),)
            for k, (z, hz) in enumerate(runs):
                scab((x, 1.08 if wreck else 1.02, z), (0, 0, hz), (0, 0.3 if wreck else 0.14, 0), (x, 1.0 + k, z))
            # arch lips: short patches following the arc just outside the cut
            for wz in (-WHEEL_Z, WHEEL_Z):
                angs = (55, 125) if wreck else ((150,) if wz < 0 else (40,))
                for a in angs:
                    t = math.radians(a)
                    rr = ARCH_R + 0.14
                    c = (x, WHEEL_R + rr * math.sin(t), wz + rr * math.cos(t))
                    tang = (0, 0.42 * math.cos(t), -0.42 * math.sin(t))
                    nrm = (0, 0.18 * math.sin(t), 0.18 * math.cos(t))
                    scab(c, tang, nrm, (x, a * 0.1, wz))
            if wreck:  # the bottoms of the door seams, rust running up them
                for zz in ((-3.15,) if sx < 0 else (-0.2,)):
                    scab((x, 1.25, zz), (0, 0.32, 0), (0, 0, 0.12), (x, 7.0, zz), n=6)
        for z, x, hx, hz in ((6.3, -1.2, 1.1, 0.8),) if wreck else ((-6.3, 2.2, 0.5, 0.4),):
            bm = _blob(bvh, (x, 3.2, z), (hx, 0, 0), (0, 0, hz), (0, -1, 0), noise, (x, 9.0, z), n=12, rings=(0.55, 1.0))
            if bm.verts:
                add("Rust", bm)
                patches.append((Vector((x, 3.2, z)), Vector((hx, 0, 0)), Vector((0, 0, hz))))
            else:
                bm.free()

    def rust_mask(q):
        best = None
        for c, ua, va in patches:
            dq = q - Vector((0, lift, 0)) - c
            if abs(dq.x) > 0.4 and abs(c.x) > 2.5:
                continue
            ea = dq.dot(ua) / ua.length_squared
            eb = dq.dot(va) / va.length_squared
            e = math.hypot(ea, eb)
            if e < 1.15:
                m = (1 - e) * min(ua.length, va.length) + 0.02
                best = m if best is None else max(best, m)
        return best

    if kind == "worn":
        # the front-left fender from a scrapyard: grey primer, side and top
        card("Concrete", (-3.0, 1.9, -5.35), (0, 0, 2.0), (0, 0.9, 0), (1, 0, 0), 9, 4,
             lambda a, b: not (a > 0.92 and b < 0.0), off0=-0.006, off1=0.016)
        card("Concrete", (-2.83, 3.0, -5.9), (0.25, 0, 0), (0, 0, 1.45), (0, -1, 0), 2, 6, off0=-0.006, off1=0.016)

    # ---- greenhouse: glass, then the metal laid on it
    gb = g.solid()
    if kind == "wrecked":
        pass
    add("Glass", gb)
    metal = "MetalPainted"
    add(metal, g.slab(-0.5, 0.5, g.wind_top + 0.05, g.rear_top - 0.03, 6, 5, th=0.055))  # roof skin
    for sx in (-1, 1):
        s0, s1 = (0.5, 0.64) if sx > 0 else (-0.64, -0.5)
        add(metal, g.slab(s0, s1, g.z0 + 0.02, 1.75, 2, 8, th=0.045))  # A pillar + roof side rail
        s0, s1 = (0.64, 1.0) if sx > 0 else (-1.0, -0.64)
        add(metal, g.slab(s0, s1, -0.36, -0.04, 4, 1, th=0.04))  # B pillar
        s0, s1 = (0.5, 1.0) if sx > 0 else (-1.0, -0.5)
        add(metal, g.slab(s0, s1, 1.75, g.z1 - 0.02, 4, 6, th=0.05))  # C pillar (formal, wide)
        s0, s1 = (0.62, 0.66) if sx > 0 else (-0.66, -0.62)
        add("Chrome" if kind in ("clean", "taxi") else "Black", g.slab(s0, s1, g.wind_top - 0.4, 1.75, 1, 5, off=0.03, th=0.03))
        s0, s1 = (0.93, 0.975) if sx > 0 else (-0.975, -0.93)
        add("Chrome" if kind != "wrecked" else "Black", g.slab(s0, s1, g.z0 + 0.35, 1.75, 1, 6, off=-0.01, th=0.04))
    add("Black", g.slab(-0.5, 0.5, g.z0 + 0.02, g.z0 + 0.14, 6, 1, off=-0.01, th=0.03))  # cowl seal
    add("Black", g.slab(-0.5, 0.5, g.z1 - 0.14, g.z1 - 0.02, 6, 1, off=-0.01, th=0.03))  # rear window seal

    # wipers (resting on the cowl, along the glass)
    for x0, x1 in ((-2.0, -0.25),) + (() if kind == "wrecked" else ((0.05, 1.75),)):
        z = g.z0 + 0.3
        y = g.H(z) + 0.035
        ang = math.degrees(math.atan(g.ws))
        add("Black", box(x1 - x0, 0.035, 0.06), T((x0 + x1) / 2, y, z) @ R(-ang, 0, 0))
        add("Black", box(0.07, 0.05, 0.3, bevel=0.015), T(x1 - 0.1, y - 0.02, z + 0.05) @ R(-ang, 0, 0))

    # ---- front end (z = -7.5)
    fz = -L_HALF
    smashed = kind == "wrecked"
    corner_glow = kind == "taxi"
    for sx in (-1, 1):
        hx = sx * 1.9
        if smashed:
            add("Black", box(0.92, 0.38, 0.1, bevel=0.02), T(hx, 2.08, fz - 0.01))
            for p in _frame(hx, 2.08, fz - 0.05, 1.04, 0.5, 0.07, 0.1):
                if rng.random() < 0.7:
                    add("Rust", *p)
        else:
            add("Reflective", box(0.94, 0.4, 0.12, bevel=0.03, segments=1), T(hx, 2.08, fz - 0.02))
            for p in _frame(hx, 2.08, fz - 0.05, 1.06, 0.52, 0.07, 0.11):
                add("Chrome", *p)
        # wraparound corner lamp on the rounded corner
        a = math.radians(48)
        cxp = sx * (W_HALF - PLAN_R + (PLAN_R + 0.015) * math.sin(a))
        czp = -(L_HALF - PLAN_R + (PLAN_R + 0.015) * math.cos(a))
        lamp = "Glow" if corner_glow else ("Black" if smashed else LENS_AMBER)
        add(lamp, box(0.52, 0.36, 0.09, bevel=0.025), T(cxp, 2.08, czp) @ R(0, -sx * 48, 0))
    # grille: chrome frame, black egg-crate, chrome bars
    gy = 2.09
    add("Black", box(2.5, 0.4, 0.1, bevel=0.02), T(0, gy, fz - 0.03))
    if True:  # (egg-crate bars and slats)
        for k in range(3):
            add("Chrome" if not worn else "Metal", box(2.5, 0.03, 0.05, bevel=0.008), T(0, gy - 0.12 + k * 0.12, fz - 0.075))
        for k in range(-3, 4):
            add("Black", box(0.03, 0.38, 0.05, bevel=0.0), T(k * 0.34, gy, fz - 0.065))
        for p in _frame(0, gy, fz - 0.06, 2.66, 0.54, 0.08, 0.12):
            add("Chrome" if kind != "wrecked" else "Rust", *p)
    add("Chrome", box(0.22, 0.12, 0.05, bevel=0.02), T(0, 2.6, fz + 0.05) @ R(20, 0, 0))  # hood ornament

    # ---- rear end (z = +7.5): wide tail lamps, reversing lamps, trunk lock
    rz = L_HALF
    for sx in (-1, 1):
        if kind == "taxi":
            add("Glow", box(0.36, 0.44, 0.1, bevel=0.025), T(sx * 2.15, 2.1, rz + 0.03))
            add(LENS_RED, box(0.84, 0.44, 0.1, bevel=0.025), T(sx * 1.53, 2.1, rz + 0.03))
        else:
            add(LENS_RED, box(1.2, 0.44, 0.1, bevel=0.025), T(sx * 1.71, 2.1, rz + 0.03))
        add("Reflective", box(0.28, 0.44, 0.1, bevel=0.025), T(sx * 0.94, 2.1, rz + 0.03))
        add(LENS_RED, box(0.03, 0.4, 0.04, bevel=0.0), T(sx * 1.71, 2.1, rz + 0.09))  # (the lens's divider)
        for p in _frame(sx * 1.55, 2.1, rz + 0.05, 1.68, 0.54, 0.06, 0.1):
            add("Chrome" if not worn else "Black", *p)
        # side marker lamps on the rear quarters
        add(LENS_RED, box(0.06, 0.16, 0.42, bevel=0.02), T(sx * 3.12, 1.95, 6.6))
    add("Chrome", box(0.22, 0.22, 0.05, bevel=0.03), T(0, 2.4, rz + 0.04))  # trunk lock

    # ---- bumpers: chrome (or grey plastic) wrapping round the corners, black rubber strip
    def bumper_path(front):
        sgn = -1 if front else 1
        pts = [(-3.0, sgn * 6.75)]
        for side in (-1, 1):
            arc = [(side * (2.5 + 0.5 * math.sin(math.radians(t))), sgn * (7.08 + 0.5 * math.cos(math.radians(t))))
                   for t in (range(90, -1, -30) if side < 0 else range(0, 91, 30))]
            pts += arc
        pts.append((3.0, sgn * 6.75))
        if not front:
            pts.reverse()
        return pts

    bprof = [(-0.14, 0.94), (0.1, 0.93), (0.19, 1.04), (0.21, 1.3), (0.19, 1.56), (0.1, 1.69), (-0.14, 1.68)]
    sprof = [(0.17, 1.22), (0.24, 1.25), (0.24, 1.35), (0.17, 1.38)]
    blayer = "Chrome" if kind in ("clean", "taxi", "jacks") else "PlasticDark"
    for front in (True, False):
        path = bumper_path(front)
        bm = _sweep(path, bprof)
        sb = _sweep(path, sprof)
        if kind == "wrecked" and front:
            # (torn off its right mount: hanging, its right end on the ground)
            m = T(-3.0, 1.5, -7.1) @ R(0, 0, -10) @ R(0, -4, 0) @ T(3.0, -1.5, 7.1)
            bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
            bmesh.ops.transform(sb, matrix=m, verts=sb.verts)
            add("Rust", bm)
            add("Black", sb)
            continue
        add(blayer if not (kind == "wrecked") else "Rust", bm)
        add("Black", sb)
        # licence plate on the bumper, its characters embossed
        pz = (-1 if front else 1) * 7.81
        add("Paper", box(1.5, 0.5, 0.05, bevel=0.015), T(0, 1.3, pz))
        sgn = -1 if front else 1
        for k in range(3):
            add("Black", box(0.3, 0.22, 0.03, bevel=0.0), T(-0.42 + k * 0.42, 1.28, pz + sgn * 0.03))
        add("Black", box(1.2, 0.03, 0.03, bevel=0.0), T(0, 1.49, pz + sgn * 0.03))
    if kind == "wrecked":  # the front plate fell: lying on the ground under the nose
        add("Paper", box(1.5, 0.05, 0.5, bevel=0.015), T(-0.6, 0.03, -7.2) @ R(0, 18, 0))

    # ---- mirrors, door handles, antenna, exhaust
    for sx in (-1, 1):
        p = g.point(-3.55, sx * 0.97)
        mx = sx * (abs(p.x) + 0.42)
        add("Black", box(0.5, 0.1, 0.18, bevel=0.03), T(sx * (abs(p.x) + 0.18), 3.05, -3.55))
        if not (kind == "wrecked" and sx < 0):
            add(metal if kind != "worn" else "PlasticDark", box(0.34, 0.36, 0.34, bevel=0.1), T(mx, 3.12, -3.55) @ R(0, sx * 8, 0))
            add("Glass", box(0.28, 0.3, 0.04, bevel=0.02), T(mx, 3.12, -3.36) @ R(0, sx * 8, 0))
        for zz in (-0.95, 2.45):
            add("Chrome", box(0.06, 0.08, 0.38), T(sx * 3.09, 2.36, zz))
    if kind == "clean" or kind == "taxi":
        add("Chrome", cyl(0.016, 1.6, 6), T(2.55, 3.6, -4.75))
        add("Chrome", cyl(0.05, 0.06, 8), T(2.55, 2.81, -4.75))
    elif kind == "worn":
        add("Chrome", cyl(0.016, 0.35, 4), T(2.55, 3.0, -4.75) @ R(0, 0, 25))  # (snapped off)
    if kind != "wrecked":  # (the wreck's tailpipe rusted off)
        ex = tube([(-1.75, 0.62, 5.9), (-1.75, 0.6, 7.2), (-1.78, 0.55, 7.7)], 0.085, 7)
        add("Rust" if worn else "Metal", ex)

    # ---- wheels
    style = {"clean": "cover", "taxi": "hubcap", "worn": "steel", "wrecked": "rusty", "jacks": None}[kind]
    for zz in (-WHEEL_Z, WHEEL_Z):
        for sx in (-1, 1):
            if kind == "jacks":
                _brake(add, sx * 2.6, zz, sx, WHEEL_R)
                continue
            if kind == "wrecked" and sx > 0 and zz > 0:
                # (the rear-right wheel gone: the axle on a breeze block and a scrap of plank)
                _brake(add, sx * 2.6, zz, sx, WHEEL_R)
                ctx.add("Concrete", box(0.75, 0.73, 1.45, bevel=0.04), T(2.25, 0.365, 4.75) @ R(0, 7, 0))
                ctx.add("Wood", box(0.9, 0.08, 1.2), T(2.25, 0.77, 4.7) @ R(0, -5, 1.5))
                continue
            st = style
            if kind == "worn" and sx < 0 and zz < 0:
                st = "hubcap"  # (the odd one: a different wheel)
            flat = 0.32 if (kind == "wrecked" and sx < 0 and zz < 0) else 0.0
            _add_wheel(add, sx * WHEEL_X, zz, st, sx, flat=flat, nuts=4,
                       tyre_layer="RubberWorn" if kind == "wrecked" else "Rubber",
                       tyre_segs={"wrecked": 16, "taxi": 20, "worn": 20}.get(kind, 22))

    # ---- kind specials
    if kind == "taxi":
        _taxi_sign(add, g)
        _checker(card)
        ctx.mark("Light", (0, 2.1, L_HALF + 0.25))
    if kind == "wrecked":
        _wreck_specials(ctx, add, g, rng, noise)
    if kind == "jacks":
        _jacks_specials(ctx, add, g, lift)

    # ---- wear
    wheels = ((WHEEL_X, -WHEEL_Z), (WHEEL_X, WHEEL_Z))
    ctx.wear("MetalPainted", _car_wear(ctx, lift, level, wheels))
    ctx.wear("Glass", _glass_wear(ctx, g, level, lift))
    ctx.wear("Chrome", kitlib.mul(kitlib.ground_dirt(1.0 + lift, 0.3, noise), kitlib.cavity(0.3),
                                  kitlib.scuffs(noise, 0.25 * level, 5.0)))
    tyre = _tyre_wear(wheels, WHEEL_R + lift, noise)
    ctx.wear("Rubber", tyre)
    ctx.wear("RubberWorn", tyre)
    ctx.wear("Metal", _wheel_wear(wheels, WHEEL_R + lift, level, noise, rusty=(kind == "wrecked")))
    ctx.wear("Black", kitlib.mul(kitlib.cavity(0.3), kitlib.ground_dirt(1.0 + lift, 0.2, noise)))
    ctx.wear("Rust", _rust_wear(noise, rust_mask))
    ctx.budget = 8000


def _taxi_sign(add, g):
    """The roof sign: a two-faced plastic box on a black base, TAXI raised on both faces."""
    y0 = g.H(0.5) + g.crown + 0.03
    add("Black", box(1.6, 0.1, 0.62, bevel=0.03), T(0, y0 + 0.03, 0.5))
    prof = [(-0.36, 0.0), (0.36, 0.0), (0.3, 0.48), (-0.3, 0.48)]  # (z, y) trapezoid
    rings = [[(x, y0 + 0.06 + yy, 0.5 + zz) for zz, yy in prof] for x in (-0.88, 0.88)]
    add("Paper", loft(rings, cap_start=True, cap_end=True))
    # letters on the two sloped faces (front: -z, back: +z), each stroke a small proud box
    slope = math.degrees(math.atan2(0.06, 0.48))
    for face in (-1, 1):
        def stroke(x, y, w, h, rot=0.0):
            m = (T(x, y0 + 0.06 + y, 0.5 + face * (0.36 - 0.06 * y / 0.48 + 0.012)) @ R(-face * slope, 0, 0)
                 @ R(0, 0, rot * -f))
            add("Black", box(w, h, 0.03, bevel=0.0), m)

        xs = (-0.48, -0.16, 0.16, 0.44)
        f = face  # (letters read left to right from the side looked at)
        stroke(f * xs[0], 0.4, 0.22, 0.045)
        stroke(f * xs[0], 0.24, 0.045, 0.3)
        stroke(f * (xs[1] - 0.05), 0.24, 0.04, 0.32, 17)
        stroke(f * (xs[1] + 0.05), 0.24, 0.04, 0.32, -17)
        stroke(f * xs[1], 0.2, 0.1, 0.035)
        stroke(f * xs[2], 0.24, 0.04, 0.34, 32)
        stroke(f * xs[2], 0.24, 0.04, 0.34, -32)
        stroke(f * xs[3], 0.24, 0.045, 0.3)


def _checker(card):
    """The taxi's checker band along both sides: two rows of black squares, 0.02 proud."""
    q = 0.2
    n = 14  # squares along z over 5.6 studs
    for sx in (-1, 1):
        card("Black", (sx * 3.0, 2.27, -0.05), (0, 0, n * q / 2), (0, q, 0), (-sx, 0, 0), n, 2,
             lambda a, b: (int((a + 1) / 2 * n) + int((b + 1) / 2 * 2)) % 2 == 0, off0=-0.008, off1=0.02)


def _wreck_specials(ctx, add, g, rng, noise):
    """The Lot 9 wreck: hood buckled up off its latch (the proxy Hood is tilted 12 degrees, its
    front up), windscreen crazed from a head impact, the driver's rear window gone."""
    # hood: a crumpled panel over the hood area, its front edge up, a ridge across it
    rows = []
    for j in range(7):
        z = lerp(-4.55, -7.42, j / 6)
        t = j / 6
        # (folded up along a crease across its middle, the front edge highest, like the proxy)
        lift = 0.85 * math.sin(0.5 * math.pi * t / 0.55) if t <= 0.55 else 0.85 + 0.17 * (t - 0.55) / 0.45
        row = []
        for i in range(7):
            x = lerp(-2.62, 2.62, i / 6)
            w = sed_w(z)
            xn = abs(x) / w
            yn = 1.0 + 0.018 * (1 - xn)
            y = sed_bot(z) + yn * (sed_top(z) - sed_bot(z)) + lift * (0.82 + 0.18 * (x + 2.62) / 5.24)
            y += 0.08 * noise.fbm(Vector((x, 0, z)) * 1.1, 2) * t
            row.append(Vector((x, y, z)))
        rows.append(row)
    g0 = [[p + Vector((0, -0.02, 0)) for p in r] for r in rows]
    g1 = [[p + Vector((0, 0.05, 0)) for p in r] for r in rows]
    add("MetalPainted", _slab(g0, g1))
    add("Rust", box(0.08, 0.5, 0.08, bevel=0.0), T(0, 2.7, -7.2) @ R(20, 0, 0))  # (the bent latch)
    # crazed windscreen: radial cracks from a star, two broken rings
    c = g.point(-3.0, -0.28)
    n = g.normal(-3.0, -0.28)
    for k in range(6):
        a = 2 * math.pi * k / 6 + rng.uniform(-0.25, 0.25)
        pts = []
        for step in range(5):
            r = step * 0.28 + rng.uniform(0, 0.08)
            s = -0.28 + r * math.cos(a) * 0.17
            z = -3.0 + r * math.sin(a) * 0.9
            if not (g.z0 + 0.15 < z < g.wind_top - 0.1 and abs(s) < 0.58):
                break
            pts.append(g.point(z, s) + g.normal(z, s) * 0.01)
        if len(pts) >= 2:
            add("Reflective", tube(pts, 0.014, 3))
    for rr in ():
        pts = []
        for k in range(13):
            a = 2 * math.pi * k / 12
            s, z = -0.28 + rr * math.cos(a) * 0.17, -3.0 + rr * math.sin(a) * 0.9
            pts.append(g.point(z, s) + g.normal(z, s) * 0.012)
        add("Reflective", tube(pts, 0.012, 3))
    add("Reflective", kitlib.sphere(0.09, 8, 6), T(*(c + n * 0.0)))
    # the left rear door glass smashed out: a dark opening with a few teeth left
    add("Black", g.slab(-0.92, -0.66, 0.05, 1.7, 3, 4, off=-0.008, th=0.025))
    for k in range(2):
        z = lerp(0.3, 1.5, k)
        p = g.point(z, -0.9)
        add("Glass", box(0.03, 0.18 + 0.1 * (k % 2), 0.2, bevel=0.0), T(p.x - 0.03, p.y + 0.08, z) @ R(0, 0, 6))


def _jacks_specials(ctx, add, g, lift):
    """Ferro's job: up on four stands, the wheels off, the hood propped open on an engine bay
    with a V8, radiator, battery, hoses; a drain pan under it."""
    # stands (on the ground, not lifted)
    for sx in (-1, 1):
        for zz in (-WHEEL_Z + 0.3, WHEEL_Z - 0.3):
            x = sx * 2.4
            legs = []
            for a in range(4):
                ang = math.radians(45 + 90 * a)
                legs.append(tube([(x + 0.42 * math.cos(ang), 0.03, zz + 0.42 * math.sin(ang)),
                                  (x + 0.1 * math.cos(ang), 0.65, zz + 0.1 * math.sin(ang))], 0.045, 4))
            for bm in legs:
                ctx.add("Metal", bm)
            ctx.add("Metal", box(0.26, 0.18, 0.26, bevel=0.03), T(x, 0.68, zz))
            ctx.add("Metal", box(0.12, 0.42, 0.12, bevel=0.02), T(x, 0.92, zz))
            ctx.add("Metal", box(0.3, 0.06, 0.16, bevel=0.02), T(x, 1.14, zz))
            for k in (-1, 1):
                ctx.add("Metal", box(0.05, 0.1, 0.16, bevel=0.01), T(x + k * 0.12, 1.2, zz))
            ctx.add("Rust", tube([(x + 0.12, 0.8, zz), (x + 0.3, 0.86, zz)], 0.025, 5))  # (the ratchet pin)
    # engine bay: radiator, V8 (block, two valve covers, air cleaner), battery, hoses
    E = T(0, lift, 0)
    add("Black", box(4.6, 0.75, 0.22, bevel=0.03), T(0, 2.45, -6.95))
    add("Black", box(1.6, 0.6, 1.6, bevel=0.1), T(0, 2.25, -5.65))
    for sx in (-1, 1):
        add("Metal", box(0.42, 0.22, 1.5, bevel=0.06), T(sx * 0.62, 2.62, -5.65) @ R(0, 0, sx * 30))
    add("Black", lathe([(0.0, 0.0), (0.55, 0.0), (0.58, 0.04), (0.58, 0.2), (0.55, 0.24), (0.0, 0.25)], 20),
        T(0, 2.66, -5.75))
    add("Metal", cyl(0.06, 0.08, 8), T(0, 2.94, -5.75))
    add("Black", box(0.7, 0.55, 0.5, bevel=0.04), T(-1.95, 2.35, -6.3))
    add("Rust", cyl(0.05, 0.08, 6), T(-2.1, 2.66, -6.3))
    add("Rust", cyl(0.05, 0.08, 6), T(-1.8, 2.66, -6.3))
    add("Black", tube([(1.1, 2.45, -6.8), (1.0, 2.6, -6.4), (0.7, 2.55, -6.1)], 0.07, 8))
    add("Black", tube([(-1.0, 2.3, -6.8), (-0.6, 2.2, -6.3), (-0.5, 2.3, -6.0)], 0.07, 8))
    add("Metal", cyl(0.18, 0.3, 12), T(1.95, 2.42, -5.1))  # (brake booster / master cylinder)
    # the hood, hinged at the cowl and propped up (~62 degrees)
    rows = []
    for j in range(6):
        z = lerp(-4.62, -7.42, j / 5)
        row = []
        for i in range(7):
            x = lerp(-2.6, 2.6, i / 6)
            w = sed_w(z)
            yn = 1.0 + 0.018 * (1 - abs(x) / w)
            row.append(Vector((x, sed_bot(z) + yn * (sed_top(z) - sed_bot(z)), z)))
        rows.append(row)
    hinge = Vector((0, BELT + 0.02, -4.6))
    m = T(*hinge) @ R(62, 0, 0) @ T(*(-hinge))
    g0 = [[m @ (p + Vector((0, -0.03, 0))) for p in r] for r in rows]
    g1 = [[m @ (p + Vector((0, 0.03, 0))) for p in r] for r in rows]
    add("MetalPainted", _slab(g0, g1))
    tip = m @ Vector((2.1, sed_top(-6.9) - 0.03, -6.9))
    add("Metal", tube([(2.25, 2.62, -6.95), tuple(tip)], 0.025, 5))
    del E
    # drain pan on the floor under the engine
    ctx.add("Metal", lathe([(0.0, 0.02), (0.7, 0.02), (0.78, 0.2), (0.74, 0.21), (0.66, 0.06), (0.0, 0.06)], 20),
            T(0.2, 0, -5.4))
    ctx.add("Black", cyl(0.64, 0.03, 18), T(0.2, 0.08, -5.4))


def sedan_clean(ctx):
    """A 90s full-size US sedan (Crown Victoria / Caprice) at the city's car size: three-box
    body with a shoulder line, formal C-pillar, chrome bumpers and grille, full wheel covers,
    light road dirt. Tint: the body paint."""
    sedan(ctx, "clean")
    ctx.tint("MetalPainted", (35, 41, 56))


def sedan_worn(ctx):
    """The same sedan run into the ground: grey plastic bumpers, bare steel wheels (one odd),
    a primer-grey fender from the scrapyard, rust scabs on the sills and arches, a dent in a
    door, the aerial snapped, thick road grime."""
    sedan(ctx, "worn")
    ctx.tint("MetalPainted", (87, 88, 90))


def sedan_taxi(ctx):
    """The crossroads taxi: the sedan with a TAXI roof sign, a checker band, dog-dish hubcaps;
    its hazard lamps (Glow, front corners and rear) take the old Hazard neon (Light marker)."""
    sedan(ctx, "taxi")
    ctx.tint("MetalPainted", (164, 133, 49))


def sedan_wrecked(ctx):
    """Lot 9's wreck: hood buckled up, windscreen crazed, a rear window smashed out, the front
    bumper hanging, headlamps gone, a flat tyre, the rear-right wheel off (axle on a breeze
    block), rust everywhere."""
    sedan(ctx, "wrecked")
    ctx.tint("MetalPainted", (98, 108, 96))  # (faded sage paint: the rust reads on it)


def sedan_on_jacks(ctx):
    """Ferro's job: the sedan up 1.05 on four jack stands, wheels off (brake discs, calipers),
    hood propped open over a V8 bay, a drain pan underneath."""
    sedan(ctx, "jacks")
    ctx.tint("MetalPainted", (33, 39, 53))


# ==============================================================================================
# BOX VAN (the Yard's Halvorsen Freight van)
# ==============================================================================================
# The city's van: a box body 7.4 x 7.6 x 11.5 (VanBody, down to 0.8 over the ground) behind a cab
# 7.4 x 3.8 x 5.5 (VanCab) with a raked windscreen and a roof at 8.3, 2.6-stud wheels at 11.5
# apart, the HALVORSEN FREIGHT livery (a SurfaceGui) on the box's left side. Real reference: a
# 3.5 t European box van (Ford Transit Mk3 / Iveco Daily "Luton" without the peak) or a US
# cutaway (E-350 + Supreme box): 5.9 x 2.1 x 2.5 m = 21 x 7.5 x 8.9 studs, so the city's van is
# again ~0.85 of life. What makes it read:
#   * the BOX: GRP / aluminium sheet on a frame: extruded aluminium corner posts, top rails and
#     a deep bottom rail (the rub rail), panel joints with vertical cover strips, the floor on
#     cross-members over two chassis rails; rear barn doors with four lock rods (cam keepers top
#     and bottom, handles), hinges on the outer posts, a rubber seal down the middle; marker
#     lamps on the corners (amber front, red rear), tail lamps low on the rear, a steel step
#     bumper and an under-run bar; dual rear wheels with black mudguards and flaps; side guard
#     rails between the axles; a fuel tank;
#   * the CAB: short sloping nose, black grille between rectangular headlamps, indicators,
#     black wraparound bumper, a big raked windscreen, door windows, truck mirrors on arms, a
#     step behind the front wheel;
#   * wear: road dirt up the lower third, black streaks running down the box from the top rails
#     and posts, grime round the wheels; the worn one: dented box panel (the side WITHOUT the
#     livery), a primer door, rust round the arches and sills, a smashed tail lamp, a flap gone,
#     the step bumper rusted.
# Piece space: the cab is at -Z (the front), the origin under the box's middle on the ground
# (the old VanBody's x / z), so the marker sits where VanBody was (turned 180 degrees: the data
# van faces +Z).
# ----------------------------------------------------------------------------------------------
VB_W = 3.66  # box half width (the old box 3.7: the livery stands 0.04 off it)
VB_Y0, VB_Y1 = 2.95, 8.36  # box floor / roof
VB_Z0, VB_Z1 = -5.66, 5.66
VC_Z0 = -11.25  # cab front
VAN_WR = 1.3
VAN_FZ, VAN_RZ = -8.25, 3.25

CPROF = [(0.0, 0.0), (0.85, 0.0), (0.98, 0.05), (1.0, 0.16), (1.006, 0.5), (1.0, 0.86), (0.975, 0.95),
         (0.9, 0.99), (0.0, 1.012)]


def _cab_rings():
    zs = [VC_Z0, VC_Z0 + 0.04, VC_Z0 + 0.16, VC_Z0 + 0.36, VC_Z0 + 0.6, -10.1, -9.8, -9.0, -7.4, -6.3, -5.6]
    rings = []
    for z in zs:
        a = z - VC_Z0
        w = 3.55 - 0.6 + math.sqrt(max(0.0, 0.36 - max(0.0, 0.6 - a) ** 2)) if a < 0.6 else 3.55
        top = 4.65 - 0.35 * smoothstep(0.0, 1.45, 1.45 - a) if a < 1.45 else 4.65
        bot = 1.0 + 0.2 * smoothstep(0.6, 0.0, a)
        if a < 0.01:
            w, top, bot = w - 0.03, top - 0.06, bot + 0.06
        ring = [(xn * w, bot + yn * (top - bot), z) for xn, yn in CPROF]
        rings.append(ring + [(-x, y, z) for (x, y, z) in reversed(ring[1:-1])])
    return rings


def _box_rings(dents=None):
    """The box shell: a section ring (floor, side, top, rounded top edges) swept along z, with
    enough rings for the panels' oil-canning and the dents."""
    side = [VB_Y0, 3.6, 4.6, 5.6, 6.6, 7.6, VB_Y1 - 0.12]
    zs = [VB_Z0 + k * (VB_Z1 - VB_Z0) / 10 for k in range(11)]
    rings = []
    for z in zs:
        right = [(0.0, VB_Y0), (VB_W, VB_Y0)] + [(VB_W, y) for y in side[1:]]
        right += [(VB_W - 0.04, VB_Y1 - 0.03), (VB_W - 0.12, VB_Y1), (0.0, VB_Y1 + 0.02)]
        ring = []
        for x, y in right:
            p = Vector((x, y, z))
            if dents and abs(x) > VB_W - 0.01 and VB_Y0 + 0.3 < y < VB_Y1 - 0.3:
                p.x -= dents(p) * (1 if x > 0 else -1)
            ring.append(tuple(p))
        rings.append(ring + [(-x, y, zz) for (x, y, zz) in reversed(ring[1:-1])])
    return rings


def box_van(ctx, worn=False):
    noise = ctx.noise
    add = ctx.add
    level = 0.85 if worn else 0.45

    # ---- the box: shell (its left / -X side dented on the worn van; +X carries the livery)
    def dents(p):
        d = 0.0
        if worn and p.x < 0:
            for c, r, k in ((Vector((-VB_W, 4.1, 2.3)), 0.9, 0.12), (Vector((-VB_W, 6.8, -3.9)), 0.7, 0.07)):
                d += k * math.exp(-((p - c).length / r) ** 2)
        return d + 0.012 * math.sin((p.z - VB_Z0) / (VB_Z1 - VB_Z0) * math.pi * 4) * smoothstep(VB_Y0, 5.0, p.y)

    shell = loft(_box_rings(dents), cap_start=True, cap_end=True)
    add("MetalPainted", shell)
    # corner posts, top rails, the rub rail (aluminium extrusions)
    for sx in (-1, 1):
        for zz in (VB_Z0, VB_Z1):
            add("Metal", box(0.24, VB_Y1 - VB_Y0 + 0.06, 0.24, bevel=0.04), T(sx * (VB_W - 0.02), (VB_Y0 + VB_Y1) / 2, zz))
        add("Metal", box(0.2, 0.22, VB_Z1 - VB_Z0, bevel=0.04), T(sx * (VB_W - 0.03), VB_Y1 - 0.08, 0))
        add("Metal", box(0.2, 0.46, VB_Z1 - VB_Z0, bevel=0.04), T(sx * (VB_W + 0.02), VB_Y0 + 0.2, 0))
        for zz in (-3.25, 3.25):  # (panel joints: cover strips)
            add("Metal", box(0.07, VB_Y1 - VB_Y0 - 0.5, 0.16), T(sx * (VB_W + 0.01), (VB_Y0 + VB_Y1) / 2 + 0.05, zz))
    for zz in (VB_Z0, VB_Z1):
        add("Metal", box(2 * VB_W, 0.22, 0.2, bevel=0.04), T(0, VB_Y1 - 0.08, zz))
    add("Metal", box(2 * VB_W, 0.42, 0.2, bevel=0.04), T(0, VB_Y0 + 0.2, VB_Z1 + 0.02))
    # rear barn doors: two panels, the seal, four lock rods with cam keepers, handles, hinges
    rz = VB_Z1 + 0.04
    for sx in (-1, 1):
        add("MetalPainted", box(VB_W - 0.2, VB_Y1 - VB_Y0 - 0.62, 0.06, bevel=0.02),
            T(sx * (VB_W / 2 - 0.0), (VB_Y0 + VB_Y1) / 2 + 0.06, rz))
        for rx in (sx * 0.5, sx * 2.9):
            add("Metal", cyl(0.045, VB_Y1 - VB_Y0 - 0.5, 5), T(rx, (VB_Y0 + VB_Y1) / 2 + 0.06, rz + 0.1))
            for yy in (VB_Y0 + 0.45, VB_Y1 - 0.3):
                add("Metal", box(0.22, 0.16, 0.14), T(rx, yy, rz + 0.08))
            add("Metal", box(0.12, 0.62, 0.1), T(rx + sx * 0.12, 4.4, rz + 0.17) @ R(0, 0, sx * 4))
        for yy in (3.9, 7.5):
            add("Metal", box(0.34, 0.26, 0.1), T(sx * (VB_W - 0.12), yy, rz + 0.06))
    add("Black", box(0.06, VB_Y1 - VB_Y0 - 0.6, 0.06), T(0, (VB_Y0 + VB_Y1) / 2 + 0.06, rz + 0.04))
    # lamps: rear tail lamps low on the doors, marker / ID lamps along the top
    for sx in (-1, 1):
        smashed = worn and sx < 0
        add("Black" if smashed else LENS_RED, box(0.46, 1.3, 0.08), T(sx * 3.2, 3.95, rz + 0.06))
        add("PlasticDark", box(0.56, 1.42, 0.05), T(sx * 3.2, 3.95, rz + 0.02))
        add(LENS_RED, box(0.18, 0.12, 0.08), T(sx * (VB_W - 0.1), VB_Y1 - 0.1, VB_Z1 + 0.14))
        add(LENS_AMBER, box(0.18, 0.12, 0.08), T(sx * (VB_W - 0.1), VB_Y1 - 0.1, VB_Z0 - 0.14))
        add(LENS_AMBER, box(0.06, 0.12, 0.2), T(sx * (VB_W + 0.13), VB_Y0 + 0.2, 0.0))
    for k in (-1, 0, 1):
        add(LENS_RED, box(0.14, 0.1, 0.06), T(k * 0.35, VB_Y1 - 0.08, VB_Z1 + 0.13))
    # under the box: cross-members, chassis rails, fuel tank, side guards, rear step, under-run
    for k in range(6):
        z = VB_Z0 + 0.5 + k * (VB_Z1 - VB_Z0 - 1.0) / 5
        add("Black", box(2 * VB_W - 0.3, 0.2, 0.16), T(0, VB_Y0 - 0.1, z))
    for sx in (-1, 1):
        add("Black", box(0.3, 0.6, 16.4, bevel=0.03), T(sx * 1.45, 2.3, -2.6))
    add("Metal", tube([(-2.35, 1.95, -4.9), (-2.35, 1.95, -1.6)], 0.5, 12))
    for z in (-4.5, -2.0):
        add("Black", box(0.9, 0.1, 0.12), T(-2.3, 2.47, z))
    for sx in (-1, 1):
        for yy in (1.35, 2.05):
            add("Metal", tube([(sx * 3.5, yy, -6.35), (sx * 3.5, yy, 1.55)], 0.07, 6))
        for z in (-5.9, -2.4, 1.2):
            add("Metal", box(0.6, 0.9, 0.1), T(sx * 3.2, 1.75, z))
    # the rear step / under-run bar: a C-channel of black-painted steel (open side in), the worn
    # van's with rust only where water sits: along the bottom flange's edge and drips down the web
    zb = VB_Z1 + 0.32
    add("Black", box(6.8, 0.42, 0.05, bevel=0.0), T(0, 1.45, zb + 0.285))  # web (facing back)
    for yy in (1.645, 1.255):
        add("Black", box(6.8, 0.05, 0.62, bevel=0.0), T(0, yy, zb))  # top / bottom flanges
    if worn:
        for x0, x1 in ((-3.3, -1.6), (-0.4, 0.5), (1.9, 3.3)):
            add("Rust", box(x1 - x0, 0.035, 0.08, bevel=0.0), T((x0 + x1) / 2, 1.255, zb + 0.29))
        for x, ln in ((-2.6, 0.22), (-1.9, 0.14), (0.1, 0.18), (2.4, 0.26), (2.9, 0.12)):
            add("Rust", box(0.05, ln, 0.012, bevel=0.0), T(x, 1.28 + ln / 2, zb + 0.312))
    for sx in (-1, 1):
        add("Metal", box(0.16, 1.4, 0.16), T(sx * 1.6, 2.1, VB_Z1 + 0.1))
    add("Paper", box(1.6, 0.48, 0.05), T(0, 2.25, VB_Z1 + 0.27))
    for k in range(3):
        add("Black", box(0.32, 0.22, 0.03), T(-0.45 + k * 0.45, 2.24, VB_Z1 + 0.3))
    # rear mudguards over the duals and the flaps
    for sx in (-1, 1):
        arc = [math.radians(a) for a in range(0, 181, 20)]
        poly = [(1.3 + 1.5 * math.sin(a), VAN_RZ + 1.5 * math.cos(a)) for a in arc]
        poly += [(1.3 + 1.42 * math.sin(a), VAN_RZ + 1.42 * math.cos(a)) for a in reversed(arc)]
        rings = [[(sx * x, y, z) for y, z in poly] for x in (1.6, 3.42)]
        add("Black", loft(rings, cap_start=True, cap_end=True))
        if not (worn and sx > 0):
            add("Black", box(1.5, 1.3, 0.05), T(sx * 2.6, 0.95, VAN_RZ + 1.55))

    # ---- the cab: lower body (arches cut), greenhouse
    cab = loft(_cab_rings(), cap_start=True, cap_end=True)
    cab = _boolean(cab, _wheel_cutters(zs=(VAN_FZ,), r=1.62, cx=3.2, length=1.6, cy=VAN_WR))
    bvh = _bvh(cab)
    add("MetalPainted", cab)
    for sx in (-1, 1):
        _arch_liner(ctx, VAN_FZ, sx, r=1.62, cy=VAN_WR, floor=1.0, x_in=2.41, x_lip=3.6)

    def card(layer, c, ua, va, d, na, nb, keep=None, off0=-0.008, off1=0.02, jitter=0.0):
        bm = _card(bvh, c, ua, va, d, na, nb, keep, off0, off1, jitter, noise)
        if bm.verts:
            add(layer, bm)
        else:
            bm.free()

    for sx in (-1, 1):
        card("Black", (sx * 3.5, 3.6, -9.75), (0, 0, 0.012), (0, 1.0, 0), (-sx, 0, 0), 1, 3)  # door front
        card("Black", (sx * 3.5, 2.85, -6.05), (0, 0, 0.012), (0, 1.75, 0), (-sx, 0, 0), 1, 4)  # door rear
        card("Black", (sx * 3.5, 1.55, -6.6), (0, 0, 0.55), (0, 0.012, 0), (-sx, 0, 0), 2, 1)  # door bottom
        add("PlasticDark", box(0.08, 0.12, 0.55), T(sx * 3.56, 4.05, -6.7))  # handle
        add("Black", box(0.5, 0.08, 0.6), T(sx * 3.3, 0.95, -6.15))  # step
        add(LENS_AMBER, box(0.06, 0.14, 0.32), T(sx * 3.57, 3.4, -10.5))  # side repeater
    if worn:  # primer door (left), rust round the arch and the sill
        card("Concrete", (-3.5, 3.1, -7.9), (0, 0, 1.8), (0, 1.5, 0), (1, 0, 0), 5, 4, off0=-0.006, off1=0.016)
        for sx, z, y, hz, hy in ((1, -8.25, 2.75, 0.9, 0.3), (-1, -10.4, 1.5, 0.45, 0.32)):
            bm = _blob(bvh, (sx * 3.4, y, z), (0, 0, hz), (0, hy, 0), (-sx, 0, 0), noise, (sx, y * 3, z))
            add("Rust", bm) if bm.verts else bm.free()

    g = Greenhouse(z0=-9.8, z1=-5.62, wb=3.56, tumble=0.1, base=4.55, top=7.98, crown=0.12, rc=0.3,
                   wind_top=-7.75, rear_top=-5.72)
    gst = [-9.8, -9.66, -9.2, -8.6, -8.0, -7.6, -7.1, -6.45, -6.2, -5.85, -5.72, -5.62]
    add("Glass", g.solid(gst))
    add("MetalPainted", g.slab(-0.5, 0.5, g.wind_top + 0.05, g.z1, 6, 4, th=0.06))  # roof
    add("MetalPainted", box(6.9, 0.26, 0.62, bevel=0.08, segments=1), T(0, g.top + 0.08, g.wind_top - 0.12))  # peak over the screen
    for sx in (-1, 1):
        s0, s1 = (0.5, 0.64) if sx > 0 else (-0.64, -0.5)
        add("MetalPainted", g.slab(s0, s1, g.z0 + 0.02, g.z1, 2, 7, th=0.05))  # A pillar + rail
        s0, s1 = (0.64, 1.0) if sx > 0 else (-1.0, -0.64)
        add("MetalPainted", g.slab(s0, s1, -6.35, g.z1, 4, 2, th=0.05))  # rear pillar
        s0, s1 = (0.94, 0.99) if sx > 0 else (-0.99, -0.94)
        add("Black", g.slab(s0, s1, g.z0 + 0.3, -6.35, 1, 4, off=-0.01, th=0.04))  # window seal
    add("Black", g.slab(-0.5, 0.5, g.z0 + 0.02, g.z0 + 0.16, 6, 1, off=-0.01, th=0.03))
    for x0, x1 in ((-2.6, -0.2), (0.3, 2.7)):  # wipers (parked across the bottom of the glass)
        z = g.z0 + 0.22
        y = g.H(z) + 0.04
        ang = math.degrees(math.atan(g.ws))
        add("Black", box(x1 - x0, 0.04, 0.07), T((x0 + x1) / 2, y, z) @ R(-ang, 0, 0))
    # truck mirrors on tube arms
    for sx in (-1, 1):
        base = g.point(-9.3, sx * 0.97)
        add("Black", tube([(base.x, 5.0, -9.3), (sx * 3.95, 5.15, -9.0), (sx * 3.95, 5.15, -8.7)], 0.04, 5))
        add("Black", tube([(base.x, 6.3, -9.0), (sx * 3.95, 6.1, -8.75)], 0.04, 5))
        add("PlasticDark", box(0.26, 1.0, 0.42, bevel=0.06), T(sx * 4.0, 5.65, -8.6))
        add("Glass", box(0.2, 0.9, 0.04), T(sx * 4.0, 5.65, -8.38))

    # ---- the nose: grille, headlamps, indicators, bumper, plate, badge
    fz = VC_Z0
    add("Black", box(3.3, 1.45, 0.12, bevel=0.03), T(0, 2.95, fz - 0.02))
    for k in range(5):
        add("PlasticDark", box(3.3, 0.07, 0.06), T(0, 2.4 + k * 0.28, fz - 0.08))
    for p in _frame(0, 2.95, fz - 0.06, 3.5, 1.62, 0.1, 0.14):
        add("PlasticDark", *p)
    add("Chrome", box(0.6, 0.24, 0.05), T(0, 2.98, fz - 0.12))
    for sx in (-1, 1):
        add("Reflective", box(1.0, 0.72, 0.12, bevel=0.03), T(sx * 2.3, 3.05, fz - 0.03))
        for p in _frame(sx * 2.3, 3.05, fz - 0.06, 1.14, 0.86, 0.08, 0.12):
            add("PlasticDark", *p)
        add(LENS_AMBER, box(0.6, 0.3, 0.1), T(sx * 2.3, 2.38, fz - 0.03))
    bprof = [(-0.16, 0.92), (0.12, 0.9), (0.24, 1.05), (0.26, 1.3), (0.24, 1.6), (0.12, 1.72), (-0.16, 1.7)]
    path = [(-3.55, -10.1)]
    for side in (-1, 1):
        ts = range(90, -1, -30) if side < 0 else range(0, 91, 30)
        path += [(side * (2.95 + 0.6 * math.sin(math.radians(t))), -(10.65 + 0.6 * math.cos(math.radians(t)))) for t in ts]
    path.append((3.55, -10.1))
    add("PlasticDark", _sweep(path, bprof))
    add("Paper", box(1.6, 0.48, 0.05), T(0, 1.3, fz - 0.3))
    for k in range(3):
        add("Black", box(0.32, 0.22, 0.03), T(-0.45 + k * 0.45, 1.29, fz - 0.33))

    # ---- wheels: front singles, rear duals (steel, the outer dish deep), dirty
    for sx in (-1, 1):
        k = VAN_WR / WHEEL_R
        _add_wheel(add, sx * 2.95, VAN_FZ, "steel", sx, cy=VAN_WR, k=k, segs=13, nuts=0)
        _add_wheel(add, sx * 2.92, VAN_RZ, "steel", sx, cy=VAN_WR, k=k, segs=13, nuts=0)
        add("Rubber", _tyre(r=VAN_WR, hw=0.38, bead=0.88, segs=13), T(sx * 2.03, VAN_WR, VAN_RZ))

    # ---- wear
    def box_wear(p):
        y = p.co.y
        dirt = 1 - (0.2 + 0.25 * level) * (1 - smoothstep(0.0, 3.4 + 0.6 * noise.fbm(p.co, 2, 0.8), y))
        q = (p.co.x * 2.2 + p.co.z * 2.2, y * 0.18, p.co.z * 0.3)
        streak = 1 - (0.1 + 0.18 * level) * smoothstep(0.25, 0.8, noise.fbm(q, 2)) * smoothstep(VB_Y0, VB_Y1 - 1.0, y)
        cav = 1 - 0.3 * smoothstep(0.0, 0.45, -p.convex)
        arch = 1.0
        for wz in (VAN_FZ, VAN_RZ):
            d = math.hypot(p.co.z - wz, y - VAN_WR)
            arch = min(arch, 1 - 0.25 * (1 - smoothstep(1.6, 2.4, d)))
        return dirt * streak * cav * arch

    ctx.wear("MetalPainted", box_wear)
    ctx.wear("Metal", kitlib.mul(kitlib.ground_dirt(3.0, 0.3, noise), kitlib.cavity(0.35),
                                 kitlib.streaks(noise, 0.2 * level, 4.0), lambda p: (0.8, 0.77, 0.72)))
    ctx.wear("Glass", _glass_wear(ctx, g, level))
    ctx.wear("Rubber", kitlib.mul(kitlib.ground_dirt(1.2, 0.3, noise), kitlib.cavity(0.2)))
    ctx.wear("Black", kitlib.mul(kitlib.cavity(0.3), kitlib.ground_dirt(1.5, 0.25, noise)))
    ctx.budget = 8000


def box_van_clean(ctx):
    """A box van (3.5 t Transit / E-350 class) at the city's van size: aluminium-framed box with
    corner posts, rub rail, barn doors with lock rods, marker lamps, step bumper, dual rear
    wheels, guard rails; short-nosed cab with raked screen, black grille, truck mirrors."""
    box_van(ctx, worn=False)
    ctx.tint("MetalPainted", (83, 92, 111))


def box_van_worn(ctx):
    """The same van after years of yard work: a dented box panel (the side without the
    livery), a primer cab door, rust round the arches, a smashed tail lamp, a mud flap gone,
    the step bumper rusted, black streaks down the box."""
    box_van(ctx, worn=True)
    ctx.tint("MetalPainted", (83, 92, 111))


PIECES = {
    "Sedan": sedan_clean,
    "SedanWorn": sedan_worn,
    "SedanTaxi": sedan_taxi,
    "SedanWrecked": sedan_wrecked,
    "SedanOnJacks": sedan_on_jacks,
    "BoxVan": box_van_clean,
    "BoxVanWorn": box_van_worn,
}
