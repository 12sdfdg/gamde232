# Pop a Balloon RNG (clone)

A Roblox tower-defense + RNG game: roll turrets ("1 in N"), place them on your
island base, press **Start** and pop balloon waves for coins. Spend coins in
the skill tree (coins, luck, roll speed, auto roll, damage, slots, wave speed).

## Open in Roblox Studio
1. Studio → **File → Open from File…** → `game/PopBalloonRNG.rbxlx`
2. Press **Play** (F5). The map, plots and UI are built by scripts at runtime.
3. For saving and global leaderboards: **Game Settings → Security → Enable
   Studio Access to API Services** (the game must be published first).
   Without it everything works, data just isn't saved.

## Controls
- 🎲 **ROLL** – roll a turret. Auto Roll unlocks in the skill tree.
- 🏰 **Turrets** – pick a turret, click on your base to place it
  (green = ok, red = blocked). `R` rotate, `Q` cancel. **Delete** / **Remove All**.
- ▶ **Start** – start the waves. Balloons that reach the hut cost lives.
- ⚔ **Popper Sword** – pop balloons yourself.
- ⬆ **Skills**, 📖 **Index**, 🏠 **Home**.

## Editing
All balance/content lives in `src/shared/Config.luau` (turrets, balloons,
chances, upgrades, sounds). Sources follow the Rojo layout
(`default.project.json`), so you can `rojo serve` instead of the .rbxlx.
After editing sources run `python3 tools/build_rbxlx.py` to rebuild the place.

Custom sounds: upload files from `sfx_pack/ogg` to Roblox and paste the
`rbxassetid://…` ids into `Config.Sounds`.
