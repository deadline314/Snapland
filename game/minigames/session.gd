extends Control
## Self-contained welcome-park minigame session. Each game keeps its own state and
## input rule; this node only supplies the shared HUD, retry, exit and result contract.

signal finished(result: Dictionary)
signal cancelled
signal note_played(note: int)
signal feedback(kind: String)
signal help_requested(game_id: String)

const ROUND_SECONDS := 60.0
const BG := Color("#172d49")
const CREAM := Color("#fff5dc")
const MINT := Color("#70e1c1")
const PINK := Color("#ff83aa")
const YELLOW := Color("#ffd166")
const BLUE := Color("#79bdff")
const FONT: Font = preload("res://assets/fonts/NotoSansCJKtc-Regular.otf")
const FLOWER_ROUTE: Array[int] = [0, 4, 5, 6, 10, 14, 15]
const PIPE_DIRS: Array[Vector2i] = [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
const PIPE_BITS: Array[int] = [1,2,4,8]
const CROWD_COLORS: Array[Color] = [Color("#ff83aa"), Color("#79bdff"), Color("#ffd166"), Color("#70e1c1")]
const DESIGN_SIZE := Vector2(1280, 720)
const INK := Color("#243b50")
const SEA := Color("#55b8ad")
const GOLD := Color("#b77c45")
const PAPER := Color("#fff2d4")
const TimeOfDayScript = preload("res://game/core/time_of_day.gd")
const MinigameHUDScript = preload("res://game/ui/minigame_hud.gd")
const AvatarRendererScript = preload("res://game/world/avatar_renderer.gd")
const FountainJumpViewScript = preload("res://game/minigames/fountain_jump_view.gd")
const BalloonHarborScript = preload("res://game/minigames/balloon_harbor_view.gd")
const PipePlanScript = preload("res://game/minigames/pipe_plan_view.gd")
const PipeRoundScript = preload("res://game/minigames/pipe_round_model.gd")
const CrowdTrafficScript = preload("res://game/minigames/crowd_traffic_model.gd")
const CrowdCrossingScript = preload("res://game/minigames/crowd_crossing_view.gd")
const CrowdSemaphoreScript = preload("res://game/minigames/crowd_semaphore_view.gd")
const KiteFlightModelScript = preload("res://game/minigames/kite_flight_model.gd")
const KiteFlightViewScript = preload("res://game/minigames/kite_flight_view.gd")
const BubblePhotoModelScript = preload("res://game/minigames/bubble_photo_model.gd")
const BubblePhotoViewScript = preload("res://game/minigames/bubble_photo_view.gd")
const SignBalanceModelScript = preload("res://game/minigames/sign_balance_model.gd")
const SignBalanceViewScript = preload("res://game/minigames/sign_balance_view.gd")
const HatRescueModelScript = preload("res://game/minigames/hat_rescue_model.gd")
const HatRescueViewScript = preload("res://game/minigames/hat_rescue_view.gd")
const MelodyMemoryModelScript = preload("res://game/minigames/melody_memory_model.gd")
const MelodyMemoryViewScript = preload("res://game/minigames/melody_memory_view.gd")
const ShadowTheatreModelScript = preload("res://game/minigames/shadow_theatre_model.gd")
const ShadowTheatreViewScript = preload("res://game/minigames/shadow_theatre_view.gd")
const BenchSwapModelScript = preload("res://game/minigames/bench_swap_model.gd")
const BenchSwapViewScript = preload("res://game/minigames/bench_swap_view.gd")
const RibbonRhythmModelScript = preload("res://game/minigames/ribbon_rhythm_model.gd")
const RibbonRhythmViewScript = preload("res://game/minigames/ribbon_rhythm_view.gd")
const BALLOON_MAILBOXES: Array[Vector2] = [Vector2(520, 305), Vector2(820, 480), Vector2(1080, 320)]
const BALLOON_WIND_FORECAST_SECONDS := 0.8
const BALLOON_MAX_SPEED := 260.0
const BALLOON_ACCELERATION := 520.0
const BALLOON_BRAKE_ACCELERATION := 680.0
const BALLOON_DOCK_RADIUS := 66.0
const BALLOON_DOCK_SPEED := 68.0
const BALLOON_DOCK_HOLD_SECONDS := 0.5
const BALLOON_WIND_SCALE := 1.0
const BALLOON_ASSIST_DOCK_RADIUS := 88.0
const BALLOON_ASSIST_DOCK_SPEED := 102.0
const BALLOON_ASSIST_WIND_SCALE := 0.72
const FOUNTAIN_PERIOD := 1.35
const FOUNTAIN_FIRST_BEAT := 1.0
const FOUNTAIN_PERFECT_WINDOW := 0.07
const FOUNTAIN_GOOD_WINDOW := 0.16
const FOUNTAIN_HIT_WINDOW := 0.22
const FOUNTAIN_ASSIST_PERFECT_WINDOW := 0.11
const FOUNTAIN_ASSIST_GOOD_WINDOW := 0.24
const FOUNTAIN_ASSIST_HIT_WINDOW := 0.34
const FOUNTAIN_TIMING_EPSILON := 0.0005
const FOUNTAIN_JUMP_DURATION := 8.0 / 12.0
const FOUNTAIN_LANDING_SETTLE_SECONDS := 0.07
const FOUNTAIN_POSE_CACHE_META := "_snapland_fountain_pose_cache"
const FOUNTAIN_RENDERER_META := "_snapland_fountain_avatar_renderer"
const FOUNTAIN_POSE_CACHE_LIMIT := 4
const REQUIRED_PROP_KEYS: Array[String] = ["balloon", "mailbox", "kite", "urchin", "hat", "visitor", "mascot", "lantern", "tourist_coral", "tourist_blue", "tourist_gold", "tourist_green", "flower_horn", "camera", "sign", "bench"]
const BACKDROP_SCENES: Array[String] = ["harbor", "garden", "stage", "night"]
static var _catalog_cache: Array = []
static var _catalog_loaded := false
static var _backdrop_texture: Texture2D
static var _backdrop_checked := false
static var _backdrop_warning_emitted := false
static var _scene_textures: Dictionary = {}
static var _props_atlas: Texture2D
static var _prop_regions: Dictionary = {}
static var _prop_textures: Dictionary = {}
static var _props_checked := false
static var _props_available := false
static var _props_warning_emitted := false

var game_id := ""
var mode := ""
var round_seconds := ROUND_SECONDS
var assisted := false
var elapsed := 0.0
var score := 0
var mistakes := 0
var devil_progress := 0
var ended := false
var won := false
var devil_won := false
var paused := false
var _discard_next_delta := false
var practice_mode := false
var minigame_hud: Control
var presentation: Control
var presentation_mode := ""
var _fountain_output: TextureRect
var pipe_connected := false
var pipe_finish_at := -1.0
var pipe_model: RefCounted = PipeRoundScript.new()
var crowd_model: RefCounted = CrowdTrafficScript.new()
var kite_model: RefCounted = KiteFlightModelScript.new()
var bubble_model: RefCounted = BubblePhotoModelScript.new()
var sign_model: RefCounted = SignBalanceModelScript.new()
var hat_model: RefCounted = HatRescueModelScript.new()
var melody_model: RefCounted = MelodyMemoryModelScript.new()
var ribbon_model: RefCounted = RibbonRhythmModelScript.new()
var melody_snapshot: Dictionary = {}
var _melody_audio_cursor := 0
var _melody_error_cursor := 0
var _melody_last_event := ""
var shadow_model: RefCounted = ShadowTheatreModelScript.new()
var _shadow_frame_delta := 1.0 / 60.0
var _shadow_left_held := false
var _shadow_right_held := false
var _shadow_near_held := false
var _shadow_far_held := false
var bench_model: RefCounted = BenchSwapModelScript.new()
var _bench_score_published := 0
var _bench_last_event := ""
var _sign_stage_cursor := 0
var _sign_impact_cursor := 0
var _bubble_photo_cursor := 0
var _kite_marker_cursor := 0
var _kite_up_held := false
var _kite_down_held := false
var _kite_boost_held := false
var _kite_reel_held := false
var _crowd_event_cursor := 0
var _hat_ledger_cursor := 0
var _hat_left_held := false
var _hat_right_held := false
var _ribbon_snapshot: Dictionary = {}
var _ribbon_note_cursor := 0
var _ribbon_score_cursor := 0
var _ribbon_error_cursor := 0
var _ribbon_last_event := ""
var _fountain_avatar_renderer: RefCounted
var _fountain_jump_textures: Array[Texture2D] = []
var _fountain_idle_texture: Texture2D
var score_events: Array[Dictionary] = []
var _hud_refresh_clock := 1.0
var _hud_dirty := true
const HUD_REFRESH_INTERVAL := 0.1
var game_time := 0.0
var rng := RandomNumberGenerator.new()
var p := Vector2(270, 390)
var target := Vector2(1010, 360)
var mouse_steering := false
var steering_target := Vector2.ZERO
var balloon_started := false
var balloon_tutorial_seen := false
var balloon_intro_step := 0
var balloon_intro_step_clock := 0.0
var balloon_braking := false
var balloon_delivery_index := 0
var balloon_dock_hold := 0.0
var balloon_dock_miss_latched := false
var balloon_hazard_cooldown := 0.0
var balloon_wind_current := Vector2.ZERO
var balloon_wind_forecast := Vector2.ZERO
var balloon_wind_scale := BALLOON_WIND_SCALE
var balloon_dock_radius := BALLOON_DOCK_RADIUS
var balloon_dock_speed := BALLOON_DOCK_SPEED
var velocity := Vector2.ZERO
var phase := 0.0
var beat := 0
var beat_window := false
var fountain_attempts := 0
var fountain_jump_started := -1.0
var fountain_finish_pending := false
var fountain_finish_at := -1.0
const RIBBON_FINISH_DANCE_SECONDS := 1.30
const RIBBON_REDUCED_FINISH_SECONDS := 0.18
var ribbon_finish_pending := false
var ribbon_finish_elapsed := 0.0
var ribbon_finish_duration := RIBBON_FINISH_DANCE_SECONDS
var ribbon_finish_success := false
var ribbon_finish_devil := false
var fountain_grades: Array[String] = []
var fountain_errors_ms: Array[int] = []
var feedback_color := MINT
var reduced_motion := false
var time_phase := TimeOfDayScript.DEFAULT_PHASE
var phase_wash := Color(0.93,0.72,0.55,0.055)
var phase_shadow_color := Color(0.12,0.22,0.24,0.24)
var phase_shadow_x := 4.0
var feedback_age := 99.0
var feedback_origin := Vector2(640, 400)
var particles: Array[Dictionary] = []
var prompt := ""
var select_index := -1
var pipe_cursor := 0
var move_count := 0
var streak := 0
var count := 0
var lane := 0
var balance := 0.0
var alignment := 0.0
var alignment_hold := 0.0
var shadow_started := false
var shadow_broken := false
var seats: Array[int] = []
var flower_cells: Array[int] = []

static func definitions() -> Array:
	if not _catalog_loaded:
		_catalog_loaded = true
		var file := FileAccess.open("res://game/data/welcome_games.json", FileAccess.READ)
		if file:
			var parser := JSON.new()
			if parser.parse(file.get_as_text()) == OK and parser.data is Array:
				_catalog_cache = parser.data
	return _catalog_cache

func start(id: String, assisted_mode: bool = false) -> void:
	game_id = ""
	mode = ""
	if _catalog_cache.is_empty(): definitions()
	for item in _catalog_cache:
		if item is Dictionary and (item.get("id", "") == id or item.get("mode", "") == id):
			game_id = str(item.id)
			mode = str(item.mode)
			break
	if game_id.is_empty():
		ended = true
		prompt = "這款小遊戲暫時無法開啟"
		queue_redraw()
		cancelled.emit()
		return
	assisted = assisted_mode
	balloon_tutorial_seen = false
	var progress := get_node_or_null("/root/Progress")
	reduced_motion = progress != null and bool(progress.settings.get("reduced_motion", false))
	_rng_reset()
	reset_round()
	queue_redraw()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	grab_focus()
	minigame_hud = MinigameHUDScript.new()
	minigame_hud.name = "MinigameHUD"
	add_child(minigame_hud)
	minigame_hud.pause_requested.connect(func(): set_paused(true))
	minigame_hud.resume_requested.connect(func(): set_paused(false))
	minigame_hud.help_requested.connect(request_help)
	minigame_hud.details_requested.connect(func(): minigame_hud.set_score_details(score_summary()))
	minigame_hud.practice_requested.connect(func(): set_practice_mode(true))
	minigame_hud.retry_requested.connect(_retry_from_hud)
	minigame_hud.leave_requested.connect(_leave_from_hud)
	resized.connect(_layout_presentation)
	_sync_presentation()
	_refresh_hud()

func _sync_presentation() -> void:
	if not is_inside_tree(): return
	if presentation_mode != mode:
		if is_instance_valid(presentation):
			presentation.hide()
			presentation.queue_free()
		presentation = null
		_fountain_output = null
		presentation_mode = mode
		match mode:
			"balloon_delivery":
				# Headless rules tests do not allocate a renderer or GPU world.
				if DisplayServer.get_name() != "headless": presentation = BalloonHarborScript.new()
			"fountain_timing":
				# The 3D court has its own SubViewport; keep headless rules tests renderer-free.
				if DisplayServer.get_name() != "headless": presentation = FountainJumpViewScript.new()
			"flower_pipes": presentation = PipePlanScript.new()
			"crowd_traffic": presentation = CrowdSemaphoreScript.new()
			"kite_rings": presentation = KiteFlightViewScript.new()
			"bubble_photo":
				# Headless rule tests exercise the model without allocating avatar textures.
				if DisplayServer.get_name() != "headless": presentation = BubblePhotoViewScript.new()
			"sign_balance":
				if DisplayServer.get_name() != "headless": presentation = SignBalanceViewScript.new()
			"hat_catching":
				if DisplayServer.get_name() != "headless": presentation = HatRescueViewScript.new()
			"melody_memory":
				if DisplayServer.get_name() != "headless": presentation = MelodyMemoryViewScript.new()
			"shadow_alignment":
				if DisplayServer.get_name() != "headless": presentation = ShadowTheatreViewScript.new()
			"bench_swap": presentation = BenchSwapViewScript.new()
			"ribbon_rhythm": presentation = RibbonRhythmViewScript.new()
		if presentation != null:
			presentation.name = "GamePresentation"
			presentation.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(presentation)
			move_child(presentation, 0)
			if mode == "kite_rings":
				# Own play-surface mouse events before a fullscreen GUI ancestor stops
				# them. The later HUD sibling still receives its own buttons/overlays.
				presentation.mouse_filter = Control.MOUSE_FILTER_STOP
				presentation.gui_input.connect(_on_kite_presentation_input)
			if mode == "sign_balance":
				presentation.mouse_filter = Control.MOUSE_FILTER_STOP
				presentation.balance_requested.connect(_on_sign_balance_requested)
			if mode == "hat_catching":
				presentation.mouse_filter = Control.MOUSE_FILTER_STOP
				presentation.gui_input.connect(_on_hat_presentation_input)
				var hat_progress := get_node_or_null("/root/Progress")
				var hat_appearance: Dictionary = hat_progress.appearance if hat_progress != null and hat_progress.get("appearance") is Dictionary else {}
				var hat_equipped: Dictionary = hat_progress.equipped if hat_progress != null and hat_progress.get("equipped") is Dictionary else {}
				presentation.configure_avatar(hat_appearance, hat_equipped)
			if mode == "crowd_traffic":
				presentation.mouse_filter = Control.MOUSE_FILTER_STOP
				presentation.focus_mode = Control.FOCUS_ALL
				presentation.signal_requested.connect(_on_crowd_signal_requested)
			if mode == "melody_memory":
				presentation.mouse_filter = Control.MOUSE_FILTER_STOP
				presentation.note_requested.connect(_on_melody_note_requested)
				presentation.replay_requested.connect(_on_melody_replay_requested)
			if mode == "shadow_alignment":
				presentation.mouse_filter = Control.MOUSE_FILTER_STOP
				presentation.axis_requested.connect(_on_shadow_axis_requested)
				presentation.lamp_target_requested.connect(_on_shadow_lamp_target_requested)
				presentation.shutter_requested.connect(_on_shadow_shutter_requested)
			if mode == "bench_swap":
				presentation.mouse_filter = Control.MOUSE_FILTER_STOP
				presentation.seat_requested.connect(_on_bench_seat_requested)
				var bench_progress := get_node_or_null("/root/Progress")
				var bench_appearance: Dictionary = bench_progress.appearance if bench_progress != null and bench_progress.get("appearance") is Dictionary else {}
				var bench_equipped: Dictionary = bench_progress.equipped if bench_progress != null and bench_progress.get("equipped") is Dictionary else {}
				presentation.configure_avatar(bench_appearance, bench_equipped)
			if mode == "balloon_delivery": presentation.initialize()
			if mode == "fountain_timing":
				presentation.call("initialize")
				var fountain_progress := get_node_or_null("/root/Progress")
				var appearance: Dictionary = fountain_progress.appearance if fountain_progress != null and fountain_progress.get("appearance") is Dictionary else {}
				var equipped: Dictionary = fountain_progress.equipped if fountain_progress != null and fountain_progress.get("equipped") is Dictionary else {}
				presentation.call("configure_avatar", appearance, equipped)
				var fountain_texture := presentation.call("get_texture") as Texture2D
				_fountain_output = _attach_fountain_output(presentation, fountain_texture)
			if mode == "bubble_photo":
				presentation.initialize()
				var progress := get_node_or_null("/root/Progress")
				var appearance: Dictionary = progress.appearance if progress != null and progress.get("appearance") is Dictionary else {}
				var equipped: Dictionary = progress.equipped if progress != null and progress.get("equipped") is Dictionary else {}
				presentation.set_appearance(appearance, equipped)
				bubble_model.set_subject_size(presentation.measured_subject_size())
			if mode == "ribbon_rhythm":
				presentation.mouse_filter = Control.MOUSE_FILTER_STOP
				presentation.action_pressed.connect(_on_ribbon_action_pressed)
				presentation.action_released.connect(_on_ribbon_action_released)
				var ribbon_progress := get_node_or_null("/root/Progress")
				var ribbon_appearance: Dictionary = ribbon_progress.appearance if ribbon_progress != null and ribbon_progress.get("appearance") is Dictionary else AvatarRendererScript.DEFAULT_APPEARANCE
				var ribbon_equipped: Dictionary = ribbon_progress.equipped if ribbon_progress != null and ribbon_progress.get("equipped") is Dictionary else {"outfit": "outfit-tide", "hat": "hat-none"}
				presentation.configure_avatar(ribbon_appearance, ribbon_equipped)
				presentation.grab_focus()
			_layout_presentation()
	if not is_instance_valid(presentation): return
	match mode:
		"balloon_delivery":
			presentation.present(p, velocity, balloon_wind_current, balloon_wind_forecast, balloon_delivery_index, balloon_dock_hold, balloon_braking, phase, reduced_motion, time_phase, balloon_delivery_index, _balloon_hazard_at(phase), 65.0)
		"fountain_timing":
			presentation.call("update_frame", {"phase": phase, "fountain_attempts": fountain_attempts, "fountain_jump_started": fountain_jump_started, "beat_window": beat_window}, time_phase, reduced_motion)
		"flower_pipes":
			presentation.configure(reduced_motion, time_phase)
			presentation.set_animation_active(not paused)
			presentation.present_order(pipe_model.snapshot(), phase, reduced_motion, time_phase)
			presentation.cursor = pipe_cursor
		"crowd_traffic": presentation.present_traffic(crowd_model.snapshot(), crowd_model.elapsed, reduced_motion, time_phase)
		"kite_rings": presentation.update_frame(kite_model.snapshot(), "result" if ended else ("paused" if paused else "playing"), reduced_motion, time_phase)
		"bubble_photo": presentation.present_state(bubble_model.snapshot(), str(bubble_model.phase), reduced_motion, time_phase)
		"sign_balance": presentation.update_frame(sign_model.snapshot(), time_phase, reduced_motion)
		"hat_catching": presentation.update_frame(hat_model.snapshot(), time_phase, reduced_motion)
		"shadow_alignment": presentation.present_state(shadow_model.snapshot(), time_phase, reduced_motion)
		"melody_memory": presentation.update_frame(melody_snapshot, time_phase, reduced_motion)
		"bench_swap": presentation.update_frame(bench_model.snapshot(), time_phase, reduced_motion)
		"ribbon_rhythm": presentation.update_frame(_ribbon_snapshot, time_phase, reduced_motion)

func _layout_presentation() -> void:
	if not is_instance_valid(presentation): return
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	presentation.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	presentation.size = DESIGN_SIZE
	presentation.scale = Vector2.ONE * factor
	presentation.position = (size - DESIGN_SIZE * factor) * 0.5

func _attach_fountain_output(view: Control, texture: Texture2D) -> TextureRect:
	if texture == null:
		push_error("Fountain timing SubViewport returned no texture")
		return null
	var output := TextureRect.new()
	output.name = "FountainRenderOutput"
	output.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	output.texture = texture
	output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	output.stretch_mode = TextureRect.STRETCH_SCALE
	output.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(output)
	return output

func set_paused(value: bool) -> void:
	if ended and value:
		return
	if value and mode == "bubble_photo" and bubble_model != null:
		# A held control can lose its release while focus is in the pause menu.
		# Cancel only an unlaunched charge; an already launched bubble remains live.
		bubble_model.cancel_bubble_charge()
		_sync_presentation()
	if mode == "ribbon_rhythm" and is_instance_valid(presentation):
		presentation.set_process(not value)
	if value and mode == "hat_catching":
		_hat_left_held = false
		_hat_right_held = false
		hat_model.set_axis(0.0)
		if is_instance_valid(presentation) and presentation.has_method("clear_held_directions"):
			presentation.clear_held_directions()
	if mode == "shadow_alignment":
		_shadow_left_held = false
		_shadow_right_held = false
		_shadow_near_held = false
		_shadow_far_held = false
		if is_instance_valid(presentation):
			if value:
				for field in ["_left_down", "_right_down", "_up_down", "_down_down"]:
					presentation.set(field, false)
			presentation.set_process(not value)
			presentation.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
	if paused and not value:
		_discard_next_delta = true
	paused = value
	if minigame_hud != null:
		minigame_hud.set_paused(value)
	_refresh_hud(true)

func set_practice_mode(value: bool) -> void:
	if practice_mode == value:
		return
	practice_mode = value
	if game_id.is_empty():
		return
	reset_round()
	set_paused(false)
	_refresh_hud()

func request_help() -> void:
	if ended:
		return
	set_paused(true)
	help_requested.emit(game_id)

func _retry_from_hud() -> void:
	reset_round()
	set_paused(false)

func _leave_from_hud() -> void:
	paused = false
	_cancel_ribbon_finish_gate()
	if mode == "shadow_alignment" and is_instance_valid(presentation):
		presentation.set_process(false)
	cancelled.emit()

func _refresh_hud(force: bool = false) -> void:
	if minigame_hud == null or not is_instance_valid(minigame_hud):
		return
	if not force and _hud_refresh_clock < HUD_REFRESH_INTERVAL:
		_hud_dirty = true
		return
	_hud_refresh_clock = 0.0
	_hud_dirty = false
	var info := _definition()
	var time_left := maxf(0.0, round_seconds - elapsed)
	var time_text := "練習" if mode == "balloon_delivery" and not balloon_started else "%02d:%02d" % [int(time_left / 60.0), int(time_left) % 60]
	if mode == "melody_memory": time_text = "自由節奏"
	if mode == "bubble_photo":
		var photo_state: Dictionary = bubble_model.snapshot()
		time_text = "已拍滿" if bool(photo_state.finished) else ("顯影中" if str(photo_state.phase) == "exposure" else "本張 %.1fs" % maxf(0.0, BubblePhotoModelScript.ROUND_SECONDS - float(photo_state.round_elapsed)))
	if mode == "fountain_timing":
		if ended:
			time_text = "3 / 3 拍"
		else:
			var next_beat := _fountain_beat_time(mini(fountain_attempts, 2))
			time_text = "第%d拍 %.1fs" % [mini(fountain_attempts + 1, 3), maxf(0.0, next_beat - phase)]
	if mode == "shadow_alignment":
		var shadow_time_left := maxf(0.0, float(shadow_model.snapshot().time_left))
		time_text = "%02d:%02d" % [int(shadow_time_left / 60.0), int(shadow_time_left) % 60]
	var feedback_text := ""
	if mode == "balloon_delivery" and not balloon_started:
		feedback_text = prompt
	elif feedback_age <= 1.2:
		feedback_text = prompt
	minigame_hud.set_state({
		"title": str(info.get("name", "小遊戲")),
		"objective": str(info.get("goal", "完成挑戰")),
		"progress_text": _progress_text(),
		"score": score,
		"time_text": time_text,
		"feedback_text": feedback_text,
		"feedback_width": 240.0 if mode == "flower_pipes" else (420.0 if mode in ["sign_balance", "kite_rings"] else 540.0),
		"feedback_color": feedback_color,
		"assisted": assisted,
		"practice": practice_mode,
		"reduced_motion": reduced_motion,
		"ended": ended,
		"won": won,
		"devil": devil_won
	})

func _progress_text() -> String:
	match mode:
		"balloon_delivery": return "郵袋 %d / 3" % balloon_delivery_index
		"kite_rings": return "風環 %d / 5　中心 %d　救援 %d" % [count, devil_progress, int(kite_model.snapshot().rescues_used)]
		"fountain_timing": return "機會 %d / 3　成功 %d" % [fountain_attempts, count]
		"crowd_traffic": return "隊伍 %d / 6" % count
		"hat_catching": return "接住 %d / 6" % count
		"ribbon_rhythm": return "命中 %d / 8　失拍 %d　錯誤 %d" % [devil_progress, int(_ribbon_snapshot.get("missed_count", 0)), mistakes]
		"flower_pipes": return "工單 %d / 3　轉動 %d 次" % [mini(pipe_model.order_index + 1, 3), move_count]
		"sign_balance": return "穩住 %d / 7 拍" % count
		"shadow_alignment":
			var shadow_state: Dictionary = shadow_model.snapshot()
			var resolved := 0
			for row in shadow_state.ledger:
				if str(row.status) != "waiting": resolved += 1
			return "定影 %d / 3　合格 %d" % [resolved, int(shadow_state.qualified_count)]
		"bubble_photo":
			var photo_state: Dictionary = bubble_model.snapshot()
			return "合格 %d / 2　完美 %d / 3" % [int(photo_state.qualified_count), int(photo_state.perfect_count)]
		"bench_swap": return "桌 %d / 3　交換 %d 次" % [mini(int(bench_model.snapshot().level) + 1, 3), move_count]
		"melody_memory":
			var phase_name := str(melody_snapshot.get("phase", "listen"))
			var phrase := int(melody_snapshot.get("phrase_number", 1))
			if phase_name != "active":
				var heard: Array = melody_snapshot.get("heard_notes", [])
				return "樂句 %d / 3　聽看 %d / %d" % [phrase, heard.size(), int(melody_snapshot.get("phrase_length", 0))]
			return "樂句 %d / 3　音符 %d / %d" % [phrase, int(melody_snapshot.get("input_index", 0)), int(melody_snapshot.get("phrase_length", 0))]
	return ""

func score_summary() -> Dictionary:
	var totals: Dictionary = {}
	var labels: Dictionary = {}
	var counts: Dictionary = {}
	for event in score_events:
		var key := str(event.get("key", "score"))
		totals[key] = int(totals.get(key, 0)) + int(event.get("amount", 0))
		labels[key] = str(event.get("label", "得分"))
		counts[key] = int(counts.get(key, 0)) + int(event.get("count", 1))
	var rows: Array[Dictionary] = []
	var sum := 0
	for key in totals:
		var amount := int(totals[key])
		sum += amount
		rows.append({"key": key, "label": str(labels[key]), "amount": amount, "count": int(counts[key])})
	if sum != score:
		rows.append({"key": "score_adjustment", "label": "目前計分調整", "amount": score - sum, "count": 1})
	if mode == "flower_pipes" or mode == "bench_swap":
		rows.append({"key": "move_progress", "label": "操作步數（不計分）", "amount": 0, "count": move_count, "progress_only": true})
	if mistakes > 0:
		rows.append({"key": "mistakes", "label": "失誤（不計分）", "amount": 0, "count": mistakes, "progress_only": true})
	if rows.is_empty():
		rows.append({"key": "no_score", "label": _score_label(), "amount": 0, "count": 0})
	return {"total": score, "label": _score_label(), "rule": _score_rule_text(), "rows": rows}

func _score_label() -> String:
	match mode:
		"balloon_delivery": return "郵袋交付分"
		"kite_rings": return "穿環分"
		"fountain_timing": return "跳拍分"
		"crowd_traffic": return "安全通行分"
		"hat_catching": return "接帽分"
		"ribbon_rhythm": return "節拍分"
		"flower_pipes": return "路線轉動分"
		"sign_balance": return "平衡段落分"
		"shadow_alignment": return "影子對準分"
		"bubble_photo": return "合照分"
		"bench_swap": return "換位分"
		"melody_memory": return "演奏分"
	return "得分"

func _score_rule_text() -> String:
	match mode:
		"balloon_delivery": return "每送達一封郵袋 +150。"
		"kite_rings": return "中心穿環 +100，擦邊穿環 +60，漏環或斷線不加分。"
		"fountain_timing": return "三跳總分 0–900；每跳完美 ±70ms +300、準確 ±160ms +200、踩中 ±220ms +100。三跳全中得普通拍貼，三跳完美得小惡魔拍貼。"
		"crowd_traffic": return "每隊安全通過 +50；等候效率 +20／10；救援隊及時通行另 +50。"
		"hat_catching": return "每接住一頂帽子 +100。"
		"ribbon_rhythm": return "精準 +100、合拍 +60；四個重拍另 +25。六拍一般成功；未輔助、八拍全精準且零錯誤才得惡魔拍貼。"
		"flower_pipes": return "每張完成工單 +1000，每次旋轉 −20，最低 0 分；三張全部供水才完成。"
		"sign_balance": return "每段連續穩定至少 0.52 秒得 70 分；中心精準落點得 100 分。五段安全可普通通關，七段全精準且零撞線可得小惡魔拍貼。"
		"shadow_alignment": return "三輪以實際點光源投影定影；每輪形狀誤差達門檻才合格。至少兩輪合格得普通成功；三輪精準且零失誤、未開輔助得小惡魔拍貼。"
		"bubble_photo": return "三張各 0–100 分：全身涵蓋 60、置中 30、合焦時機 10；合格還需泡泡完整包住全身。至少兩張合格成功，三張完美可得小惡魔拍貼。"
		"bench_swap": return "每桌依完成步數得分；符合本桌全部規則為普通目標，每桌以最少交換完成且未開輔助或重排可得加碼。"
		"melody_memory": return "每個正確音符 +25；完成每段樂句再 +100。"
	return "得分由已記錄的遊戲事件累加。"

func set_time_of_day(phase_id: Variant) -> void:
	time_phase = TimeOfDayScript.normalize(phase_id)
	if mode == "bubble_photo" and bubble_model != null:
		bubble_model.time_of_day = time_phase
		bubble_model.snapshot()
		_sync_presentation()
	if mode == "shadow_alignment" and shadow_model != null:
		shadow_model.time_of_day = time_phase
		shadow_model.snapshot()
		_sync_presentation()
	if mode == "bench_swap" and bench_model != null:
		bench_model.time_phase = time_phase
		_sync_presentation()
	var profile: Dictionary = TimeOfDayScript.phase_for_id(time_phase)
	var veil_color: Color
	var veil_alpha: float
	match time_phase:
		"dawn":
			veil_color = Color("#efb990")
			veil_alpha = 0.075
		"noon":
			veil_color = Color("#e8efd8")
			veil_alpha = 0.025
		"dusk":
			veil_color = Color("#e88f79")
			veil_alpha = 0.105
		"night":
			veil_color = Color("#526c9a")
			veil_alpha = 0.14
	phase_wash = Color(veil_color,veil_alpha)
	var rotation: Vector3 = profile.key_rotation_degrees
	phase_shadow_x = clampf(sin(deg_to_rad(rotation.y))*14.0,-9.0,9.0)
	phase_shadow_color = Color("#203a4b",0.18 if time_phase == "noon" else 0.25)
	queue_redraw()

func _rng_reset() -> void:
	rng.seed = hash(game_id) + int(Time.get_ticks_msec())

func reset_round() -> void:
	pipe_connected = false
	pipe_finish_at = -1.0
	elapsed = 0.0
	score = 0
	score_events.clear()
	mistakes = 0
	devil_progress = 0
	ended = false
	paused = false
	won = false
	devil_won = false
	game_time = 0.0
	phase = 0.0
	round_seconds = 55.0 if mode == "balloon_delivery" else (24.0 if mode == "bubble_photo" else ROUND_SECONDS)
	_kite_up_held = false
	_kite_down_held = false
	_kite_boost_held = false
	_kite_reel_held = false
	_kite_marker_cursor = 0
	_shadow_left_held = false
	_shadow_right_held = false
	_shadow_near_held = false
	_shadow_far_held = false
	if mode == "kite_rings":
		kite_model.reset(assisted)
		_kite_marker_cursor = kite_model.snapshot().eventmarkers.size()
	beat = 0
	beat_window = false
	_ribbon_note_cursor = 0
	_ribbon_score_cursor = 0
	_ribbon_error_cursor = 0
	_ribbon_last_event = ""
	_ribbon_snapshot.clear()
	fountain_attempts = 0
	fountain_jump_started = -1.0
	fountain_finish_pending = false
	fountain_finish_at = -1.0
	_cancel_ribbon_finish_gate()
	fountain_grades.clear()
	fountain_errors_ms.clear()
	_fountain_jump_textures.clear()
	_fountain_idle_texture = null
	feedback_age = 99.0
	particles.clear()
	feedback_color = MINT
	prompt = "準備好了嗎？"
	select_index = -1
	pipe_cursor = 0
	move_count = 0
	streak = 0
	count = 0
	lane = 0
	balance = 0.0
	alignment = 0.0
	p = Vector2(270, 390)
	target = Vector2(1010, 360)
	velocity = Vector2.ZERO
	mouse_steering = false
	steering_target = p
	balloon_started = mode != "balloon_delivery" or balloon_tutorial_seen
	balloon_intro_step = 3 if balloon_tutorial_seen else 0
	balloon_braking = false
	balloon_delivery_index = 0
	balloon_dock_hold = 0.0
	balloon_dock_miss_latched = false
	balloon_hazard_cooldown = 0.0
	balloon_wind_current = Vector2.ZERO
	balloon_wind_forecast = Vector2.ZERO
	balloon_wind_scale = BALLOON_ASSIST_WIND_SCALE if assisted else BALLOON_WIND_SCALE
	balloon_dock_radius = BALLOON_ASSIST_DOCK_RADIUS if assisted else BALLOON_DOCK_RADIUS
	balloon_dock_speed = BALLOON_ASSIST_DOCK_SPEED if assisted else BALLOON_DOCK_SPEED
	_bubble_photo_cursor = 0
	seats.clear()
	flower_cells.clear()
	_hat_ledger_cursor = 0
	_hat_left_held = false
	_hat_right_held = false
	_sign_stage_cursor = 0
	_sign_impact_cursor = 0
	alignment_hold = 0.0
	shadow_started = false
	shadow_broken = false
	match mode:
		"balloon_delivery":
			p = Vector2(250, 380)
			target = BALLOON_MAILBOXES[0]
			steering_target = p
			prompt = "吹風練習：方向鍵或 WASD 推動氣球。Enter 隨時開始送件"
		"kite_rings":
			var kite_snapshot: Dictionary = kite_model.snapshot()
			p = Vector2(float(kite_snapshot.x), float(kite_snapshot.height))
		"fountain_timing": pass
		"crowd_traffic":
			crowd_model.reset(assisted)
			_crowd_event_cursor = 0
		"hat_catching":
			hat_model.reset(assisted, time_phase)
			var initial_hat_state: Dictionary = hat_model.snapshot()
			p.x = float(initial_hat_state.player_x)
		"ribbon_rhythm":
			ribbon_model.reset(assisted, time_phase)
			_ribbon_snapshot = ribbon_model.snapshot().duplicate(true)
			_ribbon_last_event = str(_ribbon_snapshot.get("last_event", ""))
			prompt = _ribbon_last_event
		"flower_pipes":
			pipe_model.reset()
			flower_cells = pipe_model.cells
		"sign_balance": sign_model.reset(assisted)
		"shadow_alignment":
			shadow_model.reset(assisted, time_phase)
			_shadow_frame_delta = 1.0 / 60.0
			if is_instance_valid(presentation):
				for field in ["_left_down", "_right_down", "_up_down", "_down_down"]:
					presentation.set(field, false)
				presentation.set_process(true)
				presentation.mouse_filter = Control.MOUSE_FILTER_STOP
			prompt = "移動點光源的左右與深度，讓完整影形貼合牆上印記；按 Space 定影三輪"
		"bubble_photo":
			bubble_model.reset(assisted, time_phase)
			_sync_presentation()
		"bench_swap":
			bench_model.reset(assisted, time_phase)
			_bench_score_published = 0
			_bench_last_event = str(bench_model.snapshot().last_event)
			_sync_bench_state()
		"melody_memory":
			melody_model.reset(assisted, time_phase)
			melody_snapshot = melody_model.snapshot()
			_melody_audio_cursor = int(melody_snapshot.get("note_start_serial", 0))
			_melody_error_cursor = int(melody_snapshot.get("error_count", 0))
			_melody_last_event = str(melody_snapshot.get("last_event", ""))
			prompt = _melody_last_event
	if assisted:
		prompt = "輔助已開：目標會標亮，判定範圍加寬"
	if mode == "fountain_timing":
		_prepare_fountain_avatar_poses()
	_sync_presentation()
	_refresh_hud(true)
	queue_redraw()

func _prepare_fountain_avatar_poses() -> void:
	var progress := get_node_or_null("/root/Progress")
	var appearance: Dictionary = progress.appearance if progress != null and progress.get("appearance") is Dictionary else {}
	var equipped: Dictionary = progress.equipped if progress != null and progress.get("equipped") is Dictionary else {}
	var cache_key := JSON.stringify([appearance, equipped])
	var pose_cache: Dictionary = {}
	if progress != null and progress.has_meta(FOUNTAIN_POSE_CACHE_META):
		pose_cache = progress.get_meta(FOUNTAIN_POSE_CACHE_META) as Dictionary
	if pose_cache.has(cache_key):
		var cached: Dictionary = pose_cache[cache_key]
		_fountain_idle_texture = cached.get("idle") as Texture2D
		_fountain_jump_textures.assign(cached.get("jump", []))
		return
	if progress != null:
		var shared_renderer: Variant = null
		if progress.has_meta(FOUNTAIN_RENDERER_META):
			shared_renderer = progress.get_meta(FOUNTAIN_RENDERER_META)
		if shared_renderer is RefCounted:
			_fountain_avatar_renderer = shared_renderer
	if _fountain_avatar_renderer == null:
		_fountain_avatar_renderer = AvatarRendererScript.new()
		if progress != null:
			progress.set_meta(FOUNTAIN_RENDERER_META, _fountain_avatar_renderer)
	_fountain_idle_texture = _fountain_avatar_renderer.texture(appearance, equipped, "front", 0, "idle")
	if not _fountain_avatar_renderer.has_authored_action("jump", "front"):
		return
	var frame_count: int = _fountain_avatar_renderer.authored_frame_count("jump", "front")
	for index in frame_count:
		# AvatarRenderer applies the saved face/hair/skin, equipped layers, and the
		# authored outfit variant. Its texture cache makes these one-time lookups.
		var frame_texture: Texture2D = _fountain_avatar_renderer.texture(appearance, equipped, "front", index, "jump")
		if frame_texture != null:
			_fountain_jump_textures.append(frame_texture)
	if progress != null and _fountain_jump_textures.size() > 0:
		pose_cache[cache_key] = {"idle": _fountain_idle_texture, "jump": _fountain_jump_textures.duplicate()}
		while pose_cache.size() > FOUNTAIN_POSE_CACHE_LIMIT:
			pose_cache.erase(pose_cache.keys()[0])
		progress.set_meta(FOUNTAIN_POSE_CACHE_META, pose_cache)

func _process(delta: float) -> void:
	var shadow_delta := delta if is_finite(delta) and delta > 0.0 else 0.0
	if mode == "shadow_alignment":
		shadow_delta = minf(shadow_delta, 0.5)
		_shadow_frame_delta = minf(shadow_delta, ShadowTheatreModelScript.MAX_STEP)
	_sync_presentation()
	_hud_refresh_clock += maxf(delta, 0.0)
	if _hud_dirty and _hud_refresh_clock >= HUD_REFRESH_INTERVAL:
		_refresh_hud(true)
	if ended or paused:
		return
	if _discard_next_delta:
		_discard_next_delta = false
		_refresh_hud()
		queue_redraw()
		return
	if mode == "ribbon_rhythm" and ribbon_finish_pending:
		# The model has already produced its immutable result. Keep the Session
		# alive just long enough for the authored final dance to be seen.
		ribbon_finish_elapsed += minf(maxf(delta, 0.0), 0.1)
		_sync_presentation()
		_refresh_hud()
		queue_redraw()
		if ribbon_finish_elapsed + 0.00001 >= ribbon_finish_duration:
			ribbon_finish_pending = false
			_finish(ribbon_finish_success, ribbon_finish_devil)
		return
	if mode == "balloon_delivery" and not balloon_started:
		feedback_age += delta
		# The tutorial is learn-by-doing, with a short fallback per lesson. Cap a
		# suspended-window delta so neither wind phase nor balloon position jumps.
		var intro_remaining := minf(maxf(delta, 0.0), 0.5)
		while intro_remaining > 0.00001:
			var intro_step := minf(intro_remaining, 0.05)
			phase += intro_step
			balloon_intro_step_clock += intro_step
			_tick_balloon_motion(intro_step)
			if balloon_intro_step_clock >= 3.0 and balloon_intro_step < 2:
				balloon_intro_step += 1
				balloon_intro_step_clock = 0.0
			intro_remaining -= intro_step
		_set_balloon_intro_prompt()
		_sync_presentation()
		_refresh_hud()
		queue_redraw()
		return
	var simulation_delta := shadow_delta if mode == "shadow_alignment" else delta
	elapsed += simulation_delta
	game_time += simulation_delta
	if mode != "balloon_delivery": phase += simulation_delta
	feedback_age += simulation_delta
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		particle.life = float(particle.life) - simulation_delta
		particle.pos = Vector2(particle.pos) + Vector2(particle.velocity) * simulation_delta
		particles[i] = particle
		if particle.life <= 0.0: particles.remove_at(i)
	if mode == "shadow_alignment":
		_tick_shadow_theatre(simulation_delta)
		if ended: return
	if mode not in ["melody_memory", "bench_swap", "shadow_alignment"] and elapsed >= round_seconds:
		_finish(false)
		return
	if mode == "kite_rings":
		_tick_kite(delta)
	elif mode == "balloon_delivery":
		# Time still advances at wall-clock delta; physics uses bounded substeps.
		var remaining := minf(maxf(delta, 0.0), 0.5)
		while remaining > 0.00001 and not ended:
			var step := minf(remaining, 0.05)
			phase += step
			_tick_balloon(step)
			remaining -= step
	else:
		_tick_game(delta)
	_sync_presentation()
	_refresh_hud()
	queue_redraw()

func _set_balloon_intro_prompt() -> void:
	match balloon_intro_step:
		0: prompt = "練習 1/3　方向鍵／WASD 或移動滑鼠推動氣球。Enter 隨時出發"
		1: prompt = "練習 2/3　按空白鍵／右鍵煞車；↑↓ 調整航線。Enter 隨時出發"
		2: prompt = "練習 3/3　依序送達三個亮起的郵箱；進圈後煞停。Enter 開始計時"

func _tick_kite(delta: float) -> void:
	kite_model.step(delta)
	var state: Dictionary = kite_model.snapshot()
	p = Vector2(float(state.get("x", 120.0)), float(state.get("height", 380.0)))
	count = int(state.get("nextRing", 0))
	devil_progress = int(state.get("center_hits", 0))
	mistakes = int(state.get("mistakes", 0))
	var markers: Array = state.get("eventmarkers", [])
	while _kite_marker_cursor < markers.size():
		var marker: Dictionary = markers[_kite_marker_cursor]
		var kind := str(marker.get("kind", ""))
		if kind == "center":
			_award_points("kite_center", "中心穿環", 100)
			_feedback("穿過風環中心！", MINT)
		elif kind == "edge":
			_award_points("kite_edge", "擦邊穿環", 60)
			_feedback("擦邊穿過風環", YELLOW)
		elif kind == "miss":
			_feedback("漏過風環，風箏已退回安全距離", PINK)
		elif kind == "line_snap":
			_feedback("風箏線張力過高，已安全復位", PINK)
		_kite_marker_cursor += 1
	if bool(state.get("ended", false)):
		_finish(bool(state.get("won", false)), bool(state.get("devil", false)))

func _tick_game(delta: float) -> void:
	match mode:
		"balloon_delivery": _tick_balloon(delta)
		"fountain_timing":
			_tick_fountain()
		"crowd_traffic": _tick_crowd(delta)
		"hat_catching": _tick_hats(delta)
		"ribbon_rhythm":
			ribbon_model.step(delta)
			_sync_ribbon_model("elapsed")
		"flower_pipes": _tick_pipe(delta)
		"sign_balance":
			var input_axis := _axis_x()
			if not is_zero_approx(input_axis):
				sign_model.set_balance(sign_model.balance + input_axis * delta * 1.8)
			var state: Dictionary = sign_model.step(delta)
			balance = float(state.balance)
			count = int(state.safe_stages)
			devil_progress = int(state.precise_stages)
			mistakes = int(state.impacts)
			var stage_results: Array = state.stage_results
			var completed_stage_count := mini(int(state.completed_stage_count), stage_results.size())
			while _sign_stage_cursor < completed_stage_count:
				var stage_result: Dictionary = stage_results[_sign_stage_cursor]
				if bool(stage_result.passed):
					var stage_number := _sign_stage_cursor + 1
					var stage_label := "第 %d 段・中心精準" % stage_number if bool(stage_result.precise) else "第 %d 段・安全帶" % stage_number
					_award_points("sign_stage_%d" % stage_number, stage_label, 100 if bool(stage_result.precise) else 70)
					_feedback("中心精準！" if bool(stage_result.precise) else "穩住安全帶！", MINT if bool(stage_result.precise) else YELLOW)
				else:
					_feedback("這段沒有穩在安全帶", PINK)
				_sign_stage_cursor += 1
			while _sign_impact_cursor < int(state.impacts):
				_sign_impact_cursor += 1
				_feedback("招牌撞到外側安全線", PINK)
			if bool(state.ended):
				_finish(bool(state.success), bool(state.devil_success))
		"shadow_alignment": pass # Advanced by the bounded projection-model clock in _process.
		"bubble_photo":
			_tick_bubble_photo(delta)
		"bench_swap": _tick_bench_swap(delta)
		"melody_memory": _tick_melody(delta)

func _tick_shadow_theatre(delta: float) -> void:
	var remaining := minf(maxf(delta, 0.0), 0.5)
	while remaining > 0.000001 and not shadow_model.finished:
		var step := minf(remaining, ShadowTheatreModelScript.MAX_STEP)
		if not is_instance_valid(presentation):
			shadow_model.continuous_axis(float(int(_shadow_right_held) - int(_shadow_left_held)), float(int(_shadow_near_held) - int(_shadow_far_held)), step)
		shadow_model.step(step)
		remaining -= step
	if shadow_model.timed_out:
		_sync_shadow_progress()
		_sync_presentation()
		_finish(false, false)

func _sync_shadow_progress() -> void:
	var state: Dictionary = shadow_model.snapshot()
	count = int(state.qualified_count)
	devil_progress = int(state.perfect_count)
	mistakes = int(state.misses)

func _on_shadow_axis_requested(horizontal: float, depth: float) -> void:
	if mode != "shadow_alignment" or ended or paused:
		return
	shadow_model.continuous_axis(horizontal, depth, _shadow_frame_delta)
	_sync_presentation()
	_refresh_hud()

func _on_shadow_lamp_target_requested(target_position: Vector2) -> void:
	if mode != "shadow_alignment" or ended or paused:
		return
	shadow_model.setlamp_target(target_position)
	_sync_presentation()
	_refresh_hud(true)

func _on_shadow_shutter_requested() -> void:
	if mode != "shadow_alignment" or ended or paused:
		return
	var result: Dictionary = shadow_model.capture()
	if not bool(result.get("accepted", false)):
		return
	var round_number := int(result.round) + 1
	if bool(result.qualified):
		_award_points("shadow_round_%d" % round_number, "第 %d 輪影形定影" % round_number, int(result.score))
		_feedback("影形吻合並完成定影" if bool(result.perfect) else "影形合格，進入下一輪", MINT if bool(result.perfect) else YELLOW)
	else:
		_record_score_event("shadow_round_%d" % round_number, "第 %d 輪未達投影門檻" % round_number, 0)
		_feedback("影形未合格；檢查左右與燈距後再定影", PINK)
	_sync_shadow_progress()
	_sync_presentation()
	_refresh_hud(true)
	if bool(shadow_model.finished):
		_finish(bool(shadow_model.success), bool(shadow_model.devil))

func _tick_balloon_motion(delta: float) -> void:
	balloon_wind_current = _balloon_wind_at(phase, p.y)
	balloon_wind_forecast = _balloon_wind_at(phase + BALLOON_WIND_FORECAST_SECONDS, p.y)
	var control := Vector2(_axis_x(), _axis_y())
	if control.length() > 1.0: control = control.normalized()
	if control.is_zero_approx() and mouse_steering:
		var guide := steering_target - p
		if guide.length() > 18.0: control = guide.normalized()
	if not balloon_started:
		if balloon_intro_step == 0 and not control.is_zero_approx():
			balloon_intro_step = 1
			balloon_intro_step_clock = 0.0
		elif balloon_intro_step == 1 and balloon_braking:
			balloon_intro_step = 2
			balloon_intro_step_clock = 0.0
	var desired_velocity := control * BALLOON_MAX_SPEED + balloon_wind_current
	if balloon_braking:
		# Braking damps the current flight speed without taking steering away;
		# the 22% control cap keeps a aimed dock approach under the low-speed limit.
		desired_velocity = control * BALLOON_MAX_SPEED * 0.22 + balloon_wind_current * 0.16
	var max_velocity := BALLOON_MAX_SPEED
	if desired_velocity.length() > max_velocity: desired_velocity = desired_velocity.normalized() * max_velocity
	velocity = velocity.move_toward(desired_velocity, (BALLOON_BRAKE_ACCELERATION if balloon_braking else BALLOON_ACCELERATION) * delta)
	if velocity.length() > max_velocity: velocity = velocity.normalized() * max_velocity
	p += velocity * delta
	p.x = clampf(p.x, 130.0, 1150.0)
	p.y = clampf(p.y, 210.0, 585.0)

func _balloon_wind_at(at_time: float, altitude: float = -1.0) -> Vector2:
	# The upper and lower harbor lanes pull in opposite directions; the middle is calm.
	var height := p.y if altitude < 0.0 else altitude
	var interval := 12.0
	var gust_index := int(floor(maxf(0.0, at_time) / interval))
	var gust_direction := 1.0 if gust_index % 2 == 0 else -1.0
	var gust_strength := 42.0 + float(gust_index % 3) * 8.0
	var lane_bias := 1.0 - 2.0 * clampf(inverse_lerp(280.0, 520.0, height), 0.0, 1.0)
	return Vector2(gust_direction * gust_strength * lane_bias * balloon_wind_scale, 0.0)

func _balloon_hazard_at(at_time: float) -> Vector2:
	return Vector2(720.0 + sin(at_time * 0.48) * 54.0, 390.0 + sin(at_time * 0.71 + 0.4) * 24.0)

func _tick_balloon(delta: float) -> void:
	_tick_balloon_motion(delta)
	balloon_hazard_cooldown = maxf(0.0, balloon_hazard_cooldown - delta)
	var hazard := _balloon_hazard_at(phase)
	if balloon_hazard_cooldown <= 0.0 and p.distance_to(hazard) < 65.0:
		var separation := p - hazard
		if separation.is_zero_approx(): separation = Vector2.LEFT
		p = hazard + separation.normalized() * 66.0
		velocity *= 0.48
		balloon_hazard_cooldown = 1.0
		mistakes += 1
		balloon_dock_hold = 0.0
		_feedback("海膽擦到氣球！看風向繞過它", PINK)
	var distance_to_mailbox := p.distance_to(target)
	if distance_to_mailbox <= balloon_dock_radius:
		if velocity.length() <= balloon_dock_speed:
			balloon_dock_miss_latched = false
			balloon_dock_hold += delta
			if balloon_dock_hold >= BALLOON_DOCK_HOLD_SECONDS:
				balloon_delivery_index += 1
				count = balloon_delivery_index
				devil_progress += 1
				_score(150)
				balloon_dock_hold = 0.0
				balloon_dock_miss_latched = false
				if balloon_delivery_index >= BALLOON_MAILBOXES.size():
					_feedback("三封郵袋都送達！", MINT)
					_finish(true, mistakes == 0 and devil_progress == 3)
				else:
					target = BALLOON_MAILBOXES[balloon_delivery_index]
					_feedback("郵袋送達！下一站亮起了", MINT)
		else:
			balloon_dock_hold = 0.0
			if not balloon_dock_miss_latched:
				balloon_dock_miss_latched = true
				mistakes += 1
				_feedback("郵箱前按空白鍵或右鍵煞車", YELLOW)
	else:
		balloon_dock_hold = 0.0
		balloon_dock_miss_latched = false

func _launch_balloon() -> void:
	if mode != "balloon_delivery" or balloon_started: return
	balloon_started = true
	balloon_tutorial_seen = true
	balloon_intro_step = 3
	balloon_intro_step_clock = 0.0
	elapsed = 0.0
	game_time = 0.0
	phase = 0.0
	p = Vector2(250, 380)
	target = BALLOON_MAILBOXES[0]
	velocity = Vector2.ZERO
	balloon_braking = false
	balloon_delivery_index = 0
	count = 0
	mistakes = 0
	devil_progress = 0
	balloon_dock_hold = 0.0
	balloon_dock_miss_latched = false
	balloon_hazard_cooldown = 0.0
	steering_target = p
	_feedback("出發！按方向鍵／WASD飛行，空白鍵或右鍵煞車", BLUE)

func _tick_crowd(delta: float) -> void:
	crowd_model.step(delta)
	var state: Dictionary = crowd_model.snapshot()
	count = int(state.safe_count) + int(state.missed_count)
	mistakes = int(state.mistakes)
	devil_progress = int(state.devil_progress)
	while _crowd_event_cursor < crowd_model.events.size():
		var event: Dictionary = crowd_model.events[_crowd_event_cursor]
		_crowd_event_cursor += 1
		if event.kind == "safe":
			var data: Dictionary = event.data
			_award_points("crowd", "隊伍安全通過", int(data.base))
			if int(data.efficiency) > 0: _award_points("crowd_wait", "等候效率", int(data.efficiency))
			if int(data.rescue_bonus) > 0: _award_points("crowd_rescue", "救援隊及時通行", int(data.rescue_bonus))
			_feedback("隊伍安全通過", MINT)
		elif event.kind == "expired": _feedback("等候太久，隊伍改走別條路", PINK)
	if bool(state.finished): _finish(bool(state.success), bool(state.devil))

func _request_crowd_lane(value: int) -> void:
	if ended or paused: return
	lane = value
	crowd_model.request_lane(value)
	_feedback("安排橫向通行" if value == 0 else "安排縱向通行", BLUE)
	_sync_presentation()

func _on_crowd_signal_requested(value: int) -> void:
	if mode == "crowd_traffic" and value in [0, 1]:
		_request_crowd_lane(value)

func _tick_pipe(delta: float) -> void:
	var previous_order: int = pipe_model.order_index
	var previous_completed: int = pipe_model.completed_beds
	var state: Dictionary = pipe_model.step(delta)
	flower_cells = pipe_model.cells
	move_count = int(state.total_turns)
	pipe_connected = bool(state.connected)
	if int(state.score) != score: _set_formula_score("pipe_orders", "供水工單與轉動計分", int(state.score))
	if pipe_model.order_index != previous_order:
		pipe_cursor = 0
		_feedback("工單 %d：%s" % [pipe_model.order_index + 1, str(state.brief)], MINT)
	if bool(state.ended):
		if not bool(state.success): _finish(false); return
		if pipe_finish_at < 0.0: pipe_finish_at = phase + 0.20
		if phase >= pipe_finish_at:
			var perfect := true
			for index in pipe_model.orders.size():
				if pipe_model.order_turns[index] > int(pipe_model.orders[index].turn_par): perfect = false
			_finish(true, perfect)
	elif pipe_model.completed_beds > previous_completed:
		_feedback("花床已供水", MINT)

func _tick_hats(delta: float) -> void:
	var state: Dictionary = hat_model.step(delta)
	count = int(state.get("caught", 0))
	devil_progress = int(state.get("center_catches", 0))
	mistakes = int(state.get("misses", 0))
	p.x = float(state.get("player_x", p.x))
	var ledger: Array = state.get("ledger", [])
	while _hat_ledger_cursor < mini(HatRescueModelScript.HAT_COUNT, ledger.size()):
		var entry: Dictionary = ledger[_hat_ledger_cursor]
		var status := str(entry.get("status", "waiting"))
		if status == "waiting":
			break
		var points := int(entry.get("points", 0))
		if points > 0:
			_award_points("hat_%d" % _hat_ledger_cursor, "第 %d 頂・%s接住" % [_hat_ledger_cursor + 1, str(entry.get("grade", ""))], points)
			_feedback("第 %d 頂%s　+%d" % [_hat_ledger_cursor + 1, str(entry.get("grade", "")), points], MINT if status == "center" else YELLOW)
		else:
			_feedback("第 %d 頂漏接" % (_hat_ledger_cursor + 1), PINK)
		_hat_ledger_cursor += 1
	_sync_presentation()
	if bool(state.get("finished", false)):
		_finish(bool(state.get("success", false)), bool(state.get("devil", false)))

func _tick_melody(delta: float) -> void:
	melody_model.step(delta)
	_sync_melody_state()
	if bool(melody_snapshot.get("ended", false)):
		_finish(bool(melody_snapshot.get("success", false)), bool(melody_snapshot.get("devil_success", false)) and not practice_mode)

func _axis_x() -> float:
	return clampf(Input.get_axis("ui_left", "ui_right") + Input.get_axis("move_left", "move_right"), -1.0, 1.0)

func _axis_y() -> float:
	return clampf(Input.get_axis("ui_up", "ui_down") + Input.get_axis("move_up", "move_down"), -1.0, 1.0)

func _on_kite_presentation_input(event: InputEvent) -> void:
	if mode != "kite_rings" or ended or paused:
		return
	if event is InputEventMouseMotion:
		# gui_input is already expressed in the unscaled presentation design plane.
		kite_model.set_aim(clampf((390.0 - event.position.y) / 235.0, -1.0, 1.0))
	elif event is InputEventMouseButton:
		_apply_kite_pointer_button(event)

func _on_sign_balance_requested(value: float) -> void:
	if mode == "sign_balance" and not ended and not paused:
		sign_model.set_balance(value)

func _on_hat_presentation_input(event: InputEvent) -> void:
	if mode != "hat_catching" or ended or paused:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode in [KEY_LEFT, KEY_A]:
			_hat_left_held = key.pressed
			_update_hat_axis()
			presentation.accept_event()
		elif key.keycode in [KEY_RIGHT, KEY_D]:
			_hat_right_held = key.pressed
			_update_hat_axis()
			presentation.accept_event()
		elif key.keycode == KEY_SPACE and key.pressed and not key.echo:
			hat_model.set_catch(true)
			presentation.accept_event()
	elif event is InputEventMouseMotion:
		var pointer := (event as InputEventMouseMotion).position
		# Incidental mouse motion must not switch a held keyboard route into
		# pointer-target mode. An explicit click still selects a pointer target.
		if HatRescueViewScript.PLAY_BOUNDS.has_point(pointer):
			if not _hat_left_held and not _hat_right_held:
				hat_model.set_target_x(pointer.x)
			presentation.accept_event()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and HatRescueViewScript.PLAY_BOUNDS.has_point(button.position):
			if button.pressed:
				hat_model.set_target_x(button.position.x)
				hat_model.set_catch(true)
			presentation.accept_event()
	_sync_presentation()

func _update_hat_axis() -> void:
	if mode == "hat_catching" and not ended and not paused:
		hat_model.set_axis(float(int(_hat_right_held) - int(_hat_left_held)))

func _apply_kite_pointer_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT: _kite_boost_held = event.pressed
	elif event.button_index == MOUSE_BUTTON_RIGHT: _kite_reel_held = event.pressed
	kite_model.set_boost(_kite_boost_held)
	kite_model.set_reel(_kite_reel_held)

func _unhandled_input(event: InputEvent) -> void:
	if ended:
		return
	var viewport := get_viewport()
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if viewport: viewport.set_input_as_handled()
		set_paused(not paused)
		return
	if paused:
		return
	if (event is InputEventKey or event is InputEventMouse) and viewport:
		viewport.set_input_as_handled()
	if mode == "shadow_alignment" and not is_instance_valid(presentation) and event is InputEventKey:
		var shadow_key := event as InputEventKey
		match shadow_key.keycode:
			KEY_LEFT, KEY_A: _shadow_left_held = shadow_key.pressed
			KEY_RIGHT, KEY_D: _shadow_right_held = shadow_key.pressed
			KEY_UP, KEY_W: _shadow_near_held = shadow_key.pressed
			KEY_DOWN, KEY_S: _shadow_far_held = shadow_key.pressed
			_: pass
		if shadow_key.keycode in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D, KEY_UP, KEY_W, KEY_DOWN, KEY_S]:
			return
	if mode == "balloon_delivery" and event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_SPACE:
			balloon_braking = key_event.pressed
			return
		if key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER):
			_launch_balloon()
			return
	if mode == "balloon_delivery" and event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		balloon_braking = (event as InputEventMouseButton).pressed
		return
	if mode == "bubble_photo" and event is InputEventKey:
		var bubble_key := event as InputEventKey
		if bubble_key.keycode == KEY_E:
			if bubble_key.echo: return
			if bubble_key.pressed and not bubble_key.echo:
				bubble_model.start_bubble_charge()
			else:
				bubble_model.release_bubble_charge()
			_sync_presentation()
			_refresh_hud()
			return
	if mode == "bubble_photo" and event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if (event as InputEventMouseButton).pressed:
			bubble_model.start_bubble_charge()
		else:
			bubble_model.release_bubble_charge()
		_sync_presentation()
		_refresh_hud()
		return
	if mode == "kite_rings":
		if event is InputEventKey:
			var kite_key := event as InputEventKey
			if kite_key.keycode == KEY_UP: _kite_up_held = kite_key.pressed
			elif kite_key.keycode == KEY_DOWN: _kite_down_held = kite_key.pressed
			elif kite_key.keycode == KEY_SPACE: _kite_boost_held = kite_key.pressed
			elif kite_key.keycode == KEY_SHIFT: _kite_reel_held = kite_key.pressed
			kite_model.set_aim(float(int(_kite_up_held) - int(_kite_down_held)))
			kite_model.set_boost(_kite_boost_held)
			kite_model.set_reel(_kite_reel_held)
		elif event is InputEventMouseButton:
			_apply_kite_pointer_button(event as InputEventMouseButton)
			return
	if mode == "hat_catching" and event is InputEventKey:
		var hat_key := event as InputEventKey
		if hat_key.keycode in [KEY_LEFT, KEY_A]:
			_hat_left_held = hat_key.pressed
			_update_hat_axis()
			return
		if hat_key.keycode in [KEY_RIGHT, KEY_D]:
			_hat_right_held = hat_key.pressed
			_update_hat_axis()
			return
		if hat_key.keycode == KEY_SPACE and hat_key.pressed and not hat_key.echo:
			hat_model.set_catch(true)
			_sync_presentation()
			return
	if mode == "ribbon_rhythm" and event is InputEventKey:
		var ribbon_key := event as InputEventKey
		if ribbon_key.echo: return
		var ribbon_action := ""
		match ribbon_key.keycode:
			KEY_LEFT, KEY_A: ribbon_action = "left"
			KEY_RIGHT, KEY_D: ribbon_action = "right"
			KEY_SPACE, KEY_UP, KEY_W: ribbon_action = "jump"
		if not ribbon_action.is_empty():
			if ribbon_key.pressed: _on_ribbon_action_pressed(ribbon_action)
			else: _on_ribbon_action_released(ribbon_action)
			return
	if mode == "ribbon_rhythm" and event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var ribbon_pointer := _to_design((event as InputEventMouseButton).position)
		if is_instance_valid(presentation): ribbon_pointer = presentation.screen_to_design((event as InputEventMouseButton).position)
		for action in ["left", "jump", "right"]:
			if RibbonRhythmViewScript.CONTROL_RECTS[action].has_point(ribbon_pointer):
				if (event as InputEventMouseButton).pressed: _on_ribbon_action_pressed(action)
				else: _on_ribbon_action_released(action)
				return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R: set_paused(true); return
		if event.keycode == KEY_SPACE:
			if mode == "bubble_photo": _bubble_shutter()
			else: _press_action()
		if mode == "melody_memory":
			if event.keycode >= KEY_1 and event.keycode <= KEY_4:
				_melody_input(event.keycode - KEY_1)
			elif event.keycode in [KEY_A, KEY_S, KEY_D, KEY_F]:
				_melody_input([KEY_A, KEY_S, KEY_D, KEY_F].find(event.keycode))
		if mode == "bench_swap" and event.keycode >= KEY_1 and event.keycode <= KEY_6: _bench_key(int(event.keycode - KEY_1))
		if mode == "flower_pipes":
			if event.keycode == KEY_LEFT: pipe_cursor = maxi(0, pipe_cursor - 1)
			if event.keycode == KEY_RIGHT: pipe_cursor = mini(15, pipe_cursor + 1)
			if event.keycode == KEY_UP: pipe_cursor = maxi(0, pipe_cursor - 4)
			if event.keycode == KEY_DOWN: pipe_cursor = mini(15, pipe_cursor + 4)
			if event.keycode == KEY_SPACE: _rotate_pipe_index(pipe_cursor)
		if mode == "bubble_photo" and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			var center: Vector2 = bubble_model.snapshot().frame_center
			var shift := Vector2.ZERO
			if event.keycode == KEY_LEFT: shift.x = -14.0
			elif event.keycode == KEY_RIGHT: shift.x = 14.0
			elif event.keycode == KEY_UP: shift.y = -14.0
			else: shift.y = 14.0
			bubble_model.set_frame_center(center + shift)
			_sync_presentation()
			_refresh_hud(true)
		if mode == "crowd_traffic" and event.keycode in [KEY_Q, KEY_E]: _request_crowd_lane(0 if event.keycode == KEY_Q else 1)
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		var m := _to_design(mouse_event.position)
		if mode == "fountain_timing" and mouse_event.button_index == MOUSE_BUTTON_LEFT: _press_action()
		elif mode == "crowd_traffic":
			var chosen_lane: int = presentation.signal_lane_at(m) if is_instance_valid(presentation) else -1
			if chosen_lane >= 0:
				_request_crowd_lane(chosen_lane)
		elif mode == "shadow_alignment" and not is_instance_valid(presentation):
			_on_shadow_lamp_target_requested(_shadow_pointer_target(m))
		elif mode == "bubble_photo":
			if m.distance_to(Vector2(1020.0, 184.0)) <= 32.0: _bubble_shutter()
		elif mode == "flower_pipes": _rotate_pipe(m)
		elif mode == "hat_catching" and not is_instance_valid(presentation) and HatRescueViewScript.PLAY_BOUNDS.has_point(m):
			hat_model.set_target_x(m.x)
			hat_model.set_catch(true)
	if event is InputEventMouseMotion:
		var mouse := event as InputEventMouseMotion
		var pointer := _to_design(mouse.position)
		match mode:
			"balloon_delivery":
				if is_instance_valid(presentation): pointer = presentation.screen_to_design(pointer)
				steering_target = Vector2(clampf(pointer.x, 130, 1150), clampf(pointer.y, 210, 585))
				mouse_steering = true
			"kite_rings": kite_model.set_aim(clampf((390.0 - pointer.y) / 235.0, -1.0, 1.0))
			"hat_catching":
				if not is_instance_valid(presentation) and HatRescueViewScript.PLAY_BOUNDS.has_point(pointer):
					hat_model.set_target_x(pointer.x)
			"shadow_alignment":
				if not is_instance_valid(presentation):
					_on_shadow_lamp_target_requested(_shadow_pointer_target(pointer))
			"bubble_photo":
				if BubblePhotoModelScript.PLAY_RECT.has_point(pointer):
					bubble_model.set_frame_center(pointer)
					_sync_presentation()
					_refresh_hud()

