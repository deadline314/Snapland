extends Node
## CPU-only integrity and measurement audit for candidate NPC motion sources.

const ProviderScript := preload("res://game/world/npc_motion_sources.gd")
const Rig := preload("res://game/world/avatar_motion_rig.gd")

const IMP_HAND_WITNESSES := {"left":[Vector2i(68,285),Vector2i(74,287),Vector2i(158,286),Vector2i(172,285),Vector2i(174,291)],"right":[Vector2i(110,291),Vector2i(120,291),Vector2i(130,291),Vector2i(210,291),Vector2i(210,294),Vector2i(218,282)]}
const IMP_HAND_INTERIORS := {"left":[Rect2i(58,271,23,22),Rect2i(150,271,23,22)],"right":[Rect2i(105,276,25,20),Rect2i(200,272,19,22)]}

var _results: Array[Dictionary] = []
var _diagnostic_dir := ""

func _ready() -> void:
	var save_path := OS.get_environment("SNAPLAND_SAVE_PATH").strip_edges()
	if save_path.is_empty() or not save_path.is_absolute_path():
		push_error("NPC motion source test requires an isolated absolute SNAPLAND_SAVE_PATH")
		get_tree().quit(1)
		return
	_diagnostic_dir = save_path.get_base_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(_diagnostic_dir)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		push_error("NPC motion source test cannot create diagnostics directory '%s': %s" % [_diagnostic_dir, error_string(mkdir_error)])
		get_tree().quit(1)
		return
	_run()

