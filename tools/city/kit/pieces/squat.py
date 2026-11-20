"""The squat's furniture in the city prop kit: old mattresses, a worn armchair, a small ridge tent,
a tarp lean-to and a one-ring camping stove with its saucepan.

Why these are meshes: the old props were stacks of primitives that read as toys (a mattress =
three boxes with round "stain" disks lying flat on its top, flickering; an armchair = a box with
cylinders for arms, a "Lego sofa"; a tent = four flat panels with hard creases; the stove = a
pile of cylinders, its pan a solid drum). Soft things live by their silhouette: rounded, piped
edges, sag, puffiness between tufts, folds where a sheet is pulled. Here:
  * upholstery (mattress, armchair) is built from ROUNDED-BOX LATTICES (_RBox: a quad grid on the
    six faces of a box, every point pushed onto a box with rounded edges), then sculpted point by
    point (sag, quilting tufts, side borders puffing out, noise wobble), with piping tubes run
    along the box's edge loops, a real tear (the cover cut open, foam bulging out, a frayed lip
    and a peeled flap);
  * sheets (tent, tarp) are grids laid out by a function (ridge to eave, wall to pole), sagging
    between their supports, with tension creases running from the poles and pegs; every sheet
    is a closed slab 0.03 studs thick (no zero-thickness face, so it never needs DoubleSided);
  * hard goods (stove, saucepan) are lathes with the real profile: rolled rims, crimped seams,
    a dented pan, riveted handle, lid ajar on the rim.

Each build function gets a kitlib.Piece (`ctx`) and models its piece in Roblox axes (Y up, the
front faces -Z, studs; 1 stud ~ 0.29 m, props ~15 % large like the rest of the city), the origin
at the centre of the footprint on the floor. Every piece's lowest point sits 0.012 studs above
the floor (never in its plane). Layers never share a surface: details laid on a body stand
proud of it or cross it at an angle. Only ONE tintable layer per piece (the marker's Tint goes to
every tintable layer): ropes use FabricDark, the armchair's blanket its own Wool layer. No bottles anywhere: the stove's gas
cartridge is the squat screw-top kind, wider than tall.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

from kitlib import T, R, Noise, TO_BLENDER, to_blender, merge, bevel_edges, box, cyl, lathe, loft, tube, lerp, smoothstep, mul, ground_dirt, cavity, edge_wear  # noqa: F401

FLOOR = 0.012  # every piece's lowest point: just above the floor, never in its plane


# ----------------------------------------------------------------------------------------------
# Shared helpers
# ----------------------------------------------------------------------------------------------
def _axis(lo, hi, r, step, band):
    """The lattice coordinates along one axis of a rounded box from lo to hi: `band` points in
    each rounded edge (spaced so they land evenly on the edge's quarter circle, see _RBox) and
    the flat middle cut every `step` or so."""
    r = max(0.0, min(r, (hi - lo) / 2 - 1e-3))
    a, b = lo + r, hi - r
    n = max(1, math.ceil((b - a) / step - 1e-6))
    flat = [a + (b - a) * k / n for k in range(n + 1)]
    if r <= 0 or band <= 0:
        return flat
    lo_b = [lo + r - r * math.tan(math.radians(45 * k / band)) for k in range(band, 0, -1)]
    hi_b = [hi - r + r * math.tan(math.radians(45 * k / band)) for k in range(1, band + 1)]
    return lo_b + flat + hi_b


class _RBox:
    """A box from `lo` to `hi` with every edge rounded by `r`, as a closed quad lattice whose
    faces are cut every `step` (one number or per axis). Each lattice point on the box's surface
    is pushed onto the rounded box (clamped to the inner box, then out by r along the
    difference), so the edges come out as true quarter rounds and the corners as sphere
    octants. build(deform, keep) makes the bmesh: deform(p, n) -> new point moves every vertex
    (p on the rounded box, n its normal there), keep(centre) -> False cuts a face away (a tear).
    The faces are wound outward from the start (an open, torn skin keeps the right side)."""

    def __init__(self, lo, hi, r, step, band=3):
        self.lo, self.hi, self.r = Vector(lo), Vector(hi), r
        self.c = (self.lo + self.hi) / 2
        self.h = (self.hi - self.lo) / 2
        st = step if isinstance(step, (tuple, list)) else (step, step, step)
        self.band = band
        self.ax = [_axis(self.lo[i], self.hi[i], r, st[i], band) for i in range(3)]

    def flat(self, i):
        """The lattice coordinates of axis i on the flat part of the faces."""
        a = self.ax[i]
        return a[self.band:len(a) - self.band] if self.r > 0 else a

    def rounded(self, p):
        q = Vector(p) - self.c
        inner = [max(self.h[i] - self.r, 0.0) for i in range(3)]
        cl = Vector([max(-inner[i], min(inner[i], q[i])) for i in range(3)])
        d = q - cl
        if d.length < 1e-9:
            return Vector(p), Vector((0, 1, 0))
        n = d.normalized()
        return self.c + cl + n * self.r, n

    def build(self, deform=None, keep=None, snap=None):
        xs, ys, zs = self.ax
        nx, ny, nz = len(xs) - 1, len(ys) - 1, len(zs) - 1
        bm = bmesh.new()
        vid, info = {}, {}

        def V(i, j, k):
            key = (i, j, k)
            v = vid.get(key)
            if v is None:
                p, n = self.rounded((xs[i], ys[j], zs[k]))
                v = bm.verts.new(p)
                vid[key] = v
                info[v] = (p, n)
            return v

        quads = []
        for i in (0, nx):
            quads += [(V(i, j, k), V(i, j + 1, k), V(i, j + 1, k + 1), V(i, j, k + 1)) for j in range(ny) for k in range(nz)]
        for j in (0, ny):
            quads += [(V(i, j, k), V(i + 1, j, k), V(i + 1, j, k + 1), V(i, j, k + 1)) for i in range(nx) for k in range(nz)]
        for k in (0, nz):
            quads += [(V(i, j, k), V(i + 1, j, k), V(i + 1, j + 1, k), V(i, j + 1, k)) for i in range(nx) for j in range(ny)]
        for q in quads:
            cen = sum((v.co for v in q), Vector()) / 4
            if keep is not None and not keep(cen):
                continue
            nrm = (q[1].co - q[0].co).cross(q[2].co - q[0].co)
            if nrm.length < 1e-12:
                nrm = (q[2].co - q[0].co).cross(q[3].co - q[0].co)
            bm.faces.new(q if nrm.dot(cen - self.c) >= 0 else tuple(reversed(q)))
        if snap is not None:  # (the edge of a cut moved onto its true, ragged outline)
            for v in bm.verts:
                if any(len(e.link_faces) == 1 for e in v.link_edges):
                    p, n = info[v]
                    info[v] = (snap(p), n)
                    v.co = info[v][0]
        if deform is not None:
            for v in bm.verts:
                p, n = info[v]
                v.co = deform(p.copy(), n.copy())
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
        return bm

    def edge_loop(self, axis, side, thin=2):
        """The points of the box's edge loop round its face across `axis` (0 = x, 1 = y,
        2 = z) on `side` (-1 = lo, +1 = hi), going round the face; every `thin`-th flat point
        kept (the rounded corners keep all theirs). Returns [(rounded point, normal)]: the cube's
        edge maps to the middle of the rounded edge, where a piping (welt) runs."""
        ia, ib = [i for i in range(3) if i != axis]
        fixed = self.hi[axis] if side > 0 else self.lo[axis]

        def thin_out(a):
            b = self.band if self.r > 0 else 0
            mid = a[b:len(a) - b]
            keep = mid[::thin]
            if keep[-1] != mid[-1]:
                keep.append(mid[-1])
            return a[:b] + keep + a[len(a) - b:]

        A, Bc = thin_out(self.ax[ia]), thin_out(self.ax[ib])
        ring = []
        ring += [(self.hi[ia], b) for b in Bc[:-1]]
        ring += [(a, self.hi[ib]) for a in reversed(A[1:])]
        ring += [(self.lo[ia], b) for b in reversed(Bc[1:])]
        ring += [(a, self.lo[ib]) for a in A[:-1]]
        out = []
        for a, b in ring:
            p = [0.0, 0.0, 0.0]
            p[axis], p[ia], p[ib] = fixed, a, b
            out.append(self.rounded(p))
        return out

    def project(self, p):
        """The point of the rounded box's surface nearest to p (p near the surface)."""
        q = Vector(p) - self.c
        inner = [max(self.h[i] - self.r, 0.0) for i in range(3)]
        cl = Vector([max(-inner[i], min(inner[i], q[i])) for i in range(3)])
        d = q - cl
        if d.length < 1e-9:
            return Vector(p)
        return self.c + cl + d.normalized() * self.r


