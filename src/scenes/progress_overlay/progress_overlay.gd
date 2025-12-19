class_name ProgressOverlay
extends Control


@export var title_label: Label
@export var progress_bar: ProgressBar
@export var progress_hint: Label
@export var scroll_container: ScrollContainer
@export var status_hbox: HBoxContainer
@export var vbox: VBoxContainer

var file_labels: Dictionary = {}



func update_title(title: String) -> void:
	title_label.text = title


func update_progress(value: int, text: String) -> void:
	update_progress_bar(value)
	update_progress_hint(text)
	await RenderingServer.frame_post_draw


func update_progress_bar(value: int, wait_frame: bool = false) -> void:
	var tween: Tween = create_tween()

	@warning_ignore("return_value_discarded")
	tween.tween_property(progress_bar, "value", value, 1)

	if wait_frame:
		await RenderingServer.frame_post_draw


func update_progress_hint(text: String) -> void:
	progress_hint.text = text


func increment_progress_bar(value: float) -> void:
	var tween: Tween = create_tween()

	@warning_ignore("return_value_discarded")
	tween.tween_property(progress_bar, "value", progress_bar.value + value, 0.1)


func set_state_file_loading(loading_size: int) -> void:
	if progress_hint.visible:
		progress_hint.visible = false
	if !scroll_container.visible:
		scroll_container.visible = true
		scroll_container.custom_minimum_size.y = clampi(loading_size, 0, 10) * 25


func update_file(file: FileHandler.FileDrop) -> void:
	var path: String = file.path

	if !file_labels.has(path):
		var new_label: Label = Label.new()

		new_label.text = "- " + file.path.get_file()
		new_label.self_modulate = Color.ORANGE
		file_labels[file.path] = new_label
		vbox.add_child(new_label)			

	match file.status:
		FileHandler.STATUS.ALREADY_LOADED: file_labels[path].self_modulate = Color.GRAY
		FileHandler.STATUS.PROBLEM: file_labels[path].self_modulate = Color.RED
		FileHandler.STATUS.LOADED:  file_labels[path].self_modulate = Color.GREEN

