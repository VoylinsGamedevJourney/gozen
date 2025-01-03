#pragma once

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "ffmpeg.hpp"
#include "avio_audio.hpp"


using namespace godot;

class Renderer : public Resource {
	GDCLASS(Renderer, Resource);

private:
	// FFmpeg classes
	AVFormatContext *av_format_ctx = nullptr;
	const AVOutputFormat *av_output_format = nullptr;

	AVCodecContext *av_codec_ctx_video = nullptr;
	AVStream *av_stream_video = nullptr;
	AVPacket *av_packet_video = nullptr;
	AVFrame *av_frame_video = nullptr;

	AVCodecContext *av_codec_ctx_audio = nullptr;
	AVStream *av_stream_audio = nullptr;
	AVPacket *av_packet_audio = nullptr;

	struct SwsContext *sws_ctx = nullptr;

	AVCodecID video_codec_id = AV_CODEC_ID_NONE;
	AVCodecID audio_codec_id = AV_CODEC_ID_NONE;

	// Default variable types
	int sample_rate = 44100;
	int gop_size = 0;
	int crf = 23; // 0 best quality, 51 worst quality, 18 tends to be not noticable
 
	int response = 0;
	int frame_nr = 0;

	float framerate = 30.;

	bool renderer_open = false;
	bool audio_added = false;

	bool audio_enabled = true;
	bool debug = true;

	std::string h264_preset = "medium";
	
	// Godot classes
	String path = "";
	Vector2i resolution = Vector2i(1920, 1080);

	static inline void _log(String a_message) {
		UtilityFunctions::print("Renderer: ", a_message, ".");
	}
	static inline bool _log_err(String a_message) {
		UtilityFunctions::printerr("Renderer: ", a_message, "!");
		return false;
	}


public:
	enum VIDEO_CODEC {
		V_H264 = AV_CODEC_ID_H264,
		V_HEVC = AV_CODEC_ID_HEVC, // H265
		V_VP9 = AV_CODEC_ID_VP9,
		V_MPEG4 = AV_CODEC_ID_MPEG4,
		V_MPEG2 = AV_CODEC_ID_MPEG2VIDEO,
		V_MPEG1 = AV_CODEC_ID_MPEG1VIDEO,
		V_AV1 = AV_CODEC_ID_AV1,
		V_VP8 = AV_CODEC_ID_VP8,
		V_AMV = AV_CODEC_ID_AMV,
		V_GIF = AV_CODEC_ID_GIF,
		V_THEORA = AV_CODEC_ID_THEORA,
		V_WEBP = AV_CODEC_ID_WEBP,
		V_DNXHD = AV_CODEC_ID_DNXHD,
		V_MJPEG = AV_CODEC_ID_MJPEG,
		V_PRORES = AV_CODEC_ID_PRORES,
		V_RAWVIDEO = AV_CODEC_ID_RAWVIDEO,
		V_NONE = AV_CODEC_ID_NONE,
	};
	enum AUDIO_CODEC {
		A_MP3 = AV_CODEC_ID_MP3,
		A_AAC = AV_CODEC_ID_AAC,
		A_OPUS = AV_CODEC_ID_OPUS,
		A_VORBIS = AV_CODEC_ID_VORBIS,
		A_FLAC = AV_CODEC_ID_FLAC,
		A_PCM = AV_CODEC_ID_PCM_S16LE,
		A_WAV = AV_CODEC_ID_WAVPACK,
		A_NONE = AV_CODEC_ID_NONE,
	};
	enum H264_PRESETS { // Only works for H.H264
		H264_PRESET_ULTRAFAST,
		H264_PRESET_SUPERFAST,
		H264_PRESET_VERYFAST,
		H264_PRESET_FASTER,
		H264_PRESET_FAST,
		H264_PRESET_MEDIUM, // default preset
		H264_PRESET_SLOW,   // recommended
		H264_PRESET_SLOWER,
		H264_PRESET_VERYSLOW,
	};


