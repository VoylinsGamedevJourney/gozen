@tool
extends EditorScript

enum BLOCKS {
	TOOL, EXTENDS, CLASS_NAME, DOC_COMMENT,
	SIGNAL, ENUM, CONST, STATIC_VAR, EXPORT, ONREADY, VAR,
	FUNC, CLASS_DEF,
	OTHER }


# --- CONFIGURATION ---

const TOP_GROUP: Array[BLOCKS] = [
	BLOCKS.TOOL,
	BLOCKS.CLASS_NAME,
	BLOCKS.EXTENDS,
	BLOCKS.DOC_COMMENT,
]

const ORDER: Array[BLOCKS] = [
	BLOCKS.TOOL,
	BLOCKS.CLASS_NAME,
	BLOCKS.EXTENDS,
	BLOCKS.DOC_COMMENT,

	BLOCKS.SIGNAL,
	BLOCKS.ENUM,
	BLOCKS.CONST,
	BLOCKS.STATIC_VAR,
	BLOCKS.EXPORT,
	BLOCKS.ONREADY,
	BLOCKS.VAR,

	BLOCKS.FUNC,
	BLOCKS.CLASS_DEF,
	BLOCKS.OTHER,
]

const SPACING_DEFAULT: int = 2 ## Spacing between variables, signals, etc...
const SPACING_TOP: int = 1 ## Spacing between top blocks (tool, extends, class_name, doc_comments).
const SPACING_AFTER_TOP: int = 1 ## Spacing between top blocks (tool, extends, class_name, doc_comments).
const SPACING_FUNC: int = 2 ## Spacing between functions.
const SPACING_CLASS_DEF: int = 3 ## Spacing before inner classes.

const MAX_INTERNAL_NEWLINES: int = 1 ## Max consecutive newlines allowed inside a function/block.

const USE_TABS: bool = true
const SPACES_PER_TAB: int = 4


# --- SCRIPT LOGIC ---

func _run() -> void:
	var dir: DirAccess = DirAccess.open("res://")
	process_folder(dir, "res://")
	EditorInterface.get_resource_filesystem().scan()


func process_folder(dir: DirAccess, current_path: String) -> void:
	dir.list_dir_begin()

	var file_name: String = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if !file_name.begins_with(".") and file_name != "addons":
				var sub_dir: DirAccess = DirAccess.open(current_path + file_name)
				process_folder(sub_dir, current_path + file_name + "/")
		elif file_name.get_extension() == "gd" and file_name != "format.gd":
			format_file(current_path + file_name)
		file_name = dir.get_next()


func format_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var text: String = file.get_as_text()

	var regex_cls: RegEx = RegEx.new() # Split class_name and extends if on same line.
	regex_cls.compile("(?<pre>class_name\\s+\\w+)\\s+(?<post>extends\\s+\\S+)")
	text = regex_cls.sub(text, "$pre\n$post", true)

	var blocks: Array[Block] = parse_blocks(text)
	var new_text: String = assemble_text(blocks)

	# 5. Save only if changed
	if text != new_text:
		print("Formatting: ", path)
		var write_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		write_file.store_string(new_text)
		write_file.close()


func parse_blocks(text: String) -> Array[Block]:
	var raw_lines: PackedStringArray = text.split("\n")
	var blocks: Array[Block] = []
	var current_block: Block = null
	var comment_buffer: Array[String] = []
	var in_string: bool = false

	for i: int in raw_lines.size():
		var line: String = raw_lines[i]
		if line.count("\"\"\"") % 2 == 1: # Multi-line strings.
			in_string = !in_string

		var indent_count: int = 0
		if USE_TABS:
			if line.contains("    "): # Accidental spaces instead of tabs?
				line = line.replace("    ", "\t")
			indent_count = line.count("\t", 0, line.length() - len(line.lstrip("\t")))
		else:
			if line.contains("    "): # Accidental tabs instead of spaces?
				line = line.replace("\t", "    ")
			var spaces: float = line.length() - len(line.lstrip(" "))
			indent_count = int(spaces / SPACES_PER_TAB)

		var stripped_line: String = line.strip_edges()
		if stripped_line.is_empty():
			if not comment_buffer.is_empty():
				comment_buffer.append(line)
			elif current_block != null:
				current_block.lines.append(line)
			continue

		if stripped_line.begins_with("##"):
			comment_buffer.append(line)
			continue
		if stripped_line.begins_with("#"):
			if indent_count == 0 or current_block != null:
				current_block.lines.append(line)
			else:
				comment_buffer.append(line)
			continue

		var brace_depth: int = 0
		brace_depth += line.count("{")
		brace_depth -= line.count("}")
		brace_depth += line.count("[")
		brace_depth -= line.count("]")
		brace_depth += line.count("(")
		brace_depth -= line.count(")")

		var is_closing: bool = stripped_line == "}" or stripped_line == "]" or stripped_line == ")"
		if indent_count == 0 and not in_string  and not is_closing and brace_depth == 0:
			if current_block:
				blocks.append(current_block)

			current_block = Block.new()
			current_block.lines.append_array(comment_buffer)
			current_block.code_start_index = comment_buffer.size()
			comment_buffer.clear()
			current_block.lines.append(line)
			current_block.type = identify_type(stripped_line)
		else:
			if current_block:
				current_block.lines.append(line)
			else:
				current_block = Block.new()
				current_block.lines.append(line)
				current_block.type = BLOCKS.OTHER
	if current_block:
		blocks.append(current_block)

	# Sort all blocks.
	var sorted: Array[Block] = []
	var buckets: Dictionary = {}

	for key: int in ORDER:
		buckets[key] = []

	for block: Block in blocks:
		if block.lines.size() > 0 and block.code_start_index >= block.lines.size():
			buckets[BLOCKS.DOC_COMMENT].append(block)
		elif buckets.has(block.type):
			buckets[block.type].append(block)
		else:
			buckets[BLOCKS.OTHER].append(block)

	for key: BLOCKS in ORDER:
		sorted.append_array(buckets[key])
	return sorted


