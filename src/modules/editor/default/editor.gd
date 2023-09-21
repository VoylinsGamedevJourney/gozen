extends Control

enum TAB_POSITION { TOP, BOTTOM }


const DATA_PATH := "user://default_editor_module.dat"


var data: Dictionary = {
	tab_position = TAB_POSITION.TOP,
	show_tab_tag_when_single = false,
	panels = { 
		left_top = [],
		left_bottom = [],
		middle_top_left = [],
		middle_bottom_left = [],
		middle_top_right = [],
		middle_bottom_right = [],
		right_top = [],
		right_bottom = [],
	},
	offsets = {
		main_h = -1200,
		left_v = 0,
		second_h = 1200,
		middle_v = 0,
		middle_top_h = 1200,
		middle_second_top_h = -1200,
		middle_bottom_h = 1200,
		middle_second_bottom_h = -1200,
		right_v = 0
	}
}
@onready var panel_nodes: Dictionary = {
	left_top = %LeftTopPanel,
	left_bottom = %LeftBottomPanel,
	middle_top_left = %MiddleTopLeftPanel,
	middle_bottom_left = %MiddleBottomLeftPanel,
	middle_top_right = %MiddleTopRightPanel,
	middle_bottom_right = %MiddleBottomRightPanel,
	right_top = %RightTopPanel,
	right_bottom = %RightBottomPanel
}


func _ready() -> void:
	ProjectManager._on_saved.connect(save_editor_data)
	if !FileAccess.file_exists(DATA_PATH):
		reset_editor_data()
	else:
		load_editor_data()


# Create a way to save position and offset data
func save_editor_data() -> void:
	# data being stored is [module_positions, offset info]
#	FileManager.save_data([module_positions, offset_data])
	pass


func load_editor_data() -> void:
	# Remove all modules from panels first
	# Get list of module positions and offset info
	
	build_editor()


func build_editor() -> void:
	# Loading all modules in the correct panel
	for panel in data.panels:
		if data.panels[panel].size() == 0:
			panel_nodes[panel].visible = false
			continue
		for mod in data.panels[panel]:
			if data.panels[panel].get_child_count() == 0:
				var new_panel =
			panel_nodes[panel].add_child(ModuleManager .get_selected_module(mod))
	
	# Check for Left and Right panel to see if empty or not
	if data.panels.left_top == [] and data.panels.left_bottom == []:
		%LeftPanel.visible = false
	if data.panels.right_top == [] and data.panels.right_bottom == []:
		%RightPanel.visible = false
	
	
	# Setting all offsets
	%MainHSplit.split_offset = data.offsets.main_h
	%LeftVSplit.split_offset = data.offsets.left_v
	%SecondHSplit.split_offset = data.offsets.second_h
	%MiddleVSplit.split_offset = data.offsets.middle_v
	%MiddleTopHSplit.split_offset = data.offsets.middle_top_h
	%MiddleSecondTopHSplit.split_offset = data.offsets.middle_second_top_h
	%MiddleBottomHSplit.split_offset = data.offsets.middle_bottom_h
	%MiddleSecondBottomHSplit.split_offset = data.offsets.middle_second_bottom_h
	%RightVSplit.split_offset = data.offsets.right_v


func reset_editor_data() -> void:
	data.offsets.main_h = -1200
	data.offsets.left_v = 0
	data.offsets.second_h = 1200
	data.offsets.middle_v = 0
	data.offsets.middle_top_h = 1200
	data.offsets.middle_second_top_h = -1200
	data.offsets.middle_bottom_h = 1200
	data.offsets.middle_second_bottom_h = -1200
	data.offsets.right_v = 0
	
	data.panels.left_top = ["media_pool"]
	data.panels.left_bottom = []
	data.panels.middle_top_left = ["effects_view"]
	data.panels.middle_bottom_left = []
	data.panels.middle_top_right = []
	data.panels.middle_bottom_right = []
	data.panels.right_top = []
	data.panels.right_bottom = []
	
	save_editor_data()
	build_editor()


func set_split_offset(target: String, value: int) -> void:
	if !data.offsets.has(target):
		printerr("Target '%s' does not exists in offsets!" % target)
	else:
		data.offsets[target] = value
