extends RefCounted
## Resident errands: after the district greeting, each host has a small three
## step favour. Steps name interaction points, so the same runner works for
## every district: "reach" (the walker comes near a point), "field_game" (a
## round of that instant game ends), "toy" (that toy is played with) and
## "talk" (back to the host, whose photo finishes the errand).
##
## Saved progress per region (Progress.errands): absent = not offered yet,
## 0..2 = working on that step, DONE = the errand photo is in the album.

const RegionalVisit = preload("res://game/story/regional_visit.gd")
const STEP_KINDS := ["reach", "field_game", "toy", "talk"]
const PHOTO_STEP := 2
const DONE := 3
const MAX_GOAL_CHARS := 20
const REGIONS := [RegionalVisit.CIRCUS, RegionalVisit.TOY, RegionalVisit.GARDEN]

const ERRANDS := {
	RegionalVisit.CIRCUS: {
		"id": "photo-circus-quest-1",
		"title": "倒影偷走領結",
		"instructions": "幫小角從鏡廊追回領結，再和他合照。",
		"saved_notice": "領結回來了，合照收進本子裡。",
		"intro": [
			{"speaker": "小角", "text": "鏡廊裡的倒影學我鞠躬，順手把我的領結也拿走了。"},
			{"speaker": "主角", "text": "倒影也要謝幕？"},
			{"speaker": "小角", "text": "他說沒領結不好意思上台。先去鏡廊找找！"},
		],
		"finale": [
			{"speaker": "小角", "text": "領結回來了！倒影說，那他改戴我的尾巴。"},
			{"speaker": "主角", "text": "那你的尾巴呢？"},
			{"speaker": "小角", "text": "……先合照，晚點再數。"},
		],
		"steps": [
			{"goal": "到鏡廊找領結", "kind": "reach", "point": "circus:mirrors", "done": "鏡子裡的領結一閃，倒影溜去聚光燈那邊了。"},
			{"goal": "玩一場追聚光燈", "kind": "field_game", "point": "field:circus-spotlight", "done": "燈一照，倒影害羞得把領結丟了回來。"},
			{"goal": "回入口找小角合照", "kind": "talk", "point": RegionalVisit.CIRCUS_POINT},
		],
	},
	RegionalVisit.TOY: {
		"id": "photo-toy-quest-1",
		"title": "兵兵只會喊立正",
		"instructions": "陪兵兵玩一場木頭人，把發條鑰匙送去維修台，再和阿浪合照。",
		"saved_notice": "車站廣播改喊稍息了，合照收進本子裡。",
		"intro": [
			{"speaker": "阿浪", "text": "我請兵兵幫車站錄廣播，他只會喊『立正！』，整列火車都不敢動。"},
			{"speaker": "主角", "text": "難怪乘客都站得好直。"},
			{"speaker": "阿浪", "text": "他的發條上太緊了。先陪他玩一場木頭人，讓他鬆一鬆。"},
		],
		"finale": [
			{"speaker": "阿浪", "text": "聽！廣播現在說『請稍息』，乘客終於肯坐下了。"},
			{"speaker": "主角", "text": "那下一站呢？"},
			{"speaker": "阿浪", "text": "下一站，合照站。看鏡頭！"},
		],
		"steps": [
			{"goal": "陪兵兵玩木頭人", "kind": "field_game", "point": "field:toy-statue", "done": "兵兵鬆了口氣，掉出一把發條鑰匙。"},
			{"goal": "把鑰匙送到維修台", "kind": "reach", "point": "toy:repair", "done": "維修台把鑰匙轉鬆半圈，廣播喇叭咳了一聲。"},
			{"goal": "回車站找阿浪合照", "kind": "talk", "point": RegionalVisit.TOY_POINT},
		],
	},
	RegionalVisit.GARDEN: {
		"id": "photo-garden-quest-1",
		"title": "溫室的花在打噴嚏",
		"instructions": "到濕地找噴嚏的源頭、吹散蒲公英，再和票票合照。",
		"saved_notice": "溫室安靜下來了，合照收進本子裡。",
		"intro": [
			{"speaker": "票票", "text": "溫室的花在打噴嚏，剛剛把我的票根噴成了紙花。"},
			{"speaker": "主角", "text": "那也算一種剪票。"},
			{"speaker": "票票", "text": "噴到第三張我就沒票了！先去濕地看看是誰起的頭。"},
		],
		"finale": [
			{"speaker": "票票", "text": "安靜了！我的票根終於只是一張票。"},
			{"speaker": "主角", "text": "有點可惜，紙花挺好看的。"},
			{"speaker": "票票", "text": "那合照時撒一點，當作謝幕。"},
		],
		"steps": [
			{"goal": "到濕地找噴嚏源頭", "kind": "reach", "point": "garden:wetland", "done": "濕地的蘆葦小聲說：是外面的蒲公英先開始的。"},
			{"goal": "到溫室外吹散蒲公英", "kind": "toy", "point": "toy:garden-dandelion", "done": "絨毛飛走了，整座溫室安靜了三秒。"},
			{"goal": "回日照窗找票票合照", "kind": "talk", "point": RegionalVisit.GARDEN_POINT},
		],
	},
}

