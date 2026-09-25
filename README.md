# SHIFT//WING

2.5D vertical slice in Godot 4.7: a horizontal space shooter that transforms into a Mega Man X-style mech
platformer, then into a motorcycle racing along the top of the exploding warship (3D chase view). The link between both halves is **Echo Shift** — decode an enemy's combat pattern (Burst, Arc,
Guard) and carry it through the ship-to-mech transformation.

**Status:** one seamless campaign, no scene switches. Stage 1 side-view shooter against enemy starships (Choir
Colossus mecha boss), the enemy warship creeping in from far away until you fly over its runway → the camera
swings behind the Kestrel, it dives at the warship (manga speed lines), transforms mid-dive and the mech
lands on the roof → Stage 2 Mega Man X-style platformer through eight colour-zoned sections of the warship
(charge shot, appearing blocks, conveyors, Heart/Energy Tanks, secrets, Bulkhead Sentinel mid-boss, Reactor
Core) → the roof blows out, the mech thrusts up, becomes the bike and the camera swings behind it → Stage 3
3D chase-view run along the spine of the burning 3.6 km warship (fighters, turrets, trench run, pursuit
gunship) → launch off the bow, the camera pulls back and the whole ship explodes → the picture de-rezzes into
Stage 4, an 8-bit (NES-style) rearrangement of Stage 1 with pixel sprites, chiptune and the Core Breaker
boss → Mission Complete. SUPER beam in every form,
elite weapon drops that carry across forms, checkpoints (restart resumes at the current stage), pause menu with
accessibility options. Original 16-bit-style soundtrack and sound effects, generated in code
([audio](docs/audio.md)), with music/effects volume in Options. Desktop builds default to **High graphics**
(shadows, SSAO, 4x MSAA, denser particles; toggle in Options); the web build runs the standard setup.

## Play it
**In the browser:** https://nikolaskorakidis.github.io/Mecha-Techa-Soldier/ (Chrome or Edge recommended;
click the game once to give it keyboard focus). Transitions play in-engine with letterbox bars. **Select Stage** on the title menu jumps straight to Stage 1, 2, 3 or 4. Every push to the branch rebuilds it after the tests pass.

**Locally:**
1. Install Godot 4.7.2 (standard build).
2. `godot --path .` from the repo root, or open `project.godot` in the editor and press F5.

| Action | Keyboard | Controller | Ship | Mech | Bike |
|---|---|---|---|---|---|
| Move | WASD / arrows | Left stick / D-pad | Fly | Run | Steer left/right, hold down to brake |
| Fire (hold) | J / left mouse | Right trigger | Shoot | Shoot; keep holding to charge, release for a charge shot | Shoot |
| Jump | Space | A / Cross | Vertical burst | Jump, press again to double jump | Jump / double jump |
| Dash | K / Shift | B / Circle | Dash | Dash (dash + jump = long jump) | Boost (rams, i-frames; steer + boost = roll) |
| SUPER (3 energy) | I / Q | Right bumper | Resonance Beam | Resonance Beam | Resonance Beam |
| Pause menu (Resume / Restart Stage / Controls / Options / Quit) | Esc | Start | | | |
| Next stage / debug panel | F2 / F3 | — | | | |
| Skip to boss (or finish) / cycle weapon / next boss phase | F6 / F7 / F8 | — | | | |

## Docs
- [Game design](docs/game-design.md) — loop, Echo Shift, levels, bosses, milestones
- [Architecture](docs/architecture.md) — scene tree, state ownership, damage contract
- [Art direction](docs/art-direction.md) — palette, style tokens, accessibility, visual test room
- [Art bible](docs/art-bible.md) — original shape language and VFX budget
- [Audio](docs/audio.md) — soundtrack, SFX generation, AudioService
- [Test plan](docs/test-plan.md) — automated coverage and manual regression
- [Local setup](docs/local-setup.md) — engine path, import/test/boot commands
- [CLAUDE.md](CLAUDE.md) — rules for Claude Code sessions
