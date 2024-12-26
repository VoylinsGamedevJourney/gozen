#include "audio.hpp"


AudioStreamWAV *Audio::get_wav(String a_path) {
	AVFormatContext *l_format_ctx = avformat_alloc_context();
	AudioStreamWAV *l_audio = nullptr;

	if (!l_format_ctx) {
		error = GoZenError::ERR_CREATING_AV_FORMAT_FAILED;
		return nullptr;
	}

	if (avformat_open_input(&l_format_ctx, a_path.utf8(), NULL, NULL)) {
		error = GoZenError::ERR_OPENING_AUDIO;
		return nullptr;
	}

	if (avformat_find_stream_info(l_format_ctx, NULL)) {
		error = GoZenError::ERR_NO_STREAM_INFO_FOUND;
		return nullptr;
	}

	for (int i = 0; i < l_format_ctx->nb_streams; i++) {
		AVCodecParameters *av_codec_params = l_format_ctx->streams[i]->codecpar;

		if (!avcodec_find_decoder(av_codec_params->codec_id)) {
			l_format_ctx->streams[i]->discard = AVDISCARD_ALL;
			continue;
		} else if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO) {
			l_audio = FFmpeg::get_audio(l_format_ctx, l_format_ctx->streams[i]);
			break;
		}
	}

	avformat_close_input(&l_format_ctx);

	error = OK;
	return l_audio;
}


PackedByteArray Audio::combine_data(PackedByteArray a_one, PackedByteArray a_two) {
	for (size_t i = 0; i < a_one.size(); i += 2) {
        int32_t combinedSample = Math::clamp(
				static_cast<int16_t>(a_one[i] | (a_one[i + 1] << 8)) +
				static_cast<int16_t>(a_two[i] | (a_two[i + 1] << 8)),
				-32768, 32767);

        a_one.ptrw()[i] = static_cast<uint8_t>(combinedSample & 0xFF);
        a_one.ptrw()[i + 1] = static_cast<uint8_t>((combinedSample >> 8) & 0xFF);
    }

    return a_one;
}