static func has(region: String) -> bool:
	return ERRANDS.has(region)

## Read every frame by the walk check, so a constant, never a fresh array.
static func regions() -> Array:
	return REGIONS

static func photo_id(region: String) -> String:
	return str(ERRANDS.get(region, {}).get("id", ""))

static func title(region: String) -> String:
	return str(ERRANDS.get(region, {}).get("title", ""))

static func saved_notice(region: String) -> String:
	return str(ERRANDS.get(region, {}).get("saved_notice", ""))

static func intro(region: String) -> Array:
	return ERRANDS.get(region, {}).get("intro", [])

static func finale(region: String) -> Array:
	return ERRANDS.get(region, {}).get("finale", [])

## The step being worked on at a saved progress value, or {} when none is.
static func step(region: String, progress: int) -> Dictionary:
	var steps: Array = ERRANDS.get(region, {}).get("steps", [])
	return steps[progress] if progress >= 0 and progress < steps.size() else {}

## True when this evidence finishes the step the saved progress is on.
## The talk step is finished by the photo, never by evidence.
static func matches(region: String, progress: int, kind: String, point: String) -> bool:
	var current := step(region, progress)
	return progress < PHOTO_STEP and str(current.get("kind", "")) == kind and str(current.get("point", "")) == point

## One HUD line while an errand is under way, empty otherwise.
static func hud_line(region: String, progress: int) -> String:
	var current := step(region, progress)
	return "" if current.is_empty() else "%s  %d / 3｜%s" % [title(region), progress + 1, current.goal]

## What the host says when visited before the current step is done.
static func reminder(region: String, progress: int) -> Array:
	var current := step(region, progress)
	return [{"speaker": RegionalVisit.host_name(region), "text": "%s——我在這裡等你！" % str(current.get("goal", ""))}]

## The notice after a step is finished: what happened, then the next goal.
static func progress_notice(region: String, finished: int) -> String:
	return "%s　下一步：%s" % [str(step(region, finished).get("done", "")), str(step(region, finished + 1).get("goal", ""))]

## The album entry; "story_errand" asks the album for an errand replay.
static func entry(region: String) -> Dictionary:
	var errand: Dictionary = ERRANDS.get(region, {})
	if errand.is_empty():
		return {}
	return {"id": errand.id, "title": errand.title, "instructions": errand.instructions, "story_errand": region}

## Data problems; tests and the story validator read this.
static func problems() -> Array[String]:
	var found: Array[String] = []
	if REGIONS != ERRANDS.keys():
		found.append("REGIONS must list every errand region")
	for region: String in ERRANDS:
		var errand: Dictionary = ERRANDS[region]
		var steps: Array = errand.get("steps", [])
		if steps.size() != DONE or str(steps[PHOTO_STEP].get("kind", "")) != "talk" or str(steps[PHOTO_STEP].get("point", "")) != RegionalVisit.point_id(region):
			found.append("%s errand needs three steps ending with a talk at its host" % region)
			continue
		var kinds := steps.map(func(row: Dictionary) -> String: return str(row.get("kind", "")))
		if not kinds.has("reach") or not (kinds.has("field_game") or kinds.has("toy")):
			found.append("%s errand needs a reach step and an instant game or toy step" % region)
		for row: Dictionary in steps:
			if not STEP_KINDS.has(str(row.get("kind", ""))) or str(row.get("point", "")).is_empty():
				found.append("%s errand step has an unknown kind or no point" % region)
			var goal := str(row.get("goal", ""))
			if goal.is_empty() or goal.length() > MAX_GOAL_CHARS:
				found.append("%s errand goal '%s' must be 1 to %d characters" % [region, goal, MAX_GOAL_CHARS])
			if row.get("kind") != "talk" and str(row.get("done", "")).is_empty():
				found.append("%s errand step '%s' needs a done line" % [region, goal])
		for key in ["intro", "finale"]:
			for line: Dictionary in errand.get(key, []):
				if not [RegionalVisit.host_name(region), "主角"].has(str(line.get("speaker", ""))) or str(line.get("text", "")).is_empty():
					found.append("%s errand %s line has an unknown speaker or no text" % [region, key])
		if not str(errand.get("id", "")).begins_with("photo-%s-quest-" % region):
			found.append("%s errand photo must use the region's quest sticker id" % region)
	return found
