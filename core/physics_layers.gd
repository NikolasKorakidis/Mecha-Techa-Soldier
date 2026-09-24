class_name PhysicsLayers
extends RefCounted
## Bit values for the named 3D physics layers in project.godot.

const WORLD := 1
const HURTBOX := 2
const HITBOX := 4
## Character bodies (mech, bike, walkers): collide with WORLD only, never with each other.
const ACTOR := 16
