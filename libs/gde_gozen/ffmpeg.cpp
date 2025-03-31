#include "ffmpeg.hpp"



void FFmpeg::print_av_error(const char *message, int error) {
	char error_buffer[AV_ERROR_MAX_STRING_SIZE];

	av_strerror(error, error_buffer, sizeof(error_buffer));
	UtilityFunctions::printerr("FFmpeg error: ", message, " ", error_buffer);
}

void FFmpeg::enable_multithreading(AVCodecContext *&codec_ctx, const AVCodec *&codec) {
	codec_ctx->thread_count = Math::min(
			OS::get_singleton()->get_processor_count() - 1, 1);
	// TODO: Let users decide how many threads they maximum want to use.

	if (codec->capabilities & AV_CODEC_CAP_FRAME_THREADS)
		codec_ctx->thread_type = FF_THREAD_FRAME;
	else if (codec->capabilities & AV_CODEC_CAP_SLICE_THREADS)
		codec_ctx->thread_type = FF_THREAD_SLICE;
	else
		codec_ctx->thread_count = 1; // Fallback
}

int FFmpeg::get_frame(AVFormatContext *format_ctx, AVCodecContext *codec_ctx, int stream_id, AVFrame *frame, AVPacket *packet) {
	eof = false;

	while ((response = avcodec_receive_frame(codec_ctx, frame)) == AVERROR(EAGAIN) && !eof) {
		do {
			av_packet_unref(packet);
			response = av_read_frame(format_ctx, packet);
		} while (packet->stream_index != stream_id && response >= 0);

		if (response == AVERROR_EOF) {
			eof = true;
			avcodec_send_packet(codec_ctx, nullptr); // Send null packet to signal end
		} else if (response < 0) {
			UtilityFunctions::printerr("Error reading frame! ", response);
			break;
		} else {
			response = avcodec_send_packet(codec_ctx, packet);
			if (response < 0 && response != AVERROR_INVALIDDATA) {
				UtilityFunctions::printerr("Problem sending package! ", response);
				break;
			}
		}
	}

	return response;
}

