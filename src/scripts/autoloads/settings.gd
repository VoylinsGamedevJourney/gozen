extends Node

signal on_show_menu_bar_changed(value: bool)
signal on_show_time_mode_bar_changed(value: bool)
signal localization_updated


const PATH: String = "user://settings"
const PATH_THEMES: String = "user://themes/"


var data: SettingsData = SettingsData.new()


var fonts: Dictionary[String, SystemFont] = {}
var custom_themes: Dictionary = {} # { Name: Path }



func _ready() -> void:
	for arg: String in OS.get_cmdline_args():
		if arg.to_lower() == "reset_settings": save()

	if !FileAccess.file_exists(PATH):
		data.language = get_system_locale()
		data.display_scale = get_display_scale()
		data.default_project_path = OS.get_executable_path().trim_suffix(
				OS.get_executable_path().get_file())
	elif DataManager.load_data(PATH, data):
		printerr("Settings: Couldn't load settings! ", FileAccess.get_open_error())

	if !DirAccess.dir_exists_absolute(PATH_THEMES):
		DirAccess.make_dir_absolute(PATH_THEMES)

	load_system_fonts()
	load_custom_themes()

	apply_language()
	apply_display_scale()
	apply_theme()
	apply_shortcuts()

	load_new_shortcuts()


func save() -> void:
	if DataManager.save_data(PATH, data):
		printerr("Settings: Something went wrong saving settings! ", FileAccess.get_open_error())


func open_settings_menu() -> void:
	PopupManager.open_popup(PopupManager.POPUP.SETTINGS)


func load_system_fonts() -> void:
	for font: String in OS.get_system_fonts():
		var system_font: SystemFont = SystemFont.new()

		system_font.font_names = [font]
		fonts[font] = system_font


func load_custom_themes() -> void:
	var default_themes: Dictionary[String, String] = get_themes()
	var dir: DirAccess = DirAccess.open(PATH_THEMES)
	if !dir: return

	dir.list_dir_begin()

	var file_name: String = dir.get_next()

	while file_name != "":
		if !dir.current_is_dir() and file_name.ends_with(".tres"):
			var theme_name: String = file_name.get_basename().replace('_', ' ')

			if not theme_name in default_themes and not theme_name in custom_themes:
				custom_themes[theme_name] = PATH_THEMES + file_name

		file_name = dir.get_next()


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
	data.language = code
	apply_language()
	localization_updated.emit()


func apply_language() -> void:
	TranslationServer.set_locale(get_language())


func get_language() -> String:
	return data.language


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
	data.display_scale = value
	apply_display_scale()


func set_display_scale_int(value: int) -> void:
	data.display_scale = float(value) / 100
	apply_display_scale()


func apply_display_scale() -> void:
	get_tree().root.content_scale_factor = data.display_scale


func get_display_scale() -> float:
	var size: Vector2 = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())

	if size.y > 1100:
		return 1.5
	elif size.y < 1000:
		return 0.5

	return 1.0


func get_display_scale_int() -> int:
	return int(data.display_scale * 100)


func set_theme_path(new_path: String) -> void:
	data.theme = new_path
	apply_theme()


func apply_theme() -> void:
	if FileAccess.file_exists(data.theme):
		get_tree().root.theme = load(data.theme)
	else: # Default is dark
		get_tree().root.theme = null


func get_theme_path() -> String:
	return data.theme


func get_themes() -> Dictionary[String, String]:
	var themes: Dictionary[String, String] = {
		"Default Dark": Library.THEME_DARK,
		"Default Light": Library.THEME_LIGHT,
		"": "" } # Separator

	for custom_theme_name: String in custom_themes:
		if !themes.has(custom_theme_name):
			themes[custom_theme_name] = custom_themes[custom_theme_name]

	return themes


func set_show_menu_bar(value: bool) -> void:
	data.show_menu_bar = value
	on_show_menu_bar_changed.emit(value)


func get_show_menu_bar() -> bool:
	return data.show_menu_bar


func set_audio_waveform_style(style: SettingsData.AUDIO_WAVEFORM_STYLE) -> void:
	data.audio_waveform_style = style
	Project.files.update_audio_waves()


func get_audio_waveform_style() -> int:
	return data.audio_waveform_style


func get_audio_waveform_styles() -> Dictionary[String, SettingsData.AUDIO_WAVEFORM_STYLE]:
	var styles: Dictionary[String, SettingsData.AUDIO_WAVEFORM_STYLE] = {
		"Center": SettingsData.AUDIO_WAVEFORM_STYLE.CENTER,
		"Bottom to Top": SettingsData.AUDIO_WAVEFORM_STYLE.BOTTOM_TO_TOP,
		"Top to bottom": SettingsData.AUDIO_WAVEFORM_STYLE.TOP_TO_BOTTOM}

	return styles


