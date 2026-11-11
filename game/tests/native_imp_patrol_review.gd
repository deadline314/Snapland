extends "res://game/tests/native_authored_patrol_review.gd"

func _npc_actions() -> void:
	await _observe_authored_patrol("imp")