func _press_action() -> void:
	match mode:
		"shadow_alignment": _on_shadow_shutter_requested()
		"fountain_timing":
			if fountain_attempts >= 3:
				return
			var target_time := _fountain_beat_time(fountain_attempts)
			var error := phase - target_time
			var tolerance := _fountain_hit_tolerance()
			# An early spammed key before the water's pre-cue cannot burn the next jump.
			if error < -tolerance - FOUNTAIN_TIMING_EPSILON:
				_feedback("水柱還在蓄水，等中央水簾預亮", BLUE)
				return
			if error > tolerance + FOUNTAIN_TIMING_EPSILON:
				_tick_fountain()
				return
			_resolve_fountain_jump(error)

func _fountain_beat_time(index: int) -> float:
	return FOUNTAIN_FIRST_BEAT + float(index) * FOUNTAIN_PERIOD

func _fountain_perfect_tolerance() -> float:
	return FOUNTAIN_ASSIST_PERFECT_WINDOW if assisted else FOUNTAIN_PERFECT_WINDOW

func _fountain_good_tolerance() -> float:
	return FOUNTAIN_ASSIST_GOOD_WINDOW if assisted else FOUNTAIN_GOOD_WINDOW

func _fountain_hit_tolerance() -> float:
	return FOUNTAIN_ASSIST_HIT_WINDOW if assisted else FOUNTAIN_HIT_WINDOW

