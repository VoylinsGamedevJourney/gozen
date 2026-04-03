extends VBoxContainer


@export var timeline_scroll: ScrollContainer
@onready var scroll: ScrollContainer = get_parent()

var spacer: Control


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	Project.project_ready.connect(_rebuild)
	TrackLogic.updated.connect(_rebuild)
	Settings.on_track_height_changed.connect(_on_track_height_changed)

	timeline_scroll.get_v_scroll_bar().value_changed.connect(_on_scrolled)


func _on_scrolled(value: float) -> void:
	scroll.scroll_vertical = value as int
	spacer.visible = timeline_scroll.get_h_scroll_bar().visible


func _on_track_height_changed(_new_height: float) -> void:
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()

	var track_total_size: float = Settings.get_track_height() + 1 # For the track line width.
	for i: int in TrackLogic.tracks.size():
		var track_data: TrackData = TrackLogic.tracks[i]
		var panel: PanelContainer = PanelContainer.new()
		panel.custom_minimum_size.y = track_total_size
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.border_width_bottom = 1
		style.border_color = Color.DIM_GRAY
		panel.add_theme_stylebox_override("panel", style)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 5)

		var button_visibility: TextureButton = TextureButton.new()
		button_visibility.toggle_mode = true
		button_visibility.texture_normal = preload(Library.ICON_VISIBLE)
		button_visibility.texture_pressed = preload(Library.ICON_INVISIBLE)
		button_visibility.button_pressed = !track_data.is_visible
		button_visibility.ignore_texture_size = true
		button_visibility.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button_visibility.custom_minimum_size = Vector2(12, 12)
		button_visibility.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button_visibility.tooltip_text = tr("Toggle track visibility")
		button_visibility.toggled.connect(func(toggled: bool) -> void:
			track_data.is_visible = !toggled
			EditorCore.set_frame_nr(EditorCore.frame_nr)
			Project.unsaved_changes = true)

		var button_mute: Button = Button.new()
		button_mute.toggle_mode = true
		button_mute.flat = true
		button_mute.text = "M"
		button_mute.button_pressed = track_data.is_muted
		button_mute.custom_minimum_size = Vector2(8, 8)
		button_mute.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button_mute.tooltip_text = tr("Mute track")
		button_mute.add_theme_font_size_override("font_size", 8)
		button_mute.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		button_mute.add_theme_color_override("font_hover_color", Color(0.8, 0.8, 0.8))
		button_mute.add_theme_color_override("font_pressed_color", Color(1, 0.3, 0.3))
		button_mute.toggled.connect(func(toggled: bool) -> void:
			track_data.is_muted = toggled
			EditorCore.set_frame_nr(EditorCore.frame_nr)
			Project.unsaved_changes = true)

		vbox.add_child(button_visibility)
		vbox.add_child(button_mute)
		panel.add_child(vbox)
		add_child(panel)

	# We need a spacer for the scrollbar.
	spacer = Control.new()
	spacer.custom_minimum_size.y = timeline_scroll.get_h_scroll_bar().size.y
	add_child(spacer)
