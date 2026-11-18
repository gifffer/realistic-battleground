# Ajouter les sons

Tous les sons sont listés dans **`src/shared/Sounds.luau`**. Chaque son a une **liste** d'IDs
(`ids`) : le jeu en tire un au hasard à chaque fois (jamais deux fois le même de suite), pour qu'un
combat ne sonne pas comme une boucle. Tant qu'une liste est vide (`{}`), le jeu ne joue rien pour ce
son (ou son son de secours `fallback`) : tu peux les remplir dans l'ordre que tu veux.

Déjà remplis : `Swing` (3 sons) et `Hit` (3 sons). `HeavySwing` et `HeavyHit` (le finisher)
réutilisent ces sons en plus **grave** et plus **fort** tant qu'ils n'ont pas les leurs.

## 1. Trouver un son
- **Creator Store** (dans Studio : *Toolbox* → onglet *Audio*, ou sur create.roblox.com) :
  cherche par exemple `punch`, `whoosh`, `block`, `slide`.
- Ou **importe ton propre fichier** (.mp3 / .ogg) : *Creator Hub → Creations → Audio → Upload*.
  Roblox vérifie le fichier (quelques minutes).

> Le son doit être **public** (Creator Store) ou t'appartenir, sinon il ne se joue pas en jeu.

## 2. Récupérer son ID
Clic droit sur le son → *Copy Asset ID*. Tu obtiens un nombre (ex. `1234567890`).

## 3. Le mettre dans le jeu
Dans VS Code, ouvre `src/shared/Sounds.luau` et ajoute le nombre dans la liste `ids`
(un seul, ou plusieurs séparés par des virgules pour avoir des variantes) :

```lua
Block = { ids = { 1234567890, 2345678901 }, volume = 0.6, pitch = 1, pitchVariation = 0.1 },
```

- `volume` : de 0 à 1.
- `pitch` : 1 = normal ; 0.8 = plus grave et plus lourd ; 1.2 = plus aigu.
- `pitchVariation` : chaque fois, le son est un peu plus aigu ou grave au hasard (0.1 = ±10 %),
  pour qu'un même coup ne sonne jamais exactement pareil.

Rojo synchronise, *Play*.

## Les sons et quand ils jouent
| Nom | Quand |
|---|---|
| `Swing` | Coups M1 1 à 3 (souffle du poing) |
| `HeavySwing` | Coup M1 4 (le finisher) |
| `Hit` | Un coup touche |
| `HeavyHit` | Le finisher touche |
| `Block` | Un coup tape dans la garde |
| `Parry` | Parade réussie |
| `GuardBreak` | Garde brisée |
| `Dash` | Esquive (Q) |
| `Dodge` | Un coup esquivé pendant le dash |
| `Slide` | Début d'une glissade |
| `Vault` | Passage par-dessus un obstacle bas |
| `Mantle` | Attraper un rebord |
| `BloodDrip` | Une goutte de sang qui tombe d'un blessé (doux, discret) |
| `BloodSplat` | Une giclée de sang sur un coup lourd qui saigne |
| `ArterialSpurt` | Chaque jet d'une artère coupée (finishers) |
| `BloodGurgle` | Le sang dans la gorge ouverte (finisher de la batte) |

Les sons sont joués **en 3D** sur le personnage : on les entend plus fort de près, et du bon côté.
Ils sont tous téléchargés au lancement du jeu, pour que le premier coup ne soit pas muet.

> Si un son ne joue pas : ouvre l'Output dans Studio. Un message `Failed to load sound` veut dire
> que le son est privé ou supprimé — il faut qu'il soit public ou qu'il appartienne à ton compte.
