# World rain pictures for Config.Weather.RAIN_IMAGES (Client/Controllers/RainController).
# Run from the repo root:  python3 tools/rain/make_rain_textures.py
# Then the preview:        python3 tools/rain/preview.py
#
# All pictures are white (or near white) with the shape in the alpha, so Roblox can tint them
# with ParticleEmitter.Color / Beam.Color and light them (LightInfluence) without dark fringes.
#
#   rain_drop.png    64 x 64    one falling drop. The game stretches it along its fall
#                               (Squash), like motion blur: a thin bright core (the specular
#                               glint of clear water) and soft darker edges (the refracting
#                               rim seen in the droplet reference, video 12).
#   rain_splash.png  512 x 512  4 x 4 flipbook (16 frames): the small crown a drop throws up
#                               when it hits the ground: a thin sheet, then 5-8 droplets on
#                               ballistic arcs that fall back. Ground line at 85 % of a frame.
#   rain_ripple.png  1024x1024  4 x 4 flipbook: the ring a drop makes on a puddle, seen from
#                               above (video 13): a thin ring growing from the impact, damped,
#                               a weaker second ring a little later, a faint dark band inside
#                               the bright crest, never a perfect circle.
#   rain_sheet.png   1024 x 256 a sheet of far rain for the distant curtains (Beams). Streaks
#                               run along X (a Beam lays its texture along its length), tiles
#                               along X, fades out at the top and bottom edges.
import numpy as np
from PIL import Image

OUT = "assets/rain/"
rng = np.random.default_rng(13)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def save(rgb, alpha, name):
    a = np.clip(alpha, 0, 1)
    img = np.dstack([np.clip(rgb, 0, 1), a]) if rgb.ndim == 3 else None
    if img is None:
        img = np.dstack([rgb, rgb, rgb, a])
    Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT + name)
    print("wrote", OUT + name)


def disc(h, w, cx, cy, r, soft=1.0):
    y, x = np.mgrid[0:h, 0:w]
    d = np.hypot(x + 0.5 - cx, y + 0.5 - cy)
    return 1 - smooth(r - soft, r + soft, d)


# ---------------------------------------------------------------------------- the drop
def make_drop():
    n = 64
    y, x = np.mgrid[0:n, 0:n]
    d = np.hypot(x + 0.5 - n / 2, y + 0.5 - n / 2) / (n / 2)
    core = np.exp(-0.5 * (d / 0.16) ** 2)  # the bright glint
    body = 1 - smooth(0.55, 0.95, d)  # the clear body
    alpha = np.clip(core * 0.95 + body * 0.35, 0, 1)
    # the rim refracts the dark street: darker towards the edge, white in the core
    rgb = 0.55 + 0.45 * np.clip(core * 1.6, 0, 1)
    save(rgb, alpha, "rain_drop.png")


# ---------------------------------------------------------------------------- the splash
def make_splash():
    cell, grid = 128, 4
    sheet_rgb = np.ones((cell * grid, cell * grid))
    sheet_a = np.zeros((cell * grid, cell * grid))
    ground = cell * 0.85
    srng = np.random.default_rng(5)
    count = 7
    angles = np.linspace(-1.25, 1.25, count) + srng.normal(0, 0.08, count)
    speeds = srng.uniform(0.6, 1.15, count)
    sizes = srng.uniform(2.0, 3.6, count)
    for f in range(grid * grid):
        t = f / (grid * grid - 1)
        a = np.zeros((cell, cell))
        rgb = np.ones((cell, cell))
        yy, xx = np.mgrid[0:cell, 0:cell]
        # the crown: two thin walls of water flaring out of the impact (a cup seen side on),
        # rising fast and breaking up early
        crown = smooth(0.0, 0.06, t) * (1 - smooth(0.2, 0.45, t))
        if crown > 0.01:
            hgt = 34 * min(1, t / 0.22)
            up = np.clip((ground - yy) / max(hgt, 1), 0, 1)
            inside = (yy <= ground) & (yy >= ground - hgt)
            for side in (-1, 1):
                wall_x = cell / 2 + side * (5 + (10 + 26 * t) * up)
                wall = np.exp(-0.5 * ((xx - wall_x) / (1.1 + 0.6 * up)) ** 2)
                a = np.maximum(a, wall * inside * (0.35 + 0.55 * up) * crown)
            # the thin skin between the walls
            skin = inside * (np.abs(xx - cell / 2) < 5 + (10 + 26 * t) * up) * 0.06 * crown
            a = np.maximum(a, skin)
        # the droplets: thrown off the crown rim, they arc out and fall back by the end
        for i in range(count):
            vx = np.sin(angles[i]) * 46 * speeds[i]
            vy = np.cos(angles[i]) * 120 * speeds[i]
            g = 2 * vy / 0.95  # back on the ground at about t = 0.95
            start_x = cell / 2 + np.sign(angles[i]) * (8 + 6 * abs(angles[i]))
            px = start_x + vx * t
            py = ground - 26 * min(1, t / 0.2) * (1 - smooth(0.2, 0.6, t)) - (vy * t - 0.5 * g * t * t)
            if t < 0.12 or py > ground - 1 or px < 4 or px > cell - 4:
                continue
            life = 1 - smooth(0.8, 1.0, t)
            r = sizes[i] * 1.3 * (1 - 0.3 * t)
            dvx, dvy = vx, -(vy - g * t)
            # a short stretch along the motion (motion blur)
            for k in range(4):
                s = k / 3
                b = disc(cell, cell, px - dvx * 0.02 * s, py - dvy * 0.02 * s, r * (1 - 0.3 * s))
                a = np.maximum(a, b * (0.9 - 0.45 * s) * life)
            glint = disc(cell, cell, px - r * 0.3, py - r * 0.3, max(0.8, r * 0.35), 0.7)
            a = np.maximum(a, glint * life)
            rgb = np.minimum(rgb, 1 - 0.3 * disc(cell, cell, px + r * 0.3, py + r * 0.3, r * 0.6))
        gy, gx = divmod(f, grid)
        sheet_a[gy * cell:(gy + 1) * cell, gx * cell:(gx + 1) * cell] = a
        sheet_rgb[gy * cell:(gy + 1) * cell, gx * cell:(gx + 1) * cell] = rgb
    save(sheet_rgb, sheet_a, "rain_splash.png")


