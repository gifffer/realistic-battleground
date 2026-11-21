"""apply: the CityOverlay applied to the merged city data, EXACTLY like init.luau applyOverlay
(keep both in step). Used by build_overlay.py (validation) and render_city.py (previews).

    from overlay import apply, citydata
    data = citydata.merged()
    stats = apply.apply(data, citydata.load("CityOverlay"))   # {"applied", "skipped", "ops", "missed": [...]}

Overlay JSON (written by build_overlay.py):
  colors, materials, folders, names, extras: its own palette (remapped like mergeAlleys)
  parts:   new rows; their PARENT (> 0) is an index into these parts, their EXTRA into extras
  entries: [{"id": str, "ops": [op...]}]; an entry applies only when ALL its matches are found
           (exactly one row each, not removed by the alleys or an earlier entry), else it is
           skipped as a whole (the original city stays).
  match M: {"f": folder, "n": name, "at": [x, y, z]} (ORIGINAL position, tolerance 0.05), plus
           its guards (core.Match): "sz" [3] original size (tolerance 0.05), "r" [3] original
           rotation (0.5 deg), "tx" its sign's original text: a row that differs is no match
  ops:
    {"op": "set", "m": M, ...}   fields: color, material (overlay palette indices), tr, refl,
         flags, shape, pos [3], rot [3], size [3], extra (overlay extra index: replaces the
         row's extra; 0 = none), xp (overlay extra index: PATCH, see patch_extra)
    {"op": "remove", "m": M}
    {"op": "add", "p": k, "under": M?}   adds overlay part k (1-based); `under`: parent it to M
    {"op": "parent", "m": M, "p": k}     puts M under overlay part k (added in this entry)
    {"op": "parent", "m": M, "to": M2}   puts M under the city row M2
"""

import copy

from overlay.citydata import (COLOR, EXTRA, FLAGS, FOLDER, MATERIAL, NAME, PARENT, REFL, RX, SHAPE, SX,
                              TOL, TRANSP, X, remap_tables)


def patch_extra(base, patch):
    """A new extra: `base` (or {}) with `patch` on top. For the tables "g" (sign), "l" (light),
    "a" (attributes) the patch's keys merge into the existing table; any other key is replaced.
    The patch's key "-" lists what to delete first: "g" (the whole sign), "g.pad" (one field)."""
    out = copy.deepcopy(base) if base else {}
    for path in patch.get("-", ()):
        head, dot, field = path.partition(".")
        if not dot:
            out.pop(head, None)
        elif head and field and isinstance(out.get(head), dict):  # (like the Luau "^([^.]+)%.(.+)$")
            out[head].pop(field, None)
    for k, v in patch.items():
        if k == "-":
            continue
        if k in ("g", "l", "a") and isinstance(v, dict) and isinstance(out.get(k), dict):
            for k2, v2 in v.items():
                out[k][k2] = copy.deepcopy(v2)
        else:
            out[k] = copy.deepcopy(v)
    return out


ROT_TOL = 0.5


def sign_text(data, r):
    ex = data["extras"][r[EXTRA] - 1] if r[EXTRA] else None
    g = ex.get("g") if isinstance(ex, dict) else None
    return g.get("text") if isinstance(g, dict) else None


class Index:
    """folder|name -> [(row index, original position, size, rotation, sign text)] of the rows that
    are built (ORIGINAL values: an earlier entry may move or resize a row, later entries still
    know it as the generator made it)."""

    def __init__(self, data):
        self.data = data
        self.by_key = {}
        skip = data.get("skip", set())
        for i, r in enumerate(data["parts"]):
            if i in skip:
                continue
            k = data["folders"][r[FOLDER] - 1] + "|" + data["names"][r[NAME] - 1]
            self.by_key.setdefault(k, []).append((i, tuple(r[X:X + 3]), tuple(r[SX:SX + 3]), tuple(r[RX:RX + 3]),
                                                  sign_text(data, r)))

    def find(self, m, gone=()):
        """[row indices] matching M (all hits: the caller wants exactly one)."""
        out = []
        for i, at, size, rot, text in self.by_key.get(m["f"] + "|" + m["n"], ()):
            if i in gone:
                continue
            if not all(abs(at[k] - m["at"][k]) < TOL for k in range(3)):
                continue
            if "sz" in m and not all(abs(size[k] - m["sz"][k]) < TOL for k in range(3)):
                continue
            if "r" in m and not all(abs(rot[k] - m["r"][k]) < ROT_TOL for k in range(3)):
                continue
            if "tx" in m and text != m["tx"]:
                continue
            out.append(i)
        return out


