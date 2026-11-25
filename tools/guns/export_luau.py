#!/usr/bin/env python3
"""export_luau: the five guns' model data for the game, from the exported assets.

Reads, per gun:
  * assets/guns/<Id>/<id>.markers.json   (parts, paints, fit parts, groups, hinges, markers, colliders)
  * tools/guns/<gun>_holds.json            (the solved R6 holds)
  * the FBX files themselves               (Blender import: the part centres Roblox will report for the
                                            imported MeshParts, and the geometry the primitives are cut from)
  * assets/guns/texture_ids.json           (the uploaded atlases: SurfaceAppearance ids)
and writes src/shared/Firearms/Models/<Id>.luau:
  PARTS     every FBX part: paint, moving group, its atlas, its bounding-box centre / size in gun space
            (what an imported MeshPart reports), fit index
  FIT       the 3 + 1 fit parts (Receiver / Barrel / Trigger + the feed), as Flamethrower.fitMesh
  HINGES    every moving part: type, pivot (gun space CFrame), axis (gun space), rest / min / max (degrees or
            studs), detents, a chained second motion ("then"), its parent hinge
  MARKERS   every marker as a gun-space CFrame (LookVector = the marker's +X, UpVector = its +Z)
  PRIMS     the code-made build: boxes and cylinders named like the FBX parts, painted per material,
            in the part's moving group (used when ReplicatedStorage.Assets.Guns.<Id> is absent)
  CASE / ROUND / LINK  primitives of the separate small models (case axis = LookVector, toward the mouth)
  MAG       the detachable feed: its group, collider box (gun space) and masses
  HOLDS     the solved stances (gunInTorso / gunInHRP / weld CFrames, the joint angles, the residuals)
  ATLAS     part -> texture atlas ids (Color / Normal / Roughness / Metalness, 0 = not uploaded)

Spaces: model metres, +X muzzle, +Y left, +Z up. Game gun space: studs, -Z muzzle, +X right, +Y up:
roblox = (-y, z, -x) / 0.28 (as tools/pyro/flamethrower_parts.py).

How the primitives are cut (automatic, per part, no hand-made table):
  1. the part's triangles are sampled densely (points + their material);
  2. its frame: the main direction of its side (XZ) profile, model +Y (guns are thin sideways), snapped to
     X / Z within 10 degrees;
  3. it is sliced along that direction: runs of slices whose cross-section is a circle (most outer
     samples near the max radius, all round) become Cylinders;
  4. the rest is cut in 2.5D: in each slice the occupied intervals of the profile (a trigger guard or a
     thumbhole stays open), each with its own width; matching intervals of consecutive slices merge;
     coarser slices until the part fits its share of the gun budget (pistol 60, long guns 150);
  6. each piece is painted with the dominant material of the samples it holds.

Usage (Blender's Python, headless, from the repo root):
  /home/user/z-anatomy/venv/bin/python -I tools/guns/export_luau.py [Pistol Shotgun Rifle Sniper Lmg]
        [--render DIR]   side-by-side renders: the FBX (top) and the primitives (bottom), side + 3/4 views
then `stylua src/shared/Firearms/Models`.
"""
import argparse
import json
import math
import os
import sys

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from scipy import ndimage  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ASSETS = os.path.join(ROOT, 'assets', 'guns')
OUT_DIR = os.path.join(ROOT, 'src', 'shared', 'Firearms', 'Models')
GUNS = ['Pistol', 'Shotgun', 'Rifle', 'Sniper', 'Lmg']
HOLDS = {'Pistol': 'pistol', 'Shotgun': 'shotgun', 'Rifle': 'rifle_ak', 'Sniper': 'sniper', 'Lmg': 'lmg'}
S = 0.28  # metres per stud
CM = np.array([[0, -1, 0], [0, 0, 1], [-1, 0, 0]], dtype=float)  # model axes -> game axes (det +1)
BUDGET = {'Pistol': 60, 'Shotgun': 150, 'Rifle': 150, 'Sniper': 150, 'Lmg': 150}
# separate small models: their own budgets (pieces)
SMALL_BUDGET = {'Case': 4, 'Round': 5, 'Link': 3}

# Material (Blender) -> paint key of the primitives' palette (Firearms/GunModel PAINTS).
MAT_PAINT = {
    'Polymer': 'Polymer', 'PolymerStipple': 'Polymer', 'SteelBlued': 'SteelBlued', 'SteelBare': 'SteelBare',
    'SteelPhosphate': 'SteelPhosphate', 'SteelLacquer': 'SteelLacquer', 'SteelMag': 'SteelBlued',
    'Aluminium': 'Aluminium', 'Wood': 'Wood', 'WoodGrip': 'Wood', 'WoodStock': 'Wood', 'Rubber': 'Rubber',
    'RubberRibbed': 'Rubber', 'Fabric': 'Fabric', 'FabricTan': 'FabricTan', 'FabricCamo': 'FabricCamo',
    'Brass': 'Brass', 'CaseHead': 'Brass', 'Copper': 'Copper', 'Nickel': 'Nickel', 'Lens': 'Lens',
    'Glow': 'Glow', 'Reticle': 'Lens', 'Stamp': 'SteelPhosphate', 'Bore': 'Bore', 'SightPaint': 'SightPaint',
    'RaceInner': 'Aluminium', 'HullPlastic': 'HullRed', 'Hull': 'HullRed',
}

