#!/usr/bin/env python3
"""check_model: enforce the gun model contract (docs/firearms/ARCHITECTURE.md §5) on the exported assets.

Run (Blender's Python, headless; `-I` isolates it):
    /home/user/z-anatomy/venv/bin/python -I tools/guns/check_model.py [Pistol Shotgun Rifle Sniper Lmg] [--json OUT]

It reads assets/guns/<Id>/<id>.markers.json and IMPORTS every FBX the JSON lists (the gun, the separate case /
round / mag / pouch models), so it checks what Roblox will get, not what the build script believes it wrote:

  * names: PascalCase, no `.001`, the FBX objects are exactly the JSON parts (MagFollower lives only in
    <Id>_MagEmpty.fbx), required parts (§5.2) present, fit parts 1-4 on the right parts (§5.7);
  * units / axes / rest: scales (1, 1, 1), the FBX bounding box equals the JSON length / height, the muzzle on
    the bore at the front of the gun, the magazine origin at MagWell;
  * hinges (§5.2 table + its amendments): type, axis and range of every moving part; groups (children);
  * markers (§5.3): present, orthonormal frames, conventions (ejection to the right, or down for the LMG;
    SightEye looking along +X behind the sights; GripR / GripL hand-to-elbow axes pointing back);
  * dimensions and mass within ±3 % of §5.6;
  * budgets (§5.1): ≤ 25 MeshParts; the whole gun FBX ≤ the ceiling (pistol 6 000, long guns 20 000: FAIL);
    the gun WITHOUT its detachable feed (magazine + top round, or pouch + belt) over the target 8 000 (pistol
    4 000, LMG 12 000) is a WARN (a decision for the player); the feed ≤ 1 200 (mag FBX) / the pouch + belt ≤ 2 400; case ≤ 150,
    round ≤ 200; every FBX mesh fully triangulated (no quads / n-gons: Roblox's tangents must match the bake);
  * textures: every atlas the gun uses has its 4 maps (Color, Normal, Roughness, Metalness), power-of-two
    square; texel density per atlas (px per metre) reported; uploaded ids in assets/guns/texture_ids.json
    are flagged STALE when the PNG no longer matches the uploaded file (assets/guns/texture_uploads.json keeps
    the git blob of each uploaded PNG).

Exit 1 when any FAIL.  WARN lines are reported but do not fail.  The score is passed checks / all checks.
"""
import argparse
import glob
import json
import math
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ASSETS = os.path.join(ROOT, 'assets', 'guns')
GUNS = ['Pistol', 'Shotgun', 'Rifle', 'Sniper', 'Lmg']

PAINTS = {'Polymer', 'SteelBlued', 'SteelPhosphate', 'SteelLacquer', 'SteelBare', 'Aluminium', 'Wood', 'Rubber',
          'Fabric', 'FabricTan', 'FabricCamo', 'Brass', 'Nickel', 'Lens', 'Glow', 'Reticle', 'Stamp'}

# §5.6 targets: length, barrel, height (None = not checked: the class height is "+ scope / + optic"), mass
TARGET = {
    'Pistol': dict(length=0.185, barrel=0.102, height=0.128, mass=0.85),
    'Shotgun': dict(length=0.98, barrel=0.47, height=0.20, mass=3.6),
    'Rifle': dict(length=0.88, barrel=0.415, height=0.255, mass=3.9),
    'Sniper': dict(length=1.23, barrel=0.686, height=None, mass=7.5),
    'Lmg': dict(length=0.89, barrel=0.35, height=0.28, mass=7.1 + 3.0),
}
# §5.1 (amended by the consistency pass): the TARGET is the performance aim for the gun without its feed (WARN
# above it); the CEILING is the modelling brief's hard limit for the whole gun FBX, feed included (FAIL above it)
GUN_BUDGET = {'Pistol': 4000, 'Shotgun': 8000, 'Rifle': 8000, 'Sniper': 8000, 'Lmg': 12000}
GUN_CEILING = {'Pistol': 6000, 'Shotgun': 20000, 'Rifle': 20000, 'Sniper': 20000, 'Lmg': 20000}

