# SHIFT//WING — Game Design

Working title: **SHIFT//WING: Echoes of Kharon** (production label only — trademark search required
before public release; alternatives: Echoframe, Wingbreaker, Nova Chassis, Starforge Shift, Project Kestrel).

## High concept
A courier pilot and a shape-shifting rescue craft enter a shattered orbital foundry to recover an
imprisoned machine intelligence. In space, the craft flies as a nimble interceptor that decodes enemy
attack patterns. After the orbital guardian falls, the station collapses toward the planet; the craft
transforms into a bipedal mech, carries its last decoded weapon into the foundry, and fights through
assembly lines to free the intelligence.

**Player promise:** steal an enemy's combat rhythm, weaponize it, and carry that power through a
spectacular transformation from starfighter to ground mech.

## Target experience
| Item | Target |
|---|---|
| Platform | Windows desktop first; keyboard + controller |
| Session | 10–15 min for the full slice |
| Camera | Fixed side view, orthographic |
| Presentation | Low-poly 3D on a constrained 2D gameplay plane |
| Difficulty | Forgiving first clear, optional score challenge |
| Performance | Stable 60 fps at 1080p on a mid-range PC |

## Scope
**In:** one shooter level + boss, one transformation sequence, one platformer level + boss, three
echo types, three enemy families shared across modes, one checkpoint between levels, title/pause/result
screens, short tutorial prompts, keyboard + gamepad, basic audio/particles/camera feedback,
accessibility toggles.

**Out:** online play, co-op, procedural generation, inventory, skill trees, branching story, multiple
playable characters, more than one save slot, mobile, large cinematic pipeline.

## Design pillars
1. **One machine, two genres.** Health, dash, fire, Echo Energy, the active module, enemy colors and
   threat indicators all survive the transformation. The player changes embodiment, not identity.
2. **Enemies are opportunities.** Every enemy is a threat, a score source and a possible echo:
   destroy it now, decode it, or save it?
3. **Spectacle with readable rules.** Big beams and transformations are fine; dangerous areas always
   get clear anticipation. Effects may exceed the visual budget only while input is locked or the
   player is invulnerable.
4. **Short, replayable mastery.** Replay comes from medals, micro-routes, no-hit bonuses, echo choices
   and faster boss kills — not filler.

## Core system: Echo Shift
Enemies with a glowing core can be decoded. Hold **Echo** while the target stays inside a tether cone.
The tether slows the player's fire rate. Completing the decode installs that target's echo.
Leaving range/angle, dashing, or taking damage interrupts the tether.

| Echo | Space form | Mech form | Best use | Trade-off |
|---|---|---|---|---|
| Burst | Three-round forward spread | Rapid arm cannon | General damage, small enemies | Weak vs armor |
| Arc | Electricity jumps between nearby targets (capped) | Short-range chain blaster that powers machinery | Crowds, puzzle switches | Limited reach |
| Guard | Small orbiting drone intercepts shots | Directional shield that reflects marked projectiles | Survival, counters | Lower damage |

Only one echo is active. Decoding a new one replaces the old module.

### Echo Energy (3 segments)
- **Tap Special (1 segment):** Echo Pulse — short defensive burst, behavior depends on module.
- **Hold Special (≥2 segments):** Resonance Beam — powerful forward attack.
- **All 3 during a boss telegraph:** Overdrive Counter — highest damage and score.

Energy comes from skilled play: full formations, damage-free decodes, reflected shots, exposed weak
points. Passive trickle only on Story difficulty.

### Originality guardrails
Echo Shift copies a behavior; it does not capture or retain the enemy. Avoid purple capture spheres,
fish-shaped enemies, the names Alpha/Beta Beam, copied enemy followers, and G-Darius power-up colors.

## Current build: stage flow, enemy roster, weapon drops (implemented)
Built ahead of the M2–M4 order at the user's request. Where it differs from the plan above, this section
describes what is actually in the game.

### Weapon drops (echo acquisition, v1)
Elite carriers (gold-white pulsing core with a concentric ring) drop a **weapon core** when destroyed.
Flying into it installs that echo weapon for a fixed number of shots; the HUD shows `NAME ×ammo`
(red when low). At zero ammo the ship reverts to the base gun. A new core replaces the current weapon.
Dying drops the weapon (Contra rule). The weapon carries between stages.

