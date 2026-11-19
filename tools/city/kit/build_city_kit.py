"""
Builds the city prop kit (CityProps.fbx): the alleys' props as real meshes.

    venv/bin/python -I tools/city/kit/build_city_kit.py assets/cityprops [--only A,B]
                    [--preview DIR] [--fast] [--night] [--shots close,...] [--export]

  (no --only)   builds EVERY piece, checks them, writes <out>/CityProps.fbx and <out>/README.md
  --only A,B    builds only these pieces (checks + previews), and does NOT write the FBX unless
                --export is given too (a partial kit would drop the other pieces)
  --preview DIR renders each piece to DIR/<Piece>_{front,back,top,low,close}.png: four angles
                and a close-up, next to a 1.8 m human silhouette (LOOK at them)
  --fast        smaller, noisier previews (400 x 264, 10 samples) to iterate quickly
  --night       previews at night under a warm bulb
  --shots a,b   only these views (front, back, top, low, close)

Pieces come from tools/city/kit/pieces/*.py (not the ones starting with "_"): each module has
PIECES = {"PieceName": build_fn}, build_fn(ctx) fills a kitlib.Piece (see kitlib.py and
pieces/_template.py). Each piece is built at its own spot along +X (Roblox axes), with its
markers "<Piece>_Pivot" (+ "_Light" / "_Fx"), and the kit markers Kit_Origin / Kit_Up /
Kit_Out (1 stud apart, Kit_Up = +Y, Kit_Out = +Z) as in tools/rift/build_rift_gear.py: the
game measures them to undo whatever scale / axes the importer applied.

Checks (the build fails on any): layer names from kitlib.LAYERS, each layer mesh < 10 000
triangles, each piece within its ctx.budget (default 3 000, hero props up to 8 000), piece names
letters and digits only, and NO name containing "bottle" (the player's absolute rule).
"""

import hashlib
import json
import importlib
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "pieces"))

import bpy  # noqa: E402  isort: skip
from mathutils import Vector  # noqa: E402

import kitlib  # noqa: E402

args = sys.argv[1:]
OUT = args[0] if args and not args[0].startswith("--") else None


def opt(name, default=None):
    return args[args.index(name) + 1] if name in args else default


ONLY = [s for s in (opt("--only") or "").split(",") if s]
PREVIEW = opt("--preview")
FAST = "--fast" in args
NIGHT = "--night" in args
SHOTS = [s for s in (opt("--shots") or "").split(",") if s]
EXPORT = OUT is not None and (not ONLY or "--export" in args)
GAP = 4.0  # studs between pieces in the kit
LAYER_TRIS = 10000
HERO_TRIS = 8000


def load_pieces():
    """{name: (build_fn, module name)} from every pieces/*.py not starting with "_"."""
    found = {}
    for fn in sorted(os.listdir(os.path.join(HERE, "pieces"))):
        if not fn.endswith(".py") or fn.startswith("_"):
            continue
        mod = importlib.import_module(fn[:-3])
        for name, build in getattr(mod, "PIECES", {}).items():
            if name in found:
                raise SystemExit(f"piece {name} defined twice ({found[name][1]} and {fn})")
            found[name] = (build, fn)
    return found


def seed_of(name):
    return int(hashlib.md5(name.encode()).hexdigest()[:8], 16)


def check_name(name):
    if not re.fullmatch(r"[A-Z][A-Za-z0-9]*", name):
        raise SystemExit(f"bad piece name {name!r}: letters and digits, starting with a capital")
    if "bottle" in name.lower():
        raise SystemExit(f"{name}: no bottles of any kind (the player's rule)")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    pieces = load_pieces()
    names = sorted(pieces)
    if ONLY:
        missing = [n for n in ONLY if n not in pieces]
        if missing:
            raise SystemExit(f"unknown piece(s): {', '.join(missing)} (have: {', '.join(names)})")
        names = ONLY
    objects, rows, spots = [], [], {}
    x = 0.0
    for name in names:
        check_name(name)
        build, module = pieces[name]
        ctx = kitlib.Piece(name, seed_of(name))
        build(ctx)
        if not ctx.layers:
            raise SystemExit(f"{name}: no geometry")
        doc = ctx.doc or " ".join((build.__doc__ or "").split())
        # build at the origin first to measure, then move along +X
        objs, stats = kitlib.make_objects(ctx, (0, 0, 0))
        lo, hi = kitlib.bounds(objs)
        x += -lo.x
        shift = kitlib.to_blender(Vector((x, 0, 0)))
        for ob in objs:
            ob.location += shift
        spots[name] = (Vector((x, 0, 0)), lo, hi, objs)
        x += hi.x + GAP
        total = sum(stats.values())
        for layer, tris in stats.items():
            if tris >= LAYER_TRIS:
                raise SystemExit(f"{name}_{layer}: {tris} triangles (one MeshPart must stay < {LAYER_TRIS})")
        if total > min(ctx.budget, HERO_TRIS):
            print(f"WARNING {name}: {total} triangles, over its budget {min(ctx.budget, HERO_TRIS)}")
        size = hi - lo
        print(f"{name:22s} {total:6d} tris  size {size.x:.2f} x {size.y:.2f} x {size.z:.2f}  "
              + "  ".join(f"{k}:{v}" for k, v in stats.items()))
        rows.append((name, module, sorted(stats), total, lo, hi, sorted(ctx.markers), doc, dict(ctx.tints)))
        objects += objs
    for ob in objects:
        if "bottle" in ob.name.lower():
            raise SystemExit(f"{ob.name}: no bottles")
    for name, at in (("Kit_Origin", (0, -4, 0)), ("Kit_Up", (0, -3, 0)), ("Kit_Out", (0, -4, 1))):
        objects.append(kitlib.marker(name, Vector(at)))

    if EXPORT:
        os.makedirs(OUT, exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        for ob in objects:
            ob.select_set(True)
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(OUT, "CityProps.fbx"),
            use_selection=True,
            object_types={"MESH"},
            use_mesh_modifiers=True,
            mesh_smooth_type="OFF",
            colors_type="SRGB",
            axis_forward="-Z",
            axis_up="Y",
            apply_scale_options="FBX_SCALE_UNITS",
            bake_space_transform=True,
            path_mode="STRIP",
        )
        write_readme(rows)
        write_info(rows)
        print("written", os.path.join(OUT, "CityProps.fbx"))
    elif OUT:
        print("(--only without --export: CityProps.fbx left as it was)")
    if PREVIEW:
        render(spots)


