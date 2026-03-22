#include "encoder.hpp"


Encoder::~Encoder() { close(); }

PackedStringArray Encoder::get_available_codecs(int codec_id) {
	PackedStringArray codec_names = PackedStringArray();
	const AVCodec* current_codec = nullptr;
	void* i = nullptr;

	while ((current_codec = av_codec_iterate(&i)))
		if (current_codec->id == codec_id && av_codec_is_encoder(current_codec))
			codec_names.append(current_codec->name);

	return codec_names;
}

bool Encoder::open(bool rgba) {
	if (encoder_open)
		return _log_err("Already open");

	if (path.is_empty())
		return _log_err("No path set");
	if (video_codec_id == AV_CODEC_ID_NONE)
		return _log_err("No video codec set");
	if (resolution.x <= 0 || resolution.y <= 0)
		return _log_err("Invalid resolution set");
	if (framerate <= 0)
		return _log_err("Invalid framerate set");

	format_size = rgba ? 4 : 3;

	// Allocating output media context.
	AVFormatContext* temp_format_ctx = nullptr;
	CharString local_path = path.utf8();

	if (avformat_alloc_output_context2(&temp_format_ctx, nullptr, nullptr, local_path.get_data())) {
		_log_err("Error creating AV Format by path extension, using MPEG");
		if (avformat_alloc_output_context2(&temp_format_ctx, nullptr, "mpeg", local_path.get_data())) {
			return _log_err("Error creating AV Format");
		}
	}

	av_format_ctx = make_unique_ffmpeg<AVFormatContext, AVFormatCtxOutputDeleter>(temp_format_ctx);

	// Setting up video stream.
	if (!_add_video_stream()) {
		close();
		return _log_err("Couldn't create video stream");
	}

	// Setting up audio stream.
	if (audio_codec_id != AV_CODEC_ID_NONE && !_add_audio_stream()) {
		close();
		return _log_err("Couldn't create video stream");
	}
	av_dump_format(av_format_ctx.get(), 0, local_path.get_data(), 1);

	// Open output file if needed.
	if (!_open_output_file()) {
		close();
		return _log_err("Couldn't open output file");
	}

	// Write stream header - if any.
	if (!_write_header()) {
		close();
		return _log_err("Couldn't write header");
	}

	frame_nr = 0;
	encoder_open = true;
	return true;
}

