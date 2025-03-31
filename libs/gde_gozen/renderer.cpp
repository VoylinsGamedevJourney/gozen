#include "renderer.hpp"


Renderer::~Renderer() {
	close();
}

PackedStringArray Renderer::get_available_codecs(int codec_id) {
	PackedStringArray codec_data = PackedStringArray();

	const AVCodec *codec = nullptr;
	void *i = nullptr;

	while ((codec = av_codec_iterate(&i)))
		if (codec->id == codec_id && av_codec_is_encoder(codec))
			codec_data.append(codec->name);

	return codec_data;
}

bool Renderer::open() {
	if (renderer_open)
		return _log_err("Already open");
	else {
		if (path == "")
			return _log_err("No path set");
		else if (video_codec_id == AV_CODEC_ID_NONE)
			return _log_err("No video codec set");
		else if (audio_enabled && audio_codec_id == AV_CODEC_ID_NONE)
			_log("Audio codec not set, not rendering audio");
		else if (audio_enabled && audio_codec_id != AV_CODEC_ID_NONE
					&& sample_rate == -1) {
			_log("A sample rate needs to be set for audio exporting");
			audio_codec_id = AV_CODEC_ID_NONE;
		}
	}

	// Allocating output media context
	avformat_alloc_output_context2(&av_format_ctx, NULL, NULL, path.utf8());
	if (!av_format_ctx) {
		_log_err("Error creating AV Format by path extension, using MPEG");
		avformat_alloc_output_context2(
				&av_format_ctx, NULL, "mpeg", path.utf8());
	} if (!av_format_ctx)
		return _log_err("Error creating AV Format");

	av_output_format = av_format_ctx->oformat;

	// Setting up video stream
	const AVCodec *av_codec_video = avcodec_find_encoder(video_codec_id);
	if (!av_codec_video) {
		UtilityFunctions::printerr("Video codec '",
									avcodec_get_name(video_codec_id),
									"' not found!");
		return _log_err("Couldn't open video codec");
	}

	av_packet_video = av_packet_alloc();
	if (!av_packet_video)
		return _log_err("Out of memory");

	av_stream_video = avformat_new_stream(av_format_ctx, NULL);
	if (!av_stream_video)
		return _log_err("Couldn't create stream");

	av_stream_video->id = av_format_ctx->nb_streams-1;

	av_codec_ctx_video = avcodec_alloc_context3(av_codec_video);
	if (!av_codec_ctx_video)
		return _log_err("Couldn't alloc video codec");

	FFmpeg::enable_multithreading(av_codec_ctx_video, av_codec_video);

	av_codec_ctx_video->codec_id = video_codec_id;
	av_codec_ctx_video->pix_fmt = AV_PIX_FMT_YUV420P;
	// Resolution must be a multiple of two
	av_codec_ctx_video->width = resolution.x;
	av_codec_ctx_video->height = resolution.y;
	av_codec_ctx_video->time_base = AVRational{1, (int)framerate};
	av_stream_video->time_base = av_codec_ctx_video->time_base;

	av_codec_ctx_video->framerate = AVRational{(int)framerate, 1};
	av_stream_video->avg_frame_rate = av_codec_ctx_video->framerate;

	av_codec_ctx_video->gop_size = gop_size;

	if (av_codec_ctx_video->codec_id == AV_CODEC_ID_MPEG2VIDEO)
		av_codec_ctx_video->max_b_frames = b_frames <= 2 ? b_frames : 2;
	else
		av_codec_ctx_video->max_b_frames = b_frames;

	if (av_codec_ctx_video->codec_id == AV_CODEC_ID_MPEG1VIDEO)
		av_codec_ctx_video->mb_decision = 2;

	// Some formats want stream headers separated
	if (av_output_format->flags & AVFMT_GLOBALHEADER)
		av_codec_ctx_video->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;

	// Setting the CRF
	av_opt_set(av_codec_ctx_video->priv_data, "crf",
				std::to_string(crf).c_str(), 0);

	// Encoding options for different codecs
	if (av_codec_video->id == AV_CODEC_ID_H264)
		av_opt_set(av_codec_ctx_video->priv_data, "preset",
				h264_preset.c_str(), 0);

	// Opening the video encoder codec
	response = avcodec_open2(av_codec_ctx_video, av_codec_video, NULL);
	if (response < 0) {
		FFmpeg::print_av_error("Couldn't open video codec context!", response);
		return _log_err("Couldn't open video codec");
	}

	av_frame_video = av_frame_alloc();
	if (!av_frame_video)
		return _log_err("Out of memory");

	av_frame_video->format = av_codec_ctx_video->pix_fmt;
	av_frame_video->width = resolution.x;
	av_frame_video->height = resolution.y;

	if (av_frame_get_buffer(av_frame_video, 0))
		return _log_err("Couldn't get frame buffer");

	// Copy video stream params to muxer
	if (avcodec_parameters_from_context(av_stream_video->codecpar,
										av_codec_ctx_video) < 0) {
		return _log_err("Couldn't copy stream params");
	}

	if (audio_enabled) {
		const AVCodec *av_codec_audio = avcodec_find_encoder(audio_codec_id);
		if (!av_codec_audio) {
			UtilityFunctions::printerr("Audio codec '",
										avcodec_get_name(audio_codec_id),
										"' not found!");
			return _log_err("Couldn't find audio encoder");
		}

		av_packet_audio = av_packet_alloc();
		if (!av_packet_audio)
			return _log_err("Out of memory");

		av_stream_audio = avformat_new_stream(av_format_ctx, NULL);
		if (!av_stream_audio)
			return _log_err("Couldn't create stream");

		av_stream_audio->id = av_format_ctx->nb_streams-1;

		av_codec_ctx_audio = avcodec_alloc_context3(av_codec_audio);
		if (!av_codec_ctx_audio)
			return _log_err("Couln't alloc audio codec");

		FFmpeg::enable_multithreading(av_codec_ctx_audio, av_codec_audio);

		av_codec_ctx_audio->bit_rate = 128000;
		av_codec_ctx_audio->sample_fmt = av_codec_audio->sample_fmts[0];
		av_codec_ctx_audio->sample_rate = sample_rate;

		if (av_codec_audio->supported_samplerates) {
			for (int i = 0; av_codec_audio->supported_samplerates[i]; i++) {
				if (av_codec_audio->supported_samplerates[i] == 48000) {
					av_codec_ctx_audio->sample_rate = 48000;
					break;
				}
			}
		}
		av_codec_ctx_audio->time_base = AVRational{
				1, av_codec_ctx_audio->sample_rate};
		av_stream_audio->time_base = av_codec_ctx_audio->time_base;

		AVChannelLayout ch_layout = AV_CHANNEL_LAYOUT_STEREO;
		av_channel_layout_copy(&av_codec_ctx_audio->ch_layout, &(ch_layout));

		// Opening the audio encoder codec
		response = avcodec_open2(av_codec_ctx_audio, av_codec_audio, NULL);
		if (response < 0) {
			FFmpeg::print_av_error("Couldn't open audio codec!", response);
			return false;
		}

		// Copy audio stream params to muxer
		if (avcodec_parameters_from_context(av_stream_audio->codecpar,
											av_codec_ctx_audio))
			return _log_err("Couldn't copy stream params");

		if (av_output_format->flags & AVFMT_GLOBALHEADER)
			av_codec_ctx_audio->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
	}

	av_dump_format(av_format_ctx, 0, path.utf8(), 1);

	// Open output file if needed
	if (!(av_output_format->flags & AVFMT_NOFILE)) {
		response = avio_open(&av_format_ctx->pb, path.utf8(), AVIO_FLAG_WRITE);
		if (response < 0) {
			FFmpeg::print_av_error("Couldn't open output file!", response);
			return _log_err("Couldn't open video");
		}
	}

	// Write stream header - if any
	response = avformat_write_header(av_format_ctx, NULL);
	if (response < 0) {
		FFmpeg::print_av_error("Error when writing header!", response);
		return _log_err("Couldn't write header");
	}

	// Setting up SWS
	sws_ctx = sws_getContext(
		av_frame_video->width, av_frame_video->height, AV_PIX_FMT_RGBA,
		av_frame_video->width, av_frame_video->height, AV_PIX_FMT_YUV420P,
		sws_quality, NULL, NULL, NULL);
	if (!sws_ctx)
		return _log_err("Couldn't create SWS");

	frame_nr = 0;
	renderer_open = true;
	return OK;
}

