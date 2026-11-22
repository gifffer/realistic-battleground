# 7.62 RIFLE — le fusil d'assaut (type AK, bois)

Modèle procédural (Blender, `tools/guns/rifle_ak.py` + la boîte à outils partagée `tools/guns/gunkit.py`).
Fusil type AK‑47 en 7,62×39 à boîtier usiné (long évidement latéral au‑dessus du chargeur, deux goupilles
transversales affleurantes, pas de rivets, marquage générique « RB-04127 / 7.62x39 » gravé sur le flanc gauche),
couvercle de culasse lisse, garnitures en bois (crosse montée à
fleur du boîtier avec ses pattes de fixation en acier, poignée, garde‑mains haut et bas), chargeur courbe
30 coups en acier. Dessin original inspiré de la photo de référence : aucun logo, aucune marque, aucun marquage copié.

Planche de rendus : `rifle_sheet.png` ; prises R6 résolues : `rifle_holds.png`.

## Dimensions (réelles, mètres ; axes : +X bouche, +Y gauche de l'arme, +Z haut ; origine sur l'axe du canon, à la face de culasse)

| | Valeur |
|---|---|
| Longueur totale | 0,880 m (cible 0,88) |
| Canon | 0,415 m (bouche avec écrou : x = 0,418) |
| Hauteur avec chargeur | 0,258 m (cible 0,255 ; les oreilles du guidon dépassent de 3 mm pour rester visibles dans la visée) |
| Largeur | 0,080 m avec le levier d'armement (boîtier 0,039 m) |
| Rayon de visée | 0,361 m (cran de hausse → guidon, zéro ≈ 100 m) |
| Course du porte‑culasse | 0,120 m |
| Masse chargée | 3,9 kg |

Silhouette comparée à la photo (redressée de 44°, même largeur) : IoU ≈ 0,89 (≈ 0,91 au meilleur recalage
vertical, 1 mm) (`12_reference_compare.png`). Chargeur, poignée et crosse ont été recalés ligne par ligne sur la photo
(écart ≤ 3 mm sur les bords).

## Matériaux (PBR, construits dans Blender puis cuits)