func _tick_fountain() -> void:
	if fountain_finish_pending:
		if phase + FOUNTAIN_TIMING_EPSILON >= fountain_finish_at:
			fountain_finish_pending = false
			_finish(count == 3, devil_progress == 3 and mistakes == 0)
		return
	while fountain_attempts < 3 and phase >= _fountain_beat_time(fountain_attempts) + _fountain_hit_tolerance() + FOUNTAIN_TIMING_EPSILON:
		var missed_index := fountain_attempts + 1
		fountain_attempts += 1
		fountain_grades.append("錯過")
		fountain_errors_ms.append(0)
		mistakes += 1
		_record_score_event("fountain_jump_%d" % missed_index, "第 %d 跳・錯過拍點　0 分" % missed_index, 0)
		_feedback("第 %d 跳錯過拍點・沒有輸入" % missed_index, PINK)
		if fountain_attempts >= 3:
			_finish(count == 3, devil_progress == 3 and mistakes == 0)
	beat_window = fountain_attempts < 3 and absf(phase - _fountain_beat_time(fountain_attempts)) <= _fountain_perfect_tolerance() + FOUNTAIN_TIMING_EPSILON

func _resolve_fountain_jump(error: float) -> void:
	if fountain_attempts >= 3:
		return
	var index := fountain_attempts + 1
	var deviation := absf(error)
	var grade := "擦邊"
	var points := 100
	var color := YELLOW
	if deviation <= _fountain_perfect_tolerance() + FOUNTAIN_TIMING_EPSILON:
		grade = "完美"
		points = 300
		devil_progress += 1
		color = MINT
	elif deviation <= _fountain_good_tolerance() + FOUNTAIN_TIMING_EPSILON:
		grade = "準確"
		points = 200
	else:
		grade = "踩中"
	# All three authored timing grades are successful landings. Beyond the hit
	# window the scheduled opportunity is a miss and is resolved by _tick_fountain.
	count += 1
	fountain_attempts += 1
	fountain_jump_started = phase
	fountain_grades.append(grade)
	var signed_ms := roundi(error * 1000.0)
	fountain_errors_ms.append(signed_ms)
	var timing := "晚 +%dms" % signed_ms if signed_ms >= 0 else "早 %dms" % abs(signed_ms)
	_award_points("fountain_jump_%d" % index, "第 %d 跳・%s（%s）" % [index, grade, timing], points)
	_feedback("%s　%s　+%d" % [grade, timing, points], color)
	if fountain_attempts >= 3:
		fountain_finish_pending = true
		fountain_finish_at = fountain_jump_started + FOUNTAIN_JUMP_DURATION + FOUNTAIN_LANDING_SETTLE_SECONDS

