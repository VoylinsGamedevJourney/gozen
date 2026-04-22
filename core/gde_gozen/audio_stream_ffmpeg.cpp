#include "audio_stream_ffmpeg.hpp"

int AudioStreamFFmpeg::open(const String& path, int stream_index) {
	if (mutex) {
		close();
	}

	mutex = memnew(Mutex);
	mutex->lock();
	AVFormatContext* temp_format_ctx = nullptr;
	CharString local_path = path.utf8();
	file_path = path;

	if (path.begins_with("res://") || path.begins_with("user://")) {
		temp_format_ctx = avformat_alloc_context();
		file_buffer = FileAccess::get_file_as_bytes(path);

		if (!temp_format_ctx) {
			mutex->unlock();
			return _log_err("Failed to allocate AVFormatContext");
		} else if (file_buffer.is_empty()) {
			avformat_free_context(temp_format_ctx);
			mutex->unlock();
			return _log_err("Couldn't load file from res:// or user://");
		}

		buffer_data.ptr = file_buffer.ptrw();
		buffer_data.size = file_buffer.size();
		buffer_data.offset = 0;

		const int IO_BUFFER_SIZE = 8 * 1024 * 1024; // 8 MB
		unsigned char* avio_ctx_buffer = (unsigned char*)av_malloc(IO_BUFFER_SIZE);
		avio_ctx = make_unique_ffmpeg<AVIOContext, AVIOContextDeleter>(
			avio_alloc_context(avio_ctx_buffer, IO_BUFFER_SIZE, 0, &buffer_data, &FFmpeg::read_buffer_packet, nullptr,
							   &FFmpeg::seek_buffer));

		if (!avio_ctx) {
			av_free(avio_ctx_buffer);
			mutex->unlock();
			return _log_err("Failed to create avio_ctx");
		}

		temp_format_ctx->pb = avio_ctx.get();

		if (avformat_open_input(&temp_format_ctx, nullptr, nullptr, nullptr) != 0) {
			mutex->unlock();
			return _log_err("Failed to open input from memory buffer");
		}
	} else if (avformat_open_input(&temp_format_ctx, local_path.get_data(), NULL, NULL)) {
		mutex->unlock();
		return _log_err("Couldn't open file");
	}

	av_format_ctx = make_unique_ffmpeg<AVFormatContext, AVFormatCtxInputDeleter>(temp_format_ctx);
	if (avformat_find_stream_info(av_format_ctx.get(), NULL)) {
		mutex->unlock();
		return _log_err("Couldn't find stream info");
	}

	if (stream_index == -1) {
		for (int i = 0; i < av_format_ctx->nb_streams; i++) {
			AVCodecParameters* params = av_format_ctx->streams[i]->codecpar;

			if (params->codec_type == AVMEDIA_TYPE_AUDIO) {
				av_stream = av_format_ctx->streams[i];
				break;
			}
		}
	} else if (stream_index >= 0 && stream_index < av_format_ctx->nb_streams) {
		AVCodecParameters* av_codec_params = av_format_ctx->streams[stream_index]->codecpar;

		if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO)
			av_stream = av_format_ctx->streams[stream_index];
	} else if (stream_index != -1) {
		mutex->unlock();
		return _log_err("Invalid stream index");
	}

	if (!av_stream) {
		mutex->unlock();
		return _log_err("No audio stream found");
	}

	// Getting the length (average).
	if (av_stream->duration != AV_NOPTS_VALUE) {
		length = av_stream->duration * av_q2d(av_stream->time_base);
	} else if (av_format_ctx->duration != AV_NOPTS_VALUE) {
		length = av_format_ctx->duration / (double)AV_TIME_BASE;
	}

	// Discard all non-audio streams.
	for (int i = 0; i < av_format_ctx->nb_streams; i++) {
		AVCodecParameters* av_codec_params = av_format_ctx->streams[i]->codecpar;

		if (!avcodec_find_decoder(av_codec_params->codec_id)) {
			if (i != stream_index)
				av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
		}
	}

	if (!av_stream) {
		mutex->unlock();
		return _log_err("No audio stream found");
	}

	const AVCodec* codec = avcodec_find_decoder(av_stream->codecpar->codec_id);
	if (!codec) {
		mutex->unlock();
		return _log_err("Couldn't find decoder");
	}

	av_codec_ctx = make_unique_ffmpeg<AVCodecContext, AVCodecCtxDeleter>(avcodec_alloc_context3(codec));
	if (!av_codec_ctx) {
		mutex->unlock();
		return _log_err("Couldn't allocate codec context");
	} else if (avcodec_parameters_to_context(av_codec_ctx.get(), av_stream->codecpar)) {
		mutex->unlock();
		return _log_err("Couldn't initialize codec context");
	}

	av_codec_ctx->request_sample_fmt = AV_SAMPLE_FMT_S16;
	if (avcodec_open2(av_codec_ctx.get(), codec, nullptr)) {
		mutex->unlock();
		return _log_err("Couldn't open audio codec");
	}

	if (av_codec_ctx->ch_layout.nb_channels == 0) {
		av_channel_layout_default(&av_codec_ctx->ch_layout, 2);
	}

	stereo = av_codec_ctx->ch_layout.nb_channels >= 2;
	ch_layout = av_codec_ctx->ch_layout;
	sample_rate = av_codec_ctx->sample_rate;
	bytes_per_sample = av_get_bytes_per_sample(AV_SAMPLE_FMT_S16);

	AVChannelLayout out_ch_layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_STEREO;

	SwrContext* temp_swr_ctx = nullptr;
	int response = swr_alloc_set_opts2(&temp_swr_ctx, &out_ch_layout, AV_SAMPLE_FMT_S16, sample_rate,
									   &av_codec_ctx->ch_layout, av_codec_ctx->sample_fmt, sample_rate, 0, nullptr);
	swr_ctx = make_unique_ffmpeg<SwrContext, SwrCtxDeleter>(temp_swr_ctx);
	if (response < 0 || swr_init(swr_ctx.get()) < 0) {
		mutex->unlock();
		return _log_err("Failed to initialize SWR");
	}

	if (av_stream->start_time != AV_NOPTS_VALUE) {
		start_time = av_stream->start_time;
	} else {
		start_time = 0;
	}

	loaded = true;
	mutex->unlock();
	return 0;
}

