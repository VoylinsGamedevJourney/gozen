#include "gozen_video.hpp"


int GoZenVideo::open(const String& video_path) {
	if (loaded)
		return _log_err("Already open");

	// Allocate video file context.
	AVFormatContext* temp_format_ctx = nullptr;

	path = video_path;
	resolution = Vector2i(0, 0);

	if (path.begins_with("res://") || path.begins_with("user://")) {
		if (!(temp_format_ctx = avformat_alloc_context()))
			return _log_err("Failed to allocate AVFormatContext");

		file_buffer = FileAccess::get_file_as_bytes(path);

		if (file_buffer.is_empty()) {
			avformat_free_context(temp_format_ctx);
			close();
			return _log_err("Couldn't load file from res:// at path '" + path + "'");
		}

		buffer_data.ptr = file_buffer.ptrw();
		buffer_data.size = file_buffer.size();
		buffer_data.offset = 0;

		unsigned char* avio_ctx_buffer = (unsigned char*)av_malloc(FFmpeg::AVIO_CTX_BUFFER_SIZE);
		avio_ctx = make_unique_ffmpeg<AVIOContext, AVIOContextDeleter>(
			avio_alloc_context(avio_ctx_buffer, FFmpeg::AVIO_CTX_BUFFER_SIZE, 0, &buffer_data,
							   &FFmpeg::read_buffer_packet, nullptr, &FFmpeg::seek_buffer));

		if (!avio_ctx) {
			close();
			av_free(avio_ctx_buffer);
			return _log_err("Failed to create avio_ctx");
		}

		temp_format_ctx->pb = avio_ctx.get();

		if (avformat_open_input(&temp_format_ctx, nullptr, nullptr, nullptr) != 0) {
			close();
			return _log_err("Failed to open input from memory buffer");
		}
	} else if (avformat_open_input(&temp_format_ctx, path.utf8(), NULL, NULL)) {
		close();
		return _log_err("Couldn't open video");
	}

	av_format_ctx = make_unique_ffmpeg<AVFormatContext, AVFormatCtxInputDeleter>(temp_format_ctx);

	// Getting video stream information.
	avformat_find_stream_info(av_format_ctx.get(), NULL);

	for (int i = 0; i < av_format_ctx->nb_streams; i++) {
		AVCodecParameters* av_codec_params = av_format_ctx->streams[i]->codecpar;

		if (!avcodec_find_decoder(av_codec_params->codec_id)) {
			av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
			continue;
		} else if (av_codec_params->codec_type == AVMEDIA_TYPE_VIDEO &&
				   !(av_format_ctx->streams[i]->disposition & AV_DISPOSITION_ATTACHED_PIC)) {
			av_stream = av_format_ctx->streams[i];
			resolution.x = av_codec_params->width;
			resolution.y = av_codec_params->height;
			color_profile = av_codec_params->color_primaries;

			AVDictionaryEntry* rotate_tag = av_dict_get(av_stream->metadata, "rotate", nullptr, 0);
			rotation = rotate_tag ? atoi(rotate_tag->value) : 0;
			if (rotation == 0) { // Check modern rotation detecting.
				for (int i = 0; i < av_stream->codecpar->nb_coded_side_data; ++i) {
					const AVPacketSideData* side_data = &av_stream->codecpar->coded_side_data[i];

					if (side_data->type == AV_PKT_DATA_DISPLAYMATRIX && side_data->size == sizeof(int32_t) * 9)
						rotation = av_display_rotation_get(reinterpret_cast<const int32_t*>(side_data->data));
				}
			}

			continue;
		}
		av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
	}

	// Get all streams.
	video_streams = PackedInt32Array();
	audio_streams = PackedInt32Array();
	subtitle_streams = PackedInt32Array();

	for (int i = 0; i < av_format_ctx->nb_streams; i++) {
		AVCodecParameters* av_codec_params = av_format_ctx->streams[i]->codecpar;

		if (!avcodec_find_decoder(av_codec_params->codec_id))
			continue;

		if (av_codec_params->codec_type == AVMEDIA_TYPE_VIDEO &&
			!(av_format_ctx->streams[i]->disposition & AV_DISPOSITION_ATTACHED_PIC))
			video_streams.append(i);
		else if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO)
			audio_streams.append(i);
		else if (av_codec_params->codec_type == AVMEDIA_TYPE_SUBTITLE)
			subtitle_streams.append(i);
	}

	// Setup Decoder codec context.
	const AVCodec* av_codec = avcodec_find_decoder(av_stream->codecpar->codec_id);
	if (av_codec == NULL) {
		close();
		return _log_err("Couldn't find decoder");
	}

	// Allocate codec context for decoder.
	av_codec_ctx = make_unique_ffmpeg<AVCodecContext, AVCodecCtxDeleter>(avcodec_alloc_context3(av_codec));
	if (!av_codec_ctx) {
		close();
		return _log_err("Couldn't alloc codec");
	}

	// Copying parameters.
	if (avcodec_parameters_to_context(av_codec_ctx.get(), av_stream->codecpar)) {
		close();
		return _log_err("Failed to init codec");
	}

	FFmpeg::enable_multithreading(av_codec_ctx.get(), av_codec);

	// Open codec - Video.
	if (avcodec_open2(av_codec_ctx.get(), av_codec, NULL)) {
		close();
		return _log_err("Failed to open codec");
	}

	// Adjust resolution according to the aspect ratio.
	sar = av_q2d(av_stream->codecpar->sample_aspect_ratio);
	actual_resolution = resolution;

	if (sar > 1.0)
		resolution.x *= sar;
	else if (sar != 0.0 && sar != 1.0)
		resolution.x /= sar;

	if (av_stream->start_time != AV_NOPTS_VALUE)
		start_time_video = (int64_t)(av_stream->start_time * stream_time_base_video);
	else
		start_time_video = 0;

	// Getting some data out of first frame.
	av_packet = make_unique_avpacket();
	av_frame = make_unique_avframe();
	av_sws_frame = make_unique_avframe();

	if (!av_packet || !av_frame || !av_sws_frame) {
		close();
		return _log_err("Couldn't create frame/packet");
	}

	avcodec_flush_buffers(av_codec_ctx.get());
	bool duration_from_bitrate = av_format_ctx->duration_estimation_method == AVFMT_DURATION_FROM_BITRATE;

	if (duration_from_bitrate) {
		close();
		return _log_err("Invalid video");
	}

	int response = 0;
	int attempts = 0;

	while (true) {
		response = FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(), av_stream->index, av_frame.get(),
									 av_packet.get());

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

	// Checking for interlacing and what type of interlacing.
	if (av_frame->flags & AV_FRAME_FLAG_INTERLACED)
		interlaced = av_frame->flags & AV_FRAME_FLAG_TOP_FIELD_FIRST ? 1 : 2;

	// Checking color range.
	full_color_range = av_frame->color_range == AVCOL_RANGE_JPEG;

	// Getting frame rate.
	// - Average framerate.
	if (av_stream->avg_frame_rate.num > 0 && av_stream->avg_frame_rate.den > 0) {
		double avg_rate = av_q2d(av_stream->avg_frame_rate);

		if (avg_rate > 0.1)
			framerate = avg_rate;
	}

	// - Real framerate (not always correct).
	if (framerate <= 0.1 && av_stream->r_frame_rate.num > 0 && av_stream->r_frame_rate.den > 0) {
		double r_rate = av_q2d(av_stream->r_frame_rate);

		if (r_rate > 0.1)
			framerate = r_rate;
	}

	// - Guess the framerate.
	if (framerate <= 0.1) {
		AVRational guessed_rate_q = av_guess_frame_rate(av_format_ctx.get(), av_stream, av_frame.get());
		double guessed_rate = av_q2d(guessed_rate_q);

		if (guessed_rate > 0.1)
			framerate = guessed_rate;
	}
	// - Make sure we have a valid framerate after all checks.
	if (framerate <= 0) {
		close();
		return _log_err("Invalid framerate (could not be determined)");
	}

	// Setting variables.
	average_frame_duration = 10000000.0 / framerate; // eg. 1 sec / 25 fps = 400.000 ticks (40ms).
	stream_time_base_video = av_q2d(av_stream->time_base) * 1000.0 * 10000.0; // Converting timebase to ticks.

	// Check for alpha layer.
	has_alpha = (av_frame->format == AV_PIX_FMT_YUVA420P || av_frame->format == AV_PIX_FMT_YUVA444P ||
				 av_frame->format == AV_PIX_FMT_ARGB || av_frame->format == AV_PIX_FMT_BGRA ||
				 av_frame->format == AV_PIX_FMT_ABGR || av_frame->format == AV_PIX_FMT_RGBA);

	pixel_format = av_get_pix_fmt_name((AVPixelFormat)av_frame->format);
	_log(String("Selected pixel format is: ") + pixel_format);

	// Preparing the data images.
	bool is_natively_supported = (av_frame->format == AV_PIX_FMT_YUV420P || av_frame->format == AV_PIX_FMT_YUVJ420P ||
								  av_frame->format == AV_PIX_FMT_YUVA420P);

	if (is_natively_supported) {
		padding = av_frame->linesize[0] - resolution.x;
		y_data = Image::create_empty(av_frame->linesize[0], resolution.y, false, Image::FORMAT_R8);
		u_data = Image::create_empty(av_frame->linesize[1], resolution.y / 2, false, Image::FORMAT_R8);
		v_data = Image::create_empty(av_frame->linesize[2], resolution.y / 2, false, Image::FORMAT_R8);

		if (has_alpha)
			a_data = Image::create_empty(av_frame->linesize[3], resolution.y, false, Image::FORMAT_R8);
	} else {
		AVPixelFormat new_format = has_alpha ? AV_PIX_FMT_YUVA420P : AV_PIX_FMT_YUV420P;

		using_sws = true;
		sws_ctx = make_unique_ffmpeg<SwsContext, SwsCtxDeleter>(
			sws_getContext(resolution.x, resolution.y, (AVPixelFormat)av_frame->format, resolution.x, resolution.y,
						   new_format, sws_flag, NULL, NULL, NULL));

		// We will use av_hw_frame to convert the frame data to as we won't use it anyway without hw decoding.
		av_sws_frame = make_unique_avframe();
		sws_scale_frame(sws_ctx.get(), av_sws_frame.get(), av_frame.get());

		// NOTE: It's possible that linesize is empty so we should switch to resolution.x and to resolution.x / 2.
		// If that's the case, padding is automatically 0 due to how SWR works.
		padding = av_sws_frame->linesize[0] - resolution.x;
		y_data = Image::create_empty(av_sws_frame->linesize[0], resolution.y, false, Image::FORMAT_R8);
		u_data = Image::create_empty(av_sws_frame->linesize[1], resolution.y / 2, false, Image::FORMAT_R8);
		v_data = Image::create_empty(av_sws_frame->linesize[2], resolution.y / 2, false, Image::FORMAT_R8);

		if (has_alpha)
			a_data = Image::create_empty(av_sws_frame->linesize[3], resolution.y, false, Image::FORMAT_R8);

		av_frame_unref(av_sws_frame.get());
	}

	duration = av_format_ctx->duration;
	if (av_stream->duration == AV_NOPTS_VALUE || duration_from_bitrate) {
		if (duration == AV_NOPTS_VALUE || duration_from_bitrate) {
			close();
			return _log_err("Invalid video duration");
		} else {
			AVRational temp_rational = AVRational{1, AV_TIME_BASE};
			if (temp_rational.num != av_stream->time_base.num || temp_rational.num != av_stream->time_base.num)
				duration =
					std::ceil(static_cast<double>(duration) * av_q2d(temp_rational) / av_q2d(av_stream->time_base));
		}

		av_stream->duration = duration;
	}

	if (av_stream->nb_frames > 0)
		frame_count = av_stream->nb_frames;
	else
		frame_count = static_cast<int>(
			std::round((static_cast<double>(duration) / static_cast<double>(AV_TIME_BASE)) * framerate));

	if (av_packet)
		av_packet_unref(av_packet.get());
	if (av_frame)
		av_frame_unref(av_frame.get());

	loaded = true;
	seek_frame(0);

	return OK;
}


