# Les 4 coups de base (M1) : Motifect → R6

Les 4 coups du combo M1 (`Brawler_M1_1` à `Brawler_M1_4` dans
`src/client/Animation/CombatClips.luau`, communs à tous les kits) viennent maintenant du
**Motifect Combat Motion Pack** (40 animations FBX faites pour Unreal), adaptées au R6.

## Les animations choisies

| Coup | Animation Motifect | Images | Pourquoi |
|---|---|---|---|
| M1_1 jab gauche | `jab_right` **en miroir** (la garde du pack est inversée) | 5 → 23,5, impact 11,2 | Le jab le plus droit et le plus rapide du pack, il part presque dans l'axe. Testé contre `jab_left` : même rendu, mais plus lent à l'impact. |
| M1_2 direct droit | `combo_punch_kick`, 2e direct (haut du corps seulement) | 52 → 74,5, impact 65,7 | Le seul vrai direct du bras arrière : trajet droit, au centre, à hauteur de tête, les hanches lancent le torse. `cross_left` faisait une boucle (lu comme un crochet en R6). |
| M1_3 crochet gauche | `hook_left` (haut du corps seulement) | 14 → 29,7, impact 28,6 | Le crochet le plus rapide : le poing sort puis balaie à hauteur de tête. On coupe le suivi qui s'enroule derrière la tête et on revient en garde. |
| M1_4 finisher | `cross_right` (overhand / haymaker) | 9 → 40, impact 23,7 | Le coup le plus lourd : le bras arrière boucle par le côté, tout le corps tourne, le talon arrière pivote. Même famille que l'ancien M1_4. |

L'ordre des mains reste gauche-droite-gauche-droite : les réactions (`HitJab`, `HitCross`,
`HitHook`, `HitHeavy`) et le côté où la tête part n'ont pas changé.

