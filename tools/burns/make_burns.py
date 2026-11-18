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
    """Stage 2 (partial thickness). Three zones from the rim inward:
    intact but swollen red skin with a few fluid blisters; a band of dead
    epidermis coming loose (grey-white, wrinkled, torn edge, curling);
    the denuded dermis in the middle (raw red, wet, glistening, mottled).
    Never fully uniform: the deeper the depth map, the rawer."""
    region = smooth(-0.02, 0.02, depth - cover)
    raw_at = cover + 0.16  # the skin is off past this depth
    jag = spectral(rng, 1.8, low=12, high=90) * 0.012
    denuded = smooth(-0.006, 0.006, depth - raw_at + jag)

    # Intact zone: swollen erythema under a dull, tight epidermis.
    mott = norm(spectral(rng, 2.2, low=5, high=70))
    intact = palette(mott, [(0, (198, 104, 88)), (0.6, (184, 80, 70)), (1, (164, 62, 58))])
    intact_alpha = 0.62 + 0.18 * mott

    # The dermis: red, not pink; paler punctate spots, darker deep patches.
    deep = norm(spectral(rng, 2.6, low=3, high=30) + 2.2 * (depth - raw_at))
    dermis = palette(
        deep,
        [(0, (206, 104, 92)), (0.4, (190, 76, 70)), (0.75, (164, 54, 54)), (1, (132, 38, 42))],
    )
    punct = smooth(0.78, 0.95, norm(spectral(rng, 0.9, low=60, high=240)))
    dermis = mix(dermis, rgb(206, 124, 110), 0.25 * wrap_blur(punct, 1.0))
    # deep partial thickness: waxy pale, poorly perfused islands
    wax = smooth(0.78, 0.92, deep + 0.15 * spectral(rng, 1.6, low=8, high=60))
    dermis = mix(dermis, rgb(214, 170, 156), 0.35 * wax)
    # wet: a fine film (small highlights), barely any relief
    film = spectral(rng, 1.8, low=20, high=160)
    dermis = relit(dermis, film * 0.7, 0.6, 0.9)
    _, spec = shade(film * 1.2 + spectral(rng, 2.6, low=3, high=24) * 2.0, 1.4)
    dermis = dermis + wrap_blur((spec**90), 0.7)[..., None] * 0.3

    # Peeling epidermis: a band along the denuded edge (the dead skin rolls
    # back from it), wider in places, plus a few torn flaps lying on it.
    band_w = 0.05 + 0.06 * norm(spectral(rng, 2.4, low=3, high=18))
    band = smooth(-0.004, 0.004, depth - (raw_at - band_w) + jag) * (1 - denuded)
    flap_f = rank(spectral(rng, 2.6, low=4, high=40))
    flaps = smooth(0.9, 0.905, flap_f) * denuded * smooth(0.0, 0.05, raw_at + 0.1 - depth)
    sheet = np.clip(band + flaps, 0, 1)
    wrinkle = spectral(rng, 1.4, low=30, high=160, stretch=(1.0, 2.4))
    sheet_c = palette(
        norm(wrinkle + 0.5 * spectral(rng, 2.0, low=6, high=40)),
        [(0, (176, 150, 136)), (0.5, (204, 186, 172)), (1, (226, 214, 202))],
    )
    sheet_c = relit(sheet_c, wrinkle * 1.6, 0.7, 0.75)
    # the torn edge curls up: a lighter lip, a thin shadow on the dermis
    lip, _ = edge_band(sheet, 3)
    sheet_c = mix(sheet_c, rgb(236, 228, 218), 0.5 * lip)
    shadow = np.clip(wrap_blur(sheet, 2.0) - sheet, 0, 1)
    dermis = dermis * (1 - 0.55 * smooth(0, 0.3, shadow))[..., None]

    color = mix(mix(intact, dermis, denuded), sheet_c, sheet)
    alpha = np.maximum(intact_alpha * (1 - denuded), denuded)
    alpha = np.maximum(alpha, 0.92 * sheet)

    # Intact blisters: a few flat domes of straw fluid under thin skin, in
    # the intact zone near the edge of the raw area.
    f1, _, _ = cells(rng, 22)
    radius = 10 + 18 * norm(spectral(rng, 2.0, low=3, high=20))
    dome = np.clip(1 - f1 / radius, 0, 1)
    near = smooth(cover + 0.03, cover + 0.08, depth) * (1 - smooth(raw_at - 0.07, raw_at - 0.04, depth))
    dome = dome * (near > 0.5) * (norm(spectral(rng, 2.0, low=3, high=12)) > 0.4)
    height = np.sqrt(dome)
    _, bspec = shade(height * 10, 1.0)
    fluid = mix(rgb(206, 156, 116), rgb(232, 204, 160), height)
    fluid = fluid + (bspec**60)[..., None] * 0.7
    cover_d = smooth(0, 0.12, dome)
    color = mix(color, fluid, 0.75 * cover_d)
    alpha = np.maximum(alpha, 0.85 * cover_d)
    return color, alpha * region


