# Blood pictures for Config.Blood.IMAGES (grey, tinted in game by Decal.Color3).
# Run from the repo root:  python3 tools/blood/make_blood_textures.py
# Then look at the result:  python3 tools/blood/preview.py   (-> assets/blood/preview.png)
#
# How the pictures work (read this before changing anything):
# - Every PNG is RGBA with *straight* alpha. The colour channels are the same
#   grey value: a THICKNESS map. White (1.0) = a thin film of blood, dark
#   (~0.35) = thick blood. The game multiplies this grey by a palette colour
#   (Config.Blood.PALETTE), so thin blood comes out lighter red and thick blood
#   almost black-red, like in real photos. No colour is baked in.
# - Alpha = where there is blood, with a sharp 1 px antialiased edge (fresh
#   blood has a crisp, rounded edge because of surface tension - no blur).
# - Under transparent pixels we copy the nearest edge grey ("colour bleed"),
#   otherwise Roblox's smaller mipmaps would get a dark or white fringe.
# - Directional stains travel toward +X (to the right). Their parent drop centre
#   sits at 35 % of the width (ANCHOR_X = 0.35) and they already contain some
#   stretch (see BAKED_ASPECT in the report printed at the end).
# - Shapes are signed distance fields (SDF): circles, ellipses and tapered
#   capsules glued with a "smooth minimum", which makes the rounded necks a real
#   liquid makes between two drops. A gentle noise warp makes outlines organic.
# - Everything is seeded: running it twice gives the same files.
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/blood"
F32 = np.float32
THICK_L = 0.35  # grey of the thickest blood (white = thinnest film)


# ---------------------------------------------------------------- noise ----
def noise(rng, shape, sigma, wrap=False):
    """Smooth random field, about unit standard deviation. sigma = blob size (px).
    sigma can be a (sy, sx) pair for stretched (anisotropic) noise."""
    n = rng.standard_normal(shape).astype(F32)
    n = ndi.gaussian_filter(n, sigma, mode="wrap" if wrap else "reflect")
    return n / (n.std() + 1e-6)


def fbm(rng, shape, octaves, wrap=False):
    """Sum of several noise sizes: octaves = [(sigma, weight), ...]."""
    out = np.zeros(shape, F32)
    tot = 0.0
    for s, g in octaves:
        out += g * noise(rng, shape, s, wrap)
        tot += g * g
    return out / np.sqrt(tot)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ SDF ----
def smin(a, b, k):
    """Smooth minimum (Inigo Quilez): unions two shapes with a rounded neck of
    radius ~k pixels, like the meniscus between two touching drops."""
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def harm_mod(th, harm):
    m = 1.0
    for n, amp, ph in harm:
        m = m + amp * np.cos(n * th + ph)
    return m


def random_harm(rng, bands):
    """Edge wobble: bands = [(nmin, nmax, amp), ...] -> list of harmonics."""
    out = []
    for nmin, nmax, amp in bands:
        for _ in range(2):
            out.append((int(rng.integers(nmin, nmax + 1)), amp * rng.uniform(0.5, 1.0), rng.uniform(0, 6.283)))
    return out


def circle(cx, cy, r, harm=(), weight=None):
    def fn(X, Y):
        dx, dy = X - cx, Y - cy
        th = np.arctan2(dy, dx)
        m = harm_mod(th, harm) - 1.0
        if weight is not None:
            m = m * weight(th)
        return np.hypot(dx, dy) - r * (1.0 + m)

    return fn, (cx - r * 1.3, cy - r * 1.3, cx + r * 1.3, cy + r * 1.3)


def ellipse(cx, cy, a, b, ang=0.0, harm=(), weight=None):
    """a = half length along the angle `ang`, b = half width."""
    c, s = np.cos(ang), np.sin(ang)

    def fn(X, Y):
        dx, dy = X - cx, Y - cy
        u, v = dx * c + dy * s, -dx * s + dy * c
        th = np.arctan2(v / b, u / a)
        m = harm_mod(th, harm) - 1.0
        if weight is not None:
            m = m * weight(th)
        q = np.hypot(u / a, v / b) + 1e-4
        g = np.hypot(u / (a * a), v / (b * b)) / q + 1e-6
        return (q / (1.0 + m) - 1.0) / g

    r = max(a, b) * 1.3
    return fn, (cx - r, cy - r, cx + r, cy + r)


def ucap(x1, y1, r1, x2, y2, r2):
    """Tapered capsule from (x1,y1) radius r1 to (x2,y2) radius r2."""
    h = max(np.hypot(x2 - x1, y2 - y1), 1e-3)
    ax, ay = (x2 - x1) / h, (y2 - y1) / h
    b = np.clip((r1 - r2) / h, -0.98, 0.98)
    a = np.sqrt(1 - b * b)

    def fn(X, Y):
        dx, dy = X - x1, Y - y1
        py = dx * ax + dy * ay
        px = np.abs(-dx * ay + dy * ax)
        k = -b * px + a * py
        d1 = np.hypot(px, py) - r1
        d2 = np.hypot(px, py - h) - r2
        d3 = a * px + b * py - r1
        return np.where(k < 0, d1, np.where(k > a * h, d2, d3))

    m = max(r1, r2)
    return fn, (min(x1, x2) - m, min(y1, y2) - m, max(x1, x2) + m, max(y1, y2) + m)


class Shape:
    """A canvas holding one signed distance field D (pixels, <0 inside)."""

    def __init__(self, w, h, rng, warps=((30, 4.0), (8, 1.4)), wrap_x=False):
        self.w, self.h = w, h
        Y, X = np.mgrid[0:h, 0:w].astype(F32) + 0.5
        dx = np.zeros((h, w), F32)
        dy = np.zeros((h, w), F32)
        for s, amp in warps:
            dx += amp * noise(rng, (h, w), s, wrap_x)
            dy += amp * noise(rng, (h, w), s, wrap_x)
        self.X, self.Y = X + dx, Y + dy
        self.wmax = 3 * sum(a for _, a in warps) + 3
        self.D = np.full((h, w), 1e4, F32)

    def add(self, prim, k=0.0, sub=False):
        fn, (x0, y0, x1, y1) = prim
        m = k + self.wmax
        ix0, iy0 = max(0, int(x0 - m)), max(0, int(y0 - m))
        ix1, iy1 = min(self.w, int(x1 + m) + 1), min(self.h, int(y1 + m) + 1)
        if ix0 >= ix1 or iy0 >= iy1:
            return
        win = (slice(iy0, iy1), slice(ix0, ix1))
        d = fn(self.X[win], self.Y[win]).astype(F32)
        if sub:
            self.D[win] = np.maximum(self.D[win], -d)
        else:
            self.D[win] = smin(self.D[win], d, k)

    def chain(self, pts, k=4.0):
        """A tapered tube through points [(x, y, r), ...]."""
        for (xa, ya, ra), (xb, yb, rb) in zip(pts[:-1], pts[1:]):
            self.add(ucap(xa, ya, ra, xb, yb, rb), k)

    def alpha(self):
        return np.clip(0.5 - self.D, 0, 1)


def depth_of(alpha):
    """Distance (px) from each inside pixel to the edge."""
    return ndi.distance_transform_edt(alpha >= 0.5).astype(F32)


def meniscus(depth, lam):
    """Film thickness 0..1: thin at the edge, saturating inside (a puddle is
    flat-topped, its edge rounded by surface tension over ~lam pixels)."""
    return 1 - np.exp(-depth / lam)


def lum(t):
    """Thickness 0..1 -> grey: thin = white, thick = THICK_L."""
    return 1 - (1 - THICK_L) * np.clip(t, 0, 1)


# ---------------------------------------------------------------- output ---
SIZES = {}


def to_rgba(L, A):
    """Floats -> uint8 RGBA with colour bleed under transparent pixels."""
    A8 = np.round(np.clip(A, 0, 1) * 255).astype(np.uint8)
    L = np.clip(L, 0, 1)
    inside = A8 > 0
    if inside.any() and not inside.all():
        idx = ndi.distance_transform_edt(~inside, return_distances=False, return_indices=True)
        L = np.where(inside, L, L[idx[0], idx[1]])
    # 7-bit grey is plenty after tinting and makes the PNGs much smaller.
    L8 = (np.round(L * 127) * 2).astype(np.uint8)
    return np.dstack([L8, L8, L8, A8])


