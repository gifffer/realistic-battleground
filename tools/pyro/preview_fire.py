# Previews of the fire textures (tools/pyro/make_fire.py):
#   sheets.png   every sheet over a night ground and a daylight sky, blended
#                the way the game draws them (LightEmission 0.6)
#   scene.png    a small particle simulation with the game's own layers
#                (Combat/FireLook presets): a burning body, a fire pool seen
#                from a fighter's camera, a fireball; 8 frames each, over
#                dusk and daylight
#   scene.gif    the same, animated
# Run from the repo root:
#   venv/bin/python -I tools/pyro/preview_fire.py [assets/fire] [out_dir]
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

SRC = sys.argv[1] if len(sys.argv) > 1 else "assets/fire"
OUT = sys.argv[2] if len(sys.argv) > 2 else SRC

DARK = np.array([22, 20, 24], np.float32) / 255
SKY = np.array([168, 186, 204], np.float32) / 255


def load(name):
    img = np.asarray(Image.open(os.path.join(SRC, name)).convert("RGBA"), np.float32) / 255
    return img[..., :3], img[..., 3]


def blend(dst, color, alpha, emission=0.6, brightness=1.0):
    """Roblox-like: LightEmission 0 = alpha blend, 1 = additive."""
    a = alpha[..., None]
    return dst * (1 - a * (1 - emission)) + color * brightness * a


def sheets():
    names = [
        "flame_loop.png",
        "flame_tongue.png",
        "fireball.png",
        "ground_fire.png",
        "smoke.png",
        "ember.png",
        "glow.png",
        "scorch.png",
        "flame_strip.png",
    ]
    tiles = []
    for name in names:
        color, alpha = load(name)
        h, w = alpha.shape
        scale = 512 / max(h, w)
        size = (int(w * scale), int(h * scale))
        row = []
        for bg in (DARK, SKY):
            base = np.ones((h, w, 3), np.float32) * bg
            if name == "smoke.png":
                out = blend(base, color * np.array([0.35, 0.33, 0.31]), alpha, 0)
            elif name == "scorch.png":
                ground = np.ones((h, w, 3), np.float32) * np.array([0.42, 0.40, 0.37])
                out = blend(ground, color, alpha, 0)
            else:
                out = blend(base, color, alpha, 0.6)
            img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).resize(size, Image.LANCZOS)
            row.append(img)
        tile = Image.new("RGB", (size[0] * 2 + 8, size[1] + 22), (40, 40, 44))
        tile.paste(row[0], (0, 22))
        tile.paste(row[1], (size[0] + 8, 22))
        ImageDraw.Draw(tile).text((6, 5), name, fill=(240, 240, 240))
        tiles.append(tile)
    width = max(t.width for t in tiles)
    cols = 2
    rows = math.ceil(len(tiles) / cols)
    heights = [max(t.height for t in tiles[r * cols : (r + 1) * cols]) for r in range(rows)]
    sheet = Image.new("RGB", (width * cols, sum(heights)), (30, 30, 34))
    y = 0
    for r in range(rows):
        for c in range(cols):
            i = r * cols + c
            if i < len(tiles):
                sheet.paste(tiles[i], (c * width, y))
        y += heights[r]
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, "sheets.png"))
    print("wrote", os.path.join(OUT, "sheets.png"))



def strip(name, grid, picks, cell=192, bg=DARK, emission=0.6):
    """A few frames of a sheet, big, side by side (looking at the shapes)."""
    color, alpha = load(name)
    n = alpha.shape[0] // grid
    out = Image.new("RGB", (cell * len(picks), cell), (0, 0, 0))
    for k, i in enumerate(picks):
        r, c = divmod(i, grid)
        fc = color[r * n : (r + 1) * n, c * n : (c + 1) * n]
        fa = alpha[r * n : (r + 1) * n, c * n : (c + 1) * n]
        base = np.ones(fc.shape, np.float32) * bg
        img = blend(base, fc, fa, emission)
        out.paste(Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((cell, cell), Image.LANCZOS), (k * cell, 0))
    return out


def frames():
    rows = [
        strip("flame_loop.png", 8, [0, 9, 18, 27, 36, 45, 54, 63]),
        strip("flame_loop.png", 8, [0, 9, 18, 27, 36, 45, 54, 63], bg=SKY),
        strip("flame_tongue.png", 4, [0, 2, 4, 6, 8, 10, 12, 14]),
        strip("fireball.png", 8, [0, 6, 12, 20, 28, 36, 46, 56]),
        strip("fireball.png", 8, [0, 6, 12, 20, 28, 36, 46, 56], bg=SKY),
        strip("ground_fire.png", 4, [0, 2, 4, 6, 8, 10, 12, 14]),
    ]
    sheet = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    sheet.save(os.path.join(OUT, "frames.png"))
    print("wrote", os.path.join(OUT, "frames.png"))


