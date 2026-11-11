# Ajouter les sons

Tous les sons sont listés dans **`src/shared/Sounds.luau`**. Tant qu'un `id` vaut `0`, le jeu ne
joue simplement rien pour ce son : tu peux les remplir dans l'ordre que tu veux.

## 1. Trouver un son
- **Creator Store** (dans Studio : *Toolbox* → onglet *Audio*, ou sur create.roblox.com) :
  cherche par exemple `punch`, `whoosh`, `block`, `slide`.
- Ou **importe ton propre fichier** (.mp3 / .ogg) : *Creator Hub → Creations → Audio → Upload*.
  Roblox vérifie le fichier (quelques minutes).

> Le son doit être **public** (Creator Store) ou t'appartenir, sinon il ne se joue pas en jeu.

## 2. Récupérer son ID
Clic droit sur le son → *Copy Asset ID*. Tu obtiens un nombre (ex. `1234567890`).

## 3. Le mettre dans le jeu
Dans VS Code, ouvre `src/shared/Sounds.luau` et remplace le `0` :

```lua
Hit = { id = 1234567890, volume = 0.7, pitchVariation = 0.1 },
```

- `volume` : de 0 à 1.
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

Les sons sont joués **en 3D** sur le personnage : on les entend plus fort de près, et du bon côté.
