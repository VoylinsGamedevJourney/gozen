extends Node


## Make the node name the same as the module which you want to load
## We use _process as _ready gives errors of parents not being fully ready
func _process(_delta: float) -> void:
	self.replace_by(ModuleManager.get_module(name), true)