bool Renderer::send_frame(Ref<Image> frame_image) {
	if (!renderer_open)
		return _log_err("Not open");
	else if (audio_enabled && audio_codec_id != AV_CODEC_ID_NONE
			&& !audio_added)
		return _log_err("Audio hasn't been send");
	else if (av_frame_make_writable(av_frame_video) < 0)
		return _log_err("Frame not writable");

	uint8_t *src_data[4] = { frame_image->get_data().ptrw(), NULL, NULL, NULL};
	int src_linesize[4] = { av_frame_video->width * 4, 0, 0, 0 };

	response = sws_scale(
			sws_ctx,
			src_data, src_linesize, 0, av_frame_video->height,
			av_frame_video->data, av_frame_video->linesize);
	if (response < 0) {
		FFmpeg::print_av_error("Scaling frame data failed!", response);
		return false;
	}

	av_frame_video->pts = frame_nr;
	frame_nr++;

	// Adding frame
	response = avcodec_send_frame(av_codec_ctx_video, av_frame_video);
	if (response < 0) {
		FFmpeg::print_av_error("Error sending video frame!", response);
		return false;
	}

	av_packet_video = av_packet_alloc();

	while (response >= 0) {
		response = avcodec_receive_packet(av_codec_ctx_video, av_packet_video);
		if (response == AVERROR(EAGAIN) || response == AVERROR_EOF)
			break;
		else if (response < 0) {
			FFmpeg::print_av_error("Error encoding video frame!", response);
			av_packet_free(&av_packet_video);
			return false;
		}

		// Rescale output packet timestamp values from codec to stream timebase
		av_packet_video->stream_index = av_stream_video->index;
		av_packet_rescale_ts(av_packet_video, av_codec_ctx_video->time_base,
							 av_stream_video->time_base);

		// Write the frame to file
		response = av_interleaved_write_frame(av_format_ctx, av_packet_video);
		if (response < 0) {
			FFmpeg::print_av_error("Error writing output packet!", response);
			response = -1;
			av_packet_free(&av_packet_video);
			return false;
		}

		av_packet_unref(av_packet_video);
	}

	av_packet_free(&av_packet_video);
	return true;
}

