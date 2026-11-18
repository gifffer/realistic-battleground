# Burn textures for the burn system (src/client/Combat/Burns.luau, ids in
# Config.Injuries.BURNS). Every picture is made here from noise: no photo.
#
# Tiled on the body parts (seamless 512 x 512 RGBA, 2 studs a tile). The
# four stages of one set come from ONE depth map, so the deeper stage always
# sits in the middle of the shallower one (char inside eschar inside
# blisters inside redness), like a real burn:
#   skin_1..4.png   bare skin: 1 redness (erythema), 2 blisters, wet pink
#                   dermis and peeling skin, 3 leathery eschar (waxy white,
#                   parchment tan, mahogany, clotted veins), 4 charred black
#                   with cracks showing yellow fat and red flesh
#   cloth_1..4.png  over a shirt / pants: 1 singed brown, 2 charred cloth
#                   with burnt-through holes (blistered skin in them), 3 big
#                   holes (eschar), 4 cloth burnt into the charred skin
#   acid_1..3.png   a chemical burn: 1 yellow-brown stain, 2 eroded
#                   yellow-grey slough with raw pits, runs going down,
#                   3 brown-black leathery eschar with eroded edges
# Not tiled:
#   spot.png        one laser / ray burn in the middle (content within the
#                   central 40 %: a tile bigger than the face shows one)
#   flame.png       4 x 4 flipbook of a flame tongue (grey: tinted in game)
#   smoke.png       a soft smoke puff (grey: tinted in game)
#   ember.png       a glowing ember streak
#
# Run from the repo root (numpy, scipy, pillow):
#   venv/bin/python -I tools/burns/make_burns.py [out_dir]
# then look at preview.png (venv/bin/python -I tools/burns/preview_burns.py).
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree

N = 512
OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/burns"


# ---------------------------------------------------------------------------
# Noise (all periodic: the tiles are seamless)
# ---------------------------------------------------------------------------


def spectral(rng, beta, low=1.0, high=None, stretch=(1.0, 1.0), n=N):
    """Periodic noise with a 1/f^beta spectrum between `low` and `high`
    cycles per tile. `stretch` (y, x) > 1 squeezes features on that axis."""
    white = rng.standard_normal((n, n))
    ky = np.fft.fftfreq(n)[:, None] * n * stretch[0]
    kx = np.fft.fftfreq(n)[None, :] * n * stretch[1]
    k = np.sqrt(kx * kx + ky * ky)
    k[0, 0] = 1
    amp = k ** (-beta / 2)
    amp[k < low] = 0
    if high is not None:
        amp *= np.exp(-((k / high) ** 2))
    field = np.real(np.fft.ifft2(np.fft.fft2(white) * amp))
    return field / (field.std() + 1e-9)


def rank(field):
    """Same shape, values spread evenly over [0, 1] (so a threshold t keeps
    exactly 1 - t of the tile)."""
    flat = field.ravel()
    order = flat.argsort()
    out = np.empty_like(flat)
    out[order] = np.linspace(0, 1, flat.size)
    return out.reshape(field.shape)


def norm(field):
    lo, hi = np.percentile(field, 1), np.percentile(field, 99)
    return np.clip((field - lo) / (hi - lo + 1e-9), 0, 1)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def wrap_blur(field, sigma):
    return ndimage.gaussian_filter(field, sigma, mode="wrap")


def warp(field, dx, dy):
    """`field` sampled at (x + dx, y + dy), wrapping (bilinear)."""
    n = field.shape[0]
    py, px = np.mgrid[0:n, 0:n].astype(float)
    return ndimage.map_coordinates(field, [py + dy, px + dx], order=1, mode="grid-wrap")


def cells(rng, count, n=N, stretch=(1.0, 1.0)):
    """Periodic Worley noise: distances to the nearest and second nearest of
    `count` random points; F2 - F1 ~ 0 along the cell walls (cracks)."""
    points = rng.random((count, 2)) * n
    tree = cKDTree(points, boxsize=n)
    py, px = np.mgrid[0:n, 0:n]
    dist, idx = tree.query(np.stack([px.ravel(), py.ravel()], -1), k=2)
    f1 = dist[:, 0].reshape(n, n)
    f2 = dist[:, 1].reshape(n, n)
    return f1, f2, idx[:, 0].reshape(n, n)


