# 5.56 LMG — la mitrailleuse légère à bande (type M249 / Minimi « para »)

Modèle procédural (Blender, `tools/guns/lmg.py` + la boîte à outils partagée `tools/guns/gunkit.py`).
Mitrailleuse légère alimentée par bande en 5,56×45 : boîtier en tôle emboutie phosphatée (nervures, rivets),
couvercle d'alimentation embouti creux (parois 2 mm, levier d'alimentation, griffes et guides dessous) à charnière AVANT
sur le tourillon et verrou arrière, avec rail picatinny (la lunette prismatique 4× est montée dessus, embase basse à levier),
plateau d'alimentation dans un puits ouvert, plaque de marquage générique (`RB-24581`, `CAL 5.56 NATO`), deux grandes
goupilles de démontage, nervures embouties dans des panneaux en creux, fenêtre d'éjection SOUS le boîtier (les douilles tombent vers le bas), fenêtre
d'éjection des maillons à droite (volet à ressort ouvert), levier d'armement non solidaire à droite dans sa
lumière, carcasse de détente en polymère avec grand pontet et poignée‑pistolet, canon à changement rapide avec
sa poignée de transport, bloc de gaz, guidon à oreilles et cache‑flamme à fentes, garde‑main aluminium à quatre
rails, cylindre de gaz, bipied repliable (jambes repliées vers l'arrière sous le garde‑main), crosse
télescopique à tubes avec talon polymère et plaque de couche caoutchouc, sac souple de 200 cartouches (cordura
camouflage numérique fin et peu contrasté, profil ovale 200 × 160 × 85 mm, bord roulé, ganse sombre, une sangle
de compression, rangées MOLLE, adaptateur polymère accroché sous le boîtier) d'où sort une bande de cartouches
maillonnées qui monte jusqu'au plateau. La bretelle beige est un modèle à part (`Lmg_Sling.fbx`). Dessin original inspiré de
la photo de référence : aucun logo, aucune marque, aucun marquage copié.

Planche de rendus : `lmg_sheet.png` ; prises R6 résolues : `lmg_holds.png`.

## Dimensions (réelles, mètres ; axes : +X bouche, +Y gauche de l'arme, +Z haut ; origine sur l'axe du canon, à la face de culasse)

| | Valeur |
|---|---|
| Longueur totale | 0,894 m crosse sortie (cible 0,89) ; 0,794 m crosse rentrée |
| Canon | 0,349 m (bouche du cache‑flamme : x = 0,395) |
| Hauteur | 0,280 m du haut de la poignée de transport au bas de la poignée‑pistolet (cible 0,28, sans lunette, sac ni bipied) |
| Hauteur totale | ≈ 0,36 m avec la lunette et le sac |
| Axe de visée au‑dessus de l'âme | 0,080 m (lunette 4× directement sur le rail du couvercle, zéro à 100 m) |
| Course du levier d'armement | 0,140 m |
| Pas de la bande (maillons type M27) | 10,2 mm |
| Masse | 7,1 kg + 3,0 kg le sac plein (10,1 kg dans le JSON) |

Silhouette comparée à la photo : `12_reference_compare.png` (côté gauche, bipied déplié et bretelle pendante
comme sur la photo). L'IoU reste bas (0,39) parce que la photo est une vue de trois‑quarts en perspective,
avec la bretelle posée au sol, pas un profil ; les proportions viennent des cotes réelles, pas de la photo.

## Fichiers

| Fichier | Contenu |
|---|---|
| `Lmg.fbx` | l'arme, 24 pièces nommées (voir ci‑dessous), UV ; SANS la bretelle |
| `Lmg_Pouch.fbx` | le sac plein seul (origine = point `PouchMount`) |
| `Lmg_PouchEmpty.fbx` | le sac vide, affaissé (moitié basse écrasée, faces enfoncées, rabat ouvert ; ses propres UV dans l'atlas `Lmg_Soft`) |
| `Lmg_Sling.fbx` | la bretelle au repos, pendante sous l'arme (origine = `SlingFront`) ; en jeu la sangle est pilotée entre `SlingFront` et `SlingRear` (corde / Beam beige) |
| `Lmg_BeltSegment.fbx` | un bout de bande de 10 cartouches (bande le long de +X, cartouches le long de +Y) |
| `Lmg_Link.fbx` | un maillon seul (éjecté à droite à chaque tir) |
| `Lmg_Case.fbx` | douille 5,56 laiton percutée (éjectée vers le bas) |
| `Lmg_Round.fbx` | cartouche 5,56 |
| `Lmg_Color/Normal/Roughness/Metalness.png` | atlas 1024 : métal, polymère, lunette, bipied (toutes les pièces sauf sac, bretelle, bande) |
| `Lmg_Soft_*.png` | atlas 1024 des tissus : `AmmoPouch` (= `Lmg_Pouch`), `Lmg_PouchEmpty`, `Lmg_Sling` |
| `Lmg_Ammo_*.png` | atlas 512 : `Belt01`…`Belt12`, douille, cartouche, maillon, bout de bande |
| `lmg.markers.json` | points (marqueurs), charnières, groupes, triangles, collisionneur du sac |

Les prises R6 résolues sont dans `tools/guns/lmg_holds.json` : `Aim` (crosse à l'épaule, œil sur l'axe de la
lunette à 0,011 stud, main gauche à 0,011 stud), `Ready`, `LowReady`, `HipCarry` (port d'assaut bas, crosse
sous l'avant‑bras droit, main gauche sous le garde‑main à 0,064 stud ; poignet 42°, au‑dessus de la limite :
des bras R6 sans coude ne peuvent pas tenir une arme à la hanche), `BeltReload` (couvercle ouvert, arme
inclinée de 12°, tête vers le plateau, main gauche sur la bande à 0,003 stud).

## Pièces (`Lmg.fbx`)

`Receiver` (boîtier, tourillon, carcasse de détente, poignée‑pistolet, pontet, hausse arrière, garde‑main et
rails, cylindre de gaz, chape du bipied, anneau de bretelle), `Barrel` (canon, collier, poignée de transport,
bloc de gaz, guidon, cache‑flamme), `FeedCover` avec ses enfants `Optic` puis `OpticLens`, `FeedTray`, `Stock`,
`Trigger`, `ChargingHandle`, `BipodLegL`, `BipodLegR`, `AmmoPouch`, `Belt01`…`Belt12`.

Pièces mobiles (pivot = origine de l'objet, aussi dans le JSON) :
- `FeedCover` tourne de 0 à +70° autour de +Y (charnière AVANT sur le tourillon, l'arrière se lève, comme la vraie
  arme ; contrat §5.2 amendé) ; la lunette suit et passe devant la poignée de transport.
- `FeedTray` 0 → −20° (charnière arrière).
- `ChargingHandle` recule de 140 mm (−X).
- `Stock` 0 = sortie (exportée), +100 mm (+X) = rentrée.
- `BipodLegL/R` 0 → −90° autour de +Y à `BipodPivot` (repliées vers l'arrière, elles descendent).
- `Trigger` +12°.
- `AmmoPouch` se décroche vers le bas (40 mm) puis tombe librement (`Magazines.luau`).
- `Belt01`…`Belt12` affichées ou cachées selon les cartouches restantes ; `Belt01` est la cartouche sur le
  plateau (la prochaine tirée), `Belt12` plonge dans l'embouchure du sac. À chaque tir la bande « tressaute »
  d'un pas de maillon.

## Marqueurs

`Muzzle`, `EjectionPort` (+X = éjection moyenne : VERS LE BAS, 10° vers l'avant, 8° vers la droite pour éviter
le sac), `CasingSpawn`, `LinkPort` et `LinkSpawn` (maillons à droite, 10° vers le bas), `FeedTrayEntry` (+X =
sens de la bande, vers la droite), `PouchMount` (+X = sortie de la bande, vers le haut ; le sac part en −X),
`GripR`, `GripL` (sous le rail du garde‑main), `Shoulder`, `SightEye` (38 mm derrière l'oculaire), `CoM`,
`BackMount`, `ChargeHandle` (+X = sens de tirage), `FeedCoverLatch` (bord arrière, libre), `CarryHandle`,
`SlingFront` / `SlingRear` (points d'attache de la sangle), `BipodPivot`, `BipodFoot`
(pied gauche déplié), et deux repères du solveur : `BeltGrab` (main gauche posant la bande, couvercle ouvert) et
`PouchGrab` (main gauche sur la face du sac).

## Triangles

Voir `lmg.markers.json` → `tris`. Arme complète (sac, bande et bretelle compris) ≈ 18 500 : `Receiver` ≈ 5 600,
`Barrel` ≈ 2 400, `Stock` ≈ 2 100, `AmmoPouch` ≈ 1 900, bande 12 × ≈ 228, `Sling` 600, le reste < 1 000 chacun.
Chaque pièce est très en dessous de la limite de 20 000 triangles d'une MeshPart Roblox. C'est au‑dessus des
12 000 du contrat de l'architecture (comme le fusil de précision), dans la fourchette 15–20 k demandée pour une
arme longue ; pour descendre vers 12 k, baisser `gk.set_quality` (0,8 aujourd'hui) ou cacher la bretelle.
Douille 114, cartouche 156, maillon 168, bout de bande ≈ 2 250, sac seul ≈ 1 900.

## Import dans Roblox Studio

1. Importer `Lmg.fbx` en unités **mètres** (comme le lance‑flammes), sans « Anchor » ni rigging. Les pièces
   arrivent nommées comme ci‑dessus.
2. Trois `SurfaceAppearance` :
   - tissus : `Lmg_Soft_Color.png` (ColorMap), `Lmg_Soft_Normal.png` (NormalMap), `Lmg_Soft_Roughness.png`,
     `Lmg_Soft_Metalness.png`, dans `AmmoPouch` (et `Lmg_PouchEmpty`, `Lmg_Sling`) ;
   - munitions : `Lmg_Ammo_*`, dans `Belt01`…`Belt12` ;
   - métal : `Lmg_*` dans toutes les autres MeshParts. `OpticLens` peut garder un matériau `Glass`.
3. Ranger le modèle dans `ReplicatedStorage.Assets.Guns.Lmg` ; le jeu l'ajuste lui‑même à partir de
   `Receiver`, `Barrel`, `Trigger` et vérifie `AmmoPouch`. Sans FBX, le jeu garde la version en primitives.
4. Même chose pour `Lmg_Pouch.fbx` / `Lmg_PouchEmpty.fbx` (atlas `Lmg_Soft_*`) et `Lmg_Case.fbx`,
   `Lmg_Round.fbx`, `Lmg_Link.fbx`, `Lmg_BeltSegment.fbx` (atlas `Lmg_Ammo_*`).
5. La bretelle n'est plus dans `Lmg.fbx` : le jeu tend une sangle beige entre `SlingFront` et `SlingRear`.
   `Lmg_Sling.fbx` (pendante, dans le plan de l'arme, posée sous le sac) sert à l'arme au sol / en présentoir.

## Régénérer

```
/home/user/z-anatomy/venv/bin/python -I tools/guns/lmg.py --out DOSSIER [--samples 32] [--quick] \
    [--only 01,07] [--no-bake] [--no-holds] [--no-render] [--no-export] [--ref photo.png]
```
