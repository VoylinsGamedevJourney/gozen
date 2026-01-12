extends Node


signal on_show_menu_bar_changed(value: bool)


const PATH: String = "user://settings"


var _data: SettingsData = SettingsData.new()


var fonts: Dictionary[String, SystemFont] = {}



func _ready() -> void:
	for arg: String in OS.get_cmdline_args():
		if arg.to_lower() == "reset_settings": save()

	if !FileAccess.file_exists(PATH):
		_data.language = get_system_locale()
		_data.display_scale = get_display_scale()
		_data.default_project_path = OS.get_executable_path().trim_suffix(
				OS.get_executable_path().get_file())
	elif DataManager.load_data(PATH, _data):
		printerr("Couldn't load settings! ", FileAccess.get_open_error())

	load_system_fonts()
	apply_language()
	apply_display_scale()
	apply_theme()
	apply_shortcuts()

	load_new_shortcuts()

	CommandManager.register(
			"command_editor_settings", open_settings_menu, "open_settings")


func save() -> void:
	if DataManager.save_data(PATH, _data):
		printerr("Something went wrong saving settings! ", FileAccess.get_open_error())


func open_settings_menu() -> void:
	PopupManager.open_popup(PopupManager.POPUP.SETTINGS)


func load_system_fonts() -> void:
	for font: String in OS.get_system_fonts():
		var system_font: SystemFont = SystemFont.new()

		system_font.font_names = [font]
		fonts[font] = system_font


func get_system_locale() -> String:
	if OS.get_locale() in TranslationServer.get_loaded_locales():
		return OS.get_locale() # Language with country code found.
	elif OS.get_locale_language() in TranslationServer.get_loaded_locales():
		return OS.get_locale_language() # Language code found.

	# Next up, get the first entry which has the language code, this can happen
	# if we only have the language available with a certain country code.
	for loaded_locale: String in TranslationServer.get_loaded_locales():
		if loaded_locale.begins_with(OS.get_locale_language()):
			return loaded_locale
	
	return "en" # Return English as a default.


# Appearance set/get
func set_language(code: String) -> void:
	_data.language = code
	apply_language()


func apply_language() -> void:
	TranslationServer.set_locale(get_language())


func get_language() -> String:
	return _data.language


func get_languages() -> Dictionary:
	var temp_language_data: Dictionary[String, String] = {}
	var language_data: Dictionary[String, String] = {}

	# Get all the 
	for code: String in TranslationServer.get_loaded_locales():
		var key: String = code.split('_')[0]

		if Localization.native_locale_names.has(key):
			key = Localization.native_locale_names[key]
		else:
			key = TranslationServer.get_locale_name(key)

		if code.contains('_'): # Country code present
			var country_code: String = code.split('_')[1]

			if Localization.native_country_names.has(country_code):
				key += " (" + Localization.native_country_names[country_code] + ")"
			else:
				key += " (" + TranslationServer.get_country_name(country_code) + ")"

		temp_language_data[key] = code
	
	var keys: PackedStringArray = temp_language_data.keys()
	keys.sort()

	for key: String in keys:
		language_data[key] = temp_language_data[key]

	return language_data


func set_display_scale(value: float) -> void:
	_data.display_scale = value
	apply_display_scale()


func set_display_scale_int(value: int) -> void:
	_data.display_scale = float(value) / 100
	apply_display_scale()


func apply_display_scale() -> void:
	get_tree().root.content_scale_factor = _data.display_scale


func get_display_scale() -> float:
	var size: Vector2 = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())

	if size.y > 1100:
		return 1.5
	elif size.y < 1000:
		return 0.5

	return 1.0


func get_display_scale_int() -> int:
	return int(_data.display_scale * 100)


func set_theme(new_theme: SettingsData.THEME) -> void:
	_data.theme = new_theme
	apply_theme()


func apply_theme() -> void:
	match _data.theme:
		_data.THEME.DARK:
			get_tree().root.theme = null  # Default is dark
		_data.THEME.LIGHT:
			get_tree().root.theme = load(Library.THEME_LIGHT)


func get_theme() -> SettingsData.THEME:
	return _data.theme


func get_themes() -> Dictionary[String, SettingsData.THEME]:
	var themes: Dictionary[String, SettingsData.THEME] = {
		"Dark": _data.THEME.DARK,
		"Light": _data.THEME.LIGHT}

	return themes


func set_show_menu_bar(value: bool) -> void:
	_data.show_menu_bar = value
	on_show_menu_bar_changed.emit(value)


func get_show_menu_bar() -> bool:
	return _data.show_menu_bar


func set_audio_waveform_style(style: SettingsData.AUDIO_WAVEFORM_STYLE) -> void:
	_data.audio_waveform_style = style

	for file_data: FileData in FileHandler.data.values():
		file_data.update_wave.emit()


func get_audio_waveform_style() -> int:
	return _data.audio_waveform_style


func get_audio_waveform_styles() -> Dictionary[String, SettingsData.AUDIO_WAVEFORM_STYLE]:
	var styles: Dictionary[String, SettingsData.AUDIO_WAVEFORM_STYLE] = {
		"Center": SettingsData.AUDIO_WAVEFORM_STYLE.CENTER,
		"Bottom to Top": SettingsData.AUDIO_WAVEFORM_STYLE.BOTTOM_TO_TOP,
		"Top to bottom": SettingsData.AUDIO_WAVEFORM_STYLE.TOP_TO_BOTTOM}

	return styles