def fade_border(rgba, px=6):
    """Fade alpha to 0 over the last few pixels of the image, so a mark that
    runs off the canvas never ends in a straight cut."""
    h, w = rgba.shape[:2]
    yy = np.minimum(np.arange(h), np.arange(h)[::-1])[:, None]
    xx = np.minimum(np.arange(w), np.arange(w)[::-1])[None, :]
    f = smooth(0, px, np.minimum(yy, xx).astype(F32))
    out = rgba.copy()
    out[..., 3] = np.round(out[..., 3] * f).astype(np.uint8)
    return out


def save(name, rgba):
    if name != "beam_stream":  # the beam tiles along X: no fade
        rgba = fade_border(rgba, 12 if name.startswith(("smear", "skin_smear")) else 3)
    path = os.path.join(OUT, name + ".png")
    Image.fromarray(rgba, "RGBA").save(path, optimize=True, compress_level=9)
    SIZES[name] = (os.path.getsize(path), rgba.shape[1], rgba.shape[0])


def grid(cells, n):
    """Flipbook: n x n cells (already RGBA), row by row from the top left."""
    cells = [fade_border(c, 3) for c in cells]
    rows = [np.concatenate(cells[r * n : (r + 1) * n], axis=1) for r in range(n)]
    return np.concatenate(rows, axis=0)


# ------------------------------------------------------- shared painters ---
def satellite(S, rng, x, y, r, ang, tail_p=0.4, k=2.0):
    """A small droplet moving toward `ang`: slightly stretched, sometimes with a
    tiny tail pointing the way it travelled."""
    asp = rng.uniform(1.0, 1.6)
    S.add(ellipse(x, y, r * asp, r, ang), k)
    if r > 2.2 and rng.random() < tail_p:
        L = r * rng.uniform(1.2, 2.6)
        S.add(ucap(x, y, r * 0.55, x + np.cos(ang) * (r * asp + L), y + np.sin(ang) * (r * asp + L), max(0.7, r * 0.18)), 1.5)


def spine(S, rng, cx, cy, ang, r0, R, length, width, bulb_p=0.6):
    """A spike shooting out of an impact stain, often ending in a little bulb."""
    x1, y1 = cx + np.cos(ang) * r0, cy + np.sin(ang) * r0
    x2, y2 = cx + np.cos(ang) * (r0 + length), cy + np.sin(ang) * (r0 + length)
    tip = max(1.0, width * rng.uniform(0.25, 0.45))
    S.add(ucap(x1, y1, width, x2, y2, tip), 4.0)
    if rng.random() < bulb_p:
        br = tip * rng.uniform(1.3, 2.2)
        gap = rng.uniform(-0.5, 1.8) * br
        S.add(circle(x2 + np.cos(ang) * gap, y2 + np.sin(ang) * gap, br), 2.5)


def impact_thickness(rng, alpha, R, lam=3.5):
    """Thickness of a fresh impact stain: thin meniscus at the edge, a thick
    ring where the spreading blood piled up (the 'rim' of the lamella), a
    slightly thinner middle, and a little unevenness."""
    d = depth_of(alpha)
    t = meniscus(d, lam)
    ring = np.exp(-(((d - 0.16 * R) / (0.09 * R)) ** 2))
    mid = smooth(0.25 * R, 0.7 * R, d)
    n = noise(rng, alpha.shape, max(3, R * 0.15))
    t = t * (0.8 + 0.2 * ring - 0.1 * mid + 0.05 * n)
    return np.clip(t, 0, 1)


def edge_alpha(alpha, t):
    """The thinnest film at an edge lets a little of the surface show through."""
    return alpha * (0.86 + 0.14 * smooth(0.05, 0.5, t))


# ============================================================== SET A =====
def spatter_round(seed, N=512):
    rng = np.random.default_rng(seed)
    S = Shape(N, N, rng, warps=((26, 3.0), (7, 1.1)))
    cx = cy = N * 0.5
    R = N * rng.uniform(0.15, 0.18)
    harm = random_harm(rng, [(4, 7, 0.03), (10, 16, 0.022), (22, 34, 0.01)])
    S.add(circle(cx, cy, R, harm))
    for _ in range(int(rng.integers(6, 15))):
        a = rng.uniform(0, 2 * np.pi)
        spine(S, rng, cx, cy, a, R * 0.85, R, R * rng.uniform(0.18, 0.62), R * rng.uniform(0.05, 0.1))
    for _ in range(int(rng.integers(10, 26))):
        a = rng.uniform(0, 2 * np.pi)
        d = R * rng.uniform(1.2, 1.85)
        r = R * np.clip(rng.lognormal(np.log(0.035), 0.5), 0.012, 0.09)
        satellite(S, rng, cx + np.cos(a) * d, cy + np.sin(a) * d, r, a)
    A = S.alpha()
    t = impact_thickness(rng, A, R)
    return to_rgba(lum(t), edge_alpha(A, t))


def front_weight(th):
    # stronger edge wobble / spines on the leading (+X) side
    return 0.3 + 0.7 * np.clip(np.cos(th), 0, 1)


def spatter_oval(seed, N=512):
    rng = np.random.default_rng(seed)
    S = Shape(N, N, rng, warps=((26, 3.0), (7, 1.1)))
    cx, cy = N * 0.35, N * 0.5
    b = N * rng.uniform(0.12, 0.14)
    asp = rng.uniform(1.3, 1.45)
    a = b * asp
    harm = random_harm(rng, [(4, 7, 0.035), (10, 18, 0.03), (24, 34, 0.012)])
    S.add(ellipse(cx, cy, a, b, 0, harm, front_weight))
    for _ in range(int(rng.integers(5, 11))):
        ang = rng.normal(0, 0.55)
        ang = np.clip(ang, -1.3, 1.3)
        rr = np.hypot(a * np.cos(ang), b * np.sin(ang))
        L = b * rng.uniform(0.2, 0.75) * (0.4 + 0.6 * np.cos(ang))
        spine(S, rng, cx, cy, ang, rr * 0.9, b, L, b * rng.uniform(0.05, 0.1))
    for _ in range(int(rng.integers(1, 4))):
        x = cx + a + b * rng.uniform(0.5, 1.6)
        y = cy + rng.normal(0, b * 0.35)
        satellite(S, rng, x, y, b * rng.uniform(0.05, 0.11), np.arctan2(y - cy, x - cx) * 0.4, tail_p=0.9)
    for _ in range(int(rng.integers(4, 10))):
        ang = rng.normal(0, 0.7)
        d = rng.uniform(1.15, 1.6)
        x, y = cx + np.cos(ang) * a * d, cy + np.sin(ang) * b * d
        satellite(S, rng, x, y, b * rng.uniform(0.015, 0.045), ang * 0.6)
    A = S.alpha()
    t = impact_thickness(rng, A, b)
    return to_rgba(lum(t), edge_alpha(A, t))


def spatter_tail(seed, N=512):
    """The 'exclamation mark': an elongated body, a narrowing tail toward +X
    and a detached drop at the tip (wave cast-off)."""
    rng = np.random.default_rng(seed)
    S = Shape(N, N, rng, warps=((26, 2.5), (7, 0.9)))
    cx, cy = N * 0.35, N * 0.5
    b = N * rng.uniform(0.07, 0.085)
    a = b * rng.uniform(1.9, 2.3)
    harm = random_harm(rng, [(4, 6, 0.02), (12, 18, 0.02)])
    S.add(ellipse(cx, cy, a, b, 0, harm, front_weight))
    # the tail: a slightly wavy tapered tube
    x0 = cx + a * 0.55
    xe = N * rng.uniform(0.74, 0.8)
    n = 6
    bend = rng.normal(0, b * 0.25)
    pts = []
    for i in range(n + 1):
        f = i / n
        x = x0 + (xe - x0) * f
        y = cy + bend * np.sin(f * np.pi) + rng.normal(0, 0.8)
        r = b * 0.62 * (1 - f) ** 1.3 + 1.6
        pts.append((x, y, r))
    S.chain(pts, k=6)
    # wave cast-off: the detached drop
    gx = xe + b * rng.uniform(0.4, 0.9)
    satellite(S, rng, gx + b * 0.3, pts[-1][1], b * rng.uniform(0.18, 0.28), 0.0, tail_p=0.5)
    for _ in range(int(rng.integers(2, 6))):
        ang = rng.normal(0, 0.9)
        x, y = cx + np.cos(ang) * a * rng.uniform(1.15, 1.5), cy + np.sin(ang) * b * rng.uniform(1.3, 2.0)
        satellite(S, rng, x, y, b * rng.uniform(0.03, 0.08), ang * 0.3)
    A = S.alpha()
    d = depth_of(A)
    t = meniscus(d, 3.5) * (0.85 + 0.15 * smooth(0, b * 0.5, d)) + 0.04 * noise(rng, A.shape, 6)
    # the body is thickest toward its front (blood piles up before the tail)
    t = t * (0.9 + 0.1 * smooth(cx - a, cx + a, S.X))
    t = np.clip(t, 0, 1)
    return to_rgba(lum(t), edge_alpha(A, t))