class _Tear:
    """A rip in an upholstered cover (_RBox): a ragged hole round `centre` (a point on the
    rounded box), radius ~`rad`. Use keep / snap when building the cover, then foam() for the
    foam core bulging out of it (a patch of a box `inset` inside the cover, wider than the hole
    so its edges stay hidden under the cover: no see-through) and lip() for the frayed edge of
    the cut fabric."""

    def __init__(self, rb, centre, rad, noise, seed=0.0):
        self.rb, self.noise, self.rad, self.seed = rb, noise, rad, seed
        self.c = rb.project(centre)
        _p, n = rb.rounded(self.c)
        self.n = n
        ref = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
        self.u = n.cross(ref).normalized()
        self.v = n.cross(self.u)

    def ang(self, p):
        d = p - self.c
        return math.atan2(d.dot(self.v), d.dot(self.u))

    def r(self, a):
        nz, s = self.noise, self.seed
        return self.rad * (1 + 0.3 * nz.fbm((math.cos(a) * 0.9 + 7 + s, math.sin(a) * 0.9, 3.3), 2)) + 0.06 * self.rad / 0.4 * nz.n((a * 7.0, 1.5 + s, 0.2))

    def keep(self, cen):
        return (cen - self.c).length > self.r(self.ang(cen))

    def snap(self, p):
        a = self.ang(p)
        d = p - self.c
        d -= self.n * d.dot(self.n)
        return self.rb.project(self.c + d.normalized() * self.r(a) + self.n * 0.0)

    def foam(self, parts, deform, inset=0.035, step=0.12, layer="Foam"):
        rb = self.rb
        lo = rb.lo + Vector((inset, inset, inset))
        hi = rb.hi - Vector((inset, inset, inset))
        inner = _RBox(lo, hi, max(rb.r - inset, 0.02), step)
        reach = self.rad * 1.85
        c, nz = self.c, self.noise

        def keep(cen):
            return (cen - c).length < reach

        def fd(p, n):
            q = deform(p, n)
            bulge = 1 - smoothstep(0.1 * self.rad, 1.1 * self.rad, (p - c).length)
            q += n * (0.5 * self.rad * bulge + 0.12 * self.rad * nz.fbm(p * 9.0, 2) * (0.3 + bulge))
            q -= n * 0.12 * self.rad * smoothstep(0.7, 0.9, nz.n(p * 4.5 + Vector((3, 1, 2))) * 0.5 + 0.5) * bulge
            return q

        parts.add(layer, inner.build(fd, keep))

    def lip(self, parts, cover, layer, thick=0.028):
        for loop in _boundary_loops(cover):
            lip = [q + (q - self.c).normalized() * 0.006 for q in loop]
            lip.append(lip[0])
            parts.add(layer, tube(lip, [thick + 0.6 * thick * abs(self.noise.n(q * 11)) for q in lip], segs=5, closed=False, cap=False))


class _Parts:
    """Collects (layer, bmesh) pairs before they go into the piece, so a whole piece can be
    deformed at once (a mattress bent to lean on a wall) and so its wear can look up where each
    final vertex was in the piece's REST space (stains drawn on the flat mattress follow it)."""

    def __init__(self):
        self.items = []

    def add(self, layer, bm, matrix=None):
        if matrix is not None:
            bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
        self.items.append((layer, bm))

    def commit(self, ctx, warp=None):
        """Applies warp(p) -> p to every vertex, adds everything to ctx; returns rest(p) that maps
        a final point back to its rest-space point (nearest vertex)."""
        rest, final = [], []
        for _layer, bm in self.items:
            for v in bm.verts:
                rest.append(v.co.copy())
                if warp is not None:
                    v.co = warp(v.co.copy())
                final.append(v.co.copy())
        kd = KDTree(len(final))
        for k, p in enumerate(final):
            kd.insert(p, k)
        kd.balance()
        for layer, bm in self.items:
            ctx.add(layer, bm)
        self.items = []

        def lookup(p):
            _co, k, _d = kd.find(p)
            return rest[k]

        return lookup


def _ribbon(path, width, thick, ups, n=8, square=0.4):
    """A flat closed strip along `path` (a strap, a flap edge), its cross-section a rounded
    rectangle `width` x `thick`, its flat face turned toward ups (one vector or one per point)."""
    pts = [Vector(p) for p in path]
    if isinstance(ups, Vector):
        ups = [ups] * len(pts)
    rings = []
    for i, p in enumerate(pts):
        d = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
        d.normalize()
        up = Vector(ups[i])
        up = (up - d * up.dot(d)).normalized()
        side = d.cross(up)
        ring = []
        for k in range(n):
            t = 2 * math.pi * k / n
            c, s = math.cos(t), math.sin(t)
            ring.append(tuple(p + side * (math.copysign(abs(c) ** square, c) * width / 2)
                              + up * (math.copysign(abs(s) ** square, s) * thick / 2)))
        rings.append(ring)
    return loft(rings, cap_start=True, cap_end=True)


