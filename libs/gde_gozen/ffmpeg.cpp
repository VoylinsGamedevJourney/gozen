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


AudioStreamWAV *FFmpeg::get_audio(AVFormatContext *&a_format_ctx, AVStream *&a_stream) {
	AudioStreamWAV *l_audio = memnew(AudioStreamWAV);

	const AVCodec *l_codec_audio = avcodec_find_decoder(a_stream->codecpar->codec_id);
	if (!l_codec_audio) {
		UtilityFunctions::printerr("Couldn't find any codec decoder for audio!");
		return l_audio;
	}

	AVCodecContext *l_codec_ctx_audio = avcodec_alloc_context3(l_codec_audio);
	if (l_codec_ctx_audio == NULL) {
		UtilityFunctions::printerr("Couldn't allocate codec context for audio!");
		return l_audio;
	} else if (avcodec_parameters_to_context(l_codec_ctx_audio, a_stream->codecpar)) {
		UtilityFunctions::printerr("Couldn't initialize audio codec context!");
		return l_audio;
	}

	enable_multithreading(l_codec_ctx_audio, l_codec_audio);
	l_codec_ctx_audio->request_sample_fmt = AV_SAMPLE_FMT_S16;

	// Open codec - Audio
	if (avcodec_open2(l_codec_ctx_audio, l_codec_audio, NULL)) {
		UtilityFunctions::printerr("Couldn't open audio codec!");
		return l_audio;
	}

	AVChannelLayout l_ch_layout;
	struct SwrContext *l_swr_ctx = nullptr;
	if (l_codec_ctx_audio->ch_layout.nb_channels <= 3) 
		l_ch_layout = l_codec_ctx_audio->ch_layout;
	else
		l_ch_layout = AV_CHANNEL_LAYOUT_STEREO;

	response = swr_alloc_set_opts2(
		&l_swr_ctx, &l_ch_layout, AV_SAMPLE_FMT_S16,
		l_codec_ctx_audio->sample_rate, &l_codec_ctx_audio->ch_layout,
		l_codec_ctx_audio->sample_fmt, l_codec_ctx_audio->sample_rate, 0,
		nullptr);

	if (response < 0) {
		print_av_error("Failed to obtain SWR context!", response);
		avcodec_flush_buffers(l_codec_ctx_audio);
		avcodec_free_context(&l_codec_ctx_audio);
		return l_audio;
	}

	response = swr_init(l_swr_ctx);
	if (response < 0) {
		print_av_error("Couldn't initialize SWR!", response);
		avcodec_flush_buffers(l_codec_ctx_audio);
		avcodec_free_context(&l_codec_ctx_audio);
		return l_audio;
	}

	// Set the seeker to the beginning
	int start_time_audio = a_stream->start_time != AV_NOPTS_VALUE ? a_stream->start_time : 0;
	avcodec_flush_buffers(l_codec_ctx_audio);

	if ((response = av_seek_frame(a_format_ctx, -1, start_time_audio, AVSEEK_FLAG_BACKWARD)) < 0) {
		UtilityFunctions::printerr("Can't seek to the beginning of audio stream!");
		avcodec_flush_buffers(l_codec_ctx_audio);
		avcodec_free_context(&l_codec_ctx_audio);
		swr_free(&l_swr_ctx);
		return l_audio;
	}

	AVFrame *l_frame = av_frame_alloc();
	AVFrame *l_decoded_frame = av_frame_alloc();
	AVPacket *l_packet = av_packet_alloc();
	if (!l_frame || !l_decoded_frame || !l_packet) {
		UtilityFunctions::printerr("Couldn't allocate frames or packet for audio!");
		avcodec_flush_buffers(l_codec_ctx_audio);
		avcodec_free_context(&l_codec_ctx_audio);
		swr_free(&l_swr_ctx);
		return l_audio;
	}

	int l_bytes_per_samples = av_get_bytes_per_sample(AV_SAMPLE_FMT_S16);
	PackedByteArray l_audio_data = PackedByteArray();
	bool l_stereo = l_codec_ctx_audio->ch_layout.nb_channels >= 2;
	size_t l_audio_size = 0;

	while (true) {
		if (get_frame(a_format_ctx, l_codec_ctx_audio, a_stream->index, l_frame, l_packet))
			break;

		// Copy decoded data to new frame
		l_decoded_frame->format = AV_SAMPLE_FMT_S16;
		l_decoded_frame->ch_layout = l_ch_layout;
		l_decoded_frame->sample_rate = l_frame->sample_rate;
		l_decoded_frame->nb_samples = swr_get_out_samples(l_swr_ctx, l_frame->nb_samples);

		if ((response = av_frame_get_buffer(l_decoded_frame, 0)) < 0) {
			print_av_error("Couldn't create new frame for swr!", response);
			av_frame_unref(l_frame);
			av_frame_unref(l_decoded_frame);
			break;
		}

		if ((response = swr_config_frame(l_swr_ctx, l_decoded_frame, l_frame)) < 0) {
			print_av_error("Couldn't config the audio frame!", response);
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

		size_t l_byte_size = l_decoded_frame->nb_samples * l_bytes_per_samples;
		if (l_codec_ctx_audio->ch_layout.nb_channels >= 2)
			l_byte_size *= 2;

		l_audio_data.resize(l_audio_size + l_byte_size);
		memcpy(&(l_audio_data.ptrw()[l_audio_size]), l_decoded_frame->extended_data[0], l_byte_size);
		l_audio_size += l_byte_size;

		av_frame_unref(l_frame);
		av_frame_unref(l_decoded_frame);
	}

	// Audio creation
	l_audio->set_format(l_audio->FORMAT_16_BITS);
	l_audio->set_mix_rate(l_codec_ctx_audio->sample_rate);
	l_audio->set_stereo(l_stereo);
	l_audio->set_data(l_audio_data);

	// Cleanup
	avcodec_flush_buffers(l_codec_ctx_audio);
	avcodec_free_context(&l_codec_ctx_audio);
	swr_free(&l_swr_ctx);

	av_frame_free(&l_frame);
	av_frame_free(&l_decoded_frame);
	av_packet_free(&l_packet);

	return l_audio;
}

