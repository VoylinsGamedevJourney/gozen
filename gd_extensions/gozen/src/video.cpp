#include "video.hpp"


void Video::open(String a_path) {

	// Opening video
	av_format_ctx = avformat_alloc_context();
	if (!av_format_ctx)
		 return printerr("Couldn't allocate av format context!");
	if (avformat_open_input(&av_format_ctx, a_path.utf8(), NULL, NULL))
		return printerr("Couldn't open video file!");
	if (avformat_find_stream_info(av_format_ctx, NULL))
		return printerr("Couldn't find stream info!");

	// Getting the audio and video stream
	AVStream* av_stream_audio;
	for (int i = 0; i < av_format_ctx->nb_streams; i++) {
		AVCodecParameters* av_codec_params = av_format_ctx->streams[i]->codecpar;

		// TODO: Find way to get all streams and save them in arrays instead
		if (!avcodec_find_decoder(av_codec_params->codec_id))
			continue;
		else if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO)
			av_stream_audio = av_format_ctx->streams[i];
		else if (av_codec_params->codec_type == AVMEDIA_TYPE_VIDEO)
			av_stream = av_format_ctx->streams[i];
	}

// Video Decoder Setup 
	// Setup Decoder codec context
	const AVCodec* av_codec_video = avcodec_find_decoder(av_stream->codecpar->codec_id);
	if (!av_codec_video)
		return printerr("Couldn't find any codec decoder for video!");

	// Allocate codec context for decoder
	av_codec_ctx = avcodec_alloc_context3(av_codec_video);
	if (av_codec_ctx == NULL)
		return printerr("Couldn't allocate codec context for video!");

	// Copying parameters
	if (avcodec_parameters_to_context(av_codec_ctx, av_stream->codecpar))
		return printerr("Couldn't initialize video codec context!");

	// Enable multi-threading for decoding - Video
	// set codec to automatically determine how many threads suits best for the decoding job
	av_codec_ctx->thread_count = 0;
	if (av_codec_video->capabilities & AV_CODEC_CAP_FRAME_THREADS)
		av_codec_ctx->thread_type = FF_THREAD_FRAME;
	else if (av_codec_video->capabilities & AV_CODEC_CAP_SLICE_THREADS)
		av_codec_ctx->thread_type = FF_THREAD_SLICE;
	else av_codec_ctx->thread_count = 1; //don't use multithreading

	// Open codec
	if (avcodec_open2(av_codec_ctx, av_codec_video, NULL))
		return printerr("Couldn't open video codec!");

	// Setup SWS context for converting frame from YUV to RGB
	sws_ctx = sws_getContext(
		av_codec_ctx->width, av_codec_ctx->height, (AVPixelFormat)av_stream->codecpar->format,
		av_codec_ctx->width, av_codec_ctx->height, AV_PIX_FMT_RGB24,
		SWS_BILINEAR, NULL, NULL, NULL);
	if (!sws_ctx)
		return printerr("Couldn't get SWS context!");

	// Byte_array setup
	byte_array.resize(av_codec_ctx->width * av_codec_ctx->height * 3);
	src_linesize[0] = av_codec_ctx->width * 3;

	// Set other variables
	stream_time_base_video = av_q2d(av_stream->time_base) * 1000.0 * 10000.0; // Converting timebase to ticks
	start_time_video = av_stream->start_time != AV_NOPTS_VALUE ? (long)(av_stream->start_time * stream_time_base_video): 0;
	average_frame_duration = 10000000.0 / av_q2d(av_stream->avg_frame_rate);  // eg. 1 sec / 25 fps = 400.000 ticks (40ms)

	_get_total_frame_nr();