# Parts on a second atlas (the JSON "atlases" notes, as data). Everything else uses <Id>_*.
ATLAS_PARTS = {
    'Rifle': {'Rifle_Wood': ['Stock', 'PistolGrip', 'HandguardLower', 'HandguardUpper']},
    'Sniper': {'Sniper_Stock': ['Stock', 'CheekPiece', 'ButtPad', 'Monopod']},
    'Lmg': {'Lmg_Soft': ['AmmoPouch', 'Sling', 'PouchEmpty'],
            'Lmg_Ammo': ['Belt%02d' % i for i in range(1, 13)] + ['Case', 'Round', 'Link', 'BeltSegment']},
}


# --------------------------------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------------------------------

def to_game_vec(v):
    return CM @ np.asarray(v, dtype=float)


def to_game_point(p):
    return CM @ np.asarray(p, dtype=float) / S


def fmt(x, nd=4):
    v = round(float(x), nd)
    if v == 0:
        v = 0.0
    s = ('%.' + str(nd) + 'f') % v
    s = s.rstrip('0').rstrip('.')
    return s if s not in ('-0', '') else '0'


def v3(v, nd=4):
    return 'Vector3.new(%s, %s, %s)' % (fmt(v[0], nd), fmt(v[1], nd), fmt(v[2], nd))


def cframe(pos, right, up, back, nd=4):
    """Roblox CFrame from a position and its 3 column axes (all game space)."""
    r, u, b = right, up, back
    vals = [pos[0], pos[1], pos[2], r[0], u[0], b[0], r[1], u[1], b[1], r[2], u[2], b[2]]
    return 'CFrame.new(%s)' % ', '.join(fmt(x, nd if i < 3 else 5) for i, x in enumerate(vals))


def cframe12(vals):
    return 'CFrame.new(%s)' % ', '.join(fmt(x, 5) for x in vals)


def marker_cframe(m):
    """Marker: p (m), x (direction), z (up-ish). Gun space CFrame: LookVector = x, UpVector = z."""
    look = to_game_vec(m['x'])
    up = to_game_vec(m['z'])
    look /= np.linalg.norm(look)
    up = up - look * np.dot(up, look)
    up /= np.linalg.norm(up)
    back = -look
    right = np.cross(up, back)
    return cframe(to_game_point(m['p']), right, up, back)


def lua_str(s):
    return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"') + '"'


def lua_value(v, indent=1):
    pad = '\t' * indent
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return fmt(v, 5)
    if isinstance(v, str):
        return lua_str(v)
    if isinstance(v, (list, tuple)):
        return '{ ' + ', '.join(lua_value(x, indent + 1) for x in v) + ' }'
    if isinstance(v, dict):
        items = []
        for k, x in v.items():
            key = k if k.isidentifier() else '[%s]' % lua_str(k)
            items.append('%s\t%s = %s,' % (pad, key, lua_value(x, indent + 1)))
        return '{\n' + '\n'.join(items) + '\n' + '\t' * (indent - 1) + '}'
    if v is None:
        return 'nil'
    raise TypeError(type(v))


# --------------------------------------------------------------------------------------------------
# FBX import -> per-part triangles
# --------------------------------------------------------------------------------------------------

