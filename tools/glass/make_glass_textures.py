# Window glass pictures for Config.Glass (Client/Controllers/GlassController).
# Run from the repo root:  python3 -I tools/glass/make_glass_textures.py
# Needs numpy + pillow only. Writes assets/glass/*.png and assets/glass/preview.png.
#
# What the reference videos taught (docs/references/video12.md, video14.md):
#   - glass reads as glass because of its EDGES (a darker band where the thick rim refracts
#     the dark world) and one sharp highlight; the face itself is clear.
#   - a water bead on glass is a tiny lens: clear body, a dark refracting rim, one sharp
#     white highlight up-left (towards the light) and a softer glint inside the bottom-right
#     rim. Beads are scattered without clumps (Poisson disk), in 3 sizes, sparse rather
#     than dense (the dense pass of video 12 looked like a rash).
# Roblox has no refraction, so all of this is baked into straight-alpha RGBA pictures that
# lie ON the pane (Decal / Texture). They stay neutral (no tint), as in the glass video.
import os
import sys

import numpy as np
from PIL import Image

OUT = "assets/glass/"
rng = np.random.default_rng(1337)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def periodic_blur(a, sigma):
    # Gaussian blur that wraps around (keeps a tileable picture tileable).
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def tile_noise(shape, sigma):
    n = periodic_blur(rng.standard_normal(shape), sigma)
    n -= n.min()
    return n / max(n.max(), 1e-9)


def fbm(shape, base_sigma, octaves=4):
    out = np.zeros(shape)
    amp, total = 1.0, 0.0
    sigma = base_sigma
    for _ in range(octaves):
        out += tile_noise(shape, sigma) * amp
        total += amp
        amp *= 0.5
        sigma *= 0.5
    return out / total


class Layer:
    # Straight-alpha painting: each stroke is (colour, alpha) composited "over".
    def __init__(self, h, w):
        self.rgb = np.zeros((h, w, 3))
        self.a = np.zeros((h, w))

    def over(self, alpha, color):
        alpha = np.clip(alpha, 0, 1)
        color = np.asarray(color, dtype=float) / 255.0
        out_a = alpha + self.a * (1 - alpha)
        safe = np.where(out_a > 1e-6, out_a, 1)
        if color.ndim == 1:
            color = color[None, None, :]
        self.rgb = (color * alpha[..., None] + self.rgb * (self.a * (1 - alpha))[..., None]) / safe[
            ..., None
        ]
        self.a = out_a

    def over_region(self, ys, xs, alpha, color):
        # The same, on a window of the picture only (beads are small).
        sub = Layer(1, 1)
        sub.rgb, sub.a = self.rgb[ys, xs], self.a[ys, xs]
        sub.over(alpha, color)
        self.rgb[ys, xs], self.a[ys, xs] = sub.rgb, sub.a

    def image(self, size=None):
        rgb = np.clip(self.rgb, 0, 1)
        # Where alpha is 0 the colour still matters (bilinear filtering bleeds it):
        # fill it with the average visible colour so no dark or white fringes appear.
        visible = self.a > 0.02
        if visible.any():
            mean = (rgb[visible] * self.a[visible][:, None]).sum(0) / self.a[visible].sum()
            rgb = np.where((self.a > 0.004)[..., None], rgb, mean[None, None, :])
        data = np.dstack([rgb, np.clip(self.a, 0, 1)])
        img = Image.fromarray((data * 255 + 0.5).astype(np.uint8), "RGBA")
        if size:
            img = img.resize(size, Image.LANCZOS)
        return img


# ------------------------------------------------------------------------------------------
# 1) Dirt + edges on a dry pane (a Decal stretched over the whole face)
# ------------------------------------------------------------------------------------------


