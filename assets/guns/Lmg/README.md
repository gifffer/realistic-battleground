# 5.56 LMG — la mitrailleuse légère à bande (type M249 / Minimi « para »)

Modèle procédural (Blender, `tools/guns/lmg.py` + la boîte à outils partagée `tools/guns/gunkit.py`).
Mitrailleuse légère alimentée par bande en 5,56×45, d'après la photo de référence : boîtier en tôle emboutie
phosphatée (plaques de renfort embouties avec nervure, rivets, deux grandes goupilles de démontage, plaque de
marquage générique `RB-24581` / `CAL 5.56 NATO`), couvercle d'alimentation embouti creux à charnière AVANT
(levier d'alimentation, griffes et guides dessous) portant un rail et une lunette prismatique 4× sur une embase
rehaussée de 15 mm, plateau d'alimentation dans un puits ouvert, fenêtre d'alimentation dans la paroi gauche,
fenêtre d'éjection des douilles SOUS le boîtier (à droite de l'axe), fenêtre des maillons à droite (volet ouvert),
levier d'armement non solidaire à droite, carcasse de détente polymère avec grand pontet et poignée‑pistolet,
canon à changement rapide avec poignée de transport, bloc de gaz, guidon à oreilles, cache‑flamme à fentes,
garde‑main aluminium (rail en haut, couvre‑rails polymère sur les côtés comme sur la photo) avec **poignée
verticale** sous le rail inférieur, cylindre de gaz, **bipied à pivots inclinés** (jambes repliées vers l'arrière
de part et d'autre de la poignée verticale, qui descendent ET s'écartent de 22° en se dépliant), crosse
télescopique à un tube avec busc et talon plein, plaque de couche caoutchouc, et le **sac de 200 cartouches en
forme de tambour** (cordura camouflage numérique, faces bombées, bord arrondi profond, ganse sombre sur les deux
coutures, sangle de compression, panneau MOLLE, adaptateur polymère accroché sous le boîtier) d'où la bande
monte à la verticale, À L'EXTÉRIEUR de la paroi gauche, jusqu'au plateau. Aucun logo, aucune marque, aucun
marquage copié.

Planche de rendus : `lmg_sheet.png` ; prises R6 résolues : `lmg_holds.png` (les 10 postures).

## Dimensions (réelles, mètres ; axes : +X bouche, +Y gauche de l'arme, +Z haut ; origine sur l'axe du canon, à la face de culasse)

| | Valeur |
|---|---|
| Longueur totale | 0,894 m crosse sortie (cible 0,89) ; 0,794 m crosse rentrée |
| Canon | 0,349 m (bouche du cache‑flamme : x = 0,395) |
| Hauteur | 0,279 m du haut de la poignée de transport au bas de la poignée‑pistolet (cible 0,28, sans lunette, sac ni bipied) |
| Hauteur totale | 0,353 m avec la lunette et le sac ; largeur 0,154 m (le sac déborde à gauche) |
| Axe de visée au‑dessus de l'âme | 0,095 m (rail du couvercle + embase rehaussée de 15 mm, voir « Prises ») |
| Bipied déplié | pieds écartés de 213 mm, 257 mm sous l'âme (sous le bas du sac) |
| Sac | tambour Ø 170 mm × 88 mm, centré 46 mm à gauche de l'axe |
| Course du levier d'armement | 0,140 m |
| Pas de la bande (maillons type M27) | 10,2 mm |
| Masse | 7,1 kg + 3,0 kg le sac plein (10,1 kg dans le JSON) |

## Fichiers

