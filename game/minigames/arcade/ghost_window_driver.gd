extends "res://game/minigames/arcade/arcade_driver.gd"
## 鬼影擦窗: a tall hotel window of six panes keeps fogging over. A little
## ghost peeks in at one pane at a time, a faint glow through the fog. Move the
## cloth with the arrows: it wipes the fog wherever it moves. Rub the ghost's
## pane clear before he fades and he waves hello for points (more the quicker).
## The fog creeps back faster and faster, ghosts stay for less time and later
## blink across to another pane. Rub a pane with no ghost behind it mostly clear
## (or keep rubbing it) and it shows your own reflection with a ghost standing
## right behind you.
## Rules only: the picture lives in ghost_window_view.gd.
##
## Positions are screen pixels; the fog is a grid of CELL-pixel cells, 1 fully
## fogged and 0 wiped clear.

const View = preload("res://game/minigames/arcade/ghost_window_view.gd")
const WINDOW := Rect2(264, 176, 756, 384)
const COLUMNS := 3
const ROWS := 2
const CELL := 21.0
## Cloth: radius of its wipe, top speed and how fast it answers the arrows.
const CLOTH := 50.0
const CLOTH_SPEED := 560.0
const CLOTH_RESPONSE := 14.0
## Fog wiped per second under a moving cloth, and how fast it creeps back
## early and late.
const WIPE := 5.0
const FOG_FIRST := 0.1
const FOG_LAST := 0.32
## A pane counts as wiped at this share clear; a wrong pane at the bigger one.
const REVEAL := 0.55
const WRONG := 0.72
## Or keep rubbing an empty pane this long.
const LINGER := 1.4
## A tap of an arrow nudges the cloth this share of its top speed.
const NUDGE := 0.35
## Seconds a ghost stays early and late, and the pause between ghosts.
const STAY_FIRST := 3.4
const STAY_LAST := 1.9
const GAP := 0.45
const HOP_HEAT := 0.4
const WAVE_SECONDS := 0.9
const SCARE_SECONDS := 1.6
const HELLO_POINTS := 20
const QUICK_POINTS := 20
const STREAK_POINTS := 2
const STREAK_CAP := 10

var cloth := Vector2.ZERO
var cloth_velocity := Vector2.ZERO
## Fog per cell, row by row across the whole window.
var fog: PackedFloat32Array = PackedFloat32Array()
var grid := Vector2i.ZERO
## Fog cell indices inside each pane; the panes never move, so this is built once per round.
var _pane_cells: Array[PackedInt32Array] = []
## Ghosts now peeking: {pane, at (clock when he arrived), stay, hop_at (clock
## of a blink to another pane, negative for none), from (pane before a hop)}.
var ghosts: Array[Dictionary] = []
## The last hello and the last fright: {pane, at}.
var hello: Dictionary = {}
var scare: Dictionary = {}
var greeted := 0
var missed := 0
var scares := 0
var streak := 0
var _next_ghost := 0.0
## The empty pane being rubbed and for how long.
var _rub_pane := -1
var _rub_time := 0.0
var _arrows := {&"left": 0, &"right": 0, &"up": 0, &"down": 0}
var _demo := false


func _init() -> void:
	verb = "移動抹布擦掉霧氣，在小鬼淡掉前把他擦出來！"
	hint = [["← → ↑ ↓", "移動抹布"]]
	round_seconds = 45.0
	thresholds = [200, 540, 720]
	verdicts = [
		"窗外的小鬼們決定改去別家旅館。",
		"銅牌！擦出幾個小鬼，也被自己的倒影嚇到。",
		"銀牌！小鬼們排隊等你擦窗。",
		"金牌！整扇窗亮晶晶，小鬼都來跟你揮手。",
	]
	variants = [
		{"id": "standard", "label": "月夜窗"},
		{"id": "twins", "label": "雙胞胎小鬼", "twins": 0.35},
		{"id": "mist", "label": "濃霧夜", "fog": 1.35, "hop_heat": 0.1},
	]
	score_label = "擦窗得分"
	view_script = View


func _begin_round(_chosen: Dictionary) -> void:
	_demo = true
	_reset_window()
	ghosts.append(_ghost(0, 99.0))


## The countdown rubs the first pane clear by itself.
func _warm_up(delta: float) -> void:
	var target := pane_rect(0).get_center() + Vector2(70.0 * sin(clock * 9.0), 45.0 * cos(clock * 7.0))
	_move_cloth(delta, (target - cloth).normalized() if cloth.distance_to(target) > 8.0 else Vector2.ZERO)
	_age_fog(delta)
	_check_panes()


func _go() -> void:
	_demo = false
	_reset_window()
	# Arrows already held through the countdown take hold at once.
	for button: StringName in _held.values():
		touched = true
		_press(button)


func _tick(delta: float) -> void:
	var push := Vector2(_arrows[&"right"] - _arrows[&"left"], _arrows[&"down"] - _arrows[&"up"])
	_move_cloth(delta, push.normalized() if push != Vector2.ZERO else Vector2.ZERO)
	_age_fog(delta)
	_run_ghosts()
	_check_panes()


