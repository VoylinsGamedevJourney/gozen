#include "video.hpp"


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

Ref<Video> Video::open_new(String a_path, bool a_load_audio) {
	Ref<Video> l_video = memnew(Video);
	l_video->open(a_path, a_load_audio);
	return l_video;
}


int Video::open(String a_path, bool a_load_audio) {
	if (loaded)
		close();

	// Allocate video file context
	av_format_ctx = avformat_alloc_context();
	if (!av_format_ctx) {
		UtilityFunctions::printerr("Couldn't allocate av format context!");
		return -1;
	}

	// Open file with avformat
	if (avformat_open_input(&av_format_ctx, a_path.utf8(), NULL, NULL)) {
		UtilityFunctions::printerr("Couldn't open video file!");
		close();
		return -1;
	}

	// Find stream information
	if (avformat_find_stream_info(av_format_ctx, NULL)) {
		UtilityFunctions::printerr("Couldn't find stream info!");
		close();
		return -1;
	}

	// Getting the audio and video stream
	for (int i = 0; i < av_format_ctx->nb_streams; i++) {
		AVCodecParameters *av_codec_params = av_format_ctx->streams[i]->codecpar;

		if (!avcodec_find_decoder(av_codec_params->codec_id))
			continue;
		else if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO) {
			av_stream_audio = av_format_ctx->streams[i];
			if (a_load_audio && (response = _get_audio()) != 0) {
				close();
				return response;
			}
		} else if (av_codec_params->codec_type == AVMEDIA_TYPE_VIDEO)
			av_stream_video = av_format_ctx->streams[i];
	}

	// TODO: Implement hardware decoding
	//	"vaapi", "qsv", "vulkan", "vdpau", "nvdec"
	//
	// Setup Decoder codec context
	const AVCodec *av_codec_video = avcodec_find_decoder(av_stream_video->codecpar->codec_id);
	if (!av_codec_video) {
		UtilityFunctions::printerr("Couldn't find any codec decoder for video!");
		close();
		return -3;
	}
	

	// Allocate codec context for decoder
	av_codec_ctx_video = avcodec_alloc_context3(av_codec_video);
	if (av_codec_ctx_video == NULL) {
		UtilityFunctions::printerr("Couldn't allocate codec context for video!");
		close();
		return -3;
	}

	// Copying parameters
	if (avcodec_parameters_to_context(av_codec_ctx_video, av_stream_video->codecpar)) {
		UtilityFunctions::printerr("Couldn't initialize video codec context!");
		close();
		return -3;
	}

	// Open codec - Video
	if (avcodec_open2(av_codec_ctx_video, av_codec_video, NULL)) {
		UtilityFunctions::printerr("Couldn't open video codec!");
		close();
		return -3;
	}
	
	// Enable multi-threading for decoding - Video
	av_codec_ctx_video->thread_count = 0;
	if (av_codec_video->capabilities & AV_CODEC_CAP_FRAME_THREADS)
		av_codec_ctx_video->thread_type = FF_THREAD_FRAME;
	else if (av_codec_video->capabilities & AV_CODEC_CAP_SLICE_THREADS)
		av_codec_ctx_video->thread_type = FF_THREAD_SLICE;
	else
		av_codec_ctx_video->thread_count = 1; // Don't use multithreading
	
	resolution.x = av_codec_ctx_video->width;
	resolution.y = av_codec_ctx_video->height;

	float l_aspect_ratio = av_q2d(av_stream_video->codecpar->sample_aspect_ratio);
	if (l_aspect_ratio > 1.0) {
		resolution.x = static_cast<int>(std::round(resolution.x * l_aspect_ratio));
	}

	if ((AVPixelFormat)av_stream_video->codecpar->format != AV_PIX_FMT_YUV420P) {
		UtilityFunctions::printerr("Video has unsupported format!");
		UtilityFunctions::printerr(av_stream_video->codecpar->format);
		close();
		return -4;
	}

	start_time_video = av_stream_video->start_time != AV_NOPTS_VALUE ? (long)(av_stream_video->start_time * stream_time_base_video) : 0;

	// Getting some data out of first frame
	av_packet = av_packet_alloc();
	av_frame = av_frame_alloc();
	avcodec_flush_buffers(av_codec_ctx_video);
	bool l_duration_from_bitrate = av_format_ctx->duration_estimation_method == AVFMT_DURATION_FROM_BITRATE;
	if (l_duration_from_bitrate) {
		UtilityFunctions::printerr("This video file is not usable!");
		close();
		return -5;
	}
	response = av_seek_frame(av_format_ctx, -1, start_time_video, AVSEEK_FLAG_FRAME | AVSEEK_FLAG_ANY);
	if (response < 0) {
		print_av_error("Seeking to beginning error: ");
		close();
		return -5;
	}
	_get_frame(av_codec_ctx_video, av_stream_video->index);
	if (response) {
		print_av_error("Something went wrong getting first frame!");
		close();
		return -5;
	}

	// Checking for interlacing and what type of interlacing
	if (av_frame->flags & AV_FRAME_FLAG_INTERLACED)
		interlaced = av_frame->flags & AV_FRAME_FLAG_TOP_FIELD_FIRST ? 1 : 2;

	// Getting frame rate
	framerate = av_q2d(av_guess_frame_rate(av_format_ctx, av_stream_video, av_frame));
	if (framerate == 0) {
		UtilityFunctions::printerr("Invalid frame-rate for video found!");
		close();
		return -6;
	}

	// Setting variables
	average_frame_duration = 10000000.0 / framerate;								// eg. 1 sec / 25 fps = 400.000 ticks (40ms)
	stream_time_base_video = av_q2d(av_stream_video->time_base) * 1000.0 * 10000.0; // Converting timebase to ticks

	// Checking for variable framerate
	variable_framerate = av_codec_ctx_video->framerate.num == 0 || av_codec_ctx_video->framerate.den == 0;
	if (variable_framerate) {
		if (av_stream_video->r_frame_rate.num == av_stream_video->avg_frame_rate.num) {
			variable_framerate = false;
		} else {
			UtilityFunctions::printerr("Variable framerate detected, aborting! (not supported)");
			close();
			return -6;
		}
	}

	// Checking second frame
	_get_frame(av_codec_ctx_video, av_stream_video->index);
	if (response)
		print_av_error("Something went wrong getting second frame!");

	duration = av_format_ctx->duration;
	if (av_stream_video->duration == AV_NOPTS_VALUE || l_duration_from_bitrate) {
		if (duration == AV_NOPTS_VALUE || l_duration_from_bitrate) {
			UtilityFunctions::printerr("Video file is not usable!");
			close();
			return -7;
		} else {
			AVRational l_temp_rational = AVRational{1, AV_TIME_BASE};
			if (l_temp_rational.num != av_stream_video->time_base.num || l_temp_rational.num != av_stream_video->time_base.num)
				duration = std::ceil(static_cast<double>(duration) * av_q2d(l_temp_rational) / av_q2d(av_stream_video->time_base));
		}
		av_stream_video->duration = duration;
	}

	frame_duration = (static_cast<double>(duration) / static_cast<double>(AV_TIME_BASE)) * framerate;
	y.resize(av_frame->linesize[0] * resolution.y);
	u.resize((av_frame->linesize[0] / 2) * (resolution.y / 2));
	v.resize((av_frame->linesize[0] / 2) * (resolution.y / 2));

	av_packet_free(&av_packet);
	av_frame_free(&av_frame);

	loaded = true;
	path = a_path;
	response = OK;

	return OK;
}