def shade(height, strength=1.0, light=(-0.5, -0.65, 0.58)):
    """Diffuse and a specular lobe from a height map (light from the top
    left, the eye in front): baked relief on a flat face."""
    gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) / 2
    gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) / 2
    nx, ny, nz = -gx * strength, -gy * strength, np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / length, ny / length, nz / length
    lx, ly, lz = np.array(light) / np.linalg.norm(light)
    diffuse = np.clip(nx * lx + ny * ly + nz * lz, 0, 1)
    hx, hy, hz = lx, ly, lz + 1
    hl = np.sqrt(hx * hx + hy * hy + hz * hz)
    spec = np.clip((nx * hx + ny * hy + nz * hz) / hl, 0, 1)
    return diffuse, spec


def relit(color, height, strength, flat=0.55):
    """Colour lit by its relief, average brightness kept."""
    diffuse, _ = shade(height, strength)
    base = diffuse / (diffuse.mean() + 1e-9)
    return color * (flat + (1 - flat) * base)[..., None]


def rgb(*c):
    return np.array(c, float) / 255


def mix(a, b, t):
    t = np.asarray(t, float)
    if t.ndim == 2:
        t = t[..., None]
    return a * (1 - t) + b * t


def palette(t, stops):
    """Colour along a ramp of (position, rgb) stops, t in [0, 1]."""
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,))
    pos = [s[0] for s in stops]
    for c in range(3):
        out[..., c] = np.interp(t, pos, [s[1][c] for s in stops])
    return out / 255


def save(name, color, alpha):
    os.makedirs(OUT, exist_ok=True)
    out = np.concatenate([np.clip(color, 0, 1), np.clip(alpha, 0, 1)[..., None]], -1)
    Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, name))
    print("wrote", os.path.join(OUT, name))


# ---------------------------------------------------------------------------
# Building blocks of a burn
# ---------------------------------------------------------------------------


def depth_map(rng):
    """Where the burn is deepest: big soft blobs with ragged edges, evenly
    spread over [0, 1]. Stage k covers depth > threshold k."""
    big = spectral(rng, 3.6, low=1.5, high=10)
    mid = spectral(rng, 2.6, low=4, high=40)
    ragged = spectral(rng, 1.6, low=20, high=140)
    return rank(big + 0.35 * mid + 0.12 * ragged)


def edge_band(mask_soft, width):
    """1 near the border of a mask (inside), fading over `width` pixels."""
    inside = mask_soft > 0.5
    dist = ndimage.distance_transform_edt(np.tile(inside, (3, 3)))[N : 2 * N, N : 2 * N]
    return np.clip(1 - dist / width, 0, 1) * inside, dist


def erythema(rng, depth):
    """Stage 1: red, blotchy, dry; capillary mottling; strongest where the
    burn is deeper."""
    blotch = norm(spectral(rng, 2.4, low=3, high=60))
    capillary = norm(spectral(rng, 1.2, low=40, high=200))
    color = palette(
        0.55 * blotch + 0.45 * depth,
        [(0, (214, 120, 98)), (0.5, (206, 86, 72)), (0.8, (188, 62, 56)), (1, (166, 46, 46))],
    )
    color = mix(color, rgb(150, 40, 46), 0.25 * smooth(0.6, 1, capillary))
    alpha = 0.32 + 0.38 * smooth(0.0, 1.0, depth) + 0.18 * (blotch - 0.5)
    alpha *= 0.85 + 0.15 * capillary
    return color, np.clip(alpha, 0, 0.82)