func identify_type(line: String) -> BLOCKS:
	var beginning: String = line.split(' ')[0]
	match beginning:
		"extends": return BLOCKS.EXTENDS
		"class_name": return BLOCKS.CLASS_NAME
		"signal": return BLOCKS.SIGNAL
		"enum": return BLOCKS.ENUM
		"const": return BLOCKS.CONST
		"var": return BLOCKS.VAR
		"func": return BLOCKS.FUNC
		"@export": return BLOCKS.EXPORT
		"export": return BLOCKS.EXPORT
		"@onready": return BLOCKS.ONREADY
		"onready": return BLOCKS.ONREADY
		"static":
			match line.split(' ')[1]:
				"func": return BLOCKS.FUNC
				"var": return BLOCKS.STATIC_VAR

	# Some special cases.
	if line.begins_with("@export"):
		return BLOCKS.EXPORT
	if line.begins_with("@"):
		return BLOCKS.TOOL
	return BLOCKS.OTHER


func assemble_text(blocks: Array[Block]) -> String:
	var result: String = ""
	for i: int in blocks.size():
		var block: Block = blocks[i]
		process_internal_formatting(block) # Formatting inside the blocks.

		var block_text: String = "\n".join(block.lines)
		result += block_text

		if i < blocks.size() - 1:
			var next_block: Block = blocks[i+1]
			var needed_newlines: int = SPACING_DEFAULT

			if block.type in TOP_GROUP:
				if next_block.type in TOP_GROUP:
					needed_newlines = SPACING_TOP
				else:
					needed_newlines = SPACING_AFTER_TOP
			elif next_block.type in [BLOCKS.CLASS_DEF, BLOCKS.OTHER]:
				needed_newlines = SPACING_CLASS_DEF
			elif block.type == BLOCKS.FUNC or next_block.type == BLOCKS.FUNC:
				var is_block_oneliner: bool = block.lines.size() - block.code_start_index == 1
				var is_next_block_oneliner: bool = block.lines.size() - block.code_start_index == 1
				if is_block_oneliner and is_next_block_oneliner:
					needed_newlines = 1
				else:
					needed_newlines = SPACING_FUNC
			elif block.type == BLOCKS.FUNC or next_block.type == BLOCKS.FUNC:
				needed_newlines = SPACING_FUNC
			elif block.type == next_block.type:
				needed_newlines = 1
			result += "\n".repeat(needed_newlines)
	return result.strip_edges() + "\n"


func process_internal_formatting(block: Block) -> void:
	var new_lines: Array[String] = []
	var regex_one_liner: RegEx = RegEx.new()
	regex_one_liner.compile("^(\\s*)(if|elif|else|for|while)\\b.*:[ \\t]*(?!$|#)(.+)")

	var consecutive_enters: int = 0
	for line: String in block.lines:
		var stripped_line: String = line.strip_edges()

		if stripped_line == "":
			consecutive_enters += 1
			if consecutive_enters <= MAX_INTERNAL_NEWLINES:
				new_lines.append("")
			continue
		else:
			consecutive_enters = 0

		var search: RegExMatch = regex_one_liner.search(line)
		if search:
			var content_after_colon: String = search.get_string(3)
			if content_after_colon.strip_edges().begins_with("#"):
				new_lines.append(line)
				continue

			var clean_content: String = content_after_colon.split("#")[0].strip_edges()
			if clean_content.ends_with(":"):
				new_lines.append(line)
				continue

			var indent: String = search.get_string(1)
			var main_line: String = line.substr(0, line.rfind(content_after_colon)).strip_edges(false, true) # Right strip only

			new_lines.append(main_line)
			var extra_indent: String = "\t" if USE_TABS else " ".repeat(SPACES_PER_TAB)
			new_lines.append(indent + extra_indent + content_after_colon.strip_edges())
		else:
			new_lines.append(line)
	block.lines = new_lines



class Block:
	var type: BLOCKS = BLOCKS.OTHER
	var lines: Array[String] = [] # Includes comments
	var code_start_index: int = 0 # Index in 'lines' where actual code starts (after comments)
