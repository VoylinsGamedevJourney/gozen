extends Button
# TODO: Check if multiple files were selected to drag in the timeline


func _ready() -> void:
	if Project._on_file_nickname_changed.connect(_on_file_nickname_changed):
		printerr("Couldn't connect on file nickname changed in file button!")


func _on_pressed() -> void:
	GoZenServer.open_file_effects(name.to_int())


func _get_drag_data(_pos: Vector2) -> Variant:
	return Draggable.new(Draggable.NEW_CLIP, [name.to_int()])


func _on_file_nickname_changed(a_file_id: int) -> void:
	var l_file: File = Project.files[a_file_id]

	text = l_file.nickname