def blisters(rng, depth, cover):
    """Stage 2 (partial thickness): wet glossy pink-red dermis where the
    skin has come off, peeling sheets of dead white skin curling at their
    edges, intact fluid blisters around. Opaque within `cover`."""
    region = smooth(-0.02, 0.02, depth - cover)  # (soft edge, ~2 px)
    # The dermis: bright wet pink-red, mottled darker (deeper) and paler.
    mott = norm(spectral(rng, 2.0, low=8, high=90))
    dermis = palette(
        0.6 * mott + 0.4 * depth,
        [(0, (232, 140, 128)), (0.45, (218, 100, 94)), (0.75, (196, 70, 70)), (1, (168, 52, 56))],
    )
    # Deep partial thickness: waxy pale islands in the deepest dermis.
    wax = smooth(0.72, 0.9, depth + 0.12 * spectral(rng, 1.5, low=10, high=80))
    dermis = mix(dermis, rgb(236, 206, 196), 0.55 * wax)
    wet_h = spectral(rng, 2.4, low=6, high=50) * 3.0
    dermis = relit(dermis, wet_h, 1.0, 0.85)
    _, spec = shade(wet_h, 1.6)
    dermis = dermis + (spec ** 60)[..., None] * 0.45  # glossy, wet

    # Peeling epidermis: sheets where the field says so, more at the rim.
    sheet_f = rank(spectral(rng, 2.8, low=3, high=24) + 0.9 * (1 - depth))
    sheet = smooth(0.7, 0.72, sheet_f)
    wrinkle = spectral(rng, 1.6, low=20, high=90, stretch=(1.0, 2.0))
    skin_c = palette(
        norm(wrinkle) * 0.5 + 0.5 * norm(sheet_f),
        [(0, (214, 190, 170)), (0.5, (230, 214, 196)), (1, (240, 230, 214))],
    )
    skin_c = relit(skin_c, wrinkle * 1.2, 0.8, 0.8)
    # the rolled edge: a lighter lip, a dark shadow line on the dermis
    lip, _ = edge_band(sheet, 5)
    skin_c = mix(skin_c, rgb(250, 246, 236), 0.6 * lip)
    shadow = np.clip(wrap_blur(sheet, 2.5) - sheet, 0, 1)
    dermis = dermis * (1 - 0.45 * wrap_blur(smooth(0, 0.35, shadow), 1.2))[..., None]

    color = mix(dermis, skin_c, sheet)

    # Intact blisters: rounded domes of yellowish fluid under thin skin,
    # in the shallow part of the region.
    f1, f2, _ = cells(rng, 34)
    radius = 12 + 14 * norm(spectral(rng, 2.0, low=4, high=30))
    dome = np.clip(1 - f1 / radius, 0, 1)
    keep = smooth(0.15, 0.4, 1 - depth) * smooth(0.3, 0.5, norm(spectral(rng, 2.5, low=3, high=20)))
    dome = dome * (keep > 0.4)
    blister = dome > 0
    height = np.sqrt(np.clip(dome, 0, 1))
    _, bspec = shade(height * 14, 1.0)
    fluid = mix(rgb(228, 196, 150), rgb(246, 228, 196), height)
    fluid = fluid * (0.8 + 0.25 * height)[..., None] + (bspec ** 40)[..., None] * 0.9
    ring = smooth(0.0, 0.2, dome) * (1 - smooth(0.2, 0.45, dome))
    fluid = mix(fluid, rgb(200, 90, 80), 0.6 * ring)  # red base around each
    color = mix(color, fluid, smooth(0, 0.08, dome) * blister)

    alpha = region
    return color, alpha


