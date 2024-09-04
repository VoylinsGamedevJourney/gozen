#pragma once

#include <cstdint>
#include <cmath>
#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include "godot_cpp/classes/gd_extension_manager.hpp"
#include <godot_cpp/variant/utility_functions.hpp>

#include "ffmpeg.hpp"


using namespace godot;

class Video : public Resource {
	GDCLASS(Video, Resource);

private:
	AVFormatContext *av_format_ctx = nullptr;
	AVStream *av_stream_video = nullptr, *av_stream_audio = nullptr;
	AVCodecContext *av_codec_ctx_video = nullptr;
	AVBufferRef *hw_device_ctx = nullptr;

	AVFrame *av_frame = nullptr;
	AVPacket *av_packet = nullptr;

	PackedByteArray y = PackedByteArray(), u = PackedByteArray(), v = PackedByteArray();

	int response = 0;
	long start_time_video = 0, frame_timestamp = 0, current_pts = 0;
	double average_frame_duration = 0, stream_time_base_video = 0;

	Vector2i resolution = Vector2i(0, 0);
	bool loaded = false, variable_framerate = false;
	int64_t duration = 0, frame_duration = 0;
	int8_t interlaced = 0; // 0 = no interlacing, 1 = interlaced top first, 2 interlaced bottom first
	float framerate = 0.0;
	double expected_pts = 0.0, actual_pts = 0.0;

	AudioStreamWAV *audio = nullptr;
	String path = "";


public:
	Video() {}
	~Video() { close(); }

	static Dictionary get_file_meta(String a_file_path);
	static Ref<Video> open_new(String a_path = "", bool a_load_audio = true);

	int open(String a_path = "", bool a_load_audio = true);
	void close();

	inline bool is_open() { return loaded; }

	void seek_frame(int a_frame_nr);
	void next_frame(bool a_skip = false);

	inline Ref<AudioStreamWAV> get_audio() { return audio; };
	int _get_audio();

	inline float get_framerate() { return framerate; }

	inline bool is_framerate_variable() { return variable_framerate; }
	inline int get_frame_duration() { return frame_duration; };

	inline String get_path() { return path; }
	
	inline PackedByteArray get_y() { return y; }
	inline PackedByteArray get_u() { return u; }
	inline PackedByteArray get_v() { return v; }

	inline Vector2i get_resolution() { return resolution; }
	inline int get_width() { return resolution.x; }
	inline int get_height() { return resolution.y; }

	void print_av_error(const char *a_message);

	void _get_frame(AVCodecContext *a_codec_ctx, int a_stream_id);

protected:
	static inline void _bind_methods() {
		ClassDB::bind_static_method("Video", D_METHOD("get_file_meta", "a_path"), &Video::get_file_meta);
		ClassDB::bind_static_method("Video", D_METHOD("open_new", "a_path", "a_load_audio"), &Video::open_new);

		ClassDB::bind_method(D_METHOD("open", "a_path", "a_load_audio"),
							 &Video::open, DEFVAL(""), DEFVAL(true));
		ClassDB::bind_method(D_METHOD("close"), &Video::close);

		ClassDB::bind_method(D_METHOD("is_open"), &Video::is_open);

		ClassDB::bind_method(D_METHOD("seek_frame", "a_frame_nr"), &Video::seek_frame);
		ClassDB::bind_method(D_METHOD("next_frame", "a_skip"), &Video::next_frame, DEFVAL(false));
		ClassDB::bind_method(D_METHOD("get_audio"), &Video::get_audio);

		ClassDB::bind_method(D_METHOD("get_framerate"), &Video::get_framerate);

		ClassDB::bind_method(D_METHOD("get_path"), &Video::get_path);

		ClassDB::bind_method(D_METHOD("get_y"), &Video::get_y);
		ClassDB::bind_method(D_METHOD("get_u"), &Video::get_u);
		ClassDB::bind_method(D_METHOD("get_v"), &Video::get_v);

		ClassDB::bind_method(D_METHOD("get_resolution"), &Video::get_resolution);
		ClassDB::bind_method(D_METHOD("get_width"), &Video::get_width);
		ClassDB::bind_method(D_METHOD("get_height"), &Video::get_height);

		ClassDB::bind_method(D_METHOD("is_framerate_variable"), &Video::is_framerate_variable);
		ClassDB::bind_method(D_METHOD("get_frame_duration"), &Video::get_frame_duration);
	}
};
