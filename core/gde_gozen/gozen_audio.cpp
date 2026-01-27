#include "gozen_audio.hpp"


PackedByteArray GoZenAudio::_get_audio(AVFormatContext*& format_ctx, AVStream*& stream, double start_time,
									   double duration) {
	const int TARGET_SAMPLE_RATE = 44100;
	const AVSampleFormat TARGET_FORMAT = AV_SAMPLE_FMT_S16;
	const AVChannelLayout TARGET_LAYOUT = AV_CHANNEL_LAYOUT_STEREO;

	UniqueAVCodecCtx codec_ctx;
	UniqueSwrCtx swr_ctx;
	UniqueAVPacket av_packet;
	UniqueAVFrame av_frame;
	UniqueAVFrame av_decoded_frame;

	PackedByteArray audio_data = PackedByteArray();

	const AVCodec* codec = avcodec_find_decoder(stream->codecpar->codec_id);
	if (!codec) {
		_log_err("Couldn't find any decoder for audio!");
		return audio_data;
	}

	codec_ctx = make_unique_ffmpeg<AVCodecContext, AVCodecCtxDeleter>(avcodec_alloc_context3(codec));
	if (codec_ctx == NULL) {
		_log_err("Couldn't allocate context for audio!");
		return audio_data;
	}
	if (avcodec_parameters_to_context(codec_ctx.get(), stream->codecpar)) {
		_log_err("Couldn't initialize audio codec context!");
		return audio_data;
	}

	FFmpeg::enable_multithreading(codec_ctx.get(), codec);
	codec_ctx->request_sample_fmt = TARGET_FORMAT;

	if (avcodec_open2(codec_ctx.get(), codec, NULL)) {
		_log_err("Couldn't open audio codec!");
		return audio_data;
	}

	int64_t seek_target = start_time * AV_TIME_BASE;

	if (start_time > 0) {
		av_seek_frame(format_ctx, stream->index, seek_target, AVSEEK_FLAG_BACKWARD);
		avcodec_flush_buffers(codec_ctx.get());
	}

	SwrContext* temp_swr_ctx = nullptr;
	int response = swr_alloc_set_opts2(&temp_swr_ctx,
									   &TARGET_LAYOUT,		   // Out channel layout: Stereo.
									   TARGET_FORMAT,		   // We need 16 bits.
									   TARGET_SAMPLE_RATE,	   // Sample rate should be the Godot default.
									   &codec_ctx->ch_layout,  // In channel layout.
									   codec_ctx->sample_fmt,  // In sample format.
									   codec_ctx->sample_rate, // In sample rate.
									   0, nullptr);
	swr_ctx = make_unique_ffmpeg<SwrContext, SwrCtxDeleter>(temp_swr_ctx);

	if (response < 0 || (response = swr_init(swr_ctx.get()))) {
		FFmpeg::print_av_error("GoZenAudio: Couldn't initialize SWR!", response);
		return audio_data;
	}

	av_packet = make_unique_avpacket();
	av_frame = make_unique_avframe();
	av_decoded_frame = make_unique_avframe();

	if (!av_frame || !av_decoded_frame || !av_packet) {
		_log_err("Couldn't allocate frames/packet for audio!");
		return audio_data;
	}

	int64_t max_bytes = -1;
	int bytes_per_sample = av_get_bytes_per_sample(TARGET_FORMAT);

	if (duration > 0) {
		max_bytes = (int64_t)(duration * TARGET_SAMPLE_RATE * bytes_per_sample * 2);
		audio_data.resize(max_bytes);
	} else {
		double stream_duration_sec = (stream->duration != AV_NOPTS_VALUE)
										 ? (stream->duration * av_q2d(stream->time_base))
										 : ((double)format_ctx->duration / AV_TIME_BASE);
		int64_t total_size = (size_t)(stream_duration_sec * TARGET_SAMPLE_RATE) * bytes_per_sample * 2;

		if (total_size >= 2147483600)
			return audio_data;

		audio_data.resize(total_size);
	}

	size_t current_size = 0;

	while (!(FFmpeg::get_frame(format_ctx, codec_ctx.get(), stream->index, av_frame.get(), av_packet.get()))) {
		if (av_frame->nb_samples <= 0)
			break;

		// Copy decoded data to new frame.
		av_decoded_frame->format = TARGET_FORMAT;
		av_decoded_frame->ch_layout = TARGET_LAYOUT;
		av_decoded_frame->sample_rate = TARGET_SAMPLE_RATE;
		av_decoded_frame->nb_samples = swr_get_out_samples(swr_ctx.get(), av_frame->nb_samples);

		if ((response = av_frame_get_buffer(av_decoded_frame.get(), 0)) < 0) {
			FFmpeg::print_av_error("GoZenAudio: Couldn't create new frame for swr!", response);
			av_frame_unref(av_frame.get());
			av_frame_unref(av_decoded_frame.get());
			break;
		}

		response = swr_convert_frame(swr_ctx.get(), av_decoded_frame.get(), av_frame.get());
		if (response < 0) {
			FFmpeg::print_av_error("GoZenAudio: Couldn't convert the audio frame!", response);
			av_frame_unref(av_frame.get());
			av_frame_unref(av_decoded_frame.get());
			break;
		}

		size_t byte_size = av_decoded_frame->nb_samples * bytes_per_sample * 2;
		if (current_size + byte_size > audio_data.size()) {
			size_t new_size = current_size + byte_size + 4096;
			audio_data.resize(new_size);
		}

		memcpy(&(audio_data.ptrw()[current_size]), av_decoded_frame->extended_data[0], byte_size);
		current_size += byte_size;

		av_frame_unref(av_frame.get());
		av_frame_unref(av_decoded_frame.get());

		if (max_bytes > 0 && current_size >= max_bytes)
			break;
	}

	if (current_size < audio_data.size())
		audio_data.resize(current_size);

	// Cleanup.
	avcodec_flush_buffers(codec_ctx.get());

	return audio_data;
}


