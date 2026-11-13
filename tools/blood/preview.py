# Preview of the blood pictures, tinted like the game does (Decal.Color3 x grey)
# over photo-like surfaces (asphalt, concrete, brick, skin, cotton).
# Run from the repo root after make_blood_textures.py:
#   python3 tools/blood/preview.py            -> assets/blood/preview.png
#   python3 tools/blood/preview.py out_dir    -> also writes full-size panels there
# The surfaces are procedural (made here), only for this preview.
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

SRC = os.environ.get("BLOOD_SRC", "assets/blood")  # (BLOOD_SRC: another folder, for tests)
F32 = np.float32
P = 512  # panel size

# Config.Blood.PALETTE (sRGB 0-255)
PAL = {
    "ARTERIAL": (138, 9, 6),
    "ARTERIAL_LIGHT": (161, 20, 14),
    "VENOUS": (94, 11, 11),
    "CLOTTED": (72, 10, 10),
    "DRYING": (62, 13, 11),
    "DRY": (48, 14, 11),
    "OLD": (42, 21, 16),
    "FABRIC_SOAK": (70, 12, 12),
}


def col(name):
    return np.array(PAL[name], F32) / 255


def noise(rng, shape, sigma):
    n = ndi.gaussian_filter(rng.standard_normal(shape).astype(F32), sigma)
    return n / (n.std() + 1e-6)


# ------------------------------------------------------------ surfaces ----
def asphalt(seed):
    rng = np.random.default_rng(seed)
    s = (P, P)
    base = 0.2 + 0.025 * noise(rng, s, 60) + 0.02 * noise(rng, s, 8)
    stones = noise(rng, s, 2.2)
    sh = ndi.gaussian_filter(stones, 0.8)
    lit = np.clip(sh - np.roll(sh, (2, 2), (0, 1)), -1, 1)  # aggregate lit from the top left
    base += 0.05 * np.clip(stones - 0.6, 0, None) + 0.03 * lit * (stones > 0.4)
    base -= 0.08 * np.clip(-stones - 1.2, 0, None)  # pits between stones
    base += 0.025 * rng.standard_normal(s)
    img = np.dstack([base * 0.98, base * 0.99, base * 1.03])
    return np.clip(img, 0, 1)


def concrete(seed):
    rng = np.random.default_rng(seed)
    s = (P, P)
    base = 0.55 + 0.04 * noise(rng, s, 90) + 0.025 * noise(rng, s, 20) + 0.02 * noise(rng, s, 3)
    pores = noise(rng, s, 1.2)
    base -= 0.25 * np.clip(pores - 2.3, 0, None)
    base += 0.02 * rng.standard_normal(s)
    img = np.dstack([base * 1.02, base * 1.0, base * 0.95])
    return np.clip(img, 0, 1)


