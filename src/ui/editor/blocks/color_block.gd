extends ColorRect
# TODO: When changing the size, keep rect centered on pivot

var file_id: String


func get_data_dic() -> Dictionary:
	return {
		"color": color,
		"size": size,
		"position": position,
		"scale": scale
	}


func load_data_dic(data: Dictionary) -> void:
	color = data.color
	size = data.size
	position = data.position
	scale = data.scale
	
	pivot_offset = size/2 # Lastly set pivot to center
