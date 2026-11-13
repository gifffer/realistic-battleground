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
        rgba = fade_border(rgba, 12 if name.startswith(("smear", "skin_smear", "drag", "wipe_smear")) else 3)
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


# ======================================================= SET D (v2) =====
# Blood v2 "details": NEW pictures only (docs/BLOOD_FR.md, "Nouvelles images
# (v2)"). Same rules as above: grey = thickness, straight alpha, travel +X,
# upright pictures drawn top -> bottom. A few of them are masks for raw skin
# (abrasion, split knuckle): there the grey is "how raw / how bloody", tinted
# by the code with Config.Blood.PALETTE.RAW.
# Nothing here changes a v1 picture: the v1 functions are only called.
def v2_rng(seed):
    return np.random.default_rng(seed)


def rows_cols(h, w):
    Y, X = np.mgrid[0:h, 0:w].astype(F32) + 0.5
    return Y, X


def rivulet_profile(rng, W, H, top=0.27, bottom=0.17):
    """A skin rivulet seen face-on, one value per row: centre x, half-width
    (px) and the 'pause marks' (0..1) where the front stopped and swelled.
    Real runs are 2-6 mm wide, wider where they left the wound (top)."""
    y = np.arange(H, dtype=F32) + 0.5
    f = y / H
    cx = W * 0.5 + W * 0.04 * noise(rng, (H,), 70) + W * 0.012 * noise(rng, (H,), 14)
    half = W * (top + (bottom - top) * f**0.7) * (1 + 0.07 * noise(rng, (H,), 30) + 0.03 * noise(rng, (H,), 8))
    pause = np.zeros(H, F32)
    for p in rng.uniform(0.2, 0.85, int(rng.integers(2, 4))) * H:
        g = np.exp(-(((y - p) / (W * rng.uniform(0.1, 0.16))) ** 2))
        half = half * (1 + 0.15 * g)
        pause = np.maximum(pause, g)
    return cx, half, pause


def rivulet_field(rng, W, H, cx, half, wobble=0.9):
    """Signed distance (px, <0 inside) and normalised cross position q
    (0 = centre line, 1 = edge) of a rivulet from its profile."""
    Y, X = rows_cols(H, W)
    # the contact line is never perfectly straight: each side wobbles on its own
    left = wobble * (noise(rng, (H,), 7) + 0.4 * noise(rng, (H,), 2))
    right = wobble * (noise(rng, (H,), 7) + 0.4 * noise(rng, (H,), 2))
    edge = np.where(X < cx[:, None], left[:, None], right[:, None])
    dx = np.abs(X - cx[:, None])
    D = dx - half[:, None] - edge
    q = np.clip(dx / (half[:, None] + edge + 1e-3), 0, 1.5)
    return D, q, Y, X


def rivulet_strip(seed, W=128, H=512):
    """A run on skin WITHOUT its front bead (the bead is a separate 3D drop or
    rivulet_bead): round cross-section (dark centre line, thin light edges),
    2-3 swollen darker 'pause marks', a faint wet film left beside it where
    it drained, and the bottom 6 % fading into the bead."""
    rng = v2_rng(seed)
    cx, half, pause = rivulet_profile(rng, W, H)
    D, q, Y, X = rivulet_field(rng, W, H, cx, half)
    A = np.clip(0.5 - D, 0, 1)
    cap = np.sqrt(np.clip(1 - q * q, 0, 1))  # a rivulet is a circular cap in section
    flow = noise(rng, (H, W), (24, 1.2))  # faint streaks along the flow
    t = 0.12 + 0.72 * cap**1.3 + 0.12 * pause[:, None] * cap + 0.04 * flow * cap
    # wet film beside the run (it was wider while it flowed, then drained)
    film_w = half * (1.35 + 0.2 * noise(rng, (H,), 40))
    film = (1 - smooth(-1, 1, np.abs(X - cx[:, None]) - film_w[:, None])) * smooth(-0.5, 0.8, noise(rng, (H,), 50))[:, None]
    A = np.maximum(A, 0.2 * film)
    t = np.where(D < 0, t, 0.05)
    A = A * (1 - smooth(H * 0.94, H * 1.0, Y))
    return to_rgba(lum(np.clip(t, 0, 1)), A)


def rivulet_bead(seed, N=128):
    """The front bead of a run, face-on: a thick dark dome 1.0 x 1.3, a thin
    light meniscus, a short neck at the top (where the run joins it) and the
    light that passes through the drop glowing at its bottom (as in photos)."""
    rng = v2_rng(seed)
    S = Shape(N, N, rng, warps=((12, 1.2), (4, 0.4)))
    c = N * 0.5
    a = N * rng.uniform(0.25, 0.28)
    S.add(ellipse(c, c + N * 0.06, a * 1.3, a, np.pi / 2, random_harm(rng, [(3, 5, 0.03)])))
    S.add(ucap(c + rng.normal(0, 2), 0, a * 0.55, c, c, a * 0.75), 8)  # the neck
    A = S.alpha()
    d = depth_of(A)
    t = meniscus(d, 2.5) * (0.82 + 0.18 * smooth(0, a * 0.8, d))
    glow = np.exp(-(((S.X - c) / (a * 0.55)) ** 2 + ((S.Y - (c + N * 0.06 + a * 0.75)) / (a * 0.28)) ** 2))
    t = np.clip(t - 0.3 * glow * smooth(2, 6, d), 0, 1)
    return to_rgba(lum(t), A)


def rivulet_fork(seed, W=256, H=512):
    """A run that splits into 2-3 fingers below 40 % of its height (a Y / psi
    shape): blood met an obstacle (a skin crease, a hair). One finger is the
    main channel and goes further; the ends are round, without a bulb."""
    rng = v2_rng(seed)
    S = Shape(W, H, rng, warps=((18, 1.2), (5, 0.4)))
    c = W * 0.5 + rng.normal(0, 4)
    r0 = W * 0.1
    ys = np.arange(0, H * rng.uniform(0.4, 0.5), 10.0)
    trunk = [(c + 3 * np.sin(y / 37), y, r0 * (1 - 0.1 * y / H)) for y in ys]
    S.chain(trunk, k=4)
    sx, sy, sr = trunk[-1]
    n = int(rng.integers(2, 4))
    main = int(rng.integers(n))
    for i in range(n):
        ang = np.pi / 2 + (i - (n - 1) / 2) * rng.uniform(0.3, 0.45) + rng.normal(0, 0.05)
        length = (H * 0.92 - sy) * (1.0 if i == main else rng.uniform(0.35, 0.7))
        r = sr * (0.85 if i == main else rng.uniform(0.5, 0.65))
        pts = []
        for f in np.linspace(0, 1, 9):
            bend = ang + 0.35 * f * (np.pi / 2 - ang)  # gravity pulls each finger back toward straight down
            x = sx + np.cos(bend) * length * f + 2 * np.sin(f * 7 + i)
            y = sy + np.sin(bend) * length * f
            pts.append((x, y, r * (1 - 0.25 * f)))
        S.chain(pts, k=6)
        S.add(circle(pts[-1][0], pts[-1][1], pts[-1][2] * 1.05), 3)
    A = S.alpha()
    d = depth_of(A)
    t = np.clip(meniscus(d, sr * 0.45) * 0.86 + 0.04 * noise(rng, A.shape, (20, 2)), 0, 1)
    return to_rgba(lum(t), edge_alpha(A, t))


def cut_shape(rng, W, H, length, gape, bow, tilt, rim_w):
    """Shared by brow / cheek cuts: a ragged split along a curved line.
    Returns maps: slit (the open wound), rim (swollen lips), centre line v."""
    Y, X = rows_cols(H, W)
    c = W * 0.5
    u = (X - c) / (length / 2)  # -1..1 along the cut
    yc = H * 0.5 + bow * (1 - u * u) * H + tilt * u * H + 1.5 * noise(rng, (W,), 10)[None, :]
    v = Y - yc
    open_ = np.clip(1 - u * u, 0, 1) ** 0.6
    rag = 1 + 0.35 * noise(rng, (H, W), (2, 3)) + 0.25 * noise(rng, (W,), 4)[None, :]
    gap = gape * open_ * rag
    slit = (1 - smooth(-0.7, 0.7, np.abs(v) - gap)) * smooth(0.4, 1.2, gap)
    lip = gap + rim_w * (0.7 + 0.5 * noise(rng, (W,), 6)[None, :]) * np.clip(1 - np.abs(u) ** 3, 0, 1)
    rim = (1 - smooth(-1.5, 1.5, np.abs(v) - lip - 1.2 * noise(rng, (H, W), 2))) * (np.abs(u) < 1.15)
    return slit, rim, u, v, Y, X