func set_audio_waveform_amp(value: float) -> void:
	_data.audio_waveform_amp = value


func get_audio_waveform_amp() -> float:
	return _data.audio_waveform_amp


func set_use_native_dialog(value: bool) -> void:
	_data.use_native_dialog = value


func get_use_native_dialog() -> bool:
	return _data.use_native_dialog


# Defaults set/get
func set_image_duration(duration: int) -> void:
	_data.image_duration = duration


func get_image_duration() -> int:
	return _data.image_duration


func set_color_duration(duration: int) -> void:
	_data.color_duration = duration


func get_color_duration() -> int:
	return _data.color_duration


func set_text_duration(duration: int) -> void:
	_data.text_duration = duration


func get_text_duration() -> int:
	return _data.text_duration


func set_default_project_path(path: String) -> void:
	_data.default_project_path = path


func get_default_project_path() -> String:
	return _data.default_project_path


func set_default_resolution(res: Vector2i) -> void:
	_data.default_resolution = res


func set_default_resolution_x(x_value: int) -> void:
	_data.default_resolution.x = x_value


func set_default_resolution_y(y_value: int) -> void:
	_data.default_resolution.y = y_value


func get_default_resolution() -> Vector2i:
	return _data.default_resolution


func get_default_resolution_x() -> int:
	return _data.default_resolution.x


func get_default_resolution_y() -> int:
	return _data.default_resolution.y


func set_default_framerate(framerate: float) -> void:
	_data.default_framerate = framerate
	

func get_default_framerate() -> float:
	return _data.default_framerate


#--- Timeline set/get ---
func set_tracks_amount(track_amount: int) -> void:
	_data.tracks_amount = track_amount


func get_tracks_amount() -> int:
	return _data.tracks_amount


func set_pause_after_drag(value: bool) -> void:
	_data.pause_after_drag = value


func get_pause_after_drag() -> bool:
	return _data.pause_after_drag


func set_delete_empty_modifier(new_key: int) -> void:
	_data.delete_empty_modifier = new_key
	

func get_delete_empty_modifier() -> int:
	return _data.delete_empty_modifier


func get_delete_empty_modifiers() -> Dictionary[String, int]:
	var mods: Dictionary[String, int] = {
		"": KEY_NONE,
		"Control": KEY_CTRL,
		"Shift": KEY_SHIFT}

	return mods


#--- Markers set/get ---
func set_marker_name(index: int, text: String) -> void:
	_data.marker_names[index] = text


func get_marker_name(index: int) -> String:
	return _data.marker_names[index]


func get_marker_names() -> PackedStringArray:
	return _data.marker_names


func set_marker_color(index: int, color: Color) -> void:
	_data.marker_colors[index] = color


func get_marker_color(index: int) -> Color:
	return _data.marker_colors[index]


func get_marker_colors() -> PackedColorArray:
	return _data.marker_colors


#--- Extra set/get ---
func set_check_version(value: bool) -> void:
	_data.check_version = value
	

func get_check_version() -> int:
	return _data.check_version


func set_auto_save(value: bool) -> void:
	_data.auto_save = value
	if value:
		Project._auto_save()
	

func get_auto_save() -> bool:
	return _data.auto_save


#--- Input set/get ---
func load_new_shortcuts(reset: bool = false) -> void:
	# Add new (or all) shortcuts to the Settings data
	for action: StringName in InputMap.get_actions():
		if reset:
			_data.shortcuts[action] = InputMap.action_get_events(action)
		elif _data.shortcuts.has(action):
			continue
		elif action.begins_with("ui_") or action.begins_with("_"):
			continue
		else:
			_data.shortcuts[action] = InputMap.action_get_events(action)


func apply_shortcuts() -> void:
	for action: String in _data.shortcuts:
		if !InputMap.has_action(action):
			continue

		InputMap.action_erase_events(action)

		for event: InputEvent in _data.shortcuts[action]:
			InputMap.action_add_event(action, event)


func reset_shortcuts_to_default() -> void:
	InputMap.load_from_project_settings()
	load_new_shortcuts(true)
	apply_shortcuts()


func set_shortcut(action: String, events: Array[InputEvent]) -> void:
	if !_data.shortcuts.has(action):
		return

	_data.shortcuts[action] = events
	InputMap.action_erase_events(action)

	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


func set_shortcut_event_at_index(action: String, index: int, event: InputEvent) -> void:
	var events: Array[InputEvent] = get_events_for_action(action)
	
	if index >= 0 and index < events.size():
		events[index] = event

	# Clean nulls
	var cleaned_events: Array[InputEvent] = []
	
	for action_event: InputEvent in events:
		if action_event != null:
			cleaned_events.append(action_event)

	set_shortcut(action, cleaned_events)


func get_events_for_action(action: String) -> Array[InputEvent]:
	var events: Array[InputEvent] = _data.shortcuts[action]

	# We need to make certain we have exactly 2
	if events.size() > 2:
		events.resize(2)
		return events

	while events.size() < 2:
		events.append(null)

	return events
		
