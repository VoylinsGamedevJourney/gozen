#pragma once

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "ffmpeg.hpp"

using namespace godot;

class Renderer : public Resource {
	GDCLASS(Renderer, Resource);

private:
	static const int byte_per_pixel = 4;
	static constexpr AVChannelLayout chlayout_stereo = AV_CHANNEL_LAYOUT_STEREO;
	AVFormatContext *av_format_ctx = nullptr;
	const AVOutputFormat *av_out_format = nullptr;
	struct SwsContext *sws_ctx = nullptr;
	struct SwrContext *swr_ctx = nullptr;
	AVCodecContext *av_codec_ctx_video = nullptr, *av_codec_ctx_audio = nullptr;
	const AVCodec *av_codec_video = nullptr, *av_codec_audio = nullptr;
	FILE *output_file = nullptr;
	AVStream *av_stream_video, *av_stream_audio;
	AVPacket *av_packet_video = nullptr, *av_packet_audio = nullptr;
	AVFrame *av_frame_video = nullptr, *av_frame_audio = nullptr;
	char error_str[AV_ERROR_MAX_STRING_SIZE];
	int i = 0, x = 0, y = 0, response = 0;

	/* Render requirements */
	String file_path = "";
	AVCodecID av_codec_id_video, av_codec_id_audio;
	Vector2i resolution = Vector2i(1920, 1080);
	float framerate = 30;
	int bit_rate = 400000, gop_size = 0;
	String h264_preset = "medium";
	bool render_audio = false;

public:
	enum RENDERER_AUDIO_CODEC {
		A_MP3 = AV_CODEC_ID_MP3,
		A_AAC = AV_CODEC_ID_AAC,
		A_OPUS = AV_CODEC_ID_OPUS,
		A_VORBIS = AV_CODEC_ID_VORBIS,
		A_PCM_UNCOMPRESSED = AV_CODEC_ID_PCM_S16LE,
		A_WAV = AV_CODEC_ID_WAVPACK,
	};
	enum RENDERER_VIDEO_CODEC {
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
	};
	enum RENDERER_SUBTITLE_CODEC {
		S_ASS = AV_CODEC_ID_ASS,
		S_MOV_TEXT = AV_CODEC_ID_MOV_TEXT,
		S_SUBRIP = AV_CODEC_ID_SUBRIP,
		S_TEXT = AV_CODEC_ID_TEXT,
		S_TTML = AV_CODEC_ID_TTML,
		S_WEBVTT = AV_CODEC_ID_WEBVTT,
		S_XSUB = AV_CODEC_ID_XSUB,
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

	~Renderer();

	static Dictionary get_supported_codecs();
	static bool is_video_codec_supported(RENDERER_VIDEO_CODEC a_codec);
	static bool is_audio_codec_supported(RENDERER_AUDIO_CODEC a_codec);

	inline void set_output_file_path(String a_file_path) { file_path = a_file_path; }
	inline String get_output_file_path(String a_file_path) { return file_path; }

	inline void set_video_codec(RENDERER_VIDEO_CODEC a_video_codec) { av_codec_id_video = static_cast<AVCodecID>(a_video_codec); }
	inline RENDERER_VIDEO_CODEC get_video_codec() { return static_cast<RENDERER_VIDEO_CODEC>(av_codec_id_video); }

	inline void set_audio_codec(RENDERER_AUDIO_CODEC a_audio_codec) { av_codec_id_audio = static_cast<AVCodecID>(a_audio_codec); }
	inline RENDERER_AUDIO_CODEC get_audio_codec() { return static_cast<RENDERER_AUDIO_CODEC>(av_codec_id_audio); }

	inline void set_resolution(Vector2i a_resolution) { resolution = a_resolution; }
	inline Vector2i get_resolution() { return resolution; }

	inline void set_framerate(float a_framerate) { framerate = a_framerate; }
	inline float get_framerate() { return framerate; }

	inline void set_bit_rate(int a_bit_rate) { bit_rate = a_bit_rate; }
	inline int get_bit_rate() { return bit_rate; }

	inline void set_gop_size(int a_gop_size) { gop_size = a_gop_size; }
	inline int get_gop_size() { return gop_size; }

	inline void set_render_audio(bool a_value) { render_audio = a_value; }
	inline bool get_render_audio() { return render_audio; }

	inline void set_h264_preset(int a_value) {
		switch (a_value) {
			case H264_PRESET_ULTRAFAST: h264_preset = "ultrafast";
			case H264_PRESET_SUPERFAST: h264_preset = "superfast";
			case H264_PRESET_VERYFAST: h264_preset = "veryfast";
			case H264_PRESET_FASTER: h264_preset = "faster";
			case H264_PRESET_FAST: h264_preset = "fast";
			case H264_PRESET_MEDIUM: h264_preset = "medium";
			case H264_PRESET_SLOW: h264_preset = "slow";
			case H264_PRESET_SLOWER: h264_preset = "slower";
			case H264_PRESET_VERYSLOW: h264_preset = "veryslow";
		}
	}
	inline String get_h264_preset() { return h264_preset; }