// Audio Decoder Setup 
	// Setup Decoder codec context
	const AVCodec* av_codec_audio = avcodec_find_decoder(av_stream_audio->codecpar->codec_id);
	if (!av_codec_audio)
		return printerr("Couldn't find any codec decoder for audio!");

	// Allocate codec context for decoder
	AVCodecContext* av_codec_ctx_audio = avcodec_alloc_context3(av_codec_audio);
	if (av_codec_ctx_audio == NULL)
		return printerr("Couldn't allocate codec context for audio!");

	// Copying parameters
	if (avcodec_parameters_to_context(av_codec_ctx_audio, av_stream_audio->codecpar))
		return printerr("Couldn't initialize audio codec context!");

	// Enable multi-threading for decoding - Audio
	// set codec to automatically determine how many threads suits best for the decoding job
	av_codec_ctx_audio->thread_count = 0;
	if (av_codec_audio->capabilities & AV_CODEC_CAP_FRAME_THREADS)
		av_codec_ctx_audio->thread_type = FF_THREAD_FRAME;
	else if (av_codec_audio->capabilities & AV_CODEC_CAP_SLICE_THREADS)
		av_codec_ctx_audio->thread_type = FF_THREAD_SLICE;
	else av_codec_ctx_audio->thread_count = 1; //don't use multithreading

	// Open codec
	if (avcodec_open2(av_codec_ctx_audio, av_codec_audio, NULL))
		return printerr("Couldn't open audio codec!");

	av_codec_ctx_audio->request_sample_fmt = AV_SAMPLE_FMT_S16;

	// Setup SWR for converting frame
	struct SwrContext* swr_ctx = nullptr;
	response = swr_alloc_set_opts2(
		&swr_ctx,
		&av_codec_ctx_audio->ch_layout, AV_SAMPLE_FMT_S16, av_codec_ctx_audio->sample_rate,
		&av_codec_ctx_audio->ch_layout, av_codec_ctx_audio->sample_fmt, av_codec_ctx_audio->sample_rate,
		0, nullptr);
	if (response < 0)
		return print_av_error("Failed to obtain SWR context!");
	else if (!swr_ctx)
		return printerr("Could not allocate re-sampler context!");

	response = swr_init(swr_ctx);
	if (response < 0)
		return print_av_error("Couldn't initialize SWR!");

	// Setting up variables for audio
	stream_time_base_audio = av_q2d(av_stream_audio->time_base) * 1000.0 * 10000.0; // Converting timebase to ticks
	start_time_audio = av_stream_audio->start_time != AV_NOPTS_VALUE ? (long)(av_stream_audio->start_time * stream_time_base_audio): 0;

