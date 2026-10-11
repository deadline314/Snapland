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
const BalloonHarborScript = preload("res://game/minigames/balloon_harbor_view.gd")
const PipePlanScript = preload("res://game/minigames/pipe_plan_view.gd")
const PipeRoundScript = preload("res://game/minigames/pipe_round_model.gd")
const CrowdTrafficScript = preload("res://game/minigames/crowd_traffic_model.gd")
const CrowdCrossingScript = preload("res://game/minigames/crowd_crossing_view.gd")
const BUBBLE_MASCOT_RADIUS := 52.0
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
var pipe_connected := false
var pipe_finish_at := -1.0
var pipe_model: RefCounted = PipeRoundScript.new()
var crowd_model: RefCounted = CrowdTrafficScript.new()
var _crowd_event_cursor := 0
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
var bubble_cycle := -1
var bubble_attempts := 0
var velocity := Vector2.ZERO
var phase := 0.0
var beat := 0
var beat_window := false
var fountain_attempts := 0
var fountain_jump_started := -1.0
var fountain_finish_pending := false
var fountain_finish_at := -1.0
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
var sequence: Array[int] = []
var sequence_index := 0
var sequence_showing := false
var sequence_clock := 0.0
var sequence_show_index := 0
var bubble_ready := false
var bubble_aim := Vector2(790, 380)
var bubble_perfect := true
var alignment_hold := 0.0
var shadow_started := false
var shadow_broken := false
var seats: Array[int] = []
var flower_cells: Array[int] = []
var hat_x: Array[float] = []
var hat_y: Array[float] = []
var hats_consumed: Array[bool] = []
var ring_x: Array[float] = []
var ring_y: Array[float] = []

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
		presentation_mode = mode
		match mode:
			"balloon_delivery":
				# Headless rules tests do not allocate a renderer or GPU world.
				if DisplayServer.get_name() != "headless": presentation = BalloonHarborScript.new()
			"flower_pipes": presentation = PipePlanScript.new()
			"crowd_traffic": presentation = CrowdCrossingScript.new()
		if presentation != null:
			presentation.name = "GamePresentation"
			presentation.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(presentation)
			move_child(presentation, 0)
			if mode == "balloon_delivery": presentation.initialize()
			_layout_presentation()
	if not is_instance_valid(presentation): return
	match mode:
		"balloon_delivery":
			presentation.present(p, velocity, balloon_wind_current, balloon_wind_forecast, balloon_delivery_index, balloon_dock_hold, balloon_braking, phase, reduced_motion, time_phase, balloon_delivery_index, _balloon_hazard_at(phase), 65.0)
		"flower_pipes":
			presentation.configure(reduced_motion, time_phase)
			presentation.set_animation_active(not paused)
			presentation.present_order(pipe_model.snapshot(), phase, reduced_motion, time_phase)
			presentation.cursor = pipe_cursor
		"crowd_traffic": presentation.present_state(crowd_model.snapshot(), phase, reduced_motion, time_phase)

func _layout_presentation() -> void:
	if not is_instance_valid(presentation): return
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	presentation.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	presentation.size = DESIGN_SIZE
	presentation.scale = Vector2.ONE * factor
	presentation.position = (size - DESIGN_SIZE * factor) * 0.5

func set_paused(value: bool) -> void:
	if ended and value:
		return
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
	if mode == "fountain_timing":
		if ended:
			time_text = "3 / 3 拍"
		else:
			var next_beat := _fountain_beat_time(mini(fountain_attempts, 2))
			time_text = "第%d拍 %.1fs" % [mini(fountain_attempts + 1, 3), maxf(0.0, next_beat - phase)]
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
		"feedback_width": 240.0 if mode == "flower_pipes" else 540.0,
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
		"kite_rings": return "風環 %d / 5" % count
		"fountain_timing": return "機會 %d / 3　成功 %d" % [fountain_attempts, count]
		"crowd_traffic": return "隊伍 %d / 6" % count
		"hat_catching": return "接住 %d / 6" % count
		"ribbon_rhythm": return "命中 %d / 8" % devil_progress
		"flower_pipes": return "工單 %d / 3　轉動 %d 次" % [mini(pipe_model.order_index + 1, 3), move_count]
		"sign_balance": return "穩住 %d / 7 拍" % count
		"shadow_alignment": return "穩定 %0.1f / 3.0 秒" % alignment_hold
		"bubble_photo": return "有效合照 %d / 3" % devil_progress
		"bench_swap": return "交換 %d 次" % move_count
		"melody_memory": return "樂句 %d / 3　音符 %d / %d" % [count, sequence_index, sequence.size()]
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
		"sign_balance": return "平衡拍點分"
		"shadow_alignment": return "影子對準分"
		"bubble_photo": return "合照分"
		"bench_swap": return "換位分"
		"melody_memory": return "演奏分"
	return "得分"

