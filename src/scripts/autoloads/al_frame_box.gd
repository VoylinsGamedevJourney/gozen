extends Node
## Frame box
##
## This is the tool which helps to generate the images to display in the project view,
## it's also the tool to control the playhead.

signal _on_playhead_position_changed(value: int)


var playhead_position: int = 0: # Position in frames
	set = set_playhead_position

var timer: Timer = Timer.new()
var playing: bool = false
var playback_speed: float = 1.0 # TODO: Implement


func _ready() -> void:
	Printer.connect_error(
		ProjectManager._on_framerate_changed.connect(_on_framerate_changed))
	add_child(timer)
	Printer.connect_error(timer.timeout.connect(_next_frame))


func _input(a_event: InputEvent) -> void:
	if a_event.is_action_pressed("play_pause"):
		if playing:
			timer.stop()
		else:
			timer.start()
		playing = !playing


func _on_framerate_changed(a_value: float) -> void:
	timer.wait_time = 1.0 / a_value


func _next_frame() -> void:
	playhead_position += 1


func set_playhead_position(a_value: int) -> void:
	playhead_position = a_value
	_on_playhead_position_changed.emit(a_value)


func get_timestamp(a_frames: int = playhead_position) -> String:
	if a_frames == 0 or ProjectManager.framerate == 0:
		return "00:00:00,00"
	var l_frames_per_hours: int = int(ProjectManager.framerate) * 60 * 60
	var l_frames_per_minutes: int = int(ProjectManager.framerate) * 60
	var l_frames_per_seconds: int = int(ProjectManager.framerate)
	
	# Calculate hours
	var l_hours: int = int(float(a_frames) / l_frames_per_hours)
	var l_remaining_frames: int = a_frames % l_frames_per_hours

	# Calculate minutes
	var l_minutes: int = int(float(l_remaining_frames) / l_frames_per_minutes)
	l_remaining_frames %= l_frames_per_minutes

	# Calculate seconds
	var l_seconds: int = int(float(l_remaining_frames) / l_frames_per_seconds)

	# Calculate frames
	var l_frames: int = l_remaining_frames % l_frames_per_seconds
	return "%02d:%02d:%02d,%02d" % [l_hours, l_minutes, l_seconds, l_frames]
