#!/usr/bin/env python3
"""overview: one picture of the five guns side by side, from the EXPORTED assets (what Roblox will import).

Top: the five right-side profiles TO SCALE (1 000 px per metre; the same window for every gun, the model origin
= the breech face on the dashed line), with the baked atlases on (the SurfaceAppearance look) and a 1 m ruler.
Bottom: each gun's solved R6 `Aim` hold (tools/guns/<gun>_holds.json), 3/4 front-right orthographic, the same
window and scale for the five, a 1 m ruler.  Labels: length, triangles (gun / feed), MeshParts, mass, and the check_model score when a
check JSON is given.

Run (Blender's Python, headless):
    /home/user/z-anatomy/venv/bin/python -I tools/guns/overview.py --out OUT.png [--small docs/firearms/overview.png]
        [--check check.json] [--samples 24]
"""
import argparse
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Matrix  # noqa: E402

import gunkit as gk  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ASSETS = os.path.join(ROOT, 'assets', 'guns')
GUNS = [('Pistol', 'pistol', 'Pistol 9 mm compact'), ('Shotgun', 'shotgun', 'Shotgun 12 ga semi-auto'),
        ('Rifle', 'rifle_ak', 'Rifle 7.62x39 (AK, wood)'), ('Sniper', 'sniper', 'Sniper .338 bolt-action'),
        ('Lmg', 'lmg', 'LMG 5.56 belt-fed')]
ATLAS_OF = {
    'Rifle': {n: 'Rifle_Wood' for n in ('Stock', 'PistolGrip', 'HandguardLower', 'HandguardUpper')},
    'Sniper': {n: 'Sniper_Stock' for n in ('Stock', 'CheekPiece', 'ButtPad', 'Monopod')},
    'Lmg': {'AmmoPouch': 'Lmg_Soft', **{'Belt%02d' % i: 'Lmg_Ammo' for i in range(1, 13)}},
}
PXM = 1000                         # px per metre of the profile band
WIN_X = (-0.56, 0.84)              # model-space window of every profile (breech face at x = 0)
WIN_Z = (-0.25, 0.17)
HOLD_PXM = 250
HOLD_X = (-0.55, 1.30)             # Blender world window of every hold (HRP at the origin, facing +X)
HOLD_Z = (-0.92, 0.70)