func set_audio_waveform_amp(value: float) -> void:
	data.audio_waveform_amp = value


func get_audio_waveform_amp() -> float:
	return data.audio_waveform_amp


func set_use_native_dialog(value: bool) -> void:
	data.use_native_dialog = value


func get_use_native_dialog() -> bool:
	return data.use_native_dialog


# Defaults set/get
func set_image_duration(duration: int) -> void:
	data.image_duration = duration


func get_image_duration() -> int:
	return data.image_duration


func set_color_duration(duration: int) -> void:
	data.color_duration = duration


func get_color_duration() -> int:
	return data.color_duration


func set_text_duration(duration: int) -> void:
	data.text_duration = duration


func get_text_duration() -> int:
	return data.text_duration


func set_default_project_path(path: String) -> void:
	data.default_project_path = path


func get_default_project_path() -> String:
	return data.default_project_path


func set_default_resolution(res: Vector2i) -> void:
	data.default_resolution = res


func set_default_resolution_x(x_value: int) -> void:
	data.default_resolution.x = x_value


func set_default_resolution_y(y_value: int) -> void:
	data.default_resolution.y = y_value


func get_default_resolution() -> Vector2i:
	return data.default_resolution


func get_default_resolution_x() -> int:
	return data.default_resolution.x


func get_default_resolution_y() -> int:
	return data.default_resolution.y


func set_default_framerate(framerate: float) -> void:
	data.default_framerate = framerate


func get_default_framerate() -> float:
	return data.default_framerate


func set_use_proxies(value: bool) -> void:
	data.use_proxies = value
	Project.files.reload_videos()


func get_use_proxies() -> bool:
	return data.use_proxies


#--- Timeline set/get ---
func set_tracks_amount(track_amount: int) -> void:
	data.tracks_amount = track_amount


func get_tracks_amount() -> int:
	return data.tracks_amount


func set_pause_after_drag(value: bool) -> void:
	data.pause_after_drag = value


func get_pause_after_drag() -> bool:
	return data.pause_after_drag


func set_delete_empty_modifier(new_key: int) -> void:
	data.delete_empty_modifier = new_key


func get_delete_empty_modifier() -> int:
	return data.delete_empty_modifier


func get_delete_empty_modifiers() -> Dictionary[String, int]:
	var mods: Dictionary[String, int] = {
		"": KEY_NONE,
		"Control": KEY_CTRL,
		"Shift": KEY_SHIFT}

	return mods


func set_show_time_mode_bar(value: bool) -> void:
	data.show_time_mode_bar = value
	on_show_time_mode_bar_changed.emit(value)


func get_show_time_mode_bar() -> bool:
	return data.show_time_mode_bar


#--- Markers set/get ---
func set_marker_name(index: int, text: String) -> void:
	data.marker_names[index] = text


func get_marker_name(index: int) -> String:
	return data.marker_names[index]


func get_marker_names() -> PackedStringArray:
	return data.marker_names


func set_marker_color(index: int, color: Color) -> void:
	data.marker_colors[index] = color


func get_marker_color(index: int) -> Color:
	return data.marker_colors[index]


func get_marker_colors() -> PackedColorArray:
	return data.marker_colors


#--- Extra set/get ---
func set_check_version(value: bool) -> void:
	data.check_version = value


func get_check_version() -> int:
	return data.check_version


func set_auto_save(value: bool) -> void:
	data.auto_save = value
	if value:
		Project._auto_save()


func get_auto_save() -> bool:
	return data.auto_save


#--- Input set/get ---
func load_new_shortcuts(reset: bool = false) -> void:
	# Add new (or all) shortcuts to the Settings data
	for action: StringName in InputMap.get_actions():
		if reset:
			data.shortcuts[action] = InputMap.action_get_events(action)
		elif data.shortcuts.has(action):
			continue
		elif action.begins_with("ui_") or action.begins_with("_"):
			continue
		else:
			data.shortcuts[action] = InputMap.action_get_events(action)


func apply_shortcuts() -> void:
	for action: String in data.shortcuts:
		if !InputMap.has_action(action):
			continue

		InputMap.action_erase_events(action)

		for event: InputEvent in data.shortcuts[action]:
			if event != null:
				InputMap.action_add_event(action, event)


func reset_shortcuts_to_default() -> void:
	InputMap.load_from_project_settings()
	load_new_shortcuts(true)
	apply_shortcuts()


func set_shortcut(action: String, events: Array[InputEvent]) -> void:
	if !data.shortcuts.has(action):
		return

	data.shortcuts[action] = events
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
	var events: Array[InputEvent] = data.shortcuts[action]

	# We need to make certain we have exactly 2
	if events.size() > 2:
		events.resize(2)
		return events

	while events.size() < 2:
		events.append(null)

	return events