func _on_ribbon_action_pressed(action: String) -> void:
	if ended or paused or mode != "ribbon_rhythm": return
	ribbon_model.press_action(action)
	_sync_ribbon_model("input")

func _on_ribbon_action_released(action: String) -> void:
	if ended or paused or mode != "ribbon_rhythm": return
	ribbon_model.release_action(action)
	_sync_ribbon_model("input")

func _sync_ribbon_model(_source: String) -> void:
	var state: Dictionary = ribbon_model.snapshot().duplicate(true)
	var trail: Array = state.get("ribbon_trail", [])
	while _ribbon_score_cursor < trail.size():
		var entry: Dictionary = trail[_ribbon_score_cursor]
		var points := (100 if str(entry.get("grade", "")) == "精準" else 60) + (25 if bool(entry.get("strong", false)) else 0)
		_award_points("ribbon_gesture_%d" % int(entry.get("index", _ribbon_score_cursor)), "第 %d 拍・%s%s" % [int(entry.get("index", _ribbon_score_cursor)) + 1, str(entry.get("grade", "合拍")), "・重拍" if bool(entry.get("strong", false)) else ""], points)
		_ribbon_score_cursor += 1
	while _ribbon_error_cursor < int(state.get("error_count", 0)):
		_ribbon_error_cursor += 1
		_feedback(str(state.get("last_event", "這拍失誤")), PINK)
	var notes := int(state.get("note_played_serial", 0))
	while _ribbon_note_cursor < notes:
		var cue: Dictionary = RibbonRhythmModelScript.GESTURES[_ribbon_note_cursor]
		note_played.emit(0 if str(cue.action) == "left" else (1 if str(cue.action) == "right" else 2))
		_ribbon_note_cursor += 1
	_ribbon_snapshot = state
	beat = int(state.get("gesture_index", 0))
	devil_progress = int(state.get("correct_count", 0))
	count = devil_progress
	mistakes = int(state.get("error_count", 0))
	beat_window = false
	var current: Dictionary = state.get("current_gesture", {})
	if not current.is_empty():
		beat_window = absf(float(state.get("elapsed", 0.0)) - float(current.get("time", 0.0))) <= float(state.get("timing_window", 0.0))
	var new_event := str(state.get("last_event", ""))
	if new_event != _ribbon_last_event:
		prompt = new_event
		if _ribbon_error_cursor == int(state.get("error_count", 0)) and str(state.get("last_grade", "")) != "失拍":
			_feedback(new_event, MINT)
		_ribbon_last_event = new_event
	_sync_presentation()
	_refresh_hud(true)
	if bool(state.get("ended", false)):
		if bool(state.get("success", false)):
			_begin_ribbon_finish(state)
		else:
			_finish(false, false)

