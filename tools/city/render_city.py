"""render_city: renders the WHOLE city as the game builds it, with Blender Cycles (CPU, 2 threads):
CityData + AlleyData merged like City/init.luau, then the CityOverlay applied exactly like
applyOverlay (tools/city/overlay/apply.py), then PropKit simulated (--mode kit) or not
(--mode fallback), and the signs' SurfaceGui text drawn on their faces (PIL, see below).

    venv/bin/python -I tools/city/render_city.py --cams kitchen_door,duffys --out /tmp/r
    venv/bin/python -I tools/city/render_city.py --cam 0,60,120:0,0,0 --night --out /tmp/r
    venv/bin/python -I tools/city/render_city.py --list
    options: --mode kit|fallback, --night, --samples 12, --size 880x550, --fov 70,
             --region x0,x1,z0,z1 (only parts whose centre is inside: faster), --no-overlay,
             --no-signs

Writes <out>/<cam>_<mode>_<day|night>.png. LOOK at every image. The alleys' named cameras
(render_alleys.py) are here too, as alley_<name>.

SIGNS: every part with a sign ("g" in its extra) gets a plane on that face showing what
City/init.luau addSign builds: a TextLabel filling the face, TextScaled (the biggest integer size
<= 100 px, or <= maxSize, >= minSize, whose word-wrapped lines fit), inside the UIPadding
(pad), aligned (xalign / yalign), drawn at the SurfaceGui's real resolution (face size x pps,
default 25 px per stud) then magnified: a low pps looks as blurry as in the game. Fonts:
tools/city/fonts (Google Fonts; Libre Bodoni stands in for Bodoni, Arimo for Arial / Gotham).
Lit signs glow (Ambience: Brightness 0.7 by day, 2.5 at night). Signs on parts PropKit retires
(under a swapped MeshProp marker) are hidden, like PropKit.hideSkin.

Coordinates are Roblox studs (X east, Y up, Z south); Blender gets (x, -z, y).
"""

import argparse
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "kit"))

import render_alleys as RA  # noqa: E402  (load_kit, add_ambient, cameras)
from overlay import apply as overlay_apply  # noqa: E402
from overlay import citydata as C  # noqa: E402
from overlay.core import FACES, rotm  # noqa: E402

FONT_DIR = os.path.join(HERE, "fonts")
FONTS = {"Oswald": "Oswald.ttf", "Arimo": "Arimo.ttf", "Arial": "Arimo.ttf", "Gotham": "Arimo.ttf",
         "GothamBold": "Arimo.ttf", "SourceSans": "Arimo.ttf", "PermanentMarker": "PermanentMarker-Regular.ttf",
         "Kalam": "Kalam-Regular.ttf", "SpecialElite": "SpecialElite-Regular.ttf",
         "Fondamento": "Fondamento-Regular.ttf", "Bodoni": "LibreBodoni.ttf"}
FALLBACK_FONTS = ("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
                  "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")

# Named cameras: (eye, look-at, horizontal fov[, cut]) like render_alleys (negative fov: plan).
CITY_CAMS = {
    "overview": ((0, 170, 250), (0, 0, 0), 60),
    "plan": ((0, 400, 0), (0, 0, -0.01), -440),
    "crossroads": ((0, 6.5, -40), (0, 4, -80), 72),
    "duffys": ((72, 6.3, -34), (66, 6.5, -17), 70),
    "rewind": ((-56, 6.3, -32), (-56, 6.2, -16), 70),
    "threadbare": ((-44, 6.3, -56), (-44, 6.0, -72), 72),
    "cage": ((-86, 8, 98), (-86, 11.5, 118.8), 70),
    "kitchen_door": ((151.6, 6.6, 64.5), (151.6, 6.4, 58.4), 58),
    "park": ((-150, 9, 112), (-176, 4, 126), 72),
    "viaduct": ((0, 6.5, 60), (40, 18, 85), 72),
    "kiosk": ((112, 6.3, -62), (124, 4.5, -40), 70),
}
CAMS = {**CITY_CAMS, **{f"alley_{k}": v for k, v in RA.CAMS.items()}}


