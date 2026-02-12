extends Control
# TODO: Make the button open a popupmenu through toolbox get_popup()
# When pressing one of the options, color of button should save.
# TODO: Switch the option button by a palette instead with the currently
# 	selected one being the bigger one. (maybe self_modulate the background to
# 	give more of an indication of the selected marker color)

static var marker_type: int = 0 ## We want to save the last used type.


@export var marker_line_edit: LineEdit
@export var type_option_button: OptionButton
@export var time_label: Label
@export var delete_button: TextureButton


func _ready() -> void:
	_setup_type_option_button()
	accept_event()

	# Check if marker present, if yes, we edit.
	var marker_index: int = Project.data.markers_frame.find(EditorCore.frame_nr)
	if marker_index != -1:
		marker_line_edit.text = Project.data.markers_text[marker_index]
		marker_type = Project.data.markers_type[marker_index]
	else:
		marker_line_edit.text = ""

	marker_line_edit.grab_focus()
	marker_line_edit.select_all()
	type_option_button.selected = marker_type
	time_label.text = "%s (Frame: %d)" % [
			Utils.format_time_str_from_frame(EditorCore.frame_nr, Project.get_framerate(), false),
			EditorCore.frame_nr]

	delete_button.visible = marker_index != -1


func _setup_type_option_button() -> void:
	var marker_names: PackedStringArray = Settings.get_marker_names()
	var marker_colors: PackedColorArray = Settings.get_marker_colors()

	for id: int in marker_names.size():
		var icon: Image = Image.create(16, 16, false, Image.FORMAT_RGB8)

		icon.fill(marker_colors[id])
		type_option_button.add_icon_item(ImageTexture.create_from_image(icon), marker_names[id], id)


func _on_create_marker_pressed() -> void:
	var text_content: String = marker_line_edit.text.strip_edges()
	var marker_index: int = Project.data.markers_frame.find(EditorCore.frame_nr)

	if text_content == "": # Delete if empty
		if marker_index != -1:
			Project.markers.remove(EditorCore.frame_nr)
	elif marker_index != -1:
		Project.markers.update(marker_index, EditorCore.frame_nr, text_content, marker_type)
	else:
		Project.markers.add(EditorCore.frame_nr, text_content, marker_type)
	PopupManager.close(PopupManager.MARKER)


func _on_type_selected(marker_index: int) -> void:
	marker_type = marker_index


func _on_cancel_button_pressed() -> void:
	PopupManager.close(PopupManager.MARKER)


func _on_delete_marker_button_pressed() -> void:
	Project.markers.remove(EditorCore.frame_nr)
	PopupManager.close(PopupManager.MARKER)
