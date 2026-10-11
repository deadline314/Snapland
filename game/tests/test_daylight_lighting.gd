extends SceneTree

const ParkWorldScript = preload("res://game/world/park_world.gd")
const SessionScript = preload("res://game/minigames/session.gd")
const TimeOfDayScript = preload("res://game/core/time_of_day.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := ParkWorldScript.new()
	root.add_child(world)
	await process_frame
	for phase_id in TimeOfDayScript.phase_ids():
		world.set_time_of_day(phase_id)
		await process_frame
		var emitted_ray: Vector3 = -world.sun.global_basis.z
		if emitted_ray.y >= 0.0:
			_fail("The %s key-light ray points above the ground: %s" % [phase_id, emitted_ray])
		var profile: Dictionary = TimeOfDayScript.phase_for_id(phase_id)
		if world.environment.background_color != profile.sky_color:
			_fail("The %s sky profile was not applied." % phase_id)
		var active_lamps := 0
		for lamp in world.lamps:
			if lamp.light_energy > 0.0:
				active_lamps += 1
		if active_lamps > 8:
			_fail("The %s phase enables %d local lights (limit 8)." % [phase_id, active_lamps])
	if world.avatar.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		_fail("The avatar billboard still casts a card shadow.")
	if world.contact_shadows.size() != 4:
		_fail("Expected three NPC and one player contact anchors; found %d." % world.contact_shadows.size())
	if not world.material_cache.has("contact_shadow"):
		_fail("The world contact-shadow material is not cached.")
	var session := SessionScript.new()
	root.add_child(session)
	for phase_id in TimeOfDayScript.phase_ids():
		session.set_time_of_day(phase_id)
		if session.time_phase != phase_id or session.phase_wash.a <= 0.0:
			_fail("The session backdrop did not accept phase %s." % phase_id)
	if failures == 0:
		print("PASS: daylight lighting runtime checks")
	world.queue_free()
	session.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _fail(message: String) -> void:
	failures += 1
	push_error("[test_daylight_lighting] " + message)