# ------------------------------------------------------------------------------ the data
def city_data(overlay=True):
    """The merged city with the CityOverlay applied (what the game builds)."""
    data = C.merged()
    stats = None
    if overlay:
        stats = overlay_apply.apply(data, C.load("CityOverlay"))
        print(f"[CityOverlay] {stats['applied']} entries applied, {stats['skipped']} skipped")
    return data, stats


# ------------------------------------------------------------------------------ signs (PIL)
_font_cache = {}


def font(name, px):
    key = (name, px)
    if key not in _font_cache:
        from PIL import ImageFont

        path = os.path.join(FONT_DIR, FONTS.get(name, "Arimo.ttf"))
        if not os.path.exists(path):
            path = next((p for p in FALLBACK_FONTS if os.path.exists(p)), None)
        _font_cache[key] = ImageFont.truetype(path, px) if path else ImageFont.load_default()
    return _font_cache[key]


def wrap(text, fnt, max_w):
    lines = []
    for para in text.split("\n"):
        cur = ""
        for word in para.split(" "):
            t = f"{cur} {word}" if cur else word
            if not cur or fnt.getlength(t) <= max_w:
                cur = t
            else:
                lines.append(cur)
                cur = word
        lines.append(cur)
    return lines


def text_scaled(text, font_name, w, h, max_size=100, min_size=1):
    """Roblox TextScaled: the biggest size whose wrapped lines fit (w, h) px (line height = size)."""
    top = int(max(1, min(100, max_size)))
    for s in range(top, 0, -1):
        f = font(font_name, s)
        lines = wrap(text, f, w)
        if len(lines) * s <= h and all(f.getlength(ln) <= w for ln in lines):
            return max(s, int(min_size)), lines
    s = max(1, int(min_size))
    return s, wrap(text, font(font_name, s), w)


def strip_rich(text):
    import re

    return re.sub(r"<[^>]+>", "", text)


def rich_alpha(text):
    """(plain text, [alpha factor per character]): RichText <font transparency="t"> runs (a dead
    neon letter); other tags are dropped."""
    import re

    plain, alphas, stack = [], [], [1.0]
    for tok in re.split(r"(<[^>]+>)", text):
        if tok.startswith("<"):
            m = re.match(r'<font[^>]*transparency="([0-9.]+)"', tok)
            if m:
                stack.append(stack[-1] * (1 - float(m.group(1))))
            elif tok.startswith("</font"):
                if len(stack) > 1:
                    stack.pop()
            continue
        plain.append(tok)
        alphas.extend([stack[-1]] * len(tok))
    return "".join(plain), alphas


