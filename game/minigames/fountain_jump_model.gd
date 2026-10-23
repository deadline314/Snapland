extends RefCounted
class_name FountainJumpModel

## Authored three-phrase schedule for fountain_timing (SG-18).
## Session rules, the 3D court, HUD and tests all read beat and count-in times
## from here, so the visible pre-cue, the count-in sound and the judged beat can
## never drift apart. Each phrase is a short count-in played by the side jets,
## followed by the judged jump on the central jet's crest.

## The opening rest before the first count-in, in seconds of round time.
const LEAD_IN := 0.8
## Space between a judged beat and the next phrase's first count. It must stay
## longer than the latest accepted input plus the jump animation and settle so
## a late landing never overlaps the next count-in.
const PHRASE_GAP := 1.2
## Each entry: id, display name, seconds per count, and the count pattern.
## true = a sounded count (a side jet fires); false = a rest the player keeps
## in their head. The judged jump always falls one interval after the pattern.
const PHRASES: Array[Dictionary] = [
	{"id": "slow", "name": "慢拍", "interval": 0.60, "pattern": [true, true, true]},
	{"id": "quick", "name": "快拍", "interval": 0.45, "pattern": [true, true, true]},
	{"id": "rest", "name": "休止拍", "interval": 0.45, "pattern": [true, true, false]},
]
## Side-jet order for sounded counts: outer pair first, then inner pair.
const COUNT_JETS: Array[int] = [0, 4, 1, 3]

static func phrase_count() -> int:
	return PHRASES.size()

static func phrase(index: int) -> Dictionary:
	return PHRASES[clampi(index, 0, PHRASES.size() - 1)]

static func phrase_name(index: int) -> String:
	return str(phrase(index).get("name", ""))

static func interval(index: int) -> float:
	return float(phrase(index).get("interval", 0.5))

## Round time of the first count of a phrase.
static func phrase_start(index: int) -> float:
	var start := LEAD_IN
	for previous in clampi(index, 0, PHRASES.size()):
		var row: Dictionary = PHRASES[previous]
		start += float(row.interval) * float((row.pattern as Array).size()) + PHRASE_GAP
	return start

## Round time of the judged jump beat for the given opportunity.
static func beat_time(index: int) -> float:
	var row := phrase(index)
	return phrase_start(index) + float(row.interval) * float((row.pattern as Array).size())

## Every count position of a phrase as {time, sounded, slot}; the beat is not included.
static func counts(index: int) -> Array[Dictionary]:
	var row := phrase(index)
	var result: Array[Dictionary] = []
	var start := phrase_start(index)
	var pattern: Array = row.pattern
	for slot in pattern.size():
		result.append({"time": start + float(row.interval) * float(slot), "sounded": bool(pattern[slot]), "slot": slot})
	return result

## Number of count positions (sounded or rest) already reached at `phase`.
static func counts_reached(index: int, phase: float) -> int:
	var reached := 0
	for count in counts(index):
		if phase + 0.0005 >= float(count.time):
			reached += 1
	return reached

## Final round time after which no opportunity can still be judged.
static func last_deadline(hit_window: float) -> float:
	return beat_time(PHRASES.size() - 1) + hit_window

static func rule_text() -> String:
	return "三段預告後起跳：慢拍、快拍、休止拍（最後一拍不響，靠心中節拍）。"
