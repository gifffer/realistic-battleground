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

from citykit import DECOR

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
