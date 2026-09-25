# SHIFT//WING — Test Plan

## Automated checks (`tests/`)
Run with `$GODOT --headless --path . --script res://tests/run_tests.gd` (see `docs/local-setup.md`).
Each `tests/test_*.gd` extends `TestCase`; every `test_*` method runs on a fresh instance with a reset
`RunSession`. Async tests (`await`) are supported.

| Area | Covered by | Status |
|---|---|---|
| Input actions exist with keyboard + controller bindings | `test_input_actions.gd` | ✅ |
| Energy cannot exceed 3 or drop below 0 | `test_run_session.gd` | ✅ |
| Echo replacement updates RunSession | `test_run_session.gd` (session level) | ✅ — ship decode path in M2 |
| Checkpoint snapshot restores intended fields | `test_run_session.gd` | ✅ |
| Main boots into a level; room switch; pause | `test_main_boot.gd` | ✅ |
| Damage team filtering (friendly fire rejected) | `test_combat_contract.gd` | ✅ |
| Health depletion emitted once; dead actors ignore damage | `test_combat_contract.gd` | ✅ |
| Projectile off-screen / lifetime cleanup | `test_combat_contract.gd` | ✅ |
| Projectile → hurtbox hit through physics | `test_combat_contract.gd` | ✅ |
| HUD health updates only from RunSession | `test_ship_player.gd` | ✅ |
| Ship accel, bounds, dash, invulnerability, death, respawn | `test_ship_player.gd` | ✅ |
| Wave timing uses elapsed time consistently | `test_stage_flow.gd` | ✅ |
| Formation bonus only when every unit is destroyed | `test_stage_flow.gd` | ✅ |
| WARNING → boss → clear flow; skip-to-boss | `test_stage_flow.gd` | ✅ |
| Boss transitions cannot skip or repeat illegally; defeated emitted once | `test_stage_flow.gd` | ✅ |
| Boss breaks clear bullets and protect the player; no back-to-back attacks | `test_stage_flow.gd` | ✅ |
| Dreadnought core armored until turrets die | `test_stage_flow.gd` | ✅ |
| Echo ammo, replacement, loss on death; Burst/Arc/Guard behavior; elite drops | `test_echo_weapons.gd` | ✅ |
| Enemy aim, fan count, hold/exit, charge lock-on; all enemy scenes wired | `test_enemy_patterns.gd` | ✅ |
| Settings load defaults when absent or incompatible; round trip | `test_settings.gd` | ✅ |
| Reduced flash / shake scale feedback; trauma cap; hit stop restores time | `test_settings.gd`, `test_visual_feedback.gd` | ✅ |
| Overlay flash strobes (never solid) under sustained fire; sparks follow impact direction | `test_visual_feedback.gd` | ✅ |
| HUD shows ECHO: NONE / name + ammo; last health segment pulses | `test_hud_tutorial.gd` | ✅ |
| Tutorial card completes on action, is remembered, can be disabled | `test_hud_tutorial.gd` | ✅ |
| Pause opens the menu and freezes stage time; title → start → restart → quit | `test_main_boot.gd` | ✅ |
| Mech: held jump ≈ 3u, tap lower, double jump once, coyote, dash distance, wall jump, SUPER gating, pit recovery | `test_mech_player.gd` | ✅ |
| Audio: all tracks/SFX load, music loops, crossfade state, volume options drive buses, rapid-fire throttle | `test_audio.gd` | ✅ |
| Hull run: chase camera behind in perspective, auto-ride + steering limits, wall hurts / jump clears, gap recovery, bolts kill fighters, gunship + finish, gap clearability | `test_hull_run.gd` | ✅ |
| Campaign: Start → campaign; shooter phase; boarding dive transforms ship → mech on the roof without a scene change; resume at Stage 2 → escape → bike + 3D camera + roof blown; resume at Stage 3 → ending | `test_campaign_flow.gd` | ✅ |
| Stage 2 upgrades: appearing-block rhythm is clearable without falling, Heart/Energy Tanks, charge shot pierces, shield guard front block + back window, swooper dive/return, secret shaft reaches the Heart Tank, Sentinel room seals / resets on death / opens on victory | `test_stage2_upgrades.gd` | ✅ |
| Stage 4 (8-bit): NES-sized nearest-filtered screen, 3D off/on, playfield clamp, shots per weapon level, carrier capsule → power-up, damage + respawn at full health, fortress terrain solid, boss core only hurt when open → clear, campaign resumes at STAGE 4 | `test_retro_stage.gd` | ✅ |
| Warship: roof-deck start, hatch drops into the bay, checkpoints, gate lock → Reactor Core → escape, respawn, blast roof, core damage window | `test_warship.gd` | ✅ |

## Movement instrumentation (F3 debug panel)
- Ship: state, speed, time-to-max-speed, last dash distance, dash cooldown, invulnerability, last hit source + time.
- Mech (M5): run speed, jump apex, airtime, coyote use, buffered jump use, dash distance, landing recovery.
- Boss (M4/M7): attack selected, state transition reason.

