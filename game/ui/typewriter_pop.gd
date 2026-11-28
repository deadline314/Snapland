extends RichTextEffect
## Per-character pop for the dialogue typewriter: each newly revealed character
## rises a few pixels, grows past full size and settles, fading in on the way.
## The dialogue panel stamps the moment each index appears; characters revealed
## all at once by a skip are stamped as already settled. Spec:
## design/runtime/type-system.md. No-op under reduced motion and headless.

const PaperMotion = preload("res://game/ui/paper_motion.gd")

const POP_SECONDS := 0.18

var bbcode := "pop"
## Seconds on the panel's clock; the panel advances it every frame.
var now := 0.0
## Font size of the text, for the pivot each character grows around.
var font_size := 22
var _stamps := PackedFloat64Array()


func reset() -> void:
	_stamps.clear()


## Character `index` appeared at `at`; pass a time in the past to skip its pop.
func stamp(index: int, at: float) -> void:
	if index >= _stamps.size():
		var old := _stamps.size()
		_stamps.resize(index + 1)
		for fill in range(old, index + 1):
			_stamps[fill] = -100.0
	_stamps[index] = at


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	if not PaperMotion.enabled():
		return true
	var index := char_fx.relative_index
	if index < 0 or index >= _stamps.size():
		return true
	var age := now - _stamps[index]
	if age >= POP_SECONDS or age < 0.0:
		return true
	var t := age / POP_SECONDS
	# Up from slightly below, a small overshoot, then rest.
	var grow := lerpf(0.55, 1.0, t) + 0.22 * sin(t * PI)
	var pivot := Vector2(font_size * 0.5, -font_size * 0.38)
	char_fx.transform = char_fx.transform * Transform2D(0.0, Vector2(grow, grow), 0.0, pivot - pivot * grow)
	char_fx.offset += Vector2(0.0, 6.0 * (1.0 - t) * (1.0 - t))
	char_fx.color.a *= clampf(t * 2.5, 0.0, 1.0)
	return true