| Echo | Dropped by | Ship weapon | Shots |
|---|---|---|---|
| BURST | Gunship | 5-way spread | 140 |
| ARC | Tesla | Chain lightning: nearest enemy in reach, then up to 2 more nearby (no ammo spent without a target) | 110 |
| GUARD | Warden | Two orbiting orbs that destroy enemy bullets and fire alongside you | 180 |

The tether/decode interaction and the Echo Energy meter (Pulse, Resonance Beam, Overdrive Counter) are
still planned (M2); drops are the first acquisition path.

### Enemy roster (space)
| Enemy | Movement | Attack | Role |
|---|---|---|---|
| Drone | Sine drift | Straight shot | Basic fodder |
| Needle | Fast straight rows | None (contact) | Formation bonus target |
| Lancer | Swoop toward center and back | Diagonal pair | Lane pressure |
| Gunpod | Enters, parks, leaves | Aimed 3-round burst (barrel tracks you) | Priority turret (Contra-style) |
| Rammer | Approaches, telegraphs, locks on, charges | Body | Forces sidesteps |
| Gunship (elite) | Parks | 5-way aimed fan | Drops BURST |
| Tesla (elite) | Parks, wide bob | 5-round aimed burst | Drops ARC |
| Warden (elite) | Parks | 12-way radial ring, alternating gaps | Drops GUARD |

Every volley is preceded by a swelling telegraph flare. Whole formations destroyed award a
**formation bonus**; one escapee voids it.

### Stage structure (campaign v3 — seamless)
The whole run is one continuous world (`levels/campaign/campaign.tscn`): one camera, one sky, no loading between
stages. Score, echo weapon and SUPER energy carry across all three forms.
- **Stage 1 — Orbital Riptide** (side-view shooter, ~80 s of waves) → **The Choir Engine**. G-Darius-style
  depth: a real 3D world renders behind the play plane (`PerspectiveBackdrop`, SubViewport) and the camera
  flies through it — ringed planet, capital fleet and asteroids in open space → a space-station trench
  mid-stage (modules, arches) → a sunset cloud sea with spires for the boss. Zones blend sky and fog presets.
  Flat layers on top: capital-ship battle trading turbolaser fire, sun shafts. From ~16 s the real enemy
  warship (`WarshipModel`) cruises below the flight line in the backdrop — the destination.
- **Boarding run** (in-engine, letterboxed): the camera stays locked on the Kestrel while the backdrop
  cuts to open space, speeds up, and the warship rises in below the flight line until its deck fills the
  lower screen; the Kestrel races across, transforms above the roof and
  the **mech drops onto the hull** with the rest of the ship spreading out behind it.
- **Stage 2 — Warship Infiltration** (Mega Man X-style platformer): roof deck drop zone → entry hatch (a
  bulkhead + gantry block roof-running) → landing bay → pit run → electric corridor → tower climb → moving
  platforms over the reactor pit → crusher hall → **Bulkhead Sentinel** mid-boss room → elite guard +
  dash-jump gap → **Warship Reactor Core**. Five checkpoints; pits cost 1 HP. Secrets (Metroid layer): a
  wall-kick shaft above the high walkway leads to a hidden roof pocket with a **Heart Tank**; an **Energy
  Tank** floats above the vertical lift over the reactor pit. Platforming set pieces: **appearing blocks**
  over the foundry pit (on 1.8 s / off 1.4 s, staggered 0.8 s — flicker before vanishing), a **crumbling
  ledge** on the tower climb, **conveyor strips** dragging you back under the crushers.
  Art: eight colour zones (`WarshipZones`) — amber hangar with parked fighters and a gantry crane, molten
  foundry with vats pouring into the pit, electric-blue corridor with arcing tesla coils, teal lift shaft
  with moving counterweights, reactor column with spinning rings, red alarm hall with pistons, gold security
  bulkhead with the emblem, violet core approach. Each tints the walls and platforms, lights the play plane
  with accent pools and sets the depth-fog colour of the far layers. A secondary colour per zone drives neon
  bands, light strips, coloured light shafts and the big sector signs ("SECTOR 02 // FOUNDRY"); the key and
  rim lights shift toward the zone colours while inside. Plus the parallax back wall (windows,
  pipes, screens, fans, beacons, generators), mid-layer pillars/catwalks, foreground girders, steam, sparks.