# ---------------------------------------------------------------------------- the ripple
def make_ripple():
    cell, grid = 256, 4
    sheet_rgb = np.ones((cell * grid, cell * grid))
    sheet_a = np.zeros((cell * grid, cell * grid))
    y, x = np.mgrid[0:cell, 0:cell]
    cx = cy = cell / 2
    ang = np.arctan2(y + 0.5 - cy, x + 0.5 - cx)
    dist = np.hypot(x + 0.5 - cx, y + 0.5 - cy)
    # the ring is never a perfect circle: a slow wobble of 1-2 % of the radius
    wobble = 1 + 0.012 * np.sin(3 * ang + 0.7) + 0.008 * np.sin(5 * ang + 2.1) + 0.006 * np.sin(9 * ang)
    rmax = cell / 2 - 6
    for f in range(grid * grid):
        t = (f + 0.5) / (grid * grid)
        a = np.zeros((cell, cell))
        rgb = np.ones((cell, cell))
        for start, strength in ((0.0, 1.0), (0.25, 0.45)):
            tt = (t - start) / (1 - start)
            if tt <= 0:
                continue
            # fast at first, slowing down (a damped wave)
            r = rmax * (0.05 + 0.9 * (1 - (1 - tt) ** 1.6))
            width = 1.6 + 2.2 * tt
            d = dist / wobble
            crest = np.exp(-0.5 * ((d - r) / width) ** 2)
            trough = np.exp(-0.5 * ((d - (r - width * 2.6)) / (width * 1.2)) ** 2)
            fade = (1 - tt) ** 1.5 * strength
            a = np.maximum(a, crest * 0.9 * fade)
            # the darker band inside the crest (the slope refracting the dark ground)
            a = np.maximum(a, trough * 0.35 * fade)
            rgb = np.where(trough * fade > crest * fade, 0.25, rgb)
        # the impact itself on the first frames: a small bright dimple
        if t < 0.15:
            a = np.maximum(a, np.exp(-0.5 * (dist / 4) ** 2) * (1 - t / 0.15))
        gy, gx = divmod(f, grid)
        sheet_a[gy * cell:(gy + 1) * cell, gx * cell:(gx + 1) * cell] = a
        sheet_rgb[gy * cell:(gy + 1) * cell, gx * cell:(gx + 1) * cell] = rgb
    save(sheet_rgb, sheet_a, "rain_ripple.png")


# ---------------------------------------------------------------------------- the far sheet
def make_sheet():
    w, h = 1024, 256
    a = np.zeros((h, w))
    xs = np.arange(w)
    for _ in range(420):
        row = rng.uniform(4, h - 4)
        length = rng.uniform(40, 160)
        start = rng.uniform(0, w)
        thick = rng.uniform(0.5, 1.2)
        strength = rng.uniform(0.15, 0.55)
        # wrapped distance along X: the sheet tiles along the beam
        along = (xs - start) % w
        prof = smooth(0, length * 0.3, along) * (1 - smooth(length * 0.6, length, along))
        y0, y1 = int(max(0, row - 4)), int(min(h, row + 5))
        rows = np.arange(y0, y1)[:, None]
        across = np.exp(-0.5 * ((rows + 0.5 - row) / thick) ** 2)
        a[y0:y1] = np.maximum(a[y0:y1], across * prof[None, :] * strength)
    edge = smooth(0, 40, np.arange(h)) * smooth(0, 40, h - np.arange(h))
    a *= edge[:, None]
    save(np.ones((h, w)), a, "rain_sheet.png")


if __name__ == "__main__":
    import os

    os.makedirs(OUT, exist_ok=True)
    make_drop()
    make_splash()
    make_ripple()
    make_sheet()