## Comment c'est adapté au R6
Le R6 n'a ni coude ni genou, et le jeu impose le moment de l'impact (**0,15 s** pour le jab et le
crochet, **0,28 s** et **0,38 s** pour le direct et le coup final, qui sont chargés). Le script :
- vise le **poing** (pas l'os du bras) : le trajet du poing Motifect est recalé pour partir du poing
  de la Garde et arriver au même point d'impact que les anciens coups (dans la hitbox) ;
- reprend la rotation du torse (mise à l'échelle : jab −35°, direct +40°, crochet −49°, finisher +50°),
  une petite fente vers l'avant, la tête qui reste sur la cible, l'autre poing au menton ;
  après l'impact le torse continue de tourner de quelques degrés (2–5°, 14° sur le finisher : le poids
  passe à travers la cible) ;
- garde le crochet à hauteur de tête : son arc s'élargit sur les côtés, mais pas vers le bas ;
- plante les pieds au sol (genou simulé), sans glisser ;
- ajoute une vraie **prise d'élan** avant chaque coup (voir plus bas), puis fait partir le coup en chaîne,
  du bas vers le poing, de plus en plus vite jusqu'au contact ;
- arrête le poing net sur la cible (le hit-stop fige une pose propre), puis le ramène en douceur ;
- commence et finit **exactement** en pose de Garde (le combo s'enchaîne 0,38 s après le jab et le
  crochet, 0,48 s après le direct ; voir plus bas la rotation du torse gardée jusqu'au clic suivant).

## Préparation et transfert de poids
Les boxeurs du pack Motifect ne « télégraphient » presque pas (7° de contre-rotation au plus, le poing
ne recule jamais) : en 0,15 s le bras partait directement. Le script ajoute donc, **par-dessus** la mocap
(réglages `windup` de chaque coup dans `SPECS`) une petite prise d'élan réaliste. C'est ce que font le
**jab et le crochet**. Le direct et le coup final ont maintenant un **grand élan chargé** à la place
(voir « L'élan des coups chargés » plus bas) ; leur impact, leur suivi et leur récupération restent
ceux décrits ici, juste décalés à 0,28 s / 0,38 s.

1. **Préparation (0 → 0,067 s, 4 images)** : le torse tourne à l'envers du coup, le poids descend et
   recule vers la jambe qui charge (les genoux plient), l'épaule recule, le poing revient vers le menton
   (sur un bras R6 rigide, un poing plus près de l'épaule = un coude replié), le menton rentre, l'autre
   poing reste en garde. La pose chargée est presque tenue une image (le poing bouge de 1 à 4 studs/s).
2. **Frappe (0,08 → 0,15 s)** : chaque partie lâche sa charge l'une après l'autre : jambes et poids
   d'abord, puis la rotation du torse, l'épaule, et le bras en dernier. Un bras R6 est un seul bloc : le
   poing ne peut pas « rester derrière » pendant que l'épaule avance (le bras glisserait dans l'épaule).
   Le bras, encore plié, est donc d'abord **porté par le corps qui tourne**, puis il se déplie : pour le
   jab, le direct et l'overhand, le poing est calculé depuis l'épaule (le bras pivote vers la cible et
   s'allonge, de plus en plus vite). La vitesse du poing = celle du corps + celle du bras : elle
   **augmente à chaque image** jusqu'à l'impact, et l'épaule ne glisse pas plus d'environ 0,3 stud par image.
   Le crochet garde son trajet « dehors, puis en travers ».
3. **Après l'impact** : le poing reste sur la cible pendant que le torse continue de tourner de quelques
   degrés et que le poids s'enfonce un peu (rien ne se fige pendant le hit-stop).
4. **Récupération** : le bras revient d'abord, le torse ensuite. Pour M1_1 à M1_3, la rotation du torse
   s'arrête à 7° de la Garde, du côté où le coup est parti, jusqu'à 0,38 s : dans le combo, la prise
   d'élan du coup suivant continue dans ce sens (la fin du jab = l'armé du direct, la fin du direct =
   l'armé du crochet…), donc le torse ne fait plus d'aller-retour au moment du clic. La pose est
   exactement la Garde à la fin du clip.

| Coup | Préparation (pose chargée à 0,05–0,067 s) | Vitesse du poing, 5 dernières images (studs/s) |
|---|---|---|
| Jab (M1_1) | torse 13° à l'envers, épaule avant qui plonge, poing 0,38 stud en arrière, le poids recule vers la jambe arrière | 5 → 12 → 23 → 25 → 29 |
| Direct (M1_2) | remplacé par l'élan chargé (plus bas) | — |
| Crochet (M1_3) | torse enroulé 15° à droite sur la jambe avant, coude et poing écartés et bas | 4 → 8 → 21 → 24 → 39 |
| Finisher (M1_4) | remplacé par l'élan chargé (plus bas) | — |

Tout reste réaliste (amplitudes 1,5 à 2× les vraies, bien en dessous d'un style cartoon). Ce qui ne
change pas pour le jab et le crochet : impact à 0,15 s, durées, ordre des mains, poing au même point
d'impact, pieds au sol.

## Régénérer
```
python3 -m venv venv && venv/bin/pip install bpy numpy scipy
venv/bin/python -I tools/anim/motifect_dump.py <dossier dump> <fichiers .fbx du pack>
venv/bin/python -I tools/anim/motifect_retarget.py <dossier dump> --write
stylua src
```
Les réglages de chaque coup (images, vitesse, point d'impact, rotation…) sont dans `SPECS`, en haut
de `tools/anim/motifect_retarget.py`. Ne modifie pas les images clés à la main : relance le script.

## Ce qui n'a PAS changé
Les coups des kits (Street Brawler, Boxer, Bouncer, Sentinel, Rift), la Garde, le blocage, les
réactions, les VFX, les sons, les dégâts, les hitbox et les timings de `Config`
(à l'époque `HIT_DELAY` 0,15 s, `M1_INTERVAL` 0,38 s). Seuls les 4 blocs `Brawler_M1_N` ont été remplacés.

## Coups chargés (direct du droit et coup final)
Les deux coups du bras droit prennent un grand élan (le bras part vers le dos), donc ils touchent
plus tard. Les timings sont maintenant **par coup** dans `Config.Combat` :

| Coup | Impact (`M1_HIT_DELAY`) | Coup suivant possible (`M1_INTERVAL` / `FINISHER_RECOVERY`) |
|---|---|---|
| 1 jab (gauche) | 0,15 s | 0,38 s |
| 2 direct (droit, chargé) | 0,28 s | 0,48 s |
| 3 crochet (gauche) | 0,15 s | 0,38 s |
| 4 coup final (droit, chargé) | 0,38 s | 1,23 s (toujours 0,85 s après l'impact) |

- Le « whoosh » du coup part 0,15 s avant l'impact (`M1_SWING_LEAD`) : tout de suite pour le jab et
  le crochet, après l'élan pour les coups chargés.
- Le combo reste inévitable : quand tu lances le coup suivant, la victime du coup d'avant reste
  sonnée jusqu'à l'impact + 0,1 s (`COMBO_HOLD_MARGIN`).
- Hors combo, un coup chargé se voit venir : l'adversaire peut le couper avec un jab, l'esquiver
  (dash) ou le bloquer / parer (surtout le coup final).

## L'élan des coups chargés (animation)
Tu voulais qu'il **charge** son coup : le bras part presque derrière, au niveau du dos, comme une grosse
prise d'élan, mais animé. C'est fait sur les deux coups du bras droit, par-dessus la mocap Motifect
(l'impact, le suivi et la récupération restent ceux de Motifect, décalés plus tard). Le jab et le crochet
n'ont pas changé (leurs blocs sont identiques à l'octet près).

| | Direct (M1_2) | Coup final (M1_4) |
|---|---|---|
| Où part le poing | le bras descend le long de la hanche puis part en arrière : poing **derrière le dos**, à hauteur de la taille | le bras monte sur le côté puis en arrière : poing **derrière la tête** |
| Torse enroulé (Garde −12°) | −66° (54° plus loin que la Garde) | −76° (64°), penché en arrière |
| Poids | descend de 0,24 stud sur la jambe arrière pliée | descend de 0,17 stud, en arrière |
| Main avant | reste devant le visage | vise l'adversaire (comme un lanceur), puis revient à la poitrine |
| Élan (bras en arrière) | 0 → 0,15 s | 0 → 0,20 s |
| Charge tenue | 0,15 → 0,18 s (2 images, le corps s'enroule encore un peu) | 0,20 → 0,263 s (4 images) |
| Frappe | 0,18 → **0,28 s** : jambes et poids, puis torse, puis bras | 0,263 → **0,38 s** : le bras fait une boucle sur le côté puis tombe sur la cible |
| Vitesse du poing, 5 dernières images (studs/s) | 28 → 55 → 92 → 141 → 146 | 34 → 62 → 102 → 154 → 155 |
| Retour en Garde | ~0,45 s (le crochet part à 0,48 s) | ~0,9 s |
| Durée du clip | 0,6 s | 1,08 s |

- La frappe **accélère jusqu'au contact** (jamais de ralenti avant l'impact). Les 2 dernières images
  sont très rapides (le bras tourne de 60 à 78° par image) : c'est le côté « animé », l'œil le lit comme
  un flou de mouvement. Une traînée VFX sur ces 2 images marcherait bien.
- Tout le reste reste humain : pendant l'élan le bras tourne de 30 à 40° par image au plus, la charge
  tenue bouge de moins de 4 studs/s, les pieds restent au sol (le pied arrière pivote pendant la frappe).
- Sur le coup final, quand le bras est armé derrière la tête, le haut du bras passe un peu dans le coin
  arrière du torse (limite des épaules R6) : on le voit comme un bras derrière l'épaule.
- Réglages : `CROSS_CHARGE` et `FINISHER_CHARGE` en haut de `tools/anim/motifect_retarget.py`
  (les poses clés de l'élan, le chemin du bras pendant la frappe, l'ordre de départ de chaque partie
  du corps). Relance le script avec `--write`, puis `stylua src`.