def bridges(rng, slit, u, v, count, gape):
    """Tissue bridges: thin strands that cross the gap of a blunt laceration
    (nerves, small vessels). A cut by glass has none; a split by a fist has."""
    out = np.zeros_like(slit)
    for _ in range(count):
        u0 = rng.uniform(-0.5, 0.5)
        sl = rng.normal(0, 0.4)
        w = rng.uniform(0.012, 0.022)
        out = np.maximum(out, np.exp(-(((u - u0 - sl * v / (gape * 20)) / w) ** 2)) * slit)
    return out


def bruise_halo(rng, shape, X, Y, cx, cy, rx, ry, mott=0.6):
    """Faint mottled halo (fresh bruise / swelling) around a wound."""
    r = ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2
    m = fbm(rng, shape, [(6, 1.0), (2, 0.5)])
    return np.exp(-r * 1.4) * np.clip(1 - mott * 0.5 + mott * 0.35 * m, 0, 1)


def browcut(seed, W=256, H=128):
    """The boxing cut along the eyebrow (+X = along the brow): a dark wet slit
    with ragged gaping lips, 2-3 tissue bridges, a lighter swollen rim of
    split skin, blood welling over the LOWER end (where it will run from),
    and a faint mottled bruise. Tinted with blood colours: the rim (light
    grey) reads as raw red skin, the slit as near-black wet blood."""
    rng = v2_rng(seed)
    length = W * rng.uniform(0.62, 0.72)
    slit, rim, u, v, Y, X = cut_shape(rng, W, H, length, gape=H * 0.075, bow=-0.08, tilt=0.07, rim_w=H * 0.075)
    br = bridges(rng, slit, u, v, int(rng.integers(2, 4)), H * 0.075)
    # blood welling at the low end (+X) and spilling a little below it
    S = Shape(W, H, rng, warps=((8, 1.5), (3, 0.5)))
    ex = W * 0.5 + length * 0.42
    ey = H * 0.5 + 0.07 * H + 2
    S.add(ellipse(ex, ey + 3, 11, 7.5, 0.4, random_harm(rng, [(3, 5, 0.08)])))
    S.add(ucap(ex, ey + 3, 6.5, ex + rng.normal(2, 2), ey + H * rng.uniform(0.25, 0.34), 5), 4)
    for _ in range(int(rng.integers(2, 5))):  # little pearls of blood along the lips
        x = W * 0.5 + rng.uniform(-0.4, 0.4) * length
        k = (x - W * 0.5) / (length / 2)
        S.add(circle(x, H * 0.5 + (-0.08 * (1 - k * k) + 0.07 * k) * H + rng.uniform(3, 6), rng.uniform(1.8, 3.2)))
    welled = S.alpha()
    halo = bruise_halo(rng, (H, W), X, Y, W * 0.5, H * 0.5, length * 0.62, H * 0.38)
    L = np.full((H, W), 0.7, F32)
    A = 0.16 * halo
    L = np.where(rim > 0.02, 0.9 - 0.12 * noise(rng, (H, W), 2) * 0.5, L)
    A = np.maximum(A, rim * 0.8)
    wet_d = depth_of(np.maximum(slit, welled))
    L = np.where(np.maximum(slit, welled) > 0.02, 0.3 + 0.18 * (1 - meniscus(wet_d, 1.6)), L)
    A = np.maximum(A, np.maximum(slit, welled))
    L = np.where(br > 0.3, 0.75, L)  # the bridges are lighter strands across the gap
    return to_rgba(np.clip(L, 0, 1), np.clip(A, 0, 1))


def cheekcut(seed, W=256, H=128):
    """Cheekbone split: a shorter crescent (bowed toward +Y), more bruised and
    swollen than the brow cut."""
    rng = v2_rng(seed)
    length = W * rng.uniform(0.46, 0.52)
    slit, rim, u, v, Y, X = cut_shape(rng, W, H, length, gape=H * 0.065, bow=0.12, tilt=0.02, rim_w=H * 0.085)
    br = bridges(rng, slit, u, v, 2, H * 0.065)
    halo = bruise_halo(rng, (H, W), X, Y, W * 0.5, H * 0.56, length * 0.85, H * 0.42, mott=0.9)
    S = Shape(W, H, rng, warps=((8, 1.5),))
    lx = W * 0.5 + rng.choice([-1, 1]) * length * 0.1
    S.add(ellipse(lx, H * 0.5 + 0.12 * H + 4, 7, 5, 0.0))
    S.add(ucap(lx, H * 0.62 + 4, 4.5, lx + rng.normal(0, 2), H * 0.86, 3.5), 4)
    welled = S.alpha()
    L = np.full((H, W), 0.62, F32)
    A = 0.32 * halo
    L = np.where(rim > 0.02, 0.88, L)
    A = np.maximum(A, rim * 0.8)
    wet = np.maximum(slit, welled)
    L = np.where(wet > 0.02, 0.3 + 0.18 * (1 - meniscus(depth_of(wet), 1.6)), L)
    A = np.maximum(A, wet)
    L = np.where(br > 0.3, 0.75, L)
    return to_rgba(np.clip(L, 0, 1), np.clip(A, 0, 1))


def lipfilm(seed, W=256, H=64):
    """A thin film of blood along the lower lip (+X = across the mouth),
    lighter (thin, mixed with saliva), with 2-3 short beads hanging from its
    bottom edge, darker (thicker) because blood collects there."""
    rng = v2_rng(seed)
    S = Shape(W, H, rng, warps=((10, 1.5), (3, 0.5)))
    pts = []
    lump = noise(rng, (16,), 1.5)
    for j, x in enumerate(np.linspace(W * 0.08, W * 0.92, 16)):
        f = (x - W * 0.5) / (W * 0.42)
        pts.append((x, H * 0.36 + 2 * f * f + rng.normal(0, 0.6), (H * 0.11 + 2.5 * lump[j]) * np.sqrt(max(0.05, 1 - f**4)) + 1.5))
    S.chain(pts, k=5)
    for _ in range(int(rng.integers(2, 4))):  # the film breaks where the lip was dry
        S.add(circle(rng.uniform(W * 0.15, W * 0.85), H * 0.3 + rng.normal(0, 2), rng.uniform(2.5, 5)), 2, sub=True)
    beads = []
    for _ in range(int(rng.integers(2, 4))):
        x = rng.uniform(W * 0.2, W * 0.8)
        L = rng.uniform(H * 0.18, H * 0.4)
        r = rng.uniform(4, 6.5)
        y0 = H * 0.42
        S.add(ucap(x, y0, r * 0.55, x + rng.normal(0, 1), y0 + L, r * 0.75), 4)
        S.add(ellipse(x, y0 + L + r * 0.4, r * 1.15, r, np.pi / 2), 3)
        beads.append((x, y0 + L + r * 0.4, r))
    A = S.alpha()
    d = depth_of(A)
    t = 0.08 + 0.16 * meniscus(d, 2.0) + 0.05 * noise(rng, A.shape, (2, 8))
    for x, y, r in beads:
        g = np.exp(-(((S.X - x) / (r * 1.1)) ** 2 + ((S.Y - y) / (r * 1.3)) ** 2))
        t = np.maximum(t, 0.78 * g * meniscus(d, 1.5))
    return to_rgba(lum(np.clip(t, 0, 1)), A)


def crack_plates(rng, h, w, cell, warp=1.5):
    """Dried crust breaks into plates (like dried mud). Voronoi cells about
    `cell` px wide. Returns the distance (px) to the nearest crack and the
    plate id of each pixel."""
    from scipy.spatial import cKDTree

    Y, X = rows_cols(h, w)
    Yw = Y + warp * noise(rng, (h, w), 3)
    Xw = X + warp * noise(rng, (h, w), 3)
    n = max(4, int(h * w / (cell * cell)))
    pts = np.stack([rng.uniform(0, h, n), rng.uniform(0, w, n)], 1)
    tree = cKDTree(pts)
    q = np.stack([Yw.ravel(), Xw.ravel()], 1)
    dist, idx = tree.query(q, k=2)
    p1, p2 = pts[idx[:, 0]], pts[idx[:, 1]]
    sep = np.linalg.norm(p2 - p1, axis=1) + 1e-6
    edge = (dist[:, 1] ** 2 - dist[:, 0] ** 2) / (2 * sep)
    return edge.reshape(h, w).astype(F32), idx[:, 0].reshape(h, w)


