# 9MM COMPACT — le pistolet

Modèle procédural (Blender, `tools/guns/pistol.py` + la boîte à outils partagée `tools/guns/gunkit.py`).
Pistolet compact à carcasse polymère, percuteur lancé, 9×19, chargeur 15 coups. Dessin original inspiré de la
photo de référence : aucun logo, aucune marque, aucun marquage copié (seulement le marquage générique
`RB-04127` et `9x19` gravé sur le flanc gauche de la culasse).

Planche de rendus : `pistol_sheet.png` ; prises R6 résolues : `pistol_holds.png`.

## Dimensions (réelles, mètres, axes : +X bouche, +Y gauche de l'arme, +Z haut ; origine sur l'axe du canon, à la face de culasse)

| | Valeur |
|---|---|
| Longueur totale | 0,184 m (cible 0,185) |
| Canon | 0,102 m (la couronne dépasse de 2,5 mm de la culasse, comme sur la photo) |
| Hauteur avec chargeur | 0,1285 m |
| Largeur | 0,031 m (poignée), culasse 0,0255 m |
| Course de la culasse | 0,028 m (reste en arrière sur chargeur vide) |
| Masse chargée | 0,85 kg |

## Fichiers

| Fichier | Contenu |
|---|---|
| `Pistol.fbx` | l'arme, pièces nommées (voir ci-dessous), UV d'atlas |
| `Pistol_Mag.fbx` | chargeur plein seul (origine = point `MagWell`, +X = sens d'extraction) |
| `Pistol_MagEmpty.fbx` | chargeur vide (l'élévateur dépasse entre les lèvres) |
| `Pistol_Case.fbx` | douille 9×19 percutée (146 triangles) |
| `Pistol_Round.fbx` | cartouche 9×19 (170 triangles) |
| `Pistol_Color/Normal/Roughness/Metalness.png` | atlas 1024 de l'arme et du chargeur (SurfaceAppearance) |
| `Pistol_Ammo_*.png` | atlas 256 de la douille et de la cartouche |
| `pistol.markers.json` | points (marqueurs), charnières, groupes, triangles, collisionneur du chargeur |

Les prises R6 résolues sont dans `tools/guns/pistol_holds.json`.

## Pièces (`Pistol.fbx`)

`Frame` (polymère : panneaux granités sur les flancs de la poignée, rainures horizontales sur le dos de la
poignée et dans les creux des doigts, deux bosses de doigts, rail, pontet à l'avant strié, ouverture du ressort
récupérateur à l'avant), `Slide` (acier, stries arrière seulement comme la photo, fenêtre d'éjection, marquage
gravé à gauche) avec ses enfants `SightFront`, `SightRear` (points blancs) et `Extractor`, `Barrel` (bascule),
`Trigger` (avec lame de sécurité dans sa fente), `SlideStop`, `MagRelease`, `Pins` (leviers de démontage,
goupilles, bout de la tige-guide), `Magazine` avec ses enfants `MagRoundTop` (la cartouche du dessus) et
`MagFollower` (l'élévateur, visible seulement dans le modèle du chargeur vide).

Pièces mobiles : `Slide` glisse en −X de 28 mm ; `Barrel` −2,5° autour de +Y, **pivot à l'avant** (sous le nez
de la culasse en position arrière, x = 0,067 m) : la culasse du canon descend de 2,9 mm et la bouche reste
centrée dans le nez ; `Trigger` +10° ; `SlideStop` −6° (avant relevé = culasse bloquée) ; `MagRelease` −Y de
3 mm ; `Magazine` sort le long de `MagWell` +X.

## Marqueurs

`Muzzle`, `EjectionPort` (+X = direction moyenne d'éjection : droite, 20° vers l'arrière, 35° vers le haut),
`CasingSpawn`, `MagWell`, `GripR`, `GripL`, `SightEye` (à longueur de bras : 0,55 m derrière le cran de mire ;
la caméra de visée se place sur cette ligne), `CoM`, `HolsterMount`, `MagGrab`, `SlideGrip`, `MagRelease`,
`SlideStop`.

## Triangles

Arme sans chargeur 3 592 (cible 4 000), chargeur + cartouche du dessus 670, total du FBX 4 262 ; douille 146 ; cartouche 170.

Tous les maillages sont **triangulés** avant les UV, la cuisson et l'export (les tangentes de Roblox suivent la normal map), sans faces dégénérées ni doublées : les nombres ci‑dessous sont exactement ceux du FBX. Contrat (ARCHITECTURE §5.1, passe de cohérence) : **cible** 8 000 pour une arme longue sans son chargeur (pistolet 4 000, LMG 12 000), **plafond** 20 000 pour le FBX entier (pistolet 6 000) ; chargeur ≤ 1 200, douille ≤ 150, cartouche ≤ 200. Vérifié par `tools/guns/check_model.py`.

## Prises R6 (`tools/guns/pistol_holds.json`)

Postures : `Aim` (isocèle, œil SUR la ligne de mire), `Ready`, `HighReady`, `LowReady` (buste droit),
`SprintCarry`, `ObstructedHigh`, `ObstructedLow`, `ReloadInsert` ; rangées de tangage de la visée
`Aim_p-60`, `Aim_p-30`, `Aim` (0), `Aim_p+30`, `Aim_p+60` ; colonnes de recul contre un mur `Aim` (0),
`Aim_t0.5`, `Aim_t1.0`. Chaque posture porte son contrôle (`check`) : main droite, main gauche, poignet,
roulis de la tête, arme dans les bras ou la tête, part visible de l'arme, pieds à plat.

Limite connue : les bras R6 sont rigides, donc la tête R6 se trouve à 0,15–0,27 m des organes de visée (et non à
0,55–0,65 m comme un vrai tireur). L'œil est placé exactement sur la ligne ; la caméra de visée du jeu doit
utiliser `SightEye`, pas la tête. Les rangées vers le haut (+30, +60) ne peuvent pas garder l'œil R6 sur la
ligne : la tête suit l'arme du regard. Seul échec signalé par le contrôle : `Aim_p+60` plafonne à 53° de
tangage (bras rigides) au lieu de 60 ± 6. Les tenues basses à deux mains (`LowReady`, `SprintCarry`) gardent
les bras presque horizontaux, l'arme pointant vers le bas : des bras R6 rigides ne peuvent pas descendre à 45°
et se rejoindre au centre.

## Import dans Roblox Studio

1. Avatar / 3D Importer : importer `Pistol.fbx` en unités **mètres** (comme le lance-flammes), sans
   « Anchor » ni rigging. Les pièces arrivent nommées comme ci-dessus.
2. **Les textures ont été recalculées (nouvel atlas) : les identifiants de `assets/guns/texture_ids.json` pour
   `Pistol_*` sont périmés et doivent être remplacés** après un nouvel envoi de `Pistol_Color.png`,
   `Pistol_Normal.png`, `Pistol_Roughness.png`, `Pistol_Metalness.png` et des `Pistol_Ammo_*.png`.
   (`Pistol_Roughness` et `Pistol_Ammo_Color` n'avaient de toute façon jamais été envoyés : ils valent 0.)
3. Créer une `SurfaceAppearance` avec ColorMap = `Pistol_Color`, NormalMap = `Pistol_Normal`,
   RoughnessMap = `Pistol_Roughness`, MetalnessMap = `Pistol_Metalness`, et la copier dans chaque MeshPart
   (elles partagent le même atlas). Tant qu'une carte vaut 0, laisser le champ vide.
4. Ranger le modèle dans `ReplicatedStorage.Assets.Guns.Pistol` ; le jeu l'ajuste lui‑même à partir des
   pièces `Frame`, `Barrel`, `Trigger` et vérifie `Magazine`. Sans FBX, le jeu garde la version en primitives.
5. Même chose pour `Pistol_Mag.fbx`, `Pistol_MagEmpty.fbx`, `Pistol_Case.fbx`, `Pistol_Round.fbx`
   (atlas `Pistol_Ammo_*` pour la douille et la cartouche).