def spatter_streak(seed, N=512):
    """A grazing impact: long tapered streak, beaded thin line, breakaway drops."""
    rng = np.random.default_rng(seed)
    S = Shape(N, N, rng, warps=((30, 2.0), (6, 0.7)))
    cx, cy = N * 0.35, N * 0.5
    b = N * rng.uniform(0.034, 0.042)
    a = b * rng.uniform(2.6, 3.2)
    S.add(ellipse(cx, cy, a, b, 0, random_harm(rng, [(10, 16, 0.02)])))
    xe = N * rng.uniform(0.7, 0.78)
    pts = []
    n = 8
    drift = rng.normal(0, b * 0.5)
    for i in range(n + 1):
        f = i / n
        pts.append((cx + a * 0.4 + (xe - cx - a * 0.4) * f, cy + drift * f * f + rng.normal(0, 0.4), b * 0.85 * (1 - f) ** 1.1 + 1.2))
    S.chain(pts, k=5)
    # beaded thread: drops along a line that thins out
    x, y = pts[-1][0], pts[-1][1]
    r = 2.6
    while x < N * 0.95:
        x += rng.uniform(5, 13)
        y += rng.normal(0, 0.8) + drift * 0.02
        S.add(ellipse(x, y, r * rng.uniform(1.1, 1.8), r, 0), 2.0)
        r = max(0.9, r * rng.uniform(0.82, 0.98))
    for _ in range(int(rng.integers(3, 8))):
        bx = rng.uniform(cx, N * 0.9)
        by = cy + rng.choice([-1, 1]) * rng.uniform(b * 1.4, b * 4) + drift * 0.5
        satellite(S, rng, bx, by, rng.uniform(1.2, 3.6), rng.normal(0, 0.15), tail_p=0.8)
    A = S.alpha()
    d = depth_of(A)
    t = meniscus(d, 3.0) * (0.85 + 0.15 * (1 - smooth(cx, N * 0.8, S.X)))
    t = np.clip(t + 0.04 * noise(rng, A.shape, 5), 0, 1)
    return to_rgba(lum(t), edge_alpha(A, t))


def satellites(seed, count, N=512):
    """A fan of fine droplets (medium/high velocity spray), all moving to +X."""
    rng = np.random.default_rng(seed)
    S = Shape(N, N, rng, warps=((20, 1.0),))
    ox, oy = N * 0.3, N * 0.5
    for _ in range(count):
        ang = np.clip(rng.normal(0, 0.38), -1.0, 1.0)
        dist = N * (0.04 + 0.62 * rng.random() ** 0.8)
        x, y = ox + np.cos(ang) * dist, oy + np.sin(ang) * dist
        if not (6 < x < N - 6 and 6 < y < N - 6):
            continue
        near = 1 - dist / (N * 0.7)
        r = np.clip(rng.lognormal(np.log(1.6 + 2.5 * near), 0.5), 0.7, 9.0)
        asp = 1.0 + (1 - near) * rng.uniform(0.3, 1.6)
        S.add(ellipse(x, y, r * asp, r, ang), 1.0)
        if r > 2.4 and rng.random() < 0.55:
            L = r * rng.uniform(1.0, 3.0) * (1.2 - near)
            S.add(ucap(x, y, r * 0.5, x + np.cos(ang) * (r * asp + L), y + np.sin(ang) * (r * asp + L), 0.7), 1.2)
    A = S.alpha()
    d = depth_of(A)
    t = np.clip(meniscus(d, 2.2) * 1.1, 0, 1)
    return to_rgba(lum(t), edge_alpha(A, t))


def drip(seed, N=256):
    """A drop that fell ~1 m: round, finely crenellated, thick dome."""
    rng = np.random.default_rng(seed)
    S = Shape(N, N, rng, warps=((18, 1.5), (5, 0.5)))
    c = N * 0.5
    R = N * rng.uniform(0.22, 0.26)
    S.add(circle(c, c, R, random_harm(rng, [(5, 8, 0.02), (18, 26, 0.018), (30, 40, 0.01)])))
    for _ in range(int(rng.integers(0, 4))):
        a = rng.uniform(0, 6.28)
        spine(S, rng, c, c, a, R * 0.92, R, R * rng.uniform(0.08, 0.22), R * 0.06, 0.5)
    for _ in range(int(rng.integers(1, 6))):
        a = rng.uniform(0, 6.28)
        d = R * rng.uniform(1.15, 1.6)
        satellite(S, rng, c + np.cos(a) * d, c + np.sin(a) * d, R * rng.uniform(0.02, 0.05), a)
    A = S.alpha()
    d = depth_of(A)
    t = meniscus(d, R * 0.22)
    ring = np.exp(-(((d - R * 0.1) / (R * 0.06)) ** 2))
    t = np.clip(t * (0.9 + 0.12 * ring) + 0.03 * noise(rng, A.shape, 5), 0, 1)
    return to_rgba(lum(t), edge_alpha(A, t))


def pool_shape(seed, N=1024):
    """Outline of a passive pool: a random walk of overlapping blobs (the pool
    spread unevenly over a rough floor), a few fingers that ran further, and
    drips that landed next to it (some joined by a liquid neck)."""
    rng = np.random.default_rng(seed)
    S = Shape(N, N, rng, warps=((70, 14.0), (20, 4.0), (6, 0.8)))
    c = N * 0.5
    x, y = c, c
    r0 = N * rng.uniform(0.13, 0.15)
    body = []
    for _ in range(int(rng.integers(7, 12))):
        r = r0 * rng.uniform(0.55, 1.1)
        S.add(circle(x, y, r, random_harm(rng, [(3, 5, 0.05)])), N * 0.05)
        body.append((x, y, r))
        a = rng.uniform(0, 2 * np.pi)
        step = r * rng.uniform(0.5, 0.95)
        x, y = c + (x + np.cos(a) * step - c) * 0.85, c + (y + np.sin(a) * step - c) * 0.85
    # Fingers: on a flat floor a pool only pushes out short, fat, rounded
    # bulges (long thin fingers need a slope: that's pool_lobe's job). The
    # first version made "rabbit ears"; these stay stubby.
    for _ in range(int(rng.integers(1, 4))):
        bx, by, br = body[int(rng.integers(len(body)))]
        a = np.arctan2(by - c, bx - c) + rng.normal(0, 0.5)
        L = N * rng.uniform(0.02, 0.06)
        r1, r2 = br * rng.uniform(0.6, 0.8), br * rng.uniform(0.38, 0.55)
        x2, y2 = bx + np.cos(a) * (br + L), by + np.sin(a) * (br + L)
        S.add(ucap(bx, by, r1, x2, y2, r2), N * 0.03)
        S.add(circle(x2, y2, r2 * rng.uniform(1.0, 1.25)), N * 0.03)
    for _ in range(int(rng.integers(4, 10))):
        a = rng.uniform(0, 2 * np.pi)
        d = N * rng.uniform(0.36, 0.45)
        r = N * np.clip(rng.lognormal(np.log(0.012), 0.5), 0.004, 0.026)
        S.add(circle(c + np.cos(a) * d, c + np.sin(a) * d, r, random_harm(rng, [(12, 20, 0.04)])), N * 0.012)
    return rng, S


