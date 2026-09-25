class_name RetroTimeline
extends RefCounted
## Stage 4 script (seconds from the start): open space → asteroid belt → fortress corridor →
## boss. Authored like a Famicom shooter: fixed waves, no randomness in what spawns.

const E := RetroEnemy.Kind

## [time, event, params]
const EVENTS := [
	[2.5, &"drones", {"count": 5, "y": 70.0}],
	[5.0, &"drones", {"count": 5, "y": 160.0}],
	[8.0, &"darts", {"ys": [60.0, 120.0, 180.0]}],
	[10.5, &"drones", {"count": 6, "y": 115.0, "carrier": true}],
	[14.0, &"pod", {"y": 60.0}],
	[14.0, &"pod", {"y": 180.0}],
	[17.0, &"darts", {"ys": [50.0, 90.0, 150.0, 190.0]}],
	[19.5, &"drones", {"count": 6, "y": 80.0}],
	[20.5, &"drones", {"count": 6, "y": 160.0, "carrier": true}],
	[24.0, &"banner", {"text": "ASTEROID BELT"}],
	[24.5, &"rocks", {"count": 3}],
	[27.0, &"rocks", {"count": 4}],
	[28.5, &"pod", {"y": 120.0}],
	[30.5, &"rocks", {"count": 4}],
	[32.0, &"heavy", {"y": 110.0}],
	[33.5, &"rocks", {"count": 3}],
	[35.0, &"drones", {"count": 6, "y": 60.0, "carrier": true}],
	[37.0, &"rocks", {"count": 5}],
	[39.0, &"darts", {"ys": [70.0, 110.0, 150.0, 190.0]}],
	[41.0, &"heavy", {"y": 170.0}],
	[44.0, &"banner", {"text": "FORTRESS ZONE"}],
	[45.0, &"terrain", {}],
	[49.0, &"drones", {"count": 5, "y": 120.0}],
	[53.0, &"darts", {"ys": [100.0, 140.0]}],
	[56.0, &"heavy", {"y": 120.0}],
	[60.0, &"drones", {"count": 6, "y": 110.0, "carrier": true}],
	[64.0, &"pod", {"y": 100.0}],
	[64.0, &"pod", {"y": 150.0}],
	[68.0, &"darts", {"ys": [90.0, 120.0, 150.0]}],
	[72.0, &"heavy", {"y": 125.0}],
	[76.0, &"drones", {"count": 6, "y": 125.0}],
	[82.0, &"warning", {}],
	[85.0, &"boss", {}],
]

## Fortress terrain per 16 px column (tiles of height), ceiling and floor.
const CEILING := "0011122223322211112222333322221111222233332222111122223333222211112223332222111100000000"
const FLOOR := "0011122223333221111222233334433322211112223333222211122233334444333221111222333222111100000000"
## Terrain turrets: [column, on_ceiling].
const TURRETS := [
	[9, false], [14, true], [21, false], [27, true], [33, false], [38, true], [44, false],
	[50, true], [56, false], [61, true], [67, false], [72, true], [78, false],
]
const TILE := 16.0