void GoZenVideo::close() {
	_log("Closing video file on path: " + path);
	loaded = false;
	current_frame = -1;

	av_packet.reset();
	av_frame.reset();
	av_sws_frame.reset();
	avio_ctx.reset();

	file_buffer.clear();

	sws_ctx.reset();
	av_codec_ctx.reset();
	av_format_ctx.reset();
}


bool GoZenVideo::seek_frame(int frame_nr) {
	if (!loaded)
		return _log_err("Not open");

	int response = 0;
	int attempts = 0;

	int frame_difference = frame_nr - current_frame;

	if (frame_difference > 0 && frame_difference <= smart_seek_threshold) {
		for (int i = 0; i < frame_difference; i++) {
			if (!next_frame(true)) {
				_log_err("Smart seek failed, falling back to hard seeking");
				frame_difference = 0;
				break;
			}
		}

		if (frame_difference != 0) {
			_copy_frame_data();
			return true;
		}
	}

	// Video seeking.
	if ((response = _seek_frame(frame_nr)) < 0)
		return _log_err("Couldn't seek");

	while (true) {
		if ((response = FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(), av_stream->index, av_frame.get(),
										  av_packet.get()))) {
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
					return _log_err("Couldn't seek frame! Error core: " + String::num_int64(response));

				continue;
			}

			FFmpeg::print_av_error("Problem happened getting frame in seek_frame! ", response);
			response = 1;
			break;
		}

		// Get frame pts.
		if (av_frame->best_effort_timestamp == AV_NOPTS_VALUE)
			current_pts = av_frame->pts;
		else
			current_pts = av_frame->best_effort_timestamp;

		if (current_pts == AV_NOPTS_VALUE)
			continue;

		// Skip to actual requested frame.
		if ((int64_t)(current_pts * stream_time_base_video) / 10000 >= frame_timestamp / 10000) {
			_copy_frame_data();
			break;
		}
	}

	current_frame = frame_nr;

	av_frame_unref(av_frame.get());
	av_packet_unref(av_packet.get());

	return true;
}