func _press(button: StringName) -> void:
	if _arrows.has(button):
		_arrows[button] += 1
		# Even a tap nudges the cloth.
		var push := {&"left": Vector2.LEFT, &"right": Vector2.RIGHT, &"up": Vector2.UP, &"down": Vector2.DOWN}
		cloth_velocity += (push[button] as Vector2) * CLOTH_SPEED * NUDGE


func _release(button: StringName) -> void:
	if _arrows.has(button):
		_arrows[button] = maxi(0, _arrows[button] - 1)


## No input, no points (a cloth nobody moves wipes nothing anyway).
func add_score(points: int, word := "") -> void:
	if touched:
		super(points, word)


func _round_over() -> void:
	for key in _arrows:
		_arrows[key] = 0


func _snapshot(into: Dictionary) -> void:
	into.cloth = cloth
	into.cloth_velocity = cloth_velocity
	into.cloth_radius = CLOTH
	into.fog = fog
	into.grid = grid
	into.cell = CELL
	into.window = WINDOW
	into.ghosts = ghosts
	into.hello = hello
	into.scare = scare
	into.wave_seconds = WAVE_SECONDS
	into.scare_seconds = SCARE_SECONDS
	into.streak = streak
	var shares: Array[float] = []
	for pane in COLUMNS * ROWS:
		shares.append(clear_share(pane))
	into.shares = shares


func pane_rect(pane: int) -> Rect2:
	var size := Vector2(WINDOW.size.x / COLUMNS, WINDOW.size.y / ROWS)
	return Rect2(WINDOW.position + Vector2(pane % COLUMNS, pane / COLUMNS) * size, size)


## Share of a pane wiped clear, 0..1.
func clear_share(pane: int) -> float:
	var cells := _pane_cells[pane]
	var total := 0.0
	for index in cells:
		total += 1.0 - fog[index]
	return total / maxf(1.0, cells.size())


func fog_rate() -> float:
	return lerpf(FOG_FIRST, FOG_LAST, heat()) * float(variant.get("fog", 1.0)) / (ASSIST_WINDOW if assisted else 1.0)


func stay_seconds() -> float:
	return window(lerpf(STAY_FIRST, STAY_LAST, heat()))


func scared() -> bool:
	return not scare.is_empty() and clock - float(scare.at) < SCARE_SECONDS


func ghost_pane(ghost: Dictionary) -> int:
	if float(ghost.hop_at) >= 0.0 and clock >= float(ghost.hop_at):
		return int(ghost.pane)
	return int(ghost.from) if int(ghost.from) >= 0 else int(ghost.pane)


func _cell_centre(x: int, y: int) -> Vector2:
	return WINDOW.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * CELL


func _move_cloth(delta: float, push: Vector2) -> void:
	if scared():
		cloth_velocity = Vector2.ZERO
		return
	cloth_velocity = cloth_velocity.lerp(push * CLOTH_SPEED, 1.0 - exp(-CLOTH_RESPONSE * delta))
	var before := cloth
	cloth = (cloth + cloth_velocity * delta).clamp(WINDOW.position, WINDOW.end)
	# Only a moving cloth wipes; it clears what it passes over.
	var moved := cloth.distance_to(before)
	_note_rub(delta, moved >= 0.5)
	if moved < 0.5:
		return
	var rub := minf(1.0, WIPE * delta * (0.4 + moved / (CLOTH_SPEED * delta)))
	var low := ((cloth - WINDOW.position - Vector2(CLOTH, CLOTH)) / CELL).floor()
	var high := ((cloth - WINDOW.position + Vector2(CLOTH, CLOTH)) / CELL).ceil()
	for y in range(maxi(0, int(low.y)), mini(grid.y, int(high.y))):
		for x in range(maxi(0, int(low.x)), mini(grid.x, int(high.x))):
			if _cell_centre(x, y).distance_to(cloth) <= CLOTH:
				var index := y * grid.x + x
				fog[index] = maxf(0.0, fog[index] - rub)


## Keep count of how long the cloth has been rubbing one pane with no ghost
## behind it.
func _note_rub(delta: float, moving: bool) -> void:
	var pane := pane_at(cloth)
	var empty := not ghosts.any(func(ghost: Dictionary) -> bool: return ghost_pane(ghost) == pane)
	if moving and empty:
		if pane != _rub_pane:
			_rub_pane = pane
			_rub_time = 0.0
		_rub_time += delta
	else:
		_rub_time = maxf(0.0, _rub_time - delta * 0.5)


func pane_at(at: Vector2) -> int:
	var column := clampi(int((at.x - WINDOW.position.x) / (WINDOW.size.x / COLUMNS)), 0, COLUMNS - 1)
	var row := clampi(int((at.y - WINDOW.position.y) / (WINDOW.size.y / ROWS)), 0, ROWS - 1)
	return row * COLUMNS + column


