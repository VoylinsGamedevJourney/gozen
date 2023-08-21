extends EditorModule

enum LAYOUT {UNCONFIGURED,LANDSCAPE,PORTRAIT}
var layout : LAYOUT = LAYOUT.UNCONFIGURED


func _ready() -> void:
	ProjectManager._on_resolution_changed.connect(_on_project_resolution_change)


func _on_project_resolution_change(new_resolution: Vector2i) -> void:
	var change: bool = false
	if new_resolution.x < new_resolution.y:
		if layout != LAYOUT.LANDSCAPE: change = true
		layout = LAYOUT.LANDSCAPE
	else:
		if layout != LAYOUT.PORTRAIT: change = true
		layout = LAYOUT.PORTRAIT
	if !change: return
	for child in get_children(): child.queue_free()
	match layout:
		LAYOUT.PORTRAIT:
			add_child(preload("res://modules/editor/default/portrait_view.tscn").instantiate())
		LAYOUT.LANDSCAPE:
			add_child(preload("res://modules/editor/default/landscape_view.tscn").instantiate())
