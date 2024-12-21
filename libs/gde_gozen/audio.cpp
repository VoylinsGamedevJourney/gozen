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
