extends RefCounted
## Everything in the night market that moves by hand rather than by shader: the
## rotisserie, the standing fans, the turning oil-paper umbrella and the lucky cat
## that beckons harder when the player comes near. Nothing here is saved or
## scored, and the reduced-motion pose is still.

const Scenery := preload("res://game/world/nightmarket_scenery.gd")
## The cat notices a visitor this close (metres on the ground).
const CAT_NOTICE := 3.4
const CAT_REST := 0.12
const CAT_GREETING := 0.75

var world: Node3D
var scenery: Scenery
## True while the cat is greeting the player.
var cat_excited := false
var _cat_phase := 0.0

func _init(owner: Node3D, market_scenery: Scenery) -> void:
	world = owner
	scenery = market_scenery

func animate(delta: float) -> void:
	scenery.spit.rotate_object_local(Vector3.BACK, delta * 1.4)
	for fan in scenery.fans:
		fan.rotate_object_local(Vector3.BACK, delta * 9.0)
	scenery.parasol_spinner.rotate_y(delta * 0.5)
	_notice_player()
	# A slow beckon for nobody in particular; a quick wave for a visitor.
	_cat_phase = fposmod(_cat_phase + delta * (10.0 if cat_excited else 2.4), TAU)
	scenery.cat_arm.rotation.z = (CAT_GREETING if cat_excited else CAT_REST) * 0.5 + sin(_cat_phase) * (0.42 if cat_excited else 0.16)

## Reduced motion: nothing turns, and the cat simply holds its paw up for a visitor.
func hold_still() -> void:
	_notice_player()
	scenery.cat_arm.rotation.z = CAT_GREETING if cat_excited else CAT_REST

func _notice_player() -> void:
	var player: Node3D = world.player
	if not is_instance_valid(player):
		cat_excited = false
		return
	var away := player.position - scenery.cat_arm.position
	cat_excited = away.x * away.x + away.z * away.z < CAT_NOTICE * CAT_NOTICE