- **Escape** (in-engine): slow motion, the arena roof blows out, the mech thrusts up to the top hull, turns into
  the bike, and the camera swings from the side view to a chase view behind it (ortho → matched-FOV
  perspective → orbit).
- **Stage 3 — Hull Run** (3D, camera behind the bike, ~50–55 s at 56–80 u/s): warm-up → blast field →
  **trench run** (walls with turrets) → burning deck with jump pads → **pursuit gunship** mini boss →
  **collapse run** (debris rains, the deck blows apart around you) → the bow. Explosions erupt along the
  route the whole way and intensify toward the bow. You ride the spine of the 3.6 km warship itself
  (`WarshipModel` at track scale): the hull, command islands, gun batteries and superstructure skyline spread
  out to both sides and drop away at the flanks, with fires and skyline explosions across it. Around it:
  ringed gas giant, red moon, the blue world below, capital ships fighting.
- **Ending**: the bike launches off the bow; the camera pulls far back to a three-quarter view of the whole
  burning warship, which explodes stern to bow and breaks into drifting sections → core flash → MISSION
  COMPLETE → title.
- Restart Stage resumes at the current stage inside the campaign. Standalone dev rooms (F2) exist for each
  stage: `orbital_riptide`, `warship_level`, `hull_run_level`, plus Foundry Descent.

### Mech (Stage 2)
Run, variable-height jump, **double jump**, coyote time + jump buffer, ground/air **dash** (dash + jump keeps
the dash speed for long gaps), wall slide + wall jump, hold-to-fire (echo weapons carry over and fire
forward), **charge shot** (keep holding fire: the buster keeps shooting while the cannon charges; release at
level 1 (0.75 s, 4 damage) or level 2 (1.6 s, 10 damage) for a piercing plasma ball — base buster only),
**SUPER** = Resonance Beam. Look: Mega Man X-style side profile (helmet with crest, visor and ear discs,
chest core, pauldron, buster forearm, chunky boots, twin-nozzle pack). Tuning: `player/mech/mech_tuning.tres`
(single jump ≈ 3 high / 6 wide, double ≈ 5.3 high / 10 wide, dash-jump ≈ 12 wide).

Ground enemies: Walker (patrols, turns at ledges, fires forward), Hopper (leaps at you), Turret (aimed
bursts), Flyer (sine hover, aimed shots), Shield Guard (Sniper Joe-style: front shield blocks shots, drops it
only to fire a 3-burst, turns slowly so jumping over opens its back), Swooper (hangs from the ceiling, dives
at you, climbs back), Elite Walker (drops BURST). All telegraph before firing.

Pickups: health capsule (+2), energy cell (+1 SUPER segment), **Heart Tank** (+1 max health for the run,
full refill), **Energy Tank** (SUPER fully charged).