func _run() -> void:
	var provider := ProviderScript.new()
	var stale_provider := ProviderScript.new()
	stale_provider._metadata.roles.ticket.directions.left.leg_measurement.ankle_y_px = 300
	assert(stale_provider.direction_measurement("ticket","left").is_empty() and not stale_provider.diagnostics.is_empty(),"stale ticket crop-row ankle cannot configure a fixed anatomical chain")
	var left_leg: Dictionary = provider.direction_measurement("ticket","left").leg_measurement
	var right_leg: Dictionary = provider.direction_measurement("ticket","right").leg_measurement
	assert(is_equal_approx((float(left_leg.source_hip_to_ankle_m)+float(right_leg.source_hip_to_ankle_m))*0.5,0.23),"one fixed ticket role chain uses the mean measured 35/34px distances to row296")
	var root: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProviderScript.METADATA_PATH))
	assert(root is Dictionary and bool(root.get("candidate_only", false)), "source sheet metadata remains explicitly candidate-only")
	for role: String in ["ticket", "imp", "announcer"]:
		for unsupported_view in ["front", "front_right", "back_right", "back", "back_left", "front_left"]:
			assert(provider.provide(role, unsupported_view).is_empty(), "%s unsupported %s view is not mirrored or fabricated" % [role, unsupported_view])
	for role in ["ticket", "imp", "announcer"]:
		var role_data: Dictionary = provider.measurements_for(role)
		var atlas_path := ProjectSettings.globalize_path(String(role_data.source_atlas))
		assert(FileAccess.get_sha256(atlas_path) == String(role_data.source_sha256), role + " original candidate atlas hash is unchanged")
		var atlas := Image.new()
		assert(atlas.load(atlas_path) == OK, role + " candidate atlas loads on CPU")
		for view in ["left", "right"]:
			var entry: Dictionary = provider.direction_measurement(role, view)
			if role != "announcer":
				var length_scale := float(entry.leg_measurement.leg_length_scale)
				assert(length_scale >= 0.35 and length_scale <= 1.2, "%s/%s hip-to-ankle measurement fits documented rig scale bounds" % [role, view])
			var measured_rect := ProviderScript.rect_from_values(entry.source_rect)
			var half_width := atlas.get_width() / 2
			var half_rect := Rect2i(0 if view == "left" else half_width, 0, half_width, atlas.get_height())
			var strong_bounds: Rect2i = ProviderScript.strong_alpha_bounds(atlas, half_rect)
			assert(strong_bounds == measured_rect, "%s/%s crop equals measured alpha>=128 body bounds" % [role, view])
			assert(int(entry.normalization.destination_origin[1]) >= 12, "%s/%s normalized body keeps at least 12px head/top padding" % [role, view])
			assert(int(entry.normalization.destination_origin[1]) + int(entry.normalization.destination_body_size[1]) == 346, "%s/%s normalized crop retains its measured sole baseline" % [role, view])
			var supplied: Dictionary = provider.provide(role, view, {}, {})
			assert(not supplied.is_empty(), "%s/%s source provider returns reviewed candidate" % [role, view])
			var source: Image = supplied.source
			var raw: Image = supplied.raw
			assert(source.get_size() == Vector2i(280, 360) and raw.get_size() == Vector2i(280, 360), "%s/%s normalization uses the SourceRig canvas" % [role, view])
			assert(source.get_data() == raw.get_data(), "%s/%s raw stream is byte-identical to unmodified source stream" % [role, view])
			assert(String(supplied.atlas_sha256) == String(role_data.source_sha256), "%s/%s records immutable source hash" % [role, view])
			var prep: Dictionary = Rig.prepare_source(source, raw, entry, "%s/roles/%s/directions/%s" % [ProviderScript.METADATA_PATH, role, view])
			var source_diag := _diagnostic_dir.path_join("npc-source-%s-%s.png" % [role, view])
			var upper_diag := _diagnostic_dir.path_join("npc-upper-%s-%s.png" % [role, view])
			assert(source.save_png(source_diag) == OK and prep.upper.save_png(upper_diag) == OK, "%s/%s .review diagnostics save on CPU" % [role, view])
			var source_height_m := float(role_data.target_body_height_px) * 2.4 / 360.0
			var result := {"role": role, "view": view, "source_sha256": supplied.atlas_sha256, "source_bounds": entry.source_rect, "normalized_body_size": entry.normalization.destination_body_size, "source_body_height_m": source_height_m, "requested_npc_world_height_m": float(role_data.requested_npc_world_height_m), "observed_shared_park_sprite_height_m": float(role_data.observed_shared_park_sprite_height_m), "height_delta_vs_requested_m": source_height_m - float(role_data.requested_npc_world_height_m), "height_delta_vs_observed_shared_m": source_height_m - float(role_data.observed_shared_park_sprite_height_m), "leg_measurement": entry.leg_measurement, "measured_ankle_height_m": entry.measurements.ankle_height_source_m, "skin_hue_classifier_pixels": _skin_classifier_pixel_count(raw, entry.lower), "prepare_source_valid": bool(prep.get("valid", false)), "prepare_source_reason": String(prep.get("reason", "")), "boot_or_foot_sole_px": int(prep.get("sole", -1)), "normalized_source_diagnostic": source_diag, "prepared_upper_diagnostic": upper_diag}
			assert(bool(prep.get("valid", false)), "%s/%s measured regions prepare through AvatarMotionRig: %s" % [role, view, String(prep.get("reason", ""))])
			if role == "imp":
				# Independent raw-cel hand/finger witnesses: the former broad boot
				# flood deletes imp-right x210/y291 even though it is an authored hand.
				if view == "right":
					assert(source.get_pixel(210,291)==Color8(227,58,49,252),"independently measured original imp fingertip RGBA establishes the source landmark")
					var old_entry := entry.duplicate(true)
					old_entry.erase("hand_guards")
					old_entry.erase("limb_corridors")
					old_entry.hip_points = [[124,279],[153,279]]
					var old_prep := Rig.prepare_source(source,raw,old_entry,"isolated former boot-connected ownership")
					assert(old_prep.valid and old_prep.upper.get_pixel(210,291).a==0,"former broad connected ownership independently reproduces deletion of a real hand pixel")
				for point: Vector2i in IMP_HAND_WITNESSES[view]:
					assert(source.get_pixelv(point).a>0.95,"measured imp hand witness exists in immutable normalized source")
					assert(prep.upper.get_pixelv(point)==source.get_pixelv(point),"imp/%s whole authored hand/finger RGBA stays exact at %s" % [view,str(point)])
				for interior: Rect2i in IMP_HAND_INTERIORS[view]:
					for y in range(interior.position.y,interior.end.y):
						for x in range(interior.position.x,interior.end.x):
							if source.get_pixel(x,y).a>0.4:
								assert(prep.upper.get_pixel(x,y)==source.get_pixel(x,y),"independently measured hand interior preserves every original opaque RGBA")
			assert(source.get_data() == prep.source.get_data(), "%s/%s preparation leaves source RGB/alpha stream unchanged" % [role, view])
			assert(int(prep.sole) == int(entry.sole_y), "%s/%s extracted boot/bare-foot sole matches measured contact row" % [role, view])
			var limb_counts: Array[int] = []
			for envelope: Array in entry.limb_envelopes:
				var box := ProviderScript.rect_from_values(envelope)
				var limb_pixels := 0
				for y in range(box.position.y, box.end.y):
					for x in range(box.position.x, box.end.x):
						limb_pixels += int(prep.limb_mask[y * 280 + x])
				assert(limb_pixels > 40, "%s/%s leg envelope %d contains measured, removable limb pixels" % [role, view, limb_counts.size()])
				limb_counts.append(limb_pixels)
			result["limb_mask_pixels_by_envelope"] = limb_counts
			for protected: Dictionary in entry.protected_regions_named:
				var box := ProviderScript.rect_from_values(protected.rect)
				for y in range(box.position.y, box.end.y):
					for x in range(box.position.x, box.end.x):
						assert(prep.upper.get_pixel(x, y) == source.get_pixel(x, y), "%s/%s %s guard preserves original pixel" % [role, view, protected.label])
			_results.append(result)
	for result: Dictionary in _results:
		print("NPC_SOURCE_MEASUREMENT " + JSON.stringify(result))
	var report_path := _diagnostic_dir.path_join("npc-motion-source-report.json")
	var report := {"candidate_only": true, "human_visual_acceptance": false, "results": _results, "runtime_height_note": root.runtime_height_configuration_note}
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	assert(report_file != null, "write isolated .review report")
	report_file.store_string(JSON.stringify(report, "\t"))
	report_file.close()
	print("PASS: all three NPC roles' source hashes, measured alpha bounds, nearest normalized RGBA streams, unsupported-view behavior, and rig-prepared limb/boot regions")
	get_tree().quit(0)

func _skin_classifier_pixel_count(raw: Image, lower: Array) -> int:
	var matched := 0
	for index in range(mini(2, lower.size())):
		var box := ProviderScript.rect_from_values(lower[index])
		for y in range(box.position.y, box.end.y):
			for x in range(box.position.x, box.end.x):
				var color := raw.get_pixel(x, y)
				if color.a > 0.4 and color.r > 0.70 and color.g / color.r > 0.4 and color.g / color.r < 0.8 and color.b / color.r < 0.62:
					matched += 1
	return matched