| Fichier | Contenu |
|---|---|
| `Lmg.fbx` | l'arme, 24 pièces nommées (voir ci‑dessous), UV, **toutes triangulées** avant la cuisson (les tangentes de Roblox correspondent à la normal map) ; SANS la bretelle |
| `Lmg_Pouch.fbx` | le sac plein seul (origine = point `PouchMount`) |
| `Lmg_PouchEmpty.fbx` | le sac vide, affaissé (≈ 55 % de la hauteur, le haut replié vers l'extérieur, faces enfoncées, rabat ouvert ; ses propres UV dans l'atlas `Lmg_Soft`) |
| `Lmg_Sling.fbx` | la bretelle au repos, pendante sous l'arme (origine = `SlingFront`) ; en jeu la sangle est tendue entre `SlingFront` et `SlingRear` |
| `Lmg_BeltSegment.fbx` | un bout de bande de 10 cartouches |
| `Lmg_Link.fbx` | un maillon seul (éjecté à droite à chaque tir) |
| `Lmg_Case.fbx` | douille 5,56 laiton percutée (éjectée vers le bas) |
| `Lmg_Round.fbx` | cartouche 5,56 |
| `Lmg_Color/Normal/Roughness/Metalness.png` | atlas 1024 : métal, polymère, lunette, bipied |
| `Lmg_Soft_*.png` | atlas 1024 des tissus : `AmmoPouch` (= `Lmg_Pouch`), `Lmg_PouchEmpty`, `Lmg_Sling` |
| `Lmg_Ammo_*.png` | atlas 512 : `Belt01`…`Belt12`, douille, cartouche, maillon, bout de bande |
| `lmg.markers.json` | points, charnières, groupes, triangles, collisionneur du sac |

**Attention : les 12 textures `Lmg_*` ont été recuites (nouvelle géométrie, nouvelles UV).** Les identifiants
Roblox de `assets/guns/texture_ids.json` pour le LMG pointent vers les ANCIENNES images : il faudra re‑téléverser
ces 12 PNG au moment de l'import et remplacer leurs identifiants.

## Pièces (`Lmg.fbx`) et triangles (11 708 au total, cible 12 000)