func _age_fog(delta: float) -> void:
	var creep := fog_rate() * delta
	for index in fog.size():
		fog[index] = minf(1.0, fog[index] + creep)


func _run_ghosts() -> void:
	for ghost in ghosts.duplicate():
		if clock - float(ghost.at) >= float(ghost.stay):
			ghosts.erase(ghost)
			missed += 1
			streak = 0
			say("小鬼淡掉了…", false)
			sound(52)
			_next_ghost = clock + GAP
	if ghosts.is_empty() and clock >= _next_ghost and not scared():
		_spawn()


func _spawn() -> void:
	var count := 2 if rng.randf() < float(variant.get("twins", 0.0)) and heat() > 0.15 else 1
	var taken: Array[int] = []
	for index in count:
		var pane := _far_pane(taken)
		taken.append(pane)
		var ghost := _ghost(pane, stay_seconds() * (1.3 if count == 2 else 1.0))
		# Later ghosts blink across to another pane part-way through.
		if heat() >= float(variant.get("hop_heat", HOP_HEAT)) and rng.randf() < 0.45:
			var other := _far_pane(taken + [pane])
			ghost.from = pane
			ghost.pane = other
			ghost.hop_at = clock + float(ghost.stay) * rng.randf_range(0.3, 0.45)
			ghost.stay = float(ghost.stay) + 0.6
		ghosts.append(ghost)
		# Fog him in properly so he has to be wiped out.
		_fog_pane(int(ghost.pane))
		if int(ghost.from) >= 0:
			_fog_pane(int(ghost.from))
	sound(60)


## A pane away from the cloth and from `avoid`.
func _far_pane(avoid: Array) -> int:
	var choices: Array[int] = []
	for pane in COLUMNS * ROWS:
		if pane not in avoid and not pane_rect(pane).grow(-20.0).has_point(cloth):
			choices.append(pane)
	if choices.is_empty():
		for pane in COLUMNS * ROWS:
			if pane not in avoid:
				choices.append(pane)
	return choices[rng.randi() % choices.size()]


func _check_panes() -> void:
	if scared():
		return
	for ghost in ghosts.duplicate():
		var pane := ghost_pane(ghost)
		if clear_share(pane) >= REVEAL:
			ghosts.erase(ghost)
			_hello(pane, ghost)
	if _demo:
		return
	if _rub_time >= LINGER and _rub_pane >= 0:
		_scare(_rub_pane)
		return
	for pane in COLUMNS * ROWS:
		if ghosts.any(func(ghost: Dictionary) -> bool: return ghost_pane(ghost) == pane):
			continue
		if clear_share(pane) >= WRONG:
			_scare(pane)
			return


func _hello(pane: int, ghost: Dictionary) -> void:
	hello = {"pane": pane, "at": clock}
	# He waves through the glass, then the pane mists over behind him.
	_fog_pane(pane)
	streak += 1
	sound(74 + mini(streak, 12))
	_next_ghost = clock + GAP
	if _demo:
		return
	greeted += 1
	var left := clampf(1.0 - (clock - float(ghost.at)) / float(ghost.stay), 0.0, 1.0)
	var points := HELLO_POINTS + roundi(QUICK_POINTS * left) + mini(streak, STREAK_CAP) * STREAK_POINTS
	add_score(points, "哈囉！+%d" % points)


func _scare(pane: int) -> void:
	scare = {"pane": pane, "at": clock}
	_rub_time = 0.0
	streak = 0
	scares += 1
	sound(46)
	sound(40)
	_fog_pane(pane)
	_next_ghost = clock + SCARE_SECONDS
	# The first fright of a round is a free look.
	funny_fail("背後有鬼！", scares > 1)


func _fog_pane(pane: int) -> void:
	for index in _pane_cells[pane]:
		fog[index] = 1.0


func _reset_window() -> void:
	grid = Vector2i(ceili(WINDOW.size.x / CELL), ceili(WINDOW.size.y / CELL))
	fog = PackedFloat32Array()
	fog.resize(grid.x * grid.y)
	fog.fill(1.0)
	_pane_cells.clear()
	for pane in COLUMNS * ROWS:
		var rect := pane_rect(pane)
		var cells := PackedInt32Array()
		for y in grid.y:
			for x in grid.x:
				if rect.has_point(_cell_centre(x, y)):
					cells.append(y * grid.x + x)
		_pane_cells.append(cells)
	cloth = WINDOW.get_center() + Vector2(0, WINDOW.size.y * 0.25)
	cloth_velocity = Vector2.ZERO
	ghosts.clear()
	hello = {}
	scare = {}
	greeted = 0
	missed = 0
	scares = 0
	streak = 0
	_next_ghost = clock + 0.6
	_rub_pane = -1
	_rub_time = 0.0
	for key in _arrows:
		_arrows[key] = 0


func _ghost(pane: int, stay: float) -> Dictionary:
	return {"pane": pane, "at": clock, "stay": stay, "hop_at": -99.0, "from": -1}
