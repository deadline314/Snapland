extends Node
## Automated UI geometry with synthetic ownership; no gameplay or listening claim.

const Catalog = preload("res://game/core/game_catalog.gd")
const Release = preload("res://game/tests/audio_playback_release.gd")
const MARKER = "PASS: native game rules actual viewport, complete text, actions and paging"
var main: Node
var failures: Array[String] = []
var records: Array = []

func _ready() -> void:
	get_tree().create_timer(85.0).timeout.connect(func(): push_error("Native rules watchdog"); get_tree().quit(1))
	_run.call_deferred()

func _run() -> void:
	var output := OS.get_environment("RULES_CAPTURE_DIR")
	var parts := OS.get_environment("RULES_REVIEW_SIZE").split("x")
	if DisplayServer.get_name()=="headless" or not output.is_absolute_path() or not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path() or parts.size()!=2:
		push_error("Native rules review requires GPU and isolated absolute paths")
		get_tree().quit(1)
		return
	var dimensions := Vector2i(int(parts[0]),int(parts[1]))
	if dimensions not in [Vector2i(800,600),Vector2i(1152,648),Vector2i(1280,720)]:
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size=dimensions
	get_window().size=dimensions
	Progress.reset_progress()
	Progress.intro_seen=true
	Progress.prologue_seen=true
	Progress.settings["ui_scale"]=1.25 if dimensions.x==800 else 1.0
	Progress.settings["reduced_motion"]=dimensions.x==800
	main=load("res://game/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(5)
	if get_viewport().get_visible_rect().size!=Vector2(dimensions): failures.append("actual viewport differs from request")
	for id in ["game-001","game-009","game-013","game-025","game-026"]:
		for context in 5:
			set_context(id,context)
			main._show_game_rules(id)
			await frames(5)
			var pager: Control=main.overlay.find_child("GameRulesExtraDetails",true,false)
			for page in int(pager.get_meta("page_count")):
				var label := "%s-context%d-page%d"%[id,context,page]
				var problems := inspect_layout(main)
				for problem in problems: failures.append(label+": "+problem)
				records.append({"case":label,"viewport":str(get_viewport().get_visible_rect()),"metrics":metrics(main),"failures":problems})
				if context in [0,1,4] and page in [0,1,3]:
					await RenderingServer.frame_post_draw
					var image := get_viewport().get_texture().get_image()
					if image.get_size()!=dimensions or image.save_png(output.path_join(label+".png"))!=OK: failures.append("raw capture failed "+label)
				if page<int(pager.get_meta("page_count"))-1:
					var next: Button=main.overlay.find_child("GameRulesExtraDetailsNext",true,false)
					await click(next)
					await frames(4)
					if int(pager.get_meta("page_index"))!=page+1: failures.append("real pointer did not advance notes")
	main.quitting=true
	var playbacks: Array[WeakRef]=Release.capture(main.audio)
	main.audio.shutdown()
	main.queue_free()
	await frames(3)
	if not await Release.wait_for_release(get_tree(),playbacks): failures.append("audio release timeout")
	var report := {"scope":"Synthetic UI ownership only; no gameplay or listening", "catalog_count":Catalog.all_definitions().size(),"dimensions":str(dimensions),"content_scale_mode":get_window().content_scale_mode,"records":records,"failures":failures}
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	for problem in failures: push_error(problem)
	if failures.is_empty(): print(MARKER)
	get_tree().quit(0 if failures.is_empty() else 1)

static func set_context(id: String, context: int) -> void:
	# Isolated synthetic UI state: no rewards, photo files or gameplay result.
	Progress.photos.clear()
	Progress.attempted_games.clear()
	var identity := Catalog.identity(id)
	if context>0: Progress.attempted_games.append(id)
	if context in [2,4]: Progress.photos[identity.photo_id]={}
	if context in [3,4]: Progress.photos[identity.devil_photo_id]={}

static func inspect_layout(owner: Node) -> Array[String]:
	var problems: Array[String]=[]
	var viewport: Rect2=owner.get_viewport().get_visible_rect()
	var panel: Control=owner.overlay.find_child("AdaptiveMenuPanel",true,false)
	if not viewport.encloses(panel.get_global_rect()): problems.append("panel outside viewport: "+str(panel.get_global_rect()))
	var leaves: Array[Control]=[]
	for control: Control in panel.find_children("*","Control",true,false):
		if not control.is_visible_in_tree(): continue
		if not viewport.encloses(control.get_global_rect()): problems.append("viewport clips "+str(control.get_path())+" "+str(control.get_global_rect()))
		if control.get_parent() is Control and not (control.get_parent() as Control).get_global_rect().encloses(control.get_global_rect()): problems.append("parent clips "+str(control.get_path()))
		if control is Label:
			var height: float=float(control.get_line_count())*control.get_line_height()+maxi(0,control.get_line_count()-1)*control.get_theme_constant("line_spacing")
			if height>control.size.y: problems.append("label text height clipped: "+control.text)
			if control.autowrap_mode==TextServer.AUTOWRAP_OFF and control.get_theme_font("font").get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size")).x>control.size.x: problems.append("label text width clipped: "+control.text)
			leaves.append(control)
		elif control is Button:
			var style := control.get_theme_stylebox("normal")
			var text_size := control.get_theme_font("font").get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size"))
			if text_size.x+style.get_minimum_size().x>control.size.x or text_size.y+style.get_minimum_size().y>control.size.y: problems.append("button text clipped: "+control.text)
			leaves.append(control)
	for first in leaves.size():
		for second in range(first+1,leaves.size()):
			if leaves[first].get_global_rect().intersects(leaves[second].get_global_rect()): problems.append("text/actions overlap: %s / %s"%[leaves[first].name,leaves[second].name])
	return problems

static func metrics(owner: Node) -> Array:
	var result: Array=[]
	for name in ["AdaptiveMenuPanel","AdaptiveMenuShell","GameRulesDetails","GameRulesRetakes","KioskRetakeOrdinary","KioskRetakeDevil","AdaptiveMenuFooter"]:
		var control: Control=owner.overlay.find_child(name,true,false)
		if control!=null: result.append({"name":name,"type":control.get_class(),"rect":str(control.get_global_rect()),"minimum":str(control.get_combined_minimum_size()),"parent":str(control.get_parent().name)})
	return result

func click(control: Control) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=control.get_global_rect().get_center()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		get_viewport().push_input(event,true)
		await frames(1)

func frames(count: int) -> void:
	for index in count: await get_tree().process_frame
