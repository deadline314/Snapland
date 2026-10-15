extends "res://game/tests/native_island_animation_acceptance.gd"
## Main-backed evidence: real input events reach the island; framing is scripted.
var _look_capture_prefix := "initial"

func _store_capture(label: String, image: Image, framing: Dictionary = {}) -> void:
	super._store_capture(_look_capture_prefix + "-" + label, image, framing)

func _hero_actions() -> void:
	var original_appearance: Dictionary = _world.avatar_appearance.duplicate(true)
	var original_equipped: Dictionary = _world.avatar_equipped.duplicate(true)
	var looks := [{"appearance": original_appearance, "equipped": original_equipped}]
	var key_pairs := {"left": [KEY_A], "right": [KEY_D], "front_left": [KEY_S, KEY_A], "front_right": [KEY_S, KEY_D], "back_left": [KEY_W, KEY_A], "back": [KEY_W], "back_right": [KEY_W, KEY_D], "front": [KEY_S]}
	var opposite := {"left":"right", "right":"left", "front_left":"back_right", "front_right":"back_left", "back_left":"front_right", "back":"front", "back_right":"front_left", "front":"back"}
	var directions := _arg(OS.get_cmdline_user_args(), "--idle-directions=").split(",", false)
	if directions.is_empty(): directions = PackedStringArray(["left", "right"])
	for direction in directions:
		if not key_pairs.has(direction):
			_fail("unsupported idle review direction: " + direction)
			return
	if not OS.get_cmdline_user_args().has("--default-look-only"):
		looks.append({"appearance": original_appearance, "equipped": {"hat": "hat-straw", "outfit": "outfit-coral"}})
		looks.append({"appearance": {"skin": "warm", "species": "elf", "hair": "bob", "hair_color": "ink", "face": "curious"}, "equipped": {"hat": "hat-flower", "outfit": "outfit-tide"}})
	for look_index in range(looks.size()):
		var look: Dictionary = looks[look_index]
		_look_capture_prefix = "look-%d" % look_index
		_world.set_avatar_look(look.appearance, look.equipped)
		await _physics_frames(4)
		for direction in directions:
			var review_start: Vector3 = _world.player.global_position
			for key in key_pairs[direction]: _press(key, true)
			await _physics_frames(3)
			var walk := await _observe_hero_walk(0.32, direction)
			for key in key_pairs[direction]: _press(key, false)
			var settle := await _wait_hero_settle()
			walk["world_blocked"] = _world.blocked
			walk["main_modal"] = _main.modal_kind
			walk["facing_after_input"] = _world.facing
			await _record_action("side-walk-" + str(look_index), "walk", direction, "authored-walk-atlas", _actor_anchor(), bool(walk.complete) and bool(settle.complete), walk)
			_begin_observation("idle", "")
			var start := _simulated_seconds
			var anchor := _actor_anchor()
			var root_start: Vector3 = _world.player.global_position
			var sprite_start: Vector3 = _world.avatar.global_position
			var root_drift := 0.0
			var sprite_drift := 0.0
			while _simulated_seconds - start < 3.05 and _within_budget():
				await _frames(1)
				root_drift = maxf(root_drift, root_start.distance_to(_world.player.global_position))
				sprite_drift = maxf(sprite_drift, sprite_start.distance_to(_world.avatar.global_position))
			var rendered := _end_observation()
			_flush_buffered_captures()
			var expected_cels := 8 if direction == "front" else 4
			# Sprite grounding follows the camera's up vector; compare the physical
			# player separately and report the tiny grounding adjustment explicitly.
			var stationary := root_drift <= 0.00001 and sprite_drift <= 0.001
			var complete: bool = bool(rendered.source_consistent) and (rendered.frames as Dictionary).size() == expected_cels and stationary and not _world.avatar_is_walking
			await _record_action("side-idle-look-" + str(look_index), "idle", direction, "authored", anchor, complete, {"look": look, "rendered": rendered, "stationary": stationary, "max_player_drift_m":root_drift, "max_sprite_grounding_drift_m":sprite_drift, "end_anchor":_actor_anchor()})
			await _capture("side-idle-look-%d-%s" % [look_index, direction])
			# Walk back through real input so successive looks stay on the clear
			# review patch. No teleport or actor repositioning hides an idle defect.
			var return_direction: String = opposite[direction]
			for key in key_pairs[return_direction]: _press(key, true)
			await _physics_frames(3)
			var return_walk := await _observe_hero_walk(0.32, return_direction)
			for key in key_pairs[return_direction]: _press(key, false)
			var return_settle := await _wait_hero_settle()
			return_walk["distance_from_review_start_m"] = review_start.distance_to(_world.player.global_position)
			await _record_action("return-to-review-patch-" + str(look_index), "walk", return_direction, "authored-walk-atlas", _actor_anchor(), bool(return_walk.complete) and bool(return_settle.complete) and review_start.distance_to(_world.player.global_position) < 0.1, return_walk)
	_world.blocked = true
	var frozen_time: float = _world.time
	var frozen_texture := _live_texture_id()
	await _frames(12)
	await _record_action("side-idle-pause", "idle", String(_world.facing), "authored", _actor_anchor(), _world.time == frozen_time and _live_texture_id() == frozen_texture)
	_world.blocked = false
	_world.set_avatar_look(original_appearance, original_equipped)
	var settings: Dictionary = get_tree().root.get_node("Progress").settings.duplicate(true)
	settings["reduced_motion"] = true
	_world.apply_settings(settings)
	await _frames(3)
	await _record_action("side-idle-reduced", "idle", String(_world.facing), "authored", _actor_anchor(), _world.last_avatar_frame == 0 and _hero_sprite_source_consistent())
	await _capture("side-idle-reduced")
