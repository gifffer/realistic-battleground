# 9MM COMPACT — le pistolet

Modèle procédural (Blender, `tools/guns/pistol.py` + la boîte à outils partagée `tools/guns/gunkit.py`).
Pistolet compact à carcasse polymère, percuteur lancé, 9×19, chargeur 15 coups. Dessin original inspiré de la
photo de référence : aucun logo, aucune marque, aucun marquage copié.

Planche de rendus : `pistol_sheet.png` ; prises R6 résolues : `pistol_holds.png`.

## Dimensions (réelles, mètres, axes : +X bouche, +Y gauche de l'arme, +Z haut ; origine sur l'axe du canon, à la face de culasse)

| | Valeur |
|---|---|
| Longueur totale | 0,184 m (cible 0,185) |
| Canon | 0,102 m |
| Hauteur avec chargeur | 0,128 m |
| Largeur | 0,031 m (poignée), culasse 0,0255 m |
| Course de la culasse | 0,028 m (reste en arrière sur chargeur vide) |
| Masse chargée | 0,85 kg |

## Fichiers

| Fichier | Contenu |
|---|---|
| `Pistol.fbx` | l'arme, pièces nommées (voir ci-dessous), UV d'atlas |
| `Pistol_Mag.fbx` | chargeur plein seul (origine = point `MagWell`, +X = sens d'extraction) |
| `Pistol_MagEmpty.fbx` | chargeur vide (élévateur en haut) |
| `Pistol_Case.fbx` | douille 9×19 percutée (150 triangles) |
| `Pistol_Round.fbx` | cartouche 9×19 (176 triangles) |
| `Pistol_Color/Normal/Roughness/Metalness.png` | atlas 1024 de l'arme et du chargeur (SurfaceAppearance) |
| `Pistol_Ammo_*.png` | atlas 256 de la douille et de la cartouche |
| `pistol.markers.json` | points (marqueurs), charnières, groupes, triangles, collisionneur du chargeur |

Les prises R6 résolues sont dans `tools/guns/pistol_holds.json`.

## Pièces (`Pistol.fbx`)

`Frame` (polymère, poignée granitée, rainures de doigts, rail), `Slide` (acier, stries avant/arrière, fenêtre
d'éjection) avec ses enfants `SightFront`, `SightRear` (points blancs) et `Extractor`, `Barrel` (bascule),
`Trigger` (avec lame de sécurité), `SlideStop`, `MagRelease`, `Pins` (levier de démontage, goupilles),
`Magazine` avec son enfant `MagRoundTop` (la cartouche du dessus).

Pièces mobiles : `Slide` glisse en −X de 28 mm ; `Barrel` −2,5° autour de +Y (la culasse descend) ;
`Trigger` +10° ; `SlideStop` −6° (avant relevé = culasse bloquée) ; `MagRelease` −Y de 3 mm ; `Magazine`
sort le long de `MagWell` +X.

## Marqueurs

`Muzzle`, `EjectionPort` (+X = direction moyenne d'éjection : droite, 20° vers l'arrière, 35° vers le haut),
`CasingSpawn`, `MagWell`, `GripR`, `GripL`, `SightEye`, `CoM`, `HolsterMount`, `MagGrab`, `SlideGrip`,
`MagRelease`, `SlideStop`.

## Triangles

Arme sans chargeur ≈ 4 100, chargeur + cartouche du dessus 684, total du FBX ≈ 4 800 ; douille 150 ;
cartouche 176. Chaque pièce est très en dessous de la limite de 20 000 triangles de Roblox.

## Import dans Roblox Studio

1. Avatar / 3D Importer : importer `Pistol.fbx` en unités **mètres** (comme le lance-flammes), sans
   « Anchor » ni rigging. Les pièces arrivent nommées comme ci-dessus.
2. Créer une `SurfaceAppearance` avec `Pistol_Color.png` (ColorMap), `Pistol_Normal.png` (NormalMap),
   `Pistol_Roughness.png` (RoughnessMap), `Pistol_Metalness.png` (MetalnessMap), et la copier dans chaque
   MeshPart (elles partagent le même atlas).
3. Ranger le modèle dans `ReplicatedStorage.Assets.Guns.Pistol` ; le jeu l'ajuste lui‑même à partir des
   pièces `Frame`, `Barrel`, `Trigger` et vérifie `Magazine`. Sans FBX, le jeu garde la version en primitives.
4. Même chose pour `Pistol_Mag.fbx`, `Pistol_Case.fbx`, `Pistol_Round.fbx` (atlas `Pistol_Ammo_*`).
