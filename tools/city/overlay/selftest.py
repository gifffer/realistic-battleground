"""selftest: exercises every CityOverlay op on the current city, in memory (nothing is written).

    venv/bin/python -I tools/city/overlay/selftest.py

Checks: set / remove / add (+ sign plate) / reparent / wrap / sign / box resolve and apply;
refusals (removing a colliding or tagged part, wrapping a door) are reported; an entry whose
match is gone (the city regenerated) is skipped whole at runtime and the rest still applies.
"""

import copy
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

from overlay import apply as A  # noqa: E402
from overlay import citydata as C  # noqa: E402
from overlay.core import Overlay  # noqa: E402


def main():
    data = C.merged()
    O = Overlay(data)
    O.module = "selftest"
    lid = O.match("Props/Street", "Lid", (-87.7, 4.35, 25))
    O.set(lid, color=(40, 42, 40), material="Metal", reflectance=0.02)
    O.remove(O.match("Props/Street", "PhoneHandset", (-68.89, 6.4, -70.225)))
    n_err = len(O.errors)
    O.remove(O.match("Props/Street", "Bin", (-87.7, 2.75, 25)))  # (collides: refused)
    assert len(O.errors) == n_err + 1 and "refused" in O.errors[-1], O.errors[-1:]
    O.errors.pop()
    bags = O.box("Props/Street", "TrashBag", lo=(-102, 0, -87), hi=(-99, 4, -83))
    assert len(bags) == 6, len(bags)
    marker = O.wrap(bags, "TrashBag1", origin=(-100.6, 1.2, -84.8), ry=30, tint=(30, 30, 32))
    assert marker is not None
    booth = O.match("Props/Street", "PhoneSign", (-69.5, 9.3, -67.46))
    plate = O.sign(booth, text="PHONE", face="Front", font="Arimo", color=[230, 230, 220], pps="auto",
                   pad=[0.05, 0.15], maxSize=60, plate=dict(pos=(-69.5, 9.3, -67.40), size=(2.6, 0.45, 0.02),
                                                            color=(20, 20, 20)))
    assert plate is not None
    with O.entry("street_sign"):
        pole = O.add("Props/Street", "SignPost", (0, 6, 0), (0.3, 10, 0.3), (40, 40, 40), "Metal")
        O.add("Props/Street", "StreetSign", (0, 10, 0), (3.2, 0.7, 0.08), (30, 60, 45), "Metal", under=pole,
              sign=dict(text="DELMAR ST", font="Arimo", color=[235, 235, 225], face="Front", lit=False,
                        pad=[0.04, 0.12], pps=40))
    O.match("Props/Street", "Nope", (0, 0, 0))
    assert "no row" in O.errors[-1]
    O.errors.pop()
    O.match("Ring/E3", "E3", (139, 24.2, 27))
    assert "removed by the alleys" in O.errors[-1], O.errors[-1]
    O.errors.pop()
    doors = [i for i, r in enumerate(data["parts"]) if "CityDoor" in ((C.extra_of(data, r) or {}).get("t") or [])]
    r = data["parts"][doors[0]]
    O.wrap(O.match(C.folder_of(data, r), C.name_of(data, r), r[1:4]), "Dumpster", origin=r[1:4])
    assert "refused" in O.errors[-1], O.errors[-1]
    O.errors.pop()
    assert not O.errors, O.errors
    ov = json.loads(json.dumps(O.json()))

    fresh = C.merged()
    stats = A.apply(fresh, copy.deepcopy(ov))
    assert stats["skipped"] == 0, stats
    print("applied", stats)
    # the trash bags hang under the marker, the handset is gone, the lid recoloured
    mk = [i for i, r in enumerate(fresh["parts"]) if C.name_of(fresh, r) == "MeshProp"
          and (C.extra_of(fresh, r) or {}).get("a", {}).get("Piece") == "TrashBag1"
          and abs(r[1] + 100.6) < 0.01]
    assert len(mk) == 1
    under = [i for i, r in enumerate(fresh["parts"]) if r[17] == mk[0] + 1]
    assert len(under) == 6, under
    gone = [i for i in fresh["skip"] if C.name_of(fresh, fresh["parts"][i]) == "PhoneHandset"]
    assert len(gone) == 1
    old = [i for i, r in enumerate(fresh["parts"]) if C.name_of(fresh, r) == "PhoneSign"][0]
    assert "g" not in (C.extra_of(fresh, fresh["parts"][old]) or {})
    sp = [r for r in fresh["parts"] if C.name_of(fresh, r) == "SignPlate"][0]
    g = C.extra_of(fresh, sp)["g"]
    assert g["text"] == "PHONE" and 10 <= g["pps"] <= 200, g
    print("sign plate", g)

    # the city changed: the lid moved -> its entry is skipped, the rest applies
    changed = C.merged()
    for r in changed["parts"]:
        if C.name_of(changed, r) == "Lid" and abs(r[1] + 87.7) < 0.01 and abs(r[3] - 25) < 0.01:
            r[1] += 1.0
    stats = A.apply(changed, copy.deepcopy(ov))
    assert stats["skipped"] == 1 and stats["applied"] == len(ov["entries"]) - 1, stats
    print("city changed:", stats["applied"], "applied,", stats["skipped"], "skipped:", stats["missed"])
    if "--luau" in sys.argv:
        luau_parity(ov)
    print("selftest OK")


def strip(v):
    """JSON as Lua sees it: null fields vanish, empty tables are [] (not {})."""
    if isinstance(v, dict):
        out = {k: strip(x) for k, x in v.items() if x is not None}
        return out if out else []
    if isinstance(v, list):
        return [strip(x) for x in v]
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        return round(float(v), 6) + 0.0
    return v


def luau_parity(ov):
    """The game's own code (init.luau's applyOverlay, run under Lune) must give the same rows,
    extras and skipped rows as apply.py."""
    import subprocess
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        ov_path, out_path = os.path.join(tmp, "ov.json"), os.path.join(tmp, "out.json")
        with open(ov_path, "w") as f:
            json.dump(ov, f)
        root = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
        subprocess.run(["lune", "run", os.path.join(HERE, "runtime_sim.luau"), C.CITY_DIR, ov_path, out_path],
                       check=True, cwd=root)
        with open(out_path) as f:
            lua = json.load(f)
    py = C.merged()
    A.apply(py, copy.deepcopy(ov))
    assert sorted(py["skip"]) == lua["skip"], "skipped rows differ"
    assert len(py["parts"]) == len(lua["parts"]), (len(py["parts"]), len(lua["parts"]))
    for i, (a, b) in enumerate(zip(py["parts"], lua["parts"])):
        assert strip(a) == strip(b), (i, a, b)
    for i, r in enumerate(py["parts"]):
        if r[18]:
            ea, eb = strip(py["extras"][r[18] - 1]), strip(lua["extras"][r[18] - 1])
            assert ea == eb, (i, ea, eb)
    print("luau parity OK:", len(py["parts"]), "rows,", len(py["skip"]), "skipped")


if __name__ == "__main__":
    main()
