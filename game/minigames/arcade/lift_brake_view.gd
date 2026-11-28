extends "res://game/minigames/arcade/arcade_view.gd"
## Picture for 電梯借重: the hotel hall at night (hotel_backdrop) cut away to
## show a five-floor lift shaft: dark wood floor slabs with brass floor plates,
## a brass cage car on its cable with the traveller at the controls in a red
## bellhop cap, ghost guests riding along with their floor above their heads,
## and more ghosts waiting on the landings beside lit call lamps, a ring of
## patience round each. Accordion gates fold open on level stops. Stop between
## floors and a guest steps out with little feet dangling over the gap while
## the gate pinches the cap off the traveller's head. Every object is baked
## pixel art.

const Hero = preload("res://game/minigames/arcade/arcade_hero.gd")
const Hotel = preload("res://game/minigames/arcade/hotel_backdrop.gd")
const GROUND_Y := 632.0
const STOREY := 100.0
const SHAFT := Rect2(560, 150, 170, 492)
const CAR := Vector2i(42, 22)
const BRASS := Color("#d9a64e")
const SLAB := Color("#4a3046")
const CAP := Color("#c0485e")
const NIGHT_TINT := Color(0.95, 0.94, 1.04)
const GUEST_TINTS: Array[Color] = [Color(1, 1, 1), Color(1.0, 0.92, 0.96), Color(0.92, 0.96, 1.0), Color(0.96, 1.0, 0.92)]

var _car: ImageTexture
var _gate: ImageTexture
var _cap: ImageTexture
var _lamp: ImageTexture


func _init() -> void:
	super()
	word_anchor = Vector2(340, 236)


func _ready() -> void:
	_car = Pixels.bake("lb-car", CAR, _paint_car)
	_gate = Pixels.bake("lb-gate", Vector2i(40, 21), _paint_gate)
	_cap = Pixels.bake("lb-cap", Vector2i(10, 5), _paint_cap)
	_lamp = Pixels.bake("lb-lamp", Vector2i(7, 9), _paint_lamp)


func _draw_backdrop() -> void:
	Hotel.draw(self, now, reduced_motion)
	vignette(0.3)


func _draw_scene() -> void:
	if not state.has("car"):
		return
	_draw_shaft()
	_draw_floors()
	_draw_waiting()
	_draw_car()
	var streak := int(state.get("streak", 0))
	if streak >= 3:
		label(Vector2(1110, 200), "連停 × %d" % streak, 26, GOLD, 1.0 + 0.08 * pulse(2.0))


func _floor_y(storey: float) -> float:
	return GROUND_Y - storey * STOREY


# --- The shaft and the floors -------------------------------------------------------

func _draw_shaft() -> void:
	draw_rect(Rect2(SHAFT.position + Vector2(10, 10), SHAFT.size), Color(Props.SHADOW, 0.4))
	draw_rect(SHAFT, Color("#1d1426"))
	# Brass guide rails and the hanging cable.
	for side: float in [SHAFT.position.x + 10.0, SHAFT.end.x - 18.0]:
		panel(Rect2(side, SHAFT.position.y, 8, SHAFT.size.y), "pole", BRASS.darkened(0.25))
	var top := _floor_y(float(state.car)) - CAR.y * TEXEL
	draw_rect(Rect2(SHAFT.get_center().x - 3.0, SHAFT.position.y, 6, top - SHAFT.position.y), Color("#3a3040"))
	draw_rect(Rect2(SHAFT.get_center().x - 1.0, SHAFT.position.y, 2, top - SHAFT.position.y), Color("#6a6070"))


func _draw_floors() -> void:
	var floors := int(state.get("floors", 5))
	for storey in floors:
		var y := _floor_y(storey)
		# The floor slab either side of the shaft, and its brass number plate.
		for part: Rect2 in [Rect2(300, y, SHAFT.position.x - 300.0, 16), Rect2(SHAFT.end.x, y, 1180.0 - SHAFT.end.x, 16)]:
			draw_rect(Rect2(part.position + Vector2(0, 16), Vector2(part.size.x, 8)), Color(Props.SHADOW, 0.3))
			panel(part, "planks", SLAB)
		var sign_rect := Rect2(SHAFT.position.x - 70.0, y - 64.0, 52, 34)
		plate(sign_rect, Color("#c9953e"), Color("#8a6030"))
		label(sign_rect.get_center() + Vector2(0, 1), "%dF" % (storey + 1), 18, GOLD)
		# A closed accordion gate on every floor the car is not at.
		if absf(float(state.car) - storey) > 0.95:
			stamp(_gate, Vector2(SHAFT.position.x + 4.0, y - _gate.get_height() * TEXEL + 4.0), TEXEL, Color(NIGHT_TINT, 0.85))


