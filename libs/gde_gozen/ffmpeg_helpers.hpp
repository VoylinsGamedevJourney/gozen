#pragma once

#include <memory>

extern "C" {
	#include <libavformat/avformat.h>
	#include <libavcodec/avcodec.h>
	#include <libavutil/frame.h>
	#include <libswresample/swresample.h>
	#include <libswscale/swscale.h>
}


// AV Format Context helpers
struct AVFormatContextInputDeleter {
	void operator()(AVFormatContext* ctx) const {
		if (ctx)
			avformat_close_input(&ctx);
	}
};
using UniqueAVFormatContextInput = std::unique_ptr<AVFormatContext, AVFormatContextInputDeleter>;


struct AVFormatContextOutputDeleter {
	void operator()(AVFormatContext* ctx) const {
		if (ctx) {
			if (ctx->pb && !(ctx->oformat->flags & AVFMT_NOFILE))
				avio_closep(&ctx->pb);

			avformat_free_context(ctx);
		}
	}
};
using UniqueAVFormatContextOutput = std::unique_ptr<AVFormatContext, AVFormatContextOutputDeleter>;


// AV Codec Context helpers
struct AVCodecContextDeleter {
	void operator()(AVCodecContext* ctx) const {
		if (ctx) {
			avcodec_free_context(&ctx);
		}
	}
};
using UniqueAVCodecContext = std::unique_ptr<AVCodecContext, AVCodecContextDeleter>;


// AV Frame helper
struct AVFrameDeleter {
	void operator()(AVFrame* frame) const {
		if (frame) {
			av_frame_free(&frame);
		}
	}
};
using UniqueAVFrame = std::unique_ptr<AVFrame, AVFrameDeleter>;


// AV Packet helper
struct AVPacketDeleter {
	void operator()(AVPacket* packet) const {
		if (packet) {
			av_packet_free(&packet);
		}
	}
};
using UniqueAVPacket = std::unique_ptr<AVPacket, AVPacketDeleter>;


// SWResample Context helper
struct SwrContextDeleter {
	void operator()(SwrContext* ctx) const {
		if (ctx) {
			swr_free(&ctx);
		}
	}
};
using UniqueSwrContext = std::unique_ptr<SwrContext, SwrContextDeleter>;


// SWScale Context helper
struct SwsContextDeleter {
	void operator()(SwsContext* ctx) const {
		if (ctx) {
			sws_freeContext(ctx);
		}
	}
};
using UniqueSwsContext = std::unique_ptr<SwsContext, SwsContextDeleter>;


template<typename T_FFmpeg, typename T_Deleter>
std::unique_ptr<T_FFmpeg, T_Deleter> make_unique_ffmpeg(T_FFmpeg* ptr) {
	return std::unique_ptr<T_FFmpeg, T_Deleter>(ptr);
}


inline UniqueAVFrame make_unique_avframe() {
	return make_unique_ffmpeg<AVFrame, AVFrameDeleter>(av_frame_alloc());
}


inline UniqueAVPacket make_unique_avpacket() {
	return make_unique_ffmpeg<AVPacket, AVPacketDeleter>(av_packet_alloc());
}