def write_info(rows):
    """pieces.json: what the Python data side needs to place a piece without Blender
    (tools/city/meshprop.py): its bounds (studs, piece space), layers and default tints."""
    info = {}
    for name, module, layers, total, lo, hi, markers, doc, tints in rows:
        info[name] = {
            "min": [round(v, 3) for v in lo],
            "max": [round(v, 3) for v in hi],
            "layers": layers,
            "tint": {k: list(v) for k, v in tints.items()},
            "markers": markers,
            "tris": total,
        }
    with open(os.path.join(OUT, "pieces.json"), "w") as f:
        json.dump(info, f, indent=1, sort_keys=True)
        f.write("\n")


def write_readme(rows):
    lines = [
        "# City props (CityProps.fbx)",
        "",
        "Made by `tools/city/kit/build_city_kit.py` (Blender, run from the repo root):",
        "",
        "    venv/bin/python -I tools/city/kit/build_city_kit.py assets/cityprops [--preview <dir>]",
        "",
        "Each piece is a few meshes, one per material layer, named `<Piece>_<Layer>`; the game colours",
        "them (`src/server/Systems/City/PropKit.luau`, table LOOKS) and multiplies by the meshes' vertex",
        "colours (the wear). Markers (tiny cubes, never shown): `<Piece>_Pivot` (the piece's origin:",
        "the centre of its footprint on the floor, or on the wall face for wall pieces), optional",
        "`<Piece>_Light` / `<Piece>_Fx`, and `Kit_Origin` / `Kit_Up` / `Kit_Out` (how the importer",
        "turned and scaled the file). Axes: Roblox (Y up, the front faces -Z), studs.",
        "",
        "Import it into Studio: see `docs/PROPS_FR.md`.",
        "",
        "| Piece | Layers | Size x * y * z (studs) | Tris | What |",
        "|---|---|---|---|---|",
    ]
    for name, module, layers, total, lo, hi, markers, doc, tints in rows:
        size = hi - lo
        extra = (" (markers: " + ", ".join(markers) + ")") if markers else ""
        lines.append(f"| `{name}` | {', '.join(layers)} | {size.x:.2f} x {size.y:.2f} x {size.z:.2f} | {total} | {doc}{extra} |")
    lines.append("")
    with open(os.path.join(OUT, "README.md"), "w") as f:
        f.write("\n".join(lines))


def render(spots):
    """Each piece alone (the others hidden), the silhouette beside it."""
    os.makedirs(PREVIEW, exist_ok=True)
    res = (400, 264) if FAST else (640, 420)
    pv = kitlib.Preview(res=res, samples=10 if FAST else 24, night=NIGHT)
    human = kitlib.human_silhouette((0, 0, 0))
    every = [ob for spot in spots.values() for ob in spot[3]]
    for ob in every:
        if ob.name.endswith(kitlib.MARKER_SUFFIXES) or ob.name.startswith("Kit_"):
            ob.hide_render = True
    for name, (at, lo, hi, objs) in spots.items():
        for ob in every:
            if not ob.name.endswith(kitlib.MARKER_SUFFIXES):
                ob.hide_render = ob not in objs
        size = hi - lo
        c = at + (lo + hi) / 2
        big = max(size.x, size.y, size.z, 1.0)
        human.location = kitlib.to_blender(Vector((at.x + hi.x + 1.6, 0, at.z + 0.6)))
        pv.place_floor(Vector((at.x, 0, 0)))
        # (distances that fit the piece in a 50 mm frame; "front" also shows the silhouette)
        d = big * 2.1 + 0.8
        far = max(big, 6.2) * 1.35 + 2.0
        shots = [
            ("front", c + Vector((-0.45 * far, 0.32 * far, -0.9 * far)), Vector((c.x + 0.9, min(c.y, 2.8), c.z)), 40),
            ("back", c + Vector((0.62 * d, 0.45 * d, 0.75 * d)), c, 50),
            ("top", c + Vector((-0.3 * d, 1.0 * d, -0.55 * d)), c, 50),
            ("low", c + Vector((-0.8 * d, -0.25 * size.y + 0.25, -0.5 * d)), c + Vector((0, 0.05 * size.y, 0)), 50),
            ("close", c + Vector((-0.25 * d, 0.15 * d, -0.48 * d)), c + Vector((0, -0.2 * size.y, 0)), 50),
        ]
        for tag, eye, target, lens in shots:
            if SHOTS and tag not in SHOTS:
                continue
            path = os.path.join(PREVIEW, f"{name}_{tag}.png")
            pv.shoot(eye, target, path, lens)
            print("rendered", path)


if __name__ == "__main__":
    main()
