"""render_alleys: renders the alleys (and the city around them) as the player sees them, from
named cameras, with Blender Cycles (CPU). Two modes:

  --mode kit        what the game shows ONCE CityProps.fbx is imported: City/PropKit.luau is
                    simulated. Every "MeshProp" marker whose piece is in the kit gets that piece's
                    layer meshes (read from assets/cityprops/CityProps.fbx), placed at the marker's
                    CFrame and Scale, coloured like PropKit (kitlib LAYERS = PropKit LOOKS, the
                    marker's Tint on tintable layers, x the meshes' vertex colours "Col"); every
                    part under such a marker disappears (PropKit makes the proxies invisible and
                    removes the decoration); the live bulb (a part tagged CityLamp,
                    CityBulkhead...) hands its colour, material and light over to the Glow layer;
                    other lights move to the piece's Light marker.
  --mode fallback   what shows before the import: the primitive parts only (markers invisible).

    venv/bin/python -I tools/city/render_alleys.py --mode kit --time day \\
        --cams alleyA_mouth,kitchen --out /tmp/renders [--samples 16] [--size 880x550] [--world 1]
    venv/bin/python -I tools/city/render_alleys.py --list        (the named cameras)

Writes <out>/<cam>_<mode>_<time>.png. LOOK at every image (grazing cameras along walls are
there to catch z-fighting: coplanar faces show as noisy speckle). Keep renders small (the
machine is shared): <= 900x560, <= 20 samples + denoise.

Coordinates are Roblox studs (X east, Y up, Z south); Blender gets (x, -z, y).
"""

import argparse
import json
import math
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
CITY_DIR = os.path.join(ROOT, "src", "server", "Systems", "City")
KIT_FBX = os.path.join(ROOT, "assets", "cityprops", "CityProps.fbx")
sys.path.insert(0, os.path.join(HERE, "kit"))

# The region drawn (X0, X1, Z0, Z1) and the highest part centre kept.
REGION = (88, 266, 24, 136)
TOP = 120

# Named cameras: (eye, look-at, horizontal fov degrees[, cut]). A negative fov is an orthographic
# plan that many studs wide; `cut` (a Y) leaves out everything that starts above it (the rail
# tunnel over the courtyard, the viaduct's deck) so high views see the floor. Street views:
# eye 5-6 studs above the floor (FINISH = 1.255).
CAMS = {
    # Alley A (north of the viaduct): the Golden Dragon's back
    "alleyA_mouth": ((127.5, 6.3, 62.4), (160, 4.5, 61.6), 70),
    "alleyA_mid": ((145, 6.3, 64.6), (162, 4.2, 59.5), 70),
    "kitchen": ((147.6, 6.0, 65.0), (156.0, 3.4, 58.6), 76),
    "dumpster_side": ((162.6, 6.3, 63.8), (157.0, 3.8, 59.2), 66),
    # Alley B (south): the demolition job
    "alleyB_site": ((134.5, 6.3, 93.2), (160, 3.0, 95.4), 72),
    "alleyB_reverse": ((167.5, 6.3, 92.4), (146, 3.0, 95.0), 72),
    # the yard north: Vic's black market (arch X 175..187, opening at Z 72) and the container
    "market_close": ((180.2, 6.0, 63.4), (180.0, 3.4, 67.6), 62),
    "market_yard": ((174.5, 6.3, 63.6), (182.0, 3.6, 71.0), 74),
    "market_back": ((183.8, 6.0, 71.2), (178.6, 3.4, 77.6), 72),
    "container": ((177.5, 6.3, 67.8), (194, 4.0, 61.0), 72),
    # the yard south: the squat (arch X 181..193, opening at Z 92)
    "squat_fire": ((181.0, 6.0, 86.2), (187.4, 2.6, 96.4), 74),
    "squat_tent": ((198.0, 6.0, 94.2), (176.0, 2.6, 98.0), 74),
    "squat_mattress": ((185.4, 6.0, 84.4), (189.8, 1.8, 87.8), 66),
    # behind the fences: the east passage (X 199..205)
    "passage": ((202.2, 6.0, 73.4), (201.6, 2.6, 90.5), 70),
    # grazing along walls (posters, grime, windows): overlaps show here first
    "graze_A_north": ((167.0, 5.6, 59.3), (148, 5.0, 58.2), 60),
    "graze_B_south": ((168.0, 5.6, 96.9), (150, 5.0, 97.9), 60),
    "graze_arch": ((174.0, 6.0, 68.6), (171.6, 5.0, 72.0), 60),
    "graze_yard_north": ((185.2, 7.0, 57.4), (168, 6.5, 56.3), 62),
    # high views (cutaways: the rail tunnel / the roofs over the alleys left out)
    "high_alleyA": ((147.0, 15.0, 63.5), (162, 1.5, 61.0), 74, 16),
    "high_alleyB": ((147.5, 15.0, 92.0), (163, 1.5, 95.0), 74, 16),
    "high_yard_north": ((170.5, 20.0, 57.0), (192, 1.5, 67.0), 76, 22),
    "high_yard_south": ((170.5, 20.0, 101.0), (194, 1.5, 93.0), 76, 22),
    # plans (north up)
    "plan_yard_north": ((187.0, 80.0, 68.0), (187.0, 0.0, 67.99), -40, 22),
    "plan_yard_south": ((187.0, 80.0, 90.0), (187.0, 0.0, 89.99), -40, 22),
    "plan_alleyA": ((147.0, 80.0, 62.0), (147.0, 0.0, 61.99), -52, 16),
    "plan_alleyB": ((147.0, 80.0, 94.0), (147.0, 0.0, 93.99), -52, 16),
    # the rail tunnel's roof over the market (a CrtTv once landed up there: nothing must)
    "tv_check": ((171.0, 47.0, 70.0), (177.7, 42.6, 76.4), 60),
    # the rail tunnel's east end, its north corner (the end cladding wraps the side ones)
    "tunnel_end": ((204.0, 22.0, 66.0), (199.0, 34.5, 76.0), 64),
}


