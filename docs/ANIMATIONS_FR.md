# Créer et brancher une animation

Le code joue les animations listées dans `src/shared/Animations.luau`.
Tant qu'un ID est vide (`""`), le jeu l'ignore simplement (les animations Roblox par défaut jouent).

## 1. Créer l'animation
1. Studio → onglet *Avatar* → **Rig Builder** → *Block Rig* **R15** (le jeu est en R15).
2. Sélectionne le rig → onglet *Avatar* → **Animation Editor**, donne un nom.
3. Anime. Pour une boucle (sprint, accroupi) : la dernière pose = la première.
4. Dans l'éditeur, menu `...` :
   - **Looping** : ON pour les boucles.
   - **Set Animation Priority** : celle indiquée dans le commentaire de `Animations.luau`
     (ex. `Movement`).
5. Menu `...` → **Publish to Roblox**. Copie l'ID (`rbxassetid://123456789`).

> Publie l'animation sur **le même compte / groupe** que le jeu, sinon Roblox refuse de la jouer.

## 2. La brancher
Colle l'ID dans `src/shared/Animations.luau` (dans VS Code, pas dans Studio) :

```lua
SPRINT = "rbxassetid://123456789",
```

Rojo synchronise, relance le test (Play).

## Animations à faire (mouvements)
| Nom | Boucle | Priorité | Quand |
|---|---|---|---|
| `SPRINT` | oui | Movement | Shift maintenu + on avance |
| `CROUCH_IDLE` | oui | Movement | Accroupi, immobile |
| `CROUCH_WALK` | oui | Movement | Accroupi, en marchant |

Conseil réalisme : un sprint avec le buste légèrement penché en avant, des bras qui balancent fort ;
un accroupi « garde haute » (poings devant le visage), ça colle au thème combat.
