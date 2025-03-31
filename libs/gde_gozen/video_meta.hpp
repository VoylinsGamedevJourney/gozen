#pragma once

#include <cstdint>
#include <cmath>
#include <string>

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include "ffmpeg.hpp"
#include "ffmpeg_helpers.hpp"


using namespace godot;

class VideoMeta : public Resource {
	GDCLASS(VideoMeta, Resource);

private:
	// Metadata variables
	String path = "";

	Vector2i resolution = Vector2i(0,0);
	float framerate = 0.0;
	int64_t duration_us = 0; // Duration in microseconds.
	int64_t frame_count = 0; // Amount of video frames.
	
	int rotation = 0; // Rotation in degrees (0, 90, 180, 270).
	int padding = 0;
	
	String pixel_format_name = "";
	String color_primaries_name = "";
	String color_trc_name = "";
	String color_space_name = "";

	bool is_full_color_range = false; // Limited (tv) or full (pc) range.
	bool is_interlaced = false;

	// TODO: Maybe add bitrate, codec name, aspect ratio, ...	

	bool meta_loaded = false;

	// Debug helpers
	static inline void _log(String message) {
		UtilityFunctions::print("VideoMeta: ", message, ".");
	}
	static inline bool _log_err(String message) {
		UtilityFunctions::printerr("VideoMeta: ", message, "!");
		return false;
	}

public:
	VideoMeta() = default;
	~VideoMeta() = default;

	bool load_meta(const String &video_path);
	inline bool is_loaded() const { return meta_loaded; }

	// Metadata getters
	inline String get_path() const { return path; }

	inline Vector2i get_resolution() const { return resolution; }
	inline int get_width() const { return resolution.x; }
	inline int get_height() const { return resolution.y; }

	inline float get_framerate() const { return framerate; }
	inline int get_frame_count() const { return static_cast<int>(frame_count); }
	inline int64_t get_duration_microseconds() const { return duration_us; }
	inline double get_duration_seconds() const { return static_cast<double>(duration_us) / 1000000.0; }
	inline int get_rotation() const { return rotation; }
	inline int get_padding() const { return padding; }

	inline String get_pixel_format_name() const { return pixel_format_name; }
	inline String get_color_primaries_name() const { return color_primaries_name; }
	inline String get_color_trc_name() const { return color_trc_name; }
	inline String get_color_space_name() const { return color_space_name; }

	inline bool get_is_full_color_range() const { return is_full_color_range; }
	inline bool get_is_interlaced() const { return is_interlaced; }


protected:
	static void _bind_methods();
};

