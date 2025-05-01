extends Node

signal on_show_menu_bar_changed(value: bool)


const PATH: String = "user://settings"


var data: SettingsData = SettingsData.new()

var menu_bar: MenuBar



func _ready() -> void:
	for arg: String in OS.get_cmdline_args():
		if arg.to_lower() == "reset_settings":
			Settings.reset_settings()
			Settings.save()

	if data.load_data(PATH) not in [OK, ERR_FILE_NOT_FOUND]:
		printerr("Something went wrong loading settings! ", data.error)
	apply_theme()
	

func save() -> void:
	if data.save_data(PATH):
		printerr("Something went wrong saving settings! ", data.error)


func reset_settings() -> void:
	data = SettingsData.new()


# Appearance set/get
func set_theme(theme: SettingsData.THEME) -> void:
	data.theme = theme
	apply_theme()


func apply_theme() -> void:
	match data.theme:
		SettingsData.THEME.DARK:
			get_tree().root.theme = null  # Default is dark
		SettingsData.THEME.LIGHT:
			get_tree().root.theme = load("uid://dxq4vg1l5rwhj")


func get_theme() -> SettingsData.THEME:
	return data.theme


func set_show_menu_bar(value: bool) -> void:
	data.show_menu_bar = value
	on_show_menu_bar_changed.emit(value)


func get_show_menu_bar() -> bool:
	return data.show_menu_bar


func set_audio_waveform_style(style: SettingsData.AUDIO_WAVEFORM_STYLE) -> void:
	data.audio_waveform_style = style
	for file_data: FileData in Project.file_data.values():
		file_data.update_wave.emit()


func get_audio_waveform_style() -> SettingsData.AUDIO_WAVEFORM_STYLE:
	return data.audio_waveform_style


# Defaults set/get
func set_image_duration(duration: int) -> void:
	data.image_duration = duration


func get_image_duration() -> int:
	return data.image_duration


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


# Timeline set/get
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