def eschar(rng, depth, cover):
    """Stage 3 (full thickness): dry leathery dead skin, pearly white,
    parchment tan and mahogany brown, clotted veins showing as dark lines;
    a rim of raw red where it meets the living skin."""
    region = smooth(-0.02, 0.02, depth - cover)
    t = norm(0.55 * spectral(rng, 2.6, low=3, high=40) + 0.45 * (depth - cover) * 3)
    color = palette(
        t,
        [
            (0.0, (238, 230, 214)),  # pearly / waxy white
            (0.28, (222, 204, 168)),  # parchment
            (0.5, (196, 160, 112)),  # tan
            (0.72, (150, 96, 58)),  # light mahogany
            (1.0, (104, 58, 36)),  # mahogany brown
        ],
    )
    # Clotted vessels: branching dark lines (ridges of a noise).
    veins = np.zeros((N, N))
    for scale in (24, 60):
        n = spectral(rng, 2.0, low=scale / 4, high=scale)
        veins = np.maximum(veins, 1 - smooth(0.0, 0.09, np.abs(n) / 3))
    veins *= smooth(0.2, 0.7, norm(spectral(rng, 2.5, low=2, high=12)))
    color = mix(color, rgb(84, 34, 38), 0.65 * veins)
    # Leather: fine wrinkles, matte.
    leather = spectral(rng, 1.6, low=30, high=110, stretch=(1.6, 1.0))
    bumps = spectral(rng, 2.6, low=4, high=30)
    color = relit(color, leather * 0.8 + bumps * 3.0, 0.7, 0.8)
    # The living rim: raw red and a little peeled skin.
    rim, _ = edge_band(region, 7)
    color = mix(color, rgb(182, 64, 60), 0.75 * rim)
    return color, region


def char(rng, depth, cover):
    """Stage 4: charred black, dull ash on raised plates, split by cracks
    that show yellow fat and dark red flesh; brown where the char thins."""
    region = smooth(-0.02, 0.02, depth - cover)
    d = np.clip((depth - cover) / (1 - cover), 0, 1)
    f1, f2, idx = cells(rng, 140, stretch=(1, 1))
    # crack walls, jittered (crooked)
    jx = spectral(rng, 1.6, low=10, high=80) * 2.2
    jy = spectral(rng, 1.6, low=10, high=80) * 2.2
    walls = warp(f2 - f1, jx, jy)
    width = 1.2 + 3.5 * smooth(0.2, 1.0, d) * norm(spectral(rng, 2.0, low=4, high=30))
    crack = 1 - smooth(0.0, 1.0, walls / width)
    crack *= smooth(0.1, 0.35, d)  # no cracks at the thin edge
    # plates: each cell slightly different (some greyer, some browner)
    plate_rng = np.random.default_rng(int(rng.integers(1 << 30)))
    tone = plate_rng.random(140)[idx]
    rough = spectral(rng, 1.6, low=30, high=120)
    blob = spectral(rng, 2.4, low=6, high=40)
    base = palette(
        0.5 * tone + 0.3 * norm(blob) + 0.2 * norm(rough),
        [(0, (14, 12, 12)), (0.45, (28, 22, 20)), (0.75, (46, 36, 30)), (1, (70, 62, 58))],
    )
    # ash sheen on the raised middle of a plate
    middle = smooth(0.3, 1.0, np.clip(walls / 10, 0, 1))
    base = mix(base, rgb(104, 98, 94), 0.25 * middle * smooth(0.55, 1, norm(rough)))
    # thin char at the edge: brown, singed
    thin = 1 - smooth(0.0, 0.35, d)
    base = mix(base, rgb(74, 42, 26), 0.75 * thin)
    height = -crack * 3 + blob * 2.0 + rough * 0.5
    base = relit(base, height, 1.0, 0.65)
    _, spec = shade(height, 2.0)
    base = base + (spec ** 25)[..., None] * 0.08  # a dull, greasy sheen
    # inside the cracks: yellow fat, dark red flesh, black at the bottom
    inner_t = norm(spectral(rng, 2.0, low=6, high=50))
    inner = palette(inner_t, [(0, (34, 12, 10)), (0.4, (104, 28, 24)), (0.75, (150, 70, 44)), (1, (196, 160, 100))])
    core = smooth(0.4, 1.0, crack)
    color = mix(base, inner * (0.55 + 0.45 * core)[..., None], smooth(0.2, 0.7, crack))
    return color, region


# ---------------------------------------------------------------------------
# The sets
# ---------------------------------------------------------------------------

# Depth thresholds: stage k covers depth > COVER[k] (share of the tile).
SKIN_COVER = {2: 0.08, 3: 0.26, 4: 0.38}


def skin_set(seed):
    rng = np.random.default_rng(seed)
    depth = depth_map(rng)
    save("skin_1.png", *erythema(rng, depth))
    save("skin_2.png", *blisters(rng, depth, SKIN_COVER[2]))
    save("skin_3.png", *eschar(rng, depth, SKIN_COVER[3]))
    save("skin_4.png", *char(rng, depth, SKIN_COVER[4]))
    return depth


