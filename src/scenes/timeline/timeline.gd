extends BoxContainer
## Handles the sizing of the timeline.

const END_PADDING: int = 80000


@export var timestamp_panel: PanelContainer
@export var timeline_panel: PanelContainer



func _ready() -> void:
	Project.timeline_end_update.connect(_end_update)
	Timeline.zoom_changed.connect(_end_update.unbind(1))


func _end_update(new_end: int = Project.data.timeline_end) -> void:
	var new_size: float = (new_end + END_PADDING) * Timeline.zoom
	timestamp_panel.custom_minimum_size.x = new_size
	timeline_panel.custom_minimum_size.x = new_size
	timestamp_panel.size.x = new_size
	timeline_panel.size.x = new_size

	var timestamp_scroll: ScrollContainer = timestamp_panel.get_parent() as ScrollContainer
	if timestamp_scroll:
		var ts_h_scroll: HScrollBar = timestamp_scroll.get_h_scroll_bar()
		ts_h_scroll.max_value = maxf(ts_h_scroll.max_value, new_size)
		ts_h_scroll.page = timestamp_scroll.size.x

	var timeline_scroll: ScrollContainer = timeline_panel.get_parent() as ScrollContainer
	var timeline_h_scroll: HScrollBar = timeline_scroll.get_h_scroll_bar()
	timeline_h_scroll.max_value = maxf(timeline_h_scroll.max_value, new_size)
	timeline_h_scroll.page = timeline_scroll.size.x
