#include "video.hpp"


bool Video::open(String video_path) {
	if (loaded)
		return _log_err("Already open");

	Vector2i resolution = Vector2i(0, 0);

	// Allocate video file context
	AVFormatContext* temp_format_ctx = nullptr;
	if (avformat_open_input(&temp_format_ctx, video_path.utf8(), NULL, NULL)) {
		close();
		return _log_err("Couldn't open video");
	}

	av_format_ctx = make_unique_ffmpeg<AVFormatContext, AVFormatCtxInputDeleter>(
			temp_format_ctx);

	// Getting the video stream
	avformat_find_stream_info(av_format_ctx.get(), NULL);

	for (int i = 0; i < av_format_ctx->nb_streams; i++) {
		AVCodecParameters *av_codec_params =
				av_format_ctx->streams[i]->codecpar;

		if (!avcodec_find_decoder(av_codec_params->codec_id)) {
			av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
			continue;
		} else if (av_codec_params->codec_type == AVMEDIA_TYPE_VIDEO) {
			av_stream = av_format_ctx->streams[i];
			resolution.x = av_codec_params->width;
			resolution.y = av_codec_params->height;
			break;
		}
		av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
	}

	// Setup Decoder codec context
	const AVCodec *av_codec = avcodec_find_decoder(
			av_stream->codecpar->codec_id);
	if (!av_codec) {
		close();
		return _log_err("Couldn't find decoder");
	}

	av_codec_ctx = make_unique_ffmpeg<AVCodecContext, AVCodecCtxDeleter>(
			avcodec_alloc_context3(av_codec));
	if (!av_codec_ctx) {
		close();
		return _log_err("Couldn't alloc codec");
	}
	
	// Copying parameters
	if (avcodec_parameters_to_context(
			av_codec_ctx.get(), av_stream->codecpar)) {
		close();
		return _log_err("Failed to init codec");
	}

	FFmpeg::enable_multithreading(av_codec_ctx.get(), av_codec);
	
	// Open codec - Video
	if (avcodec_open2(av_codec_ctx.get(), av_codec, NULL)) {
		close();
		return _log_err("Failed to open codec");
	}

	float aspect_ratio = av_q2d(av_stream->codecpar->sample_aspect_ratio);
	if (aspect_ratio > 1.0)
		resolution.x = static_cast<int>(
				std::round(resolution.x * aspect_ratio));

	if (av_stream->start_time != AV_NOPTS_VALUE)
		start_time_video = (int64_t)(av_stream->start_time * stream_time_base_video);
	else
		start_time_video = 0;

	// Getting some data out of first frame
	av_packet = make_unique_avpacket();
	av_frame = make_unique_avframe();
	if (!av_packet || !av_frame) {
		close();
		return _log_err("Couldn't create frame/packet");
	}

	avcodec_flush_buffers(av_codec_ctx.get());
	bool duration_from_bitrate = av_format_ctx->duration_estimation_method == AVFMT_DURATION_FROM_BITRATE;
	if (duration_from_bitrate) {
		close();
		return _log_err("Invalid video");
	}

	if ((response = _seek_frame(0)) < 0) {
		FFmpeg::print_av_error("Seeking to beginning error: ", response);
		close();
		return false;
	}

	if ((response = FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(),
						 av_stream->index, av_frame.get(), av_packet.get()))) {
		FFmpeg::print_av_error("Something went wrong getting first frame!", response);
		close();
		return false;
	}

	// Getting frame rate
	double framerate = av_q2d(av_guess_frame_rate(av_format_ctx.get(), av_stream, av_frame.get()));
	if (framerate <= 0) {
		close();
		return _log_err("Invalid framerate");
	}

	// Setting variables
	average_frame_duration = 10000000.0 / framerate;								// eg. 1 sec / 25 fps = 400.000 ticks (40ms)
	stream_time_base_video = av_q2d(av_stream->time_base) * 1000.0 * 10000.0; // Converting timebase to ticks

	// Preparing the data array's
	y_data.resize(av_frame->linesize[0] * resolution.y);

	if (av_frame->format == AV_PIX_FMT_YUV420P || av_frame->format == AV_PIX_FMT_YUVJ420P) {
		u_data.resize(av_frame->linesize[1] * (resolution.y / 2));
		v_data.resize(av_frame->linesize[2] * (resolution.y / 2));
	} else {
		_log("Enabling SWS due to foreign format");
		using_sws = true;

		sws_ctx = make_unique_ffmpeg<SwsContext, SwsCtxDeleter>(sws_getContext(
						resolution.x, resolution.y, av_codec_ctx->pix_fmt,
						resolution.x, resolution.y, AV_PIX_FMT_YUV420P,
						SWS_BICUBIC, NULL, NULL, NULL));

		av_sws_frame = make_unique_avframe();
		sws_scale_frame(sws_ctx.get(), av_sws_frame.get(), av_frame.get());

		u_data.resize(av_sws_frame->linesize[1] * (resolution.y / 2));
		v_data.resize(av_sws_frame->linesize[2] * (resolution.y / 2));
		av_frame_unref(av_sws_frame.get());
	}

	// Checking second frame
	if ((response = FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(),
								av_stream->index, av_frame.get(), av_packet.get())))
		FFmpeg::print_av_error("Something went wrong getting second frame!", response);

	duration = av_format_ctx->duration;

	if (av_stream->duration == AV_NOPTS_VALUE || duration_from_bitrate) {
		if (duration == AV_NOPTS_VALUE || duration_from_bitrate) {
			close();
			return _log_err("Invalid video");
		} else {
			AVRational temp_rational = AVRational{1, AV_TIME_BASE};

			if (temp_rational.num != av_stream->time_base.num || temp_rational.num != av_stream->time_base.num)
				duration = std::ceil(static_cast<double>(duration) * av_q2d(temp_rational) / av_q2d(av_stream->time_base));
		}

		av_stream->duration = duration;
	}

	if (av_packet)
		av_packet_unref(av_packet.get());
	if (av_frame)
		av_frame_unref(av_frame.get());

	loaded = true;
	response = OK;

	return OK;
}