def sign_image(g, face_w, face_h, magnify=4, max_tex=2048):
    """The sign's canvas (RGBA, PIL), drawn at the game's resolution then magnified."""
    from PIL import Image, ImageDraw

    pps = float(g.get("pps") or 25)
    W, H = max(1, round(face_w * pps)), max(1, round(face_h * pps))
    pad = g.get("pad") or 0
    px, py = (pad, pad) if isinstance(pad, (int, float)) else (pad[0], pad[1])
    iw, ih = W * (1 - 2 * px), H * (1 - 2 * py)
    text = g.get("text") or ""
    alphas = None
    if g.get("rich"):
        text, alphas = rich_alpha(text)
    size, lines = text_scaled(text, g.get("font", "Oswald"), max(1, iw), max(1, ih),
                             g.get("maxSize", 100), g.get("minSize", 1))
    bg = g.get("bg")
    bg_tr = g.get("bg_tr", 1)
    fill_bg = (0, 0, 0, 0)
    if bg and bg_tr is not None and bg_tr < 1:
        fill_bg = tuple(bg) + (int(255 * (1 - bg_tr)),)
    img = Image.new("RGBA", (W, H), fill_bg)
    draw = ImageDraw.Draw(img)
    f = font(g.get("font", "Oswald"), size)
    alpha = int(255 * (1 - float(g.get("textTr", 0))))
    color = tuple(g.get("color", (255, 255, 255))) + (alpha,)
    stroke = g.get("stroke")
    total = len(lines) * size
    ya = g.get("yalign", "Center")
    y0 = H * py + (0 if ya == "Top" else (ih - total) if ya == "Bottom" else (ih - total) / 2)
    xa = g.get("xalign", "Center")
    pos = 0  # (index into the plain text: the per-character alpha of a rich text)
    for i, ln in enumerate(lines):
        lw = f.getlength(ln)
        x = W * px + (0 if xa == "Left" else (iw - lw) if xa == "Right" else (iw - lw) / 2)
        kw = {}
        if isinstance(stroke, dict) and stroke.get("color"):
            kw = dict(stroke_width=max(1, size // 14),
                      stroke_fill=tuple(stroke["color"]) + (int(255 * (1 - stroke.get("tr", 0))),))
        yy = y0 + i * size + size / 2
        if alphas is None:
            draw.text((x, yy), ln, font=f, fill=color, anchor="lm", **kw)
            continue
        while pos < len(text) and text[pos] in " \n" and not ln.startswith(text[pos]):
            pos += 1
        run, run_a, xs = "", None, x
        for ch in ln + "\0":
            a = alphas[pos] if ch != "\0" and pos < len(alphas) else None
            if run and (a != run_a or ch == "\0"):
                draw.text((xs, yy), run, font=f, fill=color[:3] + (int(color[3] * run_a),), anchor="lm", **kw)
                xs += f.getlength(run)
                run = ""
            if ch != "\0":
                run, run_a = run + ch, a
                pos += 1
    k = max(1, min(magnify, int(max_tex / max(W, H))))
    return img.resize((W * k, H * k), Image.BILINEAR) if k > 1 else img


def face_frame(row, face):
    """(centre, normal, right, up, width, height) of a part's face, Roblox space."""
    R = rotm(row[C.RX], row[C.RY], row[C.RZ])
    n_l, r_l, u_l, wi, hi = FACES[face]

    def tw(v):
        return tuple(sum(R[i][k] * v[k] for k in range(3)) for i in range(3))

    n, r, u = tw(n_l), tw(r_l), tw(u_l)
    size = row[C.SX:C.SX + 3]
    half = sum(abs(n_l[k]) * size[k] / 2 for k in range(3))
    c = tuple(row[C.X + k] + n[k] * half for k in range(3))
    return c, n, r, u, size[wi], size[hi]


# ------------------------------------------------------------------------------ Blender
def build(data, mode="kit", night=False, world=None, samples=12, size=(880, 550), exposure=1.0, ambient=None,
          region=None, signs=True, sign_dir=None):
    import bpy  # noqa: I001
    import bmesh
    from mathutils import Matrix, Vector

    import kitlib

    world = world if world is not None else (0.6 if night else 2.0)
    ambient = ambient if ambient is not None else (0.03 if night else 0.35)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.render.threads_mode = "FIXED"
    sc.render.threads = 2  # (the machine is shared)
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 4
    sc.cycles.use_adaptive_sampling = True
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.view_settings.view_transform = "AgX" if "AgX" in RA._view_transforms(bpy) else "Filmic"
    sc.view_settings.exposure = exposure
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.04, 0.05, 0.08, 1) if night else (0.6, 0.64, 0.7, 1)
    bg.inputs[1].default_value = (0.35 if night else 1.0) * world
    if not night:
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 3.0
        sun.data.angle = math.radians(2)
        sun.rotation_euler = (math.radians(40), math.radians(15), math.radians(130))
        sc.collection.objects.link(sun)

    def unit(name, fn):
        bm = bmesh.new()
        fn(bm)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(None)
        return me

    cube = unit("cube", lambda bm: bmesh.ops.create_cube(bm, size=1))

    def cyl_fn(bm):
        bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.5, radius2=0.5, depth=1,
                              matrix=Matrix.Rotation(math.radians(90), 4, "Y"))

    cyl = unit("cyl", cyl_fn)
    for p in cyl.polygons:
        p.use_smooth = abs(p.normal.x) < 0.5
    ball = unit("ball", lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=0.5))
    for p in ball.polygons:
        p.use_smooth = True

    def wedge_fn(bm):
        vs = [bm.verts.new(v) for v in [(-.5, -.5, -.5), (.5, -.5, -.5), (-.5, -.5, .5), (.5, -.5, .5),
                                        (-.5, .5, .5), (.5, .5, .5)]]
        for f in [(0, 1, 3, 2), (2, 3, 5, 4), (0, 4, 5, 1), (0, 2, 4), (1, 5, 3)]:
            bm.faces.new([vs[i] for i in f])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    wedge = unit("wedge", wedge_fn)
    W = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    Cm = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))

    def rot(rx, ry, rz):
        return (Matrix.Rotation(math.radians(ry), 3, "Y") @ Matrix.Rotation(math.radians(rx), 3, "X")
                @ Matrix.Rotation(math.radians(rz), 3, "Z"))

    def frame(r):
        m = (Cm @ rot(r[4], r[5], r[6]) @ Cm.transposed()).to_4x4()
        m.translation = Vector((r[1], -r[3], r[2]))
        return m

    def B(v):
        return Vector((v[0], -v[2], v[1]))

    mats = {}
    ROUGH = {"Metal": 0.35, "Glass": 0.05, "SmoothPlastic": 0.5, "Plastic": 0.55, "Neon": 0.5, "DiamondPlate": 0.4}

    def mat(rgb, name, tr):
        key = (tuple(rgb), name, tr)
        if key in mats:
            return mats[key]
        m = bpy.data.materials.new(f"P{len(mats)}")
        m.use_nodes = True
        p = m.node_tree.nodes["Principled BSDF"]
        c = tuple(kitlib.srgb_to_linear(v) for v in rgb) + (1,)
        p.inputs["Base Color"].default_value = c
        p.inputs["Roughness"].default_value = ROUGH.get(name, 0.85)
        if name in ("Metal", "DiamondPlate", "CorrodedMetal"):
            p.inputs["Metallic"].default_value = 0.6
        if name == "Neon":
            p.inputs["Emission Color"].default_value = c
            p.inputs["Emission Strength"].default_value = 5
        if tr > 0:
            p.inputs["Alpha"].default_value = max(0.05, 1 - tr)
        mats[key] = m
        return m

    parts = data["parts"]
    skip = data.get("skip", set())

    def inside(r):
        if region is None:
            return True
        return region[0] <= r[1] <= region[1] and region[2] <= r[3] <= region[3]

    kit = RA.load_kit(bpy, Vector) if mode == "kit" else {}
    swapped = {}  # row index -> piece (the markers PropKit swaps)
    for i, r in enumerate(parts):
        if i in skip or C.name_of(data, r) != "MeshProp":
            continue
        piece = ((C.extra_of(data, r) or {}).get("a") or {}).get("Piece")
        if piece and piece in kit:
            swapped[i] = piece

    def built(i):
        """Is row i built (not skipped, and every ancestor built)? A child of a skipped part
        has no parent in the game (it is lost)."""
        seen = 0
        while i is not None and seen < 64:
            if i in skip:
                return False
            p = parts[i][C.PARENT]
            i = p - 1 if p else None
            seen += 1
        return True

    def owner(i):
        seen = 0
        p = parts[i][C.PARENT]
        while p and seen < 64:
            if (p - 1) in swapped:
                return p - 1
            p = parts[p - 1][C.PARENT]
            seen += 1
        return None

    LIGHT_TAGS = {"CityLamp", "CityBulkhead", "CityFireEmbers", "CityShopLight", "CityNeon", "CityEmergency"}
    under = {}
    for i, r in enumerate(parts):
        if r[C.PARENT] and swapped:
            o = owner(i)
            if o is not None:
                under.setdefault(o, []).append(i)
    bulbs = {}
    for mk, kids in under.items():
        tagged = [k for k in kids if set((C.extra_of(data, parts[k]) or {}).get("t", [])) & LIGHT_TAGS]
        lit = [k for k in kids if (C.extra_of(data, parts[k]) or {}).get("l")]
        if tagged or lit:
            bulbs[mk] = (tagged or lit)[0]

    lights, sign_rows = [], []
    stats = {"parts": 0, "hidden": 0, "markers": 0, "kit_objects": 0, "signs": 0}
    for i, r in enumerate(parts):
        if not built(i) or not inside(r):
            continue
        ex = C.extra_of(data, r)
        o = owner(i) if swapped else None
        if o is not None:
            stats["hidden"] += 1
            if ex and ex.get("l"):
                lights.append(("moved", o, i, ex["l"]))
            continue
        if ex and ex.get("l"):
            lights.append(("here", None, i, ex["l"]))
        if ex and ex.get("g") and signs:
            sign_rows.append(i)
        if r[C.TRANSP] >= 0.99:
            continue
        shape = r[0]
        sx, sy, sz = r[7], r[8], r[9]
        if shape == 3:
            dia = min(sy, sz)
            m = frame(r) @ Matrix.Diagonal((sx, dia, dia, 1))
            me = cyl
        elif shape == 4:
            dia = min(sx, sy, sz)
            m = frame(r) @ Matrix.Diagonal((dia, dia, dia, 1))
            me = ball
        elif shape == 2:
            m = frame(r) @ (W @ Matrix.Diagonal((sx, sy, sz, 1)))
            me = wedge
        else:
            m = frame(r) @ Matrix.Diagonal((sx, sz, sy, 1))
            me = cube
        ob = bpy.data.objects.new("p", me)
        ob.matrix_world = m
        sc.collection.objects.link(ob)
        ob.material_slots[0].link = "OBJECT"
        ob.material_slots[0].material = mat(data["colors"][r[10] - 1], data["materials"][r[11] - 1], r[12])
        ob.visible_shadow = bool(r[14] & 4) or (r[12] < 0.2 and sx > 0.3 and sy > 0.3 and sz > 0.3)
        stats["parts"] += 1

    glow_at = {}
    for i, piece_name in swapped.items():
        r = parts[i]
        if not built(i) or not inside(r):
            continue
        piece = kit[piece_name]
        attrs = C.extra_of(data, r)["a"]
        scale = float(attrs.get("Scale") or 1.0)
        tint = tuple(int(v) for v in attrs["Tint"].split(",")) if attrs.get("Tint") else None
        base = frame(r) @ Matrix.Diagonal((scale, scale, scale, 1))
        bulb = bulbs.get(i)
        for layer, (mesh, local, centre) in piece["layers"].items():
            ob = bpy.data.objects.new(f"{piece_name}_{layer}", mesh)
            ob.matrix_world = base @ local
            sc.collection.objects.link(ob)
            tintable = kitlib.LAYERS.get(layer, kitlib.LAYERS["Plastic"])[3]
            if layer == "Glow" and piece["points"].get("Light") is not None:
                if bulb is not None:
                    br = parts[bulb]
                    bm_ = mat(data["colors"][br[10] - 1], data["materials"][br[11] - 1], 0)
                else:
                    bm_ = mat((90, 90, 86), "Glass", 0)
            else:
                bm_ = kitlib.preview_material(layer if layer in kitlib.LAYERS else "Plastic",
                                              tint if (tintable and tint) else None)
            ob.material_slots[0].link = "OBJECT"
            ob.material_slots[0].material = bm_
            ob.visible_shadow = piece["extent"] * scale >= 1.2 and layer not in ("Glow", "Glass")
            stats["kit_objects"] += 1
            if layer == "Glow":
                glow_at[i] = base @ centre
        stats["markers"] += 1

    # -- signs: a textured plane on the face (0.006 off it)
    sign_dir = sign_dir or os.path.join("/tmp", f"render_city_signs_{os.getpid()}")
    os.makedirs(sign_dir, exist_ok=True)
    for i in sign_rows:
        r = parts[i]
        g = C.extra_of(data, r)["g"]
        face = g.get("face", "Front")
        if face not in FACES:
            continue
        c, n, rt, up, fw, fh = face_frame(r, face)
        img = sign_image(g, fw, fh)
        path = os.path.join(sign_dir, f"sign_{i}.png")
        img.save(path)
        cB = B(c) + B(n) * 0.006
        hw, hh = B(rt) * (fw / 2), B(up) * (fh / 2)
        me = bpy.data.meshes.new(f"sign{i}")
        me.from_pydata([cB - hw - hh, cB + hw - hh, cB + hw + hh, cB - hw + hh], [], [(0, 1, 2, 3)])
        uv = me.uv_layers.new(name="uv")
        for k, (u, v) in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))):
            uv.data[k].uv = (u, v)
        ob = bpy.data.objects.new(f"sign{i}", me)
        sc.collection.objects.link(ob)
        m = bpy.data.materials.new(f"sign{i}")
        m.use_nodes = True
        nt = m.node_tree
        p = nt.nodes["Principled BSDF"]
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(path)
        tex.interpolation = "Linear"
        nt.links.new(tex.outputs["Color"], p.inputs["Base Color"])
        nt.links.new(tex.outputs["Alpha"], p.inputs["Alpha"])
        p.inputs["Roughness"].default_value = 0.8
        lit = g.get("lit")
        light_inf = g.get("light", 0 if lit else 1)
        if light_inf < 0.5:
            nt.links.new(tex.outputs["Color"], p.inputs["Emission Color"])
            p.inputs["Emission Strength"].default_value = g.get("bright", 2.5 if night else 0.7) * (2 if night else 1)
        if hasattr(m, "blend_method"):
            m.blend_method = "BLEND"
        me.materials.append(m)
        ob.visible_shadow = False
        stats["signs"] += 1

    if night:
        for how, o, i, lt in lights:
            r = parts[i]
            at = B(r[1:4])
            if how == "moved":
                mr = parts[o]
                piece = kit[swapped[o]]
                scale = float(C.extra_of(data, mr)["a"].get("Scale") or 1.0)
                base = frame(mr) @ Matrix.Diagonal((scale, scale, scale, 1))
                if bulbs.get(o) == i and o in glow_at:
                    at = glow_at[o]
                elif piece["points"].get("Light") is not None:
                    at = base @ piece["points"]["Light"]
            ld = bpy.data.lights.new("l", "POINT" if lt["type"] == "Point" else "SPOT")
            ld.color = tuple(v / 255 for v in lt["color"])
            ld.energy = lt["brightness"] * lt["range"] ** 2 * 1.2
            ld.shadow_soft_size = 0.2
            lo = bpy.data.objects.new("l", ld)
            lo.location = at
            if lt["type"] == "Spot":
                ld.spot_size = math.radians(lt.get("angle", 90))
                lo.location = at - Vector((0, 0, 0.5))
            sc.collection.objects.link(lo)

    plane = bpy.data.objects.new("ground", unit("plane", lambda bm: bmesh.ops.create_grid(
        bm, x_segments=1, y_segments=1, size=600)))
    plane.location = (0, 0, -0.01)
    sc.collection.objects.link(plane)
    if ambient > 0:
        RA.add_ambient(bpy, ambient)
    print("built", stats, "lights", len(lights) if night else 0, flush=True)
    return sc


