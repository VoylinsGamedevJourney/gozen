extends PanelContainer

@export var markers_text_edit: TextEdit
@export var markers_option_button: OptionButton


var markers_text: PackedStringArray = []



func _ready() -> void:
	markers_text.resize(5) # Default amount of markers
	Project.project_ready.connect(_on_project_ready)


func _on_project_ready() -> void:
	Project.markers.added.connect(_on_markers_updated.unbind(1))
	Project.markers.updated.connect(_on_markers_updated.unbind(2))
	Project.markers.removed.connect(_on_markers_updated.unbind(1))
	_on_markers_updated()


func _on_copy_markers_button_pressed() -> void:
	DisplayServer.clipboard_set(markers_text_edit.text)


func _on_markers_updated() -> void:
	var marker_names: PackedStringArray = Settings.get_marker_names()
	var marker_colors: PackedColorArray = Settings.get_marker_colors()
	var selected: int = markers_option_button.selected
	var frames: PackedInt64Array = Project.data.markers_frame

	# Resetting strings + options
	markers_text.fill("")
	markers_option_button.clear()

	# Updating the options button
	for id: int in marker_names.size():
		var icon: Image = Image.create(16, 16, false, Image.FORMAT_RGB8)
		icon.fill(marker_colors[id])
		markers_option_button.add_icon_item(ImageTexture.create_from_image(icon), marker_names[id], id)

	# Updating the texts
	for frame_nr: int in frames:
		var time: String = Utils.format_time_str_from_frame(frame_nr, Project.get_framerate(), true)
		var marker_index: int = Project.data.markers_frame.find(frame_nr)
		var marker_type: int = Project.data.markers_type[marker_index]
		var marker_text: String = Project.data.markers_text[marker_index]
		markers_text[marker_type] += "%s %s\n" % [time, marker_text]
	markers_option_button.selected = max(0, selected)
	_on_markers_button_item_selected(markers_option_button.selected)


func _on_markers_button_item_selected(index: int) -> void:
	markers_text_edit.text = markers_text[index]
