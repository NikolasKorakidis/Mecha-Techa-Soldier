# SHIFT//WING

2.5D vertical slice in Godot 4.7: a horizontal space shooter that transforms into a run-and-gun mech
platformer. The link between both halves is **Echo Shift** — decode an enemy's combat pattern (Burst, Arc,
Guard) and carry it through the ship-to-mech transformation.

**Status:** M0 foundation + M1 ship feel (graybox). Next up: M2 Echo lab.

## Play it
**In the browser:** https://nikolaskorakidis.github.io/Mecha-Techa-Soldier/ (Chrome or Edge recommended;
click the game once to give it keyboard focus). Every push to the branch rebuilds it after the tests pass.

**Locally:**
1. Install Godot 4.7.2 (standard build).
2. `godot --path .` from the repo root, or open `project.godot` in the editor and press F5.

| Action | Keyboard | Controller |
|---|---|---|
| Move | WASD / arrows | Left stick / D-pad |
| Fire (hold) | J / left mouse | Right trigger |
| Vertical burst | Space | A / Cross |
| Dash | K / Shift | B / Circle |
| Pause | Esc | Start |
| Next dev room / debug panel | F2 / F3 | — |

## Docs
- [Game design](docs/game-design.md) — loop, Echo Shift, levels, bosses, milestones
- [Architecture](docs/architecture.md) — scene tree, state ownership, damage contract
- [Art bible](docs/art-bible.md) — shape language, color language, VFX budget
- [Test plan](docs/test-plan.md) — automated coverage and manual regression
- [Local setup](docs/local-setup.md) — engine path, import/test/boot commands
- [CLAUDE.md](CLAUDE.md) — rules for Claude Code sessions