PackedByteArray GoZenAudio::get_audio_data(String file_path, int stream_index, double start_time, double duration) {
	av_log_set_level(AV_LOG_VERBOSE);
	AVFormatContext* format_ctx = nullptr;
	PackedByteArray data = PackedByteArray();
	PackedByteArray file_buffer; // For `res://` videos.
	UniqueAVIOContext avio_ctx;
	BufferData buffer_data;

	if (file_path.begins_with("res://") || file_path.begins_with("user://")) {
		if (!(format_ctx = avformat_alloc_context())) {
			_log_err("Failed to allocate AVFormatContext");
			return data;
		}

		file_buffer = FileAccess::get_file_as_bytes(file_path);

		if (file_buffer.is_empty()) {
			avformat_free_context(format_ctx);
			_log_err("Couldn't load file from res:// at path '" + file_path + "'");
			return data;
		}

		buffer_data.ptr = file_buffer.ptrw();
		buffer_data.size = file_buffer.size();
		buffer_data.offset = 0;

		unsigned char* avio_ctx_buffer = (unsigned char*)av_malloc(FFmpeg::AVIO_CTX_BUFFER_SIZE);
		avio_ctx = make_unique_ffmpeg<AVIOContext, AVIOContextDeleter>(
			avio_alloc_context(avio_ctx_buffer, FFmpeg::AVIO_CTX_BUFFER_SIZE, 0, &buffer_data,
							   &FFmpeg::read_buffer_packet, nullptr, &FFmpeg::seek_buffer));

		if (!avio_ctx) {
			av_free(avio_ctx_buffer);
			_log_err("Failed to create avio_ctx");
			return data;
		}

		format_ctx->pb = avio_ctx.get();

		if (avformat_open_input(&format_ctx, nullptr, nullptr, nullptr) != 0) {
			_log_err("Failed to open input from memory buffer");
			return data;
		}

	} else if (avformat_open_input(&format_ctx, file_path.utf8(), NULL, NULL)) {
		_log_err("Couldn't open audio");
		return data;
	}

	if (avformat_find_stream_info(format_ctx, NULL)) {
		_log_err("Couldn't find stream info");
		return data;
	}

	if (stream_index == -1) {
		for (int i = 0; i < format_ctx->nb_streams; i++) {
			AVCodecParameters* av_codec_params = format_ctx->streams[i]->codecpar;

			if (!avcodec_find_decoder(av_codec_params->codec_id)) {
				format_ctx->streams[i]->discard = AVDISCARD_ALL;
				continue;
			} else if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO) {
				stream_index = i;
				break;
			}
		}
	}

	// Discard all non-audio streams.
	for (int i = 0; i < format_ctx->nb_streams; i++) {
		AVCodecParameters* av_codec_params = format_ctx->streams[i]->codecpar;
		if (!avcodec_find_decoder(av_codec_params->codec_id) || av_codec_params->codec_type != AVMEDIA_TYPE_AUDIO) {
			if (i != stream_index) {
				format_ctx->streams[i]->discard = AVDISCARD_ALL;
			}
		}
	}

	if (stream_index >= 0 && stream_index < format_ctx->nb_streams) {
		AVCodecParameters* av_codec_params = format_ctx->streams[stream_index]->codecpar;

		if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO)
			data = _get_audio(format_ctx, format_ctx->streams[stream_index], start_time, duration);
	} else {
		_log_err("Invalid stream index");
		return data;
	}


	avformat_close_input(&format_ctx);
	av_log_set_level(AV_LOG_INFO);
	return data;
}


