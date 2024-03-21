#include "render_profile.hpp"


void GoZenRenderProfile::set_filename(String new_filename) {
	filename = new_filename;
}


String GoZenRenderProfile::get_filename() {
	return filename;
}


void GoZenRenderProfile::set_video_codec(GoZenInterface::CODEC new_video_codec) {
	video_codec = static_cast<AVCodecID>(new_video_codec);
}


AVCodecID GoZenRenderProfile::get_video_codec() {
	return video_codec;
}


GoZenInterface::CODEC GoZenRenderProfile::get_video_codec_gozen() {
	return static_cast<GoZenInterface::CODEC>(video_codec);
}


void GoZenRenderProfile::set_audio_codec(GoZenInterface::CODEC new_audio_codec) {
	audio_codec = static_cast<AVCodecID>(new_audio_codec);
}


AVCodecID GoZenRenderProfile::get_audio_codec() {
	return audio_codec;
}


GoZenInterface::CODEC GoZenRenderProfile::get_audio_codec_gozen() {
	return static_cast<GoZenInterface::CODEC>(audio_codec);
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
