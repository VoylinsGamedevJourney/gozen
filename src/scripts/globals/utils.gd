extends Node


## Used for opening websites from the editor.
func open_url(a_url: String) -> void:
	if OS.shell_open(a_url):
		print("Something went wrong opening ", a_url, " url!")


## Generates a unique id, which is used for the file and clip id's.
func get_unique_id(a_keys: PackedInt32Array) -> int:
	var l_id: int = 0

	while true:
		randomize()
		l_id = abs(randi())

		if !a_keys.has(l_id):
			break

	return l_id