REQUIRED_PARTS = {
    'Pistol': ['Frame', 'Slide', 'Barrel', 'Magazine', 'MagRoundTop', 'Trigger', 'SightFront', 'SightRear',
               'SlideStop', 'MagRelease', 'Extractor'],
    'Shotgun': ['Receiver', 'Barrel', 'MagTube', 'MagCap', 'Trigger', 'Stock', 'Bolt', 'ChargingHandle',
                'BoltRelease', 'Lifter', 'Safety', 'Optic', 'OpticLens'],
    'Rifle': ['Receiver', 'Barrel', 'Magazine', 'MagRoundTop', 'Trigger', 'SightFront', 'SightRear', 'Stock',
              'PistolGrip', 'BoltCarrier', 'ChargingHandle', 'Selector', 'MagRelease'],
    'Sniper': ['Receiver', 'Barrel', 'Magazine', 'MagRoundTop', 'Trigger', 'Optic', 'OpticLens', 'Stock',
               'Bolt', 'BoltHandle', 'MagRelease', 'Safety', 'CheekPiece', 'ButtPad', 'BipodLegL', 'BipodLegR',
               'BipodExtL', 'BipodExtR'],
    'Lmg': ['Receiver', 'Barrel', 'AmmoPouch', 'Trigger', 'Optic', 'OpticLens', 'Stock', 'FeedCover', 'FeedTray',
            'ChargingHandle', 'BipodLegL', 'BipodLegR'] + ['Belt%02d' % i for i in range(1, 13)],
}
FIT = {
    'Pistol': {'Frame': 1, 'Barrel': 2, 'Trigger': 3, 'Magazine': 4},
    'Shotgun': {'Receiver': 1, 'Barrel': 2, 'Trigger': 3, 'MagTube': 4},
    'Rifle': {'Receiver': 1, 'Barrel': 2, 'Trigger': 3, 'Magazine': 4},
    'Sniper': {'Receiver': 1, 'Barrel': 2, 'Trigger': 3, 'Magazine': 4},
    'Lmg': {'Receiver': 1, 'Barrel': 2, 'Trigger': 3, 'AmmoPouch': 4},
}
# children that must move with their parent (§5.2)
GROUPS = {
    'Pistol': {'Slide': ['SightFront', 'SightRear', 'Extractor'], 'Magazine': ['MagRoundTop']},
    'Shotgun': {'Bolt': ['ChargingHandle'], 'Optic': ['OpticLens']},
    'Rifle': {'BoltCarrier': ['ChargingHandle'], 'Magazine': ['MagRoundTop']},
    'Sniper': {'Bolt': ['BoltHandle'], 'BipodLegL': ['BipodExtL'], 'BipodLegR': ['BipodExtR'],
               'Optic': ['OpticLens'], 'Magazine': ['MagRoundTop']},
    'Lmg': {'FeedCover': ['Optic'], 'Optic': ['OpticLens']},
}
# §5.2 hinges: (type, axis or None = read from the JSON (canted / leg axes), lo, hi)
Y, NY, X, NX, Z, NZ = (0, 1, 0), (0, -1, 0), (1, 0, 0), (-1, 0, 0), (0, 0, 1), (0, 0, -1)
HINGES = {
    'Pistol': {'Slide': ('slide', NX, 0, 0.028), 'Barrel': ('rotate', Y, -2.5, 0), 'Trigger': ('rotate', Y, 0, 10),
               'SlideStop': ('rotate', Y, -6, 0), 'MagRelease': ('slide', NY, 0, 0.003)},
    'Shotgun': {'Bolt': ('slide', NX, 0, 0.075), 'BoltRelease': ('slide', Y, 0, 0.003),
                'Lifter': ('rotate', NY, 0, 12), 'Trigger': ('rotate', Y, 0, 12), 'Safety': ('slide', X, 0, 0.005)},
    'Rifle': {'BoltCarrier': ('slide', NX, 0, 0.120), 'Selector': ('rotate', Y, 0, 20),
              'MagRelease': ('rotate', Y, -12, 0), 'Magazine': ('rotate', Y, -25, 0), 'Trigger': ('rotate', Y, 0, 14),
              # amendment (rifle): the AK leaf hinges at its FRONT, so raising the notch is POSITIVE
              'SightRear': ('rotate', Y, 0, 8)},
    'Sniper': {'Bolt': ('rotate', X, -60, 0), 'MagRelease': ('rotate', Y, -10, 0), 'Safety': ('rotate', Y, 0, 15),
               'CheekPiece': ('slide', Z, 0, 0.030), 'ButtPad': ('slide', NX, 0, 0.040),
               'BipodLegL': ('rotate', Y, 0, 90), 'BipodLegR': ('rotate', Y, 0, 90),
               'BipodExtL': ('slide', None, 0, 0.08), 'BipodExtR': ('slide', None, 0, 0.08),
               'Trigger': ('rotate', Y, 0, 8)},
    'Lmg': {'FeedCover': ('rotate', Y, 0, 70), 'FeedTray': ('rotate', Y, -20, 0),
            'ChargingHandle': ('slide', NX, 0, 0.140), 'Stock': ('slide', X, 0, 0.100),
            'BipodLegL': ('rotate', None, -90, 0), 'BipodLegR': ('rotate', None, -90, 0),
            'Trigger': ('rotate', Y, 0, 12)},
}
COMMON_MARKERS = ['Muzzle', 'EjectionPort', 'CasingSpawn', 'GripR', 'GripL', 'SightEye', 'CoM']
MARKERS = {
    'Pistol': COMMON_MARKERS + ['MagWell', 'HolsterMount', 'MagGrab', 'SlideGrip', 'SlideStop', 'MagRelease'],
    'Shotgun': COMMON_MARKERS + ['ShellPort', 'PortLoad', 'Shoulder', 'BackMount', 'ChargeHandle', 'BoltRelease'],
    'Rifle': COMMON_MARKERS + ['MagWell', 'MagRockPivot', 'Shoulder', 'BackMount', 'MagGrab', 'ChargeHandle',
                               'MagRelease'],
    'Sniper': COMMON_MARKERS + ['MagWell', 'Shoulder', 'BackMount', 'MagGrab', 'BoltKnob', 'MagRelease',
                                'BipodPivot', 'BipodFoot'],
    'Lmg': COMMON_MARKERS + ['PouchMount', 'FeedTrayEntry', 'LinkSpawn', 'Shoulder', 'BackMount', 'ChargeHandle',
                             'FeedCoverLatch', 'SlingFront', 'SlingRear', 'CarryHandle', 'BipodPivot', 'BipodFoot'],
}
# the detachable feed: excluded from the gun budget, counted against its own
FEED = {'Pistol': ['Magazine', 'MagRoundTop'], 'Rifle': ['Magazine', 'MagRoundTop'],
        'Sniper': ['Magazine', 'MagRoundTop'], 'Shotgun': [],
        'Lmg': ['AmmoPouch'] + ['Belt%02d' % i for i in range(1, 13)]}
