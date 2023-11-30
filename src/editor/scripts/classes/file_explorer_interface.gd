class_name FileExplorer extends Node

signal _on_save_project_path_selected(resultw)
signal _on_cancel_pressed

## For SAVE_PROJECT, no filter argument is needed
enum MODE { SAVE_PROJECT }


var title: String
var mode: MODE
var filter: Array


func show() -> void:
	self.visible = true


func close() -> void:
	self.queue_free()


func ok_pressed(path: Array) -> void:
	match mode:
		MODE.SAVE_PROJECT:
			_on_save_project_path_selected.emit(path)


func cancel_pressed() -> void:
	_on_cancel_pressed.emit()
	close()
