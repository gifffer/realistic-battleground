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
| Avatars | **R15 forcé** (nécessaire pour ragdoll, dégâts localisés, animations) |
| Caméra | **3ᵉ personne épaule par défaut**, touche **V** pour passer en 1ʳᵉ personne (choix sauvegardé) |
| Map | **Quartier urbain** (ruelles, parking, entrepôt ouvert) + **arène(s) de duel** à l'écart |
| Éclairage | `Future`, post-processing (Bloom, ColorCorrection, DepthOfField léger, Atmosphere) |

## 3. Modes de jeu

### 3.1 Arène libre (mode principal)
- Tout le monde se bat en continu dans le quartier. À la mort → ragdoll → réapparition après **5 s**
  à un point d'apparition éloigné des ennemis.
- **Pas de régénération passive.** Un **kill rend +35 PV** (et soigne les blessures, voir §5.3).
- **Protection d'apparition** : 3 s d'invincibilité (annulée si le joueur attaque).

### 3.2 Duels 1v1 (best of 3)
1. Dans l'arène, je vise un joueur (curseur dessus, à moins de 30 studs) et j'appuie sur **H**
   → il reçoit une fenêtre « *PlayerX challenges you to a duel!* » **Accept / Decline** (15 s).
2. S'il accepte : les deux sont téléportés dans une **arène de duel libre** (dans le même serveur,
   pas de changement de serveur). Le kit est verrouillé pendant le duel.
3. **Best of 3** : chaque manche démarre à PV/endurance pleins, compte à rebours « 3, 2, 1, FIGHT! ».
   Premier à 2 manches gagne.
4. Fin : retour à l'arène libre. Quitter le jeu ou un duel = **forfait** (défaite).
- Anti-spam : 1 défi toutes les 10 s, on ne peut pas défier quelqu'un déjà en duel ou en combat
  (touché il y a moins de 5 s). Option « Block duel requests » dans les paramètres.
- Si toutes les arènes de duel sont occupées : file d'attente, message « *Waiting for a free arena…* ».

## 4. Combat

