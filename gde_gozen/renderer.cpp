#include "renderer.hpp"


Renderer::~Renderer() {
	close();
}

Dictionary Renderer::get_supported_codecs() {
	std::pair<RENDERER_AUDIO_CODEC, String> l_audio_codecs[] = {
		{A_MP3, "MP3"},
		{A_AAC, "AAC"},
		{A_OPUS, "OPUS"},
		{A_VORBIS, "VORBIS"},
		{A_PCM_UNCOMPRESSED, "PCM_UNCOMPRESSED"},
		{A_WAV, "WAV"},
	};
	std::pair<RENDERER_VIDEO_CODEC, String> l_video_codecs[] = {
		{V_H264, "H264"},
		{V_HEVC, "HEVC"},
		{V_VP9, "VP9"},
		{V_MPEG4, "MPEG4"},
		{V_MPEG2, "MPEG2"},
		{V_MPEG1, "MPEG1"},
		{V_AV1, "AV1"},
		{V_VP8, "VP8"},
		{V_AMV, "AMV"},
		{V_GIF, "GIF"},
		{V_THEORA, "THEORA"},
		{V_WEBP, "WEBP"},
		{V_DNXHD, "DNXHD"},
		{V_MJPEG, "MJPEG"},
		{V_PRORES, "PRORES"},
		{V_RAWVIDEO, "RAWVIDEO"},
	};
	Dictionary l_dic = {}, l_audio_dic = {}, l_video_dic = {};

	for (const auto &l_audio_codec : l_audio_codecs) {
		const AVCodec *l_codec = avcodec_find_encoder(static_cast<AVCodecID>(l_audio_codec.first));
		Dictionary l_entry = {};
		l_entry["codec_id"] = l_audio_codec.first;
		if (!l_codec) {
			l_entry["supported"] = false;
			l_entry["hardware_accel"] = false;
		}
		else {
			l_entry["supported"] = true;
			if (l_codec->capabilities & (AV_CODEC_CAP_HARDWARE | AV_CODEC_CAP_HYBRID))
				l_entry["hardware_accel"] = true;
			else {
				const AVCodecHWConfig* l_config_0 = avcodec_get_hw_config(l_codec, 0);
				if (l_config_0)
					l_entry["hardware_accel"] = true;
				else
					l_entry["hardware_accel"] = false;
			}
		}
		l_audio_dic[l_audio_codec.second] = l_entry;
	}

	for (const auto &l_video_codec : l_video_codecs) {
		const AVCodec *l_codec = avcodec_find_encoder(static_cast<AVCodecID>(l_video_codec.first));
		Dictionary l_entry = {};
		l_entry["codec_id"] = l_video_codec.first;
		if (!l_codec) {
			l_entry["supported"] = false;
			l_entry["hardware_accel"] = false;
		}
		else { 
			l_entry["supported"] = true;
			if (l_codec->capabilities & (AV_CODEC_CAP_HARDWARE | AV_CODEC_CAP_HYBRID))
				l_entry["hardware_accel"] = true;
			else {
				const AVCodecHWConfig* l_config_0 = avcodec_get_hw_config(l_codec, 0);
				if (l_config_0)
					l_entry["hardware_accel"] = true;
				else
					l_entry["hardware_accel"] = false;
			}
		}
		l_video_dic[l_codec->name] = l_entry;
	}

	l_dic["audio"] = l_audio_dic;
	l_dic["video"] = l_video_dic;
	return l_dic;
}

bool Renderer::is_video_codec_supported(RENDERER_VIDEO_CODEC a_codec) {
	return (const AVCodec *)avcodec_find_encoder(static_cast<AVCodecID>(a_codec));
}

bool Renderer::is_audio_codec_supported(RENDERER_AUDIO_CODEC a_codec) {
	return (const AVCodec *)avcodec_find_encoder(static_cast<AVCodecID>(a_codec));
}

bool Renderer::ready_check() {
	if (render_audio)
		return !(file_path.is_empty() || !av_codec_id_video || !av_codec_id_audio);
	else
		return !(file_path.is_empty() || !av_codec_id_video);
}

