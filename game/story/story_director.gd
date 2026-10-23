extends RefCounted

const TimeOfDay = preload("res://game/core/time_of_day.gd")
const STORY_DATA_PATH := "res://game/data/first_park_story.json"
const REQUIRED_CHARACTER_IDS := ["ticket", "imp", "announcer"]
const ALLOWED_SPEAKERS := ["票票", "小角", "阿浪", "主角"]
## Conversation conditions. Each listed atom adds one point of salience.
const CONVERSATION_CONDITIONS := ["story_photo", "steps", "complete", "incomplete", "started_any", "time_phase"]
const QUEST_IDS := ["quest-001", "quest-002"]
const QUEST_STEP_COUNT := 3

# Keep the original three-step quiz data available to existing main.gd callers.
const QUESTS: Dictionary = {
	"quest-001": {
		"id": "quest-001", "title": "小角的尾巴彩帶試拍", "photo_id": "photo-welcome-quest-1",
		"steps": [
			{"prompt": "小角想把哪個小失誤變成新構圖靈感？", "options": ["打結尾巴的樣子", "地上的腳印", "入口旗幟"], "correct": 0, "feedback": "把打結的樣子想成彩帶主題，先試拍看看。"},
			{"prompt": "要先確認新構圖是否好拍，可以怎麼做？", "options": ["用玩家自己的角色試拍", "蓋住人物的臉", "把相機收起來"], "correct": 0, "feedback": "先用自己的角色確認取景流程，再決定構圖。"},
			{"prompt": "最後要怎麼留下這張合照？", "options": ["選個姿勢再按快門", "等尾巴自己打蝴蝶結", "請票票寄存相機"], "correct": 0, "feedback": "試拍完成，小角有了調整構圖的參考。"}
		]
	},
	"quest-002": {
		"id": "quest-002", "title": "廣播即興救場", "photo_id": "photo-welcome-quest-2",
		"steps": [
			{"prompt": "阿浪剛才把入口說成哪裡？", "options": ["出口", "海底", "員工休息室"], "correct": 0, "feedback": "沒錯，入口出口只差一個方向，差點把大家送回港口。"},
			{"prompt": "指向迎賓大道入口的箭頭該朝哪邊？", "options": ["朝園區裡面", "朝回船碼頭", "朝天空"], "correct": 0, "feedback": "箭頭轉正了，這次不用搭船回來。"},
			{"prompt": "選哪句話替廣播收尾？", "options": ["歡迎來玩，迷路也算探索！", "本亭今日停止思考。", "請把票票寄到失物招領。"], "correct": 0, "feedback": "票票笑了。阿浪說廣播亭終於通過口試。"}
		]
	}
}

const EXPLORATIONS: Array[Dictionary] = [
	{"id": "explore-001", "zone": "welcome", "title": "花壇會眨眼", "interaction": "觀察花壇眼睛跟隨角色；站到地面笑臉上按表情鈕，讓花朵一起眨眼後拍貼。", "hint": "花壇旁牌子畫著笑臉與腳印。", "photo_id": "photo-welcome-explore-1"},
	{"id": "explore-002", "zone": "welcome", "title": "歡迎字樣的影子", "interaction": "旋轉大道展示燈，讓歡迎字樣投影落到牆上空框；按牆邊快門取卡。", "hint": "空框內有字樣輪廓與燈光箭頭。", "photo_id": "photo-welcome-explore-2"},
	{"id": "explore-003", "zone": "welcome", "title": "長椅雙人份", "interaction": "坐到長椅並放下免費借用的吉祥物立牌；按扶手快門取得合照卡。", "hint": "椅上有兩個座位圖示與立牌借用架。", "photo_id": "photo-welcome-explore-3"}
]

const PROLOGUE_ENTRY: Dictionary = {
	"id": "prologue-boat", "title": "開船前的小插曲", "status": "future", "replayable": true,
	"description": "預留船上序章入口；目前尚未演出，玩家從下船抵達迎賓大道開始。"
}

var _story_data: Dictionary = {}
var _diagnostics: Array[String] = []
# Session-only memory: which conversation each line came from and which time
# aside a character last mentioned. Nothing here is saved, so it cannot affect
# rewards or progress; it only avoids repeating the same visit text.
var _conversation_views: Dictionary = {}
var _conversation_view_serial := 0
var _last_aside_phase: Dictionary = {}

