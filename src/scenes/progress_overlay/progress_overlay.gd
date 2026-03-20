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


func update_bar(value: int) -> void:
	if _tween:
		_tween.kill()
	if value - progress_bar.value > 20:
		progress_bar.value = value
	else:
		_tween = create_tween()
		@warning_ignore("return_value_discarded")
		_tween.tween_property(progress_bar, "value", _target_value, 0.5)


func update_hint(text: String) -> void:
	progress_hint.text = text


func increment_bar(value: float) -> void:
	_target_value += value
	if _tween:
		_tween.kill()
	_tween = create_tween()
	@warning_ignore("return_value_discarded")
	_tween.tween_property(progress_bar, "value", _target_value, 0.1)
	_update_estimate()


func _update_estimate() -> void:
	if _target_value > 0:
		var time_elapsed: float = (Time.get_ticks_msec() - start_time) / 1000.0
		var rate: float = time_elapsed / _target_value
		var remaining_sec: float = rate * (100.0 - _target_value)
		var remaining: String = Utils.format_time_str(remaining_sec, true)
		estimated_time_label.text = "Estimated time - %s" % remaining


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
		new_label.self_modulate = Color.ORANGE
		new_label.tooltip_text = path
		file_labels[path] = new_label
		vbox.add_child(new_label)

	if status == -1: # Problem.
		file_labels[path].self_modulate = Color.RED
		file_labels[path].tooltip_text = path + "\nThis file could not be loaded."
	elif status == 1: # Loaded.
		file_labels[path].self_modulate = Color.GREEN


## If errors happen, we want the user to be able to see them and not close directly.
func show_close() -> void:
	close_button.visible = true