int Renderer::open() {
	if (!ready_check()) {
		UtilityFunctions::printerr("Render settings not fully setup!");
		return -1;
	}

	// Allocate output media context
	avformat_alloc_output_context2(&av_format_ctx, NULL, NULL, file_path.utf8());
	if (!av_format_ctx) {
		UtilityFunctions::print("Couldn't deduce output format from extensions: using MPEG");
		avformat_alloc_output_context2(&av_format_ctx, NULL, "mpeg", file_path.utf8());
	}
	if (!av_format_ctx) {
		UtilityFunctions::printerr("Couldn't allocate av format context!");
		return -2;
	}
	av_out_format = av_format_ctx->oformat;

	// Setting up video stream
	av_codec_video = avcodec_find_encoder(av_codec_id_video);
	if (!av_codec_video) {
		UtilityFunctions::printerr("Video codec not found!");
		return -3;
	}

	av_codec_ctx_video = avcodec_alloc_context3(av_codec_video);
	if (!av_codec_ctx_video) {
		UtilityFunctions::printerr("Couldn't allocate video codec context!");
		return -3;
	}

	av_stream_video = avformat_new_stream(av_format_ctx, NULL);
	if (!av_stream_video) {
		UtilityFunctions::printerr("Couldn't create stream!");
		return -7;
	}

	av_codec_ctx_video->codec_id = av_codec_id_video;
	av_codec_ctx_video->bit_rate = bit_rate;
	av_codec_ctx_video->pix_fmt = AV_PIX_FMT_YUV420P;
	av_codec_ctx_video->width = resolution.x;
	av_codec_ctx_video->height = resolution.y;
	av_codec_ctx_video->time_base = (AVRational){1, (int)framerate};
	av_codec_ctx_video->framerate = (AVRational){(int)framerate, 1};
	av_codec_ctx_video->gop_size = gop_size;
	av_codec_ctx_video->max_b_frames = 1;

	// Setting up audio stream
	if (render_audio) {
		av_codec_audio = avcodec_find_encoder(av_codec_id_audio);
		if (!av_codec_audio) {
			UtilityFunctions::printerr("Audio codec not found!");
			return -4;
		}

		av_codec_ctx_audio = avcodec_alloc_context3(av_codec_audio);
		if (!av_codec_ctx_audio) {
			UtilityFunctions::printerr("Couldn't allocate audio codec context!");
			return -4;
		}

		av_packet_audio = av_packet_alloc();
		if (!av_packet_audio) {
			UtilityFunctions::printerr("Couldn't allocate packet!");
			return -7;
		}

		av_stream_audio = avformat_new_stream(av_format_ctx, NULL);
		if (!av_stream_audio) {
			UtilityFunctions::printerr("Couldn't create new stream!");
			return -6;
		}

		av_codec_ctx_audio->sample_fmt = (*av_codec_audio).sample_fmts ? (*av_codec_audio).sample_fmts[0] : AV_SAMPLE_FMT_FLTP;
		av_codec_ctx_audio->bit_rate = 64000;
		av_codec_ctx_audio->sample_rate = 44100;
		if ((*av_codec_audio).supported_samplerates) {
			av_codec_ctx_audio->sample_rate = (*av_codec_audio).supported_samplerates[0];
			for (i = 0; (*av_codec_audio).supported_samplerates[i]; i++) {
				if ((*av_codec_audio).supported_samplerates[i] == 44100)
					av_codec_ctx_audio->sample_rate = 44100;
			}
		}
		av_channel_layout_copy(&av_codec_ctx_audio->ch_layout, &(chlayout_stereo));
	}

	// Some formats want stream headers separated
	if (av_format_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
		av_codec_ctx_video->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
		if (render_audio)
			av_codec_ctx_audio->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
	}

	// Encoding options for different codecs
	if (av_codec_video->id == AV_CODEC_ID_H264)
		av_opt_set(av_codec_ctx_video->priv_data, "preset", h264_preset.utf8(), 0);


	// Opening the video encoder codec
	response = avcodec_open2(av_codec_ctx_video, av_codec_video, NULL);
	if (response < 0) {
		UtilityFunctions::printerr("Couldn't open video codec!", get_av_error());
		return -3;
	}

	// Enable multi-threading for encoding - Video
	av_codec_ctx_video->thread_count = 0;
	if (av_codec_video->capabilities & AV_CODEC_CAP_FRAME_THREADS)
		av_codec_ctx_video->thread_type = FF_THREAD_FRAME;
	else if (av_codec_video->capabilities & AV_CODEC_CAP_SLICE_THREADS)
		av_codec_ctx_video->thread_type = FF_THREAD_SLICE;
	else
		av_codec_ctx_video->thread_count = 1; // Don't use multithreading

	av_packet_video = av_packet_alloc();
	if (!av_packet_video) {
		UtilityFunctions::printerr("Couldn't allocate packet!");
		return -7;
	}
	av_frame_video = av_frame_alloc();
	if (!av_frame_video) {
		UtilityFunctions::printerr("Couldn't allocate frame!");
		return -8;
	}
	av_frame_video->format = AV_PIX_FMT_YUV420P;
	av_frame_video->width = resolution.x;
	av_frame_video->height = resolution.y;
	if (av_frame_get_buffer(av_frame_video, 0)) {
		UtilityFunctions::printerr("Couldn't allocate frame data!");
		return -8;
	}

	sws_ctx = sws_getContext(
		av_frame_video->width, av_frame_video->height, AV_PIX_FMT_RGBA, // 24, //AV_PIX_FMT_RGBA
		av_frame_video->width, av_frame_video->height, AV_PIX_FMT_YUV420P,
		SWS_BILINEAR, NULL, NULL, NULL); // TODO: Option to change SWS_BILINEAR
	if (!sws_ctx) {
		UtilityFunctions::printerr("Couldn't get sws context!");
		return -9;
	}

	// Copy video stream params to muxer
	if (avcodec_parameters_from_context(av_stream_video->codecpar, av_codec_ctx_video) < 0) {
		UtilityFunctions::printerr("Couldn't copy video stream params!");
		return -5;
	}

	if (render_audio) {
		// Opening the audio encoder codec
		response = avcodec_open2(av_codec_ctx_audio, av_codec_audio, NULL);
		if (response < 0) {
			UtilityFunctions::printerr("Couldn't open audio codec!", get_av_error());
			return -4;
		}

		// Enable multi-threading for encoding - Audio
		// set codec to automatically determine how many threads suits best for the
		// decoding job
		av_codec_ctx_audio->thread_count = 0;
		if (av_codec_audio->capabilities & AV_CODEC_CAP_FRAME_THREADS)
			av_codec_ctx_audio->thread_type = FF_THREAD_FRAME;
		else if (av_codec_audio->capabilities & AV_CODEC_CAP_SLICE_THREADS)
			av_codec_ctx_audio->thread_type = FF_THREAD_SLICE;
		else
			av_codec_ctx_audio->thread_count = 1; // don't use multithreading

		// Copy audio stream params to muxer
		if (avcodec_parameters_from_context(av_stream_audio->codecpar, av_codec_ctx_audio)) {
			UtilityFunctions::printerr("Couldn't copy audio stream params!");
			return -4;
		}

		// Creating resampler
		swr_ctx = swr_alloc();
		if (!swr_ctx) {
			UtilityFunctions::printerr("Couldn't allocate swr!");
			return -10;
		}

		// Setting audio options
		av_opt_set_chlayout(swr_ctx, "in_chlayout", &av_codec_ctx_audio->ch_layout, 0);
		av_opt_set_int(swr_ctx, "in_sample_rate", av_codec_ctx_audio->sample_rate, 0);
		av_opt_set_sample_fmt(swr_ctx, "in_sample_fmt", AV_SAMPLE_FMT_S16, 0);
		av_opt_set_chlayout(swr_ctx, "out_chlayout", &av_codec_ctx_audio->ch_layout, 0);
		av_opt_set_int(swr_ctx, "out_sample_rate", av_codec_ctx_audio->sample_rate, 0);
		av_opt_set_sample_fmt(swr_ctx, "out_sample_fmt", av_codec_ctx_audio->sample_fmt, 0);

		// Initialize resampling context
		if ((response = swr_init(swr_ctx)) < 0) {
			UtilityFunctions::printerr("Failed to initialize resampling context!");
			return -10;
		}
	}

	av_dump_format(av_format_ctx, 0, file_path.utf8(), 1);

	// Open output file if needed
	if (!(av_out_format->flags & AVFMT_NOFILE)) {
		response = avio_open(&av_format_ctx->pb, file_path.utf8(), AVIO_FLAG_WRITE);
		if (response < 0) {
			UtilityFunctions::printerr("Couldn't open output file!", get_av_error());
			return -11;
		}
	}

	// Write stream header - if any
	response = avformat_write_header(av_format_ctx, NULL);
	if (response < 0) {
		UtilityFunctions::printerr("Error when writing header!", get_av_error());
		return -12;
	}
	av_packet_free(&av_packet_video);
	i = 0; // Reset i for send_frame
	return OK;
}

