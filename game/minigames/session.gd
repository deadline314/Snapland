extends Control
## Self-contained welcome-park minigame session. Each game keeps its own state and
## input rule; this node only supplies the shared HUD, retry, exit and result contract.

signal finished(result: Dictionary)
signal cancelled
signal note_played(note: int)
signal feedback(kind: String)

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
static var _catalog_cache: Array = []
static var _catalog_loaded := false

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
var game_time := 0.0
var rng := RandomNumberGenerator.new()
var p := Vector2(270, 390)
var target := Vector2(1010, 360)
var mouse_steering := false
var steering_target := Vector2.ZERO
var bubble_cycle := -1
var bubble_attempts := 0
var velocity := Vector2.ZERO
var phase := 0.0
var beat := 0
var beat_window := false
var fountain_cycle := -1
var fountain_attempts := 0
var flash := 0.0
var feedback_color := MINT
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
	_rng_reset()
	reset_round()
	queue_redraw()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL
	grab_focus()

func _rng_reset() -> void:
	rng.seed = hash(game_id) + int(Time.get_ticks_msec())

func reset_round() -> void:
	elapsed = 0.0
	score = 0
	mistakes = 0
	devil_progress = 0
	ended = false
	won = false
	devil_won = false
	game_time = 0.0
	phase = 0.0
	beat = 0
	beat_window = false
	fountain_cycle = -1
	fountain_attempts = 0
	flash = 0.0
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
		"balloon_delivery": p = Vector2(250, 380); target = Vector2(1060, 345)
		"kite_rings":
			p = Vector2(180, 360)
			for i in 5:
				ring_x.append(410.0 + i * 155.0)
				ring_y.append([270.0, 450.0, 320.0, 470.0, 310.0][i])
		"fountain_timing": pass
		"crowd_traffic": pass
		"hat_catching":
			for i in 6:
				hat_x.append(260.0 + i * 150.0)
				hat_y.append(-float(i) * 180.0 - 30.0)
				hats_consumed.append(false)
		"ribbon_rhythm": pass
		"flower_pipes":
			# Four visibly scrambled elbows/straights form a single pipe route.
			flower_cells = [10, 0, 0, 0, 9, 10, 6, 0, 0, 0, 5, 0, 0, 0, 3, 6]
		"sign_balance": pass
		"shadow_alignment": alignment = -0.72
		"bubble_photo": pass
		"bench_swap": seats = [2, 0, 3, 1]
		"melody_memory": _next_melody()
	if assisted:
		prompt = "輔助已開：目標會標亮，判定範圍加寬"
	queue_redraw()

func _process(delta: float) -> void:
	if ended:
		return
	elapsed += delta
	game_time += delta
	phase += delta
	flash = maxf(0.0, flash - delta)
	if elapsed >= round_seconds:
		_finish(false)
		return
	_tick_game(delta)
	queue_redraw()

