class_name EffectsPanel extends PanelContainer
# We should use the view textures themself for transform effects.
# We can resize the placeholder for sizing. For rotation we need to set the
# pivot as well
#
# Size = Placeholder texture size
# Scaling = Scale property
# Rotation = Rotation (Pivot needs to be set)
# Pivot = Used for size + scaling + rotation (Should be center by default)
#
# WARNING: Set the PIVOT by default in the center!! Maybe have pivot being a %
# instead of the pixel position
#
# Extra want to have effects:
# Trimming edges
# Rounding corners
#
# These effects will need to be implemented on a shader level
 

static var instance: EffectsPanel = self



func _ready() -> void:
	instance = self


func open_file_effects(a_id: int) -> void:
	#print("Opening file effects for ", a_id)
	pass


func open_clip_effects(a_id: int) -> void:
	#print("Opening clip effects for ", a_id)
	pass

