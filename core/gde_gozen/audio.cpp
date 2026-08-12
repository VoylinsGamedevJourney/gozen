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
		av_seek_frame(format_ctx, stream->index, seek_target, AVSEEK_FLAG_BACKWARD | AVSEEK_FLAG_ANY);
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

	bool first_frame = true;
	int64_t samples_to_discard = 0;

	while (!(FFmpeg::get_frame(format_ctx, codec_ctx.get(), stream->index, av_frame.get(), av_packet.get()))) {
		if (av_frame->nb_samples <= 0)
			break;

		if (first_frame && start_time > 0) {
			first_frame = false;
			int64_t frame_pts =
				av_frame->best_effort_timestamp != AV_NOPTS_VALUE ? av_frame->best_effort_timestamp : av_frame->pts;
			if (frame_pts != AV_NOPTS_VALUE) {
				double frame_time = frame_pts * av_q2d(stream->time_base);
				if (start_time > frame_time) {
					samples_to_discard = (int64_t)((start_time - frame_time) * TARGET_SAMPLE_RATE);
				}
			}
		}

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

		int samples_to_copy = av_decoded_frame->nb_samples;
		uint8_t* data_ptr = av_decoded_frame->extended_data[0];

		if (samples_to_discard > 0) {
			if (samples_to_discard >= samples_to_copy) {
				samples_to_discard -= samples_to_copy;
				av_frame_unref(av_frame.get());
				av_frame_unref(av_decoded_frame.get());
				continue;
			} else {
				data_ptr += samples_to_discard * bytes_per_sample * 2;
				samples_to_copy -= samples_to_discard;
				samples_to_discard = 0;
			}
		}

		size_t byte_size = samples_to_copy * bytes_per_sample * 2;
		if (current_size + byte_size > audio_data.size()) {
			size_t new_size = current_size + byte_size + (1024 * 1024 * 10); // 10MB chunk padding.
			audio_data.resize(new_size);
		}

		memcpy(&(audio_data.ptrw()[current_size]), data_ptr, byte_size);
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

PackedByteArray Audio::change_speed(PackedByteArray audio_data, float speed) {
	if (Math::is_equal_approx(speed, 1.0f) || audio_data.size() == 0) {
		return audio_data;
	}
	const int64_t sample_count = audio_data.size() / 4; // 16-bit stereo samples.
	int64_t new_sample_count = (int64_t)std::ceil((double)sample_count / (double)speed);
	PackedByteArray new_audio_data;
	new_audio_data.resize(new_sample_count * 4);
	const int16_t* src_data = reinterpret_cast<const int16_t*>(audio_data.ptr());
	int16_t* dst_data = reinterpret_cast<int16_t*>(new_audio_data.ptrw());

	auto cubic_interpolate = [](float y0, float y1, float y2, float y3, float mu) -> int16_t {
		float mu2 = mu * mu;
		float a0 = y3 - y2 - y0 + y1;
		float a1 = y0 - y1 - a0;
		float a2 = y2 - y0;
		float a3 = y1;
		float val = a0 * mu * mu2 + a1 * mu2 + a2 * mu + a3;

		float local_min = std::min(std::min(y0, y1), std::min(y2, y3));
		float local_max = std::max(std::max(y0, y1), std::max(y2, y3));
		val = Math::clamp(val, local_min, local_max);

		return (int16_t)Math::clamp(val, -32768.0f, 32767.0f);
	};

	for (int64_t i = 0; i < new_sample_count; ++i) {
		double src_index_d = i * (double)speed;
		int64_t src_index = (int64_t)src_index_d;
		float t = (float)(src_index_d - src_index);
		int64_t i0 = Math::clamp(src_index - 1, (int64_t)0, sample_count - 1);
		int64_t i1 = Math::clamp(src_index, (int64_t)0, sample_count - 1);
		int64_t i2 = Math::clamp(src_index + 1, (int64_t)0, sample_count - 1);
		int64_t i3 = Math::clamp(src_index + 2, (int64_t)0, sample_count - 1);

		dst_data[i * 2] = cubic_interpolate(src_data[i0 * 2], src_data[i1 * 2], src_data[i2 * 2], src_data[i3 * 2], t);
		dst_data[i * 2 + 1] = cubic_interpolate(src_data[i0 * 2 + 1], src_data[i1 * 2 + 1], src_data[i2 * 2 + 1],
												src_data[i3 * 2 + 1], t);
	}
	return new_audio_data;
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
		int end_sample =
			(frame == total_frames - 1) ? sample_count : MIN(start_sample + samples_per_frame, sample_count);
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


PackedByteArray Audio::apply_pan(PackedByteArray audio_data, float pan) {
	int16_t* pw_data = reinterpret_cast<int16_t*>(audio_data.ptrw());
	size_t sample_count = audio_data.size() / 2;

	float left_mult = std::min(1.0f, 1.0f - pan);
	float right_mult = std::min(1.0f, 1.0f + pan);

	for (size_t i = 0; i < sample_count; i += 2) {
		pw_data[i] = Math::clamp((int32_t)(pw_data[i] * left_mult), -32768, 32767);
		pw_data[i + 1] = Math::clamp((int32_t)(pw_data[i + 1] * right_mult), -32768, 32767);
	}
	return audio_data;
}


PackedByteArray Audio::apply_channel_swap(PackedByteArray audio_data) {
	int16_t* pw_data = reinterpret_cast<int16_t*>(audio_data.ptrw());
	size_t sample_count = audio_data.size() / 2;

	for (size_t i = 0; i < sample_count; i += 2) {
		std::swap(pw_data[i], pw_data[i + 1]);
	}
	return audio_data;
}


PackedByteArray Audio::apply_stereo_to_mono(PackedByteArray audio_data) {
	int16_t* pw_data = reinterpret_cast<int16_t*>(audio_data.ptrw());
	size_t sample_count = audio_data.size() / 2;

	for (size_t i = 0; i < sample_count; i += 2) {
		int32_t mixed = (pw_data[i] + pw_data[i + 1]) / 2;
		pw_data[i] = (int16_t)mixed;
		pw_data[i + 1] = (int16_t)mixed;
	}
	return audio_data;
}


PackedByteArray Audio::apply_retro_filter(PackedByteArray audio_data, int bit_depth) {
	if (bit_depth >= 16 || bit_depth <= 0) {
		return audio_data;
	}

	int16_t* pw_data = reinterpret_cast<int16_t*>(audio_data.ptrw());
	size_t sample_count = audio_data.size() / 2;
	int shift = 16 - bit_depth;
	int16_t mask = (int16_t)(0xFFFF << shift);

	for (size_t i = 0; i < sample_count; i++) {
		pw_data[i] = pw_data[i] & mask;
	}
	return audio_data;
}

PackedByteArray Audio::apply_pitch(PackedByteArray audio_data, float pitch_scale) {
	if (Math::is_equal_approx(pitch_scale, 1.0f) || audio_data.size() == 0) {
		return audio_data;
	}

	size_t frame_count = audio_data.size() / 4;
	const int16_t* in_data = reinterpret_cast<const int16_t*>(audio_data.ptr());

	PackedByteArray out_bytes;
	out_bytes.resize(audio_data.size());
	int16_t* out_data_16 = reinterpret_cast<int16_t*>(out_bytes.ptrw());

	PackedFloat32Array float_in;
	float_in.resize(frame_count * 2);
	float* p_in = (float*)float_in.ptrw();

	PackedFloat32Array float_out;
	float_out.resize(frame_count * 2);
	float* p_out = (float*)float_out.ptrw();

	for (size_t i = 0; i < frame_count * 2; ++i) {
		p_in[i] = in_data[i] / 32768.0f;
	}

	SMBPitchShift* shift_l = new SMBPitchShift();
	SMBPitchShift* shift_r = new SMBPitchShift();

	long fft_size = 2048;
	long osamp = 4;
	float sample_rate = 44100.0f;

	shift_l->PitchShift(pitch_scale, frame_count, fft_size, osamp, sample_rate, p_in, p_out, 2);
	shift_r->PitchShift(pitch_scale, frame_count, fft_size, osamp, sample_rate, p_in + 1, p_out + 1, 2);

	delete shift_l;
	delete shift_r;

	for (size_t i = 0; i < frame_count * 2; ++i) {
		float val = p_out[i] * 32768.0f;
		out_data_16[i] = (int16_t)Math::clamp((int32_t)val, -32768, 32767);
	}

	return out_bytes;
}

// Mainly used for waveform generating stuff atm.
Error Audio::open(String file_path, int stream_index) {
	if (loaded)
		close();

	AVFormatContext* temp_format_ctx = nullptr;

	if (file_path.begins_with("res://") || file_path.begins_with("user://")) {
		if (!(temp_format_ctx = avformat_alloc_context())) {
			_log_err("Failed to allocate AVFormatContext");
			return ERR_CANT_CREATE;
		}

		file_buffer_inst = FileAccess::get_file_as_bytes(file_path);
		if (file_buffer_inst.is_empty()) {
			avformat_free_context(temp_format_ctx);
			_log_err("Couldn't load file from res:// at path '" + file_path + "'");
			return ERR_FILE_NOT_FOUND;
		}

		buffer_data_inst.ptr = file_buffer_inst.ptrw();
		buffer_data_inst.size = file_buffer_inst.size();
		buffer_data_inst.offset = 0;

		unsigned char* avio_ctx_buffer = (unsigned char*)av_malloc(FFmpeg::AVIO_CTX_BUFFER_SIZE);
		avio_ctx_inst = make_unique_ffmpeg<AVIOContext, AVIOContextDeleter>(
			avio_alloc_context(avio_ctx_buffer, FFmpeg::AVIO_CTX_BUFFER_SIZE, 0, &buffer_data_inst,
							   &FFmpeg::read_buffer_packet, nullptr, &FFmpeg::seek_buffer));

		if (!avio_ctx_inst) {
			av_free(avio_ctx_buffer);
			_log_err("Failed to create avio_ctx");
			return ERR_CANT_CREATE;
		}
		temp_format_ctx->pb = avio_ctx_inst.get();
		if (avformat_open_input(&temp_format_ctx, nullptr, nullptr, nullptr) != 0) {
			_log_err("Failed to open input from memory buffer");
			return ERR_CANT_OPEN;
		}
	} else {
		CharString local_path = file_path.utf8();
		if (avformat_open_input(&temp_format_ctx, local_path.get_data(), NULL, NULL)) {
			_log_err("Couldn't open audio");
			return ERR_CANT_OPEN;
		}
	}

	format_ctx_inst = make_unique_ffmpeg<AVFormatContext, AVFormatCtxInputDeleter>(temp_format_ctx);

	if (avformat_find_stream_info(format_ctx_inst.get(), NULL)) {
		_log_err("Couldn't find stream info");
		close();
		return ERR_CANT_OPEN;
	} else if (stream_index == -1) {
		for (int i = 0; i < format_ctx_inst->nb_streams; i++) {
			AVCodecParameters* av_codec_params = format_ctx_inst->streams[i]->codecpar;

			if (!avcodec_find_decoder(av_codec_params->codec_id)) {
				format_ctx_inst->streams[i]->discard = AVDISCARD_ALL;
				continue;
			} else if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO) {
				stream_index = i;
				break;
			}
		}
	}

	// Getting rid of all non-audio streams.
	for (int i = 0; i < format_ctx_inst->nb_streams; i++) {
		AVCodecParameters* av_codec_params = format_ctx_inst->streams[i]->codecpar;
		if (!avcodec_find_decoder(av_codec_params->codec_id) || av_codec_params->codec_type != AVMEDIA_TYPE_AUDIO) {
			if (i != stream_index)
				format_ctx_inst->streams[i]->discard = AVDISCARD_ALL;
		}
	}

	if (stream_index >= 0 && stream_index < format_ctx_inst->nb_streams) {
		AVCodecParameters* av_codec_params = format_ctx_inst->streams[stream_index]->codecpar;
		if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO) {
			stream_inst = format_ctx_inst->streams[stream_index];
		} else {
			close();
			return ERR_CANT_OPEN;
		}
	} else {
		close();
		_log_err("Invalid stream index");
		return ERR_CANT_OPEN;
	}

	const AVCodec* codec = avcodec_find_decoder(stream_inst->codecpar->codec_id);
	if (!codec) {
		_log_err("Couldn't find any decoder for audio!");
		close();
		return ERR_CANT_OPEN;
	}

	codec_ctx_inst = make_unique_ffmpeg<AVCodecContext, AVCodecCtxDeleter>(avcodec_alloc_context3(codec));
	if (codec_ctx_inst == NULL) {
		_log_err("Couldn't allocate context for audio!");
		close();
		return ERR_CANT_OPEN;
	} else if (avcodec_parameters_to_context(codec_ctx_inst.get(), stream_inst->codecpar)) {
		_log_err("Couldn't initialize audio codec context!");
		close();
		return ERR_CANT_OPEN;
	}

	FFmpeg::enable_multithreading(codec_ctx_inst.get(), codec);
	codec_ctx_inst->request_sample_fmt = AV_SAMPLE_FMT_S16;
	if (avcodec_open2(codec_ctx_inst.get(), codec, NULL)) {
		_log_err("Couldn't open audio codec!");
		close();
		return ERR_CANT_OPEN;
	}

	if (codec_ctx_inst->ch_layout.nb_channels == 0) {
		av_channel_layout_default(&codec_ctx_inst->ch_layout, 2);
	}

	const AVChannelLayout TARGET_LAYOUT = AV_CHANNEL_LAYOUT_STEREO;
	SwrContext* temp_swr_ctx = nullptr;
	int response =
		swr_alloc_set_opts2(&temp_swr_ctx, &TARGET_LAYOUT, AV_SAMPLE_FMT_S16, 44100, &codec_ctx_inst->ch_layout,
							codec_ctx_inst->sample_fmt, codec_ctx_inst->sample_rate, 0, nullptr);
	swr_ctx_inst = make_unique_ffmpeg<SwrContext, SwrCtxDeleter>(temp_swr_ctx);
	if (response < 0 || (response = swr_init(swr_ctx_inst.get()))) {
		FFmpeg::print_av_error("Audio: Couldn't initialize SWR!", response);
		close();
		return ERR_CANT_OPEN;
	}

	bytes_per_sample_inst = av_get_bytes_per_sample(AV_SAMPLE_FMT_S16);
	loaded = true;
	last_returned_time = -1.0;
	leftover_buffer_inst.clear();
	return OK;
}