def pool(seed, N=1024):
    """A passive pool: big lobes, a thin bright meniscus band, dark thick body
    with a slightly lighter area where the gloss film will sit."""
    rng, S = pool_shape(seed, N)
    A = S.alpha()
    d = depth_of(A)
    rng2 = np.random.default_rng(seed + 999)
    t = 0.3 + 0.7 * meniscus(d, 9.0)  # the edge is thinner (lighter) but never a white outline
    body = 0.86 + 0.14 * smooth(0, N * 0.12, d)
    # the lighter, thinner area (gloss film)
    gx, gy = N * (0.5 + rng2.normal(0, 0.06)), N * (0.5 + rng2.normal(0, 0.06))
    gl = np.exp(-(((S.X - gx) ** 2 + (S.Y - gy) ** 2) / (2 * (N * 0.11) ** 2)))
    var = fbm(rng2, (N, N), [(40, 1.0), (10, 0.5)])
    t = t * (body - 0.12 * gl + 0.035 * var)
    # a few small air bubbles (light rim) floating in the fresh pool
    for _ in range(int(rng2.integers(3, 9))):
        ys, xs = np.nonzero(d > 40)
        j = int(rng2.integers(len(ys)))
        br = rng2.uniform(2.5, 7)
        rr = np.hypot(S.X - xs[j], S.Y - ys[j])
        t = t - 0.35 * np.exp(-(((rr - br) / 1.2) ** 2)) + 0.05 * (rr < br)
    t = np.clip(t, 0, 1)
    return to_rgba(lum(t), edge_alpha(A, t))


def pool_rim(seed, N=1024):
    """Same outline as pool_<n>: only the drying tide-line (dark), the serum
    halo just inside it (light, faint), and clot speckles. Faded in by age."""
    rng, S = pool_shape(seed, N)
    A = S.alpha()
    d = depth_of(A)
    rng2 = np.random.default_rng(seed + 4242)
    w = 4.0 + 2.5 * np.clip(noise(rng2, (N, N), 30), -1.5, 1.5)
    tide = 1 - smooth(w - 1.5, w + 1.5, d)
    serum = np.exp(-(((d - (w + 9)) / 5.0) ** 2))
    # clots: clustered speckles, denser toward the middle
    cl = noise(rng2, (N, N), 2.2) + 1.2 * noise(rng2, (N, N), 40) + 0.8 * smooth(10, N * 0.1, d)
    clot = smooth(1.9, 2.4, cl) * smooth(14, 30, d)
    big = smooth(1.4, 1.6, noise(rng2, (N, N), 9) + 0.6 * noise(rng2, (N, N), 50)) * smooth(30, 80, d)
    halo = np.clip(smooth(0.6, 1.2, ndi.gaussian_filter(big, 4)) - big, 0, 1)  # serum moat around clots
    clot = np.maximum(clot, big)
    a_out = A * np.clip(np.maximum.reduce([tide * 0.95, serum * 0.32, clot * 0.85, halo * 0.3]), 0, 1)
    L = np.where(np.maximum(tide, clot) * 0.95 > np.maximum(serum, halo) * 0.32, 0.38, 1.0)
    L = np.clip(L + 0.05 * noise(rng2, (N, N), 3), 0, 1)
    return to_rgba(L, a_out)


def run(seed, W=256, H=1024):
    """Blood running down a wall / skin (top -> bottom): a small stain at the
    source, a thread pulled straight down by gravity (it only wobbles a little),
    1-2 beads where it hesitated, and a terminal bulb where it stopped."""
    rng = np.random.default_rng(seed)
    S = Shape(W, H, rng, warps=((20, 1.5), (6, 0.5)))
    cx = W * 0.5 + rng.normal(0, 8)
    # source stain
    for _ in range(3):
        S.add(circle(cx + rng.normal(0, 14), 50 + rng.normal(0, 10), rng.uniform(20, 30), random_harm(rng, [(4, 7, 0.06), (12, 18, 0.03)])), 12)
    y_end = H * rng.uniform(0.85, 0.93)
    mx = noise(rng, (H,), 90) * 5 + noise(rng, (H,), 25) * 1.5
    beads = rng.uniform(0.35, 0.85, int(rng.integers(1, 3))) * y_end
    pts = []
    for y in np.arange(60, y_end, 12.0):
        f = (y - 60) / (y_end - 60)
        r = 13 * (1 - f) + 8 * f
        for by in beads:
            r += 5 * np.exp(-(((y - by) / 12) ** 2))
        pts.append((cx + mx[int(y)], y, r))
    S.chain(pts, k=6)
    ex, ey = pts[-1][0], pts[-1][1]
    S.add(ellipse(ex, ey + 8, 18, 12.5, np.pi / 2), 6)
    # a shorter, thinner side run that stopped early
    if rng.random() < 0.8:
        sx = cx + rng.choice([-1, 1]) * rng.uniform(26, 40)
        ylen = rng.uniform(140, 380)
        side = [(sx + 2.5 * np.sin(y / 50), y, 7 * (1 - (y - 55) / ylen) + 4.5) for y in np.arange(55, 55 + ylen, 12.0)]
        S.chain(side, k=5)
        S.add(ellipse(side[-1][0], side[-1][1] + 6, 10, 7, np.pi / 2), 5)
    A = S.alpha()
    d = depth_of(A)
    t = meniscus(d, 3.5)
    t = np.clip(t * (0.9 + 0.1 * smooth(0, 8, d)) + 0.03 * noise(rng, A.shape, 6), 0, 1)
    return to_rgba(lum(t), edge_alpha(A, t))


# ============================================================== SET B =====
def drip_pool(seed, N=512):
    """Drip-into-drip: drops falling on wet blood. Irregular centre, rings of
    the separate drops, and a ring of small satellites thrown out."""
    rng = np.random.default_rng(seed)
    S = Shape(N, N, rng, warps=((30, 5.0), (8, 1.2)))
    c = N * 0.5
    R = N * 0.13
    centres = []
    for i in range(int(rng.integers(5, 9))):
        x, y = c + rng.normal(0, R * 0.35), c + rng.normal(0, R * 0.35)
        r = R * rng.uniform(0.55, 0.95)
        centres.append((x, y, r))
        S.add(circle(x, y, r, random_harm(rng, [(14, 24, 0.03)])), R * 0.3)
    for _ in range(int(rng.integers(30, 60))):
        a = rng.uniform(0, 2 * np.pi)
        d = R * rng.uniform(1.25, 2.6) ** 1.2
        r = np.clip(rng.lognormal(np.log(2.6), 0.5), 0.8, 9)
        satellite(S, rng, c + np.cos(a) * d, c + np.sin(a) * d, r, a, tail_p=0.6)
    for _ in range(int(rng.integers(5, 12))):
        spine(S, rng, c, c, rng.uniform(0, 6.28), R * 0.9, R, R * rng.uniform(0.2, 0.5), R * 0.06)
    A = S.alpha()
    d = depth_of(A)
    t = meniscus(d, 4.0)
    rings = np.zeros_like(t)
    for x, y, r in centres:
        rr = np.hypot(S.X - x, S.Y - y)
        rings = np.maximum(rings, np.exp(-(((rr - r * 0.92) / 2.5) ** 2)))
    t = np.clip(t * (0.85 + 0.15 * rings + 0.04 * noise(rng, A.shape, 8)), 0, 1)
    return to_rgba(lum(t), edge_alpha(A, t))


