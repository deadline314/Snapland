class_name ComponentAnimation
extends Node

## Small, scene-scoped coordinator for ambient component animation.
## Add as a child of the scene root, register targets/materials, then call
## finish_registration() once. AnimationPlayer owns all transform/light tracks.

const ANIMATION_NAME := "ambient"
const ANIMATION_LIBRARY := ""
const CYCLE_SECONDS := 12.0
const SAMPLE_COUNT := 24

const PROFILES := {
	"flag": {"property": "rotation", "axis": 2, "amplitude": 0.035, "cycles": 3.0},
	"awning": {"property": "rotation", "axis": 0, "amplitude": 0.018, "cycles": 1.0},
	"foliage": {"property": "rotation", "axis": 1, "amplitude": 0.012, "cycles": 4.0},
	"water": {"property": "position", "axis": 1, "amplitude": 0.035, "cycles": 2.0},
	"balloon": {"property": "position", "axis": 1, "amplitude": 0.10, "cycles": 1.0},
	"hanging_sign": {"property": "rotation", "axis": 2, "amplitude": 0.025, "cycles": 2.0},
	"marker": {"property": "position", "axis": 1, "amplitude": 0.10, "cycles": 2.0},
	"cloth": {"property": "rotation", "axis": 2, "amplitude": 0.016, "cycles": 3.0},
	"soft_scale": {"property": "scale", "axis": 1, "amplitude": 0.012, "cycles": 1.0},
	"character_hero": {"property": "shader_phase", "axis": 0, "amplitude": 0.20, "cycles": 2.0},
	"character_ticket": {"property": "shader_phase", "axis": 0, "amplitude": 0.28, "cycles": 3.0},
	"character_imp": {"property": "shader_phase", "axis": 0, "amplitude": 0.42, "cycles": 5.0},
	"character_announcer": {"property": "shader_phase", "axis": 0, "amplitude": 0.12, "cycles": 1.0},
}

var _player: AnimationPlayer
var _animation: Animation
var _records: Array[Dictionary] = []
var _materials: Array[WeakRef] = []
var _registered_ids: Dictionary = {}
var _by_profile: Dictionary = {}
var _finished := false
var _reduced_motion := false


func _exit_tree() -> void:
	release()


func register_component(target: Node3D, profile: String, seed: float = 0.0) -> bool:
	if _finished:
		push_warning("ComponentAnimation: registration after finish_registration() was ignored.")
		return false
	if not is_instance_valid(target) or not PROFILES.has(profile):
		push_warning("ComponentAnimation: unknown profile or invalid target: %s" % profile)
		return false
	if not _claim_target(target, profile):
		return false
	var settings: Dictionary = PROFILES[profile]
	var property_name: String = settings["property"]
	var baseline: Variant
	if property_name == "shader_phase":
		var shader_material := target.get("material_override") as ShaderMaterial
		if shader_material == null or shader_material.shader == null:
			_registered_ids.erase(target.get_instance_id())
			push_warning("ComponentAnimation: character profile requires a ShaderMaterial override.")
			return false
		baseline = shader_material.get_shader_parameter("phase")
		if baseline == null:
			baseline = 0.0
	else:
		baseline = target.get(property_name)
	var record := {
		"target": weakref(target),
		"instance_id": target.get_instance_id(),
		"profile": profile,
		"seed": seed,
		"property": property_name,
		"baseline": baseline,
		"track_indices": [],
		"active": true,
	}
	_records.append(record)
	_by_profile[profile] = int(_by_profile.get(profile, 0)) + 1
	_connect_target_exit(target)
	return true


func register_light(target: Light3D, seed: float = 0.0) -> bool:
	if _finished:
		push_warning("ComponentAnimation: registration after finish_registration() was ignored.")
		return false
	if not is_instance_valid(target):
		push_warning("ComponentAnimation: invalid light target was ignored.")
		return false
	if not _claim_target(target, "light"):
		return false
	_records.append({
		"target": weakref(target),
		"instance_id": target.get_instance_id(),
		"profile": "light",
		"seed": seed,
		"property": "light_energy",
		"baseline": target.light_energy,
		"track_indices": [],
		"active": true,
	})
	_by_profile["light"] = int(_by_profile.get("light", 0)) + 1
	_connect_target_exit(target)
	return true


