extends SceneTree

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var geo := preload("res://game/minigames/chocolate_etching_geometry.gd")
	expect(geo._segment_fraction(Vector2(100,100), Vector2(103,100), Vector2(107,100), Vector2(103,100)) == 1.0,
		"Reversed collinear segment includes the exact shared endpoint")
	expect(FileAccess.file_exists("res://game/minigames/chocolate_etching_model.gd"), "Drawn chocolate material must have its pure model")
	expect(FileAccess.file_exists("res://game/minigames/chocolate_etching_geometry.gd"), "Actual contour and kerf geometry must exist")
	if failures == 0:
		var script = load("res://game/minigames/chocolate_etching_model.gd")
		if script == null or not script.can_instantiate():
			expect(false, "Model must instantiate")
		else:
			var model = script.new()
			var revision: int = model.snapshot().stock_revision
			draw(model, PackedVector2Array([Vector2(100,100), Vector2(125,100)]), false)
			expect(model.snapshot().stock_revision > revision, "Committed stock heat invalidates the render cache")
			revision = model.snapshot().stock_revision
			model.cycle_piece()
			model.step(0.1)
			var stock: Array = model.stock_strokes()
			stock[0].points[0] = Vector2.ZERO
			stock[0].depth = 0
			expect(model.stock_strokes()[0].points[0] == Vector2(100,100) and model.stock_strokes()[0].depth == 0.5
				and model.snapshot().stock_revision == revision and not model.snapshot().has("stock_strokes"),
				"Selection and time preserve the board revision and isolated committed heat stays outside per-frame snapshots")
			model.undo()
			expect(model.snapshot().stock_revision > revision and model.stock_strokes().is_empty(), "Undo invalidates visible heat")
			revision = model.snapshot().stock_revision
			model.reset()
			expect(model.snapshot().stock_revision > revision, "Retry advances the stock revision past earlier rounds")
			_review_round_one(model)
			_review_round_two(model)
			_assisted_geometry_precision(model)
			_material_tests(model)
			_input_tests(model)
			_network_tests(model)
			_boundary_tests(model)
			_deadline_tests(model)
			for variant in 2:
				for assisted in [false, true]:
					for idler in [false, true]:
						model.reset(assisted, variant)
						var result := solve(model, idler)
						expect(result.success and result.ended and result.ordinary_eligible, "Public drawn route succeeds")
						expect(result.devil == idler and result.score == (500 if idler else 400), "Measured route earns exact clean score")
						print("CHOCOLATE_ROUTE variant=%d assisted=%s idler=%s success=%s score=%d elapsed=%.9f positions=%s radii=%s feedback=%s" % [variant,assisted,idler,result.success,result.score,result.elapsed,positions(result),radii(result),result.feedback])
			model.reset()
			for i in 4:
				select(model, i)
				var reversed: PackedVector2Array = model.snapshot().selected_guides[0]
				reversed.reverse()
				draw(model, reversed)
				draw(model, reversed)
				model.fold_or_mount()
			assemble(model, true)
			model.begin_tool()
			advance(model, 4.0)
			expect(model.snapshot().devil and model.snapshot().score == 500, "Reversed tracing preserves real leftover route")
	print("Chocolate etching tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

static func select(model, index: int) -> void:
	for i in 4:
		if model.snapshot().selected == index:
			return
		model.cycle_piece()

static func draw(model, points: PackedVector2Array, close: bool = true) -> void:
	if points.is_empty():
		return
	model.move_cursor_to(points[0])
	model.begin_tool()
	for i in range(1, points.size()):
		model.move_cursor_to(points[i])
	if close:
		model.move_cursor_to(points[0])
	model.release_tool()

static func cut_piece(model, index: int, guide_index: int = 0, passes: int = 2) -> void:
	select(model, index)
	var guide: PackedVector2Array = model.snapshot().selected_guides[guide_index]
	for i in passes:
		draw(model, guide)
	model.fold_or_mount()

static func circle_intersection(a: Vector2, ar: float, b: Vector2, br: float) -> Vector2:
	var distance := a.distance_to(b)
	var along := (ar * ar - br * br + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, ar * ar - along * along))
	var axis := (b - a) / distance
	var first := a + axis * along + Vector2(-axis.y, axis.x) * height
	var second := a + axis * along - Vector2(-axis.y, axis.x) * height
	return first if first.y < second.y else second

static func assemble(model, idler: bool) -> void:
	var state: Dictionary = model.snapshot()
	if state.phase == "craft":
		model.toggle_phase()
	var p0: Vector2 = state.pins[0]
	var p2: Vector2 = state.pins[1]
	var r := radii(state)
	var p1 := Vector2(p0.x + (p2.x - p0.x + r[0] - r[2]) * 0.5, 220)
	var p3 := Vector2(600,350)
	if idler:
		p1 = p0 + Vector2.from_angle(-PI / 6.0) * (r[0] + r[1])
		p3 = circle_intersection(p1, r[1] + r[3], p2, r[2] + r[3])
	var points := [p0,p1,p2,p3]
	for i in (4 if idler else 3):
		select(model, i)
		model.place_selected(points[i])

static func solve(model, idler: bool = false) -> Dictionary:
	for i in (4 if idler else 3):
		cut_piece(model, i)
	assemble(model, idler)
	model.begin_tool()
	for i in 30:
		model.step(0.25)
		if model.snapshot().ended:
			break
	return model.snapshot()

