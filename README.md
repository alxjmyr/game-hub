# Game Hub

An offline arcade, built with **Godot 4.5.2 and GDScript**. Open the shelf, choose from eight games, and play. No accounts, ads, online chat, or network connection are needed. All artwork is drawn locally by the game.

## Play on this Ubuntu machine

From this directory:

```sh
./game-hub
```

The launcher uses `build/linux/game-hub` when available, otherwise the local Godot executable in `.tools/`. You can also double-click the exported executable in your file manager. If Linux asks whether an executable may run, enable its executable permission first.

To practice navigating in a terminal:

```sh
cd ~/Developer/game-hub
./game-hub
```

Optional: run `./scripts/install-command.sh` to install a small launcher in `~/.local/bin`. With that directory on your `PATH`, type `game-hub` from anywhere. This script does not change shell startup files or overwrite an existing command.

## Games

- **Memory Match:** reveal two cards to find matching pairs. Choose 6, 10, or 15 pairs. A move is one pair of flips; improve your own best score without a timer. Use the mouse or Tab and Enter/Space to choose cards and buttons.
- **Ball & Bucket:** arrange a limited set of blocks to guide a falling ball into a bucket. Drag blocks, rotate the selected piece with Q/E or the on-screen buttons, and press Space or Drop to test your plan. Hold Shift with Q/E for finer rotation; arrow keys move a selected piece. Retry preserves your arrangement. Experiment freely; there is no penalty for trying again.

- **Jigsaw Puzzles:** assemble landscape, space, or underwater pictures with 9, 16, or 25 square-cut pieces. Drag pieces into place; the hardest level adds quarter-turn rotation. Use N to select the next piece, arrows to choose a square, Enter to place it, and Q/E to rotate. The two harder levels show a small picture-box reference beside the board. Optional hints mark the selected piece’s destination.
- **Maze Explorer:** explore generated mazes with the arrow keys or WASD. Choose 7×5, 11×7, or 15×9 mazes. Harder mazes place a key down a side branch, away from the locked door, so you must retrieve it before heading out. Carry the key to the door; stepping into the door uses the key and opens it permanently. Hints reveal the next few steps; Start over preserves the maze, while New maze generates another.
- **Letter Hunt:** collect stars by typing letters, letters plus numbers, or whole words. Uppercase and lowercase both work. Mistakes preserve progress; Backspace undoes a letter in a partial word. Optional QWERTY keyboard hints help build confidence without a clock.
- **Minesweeper** has 10 mines on a 9×9 board. Your first click opens a safe patch. Each number counts neighboring mines, including diagonals. Open all 71 safe squares to win. Right-click or press F to toggle a flag, or enable Flag mode for single-button play. Opening a number again reveals its remaining neighbors if the adjacent flag count matches. A misplaced flag can make this hit a mine.

Use each game's **Game shelf** button or Escape to return to the hub. In Monster Blast, Escape pauses the game; choose **Game shelf** from its menu to leave. Instructions and difficulty choices are available inside the games.

Ball & Bucket keeps Explorer and Inventor on a simple ramp layout. Engineer varies ball and bucket positions on both axes, supplies one to four pieces including curved ramps and optional L-shaped blocks, and adds straight, L-shaped, or curved fixed barriers at varying angles. Unused shapes sit in a separate bottom dock with collisions disabled. Reference solutions use one or more ramps to pass the barrier; seeded physics tests cover 322 layouts across the three difficulties.

## Run from source