func _score_rule_text() -> String:
	match mode:
		"balloon_delivery": return "每送達一封郵袋 +150。"
		"kite_rings": return "每穿過一個風環 +100。"
		"fountain_timing": return "三跳總分 0–900；每跳完美 ±70ms +300、準確 ±160ms +200、踩中 ±220ms +100。三跳全中得普通拍貼，三跳完美得小惡魔拍貼。"
		"crowd_traffic": return "每隊安全通過 +50；等候效率 +20／10；救援隊及時通行另 +50。"
		"hat_catching": return "每接住一頂帽子 +100。"
		"ribbon_rhythm": return "每踩中一拍 +75。"
		"flower_pipes": return "每張完成工單 +1000，每次旋轉 −20，最低 0 分；三張全部供水才完成。"
		"sign_balance": return "每個拍點穩在安全區 +50；精準度決定加碼條件。"
		"shadow_alignment": return "完成三秒維持時 +100；保持時間決定一般成功。"
		"bubble_photo": return "每張有效合照 +100。"
		"bench_swap": return "目前分數 = max(0, 500 − 50 × 交換次數)；座位排列決定是否完成。"
		"melody_memory": return "每個正確音符 +25；完成每段樂句再 +100。"
	return "得分由已記錄的遊戲事件累加。"

func set_time_of_day(phase_id: Variant) -> void:
	time_phase = TimeOfDayScript.normalize(phase_id)
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
	round_seconds = 55.0 if mode == "balloon_delivery" else ROUND_SECONDS
	beat = 0
	beat_window = false
	fountain_attempts = 0
	fountain_jump_started = -1.0
	fountain_finish_pending = false
	fountain_finish_at = -1.0
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
	bubble_cycle = -1
	bubble_attempts = 0
	seats.clear()
	flower_cells.clear()
	hat_x.clear()
	hat_y.clear()
	hats_consumed.clear()
	ring_x.clear()
	ring_y.clear()
	sequence.clear()
	sequence_index = 0
	sequence_showing = false
	sequence_clock = 0.0
	sequence_show_index = 0
	bubble_ready = false
	bubble_aim = Vector2(790, 380)
	bubble_perfect = true
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
			p = Vector2(180, 360)
			for i in 5:
				ring_x.append(410.0 + i * 155.0)
				ring_y.append([270.0, 450.0, 320.0, 470.0, 310.0][i])
		"fountain_timing": pass
		"crowd_traffic":
			crowd_model.reset(assisted)
			_crowd_event_cursor = 0
		"hat_catching":
			for i in 6:
				hat_x.append(260.0 + i * 150.0)
				hat_y.append(-float(i) * 180.0 - 30.0)
				hats_consumed.append(false)
		"ribbon_rhythm": pass
		"flower_pipes":
			pipe_model.reset()
			flower_cells = pipe_model.cells
		"sign_balance": pass
		"shadow_alignment": alignment = -0.72
		"bubble_photo": pass
		"bench_swap": seats = [2, 0, 3, 1]
		"melody_memory": _next_melody()
	if assisted:
		prompt = "輔助已開：目標會標亮，判定範圍加寬"
	if mode == "fountain_timing":
		_prepare_fountain_avatar_poses()
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
	elapsed += delta
	game_time += delta
	if mode != "balloon_delivery": phase += delta
	feedback_age += delta
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		particle.life = float(particle.life) - delta
		particle.pos = Vector2(particle.pos) + Vector2(particle.velocity) * delta
		particles[i] = particle
		if particle.life <= 0.0: particles.remove_at(i)
	if elapsed >= round_seconds:
		_finish(false)
		return
	if mode == "balloon_delivery":
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