def weave(n=N, period=5.0):
    """Woven threads: a fine over / under pattern (seamless: 512 / period
    whole threads)."""
    count = round(n / period)
    py, px = np.mgrid[0:n, 0:n] / n * count * 2 * np.pi
    warp_t = np.sin(px) * 0.5 + 0.5
    weft_t = np.sin(py) * 0.5 + 0.5
    over = (np.sin(px / 2) * np.sin(py / 2)) > 0
    return np.where(over, warp_t, weft_t)


def frayed_edge(rng, region_f, cover, fibre_len=6):
    """A mask cut along `region_f > cover` with frayed fibres along it."""
    fibres = spectral(rng, 0.8, low=80, high=256, stretch=(1, 3)) * 0.02
    fibres2 = spectral(rng, 0.8, low=80, high=256, stretch=(3, 1)) * 0.02
    return smooth(-0.015, 0.015, region_f - cover + fibres + fibres2)


def cloth_set(seed):
    """Over clothes. Opaque where the cloth is charred or gone (the skin
    seen through a hole is painted in), see-through elsewhere."""
    rng = np.random.default_rng(seed)
    depth = depth_map(rng)
    thread = weave()
    grain = norm(spectral(rng, 1.4, low=20, high=200))
    skin_rng = np.random.default_rng(seed + 1)
    skin_depth = depth  # (the skin under the cloth burns where the cloth does)
    s2c, _ = blisters(skin_rng, skin_depth, 0.0)
    s3c, _ = eschar(skin_rng, skin_depth, 0.0)
    s4c, _ = char(skin_rng, skin_depth, 0.0)
    s1c, _ = erythema(skin_rng, skin_depth)

    # 1: singed: the cloth browns (yellow-brown to dark brown), patchy.
    t = norm(depth + 0.25 * spectral(rng, 2.0, low=6, high=60))
    singe = palette(t, [(0, (150, 112, 62)), (0.5, (118, 78, 40)), (1, (70, 42, 22))])
    singe = singe * (0.85 + 0.15 * thread)[..., None]
    alpha1 = 0.15 + 0.6 * smooth(0.05, 0.95, t)
    alpha1 *= 0.8 + 0.2 * thread
    save("cloth_1.png", singe, alpha1)

    def charred_cloth(cover_char, cover_hole, skin_color):
        # charred cloth: black, weave still visible, ash grey where thin
        black = palette(
            norm(grain + 0.6 * spectral(rng, 2.0, low=6, high=50)),
            [(0, (16, 14, 13)), (0.5, (30, 26, 24)), (0.85, (58, 54, 52)), (1, (96, 92, 88))],
        )
        black = black * (0.7 + 0.45 * thread)[..., None]
        charred = frayed_edge(rng, depth, cover_char)
        hole = frayed_edge(rng, depth, cover_hole)
        # brown singe around the charred ring
        ring = smooth(cover_char - 0.18, cover_char, depth) * (1 - charred)
        brown = palette(norm(grain), [(0, (96, 60, 30)), (1, (60, 36, 18))]) * (0.85 + 0.15 * thread)[..., None]
        # curled hole edge: a lighter ash lip
        lip, _ = edge_band(1 - hole, 3)
        black = mix(black, rgb(110, 104, 98), 0.5 * lip)
        # the skin seen through the hole, a shadow along the edge
        inner_shadow = np.clip(wrap_blur(1 - hole, 2.5) - (1 - hole), 0, 1)
        skin = skin_color * (1 - 0.85 * smooth(0, 0.4, inner_shadow))[..., None]
        color = mix(mix(brown, black, charred), skin, hole)
        alpha = np.maximum(np.maximum(charred, hole), 0.7 * ring)
        return color, alpha

    save("cloth_2.png", *charred_cloth(0.3, 0.55, mix(s2c, s1c, 0.25)))
    save("cloth_3.png", *charred_cloth(0.12, 0.3, mix(s3c, s2c, smooth(0.6, 0.3, depth))))
    # 4: burnt into the skin: char, with scraps of fused cloth on it
    color, alpha = char(np.random.default_rng(seed + 2), depth, 0.0)
    scraps = smooth(0.62, 0.66, rank(spectral(rng, 2.4, low=5, high=50)))
    fused = palette(norm(grain), [(0, (10, 9, 9)), (1, (38, 34, 32))]) * (0.75 + 0.35 * thread)[..., None]
    _, spec = shade(spectral(rng, 2.0, low=8, high=60) * 2, 1.0)
    fused = fused + (spec ** 20)[..., None] * 0.25  # melted: glossy
    color = mix(color, fused, scraps)
    alpha = np.maximum(smooth(-0.02, 0.02, depth - 0.06), 0)
    save("cloth_4.png", color, alpha)


