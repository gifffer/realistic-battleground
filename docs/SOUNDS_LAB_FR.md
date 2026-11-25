# Sons de l'appartement, du labo et de l'extraction (v1)

Première version complète, à écouter en jeu : dis-moi ce qu'il faut enlever ou changer.

Tous les sons viennent du Creator Store (presque tous **ProSoundEffects** ou **Roblox**, gratuits, rien à uploader). Chacun a été téléchargé et mesuré (durée, volume réel, boucle propre). Les volumes sont réglés pour que tout parte équilibré.

## Où c'est dans le code

| Fichier | Rôle |
|---|---|
| `src/shared/Sounds.luau`, section **Contraband** | La liste des sons : ids, volume, pitch, découpes (`trims`). **C'est le seul fichier à toucher pour changer un son.** |
| `src/client/Contraband/AptAudio.luau` | Le moteur : les 2 fonds sonores 2D, les boucles 3D, l'étouffement à travers les murs, la réverb par pièce. |
| `src/client/Controllers/ApartmentAmbienceController.luau` | Quand et où chaque son joue (pièces, portes, gouttes, étincelle, grincements…). Les positions de secours sont dans `SFX_HOSTS`. |
| `src/client/Controllers/ExtractionController.luau` | Les sons de l'extraction (joués sur sa propre timeline). |
| `src/client/Controllers/CityAudioController.luau` | Une seule ligne ajoutée : la musique de rue et la pluie se coupent dans l'appartement. |

## Comment ça sonne

