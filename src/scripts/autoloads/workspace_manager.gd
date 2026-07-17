extends Node
## This is the manager for the editor workspaces,
## with the default ones being "Edit", and "Render".

signal workspace_added(workspace_name: String)


const WORKSPACES_DIR: String = "user://workspaces/"


var active_panels: Dictionary[String, Control] = {}

var current_workspace_layout: WorkspaceLayout = null
var workspace_root: Control = null

var available_workspaces: Array[String] = []
var show_tab_titles: bool = false

var drag_layer: CanvasLayer
var drag_overlay: Control
var preview_tab: DockableTab = null
var preview_zone: int = 0
var preview_is_root: bool = false



func _ready() -> void:
	# Adding all GoZen default panels:
	register_panel("EffectsPanel", preload("res://scenes/effects_panel/effects_panel.tscn").instantiate() as Control)
	register_panel("FilePanel", preload("res://scenes/file_panel/file_panel.tscn").instantiate() as Control)
	register_panel("MarkersPanel", preload("res://scenes/markers_panel/markers_panel.tscn").instantiate() as Control)
	register_panel("RenderOptionsPanel", preload("res://scenes/render_options_panel/render_options_panel.tscn").instantiate() as Control)
	register_panel("ViewPanel", preload("res://scenes/view_panel/view_panel.tscn").instantiate() as Control)
	register_panel("Timeline", preload("res://scenes/timeline/timeline.tscn").instantiate() as Control)

	drag_layer = CanvasLayer.new()
	drag_layer.layer = 100
	add_child(drag_layer)

	drag_overlay = Control.new()
	drag_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	@warning_ignore("return_value_discarded")
	drag_overlay.draw.connect(_on_drag_overlay_draw)
	drag_overlay.set_drag_forwarding(Callable(), _overlay_can_drop_data, _overlay_drop_data)
	drag_layer.add_child(drag_overlay)

	# Checking if we have the workspaces or if we should add the default ones.
	if !DirAccess.dir_exists_absolute(WORKSPACES_DIR) and DirAccess.make_dir_absolute(WORKSPACES_DIR) != OK:
		printerr("WorkspaceManager: Couldn't create workspaces save directory at '%s'!" % WORKSPACES_DIR)
	if DirAccess.get_files_at(WORKSPACES_DIR).size() == 0:
		var edit_workspace: WorkspaceLayout = _create_default_edit_workspace()
		var render_workspace: WorkspaceLayout = _create_default_render_workspace()
		if ResourceSaver.save(edit_workspace, WORKSPACES_DIR + "edit.tres") != OK:
			printerr("WorkspaceManager: Something went wrong saving the default 'edit' workspace!")
		if ResourceSaver.save(render_workspace, WORKSPACES_DIR + "render.tres") != OK:
			printerr("WorkspaceManager: Something went wrong saving the default 'render' workspace!")

	_load_available_workspaces()


func _load_available_workspaces() -> void:
	for file_name: String in DirAccess.get_files_at(WORKSPACES_DIR):
		if file_name.ends_with(".tres"):
			var workspace_name: String = file_name.get_basename().capitalize()
			if not available_workspaces.has(workspace_name):
				available_workspaces.append(workspace_name)


func save_current_workspace() -> void:
	if current_workspace_layout:
		save_workspace(current_workspace_layout.name)


func save_workspace(workspace_name: String) -> void:
	if workspace_root.get_child_count() == 0: return
	var layout: WorkspaceLayout = WorkspaceLayout.new()
	layout.name = workspace_name
	layout.root = _save_node(workspace_root.get_child(0) as Control)

	var path: String = WORKSPACES_DIR + workspace_name.to_lower().replace(" ", "_") + ".tres"
	var err: Error = ResourceSaver.save(layout, path)
	if err != OK:
		return printerr("WorkspaceManager: Failed to save workspace '%s' at '%s'!" % [workspace_name, path])
	current_workspace_layout = layout


