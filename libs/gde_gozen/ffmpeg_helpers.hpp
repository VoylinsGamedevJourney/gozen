#pragma once


#include <cstdint>
#include <memory>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavformat/avio.h>
#include <libavutil/frame.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>
}


// AV Format Context helpers.
struct AVFormatCtxInputDeleter {
	void operator()(AVFormatContext* ctx) const {
		if (ctx)
			avformat_close_input(&ctx);
	}
};
using UniqueAVFormatCtxInput = std::unique_ptr<AVFormatContext, AVFormatCtxInputDeleter>;


struct AVFormatCtxOutputDeleter {
	void operator()(AVFormatContext* ctx) const {
		if (!ctx)
			return;
		if (ctx->pb && !(ctx->oformat->flags & AVFMT_NOFILE))
			avio_closep(&ctx->pb);
		avformat_free_context(ctx);
	}
};
using UniqueAVFormatCtxOutput = std::unique_ptr<AVFormatContext, AVFormatCtxOutputDeleter>;


// AV Codec Context helpers.
struct AVCodecCtxDeleter {
	void operator()(AVCodecContext* ctx) const {
		if (ctx)
			avcodec_free_context(&ctx);
	}
};
using UniqueAVCodecCtx = std::unique_ptr<AVCodecContext, AVCodecCtxDeleter>;


// AV Frame helper.
struct AVFrameDeleter {
	void operator()(AVFrame* frame) const {
		if (frame)
			av_frame_free(&frame);
	}
};
using UniqueAVFrame = std::unique_ptr<AVFrame, AVFrameDeleter>;


// AV Packet helper.
struct AVPacketDeleter {
	void operator()(AVPacket* packet) const {
		if (packet)
			av_packet_free(&packet);
	}
};
using UniqueAVPacket = std::unique_ptr<AVPacket, AVPacketDeleter>;


// AVIO helper.
struct AVIOContextDeleter {
	void operator()(AVIOContext* avio_ctx) const {
		if (!avio_ctx)
			return;
		if (avio_ctx->buffer)
			av_free(avio_ctx->buffer);
		avio_context_free(&avio_ctx);
	}
};
using UniqueAVIOContext = std::unique_ptr<AVIOContext, AVIOContextDeleter>;


// SWResample Context helper.
struct SwrCtxDeleter {
	void operator()(SwrContext* ctx) const {
		if (ctx)
			swr_free(&ctx);
	}
};
using UniqueSwrCtx = std::unique_ptr<SwrContext, SwrCtxDeleter>;


// SWScale Context helper.
struct SwsCtxDeleter {
	void operator()(SwsContext* ctx) const {
		if (ctx)
			sws_freeContext(ctx);
	}
};
using UniqueSwsCtx = std::unique_ptr<SwsContext, SwsCtxDeleter>;


template <typename T_FFmpeg, typename T_Deleter>
std::unique_ptr<T_FFmpeg, T_Deleter> make_unique_ffmpeg(T_FFmpeg* ptr) {
	return std::unique_ptr<T_FFmpeg, T_Deleter>(ptr);
}


inline UniqueAVFrame make_unique_avframe() { return make_unique_ffmpeg<AVFrame, AVFrameDeleter>(av_frame_alloc()); }


inline UniqueAVPacket make_unique_avpacket() {
	return make_unique_ffmpeg<AVPacket, AVPacketDeleter>(av_packet_alloc());
}

// For `res://` videos.
struct BufferData {
	uint8_t* ptr;
	size_t size;
	size_t offset;
};
