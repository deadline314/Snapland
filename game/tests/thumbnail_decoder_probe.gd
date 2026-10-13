extends Node
## Isolated child-process negative test for the native PNG decoder failure.

func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1 or OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges().is_empty():
		push_error("Thumbnail decoder probe requires one image path and an isolated SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	var decoder_calls_before := int(Progress._game_photo_decoder_invocations)
	var decoded: Image = Progress._read_game_photo_image("photo-welcome-game-1", arguments[0], {})
	var decoder_calls := int(Progress._game_photo_decoder_invocations) - decoder_calls_before
	var rejected := decoded == null
	print("NEGATIVE_PROOF: decoder_invocations=%d" % decoder_calls)
	print("NEGATIVE_PROOF: CRC-valid broken zlib was %s" % ("rejected" if rejected else "accepted"))
	if decoder_calls != 1 or not rejected:
		push_error("Thumbnail decoder probe did not prove native rejection: calls=%d rejected=%s" % [decoder_calls, str(rejected)])
		get_tree().quit(1)
		return
	get_tree().quit(0)
