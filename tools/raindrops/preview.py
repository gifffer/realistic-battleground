# Preview of the rain-on-the-lens pictures, composited like the game does (plain alpha "over",
# ImageTransparency ~0.2), at in-game scale on 1920 x 1080 screenshots.
# python3 tools/raindrops/preview.py out.png background1.png [background2.png ...]
import sys
import numpy as np
from PIL import Image

SRC = "assets/raindrops/"


def load(name):
    return Image.open(SRC + name).convert("RGBA")


def place(bg, img, cx, cy, w, rot=0.0, transparency=0.2, h=None):
    im = img.resize((int(w), int(h or w * img.height / img.width)), Image.LANCZOS)
    if rot:
        im = im.rotate(rot, resample=Image.BICUBIC, expand=True)
    a = np.asarray(im).astype(float) / 255
    a[..., 3] *= 1 - transparency
    x0, y0 = int(cx - im.width / 2), int(cy - im.height / 2)
    H, W, _ = bg.shape
    x1, y1 = x0 + im.width, y0 + im.height
    cx0, cy0, cx1, cy1 = max(x0, 0), max(y0, 0), min(x1, W), min(y1, H)
    if cx1 <= cx0 or cy1 <= cy0:
        return
    a = a[cy0 - y0 : cy1 - y0, cx0 - x0 : cx1 - x0]
    dst = bg[cy0:cy1, cx0:cx1]
    al = a[..., 3:]
    bg[cy0:cy1, cx0:cx1] = a[..., :3] * al + dst * (1 - al)


def scene(path, seed, storm):
    rng = np.random.default_rng(seed)
    bg = np.asarray(Image.open(path).convert("RGB").resize((1920, 1080), Image.BICUBIC)).astype(float) / 255
    # (the game's own camera picture is sharp: blur nothing, the drops are the only addition)
    place(bg, load("wet_glass.png"), 960, 540, 1920, transparency=0.35 if storm else 0.6, h=1080)
    place(bg, load("mist_1.png"), 960, 540, 1920, transparency=0.25 if storm else 0.6, h=1080)
    if storm:
        place(bg, load("mist_2.png"), 960, 540, 1920, transparency=0.4, h=1080)
    names = ["drop_round.png", "drop_egg.png", "drop_irregular.png", "drop_merged_2.png", "drop_merged_3.png"]
    n = 14 if storm else 8
    for _ in range(n):
        side = rng.random()
        if side < 0.4:
            x = rng.uniform(60, 600)
        elif side < 0.8:
            x = rng.uniform(1320, 1860)
        else:
            x = rng.uniform(300, 1620)
        y = rng.uniform(60, 1000) if side < 0.8 else rng.uniform(40, 220)
        w = rng.uniform(26, 70) * (1.5 if rng.random() < 0.2 else 1)
        place(bg, load(names[rng.integers(0, 5)]), x, y, w, rot=rng.uniform(-25, 25), transparency=rng.uniform(0.1, 0.3))
    for i in range(2 if storm else 1):
        x = rng.uniform(150, 450) if i == 0 else rng.uniform(1450, 1800)
        place(bg, load(f"streak_{rng.integers(1, 4)}.png"), x, rng.uniform(450, 760), 46, rot=rng.uniform(-4, 4), transparency=0.15)
    return Image.fromarray((np.clip(bg, 0, 1) * 255).astype(np.uint8))


def sheet():
    # every texture alone over grey and over a dark blue (to read the alpha)
    names = ["drop_round.png", "drop_egg.png", "drop_irregular.png", "drop_merged_2.png", "drop_merged_3.png"]
    out = Image.new("RGB", (5 * 256 + 3 * 128, 512), (0, 0, 0))
    for row, color in enumerate(((128, 132, 136), (30, 38, 52))):
        for i, n in enumerate(names):
            tile = Image.new("RGBA", (256, 256), color + (255,))
            tile.alpha_composite(load(n))
            out.paste(tile.convert("RGB"), (i * 256, row * 256))
    for i in range(3):
        tile = Image.new("RGBA", (128, 512), ((128, 132, 136) if i != 1 else (30, 38, 52)) + (255,))
        tile.alpha_composite(load(f"streak_{i + 1}.png"))
        out.paste(tile.convert("RGB"), (5 * 256 + i * 128, 0))
    return out


if __name__ == "__main__":
    out = sys.argv[1]
    bgs = sys.argv[2:]
    shots = [scene(p, 100 + i, storm=(i % 2 == 1)) for i, p in enumerate(bgs)]
    W = 960
    big = Image.new("RGB", (W * 2, 540 * ((len(shots) + 1) // 2) + 256), (0, 0, 0))
    for i, s in enumerate(shots):
        big.paste(s.resize((W, 540), Image.LANCZOS), ((i % 2) * W, (i // 2) * 540))
    sh = sheet()
    big.paste(sh.resize((sh.width // 2, sh.height // 2), Image.LANCZOS), (0, big.height - 256))
    big.save(out, optimize=True)
    for i, s in enumerate(shots):
        s.save(out.replace(".png", f"_full{i}.png"))
    sheet().save(out.replace(".png", "_sheet.png"))
