#include "audio.hpp"


PackedByteArray Audio::_get_audio(AVFormatContext *&format_ctx,
								  AVStream *&stream, bool wav) {
	const int TARGET_SAMPLE_RATE = 44100;
	const AVSampleFormat TARGET_FORMAT = AV_SAMPLE_FMT_S16;
	const AVChannelLayout TARGET_LAYOUT = AV_CHANNEL_LAYOUT_STEREO;

	UniqueAVCodecCtx codec_ctx;
	UniqueSwrCtx swr_ctx;
	UniqueAVPacket av_packet;
	UniqueAVFrame av_frame;
	UniqueAVFrame av_decoded_frame;

	PackedByteArray audio_data = PackedByteArray();


	const AVCodec *codec = avcodec_find_decoder(
			stream->codecpar->codec_id);
	if (!codec) {
		UtilityFunctions::printerr("Couldn't find any decoder for audio!");
		return audio_data;
	}

	codec_ctx = make_unique_ffmpeg<AVCodecContext, AVCodecCtxDeleter>(
			avcodec_alloc_context3(codec));
	if (codec_ctx == NULL) {
		UtilityFunctions::printerr("Couldn't allocate context for audio!");
		return audio_data;
	} 
	if (avcodec_parameters_to_context(codec_ctx.get(), stream->codecpar)) {
		UtilityFunctions::printerr("Couldn't initialize audio codec context!");
		return audio_data;
	}

	FFmpeg::enable_multithreading(codec_ctx.get(), codec);
	codec_ctx->request_sample_fmt = TARGET_FORMAT;

	if (avcodec_open2(codec_ctx.get(), codec, NULL)) {
		UtilityFunctions::printerr("Couldn't open audio codec!");
		return audio_data;
	}
	
	SwrContext* temp_swr_ctx = nullptr;
	int response = swr_alloc_set_opts2(&temp_swr_ctx,
			&TARGET_LAYOUT,			// Out channel layout: Stereo
			TARGET_FORMAT,			// We need 16 bits
			TARGET_SAMPLE_RATE,		// Sample rate should be the Godot default
			&codec_ctx->ch_layout,	// In channel layout
			codec_ctx->sample_fmt,	// In sample format
			codec_ctx->sample_rate,	// In sample rate
			0, nullptr);
	swr_ctx = make_unique_ffmpeg<SwrContext, SwrCtxDeleter>(temp_swr_ctx);

	if (response < 0 || (response = swr_init(swr_ctx.get()))) {
		FFmpeg::print_av_error("Couldn't initialize SWR!", response);
		return audio_data;
	}

	av_packet = make_unique_avpacket();
	av_frame = make_unique_avframe();
	av_decoded_frame = make_unique_avframe();

	if (!av_frame || !av_decoded_frame || !av_packet) {
		UtilityFunctions::printerr(
				"Couldn't allocate frames/packet for audio!");
		return audio_data;
	}

	size_t audio_size = 0;
	int bytes_per_samples = av_get_bytes_per_sample(TARGET_FORMAT);

	while (!(FFmpeg::get_frame(format_ctx, codec_ctx.get(), stream->index,
							   av_frame.get(), av_packet.get()))) {
		// Copy decoded data to new frame
		av_decoded_frame->format = TARGET_FORMAT;
		av_decoded_frame->ch_layout = TARGET_LAYOUT;
		av_decoded_frame->sample_rate = TARGET_SAMPLE_RATE;
		av_decoded_frame->nb_samples = swr_get_out_samples(
				swr_ctx.get(), av_frame->nb_samples);

		if ((response = av_frame_get_buffer(av_decoded_frame.get(), 0)) < 0) {
			FFmpeg::print_av_error(
					"Couldn't create new frame for swr!", response);
			av_frame_unref(av_frame.get());
			av_frame_unref(av_decoded_frame.get());
			break;
		}
		if (wav) {
			response = swr_config_frame(swr_ctx.get(), av_decoded_frame.get(), av_frame.get());
			if (response < 0) {
				FFmpeg::print_av_error(
						"Couldn't config the audio frame!", response);
				av_frame_unref(av_frame.get());
				av_frame_unref(av_decoded_frame.get());
				break;
			}
		}
		response = swr_convert_frame(swr_ctx.get(), av_decoded_frame.get(), av_frame.get());
		if (response < 0) {
			FFmpeg::print_av_error(
					"Couldn't convert the audio frame!", response);
			av_frame_unref(av_frame.get());
			av_frame_unref(av_decoded_frame.get());
			break;
		}

		size_t byte_size = av_decoded_frame->nb_samples * bytes_per_samples * 2;

		audio_data.resize(audio_size + byte_size);
		memcpy(&(audio_data.ptrw()[audio_size]), 
				av_decoded_frame->extended_data[0],
				byte_size);
		audio_size += byte_size;

		av_frame_unref(av_frame.get());
		av_frame_unref(av_decoded_frame.get());
	}

	// Cleanup
	avcodec_flush_buffers(codec_ctx.get());

	return audio_data;
}