func _tick_game(delta: float) -> void:
	match mode:
		"balloon_delivery": _tick_balloon(delta)
		"kite_rings":
			p.y += _axis_y() * 235.0 * delta
			p.y = clampf(p.y + sin(phase * 2.0) * (22.0 if not assisted else 11.0) * delta, 220, 570)
			p.x += 118.0 * delta
			if count < ring_x.size() and p.x >= ring_x[count]:
				if absf(p.y - ring_y[count]) <= (55 if assisted else 34):
					count += 1; _award_points("ring", "成功穿過風環", 100); devil_progress += 1; _feedback("穿環成功！", MINT)
				else:
					count += 1; mistakes += 1; _feedback("差一點，風箏擦到環了", PINK)
			if p.x > 1240: _finish(count == ring_x.size() and mistakes <= 1, devil_progress == 5 and mistakes == 0)
		"fountain_timing":
			_tick_fountain()
		"crowd_traffic": _tick_crowd(delta)
		"hat_catching": _tick_hats(delta)
		"ribbon_rhythm":
			var beat_phase := fposmod(phase, 0.82)
			var cycle := int(floor(phase / 0.82))
			var window := 0.34 if assisted else 0.12
			while beat < 8 and (beat < cycle or (beat == cycle and beat_phase >= window)):
				beat += 1; streak = 0; mistakes += 1
			if beat >= 8: _finish(devil_progress >= (4 if assisted else 6), mistakes == 0 and devil_progress == 8)
			beat_window = not ended and beat == cycle and beat_phase < window
		"flower_pipes": _tick_pipe(delta)
		"sign_balance":
			var wind := sin(phase * 1.7) * (0.50 if not assisted else 0.32)
			balance += wind * delta - _axis_x() * 0.78 * delta
			balance = clampf(balance, -1.4, 1.4)
			if absf(balance) > 1.05:
				mistakes += 1; balance = signf(balance) * 0.72; _feedback("招牌晃過安全線！", PINK)
				if mistakes >= 3: _finish(false)
			if phase > 1.5 and fposmod(phase, 1.0) < delta and absf(balance) < (0.38 if assisted else 0.25):
				count += 1; _award_points("balance", "穩住安全區拍點", 50)
				if absf(balance) < 0.12: devil_progress += 1
			if count >= 7: _finish(true, devil_progress >= 7 and mistakes == 0)
		"shadow_alignment":
			var target_alignment := 0.18 if assisted else 0.0
			if absf(alignment - target_alignment) < (0.13 if assisted else 0.065):
				alignment_hold += delta
				shadow_started = true
			else:
				if shadow_started: shadow_broken = true
				alignment_hold = 0.0
			if alignment_hold >= 3.0: _award_points("shadow", "影子維持三秒", 100); _finish(true, mistakes == 0 and not shadow_broken)
		"bubble_photo":
			target.y = 380.0 + sin(phase * 1.2) * 95.0
			var photo_beat := fposmod(phase, 2.0)
			beat_window = bubble_attempts < 3 and bubble_cycle != int(floor(phase / 2.0)) and photo_beat > (1.1 if assisted else 1.35) and photo_beat < 1.99
		"bench_swap": pass
		"melody_memory": _tick_melody(delta)

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
	for i in hat_y.size():
		hat_y[i] += (112.0 + float(i % 3) * 20.0) * delta
		if i % 2 == 0:
			hat_x[i] += sin(phase * 1.8 + i) * 24.0 * delta
		if not hats_consumed[i] and hat_y[i] > 560:
			if absf(hat_x[i] - p.x) < (115.0 if assisted else 65.0):
				_award_points("hat", "接住落帽", 100); count += 1; devil_progress += 1; _feedback("接住啦！", YELLOW)
			else:
				mistakes += 1; _feedback("帽子飛走了", PINK)
			hats_consumed[i] = true
			hat_y[i] = 700
	p.x += _axis_x() * 280.0 * delta
	p.x = clampf(p.x, 180, 1100)
	if count + mistakes >= 6: _finish(count >= 4, count == 6 and mistakes == 0)

func _tick_melody(delta: float) -> void:
	if sequence_showing:
		sequence_clock -= delta
		if sequence_clock <= 0:
			sequence_show_index += 1
			if sequence_show_index >= sequence.size():
				sequence_showing = false; prompt = "換你演奏！按 1–4 或點花朵"
			else:
				sequence_clock = 0.8 if assisted else 0.55
				note_played.emit(sequence[sequence_show_index])

