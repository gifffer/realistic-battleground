# Tester les fonctionnalités dans Studio

Pour chaque étape : récupère la branche (GitHub Desktop → *Fetch* → choisir la branche),
`rojo serve` doit tourner, Studio connecté, puis **Play**. Garde la fenêtre **Output** ouverte
(*View → Output*) : aucune ligne rouge ne doit apparaître.

## Étape 1 — Base personnage (`feature/character-base`)

Avant : place réglée en **R6** (voir `SETUP_FR.md`, « Avatar R6 »).

| # | Test | Résultat attendu |
|---|---|---|
| 1 | Lancer **Play** | Personnage R6 (blocs). En bas : barres **HEALTH 100** et **STAMINA 100**. À gauche : bouton **SETTINGS**. Pas de barre de vie Roblox en haut à droite. |
| 2 | Bouger la souris | La caméra tourne sans clic droit, le curseur reste au centre, le perso regarde où vise la caméra, caméra décalée sur l'épaule droite. |
| 3 | Molette | Zoom entre proche et moyen, jamais en 1ʳᵉ personne. |
| 4 | Maintenir **Shift** en marchant | Le perso court, l'angle de vue s'élargit un peu, STAMINA descend. |
| 5 | Shift **sans bouger** | STAMINA ne descend pas. |
| 6 | Courir jusqu'à 0 | La barre devient brun/orange, on repasse en marche. On ne peut recourir qu'à partir de 25. |
| 7 | Arrêter de courir | Après ~1 s, STAMINA remonte. |
| 8 | **Ctrl** | Le curseur apparaît, la caméra ne tourne plus. Re-**Ctrl** → verrouillé à nouveau. |
| 9 | Ctrl puis clic **SETTINGS** | Une fenêtre s'ouvre, bouton SETTINGS orange. **X** ou re-clic SETTINGS la ferme. |
| 10 | *First-person camera* → **ON** | Passage en 1ʳᵉ personne ; le curseur reste libre tant que la fenêtre est ouverte. Fermer → curseur bloqué. |
| 10b | Repasser **OFF** | Retour en 3ᵉ personne à une distance normale (pas collé au personnage). |
| 11 | Arrêter Play puis relancer | Le choix 1ʳᵉ personne est conservé (seulement si les sauvegardes sont actives dans Studio). |
| 12 | Se faire mal (ex. `game.Players.<TonNom>.Character.Humanoid.Health = 50` dans la barre de commande, côté **Server**) | HEALTH descend à 50 et **ne remonte pas** tout seul (attendre ~15 s pour vérifier). |
| 13 | Mourir et réapparaître | Barres à 100, caméra et menu fonctionnent toujours. |

Test à 2 joueurs (*Test → Clients and Servers → 2 Players → Start*) : chaque joueur a ses propres
barres, la course de l'un n'affecte pas l'autre.

Si un test échoue : copie-moi les lignes rouges de l'Output et dis-moi le numéro du test.

## Étape 1 bis — Mouvements (`main` ou `feature/better-animations`)

**Parcours de test automatique** : dans Studio, un parcours apparaît tout seul près du spawn
(dossier `Workspace > DevTestCourse`, construit par `Server/Systems/DevCourse`). Chaque obstacle a
une étiquette qui dit ce qui doit se passer. Il n'existe **que dans Studio** (jamais dans le jeu
publié) ; pour le désactiver : `Config.Dev.TEST_COURSE = false`.