func create_workspace(workspace_name: String) -> void:
	# We make a default layout as to not give people a fully empty screen.
	var layout: WorkspaceLayout = WorkspaceLayout.new()
	layout.name = workspace_name

	var root_vsplit: WorkspaceNode = WorkspaceNode.new()
	root_vsplit.type = WorkspaceNode.Type.VSPLIT
	root_vsplit.split_offsets = PackedInt32Array([650])

	var view_tab: WorkspaceNode = WorkspaceNode.new()
	view_tab.type = WorkspaceNode.Type.TAB
	view_tab.panel_ids = ["ViewPanel"]

	var timeline_tab: WorkspaceNode = WorkspaceNode.new()
	timeline_tab.type = WorkspaceNode.Type.TAB
	timeline_tab.panel_ids = ["Timeline"]

	root_vsplit.children = [view_tab, timeline_tab]
	layout.root = root_vsplit

	var path: String = WORKSPACES_DIR + workspace_name.to_lower().replace(" ", "_") + ".tres"
	var err: Error = ResourceSaver.save(layout, path)
	if err != OK:
		return printerr("WorkspaceManager: Failed to save workspace '%s' at '%s'!" % [workspace_name, path])

	available_workspaces.append(workspace_name)
	workspace_added.emit(workspace_name)


func _save_node(control: Control) -> WorkspaceNode:
	var node: WorkspaceNode = WorkspaceNode.new()
	if control is DockableTab:
		node.type = node.Type.TAB
		node.current_tab = (control as DockableTab).current_tab
		for child: Node in control.get_children():
			node.panel_ids.append(child.name)
	elif control is HSplitContainer or control is VSplitContainer:
		node.type = node.Type.HSPLIT if control is HSplitContainer else node.Type.VSPLIT
		node.split_offsets = (control as SplitContainer).split_offsets
		for child: Node in control.get_children():
			node.children.append(_save_node(child as Control))
	return node


func load_workspace(workspace_name: String) -> void:
	var path: String = WORKSPACES_DIR + workspace_name.to_lower().replace(" ", "_") + ".tres"
	if !FileAccess.file_exists(path):
		return printerr("WorkspaceManager: Workspace file not found at '%s'" % path)

	var layout: WorkspaceLayout = load(path)
	if not layout or not layout.root:
		return printerr("WorkspaceManager: Invalid workspace layout '%s'!" % workspace_name)

	current_workspace_layout = layout
	_clear_workspace()
	if workspace_root:
		var root: Control = _build_node(layout.root)
		workspace_root.add_child(root)
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _clear_workspace() -> void:
	if not workspace_root: return

	for id: String in active_panels:
		var panel: Control = active_panels[id]
		if panel.get_parent():
			panel.get_parent().remove_child(panel)

	for child: Node in workspace_root.get_children():
		child.queue_free()


func _build_node(node: WorkspaceNode) -> Control:
	if node.type == WorkspaceNode.Type.TAB:
		var tab: DockableTab = DockableTab.new()
		for id: String in node.panel_ids:
			tab.add_child(active_panels[id])
		tab.current_tab = node.current_tab
		return tab
	var split: SplitContainer
	if node.type == WorkspaceNode.Type.HSPLIT:
		split = HSplitContainer.new()
	else:
		split = VSplitContainer.new()

	for child: WorkspaceNode in node.children:
		split.add_child(_build_node(child))

	split.split_offsets = node.split_offsets
	return split


func register_panel(id: String, control: Control) -> void:
	active_panels[id] = control
	control.name = id


func start_drag() -> void:
	drag_overlay.mouse_filter = Control.MOUSE_FILTER_STOP


func stop_drag() -> void:
	drag_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_tab = null
	preview_zone = 0
	preview_is_root = false
	drag_overlay.queue_redraw()


func _overlay_can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.type == "dockable_panel":
		var global_pos: Vector2 = drag_overlay.get_global_transform() * at_position

		if workspace_root and workspace_root.is_visible_in_tree():
			var root_rect: Rect2 = workspace_root.get_global_rect()
			if root_rect.has_point(global_pos):
				var margin: float = 40.0
				var zone: int = DockableTab.DropZone.NONE

				if global_pos.x < root_rect.position.x + margin:
					zone = DockableTab.DropZone.LEFT
				elif global_pos.x > root_rect.end.x - margin:
					zone = DockableTab.DropZone.RIGHT
				elif global_pos.y < root_rect.position.y + margin:
					zone = DockableTab.DropZone.TOP
				elif global_pos.y > root_rect.end.y - margin:
					zone = DockableTab.DropZone.BOTTOM

				if zone != DockableTab.DropZone.NONE:
					if preview_tab != null or preview_zone != zone or not preview_is_root:
						preview_tab = null
						preview_zone = zone
						preview_is_root = true
						drag_overlay.queue_redraw()
					return true

		var hovered: DockableTab = _get_hovered_tab(global_pos)
		if hovered:
			var local_pos: Vector2 = hovered.get_global_transform().affine_inverse() * global_pos
			var zone: int = hovered._get_drop_zone(local_pos)

			if preview_tab != hovered or preview_zone != zone or preview_is_root:
				preview_tab = hovered
				preview_zone = zone
				preview_is_root = false
				drag_overlay.queue_redraw()
			return true

	if preview_tab != null or preview_is_root:
		preview_tab = null
		preview_zone = DockableTab.DropZone.NONE
		preview_is_root = false
		drag_overlay.queue_redraw()
	return false


