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
│       ├── Effects          (group "vfx_root" — Vfx.spawn target)
│       └── Projectiles      (group "projectile_root")
└── HUD (CanvasLayer, process_mode ALWAYS)
```
Autoloads: `Settings`, `RunSession`, `SceneRouter`, `AudioService` (see `docs/audio.md`). Planned: `SaveService`.

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

## Visual feedback
- `Vfx.spawn(tree, scene, position, size)` instantiates one-shot effects under the level's Effects node.
- Projectiles spawn their `impact_effect`; actors spawn `death_effect` on depletion.
- Camera shake: `GameplayCamera.add_trauma()`; offsets use `h_offset`/`v_offset`, so the play rect is untouched.
- `FlashComponent.Mode.BLINK` (player i-frames) vs `OVERLAY` (white flash on enemy hits).
- Models are `@tool` scripts that build primitives at runtime via `ModelKit`; scenes keep gameplay nodes
  (hurtboxes, muzzles, telegraphs) as real scene nodes so exported references resolve.

## Stage flow
```
Level (inherits graybox_room.tscn)
├── Enemies                 (LevelDirector spawns wave units here; bosses summon here)
├── Pickups                 (group "pickup_root" — elite weapon cores)
├── StageUI                 (level-owned overlay: banners, WARNING, prompts, boss bar)
└── LevelDirector           (runs a StageData resource)
```
- `StageData` (`directors/stage_data.gd`): stage name, `waves: Array[WaveData]`, boss scene, clear bonus,
  `next_level` / `restart_level`. `WaveData`: start time, enemy scene, count, interval, entry heights,
  optional parking X, speed scale, formation bonus, prompt.
- `LevelDirector` states: `INTRO → WAVES → BOSS_WARNING → BOSS → CLEAR → DONE`. Waves run on accumulated
  physics time. After the last wave, the boss comes when the field is clear (or after a straggler timeout).
  On boss defeat: clear bonus, hostiles cleared, banner, then `SceneRouter.go_to(next_level)`.
- Debug keys: F6 skip to boss, F8 advance boss phase, F7 cycle echo weapon (Main).

## Enemies and bosses
- `SpaceEnemy` (`enemies/space/space_enemy.gd`): one movement pattern (`STRAIGHT, SINE, SWOOP, HOLD, CHARGE`)
  + one fire pattern (`STRAIGHT, AIMED, AIMED_BURST, DIAGONAL_PAIR, SPREAD_FAN, RADIAL_RING`). Each type is a
  thin inherited scene of `space_enemy.tscn` overriding stats and shapes; `EnemyModel.kind` picks the look.
  Elites set `drop_echo`. Enemies join group `enemies` and expose `is_alive()` + `hurtbox` (Arc targeting).
- `BossBase` (`enemies/bosses/boss_base.gd`): `INTRO → PHASE_1 → BREAK_1 → PHASE_2 → BREAK_2 → PHASE_3 →
  DEFEATED`. Health floors (`HealthComponent.floor_health`) hold each phase until its break. Subclasses
  override `_phase_attacks`, `_attack_begin/_update/_duration`, optionally `_phase_complete` and
  `_core_exposed`. `BossTurret` is a destructible module; `BeamHazard` is a telegraphed lightning lane.

## Weapons
- `RunSession.selected_echo` + `echo_ammo`; `equip_echo()`, `consume_echo_ammo()`, `clear_echo()`.
- `EchoModuleData` resources in `combat/weapons/echoes/` (`EchoModules.get_data(id)`).
- `ShipArsenal` picks base gun vs echo each tick; `GuardOrbs` cancel hostile projectiles (hitboxes are
  monitorable on the hitbox layer so orbs can see them). `EchoPickup` magnetizes to the player and calls
  `ShipPlayer.collect_echo()`.

## UI and flow
```
Main
├── CurrentLevel      title → campaign (all three stages, seamless) → title
├── PostLayer         vignette
├── HUD (layer 10)    status + score clusters, TutorialCard, F3 debug panel — hidden on the title
└── PauseMenu (15)    scrim + panel; process ALWAYS, gameplay frozen underneath
```
- `Main.start_game()`, `restart_stage()` (restores the stage-entry checkpoint the LevelDirector saves),
  `quit_to_title()`. Scene changes triggered from UI input are connected deferred.
- `Settings` autoload (reduced flash/shake/motion, glow, high graphics, tutorials, debug labels) persisted to
  `user://settings.cfg`. `ArtStyle.flash_scale()` / `shake_scale()` read it. `high_graphics` is only offered
  where Forward+ runs (desktop): the scene's `environment_binder` then enables KeyLight shadows, SSAO and 4x
  MSAA, and `Settings.particle_amount()` scales effect particle counts.
