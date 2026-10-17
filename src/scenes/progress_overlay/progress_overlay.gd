class_name ProgressOverlay
extends Control

@export var title_label: Label
@export var progress_bar: ProgressBar
@export var progress_hint: Label
@export var status_hbox: HBoxContainer
@export var estimated_time_label: Label
@export var scroll_container: ScrollContainer
@export var vbox: VBoxContainer

@export var close_button: Button


var file_labels: Dictionary = {}
var start_time: int = 0

var _tween: Tween
var _target_value: float = 0.0
var _progress_history: Array[Vector2] = []



func _ready() -> void:
	start_time = Time.get_ticks_msec()
	close_button.visible = false


func update_title(title: String) -> void:
	title_label.text = title


func update(value: int, text: String) -> void:
	_target_value = value
	update_bar(value)
	update_hint(text)
	_update_estimate()


func set_bar(value: int) -> void:
	if _tween: _tween.kill()

	_target_value = value
	progress_bar.value = _target_value


func update_bar(value: int) -> void:
	if _tween: _tween.kill()

	_target_value = value
	_tween = create_tween()
	_tween.tween_property(progress_bar, "value", _target_value, 0.5)


func update_hint(text: String) -> void:
	progress_hint.text = text


func increment_bar(value: float) -> void:
	_target_value += value
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(progress_bar, "value", _target_value, 0.1)
	_update_estimate()


func _update_estimate() -> void:
	if _target_value > 0:
		var remaining: float = Approximator.calculate_remaining(_progress_history, _target_value)
		if remaining == -2.0:
			return
		elif remaining == 0.0:
			estimated_time_label.text = tr("Estimated time") + " - 99:60:60"
			return

		var remaining_str: String = Format.time_str(remaining, true)
		estimated_time_label.text = tr("Estimated time") + " - %s" % remaining_str


func set_state_file_loading(loading_size: int) -> void:
	if progress_hint.visible:
		progress_hint.visible = false
	if !scroll_container.visible:
		scroll_container.visible = true
		scroll_container.custom_minimum_size.y = clampi(loading_size, 0, 10) * 25


## status: 0 = loading, 1 = loaded, -1 = problem.
func update_file(path: String, status: int) -> void:
	if !file_labels.has(path):
		var new_label: Label = Label.new()
		new_label.text = "- " + path.get_file()
		new_label.add_theme_color_override("font_color", get_theme_color("loading_color", "ProgressOverlay"))
		new_label.tooltip_text = path
		file_labels[path] = new_label
		vbox.add_child(new_label)

	if status == -1: # Problem.
		(file_labels[path] as Label).add_theme_color_override("font_color", get_theme_color("error_color", "ProgressOverlay"))
		file_labels[path].tooltip_text = path + "\nThis file could not be loaded."
	elif status == 1: # Loaded.
		(file_labels[path] as Label).add_theme_color_override("font_color", get_theme_color("loaded_color", "ProgressOverlay"))


## If errors happen, we want the user to be able to see them and not close directly.
func show_close() -> void:
	close_button.visible = true
