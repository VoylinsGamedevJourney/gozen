extends Node
## File Manager
##
## Saving projects, settings, and module info is done here.
## Every var gets converted into a string of text and gets
## saved to the file. The load function returns that info


const OPEN_ERROR := "Could not open file '%s' for %s!\n\tError: %s"
const PROCESS_ERROR := "Could not %s data to '%s'!\n\tError: %s"


## Save data
##
## Turns a variable (class or native type) into a string and saves
## it to a file as text. 
func save_data(data, path: String) -> bool:
	Logger.ln("Saving data to '%s'" % path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	var error := FileAccess.get_open_error()
	if error:
		printerr(OPEN_ERROR % [path, "saving", error])
		return false
	file.store_string(var_to_str(data))
	error = file.get_error()
	if error:
		printerr(PROCESS_ERROR % ["save", path, error])
		return false
	return true


## Load data
##
## Returns the variable as a string, this can be made into the 
## correct variable again by using str_to_var().
func load_data(path: String) -> String:
	Logger.ln("Loading data from '%s'" % path)
	if !FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	var error := FileAccess.get_open_error()
	if error:
		printerr(OPEN_ERROR % [path, "loading", error])
		return ""
	var string := file.get_as_text()
	error = file.get_error()
	if error:
		printerr(PROCESS_ERROR % ["load", path, error])
		return ""
	return string
