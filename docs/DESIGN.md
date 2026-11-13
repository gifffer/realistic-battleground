# Realistic Battleground — document de design

> À coller au début d'un nouveau chat pour reprendre le projet.
> Les valeurs chiffrées (dégâts, cooldowns, prix…) sont des **points de départ** :
> elles vivront dans des fichiers de config (`src/shared/Config/…`) et seront ajustées en testant.
> Rappel : on discute en français, mais **tout le texte visible dans le jeu est en anglais**.

## Équipe & méthode
- Niveau : débutant / intermédiaire → code commenté et expliqué. Exigence : **qualité avant vitesse**.
- Repo : **https://github.com/gifffer/realistic-battleground** (branche `main`, une branche par fonctionnalité).
- Workflow : **Rojo** (guide : `docs/SETUP_FR.md`). Ne jamais modifier les scripts synchronisés dans Studio.
- Structure : `src/shared` (ReplicatedStorage.Shared), `src/server` (ServerScriptService.Server),
  `src/client` (StarterPlayerScripts.Client). Luau `--!strict`, bootstrap init()/start().
- **Serveur autoritaire** : le client envoie des *intentions* (« je veux attaquer »), le serveur
  décide de tout (touché ou non, dégâts, récompenses). Remotes déclarés dans `Shared/Remotes.luau`,
  validés et limités en fréquence.

---

## 1. Le concept en une phrase
Un jeu de combat « battlegrounds » **à personnages (kits)**, au style **réaliste** :
combats de rue au corps à corps, coups lourds, blessures, ragdoll, dans un quartier urbain.
On se bat en **arène libre**, et on peut **défier quelqu'un en duel** (best of 3).

## 2. Paramètres généraux
| Élément | Choix |
|---|---|
| Plateforme | **PC uniquement** (clavier + souris) |
| Joueurs / serveur | **16** |
| Avatars | **R6 forcé** (6 parties du corps → animations bien plus simples à faire ; ragdoll et dégâts localisés restent possibles) |
| Caméra | **3ᵉ personne épaule par défaut** ; 1ʳᵉ personne activable dans le menu **Settings** (choix sauvegardé) |
| Map | **Quartier urbain** (ruelles, parking, entrepôt ouvert) + **arène(s) de duel** à l'écart |
| Éclairage | `Future`, post-processing (Bloom, ColorCorrection, DepthOfField léger, Atmosphere) |

## 3. Modes de jeu

### 3.1 Arène libre (mode principal)
- Tout le monde se bat en continu dans le quartier.
- **KO puis achever** : à 0 PV le joueur tombe **KO** au sol (ragdoll) pendant quelques secondes.
  Un adversaire peut l'**achever** (finisher animé) ; sinon il **se relève** avec peu de PV.
  Achevé → réapparition après **5 s** à un point d'apparition éloigné des ennemis.
- **Pas de régénération passive.** Un **kill (achèvement) rend +35 PV** (et soigne les blessures, voir §6.3).
- **Protection d'apparition** : 3 s d'invincibilité (annulée si le joueur attaque).

### 3.2 Duels 1v1 (best of 3)
1. Je clique sur le bouton **Duel** du menu → une fenêtre liste les joueurs du serveur → je clique
   **Challenge** à côté d'un nom. Il reçoit une fenêtre « *PlayerX challenges you to a duel!* »
   **Accept / Decline** (15 s).
2. S'il accepte : les deux sont téléportés dans une **arène de duel libre** (dans le même serveur,
   pas de changement de serveur). Le kit est verrouillé pendant le duel.
3. **Best of 3** : chaque manche démarre à PV/endurance pleins, compte à rebours « 3, 2, 1, FIGHT! ».
   Premier à 2 manches gagne.
4. Fin : retour à l'arène libre. Quitter le jeu ou un duel = **forfait** (défaite).
- Anti-spam : 1 défi toutes les 10 s, on ne peut pas défier quelqu'un déjà en duel ou en combat
  (touché il y a moins de 5 s). Option « Block duel requests » dans les paramètres.
