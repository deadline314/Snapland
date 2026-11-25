extends RefCounted
## Fixed-step charcoal and food surfaces for three independently controlled skewers.

const BENCH := -1
const NEAR := 0
const FAR := 1
const SERVED := 2
const FACE_COUNT := 4
const SKEWER_COUNT := 3
const TICK := 1.0 / 60.0
const ROUND_SECONDS := 92.0
const ASSISTED_SECONDS := 108.0
const SKEWER_POINTS := 150
const RESIDUAL_POINTS := 100
const LOSS_POINTS := 20

const ALL_COOKED := -2
const MULTIPLE_UNCOOKED := -1
const AMBIENT := 0.14
const INCIDENCE := [1.0, 0.27, 0.10, 0.27]
const INGREDIENTS := ["青蔥串", "杏鮑菇串", "甜椒串"]
const INGREDIENT_IDS := ["scallion", "king_oyster", "sweet_pepper"]
const LAYOUTS := [
	{"order": [0, 1, 2], "sizes": [0.82, 1.05, 0.92], "fuel": 0.87, "reserve": 0.77,
		"near": [1.00, 0.92, 1.00], "far": [0.91, 1.00, 0.95]},
	{"order": [2, 0, 1], "sizes": [0.96, 0.87, 1.09], "fuel": 0.77, "reserve": 0.83,
		"near": [0.90, 1.00, 0.96], "far": [1.00, 0.90, 0.98]},
]

class Skewer extends RefCounted:
	var ingredient := ""
	var ingredient_id := ""
	var size := 1.0
	var zone := BENCH
	var down_face := 0
	var heat := PackedFloat32Array([AMBIENT, AMBIENT, AMBIENT, AMBIENT])
	var cooked := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var charred := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var gloss := 0.0
	var warned := false
	var residual_finish := false

var _layout := 0
var _assisted := false
var _skewers: Array[Skewer] = []
var _selected := 0
var _served := 0
var _helper := -1
var _warning := -1
var _fuel := 0.0
var _residual_heat := 0.0
var _refuels := 0
var _mistakes := 0
var _ticks := 0
var _accumulator := 0.0
var _handled_heat := false
var _last_finish_residual := false
var _ended := false
var _feedback := ""
var _notes: Array[int] = []

func _init() -> void:
	reset(false, 0)

func reset(assisted: bool, layout: int) -> void:
	_layout = posmod(layout, LAYOUTS.size())
	_assisted = assisted
	_skewers.clear()
	for index in SKEWER_COUNT:
		_skewers.append(_new_skewer(index))
	_selected = 0
	_served = 0
	_helper = -1
	_warning = -1
	_fuel = LAYOUTS[_layout].fuel
	_residual_heat = LAYOUTS[_layout].reserve
	_refuels = 0
	_mistakes = 0
	_ticks = 0
	_accumulator = 0.0
	_handled_heat = false
	_last_finish_residual = false
	_ended = false
	_feedback = "選一串，放到近炭或餘溫區。"
	_notes.clear()

func select_skewer(index: int) -> bool:
	if _ended or index < 0 or index >= SKEWER_COUNT:
		return false
	_selected = index
	return true

func move(zone: int) -> bool:
	var skewer := _skewers[_selected]
	if _ended or skewer.zone == SERVED or zone < BENCH or zone > FAR or skewer.zone == zone:
		return false
	skewer.zone = zone
	_clear_warning()
	match zone:
		NEAR: _feedback = "近炭加熱快，留意朝下的一面。"
		FAR: _feedback = "餘溫較慢，仍能烤熟朝下的一面。"
		BENCH: _feedback = "烤串已移開，表面仍會慢慢放涼。"
	return true

func turn() -> bool:
	var skewer := _skewers[_selected]
	if _ended or skewer.zone == SERVED:
		return false
	_rotate(skewer)
	_clear_warning()
	_feedback = "已轉四分之一圈，這一面朝下。"
	_note(8)
	return true

func add_coal() -> bool:
	if _ended or _warning >= 0:
		return false
	if _fuel >= 0.96:
		_feedback = "炭火仍足，暫時不用添炭。"
		return false
	_fuel = minf(1.0, _fuel + 0.58)
	_refuels += 1
	_feedback = "已添炭，近區回熱。這局不計無添炭挑戰。"
	_note(7)
	return true

func serve() -> bool:
	var skewer := _skewers[_selected]
	if _ended or skewer.zone == SERVED:
		return false
	if _is_ruined(skewer):
		_feedback = "有一面已焦，可換掉這一串。"
		return false
	if _uncooked_face_count(skewer) > 0:
		_feedback = "還有未熟面，轉到熟度不足的一面。"
		return false
	_clear_warning()
	skewer.zone = SERVED
	_served += 1
	if _helper == _selected:
		_helper = -1
	_note(14)
	_ended = _served == SKEWER_COUNT
	if _ended:
		_feedback = "三串都各面熟透，已上菜。"
	else:
		_feedback = "已上菜。選下一串繼續。"
	return true

