"""core: the CityOverlay builder. Edit modules (tools/city/overlay/edits/*.py) get an Overlay `O`
and declare operations on the CURRENT city (CityData + AlleyData, merged like init.luau):

    def edits(O):
        lamp = O.match("Props/Lamps", "LampHead", (41, 17.2, -60))           # exact (tolerance 0.05)
        pole = O.near("Props/Lamps", "Pole", (41, 9, -60), radius=0.5)      # the one row near there
        O.set(lamp, color=(60, 60, 58), material="Metal")
        with O.entry("lamp_41"):                     # several ops that apply together or not at all
            O.wrap([pole, lamp], "StreetLampColumn", origin=(41, 1.2, -60), ry=90)
        O.remove(O.match("Props/Street", "Litter", (10, 1.3, 5)))
        plate = O.add("Props/Street", "SignPlate", pos=(...), size=(3.2, 0.7, 0.08), color=(30, 60, 45),
                      material="Metal", sign=dict(text="DELMAR ST", font="Arimo", face="Front", ...))
        O.sign(host, text="KITCHEN\\nNO ENTRY", pos=(...), size=(2.6, 1.0, 0.02), pps=100, pad=(0.06, 0.08))
        for m in O.box("Props/Street", {"Ball"}, lo=(-10, 0, -10), hi=(10, 5, 10)):
            O.set(m, color=(20, 20, 22))

Every match must hit exactly ONE built row (not a row the alleys removed): misses and ambiguous
matches are errors at build time. See build_overlay.py for the output and apply.py for the
runtime semantics (an entry whose matches are missing at runtime is skipped whole).
"""

import contextlib
import math

from overlay.citydata import (COLLIDE, EXTRA, FLAGS, FOLDER, NAME, PARENT, QUERY, RX, SHAPES, SX, TOL, X,
                              extra_of, folder_of, name_of)

DECOR = 0
# Tags whose parts other systems move, find by name or count on: never removed / wrapped unless forced.
PROTECTED_TAGS = {"CityDoor", "ShopCounter", "Speaker", "TrainSignal", "TrainSignalGo", "WeaponSpawn",
                  "MusicZone", "ParkZone", "AlleyZone", "CityWindowLit", "CityPuddle"}
# Folders whose Model children are looked up by name (Body, Button, Torso...): no wrap inside.
PROTECTED_FOLDERS = ("SpezColaMachine_", "Mannequin_")
# SurfaceGui faces: (local normal, local right = gui +x, local up = gui -y, width axis, height axis)
FACES = {"Front": ((0, 0, -1), (-1, 0, 0), (0, 1, 0), 0, 1), "Back": ((0, 0, 1), (1, 0, 0), (0, 1, 0), 0, 1),
         "Right": ((1, 0, 0), (0, 0, -1), (0, 1, 0), 2, 1), "Left": ((-1, 0, 0), (0, 0, 1), (0, 1, 0), 2, 1),
         "Top": ((0, 1, 0), (1, 0, 0), (0, 0, -1), 0, 2), "Bottom": ((0, -1, 0), (1, 0, 0), (0, 0, 1), 0, 2)}
# The optional sign fields (City/init.luau addSign) on top of text/font/color/face/lit/bg/bg_tr.
SIGN_FIELDS = {"text", "font", "color", "face", "lit", "bg", "bg_tr", "rot", "align",
               "pad", "maxSize", "minSize", "xalign", "yalign", "pps", "stroke", "light", "textTr",
               "rich", "maxDist", "bright"}


class OverlayError(Exception):
    pass


class Match:
    """A city row by folder + name + ORIGINAL position (resolved against the merged data)."""

    def __init__(self, folder, name, at, row=None):
        self.folder, self.name, self.at, self.row = folder, name, tuple(float(v) for v in at), row

    def json(self):
        return {"f": self.folder, "n": self.name, "at": [round(v, 4) for v in self.at]}

    def __repr__(self):
        return f"{self.folder}/{self.name}@({self.at[0]:g}, {self.at[1]:g}, {self.at[2]:g})"


