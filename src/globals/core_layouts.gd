extends DataManager

const PATH_SETTINGS: String = "user://layouts_settings"

const PATH_LAYOUTS_DATA: String = "user://layouts_data/" # Path where layouts can save their data
const PATH_CUSTOM_LAYOUTS: String = "user://layouts/"

const PATH_LAYOUTS_SCENES: String = "res://layouts/"


var layouts: PackedStringArray = []
var _existing_layouts: Dictionary = {}


func _ready() -> void:
	CoreLoader.append("Loading layouts data", load_data)
	CoreLoader.append("Checking layouts", _check_layouts)
	CoreLoader.append("Checking layouts", _load_custom_layouts)


func save_data() -> void:
	_save_data_err(PATH_SETTINGS, "Saving data for CoreLayouts failed!")


func load_data() -> void:
	if FileAccess.file_exists(PATH_SETTINGS):
		_load_data_err(PATH_SETTINGS, "Loading data for CoreLayouts failed!")
	else: # Setting default main panels
		layouts.append_array([
			_create_layout_id("default_editor_layout"),
			_create_layout_id("default_subtitle_layout"),
			_create_layout_id("default_render_layout"),
		])
		save_data()


func _check_layouts() -> void:
	for l_layout: String in DirAccess.get_directories_at(PATH_LAYOUTS_SCENES):
		var l_path: String = PATH_LAYOUTS_SCENES + l_layout + "/layout.tres"

		if !FileAccess.file_exists(l_path):
			printerr("Couldn't find layout resource! ", l_path)
			continue
		
		var l_layout_node: Layout = load(l_path)
		if _check_layout(l_layout_node):
			_existing_layouts[l_layout] = l_layout_node
		else:
			printerr("Layout '%s' has incomplete data!" % l_layout)


func _check_layout(a_layout: Layout) -> bool:
	if a_layout == null:
		return false

	return !(a_layout.title == "" or a_layout.icon == null or a_layout.scene == null)


func _load_custom_layouts() -> void:
	# TODO: Implement this!
	# The way it should work is to first check the files PATH_LAYOUTS_DATA, to
	# see if the pck files don't override already existing files, and to see if
	# they don't add anything outside of their layout folder.
	# If everything checks out we can add it to the project, but we also need to
	# run _check_layout on it's Layout file!
	# Also check if the name has any '-' inside of it as this isn't allowed!
	print("Loading custom layouts isn't implemented yet!")


func _create_layout_id(a_layout_name: String) -> String:
	var l_name: String = "%s-%s" % [a_layout_name, randi_range(100000,999999)]

	while l_name in DirAccess.get_files_at(PATH_LAYOUTS_DATA):
		l_name = "%s-%s" % [a_layout_name, randi_range(100000,999999)]

	return l_name


func create_new_instance(a_layout_name: String) -> Control:
	if a_layout_name not in _existing_layouts.keys():
		printerr("Requested layout does not exist!")
		return null

	if a_layout_name.contains('-'):
		printerr("Layout names can't have an '-', if it has one it could indicate that this is an existing layout!")
		return null
	
	var l_scene: PackedScene = _existing_layouts[a_layout_name].scene
	var l_instance: Control = l_scene.instantiate()

	l_instance.name = _create_layout_id(a_layout_name)

	return l_instance


func get_existing_instance(a_name: String) -> Control:
	if a_name.get_slice('-', 0) not in _existing_layouts.keys():
		printerr("Requested layout does not exist!")
		return null

	if !a_name.contains('-'):
		printerr("Instance name does not include an ID at the end!")
		return null

	var l_scene: PackedScene = _existing_layouts[a_name.get_slice('-', 0)].scene
	var l_instance: Control = l_scene.instantiate()

	l_instance.name = a_name

	return l_instance


func get_icon(a_name: String) -> Texture2D:
	return _existing_layouts[a_name.get_slice('-', 0)].icon


func get_title(a_name: String) -> String:
	return _existing_layouts[a_name.get_slice('-', 0)].title
	