static func positions(state: Dictionary) -> Array:
	var result := []
	for part in state.parts:
		result.append(part.position)
	return result

static func radii(state: Dictionary) -> Array:
	var result := []
	for part in state.parts:
		result.append(part.pitch_radius)
	return result

static func advance(model, seconds: float) -> void:
	for i in ceili(seconds / 0.25):
		model.step(minf(0.25, seconds - i * 0.25))

func _material_tests(model) -> void:
	var geometry = load("res://game/minigames/chocolate_etching_geometry.gd")
	for assisted in [false,true]:
		model.reset(assisted)
		var guide: PackedVector2Array = model.snapshot().selected_guides[0]
		draw(model, guide)
		model.fold_or_mount()
		expect(not model.snapshot().parts[0].freed and model.snapshot().mistakes == 1, "Single shallow pass leaves real connecting material")
		draw(model, guide)
		model.fold_or_mount()
		expect(model.snapshot().parts[0].freed and not model.snapshot().parts[0].outline.is_empty(), "Real retrace accumulates local depth and extracts polygon")
		var elapsed: float = model.snapshot().elapsed
		model.step(0.25)
		model.undo()
		expect(not model.snapshot().parts[0].freed and model.snapshot().selected_strokes.size() == 2, "Undo fold restores same cut material")
		expect(is_equal_approx(model.snapshot().elapsed, elapsed + 0.25) and model.snapshot().participated and model.snapshot().mistakes == (1 if assisted else 2), "Undo retains time/participation with mode-specific cost")
	model.reset()
	var guide: PackedVector2Array = model.snapshot().selected_guides[0]
	draw(model, guide.slice(0,guide.size()-2), false)
	model.fold_or_mount()
	expect(not model.snapshot().parts[0].freed and model.snapshot().participated, "Open real cut counts participation without automatic closure")
	model.reset()
	model.adjust_depth(-1)
	guide = model.snapshot().selected_guides[0]
	draw(model,guide)
	draw(model,guide)
	model.adjust_depth(1)
	model.adjust_depth(1)
	draw(model,guide.slice(0,guide.size()/2),false)
	model.fold_or_mount()
	expect(not model.snapshot().parts[0].freed, "Deep half-perimeter cannot hide shallow uncut connections in average")
	model.reset()
	draw(model,PackedVector2Array([Vector2(110,190),Vector2(210,190)]),false)
	cut_piece(model,0)
	expect(not model.snapshot().parts[0].freed, "Prior committed crossing cut destroys integral gear")
	model.reset()
	var bow := PackedVector2Array([Vector2(105,140),Vector2(215,240),Vector2(105,240),Vector2(215,140)])
	draw(model,bow)
	draw(model,bow)
	model.fold_or_mount()
	expect(not model.snapshot().parts[0].freed, "Self-intersection never becomes a candidate")
	model.reset()
	var circle := PackedVector2Array()
	for i in 72:
		circle.append(Vector2(160,190)+Vector2.from_angle(TAU*i/72.0)*50.0)
	draw(model,circle)
	draw(model,circle)
	model.fold_or_mount()
	expect(not model.snapshot().parts[0].freed, "Round blank fails actual alternating tooth profile")
	model.reset()
	guide = model.snapshot().selected_guides[0]
	# Flatten one complete tooth in the drawn line, leaving other teeth untouched.
	for i in range(1,3):
		guide[i] = Vector2(160,190)+(guide[i]-Vector2(160,190)).normalized()*39.0
	draw(model,guide)
	draw(model,guide)
	model.fold_or_mount()
	expect(not model.snapshot().parts[0].freed, "One destroyed tooth is not averaged away")
	for variant in 2:
		model.reset(false,variant)
		model.adjust_depth(1)
		model.adjust_depth(1)
		for i in 3:
			cut_piece(model,i,0,1)
		var main_freed: bool = model.snapshot().parts[0].freed and model.snapshot().parts[1].freed and model.snapshot().parts[2].freed
		cut_piece(model,3,0,1)
		expect(main_freed and not model.snapshot().parts[3].freed, "Wide deep kerf spends actual fourth-wheel leftover in each variant")
		print("DEEP_WASTE variant=%d mains=%s fourth=%s" % [variant,main_freed,model.snapshot().parts[3].freed])
	model.reset()
	cut_piece(model,3)
	expect(not model.snapshot().parts[3].freed, "Fourth blank cannot be obtained before three main cutouts")
	model.reset()
	for i in 3:
		cut_piece(model,i)
	select(model,3)
	var thin: PackedVector2Array = geometry.template(Vector2(330,318),8)
	for i in range(0,thin.size(),3):
		thin[i] = Vector2(330,318)+(thin[i]-Vector2(330,318)).normalized()*14.5
	thin = geometry.offset(thin,1.75,Vector2(330,318))
	draw(model,thin)
	draw(model,thin)
	model.fold_or_mount()
	expect(not model.snapshot().parts[3].freed, "Thin actual web around shaft cannot transmit")
	model.reset()
	cut_piece(model,0)
	select(model,1)
	draw(model,PackedVector2Array([Vector2(160,190),Vector2(200,190)]),false)
	expect(model.snapshot().selected_strokes.is_empty(), "Removed source cannot be reused as a new board")
	var snapshot: Dictionary = model.snapshot()
	snapshot.parts[0].outline[0] = Vector2.ZERO
	snapshot.parts[0].freed = false
	snapshot.source_centers[0] = Vector2.ZERO
	expect(model.snapshot().parts[0].freed and model.snapshot().parts[0].outline[0] != Vector2.ZERO and model.snapshot().source_centers[0] == Vector2(160,190), "Snapshot geometry and nested state are isolated")
	var dumbbell := PackedVector2Array([Vector2(100,100),Vector2(130,100),Vector2(130,114),Vector2(150,114),Vector2(150,100),Vector2(180,100),Vector2(180,130),Vector2(150,130),Vector2(150,116),Vector2(130,116),Vector2(130,130),Vector2(100,130)])
	expect(geometry.offset(dumbbell,-2.0,Vector2(115,115)).is_empty(), "Multiple inner-offset fragments are rejected together")
	expect(geometry.offset(PackedVector2Array([Vector2(100,100),Vector2(102,100),Vector2(102,102),Vector2(100,102)]),-3.0,Vector2(101,101)).is_empty(), "Vanished inner offset is rejected")

