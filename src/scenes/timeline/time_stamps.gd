extends PanelContainer


const COLOR_TEXT: Color = Color(0.85, 0.85, 0.85, 0.5)
const COLOR_TICK: Color = Color(0.4, 0.4, 0.4, 0.5)
const STEPS: PackedInt32Array = [1, 5, 10, 30, 60, 150, 300, 600, 1800, 3600]


@onready var scroll: ScrollContainer = get_parent()
@export var timeline_scroll: ScrollContainer = get_parent()


var current_zoom: float = 1.0
var scrubbing: bool = false



func _ready() -> void:
	scroll.get_h_scroll_bar().value_changed.connect(_force_refresh)
	timeline_scroll.get_h_scroll_bar().value_changed.connect(_force_refresh)


func _force_refresh(_v: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				scrubbing = true
				_seek_to_mouse()
			else:
				scrubbing = false
	elif event is InputEventMouseMotion and scrubbing:
		_seek_to_mouse()


func _seek_to_mouse() -> void:
	var frame: int = maxi(0, floori(get_local_mouse_position().x / current_zoom))
	EditorCore.set_frame(frame)


func _draw() -> void:
	var first_frame: int = int(scroll.scroll_horizontal / current_zoom)
	var last_frame: int = int((scroll.scroll_horizontal + size.x) / current_zoom) + 1

	var major_step: int = _get_major_frame_step()
	var minor_step: int = int(major_step / 5.0)

	var start_frame: int = first_frame - (first_frame % minor_step)

	for frame: int in range(start_frame, last_frame, minor_step):
		var x: float = frame * current_zoom

		if x < scroll.scroll_horizontal - 100 or x > scroll.scroll_horizontal + size.x + 100:
			continue

		var is_major: int = frame % major_step == 0
		var tick_h: int = 12 if is_major else 6

		if is_major:
			draw_string(
				get_theme_default_font(),
				Vector2(x + 4, size.y - 8),
				Utils.format_time_str_from_frame(frame, Project.get_framerate(), true),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				COLOR_TEXT)

		draw_line(
			Vector2(x, size.y),
			Vector2(x, size.y - tick_h),
			COLOR_TICK
		)


func _on_timeline_zoom_changed(new_zoom: float) -> void:
	current_zoom = new_zoom
	queue_redraw()


func _get_major_frame_step() -> int:
	# 120 pixels between major ticks
	var frames: float =  120.0 / current_zoom

	for step: int in STEPS:
		if step >= frames:
			return step

	return STEPS[-1]