def eschar(rng, depth, cover):
    """Stage 3 (full thickness): dry, matte, leathery dead skin, mostly
    waxy grey-white to parchment tan, mottled mahogany where deeper,
    thrombosed vessels showing as dark branching lines under it; a thin
    raw red rim where it meets the partial-thickness burn."""
    jag = spectral(rng, 1.3, low=24, high=180) * 0.012
    region = smooth(-0.006, 0.006, depth - cover + jag)
    d = np.clip((depth - cover) / (1 - cover), 0, 1)
    t = norm(0.45 * spectral(rng, 2.8, low=2, high=24) + 0.3 * spectral(rng, 1.8, low=10, high=80) + 1.0 * d)
    color = palette(
        t,
        [
            (0.0, (216, 208, 196)),  # waxy white-grey
            (0.4, (208, 192, 168)),  # parchment
            (0.7, (190, 160, 124)),  # tan leather
            (0.9, (156, 112, 80)),  # light mahogany
            (1.0, (122, 76, 56)),  # mahogany
        ],
    )
    # Thrombosed vessels: a few branching dark lines (ridges of low noise).
    veins = np.zeros((N, N))
    for low, high, w in ((2, 8, 0.05), (5, 18, 0.035)):
        n = spectral(rng, 2.4, low=low, high=high)
        n = n + 0.15 * spectral(rng, 1.4, low=30, high=120)
        veins = np.maximum(veins, 1 - smooth(0.0, w, np.abs(n) / 3))
    veins *= smooth(0.35, 0.75, norm(spectral(rng, 2.5, low=2, high=10)))
    veins = wrap_blur(veins, 0.8)
    color = mix(color, rgb(74, 40, 46), 0.55 * veins)
    # Leather: fine dry wrinkles, a few shallow fissures, matte.
    leather = spectral(rng, 1.4, low=40, high=200, stretch=(1.8, 1.0))
    f1, f2, _ = cells(rng, 30)
    fissure = 1 - smooth(0.0, 1.6, f2 - f1)
    fissure *= smooth(0.5, 0.8, norm(spectral(rng, 2.2, low=3, high=16))) * smooth(0.2, 0.6, d)
    color = mix(color, rgb(120, 66, 52), 0.6 * fissure)
    color = relit(color, leather * 0.7 + spectral(rng, 2.6, low=3, high=24) * 1.5 - fissure * 2, 0.6, 0.82)
    # The living rim: a thin raw red line, a little dead skin.
    rim, _ = edge_band(region, 5)
    color = mix(color, rgb(168, 60, 56), 0.7 * rim)
    return color, region