PackedByteArray GoZenAudio::combine_data(PackedByteArray audio_one, PackedByteArray audio_two) {
	const int16_t* p_one = (const int16_t*)audio_one.ptr();
	const int16_t* p_two = (const int16_t*)audio_two.ptr();

	for (size_t i = 0; i < audio_one.size() / 2; i++)
		((int16_t*)audio_one.ptrw())[i] = Math::clamp(p_one[i] + p_two[i], -32768, 32767);

	return audio_one;
}


PackedByteArray GoZenAudio::change_db(PackedByteArray audio_data, float db) {
	static std::unordered_map<int, double> cache;

	const size_t sample_count = audio_data.size() / 2;
	const int16_t* p_data = reinterpret_cast<const int16_t*>(audio_data.ptr());
	int16_t* pw_data = reinterpret_cast<int16_t*>(audio_data.ptrw());

	const auto search = cache.find(db);
	double value;

	if (search == cache.end()) {
		value = std::pow(10.0, db / 20.0);
		cache[db] = value;
	} else
		value = search->second;

	for (size_t i = 0; i < sample_count; i++)
		pw_data[i] = Math::clamp((int32_t)(p_data[i] * value), -32768, 32767);

	return audio_data;
}


PackedByteArray GoZenAudio::change_to_mono(PackedByteArray audio_data, bool left) {
	const size_t sample_count = audio_data.size() / 2;
	const int16_t* p_data = (const int16_t*)audio_data.ptr();
	int16_t* pw_data = reinterpret_cast<int16_t*>(audio_data.ptrw());

	if (left) {
		for (size_t i = 0; i < sample_count; i += 2)
			pw_data[i + 1] = p_data[i];
	} else {
		for (size_t i = 0; i < sample_count; i += 2)
			pw_data[i] = p_data[i + 1];
	}

	return audio_data;
}


PackedByteArray GoZenAudio::apply_fade(PackedByteArray audio_data, int fade_in_samples, int fade_out_samples) {
	int16_t* samples = (int16_t*)audio_data.ptrw();
	int sample_count = audio_data.size() / 2; // 16-bit stereo samples

	// Apply fade in
	if (fade_in_samples > 0) {
		for (int i = 0; i < fade_in_samples * 2 && i < sample_count; i += 2) {
			float volume = (float)(i / 2.0) / (float)fade_in_samples;

			samples[i] = (int16_t)(samples[i] * volume); // Left
			samples[i + 1] = (int16_t)(samples[i + 1] * volume); // Right
		}
	}

	// Apply fade out
	int total_stereo_frames = sample_count / 2;
	int fade_out_start = total_stereo_frames - fade_out_samples;

	if (fade_out_samples > 0 && fade_out_start < total_stereo_frames) {
		int start_index = std::max(0, fade_out_start) * 2;

		for (int i = start_index; i < sample_count; i += 2) {
			int current_frame = i / 2;
			int frames_into_fade = current_frame - fade_out_start;
			float volume = 1.0f - ((float)frames_into_fade / (float)fade_out_samples);
			if (volume < 0.0f) volume = 0.0f;

			samples[i] = (int16_t)(samples[i] * volume); // Left
			samples[i + 1] = (int16_t)(samples[i + 1] * volume); // Right
		}
	}

	return audio_data;
}


void GoZenAudio::_bind_methods() {
	ClassDB::bind_static_method("GoZenAudio",
								D_METHOD("get_audio_data", "file_path", "stream_index", "start_time", "duration"),
								&GoZenAudio::get_audio_data, DEFVAL(-1), DEFVAL(0.0), DEFVAL(-1.0));

	ClassDB::bind_static_method("GoZenAudio", D_METHOD("combine_data", "audio_one", "audio_two"),
								&GoZenAudio::combine_data);
	ClassDB::bind_static_method("GoZenAudio", D_METHOD("change_db", "audio_data", "db"), &GoZenAudio::change_db);
	ClassDB::bind_static_method("GoZenAudio", D_METHOD("change_to_mono", "audio_data", "left_channel"),
								&GoZenAudio::change_to_mono);

	ClassDB::bind_static_method("GoZenAudio",
								D_METHOD("apply_fade", "audio_data", "fade_in_samples", "fade_out_samples"),
								&GoZenAudio::apply_fade);
}
