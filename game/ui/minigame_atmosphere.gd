extends Control
## Shared scene life and feedback for every minigame, old or new.
##
## It sits between the game picture and the HUD and needs nothing from the
## individual game: the session reports score, mistakes and the ending, and this
## layer answers with light, drifting motes, an edge glow, a shake and confetti.
## Everything is decoration; rules, timing and input never read from it.

const PaperMotion = preload("res://game/ui/paper_motion.gd")
const AIR_SHADER := preload("res://game/ui/minigame_atmosphere.gdshader")

## Per-zone air. Add a zone here to theme its games; unknown zones use "welcome".
const THEMES := {
	"welcome": {"mote": Color("#fff3c4"), "shaft": Color("#fff1c9"), "drift": Vector2(14.0, -6.0), "count": 26},
	"harbor": {"mote": Color("#dff7f2"), "shaft": Color("#d9f4ff"), "drift": Vector2(22.0, 4.0), "count": 24},
	"candy": {"mote": Color("#ffd9e8"), "shaft": Color("#ffe3c9"), "drift": Vector2(6.0, -12.0), "count": 30},
	"nightmarket": {"mote": Color("#ffb46a"), "shaft": Color("#ffb46a"), "drift": Vector2(4.0, -26.0), "count": 30},
	"circus": {"mote": Color("#ffe6a8"), "shaft": Color("#ffc98a"), "drift": Vector2(-8.0, 10.0), "count": 28},
	"toy": {"mote": Color("#ffe1b2"), "shaft": Color("#ffd9a0"), "drift": Vector2(10.0, 6.0), "count": 22},
	"garden": {"mote": Color("#dcff8a"), "shaft": Color("#bfe6cf"), "drift": Vector2(-6.0, -8.0), "count": 18},
}
## Light by time of day: [shaft strength, vignette strength, mote alpha].
const PHASE_LIGHT := {
	"dawn": [0.09, 0.22, 0.55],
	"noon": [0.1, 0.2, 0.5],
	"dusk": [0.11, 0.27, 0.6],
	"night": [0.05, 0.3, 0.85],
}
const SCORE_FLASH := Color("#ffd166")
const MISTAKE_FLASH := Color("#ff6f7d")
const WIN_FLASH := Color("#70e1c1")
const CONFETTI_COLORS: Array[Color] = [Color("#ffd166"), Color("#70e1c1"), Color("#ff83aa"), Color("#79bdff"), Color("#fff5dc")]
const MAX_MOTES := 32
const CONFETTI_COUNT := 44
const CONFETTI_SECONDS := 1.5
const FLASH_FADE_PER_SECOND := 2.6
const TRAUMA_FADE_PER_SECOND := 3.2
const MAX_SHAKE_PIXELS := 9.0
const STATIC_FLASH_SECONDS := 0.4

var _air: ColorRect
var _material: ShaderMaterial
var _theme: Dictionary = THEMES["welcome"]
var _mote_alpha := 0.45
var _clock := 0.0
var _flash := 0.0
var _static_flash_left := 0.0
var _trauma := 0.0
var _confetti_age := -1.0
var _frozen := false
var _reduced_motion := false
var _shake := Vector2.ZERO


func _init() -> void:
	name = "MinigameAtmosphere"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_air = ColorRect.new()
	_air.name = "Air"
	_air.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = AIR_SHADER
	_air.material = _material
	add_child(_air)
	resized.connect(_sync_aspect)


## Theme the air for a zone ("welcome", "harbor", …) and a time phase.
func configure(zone: String, phase: String, reduced_motion: bool) -> void:
	_theme = THEMES.get(zone, THEMES["welcome"])
	var light: Array = PHASE_LIGHT.get(phase, PHASE_LIGHT["noon"])
	_mote_alpha = float(light[2])
	_reduced_motion = reduced_motion
	_material.set_shader_parameter("shaft_color", _theme["shaft"])
	_material.set_shader_parameter("shaft_strength", float(light[0]))
	_material.set_shader_parameter("vignette_strength", float(light[1]))
	reset()


## Clear every running effect (new round, retry).
func reset() -> void:
	_flash = 0.0
	_static_flash_left = 0.0
	_trauma = 0.0
	_confetti_age = -1.0
	_shake = Vector2.ZERO
	_material.set_shader_parameter("flash_amount", 0.0)
	_sync_aspect()
	queue_redraw()


