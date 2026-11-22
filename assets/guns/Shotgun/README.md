# 12-GAUGE TACTICAL — le fusil à pompe semi-automatique

Modèle procédural (Blender, `tools/guns/shotgun.py` + la boîte à outils partagée `tools/guns/gunkit.py`).
Fusil semi-automatique à emprunt de gaz, calibre 12, magasin tubulaire prolongé 7 + 1. Dessin original
inspiré de la photo de référence : aucun logo, aucune marque, aucun marquage copié.

Planche de rendus : `shotgun_sheet.png` ; prises R6 résolues : `shotgun_holds.png`.

## Dimensions (réelles, mètres ; axes : +X bouche, +Y gauche de l'arme, +Z haut ; origine sur l'axe du canon, à la face de culasse)

| | Valeur |
|---|---|
| Longueur totale | 0,980 m (cible 0,98) |
| Canon | 0,470 m (18,5 po) + choke à évents jusqu'à 0,474 m |
| Hauteur | 0,204 m avec le point rouge (cible du contrat : 0,20 m avec l'optique), 0,186 m sans |
| Largeur | 0,057 m (anneau de bretelle compris), boîte de culasse 0,031 m |
| Course de la culasse | 0,075 m (reste ouverte sur magasin vide) |
| Capacité | 7 cartouches dans le tube + 1 chambrée |
| Masse chargée | 3,6 kg |

Silhouette de profil comparée à la photo : IoU 0,920 (`12_reference_compare.png` dans les rendus).

## Fichiers

| Fichier | Contenu |
|---|---|
| `Shotgun.fbx` | l'arme, 19 pièces nommées, UV d'atlas |
| `Shotgun_Round.fbx` | cartouche chargée rouge (65 mm, sertissage en étoile, culot laiton), 192 triangles, 12 pans lissés |
| `Shotgun_RoundGreen.fbx` | la même en vert, 192 triangles |
| `Shotgun_Case.fbx` | douille tirée (70 mm, sertissage ouvert, amorce percutée), 144 triangles |
| `Shotgun_Color/Normal/Roughness/Metalness.png` | atlas 1024 de l'arme (SurfaceAppearance) |
| `Shotgun_Ammo_*.png` | atlas 256 des cartouches |
| `shotgun.markers.json` | points, charnières, groupes, triangles, capacité |

Les prises R6 résolues sont dans `tools/guns/shotgun_holds.json`.

## Pièces (`Shotgun.fbx`)

`Receiver` (aluminium anodisé noir, fenêtre d'éjection, fenêtre de chargement en dessous ouverte jusqu'au
logement de culasse), `Barrel` (canon lourd, face de culasse polie et entrée de chambre chanfreinée, choke), `SightFront` (guidon fibre rouge),
`MagTube` (tube et écrou de garde-main rainuré), `MagCap` (bouchon et anneau de bretelle avant),
`BarrelClamp` (collier canon-tube, vis, prise QD), `Forend` (garde-main polymère, panneaux granités et
rainures), `Stock` (crosse polymère avec poignée pistolet, panneaux granités, grenadière arrière),
`RecoilPad` (plaque de couche caoutchouc ; nervures dans la texture), `TriggerGuard`, `Trigger`, `Safety` (sûreté de queue de
culasse), `Bolt` (culasse nickelée satinée, rainures sombres et extracteur bronzé côté droit) avec son enfant
`ChargingHandle` (levier d'armement), `Lifter` (élévateur, au repos à fleur dans la fenêtre de chargement),
`BoltRelease` (bouton d'arrêtoir), `Optic` (point rouge ouvert) avec son enfant `OpticLens`, `Pins`.

Pièces mobiles : `Bolt` recule en −X de 75 mm (le levier suit) ; `BoltRelease` +Y de 3 mm ; `Lifter` +12°
autour de −Y, pivot à l'arrière (l'avant MONTE et présente la cartouche à la chambre ; il ne sort jamais de la
boîte de culasse, vérifié par `check_lifter` à chaque build) ; `Trigger` +12° ; `Safety` +X de 5 mm (SÛRETÉ →
FEU, sûreté de queue de culasse comme la photo ; le contrat ARCHITECTURE §5.2 a été amendé en ce sens).

## Marqueurs

`Muzzle`, `EjectionPort` (+X = éjection : droite, 10° vers l'avant, 20° vers le haut), `CasingSpawn`,
`ShellPort` (+X = sens de poussée d'une cartouche dans le tube), `LoadingPort` (centre de la fenêtre de
chargement), `PortLoad` (chargement direct dans la fenêtre d'éjection, culasse ouverte), `GripR`, `GripL`,
`Shoulder`, `SightEye` (0,20 m derrière le point rouge, ligne de visée réglée à 25 m), `CoM`, `BackMount`,
`ChargeHandle`, `BoltRelease`, `Safety`, `SlingFront`, `SlingRear`, `MagCap`.

## Prises R6 résolues

Épaulé (Aim, Ready, LowReady) : crosse dans le creux de l'épaule (posée dans le haut du bloc du bras droit,
le bras R6 rigide ne permet pas de la reculer davantage), garde-main posé sur le bout du bloc du bras gauche
(point de main d'appui (0, −0,92, −0,35)), tête à moins de 15° de roulis et 20° d'inclinaison, pieds au sol.
En visée : œil à 0,019 stud de la ligne de visée, tête inclinée de 6,5°, 80 % de l'arme visible de 3/4 avant.
Recharge cartouche par cartouche (ReloadShell : arme descendue au ventre, crosse sous l'aisselle droite,
tournée ventre vers l'extérieur à 75°, le pouce pousse une cartouche à moitié entrée) et chargement par la
fenêtre d'éjection (PortLoad, culasse ouverte, arme tournée de −30°). Main gauche à moins de 0,03 stud de sa
cible dans toutes les prises. Données : `tools/guns/shotgun_holds.json`.

## Triangles

Arme complète 7 341 (budget du contrat : 8 000 ; plus grosse pièce : `Stock` 1 220, très loin de la limite
Roblox de 20 000 par maillage) ; cartouche 192 ; douille 144. Les petits détails (vis, évents, moletages,
nervures de la plaque de couche) sont dans les textures cuites.

## Import dans Roblox Studio

1. Importer `Shotgun.fbx` en unités **mètres** (comme le lance-flammes), sans « Anchor » ni rigging. Les
   pièces arrivent nommées comme ci-dessus.
2. Créer une `SurfaceAppearance` avec `Shotgun_Color.png` (ColorMap), `Shotgun_Normal.png` (NormalMap),
   `Shotgun_Roughness.png` (RoughnessMap), `Shotgun_Metalness.png` (MetalnessMap), et la copier dans chaque
   MeshPart (elles partagent le même atlas).
3. Ranger le modèle dans `ReplicatedStorage.Assets.Guns.Shotgun` ; le jeu l'ajuste à partir de `Receiver`,
   `Barrel`, `Trigger` et vérifie `MagTube`. Sans FBX, le jeu garde la version en primitives.
4. Même chose pour les cartouches (`Shotgun_Round*.fbx`, `Shotgun_Case.fbx`, atlas `Shotgun_Ammo_*`).