# parts baked into a secondary atlas (all other parts use the <Id>_* atlas)
ATLAS_OF = {
    'Rifle': {n: 'Rifle_Wood' for n in ('Stock', 'PistolGrip', 'HandguardLower', 'HandguardUpper')},
    'Sniper': {n: 'Sniper_Stock' for n in ('Stock', 'CheekPiece', 'ButtPad', 'Monopod')},
    'Lmg': {'AmmoPouch': 'Lmg_Soft', **{'Belt%02d' % i: 'Lmg_Ammo' for i in range(1, 13)}},
}
SEPARATE_BUDGET = {'Case': 150, 'Round': 200, 'RoundGreen': 200, 'Mag': 1200, 'MagEmpty': 1200, 'Link': 200,
                   'Pouch': 1200, 'PouchEmpty': 1200, 'BeltSegment': 1200, 'Sling': 1200}
FBX_ONLY_ELSEWHERE = {'MagFollower'}   # lives in <Id>_MagEmpty.fbx, not in the gun FBX
NAME_RE = re.compile(r'^[A-Z][A-Za-z0-9]*$')
MAPS = ('Color', 'Normal', 'Roughness', 'Metalness')


class Report:
    def __init__(self, gid):
        self.gid = gid
        self.lines = []
        self.n = 0
        self.ok = 0
        self.fails = []
        self.warns = []
        self.info = {}

    def check(self, cond, what, detail=''):
        self.n += 1
        if cond:
            self.ok += 1
        else:
            self.fails.append(what + (': ' + detail if detail else ''))
        return cond

    def warn(self, what):
        self.warns.append(what)

    @property
    def score(self):
        return round(100.0 * self.ok / max(1, self.n), 1)


