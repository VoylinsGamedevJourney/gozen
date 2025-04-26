extends Node


const PATH: String = "user://settings"


var data: SettingsData = SettingsData.new()



func _ready() -> void:
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


func get_default_resolution() -> Vector2i:
	return data.default_resolution


func set_default_framerate(framerate: float) -> void:
	data.default_framerate = framerate
	

func get_default_framerate() -> float:
	return data.default_framerate


func set_tracks_amount(track_amount: int) -> void:
	data.tracks_amount = track_amount


func get_tracks_amount() -> int:
	return data.tracks_amount


func set_pause_after_drag(value: bool) -> void:
	data.pause_after_drag = value


func get_pause_after_drag() -> bool:
	return data.pause_after_drag

