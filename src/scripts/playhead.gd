class_name Playhead extends Panel


@onready var main: Control = get_parent()

static var instance: Playhead
static var frame_nr: int = 0
static var is_moving: bool = false

var playback_before_moving: bool = false


func _ready() -> void:
	instance = self
	View._set_frame(0, true)


func _process(_delta: float) -> void:
	if is_moving:
		var l_new_frame: int = clampi(
				floori(main.get_local_mouse_position().x / Project.timeline_scale),
				0, Project.timeline_end)
		if l_new_frame != frame_nr:
			View._set_frame(l_new_frame, true)


func _on_main_gui_input(a_event: InputEvent) -> void:
	if a_event is InputEventMouseButton:
		if (a_event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if a_event.is_pressed():
				is_moving = true
				playback_before_moving = View.is_playing

				if playback_before_moving:
					View._on_play_button_pressed()
			elif a_event.is_released():
				is_moving = false

				if playback_before_moving:
					View._on_play_button_pressed()


func step() -> int:
	# Go one frame further
	frame_nr += 1
	position.x += Project.timeline_scale

	_on_end_check()
	return frame_nr


func move(a_frame_nr: int) -> void:
	# Move playhead frame further
	frame_nr = a_frame_nr
	position.x = Project.timeline_scale * frame_nr

	_on_end_check()


func skip(a_amount: int) -> int:
	# Move playhead frame further
	frame_nr += a_amount
	position.x = Project.timeline_scale * frame_nr

	_on_end_check()
	return frame_nr


func _on_end_check() -> void:
	if frame_nr >= Project.timeline_end:
		View._on_end_reached()
		frame_nr = Project.timeline_end

