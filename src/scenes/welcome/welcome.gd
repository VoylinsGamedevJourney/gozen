extends PanelContainer


@export var full_only_buttons: Array[Button]
@export var tab_container: TabContainer

@export var option_button_language: OptionButton
@export var option_button_theme: OptionButton

@export var option_button_video_drag: OptionButton

@export var grid_modes: GridContainer
@export var grid_shortcuts: GridContainer

@export_group("Welcome tab buttons")
@export var button_flow_website: Button
@export var button_flow_manual: Button
@export var button_flow_tutorials: Button
@export var button_flow_discord: Button
@export var button_flow_source_code: Button
@export var button_flow_support_kofi: Button

@export_group("Module related buttons")
@export var button_itch_modules: Button
@export var button_steam_workshop: Button
@export var button_gozen_module_repo: Button

@export_group("Rendering related buttons")
@export var option_button_default_profile: OptionButton
@export var region_in_line_edit: LineEdit
@export var region_out_line_edit: LineEdit

@export_group("Default project settings")
@export var spinbox_resolution_x: SpinBox
@export var spinbox_resolution_y: SpinBox
@export var spinbox_framerate: SpinBox

@export_group("Extra settings")
@export var check_button_auto_save: CheckButton
@export var option_button_empty_space: OptionButton


var listening_action: String = ""
var listening_line_edit: LineEdit = null



func _ready() -> void:
	tab_container.current_tab = 0

	if OS.has_feature("demo"):
		for button: Button in full_only_buttons:
			button.disabled = true
			button.tooltip_text = tr("Full version only!")

	button_flow_website.pressed.connect(func() -> void: URL.open("site"))
	button_flow_manual.pressed.connect(func() -> void: URL.open("manual"))
	button_flow_tutorials.pressed.connect(func() -> void: URL.open("tutorials"))
	button_flow_discord.pressed.connect(func() -> void: URL.open("discord"))
	button_flow_source_code.pressed.connect(func() -> void: URL.open("source_code"))
	button_flow_support_kofi.pressed.connect(func() -> void: URL.open("support"))

	button_itch_modules.pressed.connect(func() -> void: URL.open("itch_modules"))
	button_steam_workshop.pressed.connect(func() -> void: URL.open("steam_workshop"))

	button_gozen_module_repo.pressed.connect(func() -> void: URL.open("gozen_module_repo"))

	_setup_welcome_tab()
	_setup_basics_tab()
	_setup_editing_tab()
	_setup_rendering_tab()
	_setup_extras_tab()


func _input(event: InputEvent) -> void:
	if listening_line_edit != null:
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_cancel"):
			_stop_listening()
			return

		if event is InputEventKey and event.is_pressed():
			var key_event: InputEventKey = event
			if key_event.keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]:
				return
			elif key_event.physical_keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]:
				return

			Settings.set_shortcut_event_at_index(listening_action, 0, event)
			listening_line_edit.text = _get_event_text(event)
			_stop_listening()
		elif event is InputEventMouseButton and event.is_pressed():
			Settings.set_shortcut_event_at_index(listening_action, 0, event)
			listening_line_edit.text = _get_event_text(event)
			_stop_listening()


func _on_show_tab(id: int) -> void:
	tab_container.current_tab = id


func _on_close_button_pressed() -> void:
	Settings.set_is_first_time(false)
	Settings.save()
	self.queue_free()


func _stop_listening() -> void:
	if listening_line_edit != null:
		listening_line_edit.release_focus()

		var events: Array[InputEvent] = Settings.get_events_for_action(listening_action)
		listening_line_edit.text = _get_event_text(events[0]) if events.size() > 0 else "None"
	listening_line_edit = null
	listening_action = ""


func _get_event_text(event: InputEvent) -> String:
	if event == null:
		return "None"
	elif event is not InputEventKey:
		return event.as_text()

	var event_key: InputEventKey = event
	if event_key.physical_keycode != 0:
		return event_key.as_text_physical_keycode()
	return event_key.as_text_keycode()


func _setup_welcome_tab() -> void:
	# - Language button.
	var languages: Dictionary = Settings.get_languages()
	for language: String in languages:
		option_button_language.add_item(language)
		option_button_language.set_item_metadata(option_button_language.item_count - 1, languages[language])
	option_button_language.selected = languages.values().find(Settings.get_language())
	option_button_language.item_selected.connect(func(index: int) -> void:
			Settings.set_language(option_button_language.get_item_metadata(index) as String))

	# - Theme button.
	var themes: Dictionary = Settings.get_themes()
	for theme_name: String in themes:
		if theme_name == "":
			option_button_theme.add_separator()
		else:
			option_button_theme.add_item(theme_name)
			option_button_theme.set_item_metadata(option_button_theme.item_count - 1, themes[theme_name])
	option_button_theme.selected = themes.values().find(Settings.get_theme_path())
	option_button_theme.item_selected.connect(func(index: int) -> void:
			Settings.set_theme_path(option_button_theme.get_item_metadata(index) as String))


