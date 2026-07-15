class_name DockableTab
extends TabContainer


enum DropZone { NONE, CENTER, LEFT, RIGHT, TOP, BOTTOM }


const COLOR_OVERLAY: Color = Library.COLOR_GOZEN_ACCENT
const SPLIT_THRESHOLD: float = 0.25



func _ready() -> void:
	add_to_group("dockable_tabs")
	tabs_visible = WorkspaceManager.show_tab_titles
	tabs_position = Settings.get_panel_tabs_position() as TabContainer.TabPosition
	get_tab_bar().set_drag_forwarding(_get_drag_data, Callable(), Callable())

	@warning_ignore_start("return_value_discarded")
	child_entered_tree.connect(func(_node: Node) -> void: _update_tabs_visible.call_deferred())
	child_exiting_tree.connect(func(_node: Node) -> void: _update_tabs_visible.call_deferred())
	@warning_ignore_restore("return_value_discarded")

	_update_tabs_visible.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END: WorkspaceManager.stop_drag()


func _update_tabs_visible() -> void:
	# NOTE: Should get updated as it's not really efficient ... but oh well ...
	# Worry for future me :D
	if not is_inside_tree(): return
	tabs_visible = WorkspaceManager.show_tab_titles or get_tab_count() > 1


func _get_drop_zone(pos: Vector2) -> DropZone:
	pos /= size

	# Distances.
	var left: float = pos.x
	var right: float = 1.0 - pos.x
	var top: float = pos.y
	var bottom: float = 1.0 - pos.y
	var minimum_distance: float = minf(minf(left, right), minf(top, bottom))

	if minimum_distance > SPLIT_THRESHOLD: return DropZone.CENTER
	if minimum_distance == left: return DropZone.LEFT
	if minimum_distance == right: return DropZone.RIGHT
	if minimum_distance == top: return DropZone.TOP
	if minimum_distance == bottom: return DropZone.BOTTOM
	return DropZone.CENTER


# --- Drop logic ---

func _get_drag_data(at_position: Vector2) -> Variant:
	var index: int = get_tab_bar().get_tab_idx_at_point(at_position)
	if index == -1: return null

	var panel: Control = get_child(index)
	var drag_data: Dictionary = { "id": panel.name, "source": self, "type": "dockable_panel" }
	var preview: Label = Label.new()
	preview.text = " " + panel.name + " "
	preview.add_theme_stylebox_override("normal", load(Library.STYLE_BOX_CLIP_COLOR_FOCUS) as StyleBox)
	set_drag_preview(preview)

	WorkspaceManager.start_drag()
	return drag_data
