# Les ruelles (Marrow District)

Deux ruelles longent le viaduc, à l'est de l'enceinte, et se rejoignent dans une cour cachée sous le tunnel du train.

## Comment y aller
- **Ruelle nord** : dans le Yard, le cul-de-sac près de la tour d'escalade V1. Une lampe, et le tag « ARCHES > » sur le mur, montrent la brèche dans l'enceinte.
- **Ruelle sud** : sous le viaduc, tout au bout à l'est (après le dernier pilier). La brèche est dans le bloc de pierre du tunnel.

## Ce qu'il y a dedans
Chaque coin raconte quelque chose, et les objets sont là pour une raison.
- **Ruelle nord : l'arrière d'un restaurant.**
  - La porte « KITCHEN - NO ENTRY », la hotte qui fume, les clims, l'escalier de secours et les câbles.
  - Une benne pleine (couvercle ouvert contre le mur), un tas de sacs poubelle, des cartons mouillés, des mégots, des taches d'huile.
- **Ruelle sud : un chantier de démolition** (« KESSLER BROS »).
  - Un échafaudage avec un filet, une barrière de chantier et des cônes.
  - Des parpaings, des sacs de ciment, du fer à béton, des gravats et des planches.
  - Une lampe de chantier qui grésille.
- **Le marché noir** (cour nord, devant l'arche) : Vic, le vendeur : blouson de motard ou sweat à capuche, chaîne en or, montre, cigarette, sacoche.
  - Un stand bâché avec des téléphones, des montres, des autoradios et une caisse.
  - Des caisses de stock et un portant de vêtements sous l'arche.
  - Un néon rouge « BUY · ELL » qui clignote mal.
- **Le squat** (cour sud) : Old Ray, assis par terre avec un gobelet de pièces, une pancarte, un sac et une couverture.
  - Des matelas, un duvet, un réchaud, une tente, un abri en carton, un caddie, un fauteuil défoncé.
  - Un baril en feu.
- **Derrière les murs** : les façades de grands immeubles, avec quelques fenêtres allumées la nuit (de la profondeur).
- **Aucune bouteille**, nulle part dans les ruelles (ni en verre, ni en plastique). Les outils le vérifient.

## Lumières et ambiance
- **Les vieilles lampes** (attribut `Faulty`, 0 à 1) :
  - leur intensité varie un peu, et parfois elles baissent ou se coupent une fraction de seconde, en grésillant ;
  - tous les joueurs voient la même chose au même moment ;
  - le jour / la nuit et les coupures de courant restent gérés par le serveur.
- **Dans les ruelles**, l'image devient plus sombre et plus brumeuse, avec des couleurs plus froides : la nuit y est oppressante, mais on voit toujours le combat.
- **Quand il pleut** : des flaques et des gouttes sous les arches.
- **La vapeur** sort de la grille au sol et de la hotte du restaurant.

## Pour se battre
- **Pour se couvrir** : des bennes, un conteneur sur lequel on peut grimper par les palettes, et un muret.
- **Ce qui casse** quand on y projette quelqu'un assez fort :
  - les palissades en bois et les planches (faciles) ;
  - les tôles ;
  - le muret en briques (il faut un coup plus fort).
  - Les panneaux des façades de la ville cassent de la même façon.
- **Une arme cachée** derrière les palissades à l'est de la cour : il faut casser une palissade pour l'atteindre.

## Armes de fortune
- **Les armes** : barre de fer, planche.
- **Où les trouver** : au pied des murs, tout autour de la map (jamais au milieu), et dans les ruelles.
- **Comment les utiliser** :
  - Maintenir **E** pour ramasser.
  - Le **clic gauche** lance l'arme. Elle ne sert qu'une fois.
  - Une nouvelle arme réapparaît au même endroit 45 à 60 s plus tard.
- **Ce que fait chaque arme** :
  - La **barre de fer** tape le plus fort et projette loin.
  - La **planche** se casse en deux.

## Modifier les ruelles
Tout est généré par `tools/city/alleys.py`, avec les bibliothèques d'objets `props_ground.py`, `props_walls.py` et `props_objects.py`. Le script écrit `src/server/Systems/City/AlleyData1.luau`, `AlleyData2.luau`… (en morceaux de 150 Ko au plus). Change le script, puis relance-le :

```
venv/bin/python -I tools/city/alleys.py
```

Ne modifie jamais les fichiers `AlleyData*.luau` à la main.

Les sons « barre qui tinte » et « planche qui casse » n'ont pas encore d'ID (`MetalClang`, `PlankBreak` dans `src/shared/Sounds.luau`).