void AudioStreamFFmpeg::close() {
	if (mutex) {
		memdelete(mutex);
		mutex = nullptr;
	}
	if (!loaded)
		return;

	loaded = false;
	av_stream = nullptr;
	av_codec_ctx.reset();
	av_format_ctx.reset();

	swr_ctx.reset();
	avio_ctx.reset();
	file_buffer.clear();
}


Ref<AudioStreamPlayback> AudioStreamFFmpeg::_instantiate_playback() const {
	if (!loaded)
		return nullptr;

	auto playback = memnew(AudioStreamFFmpegPlayback);
	playback->audio_stream_ffmpeg = this;
	playback->mix_rate = sample_rate;
	playback->stereo = stereo;
	playback->fill_buffer();

	return playback;
}

void AudioStreamFFmpegPlayback::_start(double p_from_pos) {
	is_playing = true;
	fade_in_remaining = FADE_SAMPLES;
	_seek(p_from_pos);
}

void AudioStreamFFmpegPlayback::_stop() { is_playing = false; }

bool AudioStreamFFmpegPlayback::_is_playing() const { return is_playing; }

double AudioStreamFFmpegPlayback::_get_playback_position() const { return float(mixed) / float(mix_rate); }

void AudioStreamFFmpegPlayback::_seek(double p_position) {
	audio_stream_ffmpeg->mutex->lock();
	int response = 0;
	buffer_fill = 0;

	int64_t target_ts =
		av_rescale_q(p_position * AV_TIME_BASE, AV_TIME_BASE_Q, audio_stream_ffmpeg->av_stream->time_base);
	target_ts += audio_stream_ffmpeg->start_time;

	avcodec_flush_buffers(audio_stream_ffmpeg->av_codec_ctx.get());
	if (int err = av_seek_frame(audio_stream_ffmpeg->av_format_ctx.get(), audio_stream_ffmpeg->av_stream->index,
								target_ts, AVSEEK_FLAG_BACKWARD)) {
		FFmpeg::print_av_error("AudioStreamFFmpeg: audio_decoder: Error while seeking", err);
		audio_stream_ffmpeg->mutex->unlock();
		return;
	}

	avcodec_flush_buffers(audio_stream_ffmpeg->av_codec_ctx.get());

	bool found_target = false;
	while (!found_target) {
		if (FFmpeg::get_frame(audio_stream_ffmpeg->av_format_ctx.get(), audio_stream_ffmpeg->av_codec_ctx.get(),
							  audio_stream_ffmpeg->av_stream->index, av_frame.get(), av_packet.get())) {
			audio_stream_ffmpeg->mutex->unlock();
			return;
		}

		int64_t frame_pts =
			av_frame->best_effort_timestamp != AV_NOPTS_VALUE ? av_frame->best_effort_timestamp : av_frame->pts;
		int64_t frame_duration = av_rescale_q(av_frame->nb_samples, AVRational{1, av_frame->sample_rate},
											  audio_stream_ffmpeg->av_stream->time_base);

		if (frame_pts + frame_duration >= target_ts) {
			found_target = true;

			av_decoded_frame->format = AV_SAMPLE_FMT_S16;
			av_decoded_frame->ch_layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_STEREO;
			av_decoded_frame->sample_rate = av_frame->sample_rate;

			if (av_frame->ch_layout.nb_channels == 0) {
				av_channel_layout_copy(&av_frame->ch_layout, &audio_stream_ffmpeg->av_codec_ctx->ch_layout);
			}

			av_decoded_frame->nb_samples =
				swr_get_out_samples(audio_stream_ffmpeg->swr_ctx.get(), av_frame->nb_samples);

			if ((response = av_frame_get_buffer(av_decoded_frame.get(), 0)) < 0) {
				FFmpeg::print_av_error("AudioStreamFFmpeg: Couldn't create new frame for swr!", response);
				av_frame_unref(av_frame.get());
				av_frame_unref(av_decoded_frame.get());
				audio_stream_ffmpeg->mutex->unlock();
				return;
			}

			response =
				swr_convert(audio_stream_ffmpeg->swr_ctx.get(), av_decoded_frame->data, av_decoded_frame->nb_samples,
							(const uint8_t**)av_frame->extended_data, av_frame->nb_samples);
			if (response < 0) {
				FFmpeg::print_av_error("AudioStreamFFmpeg: Couldn't convert the audio data!", response);
				av_frame_unref(av_frame.get());
				av_frame_unref(av_decoded_frame.get());
				audio_stream_ffmpeg->mutex->unlock();
				return;
			}
			av_decoded_frame->nb_samples = response;

			size_t byte_size = av_decoded_frame->nb_samples * audio_stream_ffmpeg->bytes_per_sample;
			byte_size *= 2;

			std::memcpy(buffer, av_decoded_frame->extended_data[0], byte_size);
			buffer_fill = av_decoded_frame->nb_samples;
			mix_rate = av_frame->sample_rate;

			if (frame_pts < target_ts) {
				int64_t samples_to_skip = av_rescale_q(target_ts - frame_pts, audio_stream_ffmpeg->av_stream->time_base,
													   AVRational{1, static_cast<int>(mix_rate)});

				if (samples_to_skip < buffer_fill) {
					buffer_fill -= samples_to_skip;
					std::memmove(buffer, buffer + samples_to_skip, buffer_fill * sizeof(sint16_stereo));
				} else {
					buffer_fill = 0;
				}
				mixed = static_cast<int64_t>(p_position * mix_rate);
			} else {
				mixed =
					av_rescale_q(frame_pts - audio_stream_ffmpeg->start_time, audio_stream_ffmpeg->av_stream->time_base,
								 AVRational{1, static_cast<int>(mix_rate)});
			}
		}

		av_frame_unref(av_frame.get());
		av_frame_unref(av_decoded_frame.get());
	}

	audio_stream_ffmpeg->mutex->unlock();
	fill_buffer();
}