func register_shader(material: ShaderMaterial) -> void:
	if _finished:
		push_warning("ComponentAnimation: shader registration after finish_registration() was ignored.")
		return
	if not is_instance_valid(material) or material.shader == null:
		push_warning("ComponentAnimation: invalid shader material was ignored.")
		return
	for material_ref in _materials:
		if material_ref.get_ref() == material:
			return
	_materials.append(weakref(material))
	material.set_shader_parameter("motion", 0.0 if _reduced_motion else 1.0)


func set_light_baseline(target: Light3D, energy: float) -> void:
	if not is_instance_valid(target) or _animation == null:
		return
	for record_index in range(_records.size()):
		var record: Dictionary = _records[record_index]
		if record["profile"] != "light" or int(record["instance_id"]) != target.get_instance_id():
			continue
		record["baseline"] = energy
		var phase := float(record.get("phase", 0.0))
		var cycles := float(record.get("cycles", 2.0))
		var amplitude := float(record.get("amplitude", 0.05))
		for key_index in range(SAMPLE_COUNT + 1):
			var time := CYCLE_SECONDS * float(key_index) / float(SAMPLE_COUNT)
			var offset := (sin(TAU * cycles * time / CYCLE_SECONDS + phase) - sin(phase)) * 0.5 * amplitude
			_animation.track_set_key_value(int(record["track_indices"][0]), key_index, maxf(0.0, energy * (1.0 + offset)))
		_records[record_index] = record
		if _reduced_motion:
			target.light_energy = energy
		return


func finish_registration() -> void:
	if _finished:
		return
	_finished = true
	if _records.is_empty():
		return
	var scene_root := get_parent()
	if scene_root == null:
		push_warning("ComponentAnimation: add this node under a scene root before registering targets.")
		return
	_player = AnimationPlayer.new()
	_player.name = "AmbientAnimationPlayer"
	_player.root_node = NodePath("../..")
	add_child(_player)
	_animation = Animation.new()
	_animation.resource_name = ANIMATION_NAME
	_animation.length = CYCLE_SECONDS
	_animation.loop_mode = Animation.LOOP_LINEAR
	for record_index in range(_records.size()):
		_build_record_tracks(record_index, scene_root)
	var library := AnimationLibrary.new()
	library.add_animation(ANIMATION_NAME, _animation)
	_player.add_animation_library(ANIMATION_LIBRARY, library)
	if not _reduced_motion and _animation.get_track_count() > 0:
		_player.play(ANIMATION_NAME)
		_player.seek(0.0, true)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	for material_ref in _materials:
		var material := material_ref.get_ref() as ShaderMaterial
		if is_instance_valid(material):
			material.set_shader_parameter("motion", 0.0 if enabled else 1.0)
	if not is_instance_valid(_player):
		return
	if enabled:
		_player.stop()
		_restore_baselines()
	elif _finished and _animation != null and _animation.get_track_count() > 0:
		_restore_baselines()
		_player.play(ANIMATION_NAME)
		_player.seek(0.0, true)


func release() -> void:
	if is_instance_valid(_player):
		_player.stop()
		_restore_baselines()
		_player.clear_caches()
		_player.queue_free()
	_player = null
	_animation = null
	for record in _records:
		var target: Node = record["target"].get_ref()
		if is_instance_valid(target):
			var callback := Callable(self, "_on_target_exiting").bind(int(record["instance_id"]))
			if target.tree_exiting.is_connected(callback):
				target.tree_exiting.disconnect(callback)
	for material_ref in _materials:
		var material := material_ref.get_ref() as ShaderMaterial
		if is_instance_valid(material):
			material.set_shader_parameter("motion", 1.0)
	_materials.clear()
	_records.clear()
	_registered_ids.clear()
	_by_profile.clear()
	_finished = true


func statistics() -> Dictionary:
	var active_count := 0
	for record in _records:
		if bool(record.get("active", false)):
			var target: Object = record["target"].get_ref()
			if is_instance_valid(target):
				active_count += 1
	var live_materials := 0
	for material_ref in _materials:
		if is_instance_valid(material_ref.get_ref()):
			live_materials += 1
	return {
		"registration_count": active_count,
		"shader_count": live_materials,
		"by_profile": _by_profile.duplicate(),
		"playing": is_instance_valid(_player) and _player.is_playing(),
		"reduced_motion": _reduced_motion,
	}


