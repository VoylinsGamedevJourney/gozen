class_name Command
## The Command Class
##
## Very similar to other classes, this just holds data.
## All other functions are handled by the command bar manager.

## The command which needs to be typed out
var command: String
var info: String

## Edit only makes it so a command can not run from the startup screen.
var edit_only: bool = true
## Edit only makes it so a command can only run from the startup screen.
var startup_only: bool = false

## Command options
##
## If this is empty, the function will just run. If there are
## variables in here, people will be able to select one of them.
var options := []

## The function which runs when entering command
var function