Install the standard (non-.NET) [Godot 4.5.2 release](https://godotengine.org/download/archive/4.5.2-stable/), then open `project.godot` in the editor or run:

```sh
godot --path .
```

`GODOT_BIN=/path/to/godot ./game-hub` explicitly selects an engine and runs the source project, even when an exported build exists. To open a game directly, append `-- --memory`, `-- --physics`, `-- --jigsaw`, `-- --maze`, `-- --letter-hunt`, `-- --caste-maze`, `-- --minesweeper`, or `-- --monster-blast` to the launch command.

The games need neither Python nor Node.js. Only development/exporting needs the Godot editor and export templates.

## Build standalone apps

Install matching **4.5.2 export templates**. The export script uses the local template directory `.tools/data/godot/export_templates/4.5.2.stable/`, keeping development files out of your system configuration. Templates are available from the same official release above. Extract the archive's `templates/` contents there. Alternatively, export through Godot's editor using its installed templates and the checked-in presets.

```sh
./scripts/export.sh linux
./scripts/export.sh windows
./scripts/export.sh macos
# Or build all three:
./scripts/export.sh all
```

Set `GODOT_BIN` if your editor executable is elsewhere. Output:

| Platform | Build | Launch |
| --- | --- | --- |
| Linux x86-64 | `build/linux/game-hub` | `./game-hub` from its folder |
| Windows x86-64 | `build/windows/game-hub.exe` | `.\game-hub.exe` in PowerShell |
| macOS Intel + Apple Silicon | `build/macos/Game Hub.zip` | Extract, move `Game Hub.app` to Applications, then `open "/Applications/Game Hub.app"` |

Copy the exported build folder (including its license notices) to the other machine using a USB drive or your normal file-sharing method. The Linux and Windows builds embed game data in the executable. The Mac ZIP contains the app bundle. Players do not need to install Godot. Keep the whole Mac app bundle intact.

These private builds are not publicly signed/notarized. macOS may require a parent to approve the app through System Settings → Privacy & Security after attempting to open it; Windows may show an unrecognized-app prompt. Only approve the build you made or received from a trusted household source. We do not disable operating-system security settings. See [Godot's macOS launch guidance](https://docs.godotengine.org/en/stable/tutorials/export/running_on_macos.html).

The source checkout also includes `game-hub.ps1` for Windows development. It uses an existing Windows build or `$env:GODOT_BIN`. Running the exported `.exe` directly avoids PowerShell script execution-policy setup.

Godot and its bundled libraries are open source. Their notices are in `licenses/` and copied beside each exported build.

## Local progress

Settings and scores are stored in Godot's `user://progress.cfg` in the operating system's per-user application data directory, outside the game executable. Each machine keeps its own progress. Copying a new build over the old executable preserves these saves.

## Verification

Run all checks with isolated temporary save data:

```sh
./tests/run.sh
```

Or run individual checks with the editor executable (the release executable intentionally excludes test scripts):

```sh
.tools/Godot_v4.5.2-stable_linux.x86_64 --headless --path . --script tests/test_memory.gd
.tools/Godot_v4.5.2-stable_linux.x86_64 --headless --path . --script tests/test_ball_bucket.gd
.tools/Godot_v4.5.2-stable_linux.x86_64 --headless --path . --script tests/test_jigsaw.gd
.tools/Godot_v4.5.2-stable_linux.x86_64 --headless --path . --script tests/test_maze.gd
.tools/Godot_v4.5.2-stable_linux.x86_64 --headless --path . --script tests/test_letter_hunt.gd
.tools/Godot_v4.5.2-stable_linux.x86_64 --headless --path . --script tests/test_minesweeper.gd
.tools/Godot_v4.5.2-stable_linux.x86_64 --headless --path . --script tests/test_hub.gd
```

Use your installed Godot executable instead on other platforms. Headless checks cover game logic; also launch the graphical app to verify rendering, sound, and input on each machine.

## Project layout

- `app/` — game shelf, shared styling, settings, and local progress.
- `games/memory.gd` — Memory Match.
- `games/ball_bucket.gd` — Ball & Bucket.
- `games/jigsaw.gd` — Jigsaw Puzzles.
- `games/maze.gd` — Maze Explorer.
- `games/letter_hunt.gd` — Letter Hunt.
- `games/minesweeper.gd` — Minesweeper.
- `tests/` — gameplay and integration checks.
- `scripts/` — export and optional terminal-command setup.
- `GAME_IDEAS.md` — ideas and design goals.

The Compatibility renderer targets ordinary desktop hardware. Exporting an app does not prove it has been tested on that operating system: verify a first launch and all eight games on each household machine before relying on that build.

### Castle Maze

A three-level adventure designed for the family game shelf. Choose a knight, princess, or explorer; search the Black Dungeon for a boxed key and hidden exit, descend into White Castle’s basement and secret room, then cross the Three Brown Towers’ rope bridges and return to the back tower’s trapdoor to reach the courtyard. Each level has a differently shaped key. Sleepy guards wake when approached, and holes send you back to your last safe tile without losing your key. There are no lives or time limits.

Use arrow keys, WASD, or the on-screen arrows. Walk onto boxes and doors to search or unlock them; “A little hint” marks the next few safe steps. Launch directly with `./game-hub -- --caste-maze`.

### Monster Blast — escape the castle

A complete three-chapter desktop FPS campaign with original pixel art, 3D corridors, torchlight, synthesized effects, and a moonlit finale. Spooky monster combat includes pixel blood and is more intense than the other shelf games.

Choose **Easy**, **Normal**, or **Hard** before entering the dungeon. Easy preserves the original dungeon’s movement and attack timing. Normal makes monsters move 30% faster and attack 35% faster; Hard makes them move 65% faster and attack 80% faster. Difficulty does not inflate enemy health, change player speed, or increase damage. It remains fixed through the run and retries; New escape returns to the selector.

1. **The Dungeon:** leave your cell, take the sleeping guard’s pistol, find the brass key in the Warden’s Chapel, and unlock the castle stairs. Thirteen monsters and a cracked-wall supply stash retain the original opening.
2. **The Hollow Crown:** explore the armory, forbidden library, banquet gallery, and throne hall. Find the silver seal and defeat the **Iron Warden** to open the portcullis. His orange windup warns of a charge aimed at your previous position; sidestep, then attack during his blue recovery. Below half health he prepares attacks faster.
3. **The Last Drawbridge:** cross the moonlit graveyard and watchtowers. Raise both winches, defeat the **Grave Regent**, and use his gate seal to escape. His spell fans widen and he summons four gargoyles at half health. The lowered drawbridge and final gate lead to the campaign ending.

Every chapter has a secret supply room, ammunition, health, distinct landmarks, and an exploration map. The later chapters introduce fast gargoyles, a blunderbuss in the armory, and a rune caster in the north watchtower. Each heavy weapon spends three rounds; the pistol spends one. If fewer than three rounds remain, firing a heavy weapon switches to the pistol. Empty ammunition automatically falls back to melee.

| Control | Action |
| --- | --- |
| WASD or arrow keys | Move / strafe (Up/Down: forward/back; Left/Right: strafe) |
| Mouse | Look / aim |
| Left mouse (hold supported) | Shoot; melee automatically when empty |
| F or right mouse | Melee, without spending ammo |
| 1 / 2 / 3 | Pistol / blunderbuss / rune caster, once found |
| E | Use exit gate, raise winch, or search cracked wall |
| Tab | Toggle explored map (game continues) |
| Escape | Pause / resume and release mouse |
| [ / ] | Lower / raise mouse sensitivity |

At each chapter transition, health, ammunition, and weapons carry forward. Death or Restart level restores exactly that chapter’s entry equipment, while resetting its enemies, pickups, boss, key, winches, and secret. Earlier chapters remain complete. Checkpoints last for the current session; leaving for the shelf starts a new campaign next time. Only escaping the final gate records a hub win, with difficulty, all three chapter results, elapsed play time, kills, accuracy, and secrets. The window automatically pauses on focus loss; the shelf’s Sound toggle controls all effects and ambience.

Run the updated Linux build with `./game-hub -- --monster-blast`, or force source with:

```sh
GODOT_BIN="$PWD/.tools/Godot_v4.5.2-stable_linux.x86_64" ./game-hub -- --monster-blast
```

Implementation: `games/monster_blast.gd`, `games/monster_blast/art.gd`, and the hand-authored chapter layouts in `games/monster_blast/levels.gd`. `tests/run.sh` includes the original dungeon checks, campaign mechanics and hub persistence, and a continuous three-chapter traversal using normal combat and earned supplies. `tests/capture_monster_campaign.gd` renders the new rooms, bosses, and menus, including the 900×600 layout. Human playtime varies with exploration, aim, and difficulty; the design target remains roughly 15–25 minutes for a first escape.