# ------------------------------------------------------------------------------ the data
def load(prefix):
    out, i = [], 1
    while os.path.exists(os.path.join(CITY_DIR, f"{prefix}{i}.luau")):
        with open(os.path.join(CITY_DIR, f"{prefix}{i}.luau")) as f:
            out.append(re.search(r"\[==\[(.*)\]==\]", f.read(), re.S).group(1))
        i += 1
    return json.loads("".join(out))


def rows():
    """Every part of the city + the alleys as (row, data, file key), the city parts the alleys
    replace left out."""
    city, alleys = load("CityData"), load("AlleyData")
    out = []
    for r in city["parts"]:
        f, n = city["folders"][r[15] - 1], city["names"][r[16] - 1]
        if any(f == x["folder"] and n == x["name"] and all(abs(r[1 + i] - x["at"][i]) < 0.05 for i in range(3))
               for x in alleys["remove"]):
            continue
        out.append((r, city, "c"))
    for r in alleys["parts"]:
        out.append((r, alleys, "a"))
    return out, city, alleys


def extra(r, d):
    return d["extras"][r[18] - 1] if r[18] else None


def in_region(p):
    return REGION[0] < p[0] < REGION[1] and REGION[2] < p[2] < REGION[3] and p[1] <= TOP


# ------------------------------------------------------------------------------ Blender
def build(mode, night, world, samples, size, exposure=0.0, ambient=0.0):
    import bpy  # noqa: I001  (bpy first: it makes bmesh importable)
    import bmesh
    from mathutils import Matrix, Vector

    import kitlib

    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 4
    sc.cycles.use_adaptive_sampling = True
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.view_settings.view_transform = "AgX" if "AgX" in _view_transforms(bpy) else "Filmic"
    sc.view_settings.exposure = exposure
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.04, 0.05, 0.08, 1) if night else (0.6, 0.64, 0.7, 1)
    bg.inputs[1].default_value = (0.35 if night else 1.0) * world
    if not night:
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 3.0
        sun.data.angle = math.radians(2)
        sun.rotation_euler = (math.radians(40), math.radians(15), math.radians(130))
        sc.collection.objects.link(sun)

    # -- shared unit meshes (Roblox local axes are converted per object)
    def unit(name, fn):
        bm = bmesh.new()
        fn(bm)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(None)  # (one slot, linked per object)
        return me

    cube = unit("cube", lambda bm: bmesh.ops.create_cube(bm, size=1))

    def cyl_fn(bm):  # axis along Blender X (= Roblox X), diameter 1, length 1
        bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.5, radius2=0.5, depth=1,
                              matrix=Matrix.Rotation(math.radians(90), 4, "Y"))

    cyl = unit("cyl", cyl_fn)
    for p in cyl.polygons:
        p.use_smooth = abs(p.normal.x) < 0.5
    ball = unit("ball", lambda bm: bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=0.5))
    for p in ball.polygons:
        p.use_smooth = True

    def wedge_fn(bm):  # built in Roblox local axes (converted by W below)
        vs = [bm.verts.new(v) for v in [(-.5, -.5, -.5), (.5, -.5, -.5), (-.5, -.5, .5), (.5, -.5, .5),
                                        (-.5, .5, .5), (.5, .5, .5)]]
        for f in [(0, 1, 3, 2), (2, 3, 5, 4), (0, 4, 5, 1), (0, 2, 4), (1, 5, 3)]:
            bm.faces.new([vs[i] for i in f])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    wedge = unit("wedge", wedge_fn)
    W = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))

    def rot(rx, ry, rz):
        return (Matrix.Rotation(math.radians(ry), 3, "Y") @ Matrix.Rotation(math.radians(rx), 3, "X")
                @ Matrix.Rotation(math.radians(rz), 3, "Z"))

    def frame(r):
        """The part's CFrame in Blender space (4x4, no scale)."""
        Rb = C @ rot(r[4], r[5], r[6]) @ C.transposed()
        m = Rb.to_4x4()
        m.translation = Vector((r[1], -r[3], r[2]))
        return m

    # -- materials of the primitive parts (like citykit.preview)
    mats = {}
    ROUGH = {"Metal": 0.35, "Glass": 0.05, "SmoothPlastic": 0.5, "Plastic": 0.55, "Neon": 0.5, "DiamondPlate": 0.4}

    def mat(rgb, name, tr):
        key = (tuple(rgb), name, tr)
        if key in mats:
            return mats[key]
        m = bpy.data.materials.new(f"P{len(mats)}")
        m.use_nodes = True
        p = m.node_tree.nodes["Principled BSDF"]
        c = tuple(kitlib.srgb_to_linear(v) for v in rgb) + (1,)
        p.inputs["Base Color"].default_value = c
        p.inputs["Roughness"].default_value = ROUGH.get(name, 0.85)
        if name in ("Metal", "DiamondPlate", "CorrodedMetal"):
            p.inputs["Metallic"].default_value = 0.6
        if name == "Neon":
            p.inputs["Emission Color"].default_value = c
            p.inputs["Emission Strength"].default_value = 5
        if tr > 0:
            p.inputs["Alpha"].default_value = max(0.05, 1 - tr)
        mats[key] = m
        return m

    # -- the kit (kit mode)
    kit = {}
    if mode == "kit":
        kit = load_kit(bpy, Vector)

    all_rows, city, alleys = rows()
    # (index rows per file: parents are 1-based indices into the same file's parts)
    by_file = {"c": city["parts"], "a": alleys["parts"]}

    def piece_of(r, d):
        ex = extra(r, d)
        return (ex or {}).get("a", {}).get("Piece") if d["names"][r[16] - 1] == "MeshProp" else None

    swapped = {}  # (file, index) -> piece, the markers PropKit swaps
    if mode == "kit":
        for key, d in (("c", city), ("a", alleys)):
            for i, r in enumerate(d["parts"]):
                p = piece_of(r, d)
                if p and p in kit:
                    swapped[(key, i + 1)] = p

    def owner(key, r):
        """The swapped marker this part hangs under (its nearest one), else None."""
        parts = by_file[key]
        seen = 0
        while r[17] and seen < 64:
            idx = r[17]
            if (key, idx) in swapped:
                return idx
            r = parts[idx - 1]
            seen += 1
        return None

    # bulbs: per swapped marker, the part that hands over (a LIGHT_TAGS tag first, else a light)
    LIGHT_TAGS = {"CityLamp", "CityBulkhead", "CityFireEmbers", "CityShopLight", "CityNeon", "CityEmergency"}
    bulbs = {}
    under = {}
    for r, d, key in all_rows:
        if key != "a" and not r[17]:
            continue
        o = owner(key, r) if swapped else None
        if o is None:
            continue
        under.setdefault((key, o), []).append(r)
    for mk, parts in under.items():
        tagged = [r for r in parts if set((extra(r, alleys if mk[0] == "a" else city) or {}).get("t", [])) & LIGHT_TAGS]
        lit = [r for r in parts if (extra(r, alleys if mk[0] == "a" else city) or {}).get("l")]
        if tagged or lit:
            bulbs[mk] = (tagged or lit)[0]

    lights = []  # (blender location, light dict, spot?)
    stats = {"parts": 0, "hidden": 0, "markers": 0, "kit_objects": 0}
    for r, d, key in all_rows:
        if not in_region((r[1], r[2], r[3])):
            continue
        ex = extra(r, d)
        o = owner(key, r) if swapped else None
        if o is not None:
            stats["hidden"] += 1
            if ex and ex.get("l"):
                lights.append(("moved", key, o, r, ex["l"]))
            continue
        if ex and ex.get("l"):
            lights.append(("here", key, None, r, ex["l"]))
        if r[12] >= 0.99:
            continue
        shape = r[0]
        sx, sy, sz = r[7], r[8], r[9]
        if shape == 3:
            dia = min(sy, sz)
            me, S = cyl, Matrix.Diagonal((sx, dia, dia, 1))
        elif shape == 4:
            dia = min(sx, sy, sz)
            me, S = ball, Matrix.Diagonal((dia, dia, dia, 1))
        elif shape == 2:
            me, S = wedge, None
        else:
            me, S = cube, None
        if S is None:
            S = Matrix.Diagonal((sx, sz, sy, 1))  # (Blender axes: Roblox Z is Blender -Y)
            m = frame(r) @ S
            if shape == 2:
                m = frame(r) @ (W @ Matrix.Diagonal((sx, sy, sz, 1)))
        else:
            m = frame(r) @ S
        ob = bpy.data.objects.new("p", me)
        ob.matrix_world = m
        sc.collection.objects.link(ob)
        ob.material_slots[0].link = "OBJECT"
        ob.material_slots[0].material = mat(d["colors"][r[10] - 1], d["materials"][r[11] - 1], r[12])
        ob.visible_shadow = bool(r[14] & 4) or (r[12] < 0.2 and sx > 0.3 and sy > 0.3 and sz > 0.3)
        stats["parts"] += 1

    # -- the kit's meshes on the swapped markers
    glow_at = {}
    for (key, i), piece_name in swapped.items():
        d = alleys if key == "a" else city
        r = d["parts"][i - 1]
        if not in_region((r[1], r[2], r[3])):
            continue
        piece = kit[piece_name]
        attrs = extra(r, d)["a"]
        scale = float(attrs.get("Scale") or 1.0)
        tint = tuple(int(v) for v in attrs["Tint"].split(",")) if attrs.get("Tint") else None
        base = frame(r) @ Matrix.Diagonal((scale, scale, scale, 1))
        bulb = bulbs.get((key, i))
        for layer, (mesh, local, centre) in piece["layers"].items():
            ob = bpy.data.objects.new(f"{piece_name}_{layer}", mesh)
            ob.matrix_world = base @ local
            sc.collection.objects.link(ob)
            tintable = kitlib.LAYERS.get(layer, kitlib.LAYERS["Plastic"])[3]
            if layer == "Glow" and piece["points"].get("Light") is not None:
                if bulb is not None:
                    bm_ = mat(d["colors"][bulb[10] - 1], d["materials"][bulb[11] - 1], 0)
                else:
                    bm_ = mat((90, 90, 86), "Glass", 0)  # (UNLIT_GLOW)
            else:
                bm_ = kitlib.preview_material(layer if layer in kitlib.LAYERS else "Plastic",
                                              tint if (tintable and tint) else None)
            ob.material_slots[0].link = "OBJECT"
            ob.material_slots[0].material = bm_
            big = piece["extent"] * scale >= 1.2 and layer not in ("Glow", "Glass")
            ob.visible_shadow = big
            stats["kit_objects"] += 1
            if layer == "Glow":
                glow_at[(key, i)] = base @ centre
        stats["markers"] += 1

    # -- lights (night)
    if night:
        for how, key, o, r, l in lights:
            if how == "here":
                at = Vector((r[1], -r[3], r[2]))
            else:
                d = alleys if key == "a" else city
                mr = d["parts"][o - 1]
                piece = kit[swapped[(key, o)]]
                scale = float(extra(mr, d)["a"].get("Scale") or 1.0)
                base = frame(mr) @ Matrix.Diagonal((scale, scale, scale, 1))
                if bulbs.get((key, o)) is r and (key, o) in glow_at:
                    at = glow_at[(key, o)]
                elif piece["points"].get("Light") is not None:
                    at = base @ piece["points"]["Light"]
                else:
                    at = Vector((r[1], -r[3], r[2]))
            ld = bpy.data.lights.new("l", "POINT" if l["type"] == "Point" else "SPOT")
            ld.color = tuple(v / 255 for v in l["color"])
            ld.energy = l["brightness"] * l["range"] ** 2 * 1.2
            ld.shadow_soft_size = 0.2
            lo = bpy.data.objects.new("l", ld)
            lo.location = at
            if l["type"] == "Spot":
                ld.spot_size = math.radians(l.get("angle", 90))
                lo.location = at - Vector((0, 0, 0.5))
            sc.collection.objects.link(lo)

    # the ground far away
    plane = bpy.data.objects.new("ground", unit("plane", lambda bm: bmesh.ops.create_grid(
        bm, x_segments=1, y_segments=1, size=300)))
    plane.location = (180, -80, -0.01)
    sc.collection.objects.link(plane)
    if ambient > 0:
        add_ambient(bpy, ambient)
    print("built", stats, "lights", len(lights) if night else 0)
    return sc


