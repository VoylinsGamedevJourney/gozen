extends HSplitContainer


@export var view_horizontal: PanelContainer
@export var view_vertical: PanelContainer



func _ready() -> void:
	Project.project_ready.connect(_project_ready)
	var v_split: VSplitContainer = $VSplit
	if Settings.data.tab_vsplit_offsets.size() > 0:
		v_split.split_offset = Settings.data.tab_vsplit_offsets[0]
	v_split.dragged.connect(func(offset: int) -> void:
			if Settings.data.tab_vsplit_offsets.is_empty():
				Settings.data.tab_vsplit_offsets.append(offset)
			else:
				Settings.data.tab_vsplit_offsets[0] = offset
			Settings.save())

	var top_split: HSplitContainer = $VSplit/HSplit
	top_split.split_offsets = Settings.data.tab_edit_hsplit_offsets
	top_split.dragged.connect(func(_o: int) -> void:
			Settings.data.tab_edit_hsplit_offsets = top_split.split_offsets
			Settings.save())


func _project_ready() -> void:
	# "Short" editing mode.
	var res: Vector2i = Project.data.resolution
	var horizontal: bool = res.x > res.y
	view_horizontal.visible = horizontal
	view_vertical.visible = !horizontal
