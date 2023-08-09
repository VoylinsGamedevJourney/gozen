extends EditorModule

# TODO: Change layout when resolution becomes vertical/horizontal
enum LAYOUT {NOT_CONFIGURED, LANDSCAPE,PORTRAIT}
var layout : LAYOUT = LAYOUT.NOT_CONFIGURED

func _ready() -> void:
	Globals._on_project_resolution_change.connect(_on_project_resolution_change)


func _on_project_resolution_change() -> void:
	var change: bool = false
	if ProjectManager.resolution.x < ProjectManager.resolution.y:
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
