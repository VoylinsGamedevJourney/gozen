extends Node
## Module loader
##
## Just drag this script on a control node and rename it to 
## the desire module which you want to load in that location.


# We use _process because parent node may still be busy in _ready
func _process(_delta) -> void:
	var mod_path := "res://modules/default_modules/%s/%s.tscn" % [self.name,self.name]
	replace_by(load(mod_path).instantiate())
