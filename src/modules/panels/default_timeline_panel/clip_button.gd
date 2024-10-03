extends Node



func _pressed() -> void:
	GoZenServer.open_clip_effects(name.to_int())

	if GoZenServer.selected_clips.append(name.to_int()):
		printerr("Couldn't append clip id to selected clips! ", name)
