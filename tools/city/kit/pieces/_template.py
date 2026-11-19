"""TEMPLATE for a family module of the city prop kit (copy it to pieces/<family>.py; files
starting with "_" are not loaded, so this one never ends up in the kit).

HOW A PIECE IS MADE
  * A module exposes PIECES = {"PieceName": build_fn}. Names: letters and digits, starting with
    a capital (TrashBag1, TrashBag2...). Several distinct pieces for things that repeat, so
    copies are not identical; the data adds per-copy tint / scale / yaw on top.
  * build_fn(ctx) gets a kitlib.Piece and adds closed bmeshes to material layers:
        ctx.add("Plastic", bm, matrix=None)
    Layers (one MeshPart each, coloured by the game, PropKit.luau LOOKS): Plastic*, PlasticDark,
    Rubber, Reflective, Metal, MetalPainted*, Rust, Wood, WoodDark, Fabric*, FabricDark,
    Leather, Foam, Cardboard, Paper, Concrete, Brick, Tarp*, Glass, Screen, Chrome, Black,
    Glow, Soil (* = tintable: ctx.tint(layer, (r, g, b)) gives its default colour).
  * Space: Roblox axes, studs. +Y up, the front faces -Z. Floor pieces: origin = centre of the
    footprint on the floor (y = 0). Wall pieces: origin on the wall face, -Z out of the wall.
    1 stud ~ 0.3 m, props drawn ~15 % large (see real_specs / props_*.py footprints): match
    the footprint of the props_*.py function the piece replaces, keep real proportions.
  * Wear = vertex colours, a multiplier 0.35..1.0 per layer: ctx.wear(layer, fn), fn(p) with
    p.co (Vector, piece space), p.normal, p.convex (> 0 on edges, < 0 in creases) returning a
    float or (r, g, b). Helpers in kitlib: ground_dirt, cavity, edge_wear, streaks, scuffs,
    mul(...). Wear follows POSITION: dirt rises from the ground, grime in creases, scuffs on
    edges, drips run down. Without ctx.wear a layer gets kitlib.default_wear.
  * Markers: ctx.mark("Light", at) where the PointLight of a lamp goes, ctx.mark("Fx", at)
    where particles come out (fire, steam). The game moves the old parts' lights there.
  * NO BOTTLES of any kind, nothing that reads as one (no tall gas cylinders either).

CHECKLIST (do every point, then LOOK at the previews and iterate)
  1. Real reference: real_specs.md (sizes, what makes it recognisable), photos in your head.
  2. Silhouette first: the outline must read from 20 studs away. Enough segments on round
     things (16-32), spend triangles on the outline, not on flat faces.
  3. Bevel every visible hard edge (0.02-0.06 studs): box(..., bevel=), cyl(..., bevel=),
     bevel_edges(). No knife edges, no raw boxes.
  4. One mesh per material layer; layers never share a face: a layer laid on another is
     PROUD of it (>= 0.02 studs between the two visible surfaces, or recess the one below,
     as the cone's collars do). Nothing coplanar, no box sunk flush in another, no vertex ring
     lying exactly in another surface's plane (cross it mid-face).
  5. Real details: rims, lips, seams, handles, hinges, bolts, ribs, drainage holes, labels as
     raised/recessed geometry (never a flat card on a face).
  6. Imperfections: dents, squash, lean, worn edges (kitlib.displace, Noise), different per
     variant. Not random noise everywhere: where real use would put it.
  7. Vertex-colour wear (see above), checked on the previews (too dark = filthy blobs). The
     colour lives on vertices: a plain box has 8 + its bevels, so add rings / cuts where a
     gradient must show (more rings in a lathe profile, bmesh.ops.subdivide_edges...).
  8. Origin and axes right (front = -Z); check the "low" view: it sits ON the floor.
  9. Budget: ctx.budget (default 3000 triangles for a small prop, up to 8000 for a hero
     prop); each layer < 10 000. The build prints the counts.
 10. Preview, LOOK, fix, repeat. State what you changed after looking.

FAST LOOP (one piece, quick renders, the FBX untouched):
    venv/bin/python -I tools/city/kit/build_city_kit.py /tmp/kit --only MyPiece --preview /tmp/pv --fast
    (--shots close,low for fewer views; then the full quality preview without --fast)
Final: venv/bin/python -I tools/city/kit/build_city_kit.py assets/cityprops   (every piece:
writes CityProps.fbx, README.md and pieces.json, which tools/city/meshprop.py reads).
"""

import math  # noqa: F401  (most pieces need it)

from kitlib import T, R, box, cyl, lathe, mul, ground_dirt, cavity, edge_wear  # noqa: F401


def example_crate(ctx):
    """A small wooden crate (example only): bevelled body, two darker battens on the front,
    dirt rising from the floor."""
    ctx.budget = 600
    ctx.add("Wood", box(1.2, 0.8, 0.9, bevel=0.03), T(0, 0.4, 0))  # body, sitting on the floor
    for y in (0.2, 0.6):
        # battens PROUD of the front face (front = -Z): 0.04 thick, their back 0.01 into the body
        ctx.add("WoodDark", box(1.24, 0.1, 0.05, bevel=0.015), T(0, y, -0.45 - 0.015))
    ctx.wear("Wood", mul(ground_dirt(0.35, 0.3, ctx.noise), cavity(0.3), edge_wear(0.1)))


PIECES = {"ExampleCrate": example_crate}
