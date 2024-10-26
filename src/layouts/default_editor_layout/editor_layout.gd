extends VSplitContainer


@export var view_panel: PanelContainer
@export var files_panel: PanelContainer
@export var effects_panel: PanelContainer
@export var timeline_panel: PanelContainer



func _ready() -> void:
	CoreLoader.append_after("Loading View panel", add_panel_module.bind(view_panel, CoreModules.PANEL_VIEW))
	CoreLoader.append_after("Loading Files panel", add_panel_module.bind(files_panel, CoreModules.PANEL_FILES))
	CoreLoader.append_after("Loading Effects panel", add_panel_module.bind(effects_panel, CoreModules.PANEL_EFFECTS))
	CoreLoader.append_after("Loading Timeline panel", add_panel_module.bind(timeline_panel, CoreModules.PANEL_TIMELINE))


func add_panel_module(a_panel: PanelContainer, a_type: int) -> void:
	for l_child: Control in a_panel.get_children():
		l_child.queue_free()
	
	var l_panel_name: String = CoreModules.modules[a_type]
	var l_panel: Control = CoreModules.get_existing_panel_instance(l_panel_name)

	a_panel.add_child(l_panel)	

