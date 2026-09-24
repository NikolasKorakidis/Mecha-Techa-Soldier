---
paths:
  - "enemies/bosses/**"
  - "directors/boss_director.gd"
---
# Boss rules

## State model
Explicit finite states only: `INTRO → PHASE_1 → BREAK_1 → PHASE_2 → BREAK_2 → PHASE_3 → DEFEATED`.
Transitions cannot skip or repeat; log every transition with its reason for the debug panel.

## Attack scheduling
- Each phase selects from a small legal attack set with cooldown rules.
- Random order is allowed; prohibited back-to-back combinations are not.
- A new attack first appears alone; overlaps only after each part was seen separately.
- The first use of an attack is slower than later uses.

## Fairness
- Every attack has a unique wind-up silhouette and sound.
- The boss cannot collide with the player during a cinematic camera move.
- Phase transitions grant brief player invulnerability and clear hostile bullets.
- Weak points use shape and motion in addition to color.
- Never hide a lethal projectile behind the boss's own large effects.
- Beam contests use alignment + holding Fire, never rapid tapping.
- When cutting, remove an overlapping attack before shortening a warning.

## Debug commands (required per boss)
Jump to any phase; show current state and attack; force the counter opportunity; toggle player
invulnerability; reset the encounter.

## Design order
List the player skills being tested first, then design attacks for those skills, then decorate.