bool GoZenVideo::next_frame(bool skip) {
	if (!loaded)
		return false;

	int response = FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(), av_stream->index, av_frame.get(), av_packet.get());

	if (response < 0) {
		if (response == AVERROR_EOF)
			_log("End of file reached in next_frame");
		else FFmpeg::print_av_error("Error in next_frame", response);
	}

	if (av_frame->best_effort_timestamp == AV_NOPTS_VALUE)
		current_pts = av_frame->pts;
	else current_pts = av_frame->best_effort_timestamp;

	if (!skip)
		_copy_frame_data();

	current_frame++;

	av_frame_unref(av_frame.get());
	av_packet_unref(av_packet.get());

	return true;
}


Ref<Image> GoZenVideo::generate_thumbnail_at_frame(int frame_nr) {
	// This is identical to the seek_frame() function, but instead of copying
	// the data to Y,U,V we create an RGBA Image.
	if (!loaded) {
		_log_err("Not open");
		return Ref<Image>();
	}

	int response = 0;
	bool frame_found = false;
	int attempts = 0;

	if ((response = _seek_frame(frame_nr)) < 0) {
		_log_err("Couldn't seek");
		return Ref<Image>();
	}

	while (true) {
		response = FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(), av_stream->index, av_frame.get(),
									 av_packet.get());

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
		response = FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(), av_stream->index, av_frame.get(),
									 av_packet.get());
		if (response) {
			if (response == AVERROR(EAGAIN) || response == AVERROR(EWOULDBLOCK)) {
				if (attempts > 10) {
					FFmpeg::print_av_error("Reached max attempts trying to get first frame!", response);
					break;
				}
				attempts++;
				continue;
			} else if (response == AVERROR_EOF) {
				_log_err("End of file reached! Going back 1 frame!");

				if ((response = _seek_frame(frame_nr--)) < 0) {
					_log_err("Couldn't seek");
					return Ref<Image>();
				}
				continue;
			}

			FFmpeg::print_av_error("Problem happened getting frame in seek_frame! ", response);
			response = 1;
			break;
		}

		// Get frame pts.
		current_pts =
			av_frame->best_effort_timestamp == AV_NOPTS_VALUE ? av_frame->pts : av_frame->best_effort_timestamp;
		if (current_pts == AV_NOPTS_VALUE)
			continue;

		// Skip to actual requested frame.
		if ((int64_t)(current_pts * stream_time_base_video) / 10000 >= frame_timestamp / 10000) {
			frame_found = true;
			break;
		}
	}

	// We still have to set the frame_nr since that's where the "playhead" is
	// inside of the file.
	current_frame = frame_nr;

	if (!frame_found) {
		av_frame_unref(av_frame.get());
		av_packet_unref(av_packet.get());

		return Ref<Image>();
	}

	// Creation of the thumbnail.
	AVPixelFormat source_pix_fmt = static_cast<AVPixelFormat>(av_frame->format);

	UniqueSwsCtx sws_ctx_thumb = make_unique_ffmpeg<SwsContext, SwsCtxDeleter>(
		sws_getContext(resolution.x, resolution.y, source_pix_fmt,	// Source
					   resolution.x, resolution.y, AV_PIX_FMT_RGBA, // Target
					   SWS_FAST_BILINEAR, nullptr, nullptr, nullptr));

	if (!sws_ctx_thumb) {
		_log_err("Failed to create SWS context for RGBA conversion");
		return Ref<Image>();
	}

	UniqueAVFrame rgba_frame = make_unique_avframe();
	if (!rgba_frame) {
		_log_err("Failed to allocate AVFrame for RGBA data");
		return Ref<Image>();
	}
	rgba_frame->format = AV_PIX_FMT_RGBA;
	rgba_frame->width = resolution.x;
	rgba_frame->height = resolution.y;

	// Allocate buffer for the RGBA frame.
	response = av_frame_get_buffer(rgba_frame.get(), 0); // Use default alignment (usually 32)
	if (response < 0) {
		FFmpeg::print_av_error("Failed to allocate buffer for RGBA frame: ", response);
		return Ref<Image>();
	}

	sws_scale(sws_ctx_thumb.get(), (const uint8_t* const*)av_frame->data, av_frame->linesize, 0, resolution.y,
			  rgba_frame->data, rgba_frame->linesize);

	PackedByteArray pixel_data = PackedByteArray();
	int rgba_data_size = resolution.x * resolution.y * 4;
	pixel_data.resize(rgba_data_size);

	if (rgba_frame->linesize[0] == resolution.x * 4) {
		memcpy(pixel_data.ptrw(), rgba_frame->data[0], rgba_data_size);
	} else {
		// Handle potential padding in linesize.
		uint8_t* dest_ptr = pixel_data.ptrw();
		const uint8_t* src_ptr = rgba_frame->data[0];
		for (int y = 0; y < resolution.y; ++y) {
			memcpy(dest_ptr, src_ptr, resolution.x * 4);
			dest_ptr += resolution.x * 4;
			src_ptr += rgba_frame->linesize[0];
		}
	}

	Ref<Image> thumbnail_image =
		Image::create_from_data(resolution.x, resolution.y, false, Image::FORMAT_RGBA8, pixel_data);
	av_frame_unref(av_frame.get());
	av_packet_unref(av_packet.get());

	return thumbnail_image;
}