bool Renderer::send_audio(PackedByteArray wav_data) {
	if (!renderer_open)
		return _log_err("Not open");
	else if (audio_codec_id == AV_CODEC_ID_NONE)
		return _log_err("Audio not enabled");
	else if (audio_added)
		return _log_err("Audio already send");
	
	const uint8_t *input_data = wav_data.ptr();
	SwrContext *swr_ctx = nullptr;
	AVChannelLayout ch_layout = AV_CHANNEL_LAYOUT_STEREO;

	// Allocate and setup SWR
	swr_alloc_set_opts2(&swr_ctx,
			&ch_layout,av_codec_ctx_audio->sample_fmt,
			av_codec_ctx_audio->sample_rate,
			&ch_layout, AV_SAMPLE_FMT_S16, sample_rate, 0, NULL);
	if (!swr_ctx || swr_init(swr_ctx) < 0) {
		swr_free(&swr_ctx); // Godot crashes anyway when SWR can't be created.
		return _log_err("Couldn't create SWR");
	}

	// Allocate a buffer for the output in the target format
	AVFrame *frame_out = av_frame_alloc();
	if (!frame_out) {
		swr_free(&swr_ctx);
		return _log_err("Out of memory");
	}

	frame_out->ch_layout = av_codec_ctx_audio->ch_layout;
	frame_out->format = av_codec_ctx_audio->sample_fmt;
	frame_out->sample_rate = av_codec_ctx_audio->sample_rate;
	frame_out->nb_samples = av_codec_ctx_audio->frame_size;

	av_frame_get_buffer(frame_out, 0);

	av_packet_audio = av_packet_alloc();
	if (!av_packet_audio) {
		av_frame_free(&frame_out);
		swr_free(&swr_ctx);
		return _log_err("Out of memory");
	}

	int bytes_per_sample = av_get_bytes_per_sample(AV_SAMPLE_FMT_S16) * 2;
	int remaining_samples = wav_data.size() / bytes_per_sample;
	int64_t pts = 0;

	while (remaining_samples > 0) {
		int samples_to_convert = FFMIN(remaining_samples,
									   av_codec_ctx_audio->frame_size);
		
		// Resample the data 
		int converted_samples = swr_convert(swr_ctx,
				frame_out->data, frame_out->nb_samples,
				&input_data, samples_to_convert);

		if (converted_samples < 0) {
			av_frame_free(&frame_out);
			swr_free(&swr_ctx);
			return _log_err("Couldn't resample");
		}

		if (converted_samples > 0) {
			frame_out->nb_samples = converted_samples;
			frame_out->pts = pts;
			pts += converted_samples;

			// Send audio frame to the encoder
			response = avcodec_send_frame(av_codec_ctx_audio, frame_out);
			if (response < 0) {
				FFmpeg::print_av_error("Error sending audio frame!", response);
				av_frame_free(&frame_out);
				swr_free(&swr_ctx);
				av_packet_free(&av_packet_audio);
				return false;
			}

			while ((response = avcodec_receive_packet(av_codec_ctx_audio,
													  av_packet_audio)) >= 0) {
				// Rescale packet timestamp if necessary
				av_packet_audio->stream_index = av_stream_audio->index;
				av_packet_rescale_ts(
						av_packet_audio,
						av_codec_ctx_audio->time_base,
						av_stream_audio->time_base);

				response = av_interleaved_write_frame(av_format_ctx,
													  av_packet_audio);
				if (response < 0) {
					FFmpeg::print_av_error("Error writing audio packet!",
								response);
					av_frame_free(&frame_out);
					swr_free(&swr_ctx);
					av_packet_free(&av_packet_audio);
					return false;
				}
				av_packet_unref(av_packet_audio);
			}
		}

		remaining_samples -= samples_to_convert;
		input_data += samples_to_convert * bytes_per_sample;
	}

	// Flush remaining samples
	while (true) {
		int converted_samples = swr_convert(swr_ctx,
				frame_out->data, frame_out->nb_samples,
				nullptr, 0);
		if (converted_samples <= 0) break;

		frame_out->nb_samples = converted_samples;
		frame_out->pts = pts;
		pts += converted_samples;

		int response = avcodec_send_frame(av_codec_ctx_audio, frame_out);
		if (converted_samples <= 0) break;

		while ((response = avcodec_receive_packet(av_codec_ctx_audio,
												  av_packet_audio)) >= 0) {
			av_packet_audio->stream_index = av_stream_audio->index;
			av_packet_rescale_ts(
					av_packet_audio,
					av_codec_ctx_audio->time_base,
					av_stream_audio->time_base);
			av_interleaved_write_frame(av_format_ctx, av_packet_audio);
			av_packet_unref(av_packet_audio);
		}
	}

	// Flush the encoder
	avcodec_send_frame(av_codec_ctx_audio, nullptr);
	while (avcodec_receive_packet(av_codec_ctx_audio, av_packet_audio) >= 0) {
		av_packet_audio->stream_index = av_stream_audio->index;
		av_packet_rescale_ts(av_packet_audio, av_codec_ctx_audio->time_base,
							 av_stream_audio->time_base);
		av_interleaved_write_frame(av_format_ctx, av_packet_audio);
		av_packet_unref(av_packet_audio);
	}

	av_frame_free(&frame_out);
	av_packet_free(&av_packet_audio);
	swr_free(&swr_ctx);

	audio_added = true;
	return true;
}

