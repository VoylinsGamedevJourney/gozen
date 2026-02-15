class_name Print
## Static class for default print statements.

const COLOR_DEFAULT: String = "white"
const COLOR_EDITOR: String = "purple"
const SUFFIX: String = "[color=%s][b]"

# Header prints

static func header(text: String) -> void:
	print_rich(SUFFIX % COLOR_DEFAULT, text)


static func header_editor(text: String) -> void:
	print_rich(SUFFIX % COLOR_EDITOR, text)

# Info prints

static func info(title: String, ...context: Array) -> void:
	print_rich(SUFFIX % COLOR_DEFAULT, title, "[/b]: [color=gray]", " ".join(context))


static func info_editor(title: String, ...context: Array) -> void:
	print_rich(SUFFIX % COLOR_DEFAULT, title, "[/b]: [color=gray]", " ".join(context))
