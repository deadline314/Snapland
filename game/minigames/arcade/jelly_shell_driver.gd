extends "res://game/minigames/arcade/arcade_driver.gd"
## 果凍真身, the candy factory other space's finale (design/01-park/other-space.md §5c).
## Not a catalogue minigame: it earns no stickers and is started by the rift door.
##
## 啵啵 splits into wobbling jelly copies that hop over each other to swap
## places. All of them wobble to one beat except the real one, which runs half
## a beat late. ← → choose a jelly, the action key scoops it: the real one goes
## into a mould and the next round starts; a copy bursts and gums the
## traveller up for a moment, but the round goes on. Six moulds
## (two per act) finish the jelly cake; out of time and the copies wrap the traveller into a jelly.

const VIEW = preload("res://game/minigames/arcade/jelly_shell_view.gd")

const MOULDS := 6
## Per act: copies on stage (real one included), swaps, seconds per swap, lag.
const COUNTS := [3, 4, 5]
const SWAPS := [3, 5, 8]
const SWAP_SECONDS := [0.62, 0.5, 0.42]
const LAGS := [0.28, 0.2, 0.14]
const SPLIT_SECONDS := 1.4
const SCOOP_SECONDS := 1.3
const GOO_SECONDS := 1.6
const POP_SECONDS := 0.9
const FINALE_PHOTO := 1.6
const FINALE_END := 3.2
const JELLIED_SECONDS := 4.0
const JELLIED_PHOTO := 2.4

var moulds := 0
var wrong := 0
var cursor := 1
var round_phase := "split"
var round_at := 0.0
## Each jelly: {slot (where it ends up), from (where it started this swap), real, popped, popped_at}.
var jellies: Array[Dictionary] = []
## This round's swaps: [[slot a, slot b], ...]; swap i runs from shuffle start + i * swap seconds.
var swaps: Array = []
var flip_swap := -1
var goo_at := -99.0
var scoop_at := -99.0
var pick_at := 0.0
var phase := "show"
var phase_at := -99.0


func _init() -> void:
	verb = "盯住慢半拍的果凍，換位後把真身舀起來！"
	hint = [["← →", "選果凍"], ["空白鍵", "舀起"]]
	round_seconds = 120.0
	thresholds = [1200, 1550, 1800]
	verdicts = ["你被做成果凍了。", "果凍蛋糕完成！", "眼睛真利，啵啵都嚇到了。", "啵啵說你可以來當主廚。"]
	variants = [{"id": "strawberry", "label": "草莓"}, {"id": "lime", "label": "萊姆"}]
	score_label = "果凍"
	view_script = VIEW


func reset(assisted_mode: bool, clock_text: String) -> void:
	super.reset(assisted_mode, clock_text)
	round_seconds = 120.0 * clampf(round_scale, 0.1, 1.0)
	_refresh()


func score_summary(practice: bool) -> Dictionary:
	var summary := super.score_summary(practice)
	summary.rule = "六個模子都滿才有獎牌：銅 %d、銀 %d、金 %d 分。壓軸不發拍貼。" % thresholds
	summary.qualification_text = "練習回合不保存。" if practice else ""
	return summary


func medal() -> int:
	return super.medal() if moulds >= MOULDS else 0


func act() -> int:
	return 1 + mini(2, moulds / 2)


func lag() -> float:
	var seconds: float = LAGS[act() - 1]
	return seconds * 1.5 if assisted else seconds


func swap_seconds() -> float:
	var seconds: float = SWAP_SECONDS[act() - 1]
	return seconds * 1.4 if assisted else seconds


func slots() -> int:
	return jellies.size()


## The slot the real jelly is in (or will land in, mid-swap).
func real_slot() -> int:
	for jelly in jellies:
		if jelly.real:
			return int(jelly.slot)
	return -1


func can_pick() -> bool:
	return phase == "show" and round_phase == "pick" and clock - goo_at >= GOO_SECONDS