func _input_tests(model) -> void:
	model.reset()
	model.toggle_helper()
	model.step(0.25)
	expect(model.snapshot().helper_clamp != null and not model.snapshot().participated and model.snapshot().selected_strokes.is_empty() and not model.snapshot().parts[0].freed, "AI supplies only an actual second clamp")
	var clamp: Vector2 = model.snapshot().helper_clamp
	draw(model,PackedVector2Array([clamp,clamp-Vector2(10,0)]),false)
	expect(model.snapshot().helper_clamp != clamp, "Helper cannot clamp a committed kerf")
	model.reset()
	var guide: PackedVector2Array = model.snapshot().selected_guides[0]
	model.move_cursor_to(guide[0])
	model.begin_tool()
	model.step(0.25)
	model.release_tool()
	expect(not model.snapshot().participated and model.snapshot().selected_strokes.is_empty(), "Zero-motion hold never cuts or participates")
	for cancellation in ["cancel_tool","clear_input","cycle_piece","toggle_phase"]:
		model.reset()
		model.move_cursor_to(guide[0])
		model.begin_tool()
		model.move_cursor_to(guide[1])
		model.call(cancellation)
		model.release_tool()
		expect(not model.snapshot().participated and not model.snapshot().cutting, "Cancellation never commits pending stroke: "+cancellation)
	model.reset()
	model.move_cursor_to(guide[0])
	model.begin_tool()
	model.move_cursor_to(guide[1])
	model.adjust_depth(1)
	model.release_tool()
	expect(not model.snapshot().participated, "Depth change cancels preview")
	model.reset()
	model.move_cursor_to(guide[0])
	model.begin_tool()
	model.move_cursor_to(Vector2(NAN,190))
	for point in guide:
		model.move_cursor_to(point)
	model.move_cursor_to(guide[0])
	model.release_tool()
	expect(model.snapshot().selected_strokes.is_empty(), "Nonfinite stroke input invalidates the whole pending stroke")
	model.move_cursor_to(Vector2(INF,0))
	model.step(INF)
	model.step(NAN)
	model.step(-1)
	expect(model.snapshot().elapsed == 0.0, "Invalid delta never changes round time")
	model.step(1.0e100)
	expect(is_equal_approx(model.snapshot().elapsed,0.25), "Finite hostile delta is capped to one quarter second")
	model.set_motion(Vector2(1.0e30,1.0e30))
	var before: Vector2 = model.snapshot().cursor
	model.step(0.25)
	expect(absf(before.distance_to(model.snapshot().cursor)-30.0)<0.001, "Huge finite diagonal motion normalizes without overflow")
	model.clear_input()
	model.reset()
	model.move_cursor_to(Vector2(80,100))
	model.begin_tool()
	for i in 520:
		model.move_cursor_to(Vector2(80+i%2,100+i*0.1))
	expect(model.snapshot().current_stroke.size() == 512, "Point cap never grows unbounded preview")
	model.release_tool()
	expect(model.snapshot().selected_strokes.is_empty(), "Overfull stroke cannot silently lose points and commit")
	model.reset()
	for i in 10:
		draw(model,PackedVector2Array([Vector2(80,100+i*10),Vector2(100,100+i*10)]),false)
	expect(model.snapshot().selected_strokes.size() == 8 and model.snapshot().undo_available == 8, "Per-piece stroke and undo histories have fixed bounds")
	for i in 10:
		model.undo()
	expect(model.snapshot().selected_strokes.is_empty() and model.snapshot().mistakes == 8 and model.snapshot().participated, "Only available last-eight operations undo and participation remains")
	for i in 100:
		draw(model,PackedVector2Array([Vector2(80,100),Vector2(100,100)]),false)
		model.undo()
	expect(model.snapshot().undo_available == 0 and model.snapshot().mistakes == 108 and model.snapshot().score == 0, "Retry count is unrestricted while history stays bounded and score floors at zero")
	model.reset(true)
	model.move_cursor_to(guide[0]+Vector2(0.5,0.5))
	expect(model.snapshot().cursor.distance_to(guide[0]) < 1.0, "Assistance only snaps the supplied cursor near a real guide")
	expect(not model.snapshot().cutting and not model.snapshot().participated, "Snapping cannot draw automatically")

