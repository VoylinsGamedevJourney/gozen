extends Control
## Default layout module
##
## Creates a layout with 10 different resize-able panels/tab containers. 

# TODO: Make module instances have a custom ID, but different tab name
# 		Possible solution, create module node with module name, inside that
#		Control node the actual module with the idin the name

const SECTION_SPLITS := "splits"
const SECTION_PANELS := "panels"
const SECTION_TABS := "tabs"

const PATH_MODULE_DATA := "res://_modules/%s/info.tres"
var config_path: String
var config := ConfigFile.new()

var splits := {}
var panels := {}
var tabs := {}


func _ready() -> void:
	# Getting all splits, tab containers and panels 
	_check_node($MainSplit) # (looping function)
	
	# Check if config exists
	config_path = ModuleManager.get_config_file(ModuleManager.TYPE.LAYOUT, name)
	if FileAccess.file_exists(config_path):
		load_config()
	else:
		set_default_tabs()
	
	# Hide panels with no children
	for tab_container: String in tabs:
		tabs[tab_container].get_parent().visible = tabs[tab_container].get_tab_count() != 0


func _check_node(node: Node) -> void:
	## This checks all nodes of the empty layout at startup
	## creating a list of all panels, tab and split containers.
	if node is PanelContainer:
		panels[node.name] = node
	if node is TabContainer:
		tabs[node.name] = node
		return
	if node is SplitContainer:
		splits[node.name] = node
		node.dragged.connect(save_split_offset.bind(node.name))
	for child: Node in node.get_children():
		_check_node(child)


func load_config() -> void:
	config.load(config_path) # Config exists, loading in settings
	
	# Go through all offsets and tabs modules
	var sections: PackedStringArray = config.get_sections()
	if SECTION_SPLITS in sections:
		for key: String in config.get_section_keys(SECTION_SPLITS):
			splits[key].split_offset = config.get_value(SECTION_SPLITS, key)
	if SECTION_TABS in sections:
		for tab_container: String in config.get_section_keys(SECTION_TABS):
			_add_modules(config.get_value(SECTION_TABS, tab_container, []), tab_container)


func set_default_tabs() -> void:
	add_module("media_pool", "LeftTopTabs")
	add_module("project_view", "MiddleTopTabs")
	add_module("timeline", "MiddleBottomTabs")


func save_split_offset(split_offset: int, split_container: String) -> void:
	config.set_value(SECTION_SPLITS, split_container, split_offset)
	config.save(config_path)


func add_module(module_name: String, tab_container: String) -> void:
	## Adding module to the correct tab container and saving the config
	## with the updated info.
	var module_data: Module = load(PATH_MODULE_DATA % module_name)
	var module: Control = module_data.scene.instantiate()
	module.name = ModuleManager.create_module_id(ModuleManager.TYPE.MODULE, module_name)
	tabs[tab_container].add_child(module)
	var tab_index: int = module.get_index()
	var tab_name: String = Toolbox.beautify_name(module_name)
	tabs[tab_container].get_tab_bar().set_tab_title(tab_index, tab_name)
	var array: PackedStringArray = config.get_value(SECTION_TABS, tab_container, [])
	array.append(module_name)
	config.set_value(SECTION_TABS, tab_container, array)
	config.save(config_path)


func _add_modules(module_names: PackedStringArray, tab_container: String) -> void:
	## Should not be called manually as this only gets called on startup.
	## We don't use add_module for this as we don't need to create a new id,
	## nor do we need to add it to the config again.
	for module_name: String in module_names:
		var module_data: Module = load(PATH_MODULE_DATA % module_name.split('-')[0])
		var module: Control = module_data.scene.instantiate()
		module.name = module_name # Adding  existing name with existing identifier
		tabs[tab_container].add_child(module)
		var tab_index: int = module.get_index()
		var tab_name: String = Toolbox.beautify_name(module_name)
		tabs[tab_container].get_tab_bar().set_tab_title(tab_index, tab_name)


func move_module_to_tabs(module_name: String, tabs_origin: String, tabs_dest: String) -> void:
	## Function to move an existing module from one tab container to another.
	var module: Control = tabs[tabs_origin].get_node(module_name)
	module.reparent(tabs[tabs_dest])
	
	# Changin + saving config
	var new_origin: PackedStringArray = config.get_value(SECTION_TABS, tabs_origin)
	var new_dest: PackedStringArray = config.get_value(SECTION_TABS, tabs_dest)
	new_origin.remove_at(new_origin.find(module_name))
	new_dest.append(module_name)
	config.set_value(SECTION_TABS, tabs_origin, new_origin)
	config.set_value(SECTION_TABS, tabs_dest, new_dest)
	config.save(config_path)


func remove_module(module_name: String, tab_container: String) -> void:
	## Removing a module from a tab container permanently
	tabs[tab_container].get_node(module_name).queue_free()
	var new_order: PackedStringArray = []
	for child: Node in tabs[tab_container].get_children():
		new_order.append(child.name)
	config.set_value(SECTION_TABS, tab_container, new_order)
	config.save(config_path)
