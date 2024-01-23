extends Label


func _ready() -> void:
	text = tr("TEXT_UNTITLED_PROJECT_TITLE")
	ProjectManager._on_title_changed.connect(func(new_title: String): text = new_title + " ")
	ProjectManager._on_project_saved.connect(func(): text[-1] = " ")
	ProjectManager._on_unsaved_changes.connect(func(): text[-1] = "*")