def _blob(c, radii, noise, amp=0.15, scale=2.0, segs=14, rings=9, flat_bottom=None):
    """A soft lump (foam bursting out, a lumpy stuffing): a UV sphere with radii (x, y, z) pushed
    in and out by noise. flat_bottom = y below which it is squashed flat (resting on something)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    c = Vector(c)
    for v in bm.verts:
        n = v.co.normalized()
        k = 1 + amp * noise.fbm(n * scale + c, 2)
        p = c + Vector((n.x * radii[0], n.y * radii[1], n.z * radii[2])) * k
        if flat_bottom is not None and p.y < flat_bottom:
            p.y = flat_bottom + (p.y - flat_bottom) * 0.15
        v.co = p
    return bm


def _boundary_loops(bm):
    """The ordered vertex loops round the holes of an open mesh (a cut in a cover)."""
    edges = [e for e in bm.edges if len(e.link_faces) == 1]
    nxt = {}
    for e in edges:
        a, b = e.verts
        nxt.setdefault(a, []).append(b)
        nxt.setdefault(b, []).append(a)
    seen, loops = set(), []
    for start in list(nxt):
        if start in seen:
            continue
        loop, prev, cur = [start], None, start
        seen.add(start)
        while True:
            cand = [w for w in nxt[cur] if w is not prev and w not in seen]
            if not cand:
                break
            prev, cur = cur, cand[0]
            seen.add(cur)
            loop.append(cur)
        if len(loop) > 4:
            loops.append([v.co.copy() for v in loop])
    return loops


def _torus(R_, r, segs=12, rsegs=6):
    """A ring round Y (an eyelet, a grommet): major radius R_, tube radius r."""
    prof = [(R_ + r * math.cos(2 * math.pi * k / rsegs), r * math.sin(2 * math.pi * k / rsegs)) for k in range(rsegs)]
    return lathe(prof, segs=segs)


def _align_y(n):
    """A rotation matrix taking +Y onto the direction n."""
    return Vector((0, 1, 0)).rotation_difference(Vector(n).normalized()).to_matrix().to_4x4()


def _stain(cx, cz, rad, inner, rim, noise, seed):
    """A tide-mark stain on a fabric top as a wear function of (x, z): inside a lobed outline
    the `inner` multiplier, a darker `rim` line just inside the edge (where the liquid dried);
    dull brownish-grey multipliers (a dried stain greys the fabric, it does not dye it yellow)."""

    def fn(x, z):
        dx, dz = x - cx, z - cz
        a = math.atan2(dz, dx)
        rr = rad * (1 + 0.3 * noise.fbm((math.cos(a) * 0.8 + seed, math.sin(a) * 0.8, seed * 0.37), 2))
        d = math.hypot(dx, dz) / max(rr, 1e-3)
        if d > 1.2:
            return (1.0, 1.0, 1.0)
        # (a sharp edge and a tide line wide enough for the vertex colours to resolve it)
        body = 1 - smoothstep(0.85, 1.0, d)
        ring = smoothstep(0.75, 0.9, d) * (1 - smoothstep(0.97, 1.1, d))
        out = []
        for c in range(3):
            v = lerp(1.0, inner[c], body)
            v = lerp(v, rim[c], ring)
            out.append(v)
        return tuple(out)

    return fn


# ----------------------------------------------------------------------------------------------
# Mattress / MattressTorn / MattressLean. An old single mattress dragged in from the street
# (real: 90 x 190 x 20-25 cm -> 3.0 x 6.2 x 0.62 studs, as the old prop). What makes it read
# (real_specs.md): a soft slab with ROUNDED, PIPED edges (the tape edge round the top and the
# bottom), a quilted top pinched by tufting buttons with the stuffing puffing up between them, a
# side border that bulges, carry handles and little vent eyelets on the long sides, a hollow
# where a body lay and lumps where springs went, tide-mark stains (urine yellow, rust brown, an
# old grey one), the wet dark bottom. MattressTorn: a corner of the cover torn open, the yellow
# foam bulging out, the fabric's frayed edge and a peeled flap. MattressLean: stood on its end
# against a wall (+Z), leaning back ~10 degrees and buckled toward the wall, torn at a corner.
# props_objects.mattress: state "flat" -> Mattress / MattressTorn, "leaning" -> MattressLean.
# ----------------------------------------------------------------------------------------------
MW, ML, MT, MR = 3.0, 6.2, 0.62, 0.14


def _mattress(ctx, torn=False, lean=False, seed=0.0):
    ctx.budget = 7000
    ctx.smooth_angle = 60
    ctx.tint("Fabric", (196, 186, 160))  # old cream ticking (the data can pick a striped blue...)
    noise, rng = ctx.noise, ctx.rng
    parts = _Parts()
    rb = _RBox((-MW / 2, 0.0, -ML / 2), (MW / 2, MT, ML / 2), MR, (0.25, 0.2, 0.25))
    fx, fz = rb.flat(0), rb.flat(2)
    tufts = [(x, z) for x in fx[1::3] for z in fz[1::3]]
    # the hollow where a body lay (off-centre), lumps where springs have gone
    hol = (rng.uniform(-0.3, 0.3), rng.uniform(-0.8, 0.4))
    lumps = [(rng.uniform(-0.9, 0.9), rng.uniform(-2.4, 2.4), rng.uniform(0.04, 0.07)) for _ in range(2)]
    tz = -1 if lean else 1  # the torn corner: at the top end (flat) / the bottom end (leaning)
    tear_c = Vector((0.75, MT, tz * 2.2))
    sp = fx[3] - fx[0]  # tuft spacing

    def topness(p):
        return smoothstep(MT * 0.45, MT, p.y)

    def deform(p, n):
        t = topness(p)
        x, z = p.x, p.z
        dy = 0.0
        # quilted top: pinched at each tuft, the stuffing puffing up between them
        if n.y > 0.85:
            near = min((x - a) ** 2 + (z - b) ** 2 for a, b in tufts)
            dy -= 0.035 * math.exp(-near / 0.02)
            px = 0.5 - 0.5 * math.cos(2 * math.pi * (x - fx[1]) / sp)
            pz = 0.5 - 0.5 * math.cos(2 * math.pi * (z - fz[1]) / sp)
            dy += 0.022 * (px + pz) * (1 - smoothstep(MW / 2 - 0.35, MW / 2 - 0.1, abs(x))) * (1 - smoothstep(ML / 2 - 0.35, ML / 2 - 0.1, abs(z)))
        dy -= t * 0.1 * math.exp(-((x - hol[0]) / 0.95) ** 2 - ((z - hol[1]) / 1.9) ** 2)
        for a, b, h in lumps:
            dy += t * h * math.exp(-((x - a) ** 2 + (z - b) ** 2) / 0.16)
        # the corners slump, the long sides a little lower than the middle (old foam)
        cx = smoothstep(MW / 2 - 0.9, MW / 2, abs(x))
        cz = smoothstep(ML / 2 - 1.2, ML / 2, abs(z))
        dy -= t * (0.05 * cx * cz + 0.015 * cx)
        p.y += dy
        # the side border bulges out between its piped edges
        if abs(n.y) < 0.6:
            hn = Vector((n.x, 0, n.z))
            if hn.length > 1e-6:
                p += hn.normalized() * 0.04 * math.sin(math.pi * max(0.0, min(1.0, p.y / MT)))
        p += n * 0.012 * noise.fbm(p * 1.3 + Vector((seed, 0, 0)), 2)
        p.y = max(p.y, 0.0)  # (never through the floor)
        return p

    tear = _Tear(rb, tear_c, 0.4, noise, seed) if torn else None

    body = rb.build(deform, tear.keep if torn else None, tear.snap if torn else None)
    if torn:
        tear.lip(parts, body, "Fabric")
    parts.add("Fabric", body)
    # piping (the tape edge) round the top and the bottom, half sunk in the edge
    for y in (MT, 0.0):
        pts = [deform(p + n * 0.012, n) for p, n in rb.edge_loop(1, 1 if y > 0 else -1, thin=2)]
        for q in pts:
            q.y = max(q.y, 0.045)  # (the bottom piping rests ON the floor, not through it)
        parts.add("Fabric", tube(pts, 0.042, segs=6, closed=True))
    # carry handles (webbing straps) and vent eyelets on the long sides
    for s in (-1, 1):
        for zc in (-1.25, 1.25):
            path = []
            for k in range(7):
                u = k / 6
                p, n = rb.rounded((s * MW / 2, MT * 0.5, zc + (u - 0.5) * 0.7))
                q = deform(p, n) + Vector((s, 0, 0)) * (0.02 + 0.07 * math.sin(math.pi * u) ** 0.7)
                q.y -= 0.03 * math.sin(math.pi * u)
                path.append(q)
            parts.add("Fabric", _ribbon(path, 0.16, 0.03, Vector((s, 0, 0)), n=8))
        for zc in (-2.35, 2.35):
            if torn and s > 0 and zc * tz > 0:
                continue
            p, n = rb.rounded((s * MW / 2, MT * 0.52, zc))
            q = deform(p, n) + Vector((s, 0, 0)) * 0.01
            parts.add("Metal", _torus(0.07, 0.022, segs=10, rsegs=5), T(*q) @ _align_y((s, 0, 0)))
    if torn:  # the foam core bulging out of the cut
        tear.foam(parts, deform)

    if lean:
        phi = math.radians(10.0)
        d = Vector((0, math.cos(phi), math.sin(phi)))
        nf = Vector((0, math.sin(phi), -math.cos(phi)))  # the quilted top faces out (-Z)
        bow = 0.22

        def warp(p):
            s = p.z + ML / 2
            b = bow * math.sin(math.pi * s / ML)
            tw = 0.02 * math.sin(math.pi * s / ML) * p.x  # a slight twist
            return Vector((p.x, 0, 0)) + d * s + nf * (p.y - MT / 2 - b + tw)

        lo = Vector((1e9, 1e9, 1e9))
        hi = -lo
        for _layer, bm in parts.items:
            for v in bm.verts:
                w = warp(v.co)
                lo = Vector(map(min, lo, w))
                hi = Vector(map(max, hi, w))
        shift = Vector((0, FLOOR - lo.y, 0.80 - hi.z))  # its top against the wall at z = +0.8

        def warp2(p):
            return warp(p) + shift

        rest = parts.commit(ctx, warp2)
    else:
        rest = parts.commit(ctx, lambda p: p + Vector((0, FLOOR, 0)))

    stains = [
        _stain(rng.uniform(-0.7, 0.5), rng.uniform(-1.6, 0.6), rng.uniform(0.7, 1.0), (0.90, 0.85, 0.74), (0.66, 0.56, 0.44), noise, 1.0),
        _stain(rng.uniform(-0.8, 0.8), rng.uniform(1.0, 2.2), rng.uniform(0.6, 0.75), (0.84, 0.74, 0.64), (0.58, 0.46, 0.38), noise, 2.0),
        _stain(rng.uniform(0.2, 0.9), rng.uniform(-2.6, -1.8), rng.uniform(0.5, 0.7), (0.8, 0.78, 0.74), (0.62, 0.6, 0.56), noise, 3.0),
    ]

    def fabric(p):
        q = rest(p.co)
        q = Vector((q.x, q.y - FLOOR, q.z))
        k = 0.88 + 0.1 * noise.fbm(q * 1.7, 2)
        r = g = b = k
        if q.y > MT * 0.6:
            for st in stains:
                s = st(q.x, q.z)
                r, g, b = r * s[0], g * s[1], b * s[2]
        # the bottom: wet and black from the ground; dirt creeping up the border
        wet = 1 - smoothstep(0.02, 0.3, q.y)
        k2 = 1 - 0.45 * wet - 0.18 * (1 - smoothstep(0.0, 0.5, q.y)) * (0.6 + 0.4 * noise.fbm(q * 3, 2))
        k2 *= 1 - (0.08 if q.y > MT * 0.8 else 0.3) * smoothstep(0.0, 0.5, -p.convex)  # (no dark stars at the tufts)
        k2 *= 1 - 0.25 * (1 - smoothstep(FLOOR, 0.4, p.co.y))  # (leaning: its foot on the floor)
        return (r * k2, g * k2, b * k2 * 0.97)

    ctx.wear("Fabric", fabric)
    ctx.wear("Foam", mul(cavity(0.45), lambda p: (1.0, 0.86, 0.52), lambda p: 0.78 + 0.22 * noise.fbm(p.co * 5, 2)))
    ctx.wear("Metal", lambda p: (0.7, 0.62, 0.55))  # (rusty eyelets)


def _grid_slab(top, bot):
    """A closed slab between two grids of points (rows x cols), top and bottom."""
    rows, cols = len(top), len(top[0])
    flat_t = [p for r in top for p in r]
    flat_b = [p for r in bot for p in r]
    bm = bmesh.new()
    vt = [bm.verts.new(p) for p in flat_t]
    vb = [bm.verts.new(p) for p in flat_b]
    for i in range(rows - 1):
        for j in range(cols - 1):
            a, b, c, d = i * cols + j, (i + 1) * cols + j, (i + 1) * cols + j + 1, i * cols + j + 1
            bm.faces.new((vt[a], vt[b], vt[c], vt[d]))
            bm.faces.new((vb[d], vb[c], vb[b], vb[a]))
    ring = [i * cols for i in range(rows)] + [(rows - 1) * cols + j for j in range(1, cols)] + \
           [i * cols + cols - 1 for i in range(rows - 2, -1, -1)] + [j for j in range(cols - 2, 0, -1)]
    for k in range(len(ring)):
        a, b = ring[k], ring[(k + 1) % len(ring)]
        bm.faces.new((vt[b], vt[a], vb[a], vb[b]))
    return bm


def mattress(ctx):
    """Old single mattress lying flat: rounded piped edges, tufted quilted top, bulging border
    with handles and vent eyelets, a body hollow, tide-mark stains, wet dark bottom (3 x 6.2 x 0.7)."""
    _mattress(ctx, torn=False, lean=False, seed=0.0)


def mattress_torn(ctx):
    """Old mattress lying flat, a corner of the cover torn open: foam bulging out, frayed edge,
    a peeled flap; stained and sagging (3 x 6.2 x 0.7)."""
    _mattress(ctx, torn=True, lean=False, seed=4.0)


def mattress_lean(ctx):
    """Old mattress stood on its end against a wall (+Z, at z = +0.8), leaning back and buckled
    toward the wall, a bottom corner torn with foam showing (3 x 6.2 tall x 1.7 deep)."""
    _mattress(ctx, torn=True, lean=True, seed=9.0)


# ----------------------------------------------------------------------------------------------
# Armchair / ArmchairBlanket. A battered upholstered armchair dragged out to the street (real:
# 85 W x 85 D x 90 H cm, seat 43 cm -> drawn 3.1 x 2.9 x 3.2 studs, seat top 1.6, close to the old
# prop's 3.2 x 3 x 3.4). What makes it read (real_specs.md): ROLLED arms that flare out at the top
# with a scroll panel and piping on their fronts, a loose seat cushion with welted (piped) edges
# that sags where people sat, a loose back cushion leaning on the back frame, short turned
# wooden legs. Its life: one back leg gone and a brick under that corner, the fabric torn on the
# top of an arm with the yellow foam bursting out, arms rubbed dark and greasy where hands go,
# a dark patch where heads rested, a stain on the seat, dirt rising from the ground.
# ArmchairBlanket: the same chair, an old blanket thrown over its back (cloth simulation).
# props_objects.armchair: state "worn" -> Armchair, blanket=True -> ArmchairBlanket.
# ----------------------------------------------------------------------------------------------
AW, AD, ALEG = 3.1, 2.9, 0.35
BACK_TILT = 9.0  # degrees the back leans back


def _rot_about(rx, pivot):
    return T(*pivot) @ R(rx, 0, 0) @ T(*(-Vector(pivot)))


def _scroll_outline(w, y0, y1, n_arc=16):
    """The outline of an arm's front scroll panel in x-y: straight sides, a round top."""
    rr = w / 2
    pts = [(-rr, y0), (rr, y0)]
    yc = y1 - rr
    for k in range(n_arc + 1):
        a = math.pi * k / n_arc
        pts.append((rr * math.cos(a), yc + rr * math.sin(a)))
    pts.append((-rr, y0 + 0.001))
    return pts[:-1]


