extends DataManager


const PATH: String = "user://editor_settings"



func save() -> void:
	if save_data(PATH) == ERR_FILE_CANT_OPEN:
		printerr("Couldn't open settings file for saving! ", PATH)


func load() -> void:
	if load_data(PATH) == ERR_FILE_CANT_OPEN:
		printerr("Couldn't open settings file for loading! ", PATH)

