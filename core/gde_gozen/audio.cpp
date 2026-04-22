#include "audio.hpp"

#include <unordered_map>


PackedByteArray Audio::_get_audio(AVFormatContext*& format_ctx, AVStream*& stream, double start_time, double duration) {
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
	} else if (avcodec_parameters_to_context(codec_ctx.get(), stream->codecpar)) {
		_log_err("Couldn't initialize audio codec context!");
		return audio_data;
	}

	FFmpeg::enable_multithreading(codec_ctx.get(), codec);
	codec_ctx->request_sample_fmt = TARGET_FORMAT;
	if (avcodec_open2(codec_ctx.get(), codec, NULL)) {
		_log_err("Couldn't open audio codec!");
		return audio_data;
	}

	if (codec_ctx->ch_layout.nb_channels == 0) {
		av_channel_layout_default(&codec_ctx->ch_layout, 2);
	}

	if (start_time > 0) {
		int64_t seek_target = av_rescale_q(start_time * AV_TIME_BASE, AV_TIME_BASE_Q, stream->time_base);
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
		FFmpeg::print_av_error("Audio: Couldn't initialize SWR!", response);
		return audio_data;
	}

	av_packet = make_unique_avpacket();
	av_frame = make_unique_avframe();
	av_decoded_frame = make_unique_avframe();
	if (!av_frame || !av_decoded_frame || !av_packet) {
		_log_err("Couldn't allocate frames/packet for audio!");
		return audio_data;
	}

	size_t current_size = 0;
	int64_t max_bytes = -1;
	int bytes_per_sample = av_get_bytes_per_sample(TARGET_FORMAT);
	if (duration > 0) {
		max_bytes = (int64_t)(duration * TARGET_SAMPLE_RATE * bytes_per_sample * 2);
		audio_data.resize(max_bytes);
	} else {
		double stream_duration_sec = 0.0;
		if (stream->duration != AV_NOPTS_VALUE && stream->duration > 0) {
			stream_duration_sec = stream->duration * av_q2d(stream->time_base);
		} else if (format_ctx->duration != AV_NOPTS_VALUE && format_ctx->duration > 0) {
			stream_duration_sec = (double)format_ctx->duration / AV_TIME_BASE;
		}

		int64_t total_size = 0;
		if (stream_duration_sec > 0.0) {
			total_size = (int64_t)(stream_duration_sec * TARGET_SAMPLE_RATE) * bytes_per_sample * 2;
			if (total_size >= 2147483600) {
				total_size = 2147483600 - 1;
			}
		}
		audio_data.resize(total_size);
	}

	while (!(FFmpeg::get_frame(format_ctx, codec_ctx.get(), stream->index, av_frame.get(), av_packet.get()))) {
		if (av_frame->nb_samples <= 0)
			break;

		// Copy decoded data to new frame.
		av_decoded_frame->format = TARGET_FORMAT;
		av_decoded_frame->ch_layout = TARGET_LAYOUT;
		av_decoded_frame->sample_rate = TARGET_SAMPLE_RATE;
		av_decoded_frame->nb_samples = swr_get_out_samples(swr_ctx.get(), av_frame->nb_samples);

		if (av_frame->ch_layout.nb_channels == 0) {
			av_channel_layout_copy(&av_frame->ch_layout, &codec_ctx->ch_layout);
		}

		if ((response = av_frame_get_buffer(av_decoded_frame.get(), 0)) < 0) {
			FFmpeg::print_av_error("Audio: Couldn't create new frame for swr!", response);
			av_frame_unref(av_frame.get());
			av_frame_unref(av_decoded_frame.get());
			break;
		}

		response = swr_convert(swr_ctx.get(), av_decoded_frame->data, av_decoded_frame->nb_samples,
							   (const uint8_t**)av_frame->extended_data, av_frame->nb_samples);
		if (response < 0) {
			FFmpeg::print_av_error("Audio: Couldn't convert the audio data!", response);
			av_frame_unref(av_frame.get());
			av_frame_unref(av_decoded_frame.get());
			break;
		}
		av_decoded_frame->nb_samples = response;

		size_t byte_size = av_decoded_frame->nb_samples * bytes_per_sample * 2;
		if (current_size + byte_size > audio_data.size()) {
			size_t new_size = current_size + byte_size + (1024 * 1024 * 10); // 10MB chunk padding.
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


PackedByteArray Audio::get_audio_data(String file_path, int stream_index, double start_time, double duration) {
	AVFormatContext* format_ctx = nullptr;
	PackedByteArray data = PackedByteArray();
	PackedByteArray file_buffer; // For `res://` videos.
	UniqueAVIOContext avio_ctx;
	BufferData buffer_data;

	int64_t pre_padding_bytes = 0;
	double fetch_start_time = start_time;
	double fetch_duration = duration;
	if (start_time < 0) {
		pre_padding_bytes = (int64_t)(-start_time * 44100) * 4;
		fetch_start_time = 0;
		if (duration > 0) {
			fetch_duration = Math::max(0.0, duration - start_time);
		}
	}

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
	} else {
		CharString local_path = file_path.utf8();
		if (avformat_open_input(&format_ctx, local_path.get_data(), NULL, NULL)) {
			_log_err("Couldn't open audio");
			return data;
		}
	}

	if (avformat_find_stream_info(format_ctx, NULL)) {
		_log_err("Couldn't find stream info");
		avformat_close_input(&format_ctx);
		return data;
	} else if (stream_index == -1) {
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
			if (i != stream_index)
				format_ctx->streams[i]->discard = AVDISCARD_ALL;
		}
	}

	if (stream_index >= 0 && stream_index < format_ctx->nb_streams) {
		AVCodecParameters* av_codec_params = format_ctx->streams[stream_index]->codecpar;
		if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO) {
			data = _get_audio(format_ctx, format_ctx->streams[stream_index], fetch_start_time, fetch_duration);
		}
	} else if (stream_index != -1) {
		_log_err("Invalid stream index");
	}

	avformat_close_input(&format_ctx);

	// Apply pre-padding.
	if (pre_padding_bytes > 0) {
		PackedByteArray silence;
		silence.resize(pre_padding_bytes);
		memset(silence.ptrw(), 0, pre_padding_bytes);
		silence.append_array(data);
		data = silence;
	}

	// Apply post-padding.
	if (duration > 0) {
		int64_t target_size = (int64_t)(duration * 44100) * 4;
		if (data.size() < target_size) {
			int64_t current_size = data.size();
			int64_t missing_bytes = target_size - current_size;
			data.resize(target_size);
			memset(data.ptrw() + current_size, 0, missing_bytes);
		} else if (data.size() > target_size)
			data.resize(target_size);
	}
	return data;
}