def add_ambient(bpy, strength):
    """Roblox's Lighting.Ambient / OutdoorAmbient: a flat light every surface gets, whatever
    blocks the sky (the alleys under the viaduct are not black in the game). Emulated as an
    emission of each material's own colour (x its vertex colours) at `strength`."""
    for m in bpy.data.materials:
        if not m.node_tree:
            continue
        p = m.node_tree.nodes.get("Principled BSDF")
        if p is None or p.inputs["Emission Strength"].default_value > 0:
            continue
        src = p.inputs["Base Color"]
        if src.links:
            m.node_tree.links.new(src.links[0].from_socket, p.inputs["Emission Color"])
        else:
            p.inputs["Emission Color"].default_value = src.default_value
        p.inputs["Emission Strength"].default_value = strength


def _view_transforms(bpy):
    try:
        return [i.identifier for i in bpy.types.ColorManagedViewSettings.bl_rna.properties["view_transform"].enum_items]
    except Exception:
        return []


def load_kit(bpy, Vector):
    """{piece: {"layers": {layer: (mesh, local 4x4 from the pivot, bbox centre)}, "points":
    {"Light"/"Fx": Vector}, "extent": float}} from CityProps.fbx, in Blender axes."""
    from mathutils import Matrix

    bpy.ops.import_scene.fbx(filepath=KIT_FBX)
    obs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
    origin, up, out = (obs[n].matrix_world.translation.copy() for n in ("Kit_Origin", "Kit_Up", "Kit_Out"))
    unit = (up - origin).length
    if abs(unit - 1) > 1e-3 or (out - origin - Vector((0, -1, 0))).length > 1e-3:
        raise SystemExit(f"CityProps.fbx imported with an unexpected frame (unit {unit}): fix load_kit")
    kit = {}
    pivots = {}
    for name, ob in obs.items():
        m = re.match(r"^(\w+?)_([A-Za-z]+)$", name)
        if m and m.group(2) == "Pivot":
            pivots[m.group(1)] = ob.matrix_world.translation.copy()
    for name, ob in obs.items():
        m = re.match(r"^(\w+?)_([A-Za-z]+)$", name)
        if not m or m.group(1) == "Kit" or m.group(1) not in pivots:
            continue
        piece, layer = m.groups()
        entry = kit.setdefault(piece, {"layers": {}, "points": {}, "extent": 0.0})
        local = Matrix.Translation(-pivots[piece]) @ ob.matrix_world
        if layer in ("Pivot",):
            continue
        if layer in ("Light", "Fx"):
            entry["points"][layer] = local.translation.copy()
            continue
        vs = [local @ v.co for v in ob.data.vertices]
        lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        centre = (lo + hi) / 2
        entry["layers"][layer] = (ob.data, local, centre)
        entry["extent"] = max(entry["extent"], centre.length + (hi - lo).length / 2)
    for ob in list(bpy.data.objects):  # (the imported objects themselves are not drawn)
        bpy.data.objects.remove(ob)
    for m in list(bpy.data.materials):  # (the FBX's own materials carry the preview names
        bpy.data.materials.remove(m)  # kitlib.preview_material reuses: drop them)
    for piece, entry in kit.items():
        for layer, (mesh, _, _) in entry["layers"].items():
            if mesh.color_attributes and "Col" not in mesh.color_attributes:
                mesh.color_attributes[0].name = "Col"
            mesh.materials.clear()
            mesh.materials.append(None)  # (one slot, linked per object)
    return {k: v for k, v in kit.items() if v["layers"]}