func _overlay_drop_data(at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.type == "dockable_panel":
		if preview_is_root and preview_zone != DockableTab.DropZone.NONE:
			handle_root_drop(data.id as String, preview_zone)
		else:
			var global_pos: Vector2 = drag_overlay.get_global_transform() * at_position
			var hovered: DockableTab = _get_hovered_tab(global_pos)
			if hovered:
				var local_pos: Vector2 = hovered.get_global_transform().affine_inverse() * global_pos
				var zone: int = hovered._get_drop_zone(local_pos)
				handle_panel_drop(data.id as String, data.source as TabContainer, hovered, zone)
	stop_drag()


func _get_hovered_tab(global_pos: Vector2) -> DockableTab:
	var tabs: Array[Node] = get_tree().get_nodes_in_group("dockable_tabs")
	for tab: DockableTab in tabs:
		if tab.is_visible_in_tree() and tab.get_global_rect().has_point(global_pos):
			return tab
	return null


func _on_drag_overlay_draw() -> void:
	if preview_zone == DockableTab.DropZone.NONE: return
	var rect: Rect2
	var threshold: float

	if preview_is_root:
		rect = workspace_root.get_global_rect()
		threshold = 0.25
	else:
		if not preview_tab: return
		rect = preview_tab.get_global_rect()
		threshold = DockableTab.SPLIT_THRESHOLD

	var draw_rect: Rect2
	var color: Color = DockableTab.COLOR_OVERLAY

	if preview_zone == DockableTab.DropZone.CENTER:
		draw_rect = Rect2(Vector2.ZERO, rect.size)
	elif preview_zone == DockableTab.DropZone.LEFT:
		draw_rect = Rect2(0, 0, rect.size.x * threshold, rect.size.y)
	elif preview_zone == DockableTab.DropZone.RIGHT:
		draw_rect = Rect2(rect.size.x * (1.0 - threshold), 0, rect.size.x * threshold, rect.size.y)
	elif preview_zone == DockableTab.DropZone.TOP:
		draw_rect = Rect2(0, 0, rect.size.x, rect.size.y * threshold)
	elif preview_zone == DockableTab.DropZone.BOTTOM:
		draw_rect = Rect2(0, rect.size.y * (1.0 - threshold), rect.size.x, rect.size.y * threshold)

	draw_rect.position += rect.position
	draw_rect.position = drag_overlay.get_global_transform().affine_inverse() * draw_rect.position
	drag_overlay.draw_rect(draw_rect, color)


func handle_root_drop(id: String, zone: int) -> void:
	var panel: Control = active_panels[id]
	var is_horizontal: bool = (zone == DockableTab.DropZone.LEFT or zone == DockableTab.DropZone.RIGHT)
	var is_before: bool = (zone == DockableTab.DropZone.LEFT or zone == DockableTab.DropZone.TOP)
	var new_split: SplitContainer
	if is_horizontal:
		new_split = HSplitContainer.new()
	else:
		new_split = VSplitContainer.new()

	var new_tab_container: DockableTab = DockableTab.new()
	var old_content: Node = workspace_root.get_child(0)
	workspace_root.remove_child(old_content)

	workspace_root.add_child(new_split)
	new_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	new_split.add_child(old_content)
	new_split.add_child(new_tab_container)

	if is_before:
		new_split.move_child(new_tab_container, 0)
	else:
		new_split.move_child(new_tab_container, 1)

	if is_horizontal:
		new_split.split_offset = int((workspace_root.size.x * 0.25) * (-1 if is_before else 1))
	else:
		new_split.split_offset = int((workspace_root.size.y * 0.25) * (-1 if is_before else 1))

	panel.get_parent().remove_child(panel)
	new_tab_container.add_child(panel)
	clean_up_empty_containers.call_deferred()


func handle_panel_drop(id: String, source: TabContainer, target: TabContainer, zone: DockableTab.DropZone) -> void:
	var panel: Control = active_panels[id]
	if zone == DockableTab.DropZone.CENTER: # Merging.
		if source != target:
			panel.get_parent().remove_child(panel)
			target.add_child(panel)
			target.current_tab = target.get_child_count() - 1
	else: # Splitting.
		var is_horizontal: bool = (zone == DockableTab.DropZone.LEFT or zone == DockableTab.DropZone.RIGHT)
		var is_before: bool = (zone == DockableTab.DropZone.LEFT or zone == DockableTab.DropZone.TOP)
		var parent: Node = target.get_parent()
		var new_tab_container: DockableTab = DockableTab.new()

		if (is_horizontal and parent is HSplitContainer) or (not is_horizontal and parent is VSplitContainer):
			var index: int = target.get_index()
			parent.add_child(new_tab_container)
			parent.move_child(new_tab_container, index if is_before else index + 1)
		else: # Different direction split needed.
			var new_split: SplitContainer
			var target_idx: int = target.get_index()
			if is_horizontal:
				new_split = HSplitContainer.new()
			else:
				new_split = VSplitContainer.new()

			parent.add_child(new_split)
			parent.move_child(new_split, target_idx)

			parent.remove_child(target)
			new_split.add_child(target)
			new_split.add_child(new_tab_container)

			if is_before:
				new_split.move_child(new_tab_container, 0)
			else:
				new_split.move_child(new_tab_container, 1)

		panel.get_parent().remove_child(panel)
		new_tab_container.add_child(panel)
	clean_up_empty_containers.call_deferred()


func set_tab_titles_visiblity(show: bool) -> void:
	show_tab_titles = show
	var tabs: Array[Node] = get_tree().get_nodes_in_group("dockable_tabs")
	for tab_node: TabContainer in tabs:
		tab_node.tabs_visible = show_tab_titles or tab_node.get_tab_count() > 1


func toggle_tab_titles() -> void:
	show_tab_titles = !show_tab_titles
	var tabs: Array[Node] = get_tree().get_nodes_in_group("dockable_tabs")
	for tab_node: TabContainer in tabs:
		tab_node.tabs_visible = show_tab_titles or tab_node.get_tab_count() > 1


func toggle_panel(panel_id: String) -> void:
	var panel: Control = active_panels[panel_id]
	if panel.is_inside_tree():
		var parent: Node = panel.get_parent()
		parent.remove_child(panel)
		clean_up_empty_containers.call_deferred()
	else:
		var tabs: Array[Node] = get_tree().get_nodes_in_group("dockable_tabs")
		var valid_tabs: Array[Node] = []
		for tab: Node in tabs:
			if workspace_root and workspace_root.is_ancestor_of(tab):
				valid_tabs.append(tab)

		if valid_tabs.size() > 0:
			var target_tab: DockableTab = valid_tabs[0]
			var parent: Node = target_tab.get_parent()

			var new_tab: DockableTab = DockableTab.new()
			new_tab.add_child(panel)

			var new_split: HSplitContainer = HSplitContainer.new()
			var index: int = target_tab.get_index()

			parent.remove_child(target_tab)

			new_split.add_child(new_tab)
			new_split.add_child(target_tab)

			parent.add_child(new_split)
			parent.move_child(new_split, index)

			if parent == workspace_root:
				new_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

			new_split.split_offset = int((target_tab.size.x * 0.25) * -1)
		elif workspace_root and workspace_root.get_child_count() > 0:
			var root_node: Node = workspace_root.get_child(0)

			var new_tab: DockableTab = DockableTab.new()
			new_tab.add_child(panel)

			var new_split: HSplitContainer = HSplitContainer.new()

			workspace_root.remove_child(root_node)

			new_split.add_child(new_tab)
			new_split.add_child(root_node)

			workspace_root.add_child(new_split)
			new_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

			new_split.split_offset = int((workspace_root.size.x * 0.25) * -1)
		elif workspace_root:
			var new_tab: DockableTab = DockableTab.new()
			new_tab.add_child(panel)
			workspace_root.add_child(new_tab)
			new_tab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func clean_up_empty_containers() -> void:
	var to_check: Array[Node] = get_tree().get_nodes_in_group("dockable_tabs")
	for container: Node in to_check:
		if container.get_child_count() == 0:
			var parent: Node = container.get_parent()
			parent.remove_child(container)
			container.queue_free()
			if parent is SplitContainer:
				_cleanup_split_container(parent as SplitContainer)


func _cleanup_split_container(split: SplitContainer) -> void:
	var child_count: int = split.get_child_count()
	if child_count == 0:
		var parent: Node = split.get_parent()
		parent.remove_child(split)
		split.queue_free()
		if parent is SplitContainer:
			_cleanup_split_container(parent as SplitContainer)
	elif child_count == 1:
		var single_child: Node = split.get_child(0)
		var parent: Node = split.get_parent()
		var index: int = split.get_index()
		split.remove_child(single_child)
		parent.add_child(single_child)
		parent.move_child(single_child, index)
		parent.remove_child(split)
		split.queue_free()
		if parent is SplitContainer:
			_cleanup_split_container(parent as SplitContainer)


# --- Default workspaces ---

func _create_default_edit_workspace() -> WorkspaceLayout:
	var layout: WorkspaceLayout = WorkspaceLayout.new()
	layout.name = "Edit"

	var root_vsplit: WorkspaceNode = WorkspaceNode.new()
	root_vsplit.type = WorkspaceNode.Type.VSPLIT
	root_vsplit.split_offsets = PackedInt32Array([650])

	var top_hsplit: WorkspaceNode = WorkspaceNode.new()
	top_hsplit.type = WorkspaceNode.Type.HSPLIT
	top_hsplit.split_offsets = PackedInt32Array([350, 1400])

	var file_tab: WorkspaceNode = WorkspaceNode.new()
	file_tab.type = WorkspaceNode.Type.TAB
	file_tab.panel_ids = ["FilePanel"]

	var view_tab: WorkspaceNode = WorkspaceNode.new()
	view_tab.type = WorkspaceNode.Type.TAB
	view_tab.panel_ids = ["ViewPanel"]

	var effects_tab: WorkspaceNode = WorkspaceNode.new()
	effects_tab.type = WorkspaceNode.Type.TAB
	effects_tab.panel_ids = ["EffectsPanel"]

	top_hsplit.children = [file_tab, view_tab, effects_tab]

	var bottom_hsplit: WorkspaceNode = WorkspaceNode.new()
	bottom_hsplit.type = WorkspaceNode.Type.HSPLIT
	bottom_hsplit.split_offsets = PackedInt32Array([0])

	var timeline_tab: WorkspaceNode = WorkspaceNode.new()
	timeline_tab.type = WorkspaceNode.Type.TAB
	timeline_tab.panel_ids = ["Timeline"]

	bottom_hsplit.children = [timeline_tab]

	root_vsplit.children = [top_hsplit, bottom_hsplit]
	layout.root = root_vsplit
	return layout


func _create_default_render_workspace() -> WorkspaceLayout:
	var layout: WorkspaceLayout = WorkspaceLayout.new()
	layout.name = "Render"

	var root_vsplit: WorkspaceNode = WorkspaceNode.new()
	root_vsplit.type = WorkspaceNode.Type.VSPLIT
	root_vsplit.split_offsets = PackedInt32Array([650])

	var top_hsplit: WorkspaceNode = WorkspaceNode.new()
	top_hsplit.type = WorkspaceNode.Type.HSPLIT
	top_hsplit.split_offsets = PackedInt32Array([500, 1500])

	var render_options_tab: WorkspaceNode = WorkspaceNode.new()
	render_options_tab.type = WorkspaceNode.Type.TAB
	render_options_tab.panel_ids = ["RenderOptionsPanel"]

	var view_tab: WorkspaceNode = WorkspaceNode.new()
	view_tab.type = WorkspaceNode.Type.TAB
	view_tab.panel_ids = ["ViewPanel"]

	var markers_tab: WorkspaceNode = WorkspaceNode.new()
	markers_tab.type = WorkspaceNode.Type.TAB
	markers_tab.panel_ids = ["MarkersPanel"]

	top_hsplit.children = [render_options_tab, view_tab, markers_tab]

	var bottom_hsplit: WorkspaceNode = WorkspaceNode.new()
	bottom_hsplit.type = WorkspaceNode.Type.HSPLIT
	bottom_hsplit.split_offsets = PackedInt32Array([0])

	var timeline_tab: WorkspaceNode = WorkspaceNode.new()
	timeline_tab.type = WorkspaceNode.Type.TAB
	timeline_tab.panel_ids = ["Timeline"]

	bottom_hsplit.children = [timeline_tab]

	root_vsplit.children = [top_hsplit, bottom_hsplit]
	layout.root = root_vsplit
	return layout
