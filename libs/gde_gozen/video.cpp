#include "video.hpp"

Video::Video() {
	av_log_set_level(AV_LOG_VERBOSE); 
}

Video::~Video() {
	close();
}


bool Video::open(const String& video_path) {
	if (loaded)
		return _log_err("Already open");

	path = video_path;
	resolution = Vector2i(0, 0);

	// Allocate video file context
	AVFormatContext* temp_format_ctx = nullptr;
	if (avformat_open_input(&temp_format_ctx, path.utf8(), nullptr, nullptr)) {
		close();
		return _log_err("Couldn't open video");
	}

	av_format_ctx = make_unique_ffmpeg<AVFormatContext, AVFormatCtxInputDeleter>(
			temp_format_ctx);

	// Getting the video stream
	avformat_find_stream_info(av_format_ctx.get(), nullptr);

	for (int i = 0; i < av_format_ctx->nb_streams; i++) {
		AVCodecParameters *av_codec_params =
				av_format_ctx->streams[i]->codecpar;

		if (!avcodec_find_decoder(av_codec_params->codec_id)) {
			av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
			continue;
		} else if (av_codec_params->codec_type == AVMEDIA_TYPE_VIDEO  &&
				!(av_format_ctx->streams[i]->disposition & AV_DISPOSITION_ATTACHED_PIC)) {
			av_stream = av_format_ctx->streams[i];
			resolution.x = av_codec_params->width;
			resolution.y = av_codec_params->height;
			break;
		}
		av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
	}

	// Get basic stream info.
	resolution.x = av_stream->codecpar->width;
	resolution.y = av_stream->codecpar->height;
	framerate = av_q2d(av_guess_frame_rate(
			av_format_ctx.get(), av_stream, nullptr));

	if (framerate <= 0)
		framerate = av_q2d(av_stream->avg_frame_rate);
	if (framerate <= 0)
		framerate = av_q2d(av_stream->r_frame_rate);
	if (framerate <= 0) {
		_log("Could not determine framerate reliably");
		framerate = 0.0f;
	}

	// Figuring out duration.
	if (av_stream->duration != AV_NOPTS_VALUE)
		duration_us = av_rescale_q(av_stream->duration,
								   av_stream->time_base, AV_TIME_BASE_Q);
	else if (av_format_ctx->duration != AV_NOPTS_VALUE)
		duration_us = av_format_ctx->duration;
	else {
		duration_us = 0;
		_log("Could not determine video duration");
	}

	if (framerate > 0 && duration_us > 0)
		frame_count = static_cast<int64_t>(
				round(get_duration_seconds() * framerate));
	else
		frame_count = 0;

	pixel_format_name = av_get_pix_fmt_name(
			static_cast<AVPixelFormat>(av_stream->codecpar->format));
	color_primaries_name =
			av_color_primaries_name(av_stream->codecpar->color_primaries);
	color_trc_name = av_color_transfer_name(
			av_stream->codecpar->color_trc);
	color_space_name = av_color_space_name(
			av_stream->codecpar->color_space);
	is_full_color_range = 
			av_stream->codecpar->color_range == AVCOL_RANGE_JPEG;

	// Getting rotation.
	// Modern method has deprecated stuff issues, so we just check video meta.
	rotation = 0;
	AVDictionaryEntry* rotate_tag = av_dict_get(
			av_stream->metadata, "rotate", nullptr, 0);

	if (rotate_tag && rotate_tag->value) {
		rotation = atoi(rotate_tag->value);

		if (rotation == -90)
			rotation = 270;

		rotation = rotation % 360;
		if (rotation < 0)
			rotation += 360;

		if (rotation != 0 && rotation != 90 && rotation != 180 &&
			rotation != 270) {
			_log("Non-standard rotation metadata tag found: " +
					String::num_int64(rotation) + ". Resetting to 0");
			rotation = 0;
		}
	}

	is_interlaced = false;

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
	if (avcodec_open2(av_codec_ctx.get(), av_codec, nullptr)) {
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

	int attempts = 0;
	while (true) {
		response = FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(),
									 av_stream->index, av_frame.get(), av_packet.get());

		if (response == 0)
			break;
		else if (response == AVERROR(EAGAIN) || response == AVERROR(EWOULDBLOCK)) {
			if (attempts > 10) {
				FFmpeg::print_av_error("Reached max attempts trying to get first frame!", response);
				break;
			}

			attempts++;
		} else if (response == AVERROR_EOF) {
			FFmpeg::print_av_error("Reached EOF trying to get first frame!", response);
			break;
		} else {
			FFmpeg::print_av_error("Something went wrong getting first frame!", response);
			break;
		}
	}

	if (response < 0) {
		close();
		return false;
	}

	// Getting more metadata
	is_interlaced = (
			av_codec_ctx->field_order != AV_FIELD_PROGRESSIVE
			&& av_codec_ctx->field_order != AV_FIELD_UNKNOWN);

	padding = av_frame->linesize[0] - resolution.x;

	// Setting variables
	average_frame_duration = 10000000.0 / framerate; // eg. 1 sec / 25 fps = 400.000 ticks (40ms)
	stream_time_base_video = av_q2d(av_stream->time_base) * 1000.0 * 10000.0; // Converting timebase to ticks

	// Setting linesize and enabling sws if needed.
	if (av_frame->format == AV_PIX_FMT_YUV420P || av_frame->format == AV_PIX_FMT_YUVJ420P) {
		using_sws = false;

		y_data = Image::create_empty(av_frame->linesize[0], resolution.y, false, Image::FORMAT_R8);
		u_data = Image::create_empty(av_frame->linesize[1], resolution.y/2, false, Image::FORMAT_R8);
		v_data = Image::create_empty(av_frame->linesize[2], resolution.y/2, false, Image::FORMAT_R8);
	} else {
		_log("Enabling SWS due to pixel format: " + pixel_format_name);
		using_sws = true;

		sws_ctx = make_unique_ffmpeg<SwsContext, SwsCtxDeleter>(sws_getContext(
						resolution.x, resolution.y, av_codec_ctx->pix_fmt,
						resolution.x, resolution.y, AV_PIX_FMT_YUV420P,
						sws_flag, nullptr, nullptr, nullptr));
        if (!sws_ctx) {
             close();
             return _log_err("Failed to create SWS context");
        }

		av_sws_frame = make_unique_avframe();
        if (!av_sws_frame) {
            close();
            return _log_err("Failed to allocate SWS frame");
        }

		sws_scale_frame(sws_ctx.get(), av_sws_frame.get(), av_frame.get());

		y_data = Image::create_empty(av_sws_frame->linesize[0] , resolution.y, false, Image::FORMAT_R8);
		u_data = Image::create_empty(av_sws_frame->linesize[1] , resolution.y/2, false, Image::FORMAT_R8);
		v_data = Image::create_empty(av_sws_frame->linesize[2] , resolution.y/2, false, Image::FORMAT_R8);
		padding = av_sws_frame->linesize[0] - resolution.x;

		av_frame_unref(av_sws_frame.get());
	}

	if (av_packet)
		av_packet_unref(av_packet.get());
	if (av_frame)
		av_frame_unref(av_frame.get());

	loaded = true;
	response = OK;
	current_frame = 0;
	seek_frame(0);

	return OK;
}

