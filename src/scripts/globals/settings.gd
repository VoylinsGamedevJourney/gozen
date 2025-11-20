extends Node


signal on_show_menu_bar_changed(value: bool)


const PATH: String = "user://settings"


enum THEME { DARK, LIGHT }
enum AUDIO_WAVEFORM_STYLE { CENTER, BOTTOM_TO_TOP, TOP_TO_BOTTOM }


# Private variables
var _defaults: Dictionary[String, Variant] = {}
var _fonts: Dictionary[String, SystemFont] = {}


# Appearance
var language: String = get_system_locale()
var display_scale: float = get_display_scale()
var theme: THEME = THEME.DARK
var show_menu_bar: bool = true
var audio_waveform_style: AUDIO_WAVEFORM_STYLE = AUDIO_WAVEFORM_STYLE.CENTER 

# Defaults
var image_duration: int = 300
var color_duration: int = 300
var text_duration: int = 300
var default_project_path: String = OS.get_executable_path().trim_suffix(OS.get_executable_path().get_file())
var default_resolution: Vector2i = Vector2i(1920, 1080)
var default_framerate: float = 30.0

# Timeline
var tracks_amount: int = 6 # The amount of tracks
var pause_after_drag: bool = false
var delete_empty_modifier: int = KEY_NONE

# Markers
var marker_colors: PackedColorArray = [ Color.PURPLE, Color.GREEN, Color.BLUE, Color.ORANGE, Color.RED ]

# Extra
var check_version: bool = false
var auto_save: bool = true



func _ready() -> void:
	_defaults = DataManager.get_data(self)

	for arg: String in OS.get_cmdline_args():
		if arg.to_lower() == "reset_settings":
			save()

	var error: int = DataManager.load_data(PATH, self)

	if error not in [OK, ERR_FILE_NOT_FOUND]:
		printerr("Something went wrong loading settings! ", error)

	load_system_fonts()

	apply_language()
	apply_display_scale()
	apply_theme()


func save() -> void:
	var error: int = DataManager.save_data(PATH, self)

	if error:
		printerr("Something went wrong saving settings! ", error)


func reset_to_defaults() -> void:
	for property_name: String in _defaults:
		set(property_name, _defaults[property_name])


func open_settings_menu() -> void:
	PopupManager.open_popup(PopupManager.POPUP.SETTINGS)


func load_system_fonts() -> void:
	for font: String in OS.get_system_fonts():
		var system_font: SystemFont = SystemFont.new()

		system_font.font_names = [font]
		_fonts[font] = system_font


func get_system_locale() -> String:
	var locale: String = OS.get_locale()

	# Check if language with country code can be found.
	if OS.get_locale() in TranslationServer.get_loaded_locales():
		return locale

	# Next up check if only the language code can be found.
	locale = OS.get_locale_language()
	if locale in TranslationServer.get_loaded_locales():
		return locale

	# Next up, get the first entry which has the language code,
	# this can happen if we only have instances of the language being
	# available from a certain country.
	for loaded_locale: String in TranslationServer.get_loaded_locales():
		if loaded_locale.begins_with(locale):
			return loaded_locale

	# Return English as a default
	return "en"