PackedInt32Array GoZenVideo::get_streams(int stream_type) {
	if (!loaded) {
		_log_err("file is not open");
		return PackedInt32Array();
	}

	switch (stream_type) {
	case STREAM_VIDEO:
		return video_streams;
	case STREAM_AUDIO:
		return audio_streams;
	case STREAM_SUBTITLE:
		return subtitle_streams;
	}

	_log_err("invalid stream type requested");
	return PackedInt32Array();
}


Dictionary GoZenVideo::get_stream_metadata(int stream_index) {
	if (!loaded) {
		_log_err("file is not open");
		return Dictionary();
	}

	if (stream_index < 0 || stream_index >= av_format_ctx->nb_streams) {
		_log_err("invalid stream index");
		return Dictionary();
	}

	Dictionary dict = Dictionary();

	AVDictionaryEntry* entry = nullptr;
	while ((entry = av_dict_get(av_format_ctx->streams[stream_index]->metadata, "", entry, AV_DICT_IGNORE_SUFFIX))) {
		dict[entry->key] = entry->value;
	}

	if (!dict.has("title"))
		dict.set("title", "");
	if (!dict.has("language"))
		dict.set("language", "");

	return dict;
}


int GoZenVideo::get_chapter_count() {
	if (!loaded) {
		_log_err("file is not open");
		return 0;
	}

	return av_format_ctx->nb_chapters;
}