void Renderer::close() {
	if (av_codec_ctx_video == nullptr)
		return;

	// Flush encoders before cleanup
	if (av_codec_ctx_video) {
		av_packet_video = av_packet_alloc();
		avcodec_send_frame(av_codec_ctx_video, nullptr);
		
		while (avcodec_receive_packet(
				av_codec_ctx_video, av_packet_video) >= 0)
			av_packet_unref(av_packet_video);
	}

	if (audio_enabled && av_codec_ctx_audio) {
        av_packet_audio = av_packet_alloc();
		avcodec_send_frame(av_codec_ctx_audio, nullptr);

		while (avcodec_receive_packet(
				av_codec_ctx_audio, av_packet_audio) >= 0)
			av_packet_unref(av_packet_audio);
	}

	if (av_format_ctx)
		av_write_trailer(av_format_ctx);

	// Cleanup contexts
	if (sws_ctx) {
		sws_freeContext(sws_ctx);
		sws_ctx = nullptr;
	}

	if (av_codec_ctx_video)
		avcodec_free_context(&av_codec_ctx_video);

	if (audio_enabled && av_codec_ctx_audio)
		avcodec_free_context(&av_codec_ctx_audio);

	if (av_frame_video)
		av_frame_free(&av_frame_video);

	if (av_packet_video)
		av_packet_free(&av_packet_video);

	if (audio_enabled && av_packet_audio)
		av_packet_free(&av_packet_audio);

	if (av_format_ctx) {
		if (!(av_output_format->flags & AVFMT_NOFILE))
			avio_closep(&av_format_ctx->pb);

		avformat_free_context(av_format_ctx);
		av_format_ctx = nullptr;
	}

	renderer_open = false;
	audio_added = false;
	frame_nr = 0;
}