void Video::close() {
	loaded = false;
	response = OK;

	av_packet.reset();
	av_frame.reset();
	av_sws_frame.reset();

	sws_ctx.reset();

	av_codec_ctx.reset();
	av_format_ctx.reset();
	av_frame = nullptr;
	av_packet = nullptr;
}

bool Video::seek_frame(int frame_nr) {
	if (!loaded)
		return _log_err("Not open");

	// Video seeking
	if ((response = _seek_frame(frame_nr)) < 0)
		return _log_err("Couldn't seek");
	
	while (true) {
		if ((response = FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(),
									av_stream->index, av_frame.get(), av_packet.get()))) {
			if (response == AVERROR_EOF) {
				_log_err("End of file reached! Going back 1 frame!");

				if ((response = _seek_frame(frame_nr--)) < 0)
					return _log_err("Couldn't seek");

				continue;
			}
			FFmpeg::print_av_error("Problem happened getting frame in seek_frame! ", response);
			response = 1;
			break;
		}

		// Get frame pts
		current_pts = av_frame->best_effort_timestamp == AV_NOPTS_VALUE ?
				av_frame->pts : av_frame->best_effort_timestamp;
		if (current_pts == AV_NOPTS_VALUE)
			continue;

		// Skip to actual requested frame
		if ((int64_t)(current_pts * stream_time_base_video) / 10000 >=
			frame_timestamp / 10000) {
			_copy_frame_data();
			break;
		}
	}

	av_frame_unref(av_frame.get());
	av_packet_unref(av_packet.get());

	return true;
}

bool Video::next_frame(bool skip_frame) {
	if (!loaded)
		return false;

	FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(),
					  av_stream->index, av_frame.get(), av_packet.get());

	if (!skip_frame)
		_copy_frame_data();

	av_frame_unref(av_frame.get());
	av_packet_unref(av_packet.get());
	
	return true;
}

void Video::_copy_frame_data() {
	if (using_sws) {
		sws_scale_frame(sws_ctx.get(), av_sws_frame.get(), av_frame.get());

		if (av_sws_frame->data[0] == nullptr) {
			_log_err("Frame is empty!");
			return;
		}

		memcpy(y_data.ptrw(), av_sws_frame->data[0], y_data.size());
		memcpy(u_data.ptrw(), av_sws_frame->data[1], u_data.size());
		memcpy(v_data.ptrw(), av_sws_frame->data[2], v_data.size());

		av_frame_unref(av_sws_frame.get());
		return;
	}

	memcpy(y_data.ptrw(), av_frame->data[0], y_data.size());
	memcpy(u_data.ptrw(), av_frame->data[1], u_data.size());
	memcpy(v_data.ptrw(), av_frame->data[2], v_data.size());
}

int Video::_seek_frame(int frame_nr) {
	avcodec_flush_buffers(av_codec_ctx.get());

	frame_timestamp = (int64_t)(frame_nr * average_frame_duration);
	return av_seek_frame(av_format_ctx.get(), -1,
						 (start_time_video + frame_timestamp) / 10,
					 	 AVSEEK_FLAG_BACKWARD | AVSEEK_FLAG_FRAME);
}


#define BIND_METHOD(method_name) \
    ClassDB::bind_method(D_METHOD(#method_name), &Video::method_name)

#define BIND_METHOD_1(method_name, param1) \
    ClassDB::bind_method( \
        D_METHOD(#method_name, param1), &Video::method_name)


void Video::_bind_methods() {
	BIND_METHOD_1(open, "video_path");

	BIND_METHOD(is_open);

	BIND_METHOD_1(seek_frame, "frame_nr");
	BIND_METHOD_1(next_frame, "skip_frame");

	BIND_METHOD(get_y_data);
	BIND_METHOD(get_u_data);
	BIND_METHOD(get_v_data);
}