PackedByteArray Audio::get_audio_data_chunk(double start_time, double duration) {
	const int TARGET_SAMPLE_RATE = 44100;
	const AVSampleFormat TARGET_FORMAT = AV_SAMPLE_FMT_S16;
	const AVChannelLayout TARGET_LAYOUT = AV_CHANNEL_LAYOUT_STEREO;

	PackedByteArray audio_data = PackedByteArray();
	if (!loaded)
		return audio_data;

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

	UniqueAVPacket av_packet = make_unique_avpacket();
	UniqueAVFrame av_frame = make_unique_avframe();
	UniqueAVFrame av_decoded_frame = make_unique_avframe();
	if (!av_frame || !av_decoded_frame || !av_packet) {
		_log_err("Couldn't allocate frames/packet for audio!");
		return audio_data;
	}

	bool needs_seek = false;
	if (last_returned_time < 0.0) {
		needs_seek = true;
	} else if (fetch_start_time > 0 && Math::abs(fetch_start_time - last_returned_time) > 0.05) {
		needs_seek = true;
	}

	if (needs_seek) {
		int64_t seek_target = av_rescale_q(fetch_start_time * AV_TIME_BASE, AV_TIME_BASE_Q, stream_inst->time_base);
		av_seek_frame(format_ctx_inst.get(), stream_inst->index, seek_target, AVSEEK_FLAG_BACKWARD | AVSEEK_FLAG_ANY);
		avcodec_flush_buffers(codec_ctx_inst.get());
		leftover_buffer_inst.clear();
		last_returned_time = fetch_start_time;
	}

	size_t current_size = 0;
	int64_t max_bytes = -1;
	if (fetch_duration > 0) {
		max_bytes = (int64_t)(fetch_duration * TARGET_SAMPLE_RATE * bytes_per_sample_inst * 2);
		audio_data.resize(max_bytes);
	} else {
		double stream_duration_sec = 0.0;
		if (stream_inst->duration != AV_NOPTS_VALUE && stream_inst->duration > 0) {
			stream_duration_sec = stream_inst->duration * av_q2d(stream_inst->time_base);
		} else if (format_ctx_inst->duration != AV_NOPTS_VALUE && format_ctx_inst->duration > 0) {
			stream_duration_sec = (double)format_ctx_inst->duration / AV_TIME_BASE;
		}

		int64_t total_size = 0;
		if (stream_duration_sec > 0.0) {
			total_size = (int64_t)(stream_duration_sec * TARGET_SAMPLE_RATE) * bytes_per_sample_inst * 2;
			if (total_size >= 2147483600) {
				total_size = 2147483600 - 1;
			}
		}
		audio_data.resize(total_size);
	}

	if (leftover_buffer_inst.size() > 0) {
		size_t copy_size = Math::min((size_t)leftover_buffer_inst.size(), (size_t)(max_bytes - current_size));
		memcpy(audio_data.ptrw(), leftover_buffer_inst.ptr(), copy_size);
		current_size += copy_size;

		if (copy_size < leftover_buffer_inst.size()) {
			PackedByteArray new_leftover;
			size_t remainder = leftover_buffer_inst.size() - copy_size;
			new_leftover.resize(remainder);
			memcpy(new_leftover.ptrw(), leftover_buffer_inst.ptr() + copy_size, remainder);
			leftover_buffer_inst = new_leftover;
		} else {
			leftover_buffer_inst.clear();
		}
	}

	bool first_frame = needs_seek;
	int64_t samples_to_discard = 0;
	int response = 0;

	while (current_size < max_bytes && !(FFmpeg::get_frame(format_ctx_inst.get(), codec_ctx_inst.get(),
														   stream_inst->index, av_frame.get(), av_packet.get()))) {
		if (av_frame->nb_samples <= 0)
			break;

		if (first_frame) {
			first_frame = false;
			int64_t frame_pts =
				av_frame->best_effort_timestamp != AV_NOPTS_VALUE ? av_frame->best_effort_timestamp : av_frame->pts;
			if (frame_pts != AV_NOPTS_VALUE) {
				double frame_time = frame_pts * av_q2d(stream_inst->time_base);
				if (fetch_start_time > frame_time) {
					samples_to_discard = (int64_t)((fetch_start_time - frame_time) * TARGET_SAMPLE_RATE);
				}
			}
		}

		av_decoded_frame->format = TARGET_FORMAT;
		av_decoded_frame->ch_layout = TARGET_LAYOUT;
		av_decoded_frame->sample_rate = TARGET_SAMPLE_RATE;
		av_decoded_frame->nb_samples = swr_get_out_samples(swr_ctx_inst.get(), av_frame->nb_samples);

		if (av_frame->ch_layout.nb_channels == 0) {
			av_channel_layout_copy(&av_frame->ch_layout, &codec_ctx_inst->ch_layout);
		}

		if ((response = av_frame_get_buffer(av_decoded_frame.get(), 0)) < 0) {
			FFmpeg::print_av_error("Audio: Couldn't create new frame for swr!", response);
			av_frame_unref(av_frame.get());
			av_frame_unref(av_decoded_frame.get());
			break;
		}

		response = swr_convert(swr_ctx_inst.get(), av_decoded_frame->data, av_decoded_frame->nb_samples,
							   (const uint8_t**)av_frame->extended_data, av_frame->nb_samples);
		if (response < 0) {
			FFmpeg::print_av_error("Audio: Couldn't convert the audio data!", response);
			av_frame_unref(av_frame.get());
			av_frame_unref(av_decoded_frame.get());
			break;
		}
		av_decoded_frame->nb_samples = response;

		int samples_to_copy = av_decoded_frame->nb_samples;
		uint8_t* data_ptr = av_decoded_frame->extended_data[0];

		if (samples_to_discard > 0) {
			if (samples_to_discard >= samples_to_copy) {
				samples_to_discard -= samples_to_copy;
				av_frame_unref(av_frame.get());
				av_frame_unref(av_decoded_frame.get());
				continue;
			} else {
				data_ptr += samples_to_discard * bytes_per_sample_inst * 2;
				samples_to_copy -= samples_to_discard;
				samples_to_discard = 0;
			}
		}

		size_t byte_size = samples_to_copy * bytes_per_sample_inst * 2;
		size_t bytes_needed = max_bytes - current_size;

		if (byte_size <= bytes_needed) {
			memcpy(audio_data.ptrw() + current_size, data_ptr, byte_size);
			current_size += byte_size;
		} else {
			memcpy(audio_data.ptrw() + current_size, data_ptr, bytes_needed);
			current_size += bytes_needed;
			size_t excess_bytes = byte_size - bytes_needed;
			leftover_buffer_inst.resize(excess_bytes);
			memcpy(leftover_buffer_inst.ptrw(), data_ptr + bytes_needed, excess_bytes);
		}

		av_frame_unref(av_frame.get());
		av_frame_unref(av_decoded_frame.get());
	}

	if (current_size < audio_data.size()) {
		audio_data.resize(current_size);
	}

	// Pre-padding.
	if (pre_padding_bytes > 0) {
		PackedByteArray silence;
		silence.resize(pre_padding_bytes);
		memset(silence.ptrw(), 0, pre_padding_bytes);
		silence.append_array(audio_data);
		audio_data = silence;
	}

	// Post-padding.
	if (duration > 0) {
		int64_t target_size = (int64_t)(duration * 44100) * 4;
		if (audio_data.size() < target_size) {
			int64_t old_size = audio_data.size();
			int64_t missing_bytes = target_size - old_size;
			audio_data.resize(target_size);
			memset(audio_data.ptrw() + old_size, 0, missing_bytes);

		} else if (audio_data.size() > target_size) {
			audio_data.resize(target_size);
		}
	}

	last_returned_time += fetch_duration;
	return audio_data;
}

