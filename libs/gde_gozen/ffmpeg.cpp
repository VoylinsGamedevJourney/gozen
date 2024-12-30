#include "ffmpeg.hpp"



void FFmpeg::print_av_error(const char *a_message, int a_error) {
	char l_error_buffer[AV_ERROR_MAX_STRING_SIZE];

	av_strerror(a_error, l_error_buffer, sizeof(l_error_buffer));
	UtilityFunctions::printerr((std::string(a_message) + " " + l_error_buffer).c_str());
}

void FFmpeg::enable_multithreading(AVCodecContext *&a_codec_ctx, const AVCodec *&a_codec) {
	a_codec_ctx->thread_count = OS::get_singleton()->get_processor_count() - 1;
	if (a_codec->capabilities & AV_CODEC_CAP_FRAME_THREADS) {
		a_codec_ctx->thread_type = FF_THREAD_FRAME;
	} else if (a_codec->capabilities & AV_CODEC_CAP_SLICE_THREADS) {
		a_codec_ctx->thread_type = FF_THREAD_SLICE;
	} else a_codec_ctx->thread_count = 1; // Don't use multithreading
}

int FFmpeg::get_frame(AVFormatContext *a_format_ctx, AVCodecContext *a_codec_ctx, int a_stream_id, AVFrame *a_frame, AVPacket *a_packet) {
	eof = false;

	while ((response = avcodec_receive_frame(a_codec_ctx, a_frame)) == AVERROR(EAGAIN) && !eof) {
		do {
			av_packet_unref(a_packet);
			response = av_read_frame(a_format_ctx, a_packet);
		} while (a_packet->stream_index != a_stream_id && response >= 0);

		if (response == AVERROR_EOF) {
			eof = true;
			avcodec_send_packet(a_codec_ctx, nullptr); // Send null packet to signal end
		} else if (response < 0) {
			UtilityFunctions::printerr("Error reading frame! ", response);
			break;
		} else {
			response = avcodec_send_packet(a_codec_ctx, a_packet);
			if (response < 0 && response != AVERROR_INVALIDDATA) {
				UtilityFunctions::printerr("Problem sending package! ", response);
				break;
			}
		}
	}

	return response;
}

enum AVPixelFormat FFmpeg::get_hw_format(const enum AVPixelFormat *a_pix_fmt, enum AVPixelFormat *a_hw_pix_fmt) {
	const enum AVPixelFormat *p;

	for (p = a_pix_fmt; *p != -1; p++)
		if (*p == *a_hw_pix_fmt)
			return *p;

	UtilityFunctions::printerr("Failed to get HW surface format!");
	return AV_PIX_FMT_NONE;
}