func _begin_ribbon_finish(state: Dictionary) -> void:
	if ended or ribbon_finish_pending:
		return
	ribbon_finish_success = true
	ribbon_finish_devil = bool(state.get("devil_success", false))
	ribbon_finish_elapsed = 0.0
	ribbon_finish_duration = RIBBON_REDUCED_FINISH_SECONDS if reduced_motion else RIBBON_FINISH_DANCE_SECONDS
	ribbon_finish_pending = true

func _cancel_ribbon_finish_gate() -> void:
	ribbon_finish_pending = false
	ribbon_finish_elapsed = 0.0
	ribbon_finish_duration = RIBBON_FINISH_DANCE_SECONDS
	ribbon_finish_success = false
	ribbon_finish_devil = false

func _rotate_pipe(m: Vector2) -> void:
	var board: Rect2 = PipePlanScript.BOARD_RECT
	if not board.has_point(m): return
	var cell_size := board.size / 4.0
	var col := int((m.x - board.position.x) / cell_size.x)
	var row := int((m.y - board.position.y) / cell_size.y)
	_rotate_pipe_index(row * 4 + col)

func _rotate_pipe_index(idx: int) -> void:
	if pipe_connected or idx < 0 or idx >= 16: return
	pipe_cursor = idx
	var state: Dictionary = pipe_model.rotate(idx)
	flower_cells = pipe_model.cells
	move_count = int(state.total_turns)
	pipe_connected = bool(state.connected)
	if int(state.score) != score: _set_formula_score("pipe_orders", "供水工單與轉動計分", int(state.score))
	if pipe_connected: _feedback("泉水接通了，看看花床！", MINT)
	_sync_presentation()

func _pipe_solved() -> bool:
	return bool(pipe_model.snapshot().connected)

func _bubble_shutter() -> void:
	if ended or paused or str(bubble_model.phase) != "aim":
		return
	var result: Dictionary = bubble_model.shutter()
	if not bool(result.get("accepted", false)):
		if str(result.get("reason", "")) == "not_ready":
			_feedback("姿勢未準備，不消耗本輪", YELLOW)
			_sync_presentation()
			_refresh_hud()
		return
	_sync_bubble_photo_events()
	_sync_presentation()
	_refresh_hud(true)
	if bool(bubble_model.finished):
		_finish(bool(bubble_model.success), bool(bubble_model.devil))
	queue_redraw()

func _notification(what: int) -> void:
	if mode == "bubble_photo" and bubble_model != null and what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		bubble_model.cancel_bubble_charge()
		_sync_presentation()

func _tick_bubble_photo(delta: float) -> void:
	bubble_model.step(delta)
	_sync_bubble_photo_events()
	if bool(bubble_model.finished):
		_finish(bool(bubble_model.success), bool(bubble_model.devil))

func _sync_bubble_photo_events() -> void:
	var state: Dictionary = bubble_model.snapshot()
	var photos: Array = state.photos
	while _bubble_photo_cursor < photos.size():
		var shot: Dictionary = photos[_bubble_photo_cursor]
		var round_index := int(shot.get("round", _bubble_photo_cursor))
		if bool(shot.get("captured", false)):
			var amount := int(shot.get("score", 0))
			_award_points("photo_%d" % round_index, "第 %d 張・構圖得分" % (round_index + 1), amount)
			if bool(shot.get("qualified", false)):
				_feedback("第 %d 張合格・%d 分" % [round_index + 1, amount], MINT if bool(shot.get("perfect", false)) else YELLOW)
			elif not bool(shot.get("bubble_enveloped", false)):
				_feedback("第 %d 張泡泡未包住全身・%d 分" % [round_index + 1, amount], PINK)
			else:
				_feedback("第 %d 張未達合格構圖・%d 分" % [round_index + 1, amount], PINK)
		else:
			mistakes += 1
			_feedback("第 %d 次錯過快門" % (round_index + 1), PINK)
		_bubble_photo_cursor += 1
	count = photos.size()
	beat = int(state.qualified_count)
	devil_progress = int(state.perfect_count)

func _bench_key(index: int) -> void:
	if mode != "bench_swap" or ended or paused or index < 0 or index >= BenchSwapModelScript.SEATS: return
	bench_model.select_seat(index)
	_sync_bench_state()
	_sync_presentation()
	_refresh_hud(true)

func _on_bench_seat_requested(index: int) -> void:
	_bench_key(index)

func _tick_bench_swap(delta: float) -> void:
	if ended or paused: return
	bench_model.step(delta)
	_sync_bench_state()
	if bool(bench_model.snapshot().finished):
		_finish(bool(bench_model.snapshot().success), bool(bench_model.snapshot().devil) and not practice_mode and not assisted)

func _sync_bench_state() -> void:
	var state: Dictionary = bench_model.snapshot()
	seats.assign(state.get("seats", []))
	var ledger: Array = state.get("ledger", [])
	move_count = ledger.size()
	count = 0
	devil_progress = 0
	for record in ledger:
		if not bool(record.get("solved", false)): continue
		count += 1
		if int(record.get("moves", -1)) == int(record.get("optimal_moves", -2)):
			devil_progress += 1
	var model_score := int(state.get("score", 0))
	if model_score > _bench_score_published:
		var table_number := mini(count, BenchSwapModelScript.LEVELS.size())
		_award_points("bench_table_%d" % table_number, "第 %d 桌・符合座位規則" % table_number, model_score - _bench_score_published)
	_bench_score_published = model_score
	var current_event := str(state.get("last_event", ""))
	if current_event != _bench_last_event:
		_bench_last_event = current_event
		prompt = current_event
		feedback_age = 0.0
		feedback_color = MINT if current_event.contains("完成") or current_event.contains("重逢") else BLUE if current_event.contains("選") or current_event.contains("換位") else PINK if current_event.contains("重排") else MINT
	queue_redraw()

func _bench_select_view_index(index: int) -> void:
	_on_bench_seat_requested(index)

func _sync_melody_state(input_note: int = -1) -> void:
	melody_snapshot = melody_model.snapshot()
	var serial := int(melody_snapshot.get("note_start_serial", 0))
	while _melody_audio_cursor < serial:
		_melody_audio_cursor += 1
		var note := input_note if _melody_audio_cursor == serial and input_note >= 0 else int(melody_snapshot.get("current_cue", -1))
		if note >= 0 and note < 4:
			note_played.emit(note)
	var previous_score := score
	var model_score := int(melody_snapshot.get("score", 0))
	if model_score > score:
		_record_score_event("melody_notes", "演奏音符得分", model_score - score)
	score = model_score
	count = int(melody_snapshot.get("completed_phrases", 0))
	devil_progress = int(melody_snapshot.get("precise_notes", 0))
	mistakes = int(melody_snapshot.get("error_count", 0))
	var event := str(melody_snapshot.get("last_event", ""))
	if mistakes > _melody_error_cursor:
		_melody_error_cursor = mistakes
		_melody_last_event = event
		_feedback(event, PINK)
	elif event != _melody_last_event:
		_melody_last_event = event
		prompt = event
		feedback_age = 0.0
		feedback_color = MINT if str(melody_snapshot.get("phase", "")) in ["ready", "active", "complete"] else BLUE
		_refresh_hud(true)
	if is_instance_valid(presentation) and mode == "melody_memory":
		presentation.update_frame(melody_snapshot, time_phase, reduced_motion)
	if score != previous_score:
		_refresh_hud(true)

func _melody_input(note: int) -> void:
	if mode != "melody_memory" or ended or paused:
		return
	melody_model.play_note(note)
	_sync_melody_state(note)
	if bool(melody_snapshot.get("ended", false)):
		_finish(bool(melody_snapshot.get("success", false)), bool(melody_snapshot.get("devil_success", false)) and not practice_mode)
		return
	queue_redraw()

func _on_melody_note_requested(note: int) -> void:
	_melody_input(note)

func _on_melody_replay_requested() -> void:
	if mode != "melody_memory" or ended or paused:
		return
	var before_replays := int(melody_snapshot.get("replay_count", 0))
	melody_model.replay_phrase()
	_sync_melody_state()
	if int(melody_snapshot.get("replay_count", 0)) > before_replays:
		_feedback(str(melody_snapshot.get("last_event", "重聽樂句")), BLUE)
	queue_redraw()

func _feedback(message: String, color: Color) -> void:
	prompt = message; feedback_color = color; feedback_age = 0.0
	feedback_origin = _feedback_anchor()
	if not reduced_motion:
		var palette: Array[Color] = [color, PAPER, YELLOW]
		for i in mini(12, 24 - particles.size()):
			var angle := TAU * float(i) / 12.0 + rng.randf_range(-0.14, 0.14)
			particles.append({"pos": feedback_origin, "velocity": Vector2.RIGHT.rotated(angle) * rng.randf_range(34.0, 84.0), "life": rng.randf_range(0.22, 0.42), "color": palette[i % palette.size()]})
	feedback.emit("success" if color == MINT or color == YELLOW else "miss" if color == PINK else "interact")
	_refresh_hud(true)
	if minigame_hud != null:
		minigame_hud.set_feedback_at(message, feedback_origin)
		if mode == "crowd_traffic":
			var crowd_feedback := minigame_hud.find_child("ContextFeedback", true, false) as Control
			if crowd_feedback != null:
				# Keep the transient callout in the lower HUD band, below the measured 3D playfield.
				crowd_feedback.position = Vector2(clampf(640.0 - crowd_feedback.size.x * 0.5, 30.0, 1280.0 - crowd_feedback.size.x - 30.0), 622.0)

func _feedback_anchor() -> Vector2:
	match mode:
		"balloon_delivery": return Vector2(320, 208)
		"kite_rings": return Vector2(640, 208)
		"fountain_timing": return Vector2(960, 220)
		"crowd_traffic": return Vector2(640, 654)
		"hat_catching": return Vector2(640.0, 448.0)
		"ribbon_rhythm": return Vector2(640, 230)
		"flower_pipes": return Vector2(150, 460)
		"sign_balance": return Vector2(640, 208)
		"shadow_alignment": return Vector2(640, 230)
		"bubble_photo": return Vector2(640, 240)
		"bench_swap":
			var selected_seat := int(bench_model.snapshot().get("selected_seat", -1))
			return presentation.seat_geometry_bounds(selected_seat).get_center() if is_instance_valid(presentation) and selected_seat >= 0 else Vector2(640, 420)
		"melody_memory": return Vector2(640, 405)
	return Vector2(640, 400)

func _to_design(point: Vector2) -> Vector2:
	var scale_factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if scale_factor <= 0.0: return point
	var drawn := DESIGN_SIZE * scale_factor
	return (point - (size - drawn) * 0.5) / scale_factor

func _design_transform() -> void:
	var scale_factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	draw_set_transform((size - DESIGN_SIZE * scale_factor) * 0.5, 0.0, Vector2.ONE * scale_factor)

func _score(amount: int) -> void:
	_award_points("mailbag", "郵袋交付", amount)

func _award_points(key: String, label: String, amount: int, event_count: int = 1) -> void:
	score += amount
	_record_score_event(key, label, amount, event_count)
	_refresh_hud(true)

func _set_formula_score(key: String, label: String, value: int) -> void:
	var adjustment := value - score
	score = value
	if adjustment != 0:
		_record_score_event(key, label, adjustment)
	_refresh_hud(true)

func _record_score_event(key: String, label: String, amount: int, event_count: int = 1) -> void:
	for index in score_events.size():
		if str(score_events[index].get("key", "")) != key:
			continue
		var existing: Dictionary = score_events[index]
		existing.amount = int(existing.get("amount", 0)) + amount
		existing.count = int(existing.get("count", 0)) + event_count
		score_events[index] = existing
		return
	if score_events.size() < 31:
		score_events.append({"key": key, "label": label, "amount": amount, "count": event_count})
		return
	# Keep the ledger bounded without dropping any earned or deducted points.
	var aggregate: Dictionary = {"key": "other_events", "label": "其他得分事件", "amount": amount, "count": event_count}
	for index in score_events.size():
		if str(score_events[index].get("key", "")) == "other_events":
			aggregate = score_events[index]
			aggregate.amount = int(aggregate.amount) + amount
			aggregate.count = int(aggregate.count) + event_count
			score_events[index] = aggregate
			return
	score_events.append(aggregate)