## Gravity flips during act three's shuffle: from that swap on, the jellies sit
## on the other side of the room.
func flipped() -> bool:
	if act() < 3 or flip_swap < 0:
		return false
	if round_phase in ["pick", "scoop"]:
		return true
	return round_phase == "shuffle" and clock - round_at >= flip_swap * swap_seconds()


## Where each jelly is drawn now: {x (slot, fractional mid-hop), lift (0..1 arc), real, popped, popped_age, move, t}.
func layout() -> Array:
	var out: Array = []
	var swap_index := -1
	var swap_u := 0.0
	if round_phase == "shuffle":
		var into := clock - round_at
		swap_index = int(into / swap_seconds())
		swap_u = fposmod(into, swap_seconds()) / swap_seconds()
	for jelly in jellies:
		var x := float(jelly.slot)
		var lift := 0.0
		var move := "wobble"
		var t := clock
		match round_phase:
			"split":
				var u := clampf((clock - round_at) / SPLIT_SECONDS, 0.0, 1.0)
				x = lerpf((slots() - 1) * 0.5, float(jelly.slot), smoothstep(0.25, 1.0, u))
				move = "split"
				t = clock - round_at
			"shuffle":
				if swap_index >= 0 and swap_index < swaps.size():
					var pair: Array = swaps[swap_index]
					if int(jelly.from) in pair:
						x = lerpf(float(jelly.from), float(jelly.slot), smoothstep(0.0, 1.0, swap_u))
						lift = sin(PI * swap_u) * (1.0 if int(jelly.from) == int(pair[0]) else 0.55)
						move = "hop"
						t = swap_u * 0.95
			"scoop":
				if jelly.real:
					move = "scooped"
					t = clock - scoop_at
		# The tell: the real one lives a little in the past.
		if jelly.real and move in ["wobble", "hop"]:
			t = maxf(0.0, t - (lag() / swap_seconds() * 0.95 if move == "hop" else lag()))
		if jelly.popped:
			move = "pop"
			t = clock - float(jelly.popped_at)
		out.append({"x": x, "lift": lift, "real": jelly.real, "popped": jelly.popped, "popped_age": clock - float(jelly.popped_at), "move": move, "t": t})
	return out


# --- Round ------------------------------------------------------------------

func _begin_round(_variant: Dictionary) -> void:
	moulds = 0
	wrong = 0
	goo_at = -99.0
	scoop_at = -99.0
	phase = "show"
	phase_at = -99.0
	_start_round()


## The countdown shows a split and a shuffle; picks wait for play.
func _warm_up(_delta: float) -> void:
	if round_phase in ["split", "shuffle"]:
		_advance_round()


func _go() -> void:
	_start_round()


## A fresh round: split from the middle, real one holding the ladle, then swaps.
func _start_round() -> void:
	var count: int = COUNTS[act() - 1]
	jellies.clear()
	var real := rng.randi_range(0, count - 1)
	for slot in count:
		jellies.append({"slot": slot, "from": slot, "real": slot == real, "popped": false, "popped_at": -99.0})
	cursor = clampi(count / 2, 0, count - 1)
	swaps.clear()
	var last := [-1, -1]
	for i in SWAPS[act() - 1]:
		var a := rng.randi_range(0, count - 2)
		var b := a + 1 if rng.randf() < 0.7 or count < 3 else mini(count - 1, a + 2)
		# Bias toward moving the real one so the shuffle is worth watching.
		if i % 2 == 0 and rng.randf() < 0.6:
			var at := _slot_after(real, i)
			a = clampi(at - 1 if at > 0 and rng.randf() < 0.5 else at, 0, count - 2)
			b = a + 1
		if [a, b] == last:
			a = (a + 1) % (count - 1)
			b = a + 1
		swaps.append([a, b])
		last = [a, b]
	flip_swap = SWAPS[2] / 2 if act() >= 3 else -1
	_swap_started = -1
	round_phase = "split"
	round_at = clock