func _axis_x() -> float:
	return clampf(Input.get_axis("ui_left", "ui_right") + Input.get_axis("move_left", "move_right"), -1.0, 1.0)

func _axis_y() -> float:
	return clampf(Input.get_axis("ui_up", "ui_down") + Input.get_axis("move_up", "move_down"), -1.0, 1.0)

func _next_melody() -> void:
	sequence.clear()
	for i in mini(3 + count, 7): sequence.append(rng.randi_range(0, 3))
	sequence_index = 0; sequence_show_index = 0; sequence_showing = true; sequence_clock = 0.8 if assisted else 0.55
	if not sequence.is_empty(): note_played.emit(sequence[0])

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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R: set_paused(true); return
		if event.keycode == KEY_SPACE: _press_action()
		if event.keycode >= KEY_1 and event.keycode <= KEY_4: _melody_input(event.keycode - KEY_1)
		if mode == "bench_swap" and event.keycode >= KEY_1 and event.keycode <= KEY_4: _bench_key(int(event.keycode - KEY_1))
		if mode == "flower_pipes":
			if event.keycode == KEY_LEFT: pipe_cursor = maxi(0, pipe_cursor - 1)
			if event.keycode == KEY_RIGHT: pipe_cursor = mini(15, pipe_cursor + 1)
			if event.keycode == KEY_UP: pipe_cursor = maxi(0, pipe_cursor - 4)
			if event.keycode == KEY_DOWN: pipe_cursor = mini(15, pipe_cursor + 4)
			if event.keycode == KEY_SPACE: _rotate_pipe_index(pipe_cursor)
		if mode == "shadow_alignment" and (event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT): alignment = clampf(alignment + (0.04 if event.keycode == KEY_RIGHT else -0.04), -0.5, 0.5)
		if mode == "bubble_photo" and event.keycode == KEY_SPACE:
			if not bubble_ready: bubble_ready = true; bubble_aim = Vector2(790, target.y); prompt = "泡泡飛出去啦！等它包住吉祥物，再按空白鍵拍照"
			else: _bubble_click(Vector2(790, target.y))
		if mode == "ribbon_rhythm" and (event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT): _ribbon_input(event.keycode)
		if mode == "crowd_traffic" and event.keycode in [KEY_Q, KEY_E]: _request_crowd_lane(0 if event.keycode == KEY_Q else 1)
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		var m := _to_design(mouse_event.position)
		if mode == "fountain_timing" and mouse_event.button_index == MOUSE_BUTTON_LEFT: _press_action()
		elif mode == "ribbon_rhythm": _ribbon_input(KEY_LEFT if m.x < DESIGN_SIZE.x * 0.43 else (KEY_RIGHT if m.x > DESIGN_SIZE.x * 0.57 else KEY_SPACE))
		elif mode == "crowd_traffic":
			var chosen_lane: int = presentation.pointerSignalAt(m) if is_instance_valid(presentation) else -1
			if chosen_lane >= 0:
				_request_crowd_lane(chosen_lane)
		elif mode == "shadow_alignment": alignment = inverse_lerp(190.0, 1090.0, m.x) - 0.5; mistakes += 1 if absf(alignment) > 0.3 else 0
		elif mode == "bubble_photo": _bubble_click(m)
		elif mode == "flower_pipes": _rotate_pipe(m)
		elif mode == "bench_swap": _bench_click(m)
		elif mode == "melody_memory":
			var petal := int(clampi(int((m.x - 380.0) / 130.0), 0, 3)); _melody_input(petal)
		elif mode == "sign_balance": balance += -0.16 if m.x < DESIGN_SIZE.x / 2.0 else 0.16
	if event is InputEventMouseMotion:
		var mouse := event as InputEventMouseMotion
		var pointer := _to_design(mouse.position)
		match mode:
			"balloon_delivery":
				if is_instance_valid(presentation): pointer = presentation.screen_to_design(pointer)
				steering_target = Vector2(clampf(pointer.x, 130, 1150), clampf(pointer.y, 210, 585))
				mouse_steering = true
			"kite_rings": p.y = clampf(pointer.y, 220, 570)
			"hat_catching": p.x = clampf(pointer.x, 180, 1100)
			"shadow_alignment": alignment = clampf(inverse_lerp(190.0, 1090.0, pointer.x) - 0.5, -0.5, 0.5)