#define BIND_STATIC_METHOD_1(method_name, param1) \
    ClassDB::bind_static_method("Renderer", \
        D_METHOD(#method_name, param1), &Renderer::method_name)

#define BIND_METHOD(method_name) \
    ClassDB::bind_method(D_METHOD(#method_name), &Renderer::method_name)

#define BIND_METHOD_1(method_name, param1) \
    ClassDB::bind_method( \
        D_METHOD(#method_name, param1), &Renderer::method_name)

#define BIND_METHOD_2(method_name, param1, param2) \
    ClassDB::bind_method( \
        D_METHOD(#method_name, param1, param2), &Renderer::method_name)


void Renderer::_bind_methods() {
	/* VIDEO CODEC ENUMS */
	BIND_ENUM_CONSTANT(V_HEVC);
	BIND_ENUM_CONSTANT(V_H264);
	BIND_ENUM_CONSTANT(V_MPEG4);
	BIND_ENUM_CONSTANT(V_MPEG2);
	BIND_ENUM_CONSTANT(V_MPEG1);
	BIND_ENUM_CONSTANT(V_MJPEG);
	BIND_ENUM_CONSTANT(V_WEBP);
	BIND_ENUM_CONSTANT(V_AV1);
	BIND_ENUM_CONSTANT(V_VP9);
	BIND_ENUM_CONSTANT(V_VP8);
	BIND_ENUM_CONSTANT(V_AMV);
	BIND_ENUM_CONSTANT(V_GIF);
	BIND_ENUM_CONSTANT(V_THEORA);
	BIND_ENUM_CONSTANT(V_DNXHD);
	BIND_ENUM_CONSTANT(V_PRORES);
	BIND_ENUM_CONSTANT(V_RAWVIDEO);
	BIND_ENUM_CONSTANT(V_NONE);

	/* AUDIO CODEC ENUMS */
	BIND_ENUM_CONSTANT(A_WAV);
	BIND_ENUM_CONSTANT(A_MP3);
	BIND_ENUM_CONSTANT(A_PCM);
	BIND_ENUM_CONSTANT(A_AAC);
	BIND_ENUM_CONSTANT(A_OPUS);
	BIND_ENUM_CONSTANT(A_VORBIS);
	BIND_ENUM_CONSTANT(A_FLAC);
	BIND_ENUM_CONSTANT(A_NONE);

	/* H264 PRESETS */
	BIND_ENUM_CONSTANT(H264_PRESET_ULTRAFAST);
	BIND_ENUM_CONSTANT(H264_PRESET_SUPERFAST);
	BIND_ENUM_CONSTANT(H264_PRESET_VERYFAST);
	BIND_ENUM_CONSTANT(H264_PRESET_FASTER);
	BIND_ENUM_CONSTANT(H264_PRESET_FAST);
	BIND_ENUM_CONSTANT(H264_PRESET_MEDIUM);
	BIND_ENUM_CONSTANT(H264_PRESET_SLOW);
	BIND_ENUM_CONSTANT(H264_PRESET_SLOWER);
	BIND_ENUM_CONSTANT(H264_PRESET_VERYSLOW);

	/* SWS QUALITY */
	BIND_ENUM_CONSTANT(SWS_QUALITY_FAST_BILINEAR);
	BIND_ENUM_CONSTANT(SWS_QUALITY_BILINEAR);
	BIND_ENUM_CONSTANT(SWS_QUALITY_BICUBIC);


	BIND_STATIC_METHOD_1(get_available_codecs, "codec_id");

	BIND_METHOD(open);
	BIND_METHOD(is_open);

	
	BIND_METHOD_1(send_frame, "frame_image");
	BIND_METHOD_1(send_audio, "wav_data");

	BIND_METHOD(close);

	BIND_METHOD(enable_debug);
	BIND_METHOD(disable_debug);
	BIND_METHOD(get_debug);

	BIND_METHOD_1(set_video_codec_id, "codec_id");
	BIND_METHOD(get_video_codec_id);

	BIND_METHOD_1(set_audio_codec_id, "codec_id");
	BIND_METHOD(get_audio_codec_id);

	BIND_METHOD_1(set_path, "file_path");
	BIND_METHOD(get_path);

	BIND_METHOD_1(set_resolution, "video_resolution");
	BIND_METHOD(get_resolution);

	BIND_METHOD_1(set_framerate, "video_framerate");
	BIND_METHOD(get_framerate);

	BIND_METHOD_1(set_crf, "video_crf");
	BIND_METHOD(get_crf);

	BIND_METHOD_1(set_gop_size, "video_gop_size");
	BIND_METHOD(get_gop_size);

	BIND_METHOD_1(set_sample_rate, "value");
	BIND_METHOD(get_sample_rate);

	BIND_METHOD_1(set_sws_quality, "value");
	BIND_METHOD(get_sws_quality);

	BIND_METHOD_1(set_b_frames, "value");
	BIND_METHOD(get_b_frames);

	BIND_METHOD(enable_audio);
	BIND_METHOD(disable_audio);

	BIND_METHOD_1(set_h264_preset, "value");
	BIND_METHOD(get_h264_preset);

	BIND_METHOD(configure_for_high_quality);

	BIND_METHOD(configure_for_youtube_hq);
	BIND_METHOD(configure_for_youtube);

	BIND_METHOD(configure_for_av1);
	BIND_METHOD(configure_for_vp9);
	BIND_METHOD(configure_for_vp8);

	BIND_METHOD(configure_for_hq_archiving_flac);
	BIND_METHOD(configure_for_hq_archiving_aac);

	BIND_METHOD(configure_for_older_devices);
}