## Returns a Dictionary { Section_name: Dictionary {Settings label, Settings option node} }
func get_settings_menu_options() -> Dictionary[String, Array]:
	var data: Dictionary[String, Array] = {}
	
	data["title_appearance"] = [
		SettingsOption.create_label("setting_language"),
		SettingsOption.create_option_button(
				get_languages(), 
				get_languages().values().find(get_language()),
				set_language,
				TYPE_STRING,
				""),
		SettingsOption.create_label("setting_display_scale"),
		SettingsOption.create_spinbox(
				get_display_scale_int(),
				50, 300, 5, false, false,
				set_display_scale_int,
				"setting_tooltip_display_scale",
				"%"
				),
		SettingsOption.create_label("setting_theme"),
		SettingsOption.create_option_button(
				get_themes(),
				get_themes().values().find(get_theme()),
				set_theme,
				TYPE_INT,
				"setting_tooltip_theme"),
		SettingsOption.create_label("setting_show_menu_bar"),
		SettingsOption.create_check_button(
				get_show_menu_bar(),
				set_show_menu_bar,
				""),
		SettingsOption.create_label("setting_waveform_style"),
		SettingsOption.create_option_button(
				get_audio_waveform_styles(),
				get_audio_waveform_styles().values().find(get_audio_waveform_style()),
				set_audio_waveform_style,
				TYPE_INT,
				"setting_tooltip_theme")
	]

	# Adding the Defaults section.
	data["title_defaults"] = [
		SettingsOption.create_label("setting_default_image_duration"),
		SettingsOption.create_spinbox(
				get_image_duration(),
				1, 100, 1, false, true,
				set_image_duration,
				"setting_tooltip_duration_in_frames"),
		SettingsOption.create_label("setting_default_color_duration"),
		SettingsOption.create_spinbox(
				get_color_duration(),
				1, 100, 1, false, true,
				set_color_duration,
				"setting_tooltip_duration_in_frames"),
		SettingsOption.create_label("setting_default_text_duration"),
		SettingsOption.create_spinbox(
				get_text_duration(),
				1, 100, 1, false, true,
				set_text_duration,
				"setting_tooltip_duration_in_frames"),
		SettingsOption.create_label("setting_default_project_resolution"),
		SettingsOption.create_default_resolution_hbox(),
		SettingsOption.create_label("setting_default_project_framerate"),
		SettingsOption.create_spinbox(
				get_default_framerate(),
				1, 100, 1, false, true,
				set_default_framerate,
				"setting_tooltip_default_project_framerate")
	]

	# Adding the Timeline section.
	data["title_timeline"] = [
		SettingsOption.create_label("setting_default_track_amount"),
		SettingsOption.create_spinbox(
				get_tracks_amount(),
				1, 32, 1, false, false,
				set_default_framerate,
				""),
		SettingsOption.create_label("setting_pause_after_dragging"),
		SettingsOption.create_check_button(
				get_pause_after_drag(),
				set_pause_after_drag,
				""),
		SettingsOption.create_label("setting_delete_empty_space_mod"),
		SettingsOption.create_option_button(
				get_delete_empty_modifiers(), 
				get_delete_empty_modifiers().values().find(get_delete_empty_modifier()),
				set_delete_empty_modifier,
				TYPE_INT,
				"setting_tooltip_delete_empty_space_mod")
	]

	# Adding the Markers section.
	# NOTE: We only have 5 main markers for now.
	# TODO: Change this into a loop
	data["title_markers"] = [
		SettingsOption.create_label("settings_marker_one"),
		SettingsOption.create_color_picker(
				get_marker_color(0),
				set_marker_color.bind(0),
				"tooltip_setting_marker_color"),
		SettingsOption.create_label("settings_marker_two"),
		SettingsOption.create_color_picker(
				get_marker_color(1),
				set_marker_color.bind(1),
				"tooltip_setting_marker_color"),
		SettingsOption.create_label("settings_marker_three"),
		SettingsOption.create_color_picker(
				get_marker_color(2),
				set_marker_color.bind(2),
				"tooltip_setting_marker_color"),
		SettingsOption.create_label("settings_marker_four"),
		SettingsOption.create_color_picker(
				get_marker_color(3),
				set_marker_color.bind(3),
				"tooltip_setting_marker_color"),
		SettingsOption.create_label("settings_marker_five"),
		SettingsOption.create_color_picker(
				get_marker_color(4),
				set_marker_color.bind(4),
				"tooltip_setting_marker_color")
	]

	# Adding the Extras section.
	data["title_extras"] = [
		SettingsOption.create_label("setting_check_version"),
		SettingsOption.create_check_button(
				get_check_version(),
				set_check_version,
				"setting_tooltip_check_version"),
		SettingsOption.create_label("setting_auto_save"),
		SettingsOption.create_check_button(
				get_auto_save(),
				set_auto_save,
				"setting_tooltip_auto_save")
	]

	return data


# Appearance set/get
func set_language(code: String) -> void:
	language = code
	apply_language()


func apply_language() -> void:
	TranslationServer.set_locale(language)


func get_language() -> String:
	return language


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
	display_scale = value
	apply_display_scale()


func set_display_scale_int(value: int) -> void:
	display_scale = float(value) / 100
	apply_display_scale()


func apply_display_scale() -> void:
	get_tree().root.content_scale_factor = display_scale


