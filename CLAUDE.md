# Echoes of Kharon: Definite Space Saga repository instructions

## Product
Build a 10–15 minute Godot 4 vertical slice with two modes:
1. 2.5D horizontal shooter (Level 1 — Orbital Riptide, boss: Choir Engine).
2. 2.5D action platformer after a ship-to-mech transformation (Level 2 — Foundry Run, boss: Forge Regent).

The shared signature system is Echo Shift: Burst, Arc, and Guard modules persist across the
transformation. Design source of truth: `docs/game-design.md`.

## Stack
- Godot 4.7 stable (project `config/features` = 4.7).
- GDScript with static typing where it improves clarity.
- Desktop Windows target first; macOS is used for development too.
- 3D presentation constrained to the side-view gameplay plane (Z = 0) for Stages 1–2; Stage 3 (hull run)
  is a full 3D chase view behind the bike. All stages live in one continuous campaign scene.

## Commands
Exact executable paths per machine live in `docs/local-setup.md`. With `GODOT` pointing at the binary:
- Import check: `$GODOT --headless --path . --import`
- Tests: `$GODOT --headless --path . --script res://tests/run_tests.gd`
- Boot check: `$GODOT --headless --path . --quit-after 180`

Before completing a task, run the import check, the tests, and the boot check.
Report commands run and their results. Any `SCRIPT ERROR`, `Parse Error` or `ERROR:` line is a failure.

## Architecture
- Composition over deep inheritance.
- Separate ShipPlayer and MechPlayer scenes.
- Shared run state lives in the `RunSession` autoload; level changes go through `SceneRouter`.
- Tunable gameplay data lives in custom Resources (`*.tres`), not scattered constants.
- Signals notify; direct/exported references serve required local dependencies; groups for broad queries.
- UI never owns gameplay state. HUD reads `RunSession` signals only.
- Projectiles do not route scenes or update HUD directly.
- Damage flows Hitbox → Hurtbox (team filter) → HealthComponent. See `docs/architecture.md`.

## Scope
Implement only the requested vertical slice milestone (see `docs/game-design.md` → Milestones).
Do not add multiplayer, procedural generation, inventory, skill trees, networking, or save slots.
Prefer the smallest complete vertical slice over broad unfinished systems.
Do not build a universal ability/effect framework for three modules.

## Code quality
- Keep scripts focused; split files that mix unrelated responsibilities.
- Use descriptive names and typed signals.
- Avoid magic node paths; use exported references or `%UniqueName` nodes.
- Avoid silent fallbacks that hide broken scene wiring — `push_error` instead.
- Add comments only for non-obvious intent.
- Gameplay scripts reference input actions, never physical keys.

## Workflow
1. Inspect relevant files before proposing changes.
2. State a short plan and acceptance criteria.
3. Implement one vertical slice at a time.
4. Run checks and inspect Godot errors.
5. Summarize changed files, proof, and remaining risks.

## Git
- Never discard user changes.
- Keep commits small and single-purpose.
- Do not commit `.godot/`, secrets, editor caches, or local paths.
- Stop and ask if unrelated changes are present in files that must be edited.

## Definition of done
A feature is done only when it is playable from the normal scene flow (Main), has no new errors
in the import/boot checks, and its acceptance tests pass.

## Scoped rules
- Player controller work: `.claude/rules/player.md`
- Boss work: `.claude/rules/bosses.md`
