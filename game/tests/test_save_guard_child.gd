extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := str(args[args.size() - 1]) if not args.is_empty() else "probe"
	if mode == "probe":
		print("FIXTURE_USERDATA=" + OS.get_user_data_dir().replace("\\", "/"))
		quit(0)
		return
	call_deferred("_run_mode", mode)

func _run_mode(mode: String) -> void:
	if mode == "guard":
		print("ERROR: save guard child reached its test body")
		return
	if mode == "positive":
		var progress := root.get_node("Progress")
		if not progress.call("save_progress"):
			push_error("positive isolated save failed")
			quit(2)
			return
		progress.set("coins", 7)
		progress.call("load_progress")
		if int(progress.get("coins")) != 120:
			push_error("positive isolated load did not restore saved progress")
			quit(3)
			return
		print("ISOLATED_SAVE_ROUNDTRIP_OK")
		quit(0)
		return
	push_error("unknown save guard child mode: " + mode)
	quit(4)
