extends PanelContainer

const DB_MIN: float = -60.0
const DB_MAX: float = 0.0


@export var bar_left: TextureProgressBar
@export var bar_right: TextureProgressBar


func _process(_delta: float) -> void:
	var db_left: float = DB_MIN
	var db_right: float = DB_MIN
	if EditorCore.is_playing:
		db_left = AudioServer.get_bus_peak_volume_left_db(0, 0)
		db_right = AudioServer.get_bus_peak_volume_right_db(0, 0)

	if is_inf(db_left):
		bar_left.value = DB_MIN # Silence detected.
	else:
		bar_left.value = lerp(bar_left.value, clampf(db_left, DB_MIN, DB_MAX), 0.5)

	if is_inf(db_right):
		bar_right.value = DB_MIN # Silence detected.
	else:
		bar_right.value = lerp(bar_right.value, clampf(db_right, DB_MIN, DB_MAX), 0.5)
