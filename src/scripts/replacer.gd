extends Control


# We use _process because parent node may still be busy in _ready
func _process(_delta: float) -> void:
	self.replace_by(ModuleManager.get_selected_module(self.name))