- Acier bleui ancien (`SteelBlued`) : oxyde bleu‑noir huilé, bronzage aminci en plages grises sur les faces,
  arêtes et points hauts usés jusqu'à l'acier nu argenté, rayures fines, crasse dans les creux (pas de bandes
  d'étui comme sur le pistolet).
- Chargeur (`SteelMag`) : même acier, plus sombre et plus mat, pour qu'il se détache du boîtier.
- Bois (`Wood`, `WoodStock`, `WoodGrip`) : bouleau/noyer verni à la gomme‑laque, brun‑rouge foncé, cernes
  droits irréguliers (débit sur dosse, pas de flammes), pores, zones de prise plus sombres (poignet, poignée, ventre du garde‑main), arêtes cabossées plus
  claires ; le fil suit chaque pièce (garde‑mains le long du canon, crosse le long de son busc, poignée dans son
  axe).

## Fichiers

| Fichier | Contenu |
|---|---|
| `Rifle.fbx` | l'arme, pièces nommées (voir ci‑dessous), UV |
| `Rifle_Mag.fbx` | chargeur plein seul (origine = point `MagWell`) avec sa cartouche du dessus |
| `Rifle_MagEmpty.fbx` | chargeur vide (planchette élévatrice en haut) |
| `Rifle_Case.fbx` | douille 7,62×39 acier laqué percutée |
| `Rifle_Round.fbx` | cartouche 7,62×39 |
| `Rifle_Color/Normal/Roughness/Metalness.png` | atlas 1024 de l'acier (toutes les pièces sauf le bois) et du chargeur |
| `Rifle_Wood_Color/Normal/Roughness/Metalness.png` | atlas 1024 du bois : `Stock`, `PistolGrip`, `HandguardLower`, `HandguardUpper` |
| `Rifle_Ammo_*.png` | atlas 256 de la douille et de la cartouche |
| `rifle.markers.json` | points (marqueurs), charnières, groupes, triangles, collisionneur du chargeur |

Les prises R6 résolues sont dans `tools/guns/rifle_ak_holds.json`.

## Pièces (`Rifle.fbx`)

`Receiver` (boîtier, pontet, goupilles, fenêtre d'éjection), `DustCover` (couvercle lisse), `Barrel` (canon, bloc de hausse, emprunt de gaz et tube à évents, embase de guidon avec oreilles et
tenon de baïonnette, bagues, grenadière avant) avec ses enfants `MuzzleDevice` (écrou de bouche), `SightFront`
(guidon) et `SightRear` (planchette de hausse avec curseur), `CleaningRod` (baguette), `HandguardLower` (avec son collier de retenue en acier),
`HandguardUpper`, `PistolGrip`, `Stock` (pattes de fixation haute et basse, vis de patte, grenadière gauche), `ButtPlate` (plaque de couche avec trappe),
`BoltCarrier` (porte‑culasse, culasse, tige de piston jusque dans le tube à gaz : cachée au repos, visible par
la fenêtre quand le porte‑culasse recule) avec son enfant `ChargingHandle`, `Selector`
(grand levier droit), `Trigger`, `MagRelease` (palette derrière le chargeur), `Magazine` avec ses enfants
`MagRoundTop` (cartouche du dessus) et `MagFollower` (seulement dans le chargeur vide).

Pièces mobiles (pivot = origine de l'objet, aussi dans le JSON) :
- `BoltCarrier` glisse en −X de 120 mm (le levier suit).
- `Selector` tourne autour de +Y à l'arrière : SÛRETÉ 0°, RAFALE +10°, COUP PAR COUP +20° (exporté sur coup par coup) ; les trois crans d'arrêt du boîtier sont exactement sous l'ergot du levier à chaque position.
- `MagRelease` −12° (palette poussée vers l'avant).
- `Magazine` bascule de −25° autour de `MagRockPivot` (ergot avant), puis se libère.
- `Trigger` +14°.
- `SightRear` +8° (la planchette pivote à l'avant ; alias `RearSight`).

## Marqueurs

`Muzzle`, `EjectionPort` (+X = direction moyenne d'éjection : à droite, 35° vers l'avant, 18° vers le haut,
comme une AK), `CasingSpawn`, `MagWell`, `MagRockPivot`, `GripR`, `GripL`, `Shoulder`, `SightEye` (0,28 m
derrière le cran de hausse), `CoM`, `BackMount`, `MagGrab`, `ChargeHandle`, `MagRelease`, `Selector`.

## Triangles

Voir `rifle.markers.json` → `tris`. Arme sans chargeur ≈ 10 400, chargeur + cartouche ≈ 1 300 (total du FBX
≈ 11 700) ; douille 152 ; cartouche 182. Chaque pièce est très en dessous de la limite de 20 000 triangles
d'une MeshPart Roblox (les plus lourdes : `Barrel` ≈ 2 200, `Receiver` ≈ 2 100 avec le marquage gravé). Le contrat de l'architecture visait 8 000 pour
l'arme : on est un peu au‑dessus (goupilles, évents, levier, guidon), dans la fourchette 15–20 k demandée pour
une arme longue.

## Prises R6 (`tools/guns/rifle_ak_holds.json`)

Quatre postures résolues : `Aim` (épaulé, joue sur le busc, œil sur la ligne de mire, inclinaison ≈ 0°),
`Ready`, `LowReady`, `ReloadMag` (arme volontairement inclinée de 20°, main gauche sur le chargeur). Chaque
posture donne la soudure de l'arme dans le bras droit (`weld`), l'arme dans le HRP et le torse, la pose des
articulations et les écarts (`residuals`, dont `cantDeg` = inclinaison de l'arme, `left` = écart de la main
gauche à `GripL` en studs, `eyeToSightLine`).

## Import dans Roblox Studio

1. Importer `Rifle.fbx` en unités **mètres** (comme le lance‑flammes), sans « Anchor » ni rigging. Les pièces
   arrivent nommées comme ci‑dessus.
2. Deux `SurfaceAppearance` :
   - bois : `Rifle_Wood_Color.png` (ColorMap), `Rifle_Wood_Normal.png` (NormalMap), `Rifle_Wood_Roughness.png`,
     `Rifle_Wood_Metalness.png`, dans `Stock`, `PistolGrip`, `HandguardLower`, `HandguardUpper` ;
   - acier : `Rifle_Color.png`, `Rifle_Normal.png`, `Rifle_Roughness.png`, `Rifle_Metalness.png`, dans toutes les
     autres MeshParts (chargeur compris).
3. Ranger le modèle dans `ReplicatedStorage.Assets.Guns.Rifle` ; le jeu l'ajuste lui‑même à partir de
   `Receiver`, `Barrel`, `Trigger` et vérifie `Magazine`. Sans FBX, le jeu garde la version en primitives.
4. Même chose pour `Rifle_Mag.fbx` / `Rifle_MagEmpty.fbx` (atlas acier) et `Rifle_Case.fbx` / `Rifle_Round.fbx`
   (atlas `Rifle_Ammo_*`).
