extends HBoxContainer

const PATH := "user://editor_layout.dat"


func _ready() -> void:
	load_editor_layout()

###############################################################
#region Data handlers  ########################################
###############################################################

func load_editor_layout() -> void:
	if !FileAccess.file_exists(PATH):
		save_editor_layout()
		return
	var data_file := FileAccess.open(PATH, FileAccess.READ)
	var data: Dictionary = data_file.get_var()
	%LayoutVSplit.split_offset = int(data.v_split_offset)
	%LayoutHSplit.split_offset = int(data.h_split_offset)

func save_editor_layout() -> void:
	var data_file := FileAccess.open(PATH, FileAccess.WRITE)
	data_file.store_var({
		"v_split_offset": %LayoutVSplit.split_offset,
		"h_split_offset": %LayoutHSplit.split_offset,
	})

#endregion
###############################################################
#region Split dragging  #######################################
###############################################################

func _on_layout_h_split_dragged(offset: int) -> void:
	save_editor_layout()


func _on_layout_v_split_dragged(offset: int) -> void:
	save_editor_layout()

#endregion
###############################################################
