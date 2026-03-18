extends PanelContainer

@export var markers_text_edit: TextEdit
@export var markers_option_button: OptionButton


var markers_text: PackedStringArray = []



func _ready() -> void:
	markers_text.resize(5) # Default amount of markers.
	Project.project_ready.connect(_on_markers_updated)
	MarkerLogic.added.connect(_on_markers_updated.unbind(1))
	MarkerLogic.updated.connect(_on_markers_updated.unbind(1))
	MarkerLogic.removed.connect(_on_markers_updated.unbind(1))


func _on_copy_markers_button_pressed() -> void:
	DisplayServer.clipboard_set(markers_text_edit.text)


func _on_markers_updated() -> void:
	# Resetting strings + options.
	markers_text.fill("")
	markers_option_button.clear()

	# Updating the options button.
	var marker_names: PackedStringArray = Settings.get_marker_names()
	var marker_colors: PackedColorArray = Settings.get_marker_colors()
	var icon_image: Image = Image.create(16, 16, false, Image.FORMAT_RGB8)
	for id: int in marker_names.size():
		var icon: Image = icon_image.duplicate()
		icon.fill(marker_colors[id])
		markers_option_button.add_icon_item(ImageTexture.create_from_image(icon), marker_names[id], id)

	# Updating the texts.
	var selected: int = markers_option_button.selected
	for marker: MarkerData in MarkerLogic.markers:
		var time: String = Utils.format_time_str_from_frame(marker.frame_nr, Project.data.framerate, true)
		markers_text[marker.type] += "%s %s\n" % [time, marker.text]
	markers_option_button.selected = max(0, selected)
	_on_markers_button_item_selected(markers_option_button.selected)


func _on_markers_button_item_selected(index: int) -> void:
	markers_text_edit.text = markers_text[index]
