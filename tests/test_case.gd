class_name TestCase
extends Node
## Base class for headless tests. The runner creates a fresh instance per test method,
## adds it to the tree, resets RunSession, awaits the method, then frees the instance
## (and every node added with add_autofree).

var failures: PackedStringArray = []


func add_autofree(node: Node) -> Node:
	add_child(node)
	return node


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s (expected %s ± %s, got %s)" % [message, expected, tolerance, actual])


func wait_physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func wait_process_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## Records emissions of a signal so tests can count them.
class SignalSpy:
	extends RefCounted
	var calls: Array = []

	func _init(sig: Signal) -> void:
		sig.connect(_record)

	func _record(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
		calls.append([a, b, c])

	func count() -> int:
		return calls.size()
