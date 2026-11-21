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

## La couche CityOverlay (corrections de toute la ville)

**Ce que c'est.** Les données de la ville (`src/server/Systems/City/CityData1..4.luau`) sont **générées** par `citygen.py`, qui n'est pas dans le dépôt et qui est relancé quand la ville grandit. Une retouche faite à la main dans CityData serait donc **perdue** au prochain export. Toutes les corrections de la ville entière (couleurs, z-fighting, panneaux et textes recadrés, objets remplacés par les modèles 3D du kit...) passent par une **couche à part** : `CityOverlay1..N.luau`, à côté de CityData.

**Comment ça marche.** Chaque correction vise une pièce par son **dossier + nom + position d'origine** (tolérance 0,05 stud), et aussi sa **taille, sa rotation et le texte de son panneau d'origine** : si `citygen.py` garde une pièce au même endroit mais l'agrandit, la tourne ou change son texte, la correction ne la reconnaît plus et ne lui remet pas d'anciennes valeurs. Au démarrage, `City/init.luau` charge la ville, ajoute les ruelles, puis applique l'overlay (`applyOverlay`) avant de construire. Les opérations :
- **set** : change la couleur, la matière, la transparence, la taille, la position, les drapeaux ou le panneau (texte) d'une pièce ;
- **remove** : enlève une pièce de pure décoration (l'outil refuse tout ce qui a un tag, une lumière, des collisions...) ;
- **add** : ajoute une pièce (par exemple une plaque fine pour un texte) ;
- **wrap** : met des pièces sous un marqueur `MeshProp` : PropKit les remplace par le modèle 3D, comme dans les ruelles ;
- **sign** : déplace ou recadre un texte (plaque dédiée, marges, taille max, netteté).

Les opérations vont par **groupes** : si la ville a changé et qu'une pièce visée n'est plus là, tout le groupe est **sauté** et la ville d'origine reste (rien ne casse). L'Output affiche une seule ligne : `[CityOverlay] applied X ops, skipped Y (city changed?)`. Si Y n'est pas 0, la ville a été régénérée : il faut relancer l'outil (ci-dessous) pour voir quelles corrections ne trouvent plus leur pièce.

**Les textes** (`SurfaceGui`) acceptent maintenant des champs en plus, tous facultatifs (sans eux, rien ne change) : `pps` (pixels par stud : plus c'est haut, plus un petit texte est net), `pad` (marges), `maxSize` / `minSize` (taille du texte), `xalign` / `yalign` (alignement), `stroke` (contour), `light` (sensibilité à la lumière), `bright`, `textTr` (peinture usée), `rich`, `maxDist`, `lineH` (espace entre les lignes). Pour les néons (tag CityNeon), Ambience garde la main sur `light` et `bright`. Une police inconnue ou un panneau incomplet ne peut plus arrêter la construction de la ville : l'outil le refuse, et le jeu met une valeur par défaut (avec un avertissement dans l'Output).

**Refaire l'overlay** (après une modification des corrections, ou quand la ville a été régénérée) :

```bash
venv/bin/python -I tools/city/overlay/build_overlay.py           # vérifie et écrit CityOverlay*.luau
venv/bin/python -I tools/city/overlay/build_overlay.py --check   # échoue si les fichiers ne sont plus à jour (+ liste les corrections qui ne trouvent plus leur pièce)
venv/bin/python -I tools/city/overlay/build_overlay.py --prune   # après une régénération : écrit tout ce qui marche encore, liste ce qui est abandonné
venv/bin/python -I tools/city/overlay/selftest.py --luau          # teste toutes les opérations (+ le vrai code du jeu sous Lune)
```

Les corrections sont dans `tools/city/overlay/edits/*.py` (un fichier par endroit ou par famille d'objets, chacun avec une fonction `edits(O)`). L'outil s'arrête avec une erreur si une pièce visée n'existe pas, existe en double, ou a été retirée par les ruelles (avec `--prune`, ces groupes sont abandonnés et listés, le reste est écrit). Il refuse aussi : un panneau neuf sans texte, face ou couleur, un nom de police qui n'existe pas dans Roblox, une pièce mise sous elle-même ou en boucle, une pièce de machine SpezCola, de mannequin ou de façade sortie de son modèle, l'enlèvement d'une pièce sous laquelle l'overlay a accroché quelque chose, et le déplacement du texte d'un néon sur une plaque (Ambience ne le piloterait plus). Les vitres (ShopGlass, DoorGlass, Window, Glass, Transom...) sont rhabillées par CityGlass au lancement : changer leur couleur ou leur transparence dans l'overlay ne sert à rien.

**Voir le résultat** sans Studio : `tools/city/render_city.py` rend toute la ville (données + ruelles + overlay, avec ou sans le kit, de jour ou de nuit, textes compris) :

```bash
venv/bin/python -I tools/city/render_city.py --list
venv/bin/python -I tools/city/render_city.py --cams kitchen_door,duffys --out /tmp/rendus
venv/bin/python -I tools/city/render_city.py --cam 0,60,120:0,0,0 --night --out /tmp/rendus
```

**Les textes de la carte** suivent tous la même règle :
- le texte ne touche jamais les bords de sa plaque (marges) ;
- sa netteté (`pps`) est calculée pour chaque panneau par `tools/city/overlay/textfit.py`, avec les vraies polices : le texte remplit sa zone pile à la taille maximale de Roblox (100 px). Il est donc net et ne se recoupe jamais tout seul sur une ligne de plus ;
- les textes sur deux lignes ont leurs propres retours à la ligne (plus de « · » qui reste en bout de ligne) ;
- seuls les néons sont allumés ;
- les graffitis sont en PermanentMarker, assez contrastés (au moins 3:1, sinon noir ou blanc cassé) et à peine penchés ;
- un texte posé sur un panneau cassable ou une vitre est rangé sous elle : il part avec elle quand elle casse ;
- jamais de texte DERRIÈRE une vitre : en qualité graphique haute, Roblox ne dessine pas un texte vu à travers du Glass. Les affiches du vidéoclub sont donc collées côté rue ;
- le texte est à au moins 0,04 stud du mur (pas de scintillement), et dégagé des auvents, gouttières et échelles vus en biais.
- pas de bombe de peinture aux étages : personne ne la lit d'en bas (les fenêtres condamnées du haut restent nues).

Les textes de la ville sont dans `edits/texts.py`. Ceux des ruelles sont corrigés directement dans leur générateur (`tools/city/props_walls.py`, `alleys.py`) : porte de cuisine, NO LOITERING, étiquettes DANGER, tags, affiches, enseigne peinte KESSLER, néon du marché.

Ne modifie jamais `CityOverlay*.luau` ni `CityData*.luau` à la main.