func _tick_game(delta: float) -> void:
	match mode:
		"balloon_delivery":
			var steer := _axis_x()
			var lift := _axis_y()
			if steer != 0.0 or lift != 0.0: mouse_steering = false
			if mouse_steering:
				steer = clampf((steering_target.x - p.x) * 0.65 / 165.0 - sin(phase * 1.6) * 30.0 / 165.0, -1.0, 1.0)
				lift = clampf((steering_target.y - p.y) * 0.65 / 145.0 - cos(phase * 1.1) * 12.0 / 145.0, -1.0, 1.0)
			velocity.x = move_toward(velocity.x, steer * 165.0 + sin(phase * 1.6) * 30.0, 210.0 * delta)
			velocity.y = move_toward(velocity.y, lift * 145.0 + cos(phase * 1.1) * 12.0, 180.0 * delta)
			p += velocity * delta
			p.x = clampf(p.x, 130, 1150); p.y = clampf(p.y, 210, 585)
			var thorn := Vector2(715, 380)
			if p.distance_to(thorn) < 62:
				p = thorn + (p - thorn).normalized() * 64.0; mistakes += 1; _feedback("刺球擦破了氣球！", PINK)
			if p.distance_to(target) < (118.0 if assisted else 80.0):
				if absf(velocity.y) < (88.0 if assisted else 58.0) and absf(velocity.x) < (102.0 if assisted else 76.0):
					_score(100); _finish(true, mistakes == 0)
				else:
					p = Vector2(760, 455); velocity *= 0.25; mistakes += 1; _feedback("郵箱前先穩住氣球！", YELLOW)
		"kite_rings":
			p.y += _axis_y() * 235.0 * delta
			p.y = clampf(p.y + sin(phase * 2.0) * (22.0 if not assisted else 11.0) * delta, 220, 570)
			p.x += 118.0 * delta
			if count < ring_x.size() and p.x >= ring_x[count]:
				if absf(p.y - ring_y[count]) <= (55 if assisted else 34):
					count += 1; score += 100; devil_progress += 1; _feedback("穿環成功！", MINT)
				else:
					count += 1; mistakes += 1; _feedback("差一點，風箏擦到環了", PINK)
			if p.x > 1240: _finish(count == ring_x.size() and mistakes <= 1, devil_progress == 5 and mistakes == 0)
		"fountain_timing":
			var beat_phase := fposmod(phase, 1.35)
			beat_window = beat_phase > (0.76 if assisted else 0.86) and beat_phase < (1.2 if assisted else 1.12)
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
		"flower_pipes": pass
		"sign_balance":
			var wind := sin(phase * 1.7) * (0.50 if not assisted else 0.32)
			balance += wind * delta - _axis_x() * 0.78 * delta
			balance = clampf(balance, -1.4, 1.4)
			if absf(balance) > 1.05:
				mistakes += 1; balance = signf(balance) * 0.72; _feedback("招牌晃過安全線！", PINK)
				if mistakes >= 3: _finish(false)
			if phase > 1.5 and fposmod(phase, 1.0) < delta and absf(balance) < (0.38 if assisted else 0.25):
				count += 1; score += 50
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
			if alignment_hold >= 3.0: score += 100; _finish(true, mistakes == 0 and not shadow_broken)
		"bubble_photo":
			target.y = 380.0 + sin(phase * 1.2) * 95.0
			var photo_beat := fposmod(phase, 2.0)
			beat_window = bubble_attempts < 3 and bubble_cycle != int(floor(phase / 2.0)) and photo_beat > (1.1 if assisted else 1.35) and photo_beat < 1.99
		"bench_swap": pass
		"melody_memory": _tick_melody(delta)

func _tick_crowd(delta: float) -> void:
	if count >= 6: _finish(mistakes == 0, mistakes == 0 and devil_progress == 6); return
	var walk := fposmod(phase, 2.2)
	if walk < delta:
		var direction := count % 2
		if assisted: lane = direction
		if direction == lane:
			count += 1; score += 50; devil_progress += 1; _feedback("隊伍安全通過", MINT)
		else:
			mistakes += 1; count += 1; _feedback("紅綠燈放錯方向", PINK)

