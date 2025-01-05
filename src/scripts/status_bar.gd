class_name StatusBar extends HBoxContainer

static var instance: StatusBar

var frame_label: Label



func _ready() -> void:
	instance = self
	frame_label = get_node("FrameLabel")

	if View._on_frame_nr_changed.connect(_frame_update):
		printerr("Couldn't connect to _on_frame_nr_changed!")
	if Project._on_timeline_end_changed.connect(_frame_update):
		printerr("Couldn't connect to _on_timeline_end_changed!")

	
func _frame_update() -> void:
	frame_label.text = "Frame: %s/%s" % [View.frame_nr, Project.timeline_end]