# ---------------------------------------------------------------------------
# A small particle simulation of the game's layers (side view, orthographic)
# ---------------------------------------------------------------------------

PX = 46  # pixels per stud
_cache = {}


def frame_of(name, grid, index):
    key = (name, grid, index)
    if key not in _cache:
        color, alpha = load(name)
        n = alpha.shape[0] // grid
        r, c = divmod(index, grid)
        _cache[key] = np.concatenate(
            [color[r * n : (r + 1) * n, c * n : (c + 1) * n], alpha[r * n : (r + 1) * n, c * n : (c + 1) * n, None]], -1
        )
    return _cache[key]


def seq(points, t):
    ts = [p[0] for p in points]
    vs = [p[1] for p in points]
    return np.interp(t, ts, vs) if not isinstance(vs[0], (list, tuple, np.ndarray)) else np.array(
        [np.interp(t, ts, [v[i] for v in vs]) for i in range(3)]
    )


class Emitter:
    def __init__(self, rng, **kw):
        self.rng = rng
        self.__dict__.update(
            dict(
                rate=0,
                life=(0.5, 0.8),
                speed=(0.5, 1.3),
                spread=8,
                accel=5.0,
                drag=1.5,
                size=[(0, 0.5), (0.3, 1.0), (1, 0.55)],
                alpha=[(0, 1), (0.08, 0.2), (0.6, 0.35), (1, 1)],
                color=[(0, (1, 1, 1)), (0.55, (1, 0.91, 0.82)), (1, (0.77, 0.44, 0.31))],
                le=0.6,
                bright=1.6,
                sheet=("flame_loop.png", 8, "loop", (20, 28)),
                box=((0, 0), (0.5, 0.5)),
                z=0.3,
                rot=10,
                flat=False,
            )
        )
        self.__dict__.update(kw)
        self.parts = []
        self.acc = 0.0

    def emit(self, count):
        r = self.rng
        for _ in range(count):
            (cx, cy), (hx, hy) = self.box
            ang = np.radians(r.uniform(-self.spread, self.spread))
            sp = r.uniform(*self.speed)
            self.parts.append(
                dict(
                    x=cx + r.uniform(-hx, hx),
                    y=cy + r.uniform(-hy, hy),
                    vx=np.sin(ang) * sp,
                    vy=np.cos(ang) * sp,
                    age=0.0,
                    life=r.uniform(*self.life),
                    rot=r.uniform(-self.rot, self.rot),
                    fps=r.uniform(*self.sheet[3]) if self.sheet[2] == "loop" else 0,
                    start=r.integers(0, self.sheet[1] ** 2),
                )
            )

    def step(self, dt):
        self.acc += self.rate * dt
        n = int(self.acc)
        self.acc -= n
        self.emit(n)
        keep = []
        for p in self.parts:
            p["age"] += dt
            if p["age"] >= p["life"]:
                continue
            damp = np.exp(-self.drag * dt)
            p["vx"] *= damp
            p["vy"] = p["vy"] * damp + self.accel * dt
            p["x"] += p["vx"] * dt
            p["y"] += p["vy"] * dt
            keep.append(p)
        self.parts = keep


def draw(canvas, em, origin, elev=1.0):
    h, w = canvas.shape[:2]
    name, grid, mode, _ = em.sheet
    for p in em.parts:
        t = p["age"] / p["life"]
        if mode == "loop":
            idx = int(p["start"] + p["age"] * p["fps"]) % (grid * grid)
        elif mode == "still":
            idx = p["start"]
        else:
            idx = min(int(t * grid * grid), grid * grid - 1)
        img = frame_of(name, grid, idx)
        size = float(seq(em.size, t))
        sx = max(2, int(size * PX))
        sy = max(2, int(size * PX * (elev if em.flat else 1)))
        tile = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGBA").resize((sx, sy), Image.BILINEAR)
        if p["rot"]:
            tile = tile.rotate(p["rot"], resample=Image.BILINEAR, expand=False)
        a = np.asarray(tile, np.float32) / 255
        col = a[..., :3] * np.array(seq(em.color, t)) * em.bright
        alpha = a[..., 3] * (1 - float(seq(em.alpha, t)))
        cx = int(origin[0] + p["x"] * PX - sx / 2)
        cy = int(origin[1] - p["y"] * PX * (elev if em.flat else 1) - sy / 2)
        x0, y0 = max(cx, 0), max(cy, 0)
        x1, y1 = min(cx + sx, w), min(cy + sy, h)
        if x1 <= x0 or y1 <= y0:
            continue
        sub = (slice(y0 - cy, y1 - cy), slice(x0 - cx, x1 - cx))
        canvas[y0:y1, x0:x1] = blend(canvas[y0:y1, x0:x1], col[sub], alpha[sub], em.le)


