#pragma once

#include <cmath>

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/core/math.hpp>

#include "ffmpeg.hpp"


using namespace godot;

class Audio : public Resource {
	GDCLASS(Audio, Resource);

private:
	static PackedByteArray _get_audio(AVFormatContext *&a_format_ctx, AVStream *&a_stream, bool a_wav);

	static inline void _log(String a_message) {
		UtilityFunctions::print("Renderer: ", a_message, ".");
	}
	static inline bool _log_err(String a_message) {
		UtilityFunctions::printerr("Renderer: ", a_message, "!");
		return false;
	}

public:
	static PackedByteArray get_audio_data(String a_path);
	static Ref<ImageTexture> get_audio_wave(PackedByteArray a_data, int a_framerate);

	static PackedByteArray combine_data(PackedByteArray a_one, PackedByteArray a_two);

	static PackedByteArray change_db(PackedByteArray a_data, float a_db);
	static PackedByteArray change_to_mono(PackedByteArray a_data, bool a_left);


protected:
	static inline void _bind_methods() {
		ClassDB::bind_static_method("Audio", D_METHOD("get_audio_data", "a_file_path"), &Audio::get_audio_data);
		ClassDB::bind_static_method("Audio", D_METHOD("get_audio_wave", "a_data", "a_framerate"), &Audio::get_audio_wave);

		ClassDB::bind_static_method("Audio", D_METHOD("combine_data", "a_one", "a_two"), &Audio::combine_data);

		ClassDB::bind_static_method("Audio", D_METHOD("change_db", "a_db"), &Audio::change_db);
		ClassDB::bind_static_method("Audio", D_METHOD("change_to_mono", "a_left"), &Audio::change_to_mono);
	}
};
