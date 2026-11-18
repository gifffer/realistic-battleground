# Preview of the world rain pictures on a dark night street (assets/rain/preview.png).
# Run from the repo root after make_rain_textures.py:  python3 tools/rain/preview.py
# Top: the three depth layers as the game draws them (far sheet, mid fine streaks, near
# stretched drops, splashes on the ground). Bottom: the splash and ripple flipbooks.
import numpy as np
from PIL import Image

SRC = "assets/rain/"
rng = np.random.default_rng(3)
W, H = 1280, 1100


def load(name):
    return Image.open(SRC + name).convert("RGBA")


def over(base, sprite, x, y, tint=(1, 1, 1), opacity=1.0):
    s = np.asarray(sprite).astype(float) / 255
    h, w = s.shape[:2]
    x0, y0 = int(x - w / 2), int(y - h / 2)
    bx0, by0 = max(0, x0), max(0, y0)
    bx1, by1 = min(base.shape[1], x0 + w), min(base.shape[0], y0 + h)
    if bx1 <= bx0 or by1 <= by0:
        return
    sub = s[by0 - y0:by1 - y0, bx0 - x0:bx1 - x0]
    a = sub[..., 3:4] * opacity
    col = sub[..., :3] * np.array(tint)
    base[by0:by1, bx0:bx1] = base[by0:by1, bx0:bx1] * (1 - a) + col * a


def scene():
    img = np.zeros((700, W, 3))
    yy = np.linspace(0, 1, 700)[:, None]
    # night sky to wet street, a lamp glow on the left
    img[:] = (0.05 + 0.05 * yy)[..., None] * np.array([0.8, 0.9, 1.1])
    xx = np.linspace(0, 1, W)[None, :]
    glow = np.exp(-(((xx - 0.25) / 0.12) ** 2 + ((yy - 0.45) / 0.25) ** 2))
    img += glow[..., None] * np.array([0.35, 0.25, 0.12])
    img[520:] *= 0.7
    # buildings in the back
    for bx in range(0, W, 160):
        top = rng.integers(120, 300)
        img[top:520, bx + 10:bx + 140] *= 0.55
    return img


def main():
    out = np.zeros((H, W, 3))
    street = scene()
    drop = load("rain_drop.png")
    sheet = load("rain_sheet.png")
    # far: the sheet rotated upright (a Beam lays it along its length), faint
    far = sheet.rotate(90, expand=True).resize((256, 700))
    for x in range(0, W, 220):
        over(street, far, x + 110, 350, (0.75, 0.8, 0.85), 0.45)
    lean = np.deg2rad(5)
    # mid: thin, dense, faint
    for _ in range(900):
        length = int(rng.uniform(14, 24))
        sprite = drop.resize((3, length)).rotate(np.rad2deg(lean), expand=True)
        over(street, sprite, rng.uniform(0, W), rng.uniform(0, 520), (0.75, 0.8, 0.86), 0.5)
    # near: a few, thick, long
    for _ in range(70):
        length = int(rng.uniform(70, 140))
        sprite = drop.resize((6, length)).rotate(np.rad2deg(lean), expand=True)
        over(street, sprite, rng.uniform(0, W), rng.uniform(0, 700), (0.8, 0.85, 0.9), 0.55)
    # splashes and ripples on the street
    splash = load("rain_splash.png")
    ripple = load("rain_ripple.png")
    for _ in range(40):
        f = int(rng.integers(0, 16))
        gy, gx = divmod(f, 4)
        fr = splash.crop((gx * 128, gy * 128, gx * 128 + 128, gy * 128 + 128)).resize((40, 40))
        over(street, fr, rng.uniform(0, W), rng.uniform(560, 690), (0.8, 0.85, 0.9), 0.8)
    for _ in range(25):
        f = int(rng.integers(0, 16))
        gy, gx = divmod(f, 4)
        fr = ripple.crop((gx * 256, gy * 256, gx * 256 + 256, gy * 256 + 256)).resize((90, 26))
        over(street, fr, rng.uniform(0, W), rng.uniform(540, 690), (0.8, 0.85, 0.9), 0.7)
    out[:700] = street
    # bottom: the flipbooks on a dark wet ground
    out[700:] = 0.08
    sp = np.asarray(splash.resize((380, 380))).astype(float) / 255
    rp = np.asarray(ripple.resize((380, 380))).astype(float) / 255
    for arr, x0 in ((sp, 30), (rp, 450)):
        a = arr[..., 3:4]
        out[710:1090, x0:x0 + 380] = out[710:1090, x0:x0 + 380] * (1 - a) + arr[..., :3] * a
    dr = np.asarray(drop.resize((192, 192))).astype(float) / 255
    a = dr[..., 3:4]
    out[720:912, 900:1092] = out[720:912, 900:1092] * (1 - a) + dr[..., :3] * a
    st = np.asarray(drop.resize((16, 160))).astype(float) / 255
    a = st[..., 3:4]
    out[920:1080, 1150:1166] = out[920:1080, 1150:1166] * (1 - a) + st[..., :3] * a
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(SRC + "preview.png")
    print("wrote", SRC + "preview.png")


if __name__ == "__main__":
    main()
