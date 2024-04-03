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
	for l_tab_container: String in tabs:
		tabs[l_tab_container].get_parent().visible = tabs[l_tab_container].get_tab_count() != 0


func _check_node(a_node: Node) -> void:
	## This checks all nodes of the empty layout at startup
	## creating a list of all panels, tab and split containers.
	if a_node is PanelContainer:
		panels[a_node.name] = a_node
	if a_node is TabContainer:
		tabs[a_node.name] = a_node
		return
	if a_node is SplitContainer:
		splits[a_node.name] = a_node
		a_node.dragged.connect(save_split_offset.bind(a_node.name))
	for l_child: Node in a_node.get_children():
		_check_node(l_child)


func load_config() -> void:
	config.load(config_path) # Config exists, loading in settings
	# Go through all offsets and tabs modules
	var l_sections: PackedStringArray = config.get_sections()
	if SECTION_SPLITS in l_sections:
		for l_key: String in config.get_section_keys(SECTION_SPLITS):
			splits[l_key].split_offset = config.get_value(SECTION_SPLITS, l_key)
	if SECTION_TABS in l_sections:
		for l_tab_container: String in config.get_section_keys(SECTION_TABS):
			_add_modules(config.get_value(SECTION_TABS, l_tab_container, []), l_tab_container)


func set_default_tabs() -> void:
	add_module("media_pool", "LeftTopTabs")
	add_module("project_view", "MiddleTopTabs")
	add_module("timeline", "MiddleBottomTabs")


func save_split_offset(split_offset: int, split_container: String) -> void:
	config.set_value(SECTION_SPLITS, split_container, split_offset)
	config.save(config_path)


func add_module(a_module_name: String, a_tab_container: String) -> void:
	## Adding module to the correct tab container and saving the config with the updated info.
	var l_module: Control = load(PATH_MODULE_DATA % a_module_name).scene.instantiate()
	
	l_module.name = ModuleManager.create_module_id(ModuleManager.TYPE.MODULE, a_module_name)
	tabs[a_tab_container].add_child(l_module)
	tabs[a_tab_container].get_tab_bar().set_tab_title(
		l_module.get_index(), Toolbox.beautify_name(a_module_name))
	
	var l_array: PackedStringArray = config.get_value(SECTION_TABS, a_tab_container, [])
	
	l_array.append(a_module_name)
	config.set_value(SECTION_TABS, a_tab_container, l_array)
	config.save(config_path)


func _add_modules(a_module_names: PackedStringArray, a_tab_container: String) -> void:
	## Should not be called manually as this only gets called on startup.
	## We don't use add_module for this as we don't need to create a new id,
	## nor do we need to add it to the config again.
	for l_module_name: String in a_module_names:
		var l_module: Control = load(PATH_MODULE_DATA % l_module_name.split('-')[0]).scene.instantiate()
		
		l_module.name = l_module_name # Adding  existing name with existing identifier
		tabs[a_tab_container].add_child(l_module)
		tabs[a_tab_container].get_tab_bar().set_tab_title(
			l_module.get_index(), Toolbox.beautify_name(l_module_name))


func move_module_to_tabs(a_module_name: String, a_tabs_origin: String, a_tabs_dest: String) -> void:
	## Function to move an existing module from one tab container to another.
	var l_new_origin: PackedStringArray = config.get_value(SECTION_TABS, a_tabs_origin)
	var l_new_dest: PackedStringArray = config.get_value(SECTION_TABS, a_tabs_dest)
	
	tabs[a_tabs_origin].get_node(a_module_name).reparent(tabs[a_tabs_dest])
	l_new_origin.remove_at(l_new_origin.find(a_module_name))
	l_new_dest.append(a_module_name)
	
	config.set_value(SECTION_TABS, a_tabs_origin, l_new_origin)
	config.set_value(SECTION_TABS, a_tabs_dest, l_new_dest)
	config.save(config_path)


func remove_module(a_module_name: String, a_tab_container: String) -> void:
	## Removing a module from a tab container permanently
	var l_new_order: PackedStringArray = []
	
	tabs[a_tab_container].get_node(a_module_name).queue_free()
	for l_child: Node in tabs[a_tab_container].get_children():
		l_new_order.append(l_child.name)
	
	config.set_value(SECTION_TABS, a_tab_container, l_new_order)
	config.save(config_path)
