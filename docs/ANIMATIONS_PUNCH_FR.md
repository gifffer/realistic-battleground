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
Le R6 n'a ni coude ni genou, et le jeu impose l'impact à **0,15 s**. Le script :
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
- commence et finit **exactement** en pose de Garde (le combo s'enchaîne toutes les 0,38 s ; voir
  plus bas la rotation du torse gardée jusqu'au clic suivant).

## Préparation et transfert de poids
Les boxeurs du pack Motifect ne « télégraphient » presque pas (7° de contre-rotation au plus, le poing
ne recule jamais) : en 0,15 s le bras partait directement. Le script ajoute donc, **par-dessus** la mocap
(réglages `windup` de chaque coup dans `SPECS`) :

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
| Direct (M1_2) | torse 16° à l'envers, poing 0,5 en arrière près du menton, poids au centre puis rotation complète | 13 → 19 → 26 → 33 → 36 |
| Crochet (M1_3) | torse enroulé 15° à droite sur la jambe avant, coude et poing écartés et bas | 4 → 8 → 21 → 24 → 39 |
| Finisher (M1_4) | la plus grosse charge : torse 21° à l'envers, poids bas et en arrière, poing armé près de l'oreille, puis le bras passe par-dessus et redescend sur la cible | 13 → 21 → 30 → 33 → 35 |

Tout reste réaliste (amplitudes 1,5 à 2× les vraies, bien en dessous d'un style cartoon). Ce qui ne
change pas : impact à 0,15 s, durées, ordre des mains, poing au même point d'impact, pieds au sol.

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
(`HIT_DELAY` 0,15 s, `M1_INTERVAL` 0,38 s). Seuls les 4 blocs `Brawler_M1_N` ont été remplacés.
