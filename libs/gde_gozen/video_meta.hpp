#pragma once

#include <cstdint>
#include <cmath>
#include <algorithm>

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/gd_extension_manager.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/rendering_server.hpp>

#include "ffmpeg.hpp"


using namespace godot;

class VideoMeta : public Resource {
	GDCLASS(VideoMeta, Resource);

private:
	// FFmpeg classes
	AVFormatContext *av_format_ctx = nullptr;
	AVCodecContext *av_codec_ctx_video = nullptr;
	AVStream *av_stream_video = nullptr;

	AVFrame *av_frame = nullptr;
	AVFrame *av_sws_frame = nullptr;
	AVPacket *av_packet = nullptr;

	struct SwsContext *sws_ctx = nullptr;
	enum AVColorPrimaries color_profile;

	// Default variable types
	int response = 0;
	int padding = 0;

	int8_t rotation = 0;
	int8_t interlaced = 0; // 0 = no interlacing, 1 = interlaced top first, 2 interlaced bottom first
	
	int64_t duration = 0;
	int64_t frame_count = 0;

	int64_t start_time_video = 0;
	int64_t frame_timestamp = 0;
	int64_t current_pts = 0;

	double average_frame_duration = 0;
	double stream_time_base_video = 0;

	float framerate = 0.;

	bool using_sws = false; // This is set for when the pixel format is foreign and not directly supported by the addon
	bool full_color_range = true;

	std::string path = "";
	std::string pixel_format = "";
	std::string prefered_hw_decoder = "";

	// Godot classes
	Vector2i resolution = Vector2i(0, 0);

	PackedByteArray byte_array;
	PackedByteArray y_data;
	PackedByteArray u_data;
	PackedByteArray v_data;


	// Private functions
	int _seek_frame(int a_frame_nr);

	static inline void _log(String a_message) {
		UtilityFunctions::print("Video: ", a_message, ".");
	}
	static inline bool _log_err(String a_message) {
		UtilityFunctions::printerr("Video: ", a_message, "!");
		return false;
	}

public:
	VideoMeta() { av_log_set_level(AV_LOG_VERBOSE); }
	~VideoMeta() { close(); }

	bool load_meta(String a_path = "");
	void close();

	bool next_frame(bool a_skip = false);

	inline String get_path() { return path.c_str(); }

	inline float get_framerate() { return framerate; }
	inline int get_frame_count() { return std::round(frame_count); };
	inline Vector2i get_resolution() { return resolution; }
	inline int get_width() { return resolution.x; }
	inline int get_height() { return resolution.y; }
	inline int get_padding() { return padding; }
	inline int get_rotation() { return rotation; }

	inline String get_pixel_format() { return pixel_format.c_str(); }
	inline String get_color_profile() { return av_color_primaries_name(color_profile); }

	inline bool is_full_color_range() { return full_color_range; }

protected:
	static inline void _bind_methods() {
		ClassDB::bind_method(D_METHOD("load_meta", "a_path"), &VideoMeta::load_meta);

		ClassDB::bind_method(D_METHOD("get_framerate"), &VideoMeta::get_framerate);
		ClassDB::bind_method(D_METHOD("get_path"), &VideoMeta::get_path);
		ClassDB::bind_method(D_METHOD("get_resolution"), &VideoMeta::get_resolution);
		ClassDB::bind_method(D_METHOD("get_width"), &VideoMeta::get_width);
		ClassDB::bind_method(D_METHOD("get_height"), &VideoMeta::get_height);
		ClassDB::bind_method(D_METHOD("get_padding"), &VideoMeta::get_padding);
		ClassDB::bind_method(D_METHOD("get_rotation"), &VideoMeta::get_rotation);
		ClassDB::bind_method(D_METHOD("get_frame_count"), &VideoMeta::get_frame_count);
		ClassDB::bind_method(D_METHOD("get_pixel_format"), &VideoMeta::get_pixel_format);
		ClassDB::bind_method(D_METHOD("get_color_profile"), &VideoMeta::get_color_profile);

		ClassDB::bind_method(D_METHOD("is_full_color_range"), &VideoMeta::is_full_color_range);
	}
};