def pool_lobe(seed, N=512):
    """One tongue added at a pool's rim as it grows downhill (+X = flow). The
    left side tucks under the pool; the front is rounded and slightly thicker
    (a flowing liquid front piles up), sometimes split into 2 fingers."""
    rng = np.random.default_rng(seed)
    S = Shape(N, N, rng, warps=((50, 8.0), (14, 2.5), (5, 0.6)))
    cy = N * 0.5
    x, y, r = N * 0.22, cy, N * 0.19
    S.add(circle(x, y, r))
    for _ in range(4):
        nx = x + r * rng.uniform(0.55, 0.8)
        ny = y + rng.normal(0, r * 0.15)
        r = r * rng.uniform(0.8, 0.95)
        S.add(circle(nx, ny, r, random_harm(rng, [(3, 5, 0.05)])), N * 0.05)
        x, y = nx, ny
    if rng.random() < 0.6:
        a = rng.choice([-1, 1]) * rng.uniform(0.4, 0.8)
        S.add(ucap(x - r * 0.3, y, r * 0.5, x + np.cos(a) * r * 1.3, y + np.sin(a) * r * 1.3, r * 0.35), N * 0.03)
    A = S.alpha()
    d = depth_of(A)
    t = 0.3 + 0.7 * meniscus(d, 8.0)
    ridge = np.exp(-(((d - 18) / 12) ** 2)) * smooth(N * 0.5, N * 0.8, S.X)  # thick flow front
    tide = 1 - smooth(4, 8, d)
    t = np.clip(t * (0.88 + 0.12 * ridge + 0.03 * noise(rng, A.shape, 20)), 0, 1)
    L = lum(t) - 0.07 * tide * smooth(0.5, 2.0, d)  # low-contrast tide-line baked in
    return to_rgba(L, edge_alpha(A, t))


def smear(seed, W=1024, H=512):
    """A drag mark (+X = direction of the drag): a heavy start, a film that
    thins out with parallel striations, darker ridges along both sides (blood
    pushed aside), and a trailing end that breaks into separate streaks."""
    rng = np.random.default_rng(seed)
    Y, X = np.mgrid[0:H, 0:W].astype(F32) + 0.5
    x0 = W * 0.1
    prog = np.clip((X - x0) / (W * 0.86 - x0), 0, 1)
    curve = 22 * noise(rng, (W,), 160)[None, :]
    half = H * 0.22 * (1 - 0.3 * prog) + 4 * noise(rng, (W,), 25)[None, :]
    top = 6 * noise(rng, (H, W), (3, 14))
    v = (Y - H * 0.5 - curve) / half
    band = 1 - smooth(0.97, 1.03, np.abs(v) + top / half)
    stri = fbm(rng, (H, W), [((1.0, 50), 1.0), ((2.5, 110), 0.9), ((7, 260), 0.6)])
    thr = -4.5 + 5.7 * prog**1.5
    cov = smooth(thr - 0.15, thr + 0.15, stri) * band
    # the start: blood was lying there before it got dragged
    S = Shape(W, H, rng, warps=((30, 6.0), (9, 1.5)))
    hx = W * 0.12
    for _ in range(4):
        S.add(circle(hx + rng.normal(0, 25), H * 0.5 + curve[0, int(hx)] + rng.normal(0, 20), rng.uniform(72, 96), random_harm(rng, [(3, 6, 0.05), (10, 16, 0.025)])), 30)
    head = S.alpha()
    start = np.clip(X - (hx + 25 + 30 * noise(rng, (H, 1), 12)) + 0.5, 0, 1)  # ragged but crisp start
    cov = np.maximum(cov * start, head)
    side = np.exp(-np.clip(1 - np.abs(v), 0, None) / 0.07) * band * (1 - 0.6 * prog)
    dense = (1 - prog) ** 1.1
    t = 0.18 + 0.62 * dense + 0.14 * np.clip(stri - thr, -1, 2) / 2 * (0.4 + dense)
    t = t + 0.25 * side
    hd = depth_of(head)
    t = np.where(head > 0.5, np.maximum(t, 0.6 + 0.35 * meniscus(hd, 10)), t)
    t = np.clip(ndi.gaussian_filter(t, 1.0) + 0.03 * noise(rng, (H, W), 8), 0, 1)
    A = cov * (0.5 + 0.5 * smooth(0.02, 0.45, t))
    return to_rgba(lum(t), A)


def hand(seed, mirror=False, N=256):
    """A partial bloody palm print (left hand, palm side), fingers toward the
    top of the image. The palm hollow and the finger joints leave gaps; the
    skin ridges only show as a faint texture."""
    rng = np.random.default_rng(seed)
    S = Shape(N, N, rng, warps=((20, 2.0), (6, 0.6)))
    S.add(ellipse(124, 170, 50, 56, 0.05, random_harm(rng, [(3, 5, 0.04)])))
    S.add(ellipse(164, 196, 26, 32, -0.4), 12)  # thenar pad (base of the thumb)
    fingers = [(-38, 60, 10.5, -0.2), (-13, 76, 11.5, -0.07), (12, 74, 11.5, 0.04), (35, 58, 10, 0.16)]
    Y, X = np.mgrid[0:N, 0:N].astype(F32) + 0.5
    crease = np.zeros((N, N), F32)
    for ox, L, r, a in fingers:
        x0, y0 = 124 + ox, 124
        x1, y1 = x0 + np.sin(a) * L, y0 - np.cos(a) * L
        S.add(ucap(x0, y0 + 8, r, x1, y1, r * 0.9), 5)
        for f in (0.36, 0.66):  # joint creases across the finger
            px, py = x0 + np.sin(a) * L * f, y0 - np.cos(a) * L * f
            along = (X - px) * np.sin(a) - (Y - py) * np.cos(a)
            crease = np.maximum(crease, np.exp(-((along / 1.7) ** 2)) * (np.hypot(X - px, Y - py) < r + 3))
    S.add(ucap(178, 182, 14.5, 230, 122, 10.5), 10)  # thumb (left hand palm print: on the right)
    shape = S.alpha()
    # palm lines
    for k in range(3):
        y0 = 146 + k * 20 + rng.normal(0, 3)
        line = Y - y0 - 0.005 * (X - 124) ** 2 * (1 - k) - 0.15 * (X - 124) * (k - 1)
        crease = np.maximum(crease, np.exp(-((line / 1.6) ** 2)) * (np.abs(X - 124) < 50) * rng.uniform(0.6, 1))
    crease = np.maximum(crease, np.exp(-(((Y - 128) / 2.2) ** 2)) * (np.abs(X - 124) < 52))  # base of the fingers
    hollow = np.exp(-(((X - 120) ** 2 + (Y - 172) ** 2) / (2 * 24**2)))
    press = fbm(rng, (N, N), [(16, 1.0), (5, 0.6), (1.5, 0.3)]) - 1.5 * hollow
    ridges = np.sin(np.hypot(X + 4 * noise(rng, (N, N), 8), Y + 4 * noise(rng, (N, N), 8) - 40) * 2.2)
    crease = crease * smooth(-0.6, 0.4, noise(rng, (N, N), 6))  # creases only partly break the print
    cov = shape * smooth(-0.9, -0.5, press) * (1 - 0.8 * crease)
    t = np.clip(0.5 + 0.22 * press + 0.06 * ridges, 0, 1)
    A = cov * (0.7 + 0.3 * t)
    L = lum(t)
    if mirror:
        L, A = L[:, ::-1], A[:, ::-1]
    return to_rgba(L, A)


