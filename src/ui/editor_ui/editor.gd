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


var sidebar_menu_items := {
	0: ItemEntry.new("SIDEBAR_MENU_ITEM_MOVE_LAYOUT_UP", move_layout_up, "move_up", true),
	1: ItemEntry.new("SIDEBAR_MENU_ITEM_MOVE_LAYOUT_DOWN", move_layout_down, "move_down", true),
	2: ItemSeparator.new(),
	3: ItemEntry.new("SIDEBAR_MENU_ITEM_CHANGE_LAYOUT_ICON", open_change_icon_dialog, "settings_account_box", true),
	4: ItemSeparator.new(),
	5: ItemEntry.new("SIDEBAR_MENU_ITEM_ADD_LAYOUT", open_add_layout_popup, "add_box"),
	6: ItemEntry.new("SIDEBAR_MENU_ITEM_REMOVE_LAYOUT", remove_layout, "delete")}
var sidebar_menu_empty_items := {
	0: ItemEntry.new("SIDEBAR_MENU_ITEM_ADD_LAYOUT", open_add_layout_popup, "add_box")
}


var sidebar_button_menu: PopupMenu
var button_group: ButtonGroup = ButtonGroup.new()

var config := ConfigFile.new()
var config_path: String = Globals.PATH_EDITOR_UI

var indicator_pos: int


func _ready() -> void:
	instance = self
	
	if FileAccess.file_exists(config_path):
		config.load(config_path)
		var layout_order: PackedStringArray = config.get_value("general", "layouts_order", [])
		for id: String in layout_order:
			add_layout(id.split("-")[0], id)
	else:
		# Creating default layouts
		add_layout("default")
		add_layout("subtitle_manager")
		add_layout("render_menu")


func _input(event: InputEvent) -> void:
	## Shortcuts for changing the editor layout.
	# TODO: Make it possible to change these shortcuts
	for layout_id in range(1,10):
		if event.is_action_pressed("editor_layout_%s" % layout_id):
			change_layout(layout_id - 1)
	if event.is_action_pressed("editor_layout_prev"):
		change_layout(%LayoutContainer.current_tab - 1)
	if event.is_action_pressed("editor_layout_next"):
		change_layout(%LayoutContainer.current_tab + 1)


func _process(delta: float) -> void:
	if %SidebarIndicator.position.y != indicator_pos:
		if abs(%SidebarIndicator.position.y - indicator_pos) < 0.01:
			%SidebarIndicator.position.y = indicator_pos
			return
		%SidebarIndicator.position.y = lerpf(%SidebarIndicator.position.y, indicator_pos, 15 * delta)


func _build_menu(data: Dictionary) -> PopupMenu:
	var menu := PopupMenu.new()
	for id: int in data:
		if data[id] is ItemSeparator:
			menu.add_separator(data[id].label)
		else:
			menu.add_item(data[id].label, id)
			menu.set_item_icon(id, Toolbox.get_icon_tex2d(data[id].item_icon))
	menu.size.y = 10
	menu.position = get_global_mouse_position()
	menu.mouse_exited.connect(func(): menu.queue_free())
	return menu


func check_single_existing(layout_name: String) -> bool:
	for child: Node in %SidebarVBox.get_children():
		if child.name.split("-")[0] == layout_name:
			return true
	return false