func _shadow_pointer_target(point: Vector2) -> Vector2:
	var x := lerpf(ShadowTheatreModelScript.LAMP_X_MIN, ShadowTheatreModelScript.LAMP_X_MAX, clampf((point.x - 160.0) / 960.0, 0.0, 1.0))
	var depth := lerpf(ShadowTheatreModelScript.LAMP_Z_MAX, ShadowTheatreModelScript.LAMP_Z_MIN, clampf((point.y - 176.0) / 440.0, 0.0, 1.0))
	return Vector2(x, depth)

func _finish(success: bool, devil: bool = false) -> void:
	if ended: return
	ended = true; won = success; devil_won = success and devil
	var result := {"game_id": game_id, "success": success, "devil": devil_won, "score": score, "assisted": assisted, "practice": practice_mode, "mistakes": mistakes, "score_summary": score_summary()}
	minigame_hud.set_score_details(result.score_summary)
	finished.emit(result)
	_refresh_hud(true)
	queue_redraw()

func _draw() -> void:
	var viewport_size := size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), BG)
	_design_transform()
	if mode in ["balloon_delivery", "flower_pipes", "crowd_traffic", "kite_rings", "bubble_photo", "sign_balance", "bench_swap", "hat_catching"]:
		if mode == "balloon_delivery" and is_instance_valid(presentation):
			var harbor_texture: Texture2D = presentation.texture()
			if harbor_texture != null:
				draw_texture_rect(harbor_texture, Rect2(Vector2.ZERO, DESIGN_SIZE), false)
		draw_set_transform(Vector2.ZERO)
		return
	_draw_backdrop()
	# Warm inked frame, corner rivets and paper mat establish the harbor paper-theatre look.
	draw_rect(Rect2(18,18,1244,684), Color("#f2d6a7"), false, 4)
	draw_rect(Rect2(25,25,1230,670), Color(GOLD, 0.72), false, 2)
	for corner in [Vector2(42,42), Vector2(1238,42), Vector2(42,678), Vector2(1238,678)]:
		draw_circle(corner, 8, GOLD); draw_circle(corner, 3, PAPER)
	_draw_game()
	for particle in particles:
		var alpha := clampf(float(particle.life) / 0.42, 0.0, 1.0)
		draw_circle(particle.pos, 3.0 + alpha * 2.0, Color(particle.color, alpha))
	if feedback_age < 0.48:
		var stamp_alpha := 1.0 if reduced_motion else clampf(1.0-feedback_age/0.48,0.0,1.0)
		var stamp_radius := 30.0 if reduced_motion else 28.0+sin(feedback_age*PI/0.48)*8.0
		draw_circle(feedback_origin,stamp_radius,Color("#173248",0.72*stamp_alpha))
		draw_arc(feedback_origin,stamp_radius,0,TAU,32,Color(feedback_color,stamp_alpha),4)
		draw_circle(feedback_origin,5,Color(feedback_color,stamp_alpha))
	draw_set_transform(Vector2.ZERO)

func _draw_backdrop() -> void:
	var scene := "harbor"
	var tint := Color("#4b928e")
	match mode:
		"balloon_delivery": scene = "harbor"; tint = Color("#78afa3")
		"fountain_timing": scene = "garden"; tint = Color("#7ba995")
		"crowd_traffic": scene = "stage"; tint = Color("#b69477")
		"hat_catching": scene = "stage"; tint = Color("#c59485")
		"ribbon_rhythm": scene = "stage"; tint = Color("#806b86")
		"flower_pipes": scene = "garden"; tint = Color("#8ba976")
		"sign_balance": scene = "harbor"; tint = Color("#bd9c6e")
		"shadow_alignment": scene = "night"; tint = Color("#394968")
		"bubble_photo": scene = "night"; tint = Color("#527489")
		"bench_swap": scene = "garden"; tint = Color("#80aa95")
		"melody_memory": scene = "night"; tint = Color("#697794")
	draw_rect(Rect2(0,0,1280,720), tint)
	var atlas_path := "res://assets/minigames/backdrops/tidal-atlas-v3.png"
	if not _backdrop_checked:
		_backdrop_checked = true
		if ResourceLoader.exists(atlas_path):
			var loaded_atlas: Resource = load(atlas_path)
			if loaded_atlas is Texture2D:
				_backdrop_texture = loaded_atlas
			else:
				_warn_backdrop_asset("Invalid minigame backdrop atlas: " + atlas_path)
		else:
			_warn_backdrop_asset("Missing minigame backdrop atlas: " + atlas_path)
	if _backdrop_texture:
		if not _scene_textures.has(scene):
			var atlas_size := _backdrop_texture.get_size()
			var split_x := int(atlas_size.x / 2)
			var split_y := int(atlas_size.y / 2)
			var source := Vector2i.ZERO
			var region_size := Vector2i(split_x,split_y)
			match scene:
				"garden": source = Vector2i(split_x,0); region_size = Vector2i(atlas_size.x-split_x,split_y)
				"stage": source = Vector2i(0,split_y); region_size = Vector2i(split_x,atlas_size.y-split_y)
				"night": source = Vector2i(split_x,split_y); region_size = Vector2i(atlas_size.x-split_x,atlas_size.y-split_y)
			if region_size.x <= 0 or region_size.y <= 0:
				_warn_backdrop_asset("Invalid minigame backdrop dimensions at " + atlas_path)
				_backdrop_texture = null
				return
			# Each quadrant uses its exact half-size bounds; AtlasTexture clips filtering to the region.
			var region := Rect2(Vector2(source),Vector2(region_size))
			var scene_texture := AtlasTexture.new()
			scene_texture.atlas = _backdrop_texture
			scene_texture.region = region
			scene_texture.filter_clip = true
			_scene_textures[scene] = scene_texture
		var texture: Texture2D = _scene_textures[scene]
		var target := Rect2(29,122,1222,492)
		# Cover the play area at one uniform scale; wheels and window frames keep their proportions.
		var source_size := texture.get_size()
		var cover_scale := maxf(target.size.x / source_size.x, target.size.y / source_size.y)
		var visible_size := target.size / cover_scale
		var visible_region := Rect2((source_size - visible_size) * 0.5, visible_size)
		draw_texture_rect_region(texture,target,visible_region,Color(1,1,1,0.76))
	# Layered tide lines and a promenade ground band keep absent backdrops fully composed.
	for i in 7:
		var y := 145.0 + i * 65.0
		var line_color := Color(PAPER, 0.055 if i % 2 == 0 else 0.09)
		draw_line(Vector2(42,y), Vector2(1238,y + 12), line_color, 2)
	draw_rect(Rect2(30,576,1220,38), Color("#315d60",0.72), true)
	draw_line(Vector2(34,576),Vector2(1246,576),Color("#efcf93",0.7),3)
	# Scalloped printed edge and tiny brass stars add paper-cut depth without covering play.
	for i in 18:
		var x := 66.0 + i * 67.0
		draw_arc(Vector2(x,602), 8, PI, TAU, 10, Color("#e9cd9c",0.45), 2)
	for star in [Vector2(78,157),Vector2(1195,170),Vector2(1182,545),Vector2(92,548)]:
		draw_circle(star, 3, Color("#ffe6a8",0.65))
	# Scene-specific theater dressing gives each activity a distinct camera and silhouette.
	match mode:
		"balloon_delivery":
			_draw_cloud(Vector2(200,208),0.85); _draw_cloud(Vector2(1040,205),0.72)
			_draw_lighthouse(Vector2(1150,440)); _draw_boat(Vector2(270,548),0.8)
		"fountain_timing", "flower_pipes", "bench_swap":
			_draw_topiary(Vector2(130,450),0.78); _draw_topiary(Vector2(1150,450),0.78)
			_draw_awning(245,190,790)
		"crowd_traffic", "hat_catching", "ribbon_rhythm":
			_draw_curtain(40,150,165,430); _draw_curtain(1075,150,165,430)
			for x in [300,640,980]: _draw_lantern(Vector2(x,174),0.8)
		"sign_balance":
			_draw_boat(Vector2(170,540),0.55); _draw_lighthouse(Vector2(1120,475))
		"shadow_alignment", "bubble_photo", "melody_memory":
			_draw_moon(Vector2(1125,205)); _draw_lantern(Vector2(180,235),0.95)
			for x in [345,640,935]: _draw_topiary(Vector2(x,555),0.42)
	# Apply time-of-day to the authored backdrop only; targets, actors, and text
	# are drawn later and keep their original contrast and interaction cues.
	if phase_wash.a > 0.0:
		draw_rect(Rect2(29,122,1222,492),phase_wash,true)

func _warn_backdrop_asset(message: String) -> void:
	if _backdrop_warning_emitted: return
	_backdrop_warning_emitted = true
	push_warning(message)

func art_cache_status() -> Dictionary:
	# Read-only smoke hook: call after drawing each mode to confirm real assets and regions loaded.
	var loaded_props: Array[String] = []
	var missing_props: Array[String] = []
	for key in REQUIRED_PROP_KEYS:
		if _prop_textures.get(key) is Texture2D: loaded_props.append(key)
		else: missing_props.append(key)
	var loaded_scenes: Array[String] = []
	var missing_scenes: Array[String] = []
	for key in BACKDROP_SCENES:
		if _scene_textures.get(key) is Texture2D: loaded_scenes.append(key)
		else: missing_scenes.append(key)
	return {
		"props_atlas_loaded": _props_atlas != null,
		"props_regions_loaded": _props_available,
		"props_loaded": loaded_props,
		"props_missing": missing_props,
		"backdrop_atlas_loaded": _backdrop_texture != null,
		"backdrops_loaded": loaded_scenes,
		"backdrops_missing": missing_scenes,
	}

func art_assets_ready() -> bool:
	var status := art_cache_status()
	return bool(status.props_atlas_loaded) and bool(status.props_regions_loaded) and status.props_missing.is_empty() and bool(status.backdrop_atlas_loaded) and status.backdrops_missing.is_empty()

func _draw_cloud(center: Vector2, scale_factor: float = 1.0) -> void:
	var c := Color("#f4e7c9",0.72)
	for blob in [Vector2(-30,8),Vector2(-8,-8),Vector2(18,-10),Vector2(40,8)]: draw_circle(center + blob * scale_factor, 18 * scale_factor, c)
	draw_rect(Rect2(center.x - 37*scale_factor,center.y,78*scale_factor,16*scale_factor),c,true)

func _draw_boat(center: Vector2, scale_factor: float = 1.0) -> void:
	var hull := PackedVector2Array([center+Vector2(-56,0)*scale_factor,center+Vector2(50,0)*scale_factor,center+Vector2(34,20)*scale_factor,center+Vector2(-38,20)*scale_factor])
	draw_colored_polygon(hull, Color("#a7664d",0.9)); draw_line(center+Vector2(-60,2)*scale_factor,center+Vector2(52,2)*scale_factor,GOLD,3*scale_factor)
	draw_line(center+Vector2(0,0),center+Vector2(0,-38)*scale_factor,PAPER,3*scale_factor)
	draw_colored_polygon(PackedVector2Array([center+Vector2(2,-36)*scale_factor,center+Vector2(32,-5)*scale_factor,center+Vector2(2,-5)*scale_factor]), Color("#e9c782",0.9))

func _draw_lighthouse(center: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([center+Vector2(-27,0),center+Vector2(27,0),center+Vector2(20,-90),center+Vector2(-20,-90)]),Color("#f2dfb9"))
	for y in [-72,-40]: draw_rect(Rect2(center.x-22,center.y+y,44,11),Color("#cb735d"),true)
	draw_rect(Rect2(center.x-24,center.y-102,48,14),Color("#31485b"),true); draw_colored_polygon(PackedVector2Array([center+Vector2(-31,-102),center+Vector2(0,-122),center+Vector2(31,-102)]),GOLD)
	draw_rect(Rect2(center.x-7,center.y-84,14,17),Color("#8ec9c2"),true)

func _draw_topiary(center: Vector2, scale_factor: float = 1.0) -> void:
	draw_rect(Rect2(center.x-20*scale_factor,center.y,40*scale_factor,60*scale_factor),Color("#ae774d"),true)
	draw_circle(center+Vector2(0,-18)*scale_factor,31*scale_factor,Color("#3d806d")); draw_circle(center+Vector2(-17,-4)*scale_factor,19*scale_factor,Color("#579173")); draw_circle(center+Vector2(17,-4)*scale_factor,19*scale_factor,Color("#579173"))
	draw_circle(center+Vector2(-9,-20)*scale_factor,4*scale_factor,YELLOW); draw_circle(center+Vector2(11,-22)*scale_factor,4*scale_factor,PINK)

func _draw_awning(x: float, y: float, width: float) -> void:
	draw_rect(Rect2(x,y,width,24),Color("#b37256"),true)
	for i in 9:
		var sx := x + i * width / 9.0
		draw_rect(Rect2(sx,y+21,width/9.0,13),PAPER if i%2==0 else Color("#d6906b"),true)
		draw_circle(Vector2(sx+width/18.0,y+34),6,PAPER if i%2==0 else Color("#d6906b"))

func _draw_curtain(x: float, y: float, width: float, height: float) -> void:
	draw_rect(Rect2(x,y,width,height),Color("#663c59",0.85),true)
	for i in 4:
		var fold_x := x + i * width / 3.0
		draw_line(Vector2(fold_x,y+8),Vector2(fold_x-12,y+height-5),Color("#bd7083",0.58),7)
	draw_arc(Vector2(x+width/2,y+5),width/2,0,PI,24,Color("#e7b983"),7)

func _draw_lantern(center: Vector2, scale_factor: float = 1.0) -> void:
	if _draw_prop("lantern",Rect2(center.x-19*scale_factor,center.y-36*scale_factor,38*scale_factor,72*scale_factor)): return
	draw_line(center+Vector2(0,-45)*scale_factor,center+Vector2(0,-20)*scale_factor,INK,3)
	draw_colored_polygon(PackedVector2Array([center+Vector2(-18,-20)*scale_factor,center+Vector2(18,-20)*scale_factor,center+Vector2(13,20)*scale_factor,center+Vector2(-13,20)*scale_factor]),Color("#efb66b",0.92))
	draw_line(center+Vector2(-12,-15)*scale_factor,center+Vector2(-10,15)*scale_factor,Color("#fff0bd",0.8),3*scale_factor)

func _draw_moon(center: Vector2) -> void:
	draw_circle(center,36,Color("#f5d692",0.9)); draw_circle(center+Vector2(14,-9),34,Color("#586d83",0.9))
	for dot in [Vector2(-45,28),Vector2(42,48),Vector2(-8,65)]: draw_circle(center+dot,3,Color("#fff0bf",0.78))

func _draw_person(center: Vector2, palette: Color, pose: int = 0, scale_factor: float = 1.0) -> void:
	# Original paper-cut island visitor: cap, face, collar, coat and small working limbs.
	var c := center
	draw_rect(Rect2(c.x-13*scale_factor,c.y-4*scale_factor,26*scale_factor,15*scale_factor),Color("#bf7958"),true)
	draw_circle(c+Vector2(-9,-4)*scale_factor,5*scale_factor,Color("#bf7958")); draw_circle(c+Vector2(9,-4)*scale_factor,5*scale_factor,Color("#bf7958"))
	draw_circle(c+Vector2(0,-20)*scale_factor,13*scale_factor,Color("#f1c49a"))
	draw_rect(Rect2(c.x-13*scale_factor,c.y-34*scale_factor,26*scale_factor,7*scale_factor),palette,true)
	draw_arc(c+Vector2(0,-33)*scale_factor,14*scale_factor,PI,TAU,12,palette,5*scale_factor)
	draw_circle(c+Vector2(-4,-20)*scale_factor,1.6*scale_factor,INK); draw_circle(c+Vector2(4,-20)*scale_factor,1.6*scale_factor,INK)
	draw_line(c+Vector2(-10,5)*scale_factor,c+Vector2(-15,-8)*scale_factor,Color("#f1c49a"),4*scale_factor)
	draw_line(c+Vector2(10,5)*scale_factor,c+Vector2(15,-8 + float(pose%2)*9)*scale_factor,Color("#f1c49a"),4*scale_factor)
	draw_line(c+Vector2(-7,9)*scale_factor,c+Vector2(-9,19)*scale_factor,INK,3*scale_factor); draw_line(c+Vector2(7,9)*scale_factor,c+Vector2(10,18)*scale_factor,INK,3*scale_factor)

func _draw_tourist(name: String, rect: Rect2, fallback_color: Color, ground_y := -1.0) -> void:
	var foot_y := ground_y if ground_y >= 0.0 else rect.end.y
	_draw_actor_contact_shadow(Vector2(rect.position.x+rect.size.x*0.5,foot_y),Vector2(maxf(15.0,rect.size.x*0.32),maxf(4.0,rect.size.y*0.055)))
	if not _draw_prop(name,rect): _draw_person(rect.position+rect.size*0.5,fallback_color,0,1.0)

func _draw_actor_contact_shadow(center: Vector2, radii: Vector2) -> void:
	var shifted := center+Vector2(phase_shadow_x,2.0)
	_draw_ellipse(shifted,radii,phase_shadow_color)

