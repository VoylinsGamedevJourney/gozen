class_name EditorUI extends HBoxContainer
## Editor UI
## 
## Layouts get added with a name in this form: 
## 'layout_name-random number', the random number is between
## 10000,99999 to make certain that no layout of the same type gets the
## same name.
##
## Config:
## [general]
## - layouts_order: [layout_id, layout_id, ...]
## [custom_icons]
## - layout_id: icon path


static var instance: EditorUI


var sidebar_menu_items: Dictionary = {
	0: ItemEntry.new("SIDEBAR_MENU_ITEM_MOVE_LAYOUT_UP", move_layout_up, "move_up", true),
	1: ItemEntry.new("SIDEBAR_MENU_ITEM_MOVE_LAYOUT_DOWN", move_layout_down, "move_down", true),
	2: ItemSeparator.new(),
	3: ItemEntry.new("SIDEBAR_MENU_ITEM_CHANGE_LAYOUT_ICON", open_change_icon_dialog, "settings_account_box", true),
	4: ItemSeparator.new(),
	5: ItemEntry.new("SIDEBAR_MENU_ITEM_ADD_LAYOUT", open_add_layout_popup, "add_box"),
	6: ItemEntry.new("SIDEBAR_MENU_ITEM_REMOVE_LAYOUT", remove_layout, "delete")}
var sidebar_menu_empty_items: Dictionary = {
	0: ItemEntry.new("SIDEBAR_MENU_ITEM_ADD_LAYOUT", open_add_layout_popup, "add_box") }

var sidebar_button_menu: PopupMenu
var button_group: ButtonGroup = ButtonGroup.new()

var config: ConfigFile = ConfigFile.new()
var config_path: String = Globals.PATH_EDITOR_UI

var indicator_pos: int


func _ready() -> void:
	instance = self
	
	if FileAccess.file_exists(config_path):
		config.load(config_path)
		for l_id: String in config.get_value("general", "layouts_order", []):
			add_layout(l_id.split("-")[0], l_id)
	else:
		# Creating default layouts
		add_layout("default")
		add_layout("subtitle_manager")
		add_layout("render_menu")


func _input(a_event: InputEvent) -> void:
	## Shortcuts for changing the editor layout.
	# TODO: Make it possible to change these shortcuts
	for l_layout_id: int in range(1,10):
		if a_event.is_action_pressed("editor_layout_%s" % l_layout_id):
			change_layout(l_layout_id - 1)
	
	if a_event.is_action_pressed("editor_layout_prev"):
		change_layout(%LayoutContainer.current_tab - 1)
	
	if a_event.is_action_pressed("editor_layout_next"):
		change_layout(%LayoutContainer.current_tab + 1)


func _process(a_delta: float) -> void:
	if %SidebarIndicator.position.y != indicator_pos:
		if abs(%SidebarIndicator.position.y - indicator_pos) < 0.01:
			%SidebarIndicator.position.y = indicator_pos
			return
		%SidebarIndicator.position.y = lerpf(%SidebarIndicator.position.y, indicator_pos, 15 * a_delta)


func _build_menu(a_data: Dictionary) -> PopupMenu:
	var l_menu := PopupMenu.new()
	for l_id: int in a_data:
		if a_data[l_id] is ItemSeparator:
			l_menu.add_separator(a_data[l_id].label)
		else:
			l_menu.add_item(a_data[l_id].label, l_id)
			l_menu.set_item_icon(l_id, Toolbox.get_icon_tex2d(a_data[l_id].item_icon))
	l_menu.size.y = 10
	l_menu.position = get_global_mouse_position()
	l_menu.mouse_exited.connect(Toolbox.free_node.bind(l_menu))
	return l_menu


func check_single_existing(a_layout_name: String) -> bool:
	for l_child: Node in %SidebarVBox.get_children():
		if l_child.name.split("-")[0] == a_layout_name:
			return true
	return false


