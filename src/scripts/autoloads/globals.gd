extends Node

## Globals Autoload
##
## This file contains all consts which are not supposed to be
## changed during runtime like the version number and path.


const VERSION := "0.0.1-Alpha"

# Paths
const PATH_PROJECT_LIST := "user://projects_lists.dat"
const PATH_SETTINGS := "user://settings.dat"


# Nodes

var editor_layout: EditorLayoutInterface


# Variables

var current_project: Project