func _on_sidebar_gui_event(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.is_pressed():
			var menu := _build_menu(sidebar_menu_empty_items)
			menu.id_pressed.connect(_on_sidebar_empty_menu_pressed)
			add_child(menu)
			menu.popup()


func _on_sidebar_button_gui_event(event: InputEvent, button: Button) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if !event.is_pressed():
		return
	var menu := _build_menu(sidebar_menu_items)
	menu.id_pressed.connect(_on_sidebar_button_menu_pressed.bind(button))
	add_child(menu)
	menu.popup()


func _on_sidebar_button_menu_pressed(id: int, button: Button) -> void:
	if not sidebar_menu_items[id] is ItemSeparator:
		if sidebar_menu_items[id].button_needed:
			sidebar_menu_items[id].function.call(button.name)
		else:
			sidebar_menu_items[id].function.call()


func _on_sidebar_empty_menu_pressed(id: int) -> void:
	if not sidebar_menu_empty_items[id] is ItemSeparator:
		sidebar_menu_empty_items[id].function.call()


func change_layout(id: int) -> void:
	if id <= (%LayoutContainer.get_child_count() - 1) and id >= 0:
		if !%SidebarVBox.get_child(id).button_pressed:
			%SidebarVBox.get_child(id).button_pressed = true
		%LayoutContainer.current_tab = id
		indicator_pos = id * 46


func open_add_layout_popup() -> void:
	PopupManager.open_popup(PopupManager.POPUP.ADD_EDITOR_LAYOUT)


func add_layout(layout_name: String, id: String = "") -> void:
	# Check if layout type exists
	if !DirAccess.dir_exists_absolute("res://_layouts/layout_%s" % layout_name):
		remove_layout(id)
		return
	# Check if single use only or if a layout can be used in multiple instances
	var layout_data: LayoutModule = ModuleManager.get_layout_info(layout_name)
	if layout_data.single_only:
		if check_single_existing(layout_name):
			Printer.error("Module is single only, already in sidebar present!")
			return
	# Setting name for button and layout
	var button := Button.new()
	button.flat = true
	button.gui_input.connect(_on_sidebar_button_gui_event.bind(button))
	var layout: Node = layout_data.scene.instantiate()
	if id == "":
		randomize() # TODO: check if layout_id doesn't exist already
		var layout_id := "%s-%s" % [layout_name, randi_range(10000,99999)]
		var layout_order: PackedStringArray = config.get_value("general", "layouts_order", [])
		layout.name = layout_id
		button.name = layout_id
		button.icon = layout_data.default_icon
		
		# Updating the config file
		layout_order.append(layout_id)
		config.set_value("general", "layouts_order", layout_order)
		config.save(config_path)
	else:
		layout.name = id
		button.name = id
		if config.has_section_key("custom_icons", id):
			button.icon = load(config.get_value("custom_icons", id))
	
	# Setting button data
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.custom_minimum_size = Vector2i(40,40)
	button.toggle_mode = true
	button.button_group = button_group
	button.tooltip_text = layout_data.layout_description
	
	# Setting button function
	button.pressed.connect(change_layout.bind(%SidebarVBox.get_child_count()))
	
	# Setting the button icon
	var icon_path: String = config.get_value("custom_icons", id, "")
	button.icon = layout_data.default_icon if icon_path == "" else load(icon_path)
	
	# Adding the nodes to the sidebar + tab container
	%SidebarVBox.add_child(button)
	%LayoutContainer.add_child(layout)


func move_layout_up(layout_id: String) -> void:
	_move_layout(layout_id, -1)


func move_layout_down(layout_id: String) -> void:
	_move_layout(layout_id, +1)


func _move_layout(layout_id: String, pos: int) -> void:
	## Moving the layout one down in the order of the sidebar and layout container.
	var button: Node = %SidebarVBox.get_node(layout_id)
	var container: Node = %LayoutContainer.get_node(layout_id)
	var button_pos := button.get_index()
	%SidebarVBox.move_child(
		button, 
		clampi(button_pos + pos, 0, %SidebarVBox.get_child_count()))
	%LayoutContainer.move_child(
		container, 
		clampi(button_pos + pos, 0, %SidebarVBox.get_child_count()))
	# Saving new order of layouts
	var new_order: PackedStringArray = []
	for child: Node in %SidebarVBox.get_children():
		new_order.append(child.name)
	config.set_value("general", "layouts_order", new_order)
	remove_custom_icon(layout_id)
	config.save(config_path)


func remove_layout(layout_id: String) -> void:
	## Removing a layout and related stuff.
	# Removing nodes if exist
	if %SidebarVBox.has_node(layout_id):
		%SidebarVBox.get_node(layout_id).queue_free()
	if %LayoutContainer.has_node(layout_id):
		%LayoutContainer.get_node(layout_id).queue_free()
	# Adjusting configs
	ModuleManager.remove_config_layout(layout_id)
	var new_order: PackedStringArray = config.get_value("general", "layouts_order")
	new_order.remove_at(new_order.find(layout_id))
	config.set_value("general", "layouts_order", new_order)
	remove_custom_icon(layout_id)
	# TODO: Find a way to delete all custom layout files of the layout modules
	# (have a remove config files callable function in the resource?)
	config.save(config_path)


func open_change_icon_dialog(layout_id: String) -> void:
	var button: Button = %SidebarVBox.get_node(layout_id)
	var dialog := DialogManager.get_layout_icon_dialog()
	dialog.file_selected.connect(_set_custom_icon.bind(button.name))
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(500,600))


func _set_custom_icon(new_icon_path: String, layout_id: String) -> void:
	## Setting a custom icon for a sidebar button.
	if !FileAccess.file_exists(new_icon_path):
		Printer.error("No image file found at %s!" % new_icon_path)
		return
	config.set_value("custom_icons", layout_id, new_icon_path)
	var button: Button = %SidebarVBox.get_node(layout_id)
	button.icon = load(new_icon_path)
	config.save(config_path)


func remove_custom_icon(layout_id: String) -> void:
	## Removes the custom icon from sidebar and from config file.
	if config.has_section_key("custom_icons", layout_id):
		if %SidebarVBox.has_node(layout_id): # Checking if button isn't deleted yet
			%SidebarVBox.get_node(layout_id).icon = null
		config.erase_section_key("custom_icons", layout_id)
		config.save(config_path)


class ItemEntry:
	var label: String
	var function: Callable
	var item_icon: String
	var button_needed: bool
	
	
	func _init(_label: String, _function: Callable, _item_icon: String, _button_needed: bool = false) -> void:
		self.label = _label
		self.function = _function
		self.item_icon = _item_icon
		self.button_needed = _button_needed


class ItemSeparator:
	var label: String
	
	
	func _init(_label: String = "") -> void:
		self.label = _label
