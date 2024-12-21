#include "video.hpp"


//----------------------------------------------- STATIC FUNCTIONS
Dictionary Video::get_file_meta(String a_file_path) {
	AVFormatContext *l_av_format_ctx = NULL;
	const AVDictionaryEntry *l_av_dic = NULL;
	Dictionary l_dic = {};

	if (avformat_open_input(&l_av_format_ctx, a_file_path.utf8(), NULL, NULL)) {
		UtilityFunctions::printerr("Couldn't open file!");
		return l_dic;
	}

	if (avformat_find_stream_info(l_av_format_ctx, NULL)) {
		UtilityFunctions::printerr("Couldn't find stream info!");
		avformat_close_input(&l_av_format_ctx);
		return l_dic;
	}

	while ((l_av_dic = av_dict_iterate(l_av_format_ctx->metadata, l_av_dic)))
		l_dic[l_av_dic->key] = l_av_dic->value;

	avformat_close_input(&l_av_format_ctx);
	return l_dic;
}

PackedStringArray Video::get_available_hw_devices() {
	PackedStringArray l_devices = PackedStringArray();
	enum AVHWDeviceType l_type = AV_HWDEVICE_TYPE_NONE;

	while ((l_type = av_hwdevice_iterate_types(l_type)) != AV_HWDEVICE_TYPE_NONE)
		l_devices.append(av_hwdevice_get_type_name(l_type));

	return l_devices;
}

enum AVPixelFormat Video::_get_format(AVCodecContext *a_av_ctx, const enum AVPixelFormat *a_pix_fmt) {
	return FFmpeg::get_hw_format(a_pix_fmt, &static_cast<Video *>(a_av_ctx->opaque)->hw_pix_fmt);
}