## Freeze while the round is paused or over.
func set_frozen(value: bool) -> void:
	_frozen = value


func score_gained() -> void:
	_start_flash(SCORE_FLASH, 0.5)


func mistake_made() -> void:
	_start_flash(MISTAKE_FLASH, 0.62)
	if PaperMotion.enabled():
		_trauma = minf(1.0, _trauma + 0.55)


func round_finished(success: bool) -> void:
	_start_flash(WIN_FLASH if success else MISTAKE_FLASH, 0.8)
	if success and PaperMotion.enabled():
		_confetti_age = 0.0


## Pixel offset the session adds to the game picture; zero when calm.
func shake_offset() -> Vector2:
	return _shake


func _start_flash(color: Color, amount: float) -> void:
	_material.set_shader_parameter("flash_color", color)
	_flash = amount
	# Without motion the glow holds still briefly instead of pulsing out.
	_static_flash_left = STATIC_FLASH_SECONDS if not PaperMotion.enabled() else 0.0
	_material.set_shader_parameter("flash_amount", _flash)


func _sync_aspect() -> void:
	_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))


func _process(delta: float) -> void:
	var step := clampf(delta, 0.0, 0.1)
	var moving := PaperMotion.enabled() and not _reduced_motion
	if _flash > 0.0:
		if _static_flash_left > 0.0:
			_static_flash_left -= step
			if _static_flash_left <= 0.0:
				_flash = 0.0
		else:
			_flash = maxf(0.0, _flash - step * FLASH_FADE_PER_SECOND)
		_material.set_shader_parameter("flash_amount", _flash)
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - step * TRAUMA_FADE_PER_SECOND)
		# Squared trauma: light knocks barely move, heavy ones land.
		var strength := _trauma * _trauma * MAX_SHAKE_PIXELS
		_shake = Vector2(sin(_clock * 71.0), cos(_clock * 89.0)) * strength
	elif _shake != Vector2.ZERO:
		_shake = Vector2.ZERO
	if _confetti_age >= 0.0:
		_confetti_age += step
		if _confetti_age > CONFETTI_SECONDS:
			_confetti_age = -1.0
		queue_redraw()
	if moving and (not _frozen or _confetti_age >= 0.0 or _trauma > 0.0):
		_clock += step
		_material.set_shader_parameter("clock", _clock)
		queue_redraw()


func _draw() -> void:
	if not PaperMotion.has_display():
		return
	var mote_color: Color = _theme["mote"]
	var drift: Vector2 = _theme["drift"]
	var count := mini(int(_theme["count"]), MAX_MOTES)
	var area := size
	if area.x < 1.0 or area.y < 1.0:
		return
	for index in count:
		var key := float(index) * 12.9898
		var start := Vector2(fposmod(sin(key) * 43758.5453, 1.0), fposmod(sin(key * 1.7) * 24634.6345, 1.0)) * area
		var wobble := Vector2(sin(_clock * 0.7 + key), cos(_clock * 0.5 + key * 1.3)) * 9.0
		var point := (start + drift * _clock + wobble).posmodv(area)
		var twinkle := 0.55 + 0.45 * sin(_clock * 1.6 + key * 2.1)
		var side := 2.0 + float(index % 3)
		draw_rect(Rect2(point.floor(), Vector2(side, side)), Color(mote_color, _mote_alpha * twinkle * 0.6))
	if _confetti_age >= 0.0:
		var fade := 1.0 - smoothstep(CONFETTI_SECONDS * 0.6, CONFETTI_SECONDS, _confetti_age)
		for index in CONFETTI_COUNT:
			var key := float(index) * 7.31
			var launch := Vector2(fposmod(sin(key) * 9173.13, 1.0) * area.x, -20.0 - fposmod(sin(key * 3.3) * 311.7, 1.0) * 120.0)
			var fall := Vector2(sin(key * 2.0 + _confetti_age * 5.0) * 26.0, (260.0 + fposmod(sin(key * 5.1) * 77.7, 1.0) * 320.0) * _confetti_age)
			var flip := absf(sin(_confetti_age * 9.0 + key))
			draw_rect(Rect2((launch + fall).floor(), Vector2(8.0, 3.0 + 6.0 * flip)), Color(CONFETTI_COLORS[index % CONFETTI_COLORS.size()], fade))
