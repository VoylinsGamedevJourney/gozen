class_name StartupModule extends Node

func close_startup() -> void:
	Globals._on_exit_startup.emit()
	self.queue_free()
