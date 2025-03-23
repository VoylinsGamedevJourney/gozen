#include "video_meta.hpp"



bool VideoMeta::load_meta(String a_path) {
	const AVCodec *av_codec_video;

	path = a_path.utf8();

	// Allocate video file context
	av_format_ctx = avformat_alloc_context();
	if (!av_format_ctx || avformat_open_input(&av_format_ctx, path.c_str(), NULL, NULL)) {
		close();
		return _log_err("Couldn't open video");
	}

	// Getting the video stream
	avformat_find_stream_info(av_format_ctx, NULL);

	for (int i = 0; i < av_format_ctx->nb_streams; i++) {
		AVCodecParameters *av_codec_params = av_format_ctx->streams[i]->codecpar;

		if (!avcodec_find_decoder(av_codec_params->codec_id)) {
			av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
			continue;
		} else if (av_codec_params->codec_type == AVMEDIA_TYPE_VIDEO) {
			av_stream_video = av_format_ctx->streams[i];
			resolution.x = av_codec_params->width;
			resolution.y = av_codec_params->height;
			color_profile = av_codec_params->color_primaries;

			AVDictionaryEntry *l_rotate_tag = av_dict_get(av_stream_video->metadata, "rotate", nullptr, 0);
			rotation = l_rotate_tag ? atoi(l_rotate_tag->value) : 0;
			if (rotation == 0) { // Check modern rotation detecting
				for (int i = 0; i < av_stream_video->codecpar->nb_coded_side_data; ++i) {
					const AVPacketSideData *side_data = &av_stream_video->codecpar->coded_side_data[i];

					if (side_data->type == AV_PKT_DATA_DISPLAYMATRIX && side_data->size == sizeof(int32_t) * 9)
						rotation = av_display_rotation_get(reinterpret_cast<const int32_t *>(side_data->data));
				}
			}

			break;
		}
		av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
	}

	// Setup Decoder codec context
	av_codec_video = avcodec_find_decoder(av_stream_video->codecpar->codec_id);

	if (!av_codec_video) {
		close();
		return _log_err("Couldn't find decoder");
	}

	// Allocate codec context for decoder
	av_codec_ctx_video = avcodec_alloc_context3(av_codec_video);
	if (av_codec_ctx_video == NULL) {
		close();
		return _log_err("Couldn't alloc codec");
	}

	// Copying parameters
	if (avcodec_parameters_to_context(av_codec_ctx_video, av_stream_video->codecpar)) {
		close();
		return _log_err("Failed to init codec");
	}

	FFmpeg::enable_multithreading(av_codec_ctx_video, av_codec_video);
	
	// Open codec - Video
	if (avcodec_open2(av_codec_ctx_video, av_codec_video, NULL)) {
		close();
		return _log_err("Failed to open codec");
	}

	float l_aspect_ratio = av_q2d(av_stream_video->codecpar->sample_aspect_ratio);
	if (l_aspect_ratio > 1.0)
		resolution.x = static_cast<int>(std::round(resolution.x * l_aspect_ratio));

	pixel_format = av_get_pix_fmt_name(av_codec_ctx_video->pix_fmt);

	if (av_stream_video->start_time != AV_NOPTS_VALUE)
		start_time_video = (int64_t)(av_stream_video->start_time * stream_time_base_video);
	else
		start_time_video = 0;

	// Getting some data out of first frame
	if (!(av_packet = av_packet_alloc()) || !(av_frame = av_frame_alloc())) {
		close();
		return _log_err("Out of memory");
	}

	avcodec_flush_buffers(av_codec_ctx_video);
	bool l_duration_from_bitrate = av_format_ctx->duration_estimation_method == AVFMT_DURATION_FROM_BITRATE;
	if (l_duration_from_bitrate) {
		close();
		return _log_err("Invalid video");
	}

	if ((response = _seek_frame(0)) < 0) {
		FFmpeg::print_av_error("Seeking to beginning error: ", response);
		close();
		return false;
	}

	if ((response = FFmpeg::get_frame(av_format_ctx, av_codec_ctx_video, av_stream_video->index, av_frame, av_packet))) {
		FFmpeg::print_av_error("Something went wrong getting first frame!", response);
		close();
		return false;
	}
	
	// Checking for interlacing and what type of interlacing
	if (av_frame->flags & AV_FRAME_FLAG_INTERLACED)
		interlaced = av_frame->flags & AV_FRAME_FLAG_TOP_FIELD_FIRST ? 1 : 2;

	// Checking color range
	full_color_range = av_frame->color_range == AVCOL_RANGE_JPEG;

	// Getting frame rate
	framerate = av_q2d(av_guess_frame_rate(av_format_ctx, av_stream_video, av_frame));
	if (framerate <= 0) {
		close();
		return _log_err("Invalid framerate");
	}

	// Setting variables
	average_frame_duration = 10000000.0 / framerate;								// eg. 1 sec / 25 fps = 400.000 ticks (40ms)
	stream_time_base_video = av_q2d(av_stream_video->time_base) * 1000.0 * 10000.0; // Converting timebase to ticks

	// Preparing the data array's
	y_data.resize(av_frame->linesize[0] * resolution.y);

	if (av_frame->format == AV_PIX_FMT_YUV420P || av_frame->format == AV_PIX_FMT_YUVJ420P) {
		u_data.resize(av_frame->linesize[1] * (resolution.y / 2));
		v_data.resize(av_frame->linesize[2] * (resolution.y / 2));

		padding = av_frame->linesize[0] - resolution.x;
	} else {
		_log("Enabling SWS due to foreign format");
		using_sws = true;

		sws_ctx = sws_getContext(
						resolution.x, resolution.y, av_codec_ctx_video->pix_fmt,
						resolution.x, resolution.y, AV_PIX_FMT_YUV420P,
						SWS_BICUBIC, NULL, NULL, NULL);

		av_sws_frame = av_frame_alloc();
		sws_scale_frame(sws_ctx, av_sws_frame, av_frame);

		u_data.resize(av_sws_frame->linesize[1] * (resolution.y / 2));
		v_data.resize(av_sws_frame->linesize[2] * (resolution.y / 2));
		padding = av_sws_frame->linesize[0] - resolution.x;

		av_frame_unref(av_sws_frame);
	}

	// Checking second frame
	if ((response = FFmpeg::get_frame(av_format_ctx, av_codec_ctx_video, av_stream_video->index, av_frame, av_packet)))
		FFmpeg::print_av_error("Something went wrong getting second frame!", response);

	duration = av_format_ctx->duration;

	if (av_stream_video->duration == AV_NOPTS_VALUE || l_duration_from_bitrate) {
		if (duration == AV_NOPTS_VALUE || l_duration_from_bitrate) {
			close();
			return _log_err("Invalid video");
		} else {
			AVRational l_temp_rational = AVRational{1, AV_TIME_BASE};

			if (l_temp_rational.num != av_stream_video->time_base.num || l_temp_rational.num != av_stream_video->time_base.num)
				duration = std::ceil(static_cast<double>(duration) * av_q2d(l_temp_rational) / av_q2d(av_stream_video->time_base));
		}

		av_stream_video->duration = duration;
	}

	frame_count = (static_cast<double>(duration) / static_cast<double>(AV_TIME_BASE)) * framerate;

	if (av_packet)
		av_packet_unref(av_packet);
	if (av_frame)
		av_frame_unref(av_frame);

	response = OK;

	close();
	return OK;
}

void VideoMeta::close() {
	if (av_frame)
		av_frame_free(&av_frame);
	if (av_sws_frame)
		av_frame_free(&av_frame);
	if (av_packet)
		av_packet_free(&av_packet);

	if (av_codec_ctx_video)
		avcodec_free_context(&av_codec_ctx_video);
	if (av_format_ctx)
		avformat_close_input(&av_format_ctx);

	if (sws_ctx)
		sws_freeContext(sws_ctx);

	av_frame = nullptr;
	av_packet = nullptr;

	av_codec_ctx_video = nullptr;
	av_format_ctx = nullptr;
}

int VideoMeta::_seek_frame(int a_frame_nr) {
	avcodec_flush_buffers(av_codec_ctx_video);

	frame_timestamp = (int64_t)(a_frame_nr * average_frame_duration);
	return av_seek_frame(av_format_ctx, -1, (start_time_video + frame_timestamp) / 10, AVSEEK_FLAG_BACKWARD | AVSEEK_FLAG_FRAME);
}