float GoZenVideo::get_chapter_start(int chapter_index) {
	if (!loaded) {
		_log_err("file is not open");
		return -1.0f;
	}

	if (chapter_index < 0 || chapter_index >= av_format_ctx->nb_chapters) {
		_log_err("invalid chapter index");
		return -1.0f;
	}

	AVChapter* chapter = av_format_ctx->chapters[chapter_index];
	return chapter->start * av_q2d(chapter->time_base);
}


float GoZenVideo::get_chapter_end(int chapter_index) {
	if (!loaded) {
		_log_err("file is not open");
		return -1.0f;
	}

	if (chapter_index < 0 || chapter_index >= av_format_ctx->nb_chapters) {
		_log_err("invalid chapter index");
		return -1.0f;
	}

	AVChapter* chapter = av_format_ctx->chapters[chapter_index];
	return chapter->end * av_q2d(chapter->time_base);
}


Dictionary GoZenVideo::get_chapter_metadata(int chapter_index) {
	if (!loaded) {
		_log_err("file is not open");
		return Dictionary();
	}

	if (chapter_index < 0 || chapter_index >= av_format_ctx->nb_chapters) {
		_log_err("invalid chapter index");
		return Dictionary();
	}

	Dictionary dict = Dictionary();

	AVDictionaryEntry* entry = nullptr;
	while ((entry = av_dict_get(av_format_ctx->chapters[chapter_index]->metadata, "", entry, AV_DICT_IGNORE_SUFFIX))) {
		dict[entry->key] = entry->value;
	}

	return dict;
}