void Video::close() {
	if (audio)
		memdelete(audio);

	loaded = false;

	if (av_format_ctx)
		avformat_close_input(&av_format_ctx);
	if (av_codec_ctx_video)
		avcodec_free_context(&av_codec_ctx_video);

	if (av_frame)
		av_frame_free(&av_frame);
	if (av_packet)
		av_packet_free(&av_packet);
}

void Video::print_av_error(const char *a_message) {
	char l_error_buffer[AV_ERROR_MAX_STRING_SIZE];
	av_strerror(response, l_error_buffer, sizeof(l_error_buffer));
	UtilityFunctions::printerr((std::string(a_message) + l_error_buffer).c_str());
}

int Video::_get_audio() {
	audio = memnew(AudioStreamWAV);

	// Audio Decoder Setup
	const AVCodec *av_codec_audio = avcodec_find_decoder(av_stream_audio->codecpar->codec_id);
	if (!av_codec_audio) {
		UtilityFunctions::printerr("Couldn't find any codec decoder for audio!");
		close();
		return -2;
	}

	// Allocate codec context for decoder
	AVCodecContext *av_codec_ctx_audio = avcodec_alloc_context3(av_codec_audio);
	if (av_codec_ctx_audio == NULL) {
		UtilityFunctions::printerr("Couldn't allocate codec context for audio!");
		close();
		return -2;
	}

	// Copying parameters
	if (avcodec_parameters_to_context(av_codec_ctx_audio, av_stream_audio->codecpar)) {
		UtilityFunctions::printerr("Couldn't initialize audio codec context!");
		close();
		return -2;
	}

	// Open codec - Audio
	if (avcodec_open2(av_codec_ctx_audio, av_codec_audio, NULL)) {
		UtilityFunctions::printerr("Couldn't open audio codec!");
		close();
		return -2;
	}

	// Enable multi-threading for decoding - Audio
	// set codec to automatically determine how many threads suits best for the
	// decoding job
	av_codec_ctx_audio->thread_count = 0;
	if (av_codec_audio->capabilities & AV_CODEC_CAP_FRAME_THREADS)
		av_codec_ctx_audio->thread_type = FF_THREAD_FRAME;
	else if (av_codec_audio->capabilities & AV_CODEC_CAP_SLICE_THREADS)
		av_codec_ctx_audio->thread_type = FF_THREAD_SLICE;
	else
		av_codec_ctx_audio->thread_count = 1; // don't use multithreading

	av_codec_ctx_audio->request_sample_fmt = AV_SAMPLE_FMT_S16;

	// Setup SWR for converting frame
	struct SwrContext *swr_ctx = nullptr;
	response = swr_alloc_set_opts2(
		&swr_ctx, &av_codec_ctx_audio->ch_layout, AV_SAMPLE_FMT_S16, av_codec_ctx_audio->sample_rate,
		&av_codec_ctx_audio->ch_layout, av_codec_ctx_audio->sample_fmt, av_codec_ctx_audio->sample_rate, 0,
		nullptr);
	if (response < 0) {
		print_av_error("Failed to obtain SWR context!");
		close();
		return -8;
	} else if (!swr_ctx) {
		UtilityFunctions::printerr("Could not allocate re-sampler context!");
		close();
		return -8;
	}

	response = swr_init(swr_ctx);
	if (response < 0) {
		print_av_error("Couldn't initialize SWR!");
		close();
		return -8;
	}

	// Set the seeker to the beginning
	int start_time_audio = av_stream_audio->start_time != AV_NOPTS_VALUE ? av_stream_audio->start_time : 0;
	avcodec_flush_buffers(av_codec_ctx_audio);
	response = av_seek_frame(av_format_ctx, -1, start_time_audio, AVSEEK_FLAG_FRAME | AVSEEK_FLAG_ANY);
	if (response < 0) {
		UtilityFunctions::printerr("Can't seek to the beginning of audio stream!");
		return -9;
	}

	av_packet = av_packet_alloc();
	av_frame = av_frame_alloc();
	PackedByteArray l_audio_data = PackedByteArray();
	size_t l_audio_size = 0;

	while (true) {
		_get_frame(av_codec_ctx_audio, av_stream_audio->index);
		if (response)
			break;

		// Copy decoded data to new frame
		AVFrame *l_av_new_frame = av_frame_alloc();
		l_av_new_frame->format = AV_SAMPLE_FMT_S16;
		l_av_new_frame->ch_layout = av_frame->ch_layout;
		l_av_new_frame->sample_rate = av_frame->sample_rate;
		l_av_new_frame->nb_samples = swr_get_out_samples(swr_ctx, av_frame->nb_samples);

		response = av_frame_get_buffer(l_av_new_frame, 0);
		if (response < 0) {
			print_av_error("Couldn't create new frame for swr!");
			av_frame_unref(av_frame);
			av_frame_unref(l_av_new_frame);
			break;
		}

		response = swr_config_frame(swr_ctx, l_av_new_frame, av_frame);
		if (response < 0) {
			print_av_error("Couldn't config the audio frame!");
			av_frame_unref(av_frame);
			av_frame_unref(l_av_new_frame);
			break;
		}

		response = swr_convert_frame(swr_ctx, l_av_new_frame, av_frame);
		if (response < 0) {
			print_av_error("Couldn't convert the audio frame!");
			av_frame_unref(av_frame);
			av_frame_unref(l_av_new_frame);
			break;
		}
		
		size_t l_byte_size = l_av_new_frame->nb_samples * av_get_bytes_per_sample(AV_SAMPLE_FMT_S16);
		if (av_codec_ctx_audio->ch_layout.nb_channels >= 2)
			l_byte_size *= 2;

		l_audio_data.resize(l_audio_size + l_byte_size);
		memcpy(&(l_audio_data.ptrw()[l_audio_size]), l_av_new_frame->extended_data[0], l_byte_size);
		l_audio_size += l_byte_size;

		av_frame_unref(av_frame);
		av_frame_unref(l_av_new_frame);
	}

	// Audio creation
	audio->set_format(audio->FORMAT_16_BITS);
	audio->set_mix_rate(av_codec_ctx_audio->sample_rate);
	audio->set_stereo(av_codec_ctx_audio->ch_layout.nb_channels >= 2);
	audio->set_data(l_audio_data);

	// Cleanup
	avcodec_flush_buffers(av_codec_ctx_audio);
	avcodec_free_context(&av_codec_ctx_audio);
	swr_free(&swr_ctx);
	av_frame_free(&av_frame);
	av_packet_free(&av_packet);

	return OK;
}