## Visual pass 2 verification (latest)
- Collision: no Shape3D/hitbox/hurtbox values changed since the pre-pass baseline (`git diff bbcca39`);
  gameplay scripts (hurtbox, hitbox, health, movement, enemy stats) untouched.
- Resolutions 1920×1080, 1600×900, 1280×720: HUD margins scale proportionally (canvas_items + keep).
- Reduced flash: explosion region mean luminance 138 → 92 on the same frame.
- Busiest encounters (headless CPU, sandbox): Stage 2 dense waves avg 6.0 ms / peak 16.1 ms per frame;
  Forge Dreadnought avg 4.4 ms / peak 12.5 ms; peaks ≈1,050 nodes, 22 emitters, 59 projectiles.
  GPU cost must be measured on target hardware.
- Web build (Chromium, Compatibility renderer): title → start → gameplay → pause with zero console errors.
- Full-run bot: title → Stage 1 → Choir Engine → Stage 2 → Forge Dreadnought → title, zero errors.

## Campaign v3 verification (latest)
Scratch bots and captures (not committed):
- Full campaign flow (headless and rendered): title → shooter → boarding run → drop → platformer → escape →
  camera swing → hull run → ending → title, zero script errors.
- Warship bot: found a roof-running skip past the hatch (fixed with a bulkhead + gantry that also stops
  wall-climbing); intended route roof → hatch → interior → boss gate verified.
- Hull-run bot (steer around blocks/fences/blasts, jump walls/gaps, hold fire): finishes the faster
  3760-unit course in ~68 s taking 4 hits; the pad gap was widened after the bot fell short.
- Warship bot (boss- and block-aware): after the zone/mechanics pass it found the conveyor strips snagging
  the mech on the seam into the next floor block (fixed: conveyors became push areas over a continuous
  floor); full route to the boss gate in ~80 s. Hull-run bot with the warship hull in place: ~70 s.
- Ending capture: the first pass showed the dying ship with invisible blasts from 2.7 km — explosion scale
  and fires were raised until the whole ship reads as burning and breaking apart.
- Warship bot (boss-aware): roof → hatch → interior → Sentinel (beaten in ~30 s) → boss gate. A wall-kick
  bot reaches the secret Heart Tank in ~2 s; the first shaft design (single hanging pillar) was not
  climbable and became a two-wall shaft.
- Exported pack (`--main-pack build/web/index.pck`) and Chromium web build: found that binary scenes drop
  cross-instance NodePath overrides and non-editable child overrides — fixed (group lookups + `[editable]`);
  campaign, warship and hull run render with zero console errors.

## Full-run bot (manual tool)
A scratch bot (not committed) played Stage 1 → Choir Engine → Stage 2 → Forge Dreadnought → MISSION
COMPLETE → Stage 1 at 6× speed with zero engine errors. Recreate it when stage flow changes.

## Manual regression checklist
- [ ] Fresh run on keyboard.
- [ ] Repeat on controller.
- [ ] Decode each echo and replace it with each other echo.
- [ ] Spend energy at 0, 1, 2 and 3 segments.
- [ ] Die before and during both bosses.
- [ ] Pause during a projectile-heavy moment and during transformation.
- [ ] Skip transformation.
- [ ] Finish Level 1 with each echo; verify Level 2 receives it.
- [ ] Complete every critical jump without dash.
- [ ] Trigger each recovery volume.
- [ ] Reduced flash, no shake, high contrast, subtitles.
- [ ] Change resolution; verify HUD safe areas.
- [ ] Disconnect and reconnect the controller.
- [ ] Restart the run from the result screen.

### M1 ship-feel session (current graybox)
- [ ] 5 minutes in the Combat Test Room (F2 to switch rooms) on keyboard, then controller.
- [ ] Movement: starts quickly, stops with a short ease-out, never feels floaty or icy.
- [ ] Edges: ship slows into the boundary instead of slamming.
- [ ] Dash: direction matches stick; cooldown meter under the ship is readable; dash through a drone shot.
- [ ] Hold fire for 30 s — no mashing needed, no hand strain.
- [ ] Take hits: blink is visible, no instant double-hit, death → respawn in ~1.5 s with blink.
- Note any complaint with the telemetry numbers from F3.

## Playtest questions
- Could the player explain Echo Shift after the first carrier?
- Did the player notice that the module survived transformation?
- Which attacks caused damage without being understood?
- Did the player hoard energy? Why?
- Was the counter opportunity clear before the first failure?
- Did the mech feel like the same machine under gravity?
- Where did the player stop moving because the screen became noisy?
- Which deaths caused immediate retry, and which caused frustration?

## Definition of success
A new player completes both levels, can explain the Echo choice, recognizes that the carried module links
both genres, and remembers the transformation and at least one boss counter. Technically: clean launch,
state preserved through the genre transition, reliable checkpoint recovery, keyboard + controller,
readable combat, and three consecutive full runs without a crash or soft lock.
