extends SceneTree

const StoryDirector = preload("res://game/story/story_director.gd")

func _initialize() -> void:
	var story := StoryDirector.new()
	var intro := story.intro_lines()
	assert(not intro.is_empty())
	assert(intro.all(func(line: Dictionary) -> bool: return line.has("speaker") and line.has("text")))
	assert(story.main_lines().size() >= 3)
	var first := story.quest_data("quest-001")
	var second := story.quest_data("quest-002")
	for quest in [first, second]:
		assert(not quest.is_empty())
		assert((quest.get("steps", []) as Array).size() == 3)
		assert(quest.has("photo_id"))
		for step in quest.steps:
			assert(step.prompt is String and not step.prompt.is_empty())
			assert(step.options is Array and step.options.size() >= 2)
			assert(step.correct >= 0 and step.correct < step.options.size())
	assert(story.quest_data("missing").is_empty())
	var explorations := story.exploration_data()
	assert(explorations.size() == 3)
	assert(explorations.map(func(item: Dictionary) -> String: return item.id) == ["explore-001", "explore-002", "explore-003"])
	for item in explorations:
		assert(item.photo_id is String and item.hint is String)
	assert(story.prologue_entry().status == "future")
	print("PASS: story runtime checks")
	quit(0)