void Video::seek_frame(int a_frame_nr) {
	if (!loaded) {
		UtilityFunctions::printerr("Video isn't open yet!");
		return;
	}

	av_packet = av_packet_alloc();
	av_frame = av_frame_alloc();

	// Video seeking
	frame_timestamp = (long)(a_frame_nr * average_frame_duration);
	avcodec_flush_buffers(av_codec_ctx_video);
	response = av_seek_frame(av_format_ctx, -1, (start_time_video + frame_timestamp) / 10, AVSEEK_FLAG_FRAME | AVSEEK_FLAG_BACKWARD);
	if (response < 0) {
		UtilityFunctions::printerr("Can't seek video file!");
		return;
	}

	while (true) {
		_get_frame(av_codec_ctx_video, av_stream_video->index);
		if (response) {
			UtilityFunctions::printerr("Problem happened getting frame in seek_frame! ", response);
			break;
		}

		// Get frame pts
		current_pts = av_frame->best_effort_timestamp == AV_NOPTS_VALUE ? av_frame->pts : av_frame->best_effort_timestamp;
		if (current_pts == AV_NOPTS_VALUE)
			continue;

		// Skip to actual requested frame
		if ((long)(current_pts * stream_time_base_video) / 10000 < frame_timestamp / 10000)
			continue;
	
		memcpy(y.ptrw(), av_frame->data[0], y.size());
		memcpy(u.ptrw(), av_frame->data[1], u.size());
		memcpy(v.ptrw(), av_frame->data[2], v.size());

		break;
	}

	// Cleanup
	av_frame_free(&av_frame);
	av_packet_free(&av_packet);
}

