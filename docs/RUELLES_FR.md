# Les ruelles (Marrow District)

Deux ruelles longent le viaduc, à l'est de l'enceinte, et se rejoignent dans une cour cachée sous le tunnel du train.

## Comment y aller
- **Ruelle nord** : dans le Yard, le cul-de-sac près de la tour d'escalade V1. Une lampe, et le tag « ARCHES > » sur le mur, montrent la brèche dans l'enceinte.
- **Ruelle sud** : sous le viaduc, tout au bout à l'est (après le dernier pilier). La brèche est dans le bloc de pierre du tunnel.

## Ce qu'il y a dedans
- **Le marché noir** (arche nord) : Vic, le vendeur. Il y a une bâche, des tables de marchandises volées, des caisses et un néon cassé « BUY · ELL ».
- **Le squat** (arche sud) : Old Ray, assis par terre avec sa bouteille. Il y a des matelas, des cartons, un caddie et un baril en feu.
- **Pour se couvrir** : des bennes, un conteneur sur lequel on peut grimper par les palettes, et un muret.
- **Ce qui casse** quand on y projette quelqu'un assez fort :
  - les palissades en bois et les planches (faciles) ;
  - les tôles ;
  - le muret en briques (il faut un coup plus fort).
  - Les panneaux des façades de la ville cassent de la même façon.
- **Une arme cachée** derrière les palissades à l'est de la cour : il faut casser une palissade pour l'atteindre.

## Armes de fortune
- **Les armes** : barre de fer, bouteille, planche.
- **Où les trouver** : au pied des murs, tout autour de la map (jamais au milieu), et dans les ruelles.
- **Comment les utiliser** :
  - Maintenir **E** pour ramasser.
  - Le **clic gauche** lance l'arme. Elle ne sert qu'une fois.
  - Une nouvelle arme réapparaît au même endroit 45 à 60 s plus tard.
- **Ce que fait chaque arme** :
  - La **barre de fer** tape le plus fort et projette loin.
  - La **bouteille** éclate et laisse des éclats de verre dans la plaie.
  - La **planche** se casse en deux.

## Modifier les ruelles
Tout est généré par `tools/city/alleys.py`. Il crée `src/server/Systems/City/AlleyData.luau`. Change le script, puis relance-le :

```
venv/bin/python -I tools/city/alleys.py
```

Ne modifie jamais `AlleyData.luau` à la main.

Les sons « barre qui tinte » et « planche qui casse » n'ont pas encore d'ID (`MetalClang`, `PlankBreak` dans `src/shared/Sounds.luau`).