- **Rangée 1** : murs de 2,5 à 9 studs (verts = vault, bleus = mantle, orange = sauter d'abord).
- **Rangée 2** : muret fin, 4 barrières à enchaîner en courant, bloc « pas de place ».
- **Rangée 3** : piste de glissade, tour à escalader.

| # | Test | Résultat attendu |
|---|---|---|
| 1 | **C** | Accroupi tactique : buste penché en avant, genoux pliés, pied gauche devant, garde haute ; la caméra descend. Re-**C** → debout. |
| 2 | Accroupi, avancer | Marche accroupie tactique : les jambes **alternent**, le pied qui avance se soulève, aucun pied dans le sol. |
| 3 | Accroupi puis **Espace** | Le perso se relève (ne saute pas). |
| 4 | Accroupi puis **Shift** | Le perso se relève et court. |
| 5 | Courir sur la piste puis **C** | Glissade : buste en arrière et tourné, une jambe tendue devant, un genou levé, une main au sol derrière. Finit **accroupi**. STAMINA -15. |
| 6 | Glissade puis **Espace** | La glissade s'arrête, le perso saute. |
| 7 | Glissade contre un mur | Elle s'arrête net, pas de tremblement. |
| 8 | Mur **vert** (≤ 3,6 studs), **Espace** | **Vault** rapide (~0,4 s) : une main posée, le corps bascule, les jambes passent sur le côté. STAMINA -10. |
| 9 | Les 4 barrières en sprintant, **Espace** à chacune | On les enchaîne **sans perdre sa vitesse**. |
| 10 | Muret fin | Vault par-dessus, on retombe de l'autre côté. |
| 11 | Mur **bleu** (4 à 5,5 studs), **Espace** | **Mantle** (0,7 à 0,9 s) : attrape le rebord → suspendu, les jambes se balancent → traction → genou sur le rebord → debout. Les mains touchent bien le rebord. |
| 12 | Mur **orange** (7, 9 studs) : sauter, puis **Espace** en l'air | Le perso attrape le rebord en plein saut et monte. Depuis le sol : rien. |
| 13 | Arriver **de biais** sur un mur, **Espace** | Le perso se remet face au mur en grimpant (pas de travers). |
| 14 | La tour | On monte les 4 étages en enchaînant les mantles. |
| 15 | Bloc rouge « NO ROOM » | Pas d'escalade. |
| 16 | STAMINA presque vide (< 10) | Pas d'escalade ni de glissade. |
| 17 | Course | Le buste se penche en avant ; à l'arrêt il se redresse en douceur. |
| 18 | Passer d'une animation à l'autre | Toujours un fondu, jamais de « saut » de pose. |
| 19 | En 1ʳᵉ personne (Settings) | Tout marche aussi. |

Test à 2 joueurs : le joueur 2 voit les **animations** du joueur 1, avec un petit décalage normal (réseau).
Dans l'Output, **aucune ligne rouge**. S'il y en a : copie-les-moi avec le numéro du test.

## Étape 2 — Combat de base (`feature/combat-integration`)

Deux **mannequins** apparaissent devant le point d'apparition : **Dummy** (gris, passif, se soigne
après 3 s) et **Attacking Dummy** (rouge, te frappe si tu t'approches à moins de 7 studs).
Les **boîtes rouges** qui apparaissent sont les hitbox (visibles seulement dans Studio).
Les **sons** ne jouent que si leurs IDs sont remplis dans `src/shared/Sounds.luau` (`docs/SOUNDS_FR.md`).

| # | Test | Résultat attendu |
|---|---|---|
| 1 | Clic gauche près du **Dummy** | Boîte rouge devant toi, le Dummy flashe rouge, sa vie baisse (barre au-dessus de lui). |
| 2 | **Maintenir** clic gauche | 4 coups enchaînés ; le 4ᵉ **repousse** le Dummy ; petite pause avant le combo suivant. |
| 3 | Frapper dans le vide puis attendre 1 s | Le combo recommence au coup 1. |
| 4 | Pendant que tu frappes | Tu avances plus lentement, Shift ne fait pas courir. |
| 5 | S'approcher de l'**Attacking Dummy** sans rien faire | Tu flashes rouge, contour **jaune** (étourdi), ta vie baisse, l'écran tremble un peu, le 4ᵉ coup te repousse. |
| 6 | Maintenir **F** devant lui | Contour **bleu** ; les coups flashent bleu, ta vie baisse très peu, ta STAMINA baisse. |
| 7 | Rester en garde jusqu'à STAMINA 0 | « **GUARD BREAK!** » orange, contour jaune, tu ne peux plus bloquer ni frapper ~1,5 s. |
| 8 | Appuyer sur F **juste avant** un coup | « **PARRY!** » blanc : c'est **lui** qui devient jaune (étourdi 1 s). Frappe-le pendant ce temps. |
| 9 | Spammer F | Les parades ne marchent plus (il faut lâcher F ~0,6 s avant de retenter). |
| 10 | Garde (F) avec l'Attacking Dummy **dans ton dos** | Le blocage ne marche pas de dos : tu prends le coup normalement. |
| 11 | **Q** en marchant / à l'arrêt | Petit dash dans ta direction / en arrière ; STAMINA −25 ; 2 s avant le prochain. |
| 12 | Q pile quand l'Attacking Dummy frappe | « **DODGE** » : le coup ne fait rien. |
| 13 | Tuer le Dummy | Il tombe, et revient 3 s plus tard. |
| 14 | Mourir face à l'Attacking Dummy | Tu réapparais, tout remarche (frapper, bloquer, dash). |
| 15 | Animations des coups | 1 : direct du gauche ; 2 : direct du droit (le buste tourne) ; 3 : crochet du gauche ; 4 : coup plongeant du droit, bras levé avant. Mouvement **continu** : élan, accélération, le poing dépasse un peu la cible, retour en garde avec un petit rebond. |
| 15a | Entre deux coups | Les poings **restent levés** (garde de combat) ~3,5 s après le dernier coup donné ou reçu, puis redescendent doucement. |
| 15b | Un coup qui touche | Micro-pause à l'impact (**hit-stop**) sur toi et la cible : le coup a du poids. Le 4ᵉ : pause plus longue. |
| 15c | Sons des coups | Un souffle à chaque coup, un impact quand ça touche ; jamais deux fois le même son de suite. Le 4ᵉ coup : plus grave et plus fort. |
| 16 | Animations de défense | F : avant-bras croisés devant le visage (les jambes continuent de marcher). Coup bloqué : recul. Parade : le bras droit écarte le coup. Guard break : bras qui s'ouvrent, puis titube. |
| 17 | Touché (laisse l'Attacking Dummy te frapper) | Réaction **différente selon le coup** : 1 → la tête part en arrière ; 2 → tête et buste jetés d'un côté ; 3 → de l'autre côté ; 4 → écrasé, les genoux plient, titube. De dos : projeté en avant. La tête réagit d'abord, le buste suit, puis ça se stabilise, étourdi (tête basse, bras ballants). Deux coups identiques ne donnent jamais exactement la même secousse. |
| 18 | Dashs (Q) | Avant : penché, bras en arrière. Arrière : buste en arrière, garde levée. Côtés : le corps penche dans la direction. |
| 19 | L'**Attacking Dummy** | Il joue lui aussi ses coups, ses réactions et son état étourdi. |
| 20 | Pendant une glissade / escalade : clic gauche, F, Q | Rien ne se passe. Et en garde (F) ou étourdi : pas de glissade ni d'escalade. |
| 21 | Accroupi + clic gauche ou F | Ça marche : on frappe / bloque accroupi. |

Test à 2 joueurs (*Test → Clients and Servers → 2 Players*) : vous pouvez vous frapper, bloquer et
parer entre vous ; chaque joueur voit les contours bleus/jaunes **et les animations** de l'autre.

Si un test échoue : copie-moi les lignes rouges de l'Output et dis-moi le numéro du test
(une vidéo marche très bien aussi).

## Étape 3 — Dégâts & mort (`feature/damage-death`)

Utilise le **Dummy** gris (passif) et l'**Attacking Dummy** rouge. Ils peuvent eux aussi être KO
et achevés (l'Attacking Dummy ne t'achève jamais, il te laisse te relever).

| # | Test | Résultat attendu |
|---|---|---|
| 1 | Regarder le centre de l'écran | Un petit **viseur à 4 branches** ; il devient **rouge** sur la tête d'un adversaire (chapeaux et cheveux comptent). |
| 2 | Frapper le Dummy en visant la **tête** | Sa vie baisse plus (×1,25), il reste étourdi un peu plus longtemps. |
| 3 | Viser le **torse** | Dégâts normaux ; il se **plie en avant** (coup au corps) au lieu de prendre la tête en arrière. |
| 4 | Se faire frapper à la tête par l'Attacking Dummy | Ta vision est **floue** un court instant. |
| 5 | Mettre le Dummy à 0 PV | Il tombe **mou au sol** (ragdoll), il ne meurt pas. |
| 6 | Le laisser au sol 6 s | Il se **relève** (animation : un genou, une poussée ratée, debout), étourdi, avec 25 PV. |
| 7 | Le mettre KO puis s'approcher devant lui | Une touche **[M1]** et **FINISH** apparaissent au-dessus de lui, avec une fine ligne qui montre le temps restant. |
| 8 | Clic gauche | **Finisher** : tu poses un genou, poing levé, coup de marteau au sol ; il meurt. Le kill feed (en haut à droite) affiche « Toi FINISHED Dummy ». Tu gagnes **+35 PV**. |
| 9 | Pendant ton finisher, l'Attacking Dummy te frappe | Le finisher est **annulé** ; quelqu'un peut encore l'achever. |
| 10 | Te laisser mettre KO par l'Attacking Dummy | Image désaturée, bandes noires façon film, « YOU ARE DOWN / KNOCKED OUT », une ligne qui se vide (un repère par seconde), « DROPPED BY Attacking Dummy » en bas. Tu ne peux rien faire, puis tu te relèves avec 25 PV. |
| 11 | Mourir (tomber de la map, ou te faire achever à 2 joueurs) | Réapparition après **5 s**, avec une **bulle** de protection 3 s. |
| 12 | Frapper pendant ta protection | La bulle **disparaît** dès que tu attaques. |
| 13 | Frapper un joueur protégé | « **PROTECTED** » : aucun dégât. |

Test à 2 joueurs : met l'autre KO, achève-le → le kill feed s'affiche chez les deux, ton nom en
orange ; ses **deaths** et tes **kills** augmentent (fenêtre Settings / sauvegarde). Si un joueur
**quitte en plein combat** (touché il y a moins de 10 s), le kill feed affiche « X FLED » et le
dernier qui l'a frappé gagne le kill.

### Interface (nouveau style)
| # | Test | Résultat attendu |
|---|---|---|
| U1 | En jeu | En bas à gauche : grand chiffre de vie + lignes fines (vie, endurance). Pas de boîtes arrondies. Après quelques secondes au maximum, le bloc s'estompe. |
| U2 | Prendre un coup | La ligne de vie baisse, un petit morceau rouge s'efface juste après, le chiffre flashe rouge, l'image perd ses couleurs un instant. |
| U3 | Courir jusqu'à 0 | La ligne d'endurance devient rouge et pulse, le texte dit **WINDED**. En garde (F) il dit **GUARD**. |
| U4 | Parer / se faire briser la garde | Petit mot espacé à côté de l'épaule avec un trait (PARRY, GUARD BREAK en rouge si c'est ta garde). Plus de contours bleus/jaunes. |
| U5 | Cliquer « — MENU » à gauche | Le monde se floute et se désature, liste « 01 SETTINGS », panneau avec grand titre, OFF / ON souligné, touche LEFT CTRL. « — CLOSE » referme. |
| U6 | Kill feed | Lignes de texte simples en haut à droite sur un léger fond sombre, ton nom en gras blanc avec un petit trait, l'âge de la ligne à droite. |

## Réactions aux coups (`feature/hit-reactions`)

Teste sur le **Dummy gris**
(il ne se retourne pas vers toi, donc tu peux le frapper de tous les côtés). Vise avec le
réticule : **tête** ou **corps**.

| # | Test | Résultat attendu |
|---|---|---|
| R1 | Frapper le Dummy **au corps, de face** | Il se **plie en avant autour du poing** (les bras tombent sur le ventre), il ne recule plus « à vide ». |
| R2 | Au corps, **de dos** | Le dos se cambre, il est projeté vers l'avant. |
| R3 | Au corps, par **sa gauche** puis par **sa droite** | Il se tord du côté touché (coude qui couvre les côtes) et glisse de l'autre côté. Les deux côtés sont symétriques. |
| R4 | À la **tête, de face** | Comme avant : jab = tête en arrière, cross et crochet = tête projetée sur le côté. |
| R5 | À la tête par **sa gauche / sa droite** | La tête part **à l'opposé** du poing (jamais vers le poing). |
| R6 | N'importe quel coup | Un très court arrêt **au contact** (le corps est encore en place quand le poing touche), puis la réaction ; la victime recule d'environ 1 stud. |
| R7 | Coup **bloqué** (Attacking Dummy, F) | Tu es repoussé un petit peu en garde. |
| R8 | 4ᵉ coup (finisher) | Grosse réaction + gros recul (inchangé). |
| R9 | Pieds | Pendant les réactions, les pieds restent au sol (ni enfoncés, ni en l'air). |
| R10 | À 2 joueurs : B fait un **dash (Q)** pile quand A frappe | Chez A : « DODGE » et **pas** de réaction de coup sur B (si une réaction a commencé, elle s'arrête aussitôt). |
| R11 | À 2 joueurs : A frappe B qui **bloque** | Chez A : la réaction de garde (BlockHit), jamais une réaction de coup reçu. |
| R12 | Garde (F) et garde après un coup, vue de face et de côté | Poings **devant le visage à hauteur des pommettes**, à une main de distance (pas collés à la tête), coudes **bas** qui protègent les côtes, bras **pas croisés**. |
| R13 | Frapper (clic gauche), puis **tout de suite** escalader un rebord / glisser / sauter un obstacle | Les bras font l'escalade (plus de poings levés en garde) ; en arrivant en haut, pas de garde qui revient. |

À 2 joueurs : les deux écrans doivent montrer **la même** réaction (le côté est décidé par le serveur).
Aucune ligne rouge ni jaune ne doit apparaître dans l'Output. Un avertissement jaune
`no clip named "..."` signale une animation demandée qui n'existe pas : envoie-le-moi.

## Étape 4 — Kits : Street Brawler (`feature/kits-street-brawler`)

Teste sur le **Dummy gris** (il ne bouge pas) et l'**Attacking Dummy** rouge (il frappe).
Les touches **1 2 3 4** lancent les attaques du kit, **G** l'Awakening quand la jauge est pleine.

### Attaques
| # | Test | Résultat attendu |
|---|---|---|
| K1 | **1 — Bottle Smash** sur le Dummy | Une **bouteille** apparaît dans la main droite, levée au-dessus de l'épaule, fracassée sur la tête : **éclats de verre**, il ne reste que le goulot. Le Dummy **saigne** (gouttes depuis la tête, petites taches au sol qui s'effacent) pendant 4 s. |
| K2 | **2 — Headbutt** | Mains au col, recul, coup de tête. Le Dummy reste **étourdi ~1 s**. |
| K3 | **3 — Tackle** | Tu fonces en avant, très bas. Le premier touché **tombe au sol** (ragdoll) puis se **relève** (~1,4 s). La charge s'arrête au contact. Passe à travers une garde (F). |
| K4 | **4 — Dirty Kick** | Coup de pied bas dans le tibia : la jambe du Dummy **plie** ; un joueur touché est **ralenti** 3 s. |
| K5 | Rappuyer tout de suite sur la même touche | Rien ne part : la ligne du move est **grisée** avec les secondes restantes, le chiffre **clignote rouge**. |
| K6 | Endurance trop basse | Le move indique **LOW STAMINA** et ne part pas. |
| K7 | À 2 joueurs : l'autre garde (F) | Les moves peuvent être **parés** (tu es étourdi) ou **bloqués** (sauf la Tackle, qui passe à travers). |

### Street Fury (Awakening)
| # | Test | Résultat attendu |
|---|---|---|
| A1 | Frapper (M1 et moves) | La jauge **STREET FURY** (en bas à droite) se remplit (%). Prendre des coups la remplit un peu aussi. |
| A2 | Jauge pleine | Le pourcentage laisse place à **[G] AWAKEN** qui pulse doucement. |
| A3 | Appuyer sur **G** | Animation (nuque qui craque, épaules, garde plus basse). L'image perd un peu de couleur, bords **rouge sombre** sur les côtés, souffle visible, légère lueur rouge sur le perso. La ligne devient **rouge** et se vide en 10 s. |
| A4 | Pendant Street Fury | Les 4 noms changent : **BROKEN BOTTLE** (2 entailles, gros saignement), **DOUBLE HEADBUTT** (attrape + 2 coups de tête), **TACKLE SLAM** (tackle puis frappe au sol), **KICK COMBO** (tibia puis visage : **projette** l'adversaire). Un trait rouge marque la barre. |
| A5 | Se faire frapper pendant Street Fury | Tu perds de la vie mais tu **n'es pas interrompu** (pas d'étourdissement). |
| A6 | Fin des 10 s | Les couleurs reviennent doucement sur les 2 dernières secondes, les noms reviennent. |

### Saignement (toi)
| # | Test | Résultat attendu |
|---|---|---|
| S1 | Se faire saigner (à 2 joueurs, Bottle Smash) | Le mot **BLEEDING** remplace HEALTH, la partie de la vie que le saignement va encore prendre est **rouge** au bout de la ligne et rétrécit à chaque tick ; le bord gauche de l'écran s'assombrit un peu à chaque tick. |

### Menu Kits
| # | Test | Résultat attendu |
|---|---|---|
| M1 | « — MENU » | La liste montre **01 KITS**, **02 SETTINGS** ; le menu s'ouvre sur KITS. |
| M2 | KITS | À gauche **STREET BRAWLER** (EQUIPPED) et **BOXER** (NOT AVAILABLE YET). À droite : les 4 moves avec endurance, recharge et leur version Street Fury (petit tiret rouge), puis la ligne **G STREET FURY 10 s**. |
| M3 | Cliquer BOXER | Sa fiche s'affiche (pas encore jouable, pas de bouton EQUIP). |
| M4 | Cliquer une ligne de la barre de moves (curseur libre : Ctrl gauche) | Le move part, comme avec la touche. |

Pas de son dédié encore pour la bouteille / coup de tête / tackle / tibia / Awakening : ils
utilisent les sons de coups existants (plus graves / aigus). Tu peux mettre tes IDs dans
`src/shared/Sounds.luau` : **BottleBreak, Slash, Headbutt, Tackle, KickLow, Awaken**.

## Étape 5 — Blessures (`feature/injuries`)

| # | Test | Résultat attendu |
|---|---|---|
| B1 | Se faire frapper aux jambes (à 2 joueurs : Dirty Kick ×4–5, ou M1 visés bas) | Après **25 dégâts aux jambes** : tu **boites** (marche sur la bonne jambe, plus lent −25 %), pas de sprint, la ligne d'endurance dit **LIMPING**. À l'arrêt, le poids est sur la jambe gauche. |
| B2 | Faire un kill en boitant | La boiterie **disparaît** (le kill soigne toutes les blessures). |
| B3 | Frapper le Dummy plusieurs fois à la tête / au torse / aux jambes | Des **petites marques sombres** (bleus, coupure au sourcil) apparaissent là où il a été touché (3 max par partie). Elles partent à sa mort. |
| B4 | 4ᵉ M1 visé à la **tête** | L'adversaire **saigne** un peu (3 s), même sans bouteille. |
| B5 | Descendre **sous 25 PV** | Bords de l'écran qui s'assombrissent et **respirent**, image un peu floue et moins colorée ; plus tu es bas, plus c'est fort. Ton perso est **voûté** (main sur les côtes) hors combat, **garde basse et fatiguée** en combat — les autres le voient. |
| B6 | Rester **10 s sans être touché** sous 25 PV | La vie remonte doucement (1 PV/s) **jusqu'à 25**, pas plus. Pas pendant un saignement. |
| B7 | Être KO | Les effets faible vie s'arrêtent (l'écran KO prend le relais). |
| B8 | Se faire frapper **à 70 PV ou moins** | Le perso pousse un **cri de douleur** (3 sons au hasard), entendu par tout le monde. |

Sous 25 PV tu entends aussi le **battement de cœur** et la **respiration** (seulement toi).

## Marche et course réalistes (`feature/realistic-locomotion`)

| # | Test | Résultat attendu |
|---|---|---|
| L1 | Marcher (sans Shift), filmer **de côté** | 4 temps par pas : jambes écartées (contact), le corps descend (down), la jambe passe sous le corps pied levé (pass), le corps remonte jambe tendue (up). La tête ondule légèrement. Bras le long du corps qui se balancent à l'opposé des jambes. |
| L2 | Courir (Shift) | Foulées plus longues, talon qui remonte derrière, genou devant, un instant les deux pieds en l'air, torse penché, bras qui battent. |
| L3 | Passer de marche à course et inversement | Transition douce, pas de clignotement entre les deux. |
| L4 | Sauter en marchant | L'animation de saut de Roblox (pas de marche dans les airs). |
| L5 | Vitesse | Marche plus lente qu'avant (10), sprint 22 : réglable dans `src/shared/Config.luau` (`WALK_SPEED`, `SPRINT_SPEED`). |

## Son de l'awakening, sang et peau arrachée (`feature/gore-awakening-sound`)

| # | Test | Résultat attendu |
|---|---|---|
| G1 | Jauge Fury pleine, appuyer sur **G** | Le cri de Street Fury part **au moment de l'appui** (une seule fois), puis l'animation. Les autres joueurs l'entendent aussi. |
| G2 | G en gardant F (garde) ou pendant un coup | Rien ne se passe (ni son ni activation), comme le serveur. |
| G3 | Frapper au poing 20 fois (tête et corps) | Le sang est **rare** : quelques giclées à la tête, presque jamais au corps. Le 4ᵉ coup à la tête n'ouvre une coupure qu'environ 1 fois sur 3. |
| G4 | **Bouteille** (touche 1) en visant la **tête** | Giclée de sang **à chaque fois**, saignement plus long. Une **lacération** apparaît du côté de l'attaquant (front, tempe ou joue) : bord de peau déchiré, chair rouge, sang qui coule. **Jamais** d'os cassé ni de cerveau. |
| G4b | Bouteille en visant le **corps** | Le verre se brise sur le torse, sang souvent. Lacération sur la poitrine ou le ventre, avec du gras jaune ; le t-shirt reste dessiné autour. |
| G5 | Bouteille **au même endroit** 3 fois | La même plaie grandit : petite → moyenne → grande. Elle ne devient pas plus profonde jusqu'aux os. |
| G5b | **Broken Bottle** à la tête puis au corps | **Entailles** longues et nettes, en biais. À la taille L : du muscle rouge foncé au fond (corps), ou un peu d'os pâle au fond (tête). |
| G6 | Frapper ailleurs sur la même partie | Une **nouvelle** plaie (3 max par partie ; au-delà, la plus proche grandit). |
| G7 | 2 joueurs | Les deux écrans voient **les mêmes** plaies, au même endroit. |
| G8 | Mourir / réapparaître | Le corps redevient intact. |
| G9 | Regarder de près une tête ou un torse blessé | La tête et le torse gardent **exactement leur forme et leur aspect** : tête bien ronde, torse aux arêtes arrondies, ni facettes ni lignes, ni grain sur la peau. Seule la plaie change. Le visage est à sa place. Le t-shirt et le pantalon sont alignés autour de la plaie. |
| G11 | Entrer en jeu avec un avatar à tête spéciale ou avec de gros accessoires | La tête devient la tête **classique** (même visage, même couleur). Les cheveux, chapeaux et lunettes restent ; les gros accessoires et ceux du dos, de la taille ou des épaules disparaissent. Un package de corps R6 est retiré (corps en blocs classique). |
| G12 | Bouteille (touche 1) plusieurs fois | Des **bouts de verre** restent plantés dans la peau (un peu de sang autour, parfois une petite coulure). Environ 1 fois sur 3, c'est seulement du verre, sans vraie plaie. À la casse, beaucoup d'éclats volent : des gros et des petits qui brillent et restent un moment au sol. |
| G13 | Plaie en bas du torse, puis attendre | Les gouttes de sang tombent **de la plaie**, pas de la tête. |
| G14 | Plaie près du visage, regarder de près | Le visage est d'un seul morceau : **aucune ligne** sur les yeux ni sur la bouche, **aucune rayure** près de la plaie. |
| G10 | Ta propre tête blessée, en 1re personne | Rien ne gêne la vue. |

Les plaies demandent d'importer `WoundKit` (voir `docs/WOUNDS_FR.md`). **Il faut le ré-importer** après cette mise à jour : il contient maintenant les morceaux de la tête.

Note : le sang réaliste et les plaies demandent de remplir honnêtement le **questionnaire de
maturité** de l'expérience (Creator Dashboard). Pour un public plus jeune, mettre
`SKIN_TEAR = false` dans `src/shared/Config.luau` (section `Injuries`).

## Étape 6 — Kit Boxer (`feature/boxer`)

Menu **KITS** → **BOXER** → **EQUIP** (gratuit). Les touches 1–4 et G changent aussitôt.

| # | Test | Résultat attendu |
|---|---|---|
| X1 | **1 — Jab Rush** sur le Dummy | 4 jabs rapides du gauche en avançant, chacun touche (4 petits coups, le Dummy reste dans la rafale). |
| X2 | **2 — Uppercut** | Flexion puis montée explosive : le Dummy **décolle** et tombe (ragdoll ~1,2 s), puis se relève. |
| X3 | **3 — Slip** puis l'Attacking Dummy frappe pendant ~0,5 s | Tu **esquives** (« DODGE »), et tu ripostes tout seul avec un **crochet** qui l'étourdit. Sans coup reçu : juste l'esquive. |
| X4 | **4 — Liver Shot** (à 2 joueurs) | Crochet au corps : la victime se **plie sur le côté**, est étourdie ~1 s et perd **40 d'endurance**. |
| X5 | Remplir la jauge, **G** | **KNOCKOUT MODE** : le boxeur sautille, touche ses gants, garde plus serrée. Mêmes effets d'écran que Street Fury. |
| X6 | Pendant Knockout Mode | 1 = **JAB FLURRY** (6 coups, dont un direct du droit), 2 = **RISING UPPERCUT** (décolle plus haut), 3 = **SLIP & HOOK** (fenêtre plus longue, contre plus fort), 4 = **KNOCKOUT COMBO** : corps, tête, tête, gros uppercut — si le 1ᵉʳ coup touche, les suivants ne ratent pas, le dernier met au sol. |
| X7 | Menu KITS | « 2 OF 2 AVAILABLE », Boxer **EQUIPPED** une fois choisi, le choix reste au prochain lancement. |
| X8 | Finishers | Voir la section « Finishers cinématiques » plus bas. |
| X9 | Touche **W** (AZERTY) / **Z** (QWERTY) | Bascule **1ʳᵉ ↔ 3ᵉ personne**, le choix est sauvegardé (même réglage que dans SETTINGS, où la touche est rappelée). |

## Étape 7 — Progression (`feature/progression`)

À tester à **2 joueurs** (Test > Clients and Servers, 2 joueurs) : les dummies ne donnent rien.

| # | Test | Résultat attendu |
|---|---|---|
| P1 | En jeu | En bas à gauche, au-dessus de la vie : **LV 1** et une fine ligne d'XP. |
| P2 | Frapper l'autre joueur | Toutes les ~5 s : petite ligne **DAMAGE +x XP** au-dessus de la vie, la ligne d'XP avance. |
| P3 | Le mettre KO puis l'achever | **FINISHER +75 XP · +15 COINS**. Sans finisher (il tombe de la map après tes coups) : **KILL +50 XP · +10 COINS**. |
| P4 | À 3 : A frappe C, B l'achève | A reçoit **ASSIST +20 XP · +4 COINS**. |
| P5 | Passer niveau 2 (≈ 3 kills) | Bandeau sobre **NEW LEVEL — LEVEL 2** en haut, ~2,5 s. Ton niveau s'affiche partout. |
| P6 | Menu → **PROFILE** | Niveau, XP vers le prochain niveau (barre), coins, kills / deaths / K/D / wins à vie. |
| P7 | Regarder l'autre joueur | Au-dessus de sa tête : **niveau + nom** (pas au-dessus de toi), discret de loin, caché derrière les murs. |
| P8 | Maintenir **Tab** | Classement du serveur à droite : niveau, kills, morts de la partie, trié par kills ; ta ligne marquée. Le kill feed se cache pendant ce temps. |
| P9 | Kill feed | Le niveau des joueurs est écrit à côté de leur nom. |
| P10 | Jouer 5 min | **PLAYTIME +15 XP · +2 COINS**. |
| P11 | Menu KITS | Coins affichés en haut. (Les états « UNLOCKS AT LEVEL 10 » / « BUY · 500 » serviront aux futurs kits : Street Brawler et Boxer restent gratuits.) |

## Étape 8 — Duels (`feature/duels`)

À tester à **2 joueurs** (Test > Clients and Servers). Le parcours de test n'a plus de textes flottants (les couleurs restent).

| # | Test | Résultat attendu |
|---|---|---|
| D1 | Menu → **DUEL** | Ton rang (BRONZE au départ) et ton ELO (1000), l'échelle des rangs, **FIND MATCH**, puis la liste des joueurs avec **CHALLENGE** (ou la raison : IN A DUEL, IN COMBAT, BLOCKS DUELS, KNOCKED OUT, CHALLENGE SENT · 10). |
| D2 | A clique **CHALLENGE** sur B | Chez B : « A challenges you to a duel » à gauche, **Y** accepte / **N** refuse (ou clic), ligne de 15 s. Refus ou temps écoulé → A voit la raison. |
| D3 | B accepte | Les deux sont téléportés dans une **arène** fermée. En haut au centre : CHALLENGE · ROUND 1, le score, le niveau / nom / vie de l'adversaire. **3, 2, 1, FIGHT** (bloqués pendant le compte). |
| D4 | Mettre l'autre à 0 PV | Pas de KO au sol ni de finisher : **ROUND 1 — YOU**, il tombe, 3 s, manche suivante avec vie / endurance pleines. |
| D5 | Gagner 2 manches | **VICTORY 2 — 1** (+40 XP · +8 COINS), l'autre **DEFEAT** (+10 XP), puis retour à l'arène libre après 6 s. Rejouer un défi contre la même personne dans les 3 min → pas de récompense. |
| D6 | Pendant le duel | Impossible de changer de kit, personne d'autre ne peut te toucher, tes gains n'apparaissent pas en bas à gauche, un LEVEL UP attend la fin du duel. |
| D7 | Les deux cliquent **FIND MATCH** | « SEARCHING · 0:03 » + CANCEL, puis match **RANKED** automatique. Fin : ELO **1000 → 1016** (+16), rang et barre vers le rang suivant ; victoire +100 XP · +25 COINS, défaite +30 XP. |
| D8 | Quitter le jeu en plein duel | L'autre gagne par **forfait**. |
| D9 | SETTINGS → **BLOCK DUEL REQUESTS** | Les autres voient BLOCKS DUELS et ne peuvent plus te défier. |
| D10 | PROFILE | Ligne **RANKED** (rang, ELO, victoires / défaites classées) et **DUEL WINS**. |

## Étape 9 — Quêtes quotidiennes (`feature/daily-quests`)

Comme le reste de la progression, ça compte **contre de vrais joueurs** (test à 2).

| # | Test | Résultat attendu |
|---|---|---|
| Q1 | Menu → **QUESTS** | 3 quêtes du jour, chacune avec sa phrase (« Get 5 kills », « Land 20 hits to the head »…), sa récompense (+XP · +coins), un compteur 0 / 5 et une ligne de progression. En bas : « NEW QUESTS IN hh:mm:ss » (minuit UTC). |
| Q2 | Faire ce que demande une quête | Le compteur avance (même menu ouvert). |
| Q3 | Atteindre l'objectif | En bas à gauche : **QUEST +110 XP · +55 COINS**, la quête passe à **DONE**. |
| Q4 | Quitter puis revenir le même jour | Mêmes quêtes, même progression. |
| Q5 | Après minuit UTC | 3 nouvelles quêtes. |

## Étape 10 — Boutique (`feature/shop`)

| # | Test | Résultat attendu |
|---|---|---|
| B1 | Menu → **SHOP** | 4 catégories (TITLES, OUTFITS, KILL EFFECTS, EMOTES), tes coins en haut, chaque article avec son prix (ou LEVEL x / NEED x MORE). |
| B2 | **BUY** puis **CONFIRM** sur un article abordable | Les coins baissent, l'article passe à **EQUIP**. |
| B3 | **EQUIP** un titre | Il apparaît en petit sous ton nom au-dessus de ta tête (vu par l'autre joueur). Survoler EQUIPPED → TAKE OFF le retire. |
| B4 | EQUIP une tenue | Ton haut et ton pantalon prennent les couleurs (les vêtements de l'avatar sont retirés). Retirer une tenue s'applique à la prochaine vie. |
| B5 | Effet de kill équipé, achever quelqu'un | Poussière / verre brisé / gros impact (écran qui tremble, couleurs qui pâlissent) au moment du coup. |
| B6 | Touche **B** hors combat | Ton émote se joue (SHRUG gratuite au départ), les autres la voient. Juste après un coup : rien. |

## Finishers cinématiques (`feature/cinematic-finishers`)

Mettre un adversaire KO (le Dummy suffit), se placer devant, **clic gauche**.

| # | Test | Résultat attendu |
|---|---|---|
| F1 | **Street Brawler** sur un KO (couché **ou resté debout**) — **ré-importer `WoundKit` avant** | Bandes noires. La victime est allongée sur le dos devant lui, tête vers lui. Plan large de côté : le corps au sol, le perso sort une **grosse batte**. Gros plan sur la victime (vue de sa gauche) qui lève la tête et tend la main en suppliant (on l'entend) ; le bras ne bouche pas l'image. Plan du sol : comme au **golf**, à deux mains, il aligne la batte sur la tête, l'arme en arrière vers sa droite, puis **balaie** la tête au ras du sol de sa droite vers sa gauche et finit la batte au-dessus de l'épaule gauche. Plan de côté tenu : la **tête explose** en vraies pièces — morceaux de crâne (peau dehors, os dedans), cerveau, yeux, dents ; gerbe de sang, fine brume ; au sol, une éclaboussure et des traînées **sur le sol, jamais sur le corps**. Il reste la vraie mâchoire du bas avec ses dents, la peau du menton déchirée, les vertèbres ; le cou gicle par saccades, une flaque s'étend. Caméra normale ensuite (~3,3 s). |
| F2 | **Boxer** sur un KO — **ré-importer `WoundKit` avant** | Il **relève** l'adversaire, deux coups au corps, crochet droit, crochet gauche, direct (la tête part d'un côté puis de l'autre, un peu de sang). Puis un **crochet du gauche dans son flanc droit, sous les côtes** : le poing rentre (craquement, ton son du coup final, gerbe de sang, éclats de côte), fouille, et **arrache le vrai foie** (avec la vésicule verte). Il le tient **à bout de bras** sur le côté, il dégouline, il le regarde (plan de face, bien visible) ; la victime s'effondre, un **trou** dans le flanc droit avec des **côtes cassées** dedans, à travers le t-shirt, qui gicle par saccades, flaque dessous. Il **ouvre la main : le foie tombe** au sol (plan bas), bruit mouillé et éclaboussure quand il touche le sol. ~4,1 s. |
| F3 | Pendant un finisher, un 3ᵉ joueur frappe l'attaquant | Rien ne se passe : l'attaquant est intouchable pendant la scène. |
| F4 | La victime (2ᵉ joueur) | Elle voit la même cinématique (bandes noires et caméra), puis son écran de mort. |
| F5 | Un 3ᵉ joueur qui regarde | Pas de cinématique pour lui (sa caméra reste normale), mais il voit l'animation, la batte, le sang et entend les coups. |
| F6 | Après le finisher | Le joueur peut de nouveau bouger et attaquer normalement, la caméra est revenue comme avant. |
| F7 | Un 3ᵉ joueur tue l'attaquant (ou il quitte) avant le coup final | La cinématique s'arrête tout de suite chez les deux, la caméra revient, la victime retombe toujours KO (quelqu'un d'autre peut l'achever). |
| F8 | Pendant la cinématique | Impossible de dasher, bloquer ou attaquer ; on ne peut pas lancer un duel avec l'attaquant. |
| F9 | Un joueur qui arrive après (ou qui était loin) | Il voit le corps sans tête, le cou ouvert, sans l'explosion. |

### Bleus

| # | Test | Résultat attendu |
|---|---|---|
| B1 | Frapper un Dummy au visage (M1, Boxer, Street Brawler) | Un **bleu** apparaît **là où le coup touche**, du côté de l'attaquant : tache irrégulière, plus foncée au centre, qui s'estompe sur les bords. |
| B2 | Regarder le bleu ~20 s puis ~1 min | Il passe du **rouge** au **violet**, puis au **bleu-violet**. |
| B3 | Retaper au même endroit | Le même bleu **grandit et fonce** ; sur le visage, ça **gonfle** (joue, œil, arcade). Un coup très fort sur un bleu déjà gros **ouvre l'arcade** (petite coupure, filet de sang). |
| B4 | Frapper le torse / les jambes d'un Dummy | Bleus sur le torse / la jambe touchée (4 max par partie, sinon le plus proche grossit). |
| B5 | Un joueur avec un t-shirt / un pantalon | Pas de bleu visible à travers les vêtements ; ceux du visage, oui. |
| B6 | Dummy laissé tranquille | Sa vie revient vite, mais ses blessures restent : **après 13 s** sans coup, elles guérissent **petit à petit** (un bleu pâlit d'un cran puis s'efface en douceur, puis le verre, puis les coupures), une toutes les 1,5 s. |
| B7 | Kill / réapparition | Les bleus disparaissent. Un Dummy tué reste au sol **25 s** avant de réapparaître (le sang et les morceaux restent ~30 s). |

Les sons `BatDraw`, `BodyShot` et `KnockoutPunch` (`src/shared/Sounds.luau`) n'ont pas encore leur propre son : ils empruntent les coups existants avec une autre hauteur. `BatSwing`, `VictimPlea` et `BatCrush` ont leurs IDs.

## Étape 11 — Map : Marrow District (`feature/city-map`)

**Avant de tester** : vérifie dans Studio que `Lighting` → `Technology` = **Future**. Rojo le règle maintenant (`default.project.json`) ; sinon mets-le à la main (un script ne peut pas le changer). Si ce n'est pas Future, l'Output affiche un avertissement `[Ambience] Lighting.Technology is ...` : sans Future, pas de flaques de lumière sous les lampadaires ni de halo des néons.

| # | Test | Résultat attendu |
|---|---|---|
| C1 | Lancer le jeu | Le quartier se construit en quelques secondes autour de toi (le sol et les spawns d'abord). 4 rues, 2 ruelles, carrefour avec taxi accidenté et chantier, parking « Lot 9 », terrain de basket grillagé sous un pont ferroviaire, cour de chargement, chantier, casse. Tu apparais dans une des 10 zones (rue, ruelle, parking, terrain, cour, sous le pont), jamais sur le tablier du pont. La Baseplate grise de Studio a disparu, la route n'a pas de quadrillage qui clignote. |
| C2 | Après-midi | Ciel couvert, lumière grise et terne, brume au loin. Façades en brique sale, fenêtres en retrait (certaines condamnées ou cassées), clims, gouttières, escaliers de secours, châteaux d'eau sur les toits. |
| C3 | Nuit (attendre ~6 min ou changer `DAY_TIME` dans `Server/Systems/Ambience`) | Lampadaires orangés (quelques-uns grésillent, d'autres sont morts), environ un tiers des fenêtres allumées (chaud, bleu télé, néon froid), néons « DUFFY'S BAR », « DELI »… |
| C4 | Grimper | Toit du garage, de l'entrepôt, du vieux hall, puis le tablier du pont : chaque marche est un vault ou un mantle. Le pont s'atteint aussi par l'escalier et par l'échafaudage du terrain. |
| C5 | Météo (Studio : barre de commande `workspace:SetAttribute("WeatherForce", "Rain")`, ou `"Storm"`, `"Fog"`, `"PowerCut"` la nuit) | **Pluie** : ciel plus sombre, gouttes autour de toi, flaques qui brillent, gouttières qui coulent, petit texte « RAIN » en haut à gauche. **Orage** : éclairs (flash blanc) puis tonnerre. **Brouillard** : on voit à ~90 studs. **Coupure** (nuit) : tout clignote, 40 s de noir avec des lumières de secours rouges, puis le courant revient en vague. |
| C6 | Sans rien forcer | Un premier événement arrive 3–5 min après le lancement, puis 4–7 min de calme entre deux. |
| C7 | En duel | Pas de texte d'événement à l'écran. |
| C8 | Parcours de test (Studio) | Toujours là, au sud du quartier. |
| C9 | Les 2 mannequins d'entraînement | Ils sont au milieu du terrain de basket (la Cage), debout sur le sol, éclairés. Pas sous la map. |
| C10 | Nuit, loin des lampadaires | Ton personnage (et les autres) reste lisible : une petite lumière chaude et douce l'éclaire (seulement la nuit et pendant une coupure de courant). |
| C11 | Nuit : toits du garage et de l'entrepôt bas, cour de chargement, ruelle, parvis de la Cage | Chaque zone de combat a sa propre lumière (projecteur, ampoule sur un fil, tube sous le pont) : plus de grande zone bleu noir. |
| C12 | Depuis le pont, sauter vers l'entrepôt au nord (S1) | Impossible de monter sur son toit (mur invisible) : on ne sort plus de la map par là. |

### Boutiques en ville (vêtements et émotes)

| # | Test | Résultat attendu |
|---|---|---|
| S1 | Entrer dans la boutique de vêtements, s'approcher du comptoir | Au-dessus du comptoir : le nom de la boutique en petit, puis **[E] ── BROWSE CLOTHES** (style du jeu, pas la bulle grise de Roblox). Lisible même la nuit. |
| S2 | Appuyer sur **E** | Le menu s'ouvre (animation normale) sur **SHOP**, catégorie **OUTFITS** déjà sélectionnée. Le prompt disparaît tant que le menu est ouvert. |
| S3 | Même chose au comptoir de la boutique d'émotes | **BROWSE EMOTES** → SHOP sur **EMOTES**. Si le menu est déjà sur SHOP, la liste glisse vers la bonne catégorie. |
| S4 | Fermer le menu (CLOSE) près du comptoir | Le prompt revient. Le menu → **SHOP** marche toujours comme avant. |
| S5 | En duel, mort ou KO près d'un comptoir | Aucun prompt, E ne fait rien. |
| S6 | Mobile / émulateur tactile (Studio : Device) | Le prompt affiche **TAP** ; toucher le prompt ouvre la boutique. |
| S7 | Mannequins de la boutique de vêtements | Chacun porte une tenue du SHOP (haut + pantalon aux couleurs de GREY SWEATS, OLIVE…). S'il n'y a pas de mannequin, rien ne casse. |
| S8 | Le bar | On peut y entrer par l'angle (porte large de 8) ; comptoir, tabourets, billard, juke-box, lumière chaude ; pas de prompt de boutique dedans. |

### v4 : map plus grande, portes, graphismes

| # | Test | Résultat attendu |
|---|---|---|
| V1 | Se promener | La map est plus grande (~262 × 270 au lieu de ~240 × 240) : avenue et rue Kerr plus larges (chaussée et trottoirs), terrain sous le pont plus long. Toujours 10 spawns, les mannequins d'entraînement toujours dans la Cage. |
| V2 | Marcher vers une boutique (THREADBARE, REWIND, le bar — y compris la porte arrière du bar sur la cour) | Portes vitrées doubles (cadre métal, barres de poussée) qui s'ouvrent seules vers l'intérieur quand tu arrives à ~10 studs, et se referment quand plus personne n'est près. Elles ne se referment jamais sur toi. |
| V3 | Combat devant une porte fermée | Un corps projeté contre la porte fermée est arrêté par elle (normal). Une porte ouverte ne bloque rien. |
| V4 | Fenêtres | Toutes les fenêtres (étages, rez-de-chaussée, arrière des immeubles) ont le même cadre : montants, linteau, appui, traverse ; celles des immeubles lointains ont au moins un appui. |
| V5 | Voitures | Toutes les berlines (garées, taxi, épave du parking, voiture sur cric) ont le même modèle détaillé (jantes, passages de roue, rétros, calandre, plaques, joints de portes). L'épave : rouille, capot soulevé, portière enfoncée, une roue manquante. Le van a le même niveau (cabine vitrée, pare-brise incliné, phares). |
| V6 | Mannequins de la boutique de vêtements | Mieux faits (cou, épaules, bras et jambes articulés, mains, chaussures) et chacun dans une pose : main sur la hanche, bras levé, en marche, bras croisés. Ils prennent toujours les couleurs de la tenue. |
| V7 | Bout est de la rue Kerr (à côté de CHECKS CASHED) | Plus de « ROAD CLOSED » ni de barrières : un kiosque à journaux éclairé (« NEWS LOTTO SMOKES ») contre le mur, un banc, une vieille pub de diner en hauteur. |
| V8 | Parcours de test (Studio) | Toujours au sud, sans chevaucher la ville (déplacé un peu plus au sud). |

### v5 : portes de saloon, PNJ, train

| # | Test | Résultat attendu |
|---|---|---|
| N1 | Entrer chez DUFFY'S par l'entrée d'angle | Deux battants de saloon (à mi-hauteur, à lattes). Ils ne bloquent jamais : tu passes à travers, ils s'ouvrent **dans le sens opposé à toi** (~80°), restent ouverts tant que tu es dans l'embrasure, puis reviennent en battant plusieurs fois de part et d'autre avant de s'arrêter. Pareil en sortant (ils s'ouvrent vers l'extérieur). Les autres portes (vitrées) marchent comme avant. |
| N2 | Le bar | Un barman (Duffy, tablier sombre) derrière le comptoir essuie le comptoir avec un chiffon ; 2–3 clients (tabourets, box, billard) : assis, accoudés, bras croisés ou sur leur téléphone. Tous en R6 bloc, comme des joueurs. |
| N3 | THREADBARE et REWIND | Un vendeur derrière chaque comptoir (col à la couleur de la boutique, badge). Le prompt **[E] BROWSE…** marche toujours normalement. |
| N4 | S'approcher d'un PNJ (moins de ~12 studs) | Il tourne la tête vers toi (doucement, jamais à 180°). À ~8 studs, bulle de chat : vendeur « Fresh threads, cheap. » / « Got moves? Pick one. », barman « What'll it be? »… Une seule fois, puis plus avant ~40 s. |
| N5 | Frapper / utiliser un move sur un PNJ, foncer dedans | Rien : pas de dégâts, pas de verrouillage, pas de nom ni de barre de vie au-dessus, il ne bouge pas d'un pouce. |
| T1 | Forcer un train (Studio, barre de commande côté **serveur**) : `workspace:SetAttribute("TrainForce", true)` | 5 s d'alerte : les deux signaux au bout du pont passent du vert (au repos) au rouge clignotant, la caméra tremble un peu si tu es près des voies (à moins de 60 studs). Puis une locomotive rouge (phares allumés, numéro 4417) + un wagon couvert tagué + un wagon-citerne sortent du tunnel, traversent le pont à ~70 studs/s, roues qui tournent, et rentrent dans l'autre tunnel. Le tremblement grandit quand le train approche. |
| T2 | Rester sur la voie (même avec toute ta vie, même juste après le spawn) | **Toujours mortel** : bruit de choc, le corps est **démembré** (tête, bras, jambes arrachés, projetés avec le train, moignons rouges avec l'os, sang qui gicle, flaque sous le torse), la victime **hurle**. Tous les joueurs voient la même chose. Ta caméra suit ton torse jusqu'au respawn. |
| T3 | Se faire frapper par quelqu'un juste avant le train | Fil des kills : « <lui> threw <toi> under a train » (il a le kill). Sinon : « <toi> was hit by a train ». |
| T4 | Sans rien forcer | En Studio : un train ~15 s après la construction de la ville puis toutes les ~35 s. En jeu publié : 40–70 s après le lancement, puis toutes les 95–155 s, en alternant le sens. |
| T5 | En duel | Jamais touché par le train. |

| T6 | Sons du train | Klaxon au début de l'alerte puis quand la loco sort du tunnel ; bruit de roulement (en 3D) qui suit le train, plus fort quand il est proche. |

### v6 : musique, parc secret, orage

| # | Test | Résultat attendu |
|---|---|---|
| M1 | Se promener dehors | Une musique d'ambiance douce (jour), qui passe en fondu à celle de nuit au crépuscule. |
| M2 | Marcher vers DUFFY'S | À ~50 studs on entend la musique du bar, **étouffée** (comme à travers les murs), de plus en plus fort. En entrant : claire, la musique de dehors baisse. 3 enceintes au mur. Pareil pour THREADBARE et REWIND (2 enceintes chacune). |
| M3 | Deux joueurs dans le bar | Même chanson au même moment pour les deux. Quand une chanson finit, la suivante de la playlist démarre. |
| M4 | Pluie | Le bruit de pluie s'**ajoute** à la musique (elle ne la remplace pas), monte et descend avec la pluie, plus faible sous un toit et dedans. |
| M5 | Orage (`workspace:SetAttribute("WeatherForce", "Storm")`) | Texte « THUNDERSTORM », ciel noir, pluie bien plus dense et penchée par le vent, pluie plus forte au son, éclairs fréquents (un éclair dessiné dans le ciel + flash de l'écran) toutes les ~10–25 s. |
| M6 | Le parc secret (passage discret) | Arbres, bancs, lampadaires, allées, massifs, aucun animal. Toujours **ensoleillé** (même la nuit ou sous l'orage : la lumière change en ~1,5 s en entrant, revient en sortant), pas de pluie ni d'éclair dedans. Sa musique sort des enceintes du parc ; la musique de la ville et la pluie se coupent. |
| M7 | Menu → SETTINGS → SOUND → Music OFF | Plus de musique (dehors, bar, boutiques, parc). Pluie, train et coups restent. Sauvegardé. |
| M8 | En duel | Pas de musique de ville ni de pluie. |

#### v6 : SpezCola, zone sûre du parc, accessoires des PNJ

| # | Test | Résultat attendu |
|---|---|---|
| C1 | Trouver une machine SpezCola (chez DUFFY'S ou devant, près de la Cage, dans le parc) | Grande machine rouge éclairée, logo SpezCola. De près (~3–25 studs) on entend son **bourdonnement** en 3D. |
| C2 | Prompt **[E] GET A SPEZCOLA** (maintenir 0,3 s) | Gratuit. Le bouton s'allume, petit temps (le « clunk »), puis une **canette** tombe du bac avec un bruit et roule un peu vers toi. Max 4 canettes par machine (la plus vieille disparaît), elles disparaissent seules après ~90 s si personne ne les ramasse. |
| C3 | La canette | Rouge, bords argentés, opercule et languette, anneau blanc, « Spez » en blanc avec une vague. |
| C4 | Prompt **[E] PICK UP** sur la canette au sol | La canette disparaît du sol et va dans ta **poche** : en bas à droite, juste au-dessus de la liste des moves du kit, un petit emplacement apparaît : « POCKET ─── », une petite canette dessinée, « SPEZCOLA » et à droite **[R] DRINK** (la touche s'allume une fois). Sans kit : l'emplacement est à la place de la liste des moves. Tu ne bois pas tout de suite, tu peux te balader avec. |
| C5 | Appuyer sur **R** (ou cliquer sur l'emplacement avec le curseur libre) | La canette apparaît dans la main droite, animation de boisson visible par tous (canette à la bouche, tête en arrière, deux gorgées, ~2,3 s), tu marches un peu plus lentement. À la fin elle est un peu écrasée et jetée, disparaît 10 s après. L'emplacement de la poche disparaît dès le début. R sans canette en poche : rien. |
| C6 | **Max 1** : avec une canette en poche, regarder la machine | Le prompt dit **YOU HAVE ONE**. Le maintenir quand même : rien ne tombe, une petite ligne « ALREADY CARRYING ONE » s'affiche ~2 s près de la poche. Une canette au sol dit **POCKET FULL** (la ramasser : refusé, même ligne). |
| C7 | **Max 1** : prendre une canette à la machine **sans la ramasser**, puis re-essayer | Le prompt de la machine dit **TAKE YOUR CAN** ; le maintenir : rien ne tombe, ligne « YOUR CAN IS ON THE FLOOR ». Une fois ta canette ramassée (ou ramassée par quelqu'un d'autre / disparue), la machine redevient « GET A SPEZCOLA » (avec toujours 4 s minimum entre deux canettes). |
| C8 | R en duel, juste après un combat, en tenant un os (arme) | Rien ne se passe, la canette **reste** en poche. Le mot à côté de [R] est grisé et dit **NOT IN A DUEL** / **IN COMBAT** / **HANDS FULL** (et la même ligne s'affiche si on appuie). KO : la poche est cachée avec le reste du HUD, la canette est gardée. En bloquant / en attaquant : rien (le serveur refuse, la canette reste). |
| C9 | Se faire frapper (ou frapper / bloquer / glisser) en buvant | La canette tombe, l'animation est coupée. La canette est **perdue** (pas de retour en poche). |
| C10 | Mourir avec une canette en poche | Elle **tombe** de ta poche là où tu es mort (un petit saut sur le côté) ; n'importe qui peut la ramasser ([E] PICK UP). Tu réapparais la poche vide. Quitter le jeu : la canette est perdue. |
| C11 | Deux joueurs : A prend une canette, B la ramasse | B l'a en poche ; A peut de nouveau utiliser la machine (sa canette n'est plus au sol). |
| P1 | Entrer dans le parc | Petit texte discret en haut « SAFE ZONE — No fighting in the park » qui disparaît après ~3 s. |
| P2 | Frapper / move / dash-attaque / finisher dans le parc, ou frapper quelqu'un dans le parc depuis l'extérieur | Rien : pas d'animation de coup (côté client), le serveur refuse tout, personne n'est touché ni achevé dans le parc. Le dash et le blocage marchent toujours. |
| A1 | Regarder les PNJ de près | Cheveux en couches (frange, chignon, cheveux longs, rasé…), casquettes avec visière et bouton, bonnets avec revers, casquettes plates, casques audio, lunettes avec monture et verres (parfois solaires), boucles d'oreilles, montre, collier. Barman : tablier avec bretelles, poche (stylo, décapsuleur) et serviette sur l'épaule. Vendeurs : badge sur cordon à la couleur de la boutique. Rien ne flotte quand ils bougent. |

#### v7 : sons, train, météo plus immersive

| # | Test | Résultat attendu |
|---|---|---|
| D1 | Mourir (train, chute, finisher, `Health = 0`) | **Plus de « oof »** de Roblox. Sous le train : on entend toujours le **fracas** et le **cri**. |
| D2 | Attendre deux trains de suite (hors Studio) | Entre la fin d'un passage et l'alerte du suivant : **95 à 155 s** (avant 70 à 130). En Studio ça reste court (35 s). |
| D3 | S'approcher d'une porte vitrée de boutique, puis s'éloigner | Un son d'**ouverture** (en 3D, depuis la porte) quand elle s'ouvre, un son de **fermeture** quand elle se referme. Un seul son par porte double (pas deux). Faire des allers-retours rapides : pas de son en rafale. |
| D4 | Passer les portes de saloon de DUFFY'S | Son d'ouverture quand on les pousse ; quand on s'éloigne, son de fermeture au moment où les battants **se recroisent au milieu** (une seule fois, pas à chaque battement). |
| R1 | Pluie, dehors à découvert (`WeatherForce = "Rain"`) | **Rarement** (toutes les ~6–12 s), 1–2 petites **gouttes sur l'écran** sur les côtés ou en haut (jamais au centre), elles glissent un peu vers le bas et sèchent en 1–3 s. Un peu plus souvent en orage. **Aucune** sous un auvent, sous le viaduc, dans le bar / une boutique, dans le parc, en duel. |
| R2 | Pluie, regarder une flaque proche | Petits **cercles** qui s'ouvrent et disparaissent à la surface. |
| R3 | Pluie, rester dehors en 3ᵉ personne | Petites éclaboussures sur la **tête et les épaules** de ton perso. En 1ʳᵉ personne : pas d'éclaboussures devant l'objectif. |
| R4 | Pluie / orage, regarder la pluie quelques secondes | Les gouttes tombent **penchées** (un peu sous la pluie, beaucoup en orage) et de temps en temps une **rafale** les penche plus fort 1–3 s. |
| R5 | Orage : regarder les éclairs | L'éclair tombe dans une direction au hasard (souvent devant toi), le flash est **bleuté** et éclaire tout l'écran. Environ 1 sur 5 tombe **près** : flash plus fort, la rue s'éclaire un instant, la caméra **tremble** un peu, et le tonnerre claque presque tout de suite. |
| F1 | Brouillard (`WeatherForce = "Fog"`) | Une **nappe basse** qui dérive lentement au ras du sol autour de toi (pas dans le bar / les boutiques ni dans le parc), un **halo** doux autour des lampadaires allumés, la musique et la pluie de la ville un peu **étouffées**. Tout revient à la normale à la fin. |
| F2 | Coupure de courant (de nuit : `WeatherForce = "PowerCut"`) | Les lumières **grésillent / clignotent ~3,5 s** (son `PowerBuzz`), puis le transformateur de la **sous-station** (nord du Lot 9) **saute** : gerbe d'**étincelles**, fumée, flash bleu-blanc (son `TransformerBlow`). Pendant le noir, les lumières rouges de secours **pulsent** doucement. Le retour en vague marche comme avant. |
| F3 | Être dans le parc pendant pluie / brouillard / coupure | Rien de tout ça : toujours ensoleillé, pas de gouttes, pas de brume, pas d'étincelles. |

#### v8 : pluie réaliste sur l'écran, tonnerre, transformateur, grésillement

(R1 ci-dessus est remplacé par ces tests. Avant : importer les images de `assets/raindrops/`, voir `docs/RAIN_FR.md`.)

| # | Test | Résultat attendu |
|---|---|---|
| L1 | Pluie **sans** les IDs d'images (tous à `0`) | **Aucune** goutte sur l'écran (plus les petites taches rondes). Le reste de la pluie marche. |
| L2 | Pluie, dehors à découvert, IDs collés | De temps en temps (≈ 1 goutte toutes les 3 s) une **vraie goutte d'eau** se pose, surtout sur les côtés / en haut, presque jamais au centre : reflet en haut à gauche, bord sombre, bas plus clair, on voit le jeu à travers. Elle apparaît d'un coup (petite puis à sa taille). |
| L3 | Rester 30 s à 1 min sous la pluie | Les gouttes restent en place et **grossissent** doucement ; deux gouttes qui se touchent **fusionnent** ; une grosse goutte finit par **couler** vers le bas (de plus en plus vite, en zigzaguant un peu) avec une courte **traînée** mouillée, et sort de l'écran. Jamais plus de 25 gouttes. |
| L4 | Orage (`"Storm"`) | Plus de gouttes, et sur les **bords** de l'écran une **buée** de minuscules gouttelettes + un léger voile humide qui apparaissent en ~10–20 s. Le centre reste net. |
| L5 | Passer sous un auvent / le viaduc, entrer dans le bar ou une boutique | Tout **sèche** en 2–4 s (les gouttes pâlissent et rétrécissent, la buée s'efface). Ressortir : ça recommence petit à petit. |
| L6 | Entrer dans le parc, ou lancer un duel, avec des gouttes à l'écran | Tout **disparaît d'un coup**. |
| L7 | Orage : attendre un éclair | Le **tonnerre** se fait entendre 1 à 4 s après un éclair lointain (plus ou moins fort), presque tout de suite et plus fort après un éclair proche. |
| L8 | Coupure de courant (nuit, `"PowerCut"`) | Pendant les ~3,5 s de clignotement : un **grésillement électrique** ; il se coupe net quand le **transformateur saute** (bang + crépitement, en 3D depuis la sous-station, plus faible si tu es loin). |
| L9 | Nuit, se tenir près d'un lampadaire qui grésille (il se coupe une fraction de seconde de temps en temps) | Un petit **crépitement** très discret à chaque coupure (pas plus d'un toutes les 2,5 s), rien si tu es à plus de ~25 studs. |

Si tu construis ta propre map plus tard : mets un dossier **City** dans Workspace et le code ne construit plus rien.

## Kit Bouncer / Videur (`claude/bouncer-kit`)

**Ré-importer `assets/wounds/WoundKit.fbx` avant** (Import 3D dans `Assets > Wounds`, voir `WOUNDS_FR.md`) : il contient les pièces du bras arraché et l'os entier.
Dans **Studio**, tous les kits sont débloqués pour tester (`Config.Dev.UNLOCK_KITS_IN_STUDIO`) ; dans le jeu publié, le Bouncer demande le **niveau 5** et **500 coins**.
Menu **KITS** → **BOUNCER** → **EQUIP**. Tester sur le **Dummy**, puis à **2 joueurs**. Pas de sons pour l'instant (ce sera la prochaine étape) ; plus aucune voix sur la victime du finisher à la batte.

| # | Test | Résultat attendu |
|---|---|---|
| V1 | Menu KITS | La carte **BOUNCER** avec ses 4 attaques ; dans le jeu publié : UNLOCKS AT LEVEL 5 / BUY · 500. |
| V2 | Marcher, courir | Un peu plus lent qu'avec les autres kits. |
| V3 | **1** (Shove) | Il recule le poids, ramène les mains, puis fait un pas et enfonce les deux paumes dans la poitrine : la victime part **loin** en arrière, ses pieds **raclent le sol** (petite poussière). |
| V4 | **2** (Chokehold) au contact | Il attrape et se met **derrière** la victime, **son avant-bras en travers de la gorge**, sa tête à côté de la sienne ; la victime **tire sur son bras** avec les deux mains, les jambes se débattent. **3 serrées** : à chaque fois le visage vire au **violet-rouge** puis **violet foncé**, un peu de salive. Il la lâche : elle se plie en avant, les mains à la gorge ; la couleur revient en quelques secondes. Si c'est toi qu'on étrangle : l'écran **s'assombrit** à chaque serrée, puis revient. |
| V5 | **2** dans le vide | Il tend les bras, attrape le vide et revient en garde (pas d'étranglement dans l'air). |
| V6 | **2** sur quelqu'un qui **bloque** (F) | La saisie passe quand même (pas de parade possible). |
| V7 | Pendant une saisie, un 3ᵉ joueur frappe le Bouncer | Il lâche tout de suite, les animations des deux s'arrêtent, les deux peuvent bouger. |
| V8 | **3** (Body Slam) | Il **plonge sous** la victime : un bras **entre ses jambes**, l'autre derrière ses épaules, il la soulève **à l'horizontale en travers de sa poitrine**, la tient un instant en haut, puis l'**écrase sur le dos** devant lui en se baissant avec elle. Au sol : **anneau de poussière**, éclats du sol, onde au ras du sol, la caméra tremble (plus fort si tu es près). La victime part en ragdoll **là où elle est tombée** (pas de saut de position), puis se relève. |
| V9 | **4** (Hammer Fist) | Les deux poings très haut, il monte sur la pointe, puis les abat sur le haut du crâne en se pliant : grosse réaction, sueur / salive qui gicle de la tête. |
| V10 | Remplir la jauge, **G** | Il fait craquer sa nuque des deux côtés, puis se campe, torse bombé : **poussière** sous ses pieds, **buée** qui sort de sa bouche (**LAST CALL**). |
| V11 | **1** en Awakening (Throw Out) | Il l'attrape au col et à la ceinture, la fait pivoter sur le côté, puis la **jette** : elle vole loin, **poussière** là où elle retombe. |
| V12 | **2** en Awakening (Sleeper Hold) | Comme l'étranglement mais plus long : la victime **faiblit** (les bras retombent), visage violet, elle **s'effondre** à la fin. Si c'est toi : l'écran devient presque **noir**. |
| V13 | **3** en Awakening (Powerbomb) | Différent du Body Slam : il lui **met la tête entre ses jambes**, la soulève **assise sur ses épaules** (face à lui), puis l'**écrase sur le dos** devant lui et **tombe à genoux**, les jambes de la victime sur ses épaules. Poussière plus grosse. |
| V14 | **4** en Awakening (Double Hammer) | Deux coups de marteau, le 2ᵉ met au sol. |
| V15 | Se faire frapper en Bouncer | Il perd un peu moins de vie que les autres kits pour le même coup. |
| V16 | **Finisher** sur un KO (Dummy) | Bandes noires. La victime est **allongée sur le dos en travers devant lui**, tête à sa gauche. Il s'accroupit, prend son **poignet droit à deux mains** et lève le bras ; gros plan sur son visage (elle supplie). Il pose le **pied droit sur sa poitrine** et **tire trois fois** ; à la 2ᵉ, l'épaule **se déboîte**. À la 3ᵉ, **le bras s'arrache** : gerbe de sang, il recule d'un pas avec le bras dans les mains. Sur le corps : l'**épaule ouverte** qui gicle par saccades, flaque dessous. Il **lève le bras** pour le regarder (la manche toujours dessus, **l'os dépasse**), puis le **jette** à côté du corps (éclaboussure). ~4,6 s. |
| V17 | Finisher contre un mur | Il se place pour que le corps soit couché sur le sol, pas dans le mur. |
| V18 | Un joueur qui arrive après | Il voit le corps sans bras droit, l'épaule ouverte, et le bras par terre avec l'os qui dépasse. |
| V19 | 3ᵉ joueur tue l'attaquant **avant** l'arrachage | Tout s'arrête, la victime retombe KO, avec ses deux bras. |

### Os à lancer (usage unique)

| # | Test | Résultat attendu |
|---|---|---|
| W1 | Après le finisher, s'approcher du **bras par terre** | Un bouton **« Take the bone »** apparaît (maintenir **E**). |
| W2 | Maintenir E | Tu tiens **le vrai humérus** (Z-Anatomy) dans la main droite, la main **autour de l'os** près du coude, la tête ronde vers l'avant. Sur le bras au sol, l'os a disparu. Les autres joueurs voient la même chose. |
| W3 | Clic gauche | Il **lance** l'os par-dessus l'épaule (poids sur l'arrière, pas en avant, le bras fouette) : l'os vole en tournant sur lui-même, en arc. |
| W4 | L'os touche quelqu'un | Il prend un gros coup (sang souvent à la tête) et **l'os se casse en deux** sur lui : les deux moitiés rebondissent, éclats, gouttes de sang. |
| W5 | L'os touche un mur / le sol | Il **se casse en deux** là où il touche. Les moitiés restent ~20 s. |
| W6 | Se faire mettre KO / mourir en tenant l'os | Il tombe et se casse à tes pieds. |
| W7 | Un 2ᵉ joueur essaie de prendre l'os déjà pris | Plus de bouton. En duel : impossible de prendre un os. |

### Sang des finishers qui arrachent (batte, foie, bras)

| # | Test | Résultat attendu |
|---|---|---|
| S1 | Finisher **batte** (Street Brawler) | Le cou **gicle par jets** au rythme du cœur : **deux jets** (les carotides) qui montent et retombent en arc, un flot plus lent derrière ; les jets ralentissent et faiblissent en ~5 s. Là où ils retombent : éclaboussures et **gouttes allongées dans le sens du jet**. Le sang **coule sur la poitrine et le dos** en traînées qui s'allongent ; grande flaque. Taches de sang sur l'attaquant. |
| S2 | Finisher **foie** (Boxer) | Le trou gicle par jets puis coule sur le flanc, flaque, et l'attaquant est **couvert de sang** (torse, bras). |
| S3 | Finisher **bras** (Bouncer) | L'épaule **gicle fort** sur le côté à chaque battement (gouttes au sol dans l'axe des jets), le sang coule le long du flanc, flaque ; le **bout du bras** dans sa main gicle aussi un peu ; le Bouncer est éclaboussé au moment de l'arrachage. |
