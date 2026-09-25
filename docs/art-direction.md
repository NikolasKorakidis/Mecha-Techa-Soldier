# SHIFT//WING — Art Direction: "chunk-tech arcade"

Colorful, clean, chunky and readable. Big recognizable silhouettes, beveled-looking planes, toy-like
clarity. Dark navy space so gameplay colors dominate. Original shapes only — no imitation of any existing
game's characters, UI or rendering.

The game is **2.5D**: low-poly 3D models on one gameplay plane (Z = 0) seen by a fixed orthographic
camera. All art is procedural (primitives + shaders) so it also runs on the web Compatibility renderer.

Source of truth in code: `core/palette.gd` (colors) and `core/art_style.gd` (tokens below).

## Palette
| Role | Hex | Use |
|---|---|---|
| Background deep navy | `#050A1E` | Base of every space scene |
| Background blue | `#081B33` | Nebula mid-tones |
| Background violet | `#24114A` | Nebula accents, shadows |
| Player primary | `#EEF5FF` | Kestrel fuselage |
| Player secondary | `#268DFF` | Wing blocks, player UI edge |
| Player energy | `#33E2FF` | Engines, edge accents, player shots |
| Player gold accent | `#F6C84A` | Cockpit, trim |
| Enemy coral | `#ED6570` | Enemy armor (all enemies) |
| Enemy dark red | `#6D233D` | Enemy undersides, armor plates |
| Echo gold | `#FFE36A` | Echo carrier cores, orbiting fragments, weapon cores |
| Hostile projectile | `#FF3CA6` | Every bullet that can hurt the player — nothing else uses it |
| Resonance violet | `#9D5CFF` | Energy diamonds, Arc lightning, special attacks |
| Health green | `#52E686` | Health segments only |
| UI dark panel | `#081326` | HUD and menu panels |
| UI muted text | `#AFC5D8` | Captions, secondary labels |

Weighting: backgrounds ≈ 70% of the frame and stay under ~35% brightness; player cyan/white and enemy
coral carry the mid-tones; magenta, gold and violet are reserved accents.

## Shape language
- **Player:** rounded-forward, white + blue, cyan accents, gold cockpit; points right.
- **Enemies:** angular, coral with dark-red undersides, point left. Every enemy has a readable "face"
  (sensor/core) on the camera side.
- **Echo carriers (elites):** gold-white core **plus** orbiting gold fragments, a slow pulsing ring and a
  faint vertical beacon — never color alone.
- **Bosses:** large silhouettes, same materials as their family, violet/gold accents for weak points.

## Style rules
| Rule | Value (`ArtStyle`) |
|---|---|
| Outline | Dark inverted-hull shell `#02040D`, 0.07 (heroes/elites) / 0.045 (small units); backgrounds have none |
| Shading | Toon diffuse + rim light; upper faces lighter, undersides use the family's shadow color |
| Glow | Subtle 0.7 (background accents) · Standard 1.6 (engines, cores, shots) · Hot 2.6 (echo cores, special, explosion first frames) |
| Glow placement | Only energy cores, engines, projectiles, echo objects, major effects. Never backgrounds, never UI |
| Projectile brightness | Core 2.4 (solid, always brighter than trail) · trail 1.4; trails sit behind the core in Z |
| Shadow colors | Neutral `#02040D`, player `#123A78`, enemy `#3A1024` |
| UI corners | 8 px radius, 0.22 skew wedge on cluster panels (Kestrel wing motif) |
| Panel opacity | 0.78 over gameplay; menu scrim 0.6 |
| Panel edges | 3 px bottom edge: cyan (player/status), gold (score), red (boss/danger) |
| Typography | Caption 18 · body 24 · value 40 · title 64 · banner 92 (at 1080p); outline on all in-world text |
| Animation | Fast 0.12 s (hits, pips) · medium 0.25 s (UI transitions) · slow 0.5 s (banners, pulses) |
| Anticipation | Every hostile attack shows a telegraph ≥ 0.3 s before the projectile exists |