func _draw_devil_mascot(center: Vector2, radius: float = 34.0) -> void:
	if _draw_prop("mascot",Rect2(center.x-radius*1.13,center.y-radius*1.13,radius*2.26,radius*2.26)): return
	# Little tide imp "Koro": scalloped ears, coral horns, star bib and curled tail.
	draw_arc(center+Vector2(radius*0.92, radius*0.35),radius*0.55,-1.5,1.5,20,Color("#ef91a5"),5)
	draw_colored_polygon(PackedVector2Array([center+Vector2(-radius*.58,-radius*.65),center+Vector2(-radius*.80,-radius*1.22),center+Vector2(-radius*.13,-radius*.82)]),Color("#d98998"))
	draw_colored_polygon(PackedVector2Array([center+Vector2(radius*.58,-radius*.65),center+Vector2(radius*.80,-radius*1.22),center+Vector2(radius*.13,-radius*.82)]),Color("#d98998"))
	draw_colored_polygon(PackedVector2Array([center+Vector2(-radius*.36,-radius*.73),center+Vector2(-radius*.13,-radius*1.35),center+Vector2(radius*.02,-radius*.73)]),Color("#d85e63"))
	draw_colored_polygon(PackedVector2Array([center+Vector2(radius*.36,-radius*.73),center+Vector2(radius*.13,-radius*1.35),center+Vector2(-radius*.02,-radius*.73)]),Color("#d85e63"))
	draw_circle(center,radius,Color("#f5c277")); draw_circle(center+Vector2(0,radius*.34),radius*.52,Color("#fff0cf"))
	draw_circle(center+Vector2(-radius*.31,-radius*.06),radius*.085,INK); draw_circle(center+Vector2(radius*.31,-radius*.06),radius*.085,INK)
	draw_arc(center+Vector2(0,radius*.13),radius*.2,0,PI,16,INK,2)
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,radius*.48),center+Vector2(radius*.13,radius*.65),center,center+Vector2(-radius*.13,radius*.65)]),Color("#df6e6b"))

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24: points.append(center+Vector2(cos(TAU*i/24.0)*radii.x,sin(TAU*i/24.0)*radii.y))
	draw_colored_polygon(points,color)

func _draw_prop(name: String, rect: Rect2, modulation: Color = Color.WHITE) -> bool:
	var sprite := _prop_texture(name)
	if sprite == null: return false
	draw_texture_rect(sprite,rect,false,modulation)
	return true

func _draw_rotated_prop(name: String, center: Vector2, dimensions: Vector2, angle: float, modulation: Color = Color.WHITE) -> bool:
	var sprite := _prop_texture(name)
	if sprite == null: return false
	var factor := minf(size.x/DESIGN_SIZE.x,size.y/DESIGN_SIZE.y)
	var offset := (size-DESIGN_SIZE*factor)*0.5+center*factor
	draw_set_transform(offset,angle,Vector2.ONE*factor)
	draw_texture_rect(sprite,Rect2(-dimensions*0.5,dimensions),false,modulation)
	_design_transform()
	return true

func _prop_texture(name: String) -> Texture2D:
	if _prop_textures.has(name): return _prop_textures[name]
	if not _props_checked:
		_props_checked = true
		var atlas_path := "res://assets/minigames/props/tidal-props-v2.png"
		if not ResourceLoader.exists(atlas_path):
			_warn_prop_asset("Missing prop atlas: " + atlas_path)
			_prop_textures[name] = null
			return null
		var loaded_atlas: Resource = load(atlas_path)
		if not loaded_atlas is Texture2D:
			_warn_prop_asset("Invalid prop atlas: " + atlas_path)
			_prop_textures[name] = null
			return null
		_props_atlas = loaded_atlas
		var region_path := "res://assets/minigames/props/regions.json"
		if not ResourceLoader.exists(region_path):
			_warn_prop_asset("Missing prop regions: " + region_path)
			_prop_textures[name] = null
			return null
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(region_path))
		if not parsed is Dictionary:
			_warn_prop_asset("Invalid prop region JSON: " + region_path)
			_prop_textures[name] = null
			return null
		_prop_regions = parsed
		_props_available = true
	if not _props_available:
		_prop_textures[name] = null
		return null
	if not _prop_regions.has(name):
		_warn_prop_asset("No region for prop '%s' in res://assets/minigames/props/regions.json" % name)
		_prop_textures[name] = null
		return null
	if not _prop_regions[name] is Array:
		_warn_prop_asset("Non-array region for prop '%s' in res://assets/minigames/props/regions.json" % name)
		_prop_textures[name] = null
		return null
	var region: Array = _prop_regions[name]
	if region.size() != 4:
		_warn_prop_asset("Bad region for prop '%s' in res://assets/minigames/props/regions.json" % name)
		_prop_textures[name] = null
		return null
	for coordinate in region:
		if not (coordinate is int or coordinate is float):
			_warn_prop_asset("Non-numeric region for prop '%s' in res://assets/minigames/props/regions.json" % name)
			_prop_textures[name] = null
			return null
	var source_rect := Rect2i(int(region[0]),int(region[1]),int(region[2]),int(region[3]))
	var atlas_size := _props_atlas.get_size()
	if source_rect.position.x < 0 or source_rect.position.y < 0 or source_rect.size.x <= 0 or source_rect.size.y <= 0 or source_rect.end.x > atlas_size.x or source_rect.end.y > atlas_size.y:
		_warn_prop_asset("Out-of-bounds region for prop '%s' in res://assets/minigames/props/regions.json" % name)
		_prop_textures[name] = null
		return null
	var texture := AtlasTexture.new()
	texture.atlas = _props_atlas
	texture.region = Rect2(source_rect)
	texture.filter_clip = true
	_prop_textures[name] = texture
	return texture

func _warn_prop_asset(message: String) -> void:
	if _props_warning_emitted: return
	_props_warning_emitted = true
	push_warning(message)

func _definition() -> Dictionary:
	if _catalog_cache.is_empty(): definitions()
	for item in _catalog_cache:
		if item.id == game_id: return item
	return {"name":"小遊戲", "goal":"完成挑戰", "instructions":"依畫面提示操作", "devil_hint":"完成額外條件", "devil":"完成額外條件", "ordinary":"完成挑戰"}

func _draw_game() -> void:
	match mode:
		"balloon_delivery": _draw_balloon()
		"fountain_timing": pass # The child SubViewport owns this mode's full 3D stage.
		"crowd_traffic": _draw_crowd()
		"ribbon_rhythm": _draw_ribbon()
		"flower_pipes": _draw_flower()
		"sign_balance": _draw_sign()
		"shadow_alignment": _draw_shadow()
		"bench_swap": pass
		"melody_memory": pass

func _draw_scene_label(text: String, baseline: Vector2, font_size: int, alignment: int = HORIZONTAL_ALIGNMENT_CENTER, color: Color = INK) -> void:
	# Keep functional copy readable over every printed backdrop without laying a full-width strip over the scene.
	var measured_width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var plate_width := minf(measured_width + 24.0, 760.0)
	var left := baseline.x - plate_width * 0.5
	if alignment == HORIZONTAL_ALIGNMENT_LEFT:
		left = baseline.x - 8.0
	var plate := Rect2(left, baseline.y - font_size - 7.0, plate_width, font_size + 15.0)
	draw_rect(plate, Color("#fff0d2", 0.94), true)
	draw_rect(plate, Color("#87674d", 0.88), false, 1.5)
	draw_string(FONT, Vector2(left + 6.0, baseline.y), text, alignment, plate_width - 12.0, font_size, color)

func _draw_balloon() -> void:
	# Three ordered mail drops give the flight short goals and route decisions.
	draw_rect(Rect2(62,492,1156,78),Color("#bd9a6d"),true)
	for i in 14: draw_line(Vector2(72+i*82,495),Vector2(72+i*82,567),Color("#e6c793",0.8),2)
	for i in range(1, BALLOON_MAILBOXES.size()):
		draw_line(BALLOON_MAILBOXES[i-1], BALLOON_MAILBOXES[i], Color("#fff1cb",0.42), 3)
		for dot in 8:
			var point := BALLOON_MAILBOXES[i-1].lerp(BALLOON_MAILBOXES[i], float(dot+1)/9.0)
			draw_circle(point, 3, Color("#fff1cb",0.65))
	for i in BALLOON_MAILBOXES.size():
		var mailbox_point: Vector2 = BALLOON_MAILBOXES[i]
		var active := i == balloon_delivery_index and balloon_started
		var delivered := i < balloon_delivery_index
		var alpha := 1.0 if active or delivered else 0.68
		var ring_color := MINT if delivered else YELLOW if active else Color("#fff1cb",0.55)
		draw_circle(mailbox_point, balloon_dock_radius if active else 51.0, Color(ring_color, 0.08 if active else 0.04))
		draw_arc(mailbox_point, balloon_dock_radius if active else 51.0, 0, TAU, 48, ring_color, 5 if active else 2)
		var mailbox_rect := Rect2(mailbox_point.x-61,mailbox_point.y-75,122,150)
		if not _draw_prop("mailbox",mailbox_rect,Color(1,1,1,alpha)):
			draw_rect(mailbox_rect,Color("#bd704f",alpha),true)
		draw_rect(Rect2(mailbox_point.x-14,mailbox_point.y-8,28,16),Color("#fff1cb",alpha),true)
		draw_circle(mailbox_point+Vector2(0,25),13,Color("#e6bf80",alpha))
		draw_string(FONT,mailbox_point+Vector2(-8,30),"✓" if delivered else str(i+1),HORIZONTAL_ALIGNMENT_CENTER,16,12,INK)
	# A ghosted future position forecasts the bounded moving urchin hazard.
	var thorn := _balloon_hazard_at(phase)
	var thorn_preview := _balloon_hazard_at(phase + BALLOON_WIND_FORECAST_SECONDS)
	draw_arc(thorn_preview,65,0,TAU,40,Color(PINK,0.35),2)
	draw_circle(thorn,65,Color(PINK,0.10)); draw_arc(thorn,65,0,TAU,40,Color(PINK,0.82),2)
	if not _draw_prop("urchin",Rect2(thorn.x-52,thorn.y-52,104,104)):
		for i in 12:
			var a := TAU*float(i)/12.0
			draw_line(thorn+Vector2.RIGHT.rotated(a)*23,thorn+Vector2.RIGHT.rotated(a)*50,Color("#514963"),7)
			draw_colored_polygon(PackedVector2Array([thorn+Vector2.RIGHT.rotated(a)*48,thorn+Vector2.RIGHT.rotated(a+0.13)*36,thorn+Vector2.RIGHT.rotated(a-0.13)*36]),Color("#e8a17c"))
		draw_circle(thorn,27,Color("#d78072")); draw_circle(thorn+Vector2(-8,-6),4,PAPER); draw_circle(thorn+Vector2(8,-6),4,PAPER)
	# Three labeled altitude lanes use the same phase and altitude inputs as the
	# force applied in _balloon_wind_at, so the visible arrows preview route choice.
	var lane_y: Array[float] = [245.0, 395.0, 550.0]
	var lane_names: Array[String] = ["高風道", "中風道", "低風道"]
	for lane in 3:
		var yy: float = lane_y[lane]
		var lane_wind := _balloon_wind_at(phase, yy)
		var lane_direction := signf(lane_wind.x)
		var lane_arrow := "→" if lane_direction > 0.0 else "←" if lane_direction < 0.0 else "↔"
		draw_string(FONT,Vector2(63,yy+5),lane_names[lane]+"  "+lane_arrow,HORIZONTAL_ALIGNMENT_LEFT,110,13,Color("#fff1cb",0.9))
		for i in 4:
			var offset := 0.0 if reduced_motion else fposmod(phase * 58.0 + i * 43.0, 110.0)
			var start_x := 185.0 + float(i) * 54.0 + offset
			if lane_direction == 0.0:
				draw_circle(Vector2(start_x,yy),2.5,Color("#eef5db",0.72))
				continue
			var arrow_direction := lane_direction
			var arrow_length := 10.0 + absf(lane_wind.x) * 0.30
			var end_x := start_x + arrow_direction * arrow_length
			draw_line(Vector2(start_x,yy),Vector2(end_x,yy),Color("#eef5db",0.62),2)
			draw_colored_polygon(PackedVector2Array([Vector2(end_x,yy),Vector2(end_x-arrow_direction*8,yy-4),Vector2(end_x-arrow_direction*8,yy+4)]),Color("#eef5db",0.76))
	# The balloon's ribbon acts as an in-world tell for current crosswind. Calm
	# air hangs straight; stronger wind increases the sideways deflection.
	if not _draw_prop("balloon",Rect2(p.x-39,p.y-56,78,110)):
		draw_circle(p,33,Color("#dc6588")); draw_arc(p,31,PI,TAU,22,Color("#ffd39c"),2)
		draw_line(p+Vector2(-9,31),p+Vector2(-5,43),PAPER,2); draw_line(p+Vector2(9,31),p+Vector2(5,43),PAPER,2)
		draw_rect(Rect2(p.x-9,p.y+42,18,12),Color("#8b684e"),true)
	var wind_sign := signf(balloon_wind_current.x)
	var ribbon_deflection := 54.0 * clampf(absf(balloon_wind_current.x) / 60.0,0.0,1.0) * wind_sign
	var ribbon_end := p + Vector2(-ribbon_deflection,58.0 + absf(ribbon_deflection)*0.18)
	draw_line(p+Vector2(0,50),ribbon_end,Color("#ffe3a4"),4)
	var tail_direction := signf(ribbon_end.x-p.x)
	if tail_direction == 0.0:
		draw_colored_polygon(PackedVector2Array([ribbon_end,ribbon_end+Vector2(-8,9),ribbon_end+Vector2(8,9)]),PINK)
	else:
		draw_colored_polygon(PackedVector2Array([ribbon_end,ribbon_end+Vector2(tail_direction*18,-3),ribbon_end+Vector2(tail_direction*8,8)]),PINK)
	_draw_balloon_wind_gauge()
	if balloon_started:
		_draw_scene_label("郵袋 " + str(balloon_delivery_index) + " / 3　　煞停進入第 " + str(balloon_delivery_index+1) + " 號信箱",Vector2(640,585),18)
		if balloon_dock_hold > 0.0:
			var dock_fraction := clampf(balloon_dock_hold / BALLOON_DOCK_HOLD_SECONDS,0.0,1.0)
			draw_rect(Rect2(target.x-48,target.y+balloon_dock_radius+6,96,8),Color("#31495b"),true)
			draw_rect(Rect2(target.x-48,target.y+balloon_dock_radius+6,96*dock_fraction,8),MINT,true)
	else:
		var lesson: String = ["1　← →／WASD 推動", "2　↑↓ 換風道　・　空白／右鍵煞車", "3　投遞三站　・　Enter 開始計時"][balloon_intro_step]
		_draw_scene_label("氣球快遞練習　" + lesson,Vector2(470,205),17)

func _draw_balloon_wind_gauge() -> void:
	draw_rect(Rect2(930,174,285,92),Color("#fff0d5",0.94),true)
	draw_rect(Rect2(930,174,285,92),Color("#87674d",0.88),false,2)
	var direction := "→" if balloon_wind_current.x > 0.0 else "←" if balloon_wind_current.x < 0.0 else "↔"
	var forecast_direction := "→" if balloon_wind_forecast.x > 0.0 else "←" if balloon_wind_forecast.x < 0.0 else "↔"
	draw_string(FONT,Vector2(944,199),"海風　"+direction,HORIZONTAL_ALIGNMENT_LEFT,100,17,INK)
	var feather_count := clampi(int(ceil(absf(balloon_wind_current.x)/18.0)),0,3)
	for i in 3:
		var fx := 1019.0+i*15.0
		draw_line(Vector2(fx,187),Vector2(fx+(4.0 if balloon_wind_current.x>=0.0 else -4.0),198),Color("#557e80") if i<feather_count else Color("#bba88c",0.55),3)
	var forecast_value := roundi(balloon_wind_forecast.x)
	var forecast_signed := "+" + str(forecast_value) if forecast_value > 0 else str(forecast_value)
	draw_string(FONT,Vector2(944,223),"0.8 秒預報　"+forecast_direction+" "+forecast_signed,HORIZONTAL_ALIGNMENT_LEFT,200,13,Color("#536874"))
	var bar := Rect2(944,237,244,12)
	draw_rect(bar,Color("#d7c7a5"),true)
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(absf(balloon_wind_current.x)/60.0,0.0,1.0),bar.size.y)),Color("#55a99f"),true)
	var needle_x := 944.0 + bar.size.x * clampf((balloon_wind_current.x / 60.0 + 1.0) * 0.5,0.0,1.0)
	draw_line(Vector2(needle_x,232),Vector2(needle_x,253),Color("#bd704f"),3)


func _draw_fountain() -> void:
	draw_rect(Rect2(151,464,978,94),Color("#5c8b8e"),true); draw_circle(Vector2(151,511),47,Color("#5c8b8e")); draw_circle(Vector2(1129,511),47,Color("#5c8b8e"))
	draw_rect(Rect2(150,480,980,51),Color("#77aaa3"),true)
	for i in 5:
		var x := 260.0 + i * 190.0
		var height: float
		if i == 2 and fountain_attempts < 3:
			var offset := phase - _fountain_beat_time(fountain_attempts)
			height = 108.0 if reduced_motion else 42.0 + 132.0 * (0.5 + 0.5 * cos(PI * offset / (FOUNTAIN_PERIOD * 0.5)))
		else:
			height = 78.0 if reduced_motion else 42.0 + absf(sin(phase * 2.3 + i * 0.7)) * 132.0
		var near_cue := i == 2 and fountain_attempts < 3 and absf(phase - _fountain_beat_time(fountain_attempts)) <= 0.44
		var active := near_cue and beat_window
		var jet_color := MINT if active else YELLOW if near_cue else Color("#75aac0")
		draw_line(Vector2(x,484), Vector2(x,484-height), Color("#a8eff0",0.35), 24)
		draw_line(Vector2(x,484), Vector2(x,484-height), Color("#78dfe3") if near_cue else Color("#75aac0"), 13)
		draw_circle(Vector2(x,484-height), 11, Color("#f1ffff") if active else BLUE if not near_cue else PAPER)
		draw_arc(Vector2(x,484-height),18,PI,TAU,16,jet_color,3 if active else 2)
	var jump_age := phase - fountain_jump_started
	var airborne := fountain_jump_started >= 0.0 and jump_age >= 0.0 and jump_age < FOUNTAIN_JUMP_DURATION
	var jump_progress := clampf(jump_age / FOUNTAIN_JUMP_DURATION, 0.0, 1.0) if airborne else 0.0
	var jump_lift := 48.0 * sin(PI * jump_progress) if airborne and not reduced_motion else 0.0
	draw_circle(Vector2(640,465-jump_lift),54,Color(MINT,0.18) if airborne else Color(BLUE,0.10))
	_draw_fountain_avatar(jump_lift, jump_progress, airborne)
	var jump_label := "完成三跳　·　查看分數明細" if fountain_attempts >= 3 else "Space／點擊起跳　·　機會 %d / 3" % (fountain_attempts + 1)
	if fountain_attempts < 3:
		var seconds_to_beat := _fountain_beat_time(fountain_attempts) - phase
		if seconds_to_beat > _fountain_hit_tolerance():
			jump_label = ("水柱蓄水　·　%.1fs 後預亮" % maxf(0.0, seconds_to_beat - 0.44)) if seconds_to_beat > 0.44 else "中央水簾預亮　·　準備起跳"
		elif beat_window:
			jump_label = "現在起跳！　·　Space／點擊"
		elif seconds_to_beat > 0.0:
			jump_label = "中央水簾升至拍點　·　準備起跳"
		elif absf(seconds_to_beat) <= _fountain_hit_tolerance():
			jump_label = "拍點落下中　·　現在仍可起跳"
		else:
			jump_label = "中央水簾正在亮起　·　Space／點擊"
	_draw_scene_label(jump_label,Vector2(640,276),21)
	for i in 3:
		var cx := 565.0 + i*75.0
		var finished_attempt := i < fountain_grades.size()
		var grade_color := PAPER
		if finished_attempt:
			grade_color = MINT if fountain_grades[i] == "完美" else YELLOW if fountain_grades[i] in ["準確", "踩中"] else PINK
		draw_circle(Vector2(cx,576),16,grade_color if finished_attempt else PAPER)
		var marker := str(i+1)
		if finished_attempt:
			marker = "✓" if fountain_grades[i] != "錯過" else "×"
		draw_string(FONT,Vector2(cx-10,582),marker,HORIZONTAL_ALIGNMENT_CENTER,20,12,INK)