def acid_set(seed):
    """Acid runs DOWN: the depth map is stretched vertically, with drips."""
    rng = np.random.default_rng(seed)
    big = spectral(rng, 3.4, low=1.5, high=10, stretch=(0.55, 1.0))
    mid = spectral(rng, 2.6, low=4, high=40, stretch=(0.45, 1.0))
    runs = spectral(rng, 1.8, low=6, high=90, stretch=(0.18, 1.2))
    depth = rank(big + 0.35 * mid + 0.35 * runs)

    # 1: chemical erythema, yellow-brown staining.
    t = norm(depth + 0.3 * spectral(rng, 2.0, low=6, high=60))
    stain = palette(t, [(0, (196, 128, 92)), (0.5, (184, 124, 66)), (1, (150, 92, 44))])
    alpha = 0.25 + 0.45 * smooth(0.1, 1.0, t)
    save("acid_1.png", stain, alpha)

    # 2: eroded: yellow-grey wet slough, raw pink-red pits, raised pale rim.
    cover = 0.3
    region = smooth(-0.02, 0.02, depth - cover)
    slough_t = norm(spectral(rng, 2.6, low=3, high=40, stretch=(0.5, 1)))
    slough = palette(slough_t, [(0, (214, 196, 140)), (0.5, (196, 172, 110)), (1, (164, 132, 78))])
    pits = smooth(0.66, 0.7, rank(spectral(rng, 2.8, low=3, high=30) + 1.2 * depth))
    raw = palette(norm(spectral(rng, 2.4, low=4, high=40)), [(0, (190, 84, 72)), (1, (150, 56, 50))])
    h = spectral(rng, 2.4, low=5, high=60, stretch=(0.5, 1.0)) * 2 - wrap_blur(pits, 3) * 6
    color = mix(slough, raw, pits)
    color = relit(color, h, 0.8, 0.8)
    _, spec = shade(h, 1.4)
    color = color + (spec ** 60)[..., None] * 0.4  # wet
    rim, _ = edge_band(region, 5)
    color = mix(color, rgb(232, 220, 196), 0.55 * rim)  # whitened, eroded edge
    save("acid_2.png", color, region)

    # 3: deep: brown-black leathery eschar, a ragged slough rim.
    cover = 0.45
    region = smooth(-0.02, 0.02, depth - cover)
    d = np.clip((depth - cover) / (1 - cover), 0, 1)
    tone = norm(spectral(rng, 2.6, low=3, high=30) + 1.2 * d)
    esch = palette(tone, [(0, (120, 76, 40)), (0.4, (80, 46, 26)), (0.75, (48, 28, 18)), (1, (26, 16, 12))])
    leather = spectral(rng, 1.6, low=30, high=110, stretch=(1.4, 1.0))
    h = leather * 0.8 + spectral(rng, 2.6, low=4, high=30) * 3.0
    esch = relit(esch, h, 0.8, 0.75)
    _, spec = shade(h, 2.0)
    esch = esch + (spec ** 30)[..., None] * 0.18
    rim, _ = edge_band(region, 9)
    esch = mix(esch, rgb(206, 182, 120), 0.7 * rim)  # yellow slough lip
    save("acid_3.png", esch, region)