PackedByteArray Audio::combine_data(PackedByteArray audio_one, PackedByteArray audio_two, int offset_bytes) {
	int16_t* pw_one = (int16_t*)audio_one.ptrw();
	const int16_t* p_two = (const int16_t*)audio_two.ptr();
	size_t samples_one = audio_one.size() / 2;
	size_t samples_two = audio_two.size() / 2;
	size_t start_sample = offset_bytes / 2;

	size_t samples_to_mix = samples_two;
	if (start_sample + samples_to_mix > samples_one) {
		if (start_sample >= samples_one)
			return audio_one;
		samples_to_mix = samples_one - start_sample;
	}

	for (size_t i = 0; i < samples_to_mix; i++)
		pw_one[start_sample + i] = Math::clamp(pw_one[start_sample + i] + p_two[i], -32768, 32767);

	return audio_one;
}


PackedByteArray Audio::change_db(PackedByteArray audio_data, float db) {
	static std::unordered_map<float, double> cache;

	const size_t sample_count = audio_data.size() / 2;
	int16_t* pw_data = reinterpret_cast<int16_t*>(audio_data.ptrw());

	const auto search = cache.find(db);
	double value;

	if (search == cache.end()) {
		value = std::pow(10.0, db / 20.0);
		cache[db] = value;
	} else
		value = search->second;

	for (size_t i = 0; i < sample_count; i++)
		pw_data[i] = Math::clamp((int32_t)(pw_data[i] * value), -32768, 32767);

	return audio_data;
}