void Video::next_frame(bool a_skip) {
	if (!loaded) {
		UtilityFunctions::printerr("Video isn't open yet!");
		return;
	}
	av_packet = av_packet_alloc();
	av_frame = av_frame_alloc();
	_get_frame(av_codec_ctx_video, av_stream_video->index);
	
	if (!a_skip) {
		memcpy(y.ptrw(), av_frame->data[0], y.size());
		memcpy(u.ptrw(), av_frame->data[1], u.size());
		memcpy(v.ptrw(), av_frame->data[2], v.size());
	}

	// Cleanup
	av_frame_free(&av_frame);
	av_packet_free(&av_packet);
}

void Video::_get_frame(AVCodecContext *a_codec_ctx, int a_stream_id) {
	bool l_eof = false;
	av_frame_unref(av_frame);
	while ((response = avcodec_receive_frame(a_codec_ctx, av_frame)) == AVERROR(EAGAIN) && !l_eof) {
		do {
			av_packet_unref(av_packet);
			response = av_read_frame(av_format_ctx, av_packet);
		} while (av_packet->stream_index != a_stream_id && response >= 0);

		if (response == AVERROR_EOF) {
			l_eof = true;
			avcodec_send_packet(a_codec_ctx, nullptr); // Send null packet to signal end
		} else if (response < 0) {
			UtilityFunctions::printerr("Error reading frame! ", response);
			break;
		} else {
			response = avcodec_send_packet(a_codec_ctx, av_packet);
			av_packet_unref(av_packet);
			if (response < 0) {
				UtilityFunctions::printerr("Problem sending package! ", response);
				break;
			}
		}
	}
}

