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
| U5 | Cliquer le bouton **MENU** à gauche | Le monde se floute et se désature, liste « 01 KITS »…, panneau avec grand titre, boutons OFF / ON, touche LEFT CTRL. **CLOSE** referme. |
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
| M1 | Bouton **MENU** | La liste montre **01 KITS**, **02 SETTINGS** ; le menu s'ouvre sur KITS. |
| M2 | KITS | À gauche **STREET BRAWLER** (EQUIPPED) et **BOXER** (NOT AVAILABLE YET). À droite : les 4 moves avec endurance, recharge et leur version Street Fury (petit tiret rouge), puis la ligne **G STREET FURY 10 s**. |
| M3 | Cliquer BOXER | Sa fiche s'affiche (pas encore jouable, pas de bouton EQUIP). |
| M4 | Cliquer une ligne de la barre de moves (curseur libre : Ctrl gauche) | Le move part, comme avec la touche. |

Pas de son dédié encore pour la bouteille / coup de tête / tackle / tibia / Awakening : ils
utilisent les sons de coups existants (plus graves / aigus). Tu peux mettre tes IDs dans
`src/shared/Sounds.luau` : **BottleBreak, Slash, Headbutt, Tackle, KickLow, Awaken**.

## Étape 5 — Blessures (`feature/injuries`)