def render(sc, cams, out_dir, tag):
    """cams: [(name, (eye, look, fov[, cut]))]."""
    import bpy
    from mathutils import Vector

    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.clip_start = 0.1
    cam.data.clip_end = 2000
    lowest = {}
    for ob in sc.collection.objects:
        if ob.type == "MESH" and ob.name != "ground":
            lowest[ob] = min((ob.matrix_world @ Vector(c)).z for c in ob.bound_box)
    paths = []
    for name, spec in cams:
        eye, look, fov, *rest = spec
        cut = rest[0] if rest else None
        for ob, low in lowest.items():
            ob.hide_render = cut is not None and low > cut
        e = Vector((eye[0], -eye[2], eye[1]))
        lk = Vector((look[0], -look[2], look[1]))
        cam.location = e
        cam.rotation_euler = (lk - e).to_track_quat("-Z", "Y").to_euler()
        if fov < 0:
            cam.data.type = "ORTHO"
            cam.data.ortho_scale = -fov
        else:
            cam.data.type = "PERSP"
            cam.data.angle = math.radians(fov)
        sc.render.filepath = os.path.join(out_dir, f"{name}_{tag}.png")
        t = time.time()
        bpy.ops.render.render(write_still=True)
        print(f"{name}: {sc.render.filepath} ({time.time() - t:.0f} s)", flush=True)
        paths.append(sc.render.filepath)
    return paths