func _on_sidebar_gui_event(a_event: InputEvent) -> void:
	if a_event is InputEventMouseButton and a_event.button_index == MOUSE_BUTTON_RIGHT:
		if a_event.is_pressed():
			var l_menu: PopupMenu = _build_menu(sidebar_menu_empty_items)
			
			l_menu.id_pressed.connect(_on_sidebar_empty_menu_pressed)
			add_child(l_menu)
			l_menu.popup()


func _on_sidebar_button_gui_event(a_event: InputEvent, a_button: Button) -> void:
	if a_event is InputEventMouseButton and a_event.button_index == MOUSE_BUTTON_RIGHT:
		if !a_event.is_pressed():
			return
		var l_menu: PopupMenu = _build_menu(sidebar_menu_items)
		
		l_menu.id_pressed.connect(_on_sidebar_button_menu_pressed.bind(a_button))
		add_child(l_menu)
		l_menu.popup()


func _on_sidebar_button_menu_pressed(a_id: int, a_button: Button) -> void:
	if not sidebar_menu_items[a_id] is ItemSeparator:
		if sidebar_menu_items[a_id].button_needed:
			sidebar_menu_items[a_id].function.call(a_button.name)
		else:
			sidebar_menu_items[a_id].function.call()


func _on_sidebar_empty_menu_pressed(a_id: int) -> void:
	if not sidebar_menu_empty_items[a_id] is ItemSeparator:
		sidebar_menu_empty_items[a_id].function.call()


func change_layout(a_id: int) -> void:
	if a_id <= (%LayoutContainer.get_child_count() - 1) and a_id >= 0:
		if !%SidebarVBox.get_child(a_id).button_pressed:
			%SidebarVBox.get_child(a_id).button_pressed = true
		%LayoutContainer.current_tab = a_id
		indicator_pos = a_id * 46


func open_add_layout_popup() -> void:
	get_tree().root.open_popup("add_editor_layout")


func add_layout(a_layout_name: String, a_id: String = "") -> void:
	# Check if layout type exists
	if !DirAccess.dir_exists_absolute("res://_layouts/layout_%s" % a_layout_name):
		remove_layout(a_id)
		return
	
	# Check if single use only or if a layout can be used in multiple instances
	var l_layout_data: LayoutModule = ModuleManager.get_layout_info(a_layout_name)
	
	if l_layout_data.single_only:
		if check_single_existing(a_layout_name):
			Printer.error(Globals.ERROR_MODULE_SINGLE_ONLY)
			return
	
	# Setting name for button and layout
	var l_layout: Node = l_layout_data.scene.instantiate()
	var l_button := Button.new()
	var l_icon_path: String = config.get_value("custom_icons", a_id, "")
	
	l_button.icon = l_layout_data.default_icon if l_icon_path == "" else load(l_icon_path)
	l_button.flat = true
	l_button.gui_input.connect(_on_sidebar_button_gui_event.bind(l_button))
	
	if a_id == "":
		randomize() # TODO: check if layout_id doesn't exist already
		var l_layout_id := "%s-%s" % [a_layout_name, randi_range(10000,99999)]
		var l_layout_order: PackedStringArray = config.get_value("general", "layouts_order", [])
		l_layout.name = l_layout_id
		l_button.name = l_layout_id
		l_button.icon = l_layout_data.default_icon
		
		# Updating the config file
		l_layout_order.append(l_layout_id)
		config.set_value("general", "layouts_order", l_layout_order)
		config.save(config_path)
	else:
		l_layout.name = a_id
		l_button.name = a_id
		if config.has_section_key("custom_icons", a_id):
			l_button.icon = load(config.get_value("custom_icons", a_id))
	
	l_button.expand_icon = true
	l_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l_button.custom_minimum_size = Vector2i(40,40)
	l_button.toggle_mode = true
	l_button.button_group = button_group
	l_button.tooltip_text = l_layout_data.layout_description
	
	# Setting button function
	l_button.pressed.connect(func() -> void: change_layout(l_button.get_index()))
	
	# Adding the nodes to the sidebar + tab container
	%SidebarVBox.add_child(l_button)
	%LayoutContainer.add_child(l_layout)


