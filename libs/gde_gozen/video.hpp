#pragma once

#include <cstdint>
#include <cmath>

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/gd_extension_manager.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/rendering_server.hpp>

#include "ffmpeg.hpp"
#include "gozen_error.hpp"


using namespace godot;

class Video : public Resource {
	GDCLASS(Video, Resource);

private:
	// FFmpeg classes
	AVFormatContext *av_format_ctx = nullptr;
	AVCodecContext *av_codec_ctx_video = nullptr;
	AVBufferRef *hw_device_ctx = nullptr;
	AVStream *av_stream_video = nullptr;

	AVFrame *av_frame = nullptr;
	AVFrame *av_hw_frame = nullptr;
	AVPacket *av_packet = nullptr;

	struct SwsContext *sws_ctx = nullptr;

	enum AVHWDeviceType hw_decoder;
	enum AVColorPrimaries color_profile;
	enum AVPixelFormat hw_pix_fmt = AV_PIX_FMT_NONE;

	// Default variable types
	int response = 0;
	int padding = 0;

	int8_t rotation = 0;
	int8_t interlaced = 0; // 0 = no interlacing, 1 = interlaced top first, 2 interlaced bottom first
	
	int64_t duration = 0;
	int64_t frame_duration = 0;

	int64_t start_time_video = 0;
	int64_t frame_timestamp = 0;
	int64_t current_pts = 0;

	double average_frame_duration = 0;
	double stream_time_base_video = 0;

	float framerate = 0.;

	bool loaded = false; // Is true after open()
	bool hw_decoding = false; // Set by user
	bool debug = false;
	bool using_sws = false; // This is set for when the pixel format is foreign and not directly supported by the addon
	bool full_color_range = true;

	std::string path = "";
	std::string pixel_format = "";
	std::string prefered_hw_decoder = "";

	// Godot classes
	Vector2i resolution = Vector2i(0, 0);

	AudioStreamWAV *audio = nullptr;

	PackedByteArray byte_array;
	PackedByteArray y_data;
	PackedByteArray u_data;
	PackedByteArray v_data;


	// Private functions
	static enum AVPixelFormat _get_format(AVCodecContext *a_av_ctx, const enum AVPixelFormat *a_pix_fmt);
	const AVCodec *_get_hw_codec();
	
	void _copy_frame_data();
	void _clean_frame_data();

	int _seek_frame(int a_frame_nr);

	void _print_debug(std::string a_text);
	void _printerr_debug(std::string a_text);

public:
	Video() {}
	~Video() { close(); }

	static Dictionary get_file_meta(String a_file_path);
	static PackedStringArray get_available_hw_devices();

	int open(String a_path = "", bool a_load_audio = true);
	void close();

	inline bool is_open() { return loaded; }

	int seek_frame(int a_frame_nr);
	bool next_frame(bool a_skip = false);

	inline Ref<AudioStreamWAV> get_audio() { return audio; };

	inline String get_path() { return path.c_str(); }

	inline float get_framerate() { return framerate; }
	inline int get_frame_duration() { return frame_duration; };
	inline Vector2i get_resolution() { return resolution; }
	inline int get_width() { return resolution.x; }
	inline int get_height() { return resolution.y; }
	inline int get_padding() { return padding; }
	inline int get_rotation() { return rotation; }

	inline void set_hw_decoding(bool a_value) {
		if (loaded)
			UtilityFunctions::printerr("Setting hw_decoding after opening file has no effect!");
		hw_decoding = a_value; }
	inline bool get_hw_decoding() { return hw_decoding; }

	inline void set_prefered_hw_decoder(String a_value) {
		if (loaded)
			UtilityFunctions::printerr("Setting prefered_hw_decoder after opening file has no effect!");
		prefered_hw_decoder = a_value.utf8(); }
	inline String get_prefered_hw_decoder() { return prefered_hw_decoder.c_str(); }

	inline void enable_debug() { av_log_set_level(AV_LOG_VERBOSE); debug = true; }
	inline void disable_debug() { av_log_set_level(AV_LOG_INFO); debug = false; }
	inline bool get_debug_enabled() { return debug; }

	inline String get_pixel_format() { return pixel_format.c_str(); }
	inline String get_color_profile() { return av_color_primaries_name(color_profile); }

	inline bool is_full_color_range() { return full_color_range; }

	inline PackedByteArray get_y_data() { return y_data; }
	inline PackedByteArray get_u_data() { return u_data; }
	inline PackedByteArray get_v_data() { return v_data; }


protected:
	static inline void _bind_methods() {
		ClassDB::bind_static_method("Video", D_METHOD("get_file_meta", "a_file_path"), &Video::get_file_meta);
		ClassDB::bind_static_method("Video", D_METHOD("get_available_hw_devices"), &Video::get_available_hw_devices);

		ClassDB::bind_method(D_METHOD("open", "a_path", "a_load_audio"), &Video::open, DEFVAL(""), DEFVAL(true));

		ClassDB::bind_method(D_METHOD("is_open"), &Video::is_open);

		ClassDB::bind_method(D_METHOD("seek_frame", "a_frame_nr"), &Video::seek_frame);
		ClassDB::bind_method(D_METHOD("next_frame", "a_skip"), &Video::next_frame);
		ClassDB::bind_method(D_METHOD("get_audio"), &Video::get_audio);

		ClassDB::bind_method(D_METHOD("set_hw_decoding", "a_value"), &Video::set_hw_decoding);
		ClassDB::bind_method(D_METHOD("get_hw_decoding"), &Video::get_hw_decoding);

		ClassDB::bind_method(D_METHOD("set_prefered_hw_decoder", "a_codec"), &Video::set_prefered_hw_decoder);
		ClassDB::bind_method(D_METHOD("get_prefered_hw_decoder"), &Video::get_prefered_hw_decoder);

		ClassDB::bind_method(D_METHOD("get_framerate"), &Video::get_framerate);

		ClassDB::bind_method(D_METHOD("get_path"), &Video::get_path);

		ClassDB::bind_method(D_METHOD("get_resolution"), &Video::get_resolution);
		ClassDB::bind_method(D_METHOD("get_width"), &Video::get_width);
		ClassDB::bind_method(D_METHOD("get_height"), &Video::get_height);
		ClassDB::bind_method(D_METHOD("get_padding"), &Video::get_padding);
		ClassDB::bind_method(D_METHOD("get_rotation"), &Video::get_rotation);

		ClassDB::bind_method(D_METHOD("get_frame_duration"), &Video::get_frame_duration);

		ClassDB::bind_method(D_METHOD("enable_debug"), &Video::enable_debug);
		ClassDB::bind_method(D_METHOD("disable_debug"), &Video::disable_debug);
		ClassDB::bind_method(D_METHOD("get_debug_enabled"), &Video::get_debug_enabled);

		ClassDB::bind_method(D_METHOD("get_pixel_format"), &Video::get_pixel_format);
		ClassDB::bind_method(D_METHOD("get_color_profile"), &Video::get_color_profile);

		ClassDB::bind_method(D_METHOD("is_full_color_range"), &Video::is_full_color_range);

		ClassDB::bind_method(D_METHOD("get_y_data"), &Video::get_y_data);
		ClassDB::bind_method(D_METHOD("get_u_data"), &Video::get_u_data);
		ClassDB::bind_method(D_METHOD("get_v_data"), &Video::get_v_data);
	}
};
