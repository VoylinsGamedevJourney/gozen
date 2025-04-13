extends PanelContainer

const DB_MIN: float = -60.0
const DB_MAX: float = 0.0


@export var audio_bar_left: TextureProgressBar
@export var audio_bar_right: TextureProgressBar



func _process(_delta: float) -> void:
	if !Editor.is_playing:
		return

	var peak_db_left: float = AudioServer.get_bus_peak_volume_left_db(0, 0)
	var peak_db_right: float = AudioServer.get_bus_peak_volume_right_db(0, 0)

	if is_inf(peak_db_left):
		audio_bar_left.value = DB_MIN # Silence detected
	else:
		audio_bar_left.value = clampf(peak_db_left, DB_MIN, DB_MAX)

	if is_inf(peak_db_right):
		audio_bar_right.value = DB_MIN # Silence detected
	else:
		audio_bar_right.value = clampf(peak_db_right, DB_MIN, DB_MAX)

