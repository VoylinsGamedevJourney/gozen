extends VBoxContainer


@export var main_viewport: SubViewport
@export var audio_node: Node

var views: Array[TextureRect] = []

var is_dragging: bool = false
var was_dragging: bool = false
var was_playing: bool = false



func _ready() -> void:
	CoreLoader.append_after("Setting up view panel", _setup)
	CoreError.err_connect([
			CoreView._on_current_frame_changed.connect(set_frame),
			CoreView._on_update_frame_forced.connect(set_frame.bind(Project.playhead_pos))])


func _setup() -> void:
	for i: int in Project.tracks.size():
		_add_view(i)


func _add_view(a_id: int) -> void:
	if views.insert(a_id, TextureRect.new()):
		printerr("Couldn't insert view!")

	main_viewport.add_child(views[a_id])
	main_viewport.move_child(views[a_id], -(a_id + 1))


func _remove_view(a_id: int) -> void:
	views.remove_at(a_id)


#------------------------------------------------ FRAME HANDLING
func set_frame(_frame: int) -> void:
	for l_id: int in views.size():
		views[l_id].texture = CoreView.frames[l_id]


#------------------------------------------------ BUTTONS

func _on_play_button_pressed() -> void:
	CoreView._on_play_pressed()


func _on_rewind_button_pressed() -> void:
	pass # TODO: Make this work


func _on_forward_button_pressed() -> void:
	pass # TODO: Make this work

