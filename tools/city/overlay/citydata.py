"""citydata: reads the city's data exactly like src/server/Systems/City/init.luau does.

    from overlay import citydata
    data = citydata.merged()          # CityData1..N + AlleyData1..N (mergeAlleys)
    # data["parts"]: rows (0-based columns, see COL), data["skip"]: set of 0-based row indices
    # the alleys replace (never built)

Row columns (0-based here, 1-based in Luau): [shape, cx, cy, cz, rx, ry, rz, sx, sy, sz, color,
material, transp, refl, flags, folder, name, parent, extra]. color / material / folder / name /
extra / parent are 1-based indices (0 = none for parent and extra), as in the JSON.
"""

import copy
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
CITY_DIR = os.path.join(ROOT, "src", "server", "Systems", "City")

# 0-based columns
SHAPE, X, Y, Z, RX, RY, RZ, SX, SY, SZ = range(10)
COLOR, MATERIAL, TRANSP, REFL, FLAGS, FOLDER, NAME, PARENT, EXTRA = range(10, 19)
SHAPES = ("Block", "Wedge", "Cylinder", "Ball")
COLLIDE, QUERY, SHADOW = 1, 2, 4
TOL = 0.05


def load(prefix, city_dir=CITY_DIR):
    """The JSON of <prefix>1..N.luau joined (None when there is no piece)."""
    out, i = [], 1
    while os.path.exists(os.path.join(city_dir, f"{prefix}{i}.luau")):
        with open(os.path.join(city_dir, f"{prefix}{i}.luau")) as f:
            m = re.search(r"\[==\[(.*)\]==\]", f.read(), re.S)
        out.append(m.group(1))
        i += 1
    return json.loads("".join(out)) if out else None


def _remap(city_list, other_list, key):
    """mergeAlleys' remap: other index (1-based) -> city index (an equal entry reused, else
    appended). Returns a list where map[i - 1] is the city index of other entry i."""
    known = {}
    for i, v in enumerate(city_list):
        known[key(v)] = i + 1  # (the last equal entry wins, like the Luau loop)
    out = []
    for v in other_list:
        k = key(v)
        if k not in known:
            city_list.append(copy.deepcopy(v))
            known[k] = len(city_list)
        out.append(known[k])
    return out


def rgb_key(v):
    return f"{v[0]},{v[1]},{v[2]}"


def text_key(v):
    return v


def remap_tables(data, other):
    """(colors, materials, folders, names) maps of `other` onto `data` (data's lists grow)."""
    return (_remap(data["colors"], other["colors"], rgb_key),
            _remap(data["materials"], other["materials"], text_key),
            _remap(data["folders"], other["folders"], text_key),
            _remap(data["names"], other["names"], text_key))


def same_place(row, at, tol=TOL):
    return all(abs(row[X + i] - at[i]) < tol for i in range(3))


def merge_alleys(data, alleys):
    """init.luau mergeAlleys, in place."""
    skip = set()
    for rem in alleys["remove"]:
        for i, r in enumerate(data["parts"]):
            if (data["folders"][r[FOLDER] - 1] == rem["folder"] and data["names"][r[NAME] - 1] == rem["name"]
                    and same_place(r, rem["at"])):
                skip.add(i)
    colors, materials, folders, names = remap_tables(data, alleys)
    part_off, extra_off = len(data["parts"]), len(data["extras"])
    data["extras"].extend(copy.deepcopy(alleys["extras"]))
    for r in alleys["parts"]:
        c = list(r)
        c[COLOR] = colors[r[COLOR] - 1]
        c[MATERIAL] = materials[r[MATERIAL] - 1]
        c[FOLDER] = folders[r[FOLDER] - 1]
        c[NAME] = names[r[NAME] - 1]
        if r[PARENT] > 0:
            c[PARENT] = r[PARENT] + part_off
        if r[EXTRA] > 0:
            c[EXTRA] = r[EXTRA] + extra_off
        data["parts"].append(c)
    data["skip"] = skip
    data["alley_start"] = part_off  # (0-based index of the first alley row)
    return data


def merged(city_dir=CITY_DIR):
    """CityData + AlleyData merged like init.luau (before the overlay)."""
    data = load("CityData", city_dir)
    data.setdefault("skip", set())
    data["alley_start"] = len(data["parts"])
    alleys = load("AlleyData", city_dir)
    if alleys:
        merge_alleys(data, alleys)
    return data


def extra_of(data, row):
    return data["extras"][row[EXTRA] - 1] if row[EXTRA] else None


def folder_of(data, row):
    return data["folders"][row[FOLDER] - 1]


def name_of(data, row):
    return data["names"][row[NAME] - 1]