	inline char *get_av_error() { return av_make_error_string(error_str, AV_ERROR_MAX_STRING_SIZE, response); }

	bool ready_check();

	int open();
	int send_frame(PackedByteArray a_y, PackedByteArray a_u, PackedByteArray a_v);
	int send_audio(Ref<AudioStreamWAV> a_wav);
	int close();

protected:
	static inline void _bind_methods() {
		/* AUDIO CODEC ENUMS */
		BIND_ENUM_CONSTANT(A_MP3);
		BIND_ENUM_CONSTANT(A_AAC);
		BIND_ENUM_CONSTANT(A_OPUS);
		BIND_ENUM_CONSTANT(A_VORBIS);
		BIND_ENUM_CONSTANT(A_PCM_UNCOMPRESSED);
		BIND_ENUM_CONSTANT(A_WAV);

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

		/* SUBTITLE CODEC ENUMS */
		BIND_ENUM_CONSTANT(S_ASS);
		BIND_ENUM_CONSTANT(S_MOV_TEXT);
		BIND_ENUM_CONSTANT(S_SUBRIP);
		BIND_ENUM_CONSTANT(S_TEXT);
		BIND_ENUM_CONSTANT(S_TTML);
		BIND_ENUM_CONSTANT(S_WEBVTT);
		BIND_ENUM_CONSTANT(S_XSUB);

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


		ClassDB::bind_static_method("Renderer", D_METHOD("get_supported_codecs"), &Renderer::get_supported_codecs);
		ClassDB::bind_static_method("Renderer", D_METHOD("is_video_codec_supported", "a_video_codec"), &Renderer::is_video_codec_supported);
		ClassDB::bind_static_method("Renderer", D_METHOD("is_audio_codec_supported", "a_audio_codec"), &Renderer::is_audio_codec_supported);

		ClassDB::bind_method(D_METHOD("set_output_file_path", "a_file_path"), &Renderer::set_output_file_path);
		ClassDB::bind_method(D_METHOD("get_output_file_path"), &Renderer::get_output_file_path);

		ClassDB::bind_method(D_METHOD("set_video_codec", "a_video_codec"), &Renderer::set_video_codec);
		ClassDB::bind_method(D_METHOD("get_video_codec"), &Renderer::get_video_codec);

		ClassDB::bind_method(D_METHOD("set_audio_codec", "a_audio_codec"), &Renderer::set_audio_codec);
		ClassDB::bind_method(D_METHOD("get_audio_codec"), &Renderer::get_audio_codec);

		ClassDB::bind_method(D_METHOD("set_resolution", "a_resolution"), &Renderer::set_resolution);
		ClassDB::bind_method(D_METHOD("get_resolution"), &Renderer::get_resolution);

		ClassDB::bind_method(D_METHOD("set_framerate", "a_framerate"), &Renderer::set_framerate);
		ClassDB::bind_method(D_METHOD("get_framerate"), &Renderer::get_framerate);

		ClassDB::bind_method(D_METHOD("set_bit_rate", "a_bit_rate"), &Renderer::set_bit_rate);
		ClassDB::bind_method(D_METHOD("get_bit_rate"), &Renderer::get_bit_rate);

		ClassDB::bind_method(D_METHOD("set_gop_size", "a_gop_size"), &Renderer::set_gop_size);
		ClassDB::bind_method(D_METHOD("get_gop_size"), &Renderer::get_gop_size);

		ClassDB::bind_method(D_METHOD("set_render_audio", "a_value"), &Renderer::set_render_audio);
		ClassDB::bind_method(D_METHOD("get_render_audio"), &Renderer::get_render_audio);

		ClassDB::bind_method(D_METHOD("set_h264_preset", "a_value"), &Renderer::set_h264_preset);
		ClassDB::bind_method(D_METHOD("get_h264_preset"), &Renderer::get_h264_preset);

		ClassDB::bind_method(D_METHOD("ready_check"), &Renderer::ready_check);

		ClassDB::bind_method(D_METHOD("open"), &Renderer::open);
		ClassDB::bind_method(D_METHOD("send_frame", "a_y", "a_u", "a_v"), &Renderer::send_frame);
		ClassDB::bind_method(D_METHOD("send_audio", "a_wav"), &Renderer::send_audio);
		ClassDB::bind_method(D_METHOD("close"), &Renderer::close);
	}
};

VARIANT_ENUM_CAST(Renderer::RENDERER_VIDEO_CODEC);
VARIANT_ENUM_CAST(Renderer::RENDERER_AUDIO_CODEC);
VARIANT_ENUM_CAST(Renderer::RENDERER_SUBTITLE_CODEC);
VARIANT_ENUM_CAST(Renderer::H264_PRESETS);