def dirt(w, h, seed):
    global rng
    rng = np.random.default_rng(seed)
    S = 2
    W, H = w * S, h * S
    L = Layer(H, W)
    y = np.linspace(0, 1, H)[:, None] * np.ones((1, W))
    x = np.ones((H, 1)) * np.linspace(0, 1, W)[None, :]

    # Film of dust: low-frequency smudges, heavier towards the bottom (rain splash and
    # dust settle there), very faint in the middle.
    film = fbm((H, W), 40 * S, 5)
    bottom = smooth(0.35, 1.0, y) ** 1.6
    a = smooth(0.42, 0.85, film) * (0.05 + 0.20 * bottom)
    L.over(a, (150, 146, 136))

    # Dried water marks: a few faint, broken rings of mineral left by old drops (sparse:
    # many of them look like bubbles).
    for _ in range(int(w * h / 5000)):
        cx, cy = rng.random() * W, (0.3 + 0.7 * rng.random() ** 0.7) * H
        r = rng.uniform(2, 6) * S
        x0, x1 = int(max(0, cx - r * 1.5)), int(min(W, cx + r * 1.5 + 1))
        y0, y1 = int(max(0, cy - r * 1.5)), int(min(H, cy + r * 1.5 + 1))
        if x0 >= x1 or y0 >= y1:
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(float)
        d = np.hypot(xx - cx, (yy - cy) * 1.15) / r
        # only part of the ring (the side the water dried last)
        ang = np.arctan2(yy - cy, xx - cx)
        part = smooth(-0.2, 0.6, np.cos(ang - rng.uniform(0, 2 * np.pi)))
        ring = np.exp(-((d - 1) ** 2) / 0.03) * 0.06 * part
        L.over_region(slice(y0, y1), slice(x0, x1), ring, (175, 172, 162))

    # A few greasy wipes (a sleeve, a hand) and one or two fingerprint-like ovals.
    for _ in range(3):
        cx, cy = rng.uniform(0.15, 0.85) * W, rng.uniform(0.35, 0.8) * H
        ang = rng.uniform(-0.6, 0.6)
        rx, ry = rng.uniform(0.08, 0.2) * W, rng.uniform(0.015, 0.04) * H
        dx, dy = x * W - cx, y * H - cy
        u = (dx * np.cos(ang) + dy * np.sin(ang)) / rx
        v = (-dx * np.sin(ang) + dy * np.cos(ang)) / ry
        L.over(np.exp(-(u * u + v * v) * 1.5) * 0.07 * film * 2, (160, 158, 150))

    # Fine scratches: thin straight lines, barely there.
    for _ in range(int(2 + w * h / 160000)):
        x0, y0 = rng.random() * W, rng.random() * H
        ang = rng.uniform(-0.5, 0.5) + (np.pi / 2 if rng.random() < 0.3 else 0)
        length = rng.uniform(0.04, 0.18) * W
        dx, dy = x * W - x0, y * H - y0
        along = dx * np.cos(ang) + dy * np.sin(ang)
        across = -dx * np.sin(ang) + dy * np.cos(ang)
        line = np.exp(-(across**2) / (0.6 * S) ** 2) * (np.abs(along - length / 2) < length / 2)
        L.over(line * 0.1, (210, 210, 205))

    # The EDGE of the pane: a thin dark green-grey band (thick glass refracting the dark
    # frame) with a hair-thin bright line just inside it (light caught by the rim).
    edge = np.minimum(np.minimum(x * W, (1 - x) * W), np.minimum(y * H, (1 - y) * H))
    band = 0.012 * min(W, H) * 1.0 + 3 * S
    L.over((1 - smooth(band * 0.55, band, edge)) * 0.55, (34, 44, 42))
    line = np.exp(-((edge - band * 1.05) ** 2) / (0.9 * S) ** 2) * 0.22
    L.over(line, (225, 232, 230))

    # A soft sheen top-left: the sky light caught by the face (gives the eye a highlight to
    # focus on even when the engine draws none, e.g. low graphics quality).
    sheen = np.exp(-(((x - 0.18) / 0.22) ** 2 + ((y - 0.16) / 0.12) ** 2)) * 0.10
    diag = np.exp(-(((x - y * 0.6) - 0.25) / 0.05) ** 2) * 0.06 * (1 - y)
    L.over(sheen + diag, (240, 244, 246))
    return L.image((w, h))


# ------------------------------------------------------------------------------------------
# 2) Rain beads (a tiling Texture; fades in while the pane gets wet)
# ------------------------------------------------------------------------------------------


def poisson(n_try, size, radii_fn, min_gap):
    # Dart throwing with wrap-around distance (so the picture tiles).
    pts = []
    for _ in range(n_try):
        p = rng.random(2) * size
        r = radii_fn()
        ok = True
        for q, rq in pts:
            d = np.abs(p - q)
            d = np.minimum(d, size - d)
            if np.hypot(*d) < r + rq + min_gap:
                ok = False
                break
        if ok:
            pts.append((p, r))
    return pts


