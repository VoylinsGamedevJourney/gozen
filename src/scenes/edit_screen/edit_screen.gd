extends HSplitContainer


func _ready() -> void:
	split_offsets = Settings.data.tab_edit_hsplit_offsets
	dragged.connect(func(_o: int) -> void:
		Settings.data.tab_edit_hsplit_offsets = split_offsets
		Settings.save()
	)