int32_t AudioStreamFFmpegPlayback::_mix_resampled(AudioFrame* p_buffer, int32_t p_frames) {
	if (!audio_stream_ffmpeg->loaded) {
		return 0;
	}

	while (buffer_fill < p_frames) {
		if (!fill_buffer()) {
			break;
		}
	}

	int32_t frames_to_copy = (p_frames <= buffer_fill) ? p_frames : buffer_fill;
	if (frames_to_copy == 0) {
		return 0;
	}
	for (int i = 0; i < frames_to_copy; ++i) {
		float fade = 1.0f;
		if (fade_in_remaining > 0) {
			fade = 1.0f - ((float)fade_in_remaining / (float)FADE_SAMPLES);
			fade_in_remaining--;
		}
		p_buffer[i] = AudioFrame{static_cast<float>(buffer[i].l) / 32767.0f * fade,
								 static_cast<float>(buffer[i].r) / 32767.0f * fade};
	}

	buffer_fill -= frames_to_copy;
	std::memmove(buffer, buffer + frames_to_copy, buffer_fill * sizeof(sint16_stereo));
	mixed += frames_to_copy;
	return frames_to_copy;
}

bool AudioStreamFFmpegPlayback::fill_buffer() {
	audio_stream_ffmpeg->mutex->lock();
	if (audio_stream_ffmpeg->file_path == "") {
		AudioStreamFFmpeg::_log_err("AudioStreamPlayback: Can't fill buffer, path is null!");
		audio_stream_ffmpeg->mutex->unlock();
		return false;
	}

	if (FFmpeg::get_frame(audio_stream_ffmpeg->av_format_ctx.get(), audio_stream_ffmpeg->av_codec_ctx.get(),
						  audio_stream_ffmpeg->av_stream->index, av_frame.get(), av_packet.get())) {
		audio_stream_ffmpeg->mutex->unlock();
		return false;
	}

	av_decoded_frame.get()->format = AV_SAMPLE_FMT_S16;
	av_decoded_frame->ch_layout = (AVChannelLayout)AV_CHANNEL_LAYOUT_STEREO;
	av_decoded_frame.get()->sample_rate = av_frame.get()->sample_rate;
	av_decoded_frame.get()->nb_samples =
		swr_get_out_samples(audio_stream_ffmpeg->swr_ctx.get(), av_frame.get()->nb_samples);

	int response = 0;
	if ((response = av_frame_get_buffer(av_decoded_frame.get(), 0)) < 0) {
		FFmpeg::print_av_error("AudioStreamFFmpeg: Couldn't create new frame for swr!", response);
		av_frame_unref(av_frame.get());
		av_frame_unref(av_decoded_frame.get());
		audio_stream_ffmpeg->mutex->unlock();
		return false;
	}

	response = swr_convert(audio_stream_ffmpeg->swr_ctx.get(), av_decoded_frame->data, av_decoded_frame->nb_samples,
						   (const uint8_t**)av_frame->extended_data, av_frame->nb_samples);
	if (response < 0) {
		FFmpeg::print_av_error("AudioStreamFFmpeg: Couldn't convert the audio data!", response);
		av_frame_unref(av_frame.get());
		av_frame_unref(av_decoded_frame.get());
		audio_stream_ffmpeg->mutex->unlock();
		return false;
	}
	av_decoded_frame->nb_samples = response;

	int new_samples = av_decoded_frame.get()->nb_samples;
	size_t byte_size = new_samples * audio_stream_ffmpeg->bytes_per_sample;
	byte_size *= 2;

	// Check if there is enough space in the buffer.
	if (buffer_fill + new_samples > buffer_len) {
		audio_stream_ffmpeg->_log_err("Buffer overflow prevented in fill_buffer!");
		av_frame_unref(av_frame.get());
		av_frame_unref(av_decoded_frame.get());
		audio_stream_ffmpeg->mutex->unlock();
		return false;
	}

	std::memcpy(buffer + buffer_fill, av_decoded_frame.get()->extended_data[0], byte_size);

	buffer_fill += av_decoded_frame.get()->nb_samples;
	mix_rate = av_frame.get()->sample_rate;
	av_frame_unref(av_frame.get());
	av_frame_unref(av_decoded_frame.get());

	audio_stream_ffmpeg->mutex->unlock();
	return true;
}

void AudioStreamFFmpeg::_bind_methods() {
	ClassDB::bind_method(D_METHOD("open", "path", "stream_index"), &AudioStreamFFmpeg::open, DEFVAL(-1));
	ClassDB::bind_method(D_METHOD("__instantiate_playback"), &AudioStreamFFmpeg::_instantiate_playback);
}
