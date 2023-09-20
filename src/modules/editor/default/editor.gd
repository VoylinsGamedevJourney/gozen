extends Control

const DATA_PATH := "user://default_editor_module.dat"


var data := {
	panels = { 
		left_top = [],
		left_bottom = [],
		middle_left_top = [],
		middle_left_bottom = [],
		middle_right_top = [],
		middle_right_bottom = [],
		right_top = [],
		right_bottom = [],
	},
	offsets = {
		main_h = 0,
		left_v = 0,
		second_h = 0,
		middle_v = 0,
		middle_top_h = 0,
		middle_second_top_h = 0,
		middle_bottom_h = 0,
		middle_second_bottom_h = 0,
		right_v = 0
	}
}


func _ready() -> void:
	ProjectManager._on_saved.connect(save_editor_data)
	if !FileAccess.file_exists(DATA_PATH):
		reset_editor_data()
	# Get position and offset data.
	pass


# Create a way to save position and offset data
func save_editor_data() -> void:
	# data being stored is [module_positions, offset info]
#	FileManager.save_data([module_positions, offset_data])
	pass


func load_editor_data() -> void:
	# Remove all modules from panels first
	# Get list of module positions and offset info
	
	pass


func reset_editor_data() -> void:
	# TODO: Create a way to reset default positions + offset
	data.offsets["main_h"] = -1200
	data.offsets["left_v"] = 0
	data.offsets["second_h"] = 1200
	data.offsets["middle_v"] = 0
	data.offsets["middle_top_h"] = 1200
	data.offsets["middle_second_top_h"] = -1200
	data.offsets["middle_bottom_h"] = 1200
	data.offsets["middle_second_bottom_h"] = -1200
	data.offsets["right_v"] = 0
	
	save_editor_data()
	load_editor_data()


func set_split_offset(target: String, value: int) -> void:
	if !data.offsets.has(target):
		printerr("Target '%s' does not exists in offsets!" % target)
	else:
		data.offsets[target] = value


func get_placeable_modules() -> void:
	# Get all custom modules which can be placed in editor screen
	pass