func _network_tests(model) -> void:
	model.reset()
	for i in 4:
		cut_piece(model,i)
	assemble(model,false)
	select(model,3)
	model.place_selected(Vector2(600,350))
	model.begin_tool()
	model.step(0.25)
	var state: Dictionary = model.snapshot()
	expect(state.output_omega > 0 and absf(state.output_travel-0.5)<0.000001, "Detached fourth wheel does not alter ordinary signed speed or travel")
	model.release_tool()
	advance(model,0.5)
	expect(model.snapshot().output_travel == state.output_travel, "Release and idle retain progress without adding rotation")
	model.place_selected(Vector2(600,350))
	expect(model.snapshot().output_travel == state.output_travel and model.snapshot().parts[3].mounted, "An identical placement preserves progress")
	model.move_cursor_to(Vector2(600,350))
	model.fold_or_mount()
	expect(model.snapshot().output_travel == 0.0 and not model.snapshot().parts[3].mounted, "Unmount is a structural progress reset")
	var r := radii(model.snapshot())
	model.place_selected(Vector2(320,220-r[1]-r[3]))
	model.begin_tool()
	advance(model,4.0)
	expect(model.snapshot().success and not model.snapshot().devil and model.snapshot().score == 400, "Dangling branch rotates but never earns path idler qualification")
	model.reset(false,1)
	for i in 4:
		cut_piece(model,i)
	assemble(model,true)
	model.begin_tool()
	model.step(0.25)
	expect(absf(model.snapshot().output_omega+1.75)<0.000001 and absf(model.snapshot().output_travel-0.4375)<0.000001, "Inserted idler changes output direction and retains tooth-count ratio")
	var angle_before: float = model.snapshot().parts[2].angle
	model.step(0.25)
	expect(absf(wrapf(model.snapshot().parts[2].angle-angle_before,-PI,PI)+0.4375)<0.0001, "Output angle and progress share actual speed integral")
	model.clear_input()
	var retained: float = model.snapshot().output_travel
	model.step(0.25)
	expect(model.snapshot().output_travel == retained, "Pause-style clear_input preserves completed angle travel")
	model.undo()
	expect(model.snapshot().output_travel == 0.0, "Undo cannot stitch output progress across structures")
	model.reset()
	for i in 4:
		cut_piece(model,i)
	assemble(model,false)
	r = radii(model.snapshot())
	select(model,3)
	model.place_selected(circle_intersection(Vector2(200,220),r[0]+r[3],Vector2(320,220),r[1]+r[3]))
	model.begin_tool()
	advance(model,1.0)
	expect(model.snapshot().output_travel == 0.0 and model.snapshot().mistakes == 1, "Closed odd contact cycle jams once per held attempt")
	advance(model,1.0)
	expect(model.snapshot().mistakes == 1, "Held invalid drive does not charge per-frame mistakes")
	model.release_tool()
	model.begin_tool()
	model.step(0.25)
	expect(model.snapshot().mistakes == 2, "Release and retry constitutes a second jam attempt")
	model.reset()
	for i in 3:
		cut_piece(model,i)
	assemble(model,false)
	select(model,1)
	model.place_selected(Vector2(200,220))
	model.begin_tool()
	model.step(0.25)
	expect(model.snapshot().output_travel == 0.0, "Overlapping gear centers cannot transmit")
	model.place_selected(Vector2(320,330))
	model.begin_tool()
	model.step(0.25)
	expect(model.snapshot().output_travel == 0.0, "Separated gear teeth cannot transmit")
	select(model,0)
	model.place_selected(Vector2(210,220))
	model.begin_tool()
	model.step(0.25)
	expect(model.snapshot().output_travel == 0.0, "Input must actually engage its shaft")
	var old_position: Vector2 = model.snapshot().parts[0].position
	model.place_selected(Vector2(1.0e30,1.0e30))
	model.place_selected(Vector2(NAN,0))
	expect(model.snapshot().parts[0].position == old_position, "Nonfinite/outside assembly input cannot relocate material")
	# Public free-drawn enlarged teeth make an incompatible actual module.
	model.reset()
	var geo = load("res://game/minigames/chocolate_etching_geometry.gd")
	var enlarged: PackedVector2Array = geo.template(Vector2(160,190),12)
	for i in enlarged.size():
		enlarged[i] += (enlarged[i]-Vector2(160,190)).normalized()*4.0
	enlarged = geo.offset(enlarged,1.75,Vector2(160,190))
	draw(model,enlarged)
	draw(model,enlarged)
	model.fold_or_mount()
	cut_piece(model,1)
	cut_piece(model,2)
	assemble(model,false)
	model.begin_tool()
	model.step(0.25)
	state = model.snapshot()
	expect(state.parts[0].freed and absf(state.parts[0].module-state.parts[1].module)/maxf(state.parts[0].module,state.parts[1].module)>0.06 and state.output_travel == 0.0, "Actual enlarged profile module mismatch prevents contact")

