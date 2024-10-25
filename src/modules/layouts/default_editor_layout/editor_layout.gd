extends VSplitContainer

@export var view_panel: PanelContainer
@export var files_panel: PanelContainer
@export var effects_panel: PanelContainer
@export var timeline_panel: PanelContainer


func _ready() -> void:
	# TODO: Load modules with their id so they have access to saving their own data,
	# for this we first need to save the layout data using the name of this node

	CoreLoader.append_after("Loading View panel", add_panel_module.bind(view_panel, ModuleManager.PANEL.VIEW))
	CoreLoader.append_after("Loading Files panel", add_panel_module.bind(files_panel, ModuleManager.PANEL.FILES))
	CoreLoader.append_after("Loading Effects panel", add_panel_module.bind(effects_panel, ModuleManager.PANEL.EFFECTS))
	CoreLoader.append_after("Loading Timeline panel", add_panel_module.bind(timeline_panel, ModuleManager.PANEL.TIMELINE))


func add_panel_module(a_panel: PanelContainer, a_type: ModuleManager.PANEL) -> void:
	for l_child: Control in a_panel.get_children():
		l_child.queue_free()
	a_panel.add_child(ModuleManager.get_panel_module(a_type).instantiate())	

