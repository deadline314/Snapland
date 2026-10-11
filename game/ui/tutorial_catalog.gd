extends RefCounted
class_name TutorialCatalog
## Loads and validates the MAIN10 park and welcome-game tutorial catalog.

const DATA_PATH := "res://game/data/tutorials.json"
const SCREENSHOT_ROOT := "res://assets/ui/tutorials/"
const EXPECTED_LESSONS := ["park", "game-001", "game-002", "game-003", "game-004", "game-005", "game-006", "game-007", "game-008", "game-009", "game-010", "game-011", "game-012"]
const REQUIRED_STEP_FIELDS := ["id", "title", "image", "alt", "goal", "input", "success"]

var _lessons: Dictionary = {}
var _lesson_order: Array[String] = []
var _diagnostics: Array[String] = []

func _init(path: String = DATA_PATH) -> void:
	load_catalog(path)

func load_catalog(path: String = DATA_PATH) -> bool:
	_lessons.clear()
	_lesson_order.clear()
	_diagnostics.clear()
	if not FileAccess.file_exists(path):
		_diagnostics.append("tutorials: catalog file is missing: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_diagnostics.append("tutorials: catalog file could not be opened: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1:
		_diagnostics.append("tutorials: expected an object with schema_version 1")
		return false
	var lessons_value: Variant = parsed.get("lessons", null)
	if not lessons_value is Array:
		_diagnostics.append("tutorials: lessons must be an array")
		return false
	for index in range(lessons_value.size()):
		var lesson_value: Variant = lessons_value[index]
		if not lesson_value is Dictionary:
			_diagnostics.append("tutorials/lesson %d: expected an object" % index)
			continue
		var lesson: Dictionary = lesson_value
		var lesson_id := str(lesson.get("id", ""))
		var lesson_errors := _validate_lesson(lesson, lesson_id)
		for message in lesson_errors: _diagnostics.append(message)
		if lesson_errors.is_empty():
			if _lessons.has(lesson_id):
				_diagnostics.append("tutorials/%s: duplicate lesson id" % lesson_id)
			else:
				_lessons[lesson_id] = lesson.duplicate(true)
				_lesson_order.append(lesson_id)
	for expected_id in EXPECTED_LESSONS:
		if not _lessons.has(expected_id):
			_diagnostics.append("tutorials/%s: required lesson is missing or invalid" % expected_id)
	return _diagnostics.is_empty()

func lesson_ids() -> Array[String]:
	return _lesson_order.duplicate()

func get_lesson(lesson_id: String) -> Dictionary:
	var lesson: Variant = _lessons.get(lesson_id, {})
	return lesson.duplicate(true) if lesson is Dictionary else {}

func validation_report() -> Dictionary:
	return {"ok": _diagnostics.is_empty(), "lesson_count": _lessons.size(), "diagnostics": _diagnostics.duplicate()}

func _validate_lesson(lesson: Dictionary, lesson_id: String) -> Array[String]:
	var errors: Array[String] = []
	if lesson_id.is_empty():
		errors.append("tutorials/lesson: id is required")
		return errors
	var context := "tutorials/%s" % lesson_id
	for field in ["title", "goal", "ordinary", "bonus"]:
		if not lesson.get(field, "") is String or str(lesson.get(field, "")).strip_edges().is_empty():
			errors.append("%s: %s must be non-empty text" % [context, field])
	var steps_value: Variant = lesson.get("steps", null)
	if not steps_value is Array or steps_value.size() < 2 or steps_value.size() > 3:
		errors.append("%s: steps must contain two or three steps" % context)
		return errors
	var seen_steps: Dictionary = {}
	for index in range(steps_value.size()):
		var step_value: Variant = steps_value[index]
		if not step_value is Dictionary:
			errors.append("%s/step %d: expected an object" % [context, index + 1])
			continue
		var step: Dictionary = step_value
		var step_context := "%s/step %d" % [context, index + 1]
		var step_id := str(step.get("id", ""))
		for field in REQUIRED_STEP_FIELDS:
			if not step.get(field, "") is String or str(step.get(field, "")).strip_edges().is_empty():
				errors.append("%s: %s must be non-empty text" % [step_context, field])
		if step_id.is_empty():
			continue
		if seen_steps.has(step_id): errors.append("%s: duplicate step id '%s'" % [step_context, step_id])
		seen_steps[step_id] = true
		var image_path := str(step.get("image", ""))
		if not image_path.begins_with(SCREENSHOT_ROOT) or not image_path.ends_with(".png") or image_path.contains(".."):
			errors.append("%s: image must be a PNG under %s" % [step_context, SCREENSHOT_ROOT])
	return errors
