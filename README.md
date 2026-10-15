# Dig Out! ⛏️

A Roblox prison-escape digging game, built 100% from code with [Rojo](https://rojo.space) + Luau.

Punch through the wall of your cell, dig a tunnel through plaster, brick and concrete (and later
sewers, crystal caves and magma), find hidden treasures, dump the rubble in the Yard, sell finds to
The Fence and upgrade your tools in the Common Room. Mobile first.

- `src/` game code (shared / server / client), see `CLAUDE.md` for the layout and rules
- `tests/` Lune unit tests (`lune run tests`)
- `tools/simulate.luau` balance simulation (`lune run tools/simulate`)
- `tools/smoke.luau` headless smoke test that CI runs inside the place
- Push to `main` publishes the place (GitHub Actions)

Toolchain: `rokit install` (or `./tools/install-tools.sh`).
