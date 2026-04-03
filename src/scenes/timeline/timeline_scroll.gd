extends ScrollContainer
## The scroll handler for the timeline stuff.

@export var timestamp_scroll: ScrollContainer
@export var track_controls_scroll: ScrollContainer


var current_zoom: float = 1.0



func _ready() -> void:
	timestamp_scroll.get_h_scroll_bar().scrolling.connect(_on_timestamp_scrolling)
	track_controls_scroll.get_v_scroll_bar().scrolling.connect(_on_timeline_v_scrolling)
	self.get_h_scroll_bar().scrolling.connect(_on_timeline_h_scrolling)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var event_mouse_button: InputEventMouseButton = event
		if !event_mouse_button.pressed:
			return

		# We need to change the scroll direction of this node
		# TODO: Implemented as a PR for Godot (#115545)
		var h_step: float = scroll_horizontal_custom_step
		var v_step: int = floori(scroll_vertical_custom_step)

		if event.is_action_pressed("scroll_left", false, true):
			scroll_horizontal -= floori(h_step * maxf(current_zoom, 2.0))
			accept_event()
			get_h_scroll_bar().scrolling.emit()
		elif event.is_action_pressed("scroll_right", false, true):
			scroll_horizontal += floori(h_step * maxf(current_zoom, 2.0))
			accept_event()
			get_h_scroll_bar().scrolling.emit()
		elif event.is_action_pressed("scroll_up", false, true):
			scroll_vertical -= v_step
			accept_event()
			get_h_scroll_bar().scrolling.emit()
		elif event.is_action_pressed("scroll_down", false, true):
			scroll_vertical += v_step
			accept_event()
			get_h_scroll_bar().scrolling.emit()


func _on_timestamp_scrolling() -> void:
	self.scroll_horizontal = timestamp_scroll.scroll_horizontal


func _on_timeline_v_scrolling() -> void:
	self.scroll_vertical = track_controls_scroll.scroll_vertical


func _on_timeline_h_scrolling() -> void:
	timestamp_scroll.scroll_horizontal = self.scroll_horizontal


func _on_timeline_zoom_changed(new_zoom: float) -> void:
	current_zoom = new_zoom
	_on_timeline_h_scrolling()
