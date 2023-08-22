class_name Project
## Project Class
##
## The project class is where all variables get stored for a project.
## This class does not contain any functions as those are all handles
## by ProjectManager. This way the data here is easier to look at.


var title: String = "Untitled project"
var path: String = "" # user://project_folder
var resolution : Vector2i

## Files id
##
## Increases number by one everytime a file gets added. This way we
## can give all files a unique id.
var files_id: int = 0 
var files: Dictionary = {}