- Stage 2 mid-boss: `WarshipLayout` builds a `MidBossZone` (code-built doors, trigger, camera lock) that
  spawns `SentinelBoss` (a `BossBase` subclass) and resets itself on player death. Zone art:
  `WarshipZones` (x-range table: accent, fog) drives `InteriorBackdrop` wall tints, zone lights and the
  depth fog (applied to a duplicated environment only while inside), `ZoneSetPieces` in the mid layer, and
  the per-zone platform materials in `WarshipLayout`. Platforming kit: `TimedBlock`, `ConveyorBelt` (an
  Area3D pushing grounded bodies via move_and_collide over a continuous floor), `CrumblePlatform`; both
  vanishing kinds join the `unsafe_ground` group so pit recovery never returns you onto them.
- `WarshipModel` (art/models): one hero capital ship — lofted hull split into four sections, MultiMesh
  plating/windows/superstructure, towers, batteries, engines — used at full scale in the Stage 1 backdrop's
  own world and the boarding dive, at 3.6 scale under the Stage 3 track (`HullRunBackdrop.warship`), and destroyed in the ending
  (`destroy()` chains explosions and drifts the sections apart). Stage 1 depth:
  `PerspectiveBackdrop` renders its own 3D world (`own_world_3d` SubViewport) onto a screen quad under
  the sky follower; the warship approach runs on stage time (`approach_time`) and finishes early on the
  director's `boss_spawned`. `SpacePlanets` builds the shared planet set (layouts `ORBIT`, `HULL_RUN`).
- Boarding dive: `CampaignDirector._run_drop` drives the camera (`rig_override`, perspective during the
  dive); `DropCinematic` owns the temporary dive world and restores the environment; `MangaFx`
  (CanvasLayer 7, under StageUI) draws speed lines and impact frames. The mech's physics is paused while
  it is placed along the dive path.
- UI never owns gameplay state: HUD reads RunSession; TutorialCard reads input + Settings; StageUI is
  driven by the LevelDirector and boss signals.

## Stage 4 — 8-bit (levels/retro/)
- `RetroStage` renders into a 256x224 `SubViewport` (nearest filtering, pixel snapping) shown on canvas
  layer 12 (above the HUD, below pause); while it runs the main viewport's 3D is disabled and it joins
  `pausable_stage` so Main still allows pausing. It owns its entities and runs a classic rect-overlap
  collision loop (player shots vs enemies/boss core/armour/terrain; enemy shots, bodies and terrain vs
  the player) — the 3D Hitbox/Hurtbox components stay in the 3D stages.
- `RetroTimeline` holds the fixed wave script and the fortress terrain columns; `RetroPlayer`,
  `RetroEnemy` (kind-based behaviour), `RetroBoss`, `RetroText` (bitmap font), `RetroArt` (sheets).
- Health, score and SUPER energy are RunSession's, so the modern HUD state carries in and out.
- `PixelTransition` (layer 13) pixelates/posterizes the screen texture for the de-rez into Stage 4.
- Art: `tools/pixel/build.py` → `assets/retro/` (original sprites, NES 2C02 palette only).

## Seamless campaign (levels/campaign/)
```
Campaign (campaign.tscn) — one world, one GameplayCamera, one WorldEnvironment
├── Sky (CameraFollower, scales with ortho size) → SpaceBackdrop   side-view sky for Stages 1–2
├── Effects / Projectiles / Pickups / StageUI (letterbox + flash)
├── Players          ShipPlayer → MechPlayer → HullRider (swapped in-world at each transformation)
├── Stage1           Enemies + LevelDirector (auto_start=false, hand_off=true) — camera at x −700
├── Warship          warship_segment.tscn (x −130..346, roof deck y 30): InteriorBackdrop, ExteriorFollower
│                    → WarshipExterior, Layout (WarshipLayout), BossGate, PlatformerDirector (hand_off)
├── HullRun          hull_run_segment.tscn (deck y 30, x 300..2760): HullTrack, HullRunBackdrop, Enemies,
│                    HullRunDirector (hand_off)
└── CampaignDirector SHOOTER → DROP → PLATFORMER → ESCAPE → HULL_RUN → ENDING → DONE
```
- Stages are regions of one world; directors never change scenes when `hand_off` is set — they emit
  `stage_cleared`/`finished` and the CampaignDirector runs the in-engine transition.
