"""meshprop: places a piece of the city prop kit (CityProps.fbx) in the city data.

    from meshprop import meshprop
    meshprop(D, folder, "TrafficCone", origin, ry, fallback=lambda: PO.traffic_cone(D, folder, origin, ry, rng))

What it writes:
  * a "MeshProp" marker part: invisible (transparency 1), DECOR (no collision, no query, no
    shadow), its CFrame = the piece's own origin (its pivot: the centre of the footprint on the
    floor, or on the wall face for wall pieces) turned by (rx, ry, rz) like every part
    (CFrame.fromEulerAnglesYXZ), its size = twice the piece's extent from the pivot (a box
    centred on the pivot that holds the piece, times `scale`), with the attributes Piece
    (string), Tint (optional, the string "r,g,b": the data's JSON has no Color3; PropKit also
    accepts a real Color3 attribute) and Scale (number, optional);
  * then `fallback()` inside D.under(marker): the old primitive parts of that prop, parented
    UNDER the marker. They are what shows when the kit is not imported yet, and the game
    (src/server/Systems/City/PropKit.luau) turns those that collide or are queried into
    invisible collision proxies once the mesh is there (so gameplay does not change) and
    removes the pure decoration. Lights, particles and tags on them survive.

The piece's bounds and default tints come from assets/cityprops/pieces.json, written by
tools/city/kit/build_city_kit.py (so this file needs no Blender). `size` overrides the bounds,
`tint` the default colour of the piece's tintable layer: an (r, g, b) tuple, 0..255.
Rotations / tilt: a knocked-over cone is the same piece with rx / rz; the marker's frame is
the piece's own frame, so tilting it about a point on the floor is the caller's job (as the
props_*.py fallbacks do with Frame.sub).
"""

import json
import os
import random

from citykit import DECOR, yxz_angles

# The prop libraries (props_*.py) swap some of their own sub-objects for kit pieces (a stall's
# goods, a rack's jackets, a stack's crates, a door's bulkhead...) through lib_meshprop(). That
# is OFF by default, so their previews and --check part counts stay the primitive props; a
# generator that wants the kit (tools/city/alleys.py) sets meshprop.LIBS = True before building.
LIBS = False

_INFO = None
_INFO_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "cityprops", "pieces.json")


def pieces():
    """{piece name: {"min", "max", "layers", "tint", "markers", "tris"}} from pieces.json ({} if
    the kit was never built)."""
    global _INFO
    if _INFO is None:
        try:
            with open(_INFO_PATH) as f:
                _INFO = json.load(f)
        except FileNotFoundError:
            _INFO = {}
    return _INFO


def meshprop(D, folder, piece, origin, ry, rx=0.0, rz=0.0, size=None, tint=None, scale=1.0, fallback=None):
    """Writes the MeshProp marker of `piece` at `origin` (its pivot, world studs) turned by
    (rx, ry, rz) degrees, then calls fallback() with every part it makes parented under the
    marker. Returns the marker's row index."""
    info = pieces().get(piece)
    if size is None:
        if info is None:
            raise KeyError(f"meshprop: unknown piece {piece!r} (build the kit, or pass size=)")
        lo, hi = info["min"], info["max"]
        size = tuple(max(abs(lo[i]), abs(hi[i])) * 2 for i in range(3))  # (centred on the pivot)
    size = tuple(max(0.05, v * scale) for v in size)
    attrs = {"Piece": piece}
    if tint is None and info and info.get("tint"):
        tint = next(iter(info["tint"].values()))
    if tint is not None:
        attrs["Tint"] = ",".join(str(int(round(c))) for c in tint)  # (JSON has no Color3: "r,g,b")
    if scale != 1.0:
        attrs["Scale"] = round(float(scale), 3)
    marker = D.part(folder, "MeshProp", tuple(origin), size, (128, 128, 128), "SmoothPlastic", flags=DECOR,
                    rot=(rx, ry, rz), transparency=1.0, extra={"a": attrs})
    if fallback is not None:
        with D.under(marker):
            fallback()
    return marker


def lib_meshprop(D, folder, piece, origin, ry, fallback, **kw):
    """meshprop() when LIBS is on, else just fallback() (the primitive prop, no marker). For the
    prop libraries' own sub-objects. Returns the marker's row index or None."""
    if LIBS:
        return meshprop(D, folder, piece, origin, ry, fallback=fallback, **kw)
    fallback()
    return None


def frame_meshprop(D, folder, piece, frame, fallback=None, lib=False, **kw):
    """meshprop() at a citykit.Frame's origin, turned like the frame (any rotation: its YXZ
    angles). `lib`: through lib_meshprop (only when LIBS is on)."""
    rx, ry, rz = yxz_angles(frame.m)
    origin = tuple(float(v) for v in frame.origin)
    if lib:
        return lib_meshprop(D, folder, piece, origin, ry, fallback or (lambda: None), rx=rx, rz=rz, **kw)
    return meshprop(D, folder, piece, origin, ry, rx=rx, rz=rz, fallback=fallback, **kw)


def variation(*key):
    """A random.Random seeded by `key` (deterministic across runs): the kit variant / tint / small
    tilt of one placed copy, drawn WITHOUT touching the props' own rng (so the primitive layout,
    which is the fallback, stays exactly as it was)."""
    return random.Random("|".join(str(k) for k in key))


def weathered(rgb, rng, amount=10, grey=0.12):
    """A real object's colour as it is after years outside: a little off its catalogue colour,
    slightly desaturated toward its own grey. (r, g, b) 0..255."""
    m = sum(rgb) / 3
    return tuple(max(0, min(255, round(c + (m - c) * grey * rng.uniform(0.5, 1.5) + rng.uniform(-amount, amount))))
                 for c in rgb)
