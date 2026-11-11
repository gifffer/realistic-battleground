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

<<<<<<< HEAD
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
=======
## Marche et course réalistes (`feature/realistic-locomotion`)

| # | Test | Résultat attendu |
|---|---|---|
| L1 | Marcher (sans Shift), filmer **de côté** | 4 temps par pas : jambes écartées (contact), le corps descend (down), la jambe passe sous le corps pied levé (pass), le corps remonte jambe tendue (up). La tête ondule légèrement. Bras le long du corps qui se balancent à l'opposé des jambes. |
| L2 | Courir (Shift) | Foulées plus longues, talon qui remonte derrière, genou devant, un instant les deux pieds en l'air, torse penché, bras qui battent. |
| L3 | Passer de marche à course et inversement | Transition douce, pas de clignotement entre les deux. |
| L4 | Sauter en marchant | L'animation de saut de Roblox (pas de marche dans les airs). |
| L5 | Vitesse | Marche plus lente qu'avant (10), sprint 22 : réglable dans `src/shared/Config.luau` (`WALK_SPEED`, `SPRINT_SPEED`). |
>>>>>>> origin/main

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