func _press_action() -> void:
	match mode:
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
		"ribbon_rhythm":
			_ribbon_input(KEY_SPACE)

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

func _ribbon_input(action: int) -> void:
	if ended or beat != int(floor(phase / 0.82)): return
	var rhythm: Array[int] = [KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_RIGHT, KEY_LEFT, KEY_SPACE, KEY_LEFT, KEY_RIGHT]
	var expected: int = rhythm[beat % 8]
	if action == expected and beat_window:
		beat += 1; streak += 1; _award_points("rhythm", "踩中節拍", 75); devil_progress += 1
		note_played.emit(0 if action == KEY_LEFT else (1 if action == KEY_RIGHT else 2))
		_feedback("踩中節拍！", MINT)
	else:
		beat += 1; streak = 0; mistakes += 1; _feedback("慢半拍了", PINK)
	if beat >= 8: _finish(devil_progress >= (4 if assisted else 6), mistakes == 0 and devil_progress == 8)

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

func _bubble_click(m: Vector2) -> void:
	if m.y < 225 or m.y > 570: return
	var cycle := int(floor(phase / 2.0))
	if bubble_cycle == cycle: return
	if not bubble_ready:
		bubble_ready = true; bubble_aim = m; prompt = "泡泡飛出去啦！等它包住吉祥物，再點一下拍照"
		return
	bubble_ready = false
	bubble_cycle = cycle
	bubble_attempts += 1
	var aim_error := bubble_aim.distance_to(Vector2(790, target.y))
	var photo_tolerance := _bubble_photo_tolerance()
	if beat_window and aim_error < _bubble_aim_limit() and absf(m.x - 790.0) < photo_tolerance.x and absf(m.y - target.y) < photo_tolerance.y:
		beat += 1; _award_points("photo", "有效合照", 100); devil_progress += 1
		if aim_error >= 60.0 or m.distance_to(Vector2(790, target.y)) >= 40.0 or fposmod(phase, 2.0) < 1.55 or fposmod(phase, 2.0) > 1.85: bubble_perfect = false
		_feedback("咔嚓！合照成功", MINT)
	else:
		mistakes += 1; _feedback("泡泡沒包住吉祥物，等下一顆", PINK)
	if bubble_attempts >= 3: _finish(devil_progress >= 2, devil_progress == 3 and mistakes == 0 and bubble_perfect)

func _bubble_aim_limit() -> float:
	return 180.0 if assisted else 130.0

func _bubble_photo_tolerance() -> Vector2:
	return Vector2(160,140) if assisted else Vector2(120,100)

func _bubble_display_radius() -> float:
	# The rainbow rim contains every mascot center accepted by the aim test, plus its full sprite radius.
	return _bubble_aim_limit() + BUBBLE_MASCOT_RADIUS

func _bench_click(m: Vector2) -> void:
	if m.y < 300 or m.y > 510 or m.x < 370 or m.x > 910: return
	var index := int((m.x - 370.0) / 135.0)
	if select_index < 0: select_index = index; prompt = "再點一個座位交換"; return
	var tmp := seats[index]; seats[index] = seats[select_index]; seats[select_index] = tmp
	select_index = -1; move_count += 1; _set_formula_score("bench_swaps", "換位步數計分調整", maxi(0, 500 - move_count * 50))
	var solved := seats == [0, 1, 2, 3]
	if solved: _finish(true, move_count <= 3)
	else: _feedback("朋友們再換一下位置", BLUE)

func _bench_key(index: int) -> void:
	if select_index < 0:
		select_index = index; prompt = "再按一個座位編號交換"
		return
	var swap := select_index
	select_index = -1
	var tmp := seats[index]; seats[index] = seats[swap]; seats[swap] = tmp
	move_count += 1; _set_formula_score("bench_swaps", "換位步數計分調整", maxi(0, 500 - move_count * 50))
	if seats == [0,1,2,3]: _finish(true, move_count <= 3)
	else: _feedback("朋友們再換一下位置", BLUE)