def bead(L, cx, cy, r, stretch=1.0, strength=1.0):
    # One water bead, drawn at every wrapped copy that touches the picture (so it tiles).
    H, W = L.a.shape
    for ox in (-W, 0, W):
        for oy in (-H, 0, H):
            px, py = cx + ox, cy + oy
            x0, x1 = int(max(0, px - r * 1.2)), int(min(W, px + r * 1.2 + 1))
            y0, y1 = int(max(0, py - r * stretch * 1.2)), int(min(H, py + r * stretch * 1.4 + 1))
            if x0 >= x1 or y0 >= y1:
                continue
            Y, X = np.mgrid[y0:y1, x0:x1].astype(float)
            ys, xs = slice(y0, y1), slice(x0, x1)
            dx = (X - px) / r
            # gravity: a little longer and fatter at the bottom
            dy = (Y - py) / (r * stretch)
            dy = np.where(dy > 0, dy * 0.85, dy)
            d = np.hypot(dx, dy)
            inside = 1 - smooth(0.92, 1.04, d)
            # clear body (shows a darker, upside-down picture of the world)
            L.over_region(ys, xs, inside * 0.16 * strength, (58, 66, 70))
            # dark refracting rim, thicker at the bottom
            rim = smooth(0.6, 0.97, d) * inside * (0.55 + 0.25 * np.clip(dy, 0, 1))
            L.over_region(ys, xs, rim * 0.62 * strength, (16, 20, 22))
            # bright caustic glint inside the bottom-right rim
            ang = np.arctan2(dy, dx)
            crescent = (
                np.exp(-((d - 0.7) ** 2) / 0.012) * np.exp(-((ang - 0.9) ** 2) / 0.35) * inside
            )
            L.over_region(ys, xs, crescent * 0.5 * strength, (226, 236, 240))
            # sharp specular highlight up-left (the light is above)
            hx, hy = dx + 0.36, dy + 0.42
            spec = 1 - smooth(0.12, 0.24, np.hypot(hx, hy * 1.2))
            L.over_region(ys, xs, spec * 0.95 * strength, (255, 255, 255))


def rain_beads(size=512):
    S = 2
    N = size * S
    L = Layer(N, N)

    def radius():
        u = rng.random()
        if u < 0.05:
            return rng.uniform(8, 11) * S  # big
        if u < 0.30:
            return rng.uniform(3.5, 6.5) * S  # medium
        return rng.uniform(1.0, 2.4) * S  # dew

    beads = poisson(2600, N, radius, 3 * S)
    for p, r in beads:
        bead(L, p[0], p[1], r, stretch=1.0 + 0.25 * (r > 6 * S))
    return L.image((size, size)), len(beads)


# ------------------------------------------------------------------------------------------
# 3) Running water (a Texture tiling vertically, scrolled down while it rains)
# ------------------------------------------------------------------------------------------


def rain_runs(w=256, h=1024):
    S = 2
    W, H = w * S, h * S
    L = Layer(H, W)
    Y, X = np.mgrid[0:H, 0:W].astype(float)
    runs = 4
    for k in range(runs):
        x0 = (k + rng.uniform(0.2, 0.8)) / runs * W
        width = rng.uniform(1.2, 2.6) * S
        # a meandering path (periodic in y so the picture tiles)
        phase = rng.uniform(0, 2 * np.pi, 3)
        amp = rng.uniform(3, 10, 3) * S
        t = Y / H * 2 * np.pi
        path = x0 + sum(amp[i] * np.sin(t * (i + 1) + phase[i]) for i in range(3))
        dxp = X - path
        dxp = (dxp + W / 2) % W - W / 2
        # the wet trail: slightly darker, its edges catch a thin line of light;
        # it thins and breaks up here and there
        breaks = smooth(0.4, 0.62, tile_noise((H, 1), 30 * S)[:, 0])[:, None]
        trail = np.exp(-(dxp**2) / (width**2)) * breaks
        L.over(trail * 0.26, (40, 48, 52))
        edge = np.exp(-((np.abs(dxp) - width) ** 2) / (0.5 * S) ** 2) * breaks
        L.over(edge * 0.16, (220, 228, 232))
        # beads hanging on the trail and the running drop at its head
        heads = rng.integers(2, 4)
        for j in range(heads):
            hy = (j + rng.uniform(0.1, 0.9)) / heads * H
            hx = x0 + sum(amp[i] * np.sin(hy / H * 2 * np.pi * (i + 1) + phase[i]) for i in range(3))
            r = rng.uniform(3.5, 6.0) * S
            bead(L, hx, hy, r, stretch=1.5)
            for _ in range(rng.integers(2, 6)):
                by = (hy - rng.uniform(15, 140) * S) % H
                bx = x0 + sum(
                    amp[i] * np.sin(by / H * 2 * np.pi * (i + 1) + phase[i]) for i in range(3)
                )
                bead(L, bx + rng.uniform(-1, 1) * S, by, rng.uniform(1.2, 2.6) * S)
    return L.image((w, h))