def crust_from(rng, A, cell, gap_p=0.12, lam=3.0):
    """Turn a wet stain (alpha A) into dried crust: cracked plates, each its
    own thickness, lighter flaking edges where plates lift, a darker dried
    rim along the outline (coffee ring), and some plates fallen off near the
    edge. Matte: high contrast inside."""
    h, w = A.shape
    edge, pid = crack_plates(rng, h, w, cell)
    d = depth_of(A)
    plate_t = np.random.default_rng(int(rng.integers(1 << 30))).uniform(0.3, 0.62, pid.max() + 1)[pid]
    lost = np.random.default_rng(int(rng.integers(1 << 30))).random(pid.max() + 1)[pid]
    # only part of the plate borders are open cracks (a real crust is not a mosaic)
    opened = smooth(0.0, 0.8, noise(rng, (h, w), cell * 0.6))
    crack = (1 - smooth(0.35, 1.0, edge)) * opened
    near_edge = 1 - smooth(4, 14, d)
    gone = (lost < gap_p * (0.3 + 1.7 * near_edge)).astype(F32)
    lift = (1 - smooth(0.8, 3.0, edge)) * opened  # open plate borders curl up: thinner, lighter
    ring = np.exp(-(((d - 2.5) / 2.5) ** 2))
    t = plate_t * (1 - 0.35 * lift) + 0.3 * ring + 0.07 * noise(rng, (h, w), 1.0)
    t = np.clip(t * meniscus(d, lam) * 1.15, 0, 1)
    cov = A * (1 - crack * 0.85) * (1 - gone)
    return t, cov


def crust_strip(seed, W=128, H=512):
    """A dried run (same outline family as rivulet_strip, another seed):
    cracked plates, flaking lighter edges, a darker dried rim along both
    sides, small gaps. Placed over an old run when it dries."""
    rng = v2_rng(seed)
    cx, half, pause = rivulet_profile(rng, W, H, top=0.22, bottom=0.17)
    D, q, Y, X = rivulet_field(rng, W, H, cx, half, wobble=1.4)
    A = np.clip(0.5 - D, 0, 1)
    t, cov = crust_from(rng, A, cell=rng.uniform(16, 22), gap_p=0.08)
    t = np.clip(t + 0.1 * pause[:, None], 0, 1)
    cov = cov * (1 - smooth(H * 0.93, H, Y))
    return to_rgba(lum(t), cov)


def crust_patch(seed, N=256):
    """A dried smear / dried lip: an irregular patch of cracked, flaky, matte
    crust with holes."""
    rng = v2_rng(seed)
    S = Shape(N, N, rng, warps=((20, 5.0), (6, 1.5)))
    c = N * 0.5
    for _ in range(int(rng.integers(4, 7))):
        S.add(circle(c + rng.normal(0, N * 0.1), c + rng.normal(0, N * 0.07), N * rng.uniform(0.1, 0.18), random_harm(rng, [(3, 6, 0.08)])), N * 0.06)
    for _ in range(int(rng.integers(3, 7))):  # holes where it never covered
        S.add(circle(c + rng.normal(0, N * 0.12), c + rng.normal(0, N * 0.1), rng.uniform(4, 10)), 3, sub=True)
    for _ in range(int(rng.integers(5, 12))):
        satellite(S, rng, c + rng.normal(0, N * 0.3), c + rng.normal(0, N * 0.25), rng.uniform(1.5, 4), rng.uniform(0, 6.28))
    A = S.alpha()
    t, cov = crust_from(rng, A, cell=rng.uniform(18, 26), gap_p=0.12)
    return to_rgba(lum(t), cov)


def bubble_rings(rng, S, t, A, count, rmin, rmax, inside):
    """Froth: small air bubbles in thin blood. Lighter inside (a thin film
    stretched over the bubble), a thin dark ring at its foot."""
    ys, xs = np.nonzero(inside)
    if len(ys) == 0:
        return t, A
    for _ in range(count):
        j = int(rng.integers(len(ys)))
        r = rng.uniform(rmin, rmax)
        rr = np.hypot(S.X - xs[j], S.Y - ys[j])
        ring = np.exp(-(((rr - r) / max(0.9, r * 0.12)) ** 2))
        inner = 1 - smooth(r - 1.2, r, rr)
        t = np.where(inner > 0.5, 0.06, t)
        t = np.maximum(t, 0.85 * ring)
        A = np.where(inner > 0.5, A * 0.55, A)
        A = np.maximum(A, ring * 0.95)
    return t, A


def spit(seed, N=256):
    """Expirated blood (spat / coughed): an irregular light blob full of
    bubble rings, smaller blobs around, and one thin string of saliva toward
    +X. Mostly thin (light): tinted Config.Blood.PALETTE.SALIVA."""
    rng = v2_rng(seed)
    S = Shape(N, N, rng, warps=((16, 3.0), (5, 1.0)))
    c = N * 0.42
    for _ in range(int(rng.integers(3, 6))):
        S.add(circle(c + rng.normal(0, 14), N * 0.5 + rng.normal(0, 12), rng.uniform(18, 32), random_harm(rng, [(3, 6, 0.08), (8, 14, 0.04)])), 12)
    for _ in range(int(rng.integers(3, 8))):
        a = rng.uniform(-1.6, 1.6)
        d = rng.uniform(60, 100)
        S.add(circle(c + np.cos(a) * d, N * 0.5 + np.sin(a) * d * 0.8, rng.uniform(3, 9), random_harm(rng, [(3, 5, 0.1)])), 2)
    # the string: a thin wavy thread with a tiny blob or two on it
    y = N * 0.5 + rng.normal(0, 6)
    pts = [(c + 25 + i * 16, y + 6 * np.sin(i * 0.9 + rng.uniform(0, 3)), 1.8 + 0.6 * rng.random()) for i in range(int(rng.integers(5, 8)))]
    S.chain(pts, k=2)
    for p in pts[2::3]:
        S.add(ellipse(p[0], p[1], 4, 2.6, 0), 2)
    A = S.alpha()
    d = depth_of(A)
    t = 0.22 + 0.28 * meniscus(d, 3) + 0.08 * noise(rng, A.shape, 6)
    t, A = bubble_rings(rng, S, t, A, int(rng.integers(5, 11)), 2.5, 8, d > 9)
    t, A = bubble_rings(rng, S, t, A, int(rng.integers(8, 16)), 1.2, 2.6, d > 4)
    return to_rgba(lum(np.clip(t, 0, 1)), np.clip(A, 0, 1))