def foot(seed, level, mirror=False, N=256):
    """A street-shoe sole print, toe toward the top. level 1 heavy (full sole,
    blood squeezed out at the edge), 2 partial (heel + ball, tread visible),
    3 trace (a few tread lugs, thin)."""
    rng = np.random.default_rng(seed)
    S = Shape(N, N, rng, warps=((24, 1.2),))
    side = -1 if mirror else 1
    S.add(ellipse(128 + 6 * side, 64, 46, 57, 0.12 * side))  # forefoot
    S.add(ucap(128 + 8 * side, 92, 39, 128 - 2 * side, 190, 34), 22)  # waist
    S.add(ellipse(128 - 2 * side, 196, 36, 39, 0))  # heel
    D = S.D.copy()
    Y, X = np.mgrid[0:N, 0:N].astype(F32) + 0.5
    inside = np.clip(0.5 - D, 0, 1)
    # tread: zig-zag lugs at the front, straight bars on the heel, a rim, flex grooves
    # (critic pass: the old perfect zig-zag / bar stripes read as a logo.
    # A real worn street sole prints as staggered rounded lugs of slightly
    # different sizes, with the gaps between them often filled by blood.)
    jx, jy = 1.6 * noise(rng, (N, N), 5), 1.6 * noise(rng, (N, N), 5)
    cw, ch = np.where(Y < 140, 15.0, 13.0), np.where(Y < 140, 11.0, 12.0)
    row = np.floor((Y + jy) / ch)
    u = ((X + jx + (row % 2) * cw * 0.5) / cw) % 1.0
    w = ((Y + jy) / ch) % 1.0
    cell_id = np.floor((X + jx + (row % 2) * cw * 0.5) / cw) * 37 + row * 11
    size = 0.4 + 0.06 * np.sin(cell_id * 12.9898)  # each lug its own size
    box = np.maximum(np.abs(u - 0.5) - size + 0.12, 0) ** 2 + np.maximum(np.abs(w - 0.5) - size * 0.85 + 0.12, 0) ** 2
    lugs = 1 - smooth(0.0035, 0.012, box)
    lugs = lugs * smooth(-2.0, -1.3, noise(rng, (N, N), 4))  # worn / missing lugs
    rim = np.clip(0.5 - np.abs(D + 4.5) + 3.0, 0, 1)
    flex = np.exp(-(((Y - 105) / 2.2) ** 2)) + np.exp(-(((Y - 150) / 3.0) ** 2))
    arch = np.exp(-(((X - 128 - 24 * side) / 18) ** 2 + ((Y - 130) / 30) ** 2))
    tread = np.clip(np.maximum(lugs, rim) - flex, 0, 1) * (1 - 0.95 * arch)
    press = fbm(rng, (N, N), [(18, 1.0), (5, 0.6), (1.5, 0.35)])
    if level == 1:
        out = 1.5 + 3 * smooth(-1, 1.5, noise(rng, (N, N), 6))
        squeeze = np.clip(0.5 - (D - out), 0, 1) * (1 - inside)
        fill = smooth(-0.4, 0.4, press)  # where the grooves are full of blood too
        cov = inside * np.maximum(tread, fill * 0.9) * (1 - smooth(0.3, 0.5, arch)) + squeeze * smooth(-0.6, 0.2, press)
        cov *= smooth(-1.9, -1.3, press)
        t = np.clip(0.6 + 0.2 * press + 0.15 * tread - 0.25 * (1 - tread) * (1 - fill), 0, 1)
    elif level == 2:
        zones = np.maximum(
            np.exp(-(((X - 128 - 6 * side) / 42) ** 2 + ((Y - 60) / 36) ** 2)),
            np.exp(-(((X - 126) / 36) ** 2 + ((Y - 200) / 30) ** 2)),
        )
        cov = inside * tread * smooth(0.3, 0.5, zones + 0.3 * press) * smooth(-1.6, -1.0, press)
        t = np.clip(0.42 + 0.18 * press, 0, 1)
    else:
        zones = np.maximum(np.exp(-(((Y - 50) / 40) ** 2)), np.exp(-(((Y - 205) / 28) ** 2)))
        cov = inside * lugs * (1 - flex) * smooth(0.55, 0.85, zones * 0.7 + 0.35 * press + 0.25 * noise(rng, (N, N), 20))
        t = np.clip(0.22 + 0.12 * press, 0, 1)
    A = np.clip(cov, 0, 1) * (0.6 + 0.4 * smooth(0.1, 0.5, t))
    return to_rgba(lum(t), A)


def soak(seed, N=512):
    """Blood wicking into fabric: a soft edge with a fine fuzz that follows the
    threads (H and V), a darker tide-line, a slightly lighter centre and the
    weave showing through. Nearly opaque: cotton drinks it fully."""
    rng = np.random.default_rng(seed)
    S = Shape(N, N, rng, warps=((60, 16.0), (16, 4.0)))
    c = N * 0.5
    S.add(ellipse(c, c, N * rng.uniform(0.24, 0.28), N * rng.uniform(0.19, 0.24), rng.uniform(0, 3)))
    for _ in range(int(rng.integers(2, 4))):
        a = rng.uniform(0, 6.28)
        S.add(circle(c + np.cos(a) * N * 0.16, c + np.sin(a) * N * 0.16, N * rng.uniform(0.08, 0.13)), N * 0.08)
    # (critic pass: the strong 1-px thread fuzz made a "hairy carpet" edge.
    # Real wicking front: irregular capillary lobes a few threads deep, only a
    # faint thread-direction bias, and a soft-but-defined edge.)
    h = noise(rng, (N, N), (0.8, 3))
    v = noise(rng, (N, N), (3, 0.8))
    cap = fbm(rng, (N, N), [(10, 1.0), (4, 0.6)])
    F = -S.D / 12.0 + 0.16 * np.maximum(h, v) + 0.45 * cap + 0.08 * noise(rng, (N, N), 1.5)
    cov = smooth(-0.3, 0.3, F)
    d = ndi.distance_transform_edt(F > 0).astype(F32)
    Y, X = np.mgrid[0:N, 0:N].astype(F32)
    weave = np.sin(X * 2 * np.pi / 4.0) * np.sin(Y * 2 * np.pi / 4.0)
    tide = np.exp(-(((d - 4) / 5.0) ** 2))
    t = 0.62 + 0.3 * tide - 0.12 * smooth(15, 110, d) + 0.05 * weave + 0.05 * noise(rng, (N, N), 14)
    t = np.clip(t * (0.6 + 0.4 * cov), 0, 1)
    A = cov * (0.95 + 0.03 * weave)
    return to_rgba(lum(t), np.clip(A, 0, 1))


def skin_smear(seed, N=512):
    """A thin translucent film of blood wiped across skin by fingers: blood
    left where the wipe started, a film whose fingers barely show, fine
    striations, and an end that breaks into streaks."""
    rng = np.random.default_rng(seed)
    Y, X = np.mgrid[0:N, 0:N].astype(F32) + 0.5
    bend = rng.uniform(-0.0012, 0.0012)
    Yc = Y - N * 0.5 - bend * (X - N * 0.5) ** 2 - 8 * noise(rng, (N,), 80)[None, :]
    nf = int(rng.integers(3, 5))
    spacing = rng.uniform(24, 30)
    lanes = np.zeros((N, N), F32)
    for i in range(nf):
        y0 = (i - (nf - 1) / 2) * spacing + rng.normal(0, 3) + 4 * noise(rng, (N,), 60)[None, :]
        lanes = np.maximum(lanes, np.exp(-(((Yc - y0) / rng.uniform(7, 10)) ** 2)))
    width = (nf / 2) * spacing + 8
    edge = np.abs(Yc) + 6 * noise(rng, (N, N), (3, 18)) + 4 * noise(rng, (N, N), 30)
    film = 1 - smooth(width - 4, width + 4, edge)
    # (critic pass: 35-90 px long 1-px streaks read as a dry brush. Skin is
    # soft and ridged: shorter, broken streaks plus blotchy film breakup.)
    stri = fbm(rng, (N, N), [((1.2, 14), 1.0), ((3, 36), 0.7), ((9, 9), 0.6)])
    prog = np.clip((X - N * 0.12) / (N * 0.8), 0, 1)
    start = smooth(N * 0.06, N * 0.12, X + 10 * noise(rng, (N, N), 10))
    thr = -2.6 + 3.4 * prog**1.5
    cov = film * start * smooth(thr - 0.5, thr + 0.5, stri + 0.4 * lanes)
    t = 0.12 + 0.18 * (1 - prog) + 0.06 * lanes + 0.05 * np.clip(stri, -1, 2)
    # blood left where the wipe started (thicker), with a sharp edge
    S = Shape(N, N, rng, warps=((14, 3.0), (5, 0.8)))
    for _ in range(6):
        S.add(circle(N * 0.12 + rng.normal(0, 12), N * 0.5 + rng.normal(0, width * 0.6), rng.uniform(6, 16), random_harm(rng, [(3, 6, 0.1)])), 6)
    for _ in range(int(rng.integers(3, 7))):
        S.add(circle(rng.uniform(N * 0.1, N * 0.4), N * 0.5 + rng.normal(0, width * 0.7), rng.uniform(1.5, 4.5)))
    blot = S.alpha()
    t = np.clip(np.maximum(t, blot * (0.25 + 0.3 * meniscus(depth_of(blot), 6))), 0, 0.55)
    A = np.maximum(cov * (0.3 + 0.45 * smooth(0.05, 0.4, t)), blot * 0.9)
    return to_rgba(lum(t), A)