bool Encoder::_add_video_stream() {
	const AVCodec* av_codec = avcodec_find_encoder(video_codec_id);
	if (!av_codec) {
		_log_err(avcodec_get_name(video_codec_id));
		return _log_err("Couldn't open video codec");
	}

	if (!(av_packet_video = make_unique_avpacket()))
		return _log_err("Out of memory");

	av_stream_video = avformat_new_stream(av_format_ctx.get(), nullptr);
	if (!av_stream_video)
		return _log_err("Couldn't create stream");

	av_stream_video->id = av_format_ctx->nb_streams - 1;

	av_codec_ctx_video = make_unique_ffmpeg<AVCodecContext, AVCodecCtxDeleter>(avcodec_alloc_context3(av_codec));
	if (!av_codec_ctx_video)
		return _log_err("Couldn't alloc video codec");

	FFmpeg::enable_multithreading(av_codec_ctx_video.get(), av_codec, threads);

	av_codec_ctx_video->codec_id = video_codec_id;
	av_codec_ctx_video->width = resolution.x;  // Resolution must be
	av_codec_ctx_video->height = resolution.y; // a multiple of two.
	av_codec_ctx_video->time_base = {1, (int)round(framerate)};
	av_codec_ctx_video->framerate = {(int)round(framerate), 1};
	av_stream_video->time_base = av_codec_ctx_video->time_base;
	av_stream_video->avg_frame_rate = av_codec_ctx_video->framerate;
	av_codec_ctx_video->gop_size = gop_size;
	av_codec_ctx_video->pix_fmt = AV_PIX_FMT_YUV420P;

	// Set Sample Aspect Ratio (SAR) to 1:1 (Square Pixels).
	av_codec_ctx_video->sample_aspect_ratio = {1, 1};
	av_stream_video->sample_aspect_ratio = {1, 1};

	// Set color space to BT.709 and color range to TV (MPEG).
	av_codec_ctx_video->color_primaries = AVCOL_PRI_BT709;
	av_codec_ctx_video->color_trc = AVCOL_TRC_BT709;
	av_codec_ctx_video->colorspace = AVCOL_SPC_BT709;
	av_codec_ctx_video->color_range = AVCOL_RANGE_MPEG;

	if (av_codec_ctx_video->codec_id == AV_CODEC_ID_MPEG2VIDEO)
		av_codec_ctx_video->max_b_frames = b_frames <= 2 ? b_frames : 2;
	else
		av_codec_ctx_video->max_b_frames = b_frames;

	if (av_codec_ctx_video->codec_id == AV_CODEC_ID_MPEG1VIDEO)
		av_codec_ctx_video->mb_decision = 2;

	// Some formats want stream headers separated.
	if (av_format_ctx->oformat->flags & AVFMT_GLOBALHEADER)
		av_codec_ctx_video->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;

	// Setting the CRF.
	AVDictionary* codec_options = nullptr;
	av_dict_set(&codec_options, "crf", std::to_string(crf).c_str(), 0);
	av_opt_set(av_codec_ctx_video->priv_data, "crf", std::to_string(crf).c_str(), 0);

	// Encoding options for different codecs.
	if (av_codec->id == AV_CODEC_ID_H264 || av_codec->id == AV_CODEC_ID_HEVC) {
		av_opt_set(av_codec_ctx_video->priv_data, "preset", h264_preset.c_str(), 0);
		av_dict_set(&codec_options, "preset", h264_preset.c_str(), 0);
	}

	// Opening the video encoder codec.
	response = avcodec_open2(av_codec_ctx_video.get(), av_codec, &codec_options);
	av_dict_free(&codec_options);
	if (response < 0) {
		FFmpeg::print_av_error("Encoder: Couldn't open video codec context!", response);
		return _log_err("Couldn't open video codec");
	}

	av_frame_video = make_unique_avframe();
	if (!av_frame_video)
		return _log_err("Out of memory");

	av_frame_video->format = av_codec_ctx_video->pix_fmt;
	av_frame_video->width = resolution.x;
	av_frame_video->height = resolution.y;

	// 32 is a common value, 0 let's FFmpeg decide.
	if (av_frame_get_buffer(av_frame_video.get(), 32) < 0)
		return _log_err("Couldn't get frame buffer");

	// Copy video stream params to muxer
	if (avcodec_parameters_from_context(av_stream_video->codecpar, av_codec_ctx_video.get()) < 0) {
		return _log_err("Couldn't copy stream params");
	}

	return true;
}

