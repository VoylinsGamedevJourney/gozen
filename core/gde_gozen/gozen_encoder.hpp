#pragma once

#include "ffmpeg.hpp"
#include "ffmpeg_helpers.hpp"

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <string>


using namespace godot;

class GoZenEncoder : public Resource {
	GDCLASS(GoZenEncoder, Resource);

  private:
	// FFmpeg classes
	UniqueAVFormatCtxOutput av_format_ctx;
	UniqueAVCodecCtx av_codec_ctx_video;
	UniqueAVPacket av_packet_video;
	UniqueAVFrame av_frame_video;
	AVStream* av_stream_video = nullptr;

	UniqueAVFrame av_frame_hw_video;
	AVBufferRef* hw_device_ctx = nullptr;

	UniqueAVCodecCtx av_codec_ctx_audio;
	UniqueAVPacket av_packet_audio;
	AVStream* av_stream_audio = nullptr;

	UniqueSwsCtx sws_ctx;

	AVCodecID video_codec_id = AV_CODEC_ID_NONE;
	AVCodecID audio_codec_id = AV_CODEC_ID_NONE;

	// Default variable types
	int sample_rate = 44100;
	int gop_size = 15;
	int crf = 23; // 0 best quality, 51 worst quality, 18 not really noticable.
	int audio_bit_rate = 128000;
	int threads = 0;

	int sws_quality = SWS_QUALITY_BILINEAR;

	// The maximum for B-frames
	// B-frames can improve the compression of a video as it looks to
	// previous and future frames to make up the image.
	int b_frames = 0;

	int response = 0;
	int frame_nr = 0;
	int format_size = 3; // RGB/RGBA

	float framerate = 30.;

	bool encoder_open = false;
	bool audio_added = false;


	bool debug = true;

	std::string h264_preset = "medium";
	int hw_device_type = HW_DEVICE_TYPE_NVENC;

	// Godot classes
	String path = "";
	Vector2i resolution = Vector2i(1920, 1080);

	// Private classes
	bool _add_video_stream();
	bool _add_audio_stream();
	bool _open_output_file();
	bool _write_header();
	bool _finalize_encoding();

	static inline void _log(String message) { UtilityFunctions::print("GoZenEncoder: ", message, "."); }
	static inline bool _log_err(String message) {
		UtilityFunctions::printerr("GoZenEncoder: ", message, "!");
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
		V_AV1 = AV_CODEC_ID_AV1,
		V_VP9 = AV_CODEC_ID_VP9,
		V_VP8 = AV_CODEC_ID_VP8,
		V_NONE = AV_CODEC_ID_NONE,
	};
	enum AUDIO_CODEC {
		A_WAV = AV_CODEC_ID_WAVPACK,
		A_PCM = AV_CODEC_ID_PCM_S16LE,
		A_MP2 = AV_CODEC_ID_MP2,
		A_MP3 = AV_CODEC_ID_MP3,
		A_AAC = AV_CODEC_ID_AAC,
		A_OPUS = AV_CODEC_ID_OPUS,
		A_VORBIS = AV_CODEC_ID_VORBIS,
		A_FLAC = AV_CODEC_ID_FLAC,
		A_NONE = AV_CODEC_ID_NONE,
	};
	enum H264_PRESETS { // Only works for H.H264
		H264_PRESET_VERYSLOW,
		H264_PRESET_SLOWER,
		H264_PRESET_SLOW,	// recommended
		H264_PRESET_MEDIUM, // default preset
		H264_PRESET_FAST,
		H264_PRESET_FASTER,
		H264_PRESET_VERYFAST,
		H264_PRESET_SUPERFAST,
		H264_PRESET_ULTRAFAST,
	};
	enum SWS_QUALITY {
		SWS_QUALITY_FAST_BILINEAR = SWS_FAST_BILINEAR, // (Fast, lower quality)
		SWS_QUALITY_BILINEAR = SWS_BILINEAR,		   // (Good balance between speed and quality)
		SWS_QUALITY_BICUBIC = SWS_BICUBIC,			   // (Better quality, but slower)
	};
	enum HW_DEVICE_TYPES {
		HW_DEVICE_TYPE_NONE = -1,
		HW_DEVICE_TYPE_NVENC, // NVidia
		HW_DEVICE_TYPE_VAAPI, // AMD/Intel on Linux
		HW_DEVICE_TYPE_QSV,	  // Intel
	};

	GoZenEncoder() {};
	~GoZenEncoder();

	bool open(bool rgba);
	inline bool is_open() { return encoder_open; }

	bool send_frame(Ref<Image> frame_image);
	bool send_audio(PackedByteArray wav_data);

	void close();

	static PackedStringArray get_available_codecs(int codec_id);

	inline void enable_debug() {
		av_log_set_level(AV_LOG_DEBUG);
		debug = true;
	}
	inline void enable_trace() {
		av_log_set_level(AV_LOG_TRACE);
		debug = true;
	}
	inline void disable_debug() {
		av_log_set_level(AV_LOG_INFO);
		debug = false;
	}

	inline void set_video_codec_id(VIDEO_CODEC codec_id) { video_codec_id = (AVCodecID)codec_id; }
	inline void set_audio_codec_id(AUDIO_CODEC codec_id) { audio_codec_id = (AVCodecID)codec_id; }
	inline bool audio_codec_set() const { return AV_CODEC_ID_NONE != audio_codec_id; }

	inline void set_file_path(String file_path) { path = file_path; }

	inline void set_resolution(Vector2i video_resolution) { resolution = video_resolution; }
	inline void set_framerate(float video_framerate) { framerate = video_framerate; }
	inline void set_crf(int video_crf) { crf = video_crf; }
	inline void set_audio_bit_rate(int bit_rate) { audio_bit_rate = bit_rate; }
	inline void set_threads(int thread_count) { threads = thread_count; }
	inline void set_gop_size(int video_gop_size) { gop_size = video_gop_size; }
	inline void set_sws_quality(SWS_QUALITY value) { sws_quality = value; }
	inline void set_b_frames(int value) { b_frames = value; }

	inline void set_h264_preset(int value) {
		switch (value) {
		case H264_PRESET_VERYSLOW:
			h264_preset = "veryslow";
			break;
		case H264_PRESET_SLOWER:
			h264_preset = "slower";
			break;
		case H264_PRESET_SLOW:
			h264_preset = "slow";
			break;
		case H264_PRESET_MEDIUM:
			h264_preset = "medium";
			break;
		case H264_PRESET_FAST:
			h264_preset = "fast";
			break;
		case H264_PRESET_FASTER:
			h264_preset = "faster";
			break;
		case H264_PRESET_VERYFAST:
			h264_preset = "veryfast";
			break;
		case H264_PRESET_SUPERFAST:
			h264_preset = "superfast";
			break;
		case H264_PRESET_ULTRAFAST:
			h264_preset = "ultrafast";
			break;
		}
	}

	inline void set_sample_rate(int value) { sample_rate = value; }

  protected:
	static void _bind_methods();
};

VARIANT_ENUM_CAST(GoZenEncoder::VIDEO_CODEC);
VARIANT_ENUM_CAST(GoZenEncoder::AUDIO_CODEC);
VARIANT_ENUM_CAST(GoZenEncoder::H264_PRESETS);
VARIANT_ENUM_CAST(GoZenEncoder::SWS_QUALITY);
VARIANT_ENUM_CAST(GoZenEncoder::HW_DEVICE_TYPES);