def char(rng, depth, cover):
    """Stage 4: charred black, dull ash on raised plates, split by cracks
    that show dark red flesh and a little yellow fat; a sooty brown scorch
    spreading past the char (half see-through) so it never ends sharp."""
    jag = spectral(rng, 1.3, low=24, high=180) * 0.014
    region = smooth(-0.006, 0.006, depth - cover + jag)
    scorch = smooth(cover - 0.16, cover, depth + jag) * (1 - region)
    d = np.clip((depth - cover) / (1 - cover), 0, 1)
    f1, f2, idx = cells(rng, 140, stretch=(1, 1))
    jx = spectral(rng, 1.6, low=10, high=80) * 2.2
    jy = spectral(rng, 1.6, low=10, high=80) * 2.2
    walls = warp(f2 - f1, jx, jy)
    width = 1.0 + 3.0 * smooth(0.2, 1.0, d) * norm(spectral(rng, 2.0, low=4, high=30))
    crack = 1 - smooth(0.0, 1.0, walls / width)
    crack *= smooth(0.08, 0.3, d)
    plate_rng = np.random.default_rng(int(rng.integers(1 << 30)))
    tone = plate_rng.random(140)[idx]
    rough = spectral(rng, 1.6, low=30, high=120)
    blob = spectral(rng, 2.4, low=6, high=40)
    base = palette(
        0.45 * tone + 0.35 * norm(blob) + 0.2 * norm(rough),
        [(0, (12, 11, 11)), (0.45, (24, 20, 19)), (0.75, (40, 33, 29)), (1, (64, 58, 54))],
    )
    middle = smooth(0.3, 1.0, np.clip(walls / 10, 0, 1))
    base = mix(base, rgb(98, 94, 90), 0.22 * middle * smooth(0.55, 1, norm(rough)))
    thin = 1 - smooth(0.0, 0.25, d)
    base = mix(base, rgb(70, 42, 28), 0.7 * thin)
    height = -crack * 3 + blob * 2.0 + rough * 0.5
    base = relit(base, height, 1.0, 0.65)
    _, spec = shade(height, 2.0)
    base = base + (spec**25)[..., None] * 0.07
    inner_t = norm(spectral(rng, 2.0, low=6, high=50))
    inner = palette(inner_t, [(0, (30, 10, 9)), (0.5, (92, 24, 20)), (0.85, (128, 50, 34)), (1, (176, 140, 90))])
    core = smooth(0.4, 1.0, crack)
    color = mix(base, inner * (0.5 + 0.5 * core)[..., None], smooth(0.25, 0.75, crack))
    # the scorch past it: soot over the eschar, darker toward the char
    soot = palette(norm(spectral(rng, 2.0, low=8, high=80)), [(0, (46, 32, 26)), (1, (78, 52, 36))])
    color = mix(soot, color, region)
    alpha = np.maximum(region, 0.7 * scorch * (0.75 + 0.25 * norm(rough)))
    return color, alpha


# ---------------------------------------------------------------------------
# The sets
# ---------------------------------------------------------------------------

# Depth thresholds: stage k covers depth > COVER[k] (share of the tile).
# Each deeper stage covers most of the one before (a limb burnt to a stage
# is mostly that stage, with the shallower ones showing between).
SKIN_COVER = {2: 0.06, 3: 0.16, 4: 0.3}


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
        # greyish dead skin just inside the burnt edge
        dead, _ = edge_band(hole, 7)
        skin = mix(skin_color, rgb(168, 150, 138), 0.45 * dead)
        skin = skin * (1 - 0.85 * smooth(0, 0.4, inner_shadow))[..., None]
        color = mix(mix(brown, black, charred), skin, hole)
        alpha = np.maximum(np.maximum(charred, hole), 0.7 * ring)
        return color, alpha

    # (the skin in cloth_2's holes: a partial-thickness wound bed, not a
    # flat red: swollen red skin and blisters at the hole's edge, peeling
    # grey-white dead skin, the wet raw dermis in the middle)
    bed, _ = blisters(np.random.default_rng(seed + 5), skin_depth, 0.5)
    save("cloth_2.png", *charred_cloth(0.3, 0.55, bed))
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


def drips(rng, count, n=N):
    """Periodic run-down streaks: each starts at a random point and runs
    straight down a random length, thinning and fading as it goes (acid
    trickling down the skin). 1 on a streak, 0 elsewhere."""
    out = np.zeros((n, n))
    py, px = np.mgrid[0:n, 0:n]
    for _ in range(count):
        x0, y0 = rng.random() * n, rng.random() * n
        length = n * (0.15 + 0.45 * rng.random())
        width = 5 + 12 * rng.random()
        dy = (py - y0) % n  # (below the start, wrapping)
        t = dy / length
        wobble = 4 * np.sin(dy / (18 + 20 * rng.random()) + rng.random() * 6)
        dx = np.abs(((px - x0 - wobble + n / 2) % n) - n / 2)
        w = width * (1 - 0.7 * t)
        streak = np.clip(1 - dx / np.maximum(w, 0.5), 0, 1) * np.clip(1 - t, 0, 1) ** 0.6
        out = np.maximum(out, streak)
    return wrap_blur(out, 1.2)