void Video::close() {
	loaded = false;
	response = OK;
	current_frame = -1;

	av_packet.reset();
	av_frame.reset();
	av_sws_frame.reset();

	sws_ctx.reset();

	av_codec_ctx.reset();
	av_format_ctx.reset();
}

bool Video::seek_frame(int frame_nr) {
	if (!loaded)
		return _log_err("Not open");

	// Video seeking
	if ((response = _seek_frame(frame_nr)) < 0)
		return _log_err("Couldn't seek");





	int attempts = 0;
	while (true) {
		response = FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(),
									 av_stream->index, av_frame.get(), av_packet.get());

		if (response == 0)
			break;
		else if (response == AVERROR(EAGAIN) || response == AVERROR(EWOULDBLOCK)) {
			if (attempts > 10) {
				FFmpeg::print_av_error("Reached max attempts trying to get first frame!", response);
				break;
			}

			attempts++;
		} else if (response == AVERROR_EOF) {
			FFmpeg::print_av_error("Reached EOF trying to get first frame!", response);
			break;
		} else {
			FFmpeg::print_av_error("Something went wrong getting first frame!", response);
			break;
		}
	}





	
	while (true) {
		if ((response = FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(),
									av_stream->index, av_frame.get(), av_packet.get()))) {
			if (response == AVERROR(EAGAIN) || response == AVERROR(EWOULDBLOCK)) {
				if (attempts > 10) {
					FFmpeg::print_av_error("Reached max attempts trying to get first frame!", response);
					break;
				}

				attempts++;
				continue;
			} else if (response == AVERROR_EOF) {
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

	current_frame = frame_nr;

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

	current_frame++;

	av_frame_unref(av_frame.get());
	av_packet_unref(av_packet.get());
	
	return true;
}

void Video::_copy_frame_data() {
	if (av_frame->data[0] == nullptr) {
		_log_err("Frame is empty!");
		return;
	}

	if (using_sws) {
		sws_scale_frame(sws_ctx.get(), av_sws_frame.get(), av_frame.get());

		memcpy(y_data->ptrw(), av_sws_frame->data[0], y_data->get_size().x*y_data->get_size().y);
		memcpy(u_data->ptrw(), av_sws_frame->data[1], u_data->get_size().x*u_data->get_size().y);
		memcpy(v_data->ptrw(), av_sws_frame->data[2], v_data->get_size().x*v_data->get_size().y);

		av_frame_unref(av_sws_frame.get());
	} else {
		memcpy(y_data->ptrw(), av_frame->data[0], y_data->get_size().x*y_data->get_size().y);
		memcpy(u_data->ptrw(), av_frame->data[1], u_data->get_size().x*u_data->get_size().y);
		memcpy(v_data->ptrw(), av_frame->data[2], v_data->get_size().x*v_data->get_size().y);
	}

	return;
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

#define BIND_METHOD_ARGS(method_name, ...) \
    ClassDB::bind_method( \
        D_METHOD(#method_name, __VA_ARGS__), &Video::method_name)


void Video::_bind_methods() {
	BIND_METHOD_ARGS(open, "video_path");

	BIND_METHOD(is_open);

	BIND_METHOD_ARGS(seek_frame, "frame_nr");
	BIND_METHOD_ARGS(next_frame, "skip_frame");

	BIND_METHOD(get_current_frame);
	BIND_METHOD(get_y_data);
	BIND_METHOD(get_u_data);
	BIND_METHOD(get_v_data);

	BIND_METHOD(set_sws_flag_bilinear);
	BIND_METHOD(set_sws_flag_bicubic);

	// Metadata getters
	BIND_METHOD(get_path);

	BIND_METHOD(get_resolution);
	BIND_METHOD(get_width);
	BIND_METHOD(get_height);

	BIND_METHOD(get_framerate);
	BIND_METHOD(get_frame_count);
	BIND_METHOD(get_duration_microseconds);
	BIND_METHOD(get_duration_seconds);
	BIND_METHOD(get_rotation);
	BIND_METHOD(get_padding);

	BIND_METHOD(get_pixel_format_name);
	BIND_METHOD(get_color_primaries_name);
	BIND_METHOD(get_color_trc_name);
	BIND_METHOD(get_color_space_name);

	BIND_METHOD(get_is_full_color_range);
	BIND_METHOD(get_is_interlaced);
}

