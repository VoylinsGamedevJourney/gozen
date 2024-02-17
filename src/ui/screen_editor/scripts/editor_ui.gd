extends HBoxContainer


var config := ConfigFile.new()
var splits := {}
var panels := {}


# Called when the node enters the scene tree for the first time.
func _ready():
	var path: String = ProjectSettings.get_setting("globals/path/recent_projects")
	
	for child: Node in get_children():
		if child is SplitContainer:
			splits[child.name] == child
		elif child is PanelContainer:
			panels[child.name] == child
	
	if FileAccess.file_exists(path):
		config.load(path)
		# Go through all offsets, panel visibilities and panel modules
	
	# Get all SplitContainers and connect dragged(offset:int) to
	# a fuynctin to save the new layout
	
	# Hide panels with no children
	
	
	pass # Replace with function body.


func add_module(module_name: String, panel_name: String) -> void:
	# load in module and update panel
	pass


func move_module(panel_origin: String, panel_dest: String) -> void:
	# Update the previous panel and update new panel
	pass


func update_panel(panel_name: String) -> void:
	# If panel empty, hide, else show
	pass
