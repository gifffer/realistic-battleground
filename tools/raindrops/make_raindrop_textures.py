# Rain-on-the-lens pictures for Config.Weather.SCREEN_RAIN_IMAGES (WeatherFxController).
# Run from the repo root:  python3 tools/raindrops/make_raindrop_textures.py [preview backgrounds...]
#
# Roblox UI cannot bend the picture behind it (no refraction), so every drop is a small
# "physically inspired" render of a water drop sitting on glass, baked into an RGBA picture
# (straight alpha):
#   - a height field (a sphere cap, sagging a little: the drop is fatter at the bottom),
#   - its surface normals give: the refracted view (a drop is a tiny fish-eye lens: it shows
#     the scene UPSIDE DOWN, so the sky is seen at its bottom and the ground at its top),
#     the dark rim where light is totally reflected inside the water (thick at the bottom),
#     the bright caustic crescent inside the bottom rim, the sharp highlight top-left and a
#     small second one.
#   - the inside COVERS a good part of what is behind (a real drop shows its own tiny
#     picture, not the street behind it: a see-through middle reads as a soap bubble),
#   - everything is a little blurred (a camera lens is out of focus), except the highlight.
import sys
import numpy as np
from PIL import Image, ImageFilter

OUT = "assets/raindrops/"
SS = 3  # supersampling (anti-aliased edges)
rng_global = np.random.default_rng(7)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def gblur(a, sigma):
    if sigma <= 0:
        return a
    r = int(3 * sigma) + 1
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    pad = np.pad(a, r, mode="edge")
    tmp = np.apply_along_axis(lambda v: np.convolve(v, k, mode="valid"), 0, pad)
    return np.apply_along_axis(lambda v: np.convolve(v, k, mode="valid"), 1, tmp)


def value_noise(shape, scale, rng):
    gy, gx = int(shape[0] / scale) + 3, int(shape[1] / scale) + 3
    grid = rng.random((gy, gx))
    y = np.linspace(0, gy - 3, shape[0])
    x = np.linspace(0, gx - 3, shape[1])
    yi, xi = np.floor(y).astype(int), np.floor(x).astype(int)
    yf, xf = y - yi, x - xi
    yf = yf * yf * (3 - 2 * yf)
    xf = xf * xf * (3 - 2 * xf)
    a = grid[yi][:, xi]
    b = grid[yi][:, xi + 1]
    c = grid[yi + 1][:, xi]
    d = grid[yi + 1][:, xi + 1]
    top = a + (b - a) * xf[None, :]
    bot = c + (d - c) * xf[None, :]
    return top + (bot - top) * yf[:, None]


def fbm(shape, rng, octaves=4, base=64.0):
    out = np.zeros(shape)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        out += value_noise(shape, base / 2**o, rng) * amp
        total += amp
        amp *= 0.5
    return out / total


# ---------------------------------------------------------------- height fields (pixels)


def cap(xx, yy, cx, cy, rx, ry_top, ry_bot, contact=1.15, wobble=None):
    """Height (in px) of a sphere-cap drop with an egg-shaped footprint.
    contact = contact angle in radians (1.57 = half sphere)."""
    dx = (xx - cx) / rx
    ry = np.where(yy < cy, ry_top, ry_bot)
    dy = (yy - cy) / ry
    r = np.sqrt(dx * dx + dy * dy)
    if wobble is not None:  # irregular outline: radius varies with the angle
        ang = np.arctan2(dy, dx)
        rr = 1.0
        for k, amp, ph in wobble:
            rr = rr + amp * np.cos(k * ang + ph)
        r = r / rr
    return profile(r, contact) * (rx + 0.5 * (ry_top + ry_bot)) / 2  # back to pixels


def profile(r, contact):
    """sphere-cap height at normalized radius r (0 = middle, 1 = edge), in footprint units."""
    s = np.sin(contact)
    rs = 1.0 / s  # sphere radius in footprint units
    h = np.sqrt(np.maximum(rs * rs - np.minimum(r, 1.0) ** 2, 0)) - rs * np.cos(contact)
    return np.where(r < 1.0, h, 0.0)