bool Encoder::_add_audio_stream() {
	const AVCodec* av_codec = avcodec_find_encoder(audio_codec_id);
	if (!av_codec) {
		_log_err(avcodec_get_name(audio_codec_id));
		return _log_err("Couldn't find audio encoder");
	}

	if (!(av_packet_audio = make_unique_avpacket()))
		return _log_err("Out of memory");

	av_stream_audio = avformat_new_stream(av_format_ctx.get(), nullptr);
	if (!av_stream_audio)
		return _log_err("Couldn't create stream");

	av_stream_audio->id = av_format_ctx->nb_streams - 1;

	av_codec_ctx_audio = make_unique_ffmpeg<AVCodecContext, AVCodecCtxDeleter>(avcodec_alloc_context3(av_codec));
	if (!av_codec_ctx_audio)
		return _log_err("Couln't alloc audio codec");

	FFmpeg::enable_multithreading(av_codec_ctx_audio.get(), av_codec, threads);

	av_codec_ctx_audio->bit_rate = audio_bit_rate;
	const enum AVSampleFormat* sample_fmts;
	int num_sample_fmts;
	avcodec_get_supported_config(nullptr, av_codec, AV_CODEC_CONFIG_SAMPLE_FORMAT, 0, (const void**)&sample_fmts,
								 &num_sample_fmts);
	if (sample_fmts && num_sample_fmts > 0) {
		av_codec_ctx_audio->sample_fmt = sample_fmts[0];
	}

	av_codec_ctx_audio->sample_rate = sample_rate;
	const int* supported_samplerates;
	int num_supported_samplerates;
	avcodec_get_supported_config(nullptr, av_codec, AV_CODEC_CONFIG_SAMPLE_RATE, 0,
								 (const void**)&supported_samplerates, &num_supported_samplerates);
	if (supported_samplerates && num_supported_samplerates > 0) {
		for (int i = 0; i < num_supported_samplerates; i++) {
			if (supported_samplerates[i] == 48000) {
				av_codec_ctx_audio->sample_rate = 48000;
				break;
			}
		}
	}

	av_codec_ctx_audio->time_base = AVRational{1, av_codec_ctx_audio->sample_rate};
	av_stream_audio->time_base = av_codec_ctx_audio->time_base;

	AVChannelLayout ch_layout = AV_CHANNEL_LAYOUT_STEREO;
	av_channel_layout_copy(&av_codec_ctx_audio->ch_layout, &(ch_layout));

	if (av_format_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
		av_codec_ctx_audio->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
	}

	// Opening the audio encoder codec.
	response = avcodec_open2(av_codec_ctx_audio.get(), av_codec, nullptr);
	if (response < 0) {
		FFmpeg::print_av_error("Encoder: Couldn't open audio codec!", response);
		return false;
	}

	// Copy audio stream params to muxer.
	if (avcodec_parameters_from_context(av_stream_audio->codecpar, av_codec_ctx_audio.get())) {
		return _log_err("Couldn't copy stream params");
	}

	// Setup SWR.
	SwrContext* temp_swr_ctx = nullptr;
	swr_alloc_set_opts2(&temp_swr_ctx, &av_codec_ctx_audio->ch_layout, av_codec_ctx_audio->sample_fmt,
						av_codec_ctx_audio->sample_rate, &av_codec_ctx_audio->ch_layout, AV_SAMPLE_FMT_S16, sample_rate,
						0, nullptr);
	swr_ctx_audio = make_unique_ffmpeg<SwrContext, SwrCtxDeleter>(temp_swr_ctx);
	if (!swr_ctx_audio || swr_init(swr_ctx_audio.get()) < 0) {
		return _log_err("Couldn't create SWR");
	}

	return true;
}

bool Encoder::_open_output_file() {
	if (!(av_format_ctx->oformat->flags & AVFMT_NOFILE)) {
		CharString local_path = path.utf8();
		response = avio_open(&av_format_ctx->pb, local_path.get_data(), AVIO_FLAG_WRITE);

		if (response < 0) {
			FFmpeg::print_av_error("Encoder: Couldn't open output file!", response);
			return false;
		}
	}

	return true;
}

bool Encoder::_write_header() {
	AVDictionary* options = nullptr;

	CharString file_name = path.get_file().utf8();
	av_dict_set(&options, "title", file_name.get_data(), 0);
	av_dict_set(&options, "comment", "Rendered with the GoZen Video editor.", 0);

	if (path.get_extension().to_lower() == "mp4") {
		av_dict_set(&options, "movflags", "faststart", 0);
	}

	response = avformat_write_header(av_format_ctx.get(), &options);
	av_dict_free(&options);

	if (response < 0) {
		FFmpeg::print_av_error("Encoder: Error when writing header!", response);
		return false;
	}

	return true;
}

