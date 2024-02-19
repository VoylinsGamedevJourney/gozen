class_name EditorUI extends HBoxContainer
## Info:
## Layouts get added with a name in this form: 
## 'layout_name-random number', the random number is between
## 10000,99999 to make certain that no layout of the same type gets the
## same name.
##
## Layout names can not contain '-' as this is used to split the name.
##
## Config:
## [general]
## - layouts_order: []

# TODO:
# - Figure out re-ordering buttons in sidebar; (Right click shows menu for 'move up' and 'move down'?)
# - Adding new layouts to sidebar (Right menu click?);
# - Shortcuts for easily switching between different layouts (ctrl+number?);
# - Make it possible to set custom icons (Right click menu);

var instance: EditorUI
var config := ConfigFile.new()


func _ready():
	if instance != null:
		printerr("No 2 'EditorUI' screens are allowed!")
		self.queue_free()
		return
	instance = self
	
	# Making certain paths to configs and custome layout modules exist
	var path := "globals/path/modules/%s"
	for dir in [
		ProjectSettings.get_setting(path % "custom_layout_modules"),
		ProjectSettings.get_setting(path % "layout_cfg")]:
		if DirAccess.dir_exists_absolute(dir.replace("user://", OS.get_user_data_dir())):
			DirAccess.make_dir_absolute(dir.replace("user://", OS.get_user_data_dir()))
	
	path = ProjectSettings.get_setting("globals/path/editor_ui")
	if FileAccess.file_exists(path):
		config.load(path)
		set_layouts()
	else:
		set_default_layout()


## Loading in all layouts
func load_layouts() -> void:
	# First load in all custom layouts
	var path: String = ProjectSettings.get_setting("globals/path/modules/custom_layout_modules")
	if DirAccess.dir_exists_absolute(path.replace("user://", OS.get_user_data_dir())):
			DirAccess.make_dir_absolute(path.replace("user://", OS.get_user_data_dir()))
	var dir := DirAccess.open(path)
	for module_name: String in dir.get_files():
		if not ".pck" in module_name:
			print("'%s' does not have a pck extension!")
			continue
		Printer.debug("Loading in layout module '%s' ..." % module_name)
		ProjectSettings.load_resource_pack(path + module_name)


func set_default_layout() -> void:
	# TODO: Change default icons
	add_layout("file_manager")
	add_layout("default")
	add_layout("render_menu")


func set_layouts() -> void:
	## Happens on startup when config file is present. Getting the data
	## from the config file
	var layout_order: PackedStringArray = config.get_value("general", "layouts_order")
	print(layout_order)
	for id: String in layout_order:
		add_layout(id.split("-")[0], id)


func _get_available_layouts() -> PackedStringArray:
	var data : PackedStringArray
	var dir := DirAccess.open("res://layout_modules")
	for module_dir: String in dir.get_directories():
		data.append(module_dir.lstrip("layout_"))
	return data


func add_layout(layout_name: String, id: String = "") -> void:
	var layout_data: LayoutModule = load("res://layout_modules/layout_%s.tres" % layout_name)
	# Check if single only or not
	if layout_data.single_only:
		for child: Node in %SidebarVBox.get_children():
			if child.name.split("-")[0] == layout_name:
				Printer.error("Module is single only, already in sidebar present!")
				return
	
	var button := Button.new()
	var layout: Node = layout_data.scene.instantiate()
	if id == "":
		var layout_id := "%s-%s" % [layout_name, randi_range(10000,99999)]
		var layout_order: PackedStringArray = config.get_value("general", "layouts_order", [])
		layout.name = layout_id
		button.name = layout_id
		# Updating the config file
		layout_order.append(layout_id)
		config.set_value("general", "layouts_order", layout_order)
		config.save(ProjectSettings.get_setting("globals/path/editor_ui"))
	else:
		layout.name = id
		button.name = id
	button.icon = layout_data.default_icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2i(40,40)
	var tab_nr := %SidebarVBox.get_child_count()
	button.pressed.connect(func(): 
		%LayoutContainer.current_tab = tab_nr)
	# Adding the nodes to the sidebar + tab container
	%SidebarVBox.add_child(button)
	%LayoutContainer.add_child(layout)


func move_up(layout_id: String) -> void:
	# TODO: move the Sidebar button, but also the tab itself + 
	# update the button pressed function
	pass


func move_down(layout_id: String) -> void:
	# TODO: move the Sidebar button, but also the tab itself + 
	# update the button pressed function
	pass


func set_custom_icon(layout_id: String, new_icon_path: Texture) -> void:
	# TODO: Add to config under category "custom_icons" section
	# Key is layout_id and key value is the new_icon_path
	# After changin that in the config, save config and change the icon in
	# the sidebar
	
	pass