func _draw_waiting() -> void:
	for guest: Dictionary in state.get("waiting", []):
		var storey := int(guest.floor)
		var y := _floor_y(storey)
		var lamp_at := Vector2(SHAFT.end.x + 14.0, y - 92.0)
		draw_circle(lamp_at + Vector2(14, 16), 26.0, Color(1.0, 0.85, 0.5, 0.25 + 0.15 * pulse(1.5)))
		stamp(_lamp, lamp_at, TEXEL, NIGHT_TINT)
		var left := 1.0 - age(float(guest.at)) / maxf(0.1, float(guest.patience))
		var rush := bool(guest.rush)
		var bob := 0.0 if reduced_motion else 4.0 * sin(now * (6.0 if rush else 2.0) + storey)
		var at := Vector2(SHAFT.end.x + 80.0, y - 50.0 + bob)
		var sprite := Hotel.ghost("oops" if left < 0.3 else ("cheeky" if rush else "plain"))
		var size := Vector2(sprite.get_size()) * 3.5
		ground_shadow(Vector2(at.x, y + 2.0), Vector2(22, 5), 0.25)
		stamp(sprite, at - size * 0.5, 3.5, GUEST_TINTS[storey % GUEST_TINTS.size()])
		# A ring of patience running down round the guest.
		draw_arc(at, 40.0, -PI * 0.5, -PI * 0.5 + TAU * left, 32, Color(GOLD if left > 0.3 else ROSE, 0.85), 5.0)
		if rush:
			label(at + Vector2(40, -38), "快！", 22, ROSE, 1.0 + 0.1 * pulse(3.0))


# --- The car ---------------------------------------------------------------------------

func _draw_car() -> void:
	var car := float(state.car)
	var floor_y := _floor_y(car)
	var size := Vector2(CAR) * TEXEL
	var at := Vector2(SHAFT.get_center().x - size.x * 0.5, floor_y - size.y)
	var stop: Dictionary = state.get("stop", {})
	var since := age(float(stop.get("at", -99.0))) if not stop.is_empty() else 99.0
	var pinch := age(float(state.get("pinch_at", -99.0)))
	var pinching := pinch >= 0.0 and pinch < float(state.get("pinch_seconds", 1.6))
	var doors := since >= 0.0 and since < (float(state.get("pinch_seconds", 1.6)) if pinching else float(state.get("doors_seconds", 0.9)))
	stamp(_car, at, TEXEL, NIGHT_TINT)
	# Riders: ghost guests with the floor each wants floating overhead.
	var riders: Array = state.get("riders", [])
	for index in riders.size():
		var rider: Dictionary = riders[index]
		var spot := at + Vector2(26.0 + index * 34.0 + (60.0 if index >= 2 else 0.0), size.y - 46.0)
		var sprite := Hotel.ghost("happy" if bool(rider.rush) else "plain")
		stamp(sprite, spot - Vector2(sprite.get_size()) * 1.25, 2.5, GUEST_TINTS[(index + 1) % GUEST_TINTS.size()])
		label(spot + Vector2(0, -34), "%dF" % (int(rider.to) + 1), 15, ROSE if bool(rider.rush) else CREAM)
	# The traveller at the controls, in a red bellhop cap.
	var feet := Vector2(at.x + size.x * 0.5, floor_y - 6.0)
	var mood := "shocked" if pinching else ("tongue" if doors and bool(stop.get("level", false)) and int(stop.get("left", 0)) > 0 else "plain")
	var hero := Hero.texture(&"idle", true, mood)
	var scale_factor := 1.9
	stamp(hero, feet + Vector2(-Hero.FEET.x, -Hero.FEET.y) * scale_factor + Vector2(scale_factor, scale_factor), scale_factor, NIGHT_TINT)
	var head := feet + Vector2(0, -44.0 * scale_factor)
	if not pinching:
		stamp(_cap, head + Vector2(-20, -8), TEXEL, NIGHT_TINT)
	# The car's own gate: folded open on a stop, closed while it runs.
	var gate_x := SHAFT.position.x + 4.0
	var gate := Vector2(gate_x, floor_y - _gate.get_height() * TEXEL + 4.0)
	var open := 0.0
	if doors:
		open = 1.0 if reduced_motion else clampf(minf(since / 0.2, (float(state.get("pinch_seconds", 1.6) if pinching else state.get("doors_seconds", 0.9)) - since) / 0.2), 0.0, 1.0)
	var gate_size := Vector2(_gate.get_size()) * TEXEL
	# The car's own gate is see-through, so the riders show while it runs.
	draw_texture_rect(_gate, Rect2(gate + Vector2(gate_size.x * open * 0.8, 0), Vector2(gate_size.x * (1.0 - open * 0.8), gate_size.y)), false, Color(NIGHT_TINT, 0.45))
	if braking_sparks():
		for spark in 4:
			var side := SHAFT.position.x + 12.0 if spark % 2 == 0 else SHAFT.end.x - 14.0
			draw_rect(Rect2(side - 3.0, at.y + 10.0 + spark * 6.0, 6, 3), Color(GOLD, 0.8))
	if pinching:
		_draw_pinch(at, size, head, float(stop.get("offset", 0.0)), pinch)


