extends SceneTree
## Renderers share decoded atlas sources; each still owns its own tables and
## produces the same pixels as a renderer loaded from disk.

const AvatarRenderer = preload("res://game/world/avatar_renderer.gd")

var failures := 0
var checks := 0


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Avatar shared sources: " + message)


func _initialize() -> void:
	AvatarRenderer.clear_shared_sources()
	var appearance := {}
	var equipped := {}
	var first := AvatarRenderer.new()
	_check(first.is_asset_ready(), "first renderer loads the atlas")
	var started := Time.get_ticks_msec()
	var second := AvatarRenderer.new()
	var reuse_msec := Time.get_ticks_msec() - started
	_check(second.is_asset_ready(), "second renderer is ready from shared sources")
	_check(reuse_msec < 400, "second renderer skips the atlas scan (%d ms)" % reuse_msec)
	_check(second.pose_height() == first.pose_height(), "pose height matches")
	_check(second.has_hat_atlas() == first.has_hat_atlas() and second.has_hair_atlas() == first.has_hair_atlas() and second.has_species_atlas() == first.has_species_atlas(), "optional atlases match")
	for sample in [["front", 0, "idle"], ["left", 1, "walk"], ["back_right", 2, "walk"]]:
		var a: Texture2D = first.texture(appearance, equipped, sample[0], sample[1], sample[2])
		var b: Texture2D = second.texture(appearance, equipped, sample[0], sample[1], sample[2])
		_check(a != null and b != null and a.get_image().get_data() == b.get_image().get_data(), "%s %s frame %d renders identically" % [sample[2], sample[0], sample[1]])
	var bottoms_before: int = first._pose_visible_bottoms.size()
	second._pose_visible_bottoms.append(-1)
	second._walk_frame_counts["__probe__"] = 1
	_check(first._pose_visible_bottoms.size() == bottoms_before, "arrays are not shared between renderers")
	_check(not first._walk_frame_counts.has("__probe__"), "tables are not shared between renderers")
	var third := AvatarRenderer.new()
	_check(third._pose_visible_bottoms.size() == bottoms_before and not third._walk_frame_counts.has("__probe__"), "a later renderer starts from clean shared sources")
	AvatarRenderer.clear_shared_sources()
	var reloaded := AvatarRenderer.new()
	_check(reloaded.is_asset_ready() and reloaded.pose_height() == first.pose_height(), "clearing forces a clean reload")
	if failures == 0:
		print("PASS: avatar renderers share decoded sources without sharing state (%d checks)" % checks)
	quit(1 if failures > 0 else 0)
