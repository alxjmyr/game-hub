# Game Hub

An offline family arcade for ages 8–12, built with **Godot 4.5.2 and GDScript**. Open the shelf, choose Memory Match or Ball & Bucket, and play. No accounts, ads, online chat, or network connection are needed. All artwork is drawn locally by the game.

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

Use each game's **Game shelf** button or Escape to return to the hub. Instructions and difficulty choices are available inside the games.

The first Ball & Bucket puzzle generator translates and mirrors a tested ramp layout, then varies the piece budget and bucket width by difficulty. This keeps random puzzles solvable; more varied multi-ramp puzzle families can be added later.

## Run from source

Install the standard (non-.NET) [Godot 4.5.2 release](https://godotengine.org/download/archive/4.5.2-stable/), then open `project.godot` in the editor or run:

```sh
godot --path .
```

`GODOT_BIN=/path/to/godot ./game-hub` explicitly selects an engine and runs the source project, even when an exported build exists. The games need neither Python nor Node.js. Only development/exporting needs the Godot editor and export templates.

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
.tools/Godot_v4.5.2-stable_linux.x86_64 --headless --path . --script tests/test_hub.gd
```

Use your installed Godot executable instead on other platforms. Headless checks cover game logic; also launch the graphical app to verify rendering, sound, and input on each machine.

## Project layout

- `app/` — game shelf, shared styling, settings, and local progress.
- `games/memory.gd` — Memory Match.
- `games/ball_bucket.gd` — Ball & Bucket.
- `tests/` — headless gameplay checks.
- `scripts/` — export and optional terminal-command setup.
- `GAME_IDEAS.md` — ideas and design goals.

The Compatibility renderer targets ordinary desktop hardware. Exporting an app does not prove it has been tested on that operating system: verify a first launch and both games on each household machine before relying on that build.