func replace_skewer() -> bool:
	if _ended or _skewers[_selected].zone == SERVED or not _is_ruined(_skewers[_selected]):
		return false
	_skewers[_selected] = _new_skewer(_selected)
	_mistakes += 1
	_clear_warning()
	_feedback = "換了一串，先前上菜的份數保留。"
	_note(3)
	return true

func toggle_helper() -> bool:
	if not _assisted or _ended or _skewers[_selected].zone == SERVED:
		return false
	_helper = -1 if _helper == _selected else _selected
	_feedback = "輔助手會在熟窗內轉這一串。" if _helper >= 0 else "此局由你手動翻面。"
	return true

func clear_input() -> void:
	# The driver owns pressed inputs; model commands are discrete and never latch.
	pass

func step(delta: float) -> void:
	if _ended or _warning >= 0 or not is_finite(delta) or delta <= 0.0:
		return
	_accumulator += minf(delta, 0.25)
	while _accumulator + 0.00000001 >= TICK:
		_accumulator = maxf(0.0, _accumulator - TICK)
		_advance()
		if _ended or _warning >= 0:
			_accumulator = 0.0
			return

func _advance() -> void:
	_ticks += 1
	_fuel = maxf(0.0, _fuel - 0.018 * TICK)
	var near_heat := _near_heat()
	var reservoir_goal := 0.43 + 0.42 * near_heat if _fuel > 0.0 else 0.28
	_residual_heat = lerpf(_residual_heat, reservoir_goal, 0.035 * TICK)
	for index in SKEWER_COUNT:
		var skewer := _skewers[index]
		if skewer.zone == SERVED:
			continue
		_heat_skewer(skewer, index, near_heat)
		_help_selected(skewer, index)
		if _assisted and not skewer.warned and skewer.zone == NEAR and _warning < 0 \
			and skewer.charred[skewer.down_face] >= _char_limit() * 0.72:
			skewer.warned = true
			_warning = index
			_feedback = "第 %d 串快焦了。轉面或移離近炭。" % (index + 1)
	if _ticks * TICK >= _seconds_limit():
		_ended = true
		_warning = -1
		_feedback = "收攤時間到，已上菜 %d / %d 串。" % [_served, SKEWER_COUNT]

func _heat_skewer(skewer: Skewer, index: int, near_heat: float) -> void:
	var remaining_face := _only_uncooked_face(skewer)
	var unfinished_before := remaining_face != ALL_COOKED
	var energy := 0.0
	match skewer.zone:
		NEAR: energy = near_heat * float(LAYOUTS[_layout].near[index])
		FAR: energy = _residual_heat * 0.77 * float(LAYOUTS[_layout].far[index])
	var mean_heat := 0.0
	for surface in skewer.heat:
		mean_heat += surface / FACE_COUNT
	var response := 1.75 / skewer.size
	for face in FACE_COUNT:
		var strength: float = INCIDENCE[posmod(face - skewer.down_face, FACE_COUNT)]
		var temperature := float(skewer.heat[face])
		var equilibrium := AMBIENT + energy * 0.93 * strength
		var diffusion := (mean_heat - temperature) * 0.16
		temperature = clampf(temperature + ((equilibrium - temperature) * response + diffusion) * TICK, 0.0, 1.0)
		skewer.heat[face] = temperature
		var improvement := maxf(0.0, temperature - 0.29) * 1.05 * TICK / skewer.size
		skewer.cooked[face] = minf(1.6, skewer.cooked[face] + improvement)
		if skewer.cooked[face] >= 0.88:
			var overheat := maxf(0.0, temperature - 0.68)
			var overcooked := maxf(0.0, skewer.cooked[face] - 1.08) * smoothstep(0.39, 0.82, temperature)
			skewer.charred[face] = minf(1.6, skewer.charred[face] + (overheat * 1.8 + overcooked * 1.3) * TICK)
	skewer.gloss = maxf(0.0, skewer.gloss - 2.3 * TICK)
	if skewer.zone in [NEAR, FAR] and skewer.cooked[skewer.down_face] >= 0.18:
		_handled_heat = true
	if unfinished_before and _uncooked_face_count(skewer) == 0:
		# This event is the actual final face crossing, not a zone check after plating.
		skewer.residual_finish = remaining_face == skewer.down_face and skewer.zone == FAR and energy > AMBIENT
		_last_finish_residual = skewer.residual_finish

