extends Control
# Make module manager which updates module list on startup
# and loads in all necesarry buttons (top_bar, other views)

var config := ConfigFile.new()
var splits := {}
var panels := {}


# Called when the node enters the scene tree for the first time.
func _ready():
	#for child: Node in %LayoutContainer.get_children():
		#if child is SplitContainer:
			#splits[child.name] = child
		#elif child is PanelContainer:
			#panels[child.name] = child
	
	#if FileAccess.file_exists(path):
		#config.load(path)
		# Go through all offsets, panel visibilities and panel modules
	
	# Get all SplitContainers and connect dragged(offset:int) to
	# a fuynctin to save the new layout
	
	# Hide panels with no children
	
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func add_module(module_name: String, panel_name: String) -> void:
	# load in module and update panel
	# save config
	pass


func move_module(panel_origin: String, panel_dest: String) -> void:
	# Update the previous panel and update new panel
	
	# save config
	pass


func update_panel(panel_name: String) -> void:
	# If panel empty, hide, else show
	
	# save config
	pass
