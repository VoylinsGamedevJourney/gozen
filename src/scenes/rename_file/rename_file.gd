class_name FileRenameDialog
extends PanelContainer

@export var rename_line_edit: LineEdit


var file: FileData = null


func prepare(file_data: FileData) -> void:
	file = file_data
	rename_line_edit.text = file.nickname


func _on_cancel_button_pressed() -> void:
	self.queue_free()


func _on_save_button_pressed() -> void:
	_on_rename_file_line_edit_text_submitted(rename_line_edit.text)


func _on_rename_file_line_edit_text_submitted(new_nickname: String) -> void:
	# Only save if an actual new nickname got given
	if new_nickname != "" and file.nickname != new_nickname:
		FileLogic.set_nickname(file, new_nickname)
	self.queue_free()