PackedByteArray Audio::get_audio_data(String file_path) {
	av_log_set_level(AV_LOG_VERBOSE);
	AVFormatContext *format_ctx = avformat_alloc_context();
	PackedByteArray data = PackedByteArray();

	if (!format_ctx) {
		_log_err("Couldn't create AV Format");
		return data;
	}

	if (avformat_open_input(&format_ctx, file_path.utf8(), NULL, NULL)) {
		_log_err("Couldn't open audio");
		return data;
	}

	if (avformat_find_stream_info(format_ctx, NULL)) {
		_log_err("Couldn't find stream info");
		return data;
	}

	for (int i = 0; i < format_ctx->nb_streams; i++) {
		AVCodecParameters *av_codec_params = format_ctx->streams[i]->codecpar;

		if (!avcodec_find_decoder(av_codec_params->codec_id)) {
			format_ctx->streams[i]->discard = AVDISCARD_ALL;
			continue;
		} else if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO) {
			data = _get_audio(format_ctx, format_ctx->streams[i],
						file_path.get_extension().to_lower() == "wav");
			break;
		}
	}

	avformat_close_input(&format_ctx);
	av_log_set_level(AV_LOG_INFO);
	return data;
}


PackedByteArray Audio::combine_data(PackedByteArray audio_one,
									PackedByteArray audio_two) {
	const int16_t *p_one = (const int16_t*)audio_one.ptr();
	const int16_t *p_two = (const int16_t*)audio_two.ptr();

	for (size_t i = 0; i < audio_one.size() / 2; i++)
        ((int16_t*)audio_one.ptrw())[i] = Math::clamp(
				p_one[i] + p_one[i], -32768, 32767);

    return audio_one;
}


PackedByteArray Audio::change_db(PackedByteArray audio_data, float db) {
	static std::unordered_map<int, double> cache;
	
	const size_t sample_count = audio_data.size() / 2;
	const int16_t *p_data = reinterpret_cast<const int16_t*>(audio_data.ptr());
	int16_t *pw_data = reinterpret_cast<int16_t*>(audio_data.ptrw());

	const auto search = cache.find(db);
	double value;
	
	if (search == cache.end()) {
		value = std::pow(10.0, db / 20.0);
		cache[db] = value;
	} else value = search->second;
	
	for (size_t i = 0; i < sample_count; i++)
		pw_data[i] = Math::clamp((int32_t)(p_data[i] * value), -32768, 32767);

	return audio_data;
}


PackedByteArray Audio::change_to_mono(PackedByteArray audio_data, bool left) {
	const size_t sample_count = audio_data.size() / 2;
	const int16_t *p_data = (const int16_t*)audio_data.ptr();
	int16_t *pw_data = reinterpret_cast<int16_t*>(audio_data.ptrw());

	if (left) {
		for (size_t i = 0; i < sample_count; i += 2)
			pw_data[i + 1] = p_data[i];
    } else {
		for (size_t i = 0; i < sample_count; i += 2)
			pw_data[i] = p_data[i + 1];
	}

	return audio_data;
}


#define BIND_STATIC_METHOD_1(method_name, param1) \
    ClassDB::bind_static_method("Audio", \
        D_METHOD(#method_name, param1), &Audio::method_name)

#define BIND_STATIC_METHOD_2(method_name, param1, param2) \
    ClassDB::bind_static_method("Audio", \
        D_METHOD(#method_name, param1, param2), &Audio::method_name)


void Audio::_bind_methods() {
	BIND_STATIC_METHOD_1(get_audio_data, "file_path");

	BIND_STATIC_METHOD_2(combine_data, "audio_one", "audio_two");
	BIND_STATIC_METHOD_2(change_db, "audio_data", "db");
	BIND_STATIC_METHOD_2(change_to_mono, "audio_data", "left_channel");
}

