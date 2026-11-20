"""
Takes the organs of the chest and the belly out of Z-Anatomy
(https://www.z-anatomy.com, CC BY-SA 4.0) for the autopsy video pieces
(gore.py "Aut*": the R6 torso opened from the front, each organ its own
piece so it can be pulled out).

    venv/bin/python -I tools/wounds/extract_autopsy.py <Z-Anatomy/Startup.blend>

Writes tools/wounds/anatomy/autopsy.npz: one decimated mesh per group, in
the R6 torso's space (studs: X right of the character, Y up, Z toward the
back, its front face at Z = -0.5). Flatter than torso.npz's mapping so that
everything sits behind the skin, fat and muscle the game draws over the
front (Z >= -0.40) and inside the torso's top and bottom (|Y| <= 0.97).
Only needed again to change what is taken; gore.py reads the .npz.
"""

import re
import sys

import bpy  # noqa: I001 (first: it makes the other Blender modules importable)
import numpy as np
from mathutils import Vector

BLEND = sys.argv[-1]
OUT = "tools/wounds/anatomy/autopsy.npz"

# name -> (pattern on Z-Anatomy object names, triangles for all of them)
GROUPS = {
    "ventricles": (r"^(Right|Left) ventricle$", 1800),
    "atria": (r"^(Right|Left) atrium$", 1100),
    "heartvessels": (r"^(Ascending aorta|Pulmonary trunk|Superior vena cava)$", 500),
    "lungr": (r"^(Superior|Middle|Inferior) lobe of right lung$", 1800),
    "lungl": (r"^(Superior|Inferior) lobe of left lung$", 1800),
    "bronchusr": (r"^Right main bronchus$", 120),
    "bronchusl": (r"^Left main bronchus$", 160),
    "liver": (r"^Liver$", 1800),
    "gallbladder": (r"^Gallbladder$", 250),
    "stomach": (r"^Stomach$", 1200),
    "spleen": (r"^Spleen$", 600),
    "pancreas": (r"^Pancreas$", 700),
    "duodenum": (r"^Duodenum$", 500),
    "kidneyr": (r"^Kidney\.r$", 700),
    "kidneyl": (r"^Kidney\.l$", 700),
    "renalr": (r"^Right renal (artery|vein)$", 200),
    "renall": (r"^Left renal (artery|vein)$", 200),
    "jejunum": (r"^Jejunum$", 3200),
    "colon": (r"^(Ascending|Transverse|Descending) colon$", 1400),
    "omentum": (r"^Greater omentum$", 1500),
    "sternum": (r"^(Body|Manubrium) of sternum$", 900),
    "cartilage": (r"^Costal cartilage of (first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth) rib\.[lr]$",
                  1400),
    "ribs": (r"^(First|Second|Third|Fourth|Fifth|Sixth|Seventh|Eighth|Ninth|Tenth|Eleventh|Twelfth) rib\.[lr]$", 6000),
    "spine": (r"^Vertebra (T\d+|L[1-5])$", 3000),
    "discs": (r"^Intervertebral disc (T\d+-T\d+|T12-L1|L[1-4]-L[2-5])$", 600),
    "psoas": (r"^(Psoas major|Quadratus lumborum muscle)\.[lr]$", 900),
    "aorta": (r"^(Thoracic|Abdominal) aorta$", 400),
    "cava": (r"^Inferior vena cava \((abdominal|thoracic) part\)$", 250),
    "trachea": (r"^Trachea$", 400),
    "oesophagus": (r"^Oesophagus$", 400),
    "diaphragm": (r"^Diaphragm$", 1200),
}

# The real body (metres, Z up, -Y = the front) -> the R6 torso (studs).
CENTER = Vector((0.0, -0.014, 1.17))  # (the sternum's front lands at Z = -0.40)
SCALE = Vector((5.9, 3.5, 3.4))  # across, up, front-back
TOP, BOTTOM, FRONT = 0.97, -0.97, -0.40  # soft limits (Y up and down, Z front)


def soft(t, knee, limit):
    """t past `knee` eased toward `limit`, never past it."""
    span = limit - knee
    return np.where(t * np.sign(span) <= knee * np.sign(span), t, knee + span * np.tanh((t - knee) / span))


def to_torso(points):
    d = points - np.array(CENTER, dtype=np.float64)
    # anatomical right (x < 0) -> the character's right (+X); up -> Y; front (-y) -> -Z
    out = np.stack((-d[:, 0] * SCALE.x, d[:, 2] * SCALE.y, d[:, 1] * SCALE.z), axis=1)
    out[:, 1] = soft(soft(out[:, 1], 0.88, TOP), -0.88, BOTTOM)
    out[:, 2] = soft(out[:, 2], -0.35, FRONT)
    return out.astype(np.float32)


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    arrays = {}
    for group, (pattern, budget) in GROUPS.items():
        rx = re.compile(pattern)
        found = []
        for ob in bpy.data.objects:
            # (curves too: the jejunum, the aorta, the bronchi - their mesh)
            if ob.type not in ("MESH", "CURVE") or not rx.search(ob.name):
                continue
            evaluated = ob.evaluated_get(depsgraph)
            mesh = evaluated.to_mesh().copy()
            evaluated.to_mesh_clear()
            mesh.transform(ob.matrix_world)
            if len(mesh.polygons):
                found.append((ob.name, mesh))
            else:
                bpy.data.meshes.remove(mesh)
        if not found:
            raise SystemExit(f"nothing found for {group} ({pattern})")
        for _n, mesh in found:
            mesh.calc_loop_triangles()
        total = sum(len(m.loop_triangles) for _n, m in found) or 1
        vs, fs, base = [], [], 0
        for _name, mesh in found:
            temp = bpy.data.objects.new("tmp", mesh)
            bpy.context.scene.collection.objects.link(temp)
            temp.modifiers.new("t", "TRIANGULATE")
            dec = temp.modifiers.new("d", "DECIMATE")
            dec.ratio = min(1.0, budget / total)
            done = temp.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
            done.calc_loop_triangles()
            v = np.array([tuple(vx.co) for vx in done.vertices], dtype=np.float64)
            f = np.array([tuple(t.vertices) for t in done.loop_triangles], dtype=np.int32)
            bpy.data.objects.remove(temp)
            if len(f):
                vs.append(to_torso(v))
                fs.append(f + base)
                base += len(v)
        arrays[f"{group}__0__v"] = np.vstack(vs)
        arrays[f"{group}__0__f"] = np.vstack(fs)
        print(group, [n for n, _m in found], base, "verts", sum(len(f) for f in fs), "tris")
    np.savez_compressed(OUT, **arrays)
    print("wrote", OUT)


main()
