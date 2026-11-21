"""Every text of the city (CityData; the alleys' own texts are fixed in their generator,
tools/city/props_walls.py and alleys.py): texts audit S0 and T04-T12.

The harmonised look (audit S0):
* the text never touches its plate: a UIPadding (pad, in Scale of the face) on every sign;
* PixelsPerStud per sign (overlay/textfit.fit_pps): the text fills its padded box exactly at
  TextScaled's 100 px cap, so it is as sharp as it can be and never wraps into a bigger size;
* texts on several lines carry their own line breaks (no automatic wrap: no "·" left hanging);
* fonts by kind: fascias and neons Oswald / Bodoni as built, boards Arimo, sprays
  PermanentMarker; only neons are lit (their SurfaceGui stays "Sign" on the tagged part:
  Ambience.setNeon drives its LightInfluence / Brightness);
* carriers sit 0.01-0.03 off the surface they are painted or stuck on, and are parented to that
  panel / glass so they go with it when it breaks (Destruction hides a broken part's descendants).
"""

from overlay.core import FACES
from overlay.textfit import fit_pps

F = "Buildings/B12"


def _face_wh(size, face):
    _, _, _, wi, hi = FACES[face]
    return size[wi], size[hi]


def tidy(O, m, pad, text=None, size=None, scale=1.0, **fields):
    """Pads a sign where it is, with the PixelsPerStud that fits its (new) text, and any other
    sign fields; pos / rot / under pass through to O.sign."""
    row, ex = O.row(m), O.extra(m)
    if row is None or not ex or "g" not in ex:
        O.error(f"tidy {m}: no sign there")
        return
    g = ex["g"]
    face = fields.get("face", g["face"])
    w, h = _face_wh(size or row[7:10], face)
    sign_fields = {k: v for k, v in fields.items() if k not in ("pos", "rot", "under")}
    font = sign_fields.get("font", g.get("font", "Oswald"))
    pps = fit_pps(text or g["text"], font, w, h, pad, scale=scale)
    pps = min(pps, max(25, 2048 // max(w, h)))  # (a canvas at most 2048 px long: big faces cost)
    O.sign(m, text=text, size=size, pos=fields.get("pos"), rot=fields.get("rot"), under=fields.get("under"),
           pad=pad, pps=pps, **sign_fields)


def edits(O):
    # ---------------------------------------------------------------- shop fascias (T08)
    # Lit letters on the whole fascia touched its top and bottom: cap height ~55 % of the plate.
    for at in ((-43.7, 14, -70.7), (-26.7, 14, -85)):
        tidy(O, O.match("Buildings/B1", "Fascia", at), [0.04, 0.18])
    for at in ((-42.7, 14, -17.3), (-26.7, 14, 4)):
        tidy(O, O.match("Buildings/B5", "Fascia", at), [0.04, 0.18])
    for at in ((26.7, 14, 5.1), (49.1, 14, -17.3)):
        tidy(O, O.match(F, "Fascia", at), [0.04, 0.18])

    # ---------------------------------------------------------------- shop sub-boards / name boards
    tidy(O, O.match("Buildings/B1", "SignBoard", (-35, 11.6, -70.925)), [0.04, 0.15])
    tidy(O, O.match("Buildings/B5", "SignBoard", (-34.2, 11.6, -17.075)), [0.04, 0.15])
    tidy(O, O.match("Buildings/SEN", "NameBoard", (-11, 14.2, 118.9)), [0.05, 0.18])
    # FERRO AUTO REPAIR: a dead sign, its paint faded to 1.6:1 on the board: still worn (paint
    # 15 % gone), but readable (about 3:1).
    tidy(O, O.match("Zones/Ferro", "DeadSign", (-90, 12.9, -86.9)), [0.03, 0.18], color=(150, 144, 128),
         textTr=0.15)

    # ---------------------------------------------------------------- neons (T09-T12, kiosk)
    tidy(O, O.match("Buildings/B7", "NeonSign", (-102, 10.9, -17.85)), [0.05, 0.15])  # LIQUOR
    tidy(O, O.match("Buildings/B11", "NeonSign", (119, 10.9, -70.15)), [0.05, 0.15])  # CHECKS CASHED
    tidy(O, O.match("Props/Kiosk", "KioskSign", (126.1, 10.55, -44)), [0.04, 0.15])  # NEWS LOTTO SMOKES
    # LOT 9 · PARKING wrapped as "LOT 9 ·" / "PARKING": two lines of its own.
    tidy(O, O.match("Zones/Lot9", "NeonSign", (42, 11, -70.9)), [0.08, 0.1], text="LOT 9\nPARKING")
    # The blade signs: VHS width-bound (letters touched the sides); DUFFY'S had its apostrophe on
    # a line of its own (a gap: "DUFFY" + "S"): six letters, evenly stacked.
    tidy(O, O.match("Buildings/B5", "BladeSign", (-26.293, 22.2, -17.707)), [0.12, 0.05])
    tidy(O, O.match(F, "BladeSign", (26.293, 24.6, -17.707)), [0.1, 0.04], text="D\nU\nF\nF\nY\nS")
    # COLD BEER / ON TAP (T07): opaque black boards over the window, their back on the glass and
    # their foot on the sash: neon tubes hung 0.03 in front of the glass, clear of the sash, on
    # the facade panel (they go with it when it breaks).
    for x in (69, 77):
        board = O.match(F, "WindowNeon", (x, 6.3, -17.15))
        panel = O.match(f"{F}/Facade_N", "Panel", (x, 5.2, -16.4))
        with O.entry(f"window_neon_{x}"):
            O.set(board, transparency=1.0)
            tidy(O, board, [0.06, 0.12], pos=(x, 6.55, -17.18), under=panel)

    # ---------------------------------------------------------------- posters, printed boards
    # DANCE NIGHT FRI (T05): centred on the window's mullion ("DA NCE"), its face on the glass's
    # inner face (z-fight): in the left pane, 0.02 behind the glass, on the glass.
    glass_n = O.match("Buildings/B5/Facade_N", "ShopGlass", (-54, 7.1, -16.4))
    tidy(O, O.match("Interiors/Rewind", "Poster", (-54.3, 6.2, -16.2)), 0.1, pos=(-56.6, 6.2, -16.18), under=glass_n)
    # 2 FOR 1 RENTALS (T06): same on the east window, clear of the mullion.
    glass_e = O.match("Buildings/B5/Facade_E", "ShopGlass", (-27.6, 7.1, 8))
    tidy(O, O.match("Interiors/Rewind", "Poster", (-27.8, 5.9, 12.3)), 0.1, pos=(-27.82, 5.9, 12.8), under=glass_e)
    for at in ((-58.95, 13.5, -2), (-58.95, 13.5, 8)):  # the film posters upstairs
        tidy(O, O.match("Interiors/Rewind", "Poster", at), [0.1, 0.12])
    tidy(O, O.match("Interiors/Threadbare", "SaleSign", (-54.276, 5.034, -76.115)), 0.08)
    tidy(O, O.match("Climb/Billboard", "Billboard", (87, 25.2, -126.75)), [0.06, 0.1])
    tidy(O, O.match("Ring/W2", "Advert", (-130.9, 40.2, -44)), [0.06, 0.12])  # SAVOY SOAP
    tidy(O, O.match("Ring/E2", "Advert", (130.9, 25.2, -40)), [0.05, 0.1])  # NITE OWL DINER
    # the van's livery: "HALVORSEN" / "FREIGHT" on two lines of their own, off the edges
    tidy(O, O.match("Zones/Yard", "Livery", (40.8, 7.25, 28.725)), [0.05, 0.1], text="HALVORSEN\nFREIGHT")
    # the vending machines' lit panels (text touched both sides)
    for folder, at in (("Interiors/Duffys/SpezColaMachine_1", (60.01, 6.7, -7.25)),
                       ("Zones/Cage/SpezColaMachine_2", (-42.35, 6.05, 115.91)),
                       ("Park/SpezColaMachine_3", (-149.89, 6.4, 130.15))):
        tidy(O, O.match(folder, "Panel", at), [0.08, 0.3])

    # ---------------------------------------------------------------- graffiti
    # KINGS (T04): 16 studs across two breakable panels, its K under the drainpipe and its top by
    # the floodlight. Now one tag in two halves, each painted on its own panel (it breaks with
    # it): "KIN" ending at the panels' seam (x -87), "GS" starting there, same size (same 100 px
    # cap), 0.01 off the brick, clear of the pipe (x -79.4) and the floodlight.
    kings = O.match("Zones/Cage", "Graffiti", (-85, 12.9, 118.875))
    left = O.match("Buildings/M/Facade_N", "Panel", (-91, 13.2, 119.6))
    right = O.match("Buildings/M/Facade_N", "Panel", (-83, 13.2, 119.6))
    h, z = 4.2, 118.98
    wl, wr = 7.4, 6.4
    pps = max(fit_pps("KIN", "PermanentMarker", wl, h), fit_pps("GS", "PermanentMarker", wr, h))
    ex = O.extra(kings)
    if ex:
        with O.entry("kings"):
            O.sign(kings, text="KIN", pos=(-87 - wl / 2, 12.9, z), size=(wl, h, 0.02), xalign="Right", pps=pps,
                   textTr=0.05, under=left)
            O.add("Zones/Cage", "Graffiti", pos=(-87 + wr / 2, 12.9, z), size=(wr, h, 0.02), color=(0, 0, 0),
                  transparency=1.0, sign={**ex["g"], "text": "GS", "xalign": "Left", "pps": pps, "textTr": 0.05},
                  under=right)
    # NO REFS: red on red brick (1.4:1) across two panels: off-white, on one panel (row 2, slot 7),
    # clear of the louvre below, 0.01 off the brick.
    tidy(O, O.match("Zones/Doyle", "Graffiti", (-88.975, 12.7, -4)), [0.04, 0.06], text="NO\nREFS",
         pos=(-88.98, 12.8, -5), size=(0.02, 4.6, 7.2), color=(228, 222, 206), textTr=0.08,
         under=O.match("Buildings/B7/Facade_E", "Panel", (-89.6, 13.2, -5)))