	Renderer() {};
	~Renderer();

	bool open();
	inline bool is_open() { return renderer_open; }

	bool send_frame(Ref<Image> a_image);
	bool send_audio(PackedByteArray a_wav_data);

	void close();

	static PackedStringArray get_available_codecs(int a_codec_id);

	inline void enable_debug() { av_log_set_level(AV_LOG_VERBOSE); debug = true; }
	inline void disable_debug() { av_log_set_level(AV_LOG_INFO); debug = false; }
	inline bool get_debug() { return debug; }

	inline void set_video_codec_id(VIDEO_CODEC a_codec_id) { video_codec_id = (AVCodecID)a_codec_id; }
	inline VIDEO_CODEC get_video_codec_id() { return static_cast<VIDEO_CODEC>(video_codec_id); }

	inline void set_audio_codec_id(AUDIO_CODEC a_codec_id) { audio_codec_id = (AVCodecID)a_codec_id; }
	inline AUDIO_CODEC get_audio_codec_id() { return static_cast<AUDIO_CODEC>(audio_codec_id); }

	inline void set_path(String a_path) { path = a_path; }
	inline String get_path() { return path; }

	inline void set_resolution(Vector2i a_resolution) { resolution = a_resolution; }
	inline Vector2i get_resolution() { return resolution; }

	inline void set_framerate(float a_framerate) { framerate = a_framerate; }
	inline float get_framerate() { return framerate; }

	inline void set_crf(int a_crf) { crf = a_crf; }
	inline int get_crf() { return crf; }

	inline void set_gop_size(int a_gop_size) { gop_size = a_gop_size; }
	inline int get_gop_size() { return gop_size; }

	inline void set_sample_rate(int a_value) { sample_rate = a_value; }
	inline int get_sample_rate() { return sample_rate; }

	inline void enable_audio() { audio_enabled = true; }
	inline void disable_audio() { audio_enabled = false; }

	inline void set_h264_preset(int a_value) {
		switch (a_value) {
			case H264_PRESET_ULTRAFAST:
				h264_preset = "ultrafast";
				break;
			case H264_PRESET_SUPERFAST:
				h264_preset = "superfast";
				break;
			case H264_PRESET_VERYFAST:
				h264_preset = "veryfast";
				break;
			case H264_PRESET_FASTER:
				h264_preset = "faster";
				break;
			case H264_PRESET_FAST:
				h264_preset = "fast";
				break;
			case H264_PRESET_MEDIUM:
				h264_preset = "medium";
				break;
			case H264_PRESET_SLOW:
				h264_preset = "slow";
				break;
			case H264_PRESET_SLOWER:
				h264_preset = "slower";
				break;
			case H264_PRESET_VERYSLOW:
				h264_preset = "veryslow";
				break;
		}
	}
	inline String get_h264_preset() { return h264_preset.c_str(); }

	inline void configure_for_high_quality() { // MP4
		set_video_codec_id(V_HEVC);
		set_audio_codec_id(A_AAC);
		set_crf(18);
		set_h264_preset(H264_PRESET_SLOW);
		set_gop_size(15);
	}

	inline void configure_for_youtube_hq() { // MP4
		set_video_codec_id(V_VP9);
		set_audio_codec_id(A_OPUS);
		set_crf(18);
		set_gop_size(15);
	}

	inline void configure_for_youtube() { // MP4
		set_video_codec_id(V_H264);
		set_audio_codec_id(A_AAC);
		set_crf(23);
		set_h264_preset(H264_PRESET_VERYFAST);
		set_gop_size(15);
	}

	inline void configure_for_av1() { // webm
		set_video_codec_id(V_AV1);
		set_audio_codec_id(A_OPUS);
		set_crf(20);
		set_gop_size(15);
	}

	inline void configure_for_vp9() { // webm
		set_video_codec_id(V_VP9);
		set_audio_codec_id(A_OPUS);
		set_crf(20);
		set_gop_size(15);
	}