def knuckles(seed, N=256):
    """Blood on a fist: 4 knuckle dabs, transferred smears pulled down the
    fingers, a few flecks, and skin creases breaking the dabs."""
    rng = np.random.default_rng(seed)
    S = Shape(N, N, rng, warps=((14, 2.5), (4, 0.8)))
    Y, X = np.mgrid[0:N, 0:N].astype(F32) + 0.5
    crease = np.zeros((N, N), F32)
    for i in range(4):
        x = 52 + i * 50 + rng.normal(0, 3)
        y = 100 + 5 * (i - 1.5) ** 2 + rng.normal(0, 3)
        r = rng.uniform(14, 21)
        S.add(ellipse(x, y, r * 1.2, r, rng.normal(0, 0.3), random_harm(rng, [(3, 6, 0.08), (8, 12, 0.04)])))
        L = rng.uniform(12, 50)
        S.add(ucap(x, y, r * 0.65, x + rng.normal(0, 6), y + L, r * 0.3), 8)
        for k in range(2):  # knuckle skin creases: short, faint, broken arcs (not a wavy zebra)
            cy = y - 4 + k * 7 + rng.normal(0, 1.5)
            crease = np.maximum(crease, 0.6 * np.exp(-(((Y - cy - 0.01 * (X - x) ** 2) / 2.0) ** 2)) * (np.abs(X - x) < r * rng.uniform(0.4, 0.7)))
    for _ in range(int(rng.integers(8, 20))):
        satellite(S, rng, rng.uniform(20, 236), rng.uniform(50, 190), rng.uniform(0.8, 2.4), rng.uniform(0, 6.28))
    shape = S.alpha()
    press = fbm(rng, (N, N), [(8, 1.0), (2.5, 0.5)])
    crease = crease * smooth(-0.5, 0.5, noise(rng, (N, N), 5))
    cov = shape * smooth(-2.2, -1.7, press) * (1 - 0.3 * crease)
    d = depth_of(shape)
    t = np.clip(meniscus(d, 4) * (0.65 + 0.15 * press), 0, 1)
    A = cov * (0.75 + 0.25 * smooth(0, 0.5, t))
    return to_rgba(lum(t), A)


# ============================================================== SET C =====
LIGHT = np.array([-0.45, -0.55, 0.7])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def shade_liquid(alpha, height, soft=1.0):
    """Grey shading of a liquid blob seen up close (particles): dark Fresnel
    rim, light passing through to the far side, one sharp highlight upper left.
    The brightest pixel is the highlight; tinted it reads as a wet glint."""
    hgt = ndi.gaussian_filter(height, soft)
    gy, gx = np.gradient(hgt)
    nz = 1.0 / np.sqrt(gx * gx + gy * gy + 1)
    nx, ny = -gx * nz, -gy * nz
    ndl = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
    hx, hy, hz = LIGHT[0], LIGHT[1], LIGHT[2] + 1
    hn = np.sqrt(hx * hx + hy * hy + hz * hz)
    spec = np.clip((nx * hx + ny * hy + nz * hz) / hn, 0, 1) ** 90
    fres = (1 - nz) ** 1.5
    glow = np.clip(-(nx * LIGHT[0] + ny * LIGHT[1]) / (np.hypot(nx, ny) + 1e-4), 0, 1) * smooth(0.15, 0.7, 1 - nz) * (1 - smooth(0.8, 1.0, 1 - nz))
    L = 0.42 + 0.12 * ndl - 0.22 * fres + 0.2 * glow + 0.9 * spec
    return np.clip(L, 0, 1) * (alpha > 0) + 0.42 * (alpha <= 0)


def dome(alpha, D=None):
    d = ndi.distance_transform_edt(alpha >= 0.5).astype(F32) + alpha * 0.5
    m = max(d.max(), 1)
    return np.sqrt(np.clip(d * (2 * m - d), 0, None))


def p_drop_cell(N, a, b, ang=0.0, soft=1.2):
    rng = np.random.default_rng(1)
    S = Shape(N, N, rng, warps=())
    S.add(ellipse(N / 2, N / 2, a, b, ang))
    A = np.clip(0.5 - S.D / soft, 0, 1)
    return shade_liquid(A, dome(A)), A


def p_drop():
    L, A = p_drop_cell(128, 44, 44)
    return to_rgba(L, A)


def p_drops_4x4():
    cells = []
    for f in range(16):
        s = 1 + 0.3 * np.exp(-f / 9) * np.cos(2 * np.pi * f / 5.5)
        r = 64
        L, A = p_drop_cell(256, r / np.sqrt(s), r * s, np.pi / 2)  # long axis = +Y (velocity)
        cells.append(to_rgba(L, A))
    return grid(cells, 4)


def p_gobs_4x4():
    cells = []
    for i in range(16):
        rng = np.random.default_rng(700 + i)
        N = 256
        S = Shape(N, N, rng, warps=((20, 3.0), (6, 1.0)))
        kind = i % 4
        c = N / 2
        if kind == 0:  # dumbbell: two drops pinching apart
            r1, r2 = rng.uniform(28, 40), rng.uniform(18, 30)
            S.add(circle(c, c - 45, r1))
            S.add(circle(c + rng.normal(0, 4), c + 50, r2), 0)
            S.add(ucap(c, c - 45, 9, c, c + 50, 6), 14)
        elif kind == 1:  # tadpole: drop with a ligament behind it
            r = rng.uniform(30, 42)
            S.add(circle(c, c + 40, r))
            S.chain([(c + rng.normal(0, 3), c + 40 - f * 130, r * 0.5 * (1 - f) + 3) for f in np.linspace(0, 1, 6)], k=10)
        elif kind == 2:  # beaded ligament
            y = c - 100
            for j in range(int(rng.integers(3, 6))):
                r = rng.uniform(12, 26)
                S.add(circle(c + rng.normal(0, 6), y + r, r), 12)
                y += 2 * r + rng.uniform(-6, 4)
            S.add(ucap(c, c - 95, 5, c, min(y, c + 110), 4), 10)
        else:  # irregular gob
            for _ in range(int(rng.integers(3, 6))):
                S.add(circle(c + rng.normal(0, 20), c + rng.normal(0, 30), rng.uniform(22, 40)), 20)
        A = S.alpha()
        cells.append(to_rgba(shade_liquid(A, dome(A)), A))
    return grid(cells, 4)


def p_mist_8x8():
    """64 frames of a fine spray cloud expanding then breaking into specks."""
    N, F = 128, 64
    rng = np.random.default_rng(31)
    n = 420
    ang = rng.uniform(0, 2 * np.pi, n)
    spd = rng.lognormal(np.log(22), 0.55, n)
    p0 = rng.normal(0, 4, (n, 2))
    rad = np.clip(rng.lognormal(np.log(0.9), 0.5, n), 0.35, 2.6)
    life = rng.uniform(0.55, 1.0, n)
    lumv = rng.uniform(0.6, 0.95, n)
    Y, X = np.mgrid[0:N, 0:N].astype(F32) + 0.5
    cells = []
    for f in range(F):
        tau = f / (F - 1)
        A = np.zeros((N, N), F32)
        L = np.ones((N, N), F32) * 0.8
        pos = p0 + np.stack([np.cos(ang), np.sin(ang)], 1) * (spd * (1 - np.exp(-3 * tau)) / 0.95)[:, None]
        pos[:, 1] += 14 * tau * tau  # falls a little
        for j in range(n):
            fade = 1 - smooth(life[j] * 0.7, life[j], tau)
            if fade <= 0:
                continue
            r = rad[j] * (1 - 0.35 * tau)
            x, y = N / 2 + pos[j, 0], N / 2 + pos[j, 1]
            x0, x1 = int(max(0, x - r - 2)), int(min(N, x + r + 3))
            y0, y1 = int(max(0, y - r - 2)), int(min(N, y + r + 3))
            if x0 >= x1 or y0 >= y1:
                continue
            d = np.hypot(X[y0:y1, x0:x1] - x, Y[y0:y1, x0:x1] - y)
            a = np.clip(r + 0.5 - d, 0, 1) * min(1.0, r * 1.6) * fade
            L[y0:y1, x0:x1] = np.where(a > A[y0:y1, x0:x1], lumv[j], L[y0:y1, x0:x1])
            A[y0:y1, x0:x1] = np.maximum(A[y0:y1, x0:x1], a)
        cells.append(to_rgba(L, A))
    return grid(cells, 8)