bool Encoder::send_frame(PackedByteArray yuv_data) {
	if (!encoder_open) {
		return _log_err("Not open");
	} else if (audio_codec_id != AV_CODEC_ID_NONE && !audio_added) {
		return _log_err("Audio hasn't been send");
	} else if (av_frame_make_writable(av_frame_video.get()) < 0) {
		return _log_err("Couldn't make frame writable");
	}
	av_frame_video->sample_aspect_ratio = {1, 1};
	av_frame_video->color_primaries = AVCOL_PRI_BT709;
	av_frame_video->color_trc = AVCOL_TRC_BT709;
	av_frame_video->colorspace = AVCOL_SPC_BT709;
	av_frame_video->color_range = AVCOL_RANGE_MPEG;

	// Directly copy the continuous YUV buffer from Godot into the AVFrame.
	int y_size = resolution.x * resolution.y;
	int u_size = (resolution.x / 2) * (resolution.y / 2);

	memcpy(av_frame_video->data[0], yuv_data.ptr(), y_size);				   // Y Plane.
	memcpy(av_frame_video->data[1], yuv_data.ptr() + y_size, u_size);		   // U Plane.
	memcpy(av_frame_video->data[2], yuv_data.ptr() + y_size + u_size, u_size); // V Plane.
	av_frame_video->linesize[0] = resolution.x;
	av_frame_video->linesize[1] = resolution.x / 2;
	av_frame_video->linesize[2] = resolution.x / 2;
	av_frame_video->pts = frame_nr;
	frame_nr++;

	// Adding frame.
	response = avcodec_send_frame(av_codec_ctx_video.get(), av_frame_video.get());
	if (response < 0) {
		FFmpeg::print_av_error("Encoder: Error sending video frame!", response);
		return false;
	}

	while (true) {
		response = avcodec_receive_packet(av_codec_ctx_video.get(), av_packet_video.get());
		if (response == AVERROR(EAGAIN) || response == AVERROR_EOF)
			break;
		else if (response < 0) {
			FFmpeg::print_av_error("Encoder: Error encoding video frame!", response);
			av_packet_unref(av_packet_video.get());
			return false;
		}

		// Rescale output packet timestamp values from codec to stream timebase
		av_packet_video->stream_index = av_stream_video->index;
		av_packet_rescale_ts(av_packet_video.get(), av_codec_ctx_video->time_base, av_stream_video->time_base);

		// Write the frame to file
		response = av_interleaved_write_frame(av_format_ctx.get(), av_packet_video.get());
		if (response < 0) {
			FFmpeg::print_av_error("Encoder: Error writing output packet!", response);
			response = -1;
			return false;
		}

		av_packet_unref(av_packet_video.get());
	}

	return true;
}

