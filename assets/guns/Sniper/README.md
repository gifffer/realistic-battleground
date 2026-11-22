# .338 BOLT RIFLE — le fusil de précision à verrou (type AWM / L96)

Modèle procédural (Blender, `tools/guns/sniper.py` + la boîte à outils partagée `tools/guns/gunkit.py`).
Fusil à verrou en .338 : crosse châssis squelette noire à trou de pouce (polymère), busc réglable en hauteur,
plaque de couche caoutchouc sur entretoises (longueur de crosse réglable), molette de monopode arrière, canon
lourd cannelé avec frein de bouche à évents, boîtier rond parkérisé gris très foncé avec long rail picatinny, lunette 3‑12×50
(tourelles, bagues, pare‑soleil), culasse trois tenons avec levier coudé et boule, pontet aluminium en boucle ovale, détente à lame large, garde‑main dont les flancs montent jusqu'à l'axe du canon (canal de canon flottant), chargeur
amovible 5 coups (tôle creuse, lèvres ouvertes, deux cartouches visibles, nervures), bipied repliable (jambes à charnière, rallonges) et grenadières QD. Dessin original inspiré de
la photo de référence : aucun logo, aucune marque, aucun marquage copié.

Planche de rendus : `sniper_sheet.png` ; prises R6 résolues : `sniper_holds.png`.

## Dimensions (réelles, mètres ; axes : +X bouche, +Y gauche de l'arme, +Z haut ; origine sur l'axe du canon, à la face de culasse)

| | Valeur |
|---|---|
| Longueur totale | 1,230 m (cible 1,23) |
| Canon | 0,686 m + frein (bouche du frein : x = 0,757) |
| Hauteur avec lunette et chargeur | 0,255 m (cible 0,24 + lunette) |
| Largeur | 0,096 m (lunette, tourelles et levier de culasse compris) |
| Axe de la lunette au‑dessus de l'âme | 0,065 m (zéro à 100 m) |
| Course de la culasse | rotation −60° (levier en haut), puis recul de 0,115 m |
| Longueur de crosse | +0,040 m ; busc +0,030 m |
| Masse avec lunette et bipied | 7,5 kg |

Silhouette comparée à la photo (côté droit, bipied déplié comme la photo, même largeur) : IoU ≈ 0,79
(`12_reference_compare.png` ; la photo fait 448 px de large, les pièces fines, bipied et anneaux, pèsent lourd).

## Fichiers

| Fichier | Contenu |
|---|---|
| `Sniper.fbx` | l'arme, pièces nommées (voir ci‑dessous), UV |
| `Sniper_Mag.fbx` | chargeur plein seul (origine = point `MagWell`) avec les deux cartouches visibles entre les lèvres |
| `Sniper_MagEmpty.fbx` | chargeur vide (planchette élévatrice grise visible sous les lèvres) |
| `Sniper_Case.fbx` | douille .338 laiton percutée (11 segments lissés, culot avec amorce, bouche sombre = creuse) |
| `Sniper_Round.fbx` | cartouche .338 (10 segments lissés) |
| `Sniper_Color/Normal/Roughness/Metalness.png` | atlas 1024 du métal : boîtier, canon, frein, lunette, culasse, commandes, bipied, chargeur |
| `Sniper_Stock_Color/Normal/Roughness/Metalness.png` | atlas 1024 de la crosse : `Stock`, `CheekPiece`, `ButtPad`, `Monopod` |
| `Sniper_Ammo_*.png` | atlas 256 de la douille et de la cartouche |
| `sniper.markers.json` | points (marqueurs), charnières, groupes, triangles, collisionneur du chargeur |

Les prises R6 résolues sont dans `tools/guns/sniper_holds.json`.

## Pièces (`Sniper.fbx`)

