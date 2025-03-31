#pragma once

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "ffmpeg.hpp"


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
	int gop_size = 15;
	int crf = 23; // 0 best quality, 51 worst quality, 18 not really noticable.
	
	int sws_quality = SWS_QUALITY_BILINEAR;

	// The maximum for B-frames
	// B-frames can improve the compression of a video as it looks to
	// previous and future frames to make up the image
	int b_frames = 0;
 
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

	static inline void _log(String message) {
		UtilityFunctions::print("Renderer: ", message, ".");
	}
	static inline bool _log_err(String message) {
		UtilityFunctions::printerr("Renderer: ", message, "!");
		return false;
	}


public:
	enum VIDEO_CODEC {
		V_HEVC = AV_CODEC_ID_HEVC, // H265
		V_H264 = AV_CODEC_ID_H264,
		V_MPEG4 = AV_CODEC_ID_MPEG4,
		V_MPEG2 = AV_CODEC_ID_MPEG2VIDEO,
		V_MPEG1 = AV_CODEC_ID_MPEG1VIDEO,
		V_MJPEG = AV_CODEC_ID_MJPEG,
		V_WEBP = AV_CODEC_ID_WEBP,
		V_AV1 = AV_CODEC_ID_AV1,
		V_VP9 = AV_CODEC_ID_VP9,
		V_VP8 = AV_CODEC_ID_VP8,
		V_AMV = AV_CODEC_ID_AMV,
		V_GIF = AV_CODEC_ID_GIF,
		V_THEORA = AV_CODEC_ID_THEORA,
		V_DNXHD = AV_CODEC_ID_DNXHD,
		V_PRORES = AV_CODEC_ID_PRORES,
		V_RAWVIDEO = AV_CODEC_ID_RAWVIDEO,
		V_NONE = AV_CODEC_ID_NONE,
	};
	enum AUDIO_CODEC {
		A_WAV = AV_CODEC_ID_WAVPACK,
		A_PCM = AV_CODEC_ID_PCM_S16LE,
		A_MP3 = AV_CODEC_ID_MP3,
		A_AAC = AV_CODEC_ID_AAC,
		A_OPUS = AV_CODEC_ID_OPUS,
		A_VORBIS = AV_CODEC_ID_VORBIS,
		A_FLAC = AV_CODEC_ID_FLAC,
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
	enum SWS_QUALITY {
		SWS_QUALITY_FAST_BILINEAR = SWS_FAST_BILINEAR, // (Fast, lower quality)
		SWS_QUALITY_BILINEAR = SWS_BILINEAR, // (Good balance between speed and quality)
		SWS_QUALITY_BICUBIC = SWS_BICUBIC, // (Better quality, but slower)
	};

	Renderer() {};
	~Renderer();

	bool open();
	inline bool is_open() { return renderer_open; }

	bool send_frame(Ref<Image> frame_image);
	bool send_audio(PackedByteArray wav_data);

	void close();

	static PackedStringArray get_available_codecs(int codec_id);

	inline void enable_debug() { av_log_set_level(AV_LOG_VERBOSE); debug = true; }
	inline void disable_debug() { av_log_set_level(AV_LOG_INFO); debug = false; }
	inline bool get_debug() { return debug; }

	inline void set_video_codec_id(VIDEO_CODEC codec_id) { video_codec_id = (AVCodecID)codec_id; }
	inline VIDEO_CODEC get_video_codec_id() { return static_cast<VIDEO_CODEC>(video_codec_id); }

	inline void set_audio_codec_id(AUDIO_CODEC codec_id) { audio_codec_id = (AVCodecID)codec_id; }
	inline AUDIO_CODEC get_audio_codec_id() { return static_cast<AUDIO_CODEC>(audio_codec_id); }

	inline void set_path(String file_path) { path = file_path; }
	inline String get_path() { return path; }

	inline void set_resolution(Vector2i video_resolution) { resolution = video_resolution; }
	inline Vector2i get_resolution() { return resolution; }

	inline void set_framerate(float video_framerate) { framerate = video_framerate; }
	inline float get_framerate() { return framerate; }

	inline void set_crf(int video_crf) { crf = video_crf; }
	inline int get_crf() { return crf; }

	inline void set_gop_size(int video_gop_size) { gop_size = video_gop_size; }
	inline int get_gop_size() { return gop_size; }

	inline void set_sample_rate(int value) { sample_rate = value; }
	inline int get_sample_rate() { return sample_rate; }

	inline void set_sws_quality(SWS_QUALITY value) { sws_quality = value; }
	inline int get_sws_quality() { return sws_quality; }

	inline void set_b_frames(int value) { b_frames = value; }
	inline int get_b_frames() { return b_frames; }

	inline void enable_audio() { audio_enabled = true; }
	inline void disable_audio() { audio_enabled = false; }

	inline void set_h264_preset(int value) {
		switch (value) {
			case H264_PRESET_ULTRAFAST: h264_preset = "ultrafast"; break;
			case H264_PRESET_SUPERFAST: h264_preset = "superfast"; break;
			case H264_PRESET_VERYFAST:	h264_preset = "veryfast"; break;
			case H264_PRESET_FASTER:	h264_preset = "faster"; break;
			case H264_PRESET_FAST:		h264_preset = "fast"; break;
			case H264_PRESET_MEDIUM:	h264_preset = "medium"; break;
			case H264_PRESET_SLOW:		h264_preset = "slow"; break;
			case H264_PRESET_SLOWER:	h264_preset = "slower";	break;
			case H264_PRESET_VERYSLOW:	h264_preset = "veryslow"; break;
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

protected:
	static void _bind_methods();
};

VARIANT_ENUM_CAST(Renderer::VIDEO_CODEC);
VARIANT_ENUM_CAST(Renderer::AUDIO_CODEC);
VARIANT_ENUM_CAST(Renderer::H264_PRESETS);
VARIANT_ENUM_CAST(Renderer::SWS_QUALITY);

