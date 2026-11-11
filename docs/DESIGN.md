# Realistic Battleground — document de design

> À coller au début d'un nouveau chat pour reprendre le projet.
> Les chiffres (vitesses, dégâts, durées) vivent dans `src/shared/Config.luau`, pas ici.

## Équipe & méthode
- Niveau : débutant / intermédiaire → code commenté et expliqué. On discute en français,
  **tout le texte affiché dans le jeu est en anglais**.
- Repo GitHub : **https://github.com/gifffer/realistic-battleground** (branche `main`).
- Workflow : **Rojo** (fichiers `.luau` dans le repo, synchronisés dans Roblox Studio). Guide : `docs/SETUP_FR.md`.
  On ne modifie jamais les scripts synchronisés directement dans Studio.
- Structure : `src/shared` (ReplicatedStorage.Shared), `src/server` (ServerScriptService.Server),
  `src/client` (StarterPlayerScripts.Client). Luau `--!strict`, bootstrap init()/start(),
  serveur autoritaire (on ne fait jamais confiance au client).
- Git : une branche par fonctionnalité, jamais de push direct sur `main`.
- Exigence : **qualité avant vitesse**.

## Concept
Jeu de combat « battlegrounds » **réaliste** : pas de pouvoirs magiques, des styles de combat
réels (bagarre de rue, boxe…). Chaque personnage a un **kit** : combo M1, 4 attaques spéciales
et un **mode Awakening** (ultime).

## Ce que « Realistic » veut dire
- **Animations / mouvements** : coups lourds, inertie, ragdoll quand on est sonné / KO.
- **Graphismes** : éclairage Future, post-process, matériaux PBR, map urbaine détaillée.
- **Dégâts localisés** : tête = plus de dégâts + étourdissement, jambes = ralentissement.
- **Endurance (stamina)** : sprint, dash, blocage et coups consomment de la stamina.

## Personnages (sortie)
| Perso | Style | Déblocage |
|---|---|---|
| **Street Brawler** (Bagarreur de rue) | Coups sales, armes improvisées | Gratuit |
| **Boxer** (Boxeur) | Jab, crochet, uppercut, esquives du buste | Niveau ou coins |

- Animations faites par nous dans l'Animation Editor de Studio (avatar **R15**).
- Les objets ramassables (bouteille, barre de fer…) sont sur la map et **utilisables par tout le monde**.

## Mécaniques de combat communes
- **Combo M1** (clic gauche, 4 coups) + **blocage** (F).
- **Parade** (perfect block) : bloquer pile au bon moment étourdit l'attaquant.
- **Dash / esquive** (Q) avec cooldown.
- **Guard break** : bloquer trop longtemps casse la garde.
- **Ultime** : une barre se remplit en donnant / prenant des coups ; à 100 % on active
  l'**Awakening** (mode temporaire qui change les 4 attaques).
- Hitbox et dégâts **calculés par le serveur**.

## Mouvements & caméra
- **Sprint** : maintenir Shift, consomme la stamina.
- **Accroupi** (C), **glissade** (accroupi pendant un sprint), **escalade de rebord**.
- **Caméra 1re / 3e personne** : la molette (zoom à fond = 1re personne).
- **3e personne épaule**, **shift-lock au choix** (touche pour activer / désactiver).

## Modes de jeu (16 joueurs par serveur)
- **Arène libre (FFA)** en continu.
  - À 0 PV : **KO** au sol quelques secondes → l'adversaire peut **achever** (finisher animé),
    sinon on se relève.
  - **Regen sur kill** : achever quelqu'un rend de la vie (pas de regen passive).
- **Duels 1v1** dans une arène séparée, best-of-3 :
  - **Ranked** : bouton → matchmaking automatique, classement **ELO**.
  - **Défi** : on cible un joueur, il accepte. **Non classé** (évite le farm entre amis).
- **Anti-fuite** : quitter en plein combat = mort + kill pour le dernier attaquant
  (en Ranked = défaite).

## Map
Quartier urbain : ruelles, parking, entrepôt ouvert. Objets ramassables dispersés.

## Plateformes
**PC d'abord.** Les entrées passent par ContextActionService pour ajouter mobile / manette plus tard.

## Progression & économie
- **XP / niveau** : certains persos se débloquent à un niveau.
- **Coins** gagnés en jouant (kills, duels gagnés) : certains persos s'achètent avec des coins
  (Robux possibles en raccourci).
- **Boutique** (cosmétique uniquement, jamais de pay-to-win) : skins de persos,
  effets de coups / KO, émotes, serveur privé.

## Déjà en place
- Structure Rojo + Wally + StyLua + Selene + CI GitHub.
- Sauvegarde des joueurs avec **ProfileStore** (session locking, autosave, migrations) :
  `src/server/Systems/PlayerData/`. Données actuelles : `coins`, `stats` (kills, deaths, wins, matchesPlayed).

## Feuille de route
1. Caméra 1re / 3e personne + mouvements (sprint, stamina, accroupi). ← en cours
2. Glissade + escalade de rebord.
3. Noyau de combat : M1, blocage, parade, dash, dégâts localisés, KO / finisher.
4. Street Brawler (kit complet) + objets ramassables.
5. HUD (vie, stamina, ultime), sélection de perso.
6. Boxer.
7. Duels (défi puis Ranked / ELO).
8. XP / niveaux, coins, boutique.
9. Map urbaine, graphismes.