//----------------------------------------------- NON-STATIC FUNCTIONS
int Video::open(String a_path, bool a_load_audio) {
	if (loaded)
		return GoZenError::ERR_ALREADY_OPEN_VIDEO;

	path = a_path.utf8();

	// Allocate video file context
	av_format_ctx = avformat_alloc_context();
	if (!av_format_ctx)
		return GoZenError::ERR_CREATING_AV_FORMAT_FAILED;
	
	// Open file with avformat
	if (avformat_open_input(&av_format_ctx, path.c_str(), NULL, NULL)) {
		close();
		return GoZenError::ERR_OPENING_VIDEO;
	}

	// Find stream information
	if (avformat_find_stream_info(av_format_ctx, NULL)) {
		close();
		return GoZenError::ERR_NO_STREAM_INFO_FOUND;
	}

	// Getting the audio and video stream
	for (int i = 0; i < av_format_ctx->nb_streams; i++) {
		AVCodecParameters *av_codec_params = av_format_ctx->streams[i]->codecpar;

		if (!avcodec_find_decoder(av_codec_params->codec_id)) {
			av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
			continue;
		} else if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO) {
			if (a_load_audio && (audio = FFmpeg::get_audio(av_format_ctx, av_format_ctx->streams[i])) == nullptr) {
				close();
				return response;
			}
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

			if (av_codec_params->format != AV_PIX_FMT_YUV420P && hw_decoding) {
				_print_debug("Hardware decoding not supported for this pixel format, switching to software decoding!");
				hw_decoding = false;
			}

			continue;
		}
		av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
	}

	// Setup Decoder codec context
	const AVCodec *av_codec_video;
	if (hw_decoding)
		av_codec_video = _get_hw_codec();
	else
		av_codec_video = avcodec_find_decoder(av_stream_video->codecpar->codec_id);

	if (!av_codec_video) {
		close();
		return GoZenError::ERR_FAILED_FINDING_VIDEO_DECODER;
	}

	// Allocate codec context for decoder
	av_codec_ctx_video = avcodec_alloc_context3(av_codec_video);
	if (av_codec_ctx_video == NULL) {
		close();
		return GoZenError::ERR_FAILED_ALLOC_VIDEO_CODEC;
	}
	
	if (hw_decoding && hw_device_ctx) {
		av_codec_ctx_video->hw_device_ctx = hw_device_ctx;

		for (int i = 0;; i++) {
			const AVCodecHWConfig *config = avcodec_get_hw_config(av_codec_video, i);
			if (!config) {
				_printerr_debug("Current decoder does not accept selected device!");
				_printerr_debug(std::string("Codec name: ") + av_codec_video->long_name + "  -  Device: " + av_hwdevice_get_type_name(hw_decoder));
				hw_decoding = false;
				av_codec_ctx_video->hw_device_ctx = nullptr;
				break;
			}
			if ((config->methods & AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX) && config->device_type == hw_decoder) {
				hw_pix_fmt = config->pix_fmt;
				_print_debug(std::string("Hardware pixel format is: ") + av_get_pix_fmt_name(hw_pix_fmt));
				break;
			}
		}

		av_codec_ctx_video->opaque = this;
		av_codec_ctx_video->get_format = _get_format;
	}

	// Copying parameters
	if (avcodec_parameters_to_context(av_codec_ctx_video, av_stream_video->codecpar)) {
		close();
		return GoZenError::ERR_FAILED_INIT_VIDEO_CODEC;
	}

	FFmpeg::enable_multithreading(av_codec_ctx_video, av_codec_video);
	
	// Open codec - Video
	if (avcodec_open2(av_codec_ctx_video, av_codec_video, NULL)) {
		close();
		return GoZenError::ERR_FAILED_OPEN_VIDEO_CODEC;
	}

	float l_aspect_ratio = av_q2d(av_stream_video->codecpar->sample_aspect_ratio);
	if (l_aspect_ratio > 1.0)
		resolution.x = static_cast<int>(std::round(resolution.x * l_aspect_ratio));

	if (hw_decoding)
		pixel_format = av_get_pix_fmt_name(hw_pix_fmt);
	else
		pixel_format = av_get_pix_fmt_name(av_codec_ctx_video->pix_fmt);
	_print_debug("Selected pixel format is: " + pixel_format);

	start_time_video = av_stream_video->start_time != AV_NOPTS_VALUE ? (int64_t)(av_stream_video->start_time * stream_time_base_video) : 0;

	// Getting some data out of first frame
	if (!(av_packet = av_packet_alloc())) {
		close();
		return GoZenError::ERR_FAILED_ALLOC_PACKET;
	}

	if (!(av_frame = av_frame_alloc())) {
		close();
		return GoZenError::ERR_FAILED_ALLOC_FRAME;
	}

	if (hw_decoding && !(av_hw_frame = av_frame_alloc())) {
		close();
		return GoZenError::ERR_FAILED_ALLOC_FRAME;
	}

	avcodec_flush_buffers(av_codec_ctx_video);
	bool l_duration_from_bitrate = av_format_ctx->duration_estimation_method == AVFMT_DURATION_FROM_BITRATE;
	if (l_duration_from_bitrate) {
		close();
		return GoZenError::ERR_INVALID_VIDEO;
	}

	if ((response = _seek_frame(0)) < 0) {
		FFmpeg::print_av_error("Seeking to beginning error: ", response);
		close();
		return GoZenError::ERR_SEEKING;
	}

	if ((response = FFmpeg::get_frame(av_format_ctx, av_codec_ctx_video, av_stream_video->index, av_frame, av_packet))) {
		FFmpeg::print_av_error("Something went wrong getting first frame!", response);
		close();
		return GoZenError::ERR_SEEKING;
	}
	
	// Checking for interlacing and what type of interlacing
	if (av_frame->flags & AV_FRAME_FLAG_INTERLACED)
		interlaced = av_frame->flags & AV_FRAME_FLAG_TOP_FIELD_FIRST ? 1 : 2;

	// Checking color range
	full_color_range = av_frame->color_range == AVCOL_RANGE_JPEG;

	// Getting frame rate
	framerate = av_q2d(av_guess_frame_rate(av_format_ctx, av_stream_video, av_frame));
	if (framerate == 0) {
		close();
		return GoZenError::ERR_INVALID_FRAMERATE;
	}

	// Setting variables
	average_frame_duration = 10000000.0 / framerate;								// eg. 1 sec / 25 fps = 400.000 ticks (40ms)
	stream_time_base_video = av_q2d(av_stream_video->time_base) * 1000.0 * 10000.0; // Converting timebase to ticks

	// Preparing the data array's
	if (!hw_decoding) {
		if (av_frame->format == AV_PIX_FMT_YUV420P) {
			y_data.resize(av_frame->linesize[0] * resolution.y);
			u_data.resize(av_frame->linesize[1] * (resolution.y / 2));
			v_data.resize(av_frame->linesize[2] * (resolution.y / 2));
			padding = av_frame->linesize[0] - resolution.x;
		} else {
			using_sws = true;
			sws_ctx = sws_getContext(
							resolution.x, resolution.y, av_codec_ctx_video->pix_fmt,
							resolution.x, resolution.y, AV_PIX_FMT_YUV420P,
							SWS_BICUBIC, NULL, NULL, NULL);

			// We will use av_hw_frame to convert the frame data to as we won't use it anyway without hw decoding.
			av_hw_frame = av_frame_alloc();
			sws_scale_frame(sws_ctx, av_hw_frame, av_frame);

			y_data.resize(av_hw_frame->linesize[0] * resolution.y);
			u_data.resize(av_hw_frame->linesize[1] * (resolution.y / 2));
			v_data.resize(av_hw_frame->linesize[2] * (resolution.y / 2));
			padding = av_hw_frame->linesize[0] - resolution.x;

			av_frame_unref(av_hw_frame);
		}
	} else {
		if (av_hwframe_transfer_data(av_hw_frame, av_frame, 0) < 0)
			_printerr_debug("Error transferring the frame to system memory!");

		y_data.resize(av_hw_frame->linesize[0] * resolution.y);
		u_data.resize((av_hw_frame->linesize[1] / 2) * (resolution.y / 2) * 2);
		padding = av_hw_frame->linesize[0] - resolution.x;
		av_frame_unref(av_hw_frame);
	} 

	// Checking second frame
	if ((response = FFmpeg::get_frame(av_format_ctx, av_codec_ctx_video, av_stream_video->index, av_frame, av_packet)))
		FFmpeg::print_av_error("Something went wrong getting second frame!", response);

	duration = av_format_ctx->duration;
	if (av_stream_video->duration == AV_NOPTS_VALUE || l_duration_from_bitrate) {
		if (duration == AV_NOPTS_VALUE || l_duration_from_bitrate) {
			close();
			return GoZenError::ERR_INVALID_VIDEO;
		} else {
			AVRational l_temp_rational = AVRational{1, AV_TIME_BASE};
			if (l_temp_rational.num != av_stream_video->time_base.num || l_temp_rational.num != av_stream_video->time_base.num)
				duration = std::ceil(static_cast<double>(duration) * av_q2d(l_temp_rational) / av_q2d(av_stream_video->time_base));
		}
		av_stream_video->duration = duration;
	}

	frame_duration = (static_cast<double>(duration) / static_cast<double>(AV_TIME_BASE)) * framerate;

	if (av_packet)
		av_packet_unref(av_packet);
	if (av_frame)
		av_frame_unref(av_frame);

	loaded = true;
	response = OK;

	return OK;
}