def acid_set(seed):
    """Acid runs DOWN: the depth map is made of tall blobs and drip
    streaks. (spectral's `stretch` (y, x) > 1 on an axis damps change
    along it: features get long on that axis; low = 1 so the one-cycle
    terms along x are kept, else the tile turns into horizontal bands.)"""
    rng = np.random.default_rng(seed)
    big = spectral(rng, 3.4, low=1.0, high=10, stretch=(1.4, 1.0))
    mid = spectral(rng, 2.6, low=1.0, high=40, stretch=(1.7, 1.0))
    runs = spectral(rng, 1.8, low=1.0, high=90, stretch=(4.0, 0.9))
    streaks = drips(rng, 22)
    depth = rank(big + 0.35 * mid + 0.25 * runs + 2.2 * streaks)
    # eroded, ragged edges: a coarse bite plus fine fraying
    jag = spectral(rng, 1.6, low=8, high=60) * 0.03 + spectral(rng, 1.0, low=40, high=220) * 0.012

    # 1: chemical erythema with yellow-brown staining (the acid's colour
    # soaked into the skin), streaked downward, darker tide marks where
    # it dried at the edge of the wet area.
    t = norm(depth + 0.3 * spectral(rng, 2.0, low=1.0, high=60, stretch=(2.4, 1.0)))
    stain = palette(
        t,
        [(0, (200, 116, 88)), (0.35, (190, 132, 70)), (0.7, (168, 120, 48)), (1, (124, 84, 34))],
    )
    wet = smooth(0.35, 0.45, depth + jag)
    tide, _ = edge_band(wet, 5)
    stain = mix(stain, rgb(112, 76, 32), 0.55 * tide)
    alpha = 0.3 + 0.45 * smooth(0.1, 1.0, t) + 0.2 * tide
    save("acid_1.png", stain, np.clip(alpha, 0, 0.9))

    # 2: eroded: dull yellow-grey / brown slough (coagulated dead skin),
    # raw red where it has come off, pale ragged eroded margins with
    # lifted shreds of skin. Matte-moist.
    cover = 0.3
    region = smooth(-0.006, 0.006, depth - cover + jag)
    slough_t = norm(spectral(rng, 2.6, low=1.0, high=40, stretch=(2.4, 1)) + 1.2 * (depth - cover))
    slough = palette(
        slough_t,
        [(0, (204, 180, 130)), (0.4, (184, 152, 96)), (0.75, (152, 114, 66)), (1, (118, 80, 46))],
    )
    pits = smooth(0.7, 0.72, rank(spectral(rng, 2.8, low=1.0, high=30, stretch=(2.0, 1)) + 0.6 * depth + 1.5 * streaks) + jag)
    raw = palette(norm(spectral(rng, 2.4, low=4, high=40)), [(0, (178, 84, 66)), (1, (130, 50, 44))])
    h = spectral(rng, 1.8, low=10, high=120, stretch=(2.4, 1.0)) * 0.8 - wrap_blur(pits, 2) * 3
    color = mix(slough, raw, pits)
    color = relit(color, h, 0.6, 0.85)
    _, spec = shade(h, 1.2)
    color = color + wrap_blur(spec**50, 0.7)[..., None] * 0.12  # moist, not glossy
    rim, _ = edge_band(region, 6)
    shreds = smooth(0.55, 0.65, norm(spectral(rng, 1.2, low=30, high=200, stretch=(3.0, 1.0))))
    color = mix(color, rgb(222, 208, 176), 0.55 * rim)  # whitened, eroded edge
    color = mix(color, rgb(238, 228, 206), 0.6 * rim * shreds)  # lifted shreds
    save("acid_2.png", color, region)

    # 3: deep: brown-black leathery eschar running down, a ragged
    # yellow-brown slough rim.
    cover = 0.42
    region = smooth(-0.006, 0.006, depth - cover + jag)
    d = np.clip((depth - cover) / (1 - cover), 0, 1)
    tone = norm(spectral(rng, 2.6, low=1.0, high=30, stretch=(2.0, 1.0)) + 1.2 * d)
    esch = palette(tone, [(0, (122, 80, 44)), (0.4, (86, 52, 30)), (0.75, (52, 32, 20)), (1, (30, 19, 14))])
    leather = spectral(rng, 1.4, low=40, high=200, stretch=(1.0, 1.8))
    h = leather * 0.7 + spectral(rng, 2.6, low=4, high=30) * 1.6
    esch = relit(esch, h, 0.7, 0.78)
    _, spec = shade(h, 1.6)
    esch = esch + (spec**30)[..., None] * 0.08
    rim, _ = edge_band(region, 8)
    esch = mix(esch, rgb(176, 148, 92), 0.65 * rim)  # yellow-brown slough lip
    esch = mix(esch, rgb(214, 196, 160), 0.5 * rim * shreds)
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
    """16 frames of one flame tongue's life (a one-shot): it rises from the
    skin, stretches into a tall licking tongue that sways, its tip tears
    off into a wisp, then it shrinks and lifts away. Smooth edges (a real
    flame is a sheet of glowing gas, not a cloud), the brightest at the
    root, dimmer and redder up the tongue. Grey (luminance + alpha): the
    game tints it."""
    rng = np.random.default_rng(seed)
    n = frame
    sheet = np.zeros((n * grid, n * grid, 4))
    # turbulence fields, scrolled up through the frames (wrap: seamless)
    sway = spectral(rng, 3.0, low=1, high=6, n=n * 2)
    edge = spectral(rng, 2.2, low=3, high=18, n=n * 2)
    tear = spectral(rng, 2.6, low=2, high=10, n=n * 2)
    py, px = np.mgrid[0:n, 0:n] / n
    y = 1 - py  # 0 at the bottom, 1 at the top
    count = grid * grid
    for i in range(count):
        t = i / (count - 1)
        shift = int(t * n * 1.2)  # the gas rises
        sw = np.roll(sway, shift, axis=0)[:n, :n]
        ed = np.roll(edge, int(shift * 1.6), axis=0)[:n, :n]
        tr = np.roll(tear, int(shift * 1.3), axis=0)[:n, :n]
        # life: height grows fast, holds, then the flame lifts and shrinks
        height = 0.45 + 0.45 * smooth(0.0, 0.25, t) - 0.25 * smooth(0.6, 1.0, t)
        lift = 0.06 + 0.3 * smooth(0.55, 1.0, t)
        width = 0.15 * (1 - 0.4 * smooth(0.5, 1.0, t))
        # the tongue sways more the higher it is
        x = px - 0.5 - sw * 0.06 * (y - lift).clip(0) / max(height, 0.1)
        h = np.clip((y - lift) / height, -1, 2)
        profile = width * np.clip(1 - h, 0, 1) ** 0.7 * np.sqrt(smooth(0.0, 0.16, h))
        body = smooth(0.0, 0.02, profile - np.abs(x) + ed * 0.012 * (0.3 + h.clip(0, 1)))
        body *= smooth(-0.02, 0.04, h)  # (nothing below the root)
        # the tip tears off: gaps cut across the upper tongue
        gap = smooth(0.25, 0.45, tr + (h - 0.45) * 1.4) * smooth(0.45, 0.7, h)
        body *= 1 - gap
        # a detached wisp above the tongue in the middle of its life
        wisp_h = (y - lift - height * 0.95) / 0.18
        wisp = smooth(-0.01, 0.01, 0.035 * (1 - np.abs(wisp_h - 0.5) * 2).clip(0) - np.abs(x - sw * 0.03))
        wisp *= smooth(0.15, 0.35, t) * (1 - smooth(0.7, 0.9, t))
        alpha = np.maximum(body, 0.7 * wisp)
        core = smooth(-0.01, 0.03, profile * 0.5 - np.abs(x)) * (1 - smooth(0.0, 0.5, h))
        lum = 0.5 + 0.5 * core - 0.25 * smooth(0.3, 1.0, h) + 0.06 * ed
        alpha = ndimage.gaussian_filter(alpha, 1.2)
        alpha *= 0.85 + 0.15 * core
        alpha *= 1 - 0.5 * smooth(0.6, 1.0, t)  # it fades as it dies
        lum = ndimage.gaussian_filter(lum, 1.0)
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