def import_fbx(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    out = {}
    deps = bpy.context.evaluated_depsgraph_get()
    for o in bpy.context.scene.objects:
        if o.type != 'MESH':
            continue
        ev = o.evaluated_get(deps)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        mw = o.matrix_world
        verts = np.array([tuple(mw @ v.co) for v in me.vertices], dtype=float)
        tris = np.array([tuple(t.vertices) for t in me.loop_triangles], dtype=int).reshape(-1, 3)
        mats = [(me.materials[t.material_index].name if me.materials and me.materials[t.material_index]
                 else 'SteelBlued') for t in me.loop_triangles]
        out[o.name] = dict(verts=verts, tris=tris, mats=mats,
                           parent=o.parent.name if o.parent else None)
        ev.to_mesh_clear()
    return out


def sample_surface(mesh, spacing):
    """Points on every triangle (about one per spacing^2), with the triangle's material index."""
    v, t = mesh['verts'], mesh['tris']
    if len(t) == 0:
        return np.zeros((0, 3)), np.zeros(0, dtype=int), []
    names = sorted(set(mesh['mats']))
    mid = np.array([names.index(m) for m in mesh['mats']])
    a, b, c = v[t[:, 0]], v[t[:, 1]], v[t[:, 2]]
    area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    pts, ids = [a, b, c, (a + b + c) / 3], [mid, mid, mid, mid]
    n = np.minimum(np.ceil(area / (spacing * spacing) * 2).astype(int), 400)
    rng = np.random.default_rng(7)
    for k in range(1, int(n.max()) + 1 if len(n) else 1):
        sel = n >= k
        if not sel.any():
            break
        r1, r2 = rng.random(sel.sum()), rng.random(sel.sum())
        flip = r1 + r2 > 1
        r1[flip], r2[flip] = 1 - r1[flip], 1 - r2[flip]
        p = a[sel] + (b[sel] - a[sel]) * r1[:, None] + (c[sel] - a[sel]) * r2[:, None]
        pts.append(p)
        ids.append(mid[sel])
    return np.concatenate(pts), np.concatenate(ids), names


# --------------------------------------------------------------------------------------------------
# decomposition
# --------------------------------------------------------------------------------------------------

def circle_runs(local, h, min_len_ratio=2.2):
    """Slices along local X: runs of circular cross-sections -> [(x0, x1, cy, cz, r)]."""
    ext = local.max(axis=0) - local.min(axis=0)
    if ext[0] < min_len_ratio * max(ext[1], ext[2]) and ext[0] < 3 * h:
        return []
    x0 = local[:, 0].min()
    nsl = max(1, int(math.ceil(ext[0] / h)))
    rows = []
    for i in range(nsl):
        a, b = x0 + i * h, x0 + (i + 1) * h
        sel = local[(local[:, 0] >= a) & (local[:, 0] <= b + 1e-9)]
        if len(sel) < 12:
            rows.append(None)
            continue
        yz = sel[:, 1:]
        lo, hi = yz.min(axis=0), yz.max(axis=0)
        cen = (lo + hi) / 2
        ex = hi - lo
        if min(ex) <= 1e-5 or max(ex) / min(ex) > 1.2:
            rows.append(None)
            continue
        r = np.linalg.norm(yz - cen, axis=1)
        rmax = r.max()
        outer = r > 0.6 * rmax
        if outer.sum() < 8 or (r[outer] > 0.9 * rmax).mean() < 0.8:
            rows.append(None)
            continue
        # angular coverage of the outer ring (a half-pipe is not a cylinder)
        ang = np.degrees(np.arctan2(yz[outer, 1] - cen[1], yz[outer, 0] - cen[0]))
        bins = np.histogram(ang, bins=12, range=(-180, 180))[0]
        if (bins > 0).sum() < 10:
            rows.append(None)
            continue
        rows.append((a, b, cen[0], cen[1], rmax))
    runs = []
    cur = None
    for row in rows:
        if row is None:
            if cur:
                runs.append(cur)
            cur = None
            continue
        a, b, cy, cz, r = row
        if cur and abs(r - cur[4]) <= 0.12 * max(r, cur[4]) and math.hypot(cy - cur[2], cz - cur[3]) < 0.15 * r:
            n = cur[5] + 1
            cur = (cur[0], b, (cur[2] * cur[5] + cy) / n, (cur[3] * cur[5] + cz) / n, max(cur[4], r), n)
        else:
            if cur:
                runs.append(cur)
            cur = (a, b, cy, cz, r, 1)
    if cur:
        runs.append(cur)
    return [(a, b, cy, cz, r) for (a, b, cy, cz, r, n) in runs if (b - a) >= 1.5 * h or n >= 2]


def frame_at(angle_deg):
    """e1 at `angle_deg` in the side (XZ) plane (0 = +X, 90 = +Z), e2 = model +Y, e3 = e1 x e2."""
    r = math.radians(angle_deg)
    e1 = np.array([math.cos(r), 0, math.sin(r)])
    e2 = np.array([0, 1.0, 0])
    return np.stack([e1, e2, np.cross(e1, e2)], axis=1)


def pca_angle(points):
    """Main direction of the side (XZ) profile, degrees in [0, 180)."""
    xz = points[:, [0, 2]]
    if len(points) <= 3:
        return 0.0
    w, vec = np.linalg.eigh(np.cov((xz - xz.mean(axis=0)).T))
    u = vec[:, int(np.argmax(w))]
    return math.degrees(math.atan2(u[1], u[0])) % 180


def raster_xz(points, lo, res, shape):
    g = np.zeros(shape, dtype=bool)
    ij = np.floor((points[:, [0, 2]] - lo) / res).astype(int)
    ok = (ij[:, 0] >= 0) & (ij[:, 1] >= 0) & (ij[:, 0] < shape[0]) & (ij[:, 1] < shape[1])
    g[ij[ok, 0], ij[ok, 1]] = True
    return g


def pieces_raster(pieces, lo, res, shape):
    """Side silhouette (XZ) of the pieces, on the same grid."""
    g = np.zeros(shape, dtype=bool)
    xs = lo[0] + (np.arange(shape[0]) + 0.5) * res
    zs = lo[1] + (np.arange(shape[1]) + 0.5) * res
    X, Z = np.meshgrid(xs, zs, indexing='ij')
    for p in pieces:
        e1, e3 = p['axes'][:, 0], p['axes'][:, 2]
        dx, dz = X - p['centre'][0], Z - p['centre'][2]
        u = dx * e1[0] + dz * e1[2]
        v = dx * e3[0] + dz * e3[2]
        g |= (np.abs(u) <= p['size'][0] / 2 + res * 0.5) & (np.abs(v) <= p['size'][2] / 2 + res * 0.5)
    return g


def slice_intervals(vals, gap):
    """Sorted values -> [(lo, hi)] intervals split where consecutive values are more than `gap` apart."""
    if len(vals) == 0:
        return []
    v = np.sort(vals)
    cuts = np.nonzero(np.diff(v) > gap)[0]
    out, start = [], 0
    for c in cuts:
        out.append((v[start], v[c]))
        start = c + 1
    out.append((v[start], v[-1]))
    return out


def profile_boxes(local, h, tol):
    """2.5D cut: slices along local X; in each slice the occupied intervals along local Z (holes such as
    a trigger guard or a thumbhole stay open), each with its Y extent; consecutive slices whose
    intervals match within `tol` merge. -> [(lo(3), hi(3), sample mask)]"""
    x0, x1 = local[:, 0].min(), local[:, 0].max()
    nsl = max(1, int(math.ceil((x1 - x0) / h - 1e-9)))
    open_boxes = []  # [lo, hi, mask]
    done = []
    for i in range(nsl):
        a, b = x0 + i * h, (x0 + (i + 1) * h) if i < nsl - 1 else x1 + 1e-9
        sel = np.nonzero((local[:, 0] >= a) & (local[:, 0] < b))[0]
        if len(sel) == 0:
            done.extend(open_boxes)
            open_boxes = []
            continue
        zs = local[sel, 2]
        order = np.argsort(zs)
        ints = slice_intervals(zs[order], max(1.6 * h, 0.003))
        rows = []
        for (zl, zh) in ints:
            m = sel[(zs >= zl - 1e-12) & (zs <= zh + 1e-12)]
            yl, yh = local[m, 1].min(), local[m, 1].max()
            xl, xh = local[m, 0].min(), local[m, 0].max()
            rows.append((np.array([xl, yl, zl]), np.array([xh, yh, zh]), m))
        still = []
        used = set()
        for ob in open_boxes:
            match = None
            for k, (lo, hi, m) in enumerate(rows):
                if k in used:
                    continue
                if (abs(lo[2] - ob[0][2]) <= tol and abs(hi[2] - ob[1][2]) <= tol
                        and abs(lo[1] - ob[0][1]) <= tol and abs(hi[1] - ob[1][1]) <= tol):
                    match = k
                    break
            if match is None:
                done.append(ob)
            else:
                used.add(match)
                lo, hi, m = rows[match]
                ob[0] = np.minimum(ob[0], lo)
                ob[1] = np.maximum(ob[1], hi)
                ob[2] = np.concatenate([ob[2], m])
                still.append(ob)
        for k, (lo, hi, m) in enumerate(rows):
            if k not in used:
                still.append([lo.copy(), hi.copy(), m])
        open_boxes = still
    done.extend(open_boxes)
    return done


def decompose(name, mesh, spacing, cap, angles=None):
    """-> list of pieces dict(shape, centre(model), axes(3x3 model columns), size(model m), paint)."""
    pts, mid, names = sample_surface(mesh, spacing / 3)
    if len(pts) == 0:
        return []
    origin = pts.mean(axis=0)

    def paint_of(idx):
        if len(idx) == 0:
            return MAT_PAINT.get(names[int(np.bincount(mid).argmax())], 'SteelBlued')
        k = int(np.bincount(mid[idx], minlength=len(names)).argmax())
        return MAT_PAINT.get(names[k], 'SteelBlued')

    def build(e, local, h, tol):
        pieces = []
        covered = np.zeros(len(local), dtype=bool)
        for (a, b, cy, cz, r) in circle_runs(local, h):
            sel = (local[:, 0] >= a - 1e-9) & (local[:, 0] <= b + 1e-9)
            xs = local[sel, 0]
            covered |= sel
            centre = origin + e @ np.array([(xs.min() + xs.max()) / 2, cy, cz])
            pieces.append(dict(shape='Cyl', centre=centre, axes=e,
                               size=np.array([xs.max() - xs.min(), 2 * r, 2 * r]),
                               paint=paint_of(np.nonzero(sel)[0]), vol=math.pi * r * r * (xs.max() - xs.min())))
        rest_ids = np.nonzero(~covered)[0]
        if len(rest_ids):
            for lo, hi, m in profile_boxes(local[rest_ids], h, tol):
                size = np.maximum(hi - lo, 0.0012)
                centre = origin + e @ ((lo + hi) / 2)
                pieces.append(dict(shape='Block', centre=centre, axes=e, size=size,
                                   paint=paint_of(rest_ids[m]), vol=float(np.prod(size)) + 1e-9 * len(m)))
        return pieces

    def fit_cap(e):
        local = (pts - origin) @ e
        ext = local.max(axis=0) - local.min(axis=0)
        h = max(min(spacing, ext[0] / 2), 0.0015)
        tol = max(spacing * 0.35, 0.001)
        pieces = build(e, local, h, tol)
        tries = 0
        while len(pieces) > cap and tries < 10:
            h *= 1.25
            tol *= 1.4
            pieces = build(e, local, h, tol)
            tries += 1
        pieces.sort(key=lambda p: -p['vol'])
        return pieces[:cap]

    # candidate frames: the model axes and the profile's own main direction; the one whose side
    # silhouette is closest to the part's (fewer pieces breaking ties) wins
    res = max(spacing / 3, 0.001)
    lo2 = pts[:, [0, 2]].min(axis=0) - 2 * res
    shape = tuple(np.ceil((pts[:, [0, 2]].max(axis=0) + 2 * res - lo2) / res).astype(int))
    truth = raster_xz(pts, lo2, res, shape)
    truth = ndimage.binary_closing(truth, iterations=1) | truth
    best = None
    if angles is None:
        angles = sorted({0.0, 90.0, round(pca_angle(pts), 1)})
    for ang in angles:
        pieces = fit_cap(frame_at(ang))
        err = np.logical_xor(pieces_raster(pieces, lo2, res, shape), truth).sum() / max(1, truth.sum())
        score = err + 0.004 * len(pieces)
        if best is None or score < best[0]:
            best = (score, pieces)
    return best[1]


def piece_cframe(p):
    """Gun space CFrame + size (studs) of a piece."""
    e = p['axes']
    right, up, back = to_game_vec(e[:, 0]), to_game_vec(e[:, 1]), to_game_vec(e[:, 2])
    return cframe(to_game_point(p['centre']), right, up, back), np.asarray(p['size']) / S


# --------------------------------------------------------------------------------------------------
# per gun
# --------------------------------------------------------------------------------------------------

def hinge_group_of(name, parents, hinges):
    """The nearest hinge at or above this part (parts move with it), or 'Body'."""
    seen = 0
    cur = name
    while cur and seen < 20:
        if cur in hinges:
            return cur
        cur = parents.get(cur)
        seen += 1
    return 'Body'


def atlas_of(gid, part):
    for atlas, members in ATLAS_PARTS.get(gid, {}).items():
        if part in members:
            return atlas
    if part in ('Case', 'Round', 'Link', 'BeltSegment', 'RoundGreen'):
        return gid + '_Ammo'
    return gid


def export(gid, render_dir=None):
    folder = os.path.join(ASSETS, gid)
    data = json.load(open(os.path.join(folder, gid.lower() + '.markers.json')))
    holds = json.load(open(os.path.join(HERE, HOLDS[gid] + '_holds.json')))
    tex = json.load(open(os.path.join(ASSETS, 'texture_ids.json')))
    gun = import_fbx(os.path.join(folder, gid + '.fbx'))
    parts_json = data['parts']
    hinges = data['hinges']
    parents = {}
    for name, info in parts_json.items():
        if info.get('parent'):
            parents[name] = info['parent']
    for name, m in gun.items():
        if m['parent'] and name not in parents:
            parents[name] = m['parent']
    for g, kids in data.get('groups', {}).items():
        for k in kids:
            parents.setdefault(k, g)

    # ---- PARTS (fit centres = the bounding-box centres an imported MeshPart reports)
    parts_out = {}
    for name, m in sorted(gun.items()):
        lo, hi = m['verts'].min(axis=0), m['verts'].max(axis=0)
        c = to_game_point((lo + hi) / 2)
        size = np.abs(CM @ (hi - lo)) / S
        info = parts_json.get(name, {})
        parts_out[name] = dict(
            paint=MAT_PAINT.get(info.get('paint', 'SteelBlued'), info.get('paint', 'SteelBlued')),
            group=hinge_group_of(name, parents, hinges), atlas=atlas_of(gid, name),
            centre=c, size=size, fit=info.get('fit'), tris=len(m['tris']))
    fit = sorted([(p['fit'], n) for n, p in parts_out.items() if p['fit']])

    # ---- PRIMS: each part cut freely first; over the gun budget, every part's share shrinks in
    # proportion to what it needed (a detailed receiver keeps more pieces than a pin)
    spacing = 0.004 if gid == 'Pistol' else 0.008
    budget = BUDGET[gid]
    free = {name: decompose(name, gun[name], spacing, 40) for name in sorted(gun)}
    need = sum(len(v) for v in free.values())
    prims = []
    for name in sorted(gun):
        pieces = free[name]
        if need > budget:
            cap = max(1, int(len(pieces) * budget / need))
            if cap < len(pieces):
                pieces = decompose(name, gun[name], spacing, cap)
        for p in pieces:
            p['name'] = name
            p['group'] = parts_out[name]['group']
            prims.append(p)
    while len(prims) > budget:  # (rounding) drop the smallest piece of a part that has several
        counts = {}
        for p in prims:
            counts[p['name']] = counts.get(p['name'], 0) + 1
        cand = [p for p in prims if counts[p['name']] > 1]
        cand.sort(key=lambda p: p['vol'])
        prims.remove(cand[0])

    # ---- separate small models
    small = {}
    for key in ('Case', 'Round', 'Link'):
        fname = data.get('separate', {}).get(key)
        if not fname:
            continue
        sm = import_fbx(os.path.join(folder, fname))
        pieces = []
        for name, m in sm.items():
            pieces += decompose(key, m, 0.0015, SMALL_BUDGET[key], angles=[0.0] if key != 'Link' else None)
        pieces.sort(key=lambda p: -p['vol'])
        small[key] = pieces[:SMALL_BUDGET[key]]

    # ---- the feed (magazine / pouch): its group and collider in gun space
    feed = None
    feed_part = 'AmmoPouch' if 'AmmoPouch' in gun else ('Magazine' if 'Magazine' in gun else None)
    if feed_part:
        members = [n for n in gun if hinge_group_of(n, parents, hinges) == feed_part]
        allv = np.concatenate([gun[n]['verts'] for n in members])
        lo, hi = allv.min(axis=0), allv.max(axis=0)
        col = data.get('colliders', {}).get(feed_part, {})
        feed = dict(part=feed_part, members=members, centre=to_game_point((lo + hi) / 2),
                    size=np.abs(CM @ (hi - lo)) / S, mass=col.get('massKg', 0.3),
                    massEmpty=col.get('massEmptyKg', 0.1))

    write_luau(gid, data, holds, tex, parts_out, fit, hinges, parents, prims, small, feed)
    if render_dir:
        render(gid, os.path.join(folder, gid + '.fbx'), prims, render_dir)
    return len(prims)


def write_luau(gid, data, holds, tex, parts_out, fit, hinges, parents, prims, small, feed):
    L = []
    w = L.append
    w('--!strict')
    w('-- GENERATED by tools/guns/export_luau.py from assets/guns/%s (markers JSON + FBX) and' % gid)
    w('-- tools/guns/%s_holds.json. Do not edit: change the model / holds and run it again.' % HOLDS[gid])
    w('--')
    w('-- The %s in GUN SPACE (studs; -Z = muzzle / LookVector, +X = right, +Y = up; the origin is the' % gid)
    w('-- breech face on the bore). See Shared/Firearms/Types (GunModelData) and docs/firearms/CORE.md.')
    w('')
    w('local Types = require(script.Parent.Parent.Types)')
    w('')
    w('local M: Types.GunModelData = {')
    w('\tid = %s,' % lua_str(gid))
    w('\tmassKg = %s,' % fmt(data['massKg'], 3))
    dims = {k: v for k, v in data['dims'].items() if isinstance(v, (int, float))}
    w('\tdims = %s, -- metres' % lua_value(dims, 2))
    # parts
    w('\tparts = {')
    for name, p in parts_out.items():
        w('\t\t%s = { paint = %s, group = %s, atlas = %s, centre = %s, size = %s%s },' % (
            name if name.isidentifier() else '[%s]' % lua_str(name), lua_str(p['paint']), lua_str(p['group']),
            lua_str(p['atlas']), v3(p['centre']), v3(p['size']),
            (', fit = %d' % p['fit']) if p['fit'] else ''))
    w('\t},')
    w('\tfit = {')
    for idx, name in fit:
        w('\t\t{ name = %s, centre = %s },' % (lua_str(name), v3(parts_out[name]['centre'])))
    w('\t},')
    # hinges
    w('\thinges = {')
    for name, hg in hinges.items():
        pivot = to_game_point(hg['pivot'])
        axis = to_game_vec(hg['axis'])
        n = np.linalg.norm(axis)
        axis = axis / n if n > 0 else axis
        unit = S if hg['type'] in ('slide', 'detach') else 1.0
        rest = hg.get('rest', 0) / unit
        mn = hg.get('min', 0) / unit
        mx = hg.get('max', 0) / unit
        parent = hinge_group_of(parents.get(name), parents, hinges) if parents.get(name) else 'Body'
        extra = ''
        then = hg.get('then')
        if isinstance(then, dict):
            tax = to_game_vec(then['axis'])
            tu = S if then['type'] == 'slide' else 1.0
            extra += ', ["then"] = { type = %s, axis = %s, max = %s }' % (
                lua_str(then['type']), v3(tax / np.linalg.norm(tax)), fmt(then.get('max', 0) / tu, 4))
        elif then == 'detach':
            extra += ', detach = true'
        if hg.get('detents'):
            extra += ', detents = %s' % lua_value({k: v for k, v in hg['detents'].items()}, 3).replace('\n', ' ')
        if hg.get('lockBackOnEmpty'):
            extra += ', lockBack = true'
        w('\t\t%s = { type = %s, pivot = %s, axis = %s, rest = %s, min = %s, max = %s, parent = %s%s },' % (
            name, lua_str(hg['type']), v3(pivot), v3(axis), fmt(rest, 4), fmt(mn, 4), fmt(mx, 4),
            lua_str(parent), extra))
    w('\t},')
    # markers
    w('\tmarkers = {')
    for name, m in data['markers'].items():
        w('\t\t%s = %s,' % (name, marker_cframe(m)))
    w('\t},')
    # primitives
    def prim_lines(plist, indent):
        out = []
        for p in plist:
            cf, size = piece_cframe(p)
            out.append('%s{ name = %s, shape = %s, cf = %s, size = %s, paint = %s, group = %s },' % (
                indent, lua_str(p['name']), lua_str(p['shape']), cf, v3(size, 4), lua_str(p['paint']),
                lua_str(p.get('group', 'Body'))))
        return out
    w('\tprims = {')
    L.extend(prim_lines(prims, '\t\t'))
    w('\t},')
    for key in ('Case', 'Round', 'Link'):
        if key in small:
            for p in small[key]:
                p['name'] = key
                p['group'] = 'Body'
            w('\t%s = {' % key.lower())
            L.extend(prim_lines(small[key], '\t\t'))
            w('\t},')
    if feed:
        w('\tfeed = { part = %s, members = %s, centre = %s, size = %s, massKg = %s, massEmptyKg = %s },' % (
            lua_str(feed['part']), lua_value(sorted(feed['members'])), v3(feed['centre']), v3(feed['size']),
            fmt(feed['mass'], 3), fmt(feed['massEmpty'], 3)))
    # atlases
    atlases = sorted({p['atlas'] for p in parts_out.values()} | {atlas_of(gid, k) for k in small})
    w('\tatlases = {')
    for a in atlases:
        ids = [tex.get('%s_%s' % (a, mapn), 0) for mapn in ('Color', 'Normal', 'Roughness', 'Metalness')]
        w('\t\t%s = { color = %d, normal = %d, roughness = %d, metalness = %d },' % (a, *ids))
    w('\t},')
    # holds
    w('\tholds = {')
    for sname, st in holds['stances'].items():
        key = sname if sname.isidentifier() else '[%s]' % lua_str(sname)
        pose = st.get('pose', {})
        res = st.get('residuals', {})
        w('\t\t%s = {' % key)
        for f in ('gunInTorso', 'gunInHRP', 'weld'):
            if f in st:
                w('\t\t\t%s = %s,' % (f, cframe12(st[f])))
        w('\t\t\tpose = {')
        for j, vals in pose.items():
            w('\t\t\t\t%s = { %s },' % (j, ', '.join(fmt(x, 3) for x in vals)))
        w('\t\t\t},')
        aim = st.get('aim', {})
        w('\t\t\taim = { yaw = %s, pitch = %s, cant = %s },' % (
            fmt(aim.get('yaw', 0), 2), fmt(aim.get('pitch', 0), 2), fmt(aim.get('cant', 0), 2)))
        if st.get('owner'):
            w('\t\t\towner = %s,' % lua_str(st['owner']))
        nums = {k: v for k, v in res.items() if isinstance(v, (int, float))}
        w('\t\t\tresiduals = %s,' % lua_value(nums, 4).replace('\n', ' '))
        w('\t\t},')
    w('\t},')
    rows = holds.get('aimRows')
    if rows:
        w('\taimRows = { %s },' % ', '.join('{ pitch = %s, stance = %s }' % (k, lua_str(v)) for k, v in
                                           sorted(rows.items(), key=lambda kv: float(kv[0]))))
    w('}')
    w('')
    w('return table.freeze(M)')
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, gid + '.luau')
    open(path, 'w').write('\n'.join(L) + '\n')
    print('wrote', os.path.relpath(path, ROOT), '-', len(prims), 'primitives')