func _tick_hats(delta: float) -> void:
	for i in hat_y.size():
		hat_y[i] += (112.0 + float(i % 3) * 20.0) * delta
		if i % 2 == 0:
			hat_x[i] += sin(phase * 1.8 + i) * 24.0 * delta
		if not hats_consumed[i] and hat_y[i] > 560:
			if absf(hat_x[i] - p.x) < (115.0 if assisted else 65.0):
				score += 100; count += 1; devil_progress += 1; _feedback("接住啦！", YELLOW)
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
	if ended: return
	var viewport := get_viewport()
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if viewport: viewport.set_input_as_handled()
		cancelled.emit()
		return
	if (event is InputEventKey or event is InputEventMouse) and viewport:
		viewport.set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R: reset_round(); return
		if event.keycode == KEY_SPACE: _press_action()
		if event.keycode >= KEY_1 and event.keycode <= KEY_4: _melody_input(event.keycode - KEY_1)
		if mode == "bench_swap" and event.keycode >= KEY_1 and event.keycode <= KEY_4: _bench_key(int(event.keycode - KEY_1))
		if mode == "flower_pipes":
			if event.keycode == KEY_LEFT: pipe_cursor = maxi(0, pipe_cursor - 1)
			if event.keycode == KEY_RIGHT: pipe_cursor = mini(15, pipe_cursor + 1)
			if event.keycode == KEY_UP: pipe_cursor = maxi(0, pipe_cursor - 4)
			if event.keycode == KEY_DOWN: pipe_cursor = mini(15, pipe_cursor + 4)
			if event.keycode == KEY_SPACE: _rotate_pipe(Vector2(370 + (pipe_cursor % 4) * 135 + 50, 205 + int(pipe_cursor / 4) * 85 + 30))
		if mode == "shadow_alignment" and (event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT): alignment = clampf(alignment + (0.04 if event.keycode == KEY_RIGHT else -0.04), -0.5, 0.5)
		if mode == "bubble_photo" and event.keycode == KEY_SPACE:
			if not bubble_ready: bubble_ready = true; bubble_aim = Vector2(790, target.y); prompt = "泡泡飛出去啦！等它包住吉祥物，再按空白鍵拍照"
			else: _bubble_click(Vector2(790, target.y))
		if mode == "ribbon_rhythm" and (event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT): _ribbon_input(event.keycode)
		if mode == "crowd_traffic" and (event.keycode == KEY_Q or event.keycode == KEY_E): lane = 1 - lane; _feedback("號誌切換：" + ("左向" if lane == 0 else "右向"), BLUE)
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		var m: Vector2 = mouse_event.position
		if m.y < 100:
			if m.x > size.x - 125: cancelled.emit()
			elif m.x > size.x - 280: reset_round()
			return
		if mode == "fountain_timing": _press_action()
		elif mode == "ribbon_rhythm": _ribbon_input(KEY_LEFT if m.x < size.x * 0.43 else (KEY_RIGHT if m.x > size.x * 0.57 else KEY_SPACE))
		elif mode == "crowd_traffic": lane = 1 - lane; _feedback("號誌切換", BLUE)
		elif mode == "shadow_alignment": alignment = inverse_lerp(190.0, 1090.0, m.x) - 0.5; mistakes += 1 if absf(alignment) > 0.3 else 0
		elif mode == "bubble_photo": _bubble_click(m)
		elif mode == "flower_pipes": _rotate_pipe(m)
		elif mode == "bench_swap": _bench_click(m)
		elif mode == "melody_memory":
			var petal := int(clampi(int((m.x - 380.0) / 130.0), 0, 3)); _melody_input(petal)
		elif mode == "sign_balance": balance += -0.16 if m.x < size.x / 2.0 else 0.16
	if event is InputEventMouseMotion:
		var mouse := event as InputEventMouseMotion
		match mode:
			"balloon_delivery":
				steering_target = Vector2(clampf(mouse.position.x, 130, 1150), clampf(mouse.position.y, 210, 585))
				mouse_steering = true
			"kite_rings": p.y = clampf(mouse.position.y, 220, 570)
			"hat_catching": p.x = clampf(mouse.position.x, 180, 1100)
			"shadow_alignment": alignment = clampf(inverse_lerp(190.0, 1090.0, mouse.position.x) - 0.5, -0.5, 0.5)

func _press_action() -> void:
	match mode:
		"fountain_timing":
			var cycle := int(floor(phase / 1.35))
			if fountain_cycle == cycle: return
			fountain_cycle = cycle
			fountain_attempts += 1
			if beat_window:
				count += 1; score += 100; devil_progress += 1; _feedback("跳得漂亮！", MINT)
			else:
				mistakes += 1; _feedback("看水柱亮起再跳", PINK)
			if fountain_attempts >= 3: _finish(count >= 2, devil_progress == 3 and mistakes == 0)
		"ribbon_rhythm":
			_ribbon_input(KEY_SPACE)

func _ribbon_input(action: int) -> void:
	if ended or beat != int(floor(phase / 0.82)): return
	var rhythm: Array[int] = [KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_RIGHT, KEY_LEFT, KEY_SPACE, KEY_LEFT, KEY_RIGHT]
	var expected: int = rhythm[beat % 8]
	if action == expected and beat_window:
		beat += 1; streak += 1; score += 75; devil_progress += 1
		note_played.emit(0 if action == KEY_LEFT else (1 if action == KEY_RIGHT else 2))
		_feedback("踩中節拍！", MINT)
	else:
		beat += 1; streak = 0; mistakes += 1; _feedback("慢半拍了", PINK)
	if beat >= 8: _finish(devil_progress >= (4 if assisted else 6), mistakes == 0 and devil_progress == 8)

