extends RefCounted
## Test-only keyboard delivery through the normal viewport GUI route.

static func key(viewport: Viewport, code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		viewport.push_input(event)
		await viewport.get_tree().process_frame

static func activate(button: Button) -> void:
	button.grab_focus()
	await key(button.get_viewport(), KEY_ENTER)