void GoZenVideo::_copy_frame_data() {
	if (av_frame->data[0] == nullptr) {
		_log_err("Frame is empty!");
		return;
	}

	if (using_sws) {
		sws_scale_frame(sws_ctx.get(), av_sws_frame.get(), av_frame.get());

		memcpy(y_data->ptrw(), av_sws_frame->data[0], y_data->get_size().x * y_data->get_size().y);
		memcpy(u_data->ptrw(), av_sws_frame->data[1], u_data->get_size().x * u_data->get_size().y);
		memcpy(v_data->ptrw(), av_sws_frame->data[2], v_data->get_size().x * v_data->get_size().y);

		if (has_alpha)
			memcpy(a_data->ptrw(), av_sws_frame->data[3], a_data->get_size().x * a_data->get_size().y);

		av_frame_unref(av_sws_frame.get());
	} else {
		memcpy(y_data->ptrw(), av_frame->data[0], y_data->get_size().x * y_data->get_size().y);
		memcpy(u_data->ptrw(), av_frame->data[1], u_data->get_size().x * u_data->get_size().y);
		memcpy(v_data->ptrw(), av_frame->data[2], v_data->get_size().x * v_data->get_size().y);

		if (has_alpha)
			memcpy(a_data->ptrw(), av_frame->data[3], a_data->get_size().x * a_data->get_size().y);
	}
}


int GoZenVideo::_seek_frame(int frame_nr) {
	avcodec_flush_buffers(av_codec_ctx.get());

	frame_timestamp = (int64_t)(frame_nr * average_frame_duration);
	return av_seek_frame(av_format_ctx.get(), -1, (start_time_video + frame_timestamp) / 10,
						 AVSEEK_FLAG_BACKWARD | AVSEEK_FLAG_FRAME);
}


