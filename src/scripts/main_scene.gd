extends Control
## Mainly for handling the window itself

@onready var gozen_button: MenuButton = %GoZenButton
@onready var layout_tab_container: TabContainer = %LayoutTabContainer
@onready var layout_indicator: Panel = %LayoutIndicator
@onready var layout_buttons: Array[Button] = [
		%EditingLayoutButton,
		%SubtitlingLayoutButton,
		%RenderingLayoutButton ]



func _ready() -> void:
	@warning_ignore("return_value_discarded")
	gozen_button.get_popup().id_pressed.connect(_on_gozen_popup_option_pressed)

	# We need to manually fix the icon size for the items in the popup
	for l_id: int in gozen_button.get_popup().item_count:
		gozen_button.get_popup().set_item_icon_max_width(l_id, 20)

	# Check if the editor got opened with a project path
	for l_arg: String in OS.get_cmdline_args():
		if l_arg.ends_with(".gozen"):
			# TODO: Load project with the path found
			break

	_on_switch_layout(0)

	
func _input(a_event: InputEvent) -> void:
	if a_event.is_action_pressed("layout_1"):
		_on_switch_layout(0)
	elif a_event.is_action_pressed("layout_2"):
		_on_switch_layout(1)
	elif a_event.is_action_pressed("layout_3"):
		_on_switch_layout(2)


func _on_switch_layout(a_tab_index: int) -> void:
	if RenderLayout.is_rendering:
		print("Can't change layout when rendering!")
		return

	layout_tab_container.current_tab = a_tab_index
	layout_indicator.position.y = layout_buttons[a_tab_index].position.y + 2

	for i: int in layout_buttons.size():
		layout_buttons[i].modulate.a = 1.0 if a_tab_index == i else 0.5


func _on_gozen_popup_option_pressed(a_id: int) -> void:
	match a_id:
		0: Project.save_project(Project._path) # Save current project
		1: Project.save_project() # Save as ...
		2: Project.load_project() # Open file dialog to select project
		10: # Support
			@warning_ignore("return_value_discarded")
			OS.shell_open("https://ko-fi.com/voylin")
		11: pass # About   TODO: Create a popup window which display's GoZen info + version
		12: # Site    TODO: Make a real site
			@warning_ignore("return_value_discarded")
			OS.shell_open("https://github.com/VoylinsGamedevJourney/GoZen")

