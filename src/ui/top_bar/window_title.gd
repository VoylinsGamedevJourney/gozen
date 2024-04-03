extends Label


func _ready() -> void:
	text = tr("TEXT_UNTITLED_PROJECT_TITLE")
	ProjectManager._on_title_changed.connect(_on_project_title_changed)
	ProjectManager._on_unsaved_changes_changed.connect(_on_project_unsaved_changes_changed)


func _on_project_title_changed(a_title: String) -> void:
	# Extra space is needed for the '*' mark to indicate unsaved changes
	text = a_title + " "


func _on_project_unsaved_changes_changed(a_value: bool) -> void:
	text[-1] = "*" if a_value else " "