def smin(a, b, k):
    # smooth minimum of two distance fields: two drops touching merge with a full neck
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def merged_height(xx, yy, parts, k, contact):
    """parts = (cx, cy, r): circles merged into one body of water. Height from the distance
    to the merged outline (so the neck is smooth), scaled by the biggest radius."""
    d = None
    for cx, cy, r in parts:
        di = np.sqrt((xx - cx) ** 2 + ((yy - cy) * np.where(yy < cy, 1.04, 0.93)) ** 2) - r
        d = di if d is None else smin(d, di, k)
    rl = max(p[2] for p in parts)
    e = np.clip(-d / rl, 0, 1)
    # distance to the edge e -> normalized radius (for a lone circle this is exact)
    h = profile(1 - e + 1e-6 * (d >= 0), contact) * rl
    return gblur(h, 3.0 * SS) * (d < 0)


def smax(a, b, k):
    # smooth maximum (merging drops: the neck between them fills in)
    h = np.clip(0.5 + 0.5 * (a - b) / k, 0, 1)
    return a * h + b * (1 - h) + k * h * (1 - h)


def sag(h, yy, cy, r, amount=0.28):
    # gravity: the water slides to the bottom of the drop (peak lower, bottom edge steeper)
    t = np.clip((yy - (cy - r)) / (2 * r), 0, 1)
    return h * (1 - amount + 2 * amount * t)


# ---------------------------------------------------------------- shading


def env(ex, ey, tex=None):
    """The tiny upside-down world a drop shows (it is a fish-eye lens), baked neutral and
    blurred. ey < 0 = the bottom of the drop, which shows the SKY; the rest (the top half or
    so of the drop) shows the street and the buildings, which are dark. The horizon is
    a little below the middle. `tex` = soft blobs (the
    blurred buildings and lights). Returns (RGB, how covering it is)."""
    t = 0.5 + 0.5 * np.tanh(-(ey + 0.12) / 0.2)  # 1 = sky, 0 = street
    ground = 0.065 + 0.03 * np.clip(ey, 0, 1)
    if tex is not None:
        ground = ground + 0.05 * (tex - 0.5)
    sky = 0.33 + 0.08 * np.clip(-ey - 0.5, 0, 1)
    lum = ground * (1 - t) + sky * t
    # (the fish-eye squeezes the sides: a little darker there)
    lum = lum * (1 - 0.18 * np.clip(np.abs(ex) - 0.4, 0, 1))
    rgb = np.stack([lum * 0.95, lum * 0.99, lum * 1.05], -1)
    # the street part hides what is behind more than the pale sky part (at night the sky is
    # dark too, so it must not cover much)
    cover = 0.6 * (1 - t) + 0.34 * t
    return rgb, cover


def over(dst, rgb, a):
    """premultiplied 'over': dst (H,W,4) premult, rgb (H,W,3) straight, a (H,W)"""
    a = np.clip(a, 0, 1)[..., None]
    dst[..., :3] = rgb * a + dst[..., :3] * (1 - a)
    dst[..., 3:] = a + dst[..., 3:] * (1 - a)
    return dst


def blur_prem(prem, sigma):
    out = np.empty_like(prem)
    for c in range(4):
        out[..., c] = gblur(prem[..., c], sigma)
    return out


