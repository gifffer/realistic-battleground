# Preview of the burn textures (tools/burns/make_burns.py) as the game
# stacks them (src/client/Combat/Burns.luau): every stage up to the
# degree, each fading in over its first 0.4 degree, on light and dark skin,
# on a shirt; tiled 2 x 2 (seams); the laser spot; the flame, smoke and
# ember sprites tinted as in the game; an R6 body front with a few cases.
#   venv/bin/python -I tools/burns/preview_burns.py [textures_dir] [out.png]
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

SRC = sys.argv[1] if len(sys.argv) > 1 else "assets/burns"
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(SRC, "preview.png")
CELL = 256


def load(name):
    return np.asarray(Image.open(os.path.join(SRC, name)).convert("RGBA")).astype(float) / 255


def fade(stage, degree):
    """How much of a stage shows at a degree (same curve as the game)."""
    t = np.clip((degree - (stage - 1)) / 0.4, 0, 1)
    return t * t * (3 - 2 * t)


def stack(base, prefix, count, degree, tint=1.0):
    out = base.copy()
    for k in range(1, count + 1):
        a = fade(k, degree)
        if a <= 0:
            continue
        img = load(f"{prefix}_{k}.png")
        color = img[..., :3] * (tint if k <= 2 else 1.0)
        alpha = img[..., 3:] * a
        out = out * (1 - alpha) + color * alpha
    return out


def base_color(rgb, n=512, cloth=False):
    out = np.ones((n, n, 3)) * np.array(rgb) / 255
    if cloth:  # a plain knit: faint threads
        py, px = np.mgrid[0:n, 0:n]
        out *= (0.93 + 0.07 * np.sin(px * 1.3) * np.sin(py * 1.3))[..., None]
    return out


def to_img(arr, size=CELL):
    return Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).resize((size, size), Image.LANCZOS)


SKINS = [((226, 180, 146), 1.0), ((120, 78, 52), 0.6)]
SHIRT = (52, 70, 110)


def label(draw, xy, text):
    draw.text(xy, text, fill=(230, 230, 230))


