class_name WindowResizeHandles extends Control


static var instance: WindowResizeHandles

var resizing: bool = false  ## Bool to check if currently resizing.
var resize_node: Control    ## Handle used for deciding how to resize.
var tiling: bool = false


func _ready() -> void:
	instance = self
	
	check_tiling_window_manager()
	
	get_window().min_size = Vector2i(700,600)
	
	$Right.gui_input.connect(_on_gui_input.bind($Right))
	$Bottom.gui_input.connect(_on_gui_input.bind($Bottom))
	$Corner.gui_input.connect(_on_gui_input.bind($Corner))


func check_tiling_window_manager() -> void:
	if OS.get_name() in ["Windows", "macOS"]:
		return # No tiling for these operating systems
	for l_de: String in ["SWAYSOCK", "I3SOCK"]:
		tiling = OS.has_environment(l_de)
		if tiling:
			visible = false
			return # Environment found so exit


#region #####################  Resizing logic  #################################

func _on_gui_input(a_event: InputEvent, a_node: Control) -> void:
	if a_event is InputEventMouseButton and a_event.button_index == 1:
		if !resizing:
			resize_node = a_node
		resizing = a_event.is_pressed()


func _process(_delta: float) -> void:
	if resizing:
		var l_window_pos: Vector2i = DisplayServer.window_get_position(get_window().get_window_id())
		var l_relative_mouse_pos: Vector2i = (DisplayServer.mouse_get_position() -l_window_pos)
		
		if resize_node in [$Bottom, $Corner]:
			get_window().size.y = l_relative_mouse_pos.y
		if resize_node in [$Right, $Corner]:
			get_window().size.x = l_relative_mouse_pos.x

#endregion
