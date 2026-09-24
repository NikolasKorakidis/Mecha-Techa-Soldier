# SHIFT//WING

2.5D vertical slice in Godot 4.7: a horizontal space shooter that transforms into a Mega Man X-style mech
platformer, then into a motorcycle for a highway escape. The link between both halves is **Echo Shift** — decode an enemy's combat pattern (Burst, Arc,
Guard) and carry it through the ship-to-mech transformation.

**Status:** full three-stage run — Stage 1 shooter (Choir Engine) → ship-to-mech transformation → Stage 2
warship platformer (Reactor Core) → mech-to-bike transformation → Stage 3 highway runner → Mission Complete.
SUPER beam in every form, elite weapon drops (Burst / Arc / Guard) that carry across forms, checkpoints,
pause menu with accessibility options. Next up: audio.

## Play it
**In the browser:** https://nikolaskorakidis.github.io/Mecha-Techa-Soldier/ (Chrome or Edge recommended;
click the game once to give it keyboard focus). Cutscenes skip with Jump or Fire. Every push to the branch rebuilds it after the tests pass.

**Locally:**
1. Install Godot 4.7.2 (standard build).
2. `godot --path .` from the repo root, or open `project.godot` in the editor and press F5.

| Action | Keyboard | Controller | Ship | Mech | Bike |
|---|---|---|---|---|---|
| Move | WASD / arrows | Left stick / D-pad | Fly | Run | Throttle ± / hold down to duck |
| Fire (hold) | J / left mouse | Right trigger | Shoot | Shoot | Shoot |
| Jump | Space | A / Cross | Vertical burst | Jump, press again to double jump | Jump / double jump |
| Dash | K / Shift | B / Circle | Dash | Dash (dash + jump = long jump) | Boost (rams crates) |
| SUPER (3 energy) | I / Q | Right bumper | Resonance Beam | Resonance Beam | Resonance Beam |
| Pause menu (Resume / Restart Stage / Controls / Options / Quit) | Esc | Start | | | |
| Next stage / debug panel | F2 / F3 | — | | | |
| Skip to boss (or finish) / cycle weapon / next boss phase | F6 / F7 / F8 | — | | | |

## Docs
- [Game design](docs/game-design.md) — loop, Echo Shift, levels, bosses, milestones
- [Architecture](docs/architecture.md) — scene tree, state ownership, damage contract
- [Art direction](docs/art-direction.md) — palette, style tokens, accessibility, visual test room
- [Art bible](docs/art-bible.md) — original shape language and VFX budget
- [Test plan](docs/test-plan.md) — automated coverage and manual regression
- [Local setup](docs/local-setup.md) — engine path, import/test/boot commands
- [CLAUDE.md](CLAUDE.md) — rules for Claude Code sessions