int Renderer::send_frame(PackedByteArray a_y, PackedByteArray a_u, PackedByteArray a_v) {
	if (!av_codec_ctx_video) {
		UtilityFunctions::printerr("Video codec isn't open!");
		return -1;
	}

	if (av_frame_make_writable(av_frame_video) < 0) {
		UtilityFunctions::printerr("Video frame is not writeable!");
		return -2;
	}

	av_frame_video->data[0] = a_y.ptrw();
	av_frame_video->data[1] = a_u.ptrw();
	av_frame_video->data[2] = a_v.ptrw();

	av_frame_video->linesize[0] = resolution.x;
	av_frame_video->linesize[1] = resolution.x / 2;
	av_frame_video->linesize[2] = resolution.x / 2;

	av_frame_video->pts = i;
	i++;

	// Adding frame
	response = avcodec_send_frame(av_codec_ctx_video, av_frame_video);
	if (response < 0) {
		UtilityFunctions::printerr("Error sending video frame!", get_av_error());
		return -3;
	}

	av_packet_video = av_packet_alloc();

	while (response >= 0) {
		response = avcodec_receive_packet(av_codec_ctx_video, av_packet_video);
		if (response == AVERROR(EAGAIN) || response == AVERROR_EOF)
			break;
		else if (response < 0) {
			UtilityFunctions::printerr("Error encoding video frame!", get_av_error());
			response = -1;
			goto failed;
		}

		// Rescale output packet timestamp values from codec to stream timebase
		av_packet_video->stream_index = av_stream_video->index;
		av_packet_rescale_ts(av_packet_video, av_codec_ctx_video->time_base, av_stream_video->time_base);

		// Write the frame to file
		response = av_interleaved_write_frame(av_format_ctx, av_packet_video);
		// Packet is now blank as function above takes ownership of it, so no unreferencing is necessary.
		// When using av_write_frame this would be needed.
		if (response < 0) {
			UtilityFunctions::printerr("Error whilst writing output packet!", get_av_error());
			response = -1;
			goto failed;
		}

		av_packet_unref(av_packet_video);
	}

	av_packet_free(&av_packet_video);
	return 0;

failed:
	av_packet_free(&av_packet_video);
	return response;
}

