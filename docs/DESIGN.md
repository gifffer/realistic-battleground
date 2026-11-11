# Realistic Battleground — résumé du projet

> À coller au début d'un nouveau chat pour reprendre le projet.

## Équipe & méthode
- Niveau : débutant / intermédiaire → code commenté et expliqué. On discute en français.
- Repo GitHub : **https://github.com/gifffer/realistic-battleground** (branche `main`).
- Workflow : **Rojo** (fichiers `.luau` dans le repo, synchronisés dans Roblox Studio). Guide : `docs/SETUP_FR.md`.
- Structure : `src/shared` (ReplicatedStorage.Shared), `src/server` (ServerScriptService.Server),
  `src/client` (StarterPlayerScripts.Client). Luau `--!strict`, bootstrap init()/start(),
  serveur autoritaire (on ne fait jamais confiance au client).
- Exigence : **qualité avant vitesse**.

## Déjà en place
- Structure Rojo + Wally + StyLua + Selene + CI GitHub.
- Sauvegarde des joueurs avec **ProfileStore** (session locking, autosave, migrations) :
  `src/server/Systems/PlayerData/`. Données actuelles : `coins`, `stats` (kills, deaths, wins, matchesPlayed).

## À décider
- Le concept : type de combat (armes à feu ? corps à corps / pouvoirs façon « battlegrounds » ?),
  vue (1ʳᵉ / 3ᵉ personne), modes de jeu, nombre de joueurs par serveur.
- Ce que « Realistic » veut dire ici (graphismes, physique, dégâts, mouvements).
- Monnaie(s), boutique, progression.