## report_errors=false is for validator self-tests that load deliberately broken
## data and read validation_report() instead of failing the engine log.
func _init(path: String = STORY_DATA_PATH, report_errors := true) -> void:
	_load_story_data(path, report_errors)

func _load_story_data(path: String, report_errors := true) -> void:
	_story_data.clear()
	_diagnostics.clear()
	if not FileAccess.file_exists(path):
		_diagnostics.append("missing story data: %s" % path)
	else:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1:
			_diagnostics.append("expected story JSON object with schema_version 1")
		else:
			_story_data = parsed
			_diagnostics = _validate_story_data()
	if report_errors:
		for diagnostic in _diagnostics:
			push_error("StoryDirector: " + diagnostic)

func validation_report() -> Dictionary:
	var diagnostics := _diagnostics.duplicate()
	return {
		"ok": not _story_data.is_empty() and diagnostics.is_empty(),
		"diagnostics": diagnostics,
		"character_ids": REQUIRED_CHARACTER_IDS.duplicate(),
		"quest_ids": ["quest-001", "quest-002"],
		"legacy_step_count": 3
	}

func _validate_story_data() -> Array[String]:
	var errors: Array[String] = []
	var characters: Variant = _story_data.get("characters", {})
	if not characters is Dictionary:
		errors.append("characters must be an object")
	else:
		for character_id in REQUIRED_CHARACTER_IDS:
			var profile: Variant = characters.get(character_id, {})
			if not profile is Dictionary or str(profile.get("name", "")).is_empty() or str(profile.get("motivation", "")).is_empty() or str(profile.get("voice", "")).is_empty():
				errors.append("character '%s' requires name, motivation and voice" % character_id)
	for field in ["intro_lines", "main_lines"]:
		var lines: Variant = _story_data.get(field, [])
		if not lines is Array or lines.is_empty():
			errors.append("%s must be a non-empty array" % field)
			continue
		for index in range(lines.size()):
			var line: Variant = lines[index]
			if not line is Dictionary or not ALLOWED_SPEAKERS.has(str(line.get("speaker", ""))) or str(line.get("text", "")).strip_edges().is_empty():
				errors.append("%s[%d] has unknown speaker or empty text" % [field, index])
			elif str(line.get("speaker", "")) == "露露":
				errors.append("%s[%d] uses unavailable character 露露" % [field, index])
	errors.append_array(_validate_conversations())
	var missions: Variant = _story_data.get("quest_missions", {})
	if not missions is Dictionary:
		errors.append("quest_missions must be an object")
	else:
		for quest_id in QUESTS:
			var mission: Variant = missions.get(quest_id, {})
			if not mission is Dictionary:
				errors.append("missing mission '%s'" % quest_id)
				continue
			var expected_photo_id := str(QUESTS[quest_id].photo_id)
			if str(mission.get("completion_photo_id", "")) != expected_photo_id:
				errors.append("mission '%s' must preserve completion photo id %s" % [quest_id, expected_photo_id])
			var steps: Variant = mission.get("steps", [])
			if not steps is Array or steps.size() != 3 or int(mission.get("legacy_progress_max", -1)) != 3:
				errors.append("mission '%s' must preserve three progress steps" % quest_id)
				continue
			var seen_steps: Dictionary = {}
			for index in range(steps.size()):
				var step: Variant = steps[index]
				if not step is Dictionary:
					errors.append("mission '%s' step %d must be an object" % [quest_id, index])
					continue
				var step_id := str(step.get("step_id", ""))
				if step_id.is_empty() or seen_steps.has(step_id):
					errors.append("mission '%s' step %d has missing or duplicate step_id" % [quest_id, index])
				else:
					seen_steps[step_id] = true
				if not ["interaction", "photo", "observation", "minigame_result", "time_phase"].has(str(step.get("kind", ""))) or str(step.get("target_id", "")).is_empty() or str(step.get("goal", "")).is_empty():
					errors.append("mission '%s' step %d has invalid kind, target_id or goal" % [quest_id, index])
	return errors

