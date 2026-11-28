class_name Type


## These types should have a number for avoiding issues with different versions.
enum {
	EMPTY = 0,

	IMAGE = 1 << 0,
	AUDIO = 1 << 1,
	VIDEO = 1 << 2,
	TEXT  = 1 << 3,
	COLOR = 1 << 4,
	SCENE = 1 << 5, ## GoZen Scenes.
}


const GROUP_AUDIO:  int = AUDIO | VIDEO
const GROUP_VISUAL: int = IMAGE | COLOR | TEXT | VIDEO | SCENE
const GROUP_EXTRA:  int = TEXT | SCENE