PackedByteArray FFmpeg::get_audio(AVFormatContext *&a_format_ctx, AVStream *&a_stream) {
	const int TARGET_SAMPLE_RATE = 44100;
	const AVSampleFormat TARGET_FORMAT = AV_SAMPLE_FMT_S16;
	const AVChannelLayout TARGET_LAYOUT = AV_CHANNEL_LAYOUT_STEREO;

	struct SwrContext *l_swr_ctx = nullptr;
	PackedByteArray l_data = PackedByteArray();


	const AVCodec *l_codec_audio = avcodec_find_decoder(a_stream->codecpar->codec_id);
	if (!l_codec_audio) {
		UtilityFunctions::printerr("Couldn't find any codec decoder for audio!");
		return l_data;
	}

	AVCodecContext *l_codec_ctx_audio = avcodec_alloc_context3(l_codec_audio);
	if (l_codec_ctx_audio == NULL) {
		UtilityFunctions::printerr("Couldn't allocate codec context for audio!");
		return l_data;
	} else if (avcodec_parameters_to_context(l_codec_ctx_audio, a_stream->codecpar)) {
		UtilityFunctions::printerr("Couldn't initialize audio codec context!");
		return l_data;
	}

	enable_multithreading(l_codec_ctx_audio, l_codec_audio);
	l_codec_ctx_audio->request_sample_fmt = TARGET_FORMAT;

	if (avcodec_open2(l_codec_ctx_audio, l_codec_audio, NULL)) {
		UtilityFunctions::printerr("Couldn't open audio codec!");
		return l_data;
	}

	response = swr_alloc_set_opts2(&l_swr_ctx,
			&TARGET_LAYOUT,		// Out channel layout: Stereo
			TARGET_FORMAT,		// We need 16 bits
			TARGET_SAMPLE_RATE,	// Sample rate should be the Godot default
			&l_codec_ctx_audio->ch_layout,  // In channel layout
			l_codec_ctx_audio->sample_fmt,	// In sample format
			l_codec_ctx_audio->sample_rate, // In sample rate
			0, nullptr);
	if (response < 0 || (response = swr_init(l_swr_ctx))) {
		print_av_error("Couldn't initialize SWR!", response);
		avcodec_flush_buffers(l_codec_ctx_audio);
		avcodec_free_context(&l_codec_ctx_audio);
		return l_data;
	}

	AVFrame *l_frame = av_frame_alloc(), *l_decoded_frame = av_frame_alloc();
	AVPacket *l_packet = av_packet_alloc();
	if (!l_frame || !l_decoded_frame || !l_packet) {
		UtilityFunctions::printerr("Couldn't allocate frames or packet for audio!");
		avcodec_flush_buffers(l_codec_ctx_audio);
		avcodec_free_context(&l_codec_ctx_audio);
		swr_free(&l_swr_ctx);
		return l_data;
	}

	// Set the seeker to the beginning
	int l_start_time = a_stream->start_time != AV_NOPTS_VALUE ? a_stream->start_time : 0;
	//avcodec_flush_buffers(l_codec_ctx_audio); // Not certain if needed here
	if ((response = av_seek_frame(a_format_ctx, -1, l_start_time, AVSEEK_FLAG_BACKWARD)) < 0) {
		UtilityFunctions::printerr("Can't seek to the beginning of audio stream!");
		avcodec_flush_buffers(l_codec_ctx_audio);
		avcodec_free_context(&l_codec_ctx_audio);
		swr_free(&l_swr_ctx);
		return l_data;
	}


	size_t l_audio_size = 0;
	int l_bytes_per_samples = av_get_bytes_per_sample(TARGET_FORMAT);

	while (!(get_frame(a_format_ctx, l_codec_ctx_audio, a_stream->index, l_frame, l_packet))) {
		// Copy decoded data to new frame
		l_decoded_frame->format = TARGET_FORMAT;
		l_decoded_frame->ch_layout = TARGET_LAYOUT;
		l_decoded_frame->sample_rate = TARGET_SAMPLE_RATE;
		l_decoded_frame->nb_samples = swr_get_out_samples(l_swr_ctx, l_frame->nb_samples);

		if ((response = av_frame_get_buffer(l_decoded_frame, 0)) < 0) {
			print_av_error("Couldn't create new frame for swr!", response);
			av_frame_unref(l_frame);
			av_frame_unref(l_decoded_frame);
			break;
		}

		if ((response = swr_convert_frame(l_swr_ctx, l_decoded_frame, l_frame)) < 0) {
			print_av_error("Couldn't convert the audio frame!", response);
			av_frame_unref(l_frame);
			av_frame_unref(l_decoded_frame);
			break;
		}

		size_t l_byte_size = l_decoded_frame->nb_samples * l_bytes_per_samples * 2;

		l_data.resize(l_audio_size + l_byte_size);
		memcpy(&(l_data.ptrw()[l_audio_size]), l_decoded_frame->extended_data[0], l_byte_size);
		l_audio_size += l_byte_size;

		av_frame_unref(l_frame);
		av_frame_unref(l_decoded_frame);
	}

	// Cleanup
	avcodec_flush_buffers(l_codec_ctx_audio);
	avcodec_free_context(&l_codec_ctx_audio);
	swr_free(&l_swr_ctx);

	av_frame_free(&l_frame);
	av_frame_free(&l_decoded_frame);
	av_packet_free(&l_packet);

	return l_data;
}