# --------------------------------------------------------------------------------------------------
# preview renders (Workbench): FBX on top, primitives below, side view and a 3/4 view
# --------------------------------------------------------------------------------------------------

PREVIEW_RGB = {
    'Polymer': (0.035, 0.035, 0.037), 'SteelBlued': (0.06, 0.062, 0.07), 'SteelBare': (0.32, 0.32, 0.33),
    'SteelPhosphate': (0.09, 0.09, 0.085), 'SteelLacquer': (0.13, 0.11, 0.08), 'Aluminium': (0.22, 0.22, 0.22),
    'Wood': (0.30, 0.12, 0.04), 'Rubber': (0.025, 0.025, 0.025), 'Fabric': (0.09, 0.09, 0.08),
    'FabricTan': (0.38, 0.30, 0.18), 'FabricCamo': (0.16, 0.18, 0.13), 'Brass': (0.55, 0.40, 0.14),
    'Copper': (0.50, 0.26, 0.13), 'Nickel': (0.5, 0.5, 0.5), 'Lens': (0.05, 0.08, 0.1), 'Glow': (1, 0.2, 0.1),
    'Bore': (0.01, 0.01, 0.01), 'SightPaint': (0.8, 0.8, 0.7), 'HullRed': (0.45, 0.06, 0.05),
}