bool Encoder::send_audio(PackedByteArray wav_data) {
	if (!encoder_open)
		return _log_err("Not open");
	if (audio_codec_id == AV_CODEC_ID_NONE)
		return _log_err("Audio not enabled");
	if (audio_added)
		return _log_err("Audio already send");

	audio_buffer = wav_data;
	audio_buffer_offset = 0;
	audio_pts = 0;
	audio_added = true;

	// Pre-encode the entire audio buffer immediately.
	if (!_encode_audio_chunk(-1)) {
		return false;
	}

	// Flush the SWR buffer and Audio Encoder.
	int frame_size = av_codec_ctx_audio->frame_size == 0 ? 1024 : av_codec_ctx_audio->frame_size;
	UniqueAVFrame av_frame_out = make_unique_avframe();
	while (true) {
		av_frame_unref(av_frame_out.get());
		av_frame_out->ch_layout = av_codec_ctx_audio->ch_layout;
		av_frame_out->format = av_codec_ctx_audio->sample_fmt;
		av_frame_out->sample_rate = av_codec_ctx_audio->sample_rate;
		av_frame_out->nb_samples = frame_size;
		if (av_frame_get_buffer(av_frame_out.get(), 0) < 0) {
			break;
		}

		int converted_samples = swr_convert(swr_ctx_audio.get(), av_frame_out->data, frame_size, nullptr, 0);
		if (converted_samples <= 0) {
			break;
		}

		av_frame_out->nb_samples = converted_samples;
		av_frame_out->pts = audio_pts;
		audio_pts += converted_samples;

		avcodec_send_frame(av_codec_ctx_audio.get(), av_frame_out.get());
		while (avcodec_receive_packet(av_codec_ctx_audio.get(), av_packet_audio.get()) >= 0) {
			av_packet_audio->stream_index = av_stream_audio->index;
			av_packet_rescale_ts(av_packet_audio.get(), av_codec_ctx_audio->time_base, av_stream_audio->time_base);
			av_interleaved_write_frame(av_format_ctx.get(), av_packet_audio.get());
			av_packet_unref(av_packet_audio.get());
		}
	}
	av_packet_audio = make_unique_avpacket();
	avcodec_send_frame(av_codec_ctx_audio.get(), nullptr);
	while (avcodec_receive_packet(av_codec_ctx_audio.get(), av_packet_audio.get()) >= 0) {
		av_packet_audio->stream_index = av_stream_audio->index;
		av_packet_rescale_ts(av_packet_audio.get(), av_codec_ctx_audio->time_base, av_stream_audio->time_base);
		av_interleaved_write_frame(av_format_ctx.get(), av_packet_audio.get());
		av_packet_unref(av_packet_audio.get());
	}
	return true;
}

bool Encoder::_encode_audio_chunk(int samples_to_read) {
	if (audio_codec_id == AV_CODEC_ID_NONE || audio_buffer.size() == 0)
		return true;

	int frame_size = av_codec_ctx_audio->frame_size == 0 ? 1024 : av_codec_ctx_audio->frame_size;
	int in_bytes_per_sample = av_get_bytes_per_sample(AV_SAMPLE_FMT_S16) * 2;

	int remaining_in_buffer = (audio_buffer.size() - audio_buffer_offset) / in_bytes_per_sample;

	int samples_left;
	if (samples_to_read == -1) {
		samples_left = remaining_in_buffer;
	} else {
		int64_t expected_audio_samples = (int64_t)(frame_nr + 1) * sample_rate / framerate;
		int encoded_audio_samples = audio_buffer_offset / in_bytes_per_sample;
		samples_left = expected_audio_samples - encoded_audio_samples;
		samples_left = FFMIN(samples_left, remaining_in_buffer);
	}

	UniqueAVFrame av_frame_out = make_unique_avframe();
	if (!av_frame_out) {
		return _log_err("Out of memory");
	}
	if (samples_left > 0) {
		const uint8_t* input_data = audio_buffer.ptr() + audio_buffer_offset;
		const uint8_t* in_ptrs[1] = {input_data};
		int ret = swr_convert(swr_ctx_audio.get(), nullptr, 0, in_ptrs, samples_left);
		if (ret < 0) {
			return _log_err("Couldn't feed audio to swr");
		}
		audio_buffer_offset += samples_left * in_bytes_per_sample;
	}
	while (swr_get_out_samples(swr_ctx_audio.get(), 0) >= frame_size ||
		   (samples_to_read == -1 && swr_get_out_samples(swr_ctx_audio.get(), 0) > 0)) {

		av_frame_unref(av_frame_out.get());
		av_frame_out->ch_layout = av_codec_ctx_audio->ch_layout;
		av_frame_out->format = av_codec_ctx_audio->sample_fmt;
		av_frame_out->sample_rate = av_codec_ctx_audio->sample_rate;
		av_frame_out->nb_samples = frame_size;
		if (av_frame_get_buffer(av_frame_out.get(), 0) < 0) {
			return _log_err("Failed to allocate audio frame buffer");
		}
		int converted_samples = swr_convert(swr_ctx_audio.get(), av_frame_out->data, frame_size, nullptr, 0);
		if (converted_samples < 0) {
			return _log_err("Couldn't resample");
		} else if (converted_samples == 0) {
			break;
		} else if (converted_samples > 0) {
			av_frame_out->nb_samples = converted_samples;
			av_frame_out->pts = audio_pts;
			audio_pts += converted_samples;
			response = avcodec_send_frame(av_codec_ctx_audio.get(), av_frame_out.get());
			if (response < 0) {
				return _log_err("Error sending audio frame!");
			}
			while ((response = avcodec_receive_packet(av_codec_ctx_audio.get(), av_packet_audio.get())) >= 0) {
				av_packet_audio->stream_index = av_stream_audio->index;
				av_packet_rescale_ts(av_packet_audio.get(), av_codec_ctx_audio->time_base, av_stream_audio->time_base);
				response = av_interleaved_write_frame(av_format_ctx.get(), av_packet_audio.get());
				av_packet_unref(av_packet_audio.get());
				if (response < 0) {
					return _log_err("Error writing audio packet!");
				}
			}
		}
	}
	return true;
}

