# Fire textures for the Pyromaniac and every burning body
# (src/client/Combat/FireLook.luau, ids in Config.Injuries.FIRE).
# Made here from noise, no photo. Colours are baked in (a white-yellow core,
# orange body, deep red edges, dark soot): the game's Color only warms and
# darkens them over a particle's life.
#
#   flame_loop.png    1024, 8 x 8 LOOP (64 frames, 128 px): a cluster of
#                     3-5 licking tongues that merge into one burning body.
#                     3D noise periodic in time, scrolled up exactly one or
#                     more frame heights per loop: it loops with no seam.
#   flame_tongue.png  1024, 4 x 4 ONE-SHOT (16 frames, 256 px): one tongue
#                     licks up, stretches, tears off at the root, breaks
#                     into wisps and dies.
#   fireball.png      1024, 8 x 8 ONE-SHOT (64 frames, 128 px): a petrol
#                     fireball, full size on frame 0 (pop), white-yellow
#                     core, orange billows rolling up, darkening to soot,
#                     then eroding smoke.
#   ground_fire.png   1024, 4 x 4 LOOP (16 frames, 256 px): a burning film
#                     seen from above: ragged hot patches, flickering
#                     fingers, an irregular outline (never a circle).
#   smoke.png         512, 2 x 2 (4 different puffs: a random one per
#                     particle), grey, lit from above (tinted in game).
#   ember.png         256, 2 x 2: a dot, a streak, a curled flake, a
#                     double spark.
#   glow.png          256: a soft hot glow (the core hugging the fuel).
#   flame_strip.png   512 x 128, tiles along X: a flowing flame band for
#                     Beams (the breath's jet) and Trails (a Molotov).
#   scorch.png        1024: the black mark a fire leaves, with a broken
#                     edge, splash fingers and droplets (+Y = the throw).
#
# Run from the repo root (numpy, scipy, pillow):
#   venv/bin/python -I tools/pyro/make_fire.py [out_dir]
# then LOOK at the previews (venv/bin/python -I tools/pyro/preview_fire.py).
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/fire"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def band(rng, shape, cycles, width=0.55):
    """Periodic noise (every axis) whose features are about `cycles[i]`
    per extent along axis i (a soft band around that frequency)."""
    white = rng.standard_normal(shape).astype(np.float32)
    spectrum = np.fft.fftn(white)
    q2 = 0.0
    for axis, (n, c) in enumerate(zip(shape, cycles)):
        k = np.fft.fftfreq(n) * n / max(c, 1e-6)
        sh = [1] * len(shape)
        sh[axis] = n
        q2 = q2 + k.reshape(sh) ** 2
    q = np.sqrt(q2)
    amp = np.exp(-(((q - 1) / width) ** 2))
    amp.flat[0] = 0
    field = np.real(np.fft.ifftn(spectrum * amp)).astype(np.float32)
    return field / (field.std() + 1e-9)


def fbm(rng, shape, cycles, octaves=3, gain=0.5):
    total = np.zeros(shape, np.float32)
    weight = 1.0
    for o in range(octaves):
        total += weight * band(rng, shape, [c * 2**o for c in cycles])
        weight *= gain
    return total / (total.std() + 1e-9)


def rgb(*c):
    return np.array(c, np.float32) / 255


# Fire colour by temperature (0 = the coolest visible edge, 1 = the core).
FIRE_STOPS = [
    (0.00, rgb(90, 14, 4)),
    (0.18, rgb(176, 38, 8)),
    (0.36, rgb(236, 92, 16)),
    (0.55, rgb(255, 152, 40)),
    (0.75, rgb(255, 208, 96)),
    (0.92, rgb(255, 240, 190)),
    (1.00, rgb(255, 252, 236)),
]


def palette(t, stops=FIRE_STOPS):
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,), np.float32)
    for (t0, c0), (t1, c1) in zip(stops[:-1], stops[1:]):
        m = (t >= t0) & (t <= t1)
        u = ((t - t0) / (t1 - t0))[m][:, None]
        out[m] = c0 * (1 - u) + c1 * u
    return out


