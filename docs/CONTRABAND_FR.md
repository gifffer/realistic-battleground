# Contrebande : prototype (`feature/contraband-prototype`)

Première version jouable de la nouvelle direction : un labo clandestin caché dans un appartement miteux, une culture de clone qui pousse dans une cuve, l'extraction au *cutter* avec un mini-jeu où l'on choisit les bio-éléments à garder, la mallette BX-7 qu'on porte à la main gauche et l'acheteur qui paie en coins. Pas de police, pas de PNJ en plus (sauf l'acheteur), pas de trams. Le gore et le train ne changent pas.

Tout est décidé par le serveur : les clients ne font que demander (3 remotes + des ProximityPrompts), et chaque demande est vérifiée (cadence, distance, état, propriétaire).

## Ce qui a été ajouté

### La boucle
1. **Entrer** : 3 portes en bois de la ville ouvrent **ton** appartement « Flat 4B » (chacun le sien, privé) : **Calloway Tenements** (avenue, ouest), **Doyle Alley 7**, **Lot 9 Rear**. Maintenir **E** « Enter lab ». Une petite réglette de lumière froide au-dessus de chaque porte aide à les trouver. Refusé si on vient d'être frappé **ou de frapper** (« Not while fighting. », 8 s après un coup reçu, 5 s après un coup donné), si on n'est pas au repos (en train d'attaquer, de bloquer…), en duel ou en train de vendre. Tout est revérifié juste avant la téléportation. On ressort par la porte d'entrée de l'appartement (« Leave »), devant la porte de la ville par où on est entré. Le labo est au fond du couloir (voir « L'appartement » plus bas).
2. **Planter** : « Plant culture » sur la cuve. Le clone pousse **8 min**, seulement tant que tu es sur le serveur (dans le labo ou dehors) ; hors ligne, ça attend :
   - **MATRIX** (0–25 %) : liquide ambre, lobes de gel sur une tige ;
   - **FRAME** (25–75 %) : armature adulte blanche qui se remplit de gel laiteux depuis les pieds ;
   - **SHELL** (75–100 %) : corps synthétique gris nacré sans visage, « SYN-04 NO ID » ;
   - **READY** : LED fixe, écran « READY · EXTRACT », la cuve propose « Extract ». Message « Culture ready. Back to your lab. » où que tu sois.
   - Le HUD (en bas à droite) affiche toujours « CULTURE 47 % · 4:15 », puis « CULTURE READY ».
3. **Extraire** (~20 s, sans mallette en main) : maintiens **E** sur la cuve PRÊTE (« Extract »). La caméra coupe sur le chariot : la main gantée prend le *cutter* (un fil chaud bricolé sur un vieux manche de fer à souder) sur son chargeur et ouvre **seule** la couture du torse de la coque (1,6 s) ; la couture rougeoie ambre puis refroidit en une ligne sombre. Les deux panneaux s'ouvrent, une vapeur froide déborde, et **4 à 6 bio-éléments** stylisés s'allument un par un dans leur gel : **CLUSTER** (lobes ambre sombre, une lueur chaude dedans), **POD** (cosse violet foncé nervurée), **COIL** (spirale vert olive qui pâlit, la plus chère) et parfois une **HUSK** (leurre desséché, sans lumière). Leur état se lit à l'œil : intact, meurtri ou rompu. **Survole** un élément 0,5 s : le vieil écran à côté affiche sa lecture (« SCANNING » puis le type et 0 à 3 barres ; une husk = « NO SIGNAL »). **Maintiens le clic** 0,45 s (anneau de points autour du curseur) : l'élément résiste, se détache, monte et glisse dans une capsule posée à côté de la tête de la coque, le bouchon tombe, la petite lumière de note s'allume. **2 capsules** et une barre de refroidissement de **18 s**. Une husk gâche une capsule (INERT). Le **serveur décide tout** (contenu, score, note, à partir d'une graine sauvegardée avec la culture) ; le client n'envoie que son choix. Arrêter avant le premier choix : la cuve reste PRÊTE avec **les mêmes** éléments. Après un choix, ce qui est scellé est gardé (et la culture est consommée tout de suite dans la sauvegarde : un crash ne peut pas dupliquer les cores). Barre écoulée sans choix : « The tissue cooled. The vat is still ready. ». Liquides laiteux et gris-vert, jamais de rouge, jamais d'organe reconnaissable. La coque part dans la goulotte. Le core va dans le congélateur vitré (stash, 8 places, sauvegardé) ou directement dans une mallette posée dans le labo.
4. **Mallette** : « Take case » sur le râtelier, puis « Load cores » (**E**) sur l'établi pour y mettre les cores du stash ; « Unload cores » (**T**) pour les remettre. Chaque prompt n'apparaît que s'il peut servir. Mallette « Courier » = 2 berceaux (le 3e est bouché par la mousse). Au plus 2 mallettes posées dans ton labo ; prendre une nouvelle mallette reprend tes mallettes **vides** laissées en ville.
5. **Porter** : la mallette est dans la main **gauche** (le buste penche un peu de l'autre côté, l'épaule chargée descend). Les M1 de la main gauche (coups 1 et 3) sont donnés avec la main droite : le poing arrive au même moment, puis le retour en garde remplit le temps jusqu'au clic suivant (plus de garde qui « saute » entre deux coups), et la victime réagit au coup **vu** (un direct du droit, pas un jab ou un crochet du gauche). En **bloquant**, la mallette remonte devant la poitrine comme un bouclier (0,12 s, redescend en 0,2 s). Pendant une réaction à un coup, le bras suit un peu le choc ; pas de changement de prise en plein combat. Vitesse ×0,88 (le sprint marche), endurance du sprint ×1,3, pas d'escalade haute (mantle), l'enjambement bas marche. M1, blocage et dash marchent ; pas de coups de kit (1–4), pas d'Awakening, pas de finisher. **G** = poser la mallette debout devant soi ; **E** sur une mallette au sol = la ramasser. Poser et ramasser : un accroupissement de 0,5 s, la mallette quitte (ou rejoint) la main au moment où la main touche le sol, pas à la réponse du serveur (pareil pour les autres joueurs).
6. **KO** par un **joueur** (pas par un mannequin ou un PNJ) : la mallette tombe à plat, fermée, et son couvercle **saute** entrouvert à 12° quand elle touche le sol (un peu plus, puis il se stabilise), avec une fine lueur froide (seule la réglette LED, la même pleine ou vide). Si elle roule trop loin, tombe d'une corniche ou finit sur la voie du train, elle revient au point de chute. **N'importe qui** peut la ramasser ; le contenu n'est connu qu'en la prenant.
7. **Vendre** : l'acheteur « Marlow » à l'arrière de la camionnette du Yard (petite ampoule rouge, « NIGHT INTAKE »). « Sell cores » (« Night Intake ») n'apparaît que si on porte une mallette. La mallette s'ouvre **1,6 s** (sur l'horloge du serveur : tout le monde voit la même chose, un joueur qui arrive pendant la vente ne la voit pas recommencer) : la main la tient à plat devant la hanche, poignée dans le poing ; les molettes cliquent, les 2 loquets se relèvent (0,4 / 0,5 s), le joint lâche avec une bouffée de froid (0,6 s), puis le couvercle s'ouvre. Un coup, un KO ou bouger de plus de 4 studs annule (« Interrupted », rien de perdu). Prix par core = 60 × (A 1,2 / B 1,0 / C 0,8), ×0,5 sur un serveur privé. La mallette reste en main, vide.

### L'appartement (« Flat 4B »)
Un appartement pauvre, la nuit, sale et mal éclairé : une entrée (courrier en tas sur un paillasson usé, deux vieilles vestes au crochet, placard du compteur ouvert avec six rallonges nouées qui descendent le long du mur), un salon-cuisine (canapé usé, télé cathodique en veille, store vénitien sous la lampe sodium de la rue, frigo « DON'T OPEN — CULTURE MEDIUM » qu'on peut ouvrir), un couloir en L (peinture à deux tons, sombre sous la cimaise, traces de mains autour des poignées, auréole d'humidité près de la salle de bain, moisissure au plafond au-dessus du seau qui recueille la goutte, rallonges scotchées en un faisceau le long de la plinthe, tuyau d'arrosage qui sort de la baignoire, ampoule qui grésille avec une zone sombre avant le coude), la salle de bain entrouverte, une chambre cadenassée, une chambre condamnée par deux planches (une lumière passe parfois dessous), la chambre du « cuisinier » (matelas au sol éclairé par le réveil, tableau blanc avec la courbe MATRIX / FRAME / SHELL) et, au bout du couloir, **une porte entrouverte, scotchée d'alu, avec un trait de lumière turquoise et une vapeur froide qui rampe dessous**.

Derrière un rideau à lanières, **l'ancienne chambre devenue labo clandestin**. On voit encore la chambre : le vieux papier peint et la trace d'un poster là où la bâche s'est décrochée (la bâche tombée est pliée par terre), la tête de lit debout contre le mur, la moquette et sa baguette à clous au bord du tapis caoutchouc, un abat-jour poussiéreux au-dessus des bâches du plafond, les rideaux de l'ancienne fenêtre. Puis le labo : cuve sur un châssis de récup (la lumière principale de la pièce, turquoise, avec trois flaques devant), chariot d'hôpital en acier terne et rayé avec une alèse bleue et du scotch, vieille lampe d'atelier à abat-jour cabossé, congélateur vitré gris-vert (autocollant à moitié arraché, rouille en bas) pour la planque, frigo couleur amande, étagère métallique pour les mallettes, pompes d'aquarium, bâches plastique, fenêtre couverte d'alu avec un ventilateur, goulotte (petite trappe de 3 × 2,8 au rabat entrouvert). Les portes s'ouvrent toutes seules en approchant (sauf le frigo : « Open » / « Close » ; les portes fermées : « Try » → « Locked. »). L'ambiance passe du chaud (appartement) au froid (labo) en 0,7 s. Tout est construit en parts et matériaux Roblox, rien d'importé.

### Ambiance, effets et sons
Chaque pièce a son fond sonore (grondement de l'immeuble, ville étouffée derrière les murs), en fondu quand tu passes d'une pièce à l'autre, avec sa propre réverb. Les sons des autres pièces sont étouffés comme à travers un mur : la cuve du labo s'entend faiblement dès le coude du couloir. À l'arrivée, le verrou tourne, la porte claque derrière toi, un peu de poussière roule au sol et l'ampoule nue se balance, avec les ombres de l'entrée qui bougent (une phalène tourne autour). Dans le couloir, l'ampoule grésille et saute de temps en temps (le bourdonnement suit), une goutte tombe dans le seau en rythme avec son « plic » et son onde, le parquet grince parfois, la lumière sous la porte condamnée s'allume et s'éteint, et une vapeur froide (un peu plus visible maintenant) rampe sous la porte du labo. Dans le labo, les pompes bullent, le congélateur fume (bouffée quand une capsule entre ou sort), les bâches ondulent au vent du ventilateur, le rideau de lanières s'écarte quand tu passes, la multiprise brûlée lâche parfois une étincelle, et le vieil écran trace la courbe de la culture et bipe quand elle est PRÊTE. Pendant l'extraction, le néon ne saute jamais, la lampe baisse un peu et l'ambiance baisse. La musique de rue et la pluie se coupent à l'intérieur. **Liste complète des sons (première version, à écouter) : `docs/SOUNDS_LAB_FR.md`.**

### Autres règles
- **Déconnexion en portant** : en ville, la mallette reste au sol où tu étais ; dans ton labo, ses cores retournent dans ton stash. « Dans le labo » se décide par la **position** (la boîte du labo), jamais par l'attribut seul.
- **Quitter le serveur** : ton labo disparaît ; les mallettes posées dedans reversent leurs cores dans ton stash.
- **Sauvegarde** : le stash sauvegardé contient aussi les cores des mallettes posées dans ton labo (et de celle que tu tiens dans ton labo), réécrit à chaque changement : un crash ou un arrêt du serveur ne les perd pas. Une mallette **portée en ville** est perdue avec ses cores si le serveur s'arrête (voulu).
- **Mallette abandonnée** : vide et personne à moins de 60 studs pendant 2 min, elle disparaît ; pleine et personne à moins de 60 studs pendant **15 min**, chaque core retourne sur l'étagère de celui qui l'a extrait (s'il est en ligne et a de la place), puis la mallette vide disparaît.
- **Limite du serveur** : au moins `MaxPlayers × 2 + 8` mallettes ; quand c'est plein, la plus vieille mallette **vide** en ville est reprise d'abord.
- **Train** : toujours mortel ; une mallette qui tombe sur la voie est posée sur la passerelle.
- **Anti-téléport** : un trajet trop rapide ou un saut énorme avant la vente → « Try again. » (rien de perdu, ligne d'avertissement dans l'Output).
- **Chaleur** : des compteurs silencieux (extractions, ventes, ramassages, coups pris en portant…) sont seulement enregistrés, sans effet pour l'instant (pour la police plus tard). Dans Studio ils s'affichent dans l'Output quand un joueur part.

### Autres changements visibles
- **Smog Night** : la nuit de la ville a un nouveau réglage (brouillard brun chaud, noirs plus profonds). Toujours la nuit en ville, la pluie et l'orage marchent comme avant, le parc reste ensoleillé.
- **Look « Lab »** dans le labo (air clair et froid). Aux portes du labo, l'écran passe au noir (0,15 s) pendant que la porte s'ouvre, la téléportation se fait porte presque ouverte (0,21 s), le look change d'un coup dans le noir, puis l'écran revient (0,25 s). Pas de pluie, d'éclair ni d'annonce météo dans le labo.
- **Extraction (effets)** : la vapeur froide est une vraie fumée (particules, texture intégrée à Roblox, rien d'importé) qui retombe et s'étale au lieu de monter ; au scellement, une bouffée lente sort de la capsule puis un anneau de froid au joint quand le bouchon claque. Les capsules ont 4 petites pattes ocre sur le bord (plus de bande orange qui faisait « flacon de pilules »). Les gouttes laiteuses tombent à vraie gravité et **restent** en petites perles au fond. Les bulles de la cuve apparaissent en fondu et s'aplatissent en crevant à la surface (bien plus nombreuses pendant un changement de phase), teintées par la couleur du liquide. Loin de la cuve (> 90 studs), sa lumière s'éteint et les bulles disparaissent.
- **Extraction (timing)** : chaque son part au geste local qui le produit (cutter, couture, panneaux, élément qui résiste puis se détache, bouchon), plus à la réponse du serveur. Caméra : coupe nette sur le chariot puis léger travelling avant, et retour derrière le personnage là où il est. La ligne d'aide a un fond sombre, l'anneau de maintien est clair avec un contour sombre.
- Dans le congélateur du labo, les capsules « respirent » chacune à son rythme ; seules les 2 plus proches de la caméra éclairent.
- **HUD** : le bloc mallette disparaît en fondu ; la barre d'ouverture de la vente part du bon endroit et ne peut plus être cachée par une ancienne vente.
- La pluie et l'orage ne descendent plus la lumière ambiante de nuit sous un seuil de lisibilité (seule une coupure de courant va plus sombre).

## Comment tester dans Studio
1. Synchroniser avec Rojo, puis **Test → Clients and Servers → 2 Players** (le détail des tests est dans `docs/TEST_FR.md`, section « Contrebande »).
2. Dans Studio, la culture pousse en **45 s** au lieu de 8 min (attribut `CultureFast` du Workspace, mis à `true` par le serveur au démarrage). Pour tester le vrai temps : dans la fenêtre Properties du Workspace (côté serveur), décocher `CultureFast`.
3. La sauvegarde de Studio utilise le vrai DataStore : il faut **Game Settings → Security → Enable Studio Access to API Services** pour tester « quitter puis revenir ».
4. Vérifications dans la barre de commande (côté **serveur**), elles doivent toutes renvoyer `true` :
   - `require(game.ServerScriptService.Server.Systems.Contraband.Ledger).selfTest(1, 5000)`
   - `require(game.ReplicatedStorage.Shared.Contraband.Grades).selfTest()`
   - `require(game.ServerScriptService.Server.Systems.Contraband.Ledger).verify()` (après chaque scénario)

## Réglages (`src/shared/Config.luau`)
| Section | Clé | Valeur | Rôle |
|---|---|---|---|
| `Lab` | `CULTURE_TIME` | 480 | secondes de pousse (en ligne) |
| `Lab` | `CULTURE_FAST_IN_STUDIO` / `CULTURE_FAST_TIME` | true / 45 | pousse rapide dans Studio |
| `Lab` | `PLANT_COST` | 0 | prix en coins pour planter |
| `Lab` | `STASH_MAX` | 8 | places sur l'étagère |
| `Lab` | `NO_ENTRY_AFTER_HIT` | 8 | pas d'entrée au labo juste après un coup |
| `Lab` | `SPACING` | 1200 | écart entre deux appartements (assez pour ne jamais charger celui du voisin) |
| `Extraction` | `CUT_TIME` / `SELECT_TIME` / `CAPSULES` | 1,6 / 18 / 2 | couture automatique, barre de refroidissement, capsules par extraction |
| `Extraction` | `ELEMENTS`, `KIND_WEIGHT`, `KIND_BASE`, `CONDITION_*`, `ROLL` | — | nombre d'éléments (4–6), fréquence et valeur de chaque type et état, petit hasard caché ±4 |
| `Extraction` | `PICK_MIN_GAP` / `HOLD_TIME` / `SCAN_TIME` | 0,9 / 0,45 / 0,5 | écart minimal entre deux choix (serveur), maintien et survol (client) |
| `Extraction` | `GRADE_A` / `GRADE_B` | 85 / 60 | seuils des notes |
| `Case` | `SPEED_MULT` / `STAMINA_DRAIN_MULT` | 0,88 / 1,3 | vitesse et endurance en portant |
| `Case` | `CRADLES` | Courier 2, MkII 3 | berceaux par mallette |
| `Case` | `EMPTY_DESPAWN_TIME` / `DESPAWN_CLEAR_RADIUS` | 120 / 60 | ménage des mallettes vides |
| `Case` | `ABANDON_TIME` | 900 | mallette pleine abandonnée : ses cores retournent à leur auteur |
| `Case` | `MAX_WORLD` / `MAX_ISSUED_LIVE` | 40 / 2 | mallettes du serveur (au moins MaxPlayers × 2 + 8) / mallettes posées dans ton labo |
| `Case` | `SETTLE_MAX_FALL` / `SETTLE_MAX_ROLL` | 6 / 8 | mallette tombée : trop bas ou trop loin = remise au point de chute |
| `Market` | `BASE_PRICE`, `GRADE_MULT`, `PRIVATE_SERVER_MULT` | 60, A1,2/B1/C0,8, 0,5 | prix |
| `Market` | `OPEN_TIME` / `CANCEL_MOVE` | 1,6 / 4 | ouverture vulnérable de la vente |
| `Contraband` | `DEBUG_LOG` | true | lignes de debug dans l'Output (Studio seulement) |
| `Controls` | `CASE_SET_DOWN` | G | poser la mallette |

## Fichiers
- Serveur : `src/server/Systems/Contraband/` (Ledger, Guard, Heat, TripLog, Case, LabBuilder + AptProps (l'appartement et ses meubles), Apartments, Lab, Extraction, Market ; seul `init.luau` est chargé par le bootstrap).
- Partagé : `src/shared/Contraband/` (CaseModel, Grades, Sites).
- Client : `src/client/Contraband/` (modèles du clone, du core, de la cuve, de l'établi, interface d'extraction, `AptFx` (particules de l'appartement), `AptAudio` (sons par pièce)), contrôleurs `LabController`, `ExtractionController`, `CaseController`, `ContrabandHudController`, `ZoneLookController`, `ApartmentController` (portes, pièces), `ApartmentAmbienceController` (lumières, effets, sons), et `Animation/CarryClips.luau`.
- Retouchés : CharacterAnimationController (bouclier, coups re-calés, `getLastShownClip`), CombatEffectsController (réaction au coup vu), Knockout (signal `onKnockedOut`, liste d'intercepteurs), Duels, CityDoors (`Locked`, `pulse`), Combat (verrous en portant / en extraction), Movement (endurance, escalade), CityNpcs (`spawnExtra`), Ambience (Smog Night), PlayerData (champ `contraband`), Config, Remotes, Types.

## À vérifier dans Studio (le code n'a pas encore tourné en jeu)
- Le sens d'ouverture des 3 portes de la ville, l'endroit où l'on ressort, la porte et le texte « NIGHT INTAKE » de la camionnette.
- **Appartement** : l'ambiance générale (assez sombre, pas noir) ; les rayures du store sur le sol du salon (lampe sodium) ; le matelas de la chambre 2 visible (lueur du réveil) ; les carreaux manquants de la salle de bain par rapport à la texture CeramicTiles ; le papier peint et la trace de poster au-dessus des bâches tombées dans le labo ; la tête de lit et l'abat-jour vus à travers la bâche du plafond.
- **Effets** : direction des émetteurs, balancement du rideau ; vapeur sous la porte du labo visible mais discrète. Tester au réglage graphique le plus bas et le plus haut, et regarder **Render → Overdraw** devant la cuve.
- **Extraction** : le cadrage (cavité à droite, capsules en bas à gauche), la lisibilité des éléments (aucun ne doit ressembler à un organe), la coque qui ne vire pas au blanc sous la lampe, la ligne d'aide lisible.
- **Sons** : que chaque id se charge et s'entende (liste dans `docs/SOUNDS_LAB_FR.md`).
- La mallette posée (debout) et tombée (à plat) : bien au sol, pas dans le sol.
- La main gauche sur la poignée (en marchant, pendant la vente et en bloquant : bouclier devant la poitrine, pas dans le bras droit).
- Le look Smog Night et le look Lab ; la lisibilité du clone, du core et de la mallette.
- La mallette paraît-elle en aluminium brossé sous les lampes sodium ? Sinon monter `ALU` vers 190 dans `CaseModel.luau`.
- Pendant la vente, la mallette est tenue à plat d'une main (pas encore posée sur le hayon).
- Les molettes des serrures ne tournent pas visiblement (des cylindres lisses) : seul le son les fait cliquer.
- **Nombre de parts** : un appartement fait ~1 310 parts (objectif ≤ 1 100). À décider : enlever du désordre, ou accepter.
- Échap pendant l'extraction ouvre aussi le menu Roblox (on peut aussi utiliser le bouton STOP).