def main():
    rows = []
    titles = []
    degrees = [0.6, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]
    for skin, tint in SKINS:
        rows.append([stack(base_color(skin), "skin", 4, d, tint) for d in degrees])
        titles.append(f"skin {skin}")
    rows.append([stack(base_color(SHIRT, cloth=True), "cloth", 4, d) for d in degrees])
    titles.append("cloth on a blue shirt")
    rows.append([stack(base_color((235, 235, 230), cloth=True), "cloth", 4, d) for d in degrees])
    titles.append("cloth on a white tee")
    rows.append([stack(base_color(SKINS[0][0]), "acid", 3, min(d, 3)) for d in degrees])
    titles.append("acid (max 3)")

    w = CELL * len(degrees)
    sheet = Image.new("RGB", (w, (CELL + 18) * (len(rows) + 2) + 40), (24, 24, 26))
    draw = ImageDraw.Draw(sheet)
    y = 0
    for title, row in zip(titles, rows):
        label(draw, (6, y + 2), title + "   degrees " + " / ".join(str(d) for d in degrees))
        for i, arr in enumerate(row):
            sheet.paste(to_img(arr), (i * CELL, y + 18))
        y += CELL + 18

    # Seams: 2 x 2 tiles of each full stack.
    label(draw, (6, y + 2), "2x2 tiles (seams), spot on skin, particles tinted")
    tiles = [
        stack(base_color(SKINS[0][0]), "skin", 4, 4.0),
        stack(base_color(SKINS[0][0]), "skin", 4, 2.0),
        stack(base_color(SHIRT, cloth=True), "cloth", 4, 3.0),
        stack(base_color(SKINS[0][0]), "acid", 3, 3.0),
    ]
    for i, arr in enumerate(tiles):
        big = np.tile(arr, (2, 2, 1))
        sheet.paste(to_img(big), (i * CELL, y + 18))
    spot = load("spot.png")
    skin = base_color(SKINS[0][0])
    er = load("skin_1.png")
    skin = skin * (1 - er[..., 3:] * 0.5) + er[..., :3] * er[..., 3:] * 0.5
    sp = skin * (1 - spot[..., 3:]) + spot[..., :3] * spot[..., 3:]
    sheet.paste(to_img(sp), (4 * CELL, y + 18))
    # flame: frames 0, 5, 10 tinted, additive over dark
    flame = load("flame.png")
    fr = flame.shape[0] // 4
    for j, i in enumerate((1, 6, 11)):
        r, c = divmod(i, 4)
        f = flame[r * fr : (r + 1) * fr, c * fr : (c + 1) * fr]
        lum = f[..., 0]
        col = np.stack([np.ones_like(lum), 0.35 + 0.55 * lum, 0.08 + 0.5 * lum**3], -1)
        col = col * (lum * f[..., 3])[..., None] * 1.4
        bg = np.ones_like(col) * 0.06
        sheet.paste(to_img(np.clip(bg + col, 0, 1), CELL // 2), (5 * CELL + j * (CELL // 2), y + 18))
    smoke = load("smoke.png")
    sm = 0.5 * (1 - smoke[..., 3:]) + smoke[..., :3] * 0.18 * smoke[..., 3:]
    sheet.paste(to_img(sm, CELL // 2), (6 * CELL + CELL // 2, y + 18))
    ember = load("ember.png")
    em = np.clip(0.05 + ember[..., :3] * np.array([1, 0.55, 0.2]) * ember[..., 3:] * 1.5, 0, 1)
    sheet.paste(to_img(em, CELL // 2), (7 * CELL, y + 18))
    y += CELL + 18

    # R6 front: an immolated body, a Molotov on the legs, a ray spot on the torso.
    label(draw, (6, y + 2), "R6 front: on fire all over (4) / Molotov at the feet (legs 2.5, torso 1) / ray spot + acid on an arm")
    ppx = 40  # px per stud
    cases = [
        {"Torso": 4, "Head": 3.5, "LA": 4, "RA": 4, "LL": 4, "RL": 4},
        {"Torso": 1.0, "Head": 0, "LA": 0.6, "RA": 0, "LL": 2.6, "RL": 2.2},
        {"Torso": 0.8, "Head": 0, "LA": 0, "RA": 0, "LL": 0, "RL": 0, "spot": True, "acid": 2.6},
    ]
    for ci, case in enumerate(cases):
        ox = ci * 260 + 20
        oy = y + 30
        parts = [
            ("Head", (1.5, 0, 1, 1), "skin"),
            ("Torso", (1, 1, 2, 2), "cloth"),
            ("RA", (0, 1, 1, 2), "cloth"),
            ("LA", (3, 1, 1, 2), "acid" if case.get("acid") else "cloth"),
            ("RL", (1, 3, 1, 2), "cloth"),
            ("LL", (2, 3, 1, 2), "cloth"),
        ]
        for name, (px, py, pw, ph), kind in parts:
            wpx, hpx = int(pw * ppx), int(ph * ppx)
            base = base_color(SHIRT if name in ("Torso", "RA", "LA") else (40, 40, 44), cloth=True)
            if name == "Head":
                base = base_color(SKINS[0][0])
            d = case.get(name, 0)
            if kind == "acid":
                arr = stack(base_color(SHIRT, cloth=True), "acid", 3, case["acid"])
            elif d > 0:
                arr = stack(base, kind, 4, d)
            else:
                arr = base
            if name == "Torso" and case.get("spot"):
                sp = load("spot.png")
                arr = arr * (1 - sp[..., 3:]) + sp[..., :3] * sp[..., 3:]
            # 512 px = 2 studs: crop the face size from the tile
            crop = np.tile(arr, (2, 2, 1))[: int(ph * 256), : int(pw * 256)]
            im = Image.fromarray((np.clip(crop, 0, 1) * 255).astype(np.uint8)).resize((wpx, hpx), Image.LANCZOS)
            sheet.paste(im, (ox + int(px * ppx), oy + int(py * ppx)))
    sheet.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
