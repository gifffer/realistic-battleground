# Burn pictures for Config.Injuries.BURN_IMAGES (Dr. Rift's acid and fire),
# drawn by src/client/Combat/RiftBurn.luau on the burnt body parts.
#
#   acid_1..3.png  a chemical burn: raw red-brown flesh where the acid ate
#                  the skin, a darker crusty rim, pale peeling skin, wet
#                  glistening, and runs going down (acid flows)
#   fire_1..3.png  a deep thermal burn: mottled black / brown char over a
#                  large area, lighter blistered and peeled patches with
#                  cracks, glossy, soot fading out at a ragged edge
#   burn_halo.png  a soft halo (white: tinted in the game, soot or redness)
#
# Coloured pictures with alpha (512 x 512), lit like the skin in the game.
# Run from the repo root:
#   venv/bin/python -I tools/burns/make_burns.py [out_dir]
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
from scipy.spatial import cKDTree

N = 512
yy, xx = np.mgrid[0:N, 0:N] / (N - 1) * 2 - 1  # [-1, 1], y down


def value_noise(scale, rng):
    """Smooth random values on a grid `scale` pixels apart."""
    gy, gx = int(N / scale) + 3, int(N / scale) + 3
    grid = rng.random((gy, gx))
    y = np.linspace(0, gy - 3, N)
    x = np.linspace(0, gx - 3, N)
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


def fbm(rng, octaves=5, base=96, gain=0.5):
    """Fractal noise in [0, 1]: `octaves` layers, from `base` pixels down."""
    out = np.zeros((N, N))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        out += value_noise(max(base / 2**o, 1.5), rng) * amp
        total += amp
        amp *= gain
    return out / total


def contrast(field):
    """Stretch a noise to fill [0, 1] (fbm bunches around 0.5)."""
    lo, hi = np.percentile(field, 1), np.percentile(field, 99)
    return np.clip((field - lo) / (hi - lo), 0, 1)


