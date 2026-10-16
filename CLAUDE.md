# Dig Out! – rules for every session

Roblox prison-escape digging game built entirely from this repo (Rojo + Luau). You're a prisoner:
punch through the back wall of your cell, dig a tunnel through material zones that get harder and
harder, find valuables, smuggle out rubble and loot, upgrade in the Common Room, and finally escape
(rebirth). Core loop: punch -> vacuum rubble + finds -> backpack full -> Yard dump / The Fence ->
upgrade -> punch harder -> new zone. The punch and the crumble must feel amazing: juice is a feature.

## Project facts
- Repo: `ds2877/rtr` only. Never touch other repos (SAT, DS2877, DAT, CM belong to other projects).
- Universe `10770392871`, start place `95313582510402`. One server = 12 players (one per cell).
- Push to `main` = publish (`.github/workflows/deploy.yml`, secret `RTR_PUBLISHING_KEY`). Other
  branches run checks only. Never write the key anywhere; read it only from the Actions secret.
- Creator Hub changes (passes, products, name, Max Players) go through `.github/workflows/ops.yml`
  (push a branch named `ops/*`), script `tools/ops/roblox_setup.py`.
- In-game text is English. STATUS.md is written in Swedish for Philip.
- The old game (Rob the Rich!) is archived at tag `archive/rob-the-rich`. Player data lives in the
  ProfileStore `DigOut_v1` (schema `Version` + migrations in `Services/Data.luau`).

## Build rules
1. Everything is code: world, cells, tunnels, NPCs, items and UI are built at runtime. Nothing manual in Studio.
2. The server decides everything touching economy or progress. Clients send intents only. Validate and
   rate-limit every remote.
3. Every balance number lives in `src/shared/Config/*`. Pure balance math lives in shared modules with Lune
   tests. `lune run tools/simulate` prints time-to-each-zone for a free player and for a player with
   passes (`lune run tools/simulate all` = long-term pacing with every zone open, targets: escape
   <= 2:30 free, <= 15 average hits/block per zone). `lune run tools/tune write` re-solves zone hp
   against the pacing targets in `tools/tune.luau` (model in `tools/simcore.luau`). Re-run after
   balance changes.
4. Monetization follows Roblox rules: known contents for everything bought with Robux, no paid randomness.
5. `--!strict` everywhere. StyLua + Selene + Lune tests must pass (CI runs them before publishing).
6. After every change: update STATUS.md in Swedish (klart / hur du testar på iPhone / saknas).
7. Mobile first: big thumb buttons in the lower half, nothing needs hover or keyboard. Must run smoothly on
   an iPhone 11: at most ~3000 voxel parts and 150 debris cubes per client, 50+ fps.
8. Admin commands (admins only) for phone testing: ADMIN button in the HUD (and `!cmd` in chat): give
   Noodles, set strength, jump to zone N, force day/night, reset my tunnel, stress dig, guard
   inspection, events.

## Digging tech (read before touching Dig / VoxelRender)
- Grid per cell: 18 x 12 x 600 blocks of 2 studs (`Config/World`). z = 0 is the cell's back wall,
  z grows deeper. `Shared/Tunnel` converts blocks <-> world (frame = bottom-center of the back wall,
  local -Z = deeper). Rows face opposite directions, so tunnels never meet.
- `Shared/Voxel`: dug bits as per-chunk (8x8x8) bitsets, saved as RLE + base64 in the profile.
  Damage (hp left) is server memory only. Outside the grid = bedrock (server-built parts).
- Server (`Services/Dig`) validates every punch: solid, exposed through the given face, within
  `Reach + ReachSlack` of the HRP, attack rate, backpack space. Brushes (`Progression.brushTargets`),
  finds (`Progression.findAt`: seed + coordinates, deterministic), chambers (`Progression.chamberAt`:
  sealed rooms at each zone start, opened when you break next to them).
- Clients render (`Controllers/VoxelRender`): snapshot when near a tunnel, deltas after each punch,
  only the shell (`Shared/Shell`), chunks within `StreamRadius`, pooled parts, part budget. The
  character collides with these local parts.

## Layout
- `src/shared` -> ReplicatedStorage.Shared: Config (World, Zones, Finds, Rarity, Upgrades, Economy,
  Cycle, PvP, Extras, Products, Assets, Audio, Patrol, Admin), Voxel, Shell, Progression + Strata + Patrol + ChamberSets (pure,
  Lune-tested; Strata = cosmetic features inside each zone's rock, Patrol = guard positions), Tunnel, Format, Remotes.
- `src/server` -> ServerScriptService.Server: State (runtime per player), Net, Services (WorldBuilder,
  Data, Stats, Cells, Dig, Loot, Shop, Gym, Collection, DayNight, Brawl, Raid, TopDog, Product,
  Escape, Rewards, Guards, Patrol, Events, Market, Admin), Util (Build, RateLimit, GymProps, Dressing), Packages (ProfileStore).
  Services talk through hooks wired in `init.server.luau` (e.g. `Dig.onFind`, `DayNight.onDay`).
- `src/client` -> StarterPlayerScripts.Client: Controllers (VoxelRender, DigController, DigFX,
  CameraController, HUD, Shops, Clock, PvPController, ExtraShops, Moments, GymController, DigAudio, GuardController, Chambers), Util (UI, Panel,
  Sound, Shake, PunchAnim, LootToast).
- `tools/view/`: renders CI's world dump (artifact "world") + a Lune-generated tunnel with three.js in
  headless Chromium (`render.mjs`, views in `views.json`). Use it to LOOK at changes to the world.
- `tests/` Lune specs, `tools/simulate.luau` balance sim, `tools/smoke.luau` headless smoke test run by
  CI inside the real place (`tools/ci/smoke.py`).

## Local checks
```
./tools/install-tools.sh        # or: rokit install
stylua --check src tools tests && selene src && lune run tests && lune run tools/simulate && rojo build default.project.json -o rtr.rbxl
```