func _draw_fountain_avatar(jump_lift: float, jump_progress: float, airborne: bool) -> void:
	# Draw one complete authored pose. The ground shadow stays fixed while the
	# whole character follows the jump arc; no separate limb overlays are used.
	var ground := Vector2(640.0, 504.0)
	_draw_actor_contact_shadow(ground, Vector2(25.0, 6.0))
	var pose: Texture2D = _fountain_idle_texture
	if airborne and not _fountain_jump_textures.is_empty():
		var frame_index := 0
		if not reduced_motion:
			frame_index = clampi(floori(jump_progress * _fountain_jump_textures.size()), 0, _fountain_jump_textures.size() - 1)
		pose = _fountain_jump_textures[frame_index]
	if pose == null:
		_draw_tourist("visitor", Rect2(611.0, 386.0 - jump_lift, 58.0, 118.0), Color("#e77e83"), ground.y)
		return
	var size := Vector2(140.0, 180.0)
	var feet_y := ground.y - jump_lift
	var top := feet_y - (346.0 / 360.0) * size.y
	draw_texture_rect(pose, Rect2(Vector2(ground.x - size.x * 0.5, top), size), false)

func _draw_crowd() -> void:
	# Two promenade lanes, zebra markings, direction chevrons and a brass signal post.
	draw_rect(Rect2(92,318,1096,216),Color("#827362"),true)
	draw_rect(Rect2(105,329,1070,82),Color("#d6b78a"),true); draw_rect(Rect2(105,435,1070,82),Color("#c2a47d"),true)
	for i in 11:
		var x := 150.0 + i*96.0
		draw_rect(Rect2(x,414,45,20),Color("#f8e9c6",0.76),true)
		draw_colored_polygon(PackedVector2Array([Vector2(x+13,354),Vector2(x+45,369),Vector2(x+13,384),Vector2(x+20,369)]),Color("#af9170"))
		draw_colored_polygon(PackedVector2Array([Vector2(x+30,465),Vector2(x+2,480),Vector2(x+30,495),Vector2(x+24,480)]),Color("#af9170"))
	# Six recognizable visitors move along the same two crossing lanes as the timing cue.
	for i in 6:
		var x := 90.0 + fposmod(phase * 130 + i * 180, 1100.0)
		var y := 370.0 if (i + count) % 2 == 0 else 478.0
		var tourist_keys := ["tourist_coral","tourist_blue","tourist_gold","tourist_green"]
		_draw_tourist(tourist_keys[i%4],Rect2(x-24,y-69,48,78),CROWD_COLORS[i%4])
		if int(fposmod(phase*130+i*180,1100.0)) < 55:
			draw_arc(Vector2(x,y-6),29,PI,TAU,18,YELLOW,2)
	# Signal aspect and arrow show the selected direction with a friendly signal keeper.
	draw_rect(Rect2(586,238,108,92),Color("#76533f"),true); draw_rect(Rect2(594,246,92,76),Color("#bd9263"),false,3)
	draw_circle(Vector2(640,270),20,MINT if lane==0 else Color("#563f52")); draw_circle(Vector2(640,300),13,PINK if lane==1 else Color("#563f52"))
	_draw_scene_label("切換行人燈　Q / E 或點擊　　放行　"+str(count)+" / 6",Vector2(640,558),17)

func _draw_ribbon() -> void:
	# Dancer and stage ribbon trace a unique eight-count phrase across the proscenium.
	draw_line(Vector2(246,514),Vector2(1034,514),Color("#b79a76"),4)
	var dancer := Vector2(640,430)
	_draw_tourist("tourist_green",Rect2(611,379,58,112),Color("#6595a0"))
	var wave := PackedVector2Array()
	for i in 25:
		var t := float(i)/24.0
		wave.append(Vector2(580+t*120,382+sin(t*TAU*2+phase*2.0)*18))
	draw_polyline(wave,Color("#f4a3b5"),6)
	for i in 8:
		var x := 330.0 + i * 90.0; var active := i == beat
		var c := Color("#e78aa2") if active else (Color("#64b5a7") if i < beat else Color("#879089"))
		draw_circle(Vector2(x,420), 30, c); draw_arc(Vector2(x,420),35,0,TAU,32,Color("#f5d69d"),2)
	var labels := ["←","→","跳","→","←","跳","←","→"]
	for i in 8: draw_string(FONT, Vector2(310+i*90,429), labels[i], HORIZONTAL_ALIGNMENT_CENTER, 40, 24, PAPER)
	_draw_scene_label("跟著舞者依序轉向與跳步　　←　→　空白鍵",Vector2(640,290),20)
	draw_circle(Vector2(640,535), 26, YELLOW if beat_window else Color("#617b8f")); draw_circle(Vector2(640,535),8,Color("#fff4d3"))
	for i in mini(8,beat): draw_circle(Vector2(475+i*34,570),5,MINT)

func _draw_flower() -> void:
	var dirs := PIPE_DIRS; var bits := PIPE_BITS
	# Garden bed and copper source/drain are visibly joined by each rotatable pipe piece.
	draw_rect(Rect2(346,190,573,366),Color("#866b4e"),true); draw_rect(Rect2(354,198,557,350),Color("#a58460"),false,5)
	draw_rect(Rect2(295,225,76,37),Color("#a66d4a"),true); draw_rect(Rect2(302,231,60,16),Color("#d8a46a"),true)
	draw_arc(Vector2(300,243),30,PI,TAU,22,Color("#95603e"),8)
	draw_rect(Rect2(910,510,75,39),Color("#a66d4a"),true); draw_rect(Rect2(920,517,54,14),Color("#79d3da"),true)
	draw_string(FONT, Vector2(268,295), "泉", HORIZONTAL_ALIGNMENT_CENTER, 70, 18, PAPER)
	draw_string(FONT, Vector2(910,580), "花槽", HORIZONTAL_ALIGNMENT_CENTER, 75, 16, INK)
	for i in 16:
		var x := 370.0 + (i%4)*135.0; var y := 205.0 + int(i/4)*85.0
		draw_rect(Rect2(x,y,112,65), Color("#70916a"), true)
		draw_rect(Rect2(x+4,y+4,104,57), Color("#89a678"), false, 2)
		for n in 3: draw_circle(Vector2(x+18+n*35,y+54),4,Color("#5f794f"))
		if i == pipe_cursor: draw_rect(Rect2(x,y,112,65), YELLOW, false, 4)
		for d in 4:
			if flower_cells[i] & bits[d]:
				draw_line(Vector2(x+56,y+32), Vector2(x+56+dirs[d].x*32,y+32+dirs[d].y*25), Color("#9a653e"), 15)
				draw_line(Vector2(x+56,y+32), Vector2(x+56+dirs[d].x*32,y+32+dirs[d].y*25), Color("#d29b5e"), 10)
		draw_circle(Vector2(x+56,y+32),9,Color("#d49a5a")); draw_circle(Vector2(x+53,y+29),3,Color("#ffe0a0"))
		if i in [0,5,10,15]:
			var flower_pos := Vector2(x+22,y+47)
			draw_line(flower_pos,flower_pos+Vector2(0,-13),Color("#3e785a"),2)
			for petal in 5: draw_circle(flower_pos+Vector2.RIGHT.rotated(TAU*petal/5.0)*5,3,PINK if i%2==0 else YELLOW)
	# Flow only lights reciprocal segments along the route currently reached by the source.
	var flowing := {0:true,4:true,5:true,6:true,10:true,14:true,15:true}
	for cell in flowing:
		var x := 370.0 + (int(cell)%4)*135.0; var y := 205.0 + int(int(cell)/4)*85.0
		if cell == 0: draw_line(Vector2(362,243),Vector2(x+56,y+32),Color("#8ce4e0",0.9),4)
		for d in 4:
			if flower_cells[cell] & bits[d]: draw_line(Vector2(x+56,y+32),Vector2(x+56+dirs[d].x*32,y+32+dirs[d].y*25),Color("#9cf0eb",0.68),4)
	_draw_topiary(Vector2(1020,508),0.72)
	_draw_scene_label("轉動方管讓水從左上泉口流進右下花槽　　步數 " + str(move_count),Vector2(640,575),16)

func _draw_sign() -> void:
	# A pier carpenter balances a real two-sided painted sign on its brass pivot.
	draw_rect(Rect2(575,505,130,80),Color("#a5754d"),true); draw_rect(Rect2(584,514,112,59),Color("#c99863"),false,4)
	draw_line(Vector2(640,507),Vector2(640,348),Color("#875e42"),16)
	var angle := balance * 0.30
	var center := Vector2(640,335)
	var left := center + Vector2(-185,0).rotated(angle); var right := center + Vector2(185,0).rotated(angle)
	_draw_rotated_prop("sign",Vector2(640,290),Vector2(220,124),angle)
	# Chains suspend the actual sign boards from the tilting crossbar.
	draw_line(left, left+Vector2(0,56),GOLD,4); draw_line(right,right+Vector2(0,56),GOLD,4)
	draw_line(left+Vector2(0,56),right+Vector2(0,56),Color("#916444"),8)
	draw_rect(Rect2(left.x-59,left.y+44,118,54),Color("#e6bd7e"),true); draw_rect(Rect2(right.x-59,right.y+44,118,54),Color("#7db4a2"),true)
	draw_rect(Rect2(left.x-59,left.y+44,118,54),GOLD,false,3); draw_rect(Rect2(right.x-59,right.y+44,118,54),GOLD,false,3)
	draw_string(FONT,left+Vector2(-50,79),"珊瑚餅",HORIZONTAL_ALIGNMENT_CENTER,100,14,INK); draw_string(FONT,right+Vector2(-50,79),"海鹽糖",HORIZONTAL_ALIGNMENT_CENTER,100,14,INK)
	draw_colored_polygon(PackedVector2Array([center+Vector2(-26,0),center+Vector2(26,0),center+Vector2(0,38)]),Color("#d98971")); draw_circle(center,12,YELLOW)
	# Gauge mirrors balance units; green marks the valid scoring band and outer red marks failure.
	draw_line(Vector2(300,573),Vector2(980,573),Color("#b3a17e"),9)
	draw_line(Vector2(510,573),Vector2(770,573),MINT,10)
	draw_line(Vector2(300,561),Vector2(300,585),PINK,5); draw_line(Vector2(980,561),Vector2(980,585),PINK,5)
	var needle_x := 640.0 + balance * 300.0
	draw_colored_polygon(PackedVector2Array([Vector2(needle_x,550),Vector2(needle_x-10,566),Vector2(needle_x+10,566)]),Color("#d86f78"))
	var wind_direction := -1 if sin(phase*1.7)<0 else 1
	_draw_scene_label("← → 或點擊兩側壓平招牌　　海風　" + ("←" if wind_direction<0 else "→") + "　穩住 " + str(count) + " / 7 拍",Vector2(640,220),19)
	for i in 4:
		var wx := 520.0+i*78.0
		draw_line(Vector2(wx,278),Vector2(wx+wind_direction*22,278),Color("#b27b58",0.62),2)
		draw_colored_polygon(PackedVector2Array([Vector2(wx+wind_direction*22,273),Vector2(wx+wind_direction*30,278),Vector2(wx+wind_direction*22,283)]),GOLD)

func _draw_shadow() -> void:
	draw_rect(Rect2(755,190,370,390),Color("#293e5a"),true); draw_rect(Rect2(772,206,336,356),Color("#f0d9a5"),true)
	# A painted, horned original lantern imp casts the live silhouette; target offset respects assist.
	var target_x := 940.0 + (0.18 if assisted else 0.0) * 300.0
	var x := 940.0 + alignment * 300.0
	var silhouette := PackedVector2Array([Vector2(x-75,492),Vector2(x-56,370),Vector2(x-38,329),Vector2(x-53,301),Vector2(x-24,316),Vector2(x,282),Vector2(x+24,316),Vector2(x+53,301),Vector2(x+38,329),Vector2(x+56,370),Vector2(x+75,492)])
	var ghost := silhouette.duplicate()
	for i in ghost.size(): ghost[i].x += target_x-x
	_draw_prop("mascot",Rect2(target_x-57,315,114,116),Color("#df8a9a",0.28))
	if not _draw_prop("mascot",Rect2(x-57,315,114,116),Color("#26384d")):
		draw_colored_polygon(ghost,Color("#db7b87",0.18)); draw_polyline(ghost + PackedVector2Array([ghost[0]]),Color("#ea8e9c"),4)
		draw_colored_polygon(silhouette,Color("#26384d")); draw_circle(Vector2(x-17,359),4,Color("#ffdb8b")); draw_circle(Vector2(x+17,359),4,Color("#ffdb8b"))
	draw_circle(Vector2(target_x,374),6,Color("#edafb2",0.9)); draw_circle(Vector2(x,374),5,Color("#ffdb8b"))
	draw_line(Vector2(x,355),Vector2(x,448),Color("#7797a1",0.45),2)
	draw_string(FONT,Vector2(805,535),"引燈影",HORIZONTAL_ALIGNMENT_CENTER,270,16,Color("#5c6374"))
	# Ruler maps one alignment unit to 300 pixels. Its highlighted span equals the hit tolerance.
	draw_line(Vector2(190,592),Vector2(1090,592),Color("#826c50"),5)
	for i in 19:
		var tick_x := 190.0+i*50.0
		var in_band := absf((tick_x-940.0)/300.0-(0.18 if assisted else 0.0)) < (0.13 if assisted else 0.065)
		draw_line(Vector2(tick_x,584),Vector2(tick_x,604),MINT if in_band else YELLOW,3)
	draw_circle(Vector2(x,592),8,PINK)
	_draw_scene_label("拖曳影燈，讓小角角的影子貼合珊瑚紙影" + ("　輔助目標偏右" if assisted else ""),Vector2(640,220),19)
	draw_rect(Rect2(386,533,150,28),Color("#20364c"),true); draw_rect(Rect2(386,533,clampf(alignment_hold/3.0,0,1)*150,28),MINT,true)
	_draw_scene_label("穩住 %.1f / 3 秒" % alignment_hold,Vector2(390,554),13,HORIZONTAL_ALIGNMENT_LEFT)

func _draw_bench() -> void:
	# Four individually numbered brass-backed seats and four original visitors.
	var colors := [Color("#cf7588"),Color("#5d9aab"),Color("#d2a658"),Color("#60977b")]
	var tourist_keys := ["tourist_coral","tourist_blue","tourist_gold","tourist_green"]
	for i in 4:
		var x := 425.0 + i*135.0; var y := 340.0
		_draw_prop("bench",Rect2(x-68,353,136,92))
		_draw_tourist(tourist_keys[seats[i]],Rect2(x-29,263,58,118),colors[seats[i]])
		# Paired friendship badge remains attached to person identity while seats swap.
		var group_color := Color("#ef8e99") if seats[i] < 2 else Color("#7fcdb3")
		draw_circle(Vector2(x+19,326),10,group_color); draw_circle(Vector2(x+16,323),2,PAPER)
		draw_circle(Vector2(x,462),18,Color("#e7cc98")); draw_string(FONT,Vector2(x-12,469),str(i+1),HORIZONTAL_ALIGNMENT_CENTER,24,14,INK)
		if select_index == i: draw_arc(Vector2(x,339),58,0,TAU,36,YELLOW,5)
	var pairs := "整理順序，讓四位朋友坐回編號座位　　好友徽章：珊瑚 1＋2　海草 3＋4"
	_draw_scene_label(pairs,Vector2(640,245),18)
	_draw_scene_label("點選／按編號交換　　已交換 " + str(move_count) + " 次",Vector2(640,520),18)
	for i in 4:
		draw_circle(Vector2(480+i*108,565),14,MINT if seats[i]==i else Color("#c8b68d"))
		draw_string(FONT,Vector2(470+i*108,570),"✓" if seats[i]==i else str(i+1),HORIZONTAL_ALIGNMENT_CENTER,20,12,INK)
