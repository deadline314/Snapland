extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var script=load("res://game/tests/native_walk_stability_review.gd")
	assert(script.can_instantiate())
	var probe=script.new()
	probe.free()
	print("PASS native walk review script loads after project autoloads")
	quit()
