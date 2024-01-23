#include "gozen_render_profile.hpp"


Dictionary GoZenRenderProfile::get_supported_codecs() {
  Dictionary dic = {};
  Dictionary audio = {};
  Dictionary video = {};
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
  std::pair<CODEC, String> video_codecs[] = {
    {H264, "H264"},
    {H265, "H265"},
    {VP9, "VP9"},
    {MPEG4, "MPEG4"},
    {MPEG2, "MPEG2"},
    {MPEG1, "MPEG1"},
    {AV1, "AV1"},
    {VP8, "VP8"},
  };
  
  /* Audio codecs */
  for (const auto& a_codec : audio_codecs) {
    const AVCodec* codec = avcodec_find_encoder(static_cast<AVCodecID>(a_codec.first));
    Dictionary entry = {};
    entry["supported"] = is_codec_supported(a_codec.first);
    entry["codec_id"] = a_codec.second;
    entry["hardware_accel"] = codec->capabilities & AV_CODEC_CAP_HARDWARE;
    audio[a_codec.second] = entry;
  }
  
  /* Video codecs */
  for (const auto& v_codec : video_codecs) {
    const AVCodec* codec = avcodec_find_encoder(static_cast<AVCodecID>(v_codec.first));
    Dictionary entry = {};
    entry["supported"] = is_codec_supported(v_codec.first);
    entry["codec_id"] = v_codec.second;
    entry["hardware_accel"] = codec->capabilities & AV_CODEC_CAP_HARDWARE;
    video[v_codec.second] = entry;
  }

  dic["audio"] = audio;
  dic["video"] = video;
  return dic;
}


Dictionary GoZenRenderProfile::get_video_file_meta(String file_path) {
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


void GoZenRenderProfile::set_filename(String new_filename) {
  filename = new_filename;
}


String GoZenRenderProfile::get_filename() {
  return filename;
}


void GoZenRenderProfile::set_video_codec(CODEC new_video_codec) {
  video_codec = static_cast<AVCodecID>(new_video_codec);
}


AVCodecID GoZenRenderProfile::get_video_codec() {
  return video_codec;
}


GoZenRenderProfile::CODEC GoZenRenderProfile::get_video_codec_gozen() {
  return static_cast<CODEC>(video_codec);
}


void GoZenRenderProfile::set_audio_codec(CODEC new_audio_codec) {
  audio_codec = static_cast<AVCodecID>(new_audio_codec);
}


AVCodecID GoZenRenderProfile::get_audio_codec() {
  return audio_codec;
}


GoZenRenderProfile::CODEC GoZenRenderProfile::get_audio_codec_gozen() {
  return static_cast<CODEC>(audio_codec);
}

 
void GoZenRenderProfile::set_video_size(Vector2i new_video_size) {
  video_size = new_video_size;
}


Vector2i GoZenRenderProfile::get_video_size() {
  return video_size;
}


void GoZenRenderProfile::set_framerate(int new_framerate) {
  framerate = new_framerate;
}


int GoZenRenderProfile::get_framerate() {
  return framerate;
}


void GoZenRenderProfile::set_bit_rate(int new_bit_rate) {
  bit_rate = new_bit_rate;
}


int GoZenRenderProfile::get_bit_rate() {
  return bit_rate;
}


void GoZenRenderProfile::set_alpha_layer(bool new_alpha_layer) {
  alpha_layer = new_alpha_layer;
}


bool GoZenRenderProfile::get_alpha_layer() {
  return alpha_layer;
}


bool GoZenRenderProfile::check() {
  return !(filename.is_empty() || !video_codec || !audio_codec || video_size == Vector2i(0,0) || framerate == -1 || bit_rate == -1);
}


bool GoZenRenderProfile::is_codec_supported(CODEC codec) { 
  return ((const AVCodec*)avcodec_find_encoder(static_cast<AVCodecID>(codec)));
}