func braking_sparks() -> bool:
	return bool(state.get("braking", false)) and absf(float(state.get("velocity", 0.0))) > 0.4 and not reduced_motion and int(now * 20.0) % 2 == 0


## Stopped between floors: a guest steps half out with little feet dangling
## over the gap, and the gate has the traveller's cap pinched in it.
func _draw_pinch(at: Vector2, size: Vector2, head: Vector2, offset: float, since: float) -> void:
	var landing := _floor_y(roundf(float(state.car)))
	var gap := Rect2(SHAFT.end.x - 30.0, minf(landing, _floor_y(float(state.car))), 60, absf(offset) * STOREY + 4.0)
	draw_rect(gap, Color("#120c18"))
	var swing := 0.0 if reduced_motion else 0.6 * sin(since * 10.0)
	var ghost_at := Vector2(SHAFT.end.x + 4.0, gap.position.y - 34.0)
	var sprite := Hotel.ghost("oops")
	stamp(sprite, ghost_at - Vector2(sprite.get_size()) * 1.75, 3.5, Color.WHITE)
	for foot in 2:
		var hip := ghost_at + Vector2(-8.0 + foot * 16.0, 26.0)
		var toe := hip + Vector2(0, 22).rotated(swing * (1.0 if foot == 0 else -1.0))
		draw_line(hip, toe, Color("#eef0ff"), 5.0)
		draw_circle(toe, 6.0, Color("#c0485e"))
	# The cap caught in the folding gate, tugged up and away.
	var tug := 0.0 if reduced_motion else 6.0 * sin(since * 14.0)
	var cap_at := Vector2(SHAFT.position.x + 18.0, head.y - 26.0 + tug)
	stamp(_cap, cap_at, TEXEL, NIGHT_TINT)
	draw_line(head + Vector2(-10, -4), cap_at + Vector2(16, 18), Color(CREAM, 0.6), 2.0)
	label(head + Vector2(46, -30), "！", 30, GOLD)


# --- Texel painters ---------------------------------------------------------------

## A brass cage lift car: a lit roof with a little lamp, lattice sides and a
## polished wood floor.
func _paint_car(x: int, y: int) -> Color:
	if y < 3:
		if y == 0 and (x < 18 or x > 23):
			return Pixels.CLEAR
		return Pixels.lit(BRASS, 0.6 - y * 0.4, x, y)
	if y >= CAR.y - 3:
		return Pixels.wood(Color("#8a5a3a"), x, y, 7, false) if y < CAR.y - 1 else Color("#4a2a20")
	if x < 2 or x > CAR.x - 3:
		return Pixels.lit(BRASS, 0.4 if x < 2 else -0.4, x, y)
	if (x + y) % 6 == 0 and (x < 6 or x > CAR.x - 7):
		return BRASS.darkened(0.2)
	if y == 3:
		return BRASS.darkened(0.4)
	return Color("#2a2034").lerp(Color("#3a2c48"), float(y) / CAR.y)


## A folding brass gate: diagonal lattice between two posts.
func _paint_gate(x: int, y: int) -> Color:
	if x < 2 or x > 37:
		return Pixels.lit(BRASS, 0.5 if x < 2 else -0.5, x, y)
	if posmod(x + y, 6) == 0 or posmod(x - y, 6) == 0:
		return BRASS.darkened(0.15)
	return Pixels.CLEAR


## A red bellhop cap with a gold band and a little peak.
func _paint_cap(x: int, y: int) -> Color:
	if y == 4:
		return Color("#2a2034") if x >= 2 and x <= 9 else Pixels.CLEAR
	if x < 1 or x > 8:
		return Pixels.CLEAR
	if y == 3:
		return BRASS
	return Pixels.lit(CAP, 0.5 - y * 0.3, x, y)


## A brass call lamp with a glowing bulb.
func _paint_lamp(x: int, y: int) -> Color:
	var bulb := Vector2(x - 3.0, y - 3.5).length()
	if bulb < 2.6:
		return Color("#ffe8a8") if bulb < 1.6 else Color("#ffc86a")
	if y > 6 and x >= 1 and x <= 5:
		return Pixels.lit(BRASS, 0.3, x, y)
	return Pixels.CLEAR
