# Bruise pictures for Config.Injuries.BRUISE_IMAGES (grey, tinted in game).
# Run from the repo root: python3 tools/bruises/make_bruise_textures.py
import sys
import numpy as np
from PIL import Image, ImageFilter
N = 512
def value_noise(shape, scale, rng):
    gy, gx = int(shape[0] / scale) + 3, int(shape[1] / scale) + 3
    grid = rng.random((gy, gx))
    y = np.linspace(0, gy - 3, shape[0]); x = np.linspace(0, gx - 3, shape[1])
    yi, xi = np.floor(y).astype(int), np.floor(x).astype(int)
    yf, xf = y - yi, x - xi
    yf = yf * yf * (3 - 2 * yf); xf = xf * xf * (3 - 2 * xf)
    a = grid[yi][:, xi]; b = grid[yi][:, xi + 1]; c = grid[yi + 1][:, xi]; d = grid[yi + 1][:, xi + 1]
    top = a + (b - a) * xf[None, :]; bot = c + (d - c) * xf[None, :]
    return top + (bot - top) * yf[:, None]
def fbm(rng, octaves=5, base=96, gain=0.5):
    out = np.zeros((N, N)); amp = 1; total = 0
    for o in range(octaves):
        out += value_noise((N, N), base / 2 ** o, rng) * amp; total += amp; amp *= gain
    return out / total
def warp(field, dx, dy):
    # sample field at (x+dx, y+dy) pixels, bilinear
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    x = np.clip(xx + dx, 0, N - 1.001); y = np.clip(yy + dy, 0, N - 1.001)
    x0, y0 = x.astype(int), y.astype(int); fx, fy = x - x0, y - y0
    a = field[y0, x0]; b = field[y0, x0 + 1]; c = field[y0 + 1, x0]; d = field[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)
yy, xx = np.mgrid[0:N, 0:N] / (N - 1) * 2 - 1

def blob(seed, stretch=1.0, lobes=2):
    """A bruise: blood spread under the skin. Densest in one or two soft
    cores, fading over a long way into the skin, broken up by organic,
    domain-warped mottling; no hard outline."""
    rng = np.random.default_rng(seed)
    X, Y = xx * stretch, yy / stretch
    # a few overlapping soft cores (blood pools unevenly)
    dens = np.zeros((N, N))
    for k in range(lobes + 1):
        cx, cy = rng.normal(0, 0.16, 2)
        rx, ry = rng.uniform(0.42, 0.58), rng.uniform(0.36, 0.5)
        th = rng.uniform(0, np.pi)
        u = (X - cx) * np.cos(th) + (Y - cy) * np.sin(th)
        v = -(X - cx) * np.sin(th) + (Y - cy) * np.cos(th)
        d2 = (u / rx) ** 2 + (v / ry) ** 2
        dens = np.maximum(dens, np.exp(-(d2 ** 1.15) * 0.75) * rng.uniform(0.85, 1.0))
    # warp the whole thing so the outline is ragged and organic
    wx = (fbm(rng, 5, 160) - 0.5) * 70; wy = (fbm(rng, 5, 160) - 0.5) * 70
    dens = warp(dens, wx, wy)
    # finer warp + breakup toward the edge
    edgeNoise = fbm(rng, 6, 70, 0.55)
    dens = dens * (0.8 + 0.45 * edgeNoise)
    dens = np.clip(dens, 0, 1.2)
    # long, soft falloff to zero at the image border
    border = 1 - smooth(0.8, 0.98, np.hypot(xx, yy))
    alpha = np.clip(dens / 0.9, 0, 1) ** 1.5 * border
    # mottling inside: darker clots and lighter gaps (veiny, warped)
    m = fbm(rng, 4, 80, 0.5)
    m = warp(m, wx * 0.5, wy * 0.5)
    clots = smooth(0.45, 0.72, m)
    alpha = np.clip(alpha * (0.82 + 0.3 * clots), 0, 1)
    shade = 1 - 0.32 * clots * smooth(0.15, 0.7, dens)   # darker where clotted
    shade = shade - 0.12 * smooth(0.6, 1.1, dens)        # deeper in the core
    shade = np.clip(shade, 0.35, 1)
    rgb = np.stack([shade] * 3, -1)
    img = np.concatenate([rgb, alpha[..., None] * 0.9], -1)
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGBA")
    return im.filter(ImageFilter.GaussianBlur(2.5))

def rim(seed):
    """The faint wide halo (the edge where the blood is spreading / healing)."""
    rng = np.random.default_rng(seed)
    wx = (fbm(rng, 4, 150) - 0.5) * 120; wy = (fbm(rng, 4, 150) - 0.5) * 120
    r = warp(np.hypot(xx, yy), wx, wy)
    ring = np.exp(-(r / 0.55) ** 2.2)
    alpha = np.clip(ring * (0.55 + 0.6 * fbm(rng, 4, 90)), 0, 1)
    alpha *= 1 - smooth(0.82, 0.98, np.hypot(xx, yy))
    rgb = np.ones((N, N, 3))
    return Image.fromarray((np.concatenate([rgb, alpha[..., None]], -1) * 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(3))

def petechiae(seed):
    """Pinpoint bleeding: tiny soft specks, clustered in a few patches."""
    rng = np.random.default_rng(seed)
    a = np.zeros((N, N))
    clusters = [(rng.uniform(0, 6.28), rng.uniform(0.25, 0.55)) for _ in range(3)]
    for ang, rad in clusters:
        ccx, ccy = rad * np.cos(ang), rad * np.sin(ang)
        for _ in range(int(rng.integers(10, 18))):
            cx, cy = ccx + rng.normal(0, 0.09), ccy + rng.normal(0, 0.09)
            s = rng.uniform(0.004, 0.011)
            d = np.hypot(xx - cx, yy - cy) / s
            a = np.maximum(a, np.exp(-d * d) * rng.uniform(0.35, 0.8))
    rgb = np.ones((N, N, 3))
    return Image.fromarray((np.concatenate([rgb, a[..., None]], -1) * 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(0.8))

out = sys.argv[1] if len(sys.argv) > 1 else "assets/bruises/"
for i, (seed, st, lobes) in enumerate([(11, 1.0, 2), (23, 1.2, 3), (37, 0.85, 1), (51, 1.05, 2)]):
    blob(seed, st, lobes).save(out + f"bruise_{i + 1}.png")
rim(71).save(out + "bruise_rim.png")
petechiae(83).save(out + "bruise_petechiae.png")