func _setup_basics_tab() -> void:
	option_button_video_drag.add_item("Keep Audio & Video linked")
	option_button_video_drag.set_item_metadata(0, false)
	option_button_video_drag.add_item("Always split Audio to a new track")
	option_button_video_drag.set_item_metadata(1, true)

	var default_split: bool = Settings.get_module_setting("core_timeline_panel", "video_drag_default_split", false)
	option_button_video_drag.selected = 1 if default_split else 0
	option_button_video_drag.item_selected.connect(func(index: int) -> void:
			Settings.set_module_setting(
					"core_timeline_panel", "video_drag_default_split",
					option_button_video_drag.get_item_metadata(index)))


func _bind_shortcut(line_edit: LineEdit, action: String) -> void:
	var events: Array[InputEvent] = Settings.get_events_for_action(action)
	line_edit.text = _get_event_text(events[0]) if events.size() > 0 else "None"
	line_edit.focus_entered.connect(func() -> void:
			listening_line_edit = line_edit
			listening_action = action
			line_edit.text = "Press any key...")


func _setup_editing_tab() -> void:
	_bind_shortcut(grid_modes.get_node("LineEdit") as LineEdit, "timeline_mode_select")
	_bind_shortcut(grid_modes.get_node("CutModeLineEdit") as LineEdit, "timeline_mode_split")

	_bind_shortcut(grid_shortcuts.get_node("CutPlayheadLineEdit") as LineEdit, "split_clips_at_playhead")
	_bind_shortcut(grid_shortcuts.get_node("DeleteLineEdit") as LineEdit, "delete_clips")
	_bind_shortcut(grid_shortcuts.get_node("CutCursorLineEdit") as LineEdit, "split_clips_at_mouse")
	_bind_shortcut(grid_shortcuts.get_node("RippleDeleteLineEdit") as LineEdit, "ripple_delete_clips")
	_bind_shortcut(grid_shortcuts.get_node("RemoveEmptySpaceLineEdit") as LineEdit, "remove_empty_space")
	_bind_shortcut(grid_shortcuts.get_node("OpenMarkerPopupLineEdit") as LineEdit, "open_marker_popup")
	_bind_shortcut(grid_shortcuts.get_node("DuplicateLineEdit") as LineEdit, "duplicate_selected_clips")
	_bind_shortcut(grid_shortcuts.get_node("OpenEffectsPopupLineEdit") as LineEdit, "add_effect")
	_bind_shortcut(grid_shortcuts.get_node("TrimToStartLineEdit") as LineEdit, "trim_to_clip_start")
	_bind_shortcut(grid_shortcuts.get_node("FocusOnPlayheadLineEdit") as LineEdit, "focus_on_playhead")
	_bind_shortcut(grid_shortcuts.get_node("TrimToEndLineEdit") as LineEdit, "trim_to_clip_end")
	_bind_shortcut(grid_shortcuts.get_node("FocusOnTimelineLineEdit") as LineEdit, "timeline_zoom_full")


func _setup_rendering_tab() -> void:
	_bind_shortcut(region_in_line_edit, "render_region_in")
	_bind_shortcut(region_out_line_edit, "render_region_out")

	# TODO: Load in all default profiles instead of doing it manually.
	var profiles: Array[String] = ["YouTube", "YouTube HQ", "AV1", "VP9", "VP8"]
	for profile: String in profiles:
		option_button_default_profile.add_item(profile)

	var current_profile: String = Settings.get_default_render_profile()
	var index: int = profiles.find(current_profile)
	if index != -1:
		option_button_default_profile.selected = index

	option_button_default_profile.item_selected.connect(func(i: int) -> void:
			Settings.set_default_render_profile(option_button_default_profile.get_item_text(i)))


func _setup_extras_tab() -> void:
	check_button_auto_save.button_pressed = Settings.get_auto_save()
	check_button_auto_save.toggled.connect(Settings.set_auto_save)

	option_button_empty_space.add_item("Seek Playhead")
	option_button_empty_space.set_item_metadata(0, 0)
	option_button_empty_space.add_item("Clear Selection")
	option_button_empty_space.set_item_metadata(1, 1)

	var current_action: int = Settings.get_module_setting("core_timeline_panel", "empty_space_click_action", 0)
	option_button_empty_space.selected = 1 if current_action == 1 else 0
	option_button_empty_space.item_selected.connect(func(index: int) -> void:
			Settings.set_module_setting(
					"core_timeline_panel", "empty_space_click_action",
					option_button_empty_space.get_item_metadata(index)))

	spinbox_resolution_x.value = Settings.get_default_resolution_x()
	spinbox_resolution_y.value = Settings.get_default_resolution_y()
	spinbox_framerate.value = Settings.get_default_framerate()

	spinbox_resolution_x.value_changed.connect(func(val: float) -> void: Settings.set_default_resolution_x(int(val)))
	spinbox_resolution_y.value_changed.connect(func(val: float) -> void: Settings.set_default_resolution_y(int(val)))
	spinbox_framerate.value_changed.connect(Settings.set_default_framerate)