func _help_selected(skewer: Skewer, index: int) -> void:
	if _helper != index or skewer.zone not in [NEAR, FAR] or skewer.gloss > 0.0:
		return
	var face := skewer.down_face
	if skewer.cooked[face] < _cook_target() or _uncooked_face_count(skewer) == 0 or _is_ruined(skewer):
		return
	_rotate(skewer)
	_note(9)
	_feedback = "輔助手轉了第 %d 串。移位與上菜由你決定。" % (index + 1)

func _rotate(skewer: Skewer) -> void:
	skewer.down_face = (skewer.down_face + 1) % FACE_COUNT
	skewer.gloss = 1.0

func _clear_warning() -> void:
	if _warning == _selected:
		_warning = -1

func _new_skewer(index: int) -> Skewer:
	var value := Skewer.new()
	var recipe: int = LAYOUTS[_layout].order[index]
	value.ingredient = INGREDIENTS[recipe]
	value.ingredient_id = INGREDIENT_IDS[recipe]
	value.size = LAYOUTS[_layout].sizes[index]
	return value

func _only_uncooked_face(skewer: Skewer) -> int:
	var last := ALL_COOKED
	var target := _cook_target()
	for index in FACE_COUNT:
		if skewer.cooked[index] < target:
			if last >= 0:
				return MULTIPLE_UNCOOKED
			last = index
	return last

func _uncooked_face_count(skewer: Skewer) -> int:
	var count := 0
	var target := _cook_target()
	for cooked_value in skewer.cooked:
		if cooked_value < target:
			count += 1
	return count

func _is_ruined(skewer: Skewer) -> bool:
	var limit := _char_limit()
	for charred_value in skewer.charred:
		if charred_value >= limit:
			return true
	return false

func _cook_target() -> float:
	return 0.90 if _assisted else 1.0

func _char_limit() -> float:
	return 1.15 if _assisted else 1.0

func _seconds_limit() -> float:
	return ASSISTED_SECONDS if _assisted else ROUND_SECONDS

func _near_heat() -> float:
	return 0.20 + 0.80 * sqrt(_fuel) if _fuel > 0.0 else _residual_heat * 0.30

func _face_status(skewer: Skewer, index: int) -> String:
	var char_score := skewer.charred[index]
	if char_score >= _char_limit():
		return "charred"
	if char_score >= _char_limit() * 0.68:
		return "danger"
	if skewer.cooked[index] >= _cook_target():
		return "ready"
	return "warming" if skewer.cooked[index] > 0.08 else "raw"

func _note(note: int) -> void:
	if _notes.size() < 8:
		_notes.append(note)

func consume_notes() -> Array[int]:
	var notes := _notes
	_notes = []
	return notes

func snapshot() -> Dictionary:
	var portions: Array[Dictionary] = []
	var active := 0
	for skewer in _skewers:
		var status: Array[String] = []
		for index in FACE_COUNT:
			status.append(_face_status(skewer, index))
		var ruined := _is_ruined(skewer)
		active += int(skewer.zone in [NEAR, FAR])
		portions.append({
			"ingredient": skewer.ingredient, "ingredient_id": skewer.ingredient_id,
			"size": skewer.size, "zone": skewer.zone,
			"down_face": skewer.down_face, "top_face": (skewer.down_face + 2) % FACE_COUNT,
			"heat": skewer.heat.duplicate(), "cook": skewer.cooked.duplicate(),
			"char": skewer.charred.duplicate(), "face_states": status,
			"serve_ready": skewer.zone != SERVED and not ruined and _uncooked_face_count(skewer) == 0,
			"ruined": ruined, "turn_gloss": skewer.gloss, "residual_finish": skewer.residual_finish,
		})
	var success := _served == SKEWER_COUNT
	var devil := success and _last_finish_residual and _refuels == 0
	var elapsed := _ticks * TICK
	return {
		"layout": _layout, "selected": _selected, "served": _served, "active": active,
		"refuels": _refuels, "fuel": _fuel, "near_heat": _near_heat(), "residual_heat": _residual_heat,
		"helper": _helper, "warning": _warning, "skewers": portions, "current": portions[_selected],
		"cook_target": _cook_target(), "char_limit": _char_limit(),
		"ended": _ended, "success": success, "devil": devil,
		"score": maxi(0, _served * SKEWER_POINTS + int(devil) * RESIDUAL_POINTS - _mistakes * LOSS_POINTS),
		"ordinary_eligible": _ended and _handled_heat, "assisted": _assisted, "mistakes": _mistakes,
		"elapsed": elapsed, "remaining": maxf(0.0, _seconds_limit() - elapsed), "feedback": _feedback,
	}