func _deadline_tests(model) -> void:
	model.reset()
	model.toggle_phase()
	model.begin_tool()
	advance(model,241.0)
	expect(model.snapshot().ended and not model.snapshot().ordinary_eligible and model.snapshot().elapsed == 240.0, "Empty idle driving reaches fixed deadline without participation reward")
	model.reset()
	draw(model,PackedVector2Array([Vector2(80,100),Vector2(100,100)]),false)
	advance(model,241.0)
	expect(model.snapshot().ended and model.snapshot().ordinary_eligible and not model.snapshot().success, "Actual unfinished cut is eligible only on natural formal end")
	for extra in [-0.02,0.02]:
		model.reset()
		for i in 3:
			cut_piece(model,i)
		assemble(model,false)
		advance(model,240.0-PI+extra)
		model.begin_tool()
		advance(model,4.0)
		expect(model.snapshot().success == (extra < 0) and model.snapshot().elapsed <= 240.0, "Only real pre-deadline output integral wins the cutoff bracket")
		print("CUTOFF extra=%.3f success=%s travel=%.9f elapsed=%.9f" % [extra,model.snapshot().success,model.snapshot().output_travel,model.snapshot().elapsed])

func _boundary_tests(model) -> void:
	model.reset()
	model.move_cursor_to(Vector2(80,100))
	model.begin_tool()
	model.set_motion(Vector2.RIGHT)
	advance(model,1.0)
	model.set_motion(Vector2.DOWN)
	advance(model,0.25)
	model.clear_input()
	expect(not model.snapshot().participated, "Keyboard motion preview cancels without committing")
	model.move_cursor_to(Vector2(80,100))
	model.begin_tool()
	model.set_motion(Vector2.RIGHT)
	advance(model,1.0)
	model.set_motion(Vector2.DOWN)
	advance(model,0.25)
	model.set_motion(Vector2.ZERO)
	model.release_tool()
	var sampled: PackedVector2Array = model.snapshot().selected_strokes[0].points
	expect(sampled.size() < 60 and sampled.has(Vector2(200,100)) and sampled[-1] == Vector2(200,130), "Short collinear sampling preserves the true corner and final endpoint")
	for assisted in [false,true]:
		for helper in [false,true]:
			model.reset(assisted)
			model.adjust_depth(1)
			if helper:
				model.toggle_helper()
			cut_piece(model,0,0,1)
			expect(model.snapshot().parts[0].freed == (assisted or helper), "Three-quarter depth obeys actual assisted/second-clamp threshold")
	model.reset()
	model.toggle_helper()
	for line in [PackedVector2Array([Vector2(61,71),Vector2(71,71)]),PackedVector2Array([Vector2(649,71),Vector2(639,71)]),PackedVector2Array([Vector2(61,399),Vector2(71,399)]),PackedVector2Array([Vector2(649,399),Vector2(639,399)])]:
		draw(model,line,false)
	expect(model.snapshot().helper_clamp == null, "No uncut board corner means no second clamp benefit")
	model.adjust_depth(1)
	cut_piece(model,0,0,1)
	expect(not model.snapshot().parts[0].freed, "Enabled helper with no real clamp does not lower fold threshold")
	model.reset()
	var guide: PackedVector2Array = model.snapshot().selected_guides[0]
	model.move_cursor_to(guide[0])
	model.begin_tool()
	model.move_cursor_to(Vector2(800,200))
	model.move_cursor_to(guide[0])
	model.release_tool()
	expect(not model.snapshot().participated and model.snapshot().selected_strokes.is_empty(), "Outside stroke is cancelled rather than clipped into a phantom cut")
	model.reset()
	for i in 4:
		cut_piece(model,i)
	expect(model.snapshot().undo_available == 8, "Twelve material operations retain only last eight undo entries")
	for i in 8:
		model.undo()
	expect(model.snapshot().parts[0].freed and not model.snapshot().parts[1].freed and model.snapshot().selected_strokes.is_empty(), "Oldest committed main gear survives bounded undo horizon")
	for assisted in [false,true]:
		model.reset(assisted)
		for i in 3:
			cut_piece(model,i)
		assemble(model,false)
		var state: Dictionary = model.snapshot()
		var r := radii(state)
		var half_span: float = (state.pins[1].x-state.pins[0].x)*0.5
		var tolerance := 6.0 if assisted else 3.0
		for excess in [-0.02,0.02]:
			var distance: float = r[0]+r[1]+tolerance+excess
			var height := sqrt(distance*distance-half_span*half_span)
			select(model,1)
			# Move away first so this is placement, not the public three-unit unmount gesture.
			model.place_selected(Vector2(320,350))
			model.place_selected(Vector2(320,220-height))
			model.begin_tool()
			model.step(0.25)
			expect((model.snapshot().output_travel>0)==(excess<0), "Measured contact brackets mode distance tolerance")
			print("CONTACT assisted=%s excess=%.3f travel=%.6f" % [assisted,excess,model.snapshot().output_travel])
			model.release_tool()
	model.reset()
	for i in 3:
		cut_piece(model,i)
	assemble(model,false)
	model.begin_tool()
	model.step(0.25)
	var parts: Array = model.snapshot().parts
	for edge in model.snapshot().connections:
		var a: Dictionary = parts[edge.x]
		var b: Dictionary = parts[edge.y]
		var theta: float = (b.position-a.position).angle()
		var phase_a: float = PI/2.0-PI/a.teeth
		var phase_b: float = PI/2.0-PI/b.teeth
		var residual: float = wrapf(a.teeth*(a.angle+phase_a-theta)+b.teeth*(b.angle+phase_b-theta-PI)-PI,-PI,PI)
		expect(absf(residual)<0.00001, "Contact line tooth phase constraint survives actual angular integration")

