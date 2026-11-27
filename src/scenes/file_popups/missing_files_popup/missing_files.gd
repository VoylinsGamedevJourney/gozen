extends Control
# Non re-linked files should be made tagged as "missing" but not deleted just
# in case, people can relink files manually.


@export var vbox: VBoxContainer

var _active_file_dialog: FileDialog = null



## This is basically our _ready() for the popup.
func set_data(missing_files: Array[FileData]) -> void:
	if vbox.get_child_count() != 0:
		for child: Control in vbox.get_children():
			vbox.remove_child(child)
			child.queue_free()

	for file: FileData in missing_files:
		var hbox: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		var button_relink: Button = Button.new()
		label.text = file.nickname
		label.tooltip_text = file.path
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button_relink.text = tr("Re-link file")

		hbox.add_child(label)
		hbox.add_child(button_relink)

		button_relink.pressed.connect(func() -> void:
			if _active_file_dialog != null:
				return

			var file_dialog: FileDialog = PopupManager.create_file_dialog(
					tr("Relink file ..."), FileDialog.FILE_MODE_OPEN_FILE)
			var base_dir: String = file.path.get_base_dir()
			if DirAccess.dir_exists_absolute(base_dir):
				file_dialog.current_dir = base_dir
			else:
				file_dialog.current_dir = Project.get_picker_path(OS.SYSTEM_DIR_MOVIES)

			_active_file_dialog = file_dialog
			file_dialog.file_selected.connect(func(path: String) -> void:
				_clear_active_file_dialog.call_deferred(file_dialog)
				FileLogic.relink_file(file, path)
				if is_instance_valid(hbox):
					vbox.remove_child(hbox)
					hbox.queue_free()
				if vbox.get_child_count() == 0:
					_on_close_button_pressed())
			file_dialog.canceled.connect(_clear_active_file_dialog.bind(file_dialog), CONNECT_DEFERRED)
			file_dialog.visibility_changed.connect(func() -> void:
				if not file_dialog.visible:
					_clear_active_file_dialog.call_deferred(file_dialog))

			add_child(file_dialog)
			file_dialog.popup_centered())

		vbox.add_child(hbox)


func _clear_active_file_dialog(dialog: FileDialog) -> void:
	if _active_file_dialog == dialog:
		_active_file_dialog = null


func _input(event: InputEvent) -> void:
	if _active_file_dialog != null:
		return
	if event.is_action_pressed("ui_cancel", false, true):
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if _active_file_dialog != null:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	if _active_file_dialog == null:
		PopupManager.close(PopupManager.FILES_MISSING)