void Audio::close() {
	if (!loaded)
		return;
	loaded = false;
	stream_inst = nullptr;

	swr_ctx_inst.reset();
	codec_ctx_inst.reset();
	format_ctx_inst.reset();
	avio_ctx_inst.reset();
	file_buffer_inst.clear();
	leftover_buffer_inst.clear();
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
	ClassDB::bind_static_method("Audio", D_METHOD("change_speed", "audio_data", "speed"), &Audio::change_speed);
	ClassDB::bind_static_method(
		"Audio", D_METHOD("apply_dynamic_volume", "audio_data", "frame_volumes", "mix_rate", "framerate"),
		&Audio::apply_dynamic_volume);

	ClassDB::bind_static_method(
		"Audio",
		D_METHOD("apply_fade", "audio_data", "fade_in_samples", "fade_out_samples", "start_sample", "total_samples"),
		&Audio::apply_fade, DEFVAL(0), DEFVAL(0));

	ClassDB::bind_static_method("Audio", D_METHOD("apply_pan", "audio_data", "pan"), &Audio::apply_pan);
	ClassDB::bind_static_method("Audio", D_METHOD("apply_channel_swap", "audio_data"), &Audio::apply_channel_swap);
	ClassDB::bind_static_method("Audio", D_METHOD("apply_stereo_to_mono", "audio_data"), &Audio::apply_stereo_to_mono);
	ClassDB::bind_static_method("Audio", D_METHOD("apply_retro_filter", "audio_data", "bit_depth"),
								&Audio::apply_retro_filter);
	ClassDB::bind_static_method("Audio", D_METHOD("apply_pitch", "audio_data", "pitch_scale"), &Audio::apply_pitch);

	ClassDB::bind_method(D_METHOD("open", "file_path", "stream_index"), &Audio::open, DEFVAL(-1));
	ClassDB::bind_method(D_METHOD("get_audio_data_chunk", "start_time", "duration"), &Audio::get_audio_data_chunk);
	ClassDB::bind_method(D_METHOD("close"), &Audio::close);
}
