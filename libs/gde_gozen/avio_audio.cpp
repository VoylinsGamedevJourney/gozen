#include "avio_audio.hpp"


AvioAudio::AvioAudio(const uint8_t *a_data, size_t a_size):
			wav_data(a_data), wav_size(a_size), position(0) {}

AvioAudio::~AvioAudio() {}


int AvioAudio::read_packet(void *a_opaque, uint8_t *a_buf, int a_buf_size) {
	AvioAudio *l_self = static_cast<AvioAudio*>(a_opaque);
	size_t l_remaining = l_self->wav_size - l_self->position;

	if (l_remaining == 0) {
		UtilityFunctions::print("AvioAudio: EOF reached in read_packet!");
		return AVERROR_EOF;
	}

	size_t l_to_copy = a_buf_size > l_remaining ? l_remaining : a_buf_size;
	memcpy(a_buf, l_self->wav_data + l_self->position, l_to_copy);
	l_self->position += l_to_copy;

	return l_to_copy;
}

int64_t AvioAudio::seek_packet(void *a_opaque, int64_t a_offset, int a_whence) {
	AvioAudio *l_self = static_cast<AvioAudio*>(a_opaque);
	size_t l_new_position;

	if (a_whence == AVSEEK_SIZE) return l_self->wav_size;
	else if (a_whence == SEEK_SET) l_new_position = a_offset;
	else if (a_whence == SEEK_CUR) l_new_position = l_self->position + a_offset;
	else if (a_whence == SEEK_END) l_new_position = l_self->wav_size + a_offset;	
	else return AVERROR(EINVAL);

	if (l_new_position < 0 || l_new_position > l_self->wav_size) {
		UtilityFunctions::print("AvioAudio: Seek out of bounds, offset: ", a_offset);
		return AVERROR(EINVAL);
	}

	l_self->position = l_new_position;
	return l_self->position;
}

AVFormatContext *AvioAudio::create_avformat_context() {
	AVFormatContext *l_fmt_ctx = avformat_alloc_context();
	if (!l_fmt_ctx) {
		UtilityFunctions::printerr("Couldn't allocate avformat context!");
		return nullptr;
	}

	// Allocate buffer for AVIO
	const int l_buffer_size = 4096; // 4KB buffer
	uint8_t	*l_avio_buffer = static_cast<uint8_t*>(av_malloc(l_buffer_size));
	if (!l_avio_buffer) {
		UtilityFunctions::printerr("Couldn't allocate AVIO buffer!");
		avformat_free_context(l_fmt_ctx);
		return nullptr;
	}

	// Create custom AVIO context
	AVIOContext *l_avio_ctx = avio_alloc_context(
			l_avio_buffer, l_buffer_size, 0, this, read_packet, nullptr, seek_packet);
	if (!l_avio_ctx) {
		UtilityFunctions::printerr("Couldn't allocate AVIOContext!");
		av_free(l_avio_buffer);
		avformat_free_context(l_fmt_ctx);
		return nullptr;
	}

	l_fmt_ctx->pb = l_avio_ctx;

	// Open the avformat context
	if ((response = avformat_open_input(&l_fmt_ctx, NULL, NULL, NULL)) < 0) {
		FFmpeg::print_av_error("Couldn't open AVFormatContext", response);
		av_free(l_avio_buffer);
		avio_context_free(&l_avio_ctx);
		avformat_free_context(l_fmt_ctx);
		return nullptr;
	}

	// Read stream info
	if ((response = avformat_find_stream_info(l_fmt_ctx, NULL)) < 0) {
		FFmpeg::print_av_error("Couldn't find stream info", response);
		avformat_free_context(l_fmt_ctx);
		return nullptr;
	}
	
	return l_fmt_ctx;
}
