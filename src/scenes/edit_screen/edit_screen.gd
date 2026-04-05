extends VSplitContainer


func _ready() -> void:
	if Settings.data.tab_vsplit_offsets.size() > 0:
		split_offset = Settings.data.tab_vsplit_offsets[0]
	dragged.connect(func(offset: int) -> void:
			if Settings.data.tab_vsplit_offsets.is_empty():
				Settings.data.tab_vsplit_offsets.append(offset)
			else:
				Settings.data.tab_vsplit_offsets[0] = offset
			Settings.save())

	var top_split: HSplitContainer = get_child(0)
	top_split.split_offsets = Settings.data.tab_edit_hsplit_offsets
	top_split.dragged.connect(func(_o: int) -> void:
			Settings.data.tab_edit_hsplit_offsets = split_offsets
			Settings.save())
