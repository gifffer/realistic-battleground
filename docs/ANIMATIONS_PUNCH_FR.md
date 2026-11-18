# Les 4 coups de base (M1) : Motifect → R6

Les 4 coups du combo M1 (`Brawler_M1_1` à `Brawler_M1_4` dans
`src/client/Animation/CombatClips.luau`, communs à tous les kits) viennent maintenant du
**Motifect Combat Motion Pack** (40 animations FBX faites pour Unreal), adaptées au R6.

## Les animations choisies

| Coup | Animation Motifect | Images | Pourquoi |
|---|---|---|---|
| M1_1 jab gauche | `jab_right` **en miroir** (la garde du pack est inversée) | 6,8 → 23,5, impact 11,2 | Le jab le plus droit et le plus rapide du pack, il part presque dans l'axe. Testé contre `jab_left` : même rendu, mais plus lent à l'impact. |
| M1_2 direct droit | `combo_punch_kick`, 2e direct (haut du corps seulement) | 57,5 → 74,5, impact 65,7 | Le seul vrai direct du bras arrière : trajet droit, au centre, à hauteur de tête, les hanches lancent le torse. `cross_left` faisait une boucle (lu comme un crochet en R6). |
| M1_3 crochet gauche | `hook_left` (haut du corps seulement) | 21,5 → 29,7, impact 28,6 | Le crochet le plus rapide : le poing sort puis balaie à hauteur de tête. On coupe le suivi qui s'enroule derrière la tête et on revient en garde. |
| M1_4 finisher | `cross_right` (overhand / haymaker) | 9 → 40, impact 23,7 | Le coup le plus lourd : le bras arrière boucle par le côté, tout le corps tourne, le talon arrière pivote. Même famille que l'ancien M1_4. |

L'ordre des mains reste gauche-droite-gauche-droite : les réactions (`HitJab`, `HitCross`,
`HitHook`, `HitHeavy`) et le côté où la tête part n'ont pas changé.

## Comment c'est adapté au R6
Le R6 n'a ni coude ni genou, et le jeu impose l'impact à **0,15 s**. Le script :
- vise le **poing** (pas l'os du bras) : le trajet du poing Motifect est recalé pour partir du poing
  de la Garde et arriver au même point d'impact que les anciens coups (dans la hitbox) ;
- reprend la rotation du torse (mise à l'échelle : jab −35°, direct +40°, crochet −49°, finisher +50°),
  une petite fente vers l'avant, la tête qui reste sur la cible, l'autre poing au menton ;
  sur le finisher, le torse continue de tourner d'environ 8° juste après l'impact (le poids passe
  à travers la cible) ;
- garde le crochet à hauteur de tête : son arc s'élargit sur les côtés, mais pas vers le bas ;
- plante les pieds au sol (genou simulé), sans glisser ;
- **accélère le temps** : l'élan est compressé, le poing arrive vite à l'impact (25 à 33 studs/s, de plus en plus vite jusqu'au contact),
  s'arrête net sur la cible (le hit-stop fige une pose propre), puis revient ;
- commence et finit **exactement** en pose de Garde (le combo s'enchaîne toutes les 0,38 s).

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
