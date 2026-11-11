# Realistic Battleground

Roblox game, built with [Rojo](https://rojo.space).

- Setup guide (FR): [docs/SETUP_FR.md](docs/SETUP_FR.md)
- Game design (FR): [docs/DESIGN.md](docs/DESIGN.md)

## Development

1. Install the toolchain: `rokit install`
2. Install packages: `wally install` (creates `ServerPackages/`, not committed)
3. Start syncing: `rojo serve`
4. In Roblox Studio, connect with the Rojo plugin.

## Structure

- `src/shared` → ReplicatedStorage/Shared — types, config, remotes, pure utilities
- `src/server` → ServerScriptService/Server — authoritative game systems (`Systems/*`, each with `init()` / `start()`)
- `src/client` → StarterPlayerScripts/Client — rendering, input, UI (`Controllers/*`)

## Checks

- Format: `stylua src`
- Lint: `selene src`