def crown_cell(f, seed, N=256):
    """One frame (f = 0..15) of a drop splashing on the ground, seen from the
    side and a little above (camera-facing particle). Ground = near the
    bottom of the cell. 0-2 the drop flattens, 3-7 a thin crown rises with
    fingers, 8-11 the fingers throw droplets out, 12-15 it collapses into a
    flat wet lens. The crown wall is a thin sheet: light and see-through,
    thicker (darker) at its foot and in its beaded rim."""
    rng = np.random.default_rng(seed)
    S = Shape(N, N, rng, warps=((14, 0.8),))
    c, g = N * 0.5, N * 0.86
    R0 = N * 0.1
    sheet = np.zeros((N, N), F32)
    sheet_l = np.full((N, N), 0.8, F32)
    n_f = 9
    phis = np.linspace(0, 2 * np.pi, n_f, endpoint=False) + rng.uniform(0, 0.7)
    flen = 0.7 + 0.5 * rng.random(n_f)
    lens_a = R0 * (1.0 + 1.9 * (1 - np.exp(-f / 4)))
    lens_b = max(2.5, R0 * (0.9 * np.exp(-f / 1.2) + 0.1))
    if f == 0:
        S.add(circle(c, g - R0, R0))
    elif f <= 2:
        S.add(ellipse(c, g - lens_b, lens_a, lens_b, 0))
    else:
        S.add(ellipse(c, g - 2.5, lens_a, 4.0, 0))
    tilt = 0.3  # seen a little from above: circles become ellipses
    if f >= 2:
        k = np.clip((f - 2) / 6, 0, 1)
        col = np.clip((f - 11) / 4, 0, 1)  # collapse
        Hc = R0 * (0.3 + 2.0 * k) * (1 - col)
        Rb = R0 * (1.5 + 0.8 * k + 0.3 * col)  # wall foot radius
        Rt = Rb * (1.2 + 0.3 * k)  # the crown flares outward (a tulip, not a bucket)
        yt = g - 3 - Hc
        if Hc > 1.5:
            Y, X = rows_cols(N, N)
            yrel = np.clip((g - 3 - Y) / max(Hc, 1), 0, 1)
            rad = Rb + (Rt - Rb) * yrel
            ex = np.clip(1 - ((X - c) / rad) ** 2, 0, 1)
            inside = (np.abs(X - c) < rad) & (Y < g - 3 + tilt * Rb * np.sqrt(ex)) & (Y > yt - tilt * Rt * np.sqrt(ex))
            side = np.abs(X - c) / np.maximum(rad, 1)  # the sheet looks denser where seen edge-on
            sheet = inside.astype(F32) * (0.12 + 0.3 * (1 - yrel) ** 2 + 0.3 * side**8)
            sheet_l = 0.92 - 0.3 * (1 - yrel) ** 2 - 0.15 * side**8
            for i in range(32):  # the beaded rim
                a0, a1 = 2 * np.pi * i / 32, 2 * np.pi * (i + 1) / 32
                rb = 1.6 + 0.9 * ((i * 5) % 3) / 2  # beads of uneven size along the rim
                S.add(ucap(c + Rt * np.cos(a0), yt + tilt * Rt * np.sin(a0), rb, c + Rt * np.cos(a1), yt + tilt * Rt * np.sin(a1), 1.6), 1)
        for i, p in enumerate(phis):
            bx, by = c + Rt * np.cos(p), yt + tilt * Rt * np.sin(p)
            out = np.cos(p)
            L0 = R0 * 1.3 * flen[i]
            fl = L0 * np.clip((f - 3) / 4, 0, 1) * (1 - col)
            if fl > 1 and f <= 9:  # a finger with a bead at its tip
                tx, ty = bx + out * fl * 0.5, by - fl
                S.add(ucap(bx, by, 4.6, tx, ty, 2.4), 3)
                if f >= 5:
                    S.add(circle(tx + out, ty - 2, 3.6 + 0.5 * (f - 5)), 2)
            if f >= 9:
                tf = (f - 8) / 7  # ballistic flight of the released droplet
                dx = bx + out * (L0 * 0.5 + R0 * 3.0 * tf)
                dy = by - L0 - R0 * 3.2 * tf + R0 * 5.0 * tf * tf
                if dy < g - 3:
                    S.add(ellipse(dx, dy, 4.4, 4.0, 0))
                    if f <= 10:
                        S.add(ucap(bx + out * L0 * 0.3, by - L0 * 0.6, 1.0, dx, dy, 1.4), 1)
                else:
                    S.add(ellipse(dx, g - 2, 6, 2.0, 0))  # landed: a tiny lens
    A = S.alpha()
    A[int(g + 3) :, :] = 0
    Ls = shade_liquid(A, dome(A))
    L = np.where(A > 0.02, Ls, sheet_l)
    A_all = np.maximum(A, sheet * (1 - A))
    return to_rgba(np.clip(L, 0, 1), np.clip(A_all, 0, 1))


def crown_4x4():
    return grid([crown_cell(f, 2000) for f in range(16)], 4)


def ripple_ring(N=256):
    """A ripple on a wet pool after a drop: a bright thin crest (reflecting
    the sky), a darker trough just inside it, a faint second ring, and a
    highlight on one side. Scaled up and faded by the code."""
    rng = v2_rng(2100)
    Y, X = rows_cols(N, N)
    c = N * 0.5
    r = np.hypot(X - c, Y - c) * (1 + 0.006 * noise(rng, (N, N), 20))
    th = np.arctan2(Y - c, X - c)
    side = 0.55 + 0.45 * np.cos(th + 2.3)  # light from the top left
    R1, R2 = N * 0.44, N * 0.3
    crest = np.exp(-(((r - R1) / 1.3) ** 2))
    trough = np.exp(-(((r - (R1 - 4.5)) / 2.0) ** 2))
    inner = np.exp(-(((r - R2) / 1.2) ** 2)) * 0.4
    A = np.clip(np.maximum.reduce([crest * (0.45 + 0.55 * side), trough * 0.35, inner * (0.5 + 0.5 * side)]), 0, 1)
    L = np.where(trough * 0.35 > np.maximum(crest, inner), 0.38, 1.0)
    return to_rgba(L, A)


def starburst(seed, N=512):
    """Drip-into-pool satellites: every drop falling into a wet pool throws
    tiny droplets out, radially. After a dozen drops the pool sits in a
    'starburst' of dots. Centre 25 % empty (the pool covers it)."""
    rng = v2_rng(seed)
    S = Shape(N, N, rng, warps=((20, 0.8),))
    c = N * 0.5
    R = N * 0.48
    for _ in range(int(rng.integers(70, 120))):
        a = rng.uniform(0, 2 * np.pi)
        d = R * (0.3 + 0.7 * rng.random() ** 1.7)
        far = (d / R - 0.3) / 0.7
        r = np.clip(rng.lognormal(np.log(3.2 - 1.8 * far), 0.4), 1.0, 6.0)
        x, y = c + np.cos(a) * d, c + np.sin(a) * d
        satellite(S, rng, x, y, r, a, tail_p=0.35 + 0.4 * far)
    A = S.alpha()
    t = np.clip(meniscus(depth_of(A), 1.6) * 1.1, 0, 1)
    return to_rgba(lum(t), edge_alpha(A, t))


