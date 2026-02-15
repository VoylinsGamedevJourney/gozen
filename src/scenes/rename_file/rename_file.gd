class_name FileRenameDialog
extends PanelContainer

@export var rename_line_edit: LineEdit


var old_nickname: String
var file: int = -1


func prepare(file_id: int) -> void:
	var file_index: int = Project.files.index_map[file_id]
	file = file_id
	old_nickname = Project.data.files_nickname[file_index]
	rename_line_edit.text = old_nickname


func _on_cancel_button_pressed() -> void: self.queue_free()
func _on_save_button_pressed() -> void:
	_on_rename_file_line_edit_text_submitted(rename_line_edit.text)


func _on_rename_file_line_edit_text_submitted(new_nickname: String) -> void:
	# Only save if an actual new nickname got given
	if new_nickname != "" and old_nickname != new_nickname:
		Project.files.set_nickname(file, new_nickname)
	self.queue_free()