# ------------------------------------------------------------------------------------------
# Preview: the pictures over a dark night window and over a lit shop interior
# ------------------------------------------------------------------------------------------


def backdrop(w, h, lit):
    y = np.linspace(0, 1, h)[:, None]
    x = np.linspace(0, 1, w)[None, :]
    if lit:
        base = np.dstack(
            [0.55 - 0.3 * y + 0 * x, 0.42 - 0.25 * y + 0 * x, 0.28 - 0.18 * y + 0 * x]
        )
        # a few dark shapes (shelves, a mannequin) behind the glass
        base[int(h * 0.3) : int(h * 0.9), int(w * 0.6) : int(w * 0.68)] *= 0.35
        base[int(h * 0.55) : int(h * 0.58), :] *= 0.5
    else:
        base = np.dstack([0.06 + 0.05 * (1 - y) + 0 * x, 0.075 + 0.05 * (1 - y) + 0 * x, 0.09 + 0.06 * (1 - y) + 0 * x])
        # reflection of a street lamp in the dark mirror of the glass
        base += np.exp(-(((x - 0.72) / 0.05) ** 2 + ((y - 0.3) / 0.08) ** 2))[..., None] * np.array(
            [0.7, 0.45, 0.2]
        )
    return np.clip(base, 0, 1)


def composite(base, img, transparency=0.0):
    a = np.asarray(img).astype(float) / 255
    alpha = a[..., 3:4] * (1 - transparency)
    return base * (1 - alpha) + a[..., :3] * alpha


def tile(img, w, h, sx, sy=None):
    sy = sx if sy is None else sy
    t = img.resize((int(img.width * sx), int(img.height * sy)), Image.LANCZOS)
    out = Image.new("RGBA", (w, h))
    for yy in range(0, h, t.height):
        for xx in range(0, w, t.width):
            out.paste(t, (xx, yy))
    return out


# The preview shows a 12-stud shop pane at 64 px per stud, the tiles at their game size
# (Config.Glass.BEADS_TILE = 3, RUNS_TILE = 4 x 14).
BEADS_SCALE = 3 * 64 / 512
RUNS_SCALE_V = 14 * 64 / 1024


def preview(dirt_wide, dirt_tall, beads, runs):
    panels = []
    for lit in (False, True):
        for wet in (0, 1):
            w, h = 768, 384
            base = backdrop(w, h, lit)
            img = composite(base, dirt_wide.resize((w, h), Image.LANCZOS))
            if wet:
                img = composite(img, tile(beads, w, h, BEADS_SCALE), 0.1)
                img = composite(img, tile(runs, w, h, 1.0, RUNS_SCALE_V), 0.25)
            panels.append(img)
    w, h = 300, 440
    tall = composite(backdrop(w, h, False), dirt_tall.resize((w, h), Image.LANCZOS))
    tall_wet = composite(tall, tile(beads, w, h, BEADS_SCALE), 0.1)
    tall_wet = composite(tall_wet, tile(runs, w, h, 1.0, RUNS_SCALE_V), 0.25)
    sheet = np.ones((384 * 2 + 30 + 440 + 10, 768 * 2 + 30, 3)) * 0.5
    for i, p in enumerate(panels):
        r, c = divmod(i, 2)
        sheet[10 + r * 389 : 10 + r * 389 + 384, 10 + c * 778 : 10 + c * 778 + 768] = p
    top = 10 + 2 * 389
    sheet[top : top + 440, 10 : 10 + 300] = tall
    sheet[top : top + 440, 320 : 320 + 300] = tall_wet
    # close-up of the beads at 4x over a dark window
    crop = beads.crop((0, 0, 200, 110)).resize((800, 440), Image.LANCZOS)
    sheet[top : top + 440, 640 : 640 + 800] = composite(backdrop(800, 440, False), crop)
    Image.fromarray((np.clip(sheet, 0, 1) * 255).astype(np.uint8)).save(OUT + "preview.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    dirt_wide = dirt(1024, 512, 11)
    dirt_wide.save(OUT + "glass_dirt_wide.png")
    dirt_tall = dirt(512, 768, 23)
    dirt_tall.save(OUT + "glass_dirt_tall.png")
    beads, count = rain_beads(512)
    beads.save(OUT + "glass_rain_beads.png")
    runs = rain_runs(256, 1024)
    runs.save(OUT + "glass_rain_runs.png")
    preview(dirt_wide, dirt_tall, beads, runs)
    print(f"ok: {count} beads; files in {OUT}", file=sys.stderr)


if __name__ == "__main__":
    main()
