extends Node
## Player options, persisted to user://settings.cfg. Missing or unreadable files load defaults.

signal changed

const PATH := "user://settings.cfg"
const VERSION := 1

var reduced_flash: bool = false
var reduced_shake: bool = false
var glow_enabled: bool = true
## Test-room and debug labels (HP numbers, room titles). Off in normal play.
var show_debug_labels: bool = false
var tutorials_enabled: bool = true
## Tutorial ids already completed; completed cards never show again.
var tutorials_done: PackedStringArray = []

var _persist: bool = true


func _ready() -> void:
	load_settings()


func set_option(key: StringName, value: Variant) -> void:
	if not key in self:
		push_error("Settings: unknown option '%s'." % key)
		return
	set(key, value)
	save_settings()
	changed.emit()


func mark_tutorial_done(id: String) -> void:
	if tutorials_done.has(id):
		return
	tutorials_done.append(id)
	save_settings()


func reset_defaults() -> void:
	reduced_flash = false
	reduced_shake = false
	glow_enabled = true
	show_debug_labels = false
	tutorials_enabled = true
	tutorials_done = PackedStringArray()
	changed.emit()


## Tests call this so they never touch the player's real settings file.
func set_persistence(enabled: bool) -> void:
	_persist = enabled


func load_settings(path: String = PATH) -> void:
	reset_defaults()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	if int(file.get_value("meta", "version", 0)) != VERSION:
		return
	reduced_flash = bool(file.get_value("accessibility", "reduced_flash", reduced_flash))
	reduced_shake = bool(file.get_value("accessibility", "reduced_shake", reduced_shake))
	glow_enabled = bool(file.get_value("video", "glow_enabled", glow_enabled))
	tutorials_enabled = bool(file.get_value("gameplay", "tutorials_enabled", tutorials_enabled))
	var done: Variant = file.get_value("gameplay", "tutorials_done", PackedStringArray())
	tutorials_done = done if done is PackedStringArray else PackedStringArray()
	changed.emit()


func save_settings(path: String = PATH) -> void:
	if not _persist:
		return
	var file := ConfigFile.new()
	file.set_value("meta", "version", VERSION)
	file.set_value("accessibility", "reduced_flash", reduced_flash)
	file.set_value("accessibility", "reduced_shake", reduced_shake)
	file.set_value("video", "glow_enabled", glow_enabled)
	file.set_value("gameplay", "tutorials_enabled", tutorials_enabled)
	file.set_value("gameplay", "tutorials_done", tutorials_done)
	file.save(path)