## Camera shake limits
| Event | Trauma |
|---|---|
| Basic player bullets | none |
| Basic enemy destroyed | 0.06 |
| Elite destroyed | 0.22 |
| Player damaged | 0.4 |
| Major attack / beam strike | 0.45 |
| Boss destroyed | 0.6 |
| Cap on accumulated trauma | 0.8 |

Offset = max offset × trauma². Offsets move the view only (never the play rect). Reduced-shake scales
all impulses to 15%; reduced-flash scales full-screen flashes and high-intensity pulses to 30%.
The HUD lives on its own CanvasLayer: it never shakes and never glows.

## Depth layers (far → near)
1. Distant stars — tiny, dim, slowest.
2. Nebula — broad blue/violet, soft edges, near-static.
3. Orbital structures — dark silhouettes (ring, antennae, rails, station sections).
4. Midground wreckage — recognizable panels, beams, solar fins, pipes; slow rotation.
5. Foreground — rare large dark silhouettes along the top/bottom edge, fastest.
The planet is the compositional anchor: lower-right, rim-lit, broad cloud bands, barely moving.

## Readability checks (every visual change)
- Grayscale screenshot: player, enemies, elites, hostile bullets still distinguishable.
- Hostile magenta visible over navy, violet, black and the planet.
- Verify in the **web build** (Compatibility renderer) — glow behaves differently there.

## Accessibility
| Option (Settings → Options, pause menu or title) | Effect |
|---|---|
| Reduced flash | Explosion/muzzle/impact/collect flashes, enemy hit overlay, player hit tint, elite ring pulse, WARNING pulse, distant blasts scaled to ~30%; fireball dimmed |
| Reduced camera shake | All camera impulses scaled to 15% |
| Reduced menu motion | No menu slides/scales, no title prompt pulse |
| Glow | Environment glow on/off |
| High graphics (desktop only) | Key-light shadows, SSAO, 4x MSAA, ~1.75x effect particles; hidden on web/mobile |
| Tutorial cards | Contextual tutorial cards on/off |
Settings persist in `user://settings.cfg`; a missing or incompatible file loads defaults.

## Implementation map (visual pass 2)
| Piece | Where |
|---|---|
| Palette, style tokens | `core/palette.gd`, `core/art_style.gd` |
| Outline shells (scaled back-face copies) | `ModelKit.with_outline()` / `hull()` in `art/models/model_kit.gd` |
| Kestrel (part groups, recoil, sputter, breakup) | `art/models/kestrel_model.gd`, `vfx/fragment_burst.gd`, `vfx/afterimage.gd` |
| Enemy family + echo carrier marker | `art/models/enemy_model.gd`, `vfx/core_collapse.gd`, `vfx/muzzle_flash.gd` |
| Projectile visuals | `vfx/projectile_visual.gd` (player / burst / orb / hostile / heavy) |
| Five-layer backdrop, planet, authored moments | `levels/shared/space_backdrop.gd`, `art/shaders/gas_giant.gdshader` |
| Hit stop, directional sparks, collect burst | `core/hit_stop.gd`, `vfx/impact_spark.gd`, `vfx/collect_burst.gd` |
| HUD, tutorial card, toasts | `ui/hud/`, `ui/tutorial/tutorial_card.gd`, `ui/stage/stage_ui.gd`, `ui/ui_style.gd` |
| Pause menu, title card, options | `ui/pause/`, `ui/title/`, `ui/menus/` |

## Visual test room (debug builds only; F2 to reach it)
`levels/test_rooms/visual_test_room.tscn` — enemy lineup (regular row + echo carriers), plus:
`1-8` spawn enemy · `0` clear · `9` lineup · `Z` damage player · `X` refill health · `C` refill energy ·
`V` cycle echo · `B`/`Y` explosion small/big · `N` impact sparks · `M` lightning lane · `P` projectile
samples · `U` weapon cores · `G` glow · `R` reduced flash · `T` reduced shake · `H` debug labels ·
`F1–F5` toggle background layer · `Esc` pause. Overlay shows FPS, active emitters and node count.

## Before / after
`docs/reference/current/` (before) and `docs/reference/after/` hold matching screenshot sets.
