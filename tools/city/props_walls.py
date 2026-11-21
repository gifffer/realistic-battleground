"""props_walls: the wall and facade detailing of the alleys (code-made, parts only).

Every builder has the same signature:

    build(D, folder, origin, ry, rng, **options) -> number of parts made

    D        a citykit.Data
    folder   the folder path of the parts (e.g. "Alleys/Walls/Detail")
    origin   (x, y, z): for WALL props, the point ON THE WALL FACE at floor level;
             for free-standing ones (fence, background facade, building top...) the floor
             point given in each docstring.
    ry       turn about Y (degrees). For wall props: the local -Z points OUT of the wall
             (ry = 0: a wall whose face looks north, -Z).
    rng      a random.Random: sizes, tilts, wear and colours vary with it.

Local frame (citykit.Frame): +X along the wall (seen from the alley, facing the wall, +X is
on your LEFT), +Y up, -Z out of the wall. Overlays (grime, stains, posters...) are thin DECOR parts
in front of the face, in depth slots shared by every prop on that wall (zlayers: no two layers on
one plane, opaque blended colours where possible, at most 5 layers in one place).

Scale: a character is ~5 studs tall; a floor ~10 studs; a door ~4 x 7.5; 1 stud ~ 0.3 m.
Only built-in materials and colours, no textures / meshes. NO BOTTLES anywhere (nothing that
reads as one either: no tall gas cylinders, no flasks).

Art direction (from environment-art breakdowns and DevForum building advice): never a clean
box; wear follows logic (water runs down from sills, joints and brackets; soot rises from
vents and lamps; dirt and damp climb from the ground; hands grime door handles); frames and
sills stand proud of the wall so it isn't flat; slight irregular tilts; layered, torn,
overlapping surfaces tell that the place has been used for years.

How the parts are kept from z-fighting (the player saw surfaces flicker and show two textures
at once when the camera moves):
  • Stains are MOSAICS, not stacks: one stain is a few pieces that BUTT edge to edge on one
    depth slot (a band, a darker splash strip under it, a moss stretch beside it), and their
    soft, ragged edges are right triangles (wedge parts lying flat on the wall: `tri`), never
    a pile of nested rectangles. Pieces only stack (one slot in front) where something really
    lies on top of something else (a poster on an older poster, a drip on a buffed patch).
  • Assemblies (windows, doors) stand IN FRONT of every overlay slot (deeper than 0.29 out of
    the wall) and are closed on their sides (jambs, sill, lintel), so a stain running down
    the wall passes behind them unseen instead of cutting through their glass.
  • Pieces of one assembly BUTT (a jamb stops under the lintel, a post stops under the rail);
    where two parallel faces of different parts overlap, they are at least 0.06 apart.
  • Small bumps (bolt heads, nails, staples, joints) are balls: no flat face to fight.
  • A flat part fixed on the wall inside the slots' depth (a base plate, a bracket's wall leg)
    is set a few degrees off square (`plate`), or turned corner-on, or its back sunk into the
    wall, so no face of it is parallel to a stain 0.02 away.
  • A stain is never laid behind or through something already standing against the wall (a
    door frame, a breakable board, a cabinet: `_spans`): a band stops beside it, a streak
    stops on top of a unit below it (`_blocked_below`).
  • Where two walls meet, their tops and stains don't cross on one plane: cornice courses run
    on into the crossing wall, coping runs stop short of the one already there, every
    horizontal face of a wall top is kept clear of the others' (D._top_planes), and the damp
    bands stop short of the crossing wall's face.
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from citykit import (  # noqa: E402
    BALL,
    BLOCK,
    CYLINDER,
    DECOR,
    DECOR_SHADOW,
    PROP,
    SMALL,
    SOLID,
    WEDGE,
    Frame,
    jitter,
    mix,
    yxz_angles,
    yxz_matrix,
)
import zlayers  # noqa: E402
import meshprop as MESHPROP  # noqa: E402
from overlay import textfit  # noqa: E402
from meshprop import frame_meshprop, lib_meshprop  # noqa: E402

# ------------------------------------------------------------------ palette (dirty, desaturated)
BRICK = [(84, 60, 50), (96, 64, 52), (68, 49, 42), (80, 44, 36)]
BRICK_PALE = (112, 82, 66)
MORTAR = (112, 106, 96)
SOOT = (34, 31, 29)
DAMP = (40, 36, 32)
WET_DARK = (26, 24, 22)
MOSS = (46, 54, 34)
PLASTER = [(104, 98, 86), (94, 90, 80), (108, 100, 86), (88, 86, 80)]
CONCRETE = (96, 92, 86)
CONCRETE_DARK = (70, 68, 64)
STONE = (126, 120, 108)
EFFLO = (178, 174, 162)
RUST = (89, 47, 30)
RUST_DARK = (59, 29, 19)
RUST_STAIN = (72, 38, 22)
METAL = (58, 62, 64)
METAL_DARK = (40, 40, 40)
GALV = (104, 106, 104)
STEEL_PAINT = [(52, 60, 56), (66, 58, 50), (70, 34, 30), (46, 50, 58), (84, 80, 70)]
WOOD = (104, 87, 60)
WOOD_OLD = (78, 66, 50)
WOOD_DARK = (58, 46, 36)
WOOD_GREY = (98, 94, 86)  # weathered silver-grey timber (old water tanks)
FRAME_PAINT = [(150, 144, 128), (60, 66, 56), (88, 46, 38), (44, 40, 38), (118, 112, 96)]
UPVC = (186, 182, 170)  # yellowed white plastic frames
VOID = (12, 12, 13)
GLASS_DIRTY = [(64, 70, 66), (58, 60, 56), (72, 74, 66)]
PAPER = [(150, 142, 120), (134, 122, 100), (118, 108, 90), (140, 128, 104), (108, 102, 88)]
POSTER_INK = [(118, 44, 38), (40, 54, 70), (150, 120, 60), (60, 70, 52), (30, 28, 28), (96, 58, 84)]
CABLE = (22, 22, 24)
PLASTIC_GREY = (120, 118, 108)
BEIGE = (150, 142, 120)
WARM = (255, 176, 110)
WARM_DIM = (168, 112, 64)
COLD_DIM = (96, 120, 140)
TV_DIM = (84, 104, 150)
WHITE = (180, 180, 170)


# ------------------------------------------------------------------ geometry helpers
def _unit(v):
    v = np.asarray(v, dtype=float)
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


def _beam_matrix(d, side=None):
    """Columns X, Y, Z: Y along d, Z as close to `side` as possible."""
    y = _unit(d)
    s = np.array(side if side is not None else (0, 0, 1), dtype=float)
    z = s - y * np.dot(s, y)
    if np.linalg.norm(z) < 1e-4:
        s = np.array((1, 0, 0), dtype=float)
        z = s - y * np.dot(s, y)
    z = _unit(z)
    x = np.cross(y, z)
    return np.column_stack([x, y, z])


def _rod_matrix(d):
    """Columns X (along d: a cylinder's axis), Y, Z."""
    x = _unit(d)
    ref = np.array((0, 1, 0) if abs(x[1]) < 0.9 else (1, 0, 0), dtype=float)
    y = _unit(ref - x * np.dot(ref, x))
    z = np.cross(x, y)
    return np.column_stack([x, y, z])


def beam(f, name, p0, p1, w, t, color, material, side=None, **kw):
    """A block from local point p0 to p1 (its Y), w wide (its X), t thick (its Z ~ `side`,
    default the wall normal: so in the wall plane w is the visible width)."""
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    m = f.m @ _beam_matrix(p1 - p0, side)
    folder = kw.pop("folder", None) or f.folder
    return f.D.part(folder, name, tuple(f.world((p0 + p1) / 2)), (w, float(np.linalg.norm(p1 - p0)), t),
                    color, material, rot=yxz_angles(m), **kw)


def rod(f, name, p0, p1, d, color, material, shape=CYLINDER, **kw):
    """A cylinder (diameter d) from local p0 to p1."""
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    m = f.m @ _rod_matrix(p1 - p0)
    folder = kw.pop("folder", None) or f.folder
    return f.D.part(folder, name, tuple(f.world((p0 + p1) / 2)), (float(np.linalg.norm(p1 - p0)), d, d),
                    color, material, rot=yxz_angles(m), shape=shape, **kw)


def bend(f, name, pts, d, color, material, joint=None, **kw):
    """A bent tube through local points pts: a cylinder per segment and a ball of the same
    diameter at every inner point (so each bend is round, not a kink or a gap). joint: the
    joints' colour (a socket / bend fitting a shade different), default `color`.
    Returns the number of parts."""
    n = 0
    for a, b in zip(pts, pts[1:]):
        rod(f, name, a, b, d, color, material, **kw)
        n += 1
    for p in pts[1:-1]:
        f.part(name + "Bend", p, (d * 1.04, d * 1.04, d * 1.04), joint or color, material, shape=BALL,
               flags=kw.get("flags", DECOR))
        n += 1
    return n


def bolt(f, name, p, d, color, material="Metal", flags=DECOR):
    """A round head (bolt, rivet, nail, staple) centred on local point p: a ball, so it has no
    flat face to fight with the surface it sits on."""
    return f.part(name, p, (d, d, d), color, material, shape=BALL, flags=flags)


_bolt = bolt  # (for builders whose own `bolt` option hides it)


def _in_plane(sx, sy):
    """Rotation (frame-local) that lays a Roblox wedge flat in the frame's XY plane as a right
    triangle: its thickness along Z, the right angle at the corner (-sx, -sy) of its box, one leg
    along sx * X and the other along sy * Y. (A Roblox wedge: bottom face full, back +Z face full,
    the slope from bottom-front to top-back; so its X becomes Z, its Y becomes sy * Y and its
    -Z becomes sx * X.)"""
    return np.array([[0.0, 0.0, -sx], [0.0, sy, 0.0], [sx * sy, 0.0, 0.0]])


def tri_part(f, name, px, py, a, b, z0, z1, color, material, **kw):
    """A right-triangle plate lying in the wall plane between depths z0 and z1 out of the wall
    (local z = -z0 .. -z1): the right angle at local (px, py), one leg a along X, one leg b along
    Y (signed: a < 0 runs to -X, b < 0 hangs down). A wedge part: glass shards, chipped edges,
    torn paper flaps, a cone's facets."""
    sx, sy = (1 if a >= 0 else -1), (1 if b >= 0 else -1)
    m = f.m @ _in_plane(sx, sy)
    c = f.world((px + a / 2, py + b / 2, -(z0 + z1) / 2))
    folder = kw.pop("folder", None) or f.folder
    return f.D.part(folder, name, tuple(c), (abs(z1 - z0), abs(b), abs(a)), color, material, rot=yxz_angles(m),
                    shape=WEDGE, **kw)


def cone(f, name, cx, y0, cz, r, h, color, material, n=8, flags=DECOR, jit=None, rng=None):
    """A cone (apex up) standing on local (cx, y0, cz), base radius r, height h: n wedges round
    the vertical axis, each with its tall back face on the axis and its slope facing out (the
    facets of a tank roof, a lamp shade). The wedges overlap near the axis, inside the cone,
    and their bottom faces are meant to sit on something (the tank top, a disc): nothing of
    them shows there. jit: colour jitter per facet (rng needed)."""
    chord = 2 * r * math.tan(math.pi / n)
    for i in range(n):
        g = f.sub((cx, y0, cz), ry=360 * i / n)
        c = jitter(color, rng, jit) if jit and rng else color
        g.part(name, (0, h / 2, -r / 2), (chord, h, r), c, material, shape=WEDGE, flags=flags)
    return n


def _ov(k=0):
    """Local z centre of a 0.05-thick part meant to sit in front of overlay layer k: half a slot
    in front of slot k (zlayers.WALL_* depths), so it never shares a plane with an overlay.
    Used for invisible text carriers (their SurfaceGui draws on the front face)."""
    return zlayers.wall_text_depth(k)


def overlay(f, name, x0, x1, y0, y1, color, k=0, tr=0.5, material="Concrete", rz=0.0, inset=0.002, clip=True, **kw):
    """A thin stain / paint / paper layer flat on the wall face. Matte by default (Concrete):
    a glossy translucent layer reads as a grey film, a matte one as a stain soaked in.

    The depth comes from zlayers.wall_layer: the next free slot of this wall plane, one slot in
    front of every overlay it overlaps (from any prop), each slot WALL_TH thick with an air gap,
    so no two layers share a plane or intersect. k is the order hint inside the prop (higher =
    in front). A translucent layer lying wholly over one opaque surface is made OPAQUE with the
    blended colour (nothing left to depth-sort). Pieces that only touch along an edge share a
    slot: that is how the mosaics below are built. Returns the part index, or None when that
    place already has zlayers.WALL_MAX layers (the layer is dropped, never squeezed in).
    inset: each edge is pulled in by this much, so pieces that butt never overlap by a rounding
    hair (the rows are written to 0.001 stud).
    clip: a part already standing against the wall in the slots' depth (_spans: a door frame,
    a breakable board, a cabinet) is not run behind or through: a wide layer keeps its widest
    free stretch beside it, a narrow one (a streak piece) is not made (None)."""
    flags = kw.pop("flags", DECOR)
    if clip:
        x0, x1, y0, y1 = min(x0, x1), max(x0, x1), min(y0, y1), max(y0, y1)
        spans = _spans(f, x0, x1, y0, y1)
        if spans != [(x0, x1)]:
            # something already stands against the wall here (a unit's frame, a board, a
            # cabinet): a wide layer keeps its widest free stretch, a narrow one is not made
            if x1 - x0 < 1.5 or not spans:
                return None
            x0, x1 = max(spans, key=lambda sp: sp[1] - sp[0])
    w, h = abs(x1 - x0), abs(y1 - y0)
    w, h = (w - 2 * inset if w > 4 * inset else w), (h - 2 * inset if h > 4 * inset else h)
    return zlayers.wall_layer(f, name, (x0 + x1) / 2, (y0 + y1) / 2, w, h, rz, color, k, tr, material, flags, **kw)


def _layer_item(D, idx):
    """zlayers' record of the overlay made as row idx (its plane polygon and slot)."""
    for pl in zlayers._state(D)["planes"]:
        for it in reversed(pl["items"]):
            if it["idx"] == idx:
                return it
    return None


_CORNER = {(-1, -1): 0, (1, -1): 1, (1, 1): 2, (-1, 1): 3}  # (zlayers' order of a layer's corners)


def tri(f, name, px, py, a, b, color, k=0, tr=0.5, material="Concrete", flags=DECOR):
    """A right-triangle overlay: the soft, ragged edge of a stain (a tooth on a damp line, the
    point of a run-off, a torn paper edge, a chipped render edge). Right angle at local
    (px, py), legs a along X and b along Y (signed). It takes its slot like a rectangular overlay
    (zlayers.wall_layer, with its box) and is then turned into a wedge lying flat in that slot,
    and zlayers is told its true triangle, so layers next to it are not pushed forward for the
    empty half of the box. Build a mosaic from it: a triangle sitting on the edge of a rectangle
    of the same stain shares the rectangle's slot. Returns the part index or None."""
    sx, sy = (1 if a >= 0 else -1), (1 if b >= 0 else -1)
    a, b = abs(a) - 0.004, abs(b) - 0.004  # (pulled in off its neighbours, see overlay's inset)
    if a < 0.03 or b < 0.03:
        return None
    px, py = px + sx * 0.002, py + sy * 0.002
    idx = overlay(f, name, min(px, px + sx * a), max(px, px + sx * a), min(py, py + sy * b), max(py, py + sy * b),
                  color, k=k, tr=tr, material=material, flags=flags, inset=0.0)
    if idx is None:
        return None
    row = f.D.parts[idx - 1]
    m = yxz_matrix(row[4], row[5], row[6]) @ _in_plane(sx, sy)
    row[0] = WEDGE
    row[4:7] = [round(v, 2) for v in yxz_angles(m)]
    row[7:10] = [round(zlayers.WALL_TH, 3), round(b, 3), round(a, 3)]
    it = _layer_item(f.D, idx)
    if it is not None:
        p = it["poly"]
        it["poly"] = [p[_CORNER[(-sx, -sy)]], p[_CORNER[(sx, -sy)]], p[_CORNER[(-sx, sy)]]]
    return idx


def _ok(idx):
    return 0 if idx is None else 1


def ragged_top(f, rng, name, x0, x1, y, rise, color, k=0, tr=0.5, material="Concrete", peaks=1, flags=DECOR):
    """The ragged upper edge of a stain whose body ends at height y between x0 and x1: `peaks`
    gables side by side (two right triangles back to back each, uneven widths and heights up to
    `rise`), so the edge is a wavering line of points, not a straight cut. rise < 0 hangs the
    teeth down instead (a torn lower edge, the drips of a stain). Returns the parts made."""
    n = 0
    cuts = sorted(rng.uniform(x0, x1) for _ in range(peaks - 1))
    edges = [x0] + cuts + [x1]
    for a, b in zip(edges, edges[1:]):
        if b - a < 0.12:
            continue
        px = a + (b - a) * rng.choice((rng.uniform(0.18, 0.38), rng.uniform(0.62, 0.82)))  # (off-centre)
        hh = rise * rng.uniform(0.45, 1.0)
        n += _ok(tri(f, name, px, y, -(px - a), hh, color, k=k, tr=tr, material=material, flags=flags))
        n += _ok(tri(f, name, px, y, b - px, hh * rng.uniform(0.6, 1.0), color, k=k, tr=tr, material=material,
                     flags=flags))
    return n


def streak(f, rng, name, x, y_top, length, width, color, k=1, tr=0.55, taper=3):
    """A run-off stain hanging down from (x, y_top): a mosaic on one slot, not a stack. taper 3:
    a dark core at the source, the run (a little narrower, lighter) and a pointed tip (a right
    triangle, leaning to one side) where it fades out; taper 2: run + tip; 1: the run alone.
    The whole stain is turned a degree or so (running water never hangs quite straight).
    It stops above any unit standing out of the wall below it (a window, door, cabinet, AC
    casing: _blocked_below), which it would only run behind. Returns the number of parts made."""
    taper = max(1, min(int(taper), 3))
    stop = _blocked_below(f, x - width / 2, x + width / 2, y_top)
    length = min(length, y_top - stop - 0.15)
    if length < 0.4:
        return 0
    g = f.sub((x, y_top, 0), rz=rng.uniform(-1.4, 1.4))
    n = 0
    y = 0.0
    if taper >= 3:
        ch = min(length * rng.uniform(0.12, 0.2), 0.7)
        n += _ok(overlay(g, name, -width / 2, width / 2, -ch, 0, jitter(mix(color, WET_DARK, 0.25), rng, 4),
                         k=k, tr=max(0.0, tr - 0.15)))
        y = -ch
    bw = width * (rng.uniform(0.7, 0.85) if taper >= 3 else 1.0)
    tip = (length + y) * (rng.uniform(0.35, 0.55) if taper >= 2 else 0.0)
    body = length + y - tip
    xo = rng.uniform(-0.1, 0.1) * (width - bw)
    if body > 0.05:
        n += _ok(overlay(g, name, xo - bw / 2, xo + bw / 2, y - body, y, jitter(color, rng, 4), k=k, tr=tr))
        y -= body
    if tip > 0.05:
        side = rng.choice((-1, 1))
        n += _ok(tri(g, name, xo + side * bw / 2, y, -side * bw, -tip, jitter(color, rng, 3), k=k,
                     tr=min(0.92, tr + 0.08)))
    return n


def soft(f, rng, name, x0, x1, y0, y1, color, opacity=0.5, layers=3, k=0, anchor="center", material="Concrete",
         ragged=0.25):
    """A soft-edged stain on one slot: a body with gable ends (two right triangles back to back,
    off-centre) instead of a hard rectangle edge: on top for anchor = "bottom" (it rises from
    something: grime on a step, moss), on top and bottom for "center", underneath for "top".
    opacity = how strong it is. (`layers` is kept for the callers; the stain is one tone: nested
    layers were what made the old stains read as stair-steps.) Returns the number of parts."""
    del layers
    w, h = x1 - x0, y1 - y0
    tr = 1 - opacity
    g = f.sub(((x0 + x1) / 2, 0, 0), rz=rng.uniform(-0.8, 0.8))
    hw = w / 2
    top = h * rng.uniform(0.25, 0.4) * (1 + ragged) if anchor in ("bottom", "center") else 0.0
    bot = h * rng.uniform(0.2, 0.35) * (1 + ragged) if anchor in ("top", "center") else 0.0
    b0, b1 = y0 + bot, y1 - top
    c = jitter(color, rng, 3)
    n = _ok(overlay(g, name, -hw, hw, b0, b1, c, k=k, tr=tr, material=material))
    if n == 0:
        return 0
    peaks = 1  # (one low, off-centre point per edge: few parts, and no row of teeth)
    if top > 0.05:
        n += ragged_top(g, rng, name, -hw, hw, b1, top, c, k=k, tr=tr, material=material, peaks=peaks)
    if bot > 0.05:
        n += ragged_top(g, rng, name, -hw, hw, b0, -bot, c, k=k, tr=tr, material=material, peaks=peaks)
    return n


def frame_at(D, folder, origin, ry):
    """The prop's frame. Also starts a new zlayers instance: this prop's overlays go in front of
    those of every prop placed before it on the same wall."""
    zlayers.new_instance(D)
    return Frame(D, folder, origin=origin, ry=ry)


def light_extra(tags, light, attrs=None):
    ex = {"t": tags, "l": light}
    if attrs:
        ex["a"] = attrs
    return ex


def sign_extra(text, color, font="PermanentMarker", lit=False, face="Front", bg=None, **more):
    """A SurfaceGui text on the carrier's face. bg: a background colour (a printed sticker or
    label drawn flush on the carrier, no extra part). more: the optional sign fields of
    City/init.luau addSign (pps, pad, textTr, xalign, rich...; see the texts audit S0)."""
    g = {"text": text, "font": font, "color": [int(c) for c in color], "face": face, "lit": lit,
         "bg": [int(c) for c in bg] if bg else None, "bg_tr": 0.0 if bg else 1.0, "rot": 0, "align": "Center"}
    g.update({k: v for k, v in more.items() if v is not None})
    return {"g": g}


# Text on the walls (texts audit S0): sprays and tags readable at 8+ studs, at least 3:1 against
# what they are painted on; else black or off-white, whichever reads better.
INK_BLACK = (22, 22, 22)
TAG_LINE_H = 1.15  # (graffiti_tag: LineHeight of a tag on two lines)
INK_WHITE = (228, 222, 206)


def _lum(c):
    def ch(v):
        v = v / 255.0
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

    r, g, b = (ch(v) for v in c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = _lum(a), _lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def readable_ink(color, ground, need=3.0):
    """color if it reads at `need`:1 on ground, else black or off-white (the better one)."""
    if ground is None or contrast(color, ground) >= need:
        return color
    return max((INK_BLACK, INK_WHITE), key=lambda c: contrast(c, ground))


def wall_text(text, font, w, h, pad=(0.04, 0.06), lines=True):
    """(text with its own line breaks, pps, text height in studs) for a w x h carrier: on one line
    or two, whichever draws it bigger."""
    if lines and "\n" not in text:
        two = textfit.two_lines(text, limit=0)
        if textfit.text_studs(two, font, w, h, pad) > textfit.text_studs(text, font, w, h, pad) * 1.05:
            text = two
    size = textfit.text_studs(text, font, w, h, pad)
    return text, textfit.fit_pps(text, font, w, h, pad), size


def _layer_front(f, idx):
    """Local z of the front face of overlay row idx (for things pinned on it: staples)."""
    row = f.D.parts[idx - 1]
    loc = f.m.T @ (np.array(row[1:4], float) - f.origin)
    return loc[2] - zlayers.WALL_TH / 2


# A flat part fixed on the wall (a base plate, a bracket's wall leg) has its front face inside the
# depth band of the overlay slots (0.03..0.255 out). Squared to the wall it would be parallel to
# every stain or poster running under it, 0.02-0.03 from one of their faces: the flicker the
# player saw. So it is set a few degrees off square (a bent plate, an uneven wall: real fixings
# never sit dead flat), its high corners sunk into the wall so no gap opens behind it. A face
# more than ~1.8 degrees off another one meets it along a clean line instead of fighting it.
PLATE_TILT = (2.6, 4.2)  # degrees about each in-plane axis


def plate(f, rng, name, cx, cy, w, h, t, color, material, shape=BLOCK, flags=DECOR):
    """A plate w x h, t thick, flat on the wall (its back on the wall plane), centred on local
    (cx, cy), tilted PLATE_TILT about X and Y (random signs) and sunk by its tilt. shape=CYLINDER:
    a round plate of diameter max(w, h). Returns the row."""
    ax = rng.uniform(*PLATE_TILT) * rng.choice((-1, 1))
    ay = rng.uniform(*PLATE_TILT) * rng.choice((-1, 1))
    sink = (h / 2) * math.sin(math.radians(abs(ax))) + (w / 2) * math.sin(math.radians(abs(ay)))
    g = f.sub((cx, cy, -t / 2 + sink), rx=ax, ry=ay)
    if shape == CYLINDER:
        d = max(w, h)
        return g.part(name, (0, 0, 0), (t, d, d), color, material, rot=(0, 90, 0), shape=CYLINDER, flags=flags)
    return g.part(name, (0, 0, 0), (w, h, t), color, material, flags=flags)


def _spans(f, x0, x1, y0, y1, gap=0.06, keep=0.3):
    """The stretches of local x0..x1 (between heights y0..y1) of frame f's wall face where no
    part already made stands against the wall within the overlay slots' depth: a block or
    wedge reaching from the face (or into the wall) out past slot 0 (a frame, a step, a board,
    a cabinet, a bracket plate). Each blocker is widened by `gap`; stretches narrower than
    `keep` are dropped. Uses zlayers' table of solid parts (overlays and thin parts left out)."""
    D = f.D
    zlayers.host_at(D, f.world((0.0, 0.0, 0.0)))  # (brings zlayers' table of parts up to date)
    S = zlayers._state(D)["solids"]
    if not len(S.c):
        return [(x0, x1)]
    q = np.array([f.world((x, y, z)) for x in (x0, x1) for y in (y0, y1) for z in (0.0, -0.32)])
    qlo, qhi = q.min(axis=0) - 0.01, q.max(axis=0) + 0.01
    cand = np.nonzero(np.all((S.lo <= qhi) & (S.hi >= qlo), axis=1))[0]
    cuts = []
    for i in cand:
        if S.info[i][2] >= 0.99:
            continue  # (an invisible text carrier)
        R = f.m.T @ S.m[i]
        c = f.m.T @ (S.c[i] - f.origin)
        ext = np.abs(R) @ S.h[i]
        lo, hi = c - ext, c + ext
        if not (lo[2] < -0.035 and -0.15 < hi[2] < 0.05):
            continue  # (the wall itself, or something standing clear in front of the slots)
        if hi[1] <= y0 or lo[1] >= y1 or hi[0] <= x0 or lo[0] >= x1:
            continue
        cuts.append((lo[0] - gap, hi[0] + gap))
    if not cuts:
        return [(x0, x1)]
    out, a = [], x0
    for c0, c1 in sorted(cuts):
        if c0 > a:
            out.append((a, min(c0, x1)))
        a = max(a, c1)
        if a >= x1:
            break
    if a < x1:
        out.append((a, x1))
    return [(u, v) for u, v in out if v - u >= keep]


def _signed(rng, lo, hi):
    """A random angle lo..hi degrees, either sign."""
    return rng.uniform(lo, hi) * rng.choice((-1, 1))


def _solid_at(f, p):
    """Whether local point p of frame f is inside a part already made (the alley's data or the
    city's own walls and blocks): to keep a gutter end, a broken length or roof clutter out of a
    neighbouring wall, and to skip a mass that another building already fills."""
    return zlayers.host_at(f.D, f.world(p)) is not None


# =================================================================================================
# 1. Surfaces: grime, plaster, stains, posters, signs, graffiti
# =================================================================================================


def wall_grime(D, folder, origin, ry, rng, width=12.0, height=5.0, soot=True, moss=True):
    """Rising damp at the foot of a wall, in 4-6 large pieces (it is at the foot of every wall:
    the most repeated stain of the alleys, so it must not read as a row of teeth or steps):
      • the splash-back: a wet, darkest strip along the ground (rain bouncing off it), one end
        of it green with moss (the corner that never dries);
      • the damp band above it, a tone lighter: the wall wicks water up to about 60 % of
        `height`;
      • its fringe: two long pieces a tone lighter again (the gradient: darkest at the foot,
        fading upward), each at its own height and a degree or so off level, so the tide line
        rises and falls along the wall and steps where they meet, like real damp does. The
        fringe lies one slot in front of the band (it covers the band's straight top edge).
    Every piece is a wall layer in zlayers' slots, made opaque in the blended colour with the
    wall's own material (the brick texture carries on through the stain). `soot` is kept for
    the callers (the haze above it is gone: it added layers without reading as anything).
    Footprint: width x height (flat on the face). Parts: 4-6 (a few more where it is cut
    round a door or a board standing against the wall)."""
    del soot
    f = frame_at(D, folder, origin, ry)
    n = 0
    x0, x1 = -width / 2, width / 2
    # at an inner corner a crossing wall stands at (or near) an end: the stain stops short of its
    # face by the depth of its own stain slots, so the two walls' layers never meet edge-on
    for e in (-1, 1):
        for d in (-0.3, -0.15, 0.0, 0.15, 0.3, 0.45):  # (from the inside out: the first solid is the face)
            xe = e * (width / 2 + d)
            if _solid_at(f, (xe, 1.0, -0.12)) or _solid_at(f, (xe, 2.5, -0.12)):
                if e < 0:
                    x0 = max(x0, xe + 0.34)
                else:
                    x1 = min(x1, xe - 0.34)
                break
    s = rng.uniform(0.34, 0.55)  # splash-back: rain bouncing off the ground
    hb = height * rng.uniform(0.5, 0.62)  # the damp band's top (its fringe wavers round it)
    wet = jitter(mix(WET_DARK, DAMP, rng.uniform(0.1, 0.4)), rng, 3)
    damp = jitter(DAMP, rng, 3)
    # the splash strip, one end of it moss
    runs = [(x0, x1, "Splash")]
    if moss and width > 3 and rng.random() < 0.85:
        mw = rng.uniform(0.9, min(2.8, width * 0.3))
        runs = [(x0, x0 + mw, "Moss"), (x0 + mw, x1, "Splash")] if rng.random() < 0.5 else \
            [(x0, x1 - mw, "Splash"), (x1 - mw, x1, "Moss")]
    mh = s + rng.uniform(0.1, 0.35)
    for a, b, nm in runs:
        # (each band stops beside whatever already stands against the wall: a door's frame and
        # step, a breakable board, a cabinet; it would only run behind or through it)
        for u, v in _spans(f, a, b, 0, mh if nm == "Moss" else s):
            if nm == "Moss":
                n += _ok(overlay(f, "Moss", u, v, 0, mh, jitter(MOSS, rng, 6), k=0, tr=0.35, material="Grass"))
            else:
                n += _ok(overlay(f, "Splash", u, v, 0, s, wet, k=0, tr=0.42))
    made = 0
    for u, v in _spans(f, x0, x1, s, hb):
        made += _ok(overlay(f, "Damp", u, v, s, hb, damp, k=0, tr=0.62))
    if not made:
        return n
    n += made
    # the fringe: two pieces, each its own height and slope; they butt where the tide line steps
    xm = rng.uniform(x0 + width * 0.3, x1 - width * 0.3)
    fh = min(1.8, max(1.2, height * 0.3))  # (tall enough to cover the band's top edge as it slopes)
    fringe = jitter(mix(damp, (90, 80, 70), 0.35), rng, 3)
    for a, b in ((x0 + 0.08, xm - 0.05), (xm + 0.05, x1 - 0.08)):  # (a hair apart: tilted, they would cross)
        half = (b - a) / 2
        rise = min(rng.uniform(0.15, min(0.45, fh * 0.3)), half * 0.05)  # (never steeper than ~3 degrees)
        slope = rise / half * rng.choice((-1, 1))
        rz = math.degrees(math.atan(slope))
        yc = hb + rng.uniform(-0.15, 0.3)
        col = jitter(fringe, rng, 2)
        for u, v in _spans(f, a, b, yc - fh / 2 - rise, yc + fh / 2 + rise):
            # (a piece per free stretch, all on the same sloping line)
            m = (u + v) / 2
            g = f.sub((m, yc + slope * (m - (a + b) / 2), 0), rz=rz)
            hl = (v - u) / 2 / math.cos(math.radians(rz))
            n += _ok(overlay(g, "DampFringe", -hl, hl, -fh / 2, fh / 2, col, k=1, tr=0.7))
    return n


def plaster_patch(D, folder, origin, ry, rng, width=6.0, height=5.0, y=2.0, color=None, brick=None):
    """A patch of old render left on a brick wall: a few large pieces of one render skin (on the
    wall's first slot, about 2 cm thick like real render) round a hole where it fell off and the
    brick shows, with chipped edges (right triangles biting in or sticking out, never stair-step
    rows), loose bricks standing proud in the hole, the lower part dirtier (splashed) and a dirt
    run under it. Footprint: width x height at height y. Parts: 8-16."""
    f = frame_at(D, folder, origin, ry)
    base = color or rng.choice(PLASTER)
    brick = brick or rng.choice(BRICK)
    clean = jitter(mix(base, brick, 0.12), rng, 2)  # (old render takes the wall's dirt)
    dirty = jitter(mix(base, DAMP, 0.35), rng, 2)
    n = 0
    x0, x1, y0, y1 = -width / 2, width / 2, y, y + height
    # the hole (brick showing): a box in the middle third, off-centre
    hw, hh = width * rng.uniform(0.2, 0.32), height * rng.uniform(0.22, 0.34)
    hx = rng.uniform(x0 + 0.25 * width, x1 - 0.25 * width - hw)
    hy = rng.uniform(y0 + 0.3 * height, y1 - 0.2 * height - hh)
    ym = hy - rng.uniform(0.1, 0.25) * (hy - y0)  # the dirty band's top (below the hole)
    pieces = [
        (x0, x1, y0, ym, dirty),  # dirty foot
        (x0, x1, ym, hy, clean),
        (x0, hx, hy, hy + hh, clean),
        (hx + hw, x1, hy, hy + hh, clean),
        (x0, x1, hy + hh, y1, clean),
    ]
    for a, b, c, d, col in pieces:
        if b - a > 0.1 and d - c > 0.1:
            n += _ok(overlay(f, "Render", a, b, c, d, col, k=0, tr=0.0, material="Plaster"))
    # chipped outline: the top edge breaks up in points, the sides lose triangles
    n += ragged_top(f, rng, "Render", x0, x1, y1, rng.uniform(0.35, 0.7), clean, k=0, tr=0.0, material="Plaster",
                    peaks=max(2, int(width / 1.6)))
    for sx, xe in ((-1, x0), (1, x1)):  # teeth sticking out of each side, pointing up or down
        for i, ty in enumerate(sorted(rng.uniform(y0 + 0.5, y1 - 0.6) for _ in range(2))):
            col = dirty if ty < ym else clean  # (the lower one hangs down, the upper one points up: apart)
            n += _ok(tri(f, "Render", xe, ty, sx * rng.uniform(0.2, 0.45), (1 if i else -1) * rng.uniform(0.35, 0.7),
                         col, k=0, tr=0.0, material="Plaster"))
    n += ragged_top(f, rng, "Render", x0, x1, y0, -rng.uniform(0.2, 0.45), dirty, k=0, tr=0.0, material="Plaster",
                    peaks=max(1, int(width / 2.5)))
    # the hole's edge: two chips biting into the render above and below it
    n += _ok(tri(f, "Render", hx + hw * rng.uniform(0.3, 0.7), hy + hh, rng.choice((-1, 1)) * hw * 0.3, -0.3, clean,
                 k=0, tr=0.0, material="Plaster"))
    # loose bricks in the hole, standing proud (each its own depth: they never share a face)
    for i in range(rng.randint(1, 3)):
        bx = hx + hw * rng.uniform(0.25, 0.75)
        by = hy + 0.2 + 0.36 * i  # (one course apart: they never overlap)
        if by + 0.17 > hy + hh:
            break
        dz = (0.18, 0.23, 0.13)[i]  # (fronts between the overlay slots' fronts, see SLOT_SAFE)
        # (each off square by > 2.5 degrees: its front never parallel to a layer round it)
        f.part("Brick", (bx, by, -dz / 2), (rng.uniform(0.7, 0.85), 0.3, dz),
               jitter(brick, rng, 10, 0.1), "Brick",
               rot=(_signed(rng, 2.6, 4), _signed(rng, 2.6, 4.5), rng.uniform(-4, 4)), flags=DECOR)
        n += 1
    # a dirt run under the patch (from its lowest point)
    n += streak(f, rng, "Streak", rng.uniform(x0 + 0.5, x1 - 0.5), y0 - 0.25, min(y0 - 0.3, height * 0.6), 0.45,
                DAMP, k=1, tr=0.66, taper=2) if y0 > 1.2 else 0
    return n


def crack(D, folder, origin, ry, rng, length=5.0, y=3.0, x=0.0, branch=True):
    """DROPPED (the audit's verdict): the crack was dark beams standing proud of the wall, which
    read as wires stuck on it; a real crack is a recess following the mortar, which parts
    can't make. Kept as a no-op so callers still run. Parts: 0."""
    del D, folder, origin, ry, rng, length, y, x, branch
    return 0


def rust_streak(D, folder, origin, ry, rng, x=0.0, y=8.0, length=4.0, width=0.6, bolt=True):
    """Rust run-off under an old fixing at (x, y): the stub of a cut-off bracket (a plate bolted
    to the wall, a flat bar sticking out) or just the bolt holes (bolt=False), and below it the
    rust stain: a dark core at the source, the run, a pointed tip where it fades.
    Footprint: width x length. Parts: 2-6."""
    f = frame_at(D, folder, origin, ry)
    n = 0
    top = y
    if bolt:
        pc = jitter(RUST_DARK, rng, 5)
        plate(f, rng, "Stub", x, y, 0.32, 0.32, 0.08, pc, "CorrodedMetal")
        f.box("Stub", (x - 0.05, y - 0.13, -0.5), (x + 0.05, y + 0.13, -0.04), jitter(RUST, rng, 6), "CorrodedMetal",
              rot=(0, 0, rng.uniform(-6, 6)), flags=DECOR)
        bolt_ = rng.choice((-1, 1))
        _bolt(f, "Bolt", (x + bolt_ * 0.1, y + 0.1, -0.08), 0.08, RUST_DARK)
        n += 3
        top = y - 0.26  # (clear of the tilted plate)
    n += streak(f, rng, "RustStreak", x, top, length, width, jitter(RUST_STAIN, rng, 8), k=0, tr=0.5, taper=3)
    return n


def efflorescence(D, folder, origin, ry, rng, width=4.0, y=0.4, height=1.6):
    """DROPPED (the audit's verdict): a pale panel that read as a pasted sheet, on the same
    planes as the damp. Salt bloom belongs to the damp stain itself. Kept as a no-op so callers
    still run. Parts: 0."""
    del D, folder, origin, ry, rng, width, y, height
    return 0


POSTER_TEXTS = ["MISSING", "LIVE · THE ROT", "CASH FOR GOLD", "ROOMS · NO ID", "LOST DOG", "FIGHT NIGHT",
                "WE BUY ANYTHING", "REWARD", "CLUB HOLLOW", "VOTE NO", "EVICTION NOTICE"]
POSTER_SUB = ["FRIDAY · 9PM", "NO QUESTIONS", "CALL 555-0143", "CASH ONLY", "ALL WELCOME", "LAST CHANCE"]


def _sheet(f, rng, x0, x1, y0, y1, paper, k, state):
    """One printed sheet as a mosaic on one slot: "intact", "torn" (only its top part left, the
    lower edge ripped into points), or "corner" (a corner ripped off diagonally). Returns
    (parts, the box of what is left (x0, x1, y0, y1), the row of its main piece)."""
    n = 0
    main = None
    if state == "torn":
        cut = y0 + (y1 - y0) * rng.uniform(0.38, 0.62)
        main = overlay(f, "Poster", x0, x1, cut, y1, paper, k=k, tr=0.0)
        n += _ok(main)
        n += ragged_top(f, rng, "Poster", x0, x1, cut, -rng.uniform(0.25, 0.55), paper, k=k, tr=0.0,
                        peaks=rng.randint(1, 2))
        return n, (x0, x1, cut, y1), main
    if state == "corner":
        c = (x1 - x0) * rng.uniform(0.3, 0.5)
        yc = y1 - (y1 - y0) * rng.uniform(0.2, 0.35)
        right = rng.random() < 0.5
        main = overlay(f, "Poster", x0, x1, y0, yc, paper, k=k, tr=0.0)
        n += _ok(main)
        if right:
            n += _ok(overlay(f, "Poster", x0, x1 - c, yc, y1, paper, k=k, tr=0.0))
            n += _ok(tri(f, "Poster", x1 - c, yc, c, y1 - yc, paper, k=k, tr=0.0))
        else:
            n += _ok(overlay(f, "Poster", x0 + c, x1, yc, y1, paper, k=k, tr=0.0))
            n += _ok(tri(f, "Poster", x0 + c, yc, -c, y1 - yc, paper, k=k, tr=0.0))
        return n, (x0, x1, y0, yc), main
    main = overlay(f, "Poster", x0, x1, y0, y1, paper, k=k, tr=0.0)
    return _ok(main), (x0, x1, y0, y1), main


def torn_posters(D, folder, origin, ry, rng, width=3.6, height=4.2, y=3.5, text=None, layers=None):
    """Fly-posting built up over years, as it is done: a run of the same poster pasted side by
    side (real poster proportions, A2-ish 1 : 1.41), over the torn remains of an older run in
    other faded colours. Each sheet is a mosaic on its slot (torn ones lose their lower part
    in a ragged edge of points, some lose a corner diagonally); the newest run is printed (a
    faded image block and a headline, SurfaceGui) and stapled (round heads); one torn corner
    curls off the wall. Footprint: width x height. Parts: 10-24."""
    f = frame_at(D, folder, origin, ry)
    n = 0
    x0, x1 = -width / 2, width / 2
    # the older layer: one or two big sheets side by side (they butt), torn high and low
    older = rng.randint(1, 2) if layers is None else max(1, min(2, layers - 1))
    cuts = [x0] + ([rng.uniform(x0 + width * 0.35, x1 - width * 0.35)] if older == 2 else []) + [x1]
    for a, b in zip(cuts, cuts[1:]):
        top = y + height * rng.uniform(0.7, 0.95)
        low = y + height * rng.uniform(0.0, 0.25)
        paper = jitter(mix(rng.choice(PAPER), rng.choice(POSTER_INK), rng.uniform(0.15, 0.35)), rng, 6, 0.08)
        if overlay(f, "OldPoster", a, b, low, top, paper, k=0, tr=0.0) is None:
            continue
        n += 1
        n += ragged_top(f, rng, "OldPoster", a, b, top, rng.uniform(0.25, 0.5), paper, k=0, tr=0.0, peaks=1)
    # the new run: 1-3 copies of one poster
    ph = min(height * rng.uniform(0.55, 0.68), 2.6)
    pw = ph / 1.41
    count = max(1, min(3, int((width - 0.1) / (pw + 0.06))))
    gap = rng.uniform(0.04, 0.12)
    span = count * pw + (count - 1) * gap
    sx = rng.uniform(x0, x1 - span) if span < width else x0 + (width - span) / 2
    py = y + height - ph - rng.uniform(0.05, 0.4)
    paper = jitter(rng.choice(PAPER[:4]), rng, 6)
    ink = jitter(mix(rng.choice(POSTER_INK), paper, rng.uniform(0.25, 0.45)), rng, 6)  # faded print
    label = text or rng.choice(POSTER_TEXTS)
    sub = rng.choice(POSTER_SUB)
    states = ["intact"] * count
    if count >= 2:
        states[rng.randrange(count)] = "torn"
    if rng.random() < 0.6:
        free = [i for i, s in enumerate(states) if s == "intact"]
        if free:
            states[rng.choice(free)] = "corner"
    flap_done = False
    for i in range(count):
        a = sx + i * (pw + gap)
        b = a + pw
        dy = rng.uniform(-0.06, 0.06)
        made, (ka, kb, kc, kd), main = _sheet(f, rng, a, b, py + dy, py + ph + dy, jitter(paper, rng, 3), 1, states[i])
        n += made
        if main is None:
            continue
        # the printed image block (on the sheet: one slot in front) and the headline above it
        ib0, ib1 = py + dy + ph * 0.3, py + dy + ph * 0.74
        if kc < ib0 + 0.1 and kd > ib1 - 0.05:
            n += _ok(overlay(f, "Print", a + pw * 0.1, b - pw * 0.1, max(ib0, kc + 0.05), ib1, ink, k=2, tr=0.0))
        # (texts audit S0 posters: the headline in the top band between the image and the top edge,
        # the sub-line 12 % of the sheet high, both sharp; the sub-line's faded ink kept dark enough
        # to read, 3:1 on the paper)
        if kd > py + dy + ph * 0.9:
            hw, hh = pw * 0.86, ph * 0.18
            ink_h, font_h = jitter((40, 34, 30), rng, 6), rng.choice(["Oswald", "Bodoni", "Arial"])
            f.part("PosterText", ((a + b) / 2, py + dy + ph * 0.855, _ov(3)), (hw, hh, 0.05), (0, 0, 0),
                   "SmoothPlastic", transparency=1, flags=DECOR,
                   extra=sign_extra(label, ink_h, font=font_h, pad=[0.03, 0.06],
                                    pps=textfit.fit_pps(label, font_h, hw, hh, [0.03, 0.06])))
            n += 1
        if states[i] == "intact" and kc < py + dy + ph * 0.2:
            sw_, sh_ = pw * 0.8, ph * 0.12
            f.part("PosterSub", ((a + b) / 2, py + dy + ph * 0.17, _ov(3)), (sw_, sh_, 0.05), (0, 0, 0),
                   "SmoothPlastic", transparency=1, flags=DECOR,
                   extra=sign_extra(sub, readable_ink(ink, paper), font="Oswald", pad=[0.03, 0.08],
                                    pps=textfit.fit_pps(sub, "Oswald", sw_, sh_, [0.03, 0.08])))
            n += 1
        # staples at the top corners (round heads on the paper)
        if i == 0 or rng.random() < 0.5:
            zf = _layer_front(f, main)
            for xs in (a + 0.08, b - 0.08):
                bolt(f, "Staple", (xs, kd - 0.08, zf), 0.05, (120, 120, 116))
                n += 1
        # one torn sheet's corner curls off the wall
        if states[i] == "torn" and not flap_done:
            flap_done = True
            fx = a if rng.random() < 0.5 else b
            g = f.sub((fx, kc, _layer_front(f, main) - 0.01), rx=rng.uniform(22, 38))
            tri_part(g, "Flap", 0, 0, (0.45 if fx == a else -0.45), -rng.uniform(0.35, 0.55), 0, 0.02,
                     jitter(paper, rng, 4, 0.05), "SmoothPlastic", flags=DECOR)
            n += 1
    return n


def painted_sign(D, folder, origin, ry, rng, width=9.0, height=2.4, y=11.0, text="HARLAN & SONS · TANNERY",
                 color=None, ground=None):
    """A faded 'ghost sign' painted on brick decades ago: one painted ground (no stripes: a
    banded ground read as planks nailed to the wall), a thin border line along its top and
    bottom, the lettering half gone (SurfaceGui), whole flakes of paint lost where the brick
    shows again (patches in the wall's own colour and material, ragged on one side, lying over
    the paint), and rain streaks run through it. Footprint: width x height at y. Parts: 7-14."""
    f = frame_at(D, folder, origin, ry)
    ground = ground or jitter(rng.choice([(108, 92, 64), (70, 76, 70), (96, 54, 44), (120, 116, 104)]), rng, 6)
    ink = color or jitter(rng.choice([(176, 166, 140), (150, 140, 112), (30, 30, 28)]), rng, 6)
    n = 0
    x0, x1 = -width / 2, width / 2
    bh = rng.uniform(0.12, 0.17)
    g = f.sub((0, 0, 0), rz=rng.uniform(-0.4, 0.4))  # (painted by hand: never quite level)
    if overlay(g, "SignGround", x0, x1, y + bh, y + height - bh, ground, k=0, tr=0.45) is None:
        return 0
    n += 1
    for y0 in (y, y + height - bh):  # border lines (they butt on the ground's edges)
        n += _ok(overlay(g, "SignBorder", x0, x1, y0, y0 + bh, jitter(ink, rng, 4), k=0, tr=0.5))
    # flakes: the paint gone, the brick back (its colour and material, lying over the paint)
    for _ in range(rng.randint(3, 5)):
        fw, fh = rng.uniform(0.7, 2.0), rng.uniform(0.4, height * 0.55)
        fx = rng.uniform(x0 + 0.2, x1 - 0.2 - fw)
        fy = rng.uniform(y + 0.05, y + height - 0.05 - fh)
        host = zlayers.host_at(D, f.world((fx + fw / 2, fy + fh / 2, 0.1)))
        if host and host[2] == 0:
            bc, bm = jitter(host[0], rng, 4), host[1]
        else:
            bc, bm = jitter(rng.choice(BRICK), rng, 4), "Brick"
        idx = overlay(g, "SignFlake", fx, fx + fw, fy, fy + fh, bc, k=1, tr=0.0, material=bm)
        if idx is None:
            continue
        n += 1
        # a ragged side: a chip of the flake running on along the brick course
        side = rng.choice((-1, 1))
        n += _ok(tri(g, "SignFlake", fx + (fw if side > 0 else 0), fy + fh * rng.uniform(0.0, 0.4),
                     side * rng.uniform(0.3, 0.7), fh * rng.uniform(0.4, 0.6), bc, k=1, tr=0.0, material=bm))
    # the lettering (texts audit T14): faded but readable (the ink 15 % into the ground, at least
    # 3:1; it was 35 %, 1.5:1), on two lines of its own at its separator, sharp
    words = text.replace(" · ", "\n", 1) if "\n" not in text else text
    ink = readable_ink(mix(ink, ground, 0.15), ground)
    tw, th, pad = width * 0.92, height * 0.62, [0.04, 0.04]
    f.part("SignText", (0, y + height / 2, _ov(2)), (tw, th, 0.05), (0, 0, 0), "SmoothPlastic",
           transparency=1, flags=DECOR,
           extra=sign_extra(words, ink, font="Oswald", pps=textfit.fit_pps(words, "Oswald", tw, th, pad), pad=pad,
                            textTr=0.08))
    n += 1
    for _ in range(rng.randint(1, 2)):  # rain has washed streaks through the paint
        n += streak(f, rng, "RunOff", rng.uniform(x0 + 0.5, x1 - 0.5), y + height + 0.3, height + rng.uniform(0.5, 2),
                    rng.uniform(0.3, 0.55), SOOT, k=6, tr=0.7, taper=2)
    return n


GRAFFITI_TAGS = ["NO COPS", "R0T", "SKUL", "MARROW", "DEAD END", "KRASH", "SLEEP LIGHT", "VIC OWES", "HOLLOW",
                 "ASK FOR VIC", "N.O.D.", "RATKING"]


def graffiti_tag(D, folder, origin, ry, rng, width=5.0, height=1.8, y=4.0, x=0.0, text=None, color=None,
                 buffed=None, drips=True):
    """A spray-painted tag: the text (a "g" sign on an invisible part, face Front), paint drips
    running from the strokes (each a thin run ending in a point, all different: where the can
    was held too long), and often an older tag 'buffed' out under a mismatched grey roller
    patch. Footprint: width x height. Parts: 1-12.
    Texts audit S0: PermanentMarker (thin scripts don't read at 8+ studs), its own line breaks,
    sharp (PixelsPerStud fitted), at most +-4 deg off level, at least 3:1 against the buff patch or
    the wall (else black / off-white), the buff patch centred on the text, drips starting at the
    letters' foot."""
    f = frame_at(D, folder, origin, ry)
    color = color or jitter(rng.choice([(180, 176, 160), (170, 60, 50), (60, 90, 120), (190, 180, 120),
                                         (30, 30, 30), (120, 150, 90)]), rng, 10)
    n = 0
    ground = None
    if buffed if buffed is not None else rng.random() < 0.4:
        g = f.sub((x, 0, 0), rz=rng.uniform(-1, 1))
        bc = jitter((92, 88, 80), rng, 6)
        if overlay(g, "Buff", -width * 0.57, width * 0.57, y - height * 0.12, y + height * 1.12, bc, k=0, tr=0.1,
                   material="Concrete") is not None:
            n += 1
            ground = bc
            # the roller's last pass ran out of paint: a thinner strip on one side
            n += _ok(overlay(g, "Buff", width * 0.57, width * 0.57 + rng.uniform(0.3, 0.6), y,
                             y + height * rng.uniform(0.6, 0.95), jitter(bc, rng, 4, 0.04), k=0, tr=0.35))
    if ground is None:
        host = zlayers.host_at(D, f.world((x, y + height / 2, 0.1)))
        ground = host[0] if host else None
    color = readable_ink(color, ground)
    rz = rng.uniform(-6, 6) * 4 / 6
    words = text or rng.choice(GRAFFITI_TAGS)
    rng.choice(["PermanentMarker", "Kalam"])  # (was the font: the draw is kept, the alleys stay as they were)
    words, pps, size = wall_text(words, "PermanentMarker", width, height)
    nl = words.count("\n") + 1
    # PermanentMarker's caps and descenders fill its whole line: two lines at LineHeight 1 touch
    # ("ASK FOR" sat on "VIC"). A little air between them (lineH), the size fitted with it.
    line_h = TAG_LINE_H if nl > 1 else None
    if line_h:
        size = textfit.text_studs(words, "PermanentMarker", width, height, [0.04, 0.06], line_h)
        pps = textfit.fit_pps(words, "PermanentMarker", width, height, [0.04, 0.06], line_h=line_h)
    f.part("Graffiti", (x, y + height / 2, _ov(2)), (width, height, 0.05), (0, 0, 0), "SmoothPlastic",
           rot=(0, 0, rz), transparency=1, flags=DECOR,
           extra=sign_extra(words, color, font="PermanentMarker", pps=pps, pad=[0.04, 0.06], textTr=0.04,
                            lineH=line_h))
    n += 1
    if drips:
        # under the letters: the last line's own width, from its foot (the text block is centred
        # on the carrier and tilted rz with it: the foot follows the tilt)
        size = min(size, 100 / pps)  # (what TextScaled draws: the 100 px cap)
        tw = min(width * 0.92, textfit.line_em(words.split("\n")[-1], "PermanentMarker") * size)
        foot = y + height / 2 - nl * size * (line_h or 1) / 2 + 0.03 * size
        xs = sorted(rng.uniform(-tw * 0.42, tw * 0.42) for _ in range(rng.randint(1, 5)))
        last = -1e9
        for dx in xs:
            if dx - last < 0.18:
                continue
            last = dx
            w = rng.uniform(0.035, 0.09)
            ln = rng.uniform(0.25, 1.5) * (0.6 if w < 0.05 else 1.0)
            ys = foot + dx * math.sin(math.radians(rz)) + size * (rng.uniform(0.18, 0.4) - 0.18) * 0.1
            g = f.sub((x + dx, ys, 0), rz=rng.uniform(-2, 2))
            if overlay(g, "Drip", -w / 2, w / 2, -ln, 0, color, k=1, tr=0.1) is None:
                continue
            n += 1
            side = rng.choice((-1, 1))
            n += _ok(tri(g, "Drip", side * w / 2, -ln, -side * w, -rng.uniform(0.08, 0.22), color, k=1, tr=0.1))
    return n


# =================================================================================================
# 2. Openings: windows, doors, shutters
# =================================================================================================

# Depths of a window's layers, out of the wall (studs). The whole unit stands in front of every
# overlay slot (zlayers puts its last one at 0.23-0.255), boxed in by the jambs, sill and lintel,
# so stains running down the wall pass behind it unseen. Parallel faces of layers that overlap
# are >= 0.06 apart.
W_PANEL = (0.29, 0.32)  # the room behind (dark panel, or the lit room)
W_INNER = (0.37, 0.39)  # blind / curtain / sheet / cardboard
W_LOWER = (0.44, 0.52)  # lower sash (inner) ...
W_LGLASS = (0.46, 0.48)  # ... and its glass
W_UPPER = (0.52, 0.60)  # upper sash (outer) ...
W_UGLASS = (0.56, 0.58)  # ... and its glass
W_BOX = (0.29, 0.62)  # the fixed box frame round the sashes
W_SURROUND = 0.70  # jambs
W_LINTEL = 0.76
W_SILL = 0.92  # the sill's nose
W_BOARD = (0.63, 0.69)  # plywood over a boarded window (inside the surround)
# A part fixed flat on the wall (a plate, a bracket leg) is either set a few degrees off square
# (plate()) or stands past every overlay slot (front >= 0.33 out); SLOT_SAFE (between the slots'
# fronts, 0.055 + 0.05 k) is only for small parts inside a hole of the stains (loose bricks).
SLOT_SAFE = (0.08, 0.13, 0.18, 0.23)


def _zbox(f, name, x0, x1, y0, y1, z, color, material, **kw):
    """A block between local x0..x1, y0..y1 and depths z = (near, far) out of the wall."""
    return f.box(name, (x0, y0, -z[1]), (x1, y1, -z[0]), color, material, **kw)


def window(D, folder, origin, ry, rng, width=3.4, height=5.0, y=4.0, variant="dirty", frame_color=None, x=0.0,
           kind="warm"):
    """A window unit standing in its surround: stone / pale brick / concrete jambs, a lintel
    (cracked concrete, stone with a keystone, or a rusted steel beam), a stepped sill with a
    sloped nose; inside it the fixed box frame and the sashes, the room behind (dark, or lit),
    and what hangs in it. No two of the 20 windows of the alleys look alike: the proportions
    vary a little, and so does the glazing (rng): a 1-over-1 or 2-over-2 sliding sash (the
    upper sash in front of the lower, the lower one sometimes pushed up), a casement with a
    mullion and a top light, a cheap uPVC replacement, a small frosted bathroom window; and
    what is inside: a venetian blind (some slats broken), a sheet, cardboard taped up, nothing.
    The glass is dirtiest low down (its colour, not a film in front of it).
    Variants: "dirty", "lit" (warm room light, a half-drawn curtain, tag CityWindowLit + a weak
    light on the room part), "boarded" (two plywood sheets + nailed planks, sprayed warning),
    "barred" (rusted bars on flat bars, lugs into the wall), "broken" (one pane gone but for
    shards, the other cracked). Stains: run-off from the sill horns, soot over the lintel.
    Footprint: (width + 1) x (height + 1.2), 0.95 deep. Parts: 16-36."""
    f = frame_at(D, folder, origin, ry).sub((x, 0, 0))
    lit = variant == "lit"
    style = rng.choice(["sash11", "sash11", "sash22", "sash22", "casement", "upvc", "frosted"])
    if variant in ("boarded", "barred") and style == "frosted":
        style = "sash11"
    w = width * rng.uniform(0.86, 1.03)
    h = height * rng.uniform(0.9, 1.03)
    if style == "frosted":  # a small bathroom window, high in its opening
        w, h = width * rng.uniform(0.6, 0.72), height * rng.uniform(0.55, 0.65)
    n = 0
    fc = UPVC if style == "upvc" else (frame_color or jitter(rng.choice(FRAME_PAINT), rng, 6))
    fmat = "SmoothPlastic" if style == "upvc" else "Wood"
    sur_kind = rng.choice(["stone", "stone", "brick", "concrete"])
    sur = jitter({"stone": rng.choice([STONE, (112, 106, 94)]), "brick": BRICK_PALE, "concrete": CONCRETE}[sur_kind], rng, 5)
    smat = {"stone": "Limestone", "brick": "Brick", "concrete": "Concrete"}[sur_kind]
    sw = rng.uniform(0.3, 0.42)  # jamb width
    ox = w / 2 + sw  # the surround's outer edge
    # --- surround: jambs between the sill and the lintel (they butt, never overlap)
    for s in (-1, 1):
        _zbox(f, "Jamb", min(s * w / 2, s * ox), max(s * w / 2, s * ox), y, y + h, (0, W_SURROUND),
              jitter(sur, rng, 3), smat, flags=DECOR)
        n += 1
    # --- sill: a slab, a raised back strip and a sloped nose (weathering), its horns past the jambs
    sx0, sx1 = -ox - 0.15, ox + 0.15
    sc = jitter(STONE if sur_kind != "brick" else (120, 112, 98), rng, 5, 0.06)
    _zbox(f, "Sill", sx0, sx1, y - 0.3, y - 0.07, (0, W_SILL), sc, "Slate", flags=DECOR_SHADOW)
    _zbox(f, "Sill", sx0, sx1, y - 0.07, y, (0, W_SURROUND), sc, "Slate", flags=DECOR)
    f.part("SillNose", ((sx0 + sx1) / 2, y - 0.035, -(W_SURROUND + W_SILL) / 2), (sx1 - sx0, 0.07, W_SILL - W_SURROUND),
           jitter(sc, rng, 3), "Slate", shape=WEDGE, flags=DECOR)
    n += 3
    # --- lintel
    lt = rng.choice(["concrete", "keystone", "steel"]) if sur_kind != "brick" else rng.choice(["steel", "concrete"])
    lx0, lx1 = -ox - rng.uniform(0.09, 0.2), ox + rng.uniform(0.09, 0.2)  # (its ends well past the jambs' sides)
    lh = rng.uniform(0.5, 0.66)
    if lt == "steel":  # a rusted steel beam under brick
        _zbox(f, "Lintel", lx0, lx1, y + h, y + h + 0.3, (0, W_SURROUND + 0.02), jitter(RUST_DARK, rng, 6),
              "CorrodedMetal", flags=DECOR)
        _zbox(f, "Lintel", lx0, lx1, y + h + 0.3, y + h + lh + 0.1, (0, W_LINTEL - 0.08), jitter(BRICK_PALE, rng, 6),
              "Brick", flags=DECOR)
        n += 2
    elif lt == "keystone":
        lc = jitter(sur, rng, 4)
        kw = rng.uniform(0.45, 0.6)
        _zbox(f, "Lintel", lx0, -kw / 2, y + h, y + h + lh, (0, W_LINTEL), lc, smat, flags=DECOR)
        _zbox(f, "Lintel", kw / 2, lx1, y + h, y + h + lh, (0, W_LINTEL), jitter(lc, rng, 3), smat, flags=DECOR)
        _zbox(f, "Keystone", -kw / 2, kw / 2, y + h - 0.12, y + h + lh + 0.1, (0, W_LINTEL + 0.08), jitter(lc, rng, 4),
              smat, flags=DECOR)
        n += 3
    else:  # cast concrete, cracked through and settled a little on one side
        cx = rng.uniform(-w / 4, w / 4)
        lc = jitter(CONCRETE, rng, 6)
        _zbox(f, "Lintel", lx0, cx - 0.025, y + h, y + h + lh, (0, W_LINTEL), lc, "Concrete", flags=DECOR)
        f.part("Lintel", ((cx + 0.025 + lx1) / 2, y + h + lh / 2 - 0.015, -W_LINTEL / 2), (lx1 - cx - 0.05, lh, W_LINTEL),
               jitter(lc, rng, 3), "Concrete", rot=(0, 0, rng.uniform(-0.7, -0.3) * (1 if cx > 0 else -1)), flags=DECOR)
        n += 2
    # --- stains: run-off from the sill horns, soot over the lintel (on the wall, in its slots)
    for s in rng.sample((-1, 1), rng.randint(1, 2)):
        n += streak(f, rng, "SillStain", s * (ox + rng.uniform(0.0, 0.12)), y - 0.32, rng.uniform(1.4, 3.2),
                    rng.uniform(0.25, 0.4), DAMP, k=0, tr=0.62, taper=2)
    if rng.random() < 0.45:
        n += soft(f, rng, "Soot", lx0 + 0.1, lx1 - 0.1, y + h + lh + 0.12, y + h + lh + rng.uniform(1.0, 2.0), SOOT,
                  opacity=0.2, k=0, anchor="bottom")
    ix0, ix1 = -w / 2, w / 2  # the opening inside the surround
    if variant == "boarded":
        # two plywood sheets butting (one older, darker, water-stained), planks nailed across
        split = y + h * rng.uniform(0.35, 0.6)
        ply_lo, ply_hi = jitter((92, 80, 60), rng, 8), jitter((122, 104, 76), rng, 8)
        _zbox(f, "Plywood", ix0, ix1, y, split, W_BOARD, ply_lo, "WoodPlanks", flags=DECOR)
        _zbox(f, "Plywood", ix0, ix1, split, y + h, W_BOARD, ply_hi, "WoodPlanks", flags=DECOR)
        n += 2
        planks = rng.randint(2, 3)
        for i in range(planks):
            py = y + 0.7 + (h - 1.4) * (i + rng.uniform(0.2, 0.8)) / planks
            ln = 2 * ox + rng.uniform(0.3, 0.7)
            ang = rng.uniform(-9, 9)
            z0 = W_SURROUND + 0.06 + 0.07 * i  # each plank its own depth: crossing ones never share a face
            g = f.sub((rng.uniform(-0.12, 0.12), py, -(z0 + 0.03)), rz=ang)
            ph = rng.uniform(0.4, 0.6)
            g.part("Plank", (0, 0, 0), (ln, ph, 0.06), jitter(rng.choice([WOOD_OLD, WOOD, WOOD_DARK]), rng, 8), "Wood",
                   flags=DECOR)
            n += 1
            for e in (-1, 1):
                bolt(g, "Nail", (e * (ox - sw / 2), rng.uniform(-0.1, 0.1), -0.03), 0.07, (60, 56, 52))
                n += 1
        z_spray = W_SURROUND + 0.06 + 0.07 * planks + 0.1
        words, ink = rng.choice(["KEEP OUT", "X", "CONDEMNED", "NO ENTRY"]), jitter((170, 60, 50), rng, 10)
        if y > 9:
            return n  # (texts audit S0: nobody reads a spray on an upper floor; the boards stay bare)
        # sprayed across the boards, readable from the alley: at least 3:1 on the plywood (red on
        # brown wood was 1.1-1.8:1), the carrier no wider than the opening
        ink = readable_ink(ink, mix(ply_lo, ply_hi, 0.5), need=3.5)
        sw_, sh_ = w * 0.9, h * 0.3
        words, pps, _ = wall_text(words, "PermanentMarker", sw_, sh_, pad=[0.05, 0.08])
        f.part("Spray", (0, y + h * 0.55, -z_spray), (sw_, sh_, 0.05), (0, 0, 0), "SmoothPlastic",
               transparency=1, flags=DECOR,
               extra=sign_extra(words, ink, pps=pps, pad=[0.05, 0.08], textTr=0.04))
        return n + 1
    # --- the box frame (head and bottom full width, sides between: butt joints)
    fw = 0.24 if style == "upvc" else 0.2
    _zbox(f, "Frame", ix0, ix1, y + h - fw, y + h, W_BOX, fc, fmat, flags=DECOR)
    _zbox(f, "Frame", ix0, ix1, y, y + fw, W_BOX, jitter(mix(fc, WOOD_DARK, 0.35), rng, 4), fmat, flags=DECOR)
    for s in (-1, 1):
        _zbox(f, "Frame", min(s * ix1, s * (ix1 - fw)), max(s * ix1, s * (ix1 - fw)), y + fw, y + h - fw, W_BOX,
              jitter(fc, rng, 2), fmat, flags=DECOR)
    n += 4
    ox0, ox1, oy0, oy1 = ix0 + fw, ix1 - fw, y + fw, y + h - fw  # the clear opening
    # --- the room behind
    if lit:
        _zbox(f, "Room", ox0, ox1, oy0, oy1, W_PANEL, (30, 32, 34), "Glass", flags=DECOR,
              extra={"t": ["CityWindowLit"], "a": {"Kind": kind, "Day": True},
                     "l": {"type": "Point", "color": list(WARM), "range": 12, "brightness": 0.45, "name": "Light",
                           "shadows": False}})
    else:
        _zbox(f, "Void", ox0, ox1, oy0, oy1, W_PANEL, VOID, "SmoothPlastic", flags=DECOR)
    n += 1
    gc = jitter(rng.choice(GLASS_DIRTY), rng, 4)
    if style == "frosted":
        gc = jitter((150, 154, 148), rng, 6)
    low_gc = jitter(mix(gc, (52, 46, 36), 0.35), rng, 3)  # grime crusted low down: in the colour
    gtr = 0.15 if style == "frosted" else (0.45 if lit else 0.3)
    # --- glazing: [(x0, x1, y0, y1, glass depths, colour)] panes, built with their bars / rails
    panes = []
    mid = oy0 + (oy1 - oy0) * rng.uniform(0.47, 0.55)
    raise_ = 0.0
    if style.startswith("sash") or style == "frosted":
        mr = 0.09  # half a meeting rail
        if variant == "dirty" and rng.random() < 0.35:
            raise_ = rng.uniform(0.3, (mid - oy0) * 0.5)  # the lower sash pushed up a little
        # upper sash (outer): top rail + meeting rail
        _zbox(f, "Sash", ox0, ox1, oy1 - 0.12, oy1, W_UPPER, jitter(fc, rng, 3), fmat, flags=DECOR)
        _zbox(f, "Sash", ox0, ox1, mid, mid + 2 * mr, W_UPPER, jitter(fc, rng, 3), fmat, flags=DECOR)
        # lower sash (inner): meeting rail + bottom rail, moved up by raise_
        _zbox(f, "Sash", ox0, ox1, mid - 2 * mr + raise_ + 0.0, mid + raise_, W_LOWER, jitter(fc, rng, 3), fmat,
              flags=DECOR)
        _zbox(f, "Sash", ox0, ox1, oy0 + raise_, oy0 + 0.18 + raise_, W_LOWER, jitter(mix(fc, WOOD_DARK, 0.2), rng, 3),
              fmat, flags=DECOR)
        n += 4
        bars = 1 if style == "sash22" else 0
        for (a, b, z, sash_z, col) in ((mid + 2 * mr, oy1 - 0.12, W_UGLASS, W_UPPER, gc),
                                       (oy0 + 0.18 + raise_, mid - 2 * mr + raise_, W_LGLASS, W_LOWER, low_gc)):
            if bars:
                _zbox(f, "GlazingBar", -0.04, 0.04, a, b, sash_z, jitter(fc, rng, 3), fmat, flags=DECOR)
                n += 1
                panes += [(ox0, -0.04, a, b, z, col), (0.04, ox1, a, b, z, col)]
            else:
                panes.append((ox0, ox1, a, b, z, col))
    else:  # casement / uPVC: one frame plane, a transom (and a mullion for the casement)
        tr_y = oy0 + (oy1 - oy0) * rng.uniform(0.7, 0.78)
        zc = (W_LOWER[0], W_UPPER[1])
        _zbox(f, "Transom", ox0, ox1, tr_y, tr_y + 0.16, zc, jitter(fc, rng, 3), fmat, flags=DECOR)
        n += 1
        panes.append((ox0, ox1, tr_y + 0.16, oy1, W_UGLASS, gc))
        if style == "casement":
            _zbox(f, "Mullion", -0.08, 0.08, oy0, tr_y, zc, jitter(fc, rng, 3), fmat, flags=DECOR)
            n += 1
            panes += [(ox0, -0.08, oy0, tr_y, W_UGLASS, low_gc), (0.08, ox1, oy0, tr_y, W_UGLASS, low_gc)]
        else:
            panes.append((ox0, ox1, oy0, tr_y, W_UGLASS, low_gc))
    # --- what hangs inside (between the room and the glass)
    inner = "none"
    if lit:
        inner = rng.choice(["curtain", "curtain", "blind"])
    elif variant in ("dirty", "broken", "barred") and style != "frosted":
        inner = rng.choice(["blind", "blind", "sheet", "cardboard", "none"])
    if inner == "curtain":
        cc = jitter(rng.choice([(110, 52, 44), (60, 70, 60), (120, 108, 84), (70, 60, 84)]), rng, 8)
        for s in (-1, 1):
            if s == 1 and rng.random() < 0.4:
                continue  # one side drawn back fully
            cw = (ox1 - ox0) * rng.uniform(0.18, 0.38)
            _zbox(f, "Curtain", min(s * ox1, s * (ox1 - cw)), max(s * ox1, s * (ox1 - cw)), oy0 + rng.uniform(0, 0.4),
                  oy1, W_INNER, jitter(cc, rng, 4), "Fabric", flags=DECOR)
            n += 1
    elif inner == "blind":
        stop = oy1 - (oy1 - oy0) * rng.uniform(0.35, 0.85)
        slat = 0.17
        yy = oy1 - 0.02
        i = 0
        bc = jitter((150, 146, 128), rng, 6)
        while yy - slat > stop and i < 9:
            _zbox(f, "Blind", ox0, ox1, yy - slat, yy, W_INNER, jitter(bc, rng, 2, 0.04 * (i % 2)), "SmoothPlastic",
                  flags=DECOR)
            n += 1
            yy -= slat + 0.055
            i += 1
        # the bottom rail hangs askew from one broken cord (clear of the slats and the frame)
        hl = (ox1 - ox0) * 0.42
        cy_ = yy - 0.32
        if cy_ - 0.3 > oy0:
            tilt = math.degrees(math.asin(min(0.2, 0.18 / hl))) * rng.choice((-1, 1))
            g = f.sub(((ox0 + ox1) / 2 + rng.uniform(-0.1, 0.1), cy_, -(W_INNER[0] + W_INNER[1]) / 2), rz=tilt)
            g.part("Blind", (0, 0, 0), (2 * hl, 0.12, 0.02), jitter(bc, rng, 3, 0.1), "SmoothPlastic", flags=DECOR)
            n += 1
    elif inner == "sheet":
        sh0 = oy0 + (oy1 - oy0) * rng.uniform(0.1, 0.4)
        g = f.sub(((ox0 + ox1) / 2, (sh0 + oy1) / 2, -(W_INNER[0] + W_INNER[1]) / 2), rz=rng.uniform(-2, 2))
        g.part("Sheet", (0, 0, 0), ((ox1 - ox0) * 0.94, (oy1 - sh0) * 0.96, 0.02), jitter((96, 92, 80), rng, 8),
               "Fabric", flags=DECOR)
        n += 1
    elif inner == "cardboard":  # taped over the lower pane
        _zbox(f, "Cardboard", ox0 + 0.04, ox1 - 0.04, oy0 + 0.05, mid - 0.05, W_INNER, jitter((120, 96, 64), rng, 8),
              "Cardboard", flags=DECOR)
        n += 1
    # --- the glass
    if variant == "broken":
        gone = rng.randrange(len(panes))
        for i, (a, b, c, d, z, col) in enumerate(panes):
            if i != gone:
                _zbox(f, "Glass", a, b, c, d, z, col, "Glass", transparency=gtr, flags=DECOR)
                n += 1
                if i == (gone + 1) % len(panes) and d - c > 0.6:  # cracked: two light lines
                    zc_ = (z[1] + 0.07, z[1] + 0.09)  # (in front of its glass, clear of the rails)
                    for _ in range(2):
                        p0 = (rng.uniform(a + 0.1, b - 0.1), rng.uniform(c + 0.1, d - 0.1))
                        p1 = (min(b - 0.05, max(a + 0.05, p0[0] + rng.uniform(-0.6, 0.6))),
                              min(d - 0.05, max(c + 0.05, p0[1] + rng.uniform(-0.6, 0.6))))
                        if math.dist(p0, p1) > 0.2:
                            beam(f, "GlassCrack", (p0[0], p0[1], -(zc_[0] + zc_[1]) / 2),
                                 (p1[0], p1[1], -(zc_[0] + zc_[1]) / 2), 0.03, zc_[1] - zc_[0], (150, 156, 150),
                                 "SmoothPlastic", flags=DECOR)
                            n += 1
                continue
            # shards left in the frame: triangles in the pane's own plane, in its corners
            pw, ph = b - a, d - c
            for cx_, cy_ in rng.sample([(-1, -1), (1, -1), (1, 1), (-1, 1)], rng.randint(2, 3)):
                px = a if cx_ < 0 else b
                py = c if cy_ < 0 else d
                tri_part(f, "Shard", px, py, -cx_ * rng.uniform(0.22, 0.45) * pw, -cy_ * rng.uniform(0.25, 0.45) * ph,
                         z[0], z[1], col, "Glass", transparency=gtr, flags=DECOR)
                n += 1
    else:
        for (a, b, c, d, z, col) in panes:
            _zbox(f, "Glass", a, b, c, d, z, jitter(col, rng, 2), "Glass", transparency=gtr, flags=DECOR)
            n += 1
    if variant == "barred":
        # flat bars on lugs into the wall, round bars through them, rust running from the lugs
        fz = (W_SILL, W_SILL + 0.14)
        lugx = ox + 0.22
        for yy in (y + 0.45, y + h - 0.45):
            _zbox(f, "FlatBar", -lugx - 0.1, lugx + 0.1, yy - 0.09, yy + 0.09, fz, jitter(RUST, rng, 6), "CorrodedMetal",
                  flags=DECOR_SHADOW)
            n += 1
            for s in (-1, 1):
                _zbox(f, "Lug", s * lugx - 0.08, s * lugx + 0.08, yy - 0.09, yy + 0.09, (0, W_SILL), RUST_DARK,
                      "CorrodedMetal", flags=DECOR)
                n += 1
        bars = max(3, int(w / 0.62))
        bz = -(fz[0] + fz[1]) / 2
        for i in range(bars):
            bx = -w / 2 + (i + 0.5) * w / bars
            rod(f, "Bar", (bx, y + 0.15, bz), (bx + rng.uniform(-0.03, 0.03), y + h - 0.15, bz), 0.12,
                jitter(RUST_DARK, rng, 6), "CorrodedMetal", flags=DECOR_SHADOW)
            n += 1
        s = rng.choice((-1, 1))
        n += streak(f, rng, "RustStreak", s * lugx, y + 0.45 - 0.12, rng.uniform(1.2, 2.4), 0.3, RUST_STAIN, k=1,
                    taper=2)
    return n


def back_door(D, folder, origin, ry, rng, width=4.0, height=7.6, variant="closed", light=True, x=0.0,
              stencil=None, color=None, dead_light=False):
    """A steel service door set in a deep pressed-steel frame: concrete step (chipped, its back
    half wet and darker), the frame standing out of the wall (the door sits 0.36 back in it, in
    front of every stain slot), painted leaf with a worn, rusty free edge where hands and kicks
    hit it, diamond-plate kick plate, pull handle, deadlock, hinges, a closer with its arm,
    stencilled warning, grime on the wall either side (hands, shoulders), rust run from the
    frame, and a caged bulkhead light above (optional).
    Variants: "closed", "ajar" (swung out 12-25 deg, dark corridor behind), "chained"
    (a chain and padlock across the handle and a hasp). Footprint: (width + 1.2) x 1.4 deep,
    (height + 2.5) tall with the light. Parts: 26-40."""
    f = frame_at(D, folder, origin, ry).sub((x, 0, 0))
    w, h = width, height
    paint = color or jitter(rng.choice(STEEL_PAINT), rng, 6)
    n = 0
    # step: two halves (the back one wet, darker), a chipped corner
    st = f.sub((rng.uniform(-0.1, 0.1), 0, 0))  # (square to the wall: its back face lies on it)
    sc = jitter(CONCRETE, rng, 6)
    st.box("Step", (-(w + 1.2) / 2, 0, -0.62), ((w + 1.2) / 2, 0.45, 0), jitter(mix(sc, WET_DARK, 0.3), rng, 3),
           "Concrete", flags=SOLID)
    st.box("Step", (-(w + 1.2) / 2, 0, -1.36), ((w + 1.2) / 2, 0.45, -0.62), sc, "Concrete", flags=SOLID)
    f.part("StepChip", ((w / 2 + 0.45) * rng.choice((-1, 1)), 0.33, -1.33), (0.5, 0.3, 0.3), jitter(CONCRETE_DARK, rng, 6),
           "Concrete", rot=(rng.uniform(-20, 20), rng.uniform(0, 90), rng.uniform(-15, 15)), flags=DECOR)
    n += 3
    # the opening (dark corridor), the frame: jambs and head butt, 0.46 deep (the leaf sits inside
    # it, in front of every overlay slot; a dumpster can still stand against the wall beside it)
    fd = 0.46
    _zbox(f, "Void", -w / 2, w / 2, 0.45, h, (0.29, 0.32), VOID, "SmoothPlastic", flags=DECOR)
    fcol = jitter(METAL_DARK, rng, 6)
    for s in (-1, 1):
        _zbox(f, "DoorFrame", min(s * w / 2, s * (w / 2 + 0.32)), max(s * w / 2, s * (w / 2 + 0.32)), 0.45, h, (0, fd),
              jitter(fcol, rng, 3), "Metal", flags=DECOR)
    _zbox(f, "DoorFrame", -w / 2 - 0.32, w / 2 + 0.32, h, h + 0.32, (0, fd), jitter(fcol, rng, 3), "Metal", flags=DECOR)
    n += 4
    # the leaf (in its own frame about the hinge, left side; its front face at the frame's z 0)
    angle = rng.uniform(12, 25) if variant == "ajar" else 0.0
    g = f.sub((-w / 2 + 0.04, 0.47, -0.43), ry=angle)
    lw, lh = w - 0.1, h - 0.52
    edge = rng.uniform(0.18, 0.28)  # the free edge: paint worn off, rust, hand grime
    leaf = g.box("DoorLeaf", (0, 0, 0), (lw - edge, lh, 0.08), paint, "Metal", flags=SOLID)
    g.box("DoorLeaf", (lw - edge, 0, 0), (lw, lh, 0.08), jitter(mix(paint, RUST_DARK, 0.45), rng, 4), "CorrodedMetal",
          flags=SOLID)
    g.box("KickPlate", (0.1, 0.05, -0.08), (lw - 0.1, 1.25, 0), jitter(mix(GALV, RUST_DARK, 0.25), rng, 6, 0.1),
          "DiamondPlate", flags=DECOR)
    n += 3
    # hardware: pull handle, deadlock, hinges, closer (round rods)
    rod(g, "Handle", (lw - 0.55, 3.0, -0.2), (lw - 0.55, 4.0, -0.2), 0.1, jitter(GALV, rng, 6, 0.1), "Metal",
        flags=DECOR)
    for yy in (3.05, 3.95):
        rod(g, "HandleMount", (lw - 0.55, yy, 0), (lw - 0.55, yy, -0.2), 0.08, METAL_DARK, "Metal", flags=DECOR)
    g.box("Lock", (lw - 0.69, 4.39, -0.08), (lw - 0.41, 4.81, 0), jitter(GALV, rng, 6), "Metal", flags=DECOR)
    n += 4
    for yy in (0.6, lh / 2, lh - 0.6):
        rod(g, "Hinge", (-0.06, yy - 0.3, 0.0), (-0.06, yy + 0.3, 0.0), 0.16, METAL_DARK, "Metal", flags=DECOR)
        n += 1
    g.box("Closer", (0.4, lh - 0.49, -0.22), (1.4, lh - 0.21, 0), jitter(METAL, rng, 6), "Metal", flags=DECOR)
    beam(g, "CloserArm", (1.35, lh - 0.35, -0.28), (1.6, lh + 0.05, -0.28), 0.08, 0.06, METAL_DARK, "Metal",
         side=(0, 0, 1), flags=DECOR)
    n += 2
    # the stencil (texts audit T01 / T02): in the free band between the deadlock (top 4.81) and the
    # closer (lh - 0.49), centred on the painted part of the leaf (not its worn free edge), on two
    # lines at its separator when it has one, 0.02 thick and 0.02 off the leaf, sharp, worn paint;
    # parented to the leaf (it swings and breaks with it)
    words = stencil or rng.choice(["NO ENTRY", "FIRE EXIT · KEEP CLEAR", "PRIVATE", "DELIVERIES", "NO LOITERING"])
    ink = jitter((168, 160, 140), rng, 8)
    for sep in (" · ", " - "):
        if sep in words:
            words = words.replace(sep, "\n", 1)
            break
    sw_, sh_ = min(2.6, lw - edge - 0.5), (1.0 if "\n" in words else 0.7)
    pad = [0.06, 0.08 if "\n" in words else 0.1]
    g.part("Stencil", ((lw - edge) / 2, lh - 1.4, -0.03), (sw_, sh_, 0.02), (0, 0, 0), "SmoothPlastic",
           transparency=1, flags=DECOR, parent=leaf,
           extra=sign_extra(words, ink, font="Oswald", pps=textfit.fit_pps(words, "Oswald", sw_, sh_, pad), pad=pad,
                            textTr=0.1))
    n += 1
    if variant == "chained":
        pts = [(lw - 0.55, 3.6, -0.3), (lw - 0.2, 3.25, -0.34), (lw + 0.15, 3.35, -0.36), (lw + 0.45, 3.5, -0.34)]
        n += bend(g, "Chain", pts, 0.08, jitter(GALV, rng, 4, 0.2), "Metal", flags=DECOR)
        g.box("Padlock", (lw + 0.18, 2.75, -0.44), (lw + 0.46, 3.15, -0.3), jitter((120, 100, 50), rng, 8), "Metal",
              flags=DECOR)
        _zbox(f, "Hasp", w / 2 + 0.04, w / 2 + 0.3, 3.3, 3.7, (fd, fd + 0.1), RUST_DARK, "CorrodedMetal", flags=DECOR)
        n += 2
    # rust bleeding from the frame head, wall grime either side of the frame (hands, shoulders)
    n += streak(f, rng, "RustStreak", (w / 2 + 0.32 + 0.32) * rng.choice((-1, 1)), h + 0.2, rng.uniform(1.2, 2.4), 0.4,
                RUST_STAIN, k=1, taper=3)
    for s in (-1, 1):
        a, b = w / 2 + 0.32, w / 2 + 0.32 + rng.uniform(0.5, 1.0)
        n += soft(f, rng, "Grime", min(s * a, s * b), max(s * a, s * b), 0.45, rng.uniform(2.6, 3.8), DAMP, opacity=0.3,
                  k=0, anchor="bottom")
    if light:
        dx = rng.uniform(-0.3, 0.3)
        at, a = f.world((dx, 0, 0)), ry_of(f)
        box = []
        lib_meshprop(D, folder, "BulkheadLightDead" if dead_light else "BulkheadLight",
                     tuple(float(v) for v in f.world((dx, h + 1.4, 0))), a,
                     lambda: box.append(bulkhead_light(D, folder, at, a, rng, y=h + 1.4, dead=dead_light)))
        n += box[0]
    return n


def ry_of(f):
    """The turn about Y of a frame (for passing a sub-frame on to another builder)."""
    return math.degrees(math.atan2(f.m[0, 2], f.m[2, 2]))


def roller_shutter(D, folder, origin, ry, rng, width=8.0, height=7.0, open_height=0.0, x=0.0, tag=True,
                   color=None):
    """A steel roller shutter (garage / shop back): a coil hood with a rounded front between two
    end plates, L-section guide rails, a curtain of curved slats (each slat two wedges back to
    back, so the corrugation catches the light in ridges; one dented), the low slats rusted and
    grimed (their own colours: no stain film over the ridges), bottom bar with a rubber seal,
    lift handle, ground lock and padlock, often a tag. open_height > 0 leaves it jammed
    part-open on a dark gap. Footprint: (width + 0.8) x 1.2 deep x (height + 1.4). Parts: 24-40."""
    f = frame_at(D, folder, origin, ry).sub((x, 0, 0))
    w, h = width, height
    base = color or jitter(rng.choice([GALV, (84, 88, 86), (70, 76, 84), (96, 70, 56)]), rng, 6)
    n = 0
    # coil hood: a box, a half-round front (a cylinder along X) and end plates over both ends
    hz = 0.9
    hood = jitter(base, rng, 4, 0.12)
    _zbox(f, "Housing", -w / 2 - 0.35, w / 2 + 0.35, h, h + 1.3, (0, hz), hood, "Metal", flags=DECOR_SHADOW)
    f.part("Housing", (0, h + 0.65, -hz), (w + 0.7, 1.3, 1.3), jitter(hood, rng, 2), "Metal", shape=CYLINDER,
           flags=DECOR)
    for s in (-1, 1):
        a, b = s * (w / 2 + 0.35), s * (w / 2 + 0.47)
        _zbox(f, "EndPlate", min(a, b), max(a, b), h - 0.05, h + 1.4, (0, hz + 0.72), METAL_DARK, "Metal", flags=DECOR)
        # guide: an L (outer flange to the wall, front lip over the slat ends)
        _zbox(f, "Guide", min(s * (w / 2 + 0.05), s * (w / 2 + 0.17)), max(s * (w / 2 + 0.05), s * (w / 2 + 0.17)), 0,
              h - 0.05, (0, 0.62), jitter(METAL_DARK, rng, 4), "Metal", flags=DECOR)
        _zbox(f, "Guide", min(s * (w / 2 - 0.12), s * (w / 2 + 0.05)), max(s * (w / 2 - 0.12), s * (w / 2 + 0.05)), 0,
              h - 0.05, (0.56, 0.62), jitter(METAL_DARK, rng, 4), "Metal", flags=DECOR)
        n += 3
    n += 2
    y0 = open_height
    if y0 > 0:
        _zbox(f, "Void", -w / 2 + 0.05, w / 2 - 0.05, 0, y0, (0.29, 0.32), VOID, "SmoothPlastic", flags=DECOR)
        n += 1
    # bottom bar + rubber seal
    # (the curtain hangs in front of every overlay slot, its back 0.34 out: the wall's stains
    # run behind it without sharing a plane with a slat)
    zb, zr = 0.34, 0.52
    # (both end inside the guides' lips: no end face beside a lip face)
    _zbox(f, "Seal", -w / 2 + 0.13, w / 2 - 0.13, y0, y0 + 0.07, (zb, zr + 0.04), (24, 24, 24), "Rubber", flags=DECOR)
    _zbox(f, "BottomBar", -w / 2 + 0.13, w / 2 - 0.13, y0 + 0.07, y0 + 0.32, (zb, zr + 0.07),
          jitter(METAL_DARK, rng, 4),
          "Metal", flags=SOLID)
    n += 2
    # the curtain: slats of two wedges (a ridge pointing out), back at zb, ridge at zr
    slat = rng.uniform(0.6, 0.72)
    sy0 = y0 + 0.32
    count = max(3, int((h - 0.05 - sy0) / slat))
    slat = (h - 0.05 - sy0) / count
    dent = rng.randrange(count)
    for i in range(count):
        a = sy0 + i * slat
        t = i / max(1, count - 1)
        grime = max(0.0, 0.5 - t) * 0.6  # darker and rustier toward the ground
        rusty = i < 2 and rng.random() < 0.7
        c = jitter(mix(base, RUST if rusty else WET_DARK, grime + (0.25 if rusty else 0.0)), rng, 3, 0.03 * (i % 2))
        mat = "CorrodedMetal" if rusty else "Metal"
        flags = SOLID if i == 0 or i == count - 1 else SMALL
        dz = 0.05 if i == dent else 0.0  # (the dented slat pushed in: its own planes)
        g = f.sub((0, a + slat / 2, -zb + dz))
        # upper half: wedge, its full face down at the ridge line, slope up to the back
        g.part("Slat", (0, slat / 4, -(zr - zb) / 2), (w, slat / 2, zr - zb), c, mat, shape=WEDGE, flags=flags)
        # lower half: the same flipped (upside down)
        g.part("Slat", (0, -slat / 4, -(zr - zb) / 2), (w, slat / 2, zr - zb), jitter(c, rng, 2, 0.06), mat,
               rot=(0, 0, 180), shape=WEDGE, flags=flags)
        n += 2
    # lift handle on two blocks, ground lock + padlock
    for hx in (-0.5, 0.5):
        _zbox(f, "HandleMount", hx - 0.05, hx + 0.05, y0 + 0.12, y0 + 0.24, (zr + 0.07, zr + 0.21), METAL_DARK, "Metal",
              flags=DECOR)
    rod(f, "LiftHandle", (-0.56, y0 + 0.18, -(zr + 0.26)), (0.56, y0 + 0.18, -(zr + 0.26)), 0.1, GALV, "Metal",
        flags=DECOR)
    n += 3
    if y0 == 0:
        lx = rng.choice((-1, 1)) * w * 0.3
        _zbox(f, "GroundLock", lx - 0.15, lx + 0.15, 0, 0.24, (zr + 0.07, zr + 0.37), METAL_DARK, "Metal", flags=DECOR)
        f.part("Padlock", (lx, 0.42, -(zr + 0.3)), (0.26, 0.34, 0.12), jitter((120, 100, 50), rng, 8), "Metal",
               rot=(0, _signed(rng, 6, 20), _signed(rng, 3, 8)), flags=DECOR)
        n += 2
    if tag:
        # (texts audit S0: its own line breaks, sharp, +-4 deg, at least 3:1 on the slats)
        tx, ty, trz = rng.uniform(-w / 6, w / 6), y0 + (h - y0) * 0.55, rng.uniform(-5, 5) * 0.8
        words = rng.choice(GRAFFITI_TAGS)
        ink = readable_ink(jitter(rng.choice([(180, 176, 160), (170, 60, 50), (30, 30, 30)]), rng, 10), base,
                           need=3.5)
        tw, th = w * 0.75, (h - y0) * 0.35
        words, pps, _ = wall_text(words, "PermanentMarker", tw, th)
        f.part("Graffiti", (tx, ty, -(zr + 0.08)), (tw, th, 0.05), (0, 0, 0), "SmoothPlastic", rot=(0, 0, trz),
               transparency=1, flags=DECOR,
               extra=sign_extra(words, ink, pps=pps, pad=[0.04, 0.06], textTr=0.04))
        n += 1
    # rust run from the hood's screws onto the wall beside the guides
    n += streak(f, rng, "RustStreak", rng.choice((-1, 1)) * (w / 2 + 0.5), h - 0.1, rng.uniform(1.0, 2.2), 0.3,
                RUST_STAIN, k=1, taper=3)
    return n


# =================================================================================================
# 3. Structure: fire escape, building top, background facade, fence
# =================================================================================================


# Units standing out of a wall: a stain running down from above stops on top of them.
_UNIT_NAMES = {"Jamb", "Lintel", "Keystone", "Sill", "DoorFrame", "Casing", "Cabinet", "Housing", "Duct", "Cowl",
               "BackPlate", "JunctionBox", "Gutter"}


def _blocked_below(f, x0, x1, y_top):
    """The top of the highest window / door unit already built on this wall (frame f) under the
    strip x0..x1 below y_top, or -inf. (Stains from higher up stop above it: the unit stands out
    of the wall and would hide them anyway.)"""
    best = -1e9
    ids = {i + 1 for i, nm in enumerate(f.D.names) if nm in _UNIT_NAMES}
    if not ids:
        return best
    for row in f.D.parts:
        if row[16] not in ids:
            continue
        loc = f.m.T @ (np.array(row[1:4], float) - f.origin)
        if abs(loc[2]) > 1.5:
            continue
        hx, hy = row[7] / 2 + 0.05, row[8] / 2
        # (units are built square to their wall: the row's X / Z extent along the wall)
        if row[5] % 180 != 0:
            hx = row[9] / 2 + 0.05
        if loc[0] + hx < x0 or loc[0] - hx > x1:
            continue
        top_ = loc[1] + hy
        if top_ < y_top and top_ > best:
            best = top_
    return best


def fire_escape(D, folder, origin, ry, rng, width=12.0, floors=3, floor_h=10.0, depth=3.6, ladder=True):
    """A steel fire escape for a wall of `floors` floors: an open slatted landing at each upper
    floor (flat bars on edge with gaps you see through, framed by a fascia channel), on
    diagonal brackets; a railing of posts, top and mid rails and thin balusters; a steep stair
    between landings (channel stringers, treads, handrail) through a hatch, alternating sides;
    a drop ladder hooked up under the first landing. Thick black paint, rust running down the
    wall from every bracket. Slats and treads are SOLID (walkable; the gaps are too narrow to
    fall through). Footprint: width x depth, floors * floor_h tall. Parts: ~45-110."""
    f = frame_at(D, folder, origin, ry)
    n = 0
    steel = jitter(rng.choice([(36, 36, 36), (48, 42, 36), (42, 46, 44)]), rng, 4)
    rail_h = 3.2
    run = floor_h / math.tan(math.radians(58))
    sw = 2.0  # stair band (outer side of the landing)
    landings = list(range(1, floors))
    pitch, slat_w = 0.36, 0.24  # flat bars 0.24 wide every 0.36 (0.12 gaps)
    for li, k in enumerate(landings):
        y = k * floor_h
        hatch = None
        if li > 0:  # the flight from the landing below arrives here: hatch in the outer band
            d = 1 if (li - 1) % 2 == 0 else -1
            x_bot = d * (width / 2 - 0.6)
            x_top = x_bot - d * run
            hatch = (min(x_bot, x_top) - 0.2, max(x_bot, x_top) + 0.2)
        # the deck: slats along X from the wall out to the fascia
        zs = -0.46
        i = 0
        while zs - slat_w > -depth + 0.02:
            z1, z0 = zs, zs - slat_w
            outer = z0 < -(depth - sw)
            spans = [(-width / 2, width / 2)]
            if hatch is not None and outer:
                spans = [(-width / 2, hatch[0]), (hatch[1], width / 2)]
            for a, b in spans:
                if b - a > 0.3:
                    f.box("Landing", (a, y - 0.12, z0), (b, y, z1), jitter(steel, rng, 2, 0.04 * (i % 3 == 0)), "Metal",
                          flags=SOLID)
                    n += 1
            zs -= pitch
            i += 1
        # the frame round it: a fascia channel in front, a wall angle behind (under the slats)
        f.box("Fascia", (-width / 2, y - 0.45, -depth - 0.08), (width / 2, y + 0.18, -depth), steel, "Metal",
              flags=DECOR)
        f.box("WallAngle", (-width / 2, y - 0.3, -0.34), (width / 2, y, 0), steel, "Metal", flags=SOLID)
        n += 2
        # brackets (diagonal struts under the deck) and the rust they bleed down the wall
        for bx in (-width / 2 + 0.6, width / 2 - 0.6):
            beam(f, "Bracket", (bx, y - 0.4, -depth + 0.3), (bx, y - 2.8, -0.1), 0.18, 0.18, steel, "Metal",
                 side=(1, 0, 0), flags=DECOR_SHADOW)
            n += 1
            n += streak(f, rng, "RustStreak", bx, y - 2.95, rng.uniform(2.5, 5), 0.5, RUST_STAIN, k=0, taper=3)
        # railing: posts stop under the top rail; rails in front of the posts' faces (0.07 proud)
        posts = [-width / 2 + 0.08, -width / 6, width / 6, width / 2 - 0.08]
        for px in posts:
            f.box("Post", (px - 0.08, y + 0.18, -depth), (px + 0.08, y + rail_h - 0.08, -depth + 0.12), steel, "Metal",
                  flags=DECOR_SHADOW)
            n += 1
        f.box("TopRail", (-width / 2, y + rail_h - 0.08, -depth - 0.07), (width / 2, y + rail_h + 0.08, -depth + 0.05),
              steel, "Metal", flags=PROP)
        f.box("MidRail", (-width / 2, y + rail_h * 0.5 - 0.06, -depth - 0.07), (width / 2, y + rail_h * 0.5 + 0.06,
                                                                                 -depth + 0.05), steel, "Metal",
              flags=DECOR_SHADOW)
        n += 2
        for s in (-1, 1):  # end rails butt against the top rail's back and run into the wall
            f.box("EndRail", (s * width / 2 - 0.08, y + rail_h - 0.15, -depth + 0.12),
                  (s * width / 2 + 0.08, y + rail_h, 0.12), steel, "Metal", flags=PROP)
            n += 1
        # balusters (thin round bars) along the front and the ends, from the fascia top to the top rail
        bal = []
        x = -width / 2 + 0.5
        while x < width / 2 - 0.3:
            if all(abs(x - p) > 0.2 for p in posts):
                bal.append((x, -depth + 0.03))
            x += rng.uniform(1.1, 1.3)
        for s in (-1, 1):
            zz = -depth + 0.7
            while zz < -0.4:
                bal.append((s * width / 2, zz))
                zz += rng.uniform(1.0, 1.2)
        for bx, bz in bal:
            rod(f, "Baluster", (bx, y + 0.18 if bz < -depth + 0.1 else y, bz), (bx, y + rail_h - 0.08, bz), 0.07, steel,
                "Metal", flags=DECOR)
            n += 1
        # junk left on the landing: a crate (people use these as balconies), clear of the hatch
        if rng.random() < 0.6:
            jx = rng.uniform(-width / 2 + 1, width / 2 - 1)
            if hatch is None or not (hatch[0] - 0.8 < jx < hatch[1] + 0.8):
                f.part("Crate", (jx, y + 0.5, -0.9), (1.2, 1.0, 1.0), jitter(WOOD_OLD, rng, 8), "WoodPlanks",
                       rot=(0, rng.uniform(-15, 15), 0), flags=SMALL)
                n += 1
    # flights between landings
    for li in range(len(landings) - 1):
        y0 = landings[li] * floor_h
        d = 1 if li % 2 == 0 else -1
        x_bot = d * (width / 2 - 0.6)
        x_top = x_bot - d * run
        for zs in (-depth + 0.15, -depth + sw - 0.15):
            # (its sides a few degrees off the slats' edges: never parallel to one, 0.01 away)
            beam(f, "Stringer", (x_bot, y0 - 0.1, zs), (x_top, y0 + floor_h - 0.1, zs), 0.32, 0.08, steel, "Metal",
                 side=(0.07, 0, 1), flags=DECOR_SHADOW)
            n += 1
        steps = 7
        for i in range(1, steps):
            t = i / steps
            tx = x_bot + (x_top - x_bot) * t
            f.box("Tread", (tx - 0.42, y0 + floor_h * t - 0.1, -depth + 0.2), (tx + 0.42, y0 + floor_h * t,
                                                                               -depth + sw - 0.2),
                  jitter(steel, rng, 3), "DiamondPlate", flags=SOLID)
            n += 1
        # the handrail: a round bar over the outer stringer (no flat side to lie along the rails)
        rod(f, "Handrail", (x_bot, y0 + rail_h, -depth + 0.15), (x_top, y0 + floor_h + rail_h, -depth + 0.15), 0.12,
            steel, "Metal", flags=DECOR)
        n += 1
    # drop ladder, hooked up under the first landing (round rungs between flat rails)
    if ladder and landings:
        y = landings[0] * floor_h
        lx = -(width / 2 - 0.6) if len(landings) > 1 else 0.0
        lx = lx + rng.uniform(-0.3, 0.3)
        lo, hi = y - 6.5, y + rail_h - 0.2
        for s in (-1, 1):
            f.box("LadderRail", (lx + s * 0.75 - 0.07, lo, -depth - 0.34), (lx + s * 0.75 + 0.07, hi, -depth - 0.18),
                  steel, "Metal", flags=DECOR_SHADOW)
            n += 1
        for i in range(int((hi - lo) / 1.0)):
            rod(f, "Rung", (lx - 0.68, lo + 0.5 + i, -depth - 0.26), (lx + 0.68, lo + 0.5 + i, -depth - 0.26), 0.08,
                steel, "Metal", flags=DECOR)
            n += 1
    return n


def _water_tank(f, rng, cx, base, cz, r, th, legs, color=None, braces=True, far=False):
    """A rooftop wooden water tank on a steel stand (New York style): four posts, a diagonal
    brace on two sides, two beams and a deck, the staved tank (one cylinder: wood, weathered
    grey-brown) with steel hoops at uneven heights, its conical roof (a cone of wedges, not
    stacked discs) with a small finial, and the outlet pipe down to the roof.
    (The mesh kit replaces this with a real model; these parts are the fallback.) far: the
    lighter version for a building in the background (two hoops, six facets, no outlet).
    Returns the parts made. With the kit on (meshprop.LIBS) the kit's WaterTank (staves 2.75 in
    radius: scaled r / 2.75) stands there, these parts its fallback, with the legs and staves set
    to its proportions so the solid ones (collision proxies) match it."""
    if MESHPROP.LIBS and not far:  # (the far ones stay the light primitive version: background only)
        sc = r / 2.75
        legs, th = 3.6 * sc, 5.3 * sc + 0.12
        box = []
        frame_meshprop(f.D, f.folder, "WaterTank", f.sub((cx, base, cz)), scale=round(sc, 3),
                       fallback=lambda: box.append(_water_tank_parts(f, rng, cx, base, cz, r, th, legs, color, braces,
                                                                     far)))
        return box[0] + 1
    return _water_tank_parts(f, rng, cx, base, cz, r, th, legs, color, braces, far)


def _water_tank_parts(f, rng, cx, base, cz, r, th, legs, color, braces, far):
    n = 0
    k = r * 0.68
    for sx in (-1, 1):
        for sz in (-1, 1):
            f.box("TankLeg", (cx + sx * k - 0.14, base, cz + sz * k - 0.14), (cx + sx * k + 0.14, base + legs,
                                                                              cz + sz * k + 0.14), METAL_DARK,
                  "Metal", flags=SOLID)
            n += 1
    if braces:
        for sz in (-1, 1):
            beam(f, "Brace", (cx - k, base + 0.3, cz + sz * k), (cx + k, base + legs - 0.3, cz + sz * k), 0.1, 0.1,
                 METAL_DARK, "Metal", side=(0, 0, 1), flags=DECOR)
            n += 1
    for sz in (-1, 1):  # beams across the posts
        f.box("TankBeam", (cx - r - 0.1, base + legs, cz + sz * k - 0.16), (cx + r + 0.1, base + legs + 0.36,
                                                                            cz + sz * k + 0.16), METAL_DARK, "Metal",
              flags=DECOR)
        n += 1
    yb = base + legs + 0.36
    f.box("TankBase", (cx - r - 0.15, yb, cz - r - 0.15), (cx + r + 0.15, yb + 0.2, cz + r + 0.15),
          jitter(WOOD_DARK, rng, 6), "WoodPlanks", flags=SOLID)
    n += 1
    yb += 0.2
    wood = color or jitter(rng.choice([WOOD_GREY, WOOD_OLD, (84, 76, 64)]), rng, 6)
    th -= 0.12  # (the roof deck: a disc over the tank, under the cone's facets, hiding where they meet)
    f.part("Tank", (cx, yb + th / 2, cz), (th, 2 * r, 2 * r), wood, "WoodPlanks", rot=(0, 0, 90), shape=CYLINDER,
           flags=SOLID)
    rr = 2 * (r + 0.22) * (1.16 if far else 1.09)  # (wide enough to hide where the facets meet)
    f.part("TankRoof", (cx, yb + th + 0.06, cz), (0.12, rr, rr), jitter(WOOD_DARK, rng, 4),
           "WoodPlanks", rot=(0, 0, 90), shape=CYLINDER, flags=DECOR)
    n += 2
    count = 2 if far else rng.randint(3, 4)
    hs = [(i + rng.uniform(0.25, 0.75)) / count * 0.84 + 0.08 for i in range(count)]  # (uneven, never touching)
    for t in hs:
        f.part("Hoop", (cx, yb + th * t, cz), (0.12, 2 * r + 0.1, 2 * r + 0.1), jitter(RUST_DARK, rng, 4),
               "CorrodedMetal", rot=(0, 0, 90), shape=CYLINDER, flags=DECOR)
        n += 1
    rh = r * rng.uniform(0.45, 0.6)
    n += cone(f, "TankRoof", cx, yb + th + 0.12, cz, r + 0.22, rh, jitter(WOOD_DARK, rng, 4), "WoodPlanks",
              n=6 if far else 8, rng=rng, jit=3)
    bolt(f, "Finial", (cx, yb + th + 0.12 + rh + 0.05, cz), 0.3, METAL_DARK)
    if far:
        return n + 1
    rod(f, "Outlet", (cx + r * 0.4, base, cz - r * 0.3), (cx + r * 0.4, base + legs + 0.36, cz - r * 0.3), 0.3,
        jitter(RUST_DARK, rng, 4), "CorrodedMetal", flags=DECOR)
    return n + 2


def _gutters(f, top):
    """(x0, x1, y_top) in frame f of the gutter parts already hung on this wall near its top
    (downpipe), or None."""
    names = {"Gutter", "GutterLip", "GutterEnd", "GutterBroken"}
    ids = {i + 1 for i, nm in enumerate(f.D.names) if nm in names}
    box = None
    for row in f.D.parts:
        if row[16] not in ids:
            continue
        loc = f.m.T @ (np.array(row[1:4], float) - f.origin)
        if abs(loc[2]) > 2.0 or not top - 5 < loc[1] < top + 1:
            continue
        ext = np.abs(f.m.T @ yxz_matrix(row[4], row[5], row[6])) @ (np.array(row[7:10], float) / 2)
        b = (loc[0] - ext[0], loc[0] + ext[0], loc[1] + ext[1], loc[1] - ext[1])
        if box is None:
            box = b
        else:
            box = (min(box[0], b[0]), max(box[1], b[1]), max(box[2], b[2]), min(box[3], b[3]))
    return box


def _wall_top(f, top, depth):
    """The local height of the top of the wall this frame stands on (the highest solid part
    found inside the wall, under its middle and quarters), if it is within 2.5 studs under
    `top` + 0.3; else `top`. (The parapet then sits ON the wall, with no slit under it, even
    when the caller's `top` is measured from another floor level.)"""
    D = f.D
    zlayers.host_at(D, f.world((0.0, top, depth / 2)))  # (brings zlayers' table up to date)
    best = None
    for S in (zlayers._state(D)["solids"], zlayers._city_solids()):
        if not len(S.c):
            continue
        for x in (-0.25, 0.0, 0.25):
            for y in (top - 2.5, top - 1.2):
                p = f.world((x * 8.0, y, depth / 2))
                hit = np.nonzero(np.all((S.lo - 1e-4 <= p) & (p <= S.hi + 1e-4), axis=1))[0]
                for i in hit:
                    t = float(S.hi[i][1]) - float(f.origin[1])
                    if top - 2.5 <= t <= top + 0.3 and (best is None or t > best):
                        best = t
    return top if best is None else best


def building_top(D, folder, origin, ry, rng, width=16.0, top=30.0, depth=4.0, clutter="tank"):
    """The top of a wall seen from the alley: a stepped cornice (three receding courses, the
    profile different per building) on corbels (stepped brackets, unevenly spaced, a few
    fallen or broken), black run-off below it, a parapet, coping stones of uneven length and
    thickness (one missing, some shifted), weeds, and rooftop clutter set back: clutter =
    "tank" (wooden water tank on a steel stand), "antenna" (mast + bars + guy wires), "vents"
    (stacks and a box vent) or None. origin: wall face at floor level; the wall is `top` tall
    and `depth` thick (behind). Footprint: width x (depth + ~8) on the roof. Parts: 25-70."""
    f = frame_at(D, folder, origin, ry)
    n = 0
    top = _wall_top(f, top, depth)
    # walls of one height meet at corners, where their cornices and copings cross: each building
    # top of a height gets its own offset, and every horizontal face (course beds and tops,
    # coping tops) is drawn clear of those already used by other tops (_level), so two
    # crossing courses never share a plane
    tops = D.__dict__.setdefault("_wall_tops", {})
    key = round(float(f.world((0, top, 0))[1]), 1)
    lift = 0.09 * (tops.get(key, 0) % 4)
    tops[key] = tops.get(key, 0) + 1
    used = D.__dict__.setdefault("_top_planes", [])
    oy = float(f.world((0, 0, 0))[1])

    def free(*ys):  # (clear of the other tops' planes, and of this wall's own top)
        return all(abs(oy + y_ - u) > 0.07 for y_ in ys for u in used + [oy + top])

    stone = jitter(rng.choice([STONE, (118, 110, 98), (104, 100, 94)]), rng, 6, 0.1)
    brick = jitter(rng.choice(BRICK), rng, 6)
    # a gutter already hung on this wall under the roof line (downpipe): the cornice sits above
    # it, and no corbel is set where it runs
    gut = _gutters(f, top)
    # and the windows / doors already on the wall: the cornice's bed stays above their heads
    units = _blocked_below(f, -width / 2, width / 2, top + 0.5)
    cy0 = top - 1.0 - lift
    # the cornice: courses stacked, each standing further out than the one below (the profile
    # differs per building); its planes are drawn until they are clear of other tops'
    for _try in range(40):
        p3 = rng.uniform(0.42, 0.5)
        p2 = p3 + rng.uniform(0.1, 0.2)
        p1 = p2 + rng.uniform(0.14, 0.3)
        t1, t2, t3 = rng.uniform(0.3, 0.45), rng.uniform(0.18, 0.28), rng.uniform(0.25, 0.35)
        cy = max(cy0 + rng.uniform(-0.05, 0.05), units + 0.14 + t3)
        if gut is not None:  # (above the gutter: the cornice may run up the parapet's foot)
            cy = max(cy, gut[2] + t3 + 0.1)
        cy = min(cy, top + 1.0 - t2 - t1)
        if free(cy - t3, cy, cy + t2, cy + t2 + t1):
            break
    used += [oy + y_ for y_ in (cy - t3, cy, cy + t2, cy + t2 + t1)]
    # (each course stops short of the wall's ends, each lower one 0.08 more: no end face lies on
    # the plane of a crossing wall's face at a corner, nor on its neighbour course's end)
    courses = [(cy + t2, cy + t2 + t1, p1, 0.0, 0.08), (cy, cy + t2, p2, 0.06, 0.16), (cy - t3, cy, p3, 0.12, 0.24)]
    # at an inner corner (a crossing wall at an end) the courses run on into that wall, their
    # ends hidden in it, the way a real cornice dies into the return wall
    into = [any(_solid_at(f, (sd * (width / 2 + dx), cy, -0.2)) for dx in (0.15, 0.35)) for sd in (-1, 1)]
    for i, (y0, y1, p, dk, e) in enumerate(courses):  # (backs sunk apart into the wall: no shared plane)
        ea, eb = (-0.45 if into[0] else e), (-0.45 if into[1] else e)
        f.box("Cornice", (-width / 2 + ea, y0, -p), (width / 2 - eb, y1, 0.07 + 0.06 * i), jitter(stone, rng, 3, dk),
              "Limestone", flags=DECOR)
        n += 1
    yc = cy - t3  # under the bed course
    # corbels (one kind per building): tapered brackets (a wedge, flat on top and on the wall),
    # plain blocks, or stepped (two blocks); uneven spacing, each a little different in size and
    # tone (hand-cut, weathered), a few fallen, some broken short
    kind = rng.choice(["wedge", "wedge", "block", "stepped"])
    pitch = rng.uniform(1.5, 2.1) * (1.2 if kind == "stepped" else 1.0)
    cw0 = rng.uniform(0.36, 0.5)
    ch0 = rng.uniform(0.5, 0.75)
    x = -width / 2 + rng.uniform(0.4, 0.9)
    while x < width / 2 - 0.4:
        r_ = rng.random()
        cc = jitter(stone, rng, 6, rng.uniform(0.04, 0.16))
        cw, ch = cw0 * rng.uniform(0.9, 1.1), ch0 * rng.uniform(0.9, 1.08)
        if gut is not None and gut[0] - cw < x < gut[1] + cw:
            pass  # (the gutter runs here)
        elif _blocked_below(f, x - cw / 2 - 0.1, x + cw / 2 + 0.1, yc) > yc - ch - 0.12:
            pass  # (a window head just under it: no room)
        elif (into[0] and x < -width / 2 + 1.4) or (into[1] and x > width / 2 - 1.4):
            pass  # (in the corner, under the crossing wall's cornice)
        elif r_ < 0.08:
            pass  # fallen off
        elif kind == "wedge":
            hh = ch * (0.55 if r_ < 0.16 else 1.0)  # broken short
            f.part("Corbel", (x, yc - hh / 2, -p3 / 2), (cw, hh, p3), cc, "Limestone", rot=(0, 0, 180), shape=WEDGE,
                   flags=DECOR)
            n += 1
        elif kind == "block":
            _zbox(f, "Corbel", x - cw / 2, x + cw / 2, yc - ch * 0.6, yc, (0, p3), cc, "Limestone", flags=DECOR)
            n += 1
        else:
            _zbox(f, "Corbel", x - cw / 2, x + cw / 2, yc - 0.28, yc, (0, p3), cc, "Limestone", flags=DECOR)
            n += 1
            if r_ > 0.18:  # (the lower step's front past every overlay slot)
                _zbox(f, "Corbel", x - cw * 0.35, x + cw * 0.35, yc - 0.6, yc - 0.28, (0, p3 - 0.08),
                      jitter(cc, rng, 3), "Limestone", flags=DECOR)
                n += 1
        x += pitch * rng.uniform(0.85, 1.15)
    # black run-off down the face from under the cornice, stopping above any window or door
    # already on this wall (it would only run behind their surrounds)
    taken = []  # (run-offs side by side, never overlapping: one would lie on the other's plane)
    for _ in range(rng.randint(3, 5)):
        for _try in range(6):
            sx = rng.uniform(-width / 2 + 0.5, width / 2 - 0.5)
            w_ = rng.uniform(0.5, 1.2)
            if any(abs(sx - tx) < (w_ + tw) / 2 + 0.25 for tx, tw in taken):
                continue
            y_top = yc - 0.8
            stop = _blocked_below(f, sx - w_ / 2, sx + w_ / 2, y_top)
            ln = min(rng.uniform(2.5, 7), y_top - stop - 0.3)
            if ln > 1.2:
                n += streak(f, rng, "RunOff", sx, y_top, ln, w_, SOOT, k=0, tr=0.6, taper=3)
                taken.append((sx, w_))
                break
    # parapet and coping (stones of uneven length and thickness, gaps, one missing, some shifted)
    ph = 2.2 + lift
    # (at a corner where a crossing wall's parapet or coping is already built, the run stops
    # short of it instead of running through it on nearly the same planes)
    def taken_at(xx):
        return any(_solid_at(f, (xx, top + ph + dy, dz)) for dy in (-0.25, 0.15, 0.4) for dz in (-0.25, 0.5, 1.2))

    xa, xb = -width / 2, width / 2
    while xa < xb - 1 and taken_at(xa + 0.05):
        xa += 0.25
    while xb > xa + 1 and taken_at(xb - 0.05):
        xb -= 0.25
    xa, xb = (xa + 0.12 if xa > -width / 2 else xa), (xb - 0.12 if xb < width / 2 else xb)
    f.box("Parapet", (-width / 2, top, 0), (width / 2, top + ph, 1.0), brick, "Brick", flags=SOLID)
    n += 1
    x = xa
    while x < xb - 0.2:
        ln = min(rng.uniform(1.5, 3.0), xb - x)
        if rng.random() > 0.08 and ln > 0.3:
            th = rng.uniform(0.24, 0.36)
            out = rng.uniform(-0.06, 0.06) + (0.18 if rng.random() < 0.1 else 0.0)  # one slid outward
            f.part("Coping", (x + ln / 2, top + ph + th / 2 + rng.uniform(0.0, 0.03), 0.5 - out),
                   (ln - rng.uniform(0.05, 0.1), th, 1.45 + rng.uniform(-0.05, 0.08)),
                   jitter(stone, rng, 4, rng.uniform(0.0, 0.25)), "Concrete",
                   rot=(rng.uniform(-1.2, 1.2), rng.uniform(-1.5, 1.5), rng.uniform(-1, 1)), flags=SOLID)
            n += 1
        x += ln
    for _ in range(rng.randint(1, 3)):  # weeds in the joints
        wx = rng.uniform(-width / 2, width / 2)
        f.part("Weed", (wx, top + ph + 0.45, 0.3), (rng.uniform(0.4, 0.8), rng.uniform(0.3, 0.6), 0.4),
               jitter(MOSS, rng, 10), "Grass", rot=(0, rng.uniform(0, 90), rng.uniform(-20, 20)), flags=DECOR)
        n += 1
    # rooftop clutter (behind the parapet, sits on the roof at y = top)
    # (behind the wall, on the roof: clear of any block already standing there, on a roof if
    # one is found under it)
    z0, cx = depth + rng.uniform(2.6, 3.4), rng.uniform(-width / 4, width / 4)
    spots = [(z0, cx)] + [(depth + dz, rng.uniform(-width / 3, width / 3)) for dz in (1.6, 2.2, 3.0, 4.5, 6.0)
                          for _ in range(2)]

    def clear(zz, xx):
        return not any(_solid_at(f, (xx + ax, top + ay, zz + az)) for ax in (-2.6, 0, 2.6) for az in (-2.6, 0, 2.6)
                       for ay in (0.6, 6.0, 12.0))

    good = [sp for sp in spots if clear(*sp)]
    roofed = [sp for sp in good if _solid_at(f, (sp[1], top - 0.4, sp[0]))]
    if roofed or good:
        z0, cx = (roofed or good)[0]
    elif clutter is not None:
        clutter = None  # (nowhere free: another block fills the roof)
    if clutter == "tank":
        n += _water_tank(f, rng, cx, top, z0, rng.uniform(2.2, 2.8), rng.uniform(5, 6.5), rng.uniform(4, 6))
    elif clutter == "antenna":
        mh = rng.uniform(8, 13)
        rod(f, "Mast", (cx, top, z0), (cx, top + mh, z0), 0.25, GALV, "Metal", flags=DECOR_SHADOW)
        n += 1
        for i in range(3):
            yy = top + mh * (0.6 + 0.15 * i)
            hw = 1.6 - 0.4 * i
            rod(f, "Element", (cx - hw, yy, z0), (cx + hw, yy + rng.uniform(-0.1, 0.1), z0), 0.1, GALV, "Metal",
                flags=DECOR)
            n += 1
        for gx, gz in ((-3, -2), (3, -2), (0, 3)):
            rod(f, "Guy", (cx, top + mh * 0.7, z0), (cx + gx, top, z0 + gz), 0.05, CABLE, "Metal", flags=DECOR)
            n += 1
    elif clutter == "vents":
        for i in range(rng.randint(2, 3)):
            vx = cx + rng.uniform(-4, 4)
            vz = z0 + rng.uniform(-1, 2)
            vh = rng.uniform(2, 4.5)
            vd = rng.uniform(0.6, 1.0)
            rod(f, "Stack", (vx, top, vz), (vx, top + vh, vz), vd, jitter(GALV, rng, 6, 0.25), "Metal", flags=SOLID)
            f.part("Cap", (vx, top + vh + 0.25, vz), (0.06, vd * 1.76, vd * 1.76), METAL_DARK, "Metal", rot=(0, 0, 90),
                   shape=CYLINDER, flags=DECOR)
            n += 2 + cone(f, "Cap", vx, top + vh + 0.28, vz, vd * 0.75, vd * 0.4, METAL_DARK, "Metal", n=6)
        f.box("BoxVent", (cx - 2, top, z0 + 2), (cx + 1, top + 2.2, z0 + 4), jitter(GALV, rng, 6, 0.2), "Metal",
              flags=SOLID)
        n += 1
    return n


def background_facade(D, folder, origin, ry, rng, width=40.0, height=60.0, depth=12.0, floor_h=10.0, style=None,
                      lit_share=0.25, ground_floor=True):
    """A tall building BEYOND the alley walls (for depth, seen above the near roofs): a solid
    mass with rows of recessed windows (a dark glass band behind brick piers, stone sill lines
    that stop short of the corners), each bay's pane in front of the band with some blinds
    half down, a few lit (warm / cold / TV; tagged CityWindowLit, some Day = always on at
    night), AC boxes, a shuttered ground floor, a cornice, run-off down the piers, a water
    tank and a mast. Cheap: windows are bands, not one part each. origin: floor point at the
    middle of the facade's foot; the mass extends `depth` behind. Footprint: width x depth x
    height. Parts: 30-75."""
    f = frame_at(D, folder, origin, ry)
    n = 0
    style = style or rng.choice(["brick", "concrete", "render"])
    mass_c = {"brick": jitter(rng.choice(BRICK), rng, 6, 0.15), "concrete": jitter(CONCRETE, rng, 6, 0.2),
              "render": jitter((104, 98, 86), rng, 6, 0.15)}[style]
    mat = {"brick": "Brick", "concrete": "Concrete", "render": "Concrete"}[style]
    # another building may already fill this volume (a city block): then only the face is added
    filled = _solid_at(f, (0, height * 0.5, depth * 0.5)) and _solid_at(f, (0, height - 0.5, depth * 0.5))
    if not filled:
        f.box("Mass", (-width / 2, 0, 0), (width / 2, height, depth), mass_c, mat, flags=SOLID)
        n += 1
    floors = int(height / floor_h)
    cols = max(2, int(width / 5.5))
    bay = width / cols
    win_w = bay * rng.uniform(0.45, 0.55)
    pier_w = bay - win_w
    first = 1 if ground_floor else 0
    for k in range(first, floors):
        y0 = k * floor_h + floor_h * 0.3
        y1 = y0 + floor_h * 0.5
        f.box("Glass", (-width / 2 + 0.3, y0, -0.12), (width / 2 - 0.3, y1, -0.02),
              jitter((26, 28, 30), rng, 3), "Glass", flags=DECOR, reflectance=0.08)
        # the sill line stops short of the corners (its ends well clear of the edge piers' sides)
        f.box("SillLine", (-width / 2 + 0.14, y0 - 0.35, -0.75), (width / 2 - 0.14, y0, 0), jitter(STONE, rng, 4, 0.15),
              "Concrete", flags=DECOR)
        # the frames' transom: one bar across the floor's windows (between the piers it splits
        # each window into a top light and the main pane), in front of the panes
        ty = y0 + (y1 - y0) * rng.uniform(0.68, 0.76)
        f.box("Transom", (-width / 2 + 0.3, ty - 0.09, -0.42), (width / 2 - 0.3, ty + 0.09, -0.34),
              jitter((40, 40, 40), rng, 4), "Metal", flags=DECOR)
        n += 3
    # piers between the windows (full height, in front of the glass bands)
    for i in range(cols + 1):
        px = -width / 2 + i * bay
        a, b = max(-width / 2, px - pier_w / 2), min(width / 2, px + pier_w / 2)
        f.box("Pier", (a, floor_h * first, -0.5), (b, height, 0), jitter(mass_c, rng, 3), mat, flags=DECOR)
        n += 1
    # lit windows (each a pane well in front of its band), blinds between pane and band
    budget = min(14, int((floors - first) * cols * lit_share))
    cells = [(k, i) for k in range(first, floors) for i in range(cols)]
    rng.shuffle(cells)
    for k, i in cells[:budget]:
        y0 = k * floor_h + floor_h * 0.3
        cx = -width / 2 + (i + 0.5) * bay
        kind = rng.choice(["warm", "warm", "warm", "cold", "tv"])
        col = {"warm": WARM_DIM, "cold": COLD_DIM, "tv": TV_DIM}[kind]
        day = rng.random() < 0.5
        hw = win_w / 2 - 0.1
        f.box("Window", (cx - hw, y0 + 0.1, -0.3), (cx + hw, y0 + floor_h * 0.5 - 0.1, -0.26),
              jitter(col, rng, 10, rng.uniform(0, 0.35)) if day else (30, 32, 34), "Neon" if day else "Glass",
              flags=DECOR, extra={"t": ["CityWindowLit"], "a": {"Kind": kind, "Day": day}})
        n += 1
        if rng.random() < 0.4:  # blind / curtain half down (behind the pane)
            f.box("Blind", (cx - hw, y0 + floor_h * 0.5 * rng.uniform(0.5, 0.8), -0.2),
                  (cx + hw, y0 + floor_h * 0.5 - 0.18, -0.18), jitter((70, 62, 50), rng, 8), "Fabric", flags=DECOR)
            n += 1
    # dark windows are not all the same: blinds half or fully down, a curtain, a sheet (pale
    # panels behind the glass line, in front of the dark band)
    na = rng.randint(2, 5)
    for k, i in cells[budget + na:budget + na + rng.randint(3, 8)]:
        y0 = k * floor_h + floor_h * 0.3
        cx = -width / 2 + (i + 0.5) * bay
        hw = win_w / 2 - 0.1
        drop = floor_h * 0.5 * rng.choice((rng.uniform(0.2, 0.5), rng.uniform(0.6, 0.95)))
        f.box("Blind", (cx - hw, y0 + floor_h * 0.5 - 0.1 - drop, -0.2), (cx + hw, y0 + floor_h * 0.5 - 0.1, -0.18),
              jitter(rng.choice([(140, 134, 116), (120, 116, 104), (96, 50, 44), (150, 146, 136)]), rng, 8, 0.25),
              rng.choice(["Fabric", "SmoothPlastic"]), flags=DECOR)
        n += 1
    # AC boxes stuck under some windows (on the wall between the piers)
    for k, i in cells[budget:budget + na]:
        cx = -width / 2 + (i + 0.5) * bay + rng.uniform(-0.6, 0.6) * max(0.0, win_w / 2 - 1.0)
        y0 = k * floor_h + floor_h * 0.3 - 1.7
        f.box("AC", (cx - 0.9, y0, -0.55), (cx + 0.9, y0 + 1.2, 0), jitter(BEIGE, rng, 8, 0.2), "Metal", flags=DECOR)
        n += 1
    if ground_floor:  # (hidden behind the alley walls: one shutter slab under a fascia)
        f.box("ShopShutters", (-width / 2 + 0.4, 0, -0.3), (width / 2 - 0.4, floor_h * 0.6, -0.05),
              jitter((60, 62, 62), rng, 4), "Metal", flags=SOLID)
        n += 1
        f.box("Fascia", (-width / 2, floor_h * 0.6, -0.6), (width / 2, floor_h * 0.75, 0), jitter((40, 40, 42), rng, 4),
              "Metal", flags=DECOR)
        n += 1
    # cornice, parapet, run-off on the piers' faces, roof clutter
    f.box("Cornice", (-width / 2 - 0.3, height - 1.2, -1.0),
          (width / 2 + 0.3, height - 0.4, -0.12 if filled else depth - 0.3),
          jitter(STONE, rng, 4, 0.2), "Concrete", flags=DECOR)
    n += 1
    if not filled:
        f.box("Parapet", (-width / 2, height, 0.3), (width / 2, height + 1.5, depth - 0.3), jitter(mass_c, rng, 4, 0.1),
              mat, flags=DECOR)
        n += 1
    piers = list(range(1, cols))
    for i in rng.sample(piers, min(len(piers), rng.randint(2, 4))):
        px = -width / 2 + i * bay
        g = f.sub((0, 0, -0.5))  # the pier's front face
        n += streak(g, rng, "RunOff", px, height - 1.25, rng.uniform(8, 22), min(pier_w * 0.7, 1.4), SOOT, k=0, tr=0.6,
                    taper=3)
    if filled:
        return n
    tx, tz = rng.uniform(-width / 3, width / 3), depth * 0.5
    n += _water_tank(f, rng, tx, height, tz, 2.2, 4.4, 4.0, color=jitter(WOOD_DARK, rng, 6), braces=False, far=True)
    mx = rng.uniform(-width / 2 + 2, width / 2 - 2)
    rod(f, "Mast", (mx, height, depth * 0.7), (mx, height + rng.uniform(8, 14), depth * 0.7), 0.3, METAL_DARK, "Metal",
        flags=DECOR)
    return n + 1


def chainlink_fence(D, folder, origin, ry, rng, width=10.0, height=8.0, barbed=True, torn=True):
    """A free-standing chain-link fence along local X (origin = floor point at its middle):
    galvanised posts, a top rail, mesh panels (translucent, each sagging a little), a torn
    corner peeled back, barbed-wire arms leaning out (-Z side) with three strands, and
    rubbish caught at its foot. Mesh is SOLID (blocks players).
    Footprint: width x 0.3 (x ~1.6 with the arms), height (+1.4). Parts: 10-28."""
    f = frame_at(D, folder, origin, ry)
    n = 0
    galv = jitter(GALV, rng, 6, 0.15)
    posts = max(2, int(width / 5) + 1)
    xs = [-width / 2 + i * width / (posts - 1) for i in range(posts)]
    torn_i = rng.randrange(posts - 1) if torn else -1
    for i, px in enumerate(xs):
        rod(f, "Post", (px, 0, 0), (px + rng.uniform(-0.05, 0.05), height + 0.2, rng.uniform(-0.06, 0.06)), 0.28, galv,
            "Metal", flags=SOLID)
        n += 1
        if barbed:
            beam(f, "BarbArm", (px, height + 0.1, 0), (px, height + 1.4, -1.1), 0.1, 0.1, galv, "Metal", side=(1, 0, 0),
                 flags=DECOR)
            n += 1
    rod(f, "TopRail", (-width / 2, height - 0.1, 0), (width / 2, height - 0.1, 0), 0.18, galv, "Metal", flags=DECOR)
    n += 1
    for i in range(posts - 1):
        a, b = xs[i], xs[i + 1]
        lo = 0.05
        if i == torn_i:
            lo = rng.uniform(1.4, 2.2)
            # the peeled corner: a flap bent out
            fw = (b - a) * rng.uniform(0.4, 0.6)
            g = f.sub((a + 0.15, lo / 2, 0), rx=-rng.uniform(25, 45))
            g.box("MeshFlap", (0, -lo / 2, -0.03), (fw, lo / 2, 0.03), galv, "Metal", transparency=0.72, flags=DECOR)
            n += 1
        f.part("Mesh", ((a + b) / 2, (lo + height - 0.1) / 2, rng.uniform(-0.08, 0.08)),
               (b - a - 0.2, height - 0.1 - lo, 0.06), galv, "Metal", rot=(rng.uniform(-2.5, 2.5), 0, 0),
               transparency=0.72, flags=SOLID)
        n += 1
        if i == torn_i:  # (still blocks: an invisible wall where the mesh is gone, too low to crawl)
            pass
    if barbed:
        for j in range(3):
            t = (j + 1) / 3.2
            rod(f, "Barbed", (-width / 2, height + 0.1 + 1.3 * t, -1.1 * t), (width / 2, height + 0.1 + 1.3 * t - rng.uniform(0, 0.15),
                                                                         -1.1 * t), 0.06, jitter(GALV, rng, 4, 0.35),
                "Metal", flags=DECOR)
            n += 1
        # barbs: small twisted bits along the strands
        for _ in range(rng.randint(3, 6)):
            t = rng.randint(1, 3) / 3.2
            bx = rng.uniform(-width / 2, width / 2)
            f.part("Barb", (bx, height + 0.1 + 1.3 * t, -1.1 * t), (0.3, 0.05, 0.05), GALV, "Metal",
                   rot=(rng.uniform(0, 180), rng.uniform(0, 180), rng.uniform(30, 60)), flags=DECOR)
            n += 1
    # snagged rubbish: a plastic sheet in the mesh, paper at the foot, a dark rag on the wire
    f.part("Snag", (rng.uniform(-width / 3, width / 3), rng.uniform(1.5, 4), -0.12), (rng.uniform(0.8, 1.4), rng.uniform(0.6, 1.0), 0.04),
           jitter((150, 150, 140), rng, 10), "SmoothPlastic", rot=(rng.uniform(-10, 10), 0, rng.uniform(-30, 30)),
           transparency=0.35, flags=DECOR)
    f.part("Rag", (rng.uniform(-width / 2, width / 2), height + 1.0, -0.6), (0.6, 0.9, 0.06), jitter((40, 36, 34), rng, 6),
           "Fabric", rot=(rng.uniform(-20, 20), 0, rng.uniform(-30, 30)), flags=DECOR)
    for _ in range(rng.randint(1, 3)):
        f.part("Paper", (rng.uniform(-width / 2, width / 2), 0.08, rng.uniform(-0.4, 0.4)), (rng.uniform(0.5, 0.9), 0.12, 0.6),
               jitter(rng.choice(PAPER), rng, 10, 0.2), "SmoothPlastic",
               rot=(rng.uniform(-60, 60), rng.uniform(0, 180), rng.uniform(-20, 20)), flags=DECOR)
        n += 1
    return n + 2


# =================================================================================================
# 4. Services: AC, meters, cables, pipes, downpipes, vents, dish
# =================================================================================================


def ac_unit(D, folder, origin, ry, rng, y=9.0, x=0.0, scale=1.0):
    """A wall-hung split air-con condenser: yellowed pressed-steel casing with an overhanging
    lid, a round fan opening on the left (dark disc in a raised rim, an X guard and a hub),
    louvres on the right, on two L-brackets (a wall leg, an arm under the unit, a diagonal
    brace); the insulated pipe bundle bending into the wall, a condensate pipe dribbling a dark
    wet run down the wall, rust from the bracket screws and soot above the outlet.
    Footprint: 2.6 x 1.35 (x scale), 1.9 tall. Parts: 22-26."""
    f = frame_at(D, folder, origin, ry).sub((x, y, 0))
    s = scale * 0.86  # (real 9-12k BTU units: ~0.75 x 0.55 x 0.28 m)
    W, H, Dp = 3.0 * s, 2.2 * s, 1.3 * s
    case = jitter(rng.choice([BEIGE, (130, 128, 118), (110, 112, 106)]), rng, 8, 0.1)
    n = 0
    zf = Dp + 0.25  # the casing's front, out of the wall
    _zbox(f, "Casing", -W / 2, W / 2, 0, H, (0.25, zf), case, "Metal", flags=SMALL)
    _zbox(f, "CasingTop", -W / 2 - 0.04, W / 2 + 0.04, H, H + 0.08, (0.21, zf + 0.04), jitter(case, rng, 4, 0.12), "Metal",
          flags=DECOR)
    n += 2
    gx, gy = -W * 0.17, H / 2
    d = H * 0.78

    def disc(name, dia, z0, z1, col, mat="Metal"):
        f.part(name, (gx, gy, -(z0 + z1) / 2), (z1 - z0, dia, dia), col, mat, rot=(0, 90, 0), shape=CYLINDER,
               flags=DECOR)

    # (the rim, then the dark fan disc standing proud of it under the guard: fronts 0.07 apart)
    disc("FanRim", d + 0.12, zf - 0.03, zf + 0.07, jitter(case, rng, 4, 0.2))
    disc("FanHole", d, zf - 0.03, zf + 0.14, (16, 16, 18))
    n += 2
    for i, a in enumerate((45, -45)):  # the guard: each bar its own depth (they cross)
        f.part("Guard", (gx, gy, -(zf + 0.2 + 0.07 * i)), (d * 0.98, 0.05, 0.04), (90, 90, 86), "Metal", rot=(0, 0, a),
               flags=DECOR)
        n += 1
    bolt(f, "Hub", (gx, gy, -(zf + 0.25)), 0.16, (70, 70, 66))
    n += 1
    for i in range(4):
        yy = H * (0.22 + 0.18 * i)
        f.part("Louvre", (W * 0.3, yy, -zf - 0.02), (W * 0.3, 0.08, 0.1), jitter(case, rng, 4, 0.3), "Metal",
               rot=(-30, 0, 0), flags=DECOR)
        n += 1
    # L-brackets: a leg on the wall, an arm under the unit, a brace between them
    for bx in (-W / 2 + 0.3, W / 2 - 0.3):
        bc = jitter(RUST_DARK, rng, 4)
        _zbox(f, "Bracket", bx - 0.07, bx + 0.07, -0.12, 0, (0.0, zf + 0.08), bc, "CorrodedMetal", flags=DECOR)
        # the wall leg: an angle bar seen corner-on (a square bar turned 45 degrees, half in the
        # wall), so no face of it lies parallel to the stains running down the wall
        f.part("Bracket", (bx, -0.76, -0.04), (0.13, 1.28, 0.13), bc, "CorrodedMetal", rot=(0, 45, 0), flags=DECOR)
        beam(f, "Strut", (bx, -0.12, -(zf - 0.1)), (bx, -1.3, -0.12), 0.1, 0.1, bc, "CorrodedMetal", side=(1, 0, 0),
             flags=DECOR)
        n += 3
    n += streak(f, rng, "Rust", rng.choice((-1, 1)) * (W / 2 - 0.3), -1.45, rng.uniform(0.8, 1.6), 0.24, RUST_STAIN,
                k=0, tr=0.5, taper=2)
    # insulated pipe bundle from the right side into the wall
    py_ = H * 0.25
    n += bend(f, "Lines", [(W / 2 - 0.1, py_, -0.55), (W / 2 + 0.35, py_, -0.55), (W / 2 + 0.35, py_ - 0.25, 0.0)],
              0.18, (36, 36, 36), "Rubber", flags=DECOR)
    # condensate pipe and its wet trail, soot above
    px = W / 2 - 0.5
    rod(f, "DrainPipe", (px, 0, -0.5), (px + 0.1, -1.0, -0.15), 0.12, (40, 40, 40), "Rubber", flags=DECOR)
    n += 1
    n += streak(f, rng, "WetTrail", px + 0.1, -1.08, rng.uniform(3, 7), 0.5, WET_DARK, k=0, tr=0.5, taper=3)
    n += soft(f, rng, "Soot", -W / 2 - 0.3, W / 2 + 0.3, H + 0.1, H + rng.uniform(0.9, 1.6), SOOT, opacity=0.18, k=0,
              anchor="bottom")
    return n


def meter_box(D, folder, origin, ry, rng, y=3.2, x=0.0, conduits=2, width=None):
    """Electrical meter / junction cabinet: a steel box with a rain hood, its door (gap line
    round it, two barrel hinges, a hasp and padlock, a round meter window, a vent), a printed
    DANGER sticker (flush: a SurfaceGui with its own background), conduits leaving the top with
    saddle straps and an LB fitting turning into the wall, one into the ground, a loose cable
    sagging out of the side, a dent, rust dribbling from the bottom seam.
    width: the cabinet's width (default 1.8-2.3: a 55-70 cm cabinet).
    Footprint: (width + 0.2) x 1.0, ~3 tall (+ conduits up to y + 8). Parts: 20-28."""
    f = frame_at(D, folder, origin, ry).sub((x, 0, 0))
    W, H = width or rng.uniform(1.8, 2.3), rng.uniform(2.6, 3.2)
    body = jitter(rng.choice([(78, 86, 78), (92, 92, 86), (60, 64, 66)]), rng, 6)
    n = 0
    _zbox(f, "Cabinet", -W / 2, W / 2, y, y + H, (0, 0.75), body, "Metal", flags=SMALL)
    door = jitter(body, rng, 4, 0.06)
    _zbox(f, "Door", -W / 2 + 0.08, W / 2 - 0.08, y + 0.08, y + H - 0.08, (0.75, 0.83), door, "Metal", flags=DECOR)
    _zbox(f, "Roof", -W / 2 - 0.1, W / 2 + 0.1, y + H, y + H + 0.12, (0, 0.92), jitter(body, rng, 4, 0.15), "Metal",
          flags=DECOR)
    n += 3
    for yy in (y + 0.5, y + H - 0.5):  # barrel hinges
        rod(f, "Hinge", (-W / 2 + 0.06, yy - 0.2, -0.86), (-W / 2 + 0.06, yy + 0.2, -0.86), 0.1, METAL_DARK, "Metal",
            flags=DECOR)
        n += 1
    _zbox(f, "Hasp", W / 2 - 0.32, W / 2 - 0.14, y + H / 2 - 0.15, y + H / 2 + 0.15, (0.83, 0.91), METAL_DARK, "Metal",
          flags=DECOR)
    _zbox(f, "Padlock", W / 2 - 0.34, W / 2 - 0.12, y + H / 2 - 0.5, y + H / 2 - 0.18, (0.86, 0.98),
          jitter((120, 100, 50), rng, 8), "Metal", flags=DECOR)
    n += 2
    # the meter window (a dark round glass in a ring) and the vent
    f.part("MeterRing", (-W * 0.12, y + H * 0.55, -0.87), (0.08, 0.62, 0.62), METAL_DARK, "Metal", rot=(0, 90, 0),
           shape=CYLINDER, flags=DECOR)
    f.part("MeterGlass", (-W * 0.12, y + H * 0.55, -0.92), (0.14, 0.5, 0.5), (34, 38, 36), "Glass", rot=(0, 90, 0),
           shape=CYLINDER, flags=DECOR)
    _zbox(f, "VentSlot", -W / 4, W / 4, y + 0.3, y + 0.46, (0.83, 0.9), (20, 20, 20), "Metal", flags=DECOR)
    # the warning sticker (texts audit T13): two lines of its own, sharp (5 px text at 25 px per stud
    # was a blur), off its edges
    lab_w, lab_pad = W * 0.5, [0.08, 0.08]
    f.part("Label", (W * 0.1, y + H * 0.8, -0.86), (lab_w, 0.42, 0.04), (0, 0, 0), "SmoothPlastic", transparency=1,
           flags=DECOR, extra=sign_extra("DANGER\n415 V", (25, 22, 18), font="Oswald",
                                         bg=jitter((170, 150, 40), rng, 8, 0.15), pad=lab_pad,
                                         pps=textfit.fit_pps("DANGER\n415 V", "Oswald", lab_w, 0.42, lab_pad)))
    n += 4
    # conduits up the wall: saddle straps, an LB fitting at the top turning into the wall
    for i in range(conduits):
        cx = -W / 4 + i * W / 2 / max(1, conduits - 1) if conduits > 1 else 0
        top = y + H + 0.12 + rng.uniform(4, 8)
        cc = jitter((70, 72, 70), rng, 6)
        rod(f, "Conduit", (cx, y + H + 0.12, -0.3), (cx, top, -0.3), 0.26, cc, "Metal", flags=DECOR)
        _zbox(f, "Strap", cx - 0.22, cx + 0.22, y + H + 1.6, y + H + 1.72, (0, 0.47), METAL_DARK, "Metal", flags=DECOR)
        _zbox(f, "LB", cx - 0.19, cx + 0.19, top, top + 0.5, (0.0, 0.5), jitter(cc, rng, 3), "Metal", flags=DECOR)
        n += 3
    rod(f, "Conduit", (W / 4, y, -0.3), (W / 4, 0, -0.3), 0.3, jitter((70, 72, 70), rng, 6), "Metal", flags=DECOR)
    n += 1
    # a loose cable looping out of the side (round bends)
    drop = rng.uniform(0.6, 1.4)
    pts = [(W / 2, y + H * 0.7, -0.4), (W / 2 + 0.35, y + H * 0.7 - drop, -0.55),
           (W / 2 + 0.75, y + H * 0.7 - drop * 0.8, -0.5), (W / 2 + 0.95, y + H * 0.7, -0.35),
           (W / 2 + 1.0, y + H + 2.0, -0.2)]
    n += bend(f, "LooseCable", pts, 0.08, CABLE, "Rubber", flags=DECOR)
    n += streak(f, rng, "RustStreak", rng.uniform(-W / 3, W / 3), y - 0.05, rng.uniform(1, max(1.2, y - 0.4)), 0.45,
                RUST_STAIN, k=0, taper=3)
    return n


def cable_sag(D, folder, origin, ry, rng, span=14.0, y=14.0, y_end=None, cables=3, sag=None, segments=8, shoes=None):
    """A bundle of cables sagging across between two walls (catenary): origin = foot of wall
    A's face, the cables run along local -Z to wall B's face `span` studs away, from height y
    to y_end; each cable sags differently (parabola, `segments` cylinders), with wall clamps
    at both ends. shoes=True (or by chance) adds a pair of trainers tossed over a cable.
    Footprint: 1 x span. Parts: cables*segments + 4 (+5 shoes): 3 cables ~28-33."""
    f = frame_at(D, folder, origin, ry)
    y_end = y if y_end is None else y_end
    # each end's cleat goes on bare wall: lifted clear of a window / sign already there
    for _ in range(8):
        if not any(_solid_at(f, (dx, y + dy, -0.3)) for dx in (-0.6, 0, 0.6) for dy in (-0.7, 0, 0.4)):
            break
        y += 0.5
    for _ in range(8):
        if not any(_solid_at(f, (dx, y_end + dy, -span + 0.3)) for dx in (-0.6, 0, 0.6) for dy in (-0.7, 0, 0.4)):
            break
        y_end += 0.5
    n = 0
    sags = []
    for c in range(cables):
        xo = (c - (cables - 1) / 2) * 0.35 + rng.uniform(-0.05, 0.05)
        a_y = y + rng.uniform(-0.3, 0.3)
        b_y = y_end + rng.uniform(-0.3, 0.3)
        s = (sag if sag is not None else span * 0.1) * rng.uniform(0.7, 1.4)
        d = rng.uniform(0.1, 0.2)
        pts = []
        for i in range(segments + 1):
            t = i / segments
            pts.append((xo + rng.uniform(-0.03, 0.03) * (0 < i < segments), a_y + (b_y - a_y) * t - 4 * s * t * (1 - t),
                        -0.15 - (span - 0.3) * t))
        for i in range(segments):
            rod(f, "Cable", pts[i], pts[i + 1], d, jitter(CABLE, rng, 4), "Rubber", flags=DECOR)
            n += 1
        sags.append(pts)
    for z, e, yy in ((0.0, -1, y), (-span, 1, y_end)):  # (each wall's face, the way out of it)
        # a cleat bolted into the wall (its back sunk in the brick, its front past every stain
        # slot) and a round ceramic spool on it, the cables' drip loop round it
        f.part("Clamp", (0, yy, z + e * 0.13), (cables * 0.35 + 0.3, 0.35, 0.46), METAL_DARK, "Metal", flags=DECOR)
        f.part("Insulator", (0, yy - 0.32, z + e * 0.48), (0.4, 0.26, 0.26), (110, 100, 80), "Plastic",
               rot=(0, 0, 90), shape=CYLINDER, flags=DECOR)
        n += 2
    if shoes if shoes is not None else rng.random() < 0.35:
        pts = sags[rng.randrange(len(sags))]
        p = pts[segments // 2 + rng.randint(-1, 1)]
        g = f.sub(p)
        upper = jitter((150, 146, 136), rng, 6, rng.uniform(0.1, 0.35))  # once white, now grey with grime
        for s_ in (-1, 1):
            h = g.sub((0.05 * s_, -1.1 - 0.15 * (s_ > 0), 0.3 * s_), rx=rng.uniform(60, 85) * s_, rz=rng.uniform(-10, 10))
            h.part("Trainer", (0, 0.04, 0), (0.4, 0.4, 1.0), upper, "Fabric", flags=DECOR)
            h.part("Sole", (0, -0.2, 0.02), (0.54, 0.12, 1.16), (40, 38, 36), "Rubber", flags=DECOR)
            n += 2
        rod(g, "Laces", (0, 0, 0), (0, -0.7, 0.05), 0.04, (150, 150, 140), "Fabric", flags=DECOR)
        n += 1
    return n


def pipe_run(D, folder, origin, ry, rng, length=10.0, y=6.0, x=0.0, diameter=0.6, drop="down", valve=None,
             color=None):
    """A service pipe along the wall at height y, from x - length/2 to x + length/2: two or
    three lengths joined by flanges (with bolt heads), clamps on wall plates, a slight sag
    between clamps, rust weeping from every joint; drop = "down" turns it down (a bend) into
    the ground, "up" up the wall, None ends in a cap. valve adds a gate valve with a spoked
    hand wheel. Pipes low enough to bump are SMALL. Footprint: length x (diameter + 0.4).
    Parts: 12-34."""
    f = frame_at(D, folder, origin, ry).sub((x, 0, 0))
    pc = color or jitter(rng.choice([RUST, METAL, (70, 70, 64), (96, 90, 60)]), rng, 6)
    mat = "CorrodedMetal" if pc[0] > pc[2] + 15 else "Metal"
    zc = -(diameter / 2 + 0.2)
    flags = SMALL if y < 6 else DECOR_SHADOW
    n = 0
    pieces = rng.randint(2, 3)
    xs = [-length / 2 + length * i / pieces for i in range(pieces + 1)]
    sagy = [0.0] + [rng.uniform(-0.12, 0.02) for _ in range(pieces - 1)] + [0.0]
    for i in range(pieces):
        rod(f, "Pipe", (xs[i], y + sagy[i], zc), (xs[i + 1], y + sagy[i + 1], zc), diameter, jitter(pc, rng, 4), mat,
            flags=flags)
        n += 1
        if 0 < i:
            fc_ = jitter(pc, rng, 4, 0.15)
            rod(f, "Flange", (xs[i] - 0.08, y + sagy[i], zc), (xs[i] + 0.08, y + sagy[i], zc), diameter + 0.3, fc_, mat,
                flags=DECOR)
            for a in (45, 135, 225, 315):  # bolt heads round the flange
                r_ = diameter / 2 + 0.08
                bolt(f, "Bolt", (xs[i] - 0.1, y + sagy[i] + r_ * math.sin(math.radians(a)),
                                 zc + r_ * math.cos(math.radians(a))), 0.07, METAL_DARK)
            n += 5 + streak(f, rng, "RustStreak", xs[i], y - diameter / 2 - 0.3, rng.uniform(1.5, 4), 0.4, RUST_STAIN,
                            k=0, taper=3)
    clamps = max(2, int(length / 3.5))
    for i in range(clamps):
        cx = -length / 2 + (i + 0.5) * length / clamps
        plate(f, rng, "WallPlate", cx, y, 0.4, diameter + 0.5, 0.08, METAL_DARK, "Metal")
        f.part("Clamp", (cx, y, zc), (0.2, diameter + 0.1, diameter + 0.1), METAL_DARK, "Metal", shape=CYLINDER,
               flags=DECOR)
        # (the stem from inside the wall: its end hidden in the brick)
        _zbox(f, "Clamp", cx - 0.03, cx + 0.03, y - 0.06, y + 0.06, (-0.06, -zc), METAL_DARK, "Metal", flags=DECOR)
        n += 3
    end = length / 2
    if drop in ("down", "up"):
        f.part("Elbow", (end, y, zc), (diameter + 0.12, diameter + 0.12, diameter + 0.12), jitter(pc, rng, 4, 0.1), mat,
               shape=BALL, flags=DECOR)
        y1 = 0.0 if drop == "down" else y + rng.uniform(5, 10)
        rod(f, "Pipe", (end, y, zc), (end, y1, zc), diameter, jitter(pc, rng, 4), mat, flags=SMALL)
        n += 2
        if drop == "down":
            f.part("GroundCollar", (end, 0.1, zc), (0.2, diameter + 0.4, diameter + 0.4), CONCRETE_DARK, "Concrete",
                   rot=(0, 0, 90), shape=CYLINDER, flags=DECOR)
            n += 1
    else:
        f.part("Cap", (end + 0.05, y, zc), (0.2, diameter + 0.1, diameter + 0.1), jitter(pc, rng, 4, 0.15), mat,
               shape=CYLINDER, flags=DECOR)
        n += 1
    if valve if valve is not None else rng.random() < 0.4:
        vx = rng.uniform(-length / 3, length / 3)
        _zbox(f, "ValveBody", vx - 0.25, vx + 0.25, y + diameter / 2 - 0.1, y + diameter / 2 + 0.35,
              (-zc - 0.22, -zc + 0.22), jitter(pc, rng, 4, 0.2), mat, flags=DECOR)
        rod(f, "Stem", (vx, y + diameter / 2 + 0.35, zc), (vx, y + diameter / 2 + 0.75, zc), 0.1, METAL_DARK, "Metal",
            flags=DECOR)
        n += 2
        wc = jitter((110, 40, 34), rng, 8)
        wy, wr = y + diameter / 2 + 0.75, 0.48
        g = f.sub((vx, wy, zc), ry=rng.uniform(0, 60))
        for i in range(6):  # the rim: a hexagon of flat bars
            a0, a1 = math.radians(60 * i), math.radians(60 * (i + 1))
            beam(g, "Wheel", (wr * math.cos(a0), 0, wr * math.sin(a0)), (wr * math.cos(a1), 0, wr * math.sin(a1)), 0.07,
                 0.07, wc, "Metal", side=(0, 1, 0), flags=DECOR)
        for a in (0, 180):  # two spokes from the hub (they don't meet: the hub covers the middle)
            c_, s_ = math.cos(math.radians(a)), math.sin(math.radians(a))
            beam(g, "Wheel", (0.08 * c_, 0, 0.08 * s_), (wr * c_, 0, wr * s_), 0.06, 0.06, wc, "Metal", side=(0, 1, 0),
                 flags=DECOR)
        bolt(g, "Wheel", (0, 0, 0), 0.18, wc)
        n += 9
    return n


def downpipe(D, folder, origin, ry, rng, height=24.0, x=0.0, gutter=6.0, color=None):
    """A rain downpipe from the roof edge: a sagging box gutter along the top (front bead, end
    caps, a broken length hanging off one end), the outlet and a swan neck (two round bends)
    stepping back toward the wall, one continuous round pipe down the wall with round socket
    collars at every joint and round pipe clips on stems into the wall, a cracked joint leaking
    a long wet stain, a kicked-out shoe at the foot (tag CityGutter: it spouts in the rain) over
    a green slimy patch on the wall. Footprint: gutter x 1, height tall. Parts: 22-32."""
    f = frame_at(D, folder, origin, ry).sub((x, 0, 0))
    pc = color or jitter(rng.choice([METAL_DARK, (60, 62, 60), (34, 34, 34), (70, 60, 52)]), rng, 6)
    n = 0
    kit = MESHPROP.LIBS
    if kit:
        # The kit's cast-iron lengths tile from the shoe's socket (y 1.2): 6.0 lengths, then 1.5
        # ones (never two overlapping: coaxial pipes would z-fight); the gutter comes down onto
        # the last socket (its underside just over it), so the run needs no swan neck.
        reach = height - 0.46 - 1.2
        n6 = int(reach // 6.0)
        n15 = int((reach - 6.0 * n6) // 1.5)
        height = 1.2 + 6.0 * n6 + 1.5 * n15 + 0.46
    # gutter (in its own frame: the sag tilts the gutter, its bead and its end caps together),
    # set where neither its capped end nor the broken length off its other end runs into a
    # neighbouring wall (a corner is often close)
    yg = height - 0.2
    choice = None
    for gl in (gutter, gutter * 0.8, gutter * 0.6, gutter * 0.45, 1.6):  # (shorter if it must be)
        for _try in range(12):
            gx = rng.uniform(-gl * 0.3, gl * 0.3) * (1 - _try / 12)
            sd = rng.choice((-1, 1))  # (the side the broken length hangs from)
            cap, brk = gx - sd * (gl / 2 + 0.1), gx + sd * (gl / 2 + 1.25)
            if not any(_solid_at(f, (xx, yy, -0.4)) for xx in (cap, brk, gx + sd * (gl / 2 + 0.6))
                       for yy in (yg + 0.35, yg, yg - 0.6, yg - 1.0)):
                choice = (gl, gx, sd, True)
                break
            if choice is None and not any(_solid_at(f, (gx + e * (gl / 2 + 0.1), yy, -0.4)) for e in (-1, 1)
                                          for yy in (yg - 0.3, yg, yg + 0.35)):
                choice = (gl, gx, sd, False)  # (no room for the broken length: both ends capped)
        if choice is not None:
            break
    gl, gx, sd, broken = choice or (1.6, 0.0, 1, False)
    g = f.sub((gx, yg, 0), rz=rng.uniform(-1.2, 1.2))
    gcol = jitter(pc, rng, 4)
    # (its back sunk into the wall: no face of it on the stains' planes behind it)
    _zbox(g, "Gutter", -gl / 2, gl / 2, -0.2, 0.2, (-0.06, 0.75), gcol, "Metal", flags=DECOR)
    _zbox(g, "GutterLip", -gl / 2, gl / 2, 0.2, 0.28, (0.68, 0.8), jitter(pc, rng, 4, 0.1), "Metal", flags=DECOR)
    n += 2
    for e in ((-sd,) if broken else (-1, 1)):
        a, b = e * (gl / 2 + 0.004), e * (gl / 2 + 0.064)
        _zbox(g, "GutterEnd", min(a, b), max(a, b), -0.27, 0.35, (-0.06, 0.84), jitter(gcol, rng, 3), "Metal",
              flags=DECOR)
        n += 1
    if broken:  # a broken length hanging off the other end
        f.part("GutterBroken", (gx + sd * (gl / 2 + 0.62), height - 0.62, -0.45), (1.2, 0.36, 0.56),
               jitter(pc, rng, 4, 0.1), "Metal", rot=(0, 0, sd * -rng.uniform(15, 35)), flags=DECOR)
        n += 1
    d = 0.36  # (real: 68-110 mm)
    zc = -0.38
    top = height - 2.1
    leaks = []

    def pipe():
        nonlocal n
        # outlet + swan neck: down from the gutter, a step back toward the wall, down again
        n += bend(f, "SwanNeck", [(0, height - 0.3, -0.45), (0, height - 0.95, -0.45), (0, height - 1.55, zc),
                                  (0, top, zc)], d, pc, "Metal", flags=DECOR)
        # the pipe: one length from the swan neck to the shoe; socket collars and clips
        rod(f, "Downpipe", (0, top, zc), (0, 0.9, zc), d, jitter(pc, rng, 3), "Metal", flags=DECOR_SHADOW)
        n += 1
        joints = rng.randint(3, 4)
        leak = rng.randrange(joints)
        for i in range(joints):
            a = top - (i + 0.15) * (top - 0.9) / joints
            f.part("Collar", (0, a, zc), (0.32, d + 0.1, d + 0.1), jitter(pc, rng, 3, 0.1), "Metal", rot=(0, 0, 90),
                   shape=CYLINDER, flags=DECOR)
            cy_ = a - 0.55
            f.part("Clip", (0, cy_, zc), (0.16, d + 0.07, d + 0.07), METAL_DARK, "Metal", rot=(0, 0, 90),
                   shape=CYLINDER, flags=DECOR)
            rod(f, "Clip", (0, cy_, 0.06), (0, cy_, zc), 0.06, METAL_DARK, "Metal", flags=DECOR)  # (its stem, in the wall)
            n += 3
            if i == leak:  # (a cracked joint: the wet stain stays on the wall, out of the kit's markers)
                leaks.append(a)
                if not kit:
                    leak_stain(a)

    def leak_stain(a):
        nonlocal n
        n += streak(f, rng, "Leak", rng.uniform(0.35, 0.6) * rng.choice((-1, 1)), a - 0.2,
                    rng.uniform(4, max(4.5, a - 1.5)), 0.7, WET_DARK, k=0, tr=0.5, taper=3)

    def shoe():
        nonlocal n
        # the shoe (kicked out at the foot): a bend and a short spout, the tagged shoe at its end
        f.part("ShoeBend", (0, 0.9, zc), (d * 1.04, d * 1.04, d * 1.04), jitter(pc, rng, 4, 0.1), "Metal", shape=BALL,
               flags=DECOR)
        f.part("Shoe", (0.0, 0.66, zc - 0.22), (0.62, d, d), jitter(pc, rng, 4, 0.1), "Metal", rot=(0, 90, -40),
               shape=CYLINDER, flags=DECOR, extra={"t": ["CityGutter"]})
        n += 2

    if kit:
        tint = tuple(pc)
        frame_meshprop(D, folder, "DownpipeShoe", f, shoe, tint=tint)
        y = 1.2
        for i in range(n6):
            frame_meshprop(D, folder, "DownpipeStraight", f.sub((0, y, 0)), pipe if i == 0 else None, tint=tint)
            frame_meshprop(D, folder, "DownpipeBracket", f.sub((0, y + 3.0, 0)), tint=tint)
            y += 6.0
        for i in range(n15):
            frame_meshprop(D, folder, "DownpipeStraightShort", f.sub((0, y, 0)), pipe if i == 0 and not n6 else None,
                           tint=tint)
            y += 1.5
        n += 2 * n6 + n15 + 1
        joints = [1.2 + 6.0 * (i + 1) for i in range(n6)] + [1.2 + 6.0 * n6 + 1.5 * (i + 1) for i in range(n15)]
        for a in leaks:  # (from the kit joint nearest the old cracked one)
            leak_stain(min(joints[:-1] or joints, key=lambda j: abs(j - a)) + 0.2)
    else:
        pipe()
        shoe()
    # green slime on the wall round the foot (moss where the water splashes)
    n += soft(f, rng, "Slime", -0.9, 1.1, 0, rng.uniform(1.2, 2.0), jitter(MOSS, rng, 6, 0.2), opacity=0.6, k=0,
              anchor="bottom", material="Grass")
    return n


def vent_hood(D, folder, origin, ry, rng, y=8.0, x=0.0, width=None, grease=True):
    """A kitchen / boiler exhaust through the wall: a square duct stub with a dark mouth,
    louvred blades (slanted), a sloped rain cowl over it, a black soot plume rising up the
    wall (a mosaic on one slot: a dark core over the cowl, a lighter, wider tongue above it
    ending in one tall off-centre point) and brown grease weeping below.
    Footprint: ~2 x 1.2. Parts: 10-16."""
    f = frame_at(D, folder, origin, ry).sub((x, y, 0))
    w = width or rng.uniform(1.6, 2.4)
    h = w * rng.uniform(0.8, 1.0)
    c = jitter(rng.choice([GALV, (90, 86, 76), METAL]), rng, 6, 0.15)
    n = 0
    _zbox(f, "Duct", -w / 2 - 0.15, w / 2 + 0.15, -0.15, h + 0.15, (0, 0.6), c, "Metal", flags=DECOR)
    _zbox(f, "Mouth", -w / 2, w / 2, 0, h, (0.6, 0.68), (14, 14, 14), "Metal", flags=DECOR)
    n += 2
    blades = max(3, int(h / 0.38))
    for i in range(blades):
        yy = (i + 0.5) * h / blades
        f.part("Blade", (0, yy, -0.84), (w, h / blades * 0.95, 0.06), jitter(c, rng, 3, 0.1 + 0.05 * (i == 1)), "Metal",
               rot=(-38 + rng.uniform(-4, 4), 0, 0), flags=DECOR)
        n += 1
    # the rain cowl: a wedge on the duct, tall at the wall, sloping out over the blades
    f.part("Cowl", (0, h + 0.15 + 0.17, -0.5), (w + 0.5, 0.34, 1.0), jitter(c, rng, 3, 0.08), "Metal", shape=WEDGE,
           flags=DECOR)
    n += 1
    # soot plume: a dark core over the cowl, then a lighter tongue a little wider, rising to one
    # tall, off-centre point (soot climbs where the warm air goes, it does not fan out evenly)
    y0 = h + 0.5
    core_h = rng.uniform(0.5, 0.9)
    cw = w * rng.uniform(0.8, 0.95)
    cx = rng.uniform(-0.1, 0.1) * w
    n += _ok(overlay(f, "SootPlume", cx - cw / 2, cx + cw / 2, y0, y0 + core_h, jitter(SOOT, rng, 3), k=0, tr=0.5))
    fan_h = rng.uniform(1.4, 2.4)
    tw = w * rng.uniform(1.0, 1.25)
    tx = cx + rng.uniform(-0.15, 0.15) * w
    fy = y0 + core_h
    col2 = jitter(mix(SOOT, (60, 54, 50), 0.3), rng, 3)
    if overlay(f, "SootPlume", tx - tw / 2, tx + tw / 2, fy, fy + fan_h, col2, k=0, tr=0.8) is not None:
        n += 1
        n += ragged_top(f, rng, "SootPlume", tx - tw / 2, tx + tw / 2, fy + fan_h, rng.uniform(0.9, 1.7), col2,
                        k=0, tr=0.8, peaks=1)
    if grease:
        n += streak(f, rng, "Grease", rng.uniform(-w / 4, w / 4), -0.2, rng.uniform(1.5, 3.5), 0.7, (64, 44, 24), k=0,
                    tr=0.4, taper=3)
    return n


def satellite_dish(D, folder, origin, ry, rng, y=12.0, x=0.0, size=None):
    """An old satellite dish on a wall bracket, pointing up and sideways: a round wall plate
    with bolt heads, the arm, the dish (a dirty white disc with a smaller back shell: Roblox
    balls can't be flattened, they stay spheres), the LNB arm and head looking back at the
    dish, a rust spot, the coax cable clipped down the wall, a rust stain under the plate.
    Footprint: ~2.2 x 2.4. Parts: 10-13."""
    f = frame_at(D, folder, origin, ry).sub((x, y, 0))
    d = size or rng.uniform(1.8, 2.6)
    n = 0
    pz = 0.12
    plate(f, rng, "Plate", 0, 0, 0.8, 0.8, pz, METAL_DARK, "Metal", shape=CYLINDER)
    for a in (45, 225):
        bolt(f, "Bolt", (0.28 * math.cos(math.radians(a)), 0.28 * math.sin(math.radians(a)), -pz), 0.1, RUST_DARK)
    rod(f, "Arm", (0, 0, -0.1), (0, 0.1, -1.1), 0.16, METAL_DARK, "Metal", flags=DECOR)
    n += 4
    yaw = rng.uniform(-35, 35)
    g = f.sub((0, 0.1, -1.2), ry=yaw, rx=rng.uniform(20, 35))
    white = jitter((166, 164, 156), rng, 8, 0.15)

    def disc(name, dia, z0, z1, col, mat="SmoothPlastic"):
        g.part(name, (0, 0, -(z0 + z1) / 2), (z1 - z0, dia, dia), col, mat, rot=(0, 90, 0), shape=CYLINDER,
               flags=DECOR)

    disc("Dish", d, 0.0, 0.07, white)
    disc("DishBack", d * 0.55, -0.16, 0.0, jitter(white, rng, 4, 0.12))
    rod(g, "LnbArm", (0, -d * 0.45, -0.04), (0, -0.12, -d * 0.55), 0.08, (90, 90, 86), "Metal", flags=DECOR)
    g.part("Lnb", (0, -0.08, -d * 0.6), (0.22, 0.22, 0.4), (40, 40, 40), "Plastic", rot=(-35, 0, 0), flags=DECOR)
    n += 4
    for _ in range(rng.randint(1, 2)):  # rust spots: small round blooms on the dish face
        g.part("RustSpot", (rng.uniform(-d / 4, d / 4), rng.uniform(-d / 4, d / 4), -0.07 - 0.04),
               (0.08, 0.2, 0.2), RUST_STAIN, "CorrodedMetal", rot=(0, 90, 0), shape=CYLINDER, flags=DECOR)
        n += 1
    cy = -rng.uniform(4, 8)
    rod(f, "Coax", (0.2, -0.4, -0.12), (0.25, cy, -0.12), 0.06, CABLE, "Rubber", flags=DECOR)
    n += 1
    n += streak(f, rng, "RustStreak", 0, -0.45, rng.uniform(1.2, 2.5), 0.4, RUST_STAIN, k=0, taper=3)
    return n


# =================================================================================================
# 5. Wall lights (with a light extra)
# =================================================================================================


def bulkhead_light(D, folder, origin, ry, rng, y=8.0, x=0.0, dead=False, flicker=False, color=WARM, range_=18,
                   brightness=0.9):
    """A caged bulkhead light: cast back plate, body, frosted globe (the bulb part, Neon,
    carries the light: tag CityBulkhead, or CityLamp with Dead / Flicker like alleys.py
    wall_light), a wire cage (the bars at two depths: they cross), a conduit up to a junction
    box, soot and dead insects stain above, rust under. Footprint: 0.9 x 0.9, 1 tall
    (+ conduit). Parts: 11-16."""
    f = frame_at(D, folder, origin, ry).sub((x, y, 0))
    n = 0
    plate(f, rng, "BackPlate", 0, 0, 0.9, 1.0, 0.12, jitter((50, 50, 48), rng, 6), "Metal")
    _zbox(f, "Body", -0.32, 0.32, -0.38, 0.38, (0.06, 0.42), jitter((66, 66, 60), rng, 6), "Metal", flags=DECOR)
    for bx, by in ((-0.36, 0.42), (0.36, -0.42)):
        bolt(f, "Bolt", (bx, by, -0.12), 0.1, (40, 40, 38))
    n += 4
    attrs = {}
    if dead:
        attrs["Dead"] = True
    if flicker:
        attrs["Flicker"] = True
    tag = "CityLamp" if (dead or flicker) else "CityBulkhead"
    f.part("Bulb", (0, 0, -0.55), (0.46, 0.46, 0.46), (90, 90, 86) if dead else color, "Neon" if not dead else "Glass",
           shape=BALL, flags=DECOR,
           extra=light_extra([tag], {"type": "Point", "color": list(color), "range": range_, "brightness": brightness,
                                     "name": "Light", "shadows": False}, attrs or None))
    n += 1
    for a in (-0.2, 0.2):  # cage: two upright bars, then a cross bar in front of them
        _zbox(f, "Cage", a - 0.03, a + 0.03, -0.36, 0.36, (0.74, 0.8), (36, 36, 36), "Metal", flags=DECOR)
        n += 1
    _zbox(f, "Cage", -0.3, 0.3, -0.03, 0.03, (0.8, 0.86), (36, 36, 36), "Metal", flags=DECOR)
    for s in (-1, 1):  # the cage's side legs back to the body
        _zbox(f, "Cage", -0.26, 0.26, s * 0.36 - 0.03, s * 0.36 + 0.03, (0.42, 0.74), (36, 36, 36), "Metal", flags=DECOR)
    n += 3
    top = rng.uniform(2.0, 4.0)
    rod(f, "Conduit", (0, 0.5, -0.15), (0, top, -0.15), 0.14, jitter((70, 70, 66), rng, 6), "Metal", flags=DECOR)
    _zbox(f, "JunctionBox", -0.25, 0.25, top, top + 0.5, (0, 0.4), jitter((70, 70, 66), rng, 6), "Metal", flags=DECOR)
    n += 2
    n += soft(f, rng, "Soot", -0.8, 0.8, top + 0.6, top + rng.uniform(1.3, 2.0), SOOT, opacity=0.25, k=0,
              anchor="bottom")
    n += streak(f, rng, "RustStreak", rng.uniform(-0.3, 0.3), -0.55, rng.uniform(0.8, 1.8), 0.3, RUST_STAIN, k=0,
                taper=3)
    return n


def gooseneck_lamp(D, folder, origin, ry, rng, y=10.0, x=0.0, reach=2.2, dead=False, flicker=False, color=None,
                   range_=24, brightness=1.2):
    """A gooseneck barn lamp: a round wall plate, a smooth bent arm (pipe lengths joined by
    round bends) curving out and down, a shallow enamel dish shade (a cone of wedges over a
    white reflector disc: dark outside, white inside), the bulb under it (Neon, Spot light
    facing down, tag CityLamp; Dead / Flicker), rust and soot. Footprint: 1.6 x (reach + 0.8),
    ~2 tall. Parts: 16-22."""
    f = frame_at(D, folder, origin, ry).sub((x, y, 0))
    color = color or [255, 168, 96]
    shade = jitter(rng.choice([(40, 54, 46), (34, 34, 36), (70, 34, 30)]), rng, 6)
    n = 0
    plate(f, rng, "WallPlate", 0, 0, 0.7, 0.7, 0.12, METAL_DARK, "Metal", shape=CYLINDER)
    n += 1
    r_ = reach
    pts = [(0, 0.0, -0.12), (0, 0.45, -0.5), (0, 0.8, -1.2), (0, 0.8, -r_ + 0.3), (0, 0.5, -r_)]
    n += bend(f, "Arm", pts, 0.12, jitter(shade, rng, 4, 0.2), "Metal", flags=DECOR)
    sy, sz = 0.36, -r_
    f.part("ShadeNeck", (0, sy + 0.12, sz), (0.24, 0.22, 0.22), shade, "Metal", rot=(0, 0, 90), shape=CYLINDER,
           flags=DECOR)
    # under the cone: the rolled rim (shade colour, a little wider than the cone: it also hides
    # where the cone's facets meet) and the white enamel inside
    f.part("ShadeRim", (0, sy - 0.035, sz), (0.07, 1.84, 1.84), jitter(shade, rng, 4), "Metal", rot=(0, 0, 90),
           shape=CYLINDER, flags=DECOR)
    f.part("Reflector", (0, sy - 0.105, sz), (0.07, 1.3, 1.3), (196, 192, 180), "SmoothPlastic", rot=(0, 0, 90),
           shape=CYLINDER, flags=DECOR)
    n += 3
    n += cone(f, "Shade", 0, sy, sz, 0.78, 0.36, shade, "Metal", n=6, flags=DECOR_SHADOW)
    attrs = {}
    if dead:
        attrs["Dead"] = True
    if flicker:
        attrs["Flicker"] = True
    f.part("LampHead", (0, sy - 0.28, sz), (0.3, 0.3, 0.3), (90, 90, 86) if dead else tuple(color),
           "Glass" if dead else "Neon", shape=BALL, flags=DECOR,
           extra=light_extra(["CityLamp"], {"type": "Spot", "color": list(color), "range": range_,
                                            "brightness": brightness, "angle": 100, "face": "Bottom",
                                            "shadows": True, "name": "Light"}, attrs or None))
    n += 1
    n += soft(f, rng, "Soot", -0.7, 0.7, 0.45, rng.uniform(1.4, 2.2), SOOT, opacity=0.2, k=0, anchor="bottom")
    n += streak(f, rng, "RustStreak", 0, -0.45, rng.uniform(1, 2.2), 0.35, RUST_STAIN, k=0, taper=3)
    return n


# ------------------------------------------------------------------ catalogue
WALL_PROPS = {
    "wall_grime": wall_grime, "plaster_patch": plaster_patch, "crack": crack, "rust_streak": rust_streak,
    "efflorescence": efflorescence, "torn_posters": torn_posters, "painted_sign": painted_sign,
    "graffiti_tag": graffiti_tag, "window": window, "back_door": back_door, "roller_shutter": roller_shutter,
    "fire_escape": fire_escape, "building_top": building_top, "background_facade": background_facade,
    "chainlink_fence": chainlink_fence, "ac_unit": ac_unit, "meter_box": meter_box, "cable_sag": cable_sag,
    "pipe_run": pipe_run, "downpipe": downpipe, "vent_hood": vent_hood, "satellite_dish": satellite_dish,
    "bulkhead_light": bulkhead_light, "gooseneck_lamp": gooseneck_lamp,
}

__all__ = list(WALL_PROPS) + ["WALL_PROPS", "beam", "rod", "bend", "bolt", "overlay", "streak", "soft", "tri",
                              "tri_part", "cone"]

_ = (BLOCK, PROP)  # (re-exported flags kept for callers)