def brick(seed):
    rng = np.random.default_rng(seed)
    Y, X = np.mgrid[0:P, 0:P].astype(F32)
    bh, bw, m = 44, 120, 7
    row = (Y // bh).astype(int)
    xo = X + (row % 2) * bw / 2
    col_i = (xo // bw).astype(int)
    wob = 1.5 * noise(rng, (P, P), 3)
    mort = (np.minimum(Y % bh, bh - Y % bh) < m / 2 + wob) | (np.minimum(xo % bw, bw - xo % bw) < m / 2 + wob)
    tone = np.random.default_rng(seed + 1).uniform(0.75, 1.15, (40, 40))[row % 40, col_i % 40]
    b = np.dstack([0.36 * tone, 0.2 * tone, 0.16 * tone])
    b *= (1 + 0.08 * noise(rng, (P, P), 6) + 0.08 * rng.standard_normal((P, P)))[..., None]
    mo = (0.46 + 0.04 * noise(rng, (P, P), 2) + 0.04 * rng.standard_normal((P, P)))[..., None] * np.array([1, 0.97, 0.9])
    return np.clip(np.where(mort[..., None], mo, b), 0, 1)


def skin(seed):
    rng = np.random.default_rng(seed)
    s = (P, P)
    tone = np.array([0.76, 0.56, 0.45])
    mott = 0.025 * noise(rng, s, 30) + 0.015 * noise(rng, s, 6)
    pores = np.clip(noise(rng, s, 1.0) - 2.0, 0, None) * 0.12
    Y, X = np.mgrid[0:P, 0:P].astype(F32)
    lines = 0.02 * np.sin((X * 0.7 + Y * 0.5 + 6 * noise(rng, s, 12)) / 3.0) * np.sin((X * -0.5 + Y * 0.8) / 4.0)
    img = tone[None, None] * (1 + mott - pores + lines)[..., None]
    img[..., 0] += 0.025 * noise(rng, s, 20)  # redness
    img[..., 1] -= 0.01 * noise(rng, s, 20)
    return np.clip(img, 0, 1)


def cotton(seed):
    rng = np.random.default_rng(seed)
    Y, X = np.mgrid[0:P, 0:P].astype(F32)
    knit = 0.5 + 0.5 * np.sin(X * 2 * np.pi / 4) * np.sign(np.sin(Y * 2 * np.pi / 6 + (X // 4) % 2 * 1.5))
    base = 0.78 + 0.04 * knit + 0.03 * noise(rng, (P, P), 25) + 0.03 * rng.standard_normal((P, P))
    folds = 0.06 * noise(rng, (P, P), 50)
    img = (base + folds)[..., None] * np.array([0.95, 0.95, 0.97])
    return np.clip(img, 0, 1)


def dark_bg(seed):
    rng = np.random.default_rng(seed)
    base = 0.62 + 0.05 * noise(rng, (P, P), 80)
    return np.clip(base[..., None] * np.array([0.8, 0.85, 0.9]), 0, 1)


# ---------------------------------------------------------- compositing ---
_cache = {}


def tex(name):
    if name not in _cache:
        a = np.asarray(Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")).astype(F32) / 255
        _cache[name] = a
    return _cache[name]


def place(canvas, name, cx, cy, size, tint, ang=0.0, opacity=1.0, sx=1.0, crop=None, sy=1.0):
    """Like a Decal on a carrier Part: grey x tint, alpha-blended, size = width
    in pixels of the panel, sx / sy = extra stretch along the texture X / Y axis."""
    t = tex(name)
    if crop is not None:
        t = t[crop]
    th, tw = t.shape[:2]
    scale = size / tw  # panel px per texture px
    c, s = np.cos(ang), np.sin(ang)
    half = 0.5 * np.hypot(tw * scale * sx, th * scale * sy) + 2
    x0, x1 = int(max(0, cx - half)), int(min(canvas.shape[1], cx + half))
    y0, y1 = int(max(0, cy - half)), int(min(canvas.shape[0], cy + half))
    if x0 >= x1 or y0 >= y1:
        return
    Y, X = np.mgrid[y0:y1, x0:x1].astype(F32) + 0.5
    dx, dy = X - cx, Y - cy
    u = (dx * c + dy * s) / (scale * sx) + tw / 2
    v = (-dx * s + dy * c) / (scale * sy) + th / 2
    # premultiply before resampling (no fringes), mipmap-ish prefilter
    pm = t[..., :3] * t[..., 3:4]
    sig = max(0.0, 0.5 / scale - 0.5)
    chans = []
    for k in range(3):
        ch = ndi.gaussian_filter(pm[..., k], sig) if sig > 0.1 else pm[..., k]
        chans.append(ndi.map_coordinates(ch, [v, u], order=1, mode="constant"))
    al = ndi.gaussian_filter(t[..., 3], sig) if sig > 0.1 else t[..., 3]
    a = ndi.map_coordinates(al, [v, u], order=1, mode="constant") * opacity
    rgb = np.dstack(chans) * opacity * np.asarray(tint)[None, None]
    region = canvas[y0:y1, x0:x1]
    canvas[y0:y1, x0:x1] = rgb + region * (1 - a[..., None])


def finish(img, seed, flash=True):
    """Camera look: flash falloff + a little sensor grain (both over blood and
    surface, so they sit in the same 'photo')."""
    rng = np.random.default_rng(seed)
    if flash:
        Y, X = np.mgrid[0:P, 0:P].astype(F32)
        r = np.hypot(X - P * 0.45, Y - P * 0.4) / P
        img = img * (1.12 - 0.35 * r * r)[..., None]
    img = img + 0.012 * rng.standard_normal(img.shape[:2])[..., None]
    return np.clip(img, 0, 1)


def panel_floor_fresh():
    c = asphalt(1)
    place(c, "pool_1", 230, 260, 430, col("VENOUS"), 0.4)
    place(c, "pool_lobe_2", 400, 360, 150, col("VENOUS"), 0.9)
    place(c, "drip_1", 440, 110, 40, col("VENOUS"))
    place(c, "drip_2", 470, 160, 34, col("VENOUS"))
    place(c, "drip_pool_1", 90, 450, 170, col("VENOUS"))
    place(c, "spatter_round_2", 420, 460, 110, col("ARTERIAL"))
    return finish(c, 1)


def panel_floor_clot():
    c = concrete(2)
    place(c, "pool_2", 250, 250, 440, col("CLOTTED"), 1.3)
    place(c, "pool_rim_2", 250, 250, 440, col("DRY"), 1.3)
    place(c, "spatter_oval_1", 90, 440, 120, col("DRYING"), -0.3)
    place(c, "spatter_tail_2", 380, 470, 140, col("DRYING"), -0.1)
    return finish(c, 2)


def panel_directional():
    c = concrete(3)
    place(c, "spatter_round_1", 110, 110, 150, col("ARTERIAL"))
    place(c, "spatter_oval_2", 300, 120, 170, col("ARTERIAL"), 0.15)
    place(c, "spatter_tail_1", 160, 280, 190, col("ARTERIAL"), 0.25)
    place(c, "spatter_streak_1", 330, 300, 230, col("ARTERIAL"), 0.3)
    place(c, "satellites_2", 220, 430, 300, col("ARTERIAL"), 0.1)
    place(c, "satellites_1", 420, 420, 200, col("ARTERIAL"), -0.4)
    return finish(c, 3)


def panel_wall():
    c = brick(4)
    place(c, "arterial_arc_1", 256, 120, 560, col("ARTERIAL"), 0.0)
    place(c, "run_1", 110, 330, 70, col("VENOUS"), 0.0)
    place(c, "run_2", 330, 360, 60, col("VENOUS"), 0.0)
    place(c, "handprint_R_1", 420, 360, 110, col("VENOUS"), 0.3)
    place(c, "satellites_3", 230, 300, 260, col("ARTERIAL"), 1.2)
    return finish(c, 4)


def panel_tracks():
    c = asphalt(5)
    place(c, "smear_1", 250, 120, 470, col("VENOUS"), 0.05)
    steps = [("foot_L_1", 120, 470), ("foot_R_1", 190, 420), ("foot_L_2", 260, 370), ("foot_R_2", 330, 320), ("foot_L_3", 400, 270), ("foot_R_3", 470, 220)]
    for i, (n, x, y) in enumerate(steps):
        place(c, n, x - (12 if "L" in n else -12), y, 85, col("DRYING" if i > 1 else "VENOUS"), 0.95)
    place(c, "handprint_L_1", 70, 300, 110, col("CLOTTED"), -0.2)
    return finish(c, 5)


def panel_skin():
    c = skin(6)
    place(c, "skin_smear_1", 256, 150, 420, col("ARTERIAL_LIGHT"), 0.1)
    place(c, "knuckles_1", 130, 380, 220, col("VENOUS"), 0.0)
    place(c, "run_1", 380, 360, 80, col("VENOUS"), 0.0)
    place(c, "satellites_1", 330, 300, 160, col("ARTERIAL"), 0.6)
    return finish(c, 6)


def panel_cloth():
    c = cotton(7)
    place(c, "soak_1", 230, 230, 360, col("FABRIC_SOAK"))
    place(c, "soak_3", 420, 420, 200, (40 / 255, 12 / 255, 10 / 255))
    place(c, "spatter_round_3", 80, 440, 120, col("ARTERIAL"))
    place(c, "satellites_2", 360, 100, 240, col("ARTERIAL"), 0.5)
    return finish(c, 7)


def panel_particles():
    c = dark_bg(8)
    place(c, "beam_stream", 256, 60, 512, col("ARTERIAL"), 0.0)
    place(c, "p_drop", 60, 170, 70, col("ARTERIAL"))
    place(c, "p_drops_4x4", 180, 230, 150, col("ARTERIAL"), crop=(slice(0, 512), slice(0, 512)))
    place(c, "p_gobs_4x4", 380, 230, 260, col("ARTERIAL"))
    place(c, "p_mist_8x8", 128, 400, 220, col("ARTERIAL_LIGHT"), crop=(slice(256, 512), slice(0, 256)))
    place(c, "p_mist_8x8", 360, 410, 200, col("ARTERIAL_LIGHT"), crop=(slice(768, 1024), slice(512, 768)))
    return finish(c, 8, flash=False)


PANELS = [
    ("asphalt, fresh pool", panel_floor_fresh),
    ("concrete, clotted pool + rim", panel_floor_clot),
    ("concrete, spatter by angle", panel_directional),
    ("brick wall, arterial + runs", panel_wall),
    ("asphalt, drag + footprints", panel_tracks),
    ("skin, smear + knuckles + run", panel_skin),
    ("cotton, soak + spray", panel_cloth),
    ("particles + beam (grey bg)", panel_particles),
]


def contact_sheet(width, names=None):
    if names is None:  # v1: every picture of the folder except the previews and the v2 ones
        names = sorted(f[:-4] for f in os.listdir(SRC) if f.endswith(".png") and not f.startswith("preview") and f[:-4] not in V2_FILES)
    cell = 120
    cols = width // cell
    rows = (len(names) + cols - 1) // cols
    sheet = np.ones((rows * (cell + 14), width, 3), F32) * 0.85
    for i, n in enumerate(names):
        t = tex(n)
        img = Image.fromarray((t * 255).astype(np.uint8), "RGBA")
        img.thumbnail((cell - 6, cell - 6), Image.LANCZOS)
        a = np.asarray(img).astype(F32) / 255
        # tint grey -> fresh red so the sheet reads like blood
        rgb = a[..., :3] * (np.ones(3, F32) if n.startswith("flesh_tear") else col("ARTERIAL"))[None, None]  # (the colour picture: white)
        r, c_ = divmod(i, cols)
        y0, x0 = r * (cell + 14) + 3, c_ * cell + 3
        h, w = a.shape[:2]
        reg = sheet[y0 : y0 + h, x0 : x0 + w]
        sheet[y0 : y0 + h, x0 : x0 + w] = rgb * a[..., 3:4] + reg * (1 - a[..., 3:4])
    im = Image.fromarray((sheet * 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    for i, n in enumerate(names):
        r, c_ = divmod(i, cols)
        d.text((c_ * cell + 3, r * (cell + 14) + cell - 2), n, fill=(20, 20, 20))
    return np.asarray(im)


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else None
    panels = []
    for title, fn in PANELS:
        img = (fn() * 255).astype(np.uint8)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
            Image.fromarray(img).save(os.path.join(out_dir, title.split(",")[0].replace(" ", "_") + "_" + fn.__name__ + ".png"))
        im = Image.fromarray(img)
        ImageDraw.Draw(im).text((8, 6), title, fill=(255, 255, 255))
        panels.append(np.asarray(im))
    top = np.concatenate([np.concatenate(panels[:4], 1), np.concatenate(panels[4:], 1)], 0)
    sheet = contact_sheet(top.shape[1])
    full = np.concatenate([top, sheet], 0)
    im = Image.fromarray(full)
    im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)  # keep the file small
    im = im.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    im.save(os.path.join(SRC, "preview.png"), optimize=True)
    print("preview.png", os.path.getsize(os.path.join(SRC, "preview.png")) // 1024, "KB")


# ======================================================== v2 preview ======
# python3 tools/blood/preview.py --v2 [out_dir]  -> assets/blood/preview_v2.png
# The NEW (v2) pictures in situation: two blocky R6 heads (light and dark
# skin, default smile face) with face wounds at their real size, an arm,
# cotton (white and dark shirt), asphalt (pool + serum + drips, drag +
# running prints), and the particle flipbooks frame by frame.
PAL.update(
    {
        "SALIVA": (168, 38, 36),
        "SERUM": (214, 176, 96),
        "RAW": (190, 80, 72),
        "FABRIC_WET": (22, 8, 8),
    }
)
V2_FILES = [
    "rivulet_strip_1", "rivulet_strip_2", "rivulet_strip_3", "rivulet_bead_1", "rivulet_bead_2",
    "rivulet_fork_1", "rivulet_fork_2", "browcut_1", "browcut_2", "cheekcut_1", "lipfilm_1",
    "crust_strip_1", "crust_strip_2", "crust_patch_1", "crust_patch_2", "spit_1", "spit_2",
    "wipe_smear_1", "wipe_smear_2", "abrasion_1", "abrasion_2", "split_knuckle_1",
    "wick_halo_1", "wick_halo_2", "wick_weave_1", "serum_halo_1", "serum_halo_2", "serum_halo_3",
    "starburst_1", "starburst_2", "ripple_ring_1", "drag_1", "drag_2", "shoe_run_L_1", "shoe_run_R_1",
    "crown_4x4", "froth_4x4", "pendant_2x2", "scalp_split_1", "flesh_tear_1", "flesh_tear_2",
]  # fmt: skip


def mix(a, b, f):
    return col(a) * (1 - f) + col(b) * f


def sdf_box(X, Y, cx, cy, hx, hy, r):
    qx, qy = np.abs(X - cx) - hx + r, np.abs(Y - cy) - hy + r
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def r6_head(tone, seed, shirt=(0.16, 0.2, 0.3)):
    """A classic R6 head seen from the front (smooth plastic, lit from the
    top left) with the default 'Smile' face. 1 stud = HEAD_PX / 1.2 px."""
    rng = np.random.default_rng(seed)
    Y, X = np.mgrid[0:P, 0:P].astype(F32) + 0.5
    bg = (0.3 + 0.08 * (1 - Y / P))[..., None] * np.array([0.9, 0.92, 1.0]) + 0.01 * noise(rng, (P, P), 40)[..., None]
    cx, cy = P * 0.5, P * 0.47
    hx, hy = 205, 190
    # torso top + neck shadow
    torso = sdf_box(X, Y, cx, P + 30, 250, 70, 20) < 0
    img = np.where(torso[..., None], np.array(shirt) * (0.8 + 0.2 * (1 - np.abs(X - cx) / P))[..., None], bg)
    D = sdf_box(X, Y, cx, cy, hx, hy, 95)
    a = np.clip(0.5 - D, 0, 1)
    nx = np.clip((X - cx) / (hx + 8), -1, 1)
    nz = np.sqrt(1 - nx * nx)
    ny = np.clip((Y - cy) / (hy + 60), -1, 1) * 0.5
    shade = 0.55 + 0.45 * np.clip(-0.45 * nx - 0.5 * ny + 0.75 * nz, 0, 1)
    spec = 0.12 * np.exp(-(((X - cx + 70) / 60) ** 2 + ((Y - cy + 110) / 40) ** 2))
    head = np.asarray(tone, F32)[None, None] * shade[..., None] + spec[..., None]
    img = head * a[..., None] + img * (1 - a[..., None])
    # the default face: two tall black eyes and a curved smile
    ink = np.zeros((P, P), F32)
    for s in (-1, 1):
        q = np.hypot((X - cx - s * 62) / 17, (Y - cy + 30) / 34)
        ink = np.maximum(ink, np.clip((1 - q) * 17 + 0.5, 0, 1))
    xm = np.clip(X, cx - 100, cx + 100)
    ym = cy + 100 - 0.0058 * (xm - cx) ** 2
    dm = np.hypot(X - xm, (Y - ym) * 0.9)
    ink = np.maximum(ink, np.clip(5.5 - dm + 0.5, 0, 1))
    img = img * (1 - 0.92 * ink[..., None]) + 0.02 * ink[..., None]
    return np.clip(img, 0, 1), (cx, cy)


def run_down(c, name, x0, y0, x1, y1, width, tint, opacity=1.0):
    """A rivulet strip (128x512, top -> bottom) from (x0, y0) to (x1, y1)."""
    length = np.hypot(x1 - x0, y1 - y0)
    ang = np.arctan2(y1 - y0, x1 - x0) - np.pi / 2
    place(c, name, (x0 + x1) / 2, (y0 + y1) / 2, width, tint, ang, opacity, sy=length / (width * 4))


def panel_head_light():
    c, (cx, cy) = r6_head((0.92, 0.72, 0.57), 11)
    # brow cut over the (viewer's) left eye, its run over the eye, the cheek, the jaw
    place(c, "browcut_1", cx - 66, cy - 98, 104, col("ARTERIAL"), -0.12)
    run_down(c, "rivulet_strip_1", cx - 32, cy - 92, cx - 38, cy - 8, 30, col("ARTERIAL"))
    run_down(c, "rivulet_strip_2", cx - 38, cy - 12, cx - 28, cy + 124, 26, col("ARTERIAL"))
    place(c, "rivulet_bead_1", cx - 28, cy + 128, 26, col("VENOUS"))
    # nose bleed (R6 has no nose: from the middle of the face) splitting around the smile
    place(c, "rivulet_fork_1", cx + 6, cy + 46, 70, col("ARTERIAL"), sy=0.8)
    place(c, "lipfilm_1", cx + 2, cy + 112, 130, mix("SALIVA", "ARTERIAL", 0.5), 0.0, 0.55)
    # older cheekbone cut and its dried run
    place(c, "cheekcut_1", cx + 92, cy + 2, 90, col("VENOUS"), 0.1)
    place(c, "crust_strip_1", cx + 95, cy + 84, 24, col("DRY"), 0.03, sy=1.5)
    return finish(c, 11, flash=False)


def panel_head_dark():
    c, (cx, cy) = r6_head((0.42, 0.27, 0.19), 12, shirt=(0.75, 0.74, 0.72))
    place(c, "abrasion_1", cx + 30, cy - 150, 260, col("RAW"), 0.05, 0.9)
    place(c, "browcut_2", cx + 66, cy - 98, 104, col("ARTERIAL"), 0.12)
    run_down(c, "rivulet_strip_3", cx + 94, cy - 90, cx + 98, cy + 10, 30, col("ARTERIAL"))
    run_down(c, "rivulet_strip_1", cx + 98, cy + 6, cx + 106, cy + 132, 26, col("ARTERIAL"))
    place(c, "rivulet_bead_2", cx + 106, cy + 136, 26, col("VENOUS"))
    place(c, "wipe_smear_1", cx - 20, cy + 52, 210, col("ARTERIAL_LIGHT"), -0.08, 0.6)
    place(c, "crust_patch_1", cx - 104, cy + 90, 46, col("DRY"), 0.4)
    place(c, "rivulet_fork_2", cx - 4, cy + 50, 64, col("ARTERIAL"), sy=0.8)
    place(c, "spit_1", cx - 140, cy + 230, 90, col("SALIVA"), 0.3)
    return finish(c, 12, flash=False)


def panel_arm():
    c = skin(13)
    place(c, "knuckles_2", 160, 170, 260, col("VENOUS"), 0.0, 0.8)
    place(c, "split_knuckle_1", 160, 150, 230, col("RAW"))
    place(c, "abrasion_2", 330, 370, 420, col("RAW"), -0.2, 0.9)
    place(c, "wipe_smear_2", 140, 420, 230, col("ARTERIAL_LIGHT"), 0.3, 0.55)
    return finish(c, 13)


def dark_cloth(seed):
    return np.clip(cotton(seed) * np.array([0.2, 0.24, 0.34]) / 0.78, 0, 1)


def panel_cloth_v2():
    c = cotton(14)
    place(c, "wick_halo_1", 250, 240, 450, (0.8, 0.55, 0.45), 0.0, 0.45)  # pale plasma fringe (1.25x)
    place(c, "wick_halo_1", 250, 240, 360, col("FABRIC_WET"), 0.0, 0.4)  # wet halo (same size)
    place(c, "soak_2", 250, 240, 360, col("FABRIC_SOAK"))
    place(c, "wick_weave_1", 420, 430, 150, col("FABRIC_WET"), 0.0, 0.4)
    place(c, "soak_3", 420, 430, 150, col("FABRIC_SOAK"))
    return finish(c, 14)


def panel_dark_shirt():
    c = dark_cloth(15)
    place(c, "wick_halo_2", 250, 250, 380, col("FABRIC_WET"), 0.4, 0.7)
    place(c, "soak_1", 250, 250, 380, col("FABRIC_SOAK"), 0.0, 0.8)
    place(c, "wick_halo_1", 420, 420, 160, col("FABRIC_WET"), 1.0, 0.7)
    place(c, "soak_2", 420, 420, 160, col("FABRIC_SOAK"), 1.0, 0.8)
    return finish(c, 15)


def panel_pool_v2():
    c = asphalt(16)
    place(c, "serum_halo_2", 250, 250, 420, col("SERUM"), 1.3, 0.4)
    place(c, "pool_2", 250, 250, 420, col("CLOTTED"), 1.3)
    place(c, "pool_rim_2", 250, 250, 420, col("DRY"), 1.3)
    place(c, "starburst_1", 400, 120, 260, col("VENOUS"), 0.5, 0.9)
    place(c, "drip_pool_2", 400, 120, 90, col("VENOUS"))
    place(c, "ripple_ring_1", 230, 230, 120, (0.55, 0.42, 0.42), 0.0, 0.3)  # (lit by the sky)
    place(c, "starburst_2", 230, 230, 470, col("VENOUS"), 2.0, 0.5)
    return finish(c, 16)


def panel_drag_v2():
    c = asphalt(17)
    place(c, "drag_1", 256, 110, 500, col("VENOUS"), 0.06)
    steps = [("shoe_run_L_1", 120, 470), ("shoe_run_R_1", 220, 380), ("shoe_run_L_1", 330, 300)]
    for i, (n, x, y) in enumerate(steps):
        place(c, n, x, y, 110, col("VENOUS" if i == 0 else "DRYING"), 0.85, 1.0 - 0.25 * i)
    place(c, "spit_2", 430, 440, 110, col("SALIVA"))
    place(c, "crust_patch_2", 440, 250, 70, col("OLD"))
    return finish(c, 17)


def strip(name, n, frames, tint, cell=124):
    """Some frames of an n x n flipbook side by side on a grey card."""
    t = tex(name)
    sz = t.shape[0] // n
    out = np.ones((cell, cell * len(frames), 3), F32) * 0.6
    for k, f in enumerate(frames):
        r, q = divmod(f, n)
        im = Image.fromarray((t[r * sz : (r + 1) * sz, q * sz : (q + 1) * sz] * 255).astype(np.uint8), "RGBA").resize((cell, cell), Image.LANCZOS)
        a = np.asarray(im).astype(F32) / 255
        out[:, k * cell : (k + 1) * cell] = a[..., :3] * np.asarray(tint) * a[..., 3:] + out[:, k * cell : (k + 1) * cell] * (1 - a[..., 3:])
    return out


def panel_flipbooks():
    c = np.ones((P, P, 3), F32) * 0.6
    c[0:124, 0:496] = strip("crown_4x4", 4, [0, 2, 4, 6], col("ARTERIAL"))
    c[126:250, 0:496] = strip("crown_4x4", 4, [8, 10, 12, 15], col("ARTERIAL"))
    c[256:380, 0:496] = strip("pendant_2x2", 2, [0, 1, 2, 3], col("VENOUS"))
    c[386:510, 0:496] = strip("froth_4x4", 4, [0, 5, 10, 15], col("SALIVA"))
    return finish(c, 18, flash=False)


def panel_extreme():
    """Light skin on the left, dark on the right: the extreme wounds. The
    flesh tear is the one picture in colour (tinted white)."""
    c = skin(19)
    Y, X = np.mgrid[0:P, 0:P].astype(F32)
    dark = c * np.array([0.5, 0.42, 0.38]) / np.array([0.76, 0.56, 0.45]) * 0.62
    c = np.where((X > P / 2)[..., None], dark, c)
    place(c, "flesh_tear_1", 130, 300, 260, (1.0, 1.0, 1.0), 0.2)
    place(c, "flesh_tear_2", 390, 300, 230, (1.0, 1.0, 1.0), -0.3)
    place(c, "scalp_split_1", 130, 90, 150, col("ARTERIAL"), 0.0)
    place(c, "scalp_split_1", 390, 90, 130, col("VENOUS"), 2.0)
    return finish(c, 19)


def panel_details_close():
    """The face pictures at 2x (what MIN_ZOOM / the finisher camera shows)."""
    c = skin(20) * 1.05
    place(c, "browcut_2", 150, 90, 230, col("ARTERIAL"), -0.05)
    place(c, "cheekcut_1", 380, 90, 200, col("VENOUS"), 0.0)
    run_down(c, "rivulet_strip_2", 120, 170, 130, 470, 60, col("ARTERIAL"))
    place(c, "rivulet_bead_1", 130, 470, 52, col("VENOUS"))
    run_down(c, "crust_strip_2", 250, 160, 255, 470, 56, col("DRY"))
    place(c, "lipfilm_1", 390, 230, 220, mix("SALIVA", "ARTERIAL", 0.5), 0.0, 0.7)
    place(c, "rivulet_fork_2", 390, 380, 140, col("ARTERIAL"), sy=0.8)
    return finish(c, 20)


PANELS_V2 = [
    ("R6 light skin: brow cut, runs, bead, nose fork, lip, cheek cut + crust", panel_head_light),
    ("R6 dark skin: graze, brow cut, wipe, crust, spit", panel_head_dark),
    ("skin: split knuckles, road rash, wipe", panel_arm),
    ("white cotton: soak + wet halo + fringe, weave", panel_cloth_v2),
    ("dark shirt: soak + wet halo", panel_dark_shirt),
    ("asphalt: old pool + serum, starburst, ripple", panel_pool_v2),
    ("asphalt: drag, running prints, spit, crust", panel_drag_v2),
    ("crown / pendant / froth frames", panel_flipbooks),
    ("EXTREME: scalp split + flesh tear (colour), light / dark skin", panel_extreme),
    ("close-up x2: cuts, run + bead, crust, lip film, fork", panel_details_close),
]


def main_v2(out_dir=None):
    panels = []
    for title, fn in PANELS_V2:
        img = (fn() * 255).astype(np.uint8)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
            Image.fromarray(img).save(os.path.join(out_dir, "v2_" + fn.__name__ + ".png"))
        im = Image.fromarray(img)
        ImageDraw.Draw(im).text((8, 6), title, fill=(255, 255, 255))
        panels.append(np.asarray(im))
    top = np.concatenate([np.concatenate(panels[:5], 1), np.concatenate(panels[5:], 1)], 0)
    sheet = contact_sheet(top.shape[1], V2_FILES)
    full = np.concatenate([top, sheet], 0)
    im = Image.fromarray(full)
    im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
    im = im.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    im.save(os.path.join(SRC, "preview_v2.png"), optimize=True)
    print("preview_v2.png", os.path.getsize(os.path.join(SRC, "preview_v2.png")) // 1024, "KB")


if __name__ == "__main__":
    if "--v2" in sys.argv:
        args = [a for a in sys.argv[1:] if a != "--v2"]
        main_v2(args[0] if args else None)
    else:
        main()