def render(gid, fbx, prims, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    gun = import_fbx(fbx)
    sc = bpy.context.scene
    mats = {}

    def mat(key):
        if key not in mats:
            m = bpy.data.materials.new(key)
            m.diffuse_color = (*PREVIEW_RGB.get(key, (0.2, 0.2, 0.2)), 1)
            mats[key] = m
        return mats[key]

    lo = np.min([m['verts'].min(axis=0) for m in gun.values()], axis=0)
    hi = np.max([m['verts'].max(axis=0) for m in gun.values()], axis=0)
    drop = (hi[2] - lo[2]) * 1.4
    for o in list(sc.objects):
        if o.type == 'MESH':
            if o.data.materials:
                for i, mm in enumerate(o.data.materials):
                    if mm is not None:
                        o.data.materials[i] = mat(MAT_PAINT.get(mm.name, 'SteelBlued'))
    for p in prims:
        if p['shape'] == 'Cyl':
            bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.5, depth=1)
            o = bpy.context.object
            # Blender cylinder axis Z -> piece axis e1
            # (Blender's cylinder axis is its local Z: local Z -> e1, local X -> e3)
            base = Matrix([list(p['axes'][r]) for r in range(3)])
            M = base @ Matrix(((0, 0, 1), (0, 1, 0), (1, 0, 0)))
            o.matrix_world = Matrix.Translation(Vector(p['centre']) + Vector((0, 0, -drop))) @ M.to_4x4() \
                @ Matrix.Diagonal((p['size'][2], p['size'][1], p['size'][0], 1))
        else:
            bpy.ops.mesh.primitive_cube_add(size=1)
            o = bpy.context.object
            base = Matrix([list(p['axes'][r]) for r in range(3)])
            o.matrix_world = Matrix.Translation(Vector(p['centre']) + Vector((0, 0, -drop))) @ base.to_4x4() \
                @ Matrix.Diagonal((p['size'][0], p['size'][1], p['size'][2], 1))
        o.data.materials.append(mat(p['paint']))
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.show_cavity = True
    sc.display.shading.show_object_outline = True
    sc.world = bpy.data.worlds.new('w') if sc.world is None else sc.world
    sc.display.shading.background_type = 'VIEWPORT'
    sc.render.film_transparent = False
    length = hi[0] - lo[0]
    sc.render.resolution_x = 1400
    sc.render.resolution_y = 900
    cam_data = bpy.data.cameras.new('cam')
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = max(length, (hi[2] - lo[2] + drop) * 1400 / 900) * 1.12
    cam = bpy.data.objects.new('cam', cam_data)
    sc.collection.objects.link(cam)
    sc.camera = cam
    mid = Vector(((lo[0] + hi[0]) / 2, 0, (lo[2] + hi[2]) / 2 - drop / 2))
    for view, direction in (('side', Vector((0, -1, 0))), ('q34', Vector((0.55, -0.75, 0.38)))):
        d = direction.normalized()
        cam.location = mid - d * 3
        cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(out_dir, '%s_%s.png' % (gid, view))
        bpy.ops.render.render(write_still=True)
    print('rendered', out_dir)


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument('guns', nargs='*', default=GUNS)
    ap.add_argument('--render', default=None)
    args = ap.parse_args(argv)
    for gid in args.guns or GUNS:
        export(gid, args.render)


if __name__ == '__main__':
    main()
