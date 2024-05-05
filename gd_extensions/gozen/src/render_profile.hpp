#pragma once

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

extern "C" {
	#include <libavcodec/avcodec.h>
	#include <libavformat/avformat.h>
	#include <libavdevice/avdevice.h>
	#include <libavfilter/avfilter.h>
	#include <libavutil/dict.h>
	#include <libpostproc/postprocess.h>
	#include <libavutil/channel_layout.h>
	#include <libavutil/opt.h>
	#include <libavutil/imgutils.h>
	#include <libavutil/pixdesc.h>
	#include <libswscale/swscale.h>
	#include <libswresample/swresample.h>
}


using namespace godot;

class RenderProfile: public Resource {
	GDCLASS(RenderProfile, Resource);

public:

enum CODEC {
		/* Audio codecs */
		MP3 = AV_CODEC_ID_MP3,
		AAC = AV_CODEC_ID_AAC,
		OPUS = AV_CODEC_ID_OPUS,
		VORBIS = AV_CODEC_ID_VORBIS,
		FLAC = AV_CODEC_ID_FLAC,
		PCM_UNCOMPRESSED = AV_CODEC_ID_PCM_S16LE,
		AC3 = AV_CODEC_ID_AC3,
		EAC3 = AV_CODEC_ID_EAC3,
		WAV = AV_CODEC_ID_WAVPACK,

		/* Video codecs */
		H264 = AV_CODEC_ID_H264,
		H265 = AV_CODEC_ID_HEVC,
		VP9 = AV_CODEC_ID_VP9,
		MPEG4 = AV_CODEC_ID_MPEG4,
		MPEG2 = AV_CODEC_ID_MPEG2VIDEO,
		MPEG1 = AV_CODEC_ID_MPEG1VIDEO,
		AV1 = AV_CODEC_ID_AV1,
		VP8 = AV_CODEC_ID_VP8 
	};


	String filename;
	AVCodecID video_codec, audio_codec;
	Vector2i video_size;
	int framerate = -1, bit_rate = -1;
	bool alpha_layer = false;


	void set_filename(String a_filename);
	String get_filename() const;

	void set_video_codec(CODEC a_video_codec);
	CODEC get_video_codec() const;

	void set_audio_codec(CODEC a_audio_codec);
	CODEC get_audio_codec() const;
 
	void set_video_size(Vector2i a_video_size);
	Vector2i get_video_size() const;

	void set_framerate(int a_framerate);
	int get_framerate() const;

	void set_bit_rate(int a_bit_rate);
	int get_bit_rate() const;

	void set_alpha_layer(bool a_alpha_layer);
	bool get_alpha_layer() const;

	bool check() const;
	
protected:
	static void _bind_methods();
};

VARIANT_ENUM_CAST(RenderProfile::CODEC);
