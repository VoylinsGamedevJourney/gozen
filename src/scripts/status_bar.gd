class_name StatusBar extends HBoxContainer

static var instance: StatusBar

@onready var frame_label: Label = %StatusFrameLabel
@onready var time_label: Label = %StatusTimeLabel


var time: PackedInt64Array = [0,0,0] # Hours, Minutes, Seconds



func _ready() -> void:
	instance = self

	@warning_ignore_start("return_value_discarded")
	View.frame_nr_changed.connect(_frame_update)
	View.frame_nr_changed.connect(_time_update)
	Project._on_timeline_end_changed.connect(_frame_update.bind(View.frame_nr))

	
func _frame_update(a_frame_nr: int) -> void:
	frame_label.text = "%s/%s" % [a_frame_nr, Project.timeline_end]


func _time_update(a_frame_nr: int) -> void:
	@warning_ignore_start("integer_division")
	time[2] = floori(a_frame_nr / Project.framerate) # Total seconds
	time[0] = int(time[2] / 3600) # Setting the hours
	time[2] = int(fmod(time[2], 3600)) # Calculate remaining seconds
	time[1] = int(time[2] / 60) # Setting the minutes
	time[2] = int(fmod(time[2], 60)) # Setting the seconds

	time_label.text = "%d:%02d:%02d" % [time[0], time[1], time[2]]
