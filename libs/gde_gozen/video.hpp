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

class Video : public Resource {
	GDCLASS(Video, Resource);

private:
	// FFmpeg classes
	AVFormatContext *av_format_ctx = nullptr;
	AVCodecContext *av_codec_ctx_video = nullptr;
	AVStream *av_stream_video = nullptr;

	AVFrame *av_frame = nullptr;
	AVFrame *av_sws_frame = nullptr;
	AVPacket *av_packet = nullptr;

	struct SwsContext *sws_ctx = nullptr;

	// Default variable types
	int response = 0;
	
	int64_t duration = 0;
	int64_t start_time_video = 0;
	int64_t frame_timestamp = 0;
	int64_t current_pts = 0;

	double average_frame_duration = 0;
	double stream_time_base_video = 0;

	bool loaded = false; // Is true after open()
	bool using_sws = false; // This is set for when the pixel format is foreign and not directly supported by the addon

	// Godot classes
	PackedByteArray byte_array;
	PackedByteArray y_data;
	PackedByteArray u_data;
	PackedByteArray v_data;

	// Private functions
	static enum AVPixelFormat _get_format(AVCodecContext *a_av_ctx, const enum AVPixelFormat *a_pix_fmt);
	
	void _copy_frame_data();
	void _clean_frame_data();

	int _seek_frame(int a_frame_nr);

	static inline void _log(String a_message) {
		UtilityFunctions::print("Video: ", a_message, ".");
	}
	static inline bool _log_err(String a_message) {
		UtilityFunctions::printerr("Video: ", a_message, "!");
		return false;
	}

public:
	Video() { av_log_set_level(AV_LOG_VERBOSE); }
	~Video() { close(); }

	bool open(String a_path = "");
	void close();

	inline bool is_open() { return loaded; }

	bool seek_frame(int a_frame_nr);
	bool next_frame(bool a_skip = false);

	inline PackedByteArray get_y_data() { return y_data; }
	inline PackedByteArray get_u_data() { return u_data; }
	inline PackedByteArray get_v_data() { return v_data; }


protected:
	static inline void _bind_methods() {
		ClassDB::bind_method(D_METHOD("open", "a_path"), &Video::open);

		ClassDB::bind_method(D_METHOD("is_open"), &Video::is_open);

		ClassDB::bind_method(D_METHOD("seek_frame", "a_frame_nr"), &Video::seek_frame);
		ClassDB::bind_method(D_METHOD("next_frame", "a_skip"), &Video::next_frame);

		ClassDB::bind_method(D_METHOD("get_y_data"), &Video::get_y_data);
		ClassDB::bind_method(D_METHOD("get_u_data"), &Video::get_u_data);
		ClassDB::bind_method(D_METHOD("get_v_data"), &Video::get_v_data);
	}
};