def load_gun(gid, col):
    """Import <Id>.fbx, put the baked SurfaceAppearance-like materials on, parent the roots to an empty."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(ASSETS, gid, gid + '.fbx'), axis_forward='-Z', axis_up='Y')
    objs = [o for o in bpy.data.objects if o not in before]
    mats = {}
    for o in objs:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        col.objects.link(o)
        if o.type != 'MESH':
            continue
        pre = ATLAS_OF.get(gid, {}).get(o.name.split('.')[0], gid)   # 'Stock.001': the names repeat across guns
        if pre not in mats:
            paths = {k: os.path.join(ASSETS, gid, '%s_%s.png' % (pre, k)) for k in ('Color', 'Normal', 'Roughness',
                                                                                  'Metalness')}
            mats[pre] = gk.baked_material('OV_' + pre, paths)
        o.data.materials.clear()
        o.data.materials.append(mats[pre])
    root = bpy.data.objects.new('Root_' + gid, None)
    col.objects.link(root)
    for o in objs:
        if o.parent is None:
            o.parent = root
            o.matrix_parent_inverse = Matrix()
    bpy.context.view_layer.update()
    return root, objs


def cframe_np(c):
    import numpy as np
    M = np.eye(4)
    M[0, 3], M[1, 3], M[2, 3] = c[0], c[1], c[2]
    M[:3, :3] = np.array(c[3:12]).reshape(3, 3)
    return M


def set_window(rig, x0, x1, z0, z1, pxm, view=(0, -1, 0)):
    sc = bpy.context.scene
    sc.render.resolution_x = int(round((x1 - x0) * pxm))
    sc.render.resolution_y = int(round((z1 - z0) * pxm))
    lo, hi = (x0, -0.3, z0), (x1, 0.3, z1)
    rig.frame((lo, hi), view, ortho=True, margin=1.0, ortho_scale=x1 - x0,
              target=((x0 + x1) / 2, 0, (z0 + z1) / 2))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--small', default='')
    ap.add_argument('--check', default='')
    ap.add_argument('--samples', type=int, default=24)
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    args = ap.parse_args(argv)
    tmp = os.path.join(os.path.dirname(os.path.abspath(args.out)), 'overview_parts')
    os.makedirs(tmp, exist_ok=True)

    gk.reset_scene()
    gk.build_materials()
    gk.setup_render(args.samples, (1400, 420), transparent=True, exposure=-0.2)
    studio = bpy.data.collections.new('Studio')
    bpy.context.scene.collection.children.link(studio)
    rig = gk.Rig(studio)
    cols = {}
    roots = {}
    for gid, _, _ in GUNS:
        c = bpy.data.collections.new('G_' + gid)
        bpy.context.scene.collection.children.link(c)
        cols[gid] = c
        roots[gid], _ = load_gun(gid, c)

    def only(gid, r6=None):
        for g, c in cols.items():
            c.hide_render = g != gid
        for o in bpy.data.objects:
            if o.name.startswith('R6_'):
                o.hide_render = r6 is None or not o.name.startswith('R6_%s_' % r6)

    files = {}
    # profiles: gun at identity (model space = world), camera on its right side
    for gid, _, _ in GUNS:
        only(gid)
        roots[gid].matrix_world = Matrix()
        bpy.context.view_layer.update()
        set_window(rig, WIN_X[0], WIN_X[1], WIN_Z[0], WIN_Z[1], PXM)
        rig.mult = 0.9
        rig.place_lights(gk.V((0.14, 0, -0.04)), 1.6)
        files['side_' + gid] = gk.render(os.path.join(tmp, 'side_%s.png' % gid))
    # the solved Aim holds
    holds = {}
    for gid, stem, _ in GUNS:
        H = json.load(open(os.path.join(HERE, stem + '_holds.json')))
        st = H['stances']['Aim']
        holds[gid] = st
        frames = gk.r6_frames({k: tuple(v) for k, v in st['pose'].items()})
        obs = gk.build_r6(cols[gid], frames, name='R6_%s_' % gid)
        for o in obs:
            o.name = 'R6_%s_%s' % (gid, o.name.split('_')[-1])
        gk.place_gun(roots[gid], cframe_np(st['gunInHRP']))
    for gid, _, _ in GUNS:
        only(gid, r6=gid)
        # 3/4 front-right, orthographic (the same scale for the five): a pure side view hides the pistol
        # behind the right arm block
        set_window(rig, HOLD_X[0], HOLD_X[1], HOLD_Z[0], HOLD_Z[1], HOLD_PXM, view=(0.62, -0.75, 0.22))
        rig.mult = 1.0
        rig.place_lights(gk.V((0.3, 0, -0.1)), 3.2)
        files['hold_' + gid] = gk.render(os.path.join(tmp, 'hold_%s.png' % gid))
    compose(args, files, holds)


def compose(args, files, holds):
    from PIL import Image, ImageDraw
    chk = json.load(open(args.check)) if args.check and os.path.exists(args.check) else {}
    side_w = int(round((WIN_X[1] - WIN_X[0]) * PXM))
    side_h = int(round((WIN_Z[1] - WIN_Z[0]) * PXM))
    hold_w = int(round((HOLD_X[1] - HOLD_X[0]) * HOLD_PXM))
    hold_h = int(round((HOLD_Z[1] - HOLD_Z[0]) * HOLD_PXM))
    label_w = 560
    W = max(label_w + side_w + 40, hold_w * 5 + 40)
    title_h, ruler_h = 70, 90
    H = title_h + side_h * 5 + ruler_h + 60 + hold_h + 80
    bg = (16, 16, 18)
    img = Image.new('RGB', (W, H), bg)
    d = ImageDraw.Draw(img)
    f_t, f_b, f_s = gk.font(30, True), gk.font(24, True), gk.font(19)
    d.text((24, 18), 'Realistic Battleground: the five guns to scale (exported FBX + baked atlases)', font=f_t,
           fill=(232, 226, 214))
    x0 = label_w
    breech_px = x0 + int(round((0 - WIN_X[0]) * PXM))
    y = title_h
    for gid, stem, name in GUNS:
        J = json.load(open(os.path.join(ASSETS, gid, gid.lower() + '.markers.json')))
        sh = Image.open(files['side_' + gid]).convert('RGBA')
        # light band behind each gun so dark steel reads
        d.rectangle((x0, y + 2, x0 + side_w, y + side_h - 2), fill=(44, 44, 48))
        img.paste(sh, (x0, y), sh)
        c = chk.get(gid, {})
        tg = c.get('trisGun', J.get('tris', {}).get('gunFbx'))
        tf = c.get('trisFeed')
        lines = [name,
                 'length %d mm, barrel %d mm, %.2f kg' % (round(J['dims']['length'] * 1000),
                                                          round(J['dims']['barrel'] * 1000), J['massKg']),
                 'tris %s gun%s, %s MeshParts' % (tg, ' + %s feed' % tf if tf else '', c.get('meshParts', len(J['parts']))),
                 ]
        if c:
            lines.append('check_model %d/%d (%.0f %%)' % (c['passed'], c['checks'], c['score']))
        for i, t in enumerate(lines):
            d.text((24, y + 40 + i * 30), t, font=f_b if i == 0 else f_s,
                   fill=(232, 226, 214) if i == 0 else (180, 176, 168))
        y += side_h
    # breech-face line and the 1 m ruler (same scale as the profiles)
    for yy in range(title_h, y, 14):
        d.line((breech_px, yy, breech_px, yy + 7), fill=(200, 120, 60), width=2)
    d.text((breech_px + 6, title_h + 4), 'breech face (model origin)', font=f_s, fill=(200, 120, 60))
    ry = y + 30
    rx0 = x0 + int(round((-0.50 - WIN_X[0]) * PXM))
    d.line((rx0, ry, rx0 + PXM, ry), fill=(230, 230, 230), width=3)
    for k in range(11):
        xx = rx0 + k * PXM // 10
        d.line((xx, ry - (16 if k % 5 == 0 else 9), xx, ry), fill=(230, 230, 230), width=2)
    d.text((rx0, ry + 8), '0', font=f_s, fill=(230, 230, 230))
    d.text((rx0 + PXM - 30, ry + 8), '1 m', font=f_s, fill=(230, 230, 230))
    d.text((24, ry - 10), 'profiles: 1 000 px = 1 m', font=f_s, fill=(180, 176, 168))
    # holds row
    y = ry + ruler_h
    d.text((24, y - 34), 'Solved R6 Aim holds (3/4 front-right, orthographic; the same scale for the five)', font=f_b,
           fill=(232, 226, 214))
    for i, (gid, stem, name) in enumerate(GUNS):
        hx = 20 + i * hold_w
        d.rectangle((hx + 4, y, hx + hold_w - 4, y + hold_h), fill=(40, 40, 44))
        hi_ = Image.open(files['hold_' + gid]).convert('RGBA')
        img.paste(hi_, (hx, y), hi_)
        r = holds[gid].get('residuals', {})
        cant = r.get('cantDeg')
        t2 = 'eye-line %s st, wrist %s deg%s' % (r.get('eyeToSightLine', '-'), r.get('wristDeg', '-'),
                                                ', cant %s' % cant if cant is not None else '')
        d.text((hx + 10, y + 6), gid, font=f_b, fill=(232, 226, 214))
        d.text((hx + 10, y + hold_h + 6), t2, font=gk.font(16), fill=(180, 176, 168))
    # 1 m ruler of the holds
    ry = y + hold_h + 50
    rx0 = 20
    d.line((rx0, ry, rx0 + HOLD_PXM, ry), fill=(230, 230, 230), width=3)
    for k in range(11):
        xx = rx0 + k * HOLD_PXM // 10
        d.line((xx, ry - (12 if k % 5 == 0 else 6), xx, ry), fill=(230, 230, 230), width=2)
    d.text((rx0 + HOLD_PXM + 10, ry - 12), '1 m in the view plane (holds: 250 px = 1 m; R6 1 stud = 0.28 m)', font=f_s,
           fill=(230, 230, 230))
    img.save(args.out)
    print('overview', args.out, img.size, flush=True)
    if args.small:
        s = img.copy()
        s.thumbnail((1400, 1400))
        os.makedirs(os.path.dirname(os.path.abspath(args.small)), exist_ok=True)
        s.convert('P', palette=Image.ADAPTIVE, colors=192).save(args.small, optimize=True)
        print('overview small', args.small, s.size, os.path.getsize(args.small), flush=True)


if __name__ == '__main__':
    main()