def beam_stream(W=1024, H=256):
    """The liquid rope for the arterial Beam. Roblox maps a Beam texture's X
    axis along the beam (Attachment0 -> Attachment1), so the rope runs along X
    and tiles left/right. Varicose bulges and necks (Plateau-Rayleigh), a
    bright centre line, dark edges, and flow streaks."""
    rng = np.random.default_rng(55)
    X = np.arange(W, dtype=F32)[None, :]
    Y = np.arange(H, dtype=F32)[:, None] + 0.5
    ph = rng.uniform(0, 6.28, 4)
    u = X / W * 2 * np.pi
    w = H * 0.27 * (1 + 0.22 * np.sin(3 * u + ph[0]) + 0.08 * np.sin(7 * u + ph[1]) + 0.04 * np.sin(13 * u + ph[2]))
    cy = H * 0.5 + 6 * np.sin(2 * u + ph[3])
    q = (Y - cy) / w
    A = np.clip((1 - np.abs(q)) * w + 0.5, 0, 1)
    nz = np.sqrt(np.clip(1 - q * q, 0, 1))
    streak = noise(rng, (H, W), (1.5, 40), wrap=True)
    spec = np.exp(-(((q + 0.28) / 0.1) ** 2)) * (0.75 + 0.25 * streak)
    L = 0.3 + 0.25 * nz + 0.05 * streak + 0.6 * spec - 0.12 * (1 - nz) ** 2
    return to_rgba(np.clip(L, 0, 1), A)


def arterial_arc(seed, W=1024, H=256):
    """The pattern an arterial spurt leaves on a wall: a wavy line of separate
    big stains (one burst per heartbeat), elongated toward +X, satellites, and
    runs hanging under the heavy ones."""
    rng = np.random.default_rng(seed)
    S = Shape(W, H, rng, warps=((24, 2.5), (7, 0.9)))
    P = rng.uniform(320, 440)
    ph = rng.uniform(0, 6.28)
    zig = seed % 2 == 0

    def path(x):
        s = (x / P * 2 * np.pi + ph) % (2 * np.pi)
        wave = (2 * np.abs(s / np.pi - 1) - 1) if zig else np.sin(s)
        return 88 + 40 * wave

    x = 24.0
    heavy = []
    while x < W - 30:
        y = path(x) + rng.normal(0, 3)
        dy = (path(x + 4) - path(x - 4)) / 8
        ang = np.arctan(dy)
        pulse = 0.5 + 0.5 * np.cos((x / P) * 4 * np.pi + ph)
        # (critic pass: the low-pressure drops were so small and close that they
        # read as a thin "garland" thread. Real arterial spurts leave separate,
        # fat stains with gaps between beats.)
        r = np.clip(rng.lognormal(np.log(6.5 + 12 * pulse**2), 0.35), 3.5, 26)
        asp = rng.uniform(1.3, 2.2)
        S.add(ellipse(x, y, r * asp, r, ang, random_harm(rng, [(6, 12, 0.05)]), front_weight), 3)
        if r > 7 and rng.random() < 0.7:
            L = r * rng.uniform(1.5, 3.5)
            S.add(ucap(x + np.cos(ang) * r, y + np.sin(ang) * r, r * 0.35, x + np.cos(ang) * (r * asp + L), y + np.sin(ang) * (r * asp + L), 1.0), 3)
        if r > 9:
            heavy.append((x, y, r))
        for _ in range(int(rng.integers(1, 5))):
            sx, sy = x + rng.normal(r * 2, r * 2), y + rng.normal(0, r * 1.8)
            if 4 < sy < H - 4:
                satellite(S, rng, sx, sy, rng.uniform(0.8, 2.8), ang, tail_p=0.7)
        x += r * asp * rng.uniform(1.0, 2.4) + rng.uniform(4, 22)
    for hx, hy, r in heavy:
        if rng.random() < 0.8:
            yl = min(H - 14, hy + rng.uniform(40, 150))
            ys = np.arange(hy, yl, 10.0)
            if len(ys) < 2:
                continue
            w0 = min(r * 0.4, 7.5)
            wob = noise(rng, (len(ys),), 2.0) if len(ys) > 3 else np.zeros(len(ys))
            pts = [(hx + 1.5 * np.sin(yy / 31 + hx), yy, w0 * (1 - 0.45 * (yy - hy) / (yl - hy + 1)) + 1.8 + 0.6 * wb) for yy, wb in zip(ys, wob)]
            S.chain(pts, k=4)
            S.add(ellipse(pts[-1][0], pts[-1][1] + 3, 6, 4.5, np.pi / 2), 3)
    A = S.alpha()
    d = depth_of(A)
    t = np.clip(meniscus(d, 3.0) + 0.04 * noise(rng, A.shape, 6), 0, 1)
    return to_rgba(lum(t), edge_alpha(A, t))


# ================================================================= main ====
JOBS = [
    # Set A
    *[(f"spatter_round_{i}", lambda i=i: spatter_round(100 + i)) for i in (1, 2, 3)],
    *[(f"spatter_oval_{i}", lambda i=i: spatter_oval(200 + i)) for i in (1, 2, 3)],
    *[(f"spatter_tail_{i}", lambda i=i: spatter_tail(300 + i)) for i in (1, 2, 3)],
    *[(f"spatter_streak_{i}", lambda i=i: spatter_streak(400 + i)) for i in (1, 2)],
    *[(f"satellites_{i}", lambda i=i: satellites(500 + i, (40, 90, 150)[i - 1])) for i in (1, 2, 3)],
    *[(f"drip_{i}", lambda i=i: drip(600 + i)) for i in (1, 2)],
    *[(f"pool_{i}", lambda i=i: pool(700 + i)) for i in (1, 2, 3)],
    *[(f"pool_rim_{i}", lambda i=i: pool_rim(700 + i)) for i in (1, 2, 3)],
    *[(f"run_{i}", lambda i=i: run(800 + i)) for i in (1, 2)],
    # Set B
    *[(f"drip_pool_{i}", lambda i=i: drip_pool(900 + i)) for i in (1, 2)],
    *[(f"pool_lobe_{i}", lambda i=i: pool_lobe(1000 + i)) for i in (1, 2, 3)],
    *[(f"smear_{i}", lambda i=i: smear(1100 + i)) for i in (1, 2)],
    ("handprint_L_1", lambda: hand(1201)),
    ("handprint_R_1", lambda: hand(1202, mirror=True)),
    *[(f"foot_L_{i}", lambda i=i: foot(1300 + i, i)) for i in (1, 2, 3)],
    *[(f"foot_R_{i}", lambda i=i: foot(1310 + i, i, mirror=True)) for i in (1, 2, 3)],
    *[(f"soak_{i}", lambda i=i: soak(1400 + i)) for i in (1, 2, 3)],
    *[(f"skin_smear_{i}", lambda i=i: skin_smear(1500 + i)) for i in (1, 2)],
    *[(f"knuckles_{i}", lambda i=i: knuckles(1600 + i)) for i in (1, 2)],
    # Set C
    ("p_drop", p_drop),
    ("p_drops_4x4", p_drops_4x4),
    ("p_gobs_4x4", p_gobs_4x4),
    ("p_mist_8x8", p_mist_8x8),
    ("beam_stream", beam_stream),
    *[(f"arterial_arc_{i}", lambda i=i: arterial_arc(1700 + i)) for i in (1, 2)],
]


def main():
    os.makedirs(OUT, exist_ok=True)
    only = set(sys.argv[2:])
    for name, job in JOBS:
        if only and not any(name.startswith(o) for o in only):
            continue
        save(name, job())
        sz, w, h = SIZES[name]
        print(f"{name:18s} {w:4d}x{h:<4d} {sz / 1024:7.1f} KB")
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT) if f.endswith(".png") and f != "preview.png")
    print(f"total (without preview.png): {total / 1024 / 1024:.2f} MB")


if __name__ == "__main__":
    main()
