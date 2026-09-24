---
paths:
  - "player/**"
  - "combat/weapons/**"
---
# Player controller rules

- ShipPlayer and MechPlayer are separate scenes and scripts. Share components and `RunSession`, not controllers.
- Keep movement (`*_movement.gd`) separate from weapon behavior (`combat/weapons/`).
- All movement runs in `_physics_process` and stays on the Z = 0 plane.
- Read input through actions (`move_left`, `fire`, `dash`, ...) only — never keycodes.
- Tunables live in the tuning Resource (`ship_tuning.tres`, later `mech_tuning.tres`). No magic numbers in scripts.
- Small explicit state enums only: Ship `CONTROL, DASH, HIT, DISABLED, CINEMATIC`;
  Mech `GROUND, AIR, DASH, HIT, DISABLED, CINEMATIC`. Animation state is driven separately.
- Player health authority is the player's `HealthComponent`; it mirrors into `RunSession`. HUD never reads the player.
- Every feel change must keep the debug telemetry lines (`get_debug_lines()`) accurate.
- Tune one family of values per pass (e.g. dash only) and note the before/after numbers in the commit.
- Hold-to-fire is the default. Never require button mashing.
