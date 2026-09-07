class_name Type


## These types should have a number for avoiding issues with different versions.
enum {
	EMPTY = 0,

	IMAGE = 1 << 0,
	AUDIO = 1 << 1,
	VIDEO = 1 << 2,
	TEXT  = 1 << 3,
	COLOR = 1 << 4,
	PCK   = 1 << 5, ## GoZen Modules.
	MODEL = 1 << 6, ## 3D models.
}


const GROUP_AUDIO:  int = AUDIO | VIDEO
const GROUP_VISUAL: int = IMAGE | COLOR | TEXT | VIDEO | PCK | MODEL
const GROUP_EXTRA:  int = TEXT | PCK | MODEL
