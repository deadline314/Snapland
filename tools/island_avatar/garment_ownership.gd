extends RefCounted
## Authoring only: reuse a reviewed fixed head only after exact pixel proof.
static func resolve(avatar: RefCounted, original: Image, direction: String, action: String) -> Dictionary:
	var signature: String = avatar.head_source_signature(original)
	var owner: Dictionary = avatar._head_material_owners.get(signature, {})
	if owner.has("hair_owner_spans"):
		return {"owner": owner, "reference_signature": signature, "method": "exact_original_owner"}
	# Registered standing bodies have independent whole-cel signatures. Their
	# head is copied from the direction's canonical walk reference, not inferred
	# from body colors or accepted merely because the direction name matches.
	if action != "idle" or not avatar._stable_idle_pixels.manifest.has("hero-idle/" + direction): return {}
	var reference: Image = avatar._walk_pose_image(direction, 0)
	if reference == null or reference.get_size() != original.get_size(): return {}
	var reference_signature: String = avatar.head_source_signature(reference)
	owner = avatar._head_material_owners.get(reference_signature, {})
	var spans: Array = owner.get("hair_owner_spans", [])
	if spans.is_empty(): return {}
	for span in spans:
		# The reviewed owner uses a half-open right edge. Artist foreground
		# guides use an inclusive right edge and are handled separately.
		for x in range(int(span[1]), int(span[2])):
			var point := Vector2i(x, int(span[0]))
			if original.get_pixelv(point) != reference.get_pixelv(point): return {}
	return {"owner": owner, "reference_signature": reference_signature, "method": "pixel_verified_canonical_idle_head"}
