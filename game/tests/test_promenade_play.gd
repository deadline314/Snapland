extends SceneTree
var failures: Array[String]=[]
var notes: Array[int]=[]
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(count: int) -> void:
	for index in count:await physics_frame
func _initialize() -> void:
	if not OS.get_environment("SNAPLAND_SAVE_PATH").is_absolute_path():quit(2);return
	call_deferred("run")
func run() -> void:
	var progress: Node=root.get_node("Progress");progress.reset_progress();progress.intro_seen=true;progress.save_progress()
	var main: Node=load("res://game/main.tscn").instantiate();root.add_child(main);await frames(4)
	var play: Node3D=main.world.coastal_play
	var toys: Node3D=play.promenade
	play.note_requested.connect(func(note: int):notes.append(note))
	var before:=FileAccess.get_file_as_bytes(OS.get_environment("SNAPLAND_SAVE_PATH"))
	check(toys.records.size()==4,"Four distinct avenue gaps have toys")
	for record in toys.records:
		main.world.player.position=record.center+Vector3(0,0.3,0)
		await frames(4)
		check(record.turns==1,"Stepping onto a pad turns its windmill once")
		await frames(24)
		check(record.turns==1,"Standing still does not repeatedly trigger a pad")
		main.world.player.position=record.center+Vector3(0,0.3,2)
		await frames(3)
		main.world.player.position=record.center+Vector3(0,0.3,0)
		await frames(4)
		check(record.turns==2,"Leaving then returning permits another deliberate step")
		await frames(24)
		main._interact(record.id,"風車")
		check(record.turns==3,"Main's normal interaction route also turns the same toy")
		check(main.session==null and main.modal_kind=="","Toy does not open a session or panel")
		check(play.prompt(record.id)=="轉動踏板風車","Context action describes the physical result")
		main.world.player.position=record.center+Vector3(0,0.3,2)
		await frames(24)
	var first: Dictionary=toys.records[0]
	main.world.blocked=true
	var angle: float=first.rotor.rotation.z
	check(not play.activate(first.id),"Modal pause rejects toy interaction")
	await frames(12)
	check(is_equal_approx(angle,first.rotor.rotation.z) and first.turns==3,"Pause preserves windmill state")
	main.world.blocked=false
	play._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not play.activate(first.id),"Lost focus rejects toy input")
	await frames(4)
	check(first.turns==3,"Lost focus does not trigger pads")
	play._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	main.world.apply_settings({"reduced_motion":true})
	main._interact(first.id,"風車")
	check(first.turns==4 and is_equal_approx(first.rotor.rotation.z,fposmod(float(first.target),TAU)),"Reduced motion shows the final result without decorative interpolation")
	check(notes.size()==13,"Four toys each produce exactly three deliberate notes, plus reduced-motion input")
	check(before==FileAccess.get_file_as_bytes(OS.get_environment("SNAPLAND_SAVE_PATH")),"Unscored toys leave the complete saved progress unchanged")
	var rotor_refs: Array=[]
	for record in toys.records:rotor_refs.append(weakref(record.rotor))
	main.world.set_process(false);main.world.set_physics_process(false)
	main.audio.shutdown()
	# Match the shared exit contract: the audio server must consume stop commands.
	await create_timer(0.15).timeout
	main.queue_free();await frames(5)
	for reference in rotor_refs:check(reference.get_ref()==null,"Scene exit frees every windmill rotor")
	if failures.is_empty():print("PASS: promenade stepping and context toys, no standing repeats, pause/focus safety, reduced-motion result and unchanged save")
	quit(0 if failures.is_empty() else 1)
