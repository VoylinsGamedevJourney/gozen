extends Button



func _ready() -> void:
	if gui_input.connect(_on_gui_input):
		printerr("Couldn't connect to gui_input!")
	

func _on_gui_input(a_event: InputEvent) -> void:
	# We need mouse passthrough to allow for clip dragging without issues
	# But when clicking on clips we do not want the playhead to keep jumping.
	# Maybe later on we can allow for clip clicking and playhead moving by
	# holding alt or something.
	if !(a_event as InputEventWithModifiers).alt_pressed and a_event.is_pressed():
		EffectsPanel.instance.open_clip_effects(name.to_int())
		get_viewport().set_input_as_handled()


