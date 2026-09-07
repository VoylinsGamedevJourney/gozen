extends BoxContainer
## Handles the sizing of the timeline.


const END_PADDING: int = 80000


@export var timestamp_panel: PanelContainer
@export var timeline_panel: PanelContainer



func _ready() -> void:
	Project.timeline_end_update.connect(_end_update)
	Timeline.zoom_changed.connect(_end_update.unbind(1))
	(timeline_panel.get_parent() as Control).resized.connect(_end_update)


func _end_update(new_end: int = Project.data.timeline_end) -> void:
	var new_size: float = (new_end + END_PADDING) * Timeline.zoom
	var parent: Control = timeline_panel.get_parent() as Control
	if parent: new_size = maxf(new_size, parent.size.x)

	timestamp_panel.custom_minimum_size.x = new_size
	timeline_panel.custom_minimum_size.x = new_size
	timestamp_panel.size.x = new_size
	timeline_panel.size.x = new_size
