extends SceneTree
## The shared minigame air must react to score, mistakes and endings for any
## game without touching rules, and must stay calm without a display.

const Atmosphere = preload("res://game/ui/minigame_atmosphere.gd")
const Session = preload("res://game/minigames/session.gd")
const GameCatalog = preload("res://game/core/game_catalog.gd")
const TimeOfDay = preload("res://game/core/time_of_day.gd")

var failures := 0
var checks := 0


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Minigame atmosphere: " + message)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var air := Atmosphere.new()
	root.add_child(air)
	await process_frame
	for zone: String in GameCatalog.DATA_PATHS:
		_check(Atmosphere.THEMES.has(zone), "delivered zone '%s' has its own air" % zone)
	for phase: Dictionary in TimeOfDay.PHASES:
		_check(Atmosphere.PHASE_LIGHT.has(str(phase.id)), "time phase '%s' has light values" % str(phase.id))
	for zone: String in Atmosphere.THEMES:
		_check(int(Atmosphere.THEMES[zone].count) <= Atmosphere.MAX_MOTES, "'%s' stays within the mote budget" % zone)
	air.configure("not-a-zone", "not-a-phase", false)
	_check(air._theme == Atmosphere.THEMES["welcome"], "unknown zones fall back to the welcome air")

	air.score_gained()
	_check(air._flash > 0.0 and air._static_flash_left > 0.0, "score glows and holds still without motion")
	air.mistake_made()
	_check(air.shake_offset() == Vector2.ZERO and is_zero_approx(air._trauma), "no shake without a display")
	air.round_finished(true)
	_check(air._confetti_age < 0.0, "no confetti without a display")
	for frame in 40:
		await process_frame
	air.reset()
	_check(is_zero_approx(air._flash) and air.shake_offset() == Vector2.ZERO, "reset clears feedback")
	air.queue_free()

	var session := Session.new()
	root.add_child(session)
	await process_frame
	var names: Array = session.get_children().map(func(child: Node) -> String: return str(child.name))
	_check(names.has("MinigameAtmosphere") and names.find("MinigameAtmosphere") < names.find("MinigameHUD"), "air sits below the HUD")
	var nodes_before := session.get_child_count()
	session.start("game-004")
	await process_frame
	var hosted: Control = session.atmosphere
	_check(is_instance_valid(hosted), "session hosts the air")
	_check(hosted.get_index() < session.minigame_hud.get_index(), "air stays below the HUD after a game starts")
	if is_instance_valid(session.presentation):
		_check(session.presentation.get_index() < hosted.get_index(), "air sits above the game picture")
	hosted.reset()
	session.score += 5
	await process_frame
	_check(hosted._flash > 0.0, "any score gain glows")
	_check(session._seen_score == session.score, "score gain is consumed once")
	hosted.reset()
	await process_frame
	_check(is_zero_approx(hosted._flash), "an unchanged score stays calm")
	session.mistakes += 1
	await process_frame
	_check(hosted._flash > 0.0, "any mistake glows")
	hosted.reset()
	session.set_time_of_day("night")
	_check(is_equal_approx(float(hosted._mote_alpha), float(Atmosphere.PHASE_LIGHT["night"][2])), "time of day retunes the air")
	session.start("game-004")
	await process_frame
	_check(session.get_child_count() <= nodes_before + 1, "restarting adds no extra layers")
	session.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: minigame atmosphere themes, shared feedback and layer order (%d checks)" % checks)
	quit(1 if failures > 0 else 0)
