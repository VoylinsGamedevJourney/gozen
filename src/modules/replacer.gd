extends Control


# We use _process because parent node may still be busy in _ready
func _process(_delta: float) -> void:
	Logger.ln("Replacing node to module type '%s'" % self.name)
	self.replace_by(ModuleManager.get_selected_module(self.name))