def vlen(v):
    return math.sqrt(sum(c * c for c in v))


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def near(a, b, tol):
    return abs(a - b) <= tol


def git_blob(path):
    try:
        return subprocess.run(['git', 'hash-object', path], cwd=ROOT, capture_output=True, text=True,
                              check=True).stdout.strip()
    except Exception:
        return None


# --------------------------------------------------------------------------------------------- FBX import
def import_fbx(path):
    """Import an FBX into an empty scene; {name: info} of its meshes (model space, metres)."""
    import bpy
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path, axis_forward='-Z', axis_up='Y')
    out = {}
    for o in bpy.context.scene.objects:
        if o.type != 'MESH':
            continue
        me = o.data
        me.calc_loop_triangles()
        ws = [o.matrix_world @ Vector(c) for c in o.bound_box]
        mn = [min(v[i] for v in ws) for i in range(3)]
        mx = [max(v[i] for v in ws) for i in range(3)]
        sc = o.matrix_world.to_scale()
        # texel data: 3D area and UV area per material image
        area3 = 0.0
        uv_area = 0.0
        uvl = me.uv_layers.active
        Mw = o.matrix_world
        for tri in me.loop_triangles:
            a, b, c = (Mw @ me.vertices[i].co for i in tri.vertices)
            area3 += (b - a).cross(c - a).length / 2
            if uvl:
                p, q_, r = (uvl.data[i].uv for i in tri.loops)
                uv_area += abs((q_.x - p.x) * (r.y - p.y) - (r.x - p.x) * (q_.y - p.y)) / 2
        out[o.name] = dict(tris=len(me.loop_triangles), maxpoly=max((len(p.vertices) for p in me.polygons), default=0),
                           nonTri=sum(1 for p in me.polygons if len(p.vertices) > 3), bmin=mn, bmax=mx,
                           scale=[round(s, 4) for s in sc], area3=area3, uvArea=uv_area,
                           uvs=len(me.uv_layers), parent=o.parent.name if o.parent else None)
    # the exporter keeps parents' scale 1 at metres (FBX_SCALE_UNITS); sanity: no stray empties as roots
    return out


def bbox(infos, names=None):
    names = names or list(infos)
    mn = [min(infos[n]['bmin'][i] for n in names) for i in range(3)]
    mx = [max(infos[n]['bmax'][i] for n in names) for i in range(3)]
    return mn, mx


