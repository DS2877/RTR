# Rob the Rich! – rules for every session

Roblox game built entirely from this repo (Rojo + Luau). Steal-and-run genre: train speed on your
treadmill, steal loot from rich NPC vaults along Rich Street, run it home past the guards, and earn income from
it on your plot. **Twist: 👑 THE RICHEST.** The richest player on the server wears a crown, gets a gold sky beam
and the WANTED board, and earns +50%, but can never lock their base, and robbing them pays a bounty.

## Project facts
- Repo: `ds2877/rtr` only. Never touch other repos (SAT, DS2877, DAT, CM belong to other projects).
- Universe `10770392871`, start place `95313582510402`.
- Push to `main` = publish (GitHub Actions, secret `RTR_PUBLISHING_KEY`). Other branches run checks only.
- In-game text is English. STATUS.md is written in Swedish for Philip.
- Philip tests mostly on iPhone: mobile first, big buttons, nothing needs hover or keyboard.

## Build rules
1. Never write the publishing key anywhere; read it only from the Actions secret.
2. Everything is code: world, bases, vaults, guards, items and UI are built at runtime. Nothing manual in Studio.
3. Server decides everything that touches the economy. Clients send intents only. Validate + rate-limit every remote.
4. Every balance number lives in `src/shared/Config/*`. Re-run `lune run tools/simulate` after balance changes.
5. Monetization follows Roblox rules: known contents for everything bought with Robux, no random paid rewards.
6. `--!strict` in every file. StyLua + Selene + Lune tests must pass (CI runs them before publishing).
7. After every change: update STATUS.md (done / how to test / missing).

## Layout
- `src/shared` → ReplicatedStorage.Shared: Config (Vaults, Rarity, Mutations, Economy, World, Products, Assets, Admin), Progression (pure balance math, Lune-tested), Format, Remotes.
- `src/server` → ServerScriptService.Server: State (runtime per player), Net, Services (WorldBuilder, Data, Wallet, Movement, Bases, Carry, Vaults, Guards, Treadmill, Richest, Fuse, Product, Admin), Util (ItemModel, RateLimit).
- `src/client` → StarterPlayerScripts.Client: Controllers (HUD, CarryFX, WorldFX, Panels), Util (UI, Panel, Sound).

## Local checks
```
./tools/install-tools.sh        # or: rokit install
stylua --check src && selene src && lune run tests && rojo build default.project.json -o rtr.rbxl
```
