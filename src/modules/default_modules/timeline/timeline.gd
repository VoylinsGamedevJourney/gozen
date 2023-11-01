extends ModuleTimeline

var current_frame : int = 0

var zoom: float = 500

var indicator_pos: int = 0
var indicator_moving: bool = false


func _ready() -> void:
	ProjectManager._on_framerate_changed.connect(_timeline_setup)
	ProjectManager._on_project_loaded.connect(_timeline_setup)


func _timeline_setup() -> void:
	_setting_timeline_size()


func _setting_timeline_size() -> void:
	# Setting the size of the timeline
	var framerate : float = ProjectManager.get_framerate()
	var total_size: float = SettingsManager.get_timeline_max_size() * framerate
	var new_size := total_size / zoom
	%MainBox.custom_minimum_size.x = new_size
	%TopTimeline.custom_minimum_size.x = new_size





func _on_tracks_v_box_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		indicator_moving = event.button_index == 1 and event.is_pressed()


func _process(_delta: float) -> void:
	if indicator_moving:
		var framerate : float = ProjectManager.get_framerate()
		# Use different function for playing as indicator position != current frame
		indicator_pos = clampi(%MainBox.get_local_mouse_position().x,0, SettingsManager.get_timeline_max_size() * framerate)
		
		%FrameIndicator.position.x = indicator_pos
		current_frame = indicator_pos * zoom
		print("current frame %s and indicator pos %s" % [current_frame, indicator_pos])
