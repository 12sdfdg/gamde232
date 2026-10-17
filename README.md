# Pop a Balloon RNG

Roblox tower-defense with RNG: roll the dice to get turrets of different rarity ("1 in N"), place them along the beach path and pop waves of balloons before they reach the base.

## Running in Roblox Studio

The project uses [Rojo](https://rojo.space).

1. Install Rojo (the CLI and the Studio plugin).
2. In this folder run `rojo serve`.
3. In Studio, open an empty **Baseplate** place, open the Rojo plugin and press **Connect**.
4. Press **Play**. The map is built automatically when the server starts.

## Controls

- **R** or the dice button — roll a turret.
- Click a turret in the right-hand list, then click on the sand to place it. Right-click or **Q** cancels.
- **E** while hovering your own turret — pick it back up into your inventory.

## Structure

- `src/Shared` (ReplicatedStorage.Shared)
  - `Config.lua` — all balance: turrets, rarities, balloons, economy, placement rules.
  - `RNG.lua` — weighted roll (weight = 1 / N).
  - `Net.lua` — creates and resolves remotes.
- `src/Server` (ServerScriptService.Server)
  - `init.server.lua` — entry point and main loop.
  - `MapBuilder.lua` — ground, path, spawn and base.
  - `BalloonService.lua` — balloon spawning, movement, HP bars, pops and leaks.
  - `TurretService.lua` — placement validation, turret models, targeting and shooting.
  - `WaveService.lua` — waves, base health, wave rewards, restart on loss.
  - `RollService.lua` — server-side rolls with cooldown.
  - `PlayerData.lua` — cash, roll count, inventory, leaderstats (Cash / Rolls / BestWave).
- `src/Client/init.client.lua` — HUD, roll reveal animation, inventory, placement ghost, shot effects.

## Balance

Edit `src/Shared/Config.lua`. To add a turret, add an entry to `Config.Turrets` and its id to `Config.TurretOrder`.
