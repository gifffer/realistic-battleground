# Installer et utiliser Rojo (guide débutant)

Rojo fait le lien entre les fichiers `.luau` du projet (sur ton PC) et Roblox Studio.
Tu modifies un fichier → il se met à jour tout seul dans Studio.

## 1. Installer les outils (une seule fois)

1. Installe **Git** : https://git-scm.com/downloads
2. Installe **Rokit** (gestionnaire d'outils Roblox) : https://github.com/rojo-rbx/rokit
   - Windows (PowerShell) :
     ```powershell
     Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
     ```
   - Ferme et rouvre ton terminal après l'installation.
3. Installe **VS Code** : https://code.visualstudio.com
   - Extensions recommandées : **Luau Language Server** (JohnnyMorganz), **Selene**, **StyLua**.
4. Installe le **plugin Rojo dans Roblox Studio** :
   Studio → onglet *Plugins* → *Manage Plugins* / Creator Store → cherche **Rojo** (par *rojo-rbx*).

## 2. Récupérer le projet

```bash
git clone <URL_DU_REPO_GITHUB>
cd realistic-battleground
rokit install
```

`rokit install` télécharge les bonnes versions de rojo / wally / selene / stylua (listées dans `rokit.toml`).

Ensuite, installe les **paquets** (bibliothèques externes, listées dans `wally.toml`) :

```bash
wally install
```

Ça crée le dossier `ServerPackages/` (ProfileStore, la bibliothèque de sauvegarde).
Ce dossier n'est **pas** dans Git (il est dans `.gitignore`) : chaque membre de l'équipe
lance `wally install` une fois, puis à nouveau quand `wally.toml` change.
Sans lui, `rojo serve` affiche une erreur « ServerPackages » introuvable.

## 2 bis. Réglages de la place dans Studio (une seule fois)

*Home* → **Game Settings** → **Security** (la place doit être publiée : *File → Publish to Roblox*) :

- **Enable Studio Access to API Services** : ON → les sauvegardes marchent aussi pendant les tests dans Studio.
  Si c'est OFF, le jeu marche quand même mais rien n'est sauvegardé (message dans l'Output).

### Avatar R6 (obligatoire)
Le jeu est fait pour des personnages **R6**. Ce réglage appartient à la place (pas au code) :

- Onglet *Avatar* → **Avatar Settings** → *Body* (ou *Rig*) → **Avatar Type : R6**
  (sur les anciennes versions de Studio : *Home* → *Game Settings* → *Avatar* → **R6**).
- Puis *File → Publish to Roblox* pour l'enregistrer.

Si c'est oublié, l'Output affiche : `[Characters] Avatars are not R6...`


## 3. Travailler au quotidien

1. Dans le dossier du projet :
   ```bash
   rojo serve
   ```
   Laisse ce terminal ouvert.
2. Ouvre Roblox Studio → ta place (ou une Baseplate vide).
3. Onglet *Plugins* → **Rojo** → **Connect**.
4. Le code apparaît dans :
   - `ReplicatedStorage > Shared`
   - `ServerScriptService > Server`
   - `StarterPlayer > StarterPlayerScripts > Client`
5. Clique **Play** pour tester.

> ⚠️ Les dossiers synchronisés par Rojo sont écrasés par les fichiers. Ne modifie pas
> ces scripts directement dans Studio : modifie les fichiers `.luau`.
> Les **maps, modèles, images** (ce que tu construis à la main dans Studio) restent dans Studio,
> sauvegarde ta place normalement (File → Publish to Roblox).

## 4. Récupérer les nouvelles versions du code

```bash
git pull
```
Rojo met Studio à jour automatiquement si `rojo serve` tourne.

> Si `default.project.json` a changé (il apparaît dans la liste des fichiers modifiés du commit),
> **arrête `rojo serve` (Ctrl+C) et relance-le**, puis reconnecte le plugin : sinon certains
> réglages ne sont pas appliqués dans Studio.

## 5. Ajouter les images (sprites)

1. Dans Studio : *Asset Manager* (ou Creator Hub) → *Import* → ton image `.png`.
2. Clic droit → *Copy Asset ID* → tu obtiens `rbxassetid://123456789`.
3. Colle cet ID dans le fichier de config indiqué (ex. `src/shared/Assets.luau`, créé plus tard).
