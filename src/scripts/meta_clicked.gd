extends RichTextLabel
## Meta clicked
##
## A drag and drop script for RichTextLabels which contain links.


func _ready() -> void:
	## connecting the meta_clicked signal on startup.
	Printer.connect_error(meta_clicked.connect(_on_meta_clicked))


func _on_meta_clicked(a_meta: Variant) -> void:
	## Opening the link in the browser of choice.
	if OS.shell_open(a_meta):
		Printer.error(Globals.ERROR_OPEN_LINK % a_meta)
