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


func update_files(files: Dictionary) -> void:
	# This is only used for when files have been added to a project in bulk or
	# when a file needs loading time.
	# Structure of files should be - file_path: status
	# - 1: Loaded
	# - 0: Loading
	# - -1: Problem
	# - -2: Already loaded
	# - -3: Too big (2GB AudioStreamWav limit)
	if progress_hint.visible:
		progress_hint.visible = false
	if !scroll_container.visible:
		scroll_container.visible = true
		scroll_container.custom_minimum_size.y = clampi(files.size(), 0, 10) * 25

	for file: String in files.keys():
		if !file_labels.has(file):
			var new_label: Label = Label.new()
			new_label.text = "- " + file.get_file()
			new_label.self_modulate = Color.ORANGE
			file_labels[file] = new_label
			vbox.add_child(new_label)			

		match files[file]:
			1:  file_labels[file].self_modulate = Color.GREEN
			-1: file_labels[file].self_modulate = Color.RED
			-2: file_labels[file].self_modulate = Color.GRAY
			-3: file_labels[file].self_modulate = Color.RED