def spot(seed, n=N):
    """One laser burn, centred, content within the central 40 %:
    charred core, white coagulated ring, tan eschar, peeled red skin with
    scraps of white epidermis, a soft red halo."""
    rng = np.random.default_rng(seed)
    py, px = (np.mgrid[0:n, 0:n] - n / 2 + 0.5) / (n * 0.2)  # 1 = the 40 % edge
    ang = np.arctan2(py, px)
    r = np.sqrt(px * px + py * py)
    # ragged radius
    wob = np.zeros_like(r)
    for k, a in ((2, 0.1), (3, 0.08), (5, 0.05), (9, 0.03), (17, 0.015)):
        wob += a * np.sin(k * ang + rng.uniform(0, 6.28))
    jag = spectral(rng, 1.4, low=20, high=200, n=n) * 0.02
    rr = r * (1 + wob) + jag
    # each ring its own ragged line (not a target), the core off centre
    def ring_r(amount):
        return rr + spectral(rng, 2.2, low=2, high=24, n=n) * amount

    halo = 1 - smooth(0.55, 1.0, ring_r(0.05))
    peeled = 1 - smooth(0.8, 0.83, ring_r(0.07))
    esch = 1 - smooth(0.6, 0.63, ring_r(0.07))
    white = 1 - smooth(0.42, 0.45, ring_r(0.06) + 0.08 * (px * 0.6 + py * 0.3))
    core = 1 - smooth(0.24, 0.3, ring_r(0.05) + 0.1 * (px * 0.5 - py * 0.4))

    red = palette(norm(spectral(rng, 2.0, low=6, high=60, n=n)), [(0, (210, 100, 90)), (1, (178, 60, 58))])
    color = red.copy()
    alpha = 0.7 * halo
    # peeled ring: wet dermis + white scraps
    scraps = smooth(0.66, 0.7, rank(spectral(rng, 2.0, low=20, high=120, n=n)))
    wet = palette(norm(spectral(rng, 2.0, low=10, high=90, n=n)), [(0, (226, 120, 110)), (1, (196, 72, 72))])
    h = spectral(rng, 1.8, low=16, high=150, n=n)
    _, spec = shade(h, 2.4)
    wet = wet + (spec ** 30)[..., None] * 0.5
    ring = mix(wet, rgb(238, 230, 214), scraps)
    color = mix(color, ring, peeled)
    alpha = np.maximum(alpha, peeled)
    # eschar ring: tan to brown, towards the middle
    tan = palette(np.clip((0.63 - rr) / 0.2, 0, 1), [(0, (204, 170, 120)), (1, (128, 76, 44))])
    tan = relit(tan, spectral(rng, 1.1, low=50, high=200, n=n), 1.5, 0.6)
    color = mix(color, tan, esch)
    # white coagulated ring
    pearl = palette(norm(spectral(rng, 2.0, low=20, high=120, n=n)), [(0, (232, 222, 204)), (1, (248, 242, 230))])
    color = mix(color, pearl, white)
    # charred crater, cracked
    f1, f2, _ = cells(rng, 40, n=n)
    crack = 1 - smooth(0, 2.0, f2 - f1)
    crater = palette(norm(spectral(rng, 1.6, low=10, high=100, n=n)), [(0, (12, 10, 10)), (1, (52, 44, 40))])
    crater = mix(crater, rgb(120, 36, 28), 0.5 * crack * smooth(0.2, 0.0, rr))
    hc = -r * 3 + spectral(rng, 1.6, low=10, high=100, n=n) * 0.6
    crater = relit(crater, hc, 2.0, 0.5)
    color = mix(color, crater, core)
    alpha *= smooth(1.05, 0.95, r)  # (nothing past the 40 %)
    save("spot.png", color, alpha)