func _melody_input(note: int) -> void:
	if mode != "melody_memory" or sequence_showing or ended: return
	if sequence_index >= sequence.size(): return
	if note == sequence[sequence_index]:
		sequence_index += 1; _award_points("melody_notes", "演奏正確音符", 25); note_played.emit(note); _feedback("音符對了！", MINT)
		if sequence_index >= sequence.size():
			count += 1; devil_progress += sequence.size(); _award_points("melody_phrase", "完成迎賓樂句", 100)
			if count >= 3: _finish(true, devil_progress >= 12 and mistakes == 0)
			else: _next_melody()
	else:
		mistakes += 1; _feedback("音符跑掉了，再聽一次", PINK); sequence_index = 0; sequence_show_index = 0; sequence_showing = true; sequence_clock = float(sequence.size()) * (0.8 if assisted else 0.55)

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

func _feedback_anchor() -> Vector2:
	match mode:
		"balloon_delivery": return Vector2(320, 208)
		"kite_rings": return p
		"fountain_timing": return Vector2(960, 220)
		"crowd_traffic": return Vector2(320, 220)
		"hat_catching": return Vector2(p.x, 560)
		"ribbon_rhythm": return Vector2(640, 420)
		"flower_pipes": return Vector2(150, 460)
		"sign_balance": return Vector2(640, 340)
		"shadow_alignment": return Vector2(940 + alignment * 300, 390)
		"bubble_photo": return Vector2(790, target.y)
		"bench_swap": return Vector2(425 + maxi(select_index, 0) * 135, 340)
		"melody_memory": return Vector2(450 + maxi(sequence_index, 0) * 130, 420)
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
	if mode in ["balloon_delivery", "flower_pipes", "crowd_traffic"]:
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
		"kite_rings": scene = "harbor"; tint = Color("#7db8c4")
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
		"kite_rings":
			_draw_cloud(Vector2(180,220),1.0); _draw_cloud(Vector2(1085,215),0.9)
			draw_line(Vector2(55,324),Vector2(210,292),Color("#557f69",0.7),5)
			draw_line(Vector2(1070,330),Vector2(1230,292),Color("#557f69",0.7),5)
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
		"kite_rings": _draw_kite()
		"fountain_timing": _draw_fountain()
		"crowd_traffic": _draw_crowd()
		"hat_catching": _draw_hats()
		"ribbon_rhythm": _draw_ribbon()
		"flower_pipes": _draw_flower()
		"sign_balance": _draw_sign()
		"shadow_alignment": _draw_shadow()
		"bubble_photo": _draw_bubble()
		"bench_swap": _draw_bench()
		"melody_memory": _draw_melody()

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

func _draw_kite() -> void:
	for i in ring_x.size():
		var c := MINT if i < count else Color("#493f4f")
		# Physical and visible opening share the same radius used by the pass check.
		draw_arc(Vector2(ring_x[i], ring_y[i]), 34, 0, TAU, 40, c, 8)
		draw_arc(Vector2(ring_x[i], ring_y[i]), 40, 0, TAU, 40, Color("#f5d59b",0.8), 2)
		draw_circle(Vector2(ring_x[i]-34,ring_y[i]),5,GOLD); draw_circle(Vector2(ring_x[i]+34,ring_y[i]),5,GOLD)
	# Crosswind tails remain behind the original quilted kite and alternate two pennant colors.
	for i in 5:
		var trail := p + Vector2(-13-i*9, 16+i*11)
		draw_colored_polygon(PackedVector2Array([trail,trail+Vector2(-17,8),trail+Vector2(-7,18)]),PINK if i%2==0 else Color("#59b9ae"))
	if not _draw_prop("kite",Rect2(p.x-37,p.y-43,74,108)):
		draw_line(p+Vector2(0,20),p+Vector2(-4,63),PAPER,2)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-30),p+Vector2(31,0),p+Vector2(0,30),p+Vector2(-31,0)]),Color("#e97792"))
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-23),p+Vector2(22,0),p+Vector2(0,23)]),Color("#ffd27e"))
		draw_line(p+Vector2(0,-27),p+Vector2(0,27),Color("#fff0d2"),2); draw_line(p+Vector2(-27,0),p+Vector2(27,0),Color("#fff0d2"),2)
	_draw_scene_label("穿過五枚潮汐風環　　拖曳高度或按 ↑ ↓；已穿過 " + str(count) + " / 5",Vector2(640,545),18)

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

