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
| Wave timing uses elapsed time consistently | M3 | ⬜ |
| Boss transitions cannot skip or repeat illegally | M4 / M7 | ⬜ |
| Save data loads defaults when absent or incompatible | M9 | ⬜ |

## Movement instrumentation (F3 debug panel)
- Ship: state, speed, time-to-max-speed, last dash distance, dash cooldown, invulnerability, last hit source + time.
- Mech (M5): run speed, jump apex, airtime, coyote use, buffered jump use, dash distance, landing recovery.
- Boss (M4/M7): attack selected, state transition reason.

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