def warp(field, dx, dy):
    """`field` sampled at (x + dx, y + dy) pixels (bilinear)."""
    py, px = np.mgrid[0:N, 0:N].astype(float)
    x = np.clip(px + dx, 0, N - 1.001)
    y = np.clip(py + dy, 0, N - 1.001)
    x0, y0 = x.astype(int), y.astype(int)
    fx, fy = x - x0, y - y0
    a = field[y0, x0]
    b = field[y0, x0 + 1]
    c = field[y0 + 1, x0]
    d = field[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def cells(rng, count):
    """Cellular (Worley) noise: distance to the nearest and second nearest
    of `count` random points (pixels). F2 - F1 is ~0 along the cracks."""
    points = rng.random((count, 2)) * N
    tree = cKDTree(points)
    py, px = np.mgrid[0:N, 0:N]
    dist, _ = tree.query(np.stack([px.ravel(), py.ravel()], -1), k=2)
    return dist[:, 0].reshape(N, N), dist[:, 1].reshape(N, N)


def gloss(height, strength, sharp, light=(-0.45, -0.6, 0.66)):
    """Wet highlights: a light from the top left glinting on a bumpy
    surface (`height`, in pixels), a hard specular lobe."""
    gy, gx = np.gradient(height)
    nx, ny, nz = -gx * strength, -gy * strength, np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / length, ny / length, nz / length
    lx, ly, lz = light
    ll = np.sqrt(lx * lx + ly * ly + lz * lz)
    # half vector between the light and the eye (straight in front)
    hx, hy, hz = lx / ll, ly / ll, lz / ll + 1
    hl = np.sqrt(hx * hx + hy * hy + hz * hz)
    spec = np.clip((nx * hx + ny * hy + nz * hz) / hl, 0, 1) ** sharp
    diffuse = np.clip((nx * lx + ny * ly + nz * lz) / ll, 0, 1)
    return spec, diffuse


def mix(a, b, t):
    t = np.asarray(t)[..., None]
    return a * (1 - t) + b * t


def rgb(*c):
    return np.array(c, float) / 255


def save(img, alpha, path, blur=0.6):
    out = np.concatenate([np.clip(img, 0, 1), np.clip(alpha, 0, 1)[..., None]], -1)
    im = Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    im.save(path)


# --------------------------------------------------------------------------
# Acid
# --------------------------------------------------------------------------

RAW = rgb(134, 56, 46)  # raw, weeping dermis: a dull maroon
RAW_DEEP = rgb(98, 40, 34)  # deeper, darker
RAW_BROWN = rgb(118, 70, 54)  # brownish slough
RAW_RED = rgb(150, 60, 48)  # redder streaks (the dermis split)
PARTIAL = rgb(170, 104, 88)  # only reddened: the skin still there, pinkish tan
CRUST = rgb(70, 30, 24)  # dry dark crust at the margin
PIT = rgb(40, 14, 12)  # eaten deeper: dark pits
PEEL = rgb(200, 172, 150)  # lifted pale skin at the edge
REDNESS = rgb(160, 92, 78)  # inflamed skin around


def acid_shape(rng, band, runs):
    """Where the acid ate. `band`: a wide ragged area longer than wide (it
    went over a limb), else a splash in the upper part. Runs go down from
    it (acid flows), each thinning out to a point. All of it torn up by a
    strong warp and a fine noise: a ragged, broken outline."""
    dens = np.zeros((N, N))
    blobs = []
    count = int(rng.integers(5, 8)) if band else int(rng.integers(3, 6))
    for _ in range(count):
        if band:
            cx, cy = rng.normal(0, 0.12), rng.uniform(-0.5, 0.45)
            rx, ry = rng.uniform(0.45, 0.62), rng.uniform(0.25, 0.42)
        else:
            cx, cy = rng.normal(0, 0.18), rng.uniform(-0.5, -0.05)
            rx, ry = rng.uniform(0.25, 0.48), rng.uniform(0.18, 0.34)
        th = rng.uniform(-0.6, 0.6)
        u = (xx - cx) * np.cos(th) + (yy - cy) * np.sin(th)
        v = -(xx - cx) * np.sin(th) + (yy - cy) * np.cos(th)
        dens = np.maximum(dens, np.exp(-((u / rx) ** 2 + (v / ry) ** 2) ** 1.4))
        blobs.append((cx, cy, rx, ry))
    wiggle = fbm(rng, 3, 120) - 0.5
    for _ in range(runs):
        cx, cy, rx, ry = blobs[int(rng.integers(len(blobs)))]
        x0 = cx + rng.uniform(-0.8, 0.8) * rx
        y0 = cy + ry * 0.4
        y1 = min(y0 + rng.uniform(0.3, 0.75), 0.9)
        w0 = rng.uniform(0.04, 0.09)
        t = np.clip((yy - y0) / (y1 - y0), 0, 1)
        start = smooth(-0.04, 0.04, yy - y0)
        width = w0 * (1 - t) ** 1.3 + 1e-4  # thinning to a point
        x = x0 + wiggle * 0.3 * t + rng.uniform(-0.05, 0.05) * t
        run = np.exp(-(((xx - x) / width) ** 2)) * start * (yy < y1)
        dens = np.maximum(dens, run * 0.95)
    wx = (fbm(rng, 5, 80) - 0.5) * 56
    wy = (fbm(rng, 5, 80) - 0.5) * 36
    dens = warp(dens, wx, wy)
    # (and a finer warp: a torn outline, not a rounded one)
    dens = warp(dens, (fbm(rng, 4, 26) - 0.5) * 26, (fbm(rng, 4, 26) - 0.5) * 26)
    ragged = fbm(rng, 6, 28, 0.62)
    return np.clip(dens * (0.62 + 0.75 * ragged), 0, 1.2)


def streaks(rng, along, across, angle=0.0):
    """Stretched noise in [0, 1] (fibres, runs, streaks): blurred `along`
    pixels one way, `across` the other, turned `angle` radians."""
    field = ndimage.gaussian_filter(rng.random((N, N)), (along, across), mode="wrap")
    if angle:
        field = ndimage.rotate(field, np.degrees(angle), reshape=False, mode="wrap")
    return contrast(field)


def acid(seed, band=False, runs=4, pits_amount=0.5):
    rng = np.random.default_rng(seed)
    dens = acid_shape(rng, band, runs)
    inside = dens > 0.45
    inside = ndimage.binary_opening(inside, iterations=1)
    depth_in = ndimage.distance_transform_edt(inside)  # px from the edge, in
    depth_out = ndimage.distance_transform_edt(~inside)  # px from the edge, out
    border = 1 - smooth(0.88, 0.99, np.maximum(abs(xx), abs(yy)))

    big = contrast(fbm(rng, 4, 70))
    mid = contrast(fbm(rng, 5, 24, 0.55))
    fine = fbm(rng, 3, 4, 0.6)
    grain = contrast(ndimage.gaussian_filter(rng.random((N, N)), 0.8))
    lines = streaks(rng, 22, 2.2, rng.uniform(-0.6, 0.6))
    sw = (mid - 0.5) * 22
    # raw flesh: dull maroon, darker in clumps, brownish slough
    color = mix(RAW, RAW_DEEP, smooth(0.3, 0.8, big * 0.6 + mid * 0.4) * 0.8)
    color = mix(color, RAW_BROWN, smooth(0.45, 0.85, mid) * 0.55)
    # streaks of redder raw flesh (the dermis split in lines)
    fissure = smooth(0.7, 0.9, lines) * smooth(3, 12, depth_in)
    color = mix(color, RAW_RED, fissure * 0.4)
    # in many places only reddened: the skin is still there (pinkish tan
    # islands, mottled), a little see-through
    partial = contrast(warp(fbm(rng, 5, 30, 0.55), sw, -sw))
    partial = smooth(0.45, 0.9, contrast(ndimage.gaussian_filter(partial, 1.5) * 0.75 + 0.25 * lines))
    partial *= smooth(6, 24, depth_in)
    color = mix(color, PARTIAL * (0.88 + 0.22 * grain)[..., None], partial * 0.6)
    # dark eroded pits where it ate deepest, dark runs below them
    pit_field = contrast(fbm(rng, 4, 22, 0.55))
    pits = smooth(0.93 - 0.1 * pits_amount, 0.985 - 0.05 * pits_amount, pit_field)
    pits = pits * smooth(6, 16, depth_in) * (pits_amount > 0)
    trail = ndimage.gaussian_filter(pits, (0.5, 1.2))
    for _ in range(20):  # (smeared downward: the eaten tissue runs)
        trail = np.maximum(trail, np.roll(trail, 3, axis=0) * 0.93)
    trail *= smooth(0.4, 0.75, lines) * inside
    color = mix(color, PIT, np.maximum(pits * 0.92, trail * 0.55))
    ring = smooth(0.0, 0.25, ndimage.gaussian_filter(pits, 3)) * (1 - pits)
    color = mix(color, RAW_RED, ring * 0.4)
    # the margin: a dark crusty band 6-12 px wide, jagged and broken (the
    # acid's front, where the skin coagulated and dried)
    rimw = 6 + 7 * contrast(fbm(rng, 4, 20)) + 4 * (fine - 0.5)
    rim = (depth_in < rimw) * inside
    rim = rim * smooth(0.35, 0.65, contrast(fbm(rng, 4, 7, 0.65)))
    rim = rim * (0.55 + 0.45 * smooth(0.3, 0.6, contrast(fbm(rng, 3, 60))))
    rim = ndimage.gaussian_filter(rim.astype(float), 0.7)
    color = mix(color, CRUST * (0.85 + 0.3 * grain)[..., None], rim * 0.85)
    # and a thin redder line just inside it here and there
    inner = smooth(0, 3, depth_in - rimw) * (1 - smooth(3, 7, depth_in - rimw))
    color = mix(color, RAW_RED, inner * 0.35 * smooth(0.4, 0.7, mid))
    # fine granular texture (weeping tissue is never flat), a bit duller
    color *= (0.88 + 0.2 * fine)[..., None] * (0.93 + 0.12 * grain)[..., None]
    grey = color.mean(-1, keepdims=True)
    color = color * 0.85 + grey * 0.15

    # wet: sparse glints on soft bumps (not on the dry crust)
    height = 4 * fbm(rng, 3, 20, 0.5) + 2.5 * rim - 3 * pits + 1.2 * fissure - 1.0 * partial
    height = ndimage.gaussian_filter(height, 1.8)
    spec, diffuse = gloss(height, 2.4, 90)
    color *= (0.86 + 0.2 * diffuse)[..., None]
    wet = inside * (1 - rim) * (1 - partial * 0.6) * smooth(0.4, 0.75, contrast(fbm(rng, 3, 40)))
    color += (spec * 0.4 * wet)[..., None] * rgb(255, 236, 222)

    # peeling: in a few places the skin lifts in a pale ragged flap just
    # outside the margin, a dark shadow line under it
    peel_where = smooth(0.8, 0.88, contrast(fbm(rng, 3, 50)))
    flap = (depth_out > 0) & (depth_out < 2 + 7 * peel_where * (0.5 + fine)) & (peel_where > 0.05)
    flap = flap * peel_where * (0.6 + 0.4 * fine)
    color = np.where(flap[..., None] > 0.05, mix(color, PEEL * (0.85 + 0.2 * grain)[..., None], flap), color)
    shadow = (depth_out > 0) & (depth_out < 1.6) & (peel_where > 0.3)

    body = smooth(0, 3, depth_in + dens * 2) * inside * (0.97 - 0.45 * partial**1.5)
    alpha = body + flap * 0.6
    alpha = np.where(shadow, np.maximum(alpha, 0.55), alpha)
    color = np.where(shadow[..., None], color * 0.55, color)
    # inflamed skin around it: faint, blotchy, fading out over ~20 px
    halo = (1 - smooth(0, 10 + 18 * big, depth_out)) * (depth_out > 0)
    halo *= 0.3 + 0.7 * mid
    outside = (alpha < 0.25)[..., None]
    color = np.where(outside & (halo[..., None] > 0), REDNESS * (0.9 + 0.15 * fine)[..., None], color)
    alpha = np.where(alpha < 0.25, np.maximum(alpha, halo * 0.3), alpha)
    alpha *= border
    return color, alpha


# --------------------------------------------------------------------------
# Fire
# --------------------------------------------------------------------------

CHAR_BLACK = rgb(26, 16, 16)
CHAR_PURPLE = rgb(54, 32, 36)  # the dark purple-brown of a deep burn
CHAR_BROWN = rgb(76, 46, 36)
SINGED = rgb(104, 64, 48)  # darkened skin between the specks of char
SHEEN = rgb(100, 82, 90)  # peeled, wet, glossy grey-lilac
BLISTER = rgb(150, 120, 112)  # blistered / peeled, greyish tan
FLAKE = rgb(186, 174, 166)  # pale dry flakes of dead skin, greyish
CRACK_RED = rgb(146, 52, 40)  # flesh showing in a crack
SOOT = rgb(70, 46, 36)  # smoke-darkened skin around


def fire(seed, cover=1.0, sheen_amount=1.0, blisters=1.0):
    rng = np.random.default_rng(seed)
    # the burnt area: a big ragged patch, longer than wide (fire runs up a
    # limb), lobes of it reaching further
    dens = np.zeros((N, N))
    for _ in range(int(rng.integers(4, 7))):
        cx, cy = rng.normal(0, 0.2), rng.normal(0, 0.25)
        rx, ry = rng.uniform(0.3, 0.52) * cover, rng.uniform(0.45, 0.75) * cover
        dens = np.maximum(dens, np.exp(-(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2) ** 1.3))
    wx = (fbm(rng, 5, 110) - 0.5) * 70
    wy = (fbm(rng, 5, 110) - 0.5) * 70
    dens = warp(dens, wx, wy)
    level = np.clip(dens * (0.65 + 0.7 * fbm(rng, 6, 48, 0.62)), 0, 1.2)

    big = contrast(fbm(rng, 4, 80))
    mid = contrast(warp(fbm(rng, 5, 30, 0.55), wx * 0.3, wy * 0.3))
    fine = contrast(fbm(rng, 3, 3, 0.7))
    # the char is a stipple (like coffee grounds): dark specks, denser
    # toward the middle of the burn, the singed skin showing between them
    g = contrast(ndimage.gaussian_filter(rng.random((N, N)), 0.7)) * 0.7
    g += 0.3 * contrast(ndimage.gaussian_filter(rng.random((N, N)), 2.5))
    g = 0.25 * streaks(rng, 5, 1.0) + 0.75 * g  # (a grain along the limb)
    cover_field = level * 1.25 - 0.32 + (mid - 0.5) * 0.35
    char = smooth(-0.1, 0.1, cover_field - g)
    under = smooth(0.1, 0.7, level) ** 1.4  # singed skin under the specks
    char_col = mix(CHAR_BROWN, CHAR_PURPLE, smooth(0.25, 0.7, mid * 0.7 + level * 0.4))
    char_col = mix(char_col, CHAR_BLACK, smooth(0.6, 0.95, big * 0.5 + level * 0.6) * 0.7)
    singed = mix(SINGED, CHAR_BROWN, smooth(0.3, 0.9, level) * 0.6) * (0.9 + 0.2 * fine)[..., None]
    color = mix(singed, char_col, char)
    alpha = np.maximum(under * 0.7, char * 0.96)

    # glossy peeled areas in the middle (wet, grey-lilac, shiny)
    sw = (mid - 0.5) * 30
    sheen_field = contrast(ndimage.gaussian_filter(warp(fbm(rng, 5, 60, 0.55), sw, sw), 2))
    # (large zones: the skin came off over a wide area, like photo 7)
    sheen = smooth(0.66 - 0.12 * sheen_amount, 0.9 - 0.08 * sheen_amount, sheen_field)
    sheen *= smooth(0.5, 0.85, level)
    color = mix(color, SHEEN * (0.8 + 0.35 * fine)[..., None], sheen * (0.4 + 0.2 * g))
    alpha = np.maximum(alpha, sheen * 0.85)

    # lighter blistered / peeled patches, crossed by cracks
    patch_field = contrast(warp(fbm(rng, 5, 40, 0.55), wx * 0.5, wy * 0.5))
    patch = smooth(0.9 - 0.04 * blisters, 0.96 - 0.02 * blisters, patch_field)
    patch *= smooth(0.45, 0.75, level)
    color = mix(color, BLISTER * (0.85 + 0.25 * fine)[..., None], patch * 0.85)
    alpha = np.maximum(alpha, patch * 0.95)
    f1, f2 = cells(rng, 300)
    crack_wide = 1 - smooth(0.0, 3.5, f2 - f1)
    color = mix(color, CRACK_RED * 0.8, crack_wide * patch * 0.7)
    crack = (1 - smooth(0.0, 1.6, f2 - f1)) * smooth(0.4, 0.65, contrast(fbm(rng, 3, 50)))
    color = mix(color, CHAR_BLACK * 0.6, crack * char * 0.6)

    # pale dry flakes scattered over the char
    flakes = smooth(0.93, 0.98, contrast(ndimage.gaussian_filter(rng.random((N, N)), 1.3)))
    flakes *= smooth(0.5, 0.9, level) * smooth(0.6, 0.8, contrast(fbm(rng, 3, 30)))
    color = mix(color, FLAKE, flakes * 0.6)
    alpha = np.maximum(alpha, flakes * 0.9)

    # gloss: burnt skin glistens (fluid, grease), most on the peeled areas
    height = 3 * mid + 2 * fine + 4 * sheen + 4 * patch - 2 * crack - 1.5 * crack_wide * patch
    height = ndimage.gaussian_filter(height, 1.2)
    spec, diffuse = gloss(height, 2.4, 30)
    color *= (0.84 + 0.24 * diffuse)[..., None]
    shine = spec * (0.2 + 0.8 * np.maximum(sheen, patch)) * smooth(0.3, 0.7, level)
    color += (shine * 0.42)[..., None] * rgb(255, 242, 232)

    # soot beyond the burn, faint and grainy
    soot = smooth(0.02, 0.35, level) * (0.5 + 0.5 * g)
    color = np.where((alpha < soot * 0.35)[..., None], SOOT, color)
    alpha = np.maximum(alpha, soot * 0.35)
    alpha *= 1 - smooth(0.86, 0.99, np.maximum(abs(xx), abs(yy)))
    return color, alpha


# --------------------------------------------------------------------------
# Halo
# --------------------------------------------------------------------------


def halo(seed):
    """A soft ragged halo (white: tinted in the game)."""
    rng = np.random.default_rng(seed)
    wx = (fbm(rng, 4, 140) - 0.5) * 110
    wy = (fbm(rng, 4, 140) - 0.5) * 110
    r = warp(np.hypot(xx, yy), wx, wy)
    a = np.exp(-((r / 0.62) ** 2.4)) * (0.55 + 0.6 * fbm(rng, 5, 60))
    a *= 1 - smooth(0.82, 0.99, np.hypot(xx, yy))
    return np.ones((N, N, 3)), np.clip(a * 0.85, 0, 1)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/burns/"
    for i, (seed, band, runs, pits) in enumerate([(5, True, 3, 0.2), (17, False, 5, 1.0), (29, True, 2, 0.0)]):
        c, a = acid(seed, band, runs, pits)
        save(c, a, f"{out}/acid_{i + 1}.png")
    for i, (seed, cover, sheen, blis) in enumerate([(7, 1.3, 1.0, 0.6), (19, 1.15, 0.4, 1.6), (31, 1.45, 1.5, 0.3)]):
        c, a = fire(seed, cover, sheen, blis)
        save(c, a, f"{out}/fire_{i + 1}.png")
    c, a = halo(43)
    save(c, a, f"{out}/burn_halo.png", blur=2)


if __name__ == "__main__":
    main()