def _armchair(ctx, blanket):
    ctx.budget = 8000
    ctx.smooth_angle = 55
    ctx.tint("Fabric", (104, 78, 56))  # worn brown velour (the data picks green, rust, grey...)
    noise, rng = ctx.noise, ctx.rng
    parts = _Parts()
    y0 = ALEG
    xa = AW / 2 - 0.55  # inner face of the arms

    def soft(amp, scale=1.6, off=0.0):
        def fn(p, n):
            return p + n * amp * noise.fbm(p * scale + Vector((off, 0, 0)), 2)
        return fn

    # legs: short turned beech legs (one back leg missing: a brick under that corner)
    leg_prof = [(0.0, 0.0), (0.078, 0.0), (0.085, 0.03), (0.095, 0.16), (0.11, 0.25), (0.13, 0.27),
                (0.125, 0.32), (0.11, 0.4), (0.0, 0.4)]
    miss = (1, 1)
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * (AW / 2 - 0.28), sz * (AD / 2 - 0.3)
            if (sx, sz) == miss:
                bk = box(0.36, 0.33, 0.74, bevel=0.03)
                parts.add("Brick", bk, T(x, FLOOR + 0.165, z) @ R(0, 8, 0))
                continue
            leg = lathe(leg_prof, segs=9)
            parts.add("Wood", leg, T(x, FLOOR, z) @ R(0, 0, sx * -4))
    lift = FLOOR + 0.002  # (the body sits on its legs; the missing leg's corner on the brick)

    # the base: the seat deck and the front rail between the arms
    base = _RBox((-xa - 0.03, y0, -AD / 2 + 0.05), (xa + 0.03, y0 + 0.88, AD / 2 - 0.15), 0.09, (0.7, 0.45, 0.7), band=2)

    def base_def(p, n):
        p = soft(0.015)(p, n)
        if n.z < -0.6:  # the front rail bows out a little
            p.z -= 0.04 * math.sin(math.pi * max(0.0, min(1.0, (p.y - y0) / 0.88)))
        return p

    parts.add("Fabric", base.build(base_def))
    # the arms: rolled, flaring out at the top
    tear = None
    for s in (-1, 1):
        arm = _RBox((-0.28, y0, -AD / 2), (0.28, 2.02, AD / 2 - 0.22), 0.22, (0.2, 0.34, 0.34), band=2)
        cx = s * (AW / 2 - 0.28)

        def arm_def(p, n, s=s, cx=cx):
            t = smoothstep(1.2, 2.02, p.y)
            p = Vector((p.x * (1 + 0.18 * t) + s * 0.07 * t, p.y, p.z))
            p.y += 0.05 * math.sin(math.pi * (p.z + AD / 2) / (AD - 0.22)) * t  # (stuffing domes the roll)
            p = soft(0.018, 1.8, s)(p, n)
            return p + Vector((cx, 0, 0))

        if s > 0:
            tear = _Tear(arm, Vector((0.12, 2.02, -0.75)), 0.28, noise, 2.0)
            cover = arm.build(arm_def, tear.keep, tear.snap)
            tear.lip(parts, cover, "Fabric", thick=0.024)
            tear.foam(parts, arm_def, inset=0.03, step=0.08)
        else:
            cover = arm.build(arm_def)
        parts.add("Fabric", cover)
        # the scroll panel on the arm's front, its piping round the edge
        out = _scroll_outline(0.62, y0 + 0.12, 2.08)
        bm = bmesh.new()
        f = bm.faces.new([bm.verts.new((x, y, 0.0)) for x, y in out])
        ext = bmesh.ops.extrude_face_region(bm, geom=[f])
        for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
            v.co.z -= 0.08
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bevel_edges(bm, bm.edges[:], 0.025, 1)
        zf = -AD / 2 + 0.03
        parts.add("Fabric", bm, T(cx + s * 0.06, 0, zf))
        rim = [Vector((cx + s * 0.06 + x * 0.97, y, zf - 0.075)) for x, y in out]
        rim.append(rim[0])
        parts.add("Fabric", tube(rim, 0.03, segs=6, closed=False, cap=False))
    # the back frame (leaning back), its top rolled
    piv = (0.0, y0 + 0.8, AD / 2 - 0.4)
    back = _RBox((-xa - 0.02, y0 + 0.6, AD / 2 - 0.62), (xa + 0.02, 3.18, AD / 2 - 0.12), 0.22, (0.4, 0.4, 0.4), band=2)
    parts.add("Fabric", back.build(soft(0.02)), _rot_about(-BACK_TILT, piv))
    # the loose back cushion, pillowy, leaning on the frame
    bc = _RBox((-xa + 0.03, 1.55, AD / 2 - 1.15), (xa - 0.03, 3.0, AD / 2 - 0.6), 0.17, (0.24, 0.24, 0.3), band=2)

    def bc_def(p, n):
        u = (p.x / (xa - 0.03))
        v = (p.y - 2.275) / 0.725
        if n.z < -0.3:  # the front puffs out, more in the middle, sunk where heads rest
            p.z -= 0.13 * max(0.0, 1 - u * u) * max(0.0, 1 - v * v)
            p.z += 0.06 * math.exp(-((p.x - 0.1) / 0.5) ** 2 - ((p.y - 2.6) / 0.3) ** 2)
        p.y -= 0.08 * max(0.0, 1 - u * u) * smoothstep(2.6, 3.0, p.y)  # (the top slumps)
        return soft(0.02, 1.7, 5)(p, n)

    m_bc = _rot_about(-BACK_TILT - 4, piv)
    parts.add("Fabric", bc.build(bc_def), m_bc)
    if not blanket:  # (the blanket hides it)
        parts.add("Fabric", tube([bc_def(p + n * 0.01, n) for p, n in bc.edge_loop(2, -1, thin=2)], 0.035, segs=5, closed=True), m_bc)
    # the seat cushion: welted, sagging where people sat, squashed a little askew
    sc = _RBox((-xa + 0.02, y0 + 0.86, -AD / 2 - 0.05), (xa - 0.02, y0 + 1.32, AD / 2 - 0.95), 0.15, (0.3, 0.3, 0.3), band=2)
    zs_mid = (-AD / 2 - 0.05 + AD / 2 - 0.95) / 2
    sag_c = (rng.uniform(-0.15, 0.2), zs_mid + 0.15)

    def sc_def(p, n):
        top = smoothstep(y0 + 1.0, y0 + 1.32, p.y)
        u, v = p.x / (xa - 0.02), (p.z - zs_mid) / 1.0
        p.y += top * (0.07 * max(0.0, 1 - u * u) * max(0.0, 1 - v * v))  # (puffed)
        p.y -= top * 0.16 * math.exp(-((p.x - sag_c[0]) / 0.55) ** 2 - ((p.z - sag_c[1]) / 0.6) ** 2)  # (sat in)
        if n.z < -0.5:
            p.z -= 0.05 * math.sin(math.pi * max(0.0, min(1.0, (p.y - y0 - 0.86) / 0.46)))
        return soft(0.015, 2.0, 9)(p, n)

    m_sc = T(0, 0, 0) @ R(-1.5, 3, 1.0)
    parts.add("Fabric", sc.build(sc_def), m_sc)
    for sd in (-1, 1):
        pts = [sc_def(p + n * 0.012, n) for p, n in sc.edge_loop(1, sd, thin=2)]
        parts.add("Fabric", tube(pts, 0.035, segs=5, closed=True), m_sc)

    if blanket:
        _drape_blanket(ctx, parts, [p for p in parts.items if p[0] == "Fabric"], noise)

        def blanket_wear(p):
            k = 0.8 + 0.2 * noise.fbm(p.co * 2.5, 2)
            k *= 1 - 0.4 * smoothstep(0.0, 0.45, -p.convex)
            # two pale woven stripes near its ends (an old army blanket), ~0.25 studs wide
            u = p.co.x * 0.95 + p.co.z * 0.3
            st = max(1 - smoothstep(0.08, 0.14, abs(u - c)) for c in (-1.05, 1.05))
            return k * (1 + 0.35 * st)

        ctx.wear("Wool", blanket_wear)
    rest = parts.commit(ctx, lambda p: p + Vector((0, lift, 0)))  # noqa: F841

    stain = _stain(sag_c[0] + 0.15, sag_c[1] - 0.2, 0.42, (0.88, 0.83, 0.74), (0.64, 0.55, 0.45), noise, 5.0)

    def fabric(p):
        x, y, z = p.co
        k = 0.9 + 0.1 * noise.fbm(p.co * 2.2, 2)
        r = g = b = k
        # arm tops: rubbed dark and greasy where hands rest
        if abs(x) > xa and y > 1.6:
            gr = smoothstep(1.6, 2.0, y) * (1 - smoothstep(0.3, 1.2, z + AD / 2 - 0.6))
            m = 1 - 0.38 * gr * (0.7 + 0.3 * noise.fbm(p.co * 4, 2))
            r, g, b = r * m, g * m, b * m
        # the head patch on the back cushion
        hp = math.exp(-((x - 0.1) / 0.55) ** 2 - ((y - 2.65) / 0.35) ** 2) * smoothstep(-0.2, 0.3, -p.normal.z)
        m = 1 - 0.42 * hp
        r, g, b = r * m, g * m, b * m * 0.98
        # seat stain
        if y0 + 1.0 < y < y0 + 1.5 and abs(x) < xa:
            s_ = stain(x, z)
            r, g, b = r * s_[0], g * s_[1], b * s_[2]
        # the front edge of the seat worn shiny-dark, dirt rising from the ground, creases
        m = 1 - 0.3 * (1 - smoothstep(FLOOR, 0.9, y)) * (0.6 + 0.4 * noise.fbm(p.co * 3, 2))
        m *= 1 - 0.42 * smoothstep(0.0, 0.45, -p.convex)
        return (r * m, g * m, b * m)

    ctx.wear("Fabric", fabric)
    ctx.wear("Foam", mul(cavity(0.45), lambda p: (1.0, 0.86, 0.52), lambda p: 0.78 + 0.22 * noise.fbm(p.co * 5, 2)))
    ctx.wear("Wood", mul(ground_dirt(0.3, 0.4, noise), edge_wear(0.15), lambda p: 0.8 + 0.2 * noise.fbm(p.co * 6, 2)))
    ctx.wear("Brick", mul(ground_dirt(0.25, 0.35, noise), cavity(0.3), lambda p: 0.75 + 0.25 * noise.fbm(p.co * 5, 2)))