	inline void configure_for_vp8() { // webm
		set_video_codec_id(V_VP8);
		set_audio_codec_id(A_OPUS);
		set_crf(20);
		set_gop_size(15);
	}

	inline void configure_for_hq_archiving_flac() { // mkv
		set_video_codec_id(V_HEVC);
		set_audio_codec_id(A_FLAC);
		set_crf(18);
		set_gop_size(15);
	}

	inline void configure_for_hq_archiving_aac() { // mkv
		set_video_codec_id(V_HEVC);
		set_audio_codec_id(A_AAC);
		set_crf(18);
		set_gop_size(10);
	}

	inline void configure_for_older_devices() { // avi
		set_video_codec_id(V_MPEG4);
		set_audio_codec_id(A_MP3);
		set_crf(23);
		set_gop_size(10);
	}

	void _print_debug(std::string a_text);
	void _printerr_debug(std::string a_text);

protected:
	static inline void _bind_methods() {
		/* VIDEO CODEC ENUMS */
		BIND_ENUM_CONSTANT(V_H264);
		BIND_ENUM_CONSTANT(V_HEVC);
		BIND_ENUM_CONSTANT(V_VP9);
		BIND_ENUM_CONSTANT(V_MPEG4);
		BIND_ENUM_CONSTANT(V_MPEG2);
		BIND_ENUM_CONSTANT(V_MPEG1);
		BIND_ENUM_CONSTANT(V_AV1);
		BIND_ENUM_CONSTANT(V_VP8);
		BIND_ENUM_CONSTANT(V_AMV);
		BIND_ENUM_CONSTANT(V_GIF);
		BIND_ENUM_CONSTANT(V_THEORA);
		BIND_ENUM_CONSTANT(V_WEBP);
		BIND_ENUM_CONSTANT(V_DNXHD);
		BIND_ENUM_CONSTANT(V_MJPEG);
		BIND_ENUM_CONSTANT(V_PRORES);
		BIND_ENUM_CONSTANT(V_RAWVIDEO);
		BIND_ENUM_CONSTANT(V_NONE);

		/* AUDIO CODEC ENUMS */
		BIND_ENUM_CONSTANT(A_MP3);
		BIND_ENUM_CONSTANT(A_AAC);
		BIND_ENUM_CONSTANT(A_OPUS);
		BIND_ENUM_CONSTANT(A_VORBIS);
		BIND_ENUM_CONSTANT(A_FLAC);
		BIND_ENUM_CONSTANT(A_PCM);
		BIND_ENUM_CONSTANT(A_WAV);
		BIND_ENUM_CONSTANT(A_NONE);

		/* H264 PRESETS */
		BIND_ENUM_CONSTANT(H264_PRESET_ULTRAFAST);
		BIND_ENUM_CONSTANT(H264_PRESET_SUPERFAST);
		BIND_ENUM_CONSTANT(H264_PRESET_VERYFAST);
		BIND_ENUM_CONSTANT(H264_PRESET_FASTER);
		BIND_ENUM_CONSTANT(H264_PRESET_FAST);
		BIND_ENUM_CONSTANT(H264_PRESET_MEDIUM);
		BIND_ENUM_CONSTANT(H264_PRESET_SLOW);
		BIND_ENUM_CONSTANT(H264_PRESET_SLOWER);
		BIND_ENUM_CONSTANT(H264_PRESET_VERYSLOW);


		ClassDB::bind_static_method("Renderer", D_METHOD("get_available_codecs", "a_codec_id"), Renderer::get_available_codecs);

		ClassDB::bind_method(D_METHOD("open"), &Renderer::open);
		ClassDB::bind_method(D_METHOD("is_open"), &Renderer::is_open);

		ClassDB::bind_method(D_METHOD("send_frame", "a_image"), &Renderer::send_frame);
		ClassDB::bind_method(D_METHOD("send_audio", "a_wav_data"), &Renderer::send_audio);

		ClassDB::bind_method(D_METHOD("close"), &Renderer::close);

		ClassDB::bind_method(D_METHOD("enable_debug"), &Renderer::enable_debug);
		ClassDB::bind_method(D_METHOD("disable_debug"), &Renderer::disable_debug);
		ClassDB::bind_method(D_METHOD("get_debug"), &Renderer::get_debug);

		ClassDB::bind_method(D_METHOD("set_video_codec_id", "a_codec_id"), &Renderer::set_video_codec_id);
		ClassDB::bind_method(D_METHOD("get_video_codec_id"), &Renderer::get_video_codec_id);

		ClassDB::bind_method(D_METHOD("set_audio_codec_id", "a_codec_id"), &Renderer::set_audio_codec_id);
		ClassDB::bind_method(D_METHOD("get_audio_codec_id"), &Renderer::get_audio_codec_id);

		ClassDB::bind_method(D_METHOD("set_path", "a_file_path"), &Renderer::set_path);
		ClassDB::bind_method(D_METHOD("get_path"), &Renderer::get_path);

		ClassDB::bind_method(D_METHOD("set_resolution", "a_resolution"), &Renderer::set_resolution);
		ClassDB::bind_method(D_METHOD("get_resolution"), &Renderer::get_resolution);

		ClassDB::bind_method(D_METHOD("set_framerate", "a_framerate"), &Renderer::set_framerate);
		ClassDB::bind_method(D_METHOD("get_framerate"), &Renderer::get_framerate);

		ClassDB::bind_method(D_METHOD("set_crf", "a_crf"), &Renderer::set_crf);
		ClassDB::bind_method(D_METHOD("get_crf"), &Renderer::get_crf);

		ClassDB::bind_method(D_METHOD("set_gop_size", "a_gop_size"), &Renderer::set_gop_size);
		ClassDB::bind_method(D_METHOD("get_gop_size"), &Renderer::get_gop_size);

		ClassDB::bind_method(D_METHOD("set_sample_rate", "a_value"), &Renderer::set_sample_rate);
		ClassDB::bind_method(D_METHOD("get_sample_rate"), &Renderer::get_sample_rate);

		ClassDB::bind_method(D_METHOD("enable_audio"), &Renderer::enable_audio);
		ClassDB::bind_method(D_METHOD("disable_audio"), &Renderer::disable_audio);

		ClassDB::bind_method(D_METHOD("set_h264_preset", "a_value"), &Renderer::set_h264_preset);
		ClassDB::bind_method(D_METHOD("get_h264_preset"), &Renderer::get_h264_preset);

		ClassDB::bind_method(D_METHOD("configure_for_high_quality"), &Renderer::configure_for_high_quality);

		ClassDB::bind_method(D_METHOD("configure_for_youtube_hq"), &Renderer::configure_for_youtube_hq);
		ClassDB::bind_method(D_METHOD("configure_for_youtube"), &Renderer::configure_for_youtube);

		ClassDB::bind_method(D_METHOD("configure_for_av1"), &Renderer::configure_for_av1);
		ClassDB::bind_method(D_METHOD("configure_for_vp9"), &Renderer::configure_for_vp9);
		ClassDB::bind_method(D_METHOD("configure_for_vp8"), &Renderer::configure_for_vp8);

		ClassDB::bind_method(D_METHOD("configure_for_hq_archiving_flac"), &Renderer::configure_for_hq_archiving_flac);
		ClassDB::bind_method(D_METHOD("configure_for_hq_archiving_aac"), &Renderer::configure_for_hq_archiving_aac);

		ClassDB::bind_method(D_METHOD("configure_for_older_devices"), &Renderer::configure_for_older_devices);
	}
};

VARIANT_ENUM_CAST(Renderer::VIDEO_CODEC);
VARIANT_ENUM_CAST(Renderer::AUDIO_CODEC);
VARIANT_ENUM_CAST(Renderer::H264_PRESETS);