func _validate_conversations() -> Array[String]:
	var errors: Array[String] = []
	var conversations: Variant = _story_data.get("conversations", {})
	var asides: Variant = _story_data.get("time_asides", {})
	if not conversations is Dictionary or not asides is Dictionary:
		errors.append("conversations and time_asides must be objects")
		return errors
	var seen_ids: Dictionary = {}
	for character_id in REQUIRED_CHARACTER_IDS:
		var entries: Variant = conversations.get(character_id, [])
		if not entries is Array or entries.is_empty():
			errors.append("character '%s' requires conversations" % character_id)
			continue
		var has_fallback := false
		for index in range(entries.size()):
			var entry: Variant = entries[index]
			var label := "%s conversation %d" % [character_id, index]
			if not entry is Dictionary or not entry.get("when", null) is Dictionary or not entry.get("lines", null) is Array or (entry.lines as Array).is_empty():
				errors.append("%s requires when and non-empty lines" % label)
				continue
			var entry_id := str(entry.get("id", ""))
			if entry_id.is_empty() or seen_ids.has(entry_id):
				errors.append("%s has a missing or duplicate id" % label)
			seen_ids[entry_id] = true
			var when: Dictionary = entry.when
			has_fallback = has_fallback or when.is_empty()
			for key in when:
				if not CONVERSATION_CONDITIONS.has(str(key)):
					errors.append("%s uses unknown condition '%s'" % [label, str(key)])
			for quest_id in (when.get("steps", {}) as Dictionary).keys() + Array(when.get("complete", [])) + Array(when.get("incomplete", [])):
				if not QUEST_IDS.has(str(quest_id)):
					errors.append("%s names unknown quest '%s'" % [label, str(quest_id)])
			if when.has("time_phase") and not TimeOfDay.phase_ids().has(str(when.time_phase)):
				errors.append("%s names unknown time phase" % label)
			for line in entry.lines:
				if not line is Dictionary or not ALLOWED_SPEAKERS.has(str(line.get("speaker", ""))) or str(line.get("text", "")).strip_edges().is_empty():
					errors.append("%s has unknown speaker or empty text" % label)
		if not has_fallback:
			errors.append("character '%s' requires an unconditional fallback conversation" % character_id)
		var character_asides: Variant = asides.get(character_id, {})
		for phase_id in TimeOfDay.phase_ids():
			if not character_asides is Dictionary or str(character_asides.get(phase_id, "")).strip_edges().is_empty():
				errors.append("character '%s' requires a %s time aside" % [character_id, phase_id])
	return errors

## Picks what a character says for the current saved state. The most specific
## matching entry wins; equally specific entries rotate by least recent view.
## state: {"story_photo": bool, "steps": {quest_id: int}, "time_phase": String}.
func conversation_for(character_id: String, state: Dictionary) -> Dictionary:
	var conversations: Dictionary = _story_data.get("conversations", {})
	var entries: Array = conversations.get(character_id, [])
	var best: Dictionary = {}
	var best_salience := -1
	var best_view := 0
	for entry: Dictionary in entries:
		var when: Dictionary = entry.get("when", {})
		if not _conversation_matches(when, state):
			continue
		var salience := _conversation_salience(when)
		var view := int(_conversation_views.get(str(entry.get("id", "")), 0))
		if salience > best_salience or (salience == best_salience and view < best_view):
			best = entry
			best_salience = salience
			best_view = view
	if best.is_empty():
		return {}
	_conversation_view_serial += 1
	_conversation_views[str(best.get("id", ""))] = _conversation_view_serial
	var lines: Array = (best.get("lines", []) as Array).duplicate(true)
	var aside := time_aside(character_id, str(state.get("time_phase", "")))
	var aside_added := false
	if not aside.is_empty() and str(_last_aside_phase.get(character_id, "")) != str(state.get("time_phase", "")):
		lines.append({"speaker": str(character_profile(character_id).get("name", "")), "text": aside})
		_last_aside_phase[character_id] = str(state.get("time_phase", ""))
		aside_added = true
	return {"id": str(best.get("id", "")), "lines": lines, "time_aside": aside_added, "salience": best_salience}

func time_aside(character_id: String, phase_id: String) -> String:
	var asides: Dictionary = _story_data.get("time_asides", {})
	return str((asides.get(character_id, {}) as Dictionary).get(phase_id, ""))

func _conversation_salience(when: Dictionary) -> int:
	var salience := 0
	for key in when:
		match str(key):
			"steps": salience += (when.steps as Dictionary).size()
			"complete", "incomplete": salience += (when[key] as Array).size()
			_: salience += 1
	return salience