def flame_sheet(seed, frame=256, grid=4):
    """16 frames of one flame tongue rising and breaking up: a teardrop of
    turbulent fire, brightest low in the core, licks tearing off the tip.
    Grey (luminance and alpha): the game tints it orange."""
    rng = np.random.default_rng(seed)
    n = frame
    sheet = np.zeros((n * grid, n * grid, 4))
    big = spectral(rng, 2.2, low=2, high=40, n=n * 2)  # turbulence, scrolled up
    fine = spectral(rng, 2.0, low=6, high=40, n=n * 2)
    py, px = np.mgrid[0:n, 0:n] / n
    for i in range(grid * grid):
        t = i / (grid * grid)
        shift = int(t * n * 1.6)
        tb = np.roll(big, shift, axis=0)[:n, :n]
        tf = np.roll(fine, int(shift * 1.7), axis=0)[:n, :n]
        # height: 0 at the bottom, 1 at the top
        y = 1 - py
        x = px - 0.5 + tb * 0.05 * (0.3 + y)
        # life: grows in, then shrinks and lifts (a one-shot)
        reach = 0.82 + 0.1 * np.sin(t * np.pi)
        base = 0.08 + 0.12 * t  # the flame lifts off the bottom as it dies
        width = 0.2 * (1 - smooth(0.0, reach, y)) ** 0.75 * smooth(base - 0.08, base + 0.08, y)
        width = width * (1.0 - 0.45 * t)
        body = smooth(0.0, 0.05, width - np.abs(x) + tf * 0.025 + tb * 0.03)
        # tearing licks at the tip
        tear = smooth(0.15, 0.6, tf + 0.4 * tb + (y - reach * 0.6) * 1.5)
        body = body * (1 - 0.8 * tear * smooth(0.4, 0.9, y))
        core = smooth(0.0, 0.08, width * 0.55 - np.abs(x)) * (1 - smooth(0.15, 0.55, y))
        lum = 0.55 + 0.45 * core + 0.15 * tf
        lum *= 1 - 0.4 * smooth(0.5, 1.0, y)  # darker, redder up the tongue
        alpha = body * (0.75 + 0.25 * core)
        alpha = ndimage.gaussian_filter(alpha, 1.8)
        lum = ndimage.gaussian_filter(lum, 1.5)
        # (padding: nothing within 4 px of a frame's border, mip bleed)
        pad = np.ones((n, n))
        pad[:4, :] = pad[-4:, :] = pad[:, :4] = pad[:, -4:] = 0
        alpha *= ndimage.gaussian_filter(pad, 2)
        r, c = divmod(i, grid)
        sheet[r * n : (r + 1) * n, c * n : (c + 1) * n, :3] = np.clip(lum, 0, 1)[..., None]
        sheet[r * n : (r + 1) * n, c * n : (c + 1) * n, 3] = np.clip(alpha, 0, 1)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((sheet * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, "flame.png"))
    print("wrote", os.path.join(OUT, "flame.png"))


def smoke_puff(seed, n=N):
    """A soft, billowing smoke puff: lumpy edge, denser lumps inside."""
    rng = np.random.default_rng(seed)
    py, px = (np.mgrid[0:n, 0:n] - n / 2 + 0.5) / (n / 2)
    r = np.sqrt(px * px + py * py)
    billow = norm(spectral(rng, 2.4, low=2, high=30, n=n))
    detail = norm(spectral(rng, 1.6, low=10, high=120, n=n))
    edge = r + 0.35 * (billow - 0.5) + 0.12 * (detail - 0.5)
    alpha = 1 - smooth(0.35, 0.9, edge)
    alpha *= 0.55 + 0.45 * billow
    lum = 0.55 + 0.35 * billow + 0.1 * detail  # lit lumps
    alpha *= smooth(1.0, 0.85, r)
    save("smoke.png", np.repeat(lum[..., None], 3, -1), alpha)


def ember(n=64):
    py, px = (np.mgrid[0:n, 0:n] - n / 2 + 0.5) / (n / 2)
    r = np.sqrt((px * 2.2) ** 2 + (py * 0.9) ** 2)  # a short streak
    alpha = np.exp(-(r**2) * 5)
    lum = np.clip(0.6 + 0.4 * np.exp(-(r**2) * 14), 0, 1)
    save("ember.png", np.repeat(lum[..., None], 3, -1), alpha)


if __name__ == "__main__":
    skin_set(11)
    cloth_set(23)
    acid_set(37)
    spot(41)
    flame_sheet(53)
    smoke_puff(67)
    ember()