def body_scene(rng):
    """An R6 body fully alight (Burns: body, tongue, glow per part; one smoke; embers)."""
    parts = {"Torso": ((0, 3), (1.0, 1.0)), "Left Arm": ((-1.5, 3), (0.5, 1.0)), "Right Arm": ((1.5, 3), (0.5, 1.0)),
             "Left Leg": ((-0.5, 1), (0.5, 1.0)), "Right Leg": ((0.5, 1), (0.5, 1.0)), "Head": ((0, 4.6), (0.5, 0.5))}
    ems = []
    heat = 3
    for name, box in parts.items():
        s = 1.0 if name == "Torso" else 0.67
        if name == "Head":
            s = 0.67
        ems.append(Emitter(rng, rate=(2.5 + 2.2 * heat) * s, box=box, size=[(0, 0.6 * s), (0.3, 2.95 * s), (1, 0.7 * s)],
                           speed=(0.3 * s, 0.8 * s), accel=2.5 * s, drag=2))
        ems.append(Emitter(rng, rate=(1.5 + 3 * heat) * s, box=box, sheet=("flame_tongue.png", 4, "once", (0, 0)),
                           size=[(0, 0.7 * s), (1, 1.1 * s)], alpha=[(0, 0.15), (0.7, 0.3), (1, 1)], life=(0.35, 0.6),
                           speed=(2 * s, 3.5 * s), accel=9 * s, drag=1, le=0.8, bright=2, z=0.35))
        ems.append(Emitter(rng, rate=5 * heat, box=box, sheet=("glow.png", 1, "still", (0, 0)), size=[(0, 1.1 * s), (1, 1.1 * s)],
                           alpha=[(0, 0.7), (1, 1)], life=(0.15, 0.25), speed=(0, 0), accel=0, le=1, bright=2.5,
                           color=[(0, (1, 0.75, 0.43)), (1, (1, 0.75, 0.43))], z=0.4))
        ems.append(Emitter(rng, rate=0.4 + 0.6 * heat, box=box, sheet=("ember.png", 2, "still", (0, 0)), size=[(0, 0.09), (1, 0.03)],
                           alpha=[(0, 0), (0.75, 0.2), (1, 1)], life=(1, 2.2), speed=(3, 6), spread=40, accel=4, drag=1.2, le=1, bright=3,
                           color=[(0, (1, 0.96, 0.84)), (0.4, (1, 0.67, 0.38)), (1, (0.75, 0.21, 0.09))], z=0.45))
    ems.append(Emitter(rng, rate=min(1.5 + 0.6 * 18, 9), box=((0, 3.3), (0.1, 0.1)), sheet=("smoke.png", 2, "still", (0, 0)),
                       size=[(0, 1.2), (1, 6)], alpha=[(0, 1), (0.15, 0.45), (1, 1)], life=(2.5, 3.5), speed=(2, 3.5), spread=12,
                       accel=2, drag=0.8, le=0, bright=1, rot=180,
                       color=[(0, (0.44, 0.25, 0.14)), (0.2, (0.12, 0.1, 0.09)), (1, (0.31, 0.29, 0.27))], z=-0.5))
    return ems, parts