def _cloth(nu, nv, pos_fn, frames, thick, colliders=(), bend=0.5, mass=0.3, stiff=15.0, friction=5.0):
    """Blender's cloth solver, headless: a nu x nv sheet (pos_fn(i, j) -> its starting point,
    Roblox axes) dropped for `frames` frames onto the floor and the closed `colliders` (bmeshes,
    Roblox axes; consumed). Returns the final points (index i * nv + j). Everything it made is
    removed afterwards. (Same recipe as pieces/bags.py, kept here so the modules stay apart.)"""
    sc = bpy.context.scene
    made = []

    def link(name, me):
        ob = bpy.data.objects.new(name, me)
        sc.collection.objects.link(ob)
        made.append((ob, me))
        return ob

    verts = [to_blender(pos_fn(i, j)) for i in range(nu) for j in range(nv)]
    faces = [(i * nv + j, i * nv + j + 1, (i + 1) * nv + j + 1, (i + 1) * nv + j) for i in range(nu - 1) for j in range(nv - 1)]
    me = bpy.data.meshes.new("_cloth")
    me.from_pydata(verts, [], faces)
    ob = link("_cloth", me)
    m = ob.modifiers.new("Cloth", "CLOTH")
    st = m.settings
    st.quality = 6
    st.mass = mass
    st.tension_stiffness = stiff
    st.compression_stiffness = stiff
    st.shear_stiffness = stiff * 0.4
    st.bending_stiffness = bend
    st.air_damping = 2.0
    cs = m.collision_settings
    cs.collision_quality = 4
    cs.distance_min = thick / 2 + 0.015
    cs.use_self_collision = True
    cs.self_distance_min = min(thick * 0.6, 0.04)
    cs.self_friction = 8.0
    m.point_cache.frame_start = 1
    m.point_cache.frame_end = frames

    def collider(name, bm):
        cm = bpy.data.meshes.new(name)
        bm.to_mesh(cm)
        bm.free()
        cm.transform(TO_BLENDER)
        co = link(name, cm)
        co.modifiers.new("Collision", "COLLISION")
        co.collision.cloth_friction = friction
        co.collision.thickness_outer = 0.01

    fl = bmesh.new()
    bmesh.ops.create_cube(fl, size=1)
    bmesh.ops.transform(fl, matrix=T(0, FLOOR - 0.5, 0) @ Matrix.Diagonal((40, 1, 40, 1)), verts=fl.verts)
    collider("_floor", fl)
    for k, bm in enumerate(colliders):
        collider(f"_col{k}", bm)
    sc.frame_start, sc.frame_end = 1, frames
    for f in range(1, frames + 1):
        sc.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get()
    em = ob.evaluated_get(dg).to_mesh()
    pts = [Vector((v.co.x, v.co.z, -v.co.y)) for v in em.vertices]
    ob.evaluated_get(dg).to_mesh_clear()
    sc.frame_set(1)
    for o, mm in made:
        bpy.data.objects.remove(o, do_unlink=True)
        if mm.users == 0:
            bpy.data.meshes.remove(mm)
    return pts


def _sheet_slab(pts, nu, nv, thick):
    """A simulated sheet given thickness: a closed slab +-thick/2 along its vertex normals."""
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    for i in range(nu - 1):
        for j in range(nv - 1):
            bm.faces.new((vs[i * nv + j], vs[(i + 1) * nv + j], vs[(i + 1) * nv + j + 1], vs[i * nv + j + 1]))
    bm.normal_update()
    nrm = [v.normal.copy() for v in bm.verts]
    bm.free()
    top = [[pts[i * nv + j] + nrm[i * nv + j] * thick / 2 for j in range(nv)] for i in range(nu)]
    bot = [[pts[i * nv + j] - nrm[i * nv + j] * thick / 2 for j in range(nv)] for i in range(nu)]
    return _grid_slab(top, bot)


def _drape_blanket(ctx, parts, chair, noise):
    """An old blanket thrown over the chair's back: a 2.6 x 2.8 sheet dropped askew on the back
    top, simulated so it hangs down the back and over the back cushion in real folds."""
    nu, nv, th = 17, 16, 0.05
    Lz, Wx = 2.9, 2.5
    ang = math.radians(8)

    def start(i, j):
        z = (i / (nu - 1) - 0.42) * Lz
        x = (j / (nv - 1) - 0.5) * Wx
        xr = x * math.cos(ang) - z * math.sin(ang)
        zr = x * math.sin(ang) + z * math.cos(ang)
        return Vector((xr + 0.15, 3.5 + 0.05 * noise.n((x, 0, z)), zr + AD / 2 - 0.85))

    cols = []
    for _layer, bm in chair:
        c = bm.copy()
        cols.append(c)
    pts = _cloth(nu, nv, start, 90, th, colliders=cols, bend=0.6, mass=0.3, friction=30.0)
    parts.add("Wool", _sheet_slab(pts, nu, nv, th))


def armchair(ctx):
    """Battered armchair: rolled flaring arms with scroll panels and piping, welted sagging seat
    cushion, loose back cushion, turned wooden legs (one gone, a brick under it), an arm torn
    with foam bursting out, greasy arms, head patch, seat stain (3.1 x 3.3 x 3.0)."""
    _armchair(ctx, blanket=False)


def armchair_blanket(ctx):
    """The battered armchair with an old dark blanket thrown over its back (cloth-simulated
    drape over the back and down the back cushion)."""
    _armchair(ctx, blanket=True)


# ----------------------------------------------------------------------------------------------
# Tent. A cheap two-person ridge tent pitched on the yard's concrete (real: 200 x 130 x 110 cm ->
# 6.6 long x 4.6 wide x 3.8 tall, as the old prop). What makes it read (real_specs.md): the
# A-shape with its ridge SAGGING between the two upright poles (the pole tips poking through the
# apexes), the flysheet panels drooping between ridge and pegs, their bottom edge cut in curves
# lifting between the pegs, tension creases running from the pegs up toward the ridge; the front
# door zipped down the middle, one half rolled back and tied so the dark inside shows; guy
# lines from the apexes and the middle of each side to bricks (pegs won't go into concrete) and
# bent wire pegs wedged at the corners; the groundsheet edge showing; a mud tide-line along the
# bottom, a taped patch. props_objects.tent kind "ridge" (open) -> Tent.
# ----------------------------------------------------------------------------------------------
TW, TL, TH = 4.6, 6.6, 3.8