func _review_round_one(model) -> void:
	var geo = load("res://game/minigames/chocolate_etching_geometry.gd")
	model.reset(true)
	var guide: PackedVector2Array = model.snapshot().selected_guides[0]
	var blank := PackedVector2Array()
	var center := Vector2(160,190)
	for i in guide.size():
		var a := guide[i]-center
		var b := guide[(i+1)%guide.size()]-center
		if a.length() < 47.6 and b.length() > 47.6:
			var edge := b-a
			var t := (-a.dot(edge)+sqrt(pow(a.dot(edge),2)-edge.length_squared()*(a.length_squared()-47.6*47.6)))/edge.length_squared()
			blank.append(center+a+edge*t)
	expect(blank.size()==12, "Review counterexample is twelve actual guide-flank intersections")
	draw(model,blank)
	draw(model,blank)
	model.fold_or_mount()
	expect(not model.snapshot().parts[0].freed, "R1 assisted convex twelve-gon cannot masquerade as teeth")
	var missing_tooth: PackedVector2Array = geo.template(center,12)
	for i in [0,3]:
		missing_tooth[i]=center+(missing_tooth[i]-center).normalized()*44.5
	for i in [1,2]:
		missing_tooth[i]=center+(missing_tooth[i]-center).normalized()*46.8
	expect(geo.measure(missing_tooth,center,12,true).is_empty(), "R1 one low-prominence tooth fails even within assisted radial bands")
	for direction in [-1.0,1.0]:
		model.reset(true)
		guide=model.snapshot().selected_guides[0]
		var start := (guide[1]+guide[2])*0.5
		var tangent := (guide[2]-guide[1]).normalized()
		var normal: Vector2 = Vector2(-tangent.y,tangent.x)*direction
		model.move_cursor_to(start)
		model.set_motion(normal)
		advance(model,0.5)
		expect((model.snapshot().cursor-start).dot(normal)>45.0, "R2 assisted relative motion escapes the snap band in both directions")
	model.reset()
	model.set_motion(Vector2.RIGHT)
	model.cancel_tool()
	var stopped: Vector2=model.snapshot().cursor
	model.step(0.25)
	expect(model.snapshot().cursor==stopped, "R3 public cancellation clears held motion")
	model.reset()
	draw(model,PackedVector2Array([Vector2(158,190),Vector2(163,190)]),false)
	expect(model.snapshot().selected_strokes.size()==1 and model.snapshot().undo_available==1 and not model.snapshot().participated, "R4 short physical scratch commits without participation")
	cut_piece(model,0)
	expect(not model.snapshot().parts[0].freed, "R4 five-unit interior kerf prevents intact extraction")
	model.reset()
	draw(model,PackedVector2Array([Vector2(158,190),Vector2(163,190)]),false)
	model.undo()
	expect(model.snapshot().selected_strokes.is_empty() and model.snapshot().mistakes==1, "R4 short scratch is a real undoable edit")
	cut_piece(model,0)
	expect(model.snapshot().parts[0].freed, "R4 undo actually restores scratched material")
	model.reset()
	draw(model,PackedVector2Array([Vector2(158,190),Vector2(163,190)]),false)
	advance(model,241.0)
	expect(model.snapshot().ended and not model.snapshot().ordinary_eligible, "R4 short-only timeout is not participated")
	model.reset()
	for i in 3:
		cut_piece(model,i)
	assemble(model,false)
	model.begin_tool()
	model.step(0.25)
	model.toggle_phase()
	select(model,3)
	draw(model,PackedVector2Array([Vector2(80,100),Vector2(85,100)]),false)
	expect(model.snapshot().output_travel==0.0 and model.snapshot().selected_strokes.size()==1, "R4 short committed scratch resets structural travel")
	for size in [0.008,0.012,0.02]:
		var square := PackedVector2Array([Vector2(330,318),Vector2(330+size,318),Vector2(330+size,318+size),Vector2(330,318+size)])
		var represented: float = (float(square[1].x)-float(square[0].x))*(float(square[2].y)-float(square[1].y))
		for reverse in [false,true]:
			if reverse:
				square.reverse()
			expect(absf(geo.area(square)-represented)<1.0e-12, "R5 board-coordinate represented area is stable in both windings")
			expect(geo.overlaps(square,square)==(represented>0.0001), "R5 overlap respects the stated area threshold")
	model.reset()
	expect(model.snapshot().connections.is_typed() and model.snapshot().connections.get_typed_builtin()==TYPE_VECTOR2I, "R6 empty contact array has the public Vector2i element type")
	for i in 3:
		cut_piece(model,i)
	assemble(model,false)
	var contacts: Array=model.snapshot().connections
	expect(contacts.is_typed() and contacts.get_typed_builtin()==TYPE_VECTOR2I and contacts==[Vector2i(0,1),Vector2i(1,2)], "R6 rebuilt contact array retains its type and deterministic order")
	model.reset()
	var asymmetric: PackedVector2Array=geo.template(center,12)
	asymmetric.insert(28,center+Vector2.from_angle(PI/2.0-PI/12.0+TAU*9.15/12.0)*90.0)
	asymmetric=geo.offset(asymmetric,1.75,center)
	draw(model,asymmetric)
	draw(model,asymmetric)
	model.fold_or_mount()
	expect(model.snapshot().parts[0].freed, "R7 asymmetric regression uses an actually extracted valid gear")
	model.toggle_phase()
	model.place_selected(Vector2(200,65))
	expect(not model.snapshot().parts[0].mounted, "R7 full-turn envelope rejects horizontal protrusion near top canvas edge")
	model.place_selected(Vector2(200,100))
	expect(model.snapshot().parts[0].mounted, "R7 the same actual asymmetric gear fits at a safe center")
	model.reset()
	draw(model,PackedVector2Array([Vector2(100,100),Vector2(100.00005,100)]),false)
	expect(model.snapshot().selected_strokes.size()==1 and not model.snapshot().participated, "R4 every represented nonzero scratch survives, even below sampling epsilon")
	model.reset()
	draw(model,PackedVector2Array([Vector2(100,100),Vector2(103,100),Vector2(101.5,102.598)]),false)
	expect(model.snapshot().participated and model.snapshot().selected_strokes[0].points.size()==4, "R4 actual added closing segment contributes to committed material length")
	var hole := PackedVector2Array([Vector2(102,99),Vector2(108,99),Vector2(108,101),Vector2(102,101)])
	expect(is_equal_approx(geo.material_length(PackedVector2Array([Vector2(100,100),Vector2(110,100)]),[hole]),4.0), "R4 length through removed material is excluded from participation length")
	model.reset(true)
	guide=model.snapshot().selected_guides[0]
	model.move_cursor_to((guide[1]+guide[2])*0.5)
	model.set_motion(Vector2.RIGHT)
	model.step(0.05)
	model.move_cursor_to(Vector2(80,100))
	model.begin_tool()
	model.step(0.1)
	model.release_tool()
	var released: Vector2=model.snapshot().cursor
	model.step(0.1)
	expect(model.snapshot().participated and model.snapshot().cursor.distance_to(released)>10.0, "R2/R3 absolute move rebases anchor and valid begin/release preserves held movement")
	for transition in ["cycle_piece","toggle_phase","undo"]:
		model.call(transition)
		stopped=model.snapshot().cursor
		model.step(0.1)
		expect(model.snapshot().cursor==stopped, "R2/R3 transition synchronizes anchor and stops movement: "+transition)
		model.set_motion(Vector2.RIGHT)

