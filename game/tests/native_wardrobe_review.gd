extends "res://game/tests/native_review.gd"

## Native UI input review. Currency is explicit isolated fixture data, not a
## claim that this helper played the minigames.
func _run() -> void:
 if OS.get_environment('SNAPLAND_SAVE_PATH').is_empty() or DisplayServer.get_name()=='headless':
  push_error('Native wardrobe review requires GPU and isolated profile');get_tree().quit(1);return
 progress=get_tree().root.get_node_or_null('Progress')
 if progress==null: push_error('Progress autoload is missing');get_tree().quit(1);return
 progress.reset_progress();progress.intro_seen=true;progress.coins=600
 main=_instantiate_main()
 if main==null: get_tree().quit(1);return
 get_tree().root.add_child(main)
 await get_tree().create_timer(1.5).timeout
 if not await _review_wardrobe(): return
 await main._quit_game()
