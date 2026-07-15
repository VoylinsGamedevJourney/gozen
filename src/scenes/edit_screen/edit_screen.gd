extends HSplitContainer


func _ready() -> void:
	var v_split: VSplitContainer = $VSplit
	if Settings.data.tab_vsplit_offsets.size() > 0:
		v_split.split_offset = Settings.data.tab_vsplit_offsets[0]

	@warning_ignore("return_value_discarded")
	v_split.dragged.connect(func(offset: int) -> void:
			if Settings.data.tab_vsplit_offsets.is_empty():
				Settings.data.tab_vsplit_offsets.append(offset)
			else:
				Settings.data.tab_vsplit_offsets[0] = offset
			Settings.save())

	var top_split: HSplitContainer = $VSplit/HSplit
	top_split.split_offsets = Settings.data.tab_edit_hsplit_offsets
	@warning_ignore("return_value_discarded")
	top_split.dragged.connect(func(_o: int) -> void:
			Settings.data.tab_edit_hsplit_offsets = top_split.split_offsets
			Settings.save())
