extends Control
# TODO: Make the button open a popupmenu through toolbox get_popup()
# When pressing one of the options, color of button should save.


static var selected_type_index: int = 0 # We want to save the last used type

@export var marker_line_edit: LineEdit
@export var type_option_button: OptionButton
@export var time_label: Label

var current_frame: int = 0



func _ready() -> void:
	current_frame = EditorCore.frame_nr

	_setup_type_option_button()
	accept_event()
	
	# Check if marker present, if yes, we edit
	if MarkerHandler.markers.has(current_frame):
		var existing_marker: MarkerData = MarkerHandler.get_marker(current_frame)

		marker_line_edit.text = existing_marker.text
		selected_type_index = existing_marker.type_id
	else:
		marker_line_edit.text = ""
		
	marker_line_edit.grab_focus()
	marker_line_edit.select_all()
	type_option_button.selected = selected_type_index
	time_label.text = "%s (Frame: %d)" % [
			Utils.format_time_str_from_frame(current_frame, Project.get_framerate(), false),
			current_frame]


func _setup_type_option_button() -> void:
	var marker_names: PackedStringArray = Settings.get_marker_names()
	var marker_colors: PackedColorArray = Settings.get_marker_colors()

	for id: int in marker_names.size():
		var icon: Image = Image.create(16, 16, false, Image.FORMAT_RGB8)

		icon.fill(marker_colors[id])
		type_option_button.add_icon_item(ImageTexture.create_from_image(icon), marker_names[id], id)


func _on_type_selected(id: int) -> void:
	selected_type_index = id


func _on_create_marker_pressed() -> void:
	var text_content: String = marker_line_edit.text
	
	if text_content.strip_edges() == "": # Delete if empty
		if MarkerHandler.markers.has(current_frame):
			MarkerHandler.remove_marker(current_frame)
	else: # Create or update marker
		var marker: MarkerData = MarkerData.new()

		marker.text = text_content
		marker.type_id = selected_type_index
		MarkerHandler.add_marker(current_frame, marker)
		
	PopupManager.close_popup(PopupManager.POPUP.MARKER)


func _on_cancel_button_pressed() -> void:
	PopupManager.close_popup(PopupManager.POPUP.MARKER)