func _review_round_two(model) -> void:
	var geo = load("res://game/minigames/chocolate_etching_geometry.gd")
	var a := Vector2(100,100)
	var b := Vector2(103.99999,100)
	var c := Vector2(100,100.00005)
	model.reset()
	draw(model,PackedVector2Array([a,b,c]),false)
	var stroke: PackedVector2Array=model.snapshot().selected_strokes[0].points
	expect(stroke==PackedVector2Array([a,b,c,a]), "R4 round2 retains exact final sample before appending the real closure")
	var expected_length := a.distance_to(b)+b.distance_to(c)+c.distance_to(a)
	expect(absf(geo.material_length(stroke,[])-expected_length)<1.0e-12 and expected_length>8.0, "R4 round2 represented closed scratch is above eight units")
	expect(model.snapshot().participated, "R4 round2 exact near-start closure earns genuine participation")
	advance(model,241.0)
	expect(model.snapshot().ordinary_eligible, "R4 round2 qualifying near-start scratch retains ordinary timeout eligibility")
	for interior_count in [509,510]:
		model.reset()
		model.move_cursor_to(a)
		model.begin_tool()
		for i in range(1,interior_count+1):
			model.move_cursor_to(Vector2(100+4*(i%2),100+i*0.001))
		model.move_cursor_to(c)
		expect(model.snapshot().current_stroke.size()==interior_count+2, "R4 round2 capacity fixture retains all real reversing samples")
		model.release_tool()
		var state: Dictionary=model.snapshot()
		if interior_count==509:
			stroke=state.selected_strokes[0].points
			expect(stroke.size()==512 and stroke[-2]==c and stroke[-1]==a, "R4 round2 final available slot holds closure without overwriting endpoint")
		else:
			expect(state.selected_strokes.is_empty() and state.undo_available==0 and not state.participated and state.feedback=="封口需額外一點；請先撤銷", "R4 round2 full-cap closure fails explicitly without discarding a sample or raising cap")

