class_name File
## The File Class
##
## This class is what all project file types need to use.
##
## TODO: Check on opening project if file still exists (_init?)
##       This would only be for image, video and audio.

enum TYPE { COLOR, IMAGE, TEXT, VIDEO, AUDIO }


var type: TYPE
var duration: int # Duration in frames
