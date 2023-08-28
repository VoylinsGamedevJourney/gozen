class_name Logger extends Node


## Printing a line with the script name
static func ln(message) -> void:
	var source: String = get_stack()[1].source
	print_rich("[b]%s:[/b] %s." % [
			source.split('/')[-1].capitalize().replace(' ', '') ,message])