func _draw_hats() -> void:
	# Catching deck uses a front-facing performer with upturned hands and a stitched apron.
	draw_rect(Rect2(82,522,1116,54),Color("#986e54"),true)
	draw_line(Vector2(p.x-9,546),Vector2(p.x-25,518),Color("#efc09b"),6); draw_line(Vector2(p.x+9,546),Vector2(p.x+25,518),Color("#efc09b"),6)
	_draw_tourist("tourist_coral",Rect2(p.x-31,484,62,96),Color("#e07d79"))
	for i in hat_y.size():
		if hat_y[i] < 620:
			var hc := Vector2(hat_x[i],hat_y[i])
			# Catch bands match the live horizontal tolerance at the actual crossing line.
			var catch_tolerance := 115.0 if assisted else 65.0
			if hc.y > 530 and hc.y < 590:
				draw_rect(Rect2(p.x-catch_tolerance,545,catch_tolerance*2,38),Color(MINT,0.13),true)
			draw_arc(hc+Vector2(0,8),24,PI,TAU,24,YELLOW,9); draw_line(hc+Vector2(-24,8),hc+Vector2(24,8),YELLOW,5)
			draw_colored_polygon(PackedVector2Array([hc+Vector2(-17,8),hc+Vector2(-12,-13),hc+Vector2(0,-22),hc+Vector2(12,-13),hc+Vector2(17,8)]),Color("#dc8e58"))
			draw_arc(hc+Vector2(0,8),13,PI,TAU,16,Color("#f5d6a7"),2)
			draw_circle(hc+Vector2(0,-5),3,PINK if i%2==0 else BLUE)
	_draw_scene_label("← → 或拖曳接住落下的帽子　　陣風：" + ("吹左" if sin(phase*1.8) < 0 else "吹右"),Vector2(640,195),19)

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

func _draw_bubble() -> void:
	# Photo stage is a moonlit glasshouse with a real framing window around the moving mascot.
	draw_rect(Rect2(350,218,590,327),Color("#304b61",0.8),true)
	for x in [375,525,675,825,915]: draw_line(Vector2(x,222),Vector2(x,542),Color("#d5c8a0",0.48),3)
	var glasshouse_arch := PackedVector2Array()
	for i in 49:
		var angle := PI * float(i) / 48.0
		glasshouse_arch.append(Vector2(645.0 + 295.0 * cos(angle), 511.0 - 293.0 * sin(angle)))
	draw_polyline(glasshouse_arch,Color("#d8be8c",0.7),5)
	var frame_x := 790.0
	var frame_tolerance := _bubble_photo_tolerance()
	draw_rect(Rect2(frame_x-frame_tolerance.x,target.y-frame_tolerance.y,frame_tolerance.x*2,frame_tolerance.y*2),Color("#f2dda6",0.08),true)
	draw_rect(Rect2(frame_x-frame_tolerance.x,target.y-frame_tolerance.y,frame_tolerance.x*2,frame_tolerance.y*2),Color(MINT if beat_window else Color("#b2c6ca"),0.78),false,3)
	for corner in [Vector2(-frame_tolerance.x,-frame_tolerance.y),Vector2(frame_tolerance.x,-frame_tolerance.y),Vector2(-frame_tolerance.x,frame_tolerance.y),Vector2(frame_tolerance.x,frame_tolerance.y)]:
		var c: Vector2 = Vector2(frame_x,target.y)+corner
		draw_line(c,c+Vector2(-signf(corner.x)*17,0),GOLD,5); draw_line(c,c+Vector2(0,-signf(corner.y)*17),GOLD,5)
	_draw_devil_mascot(Vector2(frame_x,target.y),32)
	# Soap mix cauldron, wand and animated aim bubble.
	draw_rect(Rect2(257,472,101,52),Color("#8b614d"),true); draw_rect(Rect2(268,448,79,29),Color("#d99c65"),true)
	draw_circle(Vector2(307,446),33,Color("#96dcd6",0.8)); draw_circle(Vector2(299,438),8,Color("#e7ffff",0.9))
	draw_line(Vector2(348,466),Vector2(386,426),GOLD,5); draw_arc(Vector2(393,419),10,0,TAU,20,PAPER,3)
	if bubble_ready:
		var radius := _bubble_display_radius() if beat_window else 44.0
		if beat_window:
			# Low-contrast cloudy fill and colored rim show the actual aim tolerance without hiding Koro.
			draw_circle(bubble_aim,radius,Color("#dcf4ef",0.045))
			draw_arc(bubble_aim,radius,0,TAU,80,Color("#e7f4e5",0.52),3)
			if reduced_motion:
				draw_arc(bubble_aim,radius-5,0,TAU,80,Color("#afddd7",0.50),2)
			else:
				var rim_colors := [Color("#f5b5c5",0.62),Color("#f3d18e",0.58),Color("#9cddd0",0.62),Color("#a6cfe7",0.58)]
				for arc in 4: draw_arc(bubble_aim,radius-5,arc*TAU/4.0+0.10,(arc+1)*TAU/4.0-0.10,20,rim_colors[arc],3)
				var cloud := bubble_aim+Vector2(-radius*0.33,-radius*0.56)
				draw_arc(cloud,12,PI*0.95,PI*1.95,18,Color("#ffffff",0.60),3)
		else:
			draw_circle(bubble_aim,radius,Color("#dcf4ef",0.12))
			draw_arc(bubble_aim,radius,0,TAU,42,Color("#d5f3ed",0.78),3)
		draw_arc(bubble_aim+Vector2(-8,-8),mini(28.0,radius*0.55),3.6,4.8,12,PAPER,2)
		draw_line(Vector2(392,430),bubble_aim,Color("#dff8ee",0.42),2)
	for i in 3: draw_circle(Vector2(730+i*49,536),12,MINT if i<beat else Color("#91a5aa")); draw_circle(Vector2(730+i*49,536),4,PAPER)
	_draw_scene_label("吹一顆泡泡；等小角角進入相框、彩虹亮起時再按快門",Vector2(640,190),18)
	if not _draw_prop("camera",Rect2(995,385,112,78)):
		draw_rect(Rect2(1008,393,88,82),Color("#354452"),true); draw_rect(Rect2(1017,402,70,63),Color("#9dcbcb"),true); draw_circle(Vector2(1052,433),17,Color("#334b62")); draw_circle(Vector2(1052,433),10,Color("#d8e9d4"))
	draw_string(FONT,Vector2(1007,493),"拍貼相機",HORIZONTAL_ALIGNMENT_CENTER,90,13,INK)

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

