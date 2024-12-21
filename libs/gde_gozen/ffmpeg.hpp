#pragma once

extern "C" {
	#include <libavcodec/avcodec.h>
	#include <libavcodec/codec.h>
	#include <libavcodec/codec_id.h>
	#include <libavcodec/packet.h>
	
	#include <libavdevice/avdevice.h>
	
	#include <libavformat/avformat.h>
	
	#include <libavutil/avassert.h>
	#include <libavutil/avutil.h>
	#include <libavutil/channel_layout.h>
	#include <libavutil/dict.h>
	#include <libavutil/display.h>
	#include <libavutil/error.h>
	#include <libavutil/frame.h>
	#include <libavutil/hwcontext.h>
	#include <libavutil/imgutils.h>
	#include <libavutil/mathematics.h>
	#include <libavutil/opt.h>
	#include <libavutil/pixdesc.h>
	#include <libavutil/rational.h>
	#include <libavutil/timestamp.h>
	
	#include <libswresample/swresample.h>
	#include <libswscale/swscale.h>
}

#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/variant/utility_functions.hpp>


using namespace godot;


class FFmpeg {
public:
	static inline int response = 0;
	static inline bool eof = false;

	static void print_av_error(const char *a_message, int a_error);

	static void enable_multithreading(AVCodecContext *&a_codec_ctx, const AVCodec *&a_codec);
	static int get_frame(AVFormatContext *a_format_ctx, AVCodecContext *a_codec_ctx, int a_stream_id, AVFrame *a_frame, AVPacket *a_packet);
	static enum AVPixelFormat get_hw_format(const enum AVPixelFormat *a_pix_fmt, enum AVPixelFormat *a_hw_pix_fmt);

	static AudioStreamWAV *get_audio(AVFormatContext *&a_format_ctx, AVStream *&a_stream);
};