`Receiver` (boîtier, rail, fenêtre d'éjection, pontet et semelle aluminium, vis), `Barrel` (canon cannelé)
avec son enfant `MuzzleDevice` (frein et contre‑écrou), `Stock` (châssis, panneaux grainés, évidements,
grenadières, rail sous le garde‑main, vis de bedding) avec ses enfants `CheekPiece`, `ButtPad`, `Monopod` et
`BipodYoke` (lui‑même parent de `BipodLegL/R`, eux‑mêmes parents de `BipodExtL/R`), `Optic` (lunette, bagues)
avec `OpticLens`, `Bolt` (corps, tenons, extracteur, chien/indicateur d'armement) avec son enfant `BoltHandle`
(levier et boule), `Safety`, `Trigger`, `MagRelease`, `Magazine` avec ses enfants `MagRoundTop` (cartouche du
dessus) et `MagFollower` (seulement dans le chargeur vide). `OpticLens` porte aussi le réticule duplex (matériau `Reticle`,
légèrement lumineux).

Pièces mobiles (pivot = origine de l'objet, aussi dans le JSON) :
- `Bolt` tourne autour de l'axe de l'âme de 0 à −60° (levier relevé), puis glisse en −X de 115 mm (le levier suit).
- `MagRelease` −10° (levier devant le pontet poussé vers l'avant).
- `Safety` 0 = FEU (exporté), +15° = SÛRETÉ.
- `CheekPiece` +Z 30 mm ; `ButtPad` −X 40 mm.
- `BipodLegL/R` +90° autour de +Y à `BipodPivot` (repliées vers l'avant au repos, écartement 3° intégré) ;
  `BipodExtL/R` 80 mm le long de la jambe.
- `Trigger` +8°.
- `Magazine` sort tout droit vers le bas (axe +X de `MagWell`), puis se libère.

## Marqueurs

`Muzzle`, `EjectionPort` (+X = éjection moyenne : à droite et 30° vers le haut), `CasingSpawn`, `MagWell`,
`GripR`, `GripL` (dessous du garde‑main, z −48 mm : le garde‑main repose sur le bras gauche), `Shoulder`
(tiers haut de la plaque de couche, z −30 mm), `SightEye` (90 mm derrière l'oculaire), `CoM`, `BackMount`, `MagGrab`,
`BoltKnob` (+X = sens de tirage), `BoltGrip` (repère du solveur : la main droite sur la boule, culasse levée),
`MagRelease`, `BipodPivot`, `BipodFoot` (pied gauche, bipied déplié, rallonges rentrées).

## Triangles

Voir `sniper.markers.json` → `tris`. Arme complète **18 532** (chargeur plein et ses deux cartouches compris,
21 MeshParts) ; chargeur + deux cartouches 1 074 (budget 1 200) ; douille 150 (budget 150) ; cartouche 196
(budget 200). Plus grosses pièces : `Stock` ≈ 4 350, `Optic` ≈ 3 280, `Receiver` ≈ 3 140, toutes très en dessous
de la limite de 20 000 d'une MeshPart Roblox. C'est au‑dessus des 8 000 du contrat de l'architecture (§5.1),
mais dans la fourchette 15–20 k demandée pour une arme longue : à trancher par le joueur (le script échoue
au‑delà de 20 000 et signale l'écart au contrat).

`sniper.py` vérifie lui‑même le contrat à chaque build (en attendant `tools/guns/check_model.py`) : pièces et
marqueurs requis, noms sans suffixe, échelles appliquées, repères orthonormés, longueur et canon à ±3 %, budgets
douille / cartouche / chargeur, ≤ 25 MeshParts, fenêtre d'éjection à droite.

## Prises R6 (`tools/guns/sniper_holds.json`)

Cinq postures résolues et VÉRIFIÉES (le script échoue si une limite est dépassée ; `--allow-fail` pour déboguer) :
`Aim`, `Ready`, `LowReady`, `BoltCycle` (main droite sur la boule de culasse levée), `ReloadMag` (main gauche sur
le chargeur). Limites dures : rotation du buste et inclinaison dans la tolérance de la posture, roulis du buste
≤ 3° (les jambes ne suivent que le tangage : plus de pied en l'air), cou ≤ 25° en tangage et ≤ 12° en roulis,
poignet ≤ 25°, main gauche à ≤ 0,1 stud de sa cible, œil à ≤ 0,15 stud de l'axe de la lunette (`Aim`,
`BoltCycle`), dévers ≤ 8°, tête hors du bras droit, pieds à plat. Les points de main sont sur les faces avant des
blocs de bras (`rightHand`, `supportHand` dans le JSON), pas sur leur axe : l'arme s'appuie contre les bras au lieu
de les traverser, le boîtier et le chargeur restent visibles de côté.

## Import dans Roblox Studio

1. Importer `Sniper.fbx` en unités **mètres** (comme le lance‑flammes), sans « Anchor » ni rigging. Les pièces
   arrivent nommées comme ci‑dessus.
2. Deux `SurfaceAppearance` :
   - crosse : `Sniper_Stock_Color.png` (ColorMap), `Sniper_Stock_Normal.png` (NormalMap),
     `Sniper_Stock_Roughness.png`, `Sniper_Stock_Metalness.png`, dans `Stock`, `CheekPiece`, `ButtPad`, `Monopod` ;
   - métal : `Sniper_Color.png`, `Sniper_Normal.png`, `Sniper_Roughness.png`, `Sniper_Metalness.png`, dans toutes
     les autres MeshParts (chargeur compris). `OpticLens` peut garder un matériau `Glass` à la place.
3. Ranger le modèle dans `ReplicatedStorage.Assets.Guns.Sniper` ; le jeu l'ajuste lui‑même à partir de
   `Receiver`, `Barrel`, `Trigger` et vérifie `Magazine`. Sans FBX, le jeu garde la version en primitives.
4. Même chose pour `Sniper_Mag.fbx` / `Sniper_MagEmpty.fbx` (atlas métal) et `Sniper_Case.fbx` /
   `Sniper_Round.fbx` (atlas `Sniper_Ammo_*`).
