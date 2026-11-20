# Ruelles : importer les objets 3D (CityProps)

Les objets des ruelles sont de **vrais modèles 3D** : vraies formes et proportions, bords arrondis, salissures, rouille, traces, bosses, chaque variante différente. Ils sont tous dans **`assets/cityprops/CityProps.fbx`** (64 objets).

Sans ce fichier, le jeu marche quand même : les ruelles gardent les anciens objets faits de pièces Roblox (et l'Output affiche une fois `[PropKit] ... props wait for the city prop kit`).

## Importer dans Studio (une seule fois, et à chaque mise à jour du fichier)

1. Télécharge **`assets/cityprops/CityProps.fbx`** : sur GitHub, ouvre le fichier puis clique **Download raw file**.
2. Dans Studio, dans `ReplicatedStorage > Assets`, crée un Folder **`City`**.
   Si un ancien **`CityProps`** est déjà dedans, **supprime-le** d'abord.
3. **Import 3D** (menu File, ou onglet Avatar), choisis `CityProps.fbx`, puis clique **Import** sans rien changer (laisse **Ignore Vertex Colors** décoché : les salissures sont dans les couleurs des sommets).
4. Glisse le modèle **`CityProps`** qui apparaît dans le Workspace vers `ReplicatedStorage > Assets > City`.
5. Ne supprime **rien** dedans, ne renomme rien : surtout pas **Kit_Origin**, **Kit_Up**, **Kit_Out** et les petits cubes `..._Pivot`, `..._Light`, `..._Fx` : le jeu s'en sert pour se repérer.
   Conseillé : sélectionne toutes les MeshParts du modèle et mets **CollisionFidelity** sur **Box** (ça ne se change pas en jeu, et les objets ne servent qu'à l'affichage : les collisions restent celles d'avant).
6. **File → Publish to Roblox**.

## Les objets du kit

- **Rue** : cône de chantier (neuf, écrasé), pneu usé (et lisse), fût de 200 L, fût brasero (feu dedans), blocs de béton (avec ferraille), tas de gravats (2), boulettes de papier (2).
- **Sacs** : sacs poubelle (3, dont un éventré), sac de ciment déchiré, sac à dos, couvertures (en tas, pliées), sac de couchage.
- **Poubelles** : poubelle à roulettes (neuve, abîmée) et son couvercle, conteneur à verre/papier et ses couvercles, benne et ses couvercles (droit, tordu), casiers à lait (entier, cassé), caisse plastique.
- **Squat** : matelas (sale, déchiré, appuyé au mur), fauteuil (avec ou sans couverture), tente, abri bâche, réchaud de camping.
- **Marché** : télé cathodique, radio-cassette, blouson de cuir **noir** et **marron**, sweat à capuche, portant, stand bâché, mallette de montres, caisse à monnaie, plateau de téléphones.
- **Murs** : climatiseur, lampe col-de-cygne (et éteinte), hublot grillagé (et éteint), parabole, descente de gouttière (droite, courte, coude, dauphin, collier), château d'eau, chaise de bureau (normale, défoncée).

Aucune bouteille, nulle part.

## Ce qui change une fois importé

- Chaque objet marqué dans les données (une pièce invisible `MeshProp`) reçoit son modèle 3D au même endroit, à la même taille, tourné pareil (couché, penché...).
- Les anciennes pièces de l'objet :
  - celles qui ont des **collisions** (ou que les coups/rayons touchent) deviennent **invisibles mais restent** : on se cogne, on saute, on monte dessus et on frappe exactement comme avant ;
  - ces objets **se cassent toujours** sous les gros coups (charge, atterrissage...) : tout l'objet (modèle compris) vole en morceaux de sa couleur, puis revient au bout de 25 s ;
  - le sang et la pluie s'arrêtent sur le **modèle visible** (il est touchable par les rayons, mais sans collision) ;
  - celles qui portent un **tag**, des **particules** (feu, vapeur, gouttière) ou un son restent aussi (invisibles), déplacées à l'endroit du modèle (bouche de la gouttière, haut du brasero) ;
  - les autres (pure décoration) sont **supprimées**.
- **Les lampes** : l'ampoule (ou la vitre) du modèle **devient** l'ampoule du jeu. Elle s'allume la nuit, s'éteint le jour et pendant les coupures de courant, clignote (Flicker), vieillit (Faulty), reste morte (Dead) comme avant ; le brasero brille et vacille. Une lampe sans lumière dans les données montre une vitre éteinte.
- Plus de clignotement (« z-fighting ») sur ces objets : chaque modèle est une forme propre, sans pièces l'une dans l'autre.

## Vérifier dans Studio

- Va dans les ruelles (à l'est du ring, le long du viaduc) : les objets sont lisses et sales, pas des blocs empilés.
- Lance le jeu : l'Output ne doit **pas** afficher `[PropKit] CityProps has no Kit_Origin` ni `has no pieces`.
- Approche-toi d'une lampe col-de-cygne et d'un hublot : la vitre brille la nuit, et si une coupure de courant arrive, elle s'éteint avec les autres. Le brasero vacille.
- Cogne-toi contre une benne, monte sur un tas de gravats, frappe quelqu'un derrière une poubelle : rien ne doit avoir changé.
- Tourne la caméra autour des objets (près, loin, en rasant) : aucune surface ne doit clignoter.
- Si un objet est **trop sombre ou trop clair**, dis-moi lequel : les couleurs se règlent dans `PropKit.luau` (table LOOKS), pas besoin de réimporter.

## Refaire le fichier

```bash
venv/bin/python -I tools/city/kit/build_city_kit.py assets/cityprops --preview /tmp/props_preview
```

`--preview` rend des images de chaque objet (4 angles + un gros plan, à côté d'une silhouette humaine de 1,80 m). Voir `assets/cityprops/README.md` pour le détail des objets.