func _rotate_pipe(m: Vector2) -> void:
	if m.x < 370 or m.x > 910 or m.y < 205 or m.y > 545: return
	var col := int((m.x - 370) / 135.0); var row := int((m.y - 205) / 85.0); var idx := row * 4 + col
	if idx < 0 or idx >= 16: return
	flower_cells[idx] = ((flower_cells[idx] << 1) & 15) | (flower_cells[idx] >> 3)
	move_count += 1; score = maxi(0, 1000 - move_count * 20)
	if _pipe_solved(): _finish(true, move_count <= 4)

func _pipe_solved() -> bool:
	# Validate path by flooding reciprocal connections from upper-left inlet.
	var dirs: Array[Vector2i] = [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
	var bits: Array[int] = [1,2,4,8]
	var visited := {0: true}; var queue: Array[int] = [0]; var reached_end := false
	while not queue.is_empty():
		var at: int = queue.pop_front(); var x: int = at % 4; var y: int = int(at / 4)
		if at == 15: reached_end = true
		for d in 4:
			if flower_cells[at] & bits[d] == 0: continue
			var nx: int = x + dirs[d].x; var ny: int = y + dirs[d].y
			if nx < 0 or nx > 3 or ny < 0 or ny > 3: continue
			var n: int = ny * 4 + nx; var opposite: int = (d + 2) % 4
			if flower_cells[n] & bits[opposite] and not visited.has(n): visited[n] = true; queue.append(n)
	return reached_end and (flower_cells[0] & 1) != 0 and (flower_cells[15] & 4) != 0

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
	var aim_limit := 180.0 if assisted else 130.0
	var photo_x_limit := 160.0 if assisted else 120.0
	var photo_y_limit := 140.0 if assisted else 100.0
	if beat_window and aim_error < aim_limit and absf(m.x - 790.0) < photo_x_limit and absf(m.y - target.y) < photo_y_limit:
		beat += 1; score += 100; devil_progress += 1
		if aim_error >= 60.0 or m.distance_to(Vector2(790, target.y)) >= 40.0 or fposmod(phase, 2.0) < 1.55 or fposmod(phase, 2.0) > 1.85: bubble_perfect = false
		_feedback("咔嚓！合照成功", MINT)
	else:
		mistakes += 1; _feedback("泡泡沒包住吉祥物，等下一顆", PINK)
	if bubble_attempts >= 3: _finish(devil_progress >= 2, devil_progress == 3 and mistakes == 0 and bubble_perfect)

func _bench_click(m: Vector2) -> void:
	if m.y < 300 or m.y > 510 or m.x < 370 or m.x > 910: return
	var index := int((m.x - 370.0) / 135.0)
	if select_index < 0: select_index = index; prompt = "再點一個座位交換"; return
	var tmp := seats[index]; seats[index] = seats[select_index]; seats[select_index] = tmp
	select_index = -1; move_count += 1; score = maxi(0, 500 - move_count * 50)
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
	move_count += 1; score = maxi(0, 500 - move_count * 50)
	if seats == [0,1,2,3]: _finish(true, move_count <= 3)
	else: _feedback("朋友們再換一下位置", BLUE)

func _melody_input(note: int) -> void:
	if mode != "melody_memory" or sequence_showing or ended: return
	if sequence_index >= sequence.size(): return
	if note == sequence[sequence_index]:
		sequence_index += 1; score += 25; note_played.emit(note); _feedback("音符對了！", MINT)
		if sequence_index >= sequence.size():
			count += 1; devil_progress += sequence.size(); score += 100
			if count >= 3: _finish(true, devil_progress >= 12 and mistakes == 0)
			else: _next_melody()
	else:
		mistakes += 1; _feedback("音符跑掉了，再聽一次", PINK); sequence_index = 0; sequence_show_index = 0; sequence_showing = true; sequence_clock = float(sequence.size()) * (0.8 if assisted else 0.55)

func _feedback(message: String, color: Color) -> void:
	prompt = message; feedback_color = color; flash = 0.14
	feedback.emit("success" if color == MINT or color == YELLOW else "miss" if color == PINK else "interact")

func _score(amount: int) -> void:
	score += amount

func _finish(success: bool, devil: bool = false) -> void:
	if ended: return
	ended = true; won = success; devil_won = success and devil
	var result := {"game_id": game_id, "success": success, "devil": devil_won, "score": score, "assisted": assisted}
	finished.emit(result)
	queue_redraw()

func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), BG)
	if flash > 0.0: draw_rect(Rect2(Vector2.ZERO, s), Color(feedback_color, flash * 0.32))
	for i in 8:
		draw_circle(Vector2(90 + i * 160, 150 + sin(phase + i) * 12), 3, Color(1,1,1,0.28))
	draw_rect(Rect2(0,0,s.x,108), Color("#10243a"))
	var info := _definition()
	draw_string(FONT, Vector2(34,48), info.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, CREAM)
	draw_string(FONT, Vector2(34,82), "操作：" + info.instructions, HORIZONTAL_ALIGNMENT_LEFT, s.x - 350, 15, Color("#c2d6e4"))
	draw_string(FONT, Vector2(34,104), "目標：" + info.goal + "　✦ 惡魔：" + info.devil_hint, HORIZONTAL_ALIGNMENT_LEFT, s.x - 80, 14, Color("#d6e6ee"))
	draw_string(FONT, Vector2(s.x - 330,45), "時間 %02d　　分數 %04d" % [int(round_seconds - elapsed), score], HORIZONTAL_ALIGNMENT_LEFT, 240, 17, CREAM)
	draw_string(FONT, Vector2(s.x - 280,80), "R 重試　　Esc 離開", HORIZONTAL_ALIGNMENT_LEFT, 260, 14, Color("#c2d6e4"))
	if assisted: draw_string(FONT, Vector2(s.x - 295,105), "✦ 輔助已開", HORIZONTAL_ALIGNMENT_LEFT, 180, 16, YELLOW)
	_draw_game()
	draw_rect(Rect2(26,s.y - 67,s.x - 52,44), Color("#10243acc"), true)
	draw_string(FONT, Vector2(44,s.y - 39), prompt, HORIZONTAL_ALIGNMENT_LEFT, s.x - 100, 18, Color("#ffffff"))
	if ended:
		draw_rect(Rect2(0,0,s.x,s.y), Color(0.03,0.08,0.14,0.70))
		draw_string(FONT, Vector2(0,s.y * 0.46), "完成！" if won else "再試一次吧！", HORIZONTAL_ALIGNMENT_CENTER, s.x, 44, YELLOW if won else PINK)
		draw_string(FONT, Vector2(0,s.y * 0.54), ("惡魔拍貼達成 ✦" if devil_won else "普通拍貼達成" if won else "按 R 免費重試　／　Esc 離開"), HORIZONTAL_ALIGNMENT_CENTER, s.x, 23, CREAM)

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

