class_name Playhead extends Panel


@onready var main: Control = get_parent()

static var instance: Playhead
static var is_moving: bool = false

var playback_before_moving: bool = false


func _ready() -> void:
	instance = self
	if View._on_frame_nr_changed.connect(move):
		printerr("Couldn't connect to _on_frame_nr_changed!")


func _process(_delta: float) -> void:
	if is_moving:
		var l_new_frame: int = clampi(
				floori(main.get_local_mouse_position().x / Project.timeline_scale),
				0, Project.timeline_end)
		if l_new_frame != View.frame_nr:
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


func move() -> void:
	position.x = Project.timeline_scale * View.frame_nr

