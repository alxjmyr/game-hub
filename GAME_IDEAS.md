# Game ideas

A local games hub for kids roughly **8–12 years old**. Games should be fun and challenging first, while helping players become comfortable using a computer.

## Design goals

- Run locally, with no internet, accounts, ads, or online chat required.
- Make controls easy to learn, with room for skill and strategy to grow.
- Offer forgiving retries, optional hints, and increasing difficulty. Avoid timers by default.
- Aim for an age range, not a single difficulty: introduce concepts gently, then add meaningful challenges for older or experienced players.
- Build computer confidence through play: clicking, dragging, keyboard navigation, and eventually typing.
- Keep any saved progress on this machine.
- Support both desktop launching and terminal launching, helping kids become comfortable with the command line.

## Technical direction

- Use Godot with GDScript for the shelf and games, starting with the Compatibility renderer.
- Export standalone builds for Ubuntu Linux, macOS, and Windows; playing should not require the Godot editor or development tools.
- Bundle all game assets for offline play.
- Provide a simple `game-hub` terminal command through platform-specific launchers and PATH setup, alongside desktop shortcuts.
- Document installation and terminal launch steps for each platform. Test exported builds on the household machines, including macOS first-launch security handling.

## Ideas at a glance

| Game | Core play | Skills practiced | Ways to grow the challenge |
| --- | --- | --- | --- |
| Memory match | Flip cards to find matching pairs. | Mouse accuracy, memory, concentration. | Larger boards, more similar images, optional move goals. |
| Jigsaw puzzles | Drag and drop pieces to complete a picture. | Dragging, spatial reasoning, observation. | More pieces, rotation, fewer placement hints. |
| Maze explorer | Navigate a maze with the arrow keys. | Keyboard control, planning, problem-solving. | Larger mazes, branching routes, keys and doors. |
| Letter hunt | Find and press keys prompted by the game. | Keyboard familiarity, eventually typing. | Letters to words, more keyboard coverage, optional speed challenges. |
| Ball & bucket (working title) | Arrange blocks to guide a falling ball into a bucket. | Experimentation, spatial reasoning, cause and effect, dragging and rotation. | Smaller block budgets, trickier layouts, varied block shapes and lengths. |

## Ball & bucket

### Core concept

- A ball drop point is randomly positioned near the top of the play area.
- A bucket is randomly positioned near the bottom.
- The player receives **N blocks** of varying lengths and shapes.
- Blocks can be placed within the play area and rotated to any orientation to guide the ball.
- The player releases the ball and watches the physics simulation to see whether it lands in the bucket.
- After an attempt, the player can adjust the arrangement and try again.

### Proposed first version

- Start with a small set of straight blocks of different lengths.
- Provide clear drag and rotate controls, plus **Drop**, **Retry**, and **New Puzzle** buttons.
- Retry keeps the same puzzle and block arrangement so the player can experiment.
- Freeze placed blocks during simulation; the ball responds to gravity and collisions.
- Celebrate catching the ball without penalizing failed experiments.

### Challenge progression and future possibilities

- Begin with generous block budgets and easy-to-reach buckets.
- Introduce angled, curved, or other shaped pieces as players learn.
- Increase challenge through tighter block budgets, narrower buckets, and obstacles.
- Consider optional goals such as using fewer blocks or collecting stars along the route.
- Consider a sandbox mode for experimenting freely.

### Questions to resolve when we build it

- How do we generate random layouts that are solvable with the supplied blocks?
- What rotation controls feel comfortable for kids using a mouse or trackpad?
- How bouncy or grippy should surfaces be to make outcomes understandable and repeatable?
- Should early puzzles be handcrafted before unlocking random challenges?

## Current playable library

All five proposed archetypes now have an initial local version:

- **Memory Match:** 6, 10, or 15 pairs, keyboard/mouse selection, local best scores.
- **Ball & Bucket:** three difficulty levels, draggable/rotatable ramps, forgiving retries.
- **Jigsaw Puzzles:** square-cut 9/16/25-piece pictures, three distinct scenes, rotation on the hardest level, optional placement hints and keyboard-only play.
- **Maze Explorer:** generated 7×5, 11×7, or 15×9 mazes; harder levels add a key and locked door. Arrow keys/WASD, on-screen movement, optional route hints.
- **Letter Hunt:** letters, letters plus numbers, and words; constellation progress and optional keyboard hints, without time pressure.

Potential future work: interlocking jigsaw outlines, more pictures and word lists, additional physics puzzle families, and optional challenge goals. These are extensions beyond the initial versions.