func _draw_balloon() -> void:
	draw_rect(Rect2(0,560,size.x,160), Color("#326a6a")); draw_rect(Rect2(940,290,170,170), Color("#e5ac73"))
	draw_rect(Rect2(990,340,90,84), Color("#57496a")); draw_string(FONT, Vector2(978,326), "郵箱", HORIZONTAL_ALIGNMENT_LEFT, 120, 24, CREAM)
	draw_colored_polygon(PackedVector2Array([Vector2(690,325),Vector2(735,380),Vector2(690,435),Vector2(645,380)]), PINK)
	draw_circle(p, 33, Color("#fc78aa")); draw_line(p + Vector2(0,34), p + Vector2(0,70), CREAM, 3)
	draw_string(FONT, Vector2(120,590), "滑鼠移動瞄準　鍵盤 ← → 控風、↑↓ 控浮力　風向 " + ("←" if sin(phase * 1.6) < 0 else "→"), HORIZONTAL_ALIGNMENT_LEFT, 800, 20, CREAM)

func _draw_kite() -> void:
	draw_rect(Rect2(0,585,size.x,135), Color("#33776c"))
	for i in ring_x.size():
		var c := MINT if i < count else YELLOW
		draw_arc(Vector2(ring_x[i], ring_y[i]), 42, 0, TAU, 40, c, 9)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0,-26),p + Vector2(28,0),p + Vector2(0,26),p + Vector2(-28,0)]), PINK)
	draw_line(p + Vector2(0,26), p + Vector2(-34,68), CREAM, 3)
	draw_string(FONT, Vector2(0,630), "滑鼠移動高度　或用 ↑ ↓ 迎風修正", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, CREAM)