func _conversation_matches(when: Dictionary, state: Dictionary) -> bool:
	var steps: Dictionary = state.get("steps", {})
	if when.has("story_photo") and bool(when.story_photo) != bool(state.get("story_photo", false)):
		return false
	for quest_id in (when.get("steps", {}) as Dictionary):
		if int(steps.get(quest_id, 0)) != int(when.steps[quest_id]):
			return false
	for quest_id in when.get("complete", []):
		if int(steps.get(quest_id, 0)) < QUEST_STEP_COUNT:
			return false
	for quest_id in when.get("incomplete", []):
		if int(steps.get(quest_id, 0)) >= QUEST_STEP_COUNT:
			return false
	if when.has("started_any"):
		var underway := false
		for quest_id in QUEST_IDS:
			var step := int(steps.get(quest_id, 0))
			underway = underway or (step > 0 and step < QUEST_STEP_COUNT)
		if underway != bool(when.started_any):
			return false
	if when.has("time_phase") and str(when.time_phase) != str(state.get("time_phase", "")):
		return false
	return true

func intro_lines() -> Array:
	return (_story_data.get("intro_lines", []) as Array).duplicate(true)

func main_lines() -> Array:
	return (_story_data.get("main_lines", []) as Array).duplicate(true)

func character_profiles() -> Dictionary:
	return (_story_data.get("characters", {}) as Dictionary).duplicate(true)

func character_profile(character_id: String) -> Dictionary:
	var profiles: Dictionary = _story_data.get("characters", {})
	return (profiles.get(character_id, {}) as Dictionary).duplicate(true)

func quest_data(id: String) -> Dictionary:
	if not QUESTS.has(id):
		return {}
	var result: Dictionary = QUESTS[id].duplicate(true)
	result["mission"] = quest_mission_data(id)
	return result

func quest_mission_data(id: String) -> Dictionary:
	var missions: Dictionary = _story_data.get("quest_missions", {})
	return (missions.get(id, {}) as Dictionary).duplicate(true)

func mission_progress_valid(id: String, progress: int) -> bool:
	return QUESTS.has(id) and progress >= 0 and progress <= 3

func mission_event_result(id: String, current_step: int, evidence: Dictionary) -> Dictionary:
	var mission := quest_mission_data(id)
	if mission.is_empty():
		return {"accepted": false, "error": "unknown_mission", "current_step": current_step}
	var steps: Array = mission.get("steps", [])
	if current_step < 0 or current_step > steps.size():
		return {"accepted": false, "error": "progress_out_of_range", "current_step": current_step, "max_step": steps.size()}
	if current_step == steps.size():
		return {"accepted": false, "complete": true, "current_step": current_step, "next_step": current_step, "reward_photo_id": ""}
	var step: Dictionary = steps[current_step]
	var accepted := _evidence_matches(step, evidence)
	var next_step := current_step + (1 if accepted else 0)
	var complete := accepted and next_step == steps.size()
	return {
		"accepted": accepted,
		"complete": complete,
		"current_step": current_step,
		"next_step": next_step,
		"step_id": str(step.get("step_id", "")),
		"expected_kind": str(step.get("kind", "")),
		"target_id": str(step.get("target_id", "")),
		"reward_photo_id": str(mission.get("completion_photo_id", "")) if complete else "",
		"idempotency_key": str(mission.get("completion_photo_id", "")) if complete else ""
	}

func _evidence_matches(step: Dictionary, evidence: Dictionary) -> bool:
	var kind := str(step.get("kind", ""))
	var target_id := str(step.get("target_id", ""))
	var event_type := str(evidence.get("type", ""))
	var event_id := str(evidence.get("id", ""))
	match kind:
		"interaction":
			return event_type == "interaction" and event_id == target_id
		"photo":
			return event_type == "photo_collected" and event_id == target_id
		"observation":
			if event_type == "observation_completed" and event_id == target_id:
				return true
			return event_type == "photo_collected" and event_id == str(step.get("proof_photo_id", ""))
		"minigame_result":
			return event_type == "minigame_result" and event_id == target_id and bool(evidence.get("success", false)) and not bool(evidence.get("practice", false))
		"time_phase":
			return event_type == "time_phase" and event_id == target_id
	return false

func exploration_data() -> Array:
	return EXPLORATIONS.duplicate(true)

func prologue_entry() -> Dictionary:
	return PROLOGUE_ENTRY.duplicate(true)
