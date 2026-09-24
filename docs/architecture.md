# SHIFT//WING — Architecture

## Principles
- Composition over deep inheritance: actors are thin coordinators over components.
- ShipPlayer and MechPlayer are separate scenes; they share components, data types and `RunSession`.
- Tunables live in custom Resources (`*_tuning.tres`), behavior in nodes and scripts.
- Signals notify; exported references wire required local collaborators; groups serve broad queries.
- Autoloads only for true cross-scene services (`RunSession`, `SceneRouter`; later `AudioService`, `SaveService`).
- Build one vertical slice end to end before generalizing. No universal ability framework.

## Scene tree
```
Main (main/main.tscn, process_mode ALWAYS — owns pause + dev-room cycling)
├── CurrentLevel (process_mode PAUSABLE — SceneRouter mounts levels here)
│   └── <Level>
│       ├── WorldEnvironment, lights
│       ├── GameplayCamera   (group "gameplay_camera", defines the play rect)
│       ├── Starfield / parallax layers
│       ├── PlayerSpawn      (Marker3D)
│       ├── ShipPlayer       (later: MechPlayer)
│       ├── Enemies
│       └── Projectiles      (group "projectile_root")
└── HUD (CanvasLayer, process_mode ALWAYS)
```
Autoloads: `RunSession`, `SceneRouter`. Planned: `AudioService`, `SaveService`, `TransitionLayer`.

## State ownership
| State | Owner | Readers |
|---|---|---|
| Health (during play) | Player's `HealthComponent` → mirrored to `RunSession.set_health` | HUD via `RunSession.health_changed` |
| Score, energy, selected echo, difficulty, checkpoint | `RunSession` | HUD, levels, players |
| Current level | `SceneRouter` | Main |
| Pause | `Main` (`get_tree().paused`) | HUD label via `Main.set_paused` |
| Play rect | `GameplayCamera.get_play_rect()` (fixed 16:9, independent of window size) | Ship bounds, cleanup, enemy on-screen checks |

Rules: UI never owns gameplay state. Projectiles never route scenes or touch UI. Enemies award score via
`RunSession.add_score` (state, not UI).

## Damage contract
```
HitboxComponent (Area3D, layer "hitbox", mask "hurtbox", carries DamagePayload)
   └─ area_entered / continuous overlap → HurtboxComponent.receive_hit(payload, source)
        ├─ team filter: same team rejected; NEUTRAL payloads hit everyone
        └─ HealthComponent.apply_damage(payload, source) -> bool
             ├─ rejected if depleted, invulnerable, or amount <= 0
             ├─ health_changed(current, maximum)
             ├─ damaged(payload, source)
             └─ depleted(source)        # exactly once, until revive()
```
- `HitboxComponent.single_hit` (projectiles) stops after the first landed hit; `continuous` (contact damage)
  re-tests overlaps every tick and relies on the victim's invulnerability window.
- A depleted target returns `false`, so projectiles pass through it instead of being consumed.
- Physics layers (project.godot): 1 `world`, 2 `hurtbox`, 3 `hitbox`. Constants in `core/physics_layers.gd`.

### Data types
| Type | File | Notes |
|---|---|---|
| `DamagePayload` | `components/damage_payload.gd` | `amount: int`, `team`, `damage_type`, `knockback`, `can_be_reflected` |
| `Teams.Team` | `core/teams.gd` | `NEUTRAL, PLAYER, ENEMY` |
| `ShipTuning` | `player/ship/ship_tuning.gd` / `.tres` | All ship feel numbers |
| `ShipInput` | `player/ship/ship_input.gd` | One tick of input; `from_devices()` or `make()` for tests |
| `EchoModuleData` | M2 | id, display name, color, ship/mech weapon scenes, special cost |
| `WaveData` | M3 | start time, enemy scene, count, interval, path, formation, fire profile, echo override |

## Player (ship)
```
ShipPlayer (Node3D, ship_player.gd) — state: CONTROL, DASH, HIT, DISABLED, CINEMATIC
├── Model            (visual only; banks and squashes; FlashComponent blinks it)
├── DashMeter        (visible cooldown bar)
├── Muzzle           WeaponComponent — driven by ShipPlayer.tick(); never self-processes
├── Hurtbox          HurtboxComponent (team PLAYER), smaller than the visible hull
├── Health           HealthComponent
├── Flash            FlashComponent
└── Movement         ShipMovement — accel/decel, dash, vertical burst, soft boundary
```
- `_physics_process` builds a `ShipInput` from devices and calls `tick(delta, input)`. Tests set
  `read_devices = false` and call `tick()` directly for deterministic stepping.
- Invulnerability = hit window OR respawn window OR dash i-frames OR DISABLED/CINEMATIC.
- `died` → the level decides what happens (TestRoom respawns after `respawn_delay`).
- `get_debug_lines()` feeds the F3 panel (group `debug_telemetry`).

## Enemies (current)
- `TargetDummy` (`enemies/shared/`): stationary, scores, rebuilds after a delay.
- `SpaceDrone` (`enemies/space/`): sine drift, telegraph flash before each shot, contact damage,
  culled off-screen only after it has entered (`OffscreenCleanup.require_entered`).

## Levels
- `levels/test_rooms/graybox_room.tscn` — movement sandbox (base scene).
- `levels/test_rooms/combat_test_room.tscn` — inherits the graybox room; adds a target dummy and a
  deterministic drone spawner. This is Main's start level until the real flow exists.

## Performance approach
No pooling yet: instantiate + off-screen/lifetime cleanup. Build a stress room and profile a release
build before pooling anything; pool only proven hotspots.

## Testing
`tests/run_tests.gd` is a dependency-free headless runner. See `docs/test-plan.md` for coverage and
`docs/local-setup.md` for commands.
