class_name Logger extends Node

## Disable log by adding filenames here
const exceptions := [] 
## Disable logs all together
const enable_log := true


## Printing a line with the script name
static func ln(message) -> void:
	var file_name: String = get_stack()[1].source.split('/')[-1]
	if enable_log or file_name not in exceptions:
		print_rich("[b]%s:[/b] %s." % [file_name ,message])