### 4.1 Contrôles (PC)
| Touche | Action |
|---|---|
| Clic gauche (M1) | Combo de **4 coups** (le 4ᵉ repousse l'adversaire) |
| F (maintenu) | **Bloquer** |
| F pile avant l'impact | **Parade** (perfect block) |
| Q | **Esquive** (dash dans la direction de déplacement) |
| 1, 2, 3, 4 | Attaques spéciales du kit |
| G (une fois la jauge pleine) | **Ultime** |
| Shift | Courir |
| V | Basculer 1ʳᵉ / 3ᵉ personne |
| H (en visant un joueur, hors combat) | Défier en duel |

> Le défi n'est possible que hors combat (pas touché depuis 5 s) et en visant un joueur.

### 4.2 Règles de base
- **Vie** : 100 PV. **Endurance** : 100, se recharge après 1 s sans la dépenser.
- **Blocage** : réduit les dégâts de 80 %, consomme de l'endurance à chaque coup bloqué.
  Endurance à 0 → **garde brisée** (étourdi 1,5 s). On ne peut pas bloquer dans le dos.
- **Parade** : fenêtre de 0,2 s après l'appui sur F → l'attaquant est **étourdi 1 s**.
  Spammer F fait perdre la fenêtre de parade (pénalité).
- **Esquive** : coûte 25 d'endurance, cooldown 2 s, quelques frames d'invincibilité.
- **Courir** : consomme de l'endurance en continu.
- **Ultime** : jauge remplie en **infligeant** des dégâts (un peu en en recevant). Pleine = attaque
  ou mode spécial propre au kit.
- **Étourdissement (stun)** : impossible d'attaquer/bloquer pendant la durée.

### 4.3 Sécurité (anti-triche)
- Le client joue l'animation tout de suite (réactivité) et envoie l'intention au serveur.
- Le serveur vérifie : cooldown, endurance, état (stun, mort, ragdoll), puis fait **lui-même** la
  détection de coup (hitbox devant le joueur, avec une petite tolérance pour la latence).
- Toutes les valeurs (dégâts, cooldowns) sont côté serveur. Le client ne peut rien imposer.

## 5. « Réaliste » : ce que ça veut dire ici

### 5.1 Graphismes
Éclairage `Future`, matériaux PBR, post-processing, ambiance ville (sons de fond, lampadaires).

### 5.2 Animations & impacts
- Coups lourds : **hitstop** (micro-pause de 0,05 s à l'impact), tremblement de caméra, son d'impact,
  recul de la victime.
- **Ragdoll** à la mort **et** sur certains gros coups (projection, 4ᵉ M1 chargé, ultime) pendant
  ~1,5 s, puis le personnage se relève.

### 5.3 Dégâts localisés & blessures (version « poussée »)
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

### 5.4 Endurance
Voir §4.2 : courir, esquiver et bloquer coûtent de l'endurance → pas de spam.

## 6. Kits au lancement
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
| G | **Ultime « Street Fury »** — 10 s : dégâts +20 %, coups impossibles à interrompre |

### Boxer (kit de base, gratuit)
Rapide, mobile, esquives, combos.
| Touche | Attaque (proposition) |
|---|---|
| 1 | **Jab Rush** — rafale de jabs rapides |
| 2 | **Uppercut** — projette en l'air |
| 3 | **Slip** — esquive latérale + contre automatique si un coup arrive |
| 4 | **Liver Shot** — coup au corps, réduit l'endurance adverse |
| G | **Ultime « Knockout Combo »** — combo cinématique, fait tomber en ragdoll |

## 7. Progression & économie

### 7.1 Gains
| Action | Coins | XP |
|---|---|---|
| Kill | 10 | 25 |
| Assistance (≥ 20 dégâts infligés à la victime) | 4 | 10 |
| Victoire en duel | 50 | 100 |
| Défaite en duel (match terminé) | 10 | 25 |
| Quête quotidienne | 25–75 | 50–150 |

- Anti-farm : pas de récompense si on tue le **même joueur** plus de 3 fois en 5 min.
- **Niveaux** : XP nécessaire qui augmente à chaque niveau (formule dans la config).

### 7.2 Quêtes quotidiennes
3 quêtes par jour (renouvelées à minuit UTC), tirées au hasard. Ex. : *Get 10 kills*,
*Win 2 duels*, *Land 5 perfect blocks*, *Deal 1000 damage with Street Brawler*.

### 7.3 Déblocage des kits
- **Kits de base** (Street Brawler, Boxer) : disponibles dès le départ pour tout le monde.
- Les futurs kits se débloqueront soit avec le **niveau**, soit avec des **coins**.
- Les kits « coins » sont aussi achetables en **Robux** (Developer Product / Game Pass).

### 7.4 Boutique (plus tard)
- **Cosmétiques** (coins et/ou Robux) : skins de kit, effets de kill, émotes, titres.
- Aucun avantage de combat vendu en Robux **à part les kits eux-mêmes**.

## 8. Données sauvegardées (évolution prévue)
Déjà : `coins`, `stats.kills/deaths/wins/matchesPlayed`. À ajouter (via migration) :
- `xp`, `level`
- `ownedKits` (liste), `equippedKit`
- `stats.duelWins`, `stats.duelLosses`, `stats.assists`
- `dailyQuests` (quêtes du jour + progression + date)
- `settings` (`firstPerson`, `blockDuelRequests`)

## 9. Animations
Faites par le propriétaire du jeu dans Studio et publiées sur **son compte perso**.
Étapes détaillées : `docs/ANIMATIONS_FR.md`.

## 10. Feuille de route
Chaque étape = une branche, testée dans Studio avant de passer à la suivante.

1. **Base personnage** : R15 forcé, caméra 3ᵉ/1ʳᵉ personne (V), course + endurance, HUD vie/endurance.
2. **Combat de base** : M1 (4 coups), blocage, parade, esquive, stun, hitbox serveur.
3. **Dégâts & mort** : dégâts localisés, ragdoll, mort/réapparition, kill feed, kill = +35 PV.
4. **Système de kits** + **Street Brawler** (4 attaques + ultime).
5. **Blessures** : saignement, boiterie, effets faible vie.
6. **Boxer** + écran de sélection de kit (les deux kits de base).
7. **Progression** : XP, niveaux, coins sur kill/assist (déblocage des futurs kits).
8. **Duels** : défi, arènes, best of 3, récompenses.
9. **Quêtes quotidiennes**.
10. **Boutique** : cosmétiques, achats Robux.
11. **Polish** : map finale, sons, VFX, équilibrage, optimisation, tests à 16 joueurs.

## 11. Questions encore ouvertes
- Nom/visuel des cosmétiques et prix exacts (étape 10).
