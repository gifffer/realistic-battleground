"""Z-fighting and overlaps of the city (props audit, PLAN section 4), fixed on the decorative side.

A z-fight is two faces in the same plane, facing the same way, with a different look: the GPU
cannot tell which is in front and they flicker. Each fix moves, shrinks or removes the DECORATIVE
part by 0.01-0.04 studs (never a collider's top used for climbing, never a door, a sign or a
gameplay part's place); the audit's "hidden" pairs (faces pressed against a wall, bottoms under
the floor) are left alone. Found by the coplanar-face scan of the city as the game builds it
(CityData + alleys + CityOverlay).
"""

from overlay.citydata import SX, X


def nudge(O, m, d=(0.0, 0.0, 0.0), ds=(0.0, 0.0, 0.0)):
    """Moves the matched row by d (world studs) and grows its Size by ds (the row's own axes)."""
    r = O.row(m)
    if r is None:
        O.set(m, pos=(0, 0, 0))  # (not found: already reported, the entry is dropped)
        return
    pos = [r[X + k] + d[k] for k in range(3)]
    size = [r[SX + k] + ds[k] for k in range(3)]
    if any(v != 0 for v in ds):
        O.set(m, pos=pos, size=size)
    else:
        O.set(m, pos=pos)


def edits(O):
    # ---------------------------------------------------------------- park
    # Two piers and an ivy trail of the enclosure sit INSIDE the west garden wall, their tops in
    # the wall's top (flicker seen from the roofs): pure decoration nobody can see, removed.
    O.remove(O.match("Park/Enclosure", "WallPier", (-203, 11.225, 95.15)))
    O.remove(O.match("Park/Enclosure", "WallPier", (-203, 11.225, 149.85)))
    O.remove(O.match("Park/Enclosure", "IvyTrail", (-201, 18.929, 149.82)))
    # the SpezCola pad's east edge in the lawn's edge: the pad stops 0.02 short
    nudge(O, O.match("Park", "MachinePad", (-149.1, 1.425, 130.6)), d=(-0.01, 0, 0), ds=(-0.02, 0, 0))
    # the passage arch: each keystone stands 0.04 proud of its lintel (it was flush)
    nudge(O, O.match("Park/Passage", "ArchKeystone", (-147.325, 10.925, 117)), d=(0.04, 0, 0))
    nudge(O, O.match("Park/Passage", "ArchKeystone", (-130.675, 10.925, 117)), d=(-0.04, 0, 0))

    # ---------------------------------------------------------------- SpezCola machines
    # the kick scuff on the front lay in the tray frame's front face: 0.02 proud of it
    nudge(O, O.match("Park/SpezColaMachine_3", "Scuff", (-149.83, 3.15, 131.7)), d=(0.02, 0, 0))
    nudge(O, O.match("Zones/Cage/SpezColaMachine_2", "Scuff", (-43.9, 2.8, 115.97)), d=(0, 0, 0.02))
    nudge(O, O.match("Interiors/Duffys/SpezColaMachine_1", "Scuff", (60.07, 3.45, -5.7)), d=(0.02, 0, 0))

    # ---------------------------------------------------------------- shop doorways
    # The threshold slabs ended exactly on the door posts' faces and the street slab's edge:
    # each end now stops 0.01 inside the post (nothing that shows or collides moves).
    nudge(O, O.match("Interiors/Threadbare", "ThresholdFloor", (-27.6, 1.35, -92)), ds=(0, 0, -0.02))
    nudge(O, O.match("Interiors/Rewind", "ThresholdFloor", (-27.6, 1.35, 20)), ds=(0, 0, -0.02))
    nudge(O, O.match("Interiors/Threadbare", "ThresholdFloor", (-46, 1.35, -71.6)), d=(0, 0, -0.005),
          ds=(-0.02, 0, -0.01))
    nudge(O, O.match("Interiors/Rewind", "ThresholdFloor", (-44, 1.35, -16.4)), ds=(-0.02, 0, 0))
    nudge(O, O.match("Interiors/Duffys", "ThresholdFloor", (73, 1.35, 20.4)), d=(0, 0, -0.005), ds=(0, 0, -0.01))
    # the door mats ended on the shop floor's edge: 0.02 back from it
    nudge(O, O.match("Interiors/Threadbare", "DoorMat", (-46, 1.95, -73.7)), d=(0, 0, -0.01), ds=(0, 0, -0.02))
    nudge(O, O.match("Interiors/Threadbare", "DoorMat", (-29.7, 1.95, -92)), d=(-0.01, 0, 0), ds=(-0.02, 0, 0))
    nudge(O, O.match("Interiors/Rewind", "DoorMat", (-29.7, 1.95, 20)), d=(-0.01, 0, 0), ds=(-0.02, 0, 0))

    # ---------------------------------------------------------------- Duffy's
    # the two ceiling pipes ran through the partitions with their tops in the partitions' tops
    nudge(O, O.match("Interiors/Duffys", "Pipe", (55, 15.25, -9)), d=(0, -0.03, 0))
    nudge(O, O.match("Interiors/Duffys", "Pipe", (55, 15.25, 16)), d=(0, -0.03, 0))

    # ---------------------------------------------------------------- cars (fallback look)
    # the door pillar slab had the cabin's top and bottom faces: 0.02 inside both
    for folder, at in (("Props/Cars", (-12, 4.8, -115.5)), ("Props/Cars", (12, 4.8, 38.5)),
                       ("Zones/Lot9", (93, 4.85, -109.5)), ("Zones/Lot9", (93, 4.85, -94.5)),
                       ("Zones/Ferro", (-87, 5.85, -77.5))):
        nudge(O, O.match(folder, "Pillar", at), ds=(0, -0.04, 0))

    # ---------------------------------------------------------------- the Cage, Lot 9
    # the fence's top rails ended in the chain-link slabs' end faces: 0.01 shorter each end
    for z in (85, 101, 116.7):
        nudge(O, O.match("Zones/Cage", "TopRail", (-27.3, 15.15, z)), ds=(0, 0, -0.02))
    # the bay lines ran into the B11 plinth with their ends in the lot floor's edge: 0.05 shorter
    for z in (-117, -104, -86):
        nudge(O, O.match("Zones/Lot9", "BayLine", (99, 1.275, z)), d=(-0.025, 0, 0), ds=(-0.05, 0, 0))
    # the low window sill on the M block sank into the Cage bench under it: its bottom 0.06 up
    nudge(O, O.match("Buildings/M/Facade_N", "Sill", (-67, 3.4, 118.8)), d=(0, 0.03, 0), ds=(0, -0.06, 0))

    # ---------------------------------------------------------------- ring blocks
    # sills sharing the window pane's back face: each sill goes 0.03 further into its wall
    for z in (-8.875, 1.375, 32.125, 42.375, 52.625, 62.875):
        nudge(O, O.match("Ring/E3", "Sill", (130.75, 25.4, z)), d=(0.015, 0, 0), ds=(0.03, 0, 0))
    for x in (49.5, 63.5, 77.5, 84.5, 91.5):
        nudge(O, O.match("Ring/Delmar", "Sill", (x, 20.9, -134.75)), d=(0, 0, -0.015), ds=(0, 0, 0.03))
    for z in (-60, -50, -40, -30):
        nudge(O, O.match("Ring/W2", "Sill", (-130.75, 24, z)), d=(-0.015, 0, 0), ds=(0.03, 0, 0))
    # the Marrow Tower lobby's glow strip ended in the two end fins' faces: 0.02 short each end
    nudge(O, O.match("Ring/MarrowTower", "LobbyGlow", (0, 7.2, -135)), ds=(-0.04, 0, 0))
    # B2's roof plant room was built against the W1 block over its lowest window (half the
    # window buried in the hut): the opening above the hut's roof is bricked up, as it would be.
    # (Newer, redder brick between the stone jambs, under the lintel; its foot inside the hut.)
    # (hung under the window's lintel: it only appears where that window still is)
    lintel = O.match("Ring/W1", "Lintel", (-130.8, 22.95, -119))
    O.add("Ring/W1", "BrickInfill", (-130.86, 21.05, -119), (0.06, 3.1, 4.4), (72, 47, 39), "Brick", under=lintel)