func _draw_fountain() -> void:
	draw_rect(Rect2(140,495,1000,86), Color("#6a9ca5"), true)
	var splash := beat_window
	for i in 5:
		var x := 260.0 + i * 190.0; var height := 45.0 + absf(sin(phase * 2.3 + i * 0.7)) * 145.0
		draw_line(Vector2(x,495), Vector2(x,495-height), BLUE if splash else Color("#548293"), 18)
		draw_circle(Vector2(x,495-height), 16, MINT if splash else BLUE)
	draw_circle(Vector2(640,454),32,PINK); draw_line(Vector2(640,486),Vector2(640,510),CREAM,7)
	draw_string(FONT, Vector2(0,280), "看到水柱最亮的一刻，按空白鍵／點一下起跳", HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, YELLOW)
	draw_string(FONT, Vector2(0,350), "●　●　●".substr(0,count * 2) + "○　○　○".substr(count * 2), HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, CREAM)

func _draw_crowd() -> void:
	draw_rect(Rect2(0,300,size.x,230), Color("#53667b")); draw_rect(Rect2(0,390,size.x,42), YELLOW)
	draw_rect(Rect2(575,250,130,360), Color("#263a52"), true)
	draw_circle(Vector2(640,250), 47, MINT if lane == 0 else PINK)
	draw_string(FONT, Vector2(0,215), "號誌 " + ("綠燈 ←" if lane == 0 else "綠燈 →") + "　按 Q／E 或點擊切換", HORIZONTAL_ALIGNMENT_CENTER, size.x, 27, CREAM)
	for i in 6:
		var x := 90.0 + fposmod(phase * 130 + i * 180, 1100.0); var y := 355.0 if (i + count) % 2 == 0 else 470.0
		draw_circle(Vector2(x,y), 19, CROWD_COLORS[i % 4]); draw_rect(Rect2(x-11,y+19,22,32), CREAM)

