#include "audio.hpp"
#include <map>


PackedByteArray Audio::get_audio_data(String a_path) {
	AVFormatContext *l_format_ctx = avformat_alloc_context();
	PackedByteArray l_data = PackedByteArray();

	if (!l_format_ctx) {
		error = GoZenError::ERR_CREATING_AV_FORMAT_FAILED;
		return l_data;
	}

	if (avformat_open_input(&l_format_ctx, a_path.utf8(), NULL, NULL)) {
		error = GoZenError::ERR_OPENING_AUDIO;
		return l_data;
	}

	if (avformat_find_stream_info(l_format_ctx, NULL)) {
		error = GoZenError::ERR_NO_STREAM_INFO_FOUND;
		return l_data;
	}

	for (int i = 0; i < l_format_ctx->nb_streams; i++) {
		AVCodecParameters *av_codec_params = l_format_ctx->streams[i]->codecpar;

		if (!avcodec_find_decoder(av_codec_params->codec_id)) {
			l_format_ctx->streams[i]->discard = AVDISCARD_ALL;
			continue;
		} else if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO) {
			l_data = FFmpeg::get_audio(l_format_ctx, l_format_ctx->streams[i]);
			break;
		}
	}

	avformat_close_input(&l_format_ctx);

	error = OK;
	return l_data;
}


PackedByteArray Audio::combine_data(PackedByteArray a_one, PackedByteArray a_two) {
	const int16_t *l_one = (const int16_t*)a_one.ptr();
	const int16_t *l_two = (const int16_t*)a_two.ptr();

	for (size_t i = 0; i < a_one.size() / 2; i++)
        ((int16_t*)a_one.ptrw())[i] = Math::clamp(l_one[i] + l_two[i], -32768, 32767);

    return a_one;
}


PackedByteArray Audio::change_db(PackedByteArray a_data, float a_db) {
	static std::map<int, double> l_cache;

	const int16_t *l_data = (const int16_t*)a_data.ptr();
	const auto l_search = l_cache.find(a_db);
	double l_value;

	if (l_search == l_cache.end()) {
		l_value = std::pow(10.0, a_db / 20.0);
		l_cache[a_db] = l_value;
	} else l_value = l_search->second;
	
	for (size_t i = 0; i < a_data.size() / 2; i++)
		((int16_t*)a_data.ptrw())[i] = Math::clamp((int32_t)(l_data[i] * l_value), -32768, 32767);

    return a_data;
}


PackedByteArray Audio::change_to_mono(PackedByteArray a_data, bool a_left) {
	const int16_t *l_data = (const int16_t*)a_data.ptr();

	if (a_left) {
		for (size_t i = 0; i < a_data.size() / 2; i += 2)
			((int16_t*)a_data.ptrw())[i + 1] = l_data[i];
    } else {
		for (size_t i = 0; i < a_data.size() / 2; i += 2)
			((int16_t*)a_data.ptrw())[i] = l_data[i + 1];
	}

    return a_data;
}