void Video::close() {
	_print_debug("Closing video file on path: " + path);
	loaded = false;

	if (av_frame) av_frame_free(&av_frame);
	if (av_hw_frame) av_frame_free(&av_hw_frame);
	if (av_packet) av_packet_free(&av_packet);

	if (av_codec_ctx_video) avcodec_free_context(&av_codec_ctx_video);
	if (av_format_ctx) avformat_close_input(&av_format_ctx);

	if (sws_ctx) sws_freeContext(sws_ctx);

	av_frame = nullptr;
	av_packet = nullptr;
	hw_device_ctx = nullptr;

	av_codec_ctx_video = nullptr;
	av_format_ctx = nullptr;
}

int Video::seek_frame(int a_frame_nr) {
	if (!loaded)
		return GoZenError::ERR_NOT_OPEN_VIDEO;

	// Video seeking
	if ((response = _seek_frame(a_frame_nr)) < 0)
		return GoZenError::ERR_SEEKING;
	
	while (true) {
		if ((response = FFmpeg::get_frame(av_format_ctx, av_codec_ctx_video, av_stream_video->index, av_frame, av_packet))) {
			if (response == AVERROR_EOF) {
				_printerr_debug("End of file reached! Going back 1 frame!");

				if ((response = _seek_frame(a_frame_nr--)) < 0)
					return GoZenError::ERR_SEEKING;

				continue;
			}
			FFmpeg::print_av_error("Problem happened getting frame in seek_frame! ", response);
			response = 1;
			break;
		}

		// Get frame pts
		current_pts = av_frame->best_effort_timestamp == AV_NOPTS_VALUE ? av_frame->pts : av_frame->best_effort_timestamp;
		if (current_pts == AV_NOPTS_VALUE)
			continue;

		// Skip to actual requested frame
		if ((int64_t)(current_pts * stream_time_base_video) / 10000 >=
			frame_timestamp / 10000) {
			_copy_frame_data();
			break;
		}
	}

	av_frame_unref(av_frame);
	av_packet_unref(av_packet);

	return OK;
}

