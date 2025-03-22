class_name FileRenameDialog
extends PanelContainer


signal file_renamed(a_id: int)

@export var rename_line_edit: LineEdit

var old_nickname: String
var file_id: int = -1



func prepare(a_file_id: int) -> void:
	file_id = a_file_id
	old_nickname = Project.get_file(file_id).nickname
	rename_line_edit.text = old_nickname


func _on_cancel_button_pressed() -> void:
	self.queue_free()


func _on_save_button_pressed() -> void:
	_on_rename_file_line_edit_text_submitted(rename_line_edit.text)


func _on_rename_file_line_edit_text_submitted(a_new_nickname: String) -> void:
	# Only save if an actual new nickname got given
	if a_new_nickname != "" and old_nickname != a_new_nickname:
		Project.get_file(file_id).nickname = a_new_nickname
		file_renamed.emit(file_id)

	self.queue_free()
	