def pool_scene(rng):
    """A fire pool: per cell a flat burning film + standing flame clusters (seen from ~25 deg up)."""
    ems = []
    cells = [(x, z) for x in (-3, -1.5, 0, 1.5, 3) for z in (-1, 1)]
    for (x, z) in cells:
        r = 1.5
        depth = z * 0.42  # (farther cells a little higher on screen)
        ems.append(Emitter(rng, rate=2.5, box=((x, depth / 0.42), (r * 0.75, r * 0.75 * 0.3)), sheet=("ground_fire.png", 4, "loop", (9, 13)),
                           size=[(0, 0.85 * r * 1.6), (1, 1.05 * r * 1.6)], alpha=[(0, 1), (0.25, 0.3), (0.75, 0.35), (1, 1)],
                           life=(1.2, 2), speed=(0, 0), accel=0, le=0.8, bright=1.5, rot=180, flat=True, z=0.05))
    for (x, z) in cells:
        s = rng.uniform(2, 2.9)
        ems.append(Emitter(rng, rate=rng.uniform(2.4, 3.4), box=((x, z * 0.42 + 0.1), (1.1, 0.05)),
                           size=[(0, 0.5 * s), (0.3, 1.0 * s), (1, 0.55 * s)], speed=(0.3 * s, 0.8 * s), accel=2.5 * s, drag=2, life=(0.55, 0.9)))
    ems.append(Emitter(rng, rate=12, box=((0, 1.5), (2, 0.2)), sheet=("smoke.png", 2, "still", (0, 0)),
                       size=[(0, 1.9), (1, 9.6)], alpha=[(0, 1), (0.15, 0.45), (1, 1)], life=(3, 5), speed=(3, 5), spread=12,
                       accel=1.5, drag=0.4, le=0, bright=1, rot=180,
                       color=[(0, (0.44, 0.25, 0.14)), (0.2, (0.12, 0.1, 0.09)), (1, (0.31, 0.29, 0.27))], z=-0.5))
    return ems


def render(ems, bg, size, origin, ground=None, bodies=None, elev=1.0, glow=None):
    canvas = np.ones((size[1], size[0], 3), np.float32) * bg
    if ground is not None:
        canvas[origin[1]:, :] = ground
    if glow is not None:
        # the fire's light on the floor / the body (a soft warm pool)
        yy, xx = np.mgrid[0 : size[1], 0 : size[0]]
        d = np.hypot((xx - glow[0]) / (glow[2] * PX), (yy - glow[1]) / (glow[2] * PX * 0.45))
        canvas += np.exp(-(d**2) * 2)[..., None] * np.array([0.5, 0.24, 0.08]) * glow[3]
    if bodies:
        for (cx, cy), (hx, hy) in bodies.values():
            x0, x1 = int(origin[0] + (cx - hx) * PX), int(origin[0] + (cx + hx) * PX)
            y0, y1 = int(origin[1] - (cy + hy) * PX), int(origin[1] - (cy - hy) * PX)
            canvas[y0:y1, x0:x1] = canvas[y0:y1, x0:x1] * 0.2 + np.array([0.12, 0.08, 0.06]) * 0.8
    for em in sorted(ems, key=lambda e: e.z):
        draw(canvas, em, origin, elev)
    return np.clip(canvas, 0, 1)


def scene():
    out_frames = []
    rows = []
    for bg, ground in ((DARK * 1.4, np.array([0.1, 0.09, 0.09])), (SKY, np.array([0.45, 0.43, 0.4]))):
        for kind in ("body", "pool"):
            rng = np.random.default_rng(7)
            if kind == "body":
                ems, parts = body_scene(rng)
                size, origin = (420, 560), (210, 520)
            else:
                ems = pool_scene(rng)
                parts = None
                size, origin = (560, 420), (280, 330)
            dt = 1 / 30
            for _ in range(70):
                for em in ems:
                    em.step(dt)
            row = []
            for f in range(6):
                for _ in range(3):
                    for em in ems:
                        em.step(dt)
                glow = (origin[0], origin[1], 4 if kind == "pool" else 2.5, 1.0 if bg is not SKY else 0.35)
                img = render(ems, bg, size, origin, ground, parts, elev=0.42, glow=glow)
                row.append(Image.fromarray((img * 255).astype(np.uint8)).resize((size[0] // 2, size[1] // 2), Image.LANCZOS))
                if bg is not SKY and kind == "body":
                    out_frames.append(Image.fromarray((img * 255).astype(np.uint8)))
            strip_img = Image.new("RGB", (sum(r.width for r in row), row[0].height))
            x = 0
            for r in row:
                strip_img.paste(r, (x, 0))
                x += r.width
            rows.append(strip_img)
    width = max(r.width for r in rows)
    sheet = Image.new("RGB", (width, sum(r.height for r in rows)), (20, 20, 20))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height
    sheet.save(os.path.join(OUT, "scene.png"))
    print("wrote", os.path.join(OUT, "scene.png"))


if __name__ == "__main__":
    sheets()
    frames()
    scene()
