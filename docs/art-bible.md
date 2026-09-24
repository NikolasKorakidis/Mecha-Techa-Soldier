# SHIFT//WING — Art Bible

Style name: **chunk-tech diorama** — toy-like clarity, original shapes, no imitation of any commercial
character design.

## Form
- **Characters:** oversized hands, shoulders, engines and weapons; compact torsos; readable front/back.
- **Geometry:** low-to-medium polycount, broad planar faces, bevels that catch light, few tiny greebles.
- **Materials:** one main color, one shadow color, one accent, one emissive channel per unit.
- **Textures:** flat colors, gradients, masks, sparse decals. No noisy photo textures.
- **Lighting:** cool key, warm rim, soft ambient fill, restrained bloom.
- **Camera:** orthographic (or mild perspective), stable framing, limited shake.
- **Animation:** exaggerated anticipation, fast action, short settle. Pose clarity over realism.
- **UI:** rounded rectangles and wedge motifs derived from Kestrel's wing silhouette.

## Gameplay color language
Color alone is never enough — every state also gets a shape, motion or audio cue.
These colors do not change between levels. Source of truth in code: `core/palette.gd`.

| Meaning | Color | Hex (graybox) | Additional cue |
|---|---|---|---|
| Player / friendly | Cyan-blue | `#3FC8FF` | Rounded shapes |
| Standard enemy | Coral-red | `#FF5A4E` | Angular shapes |
| Echo carrier | Gold-white core | `#FFE08A` | Pulsing concentric ring |
| Enemy projectile | Hot magenta | `#FF2FB4` | Dark outline and glow |
| Friendly projectile | Cyan or module color | `#9FF3FF` | Bright center streak |
| Interactable machinery | Yellow | `#FFD23F` | Wrench glyph |
| Health | Green | `#52E07A` | Cross / segment shape |
| Resonance energy | Violet | `#A77BFF` | Three diamond segments |
| Imminent danger | White → red | `#FFFFFF`→`#FF3030` | Audio chirp + expanding marker |

Level palettes:
- **Orbital Riptide:** teal space, violet shadows, warm orange enemy cores, blue gas giant.
- **Foundry Run:** warm coral metal, dark navy machinery, turquoise friendly energy, yellow interactables.

## Model budget
- Kestrel ship and mech share visible wing, cockpit and core motifs (white/blue body, gold canopy, cyan core).
- Each enemy family has a space shell and a ground chassis around a shared glowing core.
- Bosses reuse shader families and effect primitives, not silhouettes.
- Environment kits: repeated beams, panels, pipes, rails, machinery blocks.
- Iteration speed outranks premature draw-call optimization.

## Effects budget
- Primary shots: small core + short trail.
- Enemy warning: one clean flash before emission.
- Hits: directional spark; tiny freeze frame on strong impacts only; damage numbers off by default.
- Dash: tapered afterimage, brief silhouette squash.
- Decode: tether line, target ring, progress travelling toward the player.
- Resonance: strong core beam, softer outer glow, screen desaturation, limited shake.
- Transformation: mechanical trails and silhouette changes; no full-screen particle fog.

## Audio direction
Bright synth percussion + mechanical found-sound. Space music wide and rhythmic; the foundry reuses the
melody with heavier drums and metallic pulses. Functional layers: enemy pre-fire chirp; distinct player-hit
vs shield-hit; tether start/progress/success/interrupt; energy segment gained; boss counter opportunity;
jump, dash, landing, low-health. No copyrighted samples; no imitation of Darius, Split Fiction or Brawl Stars audio.