def parse_cam(text, fov):
    """'x,y,z:tx,ty,tz[:fov]' -> (eye, look, fov)."""
    bits = text.split(":")
    eye = tuple(float(v) for v in bits[0].split(","))
    look = tuple(float(v) for v in bits[1].split(","))
    return (eye, look, float(bits[2]) if len(bits) > 2 else fov)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--mode", choices=("kit", "fallback"), default="kit")
    ap.add_argument("--night", action="store_true")
    ap.add_argument("--cams", default="", help="named cameras, comma list (--list)")
    ap.add_argument("--cam", action="append", default=[], help="x,y,z:tx,ty,tz[:fov] (repeatable)")
    ap.add_argument("--fov", type=float, default=70)
    ap.add_argument("--out", default=os.path.join(ROOT, "renders_city"))
    ap.add_argument("--samples", type=int, default=12)
    ap.add_argument("--size", default="880x550")
    ap.add_argument("--region", help="x0,x1,z0,z1: only the parts whose centre is inside")
    ap.add_argument("--no-overlay", action="store_true")
    ap.add_argument("--no-signs", action="store_true")
    ap.add_argument("--world", type=float)
    ap.add_argument("--exposure", type=float, default=1.0)
    ap.add_argument("--ambient", type=float)
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()
    if a.list:
        for n, c in CAMS.items():
            print(f"{n:24s} eye {c[0]}  look {c[1]}  fov {c[2]}")
        return
    cams = []
    for n in [c for c in a.cams.split(",") if c]:
        if n not in CAMS:
            raise SystemExit(f"unknown camera {n!r} (--list)")
        cams.append((n, CAMS[n]))
    for k, text in enumerate(a.cam):
        cams.append((f"cam{k + 1}", parse_cam(text, a.fov)))
    if not cams:
        raise SystemExit("no camera: --cams name,... or --cam x,y,z:tx,ty,tz (--list)")
    os.makedirs(a.out, exist_ok=True)
    region = tuple(float(v) for v in a.region.split(",")) if a.region else None
    data, _ = city_data(not a.no_overlay)
    size = tuple(int(v) for v in a.size.lower().split("x"))
    sc = build(data, a.mode, a.night, a.world, a.samples, size, a.exposure, a.ambient, region,
               not a.no_signs, os.path.join(a.out, "signs"))
    render(sc, cams, a.out, f"{a.mode}_{'night' if a.night else 'day'}")


if __name__ == "__main__":
    main()
