#include "render_profile.hpp"



void RenderProfile::set_filename(String a_filename) {
	filename = a_filename;
}


String RenderProfile::get_filename() const {
	return filename;
}


void RenderProfile::set_video_codec(CODEC a_video_codec) {
	video_codec = static_cast<AVCodecID>(a_video_codec);
}


RenderProfile::CODEC RenderProfile::get_video_codec() const {
	return static_cast<CODEC>(video_codec);
}


void RenderProfile::set_audio_codec(RenderProfile::CODEC a_audio_codec) {
	audio_codec = static_cast<AVCodecID>(a_audio_codec);
}


RenderProfile::CODEC RenderProfile::get_audio_codec() const {
	return static_cast<CODEC>(audio_codec);
}


void RenderProfile::set_video_size(Vector2i a_video_size) {
	video_size = a_video_size;
}


Vector2i RenderProfile::get_video_size() const {
	return video_size;
}


void RenderProfile::set_framerate(int a_framerate) {
	framerate = a_framerate;
}


int RenderProfile::get_framerate() const {
	return framerate;
}


void RenderProfile::set_bit_rate(int a_bit_rate) {
	bit_rate = a_bit_rate;
}


int RenderProfile::get_bit_rate() const {
	return bit_rate;
}


void RenderProfile::set_alpha_layer(bool a_alpha_layer) {
	alpha_layer = a_alpha_layer;
}


bool RenderProfile::get_alpha_layer() const {
	return alpha_layer;
}


bool RenderProfile::check() const {
	return !(filename.is_empty() || !video_codec || !audio_codec || video_size == Vector2i(0,0) || framerate == -1 || bit_rate == -1);
}


void RenderProfile::_bind_methods() { 
	/* AUDIO CODEC ENUMS */
	BIND_ENUM_CONSTANT(MP3);
	BIND_ENUM_CONSTANT(AAC);
	BIND_ENUM_CONSTANT(OPUS);
	BIND_ENUM_CONSTANT(VORBIS);
	BIND_ENUM_CONSTANT(FLAC);
	BIND_ENUM_CONSTANT(PCM_UNCOMPRESSED);
	BIND_ENUM_CONSTANT(AC3);
	BIND_ENUM_CONSTANT(EAC3);
	BIND_ENUM_CONSTANT(WAV);

	/* VIDEO CODEC ENUMS */
	BIND_ENUM_CONSTANT(H264);
	BIND_ENUM_CONSTANT(H265);
	BIND_ENUM_CONSTANT(VP9);
	BIND_ENUM_CONSTANT(MPEG4);
	BIND_ENUM_CONSTANT(MPEG2);
	BIND_ENUM_CONSTANT(MPEG1);
	BIND_ENUM_CONSTANT(AV1);
	BIND_ENUM_CONSTANT(VP8);


	ClassDB::bind_method(D_METHOD("set_filename", "a_filename"), &RenderProfile::set_filename);
	ClassDB::bind_method(D_METHOD("get_filename"), &RenderProfile::get_filename);
	
	ClassDB::bind_method(D_METHOD("set_video_codec", "CODEC"), &RenderProfile::set_video_codec);
	ClassDB::bind_method(D_METHOD("get_video_codec"), &RenderProfile::get_video_codec);

	ClassDB::bind_method(D_METHOD("set_audio_codec", "CODEC"), &RenderProfile::set_audio_codec);
	ClassDB::bind_method(D_METHOD("get_audio_codec"), &RenderProfile::get_audio_codec);
	
	ClassDB::bind_method(D_METHOD("set_video_size", "a_video_size"), &RenderProfile::set_video_size);
	ClassDB::bind_method(D_METHOD("get_video_size"), &RenderProfile::get_video_size);
	
	ClassDB::bind_method(D_METHOD("set_framerate", "a_framerate"), &RenderProfile::set_framerate);
	ClassDB::bind_method(D_METHOD("get_framerate"), &RenderProfile::get_framerate);
	
	ClassDB::bind_method(D_METHOD("set_bit_rate", "a_bit_rate"), &RenderProfile::set_bit_rate);
	ClassDB::bind_method(D_METHOD("get_bit_rate"), &RenderProfile::get_bit_rate);
	
	ClassDB::bind_method(D_METHOD("set_alpha_layer", "a_alpha_layer"), &RenderProfile::set_alpha_layer);
	ClassDB::bind_method(D_METHOD("get_alpha_layer"), &RenderProfile::get_alpha_layer);
	
	ClassDB::bind_method(D_METHOD("check"), &RenderProfile::check);


	ADD_PROPERTY(PropertyInfo(Variant::STRING, "filename"), "set_filename", "get_filename");
	ADD_PROPERTY(PropertyInfo(Variant::VECTOR2I, "video_size"), "set_video_size", "get_video_size");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "framerate"), "set_framerate", "get_framerate");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "bit_rate"), "set_bit_rate", "get_bit_rate");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "alpha_layer"), "set_alpha_layer", "get_alpha_layer");
}