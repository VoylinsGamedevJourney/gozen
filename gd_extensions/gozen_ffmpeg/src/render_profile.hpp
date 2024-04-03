#pragma once

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include "ffmpeg_includes.hpp"
#include "interface.hpp"


using namespace godot;


class GoZenRenderProfile: public Resource {
	GDCLASS(GoZenRenderProfile, Resource);

	public:
		String filename;
		AVCodecID video_codec, audio_codec;
		Vector2i video_size;
		int framerate = -1, bit_rate = -1;
		bool alpha_layer = false;


		static Dictionary get_supported_codecs();


		void set_filename(String new_filename);
		String get_filename();
		
		void set_video_codec(GoZenInterface::CODEC new_video_codec);
		AVCodecID get_video_codec();
		GoZenInterface::CODEC get_video_codec_gozen();

		void set_audio_codec(GoZenInterface::CODEC new_audio_codec);
		AVCodecID get_audio_codec();
		GoZenInterface::CODEC get_audio_codec_gozen();
 
		void set_video_size(Vector2i new_video_size);
		Vector2i get_video_size();
	 
		void set_framerate(int new_framerate);
		int get_framerate();

		void set_bit_rate(int new_bit_rate);
		int get_bit_rate();

		void set_alpha_layer(bool new_alpha_layer);
		bool get_alpha_layer();

		bool check();

	
	protected:
		static inline void _bind_methods() {	 
			ClassDB::bind_method(D_METHOD("set_filename", "new_filename"), &GoZenRenderProfile::set_filename);
			ClassDB::bind_method(D_METHOD("get_filename"), &GoZenRenderProfile::get_filename);
			
			ClassDB::bind_method(D_METHOD("set_video_codec", "CODEC"), &GoZenRenderProfile::set_video_codec);
			//ClassDB::bind_method(D_METHOD("get_video_codec"), &GoZenRenderProfile::get_video_codec);
			ClassDB::bind_method(D_METHOD("get_video_codec_gozen"), &GoZenRenderProfile::get_video_codec_gozen);

			ClassDB::bind_method(D_METHOD("set_audio_codec", "CODEC"), &GoZenRenderProfile::set_audio_codec);
			//ClassDB::bind_method(D_METHOD("get_audio_codec"), &GoZenRenderProfile::get_audio_codec);
			ClassDB::bind_method(D_METHOD("get_audio_codec_gozen"), &GoZenRenderProfile::get_audio_codec_gozen);
			
			ClassDB::bind_method(D_METHOD("set_video_size", "new_video_size"), &GoZenRenderProfile::set_video_size);
			ClassDB::bind_method(D_METHOD("get_video_size"), &GoZenRenderProfile::get_video_size);
			
			ClassDB::bind_method(D_METHOD("set_framerate", "new_framerate"), &GoZenRenderProfile::set_framerate);
			ClassDB::bind_method(D_METHOD("get_framerate"), &GoZenRenderProfile::get_framerate);
			
			ClassDB::bind_method(D_METHOD("set_bit_rate", "new_bit_rate"), &GoZenRenderProfile::set_bit_rate);
			ClassDB::bind_method(D_METHOD("get_bit_rate"), &GoZenRenderProfile::get_bit_rate);
			
			ClassDB::bind_method(D_METHOD("set_alpha_layer", "new_alpha_layer"), &GoZenRenderProfile::set_alpha_layer);
			ClassDB::bind_method(D_METHOD("get_alpha_layer"), &GoZenRenderProfile::get_alpha_layer);
			
			ClassDB::bind_method(D_METHOD("check"), &GoZenRenderProfile::check);


			ADD_PROPERTY(PropertyInfo(Variant::STRING, "filename"), "set_filename", "get_filename");
			ADD_PROPERTY(PropertyInfo(Variant::VECTOR2I, "video_size"), "set_video_size", "get_video_size");
			ADD_PROPERTY(PropertyInfo(Variant::INT, "framerate"), "set_framerate", "get_framerate");
			ADD_PROPERTY(PropertyInfo(Variant::INT, "bit_rate"), "set_bit_rate", "get_bit_rate");
			ADD_PROPERTY(PropertyInfo(Variant::BOOL, "alpha_layer"), "set_alpha_layer", "get_alpha_layer");
		}
};