func move_layout_up(a_layout_id: String) -> void:
	_move_layout(a_layout_id, -1)


func move_layout_down(a_layout_id: String) -> void:
	_move_layout(a_layout_id, +1)


func _move_layout(a_layout_id: String, a_position: int) -> void:
	## Moving the layout one down in the order of the sidebar and layout container.
	var l_button: Node = %SidebarVBox.get_node(a_layout_id)
	var l_container: Node = %LayoutContainer.get_node(a_layout_id)
	var l_new_button_position := l_button.get_index() + a_position
	var l_new_order: PackedStringArray = []
	
	# Moving nodes to new position
	%SidebarVBox.move_child(
		l_button, clampi(l_new_button_position , 0, %SidebarVBox.get_child_count()))
	%LayoutContainer.move_child(
		l_container, clampi(l_new_button_position, 0, %LayoutContainer.get_child_count()))
	
	# Saving new order of layouts
	for l_child: Node in %SidebarVBox.get_children():
		l_new_order.append(l_child.name)
	config.set_value("general", "layouts_order", l_new_order)
	change_layout(l_new_button_position)
	config.save(config_path)


func remove_layout(a_layout_id: String) -> void:
	## Removing a layout and related stuff.
	# Removing nodes if exist
	if %SidebarVBox.has_node(a_layout_id):
		%SidebarVBox.get_node(a_layout_id).queue_free()
	if %LayoutContainer.has_node(a_layout_id):
		%LayoutContainer.get_node(a_layout_id).queue_free()
	
	# Adjusting configs
	ModuleManager.remove_config_layout(a_layout_id)
	var l_new_order: PackedStringArray = config.get_value("general", "layouts_order")
	
	l_new_order.remove_at(l_new_order.find(a_layout_id))
	config.set_value("general", "layouts_order", l_new_order)
	remove_custom_icon(a_layout_id)
	
	# TODO: Find a way to delete all custom layout files of the layout modules
	# (have a remove config files callable function in the resource?)
	
	change_layout(%LayoutContainer.current_tab)
	config.save(config_path)


func open_change_icon_dialog(a_layout_id: String) -> void:
	var l_dialog := DialogManager.get_layout_icon_dialog()
	
	l_dialog.file_selected.connect(_set_custom_icon.bind(%SidebarVBox.get_node(a_layout_id).name))
	l_dialog.canceled.connect(Toolbox.free_node.bind(l_dialog))
	
	add_child(l_dialog)
	l_dialog.popup_centered(Vector2i(500,600))


func _set_custom_icon(a_new_icon_path: String, a_layout_id: String) -> void:
	## Setting a custom icon for a sidebar button.
	if Toolbox.file_exists(a_new_icon_path, Globals.ERROR_NO_IMAGE_FOUND):
		var l_button: Button = %SidebarVBox.get_node(a_layout_id)
		
		config.set_value("custom_icons", a_layout_id, a_new_icon_path)
		l_button.icon = load(a_new_icon_path)
		config.save(config_path)


func remove_custom_icon(a_layout_id: String) -> void:
	## Removes the custom icon from sidebar and from config file.
	if config.has_section_key("custom_icons", a_layout_id):
		if %SidebarVBox.has_node(a_layout_id): # Checking if button isn't deleted yet
			%SidebarVBox.get_node(a_layout_id).icon = null
		config.erase_section_key("custom_icons", a_layout_id)
		config.save(config_path)


class ItemEntry:
	var label: String
	var function: Callable
	var item_icon: String
	var button_needed: bool
	
	
	func _init(a_label: String, a_function: Callable, a_item_icon: String, a_button_needed: bool = false) -> void:
		label = a_label
		function = a_function
		item_icon = a_item_icon
		button_needed = a_button_needed


class ItemSeparator:
	var label: String
	
	
	func _init(a_label: String = "") -> void:
		label = a_label
