# Ville et ruelles : importer les objets 3D (CityProps)

Les objets des ruelles **et de toute la ville** (rues, voitures, parc, bar Duffy's, REWIND, HOLLOW THREADS, façades) sont de **vrais modèles 3D** : vraies formes et proportions, bords arrondis, salissures, rouille, traces, bosses, chaque variante différente. Ils sont tous dans **`assets/cityprops/CityProps.fbx`** (**203 objets**, environ 31 Mo : l'import prend un peu plus longtemps qu'avant, c'est normal).

Sans ce fichier, le jeu marche quand même : la ville et les ruelles gardent les anciens objets faits de pièces Roblox (et l'Output affiche une fois `[PropKit] ... props wait for the city prop kit`). Pareil si un objet manque dans le fichier : cet objet-là garde ses anciennes pièces.

## Importer dans Studio (une seule fois, et à chaque mise à jour du fichier)

1. Télécharge **`assets/cityprops/CityProps.fbx`** : sur GitHub, ouvre le fichier puis clique **Download raw file**.
2. Dans Studio, dans `ReplicatedStorage > Assets`, crée un Folder **`City`**.
   Si un ancien **`CityProps`** est déjà dedans, **supprime-le** d'abord.
3. **Import 3D** (menu File, ou onglet Avatar), choisis `CityProps.fbx`, puis clique **Import** sans rien changer (laisse **Ignore Vertex Colors** décoché : les salissures sont dans les couleurs des sommets).
4. Glisse le modèle **`CityProps`** qui apparaît dans le Workspace vers `ReplicatedStorage > Assets > City`.
5. Ne supprime **rien** dedans, ne renomme rien : surtout pas **Kit_Origin**, **Kit_Up**, **Kit_Out** et les petits cubes `..._Pivot`, `..._Light`, `..._Fx` : le jeu s'en sert pour se repérer.
   Conseillé : sélectionne toutes les MeshParts du modèle et laisse **CollisionFidelity** sur **Default** (ne mets pas Box : le sang et la pluie se poseraient sur une boîte invisible autour des fenêtres, des arbres ou des auvents ; les objets ne servent qu'à l'affichage, les collisions restent celles d'avant).
6. **File → Publish to Roblox**.

## Les objets du kit

- **Rue** : cône de chantier (neuf, écrasé), pneu usé (et lisse), fût de 200 L, fût brasero (feu dedans), blocs de béton (avec ferraille), tas de gravats (2), boulettes de papier (2).
- **Sacs** : sacs poubelle (3, dont un éventré), sac de ciment déchiré, sac à dos, couvertures (en tas, pliées), sac de couchage.
- **Poubelles** : poubelle à roulettes (neuve, abîmée) et son couvercle, conteneur à verre/papier et ses couvercles, benne et ses couvercles (droit, tordu), casiers à lait (entier, cassé), caisse plastique.
- **Squat** : matelas (sale, déchiré, appuyé au mur), fauteuil (avec ou sans couverture), tente, abri bâche, réchaud de camping.
- **Marché** : télé cathodique, radio-cassette, blouson de cuir **noir** et **marron**, sweat à capuche, portant, stand bâché, mallette de montres, caisse à monnaie, plateau de téléphones.
- **Murs** : climatiseur, lampe col-de-cygne (et éteinte), hublot grillagé (et éteint), parabole, descente de gouttière (droite, courte, coude, dauphin, collier), château d'eau, chaise de bureau (normale, défoncée).

**Nouveaux objets de la ville (vague 1, 128 objets)** :
- **Mobilier de rue** : lampadaire (LED, rouillé à tête « cobra », mort avec sa porte arrachée), feu tricolore (mât avec bouton piéton, tête à 3 feux et visières), cabine téléphonique (et vandalisée), borne à incendie (et usée), séparateur béton type Jersey (et ébréché, ferraille visible), kiosque à journaux (trappe éclairée, gros titres « BODY FOUND » / « STRIKE! »), présentoir à magazines, paquets de journaux, banc en acier, potelets (droit, tordu), grille d'égout (la vapeur en sort), plaque d'égout « SEWER ».
- **Voitures** : berline américaine des années 90 (propre, fatiguée, taxi avec enseigne TAXI, épave sur parpaing, sur chandelles capot ouvert), camion à caisse (et abîmé, avec le marquage HALVORSEN FREIGHT). Vraies roues : pneus ronds avec flanc bombé, enjoliveurs en acier gris creusés avec fentes, poussière de frein ; la rouille de l'épave suit les bas de caisse, les passages de roue et les joints de portes (cœur brun foncé, bord orange). Couleurs de carrosserie variées et passées (bordeaux, beige, rouge délavé, blanc cassé, vert foncé).
- **Quai, Cage, bennes** : cartons de livraison et palette de cartons sur le quai, butoirs en caoutchouc, panier de basket de rue (poteau rond, panneau en acier perforé, cercle rouillé, filet en chaîne), grande benne en acier sur roulettes (couvercles fermés, ou un couvercle soulevé par des sacs).
- **Parc** : banc en fonte et bois (et abîmé), lampadaire victorien (et penché), corbeille en fonte « LITTER », fontaine à boire (granit, « 1897 »), arbres (platane, tilleul, arbre d'automne avec feuilles au sol), fontaine à deux vasques avec têtes de lion, kiosque à musique victorien, distributeur SpezCola (et abîmé), touffes de fleurs dans les massifs (géraniums, œillets d'Inde, pétunias, marguerites fatiguées).
- **Bar Duffy's** : comptoir (2 moitiés différentes), tireuses à bière (3 et 2 becs), tabourets (et déchiré), banquette capitonnée, tables, lampe en laiton, bougeoirs, tonneau-table, cendrier, billard, queue, boules, lampe de billard, juke-box, distributeur de cigarettes, cible de fléchettes, suspensions (et cabossée), support d'enceinte, rangée de pintes, cadres photo, meuble de fond de bar avec miroir, **rangées de bouteilles décoratives** (DecoBottleRowA/B/C).
- **REWIND** : bacs à vinyles, piles de VHS, platine, caisse enregistreuse ancienne, petites télés, étagère de VHS remplie, enceintes de scène (et usée), pied de micro, borne d'arcade, boule à facettes.
- **HOLLOW THREADS** : mannequins (corps, haut et pantalon séparés : le jeu peint toujours les tenues), chemises et sweats sur cintres, crochets, piles de t-shirts pliés, paires de baskets, étagère murale, table en bois de récup, rideaux de cabine, miroir sur pied, caisse moderne (écran tactile, terminal carte).
- **Façades** : fenêtres à guillotine (avec ou sans store, à barreaux, condamnées par des planches, versions rez-de-chaussée), climatiseurs de fenêtre (et rouillé), rideaux métalliques de boutique (et rouillé) avec leur coffre, portes de garage enroulables (et usée, étroite), porte de quai, devantures (4 largeurs), porte vitrée avec barre anti-panique, stores bannes rayés (et déchiré), lanterne murale.

**Bouteilles** : aucune bouteille nulle part, **sauf** les rangées de bouteilles du meuble du bar Duffy's (`DecoBottleRowA/B/C`), que tu as autorisées : c'est **du décor pur**, collé à l'étagère, jamais ramassable ni utilisable, sans tag ni prompt. Elles remplacent les 48 anciennes pièces « Bottle » décoratives du meuble.

## Ce qui change une fois importé

- Chaque objet marqué dans les données (une pièce invisible `MeshProp`) reçoit son modèle 3D au même endroit, à la même taille, tourné pareil (couché, penché...).
- Les anciennes pièces de l'objet :
  - celles qui ont des **collisions** (ou que les coups/rayons touchent) deviennent **invisibles mais restent** : on se cogne, on saute, on monte dessus et on frappe exactement comme avant ;
  - les petits objets **se cassent toujours** sous les gros coups (charge, atterrissage...) : tout l'objet (modèle compris) vole en morceaux de sa couleur, puis revient au bout de 25 s. Les gros (voitures, lampadaires, feux, comptoir du bar, plus de 14 studs) **restent debout** : on ne peut pas trouer un modèle, et le faire disparaître d'un coup serait faux. Exception : un rideau métallique ou une porte de garage **cassable** (tag Breakable) part en entier, et la pièce sombre derrière apparaît comme avant. Les distributeurs SpezCola ne se cassent pas (le panneau lumineux et le bouton resteraient en l'air) ;
  - le sang et la pluie s'arrêtent sur le **modèle visible** des objets qui étaient déjà solides (il est touchable par les rayons, mais sans collision). Les objets qui n'étaient que de la décoration (cadres de fenêtres, auvents, feuillages, têtes de lampadaires) et les feuilles, vitres, ampoules et papiers ne les arrêtent pas : sinon le sang collerait à une boîte invisible en l'air. Ils ne gênent pas non plus l'escalade (la détection des rebords les traverse) ;
  - celles qui portent un **tag**, des **particules** (feu, vapeur, gouttière) ou un son restent aussi (invisibles), déplacées à l'endroit du modèle (bouche de la gouttière, haut du brasero) ;
  - les autres (pure décoration) sont **supprimées**.
- **Les lampes** : l'ampoule (ou la vitre) du modèle **devient** l'ampoule du jeu. Elle s'allume la nuit, s'éteint le jour et pendant les coupures de courant, clignote (Flicker), vieillit (Faulty), reste morte (Dead) comme avant ; le brasero brille et vacille. Une lampe sans lumière dans les données montre une vitre éteinte.
- Plus de clignotement (« z-fighting ») sur ces objets : chaque modèle est une forme propre, sans pièces l'une dans l'autre.

## Vérifier dans Studio

- **Après l'import**, vérifie que le modèle `CityProps` contient bien des objets comme `StreetLampColumn_...`, `Sedan_...`, `BandstandVictorian_...`, `BarCounterModule_...`, `RecordBinCrate_...`, `WindowFrameSash_...` (203 objets en tout, chacun avec son `_Pivot`).
- **Rues** : lampadaires, feux, bornes, cabine, kiosque, plaques d'égout. La nuit les lampadaires, le kiosque et le feu rouge s'allument ; le lampadaire « Dead » reste éteint, les « Flicker » clignotent.
- **Voitures** : elles posent bien au sol (pas de roues dans le sol, pas de voiture qui flotte), le taxi clignote orange la nuit, le texte HALVORSEN FREIGHT est lisible sur le camion. Monte sur une voiture, cogne-toi dedans : mêmes collisions qu'avant.
- **Parc** : arbres, kiosque à musique (on peut toujours monter dessus), fontaine (l'eau reste), lanternes allumées la nuit. Les 3 **distributeurs SpezCola** (parc, Duffy's, Cage) : le prompt marche toujours, la canette sort au même endroit, le panneau rouge brille.
- **Duffy's** : les tabourets et banquettes (les PNJ s'assoient à la même hauteur), le comptoir (on peut toujours s'y adosser / sauter dessus), le billard, le juke-box qui clignote, les bouteilles décoratives sur l'étagère (rien à ramasser).
- **REWIND / HOLLOW THREADS** : les comptoirs et leurs prompts marchent comme avant, les mannequins changent toujours de tenue, les télés du mur sont allumées.
- **Façades** : fenêtres, rideaux métalliques et portes de garage. Frappe une façade cassable : le panneau casse comme avant et le modèle part avec lui, puis revient. Les vitrines restent cassables.
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

Les objets sont décrits dans `tools/city/kit/pieces/*.py` (un fichier par famille : `streetfurn.py`, `vehicles.py`, `park.py`, `bar.py`, `shops.py`, `facades.py`, plus les anciens). Les matières sont dans `kitlib.py` (LAYERS) et, côté jeu, dans `PropKit.luau` (LOOKS), qui ont maintenant aussi : `LensRed` / `LensAmber` (feux de voiture), `Brass` (laiton), `Vinyl` (skaï des sièges), `Leaves` (feuilles, matière LeafyGrass) et `Bark` (écorce). Leur placement dans la ville est dans `tools/city/overlay/edits/*.py` (`street.py`, `vehicles.py`, `park.py`, `bar.py`, `shops.py`, `facades.py`, `yard.py`, `reuse.py`, `zfight.py`).

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