- Transitions drive the camera through `GameplayCamera.rig_override`; the ortho→perspective cut uses
  `GameplayCamera.fov_matching(size, distance)` so it is invisible, then orbits behind the bike.
- Restart Stage reloads the campaign; the director reads `RunSession.checkpoint_id` ("STAGE 2"/"STAGE 3") and
  starts at that stage directly.
- Exported builds (web) do not resolve `NodePath` overrides that point outside an instanced sub-scene, and only
  apply child overrides on instances marked `[editable]`: segments therefore find the level's camera, UI,
  player, pickup root and environment by group (`GameplayCamera.find`, `StageUI.find`, `Players.find`,
  `pickup_root`), and scenes that override segment children list them as editable.
- Standalone dev rooms wrap each segment with its own camera/env/UI: `warship_level.tscn`, `hull_run_level.tscn`.

## 3D hull run (levels/hull_run/)
- `HullRider` (CharacterBody3D) + `HullRunDirector` chase rig (behind/above, lateral lag, bank, boost FOV).
- 3D-only combat pieces: `Bolt3D` (free-velocity projectile), `ForwardBeam` (SUPER), `Explosion3D`
  (billboarded flash/fire/smoke/sparks/ring), `additive_glow_billboard.gdshader`.
- `RunEnemy` base (health, hurtbox, telegraphed bolts, cleanup) → `RunFighter`, `RunTurret`, `RunGunship`.
- `HullTrack`: authored decks/obstacles/orbs/turrets tables, trench walls, racing rail lights, burning
  superstructure; meshes use `visibility_range_end` so the 2.5 km deck stays cheap. `recovery_point(x)`.
- `HullRunBackdrop.activate()` swaps a duplicated environment to the `space_sky.gdshader` sky and builds
  planets/capital ships/streaks around the camera.

## Side-view level kit (levels/kit/)
`LevelKit.solid()` (StaticBody + chunk-tech visuals incl. seams, bolts, vents, ceiling lamps), `steam()`,
`sparks()`, `MovingPlatform`, `Hazard` (ELECTRIC / SPIKES / CRUSHER), `ItemPickup`, `Checkpoint`.

## Players
| Player | Scene | Body | States |
|---|---|---|---|
| Ship | `player/ship/ship_player.tscn` | Node3D, soft play-rect bounds | CONTROL, DASH, HIT, DISABLED, CINEMATIC |
| Mech | `player/mech/mech_player.tscn` | CharacterBody3D (layer actors, mask world) | GROUND, AIR, DASH, WALL, HIT, SUPER, DISABLED, CINEMATIC |
| Bike | `player/bike/hull_rider.tscn` | CharacterBody3D, 3D (forward +X, steer Z) | RIDE, AIR, BOOST, SUPER, DISABLED, CINEMATIC |
- All three join group `player` (`Players.find()`), mirror health into `RunSession`, expose `facing`,
  `aim_offset` (enemies aim at the chest via `Players.aim_point()`), `grant_invulnerability()`,
  `collect_echo()` / `can_collect()`, `get_debug_lines()`, and optionally `tutorial_steps()` (TutorialCard).
- The mech reuses `ShipArsenal` (base gun + echo weapons, `facing` aware); mech and bike read `MechInput`.
- SUPER: `RunSession.add_charge(points)` fills energy (600 per segment); `super_ready()` at 3; players spend
  it and spawn `PlayerBeam` (continuous PLAYER hitbox + bullet eraser) in the Effects root.
- Physics layers: 1 world, 2 hurtbox, 3 hitbox, 4 pickup, 5 actors (character bodies collide with world only).

## Performance approach
No pooling yet: instantiate + off-screen/lifetime cleanup. Build a stress room and profile a release
build before pooling anything; pool only proven hotspots.

## Testing
`tests/run_tests.gd` is a dependency-free headless runner. See `docs/test-plan.md` for coverage and
`docs/local-setup.md` for commands.