- Si toutes les arènes de duel sont occupées : file d'attente, message « *Waiting for a free arena…* ».
- Les duels par **défi** sont **non classés** (évite qu'on « farme » ses amis).

### 3.3 Duels classés (Ranked)
- Bouton **Ranked** dans la fenêtre Duel → **matchmaking automatique** contre un joueur de niveau
  proche, même déroulement (best of 3).
- Classement **ELO** sauvegardé ; quitter un match Ranked = **défaite**.

## 4. Interface : peu de touches, des menus

Règle : **les touches servent seulement au combat**. Tout le reste passe par des **boutons à
l'écran** qui ouvrent une fenêtre (GUI). Une seule fenêtre ouverte à la fois, fermeture avec ✕
ou en cliquant le même bouton.

**Menu latéral** (boutons-icônes à gauche de l'écran, avec le nom au survol) :
| Bouton | Fenêtre |
|---|---|
| **Kits** | Cartes des kits (aperçu, attaques, verrouillé/débloqué) → bouton **Equip**. Changement hors combat seulement. |
| **Duel** | Liste des joueurs du serveur → **Challenge** ; défis reçus en attente |
| **Quests** | Les 3 quêtes du jour et leur progression |
| **Shop** | Boutique (étape 10) |
| **Settings** | 1ʳᵉ/3ᵉ personne, bloquer les défis de duel, sensibilité caméra, volume |

**HUD de combat** (bas de l'écran) : barres de vie et d'endurance, **barre des attaques** du kit
(4 cases avec icône, touche et cooldown — cliquables aussi), jauge d'ultime.

## 5. Combat

### 5.1 Contrôles (PC)
| Touche | Action |
|---|---|
| Clic gauche (M1) | Combo de **4 coups** (le 4ᵉ repousse l'adversaire) |
| F (maintenu) | **Bloquer** |
| F pile avant l'impact | **Parade** (perfect block) |
| Q | **Esquive** (dash dans la direction de déplacement) |
| 1, 2, 3, 4 | Attaques spéciales du kit |
| G (une fois la jauge pleine) | **Ultime** |
| Shift (maintenu) | Courir |
| C | **S'accroupir** / se relever |
| C pendant la course | **Glissade** (finit accroupi) |
| Espace face à un obstacle bas | **Vault** (on passe par-dessus sans perdre sa vitesse) |
| Espace face à un rebord haut | **Mantle** (attraper le rebord, se hisser dessus) |
| Ctrl | Libérer / verrouiller le curseur (pour cliquer les menus en 3ᵉ personne) |

> Ouvrir/fermer les menus : à la souris. En 3ᵉ personne le curseur est bloqué au centre (pour viser) :
> **Ctrl** le libère pour cliquer un bouton du menu ; une fenêtre ouverte le garde libre.

### 5.2 Règles de base
- **Vie** : 100 PV. **Endurance** : 100, se recharge après 1 s sans la dépenser.
- **Blocage** : réduit les dégâts de 80 %, consomme de l'endurance à chaque coup bloqué.
  Endurance à 0 → **garde brisée** (étourdi 1,5 s). On ne peut pas bloquer dans le dos.
- **Parade** : fenêtre de 0,2 s après l'appui sur F → l'attaquant est **étourdi 1 s**.
  Spammer F fait perdre la fenêtre de parade (pénalité).
- **Esquive** : coûte 25 d'endurance, cooldown 2 s, quelques frames d'invincibilité.
- **Courir** : consomme de l'endurance en continu. **Glissade** et **escalade** coûtent un peu
  d'endurance (cooldown court). Accroupi = plus lent.
- **Ultime = mode Awakening** (commun à tous les kits) : jauge remplie en **infligeant** des dégâts
  (un peu en en recevant). Pleine → **G** active l'**Awakening** pendant un temps limité : les
  4 attaques du kit sont **remplacées par des versions améliorées** propres au kit.
- **Étourdissement (stun)** : impossible d'attaquer/bloquer pendant la durée.

### 5.3 Sécurité (anti-triche)
- Le client joue l'animation tout de suite (réactivité) et envoie l'intention au serveur.
- Le serveur vérifie : cooldown, endurance, état (stun, mort, ragdoll), puis fait **lui-même** la
  détection de coup (hitbox devant le joueur, avec une petite tolérance pour la latence).
- Toutes les valeurs (dégâts, cooldowns) sont côté serveur. Le client ne peut rien imposer.

## 6. « Réaliste » : ce que ça veut dire ici

### 6.1 Graphismes
Éclairage `Future`, matériaux PBR, post-processing, ambiance ville (sons de fond, lampadaires).

### 6.2 Animations & impacts
- Coups lourds : **hitstop** (micro-pause de 0,05 s à l'impact), tremblement de caméra, son d'impact,
  recul de la victime.
- **Ragdoll** à la mort **et** sur certains gros coups (projection, 4ᵉ M1 chargé, ultime) pendant
  ~1,5 s, puis le personnage se relève.

### 6.3 Dégâts localisés & blessures (version « poussée »)
| Zone touchée | Effet |
|---|---|
| Tête | Dégâts **x1,25** + mini-étourdissement + flou de vision bref |
| Torse | Dégâts normaux |
| Jambes | Dégâts x0,85, chaque coup **ralentit** ; après 25 dégâts aux jambes → **boite** (vitesse -25 %) |

- **Saignement** : certains coups (bouteille, coups critiques) font saigner → perte de PV lente
  pendant quelques secondes. Effets de sang **légers** (particules, pas de gore détaillé).
- **Faible vie (< 25 PV)** : vision floue et assombrie sur les bords, battement de cœur, respiration.
- Les blessures restent jusqu'à la **mort** ou un **kill** (qui soigne).
- ⚠️ Règles Roblox : le sang demande de remplir le **questionnaire de maturité** de l'expérience
  (Creator Dashboard) honnêtement. Les effets resteront modérés pour garder un public large.

### 6.4 Endurance
Voir §5.2 : courir, esquiver et bloquer coûtent de l'endurance → pas de spam.

## 7. Kits au lancement
Système prévu pour ajouter facilement d'autres kits (un fichier de config par kit).
Noms visibles en jeu en anglais.

### Street Brawler (kit de base, gratuit)
Style sale et imprévisible, armes improvisées.
| Touche | Attaque (proposition) |
|---|---|
| 1 | **Bottle Smash** — coup de bouteille, fait **saigner** |
| 2 | **Headbutt** — courte portée, étourdit |
| 3 | **Tackle** — charge en avant, fait tomber (ragdoll) |
| 4 | **Dirty Kick** — coup bas qui ralentit |
| G | **Awakening « Street Fury »** — 10 s : dégâts +20 %, coups impossibles à interrompre, 4 attaques améliorées |

Street Fury remplace les 4 attaques : **Broken Bottle** (2 entailles, gros saignement), **Double
Headbutt** (attrape le col + 2 coups de tête), **Tackle Slam** (tackle + frappe au sol), **Kick
Combo** (tibia puis visage, projette). La jauge se remplit en frappant (et un peu en encaissant).
Les chiffres de chaque attaque sont dans `src/shared/Kits/StreetBrawler.luau`.

### Boxer (kit de base, gratuit)
Rapide, mobile, esquives, combos.
| Touche | Attaque (proposition) |
|---|---|
| 1 | **Jab Rush** — rafale de jabs rapides |
| 2 | **Uppercut** — projette en l'air |
| 3 | **Slip** — esquive latérale + contre automatique si un coup arrive |
| 4 | **Liver Shot** — coup au corps, réduit l'endurance adverse |
| G | **Awakening « Knockout Mode »** — 4 attaques améliorées, dont le **Knockout Combo** (combo cinématique, ragdoll) |

### Bouncer / Videur (niveau 5, 500 coins)
Videur de boîte de nuit : énorme et lent. Il ne fait pas d'échange de coups, il **saisit**.
Prend **15 % de dégâts en moins** et se déplace **10 % moins vite**. Ses saisies passent à travers
la garde et ne se parent pas ; un coup qui l'étourdit avant (frappe > saisie) ou une esquive les bat.
| Touche | Attaque |
|---|---|
| 1 | **Shove** — pousse à deux mains, repousse loin |
| 2 | **Chokehold** — étranglement par derrière (serre 3 fois, vide l'endurance) |
| 3 | **Body Slam** — un bras entre les jambes, le soulève en travers de sa poitrine et l'écrase sur le dos |
| 4 | **Hammer Fist** — les deux poings sur le haut du crâne |
| G | **Awakening « Last Call »** — 10 s, dégâts +20 % : **Throw Out** (le jette à travers la pièce), **Sleeper Hold** (étranglement plus long, il s'évanouit), **Powerbomb** (sur les épaules, puis écrasé, à genoux), **Double Hammer** |

Finisher cinématique : pied sur la poitrine, il **arrache le bras droit** à l'épaule, le regarde, le jette.
On peut ensuite **ramasser l'os** du bras (le vrai humérus de Z-Anatomy) et le **lancer** (clic gauche,
usage unique, `src/shared/Weapons.luau`) : il vole en arc et se casse en deux sur ce qu'il touche
(quelqu'un, un mur, le sol).
Les chiffres sont dans `src/shared/Kits/Bouncer.luau`, la saisie dans `src/server/Systems/Combat/Grab.luau`.

## 8. Progression & économie

### 8.1 Gains
| Action | Coins | XP |
|---|---|---|
| Kill | 10 | 25 |
| Assistance (≥ 20 dégâts infligés à la victime) | 4 | 10 |
| Victoire en duel | 50 | 100 |
| Défaite en duel (match terminé) | 10 | 25 |
| Quête quotidienne | 25–75 | 50–150 |

- Anti-farm : pas de récompense si on tue le **même joueur** plus de 3 fois en 5 min.
- **Niveaux** : XP nécessaire qui augmente à chaque niveau (formule dans la config).

### 8.2 Quêtes quotidiennes
3 quêtes par jour (renouvelées à minuit UTC), tirées au hasard. Ex. : *Get 10 kills*,
*Win 2 duels*, *Land 5 perfect blocks*, *Deal 1000 damage with Street Brawler*.

### 8.3 Déblocage des kits
- **Kits de base** (Street Brawler, Boxer) : disponibles dès le départ pour tout le monde.
- Les futurs kits se débloqueront soit avec le **niveau**, soit avec des **coins**.
- Les kits « coins » sont aussi achetables en **Robux** (Developer Product / Game Pass).

### 8.4 Boutique (plus tard)
- **Cosmétiques** (coins et/ou Robux) : skins de kit, effets de kill, émotes, titres.
- Aucun avantage de combat vendu en Robux **à part les kits eux-mêmes**.

## 9. Données sauvegardées (évolution prévue)
Déjà : `coins`, `stats.kills/deaths/wins/matchesPlayed`. À ajouter (via migration) :
- `xp`, `level`
- `ownedKits` (liste), `equippedKit`
- `stats.duelWins`, `stats.duelLosses`, `stats.assists`
- `dailyQuests` (quêtes du jour + progression + date)
- `settings` (`firstPerson`, `blockDuelRequests`)

## 10. Animations & sons
- **Animations** : faites **en code** (pas d'Animation Editor), vérifiées dans un aperçu du rig R6.
  Détails : `docs/ANIMATIONS_FR.md`.
- **Sons** : choisis par le propriétaire du jeu, IDs dans `src/shared/Sounds.luau`.
  Guide : `docs/SOUNDS_FR.md`.

## 11. Feuille de route
Chaque étape = une branche, testée dans Studio avant de passer à la suivante.

1. ✅ **Base personnage** : R6, caméra 3ᵉ personne épaule, course + endurance, HUD vie/endurance,
   menu latéral (squelette) + fenêtre Settings (1ʳᵉ/3ᵉ personne).
1 bis. ✅ **Mouvements** : accroupi, glissade, vault, mantle (+ animations en code).
2. ✅ **Combat de base** : M1 (4 coups), blocage, parade, esquive, stun, hitbox serveur,
   animations de combat en code, sons.
3. ✅ **Dégâts & mort** : dégâts localisés, ragdoll, **KO + finisher**, réapparition, kill feed, kill = +35 PV.
4. ✅ **Système de kits** + **Street Brawler** (4 attaques + Awakening « Street Fury »), saignement
   simple, fenêtre **Kits**.
5. ✅ **Blessures** : saignement, boiterie, marques, effets faible vie, petite régénération.
6. ✅ **Boxer** (Jab Rush, Uppercut, Slip, Liver Shot + Knockout Mode avec le Knockout Combo), gratuit.
7. ✅ **Progression** : XP (kill, finisher, assist, dégâts, temps de jeu), niveaux 1–100, coins, profil, nom + niveau au-dessus des têtes, classement Tab, déblocage des futurs kits (niveau + coins).
8. ✅ **Duels** : défi (non classé), arènes, best of 3, récompenses, puis **Ranked** (matchmaking + ELO 1000, rangs Bronze → Diamond).
9. ✅ **Quêtes quotidiennes**.
10. **Boutique** : titres, tenues, effets de kill, émotes (coins). Robux plus tard. ← en cours
11. **Polish** : map finale, sons, VFX, équilibrage, optimisation, tests à 16 joueurs.

**À faire plus tard (idées validées) :**
- **Émotes spéciales** : les émotes de la boutique ne sont pas complètes pour l'instant, on les
  refera (émotes avec objet / effet).
- **Émote « serpillière » (mop)** : le perso sort une serpillière et nettoie ; elle peut effacer
  le sang au sol, voire les morceaux (crânes, etc.) laissés par les finishers.
- **Murs cassables** : les panneaux du rez-de-chaussée de la ville sont déjà tagués `Breakable`
  pour de futurs persos qui envoient l'adversaire à travers un mur.

## 12. Questions encore ouvertes
- Nom/visuel des cosmétiques et prix exacts (étape 10).
- ~~KO : durée au sol, touche du finisher, PV au relevé~~ → **6 s au sol, achever = clic gauche
  sur le joueur KO, relevé à 25 PV** (étape 3).
- **Zones** : on vise avec le centre de l'écran (tête / torse) ; le serveur vérifie que la partie
  visée est bien dans la hitbox. Les coups de poing touchent tête ou torse ; les jambes viendront
  avec les coups de pied (kits, étape 4).
- Awakening : durée, et les 4 attaques améliorées de chaque kit (étapes 4 et 6).
- Ranked : ELO de départ, gains/pertes, récompenses de saison (étape 8).