def render(sc, cams, out_dir, tag):
    import bpy
    from mathutils import Vector

    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.clip_start = 0.1
    lowest = {}
    for ob in sc.collection.objects:
        if ob.type == "MESH" and ob.name != "ground":
            lowest[ob] = min((ob.matrix_world @ Vector(c)).z for c in ob.bound_box)
    paths = []
    for name in cams:
        eye, look, fov, *rest = CAMS[name]
        cut = rest[0] if rest else None
        for ob, low in lowest.items():  # (a cutaway: what starts above `cut` is not drawn)
            ob.hide_render = cut is not None and low > cut
        e = Vector((eye[0], -eye[2], eye[1]))
        lk = Vector((look[0], -look[2], look[1]))
        cam.location = e
        cam.rotation_euler = (lk - e).to_track_quat("-Z", "Y").to_euler()
        if fov < 0:  # (a plan: orthographic, -fov studs wide)
            cam.data.type = "ORTHO"
            cam.data.ortho_scale = -fov
        else:
            cam.data.type = "PERSP"
            cam.data.angle = math.radians(fov)
        sc.render.filepath = os.path.join(out_dir, f"{name}_{tag}.png")
        t = time.time()
        bpy.ops.render.render(write_still=True)
        print(f"{name}: {sc.render.filepath} ({time.time() - t:.0f} s)", flush=True)
        paths.append(sc.render.filepath)
    return paths


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--mode", choices=("kit", "fallback"), default="kit")
    ap.add_argument("--time", choices=("day", "night"), default="day")
    ap.add_argument("--cams", default=",".join(CAMS))
    ap.add_argument("--out", default=os.path.join(ROOT, "renders_alleys"))
    ap.add_argument("--samples", type=int, default=16)
    ap.add_argument("--size", default="880x550")
    ap.add_argument("--world", type=float, default=None, help="sky light strength (default 2 by day, 0.6 at night)")
    ap.add_argument("--exposure", type=float, default=None, help="stops (default 1): Roblox's ambient")
    ap.add_argument("--ambient", type=float, default=None, help="flat ambient (default 0.35 by day, 0.03 at night)")
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()
    if a.list:
        for n, c in CAMS.items():
            print(f"{n:18s} eye {c[0]}  look {c[1]}  fov {c[2]}")
        return
    cams = [c for c in a.cams.split(",") if c]
    for c in cams:
        if c not in CAMS:
            raise SystemExit(f"unknown camera {c!r} (--list)")
    os.makedirs(a.out, exist_ok=True)
    size = tuple(int(v) for v in a.size.lower().split("x"))
    night = a.time == "night"
    world = a.world if a.world is not None else (0.6 if night else 2.0)
    exposure = a.exposure if a.exposure is not None else 1.0
    ambient = a.ambient if a.ambient is not None else (0.03 if night else 0.35)
    sc = build(a.mode, night, world, a.samples, size, exposure, ambient)
    render(sc, cams, a.out, f"{a.mode}_{a.time}")


if __name__ == "__main__":
    main()