void GoZenVideo::_bind_methods() {
	ClassDB::bind_method(D_METHOD("open", "video_path"), &GoZenVideo::open);

	ClassDB::bind_method(D_METHOD("is_open"), &GoZenVideo::is_open);

	ClassDB::bind_method(D_METHOD("seek_frame", "frame_nr"), &GoZenVideo::seek_frame);
	ClassDB::bind_method(D_METHOD("next_frame", "skip"), &GoZenVideo::next_frame);

	ClassDB::bind_method(D_METHOD("get_streams", "stream_type"), &GoZenVideo::get_streams);
	ClassDB::bind_method(D_METHOD("get_stream_metadata", "stream_index"), &GoZenVideo::get_stream_metadata);

	ClassDB::bind_method(D_METHOD("get_chapter_count"), &GoZenVideo::get_chapter_count);
	ClassDB::bind_method(D_METHOD("get_chapter_start", "chapter_index"), &GoZenVideo::get_chapter_start);
	ClassDB::bind_method(D_METHOD("get_chapter_end", "chapter_index"), &GoZenVideo::get_chapter_end);
	ClassDB::bind_method(D_METHOD("get_chapter_metadata", "chapter_index"), &GoZenVideo::get_chapter_metadata);

	ClassDB::bind_method(D_METHOD("generate_thumbnail_at_frame", "frame_nr"), &GoZenVideo::generate_thumbnail_at_frame);

	ClassDB::bind_method(D_METHOD("set_sws_flag_bilinear"), &GoZenVideo::set_sws_flag_bilinear);
	ClassDB::bind_method(D_METHOD("set_sws_flag_bicubic"), &GoZenVideo::set_sws_flag_bicubic);

	ClassDB::bind_method(D_METHOD("set_smart_seek_threshold", "frames"), &GoZenVideo::set_smart_seek_threshold);

	ClassDB::bind_method(D_METHOD("get_y_data"), &GoZenVideo::get_y_data);
	ClassDB::bind_method(D_METHOD("get_u_data"), &GoZenVideo::get_u_data);
	ClassDB::bind_method(D_METHOD("get_v_data"), &GoZenVideo::get_v_data);
	ClassDB::bind_method(D_METHOD("get_a_data"), &GoZenVideo::get_a_data);

	// Metadata getters
	ClassDB::bind_method(D_METHOD("get_path"), &GoZenVideo::get_path);

	ClassDB::bind_method(D_METHOD("get_resolution"), &GoZenVideo::get_resolution);
	ClassDB::bind_method(D_METHOD("get_actual_resolution"), &GoZenVideo::get_actual_resolution);

	ClassDB::bind_method(D_METHOD("get_width"), &GoZenVideo::get_width);
	ClassDB::bind_method(D_METHOD("get_height"), &GoZenVideo::get_height);
	ClassDB::bind_method(D_METHOD("get_actual_width"), &GoZenVideo::get_actual_width);
	ClassDB::bind_method(D_METHOD("get_actual_height"), &GoZenVideo::get_actual_height);

	ClassDB::bind_method(D_METHOD("get_padding"), &GoZenVideo::get_padding);
	ClassDB::bind_method(D_METHOD("get_rotation"), &GoZenVideo::get_rotation);
	ClassDB::bind_method(D_METHOD("get_interlaced"), &GoZenVideo::get_interlaced);
	ClassDB::bind_method(D_METHOD("get_frame_count"), &GoZenVideo::get_frame_count);
	ClassDB::bind_method(D_METHOD("get_current_frame"), &GoZenVideo::get_current_frame);

	ClassDB::bind_method(D_METHOD("get_sar"), &GoZenVideo::get_sar);
	ClassDB::bind_method(D_METHOD("get_framerate"), &GoZenVideo::get_framerate);

	ClassDB::bind_method(D_METHOD("get_pixel_format"), &GoZenVideo::get_pixel_format);
	ClassDB::bind_method(D_METHOD("get_color_profile"), &GoZenVideo::get_color_profile);

	ClassDB::bind_method(D_METHOD("get_has_alpha"), &GoZenVideo::get_has_alpha);

	ClassDB::bind_method(D_METHOD("is_full_color_range"), &GoZenVideo::is_full_color_range);
	ClassDB::bind_method(D_METHOD("is_using_sws"), &GoZenVideo::is_using_sws);

	ClassDB::bind_method(D_METHOD("enable_debug"), &GoZenVideo::enable_debug);
	ClassDB::bind_method(D_METHOD("disable_debug"), &GoZenVideo::disable_debug);
	ClassDB::bind_method(D_METHOD("get_debug_enabled"), &GoZenVideo::get_debug_enabled);
}