bool Encoder::_finalize_encoding() {
	if (!encoder_open) {
		return true;
	} else if (!av_format_ctx) {
		_log_err("Can't finalize encoding, no format context");
		return false;
	}

	// Flush video encoder.
	if (av_codec_ctx_video) {
		av_packet_video = make_unique_avpacket();
		response = avcodec_send_frame(av_codec_ctx_video.get(), nullptr);

		if (response < 0 && response != AVERROR_EOF) {
			FFmpeg::print_av_error("Encoder: Error sending null frame to video encoder!", response);
			return false;
		}

		while (true) {
			response = avcodec_receive_packet(av_codec_ctx_video.get(), av_packet_video.get());
			if (response == AVERROR_EOF) {
				av_packet_unref(av_packet_video.get());
				break;
			} else if (response == AVERROR(EAGAIN)) {
				// Should not happen when flushing with a NULL frame.
				_log_err("Video encoder returned EAGAIN during flush!");
				av_packet_unref(av_packet_video.get());
				break;
			} else if (response < 0) {
				FFmpeg::print_av_error("Encoder: Error receiving flushed video packet!", response);
				return false;
			}

			// Valid packet received, writing to file.
			av_packet_video->stream_index = av_stream_video->index;
			av_packet_rescale_ts(av_packet_video.get(), av_codec_ctx_video->time_base, av_stream_video->time_base);
			response = av_interleaved_write_frame(av_format_ctx.get(), av_packet_video.get());
			av_packet_unref(av_packet_video.get());

			if (response < 0) {
				FFmpeg::print_av_error("Encoder: Error writing flushed video packet to file!", response);
				return false;
			}
		}
	}

	// Writing stream trailer.
	if (av_format_ctx) {
		response = av_write_trailer(av_format_ctx.get());
		if (response < 0)
			FFmpeg::print_av_error("Encoder: Error writing trailer to video file!", response);
	}
	return true;
}


void Encoder::close() {
	if (frame_nr == 0)
		return;
	if (!_finalize_encoding())
		_log_err("_finalize_encoding failed with: " + String::num_int64(response));

	// Cleanup contexts.
	swr_ctx_audio.reset();
	audio_buffer.clear();

	av_packet_video.reset();
	av_packet_audio.reset();
	av_frame_video.reset();

	av_codec_ctx_video.reset();
	av_codec_ctx_audio.reset();

	av_format_ctx.reset();

	encoder_open = false;
	audio_added = false;
	frame_nr = 0;
}


