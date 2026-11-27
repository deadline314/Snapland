extends Node3D
## One instant map game. A subclass builds its props once and supplies the
## rules; the field layer owns the stand, countdown, clock, medals, saving,
## result and HUD. Rules read the player position they are given and never
## touch physics, so a round can be replayed step by step in a test.

const Kit = preload("res://game/world/field/field_kit.gd")

var world: Node3D
var field: Node3D
var spec: Dictionary = {}
var rng := RandomNumberGenerator.new()
var score := 0
var elapsed := 0.0
var seconds := 30.0
## Set by finish() when a round ends before the clock runs out.
var finished := false


func setup(owner_world: Node3D, owner_field: Node3D, row: Dictionary) -> void:
	world = owner_world
	field = owner_field
	spec = row
	seconds = float(row.get("seconds", 30.0))
	name = String(row.id).to_pascal_case()
	build()
	reset()


## Create every node this game will ever need.
func build() -> void:
	pass


## The countdown starts: show anything the player should look at first.
func ready_up() -> void:
	pass


## A round starts (after the countdown).
func begin() -> void:
	pass


## Advance the rules by one step with the player's current position.
func step(_delta: float, _player: Vector3) -> void:
	pass


## The interact key during a round. Only games with an action_label() get it.
func press() -> void:
	pass


## One or two words shown beside the interact key, or "" when it is unused.
func action_label() -> String:
	return ""


## The round is over: start the win or fail show for this medal (0 = none).
func conclude(_medal: int) -> void:
	pass


## Animate the show while the result is on screen.
func show_step(_delta: float, _player: Vector3) -> void:
	pass


## Put every round prop away (after the result, or when the player leaves).
func reset() -> void:
	pass


func comment(medal: int) -> String:
	var lines: Array = spec.get("lines", [])
	return String(lines[clampi(medal, 0, lines.size() - 1)]) if not lines.is_empty() else ""


func centre() -> Vector3:
	var at: Vector3 = spec.get("arena", spec.at)
	return Vector3(at.x, world.ground_surface_y(at), at.z)


## A layout offset from the table as a point on the ground.
func spot(offset: Vector2) -> Vector3:
	var at: Vector3 = spec.get("arena", spec.at)
	var point := Vector3(at.x + offset.x, 0.0, at.z + offset.y)
	point.y = world.ground_surface_y(point)
	return point


## 0 at the start of the round, 1 at the end: drives the escalating pace.
func pace() -> float:
	return clampf(elapsed / maxf(seconds, 0.001), 0.0, 1.0)


func reduced() -> bool:
	return world.reduced_motion


func add_score(points: int) -> void:
	score += points


func finish() -> void:
	finished = true


func note(index: int) -> void:
	field.note_requested.emit(posmod(index, 4))


func feedback(kind: String) -> void:
	field.feedback_requested.emit(kind)


## Lift the avatar's picture for a moment; collision and footing are untouched.
func hop(height: float, duration: float, repeats := 1) -> void:
	field.hop(height, duration, repeats)


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