func _claim_target(target: Node3D, profile: String) -> bool:
	var instance_id := target.get_instance_id()
	if _registered_ids.has(instance_id):
		push_warning("ComponentAnimation: duplicate target registration rejected (existing profile %s, requested %s)." % [str(_registered_ids[instance_id]), profile])
		return false
	_registered_ids[instance_id] = profile
	return true


func _connect_target_exit(target: Node) -> void:
	var callback := Callable(self, "_on_target_exiting").bind(target.get_instance_id())
	if not target.tree_exiting.is_connected(callback):
		target.tree_exiting.connect(callback, CONNECT_ONE_SHOT)


func _build_record_tracks(record_index: int, scene_root: Node) -> void:
	var record: Dictionary = _records[record_index]
	var target: Node = record["target"].get_ref()
	if not is_instance_valid(target) or not target.is_inside_tree():
		record["active"] = false
		return
	var property_path := ":material_override:shader_parameter/phase" if record["property"] == "shader_phase" else ":" + str(record["property"])
	var track_path := NodePath(String(scene_root.get_path_to(target)) + property_path)
	var track_index := _animation.add_track(Animation.TYPE_VALUE)
	_animation.track_set_path(track_index, track_path)
	_animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_CUBIC)
	_animation.value_track_set_update_mode(track_index, Animation.UPDATE_CONTINUOUS)
	var baseline: Variant = record["baseline"]
	var phase := _seed_phase(float(record.get("seed", 0.0)), int(record["instance_id"]))
	var frequency := 0.05
	var amplitude := 0.05
	var axis := 0
	if record["profile"] == "light":
		frequency = 2.0
		amplitude = 0.05
	else:
		var settings: Dictionary = PROFILES[record["profile"]]
		frequency = float(settings["cycles"])
		amplitude = float(settings["amplitude"])
		axis = int(settings["axis"])
	record["phase"] = phase
	record["cycles"] = frequency
	record["amplitude"] = amplitude
	for sample in range(SAMPLE_COUNT + 1):
		var time := CYCLE_SECONDS * float(sample) / float(SAMPLE_COUNT)
		var offset := (sin(TAU * frequency * time / CYCLE_SECONDS + phase) - sin(phase)) * 0.5 * amplitude
		_animation.track_insert_key(track_index, time, _value_with_offset(record, baseline, axis, offset))
	record["track_indices"].append(track_index)
	_records[record_index] = record


func _value_with_offset(record: Dictionary, baseline: Variant, axis: int, offset: float) -> Variant:
	if record["profile"] == "light":
		return maxf(0.0, float(baseline) * (1.0 + offset))
	if record["property"] == "shader_phase":
		return float(baseline) + offset
	if record["property"] == "position":
		var result: Vector3 = baseline
		result[axis] += offset
		return result
	var result: Vector3 = baseline
	result[axis] += offset
	return result


func _seed_phase(seed: float, instance_id: int) -> float:
	var phase_source := seed
	if is_zero_approx(phase_source):
		phase_source = float(instance_id) * 0.61803398875
	return fposmod(phase_source, 1.0) * TAU


func _restore_baselines() -> void:
	for record in _records:
		var target: Object = record["target"].get_ref()
		if is_instance_valid(target) and bool(record.get("active", false)):
			if record["profile"] == "light":
				target.set("light_energy", record["baseline"])
			elif record["property"] == "shader_phase":
				var material := target.get("material_override") as ShaderMaterial
				if is_instance_valid(material):
					material.set_shader_parameter("phase", record["baseline"])
			else:
				target.set(str(record["property"]), record["baseline"])


func _on_target_exiting(instance_id: int) -> void:
	for record_index in range(_records.size()):
		var record: Dictionary = _records[record_index]
		if int(record["instance_id"]) != instance_id:
			continue
		record["active"] = false
		var profile: String = record["profile"]
		_by_profile[profile] = maxi(0, int(_by_profile.get(profile, 1)) - 1)
		if is_instance_valid(_animation):
			for track_index in record["track_indices"]:
				if int(track_index) < _animation.get_track_count():
					_animation.track_set_enabled(int(track_index), false)
		_records[record_index] = record
		_registered_ids.erase(instance_id)
		return
