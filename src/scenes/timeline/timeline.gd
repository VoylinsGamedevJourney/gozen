extends BoxContainer
# Handles the sizing of the timeline

const END_PADDING: int = 5000


@export var timestamp_panel: PanelContainer
@export var timeline_panel: PanelContainer


var current_zoom: float = 1.0



func _ready() -> void:
	Project.timeline_end_update.connect(_end_update)


func _on_timeline_zoom_changed(new_zoom: float) -> void:
	current_zoom = new_zoom
	_end_update()


func _end_update(new_end: int = Project.data.timeline_end) -> void:
	var new_size: float = (new_end + END_PADDING) * current_zoom

	timestamp_panel.custom_minimum_size.x = new_size
	timeline_panel.custom_minimum_size.x = new_size
