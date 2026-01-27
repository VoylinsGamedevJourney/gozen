#include "ffmpeg.hpp"

void FFmpeg::print_av_error(const char* message, int error) {
	char error_buffer[AV_ERROR_MAX_STRING_SIZE];

	av_strerror(error, error_buffer, sizeof(error_buffer));
	FFmpeg::_log_err(String(message) + " " + error_buffer);
}

void FFmpeg::enable_multithreading(AVCodecContext* codec_ctx, const AVCodec* codec, int thread_count) {
	codec_ctx->thread_count = OS::get_singleton()->get_processor_count() - 1;

	if (codec->capabilities & AV_CODEC_CAP_FRAME_THREADS)
		codec_ctx->thread_type = FF_THREAD_FRAME;
	else if (codec->capabilities & AV_CODEC_CAP_SLICE_THREADS)
		codec_ctx->thread_type = FF_THREAD_SLICE;
	else
		codec_ctx->thread_count = 1; // Don't use multithreading
}

int FFmpeg::get_frame(AVFormatContext* format_ctx, AVCodecContext* codec_ctx, int stream_id, AVFrame* frame,
					  AVPacket* packet) {
	int response = 0;
	bool eof = false;

	av_frame_unref(frame);
	while ((response = avcodec_receive_frame(codec_ctx, frame)) == AVERROR(EAGAIN) && !eof) {
		do {
			av_packet_unref(packet);
			response = av_read_frame(format_ctx, packet);
		} while (packet->stream_index != stream_id && response >= 0);

		if (response == AVERROR_EOF) {
			eof = true;
			avcodec_send_packet(codec_ctx, nullptr); // Send null packet to signal end
		} else if (response < 0) {
			FFmpeg::_log_err("Error reading frame! " + String::num_int64(response));
			break;
		} else {
			response = avcodec_send_packet(codec_ctx, packet);
			if (response < 0 && response != AVERROR_INVALIDDATA) {
				FFmpeg::_log_err("Problem sending package! " + String::num_int64(response));
				break;
			}
		}
		av_frame_unref(frame);
	}

	return response;
}

enum AVPixelFormat FFmpeg::get_hw_format(const enum AVPixelFormat* pix_fmt, enum AVPixelFormat* hw_pix_fmt) {
	const enum AVPixelFormat* p;

	for (p = pix_fmt; *p != -1; p++)
		if (*p == *hw_pix_fmt)
			return *p;

	FFmpeg::_log_err("Failed to get HW surface format!");
	return AV_PIX_FMT_NONE;
}

// For `res://` videos.
int FFmpeg::read_buffer_packet(void* opaque, uint8_t* buffer, int buffer_size) {
	BufferData* buffer_data = (BufferData*)opaque;
	size_t remaining = buffer_data->size - buffer_data->offset;

	if (remaining == 0)
		return AVERROR_EOF;

	// Change buffer size if not enough data remaining.
	size_t new_size = (remaining < (size_t)buffer_size ? remaining : (size_t)buffer_size);

	memcpy(buffer, buffer_data->ptr + buffer_data->offset, new_size);
	buffer_data->offset += new_size;
	return (int)new_size;
}

// For `res://` videos.
int64_t FFmpeg::seek_buffer(void* opaque, int64_t offset, int where) {
	BufferData* buffer_data = (BufferData*)opaque;
	int64_t new_offset = 0;

	switch (where) {
	case SEEK_SET: // 0
		new_offset = offset;
		break;
	case SEEK_CUR: // 1
		new_offset = buffer_data->offset + offset;
		break;
	case SEEK_END: // 2
		new_offset = buffer_data->size + offset;
		break;
	case AVSEEK_SIZE: // 1
		return buffer_data->size;
	default: // Error
		return -1;
	}

	if (new_offset < 0)
		return -1;

	buffer_data->offset = new_offset;
	return buffer_data->offset;
}