func get_display_scale() -> float:
	var size: Vector2 = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())

	if size.y > 1100:
		return 1.5
	elif size.y < 1000:
		return 0.5

	return 1.0


func get_display_scale_int() -> int:
	return int(display_scale * 100)


func set_theme(new_theme: THEME) -> void:
	theme = new_theme
	apply_theme()


func apply_theme() -> void:
	match theme:
		THEME.DARK:
			get_tree().root.theme = null  # Default is dark
		THEME.LIGHT:
			get_tree().root.theme = load(Library.THEME_LIGHT)


func get_theme() -> THEME:
	return theme


func get_themes() -> Dictionary[String, THEME]:
	var themes: Dictionary[String, THEME] = {
		"Dark": THEME.DARK,
		"Light": THEME.LIGHT,
	}
	return themes


func set_show_menu_bar(value: bool) -> void:
	show_menu_bar = value
	on_show_menu_bar_changed.emit(value)


func get_show_menu_bar() -> bool:
	return show_menu_bar


func set_audio_waveform_style(style: AUDIO_WAVEFORM_STYLE) -> void:
	audio_waveform_style = style
	for file_data: FileData in FileManager.data.values():
		file_data.update_wave.emit()


func get_audio_waveform_style() -> AUDIO_WAVEFORM_STYLE:
	return audio_waveform_style


func get_audio_waveform_styles() -> Dictionary[String, AUDIO_WAVEFORM_STYLE]:
	var styles: Dictionary[String, AUDIO_WAVEFORM_STYLE] = {
		"Center": AUDIO_WAVEFORM_STYLE.CENTER,
		"Bottom to Top": AUDIO_WAVEFORM_STYLE.BOTTOM_TO_TOP,
		"Top to bottom": AUDIO_WAVEFORM_STYLE.TOP_TO_BOTTOM,
	}
	return styles


# Defaults set/get
func set_image_duration(duration: int) -> void:
	image_duration = duration


func get_image_duration() -> int:
	return image_duration


func set_color_duration(duration: int) -> void:
	color_duration = duration


func get_color_duration() -> int:
	return color_duration


func set_text_duration(duration: int) -> void:
	text_duration = duration


func get_text_duration() -> int:
	return text_duration


func set_default_project_path(path: String) -> void:
	default_project_path = path


func get_default_project_path() -> String:
	return default_project_path


func set_default_resolution(res: Vector2i) -> void:
	default_resolution = res


func set_default_resolution_x(x_value: int) -> void:
	default_resolution.x = x_value


func set_default_resolution_y(y_value: int) -> void:
	default_resolution.y = y_value


func get_default_resolution() -> Vector2i:
	return default_resolution


func get_default_resolution_x() -> int:
	return default_resolution.x


func get_default_resolution_y() -> int:
	return default_resolution.y


func set_default_framerate(framerate: float) -> void:
	default_framerate = framerate
	

func get_default_framerate() -> float:
	return default_framerate


#--- Timeline set/get ---
func set_tracks_amount(track_amount: int) -> void:
	tracks_amount = track_amount


func get_tracks_amount() -> int:
	return tracks_amount


func set_pause_after_drag(value: bool) -> void:
	pause_after_drag = value


func get_pause_after_drag() -> bool:
	return pause_after_drag


func set_delete_empty_modifier(new_key: int) -> void:
	delete_empty_modifier = new_key
	

func get_delete_empty_modifier() -> int:
	return delete_empty_modifier


func get_delete_empty_modifiers() -> Dictionary[String, int]:
	var mods: Dictionary[String, int] = {
		"": KEY_NONE,
		"Control": KEY_CTRL,
		"Shift": KEY_SHIFT
	}
	return mods


#--- Markers set/get ---
func set_marker_color(index: int, color: Color) -> void:
	marker_colors[index] = color


func get_marker_color(index: int) -> Color:
	return marker_colors[index]


func get_marker_colors() -> PackedColorArray:
	return marker_colors


#--- Extra set/get ---
func set_check_version(value: bool) -> void:
	check_version = value
	

func get_check_version() -> int:
	return check_version


func set_auto_save(value: bool) -> void:
	auto_save = value
	if value:
		Project._auto_save()
	

func get_auto_save() -> bool:
	return auto_save