// Getting the audio
	// Set the seeker to the beginning of audio stream
	response = av_seek_frame(av_format_ctx, av_stream_audio->index, start_time_audio, AVSEEK_FLAG_FRAME | AVSEEK_FLAG_ANY);
	avcodec_flush_buffers(av_codec_ctx_audio);
	if (response < 0)
		return printerr("Can't seek to the beginning of audio!");

	av_packet = av_packet_alloc();
	av_frame = av_frame_alloc();
	AVFrame* l_av_new_frame = nullptr;
	PackedByteArray l_audio_data = PackedByteArray();
	size_t l_audio_size = 0;

	while (av_read_frame(av_format_ctx, av_packet) >= 0) {
		
		if (av_packet->stream_index == av_stream_audio->index) {

			response = avcodec_send_packet(av_codec_ctx_audio, av_packet);
			if (response < 0) {
				UtilityFunctions::printerr("Error decoding audio packet!");
				av_packet_unref(av_packet);
				break;
			}

			while (response >= 0) {
				response = avcodec_receive_frame(av_codec_ctx_audio, av_frame);
				if (response == AVERROR(EAGAIN) || response == AVERROR_EOF)
					break;
				else if (response < 0) {
					UtilityFunctions::printerr("Error decoding audio frame!");
					break;
				}

				// Copy decoded data to new frame
				l_av_new_frame = av_frame_alloc();
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

				response = swr_convert_frame(swr_ctx, l_av_new_frame, av_frame);
				if (response < 0) {
					print_av_error("Couldn't convert the frame!");
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
		}
		av_packet_unref(av_packet);
	}

	// Audio stream settings
	audio_stream_wav->set_format(audio_stream_wav->FORMAT_16_BITS);
	audio_stream_wav->set_mix_rate(av_codec_ctx_audio->sample_rate);
	audio_stream_wav->set_stereo(av_codec_ctx_audio->ch_layout.nb_channels >= 2);
	audio_stream_wav->set_data(l_audio_data);

	// Cleanup
	av_packet_free(&av_packet);
	av_frame_free(&av_frame);
	av_frame_free(&l_av_new_frame);
	avcodec_free_context(&av_codec_ctx_audio);
	swr_free(&swr_ctx);

	is_open = true;
}


void Video::close() {
	is_open = false;

	if (av_format_ctx)
		avformat_close_input(&av_format_ctx);

	if (av_codec_ctx)
		avcodec_free_context(&av_codec_ctx);
	if (sws_ctx)
		sws_freeContext(sws_ctx);

	if (av_frame)
		av_frame_free(&av_frame);
	if (av_packet)
		av_packet_free(&av_packet);
}


Ref<Image> Video::seek_frame(int a_frame_nr) {

	Ref<Image> l_image = memnew(Image);

	if (!is_open) {
		UtilityFunctions::printerr("Video isn't open yet!");
		return l_image;
	}

	av_packet = av_packet_alloc();
	av_frame = av_frame_alloc();

	// Video seeking
	frame_timestamp = (long)(a_frame_nr * average_frame_duration);
	response = av_seek_frame(av_format_ctx, -1, (start_time_video + frame_timestamp) / 10, AVSEEK_FLAG_FRAME | AVSEEK_FLAG_BACKWARD);
	avcodec_flush_buffers(av_codec_ctx);
	if (response < 0) {
		UtilityFunctions::printerr("Can't seek video file!");
		av_frame_free(&av_frame);
		av_packet_free(&av_packet);
		return l_image;
	}

	while (true) {
		
		// Demux packet
		response = av_read_frame(av_format_ctx, av_packet);
		if (response != 0)
			break;
		if (av_packet->stream_index != av_stream->index) {
			av_packet_unref(av_packet);
			continue;
		}

		// Send packet for decoding
		response = avcodec_send_packet(av_codec_ctx, av_packet);
		av_packet_unref(av_packet);
		if (response != 0)
			break;

		// Valid packet found, decode frame
		while (true) {
			
			// Receive all frames
			response = avcodec_receive_frame(av_codec_ctx, av_frame);
			if (response != 0) {
				av_frame_unref(av_frame);
				break;
			}

			// Get frame pts
			current_pts = av_frame->best_effort_timestamp == AV_NOPTS_VALUE ? av_frame->pts : av_frame->best_effort_timestamp;
			if (current_pts == AV_NOPTS_VALUE) {
				av_frame_unref(av_frame);
				continue;
			}

			// Skip to actual requested frame
			if ((long)(current_pts * stream_time_base_video) / 10000 < frame_timestamp / 10000) {
				av_frame_unref(av_frame);
				continue;
			}

			uint8_t* l_dest_data[1] = { byte_array.ptrw() };
			sws_scale(sws_ctx, av_frame->data, av_frame->linesize, 0, av_frame->height, l_dest_data, src_linesize);
			l_image->set_data(av_frame->width, av_frame->height, 0, l_image->FORMAT_RGB8, byte_array);

			// Cleanup
			av_frame_unref(av_frame);
			av_frame_free(&av_frame);
			av_packet_free(&av_packet);
			
			return l_image;
		} 
	}

	// Cleanup
	av_frame_free(&av_frame);
	av_packet_free(&av_packet);

	return l_image;
}


Ref<Image> Video::next_frame() {
	
	Ref<Image> l_image = memnew(Image);

	if (!is_open) {
		UtilityFunctions::printerr("Video isn't open yet!");
		return l_image;
	}

	av_packet = av_packet_alloc();
	av_frame = av_frame_alloc();

	while (true) {
		
		// Demux packet
		response = av_read_frame(av_format_ctx, av_packet);
		if (response != 0)
			break;
		if (av_packet->stream_index != av_stream->index) {
			av_packet_unref(av_packet);
			continue;
		}

		// Send packet for decoding
		response = avcodec_send_packet(av_codec_ctx, av_packet);
		av_packet_unref(av_packet);
		if (response != 0)
			break;

		// Valid packet found, decode frame
		while (true) {
			
			// Receive all frames
			response = avcodec_receive_frame(av_codec_ctx, av_frame);
			if (response != 0) {
				av_frame_unref(av_frame);
				break;
			}

			uint8_t* l_dest_data[1] = { byte_array.ptrw() };
			sws_scale(sws_ctx, av_frame->data, av_frame->linesize, 0, av_frame->height, l_dest_data, src_linesize);
			l_image->set_data(av_frame->width, av_frame->height, 0, l_image->FORMAT_RGB8, byte_array);

			// Cleanup
			av_frame_unref(av_frame);
			av_frame_free(&av_frame);
			av_packet_free(&av_packet);
			
			return l_image;
		} 
	}

	// Cleanup
	av_frame_free(&av_frame);
	av_packet_free(&av_packet);

	return l_image;
}


void Video::_get_total_frame_nr() {

	if (av_stream->nb_frames > 500)
		total_frame_number = av_stream->nb_frames - 30;
	
	av_packet = av_packet_alloc();
	av_frame = av_frame_alloc();
	
	// Video seeking
	frame_timestamp = (long)(total_frame_number * average_frame_duration);
	response = av_seek_frame(av_format_ctx, -1, (start_time_video + frame_timestamp) / 10, AVSEEK_FLAG_FRAME | AVSEEK_FLAG_BACKWARD);
	avcodec_flush_buffers(av_codec_ctx);
	if (response < 0) {
		UtilityFunctions::printerr("Can't seek video stream!");
		av_frame_free(&av_frame);
		av_packet_free(&av_packet);
	}

	while (true) {
		
		// Demux packet
		response = av_read_frame(av_format_ctx, av_packet);
		if (response != 0)
			break;
		if (av_packet->stream_index != av_stream->index) {
			av_packet_unref(av_packet);
			continue;
		}

		// Send packet for decoding
		response = avcodec_send_packet(av_codec_ctx, av_packet);
		av_packet_unref(av_packet);
		if (response != 0)
			break;

		// Valid packet found, decode frame
		while (true) {
			
			// Receive all frames
			response = avcodec_receive_frame(av_codec_ctx, av_frame);
			if (response != 0) {
				av_frame_unref(av_frame);
				break;
			}

			// Get frame pts
			current_pts = av_frame->best_effort_timestamp == AV_NOPTS_VALUE ? av_frame->pts : av_frame->best_effort_timestamp;
			if (current_pts == AV_NOPTS_VALUE) {
				av_frame_unref(av_frame);
				continue;
			}

			// Skip to actual requested frame
			if ((long)(current_pts * stream_time_base_video) / 10000 < frame_timestamp / 10000) {
				av_frame_unref(av_frame);
				continue;
			}

			total_frame_number++;
		} 
	}
}


void Video::printerr(String a_message) {
	UtilityFunctions::printerr(a_message);
	close();
}


void Video::print_av_error(String a_message) {
	char l_error_buffer[AV_ERROR_MAX_STRING_SIZE];
	av_strerror(response, l_error_buffer, sizeof(l_error_buffer));
	UtilityFunctions::printerr(a_message + l_error_buffer);
	close();
}


Dictionary Video::get_video_file_meta(String a_file_path) {
	AVFormatContext *l_format_ctx = NULL;
	const AVDictionaryEntry *l_tag = NULL;
	Dictionary l_meta = {};
 
	if (avformat_open_input(&l_format_ctx, a_file_path.utf8(), NULL, NULL)) {
		UtilityFunctions::printerr("Could not open file!");
		return l_meta;
	}
	
	if (avformat_find_stream_info(l_format_ctx, NULL) < 0) {
		UtilityFunctions::printerr("Could not find stream info!");
		return l_meta;
	}
	
	while (l_tag = av_dict_iterate(l_format_ctx->metadata, l_tag))
		l_meta[l_tag->key] = l_tag->value;
	
	avformat_close_input(&l_format_ctx);
	return l_meta;
}


void Video::_bind_methods() {
	ClassDB::bind_method(D_METHOD("open", "a_path"), &Video::open);
	ClassDB::bind_method(D_METHOD("close"), &Video::close);

	ClassDB::bind_method(D_METHOD("seek_frame", "a_frame_nr"), &Video::seek_frame);
	ClassDB::bind_method(D_METHOD("next_frame"), &Video::next_frame);
	ClassDB::bind_method(D_METHOD("get_audio"), &Video::get_audio);

	ClassDB::bind_method(D_METHOD("get_framerate"), &Video::get_framerate);
	ClassDB::bind_method(D_METHOD("get_total_frame_nr"), &Video::get_total_frame_nr);
	ClassDB::bind_method(D_METHOD("get_size"), &Video::get_size);

	ClassDB::bind_static_method("Video", D_METHOD("get_video_file_meta", "a_file_path:String"), &Video::get_video_file_meta);
}
