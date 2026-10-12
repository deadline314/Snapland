extends SceneTree

const SessionScript := preload("res://game/minigames/session.gd")
const RibbonView := preload("res://game/minigames/ribbon_rhythm_view.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("SNAPLAND_SAVE_PATH").is_empty():
		push_error("Ribbon Session startup check requires isolated SNAPLAND_SAVE_PATH")
		quit(1)
		return
	var session: Control = SessionScript.new()
	root.add_child(session)
	session.start("game-006", false)
	await process_frame
	var view := session.presentation as RibbonView
	_expect(session.presentation_mode == "ribbon_rhythm" and view != null, "starting game-006 creates its Ribbon presentation through Session")
	if view != null:
		_expect(view.avatar_assets_ready(), "Session startup configures the authored avatar actions without a test-side setup call")
		var idle_texture: Texture2D = view._avatar_texture("idle_front", 0.0)
		_expect(idle_texture != null and idle_texture.get_width() > 0 and idle_texture.get_height() > 0, "Session startup supplies a usable idle performer texture")
	if failures == 0:
		print("PASS: Ribbon Session startup (%d checks)" % checks)
		session.queue_free()
		quit(0)
	else:
		push_error("Ribbon Session startup: %d check(s) failed" % failures)
		session.queue_free()
		quit(1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + message)