bool Video::next_frame(bool a_skip) {
	if (!loaded)
		return false;

	FFmpeg::get_frame(av_format_ctx, av_codec_ctx_video, av_stream_video->index, av_frame, av_packet);

	if (!a_skip)
		_copy_frame_data();

	av_frame_unref(av_frame);
	av_packet_unref(av_packet);
	
	return true;
}

void Video::_copy_frame_data() {
	if (hw_decoding && av_frame->format == hw_pix_fmt) {
		if (av_hwframe_transfer_data(av_hw_frame, av_frame, 0) < 0) {
			UtilityFunctions::printerr("Error transferring the frame to system memory!");
			return;
		} else if (av_hw_frame->data[0] == nullptr) {
			_printerr_debug("Frame is empty!");
			return;
		}

		memcpy(y_data.ptrw(), av_hw_frame->data[0], y_data.size());
		memcpy(u_data.ptrw(), av_hw_frame->data[1], u_data.size());

		av_frame_unref(av_hw_frame);
		return;
	} else {
		if (av_frame->data[0] == nullptr) {
			_printerr_debug("Frame is empty!");
			return;
		}

		if (using_sws) {
			sws_scale_frame(sws_ctx, av_hw_frame, av_frame);

			memcpy(y_data.ptrw(), av_hw_frame->data[0], y_data.size());
			memcpy(u_data.ptrw(), av_hw_frame->data[1], u_data.size());
			memcpy(v_data.ptrw(), av_hw_frame->data[2], v_data.size());

			av_frame_unref(av_hw_frame);
		} else {
			memcpy(y_data.ptrw(), av_frame->data[0], y_data.size());
			memcpy(u_data.ptrw(), av_frame->data[1], u_data.size());
			memcpy(v_data.ptrw(), av_frame->data[2], v_data.size());
		}

		return;
	}
}

const AVCodec *Video::_get_hw_codec() {
	const AVCodec *l_codec;
	AVHWDeviceType l_type = AV_HWDEVICE_TYPE_NONE;

	if (prefered_hw_decoder != "") {
		l_type = av_hwdevice_find_type_by_name(prefered_hw_decoder.c_str());
		l_codec = avcodec_find_decoder(av_stream_video->codecpar->codec_id);

		const char *l_device_name = l_type == AV_HWDEVICE_TYPE_VULKAN ? RenderingServer::get_singleton()->get_video_adapter_name().utf8() : nullptr;

        if ((response = av_hwdevice_ctx_create(&hw_device_ctx, l_type, l_device_name, nullptr, 0)) < 0) {
			FFmpeg::print_av_error("Selected hw device couldn't be created!", response);
		} else if (!av_codec_is_decoder(l_codec)) {
			UtilityFunctions::printerr("Found codec isn't a hw decoder!");
		} else {
			_print_debug(std::string("Using HW device: ") + av_hwdevice_get_type_name(l_type));
			hw_decoder = l_type;

			return l_codec;
		}
	}
	av_buffer_unref(&hw_device_ctx);

	l_type = AV_HWDEVICE_TYPE_NONE;
    while ((l_type = av_hwdevice_iterate_types(l_type)) != AV_HWDEVICE_TYPE_NONE) {
		const char *l_device_name = l_type == AV_HWDEVICE_TYPE_VULKAN ? RenderingServer::get_singleton()->get_video_adapter_name().utf8() : nullptr;

		l_codec = avcodec_find_decoder(av_stream_video->codecpar->codec_id);

		if (av_hwdevice_ctx_create(&hw_device_ctx, l_type, l_device_name, nullptr, 0) < 0)
			continue;

        if (av_codec_is_decoder(l_codec)) {
			_print_debug(std::string("Using HW device: ") + av_hwdevice_get_type_name(l_type));
			hw_decoder = l_type;

			return l_codec;
		}
		av_buffer_unref(&hw_device_ctx);
	}

	hw_decoding = false;
	_print_debug("HW decoding not possible, switching to software decoding!");
	return avcodec_find_decoder(av_stream_video->codecpar->codec_id);
}
 

int Video::_seek_frame(int a_frame_nr) {
	avcodec_flush_buffers(av_codec_ctx_video);

	frame_timestamp = (int64_t)(a_frame_nr * average_frame_duration);
	return av_seek_frame(av_format_ctx, -1, (start_time_video + frame_timestamp) / 10, AVSEEK_FLAG_BACKWARD | AVSEEK_FLAG_FRAME);
}

void Video::_print_debug(std::string a_text) {
	if (debug)
		UtilityFunctions::print(a_text.c_str());
}

void Video::_printerr_debug(std::string a_text) {
	if (debug)
		UtilityFunctions::print(a_text.c_str());
}
