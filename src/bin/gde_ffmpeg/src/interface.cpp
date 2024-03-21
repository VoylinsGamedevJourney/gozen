#include "interface.hpp"


Array GoZenInterface::get_supported_video_codecs() {
	Array codecs = Array();
	std::pair<CODEC, String> video_codecs[] = {
		{H264, "H264"},
		{H265, "H265"},
		{MPEG1, "MPEG1"},
		{MPEG2, "MPEG2"},
		{MPEG4, "MPEG4"},
		{VP8, "VP8"},
		{VP9, "VP9"},
		{AV1, "AV1"},
	};
	for (const auto& v_codec : video_codecs) {
		const AVCodec* codec = avcodec_find_encoder(static_cast<AVCodecID>(v_codec.first));
		Dictionary entry = {};
		entry["codec_id"] = v_codec.second;
		entry["supported"] = is_codec_supported(v_codec.first);
		entry["hardware_accel"] = codec->capabilities & AV_CODEC_CAP_HARDWARE;
		codecs.append(entry);
	}
	return codecs;
}


Array GoZenInterface::get_supported_audio_codecs() {
	Array codecs = Array();
	std::pair<CODEC, String> audio_codecs[] = {
		{MP3, "MP3"},
		{AAC, "AAC"},
		{OPUS, "OPUS"},
		{VORBIS, "VORBIS"},
		{FLAC, "FLAC"},
		{AC3, "AC3"},
		{EAC3, "EAC3"},
		{WAV, "WAV"},
	};
	for (const auto& a_codec : audio_codecs) {
		const AVCodec* codec = avcodec_find_encoder(static_cast<AVCodecID>(a_codec.first));
		Dictionary entry = {};
		entry["codec_id"] = a_codec.second;
		entry["supported"] = is_codec_supported(a_codec.first);
		entry["hardware_accel"] = codec->capabilities & AV_CODEC_CAP_HARDWARE;
		codecs.append(entry);
	}
	return codecs;
}


Dictionary GoZenInterface::get_video_file_meta(String file_path) {
	AVFormatContext *p_format_context = NULL;
	const AVDictionaryEntry *p_tag = NULL;
	Dictionary dic = {};
 
	if (avformat_open_input(&p_format_context, file_path.utf8(), NULL, NULL)) {
		UtilityFunctions::printerr("Could not open file!");
		return dic;
	}
	
	if (avformat_find_stream_info(p_format_context, NULL) < 0) {
		UtilityFunctions::printerr("Could not find stream info!");
		return dic;
	}
	
	while ((p_tag = av_dict_iterate(p_format_context->metadata, p_tag)))
		dic[p_tag->key] = p_tag->value;
	
	avformat_close_input(&p_format_context);
	return dic;
}


bool GoZenInterface::is_codec_supported(CODEC codec) { 
	return ((const AVCodec*)avcodec_find_encoder(static_cast<AVCodecID>(codec)));
}