class PartRef:
    """A part added by the overlay (index into the overlay's parts, 1-based)."""

    def __init__(self, index, entry):
        self.index, self.entry = index, entry


def auto_pps(face_h, pad_y=0.0, lines=1):
    """S0 rule: PixelsPerStud so the 100 px TextScaled cap is one line's height (sharp small
    text): clamp(round(100 / lineHeight), 10, 200)."""
    lh = max(1e-3, face_h * (1 - 2 * pad_y) / max(1, lines))
    return int(max(10, min(200, round(100 / lh))))


def rotm(rx, ry, rz):
    """Roblox CFrame.fromEulerAnglesYXZ (degrees) as a 3x3 list (R = Ry Rx Rz)."""
    a, b, c = (math.radians(v) for v in (rx, ry, rz))
    Rx = ((1, 0, 0), (0, math.cos(a), -math.sin(a)), (0, math.sin(a), math.cos(a)))
    Ry = ((math.cos(b), 0, math.sin(b)), (0, 1, 0), (-math.sin(b), 0, math.cos(b)))
    Rz = ((math.cos(c), -math.sin(c), 0), (math.sin(c), math.cos(c), 0), (0, 0, 1))

    def mul(A, B):
        return tuple(tuple(sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)) for i in range(3))

    return mul(mul(Ry, Rx), Rz)


