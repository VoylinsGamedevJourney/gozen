extends MarginContainer

var landscape := true


func _on_return_button_pressed() -> void:
	get_parent().current_tab = 0


func _on_create_project_button_pressed() -> void:
	if %TitleLineEdit.text == "" or %PathLineEdit.text == "":
		return
	ProjectManager.new_project(
		%TitleLineEdit.text, # title
		%PathLineEdit.text,  # path
		Vector2i(%XSpinBox.value, %YSpinBox.value), # resolution
		%FramerateSpinBox.value) # framerate
	ScreenMain.instance.close_startup()


func _on_select_path_button_pressed():
	var dialog := DialogManager.get_select_path_dialog()
	dialog.file_selected.connect(_on_file_selected)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(500,600))


func _on_file_selected(path: String) -> void:
	if %TitleLineEdit.text == "":
		%TitleLineEdit.text = path.split('/')[-1].to_pascal_case()
	if !path.contains(".gozen"):
		%PathLineEdit.text = path + ".gozen"
	else:
		%PathLineEdit.text = path


func switch_landscape(value: bool) -> void:
	landscape = value
	set_quality(Vector2i(
		%XSpinBox.value if %XSpinBox.value > %YSpinBox.value else %YSpinBox.value,
		%YSpinBox.value if %XSpinBox.value > %YSpinBox.value else %XSpinBox.value))


func set_quality(resolution: Vector2i) -> void:
	%XSpinBox.value = resolution.x if landscape else resolution.y
	%YSpinBox.value = resolution.y if landscape else resolution.x