PackedByteArray Audio::change_to_mono(PackedByteArray audio_data, bool left) {
	const size_t sample_count = audio_data.size() / 2;
	int16_t* pw_data = reinterpret_cast<int16_t*>(audio_data.ptrw());

	if (left) {
		for (size_t i = 0; i < sample_count; i += 2)
			pw_data[i + 1] = pw_data[i];
	} else {
		for (size_t i = 0; i < sample_count; i += 2)
			pw_data[i] = pw_data[i + 1];
	}
	return audio_data;
}

PackedByteArray Audio::apply_dynamic_volume(PackedByteArray audio_data, PackedFloat32Array frame_volumes,
											float mix_rate, float framerate) {
	if (audio_data.size() == 0 || frame_volumes.size() == 0) {
		return audio_data;
	}

	const int sample_count = audio_data.size() / 4; // 16-bit stereo samples.
	int16_t* pw_data = reinterpret_cast<int16_t*>(audio_data.ptrw());
	int samples_per_frame = std::ceil(mix_rate / framerate);
	int total_frames = frame_volumes.size();

	for (int frame = 0; frame < total_frames; ++frame) {
		float volume_linear = frame_volumes[frame];
		if (Math::is_equal_approx(volume_linear, 1.0f)) {
			continue;
		}

		int start_sample = frame * samples_per_frame;
		int end_sample = MIN(start_sample + samples_per_frame, sample_count);
		for (int i = start_sample; i < end_sample; ++i) {
			int idx = i * 2;
			pw_data[idx] = Math::clamp((int32_t)(pw_data[idx] * volume_linear), -32768, 32767);
			pw_data[idx + 1] = Math::clamp((int32_t)(pw_data[idx + 1] * volume_linear), -32768, 32767);
		}
	}
	return audio_data;
}

PackedByteArray Audio::apply_fade(PackedByteArray audio_data, int fade_in_samples, int fade_out_samples,
								  int start_sample, int total_samples) {
	int16_t* samples = (int16_t*)audio_data.ptrw();
	int sample_count = audio_data.size() / 2; // 16-bit stereo samples.
	if (fade_in_samples > 0 || fade_out_samples > 0) {
		for (int i = 0; i < sample_count; i += 2) {
			int current_sample = start_sample + (i / 2);
			float volume = 1.0f;
			if (fade_in_samples > 0 && current_sample < fade_in_samples) {
				volume = (float)current_sample / (float)fade_in_samples;
			}

			int fade_out_start = total_samples - fade_out_samples;
			if (fade_out_samples > 0 && current_sample >= fade_out_start) {
				volume *= 1.0f - ((float)(current_sample - fade_out_start) / (float)fade_out_samples);
			}

			if (volume < 1.0f) {
				volume = Math::clamp(volume, 0.0f, 1.0f);
				samples[i] = (int16_t)(samples[i] * volume);
				samples[i + 1] = (int16_t)(samples[i + 1] * volume);
			}
		}
	}
	return audio_data;
}


void Audio::_bind_methods() {
	ClassDB::bind_static_method("Audio",
								D_METHOD("get_audio_data", "file_path", "stream_index", "start_time", "duration"),
								&Audio::get_audio_data, DEFVAL(-1), DEFVAL(0.0), DEFVAL(-1.0));

	ClassDB::bind_static_method("Audio", D_METHOD("combine_data", "audio_one", "audio_two", "offset_bytes"),
								&Audio::combine_data, DEFVAL(0));
	ClassDB::bind_static_method("Audio", D_METHOD("change_db", "audio_data", "db"), &Audio::change_db);
	ClassDB::bind_static_method("Audio", D_METHOD("change_to_mono", "audio_data", "left_channel"),
								&Audio::change_to_mono);
	ClassDB::bind_static_method(
		"Audio", D_METHOD("apply_dynamic_volume", "audio_data", "frame_volumes", "mix_rate", "framerate"),
		&Audio::apply_dynamic_volume);

	ClassDB::bind_static_method(
		"Audio",
		D_METHOD("apply_fade", "audio_data", "fade_in_samples", "fade_out_samples", "start_sample", "total_samples"),
		&Audio::apply_fade, DEFVAL(0), DEFVAL(0));
}