class Overlay:
    def __init__(self, data):
        self.data = data
        self.skip = set(data.get("skip", set()))
        self.by_key = {}
        for i, r in enumerate(data["parts"]):
            self.by_key.setdefault(folder_of(data, r) + "|" + name_of(data, r), []).append(i)
        self.children = {}
        for i, r in enumerate(data["parts"]):
            if r[PARENT] > 0 and i not in self.skip:
                self.children.setdefault(r[PARENT] - 1, []).append(i)
        self.colors, self.materials, self.folders, self.names = [], [], [], []
        self.extras, self.parts, self.entries = [], [], []
        self.errors, self.warnings = [], []
        self.module = "overlay"
        self._entry = None
        self._auto = 0
        self.removed = set()
        self.counts = {}

    # ------------------------------------------------------------------ errors
    def error(self, msg):
        self.errors.append(f"[{self.module}] {msg}")

    def warn(self, msg):
        self.warnings.append(f"[{self.module}] {msg}")

    # ------------------------------------------------------------------ finding rows
    def _hits(self, folder, name, at, tol=TOL):
        out = []
        for i in self.by_key.get(folder + "|" + name, ()):
            r = self.data["parts"][i]
            if all(abs(r[X + k] - at[k]) < tol for k in range(3)):
                out.append(i)
        return out

    def match(self, folder, name, at):
        """The one built row folder/name at `at` (tolerance 0.05). Errors are recorded (the build
        fails), a Match with row None is returned so the edit module can go on."""
        hits = self._hits(folder, name, at)
        built = [i for i in hits if i not in self.skip]
        if len(built) == 1:
            r = self.data["parts"][built[0]]
            return Match(folder, name, (r[X], r[X + 1], r[X + 2]), built[0])
        if not built and hits:
            self.error(f"match {folder}/{name} at {tuple(at)}: that row was removed by the alleys")
        elif not built:
            near = self._nearest(folder, name, at)
            self.error(f"match {folder}/{name} at {tuple(at)}: no row" + (f" (nearest: {near})" if near else ""))
        else:
            self.error(f"match {folder}/{name} at {tuple(at)}: ambiguous, {len(built)} rows")
        return Match(folder, name, at, None)

    def _nearest(self, folder, name, at):
        best = None
        for i in self.by_key.get(folder + "|" + name, ()):
            r = self.data["parts"][i]
            d = math.dist(at, r[X:X + 3])
            if best is None or d < best[0]:
                best = (d, r[X:X + 3])
        return None if best is None else f"{best[1]} at {best[0]:.2f} studs"

    def near(self, folder, name, at, radius=0.5):
        """Like match(), for a position known only roughly (an audit's rounded numbers): the one
        built row within `radius` studs; the Match carries its exact position."""
        hits = [i for i in self.by_key.get(folder + "|" + name, ())
                if i not in self.skip and math.dist(at, self.data["parts"][i][X:X + 3]) <= radius]
        if len(hits) != 1:
            self.error(f"near {folder}/{name} at {tuple(at)} r {radius}: {len(hits)} rows")
            return Match(folder, name, at, None)
        r = self.data["parts"][hits[0]]
        return Match(folder, name, (r[X], r[X + 1], r[X + 2]), hits[0])

    def box(self, folder, names=None, lo=(-1e9, -1e9, -1e9), hi=(1e9, 1e9, 1e9), prefix=False):
        """Every built row of `folder` (or under it, prefix=True) whose name is in `names` (a str or
        a set; None = any) with its centre inside the box lo..hi. Each must be unique by
        folder+name+position (else an error)."""
        if isinstance(names, str):
            names = {names}
        out = []
        for i, r in enumerate(self.data["parts"]):
            if i in self.skip:
                continue
            f = folder_of(self.data, r)
            if not (f == folder or (prefix and f.startswith(folder + "/"))):
                continue
            n = name_of(self.data, r)
            if names is not None and n not in names:
                continue
            if all(lo[k] <= r[X + k] <= hi[k] for k in range(3)):
                if len([j for j in self._hits(f, n, r[X:X + 3]) if j not in self.skip]) != 1:
                    self.error(f"box: {f}/{n} at {r[X:X + 3]} is not unique by position")
                    continue
                out.append(Match(f, n, (r[X], r[X + 1], r[X + 2]), i))
        if not out:
            self.warn(f"box {folder} {sorted(names) if names else '*'} {lo}..{hi}: empty")
        return out

    def row(self, m):
        """The current row of a Match (list, 0-based columns) or None."""
        return None if m.row is None else self.data["parts"][m.row]

    def extra(self, m):
        r = self.row(m)
        return None if r is None else extra_of(self.data, r)

    # ------------------------------------------------------------------ palette
    def _index(self, lst, value):
        if value in lst:
            return lst.index(value) + 1
        lst.append(value)
        return len(lst)

    def _color(self, rgb):
        return self._index(self.colors, [int(round(c)) for c in rgb])

    def _material(self, name):
        return self._index(self.materials, name)

    def _extra(self, ex):
        self.extras.append(ex)
        return len(self.extras)

    # ------------------------------------------------------------------ entries
    @contextlib.contextmanager
    def entry(self, name):
        """Groups the ops inside into ONE entry: at runtime it applies whole or not at all."""
        if self._entry is not None:
            yield self._entry
            return
        self._entry = {"id": f"{self.module}:{name}", "ops": []}
        try:
            yield self._entry
        finally:
            if self._entry["ops"]:
                self.entries.append(self._entry)
            self._entry = None

    def _op(self, op):
        if self._entry is not None:
            self._entry["ops"].append(op)
            return self._entry
        self._auto += 1
        e = {"id": f"{self.module}:{self._auto}", "ops": [op]}
        self.entries.append(e)
        return e

    def _count(self, kind):
        self.counts[kind] = self.counts.get(kind, 0) + 1

    def _check(self, m, what):
        if not isinstance(m, Match):
            raise OverlayError(f"{what}: expected a Match, got {m!r}")
        if m.row is None:
            return False  # (already reported)
        if m.row in self.removed:
            self.error(f"{what} {m}: removed earlier by the overlay")
            return False
        return True

    # ------------------------------------------------------------------ ops
    def set(self, m, *, color=None, material=None, transparency=None, reflectance=None, flags=None,
            shape=None, pos=None, rot=None, size=None, extra=None, extra_patch=None, sign=None,
            attrs=None, tags=None):
        """Changes columns of the matched row. extra: a whole new extra dict (or {} for none);
        extra_patch: merged (see apply.patch_extra; its key "-" lists paths to delete, e.g.
        ["g.pad"]); sign: fields merged into its "g" (a sign that did not exist needs text,
        face...), or False to take the sign off; attrs: merged into "a"; tags: replace "t"."""
        if isinstance(m, (list, tuple)):
            for one in m:
                self.set(one, color=color, material=material, transparency=transparency,
                         reflectance=reflectance, flags=flags, shape=shape, pos=pos, rot=rot, size=size,
                         extra=extra, extra_patch=extra_patch, sign=sign, attrs=attrs, tags=tags)
            return
        if not self._check(m, "set"):
            return
        op = {"op": "set", "m": m.json()}
        if color is not None:
            op["color"] = self._color(color)
        if material is not None:
            op["material"] = self._material(material)
        if transparency is not None:
            op["tr"] = transparency
        if reflectance is not None:
            op["refl"] = reflectance
        if flags is not None:
            r = self.row(m)
            if (r[FLAGS] & (COLLIDE | QUERY)) and not (flags & (COLLIDE | QUERY)):
                self.warn(f"set {m}: drops its collision / query flags")
            op["flags"] = flags
        if shape is not None:
            op["shape"] = SHAPES.index(shape) + 1 if isinstance(shape, str) else shape
        for key, v in (("pos", pos), ("rot", rot), ("size", size)):
            if v is not None:
                op[key] = [round(float(c), 4) for c in v]
        if extra is not None:
            op["extra"] = self._extra(extra) if extra else 0
        patch = dict(extra_patch or {})
        dels = list(patch.pop("-", []))
        if sign is False:
            dels.append("g")
        elif sign is not None:
            self._check_sign(sign, m)
            patch["g"] = {**patch.get("g", {}), **sign}
        if attrs is not None:
            patch["a"] = {**patch.get("a", {}), **attrs}
        if tags is not None:
            if tags:
                patch["t"] = list(tags)
            else:
                dels.append("t")
        if dels:
            patch["-"] = dels
        if patch:
            op["xp"] = self._extra(patch)
        self._op(op)
        self._count("set")

    def remove(self, m, force=None):
        """Drops a row: only pure decoration (no tags, attributes, light, fx, collision, children
        left behind) unless force="the reason"."""
        if isinstance(m, (list, tuple)):
            for one in m:
                self.remove(one, force)
            return
        if not self._check(m, "remove"):
            return
        r = self.row(m)
        ex = extra_of(self.data, r) or {}
        why = []
        for key, label in (("t", "tags"), ("a", "attributes"), ("l", "a light"), ("fx", "particles")):
            if ex.get(key):
                why.append(label)
        if r[FLAGS] & COLLIDE:
            why.append("collision")
        kids = [k for k in self.children.get(m.row, ()) if k not in self.removed]
        if kids:
            why.append(f"{len(kids)} children (remove them first)")
        if why and not force:
            self.error(f"remove {m}: refused ({', '.join(why)}); pass force='reason'")
            return
        if why:
            self.warn(f"remove {m} FORCED ({', '.join(why)}): {force}")
        self.removed.add(m.row)
        self._op({"op": "remove", "m": m.json()})
        self._count("remove")

    def add(self, folder, name, pos, size, color, material="SmoothPlastic", shape="Block", rot=(0, 0, 0),
            transparency=0.0, reflectance=0.0, flags=DECOR, extra=None, sign=None, under=None):
        """A new part (same row format). under: a Match (a city row) or a PartRef (added in the
        same entry). sign: its "g" (a SurfaceGui on it). Returns a PartRef."""
        ex = dict(extra or {})
        if sign is not None:
            self._check_sign(sign, None, size)
            ex["g"] = sign
        row = [SHAPES.index(shape) + 1 if isinstance(shape, str) else shape,
               *[round(float(v), 4) for v in pos], *[round(float(v), 4) for v in rot],
               *[round(max(0.05, float(v)), 4) for v in size],
               self._color(color), self._material(material), transparency, reflectance, flags,
               self._index(self.folders, folder), self._index(self.names, name), 0,
               self._extra(ex) if ex else 0]
        op = {"op": "add"}
        if isinstance(under, Match):
            if not self._check(under, "add under"):
                return PartRef(0, None)
            op["under"] = under.json()
        elif isinstance(under, PartRef):
            row[PARENT] = under.index
        self.parts.append(row)
        op["p"] = len(self.parts)
        entry = self._op(op)
        if isinstance(under, PartRef) and under.entry is not entry:
            self.error(f"add {folder}/{name}: its parent was added in another entry (use O.entry)")
        self._count("add")
        return PartRef(len(self.parts), entry)

    def reparent(self, m, to):
        """Puts the matched row under `to` (a Match, or a PartRef added in the same entry)."""
        if not self._check(m, "reparent"):
            return
        op = {"op": "parent", "m": m.json()}
        if isinstance(to, PartRef):
            op["p"] = to.index
        else:
            if not self._check(to, "reparent to"):
                return
            op["to"] = to.json()
        entry = self._op(op)
        if isinstance(to, PartRef) and to.entry is not entry:
            self.error(f"reparent {m}: the new parent was added in another entry (use O.entry)")
        self._count("parent")

    def wrap(self, matches, piece, origin, ry=0.0, rx=0.0, rz=0.0, tint=None, scale=1.0, size=None,
             folder=None, force=None, name=None):
        """A MeshProp marker of kit `piece` (tools/city/meshprop.py: Piece, Tint "r,g,b", Scale;
        CFrame = origin turned by rx, ry, rz) with the matched rows reparented under it as its
        fallback: PropKit swaps in the mesh exactly as in the alleys. The marker goes in the first
        match's folder, under the first match's parent (a panel's decoration stays with the
        panel). All in one entry (atomic)."""
        import meshprop  # (tools/city on sys.path: pieces.json reader, no Blender)

        if isinstance(matches, Match):
            matches = [matches]
        ok = [m for m in matches if self._check(m, "wrap")]
        if len(ok) != len(matches) or not ok:
            return None
        for m in ok:
            r = self.row(m)
            ex = extra_of(self.data, r) or {}
            bad = sorted(set(ex.get("t", [])) & PROTECTED_TAGS)
            f = folder_of(self.data, r)
            if any(p in f for p in PROTECTED_FOLDERS):
                bad.append(f"in {f}")
            if bad and not force:
                self.error(f"wrap {m}: refused ({', '.join(bad)}); keep it out of the wrap or force='reason'")
                return None
        info = meshprop.pieces().get(piece)
        if size is None:
            if info is None:
                self.error(f"wrap: unknown kit piece {piece!r} (build the kit or pass size=)")
                return None
            lo, hi = info["min"], info["max"]
            size = tuple(max(abs(lo[i]), abs(hi[i])) * 2 for i in range(3))
        size = tuple(max(0.05, v * scale) for v in size)
        attrs = {"Piece": piece}
        if tint is None and info and info.get("tint"):
            tint = next(iter(info["tint"].values()))
        if tint is not None:
            attrs["Tint"] = ",".join(str(int(round(c))) for c in tint)
        if scale != 1.0:
            attrs["Scale"] = round(float(scale), 3)
        first = self.row(ok[0])
        parent = None
        if first[PARENT] > 0:
            p = self.data["parts"][first[PARENT] - 1]
            parent = Match(folder_of(self.data, p), name_of(self.data, p), p[X:X + 3], first[PARENT] - 1)
        with self.entry(name or f"wrap_{piece}_{len(self.entries) + 1}"):
            marker = self.add(folder or folder_of(self.data, first), "MeshProp", origin, size, (128, 128, 128),
                              "SmoothPlastic", rot=(rx, ry, rz), transparency=1.0, flags=DECOR,
                              extra={"a": attrs}, under=parent)
            for m in ok:
                self.reparent(m, marker)
        self._count("wrap")
        return marker

    def sign(self, host, *, text=None, pos=None, size=None, rot=None, plate=None, under=None, **fields):
        """Moves / reframes a sign.
        * plate=None: the host itself is the carrier: pos / size / rot move and resize it, the
          sign fields (text, pad, maxSize, pps="auto"...) are merged into its "g";
        * plate=dict(pos, size, rot?, color, material?, transparency?, flags?): a NEW thin part
          carries the text (the host keeps its look, its sign is taken off it); it is parented to
          `under` (a Match: the panel / glass it sits on, so it breaks with it) or to the host.
        pps="auto": the S0 rule (auto_pps) from the carrier's face height, pad y and lines.
        Returns the plate's PartRef (or None)."""
        if not self._check(host, "sign"):
            return None
        old = (extra_of(self.data, self.row(host)) or {}).get("g")
        if old is None and (text is None or "face" not in fields):
            self.error(f"sign {host}: it has no sign; give text= and face=")
            return None
        g = dict(fields)
        if text is not None:
            g["text"] = text
        r = self.row(host)
        if plate is None:
            carrier_size = size or r[SX:SX + 3]
        else:
            carrier_size = plate["size"]
        if g.get("pps") == "auto":
            face = g.get("face") or old["face"]
            pad = g.get("pad", 0)
            pad_y = pad[1] if isinstance(pad, (list, tuple)) else pad
            lines = (g.get("text") or old["text"]).count("\n") + 1
            g["pps"] = auto_pps(carrier_size[FACES[face][4]], pad_y, lines)
        if plate is None:
            with self.entry(f"sign_{host.name}_{len(self.entries) + 1}"):
                self.set(host, pos=pos, size=size, rot=rot, sign=g)
                if under is not None:
                    self.reparent(host, under)
            self._count("sign")
            return None
        full = {**(old or {}), **g}
        with self.entry(f"sign_{host.name}_{len(self.entries) + 1}"):
            ref = self.add(folder_of(self.data, r), plate.get("name", "SignPlate"), plate["pos"], plate["size"],
                           plate.get("color", (20, 20, 20)), plate.get("material", "SmoothPlastic"),
                           rot=plate.get("rot", r[RX:RX + 3]), transparency=plate.get("transparency", 0.0),
                           flags=plate.get("flags", DECOR), sign=full, under=under or host)
            if old is not None:
                self.set(host, sign=False)
        self._count("sign")
        return ref

    def _check_sign(self, g, m, size=None):
        if g is False:
            return
        bad = set(g) - SIGN_FIELDS
        if bad:
            self.error(f"sign fields {sorted(bad)} unknown (allowed: {sorted(SIGN_FIELDS)})")
        if "face" in g and g["face"] not in FACES:
            self.error(f"sign face {g['face']!r}")
        for key in ("xalign",):
            if key in g and g[key] not in ("Left", "Center", "Right"):
                self.error(f"sign {key} {g[key]!r}")
        if "yalign" in g and g["yalign"] not in ("Top", "Center", "Bottom"):
            self.error(f"sign yalign {g['yalign']!r}")
        if "pps" in g and not (isinstance(g["pps"], (int, float)) and 1 <= g["pps"] <= 400):
            self.error(f"sign pps {g['pps']!r} (1..400)")

    # ------------------------------------------------------------------ output
    def json(self):
        return {"version": 1, "colors": self.colors, "materials": self.materials, "folders": self.folders,
                "names": self.names, "extras": self.extras, "parts": self.parts, "entries": self.entries}


def face_size(size, face):
    _, _, _, wi, hi = FACES[face]
    return size[wi], size[hi]


def flags_alive(row):
    return bool(row[FLAGS] & (COLLIDE | QUERY))


__all__ = ["Overlay", "Match", "PartRef", "OverlayError", "auto_pps", "rotm", "face_size", "FACES", "DECOR",
           "EXTRA", "FOLDER", "NAME"]