def shade(h, strength=1.0, body=1.0, rim=0.8, spec=1.0, caustic=0.35, fade=None, defocus=2.2, seed=1):
    """h: height field in (supersampled) pixels. Returns premultiplied RGBA float.

    What makes a real drop on a lens / windshield read as WATER (and not as a soap bubble or
    a glass bead):
      - you do NOT see the scene behind it: you see a tiny blurred upside-down picture
        (dark street at the top, pale sky at the bottom), so the inside covers a lot;
      - its outline is dark (light bounces away at the steep edge), thickest at the bottom
        and on the sides, almost nothing at the top: NO bright ring all around;
      - a lens is out of focus, so the edge is soft (`defocus`, in picture pixels);
      - one small sharp highlight; a soft pale glow inside the bottom edge."""
    H, W = h.shape
    hs = gblur(h, 0.8 * SS)
    gy, gx = np.gradient(hs)
    n = np.stack([-gx, -gy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    nx, ny, nz = n[..., 0], n[..., 1], n[..., 2]
    slope = np.sqrt(np.clip(1 - nz * nz, 0, 1))
    inside = (h > 0).astype(float)
    thick = smooth(0.0, 4.0, h)  # a very thin film (a trail) bends almost nothing
    down = np.clip(ny / np.maximum(slope, 1e-4), 0, 1)  # 1 on the bottom half of the edge
    side = np.abs(nx / np.maximum(slope, 1e-4))
    out = np.zeros((H, W, 4))

    # 1) the upside-down world seen through the drop (soft blobs: blurred buildings / lights)
    rng = np.random.default_rng(seed)
    ex = np.clip(-nx / 0.5, -1.3, 1.3)
    ey = np.clip(-ny / 0.5, -1.3, 1.3)
    blobs = fbm((H, W), rng, 3, 40.0 * SS)
    col, cover = env(ex, ey, blobs)
    out = over(out, col, body * cover * thick * inside * strength)

    # 2) the dark edge (total internal reflection): soft, thick at the bottom and sides
    where = 0.35 + 0.4 * down + 0.25 * side
    tir = smooth(0.35, 0.92, slope) * where
    rimcol = np.zeros((H, W, 3)) + np.array([0.02, 0.025, 0.035])
    out = over(out, rimcol, rim * tir * thick * inside * strength)

    # 3) light focused through the water: a soft pale crescent just inside the bottom edge
    c = np.exp(-(((slope - 0.42) / 0.16) ** 2)) * down**1.5
    out = over(out, np.zeros((H, W, 3)) + np.array([0.86, 0.88, 0.9]), caustic * c * thick * inside * strength)

    if fade is not None:
        out *= fade[..., None]
    # the lens is out of focus: everything above gets a soft edge
    out = blur_prem(out, defocus * SS)

    # 4) highlights (less blurred: they are tiny and very bright): the main light top-left,
    # a faint second one bottom-right
    def half(v):
        v = np.array(v) / np.linalg.norm(v)
        hv = v + np.array([0, 0, 1.0])
        return hv / np.linalg.norm(hv)

    d1 = np.clip(n @ half([-0.45, -0.6, 0.66]), 0, 1)
    d2 = np.clip(n @ half([0.5, 0.4, 0.77]), 0, 1)
    s = d1**420 * 1.0 + d1**60 * 0.07 + d2**700 * 0.35
    hl = np.zeros((H, W, 4))
    hl = over(hl, np.ones((H, W, 3)), np.clip(spec * s, 0, 1) * smooth(1.0, 6.0, h) * strength)
    if fade is not None:
        hl *= fade[..., None]
    hl = blur_prem(hl, 0.35 * defocus * SS)
    a = hl[..., 3:]
    out = hl + out * (1 - a)
    return out


def finish(prem, size):
    """downsample a premultiplied supersampled image to `size` and return straight-alpha PIL."""
    H, W, _ = prem.shape
    im = prem.reshape(H // SS, SS, W // SS, SS, 4).mean(axis=(1, 3))
    a = im[..., 3:]
    rgb = np.where(a > 1e-4, im[..., :3] / np.maximum(a, 1e-4), 0)
    arr = np.concatenate([np.clip(rgb, 0, 1), np.clip(a, 0, 1)], -1)
    arr = (arr * 255 + 0.5).astype(np.uint8)
    # fully transparent pixels: colour = 0 (smaller file, no halo)
    arr[arr[..., 3] == 0, :3] = 0
    img = Image.fromarray(arr, "RGBA")
    if img.size != size:
        img = img.resize(size, Image.LANCZOS)
    return img


def grid(w, h):
    yy, xx = np.mgrid[0 : h * SS, 0 : w * SS].astype(float)
    return xx / SS, yy / SS


# ---------------------------------------------------------------- the drops

D = 256  # drop pictures are 256 x 256


def drop_round():
    xx, yy = grid(D, D)
    c = D / 2
    h = cap(xx, yy, c, c, 100, 98, 104, contact=1.2)
    return shade(sag(h, yy, c, 104))


def drop_egg():
    xx, yy = grid(D, D)
    h = cap(xx, yy, 128, 120, 86, 96, 118, contact=1.15)
    return shade(sag(h, yy, 120, 110, 0.33))


def drop_irregular(seed):
    rng = np.random.default_rng(seed)
    xx, yy = grid(D, D)
    wob = [(k, rng.uniform(0.03, 0.07) / k**0.5, rng.uniform(0, 6.28)) for k in (2, 3, 5)]
    h = cap(xx, yy, 128, 126, 96, 92, 104, contact=1.05, wobble=wob)
    return shade(sag(h, yy, 126, 104))


def drop_merged(parts, k=22.0):
    xx, yy = grid(D, D)
    h = merged_height(xx, yy, parts, k, 1.15)
    return shade(sag(h, yy, 128, 120, 0.22))


# ---------------------------------------------------------------- sliding drop + trail


def streak(seed, w=128, hgt=512):
    rng = np.random.default_rng(seed)
    xx, yy = grid(w, hgt)
    # the drop, at the bottom: a bit pointed upwards (it is running down)
    cy = hgt - 62
    hd = cap(xx, yy, w / 2, cy, 44, 60, 48, contact=1.2)
    hd = sag(hd, yy, cy, 56, 0.36)
    # the trail above it: a thin film of water, narrowing upwards, wandering a little
    t = np.clip((cy - 40 - yy) / (cy - 50), 0, 1)  # 0 just above the drop, 1 at the top
    ph = rng.uniform(0, 6.28, 2)
    wander = (rng.uniform(2, 5) * np.sin(t * rng.uniform(3, 6) + ph[0]) + 1.5 * np.sin(t * 13 + ph[1])) * t
    xc = w / 2 + wander
    # higher up the trail breaks into pieces (1D noise along the trail; the width goes to
    # zero at each break, so every piece has round ends)
    line = value_noise((hgt * SS, 1), 26.0 * SS, rng)[:, :1] * np.ones((1, w * SS))
    keep = smooth(0.12 + 0.6 * t - 0.1, 0.12 + 0.6 * t + 0.1, line)
    keep = np.where(t < 0.3, 1.0, keep)
    top = smooth(8, 40, yy)  # rounded top end
    # (a real trail is not a clean line: its width wobbles, it is about a third of the drop
    # just behind it and thins out higher up)
    ragged = 1 + 0.3 * (value_noise((hgt * SS, 1), 30.0 * SS, rng)[:, :1] - 0.5)
    halfw = (15 * (1 - t) ** 1.5 + 2.2) * ragged * np.sqrt(keep * top)
    d = np.abs(xx - xc) / np.maximum(halfw, 1e-3)
    film = np.sqrt(np.clip(1 - d * d, 0, 1)) * halfw * 0.45 * (halfw > 0.4)
    film = film * (yy < cy - 20)
    h = np.maximum(hd, film)
    # the beads left behind on the path
    ys = yy[:, 0]
    for i in range(int(rng.integers(5, 9))):
        tb = rng.uniform(0.35, 0.97)
        by = cy - 40 - tb * (cy - 50)
        row = int(np.argmin(np.abs(ys - by)))
        bx = float(xc[row, 0]) + rng.uniform(-2, 2)
        br = rng.uniform(2.2, 5.0) * (1.15 - 0.5 * tb)
        h = np.maximum(h, cap(xx, yy, bx, by, br, br * 0.95, br * 1.1, contact=1.25))
    h = gblur(h, 0.8 * SS) * (h > 0.05)
    # the trail fades out towards the top (it dries from the top)
    fade = np.where(yy > cy - 40, 1.0, 1 - 0.65 * t)
    return shade(h, rim=0.8, fade=fade, defocus=1.6, seed=seed)


# ---------------------------------------------------------------- mist (fine spray) sheets


def sprite(contact=1.25, size=48):
    xx, yy = grid(size, size)
    c = size / 2
    h = cap(xx, yy, c, c, size * 0.42, size * 0.41, size * 0.44, contact=contact)
    # (tiny droplets: lighter inside, or they read as holes / pores)
    return shade(sag(h, yy, c, size * 0.44), body=0.4, rim=0.5, spec=0.9, caustic=0.35, defocus=2.2)


def sprite_img(prem):
    H, W, _ = prem.shape
    return prem.reshape(H // SS, SS, W // SS, SS, 4).mean(axis=(1, 3))


def mist(seed, w=1024, h=512, count=1500, big=24):
    rng = np.random.default_rng(seed)
    base = [sprite_img(sprite(c)) for c in (1.0, 1.2, 1.4)]
    canvas = np.zeros((h, w, 4))
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    # density: dense at the edges and the corners, empty in the middle
    ex = np.abs(xx / w - 0.5) * 2
    ey = np.abs(yy / h - 0.5) * 2
    edge = np.clip(np.maximum(ex**3.2, ey**3.5 * 0.75) * 1.1, 0, 1)
    cloud = fbm((h, w), rng, 4, 160.0)
    dens = edge * smooth(0.25, 0.75, cloud * 0.8 + edge * 0.4)
    # faint haze of micro droplets (lowers the contrast at the edges, like a misted lens)
    haze = gblur(dens, 6) * 0.05
    canvas = over(canvas, np.zeros((h, w, 3)) + 0.82, haze)
    flat = dens.ravel() / dens.sum()
    n = count + big
    picks = rng.choice(flat.size, size=n, p=flat)
    py, px = np.divmod(picks, w)
    sizes = np.concatenate([2.5 + rng.pareto(2.8, count) * 2.0, rng.uniform(8, 15, big)])
    sizes = np.clip(sizes, 2.5, 18)
    order = np.argsort(-sizes)  # small ones on top
    for i in order:
        s = int(round(sizes[i] * rng.uniform(0.9, 1.1)))
        sy = int(round(s * rng.uniform(1.0, 1.15)))
        spr = base[rng.integers(0, 3)]
        raw = (np.clip(spr, 0, 1) * 255).astype(np.uint8)
        # ("RGBa" = premultiplied: resized without darkening the edges)
        im = Image.frombytes("RGBa", (raw.shape[1], raw.shape[0]), raw.tobytes())
        im = im.resize((max(s, 2), max(sy, 2)), Image.LANCZOS)
        a = np.asarray(im).astype(float) / 255 * 0.85
        x0, y0 = int(px[i]) - s // 2, int(py[i]) - sy // 2
        x1, y1 = x0 + a.shape[1], y0 + a.shape[0]
        cx0, cy0, cx1, cy1 = max(x0, 0), max(y0, 0), min(x1, w), min(y1, h)
        if cx1 <= cx0 or cy1 <= cy0:
            continue
        a = a[cy0 - y0 : cy1 - y0, cx0 - x0 : cx1 - x0]
        dst = canvas[cy0:cy1, cx0:cx1]
        canvas[cy0:cy1, cx0:cx1] = a + dst * (1 - a[..., 3:])
    return canvas


def to_img(prem):
    a = prem[..., 3:]
    rgb = np.where(a > 1e-4, prem[..., :3] / np.maximum(a, 1e-4), 0)
    arr = (np.concatenate([np.clip(rgb, 0, 1), np.clip(a, 0, 1)], -1) * 255 + 0.5).astype(np.uint8)
    arr[arr[..., 3] == 0, :3] = 0
    return Image.fromarray(arr, "RGBA")


# ---------------------------------------------------------------- wet glass smear


def wet(seed, w=512, h=256):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    ex = np.abs(xx / w - 0.5) * 2
    ey = np.abs(yy / h - 0.5) * 2
    edge = smooth(0.35, 1.0, np.sqrt(ex**2 * 0.9 + ey**2 * 0.7))
    # smears: noise stretched vertically (water running down the glass)
    n1 = fbm((h // 4 + 1, w), rng, 4, 24.0)
    n1 = np.asarray(Image.fromarray((n1 * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)) / 255
    n2 = fbm((h, w), rng, 4, 48.0)
    film = smooth(0.42, 0.7, n1 * 0.6 + n2 * 0.4)
    gy, gx = np.gradient(gblur(film, 2.0))
    ridge = np.clip(np.sqrt(gx * gx + gy * gy) * 9, 0, 1)
    out = np.zeros((h, w, 4))
    # a light milky veil (scattered light in the water film) + darker film edges
    out = over(out, np.zeros((h, w, 3)) + np.array([0.78, 0.82, 0.86]), 0.08 * film * edge)
    out = over(out, np.zeros((h, w, 3)) + np.array([0.08, 0.09, 0.11]), 0.16 * ridge * edge)
    # light catching the top edge of a smear
    lit = np.clip(-gy * 14, 0, 1) * edge
    out = over(out, np.ones((h, w, 3)), 0.12 * lit)
    # (out of focus, like everything on the lens)
    return to_img(blur_prem(out, 1.2))


# ---------------------------------------------------------------- run

if __name__ == "__main__":
    import os

    os.makedirs(OUT, exist_ok=True)
    drops = {
        "drop_round.png": drop_round(),
        "drop_egg.png": drop_egg(),
        "drop_irregular.png": drop_irregular(3),
        "drop_merged_2.png": drop_merged([(100, 140, 60), (168, 114, 50)]),
        "drop_merged_3.png": drop_merged([(94, 102, 46), (160, 124, 54), (116, 178, 40)]),
    }
    for name, prem in drops.items():
        finish(prem, (D, D)).save(OUT + name, optimize=True)
    for i, seed in enumerate((11, 23, 37)):
        finish(streak(seed), (128, 512)).save(OUT + f"streak_{i + 1}.png", optimize=True)
    to_img(mist(5)).save(OUT + "mist_1.png", optimize=True)
    to_img(mist(9, count=900, big=45)).save(OUT + "mist_2.png", optimize=True)
    wet(4).save(OUT + "wet_glass.png", optimize=True)
    print("done")
