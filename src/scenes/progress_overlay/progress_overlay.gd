class_name ProgressOverlay
extends Control
# TODO: Add a "Show details" button to explain why files failed to import

@export var title_label: Label
@export var progress_bar: ProgressBar
@export var progress_hint: Label
@export var estimated_time_label: Label
@export var scroll_container: ScrollContainer
@export var vbox: VBoxContainer

@export var close_button: Button


var file_labels: Dictionary = {}
var start_time: int = 0


func _ready() -> void:
	start_time = Time.get_ticks_msec()
	close_button.visible = false


func update_title(title: String) -> void:
	title_label.text = title


func update(value: int, text: String) -> void:
	update_bar(value)
	update_hint(text)

	# Updating estimated time
	var time_elapsed: float = (Time.get_ticks_msec() - start_time) / 1000.0
	var rate: float = time_elapsed / float(value)
	var remaining_sec: float = rate * (100 - float(value))
	var remaining: String = Utils.format_time_str(remaining_sec, true)

	estimated_time_label.text = "Estimated time - %s" % remaining

	await RenderingServer.frame_post_draw


func update_bar(value: int, wait_frame: bool = false) -> void:
	var tween: Tween = create_tween()

	@warning_ignore("return_value_discarded")
	tween.tween_property(progress_bar, "value", value, 1)

	if wait_frame:
		await RenderingServer.frame_post_draw


func update_hint(text: String) -> void:
	progress_hint.text = text


func increment_bar(value: float) -> void:
	var tween: Tween = create_tween()

	@warning_ignore("return_value_discarded")
	tween.tween_property(progress_bar, "value", progress_bar.value + value, 0.1)


func set_state_file_loading(loading_size: int) -> void:
	if progress_hint.visible:
		progress_hint.visible = false
	if !scroll_container.visible:
		scroll_container.visible = true
		scroll_container.custom_minimum_size.y = clampi(loading_size, 0, 10) * 25


## status: 0 = loading, 1 = loaded, -1 = problem
func update_file(path: String, status: int) -> void:
	if !file_labels.has(path):
		var new_label: Label = Label.new()

		new_label.text = "- " + path.get_file()
		new_label.self_modulate = Color.ORANGE
		new_label.tooltip_text = path
		file_labels[path] = new_label
		vbox.add_child(new_label)

	if status == -1: # problem
		file_labels[path].self_modulate = Color.RED
		file_labels[path].tooltip_text = path + "\nThis file could not be loaded."
	elif status == 1: # Loaded
		file_labels[path].self_modulate = Color.GREEN


## If errors happen, we want the user to be able to see them and not close directly.
func show_close() -> void: close_button.visible = true