func _draw_melody() -> void:
	var colors := [Color("#d77c8f"),Color("#62a3b2"),Color("#d4a34f"),Color("#60977d")]
	for i in 4:
		var x := 450.0 + i*130.0; var center := Vector2(x,420)
		var lit := sequence_showing and sequence_show_index < sequence.size() and i == sequence[sequence_show_index] and int(sequence_clock*3.2)%2 == 0
		# Original brass flower gramophone, with the note lamp layered on its bell.
		if not _draw_prop("flower_horn",Rect2(x-67,387,134,164)):
			draw_line(center+Vector2(0,6),center+Vector2(0,50),Color("#64816a"),7)
			for petal in 8:
				var pc := center+Vector2.RIGHT.rotated(TAU*petal/8.0)*32
				_draw_ellipse(pc,Vector2(9,15),Color(colors[i],0.72))
			draw_circle(center,25,colors[i])
		draw_circle(center,12,CREAM if lit else Color("#e1c78f")); draw_circle(center+Vector2(0,-3),5,Color("#566a70"))
		draw_arc(center,43,0,TAU,32,YELLOW if lit else Color("#e1d3ad"),4 if lit else 2)
		draw_circle(center+Vector2(0,70),15,Color("#ebd39f")); draw_string(FONT,Vector2(x-10,75+405),str(i+1),HORIZONTAL_ALIGNMENT_CENTER,20,13,INK)
		if not sequence_showing and i < sequence_index: draw_circle(center+Vector2(0,94),5,MINT)
	# Bubble-shaped notes trace the tune during playback and fly to the player on input.
	if sequence_showing and sequence_show_index < sequence.size():
		var note := sequence[sequence_show_index]
		var note_center := Vector2(450+note*130,326)
		draw_circle(note_center,13,Color("#fff4d4",0.82)); draw_circle(note_center+Vector2(-4,-4),4,PAPER)
		draw_line(note_center+Vector2(0,13),note_center+Vector2(0,30),colors[note],3)
	_draw_scene_label("花喇叭先吹奏短句，聽完後用同一順序回奏",Vector2(640,270),19)
	_draw_scene_label("曲段 " + str(count+1) + " / 3　　" + ("留心聆聽…" if sequence_showing else "演奏中…"),Vector2(640,570),18)