## Where the jelly that started in `start` sits after the first `count` swaps.
func _slot_after(start: int, count: int) -> int:
	var at := start
	for i in count:
		var pair: Array = swaps[i]
		if at == int(pair[0]):
			at = int(pair[1])
		elif at == int(pair[1]):
			at = int(pair[0])
	return at


func _tick(_delta: float) -> void:
	match phase:
		"show":
			_advance_round()
			if round_seconds - play_time <= JELLIED_SECONDS and moulds < MOULDS:
				phase = "jellied"
				phase_at = clock
		"jellied":
			if clock - phase_at >= 1.4 and fail_at < 0.0:
				funny_fail("噗啾！被包成果凍了", false)
				sound(45)
		"finale":
			if clock - phase_at >= FINALE_END:
				play_time = round_seconds


func _advance_round() -> void:
	match round_phase:
		"split":
			if clock - round_at >= SPLIT_SECONDS:
				round_phase = "shuffle"
				round_at = clock
				_begin_swap(0)
		"shuffle":
			var index := int((clock - round_at) / swap_seconds())
			if index >= swaps.size():
				round_phase = "pick"
				round_at = clock
				pick_at = clock
				for jelly in jellies:
					jelly.from = jelly.slot
			else:
				_begin_swap(index)
		"scoop":
			if clock - scoop_at >= SCOOP_SECONDS:
				if moulds >= MOULDS:
					phase = "finale"
					phase_at = clock
					round_phase = "done"
				else:
					_start_round()


var _swap_started := -1


## Commit swap `index` once: the two jellies trade their landing slots.
func _begin_swap(index: int) -> void:
	if index == _swap_started:
		return
	_swap_started = index
	for jelly in jellies:
		jelly.from = jelly.slot
	var pair: Array = swaps[index]
	for jelly in jellies:
		if int(jelly.from) == int(pair[0]):
			jelly.slot = int(pair[1])
		elif int(jelly.from) == int(pair[1]):
			jelly.slot = int(pair[0])
	sound(62 + index % 4)


func _press(button: StringName) -> void:
	match button:
		&"left", &"right":
			if phase != "show":
				return
			cursor = clampi(cursor + (-1 if button == &"left" else 1), 0, slots() - 1)
			sound(70)
		&"action":
			_scoop()


func _scoop() -> void:
	if not can_pick():
		return
	for jelly in jellies:
		if int(jelly.slot) != cursor or jelly.popped:
			continue
		if jelly.real:
			moulds += 1
			add_score(200 + roundi(maxf(0.0, 100.0 - (clock - pick_at) * 25.0)), "舀到了！")
			sound(84)
			round_phase = "scoop"
			scoop_at = clock
		else:
			jelly.popped = true
			jelly.popped_at = clock
			wrong += 1
			goo_at = clock
			say("假的！噗——", false)
			sound(40)
		return


func _round_over() -> void:
	if moulds >= MOULDS:
		add_score(roundi(maxf(0.0, round_seconds - play_time)) - wrong * 10)


func _snapshot(into: Dictionary) -> void:
	into.jellies = layout()
	into.cursor = cursor
	into.slots = slots()
	into.round_phase = round_phase
	into.round_age = clock - round_at
	into.moulds = moulds
	into.act = act()
	into.flipped = flipped()
	into.goo_at = goo_at
	into.scoop_at = scoop_at
	into.can_pick = can_pick()
	into.phase = phase
	into.phase_at = phase_at
	into.photo_ready = (phase == "finale" and clock - phase_at >= FINALE_PHOTO) or (phase == "jellied" and clock - phase_at >= JELLIED_PHOTO)
	into.cleared = moulds >= MOULDS
	into.progress_text = "模子 %d / %d" % [moulds, MOULDS]