def matches_of(op):
    out = []
    for key in ("m", "under", "to"):
        if isinstance(op.get(key), dict):
            out.append(op[key])
    return out


def apply(data, ov, report=None):
    """Applies overlay `ov` to `data` in place. Returns {"applied": entries, "skipped": entries,
    "ops": ops applied, "missed": [(entry id, M, hits)]}. `report`: a list that gets one line per
    skipped entry."""
    stats = {"applied": 0, "skipped": 0, "ops": 0, "missed": []}
    if not ov or not ov.get("entries"):
        return stats
    colors, materials, folders, names = remap_tables(data, ov)
    index = Index(data)
    gone = set(data.get("skip", set()))
    for entry in ov["entries"]:
        resolved = {}
        ok = True
        for op in entry["ops"]:
            for m in matches_of(op):
                hits = index.find(m, gone)
                if len(hits) != 1:
                    ok = False
                    stats["missed"].append((entry["id"], m, len(hits)))
                    break
                resolved[id(m)] = hits[0]
            if not ok:
                break
        if not ok:
            stats["skipped"] += 1
            if report is not None:
                report.append(f"skipped {entry['id']}")
            continue
        added = {}  # overlay part index (1-based) -> data row index (0-based)
        for op in entry["ops"]:
            kind = op["op"]
            if kind == "set":
                row = data["parts"][resolved[id(op["m"])]]
                if "color" in op:
                    row[COLOR] = colors[op["color"] - 1]
                if "material" in op:
                    row[MATERIAL] = materials[op["material"] - 1]
                if "tr" in op:
                    row[TRANSP] = op["tr"]
                if "refl" in op:
                    row[REFL] = op["refl"]
                if "flags" in op:
                    row[FLAGS] = op["flags"]
                if "shape" in op:
                    row[SHAPE] = op["shape"]
                for key, col in (("pos", X), ("rot", RX), ("size", SX)):
                    if key in op:
                        row[col:col + 3] = list(op[key])
                if "extra" in op:
                    if op["extra"] > 0:
                        data["extras"].append(copy.deepcopy(ov["extras"][op["extra"] - 1]))
                        row[EXTRA] = len(data["extras"])
                    else:
                        row[EXTRA] = 0
                if "xp" in op:
                    base = data["extras"][row[EXTRA] - 1] if row[EXTRA] else None
                    data["extras"].append(patch_extra(base, ov["extras"][op["xp"] - 1]))
                    row[EXTRA] = len(data["extras"])
            elif kind == "remove":
                i = resolved[id(op["m"])]
                gone.add(i)
                data["skip"].add(i)
            elif kind == "add":
                src = ov["parts"][op["p"] - 1]
                row = list(src)
                row[COLOR] = colors[src[COLOR] - 1]
                row[MATERIAL] = materials[src[MATERIAL] - 1]
                row[FOLDER] = folders[src[FOLDER] - 1]
                row[NAME] = names[src[NAME] - 1]
                if src[EXTRA] > 0:
                    data["extras"].append(copy.deepcopy(ov["extras"][src[EXTRA] - 1]))
                    row[EXTRA] = len(data["extras"])
                if "under" in op:
                    row[PARENT] = resolved[id(op["under"])] + 1
                elif src[PARENT] > 0:
                    row[PARENT] = added[src[PARENT]] + 1
                else:
                    row[PARENT] = 0
                data["parts"].append(row)
                added[op["p"]] = len(data["parts"]) - 1
            elif kind == "parent":
                row = data["parts"][resolved[id(op["m"])]]
                if "p" in op:
                    row[PARENT] = added[op["p"]] + 1
                else:
                    row[PARENT] = resolved[id(op["to"])] + 1
            stats["ops"] += 1
        stats["applied"] += 1
    return stats