def tent(ctx):
    """Small ridge tent: sagging ridge between two upright poles, drooping flysheet with curved
    bottom edges and tension creases, front door half rolled back on a dark inside, guy lines to
    bricks, wire pegs, groundsheet edge, mud line, taped patch (4.6 x 3.9 x 6.6 + guys)."""
    ctx.budget = 6000
    ctx.smooth_angle = 50
    ctx.tint("Tarp", (70, 92, 64))  # faded green polyester (the data can pick blue, grey, orange)
    noise, rng = ctx.noise, ctx.rng
    th = 0.03
    nu, nv = 21, 19
    sag_r = 0.2

    def ridge(u):
        return Vector((0.0, TH - sag_r * math.sin(math.pi * u), -TL / 2 + u * TL))

    def eave(u, s):
        w = abs(math.sin(2 * math.pi * u))
        return Vector((s * (TW / 2 - 0.1 * w), 0.07 + 0.2 * w ** 1.5, -TL / 2 + u * TL))

    def roof(u, v):
        s = 1 if v >= 0 else -1
        t = abs(v)
        p = ridge(u).lerp(eave(u, s), t)
        nin = Vector((-s * TH, -TW / 2, 0)).normalized()
        sag = 0.34 * math.sin(math.pi * t) * (0.3 + 0.7 * math.sin(math.pi * u) ** 0.6)
        crease = noise.ridge((u * 4.5 + t * 2.6 * s, t * 1.8, s * 3.1)) ** 7
        crease += noise.ridge((u * 3.2 - t * 2.2 * s, t * 2.4, s * 5.7 + 2)) ** 7
        p += nin * (sag + 0.08 * crease * math.sin(math.pi * t) + 0.01 * noise.n((u * 9, t * 9, s)))
        return p

    pts = [roof(i / (nu - 1), -1 + 2 * j / (nv - 1)) for i in range(nu) for j in range(nv)]
    ctx.add("Tarp", _sheet_slab(pts, nu, nv, th))
    # the end walls: from the roof's end rows down to the ground, bulging out a little; the
    # front one zipped down the middle, its right half rolled back (open door)
    for end, u in ((-1, 0.0), (1, 1.0)):
        row = [roof(u, -1 + 2 * j / (nv - 1)) for j in range(nv)]
        if end < 0:
            row = row[: nv // 2 + 1]  # (the left half: from the left eave to the apex)
        nk = 9
        cols = len(row)
        wall = []
        for k in range(nk):
            a = k / (nk - 1)
            for j, q in enumerate(row):
                x_frac = abs(q.x) / (TW / 2)
                y = lerp(0.07, q.y, a)
                bul = 0.1 * math.sin(math.pi * a) * (1 - x_frac) * (1 if end > 0 else 0.6)
                wall.append(Vector((q.x * (1 - 0.03 * math.sin(math.pi * a)), y, q.z + end * (bul - 0.005))))
        ctx.add("Tarp", _sheet_slab(wall, nk, cols, th))
    # the rolled door: a fat roll along the doorway's right edge, tied with two toggles
    door = []
    for k in range(9):
        a = k / 8
        q = roof(0.0, 0.08 + 0.75 * a)
        door.append(Vector((q.x + 0.05, q.y + 0.02, q.z - 0.1)))
    radii = [0.08 + 0.13 * math.sin(math.pi * min(1.0, k / 7)) for k in range(9)]
    ctx.add("Tarp", tube(door, radii, segs=8))
    for k in (2, 6):
        q = door[k]
        ctx.add("FabricDark", _torus(radii[k] + 0.02, 0.02, segs=10, rsegs=4), T(*q) @ _align_y(door[k + 1] - door[k - 1]))
    # the zip down the middle of the closed half, a dark strip proud of the panel
    zip_pts = [Vector((-0.04, lerp(0.1, TH - sag_r * 0.0 - 0.15, k / 6), -TL / 2 - 0.035)) for k in range(7)]
    ctx.add("FabricDark", _ribbon(zip_pts, 0.08, 0.025, Vector((0, 0, -1)), n=6))
    # inside: the dark inner tent's back wall and its floor (seen through the open door)
    inner = [Vector((lerp(-1, 1, j / 6) * (TW / 2 - 0.5) * (1 - k / 4), 0.06 + (TH - 0.6) * k / 4, TL / 2 - 0.45)) for k in range(5) for j in range(7)]
    ctx.add("FabricDark", _sheet_slab(inner, 5, 7, 0.03))
    ctx.add("PlasticDark", box(TW + 0.3, 0.03, TL + 0.35, bevel=0.012), T(0, FLOOR + 0.015, -0.05) @ R(0, rng.uniform(-3, 3), 0))
    # the upright poles (tips through the apexes), guy lines to bricks, wire pegs at the corners
    for end in (-1, 1):
        z = end * (TL / 2 - 0.07)
        ctx.add("Metal", cyl(0.045, TH + 0.23, segs=8), T(0, (TH + 0.23) / 2 + 0.065, z))
        ctx.add("Metal", cyl(0.03, 0.12, segs=8, r2=0.008), T(0, TH + 0.42, z))
    guys = [(Vector((0, TH + 0.2, -TL / 2 - 0.05)), Vector((rng.uniform(-0.3, 0.3), 0.2, -TL / 2 - 1.6))),
            (Vector((0, TH + 0.2, TL / 2 + 0.05)), Vector((rng.uniform(-0.3, 0.3), 0.2, TL / 2 + 1.6)))]
    for s in (-1, 1):
        g = roof(0.5, s * 0.62)
        guys.append((g, Vector((s * (TW / 2 + 1.1), 0.2, rng.uniform(-0.3, 0.3)))))
    for a, b in guys:
        mid = a.lerp(b, 0.5) - Vector((0, 0.05, 0))
        ctx.add("FabricDark", tube([a, mid, b], 0.025, segs=5))
        bk = box(0.72, 0.22, 0.34, bevel=0.03)
        ctx.add("Brick", bk, T(b.x, FLOOR + 0.11, b.z) @ R(0, math.degrees(math.atan2(b.x - a.x, b.z - a.z)) + 90, 0))
    for u in (0.0, 0.5, 1.0):
        for s in (-1, 1):
            e = eave(u, s) + Vector((s * 0.05, 0, 0))
            shaft = [Vector((e.x + s * 0.18, FLOOR + 0.03, e.z)), Vector((e.x + s * 0.06, 0.32, e.z)),
                     Vector((e.x - s * 0.02, 0.36, e.z)), Vector((e.x - s * 0.06, 0.3, e.z))]
            ctx.add("Metal", tube(shaft, 0.025, segs=5))
    # a tear taped over on the left panel: two crossed strips of black gaffer tape, proud of the cloth
    pu, pv = 0.62, -0.45
    for du, dv in ((0.075, 0.0), (0.0, 0.11)):
        top, bot = [], []
        for i in range(5):
            f = (i / 4 - 0.5) * 2
            rt, rb_ = [], []
            for j in range(2):
                w = (j - 0.5) * 2
                uu = pu + du * f + (0.012 if dv else 0.0) * w
                vv = pv + dv * f + (0.018 if du else 0.0) * w
                q = roof(uu, vv)
                n = (roof(uu + 0.01, vv) - q).cross(roof(uu, vv - 0.01) - q).normalized()
                if n.dot(q - Vector((0, 0.8, q.z))) < 0:
                    n = -n
                lift = 0.03 if dv else 0.045
                rt.append(q + n * lift)
                rb_.append(q + n * (lift - 0.012))
            top.append(rt)
            bot.append(rb_)
        ctx.add("FabricDark", _grid_slab(top, bot))

    ctr = Vector((0, 0.8, 0))

    def fly(p):
        inside = p.normal.dot(p.co - ctr) < 0
        k = 0.88 + 0.12 * noise.fbm(p.co * 1.5, 2)
        k *= 1 - 0.35 * (1 - smoothstep(0.0, 0.55 + 0.2 * noise.fbm(p.co * 2, 2), p.co.y))  # mud tide-line
        k *= 1 - 0.3 * smoothstep(0.0, 0.4, -p.convex)
        k *= 1 - 0.15 * smoothstep(0.3, 0.8, noise.fbm(Vector((p.co.x * 3, p.co.y * 0.6, p.co.z * 3)), 2))  # rain streaks
        if inside:
            k *= 0.42
        return (k, k * 0.98, k * 0.94)

    ctx.wear("Tarp", fly)
    ctx.wear("FabricDark", lambda p: 0.7 + 0.2 * noise.fbm(p.co * 3, 2))
    ctx.wear("PlasticDark", mul(cavity(0.3), lambda p: 0.75 + 0.25 * noise.fbm(p.co * 2, 2)))
    ctx.wear("Brick", mul(ground_dirt(0.25, 0.35, noise), cavity(0.3), lambda p: 0.75 + 0.25 * noise.fbm(p.co * 5, 2)))
    ctx.wear("Metal", mul(ground_dirt(0.4, 0.4, noise), lambda p: (0.85, 0.8, 0.75)))


# ----------------------------------------------------------------------------------------------
# LeanTo. A tarp lean-to against a wall (+Z, the wall face at z = +2.25): a woven PE tarp (real:
# 3 x 4 m, aluminium grommets every metre, a reinforced hem; here 6 wide, as the old prop) tied
# by its grommets to an old pipe on the wall up high (4.7), sloping down to the front where two
# timber poles hold it up at 2.1, then hanging down as a skirt to the ground, its hem weighed
# with bricks; a rope from each pole top to a brick in front; one side closed with a sheet of
# cardboard. What makes it read: ONE sheet, sagging into a water pool between the wall and the
# poles, tented up over the pole tops, drooping between the ties along the wall and at its loose
# corners, tension creases running from the poles; grommets clamping the hem.
# props_objects.lean_to (closed_side) -> LeanTo (the closed side is +X).
# ----------------------------------------------------------------------------------------------
LW, LDP, LHT, LHF = 6.0, 4.5, 4.7, 2.0


def lean_to(ctx):
    """Tarp lean-to on a wall: one sagging sheet with grommets and a hem tied to a rusty wall
    pipe, held at the front by two timber poles and guy ropes, a skirt down to the ground weighed
    with bricks, a cardboard side (+X) (6.6 x 4.9 x 4.3 + ropes; wall at z = +2.25)."""
    ctx.budget = 6500
    ctx.smooth_angle = 55
    ctx.tint("Tarp", (44, 86, 150))  # the classic blue PE tarp, faded (the data can pick green, brown)
    noise, rng = ctx.noise, ctx.rng
    wall = LDP / 2
    zf = -LDP / 2 + 0.6  # the poles' line
    px = 1.9  # the poles at x = +-px
    ties = [-2.85, -1.42, 0.0, 1.42, 2.85]
    y_pipe, z_pipe, r_pipe = LHT, wall - 0.2, 0.09
    vr, vg = 0.7, 0.92
    th = 0.03

    def tie_droop(x):
        for a, b in zip(ties, ties[1:]):
            if a <= x <= b:
                return 0.14 * math.sin(math.pi * (x - a) / (b - a))
        return 0.14

    def hf(x):
        ax = abs(x)
        if ax <= px:
            return LHF + 0.12 - 0.28 * math.sin(math.pi * (x + px) / (2 * px)) ** 1.5
        return LHF + 0.12 - 0.62 * ((ax - px) / (LW / 2 - px)) ** 1.4

    def sheet(x, v):
        x0 = x + 0.04 * noise.n((x * 0.7, v * 3, 1.3))
        if v <= vr:
            a = v / vr
            bk = Vector((x0, y_pipe + r_pipe + 0.03 - tie_droop(x), z_pipe - 0.02))
            fr = Vector((x0, hf(x), zf - 0.03))
            p = bk.lerp(fr, a)
            pool = 0.45 * math.sin(math.pi * a) ** 1.3 * math.exp(-(x / 1.6) ** 2)
            droop = 0.18 * math.sin(math.pi * a) * smoothstep(px - 0.4, LW / 2, abs(x))
            cr = noise.ridge((x * 1.1 + a * 2.0, a * 2.5, 0.7)) ** 6 + noise.ridge((x * 1.1 - a * 2.2, a * 2.2, 4.1)) ** 6
            p.y -= pool + droop + 0.07 * cr * math.sin(math.pi * a)
            # tented up over the pole tops
            for sx in (-1, 1):
                p.y += 0.1 * math.exp(-((x - sx * px) / 0.35) ** 2 - ((a - 1) / 0.12) ** 2)
            return p
        f = Vector((x0, hf(x), zf - 0.03))
        g = Vector((x0, FLOOR + th / 2 + 0.006, zf - 0.85 - 0.12 * noise.n((x * 0.8, 2.0, 0.3))))
        if v <= vg:
            b = (v - vr) / (vg - vr)
            p = f.lerp(g, b)
            p.z -= 0.22 * math.sin(math.pi * b) * (0.6 + 0.4 * math.sin(math.pi * (x + LW / 2) / LW))
            p.z += 0.06 * noise.ridge((x * 2.0 + b * 1.5, b * 3.0, 2.2)) ** 4
            return p
        c = (v - vg) / (1 - vg)
        return g + Vector((0, 0, -0.38 * c))

    nu, nv = 25, 27
    pts = [[sheet(-LW / 2 + LW * i / (nu - 1), j / (nv - 1)) for j in range(nv)] for i in range(nu)]
    # normals of the sheet (from the grid) and a thicker hem round its four edges
    top, bot = [], []
    for i in range(nu):
        rt, rb_ = [], []
        for j in range(nv):
            p = pts[i][j]
            du = pts[min(i + 1, nu - 1)][j] - pts[max(i - 1, 0)][j]
            dv = pts[i][min(j + 1, nv - 1)] - pts[i][max(j - 1, 0)]
            n = dv.cross(du).normalized()
            if n.y < -0.2 or (abs(n.y) <= 0.2 and n.z > 0):
                n = -n
            hem = i in (0, nu - 1) or j in (0, nv - 1)
            t = th * (1.7 if hem else 1.0)
            rt.append(p + n * t / 2)
            rb_.append(p - n * t / 2)
        top.append(rt)
        bot.append(rb_)
    ctx.add("Tarp", _grid_slab(top, bot))

    def on_sheet(x, v):
        i = (x + LW / 2) / LW * (nu - 1)
        j = v * (nv - 1)
        i0, j0 = min(int(i), nu - 2), min(int(j), nv - 2)
        fi, fj = i - i0, j - j0
        p = pts[i0][j0].lerp(pts[i0 + 1][j0], fi).lerp(pts[i0][j0 + 1].lerp(pts[i0 + 1][j0 + 1], fi), fj)
        n = (top[i0][j0] - bot[i0][j0]).normalized()
        return p, n

    # grommets clamping the hem: along the wall edge at the ties, at the corners and the pole tops
    grommets = [(x, 0.012) for x in ties] + [(-LW / 2 + 0.12, vr), (LW / 2 - 0.12, vr), (-px, vr), (px, vr),
                                             (-LW / 2 + 0.15, 0.985), (LW / 2 - 0.15, 0.985)]
    for x, v in grommets:
        p, n = on_sheet(max(-LW / 2 + 0.12, min(LW / 2 - 0.12, x)), v)
        ctx.add("Metal", _torus(0.055, 0.028, segs=8, rsegs=4), T(*p) @ _align_y(n))
    # the wall pipe (rusty), its brackets screwed to the wall, the rope ties round it
    ctx.add("Rust", tube([(-LW / 2 - 0.35, y_pipe, z_pipe), (LW / 2 + 0.35, y_pipe, z_pipe)], r_pipe, segs=10))
    for x in (-2.2, 2.2):
        ctx.add("Rust", box(0.14, 0.24, 0.16, bevel=0.02), T(x, y_pipe, wall - 0.012 - 0.08))
        ctx.add("Rust", tube([(x - 0.075, y_pipe - 0.06, z_pipe), (x - 0.075, y_pipe + 0.1, z_pipe + 0.02)], 0.03, segs=5), )
    for x in ties:
        p, _n = on_sheet(x, 0.012)
        ring = _torus(r_pipe + 0.03, 0.026, segs=10, rsegs=5)
        ctx.add("FabricDark", ring, T(x, y_pipe, z_pipe) @ R(0, 0, 90))
        ctx.add("FabricDark", tube([Vector((x, y_pipe - r_pipe - 0.02, z_pipe - 0.03)), p + Vector((0, 0.02, 0))], 0.025, segs=5))
    # the poles: old square timber, leaning a little, a rope lashing at the top
    for sx in (-1, 1):
        h = LHF + 0.14
        lean = rng.uniform(1.5, 3.5) * sx
        pole = box(0.2, h, 0.2, bevel=0.035, segments=2)
        m = T(sx * px, FLOOR + 0.012, zf) @ R(rng.uniform(-2, 2), rng.uniform(-10, 10), lean) @ T(0, h / 2, 0)
        ctx.add("Wood", pole, m)
        top_p = m @ Vector((0, h / 2, 0))
        ctx.add("FabricDark", _torus(0.15, 0.03, segs=10, rsegs=4), T(*(top_p - Vector((0, 0.25, 0)))))
        foot = Vector((sx * (px + 0.9), FLOOR + 0.2, zf - 1.7))
        ctx.add("FabricDark", tube([top_p - Vector((0, 0.22, 0)), top_p.lerp(foot, 0.5) - Vector((0, 0.06, 0)), foot], 0.028, segs=5))
        ctx.add("Brick", box(0.72, 0.22, 0.34, bevel=0.03), T(foot.x, FLOOR + 0.11, foot.z) @ R(0, sx * 25, 0))
    # bricks weighing the hem down (lying ON it: their bottom just above its top)
    for k, x in enumerate((-2.3, -0.8, 0.6, 2.1)):
        p, _n = on_sheet(x + rng.uniform(-0.2, 0.2), 0.965)
        ctx.add("Brick", box(0.72, 0.22, 0.34, bevel=0.03), T(p.x, p.y + th + 0.11 + 0.004, p.z) @ R(0, rng.uniform(-25, 25), 0))
    # the closed side (+X): a big sheet of cardboard propped under the tarp, bowed, a fold down it
    xs_ = LW / 2 - 0.35
    z0, z1 = zf + 0.25, wall - 0.35
    nzc, nyc = 9, 7
    card_t, card_b = [], []
    for i in range(nzc):
        z = lerp(z0, z1, i / (nzc - 1))
        a = (z_pipe - z) / (z_pipe - zf)
        ytop = lerp(y_pipe, LHF, max(0.0, min(1.0, a))) - 0.75
        rt, rb_ = [], []
        for j in range(nyc):
            y = lerp(0.03, ytop, j / (nyc - 1))
            x = xs_ + 0.12 * math.sin(math.pi * j / (nyc - 1)) - 0.06 * abs(math.sin(math.pi * i / (nzc - 1) * 2)) + 0.05 * (y / 3)
            rt.append(Vector((x + 0.03, y + FLOOR, z)))
            rb_.append(Vector((x - 0.03, y + FLOOR, z)))
        card_t.append(rt)
        card_b.append(rb_)
    ctx.add("Cardboard", _grid_slab(card_t, card_b))

    def tarp(p):
        x, y, z = p.co
        k = 0.85 + 0.15 * noise.fbm(p.co * 1.2, 2)
        k *= 1 - 0.35 * smoothstep(0.0, 0.5, -p.convex)
        k *= 1 - 0.4 * (1 - smoothstep(FLOOR, 0.6, y))  # mud on the skirt and hem
        # the pool: a dirty dried-water stain where it sags, and UV fade on the top (paler... darker
        # grime only, the multiplier cannot lighten: dusty grey-green tide rings)
        if p.normal.y > 0.3:
            d = math.hypot(x / 1.6, (z - 0.2) / 1.1)
            ring = smoothstep(0.55, 0.85, d) * (1 - smoothstep(0.9, 1.1, d))
            d *= 1 + 0.25 * noise.fbm(p.co * 1.4, 2)
            k *= 1 - 0.12 * ring - 0.1 * (1 - smoothstep(0.0, 0.8, d))
        return (k * 0.95, k * 0.97, k)

    ctx.wear("Tarp", tarp)
    ctx.wear("Rust", mul(cavity(0.3), lambda p: 0.7 + 0.3 * noise.fbm(p.co * 4, 2)))
    ctx.wear("Wood", mul(ground_dirt(0.6, 0.4, noise), edge_wear(0.1), lambda p: 0.75 + 0.25 * noise.fbm(p.co * Vector((6, 1, 6)), 2)))
    ctx.wear("FabricDark", lambda p: 0.85 + 0.15 * noise.fbm(p.co * 3, 2))
    ctx.wear("Metal", lambda p: (0.8, 0.8, 0.82))
    ctx.wear("Brick", mul(ground_dirt(0.25, 0.35, noise), cavity(0.3), lambda p: 0.75 + 0.25 * noise.fbm(p.co * 5, 2)))
    ctx.wear("Cardboard", mul(lambda p: 1 - 0.45 * (1 - smoothstep(FLOOR, 0.7 + 0.3 * noise.fbm(p.co * 2, 2), p.co.y)),
                              lambda p: 0.85 + 0.15 * noise.fbm(p.co * 3, 2)))


# ----------------------------------------------------------------------------------------------
# CampStove. A one-ring screw-top camping stove on the ground with a saucepan on it (real: a
# 230 g screw-top gas cartridge 11 cm across and 9 cm tall, the burner and pot supports 15-20 cm
# across, an 18 cm saucepan; drawn ~1.4x like the city's small props so it reads at game
# distance: 1.5 x 1.25 x 1.25 studs with the handle; the old prop was 1.6 x 1.4 x 1.6). What
# makes it read (real_specs.md): the SQUAT cartridge, wider than tall (a domed top inside a
# crimped seam, a rolled bottom rim, a dent, the faded label: never a bottle shape), the valve
# body screwed on top with its wire control key, the flared burner crown, three serrated fold-out
# pot supports, a HOLLOW dented aluminium saucepan with a rolled rim, a riveted handle with a
# black grip and a stew inside, its lid ajar on the rim; a spoon on the ground. Soot on the pan
# bottom and the supports. props_objects.camp_stove (lit, pot) -> CampStove (the Light / Fx
# markers at the burner: the old flame's light moves there).
# ----------------------------------------------------------------------------------------------
def camp_stove(ctx):
    """One-ring camping stove: squat screw-top gas cartridge (dented, faded label), valve with wire
    key, flared burner, three serrated pot supports, hollow dented saucepan with rolled rim,
    riveted handle, stew, lid ajar, a spoon on the ground (1.5 x 1.25 x 1.25)."""
    ctx.budget = 3200
    ctx.smooth_angle = 40
    ctx.tint("MetalPainted", (38, 72, 140))  # cartridge blue (the data can pick red, yellow)
    noise, rng = ctx.noise, ctx.rng
    da = rng.uniform(0, 2 * math.pi)

    def can_dent(a, r, y):
        d = math.atan2(math.sin(a - da), math.cos(a - da))
        k = math.exp(-(d / 0.4) ** 2) * math.exp(-((y - 0.2) / 0.08) ** 2)
        return r - 0.04 * k
    # the cartridge: rolled bottom rim, straight wall, shoulder, crimped top seam, domed top
    prof = [(0.0, 0.075), (0.17, 0.06), (0.235, 0.034), (0.25, FLOOR + 0.002), (0.268, FLOOR + 0.004), (0.276, 0.022),
            (0.27, 0.04), (0.268, 0.06), (0.268, 0.3), (0.262, 0.332), (0.245, 0.362), (0.218, 0.386), (0.208, 0.392),
            (0.214, 0.402), (0.21, 0.418), (0.192, 0.42), (0.17, 0.412), (0.12, 0.428), (0.07, 0.442), (0.0, 0.447)]
    ctx.add("MetalPainted", lathe(prof, segs=22, radius_fn=can_dent))
    # the valve body and burner (steel), the wire control key, the crown
    burner = [(0.0, 0.43), (0.085, 0.43), (0.09, 0.47), (0.085, 0.5), (0.062, 0.505), (0.06, 0.57), (0.034, 0.585),
              (0.03, 0.665), (0.07, 0.68), (0.118, 0.705), (0.122, 0.722), (0.112, 0.735), (0.04, 0.738), (0.0, 0.73)]
    ctx.add("Metal", lathe(burner, segs=12))
    key = [Vector((0.06, 0.53, 0.0)), Vector((0.2, 0.52, 0.02)), Vector((0.3, 0.5, 0.0)), Vector((0.32, 0.47, -0.06)),
           Vector((0.27, 0.46, -0.1)), Vector((0.2, 0.5, -0.06))]
    ctx.add("Metal", tube(key, 0.018, segs=5))
    # three serrated pot supports, sooty, folded out at 120 degrees
    for k in range(3):
        a = k * 120 + 25
        arm = bmesh.new()
        merge(arm, _ribbon([Vector((0.05, 0.6, 0)), Vector((0.2, 0.66, 0)), Vector((0.29, 0.72, 0)), Vector((0.31, 0.745, 0))],
                           0.028, 0.05, Vector((0, 0, 1)), n=4, square=0.2))
        for t in (0.12, 0.2, 0.27):  # the teeth the pan sits on
            merge(arm, box(0.03, 0.04, 0.028, bevel=0.006, segments=1), T(t, 0.755 if t > 0.15 else 0.7, 0))
        ctx.add("Black", arm, R(0, a, 0))
    # the glow of the burning crown (its light and particles come out here)
    ctx.add("Glow", _torus(0.1, 0.018, segs=14, rsegs=4), T(0, 0.752, 0))
    ctx.mark("Light", (0, 0.76, 0))
    ctx.mark("Fx", (0, 0.75, 0))
    # the saucepan: hollow aluminium, rolled rim, dented, on the supports' teeth
    yb = 0.778
    pd = rng.uniform(0, 2 * math.pi)

    def pan_dent(a, r, y):
        d = math.atan2(math.sin(a - pd), math.cos(a - pd))
        k = math.exp(-(d / 0.4) ** 2) * math.exp(-((y - yb - 0.2) / 0.1) ** 2)
        return r - 0.035 * k

    pan = [(0.0, yb + 0.014), (0.3, yb + 0.002), (0.37, yb + 0.008), (0.395, yb + 0.032), (0.4, yb + 0.07),
           (0.4, yb + 0.36), (0.408, yb + 0.372), (0.42, yb + 0.384), (0.418, yb + 0.398), (0.404, yb + 0.402),
           (0.381, yb + 0.388), (0.38, yb + 0.07), (0.36, yb + 0.034), (0.3, yb + 0.026), (0.0, yb + 0.036)]
    ctx.add("Metal", lathe(pan, segs=24, radius_fn=pan_dent))
    # the stew inside (its edge buried in the pan's inner wall)
    stew = bmesh.new()
    merge(stew, cyl(0.39, 0.03, segs=20), T(0, yb + 0.24, 0))
    for v in stew.verts:
        if v.co.y > yb + 0.24:
            v.co.y += 0.015 * noise.fbm(v.co * 9, 2)
    ctx.add("Soil", stew)
    # the handle: a riveted steel strap and a black grip, sticking out toward +X
    hm = T(0.4, yb + 0.29, 0) @ R(0, 0, 9)
    ctx.add("Metal", box(0.1, 0.13, 0.12, bevel=0.015, segments=1), hm @ T(0.035, 0, 0))
    ctx.add("Metal", box(0.42, 0.03, 0.085, bevel=0.012, segments=1), hm @ T(0.27, 0.0, 0))
    for zr in (-0.03, 0.03):
        ctx.add("Metal", cyl(0.016, 0.02, segs=6), hm @ T(0.035, 0.074, zr))
    grip = box(0.5, 0.075, 0.115, bevel=0.03, segments=2)
    ctx.add("PlasticDark", grip, hm @ T(0.66, 0.0, 0))
    # the lid, ajar: resting on the rim on one side, slid and tipped toward -X
    lid = [(0.0, 0.07), (0.1, 0.066), (0.3, 0.04), (0.415, 0.006), (0.43, -0.022), (0.42, -0.026), (0.405, 0.0),
           (0.3, 0.025), (0.1, 0.05), (0.0, 0.054)]
    lm = T(-0.14, yb + 0.43, 0.06) @ R(0, 0, 11)
    ctx.add("Metal", lathe(lid, segs=20), lm)
    knob = lathe([(0.0, 0.06), (0.05, 0.06), (0.06, 0.08), (0.075, 0.11), (0.07, 0.125), (0.0, 0.13)], segs=8)
    ctx.add("PlasticDark", knob, lm)
    # a spoon on the ground
    bowl = bmesh.new()
    bmesh.ops.create_uvsphere(bowl, u_segments=8, v_segments=5, radius=1.0)
    for v in bowl.verts:
        v.co = Vector((v.co.x * 0.1, max(v.co.y, -0.4) * 0.025, v.co.z * 0.068))
    sm = T(0.62, FLOOR + 0.012, -0.58) @ R(0, rng.uniform(20, 60), 0)
    ctx.add("Metal", bowl, sm)
    ctx.add("Metal", tube([Vector((0.08, 0.006, 0)), Vector((0.3, 0.012, 0)), Vector((0.48, 0.03, 0))], 0.018, segs=5), sm)

    def can(p):
        x, y, z = p.co
        a = math.atan2(z, x)
        k = 1.0
        # the faded label: a darker printed band, a logo panel, scuffed through near the bottom
        band = smoothstep(0.08, 0.1, y) * (1 - smoothstep(0.27, 0.29, y))
        logo = band * smoothstep(0.6, 0.9, math.cos(a - 1.2))
        stripe = smoothstep(0.205, 0.215, y) * (1 - smoothstep(0.235, 0.245, y))
        k *= 1 - 0.3 * band - 0.3 * logo - 0.25 * stripe * (0.6 + 0.4 * noise.fbm(p.co * 8, 2))
        k *= 1 - 0.35 * smoothstep(0.6, 0.85, noise.fbm(p.co * 10, 2) * 0.5 + 0.5) * (1 - smoothstep(0.03, 0.14, y))
        rust = 1 - smoothstep(FLOOR, 0.05, y)
        r_, g_, b_ = k * lerp(1, 0.75, rust), k * lerp(1, 0.55, rust), k * lerp(1, 0.4, rust)
        c = 1 - 0.3 * smoothstep(0.0, 0.4, -p.convex)
        return (r_ * c, g_ * c, b_ * c)

    def metal(p):
        x, y, z = p.co
        k = 0.9 + 0.1 * noise.fbm(p.co * 6, 2)
        if y > yb - 0.01 and math.hypot(x, z) < 0.45 and y < yb + 0.42:
            k *= 1 - 0.6 * (1 - smoothstep(yb, yb + 0.16, y))  # the pan's sooty bottom
            k *= 1 - 0.2 * smoothstep(0.55, 0.8, noise.fbm(Vector((x * 6, y * 1.5, z * 6)), 2) * 0.5 + 0.5)  # drips
        if y < 0.74 and math.hypot(x, z) < 0.13:
            k *= 0.6  # burner: blackened
        k *= 1 - 0.3 * smoothstep(0.0, 0.4, -p.convex)
        return k

    ctx.wear("MetalPainted", can)
    ctx.wear("Metal", metal)
    ctx.wear("Black", lambda p: 0.8 + 0.2 * noise.fbm(p.co * 8, 2))
    ctx.wear("Soil", lambda p: (0.95, 0.75, 0.55))
    ctx.wear("PlasticDark", mul(edge_wear(0.15), lambda p: 0.85))


PIECES = {
    "Mattress": mattress,
    "MattressTorn": mattress_torn,
    "MattressLean": mattress_lean,
    "Armchair": armchair,
    "ArmchairBlanket": armchair_blanket,
    "Tent": tent,
    "LeanTo": lean_to,
    "CampStove": camp_stove,
}
