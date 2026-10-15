extends "res://game/tests/native_island_animation_acceptance.gd"
## Main-backed evidence: real input events reach the island; framing is scripted.
var _look_capture_prefix := "initial"

func _store_capture(label: String, image: Image, framing: Dictionary = {}) -> void:
	super._store_capture(_look_capture_prefix + "-" + label, image, framing)

func _hero_actions() -> void:
	var original_appearance: Dictionary = _world.avatar_appearance.duplicate(true)
	var original_equipped: Dictionary = _world.avatar_equipped.duplicate(true)
	var looks := [{"appearance": original_appearance, "equipped": original_equipped}]
	if not OS.get_cmdline_user_args().has("--default-look-only"):
		looks.append({"appearance": original_appearance, "equipped": {"hat": "hat-straw", "outfit": "outfit-coral"}})
		looks.append({"appearance": {"skin": "warm", "species": "elf", "hair": "bob", "hair_color": "ink", "face": "curious"}, "equipped": {"hat": "hat-flower", "outfit": "outfit-tide"}})
	for look_index in range(looks.size()):
		var look: Dictionary = looks[look_index]
		_look_capture_prefix = "look-%d" % look_index
		_world.set_avatar_look(look.appearance, look.equipped)
		await _physics_frames(4)
		for pair in [[KEY_A, "left"], [KEY_D, "right"]]:
			_press(pair[0], true)
			await _physics_frames(3)
			var walk := await _observe_hero_walk(0.32, pair[1])
			_press(pair[0], false)
			var settle := await _wait_hero_settle()
			walk["world_blocked"] = _world.blocked
			walk["main_modal"] = _main.modal_kind
			walk["facing_after_input"] = _world.facing
			await _record_action("side-walk-" + str(look_index), "walk", pair[1], "authored-walk-atlas", _actor_anchor(), bool(walk.complete) and bool(settle.complete), walk)
			_begin_observation("idle", "")
			var start := _simulated_seconds
			var anchor := _actor_anchor()
			while _simulated_seconds - start < 3.05 and _within_budget(): await _frames(1)
			var rendered := _end_observation()
			_flush_buffered_captures()
			var complete: bool = bool(rendered.source_consistent) and (rendered.frames as Dictionary).size() == 4 and _actor_anchor() == anchor and not _world.avatar_is_walking
			await _record_action("side-idle-look-" + str(look_index), "idle", pair[1], "authored", anchor, complete, {"look": look, "rendered": rendered, "stationary": _actor_anchor() == anchor})
			await _capture("side-idle-look-%d-%s" % [look_index, pair[1]])
	_world.blocked = true
	var frozen_time: float = _world.time
	var frozen_texture := _live_texture_id()
	await _frames(12)
	await _record_action("side-idle-pause", "idle", "right", "authored", _actor_anchor(), _world.time == frozen_time and _live_texture_id() == frozen_texture)
	_world.blocked = false
	_world.set_avatar_look(original_appearance, original_equipped)
	var settings: Dictionary = get_tree().root.get_node("Progress").settings.duplicate(true)
	settings["reduced_motion"] = true
	_world.apply_settings(settings)
	await _frames(3)
	await _record_action("side-idle-reduced", "idle", "right", "authored", _actor_anchor(), _world.last_avatar_frame == 0 and _hero_sprite_source_consistent())
	await _capture("side-idle-reduced")