func _draw_hats() -> void:
	draw_rect(Rect2(0,570,size.x,150), Color("#3d6d65")); draw_circle(Vector2(p.x,570), 34, PINK); draw_rect(Rect2(p.x-22,570,44,54), Color("#f0d19a"))
	for i in hat_y.size():
		if hat_y[i] < 620:
			draw_arc(Vector2(hat_x[i],hat_y[i]), 24, PI, TAU, 24, YELLOW, 12); draw_line(Vector2(hat_x[i]-24,hat_y[i]),Vector2(hat_x[i]+24,hat_y[i]),YELLOW,5)
	draw_string(FONT, Vector2(0,190), "← → 移動接帽子　　陣風：" + ("吹左" if sin(phase*1.8) < 0 else "吹右"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, CREAM)

func _draw_ribbon() -> void:
	for i in 8:
		var x := 330.0 + i * 90.0; var c := PINK if i == beat else (MINT if i < beat else Color("#668297"))
		draw_circle(Vector2(x,420), 31, c)
	var labels := ["←","→","跳","→","←","跳","←","→"]
	for i in 8: draw_string(FONT, Vector2(310+i*90,429), labels[i], HORIZONTAL_ALIGNMENT_CENTER, 40, 25, CREAM)
	draw_string(FONT, Vector2(0,290), "依序按方向鍵／空白鍵，或按節拍點擊", HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, CREAM)
	draw_circle(Vector2(640,520), 42, YELLOW if beat_window else Color("#617b8f"))

func _draw_flower() -> void:
	var dirs := PIPE_DIRS; var bits := PIPE_BITS
	draw_string(FONT, Vector2(275,230), "🚰", HORIZONTAL_ALIGNMENT_CENTER, 60, 34, BLUE)
	for i in 16:
		var x := 370.0 + (i%4)*135.0; var y := 205.0 + int(i/4)*85.0
		draw_rect(Rect2(x,y,112,65), Color("#477663"), true)
		if i == pipe_cursor: draw_rect(Rect2(x,y,112,65), CREAM, false, 3)
		for d in 4:
			if flower_cells[i] & bits[d]: draw_line(Vector2(x+56,y+32), Vector2(x+56+dirs[d].x*32,y+32+dirs[d].y*25), BLUE, 9)
		draw_circle(Vector2(x+56,y+32),7,YELLOW)
	draw_circle(Vector2(955,545),30,PINK)

func _draw_sign() -> void:
	draw_line(Vector2(640,510),Vector2(640,590),Color("#a7754f"),14)
	var angle := balance * 0.30
	var a := Vector2(640,330).rotated(angle); var left := Vector2(640,330) + Vector2(-185,0).rotated(angle); var right := Vector2(640,330) + Vector2(185,0).rotated(angle)
	draw_line(left,right, YELLOW, 20); draw_circle(Vector2(640,330),17,PINK)
	draw_string(FONT, Vector2(0,245), "← → 壓低重的一側／點畫面左或右　風向：" + ("←" if sin(phase*1.7)<0 else "→"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, CREAM)
	draw_line(Vector2(570,600),Vector2(710,600),MINT,4)

func _draw_shadow() -> void:
	draw_rect(Rect2(790,205,310,355), Color("#f2dca6"), true)
	var x := 940.0 + alignment * 300.0
	draw_colored_polygon(PackedVector2Array([Vector2(x-65,490),Vector2(x-42,330),Vector2(x,270),Vector2(x+42,330),Vector2(x+65,490)]), Color("#263c54"))
	draw_arc(Vector2(940,390),90,PI,TAU,32,PINK,7)
	draw_string(FONT, Vector2(0,610), "點選畫面左右移動燈光　保持影子在粉紅輪廓內", HORIZONTAL_ALIGNMENT_CENTER, size.x, 21, CREAM)
	draw_line(Vector2(190,570),Vector2(1090,570),YELLOW,4)

func _draw_bubble() -> void:
	draw_circle(Vector2(790,target.y),53,YELLOW); draw_circle(Vector2(770,target.y-12),7,BG); draw_circle(Vector2(810,target.y-12),7,BG); draw_arc(Vector2(790,target.y+3),18,0,PI,20,BG,3)
	draw_circle(Vector2(310,465),50,PINK); draw_string(FONT, Vector2(0,240), "點擊吹泡泡；泡泡發亮包住吉祥物時，再點吉祥物拍照！", HORIZONTAL_ALIGNMENT_CENTER, size.x, 23, CREAM)
	var open := beat_window
	draw_arc(Vector2(790,target.y),105,0,TAU,48,MINT if open else BLUE,6 if open else 3)
	draw_string(FONT, Vector2(0,610), "合照 " + str(beat) + " / 3　　時機亮起再拍", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, YELLOW)

func _draw_bench() -> void:
	draw_rect(Rect2(330,355,620,78), Color("#9b684f"), true)
	var colors := [PINK,BLUE,YELLOW,MINT]
	for i in 4:
		var x := 425.0 + i*135.0; var y := 340.0
		draw_circle(Vector2(x,y),43,colors[seats[i]])
		draw_string(FONT, Vector2(x-19,y+8), str(seats[i]+1), HORIZONTAL_ALIGNMENT_CENTER, 38, 24, BG)
		if select_index == i: draw_arc(Vector2(x,y),52,0,TAU,32,CREAM,5)
	var pairs := "朋友組：1+2、3+4" if assisted else "好友標記：1+2、3+4（同色為一組）"
	draw_string(FONT, Vector2(0,250), pairs, HORIZONTAL_ALIGNMENT_CENTER, size.x, 25, CREAM)
	draw_string(FONT, Vector2(0,500), "點兩個座位交換　　交換次數："+str(move_count)+" / 6", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, YELLOW)

func _draw_melody() -> void:
	var colors := [PINK,BLUE,YELLOW,MINT]
	for i in 4:
		var x := 450.0 + i*130.0; var lit := sequence_showing and sequence_show_index < sequence.size() and i == sequence[sequence_show_index] and int(sequence_clock*3.2)%2 == 0
		draw_circle(Vector2(x,420),47,CREAM if lit else colors[i])
		draw_string(FONT, Vector2(x-18,430), str(i+1), HORIZONTAL_ALIGNMENT_CENTER, 36, 23, BG)
	draw_string(FONT, Vector2(0,295), "樂句 " + str(count+1) + " / 3　　" + ("請聽並記住…" if sequence_showing else "依序按 1–4 或點花朵演奏"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 25, CREAM)
	if not sequence_showing:
		for j in sequence_index: draw_circle(Vector2(470+j*35,520),9,MINT)