- **Fond par pièce (2D)** : deux nappes mélangées différemment selon la pièce, en fondu de 0,8 s quand tu changes de pièce. `AptEntranceTone` (grondement grave de l'immeuble) et `AptCorridorTone` (la ville la nuit, étouffée, comme entendue à travers les murs).

| Pièce | Grondement | Ville | Réverb |
|---|---|---|---|
| Entrée | 100 % | 30 % | Hallway |
| Salon + cuisine | 80 % | 70 % (fenêtre) | LivingRoom |
| Couloir | 50 % | 100 % | CarpettedHallway |
| Salle de bain | 40 % | 60 % | Bathroom |
| Chambre 2 | 50 % | 70 % | Room |
| Labo | 40 % | 0 % | Room |

- **Sons 3D** : ils viennent d'un point précis (plus fort quand tu es près, dans la bonne direction).
- **Étouffement** : un son d'une autre pièce perd ses aigus, comme à travers un mur. Le labo entendu du couloir porte grande ouverte n'est que légèrement étouffé. Les voisins le sont toujours.
- **Pendant l'extraction** : les fonds baissent à 60 % et le bourdonnement du néon à 70 %, pour que les sons de l'extraction passent devant.
- **Dehors** : la musique de rue et la pluie s'éteignent en douceur quand tu entres et reviennent quand tu sors.

## Liste des sons

### L'appartement

| Nom (`Sounds.luau`) | Ce que c'est | Où / quand | Id(s) |
|---|---|---|---|
| `AptEntranceTone` | Grondement lent de l'immeuble (boucle) | 2D, fond de toutes les pièces | 9112775375 |
| `AptCorridorTone` | La ville la nuit à travers les murs (boucle) | 2D, surtout dans le couloir | 9112759541 |
| `AptNeighbours` | Fête des voisins à travers le mur, voix inintelligibles (boucle) | 3D derrière le mur est de l'entrée, toujours étouffé | 9112760276, 9113851615 |
| `AptBuildingCreak` | Craquements, tuyau qui vibre | 3D au plafond, au hasard toutes les 20–45 s, à au moins 8 studs de toi | 9113135641, 9117659573 |
| `FloorCreak` | Latte de parquet qui grince | 3D sous tes pieds (couloir, chambre 2, salon) : 30 % de chance tous les 2,5–5 studs marchés, jamais 2 fois en moins de 2,5 s | 9114493461, 9114493393, 9114493656, 9114493567 |
| `LightSwitch` | Clic d'interrupteur | 3D à la porte condamnée de la chambre 3, quand la lumière dessous s'allume ou s'éteint (étouffé) | 9116283546, 9120484192 |
| `PlasticSheetBrush` | On traverse le rideau de lanières en plastique | 3D au rideau, une fois par passage | 9113606679, 9113606680 |
| `LabRevealDrone` | Montée grave et inquiétante | 2D, la première fois que tu entres dans le labo à chaque visite (pas 2 fois en 5 min) | 9125400975 |

### Portes et appareils

| Nom | Ce que c'est | Où / quand | Id(s) |
|---|---|---|---|
| `AptDoorUnlock` | Clé, verrou | 3D à la porte d'entrée, à l'arrivée | 9114144071, 9116168670 |
| `AptDoorClose` | Porte qui se ferme | 3D à la porte d'entrée, 0,45 s après le verrou | 9114829600 |
| `AptDoorOpen` | Porte en bois qui grince en s'ouvrant | 3D à la porte qui s'ouvre (salle de bain, chambre 2, labo), pitch propre à chaque porte | 9120839364, 9120838740 |
| `AptDoorLocked` | Poignée secouée, ça ne s'ouvre pas | 3D aux portes fermées (chambres 1 et 3), sur « Try » | 9120839581, 9114129572 |
| `FridgeOpen` / `FridgeClose` | Vieux frigo qu'on ouvre / ferme | 3D au frigo de la cuisine | 365549814 / 365572712 |
| `FreezerLidOpen` / `FreezerLidClose` | Couvercle du congélateur (0,8 s entre les deux) | 3D au congélateur du labo, quand une capsule entre ou sort du stash | 9114531382 / 9117526627, 9117534186 |

### Le labo

| Nom | Ce que c'est | Où / quand | Id(s) |
|---|---|---|---|
| `VatHum` | Transformateur de la cuve (boucle) | 3D à la cuve, audible faiblement et étouffé dès le coude du couloir (jusqu'à 40 studs) | 9112889082 |
| `LabFluoBuzz` | Bourdonnement de néon (boucle) | 3D au néon du labo, et plus bas à l'ampoule du couloir ; il se tait quand la lumière meurt | 9112823813, 9112823811 |
| `LabFluoFlicker` | Grésillement d'une lumière qui saute | 3D à la lumière, à chaque saute (ampoule du couloir, néon du labo, miroir de la salle de bain) | 115768564143330 |
| `LabFridgeHum` | Ronronnement de frigo (boucle) | 3D au frigo de la cuisine, au frigo du labo et au congélateur (plus grave) | 125605115496003 |
| `LabPumpBubble` | Pompes d'aquarium qui bullent (boucle) | 3D à l'étagère des pompes | 9125410132 |
| `LabDrip` | Goutte | 3D au seau du couloir et au bac du labo (synchro avec la goutte visible), au robinet de la salle de bain (toutes les 4–10 s) | 9120510269, 9120511536 |
| `LabSpark` | Petit arc électrique (**nouveau**) | 3D à la multiprise brûlée, avec l'étincelle (toutes les 45–120 s, jamais pendant une extraction) | 9114237693 |
| `VatBubbleSurge` | Grosses bulles qui remontent | 3D à la cuve : quand tu lances une culture, puis à 25 % et 75 % si tu es là | 9120559955, 9120494621, 9120559328 |
| `VatReadyChime` | Bip de moniteur, 2 fois | 3D à l’écran de la cuve (sur pied, devant la cuve) quand la culture devient PRÊTE (le seul signal sonore dans le labo : le HUD y est caché) | 9113880400 |

### L'extraction (2D, toi seul)

| Nom | Moment | Id(s) |
|---|---|---|
| `ScalpelPickup` | La main prend le scalpel (tintement d'acier) | 9116902317 |
| `ScalpelSkin` | La lame passe la peau (toutes les 3 cellules) | 138772034497598, 72475389234606, 100089328974443 |
| `ScalpelMembrane` | La lame passe la membrane (chaque cellule, humide) | 71972357334329 |
| `ScalpelPress` | Lame immobile : un cran plus profond | 9125619646 |
| `ScalpelSkid` | La lame dérape / raye hors de la couture | 9116902704 |
| `SeamPop` | La membrane est ouverte | 9126209045, 9113266090 |
| `PanelStretch` | Un panneau tiré (boucle, le pitch suit l'ouverture) | 9118744344 |
| `RetractorClick` | L'écarteur se clipse sur le panneau | 9125921369 |
| `PanelsOpen` | Les panneaux s'ouvrent | 9120627864, 9120627902 |
| `ColdBreath` | Souffle froid qui sort | 9116495722 |
| `ScanLock` | L'écran verrouille la lecture d'un élément | 9119973132 |
| `CorePickup` | On commence à tirer un élément | 9120646567 |
| `ElementStrain` | L'élément résiste (boucle) | 9118744344 |
| `ElementRelease` | Il se détache | 9113537815, 9119669074 |
| `ElementCrumble` | Une husk s'effrite | 9117088526, 9117206088 |
| `MilkDrip` | Une perle laiteuse tombe | 9113464190, 9113464198 |
| `TraySet` | L'élément posé sur l'acier | 94238955194144 |
| `HatchOpen` | Le couvercle de la boîte froide s'ouvre (pneumatique) | 9125560652 |
| `GrateSlide` | La grille s'écarte / se referme, le volet du puits | 9116902704 |
| `CapsuleDrop` | L'élément tombe dans la capsule | 2053476174 |
| `CarouselTurn` | Le carrousel tourne | 9119717529 |
| `HatchClose` | Le couvercle se ferme | 9117526627 |
| `CapsuleSeal` + `CapsuleHiss` | Bouchon de capsule + chuintement | 9125921369 + 9125560652 |
| `SealFrost` | Givre sur la capsule | 9125611419 |
| `TimerLow` | Les 4 dernières secondes | 9119193999 |
| `ToolTraySetDown` | Le scalpel reposé, la coque posée sur le chariot | 9116902704, 9116902317 |
| `ChuteSlide` | La coque dans la goulotte | 16480576087 |
| `UiSelect` / `UiConfirm` / `UiCancel` / `UiError` | Survol, DONE, Stop, refusé | 15675032796 / 15675059323 / 15675075163 / 9113880475 |

Les sons de la mallette (`Case…`) ont aussi reçu leurs ids ; ils jouent comme avant.

## Changer un son

1. Trouve un son sur le **Creator Store** (onglet Audio). Copie le nombre de son lien (`.../store/asset/`**`1234567890`**`/...`).
2. Ouvre `src/shared/Sounds.luau`, cherche le nom du son (ex. `LabDrip`) et remplace le nombre dans `ids = { ... }`. Tu peux en mettre plusieurs : un est tiré au hasard à chaque fois, jamais deux fois le même de suite.
3. Si le nouveau son a un blanc au début ou n'est pas au même volume, enlève sa ligne dans `trims` (ou ajuste `start` = secondes à sauter, `gain` = multiplicateur de volume).
4. Règle `volume` (0 → 10) et `pitch` (1 = normal, 0,8 = plus grave). `length` / `fadeOut` coupent un long fichier.
5. Rojo synchronise, Play, va écouter dans l'appartement.

- **Couper un son** : mets `ids = {}`. Le jeu le saute sans erreur.
- **Changer où il joue** : les positions sont les pièces invisibles `Sfx` de l'appartement (LabBuilder), avec leurs attributs `Slot`, `Zone`, `Min`, `Max`, `Volume`.
- **Changer quand il joue** : les rythmes (gouttes, étincelle, grincements) sont en haut de `ApartmentAmbienceController.luau`.

## À décider (en jouant)

- **Voisins** : le fichier source contient des gros mots ; on ne comprend rien à travers le mur. Garder ou enlever ? (Pour enlever : `AptNeighbours`, `ids = {}`.)
- **Réverb du labo** : `Room` aujourd'hui ; essayer `PaddedCell` pour l'effet bâche plastique (`ROOM_MIX` dans `AptAudio.luau`).
- **Drone d'entrée dans le labo** : une fois par visite (pas 2 fois en 5 min). Le garder à chaque visite ou seulement la première fois ?
- **Pas encore mis** (proposés pour plus tard) : bourdonnement de mouche (la mouche près de l'évier est muette), télé des voisins, coups dans les tuyaux, chasse d'eau lointaine.