def down(img, factor):
    """Box downsample (anti-aliased edges)."""
    if factor == 1:
        return img
    h, w = img.shape[:2]
    return img.reshape(h // factor, factor, w // factor, factor, *img.shape[2:]).mean(axis=(1, 3))


def border(n, pad):
    """1 inside, 0 within `pad` px of the edge (soft): no bleeding between frames."""
    a = np.ones((n, n), np.float32)
    a[:pad, :] = a[-pad:, :] = a[:, :pad] = a[:, -pad:] = 0
    return ndimage.gaussian_filter(a, pad / 2.5)


def premultiplied_fix(color, alpha):
    """Fill the colour of transparent pixels from their neighbours (no dark
    fringe when the GPU filters / mips the sheet)."""
    a = alpha[..., None]
    blurred = ndimage.gaussian_filter(color * a, (6, 6, 0))
    weight = ndimage.gaussian_filter(alpha, 6)[..., None]
    fill = blurred / np.maximum(weight, 1e-4)
    t = smooth(0.0, 0.25, alpha)[..., None]
    return color * t + fill * (1 - t)


def save(name, color, alpha):
    os.makedirs(OUT, exist_ok=True)
    color = premultiplied_fix(np.clip(color, 0, 1).astype(np.float32), np.clip(alpha, 0, 1))
    img = np.concatenate([np.clip(color, 0, 1), np.clip(alpha, 0, 1)[..., None]], -1)
    path = os.path.join(OUT, name)
    Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA").save(path, optimize=True)
    print("wrote", path, img.shape[1], "x", img.shape[0])


def grid_sheet(frames, grid):
    n = frames[0][0].shape[0]
    color = np.zeros((n * grid, n * grid, 3), np.float32)
    alpha = np.zeros((n * grid, n * grid), np.float32)
    for i, (c, a) in enumerate(frames):
        r, k = divmod(i, grid)
        color[r * n : (r + 1) * n, k * n : (k + 1) * n] = c
        alpha[r * n : (r + 1) * n, k * n : (k + 1) * n] = a
    return color, alpha


def coords(s):
    """u in [-1, 1] left to right, v in [0, 1] bottom to top (pixel centres)."""
    r, c = np.mgrid[0:s, 0:s].astype(np.float32)
    u = (c + 0.5) / s * 2 - 1
    v = 1 - (r + 0.5) / s
    return u, v


def scrolled(field, t, frames, periods):
    """Frame t of a (T, S, S) field scrolled UP `periods` heights per loop
    (an integer: the loop has no seam)."""
    s = field.shape[1]
    shift = int(round(periods * s * t / frames))
    return np.roll(field[t], -shift, axis=0)


# ---------------------------------------------------------------------------
# Flames
# ---------------------------------------------------------------------------


def flame_loop(seed, frames=64, out=128, ss=2):
    """A burning body: 3-5 tongues from one wide hot root. Loops."""
    rng = np.random.default_rng(seed)
    s = out * ss
    shape = (frames, s, s)
    big = fbm(rng, shape, (2, 1.6, 2.6), octaves=2)
    fine = fbm(rng, shape, (4, 4.5, 6), octaves=2)
    sway = fbm(rng, shape, (2, 1, 1.5), octaves=1)
    u, v = coords(s)
    vv = np.clip((v - 0.05) / 0.86, -0.2, 1.3)  # 0 at the root, 1 near the top
    pad = border(s, 8 * ss)
    result = []
    for t in range(frames):
        b = scrolled(big, t, frames, 2)
        f = scrolled(fine, t, frames, 3)
        w = scrolled(sway, t, frames, 1)
        h = np.clip(vv, 0, 1)
        uw = u + (0.04 + 0.22 * h**1.3) * w
        width = 0.56 * (1 - 0.42 * h) * (0.72 + 0.28 * smooth(-0.02, 0.18, vv))
        profile = np.clip(1 - (uw / width) ** 2, 0, 1)
        wide = np.clip(1 - (uw / (width * 1.3)) ** 2, 0, 1)
        heat = profile**0.8 * np.clip(1 - h, 0, 1) ** 1.1 * 0.95 * (0.8 + 0.2 * smooth(0, 0.15, vv))
        turb = 0.62 * b + 0.38 * f
        temp = heat + (0.12 + 0.75 * h) * turb * 0.4 * wide
        temp -= 0.06 * smooth(0.6, 1.1, vv)  # the top always thins out
        root = smooth(-0.06, 0.16, vv)
        alpha = smooth(0.05, 0.42, temp) ** 1.3 * root * pad
        color = palette((temp - 0.08) * 1.05)
        result.append((down(color, ss), down(alpha, ss)))
    return grid_sheet(result, 8)


def flame_tongue(seed, frames=16, out=256, ss=2):
    """One tongue's life: licks up, stretches, tears off, breaks up, dies."""
    rng = np.random.default_rng(seed)
    s = out * ss
    shape = (frames * 2, s, s)
    big = fbm(rng, shape, (2, 1.4, 2.2), octaves=2)
    fine = fbm(rng, shape, (4, 4, 5), octaves=2)
    sway = fbm(rng, shape, (1.5, 1, 1.2), octaves=1)
    u, v = coords(s)
    vv = (v - 0.04) / 0.9
    pad = border(s, 8 * ss)
    result = []
    for i in range(frames):
        tau = i / (frames - 1)
        b = scrolled(big, i, frames * 2, 1.2)
        f = scrolled(fine, i, frames * 2, 2)
        w = sway[i]
        grow = smooth(0.0, 0.3, tau)
        cut = 0.72 * smooth(0.32, 1.0, tau)  # the root lets go and rises
        top = 0.5 + 0.38 * grow + 0.12 * smooth(0.4, 1.0, tau)
        along = (vv - cut) / max(top - cut, 0.05)
        a = np.clip(along, 0, 1)
        uw = u + (0.03 + 0.2 * a**1.2) * w
        detached = smooth(0.3, 0.45, tau)
        bulb = 1 - detached * (1 - smooth(-0.05, 0.22, along))
        width = 0.36 * (1 - 0.3 * smooth(0.45, 1.0, tau)) * np.clip(1 - a, 0, 1) ** 0.55 * bulb
        profile = np.clip(1 - (uw / np.maximum(width, 1e-3)) ** 2, 0, 1)
        wide = np.clip(1 - (uw / np.maximum(width * 1.4, 1e-3)) ** 2, 0, 1)
        life = 1 - 0.55 * smooth(0.4, 1.0, tau)
        heat = profile**0.8 * np.clip(1 - a, 0, 1) ** 0.9 * 0.95 * life
        tear = 0.16 + 0.7 * a + 0.45 * smooth(0.45, 1.0, tau)
        temp = heat + tear * (0.55 * b + 0.45 * f) * 0.5 * wide
        inside = smooth(-0.04, 0.04, along) * (1 - smooth(1.0, 1.25, along))
        alpha = smooth(0.05, 0.42, temp) ** 1.3 * inside * pad
        alpha *= 1 - smooth(0.78, 1.0, tau)
        color = palette((temp - 0.08) * 1.05)
        result.append((down(color, ss), down(alpha, ss)))
    return grid_sheet(result, 4)


def fireball(seed, frames=64, out=128, ss=2):
    """A petrol fireball: full size at once, rolls up and darkens to soot."""
    rng = np.random.default_rng(seed)
    s = out * ss
    shape = (frames, s, s)
    billow = fbm(rng, shape, (1.5, 4, 4), octaves=3)
    wx = fbm(rng, shape, (1, 2, 2), octaves=2)
    wy = fbm(rng, shape, (1, 2, 2), octaves=2)
    u, v = coords(s)
    pad = border(s, 6 * ss)
    puffs = []
    for _ in range(11):
        ang = rng.uniform(0, 2 * np.pi)
        dist = rng.uniform(0.0, 0.42) ** 0.8
        puffs.append((np.cos(ang) * dist, np.sin(ang) * dist, rng.uniform(0.42, 0.66)))
    result = []
    for i in range(frames):
        tau = i / (frames - 1)
        grow = 1 - (1 - tau) ** 2.2
        radius = 0.74 * (0.82 + 0.18 * grow)
        cx, cy = 0.0, -0.1 + 0.12 * tau**1.2
        x = (u - cx) / radius + 0.11 * wx[i]
        y = (v * 2 - 1 - cy) / radius + 0.11 * wy[i]
        thick = np.zeros_like(u)
        roll = tau * 1.4  # the outer billows roll up and over
        for px, py, pr in puffs:
            ang = np.arctan2(py, px) + roll * np.sign(px + 1e-3) * 0.4
            dist = np.hypot(px, py) * (1 + 0.25 * grow)
            qx, qy = np.cos(ang) * dist, np.sin(ang) * dist + 0.15 * tau
            d2 = (x - qx) ** 2 + (y - qy) ** 2
            thick += np.sqrt(np.clip(pr * pr - d2, 0, None)) / pr
        density = (1 - np.exp(-thick * 0.7)) * (1 + 0.25 * billow[i])
        density -= 0.55 * smooth(0.45, 1.0, tau) * (1.2 + 0.6 * billow[i])  # erodes away
        density -= 0.06 * np.clip(billow[i], 0, None)  # (a ragged rim)
        density = np.clip(density, 0, None)
        heat = (1 - smooth(0.0, 0.62, tau)) ** 0.8
        temp = np.clip(density, 0, 1.2) ** 2.2 * heat * (0.8 + 0.3 * billow[i])
        temp += 0.12 * heat * smooth(0.2, 0.8, density)
        # soot shaded by its own lumps (light from above)
        gy, gx = np.gradient(ndimage.gaussian_filter(density, 2 * ss))
        light = np.clip(0.55 - 18 * gy * ss + 6 * gx * ss, 0.2, 1.2)
        warm = smooth(0.0, 0.6, heat) * 0.6  # still lit by the flames inside
        soot = rgb(30, 25, 22)[None, None, :] * (0.7 + 0.8 * light[..., None])
        soot += rgb(120, 40, 10)[None, None, :] * warm * smooth(0.1, 0.5, density)[..., None]
        flame = palette(temp)
        mix = smooth(0.12, 0.42, temp)[..., None]
        color = soot * (1 - mix) + flame * mix
        alpha = smooth(0.02, 0.22, density) * pad
        alpha *= 1 - smooth(0.82, 1.0, tau)
        alpha *= 0.85 + 0.15 * mix[..., 0]
        result.append((down(color, ss), down(alpha, ss)))
    return grid_sheet(result, 8)


def ground_fire(seed, frames=16, out=256, ss=2):
    """A burning film seen from above: ragged hot patches. Loops."""
    rng = np.random.default_rng(seed)
    s = out * ss
    shape = (frames, s, s)
    patches = fbm(rng, shape, (1, 3, 3), octaves=3)
    fingers = fbm(rng, shape, (2, 9, 9), octaves=2)
    outline = fbm(rng, (s, s), (2.5, 2.5), octaves=2)
    u, v = coords(s)
    y = v * 2 - 1
    r = np.hypot(u, y)
    edge = r * (1 + 0.28 * outline)
    mask = 1 - smooth(0.5, 0.92, edge)
    pad = border(s, 6 * ss)
    result = []
    for i in range(frames):
        ridge = 1 - np.abs(fingers[i]) * 0.9  # bright licking lines
        temp = mask * (0.3 + 0.28 * patches[i] + 0.3 * ridge * smooth(-0.3, 0.6, patches[i]))
        temp = np.clip(temp, 0, None)
        film = 0.32 * mask  # the dim burning film under it
        alpha = np.maximum(smooth(0.22, 0.5, temp), film * smooth(0.1, 0.5, mask)) * pad
        color = palette((temp - 0.12) * 1.15)
        result.append((down(color, ss), down(alpha, ss)))
    return grid_sheet(result, 4)


def flame_strip(seed, w=512, h=128, ss=2):
    """A flowing flame band, tiles along X (Beam / Trail)."""
    rng = np.random.default_rng(seed)
    W, H = w * ss, h * ss
    width_n = band(rng, (W,), (5,))
    turb = fbm(rng, (H, W), (3, 10), octaves=3)
    streak = fbm(rng, (H, W), (6, 4), octaves=2)
    yy = (np.arange(H, dtype=np.float32)[:, None] + 0.5) / H * 2 - 1
    half = 0.5 + 0.12 * width_n[None, :]
    profile = np.clip(1 - (yy / half) ** 2, 0, 1)
    wide = np.clip(1 - (yy / (half * 1.5)) ** 2, 0, 1)
    temp = profile**0.9 * 0.85 + 0.32 * wide * (0.65 * turb + 0.35 * streak) * (0.4 + np.abs(yy))
    alpha = smooth(0.12, 0.38, temp)
    alpha *= 1 - smooth(0.82, 0.98, np.abs(yy))
    color = palette((temp - 0.08) * 1.05)
    return down(color, ss), down(alpha, ss)


# ---------------------------------------------------------------------------
# Glow, embers, smoke
# ---------------------------------------------------------------------------


def glow(n=256):
    u, v = coords(n)
    r = np.hypot(u, v * 2 - 1)
    alpha = np.exp(-((r / 0.42) ** 2) * 1.6) * (1 - smooth(0.85, 1.0, r))
    color = palette(0.55 + 0.45 * np.exp(-((r / 0.25) ** 2)))
    return color, alpha


def embers(seed, n=128):
    rng = np.random.default_rng(seed)
    u, v = coords(n)
    y = v * 2 - 1
    frames = []
    # a dot
    r = np.hypot(u, y)
    a = np.exp(-((r / 0.14) ** 2)) + 0.25 * np.exp(-((r / 0.32) ** 2))
    frames.append((palette(0.5 + 0.5 * np.exp(-((r / 0.15) ** 2))), np.clip(a, 0, 1)))
    # a streak (head up: the velocity's way), a fading tail
    along = (y + 0.75) / 1.5
    across = np.abs(u) / (0.06 + 0.1 * along.clip(0, 1))
    core = np.exp(-(across**2) * 2.5) * smooth(-0.05, 0.25, along) * (1 - smooth(0.85, 1.0, along))
    frames.append((palette(0.35 + 0.65 * along.clip(0, 1)), np.clip(core * (0.25 + 0.75 * along.clip(0, 1)), 0, 1)))
    # a curled flake: dark middle, glowing ragged rim
    ang = np.arctan2(y * 1.6, u)
    jag = fbm(rng, (n, n), (5, 5), octaves=2)
    rim = 0.34 * (1 + 0.15 * np.sin(2 * ang + 1) + 0.08 * np.sin(5 * ang + 2)) + 0.03 * jag
    r = np.hypot(u, y * 1.6)
    inside = 1 - smooth(rim - 0.04, rim + 0.01, r)
    edge = np.exp(-(((r - rim + 0.04) / 0.05) ** 2)) * inside * (0.6 + 0.4 * smooth(-0.5, 1, jag))
    color = rgb(40, 20, 12)[None, None, :] * (1 - edge[..., None]) + palette(0.7 * np.ones_like(r)) * edge[..., None]
    frames.append((color, np.clip(inside * 0.85 + edge * 0.15, 0, 1)))
    # a double spark
    a = np.zeros_like(u)
    c = np.zeros_like(u)
    for (x0, y0, s0) in ((-0.3, -0.25, 0.12), (0.28, 0.32, 0.08)):
        d = np.hypot(u - x0, y - y0)
        a += np.exp(-((d / s0) ** 2)) + 0.25 * np.exp(-((d / (s0 * 3)) ** 2))
        c = np.maximum(c, np.exp(-((d / s0) ** 2)))
    frames.append((palette(0.55 + 0.45 * c), np.clip(a, 0, 1)))
    pad = border(n, 4)
    frames = [(fc, fa * pad) for fc, fa in frames]
    return grid_sheet(frames, 2)


def smoke(seed, n=256):
    rng = np.random.default_rng(seed)
    u, v = coords(n)
    y = v * 2 - 1
    r = np.hypot(u, y)
    frames = []
    for _ in range(4):
        billow = fbm(rng, (n, n), (2.5, 2.5), octaves=3, gain=0.45)
        wisps = fbm(rng, (n, n), (7, 7), octaves=2)
        outline = fbm(rng, (n, n), (1.8, 1.8), octaves=2)
        edge = r * (1 + 0.18 * outline) - 0.06 * billow
        body = 1 - smooth(0.15, 0.82, edge)
        density = body * (0.62 + 0.22 * billow + 0.08 * wisps)
        density = ndimage.gaussian_filter(np.clip(density, 0, 1), 1.5)
        gy, gx = np.gradient(ndimage.gaussian_filter(density, 6))
        light = np.clip(0.78 - 9 * gy + 2 * gx, 0.5, 1.0)  # lit from above
        lum = light * (0.9 + 0.1 * billow.clip(-1, 1))
        alpha = smooth(0.0, 0.62, density) * border(n, 6)
        frames.append((np.repeat(lum[..., None], 3, -1).clip(0, 1), alpha))
    return grid_sheet(frames, 2)


# ---------------------------------------------------------------------------
# Scorch (a decal)
# ---------------------------------------------------------------------------


def scorch(seed, n=1024):
    """The black mark a petrol fire leaves (+Y = the way it was thrown)."""
    rng = np.random.default_rng(seed)
    u, v = coords(n)
    y = v * 2 - 1
    # main stain: elongated forward, a lumpy broken edge
    outline = fbm(rng, (n, n), (3, 3), octaves=4)
    mottle_early = fbm(rng, (n, n), (12, 12), octaves=2)
    ex = u / 0.62
    ey = (y - 0.06) / 0.72
    r = np.hypot(ex, ey)
    edge = r * (1 + 0.2 * outline)
    stain = 1 - smooth(0.62, 0.86, edge)
    # splash fingers, most of them forward: a splatter outline in polar
    # coordinates (spiky where the angular noise peaks), wobbling
    ang = np.arctan2(y - 0.06, u)
    rho = np.hypot(u / 0.62, (y - 0.06) / 0.72)
    spikes = np.zeros_like(u)
    forward = 0.5 + 0.5 * np.sin(ang)  # 1 toward +Y
    for _ in range(3):
        k = rng.integers(9, 17)
        phase = rng.uniform(0, 2 * np.pi)
        wob = 0.25 * np.sin(rng.integers(2, 5) * ang + rng.uniform(0, 6))
        spikes = np.maximum(spikes, np.clip(np.sin(k * ang + phase + wob), 0, 1) ** 6 * rng.uniform(0.5, 1))
    reach = 0.7 + (0.18 + 0.32 * forward) * spikes + 0.05 * outline
    fingers = 1 - smooth(reach - 0.06, reach + 0.01, rho * (1 + 0.06 * mottle_early))
    # a droplet off the end of some fingers
    for _ in range(18):
        th = rng.normal(np.pi / 2, 1.0) if rng.random() < 0.7 else rng.uniform(0, 2 * np.pi)
        dist = rng.uniform(1.0, 1.3)
        px, py = np.cos(th) * dist * 0.62, np.sin(th) * dist * 0.72 + 0.06
        rad = rng.uniform(0.008, 0.022)
        fingers = np.maximum(fingers, smooth(rad, rad * 0.5, np.hypot(u - px, y - py)))
    # loose droplets
    for _ in range(40):
        ang = rng.uniform(0, 2 * np.pi)
        dist = rng.uniform(0.5, 0.95)
        px, py = np.cos(ang) * dist * 0.75, np.sin(ang) * dist * 0.85 + 0.05
        rad = rng.uniform(0.004, 0.014)
        fingers = np.maximum(fingers, 0.7 * smooth(rad, rad * 0.5, np.hypot(u - px, y - py)))
    fingers = ndimage.gaussian_filter(fingers, 1.0)
    grain = fbm(rng, (n, n), (40, 40), octaves=2)
    mottle = fbm(rng, (n, n), (8, 8), octaves=3)
    depth = np.clip(np.maximum(stain * (0.55 + 0.45 * smooth(0.86, 0.3, edge)), 0.6 * fingers), 0, 1)
    depth *= 0.88 + 0.12 * mottle.clip(-1, 1)
    # colours: char black in the middle, sooty brown, a singed rim
    black = rgb(14, 12, 11)
    brown = rgb(42, 32, 25)
    singed = rgb(86, 62, 42)
    t = smooth(0.25, 0.85, depth)[..., None]
    color = singed * (1 - smooth(0.0, 0.35, depth)[..., None]) + brown * smooth(0.0, 0.35, depth)[..., None]
    color = color * (1 - t) + black * t
    # pale ash flecks where it burnt hottest
    ash = smooth(2.2, 3.0, grain) * smooth(0.6, 0.9, depth)
    color = color * (1 - 0.35 * ash[..., None]) + rgb(96, 92, 88) * 0.35 * ash[..., None]
    color *= (0.9 + 0.1 * grain.clip(-1, 1))[..., None]
    alpha = np.clip(depth * 1.15, 0, 0.96) * border(n, 8)
    return color, alpha


if __name__ == "__main__":
    which = set(sys.argv[2:])

    def want(name):
        return not which or name in which

    if want("flame_loop"):
        save("flame_loop.png", *flame_loop(101))
    if want("flame_tongue"):
        save("flame_tongue.png", *flame_tongue(202))
    if want("fireball"):
        save("fireball.png", *fireball(303))
    if want("ground_fire"):
        save("ground_fire.png", *ground_fire(404))
    if want("flame_strip"):
        save("flame_strip.png", *flame_strip(505))
    if want("glow"):
        save("glow.png", *glow())
    if want("ember"):
        save("ember.png", *embers(606))
    if want("smoke"):
        save("smoke.png", *smoke(707))
    if want("scorch"):
        save("scorch.png", *scorch(808))