# --------------------------------------------------------------------------------------------- the checks
def check_gun(gid, with_fbx=True):
    R = Report(gid)
    low = gid.lower()
    jpath = os.path.join(ASSETS, gid, low + '.markers.json')
    if not R.check(os.path.exists(jpath), 'markers JSON exists', jpath):
        return R
    J = json.load(open(jpath))
    parts, hinges, markers = J['parts'], J.get('hinges', {}), J['markers']
    R.check(J.get('id') == gid, 'JSON id', str(J.get('id')))
    R.check(J.get('units') == 'm', 'units = m')
    R.check(J.get('axes') == '+X muzzle, +Y left, +Z up', 'axes string')

    # ---- names and parts
    for n in parts:
        R.check(bool(NAME_RE.match(n)), 'PascalCase part name', n)
        paint = parts[n].get('paint')
        if paint not in PAINTS:
            R.warn('part %s paint %r is not a listed paint key' % (n, paint))
    for n in REQUIRED_PARTS[gid]:
        R.check(n in parts, 'required part', n)
    fits = {n: p.get('fit') for n, p in parts.items() if p.get('fit')}
    for n, k in FIT[gid].items():
        R.check(fits.get(n) == k, 'fit part %d' % k, '%s has fit %s' % (n, fits.get(n)))
    for parent, kids in GROUPS[gid].items():
        for k in kids:
            R.check(parts.get(k, {}).get('parent') == parent, 'group %s > %s' % (parent, k),
                    'parent is %s' % parts.get(k, {}).get('parent'))

    # ---- hinges
    for n, (kind, axis, lo, hi) in HINGES[gid].items():
        h = hinges.get(n)
        if not R.check(h is not None, 'hinge present', n):
            continue
        R.check(h['type'] == kind, 'hinge %s type' % n, '%s != %s' % (h['type'], kind))
        ax = h['axis']
        R.check(near(vlen(ax), 1.0, 1e-3), 'hinge %s axis unit' % n, str(ax))
        if axis is not None:
            R.check(dot(ax, axis) > 0.999, 'hinge %s axis' % n, '%s != %s' % (ax, axis))
        tol = 1e-4 if kind == 'slide' else 0.05
        R.check(near(min(h['min'], h['max']), lo, tol) and near(max(h['min'], h['max']), hi, tol),
                'hinge %s range' % n, '[%s, %s] != [%s, %s]' % (h['min'], h['max'], lo, hi))
        R.check(h['min'] <= h.get('rest', 0) <= h['max'], 'hinge %s rest in range' % n)
        if 'pivot' in h and n in parts and h['type'] == 'rotate' and n != 'Magazine':
            o = parts[n]['origin']
            R.check(vlen([a - b for a, b in zip(h['pivot'], o)]) < 1e-4, 'hinge %s pivot = part origin' % n,
                    '%s vs %s' % (h['pivot'], o))

    # ---- markers
    for m in MARKERS[gid]:
        R.check(m in markers, 'marker present', m)
    for m, f in markers.items():
        x, z = f['x'], f['z']
        R.check(near(vlen(x), 1, 2e-3) and near(vlen(z), 1, 2e-3) and abs(dot(x, z)) < 2e-3,
                'marker %s orthonormal' % m, 'x=%s z=%s' % (x, z))
    if 'Muzzle' in markers:
        mz = markers['Muzzle']
        R.check(abs(mz['p'][1]) < 1e-4 and abs(mz['p'][2]) < 1e-4 and dot(mz['x'], X) > 0.9999,
                'Muzzle on the bore, +X forward', str(mz))
    if 'EjectionPort' in markers:
        ex = markers['EjectionPort']['x']
        if gid == 'Lmg':
            R.check(ex[2] < -0.5 and ex[1] < 0, 'EjectionPort +X down and right (bottom port)', str(ex))
        else:
            R.check(ex[1] < -0.5, 'EjectionPort +X to the right (-Y)', str(ex))
        cs = markers.get('CasingSpawn')
        if cs:
            d = vlen([a - b for a, b in zip(cs['p'], markers['EjectionPort']['p'])])
            R.check(d < 0.045, 'CasingSpawn within 45 mm of the port (a .338 case is 69 mm long)', '%.3f m' % d)
    if 'SightEye' in markers:
        se = markers['SightEye']
        R.check(dot(se['x'], X) > 0.9995, 'SightEye +X along the bore (converging)', str(se['x']))
        R.check(abs(se['p'][1]) < 1e-3 and se['p'][2] > 0, 'SightEye centred above the bore', str(se['p']))
        R.check(se['p'][0] < markers['GripR']['p'][0] + 0.05 if 'GripR' in markers else True,
                'SightEye behind the grip', str(se['p']))
    for g in ('GripR', 'GripL'):
        if g in markers:
            z = markers[g]['z']
            R.check(z[0] < 0, '%s +Z (hand to elbow) points back' % g, str(z))
            if g == 'GripR':
                R.check(z[2] < 0.2, 'GripR +Z not up', str(z))
            else:
                R.check(z[1] > 0.2, 'GripL +Z to the left (support side)', str(z))
    if 'MagWell' in markers and 'Magazine' in parts:
        o = parts['Magazine']['origin']
        R.check(vlen([a - b for a, b in zip(o, markers['MagWell']['p'])]) < 1e-4, 'Magazine origin = MagWell',
                '%s vs %s' % (o, markers['MagWell']['p']))
    if 'Shoulder' in markers:
        R.check(dot(markers['Shoulder']['x'], X) > 0.999, 'Shoulder +X forward')

    # ---- dimensions and mass (§5.6)
    T = TARGET[gid]
    dims = J.get('dims', {})
    for k in ('length', 'barrel', 'height'):
        if T.get(k) is None:
            continue
        v = dims.get(k)
        R.check(v is not None and abs(v / T[k] - 1) <= 0.03, 'dim %s within 3 %%' % k, '%s vs %s' % (v, T[k]))
    R.check(abs(J.get('massKg', 0) / T['mass'] - 1) <= 0.03, 'mass within 3 %', '%s vs %s' % (J.get('massKg'), T['mass']))

    # ---- separate models listed
    sep = J.get('separate', {})
    for k in ('Case', 'Round'):
        R.check(k in sep, 'separate %s listed' % k)
    if 'Magazine' in parts:
        R.check('Mag' in sep and 'MagEmpty' in sep, 'separate Mag + MagEmpty listed')
        R.check('Magazine' in J.get('colliders', {}), 'Magazine collider + mass')
    if gid == 'Lmg':
        for k in ('Pouch', 'PouchEmpty', 'Link', 'BeltSegment'):
            R.check(k in sep, 'separate %s listed' % k)
        R.check('AmmoPouch' in J.get('colliders', {}), 'AmmoPouch collider + mass')

    R.info['parts'] = len([n for n in parts if n not in FBX_ONLY_ELSEWHERE])
    if not with_fbx:
        return R

    # ---- the gun FBX
    fpath = os.path.join(ASSETS, gid, gid + '.fbx')
    if not R.check(os.path.exists(fpath), 'gun FBX exists'):
        return R
    F = import_fbx(fpath)
    names = set(F)
    expect = {n for n in parts if n not in FBX_ONLY_ELSEWHERE}
    R.check(names == expect, 'FBX objects = JSON parts',
            'missing %s, extra %s' % (sorted(expect - names), sorted(names - expect)))
    for n, inf in F.items():
        R.check('.' not in n, 'FBX name without suffix', n)
        R.check(all(near(s, 1.0, 1e-3) for s in inf['scale']), 'FBX %s scale 1' % n, str(inf['scale']))
        R.check(inf['nonTri'] == 0, 'FBX %s triangulated' % n, '%d quads/n-gons (max %d sides)'
                % (inf['nonTri'], inf['maxpoly']))
        R.check(inf['uvs'] >= 1, 'FBX %s has UVs' % n)
        jt = parts.get(n, {}).get('tris')
        if jt is not None:
            R.check(jt == inf['tris'], 'FBX %s tris = JSON' % n, '%d vs %d' % (inf['tris'], jt))
    R.check(len(F) <= 25, '<= 25 MeshParts', str(len(F)))
    feed = [n for n in FEED[gid] if n in F]
    tri_all = sum(i['tris'] for i in F.values())
    tri_gun = sum(i['tris'] for n, i in F.items() if n not in feed)
    tri_feed = sum(F[n]['tris'] for n in feed)
    R.info.update(meshParts=len(F), trisFbx=tri_all, trisGun=tri_gun, trisFeed=tri_feed, target=GUN_BUDGET[gid],
                  ceiling=GUN_CEILING[gid])
    R.check(tri_all <= GUN_CEILING[gid], 'gun FBX triangles <= ceiling %d' % GUN_CEILING[gid], str(tri_all))
    if tri_gun > GUN_BUDGET[gid]:
        R.warn('gun triangles without the feed %d are over the target %d (+%d %%): a decision for the player '
               '(ARCHITECTURE §5.1)' % (tri_gun, GUN_BUDGET[gid], round(100.0 * tri_gun / GUN_BUDGET[gid] - 100)))
    if gid == 'Lmg':
        R.check(tri_feed <= 2400, 'pouch + belt <= 2400', str(tri_feed))
    elif feed:
        R.check(tri_feed <= 1200, 'magazine + top round <= 1200', str(tri_feed))
    # bounding box vs dims (the JSON numbers must describe the FBX)
    body = [n for n in F if not (gid == 'Lmg' and (n in FEED['Lmg'] or n in ('Optic', 'OpticLens')))]
    mn, mx = bbox(F, body)
    R.check(near(mx[0] - mn[0], dims.get('length', 0), 0.002), 'FBX length = dims.length',
            '%.4f vs %s' % (mx[0] - mn[0], dims.get('length')))
    if 'height' in dims:
        R.check(near(mx[2] - mn[2], dims['height'], 0.002), 'FBX height = dims.height',
                '%.4f vs %s' % (mx[2] - mn[2], dims['height']))
    if 'Muzzle' in markers:
        R.check(near(markers['Muzzle']['p'][0], mx[0], 0.006), 'Muzzle at the front of the FBX',
                'muzzle x %.4f, front %.4f' % (markers['Muzzle']['p'][0], mx[0]))
    R.info['bbox'] = [round(mx[i] - mn[i], 4) for i in range(3)]

    # ---- separate FBX files
    for k, fn in sep.items():
        p = os.path.join(ASSETS, gid, fn)
        if not R.check(os.path.exists(p), 'separate %s exists' % fn):
            continue
        S = import_fbx(p)
        t = sum(i['tris'] for i in S.values())
        R.info['sep_' + k] = t
        lim = SEPARATE_BUDGET.get(k)
        if lim:
            R.check(t <= lim, 'separate %s tris <= %d' % (k, lim), str(t))
        for n, inf in S.items():
            R.check('.' not in n, 'separate name without suffix', n)
            R.check(inf['nonTri'] == 0, 'separate %s triangulated' % n, '%d quads/n-gons' % inf['nonTri'])

    # ---- textures and texel density
    prefixes = sorted({os.path.basename(p)[:-len('_Color.png')]
                       for p in glob.glob(os.path.join(ASSETS, gid, '*_Color.png'))})
    ids = {}
    up = {}
    try:
        ids = json.load(open(os.path.join(ASSETS, 'texture_ids.json')))
        up = json.load(open(os.path.join(ASSETS, 'texture_uploads.json')))
    except Exception:
        pass
    stale = []
    sizes = {}
    for pre in prefixes:
        for m in MAPS:
            p = os.path.join(ASSETS, gid, '%s_%s.png' % (pre, m))
            if not R.check(os.path.exists(p), 'map %s_%s.png' % (pre, m)):
                continue
            w, h = png_size(p)
            sizes[pre] = w
            R.check(w == h and w & (w - 1) == 0, 'map %s_%s square power of two' % (pre, m), '%dx%d' % (w, h))
            key = '%s_%s' % (pre, m)
            if key in ids and ids[key]:
                if key in up and up[key] != git_blob(p):
                    stale.append(key)
            else:
                R.warn('no uploaded id for %s' % key)
    R.info['atlases'] = sizes
    R.info['staleIds'] = stale
    if stale:
        R.warn('%d uploaded texture ids are STALE (PNG changed since upload): re-upload %s'
               % (len(stale), ', '.join(stale)))
    # texel density of the gun atlas(es): px per metre = res * sqrt(uvArea / area3), per part, median per atlas
    atl = ATLAS_OF.get(gid, {})
    dens = {}
    for n, inf in F.items():
        pre = atl.get(n) or gid
        res = sizes.get(pre)
        if not res or inf['area3'] <= 0 or inf['uvArea'] <= 0:
            continue
        dens.setdefault(pre, []).append(res * math.sqrt(inf['uvArea'] / inf['area3']))
    R.info['texelDensity'] = {k: round(sorted(v)[len(v) // 2]) for k, v in dens.items()}
    return R


def png_size(path):
    with open(path, 'rb') as f:
        head = f.read(24)
    return int.from_bytes(head[16:20], 'big'), int.from_bytes(head[20:24], 'big')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('guns', nargs='*', default=GUNS)
    ap.add_argument('--json', default='')
    ap.add_argument('--no-fbx', action='store_true', help='JSON checks only (no Blender needed)')
    ap.add_argument('--assets', default='', help='another assets root holding <Id>/ folders (scratch builds)')
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    args = ap.parse_args(argv)
    if args.assets:
        global ASSETS
        ASSETS = os.path.abspath(args.assets)
    out = {}
    bad = False
    for gid in args.guns:
        R = check_gun(gid, with_fbx=not args.no_fbx)
        bad = bad or bool(R.fails)
        print('==== %s: %d/%d checks (score %.1f), %d FAIL, %d WARN' % (gid, R.ok, R.n, R.score, len(R.fails),
                                                                       len(R.warns)))
        print('     ' + json.dumps(R.info))
        for f in R.fails:
            print('  FAIL', f)
        for w in R.warns:
            print('  WARN', w)
        out[gid] = dict(score=R.score, checks=R.n, passed=R.ok, fails=R.fails, warns=R.warns, **R.info)
    if args.json:
        with open(args.json, 'w') as f:
            json.dump(out, f, indent=1)
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
