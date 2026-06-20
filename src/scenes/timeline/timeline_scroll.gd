extends ScrollContainer
## The scroll handler for the timeline stuff.


@export var timestamp_scroll: ScrollContainer
@export var track_controls_scroll: ScrollContainer



func _ready() -> void:
	@warning_ignore_start("return_value_discarded")
	timestamp_scroll.get_h_scroll_bar().value_changed.connect(_on_timestamp_scrolling)
	track_controls_scroll.get_v_scroll_bar().value_changed.connect(_on_timeline_v_scrolling)

	get_h_scroll_bar().value_changed.connect(_on_timeline_h_scrolling)
	get_v_scroll_bar().value_changed.connect(_on_timeline_v_scrolling_self)

	Timeline.scroll_changed.connect(_on_global_scroll_changed)
	@warning_ignore_restore("return_value_discarded")


func _on_timestamp_scrolling(value: float) -> void:
	if self.scroll_horizontal != int(value):
		self.scroll_horizontal = int(value)
	Timeline.set_scroll_x(self.scroll_horizontal)


func _on_timeline_v_scrolling(value: float) -> void:
	if self.scroll_vertical != int(value):
		self.scroll_vertical = int(value)
	Timeline.set_scroll_y(self.scroll_vertical)


func _on_timeline_h_scrolling(value: float) -> void:
	if timestamp_scroll.scroll_horizontal != int(value):
		timestamp_scroll.scroll_horizontal = int(value)
	Timeline.set_scroll_x(self.scroll_horizontal)


func _on_timeline_v_scrolling_self(value: float) -> void:
	if track_controls_scroll.scroll_vertical != int(value):
		track_controls_scroll.scroll_vertical = int(value)
	Timeline.set_scroll_y(self.scroll_vertical)


func _on_global_scroll_changed(new_scroll: Vector2) -> void:
	if scroll_horizontal != int(new_scroll.x):
		scroll_horizontal = int(new_scroll.x)
	if scroll_vertical != int(new_scroll.y):
		scroll_vertical = int(new_scroll.y)
	if timestamp_scroll and timestamp_scroll.scroll_horizontal != int(new_scroll.x):
		timestamp_scroll.scroll_horizontal = int(new_scroll.x)
	if track_controls_scroll and track_controls_scroll.scroll_vertical != int(new_scroll.y):
		track_controls_scroll.scroll_vertical = int(new_scroll.y)