| Pièce | Triangles | Rôle |
|---|---|---|
| `Receiver` | 3 918 | boîtier, tourillon, carcasse de détente, poignée‑pistolet, pontet, hausse, garde‑main et rails, **poignée verticale**, cylindre de gaz, chape du bipied, anneau de bretelle (pièce d'ajustement 1) |
| `Barrel` | 1 562 | canon, collier, poignée de transport, bloc de gaz, guidon, cache‑flamme (ajustement 2) |
| `FeedCover` → `Optic` → `OpticLens` | 966 + 1 072 + 172 | couvercle (charnière avant) portant la lunette |
| `FeedTray` | 244 | plateau |
| `Stock` | 730 | crosse télescopique |
| `Trigger` | 224 | détente (ajustement 3) |
| `ChargingHandle` | 232 | levier d'armement |
| `BipodLegL`, `BipodLegR` | 176 + 176 | jambes du bipied |
| `AmmoPouch` | 1 096 | sac tambour (pièce d'ajustement 4, vérifiée) |
| `Belt01`…`Belt12` | 12 × ≈ 96 | la bande (cartouche 6 pans lissée par les normales + maillon) |

Modèles séparés : douille 114, cartouche 156, maillon 156, bout de bande 948, sac plein 1 096, sac vide 1 084,
bretelle 664.

Pièces mobiles (pivot = origine de l'objet, aussi dans le JSON `hinges`) :
- `FeedCover` 0 → +70° autour de +Y (charnière AVANT, l'arrière se lève) ; la lunette suit.
- `FeedTray` 0 → −20° (charnière arrière).
- `ChargingHandle` recule de 140 mm (−X).
- `Stock` 0 = sortie (exportée), +100 mm (+X) = rentrée.
- `BipodLegL/R` 0 → −90° autour d'un axe **incliné** : +Y penché de 22° vers ±Z, pivots à y = ±21 mm (axe et
  pivot exacts de chaque jambe dans le JSON ; amendement du contrat §5.2). Repliées, les jambes longent le
  garde‑main de part et d'autre de la poignée verticale ; dépliées, elles descendent et s'écartent.
- `Trigger` +12°.
- `AmmoPouch` se décroche vers le bas (40 mm) puis tombe librement ; à l'arrêt, remplacé par `Lmg_PouchEmpty`.
- `Belt01`…`Belt12` affichées ou cachées selon les cartouches restantes ; `Belt01` est sur le plateau (la
  prochaine tirée), `Belt12` plonge dans l'embouchure du sac.

## Marqueurs

`Muzzle`, `EjectionPort` (+X = éjection moyenne : VERS LE BAS, 10° vers l'avant, 28° vers la droite ; son +Z est
la normale de la fenêtre ré‑orthogonalisée contre +X), `CasingSpawn`, `LinkPort` / `LinkSpawn` (maillons à droite,
10° vers le bas), `FeedTrayEntry`, `PouchMount`, `GripR`, `GripL` (**sur la poignée verticale**, mi‑hauteur ;
+Z = direction neutre de l'avant‑bras gauche), `Shoulder`, `SightEye` (38 mm derrière l'oculaire), `CoM`,
`BackMount`, `ChargeHandle`, `FeedCoverLatch`, `CarryHandle`, `SlingFront` / `SlingRear`, `BipodPivot`,
`BipodFoot` (pied gauche déplié), et pour le solveur `BeltGrab` et `PouchGrab`.

Douilles : le script vérifie à chaque génération (`check_case_sweep`, 500 tirages selon l'architecture §10 :
direction ±12°, 1–2 m/s ±15 %, rotation 10–20 tr/s, 0,15 s) que les douilles qui tombent ne traversent pas le
sac : centre jamais, extrémités 1,2 % des cas (le bord du tambour effleuré).

Collisionneur du sac (`colliders.AmmoPouch`) : un cylindre selon +Y (rayon 0,088 m, longueur 0,094 m), donné dans
les **axes du modèle de l'arme** (pas dans le repère du marqueur `PouchMount`), centre = `PouchMount` + `center`.

## Prises R6 (`tools/guns/lmg_holds.json`, toutes « ok »)

`Aim`, `Ready`, `HighReady`, `LowReady`, `HipCarry`, `SprintCarry`, `ObstructedHigh`, `ObstructedLow`,
`BeltReload` (couvercle ouvert), `Bipod` (bipied posé sur un rebord). Main gauche sur la poignée verticale
partout sauf `BeltReload` (sur la bande) ; écart main gauche ≤ 0,07 stud et angle ≤ 30° (limite 35–50°, plus
aucune limite relevée pour faire passer un résultat) ; poignet droit ≤ 24°. `Aim` : tête inclinée de −12°
(−23° avant), œil à 0,074 stud de l'axe de visée et 6,5 cm en arrière du point d'œil de la lunette ; `Bipod` :
−14°, 0,081 stud. Avec la tête R6 (un cube de 0,34 m) et l'œil haut sur la tête, une lunette basse oblige la
tête à plonger : c'est pourquoi l'embase a été REHAUSSÉE de 15 mm (et non abaissée).

## Import dans Roblox Studio (plus tard, en une seule séance)

1. Importer `Lmg.fbx` en unités **mètres**, sans « Anchor » ni rigging. Les pièces arrivent nommées comme ci‑dessus.
2. Téléverser les 12 PNG `Lmg_*` (recuits, voir l'avertissement plus haut) et créer trois `SurfaceAppearance` :
   - tissus : `Lmg_Soft_Color/Normal/Roughness/Metalness` dans `AmmoPouch` (et `Lmg_PouchEmpty`, `Lmg_Sling`) ;
   - munitions : `Lmg_Ammo_*` dans `Belt01`…`Belt12` (et douille, cartouche, maillon, bout de bande) ;
   - métal : `Lmg_*` dans toutes les autres MeshParts. `OpticLens` peut garder un matériau `Glass`.
3. Ranger le modèle dans `ReplicatedStorage.Assets.Guns.Lmg` ; le jeu l'ajuste à partir des centres de
   `Receiver`, `Barrel`, `Trigger` et vérifie `AmmoPouch`. Sans FBX, le jeu garde la version en primitives.
4. Même chose pour `Lmg_Pouch.fbx` / `Lmg_PouchEmpty.fbx` / `Lmg_Sling.fbx` (atlas `Lmg_Soft_*`) et
   `Lmg_Case.fbx`, `Lmg_Round.fbx`, `Lmg_Link.fbx`, `Lmg_BeltSegment.fbx` (atlas `Lmg_Ammo_*`).
5. Les jambes du bipied tournent autour de l'axe donné dans le JSON (incliné), pas autour de +Y.

## Régénérer

```
/home/user/z-anatomy/venv/bin/python -I tools/guns/lmg.py --out DOSSIER [--samples 32] [--quick] \
    [--only 01,07] [--no-bake] [--no-holds] [--no-render] [--no-export] [--ref photo.png]
```
