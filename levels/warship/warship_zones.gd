class_name WarshipZones
extends RefCounted
## Stage 2 colour zones: each section of the warship has its own accent light, wall tint and
## depth-fog colour so the level reads as distinct places (hangar, foundry, arc corridor, lift
## shaft, reactor, alarm hall, security bulkhead, core approach). Shared by the backdrop, the
## zone set pieces and the platform light strips.

## [x_start, name, accent, fog]
const ZONES := [
	[-200.0, &"hangar", Color(1.0, 0.64, 0.3), Color(0.16, 0.1, 0.07)],
	[33.0, &"foundry", Color(1.0, 0.42, 0.16), Color(0.2, 0.07, 0.04)],
	[92.0, &"arc", Color(0.5, 0.62, 1.0), Color(0.07, 0.07, 0.2)],
	[126.0, &"shaft", Color(0.3, 1.0, 0.72), Color(0.03, 0.13, 0.12)],
	[167.0, &"reactor", Color(0.4, 0.85, 1.0), Color(0.04, 0.12, 0.2)],
	[200.0, &"alarm", Color(1.0, 0.22, 0.2), Color(0.18, 0.03, 0.05)],
	[245.0, &"security", Color(1.0, 0.78, 0.32), Color(0.16, 0.11, 0.04)],
	[272.0, &"core", Color(0.68, 0.42, 1.0), Color(0.1, 0.05, 0.2)],
]


static func index_at(x: float) -> int:
	var found := 0
	for i in ZONES.size():
		if x >= ZONES[i][0]:
			found = i
	return found


static func name_at(x: float) -> StringName:
	return ZONES[index_at(x)][1]


static func accent_at(x: float) -> Color:
	return ZONES[index_at(x)][2]


## Fog colour blended across a short band at each zone border (no hard pops while scrolling).
static func fog_at(x: float) -> Color:
	var i := index_at(x)
	var color: Color = ZONES[i][3]
	if i + 1 < ZONES.size():
		var next_x: float = ZONES[i + 1][0]
		var t := clampf((x - (next_x - 8.0)) / 16.0, 0.0, 1.0)
		color = color.lerp(ZONES[i + 1][3], t)
	if i > 0:
		var start: float = ZONES[i][0]
		var t := clampf((start + 8.0 - x) / 16.0, 0.0, 1.0)
		color = color.lerp(ZONES[i - 1][3], t * 0.5)
	return color


## Wall panel tint: the dark base nudged toward the zone accent.
static func tint(base: Color, x: float, amount: float = 0.14) -> Color:
	return base.lerp(accent_at(x) * Color(0.35, 0.35, 0.35), amount * 2.0)