| # | Test | Résultat attendu |
|---|---|---|
| B1 | Se faire frapper aux jambes (à 2 joueurs : Dirty Kick ×4–5, ou M1 visés bas) | Après **25 dégâts aux jambes** : tu **boites** (marche sur la bonne jambe, plus lent −25 %), pas de sprint, la ligne d'endurance dit **LIMPING**. À l'arrêt, le poids est sur la **bonne** jambe (voir B9–B13). |
| B2 | Faire un kill en boitant | La boiterie **disparaît** (le kill soigne toutes les blessures). |
| B3 | Frapper le Dummy plusieurs fois à la tête / au torse / aux jambes | Des **petites marques sombres** (bleus, coupure au sourcil) apparaissent là où il a été touché (3 max par partie). Elles partent à sa mort. |
| B4 | 4ᵉ M1 visé à la **tête** | L'adversaire **saigne** un peu (3 s), même sans bouteille. |
| B5 | Descendre **sous 25 PV** | Bords de l'écran qui s'assombrissent et **respirent**, image un peu floue et moins colorée ; plus tu es bas, plus c'est fort. Ton perso est **voûté** (main sur les côtes) hors combat, **garde basse et fatiguée** en combat — les autres le voient. |
| B6 | Rester **10 s sans être touché** sous 25 PV | La vie remonte doucement (1 PV/s) **jusqu'à 25**, pas plus. Pas pendant un saignement. |
| B7 | Être KO | Les effets faible vie s'arrêtent (l'écran KO prend le relais). |
| B8 | Se faire frapper **à 70 PV ou moins** | Le perso pousse un **cri de douleur** (3 sons au hasard), entendu par tout le monde. |
| B9 | Boiter (B1), marcher droit devant, regarder de profil depuis un 2ᵉ joueur | Boiterie **réaliste** (démarche antalgique) : le pied blessé **touche le sol à chaque pas**, posé à plat et prudemment, mais **très peu de temps** ; le corps retombe vite sur la bonne jambe (petite **chute de la tête** à ce moment), qui porte le poids longtemps. Rythme irrégulier « tac-TAAAC ». Jamais de jambe levée en l'air (« flamant rose »). |
| B10 | Même chose, de face | Pendant l'appui sur la jambe blessée le buste **penche au-dessus d'elle** ; puis il repasse au-dessus de la bonne jambe. La jambe blessée avance **raide** avec la hanche qui monte et un petit arc vers l'extérieur. Bras qui balancent peu, celui du côté blessé un peu écarté. |
| B11 | S'arrêter en boitant | Debout : bassin et poids **sur la bonne jambe**, le pied blessé **posé au sol** un peu en avant (genou souple), **main sur la cuisse blessée**. De temps en temps le perso **teste** sa jambe blessée, grimace (tête qui baisse) et repasse vite sur la bonne. Les pieds **ne glissent pas** pendant l'idle. |
| B12 | Se faire boiter par des coups sur la jambe **gauche** (frappé de son côté gauche), puis sur la **droite** (autre vie) | La boiterie est du **bon côté** : c'est la jambe la plus touchée qui est ménagée (animation en miroir). Les autres joueurs voient le même côté. Si l'**autre** jambe prend ensuite plus de coups (même vie), la boiterie **change de côté** (fondu, pas de saut). |
| B13 | Boiter puis ralentir / accélérer (marche normale, ralenti par un coup au tibia) | Les pas suivent la vitesse réelle (pas de patinage marqué), **même très lentement** : boiter en **bloquant** ou **étourdi** donne des petits pas lents, pas des jambes qui moulinent ; vitesse en boitant = **75 %** de la marche, pas de sprint. Accroupi en boitant : marche accroupie normale. |

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
| F1 | **Street Brawler** sur un KO (couché **ou resté debout**) — **ré-importer `WoundKit` avant** | Bandes noires. La victime est allongée sur le dos devant lui, tête vers lui. Plan large de côté : le corps au sol, le perso sort une **batte de taille réelle** (~0,85 m). Gros plan sur la victime (vue de sa gauche) qui lève la tête et tend la main en suppliant (on l'entend) ; le bras ne bouche pas l'image. Plan du sol : comme au **golf**, à deux mains, il aligne la batte sur la tête, l'arme en arrière vers sa droite, puis **balaie** la tête au ras du sol de sa droite vers sa gauche (coup à **1,92 s**) et finit en **fin de swing haute**, tourné vers la cible, la batte **derrière sa tête**. Plan de côté tenu : la **tête explose** en vraies pièces — morceaux de crâne (peau dehors, os dedans), cerveau, yeux, dents ; gerbe de sang, fine brume ; au sol, une éclaboussure et des traînées **sur le sol, jamais sur le corps**. Il reste la vraie mâchoire du bas avec ses dents, la peau du menton déchirée, les vertèbres ; le cou gicle par saccades, une flaque s'étend. Caméra normale ensuite (~3,8 s ; le swing et le ralenti : section « Finisher batte plus spectaculaire » en bas). |
| F2 | **Boxer** sur un KO — **ré-importer `WoundKit` avant** | Il **relève** l'adversaire, deux coups au corps, crochet droit, crochet gauche, direct (la tête part d'un côté puis de l'autre, un peu de sang). Il **s'enroule** (bas, poing gauche loin derrière, un temps d'arrêt) puis un **crochet du gauche dans son flanc droit, sous les côtes** : le poing rentre (craquement, ton son du coup final, gerbe de sang, éclats de côte), fouille, **tourne**, et **arrache le vrai foie** (avec la vésicule verte). Il le tient **à bout de bras** sur le côté, il dégouline, il le regarde, le **serre** ; la victime s'effondre, un **trou** dans le flanc droit avec des **côtes cassées** dedans, à travers le t-shirt, qui gicle par saccades, flaque dessous. Il **ouvre la main : le foie tombe** au sol, bruit mouillé et éclaboussure quand il touche le sol. ~4,1 s. |
| F2-cam | Boxer : **pas de caméra de cinématique** — à tester en **3ᵉ personne** puis en **1ʳᵉ personne** (Paramètres), côté tueur **et** côté victime | **Aucune bande noire, aucun plan** : chacun garde **sa propre caméra**, comme avant le finisher (3ᵉ personne sur l'épaule ou 1ʳᵉ personne), et peut toujours la **tourner à la souris** ; le perso, lui, **ne tourne pas** avec la caméra (il reste face à la victime). Seule chose en plus : **petites secousses** sur les coups. En **1ʳᵉ personne**, le Boxer **voit ses deux bras** (les coups, le foie dans son poing ; un bras qui passerait dans la caméra est caché), mais **pas** le reste de son corps (pas de tête/torse devant l'écran). **Après** le finisher : même caméra qu'avant, même champ de vision (pas de zoom resté), en 1ʳᵉ personne **les bras redeviennent invisibles**, le perso tourne de nouveau avec la caméra, on peut attaquer. |
| F2a | Boxer : les coups (vus depuis sa propre caméra, tueur ou victime) | Chaque coup **fige l'image une fraction de seconde** (hit-stop : les **deux corps** s'arrêtent ensemble — la victime ne bouge plus non plus, la petite secousse de l'image reste figée sur l'impact — puis repartent), léger zoom sec et secousse **légère** (rien qui donne mal au cœur). Coups au visage : la **tête part** dans le sens du coup **à la fin de l'arrêt** et rebondit ; coups au corps : la tête **plonge en avant**. Petit anneau d'air et gouttes de sueur à l'impact (visibles par tout le monde). Avant le coup final, la vue **s'élargit très légèrement** pendant qu'il s'enroule, avec un **grognement d'effort** grave du Boxer. |
| F2b | Boxer : la main qui rentre | Plus gros arrêt sur image, secousse et petit zoom plus forts, **l'écran flashe** (plus clair, contraste, teinte rouge) puis revient. Sur le flanc : le **trou est déjà ouvert** pendant que la main fouille (avant, il n'apparaissait qu'à la mort) ; le sang est poussé autour du poignet, des **filets épais** pendent et coulent le long du flanc ; quand la main **tourne** : craquement, la victime gémit, nouveau petit flash. |
| F2c | Boxer : l'arrachage | Des **filaments rouge sombre** (vaisseaux) restent tendus entre le trou et le foie, puis **cassent** l'un après l'autre (le plus épais en dernier), avec un filet de sang qui fouette à chaque bout. Le foie **tremble** (mou) dans le poing, en travers du poing (il ne se tasse pas à la verticale). La main qui tourne et l'arrachage ne figent pas l'image. |
| F2d | Boxer : il serre le foie (~3,1 s) | Le foie **s'écrase** dans le poing et reprend sa forme en tremblant, bruit mouillé, le sang **coule entre les doigts** en filets et le long de son avant-bras. |
| F2e | Boxer : coupé **entre la main qui rentre et l'arrachage** (le joueur Boxer **se réinitialise** par le menu Roblox, ou **quitte la partie**, vers 2,3–2,6 s ; on ne peut pas le tuer pendant la cinématique, cf. F3) | Tout s'arrête, le **trou du flanc se referme** (les coupures d'avant reviennent s'il y en avait), la victime retombe KO (on peut l'achever à nouveau), pas de foie, pas de flash qui reste à l'écran, pas de secousse ni de zoom qui reste, la caméra tourne de nouveau le perso (et en 1ʳᵉ personne ses bras redeviennent invisibles). Si c'est la **victime** qui quitte la partie, la cinématique s'arrête aussi (le Boxer est libéré, pas d'erreur dans la sortie). |
| F3 | Pendant un finisher, un 3ᵉ joueur frappe l'attaquant | Rien ne se passe : l'attaquant est intouchable pendant la scène. |
| F4 | La victime (2ᵉ joueur) | Elle voit la même cinématique (bandes noires et caméra), puis son écran de mort. **Sauf Boxer** : elle garde sa propre caméra (cf. F2-cam). |
| F5 | Un 3ᵉ joueur qui regarde | Pas de cinématique pour lui (sa caméra reste normale), mais il voit l'animation, la batte, le sang et entend les coups. |
| F6 | Après le finisher | Le joueur peut de nouveau bouger et attaquer normalement, la caméra est revenue comme avant. |
| F7 | Un 3ᵉ joueur tue l'attaquant (ou il quitte) avant le coup final | La cinématique s'arrête tout de suite chez les deux, la caméra revient, la victime retombe toujours KO (quelqu'un d'autre peut l'achever). |
| F8 | Pendant la cinématique | Impossible de dasher, bloquer ou attaquer ; on ne peut pas lancer un duel avec l'attaquant. |
| F9 | Un joueur qui arrive après (ou qui était loin) | Il voit le corps sans tête, le cou ouvert, sans l'explosion. |
| F10 | Achever un **2ᵉ joueur** (n'importe quel finisher), puis regarder son corps | Il réapparaît après 5 s, mais son **corps reste** là où il est tombé jusqu'à **10 s** après le coup final (`Config.Knockout.FINISHER_BODY_TIME`), puis disparaît. Les blessures restent dessinées (tête explosée, trou, bras arraché, tête calcinée, coupures, bleus) et les morceaux au sol (crâne, foie) restent aussi longtemps. Le corps est figé : on passe à travers, on ne peut ni le frapper ni le cibler, il n'a ni nom ni barre de vie, il ne bloque ni les coups ni les lasers. Un Bull mort garde ses cornes mais ne souffle plus. Dans l'Explorer : un modèle dans `Workspace > Corpses` (tag `Corpse`, pas `Combatant`). Les mannequins, eux, restent 25 s comme avant. |

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
| T5b | (Après la fusion avec `main`) Rester sur la voie, puis regarder le sol | Le sang au sol utilise les **grosses flaques des finishers** : une flaque qui coule du torse là où il s'arrête (traînée s'il glisse), une petite sous chaque membre. Écran de mort : « Thrown under a train by <lui> » ou « Hit by a train ». Un clone de Dr. Rift touché par le train repart dans un portail (pas de kill, pas démembré). |

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
| M7 | Barre du haut → Settings (engrenage) → Sound → Music OFF | Plus de musique (dehors, bar, boutiques, parc). Pluie, train et coups restent. Sauvegardé. |
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

#### v9 : vraie pluie dans la ville (`feature/realistic-rain`)

(R4 ci-dessus reste valable. Les images de `assets/rain/` peuvent être importées avant ou après, voir `docs/RAIN_FR.md` : sans elles, la pluie marche avec des textures Roblox de secours et sans rideaux lointains.)

| # | Test | Résultat attendu |
|---|---|---|
| P1 | `WeatherForce = "Rain"`, rester dans la rue et regarder autour | La pluie **monte doucement** (~25 s). Près de toi : des traits **longs et nets** qui tombent vite ; plus loin (jusqu'à ~100 studs) des traits **fins et serrés** ; au fond, la ville devient **grise et voilée**. Les gouttes ne **glissent pas** avec la caméra : en marchant, tu traverses la pluie. |
| P2 | Regarder le sol de la rue | Des **petites couronnes d'éclaboussures** (quelques gouttelettes qui sautent et retombent) et de **petits cercles** qui s'ouvrent sur le sol mouillé, surtout devant toi. Rien sur l'herbe. Une **brume** très légère au ras du sol. |
| P3 | Se mettre sous un auvent, sous le viaduc, entrer dans le bar / une boutique | **Aucune goutte** ne tombe sous le toit ; dehors, à côté, il pleut toujours (on le voit par la vitrine). Le son de la pluie devient **plus sourd** (on l'entend « tambouriner » sur le toit). |
| P4 | Monter sur un toit | Les gouttes **s'arrêtent sur les toits** (pas à travers), et il pleut dans la rue en dessous. |
| P5 | Orage (`"Storm"`) | Pluie **beaucoup plus dense**, **penchée** par le vent, les rafales la penchent encore plus ; plus d'éclaboussures. |
| P6 | Attendre la fin de l'événement | La pluie **diminue doucement** puis s'arrête net au moment où le ciel redevient clair : plus aucune goutte, éclaboussure ou brume. Aucun objet ne reste (Explorer : `Camera > RainField` existe toujours mais ne fait plus rien). |
| P7 | Settings Roblox → Graphics quality **1-3**, puis **8-10** | En bas : nettement moins de gouttes au loin, pas de petits cercles ni de brume, peu de rideaux ; en haut : tout. Les FPS ne doivent pas chuter (Shift+F5 : compare avec / sans pluie). En **Automatic**, la qualité de la pluie baisse toute seule si le jeu passe sous ~42 FPS. |
| P8 | Entrer dans le parc, ou lancer un duel, pendant la pluie | Plus de pluie du tout (parc toujours ensoleillé, duel = arène). |
| P9 | Brouillard / coupure juste après une pluie | Aucun reste de pluie, rien ne se mélange. |
| P10 | Pendant la pluie : marcher le long d'un mur dans la rue, puis mourir / réapparaître ailleurs | Il pleut **juste à côté de toi** même collé à un bâtiment (pas de bande sèche autour de toi, pas d'éclaboussures sans gouttes). Après la réapparition, **aucune goutte** dans les bâtiments autour (même s'ils arrivent quelques secondes après). Sur un toit ou sur le pont, la pluie dans la rue en dessous reste fluide (pas de chute de FPS). Les rideaux au loin **ne sautent pas** quand tu cours. |

Si tu construis ta propre map plus tard : mets un dossier **City** dans Workspace et le code ne construit plus rien.

## Kits Sentinel et Bull (`feature/kits-sentinel-bull`)

Équipe le kit dans le menu Kits (gratuits), puis teste sur un mannequin.

### Sentinel
- [ ] **Look** : cape rouge en tissu simulé (elle pend, se balance, vole en arrière quand tu bouges, réagit au vent de la map et aux ondes de choc), fermoirs dorés + chaîne, emblème. Plus de points rouges sur la tête (les yeux ne s'allument que pendant le laser).
- [ ] **Vitesse** : il marche un peu plus lentement que les autres et ne peut pas sprinter.
- [ ] **1 — Heat Vision** : 1 s de charge (les yeux s'allument, énergie aspirée, petits éclairs, son de charge), puis deux lasers tout droit là où il regardait au départ (ils ne suivent PAS la souris). Immobile pendant la charge et le tir, pas de dash. Il ne fait mal qu'à la TÊTE : il faut viser la tête et y rester ~0,5 s avant les dégâts. Le corps bloque le laser : s'il touche d'abord un bras, une épaule, le torse ou une jambe, il s'arrête dessus (quelques étincelles qui ricochent), sans dégâts, sans brûlure ni lueur ; un joueur caché derrière un autre est protégé. Un tir qui passe juste à côté du visage continue tout droit. Un chapeau / des cheveux sur la tête comptent comme la tête. Pas de son quand ça touche : là où le laser touche la tête, la peau brûle et disparaît (vrai trou dans la peau, bord carbonisé, peau cuite autour) et on voit le crâne dessous. Pas de sang (cautérisé). Rester au même endroit agrandit la brûlure (3 tailles). Tout le monde voit la même chose et elle reste. Le laser s'arrête sur les murs (traînée en fusion puis carbonisée). Bloquer (garde) contre un laser sur la tête coûte de l'endurance comme avant ; si les bras levés sont devant le visage, ils arrêtent le laser.
- [ ] **2 — Thunder Clap** : éclairs dans les mains, puis clap : flash, sphère d'énergie, anneaux en cône, lignes d'air, éclairs, poussière poussée devant.
- [ ] **3 — Skyfall** : impact au DÉCOLLAGE (cratère, fissures lumineuses, dalles soulevées, cailloux) + son, traînée en vol, poing qui se charge en descente, gros impact à l'ATTERRISSAGE + son, écran qui tremble.
- [ ] **4 — Haymaker** : le poing se charge (énergie aspirée, éclairs), impact : flash, anneaux, lignes d'air, étincelles + son.

### Bull
- [ ] **Look** : cornes courbées avec anneaux à la base, anneau doré dans le nez, vapeur qui sort du nez de temps en temps.
- [ ] **Vitesse** : il marche plus vite que les autres.
- [ ] **Course (Shift)** : course de taureau (penché, tête baissée cornes devant, grosses foulées), poussière + petites fissures à chaque pas, vapeur du nez.
- [ ] **1 — Gore Charge** : son de charge (coupé à la fin de l'attaque, ~1,2 s), yeux rouges, il gratte le sol, puis charge : nuage de poussière, fissures à chaque pas, traînées sur les cornes. La cible saigne.
- [ ] **2 — Horn Hook** : coup de cornes vers le haut : anneau d'air, colonne de poussière, la cible décolle.
- [ ] **3 — Stampede** : il se cabre (cailloux qui flottent), puis frappe le sol : gros impact (dalles, fissures, poussière) + son ; ralentit les cibles autour. Imblocable.
- [ ] **4 — Bull Toss** : son à l'attrapé ET au lancer, anneau d'air vers le haut au lancer.

### Murs cassables
- [ ] La **Gore Charge** traverse les murs : le mur se troue (seulement la partie touchée), débris de la couleur / matière du mur, poussière.
- [ ] Les gros impacts cassent aussi les murs proches : Thunder Clap, Skyfall (atterrissage), Haymaker, Horn Hook, Stampede.
- [ ] Le sol, les sols surélevés / toits, les murs des arènes de duel et les murs invisibles ne cassent jamais.
- [ ] Les murs se reconstruisent ~25 s après le dernier coup (pas si quelqu'un est dedans).
- [ ] Pour protéger une partie de la map : tag CollectionService `Unbreakable` ou attribut `Unbreakable = true` (sur la part ou un de ses parents).

### Finishers (adversaire KO + M1)
- [ ] **Sentinel — Incinerate** (**ré-importer `assets/wounds/WoundKit.fbx` avant**, il contient le trou « Bore » ; ~5,6 s) : il attrape l'adversaire par la gorge (bruit d'étouffement) et le soulève, les pieds ne touchent plus le sol et battent faiblement ; on entend son cœur battre. Gros plan sur ses yeux qui chargent (son de charge, éclairs), sa tête **se penche vers la poitrine**. Les deux lasers convergent **à bout portant dans le cœur** (côté **gauche** de la victime, en haut de la poitrine) : plan de profil avec les deux rayons, gros plan sur la poitrine, puis vue au-dessus de son épaule droite qui plonge dans le trou. Le trou **se creuse** pendant le tir (petit → moyen avec un craquement de côtes → grand : le cœur est traversé, le battement s'arrête). **Aucune goutte de sang** (cautérisé) ; la lumière du laser éclaire **l'intérieur** du trou, étincelles, grosse fumée qui sort du trou ; la victime convulse puis devient molle. Le rayon s'arrête : le bord du trou est **rouge-orange incandescent** et refroidit vers le **noir** en quelques secondes, fumée et braises qui montent. Dans le trou on voit les organes : peau carbonisée au bord, graisse cuite, muscle, **côtes coupées** (os blanc cassé, cartilage blanc-bleuté), bord du **poumon** (rose-gris), **cœur** traversé (rouge sombre, cavité presque noire) ; le trou ne traverse pas le dos. Il **jette le corps** sur le dos (bruit de chute, poussière), puis la caméra **descend lentement** sur le trou qui fume encore. Le t-shirt est troué autour du trou. Un joueur qui arrive après voit encore un peu de fumée sur le corps. La tête n'est plus brûlée.
- [ ] **Sentinel — Incinerate, cas limites** : la victime avait déjà des coupures sur le torse (bouteille) : celle qui est sur le cœur disparaît, le trou la remplace ; finisher coupé avant la mort (l'attaquant quitte) : le trou disparaît, les coupures d'avant reviennent, plus de fumée / lueur. Avec un vieux `WoundKit` (pas ré-importé) : une grande brûlure à la place du trou, pas d'erreur.
- [ ] **Bull — Gore** (**ré-importer `WoundKit` avant**, ~4,4 s) :
  - **Placement** : l'adversaire KO est remis **debout, sonné**, à ~11 studs devant le Bull, face à lui. Contre un mur ou au bord d'un vide, le Bull se tourne vers un côté libre ; s'il n'y a de place nulle part, la course est plus courte (~7 studs). Jamais de course à travers un mur dans un endroit dégagé.
  - **0 → 0,6 s** : plan bas derrière le Bull, puis plan près de la victime : il souffle (vapeur), baisse la tête, **gratte le sol du sabot** deux fois (poussière, petites fissures).
  - **0,6 → 1,1 s** : il **charge** (~10 studs en une demi-seconde, rugissement, nuage de poussière derrière, fissures à chaque foulée, lignes de vitesse) ; la caméra le suit de côté, au ras du sol.
  - **1,1 s** : les **cornes dans la cage thoracique** (craquement de côtes, gerbe de sang des deux côtés des cornes, éclats d'os, sang sur le Bull) ; la victime se plie par-dessus sa tête ; un **trou** déchiré dans la poitrine (à travers le t-shirt). Il l'emporte sur quelques studs.
  - **1,45 s** : il **saute** (impact au décollage), la victime sur les cornes ; elle bascule en arrière au-dessus de sa tête.
  - **1,85 s** (le coup final) : en l'air, il donne un coup de tête : le corps se **déchire en deux à la taille**. Le **haut** (torse, bras, tête) part en avant et vers le haut en tournant et retombe ~6-8 studs plus loin ; les **jambes** tombent en arrière. Gerbe de sang dans les deux sens, pluie de sang.
  - **Les intestins** sortent du torse pendant que les deux moitiés s'éloignent : une chaîne de boucles roses qui **se déroule** le long du trajet du haut du corps, retombe et reste **au sol, en boucles, des jambes jusqu'au torse** ; un **tas d'intestins** tombe près des jambes (mou, il s'écrase). Si les moitiés partent trop loin, l'intestin se déchire côté torse.
  - **Bouts arrachés** : sous le torse, les vrais muscles déchirés, la colonne (vertèbres + disque) qui dépasse, des nerfs qui pendent, l'intestin qui bombe, graisse jaune et peau retroussée ; au-dessus des jambes, le bassin (os iliaques, sacrum), l'autre moitié du disque, muscles, peau.
  - **Sang** : l'aorte et la veine cave **giclent par saccades** sous le torse, les deux artères iliaques au-dessus des jambes ; bruit sourd et éclaboussure quand chaque moitié touche le sol ; **traînée** de sang au sol là où le haut du corps glisse ; une **flaque** s'étend sous chaque moitié.
  - **2,25 s** : le Bull **atterrit** entre les deux moitiés (gros impact, fissures, poussière). Plan au ras du sol depuis les jambes : les intestins qui partent vers le haut du corps, le Bull au milieu ; il **souffle** au-dessus (vapeur), regarde les jambes derrière lui ; plan large d'en haut.
  - Sans le nouveau `WoundKit` (ancien kit) : des formes simples (chair sombre, os, boucles roses en cylindres) au lieu des vraies pièces, rien ne casse.
- [ ] **Bull — Gore, corps vu plus tard** : un joueur qui arrive après (ou le **corps figé** de `Workspace > Corpses` après la réapparition, F10) voit les deux moitiés là où elles sont tombées, les bouts arrachés, les intestins **posés au sol** d'une moitié à l'autre (immobiles), le tas d'intestins et les flaques ; pas de jets ni d'animation.
- [ ] **Bull — Gore coupé avant 1,85 s** (le Bull meurt, un joueur part) : tout s'arrête, le Bull reste **là où on le voyait** (pas de téléportation au bout de la course), la victime retombe KO, entière (le trou dans la poitrine disparaît).
- [ ] **Bull — Gore** sur un **mannequin** : même chose ; les deux moitiés disparaissent avec lui (25 s).
- [ ] Coupés en cours (l'attaquant meurt...) : tout s'arrête proprement, la caméra revient.

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
| S2 | Finisher **foie** (Boxer) | Dès que la main rentre : gerbe, fine brume rouge, filets épais, taches sur le Boxer. À l'arrachage : le trou gicle par jets puis coule sur le flanc, flaque, et l'attaquant est **couvert de sang** (torse, bras, avant-bras gauche quand il serre le foie). |
| S3 | Finisher **bras** (Bouncer) | L'épaule **gicle fort** sur le côté à chaque battement (gouttes au sol dans l'axe des jets), le sang coule le long du flanc, flaque ; le **bout du bras** dans sa main gicle aussi un peu ; le Bouncer est éclaboussé au moment de l'arrachage. |

## Finisher batte plus spectaculaire (`feature/finisher-bat`)

Street Brawler, un adversaire KO (le Dummy suffit), **clic gauche**. Tester aussi à **2 joueurs** (attaquant, victime) et avec un **3ᵉ joueur** qui regarde. Durée totale ~**3,8 s**, coup final à **1,92 s**. La victime est maintenant couchée **plus près** (2,4 studs devant lui, la batte est à taille réelle).

| # | Test | Résultat attendu |
|---|---|---|
| FB0 | La batte elle-même | Une **vraie batte de baseball en bois** (érable clair), à l'échelle du perso (~0,85 m : à peu près la longueur d'une jambe) : **pommeau** évasé au bout, **manche fin** avec du **grip noir** enroulé (on voit les spires en biais), une longue partie qui **s'épaissit** progressivement, un **gros bout** épais et une **extrémité arrondie**. Les deux mains sont sur le manche, le pommeau dépasse sous la main gauche. Plus de batte géante. Pendant tout le finisher, la batte **tourne avec ses poignets** et reste dans ses deux mains, chez tous les clients (jamais figée de travers, même si une autre animation arrive sur lui au début). |
| FB1 | Le début (regarder la **toute première image**, côté tueur, victime **et** 3ᵉ joueur) | La batte est **déjà dans ses mains dès la 1ʳᵉ image** de l'animation (plus de mains vides qui « tiennent » une batte invisible pendant ~0,35 s) : tenue devant lui, il la descend le long de son flanc droit, l'emmène un peu derrière lui puis la ramène au-dessus du visage (bruit de « whoosh » à ce moment-là, ~0,35 s). La batte **n'entre jamais dans le sol**, arrive au-dessus du visage **sans traverser la tête**, et reste en main jusqu'à ~3,55 s. |
| FB2 | Plus de tapotage | Gros plan sur le visage (la victime supplie, main tendue) : la batte passe au-dessus du visage **sans s'y arrêter** (elle ne reste jamais immobile au-dessus) puis va **directement** se poser à côté de la tête (~0,65 s), où il marque un court temps d'arrêt avant de monter. **Plus aucune tape** du bout de la batte sur le visage, plus de batte qui reste posée sur la tête, plus de provocation (il ne penche plus la tête) ; la victime ne tressaille plus, la caméra ne tremble pas avant le swing. |
| FB3 | Un seul gros swing | Entre la sortie de la batte et l'explosion de la tête, il n'y a **qu'un seul geste** : une courte mise en position, la montée, la descente, l'impact. Aucun petit coup ni aller-retour avant. |
| FB4 | Le swing de golf | Plan du sol : il **se met en position** (batte posée à côté de la tête, comme derrière la balle, ~0,1 s), puis **monte lentement** (~0,8 s) : les hanches puis les épaules tournent, le poids passe sur le pied droit, **les poignets se cassent** (la batte tourne dans ses mains) jusqu'en haut, batte **au-dessus de sa tête pointée vers la cible**. **Aucun arrêt en haut** : les hanches repartent pendant que les bras finissent de monter, la batte se retourne et enchaîne directement (pas de blocage ni d'hésitation visible). La **descente est explosive** (~0,27 s) : hanches, torse, bras, et les **poignets lâchent en dernier** ; la batte accélère jusqu'à la tête. Le **woosh** (`BatSwing`) part quand la batte prend de la vitesse, pas pendant qu'elle est encore en haut. Plan de côté (du côté où part la batte) : on voit la tête et lui dans le même cadre. |
| FB5 | L'impact (attaquant **et** victime) | La caméra **se fige net** une fraction de seconde, **zoomée**, l'image devient **pâle et dure** (désaturée, contrastée) puis revient en ~1,4 s ; ensuite seulement la caméra tremble et **dézoome lentement** : effet de ralenti. La batte arrive sur la tête **à sa vitesse maximale** (elle ne fait qu'accélérer pendant la descente, aucun ralenti avant le coup), continue vite juste après, puis **freine** jusqu'à une **fin de swing haute**, tourné vers la cible, batte derrière la tête, talon droit levé, **tenue** ~0,7 s ; puis il remonte la batte et la remet sur l'épaule. Gros boum sourd sous le craquement (`BatImpact`, emprunte `Slam` plus grave). |
| FB6 | L'explosion | Plus de morceaux qu'avant : en plus des vraies pièces (crâne, cerveau, yeux, dents), des **éclats d'os**, des **miettes de cervelle** molles, des **lambeaux de cuir chevelu** (peau dessus, os dessous). La plupart partent **vers la gauche de l'attaquant** (le sens du swing). Les petits morceaux (éclats, miettes, lambeaux, dents) **s'effacent après ~7 s** ; les vraies pièces restent avec le corps. Gerbe de sang basse dans ce sens, un peu vers l'attaquant aussi, un **nuage rouge** qui reste ~2 s et dérive dans le sens du swing en retombant. |
| FB7 | Le sol | En plus de l'éclaboussure sous la tête : un **long éventail de gouttes allongées** (4 à 7,5 studs) dans le sens du swing, et une **2ᵉ éclaboussure** à ~2 studs. Jamais sur le corps. Pareil chez tous les clients. |
| FB8 | L'attaquant | **Beaucoup de taches** de sang sur lui : torse, bras, **visage**. La batte ressort **rouge** : le gros bout et la boule couverts de sang, un anneau rouge, quelques taches plus haut ; elle **goutte** ~1,6 s (les gouttes tombent et éclaboussent le sol, projetées un peu dans le sens du geste). Le 3ᵉ joueur voit la même batte rouge. |
| FB9 | Le plan d'après | Plan bas au-delà des pieds du corps, sur sa droite : le corps au bas de l'image, lui au fond dans sa fin de swing, la batte rouge bien visible derrière sa tête. La caméra **n'est jamais dans le corps** (pas d'image grise/remplie par le torse ou une jambe), même si le corps a bougé en ragdoll. Puis plan large qui monte et tourne lentement. La batte disparaît juste avant la fin, la caméra normale revient. |
| FB10 | 3ᵉ joueur tue l'attaquant **pendant la montée de la batte** (avant 1,92 s) | Tout s'arrête net chez les deux (caméra, bandes, batte, pas d'image figée ni d'image pâle qui reste), la victime retombe KO avec sa tête. |
| FB11 | Deux finishers batte à la suite | La 2ᵉ fois, l'image pâle et le zoom refonctionnent normalement ; jamais d'image qui reste pâle après une cinématique. |
| FB12 | Un joueur qui arrive après | Corps sans tête, cou ouvert, morceaux au sol (les petits éclats déjà partis après ~7 s) ; pas d'explosion rejouée. |

## Hitbox et lag : compensation de latence (`feature/hitbox-lag`)

Le serveur teste maintenant chaque coup (M1, coups de kit, charge, prise) **aussi** là où
l'attaquant **voyait** sa cible : il « remonte le temps » de son ping + 0,1 s (jamais plus de
0,35 s, ± 0,06 s). Pour simuler du lag : *Studio → File → Studio Settings → Network →
Incoming Replication Lag* = `0.15`, puis *Test → Clients and Servers → 2 Players*.
**Vérifier d'abord (L0)** que ce lag simulé est bien pris en compte, sinon les tests L2, L3,
L6 et L12 ne veulent rien dire.

| # | Test | Résultat attendu |
|---|---|---|
| L0 | Lag 0,15, 2 joueurs : A frappe B (M1), regarder l'Output du **serveur** | Une ligne `[Rewind] … round trip … -> rewind …` par coup. Avec 0,15 de lag, **rewind ≈ 0,25 s** (round trip ≈ 0,15). Si le round trip reste ≈ 0 (rewind ≈ 0,1) : Studio ne compte pas ce lag dans le ping, mettre `REWIND_STUDIO_EXTRA_PING = 0.15` dans `Shared/Config` (Studio seulement) et refaire : rewind ≈ 0,25. Remettre `0` après les tests. |
| L1 | Dans Studio, frapper le Dummy (M1) | Comme avant : boîte **rouge** (la hitbox) ; en plus une petite boîte **bleue** sur le torse du Dummy (là où le serveur l'a « vu »). Aucune ligne rouge dans l'Output. |
| L2 | 2 joueurs avec lag 0,15 : B **sprinte de gauche à droite** devant A, A clique quand son poing touche B **sur son écran** | Le coup **compte** (dégâts, réaction) dans la grande majorité des cas. Avant : presque toujours raté. |
| L3 | Même chose, B court **en s'éloignant** de A | Si le poing touche sur l'écran de A, ça compte ; la boîte bleue est derrière B (là où A le voyait). |
| L4 | A frappe B, la réaction prédite (instantanée) chez A | Elle n'est presque plus jamais **annulée** juste après (le serveur et l'écran de A sont d'accord). |
| L5 | B est à 10 studs ou plus de A, A frappe dans le vide | **Rien** : la compensation ne rallonge pas la portée (0,35 s max). |
| L6 | Visée tête pendant que B court (A vise la tête sur son écran) | Le coup est compté **à la tête** (zone calculée sur le corps « remonté »). |
| L7 | B **bloque** (F) quand le coup arrive | Toujours **bloqué** : seule la **position** est remontée, pas l'état (garde, parade). |
| L8 | Dash (Q) de B au bon moment | Toujours **esquivé** (les frames d'esquive comptent comme avant). |
| L12 | Lag 0,15 : B **dashe un peu tôt** pour s'éloigner (Q, ~0,1–0,2 s avant que le poing de A arrive), A frappe | **Esquivé** (« Dodged »), même si la boîte bleue montre B encore dans la hitbox : touché seulement là où il **était**, ses frames d'esquive depuis ce moment-là comptent. Avant la correction, le coup passait. |
| L13 | Lag 0,15 : Bouncer, prise (Chokehold / Body Slam) sur B qui **s'enfuit en sprint** | Si B est encore à portée de bras, il est attrapé (court déplacement devant le Bouncer). S'il est déjà **loin** (plus de ~6–7 studs du Bouncer), il n'est **pas** attrapé : jamais ramené en arrière sur plusieurs studs. |
| L9 | Coups de kit (1–4), charge (tackle du Street Brawler) et prises du Bouncer sur une cible qui bouge | Ils touchent là où l'attaquant voit la cible (boîtes bleues), comme le M1. |
| L10 | B meurt / réapparaît / est téléporté dans l'arène de duel, A frappe là où B était | **Rien** : l'historique est effacé lors d'une téléportation. |
| L11 | Mettre `DEBUG_HITBOXES = false` dans `Shared/Config` | Plus aucune boîte (rouge ni bleue). |
## Sang réaliste (`feature/realistic-blood`)

Sans les images (`Config.Blood.IMAGES` à 0), le sang est dessiné avec des formes simples ; avec les
images importées (docs/BLOOD_FR.md), les mêmes tests doivent donner des taches plus détaillées.
Réglage d'éclairage conseillé pour le mouillé : `Lighting.Technology = Future`.

| # | Test | Résultat attendu |
|---|---|---|
| R1 | Coup qui saigne (bouteille) sur un Dummy, regarder le sol | Taches **rouge foncé** (jamais rose), bord irrégulier, jamais un disque parfait. Une goutte arrivée en biais est **ovale ou en « ! »**, la queue dans le sens où elle allait. |
| R2 | Attendre 1-2 min près des taches | Elles **foncent** (rouge → bordeaux), un **bord sombre** apparaît (le sang coagule), puis brun-noir mat, et elles disparaissent en fondu. |
| R3 | Coup qui saigne tout près d'un **mur** | Des taches sur le mur, étirées vers le bas, et du sang qui **coule** lentement avec une perle au bout. |
| R4 | Deux clients (Test > 2 joueurs), même coup | Les gouttes tombent **aux mêmes endroits** sur les deux écrans (à peu près). |
| R5 | Un joueur qui saigne (Bleeding) reste **immobile** ~10 s | Le sang **coule de la plaie** sur la peau, les gouttes tombent **du bout de la coulure** ; une **flaque** grandit sous lui (vite puis plus lentement), brillante au début, avec des lobes. Sur une pente, elle s'étale vers le bas. |
| R6 | Flaque près d'un trottoir / d'une marche | Elle s'arrête au bord ; si le sol tombe, du sang **coule le long du bord**. |
| R7 | Marcher dans une flaque fraîche puis s'éloigner | **Empreintes** gauche/droite : pleines, puis partielles, puis des traces, chacune plus pâle que la précédente ; plus rien après ~6-7 pas. Pas d'empreinte dans du sang sec. |
| R8 | Coup qui saigne au **visage** plusieurs fois | Souvent le **nez saigne** (coulure jusqu'à la lèvre, gouttes du menton), parfois la **lèvre** ; sur un coup lourd, un crachat de sang. Pas plus de ~14 marques sur le visage (détails : tests F ci-dessous). |
| R9 | Coup qui saigne au **torse** d'un joueur avec un t-shirt | Une tache **s'étend dans le tissu** pendant ~30 s, plus sombre et mate que sur la peau. Sans t-shirt : un film plus clair sur la peau. |
| R10 | Frapper un visage qui saigne, puis donner des coups dans le vide | Les **jointures** sont rouges ; chaque coup projette une **ligne de petites gouttes** (de plus en plus petites) au sol ; ça s'estompe en ~1 min. |
| R11 | Finisher **batte** / **bras** / **foie** | Les jets sont de **vraies gouttes** qui retombent avec la gravité et se cassent en gouttelettes ; là où les jets tombent fort : une **vague de grosses taches** ; la flaque grandit et suit la pente. L'attaquant a des taches allongées sur lui, même sur la tête ronde (pas de carrés). |
| R12 | Taper un KO qui saigne puis le laisser au sol | Une flaque se forme sous lui. S'il glisse / est poussé : une **traînée** de sang continue (détails : W8). En se relevant : une **empreinte de main**. |
| R13 | Coupure au verre | Plus de **cubes en plastique** qui rebondissent : des gouttes qui volent et tachent le sol. Le sang dans la coupure brille au début puis fonce. |
| R14 | Mourir / réapparaître | Tout le sang **sur le corps** disparaît ; le sang au sol reste et vieillit normalement. |
| R15 | 16 joueurs / 2 finishers en même temps (ou Graphismes au minimum dans Échap) | Pas de chute d'images ; au minimum, moins de taches restent (les plus vieilles s'effacent en premier, les flaques en dernier). |
| R16 | `Config.Blood.ENABLED = false` | Plus aucun sang (jets, gouttes, flaques, empreintes), le reste du combat marche. |

### Sang sur les combattants, v2 (coulures, visage, gouttes qui pendent)

À tester **à 8-12 studs** (la caméra normale) sur un Dummy, puis à 2 joueurs. Les nouvelles images
(`rivuletStrip`, `browCut`, `wipeSmear`... dans `Config.Blood.IMAGES`) sont à 0 tant qu'elles ne
sont pas importées : le jeu prend une image proche déjà importée (coulure de mur, film sur la peau),
donc tout se teste tout de suite. Les points du visage (narine, lèvre, sourcil...) sont des
estimations en haut de `Client/Combat/BloodFace.luau` : si une coulure part à côté de la narine,
c'est là qu'on règle.

| # | Test | Résultat attendu |
|---|---|---|
| F1 | 10 coups qui saignent au visage, **de face** | Le nez saigne : la coulure **avance par à-coups** (elle s'arrête, la perle au bout gonfle, puis elle saute un peu plus bas), fait une **pause sur la lèvre**, contourne la bouche (parfois des deux côtés) et arrive au **menton**. Jamais une bande droite qui glisse d'un coup. |
| F2 | Regarder le menton pendant que le nez saigne | Une **goutte pend** au menton : elle grossit, s'étire (un « cou »), tombe, une plus petite reste et regrossit. Au début une goutte par seconde environ, puis de plus en plus lent (3-4 s) jusqu'à l'arrêt (15-40 s). Les gouttes tombent **moins vite** qu'avant (elles ne « claquent » plus). |
| F3 | Pendant que la goutte pend, la victime frappe ou se fait frapper | La goutte **part tout de suite**, projetée dans le sens du mouvement. |
| F4 | Coups de **côté** (gauche puis droite) | Plus souvent la **lèvre** : un film de sang sur la lèvre inférieure, une courte coulure du coin de la bouche vers la mâchoire. |
| F5 | Uppercut / coup de tête / bouteille sur un visage déjà **bien marqué** (bleus niveau 2+) | Parfois une **coupure au sourcil** : la peau fendue (trait sombre), le sang **passe sur la paupière** (petite pause + film dans l'œil), descend la joue et **goutte de la mâchoire**. Max une coupure par sourcil. |
| F6 | Re-frapper la tête quand une coupure est ouverte | La coupure **se rouvre** (brille de nouveau) et une nouvelle coulure **suit l'ancienne trace mouillée, plus vite**, puis continue plus loin. Le jet de sang du coup est plus fort (jusqu'à ×1.9 avec plusieurs plaies ouvertes). |
| F7 | Coup lourd avec le nez qui saigne déjà | Parfois **nez cassé** : les deux narines coulent, plus large, plus longtemps. |
| F8 | Victime blessée au visage, **immobile ~3 s** (ne frappe pas, n'est pas frappée) | De temps en temps (toutes les 6-15 s) : elle **crache** (un filet de sang qui s'étire et casse, une petite mousse rosée), **se mouche** (gouttelettes vers l'avant-bas, la coulure du nez raccourcit puis **recoule**), ou **s'essuie** (traînée horizontale sur la lèvre ou le sourcil, coulures raccourcies, le sang **revient** 1-3 s après, le dos de la main devient rouge). |
| F9 | Mettre KO un combattant qui saigne du visage | Les coulures encore mouillées **tournent** : sur le côté elles traversent la joue en travers, sur le dos le sang **s'accumule** (la perle grossit) ; ~1 s après, une **flaque sous la tête** (si la tête est au sol). |
| F10 | Se relever (GetUp) avec le visage en sang | Souvent il **s'essuie** le visage. Sur béton / asphalte / pavés, parfois une **éraflure** rosée sur la pommette (max 2), qui reste jusqu'à la mort. |
| F11 | Attendre ~1 min après la fin d'un saignement | Les coulures foncent (la traînée d'abord, la perle reste brillante le plus longtemps), puis sèchent et **restent** jusqu'à la réapparition (croûte craquelée quand `crustStrip` est importée). De nouvelles coulures passent par-dessus. |
| F12 | Plus de 6 coups qui saignent sur le même combattant | **Sueur** : les nouvelles coulures sont plus claires, plus larges et vont plus loin. |
| F13 | `Bleeding` sur le **torse** (coupure au verre), rester debout | Le sang coule de la plaie **jusqu'au bas du t-shirt** (par à-coups, et il passe sur le côté s'il atteint le bord), puis goutte de là ; saignement fort (3+/s) : un **petit filet** qui coule en continu. La tache dans le tissu **descend** en grandissant, avec un **halo mouillé plus sombre** autour (visible aussi sur un t-shirt noir) et un bord pâle. La flaque se forme sous le point qui goutte. |
| F14 | Mettre KO un combattant qui saigne (torse) | La flaque part du côté de la **tête/du cou**, pas cachée sous le ventre. |
| F15 | 12 coups de poing touchés avec le même bras (un Dummy) | Les **jointures se fendent** (petites marques rosées/rouges) et restent jusqu'à la mort. Les gouttes projetées en frappant avec un poing ensanglanté partent surtout **à la fin du geste**, les deux premières plus grosses ; 3-4 coups vident le poing. |
| F16 | Caméra à plus de 60 studs d'un combattant qui saigne | Pas d'animation (les coulures sont posées d'un coup, pas de goutte qui pend : des gouttes simples). Revenir près : tout s'anime de nouveau. |
| F17 | 16 Dummies qui saignent du visage en même temps (MicroProfiler, étiquette `BloodRivulet`) | Moins de 0,4 ms par image ; pas plus de 4 coulures qui bougent par combattant, 3 gouttes qui pendent. |
| F18 | `Config.Blood.FACE.CUTS = false` | Plus de coupures ni d'éraflures ; nez et lèvre saignent toujours. |

### Sang dans le monde, v2 (gouttes au sol, flaques, traces)

Même principe : `crown4x4`, `rippleRing`, `starburst`, `serumHalo`, `drag`, `shoeRunL/R`,
`pendant2x2` sont à 0 tant qu'elles ne sont pas importées. Sans elles : pas de couronne (seulement
ses gouttelettes), pas d'anneau sur la flaque, pas d'auréole jaune ; les étoiles de gouttelettes, les
traînées et les empreintes de course prennent une image proche (gouttelettes, traînée, empreinte
normale). Couronnes, anneaux et petites éclaboussures : seulement à moins de 40 studs de la caméra.

| # | Test | Résultat attendu |
|---|---|---|
| W1 | Un Dummy qui saigne (Bleeding), **immobile** 30 s, regarder ses pieds | Les gouttes tombent **moins vite** qu'un jet et laissent des taches **rondes au bord crénelé** (pas des ovales). Les premières tombent dans la flaque qui se forme. |
| W2 | Pendant W1, une goutte tombe dans la flaque | Un **anneau** s'élargit sur la flaque (~0,35 s), deux petites éclaboussures sautent, et 2-5 **gouttelettes** sont projetées **autour** de la flaque, où elles s'accumulent. |
| W3 | W1 continue ~1 min | Autour de la flaque, des **étoiles de gouttelettes** (max 4 par flaque) : le dessin typique « quelqu'un a saigné debout ici ». Elles disparaissent avec la flaque. |
| W4 | Un combattant qui saigne **marche** | Une traînée de gouttes ; leurs petites queues pointent **vers l'avant** (le sens de la marche). |
| W5 | Gouttes qui tombent de **haut** (tête d'un joueur qui saute, bras arraché levé) sur béton | Plus la chute est haute, plus il y a de **gouttelettes satellites** autour (la tache elle-même reste de la même taille sur le béton). Grosse goutte de haut sur sol dur ou mouillé, de près : une **couronne** (doigts de sang qui montent et se cassent, 0,2 s) et 2-5 gouttelettes projetées du côté où elle allait. Sur herbe / sable : pas de couronne. Caméra qui regarde droit vers le bas : pas d'image de couronne. |
| W6 | **Courir** (> 14 studs/s) à travers une flaque fraîche | Parfois (~1 fois sur 3) une **glissade** : une longue traînée qui sort de la flaque dans le sens de la course. Ensuite des empreintes de **course** (l'avant du pied, étiré vers l'avant), plus espacées qu'en marchant, de plus en plus pâles (~6-7). |
| W7 | Regarder une flaque **4 min** (Échap > horloge, ou attendre) | Le reflet mouillé **rétrécit vers le centre** (le bord sèche d'abord ; les lobes fins foncent avant le milieu), un **bord sombre** apparaît vers 30-60 s, le centre fonce un peu (il gélifie), puis vers 90-180 s un **anneau jaune pâle** (sérum) apparaît autour. La flaque disparaît vers 4 min. |
| W8 | **ThrowOut** / **BodySlam** / **Powerbomb** sur un Dummy qui saigne | À l'impact : une **éclaboussure sous la tête** et 4-6 gouttelettes projetées autour. S'il glisse : **une seule traînée continue**, striée, qui s'allonge tant qu'il glisse dans la même direction (une nouvelle au-delà de 2,5 studs ou s'il tourne de plus de 20°), de plus en plus pâle. S'il saigne encore, elle ne disparaît jamais tout à fait. |
| W9 | Un KO qui **ne saigne pas** glisse à travers une flaque | La traînée part de la flaque, pâlit vite et s'arrête après ~5-6 studs. |
| W10 | Un KO avec seulement une **coupure à la tête** (verre) qui glisse | Une traînée **étroite** sous la tête (pas de la largeur du torse). |
| W11 | KO qui saigne allongé sur une **pente** | La flaque commence un peu **plus bas** que le corps, du côté de la pente. |
| W12 | **Nuit** (`Lighting.ClockTime = 0`) | Le sang frais paraît **presque noir** et se voit surtout par son **reflet mouillé** (plus fort qu'en plein jour). Il faut `Lighting.Technology = Future` et `EnvironmentSpecularScale` ≥ 0,5. Retour au jour (12) : en ~5 s, couleurs normales. |
| W13 | Finisher **bras** / **foie**, regarder le moignon / l'organe | Les gouttes tombent **lentement** et se détachent comme des gouttes qui pendent (image `pendant2x2` si importée) ; au sol, taches rondes. **Artère** (batte) : entre deux battements le jet ne s'arrête pas, il raccourcit, et du sang **goutte** du trou ; après la fin, ~3 s de gouttes lentes. |
| W14 | 16 combattants qui saignent dans une flaque (MicroProfiler : `BloodDrops`, `BloodPool`, `BloodAge`, `BloodTracks`) | Moins de ~1 ms par image au total pour le sang au sol ; jamais plus de 8 couronnes et 6 anneaux en même temps. |
| W15 | **Pluie** | Rien de spécial : il n'y a pas de météo (attribut `Weather`) sur cette branche ; la dilution par la pluie viendra avec elle. |

## Kit Dr. Rift / savant cyborg (`claude/compassionate-goodall-wdn4q1`)

**Ré-importer `assets/wounds/WoundKit.fbx` avant** : il contient les pièces de la coupe en deux (bassin, haut des cuisses, intestins).
Dans **Studio**, tous les kits sont débloqués ; dans le jeu publié, Dr. Rift demande le **niveau 8** et **800 coins**.
Menu **KITS** → **DR. RIFT** → **EQUIP**. Tester sur le **Dummy**, puis à **2 joueurs**. Les sons n'ont pas encore d'ID (ceux qui ont un remplaçant jouent le remplaçant, les autres ne jouent rien).

| # | Test | Résultat attendu |
|---|---|---|
| R1 | Équiper le kit | Ton **bras gauche** devient mécanique : épaulière en tôle, rails, piston, coude à rotule, avant-bras blindé avec une **fenêtre verte qui brille**, câbles, **gant de métal** avec une paume verte. Une **lentille verte** remplace l'œil droit (sangle autour de la tête). Les autres joueurs le voient aussi. Changer de kit : tout disparaît. |
| R2 | **1** (Acid Flask) | Il sort une **fiole** verte et la lance de côté. Elle vole en tournant, en arc. Au contact (quelqu'un, un mur, le sol) : verre qui éclate, **éclaboussure verte**, fumée. La personne touchée et celles autour (7 studs, sans mur entre) **grésillent** (étincelles vertes + fumée sur le corps), perdent de la vie quelques secondes et sont ralenties. Une **flaque d'acide** qui bouillonne reste 5 s : marcher dedans brûle. |
| R3 | **2** (Ray Gun) | Il se met de profil, **pistolet à rayon** (cœur orange) au bout du bras, tir : **rayon orange** jusqu'au premier corps ou au premier mur, étincelles aux deux bouts, petit recul du bras. La cible **prend feu** (petites flammes + fumée, lumière orange) et perd de la vie 3 s. À travers un mur : rien. |
| R4 | **3** (Gravity Glove) | Il ramène le gant à la hanche puis pousse la paume en avant avec un grand pas : tout ce qui est devant **s'envole** (ragdoll), même en bloquant. Éclair vert sur la cible. |
| R5 | **4** (Portal Gun) en visant le **sol** au loin | Pistolet à portails (cœur vert). Un tir vert part vers l'endroit visé, **un portail rond** s'ouvre à plat sur le sol, un **portail debout** s'ouvre devant lui ; il entre et **ressort au portail du sol**. Les portails se referment. |
| R6 | **4** en visant un **mur** | Le portail s'ouvre sur le mur, il ressort debout devant le mur. |
| R7 | **4** en visant **trop haut** (le ciel), le vide, un plafond, ou plus loin que 80 studs | Le tir **grésille** (étincelles), pas de portail, il ne bouge pas. Le pistolet revient en **2,5 s** (au lieu de 10) et ça ne coûte pas d'endurance. |
| R8 | **4** vers un endroit hors de la map, dans une salle de duel, ou sans place pour lui | Raté comme R7. En **duel** : impossible de sortir de la salle. |
| R9 | Remplir la jauge, **G** (DIMENSION RIFT) | Il lève le gant (étincelles aspirées), puis écarte les bras : un portail s'ouvre derrière lui, et **2 copies de lui** sortent de portails à côté de lui. Elles marchent vers l'ennemi le plus proche et frappent. |
| R10 | Frapper un clone | **Un seul coup** et il repart dans un portail. Les clones ne frappent jamais leur Dr. Rift ni entre eux. |
| R11 | Un clone met quelqu'un KO | Le KO compte pour **toi** (pas pour le clone). |
| R12 | **1** en Awakening (Explosive Flask) | Fiole orange : **boule de feu**, fumée noire, braises, onde au sol, trace brûlée qui reste, la caméra tremble. Tout le monde autour (10 studs) **s'envole** à l'opposé de l'explosion et brûle un peu. |
| R13 | **2** en Awakening (Overcharged Ray) | Deux mains, jambes écartées, gros **rayon** plus épais qui **traverse tout le monde** sur la ligne (jusqu'au mur), grand recul. |
| R14 | **3** en Awakening (Rift Swarm) en pointant quelqu'un | Les clones **disparaissent dans un portail et réapparaissent autour de lui**, frappent 3 fois, le 3ᵉ coup le met au sol. Les clones détruits **reviennent** pour ce coup. Personne visé : grésillement. |
| R15 | **4** en Awakening (Gravity Slam) | Petit saut, il pose un genou et **écrase le gant au sol** : anneau vert + poussière qui part tout autour, tous ceux autour (13 studs) **décollent**. |
| R16 | Fin de l'awakening / mort / reset de manche en duel | Les clones repartent dans des portails. |
| R17 | Se faire frapper en Dr. Rift | Un peu **plus** de dégâts que les autres kits (vieux). |
| R18 | **Finisher** sur un KO (Dummy) | Bandes noires. Il tend le **gant** : le corps est **soulevé** du sol et reste debout, mou, les pieds qui pendent (étincelles vertes sur lui). Il sort le **pistolet à portails** et tire sur sa taille : un **portail vert s'ouvre à plat autour de ses hanches**. Gros plan sur son visage (il supplie). Le portail **se referme d'un coup** : le corps est **coupé en deux**. Le haut (torse, tête, bras) **tombe en arrière**, les **jambes restent debout** un moment en giclant du sang vers le haut par saccades, puis **s'effondrent**. Des intestins tombent du haut du corps, flaques, sang sur le Dr. Rift. ~4,6 s. |
| R19 | Regarder les deux coupes | Haut du corps : coupe à la taille avec le **vrai bassin** (os), les muscles, la graisse sous la peau, les intestins qui pendent. Jambes : coupe avec le **fémur**, les muscles de la cuisse, les artères. |
| R20 | Un joueur qui arrive après | Il voit le corps en deux morceaux avec les coupes, sans le sang qui gicle. |
| R21 | Le Dr. Rift quitte le jeu (ou meurt) **avant** la coupe | Tout s'arrête (portail, pistolet), la victime retombe KO, entière. |

## Kit Pyromane (`feature/kit-pyromaniac`)

Le nouveau kit qui remplace le Bull : un **pyromane** avec un **Zippo**, des **cocktails Molotov** et un **jerrican** d'essence.
Dans **Studio**, tous les kits sont débloqués ; dans le jeu publié, le Pyromane demande le **niveau 6** et **650 coins**.
Menu **KITS** → **PYROMANIAC** → **EQUIP**. Tester sur le **Dummy**, puis à **2 joueurs**.
**Les sons sont muets** tant que tu n'as pas mis leurs IDs (voir `docs/SONS_PYROMANE_FR.md` : un prompt par couche à générer). Aucune erreur dans l'Output à cause d'eux.
Les brûlures sur le corps sont celles du système de brûlures (`docs/BURNS_FR.md`, tests B1–B10) : degrés qui s'aggravent là où le feu touche, vêtements qui se carbonisent, flammes, fumée.

| # | Test | Résultat attendu |
|---|---|---|
| P1 | Menu KITS | La carte **PYROMANIAC** (bras droit levé, comme pour lancer) avec ses 4 coups, l'Awakening **BURNING MAN** et le finisher **IMMOLATION**. |
| P2 | **1** (Zippo Flare) face au Dummy, de près | Un **Zippo chromé** dans la main droite : le couvercle **s'ouvre**, la flamme s'allume, il **pousse la flamme vers le visage** : une **courte gerbe de feu** en avant, un flash. Touché : la cible est **sonnée** un moment et **son visage prend feu** (rougeur puis peau à vif sur la face tournée vers lui, perte de vie 2-3 s). Le Zippo se referme. |
| P3 | **2** (Molotov) en visant le sol à 15-25 studs | Une **bouteille verte** avec un **chiffon** dans le goulot ; le Zippo dans la main gauche **allume le chiffon** ; il arme le bras au-dessus de la tête et **lance en cloche**. La bouteille tourne en l'air, le chiffon brûle, traînée de fumée. |
| P4 | L'impact du Molotov | **Verre qui éclate** (éclats verts qui rebondissent et restent quelques secondes), **éclaboussure d'essence**, une **boule de feu** qui apparaît d'un coup et monte en **fumée noire**. Puis une **flaque de feu** : petits feux qui **s'étendent du centre vers le bord** (~0,6 s), **fumée noire épaisse** qui monte lentement, braises, lumière orange qui **vacille** au sol. |
| P5 | Rester dans le feu | La cible **brûle** tant qu'elle est dedans (et ~1,5 s après) : **pieds et bas des jambes d'abord**, de plus en plus profond avec le temps, puis le feu **monte**. En **sautant par-dessus**, pas de brûlure. Dans le **parc** (zone sûre) : rien. |
| P6 | Attendre la fin du feu (~8 s) | Les feux **s'éteignent un par un**, ceux du bord d'abord, le centre en dernier. Une **tache noire** reste au sol ~45 s, puis s'efface. |
| P7 | Molotov **directement sur** le Dummy | Il prend feu **plus fort** et dégouline d'essence (voir P10), et la flaque se fait sous lui. |
| P8 | Lancer 5 Molotov de suite (plusieurs joueurs) | Jamais plus de **4 feux** en même temps : le plus vieux **s'éteint** quand un 5ᵉ commence. Les gros feux en même temps peuvent être plus petits (budget). Pas de lag. |
| P9 | **3** (Fire Breath) face au Dummy à ~8 studs | Une **flasque** à la main gauche : il **boit une gorgée** (tête en arrière), sort le Zippo, l'allume sous ses lèvres, se penche et **crache un jet de feu** (~13 studs, cône). Il peut **tourner pendant le jet** pour balayer. La cible prend plusieurs petits coups et brûle. Derrière un mur : rien. |
| P10 | **4** (Douse) sur le Dummy | Un **jerrican rouge** à la main droite, il le balance : **une gerbe d'essence** part devant lui. Touché : la cible est un peu ralentie et **dégouline d'essence** ~8 s. |
| P11 | Douse **puis** 2 / 3 / 1 | Trempée, la cible **s'embrase de partout** au premier feu, brûle **plus fort et plus longtemps** (×1,5, +2 s) et la flaque de feu l'attrape d'un peu plus loin. |
| P12 | Remplir la jauge, **G** (BURNING MAN) | Il croise les bras, le Zippo touche son avant-bras : **ses deux avant-bras prennent feu** (flammes, fumée, braises, lumière). Ils brûlent tout l'Awakening, puis s'éteignent. |
| P13 | **1** en Awakening (Burning Fist) | Un **crochet** du droit en feu : la cible est repoussée et prend feu. |
| P14 | **2** en Awakening (Firebomb) | Le chiffon s'allume **sur son poing**, lancer plus rapide, **feu plus large et plus long** (~10 s). |
| P15 | **3** en Awakening (Inferno Breath) | Comme P9 mais **plus loin** (~17 studs), plus large, plus long. |
| P16 | **4** en Awakening (Burning Rush) | Il fonce bras en avant : la cible est **mise au sol** et prend feu (passe la garde). |
| P17 | **Finisher** sur un KO (Dummy) | Bandes noires. Le corps est **couché sur le dos** devant lui. Jerrican à la main, il **verse l'essence** sur le corps de la tête vers les jambes (filet qui coule, le corps tousse et bouge la tête), **jette le jerrican** (il rebondit et reste au sol), sort le **Zippo**, l'ouvre, l'allume (gros plan sur la main), un **moment calme** sur le visage qui supplie, puis il **lâche le Zippo** sur la poitrine : le corps **s'embrase d'un coup** (flash, boule de feu), il **recule** de la chaleur. La victime **se débat et hurle** dans le feu, puis **se recroqueville** (bras repliés, poings vers le visage, genoux levés) et ne bouge plus. Les vêtements se **carbonisent** (roussis, trous, puis fondus dans la peau) et la peau passe par les degrés jusqu'au **noir craquelé**. ~5,8 s. |
| P18 | Après le finisher | Le corps **brûle encore ~12 s** (flammes, **fumée noire**, une seule lumière qui vacille, le son du feu), puis **fume** (fumée grise, quelques braises ~18 s). **Pas de double flammes** sur le cadavre. |
| P19 | Un joueur qui arrive après (ou le corps resté après la réapparition) | Le corps a les vêtements **carbonisés** et brûle / fume encore selon le temps passé. |
| P20 | Le Pyromane est frappé / meurt / quitte **avant** « l'embrasement » | Tout s'arrête (jerrican, Zippo), la victime retombe KO, **sans essence ni feu**. |
| P21 | Sons (après avoir mis les IDs) | Chaque son est fait de **5 couches** jouées ensemble au bon moment ; la flaque de feu et le corps qui brûle sont des **boucles** qui baissent quand le feu meurt. |

## Grosses flaques des finishers (`feature/finisher-pools`)

Un membre arraché, une tête éclatée, un corps coupé en deux : **beaucoup** de sang (2,5 à 4 litres en
une vingtaine de secondes). Chaque plaie verse son sang **au sol sous elle** (`BloodGush.stump`) : par
**à-coups** au rythme du cœur d'abord, puis un **suintement** régulier, puis de plus en plus lent. Ça
fait **une seule flaque uniforme qui se forme** : une seule image de flaque, **une seule couleur**,
qui naît toute petite (~0,6 stud) là où le sang tombe et **grandit en douceur depuis le centre**
pendant tout l'écoulement, puis **continue de ramper ~25 s** après (de plus en plus lentement,
jamais d'un coup : on la voit grandir ~35-45 s en tout). **Plus de taches séparées** ni de langues /
doigts autour. Ce sont de **grandes** flaques (un **lac sombre** autour du corps, ~2 fois la taille
d'un corps) : en grandissant elles **passent sous le corps** (le corps est couché dans son sang).
Une flaque **ne bouge jamais** : elle naît là où le sang touche le sol en premier et **reste à cet
endroit** (son centre ne bouge pas, ni en grandissant, ni contre un mur, ni sur une pente, ni quand
elle en touche une autre) ; seul son **bord avance**. Tous les réglages : `Config.Blood.FINISHER_POOLS`
(litres, durées ; taille finale = `SIZE_PER_LITRE` (3,5) × litres^`SIZE_POWER` (0,63) studs de
large ; `CREEP`). Tailles finales (diamètre visible) :
**torse coupé ~8,1**, **cou ~7,6**, **épaule ~7**, **trou du foie / jambes du Bull ~6,4**,
**jambes du portail ~7,1**, **bras arraché ~3**, **foie ~1,9**.
Tester sur le **Dummy**, sur sol **plat**, puis **à 2 joueurs** (comparer les deux écrans).

| # | Test | Résultat attendu |
|---|---|---|
| P1 | Finisher **batte** (Street Brawler) | Sous le **cou** (là où était la tête) **une seule flaque** qui se forme et grandit **régulièrement** depuis le centre (pas de saut, pas de taches séparées) : ~2,5 studs de large à 4 s, ~4 à 8 s, ~6 à 15 s, ~7 à 25 s, **~7,6 studs** au final (~45 s). Elle reste **centrée là où était la tête** quand le crâne a explosé : elle **ne glisse pas** (ni vers les jambes, ni sur le côté, même collée à un mur ou un bloc, même si le corps bouge), elle **grossit sur place**. Bord irrégulier (la forme de l'image), **même couleur partout** (le bord n’est pas plus clair que le milieu), **pas de disque plus clair dedans** : rouge frais au début, puis elle fonce en séchant. Les gouttes qui tombent du cou dedans font des **anneaux** et des **étoiles de gouttelettes** autour. |
| P2 | Finisher **bras** (Bouncer) | Sous l'**épaule** : une flaque **~7 studs** qui passe sous le torse. Le **bras jeté** par terre fait **sa propre flaque** (~2,6 studs) à son bout arraché ; s'il tombe près du corps et que les deux flaques se touchent, elles forment **une seule flaque** (même couleur, elles vieillissent ensemble, pas d'anneau jaune de l'une sur l'autre) mais **aucune ne bouge** : chacune continue de grandir à sa place. Tant qu'il est dans la main du Bouncer : pas de flaque sous le bras. Le sang passe **sous** le bras posé au sol. |
| P3 | Finisher **foie** (Boxer) | Pendant qu'il est tenu debout, le sang du **flanc** coule au sol sous lui ; quand le corps **tombe**, la flaque continue **là où le corps est couché** (**~6,4 studs**, sous le corps). Le **foie** jeté par terre fait une **petite flaque** (~1,6 stud) sous lui. |
| P4 | Finisher **portail** (Dr. Rift) | Le **haut du corps** : une flaque **~8,1 studs** sous la coupe (et sous le torse). Les **jambes** : **~6 studs** sous elles. Si les deux flaques se touchent (corps proches), elles forment **une seule grande flaque** (même couleur, elles vieillissent ensemble) sans bouger : chacune reste sous sa coupe et grandit sur place ; sinon deux flaques séparées, chacune uniforme. |
| P5 | Finisher **Bull** (déchiré en deux) | En l'air : pas de flaque sous les morceaux. Le **haut** glisse : la traînée de sang derrière lui, puis **une fois immobile** une flaque **~8,1 studs** sous sa coupe ; les **jambes** : **~6,4 studs** (une seule flaque si elles se touchent, sans bouger, comme P4). |
| P6 | Un corps qui **glisse** pendant qu'il saigne (foie, bras, portail) | Pas de flaque pendant qu'il glisse vite : des **traînées** (image `drag`) derrière la plaie (12 au plus), puis la flaque là où il s'arrête. |
| P7 | Finisher sur une **pente** | Toujours **une seule flaque** : son centre **ne bouge pas**, elle **s'allonge dans le sens de la pente** (autour de son centre) ; sur une vraie pente (> ~3-4°) **une seule petite coulure** collée à la flaque part vers le bas (≤ ~2,5 studs au-delà du bord). |
| P8 | Finisher contre un **trottoir / un mur** / au bord d'une **marche** | La flaque **ne bouge pas** (jamais poussée ni décalée) et **ne ressort jamais de l'autre côté** d'un mur : contre un mur **épais** (bloc, mur de la map) elle continue **sous** le mur (caché dedans), donc elle garde sa taille ; contre un mur **fin** (barrière, muret) elle **reste plus petite**. Un poteau fin : le sang passe **autour**. Au bord d'une marche elle **s'arrête** au bord (jamais dans le vide) et le sang **coule le long** de la marche. Un objet posé au sol non ancré (bras, caisse lâche) ne l'arrête pas (elle passe dessous). |
| P9 | Regarder la flaque de près, caméra basse | Pas de clignotement avec le sol ; deux flaques qui se chevauchent ne clignotent pas (hauteurs différentes) ; **jamais sur le corps** de la victime ni de l'attaquant (elle passe dessous). |
| P10 | Regarder la flaque pendant **4 min** | **Toute la flaque** garde la même couleur et vieillit d'un bloc : rouge sombre brillant tant qu'elle est alimentée, puis le reflet rétrécit, **bord sombre** (caillot) vers 30-60 s, **anneau jaune pâle** (sérum) vers 90-180 s, sèche et brunit, disparaît vers 4 min. |
| P11 | **2 joueurs** regardent le même finisher | La flaque a **la même forme** (même image, même orientation) sur les deux écrans, au même endroit (à quelques centimètres près : la physique du corps). |
| P12 | Un joueur qui **arrive après** le finisher (ou qui regarde le **corps figé** laissé ~10 s) | Les flaques sont **déjà là, à leur taille finale** (une seule flaque uniforme par plaie, **au même endroit** que pour un joueur qui a tout vu). Pas de **deuxième** flaque par-dessus quand le corps est remplacé par sa copie figée. (Foie : pas de flaque pour un joueur arrivé après — connu.) |
| P13 | 4-5 finishers d'affilée au même endroit + des combattants qui saignent (qualité **Low**) | Pas de lag (MicroProfiler : `BloodPool` reste petit : une flaque = 1 image + 1 reflet + au plus 1 coulure). Les flaques qui se chevauchent font une seule flaque (même couleur), sans bouger. Ce sont les petites flaques des saignements qui s'arrêtent de grandir d'abord. |
| P14 | Marcher dans une flaque de finisher fraîche (même au bord) | Empreintes sanglantes (comme W6), glissade possible en courant. |
| P15 | Sans images (`Config.Blood.IMAGES.pool`, `poolRim`, `poolLobe`, `serumHalo` à 0) | La même flaque en **formes simples** (ellipses, bord sombre, centre plus foncé), même taille. |
| P16 | `Config.Blood.FINISHER_POOLS.ENABLED = false` | Plus de grosses flaques ; les jets et leurs taches au sol sont toujours là. |
| P17 | Un combattant qui **saigne** debout ou KO (pas un finisher) | Sa flaque est elle aussi **une seule flaque uniforme** qui grandit doucement (pas de taches séparées) et continue de ramper ~3 s après la fin du saignement. |

## Membres qui partent à l'autre bout de la map (`fix/limbs-fly-away`)

Le bug : parfois les bras et les jambes d'un corps au sol partaient très loin, puis revenaient petit à petit sur le perso.
La cause : quand un corps tombe (ragdoll), chaque bras, jambe et la tête deviennent des morceaux séparés, tenus par une articulation molle. Le serveur ne prenait en charge que le tronc ; Roblox donnait les membres **à l'ordinateur d'un joueur** (la victime, ou le joueur le plus proche). Cet ordinateur avait encore le membre là où **son animation** le dessinait (une animation de finisher peut déplacer tout le corps de plusieurs mètres) et envoyait cette position à tout le monde : le membre « s'envolait », puis l'articulation le ramenait lentement.
Maintenant le **serveur** simule **tous** les morceaux du corps au sol (même chute pour tout le monde, un tricheur ne peut plus bouger ses membres KO), et chaque client remet tout de suite sur le corps un membre trop loin de son articulation.

Tester à **2 joueurs** (le bug venait d'un autre ordinateur), avec un peu de lag si possible (Studio : File → Studio Settings → Network → Incoming Replication Lag = 0,2).

| # | Test | Résultat attendu |
|---|---|---|
| M1 | Mettre l'autre joueur KO, plusieurs fois, sous plusieurs angles | Il tombe mou, **les bras et les jambes restent attachés** au corps, sur les deux écrans. |
| M2 | Tackle / Uppercut / Gravity Glove sur l'autre joueur (il tombe vivant), puis il se relève | Chute et relevé propres ; une fois debout il **contrôle de nouveau son perso** normalement (marcher, sauter, frapper). |
| M3 | Faire chaque finisher (Batte, KnockoutCombo, Arm Rip, Incinerate, Gore, Portal Cut) sur le **Dummy** et sur un **joueur** | À la fin, le corps tombe **là où il est** : aucun membre ne part au loin puis revient. Le bras arraché (Arm Rip) reste dans la main puis est lancé normalement ; les jambes (Gore, Portal Cut) se séparent normalement. |
| M4 | Gros combo sur le Dummy jusqu'au KO, puis attendre qu'il se relève | Pareil : membres en place, relevé propre. |
| M5 | Duel : perdre une manche | Le perdant tombe, membres en place ; la manche suivante il est debout et contrôle son perso. |
| M6 | **Dr. Rift** : **4** (Portal Gun) pendant que l'autre joueur te frappe ; essayer d'être mis au sol (Tackle / Uppercut) **juste en sortant** du portail (fenêtre très courte, 0,1 s) | Si ça tombe dedans : corps mou, membres en place sur les deux écrans ; une fois relevé, tu contrôles de nouveau ton perso. Sinon, le passage au portail reste normal. |
## Outils de test Studio (`feature/test-tools`)

Deux outils pour **regarder de l'extérieur** ce que tu ne peux pas voir seul (boiterie,
finishers). Ils n'existent **que dans Studio** (jamais dans le jeu publié), construits par
`Server/Systems/TestTools`. Pour les désactiver : `Config.Dev.TEST_TOOLS = false`.
Rien n'est sauvegardé dans la place : arrête le Play et tout disparaît.

Place-toi au spawn et regarde vers la **gauche** (le parcours de test est à droite) :

- **Limping Dummy** (marron), devant à gauche : il fait des allers-retours en boitant
  (~24 studs). Il s'arrête ~1 s à chaque bout (pose debout sur sa bonne jambe). À chaque
  tour, la jambe qui boite change (`LimpLeg` = Left / Right : visible seulement avec la
  boiterie de la branche `feature/limp-realistic` ; sur les autres branches il boite
  toujours pareil). On peut le frapper : touché (étourdi) il s'arrête sur place, puis repart
  vers le même bout. Sa vie revient après 3 s sans coup, ses bleus et coupures s'effacent
  un par un après ~13 s (comme le Dummy) ; il réapparaît 8 s après sa mort.
- **FINISHER DEMO**, derrière à gauche : une zone sombre au sol, un mannequin gris
  (« Finisher Victim ») et un bleu, et devant une rangée de **plots rouges**, un par kit
  (nom du kit + nom du finisher écrits au-dessus). Si tu tues un des deux mannequins
  hors démo, une paire neuve réapparaît ~4 s après.

| # | Test | Résultat attendu |
|---|---|---|
| 1 | Regarder le **Limping Dummy** de côté | Il marche lentement en boitant, jamais de pied dans le sol, il ne glisse pas. Debout aux bouts : appuyé sur sa bonne jambe. |
| 2 | Le suivre plusieurs tours | Il ne se bloque pas ; avec `feature/limp-realistic`, le côté de la boiterie alterne à chaque tour. |
| 3 | Aller à un plot rouge, appuyer sur **E** (« Watch finisher ») | Une nouvelle paire apparaît : le bleu (au nom du kit) met le gris KO, ~2 s après il fait **le finisher du kit** sur lui. **Ta caméra ne bouge pas** : tu regardes de l'extérieur (seuls les deux mannequins ont la cinématique). |
| 4 | Pendant la démo | Les plots sont désactivés (pas d'invite E) jusqu'à la fin. |
| 5 | Après la démo | Le corps reste ~8 s pour regarder les blessures, puis une paire neuve réapparaît debout et les plots se réactivent. |
| 6 | Tester chaque plot | STREET BRAWLER → **Bat** (la tête explose), BOXER → **KnockoutCombo** (foie arraché), SENTINEL → **Incinerate** (trou dans le cœur), BOUNCER → **ArmRip** (bras arraché, on peut prendre l'os). |
| 7 | Regarder depuis plusieurs angles (tourne autour pendant la démo) | Animations, sang, accessoires (batte, bras) visibles comme pour un vrai joueur. |

Si une démo ne démarre pas, l'Output affiche une ligne jaune `[TestTools] <kit> : ...` :
copie-la moi. Un nouveau kit avec un finisher aura **automatiquement** son plot.
## Interface : menu Kits, HUD, kill feed, écran de mort, écrans mobiles (`feature/ui-overhaul`)

| # | Test | Résultat attendu |
|---|---|---|
| U1 | Menu → **KITS**, choisir chaque kit | Sous MOVES et AWAKENING, une nouvelle section **FINISHER · ON A KO** : touche **[M1]**, le nom (**HOME RUN**, **LIVER RIP**, **ARM RIP**, **INCINERATE**) et une phrase. Le panneau est un peu plus haut, **CLOSE** reste en dessous, rien n'est coupé. |
| U2 | Kit verrouillé (niveau trop bas / pas assez de pièces) | Tout est visible mais plus terne (touches et noms), y compris le finisher ; l'action en haut à droite (LEVEL / BUY / NEED…) fonctionne comme avant (achat en deux clics, vérifié par le serveur). |
| U3 | Finisher sur le **Dummy** avec chaque kit | Kill feed en haut à droite : `TonNom finished Dummy — LIVER RIP` (tiret **rouge**, nom du finisher en petites capitales). |
| U4 | Tuer sans finisher (2 joueurs, l'autre tombe de la carte après un coup) | Ligne `X eliminated Y`, **sans** nom de finisher. |
| U5 | 2 joueurs : se faire **finir** | La cinématique joue d'abord **en entier**, puis en bas au centre : **FINISHED BY**, le nom du tueur, `LV 12  BOXER — LIVER RIP`, une ligne qui se vide et **RESPAWN 2.3** qui descend ; le monde perd ses couleurs. Au respawn tout disparaît en fondu. |
| U6 | Se faire tuer normalement | **ELIMINATED BY** + nom + niveau + kit, pas de tiret rouge. |
| U7 | Mourir seul (tomber de la carte, personne ne t'a frappé) | **ELIMINATED / YOU DIED**, pas de nom ni de kit. |
| U8 | En **duel** | Aucun écran de mort (l'écran de fin de duel reste le seul). |
| U9 | Deux joueurs avec le **même nom d'affichage** | Ta ligne du kill feed est la tienne (nom en gras blanc + petit trait) uniquement quand c'est vraiment toi (comparé par UserId). |
| U10 | *Test → Device* : **iPhone** (paysage), puis une petite fenêtre | HUD (vie à gauche, kit à droite), kill feed et tableau des joueurs plus petits mais lisibles, toujours dans leur coin. Le bloc du kit est **au-dessus du bouton de saut**. |
| U11 | Sur iPhone : **toucher** un move de la barre du kit | Le move part (comme la touche 1-4). Jauge pleine : toucher **[G] AWAKEN** lance l'Awakening. |
| U12 | Sur iPhone (paysage) / petite fenêtre : ouvrir le **MENU** (chaque section, surtout **KITS**) | Le menu commence **sous la barre Roblox** (boutons menu / chat / sac en haut à gauche) : **01, 02… et KITS se touchent** sans ouvrir le menu Roblox. La liste est plus près du bord gauche, le texte reste lisible (jamais plus petit que ×0.8). Si la section est trop haute, le panneau **défile** (glisser du doigt / molette, fine barre à droite) et **CLOSE** reste visible dessous ; changer de section repart en haut. La section choisie est entourée en ambre ; redimensionner la fenêtre recale tout. |
| U13 | Écran 1080p normal | Tout est **exactement comme avant** (mêmes tailles, mêmes places). En 1440p / 4K : un peu plus grand. |
| U14 | Shop / Profile après un achat | Pièces, niveau/XP, cosmétiques et stats se mettent à jour comme avant ; les soulignés (EQUIPPED, réglages ON/OFF) ont la bonne largeur, même sur iPhone. |
| U15 | Sur iPhone : le **HUD** pendant un combat | Le bloc de vie (chiffre, barres, XP) est **en haut à gauche, sous la barre Roblox**, plus en bas à gauche sous le joystick et le pouce. Sur PC il reste en bas à gauche. |
| U16 | Sur iPhone : kill feed et tableau des joueurs (Tab / bouton) | La première ligne du kill feed et le titre PLAYERS ne passent **jamais sous les boutons Roblox** en haut à droite (s'il y en a) ; sur PC 1080p ils restent à leur place. |
| U17 | Écran de mort (U5 / U6) | La **bande sombre** du bas apparaît **en fondu** avec le texte, et disparaît en fondu au respawn (plus de coupure sèche). |
| U18 | Finir le **Dummy** puis quitter le jeu pendant le finisher (ou finisher sans tueur crédité) | Si le kill feed n'a pas de tueur : `Dummy died` **sans** `— NOM DU FINISHER` derrière. |

## Interface : tout ce qui se clique ressemble à un bouton (`feature/ui-overhaul`)

Tout ce qu'on peut cliquer / toucher est maintenant un **vrai bouton** (un seul modèle,
`src/client/UI/Button.luau`) : fond plein, coins arrondis, contour ; il **s'éclaire et grossit un
peu** sous la souris, **s'enfonce** quand on appuie. L'action principale d'un écran est **ambre**
(EQUIP, BUY, FIND MATCH, CHALLENGE, ACCEPT, ON). Grisé = pas cliquable (avec la raison écrite
dessus). Sur téléphone les boutons sont plus hauts (doigt).

| # | Test | Résultat attendu |
|---|---|---|
| V1 | Arriver en jeu (PC) | À gauche au milieu : un bouton **MENU** bien visible (icône ☰, le mot MENU, la touche **M** dessinée dessus), **toujours entouré d'ambre avec l'icône ambre** (même après la première ouverture). Un **anneau ambre** en sort régulièrement tant que le menu n'a jamais été ouvert ; il s'arrête après la première ouverture. |
| V2 | Survoler / cliquer **MENU** | Le bouton s'éclaire et grossit un peu au survol, s'enfonce au clic ; le menu s'ouvre. |
| V3 | Touche **M** (hors chat) | Ouvre le menu sur la dernière section vue (pendant une recherche ranked / l'attente d'arène : sur **DUEL**, comme un clic sur MENU) ; **M** à nouveau (ou **CLOSE**, qui affiche aussi « M ») le ferme. Taper « m » dans le chat ne fait **rien**. Pendant l'écran de fin de duel (bouton MENU caché) : rien. |
| V4 | Liste des sections (01 KITS, 02 DUEL…) | Chaque section est un **bouton-onglet** (plaque légère). Survol : plus clair. La section ouverte : **contour ambre + barre ambre à gauche**, numéro ambre. |
| V5 | **KITS** → colonne ROSTER | Chaque kit est une **carte** (nom + ligne d'état). Le kit choisi a le contour ambre ; le kit équipé dit **EQUIPPED en ambre**. |
| V6 | KITS → **BOXER** (possédé, pas équipé) | En haut à droite un gros bouton **ambre EQUIP**. Clic → il devient le badge **✓ EQUIPPED** (contour ambre, pas de fond plein : on voit que ce n'est plus un bouton) et la carte BOXER dit EQUIPPED. Le serveur vérifie toujours. |
| V7 | KITS → kit pas encore acheté / verrouillé | Assez de pièces : bouton ambre **(pièce) BUY · 500** → 1er clic **CONFIRM · 500** (3 s), 2e clic **BUYING…** puis EQUIP. Refusé par le serveur : contour **rouge** un instant et retour à BUY. Pas assez de pièces : bouton **gris** « NEED 160 MORE » (rien ne se passe au clic). Niveau trop bas : bouton gris avec **cadenas** « UNLOCKS AT LV 10 ». |
| V8 | **SHOP** | Catégories en cartes (comme les kits), l'article équipé de chaque catégorie écrit en ambre. Chaque article : bouton **EQUIP** ambre / **BUY · 250** ambre (CONFIRM au 2e clic) / gris « LEVEL 10 » (cadenas) / gris « NEED 120 MORE ». L'article porté : **✓ EQUIPPED** avec contour ambre ; sur PC le survol affiche **TAKE OFF** et un clic l'enlève. Émotes : badge EQUIPPED (on ne peut pas l'enlever). |
| V9 | **SETTINGS** | Chaque réglage a deux boutons **OFF / ON** côte à côte : le choisi est plein (ON = ambre, OFF = sombre avec contour ambre), l'autre est une plaque légère qui s'éclaire au survol. Cliquer le côté déjà choisi ne change rien. Le réglage est toujours sauvegardé (rejoindre → même valeur). |
| V10 | **DUEL** | **FIND MATCH** = bouton ambre ; pendant la recherche **CANCEL** = bouton sombre. Chaque joueur de la liste : bouton ambre **CHALLENGE** (gris quand tu es en duel / en attente). |
| V11 | Recevoir un défi (2 joueurs) | Deux boutons : **✓ ACCEPT** (ambre, touche Y dessinée) et **✕ DECLINE** (sombre, touche N). Répondre avec Y / N fait aussi « enfoncer » le bouton. La barre de temps est juste en dessous, rien ne se chevauche. Recherche ranked en cours : la ligne « RANKED · SEARCHING » est **sous** le bouton MENU. |
| V12 | Jauge Street Fury pleine | **[G] AWAKEN** est sur une plaque ambre (et reste cliquable / touchable). |
| V13 | *Test → Device* : **iPhone** (paysage) | Boutons plus hauts (faciles à toucher), pas de touche dessinée (M / Y / N cachées). Pas d'effet de survol bloqué après un toucher. La barre de moves du kit a une plaque sombre arrondie par move. |
| V14 | iPhone, une émote équipée (SHOP → EMOTES) | Un bouton **EMOTE** au-dessus du bouton MENU ; le toucher joue l'émote (hors combat, vérifié par le serveur). Il disparaît quand le menu est ouvert, et n'existe pas sur PC (touche B). Dans SHOP → EMOTES, l'indice dit « TAP EMOTE ON THE SCREEN » (PC : « PRESS B »). |
| V15 | Manette (si dispo) | Sélectionner un bouton avec la manette l'éclaire comme le survol souris. |
| V16 | KITS ou SHOP : acheter avec un achat **refusé** (ex. Studio, retirer des pièces entre les 2 clics) | Après « BUYING… », le bouton revient à BUY avec un **contour rouge bien visible ~0,35 s**, puis repasse ambre. |
| V17 | Cliquer (plusieurs fois) un bouton **gris** (« NEED 160 MORE », « LEVEL 10 », « BUYING… ») ou double-cliquer EQUIP, avec un joueur / PNJ devant soi | **Aucun coup de poing** n'est donné. Plus généralement, aucun clic dans le menu ouvert ne lance de M1. |
| V18 | Cliquer **MENU** à la souris, puis fermer avec **M** (ou CLOSE) sans bouger la souris | Le bouton MENU revient **normal** (pas resté éclairé / grossi). Pareil pour les onglets 01, 02… à la réouverture. |
| V19 | Survoler EQUIP / BUY (KITS, SHOP), FIND MATCH / CANCEL / CHALLENGE (DUEL) | Le bouton grossit sans que son **contour soit coupé** à droite (ni en haut / bas). |
| V20 | *Test → Device* : **iPhone** paysage (844 × 390) : MENU, onglets, EQUIP / BUY, OFF / ON, FIND MATCH, CHALLENGE, CLOSE, ACCEPT / DECLINE | Chaque bouton fait **au moins ~44 px** de haut à l'écran (facile à toucher). La liste des sections **défile** au doigt si elle ne tient pas (fine barre à droite), rien ne passe sous l'écran. Dans SETTINGS / SHOP le texte d'une ligne reste centré sur son bouton ; dans DUEL, « ON THIS SERVER » est sous FIND MATCH sans chevauchement ; dans le défi, la barre de temps et son chiffre ne sont pas coupés. |

## Plus rien d'arraché en combat (`chore/remove-fractures`)

Le gore des « coups très forts » (`feature/gore-heavy-hits`) est **entièrement retiré** : plus de fractures ouvertes (os qui sort du corps), et plus de **bras arraché** après un gros combo. Le serveur ne compte plus les combos pour ça, `Config.HeavyGore` n'existe plus. **En combat normal, rien ne s'arrache.** Les **finishers ne changent pas** (Batte : tête qui explose ; Boxer : foie ; Bouncer : bras arraché ; Sentinelle : trou dans le cœur).

| # | Test | Résultat attendu |
|---|---|---|
| H1 | Plusieurs **gros combos** sur le même joueur / le Dummy (séries de 4 M1 enchaînées, au corps, à la tête, aux jambes), jusqu'au KO | **Aucun membre arraché**, aucun os qui sort, aucun trou dans un bras ou un tibia. Seulement les coupures, bleus et sang habituels. Le joueur ne boite que si ses jambes ont pris assez de coups (comme avant). |
| H2 | Tenir un **os** (arme) pendant un gros combo, puis le lancer | Il reste dans la main et se lance normalement (rien ne le fait tomber). |
| H3 | **Finishers** (Batte, KnockoutCombo, ArmRip du Bouncer, Incinerate, Gore, finisher simple) | Exactement comme avant : chacun avec **son propre** gore (le bras arraché n'existe **que** dans le finisher du Bouncer, et on peut toujours prendre l'os). |
| H4 | Ancien **ou** nouveau `WoundKit` (avec ou sans les anciens inserts `BreakArm` / `BreakLeg` et les pièces `Gore_ArmEndR` / `Gore_ShoulderR` / `Gore_LegEnd` / `Gore_Hip`…) | Les coupures, le trou de la Sentinelle, la tête de la batte, le foie et l'épaule ouverte du Bouncer s'affichent normalement ; aucune erreur ni avertissement en plus dans Output. |
| H5 | Dans l'Explorer pendant / après un combat | Pas de dossier `Workspace > TornLimbs`, aucun attribut `LimbTorn_*` sur les combattants. |
| H1 | **Gros combo** (2 séries de M1 enchaînées sur le même joueur), le 4ᵉ M1 de la 2ᵉ série **au corps** | Parfois : **fracture ouverte de l'avant-bras** du côté touché. Un **trou déchiré** s'ouvre dans l'avant de l'avant-bras (la peau et le t-shirt percés, bord de peau à vif retroussé) ; dedans : la **graisse jaune** sous la peau, les **vrais muscles** de l'avant-bras déchirés (deux rouges), du sang caillé, des **vaisseaux et nerfs** arrachés qui pendent (artère rouge, veine sombre, nerf jaune pâle), des **éclats d'os**. Le **vrai radius** cassé **sort du trou** en biais vers le bas, un **bout court et épais** (pas une plaque) : cassure irrégulière, **anneau d'os blanc épais (cortex) autour de la moelle rouge sombre** enfoncée dans l'os, du sang autour là où il sort de la peau ; le **cubitus** cassé se voit au fond. Craquement, giclée de sang, le sang coule sur la peau. Les autres joueurs voient la même chose. |
| H2 | Pareil, le coup lourd **aux jambes** | Parfois : **fracture ouverte du tibia** (sur le devant) : un trou **plus petit** que celui du bras ; le **bout cassé du vrai tibia** (le morceau du bas) **sort du trou vers le haut et vers l'avant**, court et épais : vu d'au-dessus (caméra 3ᵉ personne) on voit **l'anneau blanc de l'os et la moelle rouge sombre au milieu**, du sang en collier là où il sort de la peau ; l'autre morceau du tibia et le péroné restent dedans. Ça doit se lire comme **un os cassé**, pas comme une feuille blanche. Le joueur **boite** tout de suite (et après s'être relevé d'un KO). |
| H3 | Gros combo, coup lourd au corps ou à la tête, plus rare | Le **bras du côté touché** est **arraché** à l'épaule et **vole** loin de l'attaquant (avec sa manche et un accessoire porté dessus). Sur le torse : l'**épaule ouverte** (vraie omoplate, muscles arrachés), la **peau déchirée en bord irrégulier** (plus de « pétales »), la graisse jaune dessous ; elle **gicle par saccades**, flaque. Le bras au sol : bout à vif, **tête de l'humérus** qui dépasse, peau déchirée irrégulière ; il gicle, goutte, reste ~12 s puis disparaît. Solide sur la carte mais **pas pour les combattants** ; le **viseur passe à travers** ; un finisher peut se placer par-dessus. |
| H4 | Après H3 (bras arraché, **toujours vivant**) | Le joueur **joue toujours** (il manque juste le bras) : animé normalement (marche, M1, garde), y compris vu par un joueur qui **rejoint après** ; il ne peut plus prendre d'os sans bras droit ; ses finishers cinématiques demandent ses deux mains → **finisher simple** à la place. Le Bouncer sur une victime sans bras droit : finisher simple. |
| H5 | **Finishers** (Batte, KnockoutCombo, ArmRip, Incinerate, Gore, finisher simple) | **Aucun** membre arraché, **aucune** fracture, aucune dent, rien de ce gore-là en plus de leur propre gore. |
| H6 | Combo **trop petit** (1 série de M1), ou des coups **bloqués**, ou **2 attaquants** qui se relaient, ou une pause > 1,6 s | Jamais rien (le combo ne compte que les coups qui touchent, du même attaquant, enchaînés). |
| H7 | Fracture (H1/H2), puis le joueur **tue** quelqu'un (soins du tueur) | Coupures et bleus guérissent, mais la **fracture reste** (et l'os qui sort), il **boite toujours** si c'est la jambe ; un bras arraché reste arraché, jusqu'à la mort. |
| H8 | Un joueur qui **arrive après** / le **corps laissé** après un finisher | Il voit les mêmes plaies (fracture, épaule ouverte), sans rejouer les jets de sang. |
| H9 | Plafonds | Jamais plus de **2 membres arrachés** (le bras du Bouncer compris) ni **2 fractures** par corps ; un membre déjà cassé : c'est l'autre bras / l'autre jambe (le côté opposé) qui casse. Les **jambes** ne sont jamais arrachées (`TEAR_LEGS = false` : un corps R6 sans jambe ne tient pas debout). |
| H10 | Duel | Rien de tout ça en duel (`IN_DUELS = false`). |
| H11 | Vision de la Sentinelle, prise du Videur | Ne comptent pas (pas de coup lourd de ce genre). |
| H12 | Ancien `WoundKit` (pas ré-importé) | La fracture est dessinée en **forme simple** (disque à vif, os en bloc) sur l'avant-bras / le tibia ; ré-importer le kit l'ouvre pour de vrai (sans se reconnecter). |
| H13 | `Config.HeavyGore.ENABLED = false` ou `Injuries.SKIN_TEAR = false` | Plus aucun de ces effets. |
| H14 | **Rareté** : un combat normal (plusieurs gros combos) | La plupart des combats : **rien**. Un gros combo = **un seul** tirage (20 % fracture, 5 % bras) ; le coup lourd suivant du **même** combo ne retire pas. Une jambe ne fait jamais de fracture « en plus » (jamais plus que `FRACTURE_CHANCE`). |
| H15 | Tenir un **os** (arme) dans la main droite, puis se faire **arracher le bras droit** (H3) | L'os **tombe et se casse** tout de suite (il ne reste pas collé au bras qui vole) ; plus d'arme en main ; **impossible de lancer** quoi que ce soit sans bras droit. |
| H16 | Rejoindre la partie / se faire arracher un bras **pendant que le `WoundKit` charge encore** | D'abord une forme simple possible, puis dès que le kit est là, l'**épaule ouverte** et le **bout du bras** sont redessinés avec les vraies pièces (sans se reconnecter). |

## Interface minimaliste : petite, discrète, pas « faite par un bot » (`feature/ui-fighting-style`)

Retour du joueur : « encore trop grand, il faut vraiment très minimaliste, pas de couleurs flashy,
pas de trucs qui font IA ». Toute l'interface passe par le thème (`src/client/UI/Theme.luau`) et
le bouton commun (`src/client/UI/Button.luau`) :
- **plus petit** : sur PC le menu entier est dessiné à **×0,9**, l'en-tête des sections passe de
  116 px à 52 px, titres à 20 px (au lieu de 40), boutons 24–32 px de haut ;
- **une seule police** (Builder Sans) en **3 tailles** (20 titres, 13 texte, 11 petit),
  **espacement normal** des lettres (plus d'espaces entre les lettres) ;
- **plus de gros blocs rouges** : une liste = des **mots** (gris = pas choisi, **blanc + fine barre
  rouge** = choisi, blanc = sous la souris). Bouton principal (EQUIP, BUY, FIND MATCH…) = **petit
  contour blanc** avec une **courte marque rouge** à gauche, il se **remplit de blanc** au survol ;
- **retirés** : les « // », les numéros « 01 02 03 », les micro-titres en majuscules espacées
  (« FIGHTING STYLES · 5 OF 5 AVAILABLE », « ROSTER », « MENU », « CATEGORY », « TODAY »…), le
  trait rouge sous le titre, les contours épais ; les petits textes sont en **phrases normales**
  (« Equipped », « Locked, level 10 », « New quests in 05:12:33 ») ;
- **fond transparent** : l'ombre derrière le menu est légère, le flou et la perte de couleur du
  monde sont plus faibles : **on voit le jeu derrière**.
Tout fonctionne comme avant (mêmes boutons, mêmes vérifications serveur). Ces tests **remplacent
F1–F14** de la version précédente de cette branche.

| # | Test | Résultat attendu |
|---|---|---|
| M1 | Ouvrir le menu (**M** ou MENU) sur PC en 1920 × 1080 | Le menu prend **nettement moins de place** qu'avant : liste de sections étroite à gauche, panneau plus petit, **le jeu reste bien visible** à droite et derrière (ombre légère, peu de flou). Titre de section **petit** (« KITS »), **pas** de trait rouge ni de ligne sous le titre, **pas** de mot « MENU » au-dessus de la liste. |
| M2 | Liste des sections | De simples **mots** (KITS, DUEL, QUESTS…) **sans numéro** et **sans plaque**. Non choisis : **gris**. Section ouverte : **blanche** avec une **fine barre rouge verticale** à gauche. Aucun « // ». |
| M3 | Survoler une section / un bouton (PC) | Le texte devient **blanc** (+ une barre grise très légère et un fond à peine visible pour une section). Les boutons à contour : contour plus net ; le bouton principal se **remplit de blanc** (texte noir). Rien ne grossit. |
| M4 | Cliquer un bouton | Petit **rétrécissement rapide** (×0,96) puis retour. Les listes ne bougent pas. |
| M5 | **KITS** | Pas de sous-titre « FIGHTING STYLES · … », pas de « ROSTER ». À gauche : noms des kits, avec en dessous une **petite ligne normale** (« Equipped », « Owned », « Locked, level 10 », « 500 coins », « Need 160 more coins »). Kit regardé : blanc + barre rouge ; kit verrouillé : plus sombre + **cadenas**. À droite : nom du kit **petit**, description grise, titres « Moves / Stamina / Cooldown », « Awakening / Lasts », « Finisher / On a KO » en **minuscules normales**, pas de barre rouge devant l'Awakening. En haut à droite : « **820 coins** » sur une ligne. |
| M6 | KITS → EQUIP / BUY | **EQUIP** / **BUY · 500** = **petit bouton à contour blanc** avec une **marque rouge** à gauche (pas de bloc rouge). Après EQUIP : « **✓ EQUIPPED** » = coche rouge + mot, **sans cadre** (pas un bouton). « NEED … MORE » / « UNLOCKS AT LV 10 » = bouton grisé. BUY → CONFIRM → achat refusé : **contour rouge** ~0,35 s puis retour à BUY. |
| M7 | **SHOP** | Même liste que les kits à gauche (catégories, ligne « ce que tu portes » / « None equipped »). Pas de sous-titre « COSMETICS · … », pas de « CATEGORY ». Article porté : nom blanc + **fine barre rouge** à gauche, bouton **EQUIPPED** à contour avec un **trait rouge dessous** (survol PC : TAKE OFF ; téléphone : TAKE OFF? puis 2ᵉ tap). EQUIP = contour discret. Indice des emotes : « Press B ». |
| M8 | **DUEL** | Titres « Ranked », « On this server », colonnes « Rank », « 5 players » en texte normal. Rang (SILVER) et ELO **petits**. Ligne « 188 to Gold · 15 wins · 9 losses ». FIND MATCH / CHALLENGE = bouton principal (contour + marque rouge), CANCEL = contour discret. Recherche : « Searching · 0:23 », « Matching within ±200 ELO ». |
| M9 | **QUESTS** | Plus de « TODAY / REWARD » ni de sous-titre : directement les 3 quêtes (texte 13 px, ligne de progression fine), « Done » quand finie, et en bas « New quests in 05:12:33 » qui décompte. |
| M10 | **PROFILE** | Sous-titre = **ton nom** seulement. « Level 8 of 100 » plus petit, « 64 XP to level 9 », « 1 382 XP total », titres « Record », « Ranked », « Next unlock » en texte normal, chiffres plus petits. |
| M11 | **SETTINGS** | OFF / ON = deux **mots** : le choisi est **blanc avec un trait rouge dessous**, l'autre gris ; cliquer l'autre change bien le réglage (caméra 1ʳᵉ personne, bloquer les duels) et c'est sauvegardé. |
| M12 | Bouton **MENU** (menu fermé) + **CLOSE** | MENU : petit bouton à contour fin, **marque rouge** à gauche, touche « M » ; avant la 1ʳᵉ ouverture un **anneau fin gris** pulse doucement. CLOSE : petit bouton discret avec « M ». |
| M13 | HUD (PV / stamina / niveau) | Bloc plus petit : chiffre des PV **22 px** (au lieu de 30), « Health », « Stamina », « Lv » en texte normal ; « Winded », « Guard », « Limping », « Bleeding » selon l'état. Récompenses : « Kill +50 XP · +10 coins ». |
| M14 | Jauge Street Fury pleine | **[G] AWAKEN** = petit bouton à **contour** avec une **marque rouge** (plus de plaque rouge pleine), cliquable / touchable ; « Low stamina » sur un move sans assez d'endurance. |
| M15 | Kill feed + écran de mort | Kill feed : texte un peu plus petit, bande sombre plus légère. Écran de mort : « Eliminated by » / « Finished by » / « You died » en texte normal, nom du tueur **22 px**, « Lv 17 », « Respawn » + compte à rebours. |
| M16 | **TAB** (scoreboard) | Titre « PLAYERS » petit, « This session », colonnes « Lv / Player / Kills / Deaths », ta ligne marquée d'une **fine barre rouge**, « Release to close ». |
| M17 | Duel (compte à rebours, fin de manche, résultat) / KO / niveau supérieur | Les gros mots (FIGHT, VICTORY, KNOCKED OUT, LEVEL 10…) sont **plus petits** qu'avant (28 px max au lieu de 40) et sans lettres espacées. |
| M18 | *Test → Device* : **iPhone** paysage | Le menu n'est **pas** réduit à ×0,9 (doigts) ; les boutons sont dessinés petits mais leur **zone de tap** reste haute (≥ ~44 px à l'écran) : taper un mot de la liste ou EQUIP marche du premier coup. |
| M19 | Fenêtre Studio **petite** (~830 × 515) puis plein écran : ouvrir chaque section | Le menu est **plus petit qu'avant même sur une petite fenêtre** (×0,9 appliqué après l'ajustement à l'écran). KITS : lignes de moves plus serrées, Awakening et Finisher remontés, rien n'est coupé ni ne se chevauche. DUEL / PROFILE / QUESTS : **plus étroits** (480 au lieu de 560) ; QUESTS n'a plus de grand vide sous le décompte. DUEL : échelle des rangs sur toute la largeur, noms des joueurs coupés par « … » s'ils sont longs, colonne « Rank » alignée. PROFILE : les 4 cases Record tiennent, les phrases de Ranked / Next unlock ne passent pas sous les chiffres. |
| M20 | Duel : défi reçu / défi refusé / recherche / en duel / résultat ; KO | Plus d'étiquettes en majuscules avec « · » : « Duel request », « Your challenge », « Searching 0:12 », « Waiting for an arena » en texte normal. En duel, en haut : seulement « Round 2 » (plus de « RANKED · … · BEST OF 3 »). Résultat : juste « 12 Vex » au-dessus de VICTORY/DEFEAT (plus de « RANKED · VS ») ; tableau sans légendes REWARDS / RANK : « +100 XP · +25 coins », « ELO 1088 → 1112 +24 », « Gold » (ou « Silver → Bronze »), « No reward (forfeit) ». KO : plus de « YOU ARE DOWN » au-dessus de KNOCKED OUT. |


## Interface : barre du haut et panneaux à cartes (`feature/ui-fighting-style`)

Nouvelle direction (d'après les captures du jeu de référence) : **plus de grand menu**. Une rangée
de **boutons ronds dans la barre Roblox**, juste à droite des boutons Roblox (menu, chat, micro) :
**Kits** (icône + mot), **Duel**, **Rewards**, **Emotes**, **Shop**, **Profile**, **Settings**
(icônes seules, le nom apparaît sous la souris). Chaque bouton ouvre **son panneau** : une plaque
noire transparente sans bordure, petits onglets au-dessus à gauche, titre gras centré, cartes.
Carte **portée / équipée** = **fin contour doré** + « EQUIPPED » doré ; carte **choisie** = carte plus
claire + **fin contour blanc**. Plus de barre rouge pour la sélection (onglets : trait **blanc**).
Ces tests **remplacent M1, M2, M5, M7, M9, M12, M18 et M19** ; les autres M restent valables.

| # | Test | Résultat attendu |
|---|---|---|
| T1 | Arriver en jeu (PC 1920 × 1080) | En haut à gauche, après les boutons Roblox : 7 boutons ronds sombres **de la même hauteur** que ceux de Roblox (44 px), le premier avec « **Kits** » écrit. Plus de bouton MENU à gauche de l'écran. Survoler une icône : son nom (« Duel », « Rewards »…) s'affiche dessous, le bouton s'éclaircit. |
| T2 | Cliquer **Kits** | Un panneau s'ouvre **sous la barre, centré** ; le bouton Kits devient **blanc** (icône noire). Titre « KITS » gras centré, « 820 coins » en haut à droite. À gauche une grille de **cartes** (2 par ligne) : chaque kit en **silhouette R6 noire posée** (Boxer en garde, Bouncer bras croisés…), nom en gras blanc, en dessous « EQUIPPED » (doré), « OWNED », « LEVEL 8 », « 800 COINS », « NEED 160 MORE ». À droite : nom du kit, description, Moves / Awakening / Finisher, et **EQUIP** / **BUY · 800** en haut à droite. |
| T3 | Cliquer une autre carte de kit puis **EQUIP** | La carte cliquée devient plus claire avec un contour **blanc** ; après EQUIP elle prend le contour **doré** et « EQUIPPED ». Les touches 1–4 / G suivent. BUY → CONFIRM → achat (vérifié par le serveur) comme avant. |
| T4 | Cliquer **Kits** à nouveau / **Échap** / cliquer dans le monde hors du panneau | Le panneau se ferme à chaque fois. Le clic dans le monde qui ferme le panneau **ne donne pas de coup de poing**. |
| T5 | Panneau ouvert, cliquer un **autre** bouton de la barre | Le premier panneau disparaît, l'autre s'ouvre (un seul à la fois). |
| T6 | Touche **M** (hors chat) | Rouvre le **dernier panneau vu** (le premier fois : Kits ; pendant une recherche classée : Duel) ; **M** à nouveau le ferme. Taper « m » dans le chat : rien. |
| T7 | **Rewards** → onglet **REWARDS** | Onglets « REWARDS | CHALLENGES » au-dessus du panneau à gauche (onglet ouvert : texte blanc + trait blanc dessous). Case **LEVEL** avec ton niveau à gauche, « 92 / 100 XP », à droite « Level 10: HEAVY HANDS » (le prochain déblocage), **barre verte**. En dessous une **piste de cartes** qui défile de côté : tout ce qui se débloque par niveau (kits, titres, tenues, effets, émotes), numéro de niveau en haut à gauche, type en haut à droite. Atteint : numéro et « UNLOCKED » dorés ; le prochain est mis en avant (contour blanc). Cliquer une carte ouvre **Kits**, **Shop** ou **Emotes** sur cet objet. |
| T8 | **Rewards** → **CHALLENGES** | Les 3 défis du jour en **3 grandes cartes** : numéro, « DAILY », la phrase en gros, une barre verte, la récompense « +110 XP · +55 coins », « 3 / 5 » (ou « DONE » doré + contour doré). En bas : « New challenges in 05:12:33 » qui décompte. |
| T9 | Finir un défi (ou passer un niveau qui débloque quelque chose), panneau fermé | Une **pastille blanche** avec un nombre apparaît sur le bouton **Rewards** (et sur l'onglet concerné). Ouvrir le panneau (il s'ouvre sur CHALLENGES s'il n'y a que des défis à voir) puis regarder l'onglet : la pastille disparaît. Au premier lancement, les défis déjà finis ne comptent pas. |
| T10 | **Shop** | Onglets **TITLES / OUTFITS / KILL EFFECTS**, 4 cartes par ligne : titres = le mot en gros, tenues = une **silhouette aux couleurs** du haut et du bas, effets = une étoile. Sous la grille, une barre : nom + phrase de l'article choisi, et à droite **BUY · 250** / **EQUIP** / **TAKE OFF** / « LEVEL 10 » / « NEED 120 MORE » (grisés). Acheter (2 appuis), équiper, retirer : marche comme avant, le contour doré suit. Les coins en haut à droite se mettent à jour. |
| T11 | **Emotes** | Sous-titre « Equip one, then press B to play it ». Cartes des émotes (silhouette dans la pose de l'émote). Équiper une émote → sa carte dorée, et le bouton devient **PLAY [B]** : il joue l'émote (hors combat, vérifié par le serveur), comme la touche B. |
| T12 | **Duel**, **Profile**, **Settings** | Même contenu qu'avant dans le nouveau panneau (titre centré ; Profile : ton nom en sous-titre). Tout marche : FIND MATCH / CHALLENGE, réglages sauvegardés. Dans Settings, OFF / ON : le choisi a un trait **blanc** (plus rouge). |
| T13 | Recherche classée, panneau fermé | « Searching 0:12 » s'affiche **sous la barre du haut**, à gauche. |
| T14 | Fin de duel (écran VICTORY / DEFEAT) | La barre du haut **disparaît** (et le panneau ouvert se ferme), puis revient au retour dans l'arène. |
| T15 | *Test → Device* : **iPhone** paysage | Les boutons sont dans la barre Roblox ; s'ils ne tiennent pas tous, la rangée **défile du doigt** sur le côté. Un panneau tient sous la barre (réduit, jamais sous ×0,75) ; s'il est trop haut il **défile**. Toucher hors du panneau le ferme. Bouton **EMOTE** (émote équipée) à gauche au milieu de l'écran, caché quand un panneau est ouvert. |
| T16 | Fenêtre Studio petite (~830 × 515) puis plein écran | Panneaux réduits pour tenir, recalés au redimensionnement ; sur un grand écran (1440p) un peu plus grands. |
| T17 | Kill feed + écran de mort | Kill feed : **noms en gras blanc** (le tien plus épais), bande sombre un peu plus marquée. Écran de mort : sur **une plaque noire transparente**, carrée (plus transparente que les panneaux, qui sont maintenant presque noirs et arrondis, voir R3). |
| T18 | **Shop**, **Kits**, **Profile** : regarder « 820 coins » | Les coins sont **sur la ligne du titre**, en haut à droite, **hors du contenu** : ils ne cachent ni le type ni le haut des cartes (Shop), ni le nom du kit (Kits), ni les stats (Profile), et **ne défilent pas** quand le contenu défile (petite fenêtre). |

## Barre du haut et panneaux au style Roblox (`fix/topbar-visible-2`)

Même fonctionnement qu'avant ; seul l'aspect change, copié sur la barre et les menus sombres de
Roblox (valeurs et sources : `docs/UI_ROBLOX_STYLE.md`). Ces tests remplacent l'aspect décrit
dans T1, T2 (bouton blanc), T7 (trait blanc sous l'onglet) et T17 (l'écran de mort ne ressemble plus aux panneaux) ; le reste de T1–T18 reste valable.

| # | Test | Résultat attendu |
|---|---|---|
| R1 | Arriver en jeu (PC) | Après les boutons Roblox : une pastille **Kits** (icône + mot), puis **une seule pastille** qui regroupe les icônes Duel, Rewards, Emotes, Shop, Profile, Settings, comme la pastille menu / chat / micro de Roblox. Même hauteur (44 px), même noir transparent, mêmes bords arrondis que les pastilles Roblox. Icônes blanches **en traits fins**, toutes du même poids et de la même taille. |
| R2 | Survoler une icône | Un léger rond clair apparaît derrière l'icône (comme sur Roblox) ; son nom s'affiche dessous dans une petite bulle sombre arrondie. |
| R3 | Ouvrir un panneau (clic sur une icône ou sur Kits) | L'icône garde un **rond pâle** derrière elle tant que le panneau est ouvert (plus de bouton tout blanc). Le panneau : plaque **presque noire** aux **coins arrondis**, titre gras centré, **fine ligne grise** sous le titre. |
| R4 | Onglets (Rewards, Shop) | Petits onglets arrondis : l'ouvert est **gris plus clair** avec texte blanc, les autres sombres avec texte gris (plus de trait blanc dessous). |
| R5 | Cartes (Kits, Shop, Rewards) | Cartes **gris foncé arrondies**, plus claires au survol ; choisie = contour blanc ; portée = contour doré (comme avant). Barres de progression arrondies. |
| R6 | Boutons **EQUIP** / **BUY** / **FIND MATCH** | Bouton principal **blanc, texte sombre** (comme les boutons Roblox), un peu gris au survol. Les autres boutons : sombres, contour discret, coins arrondis. Plus de petite marque rouge. |
| R7 | Pastille de nombre (finir un défi) | Petit rond **blanc** avec un nombre sombre en haut à droite de l'icône **Rewards**, dans la pastille groupée. |
| R8 | iPhone paysage / ancienne barre Roblox (36 px) | Les pastilles rapetissent pour avoir la hauteur de la barre Roblox ; tout reste cliquable. |
| R9 | Regarder les icônes de près | Settings = un **engrenage** (dents pleines collées à l'anneau, moyeu ouvert), différent de l'étincelle des effets ; Shop = un **chapeau** (haut évasé, bande, large bord) ; Duel = **deux épées croisées** (garde en travers près de la poignée, poignées dans les coins du bas) ; Emotes = un **smiley**. Tous les petits ronds ont un trou bien visible. |
| R10 | Acheter dans Shop ou Kits | Pendant « BUYING… » (et après EQUIP), le bouton reste **blanc grisé** avec le texte sombre **bien lisible** (il ne disparaît plus). |
| R11 | Téléphone : toucher une icône puis fermer le panneau | Aucun rond clair ne **reste collé** derrière une icône ; pareil pour les onglets et les cartes des panneaux (pas d'effet de survol au doigt). Panneau ouvert : rond pâle léger derrière son icône. |
## Vitres réalistes (`feature/realistic-glass`)

Détails, réglages et import des 4 images : `docs/GLASS_FR.md`. Les tests V1 à V5 et V8 marchent **même sans les images** ; V6 et V7 ont besoin des images importées.
Pour forcer la pluie (barre de commande, côté **Server**) : `workspace:SetAttribute("WeatherForce", "Rain")` (ou `"Storm"`).

| # | Test | Résultat attendu |
|---|---|---|
| V1 | Play, attendre que la ville soit construite, regarder une **vitrine** de boutique (B1, B5, B12) depuis le trottoir, *Graphics quality* 8 ou plus | Verre clair légèrement vert-gris : on voit la pièce sombre derrière, avec le **reflet** de la rue et du ciel par-dessus, plus fort quand on la regarde de biais. Pas d'ombre noire de la vitre au sol. Output : aucune ligne rouge. |
| V2 | Regarder les **fenêtres des étages** | Verre sombre qui reflète le ciel, chaque fenêtre un peu différente (plus verte, plus bleue, plus claire). La nuit, certaines s'allument comme avant ; éteintes, elles redeviennent en verre. |
| V3 | Les **portes vitrées** (s'ouvrent quand on approche), la cabine téléphonique | Même verre clair que les vitrines ; les portes s'ouvrent et se ferment comme avant. |
| V4 | *Graphics quality* **1 à 3** | Les vitrines passent en plastique gris transparent (elles ne disparaissent pas). Remettre 8 : redeviennent du verre en ~5 s. |
| V5 | Entrer dans le **bar** (Duffy's) ou une boutique, regarder dehors par la vitrine sous la pluie | Depuis l'intérieur la vitrine est en plastique transparent : **on voit la pluie** dehors. Ressortir : redevient du verre. |
| V6 | Forcer **Rain**, rester près des vitrines / fenêtres | En ~20 s des **gouttes** apparaissent sur les vitres exposées (petits points avec reflet blanc), des gouttes **coulent lentement vers le bas** avec une traînée. Plus rapide pendant un orage. Vitres sous un **auvent** (B7, B11) : sèches. Depuis l'intérieur, les gouttes se voient aussi sur la vitrine. **Si elles remontent** : `RUN_DIRECTION = -1` dans `Config.Glass`. |
| V7 | Attendre la **fin de la pluie** | L'eau arrête de couler, puis les vitres sèchent en ~25 s. Plus rien sur les vitres. Saleté légère toujours là près de toi (bas de vitre un peu plus poussiéreux, bord un peu plus sombre). |
| V8 | Casser une vitrine avec un coup lourd (charge du **Bull**, atterrissage du **Sentinel**) | Éclats de verre **fins et transparents** qui volent puis restent au sol 16-22 s, un flash froid très court, des paillettes, le **bruit de verre brisé**. Pas de gros cubes de verre. La vitrine revient ~25 s après, en verre (et avec la pluie si il pleut). |
| V9 | *Test → Clients and Servers → 2 Players*, regarder les vitres | Même verre et mêmes teintes chez les deux joueurs. Les gouttes ne sont dessinées que chez chacun, près de lui. |

## Brûlures v2 (`feature/burns-v2`)

Détails et import des images : `docs/BURNS_FR.md`. Tout marche **sans les nouvelles images** (anciennes images + particules Roblox) ; la tache du laser (B3) a besoin de `spot.png`. Prendre le kit **Rift** contre un mannequin ou un 2e joueur (*Test → Clients and Servers → 2 Players*).

| # | Test | Résultat attendu |
|---|---|---|
| B1 | Toucher avec la **fiole explosive** (feu) | Le membre touché rougit, puis la peau part (rouge mouillé, peau blanche qui pèle), puis escarre beige, puis noir carbonisé si ça dure. Les flammes **montent** vers le torse et la tête ; vraies langues de feu, fumée noire, braises, lumière orange qui vacille. |
| B2 | Laisser le feu s'éteindre | Les flammes partent, le corps **fume** gris quelques secondes (braises sur le noir), puis plus rien. Les brûlures **restent**. Pas d'erreur dans l'Output. |
| B3 | **Rayon** (pistolet laser) sur le torse, puis au même endroit | Une **tache** profonde (cratère noir, anneau blanc, peau rouge pelée autour) là où il touche, qui s'aggrave au même endroit ; à peine de flammes, presque pas de propagation. |
| B4 | **Acide** (fiole acide, puis rester dans la flaque) | Tache jaune-brun, puis peau rongée jaune-brun / chair à vif, puis escarre brun-noir, avec des **coulures vers le bas** ; mousse, vapeur pâle, gouttes. Dans la flaque : les **pieds / jambes** d'abord. Jamais de flammes. |
| B5 | Un personnage **avec T-shirt / pantalon** brûlé | Le tissu roussit, se carbonise, des **trous brûlés** montrent la peau brûlée ; au degré 4 le tissu est fondu dans la peau noire. |
| B6 | Tuer quelqu'un **pendant** qu'il brûle (finisher) | Le corps brûle encore ~4 s puis fume. Après la réapparition, la **copie du cadavre** a les mêmes brûlures (et brûle encore un peu si elle était en feu). |
| B7 | 2e joueur : regarder la même victime | Mêmes brûlures aux mêmes endroits, mêmes membres en feu. Un joueur qui rejoint après voit aussi les brûlures. |
| B8 | Kill (la vie remonte) / nouvelle manche / réapparition | Les brûlures et les flammes partent. |
| B9 | Brûlé en vue à la 1re personne | Pas de flammes ni de fumée devant la caméra (celles de la tête sont cachées), le reste du corps brûle normalement. |
| B10 | Vision thermique du **Sentinel** | Le trou dans la peau comme avant ; pas de flammes. |