### Bike (Stage 3, 3D)
Rides forward on its own (56 → 80 u/s ramp), steer across the 18-wide deck, hold down to brake. Jump + double
jump over walls and gaps, **boost** (Dash): speed + i-frames + ram, and steering while boosting does a
sidestep roll. Hold fire for fast twin cannons (bolts inherit the bike's speed) with aim assist and a gold
lock-on reticle on the assisted target; echo weapons carry over (BURST 5-way fan,
ARC strong homing, GUARD heavy twin bolts). SUPER fires the beam straight down the track.
Hazards: machinery blocks, low walls, flame vents, laser fences with one gap, blast zones that erupt when you
get close, deck gaps into the burning interior, falling debris (ring telegraph on the deck), sweeping low bars.
Enemies: Talon interceptors (dive in ahead, overtake from behind, or strafe across from the side; elite
variant), hull turrets,
pursuit gunship (lead-flies ahead, triple volleys, drops blast mines, calls fighters).
Tuning: `player/bike/hull_rider_tuning.tres`.

### SUPER (all forms)
Kills (and energy orbs on the hull run) charge three energy segments (600 kill value each). At 3 segments,
Special fires the **Resonance Beam**: a 1.2–1.6 s screen-length beam that deals continuous heavy damage,
erases enemy bullets and grants invulnerability while it fires.

### Bosses (implemented)
- **Bulkhead Sentinel** (80 HP, Stage 2 mid-boss): sealed room, both doors shut and the camera locks. Aimed
  volley (3 → 5 shots), leap onto your position with a floor shockwave both ways (jump it), telegraphed
  wall-to-wall dash (jump over). Dying resets the room; beating it opens the way and drops a Heart Tank.
- **Warship Reactor Core** (170 HP, Stage 2): Mega Man-style rhythm — its shield plates close while it
  attacks and open between attacks (the damage window; time the SUPER for it). Attacks: low sweep (jump),
  high sweep (stay low), double sweep, bullet ring with a gap, falling rain with floor markers, drone
  summons. A high ledge gives a better firing line but sits in the high-sweep lane.
Both follow `.claude/rules/bosses.md`: explicit states, health floors so phases cannot be skipped, breaks
that clear bullets and protect the player, no back-to-back attack repeats, slower first use.
- **The Choir Engine** (420 HP): fan volleys, rotating spiral with safe lanes, drone summons; phase 2 adds
  telegraphed lightning lanes and aimed bursts; phase 3 adds the Null Chorus (inward ring → core flare →
  three radial rings with a gap). One mask shatters per break. (Overdrive Counter beam contest: pending M2.)
- **Forge Dreadnought** (520 HP): phase 1 — destroy two tracking turrets while dodging broadside walls and
  rammer escorts; the core armor opens at the break; phase 2 — lightning lane sweeps, radial bursts;
  phase 3 — spiral + everything faster.

## Controls
| Action | Keyboard | Controller | Space | Mech |
|---|---|---|---|---|
| Move | WASD / arrows | Left stick / D-pad | Free movement on plane | Run, crouch |
| Fire | J / left mouse | Right trigger | Sustained primary fire | Sustained arm weapon |
| Jump / burst | Space | A / Cross | Short vertical dodge burst | Variable-height jump |
| Dash | K / Shift | B / Circle | Fast directional evade | Ground or air dash |
| Echo | L / right mouse | Left trigger | Tether and decode | Tether weakened enemies / power nodes |
| Special | I / Q | Right bumper | Pulse / Resonance Beam | Module special / Resonance |
| Pause | Escape | Start | Pause | Pause |

Rules: hold-to-fire (no mashing); gameplay references input actions only; both modes share Fire, Dash,
Echo and Special; aim is always forward (no twin-stick); rumble optional, moderate by default.

## Level 1 — Orbital Riptide (6–7 min)
Setting: the broken Kharon Ring around a blue gas giant. Strong parallax (fast wreckage, slow ring,
near-static planet). Warm orange enemy cores against teal space and violet shadows. Player ship
**Kestrel**: broad white-and-blue silhouette, central gold canopy, two oversized wing blocks.

| Beat | Time | Content | Teaching goal |
|---|---|---|---|
| Arrival | 0:00–0:35 | Safe flight, three drone targets | Move and fire |
| Needle formation | 0:35–1:15 | Burst enemies in clear rows | Read formations |
| Broken gantry | 1:15–2:00 | Debris lanes, first dash gate | Dash through danger |
| Echo specimen | 2:00–2:45 | Isolated Burst carrier, generous tether | Decode an enemy |
| Crossfire garden | 2:45–3:45 | Burst + Guard enemies, optional high lane | Replace or retain an echo |
| Reactor trench | 3:45–4:45 | Narrow space, Arc chains, destructible conduits | Module utility |
| Quiet threshold | 4:45–5:10 | Energy refill, boss silhouette, no combat | Anticipate boss |
| Boss | 5:10–7:00 | The Choir Engine | Prove mastery |

**Ship movement:** free movement inside a soft camera boundary; quick (not instant) acceleration with a
short ease-out; dash ≈0.18 s with a small invulnerability window; hit volume smaller than the visible
ship but not dishonestly tiny; background scroll independent of enemy motion.

**Enemies (data-authored waves):** Needles (rows, straight shots after a wing flash), Lancers (shallow
sine, paired diagonal shots), Wardens (shield, carry Guard), Conduits (stationary, overloaded by Arc),
Collectors (steal dropped energy fragments). A returning wave gets one modifier; never introduce a new
enemy and a new hazard at the same time.

**Micro-route (2:45):** upper = tighter, Guard carrier, more score rings; lower = easier, Burst carrier.
Rejoin after ~35 s.

**Scoring:** fixed points per enemy; 2× for complete formations; decode = points + energy fragment;
no-hit encounter bonus; capped Resonance multi-kill multiplier; large boss-counter bonus; end medal
Bronze / Silver / Gold / Prism.

### Boss 1 — The Choir Engine
Circular foundry guardian that unfolds into three rotating masks (Burst, Arc, Guard); its shapes preview
the mech's head and shoulders. Tests positioning, dash timing, echo choice, prioritization, Resonance timing.
- **Phase 1 Listen:** fan volley; rotating safe lane; two weak drones (decodable as Burst); a mask is
  exposed after each attack.
- **Phase 2 Answer:** Arc satellites with telegraphed lightning lines; Guard plates block frontal fire
  until side nodes die; a Guard carrier offers a safer, slower strategy. Attacks overlap only after each
  has appeared alone.
- **Phase 3 Counterpoint:** Null Chorus charge with a 3-step telegraph (desaturation → inward rings →
  white core flare). Dodge through a narrow lane, or spend 3 segments on Overdrive Counter: a 2-second
  beam contest based on alignment + holding Fire (no mashing). Success breaks the masks; failure deals
  heavy but non-lethal damage on Normal.

## Transformation bridge (12–15 s)
The dying Choir Engine tears the station open; Kestrel dives through the breach. Wings rotate into
shoulders, nose splits into legs, cockpit becomes the chest. Input locks only for the first few seconds.
The active echo visibly moves from the ship core to the mech arm; the player lands, can run immediately,
and fires the same module at a harmless target. Implemented as a dedicated scene with a pre-authored
animation; ship and mech controllers stay separate scenes.

## Level 2 — Foundry Run (6–8 min)
A giant automated factory descending toward the planet: conveyors, stamping pistons, molten channels,
assembly arms. Palette: warm coral metal, dark navy machinery, turquoise friendly energy, yellow interactables.

| Beat | Time | Content | Teaching goal |
|---|---|---|---|
| Hard landing | 0:00–0:40 | Safe run, low obstacles, one target | Run and fire |
| Lift shaft | 0:40–1:30 | Platforms, buffer-friendly gaps | Jump and fall |
| Assembly line | 1:30–2:30 | Basic walkers, conveyor belts | Shoot while moving |
| Compression hall | 2:30–3:25 | Telegraphed pistons, dash gaps | Dash under pressure |
| Echo workshop | 3:25–4:25 | Arc door, Guard reflection, optional Burst route | Module utility |
| Pursuit | 4:25–5:30 | Autoscrolling collapse, forgiving recovery | Combine movement |
| Core vestibule | 5:30–5:50 | Checkpoint, quiet reveal | Boss anticipation |
| Boss | 5:50–7:50 | Forge Regent | Master mech verbs |

**Mech movement:** fast ground accel, stronger decel; variable jump (release cuts upward velocity);
higher fall gravity; coyote time + jump buffer; one air dash refreshed on landing; forgiving step-up;
controlled knockback with brief input lock (no stun chains). Physics-tick movement on the side-view plane.

**Mech combat:** always fires forward; firing in air slightly slows horizontal accel, never freezes.
Burst arm = rapid shots, breaks brittle armor. Arc arm = short chain, powers machinery, stuns small robots.
Guard arm = held shield, reflects white-ring projectiles, slow energy drain. Dash contact = shoulder bash.

**Hazards:** conveyors change ground velocity, never jump impulse; pistons show floor shadow + warning lamp;
molten pits return you to the last safe ledge and cost health; debris marks impact zones first; moving
platforms follow short, predictable loops.

**Checkpoints:** after the transformation and before the second boss. Death restarts fast, restores base
health, keeps the module held at checkpoint activation, resets score to the checkpoint snapshot. A
separate "Restart run" supports score attempts.

### Boss 2 — Forge Regent
Quadrupedal construction machine building copies of itself; fabricator head, two stamping arms,
detachable crawler legs; three broad platforms over a reactor channel.
- **Phase 1 Production Test:** floor stamp, arm sweep, two walkers. Big floor markers; damage window after every attack.
- **Phase 2 Reconfiguration:** center platform lowers, sides move. Adds a Guard-reflectable projectile,
  an Arc-powered exposed cable, and Burst-breakable brittle armor. Every module helps; none is mandatory.
- **Phase 3 Meltdown:** destroy three anchors while the arena scrolls right. The last anchor fills the
  final energy segment; Resonance Beam cuts through the unfinished shell and ends the fight.

## Narrative
- **Mara Venn** — courier pilot, practical, dryly funny. Portraits + short voice lines.
- **Kestrel** — adaptive rescue craft. Tones and on-screen glyphs.
- **ECHO-9** — imprisoned machine intelligence, broken transmissions.
- **The Foundry** — antagonist system that treats every pattern as raw material.

Arc: distress signal → Foundry attacks → Choir Engine reveals decoding → ring destabilizes → transform,
carry module inward → defeat Forge Regent → ECHO-9 freed, detects more foundries (expansion hook).
Dialogue never interrupts combat; subtitles on by default; replay from pause menu.

## Accessibility and options
Hold-to-fire default; full rebinding; separate music/SFX/dialogue sliders; subtitles with speaker labels;
reduced shake; reduced flash; high-contrast projectiles; toggle-or-hold Echo tether; Story/Arcade
difficulty; Story auto-refill of Resonance; optional tether aim assist; pause everywhere.

## Balance starting points (hypotheses, tune in playtests)
| Variable | Initial value |
|---|---|
| Player max health | 5 hits |
| Dash cooldown | 0.75 s |
| Dash invulnerability | 0.12 s |
| Echo tether | 0.8 s basic / 1.3 s elite |
| Energy capacity | 3 segments |
| Pulse / Resonance min / Overdrive | 1 / 2 / 3 segments |
| Mech coyote / jump buffer | 0.10 s / 0.12 s |
| Boss phase length | 30–45 s |
| Checkpoint reload | < 3 s |

Tune one family at a time.

## Milestones
Build prompts from the plan map onto milestones as shown. One milestone per session; commit after its checks pass.

| Milestone | Prompts | Output | Exit gate | Status |
|---|---|---|---|---|
| M0 Foundation | 0 | Bootable project, input, session, HUD | Clean launch and scene transition | Done |
| M1 Ship feel | 1, 2 | Ship movement, fire, dash, damage; shared combat contract | 5-min movement/combat test without control complaints | Graybox done — needs playtest |
| M2 Echo lab | 3 | Three ship echoes and energy | Replacement and persistence tests pass | Echo weapons via elite drops done; tether decode + energy meter pending |
| M3 Space graybox | 4 | Full pre-boss level | Complete start-to-boss run | Done (Stage 1 + Stage 2 wave scripts) |
| M4 Space boss | 5 | Choir Engine | All phase and checkpoint tests pass | Done without Overdrive Counter; Forge Dreadnought added |
| M5 Transformation | 6 | Cinematic bridge and mech movement | State carries correctly between modes | |
| M6 Ground graybox | 7 | Full pre-boss platform level | All critical jumps and hazards pass | |
| M7 Ground boss | 8 | Forge Regent and ending | Complete two-level run | |
| M8 Art/audio | 9 | Original low-poly art and feedback | Readability review and stable performance | Visual pass v1 pulled forward (procedural models, VFX, backdrop); audio + final art pending |
| M9 RC | 10 | Settings, accessibility, bug fixes, export | Three clean full runs on target hardware | |

**Cut order if time slips:** optional route → Collector enemy → pursuit complexity → advanced score
bonuses → secondary boss attacks → nonessential cinematics. **Never cut:** movement feel, telegraphs,
checkpoints, Echo carry-over.

## Inspiration boundary
Borrow principles only. Do not copy G-Darius enemy/boss designs, aquatic-machine silhouettes, stage
layouts, names, UI, sounds, music, scoring tables, Alpha/Beta terminology or capture presentation; Split
Fiction characters, premise, co-op puzzles, set pieces, dialogue or ability combos; Brawl Stars characters,
1:1 proportions, models, textures, animations, icons, UI layout, logos, sounds or branded palette.