int Renderer::send_audio(Ref<AudioStreamWAV> a_wav) {
	if (render_audio) {
		UtilityFunctions::printerr("Audio not enabled for this renderer!");
		return -1;
	} else if (!av_codec_ctx_audio) {
		UtilityFunctions::printerr("Audio codec isn't open!");
		return -2;
	}

	i = 0;
	// LOOP over data
	// uint16_t *l_data = (int16_t*)av_frame_audio->data[0];
	// for (int j = 0; j < av_frame_audio->nb_samples; j++) {
	//		l_v = (int)(sin
	// }
	// av_frame_pts = i;
	// i += av_frame_audio->nb_samples;
	// while loop end to repeat

	return OK;
}

int Renderer::close() {
	if (av_codec_ctx_video == nullptr)
		return -1;

	av_write_trailer(av_format_ctx);

	avcodec_free_context(&av_codec_ctx_video);
	av_frame_free(&av_frame_video);
	av_packet_free(&av_packet_video);
	sws_freeContext(sws_ctx);

	if (render_audio) {
		avcodec_free_context(&av_codec_ctx_audio);
		av_frame_free(&av_frame_audio);
		av_packet_free(&av_packet_audio);
		swr_free(&swr_ctx);
	}

	if (!(av_out_format->flags & AVFMT_NOFILE))
		avio_closep(&av_format_ctx->pb);
	avformat_free_context(av_format_ctx);

	return OK;
}
