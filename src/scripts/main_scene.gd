extends Control
## Mainly for handling the window itself

@export var main_tab_container: TabContainer
@export var layout_buttons: Array[Button]
@export var layout_indicator: Panel



var resizing: bool = false
var new_size: Vector2i = Vector2i.ZERO

var moving: bool = false
var move_offset: Vector2 = Vector2.ZERO

var maximized: bool = false
var old_size: Rect2i


func _ready() -> void:
	for l_arg: String in OS.get_cmdline_args():
		if l_arg.ends_with(".gozen"):
			# TODO: Load project with the path found
			break

	if OS.get_name() == "Linux":
		var l_output: Array = []

		if OS.execute("echo", ["$XDG_CURRENT_DESKTOP"], l_output) == -1:
			return

		if l_output[0] == "i3\n":
			%ResizeHandles.queue_free()
			%WindowButtons.queue_free()
			get_window().borderless = false

	_on_switch_layout(0)


func _process(_delta: float) -> void:
	if resizing:
		get_window().size = new_size

	
func _input(a_event: InputEvent) -> void:
	if a_event.is_action_pressed("layout_1"):
		_on_switch_layout(0)
	if a_event.is_action_pressed("layout_2"):
		_on_switch_layout(1)


# 1 = Right, 2 = Bottom, 3 = Corner
func _on_resize_handle_gui_input(a_event: InputEvent, a_handle: int) -> void:
	if a_event is InputEventMouseButton and a_event.get("button_index") == 1:
		if !resizing and a_event.is_pressed():
			resizing = true
			new_size = get_window().size
		elif !a_event.is_pressed():
			resizing = false

	if resizing:
		# Right + corner handling
		if a_handle & 1:
			new_size.x = int(get_global_mouse_position().x)
		
		# Bottom + corner handling
		if a_handle & 2:
			new_size.y = int(get_global_mouse_position().y)


func _on_menu_bar_panel_gui_input(a_event: InputEvent) -> void:
	if a_event is InputEventMouseButton and a_event.get("button_index") == 1:
		if !moving and a_event.is_pressed():
			moving = true
			move_offset = get_viewport().get_mouse_position()
		elif !a_event.is_pressed():
			moving = false

	if moving:
		get_window().position += Vector2i(get_global_mouse_position() - move_offset)


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_maximize_button_pressed() -> void:
	if maximized:
		get_window().set_size(old_size.size)
		get_window().set_position(old_size.position)
		maximized=false

	else:
		old_size=Rect2i(get_window().position,get_window().size)
		get_window().set_size(DisplayServer.screen_get_usable_rect().size)
		get_window().set_position(DisplayServer.screen_get_usable_rect().position)
		maximized=true


func _on_minimize_button_pressed() -> void:
	get_window().mode = Window.MODE_MINIMIZED


func _on_switch_layout(a_tab_index: int) -> void:
	if RenderLayout.is_rendering:
		print("Can't change layout when rendering!")
		return

	# Switch the tab in the MainTabContainer
	main_tab_container.current_tab = a_tab_index

	# Move the indicator to the correct button (+3 for the padding of container)
	layout_indicator.position.x = layout_buttons[a_tab_index].position.x + 3

	# Make other layout buttons dimmer to be more clear
	for i: int in layout_buttons.size():
		layout_buttons[i].modulate.a = 1.0 if a_tab_index == i else 0.5

