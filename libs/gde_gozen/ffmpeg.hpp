#pragma once

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavcodec/codec.h>
#include <libavcodec/codec_id.h>
#include <libavcodec/packet.h>
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

#include "ffmpeg_helpers.hpp"

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/variant/utility_functions.hpp>


using namespace godot;


class FFmpeg {
  public:
	const static int AVIO_CTX_BUFFER_SIZE = 4 * 1024 * 1024; // 4 MB

	static void print_av_error(const char* message, int error);

	static void enable_multithreading(AVCodecContext* codec_ctx, const AVCodec* codec, int thread_count = 0);
	static int get_frame(AVFormatContext* format_ctx, AVCodecContext* codec_ctx, int stream_id, AVFrame* frame,
						 AVPacket* packet);
	static enum AVPixelFormat get_hw_format(const enum AVPixelFormat* pix_fmt, enum AVPixelFormat* hw_pix_fmt);

	static int read_buffer_packet(void* opaque, uint8_t* buffer, int buffer_size);
	static int64_t seek_buffer(void* opaque, int64_t offset, int where);
};