#define BIND_STATIC_METHOD_ARGS(method_name, ...)                                                                      \
	ClassDB::bind_static_method("Encoder", D_METHOD(#method_name, __VA_ARGS__), &Encoder::method_name)

#define BIND_METHOD(method_name) ClassDB::bind_method(D_METHOD(#method_name), &Encoder::method_name)

#define BIND_METHOD_ARGS(method_name, ...)                                                                             \
	ClassDB::bind_method(D_METHOD(#method_name, __VA_ARGS__), &Encoder::method_name)

void Encoder::_bind_methods() {
	/* VIDEO CODEC ENUMS */
	BIND_ENUM_CONSTANT(V_HEVC);
	BIND_ENUM_CONSTANT(V_H264);
	BIND_ENUM_CONSTANT(V_MPEG4);
	BIND_ENUM_CONSTANT(V_MPEG2);
	BIND_ENUM_CONSTANT(V_MPEG1);
	BIND_ENUM_CONSTANT(V_MJPEG);
	BIND_ENUM_CONSTANT(V_AV1);
	BIND_ENUM_CONSTANT(V_VP9);
	BIND_ENUM_CONSTANT(V_VP8);
	BIND_ENUM_CONSTANT(V_NONE);

	/* AUDIO CODEC ENUMS */
	BIND_ENUM_CONSTANT(A_WAV);
	BIND_ENUM_CONSTANT(A_MP2);
	BIND_ENUM_CONSTANT(A_MP3);
	BIND_ENUM_CONSTANT(A_PCM);
	BIND_ENUM_CONSTANT(A_AAC);
	BIND_ENUM_CONSTANT(A_OPUS);
	BIND_ENUM_CONSTANT(A_VORBIS);
	BIND_ENUM_CONSTANT(A_FLAC);
	BIND_ENUM_CONSTANT(A_NONE);

	/* H264 PRESETS */
	BIND_ENUM_CONSTANT(H264_PRESET_ULTRAFAST);
	BIND_ENUM_CONSTANT(H264_PRESET_SUPERFAST);
	BIND_ENUM_CONSTANT(H264_PRESET_VERYFAST);
	BIND_ENUM_CONSTANT(H264_PRESET_FASTER);
	BIND_ENUM_CONSTANT(H264_PRESET_FAST);
	BIND_ENUM_CONSTANT(H264_PRESET_MEDIUM);
	BIND_ENUM_CONSTANT(H264_PRESET_SLOW);
	BIND_ENUM_CONSTANT(H264_PRESET_SLOWER);
	BIND_ENUM_CONSTANT(H264_PRESET_VERYSLOW);

	/* HARDWARE API'S */
	BIND_ENUM_CONSTANT(HW_DEVICE_TYPE_NONE);
	BIND_ENUM_CONSTANT(HW_DEVICE_TYPE_NVENC);
	BIND_ENUM_CONSTANT(HW_DEVICE_TYPE_VAAPI);
	BIND_ENUM_CONSTANT(HW_DEVICE_TYPE_QSV);

	BIND_STATIC_METHOD_ARGS(get_available_codecs, "codec_id");

	BIND_METHOD_ARGS(open, "rgba");
	BIND_METHOD(is_open);


	BIND_METHOD_ARGS(send_frame, "yuv_data");
	BIND_METHOD_ARGS(send_audio, "wav_data");

	BIND_METHOD(close);

	BIND_METHOD_ARGS(set_video_codec_id, "codec_id");
	BIND_METHOD_ARGS(set_audio_codec_id, "codec_id");
	BIND_METHOD(audio_codec_set);

	BIND_METHOD_ARGS(set_file_path, "file_path");

	BIND_METHOD_ARGS(set_resolution, "video_resolution");
	BIND_METHOD_ARGS(set_framerate, "video_framerate");
	BIND_METHOD_ARGS(set_crf, "video_crf");
	BIND_METHOD_ARGS(set_audio_bit_rate, "bit_rate");
	BIND_METHOD_ARGS(set_threads, "thread_count");
	BIND_METHOD_ARGS(set_gop_size, "video_gop_size");

	BIND_METHOD_ARGS(set_b_frames, "value");
	BIND_METHOD_ARGS(set_h264_preset, "value");

	BIND_METHOD_ARGS(set_sample_rate, "value");
}