def fibre_feather(rng, shape, length=8):
    """Noise stretched along random fibre directions (0, 45, 90, 135 deg
    mixed): what the edge of a wicking stain follows on cloth."""
    h, w = shape
    a = noise(rng, shape, (0.8, length))
    b = noise(rng, shape, (length, 0.8))
    cdiag = ndi.rotate(noise(rng, (h * 2, w * 2), (0.8, length)), 45, reshape=False, order=1)[h // 2 : h // 2 + h, w // 2 : w // 2 + w]
    cdiag = cdiag / (cdiag.std() + 1e-6)
    sel = noise(rng, shape, 24)
    return np.where(sel > 0.3, np.maximum(a, b), np.maximum(cdiag, 0.6 * a))


def wick_halo(seed, N=512):
    """The wicking edge of a blood stain on cotton: a fuzzy ring, feathered
    outward along the fibres, fading in toward an empty middle (the soak
    picture covers it: place it at the soak's size, the pale fringe 1.25x). Tinted FABRIC_WET it is the dark wet
    patch that shows on ANY shirt colour; tinted pale, the plasma fringe."""
    rng = v2_rng(seed)
    S = Shape(N, N, rng, warps=((50, 14.0), (14, 4.0)))
    c = N * 0.5
    R = N * 0.31  # placed at the SAME size as the soak, it starts just inside its edge
    S.add(circle(c, c, R, random_harm(rng, [(3, 5, 0.06), (6, 9, 0.03)])))
    D = S.D
    band = R * rng.uniform(0.42, 0.5)
    # (same lesson as soak: long fibre streaks read as fur. Capillary lobes a
    # few threads deep, with only a faint fibre bias.)
    feather = fibre_feather(rng, (N, N), length=4)
    lobes = fbm(rng, (N, N), [(9, 1.0), (3.5, 0.6)])
    outer = smooth(-0.5, 0.5, -D / 9 + 0.12 * feather + 0.45 * lobes)
    # wettest (darkest) next to the stain, fading out toward the fibre edge;
    # the inside melts away under the soak picture
    inner = smooth(-band * 1.3, -band * 0.55, D + 6 * noise(rng, (N, N), 10))
    A = outer * inner * (0.5 + 0.5 * smooth(0, -band * 0.7, D))
    t = 0.65 - 0.3 * smooth(-band * 0.7, 0, D) + 0.06 * noise(rng, (N, N), 6)
    return to_rgba(lum(np.clip(t, 0, 1)), np.clip(A * 0.95, 0, 1))


def wick_weave(seed=2301, N=512):
    """Wicking on a synthetic woven fabric: blood follows the threads (warp
    and weft), so the halo is squarish (a rounded rectangle), feathered along
    H and V only. Empty centre, like wick_halo (same size as the soak)."""
    rng = v2_rng(seed)
    Y, X = rows_cols(N, N)
    c = N * 0.5
    dx = np.abs(X - c + 8 * noise(rng, (N, N), 30)) / (N * 0.32)
    dy = np.abs(Y - c + 8 * noise(rng, (N, N), 30)) / (N * 0.28)
    r = (dx**3.2 + dy**3.2) ** (1 / 3.2)  # a superellipse: between a circle and a square
    D = (r - 1) * N * 0.3  # about a distance in px, < 0 inside
    feather = np.maximum(noise(rng, (N, N), (0.7, 6)), noise(rng, (N, N), (6, 0.7)))
    lobes = fbm(rng, (N, N), [(8, 1.0), (3, 0.6)])
    outer = smooth(-0.5, 0.5, -D / 8 + 0.3 * feather + 0.35 * lobes)
    band = N * 0.13
    inner = smooth(-band * 1.3, -band * 0.55, D + 5 * noise(rng, (N, N), 8))
    A = outer * inner * (0.5 + 0.5 * smooth(0, -band * 0.7, D))
    t = 0.65 - 0.3 * smooth(-band * 0.7, 0, D) + 0.05 * noise(rng, (N, N), 5)
    return to_rgba(lum(np.clip(t, 0, 1)), np.clip(A * 0.95, 0, 1))


def serum_halo(n, N=512):
    """Paired with pool_<n> (same outline, same frame): the pale ring of
    serum that seeps OUT of an old pool as the clot shrinks (plasma leaves
    the red cells behind). Transparent inside the pool. Tinted SERUM."""
    _, S = pool_shape(700 + n, 1024)
    big = S.alpha()
    A0 = big.reshape(N, 2, N, 2).mean(axis=(1, 3))  # 1024 -> 512, same frame
    # small drops beside the pool dry too fast to weep serum: keep the big body
    lab, k = ndi.label(A0 >= 0.5)
    areas = ndi.sum(np.ones_like(A0), lab, range(1, k + 1))
    keep = np.isin(lab, 1 + np.nonzero(areas >= 0.05 * areas.max())[0])
    A0 = np.where(keep, A0, 0.0)
    rng = v2_rng(2400 + n)
    out_d = ndi.distance_transform_edt(A0 < 0.5).astype(F32)
    width = N * (0.02 + 0.04 * smooth(-1, 1, noise(rng, (N, N), 30)))
    band = (1 - smooth(width * 0.6, width, out_d)) * (A0 < 0.5)
    tide = np.exp(-(((out_d - width * 0.85) / 1.6) ** 2)) * band
    A = np.clip(band * (0.55 - 0.3 * out_d / (width + 1)) + 0.3 * tide, 0, 1) * (1 - A0)
    L = np.clip(1.0 - 0.45 * tide + 0.04 * noise(rng, (N, N), 3), 0, 1)
    return to_rgba(L, A)


def drag(seed, W=1024, H=256):
    """A body dragged / sliding toward +X: the blood that was lying there is
    pushed into a heavy smeared start (left), then a film wiped by the cloth
    with 8-14 irregular parallel striations, broken where the ground's high
    points interrupt it, thinning and fading to nothing on the right."""
    rng = v2_rng(seed)
    Y, X = rows_cols(H, W)
    curve = 10 * noise(rng, (W,), 200)[None, :]
    Yc = Y - H * 0.5 - curve
    prog = np.clip((X - W * 0.1) / (W * 0.85), 0, 1)
    half = H * 0.34 * (1 - 0.45 * prog) + 5 * noise(rng, (W,), 30)[None, :]
    band = 1 - smooth(-3, 3, np.abs(Yc) - half - 7 * noise(rng, (H, W), (3, 20)) - 3 * noise(rng, (H, W), 2))
    # striations: lanes at uneven spacing, each its own width, strength and end
    n = int(rng.integers(8, 15))
    ys = np.sort(rng.uniform(-1, 1, n)) * H * 0.3
    lanes = np.zeros((H, W), F32)
    for y0 in ys:
        w = rng.uniform(1.5, 7)
        end = W * rng.uniform(0.4, 0.97)
        wig = 2.0 * noise(rng, (W,), 70)[None, :]
        broken = smooth(-1.2, -0.2, noise(rng, (W,), rng.uniform(8, 30)))[None, :]  # gaps along a lane
        g = np.exp(-(((Yc - y0 * (1 - 0.4 * prog) - wig) / w) ** 2)) * broken
        lanes = np.maximum(lanes, g * (1 - smooth(end - W * 0.2, end, X)) * rng.uniform(0.5, 1.0))
    grit = noise(rng, (H, W), 1.3) + 0.6 * noise(rng, (H, W), 5) + 0.5 * noise(rng, (H, W), (2, 30))
    thr = -2.0 + 3.6 * prog**1.1  # the further, the more the ground breaks the film
    film = smooth(thr - 0.35, thr + 0.35, grit) * (1 - smooth(0.05, 0.6, prog))
    cov = np.maximum(smooth(thr - 0.35, thr + 0.35, grit + 1.2) * lanes, film * 0.9) * band
    # the start: pooled blood pushed forward (its front smeared into the film)
    S = Shape(W, H, rng, warps=((30, 8.0), (9, 2.0)))
    hx = W * 0.1
    for _ in range(5):
        S.add(ellipse(hx + rng.normal(0, 14), H * 0.5 + curve[0, int(hx)] + rng.normal(0, 14), rng.uniform(34, 50), rng.uniform(26, 40), rng.normal(0, 0.2), random_harm(rng, [(3, 6, 0.06)])), 22)
    head = S.alpha()
    head = np.maximum(head, ndi.uniform_filter1d(head, 60, axis=1, origin=-29) * 0.9 * band)  # pushed toward +X
    cov = np.maximum(cov * smooth(hx - 40, hx + 10, X), head)
    t = 0.18 + 0.4 * (1 - prog) ** 1.3 + 0.25 * lanes * (1 - 0.6 * prog) + 0.05 * noise(rng, (H, W), 6)
    hd = depth_of(head)
    t = np.where(head > 0.5, np.maximum(t, (0.4 + 0.5 * meniscus(hd, 8)) * (1 - 0.45 * smooth(hx, hx + 90, X))), t)
    A = cov * (0.55 + 0.45 * smooth(0.05, 0.45, t)) * (1 - smooth(W * 0.9, W, X))
    return to_rgba(lum(np.clip(t, 0, 1)), np.clip(A, 0, 1))


def shoe_run(seed, mirror=False, N=256):
    """A running print: only the forefoot lands (tread lugs, grooves partly
    filled), the shoe slips forward a little on the wet blood (streaks
    toward the toes = toward the top of the image, the way the runner
    goes), and no heel."""
    rng = v2_rng(seed)
    side = -1 if mirror else 1
    S = Shape(N, N, rng, warps=((24, 1.2),))
    cy = N * 0.6
    S.add(ellipse(128 + 6 * side, cy, 44, 48, 0.12 * side))
    S.add(ucap(128 + 8 * side, cy + 30, 37, 128 + 4 * side, cy + 58, 30), 18)
    D = S.D.copy()
    inside = np.clip(0.5 - D, 0, 1)
    Y, X = rows_cols(N, N)
    jx, jy = 1.6 * noise(rng, (N, N), 5), 1.6 * noise(rng, (N, N), 5)
    cw, ch = 15.0, 11.0
    row = np.floor((Y + jy) / ch)
    u = ((X + jx + (row % 2) * cw * 0.5) / cw) % 1.0
    w = ((Y + jy) / ch) % 1.0
    cell_id = np.floor((X + jx + (row % 2) * cw * 0.5) / cw) * 37 + row * 11
    size = 0.4 + 0.06 * np.sin(cell_id * 12.9898)
    box = np.maximum(np.abs(u - 0.5) - size + 0.12, 0) ** 2 + np.maximum(np.abs(w - 0.5) - size * 0.85 + 0.12, 0) ** 2
    lugs = (1 - smooth(0.0035, 0.012, box)) * smooth(-2.0, -1.3, noise(rng, (N, N), 4))
    rim = np.clip(0.5 - np.abs(D + 4.5) + 3.0, 0, 1)
    press = fbm(rng, (N, N), [(18, 1.0), (5, 0.6)])
    fill = smooth(-0.5, 0.3, press + 0.6 * smooth(cy + 10, cy - 40, Y))  # blood in the grooves, more at the toes
    heel_fade = 1 - smooth(cy + 15, cy + 70, Y + 10 * noise(rng, (N, N), 8))  # the back barely touched
    tread = np.maximum(np.maximum(lugs, rim), fill * 0.9) * inside * heel_fade * smooth(-2.4, -1.8, press)
    # the forward slip: the front of the print dragged toward the toes
    src = tread * smooth(cy + 5, cy - 25, Y)
    slip = np.zeros_like(src)
    reach = rng.uniform(40, 60)
    for k in range(1, int(reach)):
        slip = np.maximum(slip, np.roll(src, -k, axis=0) * (1 - k / reach) ** 1.3)
    streak = smooth(-0.5, 0.7, noise(rng, (N, N), (16, 1.6)) + 0.4 * noise(rng, (N, N), (40, 4)))
    slip = slip * streak * (1 - inside * 0.6)
    cov = np.maximum(tread, slip * 0.9)
    t = np.clip(0.55 + 0.18 * press - 0.3 * (slip > tread) * (1 - slip), 0.1, 1)
    A = np.clip(cov, 0, 1) * (0.6 + 0.4 * smooth(0.1, 0.5, t))
    return to_rgba(lum(t), A)


def froth_cell(i, N=256):
    """A frothy gob of blood + saliva / mucus (spat, blown from the nose):
    a lumpy blob riddled with bubbles (holes with a bright rim), lighter
    than pure blood."""
    rng = np.random.default_rng(2500 + i)
    S = Shape(N, N, rng, warps=((18, 3.0), (6, 1.0)))
    c = N * 0.5
    for _ in range(int(rng.integers(3, 7))):
        S.add(circle(c + rng.normal(0, 22), c + rng.normal(0, 22), rng.uniform(22, 44)), 18)
    if i % 3 == 0:  # a strand trailing off
        a = rng.uniform(0, 6.28)
        S.chain([(c + np.cos(a) * d, c + np.sin(a) * d + 6 * np.sin(d / 15), 7 - d / 25) for d in np.linspace(20, 115, 7)], k=6)
    holes = []
    for _ in range(int(rng.integers(10, 26))):
        x, y = c + rng.normal(0, 28), c + rng.normal(0, 28)
        r = np.clip(rng.lognormal(np.log(6), 0.45), 2.5, 16)
        holes.append((x, y, r))
    A = S.alpha()
    h = dome(A)
    for x, y, r in holes:
        rr = np.hypot(S.X - x, S.Y - y)
        h = h + 0.6 * r * np.sqrt(np.clip(1 - (rr / r) ** 2, 0, 1))  # bubbles bulge out
    L = shade_liquid(A, h, soft=1.0) + 0.14
    for x, y, r in holes:
        rr = np.hypot(S.X - x, S.Y - y)
        if rng.random() < 0.45:  # a popped bubble: a hole with a light rim
            A = np.where(rr < r * 0.7, A * smooth(r * 0.45, r * 0.7, rr), A)
            L = np.where(np.abs(rr - r * 0.8) < 1.6, np.maximum(L, 0.85), L)
    return to_rgba(np.clip(L, 0, 1), np.clip(A, 0, 1))


def froth_4x4():
    return grid([froth_cell(i) for i in range(16)], 4)


def pendant_cell(f, N=256):
    """A drop hanging under a wet edge (stump, chin, fingertip): 0 round,
    1 pear, 2 necked, 3 released (falling drop + tiny satellite + the small
    bead left behind). The edge it hangs from is the TOP of the cell."""
    rng = np.random.default_rng(2600)
    S = Shape(N, N, rng, warps=((20, 0.8),))
    c = N * 0.5
    S.add(ellipse(c, -6, 46, 11, 0))  # the wet edge it hangs from
    if f == 0:
        S.add(circle(c, 52, 44), 22)
    elif f == 1:
        S.add(ucap(c, 14, 26, c, 112, 49), 16)
    elif f == 2:
        S.add(ucap(c, 8, 20, c, 96, 6), 14)
        S.add(ucap(c, 96, 6, c, 162, 48), 10)
    else:
        S.add(circle(c, 12, 20), 14)
        S.add(circle(c, 116, 7))
        S.add(ellipse(c, 198, 44, 47, 0))
    A = S.alpha()
    return to_rgba(shade_liquid(A, dome(A)), A)


def pendant_2x2():
    return grid([pendant_cell(f) for f in range(4)], 2)


def wipe_smear(seed, W=512, H=256):
    """The back of a hand / a forearm wiped across a bleeding face (+X): a
    heavier start, 4-6 parallel knuckle lanes, a thin film that breaks up and
    feathers out, and a fairly abrupt end where the hand left the skin."""
    rng = v2_rng(seed)
    Y, X = rows_cols(H, W)
    bend = rng.uniform(-0.0006, 0.0006)
    Yc = Y - H * 0.5 - bend * (X - W * 0.5) ** 2 - 5 * noise(rng, (W,), 60)[None, :]
    prog = np.clip((X - W * 0.08) / (W * 0.8), 0, 1)
    nf = int(rng.integers(4, 7))
    sp = H * 0.6 / nf
    lanes = np.zeros((H, W), F32)
    for i in range(nf):
        y0 = (i - (nf - 1) / 2) * sp * (1 - 0.2 * prog) + rng.normal(0, 2) + 2 * noise(rng, (W,), 50)[None, :]
        lanes = np.maximum(lanes, np.exp(-(((Yc - y0) / (sp * rng.uniform(0.2, 0.32))) ** 2)) * rng.uniform(0.6, 1.0))
    width = (nf * sp / 2 + 6) * (1 - 0.25 * prog)
    edge = np.abs(Yc) + 9 * noise(rng, (H, W), (5, 24)) + 4 * noise(rng, (H, W), 3)
    film = 1 - smooth(width - 5, width + 5, edge)
    endx = W * rng.uniform(0.84, 0.9) + 8 * noise(rng, (H,), 10)[:, None]
    end = 1 - smooth(endx - 2, endx + 1, X)
    start = smooth(W * 0.03, W * 0.1, X + 14 * noise(rng, (H, W), 8))
    stri = fbm(rng, (H, W), [((2.0, 30), 1.0), ((4, 70), 0.6), ((10, 12), 0.5)])
    thr = -1.6 + 2.4 * prog**1.2
    cov = film * start * end * smooth(thr - 0.45, thr + 0.45, stri + 1.1 * lanes - 0.4)
    t = 0.08 + 0.26 * (1 - prog) ** 1.6 + 0.1 * lanes * (1 - 0.5 * prog) + 0.04 * np.clip(stri, -1, 2)
    t = t + 0.12 * np.exp(-(((X - endx) / 3.0) ** 2)) * film  # blood piles up a little where the hand lifted
    A = cov * (0.4 + 0.6 * smooth(0.04, 0.35, t))
    return to_rgba(lum(np.clip(t, 0, 0.6)), np.clip(A, 0, 1))


def abrasion(seed, N=512):
    """Road rash (skin scraped on asphalt / concrete), +X = the way it slid:
    an irregular raw patch, fine parallel scratches along +X that run past
    its ends, pinpoint bleeding dots, a little blood film where it is
    deepest, a few grit specks and small lifted skin tags heaped at the +X
    end. A mask tinted Config.Blood.PALETTE.RAW: light = pink raw skin,
    darker = blood (redder after the tint), darkest = grit."""
    rng = v2_rng(seed)
    S = Shape(N, N, rng, warps=((40, 10.0), (12, 3.0), (4, 1.0)))
    c = N * 0.5
    for _ in range(int(rng.integers(4, 7))):
        S.add(ellipse(c + rng.normal(0, N * 0.07), c + rng.normal(0, N * 0.04), N * rng.uniform(0.12, 0.19), N * rng.uniform(0.05, 0.09), rng.normal(0, 0.1)), N * 0.05)
    D = S.D
    Y, X = rows_cols(N, N)
    scratch = noise(rng, (N, N), (0.6, 22)) + 0.7 * noise(rng, (N, N), (1.4, 50))
    core = smooth(-0.8, 0.8, -D / 8 + 0.35 * noise(rng, (N, N), (1.0, 14)))
    # scratches continue past the patch along the slide (+X and -X ends)
    tails = smooth(1.2, 2.2, scratch) * (1 - smooth(0, 70, D)) * (1 - core)
    depth = smooth(0, 45, -D)
    mott = fbm(rng, (N, N), [(7, 1.0), (2, 0.5)])
    L = 0.8 - 0.2 * depth + 0.05 * mott - 0.06 * np.clip(scratch, -2, 2) / 2
    patchy = 0.75 + 0.2 * smooth(-1, 1, noise(rng, (N, N), 12))
    A = np.maximum(core * patchy * (0.8 + 0.2 * depth), 0.55 * tails)
    # a thin blood film where it is deepest
    film = smooth(0.4, 1.2, noise(rng, (N, N), 9) + 1.2 * depth - 0.6) * core
    L = L * (1 - 0.6 * film) + 0.42 * 0.6 * film
    ys, xs = np.nonzero(D < -6)
    for _ in range(int(rng.integers(45, 80))):  # pinpoint bleeding, aligned with the scratches
        j = int(rng.integers(len(ys)))
        r = rng.uniform(0.9, 2.2)
        g = np.clip(r + 0.5 - np.hypot((X - xs[j]) / rng.uniform(1.0, 2.2), Y - ys[j]), 0, 1)
        L = L * (1 - g) + 0.42 * g
        A = np.maximum(A, g)
    for _ in range(int(rng.integers(6, 14))):  # grit
        j = int(rng.integers(len(ys)))
        g = np.clip(rng.uniform(0.6, 1.2) + 0.5 - np.hypot(X - xs[j], Y - ys[j]), 0, 1)
        L = L * (1 - g) + 0.1 * g
        A = np.maximum(A, g)
    # skin tags heaped at the end of the slide: little light curls
    xe = float(np.max(np.nonzero((D < 0).any(axis=0))[0]))
    for _ in range(int(rng.integers(5, 10))):
        col_ = D[:, int(np.clip(xe - 12, 0, N - 1))]
        cand = np.nonzero(col_ < 0)[0]
        if len(cand) == 0:
            continue
        y = float(rng.choice(cand))
        x = xe - rng.uniform(2, 22)
        tag = np.clip(1 - np.hypot((X - x) / rng.uniform(3, 6), (Y - y) / rng.uniform(1.5, 3)), 0, 1)
        L = np.where(tag > 0.05, 1.0, L)
        A = np.maximum(A, smooth(0.0, 0.3, tag))
    return to_rgba(np.clip(L, 0, 1), np.clip(A, 0, 1))


def split_knuckle(seed=2800, N=256):
    """Knuckles split by punching: 3 short dark splits in a row along +X,
    each on a small raw pink scraped peak, a bead of blood oozing out of
    each split. Tinted RAW (light = raw skin, dark = blood)."""
    rng = v2_rng(seed)
    Y, X = rows_cols(N, N)
    L = np.full((N, N), 0.92, F32)
    A = np.zeros((N, N), F32)
    for i in range(3):
        x = N * (0.24 + 0.26 * i) + rng.normal(0, 4)
        y = N * 0.5 + 6 * (i - 1) ** 2 + rng.normal(0, 3)
        P = Shape(N, N, rng, warps=((6, 3.0), (2, 1.0)))
        P.add(ellipse(x, y, rng.uniform(22, 28), rng.uniform(14, 19), rng.normal(0, 0.2), random_harm(rng, [(3, 6, 0.1)])))
        raw = smooth(-0.6, 0.6, -P.D / 4 + 0.6 * noise(rng, (N, N), (1, 6)))  # scraped: ragged, scratched along X
        L = np.where(raw > 0.05, 0.92 - 0.12 * smooth(-1, 1, noise(rng, (N, N), (0.8, 7))), L)
        A = np.maximum(A, 0.75 * raw)
        S = Shape(N, N, rng, warps=((4, 0.8), (1.5, 0.3)))
        ang = rng.normal(0, 0.15)
        ln = rng.uniform(12, 18)
        S.add(ucap(x - np.cos(ang) * ln, y - np.sin(ang) * ln, 1.0, x, y, rng.uniform(2.4, 3.2)))
        S.add(ucap(x, y, 2.8, x + np.cos(ang) * ln, y + np.sin(ang) * ln, 1.0), 2)
        if rng.random() < 0.85:
            S.add(circle(x + rng.normal(0, 4), y + rng.uniform(4, 7), rng.uniform(3, 4.5)), 3)
        sl = S.alpha()
        L = np.where(sl > 0.02, L * (1 - sl) + 0.3 * sl, L)
        A = np.maximum(A, sl)
    return to_rgba(np.clip(L, 0, 1), np.clip(A, 0, 1))


def scalp_split(seed=2900, N=256):
    """Blunt laceration of the scalp / forehead (bat, kerb, head slammed on
    the ground): a Y / star-shaped split where the skin burst over the bone,
    ragged gaping lips, tissue bridges, a swollen raw rim and blood welling
    over its lowest arm. Same greys as browcut (tinted with blood colours)."""
    rng = v2_rng(seed)
    Y, X = rows_cols(N, N)
    c = N * 0.5
    S = Shape(N, N, rng, warps=((10, 2.5), (3, 1.0)))
    R = Shape(N, N, rng, warps=((10, 2.5), (3, 1.0)))
    arms = int(rng.integers(3, 5))
    base = rng.uniform(0, 2 * np.pi)
    low = (0.0, -1.0)
    for i in range(arms):
        a = base + 2 * np.pi * i / arms + rng.normal(0, 0.35)
        ln = N * rng.uniform(0.22, 0.34)
        mx, my = c + np.cos(a) * ln * 0.5 + rng.normal(0, 4), c + np.sin(a) * ln * 0.5 + rng.normal(0, 4)
        ex, ey = c + np.cos(a) * ln, c + np.sin(a) * ln
        S.add(ucap(c, c, 6.0, mx, my, 3.8), 4)  # the open gap, widest in the middle
        S.add(ucap(mx, my, 3.8, ex, ey, 0.8), 3)
        R.add(ucap(c, c, 13, mx, my, 10), 8)  # swollen split skin around it
        R.add(ucap(mx, my, 10, ex, ey, 4.5), 6)
        if ey > low[1]:
            low = (ex, ey)
    slit = S.alpha()
    rim = R.alpha() * (1 - slit)
    # ragged lips: the edge of the gap is torn, not cut
    rag = smooth(-0.3, 0.3, noise(rng, (N, N), 1.5) + 1.2 * (slit - 0.5))
    slit = np.maximum(slit * rag, smooth(0.6, 1.0, slit))
    br = np.zeros_like(slit)
    for _ in range(int(rng.integers(3, 6))):  # tissue bridges across the gap
        bx, by = c + rng.normal(0, N * 0.06), c + rng.normal(0, N * 0.06)
        a = rng.uniform(0, np.pi)
        along = (X - bx) * np.cos(a) + (Y - by) * np.sin(a)
        across = -(X - bx) * np.sin(a) + (Y - by) * np.cos(a)
        br = np.maximum(br, np.exp(-((along / 1.4) ** 2)) * (np.abs(across) < 9) * slit)
    W_ = Shape(N, N, rng, warps=((8, 1.5),))
    lx, ly = low
    W_.add(ellipse(lx, ly + 4, 10, 7, np.pi / 2))
    W_.add(ucap(lx, ly + 4, 6, lx + rng.normal(0, 3), min(N - 12, ly + N * 0.22), 4.5), 4)
    welled = W_.alpha()
    halo = bruise_halo(rng, (N, N), X, Y, c, c, N * 0.42, N * 0.42, mott=0.9)
    L = np.full((N, N), 0.68, F32)
    A = 0.2 * halo
    L = np.where(rim > 0.02, 0.88 - 0.08 * smooth(-1, 1, noise(rng, (N, N), 3)), L)
    A = np.maximum(A, rim * 0.8)
    wet = np.maximum(slit, welled)
    L = np.where(wet > 0.02, 0.28 + 0.2 * (1 - meniscus(depth_of(wet), 1.6)), L)
    A = np.maximum(A, wet)
    L = np.where(br > 0.3, 0.72, L)
    return to_rgba(np.clip(L, 0, 1), np.clip(A, 0, 1))


def flesh_tear(seed, N=512):
    """EXTREME (finishers): a torn-open wound seen from the front, what a rip
    or a burst leaves. THE ONLY PICTURE IN COLOUR (tint it white, Color3
    1,1,1): the layers of real tissue cannot come from one tint. From the
    outside in: bruised skin, the torn edge of the skin (pale pink dermis,
    ragged with flaps), the yellow lumpy fat just under it (the strongest
    'real' cue of a deep wound), red muscle with its fibres torn in one
    direction and a few white strands of fascia, a deep wet cavity with dark
    clots, and blood welling over the lowest lip."""
    rng = v2_rng(seed)
    Y, X = rows_cols(N, N)
    c = N * 0.5
    S = Shape(N, N, rng, warps=((40, 10.0), (12, 4.0), (4, 1.0)))
    S.add(ellipse(c, c, N * rng.uniform(0.25, 0.29), N * rng.uniform(0.17, 0.21), rng.normal(0, 0.3), random_harm(rng, [(3, 6, 0.1), (7, 11, 0.05)])))
    for _ in range(int(rng.integers(3, 6))):  # flaps of torn skin hanging into the hole
        a = rng.uniform(0, 2 * np.pi)
        r0 = N * 0.24
        S.add(ucap(c + np.cos(a) * r0 * 1.1, c + np.sin(a) * r0 * 0.8, 14, c + np.cos(a) * r0 * 0.6, c + np.sin(a) * r0 * 0.45, 3), 6, sub=True)
    hole = S.D + 2.5 * noise(rng, (N, N), 2)
    d_in = -hole
    th = np.arctan2(Y - c, X - c)
    # colours (sRGB 0..1)
    skin_edge = np.array([0.86, 0.62, 0.56])
    fat_c = np.array([0.84, 0.7, 0.46])
    musc = np.array([0.46, 0.07, 0.07])
    blood = np.array([0.2, 0.01, 0.01])
    rgb = np.zeros((N, N, 3), F32)
    A = np.zeros((N, N), F32)

    def over(rgb, A, top, a):  # paint a layer (straight colour, alpha a) on top
        out = a + A * (1 - a)
        mixed = (top * a[..., None] + rgb * (A * (1 - a))[..., None]) / np.maximum(out, 1e-4)[..., None]
        return mixed, out

    # bruised skin around it (a soft dark red-purple halo, low alpha)
    halo = bruise_halo(rng, (N, N), X, Y, c, c, N * 0.4, N * 0.34)
    rgb, A = over(rgb, A, np.array([0.42, 0.12, 0.16]), 0.4 * halo)
    # torn skin edge (outside the hole): a narrow raw band, wider where flaps lifted
    edge_w = 6 + 4 * smooth(-0.5, 1.5, noise(rng, (N, N), 8)) + 3 * np.cos(th * 5 + rng.uniform(0, 6)) ** 2
    rim = smooth(-1, 1, edge_w - hole) * smooth(-1, 1, hole)
    rgb, A = over(rgb, A, skin_edge * (0.9 + 0.1 * noise(rng, (N, N), 2))[..., None], rim)
    inside = smooth(-1, 1, d_in)
    # fat: lumpy yellow band just inside the edge
    lob = noise(rng, (N, N), 3.5)
    fat = (1 - smooth(5, 14, d_in + 5 * lob)) * inside
    stain = smooth(-0.3, 0.8, noise(rng, (N, N), 5))[..., None]  # fat smeared with blood in places
    fat_rgb = fat_c * (0.88 + 0.12 * smooth(-1, 1, lob))[..., None] - 0.2 * np.exp(-((lob / 0.25) ** 2))[..., None] * np.array([0.3, 0.3, 0.2])
    fat_rgb = fat_rgb * (1 - 0.6 * stain) + np.array([0.5, 0.08, 0.07]) * 0.6 * stain
    # muscle: fibres torn along one direction, darker with depth
    a = rng.uniform(0, np.pi)
    fibres = noise(rng, (N * 2, N * 2), (1.2, 10)) + 0.7 * noise(rng, (N * 2, N * 2), 4)
    fibres = ndi.rotate(fibres, np.degrees(a), reshape=False, order=1)[N // 2 : N // 2 + N, N // 2 : N // 2 + N]
    fibres = fibres / (fibres.std() + 1e-6)
    depth = smooth(15, N * 0.17, d_in)
    m_rgb = musc * (1 + 0.16 * fibres - 0.45 * depth)[..., None]
    fascia = smooth(1.9, 2.4, fibres + 0.8 * noise(rng, (N, N), 10)) * (1 - depth) * smooth(14, 22, d_in)
    m_rgb = m_rgb * (1 - fascia[..., None]) + fascia[..., None] * np.array([0.85, 0.8, 0.74])
    # a deep wet cavity with clots, and blood pooling in the lower part
    cav = smooth(0.45, 0.85, depth + 0.25 * noise(rng, (N, N), 12))
    low = smooth(-N * 0.05, N * 0.12, Y - c) * smooth(12, 30, d_in)
    wet = np.clip(np.maximum(cav, 0.8 * low * smooth(-0.5, 0.5, noise(rng, (N, N), 14) + 0.5)), 0, 1)
    clots = smooth(1.5, 2.0, noise(rng, (N, N), 6) + 1.2 * cav)
    b_rgb = blood * (1 - 0.5 * clots)[..., None] + 0.04 * noise(rng, (N, N), 3)[..., None] * blood
    tissue = m_rgb * (1 - wet[..., None]) + b_rgb * wet[..., None]
    tissue = tissue * (1 - fat[..., None]) + fat_rgb * fat[..., None]
    rgb, A = over(rgb, A, tissue, inside)
    # blood welling over the lowest lip and starting to run
    ys, xs = np.nonzero(inside > 0.5)
    j = int(np.argmax(ys))
    W_ = Shape(N, N, rng, warps=((10, 2.0),))
    W_.add(ellipse(xs[j], ys[j] - 14, 46, 18, 0, random_harm(rng, [(3, 6, 0.12), (7, 10, 0.05)])))
    rx = xs[j] + rng.uniform(-18, 18)
    W_.add(ucap(rx, ys[j] - 4, 9, rx + rng.normal(0, 5), min(N - 24, ys[j] + N * 0.15), 6), 12)
    wa = W_.alpha()
    film = 0.55 + 0.45 * meniscus(depth_of(wa), 3)
    rgb, A = over(rgb, A, np.array([0.5, 0.04, 0.04]) * (1 - 0.5 * film)[..., None], wa * (0.75 + 0.25 * film))
    # straight alpha, colour bled under the transparent pixels (no mip fringe)
    A8 = np.round(np.clip(A, 0, 1) * 255).astype(np.uint8)
    rgb = np.clip(rgb, 0, 1)
    out = (rgb * 255).round().astype(np.uint8)
    idx = ndi.distance_transform_edt(A8 == 0, return_distances=False, return_indices=True)
    out = out[idx[0], idx[1]]
    return np.dstack([out, A8])


JOBS_V2 = [
    # Tier 1
    *[(f"rivulet_strip_{i}", lambda i=i: rivulet_strip(1800 + i)) for i in (1, 2, 3)],
    *[(f"rivulet_bead_{i}", lambda i=i: rivulet_bead(1810 + i)) for i in (1, 2)],
    *[(f"rivulet_fork_{i}", lambda i=i: rivulet_fork(1820 + i)) for i in (1, 2)],
    *[(f"browcut_{i}", lambda i=i: browcut(1830 + i)) for i in (1, 2)],
    ("lipfilm_1", lambda: lipfilm(1841)),
    *[(f"crust_strip_{i}", lambda i=i: crust_strip(1850 + i)) for i in (1, 2)],
    *[(f"spit_{i}", lambda i=i: spit(1860 + i)) for i in (1, 2)],
    ("crown_4x4", crown_4x4),
    ("ripple_ring_1", ripple_ring),
    *[(f"starburst_{i}", lambda i=i: starburst(1870 + i)) for i in (1, 2)],
    *[(f"wick_halo_{i}", lambda i=i: wick_halo(1880 + i)) for i in (1, 2)],
    # Tier 2
    ("cheekcut_1", lambda: cheekcut(1891)),
    *[(f"wipe_smear_{i}", lambda i=i: wipe_smear(1900 + i)) for i in (1, 2)],
    *[(f"crust_patch_{i}", lambda i=i: crust_patch(1910 + i)) for i in (1, 2)],
    *[(f"abrasion_{i}", lambda i=i: abrasion(1920 + i)) for i in (1, 2)],
    ("split_knuckle_1", split_knuckle),
    ("wick_weave_1", wick_weave),
    *[(f"serum_halo_{i}", lambda i=i: serum_halo(i)) for i in (1, 2, 3)],
    *[(f"drag_{i}", lambda i=i: drag(1930 + i)) for i in (1, 2)],
    ("shoe_run_L_1", lambda: shoe_run(1941)),
    ("shoe_run_R_1", lambda: shoe_run(1942, mirror=True)),
    ("froth_4x4", froth_4x4),
    ("pendant_2x2", pendant_2x2),
    # Extreme wounds (bonus: no code uses them yet; see docs/BLOOD_FR.md)
    ("scalp_split_1", scalp_split),
    *[(f"flesh_tear_{i}", lambda i=i: flesh_tear(1950 + i)) for i in (1, 2)],
]


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


# v2 names must never collide with a v1 name (a v1 file is uploaded: changing
# it would mean re-uploading it) nor start like one (the name filter below).
V1_PREFIXES = ("spatter", "satellites", "drip", "pool", "run", "smear", "hand", "foot", "soak", "skin", "knuckles", "p_", "beam", "arterial")
assert not any(n.startswith(V1_PREFIXES) for n, _ in JOBS_V2), "a v2 name starts like a v1 name"


def main():
    os.makedirs(OUT, exist_ok=True)
    # Filters after the folder: name prefixes ("drip"), or "v1" / "v2" for a
    # whole set. Nothing = everything (the v1 files come out byte-identical).
    only = set(sys.argv[2:])
    jobs = [(n, j, "v1") for n, j in JOBS] + [(n, j, "v2") for n, j in JOBS_V2]
    for name, job, set_ in jobs:
        if only and set_ not in only and not any(name.startswith(o) for o in only):
            continue
        save(name, job())
        sz, w, h = SIZES[name]
        print(f"{name:18s} {w:4d}x{h:<4d} {sz / 1024:7.1f} KB")
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT) if f.endswith(".png") and not f.startswith("preview"))
    print(f"total (without preview.png): {total / 1024 / 1024:.2f} MB")


if __name__ == "__main__":
    main()