func _assisted_geometry_precision(model) -> void:
	var geo = load("res://game/minigames/chocolate_etching_geometry.gd")
	var pairs := [
		[Vector2(203.350433349609,175.808456420898),Vector2(202.085968017578,176.940689086914),Vector2(201.142150878906,177.785827636719),Vector2(199.245437622070,179.484222412109)],
		[Vector2(208.564117431641,208.860122680664),Vector2(209.828582763672,209.992355346680),Vector2(210.772399902344,210.837493896484),Vector2(212.669113159180,212.535888671875)]]
	for pair in pairs:
		var expected: float = pair[1].distance_to(pair[2])
		for reverse_a in [false,true]:
			for reverse_b in [false,true]:
				var a: Vector2 = pair[1] if reverse_a else pair[0]
				var b: Vector2 = pair[0] if reverse_a else pair[1]
				var c: Vector2 = pair[3] if reverse_b else pair[2]
				var d: Vector2 = pair[2] if reverse_b else pair[3]
				expect(absf(geo.segment_distance(a,b,c,d)-expected)<0.00001 and absf(geo.segment_distance(c,d,a,b)-expected)<0.00001, "Core3 disjoint captured segments retain positive proper distance in both orders")
	for segments in [
		[Vector2(100,100),Vector2(110,110),Vector2(100,110),Vector2(110,100)],
		[Vector2(100,100),Vector2(110,100),Vector2(105,100),Vector2(115,100)],
		[Vector2(100,100),Vector2(110,100),Vector2(110,100),Vector2(110,110)]]:
		expect(geo.segment_distance(segments[0],segments[1],segments[2],segments[3])==0.0, "Core3 genuine crossings, collinear overlap and endpoint contact remain zero")
	expect(is_equal_approx(geo.segment_distance(Vector2(100,100),Vector2(110,100),Vector2(100,101),Vector2(110,101)),1.0), "Core3 parallel separated segments preserve their gap")
	var hole := PackedVector2Array([Vector2(102,99),Vector2(108,99),Vector2(108,101),Vector2(102,101)])
	expect(is_equal_approx(geo.material_length(PackedVector2Array([Vector2(100,100),Vector2(110,100)]),[hole]),4.0), "Core3 shared material intersection retains actual removed intervals")
	expect(is_equal_approx(geo.material_length(PackedVector2Array([Vector2(100,98),Vector2(110,98)]),[hole]),10.0), "Core3 disjoint material line receives no fabricated intersections")
	var replay = JSON.parse_string(FileAccess.get_file_as_string("res://game/tests/chocolate_assisted_keyboard_replay.json"))
	expect(replay is Dictionary and replay.variants.size()==2, "Core3 exact captured A/B replay fixture is loaded")
	var tiny := Vector2(110,100.000015258789)
	var expected_contour := PackedVector2Array([Vector2(100,100),Vector2(110,100),tiny,Vector2(110,110),Vector2(100,110)])
	var duplicate_contour := expected_contour.duplicate()
	duplicate_contour.insert(2,Vector2(110,100))
	duplicate_contour.append(duplicate_contour[0])
	expect(geo._offset_contour(duplicate_contour,Vector2(105,105))==expected_contour, "Core3 generated output drops only exact consecutive/closing duplicates and retains one-ULP edges")
	expect(not geo.simple(expected_contour), "Core3 original drawn-input EPS spacing rule remains unchanged")
	for invalid in [
		PackedVector2Array([Vector2(100,100),Vector2(112,110),Vector2(100,110),Vector2(110,100)]),
		PackedVector2Array([Vector2(100,100),Vector2(110,100),Vector2(110,110),Vector2(105,105),Vector2(100,110),Vector2(105,105)]),
		PackedVector2Array([Vector2(100,100),Vector2(110,100),Vector2(105,100),Vector2(110,110),Vector2(100,110)])]:
		expect(geo.area(invalid)>1.0 and geo._offset_contour(invalid,Vector2(105,105)).is_empty(), "Core3 generated-output handling still rejects real crossings, nonadjacent touches and overlapping backtracks")
	for variant in replay.variants:
		model.reset(true,0 if variant.variant=="A" else 1)
		model.adjust_depth(-1)
		for stroke_index in variant.strokes.size():
			var line := PackedVector2Array()
			for point in variant.strokes[stroke_index]:
				line.append(Vector2(point[0],point[1]))
			draw(model,line,false)
			expect(line[0]==line[-1] and line.size()<=512, "Core3 captured closure and point budget remain unchanged")
			var candidate := line.slice(0,line.size()-1)
			expect(geo.simple(candidate), "Core3 actual held-key contour is simple: %s stroke%d" % [variant.variant,stroke_index+1])
			for distance in [-1.1875,1.1875]:
				var raw := Geometry2D.offset_polygon(candidate,distance,Geometry2D.JOIN_MITER)
				expect(raw.size()==1, "Core3 raw captured offset is genuinely a singleton")
				if raw.size()!=1:
					continue
				var canonical := PackedVector2Array()
				for point in raw[0]:
					if canonical.is_empty() or canonical[-1]!=point:
						canonical.append(point)
				if canonical.size()>1 and canonical[0]==canonical[-1]:
					canonical.remove_at(canonical.size()-1)
				var retained: PackedVector2Array = geo.offset(candidate,distance,Vector2(160,190))
				expect(not retained.is_empty() and Geometry2D.is_point_in_polygon(Vector2(160,190),retained), "Core3 captured singleton offset has valid true topology and contains its center")
				expect(retained==canonical and geo.area(retained)==geo.area(raw[0]), "Core3 exact duplicate-only generated canonicalization preserves every nonzero point and area")
				print("CAPTURED_OFFSET variant=%s stroke=%d distance=%.4f candidate=%d raw_components=%d raw_vertices=%d area=%.9f retained=%d" % [variant.variant,stroke_index+1,distance,candidate.size(),raw.size(),raw[0].size(),geo.area(raw[0]),retained.size()])
		model.fold_or_mount()
		var state: Dictionary = model.snapshot()
		expect(state.parts[0].freed and state.mistakes==0 and state.selected_strokes.size()==3, "Core3 public replay of captured point inputs passes real depth, kerf and profile extraction")
		print("CAPTURED_PUBLIC_FOLD variant=%s freed=%s outline=%d radius=%.9f mistakes=%d feedback=%s" % [variant.variant,state.parts[0].freed,state.parts[0].outline.size(),state.parts[0].pitch_radius,state.mistakes,state.feedback])
